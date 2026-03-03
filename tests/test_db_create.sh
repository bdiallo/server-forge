#!/usr/bin/env bash
# =============================================================================
# Tests: db create command
# =============================================================================
source "$(dirname "$0")/helpers.sh"
setup_tmp

# Create a test project config with no SERVER_IP (local mode)
mkdir -p "${FORGE_ROOT}/projects"
cat > "${FORGE_ROOT}/projects/_test-db.sh" << 'EOF'
SERVER_IP=""
SERVER_USER="root"
DOMAIN="test.example.com"
POSTGRESQL_VERSION=16
POSTGRESQL_DB_STAGING="testapp_staging"
POSTGRESQL_USER_STAGING="testapp_staging"
POSTGRESQL_PASSWORD_STAGING="test_pass_staging"
POSTGRESQL_DB_PRODUCTION="testapp_prod"
POSTGRESQL_USER_PRODUCTION="testapp_prod"
POSTGRESQL_PASSWORD_PRODUCTION="test_pass_prod"
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

suite "db create — requires -e flag"

run_forge -p _test-db db create
assert_exit 1 "db create without -e fails"
assert_stderr_contains "Usage" "shows usage on missing -e"

suite "db create — rejects invalid subcommand"

run_forge -p _test-db db drop
assert_exit 1 "db drop fails (unknown subcommand)"
assert_stderr_contains "Unknown db command" "error for unknown db subcommand"

suite "db create — reads correct env vars"

# This will fail on psql (no local postgres), but we can check the output
# to verify it read the right config values
run_forge -p _test-db -e staging db create
# Will fail (no postgres) but should show correct database name
assert_stdout_contains "testapp_staging" "staging reads POSTGRESQL_DB_STAGING"

run_forge -p _test-db -e production db create
assert_stdout_contains "testapp_prod" "production reads POSTGRESQL_DB_PRODUCTION"

suite "db create — dynamic var resolution"

# Verify the env suffix is correctly uppercased
cat > "${FORGE_ROOT}/projects/_test-db2.sh" << 'EOF'
SERVER_IP=""
SERVER_USER="root"
POSTGRESQL_DB_STAGING="custom_stg"
POSTGRESQL_USER_STAGING="custom_stg_user"
POSTGRESQL_PASSWORD_STAGING="pass1"
EOF

run_forge -p _test-db2 -e staging db create
assert_stdout_contains "custom_stg" "dynamic var name resolves POSTGRESQL_DB_STAGING"
assert_stdout_contains "custom_stg_user" "dynamic var name resolves POSTGRESQL_USER_STAGING"

rm -f "${FORGE_ROOT}/projects/_test-db2.sh"

suite "db create — defaults when vars are missing"

cat > "${FORGE_ROOT}/projects/_test-db-defaults.sh" << 'EOF'
SERVER_IP=""
SERVER_USER="root"
EOF

run_forge -p _test-db-defaults -e staging db create
assert_stdout_contains "myapp_staging" "defaults to myapp_<env> when var unset"

rm -f "${FORGE_ROOT}/projects/_test-db-defaults.sh"

# Cleanup
rm -f "${FORGE_ROOT}/projects/_test-db.sh"

print_results
