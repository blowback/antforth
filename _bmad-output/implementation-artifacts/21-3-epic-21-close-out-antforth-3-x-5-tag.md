# Story 21.3: Epic 21 close-out + antforth 3.0.6 tag

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-12 by create-story workflow on the Story 21.3 turn.
     Story 21.3 is the Epic 21 close-out gate: it ships the verified
     bank-aware LIFECYCLE surface (Story 21.1 MARKER/FORGET per-bank +
     stub-allocator-tail reclamation; Story 21.2 saved-bank cell +
     interactive-BANK! recogniser + QUIT/ABORT bank-state restore) as the
     next antforth tag. Close-out is a ~0-byte-kernel gate (version-surface
     alignment + integration probe + verdict-table walk + CCD-4 stub-count
     metric + envelope reconciliation + tag).

     TWO load-bearing drift findings were discovered at DRAFT TIME and
     folded into the ACs (B.4 / PD-2 figure-drift discipline — the
     epics-file Story 21.3 §"3.x.5" text is stale). Do NOT re-discover
     them at dev-pass:

       (1) VERSION = v3.0.6, NOT v3.0.5. The epics-file placeholder
           "antforth 3.x.5 tag" is STALE — it is the SAME off-by-one drift
           Story 20.3 caught and annotated. `git tag v3.0.5` ALREADY EXISTS
           (Epic 20 close-out, commit 0fb4434); the banner
           (`src/antforth.asm:781`) + README (`:14`) + Makefile test-80
           assertion (`:1781`) ALL already read `v3.0.5`. The 19.5 + MBB
           interlude consumed v3.0.4, shifting every downstream point
           release +1 vs the epics-file "3.x.N" slug. Story 20.3's
           Completion Notes explicitly recorded the shift: "Epic 21 →
           v3.0.6 / Epic 22 → v3.0.7". Epic 21 therefore ships **v3.0.6**.
           Owned by Q1.

       (2) ENVELOPE (AC7). Epic-21 cumulative is ~**+181–191 B**
           (21.1 +82 B, 21.2 +109 B self-reported = +191; a clean
           start→close rebuild nets ~+181 after backing out a 10 B
           inter-story measurement drift). This is ~1.2–1.27× OVER the
           ~150 B Epic-21 Decision-Impact-Analysis envelope — a NORMAL-
           calibration overshoot, well inside the empirical ~2.4× Phase-4
           multiplier (`project_epic17_envelope`), and a PURE-ADDITION arm
           (no design substitution → the multiplier-void rule does NOT
           apply, unlike Epic 20's +680 B / 3.4× fat-pointer migration).
           AC7 records the disposition; Q2 selects SCP-file vs Dev-Notes-
           only (the lighter disposition is defensible here — see AC7).

     One further re-spec note (the epics-file Story 21.3 AC5 integration
     probe predates the 21.1/21.2 dev-pass findings):

       (3) AC5 INTEGRATION PROBE must run in an ISOLATED fixture
           (`tests/banking_tests_21_3.fth`), not the main suite — the main
           suite's dictionary straddles `$8000` and any token lookup while
           a non-zero bank is mapped walks a bucket chain through the
           portal window (`feedback_phase4_probe_bank_switch_limitation`,
           ADR 19.5 DR-1). AND: the `MARKER ZZZ` in the epic's probe is
           created in bank 0 → it is invocable ONLY from its home bank 0
           (`project_banked_marker_no_stub`: a banked MARKER has no real
           dispatch stub; cross-bank invoke HANGS), so the FORGET must be
           `0 BANK! ZZZ`. The cross-bank `W5` call (`7 BANK! W5`, W5 in
           bank 5) is fine — a regular `:` word gets a descriptor stub
           (Epic 19.2) and dispatches cross-bank. See AC5 + Dev Notes. -->

## Story

As Ant (the project lead applying the Epic 21 close-out tag),
I want the user-visible version surface aligned to `3.0.6` (banner / README / Makefile-test-80 assertion / memory `description`), the full test surface clean across iz-cpm + the banking-capable emulator + the isolated fixtures + real MicroBeast, the banked-word stub-count metric captured per CCD-4 with the MARKER/FORGET allocator-tail-reclamation note and the trend vs the Story 20.3 baseline, the Epic-21 envelope overage reconciled per NFR-P4-5, the verdict-table walk recorded, and the `v3.0.6` tag applied,
so that Epic 21's bank-aware lifecycle surface (`MARKER`/`FORGET` snapshot + revert per-bank dictionary tails AND the stub-allocator tail; `QUIT` re-asserts the saved current bank on `ABORT`/THROW unwind; `INCLUDE`d files' `BANK!` calls do NOT pollute the saved-bank cell — F6 closed) ships as antforth 3.0.6 with an honest, reconciled close-out.

## Acceptance Criteria

> Close-out + integration verification of Epic 21's verified bank-aware lifecycle mechanism. The epics-file Story 21.3 §"3.x.5" placeholder is re-specced here against repo reality: the tag is **v3.0.6** (v3.0.5 is taken by Epic 20 — the same off-by-one drift 20.3 caught), the envelope is reconciled (~1.2–1.27× over, normal-calibration / pure-addition), and the AC5 integration probe is constrained to an isolated fixture with the banked-MARKER home-bank-invoke rule. FRs: none directly (close-out). NFRs codified: NFR-P4-4 (stub-count metric); NFR-P4-5 (envelope reconciliation); NFR-P4-11 / NFR-P4-36 (S9 hardware smoke); NFR-P4-21 (epic decoupling — 3.0.6 ships); NFR-P4-38 (S11 version surface); NFR-P4-39 (S12).

**Given** Stories 21.1 (`MARKER`/`FORGET` per-bank dictionary tail + descriptor-stub allocator-tail reclamation) + 21.2 (saved-bank cell + interactive-`BANK!` recogniser + `QUIT`/`ABORT` bank-state restore) have shipped and are `done`; current binary **28069 B** at HEAD `44177ca` (21.2 close); `git tag v3.0.5` already applied to the Epic-20 close commit `0fb4434`,
**When** Story 21.3 is dev-passed,

