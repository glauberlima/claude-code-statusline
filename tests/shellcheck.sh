#!/usr/bin/env bash
# Shellcheck verification test - ensures all scripts pass strict linting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================"
echo "Bash Syntax & Shellcheck Verification"
echo "========================================"
echo ""

FAILED=0

# All scripts to check
FILES=(
  "${SCRIPT_DIR}/statusline.sh"
  "${SCRIPT_DIR}/patch-statusline.sh"
  "${SCRIPT_DIR}/install.sh"
  "${SCRIPT_DIR}/tests/unit.sh"
  "${SCRIPT_DIR}/tests/integration.sh"
  "${SCRIPT_DIR}/tests/shellcheck.sh"
)

# Helper: run a check on all files, track failures
run_check() {
  local label="$1"
  shift  # Remove label, remaining args are the command
  local cmd=("$@")

  for file in "${FILES[@]}"; do
    filename=$(basename "${file}")
    if "${cmd[@]}" "${file}" 2>/dev/null; then
      echo -e "${GREEN}✓${NC} ${filename}"
    else
      echo -e "${RED}✗${NC} ${filename} (${label} failed)"
      if [[ "${cmd[0]}" == "bash" ]]; then
        "${cmd[@]}" "${file}"  # Show error without suppression for bash
      fi
      FAILED=1
    fi
  done
}

# Step 1: Bash syntax validation (bash -n)
echo "Step 1: Bash Syntax Validation (bash -n)"
echo "----------------------------------------"
run_check "syntax error" bash -n

echo ""
echo "Step 2: Shellcheck Static Analysis"
echo "----------------------------------------"
run_check "shellcheck" shellcheck

echo ""
echo "========================================"
if [[ ${FAILED} -eq 0 ]]; then
  echo -e "${GREEN}All files pass syntax check and shellcheck${NC}"
  exit 0
else
  echo -e "${RED}Syntax errors or shellcheck violations found${NC}"
  exit 1
fi
