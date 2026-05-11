# OBJC-HomemadeBlockProgram

Dette Objective-C-kommandolinjeprogrammet for OpenBSD erstatter shellskriptene i `OpenBSDHomemadeBlockScripts`. Det leser `/var/log/authlog`, finner SSH-angriper-IP-er og blokkerer dem i pf.

## Situasjon

Når `sshd` er aktiv, skjer brute-force-angrep gjentatte ganger. Programmet henter angriperens IP, legger den i pf-blokklisten og sender hendelsen til sentral logging.

## Kildefiler

| Fil | Formål |
|---|---|
| `main.m` | CLI-inngang og orkestrering |
| `HBPConfiguration.h/m` | Justerbare innstillinger (stier, syslog, blokktimer) |
| `HBPAuthLogScanner.h/m` | Les authlog og hent ut unike angriper-IP-er |
| `HBPBlockManager.h/m` | Håndter blokkfil, logg, utløp og pf-omlasting |
| `HBPViolationScanner.h/m` | Tidsvindu-skanner for webbrudd |
| `GNUmakefile` | GNUstep-byggefil |

## Forutsetninger

OpenBSD + GNUstep er påkrevd. `pfctl` og `logger` finnes i basissystemet.

```sh
pkg_add gnustep-base
```

## Konfigurasjon

Rediger verdier i `HBPConfiguration.m` (`+defaultConfiguration`) før bygging:

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

> Sett `whitelistIP` til din betrodde admin-IP før utrulling.

## pf.conf

`/etc/pf.conf` må inneholde denne tabellen:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Opprett nødvendige kataloger/filer:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Bygging

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Bruk

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Nye blokker logges på `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Utløpte blokker logges på `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Kjør som root (kreves av `pfctl`).

## Cronjob

Eksempel på periodiske oppføringer for `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Risiko

Dette verktøyet er bevisst enkelt og mønsterbasert. Gå gjennom kildekoden før produksjonsbruk, spesielt `HBPConfiguration.m`. `--expire-blocks` rydder automatisk gamle oppføringer.
