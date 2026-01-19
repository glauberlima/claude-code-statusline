#!/usr/bin/env bash
# install.sh - Installer for statusline.sh
# Downloads statusline.sh from GitHub and installs to ~/.claude/statusline.sh

set -euo pipefail

# Configuration
readonly TARGET_DIR="${HOME}/.claude"
readonly TARGET_FILE="${TARGET_DIR}/statusline.sh"
readonly SETTINGS_FILE="${HOME}/.claude/settings.json"
readonly SETTINGS_COMMAND="${HOME}/.claude/statusline.sh"
readonly GITHUB_RAW_URL="https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main/statusline.sh"
readonly EXIT_PARTIAL_FAILURE=2

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

# Generate unique timestamp for backup files
generate_timestamp() {
  # shellcheck disable=SC2312  # Intentional: fallback command in OR expression
  date +%s%N 2>/dev/null || echo "$(date +%s).$$"
}

# Extract version number from command output
extract_version() {
  local -r cmd="$1"
  "${cmd}" --version 2>/dev/null | grep -oE '[0-9.]+' | head -n1 || echo 'found'
}

# Check git version (2.11+)
check_git_version() {
  local git_version_str
  local major
  local minor

  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi

  git_version_str=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)

  if [[ -z "${git_version_str}" ]]; then
    return 1
  fi

  major=$(echo "${git_version_str}" | cut -d. -f1)
  readonly major
  minor=$(echo "${git_version_str}" | cut -d. -f2)
  readonly minor

  if [[ "${major}" -lt 2 ]] || \
     [[ "${major}" -eq 2 && "${minor}" -lt 11 ]]; then
    return 1
  fi

  return 0
}

# Validate all dependencies
check_dependencies() {
  local missing=()

  # shellcheck disable=SC2310  # Intentional: explicit check in conditional
  if ! check_bash_version; then
    missing+=("bash 3.2+")
  fi

  if ! command -v claude >/dev/null 2>&1; then
    missing+=("claude")
  fi

  if ! command -v curl >/dev/null 2>&1; then
    missing+=("curl")
  fi

  if ! command -v jq >/dev/null 2>&1; then
    missing+=("jq")
  fi

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
  local -r deps=("$@")
  local platform
  # shellcheck disable=SC2312  # Intentional: fallback command in OR expression
  platform=$(uname -s 2>/dev/null || echo "Unknown")
  readonly platform

  echo "❌ Missing dependencies: ${deps[*]}"
  echo ""

  for dep in "${deps[@]}"; do
    if [[ "${dep}" == "claude" ]]; then
      echo "Claude Code CLI:"
      echo "  Visit https://claude.ai/code for installation instructions"
      echo ""
      break
    fi
  done

  case "${platform}" in
    Darwin)
      echo "Install on macOS:"
      echo "  brew install curl jq git"
      ;;
    Linux)
      echo "Install on Linux:"
      if command -v apt-get >/dev/null 2>&1; then
        echo "  sudo apt-get install curl jq git"
      elif command -v yum >/dev/null 2>&1; then
        echo "  sudo yum install curl jq git"
      elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install curl jq git"
      else
        echo "  Use your package manager to install: curl jq git"
      fi
      ;;
    *)
      echo "Please install the following dependencies:"
      echo "  - curl"
      echo "  - jq 1.5+"
      echo "  - git 2.11+"
      echo "  - bash 3.2+"
      ;;
  esac

  echo ""
  echo "Installation aborted. Install dependencies and try again."
}

# Download file with curl
download_file() {
  local -r url="$1"
  local -r dest="$2"

  curl -fsSL "${url}" -o "${dest}" 2>/dev/null || {
    echo "Error: Failed to download from ${url}"
    return 1
  }

  if [[ ! -s "${dest}" ]]; then
    echo "Error: Downloaded file is empty"
    return 1
  fi

  return 0
}

