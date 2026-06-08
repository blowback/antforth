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
\   - Probe-19.3-F (AC6-F): RE-ENABLED in Story 19.5.3 (AC4) — cross-bank
\     dispatch+return on a bank-5 CREATE'd (DOVAR) word. The former hang
\     (DOVAR has no DOCOL/EXIT pair; retired sentinel-trampoline halted) is
\     dead — 19.5.2's RST self-dispatch + xbank_thunk return it uniformly.
\     Dispatch+return witness only: body-addr window-resident + BANK@ = 0.
\     The cross-bank data read via `@` stays OUT (FR-P4-26 doc-and-pray
\     pointer hazard; redesign §5.4) — not a dispatch defect.
\   - Probe-19.3-G: RE-ENABLED in Story 19.5.3 (AC5) — bank-5 CREATE/DOES>
\     compiled-body dispatched INTRA-bank (DOES> body in slot-2, bank 5
\     mapped throughout). Proves DTC defect class (a) is retired by 19.5.2's
\     RST self-dispatch. The CROSS-bank DOES> case (DOES> body above $8000
\     mapping a foreign bank) stays the DR-1 portal-aliasing hazard — owning
\     fix Epic 20 (redesign §5.5); documented-DEFER via the note line after
\     the g-end sentinel, not forced green.
\
\ Bank-N HERE: NO manual workaround. Story 19.5.1's F2 COLD-init seeds
\ bank-table[1..28].here = $8000 at COLD, so a fresh bank-N's first-visit
\ HERE is already in slot-2 ($8000+) — bank-5 CREATE/`:` bodies land in
\ the window and never corrupt bank-0 state. The former
\ `5 BANK! HERE $9000 SWAP - ALLOT` bump (removed in Story 19.5.3 AC1) is
\ now redundant; the COLD-init is the single mechanism (gated behaviourally
\ by probe-19.5.1-c / test-repl-banking-isolated-19-5-1).
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

\ === Probe-19.3-F — cross-bank dispatch+return on a bank-5 CREATE'd (DOVAR) word
\ RE-ENABLED in Story 19.5.3 (AC4) — verified PASS under iz-cpm-banking.
\ The hang this probe formerly deferred for is DEAD: the original defect
\ (DOVAR-targeted CFAs have no DOCOL/EXIT pair, so the retired sentinel-
\ trampoline dereferenced DE = cross_bank_return as a thread cell and
\ halted) was fixed by ADR 19.5 DR-2 option C (Story 19.5.2): NEXT's
\ blind `JP (HL)` now lands on stub byte 0 = $EF = RST $28 → stub_dispatch;
\ the cross path sets DE = xbank_thunk; DOVAR pushes body-addr and NEXTs
\ with IP = thunk → xbank_restore → caller resumes in bank 0. This is the
\ exact shape probe-19.5.2-b witnesses; here graded as the re-enabled F.
\
\ FR-P4-26 fence (load-bearing): the original F body's cross-bank `EXECUTE @`
\ (expecting the stored 99 from bank 5) stays OUT. After xbank_restore the
\ slot-2 window maps bank 0, so reading the returned $8xxx body-pointer
\ would yield bank-0 memory, not 99 — the FR-P4-26 "doc-and-pray" cross-bank
\ pointer hazard (no runtime guard; redesign §5.4:105..107), NOT a dispatch
\ defect. F asserts the cross-bank dispatch RETURNS (the hang class) AND hands
\ back the SAME body-addr as an intra-bank dispatch of the same word — proving
\ the returned pointer is the real DOVAR body, not merely some value ≥ $8000 —
\ with BANK@ = 0. The cross-bank pointer is never dereferenced (fence honored).
." ---probe-19.3-f-start---" CR
5 BANK!
CREATE _p193f-tgt 99 ,
LATEST @                          \ ( stub-xt )
DUP EXECUTE                       \ ( stub-xt body-addr-intra )  intra-bank dispatch (bank 5)
SWAP                              \ ( body-addr-intra stub-xt )
0 BANK!
EXECUTE                           \ ( body-addr-intra body-addr-xbank )  cross-bank via thunk
=                                 \ ( addrs-equal? )  cross returns the SAME body-addr
BANK@ 0 =                         \ ( addrs-equal? bank-restored? )  caller bank 0 restored
AND                               \ ( verdict-flag: -1=PASS )
." result=" . CR
." ---probe-19.3-f-end---" CR

