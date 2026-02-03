#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures (bash 3.2+)

# ============================================================
# CONFIGURATION
# ============================================================
readonly BAR_WIDTH=15

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly ORANGE='\033[0;33m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m'

# Derived constants
readonly SEPARATOR="${GRAY}|${NC}"
readonly NULL_VALUE="null"

# Icons
readonly MODEL_ICON="🤖"
readonly CONTEXT_ICON="📊"
readonly DIR_ICON="📁"
readonly GIT_ICON="🌿"
readonly CHANGE_ICON="✏️"

# Git state constants
readonly STATE_NOT_REPO="not_repo"
readonly STATE_CLEAN="clean"
readonly STATE_DIRTY="dirty"

# i18n configuration
readonly DEFAULT_LANGUAGE="en"
readonly CONFIG_FILE="${CONFIG_FILE:-${HOME}/.claude/statusline-config.sh}"
readonly MESSAGES_DIR="${MESSAGES_DIR:-${HOME}/.claude/messages}"

# Progress bar characters
readonly BAR_FILLED="█"
readonly BAR_EMPTY="░"

# ============================================================
# I18N FUNCTIONS
# ============================================================

# Load user configuration
# Returns: "language|show_messages|show_cost" (pipe-separated)
load_config() {
  local config_file_json="${CONFIG_FILE%.sh}.json"

  # Load JSON config or use defaults
  if [[ -f "${config_file_json}" ]]; then
    jq -r '(.language // "en") + "|" + (.show_messages // true | tostring) + "|" + (.show_cost // true | tostring)' "${config_file_json}" 2>/dev/null || echo "en|true|true"
  else
    echo "en|true|true"
  fi
}

# Load language messages
# Args: $1 = language code
# Side effect: Defines CONTEXT_MSG_* variables in pipe-delimited format
load_language_messages() {
  local lang="$1"
  local lang_file_json="${MESSAGES_DIR}/${lang}.json"

  # Try to load JSON file
  if [[ -f "${lang_file_json}" ]]; then
    load_json_messages "${lang_file_json}"
    return 0
  fi

  # Fallback to default language
  if [[ "${lang}" != "${DEFAULT_LANGUAGE}" ]]; then
    load_language_messages "${DEFAULT_LANGUAGE}"
    return 0
  fi

  # Critical failure: no language files found
  echo "Error: Language file not found: ${lang_file_json}" >&2
  exit 1
}

# Load messages from JSON file
# Args: $1 = path to JSON file
# Side effect: Defines CONTEXT_MSG_* variables in pipe-delimited format
load_json_messages() {
  local json_file="$1"

  # Validate JSON file exists and is readable
  if [[ ! -f "${json_file}" ]] || [[ ! -r "${json_file}" ]]; then
    return 1
  fi

  # Parse JSON and convert arrays to pipe-delimited strings for compatibility
  # Use single jq call for efficiency
  local json_data
  json_data=$(jq -r '
    (.tiers.very_low // [] | join("|")),
    (.tiers.low // [] | join("|")),
    (.tiers.medium // [] | join("|")),
    (.tiers.high // [] | join("|")),
    (.tiers.critical // [] | join("|"))
  ' "${json_file}" 2>/dev/null)

  if [[ -z "${json_data}" ]]; then
    return 1
  fi

  # Parse the five lines into variables
  local line_num=0
  while IFS= read -r line; do
    case "${line_num}" in
      0) CONTEXT_MSG_VERY_LOW="${line}" ;;
      1) CONTEXT_MSG_LOW="${line}" ;;
      2) CONTEXT_MSG_MEDIUM="${line}" ;;
      3) CONTEXT_MSG_HIGH="${line}" ;;
      4) CONTEXT_MSG_CRITICAL="${line}" ;;
      *) ;; # Ignore extra lines
    esac
    ((line_num++)) || true
  done <<< "${json_data}"

  return 0
}

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

# String utilities
get_dirname() { echo "${1##*/}"; }
sep() { echo -n " ${SEPARATOR} "; }

# Conditional append helper (DRY pattern)
append_if() {
  local value="$1"
  local text="$2"
  if [[ "${value}" != "0" ]] 2>/dev/null && [[ -n "${value}" ]] && [[ "${value}" != "${NULL_VALUE}" ]]; then
    echo -n " ${text}"
  fi
}

