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

# Prompt for sudo password once (skip if connecting as root)
require_sudo_access() {
  if [[ "${SERVER_USER:-root}" == "root" ]] || [[ -n "${FORGE_SUDO_PASS:-}" ]]; then
    return 0
  fi
  read -rsp "[sudo] password for ${SERVER_USER}@${SERVER_IP}: " FORGE_SUDO_PASS
  echo ""
}

# Execute a sudo command on the remote server
# Pipes cached password via stdin when not connecting as root
ssh_sudo_exec() {
  local cmd="$1"
  if [[ "${SERVER_USER:-root}" == "root" ]]; then
    $(_ssh_cmd) "$cmd"
  else
    printf '%s\n' "${FORGE_SUDO_PASS}" | $(_ssh_cmd) "sudo -S -p '' ${cmd}"
  fi
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
  
  # Add module execution (pass global flags if set)
  local global_flags=""
  if [[ -n "${FORGE_PROJECT:-}" ]]; then
    global_flags="${global_flags} -p ${FORGE_PROJECT}"
  fi
  if [[ -n "${FORGE_ENVIRONMENT:-}" ]]; then
    global_flags="${global_flags} -e ${FORGE_ENVIRONMENT}"
  fi

  if [[ ${#modules[@]} -eq 0 ]]; then
    echo "./forge.sh${global_flags} local setup" >> "$bundle"
  else
    echo "./forge.sh${global_flags} local run ${modules[*]}" >> "$bundle"
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
  
  # Copy bundle to remote server, then execute it
  log_step "Executing on remote server"

  local remote_bundle="/tmp/serverforge_bundle_$$.sh"

  # Upload bundle via scp
  local scp_key_opt="" scp_port_opt=""
  if [[ -n "${SERVER_SSH_KEY:-}" ]]; then
    scp_key_opt="-i ${SERVER_SSH_KEY}"
  fi
  if [[ -n "${SERVER_SSH_PORT:-}" ]] && [[ "${SERVER_SSH_PORT}" != "22" ]]; then
    scp_port_opt="-P ${SERVER_SSH_PORT}"
  fi
  scp ${SERVER_SSH_OPTIONS:-} ${scp_key_opt} ${scp_port_opt} "$bundle" "${SERVER_USER}@${SERVER_IP}:${remote_bundle}"

  if [[ "${SERVER_USER}" == "root" ]]; then
    $(_ssh_cmd) "bash ${remote_bundle}; rm -f ${remote_bundle}"
  else
    require_sudo_access
    printf '%s\n' "${FORGE_SUDO_PASS}" \
      | $(_ssh_cmd) "sudo -S -p '' bash ${remote_bundle}; rm -f ${remote_bundle}"
  fi

  # Cleanup local temp files
  rm -rf "$tmp_dir"

  log_success "Remote execution completed"
}

export -f _ssh_cmd ssh_test ssh_exec ssh_sudo_exec ssh_exec_script ssh_copy ssh_sync
export -f ssh_get_info remote_execute require_sudo_access
