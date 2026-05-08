---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
classification:
  projectType: developer_tool_embedded
  domain: general
  complexity: low
  projectContext: brownfield
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-05-08.md
  - _bmad-output/planning-artifacts/prd-phase2-epics-9-13.5.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md
  - docs/PHASE-3-CARRY-FORWARD.md
  - docs/antforth-banking-design.md
  - docs/WISHLIST.md
  - docs/ans-forth-core-compliance.md
  - docs/z80-instruction-coverage.md
  - docs/z80-instruction-coverage-reaudit.md
  - docs/z80_forth_assemblers.md
  - docs/shadow-register-survey.md
  - docs/shadow-register-followup-survey.md
  - docs/register-conventions.md
  - docs/throw-codes.md
documentCounts:
  briefCount: 1
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 14
workflowType: 'prd'
---

# Product Requirements Document - antforth

**Author:** Ant
**Date:** 2026-05-08

## Executive Summary

antforth is an ANS-compliant Forth interpreter and interactive development environment built from scratch in Z80 assembly for the MicroBeast retrocomputer (8 MHz Z80, 512K banked RAM/ROM, CP/M 2.2). **antforth 2.0 shipped 2026-05-07** (git tag `v2.0.0` on commit `6599d73`) — kernel, REPL, language-extension compiler, built-in Z80 assembler, MARKER, full ANS Forth Core wordset (with §-level back-fills), Exception subsystem (CATCH/THROW with all internal error paths migrated), Search-Order wordset (multi-vocabulary), File-Access wordset against CP/M 2.2 hardware, and the Epic 13.5 process-recovery cleanup slate are all operational and exercised on real MicroBeast hardware.

This PRD scopes **Phase 3** — a **debt-cleanup interlude** dedicated to clearing accumulated technical debt and closing standards-compliance gaps before any net-new feature work begins. Like Epic 13.5 within Phase 2, Phase 3 is an interlude: zero new feature scope, no new user-facing words (except possibly back-fills surfaced by the §-by-§ audit), all effort directed at making the v2.0 foundation production-defensible at the §-level.

The phase is structured as **one or more "debt-cleanup" epics** drawn from the prioritised carry-forward catalogue (`docs/PHASE-3-CARRY-FORWARD.md`, authored 2026-05-07): 12 P1 items split across two categories — Standards/Compliance (A.1–A.3) and Stabilisation/Process Debt (B.1–B.9). Intermediate releases tag as **antforth 2.x**. The phase concludes when the P1 carry-forward catalogue is closed and the §-by-§ ANS Forth Core + Core-Extension audit is complete.

The two phase-defining goals are mutually reinforcing:

1. **§-level standards-compliance defensibility** — replace word-counted compliance claims with §-by-§ verified ones (the framework that caught two §-level blindspots mid-Epic-13 applied systematically across DPANS94 + Forth 2014)
2. **Story-template / process-discipline cleanup landed before the next feature epic** — B.1–B.5 lead-in shapes every subsequent dev-pass; future feature epics inherit improved discipline rather than re-discovering Epic 13.5's six lessons

The phase ships when the Phase-3 carry-forward catalogue's P1 items are closed, the §-level standards-compliance audit completes, all 11+ standing process commitments (S1–S12) continue to hold, the 973 PASS / 0 FAIL test baseline is maintained or extended, and hardware smoke continues clean on real CP/M 2.2 / MicroBeast.

### What Makes This Special

Three things distinguish this phase from a typical "we'll get to the debt eventually" approach:

- **Debt cleanup is a first-class phase, not a sidecar.** Epic 13.5 prototyped this pattern within Phase 2 (process-recovery vehicle gating v2.0.0); Phase 3 promotes it to a whole phase. Project-lead direction at the Epic 13.5 retro: *"I am trying to clear the decks of baggage, before we embark on new features."* The economic case: debt cleanup costs less between major versions (no release pressure) and prevents debt from becoming feature-blocking once Phase 4 starts.
- **§-by-§ audit replaces word-counted compliance.** Epic 10's "100% Core" claim was structurally word-counted, not §-counted; Stories 13.0 and 13.0.1 had to back-fill two §-level structural-rule gaps (§3.4.1.3 dot-marker, §3.1.4.1 high-on-TOS double-cell) the survey was structurally blind to. Phase 3's A.1 strategic body builds the audit framework that would have caught those at Epic 10, applied across the entire Core + Core-Extension specification.
- **Process improvements ship as concretely as defect closures.** B.1–B.5 are story-template / drafting-checklist edits that shape every subsequent dev-pass; the phase delivers them as proper stories with verdict criteria, not as parenthetical notes. The discipline doesn't scale down with the size of the fix — Story 13.5.3 retired the prototypical S8/Lesson-13-B example with a 2-byte fix, but the AC catalogue, kernel-dependency negative-result confirmation, four new probes, and hardware smoke around those two bytes were the heavyweight part. Phase 3 stories will repeat this shape.

The north-star acceptance criterion — *"AntForth's standards-compliance claims are §-level defensible, not word-counted"* — directly extends the project-lead verdict at the Epic 13.5 retro: *"AntForth feels more stable, and more 'defensible' from a standards point of view."*

## Project Classification

- **Project Type:** `developer_tool_embedded` — a programming-language implementation (Forth, a developer tool) targeting embedded 8-bit hardware (MicroBeast Z80 retrocomputer + CP/M 2.2). Generic SDK signals (package managers, IDE integration, OTA updates) do not apply: the `.COM` file IS the package, the REPL IS the IDE, updates are delivered by copying a new `.COM` file to a CP/M drive.
- **Domain:** `general` — hobbyist / retrocomputing personal-learning project. No regulated industry, no external compliance regime; the ANS Forth 1994 / Forth 2014 standards are voluntary self-discipline targets, not external-compliance requirements.
- **Complexity:** `low` — single-developer, well-understood scope, no novel-technology risk, no external-stakeholder dependencies, no deadline pressure. Technical intricacy lives in Z80 assembly minutiae, not systemic complexity. Phase 3 specifically lowers complexity further than Phase 2 did: no new subsystems, no new user-facing surface (with the possible exception of §-level back-fill words surfaced by A.1), all work directed at hardening existing subsystems.
- **Project Context:** `brownfield` — Phase 1 (Epics 1–8) and Phase 2 (Epics 9–13.5) shipped; v2.0.0 tagged 2026-05-07 on commit `6599d73`. This PRD scopes Phase 3 — a second debt-cleanup interlude (Epic 13.5 was the first, mid-Phase-2) — building on the v2.0 foundation with strict regression discipline (973 PASS / 0 FAIL baseline; zero regressions on 1..952 baseline; per-story hardware-smoke discipline per S9).

## Success Criteria

### User Success

Phase 3 is a debt-cleanup interlude — its user-facing wins are *defensibility* and *non-regression* rather than new capability.

**For "The OG" (experienced retrocomputing enthusiast):**

- All v2.0 user-visible behaviour continues to work identically — REPL, colon definitions, CATCH/THROW, multi-vocabulary, INCLUDE / SAVE-SOURCE on B: ramdisk, the unchanged hard-coded Z80 assembler. Zero regressions on the 1..952 baseline; the 21 cleanup-slate probes (944..964) all continue to pass; any new probes added by Phase-3 stories pass.
- When the user looks at `docs/ans-forth-core-compliance.md` to check whether their Forth code's expectations are met, every mandatory §-level rule has its own row with verdict and source citation — not just word-by-word but rule-by-rule. The compliance claim is *checkable* against the standard text directly.
- Errors raised by the asm-error THROW codes (−258..−272) are catchable in user code via the standard `' WORD CATCH . CR` idiom — caught-form coverage gap (A.2) closes for the full current asm-error block.
- When the user has set an explicit `BASE` and types an unprefixed numeral, parsing is base-aware (A.3 — unprefixed `NUMBER?` base-specialization).

**For "The Newb" (newcomer to retrocomputing):**

- No user-visible behaviour changes. The phase preserves all v2.0 onboarding-friendly behaviour (numeric literal prefixes including `0x`, standardised THROW codes with descriptions, REPL survivability across errors).
- The §-by-§ audit's outputs (per-rule verdicts) become future-proof reference material for any beginner's-guide author (deferred to Phase 4+), even though the guide itself isn't drafted in Phase 3.

**For the Hardware / Peripheral Developer (secondary persona):**

- Disk-full / directory-full / zero-byte READ-FILE failure modes (B.7) raise specific iors/THROWs and leave the filesystem in a consistent state — the NFR8 stress-matrix gaps closed if hardware reveals issues.
- `make check-tools` (B.6) confirms the iz-cpm version the build was tested against — so a contributor on a different host can reproduce the test baseline confidently.

### Business Success

N/A — antforth is a hobby / learning project with no commercial objectives. Equivalent non-commercial framing for Phase 3:

- **Community signal continuity:** the v2.0 launch's "mild interest" baseline is held or extended through the Phase-3 maintenance window. No specific user-facing release-publicity is in scope (Phase 3 is debt cleanup, not feature work) but Phase-3 antforth 2.x point-releases are tagged and announced where interest already exists.
- **External-visibility credibility:** the README's "100% ANS Forth Core compliant" claim becomes §-level defensible — backed by `docs/ans-forth-core-compliance.md`'s per-rule rows rather than a word-count survey. When a community member or fellow Forth implementor inspects the compliance claim, the supporting evidence is checkable line-by-line against DPANS94 + Forth 2014.
- **Foundation laid for Phase 4 (the next feature phase):** the story-template / process-discipline cluster (B.1–B.5) lands before Phase 4 epic-drafting begins. Phase 4 stories inherit the improved discipline rather than re-discovering the Epic 13.5 retro's six lessons. Strategic Phase-4 candidate (per the brief): banked RAM awareness — the enabler for everything past the ~25 KB binary ceiling.

### Technical Success

All items below are hard, verifiable acceptance criteria for the phase.

**Standards / Compliance:**

