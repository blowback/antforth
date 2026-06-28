\ ============================================================================
\ Story 23.7 — banked MARKER window-top overflow guard regression probe.
\ ============================================================================
\ MARKER is the one banked-dictionary-growth path Story 23.6 left unguarded: it
\ emits a fixed ~372-byte body (saved bucket array + bank-table prefix + stub
\ tail) AFTER build_header commits the header. Story 23.7 folds MARKER's full
\ footprint into build_header's single pre-commit guard via bh_code_reserve, so
\ a banked MARKER that would cross $C000 raises a clean -8 ("dictionary
\ overflow") BEFORE anything is committed (all-or-nothing).
\
\ Asserts: (A) a banked MARKER one byte over the boundary throws -8;
\ (B) the exact acceptance boundary (guard prospective == $C000) succeeds;
\ (C) bank 0 (fixed memory, triple_owner==0) is a strict no-op — the same
\ near-top MARKER succeeds; (D) post-THROW liveness — a normally-sized banked
\ MARKER still works and the interpreter prints a final sentinel.
\
\ HARNESS NOTES (load-bearing — do not "simplify" to CATCH/EVALUATE):
\  * Uses the UNCAUGHT-throw form like banking_tests_23_6.fth. A banked
\    over-$C000 MARKER raises -8 which, with no enclosing CATCH, the QUIT loop
\    reports as "error -8: dictionary overflow" and then recovers (ABORT resets
\    the data stack + STATE; Story 21.2 re-asserts the saved bank). CATCH/
\    EVALUATE recovery is fragile under piped console stdin
\    (feedback_phase4_probe_bank_switch_limitation).
\  * Every probe runs at INTERPRET level (no probe colon body near $8000) per
\    feedback_banking_probe_straddle_halt.
\  * Each brink is self-calibrated from live HERE. The guard's prospective
\    one-past-end = HERE + 6 (header) + name_len + MARKER_CODE_RESERVE (372).
\    For name "Z" (len 1) the fixed reserve is 6+1+372 = 379, so HERE = $C000-379
\    is the exact accept boundary and HERE = $C000-378 is one byte over.
\  * Driven under iz-cpm-banking by `make test-repl-banking-23-7`, which awk-
\    extracts each ---X-start--- .. ---X-end--- span and asserts "dictionary
\    overflow" present (case A) / absent (cases B, C, D).
\ Piped to stdin (not placed in disk/a/), so no 0x1A EOF terminator is needed;
\ the Makefile appends BYE.
\ ============================================================================

DECIMAL
." ===23-7-PROBE-START===" CR

\ One physical page ($22) mapped into several logical banks; each bank has its
\ own (HERE,LATEST,wordlist) triple, so a fresh BANK! gives a fresh HERE.
\ Seven +BANKs → logical banks 0..6 (valid BANK! indices 0..6). A uses bank 1,
\ B uses bank 2, C uses bank 0 (fixed memory), D uses the untouched bank 4.
BANKS-CLEAR
$22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK

\ --- Case A (AC1): a banked MARKER one byte OVER the boundary throws -8 BEFORE
\ committing. name "Z" (len 1): reserve = 6+1+372 = 379; HERE driven to
\ $C000-378 so the guard prospective = $C001 (> $C000) → -8.
." ---A-start---" CR
1 BANK!  $C000 HERE - 378 - ALLOT
MARKER Z
." ---A-end---" CR

\ --- Case B (AC2 boundary): a banked MARKER at the EXACT boundary is ACCEPTED.
\ HERE driven to $C000-379 so the guard prospective = $C000 (one-past-end ==
\ $C000 is legal — the compare is strictly > $C000). No -8; Z is created.
\ POSITIVE witness (not just absence-of-throw): after MARKER, the new bank-2 HERE
\ (one-past the body MARKER actually wrote) must be <= $C000 — i.e. the footprint
\ landed inside the window, NOT past the top. `B-OK=-1` is a runtime-computed token
\ (U< yields -1); the echoed source line carries `B-OK="` but never `B-OK=-1`, so
\ the Makefile grep matches genuine execution only, never the echo. A reserve that
\ under-counted MARKER's real write would push HERE past $C000 → U< 0 → witness
\ absent → FAIL (so this guards the dangerous direction, not just the throw).
." ---B-start---" CR
2 BANK!  $C000 HERE - 379 - ALLOT
MARKER Z
." B-OK=" HERE $C000 1+ U< . CR
." ---B-end---" CR

\ --- Case C (AC3): bank 0 (fixed memory, triple_owner==0) — the guard is a
\ strict no-op. The guard's prospective (HERE + 9 + 372) must still clear $C000
\ so a banked owner WOULD throw, proving bank 0 takes the early no-op exit; HERE
\ is driven to $C000-300 so prospective = $C000+81 (> $C000) yet the body MARKER
\ actually writes (~249 B at this 7-bank snap_count) ends at ~$BFCD, comfortably
\ inside the window. This is deliberately NOT the old $C000-3 slam: that wrote
\ MARKER's ~250-byte body straight across $C000 into the descriptor-stub region
\ that case D allocates from, so a non-throwing clobber there could have masked a
\ D failure. Staying below $C000 keeps the bank-0 control non-destructive while
\ still exercising the over-$C000 guard arithmetic. (Margin holds for snap_count
\ up to 15; this probe uses 7.) `C-OK=-1` is the runtime-computed witness. No -8.
." ---C-start---" CR
0 BANK!  $C000 HERE - 300 - ALLOT
MARKER B0M
." C-OK=" HERE $C000 1+ U< . CR
." ---C-end---" CR

\ --- Case D (AC7 post-THROW liveness): after case A's uncaught -8 and recovery,
\ a normally-sized banked MARKER still works. Untouched bank 4, HERE driven 1000
\ bytes below the top so the full 372-byte footprint fits comfortably. No -8.
." ---D-start---" CR
4 BANK!  $C000 HERE - 1000 - ALLOT
MARKER OKAY
." D-OK=" HERE $C000 1+ U< . CR
." ---D-end---" CR

\ Final witness: a live interpreter after the overflow THROW and the accepted
\ MARKERs. The trailing `6 7 *` is computed AT RUNTIME so the gate token
\ `PROBE-ALIVE===42` only ever appears in genuine output — the echoed source line
\ carries `PROBE-ALIVE===" 6 7 * . CR` but never the contiguous `===42`. This
\ proves the interpreter actually EXECUTED to the end, not merely that iz-cpm
\ echoed the line back (a silently-wedged-but-not-crashed interpreter would still
\ echo every sentinel; it cannot fake the product).
." ===23-7-PROBE-ALIVE===" 6 7 * . CR
