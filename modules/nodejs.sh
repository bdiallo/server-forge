#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: Node.js
# =============================================================================
# Install Node.js via NodeSource repository
# =============================================================================

MODULE_NAME="nodejs"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  detect_distro
  require_var DEPLOY_USER
  
  local version="${NODEJS_VERSION:-20}"
  local install_yarn="${NODEJS_YARN:-true}"
  local username="${DEPLOY_USER}"
  
  # Install Node.js
  log_step "Installing Node.js ${version}.x"
  
  # Add NodeSource repository
  log_substep "Adding NodeSource repository"
  pkg_install curl ca-certificates gnupg
  
  ensure_dir /usr/share/keyrings
  
  if [[ ! -f /usr/share/keyrings/nodesource.gpg ]]; then
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
  fi
  
  echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${version}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  
  pkg_update
  pkg_install nodejs
  
  log_substep "Node.js version: $(node --version)"
  log_substep "npm version: $(npm --version)"
  
  # Install Yarn
  if is_true "$install_yarn"; then
    log_step "Installing Yarn"
    corepack enable
    corepack prepare yarn@stable --activate
    log_substep "Yarn version: $(yarn --version)"
  fi
  
  # Configure npm for deploy user
  log_step "Configuring npm for user: ${username}"
  
  local npm_dir="/home/${username}/.npm-global"
  ensure_dir "$npm_dir" "$username"
  
  sudo -u "$username" npm config set prefix "$npm_dir"
  
  # Add to PATH
  local bashrc="/home/${username}/.bashrc"
  if ! grep -q "NPM_GLOBAL" "$bashrc"; then
    cat >> "$bashrc" << 'EOF'

# npm global packages
export NPM_GLOBAL="$HOME/.npm-global"
export PATH="$NPM_GLOBAL/bin:$PATH"
EOF
  fi
  
  log_substep "Global npm packages will be installed to: $npm_dir"
  
  log_module_end "$MODULE_NAME"
}
