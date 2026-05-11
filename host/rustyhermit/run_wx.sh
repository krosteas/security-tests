#!/usr/bin/env bash
set -euo pipefail

HERMIT_LOADER="${HERMIT_LOADER:-hermit-loader-x86_64}"
HERMIT_APP="${HERMIT_APP:-target/x86_64-unknown-hermit/debug/aslr_probe}"

OUTDIR="${OUTDIR:-../../results/rustyhermit/wx}"
mkdir -p "$OUTDIR"

LOGFILE="$OUTDIR/wx.log"

audit_elf() {
  local label="$1"
  local elf="$2"

  echo
  echo "[*] Auditing $label"
  echo "[*] Target ELF: $elf"

  if [ ! -f "$elf" ]; then
    echo "RESULT ($label): FAIL (ELF not found)"
    return 1
  fi

  if ! file "$elf" | grep -q "ELF"; then
    echo "RESULT ($label): FAIL (target is not an ELF file)"
    return 1
  fi

  local load_wx_count
  local section_wx_count
  local exec_stack_count

  load_wx_count=$(
    readelf -lW "$elf" | awk '
      /LOAD/ {
        if ($0 ~ /W/ && $0 ~ /E/) c++
      }
      END { print c+0 }
    '
  )

  section_wx_count=$(
    readelf -SW "$elf" | awk '
      /^\s*\[/ {
        if ($0 ~ /W/ && $0 ~ /X/) c++
      }
      END { print c+0 }
    '
  )

  exec_stack_count=$(
    readelf -lW "$elf" | awk '
      /GNU_STACK/ {
        if ($0 ~ /E/) c++
      }
      END { print c+0 }
    '
  )

  echo "Writable+Executable LOAD segments: $load_wx_count"
  echo "Writable+Executable sections:      $section_wx_count"
  echo "Executable GNU_STACK headers:      $exec_stack_count"

  if [ "$load_wx_count" -gt 0 ] || [ "$section_wx_count" -gt 0 ] || [ "$exec_stack_count" -gt 0 ]; then
    echo "RESULT ($label): FAIL (W+X memory layout detected)"
    return 1
  else
    echo "RESULT ($label): PASS (no W+X layout detected)"
    return 0
  fi
}

{
  echo "[*] RustyHermit W^X check"

  loader_result=0
  app_result=0

  audit_elf "loader" "$HERMIT_LOADER" || loader_result=1
  audit_elf "app" "$HERMIT_APP" || app_result=1

  echo
  if [ "$loader_result" -eq 0 ] && [ "$app_result" -eq 0 ]; then
    echo "RESULT: PASS (no W+X layout detected in loader or app)"
  else
    echo "RESULT: FAIL (W+X issue detected in loader or app)"
    exit 1
  fi
} | tee "$LOGFILE"