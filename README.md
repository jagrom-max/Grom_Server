# 🖥️ GROM SERVER - Servidor de Hospedagem Caseiro

## Infraestrutura Profissional Open Source para Hospedagem e Acesso Remoto

---

## 📋 Visão Geral do Projeto

O **Grom Server** é um projeto de servidor caseiro profissional, projetado para hospedagem web, gestão documental e acesso remoto seguro, construído inteiramente com tecnologias **open source**.

> **Leitura obrigatória antes da implantação**:
> `docs/00-ARQUITETURA-SEGURA-LGPD.md`, `docs/13-CHECKLIST-PRE-IMPLANTACAO.md`
> `docs/14-IMPLANTACAO-HARDWARE-ATUAL.md`, `docs/15-PRINCIPIOS-BAIXO-CUSTO.md`
> `docs/16-DOWNLOADS-PREPARACAO-OFFLINE.md`, `docs/17-CONTA-GOOGLE-BACKUP.md`,
> `docs/18-DIAGRAMAS-E-MATRIZES.md`, `docs/19-RUNBOOK-PRIMEIRA-IMPLANTACAO.md`
> `docs/20-MATRIZ-RISCOS-CONTROLES.md`, `docs/21-AUTOMACAO-E-BAIXA-MANUTENCAO.md`,
> `docs/22-VALIDACAO-POS-DEPLOY.md`, `docs/23-RELATORIO-OPERACIONAL-MENSAL.md`
> `docs/24-TRANSICAO-GROM-SEG.md`, `docs/25-DNS-REGISTRO-BR.md`
> `docs/26-HOME-ASSISTANT-GROM-SECURITY.md`, `docs/27-GROM-SECURITY-IMPLANTACAO.md`
> `docs/28-CAMERAS-DVR-VIDEO.md`, `docs/29-GROM-SECURITY-REGRAS.md`
> `docs/30-COMUNICACAO-OFICIAL.md`, `docs/31-GO-NOGO-PRODUCAO.md`
> `docs/32-DESENVOLVIMENTO-SEGURO-LAB.md`,
> `docs/38-ESTRUTURA-POR-MAQUINA.md` e
> `docs/39-MIGRACAO-HA-BACK.md` e
> `docs/37-INVENTARIO-EVOLUCAO-HP-ELITEDESK.md`.

### Fase atual: laboratorio seguro

O projeto deve amadurecer em unidade separada antes de qualquer implantacao definitiva no HP EliteDesk e na rede real.

Use o fluxo seguro:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/run-safe-lab-checks.ps1 -BuildRelease
```

Esse fluxo valida auditoria, variaveis ficticias e pacote de release sem executar `deploy-all.sh`, sem tocar Proxmox, sem escrever em `/etc` e sem usar dominio ou segredos reais.

### Subprojeto Grom_Security

O `Grom_Security` deve ser mantido como sistema independente e repositorio irmao do `Grom_Server`, preferencialmente em `E:\Grom_Security` no ambiente Windows de desenvolvimento.

O `Grom_Server` continua responsavel pela infraestrutura, runbooks, Proxmox, rede, backups e modelos de implantacao em `configs/grom-security/`, `configs/docker/` e `docs/`. Codigo, API, OCR, MQTT, alertas e motor de regras do Security devem evoluir fora da arvore do Server, evitando mistura de dependencias, commits e deploys.

### Separacao por maquina

Para acompanhar a nova arquitetura em dois nos, o repositorio passa a reservar
`machines/hp-core/` para o HP EliteDesk e `machines/home-ops/` para a segunda
maquina. Isso permite desenvolver cada host com mais liberdade, menor risco de
mistura e melhor rastreabilidade operacional.

### Hardware Base
| Componente | Especificação |
|---|---|
| **Mini PC** | HP EliteDesk 800 G4 Mini |
| **Processador** | Intel Core i7-8700T (6C/12T) |
| **Memória RAM** | 16GB DDR4 |
| **Armazenamento** | SSD 500GB (substitui a unidade original de 256GB) |
| **Rede Integrada** | 1x Ethernet Gigabit |
| **Rede USB** | Adaptador Ugreen USB-A 3.0 para LAN RJ45 2.5G |
| **Switch** | TP-Link TL-SG108 (8 portas Gigabit) |
| **Backup Externo** | Unidade USB de 1TB para backup operacional temporario |
| **Vídeo** | Frigate/Grom_Security integrado ao DVR Intelbras iMHDX 3008 |
| **Segunda Maquina** | Home Assistant + servidor de backup dedicado |

### Rede Atual
| Componente | Especificação |
|---|---|
| **Internet** | Cabo 650 Mbps |
| **Roteador** | Mercusys AX3000 Wi-Fi 6 |
| **Domínio** | grom.seg.br |
| **Comunicacao externa oficial** | grom.servidor@gmail.com |

> A conta `grom.servidor@gmail.com` e a identidade externa oficial do Grom_Server,
> Grom_Security e Grom.Seg para alertas, contatos tecnicos e recuperacao de servicos.
> Nao enviar senhas, dumps ou documentos sensiveis em claro.

---

## 🏗️ Arquitetura do Sistema

```text
Internet
  -> Mercusys AX3000
  -> HP EliteDesk 800 G4 Mini
     -> Proxmox VE
        -> VM100 OPNsense
        -> CT110 Grom.Seg
        -> CT111 MySQL
        -> CT112 Orquestrador de backup local
        -> CT113 Monitoramento
        -> CT114 WireGuard
        -> VM130 Grom_Security/Frigate
     -> Unidade USB 1 TB
        -> copia operacional local temporaria

