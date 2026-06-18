# GROM SERVER - Preview local do dashboard
# Sobe um servidor HTTP estatico para validar /server/ sem depender do preview do VS Code.

[CmdletBinding()]
param(
    [int]$Port = 8090
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$PublicRoot = Join-Path $Root "apps\grom-seg\public"
$Python = Get-Command python -ErrorAction SilentlyContinue

if (-not $Python) {
    throw "Python nao encontrado. Instale Python ou sirva apps\grom-seg\public por outro servidor HTTP local."
}

if (-not (Test-Path (Join-Path $PublicRoot "server\index.html"))) {
    throw "Dashboard nao encontrado em apps\grom-seg\public\server."
}

$Listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $Listener) {
    Start-Process `
        -FilePath $Python.Source `
        -ArgumentList @("-m", "http.server", "$Port", "--bind", "127.0.0.1") `
        -WorkingDirectory $PublicRoot `
        -WindowStyle Hidden

    Start-Sleep -Seconds 2
}

$Url = "http://127.0.0.1:$Port/server/"
$Status = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 10

if ($Status.StatusCode -ne 200) {
    throw "Preview respondeu HTTP $($Status.StatusCode)."
}

Write-Host "[OK] Dashboard disponivel em $Url"
Write-Host "[OK] Raiz servida: $PublicRoot"
