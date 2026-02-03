# install.ps1 - PowerShell installer for Claude Code statusline
# Compatible with PowerShell 5.1+ (Windows 10+)

#Requires -Version 5.1

# Strict mode for better error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ============================================================================
# Configuration
# ============================================================================
$TARGET_DIR = Join-Path $env:USERPROFILE ".claude"
$TARGET_FILE = Join-Path $TARGET_DIR "statusline.sh"
$SETTINGS_FILE = Join-Path $TARGET_DIR "settings.json"
$CONFIG_FILE = Join-Path $TARGET_DIR "statusline-config.json"
$GITHUB_BASE_URL = "https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main"
$MAX_DOWNLOAD_RETRIES = 3

# ============================================================================
# UI Functions (ANSI colors for PowerShell 5.1+)
# ============================================================================

function Write-Header {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        Claude Code Statusline - Installer        ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Footer {
    param(
        [string]$Mode,
        [string]$Language
    )
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Installation Complete!              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Installed: $TARGET_FILE"
    Write-Host "Mode: $Mode"
    Write-Host "Language: $Language"
    Write-Host ""
    Write-Host "Next step: " -NoNewline -ForegroundColor Cyan
    Write-Host "Restart Claude Code to see your new statusline"
    Write-Host ""
    Write-Host "To update, run the installation command again."
    Write-Host ""
}

function Write-StepProgress {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Message
    )
    Write-Host ""
    Write-Host "[$Current/$Total] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "→ $Message" -ForegroundColor Cyan
}

# ============================================================================
# Dependency Checking
# ============================================================================

function Test-Dependencies {
    $missing = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $missing += "PowerShell 5.1+"
    }

    # Check for Git Bash (required to run statusline.sh)
    $gitBashPaths = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:ProgramFiles\Git\usr\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
    )

    $gitBashFound = $false
    foreach ($path in $gitBashPaths) {
        if (Test-Path $path) {
            $gitBashFound = $true
            break
        }
    }

    if (-not $gitBashFound) {
        $missing += "Git Bash"
    }

    # Check for git command
    try {
        $null = Get-Command git -ErrorAction Stop
    } catch {
        $missing += "git"
    }

    if ($missing.Count -gt 0) {
        Write-ErrorMsg "Missing dependencies: $($missing -join ', ')"
        Write-Host ""
        Write-Host "Please install the following:" -ForegroundColor Cyan
        Write-Host ""

        if ($missing -contains "Git Bash" -or $missing -contains "git") {
            Write-Host "  Git for Windows (includes Git Bash):"
            Write-Host "    https://git-scm.com/download/win"
            Write-Host ""
        }

        if ($missing -contains "PowerShell 5.1+") {
            Write-Host "  PowerShell 5.1+ (included in Windows 10+)"
            Write-Host "    Update Windows or install PowerShell 7+"
            Write-Host ""
        }

        Write-Host "Installation aborted."
        exit 1
    }

    # Show detected versions
    Write-Success "PowerShell $($PSVersionTable.PSVersion)"
    Write-Success "Git Bash found"

    try {
        $gitVersion = (git --version 2>$null) -replace 'git version ', ''
        Write-Success "git $gitVersion"
    } catch {
        Write-Success "git (version unknown)"
    }
}

# ============================================================================
# Download Functions
# ============================================================================

function Get-FileWithRetry {
    param(
        [string]$Url,
        [string]$Destination
    )

    for ($attempt = 1; $attempt -le $MAX_DOWNLOAD_RETRIES; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
            return $true
        } catch {
            if ($attempt -lt $MAX_DOWNLOAD_RETRIES) {
                Start-Sleep -Seconds 1
            }
        }
    }

    return $false
}

function Test-BashScript {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return $false
    }

    $firstLine = Get-Content $FilePath -First 1 -ErrorAction SilentlyContinue
    if ($firstLine -notmatch '^#!/.*bash') {
        return $false
    }

    $content = Get-Content $FilePath -Raw
    if ($content -notmatch 'assemble_statusline') {
        return $false
    }

    return $true
}

# ============================================================================
# Installation Functions
# ============================================================================

function Install-Statusline {
    param([string]$SourceFile)

    # Create target directory if it doesn't exist
    if (-not (Test-Path $TARGET_DIR)) {
        New-Item -ItemType Directory -Path $TARGET_DIR -Force | Out-Null
    }

    # Backup existing file
    if (Test-Path $TARGET_FILE) {
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $backupFile = "$TARGET_FILE.backup.$timestamp"
        Move-Item -Path $TARGET_FILE -Destination $backupFile -Force
        Write-Info "Backed up existing: $backupFile"
    }

    # Copy file
    Copy-Item -Path $SourceFile -Destination $TARGET_FILE -Force

    Write-Success "Installation complete"
}

