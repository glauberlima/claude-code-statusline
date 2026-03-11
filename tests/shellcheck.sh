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
echo "ShellCheck: https://www.shellcheck.net/"
echo ""

FAILED=0

collect_files() {
  find "${SCRIPT_DIR}" -type f -name '*.sh' | sort
}

FILES=()
file_list=$(collect_files)
while IFS= read -r file; do
  FILES+=("${file}")
done <<< "${file_list}"

run_checker() {
  local label="$1"
  shift
  for file in "${FILES[@]}"; do
    local filename
    filename=$(basename "${file}")
    if "$@" "${file}" 2>/dev/null; then
      echo -e "${GREEN}✓${NC} ${filename}"
    else
      echo -e "${RED}✗${NC} ${filename}"
      "$@" "${file}"  # Re-run to show errors
      FAILED=1
    fi
  done
}

echo "Step 1: Bash Syntax Validation (bash -n)"
echo "----------------------------------------"
run_checker "bash -n" bash -n

echo ""
echo "Step 2: Shellcheck Static Analysis"
echo "----------------------------------------"
run_checker "shellcheck" shellcheck

echo ""
echo "========================================"
if [[ ${FAILED} -eq 0 ]]; then
  echo -e "${GREEN}All files pass syntax check and shellcheck${NC}"
  exit 0
else
  echo -e "${RED}Syntax errors or shellcheck violations found${NC}"
  exit 1
fi
