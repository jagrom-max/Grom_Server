#!/bin/bash
# =============================================================================
# GROM SERVER - Setup Backup Server
# Executar DENTRO do container CT112 (grom-backup)
# TOTALMENTE AUTOMATIZADO - Configura tudo + agenda cron
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
: "${BORG_PASSPHRASE:?Defina BORG_PASSPHRASE antes de executar}"
: "${GROM_BACKUP_PASS:?Defina GROM_BACKUP_PASS antes de executar}"
umask 077

log() { echo -e "\033[0;32m[✓]\033[0m $1"; }
info() { echo -e "\033[0;34m[i]\033[0m $1"; }

echo "============================================"
echo "  GROM SERVER - Setup Backup Server"
echo "============================================"

# 1. Instalar ferramentas
info "Instalando ferramentas de backup..."
apt-get update -qq
apt-get install -y -qq borgbackup rsync mysql-client mailutils rclone
log "Ferramentas instaladas"

# 2. Criar estrutura de diretórios
info "Criando estrutura de backup..."
mkdir -p /mnt/backup/{borg-databases,borg-webfiles,borg-configs,staging,dumps}
mkdir -p /var/log/grom-backup
log "Diretórios criados"

# 3. Inicializar repositórios BorgBackup
info "Inicializando repositórios BorgBackup..."
export BORG_PASSPHRASE

for REPO in borg-databases borg-webfiles borg-configs; do
    if [ ! -d "/mnt/backup/${REPO}/data" ]; then
        borg init --encryption=repokey "/mnt/backup/${REPO}"
        log "Repositório ${REPO} inicializado"
    fi
done

# Salvar variaveis de backup em arquivo restrito para uso pelo cron.
{
    printf 'BORG_PASSPHRASE=%q\n' "$BORG_PASSPHRASE"
    printf 'GROM_BACKUP_PASS=%q\n' "$GROM_BACKUP_PASS"
    printf 'GROM_ALERT_EMAIL=%q\n' "${GROM_ALERT_EMAIL:-grom.servidor@gmail.com}"
    printf 'GROM_RCLONE_REMOTE=%q\n' "${GROM_RCLONE_REMOTE:-gromdrive_crypt:grom-server-backups}"
    printf 'GROM_RCLONE_SOURCE=%q\n' "${GROM_RCLONE_SOURCE:-/mnt/backup}"
} > /root/.grom_backup_env
chmod 600 /root/.grom_backup_env
log "Variaveis de backup salvas em /root/.grom_backup_env"

# Exportar chaves
mkdir -p /root/borg-keys
for REPO in borg-databases borg-webfiles borg-configs; do
    borg key export "/mnt/backup/${REPO}" "/root/borg-keys/${REPO}.key"
done
log "Chaves exportadas em /root/borg-keys/"

# 4. Copiar scripts de backup
info "Instalando scripts de backup..."
# Os scripts auxiliares devem estar em /tmp/ antes deste setup.
cp /tmp/backup-databases.sh /usr/local/bin/ 2>/dev/null || true
cp /tmp/backup-files.sh /usr/local/bin/ 2>/dev/null || true
cp /tmp/sync-google-drive.sh /usr/local/bin/ 2>/dev/null || true
chmod +x /usr/local/bin/backup-*.sh 2>/dev/null || true
chmod +x /usr/local/bin/sync-google-drive.sh 2>/dev/null || true

# 5. Configurar CRON - TOTALMENTE AUTOMATIZADO
info "Configurando agenda automática..."
cat > /etc/cron.d/grom-backup << 'CRONEOF'
# =============================================================================
# GROM SERVER - Agenda de Backup Automático
# =============================================================================
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=""

# Carregar segredos do backup

# Backup databases: a cada 6 horas
0 0,6,12,18 * * * root . /root/.grom_backup_env && /usr/local/bin/backup-databases.sh

# Backup de fontes montadas, se existirem: diário às 02:00
# Backups completos dos containers rodam no Proxmox host via backup-containers.sh.
0 2 * * * root . /root/.grom_backup_env && /usr/local/bin/backup-files.sh

# Sync HD externo: diário às 04:00
0 4 * * * root rsync -a /mnt/backup/ /mnt/external/ --exclude='staging/' 2>/dev/null

# Sync segundo HD externo opcional: diario as 04:30
30 4 * * * root if [ -d /mnt/external2 ]; then rsync -a /mnt/backup/ /mnt/external2/ --exclude='staging/' 2>/dev/null; fi

# Verificação de integridade: domingo às 05:00
0 5 * * 0 root . /root/.grom_backup_env && borg check /mnt/backup/borg-databases && borg check /mnt/backup/borg-webfiles

# Sync externo criptografado opcional via rclone crypt: diario as 05:30
30 5 * * * root . /root/.grom_backup_env && /usr/local/bin/sync-google-drive.sh

# Limpeza de logs: mensal
0 3 1 * * root find /var/log/grom-backup/ -name "*.log" -mtime +90 -delete

# =============================================================================
CRONEOF
log "Cron configurado - backup 100% automático"

# 6. Logrotate
cat > /etc/logrotate.d/grom-backup << 'LOGEOF'
/var/log/grom-backup/*.log {
    weekly
    missingok
    rotate 12
    compress
    delaycompress
    notifempty
}
LOGEOF
log "Logrotate configurado"

# 7. Firewall
apt-get install -y -qq ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow from 10.0.1.0/24 to any port 22
echo "y" | ufw enable
log "Firewall configurado"

echo ""
echo "============================================"
echo "  ✅ Backup Server configurado!"
echo "  Agenda 100% automática via cron"
echo "  Repositórios BorgBackup inicializados"
echo ""
echo "  ⚠️ GUARDAR EM LOCAL SEGURO:"
echo "  - /root/.grom_backup_env"
echo "  - /root/borg-keys/"
echo "============================================"
