#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-unikraft_nx_runs}"
UNIKRAFT_STACK_KERNEL="${UNIKRAFT_STACK_KERNEL:-build/nx_stack-qemu-x86_64}"
UNIKRAFT_HEAP_KERNEL="${UNIKRAFT_HEAP_KERNEL:-build/nx_heap-qemu-x86_64}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

run_probe() {
  local name="$1"
  local kernel="$2"
  local logfile="$OUTDIR/${name}.log"

  echo "[*] Unikraft ${name}"
  timeout "${TIMEOUT_SECS}s" qemu-system-x86_64 \
    -m 256 \
    -smp 1 \
    -nographic \
    -kernel "$kernel" \
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

run_probe "stack" "$UNIKRAFT_STACK_KERNEL"
run_probe "heap" "$UNIKRAFT_HEAP_KERNEL"