#!/bin/sh
# Story 19.5.0 DR-1 — driver for tests/straddle_repro.fth.in.
#
# Sweeps the dictionary-position knob (@PAD@ ALLOT) and, optionally, a
# kernel-size knob (DS K inserted before xbank_restore — anchor
# migrated from the retired cross_bank_return at Story 19.5.2 — which
# shifts kernel_end and therefore the dictionary base by +K), then
# records which output markers survive. Under the portal-window
# aliasing mechanism the verdict depends ONLY on the absolute address
# of _victim's body vs $8000, so the PASS/HANG transition pad value
# must shift by exactly -K when the kernel grows by +K.
#
# Usage:
#   tests/straddle_repro_sweep.sh K PAD1 PAD2 ...
# e.g.
#   tests/straddle_repro_sweep.sh 0   5500 5600 5650 5700
#   tests/straddle_repro_sweep.sh 128 5372 5472 5522 5572
#
# Output columns: K pad here0(dec) body-start body-end markers
#   here0       = HERE before the shim (boot dictionary base)
#   body-start  = HERE after shim (≈ _victim header position)
#   body-end    = HERE after _victim's definition
#   markers     = which of m1..m5 + survived were emitted
#
# Kernel edit is working-tree-only and restored on exit (AC5).

set -u

K="${1:?usage: $0 kernel-pad-K pad-values...}"
shift

SRC=src/banking.asm
BAK=/tmp/banking.asm.straddle-bak
COM=/tmp/straddle_antforth.com
FTH=/tmp/straddle_repro.fth
OUT=/tmp/straddle_out.txt

cp "$SRC" "$BAK"
trap 'cp "$BAK" "$SRC"' EXIT INT TERM

if [ "$K" -gt 0 ]; then
  awk -v n="$K" '/^xbank_restore:/{printf "        DS      %s              ; STRADDLE-SWEEP KNOB (19.5.0)\n", n} {print}' \
      "$BAK" > "$SRC"
  # Fail loudly if the anchor vanished (e.g. a future story renames or
  # moves xbank_restore) — a silent no-match would sweep the UNMODIFIED
  # kernel at every K and report a meaningless table.
  cmp -s "$BAK" "$SRC" && {
    echo "ANCHOR-NOT-FOUND: '^xbank_restore:' in $SRC — knob not inserted; update the anchor" >&2
    exit 1; }
fi
( cd src && sjasmplus --fullpath --nologo antforth.asm --raw="$COM" >/dev/null 2>&1 ) || {
  echo "BUILD-ERROR" >&2; exit 1; }

printf '%-5s %-6s %-6s %-7s %-7s %s\n' K pad here0 bstart bend markers

for PAD in "$@"; do
  sed "s/@PAD@/$PAD/" tests/straddle_repro.fth.in | sed 's/$/\r/' > "$FTH"
  printf 'BYE\r\n' >> "$FTH"
  timeout 15 iz-cpm-banking --disk-a disk/a --disk-b disk/b "$COM" < "$FTH" > "$OUT" 2>/dev/null
  CLEAN=$(tr -d '\r' < "$OUT")
  # The three HERE U. outputs, in order.
  set -- $(printf '%s\n' "$CLEAN" | grep -a '^[0-9][0-9]* $' | awk '{print $1}')
  H0="${1:-?}"; H1="${2:-?}"; H2="${3:-?}"
  MARKS=""
  for M in m1 m2 m3 m4 m5; do
    printf '%s\n' "$CLEAN" | grep -aq "^\[$M\]" && MARKS="$MARKS $M"
  done
  printf '%s\n' "$CLEAN" | grep -aq '^survived' && MARKS="$MARKS survived"
  # Story 19.5.1 F1 witness: BANK!'s portal-window guard surfaces THROW
  # -273 ("bank switch from banked code") when the caller IP (the cell
  # after the BANK! xt) sits at >= $8000. Recorded as a pseudo-marker so
  # make test-straddle-regression can assert the GUARD configuration
  # from the marker table alone. Matched as the uncaught-THROW printer's
  # 'error -273' line (src/exception.asm str_throw_prefix + signed code),
  # not a bare '-273' substring — corruption-class garbage output that
  # happens to contain '-273' bytes must not set the marker in rows
  # whose assertion requires its absence (e.g. the HANG config).
  printf '%s\n' "$CLEAN" | grep -aq 'error -273' && MARKS="$MARKS e273"
  [ -z "$MARKS" ] && MARKS=" none"
  printf '%-5s %-6s %-6s %-7s %-7s %s\n' "$K" "$PAD" "$H0" "$H1" "$H2" "${MARKS# }"
done

cp "$BAK" "$SRC"
trap - EXIT INT TERM
