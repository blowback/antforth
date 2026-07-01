\ multitasker_demo_tests.fth — Story 25.8: headline demo (background traffic
\ light + live REPL). Self-printing PASS:/FAIL: probe; verdict-greps are
\ COLUMN-0-ANCHORED (^PASS:): runtime verdicts land at column 0 (after the REPL
\ input-echo newline) while the echoed source holding the same literals is
\ indented (colon bodies) or mid-line, so neither false-greens (the 23.2 lesson).
\ Runs under iz-cpm-banking via `make test-repl-multitasker-demo`.
\
\ This story writes NO new kernel word — it assembles the shipped Epic-24/25 parts
\ into the headline moment. The probe INCLUDEs the shipped demo asset
\ (disk/a/TRAFFIC.FTH, mounted directory-backed via IZCPM_DISKS) and drives it
\ end-to-end: activate the LIGHTS background task, show both tasks AWAKE, prove the
\ light task yields (does not monopolize) while parked in a nonzero DELAY, and that
\ the operator survives stack-clean.
\
\ EMULATOR vs HARDWARE split (NFR-P6-14, the decisive constraint): iz-cpm-banking
\ does NOT model the MicroBeast 0xFDC7 user interrupt, so TICKS never advances
\ under emulation and a NONZERO DELAY never COMPLETES here (its target is never
\ reached). On-tempo cycling, "prompt returns immediately", and "4 DELAY does not
\ freeze the prompt" are all HARDWARE S9 (AC4, the MVP acceptance gate NFR-P6-6) —
\ NOT provable here. This probe asserts only the yield STRUCTURE, which IS testable
\ because "yields each pass" is exactly what a never-completing-but-yielding DELAY
\ does: the light task parks at the PAUSE inside DELAY and the ring keeps running,
\ so a free-running counter task and the operator both keep making progress across
\ the light task's pending DELAY (FR14/FR15, NFR-P6-7). The Story 24.3 fail-loud
\ timeout turns a non-yielding (monopolizing) DELAY into a loud FAIL, not a silent
\ CI hang. OUT to the PIO ports ($10/$12) is inert under emulation (23.3).

DECIMAL

\ --- (a) INCLUDE the shipped asset; its words resolve; activation is clean ------
\ INCLUDE compiles TRAFFIC.FTH (which does `TASK CONSTANT LIGHTS` — LIGHTS is
\ spliced into the ring ASLEEP, safely skipped by INCLUDE's yielding reader until
\ armed). ' parses from the input buffer (interpret level); a miss throws -13
\ before the verdict, so reaching PASS proves the asset's words all resolved.
INCLUDE TRAFFIC.FTH
' RUN-LIGHTS DROP  ' PIO-INIT DROP  ' LIGHTS DROP
\ Free-running counter = liveness witness, independent of the light task.
VARIABLE CNT
: BG ( -- )  BEGIN  CNT @ 1+ CNT !  PAUSE  0 UNTIL ;   \ parks at PAUSE each pass
0 CNT !
' BG TASK ACTIVATE                                    \ counter task -> ring
' RUN-LIGHTS LIGHTS ACTIVATE                          \ the demo light task -> AWAKE
: _act ( -- )  DEPTH 0= IF ." PASS: demo-activates" ELSE ." FAIL: demo-activates" THEN CR ;
_act

\ --- (b) AC2: .TASKS shows BOTH the operator and LIGHTS awake --------------------
\ `^   2   AWAKE` is RUNTIME output of .TASKS — LIGHTS is ring index 2. TASK
\ splices each new TCB right after the operator, so index order is REVERSE of
\ creation: LIGHTS (made first, during INCLUDE) is pushed to index 2 when BG (the
\ counter task above) is spliced in at index 1. Anchoring on index 2 pins LIGHTS
\ specifically — an index-1 match would green on BG even if LIGHTS never activated.
\ The row never appears in this echoed source, so a --present match proves .TASKS
\ executed and rendered LIGHTS as AWAKE (the Journey-1 "two things at once"
\ witness; 23.2 false-green defence).
." ==TASKS-BEGIN==" CR  .TASKS  ." ==TASKS-END==" CR

\ --- (c) FR14/FR15/NFR-P6-7 no-monopoly: LIGHTS parked in a nonzero DELAY does
\ not stop the free-running counter or the operator (it yields every loop pass) ---
\ LIGHTS never completes its 4 DELAY under emulation (TICKS frozen) but yields each
\ pass; the counter still bumps and the operator still finishes its line -> a
\ mid-DELAY light task is not monopolizing the ring.
0 CNT !
0 DELAY 0 DELAY 0 DELAY 0 DELAY 0 DELAY                \ operator still completes its line
: _nm ( -- )  CNT @ 0 >  6 7 * 42 = AND IF ." PASS: demo-no-monopoly" ELSE ." FAIL: demo-no-monopoly" THEN CR ;
_nm

\ --- (d) operator survives stack-clean after the whole interleave ---------------
: _alive ( -- )  DEPTH 0=  1 2 3 + + 6 = AND IF ." PASS: demo-alive" ELSE ." FAIL: demo-alive" THEN CR ;
_alive
