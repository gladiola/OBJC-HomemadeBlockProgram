# OBJC-HomemadeBlockProgram

এটি OpenBSD-এর জন্য একটি Objective-C CLI প্রোগ্রাম, যা `OpenBSDHomemadeBlockScripts`-এর shell স্ক্রিপ্টের বিকল্প। এটি `/var/log/authlog` পড়ে SSH brute-force আক্রমণকারী IP শনাক্ত করে pf-এ ব্লক করে।

## পরিস্থিতি

`sshd` সক্রিয় থাকলে brute-force আক্রমণ বারবার ঘটে। প্রোগ্রামটি আক্রমণকারীর IP বের করে pf ব্লক তালিকায় যোগ করে এবং ঘটনাটি কেন্দ্রীয় লগে পাঠায়।

## সোর্স ফাইল

| ফাইল | উদ্দেশ্য |
|---|---|
| `main.m` | CLI এন্ট্রি ও সমন্বয় |
| `HBPConfiguration.h/m` | পরিবর্তনযোগ্য সেটিংস (পাথ, syslog, ব্লক সময়) |
| `HBPAuthLogScanner.h/m` | authlog পড়ে অনন্য আক্রমণকারী IP বের করে |
| `HBPBlockManager.h/m` | ব্লক ফাইল, লেজার, মেয়াদোত্তীর্ণ ও pf রিলোড পরিচালনা করে |
| `HBPViolationScanner.h/m` | ওয়েব লঙ্ঘনের জন্য সময়-উইন্ডো স্ক্যানার |
| `GNUmakefile` | GNUstep বিল্ড ফাইল |

## পূর্বশর্ত

OpenBSD + GNUstep প্রয়োজন। `pfctl` এবং `logger` বেস সিস্টেমেই আছে।

```sh
pkg_add gnustep-base
```

## কনফিগারেশন

বিল্ডের আগে `HBPConfiguration.m` (`+defaultConfiguration`) এ মানগুলো সম্পাদনা করুন:

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

> ডিপ্লয়ের আগে `whitelistIP` আপনার বিশ্বস্ত অ্যাডমিন IP-তে সেট করুন।

## pf.conf

`/etc/pf.conf`-এ এই টেবিলটি থাকতে হবে:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

প্রয়োজনীয় ডিরেক্টরি/ফাইল তৈরি করুন:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## বিল্ড

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## ব্যবহার

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

নতুন ব্লক `auth.warning`-এ লগ হয়:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

মেয়াদোত্তীর্ণ ব্লক `auth.info`-এ লগ হয়:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

root হিসেবে চালান (`pfctl`-এর জন্য প্রয়োজন)।

## ক্রনজব

`crontab -e`-এর জন্য পর্যায়ক্রমিক এন্ট্রির উদাহরণ:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## ঝুঁকি

এই টুলটি ইচ্ছাকৃতভাবে সহজ ও প্যাটার্ন-ভিত্তিক। প্রোডাকশনে ব্যবহারের আগে সোর্স কোড, বিশেষ করে `HBPConfiguration.m`, পর্যালোচনা করুন। `--expire-blocks` স্বয়ংক্রিয়ভাবে পুরনো এন্ট্রি ছাঁটাই করে।
