# Story 19.5.3: Compiled-body verification + banked-CATCH (NFR-P4-8) variant

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-07 by create-story workflow. Implements the Epic 19.5
     story-19.5.3 line (epics-phase4-epics-16-22.md:889): "compiled-body
     verification. (H5 moved to 19.5.1.) Re-enable + verify 19.2 AC4/AC5 +
     19.3 AC3/DOES> compiled-body probes (remove the EXECUTE-explicit
     reword + the manual ALLOT); banked NFR-P4-8 (CATCH-cross-bank)
     variant verifies 19.5.2's frame fix." This is a VERIFICATION story:
     it proves the mechanism shipped by Story 19.5.2 (RST-$28 self-
     dispatch stub + 2-cell dispatch frame + xbank_thunk/xbank_restore;
     CR-F1 triple restore) actually delivers the Epic-19 north-star UX
     behaviourally — calling a banked word from a COMPILED definition,
     not just via explicit EXECUTE. Sprint-status row key (immutable):
     19-5-3-compiled-body-verification-banked-catch-variant. -->

## Story

As Marc (OG user) who was promised "`5 BANK! : MYWORD ... ;` then call `MYWORD` from a compiled definition in any bank" (the Epic-19 north-star UX),
I want the compiled-body banked-dispatch probes that Stories 19.2/19.3 had to reword to explicit-`EXECUTE` (and wrap in a manual `$9000 ALLOT` HERE bump) re-enabled in their real compiled-body form — and the banked `CATCH`-cross-bank state-integrity guarantee (NFR-P4-8) verified beyond the minimal in-story witnesses,
so that the behavioural delivery of FR-P4-15 / FR-P4-16 / FR-P4-24 / FR-P4-25 is *proven* on the emulator and the Epic-19 architectural-debt anchors are demonstrably discharged (within the DR-1 / FR-P4-26 documented limits), closing the gap between "mechanism shipped" (19.5.2) and "UX works" before the 19.5.4 epic close-out + tag.

## Acceptance Criteria

> **Story posture: verification first.** The mechanism (NEXT→RST→stub_dispatch→thunk; CATCH frame +8/+9 bank + triple restore) already shipped and is green via EXECUTE-form witnesses (probe-19.4-a, probe-19.5.2-a/b/c/d). This story re-expresses those witnesses in **compiled-body** form, removes the obsolete `$9000 ALLOT` workaround (F2 COLD-init from 19.5.1 made it redundant), and adds the **full** NFR-P4-8 banked-CATCH variant. **Expected binary delta ≈ 0 B (test + doc only).** A kernel change is in-scope ONLY if a re-enabled probe surfaces a real defect — in which case surface-file-fix per [[feedback_no_preexisting_discharge]], itemise per B.2, and report the delta plainly against the (already-breached) epic envelope.

1. **AC1 — Remove the `$9000 ALLOT` bank-N HERE workaround.** Delete the `HERE $9000 SWAP - ALLOT` lines and their explanatory header prose from the isolated banking fixtures: `tests/banking_tests_19_3.fth:52` (probe-19.3-D), `:147` (probe-19.3.1-A), and `tests/banking_tests_19_2.fth:64` (probe-19.2-D); plus the workaround-describing header comments (`banking_tests_19_3.fth:34..39`, `banking_tests_19_2.fth:49`). With Story 19.5.1's F2 COLD-init (`bank-table[1..28].here = $8000` at COLD) the bump is redundant — first-visit bank-N `HERE` is already `$8000` (gated by probe-19.5.1-C). **Verify:** after removal, bank-N `CREATE`/`:` bodies still land in the slot-2 window (`≥ $8000`) and do NOT corrupt bank-0 state; `test-repl-banking-isolated` (19-2) and `-19-3` stay green. **Do not** re-introduce any manual HERE manipulation — the COLD-init is now the single mechanism.

2. **AC2 — Intra-bank compiled-body dispatch (FR-P4-15; 19.2 AC4 re-enabled).** Add an isolated compiled-body probe: a bank-5 colon `CALLER` whose **compiled body** references a bank-5 `CALLEE` (the stub-xt is laid as a thread cell by `COMPILE,` at definition time); calling `CALLER` intra-bank dispatches `CALLEE` through `NEXT`'s blind `JP (HL)` → stub byte 0 `$EF` (`RST $28`) → `stub_dispatch` **intra path** (`target_bank == current_bank` → no MMU write) → target CF. Assert the expected value AND `BANK@ = 5` after. This is the form 19.2 AC4 was reworded away from (`... LATEST @ ... EXECUTE`). Verdict via run-time `." result=" .` (REPL-piped, [[feedback_repl_tests_preferred]]).

3. **AC3 — Cross-bank compiled-body dispatch from bank 0 (FR-P4-16; 19.2 AC5 re-enabled; the north-star case).** Add an isolated compiled-body probe in the exact shape `5 BANK! : BANKED-WORD ... ; 0 BANK! : CALLER ... BANKED-WORD ... ; CALLER` — i.e. a **bank-0** `CALLER` (body in fixed memory, below `$8000`, always mapped) whose compiled body references a **bank-5** `BANKED-WORD`. Calling `CALLER` from bank 0: `NEXT` → `RST $28` → `stub_dispatch` **cross path** (2-cell frame `[caller_bank][caller_IP]` pushed, MMU swaps bank-5 page into slot 2, `current_bank ← 5`) → `BANKED-WORD` body runs in slot 2 → terminal `EXIT`/`NEXT` reaches `xbank_thunk` → `xbank_restore` pops the frame, restores bank 0, resumes `CALLER`. Assert the expected value AND `BANK@ = 0` after return. This is the precise `0 BANK! BANKED-WORD` form 19.2 AC5 was reworded away from. **Scope fence:** the CALLER lives in bank 0 by design — a CALLER body *above* `$8000` (bank-N) calling a foreign bank is the DR-1 portal-aliasing hazard (AC9), out of scope.

