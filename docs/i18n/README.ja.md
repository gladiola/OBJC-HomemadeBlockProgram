# OBJC-HomemadeBlockProgram

これは OpenBSD 向けの Objective-C CLI で、`OpenBSDHomemadeBlockScripts` を置き換えます。`/var/log/authlog` から SSH 攻撃 IP を抽出し、pf で即時ブロックしてリモート syslog に送信します。

## 状況

`sshd` が有効な環境では、SSH の総当たり攻撃が繰り返し発生します。プログラムは攻撃元 IP を抽出して pf のブロック一覧へ追加し、イベントを集中ログへ送ります。

## ソースファイル

| ファイル | 目的 |
|---|---|
| `main.m` | CLI エントリーポイントと制御 |
| `HBPConfiguration.h/m` | 調整可能な設定（パス、syslog、ブロック時間） |
| `HBPAuthLogScanner.h/m` | authlog を読み取り、重複しない攻撃元 IP を抽出 |
| `HBPBlockManager.h/m` | ブロックファイル、台帳、有効期限、pf 再読み込みを管理 |
| `HBPViolationScanner.h/m` | Web 違反向けの時間ウィンドウスキャナ |
| `GNUmakefile` | GNUstep ビルドファイル |

## 前提条件

OpenBSD + GNUstep が必要です。`pfctl` と `logger` はベースシステムに含まれます。

```sh
pkg_add gnustep-base
```

## 設定

ビルド前に `HBPConfiguration.m`（`+defaultConfiguration`）の値を編集してください:

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

> デプロイ前に `whitelistIP` を信頼できる管理者 IP に設定してください。

## pf.conf

`/etc/pf.conf` にはこのテーブルを含める必要があります:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

必要なディレクトリ/ファイルを作成します:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## ビルド

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## 使い方

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

新しいブロックは `auth.warning` で記録されます:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

期限切れブロックは `auth.info` で記録されます:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

root で実行してください（`pfctl` に必要）。

## Cronjob

`crontab -e` の定期実行エントリ例:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## 注意点

このツールは意図的にシンプルでパターンベースです。本番利用前に、特に `HBPConfiguration.m` を含むソースコードを確認してください。`--expire-blocks` は古いエントリを自動的に削除します。
