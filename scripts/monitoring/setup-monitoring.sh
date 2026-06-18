#!/bin/bash
# =============================================================================
# GROM SERVER - Setup Monitoramento
# Executar DENTRO do container CT113 (grom-monitor)
# TOTALMENTE AUTOMATIZADO - Netdata + Uptime Kuma + Alertas
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

DOMAIN="${GROM_DOMAIN:-grom.seg.br}"
ALERT_EMAIL="${GROM_ALERT_EMAIL:-grom.servidor@gmail.com}"

log() { echo -e "\033[0;32m[✓]\033[0m $1"; }
info() { echo -e "\033[0;34m[i]\033[0m $1"; }

echo "============================================"
echo "  GROM SERVER - Setup Monitoramento"
echo "============================================"

# 1. Atualizar sistema
apt-get update -qq && apt-get upgrade -y -qq

# 2. Instalar Netdata
info "Instalando Netdata..."
wget -qO /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
bash /tmp/netdata-kickstart.sh --stable-channel --dont-wait
log "Netdata instalado (porta 19999)"

# 3. Instalar Docker para Uptime Kuma
info "Instalando Docker..."
apt-get install -y -qq docker.io
systemctl enable docker
systemctl start docker
log "Docker instalado"

# 4. Instalar Uptime Kuma
info "Instalando Uptime Kuma..."
docker run -d \
    --name uptime-kuma \
    --restart always \
    -p 3001:3001 \
    -v uptime-kuma-data:/app/data \
    louislam/uptime-kuma:1
log "Uptime Kuma instalado (porta 3001)"

# 5. Configurar alertas automáticos
info "Configurando alertas Netdata..."
cat > /etc/netdata/health_alarm_notify.conf << 'ALERTEOF'
# Email
SEND_EMAIL="YES"
DEFAULT_RECIPIENT_EMAIL="__GROM_ALERT_EMAIL__"
EMAIL_SENDER="__GROM_ALERT_EMAIL__"

# Apenas alertas críticos e warnings
SEND_CLEAR="NO"
SEND_WARNING="YES"
SEND_CRITICAL="YES"
ALERTEOF
sed -i "s/__GROM_ALERT_EMAIL__/${ALERT_EMAIL//\//\\/}/g" /etc/netdata/health_alarm_notify.conf

# 6. Alarmes customizados para o Grom Server
mkdir -p /etc/netdata/health.d/
cat > /etc/netdata/health.d/grom-custom.conf << 'HEALTHEOF'
# Alarme: Disco > 85%
alarm: grom_disk_full
    on: disk.space
lookup: max -1m at -1m unaligned of avail
 units: GiB
 every: 1m
  warn: $this < 20
  crit: $this < 10
 delay: up 1m down 15m
  info: Espaço em disco baixo

# Alarme: RAM > 90%
alarm: grom_ram_high
    on: system.ram
lookup: average -5m unaligned of used
 units: MiB
 every: 1m
  warn: $this > ($ram.total * 85 / 100)
  crit: $this > ($ram.total * 95 / 100)
 delay: up 5m down 15m
  info: Uso de RAM alto

# Alarme: CPU > 90% por 10 minutos
alarm: grom_cpu_high
    on: system.cpu
lookup: average -10m unaligned of user,system
 units: %
 every: 1m
  warn: $this > 85
  crit: $this > 95
 delay: up 10m down 15m
  info: CPU em uso alto
HEALTHEOF

systemctl restart netdata
log "Alertas Netdata configurados"

# 7. Auto-monitoramento (watchdog para serviços críticos)
cat > /usr/local/bin/grom-watchdog.sh << 'WATCHEOF'
#!/bin/bash
# =============================================================================
# GROM SERVER - Watchdog Automático
# Monitora servicos e reinicia apenas servicos locais.
# =============================================================================

LOG="/var/log/grom-watchdog.log"

check_and_alert() {
    local HOST=$1 PORT=$2 SERVICE=$3 CONTAINER=$4
    
    if ! timeout 5 bash -c "echo >/dev/tcp/${HOST}/${PORT}" 2>/dev/null; then
        echo "[$(date)] ALERTA: ${SERVICE} em ${HOST}:${PORT} nao responde" >> "$LOG"
        
        if [ "$CONTAINER" = "local" ]; then
            systemctl restart "$SERVICE" 2>/dev/null
            sleep 10
        fi
        
        if timeout 5 bash -c "echo >/dev/tcp/${HOST}/${PORT}" 2>/dev/null; then
            echo "[$(date)] OK: ${SERVICE} voltou a responder" >> "$LOG"
        else
            echo "[$(date)] CRITICO: ${SERVICE} continua indisponivel" >> "$LOG"
            echo "GROM ALERT: ${SERVICE} em ${HOST}:${PORT} indisponivel" | \
                mail -s "CRITICO: ${SERVICE} offline" "__GROM_ALERT_EMAIL__" 2>/dev/null || true
        fi
    fi
}

# Verificar serviços
check_and_alert "10.0.1.10" "80"    "nginx"        "remote"
check_and_alert "10.0.1.11" "3306"  "mysql"        "remote"
check_and_alert "10.0.1.14" "51820" "wg-quick@wg0" "remote"
check_and_alert "localhost" "19999" "netdata"      "local"
check_and_alert "localhost" "3001"  "uptime-kuma"  "local"
WATCHEOF
sed -i "s/__GROM_ALERT_EMAIL__/${ALERT_EMAIL//\//\\/}/g" /usr/local/bin/grom-watchdog.sh
chmod +x /usr/local/bin/grom-watchdog.sh

# Watchdog a cada 3 minutos
cat > /etc/cron.d/grom-watchdog << 'CRONEOF'
*/3 * * * * root /usr/local/bin/grom-watchdog.sh
CRONEOF
log "Watchdog automático configurado (a cada 3 min)"

# 8. Firewall
apt-get install -y -qq ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow from 10.0.1.0/24 to any port 22
ufw allow from 10.0.1.0/24 to any port 19999
ufw allow from 10.0.1.0/24 to any port 3001
ufw allow from 10.0.10.0/24 to any port 19999
ufw allow from 10.0.10.0/24 to any port 3001
echo "y" | ufw enable
log "Firewall configurado"

echo ""
echo "============================================"
echo "  ✅ Monitoramento configurado!"
echo ""
echo "  Netdata:     http://10.0.1.13:19999"
echo "  Uptime Kuma: http://10.0.1.13:3001"
echo ""
echo "  Watchdog: alerta serviços remotos e reinicia apenas serviços locais"
echo "  Alertas: email para ${ALERT_EMAIL}"
echo "============================================"
