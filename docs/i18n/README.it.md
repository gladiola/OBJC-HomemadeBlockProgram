# OBJC-HomemadeBlockProgram

Programma Objective-C a riga di comando per OpenBSD che sostituisce gli script shell di `OpenBSDHomemadeBlockScripts`. Legge `/var/log/authlog`, estrae gli IP attaccanti SSH, li aggiunge a pf e invia eventi a un syslog remoto.

## Situazione

Con `sshd` attivo, i tentativi brute-force sono continui. Il programma blocca automaticamente l'IP offensivo e registra l'evento.

## File sorgente

| File | Scopo |
|---|---|
| `main.m` | Entry point CLI e orchestrazione |
| `HBPConfiguration.h/m` | Impostazioni configurabili |
| `HBPAuthLogScanner.h/m` | Lettura authlog ed estrazione IP |
| `HBPBlockManager.h/m` | Gestione blocchi, ledger, scadenza e reload pf |
| `HBPViolationScanner.h/m` | Scanner temporale violazioni web |
| `GNUmakefile` | Build GNUstep |

## Prerequisiti

OpenBSD con GNUstep. `pfctl` e `logger` sono nel sistema base.

```sh
pkg_add gnustep-base
```

## Configurazione

Modifica `HBPConfiguration.m` in `+defaultConfiguration` prima della build:

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

> **Importante:** imposta `whitelistIP` con il tuo IP di amministrazione.

## pf.conf

`/etc/pf.conf` deve contenere la tabella:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Crea directory e file richiesti:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Build

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Uso

Modalità disponibili:

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Nuovi blocchi (`auth.warning`):

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Blocchi scaduti (`auth.info`):

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Eseguire come root (`pfctl`).

## Cronjob

Esempio in `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Rischi

Strumento semplice e basato su pattern. Leggi il codice, specialmente `HBPConfiguration.m`. `--expire-blocks` elimina automaticamente i blocchi vecchi.
