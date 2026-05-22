\ Story 19.3 — bank-0 hardware-smoke probes (Q4-γ; AC1 + AC2 + AC6 + FR-P4-25)
\ INCLUDED P193BK0.FTH at the MicroBeast REPL after a fresh boot.
\ Expected PASS literals (between matching start/end sentinels):
\   probe-19.3-a-pass-bank-0-create-byte-identical
\   probe-19.3-b-pass-bank-0-create-does-regression
\   probe-19.3-c-pass-bank-0-no-stub-xt-cell-flag
\   probe-19.3-h-pass-bank-0-state-integrity-after-create-throw-16
\
\ Hardware-smoke companion to the emulator probes in
\ tests/banking_tests.fth (Story 19.3 bank-0 section after Probe-19.2-J).
\ Surface: PASS on real MicroBeast (load-bearing per Story 19.3 AC7 +
\ feedback_post_hw_smoke_steps_at_review STRONG rule).

DECIMAL

\ === Probe-19.3-A — bank-0 CREATE byte-identical sanity (AC1/AC3/AC6-A)
VARIABLE _p193a-val
VARIABLE _p193a-bank
VARIABLE _p193a-pass
: _p193a-check
  -1 _p193a-pass !
  _p193a-val @ 42 = INVERT IF 0 _p193a-pass !
    ." value-not-42 " THEN
  _p193a-bank @ -1 = INVERT IF 0 _p193a-pass !
    ." bank-of-not-minus-1 " THEN
  _p193a-pass @ IF
    ." probe-19.3-a-pass-bank-0-create-byte-identical"
  ELSE
    ." FAIL: probe-19.3-a bank-0 CREATE sanity failed"
  THEN CR ;
." ---probe-19.3-a-start---" CR
CREATE _p193a-c0 42 ,
_p193a-c0 @ _p193a-val !
' _p193a-c0 BANK-OF _p193a-bank !
_p193a-check
." ---probe-19.3-a-end---" CR

\ === Probe-19.3-B — bank-0 CREATE/DOES> regression sanity (AC2/AC6-B)
VARIABLE _p193b-val
VARIABLE _p193b-pass
: _p193b-array CREATE CELLS ALLOT DOES> SWAP CELLS + ;
: _p193b-check
  -1 _p193b-pass !
  _p193b-val @ 13 = INVERT IF 0 _p193b-pass !
    ." doesify-not-13 " THEN
  _p193b-pass @ IF
    ." probe-19.3-b-pass-bank-0-create-does-regression"
  ELSE
    ." FAIL: probe-19.3-b bank-0 CREATE/DOES> regression failed"
  THEN CR ;
." ---probe-19.3-b-start---" CR
4 _p193b-array _p193b-arr
13 0 _p193b-arr !
0 _p193b-arr @ _p193b-val !
_p193b-check
." ---probe-19.3-b-end---" CR

\ === Probe-19.3-C — bank-0 entry has NO F_HAS_STUB_XT_CELL flag (AC1/AC6-C)
VARIABLE _p193c-flag
VARIABLE _p193c-pass
: _p193c-check
  -1 _p193c-pass !
  _p193c-flag @ 0= INVERT IF 0 _p193c-pass !
    ." stub-xt-cell-flag-set " THEN
  _p193c-pass @ IF
    ." probe-19.3-c-pass-bank-0-no-stub-xt-cell-flag"
  ELSE
    ." FAIL: probe-19.3-c bank-0 entry has unexpected F_HAS_STUB_XT_CELL"
  THEN CR ;
." ---probe-19.3-c-start---" CR
CREATE _p193c-c0
LATEST @ 2 + C@ $20 AND _p193c-flag !
_p193c-check
." ---probe-19.3-c-end---" CR

\ === Probe-19.3-H — bank-0 NFR-P4-8 state integrity after CREATE -16 THROW
VARIABLE _p193h-here-pre
VARIABLE _p193h-here-post
VARIABLE _p193h-latest-pre
VARIABLE _p193h-latest-post
VARIABLE _p193h-throw-code
VARIABLE _p193h-good-val
VARIABLE _p193h-pass
: _p193h-empty S" CREATE" EVALUATE ;
: _p193h-check
  -1 _p193h-pass !
  _p193h-throw-code @ -16 = INVERT IF 0 _p193h-pass !
    ." throw-not-minus-16 " THEN
  _p193h-here-pre @ _p193h-here-post @ = INVERT IF 0 _p193h-pass !
    ." here-changed " THEN
  _p193h-latest-pre @ _p193h-latest-post @ = INVERT IF 0 _p193h-pass !
    ." latest-changed " THEN
  _p193h-good-val @ 99 = INVERT IF 0 _p193h-pass !
    ." good-not-99 " THEN
  _p193h-pass @ IF
    ." probe-19.3-h-pass-bank-0-state-integrity-after-create-throw-16"
  ELSE
    ." FAIL: probe-19.3-h bank-0 state-integrity violated"
  THEN CR ;
." ---probe-19.3-h-start---" CR
HERE _p193h-here-pre !
LATEST @ _p193h-latest-pre !
' _p193h-empty CATCH _p193h-throw-code !
HERE _p193h-here-post !
LATEST @ _p193h-latest-post !
CREATE _p193h-good 99 ,
_p193h-good @ _p193h-good-val !
_p193h-check
." ---probe-19.3-h-end---" CR
