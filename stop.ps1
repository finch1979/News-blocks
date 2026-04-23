# 方塊磚新聞 - 停止腳本
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  停止方塊磚新聞服務" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 查找占用7789端口的進程
$connections = Get-NetTCPConnection -LocalPort 7789 -State Listen -ErrorAction SilentlyContinue

if ($connections) {
    $pids = $connections | Select-Object -ExpandProperty OwningProcess -Unique
    
    foreach ($pid in $pids) {
        try {
            $process = Get-Process -Id $pid -ErrorAction Stop
            Write-Host "找到進程: $($process.ProcessName) (PID: $pid)" -ForegroundColor Yellow
            Stop-Process -Id $pid -Force
            Write-Host "✓ 已停止進程 $pid" -ForegroundColor Green
        } catch {
            Write-Host "✗ 無法停止進程 $pid" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "✓ 服務已停止" -ForegroundColor Green
} else {
    Write-Host "• 未找到運行中的服務" -ForegroundColor Gray
}

Write-Host ""
Write-Host "按任意鍵繼續..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
