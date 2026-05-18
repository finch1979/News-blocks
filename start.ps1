param(
    [switch]$OpenBrowser,
    [switch]$Quiet
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$port = 7789
$url = "http://127.0.0.1:$port"
$pythonExe = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$pipExe = Join-Path $PSScriptRoot ".venv\Scripts\pip.exe"
$stampFile = Join-Path $PSScriptRoot ".venv\.requirements.stamp"
$requirementsFile = Join-Path $PSScriptRoot "requirements.txt"

function Write-Info($message, $color = "Gray") {
    if (-not $Quiet) {
        Write-Host $message -ForegroundColor $color
    }
}

function Get-BrowserExecutable {
    param([string[]]$Candidates)

    foreach ($candidate in $Candidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }

        foreach ($registryRoot in @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths",
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths"
        )) {
            $registryPath = Join-Path $registryRoot $candidate
            $registryItem = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
            if ($registryItem -and $registryItem.'(default)' -and (Test-Path $registryItem.'(default)')) {
                return $registryItem.'(default)'
            }
        }

        foreach ($basePath in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LocalAppData)) {
            if (-not $basePath) {
                continue
            }

            $matches = Get-ChildItem -Path $basePath -Filter $candidate -Recurse -File -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty FullName
            if ($matches) {
                return $matches
            }
        }
    }

    return $null
}

function Open-AppHomePage {
    $edgeExe = Get-BrowserExecutable @("msedge.exe")
    if ($edgeExe) {
        Start-Process -FilePath $edgeExe -ArgumentList @("--app=$url", "--new-window") | Out-Null
        return
    }

    $chromeExe = Get-BrowserExecutable @("chrome.exe")
    if ($chromeExe) {
        Start-Process -FilePath $chromeExe -ArgumentList @("--app=$url", "--new-window") | Out-Null
        return
    }

    $firefoxExe = Get-BrowserExecutable @("firefox.exe")
    if ($firefoxExe) {
        Start-Process -FilePath $firefoxExe -ArgumentList @("-new-window", $url) | Out-Null
        return
    }

    Start-Process $url
}

function Test-ServiceRunning {
    return [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
}

function Wait-ForService {
    param([int]$TimeoutSeconds = 15)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-ServiceRunning) {
            return $true
        }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Ensure-Venv {
    if (-not (Test-Path $pythonExe)) {
        Write-Info "Creating virtual environment..." "Yellow"
        python -m venv (Join-Path $PSScriptRoot ".venv")
    }
}

function Ensure-Requirements {
    $needsInstall = -not (Test-Path $stampFile)
    if (-not $needsInstall) {
        $needsInstall = (Get-Item $stampFile).LastWriteTimeUtc -lt (Get-Item $requirementsFile).LastWriteTimeUtc
    }

    if ($needsInstall) {
        Write-Info "Installing dependencies..." "Yellow"
        & $pipExe install -r $requirementsFile -q
        Set-Content -Path $stampFile -Value (Get-Date).ToString("o") -Encoding ASCII
    }
}

Set-Location $PSScriptRoot

Write-Info "=========================================" "Cyan"
Write-Info "  News Blocks starting" "Cyan"
Write-Info "  $url" "Yellow"
Write-Info "=========================================" "Cyan"
Write-Info ""

if (Test-ServiceRunning) {
    Write-Info "Service is already running in the background." "Green"
    if ($OpenBrowser) {
        Open-AppHomePage
    }
    exit 0
}

Ensure-Venv
Ensure-Requirements

Write-Info "Starting background service..." "Yellow"
Start-Process -FilePath $pythonExe -ArgumentList @("-m", "uvicorn", "app:app", "--host", "127.0.0.1", "--port", "$port") -WorkingDirectory $PSScriptRoot -WindowStyle Hidden | Out-Null

if (Wait-ForService) {
    Write-Info ""
    Write-Info "Service started successfully." "Green"
    Write-Info "URL: $url" "Cyan"
    Write-Info "The service will keep running after VSCode is closed." "Gray"
    Write-Info "Use stop.ps1 or stop.bat to stop it." "Gray"
    Write-Info ""

    if ($OpenBrowser) {
        Open-AppHomePage
    }
    exit 0
}

Write-Info ""
Write-Info "Service failed to start." "Red"
Write-Info "Check Python or whether port 7789 is already occupied." "Yellow"
exit 1
