# Static Message Patching System - Design Document

**Date:** 2026-02-04
**Status:** Approved
**Branch:** feat/windows-installer-json-i18n

## Overview

Replace the dynamic i18n system with a build-time patching approach that produces fully static, optimized statusline scripts with zero runtime configuration overhead.

### Current Problem

The existing system loads configuration and message files at runtime:
- Reads `~/.claude/statusline-config.json` (~2ms)
- Loads language JSON file (~3-5ms)
- Total i18n overhead: ~3-5ms per execution

### Proposed Solution

**Build-time patching:**
1. Hardcode English messages as bash arrays in `statusline.sh`
2. Add configuration flags (`SHOW_MESSAGES`, `SHOW_COST`) with marker comments
3. Create `patch-statusline.sh` script that replaces marked blocks
4. Delete all dynamic loading functions

**Result:** Zero runtime overhead, fully optimized scripts tailored to user preferences.

## Goals

- **Performance:** Eliminate 3-5ms i18n overhead
- **Simplicity:** Minimal invasive changes to statusline.sh
- **Maintainability:** Clear marker-based patching
- **Compatibility:** Bash 3.2+ (macOS support)

## User Workflow

```bash
# Patch to Portuguese with all features
./patch-statusline.sh ~/.claude/statusline.sh messages/pt.json

# Minimal English (no messages, no cost)
./patch-statusline.sh ~/.claude/statusline.sh --no-messages --no-cost

# Spanish, cost tracking only
./patch-statusline.sh ~/.claude/statusline.sh messages/es.json --no-messages
```

To change settings, re-run the patch script.

## Design Details

### 1. Simplified JSON Message Format

**Before:**
```json
{
  "language": "en",
  "display_name": "English",
  "tiers": {
    "very_low": [...],
    "low": [...],
    ...
  }
}
```

**After:**
```json
{
  "very_low": ["just getting started", "barely touched it", ...],
  "low": ["ate and left no crumbs", "light snacking", ...],
  "medium": ["halfway there", "finding the groove", ...],
  "high": ["getting spicy", "filling up fast", ...],
  "critical": ["living dangerously", "pushing the limits", ...]
}
```

Remove metadata, flatten structure. Keys match bash variable names exactly.

### 2. statusline.sh Modifications

#### Add Configuration Block

```bash
# ============================================================
# RUNTIME CONFIGURATION (Patched by patch-statusline.sh)
# ============================================================
# @CONFIG_START
readonly SHOW_MESSAGES=true
readonly SHOW_COST=true
# @CONFIG_END
```

#### Add Message Arrays Block

```bash
# ============================================================
# I18N MESSAGES (Patched by patch-statusline.sh for language)
# ============================================================
# @MESSAGES_START
readonly CONTEXT_MSG_VERY_LOW=("just getting started" "barely touched it" ...)
readonly CONTEXT_MSG_LOW=("ate and left no crumbs" "light snacking" ...)
readonly CONTEXT_MSG_MEDIUM=("halfway there" "finding the groove" ...)
readonly CONTEXT_MSG_HIGH=("getting spicy" "filling up fast" ...)
readonly CONTEXT_MSG_CRITICAL=("living dangerously" "pushing the limits" ...)
# @MESSAGES_END
```

#### Refactor get_context_message() for Arrays

**Before (pipe-delimited strings):**
```bash
msg_string="msg1|msg2|msg3"
IFS='|' for message in ${msg_string}; do ...
```

**After (bash arrays):**
```bash
get_context_message() {
  local percent="$1"
  local tier
  tier=$(get_context_tier "${percent}")

  # Select array based on tier
  local messages_array
  case "${tier}" in
    0) messages_array=("${CONTEXT_MSG_VERY_LOW[@]}") ;;
    1) messages_array=("${CONTEXT_MSG_LOW[@]}") ;;
    2) messages_array=("${CONTEXT_MSG_MEDIUM[@]}") ;;
    3) messages_array=("${CONTEXT_MSG_HIGH[@]}") ;;
    4) messages_array=("${CONTEXT_MSG_CRITICAL[@]}") ;;
    *) echo "loading..."; return 0 ;;
  esac

  # Get array length and select random index
  local count=${#messages_array[@]}
  [[ ${count} -le 0 ]] && echo "loading..." && return 0

  local index=$(( (RANDOM * count) / 32768 ))
  echo "${messages_array[$index]}"
}
```

