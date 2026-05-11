# OBJC-HomemadeBlockProgram

He polokalamu laina-kauoha Objective-C kēia no OpenBSD e pani ana i nā shell script `OpenBSDHomemadeBlockScripts`. Heluhelu ia i `/var/log/authlog`, loaʻa nā IP hoʻouka SSH, a hoʻohui i ka pf papa pāpā.

## Kūlana

Ke hana `sshd`, hoʻi pinepine nā hoʻāʻo brute-force. Lawe ka polokalamu i ka IP o ka mea hoʻouka, hoʻohui i ka papa pāpā pf, a hoʻouna i ka hanana i ka log kikowaena.

## Nā faila kumu

| Waihona | Kumu |
|---|---|
| `main.m` | Komo CLI a me ka hoʻonohonoho |
| `HBPConfiguration.h/m` | Nā hoʻonohonoho hiki ke hoʻololi (ala, syslog, hola pāpā) |
| `HBPAuthLogScanner.h/m` | Heluhelu i ka authlog a unuhi i nā IP hoʻouka kū hoʻokahi |
| `HBPBlockManager.h/m` | Mālama i ka faila pāpā, ledger, pau manawa, a me ka hoʻouka hou pf |
| `HBPViolationScanner.h/m` | Mea nānā puka-manawa no nā hewa pūnaewele |
| `GNUmakefile` | Faila kūkulu GNUstep |

## Nā koi mua

Pono ʻo OpenBSD + GNUstep. Aia ʻo `pfctl` a me `logger` i ka ʻōnaehana kumu.

```sh
pkg_add gnustep-base
```

## Hoʻonohonoho

Hoʻoponopono i nā waiwai ma `HBPConfiguration.m` (`+defaultConfiguration`) ma mua o ke kūkulu:

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

> Hoʻonohonoho iā `whitelistIP` i kāu IP luna hilinaʻi ma mua o ka hoʻolaha.

## pf.conf

Pono iā `/etc/pf.conf` ke loaʻa kēia papa:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Hana i nā waihona/pae i koi ʻia:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Kūkulu

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Hoʻohana

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Kākau ʻia nā pāpā hou ma `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Kākau ʻia nā pāpā i pau ma `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Holo ma ke ʻano root (koi ʻia e `pfctl`).

## Cronjob

Laʻana o nā komo manawa no `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Nā pilikia

He maʻalahi kēia mea hana ma ka manaʻo a kūkulu ʻia ma nā hiʻohiʻona. E nānā i ke kumu-kōd i mua o ka hoʻohana production, ʻoi loa `HBPConfiguration.m`. Hoʻomaʻemaʻe ʻo `--expire-blocks` i nā komo kahiko ma ke ʻano akomi.
