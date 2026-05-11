# OBJC-HomemadeBlockProgram

هذا برنامج سطر أوامر Objective-C لنظام OpenBSD يستبدل سكربتات `OpenBSDHomemadeBlockScripts`. يقرأ `/var/log/authlog` ويستخرج عناوين IP لهجمات SSH ثم يضيفها إلى pf ويرسل السجلات إلى syslog بعيد.

## الوضع

`sshd` عند تفعيله تتكرر هجمات brute-force. يستخرج البرنامج عنوان IP للمهاجم ويضيفه إلى قائمة حظر pf ثم يرسل الحدث إلى سجل مركزي.

## ملفات المصدر

| ملف | الغرض |
|---|---|
| `main.m` | نقطة دخول CLI والتنسيق |
| `HBPConfiguration.h/m` | إعدادات قابلة للتعديل (المسارات، syslog، ساعات الحظر) |
| `HBPAuthLogScanner.h/m` | قراءة authlog واستخراج عناوين IP الفريدة للمهاجمين |
| `HBPBlockManager.h/m` | إدارة ملف الحظر والسجل والانتهاء وإعادة تحميل pf |
| `HBPViolationScanner.h/m` | ماسح نافذة زمنية لمخالفات الويب |
| `GNUmakefile` | ملف بناء GNUstep |

## المتطلبات

يتطلب OpenBSD + GNUstep. أداتا `pfctl` و`logger` موجودتان في النظام الأساسي.

```sh
pkg_add gnustep-base
```

## الإعداد

عدّل القيم في `HBPConfiguration.m` (`+defaultConfiguration`) قبل البناء:

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

> اضبط `whitelistIP` على عنوان IP الإداري الموثوق قبل النشر.

## pf.conf

يجب أن يحتوي `/etc/pf.conf` على هذا الجدول:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

أنشئ المجلدات/الملفات المطلوبة:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## البناء

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## الاستخدام

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

يتم تسجيل عمليات الحظر الجديدة عند `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

يتم تسجيل عمليات الحظر المنتهية عند `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

شغّل كـ root (مطلوب لـ `pfctl`).

## Cronjob

أمثلة لإدخالات دورية في `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## المخاطر

هذه الأداة بسيطة عمدًا وتعتمد على الأنماط. راجع الشيفرة المصدرية قبل الاستخدام الإنتاجي، خصوصًا `HBPConfiguration.m`. يقوم `--expire-blocks` بتقليم الإدخالات القديمة تلقائيًا.
