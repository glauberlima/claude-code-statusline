#!/usr/bin/env bash
# test_statusline.sh - Unit tests for statusline.sh

set -euo pipefail

# Source the statusline functions by extracting everything except the main call
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create a temporary file with statusline functions (remove last line which calls main)
TEMP_FILE=$(mktemp)
sed '$d' "$SCRIPT_DIR/statusline.sh" > "$TEMP_FILE"
# shellcheck source=/dev/null
source "$TEMP_FILE"
rm -f "$TEMP_FILE"

# Colors are already defined in statusline.sh as readonly
# RED, GREEN, NC are available

passed=0
failed=0

test() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$expected" == "$actual" ]]; then
    echo -e "${GREEN}✓${NC} $name"
    passed=$((passed + 1))
  else
    echo -e "${RED}✗${NC} $name"
    echo "  Expected: $expected"
    echo "  Got:      $actual"
    failed=$((failed + 1))
  fi
}

echo "========================================="
echo "Unit Tests for statusline.sh"
echo "========================================="

# Test format_number()
echo ""
echo "Testing format_number()..."
test "format_number 543" "543" "$(format_number 543)"
test "format_number 999" "999" "$(format_number 999)"
test "format_number 1000" "1.0K" "$(format_number 1000)"
test "format_number 1500" "1.5K" "$(format_number 1500)"
test "format_number 9999" "9.9K" "$(format_number 9999)"
test "format_number 10000" "10K" "$(format_number 10000)"
test "format_number 54000" "54K" "$(format_number 54000)"
test "format_number 999999" "999K" "$(format_number 999999)"
test "format_number 1000000" "1.0M" "$(format_number 1000000)"
test "format_number 1200000" "1.2M" "$(format_number 1200000)"
test "format_number 9999999" "9.9M" "$(format_number 9999999)"
test "format_number 10000000" "10M" "$(format_number 10000000)"
test "format_number 15000000" "15M" "$(format_number 15000000)"

# Test get_context_message() returns non-empty strings
echo ""
echo "Testing get_context_message()..."
for percent in 10 25 50 75 95; do
  message=$(get_context_message "$percent")
  if [[ -n "$message" ]]; then
    echo -e "${GREEN}✓${NC} get_context_message $percent% returned: \"$message\""
    passed=$((passed + 1))
  else
    echo -e "${RED}✗${NC} get_context_message $percent% returned empty"
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
test "tier boundary 19%" "non-empty" "$([ -n "$msg_19" ] && echo "non-empty")"
test "tier boundary 21%" "non-empty" "$([ -n "$msg_21" ] && echo "non-empty")"
test "tier boundary 39%" "non-empty" "$([ -n "$msg_39" ] && echo "non-empty")"
test "tier boundary 41%" "non-empty" "$([ -n "$msg_41" ] && echo "non-empty")"
test "tier boundary 59%" "non-empty" "$([ -n "$msg_59" ] && echo "non-empty")"
test "tier boundary 61%" "non-empty" "$([ -n "$msg_61" ] && echo "non-empty")"
test "tier boundary 79%" "non-empty" "$([ -n "$msg_79" ] && echo "non-empty")"
test "tier boundary 81%" "non-empty" "$([ -n "$msg_81" ] && echo "non-empty")"

# Test edge cases
echo ""
echo "Testing edge cases..."
test "format_number 0" "0" "$(format_number 0)"
test "get_context_message 0%" "non-empty" "$([ -n "$(get_context_message 0)" ] && echo "non-empty")"
test "get_context_message 100%" "non-empty" "$([ -n "$(get_context_message 100)" ] && echo "non-empty")"

echo ""
echo "========================================="
echo -e "Tests passed: ${GREEN}$passed${NC}"
echo -e "Tests failed: ${RED}$failed${NC}"
echo "========================================="

if [[ "$failed" -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi

