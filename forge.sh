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
#   ./forge.sh db create <env>    Create database for environment
#   ./forge.sh nginx-site <name> <type>  Generate Nginx server block
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
}

# Print usage
usage() {
  cat << EOF
${COLOR_BOLD}ServerForge v${FORGE_VERSION}${COLOR_RESET}

${COLOR_CYAN}Usage:${COLOR_RESET}
  ./forge.sh [-p <project>] <command> [options]

${COLOR_CYAN}Global Options:${COLOR_RESET}
  ${COLOR_GREEN}-p, --project${COLOR_RESET} <name>    Use project config (projects/<name>.sh)

${COLOR_CYAN}Commands:${COLOR_RESET}
  ${COLOR_GREEN}setup${COLOR_RESET}                    Run full setup on remote server
  ${COLOR_GREEN}run${COLOR_RESET} <module> [module...] Run specific module(s) on remote server
  ${COLOR_GREEN}local setup${COLOR_RESET}              Run full setup locally (on current machine)
  ${COLOR_GREEN}local run${COLOR_RESET} <module>       Run specific module(s) locally
  ${COLOR_GREEN}test${COLOR_RESET}                     Test SSH connection to remote server
  ${COLOR_GREEN}info${COLOR_RESET}                     Show remote server information
  ${COLOR_GREEN}db create${COLOR_RESET} <env>          Create database (staging|production)
  ${COLOR_GREEN}nginx-site${COLOR_RESET} <name> <type> Generate Nginx server block (rails|node|python)
  ${COLOR_GREEN}projects${COLOR_RESET}                 List available project configurations
  ${COLOR_GREEN}help${COLOR_RESET}                     Show this help message

${COLOR_CYAN}Modules:${COLOR_RESET}
  system, security, users, git, nginx, certbot,
  postgresql, redis, docker, nodejs, ruby, python

${COLOR_CYAN}Examples:${COLOR_RESET}
  ./forge.sh setup                      # Full remote setup (uses config.sh)
  ./forge.sh run nginx certbot          # Install Nginx and Certbot
  ./forge.sh -p kaalisi setup           # Setup using projects/kaalisi.sh
  ./forge.sh -p kaalisi run nginx       # Run module with project config
  ./forge.sh projects                   # List available projects
  ./forge.sh local run postgresql       # Install PostgreSQL locally
  ./forge.sh db create production       # Create production database
  ./forge.sh nginx-site myapp rails     # Generate Rails Nginx config

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
    local enabled_var="MODULE_${module^^}"
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
  local env="${1:-}"
  
  if [[ -z "$env" ]] || [[ ! "$env" =~ ^(staging|production)$ ]]; then
    die "Usage: ./forge.sh db create <staging|production>"
  fi
  
  log_header "ServerForge - Create ${env^} Database"
  
  local db_name db_user db_password
  
  if [[ "$env" == "staging" ]]; then
    db_name="${POSTGRESQL_STAGING_DB:-myapp_staging}"
    db_user="${POSTGRESQL_STAGING_USER:-myapp_staging}"
    db_password="${POSTGRESQL_STAGING_PASSWORD:-$(generate_password 24)}"
  else
    db_name="${POSTGRESQL_PRODUCTION_DB:-myapp_production}"
    db_user="${POSTGRESQL_PRODUCTION_USER:-myapp}"
    db_password="${POSTGRESQL_PRODUCTION_PASSWORD:-$(generate_password 24)}"
  fi
  
  log_info "Database: $db_name"
  log_info "User: $db_user"
  
  if has_var SERVER_IP; then
    ssh_exec "sudo -u postgres psql -c \"CREATE USER ${db_user} WITH PASSWORD '${db_password}';\" 2>/dev/null || true"
    ssh_exec "sudo -u postgres psql -c \"CREATE DATABASE ${db_name} OWNER ${db_user};\" 2>/dev/null || true"
    ssh_exec "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};\""
  else
    require_root
    sudo -u postgres psql -c "CREATE USER ${db_user} WITH PASSWORD '${db_password}';" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE DATABASE ${db_name} OWNER ${db_user};" 2>/dev/null || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};"
  fi
  
  log_success "Database created!"
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

# Generate Nginx site config
cmd_nginx_site() {
  local name="${1:-}"
  local type="${2:-}"
  
  if [[ -z "$name" ]] || [[ -z "$type" ]]; then
    die "Usage: ./forge.sh nginx-site <name> <type>"
  fi
  
  if [[ ! "$type" =~ ^(rails|node|python|static)$ ]]; then
    die "Invalid type. Use: rails, node, python, or static"
  fi
  
  local template="${FORGE_DIR}/templates/nginx/${type}.conf.template"
  local output="${FORGE_DIR}/generated/${name}.nginx.conf"
  
  if [[ ! -f "$template" ]]; then
    die "Template not found: $template"
  fi
  
  ensure_dir "${FORGE_DIR}/generated"
  
  # Set variables for template
  export APP_NAME="$name"
  export DOMAIN="${DOMAIN:-example.com}"
  export DOMAIN_ALIASES="${DOMAIN_ALIASES:-}"
  export APP_ROOT="${APP_ROOT:-/var/www/${name}/current/public}"
  export APP_UPSTREAM="${APP_UPSTREAM:-unix:/var/www/${name}/shared/tmp/sockets/puma.sock}"
  
  template_file "$template" "$output"
  
  log_success "Generated: $output"
  log_info ""
  log_info "To deploy:"
  log_info "  1. Copy to server: scp $output root@server:/etc/nginx/sites-available/${name}"
  log_info "  2. Enable site: ln -s /etc/nginx/sites-available/${name} /etc/nginx/sites-enabled/"
  log_info "  3. Test config: nginx -t"
  log_info "  4. Reload Nginx: systemctl reload nginx"
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
    nginx-site)
      load_config
      cmd_nginx_site "$@"
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
