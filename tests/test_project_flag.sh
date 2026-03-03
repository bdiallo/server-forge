#!/usr/bin/env bash
# =============================================================================
# Tests: -p / --project flag
# =============================================================================
source "$(dirname "$0")/helpers.sh"
setup_tmp

suite "Project flag — validation"

run_forge -p ""
assert_exit 1 "-p with empty string fails"

run_forge -p
assert_exit 1 "-p without value fails"

run_forge --project
assert_exit 1 "--project without value fails"

run_forge -p "../etc/passwd" help
assert_exit 1 "-p rejects path traversal (../)"
assert_stderr_contains "Invalid project name" "error message mentions invalid name"

run_forge -p "../../root" help
assert_exit 1 "-p rejects deeper path traversal"

run_forge -p "/etc/passwd" help
assert_exit 1 "-p rejects absolute paths"
assert_stderr_contains "Invalid project name" "error message for absolute path"

run_forge -p "foo bar" help
assert_exit 1 "-p rejects spaces"

run_forge -p "foo;rm" help
assert_exit 1 "-p rejects semicolons (command injection)"

run_forge -p 'foo$(whoami)' help
assert_exit 1 "-p rejects command substitution"

run_forge -p 'foo`whoami`' help
assert_exit 1 "-p rejects backtick injection"

suite "Project flag — valid names"

run_forge -p "kaalisi" help
assert_exit 0 "-p kaalisi with help works"

run_forge -p "my-project" help
assert_exit 0 "-p accepts hyphens"

run_forge -p "my_project" help
assert_exit 0 "-p accepts underscores"

run_forge -p "Project123" help
assert_exit 0 "-p accepts mixed case and numbers"

run_forge --project "kaalisi" help
assert_exit 0 "--project long form works"

suite "Project flag — config loading"

# Create a temporary project config
mkdir -p "${FORGE_ROOT}/projects"
cat > "${FORGE_ROOT}/projects/test-project.sh" << 'EOF'
SERVER_IP=""
SERVER_USER="root"
DOMAIN="test.example.com"
POSTGRESQL_DB_STAGING="testproj_staging"
POSTGRESQL_USER_STAGING="testproj_user"
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

# Use db create to verify config loaded (no SSH, fails on psql but shows values)
run_forge -p test-project -e staging db create
assert_stdout_contains "testproj_staging" "project config loaded correctly"

rm -f "${FORGE_ROOT}/projects/test-project.sh"

suite "Project flag — missing config"

run_forge -p nonexistent test
assert_exit 1 "missing project config fails"
assert_stderr_contains "Project config not found" "error mentions project not found"

suite "Project flag — position independence"

run_forge help -p kaalisi
assert_exit 0 "-p after command works"

run_forge -p kaalisi help
assert_exit 0 "-p before command works"

print_results
