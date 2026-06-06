\ Story 19.5.0 DR-1 — minimal deterministic reproducer for the
\ "trampoline layout-fragility" hang class (actual mechanism: portal-
\ window dictionary aliasing — a colon body that straddles or lies
\ above the $8000 MMU slot-2 boundary vanishes mid-execution when the
\ body itself maps a foreign bank page over the window).
\
\ Template: 5496 is substituted by tests/straddle_repro_sweep.sh.
\ The shim ALLOT positions _victim's compiled body relative to $8000:
\   body fully below $8000  -> all markers m1..m5 + survived (PASS)
\   body straddling $8000   -> markers truncate at the first thread
\                              cell above $8000 executed after 1 BANK!
\                              (death point walks cell-by-cell with
\                              the knob — dose-response evidence)
\   body fully above $8000  -> only m1 (death at first cell after
\                              1 BANK!)
\
\ No descriptor stubs, no EXECUTE, no sentinel trampoline, no CATCH —
\ nothing from the cross-bank dispatch surface is involved. The only
\ moving parts are: dictionary position, one BANK! to a foreign page,
\ and straight-line colon-body execution.
DECIMAL
BANKS-CLEAR  $22 +BANK  $35 +BANK
HERE U. CR
CREATE _shim 5496 ALLOT
HERE U. CR
: _victim
  ." [m1]" CR
  1 BANK!
  ." [m2]" CR
  ." [m3]" CR
  ." [m4]" CR
  0 BANK!
  ." [m5]" CR
;
HERE U. CR
_victim
." survived" CR
BANKS-CLEAR
