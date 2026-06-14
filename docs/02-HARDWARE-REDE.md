# 🔌 Hardware e Configuração de Rede

## Hardware Principal

### Beelink Mini PC
| Especificação | Detalhe |
|---|---|
| **Processador** | Intel Core i5-1035G7 (4C/8T, 1.2-3.7GHz) |
| **RAM** | 16GB DDR4 |
| **SSD** | 1TB NVMe |
| **Ethernet** | 1x RJ45 Gigabit |
| **Virtualização** | VT-x e VT-d suportados ✅ |

### Adaptador Ugreen USB-A 3.0 para LAN RJ45 2.5G
- Chip: RTL8156B (suportado nativo Linux 5.x+)
- Velocidade: 2.5 Gbps

### Switch TP-Link TL-SG108
- 8 portas Gigabit Ethernet
- Não-gerenciável (plug and play)
- Posição: Conectado à saída LAN (adaptador USB Ugreen)
- Função: Distribuir rede LAN interna para dispositivos físicos

### Backup: HD Externo 1TB USB 3.0

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

## Topologia de Rede

```
[ISP 650Mbps] → [Mercusys AX3000 (AP Mode)] → Cat6 → [Mini PC ETH0 = WAN]
                                                       [Mini PC USB Ugreen = LAN]
                                                              ↓
                                                  [Switch TP-Link TL-SG108]
                                                     ↓ (dispositivos LAN)
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
| Cabos Cat6 (3x) | Conexões físicas (roteador+switch+mini pc) | R$ 45 |
| **Nobreak 600VA+** | Proteção contra queda de energia ⚠️ | R$ 250-400 |

### Futuro
| Equipamento | Motivo | Custo Est. |
|---|---|---|
| Switch Gerenciável 8p | Substituir TL-SG108 para VLANs | R$ 300-500 |
| HD Externo 2TB extra | Rotação de backup | R$ 350 |

> ⚠️ **CRÍTICO**: Nobreak é ESSENCIAL - quedas de energia corrompem filesystem e bancos de dados.
