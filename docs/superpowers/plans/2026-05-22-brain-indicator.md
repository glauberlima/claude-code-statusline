# Brain Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show 🧠 in the context component when `effort.level = "max"` AND `thinking.enabled = true` in the statusline JSON payload.

**Architecture:** Add a `bool_val` awk helper to `parse_claude_input()` to extract JSON boolean values. Compute a combined `thinking_active` flag (7th parsed field). Thread it through `main()` into `build_context_component()`, which conditionally appends ` 🧠` after the token numbers.

**Tech Stack:** Bash 3.2+, awk (POSIX), existing test harness in `tests/unit.sh` and `tests/integration.sh`.

---

## File Map

| File | Change |
|---|---|
| `statusline.sh` | Add `bool_val` awk helper; extract 7th field `thinking_active`; update line count check 6→7; add `read` + CR-strip loop entry; update `build_context_component` signature and body; update call in `main()` |
| `tests/unit.sh` | Add parse_claude_input tests for 7th field; add build_context_component brain indicator tests |
| `tests/integration.sh` | Add 3 inline JSON test cases for thinking active/inactive/absent |

---

### Task 1: Write failing tests for parser 7th field

**Files:**
- Modify: `tests/unit.sh` (after the existing `parse_claude_input` tests, around line 328)

- [ ] **Step 1: Add tests for the new 7th field to `tests/unit.sh`**

Find the block ending with:
```bash
test "parse_claude_input preserves raw used_percentage before clamp" "150" "${parsed_line_5}"
```

Add immediately after it:

```bash
# Test 7th field: thinking_active
parsed=$(parse_claude_input '{
  "model": {"display_name": "Opus"},
  "workspace": {"current_dir": "/tmp/t"},
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {"input_tokens": 1000},
    "used_percentage": 10
  },
  "cost": {"total_cost_usd": 0},
  "effort": {"level": "max"},
  "thinking": {"enabled": true}
}')
parsed_line_7=""
{
  read -r _; read -r _; read -r _; read -r _; read -r _; read -r _
  read -r parsed_line_7
} <<< "${parsed}"
test "parse_claude_input thinking_active=1 when effort=max and thinking=true" "1" "${parsed_line_7}"

parsed=$(parse_claude_input '{
  "model": {"display_name": "Opus"},
  "workspace": {"current_dir": "/tmp/t"},
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {"input_tokens": 1000},
    "used_percentage": 10
  },
  "cost": {"total_cost_usd": 0},
  "effort": {"level": "high"},
  "thinking": {"enabled": true}
}')
parsed_line_7=""
{
  read -r _; read -r _; read -r _; read -r _; read -r _; read -r _
  read -r parsed_line_7
} <<< "${parsed}"
test "parse_claude_input thinking_active=0 when effort=high (not max)" "0" "${parsed_line_7}"

parsed=$(parse_claude_input '{
  "model": {"display_name": "Opus"},
  "workspace": {"current_dir": "/tmp/t"},
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {"input_tokens": 1000},
    "used_percentage": 10
  },
  "cost": {"total_cost_usd": 0}
}')
parsed_line_7=""
{
  read -r _; read -r _; read -r _; read -r _; read -r _; read -r _
  read -r parsed_line_7
} <<< "${parsed}"
test "parse_claude_input thinking_active=0 when effort/thinking absent" "0" "${parsed_line_7}"
```

- [ ] **Step 2: Run unit tests — confirm new tests fail**

```bash
./tests/unit.sh 2>&1 | tail -20
```

Expected: The 3 new `thinking_active` tests show `✗`. The 7th `read` gets empty string because only 6 lines currently exist. Existing tests still pass.

---

### Task 2: Implement parser changes in `statusline.sh`

**Files:**
- Modify: `statusline.sh`

- [ ] **Step 1: Add `bool_val` awk helper function**

In `parse_claude_input()`, find the comment block for `num_val` ending with:
```awk
    # Return the numeric value of key from a JSON object fragment s.
    function num_val(s, key,    pat, rest) {
      if (s == "") return ""
      pat = "\"" key "\"[[:space:]]*:[[:space:]]*"
      if (!match(s, pat)) return ""
      rest = substr(s, RSTART + RLENGTH)
      match(rest, /^-?[0-9][0-9.eE+\-]*/)
      if (RLENGTH <= 0) return ""
      return substr(rest, RSTART, RLENGTH)
    }
```

