# OBJC-HomemadeBlockProgram

ይህ ለ OpenBSD የObjective-C የትእዛዝ መስመር ፕሮግራም ነው፣ `OpenBSDHomemadeBlockScripts` የshell scripts ተተኪ ነው። `/var/log/authlog` ይነብባል እና የSSH አጥቂ IP ይዘርጋል።

## ሁኔታ

`sshd` ሲነቃ የ brute-force ጥቃቶች በተደጋጋሚ ይፈጠራሉ። ፕሮግራሙ የአጥቂውን IP አድራሻ ያወጣል፣ ወደ pf የመከለከያ ዝርዝር ይጨምራል እና ክስተቱን ወደ ማዕከላዊ ሎግ ይልካል።

## የምንጭ ፋይሎች

| ፋይል | ዓላማ |
|---|---|
| `main.m` | የCLI መግቢያ እና መከናወን |
| `HBPConfiguration.h/m` | ሊቀየሩ የሚችሉ ቅንብሮች (መንገዶች፣ syslog፣ የመዝጋት ሰዓታት) |
| `HBPAuthLogScanner.h/m` | authlog ያነባል እና ልዩ የአጥቂ IP ያወጣል |
| `HBPBlockManager.h/m` | የblock ፋይል፣ ledger፣ ማብቂያ እና pf reload ያስተዳድራል |
| `HBPViolationScanner.h/m` | ለዌብ ጥሰቶች የጊዜ መስኮት ስካነር |
| `GNUmakefile` | የGNUstep build ፋይል |

## ቅድመ ሁኔታዎች

OpenBSD + GNUstep ያስፈልጋሉ። `pfctl` እና `logger` በመሠረታዊ ስርዓቱ ውስጥ አሉ።

```sh
pkg_add gnustep-base
```

## ቅንብር

ከbuild በፊት በ`HBPConfiguration.m` (`+defaultConfiguration`) ያሉ እሴቶችን ያርትዑ:

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

> ከdeployment በፊት `whitelistIP`ን ወደ የሚታመን admin IP ያቀናብሩ።

## pf.conf

`/etc/pf.conf` ይህን ሰንጠረዥ ማካተት አለበት:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

የሚያስፈልጉ ዳይሬክተሪዎች/ፋይሎችን ይፍጠሩ:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## መገንባት

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## አጠቃቀም

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

አዲስ ብሎኮች በ`auth.warning` ይመዘገባሉ:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

የጊዜ ገደብ ያለፉ ብሎኮች በ`auth.info` ይመዘገባሉ:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

እንደ root ያስኬዱ (ለ`pfctl` ያስፈልጋል).

## Cronjob

ለ`crontab -e` የወቅታዊ ግቤቶች ምሳሌ:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## አደጋዎች

ይህ መሳሪያ በተፈጥሮ ቀላል እና በpattern የተመሰረተ ነው። ከproduction ጥቅም በፊት source code ይመልከቱ፣ በተለይ `HBPConfiguration.m`። `--expire-blocks` ያረጁ ግቤቶችን በራስ-ሰር ያስወግዳል።
