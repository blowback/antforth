\ Story 20.1 — bank-aware FIND hardware-smoke probes (8.3 copy of
\ tests/banking_tests_20_1.fth; the emulator gate keeps the long name).
\ Run:  INCLUDE P201FIND.FTH   at the MicroBeast REPL after a fresh boot.
\ (INCLUDE parses the name; INCLUDED expects c-addr u on the stack.)
\ Default CL gives 12 banks ($22 + $35-$3F) so banks 3 and 5 are available.
\ Each probe emits  result=-1 (PASS) / result=0 (FAIL) between sentinels.
\
\ Mechanism: bucket heads + entry hash_links are inline 24-bit fat pointers
\ [addr:2][bank:1]; FIND pages a window-resident entry's bank into slot 2,
\ then restores. Bank-N `:` words are linked into the global FORTH-WORDLIST
\ and findable by name across BANK!. Fixed heads (addr < $8000) read directly.

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

\ --- Probe-20.1-A (AC7a): creation-bank traversal -----------------------
." ---probe-20.1-a-start---" CR
5 BANK! : _p201a 100 ; 0 BANK!
' _p201a BANK-OF 5 =                 \ ( found-in-bank-5? )
." result=" . CR
." ---probe-20.1-a-end---" CR

\ --- Probe-20.1-B (AC7b): fixed-word lookup makes NO slot-2 switch -------
." ---probe-20.1-b-start---" CR
MBB-GET-2                            \ ( before )
' BANK@                              \ ( before xt )
SWAP MBB-GET-2 =                     \ ( xt  slot2-unchanged? )
SWAP 0= INVERT                       \ ( slot2-unchanged?  xt-nonzero? )
AND                                  \ ( verdict )
." result=" . CR
." ---probe-20.1-b-end---" CR

\ --- Probe-20.1-C (AC7c): undefined word misses cleanly ------------------
CREATE _p201c-name  4 C,  90 C, 90 C, 81 C, 81 C,   \ counted "ZZQQ" (undefined)
CREATE _p201f-name  6 C,  95 C, 112 C, 50 C, 48 C, 49 C, 102 C,  \ counted "_p201f"
." ---probe-20.1-c-start---" CR
_p201c-name FIND 0= SWAP DROP        \ ( -- correctly-missed? )  flag=0 -> -1
." result=" . CR
." ---probe-20.1-c-end---" CR

\ --- Probe-20.1-D (Q2): in-window search name survives the page-in -------
." ---probe-20.1-d-start---" CR
3 BANK! : _p201d 30 ; 5 BANK!
' _p201d BANK-OF 3 =                 \ ( found-bank-3-from-bank-5? )
0 BANK!
." result=" . CR
." ---probe-20.1-d-end---" CR

\ --- Probe-20.1-E: execute a bank-N word BY NAME across BANK! ------------
." ---probe-20.1-e-start---" CR
5 BANK! : _p201e 77 ; 0 BANK!
_p201e 77 =                          \ ( ran-bank-5-body-by-name? )
." result=" . CR
." ---probe-20.1-e-end---" CR

\ --- Probe-20.1-F (CR follow-up): bank-removal scrubs the bucket chains ------
\ Bank-6 word findable before BANKS-CLEAR, cleanly gone after, kernel word
\ (DUP) still findable — the scrub unlinked the bank-6 entry without orphaning
\ the shared chain or leaving a stale window pointer for a post-clear FIND.
." ---probe-20.1-f-start---" CR
6 BANK! : _p201f 55 ; 0 BANK!
_p201f-name FIND SWAP DROP 0= INVERT \ ( found-before-clear? )  TRUE
BANKS-CLEAR                          \ scrub unlinks the bank-6 entry
_p201f-name FIND SWAP DROP 0=        \ ( found-before  missed-after? )  TRUE
AND
' DUP 0= INVERT                      \ ( both  kernel-still-findable? )
AND                                  \ ( verdict )
." result=" . CR
." ---probe-20.1-f-end---" CR

." ---probe-20.1-suite-end---" CR
