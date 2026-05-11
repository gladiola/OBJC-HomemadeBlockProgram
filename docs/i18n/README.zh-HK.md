# OBJC-HomemadeBlockProgram

這是一個給 OpenBSD 使用的 Objective-C 指令列程式，用來取代 `OpenBSDHomemadeBlockScripts` 的 shell 腳本。它會讀取 `/var/log/authlog`，擷取 SSH 暴力破解來源 IP，加入 pf 封鎖表，並把事件送到遠端 syslog。

## 目前情況

當 `sshd` 開啟時，暴力登入會反覆出現。此程式會自動封鎖來源 IP，並集中記錄。

## 原始檔案

| 檔案 | 用途 |
|---|---|
| `main.m` | CLI 入口與流程控制 |
| `HBPConfiguration.h/m` | 可調整設定（路徑、syslog、封鎖時數） |
| `HBPAuthLogScanner.h/m` | 讀取 authlog 並擷取唯一攻擊 IP |
| `HBPBlockManager.h/m` | 管理封鎖檔、ledger、到期與 pf 重新載入 |
| `HBPViolationScanner.h/m` | 具時間視窗的 Web 違規掃描 |
| `GNUmakefile` | GNUstep 建置檔 |

## 先決條件

需要 OpenBSD 與 GNUstep。`pfctl`、`logger` 已在基礎系統內。

```sh
pkg_add gnustep-base
```

## 設定

建置前請在 `HBPConfiguration.m` 的 `+defaultConfiguration` 修改：

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

> **重要：** 必須把 `whitelistIP` 設成你的管理 IP，避免誤封自己。

## pf.conf

`/etc/pf.conf` 需要包含讀取封鎖檔的表格：

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

先建立所需目錄與檔案：

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## 建置

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## 使用方式

支援模式：

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

新封鎖會以 `auth.warning` 記錄：

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

到期解除會以 `auth.info` 記錄：

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

必須以 root 執行（`pfctl` 需求）。

## Cronjob

`crontab -e` 範例：

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## 風險

此工具刻意保持簡單、以規則比對為主。部署前請先閱讀原始碼，尤其 `HBPConfiguration.m`。`--expire-blocks` 會自動清除舊條目。
