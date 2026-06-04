#!/bin/sh
# Story 19.5.0 (DR-1) — trampoline layout-fragility reproducer + sweep driver.
#
# Reproduces the Story-19.2-H5 / Story-19.3 hang class: the full
# banking_tests.fth probe sequence with the PRE-19.3 configuration
# (_iron-spike-test invoked INLINE after its definition) hangs/dies under
# iz-cpm-banking at specific kernel layouts, while the shipped suite
# (iron-spike isolated in its own subprocess) passes at the same layout.
#
# Usage:
#   tests/layout_fragility_sweep.sh before 0 1 2 4 8 16 17 32 33 64 128
#   tests/layout_fragility_sweep.sh after  0 1 2 4 8 16 32 64 128
#
# Knob positions (controlled layout shift, per Story 19.5.0 Sub-1.1/1.2):
#   before — DS N inserted immediately BEFORE the cross_bank_return label:
#            shifts cross_bank_return (and everything after it, incl.
#            kernel_end and the runtime dictionary base) relative to all
#            EARLIER kernel code/threads (EXIT_CODE, banking DEFWORD
#            threads below the trampoline).
#   after  — DS N inserted immediately AFTER the trampoline body:
#            shifts kernel_end / dictionary base relative to
#            cross_bank_return, which stays put relative to earlier code.
#
# Per N the driver records: kernel size, cross_bank_return / kernel_end
# addresses (from the sjasmplus --sym dump), verdict, and the last
# probe sentinel emitted before death.
#
# Verdict classification:
#   PASS — full sequence ran: iron-spike end-sentinel AND probe-18.2-a
#          end-sentinel AND final-probe (19.3-h) end-sentinel present,
#          no FAIL: line.
#   HANG — output truncated (emulator hung until timeout, exited early
#          on a wild jump, or died mid-probe). Last sentinel column
#          says where.
#   FAIL — sequence completed but a probe reported FAIL:.
#
# The kernel source edit is working-tree-only: banking.asm is backed up
# and restored on exit (AC5 zero-binary-delta discipline). Run from the
# repo root.

set -u

POS="${1:?usage: $0 before|after N...}"
shift

SRC=src/banking.asm
BAK=/tmp/banking.asm.sweep-bak
INPUT=/tmp/sweep_input.txt
OUT=/tmp/sweep_out.txt
SYM=/tmp/sweep.sym
COM=/tmp/sweep_antforth.com

case "$POS" in
  before) ANCHOR='^cross_bank_return:' ; MODE=insert_before ;;
  after)  ANCHOR='transfer control; no NEXT here' ; MODE=insert_after ;;
  *) echo "knob position must be 'before' or 'after'" >&2; exit 2 ;;
esac

# Build the inline-iron-spike input stream (pre-19.3 configuration):
# 16.3-probe.fth + banking_tests.fth with `_iron-spike-test` re-inserted
# directly after its definition's closing `;`, + BYE.
{
  sed 's/$/\r/' _bmad-output/implementation-artifacts/16.3-probe.fth
  awk '{print} /^: _iron-spike-test/{def=1} def && /^;/{print "_iron-spike-test"; def=0}' \
      tests/banking_tests.fth | sed 's/$/\r/'
  printf 'BYE\r\n'
} > "$INPUT"
# Fail loudly if the re-insert never fired (e.g. _iron-spike-test gets
# reformatted to a single-line definition, which the `def && /^;/` rule
# can't see) — otherwise the sweep silently runs the SHIPPED (isolated)
# configuration and every layout reports PASS.
grep -aq '^_iron-spike-test' "$INPUT" || {
  echo "ANCHOR-NOT-FOUND: inline _iron-spike-test invocation not inserted into $INPUT — update the awk re-insert rule" >&2
  exit 1; }

cp "$SRC" "$BAK"
trap 'cp "$BAK" "$SRC"' EXIT INT TERM

printf '%-6s %-6s %-7s %-7s %-7s %-6s %s\n' POS N size xbr kend verdict last-sentinel

for N in "$@"; do
  if [ "$MODE" = insert_before ]; then
    awk -v n="$N" -v a="$ANCHOR" '$0 ~ a {printf "        DS      %s              ; LAYOUT-SWEEP KNOB (19.5.0)\n", n} {print}' \
        "$BAK" > "$SRC"
  else
    awk -v n="$N" -v a="$ANCHOR" '{print} $0 ~ a {printf "        DS      %s              ; LAYOUT-SWEEP KNOB (19.5.0)\n", n}' \
        "$BAK" > "$SRC"
  fi
  # Fail loudly if the anchor vanished (e.g. 19.5.2 retires the
  # cross_bank_return trampoline body) — a silent no-match would sweep
  # the UNMODIFIED kernel at every N and report a meaningless table.
  cmp -s "$BAK" "$SRC" && {
    echo "ANCHOR-NOT-FOUND: '$ANCHOR' in $SRC — knob not inserted; update the anchor" >&2
    exit 1; }

  ( cd src && sjasmplus --fullpath --nologo antforth.asm --raw="$COM" --sym="$SYM" >/dev/null 2>&1 ) || {
    printf '%-6s %-6s BUILD-ERROR\n' "$POS" "$N"; continue; }

  SIZE=$(wc -c < "$COM" | tr -d ' ')
  XBR=$(awk -F'0x' '/^cross_bank_return: /{print $2}' "$SYM")
  KEND=$(awk -F'0x' '/^kernel_end: /{print $2}' "$SYM")

  timeout 30 iz-cpm-banking --disk-a disk/a --disk-b disk/b "$COM" < "$INPUT" > "$OUT" 2>/dev/null
  CLEAN=$(tr -d '\r' < "$OUT")

  LAST=$(printf '%s\n' "$CLEAN" | grep -ao -- '---[a-z0-9.-]*---' | tail -1)
  if printf '%s\n' "$CLEAN" | grep -aq -- '---iron-spike-end---' \
     && printf '%s\n' "$CLEAN" | grep -aq -- '---probe-18.2-a-end---' \
     && printf '%s\n' "$CLEAN" | grep -aq -- '---probe-19.3-h-end---'; then
    if printf '%s\n' "$CLEAN" | grep -aq 'FAIL:'; then VERDICT=FAIL; else VERDICT=PASS; fi
  else
    VERDICT=HANG
  fi

  printf '%-6s %-6s %-7s %-7s %-7s %-6s %s\n' "$POS" "$N" "$SIZE" "${XBR:-?}" "${KEND:-?}" "$VERDICT" "${LAST:-none}"
done

cp "$BAK" "$SRC"
trap - EXIT INT TERM
# Rebuild the pristine kernel so build/antforth.com matches the tree.
( cd src && sjasmplus --fullpath --nologo antforth.asm --raw=../build/antforth.com >/dev/null 2>&1 )