# Validate directory path for security
# Rejects path traversal (..), tilde expansion (~), and shell metacharacters
validate_directory() {
  local dir="$1"

  # Reject path traversal attempts (..)
  [[ "${dir}" =~ \.\. ]] && return 1

  # Reject paths starting with ~
  [[ "${dir}" =~ ^~ ]] && return 1

  # Reject shell metacharacters (using case for better portability)
  case "${dir}" in
    *'$'*|*'`'*|*';'*) return 1 ;;
    *) return 0 ;;  # Valid path
  esac
}

# Format numbers with K/M suffixes for readability
# Examples: 543 -> "543", 1500 -> "1.5K", 54000 -> "54K", 1200000 -> "1.2M"
format_number() {
  local num="$1"

  # Validate input is a non-negative integer
  if ! [[ "${num}" =~ ^[0-9]+$ ]]; then
    echo "0"
    return 1
  fi

  if [[ "${num}" -lt 1000 ]]; then
    echo "${num}"
  elif [[ "${num}" -lt 1000000 ]]; then
    # Thousands
    local k=$((num / 1000))
    local remainder=$((num % 1000))
    if [[ "${k}" -lt 10 ]]; then
      # Show decimal for < 10K
      local decimal=$((remainder / 100))
      echo "${k}.${decimal}K"
    else
      echo "${k}K"
    fi
  else
    # Millions
    local m=$((num / 1000000))
    local remainder=$((num % 1000000))
    if [[ "${m}" -lt 10 ]]; then
      # Show decimal for < 10M
      local decimal=$((remainder / 100000))
      echo "${m}.${decimal}M"
    else
      echo "${m}M"
    fi
  fi
}

# Returns a random ANSI color code for context messages
# Uses modulo to select from predefined color pool (5 colors)
# Returns: ANSI color escape sequence
# Bash 3.2 compatible: uses pipe-delimited string instead of arrays
get_random_message_color() {
  local colors="${GREEN}|${CYAN}|${BLUE}|${MAGENTA}|${ORANGE}"
  local colors_count=5

  # Better distribution than simple modulo (reduces bias)
  local index=$(( (RANDOM * colors_count) / 32768 ))

  # Extract color using parameter expansion (Bash 3.2 compatible)
  local i=0
  local saved_ifs="${IFS}"
  IFS='|'
  for color in ${colors}; do
    if [[ ${i} -eq ${index} ]]; then
      IFS="${saved_ifs}"
      echo "${color}"
      return 0
    fi
    ((i++))
  done
  IFS="${saved_ifs}"

  # Fallback (should never reach)
  echo "${CYAN}"
}

# ============================================================
# FUNCTIONS
# ============================================================

# Get context usage tier (0-4) based on percentage
# Tiers: 0=very_low (0-20%), 1=low (21-40%), 2=medium (41-60%), 3=high (61-80%), 4=critical (81-100%)
get_context_tier() {
  local percent="$1"

  if [[ "${percent}" -le 20 ]]; then
    echo 0  # Very low
  elif [[ "${percent}" -le 40 ]]; then
    echo 1  # Low
  elif [[ "${percent}" -le 60 ]]; then
    echo 2  # Medium
  elif [[ "${percent}" -le 80 ]]; then
    echo 3  # High
  else
    echo 4  # Critical
  fi
}

