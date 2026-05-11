#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-../../results/rustyhermit/nx_unsafe_uhyve}"
HERMIT_STACK_APP="${HERMIT_STACK_APP:-target/x86_64-unknown-hermit/debug/nx_stack_unsafe_probe}"
HERMIT_HEAP_APP="${HERMIT_HEAP_APP:-target/x86_64-unknown-hermit/debug/nx_heap_unsafe_probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

run_probe() {
  local name="$1"
  local app="$2"
  local begin_marker="$3"
  local allowed_marker="$4"
  local logfile="$OUTDIR/${name}.log"

  echo "[*] RustyHermit Uhyve unsafe NX ${name} probe"
  echo "[*] App: $app"

  if [ ! -f "$app" ]; then
    echo "RESULT (${name}): FAIL (probe binary not found)"
    return 1
  fi

  timeout "${TIMEOUT_SECS}s" uhyve "$app" > "$logfile" 2>&1 || true

  if ! grep -q '^PROBE_OK$' "$logfile"; then
    echo "RESULT (${name}): FAIL (probe did not start)"
    return 1
  fi

  if ! grep -q "^${begin_marker}$" "$logfile"; then
    echo "RESULT (${name}): FAIL (begin marker missing)"
    return 1
  fi

  if grep -q "^${allowed_marker}$" "$logfile"; then
    echo "RESULT (${name}): FAIL (${name} execution allowed)"
    return 1
  fi

  if grep -q 'INSTRUCTION_FETCH' "$logfile"; then
    echo "RESULT (${name}): PASS (${name} execution blocked by instruction-fetch fault)"
    return 0
  fi

  echo "RESULT (${name}): PASS/UNCLEAR (${name} execution stopped before allowed marker)"
  return 0
}

stack_result=0
heap_result=0

run_probe "stack" "$HERMIT_STACK_APP" "STACK_EXEC_BEGIN" "STACK_EXEC_ALLOWED" || stack_result=1
run_probe "heap" "$HERMIT_HEAP_APP" "HEAP_EXEC_BEGIN" "HEAP_EXEC_ALLOWED" || heap_result=1

echo

if [ "$stack_result" -eq 0 ] && [ "$heap_result" -eq 0 ]; then
  echo "RESULT: PASS (unsafe stack/heap execution blocked)"
else
  echo "RESULT: FAIL (unsafe stack/heap execution allowed or probe invalid)"
  exit 1
fi
