# OBJC-HomemadeBlockProgram

He hōtaka raina-whakahau Objective-C tēnei mō OpenBSD e whakakapi ana i ngā shell script `OpenBSDHomemadeBlockScripts`. Ka pānui i `/var/log/authlog`, ka hopu i ngā IP kaikino SSH, ā, ka tāpiri ki te pf.

## Āhuatanga

Ina whakakāhia te `sshd`, ka puta tonutia ngā whakaeke brute-force. Ka tango te hōtaka i te IP kaikino, ka tāpiri ki te rārangi ārai pf, ā, ka tuku i te takahanga ki te rārangi taki matua.

## Kōnae pūtake

| Kōnae | Kaupapa |
|---|---|
| `main.m` | Tomokanga CLI me te whakarite |
| `HBPConfiguration.h/m` | Ngā tautuhinga ka taea te whakarerekē (ara, syslog, hāora ārai) |
| `HBPAuthLogScanner.h/m` | Pānui authlog ka tango i ngā IP kaikōhuru ahurei |
| `HBPBlockManager.h/m` | Whakahaere kōnae ārai, pukapuka, paunga, me te uta anō pf |
| `HBPViolationScanner.h/m` | Matawai matapihi-wā mō ngā takahitanga paetukutuku |
| `GNUmakefile` | Kōnae hanga GNUstep |

## Ngā whakaritenga

E hiahiatia ana a OpenBSD + GNUstep. Kei te pūnaha taketake kē a `pfctl` me `logger`.

```sh
pkg_add gnustep-base
```

## Whirihoranga

Whakatikahia ngā uara i `HBPConfiguration.m` (`+defaultConfiguration`) i mua i te hanga:

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

> Tautuhia `whitelistIP` ki tō IP kaiwhakahaere whakawhirinaki i mua i te tuku.

## pf.conf

Me whai tēnei ripanga i roto i `/etc/pf.conf`:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Waihangatia ngā kōpaki/kōnae e hiahiatia ana:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Hanga

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Whakamahi

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Ka rangitakina ngā ārai hou ki `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Ka rangitakina ngā ārai kua pau ki `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Whakahaerehia hei root (e hiahiatia ana e `pfctl`).

## Cronjob

Tauira tāurunga ā-ia wā mō `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Mōrea

He mea hanga māmā tēnei taputapu, he mea āhua-tauira. Arotakehia te waehere pūtake i mua i te whakamahi production, otirā `HBPConfiguration.m`. Ka tapahi aunoa a `--expire-blocks` i ngā tāurunga tawhito.
