#!/usr/bin/env bash
# =============================================================================
# ServerForge - Remote Execution Helpers
# =============================================================================

# Source logging if not already loaded
[[ -z "$LOG_PREFIX" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Build SSH command
_ssh_cmd() {
  local key_opt=""
  local port_opt=""
  
  if [[ -n "${SERVER_SSH_KEY:-}" ]]; then
    key_opt="-i ${SERVER_SSH_KEY}"
  fi
  
  if [[ -n "${SERVER_SSH_PORT:-}" ]] && [[ "${SERVER_SSH_PORT}" != "22" ]]; then
    port_opt="-p ${SERVER_SSH_PORT}"
  fi
  
  echo "ssh ${SERVER_SSH_OPTIONS:-} ${key_opt} ${port_opt} ${SERVER_USER}@${SERVER_IP}"
}

# Test SSH connection
ssh_test() {
  log_step "Testing SSH connection to ${SERVER_USER}@${SERVER_IP}"
  
  if $(_ssh_cmd) "echo 'Connection successful'" &>/dev/null; then
    log_success "SSH connection established"
    return 0
  else
    log_error "Cannot connect to ${SERVER_USER}@${SERVER_IP}"
    return 1
  fi
}

# Execute a command on the remote server
ssh_exec() {
  local cmd="$1"
  $(_ssh_cmd) "$cmd"
}

# Execute a script on the remote server
ssh_exec_script() {
  local script="$1"
  $(_ssh_cmd) 'bash -s' < "$script"
}

# Copy a file to the remote server
ssh_copy() {
  local src="$1"
  local dest="$2"
  local key_opt=""
  local port_opt=""
  
  if [[ -n "${SERVER_SSH_KEY:-}" ]]; then
    key_opt="-i ${SERVER_SSH_KEY}"
  fi
  
  if [[ -n "${SERVER_SSH_PORT:-}" ]] && [[ "${SERVER_SSH_PORT}" != "22" ]]; then
    port_opt="-P ${SERVER_SSH_PORT}"
  fi
  
  scp ${SERVER_SSH_OPTIONS:-} ${key_opt} ${port_opt} "$src" "${SERVER_USER}@${SERVER_IP}:${dest}"
}

# Sync a directory to the remote server
ssh_sync() {
  local src="$1"
  local dest="$2"
  local key_opt=""
  local port_opt=""
  
  if [[ -n "${SERVER_SSH_KEY:-}" ]]; then
    key_opt="-e 'ssh -i ${SERVER_SSH_KEY}'"
  fi
  
  if [[ -n "${SERVER_SSH_PORT:-}" ]] && [[ "${SERVER_SSH_PORT}" != "22" ]]; then
    port_opt="--rsh='ssh -p ${SERVER_SSH_PORT}'"
  fi
  
  rsync -avz --progress ${key_opt} ${port_opt} "$src" "${SERVER_USER}@${SERVER_IP}:${dest}"
}

# Get remote server info
ssh_get_info() {
  log_step "Getting remote server information"
  
  local info
  info=$($(_ssh_cmd) 'cat /etc/os-release && echo "---" && uname -a && echo "---" && free -h | head -2 && echo "---" && df -h / | tail -1')
  
  echo "$info"
}

# Execute ServerForge on the remote server
# This bundles all necessary files and runs them remotely
remote_execute() {
  local modules=("$@")
  local forge_dir=$(dirname "$(dirname "${BASH_SOURCE[0]}")")
  local tmp_dir=$(mktemp -d)
  local bundle="${tmp_dir}/serverforge_bundle.sh"
  
  log_step "Preparing remote execution bundle"
  
  # Create self-extracting bundle
  cat > "$bundle" << 'BUNDLE_HEADER'
#!/usr/bin/env bash
set -euo pipefail

# Extract embedded files
EXTRACT_DIR=$(mktemp -d)
cd "$EXTRACT_DIR"

# Extract base64-encoded tar archive
sed -n '/^__ARCHIVE__$/,$ p' "$0" | tail -n +2 | base64 -d | tar xzf -

# Source config passed via environment
# Run the requested modules
cd "$(ls -d */ | head -1)"
BUNDLE_HEADER
  
  # Add module execution (pass -p flag if set)
  local project_flag=""
  if [[ -n "${FORGE_PROJECT:-}" ]]; then
    project_flag="-p ${FORGE_PROJECT}"
  fi

  if [[ ${#modules[@]} -eq 0 ]]; then
    echo "./forge.sh ${project_flag} local setup" >> "$bundle"
  else
    echo "./forge.sh ${project_flag} local run ${modules[*]}" >> "$bundle"
  fi
  
  # Add cleanup
  cat >> "$bundle" << 'BUNDLE_FOOTER'

# Cleanup
cd /
rm -rf "$EXTRACT_DIR"
exit 0

__ARCHIVE__
BUNDLE_FOOTER
  
  # Create tarball of serverforge directory
  log_substep "Creating bundle archive..."
  tar czf - -C "$forge_dir/.." "$(basename "$forge_dir")" | base64 >> "$bundle"
  
  # Make bundle executable
  chmod +x "$bundle"
  
  # Execute on remote server
  log_step "Executing on remote server"
  
  # Export config variables and run
  (
    # Export all config variables
    export DOMAIN DOMAIN_ALIASES TIMEZONE
    export DEPLOY_USER DEPLOY_USER_SSH_KEY DEPLOY_USER_SUDO DEPLOY_USER_HOME
    export FIREWALL_ENABLED FIREWALL_ALLOWED_PORTS FAIL2BAN_ENABLED SSH_HARDENING SSH_PORT
    export GIT_USER_NAME GIT_USER_EMAIL
    export NGINX_CLIENT_MAX_BODY_SIZE NGINX_WORKER_PROCESSES NGINX_WORKER_CONNECTIONS
    export CERTBOT_EMAIL CERTBOT_STAGING CERTBOT_OBTAIN_CERT
    export POSTGRESQL_VERSION POSTGRESQL_STAGING_DB POSTGRESQL_STAGING_USER POSTGRESQL_STAGING_PASSWORD
    export POSTGRESQL_PRODUCTION_DB POSTGRESQL_PRODUCTION_USER POSTGRESQL_PRODUCTION_PASSWORD
    export REDIS_MAXMEMORY REDIS_MAXMEMORY_POLICY REDIS_BIND REDIS_PASSWORD
    export DOCKER_COMPOSE DOCKER_USER_ACCESS
    export NODEJS_VERSION NODEJS_YARN
    export RUBY_VERSION RUBY_BUNDLER
    export PYTHON_VERSION PYTHON_TOOLS
    export APP_NAME APP_TYPE APP_UPSTREAM APP_ROOT
    export MODULE_SYSTEM MODULE_SECURITY MODULE_USERS MODULE_GIT MODULE_NGINX
    export MODULE_CERTBOT MODULE_POSTGRESQL MODULE_REDIS MODULE_DOCKER
    export MODULE_NODEJS MODULE_RUBY MODULE_PYTHON
    
    $(_ssh_cmd) 'bash -s' < "$bundle"
  )
  
  # Cleanup local temp files
  rm -rf "$tmp_dir"
  
  log_success "Remote execution completed"
}

export -f _ssh_cmd ssh_test ssh_exec ssh_exec_script ssh_copy ssh_sync
export -f ssh_get_info remote_execute
