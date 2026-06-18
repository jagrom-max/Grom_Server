# 🔒 Hardening de Segurança

## Princípios

1. **Defesa em profundidade** - Múltiplas camadas de segurança
2. **Menor privilégio** - Cada serviço tem apenas as permissões necessárias
3. **Fail-safe** - Em caso de falha, o sistema nega acesso
4. **Simplicidade** - Quanto menos complexo, mais fácil de manter e auditar

---

## Camadas de Segurança

```
Camada 1: Rede         → OPNsense Firewall + IDS/IPS (Suricata)
Camada 2: DNS          → DNS over TLS + DNSSEC + Bloqueio de domínios maliciosos
Camada 3: Transporte   → SSL/TLS em todos os serviços + WireGuard VPN
Camada 4: Aplicação    → Fail2Ban + CrowdSec opcional + Rate Limiting + WAF headers
Camada 5: Autenticação → SSH por chave + 2FA no Proxmox/OPNsense + senhas fortes
Camada 6: Dados        → Backups criptografados + MySQL com TLS + permissões restritas
Camada 7: Monitoramento→ Netdata + Uptime Kuma + Logs centralizados + Alertas
```

---

## 1. SSH Hardening (Todos os containers)

Editar `/etc/ssh/sshd_config`:

```bash
# Desabilitar login root
PermitRootLogin no

# Apenas autenticação por chave
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Limitar tentativas
MaxAuthTries 3
MaxSessions 3
LoginGraceTime 30

# Desabilitar recursos desnecessários
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no

# Timeout de sessão
ClientAliveInterval 300
ClientAliveCountMax 2

# Protocolo e cifras seguras
Protocol 2
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

# Permitir apenas usuário admin
AllowUsers gromadmin
```

Após editar: `systemctl restart sshd`

---

## 2. Fail2Ban (Todos os containers)

```bash
apt install fail2ban -y
systemctl enable fail2ban
```

### Config: `/etc/fail2ban/jail.local`
Ver arquivo: `configs/fail2ban/jail.local`

Principais jails:
- **sshd**: 3 tentativas → ban 1 hora
- **nginx-http-auth**: 5 tentativas → ban 30min
- **nginx-limit-req**: Rate limiting
- **mysql-auth**: 5 tentativas → ban 1 hora

---

## 3. CrowdSec (Proteção Colaborativa Opcional)

```bash
# Configurar o repositório oficial conforme documentação do CrowdSec.
# Depois executar explicitamente:
INSTALL_CROWDSEC=1 bash scripts/security/hardening.sh
```

CrowdSec pode ser útil, mas não deve ser instalado via `curl | bash` no baseline. Para este projeto, Fail2Ban + OPNsense/Suricata são obrigatórios; CrowdSec é uma camada adicional controlada.

---

## 4. Atualizações Automáticas de Segurança

```bash
apt install unattended-upgrades -y
dpkg-reconfigure -plow unattended-upgrades
```

Editar `/etc/apt/apt.conf.d/50unattended-upgrades`:
```
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Mail "grom.servidor@gmail.com";
Unattended-Upgrade::MailReport "on-change";
```

---

## 5. Firewall Local (UFW) - Cada Container

### Web Server (10.0.1.10)
```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow from 10.0.1.0/24 to any port 22    # SSH interno
ufw allow 80/tcp                                # HTTP
ufw allow 443/tcp                               # HTTPS
ufw enable
```

### MySQL (10.0.1.11)
```bash
ufw default deny incoming
ufw allow from 10.0.1.10 to any port 3306     # Web server
ufw allow from 10.0.1.12 to any port 3306     # Backup
ufw allow from 10.0.1.0/24 to any port 22     # SSH
ufw enable
```

---

## 6. Nginx - Headers de Segurança

Ver arquivo: `configs/nginx/security-headers.conf`

```nginx
# Prevenir clickjacking
add_header X-Frame-Options "SAMEORIGIN" always;
# Prevenir MIME sniffing
add_header X-Content-Type-Options "nosniff" always;
# XSS Protection
add_header X-XSS-Protection "1; mode=block" always;
# Referrer Policy
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
# Content Security Policy
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline';" always;
# HSTS
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
# Permissions Policy
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
```

---

## 7. Checklist de Auditoria Mensal

- [ ] Verificar logs de Fail2Ban
- [ ] Verificar logs de CrowdSec, se instalado
- [ ] Verificar IPs banidos
- [ ] Testar backups (restauração)
- [ ] Verificar certificados SSL (validade)
- [ ] Revisar regras de firewall
- [ ] Verificar atualizações pendentes
- [ ] Verificar uso de disco e RAM
- [ ] Revisar logs de acesso do Nginx
- [ ] Verificar slow queries MySQL
- [ ] Testar conexão VPN

---

## 8. Senhas e Credenciais

> ⚠️ NUNCA armazene senhas em texto puro no repositório!

### Gerenciamento de Senhas:
- Usar **KeePassXC** (open source) para gerenciar todas as senhas
- Arquivo .kdbx guardado em local seguro, NÃO no repositório
- Senhas mínimas: 20 caracteres, alfanumérico + especiais
- Cada serviço com senha ÚNICA

### Serviços que necessitam senha forte:
1. Proxmox root
2. OPNsense admin
3. MySQL root + usuários de aplicação
4. SSH keys (com passphrase)
5. WireGuard keys
6. BorgBackup encryption key
7. Certificados SSL
