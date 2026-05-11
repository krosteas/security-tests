#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-../../results/rustyhermit/nx}"
HERMIT_LOADER="${HERMIT_LOADER:-hermit-loader-x86_64}"
HERMIT_STACK_APP="${HERMIT_STACK_APP:-target/x86_64-unknown-hermit/debug/nx_stack_unsafe_probe}"
HERMIT_HEAP_APP="${HERMIT_HEAP_APP:-target/x86_64-unknown-hermit/debug/nx_heap_unsafe_probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

run_probe() {
  local name="$1"
  local app="$2"
  local logfile="$OUTDIR/${name}.log"

  echo "[*] RustyHermit unsafe NX ${name} probe"
  echo "[*] App: $app"

  if [ ! -f "$app" ]; then
    echo "RESULT (${name}): FAIL (probe binary not found)"
    return 1
  fi

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
    if ! grep -q '^STACK_EXEC_BEGIN$' "$logfile"; then
      echo "RESULT (${name}): FAIL (begin marker missing)"
      return 1
    fi

    if grep -q '^STACK_EXEC_ALLOWED$' "$logfile"; then
      echo "RESULT (${name}): FAIL (stack execution allowed)"
      return 1
    else
      echo "RESULT (${name}): PASS (stack execution blocked)"
      return 0
    fi
  fi

  if [[ "$name" == "heap" ]]; then
    if ! grep -q '^HEAP_EXEC_BEGIN$' "$logfile"; then
      echo "RESULT (${name}): FAIL (begin marker missing)"
      return 1
    fi

    if grep -q '^HEAP_EXEC_ALLOWED$' "$logfile"; then
      echo "RESULT (${name}): FAIL (heap execution allowed)"
      return 1
    else
      echo "RESULT (${name}): PASS (heap execution blocked)"
      return 0
    fi
  fi
}

stack_result=0
heap_result=0

run_probe "stack" "$HERMIT_STACK_APP" || stack_result=1
run_probe "heap" "$HERMIT_HEAP_APP" || heap_result=1

echo

if [ "$stack_result" -eq 0 ] && [ "$heap_result" -eq 0 ]; then
  echo "RESULT: PASS (unsafe stack/heap execution blocked)"
else
  echo "RESULT: FAIL (unsafe stack/heap execution allowed or probe invalid)"
  exit 1
fi