#!/bin/bash
# =============================================================================
# GROM SERVER - Setup SSL/TLS com Let's Encrypt
# Executar DENTRO do container CT100 (grom-web)
# TOTALMENTE AUTOMATIZADO com renovação automática
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

DOMAIN="grom.seg.br"
EMAIL="admin@${DOMAIN}"

log() { echo -e "\033[0;32m[✓]\033[0m $1"; }
info() { echo -e "\033[0;34m[i]\033[0m $1"; }

echo "============================================"
echo "  GROM SERVER - Setup SSL/TLS"
echo "============================================"

# 1. Instalar Certbot
info "Instalando Certbot..."
apt-get install -y -qq certbot python3-certbot-nginx
log "Certbot instalado"

# 2. Obter certificados para todos os subdomínios
info "Obtendo certificados SSL..."
certbot --nginx --non-interactive --agree-tos \
    --email "${EMAIL}" \
    -d "web.${DOMAIN}" \
    -d "docs.${DOMAIN}" \
    --redirect \
    --staple-ocsp

log "Certificados SSL obtidos e configurados"

# 3. Verificar renovação automática
info "Testando renovação automática..."
certbot renew --dry-run
log "Renovação automática funcional"

# 4. Cron para verificação diária de renovação
# Certbot já instala timer systemd, mas garantir:
systemctl enable certbot.timer
systemctl start certbot.timer
log "Timer de renovação ativo"

# 5. Configurar DH params para segurança extra
info "Gerando Diffie-Hellman params (pode levar alguns minutos)..."
openssl dhparam -out /etc/nginx/dhparam.pem 2048 2>/dev/null
log "DH params gerados"

# 6. Adicionar SSL hardening ao Nginx
cat > /etc/nginx/snippets/ssl-hardening.conf << 'SSLEOF'
# SSL/TLS Hardening
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
ssl_dhparam /etc/nginx/dhparam.pem;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 1.1.1.1 8.8.8.8 valid=300s;
resolver_timeout 5s;
SSLEOF

nginx -t && systemctl reload nginx
log "SSL hardening aplicado"

echo ""
echo "  ✅ SSL/TLS configurado!"
echo "  web.${DOMAIN} → HTTPS ✅"
echo "  docs.${DOMAIN} → HTTPS ✅"
echo "  Renovação automática → ✅"
