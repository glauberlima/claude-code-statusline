#!/usr/bin/env bash
# install.sh - Installer for statusline.sh
# Downloads statusline.sh from GitHub and installs to ~/.claude/statusline.sh

set -euo pipefail

# Configuration
readonly TARGET_DIR="${HOME}/.claude"
readonly TARGET_FILE="${TARGET_DIR}/statusline.sh"
readonly GITHUB_RAW_URL="${STATUSLINE_INSTALL_URL:-https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/statusline.sh}"

# Temporary file for downloads (set in main)
TEMP_FILE=""

# Cleanup function for trap
cleanup_on_error() {
  [[ -n "${TEMP_FILE}" ]] && [[ -f "${TEMP_FILE}" ]] && rm -f "${TEMP_FILE}"
  echo "Installation failed. No changes made."
  exit 1
}

# Check bash version (3.2+)
check_bash_version() {
  if [[ "${BASH_VERSINFO[0]}" -lt 3 ]] || \
     [[ "${BASH_VERSINFO[0]}" -eq 3 && "${BASH_VERSINFO[1]}" -lt 2 ]]; then
    echo "Error: bash 3.2+ required (found ${BASH_VERSION})"
    return 1
  fi
  return 0
}

# Check git version (2.11+)
check_git_version() {
  local git_version_str major minor

  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi

  git_version_str=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)

  if [[ -z "${git_version_str}" ]]; then
    return 1
  fi

  major=$(echo "${git_version_str}" | cut -d. -f1)
  minor=$(echo "${git_version_str}" | cut -d. -f2)

  if [[ "${major}" -lt 2 ]] || \
     [[ "${major}" -eq 2 && "${minor}" -lt 11 ]]; then
    return 1
  fi

  return 0
}

# Validate all dependencies
check_dependencies() {
  local missing=()

  # Check bash version
  # shellcheck disable=SC2310  # Intentional: explicit check in conditional
  if ! check_bash_version; then
    missing+=("bash 3.2+")
  fi

  # Check jq
  if ! command -v jq >/dev/null 2>&1; then
    missing+=("jq")
  fi

  # Check git version
  # shellcheck disable=SC2310  # Intentional: explicit check in conditional
  if ! check_git_version; then
    missing+=("git 2.11+")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    show_install_instructions "${missing[@]}"
    return 1
  fi

  return 0
}

# Show platform-specific installation instructions for missing dependencies
show_install_instructions() {
  local deps=("$@")
  local platform
  platform=$(uname -s 2>/dev/null || echo "Unknown")

  echo "❌ Missing dependencies: ${deps[*]}"
  echo ""

  case "${platform}" in
    Darwin)
      echo "Install on macOS:"
      echo "  brew install jq git"
      ;;
    Linux)
      echo "Install on Linux:"
      if command -v apt-get >/dev/null 2>&1; then
        echo "  sudo apt-get install jq git"
      elif command -v yum >/dev/null 2>&1; then
        echo "  sudo yum install jq git"
      elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install jq git"
      else
        echo "  Use your package manager to install: jq git"
      fi
      ;;
    *)
      echo "Please install the following dependencies:"
      echo "  - jq 1.5+"
      echo "  - git 2.11+"
      echo "  - bash 3.2+"
      ;;
  esac

  echo ""
  echo "Installation aborted. Install dependencies and try again."
}

# Download file with curl/wget fallback
download_file() {
  local url="$1"
  local dest="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" -o "${dest}" 2>/dev/null
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "${dest}" "${url}" 2>/dev/null
  else
    echo "Error: curl or wget required for remote installation"
    return 1
  fi

  # Validate download succeeded and file is not empty
  if [[ ! -s "${dest}" ]]; then
    echo "Error: Download failed or file is empty"
    return 1
  fi

  return 0
}

# Validate downloaded file
validate_file() {
  local file="$1"

  # Check file exists and not empty
  if [[ ! -s "${file}" ]]; then
    echo "Error: File does not exist or is empty"
    return 1
  fi

  # Check contains bash shebang
  if ! head -n1 "${file}" 2>/dev/null | grep -q '^#!/.*bash'; then
    echo "Error: Invalid file format (missing bash shebang)"
    return 1
  fi

  # Sanity check for expected content
  if ! grep -q 'assemble_statusline' "${file}" 2>/dev/null; then
    echo "Error: File does not appear to be statusline.sh"
    return 1
  fi

  return 0
}

