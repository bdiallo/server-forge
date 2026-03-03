# ServerForge

A modular, idempotent collection of bash scripts for server provisioning and application deployment.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

## Features

- **Remote Execution** — Configure once, deploy via SSH
- **Multi-distro** — Supports Debian and Ubuntu (auto-detection)
- **Modular** — Each component is an independent script
- **Configurable** — All values via environment variables
- **Idempotent** — Safe to run multiple times
- **Framework-agnostic** — Works with Rails, Python, Node, or any web app

## Quick Start

```bash
# Clone the repository
git clone https://github.com/bdiallo/server-forge.git
cd server-forge

# Copy and edit the configuration
cp config.example.sh config.sh
nano config.sh

# Run the full setup on a remote server
./forge.sh setup

# Or run individual modules
./forge.sh run nginx
./forge.sh run certbot
```

## Architecture

ServerForge is inspired by the modular architecture of [serverforge (Rust)](https://crates.io/crates/serverforge), adapted for bash scripting.

```
server-forge/
├── forge.sh                    # Main entry point (orchestrator)
├── config.example.sh           # Example configuration
├── config.sh                   # Your configuration (git-ignored)
├── projects/                   # Per-project configurations (git-ignored)
│   ├── kaalisi_api.sh          # Example: ./forge.sh -p kaalisi_api setup
│   └── blog.sh                 # Example: ./forge.sh -p blog run nginx
├── lib/
│   ├── colors.sh               # Terminal colors
│   ├── logging.sh              # Logging functions
│   ├── utils.sh                # Utility functions
│   ├── distro.sh               # Distribution detection & package management
│   └── remote.sh               # SSH remote execution helpers
├── modules/
│   ├── system.sh               # System setup (updates, essential packages)
│   ├── security.sh             # Security (firewall, fail2ban, SSH hardening)
│   ├── users.sh                # User management (deploy user, SSH keys)
│   ├── git.sh                  # Git installation & configuration
│   ├── nginx.sh                # Nginx installation & configuration
│   ├── certbot.sh              # Let's Encrypt SSL certificates
│   ├── postgresql.sh           # PostgreSQL installation & database setup
│   ├── redis.sh                # Redis installation & configuration
│   ├── docker.sh               # Docker & Docker Compose
│   ├── nodejs.sh               # Node.js via NodeSource
│   ├── ruby.sh                 # Ruby via rbenv
│   └── python.sh               # Python via pyenv
└── templates/
    └── nginx/
        ├── rails.conf.template
        ├── node.conf.template
        └── python.conf.template
```

## Modules

| Module | Description |
|--------|-------------|
| `system` | System updates, essential packages, timezone |
| `security` | UFW firewall, fail2ban, SSH hardening |
| `users` | Create deploy user with SSH key authentication |
| `git` | Install and configure Git |
| `nginx` | Install Nginx with optimized configuration |
| `certbot` | Install Certbot and obtain SSL certificates |
| `postgresql` | Install PostgreSQL, create databases and roles |
| `redis` | Install and configure Redis |
| `docker` | Install Docker and Docker Compose |
| `nodejs` | Install Node.js and Yarn |
| `ruby` | Install Ruby via rbenv with Bundler |
| `python` | Install Python via pyenv |

## Configuration

All configuration is done in `config.sh`. See `config.example.sh` for all available options.

### Required Settings

```bash
# Remote server connection
SERVER_IP="your.server.ip"
SERVER_USER="root"
SERVER_SSH_KEY="~/.ssh/id_rsa"

# Domain
DOMAIN="example.com"

# Deploy user
DEPLOY_USER="deploy"
DEPLOY_USER_SSH_KEY="ssh-rsa AAAA..."
```

### Environment-Specific Variables

Variables that differ between staging and production can use `_STAGING` / `_PRODUCTION` suffixes. ServerForge resolves them based on the `-e` flag (defaults to `production`).

```bash
# These variables support environment suffixes:
DOMAIN_STAGING="api-staging.example.com"
DOMAIN_PRODUCTION="api.example.com"

DOMAIN_ALIASES_STAGING=""
DOMAIN_ALIASES_PRODUCTION=""

APP_UPSTREAM_STAGING="127.0.0.1:3008"
APP_UPSTREAM_PRODUCTION="127.0.0.1:3009"

APP_ROOT_STAGING="/home/deploy/app/staging/current/public"
APP_ROOT_PRODUCTION="/home/deploy/app/production/current/public"
```

When running with `-e staging`, `DOMAIN_STAGING` is used as `DOMAIN`, etc. Without `-e`, production values are used by default. You can also use the plain `DOMAIN` variable directly if you don't need per-environment values.

### Module Selection

```bash
# Enable/disable modules
MODULE_SYSTEM=true
MODULE_SECURITY=true
MODULE_USERS=true
MODULE_GIT=true
MODULE_NGINX=true
MODULE_CERTBOT=true
MODULE_POSTGRESQL=true
MODULE_REDIS=true
MODULE_DOCKER=false
MODULE_NODEJS=false
MODULE_RUBY=false
MODULE_PYTHON=false
```

## Multi-Project Support

When managing multiple servers or projects, use the `-p` / `--project` flag to maintain separate configurations.

```bash
# Create a project config from the example
cp config.example.sh projects/myapp.sh
nano projects/myapp.sh

# Use it with any command
./forge.sh -p myapp setup
./forge.sh -p myapp -e staging setup
./forge.sh -p myapp run nginx certbot

# List available projects
./forge.sh projects
```

Project configs live in `projects/<name>.sh` and are git-ignored (they contain secrets). Without `-p`, ServerForge falls back to `config.sh` as before.

## Commands Reference

| Command | Description |
|---------|-------------|
| `setup` | Run full setup on remote server (all enabled modules) |
| `run <module> [module...]` | Run specific module(s) on remote server |
| `local setup` | Run full setup locally (on current machine) |
| `local run <module>` | Run specific module(s) locally |
| `test` | Test SSH connection to remote server |
| `info` | Show remote server information |
| `db create -e <env>` | Create database for environment (staging/production) |
| `nginx-conf` | Generate Nginx conf file locally from project config |
| `nginx-conf --deploy` | Generate + upload + enable + test + reload on remote |
| `nginx-conf --http` | Generate HTTP-only conf (no SSL, for pre-certbot setup) |
| `nginx-conf --http --deploy` | Deploy HTTP-only conf to remote server |
| `projects` | List available project configurations |
| `help` | Show help message |
| `version` | Show version |

All commands support `-p <project>` and `-e <env>` global flags.

## Usage

### Full Server Setup

```bash
# Run all enabled modules on remote server
./forge.sh setup

# With a project and environment
./forge.sh -p kaalisi_api -e production setup
./forge.sh -p kaalisi_api -e staging setup
```

### Run Individual Modules

```bash
# Run a specific module
./forge.sh run nginx
./forge.sh run postgresql
./forge.sh run certbot

# Run multiple modules
./forge.sh run nginx certbot
```

### Local Execution

```bash
# Run locally (for testing or when already on the server)
./forge.sh local setup
./forge.sh local run nginx
```

### Database Operations

```bash
# Create staging database
./forge.sh db create -e staging

# Create production database
./forge.sh db create -e production

# With a project config
./forge.sh -p kaalisi_api db create -e staging
```

### Nginx Conf

Generate and optionally deploy an Nginx conf file from your project config. The output filename uses the `DOMAIN` value (e.g. `api-staging.kaalisi.com.conf`).

```bash
# Generate locally (output in generated/)
./forge.sh -p kaalisi_api -e staging nginx-conf

# Generate + upload + enable + test + reload on remote server
./forge.sh -p kaalisi_api -e staging nginx-conf --deploy
./forge.sh -p kaalisi_api -e production nginx-conf --deploy
```

The command reads `APP_NAME`, `APP_TYPE`, `DOMAIN`, `APP_UPSTREAM`, `APP_ROOT` from the project config (with environment resolution). On `--deploy`, it:
1. Uploads to `/etc/nginx/sites-available/<domain>.conf`
2. Symlinks to `sites-enabled/`
3. Runs `nginx -t`
4. If OK, `systemctl reload nginx`
5. If `nginx -t` fails, rolls back (removes symlink)

### SSL Certificates (Certbot)

The certbot module installs Certbot, sets up auto-renewal, and obtains SSL certificates.

```bash
# Install certbot + obtain cert (as part of full setup)
./forge.sh -p kaalisi_api -e staging setup

# Or run certbot module alone on remote server
./forge.sh -p kaalisi_api -e staging run certbot

# Run locally (when already on the server)
./forge.sh -p kaalisi_api -e staging local run certbot
```

The module uses these config variables:

```bash
CERTBOT_EMAIL="you@example.com"     # Required — Let's Encrypt notifications
CERTBOT_STAGING=true                # Use staging server (test first, no rate limits)
CERTBOT_OBTAIN_CERT=true            # Actually request the certificate
DOMAIN="api-staging.example.com"    # Domain to certify (resolved from DOMAIN_STAGING etc.)
```

**Important:** Before obtaining a certificate:
1. DNS must point to the server (`A` record for the domain → server IP)
2. Nginx must be running with a server block for that domain (use `nginx-conf --deploy` first)
3. Port 80 must be accessible (for ACME challenge)

**Workflow for a new domain:**
```bash
# 1. Deploy HTTP-only nginx conf (no SSL yet)
./forge.sh -p kaalisi_api -e staging nginx-conf --http --deploy

# 2. Obtain SSL certificate (needs nginx running + DNS pointing to server)
./forge.sh -p kaalisi_api -e staging run certbot

# 3. Deploy full HTTPS nginx conf (cert now exists)
./forge.sh -p kaalisi_api -e staging nginx-conf --deploy
```

**Check if certbot is installed on the server:**
```bash
ssh user@server "certbot --version"
```

**Check existing certificates:**
```bash
ssh user@server "sudo certbot certificates"
```

**Manually obtain a certificate (on the server):**
```bash
sudo certbot --nginx -d api-staging.kaalisi.com --email boubacar@kaalisi.com
```

## Idempotency

Every command is safe to run multiple times. ServerForge checks the current state before acting:

- **Packages** — installed via `apt` which skips already-installed packages
- **Services** — `systemctl enable` is a no-op if already enabled
- **PostgreSQL users** — checks `pg_roles` before `CREATE USER`
- **PostgreSQL databases** — checks `pg_database` before `CREATE DATABASE`
- **Privileges** — `GRANT ALL` is always safe to re-run
- **Firewall rules** — `ufw allow` skips existing rules
- **SSH keys** — appended only if not already present
- **Config files** — overwritten with the same content (converges to desired state)

This means you can re-run `setup` after a partial failure or to apply config changes without worrying about duplicate resources or errors.

```bash
# First run: installs everything
./forge.sh -p kaalisi_api setup

# Second run: skips what already exists, applies any config changes
./forge.sh -p kaalisi_api setup

# Same for database creation
./forge.sh -p kaalisi_api db create -e staging   # Creates user + database
./forge.sh -p kaalisi_api db create -e staging   # "User already exists", "Database already exists"
```

## Customization

ServerForge is designed to be easily customizable:

1. **Add a new module**: Create a new file in `modules/` following the existing pattern
2. **Modify existing functionality**: Edit the relevant module file
3. **Add new templates**: Add files to `templates/` directory
4. **Override defaults**: Set variables in `config.sh`

### Creating a Custom Module

```bash
# modules/mymodule.sh
#!/usr/bin/env bash

MODULE_NAME="mymodule"

mymodule_run() {
  log_module_start "$MODULE_NAME"

  # Your installation/configuration logic here
  apt_install mypackage

  log_module_end "$MODULE_NAME"
}

# Export the run function
module_run() {
  mymodule_run
}
```

## New Project Staging Workflow

When deploying a new project to a shared VPS, ServerForge handles the infrastructure (user, nginx, database, SSL). The application deployment itself (git clone, bundle install, migrations, process manager) is handled by each app's own deploy script.

### Steps

**1. Create the project config**

```bash
cp config.example.sh projects/myapp.sh
nano projects/myapp.sh
```

Set at minimum: `SERVER_IP`, `SERVER_USER` (must have sudo), `DEPLOY_USER`, `DEPLOY_USER_SSH_KEY_FILE`, `DOMAIN_STAGING`, `APP_NAME`, `APP_TYPE`, `APP_UPSTREAM_STAGING`, `APP_ROOT_STAGING`, `POSTGRESQL_DB_STAGING`, `POSTGRESQL_USER_STAGING`.

**2. Create the Linux deploy user**

```bash
./forge.sh -p myapp run users
```

Creates the user, adds SSH key, configures passwordless sudo, creates `/var/www` and `/var/log/apps`.

**3. Create the staging database**

```bash
./forge.sh -p myapp db create -e staging
```

Creates the PostgreSQL role and database. Outputs the connection URL.

**4. Deploy HTTP-only Nginx config (pre-SSL)**

```bash
./forge.sh -p myapp -e staging nginx-conf --http --deploy
```

Generates the Nginx server block from the template, uploads it, enables it, and reloads Nginx. This is needed before Certbot can verify domain ownership via the ACME challenge.

**5. Obtain SSL certificate**

```bash
./forge.sh -p myapp -e staging run certbot
```

Installs Certbot if needed, requests a Let's Encrypt certificate for the domain. DNS must already point to the server.

**6. Deploy HTTPS Nginx config**

```bash
./forge.sh -p myapp -e staging nginx-conf --deploy
```

Replaces the HTTP-only config with the full HTTPS version (SSL termination, redirect HTTP→HTTPS).

**7. Deploy the application** (not managed by ServerForge)

Each application has its own deploy script. For example:

```bash
# Rails app
cd ~/myapp && ./scripts/deploy.sh staging deploy main

# Node.js app
cd ~/myapp && ./scripts/deploy.sh staging deploy main
```

### Example: Kaalisi API

```bash
# 1. Create kaalisi user on the server
./forge.sh -p kaalisi_api run users

# 2. Create staging database
./forge.sh -p kaalisi_api db create -e staging

# 3. Deploy HTTP nginx config (for certbot ACME challenge)
./forge.sh -p kaalisi_api -e staging nginx-conf --http --deploy

# 4. Obtain SSL certificate
./forge.sh -p kaalisi_api -e staging run certbot

# 5. Deploy HTTPS nginx config
./forge.sh -p kaalisi_api -e staging nginx-conf --deploy

# 6. Deploy the app (handled by kaalisi_api's own deploy script)
cd ~/code/kaalisi_api && ./scripts/deploy.sh staging deploy main
```

## Similar Projects

- [serverforge (Rust)](https://crates.io/crates/serverforge) — Rust-based server automation tool
- [insign/server-for-laravel](https://github.com/insign/server-for-web) — Shell script for Laravel server setup
- [gtsa/server-setup-linux](https://github.com/gtsa/server-setup-linux) — Ubuntu server setup automation

## Requirements

### Local Machine
- Bash 3.2+ (macOS compatible)
- SSH client
- rsync (optional, for file sync)

### Remote Server
- Debian 10+ or Ubuntu 20.04+
- Root access (or sudo privileges)
- SSH access

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
