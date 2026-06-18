#!/bin/bash
# =============================================================================
# GROM SERVER - Sincronizacao opcional para Google Drive via rclone crypt
# Requer remote criptografado configurado localmente, ex.: gromdrive_crypt:
# =============================================================================

set -euo pipefail

REMOTE="${GROM_RCLONE_REMOTE:-gromdrive_crypt:grom-server-backups}"
SOURCE="${GROM_RCLONE_SOURCE:-/mnt/backup}"
LOG_FILE="/var/log/grom-backup/google-drive.log"
ALERT_EMAIL="${GROM_ALERT_EMAIL:-grom.servidor@gmail.com}"

mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $1"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AVISO] $1"; }
error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERRO] $1"; }

echo ""
echo "=== Sync Google Drive criptografado ==="

if ! command -v rclone >/dev/null 2>&1; then
    warn "rclone nao instalado. Pulando sync externo."
    exit 0
fi

if ! rclone listremotes 2>/dev/null | grep -qx "${REMOTE%%:*}:"; then
    warn "Remote rclone nao configurado: ${REMOTE%%:*}:"
    warn "Configure um remote crypt antes de ativar sync externo."
    exit 0
fi

if [ ! -d "$SOURCE" ]; then
    error "Fonte nao existe: ${SOURCE}"
    exit 1
fi

if rclone sync "$SOURCE" "$REMOTE" \
    --fast-list \
    --transfers 2 \
    --checkers 4 \
    --log-level INFO \
    --exclude 'staging/**' \
    --exclude '*.tmp'; then
    log "Sync externo criptografado concluido para ${REMOTE}"
else
    error "Sync externo criptografado falhou"
    echo "GROM BACKUP: falha no sync Google Drive criptografado em $(hostname)" | \
        mail -s "GROM BACKUP - falha sync externo" "$ALERT_EMAIL" 2>/dev/null || true
    exit 1
fi