function Update-SettingsJson {
    # Use forward slashes for cross-platform compatibility
    $commandPath = ($TARGET_FILE -replace '\\', '/') -replace '^C:', '$HOME'

    # Create or load settings.json
    if (Test-Path $SETTINGS_FILE) {
        try {
            $settings = Get-Content $SETTINGS_FILE -Raw | ConvertFrom-Json
        } catch {
            Write-ErrorMsg "Existing settings.json contains invalid JSON"
            return $false
        }

        # Backup existing settings
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $backupFile = "$SETTINGS_FILE.backup.$timestamp"
        Copy-Item -Path $SETTINGS_FILE -Destination $backupFile -Force
        Write-Info "Backed up settings: $backupFile"
    } else {
        $settings = @{}
        Write-Info "Created new settings.json"
    }

    # Update statusLine configuration
    $settings | Add-Member -NotePropertyName statusLine -NotePropertyValue @{
        type = "command"
        command = $commandPath
        padding = 0
    } -Force

    # Save settings
    try {
        $settings | ConvertTo-Json -Depth 10 | Set-Content $SETTINGS_FILE -Force
        Write-Success "Configured $SETTINGS_FILE"
        return $true
    } catch {
        Write-ErrorMsg "Failed to write settings.json"
        return $false
    }
}

function Install-LanguageFiles {
    param(
        [string]$Mode,
        [string]$SourceDir = "."
    )

    $messagesDir = Join-Path $TARGET_DIR "messages"

    # Create messages directory
    if (-not (Test-Path $messagesDir)) {
        New-Item -ItemType Directory -Path $messagesDir -Force | Out-Null
    }

    if ($Mode -eq "local") {
        # Local installation
        $sourceMessagesDir = Join-Path $SourceDir "messages"

        if (-not (Test-Path $sourceMessagesDir)) {
            Write-Warn "messages directory not found in $SourceDir"
            return $false
        }

        # Copy JSON files
        $jsonFiles = Get-ChildItem -Path $sourceMessagesDir -Filter "*.json"
        if ($jsonFiles.Count -eq 0) {
            Write-Warn "No JSON message files found"
            return $false
        }

        foreach ($file in $jsonFiles) {
            Copy-Item -Path $file.FullName -Destination $messagesDir -Force
        }

        Write-Success "Language files installed"
        return $true
    } else {
        # Remote installation
        $languages = @("en", "pt", "es")
        $failed = 0

        foreach ($lang in $languages) {
            $langUrl = "$GITHUB_BASE_URL/messages/$lang.json"
            $langFile = Join-Path $messagesDir "$lang.json"

            if (-not (Get-FileWithRetry -Url $langUrl -Destination $langFile)) {
                Write-Warn "Failed to download $lang.json"
                $failed++
                continue
            }

            # Validate JSON
            try {
                $null = Get-Content $langFile -Raw | ConvertFrom-Json
            } catch {
                Write-Warn "$lang.json has invalid format"
                Remove-Item $langFile -Force
                $failed++
                continue
            }
        }

        # Check for default language
        $defaultLangFile = Join-Path $messagesDir "en.json"
        if (-not (Test-Path $defaultLangFile)) {
            Write-ErrorMsg "Failed to install default language file (en.json)"
            return $false
        }

        if ($failed -eq 0) {
            Write-Success "Language files installed"
        } else {
            Write-Success "Language files installed (some files skipped)"
        }

        return $true
    }
}

function Show-LanguagePrompt {
    $languages = @(
        @{ Code = "en"; Name = "English" },
        @{ Code = "pt"; Name = "Português" },
        @{ Code = "es"; Name = "Español" }
    )

    Write-Host ""
    Write-Host "Select statusline language:" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $languages.Count; $i++) {
        $num = $i + 1
        Write-Host "  $num) $($languages[$i].Name) ($($languages[$i].Code))"
    }

    Write-Host ""
    $selection = Read-Host "Enter selection [1]"

    if ([string]::IsNullOrWhiteSpace($selection)) {
        $selection = "1"
    }

    $index = [int]$selection - 1
    if ($index -ge 0 -and $index -lt $languages.Count) {
        return $languages[$index].Code
    }

    return "en"
}

