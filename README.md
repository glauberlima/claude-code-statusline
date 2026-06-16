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
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.ps1)))
```

### Custom install directory

Override where the binary and config are installed (default: `~/.claude`):

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.sh | bash -s -- --install-dir /custom/path
```

```powershell
# Windows — PowerShell
& ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.ps1'))) -InstallDir "C:\custom"
```

### Install a specific version

To install a specific release (e.g. for testing an unstable build), set `VERSION` before running:

```bash
# macOS / Linux / WSL
VERSION=v1.1.0-dev.6f31b35 curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.sh | bash
```

```powershell
# Windows — PowerShell
$env:VERSION="v1.1.0-dev.6f31b35"; iex (irm 'https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.ps1')
```

Release tags are listed on the [GitHub releases page](https://github.com/glauberlima/claude-code-statusline/releases).

## 📥 Direct Downloads

Pre-built binaries are published with every release. These URLs always point to the latest version:

| Platform | URL |
|----------|-----|
| macOS (universal) | [`statusline-macos`](https://github.com/glauberlima/claude-code-statusline/releases/latest/download/statusline-macos) |
| Linux x64 | [`statusline-linux-x64`](https://github.com/glauberlima/claude-code-statusline/releases/latest/download/statusline-linux-x64) |
| Windows x64 | [`statusline-windows-x64.exe`](https://github.com/glauberlima/claude-code-statusline/releases/latest/download/statusline-windows-x64.exe) |

The install scripts above use these URLs automatically.

## Features

- 📁 **Directory name**
- 🌿 **Git branch**
- ✏️ **File changes**
- 🤖 **Model name**
- 📊 **Context usage** with progress bar and funny messages
- 💰 **Cost tracking**

## ⚙️ Configuration

Edit `~/.claude/statusline.toml` to customize features. Generate the default config:

**macOS / Linux / WSL**
```bash
~/.claude/statusline --print-defaults > ~/.claude/statusline.toml
```

**Windows — PowerShell**
```powershell
& "$env:USERPROFILE\.claude\statusline.exe" --print-defaults | Set-Content "$env:USERPROFILE\.claude\statusline.toml"
```

Available options: `cost`, `messages`, `messages_language` (`en`/`pt`/`es`), `usage_bar_style` (`plain`/`rainbow`/`gradient`).

## 🛠️ Development

### Testing

```bash
cargo test
```

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
