#!/bin/bash
# =============================================================================
# GROM SERVER - Orquestrador final de implantacao local
# Executar no Proxmox host definitivo, a partir do pacote extraido.
# Roda os gates na ordem correta e so executa o deploy com confirmacao explicita.
# =============================================================================

set -euo pipefail

STRICT=0
SKIP_DEPLOY=0
CONFIRM=0
PUBLIC_TARGET="${GROM_PUBLIC_TARGET:-}"
ENV_FILE="${GROM_ENV_FILE:-/etc/grom/grom.env}"

ENTRYPOINT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "${ENTRYPOINT_DIR}/../proxmox" ]; then
    SCRIPTS_DIR="$(cd "${ENTRYPOINT_DIR}/.." && pwd)"
    BASE_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
elif [ -d "${ENTRYPOINT_DIR}/scripts/proxmox" ]; then
    BASE_DIR="$ENTRYPOINT_DIR"
    SCRIPTS_DIR="${BASE_DIR}/scripts"
else
    BASE_DIR="/root/grom-scripts"
    SCRIPTS_DIR="${BASE_DIR}/scripts"
fi

for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --skip-deploy) SKIP_DEPLOY=1 ;;
        --confirm-final-deploy) CONFIRM=1 ;;
        --public-target=*) PUBLIC_TARGET="${arg#--public-target=}" ;;
        --env=*) ENV_FILE="${arg#--env=}" ;;
        -h|--help)
            cat << 'HELP'
Uso:
  bash scripts/proxmox/final-local-deploy.sh --confirm-final-deploy [--public-target=grom.seg.br] [--strict]

Opcoes:
  --confirm-final-deploy  Autoriza executar scripts/deploy-all.sh no host definitivo.
  --skip-deploy           Roda apenas gates pre-deploy e relatorios, sem implantar.
  --public-target=HOST    Testa exposicao publica em validacoes pos-deploy.
  --env=PATH              Caminho do grom.env real. Padrao: /etc/grom/grom.env.
  --strict                Falha tambem em avisos nos validadores que suportam strict.

Este script deve ser executado como root no Proxmox host definitivo.
HELP
            exit 0
            ;;
        *)
            echo "[FALHA] Argumento desconhecido: $arg" >&2
            exit 2
            ;;
    esac
done

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
fail() { echo -e "${RED}[FALHA]${NC} $1" >&2; exit 1; }

run_step() {
    local label="$1"
    shift
    echo ""
    info "$label"
    "$@"
    log "$label concluido"
}

require_file() {
    local path="$1"
    [ -f "$path" ] || fail "Arquivo ausente: $path"
}

if [ "$(id -u)" -ne 0 ]; then
    fail "Execute como root no Proxmox host"
fi

command -v pveversion >/dev/null 2>&1 || fail "pveversion ausente; este script deve rodar no Proxmox"
require_file "${SCRIPTS_DIR}/deploy-all.sh"
require_file "${SCRIPTS_DIR}/proxmox/audit-repository.sh"
require_file "${SCRIPTS_DIR}/proxmox/validate-deploy-config.sh"
require_file "${SCRIPTS_DIR}/proxmox/verify-host-readiness.sh"
require_file "${SCRIPTS_DIR}/proxmox/capacity-baseline.sh"
require_file "${SCRIPTS_DIR}/proxmox/post-deploy-validation.sh"
require_file "${SCRIPTS_DIR}/proxmox/operational-health-check.sh"
require_file "${SCRIPTS_DIR}/proxmox/production-readiness-check.sh"

if [ ! -f "$ENV_FILE" ]; then
    fail "Env real ausente: ${ENV_FILE}. Crie com permissoes 600 antes do deploy."
fi

ENV_MODE="$(stat -c '%a' "$ENV_FILE" 2>/dev/null || echo unknown)"
case "$ENV_MODE" in
    600|640|400|440) log "Permissao segura em ${ENV_FILE} (${ENV_MODE})" ;;
    *) fail "Permissao insegura em ${ENV_FILE}: ${ENV_MODE}; use chmod 600 ${ENV_FILE}" ;;
esac

echo ""
echo "=== GROM SERVER - Orquestracao final local ==="
echo "Base: ${BASE_DIR}"
echo "Scripts: ${SCRIPTS_DIR}"
echo "Env: ${ENV_FILE}"
echo "Public target: ${PUBLIC_TARGET:-nao informado}"
echo "Strict: ${STRICT}"
echo "Skip deploy: ${SKIP_DEPLOY}"

AUDIT_ARGS=(--root="$BASE_DIR")
[ "$STRICT" -eq 1 ] && AUDIT_ARGS+=(--strict)
run_step "Auditoria local do pacote" bash "${SCRIPTS_DIR}/proxmox/audit-repository.sh" "${AUDIT_ARGS[@]}"

VALIDATE_ARGS=(--env="$ENV_FILE" --scripts-dir="$BASE_DIR")
[ "$STRICT" -eq 1 ] && VALIDATE_ARGS+=(--strict)
run_step "Validacao pre-deploy" bash "${SCRIPTS_DIR}/proxmox/validate-deploy-config.sh" "${VALIDATE_ARGS[@]}"

run_step "Verificacao do host Proxmox" bash "${SCRIPTS_DIR}/proxmox/verify-host-readiness.sh"

CAPACITY_ARGS=()
[ "$STRICT" -eq 1 ] && CAPACITY_ARGS+=(--strict)
run_step "Baseline de capacidade" bash "${SCRIPTS_DIR}/proxmox/capacity-baseline.sh" "${CAPACITY_ARGS[@]}"

if [ "$SKIP_DEPLOY" -eq 1 ]; then
    warn "Deploy ignorado por --skip-deploy"
elif [ "$CONFIRM" -ne 1 ]; then
    fail "Para executar deploy real, rode novamente com --confirm-final-deploy"
else
    info "Deploy real autorizado por --confirm-final-deploy"
    GROM_ENV_FILE="$ENV_FILE" bash "${SCRIPTS_DIR}/deploy-all.sh"
fi

POST_ARGS=()
[ -n "$PUBLIC_TARGET" ] && POST_ARGS+=(--public-target="$PUBLIC_TARGET")
[ "$STRICT" -eq 1 ] && POST_ARGS+=(--strict)
run_step "Validacao pos-deploy" bash "${SCRIPTS_DIR}/proxmox/post-deploy-validation.sh" "${POST_ARGS[@]}"

HEALTH_ARGS=()
[ -n "$PUBLIC_TARGET" ] && HEALTH_ARGS+=(--public-target="$PUBLIC_TARGET")
[ "$STRICT" -eq 1 ] && HEALTH_ARGS+=(--strict)
run_step "Health check operacional" bash "${SCRIPTS_DIR}/proxmox/operational-health-check.sh" "${HEALTH_ARGS[@]}"

READINESS_ARGS=()
[ -n "$PUBLIC_TARGET" ] && READINESS_ARGS+=(--public-target="$PUBLIC_TARGET")
[ "$STRICT" -eq 1 ] && READINESS_ARGS+=(--strict)
run_step "Gate Go/No-Go" bash "${SCRIPTS_DIR}/proxmox/production-readiness-check.sh" "${READINESS_ARGS[@]}"

echo ""
log "Orquestracao final concluida. Revise os relatorios em /var/log/grom-*.log"