\ === Probe-19.3-G — bank-5 CREATE/DOES> compiled-body, INTRA-bank (Q3 default)
\ RE-ENABLED in Story 19.5.3 (AC5) — verified PASS under iz-cpm-banking.
\ Defines a bank-5 defining word `_p193g-maker` (CREATE , DOES> @) and a
\ bank-5 instance `_p193g-inst`, then dispatches the instance FROM bank 5
\ (DOES> body in slot-2, bank 5 mapped throughout — no foreign mapping).
\ The DOES>-body DTC dispatch — defect class (a), NEXT's blind `JP (HL)`
\ into a banked DOES>/colon body — is retired by 19.5.2's RST self-dispatch
\ ($EF stub byte 0). bank-N words aren't FIND-able by name (shared bucket
\ skipped per Story 19.3.1 Defect-2; bank-aware FIND is Epic 20), so the
\ maker + instance are invoked via LATEST @ EXECUTE; the maker's CREATE
\ parses the next input token (_p193g-inst) for the instance name.
\
\ DR-1 fence (cross-bank DOES> stays DEFER): a DOES> body running ABOVE
\ $8000 that maps a foreign bank over slot 2 is the DR-1 portal-window-
\ aliasing hazard — "contained, not abolished" by the F1 BANK! guard
\ (-273). Its owning fix is Epic 20 (per-wordlist bank field / bank-aware
\ FIND, redesign §5.5). That case is NOT forced green here — see the
\ note-probe-19.3-g-cross-bank line below the end sentinel.
." ---probe-19.3-g-start---" CR
5 BANK!
: _p193g-maker CREATE , DOES> @ ;
LATEST @                          \ ( maker-xt )
42 SWAP                           \ ( 42 maker-xt )
EXECUTE _p193g-inst               \ run maker → CREATE _p193g-inst, , stores 42, DOES> @
LATEST @                          \ ( inst-xt )
EXECUTE                           \ run _p193g-inst → DOES> pushes body, @ → 42
42 =                              \ ( value-ok? )
BANK@ 5 =                         \ ( value-ok? still-bank-5? )  intra: no MMU swap
AND                               \ ( verdict-flag: -1=PASS )
0 BANK!
." result=" . CR
." ---probe-19.3-g-end---" CR
." note-probe-19.3-g-cross-bank-does-deferred-dr1-epic20" CR

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

\ === Story 19.5.3 compiled-body verification + full banked NFR-P4-8 ===
\
\ The 19.5.2 witnesses above (probe-19.5.2-b/c/d) prove the dispatch +
\ CATCH-restore MECHANISM via explicit EXECUTE. The probes below re-express
\ FR-P4-15/16 in genuine COMPILED-BODY form — a banked word dispatched
\ through NEXT's `JP (HL)` from a thread cell inside another word's
\ parameter field, not via a runtime EXECUTE of a stack value. This is the
\ Epic-19 north-star UX: "call a banked word from a compiled definition."
\
\ Compiled-body construction (the `[ COMPILE, ]` idiom): bank-N words are
\ not FIND-able by name (shared bucket skipped per Story 19.3.1 Defect-2;
\ bank-aware FIND-by-name is Epic 20, redesign §5.5). So the literal source
\ shape `: CALLER ... BANKED-WORD ... ;` (BANKED-WORD a bank-5 name
\ referenced from bank 0) cannot COMPILE today — the text interpreter would
\ -13 on BANKED-WORD. The portable stub-xt (fixed memory, FR-P4-17) IS
\ valid across banks, so the probes capture it (LATEST @) and inject it into
\ the caller's body via `[ COMPILE, ]`. The result is a real compiled thread
\ cell, dispatched by NEXT byte-identically to a by-name reference — the
\ DISPATCH path (what 19.5.2 fixed and this story verifies) is exercised
\ exactly. Source-syntax by-name is the only piece awaiting Epic 20.

\ === Probe-19.5.3-AC2 — intra-bank compiled-body dispatch (FR-P4-15; 19.2 AC4)
\ A bank-5 CALLER whose COMPILED body references a bank-5 CALLEE; calling
\ CALLER intra-bank (bank 5 mapped) dispatches CALLEE through NEXT → stub
\ byte 0 $EF (RST $28) → stub_dispatch INTRA path (target_bank ==
\ current_bank → no MMU write) → CALLEE CF → 7. Assert value AND BANK@ = 5.
." ---probe-19.5.3-ac2-start---" CR
5 BANK!
: _p1953ac2-callee 7 ;
LATEST @                          \ ( callee-stub-xt )
: _p1953ac2-caller [ COMPILE, ] ; \ body = DOCOL | callee-stub-xt | EXIT
LATEST @                          \ ( caller-stub-xt )  bank-5: not FIND-able by name
EXECUTE                           \ enter CALLER; its body dispatches CALLEE intra-bank
7 =                               \ ( value-ok? )
BANK@ 5 =                         \ ( value-ok? still-bank-5? )
AND                               \ ( verdict-flag: -1=PASS )
0 BANK!
." result=" . CR
." ---probe-19.5.3-ac2-end---" CR

