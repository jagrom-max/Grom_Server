#!/bin/bash
# =============================================================================
# GROM SERVER - Setup WireGuard VPN
# Executar DENTRO do container CT114 (grom-vpn)
# TOTALMENTE AUTOMATIZADO - Gera server + 5 configs de cliente
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

DOMAIN="grom.seg.br"
VPN_SUBNET="10.0.10"
VPN_PORT="51820"
LAN_SUBNET="10.0.1.0/24"
NUM_CLIENTS=5

log() { echo -e "\033[0;32m[✓]\033[0m $1"; }
info() { echo -e "\033[0;34m[i]\033[0m $1"; }
warn() { echo -e "\033[1;33m[!]\033[0m $1"; }

echo "============================================"
echo "  GROM SERVER - Setup WireGuard VPN"
echo "============================================"

# 1. Instalar WireGuard
info "Instalando WireGuard..."
apt-get update -qq
apt-get install -y -qq wireguard wireguard-tools qrencode iptables
log "WireGuard instalado"

# 2. Habilitar IP forwarding
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
sysctl --system >/dev/null 2>&1
log "IP forwarding habilitado"

# 3. Gerar chaves do servidor
info "Gerando chaves do servidor..."
cd /etc/wireguard
umask 077

wg genkey | tee server_private.key | wg pubkey > server_public.key
SERVER_PRIVATE=$(cat server_private.key)
SERVER_PUBLIC=$(cat server_public.key)
log "Chaves do servidor geradas"

# 4. Gerar chaves dos clientes
info "Gerando chaves de ${NUM_CLIENTS} clientes..."
mkdir -p /etc/wireguard/clients
chmod 700 /etc/wireguard/clients

PEER_CONFIGS=""
CLIENT_NAMES=("admin-principal" "notebook" "celular-1" "celular-2" "emergencia")

for i in $(seq 1 $NUM_CLIENTS); do
    CLIENT_NAME="${CLIENT_NAMES[$((i-1))]}"
    CLIENT_IP="${VPN_SUBNET}.$((i+1))"
    
    wg genkey | tee "clients/${CLIENT_NAME}_private.key" | wg pubkey > "clients/${CLIENT_NAME}_public.key"
    wg genpsk > "clients/${CLIENT_NAME}_preshared.key"
    
    CLIENT_PRIVATE=$(cat "clients/${CLIENT_NAME}_private.key")
    CLIENT_PUBLIC=$(cat "clients/${CLIENT_NAME}_public.key")
    CLIENT_PSK=$(cat "clients/${CLIENT_NAME}_preshared.key")
    
    # Config do cliente
    cat > "clients/${CLIENT_NAME}.conf" << CLIENTEOF
# =============================================================================
# GROM VPN - Cliente: ${CLIENT_NAME}
# Importar este arquivo no app WireGuard do dispositivo
# =============================================================================

[Interface]
PrivateKey = ${CLIENT_PRIVATE}
Address = ${CLIENT_IP}/24
DNS = 10.0.1.1

[Peer]
PublicKey = ${SERVER_PUBLIC}
PresharedKey = ${CLIENT_PSK}
Endpoint = vpn.${DOMAIN}:${VPN_PORT}
AllowedIPs = ${LAN_SUBNET}, ${VPN_SUBNET}.0/24
PersistentKeepalive = 25
CLIENTEOF

    # Gerar QR code para mobile
    qrencode -t ansiutf8 < "clients/${CLIENT_NAME}.conf" > "clients/${CLIENT_NAME}_qr.txt" 2>/dev/null || true
    
    # Adicionar peer à config do servidor
    PEER_CONFIGS+="
# Cliente: ${CLIENT_NAME} (${CLIENT_IP})
[Peer]
PublicKey = ${CLIENT_PUBLIC}
PresharedKey = ${CLIENT_PSK}
AllowedIPs = ${CLIENT_IP}/32
"
    
    log "Cliente ${CLIENT_NAME} (${CLIENT_IP}) configurado"
done

# 5. Criar config do servidor
info "Criando configuração do servidor..."
INTERFACE=$(ip route show default | awk '{print $5}' | head -1)
INTERFACE=${INTERFACE:-eth0}

cat > /etc/wireguard/wg0.conf << SERVEREOF
# =============================================================================
# GROM SERVER - WireGuard VPN Server
# Domínio: vpn.${DOMAIN}
# =============================================================================

[Interface]
Address = ${VPN_SUBNET}.1/24
ListenPort = ${VPN_PORT}
PrivateKey = ${SERVER_PRIVATE}

# Regras de firewall automaticas e log operacional
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${INTERFACE} -j MASQUERADE; /bin/sh -c 'echo "[\$(date)] WireGuard UP" >> /var/log/wireguard.log'
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${INTERFACE} -j MASQUERADE; /bin/sh -c 'echo "[\$(date)] WireGuard DOWN" >> /var/log/wireguard.log'
${PEER_CONFIGS}
SERVEREOF

chmod 600 /etc/wireguard/wg0.conf
log "Configuração do servidor criada"

# 6. Ativar WireGuard
info "Ativando WireGuard..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
log "WireGuard ativo e habilitado no boot"

