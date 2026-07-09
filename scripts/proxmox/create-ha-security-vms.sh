#!/bin/bash
# =============================================================================
# GROM SERVER - Criacao da VM Grom_Security e HA opcional/legado
# Executar no Proxmox host apos OPNsense/rede base.
# =============================================================================

set -euo pipefail

STORAGE="${GROM_VM_STORAGE:-local-lvm}"
ISO_STORAGE="${GROM_ISO_STORAGE:-local}"
HA_VM_ID="${HA_VM_ID:-120}"
SEC_VM_ID="${SEC_VM_ID:-130}"
CREATE_HA_VM="${CREATE_HA_VM:-0}"
HA_NAME="${HA_NAME:-home-assistant}"
SEC_NAME="${SEC_NAME:-grom-security}"
HA_DISK_GB="${HA_DISK_GB:-32}"
SEC_DISK_GB="${SEC_DISK_GB:-100}"
HA_RAM_MB="${HA_RAM_MB:-2048}"
SEC_RAM_MB="${SEC_RAM_MB:-4096}"
HA_CORES="${HA_CORES:-2}"
SEC_CORES="${SEC_CORES:-4}"
UBUNTU_ISO="${GROM_SECURITY_ISO:-}"
HA_IMAGE="${HAOS_QCOW2_IMAGE:-}"

log() { echo "[OK] $1"; }
warn() { echo "[AVISO] $1"; }
fail() { echo "[FALHA] $1"; exit 1; }

require_root() {
    [ "$(id -u)" -eq 0 ] || fail "Execute como root no Proxmox host"
    command -v qm >/dev/null 2>&1 || fail "Comando qm nao encontrado"
}

vm_exists() {
    qm status "$1" >/dev/null 2>&1
}

create_ha_vm() {
    if vm_exists "$HA_VM_ID"; then
        warn "VM${HA_VM_ID} ${HA_NAME} ja existe, pulando"
        return
    fi

    if [ -z "$HA_IMAGE" ] || [ ! -f "$HA_IMAGE" ]; then
        warn "Imagem Home Assistant OS nao informada."
        warn "Defina HAOS_QCOW2_IMAGE=/caminho/haos_ova.qcow2 e execute novamente."
        return
    fi

    qm create "$HA_VM_ID" \
        --name "$HA_NAME" \
        --memory "$HA_RAM_MB" \
        --cores "$HA_CORES" \
        --cpu host \
        --net0 virtio,bridge=vmbr1 \
        --ostype l26 \
        --agent enabled=1 \
        --onboot 1 \
        --startup order=2,up=30 \
        --description "Home Assistant OS - automacao, Matter, Zemismart, alarm panel, MQTT integration"

    qm importdisk "$HA_VM_ID" "$HA_IMAGE" "$STORAGE"
    qm set "$HA_VM_ID" --scsihw virtio-scsi-pci --scsi0 "${STORAGE}:vm-${HA_VM_ID}-disk-0"
    qm set "$HA_VM_ID" --boot order=scsi0
    qm set "$HA_VM_ID" --serial0 socket --vga serial0
    log "VM${HA_VM_ID} ${HA_NAME} criada"
}

create_security_vm() {
    if vm_exists "$SEC_VM_ID"; then
        warn "VM${SEC_VM_ID} ${SEC_NAME} ja existe, pulando"
        return
    fi

    local cdrom_args=()
    if [ -n "$UBUNTU_ISO" ]; then
        cdrom_args=(--cdrom "${ISO_STORAGE}:iso/${UBUNTU_ISO}")
    else
        warn "GROM_SECURITY_ISO nao definido. VM sera criada sem ISO."
    fi

    qm create "$SEC_VM_ID" \
        --name "$SEC_NAME" \
        --memory "$SEC_RAM_MB" \
        --cores "$SEC_CORES" \
        --cpu host \
        --net0 virtio,bridge=vmbr1 \
        --ostype l26 \
        --agent enabled=1 \
        --balloon 0 \
        --onboot 1 \
        --startup order=3,up=30 \
        --scsihw virtio-scsi-pci \
        --scsi0 "${STORAGE}:${SEC_DISK_GB}" \
        --boot order=scsi0 \
        --description "Grom_Security - Docker Compose, MQTT, video, OpenCV, OCR, eventos e alertas" \
        "${cdrom_args[@]}"

    log "VM${SEC_VM_ID} ${SEC_NAME} criada"
}

require_root
if [ "$CREATE_HA_VM" = "1" ]; then
    warn "CREATE_HA_VM=1: criando Home Assistant neste host por solicitacao explicita."
    create_ha_vm
else
    log "Home Assistant omitido: previsto para maquina externa (CREATE_HA_VM=0)"
fi
create_security_vm

echo ""
echo "VM planejada no HP EliteDesk:"
echo "  VM${SEC_VM_ID} ${SEC_NAME}      10.0.1.30 sugerido"
echo "  Home Assistant + backup dedicado: segunda maquina"
echo ""
echo "Configurar IPs estaticos/DHCP reservations no OPNsense."
