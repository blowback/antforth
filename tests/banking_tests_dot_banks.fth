\ === Story 23.8 — bank-switching probes (isolated fixture) ================
\
\ Run by `make test-repl-banking-isolated-dot-banks` in a FRESH banking
\ emulator. These probes switch slot 2 into a non-zero bank, so they are kept
\ OUT of the main in-suite tests/banking_tests.fth: once kernel growth pushes
\ bank-0 HERE up, an in-suite colon body lands above $8000, and switching into
\ a foreign bank while the caller IP sits in that window portal-aliases and
\ trips the F1-unguardable straddle halt (feedback_banking_probe_straddle_halt,
\ ADR 19.5 DR-1). In a fresh emulator instance bank-0 HERE is low, so the
\ bodies stay below $8000 and the switch is layout-immune regardless of how
\ this file is structured. Migrated from banking_tests.fth (Story 23.8,
\ discharging AI-22-5); the recipe greps the same PASS:/sentinel witnesses.

DECIMAL

\ --- Probe 7: 1 BANK! BANK@ round-trip (was banking_tests.fth _probe-7) -----
\ Switches into bank 1 inside the colon body, then restores bank 0 before
\ BANKS-CLEAR (leaving current_bank = 1 over a clear would point HERE into a
\ zero-init slot and corrupt the next REPL definition). BANKS-CLEAR first: the
\ boot list already holds $22 and $35, and +BANK refuses a page already listed.
: _probe-7 ( -- )
  BANKS-CLEAR $22 +BANK $35 +BANK
  1 BANK! BANK@ DUP 1 = IF
    ." PASS: bank-store-round-trip-1 — 1 BANK! round-trips after $22+$35 +BANK"
    DROP
  ELSE
    ." FAIL: bank-store-round-trip-1 — BANK@ returned " .
  THEN
  0 BANK!
  BANKS-CLEAR
  CR
;
_probe-7

\ --- .BANKS probes X / Y / Z / M1 / W (was banking_tests.fth:368-467) -------
\ `.BANKS` reads (IY+bank_count) + (IY+current_bank) + walks active_pages[];
\ no MMU port operations. Sentinel-and-grep: each probe prints
\ `---dot-banks-probe-<name>-start---` + `.BANKS` + `---..-end---`; the recipe
\ grep-asserts on the content between sentinels. Setup (BANKS-CLEAR + $22 and
\ $35..$3F +BANK) is inlined at each site: 12 entries (logical banks 0..11), the
\ boot page list. Bank 0 (row 0) is the kernel dictionary (used/free non-zero,
\ grows with compiled state); banks 1..11 are empty slot-2 windows (used=0,
\ free=16216 below the $BF58 banked ceiling).
\ Totals SUM all 12 rows, so the deterministic invariant is computed from the
\ live row-0 values in the recipe, not from a fixed literal. Kept at INTERPRET
\ level (no colon wrappers) to match the original de-coloned form.

\ Probe X — header + banked-row shape + totals self-consistency.
BANKS-CLEAR  $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK
$3A +BANK $3B +BANK $3C +BANK $3D +BANK $3E +BANK $3F +BANK
." ---dot-banks-probe-x-start---" CR
.BANKS
." ---dot-banks-probe-x-end---" CR

\ Probe Y — current-bank marker tracking: `*` on row 0 at boot, row 1 after
\ `1 BANK!`, back to row 0 after `0 BANK!`. Each `BANK! .BANKS` kept on ONE
\ input line so the switch and the print run in a single INTERPRET pass.
BANKS-CLEAR  $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK
$3A +BANK $3B +BANK $3C +BANK $3D +BANK $3E +BANK $3F +BANK
." ---dot-banks-probe-y-start---" CR
.BANKS
." ---dot-banks-probe-y-mid1---" CR
1 BANK! .BANKS
." ---dot-banks-probe-y-mid2---" CR
0 BANK! .BANKS
." ---dot-banks-probe-y-end---" CR

\ Probe Z — empty-banked-row guard + bank-0 exemption. Empty banked windows
\ read used=0 / free=16216; bank 0 (row 0) is EXEMPT (kernel-region free).
BANKS-CLEAR  $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK
$3A +BANK $3B +BANK $3C +BANK $3D +BANK $3E +BANK $3F +BANK
." ---dot-banks-probe-z-start---" CR
.BANKS
." ---dot-banks-probe-z-end---" CR

\ Probe M1 — BASE-independence guard. Byte-count columns are FORCED decimal
\ regardless of BASE, so an empty banked row still reads `16216` in HEX mode.
BANKS-CLEAR  $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK
$3A +BANK $3B +BANK $3C +BANK $3D +BANK $3E +BANK $3F +BANK
." ---dot-banks-probe-m1-start---" CR
HEX .BANKS DECIMAL
." ---dot-banks-probe-m1-end---" CR

\ Probe W — totals row + summary rows (bank-0-inclusive totals invariant +
\ BANKED-WORDS / STUB-BYTES rows, both 0 in this setup).
BANKS-CLEAR  $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK
$3A +BANK $3B +BANK $3C +BANK $3D +BANK $3E +BANK $3F +BANK
." ---dot-banks-probe-w-start---" CR
.BANKS
." ---dot-banks-probe-w-end---" CR

0 BANK!
BANKS-CLEAR
." ---dot-banks-suite-end---" CR
BYE
