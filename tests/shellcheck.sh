#!/usr/bin/env bash
# Shellcheck verification test - ensures all scripts pass strict linting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================"
echo "Shellcheck Strict Verification"
echo "========================================"
echo ""

FAILED=0

# All scripts to check
FILES=(
  "${SCRIPT_DIR}/statusline.sh"
  "${SCRIPT_DIR}/install.sh"
  "${SCRIPT_DIR}/messages/en.sh"
  "${SCRIPT_DIR}/messages/pt.sh"
  "${SCRIPT_DIR}/messages/es.sh"
  "${SCRIPT_DIR}/tests/unit.sh"
  "${SCRIPT_DIR}/tests/integration.sh"
  "${SCRIPT_DIR}/tests/shellcheck.sh"
)

for file in "${FILES[@]}"; do
  filename=$(basename "${file}")
  if shellcheck "${file}"; then
    echo -e "${GREEN}✓${NC} ${filename}"
  else
    echo -e "${RED}✗${NC} ${filename}"
    FAILED=1
  fi
done

echo ""
echo "========================================"
if [[ ${FAILED} -eq 0 ]]; then
  echo -e "${GREEN}All files pass strict shellcheck${NC}"
  exit 0
else
  echo -e "${RED}Shellcheck violations found${NC}"
  exit 1
fi
