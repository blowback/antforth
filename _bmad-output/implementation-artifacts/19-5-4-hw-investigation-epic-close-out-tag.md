# Story 19.5.4: HW investigation + Epic 19.5 close-out + antforth 3.0.4 tag

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-08 by create-story workflow on the Story 19.5.4 turn.
     Story 19.5.4 is the Epic 19.5 close-out gate: it ships the
     *cross-bank-dispatch stabilization* (Stories 19.5.0–19.5.3 — ADR
     spike → portal-aliasing guards + H5 → RST-stub dispatch rework
     (option C) → compiled-body verification) as antforth 3.0.4, with the
     full hardware investigation recorded, the Epic-19.5 envelope
     reconciled, the NFR-P4-3 re-baseline codified, the five Epic-19
     architectural-debt anchors marked discharged, and the v3.0.4 tag
     applied.

     LOAD-BEARING REALITY — the HW investigation this story was scoped to
     PERFORM has ALREADY RUN, ahead of schedule, during Story 19.5.2's
     hardware smoke (2026-06-06). The epic plan (epics:890) assigned
     A1/A2/A3 + the three-surface HW sweep to 19.5.4; in practice the UAT
     ran early, A1/A2/A3 were all resolved on silicon, AND a NEW
     divergence (DIV-1: MMU port readback floats on real HW) was found,
     fixed, and HW-verified (commits 2fb448b → 1bab95a → 1e2c44e). The
     19.5.4 HW ledger is therefore COMPLETE before this story is dev-passed
     (sprint-status.yaml:534..580). Consequence: 19.5.4 is NOT a fresh
     HW-investigation story — it is a close-out that (a) TRANSCRIBES the
     already-gathered evidence into the formal story record, (b) re-sweeps
     the three surfaces against the v3.0.4 build, (c) reconciles the
     envelope, (d) codifies the NFR-P4-3 re-baseline, (e) discharges the
     debt anchors, (f) decides the retro, and (g) tags. It is a 0-byte-
     kernel gate (version-surface alignment + doc status + tag).

     This mirrors the Story 19.4 Epic-19 close-out precedent
     (19-4-epic-19-close-out-antforth-3-x-3-tag.md): version surface +
     verdict-table walk + CCD-4 stub metric + envelope reconciliation +
     tag, 0 B kernel. The ONE structural difference: 19.5.4 carries the
     HW evidence ledger (A1/A2/A3 + DIV-1) and the NFR-P4-3 re-baseline,
     which 19.4 did not. Sprint-status row key (immutable):
     19-5-4-hw-investigation-epic-close-out-tag. -->

## Story

As Ant (the project lead applying the Epic 19.5 close-out tag),
I want the hardware investigation ledger (A1/A2/A3 named assumptions + the DIV-1 MMU-readback divergence found/fixed/verified) recorded formally in the story, the three test surfaces (iz-cpm flat + iz-cpm-banking + real MicroBeast) re-swept clean against the v3.0.4 build, the Epic-19.5 binary envelope reconciled (~120 B cumulative vs the ~100 B ADR guidance), the NFR-P4-3 cross-bank-overhead re-baseline codified (≤ 400 T + MMU port write, per the ADR per-opcode table), the five Epic-19 architectural-debt anchors marked discharged in architecture/redesign, the Epic-19.5 retrospective disposition decided, the user-visible version surface aligned to `3.0.4`, and the `v3.0.4` tag applied,
so that Epic 19.5's *cross-bank-dispatch stabilization interlude* ships as antforth 3.0.4 with an honest, reconciled close-out — the compiled-body cross-bank north-star UX (`5 BANK! : MYWORD ... ; ... MYWORD` from a compiled definition) is now behaviourally delivered on the emulator and the dispatch mechanism is confirmed on real silicon, with the DR-1 portal-aliasing limit explicitly carried to Epic 20.

## Acceptance Criteria

> **Story posture: close-out + formal record.** Stories 19.5.0–19.5.3 shipped and verified the cross-bank-dispatch stabilization (RST-$28 self-dispatch stub + 2-cell frame + xbank_thunk/xbank_restore; CR-F1 caught-THROW triple restore; portal-aliasing F1 guard + F2 COLD-init; compiled-body + banked-CATCH verification). The HW UAT assigned to this story already ran (2026-06-06) and its ledger is COMPLETE. **Expected binary delta ≈ 0 B (banner same-length string + README/memory/doc edits only).** A kernel change is in-scope ONLY if the three-surface re-sweep surfaces a real regression — in which case surface-file-fix per [[feedback_no_preexisting_discharge]], itemise per B.2, and carry the delta to this story's envelope reconciliation (AC3).

**Given** Stories 19.5.0 (ADR spike, DONE), 19.5.1 (portal-aliasing guards + bank-N HERE COLD-init H5 + reproducer regression slot, DONE), 19.5.2 (RST-stub dispatch rework option C + CR-F1 CATCH triple restore + DIV-1 MMU-readback fix, DONE), and 19.5.3 (compiled-body verification + full banked NFR-P4-8 variant, DONE) have shipped (current binary **26953 B** at HEAD `b4cc093`; HW ledger COMPLETE per sprint-status.yaml:534..580), and ADR 19.5 was accepted with the NFR-P4-3 re-baseline rider (Ant sign-off 2026-06-04, `docs/adr-19-5-cross-bank-dispatch.md:3`),
**When** Story 19.5.4 is dev-passed,

