\ Story 20.3 — Epic-20 close-out integration hardware-smoke probe (8.3 copy
\ of tests/banking_tests_20_3.fth; the emulator gate keeps the long name).
\ Run:  INCLUDE P203INTG.FTH   at the MicroBeast REPL after a fresh boot.
\ Default CL gives 12 banks ($22 + $35-$3F) so banks 5/6/7 are available.
\
\ NORTH-STAR: the bank-aware lookup surface end-to-end — three banks' words
\ list flat under WORDS (a), `'` (FIND) + BANK-OF resolve each name to its
\ home bank (b), the caller's bank + slot-2 are restored after the
\ traversals (c), and a typo gives the PLAIN `<word> ?` — FR-P4-30 retired (d).
\
\ HW-vs-emulator ordering note: probe (d) types a bare undefined word, whose
\ -13 THROW aborts the INCLUDE (the recovery witness) — so the suite-end
\ sentinel is printed BEFORE (d) here and (d) is last with no BYE. The piped
\ emulator fixture instead recovers line-by-line, so it keeps (d) mid-stream.

DECIMAL

\ Self-contained slot-2 shadow reader (MBB_GET_PAGE, logical page 2).
CODE MBB-GET-2 ( -- page )
  BC PUSH,          \ save old TOS to the data stack
  C 2 # LD,         \ C = logical page 2 (slot 2)
  $FDDC CALL,       \ MBB_GET_PAGE -> A = physical page
  C A LD,           \ C <- A (low byte)
  B 0 # LD,         \ B <- 0  (zero-extend to a cell)
  NEXT,
END-CODE

\ Three user words, one each in banks 5, 6, 7.
5 BANK! : _w53a ; 6 BANK! : _w53b ; 7 BANK! : _w53c ; 0 BANK!

\ --- Probe-20.3-a: WORDS lists all three banks' names flat from bank 0 ----
." ---probe-20.3-a-start---" CR
WORDS
." ---probe-20.3-a-end---" CR

\ --- Probe-20.3-b: bank-aware FIND resolves each name to its home bank -----
." ---probe-20.3-b-start---" CR
' _w53a BANK-OF 5 =                  \ ( f1 )
' _w53c BANK-OF 7 =                  \ ( f1 f2 )
AND                                  \ ( verdict )
." result=" . CR
." ---probe-20.3-b-end---" CR

\ --- Probe-20.3-c: bank + slot-2 restored after WORDS + FIND traversals ----
." ---probe-20.3-c-start---" CR
BANK@ MBB-GET-2                       \ ( b0 s0 )
WORDS
' _w53a BANK-OF DROP
' _w53c BANK-OF DROP
MBB-GET-2 BANK@                      \ ( b0 s0 s1 b1 )
>R ROT R> = >R = R> AND              \ ( verdict )
." result=" . CR
." ---probe-20.3-c-end---" CR

." ---probe-20.3-suite-end---" CR

\ --- Probe-20.3-d: FR-P4-30 retired — plain <word> ?, then REPL recovers --
\ Last line: the -13 THROW aborts the INCLUDE; expect `?NOSUCH? ?` with no
\ bank suffix and the interactive prompt to return.
." ---probe-20.3-d-start---" CR
?NOSUCH?
