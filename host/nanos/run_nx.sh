#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-nanos_nx_runs}"
NANOS_STACK_IMAGE="${NANOS_STACK_IMAGE:-nx-stack-probe}"
NANOS_HEAP_IMAGE="${NANOS_HEAP_IMAGE:-nx-heap-probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

run_probe() {
  local name="$1"
  local image="$2"
  local logfile="$OUTDIR/${name}.log"

  echo "[*] Nanos ${name}"
  timeout "${TIMEOUT_SECS}s" ops run "$image" \
    > "$logfile" 2>&1 || true

  if ! grep -q '^PROBE_OK$' "$logfile"; then
    echo "RESULT (${name}): FAIL (probe did not start)"
    return 1
  fi

  if [[ "$name" == "stack" ]]; then
    grep -q '^STACK_EXEC_BEGIN$' "$logfile" || { echo "RESULT (${name}): FAIL (begin marker missing)"; return 1; }
    if grep -q '^STACK_EXEC_ALLOWED$' "$logfile"; then
      echo "RESULT (${name}): FAIL (stack execution allowed)"
      return 1
    else
      echo "RESULT (${name}): PASS (stack execution blocked)"
      return 0
    fi
  else
    grep -q '^HEAP_EXEC_BEGIN$' "$logfile" || { echo "RESULT (${name}): FAIL (begin marker missing)"; return 1; }
    if grep -q '^HEAP_EXEC_ALLOWED$' "$logfile"; then
      echo "RESULT (${name}): FAIL (heap execution allowed)"
      return 1
    else
      echo "RESULT (${name}): PASS (heap execution blocked)"
      return 0
    fi
  fi
}

run_probe "stack" "$NANOS_STACK_IMAGE"
run_probe "heap" "$NANOS_HEAP_IMAGE"