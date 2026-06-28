\ Story 20.2 — bank-aware WORDS hardware-smoke probes (8.3 copy of
\ tests/banking_tests_20_2.fth; the emulator gate keeps the long name).
\ Run:  INCLUDE P202WRDS.FTH   at the MicroBeast REPL after a fresh boot.
\ Default CL gives 12 banks ($22 + $35-$3F) so bank 5 is available.
\
\ Mechanism (shipped in Story 20.1 CR d078548; verified here): w_WORDS_cf
\ derefs each 24-bit fat pointer [addr:2][bank:1] and pages a window-resident
\ entry's bank into slot 2 before printing its name, then restores the
\ caller's slot-2 page on exit. Bank-N names list flat from bank 0.
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

\ --- Probe-20.2-a: WORDS lists bank-5 names from bank 0 ------------------
5 BANK! : _w52a ; : _w52b ; 0 BANK!
." ---probe-20.2-a-start---" CR
WORDS
." ---probe-20.2-a-end---" CR

\ --- Probe-20.2-b: WORDS restores the caller's bank + slot-2 ------------
5 BANK! : _w52d ; 0 BANK!
." ---probe-20.2-b-start---" CR
BANK@ MBB-GET-2                       \ ( b0 s0 )
WORDS
MBB-GET-2 BANK@                      \ ( b0 s0 s1 b1 )
>R ROT R> = >R = R> AND              \ ( verdict )
." result=" . CR
." ---probe-20.2-b-end---" CR

\ --- Probe-20.2-c: mixed chain — fixed (DUP) + bank-N (_w52c) both listed -
5 BANK! : _w52c ; 0 BANK!
." ---probe-20.2-c-start---" CR
WORDS
." ---probe-20.2-c-end---" CR

." ---probe-20.2-suite-end---" CR

\ --- Probe-20.2-d: FR-P4-30 retired — plain <word> ?, then REPL recovers --
\ Last line: the -13 THROW aborts the INCLUDE; expect `?NOSUCH? ?` with no
\ bank suffix and the interactive prompt to return.
." ---probe-20.2-d-start---" CR
?NOSUCH?
