# OBJC-HomemadeBlockProgram — Bahasa Melayu

Ini ialah program baris arahan Objective-C untuk OpenBSD yang menyekat IP penyerang daripada log dan menamatkan sekatan lama.

Arahan penggunaan setempat disediakan di bawah; README bahasa Inggeris penuh disertakan untuk pariti penuh.

## Localized usage directions

- `pf-blocker --monitor-invalid-user`  
  Sekat IP yang dilihat dalam entri log sshd "Invalid user".
- `pf-blocker --monitor-disconnect`  
  Sekat IP yang dilihat dalam entri log sshd "Received disconnect from".
- `pf-blocker --monitor-allowlist-violations`  
  Sekat IP yang melepasi ambang pelanggaran allowlist web dalam tetingkap yang ditetapkan.
- `pf-blocker --monitor-slowloris-violations`  
  Import IP yang ditanda oleh pengesan Slowloris ke ledger blocker.
- `pf-blocker --monitor-ddos`  
  Import IP yang ditanda oleh pengesan DDoS ke ledger blocker.
- `pf-blocker --expire-blocks`  
  Buang sekatan lama daripada fail sekatan dan ledger.

## Full-parity English reference

The full English README is included below for complete parity with the source document.

---

# OBJC-HomemadeBlockProgram

An Objective-C command-line program for OpenBSD that replaces the shell
scripts in
[gladiola/OpenBSDHomemadeBlockScripts](https://github.com/gladiola/OpenBSDHomemadeBlockScripts).
It reads `/var/log/authlog`, extracts attacker IPs from SSH brute-force
attempts, adds them to a pf block table for immediate blocking, and logs each
event to a remote syslog server.  A separate mode expires blocks after a
configurable number of hours.

---

## Situation

`sshd` is enabled.  Log entries and HIDS show that SSH is repeatedly subjected
to brute-force attacks.  This program responds automatically: extract the
offending IP, append it to the pf block file and a ledger, reload the live pf
table, and ship an `auth.warning` syslog message to a remote log server so
attackers are centrally recorded.

---

## Source files

| File | Purpose |
|------|---------|
| `main.m` | CLI entry point — argument parsing and orchestration |
| `HBPConfiguration.h/m` | All tunable settings (paths, syslog host, block hours, …) |
| `HBPAuthLogScanner.h/m` | Reads authlog and extracts unique attacker IPs |
| `HBPBlockManager.h/m` | Manages the block file, ledger, expiry, and pf reload |
| `HBPViolationScanner.h/m` | Timestamp-aware scanner for web-violation logs (allowlisting & Slowloris) |
| `GNUmakefile` | GNUstep build file |

---

## Prerequisites

The program is written for OpenBSD with GNUstep.  No other packages are
required at runtime — `pfctl` and `logger` are both part of the base system.

Install the GNUstep runtime (one-time setup):

```sh
pkg_add gnustep-base
```

---

## Configuration

Open `HBPConfiguration.m` and edit the values in `+defaultConfiguration`
before building:

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

> **⚠ Important — set `whitelistIP` before deploying.**  Replace the
> placeholder `www.xxx.yyy.zzz` with your actual management or admin IP
> address.  Any log line containing that address is skipped entirely, so you
> cannot accidentally block yourself.  If you forget, the program will log a
> warning each run but will proceed without any whitelist protection.

The remaining paths (`blockFile`, `ledgerFile`, `pfTableName`, …) match the
defaults used by the companion shell scripts and rarely need changing.

---

## pf.conf

`/etc/pf.conf` must contain a table that reads from the block file.  Keep (or
create) the same table the shell scripts used:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Create the required directories and files before running the program:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

---

## Building

Install GNUstep (one-time, if not already present):

```sh
pkg_add gnustep-base
```

Then build and install:

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

The `Makefile` uses `gnustep-config` to obtain the correct compiler and linker
flags automatically, so no environment sourcing is required.

---

## Usage

```
pf-blocker --monitor-invalid-user
    Block IPs seen in sshd "Invalid user" log entries.

pf-blocker --monitor-disconnect
    Block IPs seen in sshd "Received disconnect from" log entries.

pf-blocker --monitor-allowlist-violations
    Block IPs that have violated the CGI allowlist (OBJC-allowlisting /
    request_validator) webViolationThreshold or more times within the past
    webViolationWindowHours hours.  Reads /var/log/authlog.

pf-blocker --monitor-slowloris-violations
    Bring IPs already flagged by the Slowloris detector (OBJC-slowlorisdetector /
    SlowlorisMonitor) into the HBP ledger.  This lets --expire-blocks manage
    their lifetime alongside SSH blocks.  Reads /var/log/daemon.
    Because SlowlorisMonitor logs one line per detection run, a threshold of 1
    (one appearance within the window) is effectively "block on first detection";
    raise webViolationThreshold if you prefer to wait for repeated detections.

pf-blocker --monitor-ddos
    Bring IPs already flagged by the DDoS detector (OpenBSDDDOSShield /
    DDOSShield) into the HBP ledger.  This lets --expire-blocks manage their
    lifetime alongside SSH blocks.  Reads /var/log/daemon.
    DDOSShield logs one line per detection event, so a threshold of 1 blocks
    on first detection; raise webViolationThreshold to require repeated events.

pf-blocker --expire-blocks
    Remove blocks older than BLOCK_HOURS from the block file and ledger.
```

Each newly blocked IP is logged to the configured remote syslog server at
`auth.warning` priority:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Each expired block is logged at `auth.info` priority:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

The program must be run as root (required for `pfctl`).

---

## Cronjob

Add entries to root's crontab (`crontab -e`) to run the program periodically,
for example every 5 minutes for blocking and every hour for expiry:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

---

## Hazards

This program is a direct translation of the original primitive shell scripts.
It makes simple pattern-based decisions and is less than 300 lines of logic.
Read and understand the source — especially `HBPConfiguration.m` — before
deploying it.

Replace `www.xxx.yyy.zzz` in `HBPConfiguration.m` with a trusted IP you
never want to block (e.g. your own management address).  Any log line that
contains that address is skipped entirely.

Over time the block table grows proportionally to the attack rate and
`blockHours`.  The `--expire-blocks` mode prunes old entries automatically, so
manual intervention is only needed if you want to release a specific IP sooner
than the configured expiry time.

OpenBSD ships with `sshguard` available in packages and its own `pf` log
analysis tools; this program is a lightweight alternative for environments
where simplicity is preferred over sophistication.
