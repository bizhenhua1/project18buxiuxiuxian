@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0godot\original-six.ps1" -Mode 3D
if errorlevel 1 pause
