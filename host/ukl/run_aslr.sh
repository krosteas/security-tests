#!/usr/bin/env bash
set -euo pipefail

RUNS="${RUNS:-10}"
UKL_KERNEL="${UKL_KERNEL:-arch/x86/boot/bzImage}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

# In UKL the probe is not passed as a separate runtime binary. It is linked
# into the kernel image during the UKL build, so booting the bzImage should
# directly execute the probe-enabled program.

count_unique() {
  local prefix="$1"
  local dir="$2"
  grep -h "^${prefix}=" "$dir"/run_*.log 2>/dev/null | sed 's/.*=//' | sort -u | wc -l
}

validate_logs() {
  local dir="$1"
  local valid=0
  for logfile in "$dir"/run_*.log; do
    if grep -q '^PROBE_OK$' "$logfile" \
      && grep -q '^MAIN=' "$logfile" \
      && grep -q '^STACK=' "$logfile" \
      && grep -q '^HEAP=' "$logfile"; then
      valid=$((valid + 1))
    else
      echo "[!] Invalid log: $logfile (probe output missing)"
    fi
  done
  echo "$valid"
}

run_mode() {
  local mode="$1"
  local appendline="$2"
  local outdir="ukl_aslr_${mode}"
  mkdir -p "$outdir"

  for i in $(seq 1 "$RUNS"); do
    local logfile="$outdir/run_${i}.log"
    echo "[*] UKL ${mode} run $i"
    timeout "${TIMEOUT_SECS}s" qemu-system-x86_64 \
      -m 512 \
      -smp 1 \
      -nographic \
      -kernel "$UKL_KERNEL" \
      -append "$appendline" \
      > "$logfile" 2>&1 || true
  done

  local valid_logs
  valid_logs=$(validate_logs "$outdir")
  local main_unique
  local stack_unique
  local heap_unique
  main_unique=$(count_unique MAIN "$outdir")
  stack_unique=$(count_unique STACK "$outdir")
  heap_unique=$(count_unique HEAP "$outdir")

  echo "--- UKL ${mode} ---"
  echo "Valid logs:              $valid_logs/$RUNS"
  echo "Unique MAIN addresses:  $main_unique"
  echo "Unique STACK addresses: $stack_unique"
  echo "Unique HEAP addresses:  $heap_unique"

  if [ "$valid_logs" -ne "$RUNS" ]; then
    echo "RESULT (${mode}): FAIL (probe did not run correctly in every UKL execution)"
    return 1
  fi

  if [ "$main_unique" -gt 1 ] || [ "$stack_unique" -gt 1 ] || [ "$heap_unique" -gt 1 ]; then
    echo "RESULT (${mode}): variation detected"
    return 0
  else
    echo "RESULT (${mode}): variation not detected"
    return 2
  fi
}

nokaslr_rc=0
default_rc=0

run_mode "nokaslr" "console=ttyS0 nokaslr" || nokaslr_rc=$?
echo
run_mode "default" "console=ttyS0" || default_rc=$?
echo

if [ "$nokaslr_rc" -eq 2 ] && [ "$default_rc" -eq 0 ]; then
  echo "RESULT: PASS (variation detected with default boot and not detected with nokaslr)"
else
  echo "RESULT: FAIL (UKL did not show the expected default-vs-nokaslr behaviour)"
  exit 1
fi
