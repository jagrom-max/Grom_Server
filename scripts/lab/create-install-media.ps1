# GROM SERVER - Cria midia completa de instalacao assistida
# Gera um diretorio pronto para copiar em pendrive/HD, com pacote, checksum,
# instalador pos-Proxmox e roteiro de formatacao segura do equipamento definitivo.

[CmdletBinding()]
param(
    [string]$Destination = "D:\GROM_SERVER_INSTALL",
    [switch]$SkipBuild,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Dist = Join-Path $Root "dist"
$Package = Join-Path $Dist "grom-scripts.tar.gz"
$Checksum = Join-Path $Dist "grom-scripts.tar.gz.sha256"

Push-Location $Root
try {
    if (-not $SkipBuild) {
        & powershell -ExecutionPolicy Bypass -File "scripts\lab\prepare-local-release.ps1" -SkipPreview
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    if (-not (Test-Path -LiteralPath $Package)) {
        throw "Pacote ausente: $Package"
    }

    if (-not (Test-Path -LiteralPath $Checksum)) {
        throw "Checksum ausente: $Checksum"
    }

    if (Test-Path -LiteralPath $Destination) {
        if (-not $Force) {
            throw "Destino ja existe: $Destination. Use -Force para atualizar."
        }
    } else {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    $ResolvedDestination = Resolve-Path -LiteralPath $Destination
    $MediaRoot = Join-Path $ResolvedDestination "grom-server-install"
    $FilesDir = Join-Path $MediaRoot "files"
    $DocsDir = Join-Path $MediaRoot "docs"
    $ToolsDir = Join-Path $MediaRoot "tools"

    New-Item -ItemType Directory -Path $FilesDir -Force | Out-Null
    New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null

    Copy-Item -LiteralPath $Package -Destination (Join-Path $FilesDir "grom-scripts.tar.gz") -Force
    Copy-Item -LiteralPath $Checksum -Destination (Join-Path $FilesDir "grom-scripts.tar.gz.sha256") -Force
    Copy-Item -LiteralPath (Join-Path $Root "configs\grom.env.example") -Destination (Join-Path $FilesDir "grom.env.example") -Force
    Copy-Item -LiteralPath (Join-Path $Root "docs\34-IMPLANTACAO-EM-BANCADA.md") -Destination (Join-Path $DocsDir "34-IMPLANTACAO-EM-BANCADA.md") -Force
    Copy-Item -LiteralPath (Join-Path $Root "docs\33-IMPLANTACAO-DEFINITIVA-EQUIPAMENTO.md") -Destination (Join-Path $DocsDir "33-IMPLANTACAO-DEFINITIVA-EQUIPAMENTO.md") -Force
    Copy-Item -LiteralPath (Join-Path $Root "docs\35-MIDIA-INSTALACAO-COMPLETA.md") -Destination (Join-Path $DocsDir "35-MIDIA-INSTALACAO-COMPLETA.md") -Force

    $HashLine = (Get-Content -Raw -LiteralPath $Checksum).Trim()
    $BuildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"

    $InstallSh = @'
#!/usr/bin/env bash
set -euo pipefail

CONFIRM_DEPLOY=0
SKIP_DEPLOY=0
PUBLIC_TARGET=""
MEDIA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for arg in "$@"; do
    case "$arg" in
        --confirm-deploy) CONFIRM_DEPLOY=1 ;;
        --skip-deploy) SKIP_DEPLOY=1 ;;
        --public-target=*) PUBLIC_TARGET="${arg#--public-target=}" ;;
        -h|--help)
            cat <<HELP
Uso:
  bash tools/install-grom-server.sh --skip-deploy
  bash tools/install-grom-server.sh --confirm-deploy
  bash tools/install-grom-server.sh --confirm-deploy --public-target=grom.seg.br

Este instalador deve rodar como root no Proxmox ja instalado.
Ele nao formata disco. A formatacao e feita pela instalacao limpa do Proxmox.
HELP
            exit 0
            ;;
        *)
            echo "[FALHA] Argumento desconhecido: $arg" >&2
            exit 2
            ;;
    esac
done

fail() { echo "[FALHA] $1" >&2; exit 1; }
ok() { echo "[OK] $1"; }
info() { echo "[INFO] $1"; }

[ "$(id -u)" -eq 0 ] || fail "Execute como root no Proxmox"
command -v pveversion >/dev/null 2>&1 || fail "Este script deve rodar no host Proxmox"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum ausente"
command -v tar >/dev/null 2>&1 || fail "tar ausente"

cd "$MEDIA_DIR/files"
sha256sum -c grom-scripts.tar.gz.sha256
ok "Checksum aprovado"

mkdir -p /root
rm -rf /root/grom-scripts
tar -xzf grom-scripts.tar.gz -C /root
ok "Pacote extraido em /root/grom-scripts"

