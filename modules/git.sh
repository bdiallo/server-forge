#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: Git
# =============================================================================
# Install and configure Git
# =============================================================================

MODULE_NAME="git"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  require_var DEPLOY_USER
  
  local username="${DEPLOY_USER}"
  local git_name="${GIT_USER_NAME:-Deploy Bot}"
  local git_email="${GIT_USER_EMAIL:-deploy@localhost}"
  
  # Install Git
  log_step "Installing Git"
  pkg_update
  pkg_install git
  
  log_substep "Git version: $(git --version | cut -d' ' -f3)"
  
  # Configure Git for deploy user
  log_step "Configuring Git for user: ${username}"
  
  sudo -u "$username" git config --global user.name "$git_name"
  sudo -u "$username" git config --global user.email "$git_email"
  sudo -u "$username" git config --global init.defaultBranch main
  sudo -u "$username" git config --global pull.rebase false
  
  # Useful aliases
  sudo -u "$username" git config --global alias.st status
  sudo -u "$username" git config --global alias.co checkout
  sudo -u "$username" git config --global alias.br branch
  sudo -u "$username" git config --global alias.ci commit
  sudo -u "$username" git config --global alias.lg "log --oneline --graph --decorate"
  
  log_substep "Git configured with:"
  log_substep "  user.name: $git_name"
  log_substep "  user.email: $git_email"
  
  log_module_end "$MODULE_NAME"
}
