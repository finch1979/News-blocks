@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1" -OpenBrowser
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [錯誤] 服務啟動失敗
    pause
)
