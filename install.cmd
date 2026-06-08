@echo off
setlocal

:: install.cmd - Windows CMD wrapper for Claude Code Statusline installer
:: Delegates all installation work to install.ps1 via PowerShell.
::
:: Usage (remote, default):
::   curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main/install.cmd -o install.cmd && install.cmd && del install.cmd
::
:: Usage (remote, custom install dir):
::   install.cmd --install-dir C:\custom\path
::
:: Usage (local, from repo directory):
::   install.cmd
::   install.cmd --install-dir C:\custom\path

where powershell.exe >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: PowerShell is required but not found.
    echo Please run instead:
    echo   irm https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main/install.ps1 ^| iex
    exit /b 1
)

:: Parse --install-dir and --dev from arguments
set "INSTALL_DIR_ARG="
set "DEV_ARG="
:parse_args
if "%~1"=="" goto end_parse
if /i "%~1"=="--install-dir" (
    if "%~2"=="" (
        echo ERROR: --install-dir requires an argument.
        exit /b 1
    )
    set "INSTALL_DIR_ARG=%~2"
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--dev" (
    set "DEV_ARG=1"
    shift
    goto parse_args
)
shift
goto parse_args
:end_parse

:: Build PowerShell invocation
:: Prefer local install.ps1 (repo usage); fall back to remote download.
set "LOCAL_PS1=%~dp0install.ps1"

:: --dev only works with local install.ps1 (requires repo + cargo)
if defined DEV_ARG (
    if not exist "%LOCAL_PS1%" (
        echo ERROR: --dev requires running from the repo directory.
        exit /b 1
    )
    if defined INSTALL_DIR_ARG (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCAL_PS1%" -Dev -InstallDir "%INSTALL_DIR_ARG%"
    ) else (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCAL_PS1%" -Dev
    )
    exit /b %ERRORLEVEL%
)

if exist "%LOCAL_PS1%" (
    if defined INSTALL_DIR_ARG (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCAL_PS1%" -InstallDir "%INSTALL_DIR_ARG%"
    ) else (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCAL_PS1%"
    )
) else (
    if defined INSTALL_DIR_ARG (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
            "& ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main/install.ps1'))) -InstallDir `"%INSTALL_DIR_ARG%`""
    ) else (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
            "& ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main/install.ps1')))"
    )
)

exit /b %ERRORLEVEL%
