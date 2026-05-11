# OBJC-HomemadeBlockProgram

Program CLI Objective-C untuk OpenBSD ini menggantikan skrip shell `OpenBSDHomemadeBlockScripts`. Program membaca `/var/log/authlog`, mengekstrak IP penyerang SSH, memblokirnya di pf, dan mengirim log ke syslog remote.

## Situasi

Ketika `sshd` aktif, serangan brute-force terjadi berulang kali. Program mengekstrak IP penyerang, menambahkannya ke daftar blokir pf, lalu mengirim kejadian ke log terpusat.

## Berkas sumber

| Berkas | Tujuan |
|---|---|
| `main.m` | Titik masuk CLI dan orkestrasi |
| `HBPConfiguration.h/m` | Pengaturan yang dapat diubah (path, syslog, jam blokir) |
| `HBPAuthLogScanner.h/m` | Baca authlog dan ekstrak IP penyerang unik |
| `HBPBlockManager.h/m` | Kelola file blokir, ledger, kedaluwarsa, dan reload pf |
| `HBPViolationScanner.h/m` | Pemindai jendela waktu untuk pelanggaran web |
| `GNUmakefile` | Berkas build GNUstep |

## Prasyarat

OpenBSD + GNUstep diperlukan. `pfctl` dan `logger` ada di sistem dasar.

```sh
pkg_add gnustep-base
```

## Konfigurasi

Edit nilai di `HBPConfiguration.m` (`+defaultConfiguration`) sebelum build:

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

> Setel `whitelistIP` ke IP admin tepercaya Anda sebelum deployment.

## pf.conf

`/etc/pf.conf` harus berisi tabel ini:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Buat direktori/file yang diperlukan:

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

## Penggunaan

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Blok baru dicatat pada `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Blok kedaluwarsa dicatat pada `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Jalankan sebagai root (diperlukan oleh `pfctl`).

## Cronjob

Contoh entri berkala untuk `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Risiko

Alat ini sengaja dibuat sederhana dan berbasis pola. Tinjau source code sebelum penggunaan produksi, terutama `HBPConfiguration.m`. `--expire-blocks` memangkas entri lama secara otomatis.
