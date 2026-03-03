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
│   ├── kaalisi.sh              # Example: ./forge.sh -p kaalisi setup
│   └── staging.sh              # Example: ./forge.sh -p staging run nginx
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
cp config.example.sh projects/kaalisi.sh
nano projects/kaalisi.sh

# Use it with any command
./forge.sh -p kaalisi setup
./forge.sh -p kaalisi run nginx certbot
./forge.sh -p kaalisi test

# List available projects
./forge.sh projects
```

Project configs live in `projects/<name>.sh` and are git-ignored (they contain secrets). Without `-p`, ServerForge falls back to `config.sh` as before.

## Usage

### Full Server Setup

```bash
# Run all enabled modules on remote server
./forge.sh setup
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
./forge.sh db create staging

# Create production database
./forge.sh db create production
```

### App Server Block

```bash
# Generate Nginx server block for your app
./forge.sh nginx-site myapp rails
./forge.sh nginx-site myapi node
./forge.sh nginx-site myservice python
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

## Similar Projects

- [serverforge (Rust)](https://crates.io/crates/serverforge) — Rust-based server automation tool
- [insign/server-for-laravel](https://github.com/insign/server-for-web) — Shell script for Laravel server setup
- [gtsa/server-setup-linux](https://github.com/gtsa/server-setup-linux) — Ubuntu server setup automation

## Requirements

### Local Machine
- Bash 4.0+
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
