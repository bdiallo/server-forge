#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: Docker
# =============================================================================
# Install Docker and Docker Compose
# =============================================================================

MODULE_NAME="docker"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  detect_distro
  
  local install_compose="${DOCKER_COMPOSE:-true}"
  local user_access="${DOCKER_USER_ACCESS:-true}"
  local username="${DEPLOY_USER:-}"
  
  # Install Docker
  log_step "Installing Docker"
  
  # Remove old versions
  log_substep "Removing old Docker versions"
  pkg_remove docker docker-engine docker.io containerd runc 2>/dev/null || true
  
  # Add Docker repository
  log_substep "Adding Docker repository"
  pkg_install ca-certificates curl gnupg
  
  ensure_dir /etc/apt/keyrings
  
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL "https://download.docker.com/linux/${DISTRO_ID}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO_ID} ${DISTRO_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  
  pkg_update
  pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  
  log_substep "Docker version: $(docker --version | cut -d' ' -f3 | tr -d ',')"
  
  # Install Docker Compose
  if is_true "$install_compose"; then
    log_step "Installing Docker Compose"
    pkg_install docker-compose-plugin
    log_substep "Docker Compose version: $(docker compose version | cut -d' ' -f4)"
  fi
  
  # Start Docker
  service_enable docker
  
  # Add deploy user to docker group
  if is_true "$user_access" && [[ -n "$username" ]]; then
    log_step "Adding ${username} to docker group"
    add_user_to_group "$username" "docker"
    log_info "Note: User needs to log out and back in for group changes to take effect"
  fi
  
  # Test Docker
  log_step "Testing Docker"
  
  if docker run --rm hello-world &>/dev/null; then
    log_success "Docker is working correctly"
  else
    log_warning "Docker test failed"
  fi
  
  log_module_end "$MODULE_NAME"
}
