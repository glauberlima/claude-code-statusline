#Requires -Version 5.1
<#
.SYNOPSIS
    Installer for Claude Code Statusline (Windows)

.DESCRIPTION
    Acquires files (local or remote), patches with user preferences,
    and installs statusline.sh + settings.json to $HOME\.claude\.

.EXAMPLE
    # Remote (PowerShell pipe install)
    irm https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main/install.ps1 | iex

    # Local (from repo directory)
    .\install.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# Configuration
# ============================================================================

$TargetDir          = Join-Path $HOME '.claude'
$TargetFile         = Join-Path $HOME '.claude\statusline.sh'
$SettingsFile       = Join-Path $HOME '.claude\settings.json'
$GithubBaseUrl      = 'https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main'
$MaxDownloadRetries = 3

# Mutable globals (global: scope so engine-event cleanup handler can see $TempDir)
$global:TempDir = $null
$WorkingDir     = $null
$InstallMode    = 'local'
$BashExePath    = $null

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
    param(
        [string]$Mode,
        [string]$Language = 'en',
        [string]$Components = 'messages cost'
    )
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════╗'
    Write-Host '║              Installation Complete!              ║'
    Write-Host '╚══════════════════════════════════════════════════╝'
    Write-Host ''
    Write-Host "Installed: $TargetFile"
    Write-Host "Mode: $Mode"
    if ($Components -like '*messages*') {
        Write-Host "Language: $Language"
    }
    Write-Host ''
    Write-Host -NoNewline 'Next step: '
    Write-Host -ForegroundColor Cyan 'Restart Claude Code to see your new statusline'
    Write-Host ''
    Write-Host 'To update, run the installation command again.'
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
function Write-Muted   { param([string]$Message); Write-Host -ForegroundColor DarkGray $Message }

# ============================================================================
# Utility Functions
# ============================================================================

function Test-IsPiped {
    return [Console]::IsInputRedirected
}

function Get-Timestamp {
    return [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
}

function ConvertTo-BashPath {
    param([string]$WinPath)
    $p = $WinPath.Replace('\', '/')
    if ($p -match '^([A-Za-z]):(.*)') {
        return '/' + $Matches[1].ToLower() + $Matches[2]
    }
    return $p
}

function Invoke-Cleanup {
    if ($null -ne $global:TempDir -and (Test-Path $global:TempDir)) {
        Remove-Item -Recurse -Force $global:TempDir -ErrorAction SilentlyContinue
    }
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

function Get-BashExePath {
    # 1. bash on PATH (preferred — respects user's own setup)
    $cmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # 2. Known Git Bash locations
    $candidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:ProgramFiles\Git\usr\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\usr\bin\bash.exe"
    )
    # 32-bit fallback (rare, but cover it)
    $x86 = ${env:ProgramFiles(x86)}
    if ($x86) { $candidates += "$x86\Git\bin\bash.exe" }

    return $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Test-GitVersion {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) { return $false }

    $versionStr = & git --version 2>$null
    if ($versionStr -match '(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        return ($major -gt 2) -or ($major -eq 2 -and $minor -ge 11)
    }
    return $false
}

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

    $script:BashExePath = Get-BashExePath
    if (-not $BashExePath) { $missing += 'bash (Git Bash)' }

    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { $missing += 'claude' }
    if (-not (Get-Command node   -ErrorAction SilentlyContinue)) { $missing += 'node' }
    if (-not (Test-GitVersion))                                   { $missing += 'git 2.11+' }

    if ($missing.Count -gt 0) {
        Show-InstallInstructions $missing
        return $false
    }

    Write-Success "bash  $(Get-ToolVersion $BashExePath)"
    Write-Success "claude $(Get-ToolVersion claude)"
    Write-Success "node   $(Get-ToolVersion node)"
    Write-Success "git    $(Get-ToolVersion git)"
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

    if ($Missing -contains 'bash (Git Bash)') {
        Write-Host -ForegroundColor Cyan 'Git Bash (required to run bash scripts on Windows):'
        Write-Host '  https://git-scm.com/download/win'
        Write-Host '  winget install --id Git.Git'
        Write-Host ''
    }

    if ($Missing -contains 'node') {
        Write-Host -ForegroundColor Cyan 'Node.js:'
        Write-Host '  https://nodejs.org/'
        Write-Host '  winget install --id OpenJS.NodeJS'
        Write-Host ''
    }

    if ($Missing -contains 'git 2.11+') {
        Write-Host -ForegroundColor Cyan 'Git 2.11+:'
        Write-Host '  https://git-scm.com/download/win'
        Write-Host '  winget install --id Git.Git'
        Write-Host ''
    }

    Write-Host 'Installation aborted. Install dependencies and try again.'
}

# ============================================================================
# Acquisition Functions
# ============================================================================

function Invoke-DownloadFile {
    param([string]$Url, [string]$Dest)

    for ($attempt = 1; $attempt -le $MaxDownloadRetries; $attempt++) {
        try {
            $ProgressPreference = 'SilentlyContinue'  # suppress verbose progress bar
            Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -ErrorAction Stop
            $ProgressPreference = 'Continue'
            break
        } catch {
            if ($attempt -ge $MaxDownloadRetries) {
                Write-Err "Failed to download from $Url"
                Write-Info 'Check your internet connection and try again'
                return $false
            }
            Start-Sleep -Seconds 1
        }
    }

    if (-not (Test-Path $Dest) -or (Get-Item $Dest).Length -eq 0) {
        Write-Err 'Downloaded file is empty'
        return $false
    }
    return $true
}

function Test-StatuslineFile {
    param([string]$File)

    if (-not (Test-Path $File) -or (Get-Item $File).Length -eq 0) {
        Write-Err 'File does not exist or is empty'
        return $false
    }

    $firstLine = Get-Content $File -First 1 -ErrorAction SilentlyContinue
    if ($firstLine -notmatch '^#!/.*bash') {
        Write-Err 'Invalid file format (missing bash shebang)'
        return $false
    }

    $content = Get-Content $File -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch 'assemble_statusline') {
        Write-Err 'File does not appear to be statusline.sh'
        return $false
    }

    return $true
}

