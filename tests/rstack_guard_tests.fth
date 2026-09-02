\ rstack_guard_tests.fth — text-interpreter return-stack balance guard (-274).
\ Self-printing PASS:/FAIL: probe; verdict-greps are COLUMN-0-ANCHORED (^PASS:):
\ runtime verdicts land at column 0 (after the REPL input-echo newline) while the
\ echoed source holding the same literals is indented, so neither false-greens
\ (the 23.2 lesson). Runs under iz-cpm-banking via `make test-repl-rstack-guard`.
\
\ WHAT THIS PINS. INTERPRET runs each typed token with EXECUTE from inside its
\ own DOCOL frame, so a token that leaves the return stack at a different depth
\ than it found it overwrites INTERPRET's return address. Before the guard,
\ `1 >R` at the prompt made INTERPRET's EXIT jump to address 0x0001 and the
\ machine fell straight into CP/M's warm boot — no message, no recovery, the
\ whole session gone. The guard turns that into an ordinary -274 THROW.
\
\ THE GUARD IS NET-PER-LINE, NOT PER-TOKEN. `1 >R R> .` typed on one line is
\ legitimate and passes through a deliberately unbalanced return stack in the
\ middle; only the depth INTERPRET is about to EXIT through has to be right.
\ Case (d) pins that, so a future tightening to a per-token check fails loudly.
\
\ FAIL IS LOUD, NOT SILENT: if the guard regresses, the probe does not print
\ FAIL — it drops to CP/M mid-file and the later verdicts simply never appear,
\ which the Makefile's missing-verdict assertion catches.

DECIMAL

\ --- (a) AC1: a bare `>R` raises -274 instead of dropping to CP/M ---
1 >R

\ --- (b) AC2: a bare `R>` — which pops INTERPRET's own frame — raises it too ---
R>

\ --- (c) The REPL survived both, with a clean stack. Witnesses are computed at
\ RUNTIME (DEPTH, and an addition), never one echoed literal line. ---
VARIABLE RG   0 RG !
: _alive ( -- )  DEPTH 0=  1 2 3 + + 6 = AND
   IF ." PASS: rg-repl-survives" ELSE ." FAIL: rg-repl-survives" THEN CR ;
_alive

\ --- (d) AC3: balanced same-line >R/R> is still legal at the prompt ---
1 >R R> RG !
: _balanced ( -- )  RG @ 1 =
   IF ." PASS: rg-same-line-balanced" ELSE ." FAIL: rg-same-line-balanced" THEN CR ;
_balanced

\ --- (e) AC4: >R/R> compiled into a colon body is untouched by the guard ---
: _rt ( -- n )  7 >R R> ;
0 RG !   _rt RG !
: _compiled ( -- )  RG @ 7 =
   IF ." PASS: rg-compiled-unaffected" ELSE ." FAIL: rg-compiled-unaffected" THEN CR ;
_compiled

\ --- (f) AC5: a bare EXIT still just ends the line and returns to the prompt.
\ This is why the canary holds interp_exit_stub and not a raw address: EXIT pops
\ the canary into IP, so IP must land on something that means "return". ---
EXIT
0 RG !   5 RG !
: _exitok ( -- )  RG @ 5 =
   IF ." PASS: rg-bare-exit-benign" ELSE ." FAIL: rg-bare-exit-benign" THEN CR ;
_exitok

\ --- (g) AC6: the guard nests — EVALUATE re-enters INTERPRET and gets its own
\ canary, so ordinary EVALUATEd text is unaffected. ---
0 RG !   S" 9 RG !" EVALUATE
: _nested ( -- )  RG @ 9 =
   IF ." PASS: rg-evaluate-nests" ELSE ." FAIL: rg-evaluate-nests" THEN CR ;
_nested

\ --- (h) AC7: and the nested canary is the one that fires — an unbalanced
\ EVALUATEd line raises -274 from the INNER INTERPRET (third and last -274 of
\ the run) rather than corrupting the outer one. The same path carries INCLUDE:
\ a stray >R in an INCLUDEd file lands here too. ---
S" 1 >R" EVALUATE
: _nestthrow ( -- )  DEPTH 0=
   IF ." PASS: rg-nested-throw" ELSE ." FAIL: rg-nested-throw" THEN CR ;
_nestthrow