parse_claude_input() {
  local input="$1"

  local parsed
  parsed=$(echo "${input}" | jq -r '
    .model.display_name,
    .workspace.current_dir,
    (.context_window.context_window_size // 200000),
    (
      (.context_window.current_usage.input_tokens // 0) +
      (.context_window.current_usage.cache_creation_input_tokens // 0) +
      (.context_window.current_usage.cache_read_input_tokens // 0)
    ),
    (.cost.total_cost_usd // 0)
  ' 2>/dev/null) || {
    echo "Error: Failed to parse JSON input" >&2
    return 1
  }

  echo "${parsed}"
}

build_progress_bar() {
  local percent="$1"

  # Clamp percent to 0-100 range (prevent negative/overflow)
  if [[ ${percent} -lt 0 ]]; then
    percent=0
  elif [[ ${percent} -gt 100 ]]; then
    percent=100
  fi

  local filled=$((percent * BAR_WIDTH / 100))
  local empty=$((BAR_WIDTH - filled))

  # Determine bar color based on tier
  local tier bar_color
  tier=$(get_context_tier "${percent}")

  case "${tier}" in
    0) bar_color="${GREEN}" ;;    # Very low
    1) bar_color="${CYAN}" ;;     # Low
    2) bar_color="${ORANGE}" ;;   # Medium
    3) bar_color="${ORANGE}" ;;   # High
    4) bar_color="${RED}" ;;      # Critical
    *) bar_color="${GRAY}" ;;     # Fallback
  esac

  # Build filled and empty portions (pure bash - UTF-8 safe)
  local filled_bar="" empty_bar=""
  local i
  for ((i=0; i<filled; i++)); do
    filled_bar+="${BAR_FILLED}"
  done
  for ((i=0; i<empty; i++)); do
    empty_bar+="${BAR_EMPTY}"
  done

  # Output with colors
  echo -n "${bar_color}${filled_bar}${NC}${GRAY}${empty_bar}${NC}"
}

# Get random context message based on usage percentage
# Bash 3.2 compatible: uses pipe-delimited strings instead of arrays
get_context_message() {
  local percent="$1"
  local msg_string=""

  # Determine tier and select message string
  local tier
  tier=$(get_context_tier "${percent}")

  # shellcheck disable=SC2154  # CONTEXT_MSG_* strings sourced from language files
  case "${tier}" in
    0) msg_string="${CONTEXT_MSG_VERY_LOW}" ;;
    1) msg_string="${CONTEXT_MSG_LOW}" ;;
    2) msg_string="${CONTEXT_MSG_MEDIUM}" ;;
    3) msg_string="${CONTEXT_MSG_HIGH}" ;;
    4) msg_string="${CONTEXT_MSG_CRITICAL}" ;;
    *) msg_string="unknown tier" ;;  # Fallback
  esac

  # Validate non-empty message string
  if [[ -z "${msg_string}" ]]; then
    echo "loading..."
    return 0
  fi

  # Count messages using IFS
  local count=0
  local saved_ifs="${IFS}"
  IFS='|'
  for _ in ${msg_string}; do
    ((count++))
  done
  IFS="${saved_ifs}"

  # Protect against division by zero
  if [[ ${count} -le 0 ]]; then
    echo "loading..."
    return 0
  fi

  # Better distribution (reduces bias for small counts)
  local index=$(( (RANDOM * count) / 32768 ))

  # Extract selected message
  local i=0
  IFS='|'
  for message in ${msg_string}; do
    if [[ ${i} -eq ${index} ]]; then
      IFS="${saved_ifs}"
      echo "${message}"
      return 0
    fi
    ((i++))
  done
  IFS="${saved_ifs}"

  # Fallback (should never reach)
  echo "loading..."
}

# ============================================================
# GIT OPERATIONS (Optimized - 7 calls reduced to 2)
# ============================================================

# Helper function to parse git status output with isolated IFS
# Returns: "STATE|branch|total_files|ahead|behind"
parse_git_status_output() {
  local output="$1"
  local line branch="" ahead="0" behind="0" total_files=0
  local saved_ifs="${IFS}"

  # Parse with IFS isolated to this function
  while IFS= read -r line; do
    case "${line}" in
      "# branch.head "*)
        branch="${line#\# branch.head }"
        ;;
      "# branch.ab "*)
        local ab="${line#\# branch.ab }"
        ahead="${ab%% *}"
        ahead="${ahead#+}"
        behind="${ab##* }"
        behind="${behind#-}"
        ;;
      "#"*)
        # Ignore other comment lines
        ;;
      *)
        # Non-comment lines are file status entries - count them
        [[ -n "${line}" ]] && ((total_files++))
        ;;
    esac
  done << EOF
