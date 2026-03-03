#!/usr/bin/env bash
# =============================================================================
# Tests: help / usage output
# =============================================================================
source "$(dirname "$0")/helpers.sh"

suite "Help command"

run_forge help
assert_exit 0 "help exits 0"
assert_stdout_contains "ServerForge" "shows tool name"

suite "Help — global options documented"

run_forge help
assert_stdout_contains "\-p.*\-\-project" "shows -p / --project"
assert_stdout_contains "\-e.*\-\-environment" "shows -e / --environment"

suite "Help — commands documented"

run_forge help
assert_stdout_contains "setup" "documents setup"
assert_stdout_contains "run" "documents run"
assert_stdout_contains "local setup" "documents local setup"
assert_stdout_contains "test" "documents test"
assert_stdout_contains "info" "documents info"
assert_stdout_contains "db create" "documents db create"
assert_stdout_contains "nginx-conf" "documents nginx-conf"
assert_stdout_contains "projects" "documents projects"

suite "Help — examples include project and environment"

run_forge help
assert_stdout_contains "\-p kaalisi_api" "example with -p"
assert_stdout_contains "\-e staging\|\-e production" "example with -e"

suite "Help aliases"

run_forge --help
assert_exit 0 "--help works"
assert_stdout_contains "ServerForge" "--help shows usage"

run_forge -h
assert_exit 0 "-h works"
assert_stdout_contains "ServerForge" "-h shows usage"

suite "Version"

run_forge version
assert_exit 0 "version command works"
assert_stdout_contains "ServerForge v" "shows version string"

run_forge --version
assert_exit 0 "--version works"

run_forge -v
assert_exit 0 "-v works"

suite "Unknown command"

run_forge thiscommanddoesnotexist
assert_exit 1 "unknown command fails"
assert_stderr_contains "Unknown command" "shows error for unknown command"

print_results
