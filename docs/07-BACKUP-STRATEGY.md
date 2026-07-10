# Estrategia de Backup do HP Core

Este documento descreve a politica de backup do `hp-core` no `Grom_Server`.

O detalhamento operacional da segunda maquina `home-ops`, incluindo storage
proprio, replica recebida, restore drill local e automacao do host remoto,
pertence ao projeto `HA_Back`.

## Ferramentas

| Ferramenta | Função |
|---|---|
| **BorgBackup** | Backup incremental, deduplificado, criptografado |
| **mysqldump** | Backup lógico do MySQL |
| **vzdump** | Backup de VM/containers no Proxmox |
| **rsync** | Sincronização com HD externo |
| **rclone crypt** | Cópia externa criptografada opcional para Google Drive |
| **cron** | Agendamento de tarefas |

## Container LXC: CT112 - Orquestrador de backup local temporario

| Parâmetro | Valor |
|---|---|
| **ID** | 112 |
| **Hostname** | grom-backup |
| **SO** | Ubuntu 24.04 LTS |
| **RAM** | 512MB |
| **vCPU** | 1 |
| **Disco** | 16GB |
| **IP** | 10.0.1.12/24 |

---

## Estrategia 3-2-1 e fase provisoria

- **3** copias dos dados (producao + unidade USB + replica externa/offsite)
- **2** midias diferentes (SSD + HD externo USB)
- **1** copia fora do HP EliteDesk

Enquanto a replica externa no `HA_Back` ainda nao estiver operacional e
validada por restore, a unidade USB de 1 TB e a camada local obrigatoria. Essa
fase e provisoria e nao deve ser considerada 3-2-1 completa sem copia externa
ou offline testada.

## Midias e papeis no lado HP

O lado HP conta inicialmente com uma unidade USB de 1 TB. A evolucao prevista
e manter a replica fisicamente separada no `HA_Back`. Um segundo HD removivel
continua opcional como copia offline no lado HP.

| Midia | Montagem | Papel recomendado |
|---|---|---|
| SSD interno | Proxmox/local-lvm | Sistema, VMs/CTs, dados recentes e cache operacional |
| Unidade USB 1 TB | `/mnt/backup-external` -> CT112 `/mnt/external` | Backup operacional diario, Proxmox `vzdump`, Borg e dumps |
| HA_Back | Rede restrita, `10.0.1.20` sugerido | Replica fisicamente separada dos backups do HP |
| HD externo B opcional | `/mnt/backup-external-2` -> CT112 `/mnt/external2` | Rotacao offline e evidencias importantes |
| Google Drive/rclone crypt | remoto criptografado | Copia externa opcional, nunca backup principal |

Politica recomendada:
- A unidade USB de 1 TB pode ficar conectada para backups automaticos.
- HD B deve ficar desconectado/offline sempre que possivel, conectado apenas para sincronizacao, teste de restore ou guarda de evidencia.
- Nao usar unidade de backup para gravacao continua de video.
- Evidencias importantes devem ir para HD B e copia externa criptografada, quando aplicavel.
- Nenhum HD externo deve armazenar dados sensiveis sem criptografia Borg/rclone crypt ou protecao fisica controlada.

Resumo de ownership:

- `Grom_Server`: backup local do HP, CT112, USB externa, `vzdump`, Borg e
  provisionamento do ponto de replica.
- `HA_Back`: recebimento da replica, copia secundaria local da segunda
  maquina e restore drill do host remoto.

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
> Quando o `HA_Back` entrar em operacao, adicionar a replica para esse host
> sem remover a unidade USB ate concluir teste de restore nas duas copias.

## Ponto de replica para o HA_Back

Quando o `HA_Back` entrar em operacao, o acesso ao CT112 deve ser feito por um
usuario dedicado de replica, nunca por `root`.

Diretriz:
- usuario sugerido: `grom-replica`;
- autenticacao: chave SSH dedicada do `HA_Back`;
- acesso: LAN/VPN apenas;
- permissao: leitura do caminho de backup;
- sem `sudo`, sem tunelamento e sem reutilizar contas administrativas.

Provisionamento recomendado no CT112:

```bash
bash /tmp/setup-replica-user.sh \
  --public-key-file=/tmp/grom-ha-back.pub \
  --user=grom-replica \
  --source-path=/mnt/backup \
  --source-ip=10.0.1.20
```

Script relacionado:

```text
scripts/backup/setup-replica-user.sh
```

O lado remoto dessa replica, incluindo `pull`, espelho secundario e restore
recorrente, fica documentado e automatizado no projeto `HA_Back`.

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

## Verificacao de Backups do lado HP

```bash
# Listar backups
borg list /mnt/backup/databases

# Verificar integridade
borg check /mnt/backup/databases

# Testar restauracao
borg extract --dry-run /mnt/backup/databases::latest
```

O restore drill da segunda maquina deve ser executado e auditado no `HA_Back`,
nao neste repositorio.

---

## Alertas

- Email em caso de falha de backup
- Monitoramento do espaço em disco
- Alerta se backup não executar no horário
