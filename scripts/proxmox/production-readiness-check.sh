#!/bin/bash
# =============================================================================
# GROM SERVER - Gate Go/No-Go de producao
# Executar no Proxmox host depois do deploy e da validacao pos-deploy.
# Mede criterios objetivos e exige evidencias manuais para liberacao final.
# =============================================================================

set -euo pipefail

STRICT=0
PUBLIC_TARGET="${GROM_PUBLIC_TARGET:-}"
REPORT_FILE="${GROM_PRODUCTION_READINESS_REPORT:-/var/log/grom-production-readiness.log}"
EVIDENCE_DIR="${GROM_PRODUCTION_EVIDENCE_DIR:-/etc/grom/production-readiness.d}"
POST_DEPLOY_REPORT="${GROM_POST_DEPLOY_REPORT:-/var/log/grom-post-deploy-validation.log}"
CAPACITY_REPORT="${GROM_CAPACITY_REPORT:-/var/log/grom-capacity-baseline.log}"
RESTORE_DRILL_REPORT="${GROM_RESTORE_DRILL_REPORT:-/var/log/grom-restore-drill.log}"
OPERATIONAL_HEALTH_REPORT="${GROM_OPERATIONAL_HEALTH_REPORT:-/var/log/grom-operational-health.log}"

for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --public-target=*) PUBLIC_TARGET="${arg#--public-target=}" ;;
        --report=*) REPORT_FILE="${arg#--report=}" ;;
        --evidence-dir=*) EVIDENCE_DIR="${arg#--evidence-dir=}" ;;
        -h|--help)
            echo "Uso: $0 [--strict] [--public-target=HOST] [--report=/var/log/grom-production-readiness.log] [--evidence-dir=/etc/grom/production-readiness.d]"
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

require_cmd() {
    local cmd="$1"
    if have_cmd "$cmd"; then
        ok "Comando disponivel: ${cmd}"
    else
        fail "Comando obrigatorio ausente: ${cmd}"
    fi
}

check_file() {
    local path="$1"
    local label="$2"
    if [ -e "$path" ]; then
        ok "${label}: presente"
    else
        fail "${label}: ausente (${path})"
    fi
}

check_optional_file() {
    local path="$1"
    local label="$2"
    if [ -e "$path" ]; then
        ok "${label}: presente"
    else
        warn "${label}: ausente (${path})"
    fi
}

check_env_file() {
    local env_file="/etc/grom/grom.env"

    if [ ! -f "$env_file" ]; then
        fail "Arquivo de variaveis ausente: ${env_file}"
        return
    fi

    ok "Arquivo de variaveis existe"

    local mode
    mode=$(stat -c '%a' "$env_file" 2>/dev/null || echo "unknown")
    case "$mode" in
        600|640|400|440) ok "Permissao restrita em ${env_file} (${mode})" ;;
        *) fail "Permissao insegura em ${env_file}: ${mode}; esperado 600/640/400/440" ;;
    esac
}

check_systemd_or_cron() {
    check_optional_file /etc/cron.d/grom-proxmox-backup "Cron de backup Proxmox"
    check_optional_file /etc/cron.d/grom-monthly-report "Cron de relatorio mensal"
    check_optional_file /usr/local/sbin/grom-post-deploy-validation.sh "Validador pos-deploy instalado"
    check_optional_file /usr/local/sbin/grom-monthly-operational-report.sh "Relatorio mensal instalado"
}

check_last_post_deploy_report() {
    if [ ! -f "$POST_DEPLOY_REPORT" ]; then
        fail "Relatorio pos-deploy ausente: ${POST_DEPLOY_REPORT}"
        return
    fi

    ok "Relatorio pos-deploy encontrado"

    if grep -q 'Resumo: 0 falha(s)' "$POST_DEPLOY_REPORT"; then
        ok "Ultima validacao pos-deploy sem falhas"
    else
        fail "Ultima validacao pos-deploy possui falhas ou formato inesperado"
    fi
}

check_capacity_report() {
    if [ ! -f "$CAPACITY_REPORT" ]; then
        fail "Baseline de capacidade ausente: ${CAPACITY_REPORT}"
        return
    fi

    ok "Baseline de capacidade encontrado"

    if grep -q 'Resumo: 0 falha(s)' "$CAPACITY_REPORT"; then
        ok "Baseline de capacidade sem falhas"
    else
        fail "Baseline de capacidade possui falhas ou formato inesperado"
    fi
}

