@echo off
chcp 65001 > nul
cd /d "%~dp0"
echo 更新を開始します...
powershell -NoProfile -ExecutionPolicy Bypass -File "./update_content.ps1"
if %errorlevel% neq 0 (
    echo エラーが発生しました。
    pause
) else (
    echo 完了しました。このウィンドウは自動的に閉じます...
    timeout /t 3 > nul
)
