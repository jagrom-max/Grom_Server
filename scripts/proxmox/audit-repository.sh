#!/bin/bash
# =============================================================================
# GROM SERVER - Auditoria local do pacote antes da implantacao
# Roda no repositorio/pacote e procura riscos que podem quebrar deploy ou vazar
# segredos. Nao executa instalacao, nao altera o sistema e nao imprime segredos.
# =============================================================================

set -euo pipefail

STRICT=0
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --root=*) ROOT_DIR="${arg#--root=}" ;;
        -h|--help)
            echo "Uso: $0 [--strict] [--root=/caminho/Grom_Server]"
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

require_file() {
    local path="$1"
    if [ -f "${ROOT_DIR}/${path}" ]; then
        ok "Arquivo essencial presente: ${path}"
    else
        fail "Arquivo essencial ausente: ${path}"
    fi
}

require_dir() {
    local path="$1"
    if [ -d "${ROOT_DIR}/${path}" ]; then
        ok "Diretorio essencial presente: ${path}"
    else
        fail "Diretorio essencial ausente: ${path}"
    fi
}

check_shell_syntax() {
    local file="$1"
    if bash -n "$file"; then
        ok "Sintaxe bash valida: ${file#"$ROOT_DIR"/}"
    else
        fail "Sintaxe bash invalida: ${file#"$ROOT_DIR"/}"
    fi
}

check_no_secret_values() {
    local raw
    local matches
    raw=$(
        grep -RInE \
            --exclude-dir=.git \
            --exclude-dir=.lab \
            --exclude-dir=downloads \
            --exclude-dir=dist \
            --exclude='*.png' \
            --exclude='*.jpg' \
            --exclude='*.jpeg' \
            --exclude='*.zip' \
            '(PASS|PASSWORD|TOKEN|SECRET)[A-Z0-9_]*=[^#[:space:]][^[:space:]]{5,}' \
            "$ROOT_DIR" 2>/dev/null || true
    )
    matches=""

    while IFS= read -r line; do
        [ -n "$line" ] || continue

        case "$line" in
            *'.example:'*|*'grom.env.example:'*|*'README.md:'*|*'CHANGELOG.md:'*|*'docs/'*)
                continue
                ;;
        esac

        local value="${line#*=}"
        value="${value#\"}"
        value="${value#\'}"

        case "$value" in
            \$*|"")
                continue
                ;;
        esac

        matches="${matches}${line}"$'\n'
    done <<< "$raw"

    if [ -z "$matches" ]; then
        ok "Nenhum valor evidente de segredo versionado encontrado"
        return
    fi

    echo "$matches" | while IFS= read -r line; do
        [ -n "$line" ] || continue
        echo "[FALHA] Possivel segredo em arquivo operacional: ${line%%=*}=<redigido>"
    done

    FAIL=$((FAIL + 1))
}

check_line_endings() {
    local bad=0

    while IFS= read -r -d '' file; do
        if awk 'index($0, "\r") { found=1 } END { exit found ? 0 : 1 }' "$file"; then
            echo "[FALHA] Script com CRLF: ${file#"$ROOT_DIR"/}"
            bad=1
        fi
    done < <(find "$ROOT_DIR/scripts" -type f -name '*.sh' -print0)

    if [ "$bad" -eq 0 ]; then
        ok "Scripts shell sem CRLF"
    else
        FAIL=$((FAIL + 1))
    fi
}

check_nested_security_project() {
    local nested="${ROOT_DIR}/Grom_Security"

    if [ ! -e "$nested" ]; then
        ok "Grom_Security nao esta aninhado dentro do Grom_Server"
        return
    fi

    if find "$nested" -mindepth 1 -maxdepth 1 ! -name '.git' -print -quit 2>/dev/null | grep -q .; then
        fail "Grom_Security parece estar aninhado dentro do Grom_Server; manter como repositorio irmao"
    else
        warn "Residuo vazio/bloqueado Grom_Security encontrado; remover manualmente quando o filesystem permitir"
    fi
}

echo "=== GROM SERVER - Auditoria local do pacote ==="
echo "Raiz auditada: ${ROOT_DIR}"

require_file "README.md"
require_file "CHANGELOG.md"
require_file ".gitattributes"
require_file ".gitignore"
require_dir "scripts"
require_dir "configs"
require_dir "docs"

for path in \
    "scripts/deploy-all.sh" \
    "scripts/build-release.sh" \
    "scripts/lab/create-install-media.ps1" \
    "scripts/lab/download-proxmox-iso.ps1" \
    "scripts/lab/export-release-usb.ps1" \
    "scripts/lab/run-safe-lab-checks.ps1" \
    "scripts/lab/preview-dashboard.ps1" \
    "scripts/proxmox/audit-repository.sh" \
    "scripts/proxmox/capacity-baseline.sh" \
    "scripts/proxmox/operational-health-check.sh" \
    "scripts/proxmox/production-readiness-check.sh" \
    "scripts/proxmox/final-local-deploy.sh" \
    "scripts/proxmox/restore-drill.sh" \
    "scripts/proxmox/verify-host-readiness.sh" \
    "scripts/proxmox/validate-deploy-config.sh" \
    "scripts/proxmox/post-deploy-validation.sh" \
    "scripts/proxmox/create-containers.sh" \
    "scripts/proxmox/post-install.sh" \
    "scripts/database/setup-mysql.sh" \
    "scripts/backup/setup-backup.sh" \
    "scripts/security/hardening.sh" \
    "configs/grom.env.example" \
    "configs/nginx/security-headers.conf" \
    "configs/mysql/my.cnf" \
    "apps/grom-seg/public/server/index.html" \
    "apps/grom-seg/public/server/styles.css" \
    "apps/grom-seg/public/server/app.js" \
    "apps/grom-seg/public/server/data/status.json" \
    "apps/grom-seg/public/server/assets/logo_grom.png" \
    "apps/grom-seg/public/server/assets/logo_grom_menu.png" \
    "docs/19-RUNBOOK-PRIMEIRA-IMPLANTACAO.md" \
    "docs/22-VALIDACAO-POS-DEPLOY.md" \
    "docs/33-IMPLANTACAO-DEFINITIVA-EQUIPAMENTO.md" \
    "docs/34-IMPLANTACAO-EM-BANCADA.md" \
    "docs/35-MIDIA-INSTALACAO-COMPLETA.md" \
    "docs/31-GO-NOGO-PRODUCAO.md"; do
    require_file "$path"
done

while IFS= read -r -d '' script; do
    check_shell_syntax "$script"
done < <(find "$ROOT_DIR/scripts" -type f -name '*.sh' -print0)

check_line_endings
check_no_secret_values
check_nested_security_project

if [ "$FAIL" -gt 0 ]; then
    echo "Resumo: ${FAIL} falha(s), ${WARN} aviso(s)"
    exit 1
fi

if [ "$STRICT" -eq 1 ] && [ "$WARN" -gt 0 ]; then
    echo "Resumo: ${FAIL} falha(s), ${WARN} aviso(s)"
    exit 1
fi

echo "Resumo: ${FAIL} falha(s), ${WARN} aviso(s)"
exit 0
