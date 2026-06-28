\ ============================================================================
\ Story 23.9 (PROVISIONAL number) — complete banked window-top guard coverage.
\ ============================================================================
\ Stories 23.6/23.7 guarded the fixed-width store primitives (, C, COMPILE,
\ ALLOT), the defining-word header (build_header), and MARKER. This probe
\ covers the five remaining banked dictionary-growth paths that were writing
\ to HERE through their own hand-rolled stores with no headroom check:
\   A  `;`      — EXIT_CODE (2 B)                       src/compiler.asm
\   B  LITERAL  — LIT xt + value cell (4 B)             src/compiler.asm
\   C  DOES>    — (DOES>) xt (2 B)                       src/compiler.asm
\   D  S"       — inline counted string (arbitrary len) src/strings.asm
\   E  ."       — inline string + TYPE xt               src/strings.asm
\   F  ABORT"   — inline counted string (arbitrary len) src/system.asm
\ Each now raises a clean uncaught -8 ("dictionary overflow") when it would
\ place a byte at/past the slot-2 window top ($C000). G proves the guard does
\ NOT over-reject a banked definition that fits; H proves it stays a strict
\ no-op on bank 0 (fixed memory).
\
\ HARNESS NOTES (mirror banking_tests_23_7.fth — do NOT "simplify" to CATCH):
\  * UNCAUGHT-throw form: the -8 is reported by the QUIT loop ("error -8:
\    dictionary overflow") then recovered (ABORT resets the data stack + STATE;
\    Story 21.2 re-asserts the saved bank). CATCH/EVALUATE recovery is fragile
\    under piped console stdin (feedback_phase4_probe_bank_switch_limitation).
\  * Drivers run at INTERPRET level; the brink is reached by ALLOT, and each
\    compile-time word is driven to the brink via a `[ ... ALLOT ]` bracket so
\    the definition HEADER lands safely in-window first (a fresh bank's HERE is
\    the kernel_end clone ~$7277, so the leading ALLOT walks HERE up into the
\    $8000..$BFFF window before the header is built).
\  * Liveness + accept witnesses are RUNTIME-COMPUTED tokens (`===42` from
\    `6 7 *`, `G-OK=-1` from `U<`), never bare sentinels: iz-cpm echoes piped
\    stdin, so an echo-only gate would pass even if the interpreter wedged
\    (the echo-only-gate trap that 23-6/23-7/23-9 all avoid via a computed token).
\ Piped to stdin; the Makefile appends BYE. No 0x1A EOF terminator needed.
\ ============================================================================

DECIMAL
." ===23-9-PROBE-START===" CR

\ Each case reseeds the bank table from scratch via _RS (BANKS-CLEAR + 8x $22
\ +BANK → logical banks 0..7, one physical page $22 in each). A reseed PER CASE
\ is load-bearing: a banked definition that throws -8 leaves a committed
\ SMUDGEd header behind, and several of those accumulate into bank bucket-chain
\ corruption that breaks FIND inside the NEXT banked definition
\ (feedback_phase4_probe_bank_switch_limitation). Reseeding before each case
\ keeps every case independent. _RS is a bank-0 (fixed-memory) word, findable
\ from any bank.  \ LINT-ALLOW-BANK: N/A (this is an isolated 23-9 fixture, not
\ the in-suite banking_tests.fth)
: _RS BANKS-CLEAR
  $22 +BANK $22 +BANK $22 +BANK $22 +BANK
  $22 +BANK $22 +BANK $22 +BANK $22 +BANK ;

\ --- A (`;`): EXIT (2 B) one past the top → -8. HERE driven to $BFFF so the
\ EXIT cell would touch $BFFF..$C000 (prospective $C001 > $C000).
." ---A-start---" CR
_RS  1 BANK!  $C000 HERE - 300 - ALLOT
: WA [ $C000 HERE - 1 - ALLOT ] ;
." ---A-end---" CR

\ --- B (LITERAL): LIT xt + value cell (4 B) over the top → -8. HERE at $BFFE,
\ the 4-byte LIT cell would reach $C001.
." ---B-start---" CR
_RS  2 BANK!  $C000 HERE - 300 - ALLOT
: WB [ $C000 HERE - 2 - ALLOT 5 ] LITERAL ;
." ---B-end---" CR

\ --- C (DOES>): (DOES>) xt (2 B) over the top → -8. HERE at $BFFF.
." ---C-start---" CR
_RS  3 BANK!  $C000 HERE - 300 - ALLOT
: WC [ $C000 HERE - 1 - ALLOT ] DOES> ;
." ---C-end---" CR

\ --- D (S"): inline-string body crosses the top → -8 (per-char guard). HERE at
\ $BFFC so the (S") framing fits but the 12-char body runs into $C000.
." ---D-start---" CR
_RS  4 BANK!  $C000 HERE - 300 - ALLOT
: WD [ $C000 HERE - 4 - ALLOT ] S" AAAAAAAAAAAA" ;
." ---D-end---" CR

\ --- E ("): same as D for the ." compiler (compile_string + TYPE xt).
." ---E-start---" CR
_RS  5 BANK!  $C000 HERE - 300 - ALLOT
: WE [ $C000 HERE - 4 - ALLOT ] ." AAAAAAAAAAAA" ;
." ---E-end---" CR

\ --- F (ABORT"): inline-string body crosses the top → -8 (per-char guard).
." ---F-start---" CR
_RS  6 BANK!  $C000 HERE - 300 - ALLOT
: WF [ $C000 HERE - 4 - ALLOT ] ABORT" AAAAAAAAAAAA" ;
." ---F-end---" CR

\ --- G (accept): a banked definition that FITS is accepted — the guard must
\ not over-reject. Far below $C000; runtime witness G-OK=-1 (HERE U< $C000).
." ---G-start---" CR
_RS  7 BANK!  $C000 HERE - 300 - ALLOT
: WG S" hi" 2DROP ;
." G-OK=" HERE $C000 U< . CR
." ---G-end---" CR

\ --- H (bank-0 no-op): the SAME near-top `;` that throws in a bank is a strict
\ no-op on bank 0 (fixed memory). No -8 in the span; runtime witness H-DONE=7.
." ---H-start---" CR
_RS  0 BANK!  $C000 HERE - 300 - ALLOT
: WH [ $C000 HERE - 1 - ALLOT ] ;
." H-DONE=" 3 4 + . CR
." ---H-end---" CR

_RS 0 BANK!
\ Computed liveness witness: `===42` only ever appears at runtime (`6 7 *`);
\ the echoed source line carries `===" 6 7 * . CR` but never the contiguous
\ `===42`, so the gate proves genuine end-to-end execution, not echo.
." ===23-9-PROBE-ALIVE===" 6 7 * . CR
