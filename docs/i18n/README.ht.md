# OBJC-HomemadeBlockProgram

Sa a se yon pwogram liy-kòmand Objective-C pou OpenBSD ki ranplase script shell `OpenBSDHomemadeBlockScripts`. Li li `/var/log/authlog`, pran IP atakan SSH epi bloke yo nan pf.

## Sitiyasyon

Lè `sshd` aktif, atak brute-force yo repete anpil fwa. Pwogram nan pran IP atakan an, mete li nan lis blokaj pf, epi voye evènman an nan log santral la.

## Fichye sous

| Fichye | Objektif |
|---|---|
| `main.m` | Pwen antre CLI ak òkestrasyon |
| `HBPConfiguration.h/m` | Paramèt reglabl (chemen, syslog, èdtan blokaj) |
| `HBPAuthLogScanner.h/m` | Li authlog epi ekstrè IP atakan inik |
| `HBPBlockManager.h/m` | Jere fichye blokaj, ledger, ekspirasyon, ak rechaj pf |
| `HBPViolationScanner.h/m` | Eskanè fenèt tan pou vyolasyon web |
| `GNUmakefile` | Fichye build GNUstep |

## Prekondisyon

OpenBSD + GNUstep obligatwa. `pfctl` ak `logger` deja nan sistèm baz la.

```sh
pkg_add gnustep-base
```

## Konfigirasyon

Modifye valè yo nan `HBPConfiguration.m` (`+defaultConfiguration`) anvan build:

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

> Mete `whitelistIP` sou IP admin ou fè konfyans anvan deployment.

## pf.conf

`/etc/pf.conf` dwe genyen tablo sa a:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Kreye repètwa/fichye ki nesesè yo:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Build

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Itilizasyon

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Nouvo blokaj yo anrejistre nan `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Blokaj ki ekspire yo anrejistre nan `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Kouri kòm root (obligatwa pou `pfctl`).

## Cronjob

Egzanp antre peryodik pou `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Risk

Zouti sa a fèt pou l senp e baze sou modèl. Revize source code la anvan itilizasyon pwodiksyon, espesyalman `HBPConfiguration.m`. `--expire-blocks` koupe ansyen antre yo otomatikman.
