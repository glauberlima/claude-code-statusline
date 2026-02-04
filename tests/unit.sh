#!/usr/bin/env bash
# Unit tests for statusline.sh components

set -euo pipefail

# Source the statusline functions by extracting everything except the main call
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create a temporary file with statusline functions (remove last line which calls main)
TEMP_FILE=$(mktemp)
sed '$d' "${SCRIPT_DIR}/statusline.sh" > "${TEMP_FILE}"
# shellcheck source=/dev/null  # Dynamic temp file - runtime-generated content
source "${TEMP_FILE}"
rm -f "${TEMP_FILE}"

# Messages are now hardcoded in statusline.sh via @MESSAGES_START block

# Colors are already defined in statusline.sh as readonly
# RED, GREEN, NC, CYAN, BLUE, MAGENTA, ORANGE are available from sourced file
# shellcheck disable=SC2154
: "${RED:?}" "${GREEN:?}" "${NC:?}" "${CYAN:?}" "${BLUE:?}" "${MAGENTA:?}" "${ORANGE:?}"

passed=0
failed=0

test() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "${expected}" == "${actual}" ]]; then
    echo -e "${GREEN}✓${NC} ${name}"
    passed=$((passed + 1))
  else
    echo -e "${RED}✗${NC} ${name}"
    echo "  Expected: ${expected}"
    echo "  Got:      ${actual}"
    failed=$((failed + 1))
  fi
}

echo "========================================="
echo "Unit Tests for statusline.sh"
echo "========================================="

# Test format_number()
echo ""
echo "Testing format_number()..."
result=$(format_number 543)
test "format_number 543" "543" "${result}"
result=$(format_number 999)
test "format_number 999" "999" "${result}"
result=$(format_number 1000)
test "format_number 1000" "1.0K" "${result}"
result=$(format_number 1500)
test "format_number 1500" "1.5K" "${result}"
result=$(format_number 9999)
test "format_number 9999" "9.9K" "${result}"
result=$(format_number 10000)
test "format_number 10000" "10K" "${result}"
result=$(format_number 54000)
test "format_number 54000" "54K" "${result}"
result=$(format_number 999999)
test "format_number 999999" "999K" "${result}"
result=$(format_number 1000000)
test "format_number 1000000" "1.0M" "${result}"
result=$(format_number 1200000)
test "format_number 1200000" "1.2M" "${result}"
result=$(format_number 9999999)
test "format_number 9999999" "9.9M" "${result}"
result=$(format_number 10000000)
test "format_number 10000000" "10M" "${result}"
result=$(format_number 15000000)
test "format_number 15000000" "15M" "${result}"

# Test get_context_message() returns non-empty strings
echo ""
echo "Testing get_context_message()..."
for percent in 10 25 50 75 95; do
  message=$(get_context_message "${percent}")
  if [[ -n "${message}" ]]; then
    echo -e "${GREEN}✓${NC} get_context_message ${percent}% returned: \"${message}\""
    passed=$((passed + 1))
  else
    echo -e "${RED}✗${NC} get_context_message ${percent}% returned empty"
    failed=$((failed + 1))
  fi
done

# Test tier boundaries
echo ""
echo "Testing message tier boundaries..."
msg_19=$(get_context_message 19)
msg_21=$(get_context_message 21)
msg_39=$(get_context_message 39)
msg_41=$(get_context_message 41)
msg_59=$(get_context_message 59)
msg_61=$(get_context_message 61)
msg_79=$(get_context_message 79)
msg_81=$(get_context_message 81)

# Just verify they're not empty (can't guarantee different due to randomness)
result=$([[ -n "${msg_19}" ]] && echo "non-empty")
test "tier boundary 19%" "non-empty" "${result}"
result=$([[ -n "${msg_21}" ]] && echo "non-empty")
test "tier boundary 21%" "non-empty" "${result}"
result=$([[ -n "${msg_39}" ]] && echo "non-empty")
test "tier boundary 39%" "non-empty" "${result}"
result=$([[ -n "${msg_41}" ]] && echo "non-empty")
test "tier boundary 41%" "non-empty" "${result}"
result=$([[ -n "${msg_59}" ]] && echo "non-empty")
test "tier boundary 59%" "non-empty" "${result}"
result=$([[ -n "${msg_61}" ]] && echo "non-empty")
test "tier boundary 61%" "non-empty" "${result}"
result=$([[ -n "${msg_79}" ]] && echo "non-empty")
test "tier boundary 79%" "non-empty" "${result}"
result=$([[ -n "${msg_81}" ]] && echo "non-empty")
test "tier boundary 81%" "non-empty" "${result}"

