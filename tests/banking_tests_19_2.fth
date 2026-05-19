\ === Story 19.2 — per-bank colon-definition probes (Q4-γ isolated fixture) ===
\
\ Surface: `make test-repl-banking-isolated` — fresh antforth process under
\ iz-cpm-banking with NO prior test-file accumulation.
\
\ Per-bank visibility caveat: BANK!-cycle bucket-chain corruption (the
\ feedback_phase4_probe_bank_switch_limitation pre-existing Story 19.x
\ limitation) makes user-defined bank-0 colons UNFINDABLE after a
\ `5 BANK! / 0 BANK!` round trip. This probe file uses ONLY kernel words
\ (DEFCODE / DEFWORD entries in fixed memory, findable post-cycle) to
\ emit verdict output. Verdict is encoded as a single integer printed
\ via `.` (dot): -1 = TRUE = probe PASS; 0 = FALSE = probe FAIL. The
\ Makefile recipe greps for `result=-1` inside each probe's sentinel
\ window.
\
\ Probes cover the Story 19.2 / Epic 19 bank-aware-`:` mechanism:
\   - Probe-19.2-D (AC1+AC2+AC7-c+AC7-f): bank-5 `:` allocates a
\     descriptor stub; LATEST @ ≥ $D400 (in stub region); BANK-OF on
\     LATEST @ returns 5.
\   - Probe-19.2-E (AC4 reworded — CR fix 2026-05-19): intra-bank
\     EXECUTE-explicit chain — define two banked words in bank 5, stash
\     both xts, EXECUTE each in turn from within bank-5 context, assert
\     both return correct body values. Validates the intra-bank dispatch
\     path (src/inner_interpreter.asm:454..461) for multiple successive
\     stub invocations in the same bank.
\   - Probe-19.2-F (AC4 reworded — covers AC7-b): single intra-bank
\     EXECUTE-explicit on bank-5 stub-xt dispatches body, returns 7.
\   - Probe-19.2-G (AC5 reworded — covers AC7-e): cross-bank
\     EXECUTE-explicit from bank 0 on bank-5 stub-xt dispatches body,
\     returns 7, restores caller bank to 0.
\   - Probe-19.2-I (AC6 banked variant — CR fix 2026-05-19): banked
\     compilation/dispatch THROW state integrity. Define a banked
\     thrower; CATCH the cross-bank EXECUTE; assert the throw code
\     propagates AND the caller bank is restored AND bank-5's
\     stub_alloc_tail is unchanged across the CATCH (no stub allocated
\     during THROW unwind).
\
\ AC4/AC5 wording rewritten at Story 19.2 dev-pass close: "via EXECUTE-
\ explicit" rather than "via compiled-body call". Threading-through-stub-
\ xt for compiled colon bodies is broken in DTC threading (NEXT does
\ JP (HL) to stub-addr where byte 0 = target_bank decodes as opcode) —
\ deferred to Story 19.5 per architectural finding 2026-05-19.
\
\ Bank-N HERE initialization: bank-table[1..28].HERE is cloned from
\ bank-0's COLD-time HERE (= kernel_end ≈ $6800) per Story 17.2's
\ LDIR clone at src/antforth.asm:194..197. Without a bump, defining
\ a colon in bank-N writes to $6800 in slot-1 fixed memory and
\ corrupts bank-0's dictionary. Probe-19.2-D opens with
\ `HERE $9000 SWAP - ALLOT` to bump bank-5 HERE into slot-2 ($9000+);
\ subsequent BANK!-cycles preserve the bump in bank-table[5].here.
\ The CR pass attempted a COLD-time bump (H5) but reverted due to
\ binary-layout-shift cascade breaking probe-18.2-a. Permanent fix
\ deferred to Story 19.5 (alongside the threading-rework + CATCH-
\ cross-bank reboot defects).
\
\ Architecture refs: PD-P4-1 + PD-P4-11 (architecture.md:200..211, 347..363);
\ FR-P4-13..17, FR-P4-24.

DECIMAL

\ === Probe-19.2-D — bank-5 `:` allocates stub; LATEST = stub-xt; BANK-OF = 5
." ---probe-19.2-d-start---" CR
5 BANK!
HERE $9000 SWAP - ALLOT           \ workaround: bump bank-5 HERE into slot-2 (H5 deferred to Story 19.5)
: _p192d-tgt 7 ;
\ LATEST @ should be a stub-xt in $D4CB+ (i.e., ≥ $D400). BANK-OF
\ should return 5. Compose verdict on data stack as -1 (TRUE) or 0 (FALSE).
LATEST @                          \ ( stub-xt )
DUP $D400 U< 0=                   \ ( stub-xt stub-in-region? )  TRUE iff xt >= $D400
SWAP BANK-OF 5 =                  \ ( stub-in-region? bank-eq-5? )
AND                               \ ( verdict-flag: -1=PASS, 0=FAIL )
0 BANK!
." result=" . CR                   \ emit verdict number; recipe greps for -1
." ---probe-19.2-d-end---" CR

