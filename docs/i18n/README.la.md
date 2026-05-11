# OBJC-HomemadeBlockProgram

Hoc programma lineae mandatorum Objective-C pro OpenBSD substituit scripta shell `OpenBSDHomemadeBlockScripts`. Legit `/var/log/authlog`, IP oppugnantium SSH extrahit, et in pf tabula claudit.

## Status

Cum `sshd` activum est, impetus brute-force saepe repetuntur. Programma IP oppugnantis extrahit, in tabulam pf claudit, et eventum ad log centralem mittit.

## Fontes

| Fasciculus | Propositum |
|---|---|
| `main.m` | Ingressus CLI et ordinatio |
| `HBPConfiguration.h/m` | Optiones aptabiles (viae, syslog, horae clausurae) |
| `HBPAuthLogScanner.h/m` | Authlog legit et IP oppugnatorum unicos extrahit |
| `HBPBlockManager.h/m` | Fasciculum clausurae, rationarium, expirationem et pf re-onerat |
| `HBPViolationScanner.h/m` | Scrutator fenestrae temporis pro violationibus interretialibus |
| `GNUmakefile` | Fasciculus aedificationis GNUstep |

## Praerequisita

OpenBSD + GNUstep requiruntur. `pfctl` et `logger` in systemate basi sunt.

```sh
pkg_add gnustep-base
```

## Configuratio

Valores in `HBPConfiguration.m` (`+defaultConfiguration`) ante aedificationem muta:

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

> `whitelistIP` ad IP administratoris fidelem ante deployment constitue.

## pf.conf

`/etc/pf.conf` hanc tabulam continere debet:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Directorias/fasciculos necessarios crea:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Aedificatio

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Usus

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Novae clausurae ad `auth.warning` referuntur:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Clausurae expiratae ad `auth.info` referuntur:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Ut root currat (a `pfctl` requiritur).

## Cronjob

Exempla inscriptionum periodicorum pro `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Pericula

Hoc instrumentum consulto simplex et ex formis est. Codicem fontis ante usum productionis perlege, praesertim `HBPConfiguration.m`. `--expire-blocks` inscriptiones veteres automatice putat.
