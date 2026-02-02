#!/usr/bin/env bash
# install.sh - Installer for statusline.sh
# Downloads statusline.sh from GitHub and installs to ~/.claude/statusline.sh

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
readonly TARGET_DIR="${HOME}/.claude"
readonly TARGET_FILE="${TARGET_DIR}/statusline.sh"
readonly SETTINGS_FILE="${HOME}/.claude/settings.json"
readonly SETTINGS_COMMAND="${HOME}/.claude/statusline.sh"
readonly GITHUB_BASE_URL="https://raw.githubusercontent.com/glauberlima/claude-code-statusline/main"
readonly GITHUB_RAW_URL="${GITHUB_BASE_URL}/statusline.sh"
readonly EXIT_PARTIAL_FAILURE=2
readonly MAX_DOWNLOAD_RETRIES=3

# ANSI color codes
readonly SUCCESS='\033[0;32m'  # Green
readonly WARN='\033[0;33m'     # Yellow
readonly ERROR='\033[0;31m'    # Red
readonly CYAN='\033[0;36m'     # Cyan
readonly MUTED='\033[0;90m'    # Gray
readonly NC='\033[0m'          # No Color

# Unicode symbols
readonly CHECK_MARK="✓"
readonly CROSS_MARK="✗"
readonly WARNING_SIGN="⚠️"
readonly ARROW="→"

# Temporary file for downloads (set in main)
TEMP_FILE=""

# ============================================================================
# Utility Functions
# ============================================================================

# Detect if running in pipe mode (e.g., curl | bash)
is_piped() {
  [[ ! -t 0 ]]
}

# Detect if running in WSL
is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

# Download file with retry logic
download_with_retry() {
  local url="$1"
  local dest="$2"
  local attempt=1

  while [[ ${attempt} -le ${MAX_DOWNLOAD_RETRIES} ]]; do
    if curl -fsSL "${url}" -o "${dest}" 2>/dev/null; then
      return 0
    fi

    attempt=$((attempt + 1))
    [[ ${attempt} -le ${MAX_DOWNLOAD_RETRIES} ]] && sleep 1
  done

  return 1
}

# Cleanup function for trap
cleanup_on_error() {
  [[ -n "${TEMP_FILE}" ]] && [[ -f "${TEMP_FILE}" ]] && rm -f "${TEMP_FILE}"
  echo ""
  error "Installation failed. No changes made."
  exit 1
}

# ============================================================================
# UI Functions
# ============================================================================

# Print installation header
print_header() {
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║        Claude Code Statusline - Installer        ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
}

# Print installation footer
print_footer() {
  local mode="$1"
  local language="${2:-en}"

  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║              Installation Complete!              ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  echo "Installed: ${TARGET_FILE}"
  echo "Mode: ${mode}"
  echo "Language: ${language}"
  echo ""
  echo -e "${CYAN}Next step:${NC} Restart Claude Code to see your new statusline"
  echo ""
  echo "To update, run the installation command again."
  echo ""
}

# Print step with progress counter
step_with_progress() {
  local current="$1"
  local total="$2"
  local message="$3"

  echo ""
  echo -e "${CYAN}[${current}/${total}]${NC} ${message}"
}

# Print success message
success() {
  echo -e "${SUCCESS}${CHECK_MARK}${NC} $1"
}

# Print warning message
warn() {
  echo -e "${WARN}${WARNING_SIGN}${NC}  $1" >&2
}

# Print error message
error() {
  echo -e "${ERROR}${CROSS_MARK}${NC} $1" >&2
}

# Print info message
info() {
  echo -e "${CYAN}${ARROW}${NC} $1"
}

# Print muted message
muted() {
  echo -e "${MUTED}$1${NC}"
}

