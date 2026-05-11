# OBJC-HomemadeBlockProgram

Program command-line Objective-C iki kanggo OpenBSD ngganti skrip shell `OpenBSDHomemadeBlockScripts`. Program maca `/var/log/authlog`, njupuk IP panyerang SSH, banjur mblokir nganggo pf.

## Kahanan

Nalika `sshd` aktif, serangan brute-force kerep bola-bali. Program iki njupuk IP panyerang, nambahake menyang dhaptar blokir pf, lan ngirim kedadeyan menyang log pusat.

## Berkas sumber

| Berkas | Tujuan |
|---|---|
| `main.m` | Titik mlebu CLI lan orkestrasi |
| `HBPConfiguration.h/m` | Setelan sing bisa diatur (path, syslog, jam blokir) |
| `HBPAuthLogScanner.h/m` | Maca authlog lan njupuk IP panyerang sing unik |
| `HBPBlockManager.h/m` | Ngatur berkas blokir, ledger, kadaluwarsa, lan reload pf |
| `HBPViolationScanner.h/m` | Pemindai jendhela wektu kanggo pelanggaran web |
| `GNUmakefile` | Berkas build GNUstep |

## Prasyarat

OpenBSD + GNUstep dibutuhake. `pfctl` lan `logger` wis ana ing sistem dhasar.

```sh
pkg_add gnustep-base
```

## Konfigurasi

Owahi nilai ing `HBPConfiguration.m` (`+defaultConfiguration`) sadurunge build:

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

> Setel `whitelistIP` menyang IP admin sing dipercaya sadurunge deployment.

## pf.conf

`/etc/pf.conf` kudu ngemot tabel iki:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Gawe direktori/berkas sing dibutuhake:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Build

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Panggunaan

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Blok anyar dicathet ing `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Blok sing kadaluwarsa dicathet ing `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Jalanké minangka root (dibutuhake dening `pfctl`).

## Cronjob

Tuladha entri periodik kanggo `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Bebaya

Alat iki sengaja digawe prasaja lan adhedhasar pola. Delengen source code sadurunge digunakake ing production, utamane `HBPConfiguration.m`. `--expire-blocks` motong entri lawas kanthi otomatis.