4. **AC4 — Probe-19.3-F re-enablement: cross-bank dispatch of a non-DOCOL (DOVAR) target (FR-P4-25 partial; root-cause-(b) discharge).** Convert the `tests/banking_tests_19_3.fth:116..118` F DEFER stub to a **live** probe (compiled-body or EXECUTE form per Q2) that exercises a cross-bank `CREATE`'d (DOVAR-targeted) word and asserts the dispatch **returns cleanly** with `BANK@ = 0` after — the exact shape probe-19.5.2-b already witnesses, now graded as PASS (the Probe-19.3-F hang class is dead). **FR-P4-26 fence (load-bearing):** the original F body's cross-bank `EXECUTE @` (expecting the stored `99` from bank 5) stays OUT — after `xbank_restore` the slot-2 window maps bank 0, so reading the returned `$8xxx` body-pointer yields bank-0 memory, not `99`. This is the FR-P4-26 "doc-and-pray" cross-bank pointer hazard (no runtime guard; redesign §5.4:107 / epics:70), NOT a dispatch defect. Re-enable F as a **dispatch+return** witness only; document the fence in the probe comment and confirm redesign §5.4 already covers it. **Makefile:** move F from the DEFER clause to a PASS clause (result=`-1`) in the `for pid in d e f g` loop (`Makefile:683`); the loop membership, the per-id 3-tier grading, and the `---probe-19.3-suite-end---` marker being **last** (`Makefile:694`) must all be preserved.

5. **AC5 — Probe-19.3-G disposition: CREATE/DOES> compiled-body (FR-P4-25; defect-(a) discharge, DR-1 fence).** Re-enable the `tests/banking_tests_19_3.fth:126..128` G DEFER stub as an **intra-bank** CREATE/DOES> compiled-body probe (Q3 default): define `CREATE`+`DOES>` in bank 5 and exercise the defining word **from bank 5** (DOES> body in slot 2, bank 5 mapped throughout — no foreign mapping). This proves the DOES>-body DTC dispatch — defect class (a), `NEXT`'s blind `JP (HL)` into a banked colon/DOES> body — is retired by 19.5.2's RST self-dispatch. **DR-1 fence:** the *cross-bank* DOES> case (a DOES> body *above* `$8000` that maps a foreign bank over slot 2) is the DR-1 portal-window-aliasing hazard — "contained, not abolished" by the F1 `BANK!` guard (`-273`); its owning fix is Epic 20 (per-wordlist bank field / bank-aware FIND, redesign §5.5). Keep that case DEFER-or-documented, not forced green. Grade G PASS (intra) in the same `for pid` loop; if the cross case stays deferred, keep one labelled DEFER line so the suite reads honestly.

6. **AC6 — Full banked NFR-P4-8 (CATCH-cross-bank) state-integrity variant.** Add an isolated probe that verifies the **complete** NFR-P4-8 guarantee (epics:115, epics:815 AC6 — "no internal data structure … may be left in a corrupted or inconsistent state after a THROW … subsequent definitions in the same bank work cleanly") for the cross-bank caught-THROW case, going beyond the minimal witnesses probe-19.5.2-c (dispatch-only THROW → `BANK@` restore) and probe-19.5.2-d (real `BANK!` → CR-F1 triple `HERE`-unchanged). The variant asserts, after a caught cross-bank THROW whose thrower performed a real `BANK!`: **(a)** THROW code delivered; **(b)** `BANK@` = catcher's bank; **(c)** the live `(HERE, LATEST, wordlist_head)` triple is the catcher-bank's — proven *operationally* by compiling a fresh `:`/`CREATE` in the catcher's bank after the catch and confirming it lands at the catcher's `HERE` and is `FIND`-able (not merely `HERE =`); **(d)** the **thrower's** bank's `bank-table[]` entry is not corrupted — a subsequent definition switched into the thrower's bank works cleanly. (c)+(d) are the "subsequent definitions work cleanly" clause that the minimal witnesses do not exercise. Isolated fixture; mind the bucket-chain-pollution rule (AC9) — keep the post-catch definitions kernel-word-only and below `$8000` where the bank-0 arm runs.

7. **AC7 — EXECUTE-explicit reword + status cleanup; doc sync.** Update the now-stale "BLOCKED / anchored on Story 19.5 / deferred" prose to "verified in Story 19.5.3" at: the F/G probe comments (`banking_tests_19_3.fth:90..106`, `:120..125`), the bank-N-HERE-workaround header prose removed in AC1, and the `tests/banking_tests_19_2.fth` / `_19_3.fth` file-header rewording notes. Architecture/redesign: mark the compiled-body north-star UX **behaviourally delivered** — PD-P4-11 (`architecture.md`), redesign §3 (cross-bank call mechanism) and §2.1 status lines; note FR-P4-15/16/24/25 compiled-body dispatch and the banked NFR-P4-8 variant as verified. Do NOT silently rewrite decision history — append a "verified 19.5.3" status line in the SUPERSEDED-note style 19.5.2 used. `make check-doc-sync` → 0 drift (advisory count = baseline) at close.

8. **AC8 — All test surfaces green + binary delta.** At close (re-run and record actuals): `make test-repl` ≥ 975 PASS / 0 FAIL; `make test-repl-banking` ≥ 63 / 0; `make test-repl-banking-isolated` (19-2, workaround removed) green; `make test-repl-banking-isolated-19-3` re-graded — D/E PASS, **F now PASS**, **G PASS (intra) [+ optional DEFER line for the cross case]**, 19.3.1-A PASS, 19.5.2-b/c/d PASS, the new AC2/AC3 compiled-body probes PASS, the new AC6 NFR-P4-8 probe PASS, `---probe-19.3-suite-end---` still the last marker; `make test-repl-banking-isolated-19-4` 2/0; `-19-5-1` 2/0; `make test-repl-banking-skip` 0 FAIL; `make test-straddle-regression` 3/3; `make check-doc-sync` 0 drift. **Binary:** `wc -c build/antforth.com` vs the **26953 B** baseline (commit 1e2c44e, post-DIV-1-fix). Verification story → target **≈ 0 B**. If a kernel fix proves necessary, itemise per B.2 (per-component opcode sum, no "mirrors prior arm" shorthand) and report the as-built delta plainly ([[feedback_plain_qa_language]]); the epic is already at **120 B cumulative vs the ~100 B ADR guidance** (epics:902) — any kernel growth deepens that breach and must be carried to the 19.5.4 reconciliation, not absorbed silently.

