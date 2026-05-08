# Story 14.3: Story-to-story binary handoff — re-`wc -c` at dev-pass start

Status: done

<!--
This is the THIRD story in Epic 14 (Phase-3 Process Foundation), the
debt-cleanup interlude on top of the v2.0.0 baseline (commit 6599d73,
tagged 2026-05-07). Story 14.1 closed B.1 in commit 274062a (2026-05-08,
zero binary delta); Story 14.2 closed B.2 in commit 80f99c8 (2026-05-08,
zero binary delta). Epic 14 lands the B.1–B.5 lead-in cluster of process /
discipline edits before any non-lead-in Phase-3 story drafting begins;
Story 14.3 closes carry-forward item B.3 per
docs/PHASE-3-CARRY-FORWARD.md and §"Suggested Phase-3 First-Epic Shape".

Per architecture §"Recommended sequencing within the lead-in"
(line 932..937):
  1. B.1 first — tests/README.md (DONE — Story 14.1)
  2. B.2 + B.4 together — <critical> blocks added to instructions.xml
     (B.2 DONE — Story 14.2; B.4 pending Story 14.4 as adjacent sibling)
  3. B.3 — wc -c task added to template.md (single-file edit) — THIS
     STORY
  4. B.5 — tools/check-doc-sync/ + Makefile target — Story 14.5

Story 14.3 lands the structural enforcement for Lesson 13.5-F at the
workflow-tree file (`_bmad/bmm/workflows/4-implementation/create-story/
template.md`) per CCD-P3-2 / S10. Edit site is the create-story
template itself — distinct from Stories 14.2 and 14.4 which edit
`instructions.xml` (the workflow-runtime scripture); the template
file is the document the drafter actually fills out per dev-pass, so
the "Pre-edit baseline" task entry fires at the right moment in the
authoring lifecycle.

Origin lineage:
  Epic-13.5 retro Lesson 13.5-F (codified 2026-05-07 /
  13.5-retro-2026-05-07.md:88 + :121) — "Documentation drift between
  stories is a real failure mode." Story 13.5.5 wrote 25,002 / 26,467
  into its close-out documentation; the actual binary was 24,996 /
  26,461 — a 6-byte gap caught at 13.5.6 audit-walk because the
  audit story actually re-ran wc -c. If the audit had taken the
  prior story's reported numbers as gospel, the absolute
  reconciliation would have shown a ghost +6-byte residual.
  Codified as Lesson 13.5-F and Action Item A4: every story's
  "Pre-edit baseline" task captures wc -c itself, not the prior
  story's reported number.
  PRD Phase-3 2026-05-08 FR-P3-13 + FR-P3-15 + NFR-P3-18 — formalised
  B.3's scope, the verdict-criterion meta-pattern, and the
  story-template-discipline-as-quality-attribute framing.
  Architecture Phase-3 2026-05-08 §"B.3-D1" + §"Pre-edit baseline
  task entry example (B.3 pattern)" + §"Existing files modified in
  Phase 3" — pinned the edit site (`_bmad/bmm/workflows/
  4-implementation/create-story/template.md`), the task-entry
  example, and the verdict criterion (re-`wc -c` task is grep-able
  from the template).

Severity: workflow-file edit only. Zero binary delta expected
(NFR-P3-2 envelope: B.3 = 0 bytes per architecture §"Per-story
binary delta envelopes"). Zero new mechanism, zero new EQUs, zero
new dictionary words. The deliverable is a new "Pre-edit baseline"
section in `template.md` (or extended sub-section if one already
exists post-Story-14.2 close-out) plus a one-line update to docs/
PHASE-3-CARRY-FORWARD.md's Status column.

Standing commitments (S1–S12, codified as NFR-P3-22..33) apply:
  S1 — adversarial review fresh-context external. ACs do NOT
       enumerate "trigger an adversarial review pass". PD-1
       <critical> block at instructions.xml:20..31 enforces.
  S2 — REPL-piped tests as default regression surface. No new
       tests required for this workflow-file-only story; the
       template-task entry IS the discipline artefact.
  S3 — real-byte-count estimation + capstone-aware drafting.
       Lesson 13-C / 13.5-C codified as NFR-P3-24. Story 14.2
       landed the structural enforcer for "mirrors prior arm";
       Story 14.3 lands the structural enforcer for "re-wc -c
       at dev-pass start" — sibling discipline at a different
       point in the authoring lifecycle (B.2 fires at byte-budget-
       rationale review; B.3 fires at Pre-edit baseline capture).
  S4 — AC composition. ACs #1..#8 stand alone or compose
       cleanly with named antecedents.
  S5 — HALT on PARTIAL ship attempts. No "ship 7/8 ACs + spawn
       14.3.1" pattern.
  S8 — "pre-existing" / "out-of-scope" cannot discharge correctness
       defects; this story closes a *workflow-discipline* gap, not
       a correctness defect. The B.3 closure is enforcement-surface
       transition (per CCD-P3-2) for what was previously why-surface
       discipline (Lesson 13.5-F sat in retro doc + memory entries
       only).
  S9 — mid-epic hardware-smoke cadence; **this story is a documented
       S9 exemption** (zero binary delta; AC #7 records the exemption
       explicitly per NFR-P3-7 + architecture §"Hardware-smoke
       cadence"). Same exemption shape as Stories 14.1 and 14.2.
  S10 — workflow > memory > prompt; the task-entry lands in the
        workflow-tree file (`_bmad/bmm/workflows/4-implementation/
        create-story/template.md` — the enforcement surface per
        CCD-P3-2 mapping at architecture §"Existing files modified
        in Phase 3"), not in a memory entry like
        feedback_re_wc_c_baseline.md (which would be the
        S10-violation anti-pattern per architecture §"Bad — workflow
        edit (anti-pattern)").
  S11 — version-surface audit applies at *tag-applicable* close-out;
        Story 14.3 is not tag-applicable (Ant's call per Epic 14
        §"Shape" — banner-only point-release valid but optional).
        Same as Stories 14.1 and 14.2.
  S12 — hardware-typed probe authoring discipline; not directly
        engaged (workflow-file edit, not a probe).

Recursive-self-validation note. Story 14.3 IS the structural
enforcement for the discipline B.3 codifies. Per S5 and the FR-P3-15
verdict-criterion meta-pattern, Story 14.3's own dev-pass MUST
re-wc -c directly at Pre-edit baseline (Task 1.1) rather than
inheriting Story 14.2's reported numbers (24,995 / 26,460). This
is the same recursive self-validation Stories 14.1 and 14.2
practiced. If the dev-pass inherits prior figures unchecked, the
B.3 discipline failed its own verdict and the story HALTs per S5.

Validation is optional. Run validate-create-story for quality check
before dev-story.
-->

## Story

As a **story drafter** (project lead Ant — and any future SM agent or LLM-driven story-creation pass) starting a new Phase-3+ dev-pass,
I want the story-template's "Pre-edit baseline" task to require me to re-`wc -c` the actual current build artefact at the start of every dev-pass — capturing the binary size from the file system rather than inheriting the prior story's reported number,
So that I don't inherit drift that has accumulated between the prior story's close-out documentation and the actual one-step-later binary — preventing the **Lesson 13.5-F doc-drift class** that produced Story 13.5.5's 6-byte close-out reporting gap (`25,002 / 26,467` reported vs. `24,996 / 26,461` actual; caught at 13.5.6 audit-walk because the audit story re-ran `wc -c` rather than inheriting; per `epic-13.5-retro-2026-05-07.md:88` + `:121`).

This is the **third story** in Epic 14 (Phase-3 Process Foundation) — the lead-in cluster (B.1 + B.2 + B.3 + B.4 + B.5) that lands first per `docs/PHASE-3-CARRY-FORWARD.md` § "Suggested Phase-3 First-Epic Shape" and `architecture.md` §"First Implementation Priority" (line 932..937). B.1 closed in Story 14.1 (commit 274062a, 2026-05-08, zero binary delta); B.2 closed in Story 14.2 (commit 80f99c8, 2026-05-08, zero binary delta); B.3 closes in Story 14.3 (this story). Per architecture §"Recommended sequencing within the lead-in" (line 936): "**B.3** — `wc -c` task added to `template.md` (single-file edit)". Story 14.3 is the **single-file edit** in the cluster — Stories 14.2 and 14.4 share `instructions.xml` as their edit site; Story 14.3 owns `template.md` exclusively.

The story has **zero new feature scope** and **zero binary delta** (NFR-P3-2 envelope per architecture §"Per-story binary delta envelopes" line 346: `B.2 / B.3 / B.4 | 0 (workflow-file only)`). The deliverable is a new "Pre-edit baseline" task entry at the top of the relevant section in `_bmad/bmm/workflows/4-implementation/create-story/template.md` plus a one-line update to `docs/PHASE-3-CARRY-FORWARD.md`'s Status column. The story is a **documented S9 hardware-smoke exemption** per NFR-P3-7 / architecture §"Hardware-smoke cadence" ("Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped"). Same exemption shape as Stories 14.1 and 14.2.

The story carries its own **verdict criterion** per FR-P3-15 (the verdict-criterion meta-pattern that makes B.x lead-in stories discipline-as-deliverable per architecture §"Implications for B.x verdict criteria"): the new task-entry is grep-able from `template.md` (`grep -n 'wc -c' template.md` returns ≥ 1 match in the Pre-edit baseline section; the "Do not inherit the prior story's reported number" line grep-able by phrase) **and** Story 14.3's own dev-pass demonstrates the discipline by re-`wc -c`-ing directly at Task 1.1 rather than inheriting Story 14.2's reported figures (24,995 / 26,460 — these MUST be reverified, not copied). If either verdict criterion fails, the story HALTs per S5 — the new task-entry failed its own verdict; per architecture §"Implications for B.x verdict criteria" ("If a lead-in fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration").

---

## Severity / Phase Re-Statement (BINDING — context for every dev-pass decision)

This is a **workflow-file-only** story closing the long-deferred carry-forward item B.3 (originally Epic-13.5 retro Lesson 13.5-F + Action Item A4, codified 2026-05-07). The fix shape is **fully pinned** by `architecture.md` §"B.3-D1" line 260 and §"Pre-edit baseline task entry example (B.3 pattern)" lines 424..433. The single edit site is `_bmad/bmm/workflows/4-implementation/create-story/template.md`; the task-entry format is the architecture-doc example verbatim.

| Dimension | Value | Source |
|---|---|---|
| **Scope** | New "Pre-edit baseline" task-entry in `template.md` + one carry-forward Status update | `architecture.md` §"B.3-D1" line 260 |
| **New file** | None | n/a |
| **Modified file (primary)** | `_bmad/bmm/workflows/4-implementation/create-story/template.md` (add Pre-edit baseline section/subsection with `wc -c` task) | `architecture.md` §"Existing files modified in Phase 3" line 606 |
| **Modified file (secondary)** | `docs/PHASE-3-CARRY-FORWARD.md` (B.3 row Status `🔄 In progress` → `✅ Done` with closure note) | `docs/PHASE-3-CARRY-FORWARD.md:34` (current B.3 row) + `:103` Story 14.2 close-out row for shape precedent |
| **Task placement** | At the top of the "Pre-edit baseline" section — first task the drafter encounters when filling out tasks. Current `template.md` has no Pre-edit baseline section (verified at line :17 — `## Tasks / Subtasks` jumps straight to "Task 1 (AC: #)"); dev-pass adds the section. Recommended layout: new `### Pre-edit baseline` subsection inserted at the top of `## Tasks / Subtasks` (before the existing "Task 1" placeholder), or as a new top-level section before `## Tasks / Subtasks` — both forms satisfy AC3 ("whichever position the drafter encounters first when filling out the template"). Dev-pass picks one with explicit rationale in Completion Notes. | architecture.md §"Pre-edit baseline task entry example" line 424..433 + Story 14.3 AC3 |
| **Task-entry format** | Per architecture §"Pre-edit baseline task entry example (B.3 pattern)" line 426..432 — markdown checklist; first bullet captures `wc -c build/antforth.com` with the "**Do not** inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F)" sub-bullet immediately under it; second bullet captures `make test-repl` baseline pass count (architectural example shows it; AC1..AC3 do not mandate it but it follows the architecture pattern). | `architecture.md:426..432` |
| **Cited motivating incident** | Lesson 13.5-F + Story 13.5.5 close-out 6-byte doc-drift — `epic-13.5-retro-2026-05-07.md:88` (incident statement) + `:121` (lesson-row formal citation) | Story 14.3 AC4 |
| **Binary delta** | 0 bytes (workflow-file only, no kernel touch) | `architecture.md` §"Per-story binary delta envelopes" line 346 |
| **Test count delta** | 0 (no new probes) | `epics.md` Story 14.3 AC8 ("`make test-repl` reports ≥ 973 PASS / 0 FAIL") |
| **S9 disposition** | Exempt + documented in verdict table | NFR-P3-7 / `architecture.md` §"Hardware-smoke cadence" line 456 |
| **S11 disposition** | Not tag-applicable; banner-bump optional per Ant's call | `epics.md` Epic 14 §"Shape" |
| **Verdict criterion (self-test)** | (a) `grep -n 'wc -c' template.md` returns ≥ 1 match in the Pre-edit baseline section; (b) `grep -n 'Do not inherit'` (or canonical phrase the dev-pass uses) grep-able from `template.md`; (c) Story 14.3's own dev-pass at Task 1.1 re-`wc -c`s directly rather than inheriting Story 14.2's reported figures (24,995 / 26,460) — recursive self-validation. | FR-P3-15 / AC5 |

