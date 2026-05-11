#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-../../results/nanos/pie_relro}"
TARGET="${NANOS_ELF:-build/aslr_probe}"
mkdir -p "$OUTDIR"
LOGFILE="$OUTDIR/pie_relro.log"

{
  echo "[*] Nanos PIE/RELRO check"
  echo "[*] Target guest ELF: $TARGET"
  echo "[*] Note: checks packaged guest ELF, not final ops image."

  [ -f "$TARGET" ] || { echo "RESULT: FAIL (target not found)"; exit 1; }
  file "$TARGET" | grep -q ELF || { echo "RESULT: FAIL (not ELF)"; exit 1; }

  type=$(readelf -h "$TARGET" | awk '/Type:/ {print $2}')
  relro=$(readelf -lW "$TARGET" | grep -c GNU_RELRO || true)
  bind_now=$(readelf -d "$TARGET" 2>/dev/null | grep -c BIND_NOW || true)

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
    echo "RESULT: PASS (PIE + Full RELRO)"
  else
    echo "RESULT: PARTIAL/FAIL (missing PIE and/or Full RELRO)"
    exit 1
  fi
} | tee "$LOGFILE"