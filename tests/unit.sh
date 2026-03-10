#!/usr/bin/env bash
# Unit tests for statusline.sh components

set -euo pipefail

# Source the statusline functions by extracting everything except the main call
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source_statusline_functions() {
  local temp_file
  temp_file=$(mktemp)
  sed '$d' "${SCRIPT_DIR}/statusline.sh" > "${temp_file}"
  # shellcheck source=/dev/null  # Dynamic temp file - runtime-generated content
  source "${temp_file}"
  rm -f "${temp_file}"
}

source_statusline_functions

passed=0
failed=0
bar_width=$(eval 'printf "%s" "${BAR_WIDTH}"')
show_messages=$(eval 'printf "%s" "${SHOW_MESSAGES}"')
show_cost=$(eval 'printf "%s" "${SHOW_COST}"')
red=$(eval 'printf "%s" "${RED}"')
green=$(eval 'printf "%s" "${GREEN}"')
nc=$(eval 'printf "%s" "${NC}"')
cyan=$(eval 'printf "%s" "${CYAN}"')
blue=$(eval 'printf "%s" "${BLUE}"')
magenta=$(eval 'printf "%s" "${MAGENTA}"')
orange=$(eval 'printf "%s" "${ORANGE}"')

test() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "${expected}" == "${actual}" ]]; then
    echo -e "${green}✓${nc} ${name}"
    passed=$((passed + 1))
  else
    echo -e "${red}✗${nc} ${name}"
    echo "  Expected: ${expected}"
    echo "  Got:      ${actual}"
    failed=$((failed + 1))
  fi
}

strip_ansi() {
  sed -E $'s/\033\\[[0-9;]*m//g; s/\\\\033\\[[0-9;]*m//g'
}

echo "========================================="
echo "Unit Tests for statusline.sh"
echo "========================================="

# Test get_dirname()
echo ""
echo "Testing get_dirname()..."
result=$(get_dirname "/home/user/my-project")
test "get_dirname unix path" "my-project" "${result}"
result=$(get_dirname 'C:\projetos\meu-projeto')
test "get_dirname windows path (MINGW)" "meu-projeto" "${result}"
result=$(get_dirname 'C:/projetos/meu-projeto')
test "get_dirname windows forward slashes" "meu-projeto" "${result}"

# Test format_number()
echo ""
echo "Testing format_number()..."
result=$(format_number 999)
test "format_number 999" "999" "${result}"
result=$(format_number 1000)
test "format_number 1000" "1.0K" "${result}"
result=$(format_number 10000)
test "format_number 10000" "10K" "${result}"
result=$(format_number 54000)
test "format_number 54000" "54K" "${result}"
result=$(format_number 999999)
test "format_number 999999" "999K" "${result}"
result=$(format_number 1000000)
test "format_number 1000000" "1.0M" "${result}"
result=$(format_number 10000000)
test "format_number 10000000" "10M" "${result}"

# Test clamp_percent()
echo ""
echo "Testing clamp_percent()..."
result=$(clamp_percent -10)
test "clamp_percent negative" "0" "${result}"
result=$(clamp_percent 28)
test "clamp_percent valid" "28" "${result}"
result=$(clamp_percent 120)
test "clamp_percent overflow" "100" "${result}"
result=$(clamp_percent "bad")
test "clamp_percent invalid" "0" "${result}"

# Test get_context_message() returns non-empty strings
echo ""
echo "Testing get_context_message()..."
for percent in 10 25 50 75 95; do
  message=$(get_context_message "${percent}")
  if [[ -n "${message}" ]]; then
    echo -e "${green}✓${nc} get_context_message ${percent}% returned: \"${message}\""
    passed=$((passed + 1))
  else
    echo -e "${red}✗${nc} get_context_message ${percent}% returned empty"
    failed=$((failed + 1))
  fi
done

# Test tier boundaries
echo ""
echo "Testing message tier boundaries..."
# Test tier boundaries by verifying get_context_tier() returns correct tier
tier_19=$(get_context_tier 19)
test "tier boundary 19% (tier 0)" "0" "${tier_19}"

tier_20=$(get_context_tier 20)
test "tier boundary 20% (tier 0)" "0" "${tier_20}"

tier_21=$(get_context_tier 21)
test "tier boundary 21% (tier 1)" "1" "${tier_21}"

tier_40=$(get_context_tier 40)
test "tier boundary 40% (tier 1)" "1" "${tier_40}"

tier_41=$(get_context_tier 41)
test "tier boundary 41% (tier 2)" "2" "${tier_41}"

tier_60=$(get_context_tier 60)
test "tier boundary 60% (tier 2)" "2" "${tier_60}"

tier_61=$(get_context_tier 61)
test "tier boundary 61% (tier 3)" "3" "${tier_61}"

tier_80=$(get_context_tier 80)
test "tier boundary 80% (tier 3)" "3" "${tier_80}"

tier_81=$(get_context_tier 81)
test "tier boundary 81% (tier 4)" "4" "${tier_81}"

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
result=$(build_model_component "claude-3-opus" | strip_ansi)
expected="🤖 claude-3-opus"
test "build_model_component" "${expected}" "${result}"

