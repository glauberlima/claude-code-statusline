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
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.ps1'))) -InstallDir "C:\Custom\Path"
```

### Install a specific version

To install a specific release (e.g. for testing an unstable build):

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.sh | bash -s -- --version v1.1.0-dev.6f31b35
```

```powershell
# Windows — PowerShell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.ps1'))) -Version v1.1.0-dev.6f31b35
```

Both parameters can be combined:

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.sh | bash -s -- --install-dir /custom/path --version v1.1.0-dev.6f31b35
```

```powershell
# Windows — PowerShell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.ps1'))) -InstallDir "C:\Custom\Path" -Version v1.1.0-dev.6f31b35
```

Release tags are listed on the [GitHub releases page](https://github.com/glauberlima/claude-code-statusline/releases).

## Features

- 📁 **Directory name**
- 🌿 **Git branch**
- ✏️ **File changes**
- 🤖 **Model name**
- 📊 **Context usage** with progress bar and funny messages
- 💰 **Cost tracking**
- 🎨 **Color themes** (Dracula, Tokyo Night, One Dark, Solarized Dark, Phosphor)

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

Available options: `cost`, `messages`, `messages_language` (`en`/`pt`/`es`), `usage_bar_style` (`plain`/`rainbow`/`gradient`/`gsd`/`dracula`/`tokyo-night`/`one-dark`/`solarized-dark`/`phosphor`), `theme` (`default`/`dracula`/`tokyo-night`/`one-dark`/`solarized-dark`/`phosphor`).

### 🎨 Themes

`theme` recolors the directory, git branch, file changes, model, cost, and context (`plain` bar style only) segments using the official palette of the selected theme. The `rainbow` and `gsd` bar styles are unaffected by `theme` — they always use their own fixed colors. The `gradient` and per-theme bar styles below are also independent of `theme` — pick them via `usage_bar_style` regardless of which `theme` is active.

| Theme | Source palette |
|-------|----------------|
| `default` | Original 16-color ANSI (no theme applied) |
| `dracula` | [Dracula](https://draculatheme.com/) |
| `tokyo-night` | [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) |
| `one-dark` | [Atom One Dark](https://github.com/atom/atom/tree/master/packages/one-dark-ui) |
| `solarized-dark` | [Solarized Dark](https://ethanschoonover.com/solarized/) |
| `phosphor` | P1 phosphor CRT green (80s terminal) |

```toml
theme = "dracula"
```

### 📊 Themed progress bars

`usage_bar_style` also accepts each theme's name (`dracula`/`tokyo-night`/`one-dark`/`solarized-dark`/`phosphor`), rendering the progress bar as a gradient across that theme's 6 semantic colors — independent of whichever `theme` is currently active. For example, `theme = "default"` with `usage_bar_style = "phosphor"` keeps default colors everywhere except a phosphor-green progress bar.

```toml
usage_bar_style = "phosphor"
```

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
