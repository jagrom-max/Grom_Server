#!/bin/bash
# =============================================================================
# GROM SERVER - Ensaio seguro de restore
# Executar no Proxmox host depois que backups existirem.
# Nao restaura sobre producao. Verifica integridade, catalogos e legibilidade.
# =============================================================================

set -euo pipefail

STRICT=0
REPORT_FILE="${GROM_RESTORE_DRILL_REPORT:-/var/log/grom-restore-drill.log}"
BACKUP_CTID="${GROM_BACKUP_CTID:-112}"
PROXMOX_BACKUP_DIR="${GROM_PROXMOX_BACKUP_DIR:-/mnt/backup-external/proxmox}"
EVIDENCE_DIR="${GROM_PRODUCTION_EVIDENCE_DIR:-/etc/grom/production-readiness.d}"
MARK_READY=0

for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --mark-ready) MARK_READY=1 ;;
        --report=*) REPORT_FILE="${arg#--report=}" ;;
        --backup-ctid=*) BACKUP_CTID="${arg#--backup-ctid=}" ;;
        --proxmox-backup-dir=*) PROXMOX_BACKUP_DIR="${arg#--proxmox-backup-dir=}" ;;
        -h|--help)
            echo "Uso: $0 [--strict] [--mark-ready] [--report=/var/log/grom-restore-drill.log] [--backup-ctid=112] [--proxmox-backup-dir=/mnt/backup-external/proxmox]"
            exit 0
            ;;
        *)
            echo "[FALHA] Argumento desconhecido: $arg"
            exit 2
            ;;
    esac
done

FAIL=0
WARN=0
PASS=0

ok() { echo "[OK] $1"; PASS=$((PASS + 1)); }
warn() { echo "[AVISO] $1"; WARN=$((WARN + 1)); }
fail() { echo "[FALHA] $1"; FAIL=$((FAIL + 1)); }

section() {
    echo ""
    echo "== $1 =="
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

ct_exec() {
    pct exec "$BACKUP_CTID" -- "$@"
}

check_backup_ct() {
    if ! have_cmd pct; then
        fail "Comando pct ausente"
        return
    fi

    if pct status "$BACKUP_CTID" 2>/dev/null | grep -q 'status: running'; then
        ok "CT${BACKUP_CTID} Backup em execucao"
    else
        fail "CT${BACKUP_CTID} Backup nao esta em execucao"
    fi
}

check_ct_path() {
    local path="$1"
    local label="$2"

    if ct_exec test -e "$path" >/dev/null 2>&1; then
        ok "CT${BACKUP_CTID}: ${label} presente"
    else
        fail "CT${BACKUP_CTID}: ${label} ausente (${path})"
    fi
}

check_borg_repo() {
    local repo="$1"
    local label="$2"

    if ! ct_exec test -d "$repo" >/dev/null 2>&1; then
        warn "CT${BACKUP_CTID}: repositorio Borg ausente: ${label} (${repo})"
        return
    fi

    if ct_exec bash -lc ". /root/.grom_backup_env && borg list '$repo' >/tmp/grom-borg-${label}.list"; then
        ok "CT${BACKUP_CTID}: Borg lista arquivos em ${label}"
    else
        fail "CT${BACKUP_CTID}: Borg nao conseguiu listar ${label}"
        return
    fi

    if ct_exec bash -lc ". /root/.grom_backup_env && borg check --repository-only '$repo'"; then
        ok "CT${BACKUP_CTID}: Borg repository-only OK em ${label}"
    else
        fail "CT${BACKUP_CTID}: Borg check falhou em ${label}"
    fi
}

check_latest_dump() {
    local dump

    dump="$(ct_exec bash -lc "find /mnt/backup/databases/dumps -type f -name '*.sql.gz' 2>/dev/null | sort | tail -1" 2>/dev/null || true)"

    if [ -z "$dump" ]; then
        fail "Nenhum dump .sql.gz encontrado no CT${BACKUP_CTID}"
        return
    fi

    ok "Dump mais recente encontrado: ${dump}"

    if ct_exec gzip -t "$dump" >/dev/null 2>&1; then
        ok "Dump gzip legivel"
    else
        fail "Dump gzip corrompido ou ilegivel: ${dump}"
    fi

    if ct_exec bash -lc "zcat '$dump' | head -50 | grep -Eiq 'mariadb|mysql|CREATE|Database'"; then
        ok "Dump parece conter SQL valido"
    else
        warn "Dump legivel, mas assinatura SQL nao foi confirmada nos primeiros blocos"
    fi
}

check_proxmox_archives() {
    if [ ! -d "$PROXMOX_BACKUP_DIR" ]; then
        fail "Diretorio de backup Proxmox ausente: ${PROXMOX_BACKUP_DIR}"
        return
    fi

    local count
    count="$(find "$PROXMOX_BACKUP_DIR" -type f -name 'vzdump-*' 2>/dev/null | wc -l | awk '{print $1}')"

    if [ "${count:-0}" -gt 0 ]; then
        ok "Arquivos vzdump encontrados: ${count}"
    else
        fail "Nenhum arquivo vzdump encontrado em ${PROXMOX_BACKUP_DIR}"
        return
    fi

    find "$PROXMOX_BACKUP_DIR" -type f -name 'vzdump-*' -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -10 || true
}

mark_ready() {
    if [ "$MARK_READY" -ne 1 ]; then
        warn "Restore drill passou, mas marcador nao foi criado. Use --mark-ready apos revisar o relatorio."
        return
    fi

    mkdir -p "$EVIDENCE_DIR"
    {
        echo "Restore drill executado em $(date -Is)"
        echo "Relatorio: ${REPORT_FILE}"
        echo "Backup CTID: ${BACKUP_CTID}"
        echo "Proxmox backup dir: ${PROXMOX_BACKUP_DIR}"
    } > "${EVIDENCE_DIR}/restore-tested"
    chmod 600 "${EVIDENCE_DIR}/restore-tested"
    ok "Evidencia criada: ${EVIDENCE_DIR}/restore-tested"
}

mkdir -p "$(dirname "$REPORT_FILE")"
exec > >(tee "$REPORT_FILE") 2>&1

echo "=== GROM SERVER - Restore Drill ==="
echo "Inicio: $(date -Is)"

section "Pre-condicoes"
if [ "$(id -u)" -eq 0 ]; then
    ok "Execucao como root"
else
    fail "Execute como root no Proxmox host"
fi
check_backup_ct

section "Backup logico e Borg"
check_ct_path /root/.grom_backup_env "ambiente de backup"
check_ct_path /mnt/backup "diretorio base de backup"
check_latest_dump
check_borg_repo /mnt/backup/borg-databases databases
check_borg_repo /mnt/backup/borg-webfiles webfiles
check_borg_repo /mnt/backup/borg-configs configs

section "Backup VM/LXC"
check_proxmox_archives

section "Conclusao"
echo "Este ensaio nao restaurou sobre producao. Para teste completo, restaurar uma VM/LXC em ID temporario isolado e validar boot/dados."

if [ "$FAIL" -eq 0 ]; then
    mark_ready
fi

echo ""
echo "Resumo: ${FAIL} falha(s), ${WARN} aviso(s), ${PASS} ok(s)"
echo "Fim: $(date -Is)"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

if [ "$STRICT" -eq 1 ] && [ "$WARN" -gt 0 ]; then
    exit 1
fi

exit 0
