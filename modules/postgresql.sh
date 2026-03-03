#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: PostgreSQL
# =============================================================================
# Install and configure PostgreSQL database
# =============================================================================

MODULE_NAME="postgresql"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  detect_distro
  
  local version="${POSTGRESQL_VERSION:-16}"
  
  # Install PostgreSQL
  log_step "Installing PostgreSQL ${version}"
  
  # Add PostgreSQL repository
  log_substep "Adding PostgreSQL repository"
  pkg_install curl ca-certificates gnupg
  
  ensure_dir /usr/share/postgresql-common/pgdg
  
  if [[ ! -f /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc ]]; then
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc
  fi
  
  echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${DISTRO_CODENAME}-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list
  
  pkg_update
  pkg_install "postgresql-${version}" "postgresql-contrib-${version}"
  
  log_substep "PostgreSQL installed"
  
  # Ensure running
  service_enable postgresql
  
  # Create databases if configured
  create_database_if_configured "staging"
  create_database_if_configured "production"
  
  log_module_end "$MODULE_NAME"
}

create_database_if_configured() {
  local env="$1"
  local env_upper="${env^^}"
  
  local db_name_var="POSTGRESQL_${env_upper}_DB"
  local db_user_var="POSTGRESQL_${env_upper}_USER"
  local db_pass_var="POSTGRESQL_${env_upper}_PASSWORD"
  
  local db_name="${!db_name_var:-}"
  local db_user="${!db_user_var:-}"
  local db_password="${!db_pass_var:-}"
  
  if [[ -z "$db_name" ]] || [[ -z "$db_user" ]]; then
    return 0
  fi
  
  log_step "Creating ${env} database"
  
  # Generate password if not provided
  if [[ -z "$db_password" ]]; then
    db_password=$(generate_password 24)
    log_warning "Generated password for ${db_user}: ${db_password}"
    log_warning "Save this password securely!"
  fi
  
  # Create user
  if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${db_user}'" | grep -q 1; then
    log_substep "User already exists: ${db_user}"
  else
    log_substep "Creating user: ${db_user}"
    sudo -u postgres psql -c "CREATE USER ${db_user} WITH PASSWORD '${db_password}';"
  fi
  
  # Create database
  if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" | grep -q 1; then
    log_substep "Database already exists: ${db_name}"
  else
    log_substep "Creating database: ${db_name}"
    sudo -u postgres psql -c "CREATE DATABASE ${db_name} OWNER ${db_user};"
  fi
  
  # Grant privileges
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};"
  
  log_info "  Database: ${db_name}"
  log_info "  User: ${db_user}"
  log_info "  URL: postgresql://${db_user}:${db_password}@localhost:5432/${db_name}"
}
