# 📋 Plano de Implantação - Grom Server

## Fase 1: Preparação da Rede Física

### 1.1 Topologia de Rede

```
Internet (650Mbps)
       │
       ▼
┌──────────────┐
│ Mercusys      │ WAN: DHCP do ISP
│ AX3000        │ LAN: 192.168.0.0/24
│ (Modo Bridge*)│ 
└──────┬───────┘
       │ ETH (Cabo)
       ▼
┌──────────────────────────────────────────┐
│          BEELINK MINI PC                  │
│                                           │
│  ETH0 (Onboard) ──► WAN (OPNsense)       │
│  ETH1 (USB Ugreen 2.5G) ──► LAN Interna  │
│                                           │
│  Proxmox VE 9.x                           │
│  ├── vmbr0 (Bridge WAN - eth0)            │
│  └── vmbr1 (Bridge LAN - eth1/USB)        │
└──────────────────────────────────────────┘
```

### 1.2 Configuração do Roteador Mercusys AX3000

> **IMPORTANTE**: O roteador Mercusys será usado APENAS como modem/bridge ou como ponto de acesso Wi-Fi. O OPNsense será o roteador/firewall principal.

**Opção A - Modo Bridge (Recomendado)**:
- Configurar o Mercusys em modo Bridge/AP
- O OPNsense gerencia toda a rede
- Wi-Fi do Mercusys continua funcionando como Access Point

**Opção B - Duplo NAT (Mais simples, menos ideal)**:
- Manter o Mercusys como roteador
- Configurar DMZ apontando para o Mini PC
- Port forwarding das portas necessárias

### 1.3 Endereçamento IP - Fase 1 com hardware atual

| Rede | CIDR | Gateway | Função |
|---|---|---|---|
| WAN | DHCP do ISP | ISP | Internet |
| LAN Restrita | 10.0.1.0/24 | 10.0.1.1 | Servidores e manutencao local |
| VPN | 10.0.10.0/24 | 10.0.10.1 | Clientes VPN |

> A separacao inicial sera fisica: WAN na porta onboard e LAN no adaptador Ugreen USB 2.5G. O switch atual distribui apenas a LAN restrita e nao fara VLAN.

### 1.4 Atribuição de IPs Fixos

| Host | IP | Função |
|---|---|---|
| OPNsense LAN | 10.0.1.1 | Gateway / Firewall |
| Web Server | 10.0.1.10 | Nginx + PHP + Python |
| MySQL Server | 10.0.1.11 | Banco de dados |
| Backup Server | 10.0.1.12 | BorgBackup |
| Monitoring | 10.0.1.13 | Netdata + Uptime Kuma |
| WireGuard VPN | 10.0.1.14 | Servidor VPN |

---

## Fase 2: Instalação do Proxmox VE

### 2.1 Pré-requisitos
1. Download da ISO do Proxmox VE 9.x: https://www.proxmox.com/downloads
2. Criar pendrive bootável com Balena Etcher ou Rufus
3. Backup de qualquer dado existente no Mini PC

### 2.2 Procedimento de Instalação
1. Boot pelo pendrive USB
2. Selecionar o SSD 1TB como destino
3. Filesystem: **ext4** (mais simples para SSD único)
4. Configurar hostname: `grom-pve.local`
5. IP de gerenciamento: `10.0.1.100` (temporário, será ajustado)
6. Gateway: IP do roteador atual
7. DNS: `1.1.1.1` (Cloudflare)
8. Senha forte para root
9. Email para alertas: `grom.servidor@gmail.com`

### 2.3 Pós-Instalação
- Executar script `scripts/proxmox/post-install.sh`
- Configurar repositórios sem assinatura
- Atualizar sistema
- Configurar bridges de rede (vmbr0 e vmbr1)

---

## Fase 3: OPNsense Firewall

### 3.1 Criação da VM
- **Tipo**: VM (não LXC, pois precisa de acesso direto às interfaces de rede)
- **RAM**: 2GB
- **vCPU**: 2
- **Disco**: 20GB
- **Rede**: 2 interfaces (vmbr0 = WAN, vmbr1 = LAN)

### 3.2 Configuração Inicial
1. Download ISO OPNsense: https://opnsense.org/download/
2. Instalar na VM
3. Configurar WAN (DHCP)
4. Configurar LAN (10.0.1.1/24)
5. Acessar WebGUI: https://10.0.1.1

### 3.3 Regras de Firewall
- Default: DENY ALL (entrada)
- Permitir apenas portas necessárias
- Configurar IDS/IPS (Suricata)
- Configurar aliases e grupos

---

## Fase 4: Containers LXC

### 4.1 Template Base
- Ubuntu 24.04 LTS (template Proxmox)
- Configuração SSH com chave pública
- Desabilitar login root por senha

