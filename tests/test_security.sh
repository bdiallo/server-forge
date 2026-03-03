#!/usr/bin/env bash
# =============================================================================
# Tests: Security — path traversal, injection, password handling
# =============================================================================
source "$(dirname "$0")/helpers.sh"
setup_tmp

suite "Path traversal — project names"

run_forge -p "../etc/passwd" help
assert_exit 1 "rejects ../ traversal"
assert_stderr_contains "Invalid project name" "clear error for ../"

run_forge -p "../../root/.ssh/id_rsa" help
assert_exit 1 "rejects deep traversal"

run_forge -p "../" help
assert_exit 1 "rejects bare ../"

run_forge -p "." help
assert_exit 1 "rejects single dot"

run_forge -p ".hidden" help
assert_exit 1 "rejects dotfiles"

run_forge -p "foo/bar" help
assert_exit 1 "rejects slashes"

run_forge -p "/absolute/path" help
assert_exit 1 "rejects absolute paths"

suite "Command injection — project names"

run_forge -p 'test;id' help
assert_exit 1 "rejects semicolon"

run_forge -p 'test|cat /etc/passwd' help
assert_exit 1 "rejects pipe"

run_forge -p 'test&bg' help
assert_exit 1 "rejects ampersand"

run_forge -p '$(whoami)' help
assert_exit 1 "rejects command substitution"

run_forge -p '`id`' help
assert_exit 1 "rejects backtick substitution"

run_forge -p 'test>file' help
assert_exit 1 "rejects redirect"

run_forge -p 'test<file' help
assert_exit 1 "rejects input redirect"

suite "Sudo password — not stored on disk"

# Create a config and run a command that doesn't need SSH
cat > "${FORGE_ROOT}/projects/_test-sec.sh" << 'EOF'
SERVER_IP=""
SERVER_USER="deploy"
EOF

run_forge -p _test-sec help

# Verify no password files were created
assert_file_not_exists "${FORGE_ROOT}/.sudo_pass" "no .sudo_pass file"
assert_file_not_exists "${FORGE_ROOT}/.forge_pass" "no .forge_pass file"
assert_file_not_exists "${FORGE_ROOT}/projects/.sudo_pass" "no pass file in projects/"
assert_file_not_exists "${HOME}/.serverforge_pass" "no pass file in home dir"

rm -f "${FORGE_ROOT}/projects/_test-sec.sh"

suite "Sudo password — not in script output"

# FORGE_SUDO_PASS should never appear in help or error output
FORGE_SUDO_PASS="SUPERSECRET_TEST_TOKEN"
export FORGE_SUDO_PASS

run_forge help
assert_stdout_not_contains "SUPERSECRET_TEST_TOKEN" "password not leaked in help output"
assert_stderr_not_contains "SUPERSECRET_TEST_TOKEN" "password not leaked in help stderr"

run_forge -p nonexistent test
assert_stdout_not_contains "SUPERSECRET_TEST_TOKEN" "password not leaked in error output"
assert_stderr_not_contains "SUPERSECRET_TEST_TOKEN" "password not leaked in error stderr"

unset FORGE_SUDO_PASS

suite "Sudo password — variable scope"

# Verify the VALUE of FORGE_SUDO_PASS is not exported to child processes
# (The variable name may appear in exported function bodies — that's fine,
# the secret is the value, not the name)
output=$(bash -c '
  FORGE_SUDO_PASS="SHOULD_NOT_LEAK_VALUE_12345"
  source "'"${FORGE_ROOT}"'/lib/colors.sh"
  source "'"${FORGE_ROOT}"'/lib/logging.sh"
  source "'"${FORGE_ROOT}"'/lib/distro.sh"
  source "'"${FORGE_ROOT}"'/lib/utils.sh"
  source "'"${FORGE_ROOT}"'/lib/remote.sh"
  env | grep "SHOULD_NOT_LEAK_VALUE_12345" || echo "NOT_IN_ENV"
')

TESTS_TOTAL=$((TESTS_TOTAL + 1))
if [[ "$output" == "NOT_IN_ENV" ]]; then
  echo "  PASS: FORGE_SUDO_PASS value not exported to environment"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: FORGE_SUDO_PASS value leaked to environment"
  echo "    output: $output"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

suite "Config files — gitignored"

# Verify .gitignore contains the right patterns
gitignore_content=$(cat "${FORGE_ROOT}/.gitignore")

TESTS_TOTAL=$((TESTS_TOTAL + 1))
if echo "$gitignore_content" | grep -q "^config.sh$"; then
  echo "  PASS: config.sh is gitignored"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: config.sh not in .gitignore"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

TESTS_TOTAL=$((TESTS_TOTAL + 1))
if echo "$gitignore_content" | grep -q "projects/\*.sh"; then
  echo "  PASS: projects/*.sh is gitignored"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: projects/*.sh not in .gitignore"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

suite "Syntax validation"

TESTS_TOTAL=$((TESTS_TOTAL + 1))
if bash -n "${FORGE_ROOT}/forge.sh" 2>/dev/null; then
  echo "  PASS: forge.sh has valid syntax"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: forge.sh has syntax errors"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

TESTS_TOTAL=$((TESTS_TOTAL + 1))
if bash -n "${FORGE_ROOT}/lib/remote.sh" 2>/dev/null; then
  echo "  PASS: lib/remote.sh has valid syntax"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "  FAIL: lib/remote.sh has syntax errors"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

for module_file in "${FORGE_ROOT}"/modules/*.sh; do
  local_name="$(basename "$module_file")"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if bash -n "$module_file" 2>/dev/null; then
    echo "  PASS: modules/${local_name} has valid syntax"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  FAIL: modules/${local_name} has syntax errors"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
done

print_results