# 7. Firewall
apt-get install -y -qq ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ${VPN_PORT}/udp
ufw allow from 10.0.1.0/24 to any port 22
echo "y" | ufw enable
log "Firewall configurado"

# 8. Script para adicionar novos clientes
cat > /usr/local/bin/grom-vpn-add-client.sh << 'ADDEOF'
#!/bin/bash
# Uso: grom-vpn-add-client.sh <nome-do-cliente>
set -euo pipefail
CLIENT_NAME="$1"
[ -z "$CLIENT_NAME" ] && { echo "Uso: $0 <nome>"; exit 1; }

cd /etc/wireguard
NEXT_IP=$(grep -c "^\[Peer\]" wg0.conf)
NEXT_IP=$((NEXT_IP + 2))
CLIENT_IP="10.0.10.${NEXT_IP}"

wg genkey | tee "clients/${CLIENT_NAME}_private.key" | wg pubkey > "clients/${CLIENT_NAME}_public.key"
wg genpsk > "clients/${CLIENT_NAME}_preshared.key"

PRIV=$(cat "clients/${CLIENT_NAME}_private.key")
PUB=$(cat "clients/${CLIENT_NAME}_public.key")
PSK=$(cat "clients/${CLIENT_NAME}_preshared.key")
SERVER_PUB=$(cat server_public.key)

cat > "clients/${CLIENT_NAME}.conf" << EOF
[Interface]
PrivateKey = ${PRIV}
Address = ${CLIENT_IP}/24
DNS = 10.0.1.1

[Peer]
PublicKey = ${SERVER_PUB}
PresharedKey = ${PSK}
Endpoint = vpn.grom.seg.br:51820
AllowedIPs = 10.0.1.0/24, 10.0.10.0/24
PersistentKeepalive = 25
EOF

cat >> /etc/wireguard/wg0.conf << EOF

# Cliente: ${CLIENT_NAME} (${CLIENT_IP})
[Peer]
PublicKey = ${PUB}
PresharedKey = ${PSK}
AllowedIPs = ${CLIENT_IP}/32
EOF

wg syncconf wg0 <(wg-quick strip wg0)
qrencode -t ansiutf8 < "clients/${CLIENT_NAME}.conf"
echo "✅ Cliente ${CLIENT_NAME} adicionado (${CLIENT_IP})"
ADDEOF
chmod +x /usr/local/bin/grom-vpn-add-client.sh
log "Script de adição de clientes instalado"

# 9. Script para revogar clientes
cat > /usr/local/bin/grom-vpn-revoke-client.sh << 'REVOKEEOF'
#!/bin/bash
# Uso: grom-vpn-revoke-client.sh <nome-do-cliente>
set -euo pipefail
CLIENT_NAME="${1:-}"
[ -z "$CLIENT_NAME" ] && { echo "Uso: $0 <nome>"; exit 1; }

cd /etc/wireguard
CLIENT_CONF="clients/${CLIENT_NAME}.conf"
CLIENT_PUB_FILE="clients/${CLIENT_NAME}_public.key"

if [ ! -f "$CLIENT_PUB_FILE" ]; then
    echo "Cliente nao encontrado: ${CLIENT_NAME}" >&2
    exit 1
fi

PUB=$(cat "$CLIENT_PUB_FILE")
wg set wg0 peer "$PUB" remove 2>/dev/null || true

awk -v client="Cliente: ${CLIENT_NAME}" '
    $0 ~ "^# " client " " { skip=1; next }
    skip && $0 == "[Peer]" { next }
    skip && /^PublicKey|^PresharedKey|^AllowedIPs/ { next }
    skip && NF == 0 { skip=0; next }
    !skip { print }
' wg0.conf > wg0.conf.tmp
install -m 600 wg0.conf.tmp wg0.conf
rm -f wg0.conf.tmp "$CLIENT_CONF" "clients/${CLIENT_NAME}_private.key" "clients/${CLIENT_NAME}_public.key" "clients/${CLIENT_NAME}_preshared.key" "clients/${CLIENT_NAME}_qr.txt"
echo "Cliente ${CLIENT_NAME} revogado"
REVOKEEOF
chmod +x /usr/local/bin/grom-vpn-revoke-client.sh
log "Script de revogação de clientes instalado"

# 10. Monitoramento automático de VPN
cat > /etc/cron.d/grom-vpn << 'CRONEOF'
# Verificar status do WireGuard a cada 5 minutos e reiniciar se necessário
*/5 * * * * root wg show wg0 > /dev/null 2>&1 || (systemctl restart wg-quick@wg0 && echo "[$(date)] WireGuard auto-restarted" >> /var/log/wireguard.log)
CRONEOF
log "Auto-recovery de VPN configurado"

echo ""
echo "============================================"
echo "  ✅ WireGuard VPN configurado!"
echo ""
echo "  Servidor: vpn.${DOMAIN}:${VPN_PORT}"
echo "  Subnet: ${VPN_SUBNET}.0/24"
echo ""
echo "  Clientes criados:"
for i in $(seq 1 $NUM_CLIENTS); do
    echo "    ${CLIENT_NAMES[$((i-1))]}: ${VPN_SUBNET}.$((i+1))"
done
echo ""
echo "  Configs em: /etc/wireguard/clients/"
echo "  Adicionar novo: grom-vpn-add-client.sh <nome>"
echo "============================================"