${output}
EOF

  # Restore IFS
  IFS="${saved_ifs}"

  # Default values
  branch="${branch:-(detached HEAD)}"
  ahead="${ahead:-0}"
  behind="${behind:-0}"

  # Determine state
  if [[ "${total_files}" -eq 0 ]]; then
    echo "${STATE_CLEAN}|${branch}|0|${ahead}|${behind}"
  else
    echo "${STATE_DIRTY}|${branch}|${total_files}|${ahead}|${behind}"
  fi
}

get_git_info() {
  local current_dir="$1"
  local git_opts=()

  # Validate and set git directory option
  if [[ -n "${current_dir}" ]] && [[ "${current_dir}" != "${NULL_VALUE}" ]]; then
    # Invoke validation separately to avoid masking return value
    local validation_result=0
    validate_directory "${current_dir}"
    validation_result=$?
    if [[ "${validation_result}" -eq 0 ]]; then
      git_opts=(-C "${current_dir}")
    else
      # Invalid directory path - treat as not a repo
      echo "${STATE_NOT_REPO}"
      return 0
    fi
  fi

  # Check if git repo
  git "${git_opts[@]}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "${STATE_NOT_REPO}"
    return 0
  }

  # Single git status call with all info (replaces 5 separate calls)
  # Requires Git 2.11+ (Dec 2016) for --porcelain=v2
  local status_output
  status_output=$(git "${git_opts[@]}" status --porcelain=v2 --branch --untracked-files=all 2>/dev/null) || {
    echo "${STATE_NOT_REPO}"
    return 0
  }

  # Parse using helper function (IFS isolation)
  parse_git_status_output "${status_output}"
}

# ============================================================
# FORMATTING FUNCTIONS (SOLID - Single Responsibility)
# ============================================================

format_ahead_behind() {
  local ahead="$1"
  local behind="$2"
  local output=""

  # Validate numeric before arithmetic (maintain existing 2>/dev/null as requested)
  if [[ "${ahead}" =~ ^[0-9]+$ ]] && [[ "${ahead}" -gt 0 ]] 2>/dev/null; then
    output+=" ${GREEN}↑${ahead}${NC}"
  fi

  if [[ "${behind}" =~ ^[0-9]+$ ]] && [[ "${behind}" -gt 0 ]] 2>/dev/null; then
    output+=" ${RED}↓${behind}${NC}"
  fi

  [[ -n "${output}" ]] && echo "${GRAY}|${NC}${output}"
}

format_git_not_repo() {
  echo " ${ORANGE}(not a git repository)${NC}"
}

format_git_clean() {
  local branch="$1" ahead="$2" behind="$3"

  # Simple format: branch + ahead/behind (no parentheses)
  local output="${MAGENTA}${branch}${NC}"
  local ahead_behind
  ahead_behind=$(format_ahead_behind "${ahead}" "${behind}")
  [[ -n "${ahead_behind}" ]] && output+="${ahead_behind}"

  echo " ${output}"
}

format_git_dirty() {
  local branch="$1" files="$2" ahead="$3" behind="$4"

  # Simple branch + ahead/behind (no file count, no line changes)
  local output="${MAGENTA}${branch}${NC}"
  local ahead_behind
  ahead_behind=$(format_ahead_behind "${ahead}" "${behind}")
  [[ -n "${ahead_behind}" ]] && output+="${ahead_behind}"

  # Return git info and file count separately: "git_output|file_count"
  echo " ${output}|${files}"
}

format_git_info() {
  local git_data="$1"

  # Parse state with IFS protection
  local state saved_ifs
  saved_ifs="${IFS}"
  IFS='|' read -r state _ << EOF
${git_data}
EOF
  IFS="${saved_ifs}"

  case "${state}" in
    "${STATE_NOT_REPO}")
      # Returns "git_output|file_count" (empty file count)
      local not_repo_msg
      not_repo_msg=$(format_git_not_repo)
      echo "${not_repo_msg}|"
      ;;
    "${STATE_CLEAN}")
      local branch ahead behind
      saved_ifs="${IFS}"
      IFS='|' read -r _ branch ahead behind << EOF
${git_data}
EOF
      IFS="${saved_ifs}"
      # Returns "git_output|file_count" (empty file count for clean)
      local clean_msg
      clean_msg=$(format_git_clean "${branch}" "${ahead}" "${behind}")
      echo "${clean_msg}|"
      ;;
    "${STATE_DIRTY}")
      local branch files ahead behind
      saved_ifs="${IFS}"
      IFS='|' read -r _ branch files ahead behind << EOF