mkdir -p /etc/grom
chmod 700 /etc/grom
if [ ! -f /etc/grom/grom.env ]; then
    cp "$MEDIA_DIR/files/grom.env.example" /etc/grom/grom.env
    chmod 600 /etc/grom/grom.env
    echo ""
    echo "[ACAO NECESSARIA] Edite /etc/grom/grom.env com os segredos reais antes do deploy."
    echo "Comando: nano /etc/grom/grom.env"
    exit 20
fi
chmod 600 /etc/grom/grom.env

ARGS=(--env=/etc/grom/grom.env)
if [ -n "$PUBLIC_TARGET" ]; then
    ARGS+=(--public-target="$PUBLIC_TARGET")
fi

if [ "$SKIP_DEPLOY" -eq 1 ]; then
    ARGS+=(--skip-deploy)
elif [ "$CONFIRM_DEPLOY" -eq 1 ]; then
    ARGS+=(--confirm-final-deploy)
else
    fail "Use --skip-deploy para ensaio ou --confirm-deploy para instalar."
fi

info "Executando orquestrador final..."
bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh "${ARGS[@]}"
ok "Instalacao/orquestracao concluida"
'@

    Set-Content -LiteralPath (Join-Path $ToolsDir "install-grom-server.sh") -Value $InstallSh -Encoding ASCII

    $FormatDoc = @'
# GROM SERVER - Formatacao e instalacao limpa do equipamento definitivo

Este pacote nao executa formatacao automatica por seguranca. A formatacao completa
da maquina definitiva deve ser feita pela tela oficial do instalador Proxmox VE,
com confirmacao humana do disco correto.

## Antes de formatar

- Confirmar que o equipamento definitivo e o alvo correto.
- Remover discos que nao devem ser apagados.
- Conferir backup de qualquer dado existente.
- Ativar virtualizacao na BIOS/UEFI: Intel VT-x/VT-d ou AMD-V/IOMMU.
- Definir boot pelo pendrive/ISO do Proxmox.
- Separar dados de rede: IP, gateway, DNS e hostname.

## Formatacao pelo Proxmox

1. Iniciar pelo instalador oficial do Proxmox VE.
2. Escolher instalacao limpa.
3. Selecionar somente o disco definitivo correto.
4. Aceitar a remocao total das particoes desse disco.
5. Definir senha forte do root e e-mail administrativo.
6. Configurar rede inicial de gerenciamento.
7. Concluir instalacao e reiniciar sem o pendrive do instalador.

## Pos-formatacao

Copiar esta pasta `grom-server-install` para o Proxmox, por USB, SCP ou outro
meio controlado. Depois rodar:

```bash
cd /CAMINHO/grom-server-install
bash tools/install-grom-server.sh --skip-deploy
```

Se o ensaio passar e `/etc/grom/grom.env` estiver revisado:

```bash
bash tools/install-grom-server.sh --confirm-deploy
```

Na rede destinataria, repetir com alvo publico:

```bash
bash tools/install-grom-server.sh --confirm-deploy --public-target=grom.seg.br
```
'@

    $ReadmeTemplate = @'
GROM SERVER - Midia completa de instalacao assistida

Gerado em: __BUILD_DATE__

Conteudo:
- files/grom-scripts.tar.gz
- files/grom-scripts.tar.gz.sha256
- files/grom.env.example
- tools/install-grom-server.sh
- docs/01-FORMATACAO-PROXMOX.md
- docs/33-IMPLANTACAO-DEFINITIVA-EQUIPAMENTO.md
- docs/34-IMPLANTACAO-EM-BANCADA.md
- docs/35-MIDIA-INSTALACAO-COMPLETA.md

Checksum esperado:
__HASH_LINE__

Uso recomendado:
1. Formatar a maquina definitiva pelo instalador oficial do Proxmox VE.
2. Copiar esta pasta para o Proxmox.
3. Rodar ensaio:

   cd /CAMINHO/grom-server-install
   bash tools/install-grom-server.sh --skip-deploy

4. Editar /etc/grom/grom.env com segredos reais, se o instalador solicitar.
5. Executar implantacao de bancada:

   bash tools/install-grom-server.sh --confirm-deploy

6. Antes da rede destinataria, validar:

   bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh
   bash /root/grom-scripts/scripts/proxmox/operational-health-check.sh
   bash /root/grom-scripts/scripts/proxmox/restore-drill.sh

7. Na rede destinataria:

   bash tools/install-grom-server.sh --confirm-deploy --public-target=grom.seg.br

Nao use este pacote para apagar discos automaticamente. A formatacao deve ser
confirmada na tela do instalador Proxmox para evitar perda acidental de dados.
'@

    $Readme = $ReadmeTemplate.
        Replace("__BUILD_DATE__", $BuildDate).
        Replace("__HASH_LINE__", $HashLine)

    Set-Content -LiteralPath (Join-Path $DocsDir "01-FORMATACAO-PROXMOX.md") -Value $FormatDoc -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $MediaRoot "LEIA-ME-PRIMEIRO.txt") -Value $Readme -Encoding UTF8

    Get-ChildItem -LiteralPath $MediaRoot -Recurse -File |
        Select-Object FullName,Length,LastWriteTime
}
finally {
    Pop-Location
}
