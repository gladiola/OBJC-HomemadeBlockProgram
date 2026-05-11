# OBJC-HomemadeBlockProgram

Hii ni programu ya mstari wa amri ya Objective-C kwa OpenBSD inayobadilisha skripti za `OpenBSDHomemadeBlockScripts`. Husoma `/var/log/authlog`, hupata IP za mashambulizi ya SSH na kuzizuia kwenye pf.

## Hali

`sshd` ikiwashwa, mashambulizi ya brute-force hurudiwa mara kwa mara. Programu huchukua IP ya mshambuliaji, huiweka kwenye orodha ya kuzuiwa ya pf, na kutuma tukio kwenye kumbukumbu ya kati.

## Faili za chanzo

| Faili | Madhumuni |
|---|---|
| `main.m` | Kianzio cha CLI na uratibu |
| `HBPConfiguration.h/m` | Mipangilio inayoweza kubadilishwa (njia, syslog, saa za kuzuia) |
| `HBPAuthLogScanner.h/m` | Soma authlog na toa IP za washambuliaji wa kipekee |
| `HBPBlockManager.h/m` | Dhibiti faili ya kuzuia, ledger, kuisha muda, na kupakia upya pf |
| `HBPViolationScanner.h/m` | Kichanganuzi cha dirisha la muda kwa ukiukaji wa wavuti |
| `GNUmakefile` | Faili ya kujenga GNUstep |

## Mahitaji ya awali

OpenBSD + GNUstep zinahitajika. `pfctl` na `logger` zipo kwenye mfumo wa msingi.

```sh
pkg_add gnustep-base
```

## Usanidi

Hariri thamani katika `HBPConfiguration.m` (`+defaultConfiguration`) kabla ya kujenga:

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

> Weka `whitelistIP` kwenye IP ya admin unayoamini kabla ya deployment.

## pf.conf

`/etc/pf.conf` lazima iwe na jedwali hili:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Unda saraka/faili zinazohitajika:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Ujenzi

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Matumizi

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Vizuizi vipya vinaandikwa kwenye `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Vizuizi vilivyoisha muda vinaandikwa kwenye `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Endesha kama root (inahitajika na `pfctl`).

## Cronjob

Mfano wa ingizo za mara kwa mara kwa `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Hatari

Zana hii imekusudiwa kuwa rahisi na ya kutegemea mifumo. Kagua source code kabla ya matumizi ya uzalishaji, hasa `HBPConfiguration.m`. `--expire-blocks` hupunguza ingizo za zamani kiotomatiki.
