#!/bin/bash
# =============================================================================
# GROM SERVER - Verificacao de prontidao do Proxmox host
# Executar no mini PC apos instalar Proxmox e antes do deploy.
# =============================================================================

set -euo pipefail

FAIL=0
WARN=0

ok() { echo "[OK] $1"; }
warn() { echo "[AVISO] $1"; WARN=$((WARN + 1)); }
fail() { echo "[FALHA] $1"; FAIL=$((FAIL + 1)); }

echo "=== GROM SERVER - Verificacao de Host ==="

if [ "$(id -u)" -ne 0 ]; then
    fail "Execute como root no Proxmox host"
fi

if command -v pveversion >/dev/null 2>&1; then
    ok "Proxmox detectado: $(pveversion | head -1)"
else
    fail "pveversion nao encontrado"
fi

if grep -Eiq 'vmx|svm' /proc/cpuinfo; then
    ok "Virtualizacao de CPU habilitada"
else
    fail "Virtualizacao de CPU nao detectada. Verificar BIOS VT-x/VT-d."
fi

if dmesg | grep -Eiq 'DMAR|IOMMU'; then
    ok "IOMMU/DMAR aparece no kernel"
else
    warn "IOMMU/DMAR nao identificado no dmesg. Pode exigir BIOS/GRUB."
fi

IFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | wc -l)
if [ "$IFACES" -ge 2 ]; then
    ok "Duas ou mais interfaces de rede detectadas (${IFACES})"
else
    fail "Menos de duas interfaces de rede detectadas"
fi

if ip -o link show | grep -Eq 'enx|usb|eth'; then
    ok "Interfaces de rede listadas"
    ip -br link show
fi

if lsusb 2>/dev/null | grep -Eiq 'Realtek|2.5G|8156|8152|UGREEN'; then
    ok "Adaptador USB Ethernet possivelmente detectado"
else
    warn "Adaptador USB Ethernet nao identificado por lsusb"
fi

if [ -d /mnt/backup-external ]; then
    if mountpoint -q /mnt/backup-external; then
        ok "HD externo montado em /mnt/backup-external"
    else
        warn "/mnt/backup-external existe, mas nao esta montado"
    fi
else
    warn "/mnt/backup-external ainda nao existe"
fi

if [ -d /mnt/backup-external-2 ]; then
    if mountpoint -q /mnt/backup-external-2; then
        ok "Segundo HD externo montado em /mnt/backup-external-2"
    else
        warn "/mnt/backup-external-2 existe, mas nao esta montado"
    fi
else
    warn "Segundo HD externo opcional ainda nao existe em /mnt/backup-external-2"
fi

for cmd in pct qm vzdump ip ethtool lsusb smartctl sensors; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "Comando disponivel: $cmd"
    else
        warn "Comando ausente: $cmd"
    fi
done

ROOT_USAGE=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')
if [ "${ROOT_USAGE:-0}" -lt 80 ]; then
    ok "Uso de disco raiz abaixo de 80% (${ROOT_USAGE}%)"
else
    warn "Uso de disco raiz alto (${ROOT_USAGE}%)"
fi

echo ""
echo "Resumo: ${FAIL} falha(s), ${WARN} aviso(s)"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

exit 0
