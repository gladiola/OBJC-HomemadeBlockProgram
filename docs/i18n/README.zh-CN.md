# OBJC-HomemadeBlockProgram

这是一个用于 OpenBSD 的 Objective-C 命令行程序，用来替代 `OpenBSDHomemadeBlockScripts`。它读取 `/var/log/authlog`，提取 SSH 暴力破解来源 IP，写入 pf 封禁表并发送到远程 syslog。

## 现状

当 `sshd` 启用时，SSH 暴力破解会反复出现。程序会提取攻击源 IP、写入 pf 封禁列表，并将事件发送到集中日志。

## 源码文件

| 文件 | 用途 |
|---|---|
| `main.m` | CLI 入口与流程编排 |
| `HBPConfiguration.h/m` | 可调参数（路径、syslog、封禁时长） |
| `HBPAuthLogScanner.h/m` | 读取 authlog 并提取唯一攻击者 IP |
| `HBPBlockManager.h/m` | 管理封禁文件、账本、过期与 pf 重载 |
| `HBPViolationScanner.h/m` | 用于 Web 违规的时间窗口扫描器 |
| `GNUmakefile` | GNUstep 构建文件 |

## 前置条件

需要 OpenBSD + GNUstep。`pfctl` 和 `logger` 已包含在基础系统中。

```sh
pkg_add gnustep-base
```

## 配置

构建前请在 `HBPConfiguration.m`（`+defaultConfiguration`）中修改参数：

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

> 部署前请将 `whitelistIP` 设为受信任的管理员 IP。

## pf.conf

`/etc/pf.conf` 必须包含此表：

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

创建所需目录/文件：

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## 构建

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## 用法

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

新封禁会记录到 `auth.warning`：

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

过期封禁会记录到 `auth.info`：

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

请以 root 运行（`pfctl` 需要）。

## Cronjob

`crontab -e` 的周期任务示例：

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## 风险

该工具有意保持简单并基于模式匹配。生产使用前请先审阅源码，尤其是 `HBPConfiguration.m`。`--expire-blocks` 会自动清理旧记录。
