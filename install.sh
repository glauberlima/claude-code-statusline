#!/usr/bin/env bash
set -euo pipefail

GITHUB_REPO="glauberlima/claude-code-statusline"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
GITHUB_DL_BASE="https://github.com/${GITHUB_REPO}/releases/download"
MAX_RETRIES=3

# ── Colors ─────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
MUTED='\033[0;90m'
NC='\033[0m'

# ── Output helpers ─────────────────────────────────────────────────────────────
success() { echo -e "${GREEN}✓${NC} $*"; }
info()    { echo -e "${CYAN}→${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*" >&2; }
error()   { echo -e "${RED}✗${NC} $*" >&2; }
muted()   { echo -e "${MUTED}  $*${NC}"; }
step()    { echo -e "\n${CYAN}[$1/3]${NC} $2"; }

# ── Argument parsing ───────────────────────────────────────────────────────────
INSTALL_DIR="${HOME}/.claude"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-dir)
            if [[ -z "${2:-}" ]]; then
                error "--install-dir requires an argument."
                exit 1
            fi
            INSTALL_DIR="$2"
            shift 2
            ;;
        *) shift ;;
    esac
done

BINARY_DEST="${INSTALL_DIR}/statusline"
SETTINGS_FILE="${HOME}/.claude/settings.json"
TOML_FILE="${INSTALL_DIR}/statusline.toml"

if [[ "${INSTALL_DIR}" == "${HOME}/.claude" ]]; then
    COMMAND_PATH="~/.claude/statusline"
else
    COMMAND_PATH="${BINARY_DEST}"
fi

# ── Header / footer ────────────────────────────────────────────────────────────
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
    echo "Installed: ${BINARY_DEST}"
    echo ""
    echo -e "Next step: ${CYAN}Restart Claude Code to see your new statusline${NC}"
    echo ""
    echo "To update, run the installation command again."
    echo "To customize, edit ${TOML_FILE}"
    echo ""
}

# ── Trap ───────────────────────────────────────────────────────────────────────
cleanup_on_error() {
    echo ""
    error "Installation failed. No changes made."
    exit 1
}

# ── WSL detection ──────────────────────────────────────────────────────────────
is_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

# ── Dep version helper ─────────────────────────────────────────────────────────
dep_version() {
    "$1" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "found"
}

# ── Download with retries ──────────────────────────────────────────────────────
download_with_retries() {
    local url="$1"
    local dest="$2"
    local attempt=1

    while [[ ${attempt} -le ${MAX_RETRIES} ]]; do
        if curl -fsSL --output "${dest}" "${url}" 2>/dev/null; then
            return 0
        fi
        attempt=$((attempt + 1))
        [[ ${attempt} -le ${MAX_RETRIES} ]] && sleep 1
    done
    return 1
}

# ── Main ───────────────────────────────────────────────────────────────────────
print_header
trap cleanup_on_error ERR INT TERM

# [1/3] Check dependencies
step 1 "Checking dependencies..."

missing_deps=()
for dep in claude curl; do
    if ! command -v "${dep}" &>/dev/null; then
        missing_deps+=("${dep}")
    fi
done

if [[ ${#missing_deps[@]} -gt 0 ]]; then
    error "Missing dependencies: ${missing_deps[*]}"
    echo ""

    if [[ " ${missing_deps[*]} " == *" claude "* ]]; then
        echo -e "${CYAN}Claude Code CLI:${NC}"
        echo "  Visit https://claude.ai/code for installation instructions"
        echo ""
    fi

    if [[ " ${missing_deps[*]} " == *" curl "* ]]; then
        OS_NAME="$(uname -s)"
        echo -e "${CYAN}curl:${NC}"
        if [[ "${OS_NAME}" == "Darwin" ]]; then
            echo "  brew install curl"
        elif command -v apt-get &>/dev/null; then
            echo "  sudo apt-get update && sudo apt-get install curl"
        elif command -v dnf &>/dev/null; then
            echo "  sudo dnf install curl"
        elif command -v yum &>/dev/null; then
            echo "  sudo yum install curl"
        fi
        echo ""
    fi

    echo "Installation aborted. Install dependencies and try again."
    exit 1
fi

for dep in claude curl; do
    success "${dep} $(dep_version "${dep}")"
done

if is_wsl; then
    muted "Detected: WSL environment"
fi

# [2/3] Install binary
step 2 "Installing binary..."

OS="$(uname -s)"
case "${OS}" in
    Darwin) ASSET="statusline-macos" ;;
    Linux)  ASSET="statusline-linux-x64" ;;
    *)
        error "Unsupported OS: only macOS and Linux are supported."
        exit 1
        ;;
esac

TAG="$(curl -fsSL "${GITHUB_API}" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": "\(.*\)".*/\1/')"
if [[ -z "${TAG}" ]]; then
    error "Could not determine latest release tag."
    exit 1
fi

info "Downloading statusline ${TAG} for ${ASSET}..."

if ! mkdir -p "${INSTALL_DIR}" 2>/dev/null; then
    error "Cannot create install directory: ${INSTALL_DIR}"
    exit 1
fi

DOWNLOAD_URL="${GITHUB_DL_BASE}/${TAG}/${ASSET}"
if ! download_with_retries "${DOWNLOAD_URL}" "${BINARY_DEST}"; then
    error "Failed to download from ${DOWNLOAD_URL}"
    info "Check your internet connection and try again"
    exit 1
fi

if [[ ! -s "${BINARY_DEST}" ]]; then
    error "Downloaded file is empty"
    exit 1
fi

if ! chmod +x "${BINARY_DEST}"; then
    error "Failed to make binary executable"
    exit 1
fi

if [[ -f "${TOML_FILE}" ]]; then
    info "Config already exists, skipping: ${TOML_FILE}"
else
    if ! "${BINARY_DEST}" --print-defaults > "${TOML_FILE}"; then
        error "Failed to generate ${TOML_FILE}"
        exit 1
    fi
    success "Created default config: ${TOML_FILE}"
fi

success "Binary installed to ${BINARY_DEST}"

# [3/3] Configure Claude Code
step 3 "Configuring Claude Code..."

set +e
"${BINARY_DEST}" --configure-settings "${SETTINGS_FILE}" "${COMMAND_PATH}"
CFG_EXIT=$?
set -e

if [[ ${CFG_EXIT} -ne 0 ]]; then
    warn "Installation succeeded, but automatic configuration failed"
    echo ""
    echo "Please manually add to ~/.claude/settings.json:"
    echo "   {"
    echo "     \"statusLine\": {"
    echo "       \"type\": \"command\","
    echo "       \"command\": \"${COMMAND_PATH}\","
    echo "       \"padding\": 0"
    echo "     }"
    echo "   }"
    echo ""
    exit 2
fi

print_footer
