# 🔌 Hardware e Configuração de Rede

## Hardware Principal

### HP EliteDesk 800 G4 Mini
| Especificação | Detalhe |
|---|---|
| **Processador** | Intel Core i7-8700T (6C/12T) |
| **RAM** | 16GB DDR4 |
| **SSD original** | 256GB; nao usar para a implantacao definitiva |
| **SSD definitivo** | 500GB |
| **Ethernet** | 1x RJ45 Gigabit |
| **Virtualização** | VT-x e VT-d suportados ✅ |
| **Video analitico** | Frigate/OpenVINO na iGPU Intel, condicionado a teste |

### Adaptador Ugreen USB-A 3.0 para LAN RJ45 2.5G
- Chip: RTL8156B (suportado nativo Linux 5.x+)
- Velocidade: 2.5 Gbps

### Switch TP-Link TL-SG108
- 8 portas Gigabit Ethernet
- Não-gerenciável (plug and play)
- Posição: Conectado à saída LAN (adaptador USB Ugreen)
- Função: Distribuir rede LAN interna para dispositivos físicos
- Status: **aprovado para a Fase 1** do projeto

### Backup: unidade externa de 1TB USB

- Uso exclusivo para backup operacional, `vzdump`, Borg e evidencias selecionadas.
- Nao usar como destino de gravacao continua do Frigate.
- Montagem esperada no host: `/mnt/backup-external`.
- O DVR Intelbras iMHDX 3008 permanece como gravador continuo principal.

---

## BIOS - Configurações Necessárias

```
BIOS → Advanced:
  Intel Virtualization Technology (VT-x) → ENABLED
  Intel VT-d → ENABLED
  Hyper-Threading → ENABLED
BIOS → Boot:
  UEFI Boot → ENABLED
  Secure Boot → DISABLED
BIOS → Power:
  Wake on LAN → ENABLED (opcional)
```

---

## Separação WAN/LAN com Duas Interfaces de Rede

### Por que o Adaptador Ugreen é Essencial

O HP EliteDesk possui **1 porta Ethernet onboard disponível para o projeto**. Para operar um firewall
real (OPNsense) é obrigatório ter **2 interfaces de rede fisicamente separadas**:

- **Interface WAN**: Recebe o tráfego da internet (não filtrado, potencialmente malicioso)
- **Interface LAN**: Distribui o tráfego já filtrado e autorizado para a rede interna

O adaptador Ugreen USB-A 3.0 para RJ45 2.5G **cria essa segunda interface**, permitindo
a separação física completa entre o tráfego externo e interno.

> ⚠️ **Sem o adaptador Ugreen, não é possível operar o OPNsense como firewall com
> separação real de redes.** As duas portas são indispensáveis.

### Atribuição das Interfaces

| Interface Física | Localização | Nome Linux | Bridge Proxmox | Função | Velocidade |
|---|---|---|---|---|---|
| **ETH onboard** | Porta RJ45 traseira do HP EliteDesk | `eth0` | `vmbr0` | **WAN** (Internet) | 1 Gbps |
| **Ugreen USB** | Conectado em porta USB-A 3.0 | `enx<MAC>` | `vmbr1` | **LAN** (Rede interna) | 2.5 Gbps |

### Por que essa distribuição?

- **ETH onboard → WAN**: A porta onboard é mais estável (driver nativo no kernel,
  nunca desconecta fisicamente). Se a WAN cair, perde-se internet — por isso usa-se
  a interface mais confiável.
- **Ugreen USB → LAN**: É mais rápida (2.5 Gbps vs 1 Gbps), ideal para o tráfego
  interno entre containers que é mais intenso. Se a USB desconectar momentaneamente,
  os containers continuam se comunicando via bridge virtual interna do Proxmox.

### Fluxo do Tráfego (passo a passo)

```
1. INTERNET (650 Mbps)
       │
       ▼
2. Mercusys AX3000 (modo Access Point - apenas repassa tráfego)
       │
       ▼ Cabo Cat6
3. ╔═══════════════════════════════════════════════════════════════╗
   ║  HP ELITEDESK - PORTA ONBOARD (eth0)  ←── ENTRADA WAN       ║
   ║       │                                                       ║
   ║       ▼                                                       ║
   ║  ┌─────────────────────────────────────────────────────────┐  ║
   ║  │  PROXMOX VE - vmbr0 (Bridge WAN)                       │  ║
   ║  │       │                                                 │  ║
   ║  │       ▼                                                 │  ║
   ║  │  ┌──────────────────────────────┐                       │  ║
   ║  │  │  OPNsense VM                 │                       │  ║
   ║  │  │  Interface WAN (vtnet0)      │                       │  ║
   ║  │  │       │                      │                       │  ║
   ║  │  │  [FIREWALL + IDS/IPS]        │  ← Filtra, analisa,  │  ║
   ║  │  │  [Suricata] [Regras]         │    bloqueia ameaças   │  ║
   ║  │  │       │                      │                       │  ║
   ║  │  │  Interface LAN (vtnet1)      │                       │  ║
   ║  │  └──────────┬───────────────────┘                       │  ║
   ║  │             │                                           │  ║
   ║  │             ▼                                           │  ║
   ║  │  PROXMOX VE - vmbr1 (Bridge LAN)                       │  ║
   ║  │       │         │         │         │         │         │  ║
   ║  │       ▼         ▼         ▼         ▼         ▼         │  ║
   ║  │    CT110     CT111     CT112     CT113     CT114        │  ║
   ║  │    Web       MySQL     Backup    Monitor   VPN          │  ║
   ║  │    .10       .11       .12       .13       .14          │  ║
   ║  └─────────────────────────────────────────────────────────┘  ║
   ║       │                                                       ║
   ║       ▼                                                       ║
   ║  HP ELITEDESK - USB UGREEN (enx...)  ←── SAÍDA LAN          ║
   ╚═══════════════════════════════════════════════════════════════╝
       │
       ▼ Cabo Cat6
4. Switch TP-Link TL-SG108 (8 portas)
       │         │         │
       ▼         ▼         ▼
   PC local   Impressora  Outros dispositivos
   (manutenção)            (conectados via cabo)
```

