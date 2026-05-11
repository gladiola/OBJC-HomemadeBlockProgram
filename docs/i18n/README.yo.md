# OBJC-HomemadeBlockProgram

Eto laini-aṣẹ Objective-C yii fun OpenBSD rọpo awọn shell script ninu `OpenBSDHomemadeBlockScripts`. O ka `/var/log/authlog`, o fa IP awọn olùkọlu SSH jade, o sì fi wọn kun pf fun didena.

## Ipo

Nígbà tí `sshd` bá ṣiṣẹ, ìkọlù brute-force máa ń ṣẹlẹ̀ léraléra. Eto naa máa yọ IP olùkọlu, fi sí pf fún didènà, kí o sì fi ìṣẹ̀lẹ̀ ránṣẹ́ sí ibi ìkójọ log.

## Awọn faili orísun

| Fáìlì | Ète |
|---|---|
| `main.m` | Ìbẹ̀rẹ̀ CLI àti ìṣàkóso |
| `HBPConfiguration.h/m` | Àwọn ìṣètò tí a lè yí padà (ọ̀nà, syslog, wákàtí ìdènà) |
| `HBPAuthLogScanner.h/m` | Ka authlog kí o sì yọ àwọn IP olùkólù aláìdọ́gba |
| `HBPBlockManager.h/m` | Ṣàkóso fáìlì ìdènà, ledger, ìparí, àti ìtún-fọwọ́si pf |
| `HBPViolationScanner.h/m` | Scanner ferese-akoko fún ìrúfin wẹẹbu |
| `GNUmakefile` | Fáìlì kọ́ GNUstep |

## Àwọn ìbéèrè ṣáájú

OpenBSD + GNUstep ni a nílò. `pfctl` àti `logger` wà nínú eto ìpìlẹ̀.

```sh
pkg_add gnustep-base
```

## Ìtòlẹ́sẹẹsẹ

Ṣatúnṣe iye nínú `HBPConfiguration.m` (`+defaultConfiguration`) kíkọ tó bẹ̀rẹ̀:

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

> Ṣètò `whitelistIP` sí IP admin tí o gbẹ́kẹ̀lé kí deployment tó bẹ̀rẹ̀.

## pf.conf

`/etc/pf.conf` gbọ́dọ̀ ní tábìlì yìí:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Ṣẹda àwọn ìkànsí/fáìlì tí a nílò:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Kíkó

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Lílo

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Àwọn ìdènà tuntun ni a kọ sí `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Àwọn ìdènà tó ti parí ni a kọ sí `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Ṣiṣẹ́ gẹ́gẹ́ bí root (a nílò fún `pfctl`).

## Cronjob

Àpẹẹrẹ àwọn ìforúkọsílẹ̀ àkókò fún `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Ewu

Ọpa yìí jẹ́ mímọ̀ọ́rọ̀ ní ìfẹ́ àti pé ó da lórí àpẹẹrẹ. Ṣàyẹ̀wò source code kí o tó lò ní production, pàápàá `HBPConfiguration.m`. `--expire-blocks` máa ge àwọn ìforúkọsílẹ̀ àtijọ́ laifọwọyi.