#### Delete Obsolete Functions

Remove entirely:
- `load_config()` - Previously read JSON config file
- `load_language_messages()` - Previously loaded language files
- `load_json_messages()` - Previously parsed JSON to pipe-delimited format

#### Update main() Function

**Remove:**
```bash
# Load configuration and language messages
local user_config show_messages show_cost
user_config=$(load_config)
# ... parsing logic ...
load_language_messages "${user_language}"
```

**Update component calls:**
```bash
# Before:
context_part=$(build_context_component "${context_size}" "${current_usage}" "${show_messages}")
cost_part=$(build_cost_component "${cost_usd}" "${show_cost}")

# After (functions read globals directly):
context_part=$(build_context_component "${context_size}" "${current_usage}")
cost_part=$(build_cost_component "${cost_usd}")
```

#### Update Component Functions

Functions check global constants instead of parameters:

```bash
build_context_component() {
  local context_size="$1"
  local current_usage="$2"

  # ... progress bar logic ...

  local message_part=""
  if [[ "${SHOW_MESSAGES}" == "true" ]]; then
    message=$(get_context_message "${context_percent}")
    msg_color=$(get_random_message_color)
    message_part=" ${GRAY}|${NC} ${msg_color}${message}${NC}"
  fi

  echo "... ${message_part}"
}

build_cost_component() {
  local cost_usd="$1"

  # Early return if disabled
  [[ "${SHOW_COST}" != "true" ]] && return

  # ... rest of logic ...
}
```

### 3. patch-statusline.sh Script

#### Interface

```bash
./patch-statusline.sh <statusline-file> [language-json] [--no-messages] [--no-cost]
```

**Parameters:**
- `statusline-file`: Path to statusline.sh (required)
- `language-json`: Path to JSON file (optional, keeps English if omitted)
- `--no-messages`: Disable context messages
- `--no-cost`: Disable cost tracking
- Flags can be in any order

**Output:** Modifies file in-place

#### Core Algorithm

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Parse arguments
statusline_file="$1"
language_json=""
show_messages=true
show_cost=true

for arg in "${@:2}"; do
  case "$arg" in
    --no-messages) show_messages=false ;;
    --no-cost) show_cost=false ;;
    *.json) language_json="$arg" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# 2. Validate inputs
[[ ! -f "${statusline_file}" ]] && echo "Error: File not found" >&2 && exit 1
if [[ -n "${language_json}" ]] && [[ ! -f "${language_json}" ]]; then
  echo "Error: JSON file not found" >&2
  exit 1
fi

# 3. Replace CONFIG block
replace_config_block "${statusline_file}" "${show_messages}" "${show_cost}"

# 4. Replace MESSAGES block (if language JSON provided)
if [[ -n "${language_json}" ]]; then
  replace_messages_block "${statusline_file}" "${language_json}"
fi

# 5. Validate output
if ! bash -n "${statusline_file}" 2>&1; then
  echo "Error: Patched script has syntax errors" >&2
  exit 1
fi

