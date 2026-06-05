\ === Story 19.3 — per-bank CREATE/DOES> probes (Q4-γ isolated fixture) ===
\
\ Surface: `make test-repl-banking-isolated-19-3` — fresh antforth process
\ under iz-cpm-banking with NO prior test-file accumulation (Sub-5.8
\ parallel-target disposition per dev-pass-start AskUserQuestion).
\
\ Mirrors Story 19.2's tests/banking_tests_19_2.fth pattern: kernel-only
\ verdict emission (`. CR` integer flag, -1=PASS / 0=FAIL) to bypass
\ BANK!-cycle bucket-chain corruption per
\ feedback_phase4_probe_bank_switch_limitation. Sentinel-bounded
\ ---probe-19.3-X-start--- / ---probe-19.3-X-end--- markers per Story
\ 17.5.1 AC2 + Story 18.4/18.5/19.2 precedent.
\
\ Probes cover Story 19.3 / FR-P4-25 bank-aware CREATE / DOES>:
\   - Probe-19.3-D (AC1 / AC6-D): bank-5 CREATE allocates descriptor stub;
\     LATEST @ ≥ $D400 (stub region); BANK-OF on LATEST @ returns 5.
\   - Probe-19.3-E (AC6-E): intra-bank EXECUTE-explicit on bank-5 CREATE'd
\     word pushes body addr; intra-bank `@` retrieves stored 42.
\   - Probe-19.3-F (AC6-F): cross-bank EXECUTE-explicit from bank 0 on
\     bank-5 stub-xt dispatches body; caller bank tracking (BANK@) read
\     after the dispatch. Note: cross-bank data read via plain `@` after
\     EXECUTE returns is subject to the FR-P4-26 doc-and-pray cross-bank
\     pointer hazard (body-addr is in bank-5 slot-2; caller's @ may run
\     in different MMU context). Verdict checks both the data return and
\     the bank tracking to flag any state inconsistency.
\   - Probe-19.3-G (Q3-α DEFERRED): bank-5 CREATE/DOES> behavioural
\     surface is deferred — the DOES> body itself is a banked colon body
\     that hits the inherited DTC threading-through-stub-xt defect. Emits
\     a sentinel line `probe-19.3-g-deferred-on-cross-bank-thread-defect`
\     instead of running the dispatch. The Makefile recipe accepts the
\     defer-sentinel as a non-PASS, non-FAIL outcome (DEFER status).
\     Per Q3-α default chosen at dev-pass start AskUserQuestion 2026-05-20.
\
\ Bank-N HERE workaround: same as banking_tests_19_2.fth — open with
\ `5 BANK! HERE $9000 SWAP - ALLOT` to bump bank-5's COLD-time HERE
\ (cloned from bank-0's COLD HERE ≈ kernel_end) into slot-2 ($9000+).
\ Without the bump, bank-5 CREATE writes into slot-1 fixed memory and
\ corrupts bank-0 state. Permanent fix anchored on the architectural-
\ debt list inherited from Story 19.2 (bank-N HERE COLD-init bump).
\
\ Hash-collision avoidance: probe target names use disambiguated
\ `_p193X-tgt` form to dodge bucket-0 collision (Story 19.2 caveat).
\
\ Architecture refs: PD-P4-1 (architecture.md:200..211); PD-P4-11
\ (:347..363); FR-P4-13/17/25; redesign §2.1.

DECIMAL

\ === Probe-19.3-D — bank-5 CREATE allocates stub; LATEST = stub-xt; BANK-OF = 5
." ---probe-19.3-d-start---" CR
5 BANK!
HERE $9000 SWAP - ALLOT           \ bump bank-5 HERE into slot-2
CREATE _p193d-tgt 42 ,
LATEST @                          \ ( stub-xt )
DUP $D400 U< 0=                   \ ( stub-xt stub-in-region? )
SWAP BANK-OF 5 =                  \ ( stub-in-region? bank-eq-5? )
AND                               \ ( verdict-flag: -1=PASS, 0=FAIL )
0 BANK!
." result=" . CR
." ---probe-19.3-d-end---" CR

\ === Probe-19.3-E — intra-bank EXECUTE-explicit on bank-5 CREATE'd word
\ Validates intra-bank dispatch path (src/inner_interpreter.asm:454..461).
\ EXECUTE on a CREATE'd word pushes body addr (DOVAR's HL+5); intra-bank
\ @ reads the cell at body addr (= 42 stored via `,`).
." ---probe-19.3-e-start---" CR
5 BANK!
CREATE _p193e-tgt 42 ,
LATEST @                          \ ( stub-xt )
EXECUTE                           \ ( body-addr )
@                                 \ ( 42 )
42 =                              \ ( verdict-flag )
0 BANK!
." result=" . CR
." ---probe-19.3-e-end---" CR