# ============================================================================
# Validation Functions
# ============================================================================

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
  # shellcheck disable=SC2312
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

  # shellcheck disable=SC2310
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

  # shellcheck disable=SC2310
  if ! check_git_version; then
    missing+=("git 2.11+")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    show_install_instructions "${missing[@]}"
    return 1
  fi

  # Show detected versions
  success "bash ${BASH_VERSION}"
  # shellcheck disable=SC2312
  success "curl $(extract_version curl)"
  # shellcheck disable=SC2312
  success "claude $(extract_version claude)"
  # shellcheck disable=SC2312
  success "jq $(extract_version jq)"
  # shellcheck disable=SC2312
  success "git $(extract_version git)"

  # shellcheck disable=SC2310
  if is_wsl; then
    muted "  Detected: WSL environment"
  fi

  return 0
}

# Show platform-specific installation instructions
show_install_instructions() {
  local -r deps=("$@")
  local platform
  # shellcheck disable=SC2312
  platform=$(uname -s 2>/dev/null || echo "Unknown")

  error "Missing dependencies: ${deps[*]}"
  echo ""

  for dep in "${deps[@]}"; do
    if [[ "${dep}" == "claude" ]]; then
      echo -e "${CYAN}Claude Code CLI:${NC}"
      echo "  Visit https://claude.ai/code for installation instructions"
      echo ""
      break
    fi
  done

  case "${platform}" in
    Darwin)
      echo -e "${CYAN}Install on macOS:${NC}"
      echo "  brew install curl jq git"
      ;;
    Linux)
      # shellcheck disable=SC2310
      if is_wsl; then
        echo -e "${CYAN}Install on WSL:${NC}"
      else
        echo -e "${CYAN}Install on Linux:${NC}"
      fi

      if command -v apt-get >/dev/null 2>&1; then
        echo "  sudo apt-get update && sudo apt-get install curl jq git"
      elif command -v yum >/dev/null 2>&1; then
        echo "  sudo yum install curl jq git"
      elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install curl jq git"
      else
        echo "  Use your package manager to install: curl jq git"
      fi
      ;;
    *)
      echo -e "${CYAN}Please install the following dependencies:${NC}"
      echo "  - curl"
      echo "  - jq 1.5+"
      echo "  - git 2.11+"
      echo "  - bash 3.2+"
      ;;
  esac

  echo ""
  echo "Installation aborted. Install dependencies and try again."
}

# Download file (wrapper)
download_file() {
  local -r url="$1"
  local -r dest="$2"

  # shellcheck disable=SC2310
  if ! download_with_retry "${url}" "${dest}"; then
    error "Failed to download from ${url}"
    echo "  ${ARROW} Check your internet connection and try again" >&2
    return 1
  fi

  if [[ ! -s "${dest}" ]]; then
    error "Downloaded file is empty"
    return 1
  fi

  return 0
}

# Validate downloaded file
validate_file() {
  local -r file="$1"

  if [[ ! -s "${file}" ]]; then
    error "File does not exist or is empty"
    return 1
  fi

  if ! head -n1 "${file}" 2>/dev/null | grep -q '^#!/.*bash'; then
    error "Invalid file format (missing bash shebang)"
    return 1
  fi

  if ! grep -q 'assemble_statusline' "${file}" 2>/dev/null; then
    error "File does not appear to be statusline.sh"
    return 1
  fi

  return 0
}

# ============================================================================
# Installation Functions
# ============================================================================

# Perform atomic installation
install_statusline() {
  local -r source="$1"
  local backup=""

  if [[ ! -d "${TARGET_DIR}" ]]; then
    mkdir -p "${TARGET_DIR}" || {
      error "Failed to create ${TARGET_DIR}"
      return 1
    }
  fi

  if [[ -L "${TARGET_DIR}" ]]; then
    error "${TARGET_DIR} is a symbolic link (security risk)"
    return 1
  fi

  if [[ -e "${TARGET_FILE}" ]] || [[ -L "${TARGET_FILE}" ]]; then
    backup="${TARGET_FILE}.backup.$(generate_timestamp)"
    mv "${TARGET_FILE}" "${backup}" || {
      error "Failed to backup existing installation"
      return 1
    }
    info "Backed up existing: ${backup}"
  fi

  cp "${source}" "${TARGET_FILE}" || {
    error "Failed to copy file"
    [[ -n "${backup}" ]] && mv "${backup}" "${TARGET_FILE}"
    return 1
  }

  chmod +x "${TARGET_FILE}" || {
    error "Failed to make file executable"
    [[ -n "${backup}" ]] && mv "${backup}" "${TARGET_FILE}"
    return 1
  }

  return 0
}

