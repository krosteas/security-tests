#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-rustyhermit_nx_runs}"
HERMIT_LOADER="${HERMIT_LOADER:-hermit-loader-x86_64}"
HERMIT_STACK_APP="${HERMIT_STACK_APP:-target/x86_64-unknown-hermit/debug/nx_stack_probe}"
HERMIT_HEAP_APP="${HERMIT_HEAP_APP:-target/x86_64-unknown-hermit/debug/nx_heap_probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

run_probe() {
  local name="$1"
  local app="$2"
  local logfile="$OUTDIR/${name}.log"

  echo "[*] RustyHermit ${name}"
  timeout "${TIMEOUT_SECS}s" qemu-system-x86_64 \
    -display none \
    -smp 1 \
    -m 64M \
    -serial stdio \
    -kernel "$HERMIT_LOADER" \
    -initrd "$app" \
    -cpu qemu64,apic,fsgsbase,rdtscp,xsave,fxsr \
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

run_probe "stack" "$HERMIT_STACK_APP"
run_probe "heap" "$HERMIT_HEAP_APP"