### 4.2 Ordem de Criação
1. **CT110** - Web Server
2. **CT111** - MySQL Server
3. **CT112** - Backup Server
4. **CT113** - Monitoring
5. **CT114** - WireGuard VPN

---

## Fase 5: Servidor Web

### 5.1 Stack
- Nginx (último estável)
- PHP 8.3-FPM
- Python 3.12+ com venv
- Node.js 20 LTS (se necessário)

### 5.2 Aplicações
- **Grom.Seg**: Aplicacao unificada principal
- **Modulos legados**: Grom_web, Grom Documental e OCR durante transicao
- Reverse proxy para ambas via Nginx

---

## Fase 6: Banco de Dados MySQL

### 6.1 MySQL 8.0
- Instalação dedicada em container separado
- Hardening de segurança
- Configuração otimizada para 3GB RAM
- Backups automáticos

### 6.2 Bancos de Dados
- `grom_seg` - Banco principal da aplicacao unificada
- `grom_web` - Banco legado da aplicacao web
- `grom_documental` - Banco legado do sistema documental

---

## Fase 7: Deploy das Aplicações

### 7.1 Grom.Seg
- Deploy via Git
- Configuração de VirtualHost
- SSL/TLS com Let's Encrypt

### 7.2 Modulos legados/documentais
- Deploy via Git com venv
- Gunicorn como WSGI/ASGI
- Systemd service
- Reverse proxy via Nginx

---

## Fase 8: Backup

### 8.1 Estratégia 3-2-1
- **3** cópias dos dados
- **2** mídias diferentes (SSD + HD externo)
- **1** cópia offsite (HD externo rotacionável)

### 8.2 Ferramentas
- **BorgBackup**: Backup incremental, deduplificado, criptografado
- **mysqldump**: Backup lógico do MySQL
- **vzdump**: Backup de VM/containers no Proxmox host
- **rsync**: Sincronização com HD externo

### 8.3 Agenda
| Tipo | Frequência | Retenção | Destino |
|---|---|---|---|
| DB Dump | A cada 6h | 7 dias | Local + HD Externo |
| VM/LXC Proxmox | Diário | 30 dias | HD Externo |
| Fontes montadas opcionais | Diário | 30 dias | Local + HD Externo |
| Configs sistema | Semanal | 90 dias | Local + HD Externo |
| VM/LXC Snapshot | Semanal | 4 snapshots | Proxmox |
| Full backup | Mensal | 6 meses | HD Externo |

---

## Fase 9: Monitoramento

### 9.1 Netdata
- Monitoramento em tempo real
- Dashboard web
- Alertas por email/Telegram

### 9.2 Uptime Kuma
- Monitoramento de uptime dos serviços
- Dashboard de status público
- Alertas por múltiplos canais

---

## Fase 10: VPN e Acesso Remoto

### 10.1 WireGuard
- VPN moderna, rápida e segura
- Configuração de peers (clientes)
- Acesso total à rede interna via VPN

### 10.2 Clientes Suportados
- Windows, macOS, Linux
- Android, iOS
- Máximo 10 conexões simultâneas

---

## Fase 11: Hardening Final

### 11.1 Checklist de Segurança
- [ ] Todas as senhas são fortes e únicas
- [ ] SSH apenas com chave pública
- [ ] 2FA habilitado no Proxmox
- [ ] Fail2Ban configurado em todos os servidores
- [ ] CrowdSec avaliado e, se adotado, instalado por repositório oficial
- [ ] Firewall OPNsense com regras restritivas
- [ ] IDS/IPS (Suricata) ativo
- [ ] Certificados SSL em todos os serviços web
- [ ] Backups testados e verificados
- [ ] Monitoramento com alertas ativos
- [ ] Portas não utilizadas fechadas
- [ ] Serviços não necessários desabilitados
- [ ] Logs centralizados e rotacionados
- [ ] Atualizações automáticas de segurança configuradas

---

## Cronograma Estimado

| Fase | Duração | Dependências |
|---|---|---|
| Fase 1 - Rede | 1 dia | Equipamentos disponíveis |
| Fase 2 - Proxmox | 2 horas | Fase 1 |
| Fase 3 - OPNsense | 4 horas | Fase 2 |
| Fase 4 - Containers | 2 horas | Fase 3 |
| Fase 5 - Web Server | 4 horas | Fase 4 |
| Fase 6 - MySQL | 2 horas | Fase 4 |
| Fase 7 - Deploy Apps | 4 horas | Fase 5, 6 |
| Fase 8 - Backup | 2 horas | Fase 7 |
| Fase 9 - Monitoring | 2 horas | Fase 4 |
| Fase 10 - VPN | 2 horas | Fase 3 |
| Fase 11 - Hardening | 4 horas | Todas |
| **TOTAL** | **~3 dias** | |
