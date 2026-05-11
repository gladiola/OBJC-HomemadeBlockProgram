# OBJC-HomemadeBlockProgram

Αυτό το πρόγραμμα γραμμής εντολών Objective-C για OpenBSD αντικαθιστά τα shell scripts του `OpenBSDHomemadeBlockScripts`. Διαβάζει το `/var/log/authlog`, εντοπίζει IP επιτιθέμενων SSH και τις μπλοκάρει με pf.

## Κατάσταση

Όταν το `sshd` είναι ενεργό, οι επιθέσεις brute-force επαναλαμβάνονται συχνά. Το πρόγραμμα εντοπίζει την IP του επιτιθέμενου, την προσθέτει στη λίστα μπλοκαρίσματος pf και στέλνει το συμβάν σε κεντρικό log.

## Αρχεία πηγαίου κώδικα

| Αρχείο | Σκοπός |
|---|---|
| `main.m` | Σημείο εισόδου CLI και ενορχήστρωση |
| `HBPConfiguration.h/m` | Ρυθμίσεις που προσαρμόζονται (διαδρομές, syslog, ώρες αποκλεισμού) |
| `HBPAuthLogScanner.h/m` | Διαβάζει το authlog και εξάγει μοναδικές IP επιτιθέμενων |
| `HBPBlockManager.h/m` | Διαχείριση αρχείου αποκλεισμού, ledger, λήξης και επαναφόρτωσης pf |
| `HBPViolationScanner.h/m` | Σαρωτής χρονικού παραθύρου για παραβιάσεις ιστού |
| `GNUmakefile` | Αρχείο build GNUstep |

## Προαπαιτούμενα

Απαιτούνται OpenBSD + GNUstep. Τα `pfctl` και `logger` υπάρχουν στο βασικό σύστημα.

```sh
pkg_add gnustep-base
```

## Ρύθμιση

Επεξεργαστείτε τις τιμές στο `HBPConfiguration.m` (`+defaultConfiguration`) πριν το build:

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

> Ορίστε το `whitelistIP` στη αξιόπιστη IP διαχειριστή πριν την ανάπτυξη.

## pf.conf

Το `/etc/pf.conf` πρέπει να περιέχει αυτόν τον πίνακα:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Δημιουργήστε τα απαιτούμενα directories/files:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Δημιουργία

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Χρήση

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Τα νέα blocks καταγράφονται στο `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Τα ληγμένα blocks καταγράφονται στο `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Εκτέλεση ως root (απαιτείται από το `pfctl`).

## Cronjob

Παράδειγμα περιοδικών εγγραφών για `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Κίνδυνοι

Αυτό το εργαλείο είναι σκόπιμα απλό και βασισμένο σε μοτίβα. Ελέγξτε τον πηγαίο κώδικα πριν από χρήση σε παραγωγή, ειδικά το `HBPConfiguration.m`. Το `--expire-blocks` αφαιρεί αυτόματα παλιές εγγραφές.
