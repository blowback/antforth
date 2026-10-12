\ qdo_tests.fth — ?DO: skip on equal limits, same results as DO otherwise,
\ LEAVE/UNLOOP/I/J inside it, compiled cells, errors, and the banked window
\ top. Runs under iz-cpm-banking via `make test-repl-qdo`.
\
\ Each case prints its results with `.` on a tagged line such as `qdA=0 1 5 `
\ that the Makefile asserts whole. Computed results print PASS:/FAIL: lines.
\ Every grep is COLUMN-0-ANCHORED: runtime output lands at column 0 (after the
\ REPL input-echo newline) while the echoed source holding the same tags starts
\ with `."`, `:` or a word name, so neither can false-green.
\
\ Every DO here has distinct limits: a DO with equal limits runs 65,536 times,
\ which is the bug ?DO exists to avoid.
\
\ ERRORS. Each error case is on its own line; the Makefile counts them:
\ one `error -14` (?DO at the prompt) and two `error -8` from the banked
\ window-top cases plus a third that follows `49152 ` on the accepted case.
\ Any `error -13` (missing word) or `error -274` (loop frame left on the
\ return stack at the prompt) fails the run.

DECIMAL

\ --- Pre-flight: an undefined word raises -13 here and the verdicts go missing ---
' ?DO DROP

\ --- Zero, one and five passes ---
: _q1 ( n -- count ) 0 SWAP 0 ?DO 1+ LOOP ;
." qdA=" 0 _q1 . 1 _q1 . 5 _q1 . CR

\ --- With +LOOP, positive step: skip when equal; else same count as DO ---
: _q2 ( lim start -- n ) 0 -ROT ?DO 1+ 2 +LOOP ;  : _d2 0 -ROT DO 1+ 2 +LOOP ;
." qdB=" 5 5 _q2 . 10 0 _q2 . 10 0 _d2 . 9 0 _q2 . 9 0 _d2 . CR

\ --- With +LOOP, negative step ---
: _q3 ( lim start -- n ) 0 -ROT ?DO 1+ -2 +LOOP ;  : _d3 0 -ROT DO 1+ -2 +LOOP ;
." qdC=" 7 7 _q3 . 0 10 _q3 . 0 10 _d3 . -1 10 _q3 . -1 10 _d3 . CR

\ --- Same index sequence as DO; the skipped call prints nothing ---
: _q4 ?DO I . 3 +LOOP ;  : _d4 DO I . 3 +LOOP ;
." qdI=" 10 1 _q4 4 4 _q4 10 1 _d4 CR

\ --- LEAVE, bare and inside IF..THEN, including a skipped loop that holds a LEAVE ---
: _q5 0 10 0 ?DO 1+ LEAVE LOOP ;
: _q7 ( n -- c ) 0 SWAP 0 ?DO I 3 = IF LEAVE THEN 1+ LOOP ;
." qdD=" _q5 . 0 _q7 . 10 _q7 . 2 _q7 . CR

\ --- UNLOOP EXIT ---
: _q8 ( lim -- x ) 0 ?DO I 4 = IF I UNLOOP EXIT THEN LOOP -1 ;
." qdE=" 10 _q8 . 0 _q8 . CR

\ --- Nesting: ?DO in ?DO with J; skipped ?DO inside DO; DO inside ?DO with J ---
: _q9 0 3 0 ?DO 2 0 ?DO J 10 * I + + LOOP LOOP ;
: _qa 0 3 0 DO 0 0 ?DO 99 + LOOP I + LOOP ;  : _qb 0 3 0 ?DO 2 0 DO J + LOOP LOOP ;
." qdF=" _q9 . _qa . _qb . CR

\ --- A skipped loop pushes no frame: EXIT after it returns normally ---
: _qc 0 0 ?DO LOOP 7 ;  : _qd 5 5 ?DO 1 +LOOP 8 ;
." qdG=" _qc . _qd . CR

\ --- Compiled cells. _qs and _ql are never executed ---
: _qs ?DO LOOP ;  : _ql ?DO LEAVE LOOP ;
." qdS=" ' _qs 3 + @ ' (?DO) = . ' _qs 5 + @ . ' _qs 9 + @ . ' _ql 5 + @ . ' _ql 11 + @ . CR

\ --- Every case above left the data stack balanced ---
: _dep ( -- ) DEPTH 0= IF ." PASS: qd-depth" ELSE ." FAIL: qd-depth" THEN CR ;
_dep

\ --- Error: -14 once ---
?DO

\ --- Banked: a ?DO word in bank 1 runs from bank 1 and from bank 0. ---
BANKS-CLEAR $22 +BANK $35 +BANK $36 +BANK $37 +BANK
1 BANK!  : _qk ( n -- c ) 0 SWAP 0 ?DO I 3 = IF LEAVE THEN 1+ LOOP ;
." qdK=" 0 _qk . 10 _qk . 2 _qk . CR
0 BANK!  ." qdL=" 0 _qk . 10 _qk . 2 _qk . CR

\ --- Banked ceiling ($BF58): X and Y cross it (-8); Z ends at $BF57.
\ The witness after ?DO in X and Y prints only if ?DO did not throw; without
\ it, the -8 from `;` writing EXIT would satisfy the count on its own. ---
1 BANK!  : _wx [ $BF58 HERE - 1 - ALLOT ] ?DO [ ." FAIL: qd-wx" ] ;
2 BANK!  : _wy [ $BF58 HERE - 3 - ALLOT ] ?DO [ ." FAIL: qd-wy" ] ;
3 BANK!  : _wz [ $BF58 HERE - 4 - ALLOT ] ?DO [ HERE U. ] ;
0 BANK!

\ --- Computed witness: only real execution prints 42 and 4 ---
: _qe 0 4 0 ?DO 1+ LOOP ;
." qd-alive=" 6 7 * . _qe . CR
