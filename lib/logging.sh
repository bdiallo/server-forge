#!/usr/bin/env bash
# =============================================================================
# ServerForge - Logging Functions
# =============================================================================

# Source colors if not already loaded
[[ -z "$COLOR_RESET" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Prefix for all log messages
LOG_PREFIX="[ServerForge]"

# Log levels
log_info() {
  echo -e "${COLOR_BLUE}${LOG_PREFIX}${COLOR_RESET} $*"
}

log_success() {
  echo -e "${COLOR_GREEN}${LOG_PREFIX} ✓${COLOR_RESET} $*"
}

log_warning() {
  echo -e "${COLOR_YELLOW}${LOG_PREFIX} ⚠${COLOR_RESET} $*"
}

log_error() {
  echo -e "${COLOR_RED}${LOG_PREFIX} ✗${COLOR_RESET} $*" >&2
}

log_debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    echo -e "${COLOR_DIM}${LOG_PREFIX} [DEBUG]${COLOR_RESET} $*"
  fi
}

log_step() {
  echo -e "\n${COLOR_CYAN}${COLOR_BOLD}==>${COLOR_RESET} ${COLOR_BOLD}$*${COLOR_RESET}"
}

log_substep() {
  echo -e "  ${COLOR_MAGENTA}→${COLOR_RESET} $*"
}

# Print a header
log_header() {
  local title="$1"
  echo -e ""
  echo -e "${COLOR_BOLD}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_BOLD}║  🔨 $title${COLOR_RESET}"
  echo -e "${COLOR_BOLD}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
  echo -e ""
}

# Print module start
log_module_start() {
  local module_name="$1"
  echo -e ""
  echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
  echo -e "${COLOR_CYAN}${COLOR_BOLD}  📦 Module: ${module_name}${COLOR_RESET}"
  echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

# Print module end
log_module_end() {
  local module_name="$1"
  echo -e ""
  echo -e "${COLOR_GREEN}${COLOR_BOLD}  ✓ Module ${module_name} completed${COLOR_RESET}"
  echo -e ""
}

# Exit with error
die() {
  log_error "$*"
  exit 1
}

# Ask for confirmation
# Auto-accepts when stdin is not a terminal (e.g. remote execution via SSH)
confirm() {
  local message="${1:-Continue?}"
  if [[ ! -t 0 ]]; then
    return 0
  fi
  echo -e ""
  read -p "${COLOR_YELLOW}${message} [y/N]${COLOR_RESET} " -n 1 -r
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]]
}

export -f log_info log_success log_warning log_error log_debug
export -f log_step log_substep log_header log_module_start log_module_end
export -f die confirm
