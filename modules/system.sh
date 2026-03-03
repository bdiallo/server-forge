#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: System
# =============================================================================
# System updates, essential packages, timezone configuration
# =============================================================================

MODULE_NAME="system"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  detect_distro
  
  # System update
  log_step "Updating system packages"
  pkg_update
  pkg_upgrade
  pkg_clean
  
  # Essential packages
  log_step "Installing essential packages"
  
  local packages=(
    curl
    wget
    gnupg
    ca-certificates
    apt-transport-https
    software-properties-common
    lsb-release
    build-essential
    git
    vim
    nano
    htop
    tree
    unzip
    zip
    net-tools
    dnsutils
    iputils-ping
    openssl
    libssl-dev
    logrotate
  )
  
  pkg_install "${packages[@]}"
  
  # Set timezone
  if has_var TIMEZONE; then
    log_step "Setting timezone: ${TIMEZONE}"
    timedatectl set-timezone "$TIMEZONE"
  fi
  
  log_module_end "$MODULE_NAME"
}
