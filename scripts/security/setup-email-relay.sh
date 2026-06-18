#!/bin/bash
# =============================================================================
# GROM SERVER - Configuracao de relay SMTP via Gmail com msmtp
# Nao armazena senha no repositorio. Requer GROM_SMTP_APP_PASS no ambiente.
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SMTP_USER="${GROM_SMTP_USER:-grom.servidor@gmail.com}"
SMTP_FROM="${GROM_SMTP_FROM:-$SMTP_USER}"
ALERT_EMAIL="${GROM_ALERT_EMAIL:-grom.servidor@gmail.com}"
SMTP_PASS="${GROM_SMTP_APP_PASS:-}"

log() { echo -e "\033[0;32m[✓]\033[0m $1"; }
warn() { echo -e "\033[1;33m[!]\033[0m $1"; }
info() { echo -e "\033[0;34m[i]\033[0m $1"; }

echo "============================================"
echo "  GROM SERVER - Email Relay"
echo "============================================"

if [ -z "$SMTP_PASS" ]; then
    warn "GROM_SMTP_APP_PASS nao definido. Pulando configuracao SMTP."
    warn "Crie senha de app no Google e defina em /etc/grom/grom.env no servidor."
    exit 0
fi

info "Instalando msmtp/mailutils..."
apt-get update -qq
apt-get install -y -qq msmtp msmtp-mta mailutils ca-certificates

install -d -m 750 /etc/grom

cat > /etc/msmtprc << EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           ${SMTP_FROM}
user           ${SMTP_USER}
password       ${SMTP_PASS}

account default : gmail
aliases        /etc/aliases
EOF

chmod 600 /etc/msmtprc
touch /var/log/msmtp.log
chmod 640 /var/log/msmtp.log

cat > /etc/aliases << EOF
default: ${ALERT_EMAIL}
root: ${ALERT_EMAIL}
EOF

log "Relay SMTP configurado para ${SMTP_USER}"

if echo "GROM SERVER: teste de email em $(hostname) - $(date)" | \
    mail -s "GROM SERVER - teste SMTP" "$ALERT_EMAIL" 2>/dev/null; then
    log "Email de teste enviado para ${ALERT_EMAIL}"
else
    warn "Nao foi possivel enviar email de teste. Verificar senha de app, 2FA e logs em /var/log/msmtp.log."
fi
