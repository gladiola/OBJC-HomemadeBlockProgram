# OBJC-HomemadeBlockProgram

Este programa de linha de comando em Objective-C para OpenBSD substitui os scripts shell de `OpenBSDHomemadeBlockScripts`. Ele lê `/var/log/authlog`, identifica IPs de ataque SSH, adiciona à tabela pf e envia eventos para syslog remoto.

## Situação

Com `sshd` ativo, ataques de força bruta são frequentes. O programa bloqueia automaticamente o IP ofensivo e registra o evento.

## Arquivos-fonte

| Arquivo | Finalidade |
|---|---|
| `main.m` | Entrada da CLI e orquestração |
| `HBPConfiguration.h/m` | Configurações ajustáveis |
| `HBPAuthLogScanner.h/m` | Leitura de authlog e extração de IPs |
| `HBPBlockManager.h/m` | Gestão de bloqueios, ledger, expiração e recarga pf |
| `HBPViolationScanner.h/m` | Scanner temporal para violações web |
| `GNUmakefile` | Build GNUstep |

## Pré-requisitos

OpenBSD com GNUstep. `pfctl` e `logger` já vêm no sistema base.

```sh
pkg_add gnustep-base
```

## Configuração

Edite `HBPConfiguration.m` em `+defaultConfiguration` antes do build:

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

> **Importante:** defina `whitelistIP` com seu IP de administração.

## pf.conf

`/etc/pf.conf` precisa conter a tabela:

```
table <arbitraryblocks> persist file "/etc/pf/blocks/arbitraryBlocks.txt"
block in quick from <arbitraryblocks>
```

Crie os arquivos necessários:

```sh
mkdir -p /etc/pf/blocks
touch /etc/pf/blocks/arbitraryBlocks.txt
touch /etc/pf/blocks/blockLedger.txt
```

## Compilação

```sh
# Build
make

# Run the test suite (no root required)
make test

# Install to /usr/local/sbin (requires root)
sudo make install
```

## Uso

Modos suportados:

```
pf-blocker --monitor-invalid-user
pf-blocker --monitor-disconnect
pf-blocker --monitor-allowlist-violations
pf-blocker --monitor-slowloris-violations
pf-blocker --monitor-ddos
pf-blocker --expire-blocks
```

Novos bloqueios (`auth.warning`):

```
pf-blocker: blocked SSH invalid-user attacker 198.51.100.42
pf-blocker: blocked SSH disconnect attacker 198.51.100.43
pf-blocker: blocked CGI allowlist violator 198.51.100.44
pf-blocker: blocked Slowloris attacker 198.51.100.45
pf-blocker: blocked DDoS attacker 198.51.100.46
```

Bloqueios expirados (`auth.info`):

```
pf-blocker: expired block for 198.51.100.42 after 24h
```

Execute como root (`pfctl`).

## Cronjob

Exemplo para `crontab -e`:

```
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
*/5 * * * * /usr/local/sbin/pf-blocker --monitor-ddos
0   * * * * /usr/local/sbin/pf-blocker --expire-blocks
```

## Riscos

Ferramenta simples e baseada em padrões. Revise o código, especialmente `HBPConfiguration.m`. `--expire-blocks` remove entradas antigas automaticamente.