check_restore_drill_report() {
    if [ ! -f "$RESTORE_DRILL_REPORT" ]; then
        fail "Relatorio de restore drill ausente: ${RESTORE_DRILL_REPORT}"
        return
    fi

    ok "Relatorio de restore drill encontrado"

    if grep -q 'Resumo: 0 falha(s)' "$RESTORE_DRILL_REPORT"; then
        ok "Restore drill sem falhas"
    else
        fail "Restore drill possui falhas ou formato inesperado"
    fi
}

check_operational_health_report() {
    if [ ! -f "$OPERATIONAL_HEALTH_REPORT" ]; then
        fail "Relatorio de health check operacional ausente: ${OPERATIONAL_HEALTH_REPORT}"
        return
    fi

    ok "Relatorio de health check operacional encontrado"

    if tail -120 "$OPERATIONAL_HEALTH_REPORT" | grep -q 'Resumo: 0 falha(s)'; then
        ok "Health check operacional recente sem falhas"
    else
        fail "Health check operacional recente possui falhas ou formato inesperado"
    fi
}

check_public_target() {
    if [ -n "$PUBLIC_TARGET" ]; then
        ok "Alvo publico informado: ${PUBLIC_TARGET}"
    else
        warn "Alvo publico nao informado; execute tambem com --public-target=grom.seg.br"
    fi
}

check_evidence() {
    local marker="$1"
    local label="$2"
    local path="${EVIDENCE_DIR}/${marker}"

    if [ -f "$path" ]; then
        ok "Evidencia registrada: ${label}"
    else
        fail "Evidencia obrigatoria ausente: ${label} (${path})"
    fi
}

check_optional_evidence() {
    local marker="$1"
    local label="$2"
    local path="${EVIDENCE_DIR}/${marker}"

    if [ -f "$path" ]; then
        ok "Evidencia registrada: ${label}"
    else
        warn "Evidencia recomendada ausente: ${label} (${path})"
    fi
}

check_exposure_from_host() {
    if [ -z "$PUBLIC_TARGET" ]; then
        return
    fi

    if ! have_cmd nc; then
        warn "nc ausente; exposicao publica deve ser validada por scanner externo"
        return
    fi

    for port in 8006 3306 19999 3001; do
        if nc -z -w 4 "$PUBLIC_TARGET" "$port" >/dev/null 2>&1; then
            fail "Porta administrativa publica indevida: ${PUBLIC_TARGET}:${port}"
        else
            ok "Porta administrativa nao respondeu publicamente: ${port}"
        fi
    done
}

mkdir -p "$(dirname "$REPORT_FILE")"
exec > >(tee "$REPORT_FILE") 2>&1

echo "=== GROM SERVER - Gate Go/No-Go de producao ==="
echo "Inicio: $(date -Is)"
echo "Evidencias: ${EVIDENCE_DIR}"

section "Base do host"
if [ "$(id -u)" -eq 0 ]; then
    ok "Execucao como root"
else
    fail "Execute como root no Proxmox host"
fi
require_cmd pveversion
require_cmd pct
require_cmd qm
require_cmd vzdump
check_env_file

section "Artefatos e validacoes"
check_file /var/log/grom-deploy.log "Log principal do deploy"
check_last_post_deploy_report
check_capacity_report
check_restore_drill_report
check_operational_health_report
check_systemd_or_cron
check_public_target
check_exposure_from_host

section "Evidencias obrigatorias de producao"
check_evidence restore-tested "Restore de banco/arquivos/VM ou LXC testado"
check_evidence external-scan-ok "Varredura externa confirmou portas administrativas fechadas"
check_evidence vpn-tested "Cliente WireGuard externo testado"
check_evidence alert-email-ok "Alerta operacional recebido em e-mail"
check_evidence secrets-in-vault "Segredos guardados em cofre offline/gerenciador"
check_evidence dns-tls-ok "DNS e TLS validos para dominios publicos"

section "Evidencias recomendadas para maturidade"
check_optional_evidence power-loss-plan "Plano contra queda de energia/Nobreak definido"
check_optional_evidence sigepol-deploy-plan "Plano de deploy do Grom_SigePol aprovado"
check_optional_evidence security-deploy-plan "Plano de deploy do Grom_Security aprovado"
check_optional_evidence capacity-baseline "Baseline de CPU/RAM/disco revisado e aceito"

echo ""
echo "Resumo: ${FAIL} falha(s), ${WARN} aviso(s), ${PASS} ok(s)"
echo "Fim: $(date -Is)"

if [ "$FAIL" -gt 0 ]; then
    echo "Decisao: NO-GO"
    exit 1
fi

if [ "$STRICT" -eq 1 ] && [ "$WARN" -gt 0 ]; then
    echo "Decisao: NO-GO em modo strict por aviso(s) pendente(s)"
    exit 1
fi

echo "Decisao: GO para uso controlado"
exit 0
