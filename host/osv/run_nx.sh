#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-osv_nx_runs}"
OSV_KERNEL="${OSV_KERNEL:-build/last/loader-stripped.elf}"
OSV_IMAGE="${OSV_IMAGE:-build/last/usr.img}"
OSV_STACK_PROBE_PATH="${OSV_STACK_PROBE_PATH:-/nx_stack_probe}"
OSV_HEAP_PROBE_PATH="${OSV_HEAP_PROBE_PATH:-/nx_heap_probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

run_probe() {
  local name="$1"
  local probe_path="$2"
  local logfile="$OUTDIR/${name}.log"

  echo "[*] OSv ${name}"
  timeout "${TIMEOUT_SECS}s" qemu-system-x86_64 \
    -m 512 \
    -smp 1 \
    -nographic \
    -kernel "$OSV_KERNEL" \
    -drive "file=${OSV_IMAGE},if=virtio,format=raw" \
    -append "-- ${probe_path}" \
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

run_probe "stack" "$OSV_STACK_PROBE_PATH"
run_probe "heap" "$OSV_HEAP_PROBE_PATH"