#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: Ruby
# =============================================================================
# Install Ruby via rbenv
# =============================================================================

MODULE_NAME="ruby"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  detect_distro
  require_var DEPLOY_USER
  
  local ruby_version="${RUBY_VERSION:-3.3.0}"
  local install_bundler="${RUBY_BUNDLER:-true}"
  local username="${DEPLOY_USER}"
  local home_dir="/home/${username}"
  
  # Install build dependencies
  log_step "Installing Ruby build dependencies"
  pkg_update
  
  pkg_install \
    autoconf \
    bison \
    build-essential \
    libssl-dev \
    libyaml-dev \
    libreadline-dev \
    zlib1g-dev \
    libncurses5-dev \
    libffi-dev \
    libgdbm-dev \
    libgdbm-compat-dev \
    libdb-dev \
    uuid-dev
  
  # Install rbenv
  log_step "Installing rbenv for user: ${username}"
  
  local rbenv_dir="${home_dir}/.rbenv"
  
  if [[ -d "${rbenv_dir}" ]]; then
    log_substep "rbenv already installed, updating..."
    sudo -u "$username" git -C "${rbenv_dir}" pull --quiet
  else
    log_substep "Cloning rbenv..."
    sudo -u "$username" git clone --quiet https://github.com/rbenv/rbenv.git "${rbenv_dir}"
  fi
  
  # Install ruby-build plugin
  local ruby_build_dir="${rbenv_dir}/plugins/ruby-build"
  if [[ -d "${ruby_build_dir}" ]]; then
    log_substep "ruby-build already installed, updating..."
    sudo -u "$username" git -C "${ruby_build_dir}" pull --quiet
  else
    log_substep "Cloning ruby-build..."
    sudo -u "$username" git clone --quiet https://github.com/rbenv/ruby-build.git "${ruby_build_dir}"
  fi
  
  # Add rbenv to PATH
  local bashrc="${home_dir}/.bashrc"
  if ! grep -q "rbenv init" "$bashrc"; then
    log_substep "Adding rbenv to .bashrc"
    cat >> "$bashrc" << 'EOF'

# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - bash)"
EOF
  fi
  
  # Install Ruby
  log_step "Installing Ruby ${ruby_version}"
  
  if sudo -u "$username" "${rbenv_dir}/bin/rbenv" versions --bare | grep -q "^${ruby_version}$"; then
    log_substep "Ruby ${ruby_version} already installed"
  else
    log_substep "Building Ruby ${ruby_version} (this may take a while)..."
    sudo -u "$username" "${rbenv_dir}/bin/rbenv" install "$ruby_version"
  fi
  
  # Set global version
  log_substep "Setting global Ruby version to ${ruby_version}"
  sudo -u "$username" "${rbenv_dir}/bin/rbenv" global "$ruby_version"
  sudo -u "$username" "${rbenv_dir}/bin/rbenv" rehash
  
  log_substep "Ruby version: $(sudo -u "$username" "${rbenv_dir}/shims/ruby" --version)"
  
  # Install Bundler
  if is_true "$install_bundler"; then
    log_step "Installing Bundler"
    sudo -u "$username" "${rbenv_dir}/shims/gem" install bundler --no-document
    sudo -u "$username" "${rbenv_dir}/bin/rbenv" rehash
    log_substep "Bundler version: $(sudo -u "$username" "${rbenv_dir}/shims/bundle" --version)"
  fi
  
  log_module_end "$MODULE_NAME"
}
