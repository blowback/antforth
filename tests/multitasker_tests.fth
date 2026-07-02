\ multitasker_tests.fth — Story 25.1: PAUSE + circular ring + TASK/ACTIVATE.
\ Self-printing PASS:/FAIL: probe. Harness verdict-greps are COLUMN-0-ANCHORED
\ (^PASS: / ^FAIL:): runtime verdicts land at column 0 (after the REPL's input-
\ echo newline), while echoed source holding the same literals is indented (in
\ colon bodies) or mid-line (the ' ...-resolve line), so neither can false-green
\ (the 23.2 lesson). Runs under iz-cpm-banking via `make test-repl-multitasker`.
\
\ The two-task interleave is driven by EXPLICIT PAUSE (no KEY-hook / DELAY /
\ banking yet — those are 25.2/25.3/25.5). This asserts STRUCTURE: the words
\ resolve, a solo PAUSE on a length-1 ring is a clean no-op (AC1/FR9), two tasks
\ alternate deterministically (AC5/NFR-P6-8), the completion epilogue parks a
\ finished task ASLEEP so it leaves the rotation (AC4), and nothing corrupts the
\ stacks or dictionary. Wall-clock / interrupt behaviour is S9 hardware-smoke.

DECIMAL

\ --- Word-existence pre-flight: all three must resolve ---
\ At interpret level (' parses from the input buffer); a miss throws -13 before
\ the verdict, so reaching PASS proves all three are resolvable dictionary words.
' PAUSE DROP  ' TASK DROP  ' ACTIVATE DROP  ." PASS: mt-words-resolve" CR

\ --- Solo PAUSE on a length-1 ring (operator only) is a clean no-op (AC1/FR9) ---
\ Walks link once back to self, restores, resumes — DEPTH conserved, alive after.
: _solo ( -- )
  DEPTH >R  PAUSE PAUSE  DEPTH R> = IF ." PASS: mt-solo-pause" ELSE ." FAIL: mt-solo-pause" THEN CR
;
_solo

\ --- Two-task round-robin witness ---
\ TAPE is a shared decimal accumulator: each task appends its digit on its turn
\ (operator -> 1, background -> 2). Strict alternation builds a fixed value, which
\ is the deterministic round-robin proof (NFR-P6-8). Counts kept so the tape stays
\ inside one 16-bit cell (max 65535): BG appends two 2's, the operator three 1's.
VARIABLE TAPE
: APP ( d -- )  TAPE @ 10 * + TAPE ! ;
\ Background: 2 turns, then EXIT -> task_exit epilogue (ASLEEP + PAUSE).
: BG ( -- )  2 APP PAUSE  2 APP ;
\ Operator driver: 3 turns interleaved with the background task via PAUSE.
: DRV ( -- )  1 APP PAUSE  1 APP PAUSE  1 APP ;

0 TAPE !
' BG TASK ACTIVATE        \ ' BG (xt), TASK (task handle) -> ACTIVATE ( xt task -- )
DRV

\ Trace: op 1 ->1, PAUSE->BG 2 ->12, PAUSE->op 1 ->121, PAUSE->BG 2 ->1212
\ (BG ends: epilogue parks it ASLEEP + PAUSE) ->op 1 ->12121. Expected TAPE=12121.
: _rr ( -- )
  TAPE @ 12121 = IF ." PASS: mt-roundrobin" ELSE ." FAIL: mt-roundrobin" THEN CR
;
_rr

\ --- Background task is now ASLEEP: extra operator PAUSEs must not revive it ---
\ Proves the completion epilogue removed BG from the rotation (the walk skips
\ non-AWAKE); TAPE stays put because BG never runs again (AC4).
: _asleep ( -- )
  PAUSE PAUSE PAUSE  TAPE @ 12121 = IF ." PASS: mt-task-asleep" ELSE ." FAIL: mt-task-asleep" THEN CR
;
_asleep

\ --- Interpreter healthy after the whole interleave (runtime-computed token) ---
: _alive ( -- ) DEPTH 0= 6 7 * 42 = AND IF ." PASS: mt-alive" ELSE ." FAIL: mt-alive" THEN CR ;
_alive
