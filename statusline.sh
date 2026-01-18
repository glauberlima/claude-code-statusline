#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures (bash 3.2+)

# ============================================================
# CONFIGURATION
# ============================================================
readonly BAR_WIDTH=15
readonly BAR_FILLED="█"
readonly BAR_EMPTY="░"

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
readonly MODEL_ICON="🚀"
readonly CONTEXT_ICON="🔥"
readonly DIR_ICON="📂"
readonly GIT_ICON="🎋"

# Git state constants
readonly STATE_NOT_REPO="not_repo"
readonly STATE_CLEAN="clean"
readonly STATE_DIRTY="dirty"

# Context usage message tiers (for random funny messages)
readonly CONTEXT_MSG_VERY_LOW=(
  "just getting started"
  "barely touched it"
  "rookie numbers"
  "fresh as a daisy"
  "room for an elephant"
  "barely scratched the surface"
  "context? what context?"
  "zero stress mode"
  "could do this all day"
  "warming up the engines"
  "practically empty"
  "haven't even started yet"
  "smooth sailing ahead"
  "testing the waters"
  "this will go far"
  "still cold in here"
  "didn't break a sweat"
  "taking it slow"
  "plenty of runway left"
  "all systems nominal"
  "hardly made a dent"
  "got room to spare"
)

readonly CONTEXT_MSG_LOW=(
  "ate and left no crumbs"
  "light snacking"
  "taking it easy"
  "smooth operator"
  "just vibing"
  "cruising altitude reached"
  "sipping not gulping"
  "nice and steady"
  "feeling good about this"
  "like a walk in the park"
  "barely breaking a sweat"
  "coasting along nicely"
  "comfortable cruise"
  "nibbling around the edges"
  "hasn't warmed up yet"
  "too comfortable"
  "zen mode activated"
  "this rhythm is good"
  "feeling just right"
  "total tranquility"
  "not bad so far"
  "looking good"
)

readonly CONTEXT_MSG_MEDIUM=(
  "halfway there"
  "finding the groove"
  "building momentum"
  "picking up speed"
  "getting interesting"
  "this is where the fun begins"
  "entering the zone"
  "momentum is building"
  "getting warmer"
  "midpoint madness"
  "balanced as all things should be"
  "sweet spot territory"
  "perfectly balanced"
  "getting serious now"
  "halfway walked"
  "warming the turbines"
  "started to heat up"
  "catching rhythm"
  "starting to feel it"
  "can feel the weight now"
  "neither cold nor hot"
  "this is balanced"
  "gears are meshing"
)

readonly CONTEXT_MSG_HIGH=(
  "getting spicy"
  "filling up fast"
  "things are heating up"
  "now we're talking"
  "turning up the heat"
  "entering danger zone"
  "feeling the pressure"
  "this is getting real"
  "approaching the red zone"
  "intensity rising"
  "no more mr nice bot"
  "getting toasty in here"
  "full throttle mode"
  "heated up for good"
  "starting to get hot"
  "on fire"
  "cauldron is boiling"
  "starting to get heavy"
  "serious now"
  "sweating bullets"
  "things getting serious"
  "here we go"
  "warming the engine"
  "hold on tight"
)

readonly CONTEXT_MSG_CRITICAL=(
  "living dangerously"
  "pushing the limits"
  "houston we have a problem"
  "danger zone activated"
  "code like there's no tomorrow"
  "running on fumes"
  "this is fine"
  "spicy spicy spicy"
  "critical mass approaching"
  "yolo mode engaged"
  "no safety net here"
  "maximum overdrive"
  "somebody stop me"
  "pedal to the metal"
  "context window go brrrr"
  "on fire now"
  "at the limit already"
  "about to explode"
  "now we're screwed"
  "limit coming in hot"
  "someone help please"
  "going to explode"
  "all or nothing now"
  "hold my drink"
  "burning up already"
  "this will end badly"
  "limit is here"
  "can't take it anymore"
)

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
# Rejects absolute paths, path traversal (..), and suspicious patterns
validate_directory() {
  local dir="$1"

  # Reject absolute paths (starting with /)
  [[ "${dir}" =~ ^/ ]] && return 1

  # Reject path traversal attempts (..)
  [[ "${dir}" =~ \.\. ]] && return 1

  # Reject paths starting with ~
  [[ "${dir}" =~ ^~ ]] && return 1

  return 0
}

