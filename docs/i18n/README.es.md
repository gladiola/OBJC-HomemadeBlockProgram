# OBJC-HomemadeBlockProgram

Este programa de línea de comandos en Objective-C para OpenBSD reemplaza los scripts de shell de `OpenBSDHomemadeBlockScripts`. Lee `/var/log/authlog`, detecta IPs atacantes en fuerza bruta SSH, las agrega a la tabla de bloqueo de pf y envía eventos a un syslog remoto.

## Situación

Con `sshd` activo, los intentos de fuerza bruta son frecuentes. El programa extrae la IP ofensora, la bloquea y registra el evento de forma centralizada.

## Archivos fuente

| Archivo | Propósito |
|---|---|
| `main.m` | Punto de entrada CLI y orquestación |
| `HBPConfiguration.h/m` | Ajustes configurables (rutas, syslog, horas) |
| `HBPAuthLogScanner.h/m` | Lee authlog y extrae IPs únicas |
| `HBPBlockManager.h/m` | Gestiona archivo de bloqueos, ledger, expiración y recarga pf |
| `HBPViolationScanner.h/m` | Escáner temporal para violaciones web |
| `GNUmakefile` | Archivo de compilación GNUstep |

## Requisitos previos

Se requiere OpenBSD con GNUstep. `pfctl` y `logger` vienen en el sistema base.

```sh
pkg_add gnustep-base
```

## Configuración

Edite `HBPConfiguration.m` en `+defaultConfiguration` antes de compilar:

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

> **Importante:** configure `whitelistIP` con su IP de administración para evitar auto-bloqueos.

## pf.conf

`/etc/pf.conf` debe incluir una tabla que lea el archivo de bloqueos:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Cree los directorios y archivos requeridos:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Compilación

Compile e instale el programa:

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Uso

Modos disponibles:

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Los nuevos bloqueos se registran con prioridad `auth.warning`:

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Los bloqueos expirados se registran con `auth.info`:

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Debe ejecutarse como root (necesario para `pfctl`).

## Cronjob

Ejemplo para `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Riesgos

Es una implementación simple y basada en patrones. Revise el código, especialmente `HBPConfiguration.m`, antes de desplegar. `--expire-blocks` elimina entradas antiguas automáticamente.
