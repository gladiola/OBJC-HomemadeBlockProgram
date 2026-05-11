# OBJC-HomemadeBlockProgram

See on OpenBSD Objective-C käsureaprogramm, mis asendab `OpenBSDHomemadeBlockScripts` shelliskripte. Programm loeb `/var/log/authlog`, leiab SSH ründaja IP-d ja lisab need pf blokeeringusse.

## Olukord

Kui `sshd` on aktiivne, korduvad brute-force rünnakud sageli. Programm võtab ründaja IP, lisab selle pf blokeeringusse ja saadab sündmuse kesklogisse.

## Lähtefailid

| Fail | Eesmärk |
|---|---|
| `main.m` | CLI sisenemispunkt ja orkestreerimine |
| `HBPConfiguration.h/m` | Muudetavad seaded (teed, syslog, blokeerimistunnid) |
| `HBPAuthLogScanner.h/m` | Loeb authlogi ja eraldab unikaalsed ründaja IP-d |
| `HBPBlockManager.h/m` | Haldab blokifaili, registrit, aegumist ja pf-i uuestilaadimist |
| `HBPViolationScanner.h/m` | Ajaraami skanner veebirikkumiste jaoks |
| `GNUmakefile` | GNUstepi ehitusfail |

## Eeldused

Vajalikud on OpenBSD + GNUstep. `pfctl` ja `logger` on baassüsteemis olemas.

```sh
pkg_add gnustep-base
```

## Seadistus

Muuda väärtusi failis `HBPConfiguration.m` (`+defaultConfiguration`) enne ehitamist:

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

> Määra `whitelistIP` oma usaldatud administraatori IP-ks enne juurutust.

## pf.conf

`/etc/pf.conf` peab sisaldama seda tabelit:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Loo vajalikud kataloogid/failid:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Ehitus

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Kasutus

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Uued blokid logitakse tasemel `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Aegunud blokid logitakse tasemel `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Käivita rootina (vajalik `pfctl` jaoks).

## Cronjob

Näidis perioodilised kirjed käsule `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Ohud

See tööriist on teadlikult lihtne ja mustripõhine. Vaata lähtekood enne tootmises kasutamist üle, eriti `HBPConfiguration.m`. `--expire-blocks` kärbib vanad kirjed automaatselt.
