#!/usr/bin/env bash
# =============================================================================
# Tests: projects command
# =============================================================================
source "$(dirname "$0")/helpers.sh"
setup_tmp

suite "Projects command — empty state"

# Temporarily move real project configs aside
SAVED_PROJECTS="${TEST_TMP}/saved_projects"
mkdir -p "$SAVED_PROJECTS"
mv "${FORGE_ROOT}"/projects/*.sh "$SAVED_PROJECTS/" 2>/dev/null || true

run_forge projects
assert_exit 0 "projects command succeeds with empty dir"
assert_stdout_contains "No project configurations found" "shows empty message"
assert_stdout_contains "cp config.example.sh" "shows how to create one"

# Restore real project configs
mv "$SAVED_PROJECTS"/*.sh "${FORGE_ROOT}/projects/" 2>/dev/null || true

suite "Projects command — with projects"

# Create test project configs
cat > "${FORGE_ROOT}/projects/_test-alpha.sh" << 'EOF'
SERVER_IP="1.1.1.1"
EOF
cat > "${FORGE_ROOT}/projects/_test-beta.sh" << 'EOF'
SERVER_IP="2.2.2.2"
EOF

run_forge projects
assert_exit 0 "projects command succeeds with projects"
assert_stdout_contains "_test-alpha" "lists first project"
assert_stdout_contains "_test-beta" "lists second project"
assert_stdout_contains "Usage.*-p" "shows usage hint"

suite "Projects command — ignores non-.sh files"

touch "${FORGE_ROOT}/projects/_test-ignore.txt"
run_forge projects
assert_stdout_not_contains "_test-ignore" "does not list .txt files"
rm -f "${FORGE_ROOT}/projects/_test-ignore.txt"

# Cleanup
rm -f "${FORGE_ROOT}/projects/_test-alpha.sh" "${FORGE_ROOT}/projects/_test-beta.sh"

print_results
