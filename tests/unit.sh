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

# Colors are already defined in statusline.sh as readonly
# RED, GREEN, NC are available from sourced file
# shellcheck disable=SC2154
: "${RED:?}" "${GREEN:?}" "${NC:?}"

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
test "validate_directory absolute path (should fail)" "fail" "${result}"
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
expected="🚀 claude-3-opus"
test "build_model_component" "${expected}" "${result}"

# Test build_cost_component() with security validation
echo ""
echo "Testing build_cost_component()..."
result=$(build_cost_component "1.50" | sed -E 's/\\033\[[0-9;]*m//g')
expected="💵 \$1.50"
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
expected="5 files"
test "build_files_component 5 files" "${expected}" "${result}"
result=$(build_files_component "1" | sed -E 's/\\033\[[0-9;]*m//g')
expected="1 files"
test "build_files_component 1 file" "${expected}" "${result}"
result=$(build_files_component "0")
test "build_files_component 0 files (should be empty)" "" "${result}"
result=$(build_files_component "")
test "build_files_component empty (should be empty)" "" "${result}"

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

