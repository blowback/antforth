\ underflow_tests.fth — every word that takes stack items raises -4 when they
\ aren't there, before any side effect. Runs under iz-cpm-banking via
\ `make test-repl-underflow`.
\
\ Each case runs a word through CATCH, so the word sees an empty stack (or one
\ item short), then prints the throw code and DEPTH. A checked word gives
\ `-4 0`; an unchecked one computes on the junk cell under the stack and
\ prints something else. Items left by a one-short case print between the
\ code and the depth, e.g. `-4 1 0`.
\
\ Each case prints its results with `.` on a tagged line such as `uA=-4 0 `
\ that the Makefile asserts whole. Computed results print PASS:/FAIL: lines.
\ Every grep is COLUMN-0-ANCHORED: runtime output lands at column 0 (after the
\ REPL input-echo newline) while the echoed source holding the same tags starts
\ with `."`, `:` or a word name, so neither can false-green.
\
\ ERRORS. The nine assembler cases at the end run uncaught, one per line; the
\ Makefile counts their `error -4` lines. Any `error -13` (missing word) or
\ `error -274` (loop frame left on the return stack at the prompt) fails the
\ run. An unchecked WAIT, POST or ACCEPT on a short stack can block for good;
\ the target's timeout turns that into a FAIL.

DECIMAL

\ --- Pre-flight: an already-checked word gives -4 0 ---
." u0=" ' DROP CATCH . DEPTH . CR

\ --- 1-cell CODE words at interpret level: each prints -4 0 ---
." uA=" ' DUP CATCH . DEPTH . ' ?DUP CATCH . DEPTH . ' SP! CATCH . DEPTH . ' RP! CATCH . DEPTH . CR
." uB=" ' >R CATCH . DEPTH . ' 1+ CATCH . DEPTH . ' 1- CATCH . DEPTH . ' 2* CATCH . DEPTH . CR
." uC=" ' 2/ CATCH . DEPTH . ' INVERT CATCH . DEPTH . ' 0= CATCH . DEPTH . ' 0< CATCH . DEPTH . CR
." uD=" ' CELL+ CATCH . DEPTH . ' CHAR+ CATCH . DEPTH . ' CHARS CATCH . DEPTH . ' C@ CATCH . DEPTH . CR
." uE=" ' ALLOT CATCH . DEPTH . ' , CATCH . DEPTH . ' C, CATCH . DEPTH . ' ALIGNED CATCH . DEPTH . CR
." uF=" ' CELLS CATCH . DEPTH . ' EXECUTE CATCH . DEPTH . ' >BODY CATCH . DEPTH . CR
." uG=" ' COMPILE, CATCH . DEPTH . ' LITERAL CATCH . DEPTH . ' COUNT CATCH . DEPTH . ' FIND CATCH . DEPTH . CR
." uH=" ' NUMBER? CATCH . DEPTH . ' SLEEP CATCH . DEPTH . ' WAKE CATCH . DEPTH . ' SPACES CATCH . DEPTH . CR
." uI=" ' +BANK CATCH . DEPTH . ' -BANK CATCH . DEPTH . ' BANK-OF CATCH . DEPTH . ' BIN CATCH . DEPTH . CR

\ --- Side effects that would show: no junk character after `=`; bank unchanged ---
." uJ=" ' EMIT CATCH . DEPTH . CR
VARIABLE _bk  BANK@ _bk !
." uK=" ' BANK! CATCH . BANK@ _bk @ = . DEPTH . CR

\ --- Parsing words: the check fires before the parse, so `.` and the rest of the
\ line are still interpreted normally ---
." uL=" ' CONSTANT CATCH . DEPTH . ' VALUE CATCH . DEPTH . ' SEMAPHORE CATCH . DEPTH . CR
." uM=" ' WORD CATCH . DEPTH . CR

\ --- 2- and 3-cell CODE words, empty and one short ---
TASK CONSTANT _TT
." uN=" ' TYPE CATCH . DEPTH . 1 ' TYPE CATCH . . DEPTH . CR
." uO=" ' ACTIVATE CATCH . DEPTH . _TT ' ACTIVATE CATCH . _TT = . DEPTH . CR
." uP=" ' (stub-allocate) CATCH . DEPTH . 1 ' (stub-allocate) CATCH . . DEPTH . CR
." uQ=" ' (TO) CATCH . DEPTH . 1 ' (TO) CATCH . . DEPTH . CR
." uR=" ' FILL CATCH . DEPTH . 1 2 ' FILL CATCH . . . DEPTH . CR
." uS=" ' MOVE CATCH . DEPTH . 1 2 ' MOVE CATCH . . . DEPTH . CR

