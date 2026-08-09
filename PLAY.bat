@echo off
rem One-click launcher for NEON DOOM (double-click me!)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
if errorlevel 1 pause
