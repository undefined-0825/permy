@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0hot_restart_frontend.ps1" %*
