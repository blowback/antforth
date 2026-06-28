\ in_out_tests.fth — Story 23.3: Z80 runtime IN / OUT port words.
\ Self-printing PASS:/FAIL: probe. The harness verdict-greps are COLUMN-0-
\ ANCHORED (^PASS: / ^FAIL:): runtime verdicts land at column 0 (printed after
\ the REPL's input-echo newline), while the echoed colon-body source that holds
\ the same literals is indented, so it cannot false-green (the 23.2 lesson).
\
\ Coverage:
\   - AC6 distinctness / pre-flight: IN, IN,, OUT, OUT, all resolve (' tick).
\   - AC1 IN zero-extension: 72 IN 100 U< -> true (high byte provably 0).
\   - AC2/AC4 OUT executes + consumes exactly 2 cells, no THROW. NO value
\     round-trip is asserted — an inert port does not latch, by definition.
\   - AC5 underflow: IN on empty stack and OUT with one cell each raise -4,
\     left UNCAUGHT so the REPL prints `error -4: stack underflow`.
\
\ Port choices (finding (5)): 72 = slot-2 MMU page register — READING it is
\ side-effect-free (a read never remaps) and iz-cpm-banking models it; MMU
\ mapping is on at the REPL. FE = a high undecoded (inert) port — iz-cpm
\ silently ignores unmodeled writes; confirm undecoded on MicroBeast at HW
\ smoke. Ports 70-74 are OFF-LIMITS (MMU page regs + mapping-enable) and are
\ never touched here. Runs under iz-cpm-banking via `make test-repl-in-out`.

HEX

\ --- AC6: distinctness + word-existence pre-flight (all four must resolve) ---
\ Done at interpret level: ' parses from the input buffer, so it belongs here,
\ not inside a colon body (where it would find no input and throw -13). A miss
\ on any of the four throws -13 before the verdict, so reaching PASS proves all
\ four are distinct, resolvable dictionary entries.
' IN DROP  ' IN, DROP  ' OUT DROP  ' OUT, DROP  ." PASS: io-distinct-words" CR

\ --- AC1: IN zero-extension (high byte provably 0, so result < 100h) ---
: _io-in ( -- )
  72 IN 100 U< IF ." PASS: io-in-zero-extend" ELSE ." FAIL: io-in-zero-extend" THEN CR
;
_io-in

\ --- AC2/AC4: OUT runs without throw and leaves the stack 2 cells shallower ---
: _io-out ( -- )
  DEPTH >R  0 FE OUT  DEPTH R> = IF ." PASS: io-out-no-throw" ELSE ." FAIL: io-out-no-throw" THEN CR
;
_io-out

\ --- AC5: underflow raises -4 (UNCAUGHT — the REPL prints the message) ---
IN
0 OUT
