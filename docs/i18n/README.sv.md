# OBJC-HomemadeBlockProgram

Detta Objective-C-kommandoradsprogram för OpenBSD ersätter shellskripten i `OpenBSDHomemadeBlockScripts`. Det läser `/var/log/authlog`, hittar SSH-angripar-IP och blockerar dem via pf.

## Situation

När `sshd` är aktivt sker brute-force-attacker upprepade gånger. Programmet hämtar angriparens IP, lägger den i pf-blocklistan och skickar händelsen till central loggning.

## Källfiler

| Fil | Syfte |
|---|---|
| `main.m` | CLI-startpunkt och orkestrering |
| `HBPConfiguration.h/m` | Justerbara inställningar (sökvägar, syslog, blocktimmar) |
| `HBPAuthLogScanner.h/m` | Läser authlog och extraherar unika angripar-IP |
| `HBPBlockManager.h/m` | Hanterar blockfil, journal, utgång och pf-omladdning |
| `HBPViolationScanner.h/m` | Tidsfönsterskanner för webböverträdelser |
| `GNUmakefile` | Byggfil för GNUstep |

## Förkrav

OpenBSD + GNUstep krävs. `pfctl` och `logger` ingår i bassystemet.

```sh
pkg_add gnustep-base
```

## Konfiguration

Redigera värden i `HBPConfiguration.m` (`+defaultConfiguration`) före byggning:

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

> Sätt `whitelistIP` till din betrodda admin-IP före driftsättning.

## pf.conf

`/etc/pf.conf` måste innehålla denna tabell:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Skapa nödvändiga kataloger/filer:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Bygg

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Användning

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Nya blockeringar loggas på `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Utgångna blockeringar loggas på `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Kör som root (krävs av `pfctl`).

## Cronjob

Exempel på periodiska poster för `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Risker

Detta verktyg är avsiktligt enkelt och mönsterbaserat. Granska källkoden före produktionsbruk, särskilt `HBPConfiguration.m`. `--expire-blocks` rensar gamla poster automatiskt.