### Resultado: Segurança por Separação Física

**Nenhum pacote da internet chega à rede interna sem passar pelo firewall OPNsense.**

O OPNsense atua como o **único ponto de passagem** entre WAN e LAN:
- Analisa cada conexão de entrada com regras de firewall
- Executa IDS/IPS (Suricata) para detectar padrões maliciosos
- Aplica NAT para traduzir endereços
- Encaminha apenas o tráfego autorizado (port forwarding)
- Bloqueia todo o resto (política default deny)

### Papel do Switch TP-Link TL-SG108

O switch fica na **saída LAN** (porta Ugreen) e serve para:
- Conectar dispositivos físicos à rede interna (PC de manutenção, etc.)
- Expandir o número de portas LAN disponíveis (8 portas)
- Como é não-gerenciável, funciona plug-and-play sem configuração

> **Nota**: Os containers LXC não precisam do switch — eles se comunicam via bridge
> virtual (`vmbr1`) dentro do Proxmox. O switch é para dispositivos físicos externos.

### Restrições operacionais do switch atual

Como o switch atual não faz VLAN, a LAN física deve ser tratada como ambiente restrito:

- Conectar somente equipamentos necessários e confiáveis.
- Não ligar rede de visitantes, dispositivos pessoais desconhecidos ou IoT nesse switch.
- Preferir administração remota via WireGuard, mesmo quando estiver na rede local.
- Manter Proxmox, OPNsense, SSH, MySQL e monitoramento bloqueados para a internet.
- Quando a rede definitiva estiver pronta, migrar para switch gerenciável se houver necessidade de separar servidores, administração e usuários por VLAN.

---

## Topologia de Rede Resumida

```
[ISP 650Mbps] → [Mercusys AX3000 (AP)] → Cat6 → [HP EliteDesk ETH0 = WAN]
                                                    ↕ OPNsense Firewall
                                                  [HP EliteDesk USB Ugreen = LAN]
                                                         │ Cat6
                                                  [Switch TP-Link TL-SG108]
                                                    │ (dispositivos físicos)
```

### Endereçamento IP

| Rede | CIDR | Gateway | Função |
|---|---|---|---|
| WAN | DHCP do ISP | ISP | Internet |
| LAN Servidores | 10.0.1.0/24 | 10.0.1.1 | Rede interna |
| VPN | 10.0.10.0/24 | 10.0.10.1 | Clientes VPN |

### IPs Fixos dos Containers

| Host | IP | Função |
|---|---|---|
| OPNsense LAN | 10.0.1.1 | Gateway/Firewall |
| Web Server | 10.0.1.10 | Nginx+PHP+Python |
| MySQL Server | 10.0.1.11 | Banco de dados |
| Backup Server | 10.0.1.12 | BorgBackup |
| Monitoring | 10.0.1.13 | Netdata+Uptime Kuma |
| WireGuard | 10.0.1.14 | VPN |

---

## Proxmox Network Config (`/etc/network/interfaces`)

```bash
auto eth0
iface eth0 inet manual

auto enx<MAC>
iface enx<MAC> inet manual

# Bridge WAN
auto vmbr0
iface vmbr0 inet static
    address 192.168.0.100/24
    gateway 192.168.0.1
    bridge-ports eth0
    bridge-stp off
    bridge-fd 0

# Bridge LAN
auto vmbr1
iface vmbr1 inet manual
    bridge-ports enx<MAC>
    bridge-stp off
    bridge-fd 0
```

---

## Verificar Adaptador USB no Proxmox

```bash
ip link show
lsusb
dmesg | grep -i r8152
ethtool enxXXXXXXXXXXXX
```

---

## Mercusys AX3000 - Config como Access Point

1. Acessar `192.168.0.1` ou `mwlogin.net`
2. **Operation Mode** → **Access Point**
3. SSID: `Grom_Network`, WPA3/WPA2-Personal
4. Desabilitar DHCP (OPNsense será DHCP)

---

## Equipamentos Adicionais Recomendados

### Essenciais
| Equipamento | Motivo | Custo Est. |
|---|---|---|
| Cabos Cat6 (3x) | Conexões físicas (roteador+switch+HP EliteDesk) | R$ 45 |
| **Nobreak 600VA+** | Proteção contra queda de energia ⚠️ | R$ 250-400 |

### Futuro
| Equipamento | Motivo | Custo Est. |
|---|---|---|
| Switch Gerenciável 8p | Substituir TL-SG108 para VLANs | R$ 300-500 |
| HD Externo 2TB extra | Rotação de backup | R$ 350 |

> ⚠️ **CRÍTICO**: Nobreak é ESSENCIAL - quedas de energia corrompem filesystem e bancos de dados.
