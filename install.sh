#!/usr/bin/env bash
# install.sh - Installer for statusline.sh
# Acquires files (local or remote), patches with user preferences, installs to ~/.claude/

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
readonly TARGET_DIR="${HOME}/.claude"
readonly TARGET_FILE="${TARGET_DIR}/statusline.sh"
readonly SETTINGS_FILE="${HOME}/.claude/settings.json"
# shellcheck disable=SC2088  # Keep ~ literal so the command remains shell-safe for homes with spaces.
readonly SETTINGS_COMMAND='~/.claude/statusline.sh'
readonly GITHUB_BASE_URL="https://raw.githubusercontent.com/glauberlima/claude-code-statusline/refs/heads/main"
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

# Mutable globals (set by acquire_files)
TEMP_DIR=""
WORKING_DIR=""
INSTALL_MODE="local"

# ============================================================================
# Utility Functions
# ============================================================================

is_piped() { [[ ! -t 2 ]]; }

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}


cleanup_temp() {
  if [[ -n "${TEMP_DIR}" ]] && [[ -d "${TEMP_DIR}" ]]; then
    rm -rf "${TEMP_DIR}"
  fi
}

cleanup_on_error() {
  cleanup_temp
  echo ""
  error "Installation failed. No changes made."
  exit 1
}

validate_json() {
  node -e "JSON.parse(require('fs').readFileSync(process.argv[process.argv.length-1],'utf8'))" \
       "$1" 2>/dev/null
}

# ============================================================================
# UI Functions
# ============================================================================

print_header() {
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║        Claude Code Statusline - Installer        ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
}

print_footer() {
  local mode="$1"
  local language="${2:-en}"
  local components="${3:-messages cost}"

  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║              Installation Complete!              ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  echo "Installed: ${TARGET_FILE}"
  echo "Mode: ${mode}"
  if [[ "${components}" == *"messages"* ]]; then
    echo "Language: ${language}"
  fi
  echo ""
  echo -e "${CYAN}Next step:${NC} Restart Claude Code to see your new statusline"
  echo ""
  echo "To update, run the installation command again."
  echo ""
}

step_with_progress() {
  local current="$1"
  local total="$2"
  local message="$3"
  echo ""
  echo -e "${CYAN}[${current}/${total}]${NC} ${message}"
}

success() { echo -e "${SUCCESS}${CHECK_MARK}${NC} $1"; }
warn()    { echo -e "${WARN}${WARNING_SIGN}${NC}  $1" >&2; }
error()   { echo -e "${ERROR}${CROSS_MARK}${NC} $1" >&2; }
info()    { echo -e "${CYAN}${ARROW}${NC} $1"; }
muted()   { echo -e "${MUTED}$1${NC}"; }

# ============================================================================
# Validation Functions
# ============================================================================

check_bash_version() {
  if [[ "${BASH_VERSINFO[0]}" -lt 3 ]] || \
     [[ "${BASH_VERSINFO[0]}" -eq 3 && "${BASH_VERSINFO[1]}" -lt 2 ]]; then
    echo "Error: bash 3.2+ required (found ${BASH_VERSION})"
    return 1
  fi
  return 0
}

generate_timestamp() {
  date +%s%N 2>/dev/null || date +%s
}

extract_version() {
  local cmd="$1"
  "${cmd}" --version 2>/dev/null | grep -oE '[0-9.]+' | head -n1 || echo 'found'
}

check_git_version() {
  local git_version_str major minor

  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi

  git_version_str=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)
  [[ -z "${git_version_str}" ]] && return 1

  major="${git_version_str%%.*}"
  minor="${git_version_str#*.}"

  if [[ "${major}" -lt 2 ]] || [[ "${major}" -eq 2 && "${minor}" -lt 11 ]]; then
    return 1
  fi
  return 0
}

