@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0open_app.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [錯誤] 無法啟動方塊磚新聞
    pause
)
