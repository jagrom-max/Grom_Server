#!/bin/bash
# =============================================================================
# GROM SERVER - ORQUESTRADOR PRINCIPAL
# Executa TODOS os scripts de setup na ordem correta
# Executar no Proxmox Host após criar os containers
# TOTALMENTE AUTOMATIZADO - Implanta toda a infraestrutura
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $(date '+%H:%M:%S') $1"; }
info() { echo -e "${BLUE}[i]${NC} $(date '+%H:%M:%S') $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $(date '+%H:%M:%S') $1"; }
error() { echo -e "${RED}[✗]${NC} $(date '+%H:%M:%S') $1"; }
section() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

ENTRYPOINT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "${ENTRYPOINT_DIR}/scripts/proxmox" ]; then
    BASE_DIR="$ENTRYPOINT_DIR"
    SCRIPTS_DIR="${BASE_DIR}/scripts"
elif [ -d "${ENTRYPOINT_DIR}/proxmox" ]; then
    SCRIPTS_DIR="$ENTRYPOINT_DIR"
    BASE_DIR="$(dirname "$SCRIPTS_DIR")"
else
    BASE_DIR="/root/grom-scripts"
    SCRIPTS_DIR="${BASE_DIR}/scripts"
fi
LOG_FILE="/var/log/grom-deploy.log"

if [ -f /etc/grom/grom.env ]; then
    # shellcheck disable=SC1091
    . /etc/grom/grom.env
elif [ -f "${BASE_DIR}/configs/grom.env.example" ]; then
    # shellcheck disable=SC1091
    . "${BASE_DIR}/configs/grom.env.example"
fi

export GROM_CONTACT_EMAIL="${GROM_CONTACT_EMAIL:-grom.servidor@gmail.com}"
export GROM_ALERT_EMAIL="${GROM_ALERT_EMAIL:-$GROM_CONTACT_EMAIL}"
export GROM_DOMAIN="${GROM_DOMAIN:-grom.seg.br}"
export GROM_APP_DOMAIN="${GROM_APP_DOMAIN:-$GROM_DOMAIN}"
export GROM_SMTP_USER="${GROM_SMTP_USER:-$GROM_CONTACT_EMAIL}"
export GROM_SMTP_FROM="${GROM_SMTP_FROM:-$GROM_SMTP_USER}"
export GROM_RCLONE_REMOTE="${GROM_RCLONE_REMOTE:-gromdrive_crypt:grom-server-backups}"
export GROM_RCLONE_SOURCE="${GROM_RCLONE_SOURCE:-/mnt/backup}"

exec > >(tee -a "$LOG_FILE") 2>&1

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     🖥️  GROM SERVER - Deploy Automatizado    ║"
echo "║     Infraestrutura Completa                  ║"
echo "║     Domínio: grom.seg.br                     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Início: $(date)"
echo ""

require_env() {
    local VAR_NAME=$1
    if [ -z "${!VAR_NAME:-}" ]; then
        error "Variável obrigatória ausente: ${VAR_NAME}"
        error "Defina ${VAR_NAME} antes do deploy para evitar credenciais fracas ou perdidas."
        exit 1
    fi
}

run_preflight_validation() {
    local SCRIPT="${SCRIPTS_DIR}/proxmox/validate-deploy-config.sh"

    if [ -f "$SCRIPT" ]; then
        info "Executando validacao pre-deploy..."
        GROM_SCRIPTS_DIR="$BASE_DIR" bash "$SCRIPT" --strict
        log "Validacao pre-deploy concluida"
    else
        warn "Validador pre-deploy nao encontrado: ${SCRIPT}"
    fi
}

run_repository_audit() {
    local SCRIPT="${SCRIPTS_DIR}/proxmox/audit-repository.sh"

    if [ -f "$SCRIPT" ]; then
        info "Executando auditoria local do pacote..."
        bash "$SCRIPT" --root="$BASE_DIR"
        log "Auditoria local do pacote concluida"
    else
        warn "Auditor local nao encontrado: ${SCRIPT}"
    fi
}