# Configure settings.json
configure_settings() {
  local -r settings_dir="${HOME}/.claude"
  local temp_file
  local backup_file

  mkdir -p "${settings_dir}" || {
    error "Cannot create ${settings_dir}"
    return 1
  }

  if [[ ! -f "${SETTINGS_FILE}" ]]; then
    echo "{}" > "${SETTINGS_FILE}" || {
      error "Cannot create ${SETTINGS_FILE}"
      return 1
    }
    info "Created new settings.json"
  fi

  if ! jq empty "${SETTINGS_FILE}" 2>/dev/null; then
    error "Existing settings.json contains invalid JSON"
    echo "  ${ARROW} Please fix ${SETTINGS_FILE} manually" >&2
    return 1
  fi

  backup_file="${SETTINGS_FILE}.backup.$(generate_timestamp)"
  cp "${SETTINGS_FILE}" "${backup_file}" || {
    error "Failed to backup settings.json"
    return 1
  }
  info "Backed up settings: ${backup_file}"

  temp_file=$(mktemp) || {
    error "Cannot create temporary file"
    return 1
  }

  jq --arg cmd "${SETTINGS_COMMAND}" '.statusLine = {
    "type": "command",
    "command": $cmd,
    "padding": 0
  }' "${SETTINGS_FILE}" > "${temp_file}" 2>/dev/null || {
    error "Failed to update configuration"
    rm -f "${temp_file}"
    return 1
  }

  if ! jq empty "${temp_file}" 2>/dev/null; then
    error "Generated invalid JSON"
    rm -f "${temp_file}"
    return 1
  fi

  mv "${temp_file}" "${SETTINGS_FILE}" || {
    error "Failed to write settings.json"
    mv "${backup_file}" "${SETTINGS_FILE}"
    rm -f "${temp_file}"
    return 1
  }

  success "Configured ~/.claude/settings.json"
  return 0
}