${git_data}
EOF
      IFS="${saved_ifs}"
      # Already returns "git_output|file_count"
      format_git_dirty "${branch}" "${files}" "${ahead}" "${behind}"
      ;;
    *)
      # Unknown state - show error
      echo " ${ORANGE}(unknown git state)${NC}|"
      ;;
  esac
}

# ============================================================
# COMPONENT BUILDERS (Open/Closed Principle)
# ============================================================

build_model_component() {
  local model_name="$1"
  echo "${MODEL_ICON} ${CYAN}${model_name}${NC}"
}

build_context_component() {
  local context_size="$1"
  local current_usage="$2"
  local show_messages="${3:-true}"  # Default true for backwards compat

  # Calculate percentage with division-by-zero protection
  # Reorder arithmetic: multiply first, then divide (prevents division by zero when context_size < 100)
  local context_percent=0
  if [[ "${current_usage}" -gt 0 ]] && [[ "${context_size}" -gt 0 ]]; then
    context_percent=$(( (current_usage * 100) / context_size ))

    # Clamp to 0-100 range (prevent overflow)
    if [[ ${context_percent} -gt 100 ]]; then
      context_percent=100
    elif [[ ${context_percent} -lt 0 ]]; then
      context_percent=0
    fi
  fi

  # Get colored progress bar
  local bar
  bar=$(build_progress_bar "${context_percent}")

  # Format usage numbers (e.g., "54K/200K")
  local usage_formatted
  usage_formatted=$(format_number "${current_usage}")
  local size_formatted
  size_formatted=$(format_number "${context_size}")

  # Build message part conditionally
  local message_part=""
  if [[ "${show_messages}" == "true" ]]; then
    local message
    message=$(get_context_message "${context_percent}")

    local msg_color
    msg_color=$(get_random_message_color)

    message_part=" ${GRAY}|${NC} ${msg_color}${message}${NC}"
  fi

  # Output with brackets, colored bar, formatted numbers, and optional message
  echo "${CONTEXT_ICON} ${GRAY}[${NC}${bar}${GRAY}]${NC} ${context_percent}% ${usage_formatted}/${size_formatted}${message_part}"
}

build_directory_component() {
  local current_dir="$1"

  local dir_name
  if [[ -n "${current_dir}" ]] && [[ "${current_dir}" != "${NULL_VALUE}" ]]; then
    dir_name=$(get_dirname "${current_dir}")
  else
    dir_name=$(get_dirname "${PWD}")
  fi

  echo "${DIR_ICON} ${BLUE}${dir_name}${NC}"
}

build_git_component() {
  local current_dir="$1"
  local git_data

  git_data=$(get_git_info "${current_dir}")

  # format_git_info returns "git_output|file_count" format
  local formatted git_line file_line saved_ifs
  formatted=$(format_git_info "${git_data}")
  saved_ifs="${IFS}"
  IFS='|' read -r git_line file_line <<< "${formatted}"
  IFS="${saved_ifs}"

  # Extract state to determine emoji placement
  local state
  saved_ifs="${IFS}"
  IFS='|' read -r state _ << EOF
${git_data}
EOF
  IFS="${saved_ifs}"

  # Return git info and file count separately: "git_display|file_count"
  if [[ "${state}" = "${STATE_NOT_REPO}" ]]; then
    echo "${git_line#* }|"
  else
    echo "${GIT_ICON} ${git_line#* }|${file_line}"
  fi
}

build_files_component() {
  local file_count="$1"

  # Only show if there are modified files
  if [[ -n "${file_count}" && "${file_count}" != "0" ]]; then
    echo "${CHANGE_ICON} ${ORANGE}changes${NC}"
  fi
}

