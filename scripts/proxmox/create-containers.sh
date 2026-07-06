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
LOCAL_TEMPLATE_CANDIDATE="/root/grom-scripts/downloads/templates/${TEMPLATE_FILE}"
GATEWAY="10.0.1.1"
DNS="10.0.1.1"
SEARCH_DOMAIN="grom.seg.br"
SSH_KEY_FILE="/root/.ssh/id_ed25519.pub"

echo "============================================"
echo "  GROM SERVER - Criação de Containers"
echo "============================================"
echo ""

# -----------------------------------------------------------------------------
# 1. Download do template Ubuntu 24.04
# -----------------------------------------------------------------------------
if [ ! -f "$TEMPLATE_PATH" ]; then
    if [ -f "$LOCAL_TEMPLATE_CANDIDATE" ]; then
        info "Copiando template Ubuntu 24.04 LTS do kit offline..."
        cp "$LOCAL_TEMPLATE_CANDIDATE" "$TEMPLATE_PATH"
        log "Template copiado"
    else
        info "Baixando template Ubuntu 24.04 LTS..."
        wget -q "$TEMPLATE_URL" -O "$TEMPLATE_PATH"
        log "Template baixado"
    fi
else
    log "Template Ubuntu 24.04 já existe"
fi

# -----------------------------------------------------------------------------
# 2. Gerar chave SSH se não existir
# -----------------------------------------------------------------------------
if [ ! -f "$SSH_KEY_FILE" ]; then
    info "Gerando chave SSH..."
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -C "grom-admin@grom-pve"
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
    local FEATURES="${8:-}"
    local PCT_FEATURES=()

    if [ -n "$FEATURES" ]; then
        PCT_FEATURES=(--features "$FEATURES")
    fi

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
        --protection 1 \
        "${PCT_FEATURES[@]}"

    log "Container $CTID ($NAME) criado"
}

# CT110 - Web Server (Nginx + PHP + Python)
create_container 110 "grom-web" 2560 3 60 "10.0.1.10" \
    "Servidor Web - Nginx + PHP 8.3 + Python 3.12 | Grom.Seg"

# CT111 - MySQL Database
create_container 111 "grom-db" 2048 2 100 "10.0.1.11" \
    "Banco de Dados MySQL 8.0 | grom_seg + legados"

# CT112 - Backup Server
create_container 112 "grom-backup" 512 1 16 "10.0.1.12" \
    "Orquestracao de Backup - BorgBackup + rsync | Unidade USB 1TB"

# CT113 - Monitoring
create_container 113 "grom-monitor" 512 1 12 "10.0.1.13" \
    "Monitoramento - Netdata + Uptime Kuma" "nesting=1"

# CT114 - WireGuard VPN
create_container 114 "grom-vpn" 384 1 4 "10.0.1.14" \
    "VPN WireGuard | Acesso remoto seguro"

# -----------------------------------------------------------------------------
# 4. Configurações especiais
# -----------------------------------------------------------------------------

# CT112 (Backup) - Bind mount para HD externo
info "Configurando bind mount do HD externo para CT112..."
if [ -d "/mnt/backup-external" ]; then
    grep -q "mp0" /etc/pve/lxc/112.conf 2>/dev/null || \
        echo "mp0: /mnt/backup-external,mp=/mnt/external" >> /etc/pve/lxc/112.conf
    log "Bind mount configurado para CT112"
else
    warn "Diretório /mnt/backup-external não encontrado. Monte o HD externo antes."
fi

if [ -d "/mnt/backup-external-2" ]; then
    grep -q "mp1" /etc/pve/lxc/112.conf 2>/dev/null || \
        echo "mp1: /mnt/backup-external-2,mp=/mnt/external2" >> /etc/pve/lxc/112.conf
    log "Segundo bind mount de backup configurado para CT112"
else
    warn "Segundo HD externo opcional nao encontrado em /mnt/backup-external-2."
fi

# CT114 (VPN) - Habilitar TUN/TAP para WireGuard
info "Habilitando TUN/TAP para WireGuard..."
grep -q "lxc.cgroup2.devices.allow" /etc/pve/lxc/114.conf 2>/dev/null || {
    cat >> /etc/pve/lxc/114.conf << 'EOF'
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF
}
log "TUN/TAP habilitado para CT114"

# -----------------------------------------------------------------------------
# 5. Configurar ordem de boot
# -----------------------------------------------------------------------------
info "Configurando ordem de boot..."
# OPNsense primeiro (VM 100), depois containers na ordem
qm set 100 --startup order=1,up=30 2>/dev/null || true
pct set 110 --startup order=2,up=15 2>/dev/null || true  # Web
pct set 111 --startup order=2,up=15 2>/dev/null || true  # DB
pct set 112 --startup order=3,up=10 2>/dev/null || true  # Backup
pct set 113 --startup order=3,up=10 2>/dev/null || true  # Monitoring
pct set 114 --startup order=2,up=15 2>/dev/null || true  # VPN
log "Ordem de boot configurada"

# -----------------------------------------------------------------------------
# 6. Iniciar containers
# -----------------------------------------------------------------------------
info "Iniciando containers..."
for ctid in 110 111 112 113 114; do
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
echo "  VM100 - opnsense    (10.0.1.1)  - Firewall"
echo "  CT110 - grom-web    (10.0.1.10) - Grom.Seg Web Server"
echo "  CT111 - grom-db     (10.0.1.11) - MySQL"
echo "  CT112 - grom-backup (10.0.1.12) - Backup"
echo "  CT113 - grom-monitor(10.0.1.13) - Monitoring"
echo "  CT114 - grom-vpn    (10.0.1.14) - WireGuard"
echo ""
echo "  Próximo passo: Executar scripts de setup em cada container"
echo "  Ex: pct exec 110 -- bash /tmp/setup-nginx.sh"
echo ""