function Show-ComponentPrompt {
    Write-Host ""
    Write-Host "Select components to display:" -ForegroundColor Cyan
    Write-Host "(Enter numbers to toggle, empty = show all)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  1) [X] Context messages (funny messages)"
    Write-Host "  2) [X] Cost display (💰)"
    Write-Host ""

    $input = Read-Host "Toggle (default: show all)"

    if ([string]::IsNullOrWhiteSpace($input)) {
        return "messages cost"
    }

    # Parse toggles
    $showMessages = $true
    $showCost = $true

    $numbers = $input -split '\s+' | Where-Object { $_ -match '^\d+$' }
    foreach ($num in $numbers) {
        switch ($num) {
            "1" { $showMessages = -not $showMessages }
            "2" { $showCost = -not $showCost }
        }
    }

    $result = @()
    if ($showMessages) { $result += "messages" }
    if ($showCost) { $result += "cost" }

    return $result -join " "
}

function Save-UserConfig {
    param(
        [string]$Language,
        [string]$Components
    )

    $showMessages = $Components -like "*messages*"
    $showCost = $Components -like "*cost*"

    $config = @{
        language = $Language
        show_messages = $showMessages
        show_cost = $showCost
    }

    try {
        $config | ConvertTo-Json | Set-Content $CONFIG_FILE -Force
        Write-Success "Configuration saved: lang=$Language, messages=$showMessages, cost=$showCost"
        return $true
    } catch {
        Write-ErrorMsg "Failed to save configuration"
        return $false
    }
}

# ============================================================================
# Main Installation Flow
# ============================================================================

function Main {
    $sourceFile = $null
    $installMode = $null

    Write-Header

    # Step 1: Check Dependencies
    Write-StepProgress -Current 1 -Total 5 -Message "Checking dependencies..."
    Test-Dependencies

    # Step 2: Acquire Statusline
    Write-StepProgress -Current 2 -Total 5 -Message "Acquiring statusline..."

    if (Test-Path ".\statusline.sh") {
        $installMode = "local"
        Write-Info "Using local statusline.sh from current directory"

        $sourceFile = Resolve-Path ".\statusline.sh"

        if (-not (Test-BashScript -FilePath $sourceFile)) {
            Write-ErrorMsg "Local statusline.sh failed validation"
            exit 1
        }

        Write-Success "Local file validated"
    } else {
        $installMode = "remote"
        Write-Info "Downloading from GitHub"

        $tempFile = [System.IO.Path]::GetTempFileName()
        $statuslineUrl = "$GITHUB_BASE_URL/statusline.sh"

        if (-not (Get-FileWithRetry -Url $statuslineUrl -Destination $tempFile)) {
            Write-ErrorMsg "Failed to download statusline.sh"
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            exit 1
        }

        Write-Success "Downloaded successfully"

        if (-not (Test-BashScript -FilePath $tempFile)) {
            Write-ErrorMsg "Downloaded file failed validation"
            Remove-Item $tempFile -Force
            exit 1
        }

        Write-Success "File validated"
        $sourceFile = $tempFile
    }

    # Step 3: Install to ~/.claude
    Write-StepProgress -Current 3 -Total 5 -Message "Installing to ~/.claude..."
    Install-Statusline -SourceFile $sourceFile

    # Clean up temp file if remote
    if ($installMode -eq "remote" -and (Test-Path $sourceFile)) {
        Remove-Item $sourceFile -Force -ErrorAction SilentlyContinue
    }

    # Step 4: Configure Settings
    Write-StepProgress -Current 4 -Total 5 -Message "Configuring settings..."
    if (-not (Update-SettingsJson)) {
        Write-Host ""
        Write-Warn "Installation succeeded, but automatic configuration failed"
        Write-Host ""
        Write-Host "Please manually add to $SETTINGS_FILE :"
        Write-Host '   {'
        Write-Host '     "statusLine": {'
        Write-Host '       "type": "command",'
        Write-Host "       `"command`": `"$($TARGET_FILE -replace '\\', '/')`","
        Write-Host '       "padding": 0'
        Write-Host '     }'
        Write-Host '   }'
        Write-Host ""
        exit 2
    }

    # Step 5: Install Languages
    Write-StepProgress -Current 5 -Total 5 -Message "Installing languages..."

    if (-not (Install-LanguageFiles -Mode $installMode)) {
        Write-Warn "Language files installation failed"
        Write-Host "  → Statusline will use default language (English)"
    }

    # Prompt for language and components
    $language = Show-LanguagePrompt
    $components = Show-ComponentPrompt

    # Save configuration
    if (-not (Save-UserConfig -Language $language -Components $components)) {
        Write-Warn "Configuration failed"
        Write-Host "  → Statusline will use default settings"
    }

    Write-Footer -Mode $installMode -Language $language
}

# ============================================================================
# Entry Point
# ============================================================================

try {
    Main
} catch {
    Write-Host ""
    Write-ErrorMsg "Installation failed: $_"
    Write-Host ""
    Write-Host $_.ScriptStackTrace
    exit 1
}
