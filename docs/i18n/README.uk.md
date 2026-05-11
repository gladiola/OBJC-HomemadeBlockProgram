# OBJC-HomemadeBlockProgram

Це Objective-C CLI-програма для OpenBSD, яка замінює shell-скрипти `OpenBSDHomemadeBlockScripts`. Вона читає `/var/log/authlog`, знаходить IP SSH-атак і додає їх до таблиці блокувань pf.

## Ситуація

Коли `sshd` увімкнено, атаки brute-force повторюються. Програма знаходить IP нападника, додає його до блокування pf і надсилає подію в центральний лог.

## Файли джерела

| Файл | Призначення |
|---|---|
| `main.m` | Точка входу CLI та оркестрація |
| `HBPConfiguration.h/m` | Налаштовувані параметри (шляхи, syslog, години блокування) |
| `HBPAuthLogScanner.h/m` | Читає authlog і витягує унікальні IP атакувальників |
| `HBPBlockManager.h/m` | Керує файлом блокувань, журналом, терміном дії та перезавантаженням pf |
| `HBPViolationScanner.h/m` | Сканер часових вікон для веб-порушень |
| `GNUmakefile` | Файл збірки GNUstep |

## Передумови

Потрібні OpenBSD + GNUstep. `pfctl` і `logger` входять до базової системи.

```sh
pkg_add gnustep-base
```

## Конфігурація

Відредагуйте значення в `HBPConfiguration.m` (`+defaultConfiguration`) перед збіркою:

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

> Встановіть `whitelistIP` на довірену IP-адресу адміністратора перед розгортанням.

## pf.conf

`/etc/pf.conf` має містити цю таблицю:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Створіть потрібні каталоги/файли:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Збірка

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Використання

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Нові блокування логуються на рівні `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Прострочені блокування логуються на рівні `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Запускайте від root (потрібно для `pfctl`).

## Cronjob

Приклад періодичних записів для `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Ризики

Цей інструмент навмисно простий і шаблонний. Перегляньте вихідний код перед використанням у продакшені, особливо `HBPConfiguration.m`. `--expire-blocks` автоматично очищає старі записи.
