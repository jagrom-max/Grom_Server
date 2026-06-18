#!/bin/bash
# =============================================================================
# GROM SERVER - Baseline de capacidade do host definitivo
# Executar no Proxmox host antes/depois do deploy para medir margem operacional.
# Nao altera configuracoes; apenas gera relatorio.
# =============================================================================

set -euo pipefail

STRICT=0
REPORT_FILE="${GROM_CAPACITY_REPORT:-/var/log/grom-capacity-baseline.log}"

for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --report=*) REPORT_FILE="${arg#--report=}" ;;
        -h|--help)
            echo "Uso: $0 [--strict] [--report=/var/log/grom-capacity-baseline.log]"
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

to_gib() {
    awk -v kb="$1" 'BEGIN { printf "%.1f", kb / 1024 / 1024 }'
}

mkdir -p "$(dirname "$REPORT_FILE")"
exec > >(tee "$REPORT_FILE") 2>&1

echo "=== GROM SERVER - Baseline de capacidade ==="
echo "Inicio: $(date -Is)"

section "CPU e virtualizacao"
THREADS="$(nproc 2>/dev/null || echo 0)"
CORES="$(awk -F: '/^cpu cores/ {gsub(/ /,"",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null || echo 0)"
MODEL="$(awk -F: '/model name/ {sub(/^ /,"",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null || echo desconhecido)"

echo "CPU: ${MODEL}"
echo "Cores fisicos informados: ${CORES:-0}"
echo "Threads: ${THREADS:-0}"

if [ "${THREADS:-0}" -ge 8 ]; then
    ok "CPU com 8+ threads para Server + SigePol + Security em carga moderada"
elif [ "${THREADS:-0}" -ge 4 ]; then
    warn "CPU com margem limitada; evitar OCR/video pesado continuo"
else
    fail "CPU insuficiente para a arquitetura proposta"
fi

if grep -Eiq 'vmx|svm' /proc/cpuinfo; then
    ok "Virtualizacao de CPU habilitada"
else
    fail "Virtualizacao de CPU nao detectada"
fi

if [ -d /dev/dri ]; then
    ok "Dispositivo /dev/dri presente para possivel iGPU/OpenVINO"
else
    warn "iGPU /dev/dri nao detectada; Grom_Security pode depender de CPU para video/OCR"
fi

section "Memoria"
MEM_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
MEM_GIB="$(to_gib "${MEM_KB:-0}")"
echo "RAM total: ${MEM_GIB} GiB"

if awk -v mem="$MEM_GIB" 'BEGIN { exit !(mem >= 15.0) }'; then
    ok "RAM compativel com fase inicial controlada (16GB nominal)"
elif awk -v mem="$MEM_GIB" 'BEGIN { exit !(mem >= 12.0) }'; then
    warn "RAM abaixo do ideal; Security e SigePol devem ser limitados"
else
    fail "RAM insuficiente para operacao confiavel"
fi

echo ""
echo "Reserva operacional recomendada:"
echo "- Proxmox/host: 2 GiB"
echo "- OPNsense VM100: 2 GiB"
echo "- Web/SigePol CT110: 4 GiB inicial"
echo "- Database CT111: 3 GiB inicial"
echo "- Backup CT112: 1 GiB"
echo "- Monitoring CT113: 1 GiB"
echo "- VPN CT114: 0.5 GiB"
echo "- Home Assistant VM120: 2 GiB, se ativada"
echo "- Grom_Security VM130: 4 GiB inicial; mais se video/OCR continuo"
warn "Com 16GB, ativar Security pesado e SigePol completo exige monitoramento de memoria e ajustes finos"

section "Disco"
ROOT_LINE="$(df -Pk / | awk 'NR==2 {print $2, $3, $4, $5, $6}')"
ROOT_TOTAL_KB="$(printf '%s\n' "$ROOT_LINE" | awk '{print $1}')"
ROOT_USED_PCT="$(printf '%s\n' "$ROOT_LINE" | awk '{gsub("%","",$4); print $4}')"
ROOT_AVAIL_GIB="$(printf '%s\n' "$ROOT_LINE" | awk '{printf "%.1f", $3 / 1024 / 1024}')"

echo "Raiz: ${ROOT_AVAIL_GIB} GiB livres; uso ${ROOT_USED_PCT:-0}%"

if awk -v free="$ROOT_AVAIL_GIB" 'BEGIN { exit !(free >= 500.0) }'; then
    ok "Espaco livre adequado para VMs/LXC, logs e crescimento inicial"
elif awk -v free="$ROOT_AVAIL_GIB" 'BEGIN { exit !(free >= 250.0) }'; then
    warn "Espaco livre moderado; limitar retencao local de video/evidencias"
else
    fail "Espaco livre insuficiente para implantacao segura"
fi

if [ "${ROOT_USED_PCT:-100}" -lt 75 ]; then
    ok "Uso de disco raiz abaixo de 75%"
else
    warn "Uso de disco raiz alto antes da producao"
fi

section "Backup externo"
if [ -d /mnt/backup-external ]; then
    if mountpoint -q /mnt/backup-external; then
        ok "HD externo montado em /mnt/backup-external"
        df -h /mnt/backup-external || true
    else
        warn "/mnt/backup-external existe, mas nao esta montado"
    fi
else
    warn "HD externo principal ainda nao preparado em /mnt/backup-external"
fi

if [ -d /mnt/backup-external-2 ]; then
    if mountpoint -q /mnt/backup-external-2; then
        ok "Segundo HD externo/offline montado"
    else
        warn "Segundo HD externo existe, mas nao esta montado"
    fi
else
    warn "Segundo HD externo/offline ainda nao configurado"
fi

section "Rede"
IFACES="$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v '^lo$' | wc -l || echo 0)"
echo "Interfaces nao-loopback: ${IFACES}"

if [ "${IFACES:-0}" -ge 2 ]; then
    ok "Duas ou mais interfaces para separacao WAN/LAN"
else
    fail "Menos de duas interfaces; OPNsense nao deve operar sem separacao real"
fi

if have_cmd ethtool; then
    ip -br link show 2>/dev/null || true
else
    warn "ethtool ausente; nao foi possivel validar velocidade/link"
fi

section "Temperatura e saude"
if have_cmd sensors; then
    sensors || true
else
    warn "sensors ausente; instalar lm-sensors para acompanhar temperatura"
fi

if have_cmd smartctl; then
    ok "smartctl disponivel para avaliar SSD/HD"
else
    warn "smartctl ausente; instalar smartmontools para diagnostico de disco"
fi

section "Conclusao"
echo "Perfil recomendado ate a producao:"
echo "- Ativar primeiro infraestrutura base, VPN, backup e monitoramento."
echo "- SigePol: iniciar com carga interna/controlada e medir CPU/RAM/banco."
echo "- Security: iniciar em dry-run; evitar OCR/video continuo ate medir baseline."
echo "- Retencao longa de video/evidencias deve depender de HD externo e politica definida."

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
