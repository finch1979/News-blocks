@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo =========================================
echo   停止方塊磚新聞服務
echo =========================================
echo.

REM 查找占用7789端口的進程
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":7789" ^| findstr "LISTENING"') do (
    echo 找到進程 ID: %%a
    taskkill /F /PID %%a >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✓ 服務已停止
    ) else (
        echo [錯誤] 無法停止進程 %%a
    )
)

REM 檢查是否還在運行
netstat -ano | findstr ":7789" | findstr "LISTENING" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ✓ 所有服務已完全停止
) else (
    echo.
    echo [警告] 可能還有進程在運行，請手動檢查
)

echo.
pause
