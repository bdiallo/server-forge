#!/usr/bin/env bash
# =============================================================================
# Tests: -e / --environment flag
# =============================================================================
source "$(dirname "$0")/helpers.sh"

suite "Environment flag — validation"

run_forge -e ""
assert_exit 1 "-e with empty string fails"

run_forge -e
assert_exit 1 "-e without value fails"

run_forge --environment
assert_exit 1 "--environment without value fails"

run_forge -e "development" help
assert_exit 1 "-e rejects invalid environments"
assert_stderr_contains "Invalid environment" "error mentions invalid environment"

run_forge -e "test" help
assert_exit 1 "-e rejects 'test' (not staging|production)"

run_forge -e "STAGING" help
assert_exit 1 "-e rejects uppercase (must be lowercase)"

suite "Environment flag — valid values"

run_forge -e staging help
assert_exit 0 "-e staging works"

run_forge -e production help
assert_exit 0 "-e production works"

run_forge --environment staging help
assert_exit 0 "--environment long form works"

suite "Environment flag — db create requires -e"

# Need a config for db create to load
mkdir -p "${FORGE_ROOT}/projects"
cat > "${FORGE_ROOT}/projects/_test-env.sh" << 'EOF'
SERVER_IP=""
SERVER_USER="root"
POSTGRESQL_DB_STAGING="test_staging"
POSTGRESQL_USER_STAGING="test_staging"
POSTGRESQL_PASSWORD_STAGING="secret123"
POSTGRESQL_DB_PRODUCTION="test_production"
POSTGRESQL_USER_PRODUCTION="test_production"
POSTGRESQL_PASSWORD_PRODUCTION="secret456"
EOF

run_forge -p _test-env db create
assert_exit 1 "db create without -e fails"
assert_stderr_contains "Usage.*-e" "error shows -e in usage"

rm -f "${FORGE_ROOT}/projects/_test-env.sh"

suite "Environment flag — combined with -p"

run_forge -p kaalisi -e staging help
assert_exit 0 "-p and -e together work"

run_forge -e production -p kaalisi help
assert_exit 0 "-e before -p works"

run_forge help -p kaalisi -e staging
assert_exit 0 "flags after command work"

print_results
