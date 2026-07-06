# 🔧 Procedimentos de Manutenção

## Filosofia: Simples, Confiável, Documentado

Toda manutenção segue o princípio: **se não está documentado, não existe**.
Cada procedimento deve ser simples o suficiente para ser executado sob pressão.

---

## Manutenção Diária (Automática)

Executado automaticamente via cron, verificar apenas se houve alertas.

| Tarefa | Horário | Script |
|---|---|---|
| Backup databases | 00:00, 06:00, 12:00, 18:00 | `backup-databases.sh` |
| Backup fontes montadas opcionais | 02:00 | `backup-files.sh` |
| Backup VM/LXC Proxmox | 02:30 | `backup-containers.sh` no Proxmox host |
| Sync HD externo | 04:00 | rsync automático |
| Sync Google Drive criptografado | 05:30 | `sync-google-drive.sh`, se rclone crypt estiver configurado |
| Health check operacional | A cada 15 min | `grom-operational-health-check.sh` no Proxmox host |
| Verificação de saúde | 06:30 | health-check via Netdata |
| Rotação de logs | Automático | logrotate |

---

## Manutenção Semanal (5-10 min)

**Quando**: Domingo pela manhã

### Checklist Semanal
```bash
# 1. Verificar status dos containers
pct list               # No Proxmox host

# 2. Verificar espaço em disco
df -h                   # Em cada container

# 3. Verificar logs de segurança
fail2ban-client status  # Resumo de bans

# 4. Verificar backups da semana
borg list /mnt/backup/databases | tail -7
ls -lh /mnt/backup-external/proxmox | tail

# 5. Verificar atualizações
apt list --upgradable   # Em cada container

# 6. Verificar uptime dos serviços
# → Acessar Uptime Kuma: http://10.0.1.13:3001
```

---

## Manutenção Mensal (~30 min)

**Quando**: Primeiro domingo do mês

O servidor gera automaticamente um relatorio operacional mensal em:

```bash
/var/log/grom-reports/
```

Execucao manual:

```bash
/usr/local/sbin/grom-monthly-operational-report.sh
```

### Checklist Mensal
```bash
# 1. Atualizar todos os containers
apt update && apt upgrade -y

# 2. Atualizar OPNsense
# → WebGUI: System > Firmware > Check for Updates

# 3. Otimizar MySQL
mysqlcheck --optimize --all-databases -u root -p

# 4. Verificar integridade dos backups
borg check /mnt/backup/databases
borg check /mnt/backup/webfiles

# 5. Testar restauração de backup (em ambiente de teste)
# → Restaurar último backup em diretório temporário

# 6. Renovar certificados SSL (automático, mas verificar)
certbot renew --dry-run

# 7. Verificar saúde do SSD
smartctl -a /dev/nvme0n1  # No Proxmox host

# 8. Limpar logs antigos e cache
journalctl --vacuum-time=30d
apt autoremove -y
apt autoclean

# 9. Revisar regras de firewall OPNsense
# → Verificar se há regras obsoletas

# 10. Verificar senhas expiradas ou fracas
# → Rotação de senhas se necessário
```

---

## Manutenção Trimestral (~1 hora)

### Checklist Trimestral
- [ ] Teste completo de disaster recovery
- [ ] Auditoria de segurança (portas abertas, serviços)
- [ ] Revisão de políticas de backup
- [ ] Verificação de performance (benchmarks)
- [ ] Atualização de documentação
- [ ] Revisão de capacidade (disco, RAM, CPU)
- [ ] Atualizar Proxmox VE (se versão nova disponível)
- [ ] Rotação de senhas administrativas

---

## Procedimentos de Emergência

### Container não inicia
```bash
# No Proxmox host
pct status <CTID>
pct start <CTID> --debug
journalctl -u pve-container@<CTID> -n 50
```

### MySQL não responde
```bash
systemctl status mysql
journalctl -u mysql -n 50
# Se corrompido:
mysqlcheck --repair --all-databases
```

### Nginx retorna erro 502
```bash
# Verificar PHP-FPM
systemctl status php8.3-fpm
# Verificar Gunicorn (Python)
systemctl status grom-documental
# Verificar logs
tail -50 /var/log/nginx/error.log
```

### Servidor inacessível remotamente
1. Verificar VPN WireGuard local
2. Verificar se OPNsense está rodando: `qm status 100` (Proxmox host)
3. Verificar se internet está operando
4. Último recurso: acesso físico ao HP EliteDesk

### Disco cheio
```bash
# Identificar o problema
du -sh /* | sort -rh | head -20
# Limpar logs
journalctl --vacuum-size=100M
# Limpar cache apt
apt clean
# Verificar backups antigos
borg prune --keep-daily=7 --keep-weekly=4 /mnt/backup/databases
```

---

## Script de Health Check

Executar no Proxmox host:

```bash
/usr/local/sbin/grom-operational-health-check.sh
```

Ou, antes da instalacao em `/usr/local/sbin`:

```bash
bash /root/grom-scripts/scripts/proxmox/operational-health-check.sh
```

Ele verifica:
- Status de todos os containers
- Uso de CPU/RAM/Disco
- Status dos serviços principais
- Último backup realizado
- Backup VM/LXC recente
- Portas administrativas publicas, quando `--public-target` for informado
