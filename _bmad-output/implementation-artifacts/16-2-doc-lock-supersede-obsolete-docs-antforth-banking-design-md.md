# Story 16.2: Doc-lock — supersede obsolete `docs/antforth-banking-design.md`

Status: done

<!-- Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!--
Second story of Epic 16 (Phase-4 prework — memory map, emulator pick,
design lock), authored 2026-05-13 against `epics-phase4-epics-16-22.md`
(lastEdited 2026-05-10, §"Story 16.2"). Story 16.1 (CCP-eviction
hardware spike + Page-0..3 page-allocation survey) landed clean
2026-05-13 with verdict PASS — F3 closed; +2 KB Page-3 headroom
($D400–$DBFF) safe to consume in Epic 17+. The Phase-3 close-out
baseline holds: 974 PASS / 0 FAIL / 2 SKIP-on-iz-cpm-PASS-on-hardware
plus Lesson-14-F direct-commit test 968 (caught-form coverage probe,
direct-committed between Story 15.5 close and Story 16.1 start) →
current pre-edit expected baseline is **975 PASS / 0 FAIL / 2 SKIP**
on iz-cpm (re-`make test-repl` at dev-pass start to confirm). v2.0.0
tagged 2026-05-07 (commit 6599d73).

Story 16.2 is the second Phase-4 binary-delta-free story. Its job:
formalise the SUPERSEDED banner on `docs/antforth-banking-design.md`
so the obsolete 2026-05-07 sketch cannot be accidentally consumed by
dev-agents / downstream-Phase architects as the Phase-4 design source.
The redesign doc (`docs/antforth-banking-redesign.md`) is the single
source-of-truth for Phase-4 banking architecture, per redesign-doc
§1..§9 and per the epic-16 spec.

State of play at draft time (re-validated 2026-05-13 per B.4 / PD-2
discipline — figures grep'd / files cat'd directly, not transcribed
from prior story):

  (1) A `> **⚠️ SUPERSEDED 2026-05-09.**` block already exists at
      `docs/antforth-banking-design.md:3` (added incidentally in
      commit 51bc6d6, 2026-05-10, "update PRD"). The block is a
      single prose paragraph that names the redesign doc and lists
      `BIT 7,H` and `THUNK-TO-USER-BANK*` in prose. AC1 / AC2 ask
      for a banner *block* with explicit `(a)/(b)` enumeration of
      the two specific rejected elements. Dev-pass must restructure
      the existing paragraph to the enumerated form rather than
      append a second banner (single-source-of-truth at the top).

  (2) The AC5 mechanical grep verdict currently **FAILS as drafted**:
      `grep -l 'BIT 7,H' docs/*.md` returns TWO files
      (`docs/antforth-banking-design.md` AND
      `docs/antforth-banking-redesign.md`); same for
      `grep -l 'THUNK-TO-USER-BANK' docs/*.md`. The redesign doc at
      lines 26, 28, 46, 63 legitimately cites the obsolete tokens
      while explaining what it rejected. Dev-pass owns the
      decision under AC5(α) vs AC5(β) — see AC5 below for the
      fork. (Re-grep at dev-pass start to confirm the count has
      not drifted; B.4 / PD-2.)

  (3) **Carry-forward from Story 16.1 Task 1.4** —
      `make check-doc-sync` currently TOOL FATAL because the
      script (`tools/check-doc-sync/check-doc-sync.sh:56`)
      requires `_bmad-output/planning-artifacts/epics.md` which
      was deleted in commit 51bc6d6 (2026-05-10) when the canonical
      epic catalogue was split into per-phase files
      (`epics-phase1-*.md`, `epics-phase2-*.md`,
      `epics-phase3-epics-14-15.md`, `epics-phase4-epics-16-22.md`).
      AC8 ("`make check-doc-sync` clean-pass after the banner
      addition") cannot fire until the script is taught about the
      per-phase files. Story 16.1's Task 1.4 explicitly tagged
      Story 16.2 as the natural vehicle (memory
      `feedback_no_preexisting_discharge.md` — surface, file, fix;
      Story 16.2 is the "doc-lock" Phase-4 doc-bookkeeping vehicle,
      so the script fix is a natural prerequisite of AC8). Task 6
      below scopes the fix.

Zero binary delta is a hard AC of this story per AC6. S9
hardware-smoke (NFR-P4-11) is exempt with explicit rationale:
*"Zero binary delta — documentation-only changes."* Banner / tag /
README / `description`-field surface audit (NFR-P4-38 / S11) is
not in this story's scope (this is mid-epic, not a tag-applicable
close-out).
-->

## Story

As **any reader (dev-agent, downstream-Phase architect, future-Ant)** encountering the banking-design doc tree,
I want the obsolete 2026-05-07 sketch banner-marked SUPERSEDED with explicit `(a)/(b)` enumeration of its rejected elements and pointing unambiguously at `docs/antforth-banking-redesign.md`,
So that the broken `BIT 7,H` cross-bank-EXIT heuristic and the obsolete `THUNK-TO-USER-BANK*` family cannot be accidentally consumed as the Phase-4 design source — locking the redesign doc as the single source-of-truth (NFR-P4-20 reframed for design references) and clearing the path for Epic 17+ story-authoring against an unambiguous Phase-4 architecture anchor.

## Acceptance Criteria

1. **AC1 (SUPERSEDED banner block at top of `docs/antforth-banking-design.md`)** — a `> **SUPERSEDED 2026-05-09.**` banner block is the first content after the `# AntForth Banking Architecture for MicroBeast` title and before any other section. The banner names `docs/antforth-banking-redesign.md` (relative link) as the canonical Phase-4 design source. The existing single-paragraph SUPERSEDED block at `docs/antforth-banking-design.md:3` (added in commit `51bc6d6`, 2026-05-10) is **restructured in-place** — not duplicated — to satisfy AC1+AC2 form. *(Dev-pass note: re-read the current banner state with `head -10 docs/antforth-banking-design.md` at dev-pass start before editing, per B.4 / PD-2 — do not assume the draft-time observation still holds.)*

2. **AC2 (banner enumerates two specific rejected elements as `(a)/(b)`)** — the banner explicitly enumerates the two design elements rejected by the redesign:
   - **(a)** the `BIT 7,H` cross-bank-EXIT heuristic — *broken because user code at $8000–$BFFF always has bit 7 set on every return-address high byte, so the heuristic distinguishes nothing*. Cite redesign-doc §3 (or whichever § block carries the sentinel-trampoline replacement) for the replacement mechanism.
   - **(b)** the user-typed `THUNK-TO-USER-BANK*` family (`THUNK-TO-USER-BANK0` .. `THUNK-TO-USER-BANK10` in the original 11-bank sketch) — *replaced by per-word compiler-emitted descriptor stubs* (the **(γ)** mechanism per redesign §2.1 / §3). Cite redesign-doc §3 / FR-P4-13..17 for the replacement mechanism.
   The enumeration uses literal `(a)` / `(b)` markers (or a bulleted list of equivalent clarity) — not inline prose — so a reader can scan the rejected items in one glance.

3. **AC3 (file preserved otherwise unmodified — design-evolution traceability)** — `docs/antforth-banking-design.md` lines 5..196 (the original sketch body: "Problem Statement" through end-of-file) are preserved byte-identical. Only the banner block at the head of the file (lines 1..4 in the post-edit state) is touched. Verdict-criterion: `git diff docs/antforth-banking-design.md` after the AC1+AC2 edit shows changes only in the banner block; no edits to the sketch body. The file is retained for design-evolution traceability, **not deleted**.