# Validate downloaded file
validate_file() {
  local -r file="$1"

  if [[ ! -s "${file}" ]]; then
    echo "Error: File does not exist or is empty"
    return 1
  fi

  if ! head -n1 "${file}" 2>/dev/null | grep -q '^#!/.*bash'; then
    echo "Error: Invalid file format (missing bash shebang)"
    return 1
  fi

  if ! grep -q 'assemble_statusline' "${file}" 2>/dev/null; then
    echo "Error: File does not appear to be statusline.sh"
    return 1
  fi

  return 0
}

# Perform atomic installation
install_statusline() {
  local -r source="$1"
  local backup=""

  if [[ ! -d "${TARGET_DIR}" ]]; then
    mkdir -p "${TARGET_DIR}" || {
      echo "Error: Failed to create ${TARGET_DIR}"
      return 1
    }
  fi

  if [[ -L "${TARGET_DIR}" ]]; then
    echo "Error: ${TARGET_DIR} is a symbolic link (security risk)"
    return 1
  fi

  if [[ -e "${TARGET_FILE}" ]] || [[ -L "${TARGET_FILE}" ]]; then
    backup="${TARGET_FILE}.backup.$(generate_timestamp)"
    mv "${TARGET_FILE}" "${backup}" || {
      echo "Error: Failed to backup existing installation"
      return 1
    }
    echo "Backed up existing: ${backup}"
  fi

  cp "${source}" "${TARGET_FILE}" || {
    echo "Error: Failed to copy file"
    [[ -n "${backup}" ]] && mv "${backup}" "${TARGET_FILE}"
    return 1
  }

  chmod +x "${TARGET_FILE}" || {
    echo "Error: Failed to make file executable"
    [[ -n "${backup}" ]] && mv "${backup}" "${TARGET_FILE}"
    return 1
  }

  return 0
}

# Configure settings.json with statusLine configuration
configure_settings() {
  local -r settings_dir="${HOME}/.claude"
  local temp_file
  local backup_file

  mkdir -p "${settings_dir}" || {
    echo "Error: Cannot create ${settings_dir}"
    return 1
  }

  if [[ ! -f "${SETTINGS_FILE}" ]]; then
    echo "{}" > "${SETTINGS_FILE}" || {
      echo "Error: Cannot create ${SETTINGS_FILE}"
      return 1
    }
    echo "Created new settings.json"
  fi

  if ! jq empty "${SETTINGS_FILE}" 2>/dev/null; then
    echo "Error: Existing settings.json contains invalid JSON"
    echo "Please fix ${SETTINGS_FILE} manually"
    return 1
  fi

  backup_file="${SETTINGS_FILE}.backup.$(generate_timestamp)"
  cp "${SETTINGS_FILE}" "${backup_file}" || {
    echo "Error: Failed to backup settings.json"
    return 1
  }
  echo "Backed up settings: ${backup_file}"

  temp_file=$(mktemp) || {
    echo "Error: Cannot create temporary file"
    return 1
  }

  jq --arg cmd "${SETTINGS_COMMAND}" '.statusLine = {
    "type": "command",
    "command": $cmd,
    "padding": 0
  }' "${SETTINGS_FILE}" > "${temp_file}" 2>/dev/null || {
    echo "Error: Failed to update configuration"
    rm -f "${temp_file}"
    return 1
  }

  if ! jq empty "${temp_file}" 2>/dev/null; then
    echo "Error: Generated invalid JSON"
    rm -f "${temp_file}"
    return 1
  fi

  mv "${temp_file}" "${SETTINGS_FILE}" || {
    echo "Error: Failed to write settings.json"
    mv "${backup_file}" "${SETTINGS_FILE}"
    rm -f "${temp_file}"
    return 1
  }

  echo "✅ Configured ~/.claude/settings.json"
  return 0
}

# Display success message with next steps
show_success_message() {
  local -r mode="$1"
  echo ""
  echo "================================================"
  echo "✅ Installation complete!"
  echo "================================================"
  echo ""
  echo "Installed: ${TARGET_FILE}"
  echo "Mode: ${mode}"
  echo ""
  echo "Configuration applied to ~/.claude/settings.json"
  echo ""
  echo "Next step:"
  echo "  Restart Claude Code to see your new statusline"
  echo ""
  echo "To update, run the installation command again."
  echo ""
}

