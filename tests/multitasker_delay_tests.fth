\ multitasker_delay_tests.fth — Story 25.3: yielding, per-task DELAY / MS.
\ Self-printing PASS:/FAIL: probe; verdict-greps are COLUMN-0-ANCHORED (^PASS:):
\ runtime verdicts land at column 0 (after the REPL input-echo newline) while the
\ echoed source holding the same literals is indented (colon bodies) or mid-line,
\ so neither false-greens (the 23.2 lesson). Runs under iz-cpm-banking via
\ `make test-repl-multitasker-delay`.
\
\ EMULATOR vs HARDWARE split (NFR-P6-14, the decisive constraint): iz-cpm-banking
\ does NOT model the MicroBeast 0xFDC7 user interrupt, so tick_count never advances
\ under emulation. A NONZERO DELAY/MS therefore never COMPLETES here (its target is
\ never reached) — wall-clock accuracy (60 DELAY ~ 60 s +/-1 s, AC3/NFR-P6-2), "two
\ different DELAYs both complete on time" (AC2/AC4), and "4 DELAY does not freeze
\ the prompt" (AC4) are all HARDWARE S9. This probe asserts only the yield
\ STRUCTURE, which 24.2's busy-wait could not: that (DELAY) now contains a LIVE
\ PAUSE (a background counter advances across an operator 0 DELAY, FR14) and that a
\ task parked in a nonzero DELAY YIELDS rather than monopolizing the ring — the
\ operator and a free-running counter both keep making progress (FR14/FR15). These
\ run to completion because the operator drives the probe to BYE and every parked
\ task yields on each loop pass; the Story 24.3 fail-loud timeout turns a
\ non-yielding (monopolizing) DELAY into a loud FAIL, not a silent CI hang.
\
\ ISR-not-installed hang (standing gotcha, carried forward): a nonzero DELAY/MS
\ waits for TICKS to reach a target; with the 64 Hz tick ISR not installed (the
\ emulator never fires it; on hardware after TIMER-OFF, or a foreign ISR like
\ TRAFFIC's START-CLOCK evicting the slot) TICKS is frozen and the delaying task
\ never completes. The yield seam only stops that task from MONOPOLIZING the CPU
\ (the ring + REPL keep running); it does not make the wait finish. Recover with
\ TIMER-ON. Not a regression — same as 24.2.

DECIMAL

\ --- (a) Words resolve; 0 DELAY / 0 MS return and conserve DEPTH (degenerate) ---
\ ' parses from the input buffer (interpret level); a miss throws -13 before the
\ verdict, so reaching PASS proves DELAY/MS/(DELAY) are all resolvable words.
' DELAY DROP  ' MS DROP  ' (DELAY) DROP  ." PASS: delay-words-resolve" CR
\ Length-1 ring here (no task yet): 0 DELAY/0 MS PAUSE is a walk-to-self no-op.
: _d0 ( -- )  DEPTH >R  0 DELAY  DEPTH R> = IF ." PASS: delay-zero-clean" ELSE ." FAIL: delay-zero-clean" THEN CR ;
_d0
: _m0 ( -- )  DEPTH >R  0 MS  DEPTH R> = IF ." PASS: ms-zero-clean" ELSE ." FAIL: ms-zero-clean" THEN CR ;
_m0

\ --- (b) FR14 yield witness: a BG counter advances ACROSS an operator 0 DELAY ---
\ 0 DELAY's loop runs exactly one PAUSE (target == TICKS -> first-pass exit); with
\ BG enqueued, that PAUSE hands it a turn, proving (DELAY) holds a LIVE PAUSE.
VARIABLE CNT
: BG ( -- )  BEGIN  CNT @ 1+ CNT !  PAUSE  0 UNTIL ;   \ free-running; parks at PAUSE
0 CNT !
' BG TASK ACTIVATE
0 DELAY 0 DELAY 0 DELAY                                \ 3 single-yield 0 DELAYs -> BG bumps >=1
: _yield ( -- )  CNT @ 0 > IF ." PASS: delay-yields" ELSE ." FAIL: delay-yields" THEN CR ;
_yield

\ --- (c) FR14/FR15 non-monopoly: a task parked in a NONZERO DELAY does not stop
\ the operator or the free-running BG counter (it yields every loop pass) ---
\ BG-DELAY never completes under emulation (TICKS frozen) but yields each pass; the
\ operator still drives and BG still bumps -> a mid-DELAY task is not monopolizing.
: BG-DELAY ( -- )  100 DELAY ;                         \ forever-pending here; yields each pass
0 CNT !
' BG-DELAY TASK ACTIVATE
0 DELAY 0 DELAY 0 DELAY 0 DELAY 0 DELAY                \ operator still completes its line
: _nm ( -- )  CNT @ 0 >  6 7 * 42 = AND IF ." PASS: delay-no-monopoly" ELSE ." FAIL: delay-no-monopoly" THEN CR ;
_nm

\ --- (d) Interpreter healthy + stack clean after the whole interleave ---
: _alive ( -- )  DEPTH 0=  1 2 3 + + 6 = AND IF ." PASS: delay-alive" ELSE ." FAIL: delay-alive" THEN CR ;
_alive