build_cost_component() {
  local cost_usd="$1"
  local show_cost="${2:-true}"  # Default true for backwards compat

  # Early return if disabled
  [[ "${show_cost}" != "true" ]] && return

  # Validate cost is numeric before printf (prevents format string injection)
  if [[ -n "${cost_usd}" && "${cost_usd}" != "0" && "${cost_usd}" != "${NULL_VALUE}" ]]; then
    # Check if value is a valid number (integer or decimal)
    if [[ "${cost_usd}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      echo "💰 ${GREEN}\$$(printf "%.2f" "${cost_usd}")${NC}"
    fi
  fi
}

# ============================================================
# ASSEMBLY (KISS - Simple orchestration)
# ============================================================

assemble_statusline() {
  local model_part="$1"
  local context_part="$2"
  local dir_part="$3"
  local git_part="$4"
  local files_part="$5"
  local cost_part="$6"

  # Build output with separators
  local output separator
  separator=$(sep)

  # New order: dir | git | files | model | context | cost
  output="${dir_part}${separator}${git_part}"

  # Add optional components
  [[ -n "${files_part}" ]] && output+="${separator}${files_part}"

  # Add model and context
  output+="${separator}${model_part}${separator}${context_part}"

  # Add cost if present
  [[ -n "${cost_part}" ]] && output+="${separator}${cost_part}"

  echo -e "${output}"
}

# ============================================================
# MAIN (Simplified orchestration only)
# ============================================================

main() {
  # Validate environment
  if [[ -z "${HOME}" ]]; then
    echo "Error: HOME environment variable not set" >&2
    exit 1
  fi

  # Check dependencies
  command -v jq >/dev/null 2>&1 || {
    echo "Error: jq required" >&2
    exit 1
  }

  # Load configuration and language messages
  local user_config show_messages show_cost
  user_config=$(load_config)

  # Parse config: "language|show_messages|show_cost"
  local user_language saved_ifs
  saved_ifs="${IFS}"
  IFS='|' read -r user_language show_messages show_cost <<< "${user_config}"
  IFS="${saved_ifs}"

  load_language_messages "${user_language}"

  # Check if stdin is a TTY (not piped input)
  if [[ -t 0 ]]; then
    echo "Error: statusline.sh expects JSON input via stdin" >&2
    echo ""
    echo "Usage: cat test-input.json | ./statusline.sh" >&2
    echo "  Or: ./tests/unit.sh ./statusline.sh" >&2
    echo "  Or: ./tests/integration.sh ./statusline.sh" >&2
    echo "  Or: ./tests/shellcheck.sh ./statusline.sh" >&2
    exit 1
  fi

  # Read input (POSIX-compatible: cat instead of < /dev/stdin)
  local input
  input=$(cat) || {
    echo "Error: Failed to read stdin" >&2
    exit 1
  }

  # Validate non-empty input
  if [[ -z "${input}" ]]; then
    echo "Error: Empty JSON input received" >&2
    exit 1
  fi

  # Parse JSON
  local parsed
  parsed=$(parse_claude_input "${input}")
  if [[ -z "${parsed}" ]]; then
    exit 1
  fi

  # Validate field count (expected: 5 lines)
  local line_count
  line_count=$(echo "${parsed}" | wc -l)
  if [[ ${line_count} -ne 5 ]]; then
    echo "Error: Expected 5 fields from JSON, got ${line_count}" >&2
    exit 1
  fi

  # Extract fields
  local model_name current_dir context_size current_usage cost_usd
  {
    read -r model_name
    read -r current_dir
    read -r context_size
    read -r current_usage
    read -r cost_usd
  } << EOF
${parsed}
EOF

  # Build components (pass toggle flags)
  local model_part context_part dir_part git_part cost_part files_part
  model_part=$(build_model_component "${model_name}")
  context_part=$(build_context_component "${context_size}" "${current_usage}" "${show_messages}")
  dir_part=$(build_directory_component "${current_dir}")

  # Git component returns "git_display|file_count"
  local git_with_files file_count
  git_with_files=$(build_git_component "${current_dir}")
  saved_ifs="${IFS}"
  IFS='|' read -r git_part file_count <<< "${git_with_files}"
  IFS="${saved_ifs}"

  files_part=$(build_files_component "${file_count}")
  cost_part=$(build_cost_component "${cost_usd}" "${show_cost}")

  # Assemble and output (no lines_part)
  assemble_statusline "${model_part}" "${context_part}" "${dir_part}" "${git_part}" "${files_part}" "${cost_part}"
}

main "$@"