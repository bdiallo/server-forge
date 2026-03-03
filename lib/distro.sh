#!/usr/bin/env bash
# =============================================================================
# ServerForge - Distribution Detection & Package Management
# =============================================================================

# Source logging if not already loaded
[[ -z "$LOG_PREFIX" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Distribution info (populated by detect_distro)
DISTRO_ID=""
DISTRO_VERSION=""
DISTRO_CODENAME=""
DISTRO_NAME=""
DISTRO_FAMILY=""

# Detect Linux distribution
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO_ID="${ID}"
    DISTRO_VERSION="${VERSION_ID}"
    DISTRO_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
    DISTRO_NAME="${PRETTY_NAME}"
  else
    die "Cannot detect distribution: /etc/os-release not found"
  fi

  # Determine distribution family
  case "${DISTRO_ID}" in
    ubuntu|debian|linuxmint|pop)
      DISTRO_FAMILY="debian"
      ;;
    centos|rhel|fedora|rocky|alma)
      DISTRO_FAMILY="rhel"
      ;;
    *)
      die "Unsupported distribution: ${DISTRO_ID}"
      ;;
  esac

  # Validate supported distributions
  case "${DISTRO_ID}" in
    ubuntu|debian)
      log_info "Detected: ${DISTRO_NAME}"
      ;;
    *)
      die "Currently only Debian and Ubuntu are supported. Detected: ${DISTRO_ID}"
      ;;
  esac

  export DISTRO_ID DISTRO_VERSION DISTRO_CODENAME DISTRO_NAME DISTRO_FAMILY
}

# Check if running on Debian
is_debian() {
  [[ "${DISTRO_ID}" == "debian" ]]
}

# Check if running on Ubuntu
is_ubuntu() {
  [[ "${DISTRO_ID}" == "ubuntu" ]]
}

# Check if Debian family
is_debian_family() {
  [[ "${DISTRO_FAMILY}" == "debian" ]]
}

# Get package manager command
get_pkg_manager() {
  if is_debian_family; then
    echo "apt-get"
  else
    echo "dnf"
  fi
}

# Update package lists
pkg_update() {
  log_substep "Updating package lists..."
  if is_debian_family; then
    apt-get update -qq
  fi
}

# Install packages if not already installed
pkg_install() {
  local packages=("$@")
  local to_install=()

  for pkg in "${packages[@]}"; do
    if ! is_installed "$pkg"; then
      to_install+=("$pkg")
    fi
  done

  if [[ ${#to_install[@]} -gt 0 ]]; then
    log_substep "Installing: ${to_install[*]}"
    if is_debian_family; then
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${to_install[@]}"
    fi
  else
    log_substep "Already installed: ${packages[*]}"
  fi
}

# Check if a package is installed
is_installed() {
  local pkg="$1"
  if is_debian_family; then
    dpkg -l "$pkg" &>/dev/null
  fi
}

# Remove packages
pkg_remove() {
  local packages=("$@")
  log_substep "Removing: ${packages[*]}"
  if is_debian_family; then
    apt-get remove -y -qq "${packages[@]}"
  fi
}

# Upgrade all packages
pkg_upgrade() {
  log_substep "Upgrading packages..."
  if is_debian_family; then
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
  fi
}

# Clean package cache
pkg_clean() {
  log_substep "Cleaning package cache..."
  if is_debian_family; then
    apt-get autoremove -y -qq
    apt-get clean
  fi
}

export -f detect_distro is_debian is_ubuntu is_debian_family
export -f get_pkg_manager pkg_update pkg_install is_installed
export -f pkg_remove pkg_upgrade pkg_clean
export DISTRO_ID DISTRO_VERSION DISTRO_CODENAME DISTRO_NAME DISTRO_FAMILY
