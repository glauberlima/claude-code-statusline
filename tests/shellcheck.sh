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
  local file
  local files=()
  local file_list

  if command -v rg >/dev/null 2>&1; then
    file_list=$(cd "${SCRIPT_DIR}" && rg --files -g '*.sh' | sort)
    while IFS= read -r file; do
      files+=("${SCRIPT_DIR}/${file}")
    done <<< "${file_list}"
  else
    file_list=$(find "${SCRIPT_DIR}" -type f -name '*.sh' | sort)
    while IFS= read -r file; do
      files+=("${file}")
    done <<< "${file_list}"
  fi

  printf '%s\n' "${files[@]}"
}

FILES=()
file_list=$(collect_files)
while IFS= read -r file; do
  FILES+=("${file}")
done <<< "${file_list}"

# Step 1: Bash syntax validation (bash -n)
echo "Step 1: Bash Syntax Validation (bash -n)"
echo "----------------------------------------"
for file in "${FILES[@]}"; do
  filename=$(basename "${file}")
  if bash -n "${file}" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} ${filename}"
  else
    echo -e "${RED}✗${NC} ${filename} (syntax error)"
    bash -n "${file}"  # Show error without suppression
    FAILED=1
  fi
done

echo ""
echo "Step 2: Shellcheck Static Analysis"
echo "----------------------------------------"
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
  echo -e "${GREEN}All files pass syntax check and shellcheck${NC}"
  exit 0
else
  echo -e "${RED}Syntax errors or shellcheck violations found${NC}"
  exit 1
fi
