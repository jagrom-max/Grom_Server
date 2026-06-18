#!/bin/bash
# =============================================================================
# GROM SERVER - Simulacao segura do plano de deploy
# Gera plano e checa artefatos sem executar comandos de implantacao.
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/.lab/grom.env"
REPORT_FILE="${ROOT_DIR}/.lab/reports/deploy-plan.log"

for arg in "$@"; do
    case "$arg" in
        --env=*) ENV_FILE="${arg#--env=}" ;;
        --report=*) REPORT_FILE="${arg#--report=}" ;;
        -h|--help)
            echo "Uso: $0 [--env=.lab/grom.env] [--report=.lab/reports/deploy-plan.log]"
            exit 0
            ;;
        *)
            echo "[FALHA] Argumento desconhecido: $arg" >&2
            exit 2
            ;;
    esac
done

FAIL=0
WARN=0
STEP=0

ok() { echo "[OK] $1"; }
warn() { echo "[AVISO] $1"; WARN=$((WARN + 1)); }
fail() { echo "[FALHA] $1"; FAIL=$((FAIL + 1)); }

require_file() {
    local path="$1"
    if [ -f "${ROOT_DIR}/${path}" ]; then
        ok "Arquivo presente: ${path}"
    else
        fail "Arquivo ausente: ${path}"
    fi
}

require_dir() {
    local path="$1"
    if [ -d "${ROOT_DIR}/${path}" ]; then
        ok "Diretorio presente: ${path}"
    else
        fail "Diretorio ausente: ${path}"
    fi
}

plan_step() {
    STEP=$((STEP + 1))
    printf '%02d. %s\n' "$STEP" "$1"
}

check_env_value() {
    local name="$1"
    local value="${!name:-}"

    if [ -z "$value" ]; then
        fail "Variavel ausente no env simulado: ${name}"
        return
    fi

    case "$value" in
        senha|password|changeme|guardar-no-cofre|senha-do-cofre|example|exemplo|123456|admin)
            fail "Variavel parece placeholder: ${name}"
            ;;
        *)
            ok "Variavel simulada definida: ${name}"
            ;;
    esac
}

check_no_real_domain_in_lab() {
    if [ "${GROM_LAB_ALLOW_REAL_DOMAIN:-}" = "1" ]; then
        warn "Dominio real permitido explicitamente em laboratorio"
        return
    fi

    case "${GROM_DOMAIN:-}" in
        grom.seg.br)
            fail "Laboratorio nao deve apontar GROM_DOMAIN para grom.seg.br"
            ;;
        *.invalid)
            ok "Dominio de laboratorio usa TLD reservado: ${GROM_DOMAIN}"
            ;;
        *)
            warn "Dominio de laboratorio nao usa .invalid: ${GROM_DOMAIN:-ausente}"
            ;;
    esac
}

check_id_once() {
    local id="$1"
    local label="$2"
    local count
    count="$(grep -RInE "(VM|CT)?${id}| ${id} |^${id}[[:space:]]" "${ROOT_DIR}/docs" "${ROOT_DIR}/scripts" 2>/dev/null | wc -l | awk '{print $1}')"
    if [ "${count:-0}" -gt 0 ]; then
        ok "ID ${id} referenciado para ${label} (${count} ocorrencias)"
    else
        fail "ID ${id} nao encontrado para ${label}"
    fi
}

mkdir -p "$(dirname "$REPORT_FILE")"
exec > >(tee "$REPORT_FILE") 2>&1

echo "=== GROM SERVER - Simulacao segura do deploy ==="
echo "Data: $(date -Is)"
echo "Raiz: ${ROOT_DIR}"
echo "Env: ${ENV_FILE}"
echo ""
echo "Esta simulacao nao executa deploy-all.sh, pct, qm, apt, systemctl, ufw, cp, rm, install, tee em /etc ou comandos de rede."

echo ""
echo "== Artefatos obrigatorios =="
if [ -f "${ROOT_DIR}/deploy-all.sh" ]; then
    ok "Arquivo presente: deploy-all.sh"
elif [ -f "${ROOT_DIR}/scripts/deploy-all.sh" ]; then
    ok "Arquivo presente: scripts/deploy-all.sh"
