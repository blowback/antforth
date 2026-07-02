\ multitasker_throw_tests.fth — Epic 25 regression: an uncaught THROW inside an
\ ACTIVATEd task must NOT desync the cooperative scheduler.
\
\ Before the fix, the uncaught-THROW handler reset the parameter stack to the
\ (PAUSE-swapped) per-task base and `JP w_QUIT_cf` — which rebuilds the return
\ stack from the GLOBAL rp_base and re-enters the operator REPL — while
\ current_tcb still pointed at the faulting task and that task stayed AWAKE. The
\ next yielding QUERY->PAUSE then snapshotted the operator's registers INTO the
\ background TCB: scheduler/REPL desync (corruption or hang). The fix detects a
\ non-operator current_tcb on the uncaught path, marks the faulting task
\ SUSPENDED (out of the rotation), and resumes the operator's own parked
\ continuation via the scheduler's restore tail.
\
\ Discriminating signals: after a task throws uncaught, (a) the operator REPL is
\ still alive and stack-clean — proven by a RUNTIME-computed 42 token that never
\ appears in this echoed source — and (b) .TASKS renders the task SUSPENDED. The
\ state string "SUSPENDED" is deliberately ABSENT from this source (the words
\ here are THROW / CATCH, never the 9-letter state name), so the Makefile's
\ row-presence grep on it proves .TASKS actually executed and rendered the table.
\ Driven by EXPLICIT PAUSE (no timer/interrupt) so it runs fully under iz-cpm via
\ `make test-repl-multitasker-throw`.

DECIMAL

\ --- Word-existence pre-flight: all must resolve (a miss throws -13) ---
' PAUSE DROP  ' TASK DROP  ' ACTIVATE DROP  ' .TASKS DROP  ." PASS: throw-words-resolve" CR

\ A task whose word throws uncaught the first time it is scheduled. -99 is a
\ non-standard code (no description), so the handler prints just "error -99".
: BOOM ( -- )  -99 THROW ;

\ ' BOOM (xt), TASK (handle) — DUP keeps the handle in BMT before ACTIVATE eats
\ it. BOOM is the only task, spliced after the operator: ring index 1.
' BOOM TASK DUP CONSTANT BMT ACTIVATE

\ One operator yield: the scheduler enters BOOM, -99 unwinds uncaught; the fix
\ must SUSPEND BOOM and return control HERE (right after PAUSE). Before the fix
\ the operator context is corrupted and never cleanly resumes.
PAUSE

\ --- The operator survived the task's uncaught throw and is stack-clean. Both
\ the depth check and the multiply are RUNTIME-evaluated; 42 cannot appear in the
\ echoed source, so a PASS here proves genuine post-recovery execution. ---
: _survives ( -- )
  DEPTH 0= 6 7 * 42 = AND IF ." PASS: throw-operator-survives" ELSE ." FAIL: throw-operator-survives" THEN CR
;
_survives

\ --- Printed witness: .TASKS must render BOOM (ring index 1) as SUSPENDED. The
\ Makefile requires the `^   1   SUSPENDED` row between these sentinels. ---
." ==THROW-TASKS-BEGIN==" CR  .TASKS  ." ==THROW-TASKS-END==" CR

\ --- No regression to the normal exception machinery: a CATCH around the same
\ throwing word still round-trips the code (the operator's in-place path is
\ untouched by the background-task branch). ---
: _opcatch ( -- )
  ['] BOOM CATCH -99 = IF ." PASS: throw-operator-catch" ELSE ." FAIL: throw-operator-catch" THEN CR
;
_opcatch

\ --- AC3: per-task catch_top isolation. The operator holds an open CATCH across
\ the PAUSE that enters a fresh throwing task (BOOM2, -7). Because PAUSE swaps the
\ per-task catch_top, BOOM2's uncaught throw hits ITS chain (empty), suspends the
\ task, and resumes the operator INSIDE the protected region — the operator's CATCH
\ must see NO throw (returns 0). BOOM2 sets the RAN2 sentinel BEFORE it throws, so a
\ post-PAUSE RAN2=1 witnesses that BMT2 actually executed in the BACKGROUND — checked
\ before the direct operator CATCH below (which would also set it). Without that
\ witness the test would PASS even if BMT2 never ran. A final direct operator CATCH
\ still round-trips -7, proving the operator's own exception machinery is intact.
\ (BOOM2's background fault also emits a `task 1: error -7` diagnostic.) ---
VARIABLE RAN2   0 RAN2 !
: BOOM2 ( -- )  1 RAN2 ! -7 THROW ;
' BOOM2 TASK DUP CONSTANT BMT2 ACTIVATE
: _iso ( -- )
  ['] PAUSE CATCH 0=            \ (a) operator's CATCH must NOT catch the task's throw
  RAN2 @ 1 = AND               \ (b) ...and BMT2 really ran in the background (pre-suspend)
  ['] BOOM2 CATCH -7 = AND      \ (c) operator CATCH still round-trips afterward
  IF ." PASS: throw-catch-isolated" ELSE ." FAIL: throw-catch-isolated" THEN CR
;
_iso

\ --- AC4: recovery without restart (FR21). Re-ACTIVATE the SAME suspended TCB
\ handle (BMT, the fault-suspended BOOM) with a GOOD replacement word, PAUSE, and
\ prove the task ran by a sentinel it wrote. ACTIVATE re-seeds the TCB to AWAKE with
\ fresh stacks, so the stale pre-fault registers are discarded (WAKE would revive
\ them — hence redefine + re-ACTIVATE is the sanctioned path). The sentinel 42 is
\ written by the SCHEDULED task, so a PASS proves genuine post-fault progress.
\ BMT2 is explicitly SLEPT first so this test does NOT depend on _iso having
\ suspended it (an AC3 regression that left BMT2 AWAKE would otherwise make the
\ single PAUSE run BMT2 instead of BMT); SLEEP forces it out of rotation so the
\ PAUSE deterministically reaches BMT regardless of BMT2's state. ---
VARIABLE RESULT   0 RESULT !
: FIXED ( -- )  42 RESULT ! ;
BMT2 SLEEP            \ decouple from _iso: park BMT2 unconditionally
' FIXED BMT ACTIVATE
PAUSE
: _recov ( -- )
  RESULT @ 42 = IF ." PASS: throw-reactivate-recovers" ELSE ." FAIL: throw-reactivate-recovers" THEN CR
;
_recov

\ --- Final liveness: interpreter healthy after the whole sequence ---
: _alive ( -- )  6 7 * 42 = IF ." PASS: throw-alive" ELSE ." FAIL: throw-alive" THEN CR ;
_alive
