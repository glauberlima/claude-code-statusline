# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bash-based statusline for Claude Code CLI displaying:
- Model name, context usage visualization with progress bar
- Git status (branch, ahead/behind, file changes)
- Directory, optional cost tracking and line changes

**Primary file**: `statusline.sh` (438 lines)
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
./install.sh  # Creates symlink to ~/.claude/statusline.sh
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

**Key sections in statusline.sh**:
- Lines 7-33: Configuration (colors, icons, constants)
- Lines 65-104: Utilities (dirname, separators, git version cache)
- Lines 110-214: Core (JSON parsing, git operations)
- Lines 220-290: Formatters (transform raw data to display format)
- Lines 296-365: Component builders (model, context, directory, git, cost, lines)
- Lines 371-387: Assembly (combine components with separators)
- Lines 393-438: Main orchestration

### Design Patterns Applied
- **Single Responsibility**: Each function has one purpose (parse, format, build, assemble)
- **Open/Closed**: Add components without modifying existing code
- **DRY**: Reusable helpers (`append_if()`, `format_ahead_behind()`, `sep()`)
- **Functional Composition**: Functions pipe data through transformation stages

### Critical Performance Optimization
**Git operations reduced from 7 calls to 2**:
1. `git status --porcelain=v2 --branch` - Provides branch, upstream, ahead/behind, file status
2. `git diff HEAD --numstat` - Line additions/deletions

This porcelain v2 format requires **git 2.11+** (Dec 2016).

### State Management
Git states (statusline.sh:59-61):
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

### Function Structure Template
```bash
function_name() {
  local param1="$1"
  local param2="$2"
  
  # Input validation / early returns
  [[ condition ]] && return
  
  # Core logic
  local result
  result=$(computation)
  
  # Output
  echo "${result}"
}
```

## Adding New Components

Follow Open/Closed Principle - extend without modifying existing code:

1. **Create builder function** (add to lines ~296-365):
   ```bash
   build_new_component() {
     local data="$1"
     echo "🆕 ${CYAN}${data}${NC}"
   }
   ```

2. **Call in main()** (around line ~426):
   ```bash
   new_part=$(build_new_component "${data}")
   ```

3. **Update assembly** (around line ~435):
   ```bash
   assemble_statusline "$model_part" "$context_part" "$dir_part" "$git_part" "$cost_part" "$lines_part" "$new_part"
   ```

4. **Modify assemble_statusline()** to accept new parameter (around line ~371)

## Parsing JSON Input

Claude Code sends JSON via stdin. Parse once, extract all fields (statusline.sh:110-132):

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

**Always use porcelain v2 format** (statusline.sh:148-214):
- Check repo: `git rev-parse --is-inside-work-tree`
- Get all info: `git status --porcelain=v2 --branch --untracked-files=all`
- Parse structured output (lines starting with `# branch.`)
- Line changes: `git diff HEAD --numstat`

**Cache git version check** using global variables (statusline.sh:80-104):
```bash
[[ -n "${GIT_VERSION_CHECKED:-}" ]] && return "${GIT_VERSION_OK:-1}"
```

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
1. Git repo size (large repos increase diff time)
2. Number of modified files (affects status parsing)
3. jq query complexity (keep single parse)

## Common Patterns

### Color Usage
```bash
readonly RED='\033[0;31m'
readonly NC='\033[0m'  # No Color (reset)

echo "${RED}text${NC}"  # Always reset after color
```

Colors defined in statusline.sh:26-33:
- `CYAN`: Model name, primary info
- `BLUE`: Directory
- `MAGENTA`: Git branch
- `GREEN`: Additions, ahead commits
- `RED`: Deletions, behind commits
- `ORANGE`: Warnings
- `GRAY`: Separators, secondary text

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
├── statusline.sh          # Main implementation (438 lines)
├── install.sh             # Installer script
├── .shellcheckrc          # Linter config (all checks enabled)
├── .editorconfig          # Code style enforcement
├── docs/
│   ├── ARCHITECTURE.md    # Complete implementation guide
│   ├── REFERENCE.md       # Official statusline spec
│   └── TESTING.md         # Testing guide
└── tests/
    ├── unit.sh            # Component tests
    ├── integration.sh     # End-to-end tests
    ├── shellcheck.sh      # Static analysis
    ├── README.md          # Quick testing guide
    └── fixtures/
        └── test-input.json # Sample JSON input
```

## Documentation

- **README.md**: User-facing installation and features
- **docs/ARCHITECTURE.md**: Complete implementation guide (448 lines)
- **docs/REFERENCE.md**: Official Claude Code statusline specification
- **docs/TESTING.md**: Comprehensive testing guide
- **tests/README.md**: Quick testing reference

When modifying core functionality, update docs/ARCHITECTURE.md to reflect changes.
