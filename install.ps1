#Requires -Version 5.1
<#
.SYNOPSIS
    Installer for Claude Code Statusline (Windows)

.DESCRIPTION
    Downloads the latest Rust binary from GitHub releases and configures
    Claude Code settings.json.

.EXAMPLE
    # Remote (PowerShell pipe install)
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main/install.ps1)))

    # Local (from repo directory)
    .\install.ps1

    # Local dev build (from repo directory)
    .\install.ps1 -Dev
#>

param(
    [string]$InstallDir = (Join-Path $HOME '.claude'),
    [switch]$Dev
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# Configuration
# ============================================================================

$TargetDir          = $InstallDir
$TargetFile         = Join-Path $InstallDir 'statusline.exe'
# settings.json always lives in the default Claude config dir, regardless of $InstallDir
$SettingsFile       = Join-Path (Join-Path $HOME '.claude') 'settings.json'
$TomlFile           = Join-Path $InstallDir 'statusline.toml'
$GithubApi          = 'https://api.github.com/repos/glauberlima/claude-code-statusline/releases/latest'
$GithubBaseUrl      = 'https://github.com/glauberlima/claude-code-statusline/releases/download'
$MaxDownloadRetries = 3

# Use tilde path for the default location (Claude Code resolves ~ natively);
# use the absolute path when a custom install dir is specified.
$defaultClaudeDir   = Join-Path $HOME '.claude'
$StatusLineCommand  = if ($InstallDir -eq $defaultClaudeDir) { '~/.claude/statusline' } else { Join-Path $InstallDir 'statusline' }

# ============================================================================
# UI Functions
# ============================================================================

function Write-Header {
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════╗'
    Write-Host '║        Claude Code Statusline - Installer        ║'
    Write-Host '╚══════════════════════════════════════════════════╝'
    Write-Host ''
}

function Write-Footer {
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════╗'
    Write-Host '║              Installation Complete!              ║'
    Write-Host '╚══════════════════════════════════════════════════╝'
    Write-Host ''
    Write-Host "Installed: $TargetFile"
    Write-Host ''
    Write-Host -NoNewline 'Next step: '
    Write-Host -ForegroundColor Cyan 'Restart Claude Code to see your new statusline'
    Write-Host ''
    Write-Host 'To update, run the installation command again.'
    Write-Host "To customize, edit $TomlFile"
    Write-Host ''
}

function Write-Step {
    param([int]$Current, [int]$Total, [string]$Message)
    Write-Host ''
    Write-Host -NoNewline -ForegroundColor Cyan "[$Current/$Total] "
    Write-Host $Message
}

function Write-Success { param([string]$Message); Write-Host -ForegroundColor Green "✓ $Message" }
function Write-Warn    { param([string]$Message); Write-Host -ForegroundColor Yellow "⚠  $Message" }
function Write-Err     { param([string]$Message); Write-Host -ForegroundColor Red "✗ $Message" }
function Write-Info    { param([string]$Message); Write-Host -ForegroundColor Cyan "→ $Message" }

# ============================================================================
# Utility Functions
# ============================================================================

function Get-Timestamp {
    return [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
}

function Invoke-Cleanup {
    # No temp dir in this installer — placeholder for error handler symmetry
}

function Invoke-CleanupOnError {
    Invoke-Cleanup
    Write-Host ''
    Write-Err 'Installation failed. No changes made.'
    exit 1
}

# ============================================================================
# Validation Functions
# ============================================================================

function Get-ToolVersion {
    param([string]$Tool)
    try {
        $out = & $Tool --version 2>$null | Select-Object -First 1
        if ($out -match '([\d.]+)') { return $Matches[1] }
        return 'found'
    } catch {
        return 'found'
    }
}

function Test-Dependencies {
    $missing = @()

    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { $missing += 'claude' }
    if (-not (Get-Command node   -ErrorAction SilentlyContinue)) { $missing += 'node' }

    if ($missing.Count -gt 0) {
        Show-InstallInstructions $missing
        return $false
    }

    Write-Success "claude $(Get-ToolVersion claude)"
    Write-Success "node   $(Get-ToolVersion node)"
    return $true
}

function Show-InstallInstructions {
    param([string[]]$Missing)
    Write-Err "Missing dependencies: $($Missing -join ', ')"
    Write-Host ''

    if ($Missing -contains 'claude') {
        Write-Host -ForegroundColor Cyan 'Claude Code CLI:'
        Write-Host '  Visit https://claude.ai/code for installation instructions'
        Write-Host ''
    }

    if ($Missing -contains 'node') {
        Write-Host -ForegroundColor Cyan 'Node.js:'
        Write-Host '  https://nodejs.org/'
        Write-Host '  winget install --id OpenJS.NodeJS'
        Write-Host ''
    }

    Write-Host 'Installation aborted. Install dependencies and try again.'
}

# ============================================================================
# Download Functions
# ============================================================================

function Invoke-DownloadFile {
    param([string]$Url, [string]$Dest)

    $ProgressPreference = 'SilentlyContinue'
    for ($attempt = 1; $attempt -le $MaxDownloadRetries; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -ErrorAction Stop
            break
        } catch {
            if ($attempt -ge $MaxDownloadRetries) {
                $ProgressPreference = 'Continue'
                Write-Err "Failed to download from $Url"
                Write-Info 'Check your internet connection and try again'
                return $false
            }
            Start-Sleep -Seconds 1
        }
    }
    $ProgressPreference = 'Continue'

    if (-not (Test-Path $Dest) -or (Get-Item $Dest).Length -eq 0) {
        Write-Err 'Downloaded file is empty'
        return $false
    }
    return $true
}

function Install-Binary {
    # Detect architecture — only x64 supported
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    if ($arch -ne [System.Runtime.InteropServices.Architecture]::X64) {
        Write-Err "Unsupported architecture: $arch. Only x64 is supported."
        return $false
    }

    # Get latest release tag
    Write-Info 'Fetching latest release...'
    $ProgressPreference = 'SilentlyContinue'
    try {
        $release = Invoke-RestMethod -Uri $GithubApi -UseBasicParsing -ErrorAction Stop
        $tag = $release.tag_name
    } catch {
        Write-Err 'Could not fetch latest release from GitHub'
        return $false
    } finally {
        $ProgressPreference = 'Continue'
    }

    if ([string]::IsNullOrWhiteSpace($tag)) {
        Write-Err 'Could not determine latest release tag'
        return $false
    }

    $url = "$GithubBaseUrl/$tag/statusline-windows-x64.exe"
    Write-Info "Downloading statusline $tag for windows-x64..."

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    if (-not (Invoke-DownloadFile $url $TargetFile)) {
        return $false
    }

    Write-Success "Binary installed to $TargetFile"

    # Write statusline.toml defaults (skip if already exists)
    if (-not (Test-Path $TomlFile)) {
        $tomlContent = & $TargetFile '--print-defaults' 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tomlContent)) {
            Write-Err "Failed to generate $TomlFile"
            return $false
        }
        Set-Content -Path $TomlFile -Value $tomlContent -Encoding UTF8
        Write-Success "Created default config: $TomlFile"
    } else {
        Write-Info "Config already exists, skipping: $TomlFile"
    }

    return $true
}