function Get-Files {
    $localStatusline = Join-Path $PWD 'statusline.sh'
    $localPatch      = Join-Path $PWD 'patch-statusline.sh'
    $localMessages   = Join-Path $PWD 'messages'

    if ((Test-Path $localStatusline) -and (Test-Path $localPatch) -and (Test-Path $localMessages -PathType Container)) {
        $script:InstallMode = 'local'
        $script:WorkingDir  = $PWD.Path
        Write-Info 'Using local files from current directory'

        if (-not (Test-StatuslineFile $localStatusline)) { return $false }
        Write-Success 'Local files validated'
        return $true
    }

    # Remote mode
    $script:InstallMode = 'remote'
    Write-Info 'Downloading files from GitHub...'

    $tmpBase = [System.IO.Path]::GetTempPath()
    $global:TempDir    = Join-Path $tmpBase "statusline_$(Get-Timestamp)"
    $script:WorkingDir = $global:TempDir

    New-Item -ItemType Directory -Path $global:TempDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $global:TempDir 'messages') -Force | Out-Null

    if (-not (Invoke-DownloadFile "$GithubBaseUrl/statusline.sh"       (Join-Path $global:TempDir 'statusline.sh')))      { return $false }
    if (-not (Invoke-DownloadFile "$GithubBaseUrl/patch-statusline.sh" (Join-Path $global:TempDir 'patch-statusline.sh'))) { return $false }

    foreach ($lang in @('en', 'pt', 'es')) {
        $dest = Join-Path $global:TempDir "messages\$lang.json"
        if (-not (Invoke-DownloadFile "$GithubBaseUrl/messages/$lang.json" $dest)) {
            Write-Warn "Failed to download messages/$lang.json"
        }
    }

    if (-not (Test-StatuslineFile (Join-Path $global:TempDir 'statusline.sh'))) { return $false }
    Write-Success 'Files downloaded and validated'
    return $true
}

# ============================================================================
# Preference Functions
# ============================================================================

