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

SCRIPTS_DIR="/root/grom-scripts"
LOG_FILE="/var/log/grom-deploy.log"

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

# Função para copiar e executar script em container
run_in_container() {
    local CTID=$1
    local SCRIPT=$2
    local DESCRIPTION=$3
    
    info "CT${CTID}: ${DESCRIPTION}..."
    
    if [ -f "${SCRIPTS_DIR}/${SCRIPT}" ]; then
        pct push "$CTID" "${SCRIPTS_DIR}/${SCRIPT}" "/tmp/$(basename "$SCRIPT")"
        pct exec "$CTID" -- bash "/tmp/$(basename "$SCRIPT")" || {
            error "CT${CTID}: Falha em ${DESCRIPTION}"
            return 1
        }
        log "CT${CTID}: ${DESCRIPTION} ✅"
    else
        error "Script não encontrado: ${SCRIPTS_DIR}/${SCRIPT}"
        return 1
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

# =============================================================================
section "FASE 1: Pós-instalação do Proxmox"
# =============================================================================
if [ -f "${SCRIPTS_DIR}/proxmox/post-install.sh" ]; then
    bash "${SCRIPTS_DIR}/proxmox/post-install.sh"
    log "Pós-instalação Proxmox concluída"
else
    warn "Script post-install.sh não encontrado, pulando..."
fi

# =============================================================================
section "FASE 2: Criação de Containers"
# =============================================================================
if [ -f "${SCRIPTS_DIR}/proxmox/create-containers.sh" ]; then
    bash "${SCRIPTS_DIR}/proxmox/create-containers.sh"
    log "Containers criados"
fi

# Aguardar containers ficarem prontos
for CTID in 100 101 102 103 104; do
    info "Aguardando CT${CTID}..."
    wait_for_container "$CTID"
done
log "Todos os containers estão prontos"

# =============================================================================
section "FASE 3: Setup Web Server (CT100)"
# =============================================================================
run_in_container 100 "webserver/setup-nginx.sh" "Instalação Nginx"
run_in_container 100 "webserver/setup-php.sh" "Instalação PHP 8.3"
run_in_container 100 "webserver/setup-python.sh" "Instalação Python/FastAPI"
run_in_container 100 "security/hardening.sh" "Hardening de segurança"

# =============================================================================
section "FASE 4: Setup MySQL (CT101)"
# =============================================================================
run_in_container 101 "database/setup-mysql.sh" "Instalação MySQL 8.0"
run_in_container 101 "security/hardening.sh" "Hardening de segurança"

# =============================================================================
section "FASE 5: Setup Backup (CT102)"
# =============================================================================
run_in_container 102 "backup/setup-backup.sh" "Configuração do Backup"
run_in_container 102 "security/hardening.sh" "Hardening de segurança"

# =============================================================================
section "FASE 6: Setup Monitoramento (CT103)"
# =============================================================================
run_in_container 103 "monitoring/setup-monitoring.sh" "Instalação Monitoramento"
run_in_container 103 "security/hardening.sh" "Hardening de segurança"

# =============================================================================
section "FASE 7: Setup VPN (CT104)"
# =============================================================================
run_in_container 104 "vpn/setup-wireguard.sh" "Configuração WireGuard"
run_in_container 104 "security/hardening.sh" "Hardening de segurança"

# =============================================================================
section "FASE 8: SSL/TLS (CT100)"
# =============================================================================
warn "SSL/TLS requer que o domínio grom.seg.br aponte para o servidor."
warn "Execute manualmente quando o DNS estiver configurado:"
warn "  pct exec 100 -- bash /tmp/setup-ssl.sh"

# =============================================================================
section "RESUMO DA IMPLANTAÇÃO"
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║            ✅ IMPLANTAÇÃO CONCLUÍDA!                 ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║  🌐 Web Server:  10.0.1.10 (web.grom.seg.br)       ║"
echo "║  🗄️  MySQL:       10.0.1.11 (porta 3306)            ║"
echo "║  💾 Backup:      10.0.1.12 (automático via cron)    ║"
echo "║  📊 Monitoring:  10.0.1.13:19999 / :3001            ║"
echo "║  🔐 VPN:         10.0.1.14 (vpn.grom.seg.br:51820) ║"
echo "║                                                      ║"
echo "║  📋 Automações ativas:                               ║"
echo "║     • Backup databases: a cada 6h                    ║"
echo "║     • Backup arquivos: diário 02:00                  ║"
echo "║     • Sync HD externo: diário 04:00                  ║"
echo "║     • Health check: a cada 6h                        ║"
echo "║     • Watchdog serviços: a cada 3 min                ║"
echo "║     • Updates segurança: diário (automático)         ║"
echo "║     • SSL renovação: automática                      ║"
echo "║     • VPN auto-recovery: a cada 5 min                ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Finalizado em: $(date)"
echo "Log completo: ${LOG_FILE}"
echo ""
