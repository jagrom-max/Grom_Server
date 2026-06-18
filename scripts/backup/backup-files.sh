#!/bin/bash
# =============================================================================
# GROM SERVER - Backup de fontes montadas no CT112
# Executar dentro do container CT112 (grom-backup), quando houver bind mounts
# declarados em /mnt/backup/sources. Backups completos de containers devem ser
# feitos no Proxmox host via scripts/proxmox/backup-containers.sh.
# =============================================================================

set -euo pipefail

: "${BORG_PASSPHRASE:?Defina BORG_PASSPHRASE antes de executar}"

BORG_REPO_WEB="/mnt/backup/borg-webfiles"
BORG_REPO_CONFIGS="/mnt/backup/borg-configs"
SOURCES_DIR="/mnt/backup/sources"
EXTERNAL_DIR="/mnt/external/webfiles"
EXTERNAL2_DIR="/mnt/external2/webfiles"
LOG_FILE="/var/log/grom-backup/webfiles.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$(dirname "$LOG_FILE")" "$EXTERNAL_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $1"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AVISO] $1"; }
error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERRO] $1"; }

echo ""
echo "=== Backup de Arquivos Montados - ${TIMESTAMP} ==="

if [ ! -d "$SOURCES_DIR" ] || [ -z "$(find "$SOURCES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
    warn "Nenhuma fonte montada em ${SOURCES_DIR}; usando snapshots Proxmox para arquivos de containers."
    exit 0
fi

ERRORS=0

if [ -d "$BORG_REPO_WEB" ]; then
    if borg create --compression zstd,6 --stats \
        "${BORG_REPO_WEB}::files-${TIMESTAMP}" \
        "$SOURCES_DIR" 2>/dev/null; then
        log "BorgBackup de fontes montadas criado"
        borg prune --keep-daily=30 --keep-weekly=8 --keep-monthly=12 "$BORG_REPO_WEB" 2>/dev/null
    else
        error "BorgBackup de fontes montadas falhou"
        ((ERRORS++))
    fi
else
    warn "Repositorio Borg nao encontrado: ${BORG_REPO_WEB}"
fi

if [ -d "$BORG_REPO_CONFIGS" ] && [ -d "${SOURCES_DIR}/configs" ]; then
    borg create --compression zstd,6 \
        "${BORG_REPO_CONFIGS}::configs-${TIMESTAMP}" \
        "${SOURCES_DIR}/configs" 2>/dev/null && \
        log "BorgBackup configs criado" || {
            error "BorgBackup configs falhou"
            ((ERRORS++))
        }
    borg prune --keep-weekly=12 --keep-monthly=12 "$BORG_REPO_CONFIGS" 2>/dev/null
fi

if [ -d "$EXTERNAL_DIR" ]; then
    rsync -aq "$SOURCES_DIR/" "$EXTERNAL_DIR/" 2>/dev/null
    log "Fontes montadas sincronizadas com HD externo"
fi

if [ -d "$EXTERNAL2_DIR" ]; then
    rsync -aq "$SOURCES_DIR/" "$EXTERNAL2_DIR/" 2>/dev/null
    log "Fontes montadas sincronizadas com segundo HD externo"
fi

if [ "$(date +%u)" = "7" ]; then
    borg check "$BORG_REPO_WEB" 2>/dev/null && log "Integridade webfiles OK" || error "Integridade webfiles FALHOU"
fi

if [ "$ERRORS" -gt 0 ]; then
    error "Backup concluido com ${ERRORS} erro(s)"
    exit 1
fi

log "Backup de fontes montadas concluido com sucesso"
