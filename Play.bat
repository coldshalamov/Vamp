@echo off
start "Vampire City Server" /min node "%~dp0server.js" 5599
timeout /t 1 /nobreak >nul
start "" http://localhost:5599
