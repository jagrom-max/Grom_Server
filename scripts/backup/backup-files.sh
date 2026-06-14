#!/bin/bash
# =============================================================================
# GROM SERVER - Backup Automático de Arquivos Web
# Executar DENTRO do container CT102 (grom-backup) via CRON
# TOTALMENTE AUTOMATIZADO
# =============================================================================

set -euo pipefail

DOMAIN="grom.seg.br"
WEB_SERVER="10.0.1.10"
BORG_REPO_WEB="/mnt/backup/borg-webfiles"
BORG_REPO_CONFIGS="/mnt/backup/borg-configs"
EXTERNAL_DIR="/mnt/external/webfiles"
LOG_FILE="/var/log/grom-backup/webfiles.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$(dirname "$LOG_FILE")" "$EXTERNAL_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $1"; }
error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERRO] $1"; }

echo ""
echo "=== Backup de Arquivos Web - ${TIMESTAMP} ==="

ERRORS=0

# 1. Backup dos arquivos web via rsync + BorgBackup
if [ -d "$BORG_REPO_WEB" ]; then
    export BORG_PASSPHRASE="${BORG_PASSPHRASE:-}"
    
    # Sincronizar arquivos do web server para staging local
    STAGING="/mnt/backup/staging/webfiles"
    mkdir -p "$STAGING"
    
    rsync -aze ssh --delete \
        "root@${WEB_SERVER}:/var/www/" "$STAGING/" 2>/dev/null || {
        error "rsync do web server falhou"
        ((ERRORS++))
    }
    
    # Criar backup incremental
    if borg create --compression zstd,6 --stats \
        "${BORG_REPO_WEB}::web-${TIMESTAMP}" \
        "$STAGING/" 2>/dev/null; then
        log "BorgBackup webfiles criado"
        
        borg prune --keep-daily=30 --keep-weekly=8 --keep-monthly=12 \
            "$BORG_REPO_WEB" 2>/dev/null
        log "Prune webfiles executado"
    else
        error "BorgBackup webfiles falhou"
        ((ERRORS++))
    fi
fi

# 2. Backup de configurações do sistema
CONFIGS_STAGING="/mnt/backup/staging/configs"
mkdir -p "$CONFIGS_STAGING"

# Coletar configs de todos os containers via SSH
for HOST in 10.0.1.10 10.0.1.11 10.0.1.14; do
    HOSTNAME=$(ssh -o ConnectTimeout=5 "root@${HOST}" hostname 2>/dev/null || echo "unknown")
    DEST="${CONFIGS_STAGING}/${HOSTNAME}"
    mkdir -p "$DEST"
    
    rsync -aze ssh --include='*.conf' --include='*.cnf' --include='*.ini' \
        --include='*/' --exclude='*' \
        "root@${HOST}:/etc/" "$DEST/etc/" 2>/dev/null || true
done

if [ -d "$BORG_REPO_CONFIGS" ]; then
    borg create --compression zstd,6 \
        "${BORG_REPO_CONFIGS}::configs-${TIMESTAMP}" \
        "$CONFIGS_STAGING/" 2>/dev/null && \
    log "BorgBackup configs criado" || {
        error "BorgBackup configs falhou"
        ((ERRORS++))
    }
    
    borg prune --keep-weekly=12 --keep-monthly=12 \
        "$BORG_REPO_CONFIGS" 2>/dev/null
fi

# 3. Sync com HD externo
if [ -d "$EXTERNAL_DIR" ]; then
    rsync -aq "$STAGING/" "$EXTERNAL_DIR/" 2>/dev/null
    log "Sincronizado com HD externo"
fi

# 4. Verificar integridade (semanal - domingo)
if [ "$(date +%u)" = "7" ]; then
    log "Verificação de integridade semanal..."
    borg check "$BORG_REPO_WEB" 2>/dev/null && log "Integridade webfiles OK" || error "Integridade webfiles FALHOU"
    borg check "$BORG_REPO_CONFIGS" 2>/dev/null && log "Integridade configs OK" || error "Integridade configs FALHOU"
fi

# 5. Resultado
if [ "$ERRORS" -gt 0 ]; then
    error "Backup concluído com ${ERRORS} erro(s)!"
    echo "⚠️ GROM BACKUP: ${ERRORS} erro(s) no backup de arquivos" | \
        mail -s "⚠️ Backup Alert" root 2>/dev/null || true
    exit 1
else
    log "Backup concluído com sucesso!"
fi
