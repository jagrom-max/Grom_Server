# Runbook da primeira implantacao

Este runbook deve ser usado no dia em que o HP EliteDesk for instalado na rede definitiva. Ele prioriza repetibilidade, baixo risco e rastreabilidade.

## Antes do dia da instalacao

1. Revisar `docs/13-CHECKLIST-PRE-IMPLANTACAO.md`.
2. Gerar release com `bash scripts/build-release.sh` e confirmar o pacote/checksum em `dist/`.
3. Separar pendrive com Proxmox VE validado por checksum.
4. Baixar OPNsense pelo seletor oficial e validar checksum.
5. Guardar no cofre as senhas:
   - `MYSQL_ROOT_PASS`
   - `GROM_SEG_PASS`
   - `GROM_WEB_PASS`
   - `GROM_DOC_PASS`
   - `GROM_BACKUP_PASS`
   - `BORG_PASSPHRASE`
   - `GROM_SMTP_APP_PASS`, se alertas por Gmail forem ativados
6. Confirmar acesso a `grom.servidor@gmail.com` com 2FA.
7. Confirmar controle DNS de `grom.seg.br`.
8. Confirmar se a internet possui IP publico real ou CGNAT.

## Janela minima recomendada

Reservar 6 a 8 horas para a primeira implantacao:
- 1 hora para instalacao base.
- 2 horas para OPNsense, rede e testes.
- 2 horas para containers e deploy.
- 1 a 3 horas para SSL, DNS, backup, VPN e validacao.

## Instalacao fisica

1. Conectar a porta onboard do HP EliteDesk ao caminho de internet/WAN.
2. Conectar o adaptador Ugreen USB 2.5G ao switch TL-SG108.
3. Conectar somente equipamentos confiaveis ao switch TL-SG108.
4. Conectar o HD externo Toshiba apenas quando for configurar backup.
5. Usar cabos Cat6 identificados quando possivel.

## BIOS

Habilitar:
- VT-x.
- VT-d/IOMMU, se disponivel.
- Hyper-Threading.
- Boot por USB.
- Auto power on after AC loss, se houver essa opcao.

Desabilitar:
- Boot de dispositivos desconhecidos depois da instalacao.
- Wake-on-LAN externo, se nao for necessario.

## Instalar Proxmox

1. Instalar Proxmox VE no SSD interno.
2. Definir senha forte do `root`.
3. Definir IP de gerenciamento temporario somente na LAN segura.
4. Atualizar o sistema.
5. Copiar `dist/grom-scripts.zip` ou `dist/grom-scripts.tar.gz` e o respectivo `.sha256` para `/root` no host.
6. Conferir o checksum e extrair em `/root`, criando `/root/grom-scripts`.

Exemplo no Proxmox:

```bash
cd /root
sha256sum -c /root/grom-scripts.zip.sha256
unzip -o /root/grom-scripts.zip -d /root
cd /root/grom-scripts
```

Se o pacote gerado for `.tar.gz`:

```bash
cd /root
sha256sum -c /root/grom-scripts.tar.gz.sha256
tar -xzf /root/grom-scripts.tar.gz -C /root
cd /root/grom-scripts
```

## Criar arquivo local de variaveis

Criar `/etc/grom/grom.env` no Proxmox host. Esse arquivo nunca deve ir para o repositorio.

```bash
mkdir -p /etc/grom
chmod 700 /etc/grom
nano /etc/grom/grom.env
chmod 600 /etc/grom/grom.env
```

Modelo:

```bash
GROM_CONTACT_EMAIL=grom.servidor@gmail.com
GROM_ALERT_EMAIL=grom.servidor@gmail.com
GROM_DOMAIN=grom.seg.br
GROM_APP_DOMAIN=grom.seg.br
GROM_SMTP_USER=grom.servidor@gmail.com
GROM_SMTP_FROM=grom.servidor@gmail.com

MYSQL_ROOT_PASS='senha-do-cofre'
GROM_SEG_PASS='senha-do-cofre'
GROM_WEB_PASS='senha-do-cofre'
GROM_DOC_PASS='senha-do-cofre'
GROM_BACKUP_PASS='senha-do-cofre'
BORG_PASSPHRASE='senha-do-cofre'

# Ativar somente depois de criar senha de app no Google.
# GROM_SMTP_APP_PASS={SENHA_DE_APP_LOCAL}

# Ativar somente depois de configurar rclone crypt no CT112.
GROM_RCLONE_REMOTE=gromdrive_crypt:grom-server-backups
GROM_RCLONE_SOURCE=/mnt/backup
```

