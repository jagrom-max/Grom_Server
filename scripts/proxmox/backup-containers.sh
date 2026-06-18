#!/bin/bash
# =============================================================================
# GROM SERVER - Backup Proxmox de VMs/Containers
# Executar no Proxmox host via cron/systemd timer.
# Captura OPNsense e containers LXC sem depender de SSH root entre servidores.
# =============================================================================

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/mnt/backup-external/proxmox}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
LOG_FILE="/var/log/grom-proxmox-backup.log"
VM_IDS=(100 110 111 112 113 114)

mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $1"; }
error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERRO] $1"; }

echo ""
echo "=== Backup Proxmox Grom Server ==="

if ! mountpoint -q "$(dirname "$BACKUP_DIR")"; then
    error "Destino externo nao montado: $(dirname "$BACKUP_DIR")"
    exit 1
fi

ERRORS=0

for VMID in "${VM_IDS[@]}"; do
    if qm status "$VMID" >/dev/null 2>&1 || pct status "$VMID" >/dev/null 2>&1; then
        log "Iniciando vzdump de ${VMID}"
        if vzdump "$VMID" \
            --dumpdir "$BACKUP_DIR" \
            --mode snapshot \
            --compress zstd \
            --notes-template '{{guestname}} - {{vmid}} - {{node}} - {{date}}' \
            --quiet 1; then
            log "Backup ${VMID} concluido"
        else
            error "Backup ${VMID} falhou"
            ((ERRORS++))
        fi
    else
        error "VM/CT ${VMID} nao encontrado"
        ((ERRORS++))
    fi
done

find "$BACKUP_DIR" -type f -name 'vzdump-*' -mtime +"$RETENTION_DAYS" -delete
log "Retencao aplicada: ${RETENTION_DAYS} dias"

if [ "$ERRORS" -gt 0 ]; then
    error "Backup Proxmox terminou com ${ERRORS} erro(s)"
    exit 1
fi

log "Backup Proxmox concluido com sucesso"
