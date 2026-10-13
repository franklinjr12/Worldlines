@echo off
setlocal
cd /d "%~dp0"
if not exist "bin\ada_experiments.exe" (
    echo Build Worldlines first with: alr build
    pause
    exit /b 1
)
start "Worldlines" /D "%~dp0" "%~dp0bin\ada_experiments.exe"