echo "✓ Patched successfully: ${statusline_file}"
```

#### Block Replacement Functions

**Replace CONFIG block:**
```bash
replace_config_block() {
  local file="$1"
  local show_messages="$2"
  local show_cost="$3"
  local temp_file
  temp_file=$(mktemp)

  # Extract everything before @CONFIG_START (inclusive)
  sed -n '1,/@CONFIG_START/p' "${file}" > "${temp_file}"

  # Insert new config
  echo "readonly SHOW_MESSAGES=${show_messages}" >> "${temp_file}"
  echo "readonly SHOW_COST=${show_cost}" >> "${temp_file}"

  # Extract everything from @CONFIG_END onwards (inclusive)
  sed -n '/@CONFIG_END/,$p' "${file}" >> "${temp_file}"

  mv "${temp_file}" "${file}"
}
```

**Replace MESSAGES block:**
```bash
replace_messages_block() {
  local file="$1"
  local json_file="$2"
  local temp_file
  temp_file=$(mktemp)

  # Extract arrays from JSON using jq
  local very_low low medium high critical
  very_low=$(jq -r '.very_low | map(@sh) | join(" ")' "${json_file}")
  low=$(jq -r '.low | map(@sh) | join(" ")' "${json_file}")
  medium=$(jq -r '.medium | map(@sh) | join(" ")' "${json_file}")
  high=$(jq -r '.high | map(@sh) | join(" ")' "${json_file}")
  critical=$(jq -r '.critical | map(@sh) | join(" ")' "${json_file}")

  # Extract before marker
  sed -n '1,/@MESSAGES_START/p' "${file}" > "${temp_file}"

  # Insert new arrays (jq @sh handles quoting/escaping)
  echo "readonly CONTEXT_MSG_VERY_LOW=(${very_low})" >> "${temp_file}"
  echo "readonly CONTEXT_MSG_LOW=(${low})" >> "${temp_file}"
  echo "readonly CONTEXT_MSG_MEDIUM=(${medium})" >> "${temp_file}"
  echo "readonly CONTEXT_MSG_HIGH=(${high})" >> "${temp_file}"
  echo "readonly CONTEXT_MSG_CRITICAL=(${critical})" >> "${temp_file}"

  # Extract from marker onwards
  sed -n '/@MESSAGES_END/,$p' "${file}" >> "${temp_file}"

  mv "${temp_file}" "${file}"
}
```

#### Bash 3.2 Compatibility

**Using jq's `@sh` for safe quoting:**
```bash
# Input JSON:
["msg with spaces", "msg's quote", "msg|pipe"]

# jq output:
'msg with spaces' 'msg'\''s quote' 'msg|pipe'

# Bash result:
readonly CONTEXT_MSG_VERY_LOW=('msg with spaces' 'msg'\''s quote' 'msg|pipe')
```

jq handles all escaping automatically, works with Bash 3.2 arrays.

### 4. Validation

**Post-patch validation:**
```bash
bash -n "${statusline_file}"
```

Simple syntax check only. If shellcheck warnings appear, add disable comments to source:
```bash
# shellcheck disable=SC2034  # Variable used in patched code
```

## Testing Strategy

### Update tests/unit.sh

**Remove tests for deleted functions:**
- `load_config()` tests
- `load_language_messages()` tests
- `load_json_messages()` tests

**Update existing tests:**
- `get_context_message()` - now expects bash arrays

**Add new tests:**
- Validate `@CONFIG_START` / `@CONFIG_END` markers exist
- Validate `@MESSAGES_START` / `@MESSAGES_END` markers exist
- Test array-based message selection

### Update tests/integration.sh

- Remove language config file tests
- Test with different `SHOW_MESSAGES` / `SHOW_COST` combinations

### Create tests/patch-test.sh

```bash
#!/usr/bin/env bash
# Test patch-statusline.sh functionality

Test cases:
1. Patch with Portuguese messages
2. Patch with --no-messages
3. Patch with --no-cost
4. Patch with both flags
5. Verify bash -n passes
6. Test invalid inputs (missing file, bad JSON)
```

## Documentation Updates

### README.md

- Remove `~/.claude/statusline-config.json` references
- Add `patch-statusline.sh` usage section
- Update installation workflow

### CLAUDE.md

- Update i18n architecture section (static patching vs dynamic loading)
- Document patch script design
- Update performance targets (remove 3-5ms overhead)
- Update file locations (no config file, no runtime message loading)

### messages/README.md

- Document simplified JSON format
- Remove metadata fields documentation
- Update translation workflow

## Performance Impact

**Before:**
- Total execution: ~100ms
- i18n overhead: 3-5ms (config + message loading)

**After:**
- Total execution: ~95ms
- i18n overhead: 0ms (fully static)

**Improvement:** 3-5% performance gain, ~5ms reduction.

## Implementation Order

1. ✅ Write design document
2. Simplify JSON message files (en.json, pt.json, es.json)
3. Refactor statusline.sh:
   - Add @CONFIG_START/@CONFIG_END block
   - Add @MESSAGES_START/@MESSAGES_END block
   - Refactor get_context_message() for arrays
4. Delete obsolete functions from statusline.sh
5. Create patch-statusline.sh script
6. Update tests
7. Update documentation

## Notes

- install.sh remains unchanged (out of scope)
- No migration guide needed (tool still in development)
- All code must pass `bash -n` validation
- Bash 3.2+ compatibility required (macOS default)
