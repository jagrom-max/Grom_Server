#!/bin/bash
# =============================================================================
# GROM SERVER - Validacao pos-deploy
# Executar no Proxmox host depois de deploy-all.sh.
# Nao corrige automaticamente; apenas mede e aponta pendencias.
# =============================================================================

set -euo pipefail

PUBLIC_TARGET="${GROM_PUBLIC_TARGET:-}"
STRICT=0
REPORT_FILE="${GROM_POST_DEPLOY_REPORT:-/var/log/grom-post-deploy-validation.log}"

for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --public-target=*) PUBLIC_TARGET="${arg#--public-target=}" ;;
        --report=*) REPORT_FILE="${arg#--report=}" ;;
        -h|--help)
            echo "Uso: $0 [--strict] [--public-target=IP_OU_HOST] [--report=/var/log/grom-post-deploy-validation.log]"
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

section() {
    echo ""
    echo "== $1 =="
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        fail "Execute como root no Proxmox host"
    else
        ok "Execucao como root"
    fi
}

check_vm_running() {
    local vmid="$1"
    local name="$2"

    if ! have_cmd qm; then
        fail "Comando qm ausente"
        return
    fi

    if qm status "$vmid" 2>/dev/null | grep -q "status: running"; then
        ok "VM${vmid} ${name} em execucao"
    else
        fail "VM${vmid} ${name} nao esta em execucao"
    fi
}

check_optional_vm_running() {
    local vmid="$1"
    local name="$2"

    if ! have_cmd qm; then
        warn "Comando qm ausente para verificar VM opcional ${vmid}"
        return
    fi

    if ! qm status "$vmid" >/dev/null 2>&1; then
        warn "VM${vmid} ${name} ainda nao criada"
        return
    fi

    if qm status "$vmid" 2>/dev/null | grep -q "status: running"; then
        ok "VM${vmid} ${name} em execucao"
    else
        warn "VM${vmid} ${name} existe, mas nao esta em execucao"
    fi
}

check_ct_running() {
    local ctid="$1"
    local name="$2"

    if ! have_cmd pct; then
        fail "Comando pct ausente"
        return
    fi

    if pct status "$ctid" 2>/dev/null | grep -q "status: running"; then
        ok "CT${ctid} ${name} em execucao"
    else
        fail "CT${ctid} ${name} nao esta em execucao"
    fi
}

ct_exec_ok() {
    local ctid="$1"
    shift
    pct exec "$ctid" -- "$@" >/dev/null 2>&1
}

check_ct_service() {
    local ctid="$1"
    local service="$2"
    local label="$3"

    if ct_exec_ok "$ctid" systemctl is-active --quiet "$service"; then
        ok "CT${ctid}: servico ativo: ${label}"
    else
        warn "CT${ctid}: servico nao ativo ou ausente: ${label}"
    fi
}

check_ct_port() {
    local ctid="$1"
    local host="$2"
    local port="$3"
    local label="$4"

    if ct_exec_ok "$ctid" bash -c "timeout 3 bash -c '</dev/tcp/${host}/${port}'"; then
        ok "CT${ctid}: porta acessivel ${label} (${host}:${port})"
    else
        fail "CT${ctid}: porta inacessivel ${label} (${host}:${port})"
    fi
}

check_ct_file() {
    local ctid="$1"
    local path="$2"
    local label="$3"

    if ct_exec_ok "$ctid" test -e "$path"; then
        ok "CT${ctid}: ${label} existe"
    else
        warn "CT${ctid}: ${label} ausente"
    fi
}

check_host_path() {
    local path="$1"
    local label="$2"

    if [ -e "$path" ]; then
        ok "Host: ${label} existe"
    else
        warn "Host: ${label} ausente"
    fi
}

check_public_port() {
    local port="$1"
    local expected="$2"
    local label="$3"

    if [ -z "$PUBLIC_TARGET" ]; then
        warn "Teste publico ignorado para ${label}; informe --public-target"
        return
    fi

    if ! have_cmd nc; then
        warn "Comando nc ausente; nao foi possivel testar ${label}"
        return
    fi

    if nc -z -w 4 "$PUBLIC_TARGET" "$port" >/dev/null 2>&1; then
        if [ "$expected" = "open" ]; then
            ok "Publico: ${label} aberto conforme esperado (${PUBLIC_TARGET}:${port})"
        else
            fail "Publico: ${label} esta aberto, mas deveria estar bloqueado (${PUBLIC_TARGET}:${port})"
        fi
    else
        if [ "$expected" = "closed" ]; then
            ok "Publico: ${label} bloqueado conforme esperado (${PUBLIC_TARGET}:${port})"
        else
            warn "Publico: ${label} nao respondeu; confirmar DNS/NAT/firewall (${PUBLIC_TARGET}:${port})"
        fi
    fi
}

