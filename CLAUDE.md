# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bash-based statusline for Claude Code CLI displaying (in order):

- Directory (📁)
- Git branch (🌿) when in a Git repository
- File changes (✏️) when present
- Model name (🤖)
- Context usage visualization with progress bar and funny messages (📊)
- Cost tracking (💰) when present

**Primary file**: `statusline.sh`
**Language**: Bash 3.2+ with POSIX compatibility considerations

## Development Commands

### Testing

```bash
# Run all tests
./tests/unit.sh && ./tests/integration.sh && ./tests/shellcheck.sh

# Individual test suites
./tests/unit.sh          # Component-level tests (< 1s)
./tests/integration.sh   # End-to-end tests with JSON fixtures
./tests/shellcheck.sh    # Bash syntax (bash -n) + static analysis (zero-tolerance, all checks enabled)

# Manual testing
cat tests/fixtures/test-input.json | ./statusline.sh
```

### Installation

```bash
./install.sh  # Copies statusline.sh to ~/.claude/statusline.sh (always copies, no symlink mode)
```

### Linting

```bash
# Automated (recommended - includes bash -n syntax check)
./tests/shellcheck.sh

# Manual shellcheck only
shellcheck statusline.sh install.sh tests/*.sh  # Uses .shellcheckrc config
```

## Architecture

### Component-Based Flow

```
JSON Input → Parse (jq) → Load i18n → Build Components → Assemble → ANSI Output
```

**Key functional areas in statusline.sh**:

- **Configuration**: Colors (ANSI codes), icons (emoji), constants (bar width, separators)
- **i18n**: Language loading (`load_config()`, `load_language_messages()`)
- **Utilities**: Directory name extraction (`get_dirname`), separator formatting (`sep`), path validation (`validate_directory`)
- **Core logic**: JSON parsing (`parse_claude_input`), git operations (`get_git_info`), progress bar rendering (`build_progress_bar`)
- **Formatters**: Transform raw data to display format (`format_ahead_behind`, `format_git_info`)
- **Component builders**: Individual statusline segments (`build_model_component`, `build_context_component`, `build_directory_component`, `build_git_component`, `build_files_component`, `build_cost_component`)
- **Assembly**: Combine components with separators (`assemble_statusline`)
- **Orchestration**: Main entry point and dependency checks (`main`)

### Design Patterns Applied

- **Single Responsibility**: Each function has one purpose (parse, format, build, assemble)
- **Open/Closed**: Add components without modifying existing code
- **DRY**: Reusable helpers (`append_if()`, `format_ahead_behind()`, `sep()`)
- **Functional Composition**: Functions pipe data through transformation stages

### Critical Performance Optimization

**Git operations: 1 call for all status data**:

- `git status --porcelain=v2 --branch --untracked-files=all` - Provides branch, upstream, ahead/behind, file status in single call

This porcelain v2 format requires **git 2.11+** (Dec 2016).

**Why**: Reduces subprocess overhead by ~85% compared to naive approach (7 separate git calls).

### Security Features

**Path validation**:

- `validate_directory()`: Prevents path traversal attacks, format string injection
- Validates against patterns: `..`, format specifiers, null bytes
- **Allows absolute paths** (commit 6696e50) based on real-world usage
- All user-controlled inputs (workspace.current_dir) validated before use

**Recent security hardening** (commit b8deee6):

- Added input sanitization for directory paths
- Prevents malicious JSON from exploiting shell operations

### State Management

**Git state constants**:

- `STATE_NOT_REPO`: Not a git repository
- `STATE_CLEAN`: No modified files
- `STATE_DIRTY`: Has modified files

## Internationalization (i18n)

### Architecture

The statusline uses a **static patching system** for zero-runtime overhead:

```
statusline.sh (English default)
        ↓
patch-statusline.sh + messages/pt.json
        ↓
statusline.sh (Portuguese, fully static)
```

**Key points**:
- Messages hardcoded in `statusline.sh` via `@MESSAGES_START` / `@MESSAGES_END` markers
- Configuration flags (`SHOW_MESSAGES`, `SHOW_COST`) hardcoded via `@CONFIG_START` / `@CONFIG_END` markers
- `patch-statusline.sh` script replaces marker blocks to create optimized versions
- **Zero runtime overhead** - no config loading, no JSON parsing during execution

