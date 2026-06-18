# 💾 Estratégia de Backup

## Ferramentas

| Ferramenta | Função |
|---|---|
| **BorgBackup** | Backup incremental, deduplificado, criptografado |
| **mysqldump** | Backup lógico do MySQL |
| **vzdump** | Backup de VM/containers no Proxmox |
| **rsync** | Sincronização com HD externo |
| **rclone crypt** | Cópia externa criptografada opcional para Google Drive |
| **cron** | Agendamento de tarefas |

## Container LXC: CT112 - Backup Server

| Parâmetro | Valor |
|---|---|
| **ID** | 112 |
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

## Separacao com segundo HD externo opcional

Se houver um segundo HD de 1 TB, usar como complemento, sem substituir o HD principal.

| Midia | Montagem | Papel recomendado |
|---|---|---|
| SSD interno | Proxmox/local-lvm | Sistema, VMs/CTs, dados recentes e cache operacional |
| HD externo A | `/mnt/backup-external` -> CT112 `/mnt/external` | Backup operacional diario, Proxmox `vzdump`, Borg e dumps |
| HD externo B opcional | `/mnt/backup-external-2` -> CT112 `/mnt/external2` | Segunda copia local, rotacao offline e evidencias importantes |
| Google Drive/rclone crypt | remoto criptografado | Copia externa opcional, nunca backup principal |

Politica recomendada:
- HD A pode ficar conectado para backups automaticos.
- HD B deve ficar desconectado/offline sempre que possivel, conectado apenas para sincronizacao, teste de restore ou guarda de evidencia.
- Se ambos forem de 1 TB, nao usar nenhum deles para gravacao continua de video.
- Evidencias importantes devem ir para HD B e copia externa criptografada, quando aplicavel.
- Nenhum HD externo deve armazenar dados sensiveis sem criptografia Borg/rclone crypt ou protecao fisica controlada.

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
# No Proxmox, editar /etc/pve/lxc/112.conf:
# mp0: /mnt/backup-external,mp=/mnt/external
```

## Montagem do segundo HD opcional

```bash
mkdir -p /mnt/backup-external-2
lsblk
mount /dev/sdY1 /mnt/backup-external-2

# Usar nofail para nao bloquear boot se o HD B estiver offline.
echo "UUID=<UUID_HD_B> /mnt/backup-external-2 ext4 defaults,nofail 0 2" >> /etc/fstab

# Bind mount opcional no CT112:
# mp1: /mnt/backup-external-2,mp=/mnt/external2
```

---

## Agenda de Backups

| Tipo | Frequência | Retenção | Script |
|---|---|---|---|
| DB dump | 6h | 7 dias | `backup-databases.sh` |
| Fontes montadas opcionais | Diário 02:00 | 30 dias | `backup-files.sh` |
| Configs sistema | Diário 02:30 | 30 dias | `scripts/proxmox/backup-containers.sh` |
| Sync HD externo | Diário 04:00 | Espelho | rsync |
| Sync segundo HD opcional | Diário 04:30 | Espelho/rotacao | rsync se `/mnt/external2` existir |
| Proxmox VM/LXC backup | Diário 02:30 | 30 dias | `scripts/proxmox/backup-containers.sh` |
| Sync externo criptografado | Diário 05:30 | Conforme Drive | `sync-google-drive.sh` |

> O backup de arquivos dos containers nao usa SSH root. Arquivos e configuracoes dos containers sao protegidos pelo `vzdump` no Proxmox host. O CT112 fica responsavel por dumps logicos de banco e backups Borg.
> Google Drive, se usado, recebe apenas dados criptografados via `rclone crypt`.

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
