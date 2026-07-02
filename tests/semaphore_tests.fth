\ semaphore_tests.fth — Story 26.1: counting semaphore (SEMAPHORE / SIGNAL / WAIT).
\ Self-printing PASS:/FAIL: probe; verdict-greps are COLUMN-0-ANCHORED (^PASS:):
\ runtime verdicts land at column 0 (after the REPL input-echo newline) while the
\ echoed source holding the same literals is indented (colon bodies) or mid-line,
\ so neither false-greens (the 23.2 lesson). Runs under iz-cpm-banking via
\ `make test-repl-semaphore`.
\
\ WHAT IS EMULATOR-CHECKABLE HERE (unlike DELAY): semaphores do NOT depend on the
\ 64 Hz tick ISR — SIGNAL/WAIT are pure cell arithmetic + PAUSE — so the full
\ SIGNAL/WAIT/hand-off STRUCTURE runs to completion under emulation. Wall-clock
\ interleave timing still rides S9 (NFR-P6-14), but no-loss / no-corruption /
\ no-deadlock (AC4) and starvation-liveness (AC6) are asserted right here.
\
\ DEADLOCK IS A LOUD FAIL, NOT A HANG: every blocking WAIT the operator joins on is
\ guaranteed a cross-task SIGNAL. If a signal that should arrive never does, the
\ operator's WAIT blocks, the probe never reaches BYE, and the Story 24.3 fail-loud
\ timeout turns it into a loud FAIL rather than a silent CI hang.
\
\ TASK BUDGET: TCBs carve from the ~2 KB of fixed RAM below $8000 (F4/NFR-P6-11),
\ so this probe activates only TWO forever-tasks — PROD (producer, later the AC6
\ starving waiter) and PEER (the AC6 liveness counter). The single-task checks
\ (a/b/c) run before any task exists.

DECIMAL

\ --- (a) Words resolve (AC1/AC2) ---
\ ' parses at interpret level; a miss throws -13 before the verdict, so reaching
\ PASS proves SEMAPHORE/SIGNAL/WAIT are all resolvable words.
' SEMAPHORE DROP  ' SIGNAL DROP  ' WAIT DROP  ." PASS: sem-words-resolve" CR

\ --- (b) AC1: constructor initialises the count cell verbatim (no clamping) ---
2 SEMAPHORE STWO
0 SEMAPHORE SZERO
-1 SEMAPHORE SNEG
: _init ( -- )
   STWO @ 2 =  SZERO @ 0 = AND  SNEG @ -1 = AND
   IF ." PASS: sem-constructor-init" ELSE ." FAIL: sem-constructor-init" THEN CR ;
_init

\ --- (c) AC2: SIGNAL increments, WAIT (count>0) decrements, stack stays clean ---
\ Single-task context here (no task activated yet): WAIT's PAUSE is a walk-to-self
\ no-op, so a non-zero count is taken immediately without blocking.
5 SEMAPHORE SCT
: _sigwait ( -- )
   DEPTH >R
   SCT SIGNAL                       \ 5 -> 6
   SCT WAIT  SCT WAIT               \ 6 -> 5 -> 4
   DEPTH R> =  SCT @ 4 = AND
   IF ." PASS: sem-signal-wait-count" ELSE ." FAIL: sem-signal-wait-count" THEN CR ;
_sigwait

\ --- (d) AC3+AC4: producer/consumer hand-off over a shared buffer, no loss, in
\ order. A zero-count WAIT blocks until the BACKGROUND producer SIGNALs (AC3); the
\ consumer receives every value exactly once, in order (AC4). PROD writes
\ buf[i]=(i+1)*10 and SIGNALs FULL once per item; the operator WAITs FULL 4x,
\ reading each cell. Correct = sum 100 AND all four values match expected. The
\ 100 / 4-good witnesses are computed at RUNTIME (never one echoed literal line),
\ defeating false-green. After producing, PROD parks on NEVER (see test f). ---
CREATE PBUF  4 CELLS ALLOT
0 SEMAPHORE FULL
0 SEMAPHORE NEVER
: PROD ( -- )
   4 0 DO
     I 1+ 10 *   I CELLS PBUF + !   \ buf[I] = (I+1)*10
     FULL SIGNAL
     PAUSE
   LOOP
   NEVER WAIT                       \ starve-but-yield forever (AC6 waiter)
   ." FAIL: sem-prod-waiter-unblocked" CR ;
' PROD TASK ACTIVATE
VARIABLE CSUM   VARIABLE GOOD
: _handoff ( -- )
   0 CSUM !  0 GOOD !
   4 0 DO
     FULL WAIT
     I CELLS PBUF + @                \ ( v )  = buf[I]
     DUP CSUM +!
     I 1+ 10 * =  IF GOOD @ 1+ GOOD ! THEN
   LOOP
   CSUM @ 100 =  GOOD @ 4 = AND
   IF ." PASS: sem-handoff-no-loss" ELSE ." FAIL: sem-handoff-no-loss" THEN CR ;
_handoff

\ --- (e) AC6: a WAIT on a never-signalled sem starves ITS task but keeps the ring
\ alive (PAUSE-first) — the cooperative-friendly failure, vs Story 25.7's hard,
\ reset-required non-yielding stall. PROD is now blocked in `NEVER WAIT`; PEER (a
\ peer counter) MUST keep advancing and the probe MUST still reach BYE. If PROD's
\ WAIT ever wrongly returned it prints sem-prod-waiter-unblocked (never seen). ---
VARIABLE PC2   0 PC2 !
: PEER ( -- )  BEGIN  PC2 @ 1+ PC2 !  PAUSE  0 UNTIL ;
' PEER TASK ACTIVATE
PAUSE PAUSE PAUSE PAUSE PAUSE PAUSE       \ rotate the ring a few times
: _starve ( -- )
   PC2 @ 0 >
   IF ." PASS: sem-wait-starves-ring-alive" ELSE ." FAIL: sem-wait-starves-ring-alive" THEN CR ;
_starve

\ --- (f) Interpreter healthy + stack clean after the whole interleave ---
: _alive ( -- )  DEPTH 0=  1 2 3 + + 6 = AND IF ." PASS: sem-alive" ELSE ." FAIL: sem-alive" THEN CR ;
_alive
