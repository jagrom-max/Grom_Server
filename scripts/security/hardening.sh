#!/bin/bash
# =============================================================================
# GROM SERVER - Hardening de Segurança
# Executar em CADA container LXC (CT110-CT114)
# TOTALMENTE AUTOMATIZADO
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

log() { echo -e "\033[0;32m[✓]\033[0m $1"; }
info() { echo -e "\033[0;34m[i]\033[0m $1"; }

HOSTNAME=$(hostname)
ALERT_EMAIL="${GROM_ALERT_EMAIL:-grom.servidor@gmail.com}"
echo "============================================"
echo "  GROM SERVER - Hardening: ${HOSTNAME}"
echo "============================================"

# 1. Criar usuário admin (desabilitar root SSH)
info "Criando usuário gromadmin..."
if ! id gromadmin &>/dev/null; then
    useradd -m -s /bin/bash -G sudo gromadmin
    echo "gromadmin:$(openssl rand -base64 24)" | chpasswd
    mkdir -p /home/gromadmin/.ssh
    cp /root/.ssh/authorized_keys /home/gromadmin/.ssh/ 2>/dev/null || true
    chown -R gromadmin:gromadmin /home/gromadmin/.ssh
    chmod 700 /home/gromadmin/.ssh
    chmod 600 /home/gromadmin/.ssh/authorized_keys 2>/dev/null || true
fi
log "Usuário gromadmin criado"

# 2. Hardening SSH
info "Aplicando hardening SSH..."
cat > /etc/ssh/sshd_config.d/99-grom-hardening.conf << 'SSHEOF'
# GROM SERVER - SSH Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
MaxSessions 3
LoginGraceTime 30
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
Protocol 2
AllowUsers gromadmin
SSHEOF
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
log "SSH hardened"

# 3. Fail2Ban
info "Configurando Fail2Ban..."
apt-get install -y -qq fail2ban
cat > /etc/fail2ban/jail.local << 'F2BEOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
banaction = ufw
backend = systemd
ignoreip = 10.0.1.0/24 10.0.10.0/24 127.0.0.1/8

[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 3600
F2BEOF

# Adicionar jails extras dependendo do serviço
if command -v nginx &>/dev/null; then
    cat >> /etc/fail2ban/jail.local << 'F2BNGINX'

[nginx-http-auth]
enabled = true
port = http,https
maxretry = 5
bantime = 1800

[nginx-limit-req]
enabled = true
port = http,https
maxretry = 10
bantime = 600
logpath = /var/log/nginx/error.log
F2BNGINX
fi

if command -v mysql &>/dev/null; then
    cat >> /etc/fail2ban/jail.local << 'F2BMYSQL'

[mysqld-auth]
enabled = true
port = 3306
maxretry = 5
bantime = 3600
logpath = /var/log/mysql/error.log
F2BMYSQL
fi

systemctl enable fail2ban
systemctl restart fail2ban
log "Fail2Ban configurado"

# 4. CrowdSec (opcional)
if [ "${INSTALL_CROWDSEC:-0}" = "1" ]; then
    info "Instalando CrowdSec via repositorio previamente configurado..."
    apt-get install -y -qq crowdsec crowdsec-firewall-bouncer-iptables 2>/dev/null || {
        echo "CrowdSec nao instalado. Configure o repositorio oficial manualmente e execute novamente." >&2
    }
else
    info "CrowdSec pulado por padrao. Ative com INSTALL_CROWDSEC=1 apos configurar repositorio oficial."
fi

# 5. Atualizações automáticas de segurança
info "Configurando atualizações automáticas..."
apt-get install -y -qq unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UUEOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "__GROM_ALERT_EMAIL__";
Unattended-Upgrade::MailReport "on-change";
UUEOF
sed -i "s/__GROM_ALERT_EMAIL__/${ALERT_EMAIL//\//\\/}/g" /etc/apt/apt.conf.d/50unattended-upgrades

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'AUTOEOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
AUTOEOF
log "Atualizações automáticas de segurança configuradas"

# 6. Hardening do kernel
info "Aplicando hardening do kernel..."
cat > /etc/sysctl.d/99-grom-security.conf << 'SYSEOF'
# GROM SERVER - Kernel Security
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
SYSEOF
sysctl --system >/dev/null 2>&1 || true
log "Kernel hardened"

# 7. Logrotate otimizado
cat > /etc/logrotate.d/grom-server << 'LREOF'
/var/log/grom-*/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
}
LREOF
log "Logrotate configurado"

# 8. Audit de permissões
info "Verificando permissões..."
chmod 700 /root
chmod 600 /etc/shadow
chmod 644 /etc/passwd
log "Permissões verificadas"

echo ""
echo "============================================"
echo "  ✅ Hardening aplicado em: ${HOSTNAME}"
echo ""
echo "  SSH: Apenas chave pública, sem root"
echo "  Fail2Ban: Ativo (ban 1h após 3 tentativas)"
echo "  CrowdSec: Opcional (INSTALL_CROWDSEC=1)"
echo "  Updates: Automáticos para segurança"
echo "  Kernel: Hardened"
echo "============================================"
