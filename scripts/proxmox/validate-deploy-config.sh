#!/bin/bash
# =============================================================================
# GROM SERVER - Validacao de configuracao antes do deploy
# Executar no Proxmox host antes de deploy-all.sh.
# Nao imprime valores secretos.
# =============================================================================

set -euo pipefail

STRICT=0
ENV_FILE="${GROM_ENV_FILE:-/etc/grom/grom.env}"
SCRIPTS_DIR="${GROM_SCRIPTS_DIR:-/root/grom-scripts}"

for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --env=*) ENV_FILE="${arg#--env=}" ;;
        --scripts-dir=*) SCRIPTS_DIR="${arg#--scripts-dir=}" ;;
        -h|--help)
            echo "Uso: $0 [--strict] [--env=/etc/grom/grom.env] [--scripts-dir=/root/grom-scripts]"
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

ok() { echo "[OK] $1"; }
warn() { echo "[AVISO] $1"; WARN=$((WARN + 1)); }
fail() { echo "[FALHA] $1"; FAIL=$((FAIL + 1)); }

is_placeholder() {
    local value="${1:-}"
    case "$value" in
        ""|senha|password|changeme|trocar|guardar-no-cofre|senha-do-cofre|example|exemplo|123456|admin)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_required_secret() {
    local name="$1"
    local value="${!name:-}"

    if [ -z "$value" ]; then
        if [ "$STRICT" -eq 1 ]; then
            fail "Variavel obrigatoria ausente: ${name}"
        else
            warn "Variavel obrigatoria ausente: ${name}"
        fi
        return
    fi

    if is_placeholder "$value"; then
        fail "Variavel ${name} parece placeholder/fraca"
        return
    fi

    if [ "${#value}" -lt 16 ]; then
        warn "Variavel ${name} tem menos de 16 caracteres"
    else
        ok "Variavel ${name} definida"
    fi
}

check_optional_secret() {
    local name="$1"
    local value="${!name:-}"

    if [ -z "$value" ]; then
        warn "Variavel opcional ausente: ${name}"
        return
    fi

    if is_placeholder "$value"; then
        fail "Variavel opcional ${name} parece placeholder/fraca"
    else
        ok "Variavel opcional ${name} definida"
    fi
}

check_email() {
    local name="$1"
    local value="${!name:-}"

    if [ -z "$value" ]; then
        warn "E-mail nao definido: ${name}"
        return
    fi

    if printf '%s' "$value" | grep -Eq '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'; then
        ok "E-mail valido em ${name}"
    else
        fail "E-mail invalido em ${name}"
    fi
}

check_file_mode() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return
    fi

    local mode
    mode=$(stat -c '%a' "$file" 2>/dev/null || echo "unknown")
    case "$mode" in
        600|640|400|440) ok "Permissao restrita em ${file} (${mode})" ;;
        *)
            if [ "${GROM_LAB_MODE:-}" = "true" ] && printf '%s' "$file" | grep -q '/\.lab/'; then
                ok "Permissao aceita para env de laboratorio em filesystem local (${mode})"
                return
            fi
            warn "Permissao de ${file} deveria ser 600 ou 640; atual: ${mode}"
            ;;
    esac
}

echo "=== GROM SERVER - Validacao pre-deploy ==="

if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    ok "Arquivo de variaveis carregado: ${ENV_FILE}"
    check_file_mode "$ENV_FILE"
else
    if [ "$STRICT" -eq 1 ]; then
        fail "Arquivo de variaveis nao encontrado: ${ENV_FILE}"
    else
        warn "Arquivo de variaveis nao encontrado: ${ENV_FILE}"
    fi
fi

GROM_CONTACT_EMAIL="${GROM_CONTACT_EMAIL:-grom.servidor@gmail.com}"
GROM_ALERT_EMAIL="${GROM_ALERT_EMAIL:-$GROM_CONTACT_EMAIL}"
GROM_DOMAIN="${GROM_DOMAIN:-grom.seg.br}"
GROM_APP_DOMAIN="${GROM_APP_DOMAIN:-$GROM_DOMAIN}"
GROM_SMTP_USER="${GROM_SMTP_USER:-$GROM_CONTACT_EMAIL}"
GROM_SMTP_FROM="${GROM_SMTP_FROM:-$GROM_SMTP_USER}"
GROM_RCLONE_REMOTE="${GROM_RCLONE_REMOTE:-gromdrive_crypt:grom-server-backups}"
GROM_RCLONE_SOURCE="${GROM_RCLONE_SOURCE:-/mnt/backup}"

check_email GROM_CONTACT_EMAIL
check_email GROM_ALERT_EMAIL
check_email GROM_SMTP_USER
check_email GROM_SMTP_FROM

if printf '%s' "$GROM_DOMAIN" | grep -Eq '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
    ok "Dominio valido: ${GROM_DOMAIN}"
else
    fail "Dominio invalido: ${GROM_DOMAIN}"
fi

if printf '%s' "$GROM_APP_DOMAIN" | grep -Eq '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
    ok "Dominio da aplicacao valido: ${GROM_APP_DOMAIN}"
else
    fail "Dominio da aplicacao invalido: ${GROM_APP_DOMAIN}"
fi

check_required_secret MYSQL_ROOT_PASS
check_required_secret GROM_SEG_PASS
check_required_secret GROM_WEB_PASS
check_required_secret GROM_DOC_PASS
check_required_secret GROM_BACKUP_PASS
check_required_secret BORG_PASSPHRASE
check_optional_secret GROM_SMTP_APP_PASS

if [ -d "$SCRIPTS_DIR" ]; then
    ok "Diretorio de scripts encontrado: ${SCRIPTS_DIR}"
else
    fail "Diretorio de scripts ausente: ${SCRIPTS_DIR}"
fi

for path in \
    "scripts/build-release.sh" \
    "scripts/proxmox/capacity-baseline.sh" \
    "scripts/proxmox/create-containers.sh" \
    "scripts/proxmox/operational-health-check.sh" \
    "scripts/proxmox/post-install.sh" \
    "scripts/proxmox/audit-repository.sh" \
    "scripts/proxmox/production-readiness-check.sh" \
    "scripts/proxmox/restore-drill.sh" \
    "scripts/database/setup-mysql.sh" \
    "scripts/backup/setup-backup.sh" \
    "scripts/security/hardening.sh" \
    "configs/grom.env.example" \
    "docs/19-RUNBOOK-PRIMEIRA-IMPLANTACAO.md"; do
    if [ -f "${SCRIPTS_DIR}/${path}" ]; then
        ok "Presente: ${path}"
    else
        fail "Ausente no pacote: ${path}"
    fi
done

if [ -f "${SCRIPTS_DIR}/downloads/manifest.json" ]; then
    ok "Manifest de downloads encontrado"
else
    warn "Manifest de downloads ausente; conferir ISOs/templates manualmente"
fi

if [ "${GROM_RCLONE_REMOTE#*crypt}" != "$GROM_RCLONE_REMOTE" ]; then
    ok "Remote rclone aparenta usar crypt"
else
    warn "GROM_RCLONE_REMOTE nao aparenta ser remote crypt"
fi

if [ "$FAIL" -gt 0 ]; then
    echo "Resumo: ${FAIL} falha(s), ${WARN} aviso(s)"
    exit 1
fi

echo "Resumo: ${FAIL} falha(s), ${WARN} aviso(s)"
exit 0
