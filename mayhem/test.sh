#!/usr/bin/env bash
#
# mayhem/test.sh — RUN gridsort's upstream suite: src/bench.c (built by build.sh as
# /mayhem/bench). bench runs validate() (quadsort vs qsort golden check) and then, for
# every benchmark row, sorts with qsort/gridsort/quadsort and verifies each output
# element-by-element against a known-good sorted array (printing "validate:" /
# "unstable" / "Not properly sorted" / "Not verified" on mismatch). bench always exits
# 0, so this oracle asserts on its OUTPUT: every expected result row must be present
# and no mismatch marker may appear.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

RUNNER=/mayhem/bench
if [ ! -x "$RUNNER" ]; then
  echo "FATAL: $RUNNER missing — mayhem/build.sh should have built it" >&2
  emit_ctrf gridsort-bench 0 1
  exit 1
fi

LOG=/tmp/bench-test.log
rc=0
"$RUNNER" 1000 2 1 12345 >"$LOG" 2>&1 || rc=$?

# With these fixed args bench emits exactly 52 result rows (qsort/gridsort/quadsort/
# s_quadsort across every distribution), each individually verified in-process.
EXPECTED_ROWS=52
rows=$(grep -cE '^\|\s*(qsort|gridsort|quadsort|s_quadsort) \|' "$LOG" || true)
bad=$(grep -cE 'Not properly sorted|Not verified|validate:|unstable' "$LOG" || true)

# tests = validate() (1) + each verified sort row
total=$(( EXPECTED_ROWS + 1 ))
failed=0
if [ "$rc" -ne 0 ] || [ "$bad" -ne 0 ] || [ "$rows" -ne "$EXPECTED_ROWS" ]; then
  present=$(( rows > EXPECTED_ROWS ? EXPECTED_ROWS : rows ))
  failed=$(( total - present ))
  [ "$failed" -lt 1 ] && failed=1
  echo "bench suite FAILED: rc=$rc mismatch_markers=$bad rows=$rows/$EXPECTED_ROWS" >&2
  tail -20 "$LOG" >&2
fi

emit_ctrf gridsort-bench $(( total - failed )) "$failed"