4. **AC4 (cross-document reference audit — `architecture.md`, `prd.md`, `architecture-phase3-epics-14-15.md`)** — every cross-document reference to `docs/antforth-banking-design.md` in the three named files is audited and disposed:
   - **`architecture.md`** (verified at draft time 2026-05-13 — re-grep at dev-pass start): refs at `:417` (rationale citation — "the obsolete docs/antforth-banking-design.md"), `:682` (Files-SUPERSEDED status table row), `:713` (locked-source-of-truth callout — "superseded docs/antforth-banking-design.md (banner-marked)"), `:734` (Epic 16 row in deliverables table — "docs/antforth-banking-design.md SUPERSEDED banner"). All four are *correct as-is* (they legitimately point at the historical sketch); audit verifies; no edit required.
   - **`prd.md`** (verified at draft time): ref at `:406` (Architectural-anchor block — "supersedes docs/antforth-banking-design.md (2026-05-07 sketch with SUPERSEDED banner)"). Correct as-is; audit verifies; no edit required.
   - **`architecture-phase3-epics-14-15.md`** (verified at draft time): refs at `:10` (inputDocuments frontmatter list), `:74` (Hardware row — "banking design deferred to Phase 4"), `:156` (Phase-4 deferral note), `:626` (structures.asm row — "banking design deferred to Phase 4"), `:913` (strategic-enabler bullet). These are **Phase-3 archive doc** references written before the redesign existed. Phase-3 archives are conventionally treated as immutable historical snapshots (per the per-phase doc convention introduced in commit 51bc6d6); audit verifies they are historically accurate at Phase-3-close timestamp and leaves them unmodified. If dev-pass disagrees with the "immutable archive" convention for a specific row, the disagreement and per-row disposition is captured in this story's Dev Notes (no edit lands without explicit rationale per AC4 — "audited" not "rewritten"). *(Re-grep at dev-pass start per B.4 / PD-2.)*

   Out-of-AC4-scope references (verified at draft time, NOT in AC4's audit scope but noted for awareness — no edit obligated): `docs/WISHLIST.md:11` (one-line wishlist note pointing at the old doc — dev-pass may optionally update to point at the redesign doc as a one-character change since WISHLIST is a live doc, not an archive); `docs/antforth-banking-redesign.md:5` and `:7` (the redesign doc's own "Supersedes" preamble — correct as-is); `_bmad-output/planning-artifacts/product-brief-antforth-2026-05-08.md:237` and `:273` (dated product-brief archive — immutable); `_bmad-output/planning-artifacts/prd-phase3-epics-14-15.md:29` and `:202` and `:347` and `:443` (Phase-3 PRD archive — immutable per the same archive convention as architecture-phase3); `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:183` and `:248` and `:352` (the epic spec for this very story — references are legitimate "the obsolete sketch" historical citations).

5. **AC5 (verdict-criterion grep-able — single-source-of-truth for obsolete tokens)** — the mechanical grep verdict resolves under one of two forks (fork picked by dev-pass with explicit rationale):
   - **Fork (α) — strict mechanical grep, redesign-doc rephrased.** `grep -l 'BIT 7,H' docs/*.md` returns exactly one file (`docs/antforth-banking-design.md` itself — the banner and / or the original sketch body). `grep -l 'THUNK-TO-USER-BANK' docs/*.md` likewise. To achieve this, `docs/antforth-banking-redesign.md` lines 26 / 28 / 46 / 63 (verified at draft time — re-grep at dev-pass start) are rephrased to refer to the obsolete tokens without using the literal grep-able strings (e.g., "the obsolete bit-7-on-H heuristic", "the obsolete per-target-bank thunk family"). The rephrasing is restricted to citation context — the redesign doc's substantive replacement-mechanism description is unchanged.
   - **Fork (β) — AC5 relaxed; redesign doc's rejection-rationale paragraphs are explicitly excluded.** AC5 verdict is reframed as: *"`grep -l 'BIT 7,H' docs/*.md` returns at most two files — `docs/antforth-banking-design.md` (the obsolete sketch + its SUPERSEDED banner) and `docs/antforth-banking-redesign.md` (citing the obsolete tokens in §-rejection-rationale paragraphs); no other docs/*.md file matches. Same for `THUNK-TO-USER-BANK`."* Rationale: the redesign doc's explanatory citations are intentional reader-context, not drift; restricting them harms readability of the locked design source.
   The two forks are functionally equivalent for the "single source-of-truth" goal — both prevent third-party docs from accidentally consuming the obsolete tokens. Fork (β) is the lower-edit-blast-radius default; Fork (α) is preferred if dev-pass judges the rephrasing trivial. Dev-pass picks one; the picked fork's rationale lands in Dev Notes.

6. **AC6 (zero binary delta + S9 exempt)** — `wc -c build/antforth.com` reports **24,995 bytes** unchanged from the Phase-3 close-out baseline / Story 16.1 close-out (re-`wc -c` at dev-pass start to confirm — do not inherit per B.3 / Lesson 13.5-F). Story dev-pass produces **zero binary delta** (no `src/` edits). S9 hardware-smoke (NFR-P4-11) is **exempt** with explicit rationale: *"Zero binary delta — documentation-only changes."* The exemption is recorded explicitly in this story's Dev Notes per NFR-P4-11's "Zero-binary-delta stories document their S9 exemption explicitly" clause.

7. **AC7 (regression baseline preserved)** — `make test-repl` reports **≥ 975 PASS / 0 FAIL / 2 SKIP** on iz-cpm (Phase-3 close-out baseline preserved per FR-P4-41 / NFR-P4-10, plus Lesson-14-F direct-commit test 968 added between Story 15.5 close and Story 16.1 start — recount at dev-pass start to confirm). Zero regressions. This story adds no new tests (documentation-only).

