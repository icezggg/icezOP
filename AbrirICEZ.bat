@echo off
chcp 65001 >nul
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0icezop.ps1""' -Verb RunAs"