Add after it (before the closing `' 2>/dev/null)`):

```awk
    # Return "true" or "false" for a JSON boolean key, or "" if absent.
    function bool_val(s, key,    pat, rest) {
      if (s == "") return ""
      pat = "\"" key "\"[[:space:]]*:[[:space:]]*"
      if (!match(s, pat)) return ""
      rest = substr(s, RSTART + RLENGTH)
      if (rest ~ /^true/)  return "true"
      if (rest ~ /^false/) return "false"
      return ""
    }
```

- [ ] **Step 2: Extract effort/thinking fields and print 7th line**

In the awk `END {}` block, find:
```awk
      cost_block = obj_content(doc, "cost")
      cost_usd   = num_val(cost_block, "total_cost_usd")
      if (cost_usd == "") cost_usd = "0"

      print model_name
      print current_dir
      print context_size
      print current_usage
      print context_percent
      print cost_usd
```

Replace with:

```awk
      cost_block = obj_content(doc, "cost")
      cost_usd   = num_val(cost_block, "total_cost_usd")
      if (cost_usd == "") cost_usd = "0"

      effort_block     = obj_content(doc, "effort")
      effort_level     = str_val(effort_block, "level")

      thinking_block   = obj_content(doc, "thinking")
      thinking_enabled = bool_val(thinking_block, "enabled")

      thinking_active = (effort_level == "max" && thinking_enabled == "true") ? "1" : "0"

      print model_name
      print current_dir
      print context_size
      print current_usage
      print context_percent
      print cost_usd
      print thinking_active
```

- [ ] **Step 3: Update comment header for parse_claude_input**

Find:
```bash
  # Single awk call replaces jq. Three helper functions handle nested JSON:
  #   obj_content: extracts the content of { } for a given key (depth-tracked, string-aware)
  #   str_val:     extracts a string value for a key from a JSON fragment
  #   num_val:     extracts a numeric value for a key from a JSON fragment
```

Replace with:

```bash
  # Single awk call replaces jq. Four helper functions handle nested JSON:
  #   obj_content: extracts the content of { } for a given key (depth-tracked, string-aware)
  #   str_val:     extracts a string value for a key from a JSON fragment
  #   num_val:     extracts a numeric value for a key from a JSON fragment
  #   bool_val:    extracts a JSON boolean value ("true"/"false") for a key
```

- [ ] **Step 4: Update line count check in `main()`**

Find:
```bash
  if [[ ${line_count} -ne 6 ]]; then
    echo "Error: Expected 6 fields from JSON, got ${line_count}" >&2
```

Replace with:
```bash
  if [[ ${line_count} -ne 7 ]]; then
    echo "Error: Expected 7 fields from JSON, got ${line_count}" >&2
```

- [ ] **Step 5: Add `thinking_active` to the read block and CR-strip loop in `main()`**

Find:
```bash
  local model_name current_dir context_size current_usage context_percent cost_usd
  {
    read -r model_name
    read -r current_dir
    read -r context_size
    read -r current_usage
    read -r context_percent
    read -r cost_usd
  } << EOF
${parsed}
EOF

  # Strip carriage returns (Windows line endings compatibility)
  for _v in model_name current_dir context_size current_usage context_percent cost_usd; do
    declare "${_v}=${!_v%$'\r'}"
  done
```

Replace with:
```bash
  local model_name current_dir context_size current_usage context_percent cost_usd thinking_active
  {
    read -r model_name
    read -r current_dir
    read -r context_size
    read -r current_usage
    read -r context_percent
    read -r cost_usd
    read -r thinking_active
  } << EOF
${parsed}
EOF

  # Strip carriage returns (Windows line endings compatibility)
  for _v in model_name current_dir context_size current_usage context_percent cost_usd thinking_active; do
    declare "${_v}=${!_v%$'\r'}"
  done
```

- [ ] **Step 6: Run unit tests — confirm parser tests now pass**

```bash
./tests/unit.sh 2>&1 | tail -20
```

Expected: The 3 new `thinking_active` tests now show `✓`. All other tests still pass.

- [ ] **Step 7: Commit parser changes**