# Install language files
install_language_files() {
  local source_dir="${1:-.}"
  local messages_target_dir="${TARGET_DIR}/messages"

  mkdir -p "${messages_target_dir}" || {
    error "Failed to create messages directory"
    return 1
  }

  if [[ -d "${source_dir}/messages" ]]; then
    if ! cp "${source_dir}/messages"/*.sh "${messages_target_dir}/" 2>/dev/null; then
      warn "Failed to copy some language files"
      return 1
    fi
    success "Language files installed"
  else
    warn "messages directory not found in ${source_dir}"
    return 1
  fi

  return 0
}

# Download language files from GitHub
download_language_files_remote() {
  local messages_target_dir="${TARGET_DIR}/messages"
  local available_languages=("en" "pt" "es")
  local failed=0
  local temp_file

  mkdir -p "${messages_target_dir}" || {
    error "Failed to create messages directory"
    return 1
  }

  for lang in "${available_languages[@]}"; do
    local lang_url="${GITHUB_BASE_URL}/messages/${lang}.sh"
    local lang_file="${messages_target_dir}/${lang}.sh"

    temp_file=$(mktemp -t "lang_${lang}.XXXXXX") || {
      warn "Failed to create temp file for ${lang}.sh"
      failed=1
      continue
    }

    # shellcheck disable=SC2310
    if ! download_with_retry "${lang_url}" "${temp_file}"; then
      warn "Failed to download ${lang}.sh"
      rm -f "${temp_file}"
      failed=1
      continue
    fi

    if [[ ! -s "${temp_file}" ]]; then
      warn "Downloaded ${lang}.sh is empty"
      rm -f "${temp_file}"
      failed=1
      continue
    fi

    if ! head -n1 "${temp_file}" 2>/dev/null | grep -q '^#!/.*bash'; then
      warn "${lang}.sh has invalid format"
      rm -f "${temp_file}"
      failed=1
      continue
    fi

    mv "${temp_file}" "${lang_file}" || {
      warn "Failed to install ${lang}.sh"
      rm -f "${temp_file}"
      failed=1
      continue
    }
  done

  if [[ ! -f "${messages_target_dir}/en.sh" ]]; then
    error "Failed to install default language file (en.sh)"
    return 1
  fi

  if [[ "${failed}" -eq 0 ]]; then
    success "Language files installed"
  else
    success "Language files installed (some files skipped)"
  fi

  return 0
}

# Prompt for language selection
prompt_language_selection() {
  local available_languages=("en" "pt" "es")
  local lang_names=("English" "Português" "Español")

  # Default to English in pipe mode
  # shellcheck disable=SC2310
  if is_piped; then
    echo "en"
    return
  fi

  echo "" >&2
  echo -e "${CYAN}Select statusline language:${NC}" >&2
  echo "" >&2

  for i in "${!available_languages[@]}"; do
    echo "  $((i + 1))) ${lang_names[i]} (${available_languages[i]})" >&2
  done

  echo "" >&2
  printf "Enter selection [1]: " >&2
  read -r selection < /dev/tty || selection=""
  selection="${selection:-1}"

  local selected_index=$((selection - 1))
  if [[ "${selected_index}" -ge 0 ]] && [[ "${selected_index}" -lt "${#available_languages[@]}" ]]; then
    echo "${available_languages[${selected_index}]}"
  else
    echo "en"
  fi
}


# Prompt for component selection (multi-select toggle)
# Returns: space-separated enabled components (e.g., "messages cost")
prompt_component_selection() {
  # Default to all in pipe mode
  # shellcheck disable=SC2310  # is_piped invoked in if condition
  if is_piped; then
    echo "messages cost"
    return
  fi

  echo "" >&2
  echo -e "${CYAN}Select components to display:${NC}" >&2
  echo -e "${MUTED}(Enter numbers to toggle, empty = show all)${NC}" >&2
  echo "" >&2
  echo "  1) [X] Context messages (funny messages)" >&2
  echo "  2) [X] Cost display (💰)" >&2
  echo "" >&2
  printf "Toggle (default: show all): " >&2

  read -r input < /dev/tty || input=""

  # Default: show all
  [[ -z "${input}" ]] && echo "messages cost" && return

  # Parse toggles
  local show_messages=true
  local show_cost=true

  for num in ${input}; do
    case "${num}" in
      1) show_messages=$([[ "${show_messages}" == "true" ]] && echo "false" || echo "true") ;;
      2) show_cost=$([[ "${show_cost}" == "true" ]] && echo "false" || echo "true") ;;
      *) ;;  # Ignore invalid input
    esac
  done

  # Build result
  local result=""
  [[ "${show_messages}" == "true" ]] && result+="messages "
  [[ "${show_cost}" == "true" ]] && result+="cost"

  echo "${result}" | xargs
}

# Save language configuration
save_user_config() {
  local language="$1"
  local components="$2"
  local config_file="${TARGET_DIR}/statusline-config.sh"

  # Parse component string
  local show_messages="false"
  local show_cost="false"

  [[ "${components}" =~ messages ]] && show_messages="true"
  [[ "${components}" =~ cost ]] && show_cost="true"

  cat > "${config_file}" <<EOF
#!/usr/bin/env bash
# Statusline user preferences
# Generated by install.sh - modify by running install.sh again

readonly STATUSLINE_LANGUAGE="${language}"
readonly STATUSLINE_SHOW_MESSAGES="${show_messages}"
readonly STATUSLINE_SHOW_COST="${show_cost}"
EOF

  chmod +x "${config_file}" || {
    error "Failed to make config executable"
    return 1
  }

  success "Configuration saved: lang=${language}, messages=${show_messages}, cost=${show_cost}"
  return 0
}

# ============================================================================
# Main Installation Flow
# ============================================================================

main() {
  local source_file
  local install_mode
  local selected_language="en"
  local total_steps=5
  local current_step=0

  trap cleanup_on_error ERR INT TERM

  print_header

  # Step 1: Check Dependencies
  current_step=$((current_step + 1))
  step_with_progress "${current_step}" "${total_steps}" "Checking dependencies..."
  # shellcheck disable=SC2310
  if ! check_dependencies; then
    exit 1
  fi

  # Step 2: Acquire Statusline
  current_step=$((current_step + 1))
  step_with_progress "${current_step}" "${total_steps}" "Acquiring statusline..."

  if [[ -f "./statusline.sh" ]]; then
    install_mode="local"
    info "Using local statusline.sh from current directory"

    # shellcheck disable=SC2312
    if [[ "$(pwd)" == "/" ]] || [[ "$(pwd)" == "/tmp" ]] || [[ "$(pwd)" == "${TMPDIR:-/tmp}" ]]; then
      # shellcheck disable=SC2312
      error "Refusing to install from unsafe directory: $(pwd)"
      cleanup_on_error
    fi

    source_file=$(realpath "./statusline.sh" 2>/dev/null) || {
      error "Cannot resolve path to ./statusline.sh"
      cleanup_on_error
    }

    # shellcheck disable=SC2310
    if ! validate_file "${source_file}"; then
      error "Local statusline.sh failed validation"
      cleanup_on_error
    fi

    success "Local file validated"
  else
    install_mode="remote"
    info "Downloading from GitHub"

    TEMP_FILE=$(mktemp -t statusline.XXXXXX) || {
      error "Failed to create temporary file"
      exit 1
    }

    # shellcheck disable=SC2310
    if ! download_file "${GITHUB_RAW_URL}" "${TEMP_FILE}"; then
      cleanup_on_error
    fi

    success "Downloaded successfully"
    source_file="${TEMP_FILE}"

    # shellcheck disable=SC2310
    if ! validate_file "${source_file}"; then
      cleanup_on_error
    fi

    success "File validated"
  fi

  # Step 3: Install to ~/.claude
  current_step=$((current_step + 1))
  step_with_progress "${current_step}" "${total_steps}" "Installing to ~/.claude..."
  # shellcheck disable=SC2310
  if ! install_statusline "${source_file}"; then
    cleanup_on_error
  fi
  success "Installation complete"

  # Step 4: Configure Settings
  current_step=$((current_step + 1))
  step_with_progress "${current_step}" "${total_steps}" "Configuring settings..."
  # shellcheck disable=SC2310
  if ! configure_settings; then
    echo ""
    warn "Installation succeeded, but automatic configuration failed"
    echo ""
    echo "Please manually add to ~/.claude/settings.json:"
    echo '   {'
    echo '     "statusLine": {'
    echo '       "type": "command",'
    echo "       \"command\": \"${SETTINGS_COMMAND}\","
    echo '       "padding": 0'
    echo '     }'
    echo '   }'
    echo ""
    exit "${EXIT_PARTIAL_FAILURE}"
  fi

  # Step 5: Install Languages
  current_step=$((current_step + 1))
  step_with_progress "${current_step}" "${total_steps}" "Installing languages..."

  if [[ "${install_mode}" == "local" ]]; then
    # shellcheck disable=SC2310
    if ! install_language_files "."; then
      warn "Language files installation failed"
      echo "  ${ARROW} Statusline will use default language (English)" >&2
    fi
  else
    # shellcheck disable=SC2310
    if ! download_language_files_remote; then
      warn "Language files download failed"
      echo "  ${ARROW} Statusline will use default language (English)" >&2
    fi
  fi

  if [[ -d "${TARGET_DIR}/messages" ]]; then
    selected_language=$(prompt_language_selection)

    # Get component preferences
    local selected_components
    selected_components=$(prompt_component_selection)

    # Save unified config
    # shellcheck disable=SC2310
    if ! save_user_config "${selected_language}" "${selected_components}"; then
      warn "Configuration failed"
      echo "  ${ARROW} Statusline will use default settings" >&2
    fi
  fi

  [[ -n "${TEMP_FILE}" ]] && [[ -f "${TEMP_FILE}" ]] && rm -f "${TEMP_FILE}"

  print_footer "${install_mode}" "${selected_language}"

  exit 0
}

main "$@"
