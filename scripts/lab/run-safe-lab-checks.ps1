# GROM SERVER - Validacao segura em laboratorio no Windows
# Encaminha para o script Bash usando Git Bash quando disponivel.

[CmdletBinding()]
param(
    [switch]$BuildRelease,
    [string]$EnvFile = ".lab/grom.env"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Candidates = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files\Git\usr\bin\bash.exe",
    "bash.exe"
)

$Bash = $null
foreach ($Candidate in $Candidates) {
    $Command = Get-Command $Candidate -ErrorAction SilentlyContinue
    if ($Command) {
        $Bash = $Command.Source
        break
    }
}

if (-not $Bash) {
    throw "Git Bash/bash nao encontrado. Instale Git for Windows ou execute scripts/lab/run-safe-lab-checks.sh em Linux."
}

$ArgsList = @("scripts/lab/run-safe-lab-checks.sh", "--env=$EnvFile")
if ($BuildRelease) {
    $ArgsList += "--build-release"
}

Push-Location $Root
try {
    & $Bash @ArgsList
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