check_dependencies() {
  local missing=()
  local status=0

  set +e
  check_bash_version
  status=$?
  set -e
  if [[ ${status} -ne 0 ]]; then
    missing+=("bash 3.2+")
  fi
  command -v claude >/dev/null 2>&1 || missing+=("claude")
  command -v curl >/dev/null 2>&1 || missing+=("curl")
  command -v node >/dev/null 2>&1 || missing+=("node")
  set +e
  check_git_version
  status=$?
  set -e
  if [[ ${status} -ne 0 ]]; then
    missing+=("git 2.11+")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    show_install_instructions "${missing[@]}"
    return 1
  fi

  local v_curl v_claude v_node v_git
  v_curl=$(extract_version curl); v_claude=$(extract_version claude)
  v_node=$(extract_version node); v_git=$(extract_version git)
  success "bash ${BASH_VERSION}"
  success "curl ${v_curl}"
  success "claude ${v_claude}"
  success "node ${v_node}"
  success "git ${v_git}"
  set +e
  is_wsl
  status=$?
  set -e
  if [[ ${status} -eq 0 ]]; then
    muted "  Detected: WSL environment"
  fi

  return 0
}

show_install_instructions() {
  local deps=("$@")
  local platform
  platform=$(uname -s 2>/dev/null)
  [[ -n "${platform}" ]] || platform="Unknown"

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
      echo "  brew install curl git node"
      ;;
    Linux)
      local wsl_status=0
      set +e
      is_wsl
      wsl_status=$?
      set -e
      if [[ ${wsl_status} -eq 0 ]]; then
        echo -e "${CYAN}Install on WSL:${NC}"
      else
        echo -e "${CYAN}Install on Linux:${NC}"
      fi
      if command -v apt-get >/dev/null 2>&1; then
        echo "  sudo apt-get update && sudo apt-get install curl git nodejs"
      elif command -v yum >/dev/null 2>&1; then
        echo "  sudo yum install curl git nodejs"
      elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install curl git nodejs"
      else
        echo "  Use your package manager to install: curl git node"
      fi
      ;;
    *)
      echo -e "${CYAN}Please install the following dependencies:${NC}"
      echo "  - curl, node, git 2.11+, bash 3.2+"
      ;;
  esac

  echo ""
  echo "Installation aborted. Install dependencies and try again."
}

