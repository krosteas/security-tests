#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-../../results/rustyhermit/pie_relro}"
HERMIT_LOADER="${HERMIT_LOADER:-hermit-loader-x86_64}"
HERMIT_APP="${HERMIT_APP:-target/x86_64-unknown-hermit/debug/aslr_probe}"
mkdir -p "$OUTDIR"
LOGFILE="$OUTDIR/pie_relro.log"

check_one() {
  local label="$1"
  local target="$2"

  echo
  echo "[*] Checking $label: $target"

  [ -f "$target" ] || { echo "RESULT ($label): FAIL (target not found)"; return 1; }
  file "$target" | grep -q ELF || { echo "RESULT ($label): FAIL (not ELF)"; return 1; }

  local type relro bind_now pie_result relro_result
  type=$(readelf -h "$target" | awk '/Type:/ {print $2}')
  relro=$(readelf -lW "$target" | grep -c GNU_RELRO || true)
  bind_now=$(readelf -d "$target" 2>/dev/null | grep -c BIND_NOW || true)

  echo "ELF type: $type"
  echo "GNU_RELRO entries: $relro"
  echo "BIND_NOW entries: $bind_now"

  pie_result="FAIL"
  relro_result="FAIL"

  [ "$type" = "DYN" ] && pie_result="PASS"
  [ "$relro" -gt 0 ] && relro_result="PARTIAL"
  [ "$relro" -gt 0 ] && [ "$bind_now" -gt 0 ] && relro_result="FULL"

  echo "PIE: $pie_result"
  echo "RELRO: $relro_result"

  if [ "$pie_result" = "PASS" ] && [ "$relro_result" = "FULL" ]; then
    echo "RESULT ($label): PASS"
    return 0
  else
    echo "RESULT ($label): PARTIAL/FAIL"
    return 1
  fi
}

{
  echo "[*] RustyHermit PIE/RELRO check"

  loader_status=0
  app_status=0

  check_one "loader" "$HERMIT_LOADER" || loader_status=1
  check_one "app" "$HERMIT_APP" || app_status=1

  echo
  if [ "$loader_status" -eq 0 ] && [ "$app_status" -eq 0 ]; then
    echo "RESULT: PASS (loader and app have PIE + Full RELRO)"
  else
    echo "RESULT: PARTIAL/FAIL (loader or app missing PIE/Full RELRO)"
    exit 1
  fi
} | tee "$LOGFILE"