\ === Probe-19.3-F — cross-bank EXECUTE-explicit on bank-5 CREATE'd word (DEFERRED)
\ ARCHITECTURAL DEFECT discovered 2026-05-20 at Story 19.3 dev-pass:
\ cross-bank EXECUTE of a CREATE'd word (DOVAR-targeted CFA) HANGS the
\ kernel under iz-cpm-banking. Root cause: the sentinel-trampoline
\ mechanism (src/inner_interpreter.asm:402..461 EXECUTE.cross_bank +
\ src/banking.asm cross_bank_return) relies on the target's body
\ pushing the pre-loaded DE = cross_bank_return sentinel onto R-stack
\ via DOCOL, then popping it via EXIT_CODE so the trampoline can fire.
\ For DOVAR-targeted CFAs (CREATE'd words without DOES>) there is no
\ DOCOL+EXIT pair — DOVAR pushes body_addr to data stack and NEXTs
\ directly. NEXT then dereferences DE = cross_bank_return as if it were
\ a thread cell, dispatches garbage, halts the emulator.
\
\ This is the SAME architectural-debt class as Probe-19.3-G (DOES> body
\ hits DTC threading defect): cross-bank dispatch needs kernel-level
\ rework for non-DOCOL bodies. Story 19.2 referenced this as the
\ "NEXT-via-EXECUTE chokepoint" rework (its anchor remains forward work).
\
\ Probe emits defer-sentinel rather than running the dispatch. Makefile
\ recipe accepts the defer-sentinel as a non-PASS, non-FAIL DEFER
\ outcome. To re-test once the chokepoint rework lands: revert this
\ defer block to the active EXECUTE @ ( verdict) sequence below in
\ comment form.
\
\ STORY 19.5.2 NOTE: the defect class described above is FIXED (ADR
\ 19.5 DR-2 option C — sentinel-trampoline retired; non-DOCOL targets
\ return uniformly via xbank_thunk/xbank_restore; see probe-19.5.2-b
\ below, which exercises this exact shape minus the cross-bank `@`).
\ THIS DEFER STUB STAYS — full re-enablement incl. the `@` data read
\ is Story 19.5.3 scope per its AC8 fence.
\
\ Original active form (kept as comment for future re-test):
\   5 BANK!
\   CREATE _p193f-tgt 99 ,
\   LATEST @
\   0 BANK!
\   EXECUTE @                     \ expected 99 cross-bank — HANGS today
\   BANK@                         \ expected 0
\   0 = SWAP 99 = AND
." ---probe-19.3-f-start---" CR
." probe-19.3-f-deferred-on-cross-bank-dovar-sentinel-defect" CR
." ---probe-19.3-f-end---" CR

\ === Probe-19.3-G — bank-5 CREATE/DOES> behavioural surface (Q3-α DEFERRED)
\ DOES> body in a bank-N>0 word is itself a banked colon body that hits
\ the inherited DTC threading-through-stub-xt defect (Story 19.2 AC4/AC5
\ deferred work, also blocking Story 19.3 AC6-G). Probe emits the
\ defer-sentinel rather than running the dispatch. Makefile recipe
\ accepts the defer-sentinel as a non-PASS, non-FAIL DEFER outcome.
." ---probe-19.3-g-start---" CR
." probe-19.3-g-deferred-on-cross-bank-thread-defect" CR
." ---probe-19.3-g-end---" CR

." ---probe-19.3-suite-end---" CR

\ === Probe-19.3.1-A — Defect-2 fix: bucket-head unchanged after bank-N CREATE
\ Validates Story 19.3.1 Defect-2 fix at src/compiler.asm:359..396: CREATE
\ in bank-N>0 must NOT update the shared FORTH-WORDLIST bucket array.
\ Pre-fix: bucket[hash(name)] head was updated to bank-N HERE address
\ (slot-2 / bank-N RAM), polluting the chain across BANK! cycles per
\ feedback_phase4_probe_bank_switch_limitation. Hardware-only failure mode
\ on real MicroBeast (2026-05-22 transcript ~/Downloads/beastty-20260522-
\ 103928.bin: post-`5 BANK! ... 0 BANK!` `CR` -13 undefined word).
\ Post-fix: bucket-head invariant pre=post; verifies the structural fix
\ under iz-cpm-banking in the clean isolated-fixture context (no cumulative
\ state, HERE stays below $8000, kernel-word FIND reliable post-cycle).
\ Hash of `_p1931a-tgt` = 24; bucket addr = FORTH-WORDLIST + 2 + 24*CELLS.
." ---probe-19.3.1-a-start---" CR
FORTH-WORDLIST 2 + 24 CELLS + @     \ ( bucket24-pre )
5 BANK!
HERE $9000 SWAP - ALLOT
CREATE _p1931a-tgt 42 ,
0 BANK!
FORTH-WORDLIST 2 + 24 CELLS + @     \ ( bucket24-pre bucket24-post )
=                                   \ ( verdict-flag: -1=PASS iff unchanged )
." result=" . CR
." ---probe-19.3.1-a-end---" CR

." ---probe-19.3.1-suite-end---" CR

\ === Story 19.5.2 witnesses (ADR 19.5 DR-2 option C; distinct id family
\ so the F/G DEFER grading clauses above stay untouched) ===
\
\ Probe-19.5.2-B — non-DOCOL cross-bank witness (Q2 default): cross-bank
\ EXECUTE from bank 0 of a bank-5 CREATE'd word — the EXACT shape that
\ hung as Probe-19.3-F under the retired sentinel-trampoline (DOVAR has
\ no DOCOL/EXIT pair; NEXT dereferenced DE = sentinel as a thread cell
\ and halted). Post-19.5.2: stub_dispatch's cross path sets DE =
\ xbank_thunk; DOVAR pushes body-addr and NEXTs with IP = thunk →
\ xbank_restore → caller resumes in bank 0. Asserts (1) the dispatch
\ RETURNS at all (the hang class), (2) body-addr is window-resident
\ (≥ $8000), (3) BANK@ = 0 after the thunk return. The cross-bank `@`
\ data read stays OUT (FR-P4-26 pointer hazard + probe-F re-enablement
\ is 19.5.3 scope — F/G DEFER stubs above are deliberately untouched).
." ---probe-19.5.2-b-start---" CR
5 BANK!
CREATE _p1952b-tgt 99 ,
LATEST @                          \ ( stub-xt )
0 BANK!
EXECUTE                           \ ( body-addr ) — formerly the 19.3-F hang
$8000 U< 0=                       \ ( body-in-window? )
BANK@ 0 =                         \ ( body-ok? bank-restored? )
AND                               \ ( verdict-flag )
." result=" . CR
." ---probe-19.5.2-b-end---" CR

\ Probe-19.5.2-C — AC6 CATCH-cross-bank bank-restore witness: bank-5
\ colon word THROWs; CATCH wraps from bank 0. The cross-bank dispatch
\ frame + thunk-IP on the R-stack are ABANDONED wholesale by THROW's
\ snap-back (xbank_restore never runs) — pre-AC6 current_bank stayed 5;
\ post-AC6 THROW's caught path MMU-restores the catcher's bank from
\ CATCH frame +8. Asserts THROW code delivered (77) AND BANK@ = 0.
\ The full banked NFR-P4-8 variant is 19.5.3 scope.
." ---probe-19.5.2-c-start---" CR
5 BANK!
: _p1952c-thrower 77 THROW ;
LATEST @                          \ ( stub-xt )
0 BANK!
CATCH                             \ ( 77 ) — cross-bank entry, caught THROW
77 =                              \ ( code-ok? )
BANK@ 0 =                         \ ( code-ok? bank-restored? )
AND                               \ ( verdict-flag )
." result=" . CR
." ---probe-19.5.2-c-end---" CR

\ Probe-19.5.2-D — CR-F1 caught-THROW triple-restore witness: a bank-0
\ thrower performs a REAL `5 BANK!` (legal — its body sits below $8000,
\ so the F1 window guard passes) before THROWing. The real BANK! swaps
\ the live (HERE, LATEST, wordlist_head) triple to bank 5's; THROW's
\ caught path must swap it back (CATCH frame +9 / bank_triple_swap —
\ src/exception.asm). Pre-fix the caught path restored only MMU +
\ current_bank: BANK@ read 0 while the live HERE stayed bank 5's
\ (≥ $8000) and the next `:`/CREATE compiled against bank-5 HERE.
\ Asserts code delivered (88), BANK@ = 0, AND bank-0 HERE unchanged
\ across the caught cross-triple THROW.
." ---probe-19.5.2-d-start---" CR
: _p1952d-thrower 5 BANK! 88 THROW ;
HERE                              \ ( here-pre )
' _p1952d-thrower                 \ ( here-pre xt ) — tick: bank-0 words have
                                  \ no stub-xt; LATEST @ is NOT an xt here
CATCH                             \ ( here-pre 88 ) — caught after real BANK!
88 =                              \ ( here-pre code-ok? )
BANK@ 0 =                         \ ( here-pre code-ok? bank-ok? )
AND                               \ ( here-pre flags )
SWAP HERE =                       \ ( flags here-restored? )
AND                               \ ( verdict-flag )
." result=" . CR
." ---probe-19.5.2-d-end---" CR

." ---probe-19.5.2-suite-end---" CR
BYE