- **A.1 §-by-§ audit complete** — `docs/ans-forth-core-compliance.md` carries §-level rows for every mandatory rule in DPANS94 §6.1 (Core) and §6.2 (Core Extension), plus structural §-rules (§3.1.4.1 double-cell stack-layout, §3.4.1.3 numeric-literal parser rule, plus any others the systematic walk surfaces). Any §-level structural-rule gaps surfaced are back-filled with focused stories (mirroring the Stories 13.0 / 13.0.1 / 13.5 back-fill template — one story per gap, paired with a compliance-doc row addition) or explicitly accepted-with-rationale per project-lead approval (per `feedback_no_preexisting_discharge.md`, correctness defects must be closed, not rationalised).
- **A.2 caught-form coverage gap** — `tests/throw_migration_tests.fth` (or equivalent harness) exercises the caught-form path (`' WORD CATCH . CR` idiom) for each asm-error THROW code in the current `-258..-272` block (extends the carry-forward catalogue's original `-258..-269` framing to cover the post-Story-11.5.6 split codes `-270`/`-271`/`-272`). Each migration's caught-form path produces the expected THROW code on the data stack.
- **A.3 unprefixed `NUMBER?` base-specialization** — when an explicit `BASE` is set, unprefixed numerals parse per that base. REPL probe verifies in HEX, DECIMAL, and a non-default base.

**Stabilisation / Process Debt:**

- **B.1 PAD documented as canonical transient-buffer word for test authors** — `tests/README.md` (or equivalent inline header in `Makefile`'s test section) carries the convention block. Closes the long-overdue Epic-12 retro Action Item A1 (TIB-128 doc note) belatedly, now that the Story-13.5.4 real `PAD` exists.
- **B.2 "mirrors prior arm" HALT signal** — story-template / drafting-checklist edited to require the drafter to *count the parts* of a new arm independently when byte-budget rationale rests on "this mirrors arm X from Story Y". Extends Lesson 13-C into Lesson 13.5-C.
- **B.3 story-to-story binary handoff** — story-template "Pre-edit baseline" task captures `wc -c` itself, not the prior story's reported number. Closes the 6-byte 13.5.5-close-out-doc drift discipline gap.
- **B.4 PD-2 story-drafter figure drift** — story-template / process edit landed before any Phase-3 story-drafting starts. Sibling of B.2 and B.3 — these three together are the story-template-discipline cluster.
- **B.5 PD-3 PRD-vs-architecture transcription drift fix** — process / Makefile target landed before any future PRD/Architecture refresh — i.e., applied to *this* PRD's relationship with the next-revised architecture document.
- **B.6 PD-6 iz-cpm version stability** — `make check-tools` target landed; `make test-repl` verifies the iz-cpm version against a known-good baseline.
- **B.7 F-7 NFR8 stress-matrix coverage gaps** — directory-full and zero-byte READ-FILE probe coverage added to `tests/file_access_tests.fth` (or equivalent). Conditional on hardware-revealed issues; a hardware run that surfaces no new failures qualifies as "B.7 evaluated, none required".
- **B.8 test-numbering hygiene** — Makefile duplicate test numbers (from Story 11.3) renumbered on next Makefile-touching story.
- **B.9 disk-full hardware re-verification** — disk-full failure-mode probe runs cleanly on real CP/M 2.2 / MicroBeast.

**Standing-commitment hold (S1–S12):** all 12 prior standing process commitments continue to hold across every Phase-3 epic:
- S1 adversarial review fresh-context CR (post-PD-1 structural close)
- S2 REPL-piped tests as default
- S3 real-byte-count estimation + capstone-aware drafting (extended by B.2/B.4)
- S4 AC-composition validation
- S5 PARTIAL → HALT
- S6 inventory grep covers helpers, not just leaves
- S7 EXX-hygiene per kernel-internal raise site
- S8 "pre-existing" cannot discharge correctness defects
- S9 mid-epic hardware-smoke cadence per story
- S10 workflow > memory > prompt
- S11 user-visible version surface audit row at any tag-applicable epic close-out
- S12 hardware-typed probe authoring discipline (word-existence pre-flight + TIB-128 line-length lint)

**Regression / hardware:**

- Existing test suites continue to pass — 973 PASS / 0 FAIL baseline maintained or extended across every Phase-3 close-out; zero regressions on 1..952 baseline (and zero on 944..964 cleanup-slate probes).
- Mid-epic hardware-smoke per story (S9): every binary-delta Phase-3 story runs its own hardware-smoke task with PASS verdict. Zero-binary-delta stories document S9 exemption explicitly.
- Hardware smoke continues clean on real CP/M 2.2 / MicroBeast for any binary-delta story.
- Phase-3 cumulative ROM delta is small — Phase 3 is debt discharge, not feature work. Net-positive byte delta should be modest (estimate +0..+200 bytes for the catalogue close-out, dominated by any §-level back-fill stories surfaced by A.1).

### Measurable Outcomes

| Indicator | v2.0 baseline (post-Epic-13.5) | Phase 3 target |
|---|---|---|
| Binary size (`antforth.com`) | 24,996 bytes | ≤ 25,200 bytes (envelope: +200; A.1 back-fill stories may absorb most of the budget) |
| `make test-repl` passing | 973 PASS / 0 FAIL | ≥ 973 PASS / 0 FAIL (additional Phase-3 probes welcome; zero regressions) |
| §-by-§ ANS Core + Core-Ext audit | Not started (5 §-level rules covered: §3.1.4.1, §3.4.1.3 + ad-hoc §6.1.0310/0350/0090) | Complete; per-rule rows in `docs/ans-forth-core-compliance.md` |
| §-level back-fill stories surfaced by A.1 | 2 historical (Stories 13.0, 13.0.1) | 0–2 expected; each closed by a focused story or explicitly accepted-with-rationale |
| Phase-3 carry-forward catalogue P1 items closed | 0 of 12 | 12 of 12 (or explicitly re-prioritised down with project-lead approval) |
| Standing process commitments continuing to hold | S1–S12 (post-Epic-13.5) | S1–S12 across every Phase-3 epic close-out |
| Hardware smoke on real CP/M 2.2 / MicroBeast | Clean (Epic 13.5.6 close-out) | Clean for every binary-delta story (S9) |
| Tag-applicable close-out version-surface audit (S11) | Held at v2.0.0 (post-bump) | Held at every Phase-3 antforth 2.x point-release |
| External users | 0 (mild interest observed) | ≥ 0 (Phase 3 has no adoption-growth target — hold mild-interest baseline through the maintenance window) |

## Product Scope

### MVP — Minimum Viable Product

The **Phase-3 close-out** (final antforth 2.x point-release tag) is the MVP for this phase. It ships when ALL of the following hold:

- All 12 P1 items in `docs/PHASE-3-CARRY-FORWARD.md` are closed (or explicitly re-prioritised down with project-lead approval, per `feedback_no_preexisting_discharge.md`)
- §-by-§ ANS Forth Core + Core-Extension audit complete; any §-level structural-rule gaps surfaced are back-filled with focused stories
- Story-template / drafting-discipline cluster (B.1–B.5) landed before any net-new feature epic begins
- All standing process commitments S1–S12 continue to hold across every Phase-3 epic close-out
- 973 PASS / 0 FAIL test baseline maintained or extended; zero regressions on 1..952 + 944..964 baseline
- Hardware smoke continues clean on real CP/M 2.2 / MicroBeast for every binary-delta story
- Cumulative ROM delta within +0..+200 bytes (dominated by any §-level back-fill stories)
- Tag-applicable close-out passes the S11 user-visible version-surface audit (banner / README / memory-file `description` fields aligned to the new 2.x version)

**Phase-3 epic decomposition (suggested, per `docs/PHASE-3-CARRY-FORWARD.md` § "Suggested Phase-3 First-Epic Shape"):**

- **Lead-in (must land first):** B.1 + B.2 + B.3 + B.4 + B.5 — story-template / process-discipline edits that shape every subsequent dev-pass in the phase
- **Strategic body:** A.1 §-by-§ Core + Core-Extension re-audit — one audit story; 0–2 back-fill stories per gap surfaced
- **Hitch-hikers (fold opportunistically):** A.2, A.3, B.6, B.8, B.9 fold into appropriate stories opportunistically (any THROW-test-touching sprint, any number-parsing sprint, any tooling sprint, next Makefile-touching story, any hardware-touching story respectively)
- **Conditional:** B.7 if hardware-revealed issues surface; otherwise 2.x maintenance candidate

The exact epic decomposition (one large epic vs multiple smaller epics; specific story sequencing within an epic) will be pinned down in the epics document that follows this PRD.

**Partial delivery is a legitimate antforth 2.x point-release** but does not constitute Phase-3 close-out. The phase is defined by the full P1-catalogue + §-by-§ audit completion.

### Growth Features (Post-MVP — Phase 4 candidates)

Phase 4 is the **first feature phase since v2.0** and is unscoped at this PRD's writing — to be defined when Phase 3 closes. Candidate themes (drawn from `docs/PHASE-3-CARRY-FORWARD.md` category E and `docs/WISHLIST.md`), in rough order of strategic interest:

- **Banked RAM awareness** — the strategic enabler. Available user RAM is getting tight as antforth grows; the banking design (`docs/antforth-banking-design.md`) proposes bank swapping (3 fixed pages + 1 swappable user-bank slot mapping 11 banks × 16 KB = 176 KB user workspace) to make more memory available to users without sacrificing the core wordset or built-in assembler. Likely the first Phase-4 epic.
- **STARTUP.FTH** — small but high-value affordance: a file that, if present, runs at startup before the interactive REPL. Allows loading custom wordlists, beginner-friendly setup, etc.
- **MicroBeast hardware vocabulary** — system timer ISR, GPIO, 24×14-segment LED matrix, beeper, UART, I²C, memory-banking control, RTC. Strong fit with the multitasker via timer-driven `PAUSE`. Closes the gap between "antforth runs on MicroBeast" and "antforth makes the MicroBeast's hardware accessible".
- **`SEE` decompiler + `TRAVERSE-WORDLIST`** — makes the system self-inspectable; unlocks xref tools written in Forth itself.
- **Locals wordset** — `{: a b -- c :}` or `VALUE` / `TO`. Compiler surgery; ergonomic win for complex colon definitions.
- **Built-in `IN` / `OUT` primitives** — promotes commonly-used hardware-port access from user CODE words into kernel-level words.

### Vision (Future — Phase 5+)

Medium- and long-term platform evolution:

- **Cooperative multitasker** — PAUSE-based yield, `TASK` / `ACTIVATE`, `KEY`-hooked REPL multitasking, timer-ISR integration. Significant subsystem.
- **Semaphores** — `SIGNAL` / `WAIT`, mutexes, mailbox primitives for cooperating tasks.
- **VideoBeast support** — sprite manipulation, graphics primitives. Depends on VideoBeast hardware availability.
- **AudioBeast support** — instrument definition, sound-generation vocabulary. Depends on AudioBeast hardware availability.
- **Float wordset** — significant size and complexity.
- **Compilation to standalone `.com` binary** — tree-shaken Forth apps without the outer interpreter; standalone deliverables for the wider MicroBeast and CP/M communities. Architecturally interesting; shifts antforth's product positioning.
- **Object orientation** — after study of Pountain's book (acquired) and the NEON / Yerk / FOBJ literature.
- **User-facing documentation epic** — beginner's guide, per-wordset reference, worked examples. Now justified by a stable feature surface.
- **Portability epic** — second Z80 retrocomputer platform port. Validates the design's inherent portability.
- **Community word library sharing** — the ecosystem begins to form.

**Phase 3 deliberately defers all of the above.** Rationale (per project-lead direction at the Epic 13.5 retro): every feature epic adds new debt; Phase 3 exists to keep the ratio honest. Rejected during Phase 2: ASSEMBLER.FTH, ASSEMBLER wordlist auto-activation (per `project_assembler_keep_assembly.md` — `src/assembler.asm` stays kernel-resident hard-coded). Permanently deferred (P3 in carry-forward): `make bench` infrastructure, DMA pool size-reduction, `.S` migration to pictured output, MARKER full-graph snapshot, WORDS scope-pick — all unblock only on a specific trigger (ROM pressure or perf-claim dispute).

## User Journeys

### Scope Note on User Types

antforth is a **single-user interactive REPL** running on personal retrocomputer hardware. There is no network surface, no multi-tenant model, no authentication, no API layer. The traditional PRD categories of *admin*, *support*, *moderator*, and *API consumer* do not apply — the user **is** the admin of their own machine.

For Phase 3 specifically — a debt-cleanup interlude with no net-new user-facing features — the journeys covered below show the two primary personas from the 2026-05-08 product brief ("The OG" and "The Newb") in **non-regression / increased-trust** flows, the secondary Hardware/Peripheral Developer persona in a **previously-broken-path-now-works** flow, plus a Phase-3-specific persona — the **future Forth implementor / community auditor** — whose primary interaction is with `docs/ans-forth-core-compliance.md` rather than the running interpreter. There is also a Phase-3-internal "user": the project lead (Ant) authoring stories under the post-B.1–B.5 story-template discipline.

This is the full human-interaction surface of the product through the Phase-3 maintenance window.

### Journey 1 — Mo's Quiet Tuesday Afternoon (OG, happy path / non-regression)

**Opening scene.** Mo upgraded her MicroBeast's `ANTFORTH.COM` last week to the latest Phase-3 antforth 2.x release. Tuesday afternoon she boots into the REPL to continue work on her sprite-driver experiments. The banner reads `antforth 2.x — ok`. She INCLUDEs her work-in-progress driver from B: with `INCLUDE B:SPRITES.FTH`, expecting things to be exactly where she left them.

**Rising action.** They are. Every word she defined in 2.0 still works the same way in 2.x. `MARKER -OLD` still snapshots state. `CATCH` still wraps her experimental words. `WORDLIST` / `DEFINITIONS` still organise her sprite vocabulary separately from kernel words. `INCLUDE` still loads from B:; `SAVE-SOURCE` still writes back. Her CODE words assemble byte-identical against the same hard-coded inline assembler. The 21 cleanup-slate probes the upgrade brought in (944..964) didn't break anything she relied on — and the 952-baseline tests she's heard about all still pass in her own sanity check (`make test-repl`).

**Climax.** She doesn't notice anything has changed. That *is* the climax. The upgrade is invisible to her workflow.

**Resolution.** Later that evening, as she's writing a forum post about a clever trick she found, she happens to link to `docs/ans-forth-core-compliance.md` to cite that antforth's `M*` / `UM*` / `SM/REM` / `FM/MOD` behaviour matches DPANS94 §6.1. The doc now has §-level rows for every mandatory Core + Core-Extension rule (A.1's outputs). She doesn't have to caveat the link. The compliance claim is *checkable* line-by-line — a small but meaningful upgrade in how she thinks about antforth's standing.

**Requirements surfaced:** Phase-3 regression baseline (973 PASS / 0 FAIL maintained, S9 hardware-smoke per binary-delta story), A.1 §-by-§ audit complete with per-rule rows in `docs/ans-forth-core-compliance.md`, all v2.0 functional behaviour preserved (FR45-equivalent constraint).

### Journey 2 — Mo Catches an Asm Error That Used To Crash Her Session (OG, caught-form closure)

**Opening scene.** Mo is iterating on a CODE word that does block-copy of palette data. She accidentally writes `(IX) +D` without the displacement byte first — `+D` consumes its operand from the stack, gets a tag mismatch with `(IX)`, raises `-271 THROW_ASM_DISP_RANGE`. On v2.0 this would print `error -271: disp range` and (because the asm-error caught-form path was incomplete — A.2 in the carry-forward) sometimes interact awkwardly when wrapped in `' WORD CATCH . CR`.

**Rising action.** Post-A.2 (Phase 3), Mo writes a defensive shell around her experimental CODE word: `: TRY-PAL  ['] PAL-COPY CATCH ?DUP IF ." asm error " . CR THEN ;`. She runs `TRY-PAL`. Instead of an awkward print or an unwound state, she sees `asm error -271 ok` cleanly. `WORDS` still works. Her dictionary is intact. She fixes the displacement, re-runs `TRY-PAL`, gets `ok`.

**Climax.** Caught-form THROW now works for the full `-258..-272` asm-error block exactly the way it works for ANS-standard codes like `-4` (stack underflow) or `-13` (undefined word). Mo can write defensive harnesses around her experimental CODE words without the THROW system having a known asym between asm-error codes and standard codes.

**Resolution.** She mentally upgrades her trust in `CATCH` from "works for standard codes; iffy for asm errors" to "works for everything the kernel raises". The asym is closed.

**Requirements surfaced:** A.2 caught-form coverage gap closed for asm-error THROW codes -258..-272; FR16 (CATCH frame), FR17 (THROW), FR21/FR22 (REPL survives any THROW) continue to hold across the asm-error code block.

### Journey 3 — Raj Doesn't Trip on HEX Mode Confusion (Newb, base-aware parse)

**Opening scene.** Raj is following a community-authored beginner's guide that walks through experimenting with the 14-segment LED display via direct port writes. The guide says "set HEX mode and try `0xFF P!`." Raj types `HEX` and then experimentally types `255 .` — partly to check that decimal still displays correctly. On pre-A.3 antforth, he'd see `FF` (255 reinterpreted as hex 255 → output FF). Confusing.

**Rising action.** Post-A.3, antforth's unprefixed `NUMBER?` is now base-aware in the way Raj expects: the explicit `BASE` setting governs unprefixed numerals consistently. Raj sees output that matches the base he set — the typing and the display agree. He goes back to `0xFF P!` (his Forth-2014-prefixed literal, which is *always* hex regardless of BASE per FR9), gets the LED segment he expected, moves on.

**Climax.** The "wait, why is decimal showing as hex?" moment that used to derail beginners doesn't happen.

**Resolution.** Raj never even notices the gotcha was there. The kindest UX upgrades are the ones that prevent confusion that would have happened.

**Requirements surfaced:** A.3 unprefixed `NUMBER?` base-specialization; existing FR1–FR9 (Forth-2014 numeric literal prefixes including `0x`) continue to hold (prefixed literals still always parse in their declared base regardless of BASE).

### Journey 4 — Pete Stress-Tests an Edge Case That Used To Be Quiet (Hardware/Peripheral Developer, B.7 stress-matrix)

**Opening scene.** Pete is bench-testing a new hardware variant that interacts with file I/O. He fills the B: ramdisk to capacity, then deliberately exercises an edge case: trying to `WRITE-FILE` past the disk-full boundary. On pre-B.7 antforth there was no specific probe coverage for the directory-full and zero-byte-`READ-FILE` failure modes — they worked, but no test exercised them.

**Rising action.** Pete wraps his write in `' MY-WRITE CATCH ?DUP IF ." disk error " . CR THEN`. The `WRITE-FILE` returns a specific non-zero `ior`; the FCB pool stays consistent (no orphaned handles per NFR8 / B.7); the filesystem itself stays in a consistent state on real CP/M 2.2 hardware. Pete sees `disk error 8 ok` (ior = 8 — disk full). His kernel wasn't corrupted by the failed write.

**Climax.** The B.7 probe coverage that landed mid-Phase-3 (or was confirmed-not-needed by hardware run) means Pete can rely on documented failure-mode behaviour. He posts on the MicroBeast Discord: "B: ramdisk-full handling on antforth 2.x is clean — write returns ior, FCB pool stays sane, no need to defensive-CLOSE-FILE everything."

**Resolution.** A previously-untested failure-mode corner moves into "tested and documented" status. Pete validates one more variant and ships his hardware design.

**Requirements surfaced:** B.7 NFR8 stress-matrix coverage gaps (directory-full, zero-byte READ-FILE); existing FR43 (file errors raise THROW or ior) and NFR8 (filesystem error recovery) continue to hold across the new probe coverage; B.9 disk-full hardware re-verification on real CP/M 2.2 / MicroBeast.

### Journey 5 — Hana the Forth Auditor Reviews antforth's Compliance Claim (Phase-3-specific: external implementor / auditor)

**Opening scene.** Hana is implementing a new Forth on a different Z80-class board and is surveying existing implementations' compliance claims to inform her own. She browses to antforth's GitHub repo, sees the README's "100% ANS Forth Core compliant" claim, and clicks through to `docs/ans-forth-core-compliance.md`.

**Rising action.** Pre-A.1 (so: pre-Phase-3) she would have found a word-by-word table of §6.1 Core — adequate but not §-level granular. She might have wondered whether the structural §-rules (§3.1.4.1 double-cell stack-layout, §3.4.1.3 numeric-literal parser rule) were verified or just assumed. Post-A.1 she finds the document carrying §-level rows for every mandatory rule in DPANS94 §6.1 and §6.2, plus the structural §-rules. Each row cites its §-number, source file:line for the implementation, story-number for the closure, and any caveats (e.g., antforth-implementation-limit asterisks).

**Climax.** Hana can verify antforth's compliance claim *against the standard text* in an afternoon, line-by-line. She doesn't have to take the README's word for it. She's now considering antforth as a reference implementation she'll cross-check her own implementation against.

**Resolution.** External-visibility credibility moves from "antforth says it's compliant; here's a word-count" to "antforth's compliance claim is checkable rule-by-rule against the standard". Hana might or might not reach out to the project — but the next time someone in the Forth-implementor community asks "is antforth standards-compliant?", she has a concrete answer to point at.

**Requirements surfaced:** A.1 §-by-§ ANS Forth Core + Core-Extension audit complete with per-rule rows in `docs/ans-forth-core-compliance.md`; documentation discipline (per-rule citations of §-number, source, story-closure, caveats) preserved across rows.

### Journey 6 — Ant Authors a Phase-3 Story Under the New Discipline (Project Lead — internal user)

**Opening scene.** Ant sits down to draft a new Phase-3 story — let's say it's the §-by-§ Core + Core-Extension audit story (A.1 strategic body). The story-template he uses has been updated: B.1 added a `PAD` reference for transient-buffer test authoring, B.2 added a "mirrors prior arm" HALT trigger to the byte-budget rationale, B.3 added a re-`wc -c` task to the Pre-edit baseline checklist, B.4 added the figure-drift discipline, B.5 added the PRD-vs-architecture transcription-drift sync step.

**Rising action.** Halfway through drafting, Ant types something like *"the audit story's byte budget mirrors the closure shape from Story 13.5.6"*. The B.2 template lint catches the "mirrors" word and surfaces a HALT signal: *"This story claims its byte budget mirrors a prior arm — count the parts of THIS story's arm independently before accepting that estimate."* Ant pauses, decomposes the new story's actual structure, finds it's larger than the mirror analogy admitted, and rewrites the byte-budget rationale around the actual decomposition.

**Climax.** The discipline catches the calibration miss *before* the dev-pass starts. The TD-7 "mirrors prior arm" shorthand that overshot Story 13.5.5 by 40 bytes (Lesson 13.5-C from the Epic 13.5 retro) is structurally prevented from recurring — not by trying harder, but by the template lint.

**Resolution.** Ant ships the story with a calibrated byte budget. The dev-pass runs cleanly within its envelope. The standing-commitment S3 (real-byte-count estimation + capstone-aware drafting) holds with a smaller-than-Phase-2 wobble distribution. Future stories inherit the same discipline.

**Requirements surfaced:** B.1 PAD documentation, B.2 "mirrors prior arm" HALT signal, B.3 story-to-story binary handoff, B.4 PD-2 figure-drift, B.5 PD-3 PRD-vs-architecture transcription-drift; standing commitments S3 (byte-budget calibration), S5 (PARTIAL→HALT), S10 (workflow > memory > prompt) continue to hold.

### Journey Requirements Summary

The six journeys above collectively surface the following PRD-level capability requirements (functional and non-functional both):

| Capability | J1 | J2 | J3 | J4 | J5 | J6 | Carry-Forward Item |
|---|---|---|---|---|---|---|---|
| §-by-§ ANS Core + Core-Ext audit complete | ✓ |  |  |  | ✓ |  | A.1 |
| Caught-form coverage for asm-error THROW (-258..-272) |  | ✓ |  |  |  |  | A.2 |
| Unprefixed `NUMBER?` base-aware parsing |  |  | ✓ |  |  |  | A.3 |
| `PAD` documented as canonical transient-buffer for tests |  |  |  |  |  | ✓ | B.1 |
| Story-template "mirrors prior arm" HALT signal |  |  |  |  |  | ✓ | B.2 |
| Story-template re-`wc -c` baseline discipline |  |  |  |  |  | ✓ | B.3 |
| PD-2 story-drafter figure-drift fix |  |  |  |  |  | ✓ | B.4 |
| PD-3 PRD-vs-architecture transcription-drift sync |  |  |  |  |  | ✓ | B.5 |
| `make check-tools` (iz-cpm version stability) |  |  |  |  |  | ✓ | B.6 |
| NFR8 stress-matrix probe coverage (dir-full, 0-byte READ-FILE) |  |  |  | ✓ |  |  | B.7 |
| Test-numbering hygiene (Makefile renumber) |  |  |  |  |  |  | B.8 (cosmetic) |
| Disk-full hardware re-verification on real CP/M 2.2 |  |  |  | ✓ |  |  | B.9 |
| All v2.0 functional behaviour preserved (regression) | ✓ | ✓ | ✓ | ✓ | ✓ |  | (NFR-level) |
| 973 PASS / 0 FAIL test baseline maintained | ✓ |  |  | ✓ |  |  | (NFR-level) |
| S9 hardware-smoke per binary-delta story | ✓ |  |  | ✓ |  | ✓ | (NFR-level / standing commitment) |
| S11 user-visible version-surface audit at tag close-out | ✓ |  |  |  |  |  | (NFR-level / standing commitment) |
| S12 hardware-typed probe authoring discipline |  |  |  | ✓ |  | ✓ | (NFR-level / standing commitment) |

Every Phase-3 carry-forward P1 item maps to at least one journey (B.8 is the cosmetic-only exception — Makefile test-numbering hygiene has no user-facing surface, so it doesn't generate a journey but is still in the catalogue). Every journey is supported by a coherent set of carry-forward items + standing commitments. **No orphan requirements; no uncovered users.**

## Developer-Tool-Embedded Requirements

antforth is a compound `developer_tool` (programming-language implementation) + `iot_embedded` (single-purpose 8-bit hardware platform). Most generic SDK questions (package managers, IDE integration, OTA updates) do not apply — the interpreter IS the package, the device IS the IDE, and updates are delivered by copying a new `.COM` file to the CP/M filesystem. The requirements below carry forward unchanged from the Phase-2 PRD with two Phase-3 deltas (sharper standards-compliance commitment at the §-level; no growth in the BDOS function allow-list); the rest are stable platform / runtime / distribution invariants.

### Project-Type Overview

antforth is distributed as a **CP/M 2.2 `.COM` executable** that runs on the MicroBeast Z80 retrocomputer. It is simultaneously (a) an implementation of the ANS Forth 1994 / Forth 2014 programming language and (b) a self-hosted interactive development environment. It has no external build chain, no package dependency graph, no network surface, and no multi-user runtime. The user installs by copying the `.COM` file to the CP/M A: (ROM) or B: (ramdisk) drive and runs it like any other CP/M program.

**Phase-3 framing:** Phase 3 ships antforth 2.x point-releases against this same shape. No platform changes, no runtime-model changes, no distribution changes. The phase exists to harden the v2.0 baseline at the §-level.

### Target Platform Requirements (unchanged from Phase 2)

- **CPU:** Zilog Z80 @ 8 MHz (MicroBeast spec). Z80 instruction-set compliance only — no Z80N, no eZ80, no Z180 extensions.
- **Memory:** 512 KB banked RAM/ROM, MicroBeast bank-switching scheme. antforth kernel + dictionary live in bank 0 under CP/M's TPA. **Phase-3 stays in bank 0** — banking is a Phase-4+ candidate (see `docs/antforth-banking-design.md`).
- **Host OS:** CP/M 2.2. All I/O (console, file system, drive select) is routed through BDOS calls; no direct hardware I/O beyond the BIOS-level abstractions CP/M provides. **Phase-3 doesn't introduce new BDOS calls** — the function allow-list (carried forward from NFR13) does not grow.
- **Storage:** A: (ROM filesystem, read-only practically) and B: (ramdisk, read-write) as the two canonical drives. Other CP/M drives are supported generically via BDOS but not specifically tested.
- **Terminal:** standard CP/M console (character I/O via BDOS functions 1, 2, 6, 9); no assumption of ANSI escape sequences, cursor addressing, or colour. Reaffirmed by NFR-equivalent in Phase-3 NFRs (carried forward from Phase-2 NFR19).
- **Display hardware (post-phase):** 24-character 14-segment LED displays on the MicroBeast. Not consumed by Phase 3; deferred to the Phase-4+ MicroBeast hardware vocabulary epic.

### Language / Standard Compliance (Phase-3 delta: §-level commitment)

- **Primary standard:** ANS Forth 1994 (ANSI X3.215-1994) — Core wordset to **100% coverage** (133/133 §6.1 words, achieved Story 10.9, refreshed 2026-04-24). **Phase-3 delta (A.1):** the compliance claim is upgraded from word-counted (post-Epic-10) to §-level — the §-by-§ audit walks every mandatory rule in §6.1 (Core) and §6.2 (Core Extension), backed by per-rule rows in `docs/ans-forth-core-compliance.md`. Any §-level structural-rule gaps surfaced are back-filled with focused stories (the Stories 13.0 / 13.0.1 / 13.5 template) or explicitly accepted-with-rationale per project-lead approval.
- **Secondary standard:** Forth 2014 — specifically §3.4.1.3 (numeric literal prefixes `#`/`$`/`%`/`'c'`, dot-marker double-cell parser rule), §3.1.4.1 (high-on-TOS double-cell stack-layout rule), §11.6 (File-Access wordset), §9.6.1 (Exception wordset). All adopted verbatim and shipped as part of v2.0; Phase 3 verifies §-level coverage of any other Forth 2014 sections antforth claims compliance with.
- **antforth extensions beyond standards:** `0x` hex-literal prefix (Epic 9), `INCLUDE-TOP` / `CATCH-TOP` USER-variable extensions (Epic 11/13), the asm-error THROW codes `-258..-272`. All clearly flagged in source per the established standards-citation comment convention (`; antforth extension <word> — <design reason>`, per CCD-3). Phase 3 doesn't add new extensions.
- **Word-set coverage within Core + selected wordsets (post-v2.0 baseline):** §6.1 Core = 100%; §6.2 Core Extension = 14/46 (selective); §8.6 Double-Number = 13/13; §9.6 Exception = full (CATCH/THROW + standard codes); §11.6 File-Access = full user-facing surface; §16.6 Search-Order = full + ONLY (§16.6.2). Phase-3 delta: A.1 may surface 0–2 §-level back-fill candidates that lift §6.2 coverage by a few words; not a target in itself but a possible side-effect of the audit.
- **Standards-citation discipline (CCD-3):** continues to apply in Phase 3 — every word whose behaviour is specified by ANS / Forth-2014 carries a one-line citation comment in its assembly source (`; ANS Forth 1994 §<sec>` / `; Forth 2014 §<sec>` / `; antforth extension`). Any word touched by a Phase-3 story re-checks its citation comment; any §-level back-fill story adds the citation when the row lands.

### Installation & Distribution (unchanged from Phase 2)

- **Artifact:** single `.COM` file, Z80 machine code, assembled from the antforth source tree (`src/*.asm` via the project's existing build script). Phase-3 baseline: 24,996 bytes (post-Epic-13.5); target ≤ 25,200 bytes (envelope: +200; A.1 back-fill stories may absorb most of the budget).
- **Installation:** copy `ANTFORTH.COM` to a CP/M drive (A: ROM or B: ramdisk) via whatever file-transfer mechanism the user has available (serial transfer, EPROM programmer, SD-card adapter). Single-file install.
- **Update mechanism:** replace the `.COM` file. No in-place upgrade, no migration tooling. Because antforth's persistent state lives in user `.FTH` source files on disk (not in interpreter image state), sessions survive interpreter updates as long as the dictionary layout is compatible. Phase 3 does not change the dictionary layout.
- **Versioning:** semantic versioning. Phase-3 releases ship as **antforth 2.x** point-releases. The phase concludes when the carry-forward catalogue's P1 items close + §-by-§ audit completes; the close-out tag is the final 2.x version (e.g. 2.1.0 if Phase-3 is structured as one epic, or 2.x for higher x if multiple epics ship intermediate point-releases). **S11 standing commitment** ensures user-visible version surface (banner string in binary, README, memory-file `description` fields) is audited at every tag-applicable epic close-out.

### Runtime Model (unchanged from Phase 2)

- **Boot flow:** `.COM` loaded by CP/M → banner → REPL prompt. Assembler opcodes baked into the kernel dictionary, reachable from the global vocabulary. Unchanged across pre-2.0, 2.0, and 2.x; Phase 3 does not alter this. (Per `project_assembler_keep_assembly.md` — `src/assembler.asm` stays kernel-resident hard-coded; no ASSEMBLER wordlist, no `ASSEMBLER.FTH`, no auto-activation.)
- **Persistence:** user words live in RAM until the machine is powered off. Persistence across sessions is achieved by saving source to B: and `INCLUDE`-ing on next boot. There is no image-save mechanism; this is by design (keeps the source-of-truth in the user's files, not in the interpreter's state).
- **MARKER:** in-session rollback mechanism. Unchanged by Phase 3; documented scope-pick (linear dictionary snapshot, not full graph) preserved per `docs/PHASE-3-CARRY-FORWARD.md` D.3 (P3 deferred — re-evaluate only if a specific trigger fires).

### Explicitly Out of Scope for Project-Type Requirements (carried forward from Phase 2)

The following generic `developer_tool` and `iot_embedded` concerns are not applicable to antforth and will not be documented:

- **Package managers / dependency resolution** — antforth has no package ecosystem; the unit of sharing is a `.FTH` source file
- **IDE integration** — the REPL IS the IDE; syntax highlighting / completion are out of scope
- **OTA updates** — replace the `.COM` file; no over-the-air mechanism required or planned
- **Power management / sleep modes** — mains-powered retrocomputer, not battery-constrained
- **Network security** — no network surface on the platform
- **Multi-platform language-support matrix** — antforth targets Z80 + CP/M 2.2 specifically. Portability to a second Z80 retrocomputer platform is listed as a long-term Vision item but not in Phase 3's scope.
- **Visual design / store compliance / browser support** — explicitly skipped per CSV `skip_sections` for both `developer_tool` (`visual_design;store_compliance`) and `iot_embedded` (`visual_ui;browser_support`).

### Implementation Considerations (Phase-3-specific deltas)

- **Source-of-truth boundary:** kernel written in Z80 assembly (builds with the existing cross-assembler toolchain); a small handful of system words written in Forth and pre-compiled into the kernel image at build time. The boundary of what is kernel vs what is Forth source is **frozen for Phase 3** — no new Forth-source kernel additions, no new assembler-source kernel additions except those needed for §-level back-fills surfaced by A.1. (Phase-2 had moved a few capabilities across this boundary — Phase 3 holds the line.)
- **Test harness:** REPL-piped Forth test scripts (per established project testing convention since Epic 3, codified by standing commitment S2). Continues as the canonical test format for all new functionality and probe coverage in Phase 3. Probe authoring follows S12 (word-existence pre-flight + TIB-128 line-length lint for any hardware-typed smoke batch). PAD becomes the canonical transient-buffer word for test authors per B.1; this is documented in `tests/README.md` (or equivalent inline header in `Makefile`'s test section) before the next Phase-3 probe is authored.
- **Cross-tooling:** build and test happen on a modern host (iz-cpm emulator + cross-assembler); final validation happens on real MicroBeast hardware. Both surfaces must be exercised for any binary-delta story (S9 mid-epic hardware-smoke cadence). **Phase-3 delta:** B.6 adds `make check-tools` to verify the iz-cpm version against a known-good baseline before `make test-repl` runs — closing the iz-cpm version-stability gap.
- **ROM-size budget:** strict per-epic. Each Phase-3 epic logs its kernel-size delta and justifies any increase against the carry-forward item it discharges. Per-epic ROM-size budgets: B.1–B.5 are doc/template-only (zero binary delta); A.1 audit story is zero binary delta; A.1 back-fill stories (if surfaced) carry ~+10..+50 bytes each per the Story 13.0 / 13.0.1 / 13.5 precedent; A.2/A.3/B.6/B.8/B.9 carry minimal binary delta each (~0..+30 bytes); B.7 conditional on hardware-revealed issues. Cumulative phase target: +0..+200 bytes (24,996 → ≤ 25,200).
- **Story-template / drafting-discipline (Phase-3 lead-in B.1–B.5):** edited and committed before any non-lead-in Phase-3 story drafting begins. The improved discipline shapes every subsequent dev-pass in the phase. B.5 specifically applies to the Phase-3 PRD-vs-architecture relationship — i.e., this PRD's relationship with the next-revised architecture document.

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach: Debt-Cleanup Interlude (process-recovery vehicle).** Phase 3 is the second debt-cleanup interlude in the project's lifetime — Epic 13.5 was the first, mid-Phase-2, gating v2.0.0. Phase 3 promotes the pattern from "interlude epic within a feature phase" to "interlude phase between feature phases". Its job is *not* to deliver new capability; its job is to ship antforth 2.x point-releases that are §-level standards-defensible and process-discipline-improved, so Phase 4 (the next feature phase) starts against a clean baseline.

This is **not** a problem-validation MVP (the problem space is confirmed by the existing personas and the v2.0 ship). It is **not** a revenue MVP (no revenue). It is **not** an experience MVP (core UX shipped in v2.0). It is a **stabilisation MVP** — when Phase 3 closes, the project can claim "every standards-compliance assertion has §-level support" and "the story-template / drafting discipline that surfaced six lessons across Epic 13.5 has been structurally locked in" as unqualified facts.

**Resource Requirements:** single developer (Ant), supported by the BMAD agent workflow (PM, SM, Dev, QA, Architect agents) for planning, story authoring, dev execution, code review, and retrospective. No external dependencies, no contractor time, no third-party integrations to schedule. The Phase-3 work is dominated by:

- **B.1–B.5** — story-template / process-discipline edits (small individually; cluster together as the lead-in)
- **A.1** — the §-by-§ audit story (the single largest discrete piece of work in the phase)
- **0–2 back-fill stories per gap surfaced** by A.1 (each in the Story 13.0 / 13.0.1 / 13.5 shape)
- **A.2 / A.3 / B.6 / B.8 / B.9** — small standalone items, hitch-hiking on appropriate sprints
- **B.7** — conditional on hardware-revealed issues; small if not (or unstarted)

**Success Philosophy:** ship the carry-forward catalogue's P1 items in the order suggested by `docs/PHASE-3-CARRY-FORWARD.md` § "Suggested Phase-3 First-Epic Shape" (B.1–B.5 lead-in → A.1 strategic body → A.2/A.3/B.6/B.8/B.9 hitch-hikers → B.7 conditional). Intermediate antforth 2.x point-releases ship as the items close; the Phase-3 close-out tag (final 2.x version) is the acceptance signal. Partial delivery is a legitimate antforth 2.x point-release but does not constitute Phase-3 close-out — the phase is defined by the full P1-catalogue + §-by-§ audit completion.

### MVP Feature Set (Phase 1 — Phase-3 close-out)

**Core user journeys supported at Phase-3 close-out:**

- Journey 1 (Mo's Quiet Tuesday Afternoon — non-regression) — full support throughout the phase; gets the §-level compliance-doc upgrade after A.1
- Journey 2 (Mo Catches an Asm Error — caught-form closure) — full support after A.2 lands
- Journey 3 (Raj Doesn't Trip on HEX Mode Confusion — base-aware parse) — full support after A.3 lands
- Journey 4 (Pete Stress-Tests an Edge Case — B.7 stress-matrix) — full support after B.7 + B.9 land (or after B.7 evaluated as "no issues hardware-revealed, evaluation suffices")
- Journey 5 (Hana the Forth Auditor reviews antforth's compliance claim) — full support after A.1 lands; the strategic external-credibility win
- Journey 6 (Ant authors a Phase-3 story under the new discipline) — full support after B.1–B.5 land (the lead-in cluster)

**Must-have capabilities, grouped by suggested epic shape:**

| Phase-3 work item | Capability delivered | Sequencing rationale |
|---|---|---|
| **Lead-in: B.1 + B.2 + B.3 + B.4 + B.5** | Story-template / process-discipline cluster (PAD reference, "mirrors prior arm" HALT, re-`wc -c` baseline, PD-2 figure-drift, PD-3 PRD-vs-architecture sync) | First — these shape every subsequent dev-pass in the phase. Mostly small, doc/template-only, zero binary delta. The discipline they establish prevents recurrence of Epic-13.5's six lessons. |
| **Strategic body: A.1** | §-by-§ ANS Forth Core + Core-Extension audit; per-rule rows in `docs/ans-forth-core-compliance.md`; 0–2 back-fill stories per §-level structural-rule gap surfaced | Second — the audit story itself is doc-only (zero binary delta); back-fill stories carry small per-story binary deltas (~+10..+50 bytes each per Story 13.0 / 13.0.1 / 13.5 precedent). The strategic Phase-3 piece. |
| **Hitch-hikers: A.2 + A.3** | Caught-form coverage for asm-error THROW (-258..-272); unprefixed `NUMBER?` base-specialization | Folded onto sprints touching the relevant areas (THROW-test sprints, number-parsing sprints). Each ~+0..+30 bytes binary. |
| **Hitch-hikers: B.6 + B.8** | `make check-tools` (iz-cpm version stability); Makefile test-numbering hygiene | Folded onto any tooling/Makefile-touching sprint. Mostly tooling work, near-zero binary delta. |
| **Conditional: B.7** | NFR8 stress-matrix probe coverage (directory-full, zero-byte READ-FILE) | Conditional on hardware-revealed issues from B.9 / S9 hardware-smoke runs. If hardware reveals no issues, B.7 evaluation suffices and no story needed. |
| **Hitch-hiker: B.9** | Disk-full hardware re-verification on real CP/M 2.2 / MicroBeast | Folded onto any hardware-touching story (likely an A.1 back-fill story or an S9 hardware-smoke task). |
| **Phase-3 close-out gate** | Verdict-table walk + tag-applicable epic close-out audit (S11 user-visible version surface) + final hardware run | Mirrors Story 13.5.6 close-out gate shape. Audit-only Δ = 0. Tag applied on PASS verdict. |

**MVP rule (carried forward from Phase 2):** no story is considered done until its tests pass on real MicroBeast hardware (not just emulator) AND all prior stories' tests still pass. Regression is a blocker, not a deferrable. **Phase-3 specific:** the rule extends to standing-commitment hold — every Phase-3 story must demonstrate S1–S12 hold across its dev-pass.

### Post-MVP Features

**Phase 4 (post-Phase-3, near-term — first feature phase since v2.0):**

Unscoped at this PRD's writing — to be defined when Phase 3 closes. Strongest candidates (from `docs/PHASE-3-CARRY-FORWARD.md` category E and `docs/WISHLIST.md`):

- **Banked RAM awareness epic** — the strategic enabler. The banking design (`docs/antforth-banking-design.md`) proposes 3 fixed pages (CP/M + Core kernel, Assembler + Extended kernel, return stack/user area/system data) + 1 swappable user-bank slot ($8000–$BFFF) mapping 11 banks × 16 KB = 176 KB user workspace. Likely the first Phase-4 epic given the ~25 KB binary ceiling becomes a real constraint as antforth grows.
- **STARTUP.FTH** — small but high-value affordance: a file that, if present, runs at startup before the interactive REPL.
- **MicroBeast hardware vocabulary epic** — system timer ISR, GPIO, 24×14-segment LED matrix, beeper, UART, I²C, memory-banking control, RTC. Strong fit with the multitasker via timer-driven `PAUSE`.
- **`SEE` decompiler + `TRAVERSE-WORDLIST` epic** — makes the system self-inspectable; unlocks xref tools written in Forth itself.
- **Locals wordset** (`{: a b -- c :}` or `VALUE` / `TO`) — compiler surgery; ergonomic win.
- **Built-in `IN` / `OUT` primitives** — promotes hardware-port access from user CODE words into kernel-level words.

**Phase 5+ (long-term):**

- Cooperative multitasker (PAUSE-based yield, `TASK` / `ACTIVATE`, KEY-hooked REPL multitasking, timer-ISR integration)
- Semaphores (`SIGNAL` / `WAIT`)
- VideoBeast / AudioBeast support (depend on hardware availability)
- Float wordset
- Compilation to standalone `.com` binary (tree-shaken Forth apps)
- Object orientation (after Pountain study + NEON / Yerk / FOBJ literature)
- User-facing documentation (beginner's guide, per-wordset reference, worked examples)
- Portability to a second Z80 retrocomputer platform
- Community word library sharing

### Risk Mitigation Strategy

**Technical risks (Phase-3-specific):**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| A.1 §-by-§ audit surfaces more than 0–2 §-level structural-rule gaps; Phase 3 grows materially | Medium | Medium | A.1 audit story is a *survey first* (just walk the chapters and produce a row-per-rule table, marking PASS / GAP / N-A); back-fill stories are spawned per-gap as discrete sprints with their own envelopes. If the survey surfaces > 5 gaps, propose sprint-change with a re-prioritised cut (some gaps may be acceptable-with-rationale; some may be Phase-3-deferred to a Phase-3.5 micro-phase) |
| Back-fill stories carry larger byte deltas than the Story 13.0 / 13.0.1 / 13.5 precedent suggests | Low | Low | Per-story envelope checked against the +200-byte cumulative phase target; HALT signal if any single back-fill story would push cumulative over. Tightening individual back-fills to under-budget remains the primary path; cumulative-overrun proposals go through `bmad-bmm-correct-course` |
| Story-template lead-in (B.1–B.5) doesn't catch the discipline gaps it's meant to | Medium | Medium | The lead-in stories themselves carry verdict criteria that test whether the new template would have caught the prior incident (e.g., B.2 verdict criterion: "the new template's lint catches a synthesised 'mirror' phrase in a test story"; B.3 verdict criterion: "the new template's `wc -c` task captures the actual current binary, not the prior story's reported number"). If the lead-in fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration |
| B.7 hardware run reveals additional latent kernel bugs (beyond directory-full / zero-byte READ-FILE) | Low | Medium | Each newly-discovered defect spawned as its own focused story per `feedback_verdict_only_audit.md` (verdict-only audit story + standalone reproducer + fix-story spawned from verdict). Phase-3 envelope can absorb a small number of such spawns; a large number triggers sprint-change-proposal evaluation |
| The §-by-§ audit conflicts with project-lead preferred work cadence (the all-or-nothing audit may stall mid-walk) | Medium | Low | A.1 is decomposable: the per-rule rows are independent. The audit can proceed §-by-§ across multiple sittings without losing state. Each sub-survey commit lands an incremental compliance-doc update |
| B.5 PD-3 PRD-vs-architecture sync target uncovers more drift than expected | Low | Low | The sync step's first run produces a report; if drift exceeds expected, propose a focused PD-3 fix-story spawn rather than blocking on it |

**Market / adoption risks (Phase-3-specific):**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Phase-3 maintenance window (months of no-new-shiny) stalls or reverses the v2.0 mild-interest community signal | Medium | Low (hobby project, no revenue) | Phase-3 antforth 2.x point-releases are tagged and announced where interest already exists (forums / Discord). The narrative "antforth is now §-level standards-defensible" is itself a community-signal-positive announcement, even though no new feature ships. Hana-the-Forth-Auditor (Journey 5) is the audience for this — external Forth-implementor visibility moves up a step |
| MicroBeast platform itself loses community momentum during the Phase-3 maintenance window | Low | High (would cap antforth's reachable audience) | Outside the project's control; partially mitigated by designing for portability (Vision item) so antforth survives platform transitions |
| Project's lack of Phase-3 publicity (debt cleanup is unmarketable) reads as project death from outside | Low | Low | Each antforth 2.x point-release tag is a public artifact; the carry-forward catalogue's progressive close-out is visible in `docs/PHASE-3-CARRY-FORWARD.md`'s status-tracking table; commit history shows continuous progress. Anyone looking will see active development |

**Resource risks (Phase-3-specific):**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Developer (Ant) hits a burnout patch — debt-cleanup is unglamorous and lacks the dopamine of new-feature shipping | Medium | High | The phase is intentionally shaped as discrete antforth 2.x point-releases, each independently shippable. Velocity can flex to zero between point-releases without killing the project. Project-lead direction at the Epic 13.5 retro framed this as "clearing the decks of baggage" — internalised motivation for the work itself, not for a downstream payoff |
| "Just one more debt item" scope creep — Phase 3 never closes because the carry-forward catalogue keeps growing | Medium | Medium | The 12 P1 items are explicitly enumerated in `docs/PHASE-3-CARRY-FORWARD.md`; new items discovered mid-Phase-3 are added to the catalogue with their own priority but do not automatically extend the phase. Phase-3 close-out gate is the P1 set frozen at phase-start (post-A1 re-baseline 2026-05-07), not the P1 set as it stands at would-be close-out time. Project-lead approval required for any P1 set re-baselining mid-phase |
| Mid-Phase-3 the project lead becomes more interested in a Phase-4 candidate (e.g. banking) than in finishing Phase 3 | Medium | Medium | Phase-3 close-out is a project-lead-controlled decision; if the project lead wants to pivot to Phase 4 with some Phase-3 P1 items still open, those items are explicitly re-prioritised down (not silently dropped) per `feedback_no_preexisting_discharge.md`. The re-prioritisation conversation produces an updated `docs/PHASE-3-CARRY-FORWARD.md` and a documented decision in the project lead's retro / sprint-change-proposal |
| Story-template / discipline edits (B.1–B.5) introduce process drag that slows subsequent feature work | Low | Low | The lead-in stories are deliberately small; their template edits are *guards* (lints / HALT signals / pre-edit task additions), not workflow steps. They fire when they need to fire; they're invisible when they don't. If a future epic finds a B.1–B.5 edit creates measurable friction, it can be revised — the template is a living document |

**Phase-3-specific risk that didn't exist in Phase 2: standing-commitment regression.** Phase 2 ended with 12 standing commitments (S1–S12) holding across every retro. If a Phase-3 epic breaks one — say, an in-pass adversarial review re-emerges (S1 break), or a "pre-existing" verdict is allowed for a correctness defect (S8 break) — the impact is a regression in process maturity, not a kernel regression. **Mitigation:** every Phase-3 retro re-walks S1–S12 as it does today; any break is flagged in the retro and addressed in the next epic's lead-in.

## Functional Requirements

> **Capability contract notice.** This list defines the complete set of capabilities that Phase 3 must deliver. Downstream work (epics, stories, tests) will be authored against this list. Any capability not listed here will not exist in the final product unless explicitly added. **Phase 3 ships antforth 2.x point-releases**; these FRs are additive to the Phase-2 FR1–FR47 set carried into v2.0 (which continue to hold per FR-P3-22 below).

### Standards-Compliance Documentation (A.1)

- **FR-P3-1:** A reader of `docs/ans-forth-core-compliance.md` can find a §-level row for every mandatory rule in DPANS94 §6.1 (Core wordset) — verdict (Implemented / Implemented-with-caveat / Accepted-with-rationale-N-A), source `file:line` for the implementation, story-number for the closure (or "v2.0 baseline" for pre-Phase-3 closures), and any caveats.
- **FR-P3-2:** A reader of `docs/ans-forth-core-compliance.md` can find a §-level row for every implemented word in DPANS94 §6.2 (Core Extension wordset) — same row-format as FR-P3-1.
- **FR-P3-3:** A reader of `docs/ans-forth-core-compliance.md` can find a §-level row for every structural §-rule that applies to antforth (e.g., §3.1.4.1 double-cell stack-layout, §3.4.1.3 numeric-literal parser rule, plus any other structural rules surfaced by the A.1 audit walk).
- **FR-P3-4:** A reader can confirm — for any DPANS94 §6.1 / §6.2 rule that is *not* implemented in antforth — an explicit "Accepted-with-rationale: N-A" or "Deliberately-omitted: rationale" row, never a silent gap (per `feedback_no_preexisting_discharge.md`).
- **FR-P3-5:** Any §-level structural-rule gap surfaced by the A.1 audit is either back-filled with a focused story (the Stories 13.0 / 13.0.1 / 13.5 template — implementation + new compliance-doc row + REPL probes + hardware smoke) or explicitly accepted-with-rationale per project-lead approval.
- **FR-P3-6:** Every word touched by an A.1 back-fill story carries a one-line standards-citation comment in its assembly source per CCD-3 (`; ANS Forth 1994 §<sec>` / `; Forth 2014 §<sec>` / `; antforth extension`).

### Asm-Error THROW Catchability (A.2)

- **FR-P3-7:** Users can wrap any antforth assembler-error-raising operation in a `CATCH` frame and receive the corresponding asm-error THROW code (any of `-258` through `-269`, plus `-270` through `-272`) on the data stack, exactly as they receive ANS-standard codes (e.g. `-4`, `-13`).
- **FR-P3-8:** The `tests/throw_migration_tests.fth` (or equivalent harness) exercises the caught-form path (`' WORD CATCH . CR` idiom) for each asm-error THROW code in the `-258..-272` block; each test asserts that the expected code lands on the data stack.

### Base-Aware Numeric-Literal Parsing (A.3)

- **FR-P3-9:** When the user has set `BASE` to an explicit value (via `HEX`, `DECIMAL`, or direct `BASE !`), unprefixed numeric literals parse per that BASE consistently — at the REPL, in compiled colon definitions, and in the built-in Z80 assembler source.
- **FR-P3-10:** Forth-2014 §3.4.1.3 prefixed numeric literals (`#`/`$`/`%`/`'c'`/`0x`) continue to parse in their declared base regardless of `BASE` (FR9 from the Phase-2 PRD continues to hold; A.3 adds nothing to prefixed parsing).

### Test-Author Documentation (B.1)

- **FR-P3-11:** A test author can find documented guidance — in `tests/README.md` or an inline comment block in `Makefile`'s test section — establishing `PAD` (per ANS §6.2.2000) as the canonical transient-buffer word for use in REPL-piped Forth probes that need a scratch buffer surviving one space-delimited parse. The guidance acknowledges the historic alternatives (`HERE` and `S"` allocation) and explains why `PAD` is preferred.

### Story-Template / Drafting Discipline (B.2 + B.3 + B.4)

- **FR-P3-12:** A story drafter using the project's story-template encounters a HALT-signal lint when the byte-budget rationale contains "mirrors", "same shape as", or equivalent language referencing a prior arm; the lint requires the drafter to itemise the new arm's parts independently before the byte-budget rationale is accepted (B.2 — extends Lesson 13-C as Lesson 13.5-C).
- **FR-P3-13:** A story drafter using the project's story-template encounters, in the "Pre-edit baseline" task, an explicit instruction to capture `wc -c` of the current binary itself rather than inheriting the prior story's reported number (B.3 — closes the 6-byte 13.5.5-close-out doc-drift gap).
- **FR-P3-14:** A story drafter using the project's story-template encounters figure-drift discipline (PD-2): figures, tables, and code blocks are validated against the source-of-truth at draft time, not inherited from an earlier story or retro (B.4).
- **FR-P3-15:** The story-template's discipline edits (B.2–B.4) carry their own verdict criteria in the lead-in stories that introduce them — each B.2/B.3/B.4 story tests that the new template would have caught the prior-incident pattern that motivated it (e.g. B.2 verifies the lint catches a synthesised "mirror" phrase; B.3 verifies the `wc -c` task captures the actual binary).

### Build-Tool Sync & Hygiene (B.5 + B.6 + B.8)

- **FR-P3-16:** A maintainer running the project's build can invoke a sync target (Makefile rule, doc-build script, or equivalent) that detects PRD-vs-architecture transcription drift between this PRD and the next-revised architecture document; the target produces a drift report or a clean-pass verdict (B.5 — closes PD-3).
- **FR-P3-17:** A contributor running `make check-tools` (or equivalent target) can confirm the iz-cpm version installed on the host matches the version the project's test baseline is calibrated against; mismatches produce a clear advisory (B.6 — closes PD-6).
- **FR-P3-18:** The Makefile's `make test-repl` target uses unique numeric IDs across all probes; duplicate test numbers (the Story 11.3 cosmetic gap) are renumbered on the first Makefile-touching Phase-3 story (B.8).

### Filesystem Stress Coverage (B.7 + B.9)

- **FR-P3-19:** Probe coverage for directory-full failure mode (writing past the maximum-files-per-directory CP/M 2.2 limit) exists in `tests/file_access_tests.fth` (or equivalent harness), exercising both the failed-write `ior` return path and the FCB-pool / filesystem-state consistency post-failure (B.7 — conditional on hardware-revealed need; otherwise B.7 evaluation suffices).
- **FR-P3-20:** Probe coverage for zero-byte `READ-FILE` exists in `tests/file_access_tests.fth` (or equivalent harness), exercising the `( c-addr 0 fileid -- 0 0 )` no-op path (B.7 — conditional, same disposition as FR-P3-19).
- **FR-P3-21:** Disk-full handling (writing past the B: ramdisk capacity) is verified clean on real CP/M 2.2 / MicroBeast hardware via a hardware-typed probe; the probe asserts a non-zero `ior` return, FCB-pool consistency, and filesystem consistency post-failure (B.9).

### Backward Compatibility & Regression (phase-wide constraint)

- **FR-P3-22:** All functional behaviour delivered in Phase 1 (Epics 1–8) and Phase 2 (Epics 9–13.5) — the full Phase-2 FR1–FR47 set, including REPL behaviour, colon definitions, variables, constants, `CREATE`/`DOES>`, control flow, error reporting, `MARKER`, `CATCH`/`THROW`, multi-vocabulary Search-Order, File-Access wordset, Forth-2014 §3.4.1.3 numeric-literal prefixes including `0x`, double-precision arithmetic, pictured numeric output, the unchanged hard-coded inline assembler, and all existing word semantics — continues to work identically in every Phase-3 antforth 2.x point-release.
- **FR-P3-23:** All existing REPL-piped test scripts (the 1..952 baseline plus the 944..964 Epic-13.5 cleanup-slate probes) continue to pass against every Phase-3 antforth 2.x point-release. Zero regressions on either set is a release blocker (per Phase-2 NFR9, carried forward).
- **FR-P3-24:** All existing CODE-word source files written against pre-Phase-3 antforth assemble correctly and produce byte-identical output under every Phase-3 antforth 2.x point-release (extends Phase-2 FR31, NFR14).
- **FR-P3-25:** The unprefixed numeric-literal form (`<BASEnum>`) continues to be parsed per the current value of `BASE` identically to pre-Phase-3 antforth, *except* for the A.3 enhancement covered by FR-P3-9 (which is itself a refinement of the pre-Phase-3 behaviour to be more strictly base-aware in edge cases the pre-Phase-3 implementation handled inconsistently).

**Self-validation summary:**

- ✅ **Coverage** — every capability surfaced in the Executive Summary, Success Criteria, User Journeys, and Project-Type sections is represented by at least one FR. Every Phase-3 carry-forward P1 item (A.1, A.2, A.3, B.1, B.2, B.3, B.4, B.5, B.6, B.7, B.8, B.9) maps to one or more FRs.
- ✅ **Traceability** — every FR is tagged with the carry-forward item that drives it (A.x or B.x); the Journey Requirements Summary table cross-references journeys to FRs and carry-forward items.
- ✅ **Altitude** — FRs describe WHAT capabilities exist, not HOW the system implements them. Multiple FRs (FR-P3-11, FR-P3-12, FR-P3-13, FR-P3-14, FR-P3-16, FR-P3-17, FR-P3-18) describe non-runtime artifacts (docs, story templates, Makefile targets) — this is appropriate for a debt-cleanup phase whose "users" include doc-readers and story-drafters in addition to runtime Forth users.
- ✅ **Testability** — every FR can be verified by an observable outcome (doc row exists, lint fires on synthesised input, test passes on hardware, byte-identical output, etc.).
- ✅ **Independence** — each FR is understandable in isolation; cross-references to the Phase-2 PRD or carry-forward catalogue are explicit pointers, not narrative dependencies.
- ✅ **Completeness bar** — if the system satisfies all 25 FR-P3-* requirements (in addition to the carried-forward FR1–FR47 from Phase 2 via FR-P3-22), Phase 3's MVP gate is met.

**FR numbering note.** Phase-3 FRs use the `FR-P3-N` prefix (for "Phase 3") to distinguish them from the Phase-2 FR1–FR47 set carried forward via FR-P3-22. This avoids ambiguity in cross-references between this PRD and the Phase-2 PRD (`prd-phase2-epics-9-13.5.md`).

## Non-Functional Requirements

> **Selective approach.** antforth is a single-user, single-machine, offline, hobby-scale retrocomputing tool. Categories that do not apply — **Security** (no network, no sensitive data, no auth), **Scalability** (one user, one 8-bit CPU), **Accessibility** (hardware-constrained; LED display is outside software control) — are explicitly omitted to avoid requirement bloat. Phase 3 carries forward Phase-2's NFR1–NFR21 set with explicit "still holds" statements; new Phase-3-specific NFRs use the `NFR-P3-N` prefix and live under their natural category (with a new **Process Discipline** category for the S1–S12 standing-commitment hold).

### Performance (Phase 2 carry-forward; no new Phase-3 NFRs)

- **NFR-P3-1 (carries Phase-2 NFR1–NFR5):** All performance envelopes from the Phase-2 PRD continue to hold across every Phase-3 antforth 2.x point-release. Specifically: numeric-literal prefix parse overhead ≤ ~20 Z80 cycles over unprefixed (NFR1); multi-vocabulary lookup regression ≤ 10% vs single-vocabulary baseline (NFR2); uncaught CATCH frame overhead ≤ ~15 Z80 cycles (NFR3); per-epic ROM-footprint budget logged and justified (NFR4); double-precision primitives within ~20% of hand-rolled Z80 equivalents (NFR5). No Phase-3 work measurably regresses any of these envelopes; if any back-fill story would, sprint-change-proposal evaluation is triggered.
- **NFR-P3-2 (Phase-3-specific cumulative ROM budget):** Phase-3 cumulative binary growth is capped at +200 bytes (24,996 → ≤ 25,200). Per-story envelopes are checked against this cumulative target; any single story that would push cumulative over the cap triggers a HALT signal and project-lead-approval before proceeding. Per-story envelopes (per the Project Scoping section): B.1–B.5 ≈ 0; A.1 audit story ≈ 0; A.1 back-fill stories ~+10..+50 each (Story 13.0 / 13.0.1 / 13.5 precedent); A.2/A.3 ~+0..+30 each; B.6 ~0; B.7 conditional; B.8 ~0; B.9 ~0.

### Reliability

- **NFR-P3-3 (carries Phase-2 NFR6 — REPL survivability):** The REPL survives any THROW, including stack overflow, division by zero, undefined-word invocation, and the asm-error THROW codes (-258..-272). User's dictionary, in-session definitions, and working state are preserved across errors. (Carries forward verbatim from Phase 2; A.2 caught-form coverage is the FR-level extension that ensures every kernel-raise has a working caught-form path.)
- **NFR-P3-4 (carries Phase-2 NFR7 — state integrity after error):** No internal data structure (dictionary, wordlists, input buffer, pad, return stack, FCB pool, INCLUDE source frames) may be left in a corrupted or inconsistent state after a THROW. Standard ANS catch-frame cleanup semantics apply.
- **NFR-P3-5 (carries Phase-2 NFR8 — filesystem error recovery):** Failures during file operations (disk full, file locked, I/O error from BDOS, directory full, zero-byte read) raise a THROW or return an `ior` per the Story-13.2/13.5.1/13.5.2 split, leaving the filesystem in a consistent state — no partial writes that corrupt CP/M directory entries, no orphaned file handles. **Phase-3 delta:** the directory-full and zero-byte READ-FILE failure modes (B.7) gain explicit probe coverage if hardware reveals them, and disk-full handling (B.9) is re-verified on real CP/M 2.2 / MicroBeast.
- **NFR-P3-6 (Phase-3 test-baseline regression guarantee — extends Phase-2 NFR9):** The complete Phase-1 + Phase-2 + Epic-13.5 test suite (1..952 baseline plus 944..964 cleanup-slate probes = 973 PASS / 0 FAIL) passes on every Phase-3 antforth 2.x point-release candidate. A single regression on any of the 973 tests is a release blocker. Additional Phase-3 probes are welcome but additive — they do not replace the baseline.
- **NFR-P3-7 (mid-epic hardware-smoke cadence per story — codifies S9):** Every binary-delta Phase-3 story runs its own hardware-smoke task on real CP/M 2.2 / MicroBeast with a PASS verdict before the story is considered done. Zero-binary-delta stories (e.g. B.1–B.5 doc/template-only stories) document their S9 exemption explicitly. The cadence prevents Epic-13's "only the close-out story ran hardware smoke" anti-pattern.

### Compatibility & Standards Conformance

- **NFR-P3-8 (carries Phase-2 NFR10 — ANS Forth 1994 Core compliance):** The Core wordset (DPANS94 §6.1) is implemented to 100% coverage with behaviour matching the ANS specification. Compliance is measured by per-row entries in `docs/ans-forth-core-compliance.md`. **Phase-3 delta:** the compliance measurement is upgraded from word-counted to §-level — a §-by-§ audit walks every mandatory rule (not just every word), backed by per-rule rows. This is the A.1 strategic body.
- **NFR-P3-9 (carries Phase-2 NFR11 — Forth 2014 §3.4.1.3 conformance):** Numeric-literal prefix syntax is implemented verbatim per Forth 2014 §3.4.1.3 (carries forward from v2.0 baseline). **Phase-3 delta:** A.3 unprefixed `NUMBER?` base-specialization closes the residual edge case where the pre-Phase-3 implementation handled unprefixed parsing inconsistently against the BASE setting.
- **NFR-P3-10 (carries Phase-2 NFR12 — extension discipline):** The only non-standard additions to date are the `0x` hex-literal prefix (Epic 9), the `INCLUDE-TOP` / `CATCH-TOP` USER-variable extensions (Epic 11/13), and the asm-error THROW codes `-258..-272`. All clearly flagged in source per CCD-3 (`; antforth extension <word> — <design reason>`). **Phase 3 introduces no new extensions.**
- **NFR-P3-11 (carries Phase-2 NFR13 — CP/M 2.2 BDOS integration):** antforth uses only CP/M 2.2 standard BDOS functions (the existing Phase-2 allow-list: 0, 1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 25, 26, 27, 33, 34, 35, 36, 40). No CP/M Plus, MP/M, or extended BIOS-level calls. **Phase 3 does not add any new BDOS functions to the allow-list.** Portability across CP/M 2.2 implementations is preserved.
- **NFR-P3-12 (carries Phase-2 NFR14 — CODE-word source file backward compatibility):** CODE-word source files written against pre-Phase-3 antforth assemble correctly and produce byte-identical output under every Phase-3 antforth 2.x point-release.
- **NFR-P3-13 (Phase-3 §-level compliance auditability):** `docs/ans-forth-core-compliance.md` carries enough information per row (§-number, source `file:line`, story-number for closure, caveats) that an external Forth implementor can verify any single row against the standard text and the source code in under 10 minutes. (This is the FR-P3-1..FR-P3-4 capability stated as a quality attribute — the document is *checkable*, not just present.)

### Maintainability

- **NFR-P3-14 (carries Phase-2 NFR15 — code density and readability):** Z80 assembly source favours readability over micro-optimisation, except where the epic explicitly targets performance. Comments on non-obvious logic are required; comments re-stating what assembly already says are forbidden. **Phase 3 specifically:** A.1 back-fill stories follow the Story 13.0 / 13.0.1 / 13.5 commenting style — every back-filled word carries its standards-citation comment per CCD-3.
- **NFR-P3-15 (carries Phase-2 NFR16 — test-first discipline):** Every new word, every behaviour change, and every defect closure introduced in Phase 3 has REPL-piped Forth test coverage before being declared done (per established project convention since Epic 3, codified by S2). Test scripts are the canonical regression surface.
- **NFR-P3-16 (carries Phase-2 NFR17 — single-source-of-truth for standards references):** Word behaviours that derive from a standard cite the standard section in the source comment per CCD-3 (`; ANS Forth 1994 §<sec>` etc.). **Phase-3 delta:** the A.1 audit walk re-verifies every existing citation against `docs/ans-forth-core-compliance.md`'s §-level rows; mismatches are surfaced and corrected as part of the audit story.
- **NFR-P3-17 (carries Phase-2 NFR18 — epic-level decoupling):** Each Phase-3 epic delivers an independently-shippable antforth 2.x point-release. Intermediate releases are legitimate release artifacts, not internal milestones. The Phase-3 close-out tag is the final 2.x version (e.g. 2.1.0 if Phase-3 is one epic; 2.x for higher x if multiple epics).
- **NFR-P3-18 (Phase-3 story-template discipline as quality attribute):** The story-template lints / HALT signals / pre-edit task additions established by B.1–B.5 fire automatically when triggered (lint catches "mirrors" phrase, `wc -c` task captures actual binary, figure-drift discipline applies at draft time, PRD-vs-architecture sync runs at doc-build time). A story drafter does not need to remember to invoke them; they are baked into the workflow.

### Integration (CP/M and Platform — Phase 2 carry-forward)

- **NFR-P3-19 (carries Phase-2 NFR19 — terminal I/O portability):** antforth uses only character-based BDOS console I/O (functions 1, 2, 6, 9). No assumption of ANSI escape codes, cursor positioning, line-mode vs raw-mode toggles, or colour support. The interpreter runs on any CP/M 2.2 terminal.
- **NFR-P3-20 (carries Phase-2 NFR20 — file path conventions):** `INCLUDE` and related words accept CP/M 2.2 file path syntax (optional drive letter + `:` + 8.3 filename) exactly. No wildcards in scope; no Unix-style paths.
- **NFR-P3-21 (carries Phase-2 NFR21 — MicroBeast hardware dependency isolation):** No MicroBeast-specific hardware word enters the kernel during Phase 3. The MicroBeast hardware vocabulary is a Phase-4+ epic and must be loadable as pure Forth source from disk, not kernel-resident.

### Process Discipline (NEW for Phase 3 — codifies S1–S12 standing commitments)

These NFRs codify the 12 standing process commitments (S1–S12 from the Epic 13.5 retro) as Phase-3 quality attributes. Each must hold across every Phase-3 epic close-out.

- **NFR-P3-22 (S1 — adversarial review fresh-context external):** Code reviews are conducted via the `/CR` command (fresh-context external) per the post-PD-1 structural close, not in-pass within the dev-pass. Every Phase-3 retro confirms eleven-plus consecutive epics with structurally-fresh-context CR location.
- **NFR-P3-23 (S2 — REPL-piped tests as default):** New tests in Phase 3 are REPL-piped Forth scripts, not assembly test thread extensions. Probes follow S12 hardware-typed authoring discipline.
- **NFR-P3-24 (S3 — real-byte-count estimation + capstone-aware drafting):** Story byte-budget rationale is itemised per-part, not asserted via "mirrors prior arm" shorthand (extended by B.2 / Lesson 13.5-C). The story-template lint (FR-P3-12) catches the shorthand pattern.
- **NFR-P3-25 (S4 — AC-composition validation):** Story acceptance criteria are validated for composability — each AC stands alone or in composition with its named antecedents; no AC silently depends on another's side-effects.
- **NFR-P3-26 (S5 — PARTIAL → HALT):** PARTIAL verdicts (any AC not fully PASS) trigger a HALT signal at the dev-pass; root-cause is handled in-pass or the story spawns a sibling, with no carry-forward as tech debt.
- **NFR-P3-27 (S6 — inventory grep covers helpers, not just leaves):** Story inventory grep walks the helper layer (e.g. `asm_die` callers, `file_byte_read` callers, `check_underflow` callers) not just the user-facing word, ensuring fan-in completeness.
- **NFR-P3-28 (S7 — EXX-hygiene per kernel-internal raise site):** Kernel sites that raise THROW (the `-258..-272` block, the standard codes) preserve EXX state per the established §3 leaf-level rule and §7 EXX-using inventory in `docs/register-conventions.md`.
- **NFR-P3-29 (S8 — "pre-existing" cannot discharge correctness defects):** Per `feedback_no_preexisting_discharge.md`, correctness defects (clobbers, lost writes, silent error swallowing) cannot be marked "accepted-with-rationale: pre-existing" — they must be surfaced, filed, fixed (or explicitly re-prioritised down with project-lead approval). Eleven-plus consecutive epic hold of this commitment.
- **NFR-P3-30 (S9 — mid-epic hardware-smoke cadence per story):** Codified as NFR-P3-7 above (binary-delta stories run their own S9 hardware-smoke).
- **NFR-P3-31 (S10 — workflow > memory > prompt):** Process / discipline fixes land in workflow files (BMAD step files, story templates, agent definitions) and codified-discipline files (memory entries, `feedback_*.md`), not in conversational prompts. The Phase-3 lead-in stories (B.1–B.5) themselves are workflow-file edits, not prompt edits.
- **NFR-P3-32 (S11 — user-visible version surface audit row at tag-applicable epic close-out):** Every Phase-3 antforth 2.x point-release tag passes the user-visible version surface audit (banner string in binary, README version reference, memory-file `description` fields). Mismatches against the tag being applied are HALT signals.
- **NFR-P3-33 (S12 — hardware-typed probe authoring discipline):** Every smoke-batch destined for human typing on real hardware passes (a) word-existence pre-flight (every word resolves in antforth's dictionary or is documented as a planned new word) and (b) TIB-128 line-length lint (every line ≤ 128 chars). The `tests/README.md` (or equivalent) per FR-P3-11 documents these conventions for test authors.
