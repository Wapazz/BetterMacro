@echo off
rem Double-clic : bascule BetterMacro entre dev et prod. Argument optionnel : dev, prod, status.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Switch-Addon.ps1" %*
pause
