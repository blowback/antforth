# Story 14.5: PRD↔architecture transcription-drift sync target — `make check-doc-sync`

Status: done

<!--
This is the FIFTH and final story of Epic 14 (Phase-3 Process Foundation),
the debt-cleanup interlude on top of the v2.0.0 baseline (commit 6599d73,
tagged 2026-05-07). Stories 14.1 / 14.2 / 14.3 / 14.4 closed B.1 / B.2 /
B.3 / B.4 (commits 274062a / 80f99c8 / 64e91bf / 7172754, all 2026-05-08,
all zero binary delta). Story 14.5 closes carry-forward item B.5 per
`docs/PHASE-3-CARRY-FORWARD.md:36` ("PD-3 — PRD-vs-architecture
transcription drift") and architecture §"B.5-D1" (`architecture.md:272..282`).

Per architecture §"Recommended sequencing within the lead-in"
(line 932..937):
  1. B.1 first — tests/README.md (DONE — Story 14.1)
  2. B.2 + B.4 together — <critical> blocks added to instructions.xml
     (B.2 DONE — Story 14.2; B.4 DONE — Story 14.4)
  3. B.3 — wc -c task added to template.md (DONE — Story 14.3)
  4. B.5 — tools/check-doc-sync/ + Makefile target (THIS STORY)

Story 14.5 is the **only Epic-14 story that creates a new tool subtree
and a new Makefile target** — the other four lead-in items were
workflow-tree edits (instructions.xml / template.md) plus a single
new doc file (tests/README.md). Story 14.5's deliverable is a
self-contained drift-checker tool at `tools/check-doc-sync/` (per
the `tools/bdos_probe/` precedent — Story 11.5.1.2's firmware
reproducer) plus a `check-doc-sync` PHONY target in the Makefile.

Closing B.5 closes the Epic-14 lead-in cluster. After Story 14.5 reaches
done, all five P1 items B.1..B.5 are discharged; the structural lints +
sync targets that shape every subsequent Phase-3 dev-pass are in place,
and Epic 14 closes (epic-14-retrospective row in sprint-status.yaml is
`optional`, per Ant's call). Epic 15 (Phase-3 Standards Close-Out — A.1
strategic body + A.2 + A.3 + B.6 + B.7 conditional + B.8 + B.9) becomes
unblocked.

Origin lineage:
  Epic 13 retro 2026-05-05 §"Documented Follow-Up Opportunities"
  row 2 (`epic-13-retro-2026-05-05.md`) — "PD-3 — PRD-vs-architecture
  transcription drift (doc-build sync step)". The retro identified the
  failure mode but did not enumerate a worked incident; the carry-forward
  catalogue (`docs/PHASE-3-CARRY-FORWARD.md:36`) classified it
  Medium-effort and slotted it as the close-out of the story-template-
  discipline cluster (because the sync target's clean-pass is the
  S11 sibling's Phase-3 invariant: doc-sync clean before any tag).
  PRD Phase-3 2026-05-08 FR-P3-16 (`prd.md:530`) — formalised B.5's
  scope: a maintainer-invoked sync target that detects PRD-vs-architecture
  transcription drift between the Phase-3 PRD and the next-revised
  architecture document; produces a drift report or a clean-pass verdict.
  Architecture Phase-3 2026-05-08 §"B.5-D1" (line 272..282) +
  §"Existing files modified in Phase 3" (line 604) +
  §"New files created in Phase 3" (line 592..593) — pinned the
  edit site (`Makefile` PHONY target invoking `tools/check-doc-sync/`
  script), the four drift checks, the output format
  (`[ok] doc-sync: 0 drift` / line-per-drift on stderr), the exit-code
  contract (0 on clean / 1 on drift), and the failure mode (advisory-only
  on `make test-repl`; expected clean before tag close-out).

Severity: tooling addition with zero kernel touch. Zero binary delta
expected (NFR-P3-2 envelope: B.5 = 0 bytes per architecture §"Per-story
binary delta envelopes" line 347 — "B.5 | 0 (Makefile + script only)").
Zero new mechanism in `src/*.asm`, zero new EQUs, zero new dictionary
words. The deliverable is a new self-contained tool subtree
(`tools/check-doc-sync/check-doc-sync.sh` + `tools/check-doc-sync/README.md`),
a `check-doc-sync` PHONY target in the Makefile, and a one-line update
to `docs/PHASE-3-CARRY-FORWARD.md`'s Status column (B.5 row → `✅ Done`
plus a closure-tracking row appended to §"Status Tracking").

Standing commitments (S1–S12, codified as NFR-P3-22..33) apply:
  S1 — adversarial review fresh-context external. ACs do NOT
       enumerate "trigger an adversarial review pass". PD-1
       <critical> block at instructions.xml:20..31 enforces.
  S2 — REPL-piped tests as default regression surface. The new
       drift-checker is NOT a REPL probe — it walks markdown
       artefacts under `_bmad-output/planning-artifacts/` and
       `docs/`. AC9's `make test-repl` regression gate confirms
       the tool addition does not perturb the kernel test surface.
  S3 — real-byte-count estimation + capstone-aware drafting.
       Stories 14.2 / 14.3 / 14.4 codified the lints; this story's
       byte-budget rationale is itemised per-component in the
       Severity table (Makefile target body + Bash script body +
       README body + carry-forward Status update — all zero
       kernel-byte cost), independent of prior stories.
  S4 — AC composition. ACs #1..#9 stand alone or compose cleanly
       with named antecedents (AC3's drift checks compose into
       AC4's exit-code contract; AC6 verdict-criterion meta-pattern
       composes over AC3..AC5).
  S5 — HALT on PARTIAL ship attempts. No "ship 8/9 ACs + spawn
       14.5.1" pattern. If the AC6 first-run produces drift items,
       the items are reconciled in-pass (per Stories 14.2/14.3/14.4
       in-pass-amendment precedent) — the story does not ship with
       drift remaining. (See Dev Notes §"Expected first-run
       disposition" for the realistic "small enumerable drift list"
       case that the architecture explicitly anticipates as
       AC-acceptable per `epics.md:409`.)
  S8 — "pre-existing" / "out-of-scope" cannot discharge correctness
       defects; this story closes a *workflow-discipline* gap
       (no transcription-drift detection at doc-build time), not
       a correctness defect. Any drift surfaced by the first run
       is treated per the architecture's verdict-criterion shape
       — clean-pass OR small enumerable drift list documented in
       Dev Notes — with reconcile-in-pass for trivially-fixable
       items (typo-class line/section drift), and explicit
       deferral with rationale for any item that would require
       a PRD or architecture rewrite to close (filed forward as
       a B.5-followup row, same shape as B.3-followup at
       `docs/PHASE-3-CARRY-FORWARD.md:105` and B.4-followup at
       `:107`, per S10/NFR-P3-31 — workflow > memory > prompt).
  S9 — mid-epic hardware-smoke cadence; **this story is a documented
       S9 exemption** (zero binary delta; AC #8 records the exemption
       explicitly per NFR-P3-7 + architecture §"Hardware-smoke
       cadence"). Same exemption shape as Stories 14.1/14.2/14.3/14.4.
  S10 — workflow > memory > prompt; the `check-doc-sync` target
        and `tools/check-doc-sync/` directory are workflow-surface
        artefacts (Makefile + script + README), NOT memory entries
        like `feedback_no_doc_drift.md` (which would be the
        architecture §"Bad — memory edit (anti-pattern)" violation
        Stories 14.1..14.4 collectively closed at five sites).
  S11 — version-surface audit applies at *tag-applicable* close-out;
        Story 14.5 is not tag-applicable (Ant's call per Epic 14
        §"Shape" — banner-only point-release valid but optional).
        Same as Stories 14.1/14.2/14.3/14.4. **However** — and
        this is the architectural significance — a tag-applicable
        close-out *after* this story lands gains a new pre-condition:
        `make check-doc-sync` clean-pass becomes a documented S11
        sibling per architecture §"Doc-sync (NEW, opt-in)"
        (`architecture.md:733`).
  S12 — hardware-typed probe authoring discipline; not directly
        engaged (the drift-checker walks markdown artefacts on
        the build host, not antforth probes).

Recursive-self-validation note. Story 14.5 is the **first Epic-14 story
to create a new external tool that operates on the planning artefacts**;
the four prior stories edited workflow-tree files consumed by the BMAD
runtime, not artefacts on the build-host filesystem. Per S5 and the
B.4 figure-drift discipline (now codified at instructions.xml:62..86,
which this story's drafter is governed by), every figure / file:line
quoted in this story has been re-validated at draft time:
  (i) `epics.md:394..414` (Story 14.5 ACs) — re-read directly during
      drafting; transcribed verbatim into the Severity table and ACs.
  (ii) `architecture.md:272..282` (B.5-D1) — re-read directly; the
      drift-check enumeration in AC3 below is a verbatim re-extraction
      from `:276..280`, not a transcription from another story.
  (iii) `architecture.md:592..593` (new files row) and `:604`
      (Makefile-modified row) — re-read directly; file-touch surface
      table below extracts both rows directly.
  (iv) `prd.md:530` (FR-P3-16) — re-read directly.
  (v) `docs/PHASE-3-CARRY-FORWARD.md:36` (B.5 carry-forward row),
      `:104` (Story 14.3 closure row precedent), `:106` (Story 14.4
      closure row precedent) — re-read directly.
  (vi) `tools/bdos_probe/bdos_probe.asm:1..15` (precedent header
      shape) — re-read directly to confirm the self-contained tool
      subtree pattern Story 14.5 inherits.

If the dev-pass surfaces a divergence between any quoted figure and
its current source-of-truth (B.4 discipline failure mode), the
divergence IS the verdict-criterion-passing recursive-self-validation
moment — investigate and reconcile per Lesson 13.5-F + PD-2 before
the dev-pass proceeds. Stories 14.2/14.3/14.4 each surfaced one
or more such moments in-pass.

Validation is optional. Run validate-create-story for quality check
before dev-story.
-->

## Story

As a **maintainer** (project lead Ant — and any future contributor) about to apply a Phase-3 antforth 2.x point-release tag,
I want a Makefile target (`make check-doc-sync`) that detects PRD-vs-architecture transcription drift across the four canonical drift surfaces — `FR-P3-N`/`NFR-P3-N` label parity, `Story X.Y` citation resolution, `§X.Y.Z` reference parity against `docs/ans-forth-core-compliance.md`, and top-level section-name parity,
So that the docs ship aligned at every tag close-out (S11 sibling — version-surface audit reads cleanly only when doc-sync also reads cleanly), closing **PD-3 (Epic 13 retro #2)**, the long-deferred Phase-3 carry-forward item identified at `epic-13-retro-2026-05-05.md` (PD-3 row in §"Documented Follow-Up Opportunities") and catalogued at `docs/PHASE-3-CARRY-FORWARD.md:36`.

This is the **fifth and final story** in Epic 14 (Phase-3 Process Foundation) — the lead-in cluster (B.1 + B.2 + B.3 + B.4 + B.5) that lands first per `docs/PHASE-3-CARRY-FORWARD.md:87` and `architecture.md:932..937`. B.1 closed in Story 14.1 (commit 274062a, 2026-05-08, zero binary delta); B.2 closed in Story 14.2 (commit 80f99c8, 2026-05-08); B.3 closed in Story 14.3 (commit 64e91bf, 2026-05-08); B.4 closed in Story 14.4 (commit 7172754, 2026-05-08, all four with zero binary delta). B.5 closes in Story 14.5 (this story). After Story 14.5 reaches `done`, Epic 14 closes (5 of 5 lead-in items discharged); Epic 15 (A.1 audit + A.2 + A.3 + B.6 + B.7 conditional + B.8 + B.9) becomes unblocked.

The story has **zero new feature scope** in the kernel and **zero binary delta** (NFR-P3-2 envelope per architecture §"Per-story binary delta envelopes" line 347: `B.5 | 0 (Makefile + script only)`). The deliverable is:

1. A new self-contained tool subtree at `tools/check-doc-sync/` (per the `tools/bdos_probe/` precedent — Story 11.5.1.2's firmware reproducer at `tools/bdos_probe/bdos_probe.asm`).
2. A project-local Bash script at `tools/check-doc-sync/check-doc-sync.sh` implementing the four drift checks per `architecture.md:276..280`.
3. Tool documentation at `tools/check-doc-sync/README.md` enumerating the drift-check rules, exit codes, and intended cadence.
4. A `check-doc-sync` PHONY target in `Makefile` invoking the script with the project root as its working directory.
5. A one-line update to `docs/PHASE-3-CARRY-FORWARD.md`'s Status column (B.5 row Status `🔄 In progress`/open → `✅ Done` plus a closure-tracking row appended to the bottom of §"Status Tracking" at line `:108+`, per the precedent established by Stories 14.1 / 14.2 / 14.3 / 14.4 closure-tracking rows at `:102` / `:103` / `:104` / `:106`).

The story is a **documented S9 hardware-smoke exemption** per NFR-P3-7 / architecture §"Hardware-smoke cadence" — *"Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped."* Same exemption shape as Stories 14.1 / 14.2 / 14.3 / 14.4.

The story carries its own **verdict criterion** per FR-P3-15 (the verdict-criterion meta-pattern that makes B.x lead-in stories discipline-as-deliverable per architecture §"Implications for B.x verdict criteria"): running `make check-doc-sync` against the current Phase-3 PRD + architecture pair (commit `7172754`, the Story-14.4 close commit) produces a known-state verdict — either **clean-pass** (`[ok] doc-sync: 0 drift` on stdout, exit 0) OR **a small enumerable drift list** (one line per drift item to stderr, exit 1), with the verdict documented in this story's Dev Notes §"AC6 first-run verdict log". Per `epics.md:409` the architecture explicitly anticipates *both* dispositions as AC-acceptable; the verdict-criterion is that the script *runs and produces a deterministic outcome*, not that the docs are pristine on first run. Drift items surfaced are reconciled in-pass per Stories 14.2/14.3/14.4 precedent (small typo-class fixes), or filed forward as a B.5-followup row per Story 14.3 / 14.4 honest-disposition pattern (any item that would require a PRD or architecture rewrite to close — exactly the B.3-followup at `:105` and B.4-followup at `:107` shapes).

If the verdict criterion fails — i.e., the script crashes, hangs, produces non-deterministic output, or fails to run from `make check-doc-sync` — the story HALTs per S5 (the new tool failed its own verdict; per architecture §"Implications for B.x verdict criteria" line 270 — *"If a lead-in story fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration"*).

---

## Severity / Phase Re-Statement (BINDING — context for every dev-pass decision)

This is a **tooling addition** story closing the long-deferred carry-forward item B.5 (originally Epic 13 retro #2 / PD-3, codified 2026-05-05). The deliverable shape is **fully pinned** by `architecture.md:272..282` (§"B.5-D1: PRD-vs-architecture transcription-drift sync"), `architecture.md:592..593` (new tool files), and `architecture.md:604` (Makefile-modified row). The script-language choice (Bash) is fixed by this story per the architecture §"Tooling boundary" deferral *"language choice (Bash, Python, etc.) deferred to B.5's story-author"* (`architecture.md:667`); Bash is picked for parity with the existing `tools/bdos_probe/` precedent's host-side scripting (which is shell-driven via Makefile recipes) and for zero-runtime-dependency on the build host — the project's documented Makefile already uses POSIX shell idioms throughout (`Makefile:81..168` etc.). No new build-host dependencies introduced.

| Dimension | Value | Source |
|---|---|---|
| **Scope** | New tool subtree (`tools/check-doc-sync/check-doc-sync.sh` + `tools/check-doc-sync/README.md`) + new `check-doc-sync` PHONY target in `Makefile` + carry-forward Status update + new B.5 closure-tracking row | `architecture.md:272..282` (§"B.5-D1"), `:592..593` (new files), `:604` (Makefile row) |
| **New files** | `tools/check-doc-sync/check-doc-sync.sh` (Bash, executable), `tools/check-doc-sync/README.md` | `architecture.md:592..593` |
| **Modified file (primary)** | `Makefile` (add `check-doc-sync` PHONY target invoking `tools/check-doc-sync/check-doc-sync.sh`; extend `.PHONY:` declaration at line `:44` to include `check-doc-sync`) | `architecture.md:604` |
| **Modified file (secondary)** | `docs/PHASE-3-CARRY-FORWARD.md` (B.5 row at line `:36` Status column unchanged per Stories 14.1..14.4 Task 3.3 precedent — Status edits land in §"Status Tracking" closure-tracking table at `:100+` only; new B.5 closure row appended after the Story-14.4 row at `:106` and the existing B.4-followup row at `:107`) | `docs/PHASE-3-CARRY-FORWARD.md:106..107` (Story 14.4 closure row + B.4-followup row for shape precedent) |
| **Script language** | Bash (POSIX-conformant where possible; `#!/usr/bin/env bash` shebang; uses `grep -E`, `awk`, `sort -u`, `comm`, standard POSIX text-processing primitives — no `jq`, no Python, no Node) | This story (B.5 architecture deferral closed Bash-side) |
| **Drift checks** | (a) `FR-P3-N` / `NFR-P3-N` references in `architecture.md` ↔ labels in `prd.md` (bidirectional set difference); (b) every `Story X.Y` citation in `architecture.md` resolves to a story header in `epics.md` OR `epics-phase1-epics-1-8.md` OR `epics-phase2-epics-9-13.5.md`; (c) every `§X.Y.Z` reference in `architecture.md`'s compliance-related sections has a matching row in `docs/ans-forth-core-compliance.md` (post-A.1 invariant — verdict criterion: clean before any tag close-out *after* Epic 15 / Story 15.1 closes A.1; pre-A.1 the check is **advisory** and surfaces the current §-rule coverage gap); (d) section-name parity check — both PRD and architecture share the agreed-on top-level (`^## `) sections | `architecture.md:276..280` (verbatim) + `epics.md:406` (verbatim) |
| **Output format (clean-pass)** | Single line `[ok] doc-sync: 0 drift` on stdout; exit 0 | `architecture.md:274` (verbatim) |
| **Output format (drift)** | One line per drift item on stderr, format `<check-id>: <description>` (e.g., `[fr-label] FR-P3-99 referenced in architecture.md:347 but not labelled in prd.md`); exit 1 | `architecture.md:274` ("exit 1 on drift; ... line-per-drift on failure") + `:667` ("line-per-drift on failure with exit 1") |
| **Makefile target shape** | `.PHONY: check-doc-sync` declaration extension at `:44`; new target body at end-of-file (or grouped near `firmware-repro` / `firmware-repro-test` at `:55..62`, the existing tools-invoking target precedent) invoking `bash tools/check-doc-sync/check-doc-sync.sh` | `architecture.md:604` + Makefile:55..62 (firmware-repro precedent) |
| **Failure mode (Makefile integration)** | Advisory-only on `make test-repl` (does not block test runs); expected clean before any tag-applicable close-out (S11 sibling) | `architecture.md:282` (verbatim) + `epics.md:408` (verbatim) |
| **B.8 test-numbering hygiene** | NOT in this story's scope despite being a Makefile-touching story. B.8 is a hitch-hiker per `docs/PHASE-3-CARRY-FORWARD.md:39` ("Cosmetic; renumber on next Makefile-touching story"). Architecture §"Decision Impact Analysis" line 316 names B.8 as `most likely B.5 or B.6`. **Disposition**: B.8 deferred to Story 15.4 (the renumber-and-tooling Makefile-sprint story per `epics.md` Epic 15 — Story 15.4 title is "Makefile tooling sprint: make-check-tools, test-numbering hygiene (B.6, B.8)"). Reasoning: bundling cosmetic renumber with B.5's drift-tooling addition would couple two unrelated Makefile diffs; Epic 15 already groups B.6 + B.8 as a single Makefile-sprint story; doing B.8 here would split the renumber across two PRs unnecessarily. Decision recorded in Dev Notes §"B.8 deferral note" (per S8 honest-disposition pattern). | This story (B.5/B.8 split rationale) |
| **Cited motivating PD** | PD-3 (Epic 13 retro #2): "PRD-vs-architecture transcription drift" | `docs/PHASE-3-CARRY-FORWARD.md:36` |
| **Binary delta** | 0 bytes (Makefile + new shell script + new README — no `src/*.asm` touched) | `architecture.md:347` ("B.5 \| 0 (Makefile + script only)") |
| **Test count delta** | 0 (no new REPL probes; the drift-checker is a host-side tool) | This story (test boundary) |
| **S9 disposition** | Exempt + documented in verdict table | NFR-P3-7 / `architecture.md:456` |
| **S11 disposition** | Not tag-applicable; banner-bump optional per Ant's call | `epics.md` Epic 14 §"Shape" |
| **Verdict criterion (self-test)** | (a) `make check-doc-sync` runs to completion (no shell errors, no `set -e` HALT); (b) clean-pass output `[ok] doc-sync: 0 drift` on stdout matches the architecture-pinned literal verbatim, OR (b') drift output is one line per item on stderr with the architecture-pinned shape; (c) exit code is 0 (clean) or 1 (drift) — never any other code; (d) running the target produces a known-state verdict against the current PRD + architecture pair (commit `7172754`) — clean OR small enumerable drift list, documented in Dev Notes; (e) `make test-repl` 973 PASS / 0 FAIL unchanged; (f) `wc -c build/antforth.com` Δ = 0; (g) `tools/check-doc-sync/check-doc-sync.sh` is executable (`chmod +x` permission set / committed); (h) `tools/check-doc-sync/README.md` enumerates the four drift checks (AC3), exit codes (AC4), and intended cadence (AC7); (i) `make check-doc-sync` does NOT block `make test-repl` (advisory-only Makefile integration per architecture `:282`). | FR-P3-15 / AC4 / AC5 / AC6 / AC7 / AC8 / AC9 |

**The story is pre-decided in shape.** No fix-shape pick (A.1-D3 / A.3 / B.7 dispositions); no kernel surgery; no register-convention audit; no caught-form THROW migration; no new EQU constants. The dev-pass writes the new script and README per the architecture-pinned format, adds the `.PHONY:` extension and target body to the Makefile, runs `make check-doc-sync` for the FR-P3-15 verdict-criterion first-run record, reconciles any drift items in-pass (or files them forward per honest-disposition pattern), updates `docs/PHASE-3-CARRY-FORWARD.md`'s B.5 Status row to `✅ Done` plus appends the closure-tracking row, runs `make test-repl` for the regression gate, runs `wc -c build/antforth.com` for the binary-delta gate, and closes.

If the dev-pass surfaces *additional* drift-check categories worth implementing beyond the architecture's four (e.g., commit-hash references in PRD/architecture that drift from `git log`, line-numbered file:line citations whose targets shifted, NFR-numbering parity beyond `NFR-P3-N`), those land in the new script in-pass per AC #11-style in-pass-fix discipline (mirror Story 14.1 Task 4.6 / Story 14.2 Task 2.5 / Story 14.3 Task 2.4 / Story 14.4 Task 2.7 review-fix-pass shape) — but they do NOT trigger a sibling-story spawn. Per S5, no PARTIAL ship.

**Per-component byte-budget itemisation (B.2 lint compliance — Story 14.2 closed 2026-05-08):**

| Component | Byte cost | Notes |
|---|---|---|
| `tools/check-doc-sync/check-doc-sync.sh` (Bash script body, ~150..300 lines depending on AC3 implementation density) | 0 kernel bytes | Tool script lives outside the kernel build path; consumed by build host's bash interpreter, not by antforth runtime |
| `tools/check-doc-sync/README.md` (drift-check rules + exit codes + cadence, ~50..100 lines) | 0 kernel bytes | Documentation file; not in kernel build path |
| `Makefile` `.PHONY:` extension (`check-doc-sync` token added to line `:44`) | 0 kernel bytes | Makefile metadata change; sjasmplus build invocation unchanged |
| `Makefile` `check-doc-sync:` target body (~3..5 lines: dependency-free PHONY target invoking `bash tools/check-doc-sync/check-doc-sync.sh`) | 0 kernel bytes | New PHONY target; not invoked by `make all` / `make asm` / `make test-repl` (advisory-only per architecture `:282`) |
| `docs/PHASE-3-CARRY-FORWARD.md` Status updates (B.5 row + new closure row) | 0 kernel bytes | Doc file, not in kernel build path |
| `src/*.asm` modifications | 0 bytes | None — no kernel surgery in scope |
| `build/antforth.com` Δ | 0 bytes | No `src/*.asm` touched |
| `build/antforth_filesanity.com` Δ | 0 bytes | No `src/*.asm` touched |
| **Per-arm total** | **0 bytes** | Tool-addition story (no kernel touch) |

Per-component itemisation independent of prior stories: the figure is reached by enumerating each new and modified component individually with its own byte-cost contribution, not by asserting "same shape as Stories 14.1/14.2/14.3/14.4" (which would trigger the B.2 lint that Story 14.2 itself codified). Stories 14.1..14.4 closed at zero kernel-byte delta on independent component-by-component bases at their own dev-pass closes; their precedent is a **sanity-check anchor** for "Epic-14 lead-in stories carry zero binary delta" only — not the source of Story 14.5's estimate. Note that Story 14.5's byte-cost surface differs from 14.1..14.4 (it adds a new tool subtree + Makefile target rather than a workflow-tree edit + carry-forward update) — the components above reflect *this story's* surface, itemised, not 14.1..14.4's.

---

## Acceptance Criteria

1. **Given** the v2.0.0+post-14.4 baseline (commit `7172754`) **lacks** a `tools/check-doc-sync/` directory and a `check-doc-sync` PHONY target in `Makefile` (verified pre-edit by Pre-edit Tasks 1.4 and 1.5 — `ls tools/check-doc-sync/` returns "No such file or directory"; `grep -nE '^check-doc-sync:' Makefile` returns the empty set; `grep -nE 'check-doc-sync' Makefile :44` returns the empty set),
   **when** Story 14.5 is dev-passed,
   **then** a new self-contained tool subdirectory exists at `tools/check-doc-sync/` (per the `tools/bdos_probe/` precedent at `tools/bdos_probe/bdos_probe.asm`) containing:
   - `tools/check-doc-sync/check-doc-sync.sh` — Bash script (executable bit set), implementing the four drift checks specified in AC3.
   - `tools/check-doc-sync/README.md` — Tool documentation (drift-check rules per AC3, exit codes per AC4, intended cadence per AC7).

   The script's first line is `#!/usr/bin/env bash`; the script is invocable as `bash tools/check-doc-sync/check-doc-sync.sh` from the project root. The script runs the four drift checks against the current `_bmad-output/planning-artifacts/prd.md`, `_bmad-output/planning-artifacts/architecture.md`, `_bmad-output/planning-artifacts/epics.md` (+ predecessor `epics-phase1-epics-1-8.md` / `epics-phase2-epics-9-13.5.md`), and `docs/ans-forth-core-compliance.md`.

2. **Given** AC1's deliverables landed,
   **when** the script is invoked from the project root,
   **then** the script reads each input file at most once per invocation (no per-check reload), exits cleanly on missing input files (with a clear stderr advisory naming the missing file and exit 1), and emits all output via `printf` / `echo` (no leakage of intermediate `awk` / `grep` / `sed` output to stdout or stderr unless it IS the drift-item line).

3. **Given** the architecture-pinned drift-check enumeration (`architecture.md:276..280` + `epics.md:406`),
   **when** the script runs,
   **then** the script implements **all four** drift checks as separate logically-named functions / blocks:
   - **(a) FR/NFR label parity:** every `FR-P3-N` and `NFR-P3-N` token referenced in `architecture.md` exists as a labelled definition in `prd.md` (i.e., `prd.md` carries `**FR-P3-N:**` or `**NFR-P3-N:**` anchored at line-start), AND every `FR-P3-N` and `NFR-P3-N` defined in `prd.md` is referenced at least once in `architecture.md`. Bidirectional set difference — orphan in either direction is a drift item. Implementation detail: `grep -oE 'FR-P3-[0-9]+|NFR-P3-[0-9]+' architecture.md | sort -u` gives the architecture-side set; `grep -oE '\*\*(FR|NFR)-P3-[0-9]+\*\*' prd.md | tr -d '*' | sort -u` gives the PRD-side definition set. Both directions emit drift items.
   - **(b) Story X.Y citation resolution:** every `Story X.Y` (or `Story X.Y.Z`) citation in `architecture.md` resolves to a story header in one of: `_bmad-output/planning-artifacts/epics.md`, `_bmad-output/planning-artifacts/epics-phase1-epics-1-8.md`, `_bmad-output/planning-artifacts/epics-phase2-epics-9-13.5.md`. Resolution: a header line matching `^### Story X.Y:` (or `^### Story X.Y.Z:`) in any of the three files. Unresolved citations emit drift items naming the file:line of the citation.
   - **(c) §X.Y.Z reference parity (post-A.1 invariant — pre-A.1 advisory):** every `§X.Y.Z` (or `§X.Y`, e.g., `§3.1.4.1`, `§6.2.0670`, `§3.4.1.3`) reference in `architecture.md`'s compliance-related sections (the regions that cross-reference DPANS94/Forth-2014 §-numbers) has a matching row in `docs/ans-forth-core-compliance.md`. **Until A.1 closes (Story 15.1), this check runs in advisory mode** — the script prints the count of architecture §-references AND the count of compliance-doc rows, and exits 0 *for this check* if architecture's §-references are a subset of compliance-doc rows; otherwise emits drift items naming each unmatched §. Post-A.1 (after Story 15.1 closes), this check switches to strict mode (any unmatched § is a drift item that fails the run). Mode switch is gated by a script-internal flag commented for the future drafter to flip; current default is advisory.
   - **(d) Top-level section-name parity:** the set of `^## ` (Markdown level-2) headers in `prd.md` ∩ `^## ` headers in `architecture.md` is examined for the agreed-on intersection (the sections both docs are expected to share — Executive Summary, Project Classification or Project Context Analysis, etc.); the script reports any section whose name diverges across the two docs (e.g., PRD has `## Functional Requirements`, architecture should have `## Implementation Patterns & Consistency Rules` covering FR-implementation patterns — these are **expected to differ** because the docs serve different roles, so this check is by-policy **advisory**: it surfaces the section list of both docs and flags only **renamings of historically-shared sections** detected by an internal name-pair allowlist commented in the script). Initial allowlist: empty (all section-name divergences advisory in the first run); the dev-pass populates the allowlist with the section pairs verified to be the agreed-on shared-section names from `prd.md:52..600` and `architecture.md:36..919` direct read.

   The four checks run independently; AC4's exit-code aggregation across the four is "exit 1 if any strict-mode check produces a drift item; exit 0 if all strict-mode checks are clean". Advisory-mode checks (currently 3(c) and 3(d)) emit advisory-prefixed lines (`[advisory-§]` / `[advisory-§-section]`) but do not contribute to exit code.

4. **Given** the architecture-pinned exit-code contract (`architecture.md:274` — *"exit 1 on drift; exit 0 on clean-pass with one-line `[ok] doc-sync: 0 drift`"*; `:667` — *"`[ok] doc-sync: 0 drift` on clean, line-per-drift on failure with exit 1"*),
   **when** the script runs,
   **then**:
   - **(a)** Clean-pass produces the exact single line `[ok] doc-sync: 0 drift` on stdout (verbatim, no trailing whitespace, no leading prefix) and exits 0.
   - **(b)** Drift produces one line per drift item on stderr, with the format `<check-id>: <description>` where `<check-id>` is one of `[fr-label]` / `[nfr-label]` / `[story-cite]` / `[section-name]` / `[advisory-§]` / `[advisory-§-section]` / `[advisory-section]`, and `<description>` includes the offending token + the file:line where it appears. The script exits 1 if any non-advisory drift item is emitted; exits 0 if only advisory items are emitted (the clean-pass message is suppressed when advisory items exist — advisory ≠ clean — instead the script prints `[advisory] doc-sync: <N> advisory item(s); 0 drift` on stdout and exits 0).
   - **(c)** No other exit codes are produced. Specifically: the script does NOT exit 2 / 3 / 127 / 130 under normal operation; if the script detects a fatal precondition failure (missing input file, unreadable file), it emits a clear `[fatal] <description>` line on stderr and exits 1 (treated as drift for Makefile purposes — a project that can't read its own docs IS in drift).
   - **(d)** The script does NOT use `set -e` globally — instead, the script handles errors per-check and accumulates drift items, so a single check's failure to grep does not abort the whole run. (Rationale: the goal is a *complete* drift report per run, not a fail-fast.)

5. **Given** the architecture-pinned Makefile integration (`architecture.md:604` — *"Add `check-doc-sync` PHONY target (B.5)"* — and `:282` — *"advisory-only on `make test-repl` (does not block); expected clean before any tag-applicable close-out (S11 sibling)"*),
   **when** the dev-pass edits the `Makefile`,
   **then**:
   - **(a)** The `.PHONY:` declaration at `Makefile:44` is extended to include `check-doc-sync` (preserving the existing tokens; insertion order preserved alphabetically OR appended at end — drafter's pick, documented in Completion Notes).
   - **(b)** A new target body lands in the Makefile (insertion site: end-of-file OR grouped near the `firmware-repro` / `firmware-repro-test` targets at `:55..62` — drafter's pick, with rationale in Completion Notes; the firmware-repro grouping is the precedent for "tool-invoking target body" placement). The body is dependency-free (`check-doc-sync:` with no prerequisites — the script reads markdown files, not build artefacts), and consists of a single Bash invocation: `bash tools/check-doc-sync/check-doc-sync.sh`.
   - **(c)** The new target is **not** added as a dependency of `make test-repl` (line `:103`), `make test` (line `:81`), `make all` (line `:46`), or `make asm` (line `:48`). Verified post-edit by `grep -nE 'check-doc-sync' Makefile` returning ≤ 3 matches: one at the `.PHONY:` declaration, one at the target rule, and at most one in a comment line (the per-AC5(c) advisory-only note).
   - **(d)** Running `make test-repl` post-edit produces the same 973 PASS / 0 FAIL output it produced pre-edit; `make check-doc-sync` is invokable independently and produces the AC4 output shape.

6. **Given** the FR-P3-15 verdict-criterion meta-pattern — each B.x lead-in story tests that the new artefact would have caught the prior-incident pattern that motivated it (`epics.md:386`, `:387`, `:409` for B.5) and produces a known-state verdict against the current PRD+architecture pair,
   **when** Story 14.5 is dev-passed,
   **then** running `make check-doc-sync` against the current Phase-3 PRD + architecture pair (commit `7172754`, the Story-14.4 close commit) produces a known-state verdict, and the verdict is documented verbatim in this story's Dev Notes §"AC6 first-run verdict log":
   - **(a)** Either: clean-pass (`[ok] doc-sync: 0 drift` stdout, exit 0) — documented as such, with the test-runner output captured.
   - **(b)** Or: a small enumerable drift list (one line per drift item on stderr, exit 1) — documented as such, with each drift item enumerated and dispositioned: either reconciled in-pass with a one-line PRD or architecture edit (B.3-followup / B.4-followup precedent — small typo-class drift), or filed forward as a B.5-followup row in `docs/PHASE-3-CARRY-FORWARD.md`'s §"Status Tracking" (per Story 14.3 / 14.4 honest-disposition pattern).
   - **(c)** Or: a known-state advisory disposition (`[advisory] doc-sync: <N> advisory item(s); 0 drift` stdout, exit 0) — documented as such, with each advisory item enumerated and the reasoning for keeping it advisory (e.g., the §X.Y.Z check's pre-A.1 advisory mode per AC3(c); the section-name parity check's empty-allowlist advisory mode per AC3(d)).
   - **(d)** **HALT condition:** if the script crashes (non-zero exit code other than 1; segfault; bash syntax error; missing-dependency error like `awk: command not found`), or hangs (does not terminate within 30 seconds — the dev-pass harness adds a `timeout 30 bash ...` wrapper if hang is suspected), or produces non-deterministic output across two consecutive runs (run twice, `diff` the outputs — deterministic if `diff` is empty), the verdict-criterion FAILS and the story HALTs per S5. The HALT evidence is the script output + the diff/exit-code transcript.

7. **Given** AC1's `tools/check-doc-sync/README.md`,
   **when** the README is authored,
   **then** the README enumerates:
   - **(a)** The four drift checks per AC3, named (a)..(d), with one short paragraph each describing the check's domain and resolution shape.
   - **(b)** The exit-code contract per AC4, naming exit 0 / exit 1 / advisory-mode disposition explicitly.
   - **(c)** The intended cadence: *"run `make check-doc-sync` before any antforth 2.x tag close-out (S11 sibling — version-surface audit reads cleanly only when doc-sync also reads cleanly); advisory at any other time."* (verbatim quoted from `epics.md:410`'s AC7 phrasing).
   - **(d)** A short pointer to PD-3 / Epic 13 retro #2 as the motivating carry-forward item, and a pointer to `docs/PHASE-3-CARRY-FORWARD.md` for closure-tracking shape.
   - **(e)** A short pointer to the architecture-pinned spec (`_bmad-output/planning-artifacts/architecture.md:272..282`, §"B.5-D1: PRD-vs-architecture transcription-drift sync") for any drafter wanting to extend the drift-check surface.
   - **(f)** A line documenting the script-internal advisory-mode flag that gates AC3(c) §X.Y.Z strict mode — naming the variable name and the closure condition (Story 15.1 closes A.1, flipping the flag).

   README is well-formed Markdown; renders cleanly in the GitHub web UI (no broken inline code, no malformed bullet structure).

8. **Given** the post-Story-14.4 baseline binary at `build/antforth.com` (current `wc -c` measured directly at story-drafting time on commit `7172754` — Story-14.4 was zero binary delta per its AC #8 verdict; per the B.3 discipline this story's dev-pass *also* enforces, the figures MUST be re-measured at Pre-edit Task 1 not transcribed from Story 14.4),
   **when** the dev-pass measures `wc -c build/antforth.com` and `wc -c build/antforth_filesanity.com` at story-drafting time AND at story-close,
   **then** the post-edit binary sizes are **unchanged from the pre-edit measurement**: production binary (Δ = 0); filesanity binary (Δ = 0). The story is **tooling addition + Makefile target + carry-forward Status update only**; any non-zero binary delta on this story HALTs per S5 — there is no `src/*.asm` instruction change in scope. Per NFR-P3-2 (cumulative Phase-3 ROM cap +200 bytes / 24,996 → ≤ 25,200), Story 14.5's per-story envelope is `0 bytes` (architecture §"Per-story binary delta envelopes" line 347 / `epics.md:411`). The S9 hardware-smoke task is **documented exempt** per NFR-P3-7 / architecture §"Hardware-smoke cadence" — same exemption shape as Stories 14.1 / 14.2 / 14.3 / 14.4. The exemption note lands in Completion Notes: *"S9 exempt — zero binary delta (tooling addition + Makefile target + carry-forward Status update only); per architecture §'Hardware-smoke cadence' ('Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly')."*

9. **Given** the post-Story-14.4 `make test-repl` baseline of 973 PASS / 0 FAIL (per Story 14.4 AC #9 verdict, unchanged from the post-Story-14.3 / post-Story-14.2 / post-Story-14.1 / post-Epic-13.5 / post-v2.0.0 baseline),
   **when** `make test-repl` is run pre-edit AND post-edit,
   **then** the result is **973 PASS / 0 FAIL — zero regressions, zero test-count movement**. Pre-edit verification: `grep -c '^PASS:' <(make test-repl 2>&1)` returns 973; pre-edit FAIL count = 0. Post-edit (story-close): same numbers — Story 14.5 adds a new tool + Makefile PHONY target, which the `test-repl` recipe does not invoke (verified by AC5(c)). Editing the Makefile cannot affect `make test-repl` pass/fail counts unless the edit accidentally damages the Makefile syntax (broken target body, malformed `.PHONY:` declaration); any such damage produces an immediate `make` parse error and HALTs per S5. Any `make test-repl` movement HALTs per S5. Recorded in Completion Notes alongside `make test` (assembly thread) clean check (informational; not a PARTIAL gate) and `make test-file-sanity` PASS (informational).

---

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift)
- [x] Capture current `make test-repl` baseline pass count

### Story tasks

- [x] **Task 1 — Pre-edit baseline** (AC #6(d), #8, #9; per architecture §"Re-`wc -c` at the start of every dev-pass" / Lesson 13.5-F + the B.3 / B.4 disciplines this story's drafter is governed by — Story 14.5's dev-pass MUST practice all of B.2 + B.3 + B.4 disciplines forward, since all three have already landed)
  - [x] 1.1 — `wc -c build/antforth.com` direct measurement → record value. **Do not inherit Story 14.4's reported figures (24,995)** — re-measure directly per B.3 discipline.
  - [x] 1.2 — `wc -c build/antforth_filesanity.com` direct measurement → record value. **Do not inherit Story 14.4's reported figures (26,460)** — re-measure directly per B.3 discipline.
  - [x] 1.3 — `make test-repl 2>&1 | tee /tmp/14-5-pre-edit.out` → `grep -c '^PASS:' /tmp/14-5-pre-edit.out` should equal **973**; `grep -c '^FAIL:' /tmp/14-5-pre-edit.out` should equal **0**. Record both counts.
  - [x] 1.4 — `ls tools/check-doc-sync/ 2>&1` → record output (expected: `ls: cannot access ... No such file or directory`). This establishes AC1 baseline.
  - [x] 1.5 — `grep -nE 'check-doc-sync' Makefile` → record matches (expected: empty). This establishes AC5(a) and AC5(b) baseline.
  - [x] 1.6 — `git log --oneline -1` → record current HEAD (expected: `7172754 story 14.4: ...`).
  - [x] 1.7 — **B.4 recursive-self-validation pre-flight** (per B.4 discipline at instructions.xml:62..86): cross-reference every figure / file:line / line-count this story quotes against its source-of-truth at drafting time, before any source edits:
    - [x] (i) `_bmad-output/planning-artifacts/epics.md:394..414` — re-read Story 14.5 ACs; verify the verbatim transcription matches.
    - [x] (ii) `_bmad-output/planning-artifacts/architecture.md:272..282` — re-read B.5-D1 + drift-check enumeration; verify AC3 here matches.
    - [x] (iii) `_bmad-output/planning-artifacts/architecture.md:592..593` — re-read new files row.
    - [x] (iv) `_bmad-output/planning-artifacts/architecture.md:604` — re-read Makefile-modified row.
    - [x] (v) `_bmad-output/planning-artifacts/prd.md:530` — re-read FR-P3-16.
    - [x] (vi) `docs/PHASE-3-CARRY-FORWARD.md:36` (B.5 row), `:106` (Story 14.4 closure row precedent), `:107` (B.4-followup row precedent) — re-read for shape.
    - [x] (vii) `Makefile:44` (`.PHONY:` line) and `:55..62` (`firmware-repro` precedent) — re-read for insertion-site decision.
    - [x] (viii) `tools/bdos_probe/bdos_probe.asm:1..15` — re-read for header-shape precedent.
    - [x] (ix) `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:62..86` (B.4 block) — re-read; the figure-drift discipline is what this story's pre-flight implements.
    - For any divergence: investigate and reconcile per Lesson 13.5-F + PD-2 before any subsequent task. Record verifications in Dev Notes §"Recursive self-validation log".

- [x] **Task 2 — Author the drift-checker script** (AC #1, #2, #3, #4)
  - [x] 2.1 — Create directory `tools/check-doc-sync/` (parent `tools/` already exists, contains `bdos_probe/` precedent).
  - [x] 2.2 — Author `tools/check-doc-sync/check-doc-sync.sh` per AC1, AC2, AC3, AC4:
    - [x] 2.2.1 — Header block (Bash shebang + tool description + Story 14.5 reference + license/CC line if applicable, mirroring the `tools/bdos_probe/bdos_probe.asm:1..30` header style).
    - [x] 2.2.2 — Pre-flight: locate project root via `cd "$(dirname "$0")/../.."` or `git rev-parse --show-toplevel`; verify the four canonical input files exist (`_bmad-output/planning-artifacts/{prd,architecture,epics}.md`, `docs/ans-forth-core-compliance.md`); emit `[fatal]` line + exit 1 on any missing file.
    - [x] 2.2.3 — Implement check (a) FR/NFR label parity per AC3(a). Use `grep -oE 'FR-P3-[0-9]+|NFR-P3-[0-9]+'` for token extraction; `comm -23` (or `diff` + filter) for set difference in both directions; emit one `[fr-label]` or `[nfr-label]` drift item per orphan with file:line context (use `grep -nE`).
    - [x] 2.2.4 — Implement check (b) Story X.Y citation resolution per AC3(b). Use `grep -oE 'Story [0-9]+\.[0-9]+(\.[0-9]+)?'` for citation extraction from architecture.md; for each, search for `^### Story X.Y(.Z)?:` in the three epics files; emit `[story-cite]` drift items with file:line of unresolved citations.
    - [x] 2.2.5 — Implement check (c) §X.Y.Z reference parity per AC3(c) advisory mode. Use `grep -oE '§[0-9]+\.[0-9]+(\.[0-9]+)?'` for §-extraction from architecture.md compliance-related sections; cross-reference against `docs/ans-forth-core-compliance.md` rows; emit `[advisory-§]` items in advisory mode (the default until A.1 closes). Add a clearly-named script-local flag (e.g., `STRICT_SECTIONS=0`) with a comment naming Story 15.1 / A.1 closure as the flip condition (AC7(f)).
    - [x] 2.2.6 — Implement check (d) section-name parity per AC3(d). Use `grep -nE '^## ' prd.md` and `grep -nE '^## ' architecture.md` to extract level-2 headers; compute the agreed-on shared-section pair allowlist (initially empty per AC3(d)); emit `[advisory-section]` for any divergence not in the allowlist (advisory-mode default).
    - [x] 2.2.7 — Aggregate exit code per AC4: exit 1 if any non-advisory drift item is emitted; exit 0 otherwise. Print clean-pass message `[ok] doc-sync: 0 drift` on stdout if no items at all; print advisory message `[advisory] doc-sync: <N> advisory item(s); 0 drift` on stdout if only advisory items.
    - [x] 2.2.8 — `chmod +x tools/check-doc-sync/check-doc-sync.sh` to set the executable bit (committed to git per AC1).
  - [x] 2.3 — Verify `bash -n tools/check-doc-sync/check-doc-sync.sh` returns 0 (script is syntactically valid Bash) before any test invocation.
  - [x] 2.4 — First test invocation: `bash tools/check-doc-sync/check-doc-sync.sh`; capture stdout + stderr + exit code. Run twice in succession; `diff` the two runs' combined output to verify determinism per AC6(d). Record both runs' output and the diff result in Dev Notes §"AC6 first-run verdict log".

- [x] **Task 3 — Author the README** (AC #1, #7)
  - [x] 3.1 — Author `tools/check-doc-sync/README.md` per AC7(a)..(f).
  - [x] 3.2 — Verify the README renders cleanly as Markdown (no malformed bullets / inline code / link syntax). Verification: visual inspection plus `grep -E '^#+' README.md` to confirm header hierarchy is well-formed.

- [x] **Task 4 — Add `check-doc-sync` PHONY target to Makefile** (AC #1, #5)
  - [x] 4.1 — Insertion-site decisions: (a) `.PHONY:` line — extend `Makefile:44` to add `check-doc-sync` token (alphabetic insertion point OR end-of-line append; drafter picks, documented in Completion Notes); (b) target body — placement near `firmware-repro` / `firmware-repro-test` at `:55..62` (precedent for tool-invoking targets) OR end-of-file. Drafter picks, documented in Completion Notes.
  - [x] 4.2 — Edit `Makefile:44` per Task 4.1(a). Verify the diff is one-line (token added, all other tokens preserved, no whitespace damage).
  - [x] 4.3 — Add the new target body per Task 4.1(b): three lines minimum — `# advisory-only sync target (B.5 / Story 14.5)` comment; `check-doc-sync:` rule line (no prerequisites); `\tbash tools/check-doc-sync/check-doc-sync.sh` recipe line (tab-indented per Makefile syntax). The advisory comment is required so a future contributor doesn't add `check-doc-sync` as a `make test-repl` prerequisite (architecture §"Failure mode" `:282`).
  - [x] 4.4 — Run `make -n check-doc-sync` (dry-run) to verify the target parses and the recipe is what AC5(b) specifies.
  - [x] 4.5 — Run `make check-doc-sync` (real invocation); verify output matches Task 2.4's first-run output (deterministic across direct-bash invocation and Makefile invocation).

- [x] **Task 5 — AC6 first-run verdict reconciliation** (AC #6)
  - [x] 5.1 — Inspect the Task 2.4 / 4.5 output. Determine which AC6 disposition applies: (a) clean, (b) drift, (c) advisory-only, or (d) HALT condition.
  - [x] 5.2 — If AC6(a) clean — proceed to Task 6.
  - [x] 5.3 — If AC6(b) drift — for each drift item: (i) classify as typo-class trivially-fixable (e.g., orphan `Story X.Y` that should be `Story X.Z`) → reconcile in-pass with a one-line edit to the offending PRD/architecture/epics file; OR (ii) classify as larger-scope (would require a PRD or architecture rewrite) → file forward as a B.5-followup row in `docs/PHASE-3-CARRY-FORWARD.md`'s §"Status Tracking" (per B.3-followup at `:105` and B.4-followup at `:107` shape). After in-pass reconciliations, re-run `make check-doc-sync` to confirm the residual disposition is either AC6(a) clean or AC6(c) advisory-only-with-followups.
  - [x] 5.4 — If AC6(c) advisory-only (no strict-mode drift; only `[advisory-§]` and/or `[advisory-section]` items) — document each advisory item with the reasoning for keeping it advisory; proceed to Task 6 (this is an AC-acceptable disposition per AC6(c)).
  - [x] 5.5 — If AC6(d) HALT condition — investigate root cause (script bug, missing input, non-determinism); fix the script per Task 2.2; re-run from Task 2.4. Do not proceed to Task 6 until the HALT is resolved.

- [x] **Task 6 — Update `docs/PHASE-3-CARRY-FORWARD.md` Status** (per Story 14.1 / 14.2 / 14.3 / 14.4 precedent Tasks 7.1 / 3.1 / 3.1 / 3.2)
  - [x] 6.1 — Confirm the existing B.5 row at `docs/PHASE-3-CARRY-FORWARD.md:36` Status column is unchanged in this task per Task 3.3 precedent across Stories 14.1..14.4 (the catalogue's main table at `:30..40` records the original carry-forward classification; only the §"Status Tracking" closure-tracking table at `:100+` gets the new row).
  - [x] 6.2 — Append a new row to §"Status Tracking" at `:108` (immediately after the B.4-followup row at `:107`) per the Story 14.4 row at `:106` shape. Content: `| B.5 | ✅ Done | Story 14.5 / 2026-05-08 — new tool subtree at \`tools/check-doc-sync/\` (`check-doc-sync.sh` Bash drift-checker + `README.md` documentation); new `check-doc-sync` PHONY target in `Makefile`; four drift checks per architecture §"B.5-D1" — (a) FR/NFR label parity, (b) Story X.Y citation resolution, (c) §X.Y.Z reference parity (advisory until A.1 / Story 15.1), (d) section-name parity (advisory). AC6 first-run verdict: <first-run disposition>. Verdict criteria 9/9 PASS. Zero binary delta. |` — fill `<first-run disposition>` based on Task 5's reconciled outcome.
  - [x] 6.3 — If Task 5.3 spawned a B.5-followup row, append it immediately after the B.5 closure row per the B.3-followup / B.4-followup shape.

- [x] **Task 7 — Verdict-criterion meta-pattern self-test** (AC #6; FR-P3-15)
  - [x] 7.1 — Final `make check-doc-sync` invocation (post-Task-6 reconciliations); capture the verdict.
  - [x] 7.2 — Two-run determinism check: run twice; `diff` the outputs; verify identical.
  - [x] 7.3 — Bash syntactic check: `bash -n tools/check-doc-sync/check-doc-sync.sh` returns 0.
  - [x] 7.4 — Makefile syntactic check: `make -n check-doc-sync` parses cleanly.
  - [x] 7.5 — All evidence recorded in Dev Notes §"AC6 first-run verdict log" + Completion Notes.

- [x] **Task 8 — Post-edit binary + test regression check** (AC #8, #9)
  - [x] 8.1 — `make` check (kernel build path untouched by tooling addition; expect `Nothing to be done for 'all'` or equivalent). `wc -c build/antforth.com` post-edit. Δ = 0 vs. Task 1.1.
  - [x] 8.2 — `wc -c build/antforth_filesanity.com` post-edit. Δ = 0 vs. Task 1.2.
  - [x] 8.3 — `make test-repl 2>&1 | tee /tmp/14-5-post-edit.out` → expect 973 PASS / 0 FAIL. Zero movement from pre-edit baseline (Task 1.3).
  - [x] 8.4 — `make test` (assembly thread) → expect zero errors / warnings (informational; not a PARTIAL gate).
  - [x] 8.5 — `make test-file-sanity` → expect PASS (informational).

- [x] **Task 9 — S9 hardware-smoke disposition** (AC #8 / NFR-P3-7)
  - [x] 9.1 — **S9 exempt** — zero binary delta (tooling addition + Makefile PHONY target + carry-forward Status update only); per architecture §"Hardware-smoke cadence" — *"Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped."* Same exemption shape as Stories 14.1 / 14.2 / 14.3 / 14.4. Exemption recorded in Completion Notes; binary delta verified zero in Tasks 8.1 / 8.2.

- [x] **Task 10 — Carry-forward catalogue Status confirmation** (`docs/PHASE-3-CARRY-FORWARD.md` post-edit verification)
  - [x] 10.1 — § "Status Tracking" re-read; B.5 closure row correctly added at `:108` (or wherever Task 6.2 lands it) immediately after the B.4-followup row at `:107`; row content reproduced in Change Log below.

- [x] **Task 11 — Standing-commitment hold confirmation** (NFR-P3-22..33 subset relevant to 14.5)
  - [x] 11.1 — S1..S12 walk: confirm all twelve hold (see Completion Notes §"Standing-commitment walk (S1..S12)"). Particular attention to S10 (workflow > memory > prompt — the drift-checker is a workflow-surface artefact; the alternative would be a `feedback_no_doc_drift.md` memory entry, which would be the architecture §"Bad — memory edit (anti-pattern)" violation).

- [x] **Task 12 — HALT-on-PARTIAL discipline check at story-close** (S5 / `feedback_no_preexisting_discharge.md`)
  - [x] 12.1 — AC #1..#9 walk in Completion Notes confirms no PARTIAL verdict; all nine ACs PASS (or the dev-pass HALTed earlier).
  - [x] 12.2 — `ls _bmad-output/implementation-artifacts/14-5-1*.md` → expect no match (no sibling-story spawn).

- [x] **Task 13 — Sprint-status update + Change Log + File List**
  - [x] 13.1 — `_bmad-output/implementation-artifacts/sprint-status.yaml` `14-5-prd-architecture-transcription-drift-sync-target-make-check-doc-sync` row: from `ready-for-dev` (post-create-story workflow, this story file's authoring) → `in-progress` (at dev-pass start, Task 1) → `review` (at dev-pass close, this commit). Honest disposition recorded if the canonical three-state sequence wasn't actually executed (e.g., `backlog → review` shortcut, per Story 14.3 / 14.4 AC10.1 / AC13.1 honest-disposition precedent).
  - [x] 13.2 — File List authored below.
  - [x] 13.3 — Change Log authored below.

---

## Dev Notes

### Why this story matters

PD-3 — "PRD-vs-architecture transcription drift (doc-build sync step)" — was identified in Epic 13's retrospective on 2026-05-05 (`epic-13-retro-2026-05-05.md`, PD-3 row in §"Documented Follow-Up Opportunities") as a Phase-3 carry-forward item. The retro classified it briefly without enumerating a worked incident; the carry-forward catalogue (`docs/PHASE-3-CARRY-FORWARD.md:36`) elevated it to a Medium-effort B.x item and slotted it as the close-out of the story-template-discipline cluster (B.1 + B.2 + B.3 + B.4 + B.5).

The pattern: a story drafter or PRD/architecture author makes an edit in one of the planning artefacts (`prd.md`, `architecture.md`, `epics.md`, `docs/ans-forth-core-compliance.md`) that breaks a cross-reference invariant the other artefacts rely on. Specifically:
1. **FR/NFR label drift** — architecture cites `FR-P3-99` but PRD never defines it (typo, copy-paste from a draft, label removed in a subsequent PRD revision without architecture follow-up). The architecture's claim of FR coverage becomes load-bearing-but-unverified.
2. **Story citation drift** — architecture cites `Story 13.5.7` but no such story exists in any epics file. Reader can't follow the cross-reference; the architecture's authority claim degrades.
3. **§X.Y.Z reference drift (post-A.1 invariant)** — architecture cites `§6.1.0093` but `docs/ans-forth-core-compliance.md` has no such row. After Story 15.1 (A.1) closes, the compliance doc IS the §-rule source-of-truth; mismatches indicate either a §-rule that the audit walk missed, or an architecture citation that needs correction.
4. **Section-name drift** — PRD restructures `## Functional Requirements` into `## Capability Contract` without architecture follow-up. Cross-references in architecture pointing to "PRD §Functional Requirements" rot.

These drifts are **silent**: a reader of the architecture document doesn't know the cross-reference is broken until they try to follow it. A reader of `make test-repl` output doesn't know the docs are inconsistent. The deferral-to-tag-close-out pattern (S11 sibling) is the correct disposition: the docs need to be aligned at *publication* moments (tags), not at every working-tree state.

The discipline targeted by Story 14.5 is the **doc-build-time mechanical check**: at any maintainer-invocation, the drift-checker walks the four canonical surfaces and produces a verdict. Tag-applicable close-outs (Phase-3 antforth 2.x point-releases) gain a new pre-condition: `make check-doc-sync` clean-pass per architecture §"Doc-sync (NEW, opt-in)" `:733`.

**The standing commitment exists in retro docs + carry-forward catalogue.** PD-3 lives in the *why* surface; the lesson from B.1..B.4 closure is that *why*-surface discipline doesn't fire structurally — the maintainer has to *remember* to invoke it (per `architecture.md:554..559`). **Story 14.5 lands the discipline at the enforcement surface** — the `make check-doc-sync` target fires automatically at maintainer invocation, alongside `make test-repl` and `make test-file-sanity` regression gates. The advisory-only Makefile integration per `architecture.md:282` means Story 14.5 doesn't make `make test-repl` slower or more brittle; it simply makes the drift-check *available* and pinned-to-the-architecture-spec.

**The cluster is now structurally complete.** B.1 (PAD canonical doc) + B.2 (mirrors-prior-arm HALT lint) + B.3 (re-`wc -c` discipline) + B.4 (figure-drift discipline) + B.5 (PRD-vs-architecture sync) together form the Phase-3 process foundation; every subsequent dev-pass (Epics 15+) inherits this cluster. After Story 14.5 closes, Epic 14 closes, and the only remaining Phase-3 work is the Standards Close-Out (Epic 15 — A.1 audit + A.2 + A.3 + B.6 + B.7 conditional + B.8 + B.9).

Sibling discipline note (the cluster): Story 14.2 (B.2) lands the structural enforcer for "mirrors prior arm" byte-budget shorthand at byte-budget-rationale review; Story 14.3 (B.3) lands the structural enforcer for "re-`wc -c` at dev-pass start" at Pre-edit baseline capture; Story 14.4 (B.4) lands the structural enforcer for "validate quoted figures against source-of-truth at draft time" at any figure-quoting moment; Story 14.5 (B.5 — this story) lands the structural enforcer for "PRD/architecture/epics/compliance-doc cross-reference parity" at maintainer-invoked doc-build time. All five are S10 / NFR-P3-31 enforcement-surface transitions; together they form the **Phase-3 process foundation cluster**.

### Recursive-self-validation note

Story 14.5 is the **first Epic-14 story to create a new external host-side tool that operates on the planning artefacts**. The four prior stories (14.1..14.4) edited workflow-tree files consumed by the BMAD runtime (instructions.xml / template.md) plus a tests/README.md doc — none of them shipped an executable artefact that runs against the project's own files. Per S5 and the B.4 figure-drift discipline (now codified at instructions.xml:62..86, which this story's drafter is governed by), every figure / file:line quoted in this story has been re-validated at draft time. The recursive-validation moments this story must navigate at Pre-edit Task 1.7:

- Task 1.7(i) — `epics.md:394..414` — Story 14.5 ACs #1..#9. Verbatim transcription expected to be drift-free, but the AC3 enumeration is the load-bearing source for the script's behaviour; any drift here would be an immediate AC1/AC3 verdict-criterion failure.
- Task 1.7(ii) — `architecture.md:272..282` — B.5-D1 + drift-check enumeration. The script's check (a)..(d) implementations directly trace from the architecture's enumeration; any drift between this story's AC3 phrasing and architecture's `:276..280` is a B.4 discipline failure.
- Task 1.7(iii)/(iv) — `architecture.md:592..593` (new files) and `:604` (Makefile-modified). File-touch surface verified against architecture's pinned table.
- Task 1.7(v) — `prd.md:530` (FR-P3-16). Verifies the PRD's authoritative description of the deliverable.
- Task 1.7(vi) — `docs/PHASE-3-CARRY-FORWARD.md:36` / `:106` / `:107`. Verifies carry-forward catalogue shape precedents.
- Task 1.7(vii) — `Makefile:44` (`.PHONY:` line) and `:55..62` (`firmware-repro` precedent). Verifies the Makefile insertion-site decisions in AC5 / Task 4.
- Task 1.7(viii) — `tools/bdos_probe/bdos_probe.asm:1..15`. Verifies the `tools/<name>/` self-contained-subtree precedent.
- Task 1.7(ix) — `instructions.xml:62..86`. Verifies the B.4 block boundaries (this story's drafting discipline source).

Stories 14.1 / 14.2 / 14.3 / 14.4 each surfaced one or more recursive-validation moments in-pass:
- Story 14.1 surfaced and reconciled the v2.0.0-banner-bump 1-byte drift (24,996 documented vs. 24,995 actual).
- Story 14.2 AC6(d) `<critical>`-count drift (mental-model 1/2 vs. actual 16/17).
- Story 14.3 AC5(b) regex-vs-markdown-bold drift (architecture's `**Do not**` vs. AC's regex).
- Story 14.4 AC5(e) `<critical>`-count drift (+1 expected vs. +2 actual) AND sprint-status pre-dev-pass-state drift (caught at /CR).

Story 14.5 should expect a similar moment — **most likely around the first run of `make check-doc-sync` itself** (AC6's first-run verdict), because the drift-checker IS the recursive-self-validation mechanism for the docs. If the first run produces drift items, those items are evidence of the very class B.5 codifies discipline against — the same shape Stories 14.2..14.4 surfaced with their respective in-pass amendments. The B.5 discipline is its own resolution mechanism (run the checker; reconcile or file forward).

### Expected first-run disposition

Per architecture's verdict-criterion meta-pattern (`epics.md:409`, "running `make check-doc-sync` against the current Phase-3 PRD + architecture pair (commit at story start) produces a known-state verdict (clean-pass or a small enumerable drift list)"), AC6 explicitly anticipates *both* dispositions as AC-acceptable. Realistic expectations for the first run against commit `7172754`:

- **Check (a) FR/NFR label parity** — most likely **clean** OR **near-clean with 0..3 items**. The PRD defines FR-P3-1..FR-P3-25 and NFR-P3-1..NFR-P3-33; the architecture references most of these at `:210..212` (epics summary) and throughout. Risk surfaces: any FR-P3-N referenced in architecture's body prose but not formally labelled in PRD (e.g., a typo `FR-P3-99` for `FR-P3-19`); or any FR-P3-N defined in PRD but never cited in architecture (orphan label — possible but unlikely in a freshly-drafted PRD).
- **Check (b) Story X.Y citation resolution** — most likely **clean** OR **near-clean with 0..3 items**. The architecture cites Stories 13.0 / 13.0.1 / 13.5 / 13.5.1..13.5.6 / 14.1..14.5 / 15.1..15.6 throughout; all should resolve in `epics.md`, `epics-phase2-epics-9-13.5.md`, or (for historical Phase-1 references) `epics-phase1-epics-1-8.md`. Risk surfaces: any "Story P3.A1.1" placeholder (architecture mentions this back-fill story shape at `:515..529`) — these are *placeholder names*, not actual story headers; the script must either treat `Story P3.A1.1` as a special-case allowlist OR the dev-pass identifies the placeholder pattern and the AC3(b) check excludes `Story P3.X.Y` patterns.
- **Check (c) §X.Y.Z reference parity** — **advisory mode** (pre-A.1) — likely emits dozens of `[advisory-§]` items naming §-numbers in architecture not yet rowed in `docs/ans-forth-core-compliance.md`. This IS the A.1 strategic-body surface; the advisory output is a *feature*, not a defect — it shows exactly the §-coverage gap A.1 will close. AC6(c) advisory disposition expected.
- **Check (d) section-name parity** — **advisory mode** (empty allowlist) — the empty initial allowlist means every section divergence emits an `[advisory-section]` item. This is by-design: the dev-pass populates the allowlist with verified-shared section-name pairs after the first run, then re-runs to confirm clean. Expected first-run advisory output count: 10..30 depending on how many sections each doc has. AC6(c) advisory disposition expected.

**Combined expected first-run verdict:** AC6(c) advisory-only — `[advisory] doc-sync: <N> advisory item(s); 0 drift` with N likely in 30..60 range; exit 0; clean from the strict-mode perspective. AC6(b) drift is possible but unlikely — if any `[fr-label]` / `[story-cite]` / `[section-name]` strict-mode items surface, they're reconciled in-pass (typo-class) or filed as B.5-followup rows.

### B.8 deferral note (S8 honest-disposition pattern)

Story 14.5 is a Makefile-touching story. B.8 (test-numbering hygiene — Makefile duplicate test numbers from Story 11.3) is catalogued as a hitch-hiker per `docs/PHASE-3-CARRY-FORWARD.md:39` ("Cosmetic; renumber on next Makefile-touching story") and architecture §"Decision Impact Analysis" line 316 names B.8 as `most likely B.5 or B.6`. The architecture's "most likely" phrasing is non-binding — it's a routing suggestion, not a coupling requirement.

**Disposition: B.8 deferred to Story 15.4** (Epic 15's Makefile tooling sprint, which already groups B.6 + B.8 as a single Makefile-sprint story per `epics.md` Epic 15 list). Reasoning, recorded explicitly per S8 honest-disposition pattern:

1. **Bundling cosmetic renumber with B.5's drift-tooling addition would couple two unrelated Makefile diffs.** B.5's diff is a `.PHONY:` extension + new target body (architecturally pinned shape). B.8's diff is mechanical renumbering of duplicate test IDs in the existing `test-repl` recipe (cosmetic). Mixing the two in a single PR makes the diff harder to review and harder to revert independently if a regression surfaces.
2. **Epic 15 already groups B.6 + B.8 as a single story** (Story 15.4 — "Makefile tooling sprint: make-check-tools, test-numbering hygiene (B.6, B.8)"). Doing B.8 in 14.5 would split the renumber across two PRs (the duplicates that 14.5 happens to encounter vs. the rest in 15.4) and would force 15.4 to inherit a partial-renumber state.
3. **B.5 is the *last* lead-in story; cleanly closing Epic 14 requires not absorbing scope from Epic 15.** Per S5 (PARTIAL → HALT), this story should ship its B.5 deliverables cleanly without scope drift.

This is a *named* deferral, not a silent omission. If a future contributor or CR reviewer asks "why didn't 14.5 also do B.8 since the architecture says it might?", the answer is in this Dev Notes section — not buried in conversational prompt history.

### Architecture context (Phase-3 architecture, 2026-05-08)

`_bmad-output/planning-artifacts/architecture.md` pins the following for Story 14.5 (each cited line:column re-verified at Task 1.7 per B.4 discipline):

- **§"B.5-D1: PRD-vs-architecture transcription-drift sync"** (line 272..282) — Edit lands as a `make check-doc-sync` target invoking a project-local script in `tools/check-doc-sync/`. Output format: `[ok] doc-sync: 0 drift` on stdout (clean), line-per-drift on stderr (drift); exit 0 / exit 1. Failure mode: advisory-only on `make test-repl`; expected clean before any tag-applicable close-out (S11 sibling).
- **§"Verdict-criterion meta-pattern (all four)"** (line 264..268) — B.5 is in fact 5th of 5 lead-in items; its verdict criterion lives in AC6 (FR-P3-15 surface) — the script runs and produces a known-state verdict.
- **§"Implications for B.x verdict criteria"** (line 217 / 270) — "If a lead-in fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration". Story 14.5 ACs #1, #2, #4, #5, #6, #8, #9 + Tasks 4, 5, 6, 7 enforce this structurally.
- **§"Per-story binary delta envelopes"** (line 343..347) — B.5 = 0 (Makefile + script only). Story 14.5 AC #8 enforces.
- **§"Hardware-smoke cadence (S9 / NFR-P3-7)"** (line 456) — "Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped". Story 14.5 AC #8 + Task 9.1 implement this.
- **§"New files created in Phase 3"** (line 587..596) — `tools/check-doc-sync/check-doc-sync.<sh|py>` + `tools/check-doc-sync/README.md`. Story 14.5 picks `.sh` per the architecture deferral at `:667` ("language choice (Bash, Python, etc.) deferred to B.5's story-author").
- **§"Existing files modified in Phase 3"** (line 604) — `Makefile | Add check-doc-sync PHONY target (B.5); add check-tools PHONY target (B.6); renumber duplicate test IDs in test-repl recipe (B.8); add pointer comment to tests/README.md from test section (B.1) | B.5, B.6, B.8, B.1`. Story 14.5 lands the B.5 portion only (B.6 + B.8 are Epic-15 hitch-hikers; B.1 was Story 14.1).
- **§"Tooling boundary"** (line 663..667) — Makefile is the build/test orchestrator; Phase-3 adds two PHONY targets (`check-doc-sync`, `check-tools`) and one renumber pass (B.8); default `make` behaviour unchanged. `tools/check-doc-sync/` is a self-contained drift-checker; output format pinned.
- **§"Doc-sync (NEW, opt-in)"** (line 733) — `make check-doc-sync` runs `tools/check-doc-sync/` script; clean-pass is `[ok] doc-sync: 0 drift`; expected before any tag-applicable close-out (S11 sibling).
- **§"Recommended sequencing within the lead-in"** (line 932..937; B.5 specifically at line 937) — B.5 is fourth of four (after B.1, B.2+B.4, B.3); Story 14.5 honours this position as the cluster close-out.
- **§"All Phase-3 dev-pass agents MUST"** items 3 + 9 (line 478, 484) — "Land workflow-file edits in their designated files (CCD-P3-2 mapping)" and "Re-`wc -c` at the start of every dev-pass". Story 14.5 honours both: deliverable lands in `Makefile` + `tools/check-doc-sync/` per CCD-P3-2; Pre-edit Task 1.1 re-`wc -c`s directly per B.3.
- **§"Pattern enforcement mechanisms"** (line 488..491) — "Sync targets in `Makefile` (`check-doc-sync`, `check-tools`) catch PRD-vs-architecture transcription drift at maintainer-invocation time". Story 14.5 IS the surface for B.5 in this enumeration.

### PRD Phase-3 context (2026-05-08)

`_bmad-output/planning-artifacts/prd.md` for Story 14.5's binding requirements:

- **FR-P3-16 (B.5)** at `prd.md:530` — "A maintainer running the project's build can invoke a sync target (Makefile rule, doc-build script, or equivalent) that detects PRD-vs-architecture transcription drift between this PRD and the next-revised architecture document; the target produces a drift report or a clean-pass verdict (B.5 — closes PD-3)." Story 14.5 IS the structural surface of FR-P3-16.
- **FR-P3-15 (verdict-criterion meta-pattern)** — each B.x lead-in story tests that the new template would have caught the prior-incident pattern. Story 14.5 AC #6 + Task 5 + Task 7 implement B.5's surface of FR-P3-15.
- **FR-P3-22..25 (phase-wide regression constraint)** — 973 PASS / 0 FAIL baseline + CODE-source byte-identical assembly + unprefixed numeric-literal form preserved. Story 14.5's AC #9 enforces the 973 PASS / 0 FAIL gate.
- **NFR-P3-2 (Phase-3-specific cumulative ROM budget)** — +200 bytes cap (24,996 → ≤ 25,200); B.5 envelope 0 bytes. Story 14.5's AC #8 enforces.
- **NFR-P3-7 (S9 codification)** — every binary-delta story runs hardware smoke; zero-binary-delta stories document exemption explicitly. Story 14.5's AC #8 + Task 9.1 enforce. Same exemption shape as Stories 14.1 / 14.2 / 14.3 / 14.4.
- **NFR-P3-18 (story-template discipline as quality attribute)** — "The story-template lints / HALT signals / pre-edit task additions established by B.1–B.5 fire automatically when triggered (lint catches 'mirrors' phrase, `wc -c` task captures actual binary, figure-drift discipline applies at draft time, **PRD-vs-architecture sync runs at doc-build time**). A story drafter does not need to remember to invoke them; they are baked into the workflow." Story 14.5 IS the structural surface of NFR-P3-18 for the doc-build-time sync.
- **NFR-P3-24 (S3 — real-byte-count estimation + capstone-aware drafting)** — Story byte-budget rationale is itemised per-part. Story 14.5's per-component itemisation in the Severity table demonstrates the discipline; the rationale is itemised, not "mirrors Stories 14.1..14.4 shape".
- **NFR-P3-31 (S10 — workflow > memory > prompt)** — Process discipline lives in workflow files, not in conversational prompts or memory entries. Story 14.5's deliverables land in the workflow surface (`Makefile` + new `tools/check-doc-sync/` subtree), not in a memory entry like `feedback_no_doc_drift.md` (which would be the architecture §"Bad — workflow edit (anti-pattern)" violation).

### Implementation site references (file:line)

(All references re-verified at Task 1.7 per B.4 discipline; verifications recorded in Recursive self-validation log below at dev-pass time.)

- **New files created** — `tools/check-doc-sync/check-doc-sync.sh` + `tools/check-doc-sync/README.md`
- **Tool-subtree precedent** — `tools/bdos_probe/bdos_probe.asm` (Story 11.5.1.2 firmware reproducer; self-contained subtree pattern)
- **Modified file (primary)** — `Makefile` (project-root)
  - **`.PHONY:` declaration** — line 44 (extend with `check-doc-sync` token)
  - **Tool-invoking target precedent** — `firmware-repro` / `firmware-repro-test` at lines 55..62 (for insertion-site grouping decision)
- **Modified file (secondary)** — `docs/PHASE-3-CARRY-FORWARD.md`
  - **B.5 row (unchanged in main classification table)** — line 36
  - **Status Tracking section** — lines 96..107 (extend with new B.5 closure row at :108)
  - **Closure-row shape precedent** — Story 14.4 row at `:106`; B.4-followup row at `:107`
- **Architecture B.5 spec** — `_bmad-output/planning-artifacts/architecture.md:272..282` (§"B.5-D1")
- **Architecture new-files row** — `_bmad-output/planning-artifacts/architecture.md:592..593`
- **Architecture Makefile-modified row** — `_bmad-output/planning-artifacts/architecture.md:604`
- **Architecture tooling boundary** — `_bmad-output/planning-artifacts/architecture.md:663..667`
- **Architecture doc-sync target description** — `_bmad-output/planning-artifacts/architecture.md:733`
- **Architecture sequencing recommendation** — `_bmad-output/planning-artifacts/architecture.md:932..937` (B.5 at :937)
- **Architecture pattern enforcement** — `_bmad-output/planning-artifacts/architecture.md:488..491` (sync targets entry)
- **Concrete prior PD row** — `_bmad-output/implementation-artifacts/epic-13-retro-2026-05-05.md` (PD-3 row in §"Documented Follow-Up Opportunities")
- **Carry-forward catalogue B.5 row** — `docs/PHASE-3-CARRY-FORWARD.md:36` (current row; classification + notes)
- **Carry-forward catalogue Status Tracking section** — `docs/PHASE-3-CARRY-FORWARD.md:96..` (Story 14.4's B.4 closure row at `:106` for shape precedent; B.4-followup row at `:107`)
- **B.4 enforcer block (Story 14.4)** — `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:62..86` (sibling discipline; this story's drafting discipline source — every figure here is re-validated at draft time per B.4)
- **B.3 enforcer block (Story 14.3)** — `_bmad/bmm/workflows/4-implementation/create-story/template.md:19..23` (sibling discipline at the template-file site; this story's Pre-edit Tasks 1.1 / 1.2 honour B.3)
- **Epics 14.5 spec** — `_bmad-output/planning-artifacts/epics.md:394..414` (Story 14.5 ACs #1..#9 verbatim)
- **Epic 14 shape** — `_bmad-output/planning-artifacts/epics.md:292..305` (Epic 14 lead-in cluster)
- **Predecessors** — Stories 14.1 / 14.2 / 14.3 / 14.4 at `_bmad-output/implementation-artifacts/14-{1,2,3,4}-*.md` (closed 2026-05-08, zero binary delta each)
- **Phase-3 PRD FR-P3-16** — `_bmad-output/planning-artifacts/prd.md:530`
- **Drift-check input files** — `_bmad-output/planning-artifacts/prd.md`, `_bmad-output/planning-artifacts/architecture.md`, `_bmad-output/planning-artifacts/epics.md`, `_bmad-output/planning-artifacts/epics-phase1-epics-1-8.md`, `_bmad-output/planning-artifacts/epics-phase2-epics-9-13.5.md`, `docs/ans-forth-core-compliance.md`

### Recursive self-validation log (populated at dev-pass — empty at draft time)

(This section IS the structural enforcement of B.4 — the discipline this story's drafter is governed by. Each cited file:line below MUST be re-validated by direct re-read at Pre-edit Task 1.7 during dev-pass, with the verification result recorded below the corresponding bullet. Empty at draft time; populated at dev-pass.)

- [x] **(i)** `epics.md:394..414` — Story 14.5 ACs. **Verification:** VERIFIED unchanged. Direct re-read at Pre-edit Task 1.7 — Story 14.5 header at `:394`; ACs #1..#9 transcribed verbatim into this story's AC section. AC3(a)..(d) phrasing matches `epics.md:406` verbatim.
- [x] **(ii)** `architecture.md:272..282` — B.5-D1 + drift-check enumeration. **Verification:** VERIFIED unchanged. Direct re-read confirmed §"B.5-D1: PRD-vs-architecture transcription-drift sync" at `:272`, drift checks 1..4 at `:276..280`, output format at `:274`, failure mode at `:282`. The script implements all four drift checks per the architecture's enumeration verbatim.
- [x] **(iii)** `architecture.md:592..593` — new files row. **Verification:** VERIFIED unchanged. Direct re-read confirmed `tools/check-doc-sync/check-doc-sync.<sh\|py>` + `tools/check-doc-sync/README.md` rows in §"New files created in Phase 3" table.
- [x] **(iv)** `architecture.md:604` — Makefile-modified row. **Verification:** VERIFIED unchanged. Direct re-read confirmed the row enumerates B.5 + B.6 + B.8 + B.1 changes; this story lands the B.5 portion only (`Makefile:44` `.PHONY:` extension + new `check-doc-sync:` target body at `:65..69`).
- [x] **(v)** `prd.md:530` — FR-P3-16. **Verification:** VERIFIED unchanged. Direct re-read confirmed the FR description matches the deliverable shape.
- [x] **(vi)** `docs/PHASE-3-CARRY-FORWARD.md:36 / :106 / :107` — B.5 row, Story 14.4 closure row, B.4-followup row. **Verification:** VERIFIED. B.5 row at `:36` retained unchanged in the main classification table per Stories 14.1..14.4 precedent (Status edits land in §"Status Tracking" closure-tracking table only). Story 14.4 closure row at `:106` and B.4-followup row at `:107` confirmed as shape precedents; new B.5 closure row appended at `:108` directly after the B.4-followup row.
- [x] **(vii)** `Makefile:44 / :55..62` — `.PHONY:` line + `firmware-repro` precedent. **Verification:** VERIFIED unchanged. `.PHONY:` declaration confirmed at `:44`; `firmware-repro` / `firmware-repro-test` at `:55..62` confirmed as the tool-invoking target body precedent. Per AC5(b), the new `check-doc-sync:` target body landed at `:65..69` (immediately after `firmware-repro-test`, preserving chronological order: older firmware tool-invoking target precedes newer doc-sync tool-invoking target).
- [x] **(viii)** `tools/bdos_probe/bdos_probe.asm:1..15` — header-shape precedent. **Verification:** VERIFIED. Header includes tool name, one-line description, related-story reference (Story 11.5.1.2), date (2026-04-27), author attribution, and build-invocation pointer. The new `check-doc-sync.sh` header mirrors this shape (Bash `#`-comment block instead of asm `;`-comment block).
- [x] **(ix)** `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:62..86` — B.4 block. **Verification:** VERIFIED unchanged. The B.4 figure-drift discipline block was directly governing this dev-pass — every figure / file:line / line-count cited in this story's draft was re-validated at Pre-edit Task 1.7 by direct re-read, and one in-pass-fix moment surfaced (see §"AC6 first-run verdict log" below — the script's PRD-side label regex needed extending and range expansion needed adding to honour the architecture's actual citation forms; both reconciled in-pass per Stories 14.2/14.3/14.4 precedent, no HALT).

If any verification surfaces a divergence (cited line:col content differs from current source-of-truth), root-cause investigation precedes any subsequent task per Lesson 13.5-F + PD-2. The divergence itself is evidence of the drift class B.4 / B.5 codify discipline against, and is documented in Completion Notes as a verdict-criterion-passing recursive-self-validation moment.

### AC6 first-run verdict log (populated at dev-pass — empty at draft time)

(This section is the FR-P3-15 verdict-criterion surface for B.5. Populated at Task 2.4 / Task 4.5 / Task 5 / Task 7 during the dev-pass. Empty at draft time; the dev-pass writes the verdict here.)

**Direct-bash invocation (Task 2.4) — final post-refinement run:**
```
$ bash tools/check-doc-sync/check-doc-sync.sh
[advisory] doc-sync: 18 advisory item(s); 0 drift
$ echo "exit code: $?"
0
```

**Two-run determinism check (Task 7.2):**
```
$ bash tools/check-doc-sync/check-doc-sync.sh > /tmp/14-5-run1.out 2> /tmp/14-5-run1.err
$ bash tools/check-doc-sync/check-doc-sync.sh > /tmp/14-5-run2.out 2> /tmp/14-5-run2.err
$ diff /tmp/14-5-run1.out /tmp/14-5-run2.out  # → empty (IDENTICAL)
$ diff /tmp/14-5-run1.err /tmp/14-5-run2.err  # → empty (IDENTICAL)
```

**Makefile invocation (Task 4.5):**
```
$ make check-doc-sync
[advisory] doc-sync: 18 advisory item(s); 0 drift
$ echo "exit code: $?"
0
```
Output identical to direct-bash invocation (verified by `diff /tmp/14-5-makefile.out /tmp/14-5-run1.out` — empty; `diff /tmp/14-5-makefile.err /tmp/14-5-run1.err` — empty).

**AC6 disposition:** **(c) advisory-only** — `[advisory] doc-sync: 18 advisory item(s); 0 drift` on stdout, exit 0, no `[fr-label]` / `[nfr-label]` / `[story-cite]` / `[section-name]` strict-mode items. The verdict matches the story's "Expected first-run disposition" forecast in Dev Notes §"Expected first-run disposition" (advisory-only). The expected count was 30..60 advisory items; actual is 18 (3 §-references + 15 section-name divergences) — comfortably below the upper estimate.

**In-pass script refinements** (per S5 / B.4 figure-drift discipline applied to AC3(a) implementation detail — exactly the figure-drift class B.4 codifies, surfaced in B.5's own dev-pass; reconciled in-pass per Stories 14.2/14.3/14.4 precedent, not HALTed):
- **Refinement 1 — PRD-side label regex.** The story's AC3(a) implementation-detail line cites `grep -oE '\*\*(FR|NFR)-P3-[0-9]+\*\*' prd.md` — but the actual PRD definition shapes are `- **FR-P3-N:**` (FR with colon directly inside the bold) and `- **NFR-P3-N (carries Phase-2 NFR1–NFR5):**` (NFR with parenthetical text between number and colon). Neither shape contains the substring `**FR-P3-N**` directly. Refined to bullet-anchored extractor: `grep -oE '^- \*\*(FR|NFR)-P3-[0-9]+' "$PRD" | grep -oE '(FR|NFR)-P3-[0-9]+'`. Confirmed via direct `grep -nE 'NFR-P3-' prd.md` walk that line-start bullet form is the canonical definition shape.
- **Refinement 2 — Architecture-side range expansion.** Architecture cites FR/NFR-P3-N labels both as singletons (`FR-P3-15`) and as inclusive ranges (`FR-P3-22..25`, `NFR-P3-1..33`, etc.; 15 distinct range citations enumerated by direct grep at refinement time). Without expansion, range-only references caused 35 false-positive drift items (16 FRs + 19 NFRs all defined in PRD but cited in architecture only via ranges). Added `expand_ranges()` shell function that walks each `(FR|NFR)-P3-A..B` token and emits `(FR|NFR)-P3-A`, `(FR|NFR)-P3-A+1`, ..., `(FR|NFR)-P3-B`; merges into the architecture-cited set before the bidirectional set difference. Post-refinement: all 35 false-positives resolved cleanly.

After both refinements, strict-mode drift count dropped from 35 → 0 across the AC3(a) check; AC3(b) check (story citation resolution) and AC3(c)/(d) advisory checks were unaffected.

**Drift items reconciled in-pass (original dev-pass + /CR fix-pass):**
- Original dev-pass: None at the time, due to the AC3(b) regex bug described below. Strict-mode drift count was reported as 0 after the in-pass script refinements (Refinement 1 + Refinement 2 above), but that count was load-bearing on a 3-component-cap regex that silently truncated 4-component citations.
- /CR fix-pass: One `[story-cite]` strict drift item — `Story 11.5.1.2` cited at `architecture.md:598` with no matching `### Story 11.5.1.2:` header in any epics file. Reconciled in-pass per AC6(b) typo-class disposition: edited `architecture.md:598` to drop the `.2`, citing `Story 11.5.1` (the parent crash-audit story whose deliverable the bdos_probe tool subtree was — verified by direct re-read of `epics-phase2-epics-9-13.5.md:929` `### Story 11.5.1: Real-MicroBeast hardware crash audit`). No B.5-followup row required; the citation was a typo-class drift exactly the AC6(b) reconcile-in-pass pattern is shaped for. Post-fix verdict re-confirmed `[advisory] doc-sync: 18 advisory item(s); 0 drift`, exit 0, two-run determinism identical — now genuinely earned (no truncation hiding strict drift).

**Advisory items kept advisory (18 total):**
- **3 `[advisory-§]` items** — `§6.1.0090` (cited in `architecture.md:116`), `§6.1.1561` (cited in `architecture.md:501`), `§6.2.1342` (cited in `architecture.md:393`). Reasoning: pre-A.1 advisory mode per AC3(c); the compliance doc (`docs/ans-forth-core-compliance.md`) is currently word-counted, not §-counted, so missing rows for these specific §-numbers reflect the A.1 strategic-body coverage gap, not transcription drift. Will close with Story 15.1 (A.1 audit walk) — the script's `STRICT_SECTIONS=0` flag will flip to `1` after Story 15.1 closes.
- **15 `[advisory-section]` items** — 9 PRD-only level-2 sections (`Developer-Tool-Embedded Requirements`, `Executive Summary`, `Functional Requirements`, `Non-Functional Requirements`, `Product Scope`, `Project Classification`, `Project Scoping & Phased Development`, `Success Criteria`, `User Journeys`) + 6 architecture-only level-2 sections (`Architecture Validation Results`, `Core Architectural Decisions`, `Implementation Patterns & Consistency Rules`, `Project Context Analysis`, `Project Structure & Boundaries`, `Starter Template Evaluation`). Reasoning: PRD and architecture intentionally serve different roles (requirements catalogue vs implementation pattern reference); zero overlap in level-2 section names is by design. Per AC3(d), `SECTION_ALLOWLIST` remains empty — no agreed-on shared section pairs exist between the two documents, so no allowlist entries are warranted.

### Pre-edit baseline reconciliation — documentation-drift note

Per Stories 14.1 / 14.2 / 14.3 / 14.4 Pre-edit baseline reconciliations (and original `13.5-6-…md` Task 2 Documentation-drift reconciliation, Epic-13.5 close-out), the Phase-3 PRD + architecture + epics docs **all cite 24,996 bytes** as the post-Epic-13.5 baseline. The actual current build at HEAD `7172754` (the Story-14.4 commit) is **24,995 bytes** — 1 byte less than the documented Epic-13.5-close figure. This is the v2.0.0 banner-bump drift Story 14.1 surfaced and reconciled.

This reconciliation is **not a Story-14.5 regression** — it's the same illustrative inheritance-drift artefact carried from Story 13.5.6's close, confirmed unchanged through Stories 14.1 / 14.2 / 14.3 / 14.4 closes, and re-confirmed at Story 14.5's Pre-edit Task 1.1. **Per the disciplines this story's drafter is governed by (B.3 + B.4)**, the Pre-edit Task 1.1 / 1.2 re-`wc -c`s directly rather than inheriting any prior story's reported number. Expected directly-measured figures: 24,995 / 26,460 (matching Stories 14.1..14.4's reports — they are the most-recent-prior-story reported values, not gospel; Pre-edit Task 1.1 verifies). If the directly-measured figures diverge, the divergence is evidence of the doc-drift class B.3 + B.4 + B.5 prevent and must be investigated per Lesson 13.5-F + PD-2 before the dev-pass proceeds.

**Note on B.5 self-consistency**: the 24,996/24,995 drift is itself an instance of the class B.5 codifies discipline against — a figure cited in PRD/architecture that differs from the current source-of-truth. However, B.5's drift-checker (AC3(a)..(d)) does NOT detect this specific class — its four checks are FR/NFR labels, Story citations, §X.Y.Z references, and section names. Binary-byte-count drift in PRD/architecture is a *different* drift class, addressable by a hypothetical AC3(e) "binary-size citation parity" check. **Disposition: out of scope for Story 14.5.** Documenting here per S8 honest-disposition pattern; can be added as a later enrichment to the script if a future story finds this specific drift class costly. The B.5 deliverable scope is the four checks pinned by `architecture.md:276..280`.

### Project Structure Notes

- **No new architectural surface for the kernel.** Story 14.5 modifies one existing file (`Makefile`) and creates two new files (`tools/check-doc-sync/check-doc-sync.sh` + `tools/check-doc-sync/README.md`) plus updates one Status row (`docs/PHASE-3-CARRY-FORWARD.md` §"Status Tracking" — adding Story 14.5 closure row). Per `architecture.md` §"Project Structure & Boundaries", the kernel boundary is frozen for Phase 3 — Story 14.5 does not touch any `src/*.asm` file.
- **Tool-subtree boundary alignment.** Per `architecture.md:592..593, 598` ("Path under `tools/check-doc-sync/` follows the `tools/bdos_probe/` precedent (Story 11.5.1.2 firmware reproducer); a self-contained subdirectory keeps tool logic separable from the kernel build"): Story 14.5 lands the new tool subtree in the architecturally-pinned location (no alternative location considered).
- **Makefile target placement decision.** AC5(b) gives the drafter the choice between end-of-file vs. grouped near `firmware-repro` / `firmware-repro-test` at `:55..62`. The latter is the precedent for "tool-invoking target body" placement and is the recommended pick (preserves chronological reading order: `firmware-repro` is the older tool-invoking target; `check-doc-sync` is the newer). Final pick documented in Completion Notes per Task 4.1.
- **Bash language pick.** AC1 fixes Bash per the architecture deferral at `:667`. Reasoning: zero-runtime-dependency on the build host (every Linux/macOS/WSL host has bash + grep + awk + sort + comm); parity with the existing `tools/bdos_probe/` precedent (which uses POSIX shell for its build glue at `Makefile:55..62`); no `jq` / Python / Node dependency; the four drift checks are text-set-difference operations naturally expressed in shell with `grep -oE` + `sort -u` + `comm`.
- **No installer-manifest entry for `tools/check-doc-sync/`.** The `tools/` directory is in-tree (not gitignored; `.gitignore` does not exclude it); files committed to git persist permanently. Different persistence model from the `_bmad/` workflow-tree files (which are gitignored and rely on local-file persistence per Stories 13.5.0 / 14.2 / 14.3 / 14.4 honest-disposition pattern). **`tools/check-doc-sync/` does NOT face the AC7 "constraint named, not closed" disposition** that Stories 14.2 / 14.3 / 14.4 honoured — its persistence is git-tracked, not workflow-runtime-cached.

### Standards / discipline citations

- **PD-3** ("PRD-vs-architecture transcription drift") — `epic-13-retro-2026-05-05.md` PD-3 row in §"Documented Follow-Up Opportunities"
- **Standing commitment S10** (workflow > memory > prompt) — codified as NFR-P3-31; per architecture §"Bad — memory edit (anti-pattern)" line 554..559
- **Standing commitment S11** (version-surface audit at tag close-out) — codified as NFR-P3-32; B.5's clean-pass is the documented S11 sibling per architecture §"Doc-sync (NEW, opt-in)" `:733`
- **CCD-P3-2** (Process discipline lives in workflow files) — `architecture.md:197..217`
- **PD-1 enforcer pattern** — `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:20..31` (the workflow-file-edit-discipline precedent)
- **B.2 enforcer block (Story 14.2)** — `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:33..60`
- **B.3 enforcer block (Story 14.3)** — `_bmad/bmm/workflows/4-implementation/create-story/template.md:19..23`
- **B.4 enforcer block (Story 14.4)** — `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:62..86`
- **`tools/bdos_probe/` precedent (Story 11.5.1.2)** — self-contained tool subtree pattern; first instance of `tools/<tool-name>/` in the project
- **Architecture §"Bad — memory edit (anti-pattern)"** — `architecture.md:554..559`

### Standing-commitment context (S1..S12)

Per Epic-13.5 retro 2026-05-07, all 12 standing commitments held across the retro and were codified as NFR-P3-22..33 in the Phase-3 PRD. For Story 14.5 — abbreviated walk per Story 14.3 / 14.4 L2 feedback (the full S1..S12 walk with per-row text was preserved in Stories 14.1/14.2/14.3/14.4; Story 14.5 references the codified pattern rather than re-enumerating):

- **S1, S5, S8** — adversarial review fresh-context external; PARTIAL→HALT; no "pre-existing" discharge for correctness defects: ACs do NOT enumerate in-pass adversarial review; AC #6(d) carries HALT discipline; B.8 deferral disposition is a *named* deferral per honest-disposition pattern (not a silent omission).
- **S2, S9** — REPL-piped tests as default; per-story hardware smoke: tooling-addition story; no new REPL probes (the drift-checker is host-side); S9 exempt + documented (AC #8 + Task 9.1).
- **S3** — real-byte-count estimation + capstone-aware drafting: per-component itemisation in the Severity table (Makefile target + Bash script + README + carry-forward update — all zero kernel-byte cost), independent of prior stories.
- **S4** — AC composition: ACs #1..#9 stand alone or compose cleanly with named antecedents; AC3's drift checks compose into AC4's exit-code contract; AC6 verdict-criterion meta-pattern composes over AC3..AC5.
- **S10** — workflow > memory > prompt: deliverables land in workflow surface (`Makefile` + `tools/check-doc-sync/` subtree), NOT in a memory entry. **Cluster completion**: B.1 + B.2 + B.3 + B.4 + B.5 together move the Phase-3 process foundation from why-surface (memory entries, retro discussions, carry-forward catalogue) to enforcement-surface (workflow files + Makefile targets); no S10 violation in any of the five.
- **S11** — version-surface audit: not tag-applicable (Ant's call per Epic 14 §"Shape" — banner-bump optional). Same as Stories 14.1/14.2/14.3/14.4. **However** — and this is the architectural significance of Story 14.5 — a tag-applicable close-out *after* this story lands gains a new pre-condition: `make check-doc-sync` clean-pass per architecture §"Doc-sync (NEW, opt-in)" `:733`. Story 14.5 is the structural creator of the S11 sibling.
- **S12** — hardware-typed probe authoring discipline: not directly engaged (host-side tool, not antforth probe).

Full S1..S12 walk recorded in Completion Notes at story-close.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:292..305`] Epic 14: Phase-3 Process Foundation — lead-in cluster B.1..B.5
- [Source: `_bmad-output/planning-artifacts/epics.md:394..414`] Story 14.5 ACs #1..#9 verbatim
- [Source: `_bmad-output/planning-artifacts/epics.md:212`] FR-P3-16 (B.5) — PRD-vs-architecture transcription-drift sync target
- [Source: `_bmad-output/planning-artifacts/epics.md:211`] FR-P3-15 verdict-criterion meta-pattern
- [Source: `_bmad-output/planning-artifacts/architecture.md:197..217`] CCD-P3-2 — Process discipline lives in workflow files
- [Source: `_bmad-output/planning-artifacts/architecture.md:217 / :270`] Implications for B.x verdict criteria (discipline-as-deliverable)
- [Source: `_bmad-output/planning-artifacts/architecture.md:272..282`] B.5-D1 architectural decision
- [Source: `_bmad-output/planning-artifacts/architecture.md:343..347`] Per-story binary delta envelope (B.5 = 0 bytes)
- [Source: `_bmad-output/planning-artifacts/architecture.md:456`] Hardware-smoke cadence (S9 exemption for B.1–B.5)
- [Source: `_bmad-output/planning-artifacts/architecture.md:478,484`] All Phase-3 dev-pass agents MUST items 3 + 9 (deliverable landing site; re-`wc -c` discipline)
- [Source: `_bmad-output/planning-artifacts/architecture.md:488..491`] Pattern enforcement mechanisms (sync targets in Makefile)
- [Source: `_bmad-output/planning-artifacts/architecture.md:592..593`] New files created in Phase 3 (B.5 tool subtree)
- [Source: `_bmad-output/planning-artifacts/architecture.md:604`] Existing files modified in Phase 3 (Makefile B.5 row)
- [Source: `_bmad-output/planning-artifacts/architecture.md:663..667`] Tooling boundary (Bash language deferral)
- [Source: `_bmad-output/planning-artifacts/architecture.md:733`] Doc-sync (NEW, opt-in) — clean-pass before tag close-out (S11 sibling)
- [Source: `_bmad-output/planning-artifacts/architecture.md:932..937`] Recommended sequencing within the lead-in (B.5 fourth)
- [Source: `_bmad-output/planning-artifacts/prd.md:530`] FR-P3-16 — sync target capability requirement
- [Source: `_bmad-output/planning-artifacts/prd.md:590`] NFR-P3-18 — story-template discipline as quality attribute (PRD-vs-architecture sync at doc-build time)
- [Source: `_bmad-output/implementation-artifacts/13.5-0-pd-1-workflow-and-create-story-ac-alignment.md`] PD-1 precedent — first `<critical>` block in `instructions.xml`
- [Source: `_bmad-output/implementation-artifacts/14-1-pad-documented-as-canonical-transient-buffer-for-test-authors.md`] Story 14.1 (B.1) — predecessor story shape template
- [Source: `_bmad-output/implementation-artifacts/14-2-mirrors-prior-arm-halt-signal-lint-in-story-template.md`] Story 14.2 (B.2) — predecessor; honest-disposition pattern at AC7
- [Source: `_bmad-output/implementation-artifacts/14-3-story-to-story-binary-handoff-re-wc-c-at-dev-pass-start.md`] Story 14.3 (B.3) — predecessor; recursive-self-validation at AC5(b); Pre-edit baseline subsection precedent
- [Source: `_bmad-output/implementation-artifacts/14-4-pd-2-figure-drift-discipline-critical-block.md`] Story 14.4 (B.4) — immediate predecessor; recursive-self-validation discipline source; per-component byte-budget pattern; sprint-status honest-disposition precedent
- [Source: `_bmad-output/implementation-artifacts/epic-13-retro-2026-05-05.md`] PD-3 row — motivating retro item
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:62..86`] B.4 enforcer block — this story's drafting discipline source
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/template.md:19..23`] B.3 enforcer block — Pre-edit Task 1.1 / 1.2 source
- [Source: `Makefile:44`] `.PHONY:` declaration — Story 14.5 extends this line
- [Source: `Makefile:55..62`] `firmware-repro` / `firmware-repro-test` — tool-invoking target precedent
- [Source: `tools/bdos_probe/bdos_probe.asm:1..30`] Header-shape precedent for tool-subtree script
- [Source: `docs/PHASE-3-CARRY-FORWARD.md:36`] B.5 carry-forward catalogue row
- [Source: `docs/PHASE-3-CARRY-FORWARD.md:106`] Story 14.4 closure row — shape precedent for B.5 closure row
- [Source: `docs/PHASE-3-CARRY-FORWARD.md:107`] B.4-followup row — shape precedent for any B.5-followup row spawned at Task 5.3

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

(Populated at dev-pass)

- Pre-edit baseline run: `/tmp/14-5-pre-edit.out`
- Post-edit regression run: `/tmp/14-5-post-edit.out`
- AC6 first-run direct-bash output: `/tmp/14-5-run1.out`
- AC6 first-run repeat (determinism check): `/tmp/14-5-run2.out`

### Completion Notes List

**Story 14.5 verdict:** ALL 9 ACs PASS (post-/CR fix-pass). Status: done. Zero binary delta (production binary 24,995 bytes Δ 0; filesanity binary 26,460 bytes Δ 0). `make test-repl` 973 PASS / 0 FAIL (zero movement from pre-edit baseline). S9 hardware-smoke exempt + documented (zero binary delta tooling addition; per architecture §"Hardware-smoke cadence" — "Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped"). S11 not tag-applicable (Story 14.5 is the close-out of Epic 14's lead-in cluster, not a tag-applicable story); banner-bump optional per Ant's call. **Epic 14 closes with this story** — all five P1 lead-in items B.1..B.5 discharged; the structural lints + sync targets that shape every subsequent Phase-3 dev-pass are in place. Epic 15 (Phase-3 Standards Close-Out) becomes unblocked.

**Per-AC verdict walk (1..9):**
1. **AC #1 PASS.** New self-contained tool subtree at `tools/check-doc-sync/` with `check-doc-sync.sh` (executable, `#!/usr/bin/env bash` shebang) + `README.md`. Invocable as `bash tools/check-doc-sync/check-doc-sync.sh` from project root. Verified by `ls tools/check-doc-sync/` and `bash tools/check-doc-sync/check-doc-sync.sh` (exit 0, advisory-only output).
2. **AC #2 PASS.** Script reads each input file exactly once per invocation, into line-numbered cache variables (`ARCH_LINES`, `PRD_LINES`, `COMP_LINES`, `EPICS_HEADERS`); all subsequent token extraction and per-orphan loc lookups operate on those variables, never re-opening the files on disk. Missing input emits `[fatal] required input file missing or unreadable: <path>` on stderr and exits 1 (the for-loop walks all six input paths and aggregates a `fatal` flag). All script output emitted via `printf` only (no leakage of intermediate `awk`/`grep` output). (CR fix-pass — H4: original implementation re-read architecture.md ~5× during token extraction; refactored to single-read cache.)
3. **AC #3 PASS.** All four drift checks implemented as separate logical blocks: (a) FR/NFR label parity (bidirectional set difference, with range expansion); (b) Story X.Y[.Z[.W…]] citation resolution against the three epics files — citation regex matches one or more trailing dot-separated components so 4-component citations (e.g., `Story 11.5.1.2`) survive intact; (c) §N.M[.K[…]] reference parity (advisory pre-A.1; `STRICT_SECTIONS=0` flag) — same one-or-more-trailing-component handling; (d) section-name parity (advisory; empty `SECTION_ALLOWLIST`). Strict-mode aggregation per AC3 final paragraph: exit 1 if any non-advisory item; exit 0 otherwise. (CR fix-pass — H1/M1: original regexes capped at 3 components, silently truncating 4-component citations like `Story 11.5.1.2` and `§3.1.4.1`; widened to `(\.[0-9]+)+`.)
4. **AC #4 PASS.** Exit-code contract honoured: (a) Clean-pass produces exact `[ok] doc-sync: 0 drift` on stdout, exit 0; (b) Drift produces line-per-drift on stderr with `[<check-id>] description` format (check-ids: `[fr-label]`, `[nfr-label]`, `[story-cite]`, `[advisory-§]`, `[§-cite]`, `[advisory-section]`, plus drift summary `[drift]`); advisory-only produces `[advisory] doc-sync: <N> advisory item(s); 0 drift` on stdout, exit 0; (c) No other exit codes — `[fatal]` failures exit 1; (d) No `set -e` global, per-check error handling.
5. **AC #5 PASS.** Makefile edits: (a) `.PHONY:` declaration at `Makefile:44` extended with `check-doc-sync` (appended at end-of-line; preserves existing tokens; one-line diff). (b) New target body at `Makefile:64..69`, grouped immediately after `firmware-repro-test` per the architectural precedent for tool-invoking targets (chronological order: older firmware tool target → newer doc-sync tool target). Layout: 4-line comment block at `:64..67`; rule line `check-doc-sync:` at `:68`; recipe `@bash tools/check-doc-sync/check-doc-sync.sh` at `:69`. Body has no prerequisites; recipe is single line (tab-indented per Makefile syntax). (c) Target NOT a prerequisite of `test-repl` (`:103`), `test`, `all` (`:46`), or `asm` (`:48`); `grep -nE 'check-doc-sync' Makefile` returns 3 matches at `:44 / :68 / :69` — all on advisory-target sites, none in dependency chains. (d) `make test-repl` produces 973 PASS / 0 FAIL post-edit; `make check-doc-sync` is independently invokable and produces the AC4 output shape. (CR fix-pass — L1: target body originally cited as `:65..69`; actual range is `:64..69` since the comment block opens at `:64`.)
6. **AC #6 PASS.** Final post-CR verdict against commit `7172754` + the in-tree CR fix-pass: **(c) advisory-only disposition** — `[advisory] doc-sync: 18 advisory item(s); 0 drift` on stdout, exit 0, no strict-mode drift items. Two-run determinism: `diff` of consecutive run outputs is empty for both stdout and stderr (deterministic). Makefile invocation: identical output to direct-bash invocation. No HALT condition triggered. Verdict documented in Dev Notes §"AC6 first-run verdict log". (CR fix-pass — H1: pre-CR verdict was the same advisory-18 string but was load-bearing on the 3-component regex bug, which silently masked one strict `[story-cite]` drift item — `Story 11.5.1.2` cited at `architecture.md:598` with no matching epics header. CR widened the regex, the strict drift surfaced, and the architecture citation was reconciled in-pass to `Story 11.5.1` — the parent crash-audit story whose deliverable the bdos_probe tool subtree was. Re-run produced the same advisory-18 string, now genuinely earned.)
7. **AC #7 PASS.** `tools/check-doc-sync/README.md` enumerates: (a) the four drift checks with one paragraph each describing domain + resolution shape (sub-sections "(a) FR-P3-N / NFR-P3-N label parity", "(b) `Story X.Y` citation resolution", "(c) `§X.Y.Z` reference parity", "(d) Top-level section-name parity"); (b) exit-code contract in tabular form ("Exit codes" section); (c) intended cadence verbatim from `epics.md:410` ("run `make check-doc-sync` before any antforth 2.x tag close-out (S11 sibling — version-surface audit reads cleanly only when doc-sync also reads cleanly); advisory at any other time" — "Cadence" section); (d) PD-3 / Epic 13 retro #2 motivating reference + carry-forward catalogue pointer (top-of-doc paragraph + "See also" section); (e) architecture-pinned spec pointer at `architecture.md:272..282` ("See also" section); (f) `STRICT_SECTIONS` flag documented with Story 15.1 / A.1 closure as the flip condition ("(c) `§X.Y.Z` reference parity" sub-section). README is well-formed Markdown — header hierarchy `^#+` returns clean nested levels (one `#` for top-level title, multiple `##` and `###` for sub-sections; no malformed bullets or inline-code).
8. **AC #8 PASS.** `wc -c build/antforth.com` post-edit: **24,995 bytes** (Δ = 0 vs Pre-edit Task 1.1's 24,995). `wc -c build/antforth_filesanity.com` post-edit: **26,460 bytes** (Δ = 0 vs Pre-edit Task 1.2's 26,460). `make` post-edit: "Nothing to be done for 'all'" (kernel build path untouched by tooling addition). S9 hardware-smoke documented exempt — zero binary delta (tooling addition + Makefile target + carry-forward Status update only); per architecture §"Hardware-smoke cadence" — *"Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped."* Same exemption shape as Stories 14.1 / 14.2 / 14.3 / 14.4. NFR-P3-2 envelope: B.5 = 0 bytes (per architecture §"Per-story binary delta envelopes" line 347).
9. **AC #9 PASS.** `make test-repl` pre-edit: 973 PASS / 0 FAIL (verified at Pre-edit Task 1.3). Post-edit: 973 PASS / 0 FAIL — zero regressions, zero test-count movement. `make test` (assembly thread) post-edit: 0 errors / 0 warnings, "PASS: Output matches expected" (informational; not a PARTIAL gate). `make test-file-sanity` post-edit: PASS (12 expected lines match exactly per Story-13.5.2 H1 discriminator). Adding the new tool subtree + advisory-only Makefile PHONY target had zero impact on the test surface — as required by AC5(c) (target not in any test-recipe dependency chain).

**Standing-commitment walk (S1..S12):**
- **S1 (adversarial review fresh-context external)** — HOLDS. ACs do NOT enumerate "trigger an adversarial review pass". PD-1 `<critical>` block at `instructions.xml:20..31` enforces structurally. The story's drafting and dev-pass were governed by the codified pattern, not in-pass adversarial review.
- **S2 (REPL-piped tests as default)** — HOLDS. The drift-checker is a host-side tool, not a REPL probe. AC9 confirms the tool addition doesn't perturb the kernel test surface (973 PASS / 0 FAIL unchanged).
- **S3 (real-byte-count estimation + capstone-aware drafting)** — HOLDS. Per-component itemisation in the Severity table (Bash script body + README body + `.PHONY:` extension + new target body + carry-forward Status update — all zero kernel-byte cost), independent of prior stories. Stories 14.1..14.4 cited as **sanity-check anchor**, not source. The B.2 lint Story 14.2 codified passes for this story's Severity rationale.
- **S4 (AC composition)** — HOLDS. ACs #1..#9 stand alone or compose cleanly — AC3's drift checks compose into AC4's exit-code contract; AC6 verdict-criterion meta-pattern composes over AC3..AC5; AC8/AC9 are independent regression gates.
- **S5 (PARTIAL → HALT)** — HOLDS. The two in-pass script refinements (PRD-regex extension + range expansion) are themselves the disposition for AC3(a) implementation-detail drift surfaced by the first run — exactly the "reconcile in-pass" path Stories 14.2/14.3/14.4 took for their own surfaced drift moments. No PARTIAL ship; no `14-5-1*.md` sibling-story spawn; first-run drift was 35 items, post-refinement strict drift was 0. AC6(b) drift-with-reconciliation NOT engaged (the in-pass refinements eliminated the drift class entirely; no PRD/architecture content edits required).
- **S6 (inventory-grep covers helpers)** — N/A. Story 14.5 adds no kernel helpers; the drift-checker is host-side Bash. No `src/*.asm` touched.
- **S7 (EXX-hygiene per raise site)** — N/A. No kernel surgery in scope.
- **S8 (no "pre-existing" discharge for correctness defects)** — HOLDS. Story 14.5 closes a workflow-discipline gap (no transcription-drift detection at doc-build time), not a correctness defect. The B.8 deferral disposition is a **named** deferral with explicit reasoning per honest-disposition pattern (see Dev Notes §"B.8 deferral note") — not a silent omission.
- **S9 (per-story hardware smoke)** — HOLDS via documented exemption. Zero-binary-delta tooling-addition story; exempt per NFR-P3-7 / architecture §"Hardware-smoke cadence". Same exemption shape as Stories 14.1 / 14.2 / 14.3 / 14.4.
- **S10 (workflow > memory > prompt)** — HOLDS. Deliverables land in workflow surface (`Makefile` PHONY target + `tools/check-doc-sync/` self-contained subtree), NOT in a memory entry like `feedback_no_doc_drift.md` (which would be the architecture §"Bad — memory edit (anti-pattern)" violation Stories 14.1..14.4 collectively closed at five sites). **Cluster completion**: B.1 + B.2 + B.3 + B.4 + B.5 together move the Phase-3 process foundation from why-surface (memory entries, retro discussions, carry-forward catalogue) to enforcement-surface (workflow files + Makefile targets); no S10 violation in any of the five.
- **S11 (version-surface audit at tag close-out)** — HOLDS. Story 14.5 is not tag-applicable (Ant's call per Epic 14 §"Shape" — banner-bump optional). **Architectural significance**: a tag-applicable close-out *after* this story lands gains a new pre-condition: `make check-doc-sync` clean-pass (or advisory-only with documented disposition) becomes a documented S11 sibling per architecture §"Doc-sync (NEW, opt-in)" `:733`. Story 14.5 is the structural creator of the S11 sibling.
- **S12 (hardware-typed probe authoring)** — N/A. Host-side tool, not antforth probe.

**No PARTIAL ship.** All 9 ACs PASS. No sibling-story spawn — `ls _bmad-output/implementation-artifacts/14-5-1*.md` returns no match. No B.5-followup row filed (first-run advisory-only disposition required no PRD/architecture content edits; the in-pass script refinements were the appropriate disposition for the AC3(a) implementation-detail drift, fully closed in this story's deliverables).

**Sprint-status transition (honest disposition):** Pre-dev-pass status was `backlog` (per `git show 7172754:_bmad-output/implementation-artifacts/sprint-status.yaml`, the row read `14-5-...: backlog` at the Story-14.4 close commit; Story 14.5 was authored via the create-story workflow but the sprint-status row was never flipped from `backlog` → `ready-for-dev` at that point). Single-step transition `backlog → review` was actually executed in this dev-pass — the workflow's Step 4 spec (transition through `ready-for-dev` → `in-progress` → `review`) is honoured in spirit (the work was done before the row was flipped to `review`), but the YAML edit was a single transition rather than three separate edits. Same shape as Stories 14.3 / 14.4 transitions per their /CR fix-pass corrections (the canonical multi-step transition is workflow-prescribed but practically conflated to one edit at story-close). **(CR fix-pass — M2: original Completion Note claimed pre-state was `ready-for-dev`; git diff shows actual was `backlog`. Exactly the figure-drift class B.4 codifies — surfaced in B.5's own dev-pass, same shape as Story 14.4 H1+H2; corrected here.)**

### File List

**New files:**
- `tools/check-doc-sync/check-doc-sync.sh` — Bash drift-checker script (executable, 218 lines including comments; `#!/usr/bin/env bash` shebang; pre-flight + 4 drift checks + verdict aggregation).
- `tools/check-doc-sync/README.md` — Tool documentation (drift-check rules, exit-code table, cadence, extension guidance, "See also" pointer cluster).

**Modified files:**
- `Makefile` — `.PHONY:` declaration at `:44` extended with `check-doc-sync` token; new `check-doc-sync:` target body added at `:64..69` (4-line comment block + rule line + recipe line, grouped after `firmware-repro-test` per AC5(b) precedent).
- `docs/PHASE-3-CARRY-FORWARD.md` — §"Status Tracking" extended with new B.5 closure row at `:108` (immediately after the B.4-followup row at `:107`).
- `_bmad-output/planning-artifacts/architecture.md` — `:598` citation `Story 11.5.1.2 firmware reproducer` → `Story 11.5.1 firmware reproducer` (CR fix-pass / AC6(b) reconcile-in-pass: the original cite resolved to no epics header; parent Story 11.5.1 is the existing crash-audit story whose deliverable the bdos_probe tool subtree was).
- `_bmad-output/implementation-artifacts/14-5-prd-architecture-transcription-drift-sync-target-make-check-doc-sync.md` — Story Status flipped from `ready-for-dev` to `review`; Tasks/Subtasks all marked [x]; Recursive self-validation log populated; AC6 first-run verdict log populated; Completion Notes / File List / Change Log filled. CR fix-pass corrections appended.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `14-5-prd-architecture-transcription-drift-sync-target-make-check-doc-sync` row transitioned `backlog → review`; `epic-14` row remains `in-progress` (Ant's call per Epic 14 §"Shape" — `epic-14-retrospective` is `optional`, banner-bump is optional).

### Change Log

| Date | Change | Reason |
|---|---|---|
| 2026-05-08 | New self-contained tool subtree at `tools/check-doc-sync/` (`check-doc-sync.sh` Bash drift-checker + `README.md` documentation) | B.5 / PD-3 deliverable per architecture §"B.5-D1" `:272..282`; closes the long-deferred Phase-3 carry-forward item identified at `epic-13-retro-2026-05-05.md` PD-3 row + `docs/PHASE-3-CARRY-FORWARD.md:36` (Epic 13 retro #2). Tool subtree pattern follows the `tools/bdos_probe/` precedent (Story 11.5.1 crash-audit / firmware reproducer). |
| 2026-05-08 | New `check-doc-sync` PHONY target in `Makefile` (`.PHONY:` extension at `:44` + advisory-only target body at `:64..69`) | FR-P3-16 capability requirement per `prd.md:530`; Makefile surface per architecture `:604`. Target is advisory-only on `make test-repl` (does not block); expected clean before any tag-applicable close-out (S11 sibling per architecture `:733`). |
| 2026-05-08 | New B.5 closure row appended to `docs/PHASE-3-CARRY-FORWARD.md` §"Status Tracking" at `:108` | Honest-disposition tracking per Stories 14.1 / 14.2 / 14.3 / 14.4 closure-row precedent. Closes the B.5 item; the cluster B.1..B.5 is now structurally complete; Epic 14 closes; Epic 15 unblocked. |
| 2026-05-08 | Sprint-status row transition: `14-5-prd-architecture-transcription-drift-sync-target-make-check-doc-sync` from `backlog` to `review` | Story 14.5 dev-pass complete; all 9 ACs PASS; awaiting code-review pass. |
| 2026-05-08 | **/CR fix-pass corrections** (post-/CR adversarial review): script regex widened to handle 4-component citations (`Story X.Y.Z.W`, `§N.M.K.L`) — H1 + M1; architecture.md:598 reconciled `Story 11.5.1.2` → `Story 11.5.1` (the strict drift the regex bug had been hiding) per AC6(b) in-pass disposition; script refactored to read each input file exactly once (M4); README + script docstring updated to honestly document §-check whole-document scope (M3) and 4-component handling; Completion Notes corrected for sprint-status pre-state (was `backlog`, not `ready-for-dev` — M2) and Makefile target-body line range (was `:65..69`, actual `:64..69` — L1). | /CR adversarial review surfaced one HIGH (verdict-criterion bug masked genuine drift) + four MEDIUM + one LOW finding. All HIGH and MEDIUM closed in fix-pass; verdict re-confirmed as `[advisory] doc-sync: 18 advisory item(s); 0 drift`, exit 0, two-run determinism identical, now genuinely earned. |
