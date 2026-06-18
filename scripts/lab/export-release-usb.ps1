# GROM SERVER - Exporta pacote candidato para midia/local de transferencia
# Copia release, checksum e um LEIA-ME com os comandos seguros para o Proxmox.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Dist = Join-Path $Root "dist"
$Package = Join-Path $Dist "grom-scripts.tar.gz"
$Checksum = Join-Path $Dist "grom-scripts.tar.gz.sha256"

if (-not (Test-Path -LiteralPath $Package)) {
    throw "Pacote ausente: $Package. Execute scripts\lab\prepare-local-release.ps1 primeiro."
}

if (-not (Test-Path -LiteralPath $Checksum)) {
    throw "Checksum ausente: $Checksum. Execute scripts\lab\prepare-local-release.ps1 primeiro."
}

if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force:$Force | Out-Null
}

$ResolvedDestination = Resolve-Path -LiteralPath $Destination
$OutDir = Join-Path $ResolvedDestination "grom-server-release"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Copy-Item -LiteralPath $Package -Destination (Join-Path $OutDir "grom-scripts.tar.gz") -Force
Copy-Item -LiteralPath $Checksum -Destination (Join-Path $OutDir "grom-scripts.tar.gz.sha256") -Force

$HashLine = (Get-Content -Raw -LiteralPath $Checksum).Trim()
$Readme = @"
GROM SERVER - Pacote candidato para implantacao em bancada

Arquivos:
- grom-scripts.tar.gz
- grom-scripts.tar.gz.sha256

Checksum esperado:
$HashLine

No Proxmox host do equipamento definitivo, ainda fora da rede destinataria:

1. Copiar estes arquivos para /root
2. Conferir integridade:

   cd /root
   sha256sum -c grom-scripts.tar.gz.sha256

3. Extrair:

   tar -xzf grom-scripts.tar.gz -C /root

4. Criar /etc/grom/grom.env com segredos reais e permissao restrita:

   mkdir -p /etc/grom
   chmod 700 /etc/grom
   nano /etc/grom/grom.env
   chmod 600 /etc/grom/grom.env

5. Rodar ensaio sem deploy:

   bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --skip-deploy

6. Se o ensaio estiver aprovado, executar implantacao de bancada sem public-target:

   bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --confirm-final-deploy

7. Testes possiveis em bancada:

   bash /root/grom-scripts/scripts/proxmox/post-deploy-validation.sh
   bash /root/grom-scripts/scripts/proxmox/operational-health-check.sh
   bash /root/grom-scripts/scripts/proxmox/restore-drill.sh

8. Somente na rede destinataria, repetir com alvo publico:

   bash /root/grom-scripts/scripts/proxmox/final-local-deploy.sh --confirm-final-deploy --public-target=grom.seg.br

Nao prosseguir se checksum, env, rede, backup externo ou validadores apontarem falha.
Nao inserir dados reais antes do Go/No-Go no local definitivo.
"@

Set-Content -LiteralPath (Join-Path $OutDir "LEIA-ME-IMPLANTACAO.txt") -Value $Readme -Encoding UTF8

Get-ChildItem -LiteralPath $OutDir | Select-Object FullName,Length,LastWriteTime
