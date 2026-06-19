# Pendrives e ordem de uso

Este roteiro existe para evitar confusao entre os dois pendrives usados na
implantacao da maquina definitiva do Grom Server.

## Pendrive 1: `PVE_BOOT`

Uso: inicializar o instalador do Proxmox VE na maquina definitiva.

Este e o pendrive que deve ser conectado para dar boot. Nao use este pendrive
para guardar arquivos de apoio do Grom Server.

### Ordem de uso

1. Conectar o pendrive `PVE_BOOT` na maquina definitiva.
2. Entrar na BIOS/UEFI e escolher boot por USB em modo UEFI.
3. Iniciar o instalador oficial do Proxmox VE.
4. Selecionar cuidadosamente somente o disco correto da maquina definitiva.
5. Concluir a instalacao do Proxmox.
6. Remover este pendrive apos a instalacao ou no primeiro reinicio, se
   necessario.

### Lembretes

- Este pendrive e apenas para boot.
- A instalacao do Proxmox apaga o disco selecionado.
- Antes de confirmar a instalacao, conferir se o equipamento e realmente o
  definitivo.
- Se houver escolha entre UEFI e Legacy/CSM, preferir UEFI.

### Referencia do ISO

- Arquivo: `proxmox-ve_9.2-1.iso`
- Estado: download completo e hash SHA256 validado

## Pendrive 2: `GROM_APOIO`

Uso: guardar os arquivos de apoio da implantacao.

Nao inicialize a maquina definitiva por este pendrive. Ele nao e o pendrive de
boot do Proxmox.

### Conteudo esperado

- pasta `grom-server-install`
- ISO oficial do Proxmox em `grom-server-install/proxmox-iso/`

### Ordem de uso

1. Depois que o Proxmox estiver instalado e operacional, conectar o pendrive
   `GROM_APOIO`.
2. Copiar a pasta `grom-server-install` para o Proxmox por USB, SCP ou outro
   meio controlado.
3. No Proxmox, executar:

```bash
cd /CAMINHO/grom-server-install
bash tools/install-grom-server.sh --skip-deploy
```

4. Revisar `/etc/grom/grom.env` se solicitado.
5. Para a implantacao:

```bash
bash tools/install-grom-server.sh --confirm-deploy
```

6. Na rede destinataria:

```bash
bash tools/install-grom-server.sh --confirm-deploy --public-target=grom.seg.br
```

### Lembretes

- Nao estamos usando a maquina definitiva agora.
- Nao formatar discos internos na maquina atual.
- Manter este pendrive separado do pendrive de boot para evitar confusao.

## Resumo rapido

1. `PVE_BOOT` inicia o instalador do Proxmox.
2. Instalar o Proxmox no disco correto da maquina definitiva.
3. `GROM_APOIO` entra somente depois, para copiar `grom-server-install`.
