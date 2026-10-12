\ again_tests.fth — BEGIN … AGAIN: runtime exits, compiled cells, errors, and
\ the banked window top. Runs under iz-cpm-banking via `make test-repl-again`.
\
\ Each case prints its results with `.` on a tagged line such as `agA=5 ` that
\ the Makefile asserts whole. Computed results print PASS:/FAIL: lines. Every
\ grep is COLUMN-0-ANCHORED: runtime output lands at column 0 (after the REPL
\ input-echo newline) while the echoed source holding the same tags starts with
\ `."` or `:`, so neither can false-green.
\
\ No loop here lacks an exit: the operator can't be broken out of a loop that
\ never yields, so a missing exit would hang the run until PROBE_TIMEOUT.
\
\ ERRORS. Each error case is on its own line; the Makefile counts them:
\ one `error -14` (AGAIN at the prompt), two `error -4` (UNTIL and AGAIN with
\ no BEGIN, from `-` inside the word), and two `error -8` from the banked
\ window-top cases plus a third that follows `49152 ` on the accepted case.

DECIMAL

\ --- Pre-flight: an undefined word raises -13 here and the verdicts go missing ---
' AGAIN DROP

\ --- Exit by EXIT from inside the loop ---
: _a1 0 BEGIN 1+ DUP 5 = IF EXIT THEN AGAIN ;
." agA=" _a1 . CR

\ --- Inside IF..THEN (taken / not taken) ---
: _a2 ( n -- m ) DUP 0> IF BEGIN 1- DUP 0= IF EXIT THEN AGAIN THEN 100 + ;
." agB=" 3 _a2 . -2 _a2 . CR

\ --- Encloses DO..LOOP left by LEAVE (each pass adds 3; 0 3 6 9 12) ---
: _a3 0 BEGIN 10 0 DO I 3 = IF LEAVE THEN 1+ LOOP DUP 9 > IF EXIT THEN AGAIN ;
." agC=" _a3 . CR

\ --- BEGIN .. WHILE .. AGAIN THEN ---
: _a4 0 BEGIN DUP 4 < WHILE 1+ AGAIN THEN ;
." agD=" _a4 . CR

\ --- Compiled cells: BRANCH -2 EXIT. _a5 is never executed; _e gives ;'s EXIT cell ---
: _a5 BEGIN AGAIN ;  : _e ;
." agS=" ' _a5 3 + @ ' BRANCH = . ' _a5 5 + @ . ' _a5 7 + @ ' _e 3 + @ = . CR

\ --- REPEAT still compiles ?BRANCH 8 .. BRANCH -10, and runs ---
: _w BEGIN DUP WHILE 1- REPEAT ;
." agR=" ' _w 7 + @ . ' _w 11 + @ ' BRANCH = . ' _w 13 + @ . 5 _w . CR

\ --- Every case above left the data stack balanced ---
: _dep ( -- ) DEPTH 0= IF ." PASS: ag-depth" ELSE ." FAIL: ag-depth" THEN CR ;
_dep

\ --- Errors: -14 once, then -4 twice ---
AGAIN
: _u UNTIL ;
: _g AGAIN ;

\ --- Banked ceiling ($BF58): X and Y straddle it (-8); Z ends at $BF57.
\ The witness after AGAIN in X and Y prints only if AGAIN did not throw; without
\ it, the -8 from `;` writing EXIT would satisfy the count on its own. ---
BANKS-CLEAR $22 +BANK $35 +BANK $36 +BANK $37 +BANK
1 BANK!  : _wx BEGIN [ $BF58 HERE - 1 - ALLOT ] AGAIN [ ." FAIL: ag-wx" ] ;
2 BANK!  : _wy BEGIN [ $BF58 HERE - 3 - ALLOT ] AGAIN [ ." FAIL: ag-wy" ] ;
3 BANK!  : _wz BEGIN [ $BF58 HERE - 4 - ALLOT ] AGAIN [ HERE U. ] ;
0 BANK!

\ --- Computed witness: only real execution prints 42 ---
." ag-alive=" 6 7 * . CR
