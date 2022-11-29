require "net/http"
require "json"
require "stringio"
require "bitcoin"

include Bitcoin::Builder
Bitcoin.network = :testnet3

# 1 BTC = 100_000_000 SATOSHI
SATOSHI = 0.000_000_01
# комиссия майнерам
FEE = 0.0001

# получение UTXO пула кошелька в JSON формате
def get_utxo_pool(address)
  utxo_pool = Net::HTTP.get(URI("https://blockstream.info/testnet/api/address/#{address}/utxo"))
  JSON.parse(utxo_pool)
end

# получение баланса кошелька
def get_balance(address)
  balance = 0

  utxo_pool = get_utxo_pool(address)
  utxo_pool.each do |field|
    balance += field["value"] if field["status"]["confirmed"] # считаются только доступные подтвержденные выходы
  end

  balance * SATOSHI
end

# создание транзакции по переводу tBTC
# и отправка её в сеть
def send_tBTC(key, value, recipients_address)
  new_tx = build_tx do |t|
    utxo_pool = get_utxo_pool(key.addr)

    # в качестве входов используются все доступные выходы
    utxo_pool.each do |field|
      if field["status"]["confirmed"]
        t.input do |i|
          # получение необработанной транзакции в 16-ричном формате
          raw_tx = Net::HTTP.get(URI("https://blockstream.info/testnet/api/tx/#{field["txid"]}/hex"))
          # преобразование этой транзакции в двоичный формат, создание из него tx и передача
          # в качестве предыдущей транзакции
          i.prev_out Bitcoin::Protocol::Tx.new([raw_tx].pack('H*'))
          i.prev_out_index field["vout"]
          i.signature_key key
        end
      end
    end

    # выход, адресованный получателю
    t.output do |o|
      o.value value / SATOSHI
      o.script {|s| s.recipient recipients_address }
    end

    # сдача
    t.output do |o|
      o.value (get_balance(key.addr) - value - FEE) / SATOSHI
      o.script {|s| s.recipient key.addr }
    end
  end

  # преобразование собранной tx в 16-ричный формат для передачи в сеть
  new_tx_hex = new_tx.to_payload.bth

  uri = URI("https://blockstream.info/testnet/api/tx")
  req = Net::HTTP::Post.new(uri)
  req.body = new_tx_hex

  res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) {|http|
    http.request(req)
  }
  puts
  puts res.body # возвращает txid созданной транзакции
end

# создание директории с приватным ключем на диске С:
Dir.mkdir("C://tBTC_papka") unless File.directory?("C://tBTC_papka")

# генерация нового адреса кошелька и запись его в ранее созданную директорию
# если его еще не существует
unless File.exist?("C://tBTC_papka/private_key.txt")
  key = Bitcoin::Key.generate
  private_key = key.to_base58
  File.write("C://tBTC_papka/private_key.txt", private_key)
end

private_key = File.read("C://tBTC_papka/private_key.txt")
my_key = Bitcoin::Key.from_base58(private_key)

case ARGV[0]
when "--wallet"
  puts "wallet address - #{my_key.addr}"
  puts "your balance is #{get_balance(my_key.addr)} tBTC"
when "--send"
  value = ARGV[1].to_f
  balance = get_balance(my_key.addr)
  unless value + FEE < balance
    puts "Not enough coins! Balance = #{balance} tBTC"
    exit
  end

  recipients_address = ARGV[2]

  send_tBTC(my_key, value, recipients_address)
when "--help"
  puts "--wallet"
  puts "Wallet address and available balance in tBTC"
  puts
  puts "--send <value in tBTC> <recipient's address>"
  puts "Send tBTC to specified address"
else
  puts "Unknown option! Try --help for more information."
end
