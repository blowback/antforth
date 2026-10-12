\ ============================================================================
\ Story 23.6 — banked dictionary window-top overflow guard regression probe.
\ ============================================================================
\ Asserts that a banked definition (or raw dictionary growth) that would place
\ any byte AT OR PAST the banked ceiling ($BF58 = $C000 less the 168-byte
\ WORD/PAD reserve) raises a clean -8 ("dictionary overflow") THROW before
\ committing, and that the boundary case (a word whose last byte is exactly
\ $BF57) and bank 0 (fixed memory) are unaffected.
\
\ HARNESS NOTES (load-bearing — do not "simplify" back to CATCH/EVALUATE):
\  * Uses the UNCAUGHT-throw form. A banked over-ceiling op raises -8 which, with
\    no enclosing CATCH, the QUIT loop reports as "error -8: dictionary
\    overflow" and then recovers (ABORT resets the data stack + STATE,
\    Story 21.2 re-asserts the bank). CATCH/EVALUATE recovery is fragile under
\    piped console stdin (feedback_phase4_probe_bank_switch_limitation), and an
\    uncaught throw cleanly resets compile STATE for the colon-body case.
\  * Every probe runs at INTERPRET level (no probe colon body of its own near
\    $8000) per feedback_banking_probe_straddle_halt.
\  * The brink is self-calibrated from live HERE ($BF58 HERE - k - ALLOT), so it
\    is robust to whatever HERE a freshly-visited bank starts at (the per-bank
\    triple is kernel_end-cloned at COLD, ~ $7277 — below $8000 — so each ALLOT
\    advances HERE up through the window to the $BF58 brink).
\  * Driven under iz-cpm-banking by `make test-repl-banking-23-6`, which awk-
\    extracts each ---X-start--- .. ---X-end--- span and asserts "dictionary
\    overflow" present (cases A-D) / absent (cases E,F).
\ Piped to stdin (not placed in disk/a/), so no 0x1A EOF terminator is needed.
\ ============================================================================

DECIMAL
." ===23-6-PROBE-START===" CR

\ Seven distinct pages → logical banks 0..6 (cases A-E use banks 1-5; F uses
\ bank 0; G uses bank 6). Each bank has its own (HERE,LATEST,wordlist) triple,
\ so a fresh BANK! gives a fresh HERE.
BANKS-CLEAR
$22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK $3A +BANK

\ --- Case A (AC1): a defining word (VALUE) whose code field would cross the
\ ceiling raises -8 BEFORE committing the header. HERE driven to $BF55 (3 below).
." ---A-start---" CR
1 BANK!  $BF58 HERE - 3 - ALLOT
42 VALUE VAAAA
." ---A-end---" CR

\ --- Case B (AC2): a banked colon BODY that grows across the ceiling via
\ COMPILE, raises -8 at the offending cell (the header fits; the 16 compiled DUP
\ xts overrun the ceiling).
." ---B-start---" CR
2 BANK!  $BF58 HERE - 24 - ALLOT
: BBBB DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP DUP ;
." ---B-end---" CR

\ --- Case C (AC3): raw ALLOT past the ceiling raises -8 (HERE 2 below, +100).
." ---C-start---" CR
3 BANK!  $BF58 HERE - 2 - ALLOT
100 ALLOT
." ---C-end---" CR

\ --- Case D (AC3): raw , (cell store) straddling the ceiling raises -8 (HERE at
\ $BF57; the 2-byte cell would touch $BF57..$BF58).
." ---D-start---" CR
4 BANK!  $BF58 HERE - 1 - ALLOT
999 ,
." ---D-end---" CR

\ --- Case E (AC1 boundary): a VALUE whose LAST byte is exactly $BF57 is
\ ACCEPTED (one-past-end == $BF58 is legal). namelen 1 → 12-byte footprint;
\ HERE driven to $BF58-12 = $BF4C so the value cell ends at $BF57. No -8.
." ---E-start---" CR
5 BANK!  $BF58 HERE - 12 - ALLOT
42 VALUE Z
." ---E-end---" CR

\ --- Case F (AC4): bank 0 (fixed memory, triple_owner==0) — the guard is a
\ strict no-op. The SAME near-top VALUE that throws in a bank succeeds here
\ (fixed-memory HERE legitimately runs past $C000). No -8. B0's header
\ straddles $C000, so case H checks that bank 6's WORD/PAD traffic at its
\ ceiling (case G) left it intact.
." ---F-start---" CR
0 BANK!  $C000 HERE - 3 - ALLOT
42 VALUE B0
." ---F-end---" CR

\ --- Case G (AC3 wrap guard): a banked POSITIVE ALLOT large enough that the
\ 16-bit HERE+n add wraps past $FFFF must still raise -8, not silently corrupt
\ HERE to a low address (the wrapped prospective lands below $C000 and would
\ otherwise slip past the headroom predicate). HERE driven to $BF56, then a
\ +$7000 (28672-byte) request wraps the add ($BF56+$7000 = $12F56). bit15 of
\ $7000 is clear, so it is a genuine positive allocation, not a signed-negative
\ release.
." ---G-start---" CR
6 BANK!  $BF58 HERE - 2 - ALLOT
$7000 ALLOT
." ---G-end---" CR

\ --- Case H: back in bank 0, F's B0 still reads 42. Before the ceiling took
\ the WORD/PAD reserve, bank 6's parse buffer at $BF56+ ran into $C000+ and
\ overwrote B0's name.
0 BANK!  ." ---H-B0=" B0 . CR

\ Final witness: a live interpreter after all eight cases. The trailing `6 7 *`
\ is computed AT RUNTIME so the gate token `===42` only ever appears in genuine
\ output — the echoed source line carries `===" 6 7 * . CR` but never the
\ contiguous `===42`. A silently-wedged interpreter would still echo this line
\ but cannot fake the product (matches banking_tests_23_7.fth's ALIVE gate).
." ===23-6-PROBE-ALIVE===" 6 7 * . CR
