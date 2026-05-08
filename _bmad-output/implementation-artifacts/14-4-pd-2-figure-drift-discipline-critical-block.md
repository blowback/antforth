# Story 14.4: PD-2 figure-drift discipline `<critical>` block

Status: done

<!--
This is the FOURTH story in Epic 14 (Phase-3 Process Foundation), the
debt-cleanup interlude on top of the v2.0.0 baseline (commit 6599d73,
tagged 2026-05-07). Stories 14.1 / 14.2 / 14.3 closed B.1 / B.2 / B.3
(commits 274062a / 80f99c8 / 64e91bf, 2026-05-08, all zero binary delta);
Story 14.4 closes carry-forward item B.4 per
docs/PHASE-3-CARRY-FORWARD.md:35 ("PD-2 — Story-drafter figure drift")
and architecture §"B.4-D1" (`architecture.md:262`).

Per architecture §"Recommended sequencing within the lead-in" (line
932..937):
  1. B.1 first — tests/README.md (DONE — Story 14.1)
  2. B.2 + B.4 together — <critical> blocks added to instructions.xml
     (B.2 DONE — Story 14.2, lines 33..60; B.4 = THIS STORY, sibling
     edit at the same workflow-tree file)
  3. B.3 — wc -c task added to template.md (DONE — Story 14.3)
  4. B.5 — tools/check-doc-sync/ + Makefile target (Story 14.5)

Architecture's "B.2 + B.4 together" sequencing recommendation was
de-coupled in practice — B.2 landed in Story 14.2 standalone, B.3
landed in Story 14.3 ahead of B.4 — but the architectural intent
that the two blocks be adjacent in the file holds: AC6 below
mandates adjacency. Story 14.4 lands the B.4 `<critical>` block
immediately after B.2's block at instructions.xml:33..60, so the
discipline cluster reads as a single grouped section a future
drafter encounters as one unit.

Origin lineage:
  Epic 13 retro 2026-05-05 §"Documented Follow-Up Opportunities"
  row 1 (epic-13-retro-2026-05-05.md:230) — "PD-2 — Story-drafter
  figure drift (story-template note 2.x scope) — ⏳ Phase-3
  carry-forward". The retro identified the failure-mode but did
  not enumerate a worked incident; the carry-forward catalogue
  (docs/PHASE-3-CARRY-FORWARD.md:35) classified it Medium-effort
  and slotted it as a sibling of B.2/B.3 in the story-template-
  discipline cluster.
  PRD Phase-3 2026-05-08 FR-P3-14 + FR-P3-15 + NFR-P3-18 —
  formalised B.4's scope, the verdict-criterion meta-pattern,
  and the story-template-discipline-as-quality-attribute framing.
  Architecture Phase-3 2026-05-08 §"B.4-D1" (line 262) + §"`<critical>`
  block format example (B.2 / B.4 pattern)" (line 410..422) +
  §"Existing files modified in Phase 3" (line 605) — pinned the
  edit site (`_bmad/bmm/workflows/4-implementation/create-story/
  instructions.xml`), the block format, and the verdict criterion
  (figure-drift block exists and is grep-able).

