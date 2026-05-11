# OBJC-HomemadeBlockProgram

이 프로그램은 OpenBSD용 Objective-C CLI 도구로, `OpenBSDHomemadeBlockScripts` 셸 스크립트를 대체합니다. `/var/log/authlog`를 읽어 SSH 무차별 대입 공격 IP를 추출하고 pf 차단 테이블에 추가하며 원격 syslog로 기록을 전송합니다.

## 상황

`sshd`가 켜져 있으면 SSH 브루트포스가 반복됩니다. 이 도구는 공격 IP를 자동으로 차단하고 중앙 로그를 남깁니다.

## 소스 파일

| 파일 | 용도 |
|---|---|
| `main.m` | CLI 진입점 및 흐름 제어 |
| `HBPConfiguration.h/m` | 경로, syslog, 차단 시간 등 설정 |
| `HBPAuthLogScanner.h/m` | authlog 읽기 및 공격 IP 추출 |
| `HBPBlockManager.h/m` | 차단 파일/ledger/만료/pf 재적용 관리 |
| `HBPViolationScanner.h/m` | 웹 위반 로그 시간창 스캐너 |
| `GNUmakefile` | GNUstep 빌드 파일 |

## 사전 요구사항

OpenBSD와 GNUstep이 필요합니다. `pfctl`, `logger`는 기본 시스템에 포함됩니다.

```sh
pkg_add gnustep-base
```

## 설정

빌드 전에 `HBPConfiguration.m`의 `+defaultConfiguration` 값을 수정하세요:

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

> **중요:** `whitelistIP`를 관리 IP로 반드시 설정하세요.

## pf.conf

`/etc/pf.conf`에 다음 테이블이 있어야 합니다:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

필요한 디렉터리/파일을 먼저 생성하세요:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## 빌드

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## 사용법

지원 모드:

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

신규 차단 로그(`auth.warning`):

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

만료 로그(`auth.info`):

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

`pfctl` 때문에 root로 실행해야 합니다.

## 크론잡

`crontab -e` 예시:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## 주의사항

이 도구는 단순한 패턴 기반 구현입니다. 배포 전 `HBPConfiguration.m`를 포함한 소스를 검토하세요. `--expire-blocks`가 오래된 항목을 자동 정리합니다.