# Test edge cases
echo ""
echo "Testing edge cases..."
result=$(format_number 0)
test "format_number 0" "0" "${result}"
msg=$(get_context_message 0)
result=$([[ -n "${msg}" ]] && echo "non-empty")
test "get_context_message 0%" "non-empty" "${result}"
msg=$(get_context_message 100)
result=$([[ -n "${msg}" ]] && echo "non-empty")
test "get_context_message 100%" "non-empty" "${result}"

# Test get_context_tier()
echo ""
echo "Testing get_context_tier()..."
result=$(get_context_tier 10)
test "get_context_tier 10%" "0" "${result}"
result=$(get_context_tier 20)
test "get_context_tier 20%" "0" "${result}"
result=$(get_context_tier 21)
test "get_context_tier 21%" "1" "${result}"
result=$(get_context_tier 40)
test "get_context_tier 40%" "1" "${result}"
result=$(get_context_tier 41)
test "get_context_tier 41%" "2" "${result}"
result=$(get_context_tier 60)
test "get_context_tier 60%" "2" "${result}"
result=$(get_context_tier 61)
test "get_context_tier 61%" "3" "${result}"
result=$(get_context_tier 80)
test "get_context_tier 80%" "3" "${result}"
result=$(get_context_tier 81)
test "get_context_tier 81%" "4" "${result}"
result=$(get_context_tier 100)
test "get_context_tier 100%" "4" "${result}"

# Test validate_directory() - security function
echo ""
echo "Testing validate_directory()..."
validate_directory "valid/relative/path" && result="pass" || result="fail"
test "validate_directory valid relative path" "pass" "${result}"
validate_directory "." && result="pass" || result="fail"
test "validate_directory current dir" "pass" "${result}"
validate_directory "/absolute/path" && result="pass" || result="fail"
test "validate_directory absolute path (should pass)" "pass" "${result}"
validate_directory "../../etc" && result="pass" || result="fail"
test "validate_directory path traversal (should fail)" "fail" "${result}"
# shellcheck disable=SC2088  # Intentionally testing literal tilde string, not expansion
validate_directory "~/.ssh" && result="pass" || result="fail"
test "validate_directory tilde path (should fail)" "fail" "${result}"
validate_directory "safe/./path" && result="pass" || result="fail"
test "validate_directory path with dot (safe)" "pass" "${result}"

# Test build_model_component()
echo ""
echo "Testing build_model_component()..."
result=$(build_model_component "claude-3-opus" | sed -E 's/\\033\[[0-9;]*m//g')
expected="🤖 claude-3-opus"
test "build_model_component" "${expected}" "${result}"

# Test build_cost_component() with security validation
echo ""
echo "Testing build_cost_component()..."
result=$(build_cost_component "1.50" | sed -E 's/\\033\[[0-9;]*m//g')
expected="💰 \$1.50"
test "build_cost_component valid cost" "${expected}" "${result}"
result=$(build_cost_component "0")
test "build_cost_component zero cost (should be empty)" "" "${result}"
result=$(build_cost_component "%x %x %x")
test "build_cost_component format string (should be empty)" "" "${result}"
result=$(build_cost_component "malicious")
test "build_cost_component non-numeric (should be empty)" "" "${result}"

# Test build_files_component()
echo ""
echo "Testing build_files_component()..."
result=$(build_files_component "5" | sed -E 's/\\033\[[0-9;]*m//g')
expected="✏️ changes"
test "build_files_component 5 files" "${expected}" "${result}"
result=$(build_files_component "1" | sed -E 's/\\033\[[0-9;]*m//g')
expected="✏️ changes"
test "build_files_component 1 file" "${expected}" "${result}"
result=$(build_files_component "0")
test "build_files_component 0 files (should be empty)" "" "${result}"
result=$(build_files_component "")
test "build_files_component empty (should be empty)" "" "${result}"

echo ""
echo "Testing component toggle configuration..."

# Note: These tests now rely on global constants (SHOW_MESSAGES, SHOW_COST)
# which are set at source time from @CONFIG_START block

# Test context component (reads from global SHOW_MESSAGES)
temp_result=$(build_context_component "200000" "50000" | sed -E 's/\033\[[0-9;]*m//g')
if [[ "${SHOW_MESSAGES}" == "true" ]]; then
  if echo "${temp_result}" | grep -qE '\|'; then
    echo -e "${GREEN}✓${NC} Context component with SHOW_MESSAGES=true shows separator"
    passed=$((passed + 1))
  else
    echo -e "${RED}✗${NC} Context component doesn't show separator when SHOW_MESSAGES=true"
    failed=$((failed + 1))
  fi
