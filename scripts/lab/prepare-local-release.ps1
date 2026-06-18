# GROM SERVER - Preparo de pacote candidato local
# Executa validacoes seguras, gera release e lista os artefatos prontos para levar ao Proxmox.

[CmdletBinding()]
param(
    [string]$EnvFile = ".lab/grom.env",
    [switch]$SkipPreview
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

Push-Location $Root
try {
    if (-not $SkipPreview) {
        & powershell -ExecutionPolicy Bypass -File "scripts\lab\preview-dashboard.ps1"
    }

    & powershell -ExecutionPolicy Bypass -File "scripts\lab\run-safe-lab-checks.ps1" -BuildRelease -EnvFile $EnvFile
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $ReleaseFiles = Get-ChildItem -LiteralPath "dist" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^grom-scripts\.(zip|tar\.gz)(\.sha256)?$' } |
        Sort-Object Name

    if (-not $ReleaseFiles) {
        throw "Nenhum pacote de release encontrado em dist."
    }

    Write-Host ""
    Write-Host "[OK] Pacote candidato pronto para transferencia controlada:" -ForegroundColor Green
    $ReleaseFiles | ForEach-Object {
        Write-Host (" - {0} ({1:N0} bytes)" -f $_.FullName, $_.Length)
    }
    Write-Host ""
    Write-Host "Proximo passo no Proxmox: conferir checksum antes de extrair e executar validadores."
}
finally {
    Pop-Location
}