```bash
git add statusline.sh tests/unit.sh
git commit -m "feat: add bool_val awk helper and parse thinking_active field"
```

---

### Task 3: Write failing tests for `build_context_component` brain indicator

**Files:**
- Modify: `tests/unit.sh` (after the existing `build_context_component` tests, around line 358)

- [ ] **Step 1: Add brain indicator tests to `tests/unit.sh`**

Find the end of the `build_context_component` block — the last test is:
```bash
result=$(build_context_component "200000" "2000" "-5" | strip_ansi)
if echo "${result}" | grep -q "0% 2.0K/200K"; then
  echo -e "${green}✓${nc} build_context_component clamps negative percentage"
  passed=$((passed + 1))
else
  echo -e "${red}✗${nc} build_context_component failed to clamp negative percentage"
  echo "  Output: ${result}"
  failed=$((failed + 1))
fi
```

Add immediately after:

```bash
result=$(build_context_component "200000" "54000" "27" "1" | strip_ansi)
if echo "${result}" | grep -q "🧠"; then
  echo -e "${green}✓${nc} build_context_component shows brain when thinking_active=1"
  passed=$((passed + 1))
else
  echo -e "${red}✗${nc} build_context_component missing brain when thinking_active=1"
  echo "  Output: ${result}"
  failed=$((failed + 1))
fi

result=$(build_context_component "200000" "54000" "27" "0" | strip_ansi)
if ! echo "${result}" | grep -q "🧠"; then
  echo -e "${green}✓${nc} build_context_component hides brain when thinking_active=0"
  passed=$((passed + 1))
else
  echo -e "${red}✗${nc} build_context_component shows brain when thinking_active=0"
  echo "  Output: ${result}"
  failed=$((failed + 1))
fi
```

- [ ] **Step 2: Run unit tests — confirm new tests fail**

```bash
./tests/unit.sh 2>&1 | grep -E "brain|✗" | head -10
```

Expected: Both brain tests show `✗` — function doesn't accept 4th param yet.

---

### Task 4: Implement `build_context_component` changes

**Files:**
- Modify: `statusline.sh`

- [ ] **Step 1: Update `build_context_component` signature and output**

Find:
```bash
build_context_component() {
  local context_size="$1"
  local current_usage="$2"
  local context_percent="$3"

  context_percent=$(clamp_percent "${context_percent}")

  # Get colored progress bar
  local bar
  bar=$(build_progress_bar "${context_percent}")

  # Format usage numbers (e.g., "54K/200K")
  local usage_formatted
  usage_formatted=$(format_number "${current_usage}")
  local size_formatted
  size_formatted=$(format_number "${context_size}")

  # Build message part conditionally (read from global SHOW_MESSAGES)
  local message_part=""
  if [[ "${SHOW_MESSAGES}" == "true" ]]; then
    local message
    message=$(get_context_message "${context_percent}")

    local msg_color
    msg_color=$(get_random_message_color)

    message_part=" ${GRAY}|${NC} ${msg_color}${message}${NC}"
  fi

  # Output with brackets, colored bar, formatted numbers, and optional message
  echo "${CONTEXT_ICON} ${GRAY}[${NC}${bar}${GRAY}]${NC} ${context_percent}% ${usage_formatted}/${size_formatted}${message_part}"
}
```

Replace with:

```bash
build_context_component() {
  local context_size="$1"
  local current_usage="$2"
  local context_percent="$3"
  local thinking_active="${4:-0}"

  context_percent=$(clamp_percent "${context_percent}")

  # Get colored progress bar
  local bar
  bar=$(build_progress_bar "${context_percent}")

  # Format usage numbers (e.g., "54K/200K")
  local usage_formatted
  usage_formatted=$(format_number "${current_usage}")
  local size_formatted
  size_formatted=$(format_number "${context_size}")

  local brain_part=""
  [[ "${thinking_active}" == "1" ]] && brain_part=" 🧠"

  # Build message part conditionally (read from global SHOW_MESSAGES)
  local message_part=""
  if [[ "${SHOW_MESSAGES}" == "true" ]]; then
    local message
    message=$(get_context_message "${context_percent}")

    local msg_color
    msg_color=$(get_random_message_color)

    message_part=" ${GRAY}|${NC} ${msg_color}${message}${NC}"
  fi

  # Output with brackets, colored bar, formatted numbers, brain indicator, and optional message
  echo "${CONTEXT_ICON} ${GRAY}[${NC}${bar}${GRAY}]${NC} ${context_percent}% ${usage_formatted}/${size_formatted}${brain_part}${message_part}"
}
```

