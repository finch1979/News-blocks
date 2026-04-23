param(
    [switch]$NonInteractive
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$startupShortcutName = "News Blocks.lnk"
$desktopShortcutName = "News Blocks.url"
$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = Join-Path $startupFolder $startupShortcutName
$desktopUrlPath = Join-Path ([Environment]::GetFolderPath("Desktop")) $desktopShortcutName

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Configure auto start" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $isAdmin) {
    Write-Host "Running without admin is fine for per-user startup." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "This script will:" -ForegroundColor White
Write-Host "  1. Create a silent startup script" -ForegroundColor Gray
Write-Host "  2. Add a shortcut to the Windows Startup folder" -ForegroundColor Gray
Write-Host "  3. Create a desktop URL shortcut" -ForegroundColor Gray
Write-Host ""

if (-not $NonInteractive) {
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

try {
    Set-Location $PSScriptRoot

    Write-Host "Creating silent startup script..." -ForegroundColor Yellow
    $vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "$PSScriptRoot"
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$PSScriptRoot\start.ps1"" -Quiet", 0, False
"@
    $vbsContent | Out-File -FilePath "$PSScriptRoot\start_silent.vbs" -Encoding ASCII -Force

    Write-Host "Creating Startup folder shortcut..." -ForegroundColor Yellow
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = "$PSScriptRoot\start_silent.vbs"
    $Shortcut.WorkingDirectory = $PSScriptRoot
    $Shortcut.Description = "Start News Blocks in the background"
    $Shortcut.Save()

    Write-Host "Creating desktop URL shortcut..." -ForegroundColor Yellow
    $urlContent = @"
[InternetShortcut]
URL=http://127.0.0.1:7789
IconFile=$env:SystemRoot\System32\SHELL32.dll
IconIndex=220
"@
    $urlContent | Out-File -FilePath $desktopUrlPath -Encoding ASCII -Force

    Write-Host ""
    Write-Host "Auto start is configured." -ForegroundColor Green
    Write-Host ""
    Write-Host "News Blocks will start automatically after Windows sign-in." -ForegroundColor White
    Write-Host "Desktop shortcut: $desktopUrlPath" -ForegroundColor Cyan
    Write-Host "App URL: http://127.0.0.1:7789" -ForegroundColor Cyan
    Write-Host ""
} catch {
    Write-Host ""
    Write-Host "Auto start setup failed." -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if (-not $NonInteractive) {
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
