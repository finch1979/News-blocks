[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"

$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = Join-Path $startupFolder "News Blocks.lnk"
$vbsPath = Join-Path $PSScriptRoot "start_silent.vbs"
$desktopUrlPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "News Blocks.url"

$removed = $false

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Remove auto start" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force
    Write-Host "Removed Startup shortcut." -ForegroundColor Green
    $removed = $true
} else {
    Write-Host "Startup shortcut was not found." -ForegroundColor Gray
}

if (Test-Path $vbsPath) {
    Remove-Item $vbsPath -Force
    Write-Host "Removed silent startup script." -ForegroundColor Green
    $removed = $true
}

if (Test-Path $desktopUrlPath) {
    Remove-Item $desktopUrlPath -Force
    Write-Host "Removed desktop URL shortcut." -ForegroundColor Green
    $removed = $true
}

Write-Host ""
if ($removed) {
    Write-Host "Auto start has been removed." -ForegroundColor Green
} else {
    Write-Host "Nothing to remove." -ForegroundColor Gray
}

Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
