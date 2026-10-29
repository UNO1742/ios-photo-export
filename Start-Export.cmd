@echo off
cd /d "%~dp0"
if not exist "config.json" (
  copy "config.example.json" "config.json" >nul
  notepad.exe "config.json"
  exit /b 0
)
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Export-iPhone.ps1" -Config "%~dp0config.json"
pause
