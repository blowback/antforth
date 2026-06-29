\ timer_tests.fth — Story 24.1: 64 Hz tick interrupt + monotonic TICKS counter.
\ Self-printing PASS:/FAIL: probe. Harness verdict-greps are COLUMN-0-ANCHORED
\ (^PASS: / ^FAIL:): runtime verdicts land at column 0 (after the REPL's input-
\ echo newline), while echoed colon-body source holding the same literals is
\ indented and cannot false-green (the 23.2 lesson).
\
\ EMULATOR vs HARDWARE split (NFR-P6-14): iz-cpm-banking does NOT model the
\ MicroBeast 0xFDC7 user interrupt, so tick_count never advances under emulation
\ (verified at dev-pass: two TICKS readings across a busy-wait both read 0 0).
\ This probe therefore asserts STRUCTURE only — TICKS is a clean double, the
\ high word is readable and zero at boot, TICKS is monotonic non-decreasing,
\ and TIMER-OFF/TIMER-ON install/remove without wedging the interpreter. The
\ wall-clock RATE (~64/s) and the true low->high CARRY (a 65 536-tick / ~17 min
\ rollover) are asserted at S9 hardware-smoke, NOT here.
\
\ Runs under iz-cpm-banking via `make test-repl-timer`.

DECIMAL

\ --- Word-existence pre-flight (all three must resolve) ---
\ Done at interpret level: ' parses from the input buffer, so it belongs here,
\ not inside a colon body (where it would find no input and throw -13). A miss
\ on any throws -13 before the verdict, so reaching PASS proves all three are
\ resolvable dictionary entries.
' TICKS DROP  ' TIMER-ON DROP  ' TIMER-OFF DROP  ." PASS: timer-words-resolve" CR

\ --- TICKS is a clean double: pushes exactly 2 cells (2DROP balances it) ---
: _t-clean ( -- )
  DEPTH >R  TICKS 2DROP  DEPTH R> = IF ." PASS: ticks-clean-double" ELSE ." FAIL: ticks-clean-double" THEN CR
;
_t-clean

\ --- High word is readable and zero at boot (structural; carry is HW-smoke) ---
: _t-high0 ( -- )
  TICKS SWAP DROP 0= IF ." PASS: ticks-high-zero" ELSE ." FAIL: ticks-high-zero" THEN CR
;
_t-high0

\ --- Monotonic non-decreasing across a busy-wait: NOT (d2 < d1) ---
\ d2 d1 D< must be false: a backwards clock is always wrong. Holds whether the
\ counter advanced (hardware) or stayed equal (emulator).
: _spin ( -- ) 0 BEGIN 1+ DUP 8000 = UNTIL DROP ;
: _t-mono ( -- )
  TICKS _spin TICKS 2SWAP D< 0= IF ." PASS: ticks-monotonic" ELSE ." FAIL: ticks-monotonic" THEN CR
;
_t-mono

\ --- TIMER-OFF / TIMER-ON install + remove without wedging the interpreter ---
\ The verdict gates on a RUNTIME-COMPUTED token (6 7 * = 42), never a bare
\ sentinel: iz-cpm echoes piped stdin, so an echo-only check would pass even if
\ the interpreter silently wedged after the BIOS calls.
TIMER-OFF TIMER-ON
: _t-onoff ( -- ) 6 7 * 42 = IF ." PASS: timer-onoff-alive" ELSE ." FAIL: timer-onoff-alive" THEN CR ;
_t-onoff
