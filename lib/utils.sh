#!/usr/bin/env bash
# =============================================================================
# ServerForge - Utility Functions
# =============================================================================

# Source logging if not already loaded
[[ -z "$LOG_PREFIX" ]] && source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# -----------------------------------------------------------------------------
# Service Management
# -----------------------------------------------------------------------------

# Enable and start a service
service_enable() {
  local service="$1"
  log_substep "Enabling service: $service"
  systemctl enable "$service" --quiet 2>/dev/null || true
  systemctl start "$service" 2>/dev/null || true
}

# Restart a service
service_restart() {
  local service="$1"
  log_substep "Restarting service: $service"
  systemctl restart "$service"
}

# Reload a service
service_reload() {
  local service="$1"
  log_substep "Reloading service: $service"
  systemctl reload "$service" 2>/dev/null || systemctl restart "$service"
}

# Check if a service is running
service_is_running() {
  systemctl is-active --quiet "$1"
}

# Check if a service exists
service_exists() {
  systemctl list-unit-files "$1.service" &>/dev/null
}

# -----------------------------------------------------------------------------
# User Management
# -----------------------------------------------------------------------------

# Check if a user exists
user_exists() {
  id "$1" &>/dev/null
}

# Create a user
create_user() {
  local username="$1"
  local home_dir="${2:-/home/$username}"

  if user_exists "$username"; then
    log_substep "User already exists: $username"
    return 0
  fi

  log_substep "Creating user: $username"
  useradd -m -d "$home_dir" -s /bin/bash "$username"
}

# Add user to group
add_user_to_group() {
  local username="$1"
  local group="$2"
  log_substep "Adding $username to group: $group"
  usermod -aG "$group" "$username"
}

# -----------------------------------------------------------------------------
# File Operations
# -----------------------------------------------------------------------------

# Backup a file before modifying
backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local backup="${file}.backup.$(date +%Y%m%d%H%M%S)"
    log_substep "Backing up: $file"
    cp "$file" "$backup"
  fi
}

# Create directory if it doesn't exist
ensure_dir() {
  local dir="$1"
  local owner="${2:-}"
  
  if [[ ! -d "$dir" ]]; then
    log_substep "Creating directory: $dir"
    mkdir -p "$dir"
  fi

  if [[ -n "$owner" ]]; then
    chown "$owner:$owner" "$dir"
  fi
}

# Template a file (replace {{VAR}} with $VAR value)
template_file() {
  local template="$1"
  local output="$2"
  
  if [[ ! -f "$template" ]]; then
    die "Template not found: $template"
  fi

  log_substep "Generating: $output"
  
  local content
  content=$(cat "$template")
  
  # Replace all {{VAR}} patterns with environment variable values
  while [[ "$content" =~ \{\{([A-Z_][A-Z0-9_]*)\}\} ]]; do
    local var_name="${BASH_REMATCH[1]}"
    local var_value="${!var_name:-}"
    content="${content//\{\{$var_name\}\}/$var_value}"
  done
  
  echo "$content" > "$output"
}

# Append to file if line doesn't exist
append_if_missing() {
  local file="$1"
  local line="$2"
  
  if ! grep -qF "$line" "$file" 2>/dev/null; then
    echo "$line" >> "$file"
  fi
}

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

# Check if running as root
require_root() {
  if [[ $EUID -ne 0 ]]; then
    die "This script must be run as root"
  fi
}

# Check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Require a command to exist
require_command() {
  local cmd="$1"
  if ! command_exists "$cmd"; then
    die "Required command not found: $cmd"
  fi
}

# Check if a variable is set
require_var() {
  local var_name="$1"
  local var_value="${!var_name:-}"
  if [[ -z "$var_value" ]]; then
    die "Required variable not set: $var_name"
  fi
}

# Check if a variable is set (non-fatal)
has_var() {
  local var_name="$1"
  local var_value="${!var_name:-}"
  [[ -n "$var_value" ]]
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

# Get the primary IP address
get_primary_ip() {
  hostname -I 2>/dev/null | awk '{print $1}' || ip route get 1 | awk '{print $7; exit}'
}

# Check if a port is in use
port_in_use() {
  local port="$1"
  ss -tuln 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "
}

# Wait for a port to be available
wait_for_port() {
  local port="$1"
  local timeout="${2:-30}"
  local count=0
  
  while ! port_in_use "$port" && [[ $count -lt $timeout ]]; do
    sleep 1
    ((count++))
  done
  
  port_in_use "$port"
}

# -----------------------------------------------------------------------------
# Misc
# -----------------------------------------------------------------------------

# Generate a random password
generate_password() {
  local length="${1:-32}"
  openssl rand -base64 48 | tr -d '/+=' | head -c "$length"
}

# Get current timestamp
timestamp() {
  date +%Y%m%d%H%M%S
}

# Check if value is true
is_true() {
  local val="${1:-}"
  [[ "$val" == "true" ]] || [[ "$val" == "1" ]] || [[ "$val" == "yes" ]]
}

# Check if value is false
is_false() {
  local val="${1:-}"
  [[ "$val" == "false" ]] || [[ "$val" == "0" ]] || [[ "$val" == "no" ]] || [[ -z "$val" ]]
}

export -f service_enable service_restart service_reload service_is_running service_exists
export -f user_exists create_user add_user_to_group
export -f backup_file ensure_dir template_file append_if_missing
export -f require_root command_exists require_command require_var has_var
export -f get_primary_ip port_in_use wait_for_port
export -f generate_password timestamp is_true is_false