check_public_udp() {
    local port="$1"
    local label="$2"

    if [ -z "$PUBLIC_TARGET" ]; then
        warn "Teste publico ignorado para ${label}; informe --public-target"
        return
    fi

    if ! have_cmd nc; then
        warn "Comando nc ausente; nao foi possivel testar ${label}"
        return
    fi

    if nc -z -u -w 4 "$PUBLIC_TARGET" "$port" >/dev/null 2>&1; then
        ok "Publico: ${label} UDP respondeu (${PUBLIC_TARGET}:${port})"
    else
        warn "Publico: ${label} UDP nao confirmado; validar com cliente WireGuard externo (${PUBLIC_TARGET}:${port})"
    fi
}

mkdir -p "$(dirname "$REPORT_FILE")"
exec > >(tee "$REPORT_FILE") 2>&1

echo "=== GROM SERVER - Validacao pos-deploy ==="
echo "Inicio: $(date -Is)"

section "Host e virtualizacao"
check_root
have_cmd pveversion && ok "Proxmox detectado: $(pveversion | head -1)" || fail "pveversion ausente"
check_host_path /var/log/grom-deploy.log "log principal do deploy"
check_host_path /usr/local/sbin/grom-backup-containers.sh "script de backup VM/LXC"

section "VM e containers"
check_vm_running 100 "OPNsense"
check_optional_vm_running 120 "Home Assistant OS"
check_optional_vm_running 130 "Grom_Security"
check_ct_running 110 "Web"
check_ct_running 111 "Database"
check_ct_running 112 "Backup"
check_ct_running 113 "Monitoring"
check_ct_running 114 "VPN"

section "Servicos internos"
check_ct_service 110 nginx "Nginx"
check_ct_service 110 php8.3-fpm "PHP-FPM"
check_ct_service 111 mysql "MySQL"
check_ct_service 114 wg-quick@wg0 "WireGuard"
check_ct_service 113 netdata "Netdata"

section "Conectividade interna"
check_ct_port 110 10.0.1.11 3306 "Web -> MySQL"
check_ct_port 112 10.0.1.11 3306 "Backup -> MySQL"
check_ct_port 113 10.0.1.10 80 "Monitor -> Web HTTP"

section "Backup e rotinas"
check_ct_file 112 /root/.grom_backup_env "ambiente restrito de backup"
check_ct_file 112 /etc/cron.d/grom-backup "agenda de backup"
check_ct_file 112 /mnt/backup "diretorio de backup"
if [ -d /mnt/backup-external-2 ]; then
    check_ct_file 112 /mnt/external2 "segundo HD externo no CT112"
else
    warn "Segundo HD externo opcional nao configurado em /mnt/backup-external-2"
fi
check_host_path /etc/cron.d/grom-proxmox-backup "cron de backup Proxmox"

section "Seguranca local"
check_ct_file 110 /etc/fail2ban "Fail2Ban no Web"
check_ct_file 111 /etc/fail2ban "Fail2Ban no Database"
check_ct_file 112 /etc/fail2ban "Fail2Ban no Backup"
check_ct_file 113 /etc/fail2ban "Fail2Ban no Monitoring"
check_ct_file 114 /etc/fail2ban "Fail2Ban no VPN"

section "Exposicao publica opcional"
check_public_port 80 open "HTTP"
check_public_port 443 open "HTTPS"
check_public_udp 51820 "WireGuard"
check_public_port 8006 closed "Proxmox WebGUI"
check_public_port 3306 closed "MySQL"
check_public_port 19999 closed "Netdata"
check_public_port 3001 closed "Uptime Kuma"

echo ""
echo "Resumo: ${FAIL} falha(s), ${WARN} aviso(s)"
echo "Fim: $(date -Is)"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

if [ "$STRICT" -eq 1 ] && [ "$WARN" -gt 0 ]; then
    exit 1
fi

exit 0
