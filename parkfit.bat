@echo off
chcp 65001 > nul
setlocal

REM ---------------------------------------------------------------------------
REM  PARK FIT launcher  -  starts the API/app server AND the ngrok tunnel.
REM
REM  ASCII ONLY. Do not put Korean text in this file.
REM  cmd.exe parses a .bat line by line using the ACTIVE code page, so multi-byte
REM  characters here can swallow bytes and split commands ("python" -> "thon").
REM  Save without BOM, CRLF line endings.
REM
REM  Optional environment overrides:
REM    PARKFIT_PORT=8000        server port
REM    PARKFIT_NO_BROWSER=1     do not open the browser
REM    PARKFIT_NO_NGROK=1       do not start the ngrok tunnel
REM    PARKFIT_NGROK_URL=...    reserved ngrok domain (https://...)
REM    PARKFIT_KEEP_NGROK=1     leave ngrok running after the server stops
REM ---------------------------------------------------------------------------

REM Project path contains non-ASCII characters, so always anchor to this script.
cd /d "%~dp0"

set "PYTHONIOENCODING=utf-8"
if "%PARKFIT_PORT%"=="" set "PARKFIT_PORT=8000"
if "%PARKFIT_NGROK_URL%"=="" set "PARKFIT_NGROK_URL=<ngrok URL>"

REM %RANDOM% busts the browser cache - index.html is served straight off disk,
REM so without it a stale copy hides every frontend change.
set "PARKFIT_URL=http://localhost:%PARKFIT_PORT%/?debug=1&v=%RANDOM%"

set "PY=python"
if exist ".venv\Scripts\python.exe" set "PY=.venv\Scripts\python.exe"

"%PY%" -c "import fastapi, uvicorn" 2> nul
if errorlevel 1 (
    echo.
    echo   [ERROR] FastAPI / uvicorn not installed.
    echo   Run: pip install -r backend\requirements.txt
    echo.
    pause
    exit /b 1
)

REM --- ngrok -----------------------------------------------------------------
REM The free plan allows ONE agent session at a time, so a leftover ngrok from a
REM previous run makes the new one fail. Kill it first (silent if none running).
set "NGROK_STARTED=0"
if "%PARKFIT_NO_NGROK%"=="1" goto :skip_ngrok

where ngrok > nul 2> nul
if errorlevel 1 (
    echo   [WARN] ngrok not found in PATH - phone access disabled.
    echo          Install it, or set PARKFIT_NO_NGROK=1 to hide this message.
    goto :skip_ngrok
)

taskkill /IM ngrok.exe /F > nul 2> nul
start "PARK FIT ngrok" cmd /k ngrok http %PARKFIT_PORT% --url %PARKFIT_NGROK_URL%
set "NGROK_STARTED=1"

:skip_ngrok

title PARK FIT - port %PARKFIT_PORT%
echo.
echo   PARK FIT server starting on port %PARKFIT_PORT%
echo.
echo   PC    : %PARKFIT_URL%   ^(dev - debug panels on^)
REM 015 SC: the phone URL is what judges scan. ?debug=1 opens the manual
REM two-point tool, the tape-compare panel and the raw diagnostics - none of
REM which belong on a demo screen. Keep the demo URL clean; the dev URL below
REM still carries ?debug=1 for us.
if "%NGROK_STARTED%"=="1" echo   Phone : %PARKFIT_NGROK_URL%/                 ^(DEMO - show this QR^)
if "%NGROK_STARTED%"=="1" echo   Phone : %PARKFIT_NGROK_URL%/?debug=1         ^(dev only^)
if "%NGROK_STARTED%"=="0" echo   Phone : (ngrok not started)
echo.
echo   Press Ctrl+C to stop.
echo.

if not "%PARKFIT_NO_BROWSER%"=="1" (
    start "" /b powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 5; Start-Process '%PARKFIT_URL%'"
)

"%PY%" -m uvicorn backend.main:app --host 0.0.0.0 --port %PARKFIT_PORT%

REM Ctrl+C lands here. Take the tunnel down with the server so the next run is
REM not blocked by a stale session.
if "%NGROK_STARTED%"=="1" if not "%PARKFIT_KEEP_NGROK%"=="1" taskkill /IM ngrok.exe /F > nul 2> nul

echo.
echo   Server stopped.
pause
endlocal