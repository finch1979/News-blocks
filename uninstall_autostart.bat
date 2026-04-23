@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo =========================================
echo   取消開機自動啟動
echo =========================================
echo.

REM 刪除啟動資料夾中的快捷方式
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\方塊磚新聞.lnk" (
    del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\方塊磚新聞.lnk"
    echo ✓ 已移除開機啟動快捷方式
) else (
    echo • 未找到開機啟動快捷方式
)

REM 刪除VBS腳本
if exist "%~dp0start_silent.vbs" (
    del "%~dp0start_silent.vbs"
    echo ✓ 已刪除啟動腳本
)

REM 刪除桌面網址捷徑
if exist "%USERPROFILE%\Desktop\News Blocks.url" (
    del "%USERPROFILE%\Desktop\News Blocks.url"
    echo ✓ 已刪除桌面網址捷徑
)

echo.
echo ✓ 已取消開機自動啟動
echo.
echo 提示：
echo   • 下次開機將不會自動啟動服務
echo   • 如需使用，請手動執行 start.bat
echo   • 若要重新啟用自動啟動，執行 install_autostart.bat
echo.

pause
