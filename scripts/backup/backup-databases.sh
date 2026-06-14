#!/bin/bash
# =============================================================================
# GROM SERVER - Backup Automático de Bancos de Dados
# Executar DENTRO do container CT102 (grom-backup) via CRON
# TOTALMENTE AUTOMATIZADO - zero interação humana
# =============================================================================

set -euo pipefail

# Configuração
MYSQL_HOST="10.0.1.11"
MYSQL_USER="grom_backup"
MYSQL_PASS="${GROM_BACKUP_PASS:-}"
DATABASES=("grom_web" "grom_documental")
BACKUP_DIR="/mnt/backup/databases"
BORG_REPO="/mnt/backup/borg-databases"
EXTERNAL_DIR="/mnt/external/databases"
RETENTION_DAYS=7
LOG_FILE="/var/log/grom-backup/databases.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$(dirname "$LOG_FILE")" "$BACKUP_DIR/dumps" "$EXTERNAL_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $1"; }
error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERRO] $1"; }

echo ""
echo "=== Backup de Databases - ${TIMESTAMP} ==="

ERRORS=0

# 1. Dump de cada banco
for DB in "${DATABASES[@]}"; do
    DUMP_FILE="${BACKUP_DIR}/dumps/${DB}_${TIMESTAMP}.sql.gz"
    
    if mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" \
        --single-transaction --routines --triggers --events \
        "$DB" 2>/dev/null | gzip > "$DUMP_FILE"; then
        SIZE=$(du -sh "$DUMP_FILE" | awk '{print $1}')
        log "Dump $DB: ${SIZE}"
    else
        error "Falha no dump de $DB"
        ((ERRORS++))
    fi
done

# 2. Backup incremental com BorgBackup
if command -v borg &>/dev/null && [ -d "$BORG_REPO" ]; then
    export BORG_PASSPHRASE="${BORG_PASSPHRASE:-}"
    
    if borg create --compression zstd,6 --stats \
        "${BORG_REPO}::db-${TIMESTAMP}" \
        "${BACKUP_DIR}/dumps/" 2>/dev/null; then
        log "BorgBackup incremental criado"
        
        # Prune automático
        borg prune --keep-hourly=24 --keep-daily=7 --keep-weekly=4 --keep-monthly=6 \
            "$BORG_REPO" 2>/dev/null
        log "Prune do BorgBackup executado"
    else
        error "Falha no BorgBackup"
        ((ERRORS++))
    fi
fi

# 3. Copiar para HD externo
if [ -d "$EXTERNAL_DIR" ]; then
    rsync -aq "${BACKUP_DIR}/dumps/" "$EXTERNAL_DIR/"
    log "Sincronizado com HD externo"
else
    error "HD externo não disponível em ${EXTERNAL_DIR}"
    ((ERRORS++))
fi

# 4. Limpar dumps antigos (manter apenas RETENTION_DAYS dias)
find "${BACKUP_DIR}/dumps/" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null
log "Dumps antigos limpos (>${RETENTION_DAYS} dias)"

# 5. Reportar resultado
if [ "$ERRORS" -gt 0 ]; then
    error "Backup concluído com ${ERRORS} erro(s)!"
    # Enviar alerta (se configurado)
    echo "⚠️ GROM BACKUP: ${ERRORS} erro(s) no backup de databases em $(hostname)" | \
        mail -s "⚠️ Backup Alert" root 2>/dev/null || true
    exit 1
else
    log "Backup concluído com sucesso!"
fi