download_file() {
  local url="$1"
  local dest="$2"
  local attempt=1

  while [[ ${attempt} -le ${MAX_DOWNLOAD_RETRIES} ]]; do
    if curl -fsSL "${url}" -o "${dest}" 2>/dev/null; then
      break
    fi
    attempt=$((attempt + 1))
    [[ ${attempt} -le ${MAX_DOWNLOAD_RETRIES} ]] && sleep 1
  done

  if [[ ${attempt} -gt ${MAX_DOWNLOAD_RETRIES} ]]; then
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

validate_file() {
  local file="$1"
  local first_line

  if [[ ! -s "${file}" ]]; then
    error "File does not exist or is empty"
    return 1
  fi

  IFS= read -r first_line < "${file}" || return 1
  if [[ ! "${first_line}" =~ ^#!/.*bash ]]; then
    error "Invalid file format (missing bash shebang)"
    return 1
  fi

  if ! grep -q 'assemble_statusline' "${file}"; then
    error "File does not appear to be statusline.sh"
    return 1
  fi
  return 0
}

# ============================================================================
# Acquisition Functions
# ============================================================================

# Detect local or remote mode, set WORKING_DIR and INSTALL_MODE globals.
# Local mode: all files already present in current directory.
# Remote mode: downloads statusline.sh, patch-statusline.sh, messages/*.json to TEMP_DIR.
acquire_files() {
  local status=0

  if [[ -f "./statusline.sh" && -f "./patch-statusline.sh" && -d "./messages" ]]; then
    INSTALL_MODE="local"
    WORKING_DIR="$(pwd)"
    info "Using local files from current directory"

    # Refuse to install from unsafe directories
    case "${WORKING_DIR}" in
      / | /tmp | "${TMPDIR:-/tmp}")
        error "Refusing to install from unsafe directory: ${WORKING_DIR}"
        return 1
        ;;
      *) ;;
    esac

    set +e
    validate_file "${WORKING_DIR}/statusline.sh"
    status=$?
    set -e
    [[ ${status} -eq 0 ]] || return 1
    success "Local files validated"
  else
    INSTALL_MODE="remote"
    info "Downloading files from GitHub..."

    TEMP_DIR=$(mktemp -d -t statusline.XXXXXX) || {
      error "Failed to create temporary directory"
      return 1
    }
    WORKING_DIR="${TEMP_DIR}"
    mkdir -p "${WORKING_DIR}/messages"

    # Download main scripts
    set +e
    download_file "${GITHUB_BASE_URL}/statusline.sh" "${WORKING_DIR}/statusline.sh"
    status=$?
    set -e
    [[ ${status} -eq 0 ]] || return 1
    set +e
    download_file "${GITHUB_BASE_URL}/patch-statusline.sh" "${WORKING_DIR}/patch-statusline.sh"
    status=$?
    set -e
    [[ ${status} -eq 0 ]] || return 1
    chmod +x "${WORKING_DIR}/patch-statusline.sh"

    # Download language message files (warn on partial failure, don't abort)
    for lang in en pt es; do
      set +e
      download_file "${GITHUB_BASE_URL}/messages/${lang}.json" \
        "${WORKING_DIR}/messages/${lang}.json"
      status=$?
      set -e
      if [[ ${status} -ne 0 ]]; then
        warn "Failed to download messages/${lang}.json"
      fi
    done

    set +e
    validate_file "${WORKING_DIR}/statusline.sh"
    status=$?
    set -e
    [[ ${status} -eq 0 ]] || return 1
    success "Files downloaded and validated"
  fi
  return 0
}

# ============================================================================
# Patching Functions
# ============================================================================

# Run patch-statusline.sh with language JSON and feature flags derived from
# the user's component selection string (e.g., "messages cost").
apply_patches() {
  local working_dir="$1"
  local language="$2"
  local components="$3"

  local patch_script="${working_dir}/patch-statusline.sh"
  local statusline_file="${working_dir}/statusline.sh"

  chmod +x "${patch_script}"

  local patch_args=("${statusline_file}" "${working_dir}/messages/${language}.json")
  [[ "${components}" != *"messages"* ]]      && patch_args+=("--no-messages")
  [[ "${components}" != *"cost"* ]]          && patch_args+=("--no-cost")
  [[ "${components}" != *"rainbow-wave"* ]]  && patch_args+=("--no-rainbow-wave")

  "${patch_script}" "${patch_args[@]}" || {
    error "Patching failed"
    return 1
  }
  return 0
}

# ============================================================================
# Preference Functions
# ============================================================================

prompt_language_selection() {
  local available_languages=("en" "pt" "es")
  local lang_names=("English" "Português" "Español")
  local piped_status=0

  set +e
  is_piped
  piped_status=$?
  set -e
  if [[ ${piped_status} -eq 0 ]]; then
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

prompt_component_selection() {
  local piped_status=0

  set +e
  is_piped
  piped_status=$?
  set -e
  if [[ ${piped_status} -eq 0 ]]; then
    echo "messages cost rainbow-wave"
    return
  fi

  echo "" >&2
  echo -e "${CYAN}Select features:${NC}" >&2
  echo "" >&2
  echo "  1) All features (messages + cost + rainbow-wave)" >&2
  echo "  2) Messages + Cost" >&2
  echo "  3) Messages + Rainbow Wave" >&2
  echo "  4) Messages only" >&2
  echo "  5) Cost only" >&2
  echo "  6) Rainbow Wave only" >&2
  echo "  7) Minimal (no messages, no cost, no rainbow-wave)" >&2
  echo "" >&2
  printf "Enter selection [1]: " >&2
  read -r selection < /dev/tty || selection=""
  selection="${selection:-1}"

  case "${selection}" in
    1) echo "messages cost rainbow-wave" ;;
    2) echo "messages cost" ;;
    3) echo "messages rainbow-wave" ;;
    4) echo "messages" ;;
    5) echo "cost" ;;
    6) echo "rainbow-wave" ;;
    7) echo "" ;;
    *) echo "messages cost rainbow-wave" ;;
  esac
}

# ============================================================================
# Installation Functions
# ============================================================================