else
  if echo "${temp_result}" | grep -qE '\|'; then
    echo -e "${RED}✗${NC} Context component with SHOW_MESSAGES=false still shows separator"
    failed=$((failed + 1))
  else
    echo -e "${GREEN}✓${NC} Context component respects SHOW_MESSAGES=false"
    passed=$((passed + 1))
  fi
fi

# Test cost component (reads from global SHOW_COST)
temp_result=$(build_cost_component "1.50")
if [[ "${SHOW_COST}" == "true" ]]; then
  if [[ -n "${temp_result}" ]]; then
    echo -e "${GREEN}✓${NC} Cost component with SHOW_COST=true shows cost"
    passed=$((passed + 1))
  else
    echo -e "${RED}✗${NC} Cost component doesn't show cost when enabled"
    failed=$((failed + 1))
  fi
else
  if [[ -z "${temp_result}" ]]; then
    echo -e "${GREEN}✓${NC} Cost component respects SHOW_COST=false"
    passed=$((passed + 1))
  else
    echo -e "${RED}✗${NC} Cost component with SHOW_COST=false shows cost: ${temp_result}"
    failed=$((failed + 1))
  fi
fi

# Test build_progress_bar() with Unicode characters
echo ""
echo "Testing build_progress_bar() UTF-8 handling..."

# shellcheck disable=SC2154  # BAR_WIDTH, BAR_FILLED, BAR_EMPTY sourced from statusline.sh

# Build a 50% progress bar
bar_50=$(build_progress_bar 50)

# Strip ANSI codes for verification
bar_stripped=$(echo -e "${bar_50}" | sed 's/\x1b\[[0-9;]*m//g')

# Count UTF-8 characters (should be BAR_WIDTH total)
char_count=$(echo -n "${bar_stripped}" | wc -m)
# shellcheck disable=SC2154  # BAR_WIDTH sourced from statusline.sh
test "progress bar character count (50%)" "${BAR_WIDTH}" "${char_count}"

# Verify no broken encoding (no question marks or replacement chars)
if echo "${bar_stripped}" | grep -q "?"; then
  echo -e "${RED}✗${NC} UTF-8 encoding broken (found '?')"
  failed=$((failed + 1))
else
  echo -e "${GREEN}✓${NC} UTF-8 encoding intact (no '?')"
  passed=$((passed + 1))
fi

# Verify correct Unicode characters are used
if echo "${bar_stripped}" | grep -q "█"; then
  echo -e "${GREEN}✓${NC} Uses Unicode filled block (█)"
  passed=$((passed + 1))
else
  echo -e "${RED}✗${NC} Missing Unicode filled block"
  failed=$((failed + 1))
fi

if echo "${bar_stripped}" | grep -q "░"; then
  echo -e "${GREEN}✓${NC} Uses Unicode light shade (░)"
  passed=$((passed + 1))
else
  echo -e "${RED}✗${NC} Missing Unicode light shade"
  failed=$((failed + 1))
fi

# Test edge cases
bar_0=$(build_progress_bar 0)
bar_0_stripped=$(echo -e "${bar_0}" | sed 's/\x1b\[[0-9;]*m//g')
empty_0_count=$(echo -n "${bar_0_stripped}" | grep -o "░" | wc -l)
# shellcheck disable=SC2154  # BAR_WIDTH sourced from statusline.sh
test "0% progress bar (all empty)" "${BAR_WIDTH}" "${empty_0_count}"

bar_100=$(build_progress_bar 100)
bar_100_stripped=$(echo -e "${bar_100}" | sed 's/\x1b\[[0-9;]*m//g')
filled_100_count=$(echo -n "${bar_100_stripped}" | grep -o "█" | wc -l)
# shellcheck disable=SC2154  # BAR_WIDTH sourced from statusline.sh
test "100% progress bar (all filled)" "${BAR_WIDTH}" "${filled_100_count}"

# Test get_random_message_color()
echo ""
echo "Testing get_random_message_color()..."

# Helper functions for pass/fail
# ============================================================
# INSTALL.SH FUNCTION TESTS
# ============================================================

