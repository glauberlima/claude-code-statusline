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

**Requirements**: bash, jq, git (the installer checks and shows install commands if needed)

## Features

- 📁 **Directory name**
- 🌿 **Git branch**
- ✏️ **File changes**
- 🤖 **Model name**
- 📊 **Context usage** with progress bar and funny messages
- 💰 **Cost tracking**

**Multi-language**: English, Brazilian Portuguese, Spanish

## ⚙️ Configuration

### Installation Flow

```mermaid
flowchart TD
    A([▶ Start]) --> B["① Check Dependencies\nbash, curl, claude, node, git"]
    B --> C{"Local files\npresent?"}
    C -- Yes --> D["② Use local files\n(validate in place)"]
    C -- No --> E["② Download from GitHub\n(to temp directory)"]
    D --> F["③ Select Features"]
    E --> F
    F --> G{"Messages\nenabled?"}
    G -- Yes --> H["Select Language\n🇺🇸 EN | 🇧🇷 PT | 🇪🇸 ES"]
    G -- No --> I["④ Apply Patches\npatch-statusline.sh --flags"]
    H --> I
    I --> J["⑤ Install & Configure\ncopy → ~/.claude/statusline.sh\nupdate settings.json"]
    J --> K([✓ Done])

    style A fill:#2d8659,color:#fff
    style K fill:#2d8659,color:#fff
    style G fill:#d4a017,color:#000
    style C fill:#d4a017,color:#000
```

### Change Language or Toggle Components

**Option 1: Use the installer** (recommended for initial setup):

```bash
./install.sh
```

The installer lets you:
- Select language (🇺🇸 English | 🇧🇷 Português | 🇪🇸 Español)
- Enable/disable context messages
- Enable/disable cost display

**Option 2: Use the patch script** (for manual customization):

```bash
# Patch to Portuguese with all features
./patch-statusline.sh ~/.claude/statusline.sh messages/pt.json

# Disable messages
./patch-statusline.sh ~/.claude/statusline.sh --no-messages

# Spanish with cost tracking only
./patch-statusline.sh ~/.claude/statusline.sh messages/es.json --no-messages
```

The patch script creates a fully optimized, static version with zero runtime overhead. To change settings, re-run the patch.

### Add a Language

See [messages/README.md](messages/README.md) for translation guidelines.

## 🛠️ Development

### From Source

```bash
git clone https://github.com/glauberlima/claude-code-statusline.git
cd claude-code-statusline
./install.sh
```

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
