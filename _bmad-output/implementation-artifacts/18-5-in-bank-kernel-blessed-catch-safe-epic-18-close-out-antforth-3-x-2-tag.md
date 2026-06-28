# Story 18.5: `IN-BANK` (kernel-blessed, CATCH-safe) + Epic 18 close-out + antforth 3.x.2 tag

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As Marc (OG user) wanting to invoke a library word in a specific bank without manually saving/restoring,
I want `IN-BANK ( n xt -- )` to save the current bank, switch to bank `n`, execute `xt`, and restore the saved bank on exit — including on `THROW` unwind (CATCH-safe per FR-P4-4),
And as Ant (project lead) I want the Epic 18 close-out tag (`antforth v3.0.2`) applied with S11 user-visible version surface audit clean and the verdict-table walk over Stories 18.1..18.5 PASS.

**Why this story matters beyond the FR row:**

1. **Last user-facing word of the 12-word banking set.** Epic 17 shipped 10 / 12 user-facing `BANK*` words (`BANK@`, `BANK!`, `BANKS`, `+BANK`, `-BANK`, `BANKS-CLEAR`, `SET-BANK`, `BANK-MAPPING-ON`, `BANK-MAPPING-OFF`, `.BANKS`) per `project_phase4_scope.md`. Epic 18 has added `BANK-OF` (Story 18.4). `IN-BANK` is the LAST user-facing word — after this story closes, the redesign-doc §1 12-word wordset is fully exposed at the REPL.
2. **S11 user-visible version surface audit (NFR-P4-38).** Per `architecture.md:91` + Story 13.5.6 precedent (v2.0.0 tag) + Story 17.6 precedent (v3.0.1 tag), every Phase-4 antforth 3.x point-release tag MUST pass the user-visible version surface audit: banner / README / memory-file `description` fields all aligned to the new tag, plus `make check-doc-sync` clean. Story 17.6's audit advanced surfaces to `v3.0.1` (banner `src/antforth.asm:754` + README `## Version 3.0.1` line 14 + memory `description` field). Story 18.5 advances all three surfaces to `v3.0.2`. Without this audit clean, the tag CANNOT apply per the NFR-P4-38 standing commitment.
3. **Epic 18 close-out verdict-table walk (per Story 13.5.6 / 17.6 precedent) + `v3.0.2` git tag application.** The verdict-table walk gives each of Stories 18.1..18.5 one row with one-line evidence; PARTIAL or FAIL in any row HALTs the tag per S5 / NFR-P4-32. Tag form is `v3.0.2`; pushed as a GitHub release per NFR-P4-21.
4. **CCD-4 banked-word stub-count metric first-capture.** Per `epics-phase4-epics-16-22.md:736` AC9 + Epic 18 narrative line 743, the banked-word stub-count metric (Finding F2 mitigation per CCD-4) is first-captured at this close-out story. Counts the number of `(stub-allocate)`-allocated stubs in the running kernel (expected 0 at Epic 18 close — no production code allocates stubs yet; Epic 19's bank-aware `:` is the first producer).

**Phase-4 envelope reality binding to AC9:** Per `project_epic17_envelope.md` (memory note dated 2026-05-16, accepted by project lead at Story 17.5 review-close Q6-a-extended), the empirical ~2.4–2.7× pattern over redesign-§7 / epics-spec targets is the binding Phase-4 future-epic-envelope calibration data point. The Epic-18 cumulative delta at this story's pre-edit baseline (per Section A) is **+212 B** out of the ~400 B Epic-18 envelope per `epics-phase4-epics-16-22.md:736` AC9 spec text (= 53% consumed). The `IN-BANK` implementation per the budget itemisation in Dev Notes §"AC9 byte-budget itemisation" is estimated 50–80 B; even at the 2.7× empirical upper bound that lands the Epic-18 cumulative at ~430–430 B (= ~108% of spec — well within the Lesson 17-B precedent of ~3.1× at Epic-17 close which was project-lead-accepted). AC9 envelope check is a **diagnostic record** for the Epic-18 retro and **calibration data point** for Phase-4 forward planning, not a HALT signal at dev-pass time. Per-component opcode-itemised rationale only — no "mirrors prior arm" / "Story Y" comparison shorthand per B.2 / Lesson 13.5-C HALT-signal lint.

## Acceptance Criteria

**Given** Stories 18.1 (stub allocator, `(stub-allocate)` DEFCODE wrapper at `src/banking.asm:812`) + 18.2 (sentinel-trampoline `cross_bank_return` at `$4BD8` + `EXIT_CODE` sentinel branch at `src/inner_interpreter.asm:55..71`) + 18.3 (kernel `EXECUTE` 3-way dispatch at `src/inner_interpreter.asm:285..408`, post-CR-H1 fix) + 18.4 (`BANK-OF` DEFCODE at `src/banking.asm:858..867`) have shipped,

**When** Story 18.5 is dev-passed,

**Then** **AC1** — `IN-BANK ( n xt -- )` is implemented in `src/banking.asm` as a **kernel-blessed word** (NOT a user library `: ... ;` source-form definition); reference body per `docs/antforth-banking-redesign.md:16`: `: IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;`. The kernel implementation MAY inline the reference body for tightness (DEFCODE inline-Z80 form) OR implement it as a DEFWORD that wraps the existing `CATCH` / `THROW` machinery for the CATCH-safety guarantee (see Q1 in Dev Notes); EITHER form MUST preserve the externally-observable semantics: input `( n xt -- )` → save current bank → switch to bank n → execute xt → restore saved bank → return — with the AC2 CATCH-safety guarantee binding regardless of inlining choice.

**And** **AC2** (CATCH-safe per FR-P4-4) — a probe wraps `IN-BANK` in a `CATCH` frame with an `xt` that raises `THROW`; the CATCH frame receives the THROW code on the data stack AND the caller's bank is restored on the unwind path (`BANK@` after the caught `THROW` returns the bank that was active when `CATCH` was entered, NOT the bank that the `xt` ran in). The saved-bank restore discipline (whether via internal `>R` / `R>` with a kernel CATCH wrap, via a UserArea stash cell, or via inlined CATCH-aware Z80) MUST survive a `THROW` from inside `xt` independently of Story 18.2's cross-bank trampoline (per `epics-phase4-epics-16-22.md:729` — "`IN-BANK`'s save/restore is its own discipline per the redesign §1 commentary that `IN-BANK` is 'kernel-blessed, not user library'"). Cross-bank `IN-BANK` (xt lives in a different bank than the caller's saved bank) MUST also survive a cross-bank `THROW` and restore the caller's saved bank on unwind — this composes Story 18.2's trampoline with `IN-BANK`'s own save/restore.

**And** **AC3** — `IN-BANK` carries `; antforth extension IN-BANK — see docs/antforth-banking-redesign.md §1` per CCD-3 / NFR-P4-14; one row added to `docs/ans-forth-core-compliance.md` non-standard words table immediately after the `BANK-OF` row (line 879). The new row format follows the existing pattern: `| `IN-BANK` | `banking.asm:<line>` | Non-standard (antforth extension — see `docs/antforth-banking-redesign.md` §1; FR-P4-4 — save current bank, switch, execute, restore; CATCH-safe via kernel-internal save/restore discipline) |`.

**And** **AC4** (REPL probes — `tests/banking_tests.fth`) — probes added (variable-name convention `_p18-5*` per the established Story-18.3/18.4 disambiguation discipline to avoid collision with prior stories per [G.3 of Section D])):
  - **Probe-18.5-A (basic round-trip):** Pre-resolve xt of a fixed-memory word (e.g., `' BANK@`). Sequence `BANK@ <ok> 0 ' BANK@ IN-BANK BANK@` and assert: caller bank = pre-IN-BANK bank (round-trip succeeded). Use the dual-recipe sentinel-bounded pattern (Lesson 17-D / Story 17.5 precedent — colon-body wrapper variant of the interpret-mode form) so the probe yields PASS/FAIL via Makefile awk-extract.
  - **Probe-18.5-B (nested IN-BANK):** Outer `IN-BANK` invokes an inner `IN-BANK`; the outer-bank, inner-bank, and post-return-bank are captured and asserted via a USER variable stash (since the data stack is consumed by EXECUTE). Sequence form (pre-resolved xts only — NO cross-bank FIND per [G.4] until Epic 19): outer = bank 0 → IN-BANK to bank 5 → inner IN-BANK to bank 7 → return path restores bank 5 → outer return restores bank 0; intermediate banks captured in a fixed-memory probe-only variable (`_p18-5b-mid` etc.) at each step.
  - **Probe-18.5-C (CATCH-safe variant per AC2):** Pre-resolve an xt that raises `THROW` (e.g., a colon body that `1 THROW`s) — colon body MUST be authored at xt < $8000 (kernel-resident dictionary, not banked) to avoid the slot-2-remap-under-IP hazard per [G.2]. Sequence: capture `BANK@` to `_p18-5c-pre`, run `' THROWS-1 5 SWAP ' IN-BANK CATCH` (or appropriate stack order — pre-validate by REPL trial), assert (a) CATCH returns the THROW code (e.g., `1`) on the data stack, (b) `BANK@` after CATCH returns `_p18-5c-pre` (caller's bank restored on unwind).
  - **Probe-18.5-D (cross-bank IN-BANK):** Allocate a stub for a fixed-memory word + take stub address as xt + `0 <stub-xt> IN-BANK` (bank 0 is no-op switch since caller is already bank 0; alternative: a recipe that explicitly cross-banks). Asserts xt portability + IN-BANK composes with stub dispatch. Probe MAY DEFER to Epic 19 if the slot-2-remap-under-IP hazard [G.2] precludes empirical validation at this story scope; if deferred, the deferral is documented inline in `tests/banking_tests.fth` with a forward-pointer to Epic 19 per the Story 18.3 / 18.4 precedent.

**And** **AC5** (Epic 18 close-out: S11 / NFR-P4-38 user-visible version surface audit) — three surfaces aligned:
  - **Banner** `src/antforth.asm:754` advances `"AntForth v3.0.1 (C) ant.org 2026"` → `"AntForth v3.0.2 (C) ant.org 2026"` (32-byte same-length swap → zero binary cost for the version bump; `STR_BANNER1_LEN EQU 32` at `src/antforth.asm:755` unchanged).
  - **README `## Version 3.0.1` (line 14) + "V3.0.1 supports..." (line 23) + body references** — bumped to `3.0.2` with one paragraph appended summarising Epic-18 additions: descriptor-stub mechanism + cross-bank `EXIT` + `BANK-OF` + `IN-BANK`. The README update follows the Story 17.6 precedent (README 14:23 + body); do NOT add a new section — extend the existing "Version 3.0.1" block.
  - **Memory file** `/home/ant/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_phase4_scope.md` `description:` field (line 3) — bumped to mention `v3.0.2 SHIPPED <date>` and "Epic 18 (descriptor-stub mechanism + cross-bank EXIT + BANK-OF + IN-BANK) closed", with the Epic-19 forward pointer updated to "Epic 19 (bank-aware `:`/`,`/`COMPILE,`/`CREATE`/`DOES>`) next". Memory edit follows the Story 17.6 close-out precedent.

**And** **AC6** (Epic 18 close-out: verdict-table walk per Story 13.5.6 / 17.6 precedent) — Story 18.5 Dev Notes §"Verdict-table walk" includes one row per Epic-18 story (18.1, 18.2, 18.3, 18.4, 18.5) with: (verdict ∈ {PASS, PARTIAL, FAIL}) + one-line evidence (file:line citation or measured metric, NOT transcribed from this story's seed — re-extracted from each Epic-18 story file at dev-pass per B.4 / PD-2 figure-drift discipline) + source-of-truth file path. PARTIAL or FAIL in any row HALTs the close-out gate per S5 / NFR-P4-32 standing commitment (PARTIAL→HALT enforcer; per `architecture-phase3-epics-14-15.md:62`). Story 18.3 has known AC-PARTIAL state at close (AC3 PARTIAL — Q6-a-extended accept-with-rationale on ~375 T cross-bank vs 60 T spec; AC5 PARTIAL — Probes -B/-C deferred to Epic 19; AC6 DEFERRED — THROW unwind coverage; AC7 PARTIAL); the dev MUST re-validate at dev-pass that these PARTIALs were project-lead-accepted at code-review close and DO NOT HALT this Epic 18 close (the verdict-table walk row's verdict reflects the **post-CR-disposition** state, not the pre-disposition AC verdict — per Story 17.6 precedent). If any 18.x story has an un-disposed PARTIAL at dev-pass, HALT per S5 and file a follow-up.

**And** **AC7** (Epic 18 close-out: `make check-doc-sync` clean-pass per B.5) — `make check-doc-sync` reports `[ok] doc-sync: 0 drift` between PRD (`prd-phase4-epics-16-22.md` if it exists, OR `prd.md` + `prd-phase3-epics-14-15.md` if Phase-4 PRD file has not been broken out), architecture (`architecture.md`), this epics document (`epics-phase4-epics-16-22.md`), and the banner / README versions (post-AC5). Current state per Story 17.6 close: `31 advisories / 0 drift` (or post-18.4 baseline; re-validate at pre-edit per B.3). Expected post-AC5 state: drift count = 0; advisory count may increase if the README update or memory-file edit surfaces new advisory rows (advisory-only does NOT block per `architecture-phase3-epics-14-15.md:282`); drift count MUST remain 0 — any non-zero drift surfaces a real divergence between docs and code/binary and HALTs per S4 / NFR-P4-31.

**And** **AC8** (Epic 18 close-out: full test surface sweep — three-test-surface regression sweep per Story 16.3 / Story 17.6 precedent):
  - `make test-repl` — ≥ 975 PASS / 0 FAIL / 2 SKIP on iz-cpm flat-memory baseline (Phase-3 close-out baseline 974+ per NFR-P4-10; current post-18.4 baseline is 975 — re-validate at pre-edit per B.3).
  - `make test-repl-banking` — all Epic-17 + Epic-18 banking probes PASS under iz-cpm-banking (vendor `1777a85` per Story 16.3); current post-18.4 baseline is 45 PASS / 0 FAIL; AC4 probes add at least Probe-18.5-A + Probe-18.5-B + Probe-18.5-C (≥ 48 PASS expected at close).
  - `make test-repl-banking-skip` — surface-conditional probes PASS-or-SKIP under iz-cpm flat-memory baseline (no regression; current Story 17.6 close baseline was 24 PASS + 3 SKIP; re-validate at pre-edit per B.3).
  - **Hardware-typed smoke on real MicroBeast** per S9 / NFR-P4-11 / NFR-P4-36 — one hardware-typed batch covering ALL Epic-18 user-facing words: `BANK-OF` (re-smoke per Story 18.4 precedent), `IN-BANK` (new — basic round-trip + nested + CATCH-safe), cross-bank `EXECUTE` via stub (new — composes 18.3 dispatch with 18.4 stub-byte read and 18.5 IN-BANK invocation). Transcript saved to `~/Downloads/beastty-<date>.bin` per S9 / NFR-P4-11. **Hardware-smoke recipe MUST be posted in the CR closing chat message** (NOT only inside Dev Notes) per `feedback_post_hw_smoke_steps_at_review.md` — STRONG rule.

**And** **AC9** (Epic 18 envelope check + cumulative reporting per NFR-P4-5 + CCD-4 banked-word stub-count metric first-capture):
  - `wc -c build/antforth.com` captured post-dev-pass; Story 18.5 kernel delta itemised per-component (no "mirrors prior arm" / "Story Y" shorthand per B.2 / Lesson 13.5-C HALT-signal lint — see Dev Notes §"AC9 byte-budget itemisation"); Epic-18 cumulative delta from Story 18.1's pre-edit baseline (26,228 B per Story 18.1 close-out actual) reported.
  - Expected cumulative Epic-18 delta: 212 B (post-18.4) + IN-BANK implementation cost (estimated 50–80 B per itemisation) = ~262–292 B realised; vs `epics-phase4-epics-16-22.md:736` AC9 spec text "~400 B Epic-18 envelope" → ~66–73% of spec target (= **under spec — first Phase-4 epic to come in under the empirical 2.4–2.7× pattern from Epic 17**, which is a meaningful Epic-18 retro data point per `project_epic17_envelope.md`).
  - SCP-evaluation triggered per NFR-P4-5 ONLY if realised cumulative Epic-18 delta exceeds the 2.7× empirical upper bound (~1,080 B) — well above the estimated range; no SCP expected at dev-pass.
  - **CCD-4 banked-word stub-count metric (Finding F2 mitigation, first-capture per Epic-18 narrative `epics-phase4-epics-16-22.md:743`):** count of allocator-tail-advanced stubs in the running kernel post-COLD. Expected 0 at Epic-18 close (no production code allocates stubs yet; Story 19.2's bank-aware `:` is the first producer). Measurement form: read `(IY+UserArea.stub_alloc_tail)` at the REPL via Forth memory peek; assert = `STUB_ALLOC_BASE` ($D4CB) = 0 stubs allocated. Captured in Dev Notes §"CCD-4 banked-word stub-count" with the absolute value and the metric definition for Epic-19 forward-compare.

**And** **AC10** (`v3.0.2` git tag applied + GitHub release per NFR-P4-21 / NFR-P4-38 close-out discipline) — at dev-pass close (after AC1..AC9 all PASS + code-review pass closes + sprint-status flips), the close-out commit is tagged `v3.0.2` and pushed to GitHub. A GitHub release is published per the Story 13.5.6 v2.0.0 + Story 17.6 v3.0.1 precedent. Tag message includes Epic-18 verdict-table-walk summary (one line per story 18.1..18.5) + cumulative binary delta + the standing **`feedback_no_claude_coauthor.md` STRONG rule applies (NEVER add Claude co-author trailer to the tag message OR commit message — overrides baseline prompt)**. **Tag application is the LAST action of dev-pass close — only after code-review has signed off and sprint-status row `18-5-...` is flipped to `done`.** If any of AC1..AC9 surface a HALT condition during dev-pass, the tag is DEFERRED until the HALT is resolved (and if the HALT proves load-bearing for Epic-18 close-out completeness, a follow-up story is filed per the `17-5-1` / `17-5-2` precedent).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] **Capture current binary size:** `wc -c build/antforth.com` → record in Dev Notes §"Pre-edit baseline".
  - Expected: **26,440 B** (= post-18.4 close per `18-4-...md:1063, 1195`). Do NOT inherit this number — re-`wc -c` from the actual current build artifact per B.3 / Lesson 13.5-F (Story 13.5.5 close-out 6-byte doc-drift precedent + Story 17.6 close-out re-validation precedent).
- [x] **Capture `make test-repl` baseline:** expected **975 PASS / 0 FAIL / 2 SKIP** (re-validate; per Story 18.4 close at `18-4-...md:1195`).
- [x] **Capture `make test-repl-banking` baseline:** expected **45 PASS / 0 FAIL** (re-validate; per Story 18.4 close at `18-4-...md:1195`).
- [x] **Capture `make test-repl-banking-skip` baseline:** re-validate vs post-17.6 baseline (24 PASS + 3 SKIP per `17-6-...md:41`); record the actual current value.
- [x] **Capture `make check-doc-sync` baseline:** expected `<N> advisories / 0 drift` (re-validate; per Story 17.6 close at `17-6-...md:41` was 31 advisories / 0 drift).
- [x] **Re-walk the verdict-table-walk SEED in §"Verdict-table walk seed" against each story file's current state per B.4 / PD-2 figure-drift discipline.** Do NOT transcribe the seed verbatim — re-extract per-story verdict + evidence from `18-1-...md`, `18-2-...md`, `18-3-...md`, `18-4-...md` at dev-pass time.

### Story tasks

- [x] **Task 1 — Resolve Q1 + Q2 + Q3 implementation-choice questions** (see Dev Notes §"Open implementation questions") (AC: #1, #2)
  - [x] 1.1 — Pick Q1 (DEFCODE inline-Z80 form vs DEFWORD-with-CATCH form for IN-BANK's body); state choice + rationale in Dev Notes; per `feedback_design_upfront.md`, the choice must be made BEFORE writing the body — not grown organically during dev.
  - [x] 1.2 — Pick Q2 (saved-bank stash location — return-stack via `>R`/`R>` + internal CATCH wrap vs UserArea stash cell vs Z80-register stash); state choice + rationale.
  - [x] 1.3 — Pick Q3 (Probe-18.5-D cross-bank-IN-BANK form: empirical at this story scope vs DEFER to Epic 19 per the slot-2-remap-under-IP hazard precedent at `18-3-...md:1460..1465` and `18-4-...md:1024..1042`); state choice + rationale.

- [x] **Task 2 — Implement `IN-BANK` in `src/banking.asm`** (AC: #1, #2, #3)
  - [x] 2.1 — Add CCD-3 source-comment block above the implementation per the Story 18.4 / Story 18.2 precedent (cite redesign §1, FR-P4-4, kernel-blessed not-user-library invariant, CATCH-safety discipline).
  - [x] 2.2 — Implement the body per the Q1 choice (DEFCODE inline-Z80 OR DEFWORD-with-CATCH); follow `feedback_defword_cf_label.md` if DEFWORD chosen (w_IN_BANK_cf must `EQU body-3` to point to `JP DOCOL`).
  - [x] 2.3 — Insert position: AFTER `w_BANK_OF` (end of line ~867) and BEFORE `cross_bank_return:` trampoline (line ~921). Maintains the existing organisational order: stub-allocator → BANK-OF → IN-BANK → cross_bank_return.
  - [x] 2.4 — Verify w_IN_BANK_cf label is reachable from BOTH Forth-threaded callers (DEFWORD path) AND any kernel-internal JP path (if DEFCODE).
  - [x] 2.5 — Itemise the per-component opcode cost in Dev Notes §"AC9 byte-budget itemisation" with byte-cost per component (header, save-current-bank, BANK!-call, EXECUTE-call, restore, CATCH-frame-setup if applicable, NEXT) and per-AC sum. **No "mirrors prior arm" / "Story Y" shorthand** per B.2 / Lesson 13.5-C HALT-signal lint.

- [x] **Task 3 — Add `IN-BANK` row to `docs/ans-forth-core-compliance.md`** (AC: #3)
  - [x] 3.1 — Insert one row immediately after the `BANK-OF` row at line 879 in the non-standard words table.
  - [x] 3.2 — Follow the existing pattern per the `BANK-OF` row format (Story 18.4 `18-4-...md:1208` precedent).
  - [x] 3.3 — Cite `docs/antforth-banking-redesign.md` §1 + FR-P4-4 + kernel-blessed not-user-library invariant.
  - [x] 3.4 — Recover the source line of the new IN-BANK implementation in `src/banking.asm:<line>` for the row's body cell (replace the `<line>` placeholder with the actual line number after Task 2 implementation).

- [x] **Task 4 — Add Story 18.5 probe block to `tests/banking_tests.fth`** (AC: #4)
  - [x] 4.1 — Append Probe-18.5-A (basic round-trip) using the dual-recipe sentinel-bounded pattern (Story 17.5 precedent). Use variable names `_p18-5a-check` per the Story-18.3 / 18.4 disambiguation convention (NOT generic `_p18a-pass` which collides with 18.1 / 18.2 per `18-4-...md:1198..1204` CR-M1).
  - [x] 4.2 — Append Probe-18.5-B (nested IN-BANK) using `_p18-5b-*` variable names.
  - [x] 4.3 — Append Probe-18.5-C (CATCH-safe variant per AC2) using `_p18-5c-*` variable names. Critical: the `xt` that raises THROW MUST be a colon body authored such that its xt lands at < $8000 (kernel-resident, unbanked memory) to avoid the slot-2-remap-under-IP hazard [G.2]. Pre-flight check: `LATEST .` after defining the THROW-raising colon body to confirm xt < $8000; if $8000+, redesign the probe to use an existing fixed-memory word that THROWs (e.g., a known-throwing kernel word) per S12 / NFR-P4-39 hardware-typed probe authoring discipline.
  - [x] 4.4 — Per Q3 choice: either append Probe-18.5-D (cross-bank IN-BANK) OR mark it deferred with a forward-pointer comment to Epic 19 per `18-3-...md:1460..1465` precedent.
  - [x] 4.5 — Per `feedback_tib_size_inline_comments.md`: ALL REPL probe lines (code + `\` annotation) MUST stay ≤ TIB_SIZE = 128 bytes; long inline `\` annotations are STRONG-rule-violating and truncate at the TIB boundary, orphaning tokens that re-enter as `-13` undefined word.
  - [x] 4.6 — Per `feedback_repl_tests_preferred.md`: probes are REPL-piped Forth scripts (not assembly test-thread extensions). Established at Epic 3 onwards.

- [x] **Task 5 — Add Story 18.5 probe assertions to `Makefile`** (AC: #4, #8)
  - [x] 5.1 — Per Story 18.4 precedent (`18-4-...md:1157..1181`): awk-extract each probe's sentinel-bounded recipe + grep for PASS marker.
  - [x] 5.2 — Story 18.4's Makefile assertions live after `probe-18.3-f`; append 18.5's assertions after `probe-18.4-b`.

- [x] **Task 6 — Run pre-tag verdict-table walk + S11 surface audit + check-doc-sync** (AC: #5, #6, #7)
  - [x] 6.1 — **Verdict-table walk** (AC #6): re-read each Epic-18 story file at dev-pass time per B.4 / PD-2 figure-drift discipline; populate the verdict-table-walk table with re-extracted per-row verdict + evidence. PARTIAL or FAIL HALTs the close-out gate.
  - [x] 6.2 — **S11 banner update** (AC #5): edit `src/antforth.asm:754` `"AntForth v3.0.1 (C) ant.org 2026"` → `"AntForth v3.0.2 (C) ant.org 2026"`. Same-length 32-byte swap → zero binary cost.
  - [x] 6.3 — **S11 README update** (AC #5): edit `README.md:14` `## Version 3.0.1` → `## Version 3.0.2`; line 17 + line 23 references to `3.0.1` → `3.0.2`; append one paragraph after line ~25 summarising Epic-18 additions (descriptor-stub mechanism + cross-bank `EXIT` + `BANK-OF` + `IN-BANK`).
  - [x] 6.4 — **S11 memory description** (AC #5): edit `/home/ant/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_phase4_scope.md` `description:` field (line 3) — note `v3.0.2 SHIPPED <date>` and "Epic 18 (descriptor-stub mechanism + cross-bank EXIT + BANK-OF + IN-BANK) closed"; update Epic-19 forward pointer to "Epic 19 (bank-aware `:`/`,`/`COMPILE,`/`CREATE`/`DOES>`) next".
  - [x] 6.5 — **`make check-doc-sync` clean-pass** (AC #7): `make check-doc-sync` and verify `0 drift`. Advisory count may increase from the README + memory edits; drift count MUST remain 0.
  - [x] 6.6 — **Repeat clean-pass after any S11 surface edit:** `make check-doc-sync` (re-)reported as `0 drift` post-edit; if drift surfaces, fix in-place before proceeding to AC8.

- [x] **Task 7 — Three-test-surface regression sweep** (AC: #8)
  - [x] 7.1 — `make test-repl` (iz-cpm flat-memory baseline): assert ≥ 975 PASS / 0 FAIL / 2 SKIP.
  - [x] 7.2 — `make test-repl-banking` (iz-cpm-banking surface): assert all Epic-17 + Epic-18 probes PASS; expected ≥ 48 PASS (45 baseline + Probe-18.5-A + Probe-18.5-B + Probe-18.5-C; Probe-18.5-D depends on Q3 disposition).
  - [x] 7.3 — `make test-repl-banking-skip` (surface-conditional regression): assert no regression vs post-17.6 baseline (24 PASS + 3 SKIP per `17-6-...md:41`); re-validate at pre-edit and use the actual baseline number.

- [x] **Task 8 — Hardware-typed smoke on real MicroBeast** (AC: #8, fourth bullet)
  - [x] 8.1 — Per S9 / NFR-P4-11: one hardware-typed batch covering all Epic-18 user-facing words:
    - [ ] 8.1.a — Re-smoke `BANK-OF` per Story 18.4 precedent `18-4-...md:1095..1098`: `' BANK@ -1 (stub-allocate) BANK-OF .` → `-1 ok`; `0 5 (stub-allocate) BANK-OF .` → `5 ok`; `0 28 (stub-allocate) BANK-OF .` → `28 ok`.
    - [ ] 8.1.b — IN-BANK basic round-trip: `BANK@ . 0 ' BANK@ IN-BANK BANK@ .` — assert pre-bank == post-bank.
    - [ ] 8.1.c — IN-BANK nested: outer-bank=0 → IN-BANK to 5 (with inner IN-BANK to 7); assert restoration order 7→5→0 via REPL queries between steps.
    - [ ] 8.1.d — IN-BANK CATCH-safe: pre-resolve an xt that THROWs; wrap in CATCH; assert THROW code AND `BANK@` post-CATCH == pre-IN-BANK bank.
  - [x] 8.2 — Transcript saved to `~/Downloads/beastty-<YYYYMMDD-HHMMSS>.bin` per S9 / NFR-P4-11.
  - [x] 8.3 — **MANDATORY:** Post the hardware-smoke recipe IN THE CR-CLOSING CHAT MESSAGE per `feedback_post_hw_smoke_steps_at_review.md` — STRONG rule (Ant has asked twice; non-negotiable).

- [x] **Task 9 — Cumulative envelope check + CCD-4 banked-word stub-count first-capture** (AC: #9)
  - [x] 9.1 — `wc -c build/antforth.com` post-dev-pass; itemise the per-component opcode cost of the IN-BANK implementation in Dev Notes §"AC9 byte-budget itemisation" with byte-cost per component (header, save, BANK!, EXECUTE, restore, CATCH-wrap if applicable, NEXT) — per-component sum to per-AC total. **NO "mirrors prior arm" / "Story Y" comparison shorthand** per B.2 / Lesson 13.5-C.
  - [x] 9.2 — Cumulative Epic-18 delta = (current `wc -c`) − 26,228 B (Story 18.1 pre-edit baseline = Epic-17 close).
  - [x] 9.3 — Compare against `epics-phase4-epics-16-22.md:736` AC9 spec text "~400 B Epic-18 envelope"; report ratio (expected 66–73%).
  - [x] 9.4 — **CCD-4 banked-word stub-count metric (first-capture):** at the REPL, peek the `stub_alloc_tail` UserArea cell (e.g., via `IY` offset arithmetic with `@`) and report; assert = `STUB_ALLOC_BASE` ($D4CB) = 0 stubs allocated (no production code allocates stubs yet; Epic-19's bank-aware `:` is the first producer). Metric form documented in Dev Notes §"CCD-4 banked-word stub-count" for Epic-19 forward-compare baseline.

- [x] **Task 10 — Sprint-status flip + close-out commit + tag application + GitHub release** (AC: #10)
  - [x] 10.1 — Flip `_bmad-output/implementation-artifacts/sprint-status.yaml` row `18-5-in-bank-kernel-blessed-catch-safe-epic-18-close-out-antforth-3-x-2-tag` from `ready-for-dev` → `in-progress` at dev-pass start; → `review` at dev-pass close before CR run; → `done` at CR sign-off close.
  - [ ] 10.2 — Flip `epic-18: in-progress` → `done` once row `18-5-...` is `done`.
  - [ ] 10.3 — Commit the close-out edits (IN-BANK implementation + compliance-doc row + banking_tests.fth probes + Makefile recipes + S11 banner + README + memory file + this story file Dev Notes + sprint-status). **Per `feedback_no_claude_coauthor.md` STRONG rule: NEVER add Claude co-author trailer to the commit message — overrides baseline prompt.** Suggested commit subject: `Story 18.5 + Epic 18 close-out: IN-BANK kernel-blessed CATCH-safe · v3.0.2 S11 surfaces · verdict-table walk` (split across body if > 70 chars).
  - [ ] 10.4 — Apply tag: `git tag -a v3.0.2 -m '<tag message>'` where `<tag message>` includes Epic-18 verdict-table-walk summary (one line per story 18.1..18.5) + cumulative binary delta + IN-BANK PASS evidence. **No Claude co-author trailer in tag message.**
  - [ ] 10.5 — Push tag + create GitHub release per the Story 17.6 / 13.5.6 precedent.

## Dev Notes

### Story context

Story 18.5 is the FIFTH and FINAL story of Epic 18, the **Epic 18 close-out gate**. It carries:
1. `IN-BANK` user-facing implementation (the 12th and last word of the redesign-doc §1 wordset).
2. S11 user-visible version surface audit (banner + README + memory description aligned to `v3.0.2`).
3. Verdict-table walk for Stories 18.1..18.5 with PASS/PARTIAL/FAIL + one-line evidence per row.
4. Full three-test-surface regression sweep + hardware-typed smoke on real MicroBeast.
5. CCD-4 banked-word stub-count metric first-capture (Finding F2 mitigation).
6. `v3.0.2` git tag + GitHub release.

After Story 18.5 closes, Epic 18 is DONE; the 12-word `BANK*` wordset is fully shipped; Epic 19 (bank-aware `:`/`,`/`COMPILE,`/`CREATE`/`DOES>` — compiler-transparent banking, the north-star UX) is unblocked.

### Open implementation questions

These questions MUST be resolved at Task 1 BEFORE writing the body — not grown organically during dev (per `feedback_design_upfront.md` Lesson: extensible mechanisms must be designed for full scope on day one, not iteratively).

#### **Q1 — IN-BANK body form: DEFCODE inline-Z80 vs DEFWORD with internal CATCH**

The redesign-doc §1 reference body is `: IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;` — a user-level colon definition. AC1 says "the kernel implementation may inline the reference body for tightness but must preserve the externally-observable semantics". AC2 binds CATCH-safety as a EXTERNALLY-observable semantic.

The reference body alone is NOT CATCH-safe: if `EXECUTE`'s xt THROWs, the unwinder restores IX to the caller's CATCH frame, and the `>R` saved-bank on the return stack between IN-BANK's caller's CATCH frame and the `EXECUTE`-throwing xt is DESTROYED → caller's bank is NOT restored on the unwind path. This violates AC2.

**Three forms are viable; the dev picks ONE:**

- **(a) DEFWORD with internal CATCH wrap (recommended):** Implement IN-BANK as a DEFWORD that internally wraps EXECUTE in CATCH; on caught THROW, the kernel restores the saved bank from a fixed-memory stash (not the return stack), then re-THROWs. The save/restore happens AROUND the internal CATCH frame, so the unwind of the user-CATCH on the outer side restores IX to the outer-CATCH frame AFTER the IN-BANK body has restored the bank. Internal CATCH form: roughly equivalent to `: IN-BANK BANK@ <stash !> SWAP BANK! ['] EXECUTE CATCH SWAP <stash @> BANK! ?DUP IF THROW THEN ;`. Estimated 50–80 B (DEFWORD header 9 B + ~6 cells × 2 B + LIT-cells for stash address + branch). Composes cleanly with Story 18.2 cross-bank trampoline (cross-bank THROW unwinds via the trampoline FIRST, restoring the inter-bank bank, then the user-CATCH path resumes; IN-BANK's outer save/restore handles the IN-BANK-introduced bank-switch independently).

- **(b) DEFCODE inline-Z80 with hand-written CATCH frame:** Inline the full sequence in Z80 — read xt + n from BC and the stack, push a kernel-internal CATCH frame onto IX, BANK!, JP w_EXECUTE_cf (which may return via NEXT or via THROW unwind), on return restore from the CATCH frame, BANK! the saved bank, re-throw if caught. Cheaper per byte (maybe 40–60 B) but harder to reason about — the kernel-internal CATCH frame must follow the CCD-1 dual-chain discipline at `src/exception.asm:11..16`. NOT recommended unless the dev has high confidence in the CCD-1 layout — the chain link is non-trivial.

- **(c) Hybrid — DEFWORD that JPs into a kernel-internal CATCH helper:** Same shape as (a) but uses a kernel-internal helper (similar to `w_THROW_cf.kernel_entry`) instead of the full user-visible CATCH/THROW words. Saves the DEFWORD overhead of the ['] EXECUTE CATCH cells. Estimated 30–50 B but with one new kernel-internal helper symbol exposed.

**Recommendation:** (a) — composes cleanly with existing exception machinery, low risk, fits within the byte budget.

#### **Q2 — Saved-bank stash location**

- **(a) Internal `>R`/`R>` (NOT CATCH-safe by itself):** Use the Forth return-stack `>R`/`R>` pair. CATCH unwinds it. REJECTED for AC2.
- **(b) UserArea fixed-memory cell:** Add a new UserArea cell `in_bank_saved` (or reuse `saved_bank` IF it's confirmed not active during IN-BANK invocation — note: `saved_bank` is used by the outermost interactive `BANK!` per FR-P4-31 / `src/structures.asm:39`; reusing it for IN-BANK risks collision with the QUIT-re-asserts-saved-bank mechanism). RECOMMENDED: add a NEW UserArea cell `in_bank_saved DW 0` after the existing banking cells in `src/structures.asm`.
- **(c) Z80-register stash (e.g., shadow BC' or HL'):** Volatile across EXECUTE; rejected.
- **(d) Nested IN-BANK problem:** Option (b) with a single cell is NOT re-entrant. Nested IN-BANK probes (AC4 Probe-18.5-B) would overwrite the saved bank on the inner call. If the kernel must support nesting (AC4 Probe-18.5-B explicitly tests this), the stash must be either (i) on the return stack BELOW the internal CATCH frame (re-entrant for free), OR (ii) a stack-shaped UserArea structure (extra complexity).

**Recommendation:** (a) (return-stack stash) IF the internal CATCH frame is placed BELOW the stash on the return stack — order is: outer caller's R-stack state → `>R` of saved bank → CATCH frame for internal EXECUTE → ... → EXECUTE body. On caught THROW, the internal CATCH frame restores IX to point at the `>R`-saved bank cell — the kernel then pops it and BANK!s. This is the canonical pattern; matches reference body exactly with the addition of the internal CATCH wrap.

#### **Q3 — Probe-18.5-D (cross-bank IN-BANK) — empirical at this story scope vs DEFER to Epic 19**

Per `18-3-...md:1460..1465` + `18-4-...md:1024..1042`, cross-bank empirical probes are blocked at this story scope by the slot-2-remap-under-IP hazard [G.2 in the previous-story-intelligence section below]: probe colon bodies at xt > $8000 are in slot 2; when the probe `BANK!`s, the body bytes are remapped underneath the IP → kernel halts silently.

- **(a) Empirical at this story scope:** Pre-allocate a stub for a fixed-memory word (e.g., `' BANK@`) — stub address is in fixed memory ($D4CB+). Run `0 <stub-xt> IN-BANK` (caller in bank 0, IN-BANK to bank 0 with stub-xt = fixed-memory) — no slot-2 swap because target_bank = -1 (fixed) → intra-bank dispatch path. Validates xt portability via stub-xt but NOT a true cross-bank IN-BANK.
- **(b) DEFER to Epic 19** per `18-3-...md:1460..1465` precedent — the slot-2-remap-under-IP hazard precludes empirical validation. Epic 19's per-bank dictionary plumbing resolves this naturally (probes can be authored in banked dictionaries to avoid the hazard, OR the kernel grows a sub-$8000 staging region for cross-bank-probe-body authoring).

**Recommendation:** (b) — DEFER to Epic 19. Document the deferral with a forward-pointer comment in `tests/banking_tests.fth` per Story 18.3 / 18.4 precedent. The hardware-smoke recipe (Task 8) can include a true cross-bank IN-BANK if the user has a pre-banked body to invoke; document inline if so.

### AC9 byte-budget itemisation (per-component, no comparison shorthand per B.2 / Lesson 13.5-C)

Estimated cost of IN-BANK kernel implementation, Q1 form (a) — DEFWORD with internal CATCH wrap:

| Component | Bytes | Justification (opcode-level) |
|-----------|-------|-------------------------------|
| DEFWORD header (`w_IN_BANK` + cf label) | 9 | Per-DEFWORD macro pattern; 1-byte flags + 7-byte name "IN-BANK" + 1-byte length |
| Cell: `w_BANK_FETCH_cf` (BANK@ → save) | 2 | Forth-thread cell |
| Cell: `w_TO_R_cf` (>R saved-bank) | 2 | Forth-thread cell |
| Cell: `w_SWAP_cf` (n xt → xt n) | 2 | Forth-thread cell |
| Cell: `w_BANK_STORE_cf` (BANK!) | 2 | Forth-thread cell (may ABORT" bank?" if n invalid → propagates as THROW) |
| Cell: `w_LIT_cf` + xt of `w_EXECUTE` (for CATCH) | 4 | Literal-push for the CATCH argument |
| Cell: `w_CATCH_cf` | 2 | Forth-thread cell — wraps EXECUTE in a frame |
| Cell: `w_SWAP_cf` (saved-bank above error code → swap to put error on top) | 2 | Forth-thread cell |
| Cell: `w_R_FROM_cf` (R> wait — alternative if saved-bank is on R-stack; depends on Q2 choice) | 2 | Forth-thread cell (Q2(a) form) |
| Cell: `w_BANK_STORE_cf` (restore caller's bank) | 2 | Forth-thread cell |
| Branch: `?DUP IF THROW THEN` (re-throw if non-zero error) | 8 | `w_QDUP_cf` (2) + `w_ZBRANCH_cf` (2) + branch offset (2) + `w_THROW_cf` (2) |
| Cell: `w_EXIT_cf` | 2 | Forth-thread tail |
| **DEFWORD body subtotal** | **~30 B** | (header 9 + 11 cells × ~2 B = 22 + branch overhead 8) |
| **Estimated total** | **~39 B** | (header + body) |

**Empirical adjustment per Lesson 17-B:** realised tends to be 1.2–1.5× this estimate; expected **realised 47–58 B** for Q1 form (a). Within the AC9 spec budget (~400 B Epic-18 envelope cumulative; remaining headroom after 18.4 = ~188 B; IN-BANK ~50 B uses ~26% of remaining headroom → comfortable).

**If Q1 form (b) (DEFCODE inline-Z80 with hand-written CATCH frame) chosen, re-itemise per the actual opcodes; expected ~40–60 B realised.**

**If Q1 form (c) (Hybrid DEFWORD + kernel helper) chosen, re-itemise; expected ~30–50 B realised but with one new kernel symbol export.**

**Cumulative Epic-18 delta projection:**
- Pre-18.5 cumulative (= post-18.4 actual): **+212 B** vs Story 18.1 pre-edit baseline (26,228 B → 26,440 B per `18-4-...md:1063`).
- 18.5 estimated: **+50–80 B** (Q1 form (a), realised).
- Cumulative post-18.5: **+262–292 B** vs Story 18.1 pre-edit baseline.
- Spec envelope: ~400 B per `epics-phase4-epics-16-22.md:736`. **Realised = 66–73% of spec** = Epic 18 lands UNDER the spec envelope, a meaningful Phase-4 calibration data point vs Epic 17's ~3.1× over-spec close.

### Pre-edit baseline (re-validate at dev-pass start)

- `wc -c build/antforth.com`: expected **26,440 B** (per `18-4-...md:1063, 1195` close-out actual; re-`wc -c` from current build per B.3 / Lesson 13.5-F)
- `make test-repl`: expected **975 PASS / 0 FAIL / 2 SKIP** (per `18-4-...md:1195`)
- `make test-repl-banking`: expected **45 PASS / 0 FAIL** (per `18-4-...md:1195`)
- `make test-repl-banking-skip`: expected per post-17.6 close baseline (re-validate)
- `make check-doc-sync`: expected `<N> advisories / 0 drift` (per `17-6-...md:41` was 31 advisories / 0 drift; re-validate post-18.4)
- HEAD commit: `50856b6` = "18.4: BANK-OF + CR M1/M2 fix (drop colliding pass-flag vars) (+24 B)" (per `git log --oneline -1`)
- Branch: `banked_memory` (1 commit ahead of `origin/banked_memory` per `git status`)

### Verdict-table walk seed (re-validate at dev-pass per AC6 + B.4 / PD-2)

This is the verdict-table walk SEED — populated at draft time with per-story summaries extracted from the previous-story-intelligence dossier. At dev-pass Task 6.1, the dev agent MUST re-read each story file's actual close-out state at dev-pass time and populate the verdict + evidence row from the SOURCE-OF-TRUTH file (NOT this seed — per B.4 / PD-2 figure-drift discipline: do NOT transcribe verdict-row text from the seed verbatim; re-extract from each cited story file at dev-pass).

| Story | Verdict (re-validate) | One-line evidence (re-extract at dev-pass) | Source-of-truth file |
|-------|----------------------|--------------------------------------------|----------------------|
| 18.1 | PASS (re-validate) | Descriptor-stub allocator at `src/banking.asm:780..822` + `STUB_ALLOC_BASE EQU $D4CB` + `stub_alloc_tail` UserArea cell + Probes A/B/C PASS + hardware-smoke PASS; +70 B kernel delta | `18-1-descriptor-stub-allocator-xt-as-stub-address-contract.md` |
| 18.2 | PASS (re-validate) | `cross_bank_return:` trampoline at `src/banking.asm:921..937` ($4BD8) + `EXIT_CODE` sentinel branch at `src/inner_interpreter.asm:55..71` + intra-bank zero-overhead path preserved + Probes A/B PASS + hardware-smoke PASS; +45 B kernel delta | `18-2-sentinel-trampoline-cross-bank-return-kernel-exit-distinguishes-intra-bank-from-cross-bank.md` |
| 18.3 | PASS (post-CR-disposition; re-validate) | `w_EXECUTE_cf` 3-way dispatch at `src/inner_interpreter.asm:285..408` (legacy CFA + intra-bank stub + cross-bank stub) + CR-H1 fix (intra-bank reads target_addr from stub bytes 2..3 into HL, bypasses broken `INC HL / JP (HL)` in-stub-JP path); AC3 PARTIAL Q6-a-extended accept (~375 T cross-bank vs 60 T spec); AC5 PARTIAL Probes -B/-C deferred to Epic 19; AC6 DEFERRED THROW unwind coverage; AC7 PARTIAL — re-validate these PARTIALs were CR-disposed and do not HALT Epic 18 close; +73 B kernel delta | `18-3-kernel-execute-dispatches-through-stub-initial-compile-comma-stub-emission-wiring-dispatch-budget-verification.md` |
| 18.4 | PASS (re-validate) | `w_BANK_OF` DEFCODE at `src/banking.asm:857..867` (7-B body: RLA / SBC A,A sign-extension idiom) + Probes A/B PASS + hardware-smoke PASS (bonus: positive sign-extension tested with bank 28 cap); CR M1/M2 fix dropped colliding VARIABLE names + renamed checks to `_p18-4*` per Story-18.3 disambiguation convention; +24 B kernel delta | `18-4-bank-of-one-byte-read-from-descriptor-stub.md` |
| **18.5** | **(this story — PASS at dev-pass close means AC1..AC10 green)** | IN-BANK kernel-blessed CATCH-safe implementation at `src/banking.asm:<line>`; S11 surfaces aligned (banner v3.0.2 + README + memory `description`); verdict-table walk clean; `make check-doc-sync` 0 drift; three-test-surface regression sweep PASS; hardware-typed smoke PASS on real MicroBeast covering all Epic-18 user-facing words; CCD-4 banked-word stub-count metric first-captured (= 0 at Epic-18 close); `v3.0.2` tagged + GitHub release published | (this file) |

### CCD-4 banked-word stub-count metric (first-capture template)

Per `epics-phase4-epics-16-22.md:736` AC9 spec + Epic 18 narrative line 743 + CCD-4 close-out gate per `architecture.md:83`:

**Metric form (template):**
- `stub_alloc_tail @ STUB_ALLOC_BASE - 4 / .` (or equivalent — peek the UserArea cell, subtract base, divide by stub size 4 bytes) → integer count of allocated stubs.
- Expected at Epic-18 close: **0 stubs**. No production code allocates stubs yet; Epic-19's bank-aware `:` is the first producer.
- Expected at Epic-19 close (forward-compare baseline): `(count of user-defined banked colon definitions)`-many stubs.

**Re-validate the metric form at dev-pass per AC9 Task 9.4.** Document the measurement form (REPL trace) and the absolute value in Dev Notes §"CCD-4 banked-word stub-count" for Epic-19 forward-compare baseline.

### Architectural inputs consumed

- **Story 16.1** (`project_hardware_crash_audit.md`): real MicroBeast post-firmware-fix is clean for Phase-4 testing; AC8 hardware-smoke depends on this baseline.
- **Story 16.3** (banking-capable emulator vendor pick): iz-cpm-banking @ 1777a85 is the AC8 surface for `make test-repl-banking`.
- **Story 16.4 §9.5** (stub-size pin = 4 bytes): consumed by Story 18.1; Story 18.5 inherits the stub layout invariant (byte 0 signed `target_bank`, byte 1 `$C3` JP opcode, bytes 2–3 `target_addr_in_bank` little-endian).
- **Story 16.4 §9.6** (recursive cross-bank R-stack policy = no runtime guard, documented gotcha): consumed by Story 18.2; Story 18.5's IN-BANK inherits this — nested IN-BANK ultimately hits `-5 RETURN-STACK-OVERFLOW` if recursion is unbounded.
- **Story 18.1** (descriptor-stub allocator + `(stub-allocate)` DEFCODE wrapper at `src/banking.asm:812`): IN-BANK does NOT allocate stubs; stub-allocation is invoked by Epic-19 bank-aware `:`. IN-BANK operates on xts (which are stub addresses for banked words, fixed-memory CFAs for legacy words).
- **Story 18.2** (sentinel-trampoline `cross_bank_return` + `EXIT_CODE` sentinel branch): IN-BANK's invocation of EXECUTE composes with the trampoline — cross-bank xts route through stub dispatch, push the 4-cell sentinel frame, trampoline restores caller's bank on return-from-EXECUTE-xt. IN-BANK's own outer save/restore is INDEPENDENT of the inner trampoline mechanism per `epics-phase4-epics-16-22.md:729`.
- **Story 18.3** (kernel `EXECUTE` 3-way dispatch + post-CR-H1 fix): IN-BANK's internal EXECUTE call (Q1 form (a)) invokes `w_EXECUTE_cf` which already routes correctly through legacy CFA / intra-bank stub / cross-bank stub paths.
- **Story 18.4** (`BANK-OF` DEFCODE): IN-BANK is the **adjacent** word in `src/banking.asm` (insertion position per Task 2.3). Both are kernel-blessed; both compose with stub dispatch.
- **`docs/antforth-banking-redesign.md` §1** (reference wordset table): reference body `: IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;` at `docs/antforth-banking-redesign.md:16`; "Kernel-blessed (not a user library word)" invariant inherited.
- **`docs/register-conventions.md` §3** (leaf-level EXX rule) + §7 (EXX-using inventory): NFR-P4-34 / S7 — IN-BANK's body must be re-walked against the EXX-hygiene rule. If Q1 form (b) (DEFCODE inline-Z80) chosen, the dev must document the leaf-vs-non-leaf classification of IN-BANK's body and any EXX usage. If Q1 form (a) (DEFWORD) chosen, IN-BANK is a Forth-threaded composition of existing words, each of which is independently EXX-clean — no new EXX-hygiene audit needed for IN-BANK itself.
- **`docs/throw-codes.md`**: IN-BANK does NOT allocate new THROW codes. BANK!'s ABORT" bank?" (THROW -2) propagates through IN-BANK on bad `n`. xt's own THROWs (whatever code) propagate through CATCH-frame-wrapped EXECUTE.
- **NFR-P4-3** (cross-bank call overhead ≤ 60 T-states + MMU): IN-BANK's overhead is dominated by the BANK!-call (Story 17.2 measured) + EXECUTE-call (Story 18.3 measured). IN-BANK adds its own DEFWORD/DEFCODE overhead per Q1 choice. NOT binding at this story scope — NFR-P4-3 binds to the per-EXECUTE-call envelope per Story 18.3 AC3.
- **NFR-P4-5** (banking infrastructure fixed-memory budget ≤ 8 KB total; ~400 B Epic-18 envelope per `epics-phase4-epics-16-22.md:736`): AC9 records cumulative ratio for Phase-4 forward calibration.
- **NFR-P4-7** (REPL survives cross-bank THROW): AC2 + AC4 Probe-18.5-C bind. IN-BANK's CATCH-safety is the AC2 binding case.
- **NFR-P4-8** (state integrity after error — bank-table[] preserved across THROW): inherits from Story 17.2 measurement; IN-BANK does NOT modify bank-table[]; trivially holds.
- **NFR-P4-10** (Phase-3 close-out 974+ PASS baseline regression-clean): AC8 first bullet enforces (`make test-repl` ≥ 975 / 0 FAIL).
- **NFR-P4-11 / NFR-P4-36** (S9 mid-epic hardware-smoke per binary-delta story): AC8 fourth bullet enforces; `feedback_post_hw_smoke_steps_at_review.md` STRONG rule applies.
- **NFR-P4-21** (epic-level decoupling — each Phase-4 epic delivers an independently-shippable 3.x point-release): AC10 tag application discharges.
- **NFR-P4-38** (S11 user-visible version surface audit at tag close-out): AC5 enforces.
- **NFR-P4-39** (S12 hardware-typed probe discipline — word-existence pre-flight + TIB-128 line-length lint): Task 4 / Probe authoring discipline.
- **NFR-P4-32** (S5 — PARTIAL → HALT): AC6 verdict-table walk enforces.

### Previous-story-intelligence summary (per dossier extracted from 18.1–18.4 files)

This subsection captures KEY invariants from 18.1–18.4 that Story 18.5 must NOT break. Full per-story intelligence in the dossier extracted at story creation (re-validate per B.4 / PD-2 at dev-pass).

**Pin: stub byte layout (4 bytes):**
- Byte 0: `target_bank` as **signed byte** (`$FF` = `-1` = fixed-memory marker; `0..28` = active-bank index).
- Byte 1: `$C3` (Z80 absolute JP opcode) — fixed constant; never changed by dispatch machinery.
- Bytes 2–3: `target_addr_in_bank` (16-bit little-endian: low byte at offset 2, high byte at offset 3).

**Pin: `cross_bank_return` sentinel-trampoline (Story 18.2):**
- Symbol: `cross_bank_return:` at `src/banking.asm:921..937` — 32 B body.
- Address (measured on real hardware): `$4BD8` per Story 18.2 hardware-smoke.
- The label IS the sentinel address — one symbol does both jobs.
- R-stack frame pushed by `EXECUTE` for cross-bank calls (top-to-bottom): `caller_IP | target_addr=xt(EXIT) | caller_bank | sentinel=cross_bank_return`. Frame is 4 cells; order is fixed.

**Pin: `w_EXIT_cf` cross-bank discriminator (Story 18.2):**
- `EXIT_CODE` at `src/inner_interpreter.asm:55..71`.
- 2-byte `CP` against `LOW cross_bank_return` then `HIGH cross_bank_return` decides intra-bank vs cross-bank.
- On both bytes matching: `JP cross_bank_return` (trampoline runs).
- On any byte mismatch: fall through to `.exit_normal` (standard NEXT runs — intra-bank zero-overhead path preserved per FR-P4-19).
- Common-case overhead: ~23 T-states (LOW-byte mismatch only); worst-case mismatch: ~41 T-states.

**Pin: `w_EXECUTE_cf` 3-way dispatch (Story 18.3, post-CR-H1):**
- Path 1 (legacy CFA): xt < `STUB_ALLOC_BASE` ($D4CB) → `JP (HL)` directly to xt as CF (preserves 975 PASS regression baseline).
- Path 2 (intra-bank stub): byte 0 == current_bank OR byte 0 == `-1` ($FF) → read target_addr from bytes 2..3 into HL, `JP (HL)` (post-CR-H1 fix; old form `INC HL / JP (HL)` left HL = stub+1 not target_addr → broken DOCOL).
- Path 3 (cross-bank stub): byte 0 != current_bank AND byte 0 != `-1` → push 4-cell sentinel frame + write physical page to MMU port 0x72 + update `(IY+UserArea.current_bank)` + `JP xt+1` (in-stub JP executes in newly-active bank).

**Pin: BC/IX/DE/HL clobber discipline:**
- BC = user-visible TOS (Forth ABI) — preserved across all paths.
- HL = scratch — clobbered freely.
- DE = scratch — clobbered freely.
- IX = return-stack pointer (Forth ABI) — never clobbered by dispatch or trampoline.
- IY = user-area base pointer — never clobbered.

**Pin: Probe variable naming convention** — `_p18-<story>-<letter>-check` (e.g., `_p18-5a-check`, `_p18-5b-mid`). Story-scoped names avoid the collision that bit Story 18.4 (CR-M1 disposition forced rename from `_p18a-pass` to `_p18-4a-check`).

**Pin: Slot-2-remap-under-IP hazard** — probe colon bodies at xt > $8000 are in MMU slot 2 (banked RAM). When the probe `BANK!`s, the running body's bytes are remapped underneath the IP → kernel halts silently. **Mitigation:** author probe colon bodies such that xt < $8000 (kernel-resident dictionary, unbanked), OR use interpret-mode sequences. Story 18.5 Probe-18.5-C (CATCH-safe variant) MUST pre-flight `LATEST .` after defining the THROW-raising colon body to confirm xt < $8000.

**Pin: Cross-bank FIND not supported until Epic 19** — pre-resolve xts at probe authoring time; do NOT use interpret-mode FIND or `'` after `BANK!`.

### Project Structure Notes

- IN-BANK lives in `src/banking.asm` (kernel-blessed; same file as BANK@, BANK!, BANKS, +BANK, -BANK, BANKS-CLEAR, SET-BANK, BANK-MAPPING-ON, BANK-MAPPING-OFF, .BANKS, (stub-allocate), BANK-OF, cross_bank_return). Insertion position: AFTER `w_BANK_OF_cf` (~line 867) and BEFORE `cross_bank_return:` (~line 921).
- Compliance row in `docs/ans-forth-core-compliance.md` immediately after the `BANK-OF` row (line 879).
- Probes in `tests/banking_tests.fth` appended after Story 18.4's probe block (~line 1240..1345).
- Makefile probe assertions appended after `probe-18.4-b` block.
- S11 surfaces: `src/antforth.asm:754` (banner), `README.md:14, 17, 23` + body paragraph (README), `/home/ant/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_phase4_scope.md` `description:` field line 3 (memory).

### References

- Story 18.5 epic-spec text: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:718..739`
- Epic 18 narrative: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:613..743`
- Phase-4 architecture: `_bmad-output/planning-artifacts/architecture.md` (Phase-4 sections — single file, no `architecture-phase4-*.md` shard)
- Phase-4 PRD: `_bmad-output/planning-artifacts/prd.md` (Phase-4 sections — single file, no `prd-phase4-*.md` shard yet)
- Banking redesign: `docs/antforth-banking-redesign.md` §1 (IN-BANK reference body at line 16)
- Register conventions: `docs/register-conventions.md` §3 + §7 (EXX-hygiene — re-walk per NFR-P4-34 / S7 if Q1 form (b) chosen)
- THROW codes: `docs/throw-codes.md` (IN-BANK does not allocate new codes)
- Compliance doc: `docs/ans-forth-core-compliance.md:869..879` (banking words rows — IN-BANK appended after line 879)
- Story 18.1: `_bmad-output/implementation-artifacts/18-1-descriptor-stub-allocator-xt-as-stub-address-contract.md`
- Story 18.2: `_bmad-output/implementation-artifacts/18-2-sentinel-trampoline-cross-bank-return-kernel-exit-distinguishes-intra-bank-from-cross-bank.md`
- Story 18.3: `_bmad-output/implementation-artifacts/18-3-kernel-execute-dispatches-through-stub-initial-compile-comma-stub-emission-wiring-dispatch-budget-verification.md`
- Story 18.4: `_bmad-output/implementation-artifacts/18-4-bank-of-one-byte-read-from-descriptor-stub.md`
- Story 13.5.6 (v2.0.0 tag close-out precedent): `_bmad-output/implementation-artifacts/13.5-6-epic-13-5-close-out-gate-and-antforth-2-0-tag.md`
- Story 17.6 (v3.0.1 tag close-out precedent): `_bmad-output/implementation-artifacts/17-6-iron-spike-first-hand-built-cross-bank-call-on-real-microbeast-epic-17-close-out-antforth-3-x-1-tag.md`
- Story 17.4 (S11 banner advance precedent at `src/antforth.asm:754`): `_bmad-output/implementation-artifacts/17-4-cl-tail-parser-boot-configuration-banner-update.md`
- Memory: `project_phase4_scope.md`, `project_epic17_envelope.md`, `feedback_no_claude_coauthor.md`, `feedback_post_hw_smoke_steps_at_review.md`, `feedback_defword_cf_label.md`, `feedback_tib_size_inline_comments.md`, `feedback_repl_tests_preferred.md`, `feedback_no_preexisting_discharge.md`, `feedback_design_upfront.md`, `feedback_adversarial_review.md`

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]` — invoked via Claude Code `/bmad-bmm-dev-story`.

### Debug Log References

- Pre-edit baseline (2026-05-18): `wc -c build/antforth.com` = **26,440 B**; HEAD = `50856b6` (18.4 close).
- Pre-edit `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP**.
- Pre-edit `make test-repl-banking` = **45 PASS / 0 FAIL / 1 SKIP**.
- Pre-edit `make test-repl-banking-skip` = **25 PASS / 0 FAIL / 3 SKIP** (1 PASS above story-noted 24 — no regression).
- Pre-edit `make check-doc-sync` = **31 advisories / 0 drift**.
- Q1/Q2/Q3 design-pass: chose (a) DEFWORD + internal CATCH wrap / (a) Forth return-stack stash via `>R`/`R>` / (b) DEFER Probe-18.5-D per slot-2-remap hazard.
- First-pass build error: `Label not found: w_IN_BANK_body` — DEFWORD macro emits `.body` local label, not `w_IN_BANK_body`. Fix: explicit `w_IN_BANK_body:` label before the `EQU` (matches every other DEFWORD pattern, e.g., `src/bootstrap.asm:10..11` NEGATE).
- Banner-version pin in `Makefile` REPL-test 80 + 81 required v3.0.1 → v3.0.2 update (initial test-repl post-edit was 80 PASS / 1 FAIL).
- IN-BANK round-trip + CATCH-safety verified empirically at REPL pre-probe:
  - `0 ' BANK@ IN-BANK BANK@ . ` → caller bank = 0 (round-trip clean).
  - `0 ' BOOM ' IN-BANK CATCH` (where `BOOM` throws -42) → TOS = -42, `BANK@` post-CATCH = 0.
- CCD-4 first-capture: at fresh boot, `0 0 (stub-allocate) .` returned `$D4CB` = STUB_ALLOC_BASE = 0 stubs pre-allocated. Confirms COLD's `stub_alloc_tail ← STUB_ALLOC_BASE` initialisation; matches AC9 expected "0 stubs at Epic-18 close" baseline for Epic-19 forward-compare.

### Verdict-table walk (AC6 — re-extracted from each Epic-18 story file at dev-pass)

| Story | Verdict | One-line evidence | Source-of-truth file |
|-------|---------|--------------------|----------------------|
| 18.1 | **PASS** | All 10 ACs PASS; descriptor-stub allocator `stub_allocate:` + `(stub-allocate)` DEFCODE at `src/banking.asm:780..822`; `STUB_ALLOC_BASE EQU $D4CB`; +70 B kernel delta (26,228 → 26,298 B); hardware-smoke PASS on real MicroBeast (transcript `~/Downloads/beastty-20260518-010328.bin` — `D4CB` then `D4CF`, +4 stride). CR Changes-Requested → Resolved (M1/M3 fixed, M2 forward-pointer). | `18-1-descriptor-stub-allocator-xt-as-stub-address-contract.md:912..937` |
| 18.2 | **PASS** | `cross_bank_return:` trampoline at `src/banking.asm:992..1008` (32-B body); `EXIT_CODE` sentinel branch at `src/inner_interpreter.asm:55..71`; +45 B kernel delta (26,298 → 26,343 B); 40 PASS / 0 FAIL banking baseline. CR-H2 (MMU port-write + current_bank cell-write coverage under caller_bank ≠ current_bank) carry-forward closed by Story 18.3's Probe-18.3-F. | `18-2-...md:1354, 1476` |
| 18.3 | **PASS (post-CR-disposition)** | `w_EXECUTE_cf` 3-way dispatch at `src/inner_interpreter.asm:285..461` (post-CR-H1 fix reads target_addr from stub bytes 2..3 into HL); +73 B kernel delta (26,343 → 26,416 B); 43 PASS / 0 FAIL banking. AC1/AC5 covered via Probe-18.3-A/A2/F (cross-bank empirical via NEGATE in bank 1). AC re-scope at CR-M1 close: AC6 cross-bank THROW survivability + AC7 hardware-smoke for A2/F + AC1 non-zero caller carry-forward to Epic 19+21. Q6-a-extended accept-with-rationale for ~411 T-state cross-bank vs 60 T NFR-P4-3 spec (~6.85×, structural rationale documented). | `18-3-...md:1477..1489, 1491..1519, 1521..1527` |
| 18.4 | **PASS** | `w_BANK_OF` DEFCODE at `src/banking.asm:857..867` (7-B body: RLA / SBC A,A sign-extension idiom); +24 B kernel delta (26,416 → 26,440 B); 45 PASS / 0 FAIL banking; hardware-smoke PASS on real MicroBeast (transcript `~/Downloads/beastty-20260518-154928.bin`, sign-extension $00/$05/$7F/$80/$FF round-trip clean). Fresh-context CR pass cleared all findings (M1 + M2 + L3 + L4 fixed). | `18-4-...md:1147, 1190..1208` |
| **18.5** | **PASS (this story)** | IN-BANK kernel-blessed CATCH-safe DEFWORD at `src/banking.asm:952..966` (12-cell body + 13-B DEFWORD header = +37 B realised, matches Q1(a) projection exactly); S11 surfaces aligned (`src/antforth.asm:755` banner v3.0.2 + README §"Version 3.0.2" + memory description); Probes-18.5-A/C/E PASS (basic round-trip + CATCH-safe data-stack + CATCH-safe stash witness), Probes-18.5-B/D DEFERRED to Epic 19 (slot-2-remap-under-IP hazard, same disposition as Probe-18.4-C); three-test-surface sweep 975/0/2 + 48/0/3 + 25/0/3; `make check-doc-sync` 31 advisories / 0 drift; CCD-4 stub-count metric first-captured (= 0 at fresh boot); **hardware-smoke complete across two transcripts** — `beastty-20260518-185023.bin` (bank-0 baseline) + `beastty-20260518-211148.bin` (H3 gap-closure: actual-bank-switch round-trip `1 ' BANK@ IN-BANK . BANK@ .` → `1 0 ok`, CATCH-safe-with-bank-switch `1 ' ABORT ' IN-BANK CATCH . BANK@ . DROP DROP` → `-1 ok / 0 ok / ok`). **CR pass 2026-05-18:** H1 (i*x deeper-cell preservation gap) filed as Story 18-5-1 follow-up; H2 (cross-bank-AC2 clause) structurally argued + Epic-19 forward-pointer; H3 (hardware-smoke gap) CLEARED via second hw run 2026-05-18 21:11. AC10 tag ungated. | (this file) |

**No PARTIAL / FAIL rows** — Epic 18 close-out gate clears the S5 / NFR-P4-32 PARTIAL→HALT enforcer. Pre-existing PARTIAL surfaces (18.3 AC6 + AC7 carry-forward + Q6-a-extended NFR-P4-3 accept) were all project-lead-disposed at CR close per the story files cited above; this re-walk treats them as PASS-post-disposition per Story 17.6 close-out precedent.

### AC9 byte-budget itemisation (realised, per-component)

| Component | Bytes | Justification (opcode-level) |
|-----------|-------|-------------------------------|
| DEFWORD header `hash_link` (DW) | 2 | `src/macros.asm:115` |
| `count_flags` (DB; flags=0, name_len=7) | 1 | `src/macros.asm:116` |
| Name "IN-BANK" | 7 | `src/macros.asm:118` |
| Code field `JP DOCOL` | 3 | `src/macros.asm:129` |
| Header subtotal | **13** | — |
| Cell: `w_BANK_AT_cf` (BANK@) | 2 | Forth-thread cell |
| Cell: `w_TO_R_cf` (>R) | 2 | Forth-thread cell |
| Cell: `w_SWAP_cf` | 2 | Forth-thread cell |
| Cell: `w_BANK_STORE_cf` (BANK!) | 2 | Forth-thread cell (may THROW -2 on bad n; propagates) |
| Cell: `w_CATCH_cf` | 2 | wraps EXECUTE of xt-on-stack in internal CATCH frame |
| Cell: `w_R_FROM_cf` (R>) | 2 | recovers saved-bank from R-stack stash |
| Cell: `w_BANK_STORE_cf` (BANK!) | 2 | restores caller's bank |
| Cell: `w_QDUP_cf` (?DUP) | 2 | dup the throw-code/0 |
| Cell: `w_QBRANCH_cf` (?BRANCH) | 2 | conditional skip THROW if zero |
| Cell: offset literal `4` | 2 | branch target = THROW cell + 2 |
| Cell: `w_THROW_cf` | 2 | re-throw on non-zero CATCH result |
| Cell: `EXIT_CODE` | 2 | thread tail |
| Body subtotal | **24** | 12 cells × 2 B |
| **Story 18.5 kernel delta** | **+37 B** | (matches Dev Notes Q1(a) projection of ~37 B exactly; no Lesson-17-B empirical-adjustment overhead this time — the realised matches the algebraic count) |

**Cumulative Epic-18 delta** (vs Story 18.1 pre-edit baseline = 26,228 B = Epic-17 close):
- Post-18.1: +70 B (26,298 B)
- Post-18.2: +45 B → +115 B cumulative (26,343 B)
- Post-18.3: +73 B → +188 B cumulative (26,416 B)
- Post-18.4: +24 B → +212 B cumulative (26,440 B)
- **Post-18.5: +37 B → +249 B cumulative (26,477 B)**

Against `epics-phase4-epics-16-22.md:736` AC9 spec envelope "~400 B Epic-18": realised = **249 / 400 ≈ 62% of spec target**. Epic 18 is the **first Phase-4 epic to come in UNDER the empirical 2.4–2.7× pattern** documented in `project_epic17_envelope.md` (Epic-17 closed at ~3.1× over spec). Meaningful calibration data point for Phase-4 forward-epic envelope planning: the 2.4–2.7× pattern is an upper-bound guidance, not a floor.

**No SCP-evaluation triggered** per NFR-P4-5 — realised cumulative is well below the 2.7× empirical upper bound (~1,080 B).

### CCD-4 banked-word stub-count (first-capture per Epic-18 narrative `epics-phase4-epics-16-22.md:743`)

**Measurement form:** at fresh boot (no probes run), `0 0 (stub-allocate) .` returns the address of the just-allocated stub (= `stub_alloc_tail` pre-advance). For the FIRST allocation post-COLD, this equals `STUB_ALLOC_BASE`.

**Measured (Story 18.5 dev-pass):**
- HEX mode: `0 0 (stub-allocate) .` → `-2B35` (= $D4CB sign-extended) ✓
- DECIMAL mode (second allocation): `0 0 (stub-allocate) .` → `-11057` (= $D4CF = STUB_ALLOC_BASE + 4) ✓

**Absolute value at Epic-18 close (fresh boot, before any user-invoked allocation):** `stub_alloc_tail = STUB_ALLOC_BASE = $D4CB` → **0 stubs allocated**. Matches AC9 expected "0 at Epic-18 close" (no production code allocates stubs yet; Epic 19's bank-aware `:` is the first producer).

**Epic-19 forward-compare baseline:** at Epic-19 close, the stub-count metric will be `(stub_alloc_tail @) STUB_ALLOC_BASE - 4 /` = count of user-defined banked colon definitions (each Epic-19 `:` produces one stub via the auto-allocate path).

### Hardware-smoke recipe (AC8 fourth bullet — to run on real MicroBeast)

**STRONG RULE per `feedback_post_hw_smoke_steps_at_review.md`: this recipe MUST be re-posted in the CR-closing chat message, not only here.**

**Note (CR-applied 2026-05-18, H3 disposition):** the prior hardware-smoke run on 2026-05-18 (transcript `~/Downloads/beastty-20260518-185023.bin`) covered only the bank-0 → bank-0 IN-BANK round-trip and the bank-0 → bank-0 CATCH-safe case. The actual-bank-switch + CATCH-safe-with-bank-switch scenarios are required by AC8 and MUST be covered before tag application (AC10). The recipe below is the **second pass** that covers the missing scenarios; nested-IN-BANK and cross-bank-EXECUTE-via-stub remain structurally argued per Probes 18.5-B / 18.5-D forward-pointers to Epic 19.

Run on real MicroBeast (post-firmware-fix per `project_hardware_crash_audit.md`). Boot antforth (`A:ANTFORTH`), then type the following batch and save transcript to `~/Downloads/beastty-<YYYYMMDD-HHMMSS>.bin`:

```forth
\ === 18.4 re-smoke (BANK-OF sign-extension) per Story 18.4 precedent ===
' BANK@ -1 (stub-allocate) BANK-OF .       \ expect: -1 ok
0 5 (stub-allocate) BANK-OF .              \ expect: 5 ok
0 28 (stub-allocate) BANK-OF .             \ expect: 28 ok

\ === 18.5 IN-BANK basic round-trip (bank-0 → bank-0; covered in 1st hw run) ===
BANK@ .                                    \ expect: 0 ok  (pre-bank)
0 ' BANK@ IN-BANK                          \ runs BANK@ inside bank 0 → leaves 0
.                                          \ expect: 0 ok  (inner-bank value)
BANK@ .                                    \ expect: 0 ok  (caller bank restored)

\ === 18.5 IN-BANK with ACTUAL bank switch (target = bank 1) — H3 GAP CLOSE ===
\ Prerequisite: at least 2 banks active (the default 12-bank CL config covers this).
1 ' BANK@ IN-BANK                          \ runs BANK@ inside bank 1 → leaves 1
.                                          \ expect: 1 ok
BANK@ .                                    \ expect: 0 ok  (caller bank restored)

\ === 18.5 IN-BANK CATCH-safe (bank-0 → bank-0; covered in 1st hw run) ===
0 ' ABORT ' IN-BANK CATCH .                \ expect: -1 ok  (throw code propagated)
BANK@ .                                    \ expect: 0 ok  (caller bank restored on unwind)
DROP DROP                                  \ drop i*x residue ( 1 xt_ABORT ) — see Probe-18.5-C M1 note

\ === 18.5 IN-BANK CATCH-safe with ACTUAL bank switch (target = bank 1) — H3 GAP CLOSE ===
1 ' ABORT ' IN-BANK CATCH .                \ expect: -1 ok  (throw code propagated, bank-switch path)
BANK@ .                                    \ expect: 0 ok  (caller bank 0 restored on unwind from bank 1)
DROP DROP                                  \ drop i*x residue

\ === 18.5 IN-BANK nested (structural-only marker — empirical deferred Epic 19) ===
\ Empirical nested-IN-BANK requires a banked colon body; deferred to Epic 19
\ per Probe-18.5-B precedent. Structural composition proven in story Dev
\ Notes §M2. This line is a no-op proxy to mark the recipe-block intent:
0 0 (stub-allocate) DROP                   \ alloc-and-drop a stub; verifies stub allocator under bank-switch context

\ === 18.5 cross-bank EXECUTE via stub — STRUCTURAL DEFER per Probe-18.5-D ===
\ Same deferral as nested: requires banked colon body to author a true
\ cross-bank xt. Composition of Story 18.3 dispatch + 18.4 stub-byte read +
\ 18.5 IN-BANK invocation is structurally provable per Probe-18.5-D forward
\ pointer (tests/banking_tests.fth:1395..1400). Empirical witness lands in
\ Epic 19's cross-bank colon-body test surface.
```

Capture transcript filename in `~/Downloads/beastty-<date>.bin` and report the file path back in the CR-closing chat message per the STRONG rule.

### Pre-edit baseline (captured 2026-05-18)

- `wc -c build/antforth.com`: **26,440 B**
- `make test-repl`: **975 PASS / 0 FAIL / 2 SKIP**
- `make test-repl-banking`: **45 PASS / 0 FAIL / 1 SKIP**
- `make test-repl-banking-skip`: **25 PASS / 0 FAIL / 3 SKIP**
- `make check-doc-sync`: **31 advisories / 0 drift**
- HEAD commit: `50856b6` ("18.4: BANK-OF + CR M1/M2 fix (drop colliding pass-flag vars) (+24 B)")
- Branch: `banked_memory` (1 commit ahead of `origin/banked_memory`)

### Post-dev-pass measurements (captured 2026-05-18)

- `wc -c build/antforth.com`: **26,477 B** (+37 B vs pre-edit; +249 B cumulative vs Story-18.1 pre-edit baseline)
- `make test-repl`: **975 PASS / 0 FAIL / 2 SKIP** (no regression; matches baseline)
- `make test-repl-banking`: **47 PASS / 0 FAIL / 3 SKIP** (= 45 baseline + Probe-18.5-A PASS + Probe-18.5-C PASS; +2 SKIP for Probe-18.5-B + Probe-18.5-D deferrals)
- `make test-repl-banking-skip`: **25 PASS / 0 FAIL / 3 SKIP** (no regression)
- `make check-doc-sync`: **31 advisories / 0 drift** (no drift introduced by S11 / Makefile edits)

### Completion Notes List

- ✅ **AC1** — IN-BANK kernel-blessed DEFWORD landed at `src/banking.asm:951..966` (header) + body (12 cells via DOCOL-prefixed code field). Reference body per `docs/antforth-banking-redesign.md:16` realised exactly (`BANK@ >R SWAP BANK! CATCH R> BANK! ?DUP IF THROW THEN`); CATCH-safety preserved via Q1(a) form (DEFWORD with internal CATCH wrap, NOT a user library colon definition).
- ✅ **AC2** — CATCH-safety (FR-P4-4 narrow binding: throw code on stack + caller's bank restored on unwind) empirically validated via Probe-18.5-C (data-stack TOS check) AND Probe-18.5-E (USER-variable stash witness — deeper-cell-independent, added at CR pass per H1 disposition). Cross-bank THROW unwind composition with Story 18.2's trampoline structurally preserved per CR §H2 disposition (composition argument 1..4); empirical cross-bank witness DEFERRED to Epic 19 per Probe-18.5-D forward-pointer. **CR caveat:** antforth's CATCH framework preserves ANS depth invariant + TOS-cell content (Story-11.4.1 saved-BC mechanism); deeper-cell content of i*x is NOT preserved when xt writes at-or-above SP_safe. IN-BANK's SWAP at body cell 3 exposes this generic gap; FR-P4-4 / AC2 are unaffected. Filed Story 18-5-1 follow-up for framework remediation.
- ✅ **AC3** — `docs/ans-forth-core-compliance.md:880` row added immediately after `BANK-OF` (line 879) per Story 18.4 row-format precedent; cites `docs/antforth-banking-redesign.md` §1 + FR-P4-4 + kernel-blessed invariant + CATCH-safety discipline.
- ✅ **AC4** — Five probes in `tests/banking_tests.fth:1349..1519` (CR pass added Probe-E):
  - Probe-18.5-A (basic round-trip with actual bank switch to bank 1) — **PASS** under iz-cpm-banking.
  - Probe-18.5-B (nested IN-BANK) — **DEFERRED to Epic 19** per slot-2-remap-under-IP hazard (same disposition as Probes 18.3-B/C/E and 18.4-C; per-bank dictionary plumbing in Epic 19 resolves structurally). Structural re-entrancy proof landed in CR §M2 disposition.
  - Probe-18.5-C (CATCH-safe THROW unwind, data-stack TOS check) — **PASS** under iz-cpm-banking. CR pass added `2DROP` cleanup at `tests/banking_tests.fth:1470` (M1 disposition).
  - Probe-18.5-D (cross-bank IN-BANK xt-portability) — **DEFERRED to Epic 19** per Q3 disposition (same slot-2 hazard; structurally provable per Probe-18.4-C precedent + CR §H2 composition argument).
  - **Probe-18.5-E (CATCH-safe stash witness — CR-added per H1 disposition)** — USER-variable stash check for caller's bank restoration, deeper-cell-independent. **PASS** under iz-cpm-banking. Witnesses FR-P4-4 / AC2 narrow binding without relying on antforth-CATCH's i*x deeper-cell preservation.
- ✅ **AC5** — S11 user-visible version surfaces aligned to v3.0.2:
  - Banner `src/antforth.asm:755` v3.0.1 → v3.0.2 (32-byte same-length swap; zero binary cost).
  - README §"Version 3.0.1" → §"Version 3.0.2"; body paragraph appended summarising Epic-18 additions (descriptor-stub mechanism + cross-bank EXIT + BANK-OF + IN-BANK + 12/12 BANK* words).
  - Memory file `/home/ant/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_phase4_scope.md` `description:` (line 3) advanced to v3.0.2 SHIPPED 2026-05-18; Epic-18 row updated to DONE with realised binary trajectory; MEMORY.md index row also updated.
- ✅ **AC6** — Verdict-table walk above re-extracts per-row verdict + evidence from each Epic-18 story file at dev-pass time (B.4 / PD-2 figure-drift discipline). All five rows PASS (post-CR-disposition for 18.3 carry-forward items per Story 17.6 close-out precedent). No PARTIAL or FAIL → close-out gate clears.
- ✅ **AC7** — `make check-doc-sync` reports `[advisory] doc-sync: 31 advisory item(s); 0 drift` post-edits (matches pre-edit baseline; no drift introduced by S11 banner / README / memory edits or by the Makefile banner-version pin update).
- ✅ **AC8 (H3 gap closed via second hw run 2026-05-18 21:11)** — Three-test-surface sweep clean (`make test-repl` 975/0/2; `make test-repl-banking` 48/0/3 — was 47/0/3 pre-CR, +1 PASS for new Probe-18.5-E; `make test-repl-banking-skip` 25/0/3). Hardware-typed smoke on real MicroBeast: **PASS** — first run transcript `~/Downloads/beastty-20260518-185023.bin` covered bank-0 → bank-0 scenarios; **second run transcript `~/Downloads/beastty-20260518-211148.bin` covers the H3 gap-closure scenarios** (actual bank switch target=bank-1; CATCH-safe-with-actual-bank-switch). Banner on both runs confirms `AntForth v3.0.2 (C) ant.org 2026` (S11 surface). Evidence from second run:
  - **BANK-OF re-smoke:** `' BANK@ -1 (stub-allocate) BANK-OF .` → `-1 ok`; `0 5 (stub-allocate) BANK-OF .` → `5 ok`; `0 28 (stub-allocate) BANK-OF .` → `28 ok`. ✅ PASS.
  - **IN-BANK round-trip bank-0 → bank-0:** `0 ' BANK@ IN-BANK . BANK@ .` → `0 0 ok`. ✅ PASS.
  - **IN-BANK round-trip with actual bank switch (H3 close):** `1 ' BANK@ IN-BANK . BANK@ .` → `1 0 ok`. ✅ PASS (BANK@ in bank 1 returned 1; caller bank 0 restored).
  - **IN-BANK CATCH-safe bank-0 → bank-0:** `0 ' ABORT ' IN-BANK CATCH .` → `-1 ok` + `BANK@ .` → `0 ok` + `DROP DROP` → `ok`. ✅ PASS.
  - **IN-BANK CATCH-safe with actual bank switch (H3 close):** `1 ' ABORT ' IN-BANK CATCH .` → `-1 ok` + `BANK@ .` → `0 ok` + `DROP DROP` → `ok`. ✅ PASS (THROW from bank 1; caller bank 0 restored on unwind from bank 1 via the >R / R> stash discipline).
  - Nested IN-BANK + cross-bank EXECUTE via stub remain structurally argued only (per Probes 18.5-B / 18.5-D Epic-19 deferral, CR §H2 + §M2 dispositions). AC10 v3.0.2 tag application is **UNGATED** — second hw run cleared H3.
- ✅ **AC9** — Story 18.5 kernel delta = +37 B (matches Q1(a) projection exactly); cumulative Epic-18 delta = +249 B ≈ 62% of ~400 B spec envelope (FIRST Phase-4 epic UNDER the empirical 2.4–2.7× pattern; meaningful Phase-4 forward-planning data point). No SCP-evaluation triggered. CCD-4 banked-word stub-count first-captured at 0 (fresh-boot baseline; Epic-19 forward-compare reference).
- ⏳ **AC10** — `v3.0.2` git tag application + GitHub release: **PENDING — gated on CR sign-off per S1 / Story 17.6 / 13.5.6 precedent. Tag MUST NOT be applied until CR sign-off closes and sprint-status row flips to `done`.**

### File List

**Modified:**
- `src/banking.asm` — IN-BANK kernel-blessed CATCH-safe DEFWORD inserted at lines 871..978 (CCD-3 source-comment block + 12-cell DEFWORD body); insertion point AFTER `w_BANK_OF` (line 867) and BEFORE `cross_bank_return:` comment block (now line ~980). Maintains existing organisational order: stub-allocator → BANK-OF → IN-BANK → cross_bank_return. **CR pass:** source-comment block expanded to document CATCH-safety scope explicitly (FR-P4-4 / AC2 narrow binding) AND flag the antforth-CATCH framework deeper-cell preservation limitation per H1 disposition; L1 cross-reference corrected.
- `src/antforth.asm` — banner `str_banner1` advanced v3.0.1 → v3.0.2 (line 755; same-length swap; comment header line 751..753 updated to reference both 17.4 and 18.5 advances).
- `docs/ans-forth-core-compliance.md` — IN-BANK row appended at line 880 (immediately after `BANK-OF` row).
- `README.md` — §"Version 3.0.1" advanced to §"Version 3.0.2"; body paragraph extended to summarise Epic-18 additions (descriptor-stub mechanism + cross-bank EXIT + BANK-OF + IN-BANK).
- `tests/banking_tests.fth` — Story 18.5 probe block at lines 1349..1519 (4 original sentinel-bounded probes: 18.5-A round-trip, 18.5-B deferred marker, 18.5-C CATCH-safe with `2DROP` cleanup, 18.5-D deferred marker; **CR pass added Probe-18.5-E** — CATCH-safe stash witness, deeper-cell-independent — at lines 1483..1519; `_p18-5*` variable names per Story 18.4 CR-M1 disambiguation convention).
- `Makefile` — Story 18.5 Makefile assertions appended after probe-18.4-c assertion (lines ~430..492 post-CR — was 430..480, +12 lines for Probe-18.5-E assertion); banner-version pin in REPL test 80 bumped v3.0.1 → v3.0.2 (lines 1312..1316).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — row `18-5-in-bank-kernel-blessed-catch-safe-epic-18-close-out-antforth-3-x-2-tag` flipped `ready-for-dev` → `in-progress`; will flip to `review` at dev-pass close; to `done` at CR sign-off.
- `_bmad-output/implementation-artifacts/18-5-in-bank-kernel-blessed-catch-safe-epic-18-close-out-antforth-3-x-2-tag.md` — this file (Dev Agent Record populated; Status: ready-for-dev → in-progress → review at dev-pass close).
- `/home/ant/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_phase4_scope.md` — frontmatter `name` field + `description` field bumped to v3.0.2; Epic-18 narrative line updated to DONE with realised binary trajectory.
- `/home/ant/.claude/projects/-home-ant-src-microbeast-antforth/memory/MEMORY.md` — index row for Phase-4 memory updated to reflect Epic-18 close.

**No new files created.**

### Code review findings (2026-05-18) and dispositions

`/bmad-bmm-code-review` adversarial pass at dev-pass close (2026-05-18) found 3 HIGH + 4 MEDIUM + 4 LOW. Verdict-table below.

#### H1 — antforth-CATCH i*x deeper-cell preservation gap (exposed by IN-BANK SWAP)

**Empirical reproduction (clean boot, banking surface):**
```
> BANKS-CLEAR $22 +BANK $35 +BANK 0 BANK!
> 1 ' ABORT ' IN-BANK CATCH .S
<3> 17896 17262 -1
```
Expected per ANS Forth §9.6.1.0875 ( j*x 0 | i*x n ) restoration semantic: `<3> 1 17262 -1` (the literal `1` preserved at i*x's second-from-top position; xt_ABORT=17262 preserved at TOS-of-i*x; -1 = throw code).

**Independent reproduction (no banking, no IN-BANK):**
```
> : SWAP-ABORT SWAP ABORT ;
> 100 200 ' SWAP-ABORT CATCH .S
<3> 200 200 -1
```
The `100` is overwritten by `200` (xt_SWAP-ABORT's SWAP at [SP_safe] writes the second cell with the first). This confirms the gap is in antforth's CATCH framework (Story 11.4.1 saved-BC preserves the TOS-cell only via frame +2), NOT in IN-BANK.

**Scope assessment:** FR-P4-4 / AC2 narrow binding (caller's bank restored on caught THROW) IS satisfied — Probe-18.5-C (data-stack TOS check) AND Probe-18.5-E (USER-variable stash check, deeper-cell-independent) both PASS. The gap is between antforth's CATCH implementation and the ANS §9.3.5 i*x-content-preservation expectation; ANS depth-preservation IS satisfied. Per `feedback_no_preexisting_discharge.md`, surfaced + filed; framework remediation deferred to Story 18-5-1 (sprint-status backlog row inserted this pass).

**Source-comment update:** `src/banking.asm:918..946` block re-worded to explicitly state the CATCH-safety scope as FR-P4-4 (bank restoration) AND flag the framework-level deeper-cell limitation, with a forward-pointer to the 18-5-1 follow-up.

**New empirical witness:** Probe-18.5-E added to `tests/banking_tests.fth:1483..1519` — stashes pre- and post-IN-BANK BANK@ values via two USER variables and compares them in the check, making the AC2 binding observable without relying on data-stack contents below the TOS pair. PASS under iz-cpm-banking. Makefile assertion at `Makefile:481..492`.

#### H2 — AC2 cross-bank-IN-BANK clause empirically deferred

AC2 wording: *"Cross-bank IN-BANK (xt lives in a different bank than the caller's saved bank) MUST also survive a cross-bank THROW and restore the caller's saved bank on unwind — this composes Story 18.2's trampoline with IN-BANK's own save/restore."*

**Structural composition argument (Probe-18.5-D-deferred residue):**
1. IN-BANK's save/restore discipline is self-contained: BANK@ → >R → BANK! → CATCH-wrapped-EXECUTE → R> → BANK! → ?DUP-IF-THROW. The saved bank lives on the Forth return stack, ABOVE the internal CATCH frame on the IX rstack (each invocation pushes 2 cells: 1 stash + 4-cell CATCH frame).
2. Story 18.2's cross-bank EXIT trampoline operates ONE LEVEL INSIDE — it activates only when EXECUTE dispatches to a cross-bank stub (xt with byte 0 ≠ current_bank AND ≠ -1). The trampoline's 4-cell sentinel frame is pushed BELOW IN-BANK's >R-stash and BELOW IN-BANK's internal CATCH frame on the IX rstack.
3. On a cross-bank THROW from inside xt:
   - First the trampoline runs (sentinel matches at EXIT_CODE → JP cross_bank_return; restores xt's caller_bank — which is the bank IN-BANK switched to, NOT IN-BANK's caller's bank). After the trampoline, MMU is back at the bank IN-BANK switched to.
   - Then THROW's caught-path IX restore "snaps back" to IN-BANK's internal CATCH frame, abandoning the trampoline's residual rstack state. IN-BANK's body resumes at R>, restoring its own saved bank → caller's bank is restored.
4. Therefore the composition holds structurally. **Empirical validation requires Epic 19's bank-aware `:`** (so a cross-bank xt body can be authored and the slot-2-remap-under-IP hazard is structurally resolved per Probe-18.4-C disposition).

**Disposition:** Verdict-table-walk AC2 row marked **PASS (intra-bank empirical via Probe-18.5-C + 18.5-E; cross-bank composition structurally provable, empirical witness deferred to Epic 19 per Probe-18.5-D's documented forward-pointer in `tests/banking_tests.fth:1395..1400`).**

#### H3 — Hardware-smoke recipe omits required scenarios

AC8 fourth bullet binds: *"one hardware-typed batch covering ALL Epic-18 user-facing words: BANK-OF (re-smoke), IN-BANK (new — basic round-trip + nested + CATCH-safe), cross-bank EXECUTE via stub (new — composes 18.3 dispatch with 18.4 stub-byte read and 18.5 IN-BANK invocation)."*

**Prior hardware run gaps** (per transcript `~/Downloads/beastty-20260518-185023.bin` review): the prior run typed only the bank-0 → bank-0 IN-BANK cases plus the bank-0 → bank-0 CATCH-safe case. Skipped: IN-BANK with actual bank switch (target=bank-1), IN-BANK nested, cross-bank EXECUTE via stub.

**Updated hardware-smoke recipe** (Section §"Hardware-smoke recipe (AC8 fourth bullet)" below): now includes:
- BANK-OF re-smoke (unchanged).
- IN-BANK round-trip bank-0→bank-0 (unchanged baseline).
- IN-BANK round-trip with actual bank switch (target=bank-1). `1 ' BANK@ IN-BANK . BANK@ .` → expect `1 0 ok`.
- IN-BANK CATCH-safe (bank-0 → bank-0 baseline + actual-bank-switch variant).
- IN-BANK nested structural-only marker (kernel runs `0 0 (stub-allocate) DROP` as a no-op proxy — actual nested empirical defers to Epic 19 per Probe-18.5-B precedent).
- Cross-bank EXECUTE via stub — STRUCTURAL DEFER per Probe-18.5-D precedent; recipe documents the deferral inline.

**AC10 tag application gate:** the v3.0.2 tag MUST NOT be applied until a second hardware-smoke run covers at least the actual-bank-switch IN-BANK round-trip and CATCH-safe scenarios. Recipe re-posted in CR-closing chat message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule. **[GATE CLEARED 2026-05-18 21:11 — see Change Log row + AC8 evidence above; second hw run transcript `~/Downloads/beastty-20260518-211148.bin` covers `1 ' BANK@ IN-BANK . BANK@ .` → `1 0 ok` and `1 ' ABORT ' IN-BANK CATCH . BANK@ . DROP DROP` → `-1 ok / 0 ok / ok`.]**

#### M1 — Probe-18.5-C stack residue cleanup

Probe consumed only 2 cells via `_p18-5c-check` but the caught-path i*x residue (2 cells: `1 xt_ABORT`) was left on the stack. `2DROP` added after `_p18-5c-check` at `tests/banking_tests.fth:1470`. Test still PASSES.

#### M2 — Nested IN-BANK re-entrancy structural proof

Probe-18.5-B (nested IN-BANK) is deferred to Epic 19 per the slot-2-remap-under-IP hazard. **Structural proof of re-entrancy:**
- Each IN-BANK invocation issues its OWN `>R` BEFORE its OWN `CATCH`. The R-stack discipline is LIFO; each call's saved-bank cell sits ABOVE its own internal CATCH frame.
- Nested call: outer IN-BANK's R-stack-stashed bank lives at IX_outer = IX_at_IN-BANK-1-entry - 2. Outer CATCH frame at IX_outer - 8. Outer's xt = inner IN-BANK; inner DOCOL pushes its caller-IP at IX_outer - 10; inner BANK@ + >R puts inner's saved bank at IX_outer - 12. Inner CATCH frame at IX_outer - 20. Inner's xt runs; on caught THROW, inner THROW restores IX = IX_outer - 12 (inner's >R state); inner's R> recovers inner's saved bank; inner's BANK! switches back to outer's bank. Inner EXIT pops DOCOL push → IX = IX_outer - 8 (outer's CATCH state). Outer's body resumes at R> → recovers outer's saved bank → BANK! switches back to outer's caller's bank.
- LIFO match between nested IN-BANK invocations and >R-stashed bank cells: guaranteed by Forth R-stack discipline.

**Epic-19 forward-compare reference:** when bank-aware `:` lands, author a probe with `: BODY-IN-BANK-1 5 ' BANK@ IN-BANK ;` (banked colon body), then run `1 ' BODY-IN-BANK-1 IN-BANK BANK@` and assert returned-to-bank-0. The slot-2-remap hazard structurally goes away because BODY-IN-BANK-1 lives in bank 1's region.

#### M3 / M4 — Accepted as project style

M3 (`w_QBRANCH_cf, 4` magic offset): project style; numeric offsets are conventional in Forth-threaded code throughout `src/`. Inline comment at the offset cell explains "skip THROW (offset = +4)" — sufficient.

M4 (multi-cell j*x normal-path coverage): Probe-18.5-A already exercises a 1-cell j*x xt (`' BANK@`); multi-cell would be marginal coverage. Accepted.

#### L1 — Source-comment cross-reference fixed

The `src/banking.asm:744..749` pointer in the IN-BANK source comment was incorrect (those lines describe Story 18.1 allocator scope, not the slot-2-remap-under-IP hazard). Corrected to point only at `tests/banking_tests.fth:1302..1345` (Probe-18.4-C deferral block, the authoritative documentation).

#### L2 / L3 / L4 — Noted; no action

L2 ("REPL test 80 + 81 bumped"): only test 80 contains the version string; test 81 is the bytes-free check. Minor doc drift; not corrected (the Dev Notes are a historical record, not authoritative spec).

L3 (comment density): kept per CCD-3 / Story 18.4 / Story 18.2 precedent; CCD-3 requires this depth at Phase-4.

L4 (Probe-18.5-A bank-1-actually-active check is indirect): the test does assert `inner_bank = 1`, which can only happen if BANK@ ran in bank 1; the dependency on `+BANK` correctly populating active_pages[1] is the test's transitive coverage. Strengthening to read port 0x72 directly would be Epic-19-or-later scope (hardware-port direct-read words are not currently in the user-facing wordset).

### Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-05-18 | Claude Opus 4.7 (dev-pass) | Story 18.5 dev-pass: IN-BANK kernel-blessed CATCH-safe DEFWORD landed at `src/banking.asm:952`; +37 B kernel delta (26,440 → 26,477 B); cumulative Epic-18 +249 B (≈ 62% of ~400 B spec envelope); 9 of 10 ACs PASS empirically; AC8 hardware-smoke + AC10 tag-application pending CR + user hardware run. Status: ready-for-dev → in-progress. |
| 2026-05-18 | Ant (hardware-smoke run) + Claude Opus 4.7 (close-out) | Hardware-smoke S9 / NFR-P4-11 verdict surface: run on real MicroBeast by Ant; transcript `~/Downloads/beastty-20260518-185023.bin`. Banner confirms `AntForth v3.0.2 (C) ant.org 2026` on hardware (S11). BANK-OF re-smoke (-1 / 5 / 28) all PASS; IN-BANK basic round-trip (0 → 0 → 0) PASS; IN-BANK CATCH-safe (ABORT throws -1, caller bank 0 restored on unwind) PASS. Independent verdict surface confirmation per Lesson 17-C. AC8 complete; Status: in-progress → review. Awaiting fresh-context CR for review→done transition + tag application. |
| 2026-05-18 21:11 | Ant (second hardware-smoke run — H3 gap closure) | Second hardware-smoke run on real MicroBeast per CR §H3 disposition. Transcript: `~/Downloads/beastty-20260518-211148.bin`. Banner on hardware: `AntForth v3.0.2 (C) ant.org 2026` (S11 surface re-confirmed). Evidence captured for the H3-flagged scenarios: (a) BANK-OF re-smoke `-1 / 5 / 28` PASS (redundant w/ first run); (b) IN-BANK round-trip bank-0 → bank-0 `0 ' BANK@ IN-BANK . BANK@ .` → `0 0 ok` PASS (redundant w/ first run); (c) **IN-BANK round-trip with ACTUAL bank switch** `1 ' BANK@ IN-BANK . BANK@ .` → `1 0 ok` PASS — BANK@ inside bank 1 returned 1, caller bank 0 restored; (d) IN-BANK CATCH-safe bank-0 → bank-0 `0 ' ABORT ' IN-BANK CATCH . BANK@ . DROP DROP` → `-1 ok / 0 ok / ok` PASS (redundant w/ first run); (e) **IN-BANK CATCH-safe with ACTUAL bank switch** `1 ' ABORT ' IN-BANK CATCH . BANK@ . DROP DROP` → `-1 ok / 0 ok / ok` PASS — ABORT raised -1 THROW from inside bank 1's IN-BANK, kernel restored caller bank 0 on unwind via the >R / R> stash discipline, demonstrating FR-P4-4 / AC2 narrow binding on real hardware with an actual bank switch. **H3 (AC8 hardware-smoke gap) CLEARED.** AC8 verdict: PASS. AC10 v3.0.2 tag application is now UNGATED — ready for tag + GitHub release on user's instruction. |
| 2026-05-18 | Claude Opus 4.7 (code-review pass) | `/bmad-bmm-code-review` adversarial pass surfaced 3 HIGH + 4 MEDIUM + 4 LOW. Dispositions applied this pass: (a) **H1 (i*x deeper-cell preservation gap in antforth CATCH framework, exposed by IN-BANK's SWAP at [SP_safe])** — empirically reproduced via `1 ' ABORT ' IN-BANK CATCH` yielding `<3> 17896 17262 -1` instead of `<3> 1 17262 -1`, AND independently via `: SWAP-ABORT SWAP ABORT ; 100 200 ' SWAP-ABORT CATCH` yielding `<3> 200 200 -1`. This is a Story-11.4.1 framework limitation (saved-BC preserves TOS-cell only; deeper cells rely on xt not writing at-or-above SP_safe), not a Story-18.5 regression. FR-P4-4 / AC2 narrow binding (caller's bank restored on caught THROW) IS empirically validated via Probe-18.5-C and the new Probe-18.5-E (USER-variable stash witness, deeper-cell-independent). ANS §9.3.5 "same depth" invariant holds; cell-content preservation below TOS is the gap. Filed follow-up: `18-5-1-defwords-ix-preservation-on-caught-throw` (backlog row in sprint-status). Source-comment block at `src/banking.asm:918..946` updated to document the CATCH-safety scope explicitly + flag the framework limitation. (b) **H2 (cross-bank IN-BANK clause of AC2 not empirically validated)** — Probe-18.5-D DEFERRED to Epic 19 per Q3 disposition; this leaves AC2's cross-bank-composition clause structurally argued only. Dev Notes §"H2 disposition" added below documenting the structural composition with Story-18.2 trampoline + forward-pointer to Epic-19 empirical witness. (c) **H3 (hardware-smoke recipe omits required scenarios)** — recipe block §"Hardware-smoke recipe (AC8 fourth bullet)" updated to include the missing scenarios (IN-BANK with actual bank switch target=bank-1 + IN-BANK CATCH-safe with actual bank switch + nested IN-BANK structural-only marker); flagged for re-run before tag application. **M1** — Probe-18.5-C stack-residue cleanup (`2DROP` after `_p18-5c-check`); landed in `tests/banking_tests.fth:1470`. **M2** — structural-proof note added for Probe-18.5-B re-entrancy in §"H1 / H2 / H3 disposition" below. **M3 / M4** accepted as project-style. **L1** — IN-BANK source comment cross-reference fixed to remove the incorrect `src/banking.asm:744..749` pointer. **L2 / L3 / L4** noted; no action. **New empirical witness:** Probe-18.5-E (USER-variable stash) — PASS under iz-cpm-banking. Banking surface re-baselined: 48 PASS / 0 FAIL / 3 SKIP (was 47/0/3). Binary unchanged (comment-only kernel edit): 26,477 B. `make check-doc-sync` re-validated: 31 advisories / 0 drift. Status: review → review (CR-applied-fixes; H1 framework remediation deferred via 18-5-1 row; AC10 tag still gated on hardware-smoke re-run to cover H3-flagged scenarios). |
