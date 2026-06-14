#!/bin/bash
# =============================================================================
# GROM SERVER - Proxmox VE Pós-Instalação
# Execução: bash post-install.sh
# Descrição: Configura o Proxmox VE após instalação limpa
# TOTALMENTE AUTOMATIZADO - Sem interação humana necessária
# =============================================================================

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

echo "============================================"
echo "  GROM SERVER - Proxmox Pós-Instalação"
echo "============================================"
echo ""

# -----------------------------------------------------------------------------
# 1. Remover repositório Enterprise (requer assinatura paga)
# -----------------------------------------------------------------------------
info "Configurando repositórios..."

# Desabilitar enterprise repo
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
    log "Repositório enterprise desabilitado"
fi

if [ -f /etc/apt/sources.list.d/ceph.list ]; then
    sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/ceph.list
    log "Repositório Ceph enterprise desabilitado"
fi

# Adicionar repositório no-subscription
PVE_NOSUB="/etc/apt/sources.list.d/pve-no-subscription.list"
if [ ! -f "$PVE_NOSUB" ] || ! grep -q "pve-no-subscription" "$PVE_NOSUB" 2>/dev/null; then
    echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > "$PVE_NOSUB"
    log "Repositório no-subscription adicionado"
fi

# -----------------------------------------------------------------------------
# 2. Remover popup de assinatura na WebGUI
# -----------------------------------------------------------------------------
info "Removendo popup de assinatura..."

JS_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
if [ -f "$JS_FILE" ]; then
    cp "$JS_FILE" "${JS_FILE}.bak"
    sed -Ei "s/res === null \|\| res === undefined \|\| \!res || res.data.status.toLowerCase\(\) !== 'active'/false/g" "$JS_FILE" 2>/dev/null || true
    log "Popup de assinatura removido"
fi

# -----------------------------------------------------------------------------
# 3. Atualizar sistema
# -----------------------------------------------------------------------------
info "Atualizando sistema (pode levar alguns minutos)..."
apt-get update -y >/dev/null 2>&1
apt-get dist-upgrade -y >/dev/null 2>&1
log "Sistema atualizado"

# -----------------------------------------------------------------------------
# 4. Instalar pacotes úteis
# -----------------------------------------------------------------------------
info "Instalando pacotes essenciais..."
apt-get install -y \
    vim \
    htop \
    iotop \
    iftop \
    tmux \
    curl \
    wget \
    git \
    net-tools \
    dnsutils \
    smartmontools \
    lm-sensors \
    ethtool \
    unzip \
    sudo \
    libguestfs-tools \
    >/dev/null 2>&1
log "Pacotes essenciais instalados"

# -----------------------------------------------------------------------------
# 5. Habilitar IOMMU (necessário para PCI passthrough)
# -----------------------------------------------------------------------------
info "Configurando IOMMU..."

GRUB_FILE="/etc/default/grub"
if ! grep -q "intel_iommu=on" "$GRUB_FILE"; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"/' "$GRUB_FILE"
    update-grub >/dev/null 2>&1
    log "IOMMU habilitado (requer reboot)"
fi

# Carregar módulos VFIO
MODULES_FILE="/etc/modules"
for mod in vfio vfio_iommu_type1 vfio_pci vfio_virqfd; do
    grep -qxF "$mod" "$MODULES_FILE" || echo "$mod" >> "$MODULES_FILE"
done
log "Módulos VFIO configurados"

# -----------------------------------------------------------------------------
# 6. Configurar NTP (sincronização de tempo)
# -----------------------------------------------------------------------------
info "Configurando NTP..."
timedatectl set-ntp true
timedatectl set-timezone America/Sao_Paulo
log "NTP configurado (America/Sao_Paulo)"

# -----------------------------------------------------------------------------
# 7. Configurar email para alertas (postfix relay)
# -----------------------------------------------------------------------------
info "Preparando sistema de alertas por email..."
apt-get install -y libsasl2-modules mailutils >/dev/null 2>&1 || true
log "Pacotes de email instalados (configurar SMTP relay manualmente)"

# -----------------------------------------------------------------------------
# 8. Otimizações de performance
# -----------------------------------------------------------------------------
info "Aplicando otimizações..."

# Aumentar limites de arquivos abertos
cat > /etc/security/limits.d/99-grom.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF

# Otimizar sysctl para rede
cat > /etc/sysctl.d/99-grom-network.conf << 'EOF'
# GROM SERVER - Otimizações de rede
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
# Proteção contra ataques
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF
sysctl --system >/dev/null 2>&1
log "Otimizações de rede aplicadas"

# -----------------------------------------------------------------------------
# 9. Configurar SMART monitoring para SSD
# -----------------------------------------------------------------------------
info "Configurando monitoramento SMART do SSD..."
systemctl enable smartd >/dev/null 2>&1 || true
log "SMART monitoring habilitado"

# -----------------------------------------------------------------------------
# 10. Configurar lm-sensors
# -----------------------------------------------------------------------------
info "Detectando sensores de temperatura..."
sensors-detect --auto >/dev/null 2>&1 || true
log "Sensores configurados"

# -----------------------------------------------------------------------------
# 11. Criar script de health-check automático
# -----------------------------------------------------------------------------
info "Configurando health-check automático..."
cat > /usr/local/bin/grom-health-check.sh << 'HEALTHEOF'
#!/bin/bash
# GROM SERVER - Health Check Automático
# Executado via cron a cada 6 horas

ALERT_EMAIL="${GROM_ALERT_EMAIL:-root}"
HOSTNAME=$(hostname)
PROBLEMS=0
REPORT=""

check() {
    local name="$1" status="$2"
    if [ "$status" != "0" ]; then
        REPORT+="[FALHA] $name\n"
        ((PROBLEMS++))
    fi
}

# Verificar uso de disco (alerta se > 85%)
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
[ "$DISK_USAGE" -gt 85 ] && check "Disco raiz em ${DISK_USAGE}%" 1

# Verificar RAM (alerta se > 90%)
RAM_USAGE=$(free | awk '/Mem:/ {printf("%.0f", $3/$2 * 100)}')
[ "$RAM_USAGE" -gt 90 ] && check "RAM em ${RAM_USAGE}%" 1

# Verificar temperatura CPU (alerta se > 80°C)
if command -v sensors &>/dev/null; then
    TEMP=$(sensors 2>/dev/null | grep -oP '\+\K[0-9]+(?=\.[0-9]+°C)' | sort -rn | head -1)
    [ -n "$TEMP" ] && [ "$TEMP" -gt 80 ] && check "Temperatura CPU: ${TEMP}°C" 1
fi

# Verificar containers
for ctid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
    STATUS=$(pct status "$ctid" 2>/dev/null | awk '{print $2}')
    [ "$STATUS" != "running" ] && check "Container $ctid não está rodando (status: $STATUS)" 1
done

# Verificar VM OPNsense
VM_STATUS=$(qm status 100 2>/dev/null | awk '{print $2}')
[ "$VM_STATUS" != "running" ] && check "VM OPNsense não está rodando" 1

# Enviar alerta se houver problemas
if [ "$PROBLEMS" -gt 0 ]; then
    echo -e "⚠️ GROM SERVER - ${PROBLEMS} problema(s) detectado(s) em ${HOSTNAME}:\n\n${REPORT}" | \
        mail -s "⚠️ GROM SERVER ALERT - ${PROBLEMS} problema(s)" "$ALERT_EMAIL" 2>/dev/null || true
fi

exit $PROBLEMS
HEALTHEOF
chmod +x /usr/local/bin/grom-health-check.sh

# Agendar health-check a cada 6 horas
(crontab -l 2>/dev/null; echo "0 */6 * * * /usr/local/bin/grom-health-check.sh") | sort -u | crontab -
log "Health-check automático configurado (a cada 6h)"

# -----------------------------------------------------------------------------
# 12. Auto-start de VMs e Containers na boot
# -----------------------------------------------------------------------------
info "Configurando auto-start..."
# O Proxmox já suporta isso nativamente via opção --onboot
# Será configurado na criação de cada VM/container
log "Auto-start será configurado na criação das VMs/containers"

# =============================================================================
echo ""
echo "============================================"
echo "  ✅ Pós-instalação concluída!"
echo "============================================"
echo ""
echo "  Próximos passos:"
echo "  1. Configurar bridges de rede (vmbr0/vmbr1)"
echo "  2. Reiniciar: reboot"
echo "  3. Acessar WebGUI: https://<IP>:8006"
echo "  4. Executar create-containers.sh"
echo ""
warn "REBOOT NECESSÁRIO para aplicar IOMMU e módulos VFIO"