function Get-ComponentSelection {
    if (Test-IsPiped) { return 'messages cost' }

    Write-Host ''
    Write-Host -ForegroundColor Cyan 'Select features:'
    Write-Host ''
    Write-Host '  1) All features (messages + cost)'
    Write-Host '  2) Messages only'
    Write-Host '  3) Cost only'
    Write-Host '  4) Minimal (no messages, no cost)'
    Write-Host ''
    $selection = Read-Host 'Enter selection [1]'
    if ([string]::IsNullOrWhiteSpace($selection)) { $selection = '1' }

    switch ($selection) {
        '1' { return 'messages cost' }
        '2' { return 'messages' }
        '3' { return 'cost' }
        '4' { return '' }
        default { return 'messages cost' }
    }
}

function Get-LanguageSelection {
    if (Test-IsPiped) { return 'en' }

    $langs = @('en', 'pt', 'es')
    $names = @('English', 'Português', 'Español')

    Write-Host ''
    Write-Host -ForegroundColor Cyan 'Select statusline language:'
    Write-Host ''
    for ($i = 0; $i -lt $langs.Count; $i++) {
        Write-Host "  $($i + 1)) $($names[$i]) ($($langs[$i]))"
    }
    Write-Host ''
    $selection = Read-Host 'Enter selection [1]'
    if ([string]::IsNullOrWhiteSpace($selection)) { $selection = '1' }

    $idx = ([int]$selection) - 1
    if ($idx -ge 0 -and $idx -lt $langs.Count) {
        return $langs[$idx]
    }
    return 'en'
}

# ============================================================================
# Patching Functions
# ============================================================================

function Invoke-Patches {
    param(
        [string]$WorkDir,
        [string]$Language,
        [string]$Components
    )

    $patchScript   = Join-Path $WorkDir 'patch-statusline.sh'
    $statuslineFile = Join-Path $WorkDir 'statusline.sh'
    $langJson       = Join-Path $WorkDir "messages\$Language.json"

    # Convert Windows paths to POSIX for bash
    $bashPatchScript    = ConvertTo-BashPath $patchScript
    $bashStatuslineFile = ConvertTo-BashPath $statuslineFile
    $bashLangJson       = ConvertTo-BashPath $langJson

    # Only include the lang JSON arg when messages are enabled — patch-statusline.sh
    # expects --no-messages as the third positional arg, not as arg[4]
    $patchArgs = @($bashPatchScript, $bashStatuslineFile)
    if ($Components -like '*messages*') { $patchArgs += $bashLangJson }
    if ($Components -notlike '*messages*') { $patchArgs += '--no-messages' }
    if ($Components -notlike '*cost*')     { $patchArgs += '--no-cost' }

    & $BashExePath $patchArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'Patching failed'
        return $false
    }
    return $true
}

# ============================================================================
# Installation Functions
# ============================================================================

function Install-Statusline {
    param([string]$Source)

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    # Refuse to install if target dir is itself a symlink (security)
    $dirItem = Get-Item $TargetDir -ErrorAction SilentlyContinue
    if ($dirItem -and $dirItem.LinkType) {
        Write-Err "$TargetDir is a symbolic link (security risk)"
        return $false
    }

    $backup = $null
    if (Test-Path $TargetFile) {
        $backup = "$TargetFile.backup.$(Get-Timestamp)"
        Move-Item $TargetFile $backup -ErrorAction Stop
        Write-Info "Backed up existing: $backup"
    }

    try {
        Copy-Item $Source $TargetFile -ErrorAction Stop
    } catch {
        Write-Err "Failed to copy file: $_"
        if ($backup -and (Test-Path $backup)) { Move-Item $backup $TargetFile -Force }
        return $false
    }

    return $true
}