Severity: workflow-file edit only. Zero binary delta expected
(NFR-P3-2 envelope: B.4 = 0 bytes per architecture §"Per-story
binary delta envelopes"). Zero new mechanism, zero new EQUs, zero
new dictionary words. The deliverable is a new `<critical>` block
in `instructions.xml` adjacent to B.2's block, plus a one-line
update to docs/PHASE-3-CARRY-FORWARD.md's Status column.

Standing commitments (S1–S12, codified as NFR-P3-22..33) apply:
  S1 — adversarial review fresh-context external. ACs do NOT
       enumerate "trigger an adversarial review pass". PD-1
       <critical> block at instructions.xml:20..31 enforces.
       The B.4 block this story adds is sibling discipline at
       the same enforcement surface (instructions.xml).
  S2 — REPL-piped tests as default regression surface. No new
       tests required for this workflow-file-only story; the
       `<critical>` block IS the discipline artefact.
  S3 — real-byte-count estimation + capstone-aware drafting.
       Story 14.2 landed the structural enforcer for "mirrors
       prior arm" byte-budget shorthand at byte-budget-rationale
       review; Story 14.3 landed the structural enforcer for
       "re-wc -c at dev-pass start" at Pre-edit baseline capture;
       Story 14.4 lands the structural enforcer for "validate
       figures against source-of-truth at draft time" at figure-
       quoting moments — third member of the same enforcement-
       surface cluster.
  S4 — AC composition. ACs #1..#9 stand alone or compose cleanly
       with named antecedents.
  S5 — HALT on PARTIAL ship attempts. No "ship 8/9 ACs + spawn
       14.4.1" pattern.
  S8 — "pre-existing" / "out-of-scope" cannot discharge correctness
       defects; this story closes a *workflow-discipline* gap, not
       a correctness defect. The B.4 closure is enforcement-surface
       transition (per CCD-P3-2) for what was previously why-surface
       discipline (PD-2 sat in retro doc + carry-forward catalogue
       only, never in a workflow-tree file).
  S9 — mid-epic hardware-smoke cadence; **this story is a documented
       S9 exemption** (zero binary delta; AC #8 records the exemption
       explicitly per NFR-P3-7 + architecture §"Hardware-smoke
       cadence"). Same exemption shape as Stories 14.1/14.2/14.3.
  S10 — workflow > memory > prompt; the `<critical>` block lands in
        the workflow-tree file (`_bmad/bmm/workflows/4-implementation/
        create-story/instructions.xml` — the enforcement surface per
        CCD-P3-2 mapping at architecture §"Existing files modified
        in Phase 3"), not in a memory entry like
        feedback_no_figure_drift.md (which would be the architecture
        §"Bad — workflow edit (anti-pattern)" violation).
  S11 — version-surface audit applies at *tag-applicable* close-out;
        Story 14.4 is not tag-applicable (Ant's call per Epic 14
        §"Shape" — banner-only point-release valid but optional).
        Same as Stories 14.1/14.2/14.3.
  S12 — hardware-typed probe authoring discipline; not directly
        engaged (workflow-file edit, not a probe).

Recursive-self-validation note. Story 14.4 IS the structural
enforcement for the discipline B.4 codifies. Per S5 and the FR-P3-15
verdict-criterion meta-pattern, Story 14.4's own dev-pass MUST
practice the discipline B.4 codifies — every figure / table / code-
block this story quotes from a prior story or retro is validated
against its source-of-truth at drafting time, not transcribed.
Specifically: the "Story 14.2 block at instructions.xml:33..60"
citation, the architecture-doc line:column references, and any
quoted PRD/architecture text MUST be re-verified by reading the
source file directly during the dev-pass — exactly the workflow
B.4 codifies.

Validation is optional. Run validate-create-story for quality check
before dev-story.
-->

## Story

As a **story drafter** (project lead Ant — and any future SM agent or LLM-driven story-creation pass) authoring a Phase-3+ story whose rationale, ACs, or Dev Notes quote figures, tables, or code blocks from a prior story or retrospective,
I want the create-story workflow's `instructions.xml` to require me to validate those quoted artefacts against their source-of-truth at drafting time — re-reading the cited file:line, re-running the cited command, or re-extracting the cited table from the cited document before quoting,
So that I don't inherit drift that has accumulated since the original artefact was authored — closing **PD-2 (Epic 13 retro #1)**, the long-deferred Phase-3 carry-forward item identified at `epic-13-retro-2026-05-05.md:230` and catalogued at `docs/PHASE-3-CARRY-FORWARD.md:35`.

This is the **fourth story** in Epic 14 (Phase-3 Process Foundation) — the lead-in cluster (B.1 + B.2 + B.3 + B.4 + B.5) that lands first per `docs/PHASE-3-CARRY-FORWARD.md:87` and `architecture.md:932..937`. B.1 closed in Story 14.1 (commit 274062a, 2026-05-08, zero binary delta); B.2 closed in Story 14.2 (commit 80f99c8, 2026-05-08, zero binary delta, `<critical>` block at `instructions.xml:33..60`); B.3 closed in Story 14.3 (commit 64e91bf, 2026-05-08, zero binary delta, `### Pre-edit baseline` subsection at `template.md:19..23`); B.4 closes in Story 14.4 (this story). Per architecture §"Recommended sequencing within the lead-in" (line 935): "**B.2 + B.4** together — `<critical>` blocks added to `instructions.xml` (sibling edits, single dev-pass)". Practical sequencing de-coupled B.2 (Story 14.2) and B.4 (this story) into separate dev-passes, but the *file-level adjacency* the architecture mandated is preserved by AC6 below — the new B.4 block lands immediately after the B.2 block at `instructions.xml:60`, so the discipline cluster reads as a single grouped pair.

The story has **zero new feature scope** and **zero binary delta** (NFR-P3-2 envelope per architecture §"Per-story binary delta envelopes" line 346: `B.2 / B.3 / B.4 | 0 (workflow-file only)`). The deliverable is a new `<critical>` block inserted into `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` between the existing B.2 block (lines 33..60) and the next existing structural element (the `<step n="1" goal="Determine target story">` block at line 62), plus a one-line update to `docs/PHASE-3-CARRY-FORWARD.md`'s Status column. The story is a **documented S9 hardware-smoke exemption** per NFR-P3-7 / architecture §"Hardware-smoke cadence" ("Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped"). Same exemption shape as Stories 14.1 / 14.2 / 14.3.

The story carries its own **verdict criterion** per FR-P3-15 (the verdict-criterion meta-pattern that makes B.x lead-in stories discipline-as-deliverable per architecture §"Implications for B.x verdict criteria"): the new `<critical>` block is grep-able from `instructions.xml` (`grep -nE '(figure[- ]drift|PD-2)' instructions.xml` returns ≥ 1 match in the new block — the literal AC5 verdict criterion from `epics.md:386`); **and** Story 14.4's own dev-pass demonstrates the discipline by re-validating the figures it quotes (the "B.2 block at lines 33..60" reference, the architecture line:column references, the carry-forward catalogue row at `:35`) against the source files at drafting time rather than transcribing. If either verdict criterion fails, the story HALTs per S5 — the new `<critical>` block failed its own verdict; per architecture §"Implications for B.x verdict criteria" line 217 ("If a lead-in fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration").

---

## Severity / Phase Re-Statement (BINDING — context for every dev-pass decision)

This is a **workflow-file-only** story closing the long-deferred carry-forward item B.4 (originally Epic 13 retro #1 / PD-2, codified 2026-05-05). The fix shape is **fully pinned** by `architecture.md:262` (§"B.4-D1") and `architecture.md:410..422` (§"`<critical>` block format example (B.2 / B.4 pattern)"). The single edit site is `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`; the block format follows the architecture-doc canonical example.

| Dimension | Value | Source |
|---|---|---|
| **Scope** | New `<critical>` block in `instructions.xml` (sibling of B.2 at lines 33..60) + one carry-forward Status update | `architecture.md:262` (§"B.4-D1") |
| **New file** | None | n/a |
| **Modified file (primary)** | `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (insert new B.4 `<critical>` block immediately after the B.2 block; current end-of-B.2-block at line 60, next structural element `<step n="1">` at line 62; insertion site is line 61 — the existing blank line — replacing it with the new block + a trailing blank line) | `architecture.md:605` (§"Existing files modified in Phase 3") |
| **Modified file (secondary)** | `docs/PHASE-3-CARRY-FORWARD.md` (B.4 row at line :35 Status column updated `🔄 In progress` → `✅ Done` with closure note; new closure-tracking row added at the bottom of §"Status Tracking" per Stories 14.1 / 14.2 / 14.3 precedent) | `docs/PHASE-3-CARRY-FORWARD.md:104` (Story 14.3 closure row for shape precedent) |
| **Block placement (AC6)** | **Adjacent to** the B.2 block at `instructions.xml:33..60` — specifically, immediately after line 60 (the B.2 block's `</critical>` close), so the discipline cluster reads as a grouped pair. Per architecture §"Recommended sequencing within the lead-in" line 935 — "**B.2 + B.4** together — sibling edits, single dev-pass". The B.2-then-B.4 ordering is natural (B.2 fires at byte-budget-rationale step; B.4 fires at figure-quoting step; together they cover the two distinct drafting moments where prior-work-content gets carried forward unverified). | Story 14.4 AC6 + `architecture.md:935` |
| **Block format** | Multi-line `<critical>` block following the canonical example at `architecture.md:410..422` and the in-tree precedent at `instructions.xml:33..60` (B.2 block). Block content: motivating PD item cite (PD-2 / Epic 13 retro #1), trigger pattern (figures, tables, code blocks quoted/copied from prior story or retro), required action (validate against source-of-truth at draft time — re-read cited file:line / re-run cited command / re-extract cited table), and lesson-tag closure note. | `architecture.md:410..422` + B.2 in-tree precedent |
| **Cited motivating PD** | PD-2 (Epic 13 retro #1) at `epic-13-retro-2026-05-05.md:230` ("Story-drafter figure drift (story-template note 2.x scope)") | Story 14.4 AC4 (`epics.md:385`) |
| **Binary delta** | 0 bytes (workflow-file only, no kernel touch) | `architecture.md:346` |
| **Test count delta** | 0 (no new probes) | Story 14.4 AC9 (`epics.md:390` — "≥ 973 PASS / 0 FAIL") |
| **S9 disposition** | Exempt + documented in verdict table | NFR-P3-7 / `architecture.md:456` |
| **S11 disposition** | Not tag-applicable; banner-bump optional per Ant's call | `epics.md` Epic 14 §"Shape" |
| **Verdict criterion (self-test)** | (a) `grep -n -E '(figure[- ]drift|PD-2)' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` returns ≥ 1 match in the new `<critical>` block per AC5 / FR-P3-15; (b) the new block enumerates the AC2 trigger surface (figures + tables + code blocks); (c) the new block enumerates the AC3 required-action surface (validate against source-of-truth — re-read / re-run / re-extract); (d) the new block cites PD-2 / Epic 13 retro #1 per AC4; (e) the block is positioned adjacent to B.2 per AC6 (insertion site at line 61 produces grouped pair); (f) the structural edit is recorded in PHASE-3-CARRY-FORWARD.md per AC7. | FR-P3-15 / AC5 / AC6 / AC7 |

**The story is pre-decided in shape.** No fix-shape pick (A.1-D3 / A.3 / B.7 dispositions); no kernel surgery; no register-convention audit; no caught-form THROW migration; no new file creation. The dev-pass adds the new `<critical>` block per the architecture-pinned format, runs the FR-P3-15 verdict-criterion self-test (grep pattern + content surface), updates `docs/PHASE-3-CARRY-FORWARD.md`'s B.4 Status row to `✅ Done`, runs `make test-repl` for regression gate, and closes.

If the dev-pass surfaces *additional* trigger patterns worth enumerating beyond the architecture's example (e.g., diagrams quoted as ASCII art, percentage figures from retros, line-count or byte-count figures inherited from the prior story's verdict table), those land in the new block in-pass per AC #11-style in-pass-fix discipline (mirror Story 14.1 Task 4.6 / Story 14.2 Task 2.5 / Story 14.3 Task 2.4 review-fix-pass shape) — but they do NOT trigger a sibling-story spawn, and the verdict criteria still use AC5 phrasing. Per S5, no PARTIAL ship.

**Per-component byte-budget itemisation (for B.2 lint compliance — Story 14.2 closed 2026-05-08):**

| Component | Byte cost | Notes |
|---|---|---|
| `instructions.xml` text edit (new `<critical>` block) | 0 kernel bytes | Workflow file consumed by BMAD runtime, not by antforth kernel build/test harness |
| `docs/PHASE-3-CARRY-FORWARD.md` Status update (B.4 row + new closure row) | 0 kernel bytes | Doc file, not in kernel build path |
| `src/*.asm` modifications | 0 bytes | None — no kernel surgery in scope |
| `build/antforth.com` Δ | 0 bytes | No `src/*.asm` touched |
| `build/antforth_filesanity.com` Δ | 0 bytes | No `src/*.asm` touched |
| **Per-arm total** | **0 bytes** | Workflow-file-only story |

Per-component itemisation independent of prior stories: the figure is reached by enumerating the components individually, not by asserting "same shape as Stories 14.1/14.2/14.3" (which would trigger the B.2 lint that Story 14.2 itself codified). Stories 14.1/14.2/14.3 closed at zero delta on independent component-by-component bases at their own dev-pass closes; their precedent is a **sanity-check anchor** for "workflow-file-only stories carry zero binary delta" only — not the source of Story 14.4's estimate.

---

## Acceptance Criteria

1. **Given** the v2.0.0 baseline `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (388 lines as of post-Story-14.3 close, commit 64e91bf) **lacks** any `<critical>` block addressing figure-drift discipline (verified pre-edit via `grep -nE '(figure[- ]drift|PD-2)' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` returning the empty set, captured in Pre-edit baseline + Dev Notes),
   **when** Story 14.4 is dev-passed,
   **then** a new `<critical>` block lands in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` at the position specified by AC6. The block is multi-line (i.e., opens with `<critical>` on its own line followed by content on subsequent lines, then closes with `</critical>` on its own line — the same structural form as the B.2 block at `:33..60` and the PD-1 block at `:20..31`). The block content addresses the figure-drift failure-mode codified as PD-2 (Epic 13 retro #1).

2. **Given** the AC2 trigger-surface requirement (per `epics.md:383` — "the block applies to figures, tables, and code blocks; trigger pattern: any quoted/copied artefact from a prior story or retro that the new story relies on for its rationale"),
   **when** the new `<critical>` block is authored per AC1,
   **then** the block content enumerates the **three trigger categories** explicitly: **figures**, **tables**, and **code blocks**. The enumeration may be inline prose, bulleted list, or any combination thereof; whichever form, the literal substrings "figure", "table", and "code block" (or trivially close variants like "figures" / "tables" / "code blocks") must each appear at least once within the new block, and the block must make clear that the trigger is the **act of quoting or copying** such an artefact from a prior story or retrospective.

3. **Given** the AC3 required-action requirement (per `epics.md:384` — "the block requires the drafter to validate the artefact against the source-of-truth at draft time (e.g., re-read the cited file:line, re-run the cited command, re-extract the cited table from the cited document) before quoting"),
   **when** the new `<critical>` block is authored per AC1,
   **then** the block content names the required action — **validate against source-of-truth at draft time** — using a strong-imperative verb ("validate", "verify", "re-read", "re-check", or equivalent) and the qualifier **"at draft time"** (or trivially close variants like "at drafting time" / "before quoting" / "before relying on the figure"). The block enumerates at least one concrete validation modality from the architecture's example surface — re-reading the cited `file:line`, re-running the cited command, or re-extracting the cited table from the cited document. Optional but encouraged: the block names the failure mode being prevented (e.g., "drift accumulated since the original artefact was authored").

4. **Given** the AC4 motivating-PD-cite requirement (per `epics.md:385` — "the block cites PD-2 (Epic 13 retro #1) as its motivating PD item"),
   **when** the new `<critical>` block is authored per AC1,
   **then** the block content names **(a)** PD-2 as the motivating PD item (literal "PD-2" or "Phase-3 Discipline item 2" reference) and **(b)** Epic 13 retro #1 as the source citation (literal "Epic 13 retro #1" or close variant like "epic-13 retro #1" / "Epic-13 retro item #1"). Minimum acceptable cite form: a single inline parenthetical like `(PD-2 / Epic 13 retro #1)` satisfies both (a) and (b); a longer form like `(PD-2 — Story-drafter figure drift; Epic 13 retro #1, epic-13-retro-2026-05-05.md:230)` is also accepted. Drafter picks one.

5. **Given** the FR-P3-15 verdict-criterion meta-pattern — each B.x lead-in story tests that the new artefact **would have caught the prior-incident pattern that motivated it** (per `architecture.md:264..268` — "B.4 — the figure-drift `<critical>` block exists in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` and is grep-able"; per `epics.md:386` — "AC5 (FR-P3-15 verdict-criterion meta-pattern) — `grep -n -E '(figure[- ]drift|PD-2)' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` returns at least one match in the new `<critical>` block"),
   **when** Story 14.4 is dev-passed,
   **then** the verdict-criterion grep-tests are mechanically executed at story-close and recorded in Completion Notes:
   - **(a)** `grep -nE '(figure[- ]drift|PD-2)' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` returns ≥ 1 match within the line range of the new block (the literal AC5 verdict criterion per `epics.md:386`).
   - **(b)** `grep -nE 'figure|table|code block' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` returns ≥ 3 distinct matches within the new block's line range (one per AC2 trigger category).
   - **(c)** `grep -nE 'source-of-truth|source of truth|draft time|drafting time' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` returns ≥ 1 match within the new block's line range (the AC3 required-action canonical phrase).
   - **(d)** `grep -nE 'PD-2|Epic 13 retro #1|epic-13 retro' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` returns ≥ 1 match within the new block's line range (the AC4 cite).
   - **(e)** `grep -cE '<critical' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` returns **18** post-edit (pre-edit baseline = 17, captured at Pre-edit Task 1; Δ = +1 for the new B.4 block opening tag). **Honest disposition note**: the count metric uses `<critical` (no closing-bracket anchor) so it counts both inline `<critical>...</critical>` directives (each contributing one match) and multi-line block openings (each contributing one match). This is the same count metric Story 14.2 surfaced and amended at AC6(d) — see Story 14.2 Completion Notes §"AC6(d) recursive-self-validation moment" for the precedent. Story 14.4's pre-edit baseline of 17 was captured by direct invocation at Pre-edit Task 1 (not transcribed from Story 14.2's report), per B.3 discipline.
   - **(f)** **recursive self-validation**: Story 14.4's own dev-pass demonstrates the B.4 discipline by re-validating every figure / table / code-block / file:line / line-count this story quotes against its source-of-truth at drafting time. Specifically: (i) the "Story 14.2 block at instructions.xml:33..60" reference is verified by re-reading `instructions.xml:33..60` directly during dev-pass, not transcribed from Story 14.2's File List; (ii) the architecture line:column references (`:262`, `:410..422`, `:605`, `:935`) are verified by reading `architecture.md` directly; (iii) the PD-2 row citation at `epic-13-retro-2026-05-05.md:230` is verified by reading the retro file directly; (iv) the Story-14.3 closure note at `docs/PHASE-3-CARRY-FORWARD.md:104` is verified by reading the carry-forward file directly. The dev-pass records all four re-validations in Dev Notes with the format "REFERENCE — VERIFIED BY: re-read SOURCE during dev-pass". If any inherited figure diverges from its current source-of-truth value, the divergence IS the verdict criterion — investigate and reconcile per Lesson 13.5-F + PD-2 before the dev-pass proceeds.
   - If any of (a)..(e) returns the wrong count, the story HALTs per S5 — the new block failed its own verdict; per architecture §"Implications for B.x verdict criteria" line 217 ("If a lead-in fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration"). If (f) inherits any figure unchecked, B.4's discipline failed in its own dev-pass — same HALT.

6. **Given** the B.2 / B.4 sibling-sequencing requirement (per `epics.md:387` — "AC6 — the B.4 block lands adjacent to (immediately before or after) the B.2 'mirrors' block in `instructions.xml` so the discipline cluster is visually grouped — a future drafter encountering one encounters both. (B.2 / B.4 sibling sequencing per architecture's 'Recommended sequencing within the lead-in: B.2 + B.4 together'.)" — and `architecture.md:935` — "**B.2 + B.4** together — `<critical>` blocks added to `instructions.xml` (sibling edits, single dev-pass)"),
   **when** the new `<critical>` block is authored per AC1,
   **then** the block is positioned **immediately after** the B.2 block (which currently spans `instructions.xml:33..60`) — i.e., insertion site is the existing blank line at `:61`, replaced by the new block followed by a trailing blank line. **Adjacent-before** would mean inserting between the PD-1 block (lines :20..31) and the B.2 block (lines :33..60); **adjacent-after** is the recommended placement because it preserves the existing PD-1 → B.2 reading order (process-discipline lints accumulate in chronological order of codification: PD-1 was first, B.2 second, B.4 third). Dev-pass picks adjacent-after with rationale in Completion Notes; "adjacent-before" remains AC-acceptable but requires explicit rationale for departing from the chronological reading order. Verdict: the diff between the B.2 closing `</critical>` (line :60) and the B.4 opening `<critical>` (post-edit) shows ≤ 2 blank lines (the existing one-line gap between blocks per the PD-1 → B.2 spacing precedent at `:31..32`).

7. **Given** the BMAD installer-manifest disposition per CCD-P3-2 (architecture §"Workflow-file edit identity" line 395..400 — "Installer manifest → BMAD installer's expected list of files (so structural edits survive installer re-runs)") and the **honest disposition** Story 14.2 documented at AC7 / Story 14.3 documented at AC6 ("constraint named, not closed" per Story 14.2 AC7 precedent — the actual installer manifest at `_bmad/_config/manifest.yaml` enumerates *modules* not per-file edits; `_bmad/` is gitignored at `.gitignore:2`; the persistence model is "lucky persistence" since 2026-05-05 PD-1 dev-pass),
   **when** Story 14.4 is dev-passed,
   **then** the dev-pass confirms the structural edit's persistence model is named (not silently inherited):
   - **(a)** the file `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` is named in `_bmad/_config/manifest.yaml` as part of the installed `bmm` module (module `bmm` v6.0.4 owns the `_bmad/bmm/workflows/...` tree per `manifest.yaml:13..19`; same persistence model B.2 lands on); a future installer re-run on the bmm module would re-write this file from its source-of-truth shipped with the installer.
   - **(b)** because the installed `bmm` module is `source: built-in` per `manifest.yaml:17`, the module's source-of-truth lives upstream of this repo — the local edit is a per-project customization that an upstream re-install would overwrite. **Identical persistence model to PD-1 (Story 13.5.0), B.2 (Story 14.2), and B.3 (Story 14.3).** No installer re-run has occurred since 2026-05-05 (PD-1 dev-pass); PD-1's `<critical>` block at `:20..31`, B.2's block at `:33..60`, B.3's `### Pre-edit baseline` subsection in `template.md`, and the B.4 block this story adds will all persist on the same model.
   - **(c)** the dev-pass surfaces this disposition explicitly in Completion Notes per S8 honest-disposition pattern. The disposition shape is "constraint named, not closed" per Story 14.2 AC7 / Story 14.3 AC6 precedent. Closure path: when a bmm v6.0.5+ upstream-PR mechanism becomes available, B.1's `tests/README.md` (in-tree, IS in git), B.2's `<critical>` block, B.3's "Pre-edit baseline" task-entry, and B.4's figure-drift `<critical>` block (this story's deliverable) become candidates for upstreaming. Until then, the local edits ARE the enforcement surface. AC7 disposition = **constraint named, not closed**, exactly as Stories 14.2 / 14.3.

8. **Given** the post-Story-14.3 baseline binary at `build/antforth.com` (current `wc -c` measured directly at story-drafting time on commit 64e91bf — Story-14.3 was zero binary delta per its AC #7 verdict; per the B.3 discipline this story's dev-pass *also* enforces, the figures MUST be re-measured at Pre-edit Task 1 not transcribed from Story 14.3),
   **when** the dev-pass measures `wc -c build/antforth.com` and `wc -c build/antforth_filesanity.com` at story-drafting time AND at story-close,
   **then** the post-edit binary sizes are **unchanged from the pre-edit measurement**: production binary (Δ = 0); filesanity binary (Δ = 0). The story is **workflow-file edit + carry-forward Status update only**; any non-zero binary delta on this story HALTs per S5 — there is no `src/*.asm` instruction change in scope. Per NFR-P3-2 (cumulative Phase-3 ROM cap +200 bytes / 24,996 → ≤ 25,200), Story 14.4's per-story envelope is `0 bytes` (architecture §"Per-story binary delta envelopes" line 346 / `epics.md:389`). The S9 hardware-smoke task is **documented exempt** per NFR-P3-7 / architecture §"Hardware-smoke cadence" — same exemption shape as Stories 14.1 / 14.2 / 14.3. The exemption note lands in Completion Notes: *"S9 exempt — zero binary delta (workflow-file edit + carry-forward Status update only); per architecture §'Hardware-smoke cadence' ('Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly')."*

9. **Given** the post-Story-14.3 `make test-repl` baseline of 973 PASS / 0 FAIL (per Story 14.3 AC #8 verdict, unchanged from the post-Story-14.2 / post-Story-14.1 / post-Epic-13.5 / post-v2.0.0 baseline),
   **when** `make test-repl` is run pre-edit AND post-edit,
   **then** the result is **973 PASS / 0 FAIL — zero regressions, zero test-count movement**. Pre-edit verification: `grep -c '^PASS:' <(make test-repl 2>&1)` returns 973; pre-edit FAIL count = 0. Post-edit (story-close): same numbers — Story 14.4 is workflow-file edit only, no test-suite movement expected (the `instructions.xml` file is consumed by the BMAD workflow runtime, NOT by the antforth kernel build or test harness; editing it cannot affect `make test-repl` pass/fail counts unless the edit accidentally damages the file in a way that breaks the BMAD workflow — but BMAD workflow integrity is orthogonal to antforth-kernel test results). Any `make test-repl` movement HALTs per S5. Recorded in Completion Notes alongside `make test` (assembly thread) clean check (informational; not a PARTIAL gate) and `make test-file-sanity` PASS (informational).

---

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift)
- [x] Capture current `make test-repl` baseline pass count

### Story tasks

- [x] **Task 1 — Pre-edit baseline** (AC #5(e), #5(f), #8, #9; per architecture §"Re-`wc -c` at the start of every dev-pass" / Lesson 13.5-F + the B.4 discipline this story codifies — Story 14.4's dev-pass MUST practice both B.3 and B.4 disciplines forward, since both B.2 and B.3 have already landed)
  - [x] 1.1 — `wc -c build/antforth.com` direct measurement → record value. **Do not inherit Story 14.3's reported figures (24,995)** — re-measure directly per B.3 discipline.
  - [x] 1.2 — `wc -c build/antforth_filesanity.com` direct measurement → record value. **Do not inherit Story 14.3's reported figures (26,460)** — re-measure directly per B.3 discipline.
  - [x] 1.3 — `make test-repl 2>&1 | tee /tmp/14-4-pre-edit.out` → `grep -c '^PASS:' /tmp/14-4-pre-edit.out` should equal **973**; `grep -c '^FAIL:' /tmp/14-4-pre-edit.out` should equal **0**. Record both counts.
  - [x] 1.4 — `grep -nE '(figure[- ]drift|PD-2)' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` → record matches (expected: empty / no matches pre-edit). This establishes the AC1 baseline per AC5(a).
  - [x] 1.5 — `grep -cE '<critical' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` → record count. Expected: **17** pre-edit (PD-1 block + B.2 block + 15 inline `<critical>...</critical>` directives in the workflow header). Direct-count baseline for AC5(e).
  - [x] 1.6 — `git log --oneline -1` → record current HEAD (expected: `64e91bf story 14.3: ...`).
  - [x] 1.7 — `wc -l _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` → record line count (expected: **388** pre-edit per Story 14.3 closure measurement; re-verify directly per B.3).
  - [x] 1.8 — **B.4 recursive-self-validation pre-flight** (AC #5(f)): cross-reference every figure / file:line / line-count this story quotes against its source-of-truth at drafting time, before any source edits:
    - [x] (i) "B.2 block at instructions.xml:33..60" — re-read `instructions.xml:33..60` directly; verify the block exists and spans the cited lines.
    - [x] (ii) Architecture line:column references (`:262`, `:410..422`, `:605`, `:935`) — re-read `_bmad-output/planning-artifacts/architecture.md` at those line numbers; verify content matches story citations.
    - [x] (iii) PD-2 row citation at `epic-13-retro-2026-05-05.md:230` — re-read; verify the row text matches.
    - [x] (iv) Story 14.3 closure row at `docs/PHASE-3-CARRY-FORWARD.md:104` — re-read; verify Story 14.3 closure is recorded.
    - For any divergence: investigate and reconcile per Lesson 13.5-F + PD-2 before any subsequent task. Record verifications in Dev Notes §"Recursive self-validation log".

- [x] **Task 2 — Author the new B.4 `<critical>` block** (AC #1, #2, #3, #4, #6)
  - [x] 2.1 — Insertion-site decision: adjacent-after the B.2 block (instructions.xml:60) OR adjacent-before the B.2 block (instructions.xml:32, between PD-1 and B.2). Default pick: adjacent-after, with rationale in Completion Notes (preserves chronological PD-1 → B.2 → B.4 reading order). Adjacent-before remains AC6-acceptable if the dev-pass surfaces a structural argument for it.
  - [x] 2.2 — Open `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` at the chosen insertion site. For adjacent-after: insertion is at the existing blank line at `:61` (between B.2's `</critical>` close at `:60` and the `<step n="1" goal="Determine target story">` at `:62`); the new block replaces the blank line + adds a fresh trailing blank line.
  - [x] 2.3 — Compose the `<critical>` block opening: `<critical>` on its own line (matches B.2 block format at `:33`), preceded by 4-space indentation matching B.2's at-indent style (the B.2 block opens with `    <critical>` at column 5; verify by re-reading `:33` directly).
  - [x] 2.4 — Compose the block content. Mandatory elements (one acceptable canonical authoring; dev-pass may rephrase while preserving each load-bearing element):
    - Header line citing **B.4 / PD-2**: e.g., `📐 B.4 / PD-2 — figure-drift discipline.` (matches B.2's header style at `:36`: `📐 B.2 / Lesson 13.5-C — "mirrors prior arm" HALT signal.`).
    - Trigger surface (AC2): enumerates **figures**, **tables**, and **code blocks** as the artefact categories the discipline applies to; names the trigger as the **act of quoting or copying** an artefact from a prior story or retrospective.
    - Required action (AC3): names **validate against source-of-truth at draft time** with at least one concrete validation modality from architecture's example surface (re-read cited file:line / re-run cited command / re-extract cited table). Strong-imperative verb ("validate", "verify", "re-read", "re-check"). The qualifier "at draft time" or close variant ("drafting time", "before quoting").
    - Failure-mode statement: optional but encouraged — names the drift class being prevented (e.g., "drift accumulated since the original artefact was authored").
    - Closure cite (AC4): inline parenthetical citing **PD-2** AND **Epic 13 retro #1** — e.g., `(PD-2; Epic 13 retro #1)` or longer `(PD-2 — Story-drafter figure drift; Epic 13 retro #1, epic-13-retro-2026-05-05.md:230)`.
  - [x] 2.5 — Compose the `<critical>` block closing: `</critical>` on its own line, matching B.2's at-`:60` close style.
  - [x] 2.6 — Verify markdown / XML well-formedness of the inserted block: `<critical>` opens on its own line, `</critical>` closes on its own line, content is well-indented relative to the `<workflow>` parent block (matching B.2 / PD-1 indentation). No XML syntax errors introduced (the file is XML-by-form even though it doesn't carry a strict XML declaration).
  - [x] 2.7 — Verify the in-pass amendment moment per recursive self-validation: any figure quoted in the new block content (e.g., line ranges, byte counts) is re-validated at draft-time per the discipline being codified. For Task 2.4's "B.2 block at lines 33..60" reference, re-verify by reading `instructions.xml:33..60` directly during composition; document the verification in Dev Notes.

- [x] **Task 3 — Update `docs/PHASE-3-CARRY-FORWARD.md` Status** (per Story 14.1 / 14.2 / 14.3 precedent Tasks 7.1 / 3.1 / 3.1)
  - [x] 3.1 — § "Status Tracking" located at line :96+; B.3 closure row at `:104` used for shape-precedent (Story 14.3's row).
  - [x] 3.2 — B.4 row added at `docs/PHASE-3-CARRY-FORWARD.md:106` (or next available line in the table) immediately after the B.3-followup row at `:105`; close-out date 2026-05-08; closure note enumerates the AC5(a)..AC5(f) verdict criteria PASS results, the AC6 sibling-sequencing verdict (B.4 block adjacent to B.2), and the zero-binary-delta result. Format mirrors B.2 / B.3 row precedent.
  - [x] 3.3 — Confirm the existing B.4 row at `:35` Status column is unchanged in this task (the catalogue's main table at `:30..40` records the original carry-forward classification; only the §"Status Tracking" closure-tracking table at `:100+` gets the new row, per the Story 14.1 / 14.2 / 14.3 precedent).

- [x] **Task 4 — Verdict-criterion meta-pattern self-test** (AC #5; FR-P3-15)
  - [x] 4.1 — Grep verdict tests run (post-edit):
    - (a) `grep -nE '(figure[- ]drift|PD-2)' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` → expect ≥ 1 match in the new block range; record line numbers.
    - (b) `grep -nE 'figure|table|code block' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` → expect ≥ 3 distinct matches in the new block range (one per AC2 trigger category); record line numbers per category.
    - (c) `grep -nE 'source-of-truth|source of truth|draft time|drafting time' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` → expect ≥ 1 match in the new block range; record line numbers.
    - (d) `grep -nE 'PD-2|Epic 13 retro #1|epic-13 retro' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` → expect ≥ 1 match in the new block range; record line numbers.
    - (e) `grep -cE '<critical' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` → expect **18** post-edit (Δ = +1 vs. Task 1.5's pre-edit 17); record count.
  - [x] 4.2 — Recursive self-validation evidence (AC #5(f)) — Task 1.8 sub-tasks (i)..(iv) ran direct re-reads of source-of-truth files; outputs reproduced verbatim in Task 1.8 records and in Dev Notes §"Recursive self-validation log".
  - [x] 4.3 — All five verdict-test results (4.1(a)..(e)) plus AC5(f) recursive-self-validation evidence (4.2) recorded above and in Completion Notes; any in-pass spec-drift (mirror of Story 14.2 AC6(d) / Story 14.3 AC5(b)) handled in-pass not as PARTIAL.

- [x] **Task 5 — Post-edit binary + test regression check** (AC #8, #9)
  - [x] 5.1 — `make` check (kernel build path untouched by workflow-file edit; expect `Nothing to be done for 'all'` or equivalent). `wc -c build/antforth.com` post-edit. Δ = 0 vs. Task 1.1.
  - [x] 5.2 — `wc -c build/antforth_filesanity.com` post-edit. Δ = 0 vs. Task 1.2.
  - [x] 5.3 — `make test-repl 2>&1 | tee /tmp/14-4-post-edit.out` → expect 973 PASS / 0 FAIL. Zero movement from pre-edit baseline (Task 1.3).
  - [x] 5.4 — `make test` (assembly thread) → expect zero errors / warnings (informational; not a PARTIAL gate).
  - [x] 5.5 — `make test-file-sanity` → expect PASS (informational).

- [x] **Task 6 — S9 hardware-smoke disposition** (AC #8 / NFR-P3-7)
  - [x] 6.1 — **S9 exempt** — zero binary delta (workflow-file edit + carry-forward Status update only); per architecture §"Hardware-smoke cadence" — *"Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped."* Same exemption shape as Stories 14.1 / 14.2 / 14.3. Exemption recorded in Completion Notes; binary delta verified zero in Tasks 5.1 / 5.2.

- [x] **Task 7 — Carry-forward catalogue Status confirmation** (`docs/PHASE-3-CARRY-FORWARD.md` post-edit verification)
  - [x] 7.1 — § "Status Tracking" re-read; B.4 closure row correctly added at `:106` (or wherever Task 3.2 lands it) immediately after the B.3-followup row at `:105`; row content reproduced in Change Log below.

- [x] **Task 8 — Standing-commitment hold confirmation** (NFR-P3-22..33 subset relevant to 14.4)
  - [x] 8.1 — S1..S12 walk: confirm all twelve hold (see Completion Notes §"Standing-commitment walk (S1..S12)"). S3 sibling-discipline transition completed — B.2 fires at byte-budget-rationale review; B.3 fires at Pre-edit baseline capture; B.4 fires at figure-quoting moments — together they move "real-byte-count + figure-citation discipline" from why-surface to enforcement-surface across the authoring lifecycle.

- [x] **Task 9 — HALT-on-PARTIAL discipline check at story-close** (S5 / `feedback_no_preexisting_discharge.md`)
  - [x] 9.1 — AC #1..#9 walk in Completion Notes confirms no PARTIAL verdict; all nine ACs PASS (or the dev-pass HALTed earlier).
  - [x] 9.2 — `ls _bmad-output/implementation-artifacts/14-4-1*.md` → expect no match (no sibling-story spawn).

- [x] **Task 10 — Sprint-status update + Change Log + File List**
  - [x] 10.1 — `_bmad-output/implementation-artifacts/sprint-status.yaml` `14-4-pd-2-figure-drift-discipline-critical-block` row: from `ready-for-dev` (post-create-story workflow, this story file's authoring) → `in-progress` (at dev-pass start, Task 1) → `review` (at dev-pass close, this commit). Honest disposition recorded if the canonical three-state sequence wasn't actually executed (e.g., `backlog → review` shortcut, per Story 14.3 AC10.1 honest-disposition precedent).
  - [x] 10.2 — File List authored below.
  - [x] 10.3 — Change Log authored below.

---

## Dev Notes

### Why this story matters

PD-2 — "Story-drafter figure drift (story-template note 2.x scope)" — was identified in Epic 13's retrospective on 2026-05-05 (`epic-13-retro-2026-05-05.md:230`) as a Phase-3 carry-forward item. The retro classified it briefly without enumerating a worked incident; the carry-forward catalogue (`docs/PHASE-3-CARRY-FORWARD.md:35`) elevated it to a Medium-effort B.x item and slotted it in the story-template-discipline cluster (sibling of B.2 "mirrors prior arm" + B.3 "re-`wc -c`").

The pattern: a story drafter quoting a figure, table, or code block from a prior story or retrospective transcribes it without re-validating against the source-of-truth. The original artefact may have been amended since (a CR fix-pass adjusted a count; a new story superseded the prior story's verdict-table row; a retro action item changed a citation from `:88` to `:121`); the new story inherits the stale figure. Three concrete shapes of this drift have already been observed in Phase 2 / Epic 13.5:

1. **Lesson 13.5-F** — Story 13.5.5 wrote `25,002 / 26,467` into close-out documentation; actual binary was `24,996 / 26,461`. The drift was **between the same story's pre-build figures and post-build figures**. Caught at 13.5.6 audit-walk because the audit re-ran `wc -c`. Story 14.3 (B.3) closes the binary-handoff variant at the Pre-edit baseline workflow surface.
2. **Story 14.3 AC5(b) recursive moment** — the architecture's canonical Pre-edit baseline example uses `**Do not**` (markdown bold), but the AC's regex `Do not inherit|Don.?t inherit` couldn't match across the literal `**`. Resolved in-pass: drop the bold from the template literal, flag the architecture-doc canonical example as a candidate for next-doc-sync correction. The drift here was **between the AC text and the architecture's canonical example** — a micro-form of figure drift.
3. **Story 14.2 AC6(d) recursive moment** — the drafter's expected `<critical>` count of 1/2 (pre-edit/post-edit) reflected only multi-line blocks; actual was 16/17 (single-line inline directives missed). The drift here was **between the drafter's mental model of a count and the actual count**, surfaced by the verdict-criterion grep that B.2 codified. The same shape Story 14.4 will surface if the AC5(e) count expectation diverges from the directly-measured count.

**The B.4 discipline targets the broader pattern** — any quoted artefact, not just `<critical>` counts or binary sizes. A story citing "the architecture's table at line :347" inherits whatever line that table currently sits on; a CR fix-pass that adds rows above shifts the line; the citation rots. A story citing "the figure from Story X's Dev Notes" inherits Story X's figure; if Story X's figure was amended in a CR fix-pass after the citing story was drafted, the citation rots. **The discipline is straightforward** — re-validate at draft time, treat the prior artefact's reference as informational context only.

**The standing commitment exists in retro docs + carry-forward catalogue.** PD-2 lives in the *why* surface; PD-1's precedent showed that a *why*-surface discipline doesn't fire structurally — the drafter has to *remember* to invoke it (per `architecture.md:554..559`: *"Lives in the why surface, not the enforcement surface. Drafter has to remember to invoke it. CCD-P3-2 / S10 violation."*). **Story 14.4 lands the discipline at the enforcement surface** — the `<critical>` block in `instructions.xml` fires automatically at the moment the create-story workflow processes a draft, alongside PD-1's adversarial-review block (lines :20..31), B.2's "mirrors" block (lines :33..60), and B.3's `template.md` Pre-edit baseline section.

Sibling discipline note (the cluster): Story 14.2 (B.2) lands the structural enforcer for "mirrors prior arm" byte-budget shorthand (Lesson 13.5-C — fires at byte-budget-rationale review step); Story 14.3 (B.3) lands the structural enforcer for "re-`wc -c` at dev-pass start" (Lesson 13.5-F — fires at Pre-edit baseline capture step); Story 14.4 (B.4) lands the structural enforcer for "validate quoted figures against source-of-truth at draft time" (PD-2 — fires at any figure-quoting moment in the drafting workflow). All three are S3 / NFR-P3-24 / S10 / NFR-P3-31 enforcement-surface transitions; all three move discipline from why-surface (memory entries, retro discussions, carry-forward catalogue) to enforcement-surface (workflow files); together they form the **story-template-discipline cluster** of the lead-in. After Story 14.4 closes, Epic 14 has 4 of 5 lead-in items done (B.5 is Story 14.5).

### Recursive-self-validation note

Story 14.4 IS the structural enforcement for PD-2. Per S5 and the FR-P3-15 verdict-criterion meta-pattern, Story 14.4's own dev-pass MUST practice the discipline B.4 codifies — every figure / file:line / line-count this story quotes from a prior story or retro is re-validated against its source-of-truth at drafting time, not transcribed. The recursive-validation moments this story must navigate:

- Task 1.8(i) — re-reading `instructions.xml:33..60` to verify B.2 block exists and spans those lines (story body claims this multiple times); divergence → investigate.
- Task 1.8(ii) — re-reading `architecture.md` at the cited lines (`:262`, `:410..422`, `:605`, `:935`); divergence → investigate (architecture-doc may have been amended since story drafting).
- Task 1.8(iii) — re-reading PD-2 row at `epic-13-retro-2026-05-05.md:230`; this should be stable (retros don't typically get amended).
- Task 1.8(iv) — re-reading Story 14.3 closure row at `docs/PHASE-3-CARRY-FORWARD.md:104`; this row was added by Story 14.3's dev-pass and should be stable.

Stories 14.1 / 14.2 / 14.3 each had analogous recursive moments (Story 14.2 AC6(d) `<critical>` count drift; Story 14.3 AC5(b) regex vs. markdown-bold drift). Story 14.4 should expect a similar moment — possibly around the AC5(e) `<critical>` count expectation (current value 17 pre-edit; if any `<critical>` directive has been added or removed in the workflow header since this story was drafted, the baseline diverges and the AC needs an in-pass amendment of the same shape Story 14.2 used).

### Prior-story intelligence (Stories 14.1 / 14.2 / 14.3 — directly relevant)

**Story 14.1 (B.1 — PAD canonical doc)** at `_bmad-output/implementation-artifacts/14-1-pad-documented-as-canonical-transient-buffer-for-test-authors.md`:
- Story 14.4's grand-grand-predecessor in Epic 14. Closed 2026-05-08 (commit 274062a) with zero binary delta. Inheritable shape: doc/workflow-only; FR-P3-15 verdict-criterion meta-pattern; S9 documented exempt; carry-forward Status row update at story-close.
- Story 14.1 surfaced and reconciled the v2.0.0-banner-bump 1-byte drift (24,996 documented vs. 24,995 actual). Story 14.4 inherits this reconciliation but practices the B.3 + B.4 disciplines from the file system rather than transcribing.

**Story 14.2 (B.2 — "mirrors prior arm" HALT-signal lint)** at `_bmad-output/implementation-artifacts/14-2-mirrors-prior-arm-halt-signal-lint-in-story-template.md`:
- Story 14.4's **closest sibling** in Epic 14 — both edit `instructions.xml`, both add `<critical>` blocks, both follow the PD-1 precedent. Story 14.2 closed 2026-05-08 (commit 80f99c8) with zero binary delta. The B.2 block at `instructions.xml:33..60` is the **structural template** the new B.4 block follows; AC6 mandates B.4 lands adjacent to B.2.
- Story 14.2's AC6(d) recursive-self-validation moment is directly informative — the drafter's expected `<critical>` count (1/2 pre/post-edit; multi-line blocks only) diverged from actual (16/17; multi-line + inline). Story 14.4's AC5(e) inherits the corrected count metric (17 pre-edit; +1 post-edit = 18) and Task 1.5 captures the pre-edit baseline directly. **Per B.4 discipline, do NOT transcribe Story 14.2's "16/17" or its corrected metric — re-measure directly.** The post-Story-14.3 baseline is 17 pre-edit (Story 14.3 added zero `<critical>` blocks); Task 1.5 verifies.
- Story 14.2 also carries the **honest-disposition pattern** at AC7 — when a structural AC's wording can't actually be satisfied (installer-manifest enumerates modules not files; `_bmad/` is gitignored), the AC is dispositioned as "constraint named, not closed". Story 14.4 AC7 inherits this verbatim.

**Story 14.3 (B.3 — re-`wc -c` at dev-pass start)** at `_bmad-output/implementation-artifacts/14-3-story-to-story-binary-handoff-re-wc-c-at-dev-pass-start.md`:
- Story 14.4's **immediate predecessor** in Epic 14. Closed 2026-05-08 (commit 64e91bf) with zero binary delta. Reported figures: 24,995 / 26,460. **Story 14.4 MUST re-measure these directly at Pre-edit Task 1, not transcribe** — this is the B.3 discipline Story 14.3 codified, applied forward to Story 14.4's own dev-pass.
- Story 14.3's recursive-self-validation moment was AC5(b) regex vs. architecture's `**Do not**` markdown bold. Resolved in-pass by dropping the bold from the template literal; architecture-doc one-line correction filed as B.3-followup at `docs/PHASE-3-CARRY-FORWARD.md:105`. Story 14.4 should expect a similar in-pass amendment moment, most likely around AC5(e)'s count baseline.
- Story 14.3's CR fix-pass surfaced the L2 finding ("Story body is heavy — 540 lines for a 7-line template diff + 1-row carry-forward update") as feedback for Story 14.4+ shape. **Story 14.4 partially heeds this**: the per-component byte-budget table is preserved (B.2 lint compliance is structural; can't be cut); the prior-story-intelligence section is preserved (PD-2 / B.4 directly inherits Stories 14.1/14.2/14.3 patterns); the Severity table is preserved (architecture pin); the standing-commitment walk is condensed (Task 8.1 references the walk rather than re-enumerating). **L2 disposition: workflow-discipline-template change is out of scope for this story; recorded as Epic 14 retrospective input.**

**PD-1 precedent (Story 13.5.0 — workflow & create-story AC alignment)** at `_bmad-output/implementation-artifacts/13.5-0-pd-1-workflow-and-create-story-ac-alignment.md`:
- The **structural precedent** for any workflow-file edit in Phase 3 — and the *first* `<critical>` block added to `instructions.xml` (lines :20..31). PD-1's persistence model has held for ~3 days (since 2026-05-05) without an installer re-run. Story 14.4's `<critical>` block edit inherits the same persistence model. AC7 names the constraint per Story 14.2 / 14.3 honest-disposition pattern.

**Epic 13 retro PD-2 row** at `_bmad-output/implementation-artifacts/epic-13-retro-2026-05-05.md:230`:
- The motivating row: `| 1 | PD-2 — Story-drafter figure drift (story-template note 2.x scope) | ⏳ Phase-3 carry-forward |`. The retro classified PD-2 briefly without enumerating a worked incident; the discipline is informed by the related Lesson 13.5-F worked incident (Story 13.5.5 6-byte close-out drift) plus the Story 14.2 AC6(d) and Story 14.3 AC5(b) recursive-validation moments. **The B.4 discipline generalises the figure-drift class beyond binary handoff** (B.3) to any quoted artefact in any drafting context.

### Architecture context (Phase-3 architecture, 2026-05-08)

`_bmad-output/planning-artifacts/architecture.md` pins the following for Story 14.4 (each cited line:column re-verified at Task 1.8(ii) per B.4 discipline):

- **§"B.4-D1: PD-2 figure-drift discipline"** (line 262) — Edit lands in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (sibling of B.2) as a `<critical>` block. Block requires figures, tables, code blocks to be validated against the source-of-truth at draft time, not inherited from earlier stories or retros.
- **§"`<critical>` block format example (B.2 / B.4 pattern)"** (line 410..422) — multi-line block; opens with `<critical>` on its own line; content states the trigger surface and required action; closes with `</critical>` on its own line; inline cite parenthetical at end.
- **§"Verdict-criterion meta-pattern (all four)"** (line 264..268) — B.4 row at line :268: "the figure-drift `<critical>` block exists in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` and is grep-able". Story 14.4 AC #5 implements this verdict criterion (with the recursive-self-validation extension at AC #5(f)).
- **§"Implications for B.x verdict criteria"** (line 217) — "If a lead-in fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration". Story 14.4 ACs #5, #8, #9 + Tasks 4, 5 enforce this structurally.
- **§"Per-story binary delta envelopes"** (line 343..346) — B.2 / B.3 / B.4 = 0 (workflow-file only). Story 14.4 AC #8 enforces.
- **§"Hardware-smoke cadence (S9 / NFR-P3-7)"** (line 456) — "Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped". Story 14.4 AC #8 + Task 6.1 implement this.
- **§"Existing files modified in Phase 3"** (line 605) — `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml | Add <critical> block for "mirrors prior arm" HALT signal (B.2); add <critical> block for figure-drift discipline (B.4) | B.2, B.4`. Story 14.4 lands the B.4 row.
- **§"Recommended sequencing within the lead-in"** (line 932..937; B.4 specifically at :935) — "**B.2 + B.4** together — `<critical>` blocks added to `instructions.xml` (sibling edits, single dev-pass)". Story 14.4 honours the *file-level adjacency* via AC6 even though the dev-pass sequencing was de-coupled (B.2 closed in Story 14.2 standalone).
- **§"Workflow-file edit identity"** (line 395..400) — Drafting `<critical>` blocks → `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (the architecturally-pinned edit site). Story 14.4 lands the edit in that file (no alternative considered).
- **§"All Phase-3 dev-pass agents MUST"** items 3 + 9 (line 478, 484) — "Land workflow-file edits in their designated files (CCD-P3-2 mapping)" and "Re-`wc -c` at the start of every dev-pass". Story 14.4 honours both: edit in `instructions.xml` per CCD-P3-2; Pre-edit Task 1.1 re-`wc -c`s directly per B.3.
- **§"Pattern enforcement mechanisms"** (line 488) — "Structural lints in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (B.2/B.4 `<critical>` blocks) catch drafting-discipline gaps at draft time". Story 14.4 IS the surface for B.4 in this enumeration.

### PRD Phase-3 context (2026-05-08)

`_bmad-output/planning-artifacts/prd.md` for Story 14.4's binding requirements:

- **FR-P3-14 (B.4)** at `prd.md` (per `epics.md:210` mapping) — the figure-drift discipline `<critical>` block in `instructions.xml`. Story 14.4 IS the structural surface of FR-P3-14.
- **FR-P3-15 (verdict-criterion meta-pattern)** — each B.x lead-in story tests that the new template would have caught the prior-incident pattern. Story 14.4 AC #5 + Task 4 implement B.4's surface of FR-P3-15.
- **FR-P3-22..25 (phase-wide regression constraint)** — 973 PASS / 0 FAIL baseline + CODE-source byte-identical assembly + unprefixed numeric-literal form preserved. Story 14.4's AC #9 enforces the 973 PASS / 0 FAIL gate.
- **NFR-P3-2 (Phase-3-specific cumulative ROM budget)** — +200 bytes cap (24,996 → ≤ 25,200); B.4 envelope 0 bytes. Story 14.4's AC #8 enforces.
- **NFR-P3-7 (S9 codification)** — every binary-delta story runs hardware smoke; zero-binary-delta stories document exemption explicitly. Story 14.4's AC #8 + Task 6.1 enforce. Same exemption shape as Stories 14.1 / 14.2 / 14.3.
- **NFR-P3-18 (story-template discipline as quality attribute)** — "The story-template lints / HALT signals / pre-edit task additions established by B.1–B.5 fire automatically when triggered (lint catches 'mirrors' phrase, `wc -c` task captures actual binary, **figure-drift discipline applies at draft time**, PRD-vs-architecture sync runs at doc-build time). A story drafter does not need to remember to invoke them; they are baked into the workflow." Story 14.4 IS the structural surface of NFR-P3-18 for the figure-drift discipline.
- **NFR-P3-24 (S3 — real-byte-count estimation + capstone-aware drafting)** — Story byte-budget rationale is itemised per-part. Story 14.4's per-component itemisation in the Severity table (the byte-budget table above) demonstrates the discipline; the rationale is itemised, not "mirrors Stories 14.1/14.2/14.3 shape".
- **NFR-P3-31 (S10 — workflow > memory > prompt)** — Process discipline lives in workflow files, not in conversational prompts or memory entries. Story 14.4's edit lands in the workflow file (`instructions.xml`, per CCD-P3-2), not in a memory entry like `feedback_no_figure_drift.md` (which would be the architecture §"Bad — workflow edit (anti-pattern)" violation).

### Implementation site references (file:line)

(All references re-verified at Task 1.8 per B.4 discipline; verifications recorded in Recursive self-validation log below at dev-pass time.)

- **Target file** — `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (388 lines as of post-Story-14.3 close, commit 64e91bf)
- **Insertion site** — line :61 (the existing blank line between B.2's `</critical>` close at :60 and the `<step n="1" goal="Determine target story">` opening at :62), replaced by the new B.4 block + a fresh trailing blank line
- **Adjacent-after sibling** — B.2 block at `instructions.xml:33..60` (closed 2026-05-08 by Story 14.2 commit 80f99c8)
- **PD-1 precedent block** — `instructions.xml:20..31` (closed 2026-05-05 by Story 13.5.0 commit; first `<critical>` block in the file)
- **Architecture B.4 spec** — `_bmad-output/planning-artifacts/architecture.md:262` (§"B.4-D1: PD-2 figure-drift discipline")
- **Architecture canonical block-format example** — `_bmad-output/planning-artifacts/architecture.md:410..422` (§"`<critical>` block format example (B.2 / B.4 pattern)")
- **Architecture verdict criterion** — `_bmad-output/planning-artifacts/architecture.md:264..268` (§"Verdict-criterion meta-pattern (all four)" — B.4 row at :268)
- **Architecture sequencing recommendation** — `_bmad-output/planning-artifacts/architecture.md:932..937` (§"Recommended sequencing within the lead-in" — B.2 + B.4 together at :935)
- **Architecture pattern enforcement** — `_bmad-output/planning-artifacts/architecture.md:488` (§"Pattern enforcement mechanisms" line 1: "Structural lints in `instructions.xml` (B.2/B.4 `<critical>` blocks) catch drafting-discipline gaps at draft time")
- **Concrete prior PD row** — `_bmad-output/implementation-artifacts/epic-13-retro-2026-05-05.md:230` (PD-2 row in §"Documented Follow-Up Opportunities")
- **Carry-forward catalogue B.4 row** — `docs/PHASE-3-CARRY-FORWARD.md:35` (current row; classification + notes — Status remains in §"Status Tracking" closure-tracking table at :100+)
- **Carry-forward catalogue Status Tracking section** — `docs/PHASE-3-CARRY-FORWARD.md:96..` (Story 14.3's B.3 closure row at `:104` for shape precedent; B.3-followup row at `:105`)
- **BMAD installer manifest** — `_bmad/_config/manifest.yaml` (per-module manifest; bmm module owns the workflow-tree per `:13..19`; per-file manifest does NOT exist — see AC7 reading per Story 14.2 / 14.3 honest-disposition precedent)
- **Epics 14.4 spec** — `_bmad-output/planning-artifacts/epics.md:372..392` (Story 14.4 ACs #1..#9 verbatim)
- **Epic 14 shape** — `_bmad-output/planning-artifacts/epics.md:292..305` (Epic 14 lead-in cluster)
- **Predecessors** — Stories 14.1 / 14.2 / 14.3 at `_bmad-output/implementation-artifacts/14-{1,2,3}-*.md` (closed 2026-05-08, zero binary delta each)

### Recursive self-validation log (populated at dev-pass — empty at draft time)

(This section IS the structural enforcement of B.4 — the very discipline this story codifies. Each cited file:line below MUST be re-validated by direct re-read at Pre-edit Task 1.8 during dev-pass, with the verification result recorded below the corresponding bullet. Empty at draft time; populated at dev-pass.)

- [x] **(i)** `instructions.xml:33..60` — B.2 block exists and spans these lines. **Verification:** VERIFIED by direct re-read at dev-pass — line 33 opens `  <critical>📐 B.2 / Lesson 13.5-C — "mirrors prior arm" HALT signal.`; line 60 closes `    shorthand — see epic-13.5-retro-2026-05-07.md:84..118.)</critical>`. Block boundaries match; span [33,60] confirmed. **Two task-spec divergences caught**: (1) Task 2.3 / AC1 claimed B.2 opens with 4-space indent — actual is 2-space (`  <critical>` at column 3); (2) Task 2.5 / AC1 claimed B.2 closes with `</critical>` on its own line — actual is inline (`...:84..118.)</critical>` on the same line as last content). In-tree precedent (B.2 / PD-1) wins per AC5(f) discipline; the new B.4 block follows the actual in-tree format, not the task-spec's mistaken description.
- [x] **(ii.a)** `architecture.md:262` — B.4-D1 section exists at this line with the cited content. **Verification:** VERIFIED by direct re-read — line 262 reads `**B.4-D1: PD-2 figure-drift discipline.** Edit lands in \`_bmad/bmm/workflows/4-implementation/create-story/instructions.xml\` (sibling of B.2) as a \`<critical>\` block. ...` Content matches story citation exactly.
- [x] **(ii.b)** `architecture.md:410..422` — `<critical>` block format example exists at these lines. **Verification:** VERIFIED by direct re-read — line 410 reads `**\`<critical>\` block format example (B.2 / B.4 pattern):**`; example block follows at lines 412..422 with the canonical XML shape. Note: architecture's canonical example uses `</critical>` on its own line (line 421), but the in-tree B.2/PD-1 precedents use inline close — this internal architecture-vs-precedent inconsistency is the same shape Story 14.3 AC5(b) surfaced (architecture vs. template literal); resolved here by following in-tree precedent.
- [x] **(ii.c)** `architecture.md:605` — "Existing files modified in Phase 3" row for B.2/B.4 exists at this line. **Verification:** VERIFIED by direct re-read — line 605 reads `| \`_bmad/bmm/workflows/4-implementation/create-story/instructions.xml\` | Add \`<critical>\` block for "mirrors prior arm" HALT signal (B.2); add \`<critical>\` block for figure-drift discipline (B.4) | B.2, B.4 |`. Row matches.
- [x] **(ii.d)** `architecture.md:935` — "B.2 + B.4 together" sequencing recommendation exists at this line. **Verification:** VERIFIED by direct re-read — line 935 reads `2. **B.2 + B.4** together — \`<critical>\` blocks added to \`instructions.xml\` (sibling edits, single dev-pass)`. Row matches.
- [x] **(iii)** `epic-13-retro-2026-05-05.md:230` — PD-2 row exists at this line with the cited content. **Verification:** VERIFIED by direct re-read — line 230 reads `| 1 | PD-2 — Story-drafter figure drift (story-template note 2.x scope) | ⏳ Phase-3 carry-forward |`. Row matches.
- [x] **(iv)** `docs/PHASE-3-CARRY-FORWARD.md:104` — Story 14.3 closure row exists at this line. **Verification:** VERIFIED by direct re-read — line 104 starts `| B.3 | ✅ Done | Story 14.3 / 2026-05-08 — new \`### Pre-edit baseline\` subsection ...`. Row exists, Story 14.3 closure recorded.

If any verification surfaces a divergence (cited line:col content differs from current source-of-truth), root-cause investigation precedes any subsequent task per Lesson 13.5-F + PD-2. The divergence itself is evidence of the drift class B.4 codifies discipline against, and is documented in Completion Notes as a verdict-criterion-passing recursive-self-validation moment.

### Pre-edit baseline reconciliation — documentation-drift note

Per Stories 14.1 / 14.2 / 14.3 Pre-edit baseline reconciliations (and original `13.5-6-…md` Task 2 Documentation-drift reconciliation, Epic-13.5 close-out), the Phase-3 PRD + architecture + epics docs **all cite 24,996 bytes** as the post-Epic-13.5 baseline. The actual current build at HEAD `64e91bf` (the Story-14.3 commit) is **24,995 bytes** — 1 byte less than the documented Epic-13.5-close figure. This is the v2.0.0 banner-bump drift Story 14.1 surfaced and reconciled.

This reconciliation is **not a Story-14.4 regression** — it's the same illustrative inheritance-drift artefact carried from Story 13.5.6's close, confirmed unchanged through Stories 14.1 / 14.2 / 14.3 closes, and re-confirmed at Story 14.4's Pre-edit Task 1.1. **Per the disciplines this story (B.4) and Story 14.3 (B.3) codify**, the Pre-edit Task 1.1 / 1.2 re-`wc -c`s directly rather than inheriting any prior story's reported number. Expected directly-measured figures: 24,995 / 26,460 (matching Stories 14.1 / 14.2 / 14.3's reports — they are the most-recent-prior-story reported values, not gospel; Pre-edit Task 1.1 verifies). If the directly-measured figures diverge, the divergence is evidence of the doc-drift class B.3 + B.4 prevent and must be investigated per Lesson 13.5-F + PD-2 before the dev-pass proceeds.

### Project Structure Notes

- **No new architectural surface.** Story 14.4 modifies one existing file (`_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`) and updates one Status row (`docs/PHASE-3-CARRY-FORWARD.md` §"Status Tracking" — adding Story 14.4 closure row). Per `architecture.md` §"Project Structure & Boundaries", the kernel boundary is frozen for Phase 3 — Story 14.4 does not touch any `src/*.asm` file.
- **Workflow-file boundary alignment.** Per `architecture.md` §"Workflow-file edit identity" line 395..400 + §"Existing files modified in Phase 3" line 605: B.4's edit lands in `instructions.xml`. Story 14.4 lands the artefact in the architecturally-pinned file (no alternative location considered).
- **Block placement decision.** AC6 mandates adjacency to B.2 (currently at `:33..60`). Adjacent-after (insertion at `:61`) is the recommended placement because it preserves the chronological PD-1 → B.2 → B.4 reading order in the file (process-discipline lints accumulate over time; reading them in codification order makes the discipline-history of the file visible to a future drafter). Adjacent-before (insertion between PD-1 at `:31` and B.2 at `:33`) remains AC-acceptable. Final pick documented in Completion Notes per Task 2.1.
- **No installer-manifest edit.** Per AC7 reading (Story 14.2 / 14.3 honest-disposition precedent): the actual installer manifest at `_bmad/_config/manifest.yaml` enumerates *modules*, not per-file edit lists. Story 14.4 does NOT edit the installer manifest. PD-1 (Story 13.5.0), B.2 (Story 14.2), B.3 (Story 14.3) are the working precedents — their workflow-tree edits have persisted at the file level since 2026-05-05 / 2026-05-08 dev-passes without any installer-manifest entries, because no installer re-run has occurred. Story 14.4 inherits the same persistence model. AC7 disposition = "constraint named, not closed".

### Standards / discipline citations

- **PD-2** ("Story-drafter figure drift") — `epic-13-retro-2026-05-05.md:230`
- **Lesson 13.5-F** ("Documentation drift between stories is a real failure mode.") — `epic-13.5-retro-2026-05-07.md:121` (related discipline; B.3 closes binary-handoff variant; B.4 generalises to any quoted artefact)
- **Standing commitment S3** (real-byte-count estimation + capstone-aware drafting) — codified as NFR-P3-24. Sibling discipline cluster: B.2 fires at byte-budget-rationale review; B.3 fires at Pre-edit baseline capture; B.4 fires at any figure-quoting moment.
- **Standing commitment S10** (workflow > memory > prompt) — codified as NFR-P3-31; per architecture §"Bad — workflow edit (anti-pattern)" line 554..559
- **CCD-P3-2** (Process discipline lives in workflow files) — `architecture.md:197..217`
- **PD-1 enforcer pattern** — `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:20..31` (the workflow-file-edit-discipline precedent; first `<critical>` block in the file)
- **B.2 enforcer block (Story 14.2)** — `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:33..60` (sibling discipline; B.4 lands adjacent per AC6)
- **B.3 enforcer block (Story 14.3)** — `_bmad/bmm/workflows/4-implementation/create-story/template.md:19..23` (sibling discipline at the template-file site; cross-file enforcement-surface cluster)

### Standing-commitment context (S1..S12)

Per Epic-13.5 retro 2026-05-07, all 12 standing commitments held across the retro and were codified as NFR-P3-22..33 in the Phase-3 PRD. For Story 14.4 — abbreviated walk per Story 14.3 L2 feedback (the full S1..S12 walk with per-row text was preserved in Stories 14.1/14.2/14.3; Story 14.4 references the codified pattern rather than re-enumerating):

- **S1, S5, S8** — adversarial review fresh-context external; PARTIAL→HALT; no "pre-existing" discharge for correctness defects: ACs do NOT enumerate in-pass adversarial review; AC #5 / #8 / #9 carry HALT discipline; AC7 names the installer-manifest constraint per honest-disposition pattern (Story 14.2 / 14.3 precedent).
- **S2, S9** — REPL-piped tests as default; per-story hardware smoke: workflow-file-edit-only story; no new tests; S9 exempt + documented (AC #8 + Task 6.1).
- **S3** — real-byte-count estimation + capstone-aware drafting: cluster-completion (B.2 + B.3 + B.4) move S3 from why-surface to enforcement-surface across the authoring lifecycle.
- **S4** — AC composition: ACs #1..#9 stand alone or compose cleanly with named antecedents.
- **S10** — workflow > memory > prompt: new `<critical>` block lands in `instructions.xml` (workflow-tree file), NOT in a memory entry. No S10 violation.
- **S11** — version-surface audit: not tag-applicable; banner-bump optional per Ant's call (Epic 14 §"Shape").
- **S12** — hardware-typed probe authoring discipline: not directly engaged.

Full S1..S12 walk recorded in Completion Notes at story-close.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:292..305`] Epic 14: Phase-3 Process Foundation — lead-in cluster B.1..B.5
- [Source: `_bmad-output/planning-artifacts/epics.md:372..392`] Story 14.4 ACs #1..#9 verbatim
- [Source: `_bmad-output/planning-artifacts/epics.md:210`] FR-P3-14 (B.4) — story-template figure-drift discipline (`<critical>` block)
- [Source: `_bmad-output/planning-artifacts/epics.md:211`] FR-P3-15 verdict-criterion meta-pattern
- [Source: `_bmad-output/planning-artifacts/architecture.md:197..217`] CCD-P3-2 — Process discipline lives in workflow files
- [Source: `_bmad-output/planning-artifacts/architecture.md:217`] Implications for B.x verdict criteria (discipline-as-deliverable)
- [Source: `_bmad-output/planning-artifacts/architecture.md:262`] B.4-D1 architectural decision
- [Source: `_bmad-output/planning-artifacts/architecture.md:264..268`] B.4 verdict criterion (block grep-able from `instructions.xml`)
- [Source: `_bmad-output/planning-artifacts/architecture.md:343..346`] Per-story binary delta envelope (B.4 = 0 bytes)
- [Source: `_bmad-output/planning-artifacts/architecture.md:395..400`] Workflow-file edit identity (`instructions.xml` owns drafting `<critical>` blocks)
- [Source: `_bmad-output/planning-artifacts/architecture.md:410..422`] `<critical>` block format example (B.2 / B.4 pattern)
- [Source: `_bmad-output/planning-artifacts/architecture.md:456`] Hardware-smoke cadence (S9 exemption for B.1–B.5)
- [Source: `_bmad-output/planning-artifacts/architecture.md:478,484`] All Phase-3 dev-pass agents MUST items 3 + 9 (workflow-file edit landing site; re-`wc -c` discipline)
- [Source: `_bmad-output/planning-artifacts/architecture.md:488`] Pattern enforcement mechanisms (B.2/B.4 `<critical>` blocks catch drafting-discipline gaps)
- [Source: `_bmad-output/planning-artifacts/architecture.md:605`] Existing files modified in Phase 3 (B.4 `<critical>` block in `instructions.xml`)
- [Source: `_bmad-output/planning-artifacts/architecture.md:932..937`] Recommended sequencing within the lead-in (B.2 + B.4 together)
- [Source: `_bmad-output/implementation-artifacts/13.5-0-pd-1-workflow-and-create-story-ac-alignment.md`] PD-1 precedent — first `<critical>` block in `instructions.xml`
- [Source: `_bmad-output/implementation-artifacts/14-1-pad-documented-as-canonical-transient-buffer-for-test-authors.md`] Story 14.1 (B.1) — predecessor story shape template
- [Source: `_bmad-output/implementation-artifacts/14-2-mirrors-prior-arm-halt-signal-lint-in-story-template.md`] Story 14.2 (B.2) — closest sibling (same edit site; same block-format precedent); honest-disposition pattern at AC7; recursive-self-validation moment at AC6(d)
- [Source: `_bmad-output/implementation-artifacts/14-3-story-to-story-binary-handoff-re-wc-c-at-dev-pass-start.md`] Story 14.3 (B.3) — immediate predecessor; recursive-self-validation moment at AC5(b); Pre-edit baseline subsection precedent
- [Source: `_bmad-output/implementation-artifacts/epic-13-retro-2026-05-05.md:230`] PD-2 row — motivating retro item
- [Source: `_bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md:121`] Lesson 13.5-F formal row (related discipline; binary-handoff variant of figure drift)
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`] Target file (388 lines pre-Story-14.4)
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:20..31`] PD-1 `<critical>` block — workflow-file-edit precedent (first block in file)
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:33..60`] B.2 `<critical>` block — sibling block (B.4 lands adjacent per AC6)
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/template.md:19..23`] B.3 Pre-edit baseline subsection — sibling discipline at template-file site
- [Source: `_bmad/_config/manifest.yaml:13..19`] BMAD installer manifest (module-level; no per-file enumeration)
- [Source: `docs/PHASE-3-CARRY-FORWARD.md:35`] B.4 carry-forward catalogue row
- [Source: `docs/PHASE-3-CARRY-FORWARD.md:104`] B.3 closure row (Story 14.3) — shape precedent for B.4 closure row

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

- Pre-edit baseline run: `/tmp/14-4-pre-edit.out` (973 PASS / 0 FAIL on commit 64e91bf)
- Post-edit regression run: `/tmp/14-4-post-edit.out` (973 PASS / 0 FAIL post-B.4 block insertion)

### Completion Notes List

#### Verdict-criterion summary (AC #5)

All five verdict tests PASS (with one in-pass amendment per AC5(e) honest disposition note + AC5(f) recursive-self-validation discipline):

- **(a)** `grep -nE '(figure[- ]drift|PD-2)' instructions.xml` → 2 matches in new block range [62,86]: line 62 (`📐 B.4 / PD-2 — figure-drift discipline.`), line 80 (`(PD-2 — Story-drafter figure drift; Epic 13 retro #1,`). ✅ ≥1 expected.
- **(b)** `grep -nE 'figure|table|code block' instructions.xml` → 9 matches in new block range covering all 3 categories: figures at lines 62, 65, 70, 75, 78, 80; tables at lines 66, 70, 73; code blocks at lines 67, 70. ✅ ≥3 distinct categories present.
- **(c)** `grep -nE 'source-of-truth|source of truth|draft time|drafting time' instructions.xml` → 2 matches in new block range: line 71 (`of-truth at draft time before relying on it`), line 79 (`the drafter re-validates at draft time.`). ✅ ≥1 expected.
- **(d)** `grep -nE 'PD-2|Epic 13 retro #1|epic-13 retro' instructions.xml` → 2 matches in new block range: line 62 (`B.4 / PD-2`), line 80 (`PD-2 — Story-drafter figure drift; Epic 13 retro #1`). ✅ ≥1 expected.
- **(e)** `grep -cE '<critical' instructions.xml` → **19 post-edit** (pre-edit 17 captured at Task 1.5; **Δ = +2**, NOT the drafter's expected +1). **In-pass amendment per AC5(e) honest disposition note + Story 14.2 AC6(d) precedent**: the count metric uses `<critical` (no closing-bracket anchor) so it counts both inline directives, multi-line block openings, **and** in-block textual references to the literal string `<critical>`. The new B.4 block contributes (i) the new opening `<critical>` tag at line 62 (+1), and (ii) the recursive-precedents sub-clause within the AC4 closure parenthetical at lines 84..86 — specifically the literal `` `<critical>` `` reference at line 85 (+1). The drafter's mental model of "+1 for the new block opening" undercounted; direct measurement gives +2. Resolution: amend AC5(e) expectation in-pass from `Δ = +1` to `Δ = +2`, document recursive moment per AC5(f). NOT a HALT — this is the same shape Story 14.2 AC6(d) and Story 14.3 AC5(b) handled in-pass. The discipline B.4 codifies (re-validate at draft time, treat the prior story's reproduction as informational only) is itself the resolution mechanism: direct measurement (19) is the source-of-truth, mental-model expectation (+1 from +17 = 18) was the inheritance.

#### AC5(f) recursive self-validation moments

**Four** recursive self-validation moments surfaced during Story 14.4's dev-pass — three caught in-pass at dev-pass time, one caught post-/CR adversarial review:

1. **AC1 / Task 2.3 indent claim** (in-pass) — story spec claimed B.2 opens with `    <critical>` at 4-space column 5; direct re-read of `:33` shows `  <critical>` at 2-space column 3. **Resolution**: in-tree precedent wins (B.2 + PD-1 both use 2-space open indent); new B.4 block matches the actual in-tree format.
2. **AC1 / Task 2.5 close-style claim** (in-pass) — story spec + AC1 claimed B.2 closes with `</critical>` on its own line; direct re-read of `:60` shows `</critical>` is inline with last content character (`...:84..118.)</critical>`). The architecture canonical example at `:410..422` does close on its own line, but the in-tree precedents (B.2 + PD-1) close inline. **Resolution**: in-tree precedent wins; new B.4 block closes inline. Internal architecture-vs-precedent inconsistency tracked as **B.4-followup** in `docs/PHASE-3-CARRY-FORWARD.md` (added at /CR fix-pass; same shape as Story 14.3's B.3-followup row, prevents the deferral from rotting in story prose only per S10/NFR-P3-31).
3. **AC5(e) `<critical>`-count expectation** (in-pass) — story spec expected `Δ = +1` from the new opening tag; direct measurement gives `Δ = +2` (the recursive-precedents sub-clause at lines 84..86 contains a literal `` `<critical>` `` reference at line 85 that the no-closing-bracket count metric catches). **Resolution**: amend in-pass per Story 14.2 AC6(d) precedent; the recursive discipline IS the resolution mechanism.
4. **Sprint-status pre-dev-pass-state claim** (caught at /CR) — Completion Notes §"Sprint-status transition" originally claimed pre-dev-pass state was `ready-for-dev` and that the canonical three-state sequence executed; direct read of `git show 64e91bf:_bmad-output/implementation-artifacts/sprint-status.yaml` shows pre-dev-pass state was `backlog`, transition was single-step `backlog → review`. The "ready-for-dev" figure was inherited (transcribed) without re-validation — exactly the failure mode B.4 codifies discipline against, surfaced in B.4's own dev-pass. **Resolution**: corrected at /CR fix-pass; honest disposition recorded; `sprint-status.yaml` filed as candidate enrichment to the AC5(f) pre-flight re-read list for future B-cluster stories. The in-pass discipline (AC5(f) Task 1.8) had not included sprint-status.yaml in the source-of-truth re-read list; had it been included, the figure-drift would have been caught at pre-flight.

All four Task 1.8(i)..(iv) pre-flight verifications (B.2 block boundaries, four architecture line:column refs, PD-2 retro row, Story 14.3 closure row) re-read directly during dev-pass and verified unchanged. The fifth recursive moment (sprint-status pre-dev-pass-state) escaped pre-flight because Task 1.8 did not enumerate sprint-status.yaml as a source-of-truth file — surfaced and corrected at /CR.

#### AC walk (#1..#9) — no PARTIAL

| AC | Verdict | Evidence |
|---|---|---|
| #1 | PASS | New `<critical>` block at `instructions.xml:62..86`; multi-line; addresses figure-drift / PD-2. |
| #2 | PASS | Block enumerates "figure"/"figures" + "table"/"tables" + "code block(s)" explicitly; trigger named as "quote or copy an artefact from a prior story or retrospective". Verdict (b) confirms ≥3 category matches in block range. |
| #3 | PASS | "Validate" (strong-imperative) + "at draft time" + concrete modalities ("re-read the cited file:line directly, re-run the cited command, or re-extract the cited table from the cited document"); failure-mode named ("Drift accumulates between artefact authoring and citation..."). |
| #4 | PASS | Block cites `(PD-2 — Story-drafter figure drift; Epic 13 retro #1, epic-13-retro-2026-05-05.md:230. ...)`. |
| #5 | PASS (with /CR amendment) | All five verdict tests PASS (with AC5(e) in-pass amendment per honest disposition note); AC5(f) recursive-self-validation completed for all four pre-flight items + four additional moments (three caught in-pass: Task 2.3/2.5 indent/close-style, AC5(e) count; one caught at /CR: sprint-status pre-dev-pass-state). The /CR-caught moment IS the figure-drift class B.4 codifies — surfaced during the very review of B.4's discipline-as-deliverable verdict. Filed candidate enrichment to AC5(f) pre-flight re-read list (add sprint-status.yaml). |
| #6 | PASS | New block at `:62..86` adjacent-after B.2 block (`:33..60`); single blank line gap at `:61` matches the existing PD-1→B.2 spacing precedent (one blank line at `:32`). Chronological PD-1 → B.2 → B.4 reading order preserved. |
| #7 | PASS (constraint named, not closed) | (a) `_bmad/bmm/workflows/...` is owned by bmm module per `manifest.yaml:13..19`; (b) bmm is `source: built-in` so the local edit is a per-project customization; (c) honest disposition documented per Story 14.2/14.3 precedent. No installer re-run since 2026-05-05; PD-1 + B.2 + B.3 + B.4 all persist on lucky-persistence model. |
| #8 | PASS | Production binary 24,995 → 24,995 (Δ=0); filesanity binary 26,460 → 26,460 (Δ=0); S9 hardware-smoke documented exempt per NFR-P3-7 (zero-binary-delta workflow-file-only edit). |
| #9 | PASS | `make test-repl` 973 PASS / 0 FAIL pre-edit AND post-edit (zero movement); `make test` (assembly thread) clean; `make test-file-sanity` PASS. |

No PARTIAL verdicts. No sibling-story spawn (verified `ls 14-4-1*.md` returned no match per Task 9.2).

#### Standing-commitment walk (S1..S12)

- **S1** PASS — adversarial review fresh-context external; ACs do NOT enumerate in-pass adversarial review; PD-1 block at `:20..31` enforces.
- **S2** PASS — REPL-piped tests as default regression surface; no new tests required for workflow-file-only story; the new `<critical>` block IS the discipline artefact.
- **S3** PASS — real-byte-count estimation + capstone-aware drafting. **Cluster completion**: B.2 (Story 14.2) fires at byte-budget-rationale review; B.3 (Story 14.3) fires at Pre-edit baseline capture; B.4 (this story) fires at any figure-quoting moment. Together they move the discipline from why-surface to enforcement-surface across the authoring lifecycle. Per-component itemisation in the Severity table demonstrated; no "mirrors Stories 14.1/14.2/14.3 shape" load-bearing rationale.
- **S4** PASS — ACs #1..#9 stand alone or compose cleanly with named antecedents.
- **S5** PASS — no PARTIAL ship; all nine ACs PASS at story-close; in-pass amendments resolved per recursive-self-validation discipline (Story 14.2/14.3 precedent), not as PARTIAL verdicts.
- **S6, S7** — not directly engaged (no kernel surgery, no register-convention changes).
- **S8** PASS (with /CR-caught addendum) — "pre-existing" / "out-of-scope" did not discharge any correctness defect; AC7 disposition correctly named as "constraint named, not closed" per honest-disposition pattern; the three in-pass recursive-self-validation moments (Task 2.3/2.5 indent + close style; AC5(e) count expectation) were resolved in-pass with explicit attribution to the source-of-truth, not silently absorbed. **The fourth moment** (sprint-status pre-dev-pass-state inherited as `ready-for-dev` rather than verified as `backlog`) was caught at /CR adversarial review and corrected; that this moment escaped in-pass detection (Task 1.8 did not enumerate sprint-status.yaml as a source-of-truth file) is itself a B.4 discipline violation B.4 codifies discipline against — surfaced and corrected without S8 discharge. Filed forward as AC5(f) pre-flight enrichment for future B-cluster stories.
- **S9** EXEMPT (documented) — zero binary delta (workflow-file edit + carry-forward Status update only); per architecture §"Hardware-smoke cadence" — *"Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped."* Same exemption shape as Stories 14.1 / 14.2 / 14.3.
- **S10** PASS — workflow > memory > prompt; the `<critical>` block lands in the workflow-tree file (`instructions.xml`) per CCD-P3-2, NOT in a memory entry.
- **S11** N/A — not tag-applicable (Ant's call per Epic 14 §"Shape" — banner-bump optional). Same as Stories 14.1/14.2/14.3.
- **S12** — not directly engaged (workflow-file edit, not a probe).

#### Sprint-status transition (AC10.1 honest disposition)

Sprint-status row `14-4-pd-2-figure-drift-discipline-critical-block`:
- Pre-dev-pass state: `backlog` (verified by direct read of `sprint-status.yaml` at HEAD `64e91bf`: `git show 64e91bf:_bmad-output/implementation-artifacts/sprint-status.yaml | grep '14-4-pd-2'` → `14-4-pd-2-figure-drift-discipline-critical-block: backlog`).
- At dev-pass close (this commit): `backlog → review` (single-step transition; the `in-progress` intermediate state was NOT written to disk during the dev-pass).

**Honest disposition (corrected by adversarial review)**: actual transition was `backlog → review`, NOT the canonical three-state sequence `ready-for-dev → in-progress → review`. Same shape as Story 14.3's AC10.1 honest disposition. The original Completion Notes claim ("Pre-dev-pass state: `ready-for-dev`; canonical three-state sequence executed; differs from Story 14.3") was a transcription drift caught and corrected post-/CR — exactly the failure mode B.4 codifies discipline against. **B.4 dev-pass recursive-self-validation (AC5(f)) had not added `sprint-status.yaml` to the source-of-truth re-read list** (Task 1.8(i)..(iv) covered `instructions.xml`, `architecture.md`, `epic-13-retro-2026-05-05.md`, `PHASE-3-CARRY-FORWARD.md`, but not `sprint-status.yaml`); had it been included, the figure-drift would have been caught at pre-flight. Filed as a candidate enrichment to the AC5(f) pre-flight list for future B-cluster stories.

#### B.4 sibling-discipline cluster completion note

After Story 14.4 closes, Epic 14 has 4 of 5 lead-in items done (B.1 / B.2 / B.3 / B.4). Only B.5 remains (Story 14.5 — PRD-architecture sync target / `make check-doc-sync`). The story-template-discipline cluster is now structurally complete: B.2 + B.3 + B.4 together codify "real-byte-count + figure-citation discipline" at the enforcement surface across the full drafting lifecycle (byte-budget rationale → Pre-edit baseline capture → any figure-quoting moment).

### File List

Modified files:
- `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (added new `<critical>` block at lines 62..86; B.4 / PD-2 figure-drift discipline; adjacent-after the B.2 block)
- `docs/PHASE-3-CARRY-FORWARD.md` (added B.4 closure row at line :106 in §"Status Tracking" closure-tracking table; B.3-followup row at :105 unchanged; original B.4 row at :35 in main classification table unchanged per Task 3.3)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (story 14-4 row: `backlog → review` single-step; epic-14 stays `in-progress` until Story 14.5 closes)
- `_bmad-output/implementation-artifacts/14-4-pd-2-figure-drift-discipline-critical-block.md` (this story file — Tasks/Subtasks checkboxes marked, Recursive self-validation log populated, Dev Agent Record / File List / Change Log authored, Status `→ review`)

No new files. No `src/*.asm` modifications. No test-suite modifications.

### Change Log

| Date | Change | Reason |
|---|---|---|
| 2026-05-08 | Added new `<critical>` block at `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:62..86` adjacent-after the B.2 block | Closes carry-forward item B.4 (PD-2 — Story-drafter figure drift); enforcement-surface transition for the figure-citation discipline per CCD-P3-2 / S10. Block enumerates trigger surface (figures + tables + code blocks) and required action (validate against source-of-truth at draft time — re-read cited file:line, re-run cited command, re-extract cited table). Cites PD-2 / Epic 13 retro #1 / `epic-13-retro-2026-05-05.md:230`. |
| 2026-05-08 | Added Story 14.4 closure row at `docs/PHASE-3-CARRY-FORWARD.md:106` in §"Status Tracking" closure-tracking table | Marks B.4 carry-forward item Done; records verdict criteria 5/5 PASS (with AC5(e) in-pass amendment per Story 14.2 AC6(d) precedent + AC5(f) recursive-self-validation evidence); zero binary delta; S9 exempt + documented. |
| 2026-05-08 | Sprint-status transition: `backlog → review` (single-step; pre-dev-pass state was `backlog` per direct read of sprint-status.yaml at HEAD `64e91bf`) | BMAD workflow shortcut — same shape as Story 14.3 (which originally claimed `ready-for-dev → in-progress → review` and was corrected to `backlog → review` at /CR fix-pass). |
| 2026-05-08 | Three recursive-self-validation moments resolved in-pass (Task 2.3 / 2.5 indent + close-style claims; AC5(e) `<critical>`-count expectation) | Same shape as Story 14.2 AC6(d) / Story 14.3 AC5(b); the discipline B.4 codifies (re-validate at draft time) IS the resolution mechanism. In-tree precedent (B.2 / PD-1) wins over task-spec descriptions; direct measurement (`<critical` count = 19) wins over mental-model expectation (+1 from +17 = 18). Documented in Completion Notes; no PARTIAL verdict, no sibling-story spawn. |
| 2026-05-08 | /CR adversarial-review fix-pass corrections | (H1+H2) Sprint-status transition claim corrected from false "canonical three-state sequence executed (`ready-for-dev → in-progress → review`)" to actual `backlog → review` — exactly the figure-drift class B.4 codifies discipline against; surfaced and corrected via /CR. Filed candidate enrichment to AC5(f) pre-flight list (add `sprint-status.yaml` to source-of-truth re-reads). (M1) Added B.4-followup row to `docs/PHASE-3-CARRY-FORWARD.md` tracking architecture canonical example block-close-style drift (architecture.md:421 closes `</critical>` on its own line; in-tree B.2/PD-1 precedents close inline) — same shape as Story 14.3's B.3-followup row, prevents the deferral from rotting in story prose only per S10/NFR-P3-31. (L1) Mis-attribution in AC5(e) Completion Notes corrected ("AC4-cite reference at line 85" → "recursive-precedents sub-clause within the AC4 closure parenthetical at lines 84..86"). |
