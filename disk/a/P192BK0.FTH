\ Story 19.2 — bank-0 hardware-smoke probes (Q4-γ; AC7-a + AC6 + Q3-β)
\ INCLUDED P192BK0.FTH at the MicroBeast REPL after a fresh boot.
\ Expected PASS literals (between matching start/end sentinels):
\   probe-19.2-a-pass-bank-0-latest-and-tick-differ
\   probe-19.2-b-pass-bank-0-no-stub-on-semicolon
\   probe-19.2-c-pass-bank-0-no-stub-xt-cell-flag
\   probe-19.2-h-pass-bank-0-subsequent-colon-after-throw

VARIABLE _p19-2a-latest-cell
VARIABLE _p19-2a-tick-cfa
VARIABLE _p19-2a-pass
: _p19-2a-start ." ---probe-19.2-a-start---" CR ;
: _p19-2a-end   ." ---probe-19.2-a-end---"   CR ;
: _p19-2a-check
  -1 _p19-2a-pass !
  _p19-2a-latest-cell @ 0= IF 0 _p19-2a-pass ! ." latest-zero " THEN
  _p19-2a-tick-cfa @ 0= IF 0 _p19-2a-pass ! ." tick-zero " THEN
  _p19-2a-tick-cfa @ _p19-2a-latest-cell @ = IF 0 _p19-2a-pass !
    ." latest-equals-tick-but-should-differ-for-bank-0 " THEN
  _p19-2a-pass @ IF
    ." probe-19.2-a-pass-bank-0-latest-and-tick-differ"
  ELSE
    ." FAIL: probe-19.2-a bank-0 LATEST/tick differ test failed"
  THEN CR ;
_p19-2a-start
: _p19-2a-target 42 ;
LATEST @ _p19-2a-latest-cell !
' _p19-2a-target _p19-2a-tick-cfa !
_p19-2a-check
_p19-2a-end

VARIABLE _p19-2b-stub1
VARIABLE _p19-2b-stub2
VARIABLE _p19-2b-pass
: _p19-2b-start ." ---probe-19.2-b-start---" CR ;
: _p19-2b-end   ." ---probe-19.2-b-end---"   CR ;
: _p19-2b-check
  -1 _p19-2b-pass !
  _p19-2b-stub2 @ _p19-2b-stub1 @ - 4 = INVERT IF 0 _p19-2b-pass !
    ." stride-not-4 " THEN
  _p19-2b-pass @ IF
    ." probe-19.2-b-pass-bank-0-no-stub-on-semicolon"
  ELSE
    ." FAIL: probe-19.2-b bank-0 allocated stub on `;` (stride != 4)"
  THEN CR ;
_p19-2b-start
0 -1 (stub-allocate) _p19-2b-stub1 !
: _p19-2b-target 7 ;
0 -1 (stub-allocate) _p19-2b-stub2 !
_p19-2b-check
_p19-2b-end

VARIABLE _p19-2c-cf
VARIABLE _p19-2c-pass
: _p19-2c-start ." ---probe-19.2-c-start---" CR ;
: _p19-2c-end   ." ---probe-19.2-c-end---"   CR ;
: _p19-2c-check
  -1 _p19-2c-pass !
  _p19-2c-cf @ $20 AND IF 0 _p19-2c-pass ! ." cf-flag-set " THEN
  _p19-2c-pass @ IF
    ." probe-19.2-c-pass-bank-0-no-stub-xt-cell-flag"
  ELSE
    ." FAIL: probe-19.2-c bank-0 has F_HAS_STUB_XT_CELL flag set"
  THEN CR ;
_p19-2c-start
: _p19-2c-target 13 ;
LATEST @ 2 + C@ _p19-2c-cf !
_p19-2c-check
_p19-2c-end

VARIABLE _p19-2h-throw-code
VARIABLE _p19-2h-good-xt
VARIABLE _p19-2h-good-latest
VARIABLE _p19-2h-pass
: _p19-2h-throw-13 -13 THROW ;
: _p19-2h-start ." ---probe-19.2-h-start---" CR ;
: _p19-2h-end   ." ---probe-19.2-h-end---"   CR ;
: _p19-2h-check
  -1 _p19-2h-pass !
  _p19-2h-throw-code @ -13 = INVERT IF 0 _p19-2h-pass !
    ." throw-code-not-minus-13 " THEN
  _p19-2h-good-xt @ 0= IF 0 _p19-2h-pass ! ." good-xt-zero " THEN
  _p19-2h-good-latest @ 0= IF 0 _p19-2h-pass ! ." good-latest-zero " THEN
  _p19-2h-pass @ IF
    ." probe-19.2-h-pass-bank-0-subsequent-colon-after-throw"
  ELSE
    ." FAIL: probe-19.2-h bank-0 subsequent-colon-after-throw failed"
  THEN CR ;
_p19-2h-start
' _p19-2h-throw-13 CATCH _p19-2h-throw-code !
: _p19-2h-good 99 ;
' _p19-2h-good _p19-2h-good-xt !
LATEST @ _p19-2h-good-latest !
_p19-2h-check
_p19-2h-end
