#!/bin/bash
# =============================================================================
# GROM SERVER - Health check operacional recorrente
# Executar no Proxmox host. Mede disponibilidade basica, recursos e frescor de
# backups. Nao altera servicos.
# =============================================================================

set -euo pipefail

STRICT=0
ENV_FILE="${GROM_ENV_FILE:-/etc/grom/grom.env}"
PUBLIC_TARGET="${GROM_PUBLIC_TARGET:-}"
REPORT_FILE="${GROM_OPERATIONAL_HEALTH_REPORT:-/var/log/grom-operational-health.log}"
JSON_FILE="${GROM_OPERATIONAL_HEALTH_JSON:-/var/log/grom-operational-health.json}"
MAX_DB_BACKUP_AGE_HOURS="${GROM_MAX_DB_BACKUP_AGE_HOURS:-8}"
MAX_VM_BACKUP_AGE_HOURS="${GROM_MAX_VM_BACKUP_AGE_HOURS:-36}"
PROXMOX_BACKUP_DIR="${GROM_PROXMOX_BACKUP_DIR:-/mnt/backup-external/proxmox}"

if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    . "$ENV_FILE"
fi

APP_DOMAIN="${GROM_APP_DOMAIN:-${GROM_DOMAIN:-grom.seg.br}}"
SERVICES_JSON=""
SERVICES_OK=0
SERVICES_TOTAL=0
DISK_PERCENT=0
MEMORY_PERCENT=0
BACKUP_DISK_PERCENT=0
DB_BACKUP_AGE_HOURS=""
VM_BACKUP_AGE_HOURS=""
ADMIN_PORTS_STATUS="nao testado"
VPN_STATUS="pendente"

for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --public-target=*) PUBLIC_TARGET="${arg#--public-target=}" ;;
        --report=*) REPORT_FILE="${arg#--report=}" ;;
        -h|--help)
            echo "Uso: $0 [--strict] [--public-target=HOST] [--report=/var/log/grom-operational-health.log]"
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

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

add_service() {
    local name="$1"
    local role="$2"
    local status="$3"

    SERVICES_TOTAL=$((SERVICES_TOTAL + 1))
    [ "$status" = "ok" ] && SERVICES_OK=$((SERVICES_OK + 1))

    local item
    item="{\"name\":\"$(json_escape "$name")\",\"role\":\"$(json_escape "$role")\",\"status\":\"$(json_escape "$status")\"}"
    if [ -z "$SERVICES_JSON" ]; then
        SERVICES_JSON="$item"
    else
        SERVICES_JSON="${SERVICES_JSON},${item}"
    fi
}

section() {
    echo ""
    echo "== $1 =="
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

ct_exec_ok() {
    local ctid="$1"
    shift
    pct exec "$ctid" -- "$@" >/dev/null 2>&1
}

check_vm_running() {
    local vmid="$1"
    local name="$2"

    if qm status "$vmid" 2>/dev/null | grep -q 'status: running'; then
        ok "VM${vmid} ${name} em execucao"
        add_service "$name" "VM${vmid}" "ok"
    else
        fail "VM${vmid} ${name} fora de execucao"
        add_service "$name" "VM${vmid}" "fail"
    fi
}

check_optional_vm() {
    local vmid="$1"
    local name="$2"

    if ! qm status "$vmid" >/dev/null 2>&1; then
        warn "VM${vmid} ${name} ainda nao criada"
        add_service "$name" "VM${vmid}" "warn"
        return
    fi

    check_vm_running "$vmid" "$name"
}

check_ct_running() {
    local ctid="$1"
    local name="$2"

    if pct status "$ctid" 2>/dev/null | grep -q 'status: running'; then
        ok "CT${ctid} ${name} em execucao"
        add_service "$name" "CT${ctid}" "ok"
    else
        fail "CT${ctid} ${name} fora de execucao"
        add_service "$name" "CT${ctid}" "fail"
    fi
}

check_ct_service() {
    local ctid="$1"
    local service="$2"
    local label="$3"

    if ct_exec_ok "$ctid" systemctl is-active --quiet "$service"; then
        ok "CT${ctid}: ${label} ativo"
        [ "$service" = "wg-quick@wg0" ] && VPN_STATUS="ok"
    else
        fail "CT${ctid}: ${label} inativo ou ausente"
        [ "$service" = "wg-quick@wg0" ] && VPN_STATUS="falha"
    fi
}

check_disk() {
    local usage
    usage="$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')"
    DISK_PERCENT="${usage:-0}"

    if [ "${usage:-100}" -lt 80 ]; then
        ok "Disco raiz abaixo de 80% (${usage}%)"
    elif [ "${usage:-100}" -lt 90 ]; then
        warn "Disco raiz acima de 80% (${usage}%)"
    else
        fail "Disco raiz acima de 90% (${usage}%)"
    fi
}

check_memory() {
    local available_kb total_kb available_pct
    available_kb="$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
    total_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 1)"
    available_pct="$((available_kb * 100 / total_kb))"
    MEMORY_PERCENT="$((100 - available_pct))"

    if [ "$available_pct" -ge 20 ]; then
        ok "Memoria disponivel adequada (${available_pct}%)"
    elif [ "$available_pct" -ge 10 ]; then
        warn "Memoria disponivel baixa (${available_pct}%)"
    else
        fail "Memoria disponivel critica (${available_pct}%)"
    fi
}

