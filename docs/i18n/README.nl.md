# OBJC-HomemadeBlockProgram

Dit Objective-C commandoregelprogramma voor OpenBSD vervangt de shellscripts van `OpenBSDHomemadeBlockScripts`. Het leest `/var/log/authlog`, haalt aanvallende SSH-IP's eruit en blokkeert ze in pf.

## Situatie

Wanneer `sshd` actief is, komen brute-force-aanvallen herhaaldelijk voor. Het programma haalt het aanvallers-IP op, zet het in de pf-blokkeerlijst en stuurt het event naar centrale logging.

## Bronbestanden

| Bestand | Doel |
|---|---|
| `main.m` | CLI-ingang en orkestratie |
| `HBPConfiguration.h/m` | Aanpasbare instellingen (paden, syslog, blokuren) |
| `HBPAuthLogScanner.h/m` | Lees authlog en haal unieke aanvaller-IP’s eruit |
| `HBPBlockManager.h/m` | Beheer blokbestand, logboek, verval en pf-herladen |
| `HBPViolationScanner.h/m` | Tijdvenster-scanner voor webovertredingen |
| `GNUmakefile` | GNUstep-buildbestand |

## Vereisten

OpenBSD + GNUstep zijn vereist. `pfctl` en `logger` zitten in het basissysteem.

```sh
pkg_add gnustep-base
```

## Configuratie

Bewerk waarden in `HBPConfiguration.m` (`+defaultConfiguration`) vóór het bouwen:

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

> Stel `whitelistIP` in op je vertrouwde beheer-IP vóór uitrol.

## pf.conf

`/etc/pf.conf` moet deze tabel bevatten:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Maak vereiste mappen/bestanden aan:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Bouwen

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

Nieuwe blokkades worden gelogd op `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Verlopen blokkades worden gelogd op `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Draai als root (vereist door `pfctl`).

## Cronjob

Voorbeeld periodieke regels voor `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Risico’s

Deze tool is bewust eenvoudig en patroongebaseerd. Controleer de broncode vóór productiegebruik, vooral `HBPConfiguration.m`. `--expire-blocks` ruimt oude regels automatisch op.
