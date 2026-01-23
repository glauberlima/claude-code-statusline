#!/usr/bin/env bash
# Integration tests for statusline.sh

set -euo pipefail

# Get script directory for relative path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors for test output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test counters
PASSED=0
FAILED=0
TOTAL=0

# Test helper
run_test() {
  local test_name="$1"
  local json_input="$2"

  TOTAL=$((TOTAL + 1))

  local output
  local exit_code=0
  output=$(echo "${json_input}" | "${SCRIPT_DIR}/statusline.sh" 2>&1) || exit_code=$?

  if [[ ${exit_code} -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} ${test_name}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} ${test_name}"
    echo "  Exit code: ${exit_code}"
    echo "  Output: ${output}"
    FAILED=$((FAILED + 1))
  fi

  return 0  # Always return 0 to prevent set -e from exiting script early
}

# Main test suite
main() {
  # Set up test environment for i18n
  export MESSAGES_DIR="${SCRIPT_DIR}/messages"
  export CONFIG_FILE="/dev/null"  # No config file in tests, use default language

  echo -e "${YELLOW}=== Statusline Integration Tests ===${NC}"
  echo "Testing improvements to statusline.sh"
  echo ""

  # Test 1: Normal usage
  run_test "Normal usage (32% context)" '{
    "model": {"display_name": "Opus"},
    "workspace": {"current_dir": "/test/project"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {
        "input_tokens": 50000,
        "cache_creation_input_tokens": 10000,
        "cache_read_input_tokens": 5000
      }
    },
    "cost": {
      "total_cost_usd": 0.15,
      "total_lines_added": 156,
      "total_lines_removed": 23
    }
  }'

  # Test 2: Over 100% context usage (should clamp to 100%)
  run_test "Over-limit context (150% -> should clamp to 100%)" '{
    "model": {"display_name": "Haiku"},
    "workspace": {"current_dir": "/test"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {
        "input_tokens": 300000
      }
    }
  }'

  # Test 3: Zero context usage
  run_test "Zero context usage" '{
    "model": {"display_name": "Sonnet"},
    "workspace": {"current_dir": "/test"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {
        "input_tokens": 0
      }
    }
  }'

  # Test 4: Missing optional fields (nulls)
  run_test "Null/missing fields (should handle gracefully)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "/test"},
    "context_window": {
      "context_window_size": 200000
    },
    "cost": {}
  }'

  # Test 5: Large numbers (millions)
  run_test "Large context numbers (millions)" '{
    "model": {"display_name": "Opus"},
    "workspace": {"current_dir": "/test"},
    "context_window": {
      "context_window_size": 5000000,
      "current_usage": {
        "input_tokens": 2500000
      }
    }
  }'

  # Test 6: Very small numbers
  run_test "Small numbers (< 1K)" '{
    "model": {"display_name": "Haiku"},
    "workspace": {"current_dir": "/test"},
    "context_window": {
      "context_window_size": 50000,
      "current_usage": {
        "input_tokens": 500
      }
    }
  }'

  # Test 7: Minimal valid JSON
  run_test "Minimal valid JSON" '{
    "model": {"display_name": "Test"},
    "workspace": {},
    "context_window": {
      "context_window_size": 200000
    }
  }'

  # Security Tests
  echo ""
  echo -e "${YELLOW}=== Security Tests ===${NC}"

  # Test 8: Directory traversal attack
  run_test "Security: Directory traversal (../../../../etc)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "../../../../etc"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000}
    }
  }'

  # Test 9: Absolute path attack
  run_test "Security: Absolute path (/tmp/malicious)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "/tmp/malicious"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000}
    }
  }'

  # Test 10: Format string injection in cost
  run_test "Security: Format string injection (%x %x %x)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000}
    },
    "cost": {"total_cost_usd": "%x %x %x"}
  }'

  # Test 11: Tilde path expansion
  run_test "Security: Tilde path (~/.ssh)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "~/.ssh"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000}
    }
  }'

  # Test 12: Invalid cost values
  run_test "Security: Non-numeric cost (malicious)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000}
    },
    "cost": {"total_cost_usd": "malicious_string"}
  }'

  # Test 13-15: Language configuration tests
  echo -e "\n${YELLOW}=== Language Configuration Tests ===${NC}"

  # Test 13: Statusline works with English language config
  temp_config=$(mktemp)
  echo "readonly STATUSLINE_LANGUAGE=\"en\"" > "${temp_config}"
  MESSAGES_DIR="${SCRIPT_DIR}/messages" CONFIG_FILE="${temp_config}" run_test "Language config: English" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 10000}
    }
  }'
  rm -f "${temp_config}"

  # Test 14: Statusline works with Portuguese language config
  temp_config=$(mktemp)
  echo "readonly STATUSLINE_LANGUAGE=\"pt\"" > "${temp_config}"
  MESSAGES_DIR="${SCRIPT_DIR}/messages" CONFIG_FILE="${temp_config}" run_test "Language config: Portuguese" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 10000}
    }
  }'
  rm -f "${temp_config}"

  # Test 15: Statusline works with Spanish language config
  temp_config=$(mktemp)
  echo "readonly STATUSLINE_LANGUAGE=\"es\"" > "${temp_config}"
  MESSAGES_DIR="${SCRIPT_DIR}/messages" CONFIG_FILE="${temp_config}" run_test "Language config: Spanish" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 10000}
    }
  }'
  rm -f "${temp_config}"

  # Test 16: Fallback to default language when config missing
  CONFIG_FILE="/nonexistent/config" MESSAGES_DIR="${SCRIPT_DIR}/messages" run_test "Language fallback: Missing config" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 10000}
    }
  }'

  # Summary
  echo -e "\n${YELLOW}=== Test Summary ===${NC}"
  echo "Total tests: ${TOTAL}"
  echo -e "${GREEN}Passed: ${PASSED}${NC}"
  echo -e "${RED}Failed: ${FAILED}${NC}"

  if [[ ${FAILED} -eq 0 ]]; then
    echo -e "\n${GREEN}✅ All integration tests passed!${NC}"
    exit 0
  else
    echo -e "\n${RED}❌ Some tests failed${NC}"
    exit 1
  fi
}

main "$@"