function Install-DevBinary {
    $repoRoot = $PSScriptRoot
    $cargoManifest = Join-Path $repoRoot 'Cargo.toml'

    if (-not (Test-Path $cargoManifest)) {
        Write-Err 'Cargo.toml not found. Run -Dev from the repo root.'
        return $false
    }

    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        Write-Err 'cargo not found. Install Rust from https://rustup.rs'
        return $false
    }

    Write-Info 'Building debug binary...'
    & cargo build --manifest-path $cargoManifest
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'cargo build failed'
        return $false
    }

    $debugBin = Join-Path $repoRoot 'target\debug\statusline.exe'
    if (-not (Test-Path $debugBin)) {
        Write-Err "Built binary not found at $debugBin"
        return $false
    }

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    Copy-Item $debugBin $TargetFile -Force
    Write-Success "Dev binary installed to $TargetFile"

    if (-not (Test-Path $TomlFile)) {
        $tomlContent = & $TargetFile '--print-defaults' 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tomlContent)) {
            Write-Err "Failed to generate $TomlFile"
            return $false
        }
        Set-Content -Path $TomlFile -Value $tomlContent -Encoding UTF8
        Write-Success "Created default config: $TomlFile"
    } else {
        Write-Info "Config already exists, skipping: $TomlFile"
    }

    return $true
}

# ============================================================================
# Settings Functions
# ============================================================================

function Set-ClaudeSettings {
    if (-not (Test-Path $SettingsFile)) {
        Set-Content -Path $SettingsFile -Value '{}' -Encoding UTF8
        Write-Info 'Created new settings.json'
    }

    # Validate existing JSON
    & node -e "try{JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));process.exit(0)}catch(e){process.exit(1)}" $SettingsFile 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'Existing settings.json contains invalid JSON'
        Write-Info "Please fix $SettingsFile manually"
        return $false
    }

    $backup = "$SettingsFile.backup.$(Get-Timestamp)"
    Copy-Item $SettingsFile $backup -ErrorAction Stop
    Write-Info "Backed up settings: $backup"

    $tempFile = [System.IO.Path]::GetTempFileName()

    $nodeScript = @"
var fs = require('fs');
var src  = process.argv[1];
var cmd  = process.argv[2];
var dest = process.argv[3];
var settings = JSON.parse(fs.readFileSync(src, 'utf8'));
settings.statusLine = { type: 'command', command: cmd, padding: 0 };
fs.writeFileSync(dest, JSON.stringify(settings, null, 2) + '\n', 'utf8');
"@
    & node -e $nodeScript $SettingsFile $StatusLineCommand $tempFile 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'Failed to update configuration'
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $false
    }

    Move-Item $tempFile $SettingsFile -Force
    Write-Success 'Configured ~/.claude/settings.json'
    return $true
}

# ============================================================================
# Main
# ============================================================================

function Main {
    Write-Header

    if ($Dev) {
        if (-not (Install-DevBinary)) { Invoke-CleanupOnError }
        Write-Footer
        exit 0
    }

    $totalSteps  = 3
    $currentStep = 0

    $currentStep++
    Write-Step $currentStep $totalSteps 'Checking dependencies...'
    if (-not (Test-Dependencies)) { exit 1 }

    $currentStep++
    Write-Step $currentStep $totalSteps 'Downloading Rust binary...'
    if (-not (Install-Binary)) { Invoke-CleanupOnError }

    $currentStep++
    Write-Step $currentStep $totalSteps 'Configuring Claude Code...'
    if (-not (Set-ClaudeSettings)) {
        Write-Warn 'Installation succeeded, but automatic configuration failed'
        Write-Host ''
        Write-Host 'Please manually add to ~/.claude/settings.json:'
        Write-Host '   {'
        Write-Host '     "statusLine": {'
        Write-Host '       "type": "command",'
        Write-Host "       `"command`": `"$StatusLineCommand`","
        Write-Host '       "padding": 0'
        Write-Host '     }'
        Write-Host '   }'
        Write-Host ''
        exit 2
    }

    Write-Footer
    exit 0
}

Main