**The story is pre-decided in shape.** No fix-shape pick (A.1-D3 / A.3 / B.7 dispositions); no kernel surgery; no register-convention audit; no caught-form THROW migration; no new file creation. The dev-pass adds the Pre-edit baseline section to `template.md` per the architecture-pinned format, runs the FR-P3-15 verdict-criterion self-test (grep + recursive re-`wc -c`), updates `docs/PHASE-3-CARRY-FORWARD.md`'s B.3 Status row to `✅ Done`, runs `make test-repl` for regression gate, and closes.

If the dev-pass surfaces *additional* baseline-capture tasks worth enumerating beyond the architecture's example (e.g., `make` build-clean check, current-`HEAD` git ref capture), those land in the new section in-pass per AC #11-style in-pass-fix discipline (mirror Story 14.1 Task 4.6 review-fix-pass shape) — but they do NOT trigger a sibling-story spawn, and the verdict criteria still use AC5 phrasing. Per S5, no PARTIAL ship.

**Per-component byte-budget itemisation (for B.2 lint compliance — Story 14.2 closed 2026-05-08):**

| Component | Byte cost | Notes |
|---|---|---|
| `template.md` text edit | 0 kernel bytes | Workflow file consumed by BMAD runtime, not by antforth kernel build/test harness |
| `docs/PHASE-3-CARRY-FORWARD.md` Status update | 0 kernel bytes | Doc file, not in kernel build path |
| `src/*.asm` modifications | 0 bytes | None — no kernel surgery in scope |
| `build/antforth.com` Δ | 0 bytes | No `src/*.asm` touched |
| `build/antforth_filesanity.com` Δ | 0 bytes | No `src/*.asm` touched |
| **Per-arm total** | **0 bytes** | Workflow-file-only story |

Itemisation confirms the zero-delta envelope structurally — no comparison-to-prior-story shorthand was used to reach the figure. Stories 14.1 and 14.2 closed at zero delta on the same component-by-component basis (each independently verified at its own dev-pass close); their precedent is a sanity-check anchor for "workflow-file-only stories carry zero binary delta", not the source of Story 14.3's estimate.

---

## Acceptance Criteria

1. **Given** the v2.0 baseline `_bmad/bmm/workflows/4-implementation/create-story/template.md` (49 lines as of post-Story-14.2 close, commit 80f99c8) **lacks** a "Pre-edit baseline" section (verified pre-edit via `grep -nE 'Pre-edit|wc -c' _bmad/bmm/workflows/4-implementation/create-story/template.md` returning the empty set, captured in Pre-edit baseline + Dev Notes),
   **when** Story 14.3 is dev-passed,
   **then** a new task-entry lands in `_bmad/bmm/workflows/4-implementation/create-story/template.md`: **"Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes"** (or equivalent phrasing — the verbatim form used must include the literal substring `wc -c` and the build-artefact path `build/antforth.com`). The entry sits in a new "Pre-edit baseline" section (header form: `### Pre-edit baseline` as a subsection of `## Tasks / Subtasks`, OR `## Pre-edit baseline` as a new top-level section between `## Acceptance Criteria` and `## Tasks / Subtasks` — dev-pass picks one with rationale in Completion Notes).

