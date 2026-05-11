# OBJC-HomemadeBlockProgram

Tämä Objective-C-komentoriviohjelma OpenBSD:lle korvaa `OpenBSDHomemadeBlockScripts`-shell-skriptit. Se lukee `/var/log/authlog`, poimii SSH-hyökkääjien IP:t ja lisää ne pf-estolistaan.

## Tilanne

Kun `sshd` on käytössä, brute-force-hyökkäyksiä tapahtuu toistuvasti. Ohjelma poimii hyökkääjän IP-osoitteen, lisää sen pf-estolistaan ja lähettää tapahtuman keskitettyyn lokiin.

## Lähdetiedostot

| Tiedosto | Tarkoitus |
|---|---|
| `main.m` | CLI-sisääntulo ja orkestrointi |
| `HBPConfiguration.h/m` | Säädettävät asetukset (polut, syslog, estotunnit) |
| `HBPAuthLogScanner.h/m` | Lukee authlogin ja poimii yksilölliset hyökkääjä-IP:t |
| `HBPBlockManager.h/m` | Hallitsee estotiedostoa, kirjanpitoa, vanhenemista ja pf-uudelleenlatausta |
| `HBPViolationScanner.h/m` | Aikaikkunaskanneri verkkorikkomuksille |
| `GNUmakefile` | GNUstepin build-tiedosto |

## Vaatimukset

OpenBSD + GNUstep vaaditaan. `pfctl` ja `logger` ovat perusjärjestelmässä.

```sh
pkg_add gnustep-base
```

## Määritys

Muokkaa `HBPConfiguration.m`-tiedoston (`+defaultConfiguration`) arvoja ennen buildiä:

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

> Aseta `whitelistIP` luotettuun ylläpitäjän IP-osoitteeseen ennen käyttöönottoa.

## pf.conf

`/etc/pf.conf`-tiedoston täytyy sisältää tämä taulu:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Luo tarvittavat hakemistot/tiedostot:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Kääntäminen

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Käyttö

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Uudet estot kirjataan tasolla `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Vanhentuneet estot kirjataan tasolla `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Aja rootina (`pfctl` vaatii tämän).

## Cronjob

Esimerkki ajastetuista riveistä `crontab -e`:lle:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Riskit

Tämä työkalu on tarkoituksella yksinkertainen ja sääntöpohjainen. Tarkista lähdekoodi ennen tuotantokäyttöä, erityisesti `HBPConfiguration.m`. `--expire-blocks` karsii vanhat rivit automaattisesti.
