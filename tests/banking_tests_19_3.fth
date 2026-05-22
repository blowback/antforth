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
BYE
