\ stack_words_tests.fth — NIP, TUCK, -ROT, ? and the ROT depth-3 underflow check.
\ Runs under iz-cpm-banking via `make test-repl-stack-words`.
\
\ Two kinds of verdict. Printed results (.S and ? output) appear as tagged lines
\ such as `swA=<1> 2 ` that the Makefile asserts. Computed results print
\ PASS:/FAIL: lines. Every grep is COLUMN-0-ANCHORED: runtime output lands at
\ column 0 (after the REPL input-echo newline) while the echoed source holding
\ the same tags starts with `."` or `:`, so neither can false-green (the 23.2
\ lesson).
\
\ UNDERFLOW. Each underflow case is on its own line and prints
\ `error -4: stack underflow`; the Makefile counts them (9 at interpret level,
\ 9 more from inside colon bodies). `1 2 -ROT` and `1 2 ROT` are the depth-2
\ cases: with only two items both words must raise -4, not read below the stack.

DECIMAL

\ --- Pre-flight: an undefined word raises -13 here and the verdicts go missing ---
' NIP DROP  ' TUCK DROP  ' -ROT DROP  ' ? DROP

\ --- AC1 at interpret level: tagged .S output, each line cleans its stack ---
." swA=" 1 2 NIP .S CR DROP
." swB=" 1 2 TUCK .S CR DROP DROP DROP
." swC=" 1 2 3 -ROT .S CR DROP DROP DROP
." swD=" 1 2 3 -ROT ROT .S CR DROP DROP DROP

\ --- AC2 at interpret level: ? is @ . and honours BASE ---
VARIABLE V  42 V !
." qA=" V ? CR
HEX ." qB=" V ? CR DECIMAL
-1 V ! ." qC=" V ? CR
42 V !

\ --- AC1 inside colon bodies: check every result cell AND the depth ---
: _nip  1 2 NIP 2 = DEPTH 1 = AND
   IF ." PASS: sw-nip" ELSE ." FAIL: sw-nip" THEN CR ;
_nip
: _tuck  1 2 TUCK  2 = >R 1 = >R 2 = R> AND R> AND DEPTH 1 = AND
   IF ." PASS: sw-tuck" ELSE ." FAIL: sw-tuck" THEN CR ;
_tuck
: _mrot  1 2 3 -ROT  2 = >R 1 = >R 3 = R> AND R> AND DEPTH 1 = AND
   IF ." PASS: sw-mrot" ELSE ." FAIL: sw-mrot" THEN CR ;
_mrot
: _round  1 2 3 -ROT ROT  3 = >R 2 = >R 1 = R> AND R> AND DEPTH 1 = AND
   IF ." PASS: sw-mrot-rot" ELSE ." FAIL: sw-mrot-rot" THEN CR ;
_round

\ --- AC2 inside a colon body: ? prints, so this is a tagged line ---
: _q  ." qD=" V ? CR  HEX ." qE=" V ? CR DECIMAL ;
_q

\ --- AC3 at interpret level: each line raises -4 on an empty stack ---
NIP
1 NIP
TUCK
1 TUCK
-ROT
1 -ROT
1 2 -ROT
?
1 2 ROT

\ --- AC3 inside colon bodies: the same nine cases, compiled ---
: _u1 NIP ;  : _u2 1 NIP ;  : _u3 TUCK ;  : _u4 1 TUCK ;  : _u5 -ROT ;
: _u6 1 -ROT ;  : _u7 1 2 -ROT ;  : _u8 ? ;  : _u9 1 2 ROT ;
_u1
_u2
_u3
_u4
_u5
_u6
_u7
_u8
_u9

\ --- The REPL came back from all eighteen with a clean stack. The witness is
\ computed at RUNTIME (DEPTH, and an addition), never one echoed literal. ---
: _alive ( -- )  DEPTH 0=  1 2 3 + + 6 = AND
   IF ." PASS: sw-survives" ELSE ." FAIL: sw-survives" THEN CR ;
_alive