# Format numbers with K/M suffixes for readability
# Examples: 543 -> "543", 1500 -> "1.5K", 54000 -> "54K", 1200000 -> "1.2M"
format_number() {
  local num="$1"

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

# Check git version for porcelain v2 support (requires git 2.11+)
# Cache result for performance
check_git_version() {
  # Return cached result if available
  [[ -n "${GIT_VERSION_CHECKED:-}" ]] && return "${GIT_VERSION_OK:-1}"

  GIT_VERSION_CHECKED=1
  command -v git >/dev/null 2>&1 || { GIT_VERSION_OK=1; return 1; }

  local version
  version=$(git --version 2>/dev/null | awk '{print $3}')
  [[ -z "${version}" ]] && { GIT_VERSION_OK=1; return 1; }

  # Semantic version comparison: >= 2.11
  local major minor
  IFS='.' read -r major minor _ << EOF
${version}
EOF

  if [[ "${major}" -gt 2 ]] || { [[ "${major}" -eq 2 ]] && [[ "${minor}" -ge 11 ]]; }; then
    GIT_VERSION_OK=0
    return 0
  else
    GIT_VERSION_OK=1
    return 1
  fi
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
    (.cost.total_cost_usd // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0)
  ' 2>/dev/null) || {
    echo "Error: Failed to parse JSON input" >&2
    return 1
  }

  echo "${parsed}"
}

build_progress_bar() {
  local percent="$1"
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

  # Build colored filled portion and gray empty portion
  echo -n "${bar_color}"
  printf "%${filled}s" | tr ' ' "${BAR_FILLED}"
  echo -n "${NC}${GRAY}"
  printf "%${empty}s" | tr ' ' "${BAR_EMPTY}"
  echo -n "${NC}"
}

# Get random context message based on usage percentage
get_context_message() {
  local percent="$1"
  local messages=()

  # Determine tier and select message array
  local tier
  tier=$(get_context_tier "${percent}")

  case "${tier}" in
    0) messages=("${CONTEXT_MSG_VERY_LOW[@]}") ;;
    1) messages=("${CONTEXT_MSG_LOW[@]}") ;;
    2) messages=("${CONTEXT_MSG_MEDIUM[@]}") ;;
    3) messages=("${CONTEXT_MSG_HIGH[@]}") ;;
    4) messages=("${CONTEXT_MSG_CRITICAL[@]}") ;;
    *) messages=("unknown tier") ;;  # Fallback
  esac

  # Random selection using bash $RANDOM
  local count=${#messages[@]}
  local index=$((RANDOM % count))
  echo "${messages[${index}]}"
}

# ============================================================
# GIT OPERATIONS (Optimized - 7 calls reduced to 2)
# ============================================================

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

  # Parse porcelain v2 output and count files in single pass
  local branch ahead behind total_files=0
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
${status_output}
EOF

  # Default values
  branch="${branch:-(detached HEAD)}"
  ahead="${ahead:-0}"
  behind="${behind:-0}"

  # Clean state if no files
  if [[ "${total_files}" -eq 0 ]]; then
    echo "${STATE_CLEAN}|${branch}|${ahead}|${behind}"
    return 0
  fi

  # Get line changes (single diff HEAD call replaces 2 separate cached + unstaged calls)
  local added removed
  read -r added removed << EOF
$(git "${git_opts[@]}" diff HEAD --numstat 2>/dev/null | awk '{a+=$1; r+=$2} END {print a+0, r+0}' || true)
EOF

  echo "${STATE_DIRTY}|${branch}|${total_files}|${added}|${removed}|${ahead}|${behind}"
}

# ============================================================
# FORMATTING FUNCTIONS (SOLID - Single Responsibility)
# ============================================================

format_ahead_behind() {
  local ahead="$1"
  local behind="$2"
  local output=""

  [[ "${ahead}" -gt 0 ]] 2>/dev/null && output+=" ${GREEN}↑${ahead}${NC}"
  [[ "${behind}" -gt 0 ]] 2>/dev/null && output+=" ${RED}↓${behind}${NC}"

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
  local branch="$1" files="$2" added="$3" removed="$4" ahead="$5" behind="$6"

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

  # Parse state
  local state
  IFS='|' read -r state _ << EOF
${git_data}
EOF

  case "${state}" in
    "${STATE_NOT_REPO}")
      # Returns "git_output|file_count" (empty file count)
      local not_repo_msg
      not_repo_msg=$(format_git_not_repo)
      echo "${not_repo_msg}|"
      ;;
    "${STATE_CLEAN}")
      local branch ahead behind
      IFS='|' read -r _ branch ahead behind << EOF
${git_data}
EOF
      # Returns "git_output|file_count" (empty file count for clean)
      local clean_msg
      clean_msg=$(format_git_clean "${branch}" "${ahead}" "${behind}")
      echo "${clean_msg}|"
      ;;
    "${STATE_DIRTY}")
      local branch files added removed ahead behind
      IFS='|' read -r _ branch files added removed ahead behind << EOF
