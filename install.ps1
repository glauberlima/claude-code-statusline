#Requires -Version 5.1
<#
.SYNOPSIS
    Installer for Claude Code Statusline (Windows)
.DESCRIPTION
    Downloads the latest statusline binary and configures Claude Code.
.EXAMPLE
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main/install.ps1)))
.EXAMPLE
    .\install.ps1 -InstallDir C:\custom\path
#>
param(
    [string]$InstallDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$GithubRepo    = "glauberlima/claude-code-statusline"
$GithubApi     = "https://api.github.com/repos/$GithubRepo/releases/latest"
$GithubDlBase  = "https://github.com/$GithubRepo/releases/download"
$MaxRetries    = 3

# ── Derived paths ──────────────────────────────────────────────────────────────
if ([string]::IsNullOrEmpty($InstallDir)) {
    $InstallDir = Join-Path $HOME ".claude"
}

$TargetFile   = Join-Path $InstallDir "statusline.exe"
$SettingsFile = Join-Path $HOME ".claude\settings.json"
$TomlFile     = Join-Path $InstallDir "statusline.toml"

$DefaultInstallDir = Join-Path $HOME ".claude"
if ($InstallDir -eq $DefaultInstallDir) {
    $CommandPath = "~/.claude/statusline.exe"
} else {
    $CommandPath = $TargetFile
}

# ── Output helpers ─────────────────────────────────────────────────────────────
function Write-Success([string]$Msg) {
    Write-Host -NoNewline -ForegroundColor Green "✓"
    Write-Host " $Msg"
}
function Write-Info([string]$Msg) {
    Write-Host -NoNewline -ForegroundColor Cyan "→"
    Write-Host " $Msg"
}
function Write-Warn([string]$Msg) {
    Write-Host -NoNewline -ForegroundColor Yellow "⚠" -ErrorAction SilentlyContinue
    [Console]::Error.WriteLine("  $Msg")
}
function Write-Err([string]$Msg) {
    Write-Host -NoNewline -ForegroundColor Red "✗" -ErrorAction SilentlyContinue
    [Console]::Error.WriteLine(" $Msg")
}
function Write-Step([int]$N, [string]$Msg) {
    Write-Host ""
    Write-Host -NoNewline -ForegroundColor Cyan "[$N/3]"
    Write-Host " $Msg"
}

# ── Header / footer ────────────────────────────────────────────────────────────
function Print-Header {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗"
    Write-Host "║        Claude Code Statusline - Installer        ║"
    Write-Host "╚══════════════════════════════════════════════════╝"
    Write-Host ""
}

function Print-Footer {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗"
    Write-Host "║              Installation Complete!              ║"
    Write-Host "╚══════════════════════════════════════════════════╝"
    Write-Host ""
    Write-Host "Installed: $TargetFile"
    Write-Host ""
    Write-Host -NoNewline "Next step: "
    Write-Host -ForegroundColor Cyan "Restart Claude Code to see your new statusline"
    Write-Host ""
    Write-Host "To update, run the installation command again."
    Write-Host "To customize, edit $TomlFile"
    Write-Host ""
}

# ── Download with retries ──────────────────────────────────────────────────────
function Download-WithRetries([string]$Url, [string]$Dest) {
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            $prev = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
            $ProgressPreference = $prev
            return $true
        } catch {
            $ProgressPreference = $prev
            $attempt++
            if ($attempt -le $MaxRetries) { Start-Sleep -Seconds 1 }
        }
    }
    return $false
}

# ── Main ───────────────────────────────────────────────────────────────────────
Print-Header

# [1/3] Check dependencies
Write-Step 1 "Checking dependencies..."

$Missing = @()
foreach ($dep in @("claude")) {
    if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
        $Missing += $dep
    }
}

if ($Missing.Count -gt 0) {
    Write-Err "Missing dependencies: $($Missing -join ', ')"
    Write-Host ""
    if ($Missing -contains "claude") {
        Write-Host -NoNewline -ForegroundColor Cyan "Claude Code CLI:"
        Write-Host ""
        Write-Host "  Visit https://claude.ai/code for installation instructions"
        Write-Host ""
    }
    Write-Host "Installation aborted. Install dependencies and try again."
    exit 1
}

foreach ($dep in @("claude")) {
    $ver = & $dep --version 2>$null | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($ver)) { $ver = "found" }
    Write-Success "$dep $ver"
}

# [2/3] Install binary
Write-Step 2 "Installing binary..."

$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
if ($arch -ne [System.Runtime.InteropServices.Architecture]::X64) {
    Write-Err "Unsupported architecture: $arch. Only x64 is supported."
    exit 1
}

$Asset = "statusline-windows-x64.exe"

$ProgressPreference = 'SilentlyContinue'
try {
    $Release = Invoke-RestMethod -Uri $GithubApi -UseBasicParsing
} catch {
    Write-Err "Could not determine latest release tag."
    exit 1
} finally {
    $ProgressPreference = 'Continue'
}

$Tag = $Release.tag_name
if ([string]::IsNullOrEmpty($Tag)) {
    Write-Err "Could not determine latest release tag."
    exit 1
}

Write-Info "Downloading statusline $Tag for $Asset..."

if (-not (Test-Path $InstallDir)) {
    try {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    } catch {
        Write-Err "Cannot create install directory: $InstallDir"
        exit 1
    }
}

$DownloadUrl = "$GithubDlBase/$Tag/$Asset"
if (-not (Download-WithRetries $DownloadUrl $TargetFile)) {
    Write-Err "Failed to download from $DownloadUrl"
    Write-Info "Check your internet connection and try again"
    exit 1
}

if (-not (Test-Path $TargetFile) -or (Get-Item $TargetFile).Length -eq 0) {
    Write-Err "Downloaded file is empty"
    exit 1
}

if (Test-Path $TomlFile) {
    Write-Info "Config already exists, skipping: $TomlFile"
} else {
    try {
        & $TargetFile --print-defaults | Set-Content -Path $TomlFile -Encoding UTF8
        Write-Success "Created default config: $TomlFile"
    } catch {
        Write-Err "Failed to generate $TomlFile"
        exit 1
    }
}

Write-Success "Binary installed to $TargetFile"

# [3/3] Configure Claude Code
Write-Step 3 "Configuring Claude Code..."

$cfgExit = 0
try {
    & $TargetFile --configure-settings $SettingsFile $CommandPath
    $cfgExit = $LASTEXITCODE
} catch {
    $cfgExit = 1
}

if ($cfgExit -ne 0) {
    Write-Warn "Installation succeeded, but automatic configuration failed"
    Write-Host ""
    Write-Host "Please manually add to ~/.claude/settings.json:"
    Write-Host '   {'
    Write-Host '     "statusLine": {'
    Write-Host '       "type": "command",'
    Write-Host "       `"command`": `"$CommandPath`","
    Write-Host '       "padding": 0'
    Write-Host '     }'
    Write-Host '   }'
    Write-Host ""
    exit 2
}

Print-Footer
