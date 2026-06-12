\ Story 21.1 — MARKER/FORGET per-bank tail + stub reclamation hardware-smoke
\ probe (8.3 companion to tests/banking_tests_21_1.fth; the emulator gate keeps
\ the long name). Run:  INCLUDE P211MFK.FTH   at the MicroBeast REPL after a
\ fresh boot. Default CL gives 12 banks ($22 + $35-$3F) so banks 5/7 exist.
\ Each probe emits  result=-1 (PASS) / result=0 (FAIL) between sentinels.
\
\ Mechanism: MARKER snapshots the full 29-entry bank-table[] (every bank's
\ here/latest/wordlist_head) AND the descriptor-stub allocator tail into its
\ body; FORGET (DOMARKER) restores both, so words defined in ANY bank since the
\ MARKER are reclaimed.
\
\ Only COMPUTED, non-throwing verdicts here (INCLUDE-safe): the emulator's a/c
\ probes prove FIND-reachability via `' forgotten` -> -13, which would abort an
\ INCLUDE, and FIND wrongly resolves forgotten words. These three isolate the
\ NEW per-bank mechanism instead — b = stub-tail reuse, d = bank-5 dictionary
\ HERE rollback, c = a bank-5-set MARKER reclaiming a bank-7 tail (cross-bank).

DECIMAL

\ verdict ( P Q R -- (R==P)AND(Q<>P) )  — R rolled back to P, and the setup
\ actually advanced (Q<>P). Colon word so >R/R> stay balanced. Defined in
\ bank 0 before every MARKER below, so each FORGET keeps it.
: _vd  ROT DUP >R = SWAP R> = 0= AND ;

\ --- Probe-21.1-b: descriptor-stub allocator tail reclamation ------------
\ A bank-5 word's xt IS its 4-byte stub address. Capture _p2's xt, FORGET,
\ redefine _p3 in bank 5: its xt must EQUAL _p2's (tail rolled back, region
\ reused). All `'` are on live words, so no THROW.
5 BANK! : _p1 ; 0 BANK!
MARKER ZB
5 BANK! : _p2 ; 0 BANK!
' _p2
ZB
5 BANK! : _p3 ; 0 BANK!
' _p3
." ---probe-21.1-b-start---" CR
= ." result=" . CR
." ---probe-21.1-b-end---" CR

\ --- Probe-21.1-d: per-bank dictionary HERE rollback --------------------
\ Capture bank-5 HERE before the MARKER (P), advance it with a post-MARKER
\ definition (Q>P), FORGET, re-read (R). bank-table[] restore => R==P.
5 BANK! HERE 0 BANK!
MARKER ZD
5 BANK! : _qd ; HERE 0 BANK!
ZD
5 BANK! HERE 0 BANK!
." ---probe-21.1-d-start---" CR
_vd ." result=" . CR
." ---probe-21.1-d-end---" CR

\ --- Probe-21.1-c: cross-bank MARKER reclaims a foreign bank's tail -----
\ MARKER set while in bank 5; a word added in bank 7 advances bank-7 HERE;
\ FORGET via the bank-5-set marker (from its home bank 5) must roll bank-7
\ HERE back. Proves the full-table restore reverts banks other than the
\ marker's own.
7 BANK! HERE                 \ ( P7 )  pre-MARKER bank-7 HERE
5 BANK! MARKER ZC5
7 BANK! : _qc7 ; HERE        \ ( P7 Q7 )  Q7 = post-_qc7 bank-7 HERE
5 BANK!
ZC5                          \ FORGET via bank-5-set marker
7 BANK! HERE 0 BANK!         \ ( P7 Q7 R7 )
." ---probe-21.1-c-start---" CR
_vd ." result=" . CR
." ---probe-21.1-c-end---" CR

." ---probe-21.1-suite-end---" CR
