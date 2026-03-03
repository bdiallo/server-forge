#!/usr/bin/env bash
# =============================================================================
# Tests: Configuration loading
# =============================================================================
source "$(dirname "$0")/helpers.sh"
setup_tmp

suite "Config loading — no config.sh, no -p"

# Temporarily rename config.sh if it exists
if [[ -f "${FORGE_ROOT}/config.sh" ]]; then
  mv "${FORGE_ROOT}/config.sh" "${FORGE_ROOT}/config.sh.bak"
  RESTORE_CONFIG=true
else
  RESTORE_CONFIG=false
fi

run_forge test
assert_exit 1 "fails without config.sh"
assert_stderr_contains "Configuration file not found" "tells user to create config"

# Restore config.sh
if [[ "$RESTORE_CONFIG" == "true" ]]; then
  mv "${FORGE_ROOT}/config.sh.bak" "${FORGE_ROOT}/config.sh"
fi

suite "Config loading — with -p loads project config"

mkdir -p "${FORGE_ROOT}/projects"
cat > "${FORGE_ROOT}/projects/_test-cfg.sh" << 'EOF'
SERVER_IP=""
SERVER_USER="testuser"
DOMAIN="config-test.example.com"
POSTGRESQL_DB_STAGING="cfgtest_staging"
POSTGRESQL_USER_STAGING="cfgtest_user"
POSTGRESQL_PASSWORD_STAGING="pass"
MODULE_SYSTEM=false
MODULE_SECURITY=false
MODULE_USERS=false
MODULE_GIT=false
MODULE_NGINX=false
MODULE_CERTBOT=false
MODULE_POSTGRESQL=false
MODULE_REDIS=false
MODULE_DOCKER=false
MODULE_NODEJS=false
MODULE_RUBY=false
MODULE_PYTHON=false
EOF

# db create loads config — verify it reads the project's values (no SSH involved)
run_forge -p _test-cfg -e staging db create
assert_stdout_contains "cfgtest_staging" "project config loaded correctly"

rm -f "${FORGE_ROOT}/projects/_test-cfg.sh"

suite "Config loading — -p takes precedence over config.sh"

# Even if config.sh exists, -p should load from projects/
cat > "${FORGE_ROOT}/projects/_test-override.sh" << 'EOF'
SERVER_IP=""
SERVER_USER="root"
DOMAIN="override.example.com"
POSTGRESQL_DB_STAGING="override_db"
POSTGRESQL_USER_STAGING="override_user"
POSTGRESQL_PASSWORD_STAGING="pass"
EOF

run_forge -p _test-override -e staging db create
assert_stdout_contains "override_db" "project config overrides root config.sh"

rm -f "${FORGE_ROOT}/projects/_test-override.sh"

suite "Config loading — backward compatibility"

# With config.sh and no -p, should use config.sh
if [[ -f "${FORGE_ROOT}/config.sh" ]]; then
  run_forge test
  # Should at least try to load config.sh (may fail on SSH)
  # The key is it doesn't say "Project config not found"
  assert_stderr_not_contains "Project config not found" "uses config.sh when no -p"
else
  echo "  SKIP: no config.sh present, cannot test backward compat"
fi

print_results
