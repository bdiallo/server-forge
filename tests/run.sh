#!/usr/bin/env bash
# =============================================================================
# ServerForge Test Runner
# =============================================================================
# Usage:
#   ./tests/run.sh              Run all tests
#   ./tests/run.sh security     Run a specific test suite
# =============================================================================
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_TESTS=0
FAILED_SUITES=()

run_suite() {
  local test_file="$1"
  local suite_name
  suite_name="$(basename "$test_file" .sh | sed 's/^test_//')"

  echo ""
  echo "=== Suite: ${suite_name} ==="

  local output exit_code
  set +e
  output=$(bash "$test_file" 2>&1)
  exit_code=$?
  set -e

  echo "$output"

  # Extract counts from the results line
  local passed failed total
  passed=$(echo "$output" | grep "^Results:" | sed 's/Results: \([0-9]*\).*/\1/')
  total=$(echo "$output" | grep "^Results:" | sed 's/.*\/\([0-9]*\) passed.*/\1/')
  failed=$(echo "$output" | grep "^Results:" | sed 's/.*, \([0-9]*\) failed/\1/')

  if [[ -n "$passed" ]] && [[ -n "$total" ]] && [[ -n "$failed" ]]; then
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    TOTAL_TESTS=$((TOTAL_TESTS + total))
  fi

  if [[ "$exit_code" -ne 0 ]] || [[ "${failed:-0}" -gt 0 ]]; then
    FAILED_SUITES+=("$suite_name")
  fi
}

# Determine which suites to run
if [[ $# -gt 0 ]]; then
  # Run specific suites
  for name in "$@"; do
    test_file="${TESTS_DIR}/test_${name}.sh"
    if [[ -f "$test_file" ]]; then
      run_suite "$test_file"
    else
      echo "Test suite not found: $name"
      echo "Available suites:"
      for f in "${TESTS_DIR}"/test_*.sh; do
        echo "  $(basename "$f" .sh | sed 's/^test_//')"
      done
      exit 1
    fi
  done
else
  # Run all test suites
  for test_file in "${TESTS_DIR}"/test_*.sh; do
    run_suite "$test_file"
  done
fi

# Final summary
echo ""
echo "====================================="
echo "TOTAL: ${TOTAL_PASSED}/${TOTAL_TESTS} passed, ${TOTAL_FAILED} failed"
if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
  echo "Failed suites: ${FAILED_SUITES[*]}"
fi
echo "====================================="

exit "$TOTAL_FAILED"
