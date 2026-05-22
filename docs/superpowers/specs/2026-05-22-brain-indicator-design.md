---
title: Brain Indicator for Max Effort / Extended Thinking
date: 2026-05-22
status: approved
---

# Brain Indicator (🧠) for Max Effort + Extended Thinking

## Summary

Add a 🧠 emoji to the context component of the statusline when the Claude Code session has both `effort.level = "max"` **and** `thinking.enabled = true` in the JSON payload. When either condition is absent or false, no indicator is shown.

## Motivation

`/effort max` + extended thinking is a session-wide configuration visible in the statusline payload. Currently the statusline gives no indication that the model is running in its most expensive, deepest-reasoning mode. A small visual cue makes it easy to notice at a glance whether the session is in "ultrathink territory".

## Output

**With max effort + thinking active:**
```
📊 [█████████░░░░░░] 54% 54K/200K 🧠 | tá tranquilo
```

**Normal session:**
```
📊 [█████████░░░░░░] 54% 54K/200K | tá tranquilo
```

The 🧠 appears between the token numbers and the optional message segment.

## Architecture

### 1. Parser: `parse_claude_input()` in `statusline.sh`

Add a `bool_val` awk helper function alongside the existing `str_val` and `num_val`:

```awk
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

In the `END {}` block, after the existing 6 fields:

```awk
effort_block     = obj_content(doc, "effort")
effort_level     = str_val(effort_block, "level")

thinking_block   = obj_content(doc, "thinking")
thinking_enabled = bool_val(thinking_block, "enabled")

thinking_active  = (effort_level == "max" && thinking_enabled == "true") ? "1" : "0"
print thinking_active   # 7th output line
```

**Absence handling:** when `effort` or `thinking` objects are absent from the payload (models that don't support them), `obj_content` returns `""`, both helpers return `""`, the AND condition is false, `thinking_active = "0"`. No crash, no indicator shown.

### 2. Field count validation in `main()`

Update the line count check from `6` to `7`. Add one new `read`:

```bash
read -r thinking_active
```

Add `thinking_active` to the carriage-return stripping loop (Windows compatibility):

```bash
for _v in model_name current_dir context_size current_usage context_percent cost_usd thinking_active; do
  declare "${_v}=${!_v%$'\r'}"
done
```

### 3. Component: `build_context_component()`

Add 4th parameter `thinking_active`:

```bash
build_context_component() {
  local context_size="$1"
  local current_usage="$2"
  local context_percent="$3"
  local thinking_active="$4"

  # ... existing logic unchanged ...

  local brain_part=""
  [[ "${thinking_active}" == "1" ]] && brain_part=" 🧠"

  echo "${CONTEXT_ICON} ${GRAY}[${NC}${bar}${GRAY}]${NC} ${context_percent}% ${usage_formatted}/${size_formatted}${brain_part}${message_part}"
}
```

### 4. Caller: `main()`

Pass `thinking_active` when building the context component:

```bash
context_part=$(build_context_component "${context_size}" "${current_usage}" "${context_percent}" "${thinking_active}")
```

## Testing

### Unit tests (`tests/unit.sh`)

Two new cases for `build_context_component`:

| `thinking_active` | Expected output contains |
|---|---|
| `"1"` | `🧠` |
| `"0"` | no `🧠` |

### Integration tests (`tests/integration.sh`)

Two new inline JSON payloads (no new fixture files needed):

| Payload | Expected |
|---|---|
| `"effort": {"level": "max"}, "thinking": {"enabled": true}` | output contains `🧠` |
| `"effort": {"level": "high"}, "thinking": {"enabled": true}` | output does not contain `🧠` |
| `effort` field absent entirely | output does not contain `🧠` |

`bool_val` is exercised indirectly through the parser integration tests — no isolated unit test needed.

## Files Changed

| File | Change |
|---|---|
| `statusline.sh` | Add `bool_val` awk helper; extract 7th field; update line count check; add `thinking_active` read; update `build_context_component` signature and body; update call in `main()` |
| `tests/unit.sh` | 2 new test cases for `build_context_component` |
| `tests/integration.sh` | 2–3 new inline JSON test cases |

## Non-Goals

- Displaying the raw `effort.level` value in the statusline
- Supporting partial condition (effort alone or thinking alone)
- Any configuration flag to disable the indicator — absence of `effort=max+thinking=true` is sufficient