## Validar host

Executar:

```bash
bash /root/grom-scripts/scripts/proxmox/verify-host-readiness.sh
bash /root/grom-scripts/scripts/proxmox/capacity-baseline.sh
bash /root/grom-scripts/scripts/proxmox/validate-deploy-config.sh --strict
```

Nao prosseguir se houver falha critica em:
- Proxmox nao detectado.
- Virtualizacao indisponivel.
- Interfaces de rede ausentes.
- Disco sem espaco suficiente.
- Capacidade insuficiente para Server + SigePol + Security em fase controlada.
- HD externo esperado mas nao montado, se a etapa de backup completo for feita no mesmo dia.
- Variavel obrigatoria ausente ou senha com placeholder.
- Pacote `/root/grom-scripts` incompleto.

## Configurar rede Proxmox

Modelo logico:
- `vmbr0`: WAN, ligada a porta onboard.
- `vmbr1`: LAN, ligada ao adaptador Ugreen.

Ajustar nomes reais das interfaces com `ip link`. Nao assumir que serao `eno1` e `enx...` sem validar.

Depois de alterar `/etc/network/interfaces`, reiniciar rede ou reiniciar host em janela controlada.

## Criar OPNsense

1. Colocar ISO do OPNsense no armazenamento local do Proxmox.
2. Criar VM100.
3. NIC1 em `vmbr0` como WAN.
4. NIC2 em `vmbr1` como LAN.
5. Instalar OPNsense.
6. Configurar LAN `10.0.1.1/24`.
7. Alterar senha padrao imediatamente.
8. Criar usuario admin nominal com 2FA.

## Regras minimas no OPNsense

WAN:
- Permitir TCP/80 para CT110 apenas se necessario para HTTP/Let's Encrypt.
- Permitir TCP/443 para CT110.
- Permitir UDP/51820 para CT114 quando VPN estiver ativa.
- Bloquear todo o restante.

LAN/VPN:
- Permitir administracao de Proxmox, OPNsense e containers somente a partir de IPs administrativos.
- Permitir CT110 -> CT111 TCP/3306.
- Permitir CT112 -> CT111 TCP/3306.
- Permitir CT113 monitorar servicos internos.

## Criar containers

Executar no Proxmox:

```bash
cd /root/grom-scripts
bash scripts/proxmox/create-containers.sh
```

Confirmar IDs:
- VM100 OPNsense.
- CT110 Web.
- CT111 Database.
- CT112 Backup.
- CT113 Monitoring.
- CT114 VPN.

## Criar VM Grom_Security/Frigate

No HP EliteDesk, criar apenas a VM130 depois da rede base e antes da liberacao
de uso real:

```bash
cd /root/grom-scripts
bash scripts/proxmox/create-ha-security-vms.sh
```

O script usa `CREATE_HA_VM=0` por padrao e cria somente a VM130 com 4 GB RAM,
4 vCPU e disco de 100 GB.

IP sugerido:
- VM130 Grom_Security/Frigate: `10.0.1.30`.

Criar reservas DHCP ou IPs estaticos no OPNsense.

Nao criar a VM120 neste host. O Home Assistant e o servidor de backup
definitivo serao instalados em outra maquina e integrados posteriormente por
rede restrita. Ate la, o CT112 usa a unidade USB de 1 TB.

## Deploy automatizado

Executar:

```bash
cd /root/grom-scripts
bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --confirm-final-deploy --public-target=grom.seg.br
```

Registrar:
- Data/hora.
- Versao do pacote.
- Falhas ou avisos.
- Servicos que ficaram pendentes por dependerem de DNS, SMTP ou rclone.

## DNS e SSL

Usar `docs/25-DNS-REGISTRO-BR.md` como referencia operacional, pois o dominio `grom.seg.br` esta registrado no Registro.br/Dominios.br.

Criar registros DNS:

