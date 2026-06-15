#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# ── Colors ──────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

success() { echo -e "${GREEN}✓${NC} $*"; }
info()    { echo -e "${CYAN}→${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*" >&2; }
error()   { echo -e "${RED}✗${NC} $*" >&2; }

INSTALL_DIR="${HOME}/.claude"
BINARY_DEST="${INSTALL_DIR}/statusline"
SETTINGS_FILE="${INSTALL_DIR}/settings.json"
TOML_FILE="${INSTALL_DIR}/statusline.toml"
COMMAND_PATH="${HOME}/.claude/statusline"

# [1/3] Build debug binary
info "[1/3] Building debug binary..."
cargo build
success "Build complete"

# [2/3] Deploy binary
info "[2/3] Copying binary to ${BINARY_DEST}..."
cp target/debug/statusline "${BINARY_DEST}"
chmod +x "${BINARY_DEST}"
success "Binary deployed to ${BINARY_DEST}"

# [2.5] Seed config if missing
if [[ -f "${TOML_FILE}" ]]; then
    info "Config already exists, skipping: ${TOML_FILE}"
else
    if ! "${BINARY_DEST}" --print-defaults > "${TOML_FILE}"; then
        rm -f "${TOML_FILE}"
        error "Failed to generate ${TOML_FILE}"
        exit 1
    fi
    success "Created default config: ${TOML_FILE}"
fi

# [3/3] Configure settings.json
warn "Overwriting statusLine with dev debug build"
set +e
"${BINARY_DEST}" --configure-settings "${SETTINGS_FILE}" "${COMMAND_PATH}"
CFG_EXIT=$?
set -e

if [[ ${CFG_EXIT} -ne 0 ]]; then
    warn "Could not update settings.json automatically"
    echo ""
    echo "Add manually to ~/.claude/settings.json:"
    echo '  {'
    echo '    "statusLine": {'
    echo '      "type": "command",'
    echo "      \"command\": \"${COMMAND_PATH}\","
    echo '      "padding": 0'
    echo '    }'
    echo '  }'
else
    success "settings.json updated"
fi

echo ""
success "Done. Restart Claude Code to pick up changes."
