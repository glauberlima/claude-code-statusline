# Claude Code Statusline

<p align="center">
  <img src="assets/statusline-logo.png" alt="Claude Code Statusline" width="300">
</p>

<p align="center">
  <strong>> Ridiculously simple. Surprisingly rich.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL%20%7C%20MinGW-blue?style=for-the-badge" alt="Platform support" />
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

```bash
curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.sh | bash
```

## Features

- 📁 **Directory name**
- 🌿 **Git branch**
- ✏️ **File changes**
- 🤖 **Model name**
- 📊 **Context usage** with progress bar and funny messages
- 💰 **Cost tracking**

**Multi-language**: English, Brazilian Portuguese, Spanish

## ⚙️ Configuration

Re-run the installer to change language or toggle features:

```bash
./install.sh
```

## 🛠️ Development

### Testing

```bash
./tests/unit.sh && ./tests/integration.sh && ./tests/shellcheck.sh
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
