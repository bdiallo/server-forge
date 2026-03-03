#!/usr/bin/env bash
# =============================================================================
# ServerForge - Terminal Colors
# =============================================================================

# Check if terminal supports colors
if [[ -t 1 ]] && [[ -n "$TERM" ]] && [[ "$TERM" != "dumb" ]]; then
  COLOR_RESET=$'\033[0m'
  COLOR_RED=$'\033[0;31m'
  COLOR_GREEN=$'\033[0;32m'
  COLOR_YELLOW=$'\033[0;33m'
  COLOR_BLUE=$'\033[0;34m'
  COLOR_MAGENTA=$'\033[0;35m'
  COLOR_CYAN=$'\033[0;36m'
  COLOR_WHITE=$'\033[0;37m'
  COLOR_BOLD=$'\033[1m'
  COLOR_DIM=$'\033[2m'
else
  COLOR_RESET=""
  COLOR_RED=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_BLUE=""
  COLOR_MAGENTA=""
  COLOR_CYAN=""
  COLOR_WHITE=""
  COLOR_BOLD=""
  COLOR_DIM=""
fi

export COLOR_RESET COLOR_RED COLOR_GREEN COLOR_YELLOW COLOR_BLUE
export COLOR_MAGENTA COLOR_CYAN COLOR_WHITE COLOR_BOLD COLOR_DIM
