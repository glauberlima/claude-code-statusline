# Claude Code Statusline

> Advanced statusline for Claude Code CLI with git integration and context visualization

![Claude Code Statusline Demo](statusline-demo.png)

<p align="center">
[![Platform Support](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL%20%7C%20MinGW-blue)](#platform-support)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
</p>

## Features

Shows at a glance:

- 📁 **Directory name**
- 🌿 **Git branch** (when in a Git repository)
- ✏️ **File changes** indicator (when present)
- 🤖 **Model name**
- 📊 **Context usage** (progress bar + percentage + funny messages)
- 💰 **Cost tracking** (when present)

## Prerequisites

- **macOS**: `brew install jq git`
- **Other platforms**: Install commands shown by install.sh if missing

## Installation

### Quick Install (Recommended)

Install with a single command using curl:

```bash
curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.sh | bash
```

This will:

- ✅ Check dependencies
- ✅ Download statusline.sh to `~/.claude/statusline.sh`
- ✅ Make it executable
- ✅ Backup any existing installation
- ✅ Show platform-specific install instructions for missing dependencies

### From Source (Local Development)

For local development:

```bash
# Clone the repository
git clone https://github.com/glauberlima/claude-code-statusline.git
cd claude-code-statusline

# Run the installer (copies statusline.sh to ~/.claude/statusline.sh)
./install.sh
```

After making changes to statusline.sh, run `./install.sh` again to update the installed version.

## Documentation

- [Official Statusline Spec](https://code.claude.com/docs/en/statusline) - Claude Code statusline documentation

## Contributing

Contributions welcome. Fork the repository, create a feature branch, test your changes, and submit a pull request. Follow existing code style and test on multiple platforms if possible.

## Inspirations

This statusline was inspired by excellent implementations from:

- [Fatih Arslan](https://x.com/fatih/status/2003155214942241023)
- [Frank Dilo](https://x.com/frankdilo/status/2003383256205672753)

## License

[MIT License](LICENSE) - feel free to use, modify, and distribute.

---
