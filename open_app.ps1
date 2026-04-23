param(
    [switch]$Quiet
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$startScript = Join-Path $PSScriptRoot "start.ps1"
$url = "http://127.0.0.1:7789"

if (-not $Quiet) {
    Write-Host "Checking News Blocks service..." -ForegroundColor Yellow
}

& $startScript -OpenBrowser -Quiet:$Quiet
if ($LASTEXITCODE -ne 0) {
    if (-not $Quiet) {
        Write-Host "Unable to start News Blocks." -ForegroundColor Red
    }
    exit $LASTEXITCODE
}

if (-not $Quiet) {
    Write-Host "Opened $url" -ForegroundColor Green
}
