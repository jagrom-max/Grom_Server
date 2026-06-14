# 🖥️ GROM SERVER - Servidor de Hospedagem Caseiro

## Infraestrutura Profissional Open Source para Hospedagem e Acesso Remoto

---

## 📋 Visão Geral do Projeto

O **Grom Server** é um projeto de servidor caseiro profissional, projetado para hospedagem web, gestão documental e acesso remoto seguro, construído inteiramente com tecnologias **open source**.

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
| **Backup Externo** | HD Externo 1TB |

### Rede Atual
| Componente | Especificação |
|---|---|
| **Internet** | Cabo 650 Mbps |
| **Roteador** | Mercusys AX3000 Wi-Fi 6 |
| **Domínio** | grom.seg.br |

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
│  │              PROXMOX VE 8.x (Hypervisor)                   │ │
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
│              │  Backup Offsite Local  │                         │
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
│   └── 12-DISASTER-RECOVERY.md        # Plano de recuperação de desastres
├── scripts/                           # Scripts de automação
│   ├── deploy-all.sh                  # 🚀 ORQUESTRADOR - Implanta TUDO automaticamente
│   ├── proxmox/                       # Scripts para Proxmox
│   │   ├── post-install.sh            # Pós-instalação Proxmox
│   │   └── create-containers.sh       # Criação de containers LXC
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
│   │   └── backup-files.sh            # Backup de arquivos
│   ├── monitoring/                    # Scripts de monitoramento
│   │   └── setup-monitoring.sh        # Instalação monitoramento
│   ├── vpn/                           # Scripts VPN
│   │   └── setup-wireguard.sh         # Configuração WireGuard
│   └── security/                      # Scripts de segurança
│       ├── hardening.sh               # Hardening geral
│       └── fail2ban-config.sh         # Configuração Fail2Ban
├── configs/                           # Arquivos de configuração
│   ├── nginx/                         # Configs Nginx
│   │   ├── nginx.conf                 # Config principal
│   │   ├── grom-web.conf              # VHost Grom_web
│   │   ├── grom-documental.conf       # VHost Grom Documental
│   │   └── security-headers.conf      # Headers de segurança
│   ├── php/                           # Configs PHP
│   │   └── php-production.ini         # PHP otimizado produção
│   ├── mysql/                         # Configs MySQL
│   │   └── my.cnf                     # MySQL otimizado
│   ├── fail2ban/                      # Configs Fail2Ban
│   │   ├── jail.local                 # Jails configuradas
│   │   └── filter.d/                  # Filtros customizados
│   └── wireguard/                     # Configs WireGuard
│       └── wg0.conf.template          # Template WireGuard
├── apps/                              # Aplicações
│   ├── grom-web/                      # Grom_web (PHP)
│   │   └── .gitkeep
│   └── grom-documental/               # Grom Documental (Python)
│       └── .gitkeep
└── CHANGELOG.md                       # Registro de alterações
```

---

## 🔧 Stack Tecnológico

| Camada | Tecnologia | Versão | Função |
|---|---|---|---|
| **Hypervisor** | Proxmox VE | 8.x | Virtualização e containers |
| **Firewall** | OPNsense | 24.x | Firewall, IDS/IPS, VLANs |
| **SO Servidor** | Ubuntu Server | 24.04 LTS | Sistema operacional base |
| **Web Server** | Nginx | Latest | Servidor web / Reverse Proxy |
| **PHP** | PHP-FPM | 8.3 | Grom_web |
| **Python** | Python | 3.12+ | Grom Documental + APIs |
| **Banco de Dados** | MySQL | 8.0 | Banco de dados relacional |
| **VPN** | WireGuard | Latest | Acesso remoto seguro |
| **Backup** | BorgBackup + rsync | Latest | Backup incremental |
| **IDS/IPS** | Suricata (via OPNsense) | Latest | Detecção de intrusão |
| **Monitoramento** | Netdata + Uptime Kuma | Latest | Métricas e uptime |
| **Certificados** | Let's Encrypt | Latest | SSL/TLS gratuito |
| **Segurança** | Fail2Ban + CrowdSec | Latest | Proteção contra ataques |
| **DNS** | Cloudflare (gratuito) | - | DNS + proxy + proteção DDoS |

---

## 📊 Alocação de Recursos

| Container/VM | RAM | vCPU | Disco | Função |
|---|---|---|---|---|
| **Proxmox Host** | 2GB | - | 30GB | Sistema host |
| **OPNsense (VM)** | 2GB | 2 | 20GB | Firewall + IDS/IPS |
| **Web Server (LXC)** | 4GB | 4 | 100GB | Nginx + PHP + Python |
| **MySQL (LXC)** | 3GB | 2 | 200GB | Banco de dados |
| **Backup (LXC)** | 1GB | 1 | 50GB | BorgBackup + PBS |
| **Monitoring (LXC)** | 1GB | 1 | 20GB | Netdata + Uptime Kuma |
| **WireGuard (LXC)** | 512MB | 1 | 5GB | VPN |
| **Reserva** | 2.5GB | - | ~575GB | Margem de segurança |
| **TOTAL** | **16GB** | **11** | **~425GB** | |

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
7. **Fase 7** - Deploy das aplicações (Grom_web + Grom Documental)
8. **Fase 8** - Configuração de backup
9. **Fase 9** - Monitoramento e alertas
10. **Fase 10** - VPN e acesso remoto
11. **Fase 11** - Hardening final e testes

### 🤖 Automações Ativas (pós-implantação)
| Automação | Frequência | Descrição |
|---|---|---|
| Backup databases | A cada 6h | mysqldump + BorgBackup incremental |
| Backup arquivos | Diário 02:00 | rsync + BorgBackup |
| Sync HD externo | Diário 04:00 | rsync espelho |
| Health check | A cada 6h | CPU/RAM/Disco/Serviços |
| Watchdog | A cada 3 min | Auto-restart de serviços caídos |
| Updates segurança | Diário | unattended-upgrades |
| SSL renovação | Automático | certbot timer |
| VPN recovery | A cada 5 min | Auto-restart WireGuard |

---

## 🌐 Subdomínios

| Subdomínio | Serviço | IP Interno |
|---|---|---|
| `web.grom.seg.br` | Grom_web (PHP) | 10.0.1.10 |
| `docs.grom.seg.br` | Grom Documental (Python) | 10.0.1.10 |
| `vpn.grom.seg.br` | WireGuard VPN | 10.0.1.14 |
| `monitor.grom.seg.br` | Netdata + Uptime Kuma | 10.0.1.13 |

---

## 📞 Informações do Projeto

**Projeto**: Grom Server  
**Domínio**: grom.seg.br  
**Versão**: 1.0.0  
**Data de Início**: Junho 2026  
**Status**: 📝 Documentação pronta - Aguardando implantação na rede final

---

## 📄 Licença

Este projeto utiliza exclusivamente software open source. Cada componente possui sua própria licença:
- Proxmox VE: AGPL v3
- OPNsense: BSD 2-Clause
- Ubuntu: GPL
- Nginx: BSD 2-Clause
- MySQL: GPL v2
- WireGuard: GPL v2