# Perform atomic installation
install_statusline() {
  local source="$1"
  local backup=""

  # Create ~/.claude if missing
  if [[ ! -d "${TARGET_DIR}" ]]; then
    mkdir -p "${TARGET_DIR}" || {
      echo "Error: Failed to create ${TARGET_DIR}"
      return 1
    }
  fi

  # Backup existing installation
  if [[ -e "${TARGET_FILE}" ]] || [[ -L "${TARGET_FILE}" ]]; then
    backup="${TARGET_FILE}.backup.$(date +%s)"
    mv "${TARGET_FILE}" "${backup}" || {
      echo "Error: Failed to backup existing installation"
      return 1
    }
    echo "Backed up existing: ${backup}"
  fi

  # Copy file to target
  cp "${source}" "${TARGET_FILE}" || {
    echo "Error: Failed to copy file"
    [[ -n "${backup}" ]] && mv "${backup}" "${TARGET_FILE}"
    return 1
  }

  # Make executable
  chmod +x "${TARGET_FILE}" || {
    echo "Error: Failed to make file executable"
    [[ -n "${backup}" ]] && mv "${backup}" "${TARGET_FILE}"
    return 1
  }

  return 0
}

# Display success message with next steps
show_success_message() {
  echo ""
  echo "✅ statusline.sh installed to ${TARGET_FILE}"
  echo ""
  echo "To update, run the installation command again."
  echo ""
  echo "Next steps:"
  echo "1. Add to ~/.claude/settings.json:"
  echo '   {'
  echo '     "statusLine": {'
  echo '       "type": "command",'
  echo '       "command": "~/.claude/statusline.sh",'
  echo '       "padding": 0'
  echo '     }'
  echo '   }'
  echo ""
  echo "2. Restart Claude Code to apply changes"
  echo ""
}

# Main installation flow
main() {
  local source_file

  # Set up cleanup trap
  trap cleanup_on_error ERR INT TERM

  echo "Installing statusline.sh..."
  echo ""

  # Check dependencies first
  echo "Checking dependencies..."
  # shellcheck disable=SC2310  # Intentional: explicit check with exit
  check_dependencies || exit 1

  echo "✅ bash ${BASH_VERSION} found"
  # shellcheck disable=SC2312  # Intentional: display version, errors not critical
  echo "✅ jq $(jq --version 2>/dev/null | grep -oE '[0-9.]+' || echo 'found')"
  # shellcheck disable=SC2312  # Intentional: display version, errors not critical
  echo "✅ git $(git --version 2>/dev/null | grep -oE '[0-9.]+' | head -n1)"
  echo ""

  # Always download from GitHub
  echo "Downloading from GitHub..."

  # Create temp file for download
  TEMP_FILE=$(mktemp "${TMPDIR:-/tmp}/statusline.XXXXXX") || {
    echo "Error: Failed to create temporary file"
    exit 1
  }

  # Download and validate
  # shellcheck disable=SC2310  # Intentional: explicit error handling
  if ! download_file "${GITHUB_RAW_URL}" "${TEMP_FILE}"; then
    cleanup_on_error
  fi

  echo "✅ Downloaded successfully"

  source_file="${TEMP_FILE}"

  # Validate file
  # shellcheck disable=SC2310  # Intentional: explicit error handling
  if ! validate_file "${source_file}"; then
    cleanup_on_error
  fi

  # Install
  echo ""
  echo "Installing to ${TARGET_FILE}..."
  # shellcheck disable=SC2310  # Intentional: explicit error handling
  if ! install_statusline "${source_file}"; then
    cleanup_on_error
  fi

  # Cleanup temp file
  [[ -n "${TEMP_FILE}" ]] && [[ -f "${TEMP_FILE}" ]] && rm -f "${TEMP_FILE}"

  # Show success message
  show_success_message

  exit 0
}

# Run main
main "$@"
