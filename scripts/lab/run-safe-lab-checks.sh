#!/bin/bash
# =============================================================================
# GROM SERVER - Validacao segura em laboratorio
# Executa checagens locais sem tocar Proxmox, /etc, rede, containers ou servicos.
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAB_DIR="${ROOT_DIR}/.lab"
REPORT_DIR="${LAB_DIR}/reports"
ENV_FILE="${LAB_DIR}/grom.env"
RUN_BUILD=0

for arg in "$@"; do
    case "$arg" in
        --build-release) RUN_BUILD=1 ;;
        --env=*) ENV_FILE="${arg#--env=}" ;;
        -h|--help)
            echo "Uso: $0 [--build-release] [--env=.lab/grom.env]"
            exit 0
            ;;
        *)
            echo "[FALHA] Argumento desconhecido: $arg" >&2
            exit 2
            ;;
    esac
done

log() { echo "[OK] $1"; }
info() { echo "[INFO] $1"; }
fail() { echo "[FALHA] $1" >&2; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Comando obrigatorio ausente: $1"
}

write_lab_env() {
    if [ -f "$ENV_FILE" ]; then
        info "Usando env de laboratorio existente: ${ENV_FILE#"$ROOT_DIR"/}"
        if ! grep -q '^GROM_LAB_MODE=' "$ENV_FILE"; then
            printf '%s\n' "GROM_LAB_MODE=true" >> "$ENV_FILE"
            log "Complementado GROM_LAB_MODE em env de laboratorio"
        fi
        if ! grep -q '^GROM_SMTP_APP_PASS=' "$ENV_FILE"; then
            printf '%s=%s\n' "GROM_SMTP_APP_PASS" "'LAB_smtp_app_pass_2026__not_real'" >> "$ENV_FILE"
            log "Complementado SMTP ficticio em env de laboratorio"
        fi
        return
    fi

    mkdir -p "$(dirname "$ENV_FILE")"
    {
        cat << 'ENVEOF'
# GROM SERVER - Ambiente ficticio de laboratorio
# Valores deliberadamente falsos, fortes o bastante para passar validadores.

GROM_CONTACT_EMAIL=lab-admin@example.invalid
GROM_ALERT_EMAIL=lab-alerts@example.invalid
GROM_DOMAIN=lab.grom.invalid
GROM_APP_DOMAIN=lab.grom.invalid
GROM_LAB_MODE=true
GROM_SMTP_USER=lab-smtp@example.invalid
GROM_SMTP_FROM=lab-smtp@example.invalid

GROM_RCLONE_REMOTE=gromdrive_crypt:grom-server-backups-lab
GROM_RCLONE_SOURCE=/mnt/backup
ENVEOF
        printf '%s=%s\n' "MYSQL_ROOT_PASS" "'LAB_mysql_root_pass_2026__not_real'"
        printf '%s=%s\n' "GROM_SEG_PASS" "'LAB_grom_seg_pass_2026__not_real'"
        printf '%s=%s\n' "GROM_WEB_PASS" "'LAB_grom_web_pass_2026__not_real'"
        printf '%s=%s\n' "GROM_DOC_PASS" "'LAB_grom_doc_pass_2026__not_real'"
        printf '%s=%s\n' "GROM_BACKUP_PASS" "'LAB_grom_backup_pass_2026__not_real'"
        printf '%s=%s\n' "BORG_PASSPHRASE" "'LAB_borg_passphrase_2026__not_real'"
        printf '%s=%s\n' "GROM_SMTP_APP_PASS" "'LAB_smtp_app_pass_2026__not_real'"
    } > "$ENV_FILE"
    chmod 600 "$ENV_FILE" 2>/dev/null || true
    log "Env de laboratorio criado: ${ENV_FILE#"$ROOT_DIR"/}"
}

check_no_real_target() {
    case "${GROM_LAB_ALLOW_REAL_DOMAIN:-}" in
        1|true|yes) return ;;
    esac

    if grep -Eq '^(GROM_DOMAIN|GROM_APP_DOMAIN)=grom\.seg\.br$' "$ENV_FILE"; then
        fail "Env de laboratorio aponta para dominio real. Use .invalid ou defina GROM_LAB_ALLOW_REAL_DOMAIN=1 conscientemente."
    fi
}

run_and_capture() {
    local name="$1"
    shift

    local report="${REPORT_DIR}/${name}.log"
    info "Executando ${name}..."
    "$@" 2>&1 | tee "$report"
    log "Relatorio: ${report#"$ROOT_DIR"/}"
}

write_summary() {
    local summary="${REPORT_DIR}/LAB-SUMMARY.txt"
    {
        echo "GROM SERVER - Resumo de laboratorio"
        echo "Data: $(date -Is)"
        echo "Root: ${ROOT_DIR}"
        echo "Env: ${ENV_FILE}"
        echo ""
        echo "Garantias deste fluxo:"
        echo "- Nao executa deploy-all.sh."
        echo "- Nao chama pct/qm/vzdump."
        echo "- Nao escreve em /etc/grom."
        echo "- Nao altera rede, firewall, containers, VMs ou servicos."
        echo ""
        echo "Relatorios gerados:"
        find "$REPORT_DIR" -maxdepth 1 -type f -name '*.log' -printf '- %f\n' | sort
    } > "$summary"
    log "Resumo: ${summary#"$ROOT_DIR"/}"
}

require_cmd bash
require_cmd grep
require_cmd find
require_cmd tee

mkdir -p "$REPORT_DIR"
write_lab_env
check_no_real_target

run_and_capture "audit-repository" \
    bash "${ROOT_DIR}/scripts/proxmox/audit-repository.sh" --root="$ROOT_DIR"

run_and_capture "validate-deploy-config-lab" \
    bash "${ROOT_DIR}/scripts/proxmox/validate-deploy-config.sh" \
        --strict \
        --env="$ENV_FILE" \
        --scripts-dir="$ROOT_DIR"

if [ "$RUN_BUILD" -eq 1 ]; then
    run_and_capture "build-release" \
        bash "${ROOT_DIR}/scripts/build-release.sh"
fi

write_summary

echo ""
echo "Laboratorio concluido sem tocar ambiente definitivo."