9. **AC9 — Scope fences + layout-shift discipline.** **Fences:** (i) cross-bank-from-bank-N compiled-body (CALLER body `≥ $8000` mapping a foreign bank), cross-bank DOES>-body dispatch, and the cross-bank `@` data read are DR-1 / FR-P4-26 documented limits — F1-guarded, owning fix Epic 20 (redesign §5.5); do not force them green. (ii) Uncaught-path (`ABORT`/`QUIT`) bank restore = Epic 21 (sprint row 21-2). (iii) HW UAT, envelope reconciliation, the NFR-P4-3 ≤ 400 T re-baseline statement, and the epic tag = Story 19.5.4 (whose HW evidence is already gathered — see AC10). **Layout discipline:** AC1's deletions shift the dictionary base slightly; any banking-probe trip is diagnosed via the straddle harness (which body straddles `$8000`, under which mapping), never reflex-reverted ([[feedback_iz_cpm_trampoline_fragility]] is SUPERSEDED — no trampoline/emulator framing). The flat-iz-cpm test-643 `*/` quirk is re-tuned via the `cold_start` NOP slot **only if flat test 643 itself trips** ([[feedback_iz_cpm_test_643_quirk]]). F1/F2/F3 (19.5.1) are untouched; the F3 straddle-regression target must stay green through every shift.

10. **AC10 — Hardware posture (no new HW pass for this story).** 19.5.3's surface — compiled-body dispatch + banked CATCH — is emulator-verifiable under `IZCPM_BANKING`. The HW UAT that the epic plan assigned to 19.5.4 has **already run** (2026-06-06; transcripts `beastty-20260606-112043/-113348/-120930/-122352.bin`): A1/A2/A3 + F1/F2 confirmed on silicon and the DIV-1 MMU-readback defect found + fixed + HW-verified (commits 2fb448b → 1bab95a → 1e2c44e; current 26953 B). 19.5.3 therefore requires **no** deferred-HW-smoke of its own — state that explicitly in the close message. If a *new* fixture from this story would benefit from silicon confirmation, fold it into 19.5.4's close-out batch (0x1A-terminate before SLIDE per [[feedback_cpm_0x1a_eof_marker]]). [[feedback_post_hw_smoke_steps_at_review]] (STRONG) is satisfied by this explicit "no deferred HW step" statement — do not omit it.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev Notes
  - Do not inherit a prior story's number — re-`wc -c` from the actual current artifact (B.3 / [[feedback_kernel_ldir_estimate_overshoot]] / Lesson 13.5-F). Draft-time verified 2026-06-07: **26953 B** at commit 1e2c44e (clean tree). Re-verify at dev-pass start. **Dev-pass confirmed: 26953 B (clean build).**
- [x] Capture current test baselines and record actuals: `test-repl` · `test-repl-banking` · `-isolated` (19-2) · `-isolated-19-3` (D/E PASS, F/G DEFER, 19.3.1-A PASS, 19.5.2-b/c/d PASS) · `-isolated-19-4` 2/0 · `-isolated-19-5-1` 2/0 · `test-repl-banking-skip` · `test-straddle-regression` 3/3 · `check-doc-sync` 0 drift
  - **Dev-pass actuals (pre-edit): test-repl 975/0 · test-repl-banking 63/0 · isolated(19-2) 6 PASS · isolated-19-3 13 PASS + F/G DEFER · isolated-19-4 2/0 · isolated-19-5-1 2/0 · skip 25 PASS/3 SKIP · straddle 3/3 · doc-sync 0 drift/31 advisory.** All match draft-time expectations.
  - Draft-time expectation (from 19.5.2 + DIV-1 close, sprint-status): `test-repl` 975/0 · `test-repl-banking` 63/0 · isolated 6/0 · 19-3 ≈ 3 PASS + 2 DEFER (+ 19.3.1-A + 19.5.2-b/c/d) · 19-4 2/0 · 19-5-1 2/0 · skip 25/0 · straddle 3/3 · doc-sync 0 drift. Re-run and record actuals — DIV-1's fixed-pad HW fixtures were re-validated but re-confirm the emulator surface here.

### Story tasks