# Função para copiar e executar script em container
run_in_container() {
    local CTID=$1
    local SCRIPT=$2
    local DESCRIPTION=$3
    
    info "CT${CTID}: ${DESCRIPTION}..."
    
    if [ -f "${SCRIPTS_DIR}/${SCRIPT}" ]; then
        pct push "$CTID" "${SCRIPTS_DIR}/${SCRIPT}" "/tmp/$(basename "$SCRIPT")"
        pct exec "$CTID" -- env \
            MYSQL_ROOT_PASS="${MYSQL_ROOT_PASS:-}" \
            GROM_SEG_PASS="${GROM_SEG_PASS:-}" \
            GROM_WEB_PASS="${GROM_WEB_PASS:-}" \
            GROM_DOC_PASS="${GROM_DOC_PASS:-}" \
            GROM_BACKUP_PASS="${GROM_BACKUP_PASS:-}" \
            BORG_PASSPHRASE="${BORG_PASSPHRASE:-}" \
            GROM_CONTACT_EMAIL="${GROM_CONTACT_EMAIL:-}" \
            GROM_ALERT_EMAIL="${GROM_ALERT_EMAIL:-}" \
            GROM_DOMAIN="${GROM_DOMAIN:-}" \
            GROM_APP_DOMAIN="${GROM_APP_DOMAIN:-}" \
            GROM_SMTP_USER="${GROM_SMTP_USER:-}" \
            GROM_SMTP_FROM="${GROM_SMTP_FROM:-}" \
            GROM_SMTP_APP_PASS="${GROM_SMTP_APP_PASS:-}" \
            GROM_RCLONE_REMOTE="${GROM_RCLONE_REMOTE:-}" \
            GROM_RCLONE_SOURCE="${GROM_RCLONE_SOURCE:-}" \
            bash "/tmp/$(basename "$SCRIPT")" || {
            error "CT${CTID}: Falha em ${DESCRIPTION}"
            return 1
        }
        log "CT${CTID}: ${DESCRIPTION} ✅"
    else
        error "Script não encontrado: ${SCRIPTS_DIR}/${SCRIPT}"
        return 1
    fi
}

push_to_container() {
    local CTID=$1
    local SCRIPT=$2

    if [ -f "${SCRIPTS_DIR}/${SCRIPT}" ]; then
        pct push "$CTID" "${SCRIPTS_DIR}/${SCRIPT}" "/tmp/$(basename "$SCRIPT")"
        log "CT${CTID}: enviado $(basename "$SCRIPT")"
    else
        error "Script não encontrado: ${SCRIPTS_DIR}/${SCRIPT}"
        return 1
    fi
}

push_directory_to_container() {
    local CTID=$1
    local SOURCE_DIR=$2
    local TARGET_TAR=$3
    local DESCRIPTION=$4

    if [ -d "${BASE_DIR}/${SOURCE_DIR}" ]; then
        local TMP_TAR="/tmp/grom-$(basename "$SOURCE_DIR")-${CTID}.tar.gz"
        tar -C "${BASE_DIR}/${SOURCE_DIR}" -czf "$TMP_TAR" .
        pct push "$CTID" "$TMP_TAR" "$TARGET_TAR"
        rm -f "$TMP_TAR"
        log "CT${CTID}: enviado ${DESCRIPTION}"
    else
        warn "Diretorio nao encontrado para envio ao CT${CTID}: ${BASE_DIR}/${SOURCE_DIR}"
    fi
}

wait_for_container() {
    local CTID=$1
    local MAX_WAIT=60
    local COUNT=0
    
    while [ $COUNT -lt $MAX_WAIT ]; do
        if pct exec "$CTID" -- true 2>/dev/null; then
            return 0
        fi
        sleep 2
        ((COUNT+=2))
    done
    error "Timeout aguardando CT${CTID}"
    return 1
}

setup_proxmox_backups() {
    local SCRIPT="${SCRIPTS_DIR}/proxmox/backup-containers.sh"

    if [ ! -f "$SCRIPT" ]; then
        warn "Script de backup Proxmox nao encontrado: ${SCRIPT}"
        return 0
    fi

    install -m 750 "$SCRIPT" /usr/local/sbin/grom-backup-containers.sh

    if [ -d /mnt/backup-external ]; then
        cat > /etc/cron.d/grom-proxmox-backup << 'CRONBACKUP'
# GROM SERVER - Backup diario de VM/containers no Proxmox host
30 2 * * * root /usr/local/sbin/grom-backup-containers.sh
CRONBACKUP
        log "Backup Proxmox agendado diariamente as 02:30"
    else
        warn "/mnt/backup-external nao existe. Agende grom-backup-containers.sh apos montar o HD externo."
    fi
}

