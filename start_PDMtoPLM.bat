@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%extract_part.ps1"
set "PS32=%WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%PS32%" (
    echo PowerShell 32-bit nao encontrado nesta maquina.
    pause
    exit /b 1
)

"%PS32%" -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

if %ERRORLEVEL% NEQ 0 (
    echo Falha ao executar o processo.
    pause
    exit /b 1
)

echo Processo finalizado com sucesso.
pause
endlocal