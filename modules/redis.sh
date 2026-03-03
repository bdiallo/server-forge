#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: Redis
# =============================================================================
# Install and configure Redis
# =============================================================================

MODULE_NAME="redis"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  detect_distro
  
  local maxmemory="${REDIS_MAXMEMORY:-256mb}"
  local maxmemory_policy="${REDIS_MAXMEMORY_POLICY:-allkeys-lru}"
  local bind_address="${REDIS_BIND:-127.0.0.1}"
  local password="${REDIS_PASSWORD:-}"
  
  # Install Redis
  log_step "Installing Redis"
  pkg_update
  pkg_install redis-server
  
  log_substep "Redis version: $(redis-server --version | cut -d' ' -f3 | cut -d'=' -f2)"
  
  # Configure Redis
  log_step "Configuring Redis"
  
  local config="/etc/redis/redis.conf"
  backup_file "$config"
  
  # Apply configuration
  log_substep "Setting bind address: ${bind_address}"
  sed -i "s/^bind .*/bind ${bind_address}/" "$config"
  
  log_substep "Setting maxmemory: ${maxmemory}"
  if grep -q "^maxmemory " "$config"; then
    sed -i "s/^maxmemory .*/maxmemory ${maxmemory}/" "$config"
  else
    echo "maxmemory ${maxmemory}" >> "$config"
  fi
  
  log_substep "Setting maxmemory-policy: ${maxmemory_policy}"
  if grep -q "^maxmemory-policy " "$config"; then
    sed -i "s/^maxmemory-policy .*/maxmemory-policy ${maxmemory_policy}/" "$config"
  else
    echo "maxmemory-policy ${maxmemory_policy}" >> "$config"
  fi
  
  # Set password if provided
  if [[ -n "$password" ]]; then
    log_substep "Setting password"
    if grep -q "^requirepass " "$config"; then
      sed -i "s/^requirepass .*/requirepass ${password}/" "$config"
    else
      echo "requirepass ${password}" >> "$config"
    fi
  fi
  
  # Enable supervised systemd
  if grep -q "^supervised " "$config"; then
    sed -i "s/^supervised .*/supervised systemd/" "$config"
  else
    echo "supervised systemd" >> "$config"
  fi
  
  # Restart Redis
  service_restart redis-server
  service_enable redis-server
  
  # Test connection
  log_step "Testing Redis connection"
  
  local ping_cmd="redis-cli"
  [[ -n "$password" ]] && ping_cmd+=" -a $password"
  ping_cmd+=" ping"
  
  if $ping_cmd 2>/dev/null | grep -q "PONG"; then
    log_success "Redis is responding"
  else
    log_error "Redis is not responding"
  fi
  
  # Output connection info
  log_info "  Host: ${bind_address}"
  log_info "  Port: 6379"
  if [[ -n "$password" ]]; then
    log_info "  URL: redis://:${password}@${bind_address}:6379"
  else
    log_info "  URL: redis://${bind_address}:6379"
  fi
  
  log_module_end "$MODULE_NAME"
}