install_statusline() {
  local source="$1"
  local backup=""

  if [[ ! -d "${TARGET_DIR}" ]]; then
    mkdir -p "${TARGET_DIR}" || { error "Failed to create ${TARGET_DIR}"; return 1; }
  fi

  if [[ -L "${TARGET_DIR}" ]]; then
    error "${TARGET_DIR} is a symbolic link (security risk)"
    return 1
  fi

  if [[ -e "${TARGET_FILE}" ]] || [[ -L "${TARGET_FILE}" ]]; then
    backup="${TARGET_FILE}.backup.$(generate_timestamp)"
    mv "${TARGET_FILE}" "${backup}" || { error "Failed to backup existing installation"; return 1; }
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

configure_settings() {
  local settings_dir="${HOME}/.claude"
  local temp_file backup_file

  mkdir -p "${settings_dir}" || { error "Cannot create ${settings_dir}"; return 1; }

  if [[ ! -f "${SETTINGS_FILE}" ]]; then
    echo "{}" > "${SETTINGS_FILE}" || { error "Cannot create ${SETTINGS_FILE}"; return 1; }
    info "Created new settings.json"
  fi

  local status=0
  set +e
  validate_json "${SETTINGS_FILE}"
  status=$?
  set -e
  if [[ ${status} -ne 0 ]]; then
    error "Existing settings.json contains invalid JSON"
    echo "  ${ARROW} Please fix ${SETTINGS_FILE} manually" >&2
    return 1
  fi

  backup_file="${SETTINGS_FILE}.backup.$(generate_timestamp)"
  cp "${SETTINGS_FILE}" "${backup_file}" || { error "Failed to backup settings.json"; return 1; }
  info "Backed up settings: ${backup_file}"

  temp_file=$(mktemp) || { error "Cannot create temporary file"; return 1; }

  # Use node to merge statusLine into settings.json, preserving all other keys.
  # Path and command passed via process.argv to avoid shell injection risks.
  node - "${SETTINGS_FILE}" "${SETTINGS_COMMAND}" "${temp_file}" 2>/dev/null <<'NODEEOF' || {
    var fs = require('fs');
    var src  = process.argv[process.argv.length - 3];
    var cmd  = process.argv[process.argv.length - 2];
    var dest = process.argv[process.argv.length - 1];
    var settings = JSON.parse(fs.readFileSync(src, 'utf8'));
    settings.statusLine = { type: 'command', command: cmd, padding: 0 };
    fs.writeFileSync(dest, JSON.stringify(settings, null, 2) + '\n', 'utf8');
NODEEOF
    error "Failed to update configuration"
    rm -f "${temp_file}"
    return 1
  }

  mv "${temp_file}" "${SETTINGS_FILE}" || {
    error "Failed to write settings.json"
    mv "${backup_file}" "${SETTINGS_FILE}"
    rm -f "${temp_file}"
    return 1
  }

  success "Configured ~/.claude/settings.json"
  return 0
}

# ============================================================================
# Main Installation Flow
# ============================================================================

main() {
  local selected_language="en"
  local selected_components="messages cost rainbow-wave"
  local total_steps=5
  local current_step=0
  local status=0

  trap cleanup_on_error ERR INT TERM

  print_header

  # Step 1: Check Dependencies
  step_with_progress "$((++current_step))" "${total_steps}" "Checking dependencies..."
  set +e
  check_dependencies
  status=$?
  set -e
  [[ ${status} -eq 0 ]] || exit 1

  # Step 2: Acquire Files
  step_with_progress "$((++current_step))" "${total_steps}" "Acquiring files..."
  set +e
  acquire_files
  status=$?
  set -e
  [[ ${status} -eq 0 ]] || cleanup_on_error

  # Step 3: Select Preferences
  step_with_progress "$((++current_step))" "${total_steps}" "Configuring preferences..."
  selected_components=$(prompt_component_selection)

  # Only ask language if messages are enabled (language only affects context messages)
  if [[ "${selected_components}" == *"messages"* ]]; then
    selected_language=$(prompt_language_selection)
  fi
  success "Language: ${selected_language}, Components: ${selected_components:-none}"

  # Step 4: Apply Patches
  step_with_progress "$((++current_step))" "${total_steps}" "Applying patches..."
  set +e
  apply_patches "${WORKING_DIR}" "${selected_language}" "${selected_components}"
  status=$?
  set -e
  [[ ${status} -eq 0 ]] || cleanup_on_error
  success "Patched successfully"

  # Step 5: Install & Configure
  step_with_progress "$((++current_step))" "${total_steps}" "Installing to ~/.claude..."
  set +e
  install_statusline "${WORKING_DIR}/statusline.sh"
  status=$?
  set -e
  [[ ${status} -eq 0 ]] || cleanup_on_error
  success "Installed to ${TARGET_FILE}"

  set +e
  configure_settings
  status=$?
  set -e
  if [[ ${status} -ne 0 ]]; then
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
    cleanup_temp
    exit "${EXIT_PARTIAL_FAILURE}"
  fi

  cleanup_temp

  print_footer "${INSTALL_MODE}" "${selected_language}" "${selected_components}"
  exit 0
}

main "$@"