### Language Files Structure

Each language file (`messages/{lang}.json`) uses a simplified format:

```json
{
  "very_low": ["message1", "message2", ...],
  "low": ["message1", "message2", ...],
  "medium": ["message1", "message2", ...],
  "high": ["message1", "message2", ...],
  "critical": ["message1", "message2", ...]
}
```

**Message Counts**:
- `very_low`: 0-20% context usage (~22 messages)
- `low`: 21-40% context usage (~22 messages)
- `medium`: 41-60% context usage (~23 messages)
- `high`: 61-80% context usage (~24 messages)
- `critical`: 81-100% context usage (~28 messages)

**Supported Languages**:
- English (en) - Default
- Portuguese (pt) - Brazilian Portuguese with cultural adaptation
- Spanish (es) - Spanish

### Patching System

**`patch-statusline.sh`** - Build-time patching tool:

```bash
# Patch to Portuguese
./patch-statusline.sh statusline.sh messages/pt.json

# Disable messages
./patch-statusline.sh statusline.sh --no-messages

# Disable both messages and cost
./patch-statusline.sh statusline.sh --no-messages --no-cost
```

**How it works**:
1. Reads JSON messages with `jq`
2. Uses `jq @sh` for safe shell escaping
3. Replaces `@CONFIG_START` block with new flags
4. Replaces `@MESSAGES_START` block with bash arrays
5. Validates output with `bash -n`
6. Writes in-place

**Performance**: Eliminates 3-5ms runtime overhead (from ~100ms to ~95ms).

### Key Functions

**`get_context_message()`** (statusline.sh):
- Selects random message from appropriate tier
- Uses bash arrays (not pipe-delimited strings)
- Reads from hardcoded `CONTEXT_MSG_*` arrays
- Performance: <1ms (array access)

**`build_context_component()`** (statusline.sh):
- Reads global `SHOW_MESSAGES` constant
- Shows/hides messages based on flag
- No parameters for configuration

**`build_cost_component()`** (statusline.sh):
- Reads global `SHOW_COST` constant
- Early return if disabled

### Translation Guidelines

- **Tone progression**: Calm → Critical (matches usage tiers)
- **Message length**: 2-5 words (terminal display constraint)
- **Cultural adaptation**: Adapt memes/references (e.g., PT: "tá tranquilo, tá favorável")
- **Array size flexibility**: ±3 messages per tier acceptable

See `messages/README.md` for complete translation guidelines.

### Adding a New Language

1. Create `messages/de.json` (copy from `messages/en.json`)
2. Translate all messages in tier arrays
3. Validate: `jq empty messages/de.json`
4. Test patch: `./patch-statusline.sh statusline.sh messages/de.json`
5. Update installers to include "de" in available languages
6. Run tests: `./tests/unit.sh && ./tests/integration.sh && ./tests/shellcheck.sh`
7. Update this documentation

## Code Style Guidelines

### Naming Conventions

- Functions: `snake_case` (e.g., `build_model_component`, `format_git_info`)
- Constants: `SCREAMING_SNAKE_CASE` with `readonly` (e.g., `BAR_WIDTH=15`)
- Local variables: `snake_case` with `local` declaration

### Formatting (enforced by .editorconfig)

- Indent: 2 spaces (shell scripts)
- Line endings: LF (Unix)
- Charset: UTF-8
- Insert final newline
- Trim trailing whitespace

### Bash Best Practices

- Always use `local` for function variables
- Use `readonly` for constants (cannot be modified)
- Quote all variable expansions: `"${variable}"`
- Use `[[` instead of `[` for conditionals (bash-specific, more robust)
- Error handling: `set -euo pipefail` (exit on error, undefined vars, pipe failures)
- Null handling pattern: `[[ "${value}" != "0" ]] 2>/dev/null && [[ -n "${value}" ]] && [[ "${value}" != "${NULL_VALUE}" ]]`

## Adding New Components

Follow Open/Closed Principle - extend without modifying existing code:

1. **Create builder function**:

   Add a new builder function near the existing component builders (`build_model_component`, `build_context_component`, etc.):

   ```bash
   build_new_component() {
     local data="$1"
     echo "🆕 ${CYAN}${data}${NC}"
   }
   ```

2. **Call in main() function**:

   Extract data and build the component:

   ```bash
   new_part=$(build_new_component "${data}")
   ```