else
    fail "Arquivo ausente: deploy-all.sh ou scripts/deploy-all.sh"
fi
require_file "scripts/proxmox/audit-repository.sh"
require_file "scripts/proxmox/validate-deploy-config.sh"
require_file "scripts/proxmox/verify-host-readiness.sh"
require_file "scripts/proxmox/create-containers.sh"
require_file "scripts/proxmox/post-deploy-validation.sh"
require_file "scripts/proxmox/operational-health-check.sh"
require_file "scripts/proxmox/production-readiness-check.sh"
require_file "scripts/proxmox/final-local-deploy.sh"
require_file "scripts/webserver/setup-nginx.sh"
require_file "scripts/database/setup-mysql.sh"
require_file "scripts/backup/setup-backup.sh"
require_file "scripts/monitoring/setup-monitoring.sh"
require_file "scripts/vpn/setup-wireguard.sh"
require_file "scripts/security/hardening.sh"
require_file "configs/grom.env.example"
require_dir "apps/grom-seg/public/server"
require_file "apps/grom-seg/public/server/data/status.json"
require_file "apps/grom-seg/public/server/assets/logo_grom.png"
require_file "apps/grom-seg/public/server/assets/logo_grom_menu.png"
require_file "scripts/lab/preview-dashboard.ps1"
require_file "scripts/lab/export-release-usb.ps1"
require_file "scripts/lab/create-install-media.ps1"
require_file "docs/31-GO-NOGO-PRODUCAO.md"
require_file "docs/32-DESENVOLVIMENTO-SEGURO-LAB.md"
require_file "docs/33-IMPLANTACAO-DEFINITIVA-EQUIPAMENTO.md"
require_file "docs/34-IMPLANTACAO-EM-BANCADA.md"
require_file "docs/35-MIDIA-INSTALACAO-COMPLETA.md"

echo ""
echo "== Env de laboratorio =="
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    ok "Env carregado"
else
    fail "Env de laboratorio ausente: ${ENV_FILE}"
fi

check_no_real_domain_in_lab
for var in MYSQL_ROOT_PASS GROM_SEG_PASS GROM_WEB_PASS GROM_DOC_PASS GROM_BACKUP_PASS BORG_PASSPHRASE; do
    check_env_value "$var"
done

echo ""
echo "== Matriz esperada de VMs/containers =="
check_id_once 100 "OPNsense"
check_id_once 110 "Web/SigePol"
check_id_once 111 "Database"
check_id_once 112 "Backup"
check_id_once 113 "Monitoring"
check_id_once 114 "VPN"
check_id_once 120 "Home Assistant OS opcional"
check_id_once 130 "Grom_Security opcional"

echo ""
echo "== Plano que seria executado no Proxmox definitivo =="
plan_step "Copiar pacote release e checksum para /root no host final."
plan_step "Conferir sha256sum e extrair em /root/grom-scripts."
plan_step "Criar /etc/grom/grom.env real com permissoes restritas e segredos fora do Git."
plan_step "Executar verify-host-readiness.sh no host final."
plan_step "Executar capacity-baseline.sh no host final."
plan_step "Executar validate-deploy-config.sh --strict no pacote extraido."
plan_step "Configurar rede Proxmox e OPNsense manualmente em janela controlada."
plan_step "Executar final-local-deploy.sh --skip-deploy para ensaio no host final."
plan_step "Executar final-local-deploy.sh --confirm-final-deploy somente depois de GO explicito."
plan_step "Executar restore-drill.sh e registrar evidencia apenas apos revisar relatorio."
plan_step "Registrar evidencias em /etc/grom/production-readiness.d apenas apos testes reais."

echo ""
echo "== Bloqueios intencionais =="
echo "- Sem acesso ao host final nesta fase."
echo "- Sem dados reais nesta fase."
echo "- Sem dominio real no env de laboratorio."
echo "- Sem deploy automatico a partir do workspace local."

echo ""
echo "Resumo: ${FAIL} falha(s), ${WARN} aviso(s), ${STEP} passo(s) planejado(s)"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

exit 0
