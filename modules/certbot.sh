#!/usr/bin/env bash
# =============================================================================
# ServerForge Module: Certbot
# =============================================================================
# Install Certbot and obtain SSL certificates
# =============================================================================

MODULE_NAME="certbot"

module_run() {
  log_module_start "$MODULE_NAME"
  
  require_root
  detect_distro
  
  local email="${CERTBOT_EMAIL:-}"
  local staging="${CERTBOT_STAGING:-false}"
  local obtain_cert="${CERTBOT_OBTAIN_CERT:-true}"
  local domain="${DOMAIN:-}"
  local domain_aliases="${DOMAIN_ALIASES:-}"
  
  # Install Certbot
  log_step "Installing Certbot"
  pkg_update
  pkg_install certbot python3-certbot-nginx
  
  log_substep "Certbot version: $(certbot --version 2>&1 | cut -d' ' -f2)"
  
  # Setup auto-renewal
  log_step "Configuring auto-renewal"
  
  if systemctl list-timers | grep -q certbot; then
    log_substep "Certbot timer is active"
  else
    log_substep "Setting up renewal cron job"
    echo "0 3 * * * root certbot renew --quiet --post-hook 'systemctl reload nginx'" > /etc/cron.d/certbot-renewal
  fi
  
  # Obtain certificate
  if is_true "$obtain_cert" && [[ -n "$domain" ]] && [[ -n "$email" ]]; then
    obtain_certificate "$domain" "$email" "$staging" "$domain_aliases"
  else
    log_warning "Skipping certificate generation"
    log_info "To obtain a certificate later, run:"
    log_info "  certbot --nginx -d yourdomain.com"
  fi
  
  log_module_end "$MODULE_NAME"
}

obtain_certificate() {
  local domain="$1"
  local email="$2"
  local staging="$3"
  local aliases="$4"
  
  log_step "Obtaining SSL certificate for: $domain"
  
  # Check if certificate already exists
  if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
    log_substep "Certificate already exists for $domain"
    return 0
  fi
  
  # Build certbot command
  local cmd="certbot certonly --nginx --non-interactive --agree-tos"
  cmd+=" --email $email"
  cmd+=" -d $domain"
  
  # Add aliases
  for alias in $aliases; do
    cmd+=" -d $alias"
  done
  
  # Use staging if requested
  if is_true "$staging"; then
    log_warning "Using Let's Encrypt staging server"
    cmd+=" --staging"
  fi
  
  log_substep "Requesting certificate..."
  
  if eval "$cmd"; then
    log_success "Certificate obtained successfully!"
  else
    log_warning "Failed to obtain certificate. This is normal if:"
    log_warning "  - The domain doesn't point to this server yet"
    log_warning "  - Nginx is not properly configured"
    log_warning "  - Port 80 is not accessible"
  fi
}