- [x] **Task 1 — Remove the `$9000 ALLOT` workaround (AC: #1)**
  - [x] Sub-1.1 Delete the `HERE $9000 SWAP - ALLOT` line at `banking_tests_19_3.fth:52`, `:147`, and `banking_tests_19_2.fth:64`; remove the workaround header prose (`_19_3.fth:34..39`, `_19_2.fth:49`)
  - [x] Sub-1.2 Re-run `test-repl-banking-isolated` (19-2) and `-19-3`; confirm D/E/19.3.1-A still PASS (bank-N bodies land at the F2 COLD-init `$8000`, no bank-0 corruption). If anything trips → straddle-harness diagnosis (AC9), not a revert. **Confirmed: all still PASS; F2 COLD-init provides the `$8000` base.**
- [x] **Task 2 — Intra-bank compiled-body probe (AC: #2)**
  - [x] Sub-2.1 Author the bank-5 `CALLER`→`CALLEE` compiled-body probe in the isolated 19-3 fixture (kernel-words + the two probe words only; distinct `_p1953*` id family); run-time `result=` verdict; assert value AND `BANK@ = 5` **(probe-19.5.3-ac2, `[ COMPILE, ]` idiom; PASS)**
  - [x] Sub-2.2 Add the Makefile grading clause (distinct id, result=`-1`); keep the suite-end sentinel last **(`for pid in ac2 ac3 ac6`; `---probe-19.5.3-suite-end---`)**
- [x] **Task 3 — Cross-bank-from-bank-0 compiled-body probe (AC: #3)**
  - [x] Sub-3.1 Author the `5 BANK! : CALLEE ... ; 0 BANK! : CALLER ... CALLEE ... ; CALLER` probe; assert value AND `BANK@ = 0` after return (the thunk path); the CALLER body is bank-0 / fixed-memory by design (DR-1 fence) **(probe-19.5.3-ac3; bank-0 CALLER findable by name → invoked directly; PASS)**
  - [x] Sub-3.2 Makefile grading clause; verify PASS under `IZCPM_BANKING`
- [x] **Task 4 — Re-enable Probe-19.3-F (AC: #4)**
  - [x] Sub-4.1 Replace the F defer block with a live dispatch+return probe (Q2 form); assert clean return + `BANK@ = 0`; the cross-bank `@` data read stays OUT (FR-P4-26 fence — document in the probe comment)
  - [x] Sub-4.2 Move F from the DEFER clause to the PASS clause in `Makefile:683`'s `for pid in d e f g` loop; preserve loop membership + 3-tier grading + suite-end-last **(F now emits `result=-1`; existing 3-tier grading auto-promotes DEFER→PASS — zero Makefile loop edit, all constraints preserved)**
- [x] **Task 5 — Probe-19.3-G disposition (AC: #5)**
  - [x] Sub-5.1 Re-enable G as an intra-bank CREATE/DOES> compiled-body probe (Q3 default); assert the DOES>-body dispatch value; grade PASS **(maker+instance via `LATEST @ EXECUTE`; intra-bank DOES> `@` → 42, BANK@=5; PASS)**
  - [x] Sub-5.2 Cross-bank DOES> case: keep DEFER/documented (DR-1 fence, Epic 20) with a labelled line; do not force green **(`note-probe-19.3-g-cross-bank-does-deferred-dr1-epic20` after g-end)**
- [x] **Task 6 — Full banked NFR-P4-8 (CATCH-cross-bank) probe (AC: #6)**
  - [x] Sub-6.1 Author the full-state-integrity probe: caught cross-bank THROW with a real `BANK!` inside; assert (a) code, (b) `BANK@`, (c) catcher-bank triple proven by a post-catch `:`/`CREATE` that lands + `FIND`s, (d) thrower-bank definition works cleanly after switching back **(probe-19.5.3-ac6; 5-flag verdict; PASS)**
  - [x] Sub-6.2 Makefile grading clause; PASS verified; keep within the bucket-pollution-safe isolated pattern
- [x] **Task 7 — Reword/status cleanup + doc sync (AC: #7)**
  - [x] Sub-7.1 Flip the "BLOCKED/deferred/anchored on Story 19.5" prose to "verified 19.5.3" at the F/G comments + file headers
  - [x] Sub-7.2 architecture.md PD-P4-11 + redesign §2.1/§3: append "compiled-body north-star verified 19.5.3" status (no silent history rewrite); `check-doc-sync` 0 drift **(append-only blockquotes; architecture.md note avoids literal `Story 19.5.3` token per the `[story-cite]` doc-sync rule — uses "Epic 19.5 compiled-body verification pass"; 0 drift restored)**
- [x] **Task 8 — Full sweep + close-out (AC: #8, #9, #10)**
  - [x] Sub-8.1 Run every surface in AC8; record actuals; `wc -c` delta vs 26953 B (expect ≈ 0) **(0 B delta — 26953 B unchanged; all surfaces green, see Completion Notes)**
  - [x] Sub-8.2 If a kernel fix was needed: B.2 per-component itemisation + plain envelope-breach statement carried to 19.5.4 **(N/A — no kernel fix needed; pure test+doc story, 0 B)**
  - [x] Sub-8.3 Sprint-status → `review`; close message states explicitly "no deferred HW smoke for 19.5.3 (HW ledger already complete at 19.5.4 evidence)" per [[feedback_post_hw_smoke_steps_at_review]]

## Dev Notes

### Why this story exists (context)

Stories 16–19 built the bank-aware compiler **mechanism** (`:`/`CREATE`/`COMPILE,` land bodies + emit descriptor stubs) but could only verify banked dispatch via explicit `' WORD EXECUTE`, because the inner-interpreter `NEXT` (`src/macros.asm:32..47`) dispatched every thread cell with a blind `JP (HL)` — and a banked word's thread cell is a descriptor-stub xt whose byte 0 used to be inert data, so a *compiled* call into a banked word ran garbage. Two root causes blocked the compiled-body form: **(a)** the DTC-threading-through-stub-xt defect (NEXT's blind `JP (HL)`), and **(b)** the cross-bank trampoline assuming a DOCOL/EXIT pair (non-DOCOL targets — `DOVAR`/`DOCON`/DEFCODE — hung; Probe-19.3-F). Stories 19.2/19.3 therefore reworded their compiled-body ACs (19.2 AC4/AC5, 19.3 AC3/DOES>) to EXECUTE-explicit form and wrapped bank-N defining in a manual `$9000 ALLOT` HERE bump (the H5 workaround).

Story 19.5.2 (ADR 19.5 DR-2, option C) made byte 0 of the stub `$EF` = `RST $28`, so `NEXT`'s blind `JP (HL)` now lands on an instruction that performs the dispatch it was never taught — at 0 T for non-stub words, with `NEXT` byte-for-byte untouched. The 2-cell dispatch frame + fixed-memory `xbank_thunk`/`xbank_restore` made non-DOCOL cross-bank targets return uniformly, subsuming root cause (b). The 19.5.2 CR pass added CR-F1: the caught-THROW path now restores the live `(HERE, LATEST, wordlist_head)` triple (frame +9 `triple_owner` + `bank_triple_swap`) so a real `BANK!` between `CATCH` and `THROW` cannot leave sticky compile-state corruption. Story 19.5.1 re-landed F2 (bank-N `HERE = $8000` at COLD), making the `$9000 ALLOT` workaround redundant.

**So everything 19.5.3 verifies is already mechanically present and green via EXECUTE-form witnesses.** This story re-expresses those witnesses in compiled-body form (the real north-star UX), deletes the obsolete workaround, and adds the full NFR-P4-8 banked-CATCH variant — turning "mechanism shipped" into "UX proven" before the 19.5.4 close-out. It is a test/doc story; a kernel edit is in-scope only if a re-enabled probe surfaces a genuine defect ([[feedback_no_preexisting_discharge]]).

### Process note — 19.5.3 / 19.5.4 interleave (read before starting)

The HW investigation the epic plan assigned to **19.5.4** ran *ahead* of this story: during 19.5.2's HW smoke (2026-06-06) the DIV-1 MMU-port-readback defect was found, fixed, and HW-verified (commits 2fb448b → 1bab95a → 1e2c44e), moving the baseline 26940 → **26953 B** and the epic cumulative to **120 B** (20 B over the ~100 B ADR guidance). 19.5.4 is still `backlog` — only evidence-gathering + the urgent correctness fix landed early. Consequences for 19.5.3: (i) baseline is 26953 B; (ii) the epic envelope is already breached — keep this story at ≈ 0 B and do not deepen it; (iii) DIV-1 is a HW-only path (`cl_probe_and_add` restoring slot 2 from `active_pages[]` not `IN (0x72)`, [[project_div1_mmu_port_readback]]) — it does not change emulator-probe behaviour, but it IS part of the current kernel you build against.

### Draft-time verified citations (PD-2 — all re-checked against working tree 2026-06-07, commit 1e2c44e, 26953 B)

- **Story-19.5.3 epic line:** `epics-phase4-epics-16-22.md:889`. NFR-P4-8: `:115`. AC6-NFR-P4-8 precedent (19.2): `:815`. FR-P4-26 (cross-bank pointer hazard, "no runtime guard"): `:70`; redesign §5.4: `docs/antforth-banking-redesign.md:105..107`; bank-aware FIND / Epic-20 owning fix: redesign §5.5 `:138..150`.
- **`$9000 ALLOT` workaround sites:** `tests/banking_tests_19_3.fth:52` (probe-19.3-D), `:147` (probe-19.3.1-A); `tests/banking_tests_19_2.fth:64` (probe-19.2-D); header prose `_19_3.fth:34..39`, `_19_2.fth:49`.
- **Probe-19.3-F DEFER stub:** `tests/banking_tests_19_3.fth:116..118`; its comment block `:77..115` (incl. the "STORY 19.5.2 NOTE … re-enablement is Story 19.5.3 scope" at `:101..106` and the original active form preserved as comment `:108..115`).
- **Probe-19.3-G DEFER stub:** `tests/banking_tests_19_3.fth:126..128`; comment `:120..125`.
- **19.5.2 minimal witnesses (compare against — do NOT duplicate):** probe-19.5.2-b `tests/banking_tests_19_3.fth:160..181` (non-DOCOL cross-bank dispatch, no `@`); probe-19.5.2-c `:183..200` (CATCH cross-bank, `BANK@` restore, no real `BANK!`); probe-19.5.2-d `:202..224` (CR-F1 real-`BANK!` triple restore, `HERE =`). Suite sentinels: `---probe-19.3-suite-end---` `:130`; `---probe-19.3.1-suite-end---` `:155`; `---probe-19.5.2-suite-end---` `:226`.
- **Makefile recipes:** `test-repl-banking-isolated` (19-2) `:647..` (`for pid in d e f g i` `:650`); `test-repl-banking-isolated-19-3` `:680..727` (`for pid in d e f g` `:683`; 3-tier grading DEFER/PASS/FAIL `:685..691`; suite-end check `:694`; 19.3.1-A + 19.5.2-b/c/d clauses follow); probe-19.5.2-a grading `:356..374`; `.PHONY` list `:50`.
- **Kernel sites (read-only this story unless a fix is needed):** `stub_dispatch` + `xbank_thunk`/`xbank_restore` in `src/banking.asm` (replaces the retired `cross_bank_return` slot); `bank_triple_swap` `src/banking.asm:262..301` (shared by BANK! `:211..225` and THROW caught path); RST-$28 vector install in `src/antforth.asm` (COLD, `STUB_DISPATCH_VECTOR` EQU in `src/constants.asm`); `NEXT`/`NEXTHL` `src/macros.asm:32..47` (untouchable — NFR-P4-1); CATCH frame +8 bank / +9 triple_owner push `src/exception.asm:169..183`; THROW caught-path bank+triple restore `:497..517`; frame-pop advance `LD BC,10 / ADD IX,BC` `:571..577`; frame-layout comment `:15..39`; `triple_owner` field in `src/structures.asm`; BANK! F1 guard (`-273` `THROW_BANK_FROM_BANKED`) `src/banking.asm:174..228`; BANK@ `:98..104`; BANK-OF `:977..1003`; BANKS `:324..330`; BANKS-CLEAR `:578..582`.
- **F2 COLD-init (makes AC1's workaround removal safe):** bank-table[1..28].here = `$8000` at COLD (Story 19.5.1); behaviourally gated by probe-19.5.1-C (`test-repl-banking-isolated-19-5-1`); `SLOT2_WINDOW_BASE EQU 0x8000` in `src/constants.asm` (19.5.2 CR).

### Dispatch & return walk (what the new compiled-body probes exercise)

```
Compiled body cell = stub-xt  ($D4CB..$DBFF region; xt-is-stub-address, PD-P4-1)
   stub: [ $EF | target_bank | target_addr.lo | target_addr.hi ]   (4 B, NFR-P4-4)

NEXT  →  LD E,(HL)/INC/LD D,(HL)/INC/EX DE,HL/JP (HL)   (byte-for-byte untouched)
   JP (HL) lands on stub byte 0 = $EF = RST $28
      → $0028 : JP stub_dispatch
         POP HL            ; HL = stub+1 (RST pushed stub+1 on the DATA stack)
         A = (HL) = target_bank
         target_bank == current_bank  OR  == $FF  → INTRA: HL ← target CF, JP (HL)   (no MMU write; AC2, AC5-intra)
         else → CROSS (AC3):  push [caller_bank][caller_IP=DE]; MMU OUT(0x72) bank page; current_bank ← target;
                              DE ← xbank_thunk;  HL ← target CF;  JP (HL)
   ... target body runs ...
   DOCOL target: terminal EXIT pops thunk-IP → NEXT fetches xbank_thunk cell → xbank_restore
   DOVAR/DEFCODE target: NEXT directly with IP = xbank_thunk → xbank_restore   (root cause (b) subsumed; AC4)
      xbank_restore: pop [caller_bank][caller_IP]; MMU restore; current_bank ← caller; DE ← caller_IP; NEXT
```

Banked CATCH/THROW (AC6): `CATCH` frame saves `current_bank` (+8) and `triple_owner` (+9); the **caught** THROW path restores MMU+`current_bank` from +8 and, if a real `BANK!` ran between CATCH and THROW (`triple_owner != (IX+9)`), swaps the live triple back via `bank_triple_swap` (`src/exception.asm:497..517`). The **uncaught** path's bank restore is Epic 21 (fence at `.throw_uncaught`).

### Q-dispositions (defaults adopted unless Ant overrides at dev-pass start)

- **Q1 — Probe fixture placement.** Default: extend `tests/banking_tests_19_3.fth` (it already has bank-5 machinery, the `for pid` grading recipe, and the 19.5.2 witnesses to sit beside), using a distinct `_p1953*` / `probe-19.5.3-*` id family so the existing D/E/F/G grading and the suite-end-last constraint stay intact. Alternative: a fresh `tests/banking_tests_19_5_3.fth` + new isolated target if the 19-3 fixture's layout proves hostile (same Q3-fallback discipline as 19.5.1/19.5.2). **Bucket-pollution rule** ([[feedback_phase4_probe_bank_switch_limitation]] + 19.5.1 finding): behavioural bank-switching probes belong in isolated, kernel-words-only fixtures — never the main `test-repl` suite.
- **Q2 — Probe-19.3-F re-enabled form.** Default: keep F as an EXECUTE-form dispatch+return witness (it already reads cleanly as "the 19.3-F shape, now PASS") and let AC2/AC3 carry the *compiled-body* proof; the cross-bank `@` stays out (FR-P4-26). Alternative: re-express F itself in compiled-body form. Either way F grades PASS and the `@` data read stays fenced.
- **Q3 — Probe-19.3-G scope.** Default: re-enable **intra-bank** CREATE/DOES> compiled-body (proves defect (a) dead); keep the **cross-bank** DOES> case DEFER/documented (DR-1, Epic 20). Alternative (only if it proves trivially green and safe): attempt a bank-0-defined CREATE/DOES> whose DOES> body calls a bank-5 word — but the DOES> body running above `$8000` while mapping a foreign bank is exactly DR-1; do not force it.
- **Q4 — Cross-bank `@` data read.** Default: OUT of scope for every probe (FR-P4-26 doc-and-pray; redesign §5.4). If a probe must observe banked *data* cross-bank, it must re-`BANK!` into the owning bank first (and accept the F1 window-guard rules) — but that is a data-access pattern, not dispatch verification, and is not this story's job.

### Constraints and guardrails

- **Verification, not feature.** Default expectation is 0 B and test/doc-only changes. A kernel edit requires a real surfaced defect (then surface-file-fix per [[feedback_no_preexisting_discharge]], B.2-itemise, plain envelope statement). Do NOT "improve" the 19.5.2 dispatch/CATCH code opportunistically — the epic envelope is already 20 B over.
- **NEXT untouchable.** `src/macros.asm:32..47` stays byte-for-byte (NFR-P4-1 — the whole option-C case rests on it).
- **DR-1 / FR-P4-26 are real limits, not bugs to beat.** Cross-bank-from-bank-N bodies, cross-bank DOES> bodies, and cross-bank pointer reads are F1-guarded documented hazards; the owning fix is Epic 20. Probes prove what works *and* honestly DEFER/document what doesn't.
- **Layout-shift discipline.** AC1's deletions move the dictionary base; straddle-harness diagnosis for any banking-probe trip, never reflex-revert ([[feedback_iz_cpm_trampoline_fragility]] SUPERSEDED). Flat test-643 NOP slot only if flat 643 itself trips ([[feedback_iz_cpm_test_643_quirk]]). F1/F2/F3 untouched; F3 straddle-regression stays green.
- **REPL probe hygiene.** Lines ≤ 128 chars (TIB_SIZE — [[feedback_tib_size_inline_comments]]); colon-body wrappers with run-time `." result=" .`; `0 BANK!` before any `BANKS-CLEAR`; isolated fixtures only for bank-switching ([[feedback_repl_tests_preferred]]). No `disk/a/` files unless a fixture migrates for 19.5.4 (then 0x1A-terminate, [[feedback_cpm_0x1a_eof_marker]]).
- **Solo-dev calibration** ([[feedback_ceremony_diminishing_returns]]): the surface is ~4 new probes + grading clauses + one workaround deletion + status-prose flips. Match the established probe house-style; do not build new probe frameworks.
- **No Claude co-author trailer** on commits ([[feedback_no_claude_coauthor]], STRONG). CR runs separately after dev-pass close (the `CR` command, fresh context — not a story AC).

### Previous-story intelligence (19.5.2, done 2026-06-06; CR + DIV-1 landed)

- **Mechanism is proven via EXECUTE.** probe-19.5.2-a (RST intra end-to-end), -b (non-DOCOL cross-bank, no `@`), -c (CATCH `BANK@` restore), -d (CR-F1 real-`BANK!` triple restore) all PASS. 19.5.3's job is the compiled-body *form* + the *full* NFR-P4-8 case — not re-proving the dispatch primitive.
- **CR-F1 is the load-bearing CATCH fix.** Caught-THROW restores MMU+bank (+8) AND, when a real `BANK!` intervened, the live triple (+9 `triple_owner` + `bank_triple_swap`). AC6's "subsequent definitions work cleanly" is exactly the corruption CR-F1 prevents — exercise it operationally (compile-and-FIND), not just `HERE =`.
- **Bank-0 runtime words have no stub-xt** — use `'`/`LATEST @` returns a CFA for bank-0 words, a stub-xt for bank-N words. probe-19.5.2-d used `'` (not `LATEST @`) for its bank-0 thrower for this reason. Mind this in AC6's bank-0 arm.
- **F1 guard does not constrain dispatch.** The RST handler and thunk write the MMU port directly (not via `BANK!`), so the `-273` window guard never fires on a dispatch path — only on an explicit `BANK!` from window-resident code. A probe's own `5 BANK!` at the REPL (IP in fixed memory) is always legal.
- **Self-calibrating F3 absorbs layout shifts** — trust `test-straddle-regression` across AC1's shift; a straddle FAIL with `e273` present = fixture geometry drift, not a kernel regression (`Makefile:786..795` header).

### Git intelligence

Recent commits: `1e2c44e` (DIV-1 fix HW-verified, HW ledger complete — current HEAD, 26953 B), `1bab95a` (DIV-1 fix +13 B), `2fb448b` (19.5.4 HW UAT evidence anchor), `bddda48`/`cb4408b` (19.5.2 close + CR). Patterns to follow: test/doc edits cite the FR/NFR/PD/probe ids they verify; commit messages name the story + byte delta; CR runs separately post-dev-pass; **no Claude co-author trailer** (STRONG). This story should commit as a small, mostly-test diff with a "verifies FR-P4-15/16/24/25 + NFR-P4-8 banked variant; 0 B" style message (adjust if a fix landed).

### Web research

N/A — Z80/CP/M kernel, zero external dependencies. RST-vector + dispatch semantics verified against the live iz-cpm-banking emulator and the already-completed real-MicroBeast HW UAT (2026-06-06), not web sources.

### Project Structure Notes

- **Tests (primary surface):** `tests/banking_tests_19_3.fth` (workaround removal, F/G re-enable, new AC2/AC3/AC6 probes — or a new `_19_5_3.fth` per Q1), `tests/banking_tests_19_2.fth` (workaround removal), `Makefile` (grading clauses; preserve `for pid` loops + suite-end-last; new isolated target only if Q1-alt chosen).
- **Docs:** `_bmad-output/planning-artifacts/architecture.md` (PD-P4-11 status), `docs/antforth-banking-redesign.md` (§2.1/§3 status; §5.4/§5.5 already cover the FR-P4-26/DR-1 fences — confirm, don't rewrite).
- **Kernel:** none expected. If a fix is forced: the relevant file per the surfaced defect, B.2-itemised, `src/macros.asm` excluded by construction.
- No new THROW codes; no `docs/throw-codes.md` change.

### References

- Epic line + NFR/FR: `epics-phase4-epics-16-22.md:889` (story), `:115` (NFR-P4-8), `:815` (AC6 precedent), `:70` (FR-P4-26), `:902` (epic envelope ~+30..+100 B / cumulative-120-B-breach context).
- ADR: `docs/adr-19-5-cross-bank-dispatch.md` (DR-1 portal-aliasing = contained-not-abolished; DR-2 option C dispatch mechanism this story verifies).
- Predecessor artifact: `_bmad-output/implementation-artifacts/19-5-2-dispatch-rework-stub-aware-next-plus-non-docol-trampoline-targets.md` (mechanism + CR-F1 + the minimal witnesses to extend).
- Redesign fences: `docs/antforth-banking-redesign.md` §5.4 (cross-bank pointer hazard), §5.5 (bank-aware FIND / Epic-20 owning fix), §2.1/§2.2/§3 (dispatch mechanism).
- Memories: [[feedback_no_preexisting_discharge]] (surface-file-fix if a probe exposes a defect) · [[feedback_phase4_probe_bank_switch_limitation]] (isolated-fixture rule for bank-switching probes) · [[project_div1_mmu_port_readback]] (current baseline includes the HW-only DIV-1 fix) · [[feedback_repl_tests_preferred]] · [[feedback_tib_size_inline_comments]] · [[feedback_iz_cpm_test_643_quirk]] · [[feedback_iz_cpm_trampoline_fragility]] (SUPERSEDED) · [[feedback_plain_qa_language]] (envelope reporting) · [[feedback_post_hw_smoke_steps_at_review]] (STRONG — close-message HW statement) · [[feedback_cpm_0x1a_eof_marker]] · [[feedback_ceremony_diminishing_returns]] · [[feedback_no_claude_coauthor]] (STRONG).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context)

### Debug Log References

- **Load-bearing pre-flight (decisive):** traced the bank-N dictionary-linking / FIND path before authoring any compiled-body probe. Confirmed via `src/compiler.asm:359..396` (Story 19.3.1 Defect-2 `.bh_skip_bucket_update`) + `src/dictionary.asm:114..208` (`search_wid_for_name`) + redesign §5.5 that **bank-N words are NOT FIND-able by name from bank 0** — the shared FORTH-WORDLIST bucket update is deliberately skipped for `current_bank>0`, and bank-aware FIND-by-name is Epic-20 scope. Consequence: AC3's *literal source syntax* (`: CALLER ... BANKED-WORD ... ;` referencing a bank-5 name from bank 0) would `-13` at compile time. The *dispatch mechanism* this story verifies (NEXT `JP (HL)` → stub `$EF`/`RST $28` of a compiled thread cell) is independent of FIND-by-name and fully achievable: capture the portable stub-xt (`LATEST @`) and inject it into the caller body via `[ COMPILE, ]` — a genuine compiled thread cell, dispatched byte-identically to a by-name reference.
- **Empirical pre-validation (scratch fixtures, since removed):** ran each new probe shape standalone under `iz-cpm-banking` before integrating — AC2 intra (`result=-1`, BANK@=5), AC3 cross (`result=-1`, BANK@=0), AC4 F re-enable (`result=-1`), AC5 G intra CREATE/DOES> (`result=-1`, BANK@=5), AC6 full NFR-P4-8 (`result=-1`). All five passed first run; no kernel defect surfaced.
- **doc-sync `[story-cite]` gotcha:** appending the literal token `Story 19.5.3` to architecture.md raised 1 drift (`tools/check-doc-sync/check-doc-sync.sh:197` requires a matching `### Story 19.5.3:` epics header). Reworded the architecture.md note to "Epic 19.5 compiled-body verification pass", matching the existing Layout-v2 line's convention (it writes "Epic 19.5 dispatch-rework story", not `Story 19.5.2`). Redesign doc is not story-cite-checked. 0 drift restored.

### Completion Notes List

**Verification story — mechanism shipped by Story 19.5.2 proven behaviourally in compiled-body form. 0 B kernel delta (test + doc only); no kernel change needed.**

- **AC1** — removed the `$9000 ALLOT` bank-N HERE workaround from all three sites (`banking_tests_19_3.fth` probe-D + probe-19.3.1-A, `banking_tests_19_2.fth` probe-D) + header prose. Story 19.5.1's F2 COLD-init (`bank-table[1..28].here = $8000`) makes it redundant; D/E/19.3.1-A confirmed still PASS, no bank-0 corruption.
- **AC2/AC3** — new compiled-body probes `probe-19.5.3-ac2` (intra-bank, BANK@=5) and `probe-19.5.3-ac3` (cross-bank-from-bank-0 north-star, BANK@=0). Both dispatch a banked word from a *compiled thread cell* via NEXT's `JP (HL)` → `RST $28` → `stub_dispatch` (intra / cross path), not via explicit EXECUTE — the genuine FR-P4-15/16 proof. Built with the `[ COMPILE, ]` stub-xt-injection idiom (by-name source awaits Epic-20 bank-aware FIND; the dispatch path is byte-identical).
- **AC4** — re-enabled `probe-19.3-F` as a live cross-bank DOVAR dispatch+return witness (the exact former-hang shape, now returns via `xbank_thunk`/`xbank_restore`; body-addr window-resident + BANK@=0). Cross-bank `@` data read stays OUT (FR-P4-26 fence, documented in-probe). F auto-promotes DEFER→PASS via the existing 3-tier grading (zero Makefile loop edit — loop membership + grading + suite-end-last all preserved).
- **AC5** — re-enabled `probe-19.3-G` as an intra-bank CREATE/DOES> compiled-body probe (maker+instance via `LATEST @ EXECUTE`; DOES>-body `@` → 42 intra-bank, BANK@=5). Proves DTC defect class (a) retired. Cross-bank DOES> kept documented-DEFER (DR-1, Epic 20) via a labelled note line.
- **AC6** — new `probe-19.5.3-ac6` exercises the FULL NFR-P4-8 banked-CATCH guarantee beyond the minimal 19.5.2-c/d witnesses: caught cross-bank THROW after a real `BANK!` asserts (a) code=99, (b) BANK@=catcher, (c) catcher-bank triple proven *operationally* (HERE unchanged + post-catch `:` lands & is FIND-able), (d) thrower-bank (5) definition works cleanly after switching back. 5-flag verdict; PASS.
- **AC7** — F/G probe comments + both file headers flipped from "DEFERRED" to "verified 19.5.3"; redesign §2.1/§3 + architecture.md PD-P4-11 Layout-v2 block got append-only "verified 19.5.3" status blockquotes (no history rewrite). `check-doc-sync` 0 drift.
- **AC8 — final surface sweep (all green, actuals):** binary **26953 B (0 B delta vs 26953 baseline, commit 1e2c44e)**; `test-repl` 975/0; `test-repl-banking` 63/0; `test-repl-banking-isolated` (19-2, workaround removed) 6 PASS; `test-repl-banking-isolated-19-3` **15 PASS / 0 FAIL** (D/E PASS, **F PASS**, **G PASS**, 19.3.1-A PASS, 19.5.2-b/c/d PASS, **new ac2/ac3/ac6 PASS**, all suite-end sentinels present); `test-repl-banking-isolated-19-4` 2/0; `-19-5-1` 2/0; `test-repl-banking-skip` 25 PASS/3 SKIP/0 FAIL; `test-straddle-regression` 3/3; `check-doc-sync` 0 drift / 31 advisory.
- **AC9 — fences honoured:** cross-bank-from-bank-N bodies, cross-bank DOES> bodies, and cross-bank `@` data reads kept DEFER/documented (DR-1/FR-P4-26, Epic-20 owning fix). AC1's layout shift caused no straddle trip (F3 stays 3/3). No flat test-643 trip → no `cold_start` NOP re-tune.
- **AC10 — HW posture:** **No deferred HW smoke for Story 19.5.3.** Its surface (compiled-body dispatch + banked CATCH) is fully emulator-verifiable under `IZCPM_BANKING`, and the Epic-19.5 HW ledger is already COMPLETE (2026-06-06 UAT: A1/A2/A3 + F1/F2 + DIV-1 found/fixed/HW-verified, commits 2fb448b → 1bab95a → 1e2c44e). No new fixture requires silicon confirmation; if 19.5.4 wants any folded into its close-out batch, 0x1A-terminate before SLIDE per [[feedback_cpm_0x1a_eof_marker]].

### Change Log

| Date | Change |
|------|--------|
| 2026-06-07 | Story 19.5.3 dev-pass: compiled-body verification + full banked NFR-P4-8 variant. Removed `$9000 ALLOT` workaround (AC1); added compiled-body probes ac2/ac3 + full NFR-P4-8 probe ac6; re-enabled probe-19.3-F/G as live PASS; doc status appends (redesign §2.1/§3, architecture.md PD-P4-11). 0 B kernel delta; all surfaces green. Status → review. |

### File List

- `tests/banking_tests_19_3.fth` (modified) — AC1 workaround removal (probe-D, probe-19.3.1-A) + header prose; AC4 probe-19.3-F live re-enable; AC5 probe-19.3-G intra CREATE/DOES> re-enable + cross-DEFER note; AC2/AC3/AC6 new probes (`probe-19.5.3-ac2/ac3/ac6`) + `---probe-19.5.3-suite-end---`; AC7 F/G comment + header rewords.
- `tests/banking_tests_19_2.fth` (modified) — AC1 workaround removal (probe-19.2-D) + header prose.
- `Makefile` (modified) — `test-repl-banking-isolated-19-3` recipe: added `for pid in ac2 ac3 ac6` grading block + `---probe-19.5.3-suite-end---` no-halt check (the d/e/f/g loop is unchanged; F/G auto-promote to PASS).
- `docs/antforth-banking-redesign.md` (modified) — AC7 append-only "verified 19.5.3" status blockquotes at §2.1 and §3.
- `_bmad-output/planning-artifacts/architecture.md` (modified) — AC7 append-only "compiled-body dispatch behaviourally delivered" status blockquote in the PD-P4-11 Layout-v2 block.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — story row ready-for-dev → in-progress → review.
- `_bmad-output/implementation-artifacts/19-5-3-compiled-body-verification-banked-catch-variant.md` (modified) — this story file: tasks checked, Dev Agent Record, File List, Change Log, Status.
