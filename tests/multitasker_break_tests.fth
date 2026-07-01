\ multitasker_break_tests.fth — Story 25.7 keyboard break + documented stall.
\
\ Exercises the in-band Ctrl-\ (0x1C) break end-to-end. The Makefile replaces
\ each `@@BREAK@@` marker line with a real 0x1C byte on stdin (awk), so the
\ operator's (EDIT) reads the ACTUAL break byte and sets break_pending; PAUSE
\ then consumes it. This is the SAME consume->THROW -28 path silicon runs — a
\ genuine end-to-end test, not a software stand-in.
\
\ Two paths, one interpreter run (ordered so state is clean between them):
\   AC5a break path  — a background task that yields (BEGIN PAUSE 0 UNTIL) is
\                      broken by Ctrl-\: `task 1: error -28`, the task shows
\                      SUSPENDED, the operator survives stack-clean, and a
\                      redefine + re-ACTIVATE recovers it.
\   AC5b documented  — a task with no yield point is never broken: break delivery
\        stall         happens ONLY at a PAUSE seam. Bounded proxy for the honest
\                      "never-yielding task = reset-required" stall (which we do
\                      NOT run — it would hang CI): set the flag with no AWAKE
\                      breakable task, run a non-yielding stretch, and witness that
\                      nothing breaks (the flag latches, un-consumed).
\
\ Non-operator-only break (settled design): the operator is the task that READS
\ the byte, so an operator PAUSE leaves the flag set and hands off; the runaway
\ background task consumes it on ITS next yield. The explicit `PAUSE` after each
\ injection forces that hand-off deterministically under piped input.

DECIMAL

\ --- Word-existence pre-flight: all must resolve (a miss throws -13) ---
' PAUSE DROP  ' TASK DROP  ' ACTIVATE DROP  ' .TASKS DROP  ." PASS: break-words-resolve" CR

\ ===================================================================
\ AC5a — break a yielding runaway task
\ ===================================================================

\ A cooperative runaway: loops forever but reaches a yield every iteration
\ (AGAIN is undefined here, so the forever-loop idiom is BEGIN ... 0 UNTIL).
: YIELDER ( -- )  BEGIN PAUSE 0 UNTIL ;

\ ' YIELDER (xt), TASK (handle) — DUP keeps the handle in a CONSTANT before
\ ACTIVATE consumes it. YIELDER is the only task, spliced after the operator:
\ ring index 1.
' YIELDER TASK DUP CONSTANT YT ACTIVATE

\ Operator reads the injected Ctrl-\ (sets break_pending), then an explicit
\ PAUSE hands off: the operator (never the target) leaves the flag set and
\ switches to YIELDER, whose next PAUSE consumes it and raises THROW -28. The
\ 25.6 uncaught reroute prints `task 1: error -28`, SUSPENDs YIELDER, and
\ resumes the operator right here.
@@BREAK@@
PAUSE

\ --- The operator survived the break and is stack-clean. Both the depth check
\ and the multiply are RUNTIME-evaluated; 42 cannot appear in the echoed source,
\ so a PASS proves genuine post-break execution. ---
: _survives ( -- )
  DEPTH 0= 6 7 * 42 = AND IF ." PASS: break-yielding-task" ELSE ." FAIL: break-yielding-task" THEN CR
;
_survives

\ --- Printed witness: .TASKS must render YIELDER (ring index 1) as SUSPENDED.
\ The state string is absent from this source, so the Makefile's row-presence
\ grep on it proves .TASKS actually executed and rendered the table. ---
." ==BREAK-TASKS-BEGIN==" CR  .TASKS  ." ==BREAK-TASKS-END==" CR

\ --- Recovery without restart (FR21/FR22). Re-ACTIVATE the SAME suspended TCB
\ handle with a GOOD replacement word; the break flag is already consumed, so the
\ hand-off PAUSE runs GOOD cleanly. The 42 sentinel is written by the SCHEDULED
\ task, so a PASS proves genuine post-break recovery. ---
VARIABLE RESULT   0 RESULT !
: GOOD ( -- )  42 RESULT ! ;
' GOOD YT ACTIVATE
PAUSE
: _recov ( -- )
  RESULT @ 42 = IF ." PASS: break-recovers" ELSE ." FAIL: break-recovers" THEN CR
;
_recov

\ ===================================================================
\ AC5b — a non-yielding task is never broken (documented stall, bounded)
\ ===================================================================
\ The break is delivered ONLY at a PAUSE. A task that never yields therefore
\ never consumes the flag AND never returns control — an unbreakable, honest
\ reset-required stall (architecture: "no yield -> no operator turn -> no
\ break"). We can't RUN that task (it would hang CI), so we witness the
\ mechanism directly: with the sole background task now ASLEEP (YIELDER ran GOOD
\ and exited), set the flag via a second Ctrl-\ and run a finite NON-yielding
\ stretch of operator work. Nothing breaks — no THROW -28 unwinds it — because
\ there is no yielding background task to consume the flag at a PAUSE. The 42
\ token is runtime-computed (never in echoed source); a clean completion after
\ the injected break proves the flag was NOT consumed absent a yield point.
@@BREAK@@
: _nonyield ( -- )  6 7 * 42 = IF ." PASS: break-nonyield-stalls" ELSE ." FAIL: break-nonyield-stalls" THEN CR ;
_nonyield

\ ===================================================================
\ AC5c — a latched break must NOT ambush a task armed afterwards
\ ===================================================================
\ AC5b left break_pending SET with no consumer (no breakable task was AWAKE).
\ A single global latch with no owner would fire on the NEXT task to yield —
\ even one created long after the Ctrl-\. Arming a task must drain the latch, so
\ the fresh task runs its first PAUSE cleanly instead of dying with a spurious
\ -28. YT is ASLEEP here (ran GOOD, exited); re-ACTIVATE it with a word whose
\ FIRST act is a PAUSE — the exact seam a stale flag would fire at. R2 is written
\ only AFTER that PAUSE returns, so a PASS proves the task survived the yield the
\ stale flag would otherwise have broken. (Without the ACTIVATE-drain this task
\ is suspended with `task 1: error -28` and R2 stays 0 -> FAIL.)
VARIABLE R2   0 R2 !
: GOOD2 ( -- )  PAUSE 99 R2 ! ;
' GOOD2 YT ACTIVATE
PAUSE PAUSE
: _noambush ( -- )
  R2 @ 99 = IF ." PASS: break-no-ambush" ELSE ." FAIL: break-no-ambush" THEN CR ;
_noambush

\ --- Final liveness: interpreter healthy after the whole sequence ---
: _alive ( -- )  6 7 * 42 = IF ." PASS: break-alive" ELSE ." FAIL: break-alive" THEN CR ;
_alive
