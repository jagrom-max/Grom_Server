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
> e `docs/32-DESENVOLVIMENTO-SEGURO-LAB.md`.

### Fase atual: laboratorio seguro

O projeto deve amadurecer em unidade separada antes de qualquer implantacao definitiva no mini PC e na rede real.

Use o fluxo seguro:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/run-safe-lab-checks.ps1 -BuildRelease
```

Esse fluxo valida auditoria, variaveis ficticias e pacote de release sem executar `deploy-all.sh`, sem tocar Proxmox, sem escrever em `/etc` e sem usar dominio ou segredos reais.

### Subprojeto Grom_Security

O `Grom_Security` deve ser mantido como sistema independente e repositorio irmao do `Grom_Server`, preferencialmente em `E:\Grom_Security` no ambiente Windows de desenvolvimento.

O `Grom_Server` continua responsavel pela infraestrutura, runbooks, Proxmox, rede, backups e modelos de implantacao em `configs/grom-security/`, `configs/docker/` e `docs/`. Codigo, API, OCR, MQTT, alertas e motor de regras do Security devem evoluir fora da arvore do Server, evitando mistura de dependencias, commits e deploys.

### Hardware Base
| Componente | Especificação |
|---|---|
| **Mini PC** | Beelink - Intel i5-1035G7 |
| **Processador** | Intel Core i5-1035G7 (4C/8T, 1.2-3.7GHz) |
| **Memória RAM** | 16GB DDR4 |
| **Armazenamento** | 1TB SSD NVMe |
| **Rede Integrada** | 1x Ethernet Gigabit |
| **Rede USB** | Adaptador Ugreen USB-A 3.0 para LAN RJ45 2.5G |
| **Switch** | TP-Link TL-SG108 (8 portas Gigabit) |
| **Backup Externo** | HD Externo 1TB; segundo HD 1TB opcional para copia B/offline |

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

```
┌─────────────────────────────────────────────────────────────────┐
│                    INTERNET (650 Mbps)                           │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│              MERCUSYS AX3000 (Roteador Wi-Fi 6)                 │
│              Port Forwarding → Mini PC                          │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│          BEELINK MINI PC (i5-1035G7 / 16GB / 1TB)               │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              PROXMOX VE 9.x (Hypervisor)                   │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │ │
│  │  │  VM: OPNsense│ │ LXC: Web     │ │ LXC: DB      │       │ │
│  │  │  (Firewall)  │ │ Server       │ │ Server       │       │ │
│  │  │  2GB RAM     │ │ (Nginx+PHP+  │ │ (MySQL 8)    │       │ │
│  │  │  2 vCPU      │ │  Python)     │ │ 3GB RAM      │       │ │
│  │  │  WAN ↔ LAN   │ │ 4GB RAM      │ │ 2 vCPU       │       │ │
│  │  └──────────────┘ │ 4 vCPU       │ └──────────────┘       │ │
│  │                   └──────────────┘                         │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │ │
│  │  │ LXC: Backup  │ │ LXC: Monitor │ │ LXC: VPN     │       │ │
│  │  │ (PBS +       │ │ (Netdata +   │ │ (WireGuard)  │       │ │
│  │  │  BorgBackup) │ │  Uptime Kuma)│ │ 512MB RAM    │       │ │
│  │  │ 1GB RAM      │ │ 1GB RAM      │ │ 1 vCPU       │       │ │
│  │  │ 1 vCPU       │ │ 1 vCPU       │ └──────────────┘       │ │
│  │  └──────────────┘ └──────────────┘                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                          │                                      │
│              ┌───────────▼────────────┐                         │
│              │  HD Externo 1TB (USB)  │                         │
│              │  Backup local/rotação  │                         │
│              └────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

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
│   ├── 23-RELATORIO-OPERACIONAL-MENSAL.md
│   ├── 24-TRANSICAO-GROM-SEG.md
│   ├── 25-DNS-REGISTRO-BR.md
│   ├── 26-HOME-ASSISTANT-GROM-SECURITY.md
│   ├── 27-GROM-SECURITY-IMPLANTACAO.md
│   ├── 28-CAMERAS-DVR-VIDEO.md
│   ├── 29-GROM-SECURITY-REGRAS.md
│   └── 30-COMUNICACAO-OFICIAL.md
├── scripts/                           # Scripts de automação
│   ├── deploy-all.sh                  # 🚀 ORQUESTRADOR - Implanta TUDO automaticamente
│   ├── proxmox/                       # Scripts para Proxmox
│   │   ├── post-install.sh            # Pós-instalação Proxmox
│   │   ├── create-containers.sh       # Criação de containers LXC
│   │   ├── verify-host-readiness.sh   # Validação pré-deploy do host
│   │   ├── validate-deploy-config.sh  # Validação de variáveis e pacote
│   │   ├── post-deploy-validation.sh  # Validação pós-deploy
│   │   ├── monthly-operational-report.sh # Relatório operacional mensal
│   │   ├── create-ha-security-vms.sh   # VMs Home Assistant e Grom_Security
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
| **Firewall** | OPNsense | Estável vigente | Firewall, IDS/IPS, separação WAN/LAN |
| **SO Servidor** | Ubuntu Server | 24.04 LTS | Sistema operacional base |
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
| **Web Server (LXC)** | 3GB | 3 | 100GB | Grom.Seg |
| **MySQL (LXC)** | 2.5GB | 2 | 200GB | Banco de dados |
| **Backup (LXC)** | 768MB | 1 | 50GB | BorgBackup + PBS |
| **Monitoring (LXC)** | 768MB | 1 | 20GB | Netdata + Uptime Kuma |
| **WireGuard (LXC)** | 512MB | 1 | 5GB | VPN |
| **Home Assistant OS (VM)** | 2GB | 2 | 32GB | Automacao, Matter, Alarm Panel |
| **Grom_Security (VM)** | 4GB | 2-4 | 160GB | Video, MQTT, OCR, eventos |
| **Reserva** | ~1GB | - | ~403GB | Margem minima |
| **TOTAL** | **~16GB** | **15-17** | **~597GB** | Overcommit controlado |

> ⚠️ **Nota**: O i5-1035G7 possui 4 cores / 8 threads. A soma de vCPUs pode exceder os cores físicos pois nem todos os containers operam em carga máxima simultaneamente (overcommit controlado).

---

## 🚀 Implantação

> **Deploy automatizado**: Execute `bash deploy-all.sh` no Proxmox host para implantar toda a infraestrutura automaticamente.

### Fases (executadas automaticamente pelo orquestrador)
1. **Fase 1** - Preparação da rede física
2. **Fase 2** - Instalação do Proxmox VE no Mini PC
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
| Interno/VPN apenas | Home Assistant OS | 10.0.1.20 |
| Interno/VPN apenas | Grom_Security | 10.0.1.30 |
| Interno/VPN apenas | Netdata + Uptime Kuma | 10.0.1.13 |

---

## 📞 Informações do Projeto

**Projeto**: Grom Server  
**Domínio**: grom.seg.br  
**Versão**: 1.0.0  
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
