# Claude Code Statusline

> Advanced statusline implementation for Claude Code CLI with comprehensive git integration, context visualization, and performance optimizations.

[![Platform Support](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL%20%7C%20MinGW-blue)](#platform-support)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## Overview

A sophisticated, cross-platform statusline for Claude Code that displays real-time contextual information including model details, context usage visualization, directory information, comprehensive git status, cost tracking, and code change metrics.

## Features

### Core Features
- 🚀 **Model Display**: Shows the current Claude model name with icon
- 🔥 **Context Visualization**: Visual progress bar showing context window usage with percentage
- 📂 **Directory Information**: Current working directory name
- 💵 **Cost Tracking**: Optional display of total cost in USD (when available)
- ✏️ **Lines Changed**: Optional display of lines added/removed (when available)

### Git Integration
- 🎋 **Branch Tracking**: Current branch name with color coding
- ↑↓ **Ahead/Behind Indicators**: Commits ahead/behind upstream (green ↑ / red ↓)
- 📊 **Change Detection**: Modified files count with line additions/deletions
- 🧹 **Clean State Detection**: Shows clean repository status
- ⚠️ **Repository Detection**: Graceful handling of non-git directories

### Platform Support
- **macOS**: Full emoji support
- **Linux**: Full emoji support
- **WSL**: Full emoji support with Windows integration
- **MinGW/MSYS/Cygwin**: Emoji support (requires modern terminal)

### Performance Optimizations
- ⚡ **Optimized Git Operations**: Reduced from 7 git calls to 2 using porcelain v2 format (~71% reduction)
- 🚀 **Efficient String Operations**: printf + tr for fast progress bar rendering
- 🎯 **Smart Caching**: Git version check cached across execution
- ⏱️ **Target**: < 100ms execution time for responsive UX

## Prerequisites

- **Bash** 3.2 or higher
- **jq** 1.5 or higher (JSON processor)
- **git** 2.11 or higher (required for porcelain v2 format)

### Installing Dependencies

**macOS:**
```bash
brew install jq git
```

**Ubuntu/Debian:**
```bash
sudo apt-get install jq git
```

**RHEL/CentOS/Fedora:**
```bash
sudo yum install jq git
```

**Windows (Git Bash):**
```bash
# jq typically included with Git for Windows
# Or download from: https://stedolan.github.io/jq/download/
```

## Installation

### Quick Install (Recommended)

Install with a single command using curl:

```bash
curl -fsSL https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/install.sh | bash
```

This will:
- ✅ Check dependencies (bash 3.2+, jq, git 2.11+)
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

### Manual Installation

```bash
# Download the script
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/statusline.sh

# Make it executable
chmod +x ~/.claude/statusline.sh
```

## Configuration

Configure Claude Code to use the custom statusline by editing your settings file:

1. **Open Claude Code settings:**
   ```bash
   nano ~/.claude/settings.json
   ```

2. **Add the statusLine configuration:**
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh",
       "padding": 0
     }
   }
   ```

3. **Configuration options:**
   - `type`: Must be `"command"`
   - `command`: Path to statusline script (can be absolute or use `~`)
   - `padding`: Set to `0` for edge-to-edge display, or positive integer for padding

4. **Restart Claude Code** for changes to take effect

## Screenshots

### Clean Git Repository
```
📂 statusline-sh | 🚀 Opus | 🔥 [████████░░░░░░░] 53% | 🎋 (main) | 💵 $0.15 | ✏️ +156/-23
```

### Dirty Repository with Changes
```
📂 project | 🚀 Haiku | 🔥 [███░░░░░░░░░░░░] 20% | 🎋 (feature-branch | 5 files +89 -12 | ↑2)
```

### Not a Git Repository
```
📂 tmp | 🚀 Sonnet | 🔥 [████████████░░░] 80% | 🎋 (not a git repository)
```

## Architecture

### Component-Based Design

The statusline follows a **component-based functional composition** architecture with clear separation of concerns:

```
Input (JSON) → Parse → Build Components → Assemble → Output (ANSI)
```

**Key Components:**
- **Platform Detection**: Identifies OS for icon selection
- **JSON Parser**: Extracts fields using jq
- **Git Information Gatherer**: Optimized git operations (porcelain v2)
- **Component Builders**: Independent builders for each statusline section
- **Assembly Layer**: Combines components with separators

### Performance Optimizations

| Optimization | Impact | Technique |
|--------------|--------|-----------|
| Git calls: 7→2 | ~71% reduction | Porcelain v2 format |
| Git version caching | Avoid repeated checks | Global variable cache |
| String operations | Faster rendering | printf + tr vs loops |
| Early returns | Skip unnecessary work | Guard clauses |
| Single JSON parse | Minimize jq calls | Parse once, extract multiple |

For detailed architecture documentation, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Testing

### Manual Testing

```bash
# Create test input
cat > test-input.json << 'EOF'
{
  "model": {"display_name": "Opus"},
  "workspace": {"current_dir": "/Users/test/project"},
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 50000,
      "cache_creation_input_tokens": 10000,
      "cache_read_input_tokens": 5000
    }
  },
  "cost": {
    "total_cost_usd": 0.15,
    "total_lines_added": 156,
    "total_lines_removed": 23
  }
}
EOF

# Run test
cat tests/fixtures/test-input.json | ./statusline.sh
```

### Automated Testing

```bash
# Run unit tests
./tests/unit.sh

# Run integration tests
./tests/integration.sh
```

## Documentation

- [README.md](README.md) - Quick start and overview
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Complete implementation guide
- [docs/REFERENCE.md](docs/REFERENCE.md) - Official statusline specification
- [docs/TESTING.md](docs/TESTING.md) - Testing guide
- [tests/README.md](tests/README.md) - How to run tests

## Contributing

Contributions are welcome! Here's how to get involved:

### Reporting Issues
- Check existing issues before creating new ones
- Include statusline output and error messages
- Specify your platform (OS, bash version, git version)

### Submitting Improvements
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Follow the existing code style
4. Test on multiple platforms if possible
5. Reference [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for architecture guidelines
6. Submit a pull request with clear description

### Code Style Guidelines
- Follow existing naming conventions
- Maintain single responsibility per function
- Use readonly for constants
- Add comments for complex logic
- Ensure POSIX compatibility where possible
- Test performance impact of changes

## Inspirations

This statusline was inspired by excellent implementations from:
- [Fatih Arslan](https://x.com/fatih/status/2003155214942241023)
- [Frank Dilo](https://x.com/frankdilo/status/2003383256205672753)

## License

MIT License - feel free to use, modify, and distribute.

## Related Resources

- [Claude Code Documentation](https://code.claude.com/docs)
- [Git Porcelain v2 Format](https://git-scm.com/docs/git-status#_porcelain_format_version_2)
- [jq Manual](https://jqlang.github.io/jq/manual/)
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)

---

**Version**: 1.0.0
**Last Updated**: 2026-01-13
**Maintained by**: [@glauberlima](https://github.com/glauberlima)
