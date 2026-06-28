\ ============================================================================
\ Story 23.6 — banked dictionary window-top overflow guard regression probe.
\ ============================================================================
\ Asserts that a banked definition (or raw dictionary growth) that would place
\ any byte AT OR PAST the slot-2 window top ($C000) raises a clean -8
\ ("dictionary overflow") THROW before committing, and that the boundary case
\ (a word whose last byte is exactly $BFFF) and bank 0 (fixed memory) are
\ unaffected.
\
\ HARNESS NOTES (load-bearing — do not "simplify" back to CATCH/EVALUATE):
\  * Uses the UNCAUGHT-throw form. A banked over-$C000 op raises -8 which, with
\    no enclosing CATCH, the QUIT loop reports as "error -8: dictionary
\    overflow" and then recovers (ABORT resets the data stack + STATE,
\    Story 21.2 re-asserts the bank). CATCH/EVALUATE recovery is fragile under
\    piped console stdin (feedback_phase4_probe_bank_switch_limitation), and an
\    uncaught throw cleanly resets compile STATE for the colon-body case.
\  * Every probe runs at INTERPRET level (no probe colon body of its own near
\    $8000) per feedback_banking_probe_straddle_halt.
\  * The brink is self-calibrated from live HERE ($C000 HERE - k - ALLOT), so it
\    is robust to whatever HERE a freshly-visited bank starts at (the per-bank
\    triple is kernel_end-cloned at COLD, ~ $7277 — below $8000 — so each ALLOT
\    advances HERE up through the window to the $C000 brink).
\  * Driven under iz-cpm-banking by `make test-repl-banking-23-6`, which awk-
\    extracts each ---X-start--- .. ---X-end--- span and asserts "dictionary
\    overflow" present (cases A-D) / absent (cases E,F).
\ Piped to stdin (not placed in disk/a/), so no 0x1A EOF terminator is needed.
\ ============================================================================

DECIMAL
." ===23-6-PROBE-START===" CR

\ One physical page ($22) is mapped into several logical banks; each bank has
\ its own (HERE,LATEST,wordlist) triple, so a fresh BANK! gives a fresh HERE.
\ Seven +BANKs → logical banks 0..6 (cases A-E use banks 1-5; F uses bank 0;
\ G uses bank 6).
BANKS-CLEAR
$22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK

\ --- Case A (AC1): a defining word (VALUE) whose code field would cross $C000
\ raises -8 BEFORE committing the header. HERE driven to $BFFD (3 below top).
." ---A-start---" CR
1 BANK!  $C000 HERE - 3 - ALLOT
42 VALUE VAAAA
." ---A-end---" CR

\ --- Case B (AC2): a banked colon BODY that grows across $C000 via COMPILE,
\ raises -8 at the offending cell (the header fits; the 16 compiled DUP xts
\ overrun the window top).
." ---B-start---" CR
2 BANK!  $C000 HERE - 24 - ALLOT
: BBBB DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP ;
." ---B-end---" CR

\ --- Case C (AC3): raw ALLOT past the top raises -8 (HERE 2 below top, +100).
." ---C-start---" CR
3 BANK!  $C000 HERE - 2 - ALLOT
100 ALLOT
." ---C-end---" CR

\ --- Case D (AC3): raw , (cell store) straddling the top raises -8 (HERE at
\ $BFFF; the 2-byte cell would touch $BFFF..$C000).
." ---D-start---" CR
4 BANK!  $C000 HERE - 1 - ALLOT
999 ,
." ---D-end---" CR

\ --- Case E (AC1 boundary): a VALUE whose LAST byte is exactly $BFFF is
\ ACCEPTED (one-past-end == $C000 is legal). namelen 1 → 12-byte footprint;
\ HERE driven to $C000-12 = $BFF4 so the value cell ends at $BFFF. No -8.
." ---E-start---" CR
5 BANK!  $C000 HERE - 12 - ALLOT
42 VALUE Z
." ---E-end---" CR

\ --- Case F (AC4): bank 0 (fixed memory, triple_owner==0) — the guard is a
\ strict no-op. The SAME near-top VALUE that throws in a bank succeeds here
\ (fixed-memory HERE legitimately runs past $C000). No -8.
." ---F-start---" CR
0 BANK!  $C000 HERE - 3 - ALLOT
42 VALUE B0
." ---F-end---" CR

\ --- Case G (AC3 wrap guard): a banked POSITIVE ALLOT large enough that the
\ 16-bit HERE+n add wraps past $FFFF must still raise -8, not silently corrupt
\ HERE to a low address (the wrapped prospective lands below $C000 and would
\ otherwise slip past the headroom predicate). HERE driven to $BFFE, then a
\ +$7000 (28672-byte) request wraps the add. bit15 of $7000 is clear, so it is
\ a genuine positive allocation, not a signed-negative release.
." ---G-start---" CR
6 BANK!  $C000 HERE - 2 - ALLOT
$7000 ALLOT
." ---G-end---" CR

\ Final witness: a live interpreter after all seven cases.
." ===23-6-PROBE-ALIVE===" CR
