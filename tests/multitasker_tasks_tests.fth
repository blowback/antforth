\ multitasker_tasks_tests.fth — Story 25.4: SLEEP / WAKE + .TASKS introspection.
\ Self-printing PASS:/FAIL: probe. Harness verdict-greps are COLUMN-0-ANCHORED
\ (^PASS: / ^FAIL:): runtime verdicts land at column 0 (after the REPL's input-
\ echo newline), while echoed source holding the same literals is indented (in
\ colon bodies) or mid-line, so neither can false-green (the 23.2 lesson). Runs
\ under iz-cpm via `make test-repl-multitasker-tasks`.
\
\ The state strings the table prints (the uppercase awake/parked/suspended names)
\ are RUNTIME output of .TASKS — they never appear in this echoed source (the words
\ here are SLEEP / WAKE, not the 6-letter parked-state name), so the Makefile's
\ row-presence greps prove .TASKS actually executed and rendered the table.
\
\ The discriminating assertions are the behavioural SLEEP/WAKE transitions (the
\ 25.1 TAPE pattern): a parked background counter must NOT advance across operator
\ PAUSEs (the walk skipped it); a woken one must. Driven by EXPLICIT PAUSE (no
\ timer/interrupt) so it runs fully under the emulator. Live-prompt responsiveness
\ is S9 hardware-smoke.

DECIMAL

\ --- Word-existence pre-flight: all must resolve (a miss throws -13) ---
' SLEEP DROP  ' WAKE DROP  ' .TASKS DROP  ' >TASK DROP  ." PASS: tasks-words-resolve" CR

\ --- Background counter task: bumps CTR once per PAUSE, loops forever (0 UNTIL
\ never exits), so it stays in the ring and the operator manages it by hand. ---
VARIABLE CTR
: BUMP ( -- )  CTR @ 1+ CTR ! ;
: BG ( -- )  BEGIN BUMP PAUSE 0 UNTIL ;
: DRV5 ( -- )  PAUSE PAUSE PAUSE PAUSE PAUSE ;

\ ' BG (xt), TASK (handle) — DUP keeps the handle in BGT before ACTIVATE eats it.
' BG TASK DUP CONSTANT BGT ACTIVATE

\ --- >TASK ( n -- task ): the index .TASKS prints round-trips to the saved handle.
\ BG is spliced after the operator, so it is ring index 1; 1 >TASK must equal BGT. ---
: _idxhandle ( -- )
  BGT 1 >TASK = IF ." PASS: tasks-index-to-handle" ELSE ." FAIL: tasks-index-to-handle" THEN CR
;
_idxhandle

\ --- .TASKS is ( -- ) / stack-clean: prints rows but must not perturb the stack ---
: _dotclean ( -- )
  DEPTH >R .TASKS DEPTH R> = IF ." PASS: tasks-dot-clean" ELSE ." FAIL: tasks-dot-clean" THEN CR
;
_dotclean

\ --- AC2/AC3 printed witness: operator (task 0) + background (task 1) both awake.
\ The Makefile requires the task-1 awake row between these sentinels. ---
." ==TASKS-BEGIN==" CR  .TASKS  ." ==TASKS-END==" CR

\ --- AC1 SLEEP skips: park BG, drive PAUSEs; the accumulator must NOT advance
\ (reverting SLEEP's status write lets BG run and this FAILs — discriminating). ---
BGT SLEEP
0 CTR ! DRV5
: _sleepskips ( -- )
  CTR @ 0= IF ." PASS: tasks-sleep-skips" ELSE ." FAIL: tasks-sleep-skips" THEN CR
;
_sleepskips

\ --- Parked-state printed witness: BG now renders the parked-state row ---
." ==TASKS-SLEPT==" CR  .TASKS  ." ==TASKS-SLEPT-END==" CR

\ --- AC1 WAKE resumes: wake BG, drive PAUSEs; the accumulator advances ---
BGT WAKE
0 CTR ! DRV5
: _wakeresumes ( -- )
  CTR @ 0 > IF ." PASS: tasks-wake-resumes" ELSE ." FAIL: tasks-wake-resumes" THEN CR
;
_wakeresumes

\ --- Interpreter healthy after the whole sequence (runtime-computed token) ---
: _alive ( -- )  DEPTH 0= 6 7 * 42 = AND IF ." PASS: tasks-alive" ELSE ." FAIL: tasks-alive" THEN CR ;
_alive
