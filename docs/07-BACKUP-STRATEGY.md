# 💾 Estratégia de Backup

## Ferramentas

| Ferramenta | Função |
|---|---|
| **BorgBackup** | Backup incremental, deduplificado, criptografado |
| **mysqldump** | Backup lógico do MySQL |
| **rsync** | Sincronização com HD externo |
| **cron** | Agendamento de tarefas |

## Container LXC: CT102 - Backup Server

| Parâmetro | Valor |
|---|---|
| **ID** | 102 |
| **Hostname** | grom-backup |
| **SO** | Ubuntu 24.04 LTS |
| **RAM** | 1GB |
| **vCPU** | 1 |
| **Disco** | 50GB |
| **IP** | 10.0.1.12/24 |

---

## Estratégia 3-2-1

- **3** cópias dos dados (produção + backup local + HD externo)
- **2** mídias diferentes (SSD + HD externo USB)
- **1** cópia offsite (HD externo rotacionável)

---

## Montagem do HD Externo

```bash
# No Proxmox host, montar o HD externo
mkdir -p /mnt/backup-external
# Identificar o dispositivo
lsblk
# Montar (ajustar /dev/sdX)
mount /dev/sdX1 /mnt/backup-external

# Adicionar ao fstab para montagem automática
echo "UUID=<UUID> /mnt/backup-external ext4 defaults,nofail 0 2" >> /etc/fstab

# Passar o mount point para o container de backup via bind mount
# No Proxmox, editar /etc/pve/lxc/102.conf:
# mp0: /mnt/backup-external,mp=/mnt/external
```

---

## Agenda de Backups

| Tipo | Frequência | Retenção | Script |
|---|---|---|---|
| DB dump | 6h | 7 dias | `backup-databases.sh` |
| Arquivos web | Diário 02:00 | 30 dias | `backup-files.sh` |
| Configs sistema | Semanal dom 03:00 | 90 dias | `backup-files.sh` |
| Sync HD externo | Diário 04:00 | Espelho | rsync |
| Proxmox snapshots | Semanal dom 05:00 | 4 últimos | Proxmox |

---

## BorgBackup - Repositórios

```bash
# Inicializar repositórios
borg init --encryption=repokey /mnt/backup/databases
borg init --encryption=repokey /mnt/backup/webfiles
borg init --encryption=repokey /mnt/backup/configs

# IMPORTANTE: Guardar a chave de criptografia em local seguro!
borg key export /mnt/backup/databases > /root/borg-key-databases.txt
```

---

## Verificação de Backups

```bash
# Listar backups
borg list /mnt/backup/databases

# Verificar integridade
borg check /mnt/backup/databases

# Testar restauração
borg extract --dry-run /mnt/backup/databases::latest
```

---

## Alertas

- Email em caso de falha de backup
- Monitoramento do espaço em disco
- Alerta se backup não executar no horário
