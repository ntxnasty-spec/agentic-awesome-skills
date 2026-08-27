@echo off
setlocal
TITLE God's Eye View - Setup und Start

echo ===================================================
echo    God's Eye View - lokales Setup
echo ===================================================
echo.

WHERE powershell >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
    echo [FEHLER] Windows PowerShell wurde nicht gefunden.
    echo          Dieses Skript benoetigt Windows PowerShell 5.1 oder neuer.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
set EXITCODE=%ERRORLEVEL%

IF %EXITCODE% NEQ 0 (
    echo.
    echo [FEHLER] Setup wurde mit Code %EXITCODE% beendet. Meldung oben pruefen.
    pause
)

endlocal
exit /b %EXITCODE%
