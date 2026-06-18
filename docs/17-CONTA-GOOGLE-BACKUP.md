# Conta Google do projeto e backup externo

Criar uma conta Google dedicada para o Grom Server e recomendavel, desde que ela seja tratada como conta operacional sensivel e nao como conta pessoal.

Conta criada para o projeto:

```text
grom.servidor@gmail.com
```

## Uso recomendado

Esta conta tambem e a identidade externa oficial de comunicacao do ecossistema Grom. Ver:

```text
docs/30-COMUNICACAO-OFICIAL.md
```

A conta pode ser usada para:

- Disparar e receber alertas operacionais oficiais.
- Receber alertas de monitoramento e backup.
- Receber avisos de certificado TLS/Let's Encrypt.
- Ser contato tecnico em DNS, Cloudflare, registrador do dominio e servicos auxiliares.
- Guardar documentos operacionais nao sensiveis.
- Receber relatorios periodicos automatizados.
- Armazenar uma copia externa criptografada de backups, se houver espaco/plano suficiente.

## Uso proibido

Nao usar a conta para:

- Armazenar dumps de banco em claro.
- Armazenar documentos policiais em claro.
- Compartilhar arquivos por link publico.
- Login compartilhado por varias pessoas.
- Receber senhas, chaves privadas ou `.env` em texto puro.
- Ser o unico local de backup.

## Backup no Google Drive

Google Drive/Gmail/Photos compartilham a cota de armazenamento da conta. Segundo a documentacao do Google, quando a conta atinge o limite, pode afetar envio/recebimento de e-mails, upload de arquivos e backups. Portanto, Drive nao deve ser o backup principal.

Uso aceitavel:

```text
Producao -> backup local Borg criptografado -> HD externo -> copia externa criptografada no Google Drive
```

Regras:

1. Enviar apenas backup criptografado com Borg/restic/rclone crypt.
2. Nunca enviar banco `.sql`, documentos, PDFs ou imagens em claro.
3. Testar restauracao a partir da copia criptografada.
4. Controlar cota e alertar antes de 80%.
5. Manter HD externo como copia offline independente.

## Conta gratuita vs Google Workspace

Conta gratuita Gmail:

- Custo zero.
- Normalmente oferece armazenamento compartilhado entre Drive, Gmail e Photos.
- Menos controles administrativos e de auditoria.
- Aceitavel para alertas e copia criptografada pequena.

Google Workspace:

- Melhor para dominio proprio e governanca.
- Permite contas como `infra@grom.seg.br` ou `backup@grom.seg.br`.
- Oferece controles administrativos melhores, conforme o plano.
- Recomendado se o projeto passar a tratar a conta como parte formal da operacao.

## Configuracao minima obrigatoria

- Conta atual: `grom.servidor@gmail.com`.
- Melhor opcao futura: `infra@grom.seg.br` em Google Workspace ou provedor equivalente.
- Ativar 2FA com app autenticador e, se possivel, chave/passkey.
- Criar senha de app especifica para SMTP apenas se os alertas por e-mail forem ativados.
- Configurar telefone e e-mail de recuperacao institucionais.
- Guardar codigos de recuperacao no KeePassXC, fora do servidor.
- Senha unica, longa, armazenada no KeePassXC.
- Desativar compartilhamentos publicos no Drive.
- Revisar atividade da conta mensalmente.

## SMTP para alertas

O projeto usa `msmtp` para enviar e-mails do Proxmox e dos containers. A senha de app do Gmail deve ficar somente no servidor, em `/etc/grom/grom.env`, nunca no repositorio.

Exemplo no servidor:

```bash
install -d -m 750 /etc/grom
nano /etc/grom/grom.env
chmod 600 /etc/grom/grom.env
```

Conteudo esperado:

```bash
GROM_CONTACT_EMAIL=grom.servidor@gmail.com
GROM_ALERT_EMAIL=grom.servidor@gmail.com
GROM_DOMAIN=grom.seg.br
GROM_APP_DOMAIN=grom.seg.br
GROM_SMTP_USER=grom.servidor@gmail.com
GROM_SMTP_FROM=grom.servidor@gmail.com
GROM_SMTP_APP_PASS={SENHA_DE_APP_LOCAL}
```

Depois, o deploy configura o relay automaticamente. Sem `GROM_SMTP_APP_PASS`, o deploy continua, mas os alertas por e-mail ficam pendentes.

## Copia externa criptografada com rclone

O CT112 instala `rclone` e inclui o script `sync-google-drive.sh`. Ele so sincroniza se existir um remote criptografado local, por exemplo:

```text
gromdrive_crypt:
```

Modelo recomendado:

```text
Google Drive remote normal -> remote crypt -> pasta grom-server-backups
```

Procedimento resumido no CT112:

```bash
rclone config
```

Criar:

1. Remote Google Drive, por exemplo `gromdrive:`.
2. Remote `crypt` apontando para `gromdrive:grom-server-backups`, por exemplo `gromdrive_crypt:`.
3. Guardar as senhas do `crypt` no KeePassXC.
4. Testar com `rclone lsd gromdrive_crypt:`.

O script agendado usa por padrao:

```bash
GROM_RCLONE_REMOTE=gromdrive_crypt:grom-server-backups
GROM_RCLONE_SOURCE=/mnt/backup
```

Se o remote nao existir, o script apenas registra aviso e nao envia nada.

## Decisao do projeto

A conta Google dedicada esta aprovada para comunicacao operacional e copia externa criptografada. Ela nao substitui backup local, HD externo, BorgBackup, nem testes de restauracao.
