# OBJC-HomemadeBlockProgram

โปรแกรมบรรทัดคำสั่ง Objective-C สำหรับ OpenBSD นี้ใช้แทนสคริปต์เชลล์ `OpenBSDHomemadeBlockScripts` โดยอ่าน `/var/log/authlog` ดึง IP ผู้โจมตี SSH แล้วบล็อกผ่าน pf.

## สถานการณ์

เมื่อเปิดใช้งาน `sshd` มักมีการโจมตีแบบ brute-force ซ้ำ ๆ โปรแกรมจะดึง IP ของผู้โจมตี ใส่ในรายการบล็อกของ pf และส่งเหตุการณ์ไปยังระบบบันทึกส่วนกลาง。

## ไฟล์ซอร์ส

| ไฟล์ | วัตถุประสงค์ |
|---|---|
| `main.m` | จุดเริ่มต้น CLI และการประสานงาน |
| `HBPConfiguration.h/m` | การตั้งค่าที่ปรับได้ (พาธ, syslog, ชั่วโมงบล็อก) |
| `HBPAuthLogScanner.h/m` | อ่าน authlog และแยก IP ผู้โจมตีที่ไม่ซ้ำ |
| `HBPBlockManager.h/m` | จัดการไฟล์บล็อก, ledger, การหมดอายุ และรีโหลด pf |
| `HBPViolationScanner.h/m` | ตัวสแกนช่วงเวลาสำหรับการละเมิดเว็บ |
| `GNUmakefile` | ไฟล์บิลด์ GNUstep |

## ข้อกำหนดเบื้องต้น

ต้องใช้ OpenBSD + GNUstep โดย `pfctl` และ `logger` มีอยู่ในระบบพื้นฐานแล้ว

```sh
pkg_add gnustep-base
```

## การตั้งค่า

แก้ไขค่าใน `HBPConfiguration.m` (`+defaultConfiguration`) ก่อนบิลด์:

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

> ตั้งค่า `whitelistIP` เป็น IP ผู้ดูแลที่เชื่อถือได้ก่อนนำขึ้นใช้งานจริง

## pf.conf

`/etc/pf.conf` ต้องมีตารางนี้:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

สร้างไดเรกทอรี/ไฟล์ที่จำเป็น:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## การสร้าง

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## การใช้งาน

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

บล็อกใหม่จะถูกบันทึกที่ `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

บล็อกที่หมดอายุจะถูกบันทึกที่ `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

รันด้วยสิทธิ root (จำเป็นสำหรับ `pfctl`)

## Cronjob

ตัวอย่างรายการแบบกำหนดเวลาใน `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## ความเสี่ยง

เครื่องมือนี้ถูกออกแบบให้เรียบง่ายและอิงรูปแบบ ควรตรวจสอบซอร์สโค้ดก่อนใช้งานจริง โดยเฉพาะ `HBPConfiguration.m` และ `--expire-blocks` จะลบรายการเก่าอัตโนมัติ
