# Statusline.sh - Architecture & Implementation Guide

> Advanced statusline implementation for Claude Code CLI
> Version: 1.0.0
> Last updated: 2026-01-13

## Documentation Index

- [README](../README.md) - Quick start and overview
- [REFERENCE](REFERENCE.md) - Official statusline specification
- [TESTING](TESTING.md) - Testing guide
- [Tests](../tests/README.md) - Running tests

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Codebase Structure](#codebase-structure)
- [Design Patterns](#design-patterns)
- [Key Implementation Details](#key-implementation-details)
- [Performance Optimizations](#performance-optimizations)
- [Extension Guide](#extension-guide)
- [Testing](#testing)
- [Maintenance](#maintenance)

---

## Project Overview

### Purpose
A sophisticated, cross-platform statusline implementation for Claude Code that displays real-time contextual information including model details, context usage visualization, directory information, git status, cost tracking, and code change metrics.

### Technology Stack
- **Language**: Bash (with POSIX compatibility considerations)
- **Required Dependencies**:
  - `jq` - JSON parsing
  - `git` 2.11+ - Git operations (porcelain v2 format)
- **Supported Platforms**:
  - macOS (Darwin)
  - Linux
  - WSL (Windows Subsystem for Linux)
  - MinGW/MSYS/Cygwin

### Architecture Philosophy
Component-based functional composition with SOLID principles, emphasizing:
- **Separation of Concerns**: Distinct layers for parsing, building, formatting, and assembly
- **Performance**: Optimized git operations (7 calls → 2 calls)
- **Maintainability**: Clear function boundaries, DRY principles
- **Extensibility**: Easy to add new components without modifying existing code

---

## Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        Claude Code                               │
│                    (JSON via stdin)                              │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    1. PARSE & EXTRACT                            │
│  parse_claude_input() - Extract fields with jq                  │
│  → model_name, current_dir, context_size, usage, cost, etc.     │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    2. BUILD COMPONENTS                           │
│  ┌─────────────────┬──────────────┬────────────────┐           │
│  │ build_model_    │ build_       │ build_         │           │
│  │ component()     │ context_     │ directory_     │ ...       │
│  │                 │ component()  │ component()    │           │
│  └─────────────────┴──────────────┴────────────────┘           │
│                                                                  │
│  Each component builder:                                        │
│  - Receives extracted data                                      │
│  - Formats with colors/icons                                    │
│  - Returns formatted string                                     │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│               3. GIT OPERATIONS (Special Case)                   │
│  get_git_info() - Optimized git data gathering                  │
│  → format_git_info() - Transform git data to display format     │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    4. ASSEMBLE & OUTPUT                          │
│  assemble_statusline() - Combine components with separators     │
│  → Output to stdout with ANSI colors                            │
└─────────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Responsibility | Functions |
|-------|----------------|-----------|
| **Configuration** | Define constants for display (colors, icons, sizes) | Constants section |
| **Utilities** | Reusable helper functions | `get_dirname()`, `sep()`, `append_if()`, `check_git_version()` |
| **Parsing** | Extract data from JSON input | `parse_claude_input()` |
| **Data Gathering** | Collect git information | `get_git_info()` |
| **Formatting** | Transform raw data to display format | `format_*()` functions |
| **Component Building** | Create individual status components | `build_*_component()` functions |
| **Assembly** | Combine components into final output | `assemble_statusline()` |
| **Orchestration** | Coordinate all operations | `main()` |

---

## Codebase Structure

### File Organization (statusline.sh - 438 lines)

```
statusline.sh
│
├── Shebang & Shell Options (lines 1-2)
│   └── Bash with error handling (set -euo pipefail)
│
├── CONFIGURATION (lines 7-33)
│   ├── Display Constants (lines 22-33)
│   │   ├── BAR_WIDTH=15
│   │   ├── BAR_FILLED/EMPTY characters
│   │   └── Color definitions (RED, GREEN, BLUE, etc.)
│   │
│   ├── Derived Constants (lines 21-22)
│   │   ├── SEPARATOR with color
│   │   └── NULL_VALUE="null"
│   │
│   ├── Icons (lines 24-28)
│   │   └── Unicode emojis (🚀, 🔥, 📂, 🎋)
│   │
│   └── Git State Constants (lines 30-32)
│       ├── STATE_NOT_REPO
│       ├── STATE_CLEAN
│       └── STATE_DIRTY
│
├── UTILITY FUNCTIONS (lines 65-104)
│   ├── get_dirname() - Extract basename from path
│   ├── sep() - Output separator with color
│   ├── append_if() - Conditional append helper (DRY pattern)
│   └── check_git_version() - Verify git 2.11+ with caching
│
├── CORE FUNCTIONS (lines 110-214)
│   ├── parse_claude_input() - lines 110-132
│   │   └── Parse JSON with jq, extract 7 fields
│   │
│   ├── build_progress_bar() - lines 134-142
│   │   └── Create visual bar based on percentage
│   │
│   └── get_git_info() - lines 148-214
│       ├── Check if git repo
│       ├── Single git status --porcelain=v2 call
│       ├── Parse branch, upstream, ahead/behind
│       ├── Count modified files
│       └── Single git diff HEAD for line changes
│
├── FORMATTING FUNCTIONS (lines 220-290)
│   ├── format_ahead_behind() - lines 220-229
│   │   └── Format ↑ahead ↓behind indicators
│   │
│   ├── format_git_not_repo() - lines 231-233
│   │   └── Display "not a git repository" message
│   │
│   ├── format_git_clean() - lines 235-245
│   │   └── Format clean repo: (branch | ahead/behind)
│   │
│   ├── format_git_dirty() - lines 247-260
│   │   └── Format dirty repo: (branch | files +added -removed | ahead/behind)
│   │
│   └── format_git_info() - lines 262-290
│       └── Route to appropriate formatter based on state
│
├── COMPONENT BUILDERS (lines 296-365)
│   ├── build_model_component() - lines 296-299
│   │   └── 🚀 ModelName
│   │
│   ├── build_context_component() - lines 301-313
│   │   └── 🔥 [████████░░░░░░░] 53%
│   │
│   ├── build_directory_component() - lines 315-326
│   │   └── 📂 directory-name
│   │
│   ├── build_git_component() - lines 328-346
│   │   └── 🎋 (branch | files +added -removed | ↑ahead ↓behind)
│   │
│   ├── build_cost_component() - lines 348-354
│   │   └── 💵 $0.15 (optional)
│   │
│   └── build_lines_component() - lines 356-365
│       └── ✏️  +156/-23 (optional)
│
├── ASSEMBLY (lines 371-387)
│   └── assemble_statusline() - Combine all components with separators
│
└── MAIN (lines 393-438)
    └── main() - Orchestrate: dependency check → read stdin → parse → build → output
```

### Detailed Function Map

#### Critical Path Functions

1. **main() [393-438]**
   - Entry point
   - Checks for jq dependency
   - Reads stdin
   - Calls parse → build components → assemble → output

2. **parse_claude_input() [110-132]**
   - Input: Raw JSON string from Claude Code
   - Processing: jq extracts 7 fields
   - Output: Newline-separated values
   - Error handling: Returns 1 on parse failure

3. **get_git_info() [148-214]**
   - Input: current_dir path
   - Processing:
     - Check if git repo (early return if not)
     - Single `git status --porcelain=v2` call
     - Parse branch, upstream, ahead/behind from porcelain output
     - Count modified files
     - Single `git diff HEAD` for line stats
   - Output: Pipe-delimited string with state and data

4. **assemble_statusline() [371-387]**
   - Input: All component strings
   - Processing: Concatenate with separators
   - Output: Final formatted string with ANSI codes

#### Helper Functions

| Function | Lines | Purpose | Returns |
|----------|-------|---------|---------|
| `get_dirname()` | 66 | Extract basename | Directory name |
| `sep()` | 67 | Output separator | Gray pipe separator |
| `append_if()` | 70-76 | Conditional append | Text or empty |
| `check_git_version()` | 80-104 | Verify git 2.11+ | 0 (ok) or 1 (fail) |
| `build_progress_bar()` | 134-142 | Visual bar | Filled/empty chars |

#### Formatting Functions

| Function | Lines | Input | Output |
|----------|-------|-------|--------|
| `format_ahead_behind()` | 220-229 | ahead, behind counts | "↑N ↓N" or empty |
| `format_git_not_repo()` | 231-233 | None | Warning message |
| `format_git_clean()` | 235-245 | branch, ahead, behind | Clean repo display |
| `format_git_dirty()` | 247-260 | branch, files, ±lines, ahead/behind | Dirty repo display |
| `format_git_info()` | 262-290 | git_data string | Formatted git display |

---

## Design Patterns

### 1. Single Responsibility Principle (SRP)

Each function has one clear, well-defined purpose:

```bash
# ❌ BAD: Function does too much
build_and_display_git() {
  # Gets git info, formats it, AND assembles with other components
}

# ✅ GOOD: Separate concerns
get_git_info()        # Gather data
format_git_info()     # Transform data
build_git_component() # Build component
assemble_statusline() # Combine components
```

**Application in codebase:**
- `get_git_info()` only gathers data (no formatting)
- `format_git_*()` only formats (no data gathering)
- `build_*_component()` only builds component strings
- `assemble_statusline()` only combines components

### 2. Open/Closed Principle (OCP)

Open for extension, closed for modification:

```bash
# Adding a new component doesn't require modifying existing components
# Just add a new builder and update assembly

build_new_component() {
  local data="$1"
  echo "🆕 ${data}"
}

# In main(), add:
new_part=$(build_new_component "$data")

# In assemble, extend:
assemble_statusline "$model_part" "$context_part" "$dir_part" "$git_part" "$cost_part" "$lines_part" "$new_part"
```

**Application in codebase:**
- Component builders are independent (lines 296-365)
- Adding new components doesn't break existing ones
- `assemble_statusline()` accepts variable components

### 3. DRY (Don't Repeat Yourself)

Eliminate code duplication:

```bash
# Reusable helper for conditional display
append_if() {
  local value="$1"
  local text="$2"
  if [ "$value" != "0" ] 2>/dev/null && [ -n "$value" ] && [ "$value" != "$NULL_VALUE" ]; then
    echo -n " $text"
  fi
}

# Used in multiple places
output+=$(append_if "$added" "${GREEN}+${added}${NC}")
output+=$(append_if "$removed" "${RED}-${removed}${NC}")
```

**Application in codebase:**
- `append_if()` helper (line 70-76)
- `format_ahead_behind()` reused in clean and dirty formatters
- `sep()` function for consistent separators

### 4. KISS (Keep It Simple, Stupid)

Simple, straightforward code:

```bash
# Simple orchestration - no clever tricks
main() {
  # Check dependencies
  command -v jq >/dev/null 2>&1 || { echo "Error: jq required" >&2; exit 1; }

  # Read input
  input=$(cat) || { echo "Error: Failed to read stdin" >&2; exit 1; }

  # Parse
  parsed=$(parse_claude_input "$input") || exit 1

  # Extract and build
  # ... build components ...

  # Assemble and output
  assemble_statusline "$model_part" "$context_part" ...
}
```

**Application in codebase:**
- `main()` is straightforward orchestration (no complex logic)
- Clear data flow: read → parse → build → assemble → output
- No unnecessary abstractions

### 5. Functional Composition

Functions are composed together:

```
Input Data
    ↓
parse_claude_input()
    ↓
build_*_component()  ← get_git_info() + format_git_info()
    ↓
assemble_statusline()
    ↓
Output Display
```

---

## Key Implementation Details

### 1. JSON Parsing Strategy

**Location**: Lines 110-132

```bash
parse_claude_input() {
  local input="$1"

  local parsed
  parsed=$(echo "$input" | jq -r '
    .model.display_name,
    .workspace.current_dir,
    (.context_window.context_window_size // 200000),
    (
      (.context_window.current_usage.input_tokens // 0) +
      (.context_window.current_usage.cache_creation_input_tokens // 0) +
      (.context_window.current_usage.cache_read_input_tokens // 0)
    ),
    (.cost.total_cost_usd // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0)
  ' 2>/dev/null) || {
    echo "Error: Failed to parse JSON input" >&2
    return 1
  }

  echo "$parsed"
}
```

**Why jq instead of pure bash?**
- Robust: Handles complex JSON reliably
- Safe: Proper null handling with `//` operator
- Maintainable: Clear field extraction
- Standard: jq is widely available

**Null handling**: Uses jq's `//` (alternative operator) for defaults

### 2. Git Operations Optimization

**Location**: Lines 148-214

**Before optimization**: 7 separate git calls
1. `git rev-parse --is-inside-work-tree`
2. `git branch --show-current`
3. `git rev-parse --abbrev-ref @{upstream}`
4. `git rev-list --count @{upstream}..HEAD` (ahead)
5. `git rev-list --count HEAD..@{upstream}` (behind)
6. `git diff --cached --numstat` (staged)
7. `git diff --numstat` (unstaged)

**After optimization**: 2 git calls
1. `git status --porcelain=v2 --branch --untracked-files=all`
2. `git diff HEAD --numstat`

**Porcelain v2 Format Benefits**:
```
# branch.head main
# branch.upstream origin/main
# branch.ab +2 -1
1 .M N... 100644 100644 100644 abc123 def456 file.txt
```

Provides:
- Branch name
- Upstream branch
- Ahead/behind counts
- File status

**Performance gain**: ~71% reduction in git subprocess calls

### 3. Progress Bar Visualization

**Location**: Lines 134-142

```bash
build_progress_bar() {
  local percent="$1"
  local filled=$((percent * BAR_WIDTH / 100))
  local empty=$((BAR_WIDTH - filled))

  # Use printf + tr for character repetition
  printf "%${filled}s" | tr ' ' "$BAR_FILLED"
  printf "%${empty}s" | tr ' ' "$BAR_EMPTY"
}
```

**Technique**: `printf` with width specifier + `tr` for character substitution
- `printf "%5s"` creates 5 spaces
- `tr ' ' "█"` converts spaces to filled blocks
- More efficient than loops

**Display**:
```
████████████░░░  (80% usage)
```

### 4. Color Scheme

**Location**: Lines 26-33

| Color | Usage | Semantic Meaning |
|-------|-------|------------------|
| **Cyan** | Model name | Primary info |
| **Gray** | Separators, labels | Secondary/structural |
| **Blue** | Directory | Navigation context |
| **Magenta** | Git branch | Version control |
| **Green** | Added lines, ahead commits | Positive/additions |
| **Red** | Removed lines, behind commits | Negative/deletions |
| **Orange** | Warnings (not a repo) | Caution |

**Why this palette?**
- High contrast for terminal readability
- Semantic color associations
- Consistent with common terminal conventions

### 5. Null Value Handling

**Pattern used throughout**:

```bash
# Check for null, zero, and empty
if [ "$value" != "0" ] 2>/dev/null && [ -n "$value" ] && [ "$value" != "$NULL_VALUE" ]; then
  # Display the value
fi
```

**Why this pattern?**
- `2>/dev/null` suppresses arithmetic errors for non-numeric values
- Handles jq's null output (string "null")
- Handles missing values (empty string)
- Handles zero values

### 6. Git Version Caching

**Location**: Lines 80-104

```bash
check_git_version() {
  # Return cached result if available
  [ -n "${GIT_VERSION_CHECKED:-}" ] && return "${GIT_VERSION_OK:-1}"

  GIT_VERSION_CHECKED=1
  # ... version check logic ...
  GIT_VERSION_OK=0  # or 1
  return $GIT_VERSION_OK
}
```

**Why cache?**
- Version check involves subprocess + parsing
- Git version doesn't change during execution
- Cache in global variables (not readonly for modification)
- Check only once per session

---

## Performance Optimizations

### Summary of Optimizations

| Optimization | Impact | Technique |
|--------------|--------|-----------|
| **Git calls: 7→2** | ~71% reduction | Porcelain v2 format |
| **Git version caching** | Avoid repeated checks | Global variable cache |
| **Efficient string ops** | Faster bar rendering | printf + tr vs loops |
| **Early returns** | Skip unnecessary work | Guard clauses |
| **Single JSON parse** | Minimize jq calls | Parse once, extract multiple |

### Detailed Analysis

#### 1. Git Status Optimization

**Impact**: Most significant performance gain

**Before**:
```bash
# 7 separate git subprocess calls
branch=$(git branch --show-current)
upstream=$(git rev-parse --abbrev-ref @{upstream})
ahead=$(git rev-list --count @{upstream}..HEAD)
# ... etc
```

**After**:
```bash
# Single call with all info
status_output=$(git status --porcelain=v2 --branch --untracked-files=all)
# Parse structured output
```

**Benefit**: Subprocess creation overhead reduced by ~71%

#### 2. String Operation Efficiency

**Progress bar rendering**:

❌ **Inefficient**:
```bash
for ((i=0; i<filled; i++)); do
  echo -n "$BAR_FILLED"
done
```

✅ **Efficient**:
```bash
printf "%${filled}s" | tr ' ' "$BAR_FILLED"
```

**Why faster?**
- No loop overhead
- Single process (no subshells)
- Built-in string operations

#### 3. Early Returns

**Pattern**:
```bash
get_git_info() {
  # Check if git repo - early return if not
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "$STATE_NOT_REPO"
    return 0  # Early exit, skip all git operations
  }

  # Only execute expensive operations if needed
  # ...
}
```

**Benefit**: Avoid expensive operations when not needed

#### 4. Single JSON Parse

**Strategy**: Parse JSON once, extract all fields

❌ **Inefficient**:
```bash
MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd')
# Multiple jq process spawns
```

✅ **Efficient**:
```bash
parsed=$(echo "$input" | jq -r '
  .model.display_name,
  .workspace.current_dir,
  .cost.total_cost_usd
')
# Single jq process, multiple outputs
```

**Benefit**: Reduced jq subprocess overhead

### Performance Benchmarks (Estimated)

| Scenario | Operations | Estimated Time |
|----------|------------|----------------|
| **Not a git repo** | 1 git call + JSON parse | ~20ms |
| **Clean git repo** | 2 git calls + JSON parse | ~50ms |
| **Dirty git repo (100 files)** | 2 git calls + JSON parse | ~80ms |

**Target**: Keep total execution under 100ms for good UX

---

## Extension Guide

### Adding a New Component

**Example**: Add a component showing Python version

#### Step 1: Create Component Builder

Add to the "COMPONENT BUILDERS" section (after line 365):

```bash
build_python_component() {
  local python_version

  # Get Python version if available
  if command -v python3 >/dev/null 2>&1; then
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    echo "🐍 ${GREEN}${python_version}${NC}"
  fi
}
```

#### Step 2: Call Builder in main()

Modify `main()` function (around line 426):

```bash
# Build components
local model_part context_part dir_part git_part cost_part lines_part python_part
model_part=$(build_model_component "$model_name")
context_part=$(build_context_component "$context_size" "$current_usage")
dir_part=$(build_directory_component "$current_dir")
git_part=$(build_git_component "$current_dir")
cost_part=$(build_cost_component "$cost_usd")
lines_part=$(build_lines_component "$lines_added" "$lines_removed")
python_part=$(build_python_component)  # NEW
```

#### Step 3: Update Assembly

Modify `assemble_statusline()` call (around line 435):

```bash
# Assemble and output
assemble_statusline "$model_part" "$context_part" "$dir_part" "$git_part" "$cost_part" "$lines_part" "$python_part"
```

#### Step 4: Update Assembly Function

Modify `assemble_statusline()` function (around line 371):

```bash
assemble_statusline() {
  local model_part="$1"
  local context_part="$2"
  local dir_part="$3"
  local git_part="$4"
  local cost_part="$5"
  local lines_part="$6"
  local python_part="$7"  # NEW

  local output="${model_part}$(sep)${context_part}$(sep)${dir_part}${git_part}"

  [ -n "$cost_part" ] && output+="$(sep)${cost_part}"
  [ -n "$lines_part" ] && output+="$(sep)${lines_part}"
  [ -n "$python_part" ] && output+="$(sep)${python_part}"  # NEW

  echo -e "$output"
}
```

**Result**: 🐍 3.11.5 appears in statusline

### Adding a New Git State

**Example**: Add "ahead only" state (has commits to push, but working dir clean)

#### Step 1: Add State Constant

In configuration section (around line 59):

```bash
readonly STATE_AHEAD_ONLY="ahead_only"
```

#### Step 2: Modify get_git_info()

Update logic to detect this state (around line 202):

```bash
# Clean state if no files
if [ "$total_files" -eq 0 ]; then
  # Check if ahead
  if [ "$ahead" -gt 0 ] && [ "$behind" -eq 0 ]; then
    echo "$STATE_AHEAD_ONLY|$branch|$ahead"
  else
    echo "$STATE_CLEAN|$branch|$ahead|$behind"
  fi
  return 0
fi
```

#### Step 3: Add Formatter

Add new formatting function (around line 245):

```bash
format_git_ahead_only() {
  local branch="$1" ahead="$2"

  local output="${GRAY}(${NC}${MAGENTA}${branch}${NC}"
  output+=" ${GRAY}|${NC} ${GREEN}Ready to push${NC} ${GREEN}↑${ahead}${NC}"
  output+="${GRAY})${NC}"

  echo " $output"
}
```

#### Step 4: Update Router

Modify `format_git_info()` (around line 272):

```bash
case "$state" in
  $STATE_NOT_REPO)
    format_git_not_repo
    ;;
  $STATE_AHEAD_ONLY)  # NEW
    local branch ahead
    IFS='|' read -r _ branch ahead << EOF
$git_data
EOF
    format_git_ahead_only "$branch" "$ahead"
    ;;
  $STATE_CLEAN)
    # existing code...
    ;;
  # ... rest of cases
esac
```

### Customizing Colors

Modify constants section (lines 26-33):

```bash
# Change from default cyan to purple for model
readonly MODEL_COLOR='\033[0;35m'  # Magenta/Purple
```

Update usage in builder (line 298):

```bash
build_model_component() {
  local model_name="$1"
  echo "${MODEL_ICON} ${MODEL_COLOR}${model_name}${NC}"
}
```

### Adding JSON Fields

If Claude Code adds new JSON fields:

#### Step 1: Update parse_claude_input()

```bash
parse_claude_input() {
  local input="$1"

  local parsed
  parsed=$(echo "$input" | jq -r '
    .model.display_name,
    .workspace.current_dir,
    # ... existing fields ...
    (.new_field.property // "default_value")  # NEW FIELD
  ' 2>/dev/null)

  echo "$parsed"
}
```

#### Step 2: Extract in main()

```bash
local model_name current_dir ... new_field
{
  read -r model_name
  read -r current_dir
  # ... existing reads ...
  read -r new_field  # NEW
} << EOF
$parsed
EOF
```

#### Step 3: Use in component builder

Pass to relevant builder or create new one.

---

## Testing

See [TESTING.md](TESTING.md) for comprehensive testing guide including:
- Manual testing procedures
- Automated testing with test suites
- Integration testing with Claude Code
- Platform-specific testing
- Adding new test cases

---

## Maintenance

### Regular Maintenance Tasks

#### 1. Git Version Updates

When git adds new porcelain v2 features:

**Check**: `man git-status` for new fields
**Update**: `get_git_info()` parsing logic
**Test**: On multiple git versions

#### 2. Claude Code JSON Schema Changes

Monitor Claude Code releases for JSON schema updates:

**Check**: Release notes for statusline changes
**Update**: `parse_claude_input()` field extraction
**Test**: With new and old JSON formats

#### 3. Platform Compatibility

Test on all supported platforms:

- macOS (latest 2 versions)
- Linux (Ubuntu LTS, latest)
- WSL (latest)
- MinGW (latest)

**Key areas**:
- Icon display
- Color rendering
- Command availability (jq, git)

### Performance Monitoring

#### Measure Execution Time

Add timing to script:

```bash
main() {
  local start_time=$(date +%s%N)

  # ... existing code ...

  local end_time=$(date +%s%N)
  local elapsed=$(( (end_time - start_time) / 1000000 ))  # ms

  # Log to file if too slow
  [ $elapsed -gt 100 ] && echo "$(date): Slow execution: ${elapsed}ms" >> /tmp/statusline-perf.log
}
```

#### Performance Targets

| Metric | Target | Action if Exceeded |
|--------|--------|-------------------|
| Total execution time | < 100ms | Optimize or cache |
| Git operations | < 50ms | Check git repo size |
| JSON parsing | < 10ms | Review jq query |

### Code Quality Checklist

Before committing changes:

- [ ] All functions have clear single responsibility
- [ ] New functions follow existing naming conventions
- [ ] Constants are used instead of magic numbers/strings
- [ ] Error handling for all external commands
- [ ] Null value handling for all JSON fields
- [ ] POSIX compatibility maintained where possible
- [ ] Comments added for complex logic
- [ ] No code duplication (DRY principle)
- [ ] Performance impact considered
- [ ] Tested on at least 2 platforms

### Debugging Tips

#### Enable Debug Mode

Add debug output:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Enable debug mode with environment variable
[ -n "${DEBUG:-}" ] && set -x

# Continue with normal code...
```

Run with debug:
```bash
DEBUG=1 ./statusline.sh < test-input.json
```

#### Log JSON Input

```bash
main() {
  local input
  input=$(cat)

  # Log input to file for inspection
  [ -n "${DEBUG:-}" ] && echo "$input" > /tmp/statusline-input.json

  # Continue processing...
}
```

#### Verify Git Commands

Test git operations in isolation:

```bash
# Check porcelain v2 output
git status --porcelain=v2 --branch

# Check diff output
git diff HEAD --numstat
```

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Slow performance** | Statusline lags | Check git repo size, optimize operations |
| **Git errors** | Error messages in statusline | Verify git version 2.11+, check repo integrity |
| **JSON parse errors** | Statusline not displaying | Verify JSON schema matches parse_claude_input() |
| **Missing icons** | Empty squares or broken chars | Verify terminal has emoji support (modern terminals recommended) |
| **Wrong colors** | Colors not appearing | Verify ANSI support, check color code variables |

### Version Control Best Practices

#### Commit Message Format

Follow Conventional Commits:

```
feat: add Python version component
fix: handle detached HEAD state correctly
perf: optimize git status parsing
docs: update installation instructions
test: add test cases for null values
refactor: extract format_ahead_behind helper
```

#### Branching Strategy

```
main
  ├── feature/new-component
  ├── fix/git-error-handling
  └── perf/optimize-parsing
```

#### Release Process

1. Update version in documentation
2. Test on all platforms
3. Update CHANGELOG.md
4. Tag release: `git tag v1.0.1`
5. Push: `git push --tags`

---

## Appendix

### Dependencies

#### Required

| Dependency | Version | Purpose |
|------------|---------|---------|
| **bash** | 3.2+ | Shell interpreter |
| **jq** | 1.5+ | JSON parsing |
| **git** | 2.11+ | Git operations (porcelain v2) |

#### Installation

**macOS**:
```bash
brew install jq git
```

**Ubuntu/Debian**:
```bash
apt-get install jq git
```

**Windows (Git Bash)**:
```bash
# jq included with Git for Windows
# Or install via: https://stedolan.github.io/jq/download/
```

### Related Documentation

- [STATUSLINE-REFERENCE.md](./STATUSLINE-REFERENCE.md) - Official Claude Code statusline documentation
- [Claude Code Documentation](https://code.claude.com/docs)
- [Git Porcelain v2 Format](https://git-scm.com/docs/git-status#_porcelain_format_version_2)
- [jq Manual](https://jqlang.github.io/jq/manual/)
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)

### License

This implementation is provided as-is for use with Claude Code.

### Changelog

#### v1.0.0 (2026-01-13)
- Initial implementation
- Cross-platform support (macOS, Linux, WSL, MinGW)
- Git status with porcelain v2
- Context usage visualization
- Cost and line tracking
- Component-based architecture
- Performance optimizations (7 git calls → 2)

---

*Last updated: 2026-01-13*
*Document version: 1.0.0*