| Nome | Tipo | Destino |
|---|---|---|
| `grom.seg.br` | A/AAAA ou CNAME | IP publico ou destino definido |
| `web.grom.seg.br` | A/AAAA ou CNAME | IP publico ou destino definido durante transicao |
| `docs.grom.seg.br` | A/AAAA ou CNAME | IP publico ou destino definido durante transicao |
| `vpn.grom.seg.br` | A/AAAA ou CNAME | IP publico ou destino definido |

Nao criar `monitor.grom.seg.br` publico.

Depois de DNS propagado, emitir/validar certificados:

```bash
pct exec 110 -- certbot certificates
```

## Configurar Gmail operacional

Se a senha de app estiver definida:

```bash
bash /root/grom-scripts/scripts/security/setup-email-relay.sh
```

Validar recebimento de alerta em `grom.servidor@gmail.com`. Nao enviar conteudo sensivel no teste.

## Configurar Google Drive criptografado

Somente se for usar copia externa:

1. Entrar no CT112.
2. Configurar `rclone config`.
3. Criar remote Google Drive normal.
4. Criar remote `crypt` apontando para a pasta de backup.
5. Validar com arquivo teste sem dados sensiveis.
6. Executar `/usr/local/bin/sync-google-drive.sh`.

## Preparar usuario de replica para o HA_Back

Quando a segunda maquina estiver pronta para receber replica:

1. Copiar a chave publica dedicada do `HA_Back` para o CT112.
2. Entrar no CT112.
3. Provisionar o usuario restrito de replica.

Exemplo:

```bash
pct push 112 /root/grom-ha-back.pub /tmp/grom-ha-back.pub
pct push 112 /root/grom-scripts/scripts/backup/setup-replica-user.sh /tmp/setup-replica-user.sh
pct exec 112 -- bash /tmp/setup-replica-user.sh \
  --public-key-file=/tmp/grom-ha-back.pub \
  --user=grom-replica \
  --source-path=/mnt/backup \
  --source-ip=10.0.1.20
```

Objetivo:
- permitir `pull` da replica sem usar `root`;
- restringir acesso ao IP da segunda maquina;
- manter o CT112 como origem controlada da copia remota.

## Testes obrigatorios

Executar antes de uso real:

```bash
bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh
bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh --public-target=grom.seg.br
```

| Teste | Aceite |
|---|---|
| HTTPS Grom.Seg | `grom.seg.br` abre com TLS valido |
| HTTPS legados | `web.grom.seg.br` e `docs.grom.seg.br` abrem com TLS valido enquanto existirem |
| VPN | Cliente conecta e acessa LAN segura |
| Proxmox publico | Porta 8006 nao responde pela internet |
| OPNsense publico | WebGUI nao responde pela internet |
| MySQL publico | Porta 3306 nao responde pela internet |
| Monitor publico | Netdata/Uptime Kuma nao respondem pela internet |
| Backup DB | Dump criado e Borg atualizado |
| Backup VM/LXC | Arquivo `vzdump` criado no HD externo |
| Restore | Uma restauracao de teste foi concluida |
| Alerta | E-mail de teste recebido |

Executar o ensaio seguro de restore:

```bash
bash /root/grom-scripts/scripts/proxmox/restore-drill.sh
```

Depois de revisar o relatorio e confirmar que o teste foi aceito:

```bash
bash /root/grom-scripts/scripts/proxmox/restore-drill.sh --mark-ready
```

## Criterio de liberacao

Liberar uso controlado somente quando:
- Nenhum painel administrativo estiver publico.
- Backup e restore tiverem sido testados.
- VPN estiver funcionando.
- Logs basicos estiverem ativos.
- DNS e TLS estiverem corretos.
- Senhas e chaves estiverem no cofre.
- Usuario administrador nominal existir e root padrao estiver restrito.

## Plano de rollback

Se a implantacao falhar:

1. Remover port forwards no roteador/Mercusys e no OPNsense.
2. Desligar CT110 se houver risco de exposicao.
3. Manter OPNsense e Proxmox acessiveis apenas localmente.
4. Preservar logs de instalacao.
5. Restaurar VM/LXC a partir do snapshot ou recriar containers.
6. Registrar causa e correcao no changelog/runbook antes da nova tentativa.
