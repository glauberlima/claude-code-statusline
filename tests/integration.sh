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
  local expected_substring="${3:-}"  # Optional third parameter

  TOTAL=$((TOTAL + 1))

  local output
  local exit_code=0
  output=$(echo "${json_input}" | "${SCRIPT_DIR}/statusline.sh" 2>&1) || exit_code=$?

  if [[ ${exit_code} -ne 0 ]]; then
    echo -e "${RED}✗${NC} ${test_name}"
    echo "  Exit code: ${exit_code}"
    echo "  Output: ${output}"
    FAILED=$((FAILED + 1))
    return 0
  fi

  # If expected substring provided, verify it exists in output
  if [[ -n "${expected_substring}" ]]; then
    if echo "${output}" | grep -q "${expected_substring}"; then
      echo -e "${GREEN}✓${NC} ${test_name}"
      PASSED=$((PASSED + 1))
    else
      echo -e "${RED}✗${NC} ${test_name} (missing expected content)"
      echo "  Expected substring: ${expected_substring}"
      echo "  Actual output: ${output}"
      FAILED=$((FAILED + 1))
    fi
  else
    echo -e "${GREEN}✓${NC} ${test_name}"
    PASSED=$((PASSED + 1))
  fi

  return 0  # Always return 0 to prevent set -e from exiting script early
}

main() {
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
  }' "Opus"

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

  # Fixture-Based Tests
  echo ""
  echo -e "${YELLOW}=== Fixture-Based Tests ===${NC}"

  # Test 8: Fixture test (validates checked-in fixture)
  local fixture_content
  fixture_content=$(cat "${SCRIPT_DIR}/tests/fixtures/test-input.json")
  run_test "Fixture: test-input.json" "${fixture_content}" "Test Model"

  # Security Tests
  echo ""
  echo -e "${YELLOW}=== Security Tests ===${NC}"

  # Helper: test path-based security with given current_dir
  run_path_security_test() {
    local test_name="$1"
    local current_dir="$2"
    local json
    json='{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "'"${current_dir}"'"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000}
    }
  }'
    run_test "Security: ${test_name}" "${json}"
  }

  # Test 9-10, 12: Path-based security tests
  run_path_security_test "Directory traversal (../../../../etc)" "../../../../etc"
  run_path_security_test "Absolute path (/tmp/malicious)" "/tmp/malicious"
  run_path_security_test "Tilde path (~/.ssh)" "~/.ssh"

  # Test 11: Format string injection in cost
  run_test "Security: Format string injection (%x %x %x)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000}
    },
    "cost": {"total_cost_usd": "%x %x %x"}
  }'

  # Test 13: Invalid cost values
  run_test "Security: Non-numeric cost (malicious)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000}
    },
    "cost": {"total_cost_usd": "malicious_string"}
  }'

  # Unicode Character Tests
  # Note: language is statically compiled into statusline.sh via patch-statusline.sh.
  # Dynamic language switching via env vars is not supported at runtime.
  echo -e "\n${YELLOW}=== Unicode Character Tests ===${NC}"

  # Test 14: Filled blocks appear at 50% context
  run_test "Unicode: filled blocks (█) appear at 50% context" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 100000}
    }
  }' "█"

  # Test 15: Empty blocks appear at 5% context
  run_test "Unicode: empty blocks (░) appear at 5% context" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 10000}
    }
  }' "░"

  # Test 16: Near-full bar at 95% context still shows filled blocks
  run_test "Unicode: near-full bar (95% context) shows filled blocks" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 190000}
    }
  }' "█"

  # Default Behavior Tests
  # Note: SHOW_MESSAGES and SHOW_COST are hardcoded constants in statusline.sh (both false
  # by default in the base script). Feature toggling requires patching via patch-statusline.sh.
  echo -e "\n${YELLOW}=== Default Behavior Tests ===${NC}"

  # Test 17: Model name appears in output
  run_test "Default: model name appears in output" '{
    "model": {"display_name": "UniqueModelName"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 50000}
    }
  }' "UniqueModelName"

  # Test 18: Directory name appears in output
  run_test "Default: directory name appears in output" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "/home/user/myproject"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 50000}
    }
  }' "myproject"

  # Test 19: Cost data present but SHOW_COST=false — script still exits 0
  run_test "Default: cost data present, script exits cleanly" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 50000}
    },
    "cost": {"total_cost_usd": 9.99}
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
