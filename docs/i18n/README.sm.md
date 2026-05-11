# OBJC-HomemadeBlockProgram

O lenei polokalame Objective-C mo OpenBSD e sui ai shell script `OpenBSDHomemadeBlockScripts`. E faitau `/var/log/authlog`, maua ai IP o osofaiga SSH, ma poloka i le pf.

## Tulaga

A ola `sshd`, e toe faia pea osofaʻiga brute-force. E ave e le polokalame le IP o le tagata osofaʻi, faapipiʻi i le lisi poloka pf, ma lafo le mea na tupu i log autū.

## Faila puna

| Faila | Faamoemoega |
|---|---|
| `main.m` | Ulufalega CLI ma le faagasologa |
| `HBPConfiguration.h/m` | Faiga e mafai ona suia (ala, syslog, itula poloka) |
| `HBPAuthLogScanner.h/m` | Faitau authlog ma aveese IP osofaʻi eseese |
| `HBPBlockManager.h/m` | Pulea faila poloka, ledger, muta ma toe uta pf |
| `HBPViolationScanner.h/m` | Suʻesuʻe taimi mo soligatulafono i le upega |
| `GNUmakefile` | Faila fau GNUstep |

## Manaʻoga muamua

E manaʻomia OpenBSD + GNUstep. `pfctl` ma `logger` o loo i le faiga autu.

```sh
pkg_add gnustep-base
```

## Faatulagaga

Faasaʻo tau i `HBPConfiguration.m` (`+defaultConfiguration`) aʻo leʻi fauina:

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

> Seti `whitelistIP` i lau admin IP faatuatuaina aʻo leʻi faapipiiina.

## pf.conf

E tatau ona iai lenei laulau i le `/etc/pf.conf`:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Fausia faila ma faila-lava e manaʻomia:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Fausiaina

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Faʻaogaina

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

O poloka fou e tusia i `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

O poloka ua muta e tusia i `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Tamoʻe o root (e manaʻomia e `pfctl`).

## Cronjob

Faataʻitaʻiga o ulufale taamilosaga mo `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Lamatiaga

Ua fuafuaina lenei meafaigaluega e faigofie ma faavae i mamanu. Iloilo le source code aʻo leʻi faaaoga i le production, aemaise `HBPConfiguration.m`. `--expire-blocks` e aveese ulufale tuai otometi.