Segunda maquina dedicada
  -> Home Assistant
  -> servidor de backup definitivo
  -> replica dos backups do HP

DVR Intelbras iMHDX 3008
  -> gravacao continua principal
  -> streams RTSP/ONVIF para VM130
```

O HP passa a ser o cerebro principal do ecossistema: hospeda a borda segura,
os servicos centrais do `Grom Server` e a camada de video/analitico do
`Grom_Security`. A segunda maquina assume automacao residencial e resiliencia,
reduzindo disputa de CPU, RAM, disco e I/O no HP.

---

## 📁 Estrutura do Repositório

```
Grom_Server/
├── README.md                          # Este arquivo
├── docs/                              # Documentação completa
│   ├── 01-PLANO-IMPLANTACAO.md        # Plano detalhado de implantação
│   ├── 02-HARDWARE-REDE.md            # Configuração de hardware e rede
│   ├── 03-PROXMOX-SETUP.md            # Instalação e config do Proxmox
│   ├── 04-OPNSENSE-FIREWALL.md        # Configuração do firewall
│   ├── 05-WEBSERVER-SETUP.md          # Servidor web (Nginx+PHP+Python)
│   ├── 06-DATABASE-SETUP.md           # Banco de dados MySQL
│   ├── 07-BACKUP-STRATEGY.md          # Estratégia de backup
│   ├── 08-MONITORING.md               # Monitoramento e alertas
│   ├── 09-VPN-REMOTE-ACCESS.md        # VPN e acesso remoto
│   ├── 10-SECURITY-HARDENING.md       # Hardening de segurança
│   ├── 11-MANUTENCAO.md               # Procedimentos de manutenção
│   ├── 12-DISASTER-RECOVERY.md        # Plano de recuperação de desastres
│   ├── 13-CHECKLIST-PRE-IMPLANTACAO.md
│   ├── 14-IMPLANTACAO-HARDWARE-ATUAL.md
│   ├── 15-PRINCIPIOS-BAIXO-CUSTO.md
│   ├── 16-DOWNLOADS-PREPARACAO-OFFLINE.md
│   ├── 17-CONTA-GOOGLE-BACKUP.md
│   ├── 18-DIAGRAMAS-E-MATRIZES.md
│   ├── 19-RUNBOOK-PRIMEIRA-IMPLANTACAO.md
│   ├── 20-MATRIZ-RISCOS-CONTROLES.md
│   ├── 21-AUTOMACAO-E-BAIXA-MANUTENCAO.md
│   ├── 22-VALIDACAO-POS-DEPLOY.md
│   ├── 37-INVENTARIO-EVOLUCAO-HP-ELITEDESK.md
│   ├── 23-RELATORIO-OPERACIONAL-MENSAL.md
│   ├── 24-TRANSICAO-GROM-SEG.md
│   ├── 25-DNS-REGISTRO-BR.md
│   ├── 26-HOME-ASSISTANT-GROM-SECURITY.md
│   ├── 27-GROM-SECURITY-IMPLANTACAO.md
│   ├── 28-CAMERAS-DVR-VIDEO.md
│   ├── 29-GROM-SECURITY-REGRAS.md
│   ├── 30-COMUNICACAO-OFICIAL.md
│   ├── 38-ESTRUTURA-POR-MAQUINA.md
│   └── 39-MIGRACAO-HA-BACK.md
├── machines/                          # Desenvolvimento separado por host
│   ├── README.md                      # Regras da divisao por maquina
│   ├── hp-core/                       # HP EliteDesk: cerebro principal
│   │   ├── docs/
│   │   ├── configs/
│   │   └── scripts/
│   └── home-ops/                      # Segunda maquina: HA + backup
│       ├── docs/
│       ├── configs/
│       └── scripts/
├── scripts/                           # Scripts de automação
│   ├── deploy-all.sh                  # 🚀 ORQUESTRADOR - Implanta TUDO automaticamente
│   ├── proxmox/                       # Scripts para Proxmox
│   │   ├── post-install.sh            # Pós-instalação Proxmox
│   │   ├── create-containers.sh       # Criação de containers LXC
│   │   ├── verify-host-readiness.sh   # Validação pré-deploy do host
│   │   ├── validate-deploy-config.sh  # Validação de variáveis e pacote
│   │   ├── post-deploy-validation.sh  # Validação pós-deploy
│   │   ├── monthly-operational-report.sh # Relatório operacional mensal
│   │   ├── create-ha-security-vms.sh   # VM Grom_Security; HA local apenas legado/explicito
│   │   ├── deploy-grom-security.sh      # Deploy automatizado do Grom_Security
│   │   └── backup-containers.sh       # Backup VM/LXC no Proxmox
│   ├── downloads/                     # Preparação de downloads offline
│   │   ├── prepare-offline-kit.ps1
│   │   ├── prepare-offline-kit.sh
│   │   ├── prepare-grom-security-offline.ps1
│   │   └── prepare-grom-security-offline.sh
│   ├── webserver/                     # Scripts do servidor web
│   │   ├── setup-nginx.sh             # Instalação e config Nginx
│   │   ├── setup-php.sh               # Instalação PHP 8.3
│   │   ├── setup-python.sh            # Ambiente Python
│   │   └── setup-ssl.sh               # Certificados SSL
│   ├── database/                      # Scripts do banco de dados
│   │   ├── setup-mysql.sh             # Instalação MySQL 8
│   │   ├── create-databases.sh        # Criação dos bancos
│   │   └── mysql-hardening.sh         # Hardening MySQL
│   ├── firewall/                      # Scripts do firewall
│   │   └── opnsense-config.xml        # Config exportável OPNsense
│   ├── backup/                        # Scripts de backup
│   │   ├── setup-backup.sh            # Configuração backup
│   │   ├── backup-databases.sh        # Backup de bancos
│   │   ├── backup-files.sh            # Backup de fontes montadas
│   │   └── sync-google-drive.sh       # Sync externo criptografado opcional
│   ├── monitoring/                    # Scripts de monitoramento
│   │   └── setup-monitoring.sh        # Instalação monitoramento
│   ├── vpn/                           # Scripts VPN
│   │   └── setup-wireguard.sh         # Configuração WireGuard
│   └── security/                      # Scripts de segurança
│       ├── hardening.sh               # Hardening geral
│       ├── setup-email-relay.sh       # Relay SMTP seguro
│       └── fail2ban-config.sh         # Configuração Fail2Ban
├── configs/                           # Arquivos de configuração
│   ├── grom.env.example               # Variáveis operacionais não secretas
│   ├── nginx/                         # Configs Nginx
│   │   ├── nginx.conf                 # Config principal
│   │   ├── grom-seg.conf              # VHost Grom.Seg
│   │   ├── grom-web.conf              # VHost legado Grom_web
│   │   ├── grom-documental.conf       # VHost Grom Documental
│   │   └── security-headers.conf      # Headers de segurança
│   ├── php/                           # Configs PHP
│   │   └── php-production.ini         # PHP otimizado produção
│   ├── mysql/                         # Configs MySQL
│   │   └── my.cnf                     # MySQL otimizado
│   ├── fail2ban/                      # Configs Fail2Ban
│   │   ├── jail.local                 # Jails configuradas
│   │   └── filter.d/                  # Filtros customizados
│   ├── grom-security/                 # Inventario e modelos Grom_Security/OpenVINO
│   └── wireguard/                     # Configs WireGuard
│       └── wg0.conf.template          # Template WireGuard
├── apps/                              # Aplicações
│   ├── grom-seg/                      # Grom.Seg unificado
│   ├── grom-web/                      # Grom_web legado
│   │   └── .gitkeep
│   └── grom-documental/               # Grom Documental (Python)
│       └── .gitkeep
└── CHANGELOG.md                       # Registro de alterações
```

---

## 🔧 Stack Tecnológico

| Camada | Tecnologia | Versão | Função |
|---|---|---|---|
| **Hypervisor** | Proxmox VE | 9.x | Virtualização e containers |
| **Base do host HP** | Debian GNU/Linux via Proxmox VE | Debian 13 base do PVE 9 | Sistema bare metal do HP |
| **Firewall** | OPNsense | Estável vigente | Firewall, IDS/IPS, separação WAN/LAN |
| **SO dos guests principais** | Ubuntu Server | 24.04 LTS | Base dos LXCs/VMs de aplicação no HP |
| **Web Server** | Nginx | Latest | Servidor web / Reverse Proxy |
| **PHP** | PHP-FPM | 8.3 | Grom.Seg |
| **Python** | Python | 3.12+ | Modulos internos/OCR/APIs |
| **Banco de Dados** | MySQL | 8.0 | Banco de dados relacional |
| **VPN** | WireGuard | Latest | Acesso remoto seguro |
| **Backup** | BorgBackup + vzdump + rsync | Latest | Backup criptografado e snapshots |
| **IDS/IPS** | Suricata (via OPNsense) | Latest | Detecção de intrusão |
| **Monitoramento** | Netdata + Uptime Kuma | Latest | Métricas e uptime |
| **Certificados** | Let's Encrypt | Latest | SSL/TLS gratuito |
| **Segurança** | Fail2Ban + CrowdSec opcional | Latest | Proteção contra ataques |
| **DNS** | Registro.br | - | DNS autoritativo do dominio |
| **DNS opcional futuro** | Cloudflare | - | DNS/WAF, se aprovado pela politica de dados |

---

## 📊 Alocação de Recursos

| Container/VM | RAM | vCPU | Disco | Função |
|---|---|---|---|---|
| **Proxmox Host** | 2GB | - | 30GB | Sistema host |
| **OPNsense (VM)** | 2GB | 2 | 20GB | Firewall + IDS/IPS |
| **Web Server (LXC)** | 2.5GB | 3 | 60GB | Grom.Seg |
| **MySQL (LXC)** | 2GB | 2 | 100GB | Banco de dados |
| **Backup local (LXC)** | 512MB | 1 | 16GB | Orquestracao Borg/vzdump; camada temporaria no USB de 1TB |
| **Monitoring (LXC)** | 512MB | 1 | 12GB | Netdata + Uptime Kuma |
| **WireGuard (LXC)** | 384MB | 1 | 4GB | VPN |
| **Grom_Security/Frigate (VM)** | 4GB | 4 | 100GB | Deteccao, eventos, MQTT e retencao curta |
| **Reserva** | ~2GB | - | ~120GB | Margem para host, logs, snapshots e crescimento |
| **TOTAL planejado no HP** | **~14GB** | **14** | **~342GB** | Sem Home Assistant e sem backup definitivo neste host |

> ⚠️ **Nota**: o i7-8700T possui 6 cores / 12 threads. O Frigate deve usar OpenVINO na iGPU Intel quando os testes de passthrough forem aprovados. O DVR Intelbras permanece responsável pela gravação contínua; o SSD de 500GB não deve ser usado como arquivo NVR de longa retenção.

O Home Assistant e o servidor de backup definitivo ficam juntos em uma segunda
maquina. Ate essa segunda maquina entrar em operacao, o CT112 coordena os
backups para a unidade USB de 1TB como camada local provisoria.

No HP, o host fisico e `Proxmox VE` bare metal, portanto a base do host e
Debian via Proxmox, nao Ubuntu. O `Ubuntu Server 24.04 LTS` permanece como
padrao dos guests principais onde isso fizer sentido operacional.

---

## 🚀 Implantação

> **Deploy automatizado**: Execute `bash deploy-all.sh` no Proxmox host para implantar toda a infraestrutura automaticamente.

### Fases (executadas automaticamente pelo orquestrador)
1. **Fase 1** - Preparação da rede física
2. **Fase 2** - Instalação do Proxmox VE no HP EliteDesk
3. **Fase 3** - Configuração da VM OPNsense (Firewall)
4. **Fase 4** - Criação dos containers LXC
5. **Fase 5** - Configuração do servidor web
6. **Fase 6** - Configuração do MySQL
7. **Fase 7** - Deploy da aplicação unificada Grom.Seg e módulos legados em transição
8. **Fase 8** - Configuração de backup
9. **Fase 9** - Monitoramento e alertas
10. **Fase 10** - VPN e acesso remoto
11. **Fase 11** - Hardening final e testes

### 🤖 Automações Ativas (pós-implantação)
| Automação | Frequência | Descrição |
|---|---|---|
| Backup databases | A cada 6h | mysqldump + BorgBackup incremental |
| Backup fontes montadas | Diário 02:00 | BorgBackup, se houver fontes montadas |
| Backup VM/LXC | Diário 02:30 | vzdump no Proxmox host |
| Sync HD externo | Diário 04:00 | rsync espelho |
| Sync segundo HD opcional | Diário 04:30 | rsync se `/mnt/external2` existir |
| Sync externo criptografado | Diário 05:30 | rclone crypt para Google Drive, se configurado |
| Health check | A cada 6h | CPU/RAM/Disco/Serviços |
| Watchdog | A cada 3 min | Alerta serviços remotos e reinicia serviços locais |
| Updates segurança | Diário | unattended-upgrades |
| SSL renovação | Automático | certbot timer |
| VPN recovery | A cada 5 min | Auto-restart WireGuard |
| Relatório operacional | Mensal | Saúde do host, VM/CT, backups, logs e checklist |

---

## 🌐 Subdomínios

| Subdomínio | Serviço | IP Interno |
|---|---|---|
| `grom.seg.br` | Grom.Seg | 10.0.1.10 |
| `web.grom.seg.br` | Legado/transição Grom_web | 10.0.1.10 |
| `docs.grom.seg.br` | Legado/transição Grom Documental | 10.0.1.10 |
| `vpn.grom.seg.br` | WireGuard VPN | 10.0.1.14 |
| Interno/VPN apenas | Segunda maquina (Home Assistant + backup) | 10.0.1.20 sugerido |
| Interno/VPN apenas | Grom_Security | 10.0.1.30 |
| Interno/VPN apenas | Netdata + Uptime Kuma | 10.0.1.13 |

---

## 📞 Informações do Projeto

**Projeto**: Grom Server  
**Domínio**: grom.seg.br  
**Versão**: 1.2.1
**Data de Início**: Junho 2026  
**Status**: Desenvolvimento ativo - Fase 1 aprovada com hardware atual

---

## 📄 Licença

Este projeto utiliza exclusivamente software open source. Cada componente possui sua própria licença:
- Proxmox VE: AGPL v3
- OPNsense: BSD 2-Clause
- Ubuntu: GPL
- Nginx: BSD 2-Clause
- MySQL: GPL v2
- WireGuard: GPL v2