3. **Update assemble_statusline() call**:

   Pass the new component to the assembly function:

   ```bash
   assemble_statusline "$model_part" "$context_part" "$dir_part" "$git_part" "$files_part" "$cost_part" "$new_part"
   ```

4. **Modify assemble_statusline() signature**:

   Update the function to accept the new parameter and incorporate it into the output

   **Note**: The function parameters are passed in the order shown above, but the actual output order is: dir | git | files | model | context | cost (as defined in the assembly function).

## Parsing JSON Input

Claude Code sends JSON via stdin. Parse once, extract all fields using the `parse_claude_input()` function:

```bash
parsed=$(echo "${input}" | jq -r '
  .model.display_name,
  .workspace.current_dir,
  (.context_window.context_window_size // 200000),
  (.cost.total_cost_usd // 0)
')
```

Use jq's `//` operator for null defaults. Single jq call for efficiency.

## Git Operations

**Always use porcelain v2 format** via the `get_git_info()` function:

- Check repo: `git rev-parse --is-inside-work-tree`
- Get all info: `git status --porcelain=v2 --branch --untracked-files=all`
- Parse structured output (lines starting with `# branch.`)

**Single git call** provides branch, upstream, ahead/behind, and file status. No separate diff command needed for file counts.

## Testing Strategy

### Unit Tests (tests/unit.sh)

Test individual functions in isolation:

- Number formatting (`format_number()`)
- Context messages (`get_context_message()`)
- Progress bar rendering
- **Language file validation**:
  - Each language file defines all 5 required tiers
  - Each tier has minimum 15 messages
  - Files are valid JSON
- **Color randomization** (`get_random_message_color()`)

### Integration Tests (tests/integration.sh)

Test complete statusline with JSON fixtures:

- Various git states (clean, dirty, not repo)
- Null values, edge cases
- Over-limit context usage
- **Language configuration**:
  - Statusline works with each language (en, pt, es)
  - Fallback to default language when config missing
  - Invalid language code handling
- **Security validation**:
  - Path traversal prevention
  - Format string injection prevention

### Static Analysis (tests/shellcheck.sh)

Two-phase validation with zero-tolerance policy:

1. **Bash syntax validation** (`bash -n`):
   - Verifies syntax correctness before execution
   - Catches parse errors early
   - Tests all .sh files

2. **Shellcheck static analysis**:
   - All 11 optional checks enabled (.shellcheckrc)
   - Extended dataflow analysis
   - External source checking
   - Validates all bash scripts

## Dependencies

Required:

- **bash** 3.2+ (macOS default, widely available)
- **jq** 1.5+ (JSON processor)
- **git** 2.11+ (for porcelain v2 format)

Install:

```bash
# macOS
brew install jq git

# Ubuntu/Debian
apt-get install jq git

# RHEL/CentOS/Fedora
yum install jq git
```

## Performance Targets

- Total execution: < 95ms (improved from ~100ms)
- Git operations: < 50ms
- JSON parsing: < 10ms
- **i18n overhead: 0ms** (fully static, no runtime loading)

**Performance improvement**:
- Eliminated 3-5ms runtime overhead through static patching
- Messages hardcoded as bash arrays (direct access)
- No config file reading or JSON parsing at runtime

If slow, check:

1. Git repo size (large repos increase operation time)
2. Number of modified files (affects status parsing)
3. jq query complexity (keep single parse)

## Common Patterns

### Color Usage

```bash
readonly RED='\033[0;31m'
readonly NC='\033[0m'  # No Color (reset)

echo "${RED}text${NC}"  # Always reset after color
```

**Color constants** (top of statusline.sh):

- `CYAN`: Model name, primary info
- `BLUE`: Directory
- `MAGENTA`: Git branch
- `GREEN`: Additions, ahead commits
- `RED`: Deletions, behind commits
- `ORANGE`: Warnings
- `GRAY`: Separators, secondary text

**Icon constants**:

- `MODEL_ICON`: 🤖 (model)
- `CONTEXT_ICON`: 📊 (context usage)
- `DIR_ICON`: 📁 (directory)
- `GIT_ICON`: 🌿 (git branch)
- `CHANGE_ICON`: ✏️ (file changes)
- Cost: 💰 (hardcoded in `build_cost_component()`)

