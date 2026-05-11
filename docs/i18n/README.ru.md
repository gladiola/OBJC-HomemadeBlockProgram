# OBJC-HomemadeBlockProgram

Это CLI-программа Objective-C для OpenBSD, заменяющая shell-скрипты `OpenBSDHomemadeBlockScripts`. Она читает `/var/log/authlog`, находит IP SSH-атак и добавляет их в таблицу блокировки pf.

## Ситуация

Когда `sshd` включён, brute-force атаки повторяются постоянно. Программа выделяет IP атакующего, добавляет его в список блокировки pf и отправляет событие в центральный лог.

## Исходные файлы

| Файл | Назначение |
|---|---|
| `main.m` | Точка входа CLI и оркестрация |
| `HBPConfiguration.h/m` | Настраиваемые параметры (пути, syslog, часы блокировки) |
| `HBPAuthLogScanner.h/m` | Чтение authlog и извлечение уникальных IP атакующих |
| `HBPBlockManager.h/m` | Управление файлом блокировок, журналом, истечением и перезагрузкой pf |
| `HBPViolationScanner.h/m` | Сканер временного окна для веб-нарушений |
| `GNUmakefile` | Файл сборки GNUstep |

## Требования

Требуются OpenBSD + GNUstep. `pfctl` и `logger` входят в базовую систему.

```sh
pkg_add gnustep-base
```

## Конфигурация

Отредактируйте значения в `HBPConfiguration.m` (`+defaultConfiguration`) перед сборкой:

```objc
config.syslogHost  = @"your.syslog.host";  // hostname/IP of remote syslog server
config.syslogPort  = @"514";               // UDP port (514 is standard)
config.blockHours  = 24;                   // how long a block stays in effect
config.whitelistIP = @"192.0.2.1";         // YOUR management IP — never blocked

// Web-violation scanning (used by --monitor-allowlist-violations and
// --monitor-slowloris-violations):
config.webViolationThreshold   = 10;   // violations before blocking
config.webViolationWindowHours = 1;    // rolling window in hours
```

> Установите `whitelistIP` на доверенный IP администратора перед развертыванием.

## pf.conf

`/etc/pf.conf` должен содержать эту таблицу:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Создайте необходимые каталоги/файлы:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Сборка

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Использование

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Новые блокировки логируются с уровнем `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Истекшие блокировки логируются с уровнем `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Запускайте от root (требуется для `pfctl`).

## Cronjob

Пример периодических записей для `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Риски

Этот инструмент намеренно простой и шаблонный. Просмотрите исходный код перед использованием в продакшене, особенно `HBPConfiguration.m`. `--expire-blocks` автоматически удаляет старые записи.
