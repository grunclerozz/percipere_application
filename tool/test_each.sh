#!/usr/bin/env bash
# Runs every test file on its own, retrying runner crashes (flutter_tester
# dies at random on the Windows dev PC: "did not complete" / "Connection
# closed before test suite loaded"). A real failure (an assertion) is not
# retried. Usage: bash tool/test_each.sh
cd "$(dirname "$0")/.." || exit 1
pass=0; fail=0; total=0; failed=()
for f in $(find test -name '*_test.dart' | sort); do
  for attempt in 1 2 3 4; do
    out=$(flutter test "$f" 2>&1)
    if echo "$out" | grep -q "All tests passed"; then
      n=$(echo "$out" | grep -o "+[0-9]*: All tests passed" | tr -dc '0-9')
      total=$((total + n)); pass=$((pass + 1))
      echo "PASS $f ($n tests, attempt $attempt)"; break
    fi
    if ! echo "$out" | grep -q "did not complete\|Connection closed before"; then
      echo "FAIL $f"; echo "$out" | grep -E "Expected|Actual|Which" | head -6
      fail=$((fail + 1)); failed+=("$f"); break
    fi
    if [ $attempt = 4 ]; then echo "CRASH $f (4 attempts)"; fail=$((fail + 1)); failed+=("$f"); fi
  done
done
echo "files passed: $pass, failed: $fail, tests passed: $total"
[ $fail = 0 ]
