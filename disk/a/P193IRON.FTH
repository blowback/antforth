\ Story 19.3 — hardware iron-spike layout test (Dev-Pass 2026-05-20)
\
\ Distinguishes "iz-cpm-banking layout-sensitivity quirk" from "real
\ kernel defect" at the +33 B Story 19.3 kernel size (26759 B).
\
\ Under iz-cpm-banking at this kernel size, iron-spike running INSIDE
\ tests/banking_tests.fth HANGS after emitting the success literal —
\ never reaching the closing ---iron-spike-end--- sentinel (boundary
\ 26748→26749 B; same defect class as Story 19.2 H5 / antforth.asm:
\ 198..213). Hardware test: INCLUDE this file at the MicroBeast REPL
\ and observe whether BOTH the success literal AND the end sentinel
\ appear.
\
\ Expected output (between matching start/end sentinels):
\   ---iron-spike-19.3-start---
\   iron-spike-sentinel-12345-returned
\   ---iron-spike-19.3-end---
\
\ Interpretation:
\   - Both sentinels appear (incl. ---iron-spike-19.3-end---):
\     hardware can run the +33 B layout. iz-cpm-banking has an
\     emulator-only fragility (same defect class as the documented
\     project_phase4_banking_off_emulator gap). Story 19.3 ships
\     with hardware as the load-bearing verdict.
\
\   - Success literal appears but ---iron-spike-19.3-end--- does NOT:
\     hardware also hangs. Real kernel defect in the sentinel-
\     trampoline EXIT chain (Story 18.2 mechanism) — not an emulator
\     quirk. Story 19.3 + Story 18.2 trampoline need root-cause
\     investigation before either can ship.
\
\   - Nothing appears (kernel halted earlier): unexpected; check
\     INCLUDE path, BANKS-CLEAR / +BANK / 5 BANK! setup.
\
\ Note: this file does NOT include the test-repl-banking probes that
\ run BEFORE iron-spike in tests/banking_tests.fth. On the emulator,
\ those preceding probes (specifically the lines 540..650 region) are
\ what trip the +33 B layout sensitivity — iron-spike alone PASSes
\ on the emulator at +33 B too. So a hardware PASS here is necessary
\ but NOT sufficient to declare "emulator quirk"; a follow-up test
\ would replay the relevant preceding probe state to fully discriminate.
\ See dev-pass notes in _bmad-output/implementation-artifacts/19-3-*.md.

DECIMAL
: _iron-spike-19-3-test ( -- )
  DECIMAL
  ." ---iron-spike-19.3-start---" CR
  BANKS-CLEAR
  $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK
  5 BANK!
  HERE                            \ ( start-addr )
  ['] NEGATE HERE 3 MOVE  3 ALLOT \ JP DOCOL prefix at HERE..HERE+2
  ['] LIT ,                       \ w_LIT_cf at HERE+3..HERE+4
  12345 ,                         \ sentinel at HERE+5..HERE+6
  ['] EXIT ,                      \ w_EXIT_cf at HERE+7..HERE+8
  0 BANK!
  5 BANK!
  EXECUTE                         \ ( 12345 )
  12345 = IF
    ." iron-spike-sentinel-12345-returned" CR
  ELSE
    ." FAIL: iron-spike sentinel mismatch" CR
  THEN
  ." ---iron-spike-19.3-end---" CR
  0 BANK!
  BANKS-CLEAR
;
_iron-spike-19-3-test
