#!/bin/bash
# =============================================================================
# GROM SERVER - Criação Automatizada de Containers LXC e VM
# Execução: bash create-containers.sh
# TOTALMENTE AUTOMATIZADO - Cria toda a infraestrutura de containers
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# Configurações
STORAGE="local-lvm"
TEMPLATE_URL="http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
TEMPLATE_FILE="ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
TEMPLATE_PATH="/var/lib/vz/template/cache/${TEMPLATE_FILE}"
GATEWAY="10.0.1.1"
DNS="10.0.1.1"
SEARCH_DOMAIN="grom.seg.br"
SSH_KEY_FILE="/root/.ssh/id_rsa.pub"

echo "============================================"
echo "  GROM SERVER - Criação de Containers"
echo "============================================"
echo ""

# -----------------------------------------------------------------------------
# 1. Download do template Ubuntu 24.04
# -----------------------------------------------------------------------------
if [ ! -f "$TEMPLATE_PATH" ]; then
    info "Baixando template Ubuntu 24.04 LTS..."
    wget -q "$TEMPLATE_URL" -O "$TEMPLATE_PATH"
    log "Template baixado"
else
    log "Template Ubuntu 24.04 já existe"
fi

# -----------------------------------------------------------------------------
# 2. Gerar chave SSH se não existir
# -----------------------------------------------------------------------------
if [ ! -f "$SSH_KEY_FILE" ]; then
    info "Gerando chave SSH..."
    ssh-keygen -t ed25519 -f /root/.ssh/id_rsa -N "" -C "grom-admin@grom-pve"
    log "Chave SSH gerada"
fi

# -----------------------------------------------------------------------------
# 3. Criar Containers
# -----------------------------------------------------------------------------

create_container() {
    local CTID=$1
    local NAME=$2
    local RAM=$3
    local CORES=$4
    local DISK=$5
    local IP=$6
    local DESC=$7

    if pct status "$CTID" >/dev/null 2>&1; then
        warn "Container $CTID ($NAME) já existe, pulando..."
        return
    fi

    info "Criando container $CTID - $NAME ($RAM MB RAM, $CORES vCPU, ${DISK}GB disco)..."

    pct create "$CTID" "$TEMPLATE_PATH" \
        --hostname "$NAME" \
        --description "$DESC" \
        --memory "$RAM" \
        --swap 512 \
        --cores "$CORES" \
        --rootfs "${STORAGE}:${DISK}" \
        --net0 "name=eth0,bridge=vmbr1,ip=${IP}/24,gw=${GATEWAY}" \
        --nameserver "$DNS" \
        --searchdomain "$SEARCH_DOMAIN" \
        --ssh-public-keys "$SSH_KEY_FILE" \
        --onboot 1 \
        --start 0 \
        --unprivileged 1 \
        --features "nesting=1" \
        --protection 1

    log "Container $CTID ($NAME) criado"
}

# CT100 - Web Server (Nginx + PHP + Python)
create_container 100 "grom-web" 4096 4 100 "10.0.1.10" \
    "Servidor Web - Nginx + PHP 8.3 + Python 3.12 | Grom_web + Grom Documental"

# CT101 - MySQL Database
create_container 101 "grom-db" 3072 2 200 "10.0.1.11" \
    "Banco de Dados MySQL 8.0 | grom_web + grom_documental"

# CT102 - Backup Server
create_container 102 "grom-backup" 1024 1 50 "10.0.1.12" \
    "Servidor de Backup - BorgBackup + rsync | HD Externo 1TB"

# CT103 - Monitoring
create_container 103 "grom-monitor" 1024 1 20 "10.0.1.13" \
    "Monitoramento - Netdata + Uptime Kuma"

# CT104 - WireGuard VPN
create_container 104 "grom-vpn" 512 1 5 "10.0.1.14" \
    "VPN WireGuard | Acesso remoto seguro"

# -----------------------------------------------------------------------------
# 4. Configurações especiais
# -----------------------------------------------------------------------------

# CT102 (Backup) - Bind mount para HD externo
info "Configurando bind mount do HD externo para CT102..."
if [ -d "/mnt/backup-external" ]; then
    grep -q "mp0" /etc/pve/lxc/102.conf 2>/dev/null || \
        echo "mp0: /mnt/backup-external,mp=/mnt/external" >> /etc/pve/lxc/102.conf
    log "Bind mount configurado para CT102"
else
    warn "Diretório /mnt/backup-external não encontrado. Monte o HD externo antes."
fi

# CT104 (VPN) - Habilitar TUN/TAP para WireGuard
info "Habilitando TUN/TAP para WireGuard..."
grep -q "lxc.cgroup2.devices.allow" /etc/pve/lxc/104.conf 2>/dev/null || {
    cat >> /etc/pve/lxc/104.conf << 'EOF'
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF
}
log "TUN/TAP habilitado para CT104"

# -----------------------------------------------------------------------------
# 5. Configurar ordem de boot
# -----------------------------------------------------------------------------
info "Configurando ordem de boot..."
# OPNsense primeiro (VM 100), depois containers na ordem
qm set 100 --startup order=1,up=30 2>/dev/null || true
pct set 100 --startup order=2,up=15 2>/dev/null || true  # Web
pct set 101 --startup order=2,up=15 2>/dev/null || true  # DB
pct set 102 --startup order=3,up=10 2>/dev/null || true  # Backup
pct set 103 --startup order=3,up=10 2>/dev/null || true  # Monitoring
pct set 104 --startup order=2,up=15 2>/dev/null || true  # VPN
log "Ordem de boot configurada"

# -----------------------------------------------------------------------------
# 6. Iniciar containers
# -----------------------------------------------------------------------------
info "Iniciando containers..."
for ctid in 100 101 102 103 104; do
    pct start "$ctid" 2>/dev/null || warn "Não foi possível iniciar CT${ctid}"
    sleep 5
done
log "Containers iniciados"

# =============================================================================
echo ""
echo "============================================"
echo "  ✅ Containers criados com sucesso!"
echo "============================================"
echo ""
echo "  Containers:"
echo "  CT100 - grom-web    (10.0.1.10) - Web Server"
echo "  CT101 - grom-db     (10.0.1.11) - MySQL"
echo "  CT102 - grom-backup (10.0.1.12) - Backup"
echo "  CT103 - grom-monitor(10.0.1.13) - Monitoring"
echo "  CT104 - grom-vpn    (10.0.1.14) - WireGuard"
echo ""
echo "  Próximo passo: Executar scripts de setup em cada container"
echo "  Ex: pct exec 100 -- bash /tmp/setup-nginx.sh"
echo ""