check_latest_file_age() {
    local path="$1"
    local pattern="$2"
    local max_hours="$3"
    local label="$4"

    if [ ! -d "$path" ]; then
        fail "${label}: diretorio ausente (${path})"
        return
    fi

    local latest
    latest="$(find "$path" -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | awk '{print $1}')"

    if [ -z "$latest" ]; then
        fail "${label}: nenhum arquivo encontrado (${pattern})"
        return
    fi

    local now age_hours
    now="$(date +%s)"
    age_hours="$(awk -v now="$now" -v latest="$latest" 'BEGIN { printf "%.0f", (now - latest) / 3600 }')"

    if [ "$age_hours" -le "$max_hours" ]; then
        ok "${label}: fresco (${age_hours}h)"
    else
        fail "${label}: vencido (${age_hours}h > ${max_hours}h)"
    fi

    if [ "$label" = "Backup VM/LXC" ]; then
        VM_BACKUP_AGE_HOURS="$age_hours"
    fi
}

check_ct_latest_dump() {
    local latest
    latest="$(pct exec 112 -- bash -lc "find /mnt/backup/databases/dumps -type f -name '*.sql.gz' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | awk '{print \\\$1}'" 2>/dev/null || true)"

    if [ -z "$latest" ]; then
        fail "Backup DB: nenhum dump encontrado no CT112"
        return
    fi

    local now age_hours
    now="$(date +%s)"
    age_hours="$(awk -v now="$now" -v latest="$latest" 'BEGIN { printf "%.0f", (now - latest) / 3600 }')"
    DB_BACKUP_AGE_HOURS="$age_hours"

    if [ "$age_hours" -le "$MAX_DB_BACKUP_AGE_HOURS" ]; then
        ok "Backup DB fresco (${age_hours}h)"
    else
        fail "Backup DB vencido (${age_hours}h > ${MAX_DB_BACKUP_AGE_HOURS}h)"
    fi
}

check_public_admin_ports() {
    if [ -z "$PUBLIC_TARGET" ]; then
        warn "Sem --public-target; portas publicas administrativas nao testadas"
        return
    fi

    if ! have_cmd nc; then
        warn "nc ausente; portas publicas administrativas nao testadas"
        return
    fi

    for port in 8006 3306 19999 3001; do
        if nc -z -w 4 "$PUBLIC_TARGET" "$port" >/dev/null 2>&1; then
            fail "Porta administrativa publica aberta: ${PUBLIC_TARGET}:${port}"
            ADMIN_PORTS_STATUS="falha"
        else
            ok "Porta administrativa fechada publicamente: ${port}"
        fi
    done

    if [ "$ADMIN_PORTS_STATUS" != "falha" ]; then
        ADMIN_PORTS_STATUS="fechadas"
    fi
}

