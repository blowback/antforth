\ Story 22.1 - isolated behavioural .BANKS probe (bank-switch + define).
\ Kept out of the main suite: defining in a non-zero bank straddles the
\ portal-window dictionary (feedback_phase4_probe_bank_switch_limitation).
\ Verifies (a) per-bank used increases after defining a word in bank 5 from
\ the LIVE HERE (no BANK!-away needed); (b) totals reflect per-row used;
\ (c) the BANKED-WORDS / STUB-BYTES summary rows track the descriptor stubs.

5 BANK!
." ---probe-22.1-before---" CR
.BANKS
." ---probe-22.1-mid---" CR
: ISOWORD-A 1 2 + ;
: ISOWORD-B DUP * ;
.BANKS
." ---probe-22.1-after---" CR
0 BANK!
." ---probe-22.1-suite-end---" CR
