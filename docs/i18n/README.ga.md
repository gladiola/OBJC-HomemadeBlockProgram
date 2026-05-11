# OBJC-HomemadeBlockProgram

Is clár líne ordaithe Objective-C é seo do OpenBSD a chuireann in áit na scriptí shell i `OpenBSDHomemadeBlockScripts`. Léann sé `/var/log/authlog`, aimsíonn sé IP ionsaitheoirí SSH, agus blocálann sé iad le pf.

## Staid

Nuair atá `sshd` gníomhach, tarlaíonn ionsaithe brute-force arís agus arís. Aimsíonn an clár IP an ionsaitheora, cuireann sé leis an liosta blocála pf é, agus seolann sé an eachtra chuig log lárnach.

## Comhaid foinse

| Comhad | Cuspóir |
|---|---|
| `main.m` | Pointe iontrála CLI agus comhordú |
| `HBPConfiguration.h/m` | Socruithe inchoigeartaithe (cosáin, syslog, uaireanta blocála) |
| `HBPAuthLogScanner.h/m` | Léigh authlog agus bain IPanna ionsaitheora uathúla amach |
| `HBPBlockManager.h/m` | Bainistigh comhad blocála, mórleabhar, éag agus athlódáil pf |
| `HBPViolationScanner.h/m` | Scanóir fuinneoige ama do sháruithe gréasáin |
| `GNUmakefile` | Comhad tógála GNUstep |

## Réamhriachtanais

Tá OpenBSD + GNUstep ag teastáil. Tá `pfctl` agus `logger` sa bhunchóras.

```sh
pkg_add gnustep-base
```

## Cumraíocht

Cuir luachanna in eagar i `HBPConfiguration.m` (`+defaultConfiguration`) roimh thógáil:

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

> Socraigh `whitelistIP` ar do sheoladh IP admin iontaofa roimh imscaradh.

## pf.conf

Caithfidh an tábla seo a bheith i `/etc/pf.conf`:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Cruthaigh na heolairí/comhaid riachtanacha:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Tógáil

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Úsáid

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Logáiltear blocanna nua ag `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Logáiltear blocanna as dáta ag `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Rith mar root (riachtanach do `pfctl`).

## Cronjob

Sampla iontrálacha tréimhsiúla do `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Guaisí

Tá an uirlis seo simplí d’aon ghnó agus bunaithe ar phatrúin. Déan athbhreithniú ar an gcód foinse roimh úsáid léiriúcháin, go háirithe `HBPConfiguration.m`. Gearrann `--expire-blocks` iontrálacha sean go huathoibríoch.
