# OBJC-HomemadeBlockProgram

זהו כלי שורת פקודה ב-Objective-C עבור OpenBSD שמחליף את סקריפטי ה-shell של `OpenBSDHomemadeBlockScripts`. הוא קורא את `/var/log/authlog`, מאתר כתובות IP של תוקפי SSH ומוסיף אותן לחסימה ב-pf.

## מצב

כאשר `sshd` פעיל, מתקפות brute-force חוזרות שוב ושוב. התוכנית מחלצת את כתובת ה-IP של התוקף, מוסיפה אותה לרשימת החסימה של pf, ושולחת את האירוע ללוג מרכזי.

## קבצי מקור

| קובץ | מטרה |
|---|---|
| `main.m` | נקודת כניסה ל-CLI ותזמור |
| `HBPConfiguration.h/m` | הגדרות ניתנות לכוונון (נתיבים, syslog, שעות חסימה) |
| `HBPAuthLogScanner.h/m` | קריאת authlog וחילוץ כתובות IP ייחודיות של תוקפים |
| `HBPBlockManager.h/m` | ניהול קובץ חסימה, פנקס, תפוגה וטעינה מחדש של pf |
| `HBPViolationScanner.h/m` | סורק חלון זמן להפרות ווב |
| `GNUmakefile` | קובץ בנייה של GNUstep |

## דרישות מוקדמות

נדרשים OpenBSD ו-GNUstep. `pfctl` ו-`logger` כלולים במערכת הבסיס.

```sh
pkg_add gnustep-base
```

## תצורה

ערכו את הערכים ב-`HBPConfiguration.m` (`+defaultConfiguration`) לפני הבנייה:

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

> הגדירו `whitelistIP` לכתובת ה-IP המהימנה של המנהל לפני פריסה.

## pf.conf

`/etc/pf.conf` חייב לכלול את הטבלה הזו:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

צרו את התיקיות/הקבצים הנדרשים:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## בנייה

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## שימוש

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

חסימות חדשות נרשמות ברמת `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

חסימות שפגו נרשמות ברמת `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

יש להריץ כ-root (נדרש עבור `pfctl`).

## Cronjob

דוגמאות לערכים מחזוריים עבור `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## סיכונים

הכלי הזה פשוט במכוון ומבוסס תבניות. עברו על קוד המקור לפני שימוש בייצור, במיוחד `HBPConfiguration.m`. `--expire-blocks` מוחק רשומות ישנות אוטומטית.