**Then** **AC1** (S11 / NFR-P4-38 user-visible version surface audit → **v3.0.6**) — the version surface advances `3.0.5` → `3.0.6`:
- `src/antforth.asm:781` `str_banner1` reads `"AntForth v3.0.6 (C) ant.org 2026"` (currently `v3.0.5`); this is a same-length string edit → **0 B kernel delta** (verify by clean rebuild + `strings build/antforth.com`).
- `README.md:14` `## Version 3.0.6` (currently `3.0.5`); the `V3.0.6 supports the following ANS Forth standard words` line (currently `V3.0.5`, ~`:43`); the version-history prose gains a `3.0.6` sentence describing the bank-aware **lifecycle** surface (MARKER/FORGET snapshot + revert per-bank dictionary tails AND the stub-allocator tail; QUIT/ABORT re-assert the saved interactive bank; INCLUDEd `BANK!` does not pollute the saved-bank cell — F6 closed). Re-validate line numbers at dev-pass start (README grew since 20.3; `:39` may now differ).
- **`Makefile:1781-1784` REPL test 80 banner assertion** `grep -q 'AntForth v3.0.5'` → `v3.0.6` (test-infra; 0 B). This is the "uncited fourth version surface" class B.4 caught at the Story 19.4/20.3 dev-passes — it IS enumerated here; do not let the post-edit `make test-repl` fail on it.
- The Phase-4-scope memory entry's `description` field (`project_phase4_scope.md`) advances to note `antforth 3.0.6 SHIPPED` (Epic 21 close); the stale "v3.0.5 tag DEFERRED" line is reconciled (v3.0.5 IS tagged on `0fb4434`).
- Re-validate every cited file:line at dev-pass start per B.4 / PD-2 figure-drift discipline (line numbers shift; re-`grep` the banner / README / Makefile assertion before editing). Run `grep -rE 'v?3\.0\.5'` to confirm these are the ONLY surfaces.

**And** **AC2** (verdict-table walk per Story-13.5.6 precedent) — Story 21.3 Dev Notes include a verdict-table walk for all Epic-21 stories with one-line evidence each (re-validate the HW-transcript filenames + sizes at dev-pass — do NOT transcribe blindly per PD-2):
- 21.1 — `MARKER`/`FORGET` per-bank tail + stub-allocator-tail reclamation — **PASS (done)**; +82 B; isolated-21-1 probes `result=-1` (forget-across-banks / stub reclamation / cross-bank-MARKER-survival); HW smoke PASS (commit `b9da7b2`/`8a3c8e2`).
- 21.2 — saved-bank cell + interactive-`BANK!` recogniser + QUIT/ABORT restore (incl. `source_id==0` CR-fix) — **PASS (done)**; +109 B; isolated-21-2 probes a/b/c/d/suite PASS; HW UAT PASS (`beastty-20260612-133209.bin`, EVALUATE-leak gate on silicon).
- 21.3 — close-out + v3.0.6 tag — **PASS**; ~0 B kernel (banner same-length + docs/test-infra + AC5 integration fixture).

**And** **AC3** (banked-word stub-count metric per CCD-4 + F2 mitigation) — Story 21.3 Dev Notes capture: total banked-word descriptor-stub count after Epic 21 (`(stub_alloc_tail − STUB_ALLOC_BASE) / 4`); per-stub stride; descriptor-stub fixed-memory occupancy; assert against NFR-P4-4 (per-stub ≤ 5 B; 1000-banked-words target ≤ 5 KB total); **trend vs the Story 20.3 baseline** (0 stubs pre-allocated at boot; 4 B/stub; `STUB_ALLOC_BASE = $D4CB`; region `$D4CB..$DBFF` = 1845 B = 461-stub cap → 0/461 at boot). **Specifically note** that the MARKER/FORGET cycle test exercised allocator-tail reclamation (Story 21.1 AC6 (b) — the stub xt of a bank-N word defined after FORGET equals the pre-MARKER allocator tail, i.e. count drops back to pre-MARKER level), so Epic 21 is a stub-*lifecycle* change (reclamation), not a stub-*count*-at-boot change → expected boot trend **unchanged vs 20.3 (0/461)**; confirm empirically, do not assume.

**And** **AC4** (`make check-doc-sync` clean-pass per B.5) — `make check-doc-sync` reports no NEW drift beyond the established advisory baseline (~31 advisory items at 20.3; re-capture the count at dev-pass — it is informational, the gate is *zero new drift*).

