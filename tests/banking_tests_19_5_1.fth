\ === Story 19.5.1 — F2 bank-N first-visit HERE probe (isolated fixture) ===
\
\ Surface: `make test-repl-banking-isolated-19-5-1` — fresh antforth
\ process under iz-cpm-banking with NO prior test-file accumulation.
\
\ Why isolated: the main-suite (banking_tests.fth) dictionary crosses
\ $8000 long before its tail, so its bank-shared hash-bucket chains
\ contain window-resident entries; ANY token lookup while a foreign
\ bank is mapped can walk a chain through the window and read the
\ foreign page (-13 strand; observed at 19.5.1 dev-pass) -- the same
\ portal-aliasing mechanism as ADR 19.5 DR-1, hit on the lookup path
\ instead of the threading path. In isolation the dictionary stays
\ below $8000, so interpreting across a BANK! cycle is safe (the same
\ property the 19.2/19.3/19.4 isolated fixtures rely on). The main
\ suite carries the table-read witness (probe-19.5.1-b: $D406 @); this
\ fixture carries the behavioural switch witness.
\
\ The probe uses ONLY kernel words (no colon definitions at all), so
\ nothing here depends on cross-bank findability of user words.
\ Verdict encoding per isolated-fixture convention: `result=` +
\ integer, -1 = PASS, 0 = FAIL; the Makefile recipe greps result=-1
\ inside the sentinel window.

DECIMAL

\ === Probe-19.5.1-C — F2 behavioural: first visit to fresh bank 1 shows HERE = $8000
\ COLD set bank-table[1..28].here = $8000 (src/antforth.asm, Story
\ 19.5.1 F2 -- the re-landed 19.2-H5 fix). Bank 1 is fresh here (no
\ prior visit in this process), so BANK!'s triple-load must surface
\ HERE = $8000 exactly: bank-N bodies are page-resident from byte 0.
." ---probe-19.5.1-c-start---" CR
BANKS-CLEAR  $22 +BANK  $35 +BANK
0 BANK!
1 BANK! HERE 0 BANK!
$8000 =                           \ ( verdict-flag: -1 iff bank-1 first-visit HERE = $8000 )
." result=" . CR
." ---probe-19.5.1-c-end---" CR
0 BANK!
BANKS-CLEAR

\ Suite-end witness: reaching this line means no probe stranded the
\ interpreter in a foreign bank or hung the kernel mid-suite.
." ---probe-19.5.1-suite-end---" CR