\ --- PICK / ROLL: empty, one short, oversized u, then passing cases. CATCH puts
\ back the u that PICK/ROLL would have consumed, so it prints after the -4 ---
." uT=" ' PICK CATCH . DEPTH . 0 ' PICK CATCH . . DEPTH . 1 ' PICK CATCH . . DEPTH . CR
." uU=" 1 2 5 ' PICK CATCH . . . . DEPTH . 1 2 300 ' PICK CATCH . . . . DEPTH . CR
." uu=" 1 -1 ' PICK CATCH . . . DEPTH . CR
." uV=" ' ROLL CATCH . DEPTH . 0 ' ROLL CATCH . . DEPTH . 1 2 5 ' ROLL CATCH . . . . DEPTH . CR
." uW=" 7 0 PICK . . 1 2 3 2 PICK . . . . 9 0 ROLL . 1 2 3 2 ROLL . . . 5 6 1 ROLL . . DEPTH . CR

\ --- SET-ORDER: n wids plus the count; search order unchanged after -4 ---
." uX=" 1 ' SET-ORDER CATCH . . DEPTH . ' DUP DROP FORTH-WORDLIST 1 SET-ORDER GET-ORDER . FORTH-WORDLIST = . CR
: _so0 0 SET-ORDER GET-ORDER FORTH-WORDLIST 1 SET-ORDER ;
." uY=" _so0 . DEPTH . CR

\ --- RESTORE-INPUT: empty; count 4 with three cells; count not 4; count 4 with
\ five cells and a SOURCE-ID that does not match (-1, all five consumed) ---
." uZ=" ' RESTORE-INPUT CATCH . DEPTH . 1 2 3 4 ' RESTORE-INPUT CATCH . . . . . DEPTH . CR
." ua=" 5 ' RESTORE-INPUT CATCH . . DEPTH . 0 0 0 7 4 RESTORE-INPUT . DEPTH . CR

\ --- The same 1-cell words inside colon bodies ---
: _c1 DUP ; : _c2 ?DUP ; : _c3 SP! ; : _c4 RP! ; : _c5 >R ; : _c6 1+ ; : _c7 1- ; : _c8 2* ;
: _c9 2/ ; : _ca INVERT ; : _cb 0= ; : _cc 0< ; : _cd CELL+ ; : _ce CHAR+ ; : _cf CHARS ;
: _cg C@ ; : _ch ALLOT ; : _ci , ; : _cj C, ; : _ck ALIGNED ; : _cl CELLS ; : _cm EXECUTE ;
: _cn >BODY ; : _co COMPILE, ; : _cp POSTPONE LITERAL ; : _cq COUNT ; : _cr FIND ;
: _cs NUMBER? ; : _ct SLEEP ; : _cu WAKE ; : _cv SPACES ; : _cw +BANK ; : _cx -BANK ;
: _cy BANK-OF ; : _cz BIN ; : _d1 EMIT ; : _d2 BANK! ; : _d3 CONSTANT ; : _d4 VALUE ;
: _d5 WORD ; : _d6 RESTORE-INPUT ; : _d7 TYPE ; : _d8 ACTIVATE ; : _d9 (stub-allocate) ;
: _da FILL ; : _db MOVE ; : _dc PICK ; : _dd ROLL ;
." ub=" ' _c1 CATCH . ' _c2 CATCH . ' _c3 CATCH . ' _c4 CATCH . ' _c5 CATCH . ' _c6 CATCH . DEPTH . CR
." uc=" ' _c7 CATCH . ' _c8 CATCH . ' _c9 CATCH . ' _ca CATCH . ' _cb CATCH . ' _cc CATCH . DEPTH . CR
." ud=" ' _cd CATCH . ' _ce CATCH . ' _cf CATCH . ' _cg CATCH . ' _ch CATCH . ' _ci CATCH . DEPTH . CR
." ue=" ' _cj CATCH . ' _ck CATCH . ' _cl CATCH . ' _cm CATCH . ' _cn CATCH . ' _co CATCH . DEPTH . CR
." uf=" ' _cp CATCH . ' _cq CATCH . ' _cr CATCH . ' _cs CATCH . ' _ct CATCH . ' _cu CATCH . DEPTH . CR
." ug=" ' _cv CATCH . ' _cw CATCH . ' _cx CATCH . ' _cy CATCH . ' _cz CATCH . ' _d1 CATCH . DEPTH . CR
." uh=" ' _d2 CATCH . ' _d3 CATCH . ' _d4 CATCH . ' _d5 CATCH . ' _d6 CATCH . ' _d7 CATCH . DEPTH . CR
." ui=" ' _d8 CATCH . ' _d9 CATCH . ' _da CATCH . ' _db CATCH . ' _dc CATCH . ' _dd CATCH . DEPTH . CR
." uj=" 1 ' _d7 CATCH . . 1 2 ' _da CATCH . . . 1 2 5 ' _dc CATCH . . . . DEPTH . CR

