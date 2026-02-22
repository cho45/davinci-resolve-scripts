@echo off
setlocal
set "SCRIPT_PATH=%~dp0setup.ps1"

echo ======================================================
echo  DaVinci Resolve Setup Launcher (Admin)
echo ======================================================

:: 管理者権限をチェックし、なければ昇格して自分自身を再実行する
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Administrator privileges not detected.
    echo Requesting elevation...
    powershell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

:: 管理者権限でPowerShellスクリプトを実行する
pushd "%~dp0"
powershell -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
popd

echo.
echo Press any key to exit...
pause >nul
