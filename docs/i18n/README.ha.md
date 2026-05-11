# OBJC-HomemadeBlockProgram

Wannan shirin layin umarni na Objective-C ga OpenBSD yana maye gurbin shell scripts na `OpenBSDHomemadeBlockScripts`. Yana karanta `/var/log/authlog`, gano IP na harin SSH, sannan ya toshe su ta pf.

## Hali

Idan `sshd` yana aiki, hare-haren brute-force suna maimaituwa. Shirin yana cire IP na mai hari, yana ƙara shi cikin jerin toshewar pf, sannan yana aika abin da ya faru zuwa log na tsakiya.

## Fayilolin tushe

| Fayil | Manufa |
|---|---|
| `main.m` | Shigarwar CLI da tsara aiki |
| `HBPConfiguration.h/m` | Saituna masu daidaitawa (hanyoyi, syslog, awannin toshewa) |
| `HBPAuthLogScanner.h/m` | Karanta authlog ka fitar da IP na maharan na musamman |
| `HBPBlockManager.h/m` | Sarrafa fayil din toshewa, ledger, karewa, da sake loda pf |
| `HBPViolationScanner.h/m` | Na’urar duba taga-lokaci don karya dokokin yanar gizo |
| `GNUmakefile` | Fayil din gina GNUstep |

## Abubuwan da ake bukata

Ana bukatar OpenBSD + GNUstep. `pfctl` da `logger` suna cikin tsarin asali.

```sh
pkg_add gnustep-base
```

## Saiti

Gyara ƙimomi a `HBPConfiguration.m` (`+defaultConfiguration`) kafin gini:

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

> Saita `whitelistIP` zuwa amintaccen admin IP kafin deployment.

## pf.conf

`/etc/pf.conf` dole ne ya kunshi wannan tebur:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Ƙirƙiri manyan fayiloli/fayilolin da ake bukata:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Gini

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Amfani

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Ana rubuta sabbin toshewa a `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Ana rubuta toshewar da suka ƙare a `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Gudanar da shi a matsayin root (ana bukata ga `pfctl`).

## Cronjob

Misalin shigarwar lokaci-lokaci na `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Haɗari

An ƙera wannan kayan aiki da sauƙi kuma yana dogara da tsari. Duba source code kafin amfani a production, musamman `HBPConfiguration.m`. `--expire-blocks` yana cire tsoffin shigarwa ta atomatik.
