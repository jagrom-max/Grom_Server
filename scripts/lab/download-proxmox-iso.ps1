# GROM SERVER - Baixa ISO oficial do Proxmox VE para a midia de instalacao
# Usa URL e SHA256 oficiais conferidos em 2026-06-18.

[CmdletBinding()]
param(
    [string]$Destination = "D:\GROM_SERVER_INSTALL\grom-server-install\proxmox-iso",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$IsoName = "proxmox-ve_9.2-1.iso"
$IsoUrl = "https://enterprise.proxmox.com/iso/$IsoName"
$ExpectedSha256 = "4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c"

if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

$IsoPath = Join-Path $Destination $IsoName
$ShaPath = Join-Path $Destination "$IsoName.sha256"
$InfoPath = Join-Path $Destination "PROXMOX-ISO-INFO.txt"

if ((Test-Path -LiteralPath $IsoPath) -and -not $Force) {
    Write-Host "[INFO] ISO ja existe: $IsoPath"
} else {
    Write-Host "[INFO] Baixando Proxmox VE ISO oficial..."
    Write-Host "[INFO] Origem: $IsoUrl"
    Invoke-WebRequest -Uri $IsoUrl -OutFile $IsoPath
}

$ActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $IsoPath).Hash.ToLowerInvariant()
if ($ActualHash -ne $ExpectedSha256) {
    throw "SHA256 invalido para ${IsoPath}. Esperado ${ExpectedSha256}, obtido ${ActualHash}."
}

Set-Content -LiteralPath $ShaPath -Value "$ExpectedSha256 *$IsoName" -Encoding ASCII

$Info = @"
PROXMOX VE ISO

Arquivo: $IsoName
Versao: 9.2-1
Origem: $IsoUrl
SHA256: $ExpectedSha256
Validado em: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")

Uso:
1. Grave este ISO em um pendrive bootavel com Rufus, Balena Etcher ou Ventoy.
2. Inicie o equipamento definitivo pelo pendrive do Proxmox.
3. Formate pelo instalador oficial do Proxmox, escolhendo manualmente o disco correto.
4. Depois de instalado, copie a pasta grom-server-install para o Proxmox e execute tools/install-grom-server.sh.
"@

Set-Content -LiteralPath $InfoPath -Value $Info -Encoding UTF8

Get-ChildItem -LiteralPath $Destination | Select-Object FullName,Length,LastWriteTime