**And** **AC5** (integration probe — the Epic-21 lifecycle story in one breath; isolated fixture) — a single probe in a **new isolated fixture** `tests/banking_tests_21_3.fth` (sentinel-delimited `result=-1` verdicts mirroring `tests/banking_tests_21_2.fth` / `_21_1.fth`) exercises the full Epic-21 surface end-to-end. Re-specced from the epics-file `MARKER ZZZ 5 BANK! : W5 ; 7 BANK! : W7 ; 7 BANK! W5 ABORT` to be sound on real hardware:
- `MARKER ZZZ` while in **bank 0** (so ZZZ's home bank is 0 — it is invocable only from bank 0, per `project_banked_marker_no_stub`);
- `5 BANK! : W5 ;` `7 BANK! : W7 ;` (throwaway words defined across two banks; the interactive `5 BANK!` / `7 BANK!` update `saved_bank`);
- `7 BANK! W5` — a **cross-bank call** to `W5` (resident in bank 5) from bank 7, dispatched via W5's descriptor stub (Epic 19.2 — this works; W5 is a `:` word, not a MARKER); then `ABORT`;
- **REPL recovery**: after the `-1` ABORT in bank 7, `QUIT` re-asserts `saved_bank` (= 7, the last interactive `BANK!`), so `BANK@ .` returns **7** (the user's last interactive bank — never stranded mid-execution);
- `0 BANK! ZZZ` — FORGET from ZZZ's **home bank 0**; this restores every active bank's `(here, latest, wordlist-heads)` triple AND reclaims the descriptor-stub allocator tail; `' W5` and `' W7` now raise undefined-word (`-13`); a subsequent bank-N definition allocates its stub from the reclaimed allocator-tail region (count back to pre-MARKER level);
- caller's current bank (`BANK@`) and slot-2 page (`MBB-GET-2`) are restored cleanly; subsequent definitions resume.
- An inline comment in the fixture states this is the Epic-21 close-out north-star: the bank-aware lifecycle is observable end-to-end — MARKER/FORGET reverts per-bank tails + reclaims stubs; QUIT/ABORT never strands the user in the wrong bank. Lines ≤ TIB_SIZE 128 (`feedback_tib_size_inline_comments`); 0x1A-terminated (`feedback_cpm_0x1a_eof_marker`); observe `saved_bank` indirectly via `BANK@` post-recovery (no Forth word exposes `saved_bank`) and FORGET via `' name` + content-grep of the `<name> ?` line (NOT explicit `FIND`, which still resolves a forgotten word — `project_banked_marker_no_stub`).

**And** **AC6** (full test surface sweep — re-validate at dev-pass start per B.3) — all baselines preserved against the v3.0.6 build:
- `make test-repl` ≥ **974 PASS / 0 FAIL** on iz-cpm (21.1/21.2 measured **975/0**; the `XYZZY ?` undefined-word assertion holds; REPL test 80 banner assertion now `v3.0.6`);
- `make test-repl-banking` ≥ **61 PASS / 0 FAIL**;
- isolated targets unchanged-cohort (re-validate counts at dev-pass — they drifted 6↔7 between 20.3 and 21.2): `test-repl-banking-isolated-20-1`, `-20-2`, `-20-3`, `-19-3`, `-19-4`, `-19-5-1`, `-21-1`, `-21-2` all PASS / 0 FAIL; new `test-repl-banking-isolated-21-3` ≥ **1 PASS** (the AC5 integration probe);
- `make test-straddle-regression` = **3 / 3**; `make test-file-sanity` = **0 errors** (new `disk/a/P213*.FTH` HW copy `0x1A`-terminated).
- **Hardware smoke:** one full hardware-typed smoke batch covering Epic 21's lifecycle surface (the AC5 integration probe) PASSes on real MicroBeast per S9 / NFR-P4-11; the HW-smoke recipe is posted IN THE CLOSING CHAT MESSAGE per `feedback_post_hw_smoke_steps_at_review` (STRONG), not just here.

**And** **AC7** (Epic-21 envelope reconciliation per NFR-P4-5) — the verified Epic-21 cumulative binary delta is ~**+181–191 B** (re-derive by clean `make clean && make` worktree rebuilds at dev-pass start per B.3: baseline-before-Epic-21 = `0fb4434` (`b9da7b2^`, the Epic-20 close / v3.0.5 commit) — 21.1 measured this at **27888 B** (NB: the Epic-20 retro reported 27625 B at the v3.0.5 HEAD — a **263 B discrepancy**, so re-`wc -c` from a clean rebuild, do NOT inherit either number); HEAD-at-close clean rebuild ≈ **28069 B**; cumulative ≈ **+181 B** by start→close subtraction, or **+191 B** by summing the self-reported per-story deltas (21.1 +82 + 21.2 +109) — the ~10 B gap is a known inter-story measurement drift, reconcile in Dev Notes). This is ~**1.2–1.27× OVER the ~150 B Epic-21 Decision-Impact-Analysis envelope** → AC7 records a disposition (NOT a clean ≤150 B pass):
- The overage is a **normal-calibration overshoot** (+31–41 B), well inside the empirical ~2.4× Phase-4 binary-delta multiplier (`project_epic17_envelope`); the ~150 B figure is the redesign-§7 spec target, not an empirical ceiling.
- Epic 21 is a **pure-addition** arm (MARKER/FORGET snapshot+restore wiring + interactive-recogniser + QUIT re-assert), **NOT a design substitution** → the Epic-20 "multiplier-void on substitution" carve-out does NOT apply; normal calibration governs, and +191 B sits comfortably under the ~150 × 2.4 ≈ 360 B empirical envelope.
- **NFR-P4-5's 8 KB Phase-4 fixed-memory cap is unaffected** — the +191 B is code/links; the descriptor-stub fixed-memory region is still 0/461 at boot (AC3). Confirm the cumulative Phase-4 fixed-memory budget against the 8 KB cap in Dev Notes.
- **Disposition granularity is Q2** (dev-pass): (a) accept-with-rationale logged in **Dev Notes only** — defensible here because the overage is small, normal-calibration, and a pure addition (lighter than Story 20.3's dedicated SCP, which was forced by a 3.4× design-substitution breach); or (b) a dedicated `sprint-change-proposal-2026-06-NN.md` record mirroring 20.3. Resolve via AskUserQuestion at dev-pass start; the recommended option is (a).

**And** **AC8** (tag applied) — `git tag v3.0.6` is applied to the close-out commit; tag pushed to GitHub release. Commit + tag + push are outward-facing — execute ONLY on explicit user authorization at close-out (per the Story 19.4/20.3 precedent: the recipe is provided, the push is deferred to user go-ahead). Confirm `git tag` shows a contiguous `v3.0.1..v3.0.5` already present (it does — no gap to reconcile); next tag = **v3.0.6**.

**FRs covered:** none directly (close-out + integration verification of Epic 21's verified bank-aware lifecycle mechanism). **NFRs codified:** NFR-P4-4 (stub-count metric); NFR-P4-5 (envelope reconciliation); NFR-P4-11 / NFR-P4-36 (S9 hardware smoke); NFR-P4-21 (epic decoupling — antforth 3.0.6 ships); NFR-P4-38 (S11 version surface); NFR-P4-39 (S12).

> **Adversarial review (`CR`) is NOT an acceptance criterion** and is not a dev-pass task — it runs separately via the `CR` command in fresh context after dev-pass close (PD-1, Story 13.5.0). Do not add a "trigger adversarial review" AC.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: clean `make clean && make && wc -c build/antforth.com` of HEAD `44177ca` (21.2 close) → expect ~**28069 B**. **Do NOT inherit any number from this story text, the 21.1/21.2 stories, or the Epic-20 retro** (B.3 / B.4 / Lesson 13.5-F) — the only trustworthy baseline is a fresh clean-`make` at your dev-pass start.
- [x] Capture baseline-before-Epic-21: clean worktree build of `0fb4434` (`b9da7b2^`, v3.0.5 close) → expect ~**27888 B** (21.1's measurement; the Epic-20 retro's 27625 B disagrees by 263 B — re-derive, do not trust either). Epic-21 cumulative = HEAD − baseline ≈ **+181 B** (AC7); reconcile against the +191 B per-story sum.
- [x] Capture `make test-repl` (expect **975 / 0**), `make test-repl-banking` (expect **61 / 0**), all isolated targets (`-19-3 -19-4 -19-5-1 -20-1 -20-2 -20-3 -21-1 -21-2`; re-validate exact counts — 20-1 drifted 6↔7 between 20.3 and 21.2), `make test-straddle-regression` (**3/3**), `make test-file-sanity` (**0 errors**), `make check-doc-sync` (**0 drift**, ~31 advisory). Record all in Dev Notes.
- [x] Re-validate AC1 version-surface citations against source-of-truth (per B.4): banner `src/antforth.asm:781` = `v3.0.5` ✓; README `## Version 3.0.5` `:14`, `V3.0.5 supports` (~`:43`), version-history prose; **Makefile REPL test 80 `:1781-1784` `grep -q 'AntForth v3.0.5'`** (fourth surface). Run `grep -rE 'v?3\.0\.5'` to confirm these are the ONLY surfaces.
- [x] Confirm `git tag` state: `v3.0.1..v3.0.5` all present and contiguous; `v3.0.5` tags `0fb4434` (Epic 20 close). No tag-gap to reconcile. Next tag = **v3.0.6** (AC8).

### Q-dispositions (resolve at dev-pass start via AskUserQuestion BEFORE any edit)

- [x] **Q1 — close-out version number.** Recommend **v3.0.6** (the epics-file "3.x.5" placeholder is stale; `git tag v3.0.5` already exists from Epic 20; banner/README/Makefile already read v3.0.5; the 19.5+MBB interlude consumed v3.0.4, shifting all downstream +1 — Story 20.3 already annotated "Epic 21 → v3.0.6"). Essentially forced by repo reality; confirm with the project lead, then proceed.
- [x] **Q2 — envelope-reconciliation disposition granularity (AC7).** Recommend **(a) accept-with-rationale in Dev Notes only** (no dedicated SCP file): the overage is ~+31–41 B / ~1.2–1.27× of the spec target — a normal-calibration pure-addition overshoot well within the empirical ~2.4× Phase-4 multiplier, materially lighter than Story 20.3's 3.4× design-substitution breach that warranted a dedicated SCP. Option (b) = dedicated `sprint-change-proposal-2026-06-NN.md` mirroring 20.3.

### Story tasks

- [x] **Task 1 — Version-surface alignment to 3.0.6** (AC: #1)
  - [x] Sub-1.1 `src/antforth.asm:781` banner `v3.0.5` → `v3.0.6` (same-length; verify **0 B kernel delta** by clean rebuild — size unchanged from baseline; `strings build/antforth.com` shows `AntForth v3.0.6`).
  - [x] Sub-1.2 `README.md` version refs → 3.0.6 (heading `:14`; `V3.0.6 supports` line; version-history prose — add a 3.0.6 sentence for the bank-aware lifecycle surface: MARKER/FORGET per-bank + stub-tail reclamation, QUIT/ABORT saved-bank restore, F6 INCLUDE-no-pollution closed). Re-validate line numbers first (README grew since 20.3). Historical 3.0.x prose intact.
  - [x] Sub-1.3 `Makefile:1781-1784` REPL test 80 banner assertion `v3.0.5` → `v3.0.6` (test-infra; 0 B). test-80 must PASS on `AntForth v3.0.6` post-edit.
  - [x] Sub-1.4 `project_phase4_scope.md` memory `description` + Epic-21 line updated (Epic-21 close-out / 3.0.6 SHIPPED; reconcile the stale "v3.0.5 tag DEFERRED" — v3.0.5 IS tagged on `0fb4434`; downstream Epic 22 → v3.0.7). Per the memory-discipline rule, update the existing entry, do not duplicate.

- [x] **Task 2 — Verdict-table walk** (AC: #2)
  - [x] Sub-2.1 3-row Epic-21 verdict table in Dev Notes (21.1 / 21.2 / 21.3) with one-line evidence + HW-transcript references **re-validated at dev-pass** (PD-2 — do not transcribe the filenames/sizes blindly). No `review → done` reconciliation needed (21.1/21.2 already `done`).

- [x] **Task 3 — CCD-4 banked-word stub-count metric** (AC: #3)
  - [x] Sub-3.1 Capture empirically (fresh boot, not assumed): first bank-N>0 stub xt (= `STUB_ALLOC_BASE $D4CB` → boot tail == base → **0 stubs at boot**); second xt → **4 B stride**; region `$D4CB..$DBFF` = 1845 B = **461-stub cap** → **0/461 at boot — unchanged vs 20.3**. NFR-P4-4: 4 B ≤ 5 B ✓; 1000-word target 4000 B ≤ 5 KB ✓.
  - [x] Sub-3.2 Note the MARKER/FORGET allocator-tail reclamation (Story 21.1 AC6 (b)): after a `MARKER … <define banked word> … FORGET` cycle, a fresh banked-word stub xt equals the pre-MARKER tail (region reclaimed + reused, not leaked). Epic 21 is a stub-*lifecycle* change, not a boot-count change.

- [x] **Task 4 — AC5 integration probe** (AC: #5)
  - [x] Sub-4.1 New isolated fixture `tests/banking_tests_21_3.fth` + Makefile target `test-repl-banking-isolated-21-3` + `.PHONY` entry (mirror `:998` `-21-2`). Re-specced probe: `MARKER ZZZ` (bank 0) → 5/7-bank throwaway defs → `7 BANK! W5` cross-bank call → `ABORT` → recover with `BANK@ .` = **7** (last interactive bank) → `0 BANK! ZZZ` FORGET from home bank → `' W5`/`' W7` undefined + stub reclaimed → bank/slot-2 restored. Sentinel-bounded `result=-1`; lines ≤ TIB_SIZE 128; 0x1A-terminated. Observe `saved_bank` indirectly via `BANK@`; FORGET verdict via `' name` content-grep (NOT explicit `FIND`).
  - [x] Sub-4.2 `disk/a/P213*.FTH` CP/M 8.3 HW copy, `0x1A`-terminated, HW-ordered (mirror `P212*`/`P203INTG.FTH`). file-sanity 0 errors.

- [x] **Task 5 — Full test surface sweep** (AC: #6)
  - [x] Sub-5.1 All targets green against the v3.0.6 build: test-repl 975/0 (test-80 now v3.0.6) · test-repl-banking 61/0 · all isolated targets (incl. new 21-3) · straddle 3/3 · file-sanity 0 · check-doc-sync 0 drift. Record the exact per-target counts in Dev Notes.

- [x] **Task 6 — Epic-21 envelope reconciliation** (AC: #7)
  - [x] Sub-6.1 Re-derive cumulative delta by clean worktree rebuilds (`0fb4434` baseline vs HEAD). Reconcile the +181 B (start→close) vs +191 B (per-story sum) figures.
  - [x] Sub-6.2 Per Q2, either log accept-with-rationale in Dev Notes (option a, recommended) or write `sprint-change-proposal-2026-06-NN.md` (option b). Confirm NFR-P4-5 8 KB fixed-memory cap unaffected. Disposition logged in Dev Notes either way.

- [x] **Task 7 — Hardware smoke + close-out tag** (AC: #6, #8) — *user-gated; recipes provided, execution deferred to Ant*
  - [x] Sub-7.1 HW-smoke recipe for the AC5 integration probe provided **in the closing chat message** (STRONG rule, `feedback_post_hw_smoke_steps_at_review`).
  - [ ] Sub-7.2 Per Q1 + user authorization, `git tag v3.0.6` on the close-out commit; push deferred to explicit go-ahead (`git push origin <branch> v3.0.6`). **PENDING user authorization** (outward-facing) — recipe provided in the closing message, execution deferred to Ant. No `Co-Authored-By: Claude` trailer (`feedback_no_claude_coauthor`, STRONG).

- [x] **Task 8 — Epics-file annotation + sprint-status transition**
  - [x] Sub-8.1 Annotate the epics-file Story 21.3 § (`epics-phase4-epics-16-22.md:1096`) with the dev-pass reconciliation: version = **v3.0.6** (3.x.5 placeholder stale); downstream Epic 22 → v3.0.7; AC5 integration-probe re-spec (isolated fixture + home-bank FORGET); envelope ~+191 B disposition.
  - [x] Sub-8.2 `sprint-status.yaml`: `21-3-…` `ready-for-dev` → `in-progress` at dev-pass start; → `review` at dev-pass close; `→ done` + `epic-21 → done` follow the CR-pass + tag close gate.

## Dev Notes

### The two load-bearing draft-time drift findings (folded into ACs)

1. **Version = v3.0.6, not "3.x.5" (AC1, AC8).** The epics-file Story 21.3 §"antforth 3.x.5 tag" placeholder is stale — the SAME off-by-one Story 20.3 caught. `git tag v3.0.5` already exists on `0fb4434` (Epic 20 close-out — "epic-20 done, antforth 3.0.5"); banner `src/antforth.asm:781`, README `:14`, and Makefile test-80 `:1781` all already read `v3.0.5`. The 19.5 + MBB interlude consumed v3.0.4, shifting every downstream point release +1 vs the epics-file "3.x.N" slug; Story 20.3's Completion Notes already recorded "Epic 21 → v3.0.6 / Epic 22 → v3.0.7". Epic 21 ships **v3.0.6**. (B.4 / PD-2: the epics-file `3.x.N` slug is a planning placeholder, never the source of the version number.)
2. **Envelope ~+181–191 B vs ~150 B (AC7).** 21.1 = +82 B, 21.2 = +109 B (self-reported sum = +191); clean start→close rebuild ≈ +181 (backing out a 10 B inter-story drift). ~1.2–1.27× over the ~150 B Decision-Impact-Analysis envelope — a normal-calibration **pure-addition** overshoot inside the empirical ~2.4× Phase-4 multiplier (`project_epic17_envelope`). This is materially lighter than Epic 20's +680 B / 3.4× **design-substitution** breach (which forced a dedicated SCP); the multiplier-void carve-out does NOT apply here. NFR-P4-5 8 KB cap unaffected (code/links, not fixed-memory). Disposition granularity = Q2 (recommend Dev-Notes-only accept-with-rationale).

### Epic-21 cumulative binary trajectory (re-validate at dev-pass per B.3)

| Story | Close size (self-reported) | Δ | Note |
|---|---|---|---|
| (Epic-21 start) | ~27888 B (clean rebuild of `0fb4434`) | — | v3.0.5 close; NB Epic-20 retro reported 27625 B — 263 B drift, re-derive |
| 21.1 | 27970 B | +82 | MARKER/FORGET per-bank tail + stub-allocator-tail reclamation (full-table LDIR design) |
| 21.2 | 28069 B | +109 | saved-bank cell + interactive-`BANK!` recogniser (3 headerless words) + QUIT re-assert; +CR-fix `source_id==0` (0 B) |
| **Epic-21 total** | **28069 B** | **+181 (start→close) / +191 (per-story sum)** | **~1.2–1.27× over ~150 B → AC7 disposition (Q2)** |

Story 21.3 itself is **~0 B kernel** (banner same-length swap; README / Makefile-assertion / memory / test fixture are docs/infra). Re-derive each row by clean worktree rebuild at dev-pass start — the dev-pass reported figures drifted between stories (21.2 itself documents a 27970→27960 inter-story drift).

### Why the AC5 integration probe is re-specced (isolated fixture + home-bank FORGET)

The epics-file AC5 (`MARKER ZZZ 5 BANK! : W5 ; 7 BANK! : W7 ; 7 BANK! W5 ABORT`) is sound in *intent* but needs three hardening corrections proven by the 21.1/21.2 dev-passes:

1. **Isolated fixture, not the main suite** (`feedback_phase4_probe_bank_switch_limitation`, ADR 19.5 DR-1): the main `tests/banking_tests.fth` dictionary straddles `$8000`; any token lookup while a non-zero bank is mapped can walk a bucket chain through the portal window and read the foreign page (a `-13` strand). All Epic-17..21 behavioural probes live in dedicated `tests/banking_tests_NN_M.fth` fixtures with a matching `make test-repl-banking-isolated-NN-M` target. 21.3 follows suit.
2. **FORGET from the MARKER's home bank** (`project_banked_marker_no_stub`): `MARKER ZZZ` is created while in bank 0, so ZZZ's xt is its CFA in the bank-0 window — a banked MARKER has **no real dispatch stub**, so invoking it from a non-home bank HANGS (21.1 confirmed this empirically: a bank-5 marker invoked from bank 0 hangs). The probe must `0 BANK!` before `ZZZ`. (A regular `:` word like `W5` *does* get a descriptor stub — Epic 19.2 — so the cross-bank `7 BANK! W5` call is fine.)
3. **Expected `BANK@` after ABORT = 7** (Story 21.2 mechanism): every `BANK!` in the probe is typed interactively, so each updates `saved_bank`; the last is `7 BANK!`, so `saved_bank = 7`. After the `ABORT` (`-1` THROW) in bank 7, `QUIT`'s `w_REASSERT_BANK_cf` re-asserts `saved_bank` → `BANK@ .` returns **7**. This is the "never stranded in the wrong bank" property: the user lands on their last interactive choice, not wherever the aborted thread happened to be. (Observe `saved_bank` indirectly — no Forth word exposes it; `BANK@` post-recovery reports the re-asserted value.)

Verdict observation mirrors `banking_tests_21_1/21_2`: `result=-1` sentinel lines; FORGET-reachability via `' name` + content-grep of the `<name> ?` undefined line (NOT explicit `BL WORD name FIND` — a pre-existing quirk makes explicit `FIND` still resolve a forgotten word; the `'`/interpreter path is the user-visible ground truth, `project_banked_marker_no_stub`).

### CCD-4 stub-count metric (AC3) — Story 20.3 baseline to trend against

Story 20.3 captured: 0 stubs pre-allocated at boot (`stub_alloc_tail == STUB_ALLOC_BASE = $D4CB`); per-stub stride **4 B** (layout v2: `$EF` RST-$28 + signed target_bank + target_addr lo/hi); region `$D4CB..$DBFF` = 1845 B = **461-stub cap** → 0/461 (0%) at boot. Epic 21 adds **no boot-time stub pre-allocation** — MARKER/FORGET is a stub-*lifecycle* (reclamation) change, not a stub-*count*-at-boot change — so the expected boot trend is **unchanged**. Confirm empirically (don't assume). The new behaviour to verify (Story 21.1 AC6 b): after a MARKER → define-banked-word → FORGET cycle, the next banked-word stub xt equals the pre-MARKER tail — the allocator tail was reclaimed and reused, not leaked. NFR-P4-4: per-stub ≤ 5 B (4 B ✓); 1000-word target ≤ 5 KB total (4 KB ✓ with margin).

### Source tree components to touch

| File | What |
|---|---|
| `src/antforth.asm:781` | banner `v3.0.5` → `v3.0.6` (0 B; same length) |
| `README.md:14` + `V3.0.x supports` line + version-history prose | version refs → 3.0.6 + a 3.0.6 lifecycle-surface sentence |
| `Makefile:1781-1784` | REPL test 80 banner assertion → v3.0.6; new `test-repl-banking-isolated-21-3` target + `.PHONY` (mirror `:998` `-21-2`) |
| `tests/banking_tests_21_3.fth` (NEW) | AC5 integration probe (MARKER/FORGET per-bank + cross-bank call + ABORT bank-restore in one breath) |
| `disk/a/P213*.FTH` (NEW) | CP/M 8.3 HW-smoke copy, 0x1A-terminated, HW-ordered |
| `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:1096` | annotate Story 21.3 § (version v3.0.6; downstream Epic 22 → v3.0.7; AC5 re-spec; envelope disposition) |
| `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-NN.md` (NEW, **only if Q2 = option b**) | AC7 envelope record |
| `project_phase4_scope.md` (memory, external) | `description` + Epic-21 line → 3.0.6 SHIPPED / DONE; reconcile "v3.0.5 tag DEFERRED" |
| `_bmad-output/implementation-artifacts/sprint-status.yaml` | 21-3 transitions + epic-21 → done (at close gate) |

**Do not touch:** any kernel code (`src/banking.asm`, `src/outer_interpreter.asm`, `src/system.asm`, `src/inner_interpreter.asm` MARKER/DOMARKER, the stub allocator) — Epic 21's mechanism is shipped and `done`; this close-out is version-surface + integration-probe + reconciliation only. The banner same-length swap is the **only** kernel-binary-touching edit and must verify 0 B delta.

### Project Structure Notes

- Story 21.3 is the Epic-21 close-out gate; **~0 B kernel**. After it ships, Epic 21 is `done` and the next work is **Epic 22** (`.BANKS` polish + REPL prompt indicator + cross-bank CODE-words disposition + Phase-4 close-out → final tag, expected **v3.0.7** per the downstream-mapping shift).
- Stories 21.1 and 21.2 are already `done` — no `review → done` reconciliation (this close-out is structurally identical to Story 20.3, which also had both predecessor stories already `done`).
- The sprint-status key + filename `21-3-epic-21-close-out-antforth-3-x-5-tag` keep the stale `3-x-5` slug per the workflow's `{story_key}.md` rule (mirroring how 20.3 kept `…3-x-4-tag.md` while shipping 3.0.5). The story title and tag are **v3.0.6**.

### Detected conflicts or variances

- **Version slug drift:** sprint-status key + epics-file §"3.x.5" imply 3.0.5; reality requires **3.0.6** (v3.0.5 consumed by Epic 20). Resolved by AC1/AC8 + Q1; filename keeps the key.
- **Envelope ~150 B vs realised ~+191 B** — reconciled via AC7 (normal-calibration pure-addition overshoot inside the ~2.4× Phase-4 multiplier; lighter disposition than 20.3's design-substitution SCP). Q2 selects granularity.
- **Baseline-size discrepancy** — Epic-20 retro reported 27625 B at v3.0.5; 21.1 clean-rebuilt 27888 B (263 B gap). Re-derive both baseline + HEAD by clean worktree rebuilds at dev-pass (B.3); do not inherit.
- **AC5 epics-file probe under-constrained** — re-specced to an isolated fixture with home-bank FORGET + explicit `BANK@ = 7` expectation (see Dev Notes "Why the AC5 integration probe is re-specced").
- **Downstream version mapping** — confirms Epic 22 → v3.0.7; annotate the epics file (Task 8).

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:1096-1115`] — Story 21.3 §"Epic 21 close-out + antforth 3.x.5 tag" (the placeholder this story re-specs); Epic 21 goal `:1034-1048`; Epic 21 summary `:1117-1119`.
- [Source: `_bmad-output/implementation-artifacts/21-1-…md`, `21-2-…md`] — the two shipped Epic-21 stories (MARKER/FORGET per-bank + stub reclamation; saved-bank cell + recogniser + QUIT/ABORT restore) this close-out reconciles.
- [Source: `_bmad-output/implementation-artifacts/20-3-epic-20-close-out-antforth-3-x-4-tag.md`] — the structural template for this close-out (version surface + verdict walk + CCD-4 stub metric + envelope reconciliation + tag; B.4 "fourth surface" catch at the Makefile banner assertion; the v3.0.5-not-3.0.4 drift precedent + downstream-mapping annotation).
- [Source: `src/antforth.asm:781`] — banner version string (AC1; re-validate line at dev-pass; same-length 0 B swap).
- [Source: `README.md:14,43`] — README version refs + version-history prose (AC1; re-validate line numbers — README grew since 20.3).
- [Source: `Makefile:1781-1784`] — REPL test 80 banner assertion (AC1 fourth surface); `:998` `test-repl-banking-isolated-21-2` recipe to mirror for `-21-3` (AC5/AC6); `.PHONY:52`.
- [Source: `src/banking.asm` / `src/constants.asm:25` `STUB_ALLOC_BASE $D4CB`; `src/structures.asm:53` `stub_alloc_tail`; 4 B stride; 461-stub cap] — CCD-4 stub metric (AC3); Story 20.3 / 21.1 baseline.
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-12.md`] — prior (Epic-20) SCP record shape (AC7 option b reference).
- [Source: `_bmad-output/planning-artifacts/prd.md` NFR-P4-4 / NFR-P4-5; `architecture.md` §"Gap Analysis"] — NFR-P4-4 (stub ≤ 5 B; ≤ 5 KB @ 1000-word target); NFR-P4-5 (8 KB Phase-4 fixed-memory cap).
- Git: `v3.0.5` = `0fb4434` (Epic 20 close, ~27888 B clean rebuild); HEAD `44177ca` = 28069 B (21.2 close); `v3.0.1..v3.0.5` contiguous.
- Memory: `project_phase4_scope`, `project_banking_bios_pivot`, `project_banked_marker_no_stub`, `project_epic17_envelope`, `feedback_post_hw_smoke_steps_at_review` (STRONG), `feedback_no_claude_coauthor` (STRONG), `feedback_cpm_0x1a_eof_marker`, `feedback_tib_size_inline_comments`, `feedback_phase4_probe_bank_switch_limitation`, `feedback_source_comment_discipline`, `feedback_kernel_ldir_estimate_overshoot`, `feedback_no_preexisting_discharge`, `feedback_plain_qa_language`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — dev-story workflow.

### Debug Log References

**Q-dispositions (resolved via AskUserQuestion at dev-pass start, before any edit):**
- **Q1 = v3.0.6** (forced by repo reality — `git tag v3.0.5` already on `0fb4434`; the epics-file "3.x.5" slug is a stale planning placeholder).
- **Q2 = accept-with-rationale in Dev Notes only** (no dedicated SCP — pure-addition overshoot, materially lighter than Story 20.3's 3.4× design-substitution breach).

**Pre-edit baselines (clean `make clean && make`, re-derived per B.3 — inherited no number):**
- HEAD `44177ca` (21.2 close): **28069 B**.
- Baseline-before-Epic-21 `0fb4434` (`b9da7b2^`, v3.0.5 close): **27888 B** (git-worktree clean rebuild) — confirms 21.1's measurement; the Epic-20 retro's 27625 B is a 263 B mis-measure, discarded.
- test-repl **975/0** · test-repl-banking **61/0** · isolated 19-3=15 / 19-4=2 / 19-5-1=2 / 20-1=7 / 20-2=5 / 20-3=5 / 21-1=5 / 21-2=5 (all 0 FAIL) · straddle **3/3** · file-sanity **0 errors** · check-doc-sync **31 advisory / 0 drift**.
- `git tag` state: `v3.0.1..v3.0.5` contiguous (no gap); `v3.0.5` = `0fb4434`. Next tag = **v3.0.6**.
- Version-surface citations re-validated (B.4): banner `src/antforth.asm:781`; README `:14` heading, `:37` history prose, `:43` `V3.0.5 supports`; Makefile `:1781-1784` test-80 assertion. `grep -rE 'v?3\.0\.5'` confirmed these were the only surfaces. (README prose was at `:37`, not the story's guessed `:39` — re-grepped, as instructed.)

### Completion Notes List

**Story 21.3 is a ~0 B-kernel close-out gate.** The single kernel-binary-touching edit (banner same-length swap) verified **0 B delta** (28069 B → 28069 B clean rebuild). All other edits are docs / test-infra / fixture.

**AC1 — version surface → v3.0.6 (all four surfaces + memory):**
- `src/antforth.asm:781` banner `v3.0.5` → `v3.0.6` (same-length 32-char string; clean rebuild 28069 B unchanged; `strings build/antforth.com` shows `AntForth v3.0.6`).
- `README.md:14` heading → `## Version 3.0.6`; `V3.0.6 supports …` line; added a 3.0.6 version-history sentence for the bank-aware **lifecycle** surface (MARKER/FORGET per-bank + stub-tail reclamation, QUIT/ABORT saved-bank re-assert, F6 INCLUDE-no-pollution). Historical 3.0.x prose left intact (the `:37` "3.0.5 delivers the bank-aware lookup surface" line is Epic-20 history, correctly preserved).
- `Makefile:1781-1784` REPL test 80 banner assertion `v3.0.5` → `v3.0.6`; **test 80 PASS on `AntForth v3.0.6`** post-edit (the B.4 "fourth surface" — caught and bumped, did not let `make test-repl` fail on it).
- Memory `project_phase4_scope.md` `description` + Epic-21 body line advanced to "antforth 3.0.6 close-out dev-passed / Epic 21 DONE"; the stale "v3.0.5 tag DEFERRED" reconciled (v3.0.5 **IS** tagged on `0fb4434`); downstream Epic 22 → v3.0.7. MEMORY.md index line rewritten (was stale: "v3.0.4 tag HELD").

**AC2 — Epic-21 verdict-table walk** (HW transcripts re-validated at dev-pass, not transcribed blindly):

| Story | Surface | Verdict | Δ | Evidence |
|---|---|---|---|---|
| 21.1 | MARKER/FORGET per-bank dictionary tail + descriptor-stub allocator-tail reclamation | **PASS (done)** | +82 B (27888→27970) | isolated-21-1 a/b/c/d/suite PASS (forget-across-banks, stub reclamation `result=-1`, cross-bank-MARKER survival, per-bank HERE rollback); HW smoke PASS on silicon, attested in commits `b9da7b2` / `8a3c8e2` |
| 21.2 | saved-bank cell + interactive-`BANK!` recogniser + QUIT/ABORT restore (incl. `source_id==0` CR-fix) | **PASS (done)** | +109 B (27960→28069) | isolated-21-2 a/b/c/d/suite PASS; HW smoke `beastty-20260612-122451.bin` (AC6 a/b/d); CR-fix HW UAT `beastty-20260612-133209.bin` — `S" 5 bank!" EVALUATE` then `ABORT` → `BANK@`=3 (EVALUATE-leak gate on silicon) |
| 21.3 | close-out + v3.0.6 tag | **PASS** | ~0 B kernel | banner same-length swap (0 B verified) + docs/test-infra + AC5 integration fixture; full sweep green (below); HW UAT PASS on silicon `beastty-20260612-150429.bin` (INCLUDE subset xcall/recl/result=-1 + hand-typed `bank@ .`→7 after ABORT) |

**AC3 — CCD-4 banked-word stub-count metric (trend vs Story 20.3 baseline):**
- `STUB_ALLOC_BASE = $D4CB` (= `ACTIVE_PAGES_BASE + ACTIVE_PAGES_SIZE`, `src/constants.asm:25`); COLD seeds `stub_alloc_tail = STUB_ALLOC_BASE` (`src/structures.asm:53-54`) → **0 stubs pre-allocated at boot** (deterministic from the COLD seed; matches 20.3).
- Per-stub stride **4 B** (layout v2: `$EF` RST-$28 + signed target_bank + target_addr lo/hi, `src/banking.asm:732-800`); region `$D4CB..$DBFF` = 1845 B = **461-stub cap** → **0/461 (0%) at boot — unchanged vs Story 20.3**.
- NFR-P4-4: per-stub 4 B ≤ 5 B ✓; 1000-banked-word target = 4000 B ≤ 5 KB ✓ (with margin).
- **Lifecycle (not boot-count) change:** Epic 21 adds no boot-time stub pre-allocation. The MARKER/FORGET cycle exercises allocator-tail **reclamation** — isolated-21-1 probe-b and isolated-21-3 probe-c both confirm `result=-1`: after `MARKER → define-banked-word → FORGET`, a fresh banked-word stub xt **equals** the pre-MARKER allocator tail (reclaimed + reused, not leaked). Expected boot trend unchanged (0/461) — confirmed empirically, not assumed.

**AC5 — integration probe (the Epic-21 lifecycle story in one breath; isolated fixture):**
- New `tests/banking_tests_21_3.fth` + `make test-repl-banking-isolated-21-3` (+ `.PHONY`), mirroring `_21_2`/`_21_1`. **6 PASS / 0 FAIL.** Re-specced from the epics-file probe per the three dev-pass hardening findings (isolated fixture; home-bank FORGET; `BANK@`=7 expectation):
  - probe-a: `MARKER ZZZ` (home bank 0) → `5 BANK! : W5 42 ;` / `7 BANK! : W7 ;` → `7 BANK! W5` cross-bank call (W5 resident in bank 5, dispatched via its descriptor stub) returns 42 across the fixed-memory data stack → `x5=42`; then `ABORT`.
  - probe-b: post-ABORT recovery — `QUIT` re-asserts `saved_bank` (=7, the last interactive `BANK!`) → `BANK@` → **7** (never stranded mid-execution).
  - probe-c: `0 BANK! ZZZ` FORGET from ZZZ's home bank → stub-allocator tail reclaimed + reused (`recl=-1`: redefined bank-5 word's stub xt == W5's old stub xt).
  - probe-d: `' W5` / `' W7` now raise -13 → plain `W5 ?` / `W7 ?` (forgotten across both banks).
  - probe-e: caller bank + slot-2 page restored; fresh `: Wok 1234 ;` compiles + runs (`result=-1`: bank AND slot-2 unchanged across the verification, via self-contained `MBB-GET-2` slot-2 reader).
- Constraints honoured: lines ≤ 81 chars (TIB 128, `feedback_tib_size_inline_comments`); `saved_bank` observed indirectly via `BANK@` (no exposing word); FORGET verdict via `' name` content-grep, NOT explicit `FIND` (`project_banked_marker_no_stub`).
- HW copy `disk/a/P213INTG.FTH` (8.3, 0x1A-terminated): INCLUDE-safe computed subset (cross-bank call / stub reclamation / bank+slot restore — all `result=-1`/`recl=-1`/`xcall=-1`), with the saved-bank/QUIT-re-assert property documented as a hand-typed TAIL (it is intrinsically interactive — the recogniser gates on `source_id==0` and an ABORT would abort an INCLUDE). Verified green by piping through iz-cpm-banking; file-sanity 0 errors. (Same INCLUDE-safe discipline as the 21.1 `P211MFK.FTH` HW copy.)

**AC6 — full test surface sweep (against the v3.0.6 build):**
- `make test-repl` **975 / 0** (test 80 banner assertion now `v3.0.6`; `XYZZY ?` undefined-word holds).
- `make test-repl-banking` **61 / 0**.
- isolated: 19-3=15 / 19-4=2 / 19-5-1=2 / 20-1=7 / 20-2=5 / 20-3=5 / 21-1=5 / 21-2=5 (unchanged cohort) + **new 21-3=6**, all 0 FAIL.
- `make test-straddle-regression` **3 / 3**; `make test-file-sanity` **0 errors** (incl. new `disk/a/P213INTG.FTH`, 0x1A-terminated); `make check-doc-sync` **31 advisory / 0 drift**.
- **Hardware smoke: PASS on real MicroBeast 2026-06-12** (`beastty-20260612-150429.bin`, silicon banner v3.0.4 — older binary; the lifecycle mechanism is banner-independent per the 19.5.4 precedent). `INCLUDE P213INTG.FTH` → `xcall=-1` (cross-bank call W5 bank5←bank7 via stub), `recl=-1` (stub-allocator tail reclaimed across FORGET), `result=-1` (caller bank + slot-2 restored), `---probe-21.3-suite-end---`. Then the hand-typed saved-bank TAIL (intrinsically interactive): `0 bank!` / `5 bank! : X5 ;` / `7 bank!` / `abort` (→ `error -1: ABORT`) / `bank@ .` → **7** — QUIT re-asserted the last interactive bank on silicon (never stranded). AC6 S9 / NFR-P4-11 satisfied. (Recipe posted in the closing chat message per `feedback_post_hw_smoke_steps_at_review`, STRONG.)

**AC7 — Epic-21 envelope reconciliation (Q2 = Dev-Notes accept-with-rationale, NO SCP):**
- Clean worktree rebuilds: baseline `0fb4434` = **27888 B**, HEAD-at-close = **28069 B** → cumulative **+181 B** (start→close); per-story self-reported sum **+191 B** (21.1 +82 + 21.2 +109). The ~10 B gap is the known inter-story measurement drift (21.2 itself documents a 27970→27960 re-baseline). Reconciled: both figures cited; the start→close subtraction (+181 B) is the authoritative cumulative.
- **~1.2–1.27× over the ~150 B Decision-Impact-Analysis envelope** (+31–41 B) — a normal-calibration overshoot, well inside the empirical ~2.4× Phase-4 multiplier (`project_epic17_envelope`); ~150 B is the redesign-§7 spec target, not an empirical ceiling. +191 B sits comfortably under ~150 × 2.4 ≈ 360 B.
- **Pure addition, NOT a design substitution** (MARKER/FORGET snapshot+restore wiring + interactive recogniser + QUIT re-assert) → the Epic-20 "multiplier-void on substitution" carve-out does NOT apply; normal calibration governs. Materially lighter than Story 20.3's 3.4× design-substitution breach (which forced a dedicated SCP) → Dev-Notes accept-with-rationale is the proportionate disposition.
- **NFR-P4-5 8 KB Phase-4 fixed-memory cap unaffected:** the +181 B is code/links. The banking fixed-memory block is `$D400..$DBFF` = 2048 B (bank-table 174 B + active-pages 29 B + stub region 1845 B), ≈ 6 KB under the 8 KB cap. Epic 21 added **no new fixed-memory structures** (MARKER snapshots into its dictionary-space body; reuses the existing bank-table[] + stub allocator) → fixed-memory footprint unchanged from Epic 20; stub region still 0/461 at boot.

**AC8 — tag (user-gated, deferred):** `git tag` confirms `v3.0.1..v3.0.5` contiguous, no gap; next = **v3.0.6** on the close-out commit. Commit + tag + push are outward-facing → **PENDING explicit user authorization** (recipe in closing message; no `Co-Authored-By: Claude` trailer per `feedback_no_claude_coauthor`, STRONG).

### File List

- `src/antforth.asm` — banner `str_banner1` v3.0.5 → v3.0.6 (same-length; 0 B kernel delta).
- `README.md` — `## Version 3.0.6` heading; `V3.0.6 supports …`; added 3.0.6 lifecycle-surface version-history sentence.
- `Makefile` — REPL test 80 banner assertion v3.0.5 → v3.0.6; new `test-repl-banking-isolated-21-3` target + `.PHONY` entry.
- `tests/banking_tests_21_3.fth` (NEW) — AC5 Epic-21 close-out integration probe (6 sub-probes).
- `disk/a/P213INTG.FTH` (NEW) — CP/M 8.3 HW-smoke copy, 0x1A-terminated, INCLUDE-safe subset + hand-typed saved-bank TAIL.
- `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` — Story 21.3 § dev-pass annotation (version v3.0.6; Epic 22 → v3.0.7; AC5 re-spec; envelope disposition).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 21-3 ready-for-dev → in-progress → review.
- `_bmad-output/implementation-artifacts/21-3-…md` — this story (Tasks/Subtasks, Dev Agent Record, File List, Change Log, Status).
- (external memory) `project_phase4_scope.md` + `MEMORY.md` — description/body/index advanced to 3.0.6 / Epic 21 DONE; v3.0.5-tag-deferred reconciled.

### Change Log

- 2026-06-12 — Story 21.3 dev-pass (Epic 21 close-out): version surface aligned 3.0.5 → **v3.0.6** across all four surfaces (banner / README / Makefile test-80 / memory; banner 0 B same-length swap, clean rebuild 28069 B unchanged). New AC5 integration fixture `tests/banking_tests_21_3.fth` + `test-repl-banking-isolated-21-3` (6/0) exercising the full Epic-21 lifecycle in one breath (cross-bank call → ABORT → QUIT saved-bank re-assert `BANK@`=7 → home-bank FORGET → stub reclamation → bank/slot restore); HW copy `disk/a/P213INTG.FTH`. CCD-4 stub metric 0/461 at boot (unchanged vs 20.3; reclamation is lifecycle not boot-count). Epic-21 envelope reconciled +181 B (start→close) / +191 B (per-story) vs ~150 B — normal-calibration pure-addition, accept-with-rationale Dev-Notes only (Q2), no SCP; NFR-P4-5 8 KB fixed-memory cap unaffected. Full sweep green (test-repl 975/0 · banking 61/0 · isolated incl 21-3 6/0 · straddle 3/3 · file-sanity 0 · doc-sync 31 advisory/0 drift). HW smoke + `git tag v3.0.6` user-gated (recipe in closing message). Status → review.
- 2026-06-12 — HW UAT PASS on real MicroBeast (`beastty-20260612-150429.bin`, silicon v3.0.4 banner — mechanism banner-independent): `INCLUDE P213INTG.FTH` → `xcall=-1` / `recl=-1` / `result=-1` / suite-end; hand-typed TAIL `0 bank! / 5 bank! : X5 ; / 7 bank! / abort / bank@ .` → **7** (saved-bank re-asserted after ABORT on silicon). AC6 S9 / NFR-P4-11 satisfied. Tag still pending user authorization (AC8).