capture_resource_extras() {
    local load threads
    load="$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)"
    threads="$(nproc 2>/dev/null || echo 1)"
    CPU_PERCENT="$(awk -v load="$load" -v threads="$threads" 'BEGIN { pct=(load/threads)*100; if (pct > 100) pct=100; printf "%.0f", pct }')"

    if [ -d /mnt/backup-external ]; then
        BACKUP_DISK_PERCENT="$(df -P /mnt/backup-external 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}' || echo 0)"
    fi
}

write_dashboard_json() {
    local overall="ok"
    if [ "$FAIL" -gt 0 ]; then
        overall="fail"
    elif [ "$WARN" -gt 0 ]; then
        overall="warn"
    fi

    local gono="GO controlado"
    [ "$overall" != "ok" ] && gono="NO-GO"

    mkdir -p "$(dirname "$JSON_FILE")"
    cat > "$JSON_FILE" << JSONEOF
{
  "generated_at": "$(date -Is)",
  "status": "${overall}",
  "summary": {
    "failures": ${FAIL},
    "warnings": ${WARN},
    "services_ok": ${SERVICES_OK},
    "services_total": ${SERVICES_TOTAL}
  },
  "resources": {
    "cpu_percent": ${CPU_PERCENT:-0},
    "memory_percent": ${MEMORY_PERCENT:-0},
    "disk_percent": ${DISK_PERCENT:-0},
    "backup_disk_percent": ${BACKUP_DISK_PERCENT:-0}
  },
  "backups": {
    "db_age_hours": ${DB_BACKUP_AGE_HOURS:-null},
    "vm_age_hours": ${VM_BACKUP_AGE_HOURS:-null},
    "restore_drill": "$(if [ -f /etc/grom/production-readiness.d/restore-tested ]; then echo ok; else echo pendente; fi)"
  },
  "security": {
    "admin_ports": "${ADMIN_PORTS_STATUS}",
    "vpn": "${VPN_STATUS}",
    "gono": "${gono}"
  },
  "services": [${SERVICES_JSON}]
}
JSONEOF

    if have_cmd pct && pct status 110 2>/dev/null | grep -q 'status: running'; then
        pct exec 110 -- mkdir -p "/var/www/${APP_DOMAIN}/public/server/data" >/dev/null 2>&1 || true
        pct push 110 "$JSON_FILE" "/var/www/${APP_DOMAIN}/public/server/data/status.json" >/dev/null 2>&1 || true
    fi
}

mkdir -p "$(dirname "$REPORT_FILE")"
exec > >(tee -a "$REPORT_FILE") 2>&1

echo ""
echo "=== GROM SERVER - Health check operacional ==="
echo "Inicio: $(date -Is)"

section "Host"
if [ "$(id -u)" -eq 0 ]; then
    ok "Execucao como root"
else
    fail "Execute como root no Proxmox host"
fi

for cmd in pct qm df awk find; do
    if have_cmd "$cmd"; then
        ok "Comando disponivel: ${cmd}"
    else
        fail "Comando ausente: ${cmd}"
    fi
done

check_disk
check_memory
capture_resource_extras

section "VM e containers"
check_vm_running 100 "OPNsense"
check_optional_vm 120 "Home Assistant OS"
check_optional_vm 130 "Grom_Security"
check_ct_running 110 "Web/SigePol"
check_ct_running 111 "Database"
check_ct_running 112 "Backup"
check_ct_running 113 "Monitoring"
check_ct_running 114 "VPN"

section "Servicos"
check_ct_service 110 nginx "Nginx"
check_ct_service 110 php8.3-fpm "PHP-FPM"
check_ct_service 111 mysql "MySQL"
check_ct_service 113 netdata "Netdata"
check_ct_service 114 wg-quick@wg0 "WireGuard"

section "Backups"
check_ct_latest_dump
check_latest_file_age "$PROXMOX_BACKUP_DIR" 'vzdump-*' "$MAX_VM_BACKUP_AGE_HOURS" "Backup VM/LXC"

section "Exposicao"
check_public_admin_ports

write_dashboard_json

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