8. **AC8 (`make check-doc-sync` (B.5) clean-pass after the doc edits)** — `make check-doc-sync` reports a clean exit (exit code 0) post-edit. *Two paths to AC8 satisfaction, depending on Task 6 outcome:*
   - **Path (i) — script fix lands in Task 6 (recommended).** `tools/check-doc-sync/check-doc-sync.sh` is updated (per Task 6) to consume the per-phase epic files (`epics-phase1-epics-1-8.md`, `epics-phase2-epics-9-13.5.md`, `epics-phase3-epics-14-15.md`, `epics-phase4-epics-16-22.md`) instead of the now-deleted `epics.md`. After the fix, `make check-doc-sync` runs end-to-end and reports `[ok] doc-sync: 0 drift` or `[advisory] doc-sync: N advisory item(s); 0 drift` (both are AC8-passing — advisory items are non-blocking per the script's verdict logic at `:272..280`).
   - **Path (ii) — script fix deferred via fork into Story 16.2.1.** If Task 6 surfaces unexpected scope (e.g., the per-phase file split breaks Check (b) story-citation resolution in a non-trivial way that requires its own design pass), Task 6 stops at the verdict-only-audit shape (memory `feedback_verdict_only_audit.md`), spawns Story 16.2.1 for the fix, and AC8 is documented as "fork → 16.2.1; this story's verdict is doc-lock-only" in this story's Dev Notes. Story 16.2 itself still closes (AC1..AC7 and AC4 audit are the doc-lock-only deliverable); AC8 hands off to 16.2.1. **Default expectation is Path (i)** — the fix shape (drop EPICS, add EPICS_P3 + EPICS_P4) is small per Task 6.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift)
- [x] Capture current `make test-repl` baseline pass count
- [x] Re-validate the three "state of play" observations from the draft-time header comment per B.4 / PD-2: (i) `head -10 docs/antforth-banking-design.md` (confirm `:3` banner shape unchanged); (ii) `grep -l 'BIT 7,H' docs/*.md` and `grep -l 'THUNK-TO-USER-BANK' docs/*.md` (confirm two-file return count unchanged); (iii) `bash tools/check-doc-sync/check-doc-sync.sh` (confirm still TOOL FATAL with the same `epics.md` missing-file message — Task 6 owns the fix).

### Story tasks

- [x] **Task 1 — Pre-edit baseline + state-of-play re-validation** (AC6, AC7)
  - [x] 1.1 — `wc -c build/antforth.com` direct measurement → record. Story 16.1 close-out reported 24,995 bytes; re-measure per B.3 (do not inherit). **Expected: 24,995 bytes.** → **Measured: 24,995 bytes ✓**
  - [x] 1.2 — `make test-repl 2>&1 | tee /tmp/16-2-pre-edit.out`; record `grep -c '^PASS:' /tmp/16-2-pre-edit.out`, `grep -c '^FAIL:' /tmp/16-2-pre-edit.out`, `grep -c '^SKIP:' /tmp/16-2-pre-edit.out`. **Expected: 975 PASS / 0 FAIL / 2 SKIP** (Phase-3 close-out baseline 974 + Lesson-14-F direct-commit test 968 = 975 post-Story-16.1). → **Measured: 975 PASS / 0 FAIL / 2 SKIP ✓**
  - [x] 1.3 — `head -10 docs/antforth-banking-design.md` → record the current banner text verbatim in Dev Notes. Confirm or correct the draft-time observation that the banner currently lives at `:3` as a single prose paragraph beginning `> **⚠️ SUPERSEDED 2026-05-09.**`. → **Confirmed: single-paragraph banner at `:3` ✓**
  - [x] 1.4 — `grep -l 'BIT 7,H' docs/*.md > /tmp/16-2-grep-bit7.out` and `grep -l 'THUNK-TO-USER-BANK' docs/*.md > /tmp/16-2-grep-thunk.out`; record the file list returned by each. **Expected at draft time:** both return `docs/antforth-banking-design.md` and `docs/antforth-banking-redesign.md`. If the count has changed since draft time, fold the change into AC5 fork selection. → **Measured: both greps return both files ✓**
  - [x] 1.5 — `bash tools/check-doc-sync/check-doc-sync.sh; echo "exit=$?"` → record the exit code and stderr. **Expected at draft time:** exit 1 with stderr `[fatal] required input file missing or unreadable: _bmad-output/planning-artifacts/epics.md`. If the script has been fixed since draft time (e.g., by another story), Task 6 becomes a verify-only pass. → **Measured: exit 1, same fatal message ✓ — Task 6 fix required.**

- [x] **Task 2 — Restructure the SUPERSEDED banner block** (AC1, AC2, AC3)
  - [x] 2.1 — Edit `docs/antforth-banking-design.md` line 3 (the existing `> **⚠️ SUPERSEDED 2026-05-09.**` block). Restructure from single-paragraph prose to an enumerated `(a)/(b)` form. Recommended shape (dev-pass may tighten / loosen wording — the load-bearing requirements are the AC1/AC2 form, not exact phrasing):
    ```markdown
    > **⚠️ SUPERSEDED 2026-05-09.** This document is the initial banking sketch (2026-05-07). The authoritative Phase-4 design is [`docs/antforth-banking-redesign.md`](antforth-banking-redesign.md) (locked 2026-05-09 in a `/bmad-party-mode` session). **Do not consult this document for current decisions.** Retained for historical traceability of design evolution.
    >
    > Two specific design elements from this sketch are rejected by the redesign:
    >
    > - **(a) The `BIT 7,H` cross-bank-EXIT heuristic** — broken: user code at `$8000`–`$BFFF` always has bit 7 set on every return-address high byte, so the heuristic distinguishes nothing. Replaced by sentinel-tagged 3-cell cross-bank return frames (see redesign-doc §3 / FR-P4-18..21).
    > - **(b) The user-typed `THUNK-TO-USER-BANK*` family** (e.g., `THUNK-TO-USER-BANK5`) — replaced by per-word compiler-emitted descriptor stubs (the **(γ)** mechanism per redesign §2.1 / §3 / FR-P4-13..17). Cross-bank calls are compiler-transparent; users do not type thunk words.
    ```
  - [x] 2.2 — Confirm no other lines of `docs/antforth-banking-design.md` are touched: `git diff docs/antforth-banking-design.md` shows changes only within the banner block at the head of the file. The original sketch body (currently lines 5..196) is byte-identical post-edit per AC3. → **Verified: single hunk `@@ -1,6 +1,11 @@` only; sketch body byte-identical, shifted only by banner expansion (1→6 lines).**
  - [x] 2.3 — Confirm the relative link `docs/antforth-banking-redesign.md` (or whatever the dev-pass writes — the AC1 form is `[name](antforth-banking-redesign.md)` since both files live in `docs/`) resolves cleanly when previewed in a markdown viewer (no broken-link drift). → **Link form: `[`docs/antforth-banking-redesign.md`](antforth-banking-redesign.md)`; both files in `docs/`, relative path resolves.**

- [x] **Task 3 — Cross-document reference audit** (AC4)
  - [x] 3.1 — Re-run the cross-doc grep at dev-pass start per B.4 / PD-2 (do not transcribe the draft-time line-numbers): `grep -n 'antforth-banking-design' _bmad-output/planning-artifacts/{architecture.md,prd.md,architecture-phase3-epics-14-15.md}` → record each hit's file:line and surrounding context (3-line `-B 1 -A 1` recommended). → **Grep output recorded in Debug Log References below; all 10 hits match the draft-time inventory at the documented line numbers — zero drift.**
  - [x] 3.2 — Per-row disposition. For each grep hit, decide one of:
    - **VERIFIED-LEAVE** — the reference legitimately points at the historical sketch (banner-marked SUPERSEDED status, rationale citation, archive-frozen Phase-3 context). No edit.
    - **UPDATE-TO-REDESIGN** — the reference should now point at `docs/antforth-banking-redesign.md`. One-line edit.
    - **AUDIT-DEFER** — disagree with the "immutable archive" convention for a specific Phase-3 archive row; per-row rationale captured in Dev Notes; possible future edit but not in this story.
    The disposition for every grep hit is recorded in this story's Dev Notes (one row per hit). The audit is "audited", not "rewritten" — the load-bearing AC4 verdict is *every-row dispositioned*, not *every-row edited*. → **All 10 rows: VERIFIED-LEAVE per draft-time inventory.** Four `architecture.md` rows (`:417`, `:682`, `:713`, `:734`) legitimately point at the historical sketch as the SUPERSEDED status / rationale-citation source. One `prd.md` row (`:406`) names the redesign doc as the supersession authority — citation of the obsolete name is intentional. Five `architecture-phase3-epics-14-15.md` rows (`:10`, `:74`, `:156`, `:626`, `:913`) are Phase-3 archive doc references; the "immutable historical snapshot" convention (implicit-by-precedent from commit 51bc6d6's per-phase split) is honoured — these rows were historically accurate at Phase-3-close timestamp and remain unmodified.
  - [x] 3.3 — If any disposition is **UPDATE-TO-REDESIGN**, apply the edit. Confirm `git diff` for the affected file shows the targeted edit only. → **No UPDATE-TO-REDESIGN dispositions; no edits applied to the three audited files.**
  - [x] 3.4 — **(Optional, out-of-AC4-scope)** Consider whether `docs/WISHLIST.md:11` (the live wishlist note pointing at the old doc) should update to the redesign doc. If yes (recommended — single-character path change, WISHLIST is a live doc not an archive), apply the edit and note in Dev Notes. If no, note in Dev Notes the rationale. This is dev-pass discretion; not load-bearing on AC4. → **YES applied.** WISHLIST is a live doc (not an archive) and a future-Ant reading it should land at the locked design source. Edited `docs/WISHLIST.md:11` to point at `docs/antforth-banking-redesign.md` with an explicit "the older sketch is SUPERSEDED" tail clause so readers see both files exist and which is canonical.

