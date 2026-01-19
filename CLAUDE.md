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
./tests/shellcheck.sh    # Static analysis (zero-tolerance, all checks enabled)

# Manual testing
cat tests/fixtures/test-input.json | ./statusline.sh
```

### Installation

```bash
./install.sh  # Copies statusline.sh to ~/.claude/statusline.sh (always copies, no symlink mode)
```

### Linting

```bash
shellcheck statusline.sh install.sh tests/*.sh  # Uses .shellcheckrc config
```

## Architecture

### Component-Based Flow

```
JSON Input → Parse (jq) → Build Components → Assemble → ANSI Output
```

**Key functional areas in statusline.sh**:

- **Configuration**: Colors (ANSI codes), icons (emoji), constants (bar width, separators)
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

### Integration Tests (tests/integration.sh)

Test complete statusline with JSON fixtures:

- Various git states (clean, dirty, not repo)
- Null values, edge cases
- Over-limit context usage

### Static Analysis (tests/shellcheck.sh)

Zero-tolerance policy:

- All 11 optional checks enabled (.shellcheckrc)
- Extended dataflow analysis
- External source checking

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

- Total execution: < 100ms
- Git operations: < 50ms
- JSON parsing: < 10ms

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

### Efficient String Operations

```bash
# Build progress bar with printf + tr (faster than loops)
printf "%${filled}s" | tr ' ' "${BAR_FILLED}"
```

### Conditional Display

```bash
# Use append_if() helper for optional components
append_if() {
  local value="$1"
  local text="$2"
  [[ "${value}" != "0" ]] 2>/dev/null && [[ -n "${value}" ]] && [[ "${value}" != "${NULL_VALUE}" ]] && echo -n " ${text}"
}
```

## File Locations

```
/
├── statusline.sh          # Main implementation (693 lines)
├── install.sh             # Installer script (always copies, no symlink mode)
├── README.md              # User-facing documentation
├── .shellcheckrc          # Linter config (all checks enabled)
├── .editorconfig          # Code style enforcement
├── .gitignore             # Excluded files (IDE tools, temp files)
└── tests/
    ├── unit.sh            # Component tests
    ├── integration.sh     # End-to-end tests
    ├── shellcheck.sh      # Static analysis
    └── fixtures/
        └── test-input.json # Sample JSON input
```

## Documentation

- **README.md**: User-facing installation and features
- **CLAUDE.md**: Project guidance for Claude Code (this file)

For statusline implementation details, refer to the official Claude Code statusline documentation:
https://code.claude.com/docs/en/statusline