setup_host_reports() {
    local REPORT_SCRIPT="${SCRIPTS_DIR}/proxmox/monthly-operational-report.sh"
    local POST_DEPLOY_SCRIPT="${SCRIPTS_DIR}/proxmox/post-deploy-validation.sh"
    local HEALTH_SCRIPT="${SCRIPTS_DIR}/proxmox/operational-health-check.sh"

    if [ -f "$POST_DEPLOY_SCRIPT" ]; then
        install -m 750 "$POST_DEPLOY_SCRIPT" /usr/local/sbin/grom-post-deploy-validation.sh
        log "Validador pos-deploy instalado em /usr/local/sbin"
    fi

    if [ -f "$HEALTH_SCRIPT" ]; then
        install -m 750 "$HEALTH_SCRIPT" /usr/local/sbin/grom-operational-health-check.sh
        cat > /etc/cron.d/grom-operational-health << 'CRONHEALTH'
# GROM SERVER - Health check operacional recorrente
*/15 * * * * root /usr/local/sbin/grom-operational-health-check.sh
CRONHEALTH
        log "Health check operacional agendado a cada 15 minutos"
    else
        warn "Script de health check operacional nao encontrado: ${HEALTH_SCRIPT}"
    fi

    if [ -f "$REPORT_SCRIPT" ]; then
        install -m 750 "$REPORT_SCRIPT" /usr/local/sbin/grom-monthly-operational-report.sh
        cat > /etc/cron.d/grom-monthly-report << 'CRONREPORT'
# GROM SERVER - Relatorio operacional mensal
15 7 1 * * root /usr/local/sbin/grom-monthly-operational-report.sh
CRONREPORT
        log "Relatorio mensal agendado para dia 1 as 07:15"
    else
        warn "Script de relatorio mensal nao encontrado: ${REPORT_SCRIPT}"
    fi
}

setup_host_email_relay() {
    local SCRIPT="${SCRIPTS_DIR}/security/setup-email-relay.sh"

    if [ -f "$SCRIPT" ]; then
        GROM_CONTACT_EMAIL="${GROM_CONTACT_EMAIL:-}" \
        GROM_ALERT_EMAIL="${GROM_ALERT_EMAIL:-}" \
        GROM_SMTP_USER="${GROM_SMTP_USER:-}" \
        GROM_SMTP_FROM="${GROM_SMTP_FROM:-}" \
        GROM_SMTP_APP_PASS="${GROM_SMTP_APP_PASS:-}" \
        bash "$SCRIPT" || warn "Relay SMTP do host nao foi configurado"
    else
        warn "Script de relay SMTP nao encontrado: ${SCRIPT}"
    fi
}

# =============================================================================
run_repository_audit
run_preflight_validation

# =============================================================================
section "FASE 1: Pós-instalação do Proxmox"
# =============================================================================
if [ -f "${SCRIPTS_DIR}/proxmox/post-install.sh" ]; then
    bash "${SCRIPTS_DIR}/proxmox/post-install.sh"
    log "Pós-instalação Proxmox concluída"
else
    warn "Script post-install.sh não encontrado, pulando..."
fi
setup_host_email_relay

# =============================================================================
section "FASE 2: Criação de Containers"
# =============================================================================
if [ -f "${SCRIPTS_DIR}/proxmox/create-containers.sh" ]; then
    bash "${SCRIPTS_DIR}/proxmox/create-containers.sh"
    log "Containers criados"
fi

setup_proxmox_backups
setup_host_reports

# Aguardar containers ficarem prontos
for CTID in 110 111 112 113 114; do
    info "Aguardando CT${CTID}..."
    wait_for_container "$CTID"
done
log "Todos os containers estão prontos"

