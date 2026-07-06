# Downloads e preparacao offline

Este documento organiza os downloads externos antes da implantacao fisica. A ideia e reduzir improviso no dia da instalacao, mas sem baixar artefatos sem rastreabilidade.

## Fontes oficiais

| Item | Fonte | Observacao |
|---|---|---|
| Proxmox VE ISO | https://www.proxmox.com/en/downloads | Usar SHA256 oficial publicado na pagina |
| OPNsense ISO | https://opnsense.org/download/ | Usar seletor oficial amd64/dvd e verificar checksum |
| Ubuntu LXC template | http://download.proxmox.com/images/system/ | Template usado pelos containers |

Em 2026-06-15, a pagina oficial do Proxmox lista **Proxmox VE 9.2 ISO Installer**, versao `9.2-1`, com SHA256 `4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c`.

## Preparar no Windows atual

Gerar manifest sem baixar arquivos grandes:

```powershell
.\scripts\downloads\prepare-offline-kit.ps1 -SkipLargeDownloads
```

Baixar Proxmox e template Ubuntu:

```powershell
.\scripts\downloads\prepare-offline-kit.ps1
```

Baixar tambem OPNsense, informando a URL obtida no seletor oficial:

```powershell
.\scripts\downloads\prepare-offline-kit.ps1 -OPNsenseUrl "https://..."
```

## Gerar pacote de implantacao

Sem incluir ISOs/templates grandes:

```powershell
.\scripts\downloads\build-deploy-package.ps1
```

Incluindo a pasta `downloads/` completa:

```powershell
.\scripts\downloads\build-deploy-package.ps1 -IncludeDownloads
```

O pacote de release deve ser gerado com:

```bash
bash scripts/build-release.sh
```

O arquivo final fica em `dist/grom-scripts.zip` quando `zip` estiver disponivel, ou `dist/grom-scripts.tar.gz` como fallback. Copiar o pacote e seu `.sha256` para o Proxmox, conferir o hash e extrair em `/root`, criando `/root/grom-scripts`.

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

## Arquivos locais esperados

Após executar o preparo completo, a pasta `downloads/` deve conter:

```text
downloads/
  manifest.json
  SHA256SUMS.txt
  iso/proxmox-ve_9.2-1.iso
  templates/ubuntu-24.04-standard_24.04-2_amd64.tar.zst
```

O OPNsense deve ser baixado separadamente pelo seletor oficial até confirmarmos a URL/checksum exatos da versão escolhida.

## Preparar em Linux

```bash
bash scripts/downloads/prepare-offline-kit.sh
```

Para informar OPNsense:

```bash
OPNSENSE_URL="https://..." bash scripts/downloads/prepare-offline-kit.sh
```

## Politica de uso

- Nao usar ISO sem checksum verificado quando houver checksum oficial.
- Guardar `downloads/manifest.json` para rastreabilidade.
- Nao commitar ISOs, templates ou dumps no repositorio.
- Preferir baixar OPNsense pelo seletor oficial e conferir checksum conforme a documentacao do projeto.
- No dia da instalacao, copiar apenas os artefatos necessarios para o pendrive ou para `/var/lib/vz/template/`.

## Prontidao do host

Apos instalar Proxmox no HP EliteDesk, executar:

```bash
bash scripts/proxmox/verify-host-readiness.sh
```

Esse script confere interfaces, virtualizacao, comandos essenciais, adaptador USB e HD externo.
