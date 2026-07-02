\ mailbox_tests.fth — Story 26.3: one-slot mailbox (MAILBOX / POST / FETCH).
\ Self-printing PASS:/FAIL: probe; verdict-greps are COLUMN-0-ANCHORED (^PASS:):
\ runtime verdicts land at column 0 (after the REPL input-echo newline) while the
\ echoed source holding the same literals is indented (colon bodies) or mid-line,
\ so neither false-greens (the 23.2 lesson). Runs under iz-cpm-banking via
\ `make test-repl-mailbox`.
\
\ A mailbox is a bounded-buffer of capacity 1: two Story 26.1 counting semaphores
\ (empty=1 free slot, full=0 no item) plus a value cell. POST = empty WAIT / value !
\ / full SIGNAL; FETCH = full WAIT / value @ / empty SIGNAL. Like the 26.1 semaphore
\ this does NOT depend on the 64 Hz tick ISR — it is pure cell arithmetic + PAUSE —
\ so the full producer->consumer hand-off STRUCTURE runs to completion under emulation.
\ Wall-clock interleave rides S9 (NFR-P6-14), but no-loss/no-overwrite (AC4) and
\ ring-liveness (AC5) are asserted right here.
\
\ DEADLOCK IS A LOUD FAIL, NOT A HANG: the operator's consumer only ever FETCHes
\ values the background PRODUCER is actively POSTing (bounded to the exact producer
\ count), so a correct build always makes progress. If the hand-off wedged, the probe
\ never reaches BYE and the Story 24.3 fail-loud timeout turns it into a loud FAIL.
\
\ TASK BUDGET: TCBs carve from the ~2 KB of fixed RAM below $8000 (F4/NFR-P6-11), so
\ this probe activates only TWO forever-tasks — PRODUCER (later parks on NEVER, the
\ AC5 starving-but-yielding waiter) and PEER (the AC5 liveness counter). The operator's
\ consumer is a bounded DO loop, not a third task. Story 26.1 hit the -8 guard at 4 tasks.

DECIMAL

\ --- (a) Words resolve (AC1/AC2) ---
\ ' parses at interpret level; a miss throws -13 before the verdict, so reaching
\ PASS proves MAILBOX/POST/FETCH are all resolvable words.
' MAILBOX DROP  ' POST DROP  ' FETCH DROP  ." PASS: mailbox-words-resolve" CR

\ --- (b) AC1: constructor creates an empty one-slot mailbox ---
\ [value=0][empty=1][full=0] at MB / MB CELL+ / MB CELL+ CELL+.
MAILBOX MB
: _init ( -- )
   MB @ 0 =  MB CELL+ @ 1 = AND  MB CELL+ CELL+ @ 0 = AND
   IF ." PASS: mailbox-constructor-init" ELSE ." FAIL: mailbox-constructor-init" THEN CR ;
_init

\ --- (c) AC3: single-task round-trip transfers the exact value, DEPTH-clean. No task
\ activated yet: the mailbox starts with one free slot, so neither POST nor the
\ following FETCH blocks past its walk-to-self PAUSE. A second round-trip shows the
\ slot re-fills. Do NOT double-POST without an intervening FETCH (would wedge — AC6). ---
: _roundtrip ( -- )
   DEPTH >R
   123 MB POST  MB FETCH  123 =            \ exact value back
   456 MB POST  MB FETCH  456 = AND        \ slot re-fills, second value back
   DEPTH R> 1+ = AND                       \ depth clean (one result flag on stack now)
   IF ." PASS: mailbox-roundtrip-single" ELSE ." FAIL: mailbox-roundtrip-single" THEN CR ;
_roundtrip

\ --- (d) AC4: producer->consumer hand-off, no loss, no overwrite. PRODUCER (background
\ task) POSTs (I+1)*10 for I=0..3 into MB, then parks on a never-signalled sink so it
\ stays blocked-but-yielding (AC5). The operator FETCHes 4x, summing each value and
\ counting matches vs (I+1)*10. Because the mailbox is one slot (empty capped at 1),
\ the producer cannot POST reading i+1 until the consumer has FETCHed reading i — the
\ empty/full semaphores force lockstep, so no loss and no overwrite. sum=100 AND good=4
\ are RUNTIME-computed by the consumer loop (never one echoed literal), defeating false-
\ green. PRODUCER is a forever task via BEGIN..0 UNTIL park (AGAIN is undefined). ---
0 SEMAPHORE NEVER
: PRODUCER ( -- )
   4 0 DO
     I 1+ 10 *  MB POST             \ POST (I+1)*10 — waits empty, stores, signals full
   LOOP
   NEVER WAIT                       \ starve-but-yield forever (AC5 waiter)
   ." FAIL: mailbox-producer-unblocked" CR ;
' PRODUCER TASK ACTIVATE
VARIABLE CSUM   VARIABLE GOOD
: _handoff ( -- )
   0 CSUM !  0 GOOD !
   4 0 DO
     MB FETCH                        \ ( v ) — blocks until PRODUCER POSTs
     DUP CSUM +!
     I 1+ 10 * =  IF GOOD @ 1+ GOOD ! THEN
   LOOP
   CSUM @ 100 =  GOOD @ 4 = AND
   IF ." PASS: mailbox-handoff-no-loss" ELSE ." FAIL: mailbox-handoff-no-loss" THEN CR ;
_handoff

\ --- (e) AC5: PRODUCER is now parked in `NEVER WAIT` (blocked-but-yielding). A PEER
\ counter task MUST keep advancing and the probe MUST still reach BYE — the
\ cooperative-friendly failure (PAUSE-first), vs Story 25.7's hard, reset-required
\ non-yielding stall. Two forever-tasks max: PRODUCER + PEER. ---
VARIABLE PC2   0 PC2 !
: PEER ( -- )  BEGIN  PC2 @ 1+ PC2 !  PAUSE  0 UNTIL ;
' PEER TASK ACTIVATE
PAUSE PAUSE PAUSE PAUSE PAUSE PAUSE       \ rotate the ring a few times
: _ringalive ( -- )
   PC2 @ 0 >
   IF ." PASS: mailbox-empty-blocks-ring-alive" ELSE ." FAIL: mailbox-empty-blocks-ring-alive" THEN CR ;
_ringalive

\ --- (f) AC7: interpreter healthy + stack clean after the whole interleave ---
: _alive ( -- )  DEPTH 0=  1 2 3 + + 6 = AND IF ." PASS: mailbox-alive" ELSE ." FAIL: mailbox-alive" THEN CR ;
_alive
