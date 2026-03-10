# Claude Code Statusline

<p align="center">
  <img src="assets/statusline-logo.png" alt="Claude Code Statusline" width="300">
</p>

<p align="center">
  <strong>> Ridiculously simple. Surprisingly rich.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL%20%7C%20Windows-blue?style=for-the-badge" alt="Platform support" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="MIT License" />
  </a>
</p>

## 💡 What You Get

More context in Claude Code's statusline: directory, git status, file changes, model, context usage with progress bar, and cost — all visible at once.

<p align="center">
  <img src="assets/statusline-demo.png" alt="Claude Code Statusline Demo" width="100%">
</p>

Install with one command. Works immediately. Configure when you need it.

## ✨ Quick Install

**macOS / Linux / WSL**
```bash
curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.sh | bash
```

**Windows — PowerShell**
```powershell
irm https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.ps1 | iex
```

**Windows — CMD**
```cmd
curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.cmd -o install.cmd && install.cmd && del install.cmd
```

> **Windows requires [Git for Windows](https://git-scm.com/download/win).** Install it first if you don't have it.

## Manual Installation

Use this if you can't run the one-liner (corporate proxy, air-gapped environment, restricted shell).

### macOS / Linux / WSL

**1. Get the files**
```bash
git clone https://github.com/glauberlima/claude-code-statusline.git
cd claude-code-statusline
```

**2. Patch for language and features** _(optional — skip for English with messages/cost off)_
```bash
# English with messages enabled
./patch-statusline.sh statusline.sh messages/en.json

# Portuguese, no cost display
./patch-statusline.sh statusline.sh messages/pt.json --no-cost

# Disable messages entirely
./patch-statusline.sh statusline.sh --no-messages
```

**3. Copy to `~/.claude/`**
```bash
mkdir -p ~/.claude
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

**4. Add to `~/.claude/settings.json`**
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

<details>
<summary><strong>Windows (PowerShell)</strong></summary>

**1. Download the files** (run in PowerShell)
```powershell
$base = "https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main"
New-Item -ItemType Directory -Force statusline | Out-Null
Set-Location statusline
Invoke-WebRequest "$base/statusline.sh" -OutFile statusline.sh
Invoke-WebRequest "$base/patch-statusline.sh" -OutFile patch-statusline.sh
New-Item -ItemType Directory -Force messages | Out-Null
foreach ($lang in "en","pt","es") {
  Invoke-WebRequest "$base/messages/$lang.json" -OutFile "messages/$lang.json"
}
```

**2. Patch via Git Bash** _(optional — skip for English with messages/cost off)_
```bash
# Run these in Git Bash, not PowerShell
./patch-statusline.sh statusline.sh messages/en.json
```

**3. Copy to `%USERPROFILE%\.claude\`** (run in PowerShell)
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude" | Out-Null
Copy-Item statusline.sh "$env:USERPROFILE\.claude\statusline.sh"
```

**4. Add to `%USERPROFILE%\.claude\settings.json`**
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

</details>

## Features

- 📁 **Directory name**
- 🌿 **Git branch**
- ✏️ **File changes**
- 🤖 **Model name**
- 📊 **Context usage** with progress bar and funny messages
- 💰 **Cost tracking**

**Multi-language**: English, Brazilian Portuguese, Spanish

## ⚙️ Configuration

Re-run the installer to change language or toggle features. Use the same command for your platform as in Quick Install above.

## 🛠️ Development

### Testing

```bash
./tests/unit.sh && ./tests/integration.sh && ./tests/shellcheck.sh
```

ShellCheck reference: https://www.shellcheck.net/

### Contributing

1. Fork and create a feature branch
2. Make changes and run tests
3. Submit a pull request

See [CLAUDE.md](CLAUDE.md) for architecture details and development commands.

## Inspirations

- [Fatih Arslan](https://x.com/fatih/status/2003155214942241023)
- [Frank Dilo](https://x.com/frankdilo/status/2003383256205672753)

## License

[MIT License](LICENSE)
