#!/bin/bash
# =============================================================================
# GROM SERVER - Deploy do subprojeto Grom_Security para VM130
# Executar no Proxmox host depois de criar e instalar a VM Grom_Security.
# =============================================================================

set -euo pipefail

SEC_VM_ID="${SEC_VM_ID:-130}"
SEC_HOST="${GROM_SECURITY_HOST:-10.0.1.30}"
SEC_USER="${GROM_SECURITY_SSH_USER:-root}"
SRC_DIR="${GROM_SECURITY_SRC:-/root/grom-scripts/Grom_Security}"
TARGET_DIR="${GROM_SECURITY_TARGET:-/opt/grom-security}"
BACKUP_BASE="${GROM_SECURITY_BACKUP_BASE:-/opt/grom-security-releases}"

log() { echo "[OK] $1"; }
warn() { echo "[AVISO] $1"; }
fail() { echo "[FALHA] $1"; exit 1; }

require_tools() {
    command -v ssh >/dev/null 2>&1 || fail "ssh ausente"
    command -v rsync >/dev/null 2>&1 || fail "rsync ausente"
    command -v qm >/dev/null 2>&1 || warn "qm ausente; pulando verificacao de VM"
}

check_source() {
    [ -d "$SRC_DIR" ] || fail "Diretorio Grom_Security nao encontrado: ${SRC_DIR}"
    [ -f "$SRC_DIR/scripts/install-vm-dependencies.sh" ] || fail "Script install-vm-dependencies.sh ausente"
    [ -f "$SRC_DIR/scripts/deploy-local.sh" ] || fail "Script deploy-local.sh ausente"
    [ -f "$SRC_DIR/scripts/preflight-check.sh" ] || fail "Script preflight-check.sh ausente"
}

check_vm() {
    if command -v qm >/dev/null 2>&1; then
        qm status "$SEC_VM_ID" 2>/dev/null | grep -q "status: running" || \
            warn "VM${SEC_VM_ID} nao parece estar rodando; tentando SSH mesmo assim"
    fi
}

deploy() {
    ssh "${SEC_USER}@${SEC_HOST}" "mkdir -p '${TARGET_DIR}'"
    ssh "${SEC_USER}@${SEC_HOST}" "if [ -d '${TARGET_DIR}' ]; then mkdir -p '${BACKUP_BASE}'; tar --exclude='storage' --exclude='mosquitto/data' -C '$(dirname "${TARGET_DIR}")' -czf '${BACKUP_BASE}/grom-security-\$(date +%Y%m%d-%H%M%S).tgz' '$(basename "${TARGET_DIR}")'; fi"
    rsync -a --delete \
        --exclude ".git" \
        --exclude "storage/*" \
        --exclude ".env" \
        "$SRC_DIR/" "${SEC_USER}@${SEC_HOST}:${TARGET_DIR}/"

    ssh "${SEC_USER}@${SEC_HOST}" "chmod +x '${TARGET_DIR}'/scripts/*.sh && '${TARGET_DIR}'/scripts/install-vm-dependencies.sh"
    ssh "${SEC_USER}@${SEC_HOST}" "'${TARGET_DIR}'/scripts/preflight-check.sh"
    ssh "${SEC_USER}@${SEC_HOST}" "GROM_SECURITY_TARGET='${TARGET_DIR}' '${TARGET_DIR}'/scripts/deploy-local.sh"
    ssh "${SEC_USER}@${SEC_HOST}" "'${TARGET_DIR}'/scripts/preflight-check.sh"
    ssh "${SEC_USER}@${SEC_HOST}" "curl -fsS http://127.0.0.1:8080/health"
    log "Grom_Security implantado em ${SEC_HOST}:${TARGET_DIR}"
}

require_tools
check_source
check_vm
deploy
