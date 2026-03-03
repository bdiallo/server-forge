#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: Python
# =============================================================================
# Install Python via pyenv
# =============================================================================

MODULE_NAME="python"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  detect_distro
  require_var DEPLOY_USER
  
  local python_version="${PYTHON_VERSION:-3.12.0}"
  local install_tools="${PYTHON_TOOLS:-true}"
  local username="${DEPLOY_USER}"
  local home_dir="/home/${username}"
  
  # Install build dependencies
  log_step "Installing Python build dependencies"
  pkg_update
  
  pkg_install \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    curl \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev
  
  # Install pyenv
  log_step "Installing pyenv for user: ${username}"
  
  local pyenv_dir="${home_dir}/.pyenv"
  
  if [[ -d "${pyenv_dir}" ]]; then
    log_substep "pyenv already installed, updating..."
    sudo -u "$username" git -C "${pyenv_dir}" pull --quiet
  else
    log_substep "Cloning pyenv..."
    sudo -u "$username" git clone --quiet https://github.com/pyenv/pyenv.git "${pyenv_dir}"
  fi
  
  # Install pyenv-virtualenv plugin
  local virtualenv_dir="${pyenv_dir}/plugins/pyenv-virtualenv"
  if [[ -d "${virtualenv_dir}" ]]; then
    log_substep "pyenv-virtualenv already installed, updating..."
    sudo -u "$username" git -C "${virtualenv_dir}" pull --quiet
  else
    log_substep "Cloning pyenv-virtualenv..."
    sudo -u "$username" git clone --quiet https://github.com/pyenv/pyenv-virtualenv.git "${virtualenv_dir}"
  fi
  
  # Add pyenv to PATH
  local bashrc="${home_dir}/.bashrc"
  if ! grep -q "pyenv init" "$bashrc"; then
    log_substep "Adding pyenv to .bashrc"
    cat >> "$bashrc" << 'EOF'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF
  fi
  
  # Install Python
  log_step "Installing Python ${python_version}"
  
  if sudo -u "$username" "${pyenv_dir}/bin/pyenv" versions --bare | grep -q "^${python_version}$"; then
    log_substep "Python ${python_version} already installed"
  else
    log_substep "Building Python ${python_version} (this may take a while)..."
    sudo -u "$username" "${pyenv_dir}/bin/pyenv" install "$python_version"
  fi
  
  # Set global version
  log_substep "Setting global Python version to ${python_version}"
  sudo -u "$username" "${pyenv_dir}/bin/pyenv" global "$python_version"
  sudo -u "$username" "${pyenv_dir}/bin/pyenv" rehash
  
  log_substep "Python version: $(sudo -u "$username" "${pyenv_dir}/shims/python" --version)"
  
  # Install common tools
  if is_true "$install_tools"; then
    log_step "Installing Python tools"
    sudo -u "$username" "${pyenv_dir}/shims/pip" install --upgrade pip --quiet
    sudo -u "$username" "${pyenv_dir}/shims/pip" install --quiet virtualenv pipenv
    log_substep "Installed: pip, virtualenv, pipenv"
  fi
  
  log_module_end "$MODULE_NAME"
}
