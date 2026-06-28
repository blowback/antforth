\ value_to_tests.fth — Story 23.2: VALUE / TO (ANS Core-Ext named values).
\ Self-printing PASS:/FAIL: probe (the harness strips echoed source lines,
\ which begin with `."`, before matching the runtime verdicts). Covers
\ interpret-time get + set (AC1/AC2), compiled-store cumulative increment
\ (AC3), and a banked cross-bank round — define in bank 5, read AND write
\ from bank 0 (AC5). The not-a-VALUE -32 and undefined-name -13 THROWs
\ (AC4) are left UNCAUGHT below so the REPL handler runs and the harness
\ asserts the `error -32` / `error -13` lines (a CATCH is unnecessary —
\ to_verify restores slot 2 before raising, so -32 leaves no residue —
\ but uncaught also exercises the user-facing message table row).
\ Runs under iz-cpm-banking via `make test-repl-value-to`.

DECIMAL

\ --- AC1 / AC2: interpret-time get + set ---
42 VALUE VX
: _vt-getset ( -- )
  VX 42 = IF ." PASS: value-interpret-get" ELSE ." FAIL: value-interpret-get" THEN CR
  99 TO VX
  VX 99 = IF ." PASS: value-interpret-set" ELSE ." FAIL: value-interpret-set" THEN CR
;
_vt-getset

\ --- AC3: compile-time TO, cumulative (proves the store hits the cell) ---
0 TO VX
: VBUMP VX 1 + TO VX ;
VBUMP VBUMP VBUMP
: _vt-compile ( -- )
  VX 3 = IF ." PASS: value-compile-bump" ELSE ." FAIL: value-compile-bump" THEN CR
;
_vt-compile

\ --- AC5: banked cross-bank define / read / write ---
5 BANK! 7 VALUE VY 0 BANK!
: _vt-banked ( -- )
  VY 7 = IF ." PASS: value-banked-read" ELSE ." FAIL: value-banked-read" THEN CR
  8 TO VY
  VY 8 = IF ." PASS: value-banked-write" ELSE ." FAIL: value-banked-write" THEN CR
;
_vt-banked

\ --- AC4: not-a-VALUE -> -32 ; undefined name -> -13 (both UNCAUGHT) ---
42 CONSTANT VK
1 TO VK
1 TO VBUMP
5 TO NOSUCHVALUEZZ
