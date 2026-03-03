#!/usr/bin/env bash
# =============================================================================
# ServerForge Configuration
# =============================================================================
# Copy this file to config.sh and edit the values
# =============================================================================

# -----------------------------------------------------------------------------
# Remote Server Connection
# -----------------------------------------------------------------------------

# Server IP address or hostname
SERVER_IP="your.server.ip"

# SSH user (usually root for initial setup)
SERVER_USER="root"

# Path to SSH private key
SERVER_SSH_KEY="~/.ssh/id_rsa"

# SSH port (default: 22)
SERVER_SSH_PORT=22

# SSH connection options
SERVER_SSH_OPTIONS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

# -----------------------------------------------------------------------------
# Module Selection
# -----------------------------------------------------------------------------
# Set to true/false to enable/disable modules

MODULE_SYSTEM=true       # System updates, essential packages
MODULE_SECURITY=true     # Firewall, fail2ban, SSH hardening
MODULE_USERS=true        # Create deploy user
MODULE_GIT=true          # Git installation
MODULE_NGINX=true        # Nginx web server
MODULE_CERTBOT=true      # Let's Encrypt SSL
MODULE_POSTGRESQL=true   # PostgreSQL database
MODULE_REDIS=true        # Redis cache
MODULE_DOCKER=false      # Docker & Docker Compose
MODULE_NODEJS=false      # Node.js
MODULE_RUBY=false        # Ruby via rbenv
MODULE_PYTHON=false      # Python via pyenv

# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

# Primary domain for the server
DOMAIN="example.com"

# Additional domains (space-separated)
DOMAIN_ALIASES="www.example.com"

# Timezone (default: UTC)
TIMEZONE="UTC"

# -----------------------------------------------------------------------------
# Deploy User
# -----------------------------------------------------------------------------

# Username for deployment
DEPLOY_USER="deploy"

# SSH public key for deploy user (paste the full key)
DEPLOY_USER_SSH_KEY="ssh-rsa AAAA... user@machine"

# Add deploy user to sudo group (true/false)
DEPLOY_USER_SUDO=true

# Home directory for deploy user
DEPLOY_USER_HOME="/home/deploy"

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------

# Enable firewall (true/false)
FIREWALL_ENABLED=true

# Allowed ports (space-separated)
FIREWALL_ALLOWED_PORTS="22 80 443"

# Enable fail2ban (true/false)
FAIL2BAN_ENABLED=true

# SSH hardening (disable password auth, etc.)
SSH_HARDENING=true

# Change SSH port (leave empty to keep default 22)
SSH_PORT=""

# -----------------------------------------------------------------------------
# Git
# -----------------------------------------------------------------------------

# Git user name (for commits)
GIT_USER_NAME="Deploy Bot"

# Git user email
GIT_USER_EMAIL="deploy@example.com"

# -----------------------------------------------------------------------------
# Nginx
# -----------------------------------------------------------------------------

# Client max body size
NGINX_CLIENT_MAX_BODY_SIZE="100M"

# Worker processes (auto = number of CPU cores)
NGINX_WORKER_PROCESSES="auto"

# Worker connections
NGINX_WORKER_CONNECTIONS=1024

# -----------------------------------------------------------------------------
# SSL / Certbot
# -----------------------------------------------------------------------------

# Email for Let's Encrypt notifications
CERTBOT_EMAIL="admin@example.com"

# Use staging server for testing (true/false)
CERTBOT_STAGING=false

# Obtain certificate during setup (true/false)
# Set to false if DNS is not yet configured
CERTBOT_OBTAIN_CERT=true

# -----------------------------------------------------------------------------
# PostgreSQL
# -----------------------------------------------------------------------------

# PostgreSQL version (14, 15, 16, 17)
POSTGRESQL_VERSION=16

# Application database settings (for staging)
POSTGRESQL_STAGING_DB="myapp_staging"
POSTGRESQL_STAGING_USER="myapp_staging"
POSTGRESQL_STAGING_PASSWORD=""  # Auto-generated if empty

# Application database settings (for production)
POSTGRESQL_PRODUCTION_DB="myapp_production"
POSTGRESQL_PRODUCTION_USER="myapp"
POSTGRESQL_PRODUCTION_PASSWORD=""  # Auto-generated if empty

# -----------------------------------------------------------------------------
# Redis
# -----------------------------------------------------------------------------

# Redis max memory
REDIS_MAXMEMORY="256mb"

# Redis max memory policy
REDIS_MAXMEMORY_POLICY="allkeys-lru"

# Bind address (127.0.0.1 for local only)
REDIS_BIND="127.0.0.1"

# Redis password (empty = no password)
REDIS_PASSWORD=""

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------

# Install Docker Compose (true/false)
DOCKER_COMPOSE=true

# Add deploy user to docker group
DOCKER_USER_ACCESS=true

# -----------------------------------------------------------------------------
# Node.js
# -----------------------------------------------------------------------------

# Node.js major version
NODEJS_VERSION=20

# Install Yarn (true/false)
NODEJS_YARN=true

# -----------------------------------------------------------------------------
# Ruby
# -----------------------------------------------------------------------------

# Ruby version
RUBY_VERSION="3.3.0"

# Install Bundler (true/false)
RUBY_BUNDLER=true

# -----------------------------------------------------------------------------
# Python
# -----------------------------------------------------------------------------

# Python version
PYTHON_VERSION="3.12.0"

# Install common tools (virtualenv, pipenv)
PYTHON_TOOLS=true

# -----------------------------------------------------------------------------
# Application (for Nginx server blocks)
# -----------------------------------------------------------------------------

# Application name (used for Nginx config, logs, etc.)
APP_NAME="myapp"

# App type for Nginx config template (rails, node, python, static)
APP_TYPE="rails"

# Upstream socket or port
# Rails/Puma: unix:/var/www/myapp/shared/tmp/sockets/puma.sock
# Node: 127.0.0.1:3000
# Python/Gunicorn: unix:/var/www/myapp/gunicorn.sock
APP_UPSTREAM="unix:/var/www/${APP_NAME}/shared/tmp/sockets/puma.sock"

# App public root directory
APP_ROOT="/var/www/${APP_NAME}/current/public"