function Set-ClaudeSettings {
    param([string]$BashExe)

    # The command Claude Code executes: full path to bash + script path.
    # Quote the bash path to handle "Program Files" and similar paths with spaces.
    $statusLineCommand = "`"$BashExe`" ~/.claude/statusline.sh"

    if (-not (Test-Path $SettingsFile)) {
        Set-Content -Path $SettingsFile -Value '{}' -Encoding UTF8
        Write-Info 'Created new settings.json'
    }

    # Validate existing JSON
    $validJson = & node -e "try{JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));process.exit(0)}catch(e){process.exit(1)}" $SettingsFile 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'Existing settings.json contains invalid JSON'
        Write-Info "Please fix $SettingsFile manually"
        return $false
    }

    $backup = "$SettingsFile.backup.$(Get-Timestamp)"
    Copy-Item $SettingsFile $backup -ErrorAction Stop
    Write-Info "Backed up settings: $backup"

    $tempFile = [System.IO.Path]::GetTempFileName()

    # Use node inline to merge statusLine key, preserving all other settings
    $nodeScript = @"
var fs = require('fs');
var src  = process.argv[1];
var cmd  = process.argv[2];
var dest = process.argv[3];
var settings = JSON.parse(fs.readFileSync(src, 'utf8'));
settings.statusLine = { type: 'command', command: cmd, padding: 0 };
fs.writeFileSync(dest, JSON.stringify(settings, null, 2) + '\n', 'utf8');
"@
    & node -e $nodeScript $SettingsFile $statusLineCommand $tempFile 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'Failed to update configuration'
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $false
    }

    # Validate generated JSON before overwriting
    & node -e "try{JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));process.exit(0)}catch(e){process.exit(1)}" $tempFile 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'Generated invalid JSON'
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $false
    }

    Move-Item $tempFile $SettingsFile -Force
    Write-Success 'Configured ~/.claude/settings.json'
    return $true
}

# ============================================================================
# Main Installation Flow
# ============================================================================

function Main {
    $selectedLanguage   = 'en'
    $selectedComponents = 'messages cost'
    $totalSteps         = 5
    $currentStep        = 0

    # Register cleanup on unexpected exit
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Invoke-Cleanup } | Out-Null

    Write-Header

    # Step 1: Check Dependencies
    $currentStep++
    Write-Step $currentStep $totalSteps 'Checking dependencies...'
    if (-not (Test-Dependencies)) { exit 1 }

    # Step 2: Acquire Files
    $currentStep++
    Write-Step $currentStep $totalSteps 'Acquiring files...'
    if (-not (Get-Files)) { Invoke-CleanupOnError }

    # Step 3: Configure Preferences
    $currentStep++
    Write-Step $currentStep $totalSteps 'Configuring preferences...'
    $selectedComponents = Get-ComponentSelection
    if ($selectedComponents -like '*messages*') {
        $selectedLanguage = Get-LanguageSelection
    }
    $componentDisplay = if ($selectedComponents) { $selectedComponents } else { 'none' }
    Write-Success "Language: $selectedLanguage, Components: $componentDisplay"

    # Step 4: Apply Patches
    $currentStep++
    Write-Step $currentStep $totalSteps 'Applying patches...'
    if (-not (Invoke-Patches $WorkingDir $selectedLanguage $selectedComponents)) {
        Invoke-CleanupOnError
    }
    Write-Success 'Patched successfully'

    # Step 5: Install & Configure
    $currentStep++
    Write-Step $currentStep $totalSteps 'Installing to ~/.claude...'
    $statuslineSrc = Join-Path $WorkingDir 'statusline.sh'
    if (-not (Install-Statusline $statuslineSrc)) { Invoke-CleanupOnError }
    Write-Success "Installed to $TargetFile"

    if (-not (Set-ClaudeSettings $BashExePath)) {
        Write-Warn 'Installation succeeded, but automatic configuration failed'
        Write-Host ''
        Write-Host 'Please manually add to ~/.claude/settings.json:'
        Write-Host '   {'
        Write-Host '     "statusLine": {'
        Write-Host '       "type": "command",'
        Write-Host "       `"command`": `"`"$BashExePath`" ~/.claude/statusline.sh`","
        Write-Host '       "padding": 0'
        Write-Host '     }'
        Write-Host '   }'
        Write-Host ''
        Invoke-Cleanup
        exit 2
    }

    Invoke-Cleanup
    Write-Footer $InstallMode $selectedLanguage $selectedComponents
    exit 0
}

Main
