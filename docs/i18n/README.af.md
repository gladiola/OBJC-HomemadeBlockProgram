# OBJC-HomemadeBlockProgram

Hierdie Objective-C opdragreëlprogram vir OpenBSD vervang die shell-skrifte in `OpenBSDHomemadeBlockScripts`. Dit lees `/var/log/authlog`, onttrek SSH-aanvaller-IP's en blokkeer dit met pf.

## Situasie

`sshd` geaktiveer is, kom brute-force-aanvalle herhaaldelik voor. Die program haal die aanvaller se IP uit, voeg dit by die pf-bloklys en stuur die gebeurtenis na sentrale logboeke.

## Bronlêers

| Lêer | Doel |
|---|---|
| `main.m` | CLI-invoerpunt en orkestrering |
| `HBPConfiguration.h/m` | Verstelbare instellings (paaie, syslog, blok-ure) |
| `HBPAuthLogScanner.h/m` | Lees authlog en haal unieke aanvaller-IP’s uit |
| `HBPBlockManager.h/m` | Bestuur bloklêer, grootboek, verval en pf-herlaai |
| `HBPViolationScanner.h/m` | Tydvenster-skandeerder vir web-oortredings |
| `GNUmakefile` | GNUstep-boulêer |

## Vereistes

OpenBSD + GNUstep word vereis. `pfctl` en `logger` is in die basisstelsel.

```sh
pkg_add gnustep-base
```

## Konfigurasie

Wysig waardes in `HBPConfiguration.m` (`+defaultConfiguration`) voor bou:

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

> Stel `whitelistIP` op jou betroubare admin-IP voor ontplooiing.

## pf.conf

`/etc/pf.conf` moet hierdie tabel bevat:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Skep vereiste gidse/lêers:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Bou

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Gebruik

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Nuwe blokke word by `auth.warning` gelog:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Vervalde blokke word by `auth.info` gelog:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Hardloop as root (vereis deur `pfctl`).

## Cronjob

Voorbeeld periodieke inskrywings vir `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Gevare

Hierdie hulpmiddel is doelbewus eenvoudig en patroon-gebaseer. Hersien die bronkode voor produksiegebruik, veral `HBPConfiguration.m`. `--expire-blocks` snoei ou inskrywings outomaties.
