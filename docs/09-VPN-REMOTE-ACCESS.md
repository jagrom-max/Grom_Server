# 🔐 VPN e Acesso Remoto

## Container LXC: CT104 - WireGuard VPN

| Parâmetro | Valor |
|---|---|
| **ID** | 104 |
| **Hostname** | grom-vpn |
| **SO** | Ubuntu 24.04 LTS |
| **RAM** | 512MB |
| **vCPU** | 1 |
| **Disco** | 5GB |
| **IP** | 10.0.1.14/24 |

---

## Por que WireGuard?

- **Rápido**: Criptografia moderna, baixa latência
- **Simples**: Configuração mínima, código auditável (~4000 linhas)
- **Seguro**: Criptografia state-of-the-art (ChaCha20, Curve25519)
- **Leve**: Consumo mínimo de recursos
- **Multiplataforma**: Windows, macOS, Linux, Android, iOS

---

## Instalação

```bash
apt update && apt install wireguard wireguard-tools -y
```

## Gerar Chaves do Servidor

```bash
cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
```

## Configuração do Servidor (`/etc/wireguard/wg0.conf`)

```ini
[Interface]
Address = 10.0.10.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Cliente 1 - Admin Principal
[Peer]
PublicKey = <CLIENT1_PUBLIC_KEY>
AllowedIPs = 10.0.10.2/32

# Cliente 2 - Notebook
[Peer]
PublicKey = <CLIENT2_PUBLIC_KEY>
AllowedIPs = 10.0.10.3/32

# Até 10 clientes simultâneos
```

## Ativar

```bash
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

---

## Configuração de Clientes

### Gerar chaves do cliente
```bash
wg genkey | tee client1_private.key | wg pubkey > client1_public.key
```

### Config do cliente
```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.0.10.2/24
DNS = 10.0.1.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <SEU_IP_PUBLICO_OU_DDNS>:51820
AllowedIPs = 10.0.0.0/8
PersistentKeepalive = 25
```

---

## DDNS (DNS Dinâmico)

Como o IP do ISP pode mudar, configurar DDNS:

### Opções Gratuitas:
1. **DuckDNS** (https://duckdns.org) - Simples e gratuito
2. **No-IP** - Gratuito com renovação mensal
3. **Cloudflare API** - Se tiver domínio próprio

### Cron para atualizar DuckDNS:
```bash
*/5 * * * * curl -s "https://www.duckdns.org/update?domains=gromserver&token=<TOKEN>&ip=" > /dev/null
```

---

## Acesso via VPN

Com VPN conectada, acessar todos os serviços internos:
- Proxmox: `https://10.0.1.100:8006`
- OPNsense: `https://10.0.1.1`
- Web apps: `http://10.0.1.10`
- Monitoring: `http://10.0.1.13:19999`

> ⚠️ O Proxmox e OPNsense NUNCA devem ser acessíveis sem VPN.