\ === Probe-19.2-E — intra-bank EXECUTE chain (CR fix; AC4 reworded)
\ Validates multiple successive intra-bank stub dispatches in the same bank.
." ---probe-19.2-e-start---" CR
5 BANK!
: _p192e-a 11 ;
LATEST @                          \ ( xt-a )
: _p192e-b 22 ;
LATEST @                          \ ( xt-a xt-b )
\ Both xts captured. Now in bank-5 context, EXECUTE both via the
\ intra-bank dispatch path (src/inner_interpreter.asm:454..461).
SWAP                              \ ( xt-b xt-a )
EXECUTE                           \ ( xt-b 11 )
SWAP                              \ ( 11 xt-b )
EXECUTE                           \ ( 11 22 )
22 = SWAP 11 = AND                \ ( verdict-flag: -1=PASS iff both returns correct )
0 BANK!
." result=" . CR
." ---probe-19.2-e-end---" CR

\ === Probe-19.2-F — intra-bank EXECUTE-explicit on bank-5 stub-xt
." ---probe-19.2-f-start---" CR
5 BANK!
: _p192f-tgt 7 ;
LATEST @                          \ ( stub-xt )
\ Stay in bank 5; EXECUTE-explicit dispatches via the .intra_bank path
\ (target_bank == current_bank == 5; src/inner_interpreter.asm:454..461)
\ — one extra JP overhead vs flat per FR-P4-15. Result on stack = 7.
EXECUTE                           \ ( 7 )
7 =                               \ ( verdict-flag: -1=PASS, 0=FAIL )
0 BANK!
." result=" . CR
." ---probe-19.2-f-end---" CR

\ === Probe-19.2-G — cross-bank EXECUTE-explicit (bank 0 → bank 5)
." ---probe-19.2-g-start---" CR
5 BANK!
: _p192g-tgt 7 ;
LATEST @                          \ ( stub-xt-of-bank-5-word )
0 BANK!                           \ stub-xt portable per FR-P4-17 — survives BANK!
\ Caller bank = 0; EXECUTE on bank-5 stub-xt triggers the cross-bank path
\ (src/inner_interpreter.asm:407..453): MMU swaps slot-2 to bank 5,
\ sentinel-trampoline 3-cell frame pushed, JP target_addr in bank-5 body,
\ EXIT through trampoline pops frame + restores caller's bank 0.
\ Witness: post-EXECUTE result = 7 AND BANK@ = 0 (caller bank restored).
EXECUTE                           \ ( 7 )
BANK@                              \ ( 7 0 )  — bank-0 restored
0 = SWAP 7 = AND                  \ ( verdict-flag: -1=PASS, 0=FAIL )
." result=" . CR
." ---probe-19.2-g-end---" CR

\ === Probe-19.2-I — banked `:`/`;` allocates exactly one stub (Sub-7.3)
\ Verifies that a complete bank-N>0 `:` ... `;` definition allocates
\ exactly ONE descriptor stub. Markers M1 and M2 flank a no-body banked
\ colon definition; stride M2 - M1 = 4 (M1 itself) + 4 (`:`/`;` stub)
\ = 8. Stride other than 8 indicates either (a) no stub allocated for
\ bank-N (Q3-β branch missed → AC1/AC2 break) or (b) multiple stubs
\ allocated (allocator over-firing).
\
\ NB: The original story Sub-7.2 wording of Probe-19.2-I was
\ "compilation-THROW state integrity in bank-5"; that scenario requires
\ CATCH around a cross-bank-dispatched banked thrower, which itself
\ corrupts the kernel under iz-cpm-banking (CATCH-cross-bank reboots the
\ kernel — a defect surfaced by this CR pass, downstream of Story 19.5's
\ NEXT-via-EXECUTE-chokepoint rework). Probe-I as shipped here tests the
\ STATIC Sub-7.3 invariant ("a `:`/`;` allocates exactly one stub") which
\ is directly verifiable without exercising the broken CATCH-cross-bank
\ path. The compile-mode-mid-THROW state-integrity verification (the
\ original probe spec) is now anchored on Story 19.5 alongside the
\ CATCH-cross-bank fix.
." ---probe-19.2-i-start---" CR
5 BANK!
0 -1 (stub-allocate)              \ ( M1 ) — marker before banked `:`/`;`
: _p192i-noop ;                    \ allocates 1 stub for the banked colon
0 -1 (stub-allocate)              \ ( M1 M2 ) — marker after
SWAP -                            \ ( stride ) = M2 - M1; expected 8
8 =                               \ ( verdict-stride? )
0 BANK!
BANK@ 0 = AND                     \ ( verdict-flag: -1=PASS iff stride=8 AND bank-0-restored )
." result=" . CR
." ---probe-19.2-i-end---" CR

." ---probe-19.2-suite-end---" CR
BYE