\ --- Runtime words, through the colon words that compile them ---
: _r1 IF 1 THEN ;  : _r2 DO LOOP ;  : _r3 ?DO LOOP ;  : _r4 2 0 DO +LOOP ;  : _r5 ABORT" x" ;
: _r6 BEGIN UNTIL ;  : _r7 BEGIN WHILE REPEAT ;
." uk=" ' _r1 CATCH . ' _r2 CATCH . ' _r3 CATCH . ' _r4 CATCH . ' _r5 CATCH . DEPTH . CR
." ul=" 1 ' _r2 CATCH . . 1 ' _r3 CATCH . . ' _r6 CATCH . ' _r7 CATCH . DEPTH . CR

\ --- TO, compiled and interpreted; the VALUE keeps its contents. CATCH puts back
\ EVALUATE's c-addr u, hence the 2DROP ---
5 VALUE _v  : _tv TO _v ;
." um=" ' _tv CATCH . S" TO _v" ' EVALUATE CATCH . 2DROP _v . DEPTH . 9 TO _v _v . CR

\ --- Colon words: prefix guards and words that inherit a check ---
." un=" ' ACCEPT CATCH . DEPTH . 1 ' ACCEPT CATCH . . DEPTH . ' ABS CATCH . DEPTH . CR
." uo=" ' SIGNAL CATCH . DEPTH . ' WAIT CATCH . DEPTH . ' LOCK CATCH . DEPTH . CR
MAILBOX _MB
." up=" ' FETCH CATCH . DEPTH . ' POST CATCH . DEPTH . _MB ' POST CATCH . _MB = . DEPTH . CR
." uq=" 42 _MB POST _MB FETCH . DEPTH . CR

\ --- >NUMBER continues from a nonzero ud1 (high cell nearer the top) ---
." ur=" 1 0 S" 0" >NUMBER 2DROP D. 0 1 S" 0" >NUMBER 2DROP D. 65535 0 S" 0" >NUMBER 2DROP D. CR
." us=" 0 0 S" 12" >NUMBER 2DROP S" 34" >NUMBER 2DROP D. CR

\ --- Every case above left the data stack balanced ---
: _dep ( -- ) DEPTH 0= IF ." PASS: u-depth" ELSE ." FAIL: u-depth" THEN CR ;
_dep

\ --- Assembler, uncaught: each of these nine lines prints error -4. The prologue
\ minimum (DS, PUSH, LD, BIT,), then forms that need more: n #, (IX+d), # itself ---
CODE _X1 DS, END-CODE
CODE _X2 PUSH, END-CODE
CODE _X3 B LD, END-CODE
CODE _X4 B BIT, END-CODE
CODE _X5 A # LD, END-CODE
CODE _X6 (IX) 2 +D NIP B LD, END-CODE
CODE _X7 (IX) 5 +D NIP INC, END-CODE
CODE _X8 $74 # IN, END-CODE
CODE _X9 # END-CODE
\ --- -270 (not in CODE) still wins over -4 ---
." ut=" ' DS, CATCH . ' LD, CATCH . DEPTH . CR
\ --- Zero-operand mnemonics on an empty stack, and each multi-cell form with
\ exactly the cells it needs. Not executed (the (IX+d) forms would hit the return
\ stack); the length checks every form emitted its bytes: 42 + the 7-byte NEXT ---
CODE _XA NOP, A 5 # LD, B (IX) 2 +D LD, (IX) 2 +D B LD, (IX) 1 +D 7 # LD,
  A $1234 () LD, $1234 () A LD, $1234 () HL LD, 5 # ADD, (IX) 1 +D ADD,
  (IX) 3 +D INC, (IX) 1 +D RLC, 0 # (IX) 1 +D BIT, A $10 # IN, $10 # A OUT,
  NEXT, END-CODE
." uv=" HERE ' _XA - . DEPTH . CR
\ --- Indexed forms short of a displacement, caught inside an open CODE body:
\ -4 must come before any byte is emitted, so HERE does not move ---
VARIABLE _h
CODE _XB HERE _h ! ." uw=" (IX) 5 +D NIP ' INC, CATCH . HERE _h @ - . DROP DEPTH . CR
  ." ux=" (IX) 5 +D NIP ' ADD, CATCH . HERE _h @ - . DROP DEPTH . CR
  ." uy=" (IX) 5 +D NIP ' RLC, CATCH . HERE _h @ - . DROP DEPTH . CR NEXT, END-CODE

\ --- Computed witness: only real execution prints 42 ---
." u-alive=" 6 7 * . CR