**Then AC1 (Hardware investigation ledger — formal record of the already-gathered evidence).** Story 19.5.4 Dev Notes transcribe the COMPLETE HW UAT ledger (run 2026-06-06; transcripts `beastty-20260606-112043 / -113348 / -120930 / -122352.bin`) as the formal Epic-19.5 hardware record, one verdict line per ADR named assumption + the new divergence:
- **A1 (straddle reproducer PASS/HANG/GUARD signature on real MicroBeast — ADR `:303`, DR-1 prediction "dies identically"):** PASS config ✓ (m1..m5+ survived; calibration 27196 exact); HANG config ✓ (m1..m3 then crash-restart — DR-1 "dies identically" **CONFIRMED on silicon**, retiring the prior input-confounded "HW passes" evidence); GUARD config ✓ after the DIV-1 fix (STRADG re-run → `27209/32813/32900/[m1]/error -273` — the F1 window-guard `-273` fires on real silicon exactly as predicted).
- **A2 (`$0028` RST-vector claimability under MicroBeast CP/M — ADR `:305`):** DONE — `$28 C@ → C3` (a live `JP`); the RST-$28 dispatch vector installs cleanly, no re-vector needed; cross-bank DOCOL dispatch 42/0 on silicon.
- **A3 (Probe-19.2-F intra-bank-EXECUTE-into-slot-2 HW hang — ADR `:310`, "same aliasing family?"):** ✓ — intra-bank EXECUTE into slot 2 → 7 (the old 19.2-F HW hang shape is **dead** under the C dispatch + F2 COLD-init); cross-bank DOVAR → 32796/bank 0. The 19.2-F hang was NOT a distinct defect — it was the DIV-1 readback-float family (see below).
- **DIV-1 (NEW divergence — MMU port readback floats on real HW; not an ADR-named assumption):** `IN A,(0x72)` MMU-slot readback (the `cl_probe_and_add` restore path) returns an open-bus self-opcode echo on real silicon (`$4E` = `C@`'s own `LD C,(HL)`; `$7E` = `LD A,(HL)` on the WORD/FIND read path) — the restored slot-2 page is UNMAPPED, retro-explaining the original Probe-19.2-F HW-only hang. **Found** (diagnostic transcript `-120930.bin`, 4 sessions), **fixed** (1bab95a: `cl_probe_and_add` restores slot 2 from `active_pages[current_bank]` / leaves the candidate mapped, `IN (0x72)` retired; +13 B → 26953), and **HW-verified** (1e2c44e; transcript `-122352.bin` before/after: old kernel boot canary 4E/4E, new kernel 5C/5A — window live unprimed). See [[project_div1_mmu_port_readback]].
- **F1/F2 silicon confirmation:** F1 (`BANK!` window guard, `-273`) confirmed on silicon (the A1-GUARD config); F2 (bank-table[1..28].here = `$8000` at COLD) HW-verified (first-visit `HERE` = 32768/32800/27209 across configs).
**Verdict:** the dispatch mechanism (option C) is confirmed on real MicroBeast; A1/A2/A3 resolved; DIV-1 found/fixed/verified; HW ledger COMPLETE. Cross-reference the sprint-status evidence block (`sprint-status.yaml:534..580`) and the four transcripts as the source-of-truth; re-validate the figures per B.4 / PD-2 (do not transcribe a stale number — re-read the sprint-status block at dev-pass).

**And AC2 (Three-surface sweep — re-run clean against the v3.0.4 build).** All three verification surfaces green; record actuals at dev-pass start (B.3) and re-confirm at close:
- **Surface 1 — flat iz-cpm:** `make test-repl` ≥ **975 PASS / 0 FAIL** (the Phase-3 974-baseline + Phase-4 probes; NFR-P4-10 release blocker on a single regression). If flat test-643 (`*/` underflow) trips after any layout shift, re-tune via the `cold_start` NOP slot ONLY ([[feedback_iz_cpm_test_643_quirk]]) — not antforth-side.
- **Surface 2 — iz-cpm-banking (emulator):** `make test-repl-banking` ≥ **63 / 0**; `make test-repl-banking-isolated` (19-2) **6 PASS**; `make test-repl-banking-isolated-19-3` **15 PASS / 0** (D/E/F/G + 19.3.1-A + 19.5.2-b/c/d + 19.5.3-ac2/ac3/ac6 all PASS, suite-end sentinels present); `-isolated-19-4` **2/0**; `-isolated-19-5-1` **2/0**; `make test-repl-banking-skip` **25 PASS / 3 SKIP / 0 FAIL**; `make test-straddle-regression` **3/3**.
- **Surface 3 — real MicroBeast (HW):** the ledger is COMPLETE (AC1) — A1/A2/A3 + F1/F2 + DIV-1 all confirmed on silicon 2026-06-06. **No NEW deferred HW smoke is required for this close-out** (the only delta since the ledger ran is the same-length banner string — 0 B, no behavioural change). State this explicitly in the close message per [[feedback_post_hw_smoke_steps_at_review]] (STRONG). If Ant wants a belt-and-braces v3.0.4 banner-confirm smoke, provide the recipe (0x1A-terminate any fixture before SLIDE per [[feedback_cpm_0x1a_eof_marker]]) — but it is optional, not gating.
- `make check-doc-sync` reports **0 drift** (advisory count = the 31-baseline) at close.

**And AC3 (Epic-19.5 envelope reconciliation — accept-with-rationale).** Re-derive the Epic-19.5 cumulative binary delta from a clean worktree rebuild (B.3 — do NOT inherit dev-pass figures): baseline = Epic-19 close-out size (**26834 B**, Story 19.4 CR post-fix); current HEAD = **26953 B** → cumulative **≈ +119 B** (story-by-story: 19.5.0 0 B · 19.5.1 +65 B · 19.5.2 +~42 B · DIV-1 fix +13 B · 19.5.3 0 B; re-validate each via clean rebuild). The ADR-itemised guidance was **~+30..+100 B** (epics:902: F1 ~20 + F2 ~17 + option-C net −13..+25 + CATCH ~20, ×1.25). **+119 B is ~19 B over the ~100 B upper guidance.** AC3 does NOT assert a clean ≤100 B pass; it records an accept-with-rationale: (i) the **+13 B DIV-1 fix was an unbudgeted correctness fix** — a HW-only MMU-readback defect found during 19.5.2's smoke that could not be declined ([[feedback_no_accept_disposition_for_bugs]], [[project_div1_mmu_port_readback]]); excluding it, the epic lands at ~+106 B, within rounding of the guidance; (ii) the residual sits comfortably inside the realistic envelope — the empirical Phase-4 pattern is ~2.4–2.7× the redesign-§7 spec target ([[project_epic17_envelope]]), putting the ~100 B ADR figure's realistic band at ~240–270 B; (iii) NFR-P4-5's 8 KB Phase-4 fixed-memory cap is unaffected (119 B is a small fraction). Disposition: either fold into an existing SCP record or write a short Epic-19.5 envelope note in `_bmad-output/planning-artifacts/` (Q1); log the verdict in Dev Notes. **If the AC2 re-sweep forced any kernel fix, itemise it per B.2 (per-component opcode sum, NO "mirrors prior arm" shorthand) and add its bytes to this reconciliation — do not absorb silently** ([[feedback_plain_qa_language]]).

**And AC4 (NFR-P4-3 re-baseline — codify the ADR-accepted rider).** The ADR (`docs/adr-19-5-cross-bank-dispatch.md:287..297`) proposed re-baselining **NFR-P4-3** from "cross-bank call ≤ 60 T + bank-switch" (epics:107) to **"cross-bank dispatch ≤ 400 T + MMU port write, measured RST-entry → target CF"**, with the ADR per-opcode table (`:228`, ≈343 T dispatch-side for option C) as the source of truth; sign-off **rode with the ADR's acceptance** (Ant 2026-06-04, ADR `:3`). Story 19.5.4 **codifies** that accepted re-baseline:
- Update the **NFR-P4-3 text** at `epics-phase4-epics-16-22.md:107` to the re-baselined wording, with an append-only note citing ADR 19.5 + the date (do NOT silently rewrite history — use the SUPERSEDED-note style 19.5.2/19.5.3 used; the old ≤60 T figure was unmet by the **shipped Epic-18 EXECUTE path** at ≈420 T, so C at ≈343 T *improves* shipped reality while failing the original paper number — record that rationale).
- Note in Dev Notes that the ≤60 T target was never achievable with a 2-cell frame + MMU lookup on this CPU (ADR `:296..297`), and that the per-opcode table in the ADR is the authoritative measurement.
- `make check-doc-sync` stays 0 drift after the edit (the NFR text is prose; mind any `[story-cite]`-style token the doc-sync checker keys on, as 19.5.3 hit with the literal `Story 19.5.3` token — see 19.5.3 Debug Log).

**And AC5 (S11 / NFR-P4-38 user-visible version surface audit → 3.0.4).** The version surface is aligned to `3.0.4` (re-validate every cited file:line at dev-pass start per B.4 / PD-2 — line numbers drift):
- `src/antforth.asm:813` `str_banner1` reads `"AntForth v3.0.4 (C) ant.org 2026"` (currently `v3.0.3`) — same-length string edit → **0 B kernel delta** (verify via clean rebuild = unchanged size + `strings build/antforth.com`).
- `README.md` version references advance to `3.0.4` (currently `## Version 3.0.3` at `:14`, the `3.0.3 ships...` prose at `:24`, the "forthcoming cross-bank-dispatch stabilization release" forward-reference at `:29` — which IS this release, so resolve it to "delivered in 3.0.4", and `V3.0.3 supports...` at `:32`). Add a 3.0.4 version-history sentence: the cross-bank-dispatch stabilization (RST-stub dispatch + portal-aliasing guards; compiled-body north-star delivered on the emulator, dispatch confirmed on silicon; DR-1 portal-aliasing limit carried to Epic 20).
- **The Makefile REPL test-80 banner assertion (`Makefile:1689..1692`, `grep 'AntForth v3.0.3'`) MUST advance to `v3.0.4`** — this is the fourth version surface that B.4 caught in Story 19.4 (the post-edit `test-repl` will FAIL at test 80 if missed). Test-infra; 0 B.
- The Phase-4-scope memory entry's `description` field (`project_phase4_scope.md`) advances to note `antforth 3.0.4 SHIPPED` (Epic 19.5 close) — see AC9 memory update.

**And AC6 (verdict-table walk per Story-13.5.6 precedent + check-doc-sync clean).** Story 19.5.4 Dev Notes include a verdict-table walk for all Epic-19.5 stories with one-line evidence each: 19.5.0 (ADR spike — two decision records locked, 0 B) · 19.5.1 (portal-aliasing F1 guard + F2 COLD-init + F3 regression slot, +65 B) · 19.5.2 (RST-stub option-C dispatch + CR-F1 + DIV-1 fix, +~42 B core +13 B DIV-1) · 19.5.3 (compiled-body + full NFR-P4-8 verification, 0 B). `make check-doc-sync` → 0 drift (advisory = 31-baseline) after all AC4/AC5/AC8 doc edits.

**And AC7 (CCD-4 banked-word stub-count metric — per-epic close-out line item).** Capture the per-epic CCD-4 metric (the line item established at Story 19.4, AC3; F2-mitigation operational): total banked-word descriptor-stub count after Epic 19.5 (`(stub_alloc_tail − STUB_ALLOC_BASE) / 4` across the test surfaces); fixed-memory occupancy; trend vs the Story 19.4 baseline (0 stubs pre-allocated at boot; 4 B/stub stride; region `$D4CB..$DBFF` = 461-stub cap). Epic 19.5 added no static stub pre-allocation (test/verification + dispatch-mechanism story), so the expected boot metric is unchanged at 0/461 — confirm empirically and record. Assert against the redesign-§7 envelope (~4–5 KB / 1000 words).

**And AC8 (Epic-19 architectural-debt anchor discharge — architecture/redesign status).** Epic 19.5 "discharges all five Epic-19 architectural-debt anchors" (epics:902). Mark them **discharged** in `architecture.md` + `docs/antforth-banking-redesign.md` (append-only status, SUPERSEDED-note style — no history rewrite):
- **(a) DTC threading-through-stub-xt** (NEXT blind `JP (HL)` into a stub) → discharged by 19.5.2 option C (`$EF`/`RST $28` byte 0); verified compiled-body 19.5.3.
- **(b) cross-bank trampoline assumes DOCOL/EXIT — non-DOCOL targets hang** (Probe-19.3-F) → discharged by 19.5.2 `xbank_thunk`/`xbank_restore` (uniform non-DOCOL return); verified 19.5.3 AC4.
- **(c) sentinel-trampoline layout-fragility** → reframed by ADR DR-1 (it was portal-window dictionary aliasing, NOT trampoline fragility — [[feedback_iz_cpm_trampoline_fragility]] SUPERSEDED); the F1 `BANK!` guard CONTAINS the user-facing class (`-273`); the **abolition** (per-wordlist bank field / bank-aware FIND) is **Epic 20** (redesign §5.5) — mark "contained, not abolished; owning fix Epic 20".
- **(d) intra-bank-EXECUTE-into-slot-2 HW gap** (Probe-19.2-F) → discharged: A3 + DIV-1 fix proved it was the MMU-readback-float family, now fixed (AC1).
- **(e) CATCH-around-cross-bank reboot** → discharged by 19.5.2 CR-F1 (caught-THROW MMU+bank+triple restore); verified 19.5.3 AC6 (full NFR-P4-8).
- **(f) bank-N HERE COLD-init (H5)** → discharged by 19.5.1 F2 (re-landed). [This is the sixth anchor from the 19.4 carry-forward list; the epic summary's "five" counts (c)+(d) as the single layout/HW-aliasing family — note the reconciliation in Dev Notes so the count reads honestly.]
Confirm redesign §5.4/§5.5 already cover the FR-P4-26 / DR-1 residual fences (cross-bank pointer read, cross-bank-from-bank-N body, cross-bank DOES> body) — Epic 20 owning fix; do NOT force them green.

**And AC9 (Epic-19.5 retrospective disposition + memory update).** `epic-19-5-retrospective` is `optional` in sprint-status. **Decide and record** (Q2): default disposition — capture 2–3 binding Epic-19.5 lessons inline in this close-out (ADR-first-on-a-fragility-class paid off; HW-investigation-ran-ahead-of-its-story is a cadence signal; DIV-1 = "never trust a port readback the docstring never HW-verified") per the solo-dev ceremony-diminishing-returns calibration ([[feedback_ceremony_diminishing_returns]]), and leave the formal `epic-19-5-retrospective` row `optional` (run only if Ant wants the full ceremony). Update the Phase-4-scope memory (`project_phase4_scope.md`) `description` + Epic-19.5 bullet → `antforth 3.0.4 SHIPPED 2026-06-NN (Epic 19.5 close)`, cumulative ~+119 B reconciled, HW ledger complete, debt anchors discharged, DR-1 abolition → Epic 20.

**And AC10 (tag applied — v3.0.4 + epic close).** After CR-pass + explicit user authorization: `git tag v3.0.4` on the close-out commit; sprint-status `19-5-4-...` → `done` and `epic-19-5` → `done` in the same close-out edit. **Pre-tag check:** `git tag` shows `v3.0.1`/`v3.0.2`/`v3.0.3` all present (the 19.4 tag-contiguity reconciliation is resolved) — `v3.0.4` is a clean new tag, no reconciliation needed; verify no `v3.0.4` pre-exists. Commit + tag + push are outward-facing — do NOT execute during the dev-pass; provide the recipe in the closing chat message and wait for Ant's "check in and tag" authorization (the 19.4 precedent). **No Claude co-author trailer** ([[feedback_no_claude_coauthor]], STRONG).

**FRs covered:** none directly (close-out + integration record of the Epic-19.5 verified stabilization). **NFRs codified:** NFR-P4-3 (cross-bank-overhead re-baseline — AC4); NFR-P4-5 (envelope reconciliation — AC3); NFR-P4-10 (974-baseline regression guarantee — AC2 surface 1); NFR-P4-11 / NFR-P4-36 (S9 hardware smoke — AC1 ledger, already discharged); NFR-P4-21 (epic-level decoupling — antforth 3.0.4 ships); NFR-P4-38 (S11 version surface — AC5).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → **26953 B** confirmed (clean `make clean && make` rebuild of HEAD `b4cc093`).
- [x] Capture three-surface baselines and record actuals: `test-repl` **975/0/2** · `test-repl-banking` **63/0/3** · `-isolated` 19-2 **6** · `-isolated-19-3` **15** · `-isolated-19-4` **2** · `-isolated-19-5-1` **2** · `test-repl-banking-skip` **25/0/3** · `test-straddle-regression` **3/3** · `check-doc-sync` **0 drift / 31 advisory** — all match expected.
- [x] Re-validate AC5 version-surface citations against source-of-truth (B.4): banner `src/antforth.asm:813` = `v3.0.3` ✓; README `:14/:24/:29/:32`; Makefile test-80 assertion `:1689` = `grep 'AntForth v3.0.3'` ✓; memory `description`. Sweep `grep -rn 'v3.0.3\|3.0.3' src/ Makefile README.md` → no FIFTH uncited surface.
- [x] Re-read the HW ledger source-of-truth before transcribing AC1: `sprint-status.yaml:534..580` + four transcript filenames re-read; figures re-validated (B.4 / PD-2).
- [x] Re-derive the Epic-19.5 cumulative delta (AC3) via clean rebuilds: Epic-19-close baseline (**26834 B** rebuilt at tag `v3.0.3` in a throwaway worktree) vs HEAD (**26953 B**) = **+119 B**.

### Q-dispositions (resolve at dev-pass start via AskUserQuestion BEFORE any edit)

- [x] **Q1 — Envelope-reconciliation record granularity (AC3). RESOLVED α (Ant, 2026-06-08):** append a short Epic-19.5 envelope note to the existing `sprint-change-proposal-2026-06-04.md` (the Epic-19 SCP that already set the ~2.4× realistic-pattern precedent), cross-referenced from Dev Notes. (Rejected β: a dedicated new SCP file — avoid SCP proliferation per ceremony-diminishing-returns.)
- [x] **Q2 — Epic-19.5 retrospective disposition (AC9). RESOLVED β (Ant, 2026-06-08):** run the formal `bmad-bmm-retrospective` for the full Epic-19.5 retro (substantive ADR-first 5-story interlude — Ant wants the formal lessons artifact). `epic-19-5-retrospective` row advances to `done` (not left `optional`). (Rejected α: inline-lessons-only.)
- [x] **Q3 — v3.0.4 banner-confirm HW smoke (AC2 surface 3). RESOLVED α (Ant, 2026-06-08):** NO new HW smoke — ledger complete; only the same-length banner changed (0 B, no behavioural delta). Close message states "no new deferred HW smoke for 19.5.4" per [[feedback_post_hw_smoke_steps_at_review]]. (Rejected β: belt-and-braces banner-confirm smoke.)

### Story tasks

- [x] **Task 1 — HW investigation ledger transcription (AC: #1)**
  - [x] Sub-1.1 A1 (PASS/HANG/GUARD) + A2 + A3 + DIV-1 (found/fixed/verified) + F1/F2 silicon confirmation transcribed into Dev Agent Record → Completion Notes (workflow restricts Dev-Notes edits) as the formal Epic-19.5 HW record, citing the four transcripts + `sprint-status.yaml:534..580`; each figure re-validated (B.4)
  - [x] Sub-1.2 ADR named-assumptions `:303..313` cross-referenced — A1/A2/A3 all CONFIRMED/resolved; DIV-1 noted as the divergence NOT in the ADR assumption list, standing memory `project_div1_mmu_port_readback`

- [x] **Task 2 — Three-surface re-sweep (AC: #2)**
  - [x] Sub-2.1 All three surfaces re-swept green (no flat test-643 trip; no banking-probe trip)
  - [x] Sub-2.2 HW surface: ledger COMPLETE; "no new deferred HW smoke for 19.5.4" stated in close message (Q3=α; `feedback_post_hw_smoke_steps_at_review` STRONG)
  - [x] Sub-2.3 No surface forced a kernel fix → nothing added to AC3 envelope

- [x] **Task 3 — Envelope reconciliation (AC: #3)**
  - [x] Sub-3.1 Cumulative **+119 B** re-derived via clean rebuilds (Epic-19-close 26834 @ tag v3.0.3 → HEAD 26953); reconciliation addendum written to `sprint-change-proposal-2026-06-04.md` (Q1-α); verdict logged (DIV-1 +13 B unbudgeted-correctness carve-out → ~106 B; ~2.4× realistic-pattern → ~240-270 B band; NFR-P4-5 8 KB cap unaffected)

- [x] **Task 4 — NFR-P4-3 re-baseline codification (AC: #4)**
  - [x] Sub-4.1 `epics-phase4-epics-16-22.md:107` updated to "≤ 400 T + MMU port write, RST-entry → target CF" with append-only ADR-19.5-citing SUPERSEDED-note; ≈343 T-vs-≈420 T-shipped-EXECUTE rationale recorded
  - [x] Sub-4.2 `make check-doc-sync` 0 drift after edit ("Epic 19.5"/"ADR 19.5" phrasing, no `Story 19.5.N` token)

- [x] **Task 5 — Version surface → 3.0.4 (AC: #5)**
  - [x] Sub-5.1 `src/antforth.asm:813` banner `v3.0.3` → `v3.0.4` (same-length; 0 B confirmed via clean rebuild 26953 unchanged + `strings`); version-trajectory comment extended with the v3.0.3 → v3.0.4 Epic-19.5-close line
  - [x] Sub-5.2 `README.md` refs → 3.0.4 (heading :14; :29 forward-reference resolved to "delivered in 3.0.4"; supports-line :32; new 3.0.4 version-history paragraph)
  - [x] Sub-5.3 `Makefile:1689..1692` test-80 banner assertion `v3.0.3` → `v3.0.4` — `test-repl` test 80 PASS confirmed
  - [x] Sub-5.4 B.4 sweep — no fifth uncited surface

- [x] **Task 6 — Verdict-table walk + check-doc-sync (AC: #6)**
  - [x] Sub-6.1 5-row Epic-19.5 verdict table in Completion Notes (19.5.0–19.5.3 + this close-out) with one-line evidence + byte deltas
  - [x] Sub-6.2 `make check-doc-sync` 0 drift / 31 advisory after all doc edits

- [x] **Task 7 — CCD-4 stub-count metric (AC: #7)**
  - [x] Sub-7.1 Boot-time stub metric **0/461** (COLD seeds tail=base $D4CB; 4 B stride; 461-stub cap) — unchanged vs Story 19.4 (no static pre-alloc in Epic 19.5); inside redesign-§7 envelope

- [x] **Task 8 — Debt-anchor discharge in architecture/redesign (AC: #8)**
  - [x] Sub-8.1 Consolidated append-only (a)–(f) discharge status block added to `architecture.md`; (c) marked "contained by F1 `-273`, not abolished; Epic 20 owns abolition"; five-vs-six count reconciled ((c)+(d) = one portal-aliasing/MMU-readback family). Redesign §2.1/§2.2/§3 already carry the Epic-19.5 dispatch-mechanism status appends.
  - [x] Sub-8.2 Redesign §5.4/§5.5 confirmed already fence FR-P4-26 / DR-1 residuals (no rewrite); `check-doc-sync` 0 drift ("Epic 19.5 …" phrasing)

- [x] **Task 9 — Retro disposition + memory update (AC: #9)**
  - [x] Sub-9.1 Q2=β recorded; inline lessons captured (as seed) in Completion Notes; the formal `bmad-bmm-retrospective` is a gated post-tag epic ceremony — `epic-19-5-retrospective` stays `optional` until that ceremony runs and marks it `done` (flagged in close message)
  - [x] Sub-9.2 `project_phase4_scope.md` memory `description` + Epic-19.5 bullet updated → 3.0.4 close-out dev-passed → review (cumulative +119 B reconciled; HW ledger complete; debt anchors discharged; DR-1 abolition → Epic 20; tag + formal retro pending authorization)

- [x] **Task 10 — Tag + epic close (AC: #10)** [outward-facing — recipe-only at dev-pass; execute on Ant's authorization after CR]
  - [x] Sub-10.1 Verified no `v3.0.4` pre-exists (`git tag` = v3.0.1/v3.0.2/v3.0.3 only); close-out commit + `git tag v3.0.4` + push recipe provided in the closing chat message
  - [~] Sub-10.2 `v3.0.4` tag intentionally HELD (Ant decision): the banking→BIOS MBB pivot + comment-debloat interlude landed on top of the close-out commit (5abfbc5) and the pivot's Phase C is still outstanding, so tagging is deferred until that work completes (target tag then rolls forward, e.g. v3.0.5). Close-out commit shipped at 5abfbc5; epic stories all `done`.

- [x] **Task 11 — Sprint-status transitions (sprint-status.yaml)**
  - [x] Sub-11.1 `19-5-4-...` `ready-for-dev` → `in-progress` at dev-pass start
  - [x] Sub-11.2 `19-5-4-...` `in-progress` → `review` at dev-pass close
  - [x] Sub-11.3 `19-5-4-...` → `done`, `19-5-0-...` → `done` (stranded review closed), `epic-19-5` → `done`; `v3.0.4` tag held per Sub-10.2

## Dev Notes

### Why this story exists (context)

Epic 19.5 is the ADR-first stabilization interlude inserted between Epic 19 and Epic 20 (the Epic-11.5 / 13.5 precedent for interlude epics — [[feedback_stabilisation_interlude]]). It owns the cross-bank-dispatch architectural debt that Epic 19 shipped *around*: Epic 19 delivered the verified bank-aware compiler **mechanism** but could only dispatch banked words via explicit `' WORD EXECUTE`, because `NEXT`'s blind `JP (HL)` ran garbage on a banked word's descriptor-stub thread cell. Story 19.5.0's ADR spike root-caused the "trampoline layout fragility" as **portal-window dictionary aliasing** (DR-1) and chose **option C** (DR-2: self-dispatching `RST $28` stub + 2-cell frame + fixed-memory return thunk). Stories 19.5.1–19.5.3 landed and verified it: F1 portal-aliasing `BANK!` guard + F2 bank-N HERE COLD-init (19.5.1); the RST-stub dispatch rework + CR-F1 CATCH triple restore (19.5.2); and compiled-body + full-NFR-P4-8 verification (19.5.3). **Story 19.5.4 closes the epic** — it records the HW evidence, re-sweeps, reconciles the envelope, codifies the NFR-P4-3 re-baseline, discharges the debt anchors, and ships antforth 3.0.4.

### The interleave — HW investigation ran AHEAD of this story (read first)

The epic plan (epics:890) assigned the HW investigation (A1/A2/A3 + the three-surface sweep) to **19.5.4**. It actually ran during **19.5.2's** hardware smoke (2026-06-06), because that smoke is where the silicon behaviour first became observable. During it: A1/A2/A3 were all resolved AND a NEW divergence — **DIV-1** (MMU port readback floats on real HW) — was found, fixed (1bab95a, +13 B), and HW-verified (1e2c44e). So by the time 19.5.4 is dev-passed, its headline deliverable (the HW ledger) is **already COMPLETE** (sprint-status.yaml:534..580). This is a cadence signal worth a retro lesson (AC9): HW investigation gravitates to the first story whose smoke exposes the behaviour, not the story the plan names. Consequences for 19.5.4: (i) AC1 is **transcription**, not investigation; (ii) the baseline is 26953 B (post-DIV-1); (iii) the epic envelope already absorbed the +13 B DIV-1 fix → carry it in the AC3 reconciliation.

### Hardware ledger — source-of-truth to transcribe (AC1)

Re-read `sprint-status.yaml:534..580` at dev-pass (PD-2 — that block is the authoritative ledger, written as the UAT ran). Transcripts (in `~/Downloads/`): `beastty-20260606-112043.bin` (A2 + cross-bank DOCOL dispatch + CR-F1 on silicon), `-113348.bin` (A1 PASS/HANG configs), `-120930.bin` (DIV-1 diagnostic, 4 sessions — open-bus self-opcode echo confirmed), `-122352.bin` (DIV-1 fix before/after: 4E/4E old → 5C/5A new). The DIV-1 root cause + fix is codified in [[project_div1_mmu_port_readback]] (never restore slot mappings from `IN 0x70-0x73`; `$4E`/`$7E` opcode-echo = unmapped-slot signature). A1-GUARD config validity: it was INVALID pre-fix (died -13 with a 10×`$7E` garbage token at the first window-resident WORD parse) and CLOSED post-fix (STRADG → -273 as predicted) — this is the load-bearing "DIV-1 fix closes A1-GUARD" link.

### Epic-19.5 binary trajectory (re-derive at dev-pass per B.3)

| Story | Δ | Close size | Note |
|---|---|---|---|
| (Epic-19.5 start = Epic-19 close) | — | 26834 B | Story 19.4 CR post-fix |
| 19.5.0 | 0 B | 26834 B | ADR spike (zero binary delta) |
| 19.5.1 | +65 B | ~26899 B | F1 guard + F2 COLD-init + F3 slot (eda591f) |
| 19.5.2 | +~42 B | ~26940 B | RST-stub option C + CR-F1 (bddda48; epic-cum 107 B at this point) |
| DIV-1 fix | +13 B | 26953 B | MMU-readback correctness fix (1bab95a — unbudgeted) |
| 19.5.3 | 0 B | 26953 B | compiled-body + NFR-P4-8 verification (test/doc only) |
| **Epic-19.5 total** | **≈ +119 B** | **26953 B** | **~19 B over ~100 B ADR upper guidance → AC3 accept-with-rationale** |

Story 19.5.4 itself is **0 B kernel** (banner same-length; README/memory/epics-doc are docs; Makefile assertion is test-infra). Re-derive every figure via clean rebuild — do NOT inherit these (the 19.4 dev-pass figures were CR-corrected by ±2..36 B; B.3 / Lesson 13.5-F).

### NFR-P4-3 re-baseline rationale (AC4)

The original NFR-P4-3 (≤ 60 T + bank-switch, epics:107) was **already unmet by the shipped Epic-18 EXECUTE path** (≈420 T per-opcode) when it was codified — so it was an aspirational paper number, not a met constraint. Option C's dispatch costs ≈343 T (ADR `:228` per-opcode table) — it *improves* on shipped reality while still exceeding 60 T. Per [[feedback_no_accept_disposition_for_bugs]] this is surfaced as an explicit re-baseline decision, not silently accepted: NFR-P4-3 → "cross-bank dispatch ≤ 400 T + MMU port write, measured RST-entry → target CF", ADR per-opcode table = source of truth. Sign-off rode with the ADR's acceptance (Ant 2026-06-04, ADR `:3`, "includes the NFR-P4-3 re-baseline rider"). 19.5.4 only **codifies** the already-accepted rider into the epics doc — it is not re-opening the decision. The ≤60 T target was unachievable with a 2-cell frame + MMU lookup on a Z80 (ADR `:296..297`).

### Five-vs-six debt-anchor count (AC8 honesty note)

The 19.4 carry-forward (AC8 there) listed **six** anchors: (a) DTC threading, (b) non-DOCOL trampoline, (c) sentinel-trampoline layout-fragility, (d) intra-bank-EXECUTE-into-slot-2 HW gap, (e) CATCH-cross-bank reboot, (f) bank-N HERE COLD-init (H5). The epic summary (epics:902) says Epic 19.5 "discharges all **five** Epic-19 architectural-debt anchors." The reconciliation: (c) and (d) collapse into one — the ADR proved both were the **portal-window-aliasing / MMU-readback-float family** (DR-1 + DIV-1), not two independent defects. So six surface anchors → five root families. Record this so the count reads honestly and neither number looks like an error. Note (c)'s residual: "contained by F1 (`-273`), not abolished — abolition (bank-aware FIND / per-wordlist bank field) is Epic 20, redesign §5.5."

### Q-dispositions (defaults adopted unless Ant overrides at dev-pass start)

- **Q1 — envelope record granularity.** Default α: append an Epic-19.5 note to the existing `sprint-change-proposal-2026-06-04.md`; do not spawn a new SCP (small overage, already-precedented pattern).
- **Q2 — retrospective.** Default α: inline lessons in this close-out; `epic-19-5-retrospective` stays `optional`. β = run the formal `bmad-bmm-retrospective` (substantive interlude — Ant's call).
- **Q3 — v3.0.4 banner HW smoke.** Default α: none (0 B same-length banner; ledger complete). β = belt-and-braces banner-confirm smoke (recipe on request).

### Constraints and guardrails

- **Close-out, not feature.** Default 0 B kernel + doc/version/test-infra changes only. A kernel edit requires a real surfaced regression in the AC2 re-sweep (then surface-file-fix per [[feedback_no_preexisting_discharge]], B.2-itemise, carry to AC3). Do NOT "improve" the 19.5.2 dispatch / CATCH code opportunistically — the epic is already ~19 B over the ADR guidance.
- **NEXT untouchable.** `src/macros.asm:32..47` stays byte-for-byte (NFR-P4-1 — option C rests on it).
- **DR-1 / FR-P4-26 are real limits, not bugs to beat.** Cross-bank-from-bank-N bodies, cross-bank DOES> bodies, cross-bank pointer reads are F1-guarded documented hazards; Epic 20 owns the abolition (redesign §5.5). AC8 marks them "contained", not "fixed".
- **Layout-shift discipline.** AC5's banner edit is same-length (no dictionary shift). If any test trips: straddle-harness diagnosis ([[feedback_iz_cpm_trampoline_fragility]] SUPERSEDED — no trampoline/emulator framing); flat test-643 NOP slot only if 643 itself trips ([[feedback_iz_cpm_test_643_quirk]]); F1/F2/F3 untouched, F3 straddle-regression stays 3/3.
- **Version-surface completeness (B.4).** Sweep `grep -rn 'v3.0.3\|3\.0\.3' src/ Makefile README.md` — the 19.4 close found a FOURTH surface (Makefile test-80 assertion) that the AC list missed; do the full sweep, not just the enumerated cites.
- **doc-sync `[story-cite]` gotcha.** Appending the literal token `Story 19.5.N` to a doc-sync-checked file raises drift (requires a matching `### Story 19.5.N:` epics header) — use "Epic 19.5 ..." phrasing as 19.5.3 did (`tools/check-doc-sync/check-doc-sync.sh:197`).
- **REPL probe hygiene.** Lines ≤ 128 chars ([[feedback_tib_size_inline_comments]]); isolated fixtures only for bank-switching ([[feedback_phase4_probe_bank_switch_limitation]], [[feedback_repl_tests_preferred]]). No new probes expected (verification done in 19.5.3); if a re-sweep needs one, isolated + kernel-words-only.
- **Solo-dev calibration** ([[feedback_ceremony_diminishing_returns]]): close-out surface is version strings + doc status appends + Dev Notes ledger/verdict-table + tag. Match the 19.4 house-style; do not build new tooling.
- **No Claude co-author trailer** on commits ([[feedback_no_claude_coauthor]], STRONG). CR runs separately after dev-pass close (the `CR` command, fresh context — not a story AC; do NOT enumerate adversarial review in ACs).
- **Outward-facing actions gated.** Commit / tag / push are NOT executed during the dev-pass — recipe in the closing chat message, executed only on Ant's explicit authorization (the 19.4 precedent).

### Previous-story intelligence (19.5.3, done 2026-06-07)

- **0 B verification story; mechanism proven behaviourally.** Compiled-body north-star (`probe-19.5.3-ac2/ac3`) + full NFR-P4-8 banked-CATCH (`probe-19.5.3-ac6`) all PASS; Probe-19.3-F/G re-enabled as live PASS. Binary unchanged at 26953 B. So nothing new to verify in 19.5.4 — re-sweep confirms steady-state.
- **doc-sync `[story-cite]` gotcha is real and recent** — 19.5.3 hit it appending `Story 19.5.3` to architecture.md (1 drift); reworded to "Epic 19.5 compiled-body verification pass". Apply the same discipline to AC4/AC8 edits.
- **Bank-N words are NOT FIND-able by name from bank 0** (Epic-20 scope) — 19.5.3's pre-flight confirmed the shared-bucket update is skipped for `current_bank>0` (`src/compiler.asm:359..396`, `src/dictionary.asm:114..208`). This is the DR-1-family residual AC8 marks "contained, owning fix Epic 20".
- **Test surface counts at 19.5.3 close:** test-repl 975/0 · banking 63/0 · isolated-19-3 **15 PASS** (was 13+2DEFER pre-19.5.3) · isolated 6/0 · 19-4 2/0 · 19-5-1 2/0 · skip 25/3 · straddle 3/3 · doc-sync 0 drift/31 advisory. These are the AC2 expected baselines.

### Git intelligence

Recent commits: `b4cc093` (19.5.3 → done — current HEAD, 26953 B), `9571941` (19.5.3 dev-pass + CR), `1e2c44e` (DIV-1 fix HW-verified — HW ledger complete), `1bab95a` (DIV-1 fix +13 B), `2fb448b` (19.5.4 HW UAT evidence anchor). Patterns to follow: close-out commits align banner/README/memory + record verdict-table + tag; commit messages name the story + byte delta; CR runs separately post-dev-pass; **no Claude co-author trailer** (STRONG). v3.0.3 was the Epic-19 close (Story 19.4, commit chain ending the epic); v3.0.1/2/3 tags all present (tag-contiguity resolved at 19.4) — v3.0.4 is a clean new tag. This story commits as a small docs+version diff with a "Epic 19.5 close-out; antforth 3.0.4; HW ledger + envelope reconciled; 0 B kernel" style message.

### Web research

N/A — Z80/CP/M kernel, zero external dependencies. RST-vector + dispatch semantics + the HW divergence (DIV-1 MMU-port readback) were verified against the live iz-cpm-banking emulator and the completed real-MicroBeast HW UAT (2026-06-06), not web sources.

### Project Structure Notes

- **Source (version surface, 0 B):** `src/antforth.asm:813` (banner same-length swap) + version-trajectory comment.
- **Docs/version:** `README.md` (version refs → 3.0.4; resolve the :29 forward-reference), `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:107` (NFR-P4-3 re-baseline text), `architecture.md` + `docs/antforth-banking-redesign.md` (debt-anchor discharge status, append-only).
- **Test-infra:** `Makefile:1689..1692` (REPL test-80 banner assertion → v3.0.4).
- **Records:** `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md` (Q1-α envelope note) OR a new SCP (Q1-β); `_bmad-output/implementation-artifacts/sprint-status.yaml` (19.5.4 transitions + epic-19-5 → done); `project_phase4_scope.md` (memory — antforth 3.0.4 SHIPPED).
- **Kernel:** none expected. If a re-sweep forces a fix: the relevant file per the surfaced defect, B.2-itemised, `src/macros.asm` excluded (NFR-P4-1).
- After this ships, Epic 19.5 is `done`; the next work is **Epic 20** (cross-bank dispatch *abolition* — per-wordlist bank field / bank-aware FIND; owns the DR-1 residual).

### References

- Epic line + envelope: `epics-phase4-epics-16-22.md:890` (Story 19.5.4), `:902` (Epic 19.5 summary + ~+30..+100 B envelope + debt-anchor-discharge claim), `:107` (NFR-P4-3 — re-baseline target), `:115` (NFR-P4-8), `:134` (NFR-P4-21), `:157` (NFR-P4-38 / S11), `:871` (Epic-19 close-out reframing + the six debt anchors).
- ADR: `docs/adr-19-5-cross-bank-dispatch.md:3` (acceptance + NFR-P4-3 rider sign-off), `:228` (per-opcode T-state table — NFR-P4-3 source of truth), `:287..297` (NFR-P4-3 re-baseline proposal), `:303..313` (A1/A2/A3 named assumptions).
- HW ledger: `_bmad-output/implementation-artifacts/sprint-status.yaml:534..580` (the authoritative UAT evidence block); transcripts `~/Downloads/beastty-20260606-112043/-113348/-120930/-122352.bin`.
- Close-out precedent: `_bmad-output/implementation-artifacts/19-4-epic-19-close-out-antforth-3-x-3-tag.md` (version surface + verdict-table + CCD-4 + envelope SCP + tag — the structural template; B.4 fourth-surface catch).
- Predecessor artifacts: `19-5-2-...md` (mechanism + CR-F1 + DIV-1), `19-5-3-...md` (compiled-body + NFR-P4-8 verification, 0 B; doc-sync gotcha).
- Version surface: `src/antforth.asm:813` (banner), `README.md:14/24/29/32`, `Makefile:1689..1692` (test-80 assertion).
- Redesign fences: `docs/antforth-banking-redesign.md` §5.4 (cross-bank pointer hazard / FR-P4-26), §5.5 (bank-aware FIND / Epic-20 owning fix / DR-1 abolition), §2.1/§3 (dispatch mechanism status).
- Memories: [[project_div1_mmu_port_readback]] (DIV-1 root cause + fix — AC1) · [[project_phase4_scope.md]] (Phase-4 scope; Epic 19.5 closing via 3.0.4 — AC9 memory update) · [[project_epic17_envelope]] (2.4–2.7× realistic-envelope pattern — AC3) · [[feedback_no_accept_disposition_for_bugs]] (DIV-1 / NFR-P4-3 surfaced as decisions, not silent accepts) · [[feedback_no_preexisting_discharge]] (surface-file-fix if the re-sweep exposes a defect) · [[feedback_post_hw_smoke_steps_at_review]] (STRONG — close-message HW statement) · [[feedback_iz_cpm_trampoline_fragility]] (SUPERSEDED — DR-1 framing) · [[feedback_iz_cpm_test_643_quirk]] · [[feedback_cpm_0x1a_eof_marker]] · [[feedback_plain_qa_language]] (envelope reporting) · [[feedback_ceremony_diminishing_returns]] (retro / SCP granularity) · [[feedback_stabilisation_interlude]] (Epic 19.5 as interlude) · [[feedback_no_claude_coauthor]] (STRONG).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — dev-story workflow, 2026-06-08.

### Debug Log References

- Clean rebuild baseline at HEAD `b4cc093`: `make clean && make` → `wc -c build/antforth.com` = **26953 B** (matches story-expected).
- Epic-19-close baseline re-derived via throwaway worktree at tag `v3.0.3` (commit `94c2ba0`): clean rebuild = **26834 B** → cumulative Epic-19.5 delta = **26953 − 26834 = +119 B** (AC3, re-derived not inherited).
- Post-edit clean rebuild after banner `v3.0.3 → v3.0.4` swap: **26953 B unchanged** → 0 B kernel confirmed (same-length string). `strings build/antforth.com` shows `AntForth v3.0.4 (C) ant.org 2026`.
- Version-surface sweep `grep -rn 'v3.0.3\|3.0.3' src/ Makefile README.md`: post-edit residuals are all legitimate version-history (trajectory comment `antforth.asm:811`, README history sentences at `:24`/`:27`) — no stale active version marker. No FIFTH uncited surface beyond AC5's enumeration.
- `make check-doc-sync` after all AC4/AC5/AC8 doc edits: **0 drift / 31 advisory** (baseline preserved; avoided the `Story 19.5.N` `[story-cite]` token by using "Epic 19.5 …" phrasing per the 19.5.3 gotcha).
- Flat `test-repl` test 80 post-edit: `PASS: REPL test 80 — Banner version string: output contains 'AntForth v3.0.4'`.

### Completion Notes List

**Story posture confirmed:** 0-byte-kernel Epic-19.5 close-out. The HW investigation assigned to this story had already run during 19.5.2's smoke (2026-06-06); AC1 is therefore *transcription* of a complete ledger, not fresh investigation. The AC2 three-surface re-sweep forced **no** kernel fix → no addition to the envelope.

**AC1 — Hardware investigation ledger (formal record).** Transcribed from `sprint-status.yaml:534..580` (source-of-truth) + transcripts `beastty-20260606-112043 / -113348 / -120930 / -122352.bin`:
- **A1 (straddle reproducer):** PASS config ✓ (m1..m5+ survived; calibration 27196 exact). HANG config ✓ (m1..m3 then crash-restart — DR-1 "dies identically" **CONFIRMED on silicon**). GUARD config ✓ post-DIV-1-fix (STRADG → `27209/32813/32900/[m1]/error -273` — F1 window-guard `-273` fires on real silicon as predicted; was INVALID pre-fix, died -13 with 10×`$7E` garbage token).
- **A2 (`$0028` RST-vector claimability):** DONE — `$28 C@ → C3` (live `JP`); dispatch vector installs cleanly, no re-vector; cross-bank DOCOL dispatch 42/0 on silicon.
- **A3 (Probe-19.2-F intra-bank-EXECUTE-into-slot-2):** ✓ — intra-bank EXECUTE into slot 2 → 7 (old 19.2-F hang shape **dead**); cross-bank DOVAR → 32796/bank 0. Was NOT a distinct defect — same DIV-1 readback-float family.
- **DIV-1 (NEW divergence, not an ADR-named assumption):** `IN A,(0x72)` MMU-slot readback returns open-bus self-opcode echo on real silicon (`$4E` = `C@`'s `LD C,(HL)`; `$7E` = `LD A,(HL)` on WORD/FIND read path) → restored slot-2 page UNMAPPED, retro-explaining the original Probe-19.2-F HW-only hang. Found (`-120930.bin`, 4 sessions), fixed (1bab95a: restore slot 2 from `active_pages[current_bank]` / leave candidate mapped, `IN (0x72)` retired; +13 B → 26953), HW-verified (1e2c44e; `-122352.bin`: old canary 4E/4E → new 5C/5A, window live unprimed). See `project_div1_mmu_port_readback`.
- **F1/F2 silicon:** F1 (`BANK!` window guard `-273`) confirmed via A1-GUARD; F2 (bank-table[1..28].here = `$8000` COLD) HW-verified (first-visit HERE = 32768/32800/27209).
- **ADR named-assumption cross-ref (Sub-1.2):** A1/A2/A3 = ADR `:303..313` → all CONFIRMED/resolved; DIV-1 is the divergence NOT in the ADR assumption list (standing memory `project_div1_mmu_port_readback`).
- **Verdict:** dispatch mechanism (option C) confirmed on real MicroBeast; A1/A2/A3 resolved; DIV-1 found/fixed/verified; **HW ledger COMPLETE**.

**AC2 — Three-surface re-sweep (v3.0.4 build), all green:** flat `test-repl` **975/0/2** · `test-repl-banking` **63/0/3** · `-isolated` (19-2) **6/0** · `-isolated-19-3` **15/0** · `-isolated-19-4` **2/0** · `-isolated-19-5-1` **2/0** · `test-repl-banking-skip` **25/0/3** · `test-straddle-regression` **3/3** · `check-doc-sync` **0 drift / 31 advisory**. Surface 3 (HW): ledger COMPLETE (AC1) — **no new deferred HW smoke for 19.5.4** (Q3=α; only the same-length banner changed since the ledger ran — 0 B, no behavioural delta).

**AC3 — Envelope reconciliation (accept-with-rationale):** cumulative **+119 B** (26834 → 26953, both clean-rebuild-derived). ADR guidance ~+30..+100 B → **~19 B over** the ~100 B upper bound. Rationale: (i) +13 B DIV-1 fix was an unbudgeted HW-only correctness fix (could not be declined per `feedback_no_accept_disposition_for_bugs`) — excluding it, ~106 B, within rounding; (ii) realistic Phase-4 envelope is ~2.4–2.7× spec (`project_epic17_envelope`) → ~240–270 B band, +119 B well inside; (iii) NFR-P4-5 8 KB cap unaffected. Recorded as an addendum to `sprint-change-proposal-2026-06-04.md` (Q1-α). No re-sweep kernel fix → nothing added.

**AC4 — NFR-P4-3 re-baseline codified:** `epics-phase4-epics-16-22.md:107` updated to "cross-bank dispatch ≤ 400 T + MMU port write, RST-entry → target CF", ADR `:228` per-opcode table (≈343 T) as source of truth, append-only SUPERSEDED-note preserving the original ≤60 T wording. Rationale (Dev Notes): the ≤60 T figure was already unmet by the shipped Epic-18 EXECUTE path (≈420 T) when codified; option C at ≈343 T *improves* shipped reality while exceeding the paper number; ≤60 T unachievable with a 2-cell frame + MMU lookup on Z80 (ADR `:296`). Sign-off rode with ADR acceptance (Ant 2026-06-04, ADR `:3`). doc-sync 0 drift after edit. (The redesign §7 budget-sketch table retains the design-phase "~60 T" figure as historical; the normative re-baseline lives in epics:107 + ADR — left unrewritten to stay in close-out scope.)

**AC5 — Version surface → 3.0.4:** banner `src/antforth.asm:813` (same-length, 0 B) + trajectory comment extended; `README.md` heading `:14`, forward-reference at `:29` resolved to "delivered in 3.0.4", supports-line `:32`, + new 3.0.4 history paragraph; `Makefile` test-80 assertion → `v3.0.4` (test 80 PASS). B.4 sweep found no fifth surface.

**AC6 — Verdict-table walk (Epic-19.5):**

| Story | Verdict | Δ | Evidence |
|---|---|---|---|
| 19.5.0 | done | 0 B | ADR spike — DR-1 portal-aliasing root cause + DR-2 option C locked (158641c) |
| 19.5.1 | done | +65 B | F1 `BANK!` window guard (`-273`) + F2 bank-N HERE COLD-init + F3 straddle slot (eda591f) |
| 19.5.2 | done | +~42 B core, +13 B DIV-1 | RST-$28 self-dispatch stub + CR-F1 caught-THROW triple restore + DIV-1 MMU-readback fix (bddda48 → 1bab95a) |
| 19.5.3 | done | 0 B | compiled-body north-star + full banked NFR-P4-8 verified; probe-19.3-F/G re-enabled live-PASS (b4cc093) |
| 19.5.4 | review | 0 B | this close-out — ledger + re-sweep + envelope + NFR-P4-3 + anchors + version surface + tag-recipe |

check-doc-sync 0 drift / 31 advisory after all doc edits.

**AC7 — CCD-4 stub-count metric:** boot-time banked-word descriptor-stub count = **0 / 461** (COLD seeds `stub_alloc_tail = STUB_ALLOC_BASE = $D4CB`; region `$D4CB..$DBFF` = 1845 B, 4 B/stub stride = 461-stub cap; `src/banking.asm:852..856`). Epic 19.5 added **no** static stub pre-allocation (dispatch-mechanism + verification epic) → unchanged vs the Story 19.4 baseline. Inside the redesign-§7 ~4–5 KB / 1000-words envelope.

**AC8 — Debt-anchor discharge:** consolidated append-only status block added to `architecture.md` (after the stub-layout-v2 / compiled-body verification notes) marking anchors (a)–(f) discharged; (c) marked "contained by F1 `-273`, not abolished; owning fix Epic 20"; five-vs-six count reconciled ((c)+(d) = one portal-window-aliasing / MMU-readback-float family). Redesign §5.4 (FR-P4-26 pointer hazard + F1 guard + F2) and §5.5 (DR-1 lookup-path aliasing INTERIM GOTCHA until Epic 20) confirmed already-fencing the residuals — no rewrite (Sub-8.2). doc-sync 0 drift.

**AC9 — Retro disposition + memory (Q2=β):** Ant chose **β — run the formal `bmad-bmm-retrospective`** for Epic 19.5. The formal retro is an epic-level ceremony that runs after the close-out commit + `v3.0.4` tag (its natural sequence — it marks `epic-19-5-retrospective` → done on completion). It is therefore flagged as a gated post-tag step alongside the tag itself, NOT run mid-dev-pass. Inline lessons captured here as a seed for the formal retro: (1) **ADR-first on a fragility class paid off** — root-causing DR-1 (portal-window aliasing, not trampoline fragility) before any code prevented a chase of the wrong defect; (2) **HW investigation gravitates to the first story whose smoke exposes the behaviour**, not the story the plan names (it ran at 19.5.2, planned for 19.5.4) — a cadence signal; (3) **"never trust a port readback whose docstring was never HW-verified"** (DIV-1: `IN 0x72` floated on silicon though the emulator implemented it). `project_phase4_scope.md` memory updated (description + Epic-19.5 bullet → 3.0.4 close-out dev-passed → review; +119 B reconciled; HW ledger complete; anchors discharged; DR-1 abolition → Epic 20; tag + formal retro pending authorization).

**AC10 / Task 10 — tag (outward-facing, gated):** `v3.0.4` does not pre-exist (`git tag` shows v3.0.1/v3.0.2/v3.0.3 only — tag-contiguity already resolved at 19.4). Commit + `git tag v3.0.4` + push + sprint-status `→ done` transitions are deferred to Ant's explicit authorization after the CR pass — recipe provided in the closing chat message. **No Claude co-author trailer.**

### File List

**Source (0 B kernel):**
- `src/antforth.asm` — banner string `v3.0.3 → v3.0.4` (same-length, 0 B) + version-trajectory comment extended with the Epic-19.5-close line.

**Docs / planning artifacts:**
- `README.md` — version heading → 3.0.4; `:29` forward-reference resolved to "delivered in 3.0.4"; supports-line → V3.0.4; new 3.0.4 version-history paragraph.
- `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` — NFR-P4-3 re-baseline (`:107`, append-only SUPERSEDED-note).
- `_bmad-output/planning-artifacts/architecture.md` — consolidated Epic-19 debt-anchor (a)–(f) discharge status block (append-only).
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md` — Epic-19.5 envelope-reconciliation addendum (Q1-α).

**Test-infra:**
- `Makefile` — REPL test-80 banner assertion `v3.0.3 → v3.0.4`.

**Tracking / records:**
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `19-5-4-…` `ready-for-dev → in-progress → review` (done + `epic-19-5 → done` deferred to post-authorization).
- `_bmad-output/implementation-artifacts/19-5-4-hw-investigation-epic-close-out-tag.md` — this story (Q-dispositions, task checkboxes, Dev Agent Record, Change Log, Status).
- `~/.claude/projects/-home-ant-src-microbeast-antforth/memory/project_phase4_scope.md` — memory update (description + Epic-19.5 bullet).

## Change Log

| Date | Change |
|---|---|
| 2026-06-08 | Story 19.5.4 dev-pass — Epic 19.5 close-out. Q-dispositions resolved (Q1-α, Q2-β, Q3-α). Version surface → 3.0.4 (banner 0 B + README + Makefile test-80). NFR-P4-3 re-baselined (≤400 T + MMU write, epics:107). Five Epic-19 debt anchors discharged (architecture.md). Envelope reconciled +119 B accept-with-rationale (SCP addendum). HW ledger (A1/A2/A3 + DIV-1 + F1/F2) transcribed. CCD-4 stub metric 0/461 boot. Nine surfaces re-swept green; doc-sync 0 drift. 0 B kernel (26953 B). Status → review. Commit + v3.0.4 tag + formal Epic-19.5 retro pending CR + Ant authorization. |
