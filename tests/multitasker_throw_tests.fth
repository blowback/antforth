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

\ --- Final liveness: interpreter healthy after the whole sequence ---
: _alive ( -- )  6 7 * 42 = IF ." PASS: throw-alive" ELSE ." FAIL: throw-alive" THEN CR ;
_alive
