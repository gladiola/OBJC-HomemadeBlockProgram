# OBJC-HomemadeBlockProgram

Dieses Objective-C-Kommandozeilenprogramm für OpenBSD ersetzt die Shell-Skripte aus `OpenBSDHomemadeBlockScripts`. Es liest `/var/log/authlog`, erkennt Angreifer-IPs bei SSH-Bruteforce, trägt sie in die pf-Blockliste ein und sendet Ereignisse an einen entfernten Syslog-Server.

## Situation

Auf Systemen mit aktivem `sshd` treten wiederholt Brute-Force-Versuche auf. Dieses Programm blockiert die Quell-IP automatisch und protokolliert den Vorfall zentral.

## Quelldateien

| Datei | Zweck |
|---|---|
| `main.m` | CLI-Einstieg und Ablaufsteuerung |
| `HBPConfiguration.h/m` | Konfigurierbare Werte (Pfade, Syslog, Stunden) |
| `HBPAuthLogScanner.h/m` | Liest Auth-Logs und extrahiert eindeutige Angreifer-IPs |
| `HBPBlockManager.h/m` | Verwalten von Blockdatei, Ledger, Ablauf und pf-Reload |
| `HBPViolationScanner.h/m` | Zeitfenster-Scanner für Web-Verstöße |
| `GNUmakefile` | GNUstep-Builddatei |

## Voraussetzungen

OpenBSD mit GNUstep wird benötigt. Laufzeitabhängigkeiten `pfctl` und `logger` sind im Basissystem enthalten.

```sh
pkg_add gnustep-base
```

## Konfiguration

Bearbeiten Sie `HBPConfiguration.m` vor dem Build in `+defaultConfiguration`:

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

> **Wichtig:** Setzen Sie `whitelistIP` auf Ihre Verwaltungs-IP, damit Sie sich nicht selbst sperren.

## pf.conf

`/etc/pf.conf` muss eine Tabelle enthalten, die aus der Blockdatei liest:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Erstellen Sie die benötigten Dateien vor dem ersten Lauf:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Build

Kompilieren und installieren Sie das Programm:

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Verwendung

Unterstützte Modi:

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Neue Sperren werden mit `auth.warning` protokolliert:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Abgelaufene Sperren werden mit `auth.info` protokolliert:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Das Programm muss als Root laufen (für `pfctl`).

## Cronjob

Beispiel für periodische Ausführung in `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Risiken

Das Werkzeug ist bewusst einfach und regelbasiert. Prüfen Sie den Quellcode vor dem Einsatz, besonders `HBPConfiguration.m`. Die Tabelle wächst mit dem Angriffsaufkommen; `--expire-blocks` bereinigt alte Einträge automatisch.
