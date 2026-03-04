@echo off
setlocal

:: install.cmd - Windows CMD wrapper for Claude Code Statusline installer
:: Delegates all installation work to install.ps1 via PowerShell.
::
:: Usage (remote):
::   curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main/install.cmd -o install.cmd && install.cmd && del install.cmd
::
:: Usage (local, from repo directory):
::   install.cmd

where powershell.exe >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: PowerShell is required but not found.
    echo Please run instead:
    echo   irm https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main/install.ps1 ^| iex
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main/install.ps1')"

exit /b %ERRORLEVEL%
