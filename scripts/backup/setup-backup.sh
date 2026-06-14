#!/bin/bash
# =============================================================================
# GROM SERVER - Setup Backup Server
# Executar DENTRO do container CT102 (grom-backup)
# TOTALMENTE AUTOMATIZADO - Configura tudo + agenda cron
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

log() { echo -e "\033[0;32m[✓]\033[0m $1"; }
info() { echo -e "\033[0;34m[i]\033[0m $1"; }

echo "============================================"
echo "  GROM SERVER - Setup Backup Server"
echo "============================================"

# 1. Instalar ferramentas
info "Instalando ferramentas de backup..."
apt-get update -qq
apt-get install -y -qq borgbackup rsync mysql-client openssh-client mailutils
log "Ferramentas instaladas"

# 2. Criar estrutura de diretórios
info "Criando estrutura de backup..."
mkdir -p /mnt/backup/{borg-databases,borg-webfiles,borg-configs,staging,dumps}
mkdir -p /var/log/grom-backup
log "Diretórios criados"

# 3. Inicializar repositórios BorgBackup
info "Inicializando repositórios BorgBackup..."
export BORG_PASSPHRASE="${BORG_PASSPHRASE:-grom_borg_$(openssl rand -hex 8)}"

for REPO in borg-databases borg-webfiles borg-configs; do
    if [ ! -d "/mnt/backup/${REPO}/data" ]; then
        borg init --encryption=repokey "/mnt/backup/${REPO}"
        log "Repositório ${REPO} inicializado"
    fi
done

# Salvar passphrase
echo "BORG_PASSPHRASE=${BORG_PASSPHRASE}" > /root/.borg_passphrase
chmod 600 /root/.borg_passphrase
log "Passphrase salva em /root/.borg_passphrase"

# Exportar chaves
mkdir -p /root/borg-keys
for REPO in borg-databases borg-webfiles borg-configs; do
    borg key export "/mnt/backup/${REPO}" "/root/borg-keys/${REPO}.key"
done
log "Chaves exportadas em /root/borg-keys/"

# 4. Gerar chave SSH para acesso aos outros containers
info "Configurando SSH..."
if [ ! -f /root/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -C "grom-backup"
    log "Chave SSH gerada"
    echo ""
    echo "  ⚠️ Copiar chave pública para os containers:"
    echo "  $(cat /root/.ssh/id_ed25519.pub)"
    echo ""
fi

# 5. Copiar scripts de backup
info "Instalando scripts de backup..."
# Os scripts backup-databases.sh e backup-files.sh devem estar em /usr/local/bin/
cp /tmp/backup-databases.sh /usr/local/bin/ 2>/dev/null || true
cp /tmp/backup-files.sh /usr/local/bin/ 2>/dev/null || true
chmod +x /usr/local/bin/backup-*.sh 2>/dev/null || true

# 6. Configurar CRON - TOTALMENTE AUTOMATIZADO
info "Configurando agenda automática..."
cat > /etc/cron.d/grom-backup << 'CRONEOF'
# =============================================================================
# GROM SERVER - Agenda de Backup Automático
# =============================================================================
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=""

# Carregar passphrase do BorgBackup
BORG_PASSPHRASE_FILE=/root/.borg_passphrase

# Backup databases: a cada 6 horas
0 0,6,12,18 * * * root . /root/.borg_passphrase && /usr/local/bin/backup-databases.sh

# Backup arquivos web: diário às 02:00
0 2 * * * root . /root/.borg_passphrase && /usr/local/bin/backup-files.sh

# Sync HD externo: diário às 04:00
0 4 * * * root rsync -a /mnt/backup/ /mnt/external/ --exclude='staging/' 2>/dev/null

# Verificação de integridade: domingo às 05:00
0 5 * * 0 root . /root/.borg_passphrase && borg check /mnt/backup/borg-databases && borg check /mnt/backup/borg-webfiles

# Limpeza de logs: mensal
0 3 1 * * root find /var/log/grom-backup/ -name "*.log" -mtime +90 -delete

# =============================================================================
CRONEOF
log "Cron configurado - backup 100% automático"

# 7. Logrotate
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

# 8. Firewall
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
echo "  - /root/.borg_passphrase"
echo "  - /root/borg-keys/"
echo "============================================"
