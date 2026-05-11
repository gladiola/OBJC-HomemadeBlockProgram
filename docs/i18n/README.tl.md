# OBJC-HomemadeBlockProgram

Ang Objective-C command-line program na ito para sa OpenBSD ay kapalit ng shell scripts sa `OpenBSDHomemadeBlockScripts`. Binabasa nito ang `/var/log/authlog`, kinukuha ang SSH attacker IP, at binablock sa pf.

## Sitwasyon

Kapag aktibo ang `sshd`, paulit-ulit ang brute-force attack. Kinukuha ng programa ang IP ng umaatake, inilalagay sa pf block list, at ipinapadala ang event sa sentralisadong log.

## Mga source file

| File | Layunin |
|---|---|
| `main.m` | Punto ng pasok ng CLI at orkestrasyon |
| `HBPConfiguration.h/m` | Mga naiaayos na setting (paths, syslog, oras ng block) |
| `HBPAuthLogScanner.h/m` | Binabasa ang authlog at kinukuha ang natatanging attacker IP |
| `HBPBlockManager.h/m` | Pamahalaan ang block file, ledger, expiry, at pf reload |
| `HBPViolationScanner.h/m` | Scanner ng time-window para sa web violations |
| `GNUmakefile` | Build file ng GNUstep |

## Mga kinakailangan

Kailangan ang OpenBSD + GNUstep. Nasa base system na ang `pfctl` at `logger`.

```sh
pkg_add gnustep-base
```

## Konpigurasyon

I-edit ang mga value sa `HBPConfiguration.m` (`+defaultConfiguration`) bago mag-build:

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

> Itakda ang `whitelistIP` sa pinagkakatiwalaang admin IP bago i-deploy.

## pf.conf

Dapat may ganitong table ang `/etc/pf.conf`:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Gawin ang kinakailangang directories/files:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Pagbuo

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Paggamit

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Ang mga bagong block ay nilolog sa `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Ang mga nag-expire na block ay nilolog sa `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Patakbuhin bilang root (kailangan ng `pfctl`).

## Cronjob

Halimbawa ng periodic entries para sa `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Mga panganib

Sadyang simple at pattern-based ang tool na ito. Suriin ang source code bago gamitin sa production, lalo na ang `HBPConfiguration.m`. Awtomatikong nagpu-prune ng lumang entries ang `--expire-blocks`.