${git_data}
EOF
      # Already returns "git_output|file_count"
      format_git_dirty "${branch}" "${files}" "${added}" "${removed}" "${ahead}" "${behind}"
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

  local context_percent=0
  if [[ "${current_usage}" != "0" && "${context_size}" -gt 0 ]]; then
    context_percent=$((current_usage * 100 / context_size))
  fi

  # Get colored progress bar
  local bar
  bar=$(build_progress_bar "${context_percent}")

  # Format usage numbers (e.g., "54K/200K")
  local usage_formatted
  usage_formatted=$(format_number "${current_usage}")
  local size_formatted
  size_formatted=$(format_number "${context_size}")

  # Get random funny message
  local message
  message=$(get_context_message "${context_percent}")

  # Output with brackets, colored bar, formatted numbers, and message
  echo "${CONTEXT_ICON} ${GRAY}[${NC}${bar}${GRAY}]${NC} ${context_percent}% ${usage_formatted}/${size_formatted} ${GRAY}|${NC} ${GRAY}${message}${NC}"
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
  local formatted git_line file_line
  formatted=$(format_git_info "${git_data}")
  IFS='|' read -r git_line file_line <<< "${formatted}"

  # Extract state to determine emoji placement
  local state
  IFS='|' read -r state _ << EOF
${git_data}
EOF

  # Return git info and file count separately: "git_display|file_count"
  if [[ "${state}" = "${STATE_NOT_REPO}" ]]; then
    echo "${git_line}|"
  else
    echo " ${GIT_ICON}${git_line}|${file_line}"
  fi
}

build_files_component() {
  local file_count="$1"

  # Only show if there are modified files
  if [[ -n "${file_count}" && "${file_count}" != "0" ]]; then
    echo "${GRAY}${file_count} files${NC}"
  fi
}

build_cost_component() {
  local cost_usd="$1"

  # Validate cost is numeric before printf (prevents format string injection)
  if [[ -n "${cost_usd}" && "${cost_usd}" != "0" && "${cost_usd}" != "${NULL_VALUE}" ]]; then
    # Check if value is a valid number (integer or decimal)
    if [[ "${cost_usd}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      echo "💵 ${GREEN}\$$(printf "%.2f" "${cost_usd}")${NC}"
    fi
  fi
}

build_lines_component() {
  local lines_added="$1"
  local lines_removed="$2"

  if [[ -n "${lines_added}" && -n "${lines_removed}" ]] && \
     [[ "${lines_added}" != "0" || "${lines_removed}" != "0" ]] && \
     [[ "${lines_added}" != "${NULL_VALUE}" && "${lines_removed}" != "${NULL_VALUE}" ]]; then
    echo "✏️  ${GREEN}+${lines_added}${NC}/${RED}-${lines_removed}${NC}"
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

  # New order: model | context | dir | git | files | cost
  output="${model_part}${separator}${context_part}${separator}${dir_part}${separator}${git_part}"

  # Add optional components
  [[ -n "${files_part}" ]] && output+="${separator}${files_part}"
  [[ -n "${cost_part}" ]] && output+="${separator}${cost_part}"

  echo -e "${output}"
}

# ============================================================
# MAIN (Simplified orchestration only)
# ============================================================

main() {
  # Check dependencies
  command -v jq >/dev/null 2>&1 || {
    echo "Error: jq required" >&2
    exit 1
  }

  # Read input (POSIX-compatible: cat instead of < /dev/stdin)
  local input
  input=$(cat) || {
    echo "Error: Failed to read stdin" >&2
    exit 1
  }

  # Parse JSON
  local parsed
  parsed=$(parse_claude_input "${input}")
  if [[ -z "${parsed}" ]]; then
    exit 1
  fi

  # Extract fields
  local model_name current_dir context_size current_usage cost_usd lines_added lines_removed
  {
    read -r model_name
    read -r current_dir
    read -r context_size
    read -r current_usage
    read -r cost_usd
    read -r lines_added
    read -r lines_removed
  } << EOF
${parsed}
EOF

  # Build components
  local model_part context_part dir_part git_part cost_part files_part
  model_part=$(build_model_component "${model_name}")
  context_part=$(build_context_component "${context_size}" "${current_usage}")
  dir_part=$(build_directory_component "${current_dir}")

  # Git component returns "git_display|file_count"
  local git_with_files file_count
  git_with_files=$(build_git_component "${current_dir}")
  IFS='|' read -r git_part file_count <<< "${git_with_files}"

  files_part=$(build_files_component "${file_count}")
  cost_part=$(build_cost_component "${cost_usd}")

  # Assemble and output (no lines_part)
  assemble_statusline "${model_part}" "${context_part}" "${dir_part}" "${git_part}" "${files_part}" "${cost_part}"
}

main "$@"