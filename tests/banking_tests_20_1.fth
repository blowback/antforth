\ === Story 20.1 — bank-aware FIND (inline 24-bit fat dictionary pointers) ===
\
\ Isolated fixture: `make test-repl-banking-isolated-20-1`. Fresh antforth
\ under iz-cpm-banking with NO prior test-file accumulation. Each probe emits
\ a single verdict integer via `.`:  -1 = TRUE = PASS, 0 = FALSE = FAIL. The
\ Makefile recipe greps for `result=-1` between the per-probe sentinels.
\
\ Mechanism under test (supersedes the planning-era per-wordlist `bank` field):
\ every bucket head and every entry hash_link is an inline 3-byte fat pointer
\ [addr:2][bank:1]. FIND pages a window-resident entry's bank into slot 2
\ before reading its name, then restores the caller's page on the way out.
\ Bank-N `:` definitions are linked into the single global FORTH-WORDLIST and
\ are therefore findable by name across a BANK! cycle. Fixed/kernel heads
\ (addr < $8000) read directly — the everyday lookup takes no MMU switch.
\
\ Refs: docs/antforth-banking-redesign.md §5.5; FR-P4-27/28; NFR-P4-6/12.

DECIMAL

\ Self-contained slot-2 shadow reader (MBB_GET_PAGE, logical page 2). Used by
\ the fixed-word no-switch witness below; defined inline so the fixture loads
\ standalone (mirrors _bmad-output/implementation-artifacts/16.3-probe.fth).
CODE MBB-GET-2 ( -- page )
  BC PUSH,          \ save old TOS to the data stack
  C 2 # LD,         \ C = logical page 2 (slot 2)
  $FDDC CALL,       \ MBB_GET_PAGE -> A = physical page
  C A LD,           \ C <- A (low byte)
  B 0 # LD,         \ B <- 0  (zero-extend to a cell)
  NEXT,
END-CODE

\ --- Probe-20.1-A (AC7a): creation-bank traversal -----------------------
\ A bank-5 colon word is found BY NAME from bank 0; BANK-OF reports bank 5.
\ This is the headline acceptance: the per-bank body is reached through the
\ trampoline, and the name resolves through the fat bucket chain.
." ---probe-20.1-a-start---" CR
5 BANK! : _p201a 100 ; 0 BANK!
' _p201a BANK-OF 5 =                 \ ( found-in-bank-5? )
." result=" . CR
." ---probe-20.1-a-end---" CR

\ --- Probe-20.1-B (AC7b): fixed-word lookup makes NO slot-2 switch -------
\ ' BANK@ (a kernel/fixed word) resolves via the fast path: the slot-2 shadow
\ (MBB-GET-2) is identical before and after the find, and the xt is non-zero.
." ---probe-20.1-b-start---" CR
MBB-GET-2                            \ ( before )
' BANK@                              \ ( before xt )
SWAP MBB-GET-2 =                     \ ( xt  slot2-unchanged? )
SWAP 0= INVERT                       \ ( slot2-unchanged?  xt-nonzero? )
AND                                  \ ( verdict )
." result=" . CR
." ---probe-20.1-b-end---" CR

\ --- Probe-20.1-C (AC7c): undefined word misses cleanly ------------------
\ FIND of a name not in any wordlist returns flag 0 (the -13 THROW is TICK's
\ standard wrapping of that miss, unchanged by banking). The counted name
\ lives in a CREATE'd buffer (not HERE) so the outer interpreter's own
\ token-parse into HERE can't clobber it before FIND runs.
CREATE _p201c-name  4 C,  90 C, 90 C, 81 C, 81 C,   \ counted "ZZQQ" (undefined)
." ---probe-20.1-c-start---" CR
_p201c-name FIND 0= SWAP DROP        \ ( -- correctly-missed? )  flag=0 -> -1
." result=" . CR
." ---probe-20.1-c-end---" CR

\ --- Probe-20.1-D (NFR/Q2): in-window search name survives the page-in ---
\ Parked in bank 5 (HERE in the $8000 window), look up a bank-3 word. WORD
\ writes the search name into bank 5's window; FIND must snapshot it to fixed
\ scratch before paging in bank 3, or the compare would read bank 3's page.
." ---probe-20.1-d-start---" CR
3 BANK! : _p201d 30 ; 5 BANK!
' _p201d BANK-OF 3 =                 \ ( found-bank-3-from-bank-5? )
0 BANK!
." result=" . CR
." ---probe-20.1-d-end---" CR

\ --- Probe-20.1-E: execute a bank-N word BY NAME across BANK! ------------
\ Not just findable — the resolved xt dispatches the bank-5 body through the
\ trampoline and returns the right value, invoked by bare name from bank 0.
." ---probe-20.1-e-start---" CR
5 BANK! : _p201e 77 ; 0 BANK!
_p201e 77 =                          \ ( ran-bank-5-body-by-name? )
." result=" . CR
." ---probe-20.1-e-end---" CR

." ---probe-20.1-suite-end---" CR
BYE