# Test build_cost_component() with security validation
echo ""
echo "Testing build_cost_component()..."
result=$(build_cost_component "1.50" | strip_ansi)
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
result=$(build_files_component "5" | strip_ansi)
expected="✏️ changes"
test "build_files_component 5 files" "${expected}" "${result}"
result=$(build_files_component "1" | strip_ansi)
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
temp_result=$(build_context_component "200000" "50000" "25" | strip_ansi)
if [[ "${show_messages}" == "true" ]]; then
  if echo "${temp_result}" | grep -qE '\|'; then
    echo -e "${green}✓${nc} Context component with SHOW_MESSAGES=true shows separator"
    passed=$((passed + 1))
  else
    echo -e "${red}✗${nc} Context component doesn't show separator when SHOW_MESSAGES=true"
    failed=$((failed + 1))
  fi
else
  if echo "${temp_result}" | grep -qE '\|'; then
    echo -e "${red}✗${nc} Context component with SHOW_MESSAGES=false still shows separator"
    failed=$((failed + 1))
  else
    echo -e "${green}✓${nc} Context component respects SHOW_MESSAGES=false"
    passed=$((passed + 1))
  fi
fi

echo ""
echo "Testing parse_claude_input()..."
parsed=$(parse_claude_input '{
  "model": {"id": "claude-sonnet-4-6"},
  "workspace": {"project_dir": "/tmp/project-dir"},
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 1000,
      "output_tokens": 500,
      "cache_creation_input_tokens": 200,
      "cache_read_input_tokens": 300
    },
    "used_percentage": 17
  },
  "cost": {"total_cost_usd": 1.25}
}')
parsed_line_1=""
parsed_line_2=""
parsed_line_3=""
parsed_line_4=""
parsed_line_5=""
parsed_line_6=""
{
  read -r parsed_line_1
  read -r parsed_line_2
  read -r parsed_line_3
  read -r parsed_line_4
  read -r parsed_line_5
  read -r parsed_line_6
} <<< "${parsed}"
test "parse_claude_input model fallback" "claude-sonnet-4-6" "${parsed_line_1}"
test "parse_claude_input project_dir fallback" "/tmp/project-dir" "${parsed_line_2}"
test "parse_claude_input context size" "200000" "${parsed_line_3}"
test "parse_claude_input current usage includes output tokens" "2000" "${parsed_line_4}"
test "parse_claude_input used_percentage" "17" "${parsed_line_5}"
test "parse_claude_input cost" "1.25" "${parsed_line_6}"

parsed=$(parse_claude_input '{
  "model": {"display_name": "Test"},
  "workspace": {"current_dir": "/tmp/fallback"},
  "context_window": {
    "context_window_size": 1000,
    "used_percentage": 25
  }
}')
{
  read -r _
  read -r _
  read -r _
  read -r parsed_line_4
  read -r parsed_line_5
  read -r _
} <<< "${parsed}"
test "parse_claude_input keeps current usage at zero when counters are missing" "0" "${parsed_line_4}"
test "parse_claude_input keeps explicit percentage" "25" "${parsed_line_5}"

parsed=$(parse_claude_input '{
  "model": {"display_name": "Test"},
  "workspace": {"current_dir": "/tmp/fallback"},
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {"input_tokens": 1000},
    "used_percentage": 150
  }
}')
{
  read -r _
  read -r _
  read -r _
  read -r _
  read -r parsed_line_5
  read -r _
} <<< "${parsed}"
test "parse_claude_input preserves raw used_percentage before clamp" "150" "${parsed_line_5}"

echo ""
echo "Testing build_context_component()..."
result=$(build_context_component "200000" "55460" "28" | strip_ansi)
if echo "${result}" | grep -q "28% 55K/200K"; then
  echo -e "${green}✓${nc} build_context_component uses provided percentage and formatted usage"
  passed=$((passed + 1))
else
  echo -e "${red}✗${nc} build_context_component missing expected percentage/usage"
  echo "  Output: ${result}"
  failed=$((failed + 1))
fi
result=$(build_context_component "200000" "2000" "150" | strip_ansi)
if echo "${result}" | grep -q "100% 2.0K/200K"; then
  echo -e "${green}✓${nc} build_context_component clamps overflow percentage"
  passed=$((passed + 1))
else
  echo -e "${red}✗${nc} build_context_component failed to clamp overflow percentage"
  echo "  Output: ${result}"
  failed=$((failed + 1))
fi
result=$(build_context_component "200000" "2000" "-5" | strip_ansi)
if echo "${result}" | grep -q "0% 2.0K/200K"; then
  echo -e "${green}✓${nc} build_context_component clamps negative percentage"
  passed=$((passed + 1))
else
  echo -e "${red}✗${nc} build_context_component failed to clamp negative percentage"
  echo "  Output: ${result}"
  failed=$((failed + 1))
fi

