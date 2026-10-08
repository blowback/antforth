\ comparison_tests.fth — <> 0<> 0> U> <= >= at their boundary values.
\ Runs under iz-cpm-banking via `make test-repl-comparisons`.
\
\ Two kinds of verdict. Each comparison prints its results with `.` on a tagged
\ line such as `neA=0 -1 0 -1 ` that the Makefile asserts whole. The A tags run
\ at interpret level, the B tags run the same cases from inside a colon body.
\ Computed results print PASS:/FAIL: lines. Every grep is COLUMN-0-ANCHORED:
\ runtime output lands at column 0 (after the REPL input-echo newline) while the
\ echoed source holding the same tags starts with `."` or `:`, so neither can
\ false-green.
\
\ The signed $7FFF/$8000 pairs for <= and >= are the cases where SBC overflows;
\ `$8000 0 <=` overflows only because of the carry-in from SCF.
\
\ UNDERFLOW. Each underflow case is on its own line and prints
\ `error -4: stack underflow`; the Makefile counts them (10 at interpret level,
\ 10 more from inside colon bodies). `1 <>` etc. are the depth-1 cases for the
\ two-operand words.

DECIMAL

\ --- Pre-flight: an undefined word raises -13 here and the verdicts go missing ---
' <> DROP  ' 0<> DROP  ' 0> DROP  ' U> DROP  ' <= DROP  ' >= DROP

\ --- Interpret level ---
." neA=" 5 5 <> . 5 6 <> . -1 -1 <> . 0 -1 <> . CR
." zneA=" 0 0<> . 1 0<> . -1 0<> . $8000 0<> . CR
." zgtA=" 0 0> . 1 0> . -1 0> . $7FFF 0> . $8000 0> . 128 0> . CR
." ugtA=" $FFFF 1 U> . 1 $FFFF U> . 7 7 U> . 1 0 U> . 0 0 U> . CR
." leA=" 3 3 <= . 2 3 <= . 3 2 <= . -1 0 <= . $7FFF $8000 <= . CR
." le2A=" $8000 $7FFF <= . $8000 0 <= . 0 $8000 <= . $8000 $8000 <= . $7FFF $7FFF <= . CR
." geA=" 3 3 >= . 2 3 >= . 3 2 >= . -1 0 >= . $7FFF $8000 >= . CR
." ge2A=" $8000 $7FFF >= . $8000 0 >= . 0 $8000 >= . $8000 $8000 >= . CR

\ --- Colon bodies: the same cases, compiled ---
: _ne 5 5 <> . 5 6 <> . -1 -1 <> . 0 -1 <> . ;
: _zne 0 0<> . 1 0<> . -1 0<> . $8000 0<> . ;
: _zgt 0 0> . 1 0> . -1 0> . $7FFF 0> . $8000 0> . 128 0> . ;
: _ugt $FFFF 1 U> . 1 $FFFF U> . 7 7 U> . 1 0 U> . 0 0 U> . ;
: _le 3 3 <= . 2 3 <= . 3 2 <= . -1 0 <= . $7FFF $8000 <= . ;
: _le2 $8000 $7FFF <= . $8000 0 <= . 0 $8000 <= . $8000 $8000 <= . $7FFF $7FFF <= . ;
: _ge 3 3 >= . 2 3 >= . 3 2 >= . -1 0 >= . $7FFF $8000 >= . ;
: _ge2 $8000 $7FFF >= . $8000 0 >= . 0 $8000 >= . $8000 $8000 >= . ;
." neB=" _ne CR
." zneB=" _zne CR
." zgtB=" _zgt CR
." ugtB=" _ugt CR
." leB=" _le CR
." le2B=" _le2 CR
." geB=" _ge CR
." ge2B=" _ge2 CR

\ --- Every word above consumed what it should and left one flag for `.` ---
: _depth DEPTH 0= IF ." PASS: cmp-depth" ELSE ." FAIL: cmp-depth" THEN CR ;
_depth

\ --- Underflow at interpret level: each line raises -4 on an empty stack ---
<>
1 <>
U>
1 U>
<=
1 <=
>=
1 >=
0<>
0>

\ --- Underflow inside colon bodies: the same ten cases, compiled ---
: _u1 <> ;  : _u2 1 <> ;  : _u3 U> ;  : _u4 1 U> ;  : _u5 <= ;
: _u6 1 <= ;  : _u7 >= ;  : _u8 1 >= ;  : _u9 0<> ;  : _u10 0> ;
_u1
_u2
_u3
_u4
_u5
_u6
_u7
_u8
_u9
_u10

\ --- The REPL came back from all twenty with a clean stack. The witness is
\ computed at RUNTIME (DEPTH, and an addition), never one echoed literal. ---
: _alive ( -- )  DEPTH 0=  1 2 3 + + 6 = AND
   IF ." PASS: cmp-survives" ELSE ." FAIL: cmp-survives" THEN CR ;
_alive