# Main installation flow
main() {
  local source_file

  trap cleanup_on_error ERR INT TERM

  echo "Installing statusline.sh..."
  echo ""

  echo "Checking dependencies..."
  # shellcheck disable=SC2310  # Intentional: explicit check with exit
  check_dependencies || exit 1

  echo "✅ bash ${BASH_VERSION}"
  # shellcheck disable=SC2312  # Intentional: display version, errors not critical
  echo "✅ curl $(extract_version curl)"
  # shellcheck disable=SC2312  # Intentional: display version, errors not critical
  echo "✅ claude $(extract_version claude)"
  # shellcheck disable=SC2312  # Intentional: display version, errors not critical
  echo "✅ jq $(extract_version jq)"
  # shellcheck disable=SC2312  # Intentional: display version, errors not critical
  echo "✅ git $(extract_version git)"
  echo ""

  if [[ -f "./statusline.sh" ]]; then
    local install_mode="local"
    echo "Using local statusline.sh from current directory..."

    # Verify we're in a safe directory (not root, not /tmp)
    # shellcheck disable=SC2312  # Intentional: pwd unlikely to fail, comparison still works if empty
    if [[ "$(pwd)" == "/" ]] || [[ "$(pwd)" == "/tmp" ]] || [[ "$(pwd)" == "${TMPDIR:-/tmp}" ]]; then
      # shellcheck disable=SC2312  # Intentional: pwd for error message
      echo "Error: Refusing to install from unsafe directory: $(pwd)"
      cleanup_on_error
    fi

    source_file=$(realpath "./statusline.sh" 2>/dev/null) || {
      echo "Error: Cannot resolve path to ./statusline.sh"
      cleanup_on_error
    }

    # shellcheck disable=SC2310  # Intentional: explicit error handling
    if ! validate_file "${source_file}"; then
      echo "Error: Local statusline.sh failed validation"
      cleanup_on_error
    fi

    echo "✅ Local file validated"
  else
    local install_mode="remote"
    echo "Downloading from GitHub..."

    TEMP_FILE=$(mktemp -t statusline.XXXXXX) || {
      echo "Error: Failed to create temporary file"
      exit 1
    }

    # shellcheck disable=SC2310  # Intentional: explicit error handling
    if ! download_file "${GITHUB_RAW_URL}" "${TEMP_FILE}"; then
      cleanup_on_error
    fi

    echo "✅ Downloaded successfully"

    source_file="${TEMP_FILE}"

    # shellcheck disable=SC2310  # Intentional: explicit error handling
    if ! validate_file "${source_file}"; then
      cleanup_on_error
    fi
  fi

  echo ""
  echo "Installing to ${TARGET_FILE}..."
  # shellcheck disable=SC2310  # Intentional: explicit error handling
  if ! install_statusline "${source_file}"; then
    cleanup_on_error
  fi

  echo ""
  echo "Configuring Claude Code settings..."
  # shellcheck disable=SC2310  # Intentional: explicit error handling
  if ! configure_settings; then
    echo ""
    echo "⚠️  Installation succeeded, but automatic configuration failed."
    echo "Please manually add to ~/.claude/settings.json:"
    echo '   {'
    echo '     "statusLine": {'
    echo '       "type": "command",'
    echo "       \"command\": \"${SETTINGS_COMMAND}\","
    echo '       "padding": 0'
    echo '     }'
    echo '   }'
    echo ""
    # Exit code 2: Installation succeeded but configuration failed
    exit "${EXIT_PARTIAL_FAILURE}"
  fi

  [[ -n "${TEMP_FILE}" ]] && [[ -f "${TEMP_FILE}" ]] && rm -f "${TEMP_FILE}"

  show_success_message "${install_mode}"

  exit 0
}

# Run main
main "$@"
