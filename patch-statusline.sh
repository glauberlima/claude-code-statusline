#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ============================================================
# patch-statusline.sh - Static Message Patching Tool
# ============================================================
#
# Patches statusline.sh with:
# - Custom language messages (from JSON files)
# - Feature toggles (--no-messages, --no-cost)
#
# Usage:
#   ./patch-statusline.sh <statusline-file> [language-json] [--no-messages] [--no-cost]
#
# Examples:
#   ./patch-statusline.sh statusline.sh messages/pt.json
#   ./patch-statusline.sh statusline.sh --no-messages
#   ./patch-statusline.sh statusline.sh messages/es.json --no-cost
#

# ============================================================
# FUNCTIONS
# ============================================================

show_usage() {
  echo "Usage: $0 <statusline-file> [language-json] [--no-messages] [--no-cost]"
  echo ""
  echo "Arguments:"
  echo "  statusline-file   Path to statusline.sh file (required)"
  echo "  language-json     Path to JSON messages file (optional)"
  echo "  --no-messages     Disable context messages"
  echo "  --no-cost         Disable cost tracking"
  echo ""
  echo "Examples:"
  echo "  $0 statusline.sh messages/pt.json"
  echo "  $0 statusline.sh --no-messages"
  echo "  $0 statusline.sh messages/es.json --no-cost"
}

# Replace @CONFIG_START to @CONFIG_END block
replace_config_block() {
  local file="$1"
  local show_messages="$2"
  local show_cost="$3"
  local temp_file
  temp_file=$(mktemp)

  # Extract everything before @CONFIG_START (inclusive)
  sed -n '1,/@CONFIG_START/p' "${file}" > "${temp_file}"

  # Insert new config
  {
    echo "readonly SHOW_MESSAGES=${show_messages}"
    echo "readonly SHOW_COST=${show_cost}"
  } >> "${temp_file}"

  # Extract everything from @CONFIG_END onwards (inclusive)
  sed -n '/@CONFIG_END/,$p' "${file}" >> "${temp_file}"

  # Preserve original file permissions
  chmod --reference="${file}" "${temp_file}" 2>/dev/null || chmod +x "${temp_file}"

  mv "${temp_file}" "${file}"
}

# Replace @MESSAGES_START to @MESSAGES_END block
replace_messages_block() {
  local file="$1"
  local json_file="$2"
  local temp_file
  temp_file=$(mktemp)

  # Single node call extracts all 5 tiers, one per output line.
  # Replicates jq's @sh: wraps each string in single quotes, escaping ' as '\''
  # Path passed via process.argv to avoid shell injection from special chars in path.
  local tier_output very_low low medium high critical
  tier_output=$(node -e "
    var f = process.argv[process.argv.length - 1];
    var d = JSON.parse(require('fs').readFileSync(f, 'utf8'));
    var q = function(s) { return \"'\" + s.replace(/'/g, \"'\\\\''\" ) + \"'\"; };
    ['very_low','low','medium','high','critical'].forEach(function(t) {
      process.stdout.write(d[t].map(q).join(' ') + '\n');
    });
  " "${json_file}") || {
    echo "Error: Failed to extract messages from ${json_file}" >&2
    rm -f "${temp_file}"
    return 1
  }

  {
    IFS= read -r very_low
    IFS= read -r low
    IFS= read -r medium
    IFS= read -r high
    IFS= read -r critical
  } <<< "${tier_output}"

  # Extract before marker
  sed -n '1,/@MESSAGES_START/p' "${file}" > "${temp_file}"

  # Insert new arrays (no quotes around ${var} since shell-quoting already applied)
  {
    echo "readonly CONTEXT_MSG_VERY_LOW=(${very_low})"
    echo "readonly CONTEXT_MSG_LOW=(${low})"
    echo "readonly CONTEXT_MSG_MEDIUM=(${medium})"
    echo "readonly CONTEXT_MSG_HIGH=(${high})"
    echo "readonly CONTEXT_MSG_CRITICAL=(${critical})"
  } >> "${temp_file}"

  # Extract from marker onwards
  sed -n '/@MESSAGES_END/,$p' "${file}" >> "${temp_file}"

  # Preserve original file permissions
  chmod --reference="${file}" "${temp_file}" 2>/dev/null || chmod +x "${temp_file}"

  mv "${temp_file}" "${file}"
}

# ============================================================
# MAIN
# ============================================================

main() {
  # Check minimum arguments
  if [[ $# -lt 1 ]]; then
    show_usage
    exit 1
  fi

  # Parse arguments
  local statusline_file="$1"
  local language_json=""
  local show_messages=true
  local show_cost=true

  # Parse remaining args
  shift
  for arg in "$@"; do
    case "${arg}" in
      --no-messages)
        show_messages=false
        ;;
      --no-cost)
        show_cost=false
        ;;
      *.json)
        language_json="${arg}"
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      *)
        echo "Error: Unknown argument: ${arg}" >&2
        show_usage
        exit 1
        ;;
    esac
  done

  # Validate statusline file exists
  if [[ ! -f "${statusline_file}" ]]; then
    echo "Error: File not found: ${statusline_file}" >&2
    exit 1
  fi

  # Validate JSON file if provided
  if [[ -n "${language_json}" ]] && [[ ! -f "${language_json}" ]]; then
    echo "Error: JSON file not found: ${language_json}" >&2
    exit 1
  fi

  # Check node dependency (required for JSON parsing)
  command -v node >/dev/null 2>&1 || {
    echo "Error: node is required but not installed" >&2
    echo "Install Node.js from https://nodejs.org" >&2
    exit 1
  }

  # Validate markers exist
  if ! grep -q '@CONFIG_START' "${statusline_file}"; then
    echo "Error: @CONFIG_START marker not found in ${statusline_file}" >&2
    exit 1
  fi
  if ! grep -q '@MESSAGES_START' "${statusline_file}"; then
    echo "Error: @MESSAGES_START marker not found in ${statusline_file}" >&2
    exit 1
  fi

  # Perform patching
  echo "Patching ${statusline_file}..."

  # 1. Replace CONFIG block
  replace_config_block "${statusline_file}" "${show_messages}" "${show_cost}"
  echo "  ✓ Updated configuration (SHOW_MESSAGES=${show_messages}, SHOW_COST=${show_cost})"

  # 2. Replace MESSAGES block (if language JSON provided)
  if [[ -n "${language_json}" ]]; then
    # Validate JSON syntax
    if ! node -e "JSON.parse(require('fs').readFileSync(process.argv[process.argv.length-1],'utf8'))" \
         "${language_json}" 2>/dev/null; then
      echo "Error: Invalid JSON in ${language_json}" >&2
      exit 1
    fi

    replace_messages_block "${statusline_file}" "${language_json}"
    echo "  ✓ Updated messages from ${language_json}"
  else
    echo "  ⊘ Keeping existing messages (no JSON file provided)"
  fi

  # 3. Validate output
  if ! bash -n "${statusline_file}" 2>&1; then
    echo ""
    echo "Error: Patched script has syntax errors" >&2
    exit 1
  fi

  echo ""
  echo "✓ Patched successfully: ${statusline_file}"
}

main "$@"
