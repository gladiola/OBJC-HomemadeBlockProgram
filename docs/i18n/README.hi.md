# OBJC-HomemadeBlockProgram

यह OpenBSD के लिए Objective-C CLI प्रोग्राम है जो `OpenBSDHomemadeBlockScripts` की जगह लेता है। यह `/var/log/authlog` से SSH brute-force IP निकालकर pf में ब्लॉक करता है और remote syslog पर लॉग भेजता है.

## स्थिति

जब `sshd` सक्रिय होता है, brute-force हमले बार-बार होते हैं। प्रोग्राम हमलावर का IP निकालकर pf ब्लॉक सूची में जोड़ता है और घटना को केंद्रीकृत लॉग में भेजता है।

## स्रोत फ़ाइलें

| फ़ाइल | उद्देश्य |
|---|---|
| `main.m` | CLI प्रवेश बिंदु और समन्वयन |
| `HBPConfiguration.h/m` | समायोज्य सेटिंग्स (पाथ, syslog, ब्लॉक घंटे) |
| `HBPAuthLogScanner.h/m` | authlog पढ़ें और अद्वितीय हमलावर IP निकालें |
| `HBPBlockManager.h/m` | ब्लॉक फ़ाइल, लेजर, अवधि समाप्ति और pf रीलोड प्रबंधित करें |
| `HBPViolationScanner.h/m` | वेब उल्लंघनों के लिए समय-विंडो स्कैनर |
| `GNUmakefile` | GNUstep बिल्ड फ़ाइल |

## पूर्वापेक्षाएँ

OpenBSD + GNUstep आवश्यक हैं। `pfctl` और `logger` बेस सिस्टम में मौजूद हैं।

```sh
pkg_add gnustep-base
```

## कॉन्फ़िगरेशन

बिल्ड से पहले `HBPConfiguration.m` (`+defaultConfiguration`) में मान संपादित करें:

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

> डिप्लॉयमेंट से पहले `whitelistIP` को अपने विश्वसनीय एडमिन IP पर सेट करें।

## pf.conf

`/etc/pf.conf` में यह तालिका होनी चाहिए:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

आवश्यक डाइरेक्टरी/फ़ाइलें बनाएँ:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## निर्माण

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## उपयोग

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

नए ब्लॉक `auth.warning` पर लॉग होते हैं:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

समाप्त ब्लॉक `auth.info` पर लॉग होते हैं:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

रूट के रूप में चलाएँ (`pfctl` के लिए आवश्यक)।

## क्रॉनजॉब

`crontab -e` के लिए आवधिक प्रविष्टियों का उदाहरण:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## जोखिम

यह टूल जानबूझकर सरल और पैटर्न-आधारित है। प्रोडक्शन उपयोग से पहले सोर्स कोड की समीक्षा करें, विशेषकर `HBPConfiguration.m`। `--expire-blocks` पुरानी प्रविष्टियाँ अपने-आप हटाता है।
