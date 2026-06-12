\ === Story 20.3 — Epic-20 close-out integration probe ===
\
\ NORTH-STAR: the Epic-20 bank-aware lookup surface, observable end-to-end
\ in one breath. Words are defined in THREE different banks; from bank 0
\ (a) `WORDS` lists all three flat (bank switches invisible), (b) `'`
\ resolves each by name via bank-aware FIND and `BANK-OF` reports the
\ correct home bank, (c) the caller's bank + slot-2 page are restored after
\ those traversals, and (d) a typo produces the PLAIN `<word> ?` — FR-P4-30
\ source-bank error attribution is RETIRED (a miss is "absent everywhere").
\
\ Isolated fixture: `make test-repl-banking-isolated-20-3`. Fresh antforth
\ under iz-cpm-banking, no prior test-file accumulation. Verdicts are read
\ two ways: content probes grep the sentinel-bounded dump; computed probes
\ emit a Forth-side `result=-1`.
\
\ Mechanism (shipped Story 20.1, verified 20.2; this story writes NO kernel
\ code): every dictionary link is an inline 24-bit fat pointer
\ [addr:2][bank:1]; FIND and WORDS page active_pages[bank] into slot 2
\ before reading a window-resident header, then restore the caller's page.
\ The bank travels with each pointer, so a name resolves by its own header's
\ bank regardless of the current bank. Refs: docs/antforth-banking-redesign.md
\ §5.5 / §5.4; FR-P4-29 (verified), FR-P4-30 (retired).
\
\ Parked in bank 0 for every WORDS / lookup (HERE fixed, < $8000): the only
\ workable behavioural pattern — a foreign-bank-mapped token lookup would
\ strand at -13 (ADR 19.5 DR-1 aliasing). FIND/WORDS page foreign banks in
\ and out themselves, so driving from bank 0 is safe.

DECIMAL

\ Self-contained slot-2 shadow reader (MBB_GET_PAGE, logical page 2), used by
\ probe (c)'s restore witness; defined inline so the fixture loads standalone
\ (mirrors tests/banking_tests_20_1.fth / _20_2.fth).
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
\ One WORDS run from bank 0 must show _w53a (bank 5), _w53b (bank 6) and
\ _w53c (bank 7) — per-entry fat-pointer page-in reaches all three headers.
." ---probe-20.3-a-start---" CR
WORDS
." ---probe-20.3-a-end---" CR

\ --- Probe-20.3-b: bank-aware FIND resolves each name to its home bank -----
\ From bank 0, `'` (FIND) finds a name whose header lives in another bank,
\ and BANK-OF reports it: _w53a -> 5, _w53c -> 7. verdict = both correct.
." ---probe-20.3-b-start---" CR
' _w53a BANK-OF 5 =                  \ ( f1 )
' _w53c BANK-OF 7 =                  \ ( f1 f2 )
AND                                  \ ( verdict )
." result=" . CR
." ---probe-20.3-b-end---" CR

\ --- Probe-20.3-c: bank + slot-2 restored after WORDS + FIND traversals ----
\ Snapshot BANK@ and the slot-2 page, run WORDS and two name lookups (each
\ pages a foreign bank in), then re-read; assert both unchanged.
." ---probe-20.3-c-start---" CR
BANK@ MBB-GET-2                       \ ( b0 s0 )
WORDS                                \ pages banks 5/6/7 in, restores on exit
' _w53a BANK-OF DROP                 \ FIND pages bank 5 in/out
' _w53c BANK-OF DROP                 \ FIND pages bank 7 in/out
MBB-GET-2 BANK@                      \ ( b0 s0 s1 b1 )
>R ROT R> = >R = R> AND              \ ( verdict )
." result=" . CR
." ---probe-20.3-c-end---" CR

\ --- Probe-20.3-d: FR-P4-30 retired — typo gives plain <word> ? -----------
\ An undefined word produces the standard `?NOSUCH? ?` with NO bank suffix;
\ QUIT catches the -13 and resumes, so the end sentinels still print.
." ---probe-20.3-d-start---" CR
?NOSUCH?
." ---probe-20.3-d-end---" CR

." ---probe-20.3-suite-end---" CR
BYE