# =============================================================================
section "FASE 3: Setup Web Server (CT110)"
# =============================================================================
push_directory_to_container 110 "apps/grom-seg/public" "/tmp/grom-seg-public.tar.gz" "dashboard e assets Grom.Seg"
run_in_container 110 "webserver/setup-nginx.sh" "Instalação Nginx"
run_in_container 110 "webserver/setup-php.sh" "Instalação PHP 8.3"
run_in_container 110 "webserver/setup-python.sh" "Instalação Python/FastAPI"
run_in_container 110 "security/hardening.sh" "Hardening de segurança"
run_in_container 110 "security/setup-email-relay.sh" "Relay SMTP"

# =============================================================================
section "FASE 4: Setup MySQL (CT111)"
# =============================================================================
require_env MYSQL_ROOT_PASS
require_env GROM_SEG_PASS
require_env GROM_WEB_PASS
require_env GROM_DOC_PASS
require_env GROM_BACKUP_PASS
run_in_container 111 "database/setup-mysql.sh" "Instalação MySQL 8.0"
run_in_container 111 "security/hardening.sh" "Hardening de segurança"
run_in_container 111 "security/setup-email-relay.sh" "Relay SMTP"

# =============================================================================
section "FASE 5: Setup Backup Local Temporario (CT112)"
# =============================================================================
require_env BORG_PASSPHRASE
push_to_container 112 "backup/backup-databases.sh"
push_to_container 112 "backup/backup-files.sh"
push_to_container 112 "backup/sync-google-drive.sh"
run_in_container 112 "backup/setup-backup.sh" "Configuração do Backup"
run_in_container 112 "security/hardening.sh" "Hardening de segurança"
run_in_container 112 "security/setup-email-relay.sh" "Relay SMTP"

# =============================================================================
section "FASE 6: Setup Monitoramento (CT113)"
# =============================================================================
run_in_container 113 "monitoring/setup-monitoring.sh" "Instalação Monitoramento"
run_in_container 113 "security/hardening.sh" "Hardening de segurança"
run_in_container 113 "security/setup-email-relay.sh" "Relay SMTP"

# =============================================================================
section "FASE 7: Setup VPN (CT114)"
# =============================================================================
run_in_container 114 "vpn/setup-wireguard.sh" "Configuração WireGuard"
run_in_container 114 "security/hardening.sh" "Hardening de segurança"
run_in_container 114 "security/setup-email-relay.sh" "Relay SMTP"

# =============================================================================
section "FASE 8: SSL/TLS (CT110)"
# =============================================================================
warn "SSL/TLS requer que o domínio grom.seg.br aponte para o servidor."
warn "Execute manualmente quando o DNS estiver configurado:"
warn "  pct exec 110 -- bash /tmp/setup-ssl.sh"

# =============================================================================
section "RESUMO DA IMPLANTAÇÃO"
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║            ✅ IMPLANTAÇÃO CONCLUÍDA!                 ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║  🌐 Grom.Seg:    10.0.1.10 (grom.seg.br)           ║"
echo "║  🗄️  MySQL:       10.0.1.11 (porta 3306)            ║"
echo "║  💾 Backup:      10.0.1.12 (automático via cron)    ║"
echo "║  📊 Monitoring:  10.0.1.13:19999 / :3001            ║"
echo "║  🔐 VPN:         10.0.1.14 (vpn.grom.seg.br:51820) ║"
echo "║                                                      ║"
echo "║  📋 Automações ativas:                               ║"
echo "║     • Backup databases: a cada 6h                    ║"
echo "║     • Backup arquivos: diário 02:00                  ║"
echo "║     • Sync HD externo: diário 04:00                  ║"
echo "║     • Health check operacional: a cada 15 min        ║"
echo "║     • Watchdog serviços: a cada 3 min                ║"
echo "║     • Updates segurança: diário (automático)         ║"
echo "║     • SSL renovação: automática                      ║"
echo "║     • VPN auto-recovery: a cada 5 min                ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Finalizado em: $(date)"
echo "Log completo: ${LOG_FILE}"
echo "Validacao pos-deploy recomendada:"
echo "  bash ${SCRIPTS_DIR}/proxmox/post-deploy-validation.sh"
echo "  bash ${SCRIPTS_DIR}/proxmox/post-deploy-validation.sh --public-target=${GROM_DOMAIN}"
echo "Relatorio operacional mensal:"
echo "  /usr/local/sbin/grom-monthly-operational-report.sh"
echo ""
