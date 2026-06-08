#!/usr/bin/env bash
# install.sh - Installer for statusline (Rust binary)
# Downloads the latest release binary and configures Claude Code.

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
readonly SETTINGS_FILE="${HOME}/.claude/settings.json"
readonly EXIT_PARTIAL_FAILURE=2
SETTINGS_COMMAND=''  # set by parse_args after INSTALL_DIR is resolved
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

# Install configuration (set by parse_args or defaults)
INSTALL_DEV_MODE=false
INSTALL_DIR=""           # install directory (defaults to ~/.claude)

# ============================================================================
# Utility Functions
# ============================================================================

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}


cleanup_on_error() {
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
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║              Installation Complete!              ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  echo "Installed: ${INSTALL_DIR}/statusline"
  echo ""
  echo -e "${CYAN}Next step:${NC} Restart Claude Code to see your new statusline"
  echo ""
  echo "To update, run the installation command again."
  echo "To customize, edit ${INSTALL_DIR}/statusline.toml"
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

extract_version() {
  local cmd="$1"
  "${cmd}" --version 2>/dev/null | grep -oE '[0-9.]+' | head -n1 || echo 'found'
}

check_dependencies() {
  local missing=()

  command -v claude >/dev/null 2>&1 || missing+=("claude")
  command -v curl   >/dev/null 2>&1 || missing+=("curl")
  command -v node   >/dev/null 2>&1 || missing+=("node")

  if [[ ${#missing[@]} -gt 0 ]]; then
    show_install_instructions "${missing[@]}"
    return 1
  fi

  local v_curl v_claude v_node
  v_curl=$(extract_version curl)
  v_claude=$(extract_version claude)
  v_node=$(extract_version node)
  success "curl ${v_curl}"
  success "claude ${v_claude}"
  success "node ${v_node}"

  local wsl_status=0
  set +e; is_wsl; wsl_status=$?; set -e
  [[ ${wsl_status} -eq 0 ]] && muted "  Detected: WSL environment"

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
      echo "  brew install curl node"
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
        echo "  sudo apt-get update && sudo apt-get install curl nodejs"
      elif command -v yum >/dev/null 2>&1; then
        echo "  sudo yum install curl nodejs"
      elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install curl nodejs"
      else
        echo "  Use your package manager to install: curl node"
      fi
      ;;
    *)
      echo -e "${CYAN}Please install the following dependencies:${NC}"
      echo "  - curl, node"
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

# ============================================================================
# Argument Parsing
# ============================================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dev)
        INSTALL_DEV_MODE=true
        shift
        ;;
      --install-dir)
        [[ -n "${2:-}" ]] || { error "--install-dir requires an argument"; exit 1; }
        INSTALL_DIR="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ -z "${INSTALL_DIR}" ]]; then
    INSTALL_DIR="${HOME}/.claude"
    # shellcheck disable=SC2088  # Keep ~ literal so the command remains shell-safe for homes with spaces.
    SETTINGS_COMMAND='~/.claude/statusline'
  else
    SETTINGS_COMMAND="${INSTALL_DIR}/statusline"
  fi
}

# ============================================================================
# Installation Functions
# ============================================================================

write_statusline_toml() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    "${INSTALL_DIR}/statusline" --print-defaults > "${path}" || {
      error "Failed to generate ${path}"
      return 1
    }
  fi
}

install_rust_statusline() {
  local os_tag
  case "$(uname -s)" in
    Darwin) os_tag="macos" ;;
    Linux)  os_tag="linux-x64" ;;
    *)
      error "Unsupported OS: only macOS and Linux are supported."
      return 1
      ;;
  esac

  local tag
  tag=$(curl -fsSL "https://api.github.com/repos/glauberlima/claude-code-statusline/releases/latest" \
    | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": "\(.*\)".*/\1/')

  if [[ -z "${tag}" ]]; then
    error "Could not determine latest release tag."
    return 1
  fi

  local url="https://github.com/glauberlima/claude-code-statusline/releases/download/${tag}/statusline-${os_tag}"
  local binary="${INSTALL_DIR}/statusline"

  echo ""
  info "Downloading statusline ${tag} for ${os_tag}..."
  mkdir -p "${INSTALL_DIR}"
  set +e
  download_file "${url}" "${binary}"
  local status=$?
  set -e
  [[ ${status} -eq 0 ]] || return 1

  chmod +x "${binary}" || {
    error "Failed to make binary executable"
    return 1
  }

  write_statusline_toml "${INSTALL_DIR}/statusline.toml"

  success "Installed to ${binary}"
  return 0
}

install_dev_statusline() {
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local cargo_manifest="${repo_root}/Cargo.toml"

  if [[ ! -f "${cargo_manifest}" ]]; then
    error "Cargo.toml not found. Run --dev from the repo root."
    return 1
  fi

  info "Building debug binary..."
  cargo build --manifest-path "${cargo_manifest}" || {
    error "cargo build failed"
    return 1
  }

  local debug_bin="${repo_root}/target/debug/statusline"
  local binary="${INSTALL_DIR}/statusline"
  mkdir -p "${INSTALL_DIR}"
  cp "${debug_bin}" "${binary}" || {
    error "Failed to copy binary to ${binary}"
    return 1
  }
  chmod +x "${binary}"

  write_statusline_toml "${INSTALL_DIR}/statusline.toml"

  success "Dev binary installed to ${binary}"
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

  backup_file="${SETTINGS_FILE}.backup.$(date +%s 2>/dev/null || echo $$)"
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
  local status=0

  parse_args "$@"

  trap cleanup_on_error ERR INT TERM

  print_header

  # --dev: fast local build + install, skip download and settings.json
  if [[ "${INSTALL_DEV_MODE}" == "true" ]]; then
    set +e; install_dev_statusline; status=$?; set -e
    [[ ${status} -eq 0 ]] || cleanup_on_error
    print_footer
    exit 0
  fi

  local total_steps=3
  local current_step=0

  step_with_progress "$((++current_step))" "${total_steps}" "Checking dependencies..."
  set +e; check_dependencies; status=$?; set -e
  [[ ${status} -eq 0 ]] || exit 1

  step_with_progress "$((++current_step))" "${total_steps}" "Installing Rust binary..."
  set +e; install_rust_statusline; status=$?; set -e
  [[ ${status} -eq 0 ]] || cleanup_on_error

  step_with_progress "$((++current_step))" "${total_steps}" "Configuring Claude Code..."
  set +e; configure_settings; status=$?; set -e
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
    exit "${EXIT_PARTIAL_FAILURE}"
  fi

  print_footer
  exit 0
}

main "$@"