- [ ] **Step 2: Update the call in `main()`**

Find:
```bash
  context_part=$(build_context_component "${context_size}" "${current_usage}" "${context_percent}")
```

Replace with:
```bash
  context_part=$(build_context_component "${context_size}" "${current_usage}" "${context_percent}" "${thinking_active}")
```

- [ ] **Step 3: Run unit tests — confirm brain tests pass**

```bash
./tests/unit.sh 2>&1 | grep -E "brain|thinking"
```

Expected: Both brain tests show `✓`. All other tests still pass.

- [ ] **Step 4: Commit component changes**

```bash
git add statusline.sh tests/unit.sh
git commit -m "feat: show brain indicator in context component when effort=max and thinking=true"
```

---

### Task 5: Add integration tests

**Files:**
- Modify: `tests/integration.sh`

- [ ] **Step 1: Add `run_test_absent` helper to `tests/integration.sh`**

Find the existing `run_test` function (around line 36). Add `run_test_absent` immediately after it (after its closing `}`):

```bash
# Assert a substring is NOT present in the output
run_test_absent() {
  local test_name="$1"
  local json_input="$2"
  local absent_substring="$3"

  TOTAL=$((TOTAL + 1))

  local run_output exit_code output clean_output
  run_output=$(run_statusline "${json_input}")
  {
    IFS= read -r exit_code
    output=$(cat)
  } <<< "${run_output}"
  clean_output=$(printf '%s' "${output}" | strip_ansi)

  if [[ ${exit_code} -ne 0 ]]; then
    echo -e "${RED}✗${NC} ${test_name}"
    echo "  Exit code: ${exit_code}"
    echo "  Output: ${output}"
    FAILED=$((FAILED + 1))
    return 0
  fi

  if echo "${clean_output}" | grep -q "${absent_substring}"; then
    echo -e "${RED}✗${NC} ${test_name} (unexpected content found)"
    echo "  Unexpected substring: ${absent_substring}"
    echo "  Actual output: ${clean_output}"
    FAILED=$((FAILED + 1))
  else
    echo -e "${GREEN}✓${NC} ${test_name}"
    PASSED=$((PASSED + 1))
  fi

  return 0
}
```

- [ ] **Step 2: Add 3 brain indicator test cases before the summary block**

Find the comment `# Summary` (before `echo -e "\n${YELLOW}=== Test Summary ===${NC}"`). Add before it:

```bash
  # Brain indicator tests
  echo -e "\n${YELLOW}=== Brain Indicator Tests ===${NC}"

  run_test "Brain: shown when effort=max and thinking=true" '{
    "model": {"display_name": "Opus"},
    "workspace": {"current_dir": "/test/project"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 50000},
      "used_percentage": 25
    },
    "cost": {"total_cost_usd": 0},
    "effort": {"level": "max"},
    "thinking": {"enabled": true}
  }' "🧠"

  run_test_absent "Brain: absent when effort=high (not max)" '{
    "model": {"display_name": "Opus"},
    "workspace": {"current_dir": "/test/project"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 50000},
      "used_percentage": 25
    },
    "cost": {"total_cost_usd": 0},
    "effort": {"level": "high"},
    "thinking": {"enabled": true}
  }' "🧠"

  run_test_absent "Brain: absent when effort/thinking fields missing" '{
    "model": {"display_name": "Opus"},
    "workspace": {"current_dir": "/test/project"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 50000},
      "used_percentage": 25
    },
    "cost": {"total_cost_usd": 0}
  }' "🧠"
```

- [ ] **Step 2: Run all tests**

```bash
./tests/unit.sh && ./tests/integration.sh && ./tests/shellcheck.sh
```

Expected: All tests pass. Integration output includes:
```
✓ Brain indicator shown when effort=max and thinking=true
✓ Brain indicator absent when effort=high (not max)
✓ Brain indicator absent when effort/thinking fields are missing
```

- [ ] **Step 3: Commit integration tests**

```bash
git add tests/integration.sh
git commit -m "test: add integration tests for brain indicator"
```
