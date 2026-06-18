#!/bin/bash
# =============================================================================
# GROM SERVER - Relatorio operacional mensal
# Executar no Proxmox host. Nao imprime segredos.
# =============================================================================

set -euo pipefail

ENV_FILE="${GROM_ENV_FILE:-/etc/grom/grom.env}"
REPORT_DIR="${GROM_REPORT_DIR:-/var/log/grom-reports}"
SEND_EMAIL="${GROM_SEND_REPORT_EMAIL:-1}"
PUBLIC_TARGET="${GROM_PUBLIC_TARGET:-}"
MONTH_TAG="$(date '+%Y-%m')"
REPORT_FILE="${REPORT_DIR}/grom-operational-report-${MONTH_TAG}.txt"

if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    . "$ENV_FILE"
fi

ALERT_EMAIL="${GROM_ALERT_EMAIL:-grom.servidor@gmail.com}"
DOMAIN="${GROM_DOMAIN:-grom.seg.br}"

mkdir -p "$REPORT_DIR"

section() {
    echo ""
    echo "== $1 =="
}

run_or_warn() {
    local label="$1"
    shift

    echo "-- ${label}"
    if "$@" 2>&1; then
        true
    else
        echo "[AVISO] Falha ao executar: $label"
    fi
    echo ""
}

ct_cmd() {
    local ctid="$1"
    shift

    if command -v pct >/dev/null 2>&1 && pct status "$ctid" 2>/dev/null | grep -q "status: running"; then
        pct exec "$ctid" -- "$@" 2>&1 || true
    else
        echo "[AVISO] CT${ctid} indisponivel"
    fi
}

latest_path() {
    local path="$1"
    local label="$2"

    echo "-- ${label}"
    if [ -e "$path" ]; then
        find "$path" -maxdepth 3 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -10 || true
    else
        echo "[AVISO] Caminho ausente: ${path}"
    fi
    echo ""
}

