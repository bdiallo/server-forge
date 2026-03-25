#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: Nginx
# =============================================================================
# Install and configure Nginx web server
# =============================================================================

MODULE_NAME="nginx"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  detect_distro
  
  local max_body_size="${NGINX_CLIENT_MAX_BODY_SIZE:-100M}"
  local worker_processes="${NGINX_WORKER_PROCESSES:-auto}"
  local worker_connections="${NGINX_WORKER_CONNECTIONS:-1024}"
  
  # Install Nginx
  log_step "Installing Nginx"
  pkg_update
  pkg_install nginx
  
  log_substep "Nginx version: $(nginx -v 2>&1 | cut -d'/' -f2)"
  
  # Configure Nginx
  log_step "Configuring Nginx"
  backup_file /etc/nginx/nginx.conf
  
  cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes ${worker_processes};
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections ${worker_connections};
    multi_accept on;
    use epoll;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size ${max_body_size};

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

    # Virtual Hosts
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

  # Remove default site
  rm -f /etc/nginx/sites-enabled/default
  
  # Create directories
  ensure_dir /etc/nginx/sites-available
  ensure_dir /etc/nginx/sites-enabled
  ensure_dir /etc/nginx/snippets
  
  # Create SSL params snippet
  log_step "Creating Nginx snippets"
  
  cat > /etc/nginx/snippets/ssl-params.conf << 'EOF'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
EOF

  # Create proxy params snippet
  cat > /etc/nginx/snippets/proxy-params.conf << 'EOF'
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_cache_bypass $http_upgrade;
proxy_read_timeout 90;
proxy_connect_timeout 90;
proxy_send_timeout 90;
EOF

  # Generate site config from template if APP_NAME, APP_TYPE, and DOMAIN are set
  if [[ -n "${APP_NAME:-}" ]] && [[ -n "${APP_TYPE:-}" ]] && [[ -n "${DOMAIN:-}" ]]; then
    local template="${FORGE_DIR}/templates/nginx/${APP_TYPE}.conf.template"
    if [[ -f "$template" ]]; then
      local conf_filename="${DOMAIN}.conf"
      log_step "Generating nginx conf: ${conf_filename}"

      export APP_NAME
      export DOMAIN
      export DOMAIN_ALIASES="${DOMAIN_ALIASES:-}"
      export APP_ROOT="${APP_ROOT:-/var/www/${APP_NAME}/current/public}"
      export APP_UPSTREAM="${APP_UPSTREAM:-unix:/var/www/${APP_NAME}/shared/tmp/sockets/puma.sock}"
      export NGINX_CLIENT_MAX_BODY_SIZE="${NGINX_CLIENT_MAX_BODY_SIZE:-100M}"
      # Upstream name must be unique per site (avoid collisions when same app has staging + production)
      export UPSTREAM_NAME="${UPSTREAM_NAME:-$(echo "${DOMAIN}" | sed 's/[^a-zA-Z0-9]/_/g')}"

      local site_conf="/etc/nginx/sites-available/${conf_filename}"
      template_file "$template" "$site_conf"

      # Enable site
      ln -sf "$site_conf" "/etc/nginx/sites-enabled/${conf_filename}"
      log_substep "Site enabled: ${conf_filename}"
    else
      log_warning "Template not found for type '${APP_TYPE}', skipping site generation"
    fi
  fi

  # Test and start
  log_step "Testing Nginx configuration"
  nginx -t

  service_enable nginx

  log_success "Nginx installed and configured"

  log_module_end "$MODULE_NAME"
}
