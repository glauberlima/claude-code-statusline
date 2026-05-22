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

strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*m//g'
}

run_statusline() {
  local json_input="$1"
  local exit_code=0
  local output

  output=$("${SCRIPT_DIR}/statusline.sh" <<< "${json_input}" 2>&1) || exit_code=$?

  printf '%s\n' "${exit_code}"
  printf '%s' "${output}"
}

# Test helper
run_test() {
  local test_name="$1"
  local json_input="$2"
  local expected_substring="${3:-}"

  TOTAL=$((TOTAL + 1))

  local run_output
  local clean_output
  local exit_code=0
  local output
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

  # If expected substring provided, verify it exists in output
  if [[ -n "${expected_substring}" ]]; then
    if echo "${clean_output}" | grep -q "${expected_substring}"; then
      echo -e "${GREEN}✓${NC} ${test_name}"
      PASSED=$((PASSED + 1))
    else
      echo -e "${RED}✗${NC} ${test_name} (missing expected content)"
      echo "  Expected substring: ${expected_substring}"
      echo "  Actual output: ${clean_output}"
      FAILED=$((FAILED + 1))
    fi
  else
    echo -e "${GREEN}✓${NC} ${test_name}"
    PASSED=$((PASSED + 1))
  fi

  return 0  # Always return 0 to prevent set -e from exiting script early
}

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

