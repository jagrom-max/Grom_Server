# Midia de instalacao completa assistida

Este roteiro gera uma pasta de instalacao em `D:\` para levar ao equipamento
definitivo. A midia inclui pacote, checksum, instalador pos-Proxmox e roteiro de
formatacao limpa.

## Gerar a midia

No Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/create-install-media.ps1 -Destination D:\GROM_SERVER_INSTALL -Force
```

Para incluir tambem o ISO oficial do Proxmox VE na midia:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lab/create-install-media.ps1 -Destination D:\GROM_SERVER_INSTALL -IncludeProxmoxIso -Force
```

Se a midia ja foi criada e voce quer baixar apenas o ISO:

```powershell
cd D:\GROM_SERVER_INSTALL\grom-server-install
powershell -ExecutionPolicy Bypass -File tools\download-proxmox-iso.ps1 -Destination proxmox-iso
```

O resultado esperado:

```text
D:\GROM_SERVER_INSTALL\grom-server-install\
```

## Conteudo

- `files/grom-scripts.tar.gz`
- `files/grom-scripts.tar.gz.sha256`
- `files/grom.env.example`
- `tools/install-grom-server.sh`
- `tools/download-proxmox-iso.ps1`
- `proxmox-iso/proxmox-ve_9.2-1.iso`, quando `-IncludeProxmoxIso` for usado
- `docs/01-FORMATACAO-PROXMOX.md`
- `docs/33-IMPLANTACAO-DEFINITIVA-EQUIPAMENTO.md`
- `docs/34-IMPLANTACAO-EM-BANCADA.md`
- `LEIA-ME-PRIMEIRO.txt`

## Limite de seguranca

O pacote nao apaga discos automaticamente. A formatacao completa da maquina
definitiva deve ser feita no instalador oficial do Proxmox VE, com confirmacao
humana do disco correto.

Depois do Proxmox instalado, o instalador automatiza a conferencia do pacote,
extracao, preparo de `/etc/grom/grom.env` e chamada do orquestrador final.

## Uso no Proxmox

```bash
cd /CAMINHO/grom-server-install
bash tools/install-grom-server.sh --skip-deploy
```

Depois de revisar `/etc/grom/grom.env`:

```bash
bash tools/install-grom-server.sh --confirm-deploy
```

Na rede destinataria:

```bash
bash tools/install-grom-server.sh --confirm-deploy --public-target=grom.seg.br
```
