#!/usr/bin/env bash
# install.sh - Install statusline by creating symlink to ~/.claude/statusline.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${SCRIPT_DIR}/statusline.sh"
TARGET_DIR="${HOME}/.claude"
TARGET_FILE="${TARGET_DIR}/statusline.sh"

echo "Installing statusline.sh..."

# Create ~/.claude directory if it doesn't exist
if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Creating directory: ${TARGET_DIR}"
  mkdir -p "${TARGET_DIR}"
fi

# Remove existing file/symlink if present
if [[ -e "${TARGET_FILE}" ]] || [[ -L "${TARGET_FILE}" ]]; then
  echo "Removing existing file: ${TARGET_FILE}"
  rm -f "${TARGET_FILE}"
fi

# Create symlink
echo "Creating symlink: ${TARGET_FILE} -> ${SOURCE_FILE}"
ln -s "${SOURCE_FILE}" "${TARGET_FILE}"

# Verify installation
if [[ -L "${TARGET_FILE}" ]]; then
  echo "✓ Installation successful!"
  echo "  Source: ${SOURCE_FILE}"
  echo "  Target: ${TARGET_FILE}"
  echo ""
  echo "You can now use this statusline in Claude Code by configuring:"
  echo "  ~/.claude/settings.json"
else
  echo "✗ Installation failed!"
  exit 1
fi