echo ""
echo "Testing build_directory_component()..."
result=$(build_directory_component "/tmp/my-project" | strip_ansi)
test "build_directory_component valid path" "📁 my-project" "${result}"
result=$(build_directory_component "../../etc" | strip_ansi)
test "build_directory_component invalid path falls back to PWD" "📁 $(basename "${PWD}")" "${result}"

# Test cost component (reads from global SHOW_COST)
temp_result=$(build_cost_component "1.50")
if [[ "${show_cost}" == "true" ]]; then
  if [[ -n "${temp_result}" ]]; then
    echo -e "${green}✓${nc} Cost component with SHOW_COST=true shows cost"
    passed=$((passed + 1))
  else
    echo -e "${red}✗${nc} Cost component doesn't show cost when enabled"
    failed=$((failed + 1))
  fi
else
  if [[ -z "${temp_result}" ]]; then
    echo -e "${green}✓${nc} Cost component respects SHOW_COST=false"
    passed=$((passed + 1))
  else
    echo -e "${red}✗${nc} Cost component with SHOW_COST=false shows cost: ${temp_result}"
    failed=$((failed + 1))
  fi
fi

# Test build_progress_bar() with Unicode characters
echo ""
echo "Testing build_progress_bar() UTF-8 handling..."

# Build a 50% progress bar
bar_50=$(build_progress_bar 50)

# Strip ANSI codes for verification
bar_stripped=$(echo -e "${bar_50}" | strip_ansi)

# Count UTF-8 characters (should be BAR_WIDTH total)
char_count=$(( $(echo -n "${bar_stripped}" | wc -m) ))
test "progress bar character count (50%)" "${bar_width}" "${char_count}"

# Verify no broken encoding (no question marks or replacement chars)
if echo "${bar_stripped}" | grep -q "?"; then
  echo -e "${red}✗${nc} UTF-8 encoding broken (found '?')"
  failed=$((failed + 1))
else
  echo -e "${green}✓${nc} UTF-8 encoding intact (no '?')"
  passed=$((passed + 1))
fi

# Verify correct Unicode characters are used
if echo "${bar_stripped}" | grep -q "█"; then
  echo -e "${green}✓${nc} Uses Unicode filled block (█)"
  passed=$((passed + 1))
else
  echo -e "${red}✗${nc} Missing Unicode filled block"
  failed=$((failed + 1))
fi

if echo "${bar_stripped}" | grep -q "░"; then
  echo -e "${green}✓${nc} Uses Unicode light shade (░)"
  passed=$((passed + 1))
else
  echo -e "${red}✗${nc} Missing Unicode light shade"
  failed=$((failed + 1))
fi

# Test edge cases
bar_0=$(build_progress_bar 0)
bar_0_stripped=$(echo -e "${bar_0}" | strip_ansi)
empty_0_count=$(( $(echo -n "${bar_0_stripped}" | grep -o "░" | wc -l) ))
test "0% progress bar (all empty)" "${bar_width}" "${empty_0_count}"

bar_100=$(build_progress_bar 100)
bar_100_stripped=$(echo -e "${bar_100}" | strip_ansi)
filled_100_count=$(( $(echo -n "${bar_100_stripped}" | grep -o "█" | wc -l) ))
test "100% progress bar (all filled)" "${bar_width}" "${filled_100_count}"

# Test get_random_message_color()
echo ""
echo "Testing get_random_message_color()..."

# Helper functions for pass/fail
pass() {
  echo -e "${green}✓${nc} $1"
  passed=$((passed + 1))
}

fail() {
  echo -e "${red}✗${nc} $1"
  failed=$((failed + 1))
}

# Test that get_random_message_color returns a valid color
color=$(get_random_message_color)

# Verify it's one of the 5 valid colors
valid=false
for expected in "${green}" "${cyan}" "${blue}" "${magenta}" "${orange}"; do
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
    # Validate JSON structure using node (JSON.parse for correctness)
    if node -e "
      var d = JSON.parse(require('fs').readFileSync(process.argv[process.argv.length-1],'utf8'));
      if (!d.very_low || !d.low || !d.medium || !d.high || !d.critical) process.exit(1);
    " "${lang_file}" 2>/dev/null; then
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
    # Count messages in each tier using node (single call for all tiers)
    tier_counts=$(node -e "
      var d = JSON.parse(require('fs').readFileSync(process.argv[process.argv.length-1],'utf8'));
      ['very_low','low','medium','high','critical'].forEach(function(t) {
        process.stdout.write(d[t].length + '\n');
      });
    " "${lang_file}" 2>/dev/null)

    very_low_count="" low_count="" medium_count="" high_count="" critical_count=""
    {
      IFS= read -r very_low_count
      IFS= read -r low_count
      IFS= read -r medium_count
      IFS= read -r high_count
      IFS= read -r critical_count
    } <<< "${tier_counts}"

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
echo -e "Tests passed: ${green}${passed}${nc}"
echo -e "Tests failed: ${red}${failed}${nc}"
echo "========================================="

if [[ "${failed}" -eq 0 ]]; then
  echo -e "${green}All tests passed!${nc}"
  exit 0
else
  echo -e "${red}Some tests failed!${nc}"
  exit 1
fi