{
    echo "GROM SERVER - Relatorio operacional mensal"
    echo "Data: $(date -Is)"
    echo "Host: $(hostname -f 2>/dev/null || hostname)"
    echo "Dominio: ${DOMAIN}"
    echo "Contato operacional: ${ALERT_EMAIL}"

    section "Resumo executivo"
    echo "- Revisar falhas/avisos abaixo."
    echo "- Confirmar se backup e restore de amostra foram testados."
    echo "- Confirmar se portas administrativas continuam fechadas externamente."
    echo "- Confirmar usuarios ativos, peers WireGuard e regras WAN do OPNsense."

    section "Host Proxmox"
    run_or_warn "Versao Proxmox" pveversion
    run_or_warn "Uptime" uptime
    run_or_warn "Uso de disco" df -h
    run_or_warn "Memoria" free -h
    run_or_warn "Carga de CPU" bash -c "cat /proc/loadavg"
    if command -v sensors >/dev/null 2>&1; then
        run_or_warn "Temperaturas" sensors
    else
        echo "[AVISO] sensors ausente"
    fi

    section "VM e containers"
    run_or_warn "VMs" qm list
    run_or_warn "Containers" pct list
    run_or_warn "Status OPNsense VM100" qm status 100
    if qm status 120 >/dev/null 2>&1; then
        run_or_warn "Status Home Assistant VM120" qm status 120
    else
        echo "[AVISO] VM120 Home Assistant ainda nao criada"
    fi
    if qm status 130 >/dev/null 2>&1; then
        run_or_warn "Status Grom_Security VM130" qm status 130
    else
        echo "[AVISO] VM130 Grom_Security ainda nao criada"
    fi
    for ctid in 110 111 112 113 114; do
        run_or_warn "Status CT${ctid}" pct status "$ctid"
    done

    section "Servicos principais"
    echo "-- CT110 Web"
    ct_cmd 110 systemctl --no-pager --full status nginx php8.3-fpm | sed -n '1,80p'
    echo ""
    echo "-- CT111 Database"
    ct_cmd 111 systemctl --no-pager --full status mysql | sed -n '1,80p'
    echo ""
    echo "-- CT113 Monitoring"
    ct_cmd 113 systemctl --no-pager --full status netdata | sed -n '1,80p'
    echo ""
    echo "-- CT114 VPN"
    ct_cmd 114 systemctl --no-pager --full status wg-quick@wg0 | sed -n '1,80p'

    section "Backups"
    latest_path "/mnt/backup-external" "Ultimos arquivos no HD externo"
    latest_path "/mnt/backup-external-2" "Ultimos arquivos no segundo HD externo opcional"
    echo "-- CT112 repositorios/diretorios de backup"
    ct_cmd 112 bash -c "df -h /mnt/backup /mnt/external /mnt/external2 2>/dev/null; find /mnt/backup -maxdepth 3 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -20"
    echo ""
    echo "-- Cron backup host"
    [ -f /etc/cron.d/grom-proxmox-backup ] && cat /etc/cron.d/grom-proxmox-backup || echo "[AVISO] /etc/cron.d/grom-proxmox-backup ausente"
    echo ""
    echo "-- Cron backup CT112"
    ct_cmd 112 bash -c "[ -f /etc/cron.d/grom-backup ] && cat /etc/cron.d/grom-backup || echo '[AVISO] /etc/cron.d/grom-backup ausente'"

    section "Logs recentes"
    run_or_warn "Deploy log recente" bash -c "tail -80 /var/log/grom-deploy.log 2>/dev/null || true"
    run_or_warn "Validacao pos-deploy recente" bash -c "tail -80 /var/log/grom-post-deploy-validation.log 2>/dev/null || true"
    run_or_warn "Backups Proxmox recentes" bash -c "tail -80 /var/log/grom-proxmox-backup.log 2>/dev/null || true"
    echo "-- CT112 logs de backup"
    ct_cmd 112 bash -c "tail -80 /var/log/grom-backup/*.log 2>/dev/null || true"

    section "Seguranca"
    echo "-- Regras/listeners no host"
    ss -tulpen 2>/dev/null || netstat -tulpen 2>/dev/null || true
    echo ""
    echo "-- Fail2Ban por container"
    for ctid in 110 111 112 113 114; do
        echo "CT${ctid}:"
        ct_cmd "$ctid" bash -c "fail2ban-client status 2>/dev/null || echo '[AVISO] Fail2Ban sem status'"
        echo ""
    done

    section "Validacao automatica"
    if [ -x /usr/local/sbin/grom-post-deploy-validation.sh ]; then
        if [ -n "$PUBLIC_TARGET" ]; then
            /usr/local/sbin/grom-post-deploy-validation.sh --public-target="$PUBLIC_TARGET" || true
        else
            /usr/local/sbin/grom-post-deploy-validation.sh || true
        fi
    elif [ -f /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh ]; then
        if [ -n "$PUBLIC_TARGET" ]; then
            bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh --public-target="$PUBLIC_TARGET" || true
        else
            bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh || true
        fi
    else
        echo "[AVISO] Validador pos-deploy nao encontrado"
    fi

    section "Checklist humano mensal"
    echo "[ ] Teste de restore de amostra executado"
    echo "[ ] Usuarios das aplicacoes revisados"
    echo "[ ] Peers WireGuard revisados"
    echo "[ ] Regras WAN do OPNsense revisadas"
    echo "[ ] Portas administrativas testadas de fora da rede"
    echo "[ ] Espaco em SSD/HD externo A/HD externo B conferido"
    echo "[ ] Necessidade de nobreak/segundo HD/switch gerenciavel reavaliada"

    echo ""
    echo "Fim: $(date -Is)"
} > "$REPORT_FILE"

cat "$REPORT_FILE"

if [ "$SEND_EMAIL" = "1" ] && command -v mail >/dev/null 2>&1; then
    mail -s "GROM SERVER - relatorio operacional ${MONTH_TAG}" "$ALERT_EMAIL" < "$REPORT_FILE" 2>/dev/null || true
fi

exit 0