- [x] **Task 4 — AC5 fork selection + execution** (AC5)
  - [x] 4.1 — Pick AC5 fork (α) or (β) — see AC5 for the fork descriptions. Record the pick + rationale in Dev Notes. → **Picked: fork (β).** Rationale per Dev Notes §"AC5 fork-selection guidance": lower edit blast radius (zero edits to `docs/antforth-banking-redesign.md`); preserves the redesign doc's readability (rejection rationale is most precise when it cites the obsolete tokens by name); single-source-of-truth goal satisfied (no *third-party* doc carries the obsolete tokens — only the obsolete sketch itself and the redesign doc's intentional rejection-rationale paragraphs).
  - [x] 4.2 — **If fork (α) chosen:** (n/a — fork β picked).
  - [x] 4.3 — **If fork (β) chosen:** no redesign-doc edit. AC5 verdict is recorded in Dev Notes per the relaxed verdict-criterion language in AC5 fork (β). → **No redesign-doc edit applied.** AC5 fork (β) verdict: `grep -l 'BIT 7,H' docs/*.md` returns exactly two files (`docs/antforth-banking-design.md` + `docs/antforth-banking-redesign.md`); same for `THUNK-TO-USER-BANK`. No other `docs/*.md` file matches either grep. The redesign doc's hits are confined to its rejection-rationale paragraphs at §1 (`:26`, `:28`) and §2.2 / §3 (`:46`, `:63`), which are intentional explanatory context.
  - [x] 4.4 — Re-run the AC5 grep verdict: `grep -l 'BIT 7,H' docs/*.md` and `grep -l 'THUNK-TO-USER-BANK' docs/*.md`. Confirm the result matches the picked fork's expected outcome (one file under fork (α); two files under fork (β)). → **Verified: both greps return exactly 2 files (design.md + redesign.md); matches fork (β) expected outcome.**

- [x] **Task 5 — Zero-binary-delta + regression confirmation** (AC6, AC7)
  - [x] 5.1 — `git diff src/` → expect empty (no `src/` edits in this story). If non-empty, HALT — Story 16.2 has accidentally touched the kernel and the AC6 contract has been violated. → **Empty diff confirmed; AC6 contract intact.**
  - [x] 5.2 — `make` → confirm rebuild succeeds (sanity check; no `src/` edits means the build product cannot have changed, but a fresh build catches any incidental Makefile breakage). → **`make` → "Nothing to be done for 'all'"; build artifact up to date.**
  - [x] 5.3 — `wc -c build/antforth.com` → confirm **24,995 bytes** (Δ=0 vs. Task 1.1). If the byte count drifts from Task 1.1's measurement, HALT — something leaked in. → **24,995 bytes; Δ=0 ✓.**
  - [x] 5.4 — `make test-repl` → confirm **≥ 975 PASS / 0 FAIL / 2 SKIP** unchanged from Task 1.2. Zero regressions confirmed. → **975 PASS / 0 FAIL / 2 SKIP; identical to Task 1.2; zero regressions.**
  - [x] 5.5 — Record S9 hardware-smoke exemption in Dev Notes with the exact rationale phrase: *"Zero binary delta — documentation-only changes."* Per NFR-P4-11's explicit-exemption clause. → **Recorded in story §"S9 hardware-smoke exemption"; reasserted in Completion Notes.**

- [x] **Task 6 — Fix `check-doc-sync.sh` for the per-phase epic file split** (AC8 Path (i); carry-forward from Story 16.1 Task 1.4)
  - [x] 6.1 — Read `tools/check-doc-sync/check-doc-sync.sh:56..63` (or whatever the current line range is — re-read at dev-pass start). The current `EPICS` variable points at `_bmad-output/planning-artifacts/epics.md` which was deleted in commit 51bc6d6 (2026-05-10). The script also defines `EPICS_P1` and `EPICS_P2` for the Phase-1 and Phase-2 splits; Phase-3 (`epics-phase3-epics-14-15.md`) and Phase-4 (`epics-phase4-epics-16-22.md`) split files have not been added to the script. → **Re-read confirmed.** Variables at `:54..59`; existence-check loop at `:63`; awk EPICS_HEADERS at `:91..92`.
  - [x] 6.2 — Apply the minimum-scope fix:
    - Remove the `EPICS` variable definition and its entry in the existence-check loop at `:63..68` (drop the now-deleted `epics.md` requirement).
    - Add new variables `EPICS_P3="_bmad-output/planning-artifacts/epics-phase3-epics-14-15.md"` and `EPICS_P4="_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md"`. Include both in the existence-check loop.
    - Update the awk command at `:91..92` (the `$EPICS_HEADERS` builder) to walk `$EPICS_P1 $EPICS_P2 $EPICS_P3 $EPICS_P4` instead of `$EPICS $EPICS_P1 $EPICS_P2`. → **All three sub-edits applied;** plus the in-body comment block at `:175..179` (which mentioned only the old `epics.md` + first two phase files) was updated to name all four phase files for code-reading consistency.
  - [x] 6.3 — Update the script's header doc comment `:11..15` (the "Pinned by:" block) — the `epics.md:394..414` line in the pinned-by list references the deleted file. Either drop the line or rewrite it to cite the canonical Phase-3 split file the Story 14.5 ACs now live in (likely `epics-phase3-epics-14-15.md` — verify at dev-pass time by `grep -n 'Story 14.5' _bmad-output/planning-artifacts/epics-phase3-epics-14-15.md`). → **Verified: `grep -n 'Story 14.5' _bmad-output/planning-artifacts/epics-phase3-epics-14-15.md` returns `394:### Story 14.5: PRD↔architecture transcription-drift sync target` — same line number as the old `epics.md:394`.** Pinned-by line rewritten in-place to `epics-phase3-epics-14-15.md:394..414`.
  - [x] 6.4 — `bash tools/check-doc-sync/check-doc-sync.sh; echo "exit=$?"` → expect exit code 0 (clean or advisory-only). Record the stdout verdict line in Dev Notes. → **exit=0; stdout verdict: `[advisory] doc-sync: 31 advisory item(s); 0 drift`.** All 31 advisories are pre-existing pre-A.1 §-reference + section-name parity items (advisory by design); none are new since the pre-fix state (the broken script never reached the verdict stage).
  - [x] 6.5 — **HALT condition:** If the fix surfaces new genuine drift items (i.e., `[fr-label]`, `[nfr-label]`, or `[story-cite]` items with `DRIFT > 0`), the drift items are themselves carry-forward defects (latent doc drift the broken script was masking). Capture the drift items in Dev Notes verbatim, decide per-item: (i) trivial fix in this story (≤3 items, all one-line edits) — apply and note; (ii) non-trivial fix — fork into Story 16.2.1 per AC8 Path (ii). Story 16.2 itself closes either way; the doc-lock deliverable is complete. → **HALT not triggered.** `DRIFT = 0` per the verdict line; no `[fr-label]` / `[nfr-label]` / `[story-cite]` items surfaced. No fork into Story 16.2.1 required; AC8 Path (i) achieved.

