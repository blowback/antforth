\ Story 21.3 — Epic-21 close-out integration hardware-smoke probe (8.3 copy of
\ tests/banking_tests_21_3.fth; the emulator gate keeps the long name). Run:
\ INCLUDE P213INTG.FTH   at the MicroBeast REPL after a fresh boot. Default CL
\ gives 12 banks ($22 + $35-$3F) so banks 5/7 exist. Each probe emits
\ result=-1 (PASS) / result=0 (FAIL) between sentinels.
\
\ NORTH-STAR: the Epic-21 bank-aware LIFECYCLE surface — MARKER/FORGET revert
\ every active bank's dictionary tail AND reclaim the descriptor-stub allocator
\ tail (reuse, not leak); the caller's bank + slot-2 page are restored after the
\ cross-bank traffic.
\
\ Only COMPUTED, non-throwing verdicts here (INCLUDE-safe): a bare `' forgotten`
\ raises -13 which would abort the INCLUDE, and the saved-bank / QUIT-re-assert
\ property needs INTERACTIVE typing (the recogniser gates on source_id==0, and
\ an ABORT would abort an INCLUDE). Type that part by hand — see TAIL below.

DECIMAL

\ Self-contained slot-2 shadow reader (MBB_GET_PAGE, logical page 2).
CODE MBB-GET-2 ( -- page )
  BC PUSH,
  C 2 # LD,
  $FDDC CALL,
  C A LD,
  B 0 # LD,
  NEXT,
END-CODE

\ Setup: MARKER in home bank 0; throwaway `:` words across banks 5 and 7.
0 BANK!
MARKER ZZZ
5 BANK! : W5 42 ;
7 BANK! : W7 ;

\ --- Probe-21.3-a: cross-bank call W5 (bank 5) from bank 7 (via stub) ------
\ W5 returns 42 across the descriptor stub; 42 = => -1 (computed, no ABORT).
7 BANK!
." ---probe-21.3-a-start---" CR
W5 42 = ." xcall=" . CR
." ---probe-21.3-a-end---" CR
0 BANK!

\ --- Probe-21.3-c: stub-allocator-tail reclamation across FORGET ----------
\ Capture W5's stub xt (live), FORGET via ZZZ, redefine in bank 5: the fresh
\ stub xt must EQUAL W5's (tail rolled back + reused). All `'` on live words.
' W5
ZZZ
5 BANK! : Wr ; 0 BANK!
' Wr
." ---probe-21.3-c-start---" CR
= ." recl=" . CR
." ---probe-21.3-c-end---" CR

\ --- Probe-21.3-e: caller bank + slot-2 restored; defining resumes --------
." ---probe-21.3-e-start---" CR
BANK@ MBB-GET-2
: Wok 1234 ;
Wok DROP
MBB-GET-2 BANK@
>R ROT R> = >R = R> AND
." result=" . CR
." ---probe-21.3-e-end---" CR

." ---probe-21.3-suite-end---" CR

\ === TAIL — saved-bank / QUIT-re-assert: TYPE THESE LINES INTERACTIVELY ====
\ (not INCLUDE-able: the recogniser gates on source_id==0, and ABORT aborts an
\ INCLUDE). After a fresh boot, type:
\     0 BANK!
\     5 BANK! : X5 ;
\     7 BANK!            ( saved_bank <- 7, the last interactive BANK! )
\     ABORT
\     BANK@ .            ( -> 7 : QUIT re-asserted your last interactive bank )
\ Expect 7 — never the bank the aborted thread happened to be running in.
