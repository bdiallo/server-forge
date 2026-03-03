#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: Users
# =============================================================================
# Create deploy user with SSH key authentication
# =============================================================================

MODULE_NAME="users"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  require_var DEPLOY_USER
  require_var DEPLOY_USER_SSH_KEY
  
  local username="${DEPLOY_USER}"
  local ssh_key="${DEPLOY_USER_SSH_KEY}"
  local home_dir="${DEPLOY_USER_HOME:-/home/${username}}"
  local add_sudo="${DEPLOY_USER_SUDO:-true}"
  
  # Create user
  log_step "Creating deploy user: ${username}"
  create_user "$username" "$home_dir"
  
  # Add to sudo group
  if is_true "$add_sudo"; then
    add_user_to_group "$username" "sudo"
    
    # Allow passwordless sudo
    log_substep "Configuring passwordless sudo"
    echo "${username} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${username}"
    chmod 440 "/etc/sudoers.d/${username}"
  fi
  
  # Configure SSH
  log_step "Configuring SSH for ${username}"
  
  local ssh_dir="${home_dir}/.ssh"
  ensure_dir "$ssh_dir" "$username"
  chmod 700 "$ssh_dir"
  
  # Add SSH key
  local authorized_keys="${ssh_dir}/authorized_keys"
  log_substep "Adding SSH key to authorized_keys"
  
  if [[ -f "$authorized_keys" ]]; then
    if ! grep -qF "$ssh_key" "$authorized_keys"; then
      echo "$ssh_key" >> "$authorized_keys"
    else
      log_substep "SSH key already present"
    fi
  else
    echo "$ssh_key" > "$authorized_keys"
  fi
  
  chown "${username}:${username}" "$authorized_keys"
  chmod 600 "$authorized_keys"
  
  # Create application directories
  log_step "Creating application directories"
  
  local dirs=(
    "/var/www"
    "/var/log/apps"
  )
  
  for dir in "${dirs[@]}"; do
    ensure_dir "$dir"
    chown "${username}:${username}" "$dir"
  done
  
  log_module_end "$MODULE_NAME"
}