\ === Probe-19.5.3-AC3 — cross-bank compiled-body dispatch from bank 0 (north-star)
\ A bank-0 CALLER (body in fixed memory < $8000, always mapped) whose
\ COMPILED body references a bank-5 CALLEE. Calling CALLER from bank 0:
\ NEXT → RST $28 → stub_dispatch CROSS path (2-cell frame [caller_bank]
\ [caller_IP] pushed, MMU swaps bank-5 into slot 2, current_bank ← 5) →
\ CALLEE runs in slot 2 → terminal EXIT → xbank_thunk → xbank_restore pops
\ the frame, restores bank 0, resumes CALLER → 7. Assert value AND BANK@ = 0.
\ CALLER lives in bank 0 by design — a CALLER body ABOVE $8000 calling a
\ foreign bank is the DR-1 portal-aliasing hazard (AC9 fence), out of scope.
." ---probe-19.5.3-ac3-start---" CR
5 BANK!
: _p1953ac3-callee 7 ;
LATEST @                          \ ( callee-stub-xt )  portable across banks
0 BANK!
: _p1953ac3-caller [ COMPILE, ] ; \ bank-0 colon; body holds the bank-5 callee cell
_p1953ac3-caller                  \ bank-0 word IS FIND-able by name → invoke directly
7 =                               \ ( value-ok? )
BANK@ 0 =                         \ ( value-ok? bank-restored? )  thunk returned to bank 0
AND                               \ ( verdict-flag: -1=PASS )
." result=" . CR
." ---probe-19.5.3-ac3-end---" CR

\ === Probe-19.5.3-AC6 — full banked NFR-P4-8 (CATCH-cross-bank) state integrity
\ Beyond the minimal witnesses probe-19.5.2-c (dispatch-only THROW → BANK@
\ restore) and -d (real BANK! → CR-F1 triple HERE-unchanged): a bank-0
\ thrower performs a REAL `5 BANK!` (legal — body < $8000, F1 guard passes)
\ then THROWs. The caught path must restore MMU + current_bank (frame +8)
\ AND the live (HERE, LATEST, wordlist_head) triple (frame +9 triple_owner +
\ bank_triple_swap). This probe asserts the FULL NFR-P4-8 guarantee:
\   (a) THROW code delivered (99);
\   (b) BANK@ = catcher's bank (0);
\   (c) the live triple is the catcher-bank's — proven OPERATIONALLY: HERE
\       unchanged AND a fresh `:` compiled post-catch lands + is FIND-able;
\   (d) the thrower's bank's bank-table[] entry is not corrupted — a
\       subsequent definition switched into bank 5 works cleanly.
\ (c)+(d) are the "subsequent definitions work cleanly" clause that the
\ minimal witnesses do not exercise. Kept kernel-word-only + below $8000 for
\ the bank-0 arm (bucket-pollution rule, AC9).
." ---probe-19.5.3-ac6-start---" CR
: _p1953ac6-thrower 5 BANK! 99 THROW ;
HERE                              \ ( here0 ) bank-0 HERE before the catch
' _p1953ac6-thrower               \ ( here0 xt )  tick: bank-0 word has no stub-xt
CATCH                             \ ( here0 99 )  caught after real BANK!
99 =                              \ ( here0 code-ok? )           (a)
SWAP HERE =                       \ ( code-ok here-restored? )   (c-HERE)
BANK@ 0 =                         \ ( code-ok here-ok bank-ok? ) (b)
: _p1953ac6-after 55 ;            \ fresh bank-0 compile post-catch
' _p1953ac6-after EXECUTE 55 =    \ ( ... after-lands-and-finds? ) (c-FIND)
5 BANK!
: _p1953ac6-b5 123 ;             \ thrower-bank definition after switching back
LATEST @ EXECUTE 123 =           \ ( ... bank5-clean? )          (d)
0 BANK!
AND AND AND AND                   \ ( verdict-flag: -1=PASS iff all five hold )
." result=" . CR
." ---probe-19.5.3-ac6-end---" CR

." ---probe-19.5.3-suite-end---" CR
BYE
