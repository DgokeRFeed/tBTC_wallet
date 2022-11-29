# tBTC_wallet
Скрипт на языке Ruby для системы Windows, позволяющий получать и отправлять tBTC  монеты. При создании использовался гем "bitcoin-ruby"

### Для работы со скриптом необходимо скачать репозиторий и выполнить команду:
```
bundle install
```
При первом использовании программы будет создан новый кошелек, приватный ключ которого будет помещен в директории "C://tBTC_papka"

Для работы со скриптом доступны следущие опции:
- --wallet,                 вывод адреса кошелька и его доступный баланс
- --send <сумма> <адрес>,   отправка указанной суммы tBTC на указанный адрес
