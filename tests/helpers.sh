#!/usr/bin/env bash
# =============================================================================
# Test Helpers — minimal assertion library
# =============================================================================

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0
CURRENT_SUITE=""

# Path to the forge root (one level up from tests/)
FORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Temporary directory for test fixtures (cleaned up on exit)
TEST_TMP=""

setup_tmp() {
  TEST_TMP="$(mktemp -d)"
}

cleanup_tmp() {
  if [[ -n "$TEST_TMP" ]]; then
    rm -rf "$TEST_TMP"
  fi
}

trap cleanup_tmp EXIT

# Run forge.sh and capture output + exit code
# Usage: run_forge [args...]
# Sets: FORGE_EXIT, FORGE_STDOUT, FORGE_STDERR
run_forge() {
  local tmp_out tmp_err
  tmp_out="$(mktemp)"
  tmp_err="$(mktemp)"
  set +e
  bash "${FORGE_ROOT}/forge.sh" "$@" >"$tmp_out" 2>"$tmp_err"
  FORGE_EXIT=$?
  set -e
  FORGE_STDOUT="$(cat "$tmp_out")"
  FORGE_STDERR="$(cat "$tmp_err")"
  rm -f "$tmp_out" "$tmp_err"
}

suite() {
  CURRENT_SUITE="$1"
  echo ""
  echo "--- $1 ---"
}

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $msg"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  FAIL: $msg"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_exit() {
  local expected="$1" msg="$2"
  assert_eq "$expected" "$FORGE_EXIT" "$msg"
}

assert_stdout_contains() {
  local pattern="$1" msg="$2"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if echo "$FORGE_STDOUT" | grep -q "$pattern"; then
    echo "  PASS: $msg"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  FAIL: $msg"
    echo "    pattern not found in stdout: $pattern"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_stderr_contains() {
  local pattern="$1" msg="$2"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if echo "$FORGE_STDERR" | grep -q "$pattern"; then
    echo "  PASS: $msg"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  FAIL: $msg"
    echo "    pattern not found in stderr: $pattern"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_stdout_not_contains() {
  local pattern="$1" msg="$2"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if echo "$FORGE_STDOUT" | grep -q "$pattern"; then
    echo "  FAIL: $msg"
    echo "    pattern should NOT be in stdout: $pattern"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    echo "  PASS: $msg"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

assert_stderr_not_contains() {
  local pattern="$1" msg="$2"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if echo "$FORGE_STDERR" | grep -q "$pattern"; then
    echo "  FAIL: $msg"
    echo "    pattern should NOT be in stderr: $pattern"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    echo "  PASS: $msg"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

assert_file_exists() {
  local path="$1" msg="$2"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [[ -f "$path" ]]; then
    echo "  PASS: $msg"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  FAIL: $msg"
    echo "    file not found: $path"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_file_not_exists() {
  local path="$1" msg="$2"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  if [[ ! -f "$path" ]]; then
    echo "  PASS: $msg"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  FAIL: $msg"
    echo "    file should not exist: $path"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

print_results() {
  echo ""
  echo "==================================="
  echo "Results: ${TESTS_PASSED}/${TESTS_TOTAL} passed, ${TESTS_FAILED} failed"
  echo "==================================="
  return "$TESTS_FAILED"
}