### UTF-8 Character Handling

The progress bar uses pure bash string concatenation to handle multibyte UTF-8 characters:

```bash
# Build progress bar with UTF-8 safe method
for ((i=0; i<filled; i++)); do
  filled_bar+="${BAR_FILLED}"
done
```

**Characters**: `BAR_FILLED="█"` (filled block, U+2588) and `BAR_EMPTY="░"` (light shade, U+2591). These are hardcoded constants and cannot be customized.

**Why not sed/awk**: While `sed` and `awk` handle UTF-8 correctly, they spawn subprocesses (78-93x slower).

**Why not tr**: The `tr` command operates on bytes, not characters, breaking UTF-8 encoding:
- `tr ' ' '█'` produces: `e2e2e2...` (broken)
- Bash loop produces: `e29688e29688...` (correct)

**Performance**: Pure bash loops are 78x faster than `sed` for this operation (5ms vs 392ms per 100 iterations).

### Conditional Display

```bash
# Use append_if() helper for optional components
append_if() {
  local value="$1"
  local text="$2"
  [[ "${value}" != "0" ]] 2>/dev/null && [[ -n "${value}" ]] && [[ "${value}" != "${NULL_VALUE}" ]] && echo -n " ${text}"
}
```

## Fallback Mechanisms

The codebase contains several fallback mechanisms for robustness and compatibility:

### Language Configuration
- **Default**: English messages hardcoded in `statusline.sh`
- **Customization**: Use `patch-statusline.sh` with desired language JSON
- **No runtime fallback**: Language is statically compiled into the script

Strategy: User explicitly chooses language via patching. No dynamic loading or fallback needed.

### JSON Parsing (statusline.sh)
Uses jq's `//` operator for null-safe defaults:
- `context_window_size`: 200000
- Token counts: 0
- Cost: 0

Strategy: Sensible defaults when Claude Code doesn't provide values.

### Git State Defaults (statusline.sh)
- `branch`: "(detached HEAD)"
- `ahead`/`behind`: 0

Strategy: Display useful fallback text for unusual git states.

### Platform Detection (install.sh)
- **Primary**: `uname -s` output (Darwin, Linux)
- **Fallback**: "Unknown" if command fails
- **Package manager chain**: apt-get → yum → dnf → generic

Strategy: Best-effort platform detection with graceful unknown handling.

### Timestamp Generation (install.sh)
- **Primary**: `date +%s%N` (nanosecond precision, Linux)
- **Fallback**: `date +%s.$$` (seconds + PID, macOS/BSD)

Strategy: High precision when available, uniqueness when not.

### Removed Fallbacks

**Progress bar characters** (removed in current version):
- Previously allowed override via `~/.claude/statusline-config.sh`
- Now uses hardcoded Unicode constants: `BAR_FILLED="█"` and `BAR_EMPTY="░"`
- Rationale: Simplification - modern terminals universally support these characters

## File Locations

```
/
├── statusline.sh          # Main implementation (~650 lines, includes hardcoded English)
├── patch-statusline.sh    # Build-time patching tool
├── install.sh             # Unix installer script
├── install.ps1            # Windows PowerShell installer
├── README.md              # User-facing documentation
├── .shellcheckrc          # Linter config (all checks enabled)
├── .editorconfig          # Code style enforcement
├── .gitignore             # Excluded files (IDE tools, temp files)
├── docs/
│   └── plans/             # Design documents
│       └── 2026-02-04-static-message-patching-design.md
├── messages/              # i18n message files (simplified JSON format)
│   ├── en.json            # English messages
│   ├── pt.json            # Portuguese (Brazilian) messages
│   ├── es.json            # Spanish messages
│   └── README.md          # Translation guidelines
└── tests/
    ├── unit.sh            # Component tests (76 tests)
    ├── integration.sh     # End-to-end tests (24 tests)
    ├── shellcheck.sh      # Static analysis
    └── fixtures/
        └── test-input.json # Sample JSON input

After installation (~/.claude/):
└── statusline.sh           # Deployed script (patched with user's language/config)
```

## Documentation

- **README.md**: User-facing installation and features
- **CLAUDE.md**: Project guidance for Claude Code (this file)

For statusline implementation details, refer to the official Claude Code statusline documentation:
https://code.claude.com/docs/en/statusline