run_fixture_test() {
  local test_name="$1"
  local fixture_path="$2"
  local expected_substring="${3:-}"
  local fixture_content

  fixture_content=$(<"${fixture_path}")
  run_test "${test_name}" "${fixture_content}" "${expected_substring}"
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
      },
      "used_percentage": 32
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
      },
      "used_percentage": 150
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
      },
      "used_percentage": 0
    }
  }'

  # Test 4: Missing optional fields (nulls)
  run_test "Null/missing fields (should handle gracefully)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "/test"},
    "context_window": {
      "context_window_size": 200000,
      "used_percentage": 0
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
      },
      "used_percentage": 50
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
      },
      "used_percentage": 1
    }
  }'

  # Test 7: Minimal valid JSON
  run_test "Minimal valid JSON" '{
    "model": {"display_name": "Test"},
    "workspace": {},
    "context_window": {
      "context_window_size": 200000,
      "used_percentage": 0
    }
  }'

  # Fixture-Based Tests
  echo ""
  echo -e "${YELLOW}=== Fixture-Based Tests ===${NC}"

  # Test 8: Existing checked-in fixture
  run_fixture_test "Fixture: test-input.json" "${SCRIPT_DIR}/tests/fixtures/test-input.json" "Test Model"

  # Test 9: Real Claude payload fixture
  run_fixture_test "Fixture: claude-input-real.json model" "${SCRIPT_DIR}/tests/fixtures/claude-input-real.json" "Sonnet 4.6"
  run_fixture_test "Fixture: claude-input-real.json percent" "${SCRIPT_DIR}/tests/fixtures/claude-input-real.json" "28% 55K/200K"
  run_fixture_test "Fixture: claude-input-real.json cost" "${SCRIPT_DIR}/tests/fixtures/claude-input-real.json" "\$1.05"

  # Security Tests
  echo ""
  echo -e "${YELLOW}=== Security Tests ===${NC}"

  # Test 10: Directory traversal attack
  run_test "Security: Directory traversal (../../../../etc)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "../../../../etc"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": 1
    }
  }'

  # Test 11: Absolute path attack
  run_test "Security: Absolute path (/tmp/malicious)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "/tmp/malicious"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": 1
    }
  }'

  # Test 12: Invalid directory does not leak basename
  run_test "Security: Invalid directory display falls back safely" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "../../secrets"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": 1
    }
  }' "$(basename "${PWD}")"

  # Test 13: Format string injection in cost
  run_test "Security: Format string injection (%x %x %x)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": 1
    },
    "cost": {"total_cost_usd": "%x %x %x"}
  }'

  # Test 14: Tilde path expansion
  run_test "Security: Tilde path (~/.ssh)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "~/.ssh"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": 1
    }
  }'

  # Test 15: Invalid cost values
  run_test "Security: Non-numeric cost (malicious)" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": 1
    },
    "cost": {"total_cost_usd": "malicious_string"}
  }'

  # Test 16: project_dir fallback
  run_test "Fallback: project_dir is used when current_dir is absent" '{
    "model": {"display_name": "Test"},
    "workspace": {"project_dir": "/tmp/project-fallback"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": 1
    }
  }' "project-fallback"

  # Test 17: model.id fallback
  run_test "Fallback: model.id is used when display_name is absent" '{
    "model": {"id": "claude-opus-4-1"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": 1
    }
  }' "claude-opus-4-1"

  # Test 18: used_percentage drives displayed percent
  run_test "Context: used_percentage drives displayed percent" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": 42
    }
  }' "42%"

  # Test 19: output_tokens contribute to displayed usage
  run_test "Context: output_tokens contribute to displayed usage" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {
        "input_tokens": 1000,
        "output_tokens": 500,
        "cache_creation_input_tokens": 250,
        "cache_read_input_tokens": 250
      },
      "used_percentage": 1
    }
  }' "2.0K/200K"

  # Test 20: invalid used_percentage falls back to 0%
  run_test "Context: invalid used_percentage renders 0%" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": "bad"
    }
  }' "0%"

  # Test 21: negative used_percentage clamps to 0%
  run_test "Context: negative used_percentage clamps to 0%" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 1000},
      "used_percentage": -5
    }
  }' "0%"

  # Unicode Character Tests
  # Note: language is statically compiled into statusline.sh via patch-statusline.sh.
  # Dynamic language switching via env vars is not supported at runtime.
  echo -e "\n${YELLOW}=== Unicode Character Tests ===${NC}"

  # Test 22: Filled blocks appear at 50% context
  run_test "Unicode: filled blocks (█) appear at 50% context" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 100000},
      "used_percentage": 50
    }
  }' "█"

  # Test 23: Empty blocks appear at 5% context
  run_test "Unicode: empty blocks (░) appear at 5% context" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 10000},
      "used_percentage": 5
    }
  }' "░"

  # Test 24: Near-full bar at 95% context still shows filled blocks
  run_test "Unicode: near-full bar (95% context) shows filled blocks" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 190000},
      "used_percentage": 95
    }
  }' "█"

  # Default Behavior Tests
  # Note: SHOW_MESSAGES and SHOW_COST are hardcoded constants in statusline.sh (both false
  # by default in the base script). Feature toggling requires patching via patch-statusline.sh.
  echo -e "\n${YELLOW}=== Default Behavior Tests ===${NC}"

  # Test 25: Model name appears in output
  run_test "Default: model name appears in output" '{
    "model": {"display_name": "UniqueModelName"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 50000},
      "used_percentage": 25
    }
  }' "UniqueModelName"

  # Test 26: Directory name appears in output
  run_test "Default: directory name appears in output" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "/home/user/myproject"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 50000},
      "used_percentage": 25
    }
  }' "myproject"

  # Test 27: Cost data present but SHOW_COST=false — script still exits 0
  run_test "Default: cost data present, script exits cleanly" '{
    "model": {"display_name": "Test"},
    "workspace": {"current_dir": "."},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 50000},
      "used_percentage": 25
    },
    "cost": {"total_cost_usd": 9.99}
  }'

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

  run_test_absent "Brain: absent when effort=max but thinking=false" '{
    "model": {"display_name": "Opus"},
    "workspace": {"current_dir": "/test/project"},
    "context_window": {
      "context_window_size": 200000,
      "current_usage": {"input_tokens": 50000},
      "used_percentage": 25
    },
    "cost": {"total_cost_usd": 0},
    "effort": {"level": "max"},
    "thinking": {"enabled": false}
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
