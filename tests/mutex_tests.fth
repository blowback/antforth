\ mutex_tests.fth — Story 26.2: mutex / binary semaphore (MUTEX / LOCK / UNLOCK).
\ Self-printing PASS:/FAIL: probe; verdict-greps are COLUMN-0-ANCHORED (^PASS:):
\ runtime verdicts land at column 0 (after the REPL input-echo newline) while the
\ echoed source holding the same literals is indented (colon bodies) or mid-line,
\ so neither false-greens (the 23.2 lesson). Runs under iz-cpm-banking via
\ `make test-repl-mutex`.
\
\ A mutex is a counting semaphore fixed at count 1: MUTEX = 1 SEMAPHORE, LOCK = WAIT,
\ UNLOCK = store-1 (binary clamp, NOT SIGNAL's unbounded increment). Like the 26.1
\ counting semaphore, none of this depends on the 64 Hz tick ISR — it is pure cell
\ arithmetic + PAUSE — so the full LOCK/mutate/UNLOCK exclusion STRUCTURE runs to
\ completion under emulation. Wall-clock interleave still rides S9 (NFR-P6-14), but
\ mutual exclusion / no-corruption (AC4) and ring-liveness (AC5) are asserted here.
\
\ DEADLOCK IS A LOUD FAIL, NOT A HANG: the operator's checker only ever LOCKs a mutex
\ the background WRITER actively releases every loop, so a correct build always makes
\ progress. If exclusion broke into a wedge, the probe never reaches BYE and the Story
\ 24.3 fail-loud timeout turns it into a loud FAIL rather than a silent CI hang.
\
\ TASK BUDGET: TCBs carve from the ~2 KB of fixed RAM below $8000 (F4/NFR-P6-11), so
\ this probe activates only ONE forever-task (WRITER); the operator's checker is a
\ bounded DO loop, not a second task. Story 26.1 hit the -8 guard at 4 tasks.

DECIMAL

\ --- (a) Words resolve (AC1/AC2) ---
\ ' parses at interpret level; a miss throws -13 before the verdict, so reaching
\ PASS proves MUTEX/LOCK/UNLOCK are all resolvable words.
' MUTEX DROP  ' LOCK DROP  ' UNLOCK DROP  ." PASS: mutex-words-resolve" CR

\ --- (b) AC1: constructor creates an unlocked (count=1) cell ---
MUTEX MTX
: _init ( -- )
   MTX @ 1 =
   IF ." PASS: mutex-constructor-init" ELSE ." FAIL: mutex-constructor-init" THEN CR ;
_init

\ --- (c) AC2/AC3: single-task LOCK→0, UNLOCK→1, double-UNLOCK clamps to 1, stack
\ clean. No task activated yet, so LOCK's PAUSE is a walk-to-self no-op and a free
\ mutex is taken immediately. The double UNLOCK is the AC3 binary-clamp witness. ---
: _cycle ( -- )
   DEPTH >R
   MTX LOCK    MTX @ 0 =                   \ acquired: count 0
   MTX UNLOCK  MTX @ 1 =  AND              \ released: count 1
   MTX UNLOCK  MTX UNLOCK  MTX @ 1 =  AND  \ double-UNLOCK stays 1 (never 2)
   DEPTH R> 1+ =  AND                      \ depth clean (one flag on stack now)
   IF ." PASS: mutex-lock-unlock-cycle" ELSE ." FAIL: mutex-lock-unlock-cycle" THEN CR ;
_cycle

\ --- (d) AC4/AC5: two contenders interleave cleanly. WRITER (background task) locks
\ MTX, stamps BOTH halves of a shared buffer with the SAME tag but PAUSEs mid-write
\ (the corruption trap), then unlocks and bumps the tag. The operator's checker locks
\ MTX, reads both halves, and counts consistent (equal) vs. bad (unequal) reads.
\ Because the operator reads only while holding the mutex, it never catches a
\ half-stamped buffer: bad MUST be 0 and consistent MUST be > 0. Both witnesses are
\ RUNTIME-computed by the checker loop (never one echoed literal), defeating false-
\ green. WRITER is a forever task via BEGIN..0 UNTIL (AGAIN is undefined in antforth). ---
CREATE WBUF  2 CELLS ALLOT
0 WBUF !  0 WBUF CELL+ !          \ start internally-consistent (0,0), not garbage
VARIABLE WTAG   1 WTAG !
: WRITER ( -- )
   BEGIN
     MTX LOCK
     WTAG @  WBUF !                 \ stamp BUF[0]
     PAUSE                          \ mid-write yield — the corruption trap
     WTAG @  WBUF CELL+ !           \ stamp BUF[1] with the SAME tag
     MTX UNLOCK
     WTAG @ 1+ WTAG !
   0 UNTIL ;
' WRITER TASK ACTIVATE
VARIABLE BAD   VARIABLE CONS
: _excl ( -- )
   0 BAD !  0 CONS !
   20 0 DO
     MTX LOCK
     WBUF @  WBUF CELL+ @           \ ( b0 b1 ) — read both halves under the lock
     =  IF  CONS @ 1+ CONS !  ELSE  BAD @ 1+ BAD !  THEN
     MTX UNLOCK
     PAUSE
   LOOP
   BAD @ 0=  CONS @ 0 > AND
   IF ." PASS: mutex-exclusion-clean" ELSE ." FAIL: mutex-exclusion-clean" THEN CR ;
_excl

\ --- (e) AC5: the ring is still alive — WRITER kept running while the operator
\ contended (the exclusion loop above already proved liveness by completing), and a
\ peer counter advanced. Confirm the WRITER's tag advanced past its start. ---
: _ringalive ( -- )
   WTAG @ 1 >
   IF ." PASS: mutex-ring-alive" ELSE ." FAIL: mutex-ring-alive" THEN CR ;
_ringalive

\ --- (f) AC7: interpreter healthy + stack clean after the whole interleave ---
: _alive ( -- )  DEPTH 0=  1 2 3 + + 6 = AND IF ." PASS: mutex-alive" ELSE ." FAIL: mutex-alive" THEN CR ;
_alive
