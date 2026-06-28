\ === Story 20.2 — bank-aware WORDS (verify) + FR-P4-30 retired ===
\
\ Isolated fixture: `make test-repl-banking-isolated-20-2`. Fresh antforth
\ under iz-cpm-banking with NO prior test-file accumulation. Verdicts are
\ read two ways by the Makefile recipe:
\   - content probes (a)/(c): grep the per-probe WORDS dump for the names
\     that must appear (a bank-N name listed from bank 0; a fixed/kernel name
\     and a bank-N name in one run).
\   - computed probe (b): a Forth-side `result=-1` (TRUE = restore held).
\   - negative control (d): the plain `<word> ?` line with no bank suffix.
\
\ Mechanism under verification (shipped in Story 20.1's CR pass d078548; this
\ story writes NO kernel WORDS code): w_WORDS_cf walks all 64 fat bucket heads
\ of the single global FORTH-WORDLIST; words_deref reads each 3-byte fat
\ pointer [addr:2][bank:1] and, when the entry is window-resident
\ ($8000..$BFFF), pages active_pages[bank] into slot 2 before reading its
\ count_flags/name. The first switch of the walk saves the caller's slot-2
\ page; sw_restore_slot2 puts it back on exit. Because the bank travels with
\ each pointer, a single chain mixing fixed and bank-N entries lists flat with
\ the bank switches invisible.
\
\ FR-P4-30 (source-bank error attribution) is RETIRED: under the fat-pointer
\ mechanism there are no per-bank wordlists to attribute, and bank-aware FIND
\ resolves a name in any reachable bank, so a miss is simply "absent
\ everywhere". The undefined-word surface stays Phase-3-identical: <word> ?.
\
\ Refs: docs/antforth-banking-redesign.md §5.5 / §5.4; FR-P4-29 (verified),
\ FR-P4-30 (retired); NFR-P4-6/12/20.
\
\ Parked in bank 0 for every WORDS / lookup (HERE fixed, < $8000): the only
\ workable behavioural pattern — a foreign-bank-mapped token lookup would
\ strand at -13 (ADR 19.5 DR-1 aliasing). WORDS pages foreign banks in and
\ out itself, so listing from bank 0 is safe.

DECIMAL

\ Self-contained slot-2 shadow reader (MBB_GET_PAGE, logical page 2), used by
\ probe (b)'s restore witness; defined inline so the fixture loads standalone
\ (mirrors tests/banking_tests_20_1.fth).
CODE MBB-GET-2 ( -- page )
  BC PUSH,          \ save old TOS to the data stack
  C 2 # LD,         \ C = logical page 2 (slot 2)
  $FDDC CALL,       \ MBB_GET_PAGE -> A = physical page
  C A LD,           \ C <- A (low byte)
  B 0 # LD,         \ B <- 0  (zero-extend to a cell)
  NEXT,
END-CODE

\ --- Probe-20.2-a (AC6a): WORDS lists bank-5 names from bank 0 -----------
\ Two colon words defined in bank 5 must both appear in a WORDS listing typed
\ from bank 0 — the per-entry fat-pointer page-in reaches their bank-5
\ headers. The recipe greps the dump between the sentinels for both names.
5 BANK! : _w52a ; : _w52b ; 0 BANK!
." ---probe-20.2-a-start---" CR
WORDS
." ---probe-20.2-a-end---" CR

\ --- Probe-20.2-b (AC6b): WORDS restores the caller's bank + slot-2 -------
\ Snapshot BANK@ and the slot-2 page before WORDS (which pages bank 5 in to
\ print the words above), then after; assert both unchanged. Stack across the
\ four pushes: ( b0 s0 s1 b1 ); verdict = (b0=b1) AND (s0=s1).
5 BANK! : _w52d ; 0 BANK!
." ---probe-20.2-b-start---" CR
BANK@ MBB-GET-2                       \ ( b0 s0 )
WORDS                                \ pages bank 5 in, restores on exit
MBB-GET-2 BANK@                      \ ( b0 s0 s1 b1 )
>R ROT R> = >R = R> AND              \ ( verdict )
." result=" . CR
." ---probe-20.2-b-end---" CR

\ --- Probe-20.2-c (AC6c): mixed chain — fixed + bank-N both listed --------
\ One WORDS run must show a fixed/kernel name (DUP, addr < $8000, read with no
\ MMU op) and a bank-5 name (_w52c, paged in) — proves per-entry page-in,
\ not a one-shot switch that would drop one class. Recipe greps for ` DUP `
\ and `_w52c`.
5 BANK! : _w52c ; 0 BANK!
." ---probe-20.2-c-start---" CR
WORDS
." ---probe-20.2-c-end---" CR

\ --- Probe-20.2-d (AC6d): FR-P4-30 retired — plain <word> ? ---------------
\ An undefined word at the REPL produces the standard `?NOSUCH? ?` with NO
\ bank suffix; QUIT catches the -13 and resumes, so the end sentinels print.
\ (Matches the `make test-repl` "XYZZY ?" assertion — banking adds nothing.)
." ---probe-20.2-d-start---" CR
?NOSUCH?
." ---probe-20.2-d-end---" CR

." ---probe-20.2-suite-end---" CR
BYE
