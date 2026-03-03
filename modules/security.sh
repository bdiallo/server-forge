#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: Security
# =============================================================================
# Firewall (UFW), fail2ban, SSH hardening
# =============================================================================

MODULE_NAME="security"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  
  # UFW Firewall
  if is_true "${FIREWALL_ENABLED:-true}"; then
    setup_firewall
  fi
  
  # Fail2ban
  if is_true "${FAIL2BAN_ENABLED:-true}"; then
    setup_fail2ban
  fi
  
  # SSH hardening
  if is_true "${SSH_HARDENING:-true}"; then
    setup_ssh_hardening
  fi
  
  log_module_end "$MODULE_NAME"
}

setup_firewall() {
  log_step "Configuring UFW firewall"
  
  pkg_install ufw
  
  # Reset to defaults
  log_substep "Resetting UFW to defaults"
  ufw --force reset >/dev/null
  
  # Default policies
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  
  # Parse allowed ports
  local ssh_port="${SSH_PORT:-22}"
  local ports="${FIREWALL_ALLOWED_PORTS:-22 80 443}"
  
  # Always allow SSH first
  log_substep "Allowing SSH on port ${ssh_port}"
  ufw allow "${ssh_port}/tcp" >/dev/null
  
  # Allow other ports
  for port in $ports; do
    if [[ "$port" != "$ssh_port" ]]; then
      log_substep "Allowing port ${port}"
      ufw allow "$port" >/dev/null
    fi
  done
  
  # Enable UFW
  log_substep "Enabling UFW"
  ufw --force enable >/dev/null
  
  log_success "Firewall configured"
}

setup_fail2ban() {
  log_step "Configuring fail2ban"
  
  pkg_install fail2ban
  
  # Create local config
  local config="/etc/fail2ban/jail.local"
  
  if [[ ! -f "$config" ]]; then
    cat > "$config" << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
EOF
  fi
  
  service_enable fail2ban
  service_restart fail2ban
  
  log_success "fail2ban configured"
}

setup_ssh_hardening() {
  log_step "Hardening SSH configuration"
  
  local sshd_config="/etc/ssh/sshd_config"
  backup_file "$sshd_config"
  
  # Disable password authentication
  log_substep "Disabling password authentication"
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$sshd_config"
  sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$sshd_config"
  sed -i 's/^#*UsePAM.*/UsePAM yes/' "$sshd_config"
  
  # Disable root login with password (allow key-based)
  log_substep "Restricting root login to key-based only"
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' "$sshd_config"
  
  # Change SSH port if specified
  if has_var SSH_PORT && [[ "${SSH_PORT}" != "22" ]]; then
    log_substep "Changing SSH port to ${SSH_PORT}"
    sed -i "s/^#*Port.*/Port ${SSH_PORT}/" "$sshd_config"
  fi
  
  # Additional hardening
  append_if_missing "$sshd_config" "MaxAuthTries 3"
  append_if_missing "$sshd_config" "LoginGraceTime 30"
  append_if_missing "$sshd_config" "ClientAliveInterval 300"
  append_if_missing "$sshd_config" "ClientAliveCountMax 2"
  
  # Restart SSH
  service_restart sshd
  
  log_success "SSH hardened"
}