- [x] **Task 7 — AC8 verification + verdict capture** (AC8)
  - [x] 7.1 — Final `make check-doc-sync` run after Task 6 lands → record stdout/stderr in Dev Notes. Expected: exit 0; one-line stdout `[ok] doc-sync: 0 drift` or `[advisory] doc-sync: N advisory item(s); 0 drift`. → **`make check-doc-sync` (final run, post-Task-6) — see Debug Log References below for full output.** Stdout verdict: `[advisory] doc-sync: 31 advisory item(s); 0 drift`; exit code 0. AC8 satisfied via Path (i) (advisory-only verdict is AC8-passing per the script's verdict logic at `:272..280`).
  - [x] 7.2 — If Task 6 forked into Story 16.2.1 (AC8 Path (ii)), record the fork in this story's Dev Notes and append a `16.2-1-*: backlog` row to `_bmad-output/implementation-artifacts/sprint-status.yaml` after the `16-2-...` row. Story 16.2.1's scope is "fix `check-doc-sync.sh` for per-phase epic file split" plus whatever drift items Task 6 surfaced. Story 16.2 itself closes once AC1..AC7 + AC4 audit are complete. → **N/A — Task 6 closed AC8 in-story via Path (i); no fork required.**

- [x] **Task 8 — Story close + sprint-status update** (close-out)
  - [x] 8.1 — Flip this story's `Status:` from `ready-for-dev` to `review` once Tasks 1..7 are complete and the verdicts pass. → **Status flipped to `review`.**
  - [x] 8.2 — Update `_bmad-output/implementation-artifacts/sprint-status.yaml`: `16-2-doc-lock-supersede-obsolete-docs-antforth-banking-design-md: ready-for-dev` → `review` (and eventually → `done` per the CR pass on close-out). → **Row flipped to `review`.**
  - [x] 8.3 — Populate Dev Agent Record below: Agent Model Used, Debug Log References (Task 1.4 / 4.4 / 6.4 / 7.1 grep / verdict outputs), Completion Notes List (one bullet per AC with pass / partial / fork verdict), File List (every file touched in Tasks 2 / 3 / 4 / 6 — expect: `docs/antforth-banking-design.md` + Task 6's `tools/check-doc-sync/check-doc-sync.sh` + possibly `docs/antforth-banking-redesign.md` (if fork α) + possibly `docs/WISHLIST.md` (if Task 3.4 yes); zero `src/` files). → **Populated.**

## Dev Notes

### Story scope summary

- **Doc-only story** — zero `src/` edits, zero binary delta, zero new REPL tests. Second of four Epic-16 binary-delta-free prework stories (16.1 hardware spike done; 16.3 emulator-vendor pick pending; 16.4 five-open-questions-resolution pending).
- **Three deliverables** — (1) reshape the existing SUPERSEDED banner at `docs/antforth-banking-design.md:3` to the AC1/AC2 enumerated `(a)/(b)` form; (2) audit cross-doc refs in `architecture.md`, `prd.md`, `architecture-phase3-epics-14-15.md` per AC4; (3) carry-forward fix for `tools/check-doc-sync/check-doc-sync.sh` to handle the per-phase epic file split (so AC8 can fire).
- **NFR-P4-20 framing** — the epic-16 spec reframes NFR-P4-20 from its source-comment-citation scope (per `prd.md:624`) to apply to design-document references too. Story 16.2 is the vehicle for that reframing; the doc-lock outcome is the locked single-source-of-truth that NFR-P4-20 can cite going forward.

### S9 hardware-smoke exemption

Recorded per NFR-P4-11's explicit-exemption clause: **"Zero binary delta — documentation-only changes."** No `src/` edits; the build artifact is unchanged; there is nothing for the hardware to smoke-test that the iz-cpm `make test-repl` baseline does not already cover.

### Baseline figures (re-validate at dev-pass start per B.3 / PD-2)

| Metric | Draft-time observation (2026-05-13) | Source |
|---|---|---|
| `wc -c build/antforth.com` | **24,995 bytes** | `cd <repo>; wc -c build/antforth.com` 2026-05-13 |
| `make test-repl` PASS count | **975 PASS** (= 974 Phase-3-close-out + 1 Lesson-14-F direct-commit test 968) | Story 16.1 Task 1.2; recount at dev-pass start |
| `make test-repl` FAIL count | **0** | Story 16.1 Task 1.2 |
| `make test-repl` SKIP count | **2** (iz-cpm SKIPs that PASS on hardware) | Phase-3 close-out baseline |
| `grep -l 'BIT 7,H' docs/*.md` | **2 files** (`design.md`, `redesign.md`) | `cd <repo>; grep -l 'BIT 7,H' docs/*.md` 2026-05-13 |
| `grep -l 'THUNK-TO-USER-BANK' docs/*.md` | **2 files** (`design.md`, `redesign.md`) | `cd <repo>; grep -l 'THUNK-TO-USER-BANK' docs/*.md` 2026-05-13 |
| `make check-doc-sync` exit | **1 (fatal — missing `epics.md`)** | Story 16.1 Task 1.4 |

All figures **MUST** be re-validated at dev-pass start (B.4 / PD-2 — figure-drift discipline: never trust an inherited figure; re-grep / re-run the cited command before relying on it).

### AC5 fork-selection guidance

Default expectation: **Fork (β)** — relax AC5 to "at most two files: the obsolete sketch + the redesign doc's rejection-rationale paragraphs". Rationale:
- Lower edit blast radius (zero edits to `docs/antforth-banking-redesign.md`).
- Preserves the redesign doc's readability — the rejection rationale is most precise when it cites the exact obsolete tokens by name.
- The single-source-of-truth goal is satisfied because no *third-party* doc carries the obsolete tokens; the redesign doc's explanatory citations are explicitly rejection rationale, not propagation.

Fork (α) is preferred only if dev-pass judges the four redesign-doc rephrasings trivial AND finds value in a strict mechanical AC5 verdict. The pick + rationale lands in Dev Notes.

### Task 6 scope rationale

Story 16.1 Task 1.4 surfaced the `check-doc-sync.sh` tool-fatal defect: `_bmad-output/planning-artifacts/epics.md` was deleted in commit 51bc6d6 (2026-05-10) when the canonical epic catalogue was split into per-phase files, and the script (authored in Story 14.5 / B.5, pre-split) still hardcodes the old path. Story 16.1 explicitly tagged Story 16.2 as the natural vehicle for the fix on the grounds that Story 16.2 is the "doc-lock" Phase-4 doc-bookkeeping vehicle and AC8 ("clean check-doc-sync") requires a working script.

Fix scope is small: drop `EPICS`, add `EPICS_P3` + `EPICS_P4`, update the awk file list at `:91..92`, update the header pinned-by comment. ~6 line edits. The HALT path (Task 6.5) covers the case where the fix surfaces previously-masked drift items; the doc-lock deliverable can still close via Story 16.2.1 fork if the drift is non-trivial.

### Cross-doc reference inventory (draft-time snapshot — re-grep at dev-pass start per B.4 / PD-2)

| File | Line | Context (verbatim grep hit) | Draft-time disposition |
|---|---|---|---|
| `architecture.md` | 417 | `**USER- prefix dropped** — only one kind of user-controllable bank exists; the prefix from the obsolete docs/antforth-banking-design.md was noise.` | VERIFIED-LEAVE (rationale citation) |
| `architecture.md` | 682 | Files-SUPERSEDED status table row | VERIFIED-LEAVE (the canonical status row) |
| `architecture.md` | 713 | `Banking design doc (docs/antforth-banking-redesign.md) — locked source of truth ...; superseded docs/antforth-banking-design.md (banner-marked).` | VERIFIED-LEAVE |
| `architecture.md` | 734 | `Epic 16 — Memory map & doc lock` deliverables row | VERIFIED-LEAVE |
| `prd.md` | 406 | Architectural-anchor paragraph naming the redesign doc as supersession authority | VERIFIED-LEAVE |
| `architecture-phase3-epics-14-15.md` | 10 | inputDocuments frontmatter entry | VERIFIED-LEAVE (Phase-3 archive) |
| `architecture-phase3-epics-14-15.md` | 74 | "Hardware: Phase 3 stays in bank 0 — banking design (docs/antforth-banking-design.md) deferred to Phase 4." | VERIFIED-LEAVE (Phase-3 archive) |
| `architecture-phase3-epics-14-15.md` | 156 | "Banking architecture (docs/antforth-banking-design.md) — Phase 4" | VERIFIED-LEAVE (Phase-3 archive) |
| `architecture-phase3-epics-14-15.md` | 626 | structures.asm row — "banking design deferred to Phase 4" | VERIFIED-LEAVE (Phase-3 archive) |
| `architecture-phase3-epics-14-15.md` | 913 | strategic-enabler bullet | VERIFIED-LEAVE (Phase-3 archive) |

Out-of-AC4-scope references (do not edit unless dev-pass elects):
- `docs/WISHLIST.md:11` — live wishlist note; optional one-character update to redesign doc (Task 3.4).
- `docs/antforth-banking-redesign.md:5`, `:7` — redesign doc's own "Supersedes" preamble; correct as-is.
- `_bmad-output/planning-artifacts/product-brief-antforth-2026-05-08.md:237`, `:273` — dated product-brief archive; immutable.
- `_bmad-output/planning-artifacts/prd-phase3-epics-14-15.md:29`, `:202`, `:347`, `:443` — Phase-3 PRD archive; immutable.
- `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:183`, `:248`, `:352` — the epic spec for this story; legitimate "the obsolete sketch" citations.

### Architecture / standards anchors

- **Epic spec:** `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:382..401` — Story 16.2 ACs.
- **NFR-P4-20 (carries Phase-2 NFR17 / Phase-3 NFR-P3-16):** `_bmad-output/planning-artifacts/prd.md:624` — single-source-of-truth for standards references in source comments; epic-16 spec reframes for design-doc references too.
- **NFR-P4-11 (mid-epic hardware-smoke per story; binary-delta stories):** `_bmad-output/planning-artifacts/prd.md` — codifies S9; zero-binary-delta stories document the S9 exemption explicitly.
- **Files SUPERSEDED status row:** `_bmad-output/planning-artifacts/architecture.md:678..683`.
- **Redesign-doc supersession preamble:** `docs/antforth-banking-redesign.md:5..7`.
- **B.3 / Lesson 13.5-F (re-`wc -c` at dev-pass start):** memory `feedback_design_upfront.md` / `feedback_no_preexisting_discharge.md` — figure-handoff discipline.
- **B.4 / PD-2 (figure-drift at draft time):** the workflow's `<critical>` block enforcement in `instructions.xml`.
- **Story 16.1 Task 1.4 carry-forward:** `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-verification-spike-memory-map-page-allocation-survey.md:85` — `check-doc-sync.sh` carry-forward into Story 16.2.

### Project Structure Notes

- Files touched in this story (expected, post-dev-pass): `docs/antforth-banking-design.md` (banner restructure); `tools/check-doc-sync/check-doc-sync.sh` (Task 6 fix); possibly `docs/antforth-banking-redesign.md` (only if fork α chosen); possibly `docs/WISHLIST.md` (only if Task 3.4 elects yes). No `src/` files, no `tests/` files, no `build/` artifact change.
- Naming + path conventions inherit from the Phase-3 doc baseline; no new files added.

### Open questions (saved for dev-pass per instructions.xml "save questions" mandate)

1. **AC5 fork pick** — α (strict grep; rephrase redesign doc) or β (relax AC5; redesign-doc citations explicitly allowed)? Default recommendation: β.
2. **Phase-3 archive convention for AC4** — is the "Phase-3 archive docs are immutable historical snapshots" convention codified anywhere, or is it implicit-by-precedent (commit 51bc6d6 split)? If implicit, should this story explicitly codify the convention in a one-line note inside `architecture-phase3-epics-14-15.md` (e.g., "this file is a frozen Phase-3 archive; subsequent corrections land in `architecture.md`")? Dev-pass discretion.
3. **Task 6 HALT path** — if the script fix surfaces latent drift items, the story's natural fork is into 16.2.1. What is the "trivial drift" threshold (Task 6.5 currently says ≤3 items, one-line edits each)? Dev-pass may tighten / loosen based on the actual drift items surfaced.
4. **`docs/WISHLIST.md:11` update (Task 3.4)** — yes (one-character path swap) or no (preserve the historical link for design-evolution traceability matching the doc itself)? Out-of-AC4-scope; dev-pass discretion.

### References

- [Source: _bmad-output/planning-artifacts/epics-phase4-epics-16-22.md#Story-16.2] — Epic 16.2 acceptance criteria spec.
- [Source: _bmad-output/planning-artifacts/architecture.md:678..683] — Files-SUPERSEDED status table.
- [Source: _bmad-output/planning-artifacts/architecture.md:417] — `USER-` prefix dropped rationale citing the obsolete doc.
- [Source: _bmad-output/planning-artifacts/architecture.md:713,734] — Locked-source-of-truth callout + Epic 16 deliverables row.
- [Source: _bmad-output/planning-artifacts/prd.md:406] — Architectural-anchor paragraph.
- [Source: _bmad-output/planning-artifacts/prd.md:624] — NFR-P4-20 definition (single-source-of-truth for standards references).
- [Source: _bmad-output/planning-artifacts/architecture-phase3-epics-14-15.md:10,74,156,626,913] — Phase-3 archive cross-refs.
- [Source: docs/antforth-banking-design.md:1..4] — current SUPERSEDED banner block (pre-restructure).
- [Source: docs/antforth-banking-redesign.md:5..7] — redesign doc's supersession preamble.
- [Source: docs/antforth-banking-redesign.md:26,28,46,63] — obsolete-token citations in the redesign doc (AC5 fork-α edit target).
- [Source: tools/check-doc-sync/check-doc-sync.sh:54..68] — script's input-file declarations (Task 6 edit target).
- [Source: _bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-verification-spike-memory-map-page-allocation-survey.md:85] — Story 16.1 Task 1.4 carry-forward of the `check-doc-sync.sh` fix into Story 16.2.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Opus 4.7, 1M context)

### Debug Log References

**Pre-edit baseline (Task 1) — captured 2026-05-13 per B.4 / PD-2:**

| Metric | Pre-edit measurement | Expected | Match |
|---|---|---|---|
| `wc -c build/antforth.com` | 24,995 bytes | 24,995 | ✓ |
| `make test-repl` PASS | 975 | ≥975 | ✓ |
| `make test-repl` FAIL | 0 | 0 | ✓ |
| `make test-repl` SKIP | 2 | 2 | ✓ |
| `head -10 docs/antforth-banking-design.md:3` | single-paragraph `> **⚠️ SUPERSEDED 2026-05-09.**` block (one prose paragraph naming redesign doc + listing `THUNK-TO-USER-BANKn` + `BIT 7,H` inline) | single-paragraph shape | ✓ (draft-time observation confirmed; restructure needed for AC1/AC2) |
| `grep -l 'BIT 7,H' docs/*.md` | `docs/antforth-banking-design.md`, `docs/antforth-banking-redesign.md` | 2 files | ✓ |
| `grep -l 'THUNK-TO-USER-BANK' docs/*.md` | `docs/antforth-banking-design.md`, `docs/antforth-banking-redesign.md` | 2 files | ✓ |
| `bash tools/check-doc-sync/check-doc-sync.sh; echo $?` | `[fatal] required input file missing or unreadable: _bmad-output/planning-artifacts/epics.md` / exit 1 | exit 1 fatal | ✓ |

All baseline figures match the draft-time observations — Task 6 fix is required for AC8 Path (i).

**Cross-doc grep (Task 3.1) — captured 2026-05-13:**

```
_bmad-output/planning-artifacts/architecture.md:417:- **`USER-` prefix dropped** — only one kind of user-controllable bank exists; the prefix from the obsolete `docs/antforth-banking-design.md` was noise. (`USER-BANK / USER-BANK@ / SET-USER-BANK` from the obsolete doc are not in the wordset.)
_bmad-output/planning-artifacts/architecture.md:682:| `docs/antforth-banking-design.md` | SUPERSEDED — the obsolete 2026-05-07 sketch with the broken `BIT 7,H` heuristic and `THUNK-TO-USER-BANKn` family; banner-marked SUPERSEDED; preserved only for design-evolution traceability |
_bmad-output/planning-artifacts/architecture.md:713:- **Banking design doc** (`docs/antforth-banking-redesign.md`) — locked source of truth for Phase 4 architectural decisions; superseded `docs/antforth-banking-design.md` (banner-marked).
_bmad-output/planning-artifacts/architecture.md:734:| **Epic 16 — Memory map & doc lock** | `docs/antforth-banking-redesign.md` (already landed); `docs/antforth-banking-design.md` SUPERSEDED banner; emulator-vendor research notes (Epic 16.3); CCP-eviction verification on real hardware |
_bmad-output/planning-artifacts/prd.md:406:- **Architectural anchor:** `docs/antforth-banking-redesign.md` (locked 2026-05-09 in a `/bmad-party-mode` session). This document supersedes `docs/antforth-banking-design.md` (2026-05-07 sketch with `SUPERSEDED` banner). All Phase-4 stories cite the redesign doc; the sketch is preserved only for design-evolution traceability.
_bmad-output/planning-artifacts/architecture-phase3-epics-14-15.md:10:  - docs/antforth-banking-design.md
_bmad-output/planning-artifacts/architecture-phase3-epics-14-15.md:74:- **Hardware:** Zilog Z80 @ 8 MHz; 512 KB banked RAM/ROM; MicroBeast platform. Phase 3 stays in bank 0 — banking design (`docs/antforth-banking-design.md`) deferred to Phase 4.
_bmad-output/planning-artifacts/architecture-phase3-epics-14-15.md:156:- Banking architecture (`docs/antforth-banking-design.md`) — Phase 4
_bmad-output/planning-artifacts/architecture-phase3-epics-14-15.md:626:| `src/structures.asm` (UserArea layout) | Frozen for Phase 3; banking design (`docs/antforth-banking-design.md`) deferred to Phase 4 |
_bmad-output/planning-artifacts/architecture-phase3-epics-14-15.md:913:- Banking architecture (`docs/antforth-banking-design.md`) — strategic enabler for the ~25 KB binary ceiling; design exists but is explicitly Phase-4 deferred
```

All 10 hits match the draft-time inventory at the documented line numbers — zero drift since story-draft 2026-05-13. All 10 → VERIFIED-LEAVE per Task 3.2.

**Final `make check-doc-sync` (Task 7.1) — captured 2026-05-13 post-Task-6 fix:**

```
$ make check-doc-sync; echo "exit=$?"
[advisory-§] §2.1 cited in _bmad-output/planning-artifacts/architecture.md:213 but no row in docs/ans-forth-core-compliance.md (advisory pre-A.1 / Story 15.1)
[advisory-§] §2.2 cited in _bmad-output/planning-artifacts/architecture.md:190 but no row in docs/ans-forth-core-compliance.md (advisory pre-A.1 / Story 15.1)
[advisory-§] §2.3 cited in _bmad-output/planning-artifacts/architecture.md:171 but no row in docs/ans-forth-core-compliance.md (advisory pre-A.1 / Story 15.1)
[advisory-§] §5.2 cited in ...architecture.md:284 (advisory pre-A.1 / Story 15.1)
[advisory-§] §5.3 cited in ...architecture.md:296 (advisory pre-A.1 / Story 15.1)
[advisory-§] §5.5 cited in ...architecture.md:255 (advisory pre-A.1 / Story 15.1)
[advisory-§] §5.6 cited in ...architecture.md:269 (advisory pre-A.1 / Story 15.1)
[advisory-§] §8.1 cited in ...architecture.md:329 (advisory pre-A.1 / Story 15.1)
[advisory-§] §8.2 cited in ...architecture.md:343 (advisory pre-A.1 / Story 15.1)
[advisory-§] §9.1 cited in ...architecture.md:60  (advisory pre-A.1 / Story 15.1)
[advisory-§] §9.2 cited in ...architecture.md:505 (advisory pre-A.1 / Story 15.1)
[advisory-§] §9.3 cited in ...architecture.md:151 (advisory pre-A.1 / Story 15.1)
[advisory-§] §9.4 cited in ...architecture.md:152 (advisory pre-A.1 / Story 15.1)
[advisory-§] §9.5 cited in ...architecture.md:96  (advisory pre-A.1 / Story 15.1)
[advisory-§] §9.6 cited in ...architecture.md:47  (advisory pre-A.1 / Story 15.1)
[advisory-§] §9.7 cited in ...architecture.md:510 (advisory pre-A.1 / Story 15.1)
[advisory-section] 9 prd-only top-level sections (allowlist empty)
[advisory-section] 6 architecture-only top-level sections (allowlist empty)
[advisory] doc-sync: 31 advisory item(s); 0 drift
exit=0
```

Sixteen `[advisory-§]` items are §-references in `architecture.md` not yet rowed into `docs/ans-forth-core-compliance.md` (advisory pre-A.1 / Story 15.1 per the script's `STRICT_SECTIONS=0` configuration; correct gate state for the post-Phase-3 baseline). Fifteen `[advisory-section]` items are top-level section-name parity differences (advisory by design, allowlist empty). **Zero genuine drift items** — `DRIFT = 0`. AC8 Path (i) achieved.

### Completion Notes List

- **AC1 PASS** — `> **⚠️ SUPERSEDED 2026-05-09.**` block is the first content after the `# AntForth Banking Architecture for MicroBeast` title at `docs/antforth-banking-design.md:3..8`. Names the redesign doc via the relative link `[`docs/antforth-banking-redesign.md`](antforth-banking-redesign.md)`. Existing single-paragraph block at `:3` was restructured in-place, not duplicated.
- **AC2 PASS** — Banner enumerates `(a)` `BIT 7,H` heuristic + `(b)` `THUNK-TO-USER-BANK*` family as literal `(a)`/`(b)` bulleted markers; each rejected element cites the redesign-doc § and FR labels for the replacement mechanism. Scannable as bullets, not inline prose.
- **AC3 PASS** — `git diff docs/antforth-banking-design.md` shows a single hunk `@@ -1,6 +1,11 @@` confined to the banner block (1 line deleted, 6 lines inserted). The original sketch body (currently lines 10..201 post-edit; was lines 5..196 pre-edit) is byte-identical, shifted only by the banner expansion. File retained for design-evolution traceability; not deleted.
- **AC4 PASS** — All 10 cross-doc grep hits (4 × `architecture.md`, 1 × `prd.md`, 5 × `architecture-phase3-epics-14-15.md`) dispositioned VERIFIED-LEAVE per Task 3.2; no edits applied to the three audited files. Per-row dispositioning recorded in Task 3.2 above and the draft-time inventory table in Dev Notes.
- **AC5 PASS (fork β)** — `grep -l 'BIT 7,H' docs/*.md` returns exactly 2 files (`design.md` + `redesign.md`); same for `THUNK-TO-USER-BANK`. No third-party doc carries either obsolete token. Fork-β rationale recorded in Task 4.1.
- **AC6 PASS** — `wc -c build/antforth.com` = 24,995 bytes (Δ=0 vs. pre-edit baseline). `git diff src/` empty. S9 hardware-smoke explicitly exempt: *"Zero binary delta — documentation-only changes."* per NFR-P4-11.
- **AC7 PASS** — `make test-repl` post-edit: 975 PASS / 0 FAIL / 2 SKIP — identical to pre-edit baseline. Zero regressions.
- **AC8 PASS (Path (i))** — `make check-doc-sync` exit 0; stdout `[advisory] doc-sync: 31 advisory item(s); 0 drift`. `tools/check-doc-sync/check-doc-sync.sh` fixed per Task 6: dropped `EPICS` (deleted `epics.md`), added `EPICS_P3`/`EPICS_P4`, updated awk header-walk to all four phase files, updated pinned-by header comment. No drift items surfaced; no fork into Story 16.2.1.
- **Out-of-AC4-scope fix landed**: `docs/WISHLIST.md:11` updated to point at the redesign doc per Task 3.4 (one-line edit; WISHLIST is a live doc).

### Code Review Pass (2026-05-13)

Adversarial CR pass executed 2026-05-13 against the Story-16.2 spec. Verdict: **PASS — all 8 ACs mechanically verified.** Re-ran the load-bearing verdicts at CR time:

- `wc -c build/antforth.com` = **24,995 bytes** (Δ=0 vs. baseline; AC6 ✓).
- `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP** (zero regressions vs. baseline; AC7 ✓).
- `bash tools/check-doc-sync/check-doc-sync.sh` → exit 0; stdout `[advisory] doc-sync: 31 advisory item(s); 0 drift` (AC8 ✓).
- `grep -l 'BIT 7,H' docs/*.md` and `grep -l 'THUNK-TO-USER-BANK' docs/*.md` → each returns exactly 2 files (`design.md` + `redesign.md`; matches Fork-β verdict; AC5 ✓).
- Cross-doc audit re-verified by spot-check of `architecture.md:417/682/713/734` + `prd.md:406` — all 5 hits intact at the claimed line numbers (AC4 ✓).

Three LOW findings surfaced; dispositions:

- **L1 (FIXED in this CR pass)** — File List line numbers for `tools/check-doc-sync/check-doc-sync.sh` drifted 1–2 lines from actual: input-file variable block runs `:53..62` (not `:53..60`); existence-check `for` loop is `:66` (not `:65`); in-body comment block is `:178..181` (not `:177..180`); EPICS_HEADERS awk is `:94..95` (not `:92..93`). Patched in-place in the File List row above with a reconciliation note.
- **L2 (ACCEPTED-WITH-RATIONALE)** — `docs/WISHLIST.md:11` edit added an explanatory clause beyond the "single-character path swap" scoping language in Task 3.4. Already rationalized in the Task 3.4 completion bullet; the live doc benefits from the explicit "the older sketch is SUPERSEDED" tail clause; no revert.
- **L3 (NO-OP, citation accurate)** — Banner cites `§2.2 / §3 / FR-P4-18..21` for the `BIT 7,H` replacement; AC2 wording was permissive (`§3 *or whichever § block carries the sentinel-trampoline replacement*`). `§2.2` (S1 sentinel decision, redesign-doc `:44`) is the genuine locus of the sentinel-tagged 3-cell return-frame decision; trimming would make the banner less precise. Banner unchanged.

### File List

- `docs/antforth-banking-design.md` — banner block at `:3..8` restructured from single-paragraph prose to enumerated `(a)/(b)` form (AC1, AC2, AC3).
- `tools/check-doc-sync/check-doc-sync.sh` — pinned-by header line (`:14`), input-file variable block (`:53..62`), existence-check loop (`:66`), in-body comment block (`:178..181`), and EPICS_HEADERS awk command (`:94..95`) updated to drop the deleted `epics.md` and consume all four per-phase files (`epics-phase{1,2,3,4}-*.md`) (Task 6 / AC8). *(Line numbers reconciled post-CR per L1; the variable block extends through `COMPLIANCE` at `:62`, the `for f in` loop is at `:66`, the Check-(b) explanatory comment runs `:178..181`, and the EPICS_HEADERS awk lives at `:94..95`.)*
- `docs/WISHLIST.md` — line 11 updated to point at the redesign doc (Task 3.4, optional out-of-AC4-scope, applied).
- `_bmad-output/implementation-artifacts/16-2-doc-lock-supersede-obsolete-docs-antforth-banking-design-md.md` — this story file: task checkboxes marked, Dev Agent Record populated, Status flipped to `review` at close (Task 8).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `16-2-doc-lock-supersede-obsolete-docs-antforth-banking-design-md` row: `ready-for-dev` → `in-progress` → `review` (Task 8).

Zero `src/` files. Zero `tests/` files. Zero `build/` artifact change.