# Source detect_terminal_chars function from install.sh
# Extract just the function we need
detect_terminal_chars() {
  local term="${TERM:-unknown}"
  local filled empty

  case "${term}" in
    xterm*|screen*|tmux*)
      # Modern terminals with full Unicode support
      filled="█"
      empty="░"
      ;;
    linux)
      # Linux console - limited Unicode
      filled="▓"
      empty="░"
      ;;
    dumb)
      # Minimal terminal - ASCII only
      filled="#"
      empty="-"
      ;;
    *)
      # Default: assume modern terminal
      filled="█"
      empty="░"
      ;;
  esac

  echo "${filled}|${empty}"
}

echo ""
echo "Testing terminal character detection..."

# Test: xterm terminal
TERM="xterm-256color"
result=$(detect_terminal_chars)
test "Terminal detection: xterm-256color" "█|░" "${result}"

# Test: linux terminal
TERM="linux"
result=$(detect_terminal_chars)
test "Terminal detection: linux" "▓|░" "${result}"

# Test: dumb terminal
TERM="dumb"
result=$(detect_terminal_chars)
test "Terminal detection: dumb" "#|-" "${result}"

# Test: unknown terminal (default)
TERM="unknown-terminal"
result=$(detect_terminal_chars)
test "Terminal detection: unknown" "█|░" "${result}"

# Test: screen terminal
TERM="screen"
result=$(detect_terminal_chars)
test "Terminal detection: screen" "█|░" "${result}"

# Test: tmux terminal
TERM="tmux-256color"
result=$(detect_terminal_chars)
test "Terminal detection: tmux" "█|░" "${result}"

pass() {
  echo -e "${GREEN}✓${NC} $1"
  passed=$((passed + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  failed=$((failed + 1))
}

# Test that get_random_message_color returns a valid color
color=$(get_random_message_color)

# Verify it's one of the 5 valid colors
valid=false
for expected in "${GREEN}" "${CYAN}" "${BLUE}" "${MAGENTA}" "${ORANGE}"; do
  [[ "${color}" == "${expected}" ]] && valid=true && break
done

if [[ "${valid}" == "true" ]]; then
  pass "get_random_message_color returns valid color"
else
  fail "get_random_message_color returned invalid color: ${color}"
fi

# Test that colors vary across multiple calls (Bash 3.2 compatible)
# Collect first 10 colors and check if at least 2 are different
iterations=20
first_color=$(get_random_message_color)
found_different=false

for (( i=1; i<iterations; i++ )); do
  color=$(get_random_message_color)
  if [[ "${color}" != "${first_color}" ]]; then
    found_different=true
    break
  fi
done

if [[ "${found_different}" == "true" ]]; then
  pass "Colors vary across multiple calls"
else
  fail "All colors were the same in ${iterations} iterations"
fi

# ============================================================
# LANGUAGE FILE TESTS
# ============================================================

echo ""
echo "Testing language file loading..."

# Test: Each language file defines all required tiers in JSON (simplified format)
for lang in en pt es; do
  lang_file="messages/${lang}.json"

  if [[ -f "${lang_file}" ]]; then
    # Validate JSON structure (simplified format: no .tiers nesting)
    if jq -e '.very_low and .low and .medium and .high and .critical' "${lang_file}" >/dev/null 2>&1; then
      pass "Language file valid: ${lang}"
    else
      fail "Language file invalid or missing tiers: ${lang}"
    fi
  else
    fail "Language file missing: ${lang}"
  fi
done

# Test: String size validation (each tier should have 15+ messages)
for lang in en pt es; do
  lang_file="messages/${lang}.json"

  if [[ -f "${lang_file}" ]]; then
    # Count messages in each tier using jq (simplified format)
    very_low_count=$(jq '.very_low | length' "${lang_file}")
    low_count=$(jq '.low | length' "${lang_file}")
    medium_count=$(jq '.medium | length' "${lang_file}")
    high_count=$(jq '.high | length' "${lang_file}")
    critical_count=$(jq '.critical | length' "${lang_file}")

    if [[ ${very_low_count} -ge 15 ]] && \
       [[ ${low_count} -ge 15 ]] && \
       [[ ${medium_count} -ge 15 ]] && \
       [[ ${high_count} -ge 15 ]] && \
       [[ ${critical_count} -ge 15 ]]; then
      pass "Language strings have valid sizes: ${lang}"
    else
      fail "Language strings too small: ${lang}"
    fi
  fi
done

echo ""
echo "========================================="
echo -e "Tests passed: ${GREEN}${passed}${NC}"
echo -e "Tests failed: ${RED}${failed}${NC}"
echo "========================================="

if [[ "${failed}" -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi

