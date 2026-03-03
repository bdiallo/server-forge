#!/usr/bin/env bash
# =============================================================================
# ServerForge - Main Entry Point
# =============================================================================
# Usage:
#   ./forge.sh setup              Run full setup on remote server
#   ./forge.sh run <module>       Run specific module(s) on remote server
#   ./forge.sh local setup        Run full setup locally
#   ./forge.sh local run <module> Run specific module(s) locally
#   ./forge.sh test               Test SSH connection
#   ./forge.sh info               Show remote server info
#   ./forge.sh db create -e <env> Create database for environment
#   ./forge.sh nginx-conf                Generate Nginx conf (from project config)
#   ./forge.sh nginx-conf --deploy      Generate + deploy to remote server
# =============================================================================
set -euo pipefail

FORGE_VERSION="1.0.0"
FORGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "${FORGE_DIR}/lib/colors.sh"
source "${FORGE_DIR}/lib/logging.sh"
source "${FORGE_DIR}/lib/distro.sh"
source "${FORGE_DIR}/lib/utils.sh"
source "${FORGE_DIR}/lib/remote.sh"

# Load configuration
load_config() {
  local config_file

  if [[ -n "${FORGE_PROJECT:-}" ]]; then
    config_file="${FORGE_DIR}/projects/${FORGE_PROJECT}.sh"
    if [[ ! -f "$config_file" ]]; then
      die "Project config not found: projects/${FORGE_PROJECT}.sh"
    fi
  else
    config_file="${FORGE_DIR}/config.sh"
    if [[ ! -f "$config_file" ]]; then
      die "Configuration file not found. Copy config.example.sh to config.sh"
    fi
  fi

  source "$config_file"

  # Resolve environment-specific variables (VAR_STAGING / VAR_PRODUCTION)
  # If FORGE_ENVIRONMENT is set, use the matching suffix.
  # If not set but suffixed variables exist, default to production.
  # Example: DOMAIN_PRODUCTION="api.kaalisi.com" → DOMAIN="api.kaalisi.com"
  local env_suffix
  if [[ -n "${FORGE_ENVIRONMENT:-}" ]]; then
    env_suffix="$(echo "${FORGE_ENVIRONMENT}" | tr '[:lower:]' '[:upper:]')"
  else
    env_suffix="PRODUCTION"
  fi
  for var in DOMAIN DOMAIN_ALIASES APP_UPSTREAM APP_ROOT; do
    local suffixed_var="${var}_${env_suffix}"
    if [[ -n "${!suffixed_var:-}" ]]; then
      export "$var"="${!suffixed_var}"
    fi
  done
}

# Print usage
usage() {
  cat << EOF
${COLOR_BOLD}ServerForge v${FORGE_VERSION}${COLOR_RESET}

${COLOR_CYAN}Usage:${COLOR_RESET}
  ./forge.sh [-p <project>] [-e <env>] <command> [options]

${COLOR_CYAN}Global Options:${COLOR_RESET}
  ${COLOR_GREEN}-p, --project${COLOR_RESET} <name>        Use project config (projects/<name>.sh)
  ${COLOR_GREEN}-e, --environment${COLOR_RESET} <env>     Target environment (staging|production)

${COLOR_CYAN}Commands:${COLOR_RESET}
  ${COLOR_GREEN}setup${COLOR_RESET}                        Run full setup on remote server
  ${COLOR_GREEN}run${COLOR_RESET} <module> [module...]     Run specific module(s) on remote server
  ${COLOR_GREEN}local setup${COLOR_RESET}                  Run full setup locally (on current machine)
  ${COLOR_GREEN}local run${COLOR_RESET} <module>           Run specific module(s) locally
  ${COLOR_GREEN}test${COLOR_RESET}                         Test SSH connection to remote server
  ${COLOR_GREEN}info${COLOR_RESET}                         Show remote server information
  ${COLOR_GREEN}db create${COLOR_RESET}                    Create database (requires -e)
  ${COLOR_GREEN}nginx-conf${COLOR_RESET}                   Generate Nginx conf from project config
  ${COLOR_GREEN}nginx-conf --deploy${COLOR_RESET}          Generate + upload + enable + reload on remote
  ${COLOR_GREEN}nginx-conf --http${COLOR_RESET}            Generate HTTP-only conf (for pre-SSL setup)
  ${COLOR_GREEN}nginx-conf --http --deploy${COLOR_RESET}   Deploy HTTP-only conf (before certbot)
  ${COLOR_GREEN}projects${COLOR_RESET}                     List available project configurations
  ${COLOR_GREEN}help${COLOR_RESET}                         Show this help message

${COLOR_CYAN}Modules:${COLOR_RESET}
  system, security, users, git, nginx, certbot,
  postgresql, redis, docker, nodejs, ruby, python

${COLOR_CYAN}Examples:${COLOR_RESET}
  ./forge.sh setup                      # Full remote setup (uses config.sh)
  ./forge.sh run nginx certbot          # Install Nginx and Certbot
  ./forge.sh -p kaalisi_api setup       # Setup using projects/kaalisi_api.sh
  ./forge.sh -p kaalisi_api run nginx   # Run module with project config
  ./forge.sh projects                   # List available projects
  ./forge.sh local run postgresql       # Install PostgreSQL locally
  ./forge.sh db create -e production     # Create production database
  ./forge.sh -p kaalisi_api db create -e staging    # Project + environment
  ./forge.sh -p kaalisi_api -e staging nginx-conf   # Generate Nginx conf locally
  ./forge.sh -p kaalisi_api -e staging nginx-conf --deploy  # Generate + deploy

EOF
}

# Run a module
run_module() {
  local module="$1"
  local module_file="${FORGE_DIR}/modules/${module}.sh"
  
  if [[ ! -f "$module_file" ]]; then
    die "Module not found: $module"
  fi
  
  source "$module_file"
  module_run
}

# Run all enabled modules
run_all_modules() {
  local modules=(
    "system"
    "security"
    "users"
    "git"
    "nginx"
    "certbot"
    "postgresql"
    "redis"
    "docker"
    "nodejs"
    "ruby"
    "python"
  )
  
  for module in "${modules[@]}"; do
    local enabled_var="MODULE_$(echo "$module" | tr '[:lower:]' '[:upper:]')"
    if is_true "${!enabled_var:-false}"; then
      run_module "$module"
    else
      log_info "Skipping disabled module: $module"
    fi
  done
}

# Local setup
cmd_local_setup() {
  log_header "ServerForge - Local Setup"
  require_root
  detect_distro
  
  log_info "Server IP: $(get_primary_ip)"
  log_info "Distribution: ${DISTRO_NAME}"
  log_info ""
  
  if ! confirm "Continue with local setup?"; then
    log_warning "Aborted."
    exit 0
  fi
  
  run_all_modules
  
  log_header "Setup Complete!"
  log_success "Server setup completed successfully."
}

# Local run specific modules
cmd_local_run() {
  local modules=("$@")
  
  if [[ ${#modules[@]} -eq 0 ]]; then
    die "No modules specified. Usage: ./forge.sh local run <module> [module...]"
  fi
  
  log_header "ServerForge - Running Modules"
  require_root
  detect_distro
  
  for module in "${modules[@]}"; do
    run_module "$module"
  done
  
  log_success "All modules completed successfully."
}

# Remote setup
cmd_setup() {
  log_header "ServerForge - Remote Setup"
  
  require_var SERVER_IP
  require_var SERVER_USER
  
  log_info "Target: ${SERVER_USER}@${SERVER_IP}"
  log_info "Domain: ${DOMAIN:-not set}"
  log_info ""
  
  if ! ssh_test; then
    die "Cannot connect to remote server"
  fi
  
  if ! confirm "Continue with remote setup?"; then
    log_warning "Aborted."
    exit 0
  fi
  
  remote_execute
}

# Remote run specific modules
cmd_run() {
  local modules=("$@")
  
  if [[ ${#modules[@]} -eq 0 ]]; then
    die "No modules specified. Usage: ./forge.sh run <module> [module...]"
  fi
  
  log_header "ServerForge - Running Remote Modules"
  
  require_var SERVER_IP
  require_var SERVER_USER
  
  if ! ssh_test; then
    die "Cannot connect to remote server"
  fi
  
  remote_execute "${modules[@]}"
}

# Test SSH connection
cmd_test() {
  load_config
  require_var SERVER_IP
  require_var SERVER_USER
  
  if ssh_test; then
    log_info ""
    log_info "Server information:"
    ssh_get_info
  fi
}

# Show server info
cmd_info() {
  load_config
  require_var SERVER_IP
  require_var SERVER_USER
  
  log_header "ServerForge - Server Info"
  
  if ! ssh_test; then
    die "Cannot connect to remote server"
  fi
  
  ssh_get_info
}

# Create database
cmd_db_create() {
  if [[ -z "${FORGE_ENVIRONMENT:-}" ]]; then
    die "Usage: ./forge.sh db create -e <staging|production>"
  fi

  local env="$FORGE_ENVIRONMENT"
  local env_upper
  env_upper="$(echo "$env" | tr '[:lower:]' '[:upper:]')"
  local env_capitalized
  env_capitalized="$(echo "$env" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"

  log_header "ServerForge - Create ${env_capitalized} Database"
  local var_db="POSTGRESQL_DB_${env_upper}"
  local var_user="POSTGRESQL_USER_${env_upper}"
  local var_password="POSTGRESQL_PASSWORD_${env_upper}"

  local db_name="${!var_db:-myapp_${env}}"
  local db_user="${!var_user:-myapp_${env}}"
  local db_password="${!var_password:-$(generate_password 24)}"
  
  log_info "Database: $db_name"
  log_info "User: $db_user"

  # Idempotent: check user/database existence before creating
  local check_user="SELECT 1 FROM pg_roles WHERE rolname='${db_user}'"
  local check_db="SELECT 1 FROM pg_database WHERE datname='${db_name}'"

  if has_var SERVER_IP; then
    require_sudo_access
    if ! ssh_sudo_exec "-u postgres psql -tAc \"${check_user}\"" | grep -q 1; then
      log_substep "Creating user: ${db_user}"
      ssh_sudo_exec "-u postgres psql -c \"CREATE USER ${db_user} WITH PASSWORD '${db_password}';\""
    else
      log_substep "User already exists: ${db_user}"
    fi
    if ! ssh_sudo_exec "-u postgres psql -tAc \"${check_db}\"" | grep -q 1; then
      log_substep "Creating database: ${db_name}"
      ssh_sudo_exec "-u postgres psql -c \"CREATE DATABASE ${db_name} OWNER ${db_user};\""
    else
      log_substep "Database already exists: ${db_name}"
    fi
    ssh_sudo_exec "-u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};\""
  else
    require_root
    if ! sudo -u postgres psql -tAc "${check_user}" | grep -q 1; then
      log_substep "Creating user: ${db_user}"
      sudo -u postgres psql -c "CREATE USER ${db_user} WITH PASSWORD '${db_password}';"
    else
      log_substep "User already exists: ${db_user}"
    fi
    if ! sudo -u postgres psql -tAc "${check_db}" | grep -q 1; then
      log_substep "Creating database: ${db_name}"
      sudo -u postgres psql -c "CREATE DATABASE ${db_name} OWNER ${db_user};"
    else
      log_substep "Database already exists: ${db_name}"
    fi
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};"
  fi

  log_success "Database ready!"
  log_info ""
  log_info "Connection details:"
  log_info "  Host: localhost"
  log_info "  Port: 5432"
  log_info "  Database: $db_name"
  log_info "  User: $db_user"
  log_info "  Password: $db_password"
  log_info ""
  log_info "  URL: postgresql://${db_user}:${db_password}@localhost:5432/${db_name}"
}

# Generate Nginx conf from project config
# Usage: ./forge.sh -p myapp -e staging nginx-conf [--http] [--deploy]
cmd_nginx_conf() {
  local deploy=false
  local http_only=false
  for arg in "$@"; do
    case "$arg" in
      --deploy) deploy=true ;;
      --http)   http_only=true ;;
    esac
  done

  local name="${APP_NAME:-}"
  local type="${APP_TYPE:-rails}"
  local domain="${DOMAIN:-}"

  if [[ -z "$name" ]]; then
    die "APP_NAME not set. Use -p <project> to load a project config."
  fi
  if [[ -z "$domain" ]]; then
    die "DOMAIN not set. Set DOMAIN or DOMAIN_<ENV> in your project config."
  fi

  if [[ ! "$type" =~ ^(rails|node|python|static)$ ]]; then
    die "Invalid APP_TYPE: $type. Use: rails, node, python, or static"
  fi

  local template
  if [[ "$http_only" == true ]]; then
    template="${FORGE_DIR}/templates/nginx/${type}-http.conf.template"
  else
    template="${FORGE_DIR}/templates/nginx/${type}.conf.template"
  fi
  if [[ ! -f "$template" ]]; then
    die "Template not found: $template"
  fi

  local conf_filename="${domain}.conf"

  ensure_dir "${FORGE_DIR}/generated"
  local output="${FORGE_DIR}/generated/${conf_filename}"

  # Set variables for template
  export APP_NAME
  export DOMAIN
  export DOMAIN_ALIASES="${DOMAIN_ALIASES:-}"
  export APP_ROOT="${APP_ROOT:-/var/www/${name}/current/public}"
  export APP_UPSTREAM="${APP_UPSTREAM:-unix:/var/www/${name}/shared/tmp/sockets/puma.sock}"
  export NGINX_CLIENT_MAX_BODY_SIZE="${NGINX_CLIENT_MAX_BODY_SIZE:-100M}"

  log_step "Generating Nginx conf: ${conf_filename}"
  log_substep "Domain: ${DOMAIN}"
  log_substep "Upstream: ${APP_UPSTREAM}"
  log_substep "Root: ${APP_ROOT}"

  template_file "$template" "$output"
  log_success "Generated: $output"

  if [[ "$deploy" == false ]]; then
    log_info ""
    log_info "To deploy manually:"
    log_info "  scp $output ${SERVER_USER:-root}@${SERVER_IP:-server}:/etc/nginx/sites-available/${conf_filename}"
    log_info "  # Then enable, test, and reload on server"
    log_info ""
    log_info "Or deploy automatically:"
    log_info "  ./forge.sh -p ${FORGE_PROJECT:-myapp} -e ${FORGE_ENVIRONMENT:-production} nginx-conf --deploy"
    return 0
  fi

  # --deploy: upload, enable, test, reload
  require_var SERVER_IP
  require_var SERVER_USER

  if ! ssh_test; then
    die "Cannot connect to remote server"
  fi

  local remote_available="/etc/nginx/sites-available/${conf_filename}"
  local remote_enabled="/etc/nginx/sites-enabled/${conf_filename}"

  # Upload conf file
  log_step "Deploying to ${SERVER_USER}@${SERVER_IP}"

  local scp_key_opt="" scp_port_opt=""
  if [[ -n "${SERVER_SSH_KEY:-}" ]]; then
    scp_key_opt="-i ${SERVER_SSH_KEY}"
  fi
  if [[ -n "${SERVER_SSH_PORT:-}" ]] && [[ "${SERVER_SSH_PORT}" != "22" ]]; then
    scp_port_opt="-P ${SERVER_SSH_PORT}"
  fi

  scp ${SERVER_SSH_OPTIONS:-} ${scp_key_opt} ${scp_port_opt} \
    "$output" "${SERVER_USER}@${SERVER_IP}:/tmp/${conf_filename}"
  log_substep "Uploaded to remote"

  # Move to sites-available, symlink to sites-enabled, test, reload
  require_sudo_access

  local remote_script
  remote_script=$(cat <<REMOTEOF
mv /tmp/${conf_filename} ${remote_available}
ln -sf ${remote_available} ${remote_enabled}
echo '==> Testing nginx config...'
if nginx -t 2>&1; then
  echo '==> Reloading nginx...'
  systemctl reload nginx
  echo '==> Done!'
else
  echo '==> nginx -t FAILED — rolling back'
  rm -f ${remote_enabled}
  exit 1
fi
REMOTEOF
  )

  printf '%s\n' "${FORGE_SUDO_PASS}" \
    | $(_ssh_cmd) "sudo -S -p '' bash -c $(printf '%q' "$remote_script")"

  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    log_success "Deployed and active: ${conf_filename}"
    log_info "  Available: ${remote_available}"
    log_info "  Enabled:   ${remote_enabled}"
  else
    die "Deployment failed — site was not enabled. Check nginx error above."
  fi
}

# List available projects
cmd_projects() {
  local projects_dir="${FORGE_DIR}/projects"

  if [[ ! -d "$projects_dir" ]] || ! ls "$projects_dir"/*.sh &>/dev/null; then
    log_info "No project configurations found."
    log_info ""
    log_info "To create one:"
    log_info "  cp config.example.sh projects/myproject.sh"
    log_info "  nano projects/myproject.sh"
    return
  fi

  log_info "Available projects:"
  log_info ""
  for f in "$projects_dir"/*.sh; do
    local name
    name="$(basename "$f" .sh)"
    log_info "  ${COLOR_GREEN}${name}${COLOR_RESET}  →  projects/${name}.sh"
  done
  log_info ""
  log_info "Usage: ./forge.sh -p <project> <command>"
}

# Main
main() {
  # Extract -p/--project flag from any position in args
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--project)
        if [[ -z "${2:-}" ]]; then
          die "Option $1 requires a project name"
        fi
        if [[ ! "$2" =~ ^[a-zA-Z0-9_-]+$ ]]; then
          die "Invalid project name: $2 (only alphanumeric, hyphens, underscores)"
        fi
        FORGE_PROJECT="$2"
        shift 2
        ;;
      -e|--environment)
        if [[ -z "${2:-}" ]]; then
          die "Option $1 requires an environment name"
        fi
        if [[ ! "$2" =~ ^(staging|production)$ ]]; then
          die "Invalid environment: $2 (staging|production)"
        fi
        FORGE_ENVIRONMENT="$2"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done
  set -- "${args[@]+"${args[@]}"}"

  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    setup)
      load_config
      cmd_setup
      ;;
    run)
      load_config
      cmd_run "$@"
      ;;
    local)
      load_config
      local subcmd="${1:-}"
      shift || true
      case "$subcmd" in
        setup)
          cmd_local_setup
          ;;
        run)
          cmd_local_run "$@"
          ;;
        *)
          die "Unknown local command: $subcmd. Use: setup, run"
          ;;
      esac
      ;;
    test)
      cmd_test
      ;;
    info)
      cmd_info
      ;;
    db)
      load_config
      local subcmd="${1:-}"
      shift || true
      case "$subcmd" in
        create)
          cmd_db_create "$@"
          ;;
        *)
          die "Unknown db command: $subcmd. Use: create"
          ;;
      esac
      ;;
    nginx-conf)
      load_config
      cmd_nginx_conf "$@"
      ;;
    projects)
      cmd_projects
      ;;
    help|--help|-h)
      usage
      ;;
    version|--version|-v)
      echo "ServerForge v${FORGE_VERSION}"
      ;;
    *)
      log_error "Unknown command: $cmd"
      usage
      exit 1
      ;;
  esac
}

main "$@"
