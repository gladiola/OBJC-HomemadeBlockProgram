# OBJC-HomemadeBlockProgram

Ce programme Objective-C en ligne de commande pour OpenBSD remplace les scripts shell de `OpenBSDHomemadeBlockScripts`. Il lit `/var/log/authlog`, extrait les IP d'attaquants SSH, les ajoute à une table pf et envoie chaque événement vers un syslog distant.

## Situation

Avec `sshd` activé, les attaques par force brute sont répétées. Le programme bloque automatiquement l'IP fautive et journalise l'événement.

## Fichiers source

| Fichier | Rôle |
|---|---|
| `main.m` | Point d'entrée CLI et orchestration |
| `HBPConfiguration.h/m` | Paramètres configurables (chemins, syslog, durée) |
| `HBPAuthLogScanner.h/m` | Lecture de l'authlog et extraction d'IP uniques |
| `HBPBlockManager.h/m` | Gestion du fichier de blocage, ledger, expiration et reload pf |
| `HBPViolationScanner.h/m` | Scanner temporel des violations web |
| `GNUmakefile` | Fichier de build GNUstep |

## Prérequis

OpenBSD avec GNUstep est requis. `pfctl` et `logger` sont déjà dans le système de base.

```sh
pkg_add gnustep-base
```

## Configuration

Modifiez `HBPConfiguration.m` dans `+defaultConfiguration` avant la compilation :

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

> **Important :** définissez `whitelistIP` avec votre IP d'administration pour éviter l'auto-blocage.

## pf.conf

`/etc/pf.conf` doit contenir une table lisant le fichier de blocage :

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Créez les répertoires et fichiers nécessaires :

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Compilation

Compilez et installez :

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Utilisation

Modes disponibles :

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Les nouveaux blocages sont journalisés en `auth.warning` :

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Les expirations sont journalisées en `auth.info` :

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Le programme doit être exécuté en root (requis pour `pfctl`).

## Cronjob

Exemple dans `crontab -e` :

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Risques

L'outil reste volontairement simple et basé sur des motifs. Lisez le code, surtout `HBPConfiguration.m`, avant déploiement. `--expire-blocks` purge automatiquement les entrées anciennes.