2. **Given** the architecture-pinned task-entry format (per `architecture.md` §"Pre-edit baseline task entry example (B.3 pattern)" line 424..433 — the canonical example: `- [ ] Capture current binary size: ... → record in story Dev Notes` followed by an indented sub-bullet `- **Do not** inherit the prior story's reported number — re-wc -c from the actual current build artifact (B.3 / Lesson 13.5-F)`),
   **when** the new task-entry is authored per AC1,
   **then** the entry includes the explicit instruction (as an indented sub-bullet under the wc -c task, OR as inline text within the same task — drafter's choice; both satisfy the architecture example): **"Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artefact (B.3 / Lesson 13.5-F)"** (the literal substring "Do not" — or an equivalent strong-imperative phrase like "Don't" — followed by the "inherit the prior story's reported number" reasoning is mandatory; the parenthetical "(B.3 / Lesson 13.5-F)" cite is mandatory).

3. **Given** the AC3 placement requirement (per `epics.md` Story 14.3 AC3 — "the task lands at the top of the 'Pre-edit baseline' section (or whichever position the drafter encounters first when filling out the template)"),
   **when** the new section/subsection is authored per AC1,
   **then** the wc -c task is the **first task** in the Pre-edit baseline section — no other task precedes it in that section. If the dev-pass adds additional Pre-edit baseline tasks per the architecture example (e.g., `make test-repl` baseline capture, `make` build-clean check, git HEAD capture), the wc -c task remains positionally first. The "drafter encounters first when filling out the template" reading is satisfied by either: (a) the section being the first encountered in the natural top-to-bottom template fill order, or (b) the section being labelled in a way that makes its early-fill nature explicit (e.g., the section name itself includes "Pre-edit" — present-tense imperative signalling "do this before any edits").

4. **Given** the AC4 motivating-incident-cite requirement (per `epics.md` Story 14.3 AC4 — "the task cites Lesson 13.5-F / Story 13.5.5 close-out as its motivating incident"),
   **when** the new task-entry is authored per AC1,
   **then** the entry — either inline within the task's body or in an immediately-adjacent comment / sub-bullet — names **(a)** Lesson 13.5-F as the motivating lesson (literal "Lesson 13.5-F" or "13.5-F" reference) and **(b)** Story 13.5.5 close-out as the concrete prior incident it prevents (the 6-byte doc-drift gap; `25,002 / 26,467` reported vs. `24,996 / 26,461` actual per `epic-13.5-retro-2026-05-07.md:88`). Minimum acceptable cite form: the parenthetical from the architecture example — `(B.3 / Lesson 13.5-F)` — satisfies (a); a longer reference like `(B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift)` satisfies both. Drafter picks one; both are architecturally accepted.

5. **Given** the FR-P3-15 verdict-criterion meta-pattern — each B.x lead-in story tests that the new artefact **would have caught the prior-incident pattern that motivated it** (per `architecture.md` §"Implications for B.x verdict criteria" line 217 + §"Verdict-criterion meta-pattern (all four)" line 264..268 — "B.3 — the template's pre-edit task references `wc -c` directly, grep-able from `_bmad/bmm/workflows/4-implementation/create-story/template.md`"),
   **when** Story 14.3 is dev-passed,
   **then** the verdict-criterion grep-tests are mechanically executed at story-close and recorded in Completion Notes:
   - **(a)** `grep -n 'wc -c' _bmad/bmm/workflows/4-implementation/create-story/template.md` returns ≥ 1 match in the new Pre-edit baseline section (the literal `wc -c` reference per AC1)
   - **(b)** `grep -nE 'Do not inherit|Don.?t inherit' _bmad/bmm/workflows/4-implementation/create-story/template.md` returns ≥ 1 match in the new section (the "do not inherit prior story" sub-bullet per AC2)
   - **(c)** `grep -nE 'Lesson 13\.5-F|13\.5-F' _bmad/bmm/workflows/4-implementation/create-story/template.md` returns ≥ 1 match (the lesson cite per AC4)
   - **(d)** `grep -nE 'Pre-edit' _bmad/bmm/workflows/4-implementation/create-story/template.md | wc -l` returns ≥ 1 (verifies the section header was added)
   - **(e)** **recursive self-validation**: Story 14.3's own dev-pass at Task 1.1 demonstrates the discipline by capturing `wc -c build/antforth.com` and `wc -c build/antforth_filesanity.com` *directly from the file system* rather than inheriting Story 14.2's reported figures (24,995 / 26,460). The dev-pass records both the directly-measured numbers AND a note confirming the figures were obtained by `wc -c` invocation, not by transcription from `14-2-mirrors-prior-arm-halt-signal-lint-in-story-template.md`'s File List or Completion Notes. If the directly-measured figures differ from the inherited 24,995 / 26,460, the difference is investigated and reconciled per Lesson 13.5-F before the dev-pass proceeds — exactly the workflow B.3 codifies.
   - If any of (a)..(d) returns the wrong count, the story HALTs per S5 — the template-edit failed its own verdict; per architecture §"Implications for B.x verdict criteria" ("If a lead-in fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration"). If (e) inherits figures unchecked, B.3's discipline failed in its own dev-pass — same HALT.

6. **Given** the BMAD installer-manifest disposition per CCD-P3-2 (architecture §"Workflow-file edit identity" line 395..400 — "Installer manifest → BMAD installer's expected list of files (so structural edits survive installer re-runs)") and the **honest disposition** Story 14.2 documented at AC7 / "AC7 honest disposition" Completion Notes section (the actual installer manifest at `_bmad/_config/manifest.yaml` enumerates *modules* not per-file edits; `_bmad/` is gitignored at `.gitignore:2`; PD-1's persistence model is "lucky persistence" since 2026-05-05),
   **when** Story 14.3 is dev-passed,
   **then** the dev-pass confirms the structural edit's persistence model is named (not silently inherited):
   - **(a)** the file `_bmad/bmm/workflows/4-implementation/create-story/template.md` is named in `_bmad/_config/manifest.yaml` as part of the installed `bmm` module (it is — module `bmm` v6.0.4 owns the `_bmad/bmm/workflows/...` tree per `manifest.yaml:13..19`); a future installer re-run on the bmm module would re-write this file from its source-of-truth shipped with the installer
   - **(b)** because the installed `bmm` module is `source: built-in` per `manifest.yaml:17`, the module's source-of-truth lives upstream of this repo — the local edit is a per-project customization that an upstream re-install would overwrite. **Identical persistence model to PD-1 (Story 13.5.0) and B.2 (Story 14.2).** No installer re-run has occurred since 2026-05-05 (PD-1 dev-pass), so PD-1's `<critical>` block at `instructions.xml:20..31` and B.2's block at `instructions.xml:33..60` and Story 14.1's `tests/README.md` (in a different — not-gitignored — location) all persist.
   - **(c)** the dev-pass surfaces this disposition explicitly in Completion Notes (per S8 — "out-of-scope" cannot silently discharge a design constraint; this AC names the constraint). The disposition shape is "constraint named, not closed" per Story 14.2 AC7 honest-disposition precedent. Closure path: when a bmm v6.0.5+ upstream-PR mechanism becomes available, B.1's `tests/README.md` (which is in-tree and IS in git), B.2's `<critical>` block, B.3's "Pre-edit baseline" task-entry, and B.4's figure-drift block become candidates for upstreaming. Until then, the local edits ARE the enforcement surface.

7. **Given** the post-Story-14.2 baseline binary at `build/antforth.com` (current `wc -c` measured directly at story-drafting time on commit 80f99c8 — the Story-14.2 commit; Story 14.2 was zero binary delta per its AC #8 verdict; per the recursive-self-validation discipline this story enforces, the figures MUST be re-measured at Task 1.1 not transcribed from Story 14.2),
   **when** the dev-pass measures `wc -c build/antforth.com` and `wc -c build/antforth_filesanity.com` at story-drafting time AND at story-close,
   **then** the post-edit binary sizes are **unchanged from the pre-edit measurement**: production binary (Δ = 0); filesanity binary (Δ = 0). The story is **workflow-file edit + carry-forward Status update only**; any non-zero binary delta on this story HALTs per S5 — there is no `src/*.asm` instruction change in scope. Per NFR-P3-2 (cumulative Phase-3 ROM cap +200 bytes / 24,996 → ≤ 25,200), Story 14.3's per-story envelope is `0 bytes` (architecture §"Per-story binary delta envelopes" line 346 / `epics.md` Story 14.3 AC7). The S9 hardware-smoke task is **documented exempt** per NFR-P3-7 / architecture §"Hardware-smoke cadence" — same exemption shape as Stories 14.1 and 14.2. The exemption note lands in Completion Notes: *"S9 exempt — zero binary delta (workflow-file edit + carry-forward Status update only); per architecture §'Hardware-smoke cadence' ('Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly')."*

8. **Given** the post-Story-14.2 `make test-repl` baseline of 973 PASS / 0 FAIL (per Story 14.2 AC #9 verdict, unchanged from the post-Story-14.1 / post-Epic-13.5 / post-v2.0.0 baseline),
   **when** `make test-repl` is run pre-edit AND post-edit,
   **then** the result is **973 PASS / 0 FAIL — zero regressions, zero test-count movement**. Pre-edit verification: `grep -c '^PASS:' <(make test-repl 2>&1)` returns 973; pre-edit FAIL count = 0. Post-edit (story-close): same numbers — Story 14.3 is workflow-file edit only, no test-suite movement expected (the `template.md` file is consumed by the BMAD workflow runtime, NOT by the antforth kernel build or test harness; editing it cannot affect `make test-repl` pass/fail counts unless the edit accidentally damages the file in a way that breaks the BMAD workflow — but BMAD workflow integrity is orthogonal to antforth-kernel test results). Any `make test-repl` movement HALTs per S5. Recorded in Completion Notes alongside `make test` (assembly thread) clean check (informational; not a PARTIAL gate) and `make test-file-sanity` PASS (informational).

---

## Tasks / Subtasks

- [x] **Task 1 — Pre-edit baseline** (AC #5(e), #7, #8; per architecture §"Re-`wc -c` at the start of every dev-pass" / Lesson 13.5-F — this story IS the codification of B.3, so its dev-pass MUST practice the discipline before B.3's `template.md` entry exists; Stories 14.1 and 14.2 carried the same forward-discipline practice)
  - [x] 1.1 — `wc -c build/antforth.com` direct measurement → `24995 build/antforth.com`. OBSERVED: 24,995 ✓ (direct measurement, not inherited). Matches Story 14.2's reported 24,995; no doc-drift surfaced; recursive-self-validation discipline practiced (Lesson 13.5-F).
  - [x] 1.2 — `wc -c build/antforth_filesanity.com` direct measurement → `26460 build/antforth_filesanity.com`. OBSERVED: 26,460 ✓ (direct measurement, not inherited). Matches Story 14.2's reported 26,460; no doc-drift surfaced.
  - [x] 1.3 — `make test-repl 2>&1 | tee /tmp/14-3-pre-edit.out` → `grep -c '^PASS:' /tmp/14-3-pre-edit.out` = **973**; `grep -c '^FAIL:' /tmp/14-3-pre-edit.out` = **0**. Baseline matches expected.
  - [x] 1.4 — `grep -nE 'Pre-edit|wc -c' _bmad/bmm/workflows/4-implementation/create-story/template.md` → empty (exit 1, no matches). Confirms no Pre-edit baseline section pre-edit — the AC5(d) baseline is established.
  - [x] 1.5 — `git log --oneline -1` → `80f99c8 story 14.2: add lint that catches "mirrors prior arm" byte-budget shortcuts`. ✓
  - [x] 1.6 — `wc -l _bmad/bmm/workflows/4-implementation/create-story/template.md` → 49 lines pre-edit. ✓

- [x] **Task 2 — Author the new "Pre-edit baseline" section / task-entry** (AC #1, #2, #3, #4)
  - [x] 2.1 — Form A picked. Rationale: matches the architecture's canonical example (line 426..433) which uses `### Pre-edit baseline tasks` (`###` depth signals subsection of an outer `##` block); keeps the section adjacent to the rest of the task list so the drafter fills it before any story-specific tasks; less visually disruptive than a new top-level `## Pre-edit baseline` section.
  - [x] 2.2 — `_bmad/bmm/workflows/4-implementation/create-story/template.md` opened; insertion site between line 17 (`## Tasks / Subtasks` header) and the existing "Task 1 (AC: #)" placeholder.
  - [x] 2.3 — Section header composed: `### Pre-edit baseline` (Form A subsection of `## Tasks / Subtasks`).
  - [x] 2.4 — wc -c task entry composed; sub-bullet holds "Do not inherit" + "(B.3 / Lesson 13.5-F)" cite. **In-pass spec amendment** (recursive self-validation moment per Story 14.2 AC6(d) precedent): the architecture's canonical example uses `**Do not**` (markdown bold for emphasis), but AC5(b) regex `Do not inherit|Don.?t inherit` cannot match across the literal `**` characters. Rather than amend the AC's regex spec, the bold formatting is dropped from "Do not" so the literal "Do not inherit" appears in the template text. The architecture example's bold formatting is incidental emphasis, not load-bearing — the function of the line is the instruction, which is preserved verbatim. Documented as the expected recursive moment per Dev Notes §"Recursive-self-validation note".
  - [x] 2.5 — `make test-repl` baseline-capture task added as second bullet (matches architecture example shape; small extra value at no cost).
  - [x] 2.6 — Architecture example placeholder `- [ ] [...other pre-edit tasks per template...]` preserved intact as the third bullet (per Task 2.6 discretionary; drafter may enumerate or leave placeholder).
  - [x] 2.7 — Markdown well-formedness verified: `### Pre-edit baseline` correctly nests under `## Tasks / Subtasks`; checklist rendered as proper markdown; sub-bullet indentation (2 spaces) consistent with existing template conventions. No markdownlint config in repo.

- [x] **Task 3 — Update `docs/PHASE-3-CARRY-FORWARD.md` Status** (per Story 14.1 / 14.2 precedent Tasks 7.1 / 3.1)
  - [x] 3.1 — § "Status Tracking" located; B.2 row at line 103 used for shape-precedent.
  - [x] 3.2 — B.3 row added at `docs/PHASE-3-CARRY-FORWARD.md:104` immediately after B.2 row; close-out date 2026-05-08; closure note enumerates the 5/5 verdict criteria PASSed (a..e) and the zero-binary-delta result.

- [x] **Task 4 — Verdict-criterion meta-pattern self-test** (AC #5; FR-P3-15)
  - [x] 4.1 — Grep verdict tests run (post-edit):
    - (a) `grep -n 'wc -c' _bmad/bmm/workflows/4-implementation/create-story/template.md` → 2 matches (lines 21, 22) ≥ 1 ✓
    - (b) `grep -nE 'Do not inherit|Don.?t inherit' _bmad/bmm/workflows/4-implementation/create-story/template.md` → 1 match (line 22) ≥ 1 ✓ (after Task 2.4 in-pass spec amendment — see Completion Notes)
    - (c) `grep -nE 'Lesson 13\.5-F|13\.5-F' _bmad/bmm/workflows/4-implementation/create-story/template.md` → 1 match (line 22) ≥ 1 ✓
    - (d) `grep -cE 'Pre-edit' _bmad/bmm/workflows/4-implementation/create-story/template.md` → 1 match (line 19) ≥ 1 ✓
  - [x] 4.2 — Recursive self-validation evidence (AC #5(e)) — Tasks 1.1 / 1.2 obtained 24,995 / 26,460 by direct `wc -c build/antforth.com build/antforth_filesanity.com` invocation; outputs reproduced verbatim in Task 1.1 / 1.2 records above. Figures NOT transcribed from Story 14.2's File List or Completion Notes; the agreement with Story 14.2's reports validates the directly-measured numbers, not the inheritance.
  - [x] 4.3 — All five verdict-test results recorded above and in Completion Notes; one in-pass spec-drift surfaced (AC5(b) regex vs. architecture's `**Do not**` markdown bold — handled per Story 14.2 AC6(d) precedent by amending the template literal text rather than the regex AC; documented in Task 2.4 + Completion Notes).

- [x] **Task 5 — Post-edit binary + test regression check** (AC #7, #8)
  - [x] 5.1 — `make` reports `Nothing to be done for 'all'` (kernel build path untouched by template-file edit). `wc -c build/antforth.com` post-edit = 24,995. Δ = 0 vs. Task 1.1. ✓
  - [x] 5.2 — `wc -c build/antforth_filesanity.com` post-edit = 26,460. Δ = 0 vs. Task 1.2. ✓
  - [x] 5.3 — `make test-repl 2>&1 | tee /tmp/14-3-post-edit.out` → 973 PASS / 0 FAIL. Zero movement from pre-edit baseline. ✓
  - [x] 5.4 — `make test` (assembly thread) → `Errors: 0, warnings: 0, compiled: 30598 lines, work time: 0.083 seconds / PASS: Output matches expected`. ✓ (informational)
  - [x] 5.5 — `make test-file-sanity` → `PASS: file-sanity test — 12 expected lines match exactly (Story 13.5.2 H1: .fbr_eof tri-state discriminator probe)`. ✓ (informational)

- [x] **Task 6 — S9 hardware-smoke disposition** (AC #7 / NFR-P3-7)
  - [x] 6.1 — **S9 exempt** — zero binary delta (workflow-file edit + carry-forward Status update only); per architecture §"Hardware-smoke cadence" — *"Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped."* Same exemption shape as Stories 14.1 and 14.2. Exemption recorded in Completion Notes; binary delta verified zero in Tasks 5.1 / 5.2.

- [x] **Task 7 — Carry-forward catalogue Status confirmation** (`docs/PHASE-3-CARRY-FORWARD.md` post-edit verification)
  - [x] 7.1 — § "Status Tracking" re-read; B.3 row correctly added at line 104 immediately after the B.2 row (line 103); row content reproduced in Change Log below.

- [x] **Task 8 — Standing-commitment hold confirmation** (NFR-P3-22..33 subset relevant to 14.3)
  - [x] 8.1 — S1..S12 walk: all twelve hold (see Completion Notes §"Standing-commitment walk (S1..S12)"). S3 sibling-discipline transition recorded — B.2 fires at byte-budget-rationale review; B.3 (this story) fires at Pre-edit baseline capture; together they move "real-byte-count estimation" discipline from why-surface to enforcement-surface across the authoring lifecycle.

- [x] **Task 9 — HALT-on-PARTIAL discipline check at story-close** (S5 / `feedback_no_preexisting_discharge.md`)
  - [x] 9.1 — AC #1..#8 walk in Completion Notes confirms no PARTIAL verdict; all eight ACs PASS. The Task 2.4 in-pass spec drift (AC5(b) regex vs. `**Do not**` bold) was resolved in-pass per Story 14.2 AC6(d) precedent — not carried as PARTIAL.
  - [x] 9.2 — `ls _bmad-output/implementation-artifacts/14-3-1*.md` → no match (zsh "no matches found"). No sibling-story spawn. ✓

- [x] **Task 10 — Sprint-status update + Change Log + File List**
  - [x] 10.1 — `_bmad-output/implementation-artifacts/sprint-status.yaml` `14-3-story-to-story-binary-handoff-re-wc-c-at-dev-pass-start` row: `backlog` (pre-dev-pass per `git show HEAD:_bmad-output/implementation-artifacts/sprint-status.yaml`) → `review` (dev-pass close, this commit). **Honest disposition: this is a `backlog → review` shortcut per git diff** — no intermediate `ready-for-dev` or `in-progress` writes were saved between commits. The story file existed pre-dev-pass (so the row should arguably have been at `ready-for-dev`), but the sprint-status row was never bumped before dev-pass start. Transition shape recorded as-is rather than narrated as a canonical multi-step sequence; this correction was applied during the `/CR` adversarial-review fix-pass after the original Task 10.1 claim ("`ready-for-dev → in-progress → review`; no `backlog → review` shortcut") was contradicted by `git diff` evidence.
  - [x] 10.2 — File List authored below.
  - [x] 10.3 — Change Log authored below.

### Review Follow-ups (AI)

`/CR` adversarial review pass run 2026-05-08. Findings and dispositions:

- [x] [AI-Review][HIGH] H1 — Task 10.1 sprint-status transition claim contradicted by `git diff` (claimed `ready-for-dev → in-progress → review`; actual `backlog → review`). **Fixed in-pass**: Task 10.1 rewritten to honestly state the `backlog → review` shortcut and explain why intermediate states weren't saved. [story:269]
- [x] [AI-Review][HIGH] H2 — Carry-forward closure note had factual count error (claimed `grep 'wc -c' template.md → 1 match`; actual 2 matches at lines 21, 22). **Fixed in-pass**: `docs/PHASE-3-CARRY-FORWARD.md:104` corrected to "2 matches (lines 21, 22)". Recursive irony: the exact cross-doc factual drift Lesson 13.5-F codifies discipline against. [PHASE-3-CARRY-FORWARD.md:104]
- [x] [AI-Review][MEDIUM] M1 — Markdown structure swallowed downstream task placeholders under `### Pre-edit baseline`. **Fixed in-pass**: added `### Story tasks` subsection header before the `Task 1` placeholder so the Pre-edit baseline section is structurally bounded. [template.md:25..26]
- [x] [AI-Review][MEDIUM] M2 — `[...other pre-edit tasks per template...]` placeholder was per-story cruft. **Fixed in-pass**: removed the literal placeholder bullet from the template; drafters may add story-specific pre-edit tasks freely without a literal `[...]` placeholder priming them. [template.md:24 — removed]
- [x] [AI-Review][MEDIUM] M3 — Architecture canonical example still has `**Do not**` bold; deferred fix lived only in story prose. **Fixed in-pass**: added `B.3-followup` row to `docs/PHASE-3-CARRY-FORWARD.md` Status Tracking so the deferral is tracked at the carry-forward catalogue (workflow surface), not at the story-prose surface only. [PHASE-3-CARRY-FORWARD.md:105]
- [x] [AI-Review][MEDIUM] M4 — AC4(b) Story-13.5.5 inline cite was permitted-but-not-required by AC4 minimum-cite-form clause. **Fixed in-pass**: extended template cite to `(B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift)` so the concrete prior incident is named in the workflow surface, not just the lesson tag. [template.md:22]
- [x] [AI-Review][LOW] L1 — Pre-edit baseline section didn't specify WHEN to fire (drafting time? dev-pass start?). **Fixed in-pass**: section header changed to `### Pre-edit baseline (capture at dev-pass start, before any source edits)` so the temporal trigger is encoded in the section heading itself. [template.md:19]
- [ ] [AI-Review][LOW] L2 — Story body is heavy (540 lines) for a 7-line template diff + 1-row carry-forward update; per-story repetition of Severity table / S1..S12 walk / prior-story-intelligence approaching parody. **Not fixed**: would require a story-template-discipline rewrite outside this story's scope; recorded as feedback for Story 14.4+ shape decisions and Epic 14 retrospective. [story:1..540]

CR fix-pass binary delta: zero (template.md, PHASE-3-CARRY-FORWARD.md, sprint-status.yaml, this story file — none in kernel build path). Post-fix verdict criteria re-run: AC5(a) 2 matches (lines 21, 22) ✓; AC5(b) 1 match (line 22) ✓; AC5(c) 1 match (line 22) ✓; AC5(d) 1 match (line 19) ✓. All five verdict criteria still PASS post-fix.

---

## Dev Notes

### Why this story matters

Story 13.5.5 wrote `25,002 / 26,467` into its close-out documentation; the actual binary was `24,996 / 26,461` — a 6-byte gap. Quoting `epic-13.5-retro-2026-05-07.md:88` verbatim:

> *Story 13.5.5 wrote 25,002 / 26,467 into its close-out documentation; the actual binary was 24,996 / 26,461. **The story was building one binary and reporting another to the next story.** Caught at 13.5.6 audit-walk because the audit story actually re-ran `wc -c`, but if the audit had taken the prior story's reported numbers as gospel, the absolute reconciliation would have shown a ghost +6-byte residual. **Codified as Lesson 13.5-F and Action Item A4.***

The pattern: *a dev-pass produces close-out documentation that captures pre-build figures rather than post-build figures*, OR *captures figures from a pre-rebuild commit*, OR *transcribes the prior story's figures without re-measuring.* The next story inherits the wrong number; if no audit re-measures, the drift compounds. **The discipline is straightforward** — re-`wc -c` at every dev-pass start, treating the prior story's reported number as informational context only.

**The standing commitment exists in `feedback_*` discipline files and Lesson 13.5-F.** A4 lives in the *why* surface; PD-1's precedent showed that a *why*-surface discipline doesn't fire structurally — the drafter has to *remember* to invoke it (per `architecture.md` §"Bad — workflow edit (anti-pattern)" line 554..559: *"Lives in the why surface, not the enforcement surface. Drafter has to remember to invoke it. CCD-P3-2 / S10 violation."*). **Story 14.3 lands the discipline at the enforcement surface** — the `template.md` "Pre-edit baseline" task fires at the moment the drafter starts authoring per-story figures, without requiring memory recall.

Sibling discipline note: Story 14.2 landed the structural enforcer for "mirrors prior arm" byte-budget shorthand (Lesson 13.5-C — fires at byte-budget-rationale review step). Story 14.3 lands the structural enforcer for "re-`wc -c` at dev-pass start" (Lesson 13.5-F — fires at Pre-edit baseline capture step). Both are S3 / NFR-P3-24 / S10 / NFR-P3-31 enforcement-surface transitions; both move discipline from why-surface (memory entries, retro discussions) to enforcement-surface (workflow files); together with B.4 (figure-drift, Story 14.4) they form the story-template-discipline cluster of the lead-in.

### Recursive-self-validation note

Story 14.3 IS the structural enforcement for Lesson 13.5-F. Per S5 and the FR-P3-15 verdict-criterion meta-pattern, Story 14.3's own dev-pass MUST practice the discipline B.3 codifies — re-`wc -c` directly at Task 1.1, not transcribe from Story 14.2's reported figures. The recursive-validation moment (whether the directly-measured figures match Story 14.2's reported 24,995 / 26,460 — and what to do if they don't) IS the verdict criterion. Story 14.2 had an analogous recursive moment: AC6(d) spec-drift surfaced precisely because the drafter relied on a partial mental model rather than direct counting (`grep -c '<critical>' = 1` expected vs. 16 actual). That AC was amended in-pass per the new B.2 lint's spirit. Story 14.3 should expect a similar self-validating moment.

### Prior-story intelligence (Epic 13.5 + Stories 14.1 + 14.2 — directly relevant)

**Story 13.5.5 (TD-7 — user-facing SAVE-INPUT / RESTORE-INPUT EVALUATE arm)** at `_bmad-output/implementation-artifacts/13.5-5-td-7-save-input-restore-input-for-evaluate.md`:
- The **concrete prior incident** Story 14.3 cites in the new task-entry per AC4. Story 13.5.5's close-out documentation reported `25,002 / 26,467` for the production / filesanity binaries; the actual binary was `24,996 / 26,461`. Six-byte gap. The story built one binary and reported another. Caught at 13.5.6 audit-walk only because the audit story re-ran `wc -c` rather than inheriting.
- Codified as Lesson 13.5-F at `epic-13.5-retro-2026-05-07.md:88` (incident statement) + `:121` (formal lesson row) + Action Item A4 (template-edit owner).

**Story 13.5.6 (Epic 13.5 close-out audit + antforth-2.0 release gate)** at `_bmad-output/implementation-artifacts/13-5-6-epic-13-5-close-out-gate.md`:
- The story that *caught* the 13.5.5 doc-drift via re-`wc -c`. Direct evidence that the discipline B.3 codifies *works* — it's not aspirational, it's been demonstrated to catch the very class of drift that motivates it.

**Story 14.1 (B.1 — PAD canonical doc)** at `_bmad-output/implementation-artifacts/14-1-pad-documented-as-canonical-transient-buffer-for-test-authors.md`:
- Story 14.3's grand-predecessor in Epic 14. Closed 2026-05-08 with zero binary delta. Inheritable shape: doc/workflow-only; FR-P3-15 verdict-criterion meta-pattern (synthesised attempt + grep); S9 documented exempt; carry-forward Status row update at story-close.
- Story 14.1 surfaced and reconciled the v2.0.0-banner-bump 1-byte drift (24,996 documented vs. 24,995 actual). Story 14.3 inherits this reconciliation but practices it from the file system rather than transcribing.

**Story 14.2 (B.2 — "mirrors prior arm" HALT-signal lint)** at `_bmad-output/implementation-artifacts/14-2-mirrors-prior-arm-halt-signal-lint-in-story-template.md`:
- Story 14.3's **immediate predecessor** in Epic 14. Closed 2026-05-08 (commit 80f99c8) with zero binary delta. Reported figures: 24,995 / 26,460. **Story 14.3 MUST re-measure these directly at Task 1.1, not transcribe.** This is the structural enforcement of the discipline B.3 codifies — Story 14.3's own dev-pass is the first downstream consumer of the discipline.
- Story 14.2 carries a directly-relevant honest-disposition pattern at AC7 / "AC7 honest disposition" Completion Notes section — when a structural AC's wording can't actually be satisfied (installer-manifest enumerates modules not files; `_bmad/` is gitignored), the AC is dispositioned as "constraint named, not closed" rather than silently inheriting a false PASS. Story 14.3's AC6 inherits this pattern verbatim.
- Story 14.2 also surfaced a recursive-self-validation moment via AC6(d) spec drift — the drafter's expected `<critical>` count of 1/2 (pre-edit/post-edit) reflected only multi-line blocks; actual was 16/17 (single-line inline directives missed). The AC was amended in-pass per the same B.2 lint's spirit (count the parts independently, don't rely on partial mental model). Story 14.3 should expect a similar recursive moment if the directly-measured figures (Task 1.1 / 1.2) diverge from Story 14.2's reported 24,995 / 26,460 — that divergence IS the verdict criterion.

**Epic 13.5 retro Lesson 13.5-F** at `_bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md:88..121`:
- The full lesson statement at `:88` quoting the 13.5.5 incident; the formal lesson-row at `:121` titled "Documentation drift between stories is a real failure mode"; Action Item A4 (story-template edit owner) cited at `:192`-region (per the retro's Action Items section).

**PD-1 precedent (Story 13.5.0 — workflow & create-story AC alignment)** at `_bmad-output/implementation-artifacts/13.5-0-pd-1-workflow-and-create-story-ac-alignment.md`:
- The **structural precedent** for any workflow-file edit in Phase 3. PD-1 deleted `step-05-adversarial-review.md`, retargeted `step-04-self-check.md`, and added the FIRST `<critical>` block to `instructions.xml`. PD-1's persistence model has held for ~3 days (since 2026-05-05) without an installer re-run. Story 14.3's `template.md` edit inherits the same persistence model. AC6 names the constraint per Story 14.2's honest-disposition pattern.

### Architecture context (Phase-3 architecture, 2026-05-08)

`_bmad-output/planning-artifacts/architecture.md` pins the following for Story 14.3:

- **§"B.3-D1: Story-to-story binary handoff (re-`wc -c`)"** (line 260) — Edit lands in `_bmad/bmm/workflows/4-implementation/create-story/template.md`. The "Pre-edit baseline" task captures `wc -c src/antforth.com` (or the appropriate build artifact path) directly, not inheriting from the prior story's reported number.
- **§"Pre-edit baseline task entry example (B.3 pattern)"** (line 424..433) — markdown checklist format; first bullet is `- [ ] Capture current binary size: \`wc -c build/antforth.com\` → record in story Dev Notes`; sub-bullet under it: `- **Do not** inherit the prior story's reported number — re-\`wc -c\` from the actual current build artifact (B.3 / Lesson 13.5-F)`; second bullet: `- [ ] Capture current \`make test-repl\` baseline pass count`; placeholder: `- [ ] [...other pre-edit tasks per template...]`.
- **§"Verdict-criterion meta-pattern (all four)"** (line 264..268) — B.3 row: "the template's pre-edit task references `wc -c` directly, grep-able from `_bmad/bmm/workflows/4-implementation/create-story/template.md`". Story 14.3 AC #5 implements this verdict criterion (with the recursive-self-validation extension at AC #5(e)).
- **§"Implications for B.x verdict criteria"** (line 217) — "If a lead-in fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration". Story 14.3 ACs #5, #7, #8 + Tasks 4, 5 enforce this structurally.
- **§"Per-story binary delta envelopes"** (line 343..346) — B.2 / B.3 / B.4 = 0 (workflow-file only). Story 14.3 AC #7 enforces.
- **§"Hardware-smoke cadence (S9 / NFR-P3-7)"** (line 456) — "Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped". Story 14.3 AC #7 + Task 6.1 implement this.
- **§"Existing files modified in Phase 3"** (line 605..606) — `_bmad/bmm/workflows/4-implementation/create-story/template.md | Add wc -c task to "Pre-edit baseline" section (B.3) | B.3`. Story 14.3 lands the B.3 row.
- **§"Recommended sequencing within the lead-in"** (line 932..937) — "3. **B.3** — `wc -c` task added to `template.md` (single-file edit)". Single-file edit story (no `instructions.xml` touch in scope; that's Stories 14.2 + 14.4's site).
- **§"Workflow-file edit identity"** (line 395..400) — Pre-edit baseline tasks → `_bmad/bmm/workflows/4-implementation/create-story/template.md` (the architecturally-pinned edit site). Story 14.3 lands the edit in that file (no alternative considered).
- **§"All Phase-3 dev-pass agents MUST"** item 9 (line 484) — "Re-`wc -c` at the start of every dev-pass — never inherit the prior story's reported binary size". This is the standing commitment B.3 lifts to enforcement surface; Story 14.3 IS the surface for item 9.
- **§"Pre-edit baseline tasks in the story template (B.3) catch binary-handoff drift at dev-pass start"** (line 489) — codifies the catch mechanism at architectural level.

### PRD Phase-3 context (2026-05-08)

`_bmad-output/planning-artifacts/prd.md` for Story 14.3's binding requirements:

- **FR-P3-13 (B.3)** at `prd.md:524` — "A story drafter using the project's story-template encounters, in the 'Pre-edit baseline' task, an explicit instruction to capture `wc -c` of the current binary itself rather than inheriting the prior story's reported number (B.3 — closes the 6-byte 13.5.5-close-out doc-drift gap)."
- **FR-P3-15 (verdict-criterion meta-pattern)** at `prd.md:526` — "The story-template's discipline edits (B.2–B.4) carry their own verdict criteria in the lead-in stories that introduce them — each B.2/B.3/B.4 story tests that the new template would have caught the prior-incident pattern that motivated it (e.g. B.2 verifies the lint catches a synthesised 'mirror' phrase; B.3 verifies the `wc -c` task captures the actual binary)." Story 14.3 AC #5 + Task 4 implement B.3's surface of FR-P3-15.
- **FR-P3-22..25 (phase-wide regression constraint)** — 973 PASS / 0 FAIL baseline + CODE-source byte-identical assembly + unprefixed numeric-literal form preserved. Story 14.3's AC #8 enforces the 973 PASS / 0 FAIL gate.
- **NFR-P3-2 (Phase-3-specific cumulative ROM budget)** — +200 bytes cap (24,996 → ≤ 25,200); B.3 envelope 0 bytes. Story 14.3's AC #7 enforces.
- **NFR-P3-7 (S9 codification)** — every binary-delta story runs hardware smoke; zero-binary-delta stories document exemption explicitly. Story 14.3's AC #7 + Task 6.1 enforce. Same exemption shape as Stories 14.1 + 14.2.
- **NFR-P3-18 (story-template discipline as quality attribute)** at `prd.md:590` — "The story-template lints / HALT signals / pre-edit task additions established by B.1–B.5 fire automatically when triggered (lint catches 'mirrors' phrase, **`wc -c` task captures actual binary**, figure-drift discipline applies at draft time, PRD-vs-architecture sync runs at doc-build time). A story drafter does not need to remember to invoke them; they are baked into the workflow." Story 14.3 IS the structural surface of NFR-P3-18 for the `wc -c` task.
- **NFR-P3-24 (S3 — real-byte-count estimation + capstone-aware drafting)** at `prd.md:604` — Story byte-budget rationale is itemised per-part. Story 14.3's per-component itemisation in the Severity table (the byte-budget table at line :180-region of this document) demonstrates the discipline; the rationale is itemised, not "mirrors Stories 14.1/14.2 shape".
- **NFR-P3-31 (S10 — workflow > memory > prompt)** — Process discipline lives in workflow files, not in conversational prompts or memory entries. Story 14.3's edit lands in the workflow file (`template.md`, per CCD-P3-2), not in a memory entry like `feedback_re_wc_c_baseline.md` (which would be the architecture §"Bad — workflow edit (anti-pattern)" violation).

### Implementation site references (file:line)

- **Target file** — `_bmad/bmm/workflows/4-implementation/create-story/template.md` (49 lines as of post-Story-14.2 close)
- **Current section structure** — lines :1..:49: Story header (`:1`), Status line (`:3`), validation note (`:5`), `## Story` (`:7..:11`), `## Acceptance Criteria` (`:13..:15`), `## Tasks / Subtasks` (`:17..:22`), `## Dev Notes` (`:24..:38`), `## Dev Agent Record` (`:40..:49`)
- **Insertion site** — between `## Acceptance Criteria` block end (`:15`) and `## Tasks / Subtasks` header (`:17`) for Form B; OR immediately after `## Tasks / Subtasks` (`:17`) for Form A (Form A inserts a new `### Pre-edit baseline` subsection before line :19's "Task 1 (AC: #)" placeholder)
- **Architecture B.3 spec** — `_bmad-output/planning-artifacts/architecture.md:260` (§"B.3-D1: Story-to-story binary handoff")
- **Architecture canonical task-entry example** — `_bmad-output/planning-artifacts/architecture.md:424..433` (§"Pre-edit baseline task entry example (B.3 pattern)")
- **Architecture verdict criterion** — `_bmad-output/planning-artifacts/architecture.md:264..268` (§"Verdict-criterion meta-pattern (all four)" — B.3 row at line :267)
- **Architecture sequencing recommendation** — `_bmad-output/planning-artifacts/architecture.md:932..937` (§"Recommended sequencing within the lead-in")
- **Architecture standing-commitment item 9** — `_bmad-output/planning-artifacts/architecture.md:484` (§"All Phase-3 dev-pass agents MUST" item 9 — "Re-`wc -c` at the start of every dev-pass")
- **Architecture pattern enforcement** — `_bmad-output/planning-artifacts/architecture.md:489` (§"Pattern enforcement mechanisms" line 4: "Pre-edit baseline tasks in the story template (B.3) catch binary-handoff drift at dev-pass start")
- **Concrete prior incident statement** — `_bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md:88` (the 13.5.5 doc-drift narrative)
- **Lesson 13.5-F formal row** — `_bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md:121` (lesson cite "Documentation drift between stories is a real failure mode")
- **Action Item A4 (template-edit owner)** — `_bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md` Action Items section
- **Story 13.5.5 close-out reported figures** — `_bmad-output/implementation-artifacts/13.5-5-td-7-save-input-restore-input-for-evaluate.md` (the 25,002 / 26,467 reported vs. 24,996 / 26,461 actual incident; specifics at `epic-13.5-retro-2026-05-07.md:88`)
- **Story 13.5.6 audit-walk that caught the drift** — `_bmad-output/implementation-artifacts/13-5-6-epic-13-5-close-out-gate.md`
- **Carry-forward catalogue B.3 row** — `docs/PHASE-3-CARRY-FORWARD.md:34` (current row to update)
- **Carry-forward catalogue Status Tracking section** — `docs/PHASE-3-CARRY-FORWARD.md:96..` (Story 14.2's B.2 row at `:103` for shape precedent)
- **BMAD installer manifest** — `_bmad/_config/manifest.yaml` (per-module manifest; bmm module owns the workflow-tree per `:13..:19`; per-file manifest does NOT exist — see AC6 reading per Story 14.2 honest-disposition precedent)
- **Epics 14.3 spec** — `_bmad-output/planning-artifacts/epics.md:351..370` (Story 14.3 ACs #1..#8)
- **Epic 14 shape** — `_bmad-output/planning-artifacts/epics.md:292..305` (Epic 14 lead-in cluster)
- **Predecessor story (B.1)** — `_bmad-output/implementation-artifacts/14-1-pad-documented-as-canonical-transient-buffer-for-test-authors.md` (Story 14.1 close-out 2026-05-08)
- **Immediate predecessor (B.2)** — `_bmad-output/implementation-artifacts/14-2-mirrors-prior-arm-halt-signal-lint-in-story-template.md` (Story 14.2 close-out 2026-05-08)

### Standards / discipline citations

- **Lesson 13.5-F** ("Documentation drift between stories is a real failure mode.") — `epic-13.5-retro-2026-05-07.md:121`
- **Action Item A4** (template-edit: "Pre-edit baseline" task captures `wc -c` itself, not the prior story's reported number) — `epic-13.5-retro-2026-05-07.md` Action Items section
- **Standing commitment S3** (real-byte-count estimation + capstone-aware drafting) — codified as NFR-P3-24 at `prd.md:604`. Sibling discipline to B.3's "re-`wc -c`": B.2 fires at byte-budget-rationale review; B.3 fires at Pre-edit baseline capture.
- **Standing commitment S10** (workflow > memory > prompt) — codified as NFR-P3-31; per architecture §"Bad — workflow edit (anti-pattern)" line 554..559
- **CCD-P3-2** (Process discipline lives in workflow files) — `architecture.md:197..217`
- **PD-1 enforcer pattern** — `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:20..31` (the workflow-file-edit-discipline precedent; Story 14.3 inherits the same discipline at the template-file site)
- **B.2 enforcer block (Story 14.2)** — `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:33..60` (sibling discipline to B.3 — "mirrors prior arm" lint at instructions.xml; this story lands the "re-`wc -c`" task at template.md)

### Standing-commitment context (S1..S12)

Per Epic-13.5 retro 2026-05-07, all 12 standing commitments held across the retro and were codified as NFR-P3-22..33 in the Phase-3 PRD. For Story 14.3:

- **S1 — adversarial review fresh-context external.** Story 14.3 ACs do NOT enumerate "trigger an adversarial review pass" or equivalent; PD-1 enforcer (`<critical>` block in `instructions.xml:20..31`) holds; B.2's enforcer at `:33..60` reinforces the same pattern.
- **S2 — REPL-piped tests as default.** Story 14.3 is workflow-file-edit-only; no new tests required. The new template-task entry IS the discipline artefact.
- **S3 — real-byte-count estimation + capstone-aware drafting.** Story 14.2 landed the structural enforcer for "mirrors prior arm" byte-budget shorthand. Story 14.3 lands the structural enforcer for "re-`wc -c` at dev-pass start" — sibling discipline at a different point in the authoring lifecycle. Codified as NFR-P3-24. Story 14.3's close marks the **transition of A4 (Lesson 13.5-F's Action Item) from why-surface to enforcement-surface** discipline (per CCD-P3-2).
- **S4 — AC composition.** ACs #1..#8 stand alone or compose cleanly with named antecedents (AC #5 names ACs #1..#4 + the recursive-self-validation extension; AC #7 + #8 stand independently as regression gates).
- **S5 — PARTIAL → HALT.** ACs #1, #5, #7, #8 carry HALT discipline (Tasks 1.1 HALT-on-divergent-figure, 4.1 HALT-on-failed-grep, 5.1 HALT-on-non-zero-delta, 5.3 HALT-on-test-count-movement).
- **S8 — no "pre-existing" discharge for correctness defects.** Story 14.3 closes a workflow-discipline gap (B.3 carry-forward), not a correctness defect; S8 not directly engaged. AC6's installer-manifest reading explicitly names the constraint per S8 honest-disposition pattern (Story 14.2 AC7 precedent).
- **S9 — per-story hardware smoke.** Story 14.3 is exempt + documented (AC #7 + Task 6.1). Same exemption shape as Stories 14.1 and 14.2.
- **S10 — workflow > memory > prompt.** New task-entry lands in the workflow-tree file (`template.md`), NOT in a memory entry like `feedback_re_wc_c_baseline.md`. Per architecture §"Bad — workflow edit (anti-pattern)" line 554..559, the memory-entry placement would be the S10 violation; Story 14.3 explicitly does not violate.
- **S11 — version-surface audit at tag-applicable close-out.** Story 14.3 is **not** tag-applicable per `epics.md` Epic 14 §"Shape" ("Tag-applicable close-out (S11 audit) on Ant's call — banner-only point-release valid but optional"). Same as Stories 14.1 and 14.2.
- **S12 — hardware-typed probe authoring discipline.** Not directly engaged (workflow-file edit, not a probe).

### Pre-edit baseline reconciliation — documentation-drift note

Per Stories 14.1 and 14.2 Pre-edit baseline reconciliations (and original `13.5-6-…md` Task 2 Documentation-drift reconciliation, Epic-13.5 close-out), the Phase-3 PRD + architecture + epics docs **all cite 24,996 bytes** as the post-Epic-13.5 baseline. The actual current build at HEAD `80f99c8` (the Story-14.2 commit) is **24,995 bytes** — 1 byte less than the documented Epic-13.5-close figure. This is the v2.0.0 banner-bump drift Story 14.1 surfaced and reconciled.

This reconciliation is **not a Story-14.3 regression** — it's the same illustrative inheritance-drift artefact carried from Story 13.5.6's close, confirmed unchanged through Stories 14.1 + 14.2 closes, and now re-confirmed at Story 14.3's Task 1.1. **Per the discipline B.3 codifies** (Lesson 13.5-F), Story 14.3's Task 1.1 / 1.2 re-`wc -c`s directly rather than inheriting any prior story's reported number. The expected directly-measured figures are 24,995 / 26,460 (matching Stories 14.1 / 14.2's reports — they are the most-recent-prior-story reported values, not gospel; Task 1.1 verifies them). If the directly-measured figures diverge, the divergence itself is evidence of the doc-drift class B.3 prevents and must be investigated per Lesson 13.5-F before the dev-pass proceeds.

### Project Structure Notes

- **No new architectural surface.** Story 14.3 modifies one existing file (`_bmad/bmm/workflows/4-implementation/create-story/template.md`) and updates one Status row (`docs/PHASE-3-CARRY-FORWARD.md:34`). Per `architecture.md` §"Project Structure & Boundaries", the kernel boundary is frozen for Phase 3 — Story 14.3 does not touch any `src/*.asm` file.
- **Workflow-file boundary alignment.** Per `architecture.md` §"Workflow-file edit identity" line 395..400 + §"Existing files modified in Phase 3" line 605..606: B.3's edit lands in `template.md`. Story 14.3 lands the artefact in the architecturally-pinned file (no alternative location considered).
- **Section placement decision (Form A vs. Form B per Task 2.1).** The architecture's task-entry example (line 426..433) shows the section under a `### Pre-edit baseline tasks` header — `###` depth signals the section is a subsection of an outer `##` section (likely `## Tasks / Subtasks`). Form A (subsection of `## Tasks / Subtasks`) matches the architecture example more closely; Form B (top-level `## Pre-edit baseline`) gives the section higher visibility but breaks from the architecture example's nesting. **Recommendation: Form A.** Final pick documented in Completion Notes per Task 2.1.
- **No installer-manifest edit.** Per AC6 reading (Story 14.2 honest-disposition precedent): the actual installer manifest at `_bmad/_config/manifest.yaml` enumerates *modules*, not per-file edit lists. Story 14.3 does NOT edit the installer manifest. PD-1 (Story 13.5.0) and B.2 (Story 14.2) are the working precedents — their `<critical>` blocks have persisted at the file level since 2026-05-05 / 2026-05-08 dev-passes without any installer-manifest entries, because no installer re-run has occurred. Story 14.3 inherits the same persistence model.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:292..305`] Epic 14: Phase-3 Process Foundation — lead-in cluster B.1..B.5
- [Source: `_bmad-output/planning-artifacts/epics.md:351..370`] Story 14.3 ACs #1..#8 verbatim
- [Source: `_bmad-output/planning-artifacts/prd.md:524`] FR-P3-13 (B.3) "re-`wc -c` at dev-pass start" template-task instruction
- [Source: `_bmad-output/planning-artifacts/prd.md:526`] FR-P3-15 verdict-criterion meta-pattern
- [Source: `_bmad-output/planning-artifacts/prd.md:590`] NFR-P3-18 story-template discipline as quality attribute
- [Source: `_bmad-output/planning-artifacts/prd.md:604`] NFR-P3-24 S3 — real-byte-count estimation + capstone-aware drafting
- [Source: `_bmad-output/planning-artifacts/prd.md:611`] NFR-P3-31 S10 — workflow > memory > prompt
- [Source: `_bmad-output/planning-artifacts/architecture.md:197..217`] CCD-P3-2 — Process discipline lives in workflow files
- [Source: `_bmad-output/planning-artifacts/architecture.md:217`] Implications for B.x verdict criteria (discipline-as-deliverable)
- [Source: `_bmad-output/planning-artifacts/architecture.md:260`] B.3-D1 architectural decision
- [Source: `_bmad-output/planning-artifacts/architecture.md:264..268`] B.3 verdict criterion (template-task grep-able)
- [Source: `_bmad-output/planning-artifacts/architecture.md:343..346`] Per-story binary delta envelope (B.3 = 0 bytes)
- [Source: `_bmad-output/planning-artifacts/architecture.md:395..400`] Workflow-file edit identity (template.md owns B.3)
- [Source: `_bmad-output/planning-artifacts/architecture.md:424..433`] Pre-edit baseline task entry example (B.3 pattern)
- [Source: `_bmad-output/planning-artifacts/architecture.md:456`] Hardware-smoke cadence (S9 exemption for B.1–B.5)
- [Source: `_bmad-output/planning-artifacts/architecture.md:484`] All Phase-3 dev-pass agents MUST item 9 (re-`wc -c` standing commitment)
- [Source: `_bmad-output/planning-artifacts/architecture.md:489`] Pattern enforcement mechanisms (template-task catches binary-handoff drift)
- [Source: `_bmad-output/planning-artifacts/architecture.md:605..606`] Existing files modified in Phase 3 (B.3 in `template.md`)
- [Source: `_bmad-output/planning-artifacts/architecture.md:932..937`] Recommended sequencing within the lead-in (B.3 single-file edit step 3)
- [Source: `_bmad-output/implementation-artifacts/13.5-0-pd-1-workflow-and-create-story-ac-alignment.md`] PD-1 precedent — first workflow-file-edit dev-pass
- [Source: `_bmad-output/implementation-artifacts/13.5-5-td-7-save-input-restore-input-for-evaluate.md`] Story 13.5.5 — concrete prior incident (6-byte close-out doc-drift)
- [Source: `_bmad-output/implementation-artifacts/13-5-6-epic-13-5-close-out-gate.md`] Story 13.5.6 — audit-walk that caught the drift via re-`wc -c`
- [Source: `_bmad-output/implementation-artifacts/14-1-pad-documented-as-canonical-transient-buffer-for-test-authors.md`] Story 14.1 (B.1) — predecessor story shape template
- [Source: `_bmad-output/implementation-artifacts/14-2-mirrors-prior-arm-halt-signal-lint-in-story-template.md`] Story 14.2 (B.2) — immediate predecessor; honest-disposition pattern at AC7; recursive-self-validation moment at AC6(d)
- [Source: `_bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md:88`] Story 13.5.5 6-byte doc-drift narrative
- [Source: `_bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md:121`] Lesson 13.5-F formal row
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/template.md`] Target file (49 lines pre-Story-14.3)
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:20..31`] PD-1 `<critical>` block — workflow-file-edit precedent
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:33..60`] B.2 `<critical>` block — sibling discipline at instructions.xml site
- [Source: `_bmad/_config/manifest.yaml:13..19`] BMAD installer manifest (module-level; no per-file enumeration)
- [Source: `docs/PHASE-3-CARRY-FORWARD.md:34`] B.3 carry-forward catalogue row
- [Source: `docs/PHASE-3-CARRY-FORWARD.md:103`] B.2 closure row (Story 14.2) — shape precedent for B.3 closure row

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context) — dev-story workflow

### Debug Log References

- Pre-edit `make test-repl` output: `/tmp/14-3-pre-edit.out` — 973 PASS / 0 FAIL (matches expected baseline)
- Post-edit `make test-repl` output: `/tmp/14-3-post-edit.out` — 973 PASS / 0 FAIL (zero movement from pre-edit; AC #8 ✓)

### Completion Notes List

**Story 14.3 / B.3 closure summary.** The `### Pre-edit baseline` subsection (Form A) now lives at the top of `## Tasks / Subtasks` in `_bmad/bmm/workflows/4-implementation/create-story/template.md` (lines 19..24). First bullet captures `wc -c build/antforth.com → record in story Dev Notes`; sub-bullet under it carries the binding instruction `Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F)`. Second bullet captures the `make test-repl` baseline pass count. Third bullet preserves the architecture's `[...other pre-edit tasks per template...]` placeholder. Together these three bullets land Lesson 13.5-F's Action Item A4 at the workflow-tree enforcement surface (CCD-P3-2 / S10), promoting the discipline from why-surface (memory entries, retro doc) to structural enforcement.

**AC verdict table (all PASS).**

| AC | Verdict | Evidence |
|---|---|---|
| AC1 (Pre-edit baseline section + wc -c task) | ✅ PASS | `### Pre-edit baseline` subsection at template.md:19; first bullet at line 21 contains literal `wc -c` and `build/antforth.com` |
| AC2 (Do not inherit + reasoning + cite) | ✅ PASS | line 22 contains "Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F)" |
| AC3 (wc -c task is first in section) | ✅ PASS | first task in the new section is the wc -c bullet (line 21); no other task precedes it |
| AC4 (Lesson 13.5-F cite) | ✅ PASS | "(B.3 / Lesson 13.5-F)" parenthetical on line 22 satisfies AC4(a) per AC4 minimum-acceptable-cite-form clause |
| AC5(a) `grep 'wc -c'` ≥ 1 | ✅ PASS | 2 matches (lines 21, 22) |
| AC5(b) `grep -E 'Do not inherit|Don.?t inherit'` ≥ 1 | ✅ PASS | 1 match (line 22) — see in-pass spec amendment below |
| AC5(c) `grep -E 'Lesson 13\.5-F|13\.5-F'` ≥ 1 | ✅ PASS | 1 match (line 22) |
| AC5(d) `grep -E 'Pre-edit'` ≥ 1 | ✅ PASS | 1 match (line 19, section header) |
| AC5(e) recursive self-validation | ✅ PASS | Task 1.1 / 1.2 ran `wc -c build/antforth.com build/antforth_filesanity.com` directly; outputs `24995 build/antforth.com` / `26460 build/antforth_filesanity.com` reproduced verbatim; figures NOT transcribed from Story 14.2's File List |
| AC6 (installer-manifest persistence model named) | ✅ PASS — constraint named, not closed | see §"AC6 honest disposition" below |
| AC7 (zero binary delta + S9 exempt) | ✅ PASS | post-edit `wc -c build/antforth.com` = 24,995 (Δ=0); `wc -c build/antforth_filesanity.com` = 26,460 (Δ=0); S9 exempt note recorded |
| AC8 (973 PASS / 0 FAIL preserved) | ✅ PASS | pre-edit 973/0; post-edit 973/0; zero movement |

No PARTIAL verdicts. S5 HALT discipline preserved.

**Recursive self-validation moment (AC5(b) spec-drift, in-pass amended per Story 14.2 AC6(d) precedent).** The architecture's canonical task-entry example at `architecture.md:430` uses markdown bold `**Do not**` for emphasis on the "Do not" imperative. AC5(b)'s strict regex `Do not inherit|Don.?t inherit` cannot match across the literal `**` characters between "Do not" and "inherit". Two paths considered:

1. **Drop the bold from the template's "Do not"** so the literal "Do not inherit" appears, satisfying the AC's regex as written.
2. **Amend the AC's regex** to match the markdown-emphasised form (e.g., `Do not\*?\*? inherit`).

Path 1 picked. Rationale: the architecture example's bold formatting is incidental emphasis, not load-bearing — the function of the line is the imperative instruction "Do not inherit the prior story's reported number", which is preserved verbatim regardless of bold formatting. Path 2 would cascade: any future drafter copying the template-text-as-canonical and applying their own bold formatting would re-trigger the same regex drift. Path 1 makes the literal "Do not inherit" canonical in the template, removing the regex/markdown coupling.

This IS the recursive self-validation moment Story 14.3's Dev Notes §"Recursive-self-validation note" anticipated — Story 14.3's own dev-pass surfaces a spec-drift between AC text and architecture canonical example, and resolves it in-pass per the same pattern Story 14.2's AC6(d) used. The B.3 discipline lands; the AC5(b) regex passes as written; the architecture's canonical-example bold formatting is the only edit-target deviation, and that deviation is itself the documented in-pass amendment. Story 14.3 also reports this as a candidate for an architecture-doc one-line correction (drop the `**` from the example) at the next architecture refresh — not blocking this story, but noted for the next doc-build sync pass.

**AC6 honest disposition (constraint named, not closed) — inherited verbatim from Story 14.2 AC7 precedent.** The BMAD installer manifest at `_bmad/_config/manifest.yaml` enumerates *modules* (e.g., `bmm` v6.0.4 with `source: built-in` at line 13..19), not per-file edits. The file `_bmad/bmm/workflows/4-implementation/create-story/template.md` is owned by the `bmm` module's source-of-truth (upstream of this repo); a future installer re-run on the bmm module would overwrite the local edit. `_bmad/` is gitignored at `.gitignore:2`, so the local edit is **not** tracked in git. Persistence model: identical to PD-1 (Story 13.5.0, 2026-05-05) and B.2 (Story 14.2, 2026-05-08) — "lucky persistence" until an installer re-run occurs. No installer re-run has happened since 2026-05-05; PD-1's `<critical>` block at `instructions.xml:20..31`, B.2's block at `instructions.xml:33..60`, B.1's `tests/README.md` (in-tree, IS in git), and now B.3's Pre-edit baseline section all persist on the same model. **Closure path** when a bmm v6.0.5+ upstream-PR mechanism becomes available: B.1 + B.2 + B.3 + B.4 (Story 14.4 still pending) become candidates for upstreaming. Until then, the local edits ARE the enforcement surface. AC6 disposition = **constraint named, not closed**.

**Standing-commitment walk (S1..S12 — all hold).**

- **S1** (adversarial review fresh-context external) — ACs do NOT enumerate any in-pass adversarial review trigger. PD-1 `<critical>` block at `instructions.xml:20..31` enforces; B.2's block at `:33..60` reinforces. ✓
- **S2** (REPL-piped tests as default) — workflow-file-edit-only story; no new tests required. The new template-task entry IS the discipline artefact. ✓
- **S3** (real-byte-count estimation + capstone-aware drafting) — sibling-discipline transition completed at this story-close: B.2 fires at byte-budget-rationale review; B.3 (this story) fires at Pre-edit baseline capture. Together they move A3 + A4 from why-surface to enforcement-surface. ✓
- **S4** (AC composition) — ACs #1..#8 stand alone or compose cleanly with named antecedents. No nested-conditional rats' nests. ✓
- **S5** (PARTIAL → HALT) — no PARTIAL verdicts in this dev-pass. Task 2.4 in-pass spec-drift was root-caused and resolved in-pass per Story 14.2 AC6(d) precedent; not silently carried. ✓
- **S6/S7** — phase-9-architecture-handoff / specific Forth-runtime conventions — not engaged in this workflow-file-only story.
- **S8** (no "pre-existing" discharge for correctness defects) — Story 14.3 closes a workflow-discipline gap, not a correctness defect; S8 not directly engaged. AC6 names the installer-manifest constraint per S8 honest-disposition pattern (no silent inheritance). ✓
- **S9** (per-story hardware smoke) — exempt + documented (Task 6.1). Same exemption shape as Stories 14.1 and 14.2. ✓
- **S10** (workflow > memory > prompt) — new task-entry lands in `template.md` (workflow-tree file), NOT in a memory entry like `feedback_re_wc_c_baseline.md`. No S10 violation. ✓
- **S11** (version-surface audit at tag-applicable close-out) — not tag-applicable; banner-bump optional per Ant's call (`epics.md` Epic 14 §"Shape"). Same as Stories 14.1 and 14.2. ✓
- **S12** (hardware-typed probe authoring discipline) — not directly engaged (workflow-file edit, not a probe). ✓

**Component byte-budget itemisation (B.2 lint compliance, Story 14.3 dev-pass).** Per the per-component table in §"Severity / Phase Re-Statement", verified at story-close:

| Component | Pre-edit | Post-edit | Δ |
|---|---|---|---|
| `build/antforth.com` | 24,995 | 24,995 | 0 |
| `build/antforth_filesanity.com` | 26,460 | 26,460 | 0 |
| `template.md` text edit | 49 lines | 56 lines | +7 lines (workflow file, not in kernel build path) |
| `docs/PHASE-3-CARRY-FORWARD.md` Status row | 1 row (B.2) | 2 rows (B.2, B.3) | +1 row (doc, not in kernel build path) |

Zero kernel-byte movement confirmed component-by-component. The +7 lines on template.md and +1 row on PHASE-3-CARRY-FORWARD.md are workflow-file / doc edits and have no kernel binary impact.

**Form A vs. Form B section-placement decision.** Form A picked (`### Pre-edit baseline` subsection at top of `## Tasks / Subtasks`). Rationale: matches the architecture's canonical example (line 426..433) which uses `###` depth for the Pre-edit baseline section header (signals subsection of an outer `##` block); keeps the section visually adjacent to the rest of the task list, which means a drafter filling out the template top-to-bottom encounters the Pre-edit baseline tasks immediately before story-specific Task 1 — exactly the moment B.3 codifies. Form B (top-level `## Pre-edit baseline` between `## Acceptance Criteria` and `## Tasks / Subtasks`) would have been more visually prominent but breaks from the architecture's nesting choice. Both forms satisfied AC3; Form A picked for architecture-fidelity.

**Optional sub-task scope decisions.** Task 2.5 (the `make test-repl` baseline-capture bullet) was included per the architecture example shape (small extra value at no cost). Task 2.6 (third bullet) — the architecture example placeholder `- [ ] [...other pre-edit tasks per template...]` was preserved intact rather than enumerated, leaving room for future drafters to add story-specific pre-edit tasks (e.g., `make` build-clean check, git HEAD capture, regression-touchpoint inventory) without renaming the existing bullets.

**Carry-forward catalogue B.3 row landed at `docs/PHASE-3-CARRY-FORWARD.md:104`** immediately after the B.2 row at line 103; closure note enumerates the 5/5 verdict criteria PASSed (a..e) plus the zero-binary-delta result and the in-pass spec-amendment narrative. Format mirrors the B.2 row precedent verbatim.

**Sprint-status row** at `_bmad-output/implementation-artifacts/sprint-status.yaml` flipped `ready-for-dev` → `in-progress` (at dev-pass start, after Task 1) → `review` (at dev-pass close, this commit). Honest disposition: the canonical three-state sequence was actually executed (no `backlog→review` shortcut).

### File List

**Modified:**
- `_bmad/bmm/workflows/4-implementation/create-story/template.md` — added `### Pre-edit baseline` subsection at top of `## Tasks / Subtasks` (lines 19..24); 49 → 56 lines (+7 lines). **Note:** file is gitignored per `.gitignore:2`; persistence is "lucky" — see AC6 honest disposition.
- `docs/PHASE-3-CARRY-FORWARD.md` — added B.3 closure row at line 104 after B.2 row.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — flipped `14-3-…` row from `ready-for-dev` → `in-progress` → `review`.
- `_bmad-output/implementation-artifacts/14-3-story-to-story-binary-handoff-re-wc-c-at-dev-pass-start.md` — this file; populated Tasks/Subtasks checkboxes, Status, Dev Agent Record (Completion Notes / File List / Change Log).

**No new files created. No `src/*.asm` files modified.** Zero kernel binary delta confirmed at Tasks 5.1 / 5.2.

### Change Log

| Date | Change | Files |
|---|---|---|
| 2026-05-08 | Story 14.3 (B.3) dev-pass: added `### Pre-edit baseline` subsection to story-template's `## Tasks / Subtasks`, codifying Lesson 13.5-F's Action Item A4 (re-`wc -c` at dev-pass start) at the workflow-tree enforcement surface. First bullet captures `wc -c build/antforth.com`; sub-bullet carries "Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F)". Second bullet captures `make test-repl` baseline pass count. Third bullet preserves architecture's `[...other pre-edit tasks per template...]` placeholder. Verdict criteria 5/5 PASS. Zero binary delta (24,995 / 26,460 unchanged). 973 PASS / 0 FAIL preserved. Recursive self-validation moment (AC5(b) regex vs. architecture's `**Do not**` markdown bold) resolved in-pass per Story 14.2 AC6(d) precedent — bold dropped from template literal so AC's regex passes as written; architecture-doc one-line correction noted as candidate for next doc-sync pass. AC6 honest disposition: persistence model named ("constraint named, not closed") per Story 14.2 AC7 precedent. S1..S12 all hold. S9 exempt + documented (zero binary delta). | `_bmad/bmm/workflows/4-implementation/create-story/template.md`; `docs/PHASE-3-CARRY-FORWARD.md`; `_bmad-output/implementation-artifacts/sprint-status.yaml`; `_bmad-output/implementation-artifacts/14-3-story-to-story-binary-handoff-re-wc-c-at-dev-pass-start.md` |
