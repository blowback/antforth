---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-05-08'
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-05-08.md
  - docs/PHASE-3-CARRY-FORWARD.md
  - docs/antforth-banking-design.md
  - _bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md
  - docs/WISHLIST.md
  - _bmad-output/planning-artifacts/architecture-phase2-epics-9-13.5.md
  - _bmad-output/planning-artifacts/prd-phase2-epics-9-13.5.md
  - _bmad-output/planning-artifacts/epics.md
  - docs/ans-forth-core-compliance.md
  - docs/register-conventions.md
  - docs/throw-codes.md
  - docs/z80-instruction-coverage.md
  - docs/z80-instruction-coverage-reaudit.md
  - docs/z80_forth_assemblers.md
  - docs/shadow-register-survey.md
  - docs/shadow-register-followup-survey.md
workflowType: 'architecture'
project_name: 'antforth'
user_name: 'Ant'
date: '2026-05-08'
phase: 3
phaseScope: 'Phase 3 — debt-cleanup interlude (carry-forward catalogue P1 close-out + §-by-§ ANS Core/Core-Extension audit)'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

The 2026-05-08 Phase-3 PRD specifies **25 Phase-3 FRs** (FR-P3-1..25), plus full carry-forward of the Phase-2 FR1–FR47 set via FR-P3-22. All FRs map to one of the 12 P1 items in `docs/PHASE-3-CARRY-FORWARD.md`:

- **FR-P3-1..6 (A.1) — §-level compliance documentation.** Per-rule rows in `docs/ans-forth-core-compliance.md` for DPANS94 §6.1 (Core), §6.2 (Core Extension), and structural §-rules; back-fill stories for any §-level structural-rule gap surfaced (Stories 13.0 / 13.0.1 / 13.5 template); standards-citation discipline (CCD-3) preserved on every back-filled word. Architectural impact: documentation-format decision (per-row schema) + back-fill story shape (ties to existing back-fill template).
- **FR-P3-7..8 (A.2) — Asm-error caught-form coverage.** `tests/throw_migration_tests.fth` exercises the `' WORD CATCH . CR` idiom for each asm-error THROW code in the `-258..-272` block. Architectural impact: test-harness extension only — no kernel changes (the migration was completed in Story 11.5; the gap is test coverage of the caught-form path).
- **FR-P3-9..10 (A.3) — Base-aware unprefixed `NUMBER?`.** Unprefixed numerals parse per the explicit `BASE` consistently across REPL / colon bodies / assembler source. Forth-2014 §3.4.1.3 prefixed literals continue to ignore `BASE`. Architectural impact: refinement of the existing `NUMBER?` path in `src/strings.asm` — small surgical change.
- **FR-P3-11 (B.1) — `PAD` documented as canonical transient-buffer for test authors.** `tests/README.md` (or inline header in `Makefile`'s test section) documents the convention. Architectural impact: documentation only.
- **FR-P3-12..15 (B.2/B.3/B.4) — Story-template / drafting discipline.** Lints / HALT signals / "Pre-edit baseline" task additions in BMAD story-template files. Architectural impact: BMAD workflow-file edits (story-template, agent definitions); each carries its own verdict criterion.
- **FR-P3-16..18 (B.5/B.6/B.8) — Build-tool sync & hygiene.** PRD-vs-architecture transcription-drift sync target; `make check-tools` for iz-cpm version stability; Makefile test-numbering hygiene. Architectural impact: Makefile and doc-build targets.
- **FR-P3-19..21 (B.7/B.9) — Filesystem stress coverage.** Directory-full + zero-byte READ-FILE probes (B.7 conditional on hardware-revealed need); disk-full hardware re-verification on real CP/M 2.2 (B.9). Architectural impact: probe coverage + hardware test discipline; no kernel surgery expected unless hardware reveals defects.
- **FR-P3-22..25 (phase-wide regression constraint).** Full Phase-1 + Phase-2 + Epic-13.5 behaviour preserved; 973 PASS / 0 FAIL baseline; CODE-source backward compat byte-identical; unprefixed numeric literal parsing preserved (with the A.3 strict-base-aware refinement).

**Non-Functional Requirements:**

The PRD specifies **33 Phase-3 NFRs** (NFR-P3-1..33) across six categories, including a **new Process Discipline** category that codifies the S1–S12 standing commitments as quality attributes:

- **Performance** — Phase-2 NFR1–5 envelopes hold; Phase-3-specific cumulative ROM cap +200 bytes (24,996 → ≤25,200).
- **Reliability** — Phase-2 NFR6–9 carry forward; mid-epic hardware-smoke cadence per binary-delta story (NFR-P3-7 codifies S9).
- **Compatibility & Standards Conformance** — 100% §6.1 Core via §-level rows (NFR-P3-8); Forth-2014 §3.4.1.3 with A.3 strict refinement; no new extensions; no new BDOS functions added to the allow-list; §-level audit-doc checkability under 10 minutes per row (NFR-P3-13).
- **Maintainability** — Phase-2 NFR15–18 carry forward; story-template lints fire automatically (NFR-P3-18).
- **Integration** — Phase-2 NFR19–21 carry forward; bank-0 only (banking design deferred to Phase 4).
- **Process Discipline (NEW for Phase 3)** — NFR-P3-22..33 codify S1–S12: adversarial CR fresh-context (S1), REPL-piped tests (S2), real byte-count estimation extended by Lesson 13.5-C (S3), AC-composition validation (S4), PARTIAL→HALT (S5), inventory-grep covers helpers (S6), EXX-hygiene per raise site (S7), no "pre-existing" discharge for correctness defects (S8), per-story hardware smoke (S9), workflow > memory > prompt (S10), version-surface audit at tag close-out (S11), hardware-typed probe discipline (S12).

**Scale & Complexity:**

- Primary domain: `developer_tool_embedded` (Z80 Forth interpreter on CP/M 2.2)
- Complexity level: **low** (per PRD classification; Phase 3 reduces complexity vs Phase 2 — no new subsystems, no new user-facing surface beyond §-level back-fills)
- Estimated architectural components touched: 0 new subsystems; refinements to existing components in `src/strings.asm` (A.3); test-harness extensions to `tests/throw_migration_tests.fth` (A.2); documentation artifact `docs/ans-forth-core-compliance.md` (A.1); BMAD workflow files (B.1–B.5); Makefile (B.5/B.6/B.8); plus 0–2 expected A.1 back-fill stories whose shape mirrors Stories 13.0 / 13.0.1 / 13.5.

### Technical Constraints & Dependencies

**Inherited from v2.0 baseline (carry forward unchanged):**

- **Hardware:** Zilog Z80 @ 8 MHz; 512 KB banked RAM/ROM; MicroBeast platform. Phase 3 stays in bank 0 — banking design (`docs/antforth-banking-design.md`) deferred to Phase 4.
- **Host OS:** CP/M 2.2 only. BDOS function allow-list per NFR-P3-11 — Phase 3 does not grow the allow-list.
- **Threading model:** direct threading (JP-based), DEFWORD `cf` label via `EQU body-3` pointing to `JP DOCOL`.
- **Register contract (`docs/register-conventions.md`):** BC = TOS; SP = parameter stack pointer; IX = return stack pointer; IY = user area pointer; DE = IP; HL = working register / scratch. EXX leaf-level rule + "A survives EXX" idiom + shadow BC' as TOS-preservation slot — all carried forward.
- **Phase-2 cross-cutting decisions (CCD-1..CCD-4):**
  - **CCD-1** dual-chain return-stack frame discipline (`CATCH-TOP` 8-byte exception frames + `INCLUDE-TOP` 10-byte source frames).
  - **CCD-2** THROW code allocation: `-1..-58` ANS standard / `-59..-255` reserved for ANS extensions (with `-69`, `-70` re-purposed for FCB / FID-invalid) / `-256..-32767` antforth extensions (with `-257` reserved for `THROW_ASM_LOAD_FAIL` and `-258..-272` allocated for asm-errors).
  - **CCD-3** standards-citation discipline — every standard-derived word's source carries `; ANS Forth 1994 §<sec>` / `; Forth 2014 §<sec>` / `; antforth extension`.
  - **CCD-4** per-epic benchmark gate — close-out story validates NFR envelopes.
- **Source-of-truth boundary frozen for Phase 3:** kernel in Z80 assembly; `src/assembler.asm` stays kernel-resident hard-coded (per `project_assembler_keep_assembly.md`); no new Forth-source kernel additions; no new asm kernel additions except A.1 back-fills.

**Phase-3 specific:**

- **Cumulative ROM budget:** +200 bytes (NFR-P3-2). Per-story envelopes: B.1–B.5 ≈ 0; A.1 audit story ≈ 0; A.1 back-fill stories ~+10..+50 each; A.2/A.3/B.6/B.8/B.9 ≈ 0..+30 each; B.7 conditional.
- **Test baseline:** 973 PASS / 0 FAIL on real CP/M 2.2 / MicroBeast. Single regression on 1..952 baseline or 944..964 cleanup-slate is a release blocker.
- **Hardware smoke per binary-delta story (S9 / NFR-P3-7):** every binary-delta story runs its own hardware-smoke task; zero-binary-delta stories document S9 exemption explicitly.
- **Tag discipline (S11 / NFR-P3-32):** every Phase-3 antforth 2.x point-release tag passes the user-visible version surface audit (banner / README / memory-file `description` fields).

### Cross-Cutting Concerns Identified

1. **§-level compliance documentation as checkable artifact (A.1 / NFR-P3-13).** Cross-cuts every standards-claiming word in the kernel, the audit story, the back-fill stories, and the doc-build process. The architecture must define the per-rule row schema and the back-fill-story template that produces each new row.
2. **Process discipline as workflow-file edits (B.1–B.5 / NFR-P3-18 / S10).** Cross-cuts the BMAD story-template, agent definitions, Makefile sync targets, and `tests/README.md`. The architecture must define which workflow files are touched and how each lint / HALT / pre-edit task is structurally enforced (not aspirational).
3. **Standing-commitment hold (S1–S12 / NFR-P3-22..33).** Cross-cuts every Phase-3 retro and every story's verdict criteria. Architectural impact is process-shaped: each Phase-3 story re-validates the relevant subset of S1–S12 in its dev-pass.
4. **Backward-compatibility / regression invariants (FR-P3-22..25 / NFR-P3-6).** Cross-cuts every binary-delta story. The 973 PASS / 0 FAIL baseline + CODE-source byte-identical assembly + no new BDOS functions + bank-0-only — all are absolute, not negotiable.
5. **ROM budget discipline (NFR-P3-2).** Cross-cuts every binary-delta story. Per-story envelope checked against +200-byte cumulative cap; HALT signal if any single story would push cumulative over.
6. **Asm-error THROW code block contiguity (CCD-2).** A.2's caught-form coverage applies to the post-Story-11.5.6 block `-258..-272` (15 codes), not just the original Story-11.5 block `-258..-269`. Architecture must reaffirm CCD-2's reservation discipline (gap at `-256`, reservation at `-257`) and codify the contiguous-block invariant for any future allocations.

## Starter Template Evaluation

**Not applicable.** antforth is a brownfield Z80 assembly project (`developer_tool_embedded`) with no relevant starter-template ecosystem. Phase 3 is a **debt-cleanup interlude** on an already-shipped v2.0 baseline; there is no scaffolding decision to make — the "starter" is the v2.0 codebase itself.

**Phase-3 foundation: antforth v2.0** (commit `6599d73`, tagged `v2.0.0` 2026-05-07, 24,996 bytes, 973 PASS / 0 FAIL on real CP/M 2.2 / MicroBeast). Inherited from v2.0 without replacement:

- **Inner interpreter:** direct-threaded (JP-based); DEFWORD `cf` label via `EQU body-3` pointing to `JP DOCOL`.
- **Register contract** (`docs/register-conventions.md`): BC=TOS, SP=pstack, IX=rstack, IY=user-area, DE=IP, HL=W. EXX leaf-level rule + "A survives EXX" idiom + shadow BC' as TOS-preservation slot.
- **Outer interpreter / REPL:** text parser, interpret/compile state machine, exception-frame-aware error reporting (post-Epic-11 — uncaught THROWs route to the inlined `.throw_uncaught` recovery chain at `src/exception.asm:412+`).
- **Dictionary:** multi-vocabulary Search-Order (post-Epic-12) — XOR-rotate 64-bucket hash per wordlist, search-order LIFO with bounds check.
- **Language extension layer:** colon definitions, CREATE/DOES>, control flow, MARKER, immediate words, POSTPONE; numeric-literal prefixes (Forth 2014 §3.4.1.3 + `0x` extension).
- **Exception subsystem (Epic 11):** CCD-1 dual-chain frame discipline; CATCH-TOP and INCLUDE-TOP USER variables; 8-byte exception frames + 10-byte INCLUDE source frames; ABORT/ABORT" retargeted to -1/-2 THROW.
- **File-Access wordset (Epic 13):** real CP/M 2.2 BDOS integration (function allow-list per NFR-P3-11); FCB pool with use-after-free detection (-70 re-purposed); INCLUDE source-frame chain walk integrated with THROW.
- **Built-in Z80 assembler:** 113 DEFCODEs, ~4,100 lines of `src/assembler.asm`, 158/158 instruction-form coverage, asm-error THROW codes -258..-272 with caught-form coverage gap (A.2 closes for Phase 3).
- **Pictured numeric output (Epic 10) + double-cell arithmetic** with high-on-TOS layout (post-Story-13.0.1, ANS §3.1.4.1).
- **§-level Core compliance baseline:** 100% §6.1 word coverage + §3.1.4.1 / §3.4.1.3 structural rules + ad-hoc §6.1.0310 / §6.1.0350 / §6.1.0090 row-level coverage in `docs/ans-forth-core-compliance.md`. A.1 upgrades this from word-counted to §-level for the entire §6.1 + §6.2 surface.
- **Test harness:** REPL-piped Forth test scripts (convention since Epic 3, codified by S2); 973 PASS / 0 FAIL on real hardware; `make test-repl` baseline.
- **Process discipline foundation:** standing commitments S1–S12 holding eleven-plus consecutive epics (Epic 13.5 retro); BMAD workflow files (story-template, agent definitions); `feedback_*.md` discipline files; `docs/PHASE-3-CARRY-FORWARD.md` as the prioritised carry-forward catalogue.

**Toolchain (also unchanged):** project's existing Z80 cross-assembler invoked by build scripts; iz-cpm emulator for `make test-repl` (with B.6 adding `make check-tools` for version stability); real MicroBeast hardware for S9 mid-epic hardware-smoke per binary-delta story.

**Phase-1 / Phase-2 cross-reference:** The phase-1 architecture document (`architecture-phase1-epics-1-8.md`) and phase-2 architecture document (`architecture-phase2-epics-9-13.5.md`) are the canonical references for all inherited subsystems. **This document specifies only the additions and changes for phase 3.** Dev-agent invocations consult phase-1 + phase-2 for the foundation, phase-3 for what is changing or being added. Where documents disagree, phase-3 wins (it describes the target state); where phase-3 is silent, phase-2 governs; where phase-2 is silent, phase-1 governs. Phase 3 is expected to be substantially silent on most v2.0 subsystems — the changes are concentrated in the §-level audit, asm-error caught-form harness, NUMBER? base-specialization, and the BMAD process-discipline / Makefile / docs surface.

**Note:** No project-initialization story is needed — Phase 3 starts from the v2.0 working tree.

## Core Architectural Decisions

> **Phase-1 / Phase-2 cross-reference:** The phase-1 architecture document (`architecture-phase1-epics-1-8.md`) and phase-2 architecture document (`architecture-phase2-epics-9-13.5.md`) are the canonical references for all inherited subsystems. **This document specifies only the additions and changes for phase 3.** Where documents disagree, phase-3 wins; where phase-3 is silent, phase-2 governs; where phase-2 is silent, phase-1 governs. Phase 3 is substantially silent on most v2.0 subsystems — the changes concentrate in §-level audit, asm-error caught-form harness, NUMBER? base-specialization, and the BMAD process-discipline / Makefile / docs surface.

### Decision Priority Analysis

**Critical Decisions (block specific carry-forward items):**
- §-level compliance-doc row schema (blocks A.1)
- A.1 audit decomposition strategy (blocks A.1)
- Back-fill story canonical shape (blocks any A.1 back-fill)
- Story-template edit sites for B.2/B.3/B.4 (block process-discipline lead-in)
- `make check-doc-sync` mechanism (blocks B.5)
- `make check-tools` mechanism (blocks B.6)
- Disk-full probe location (blocks B.9)

**Important Decisions (shape Phase-3 dev-passes):**
- Caught-form harness location (A.2)
- NUMBER? base-specialization site (A.3)
- PAD-as-canonical doc location (B.1)
- B.7 conditional-probe-story trigger and recording mechanism
- Combined B.7 + B.9 close-out shape (one hardware run resolves both)

**Carry-forward (no re-decision):**
- CCD-1 dual-chain frame discipline (Phase-2)
- CCD-2 THROW code allocation (Phase-2; Phase-3 reaffirms post-Story-11.5.6 block extension to -258..-272)
- CCD-3 standards-citation discipline (Phase-2)
- CCD-4 per-epic benchmark gate (Phase-2)
- Register contract, EXX leaf-level rule, DTC threading, source-of-truth boundary

**Deferred (post-Phase-3):**
- Banking architecture (`docs/antforth-banking-design.md`) — Phase 4
- STARTUP.FTH integration point — Phase 4+
- MicroBeast hardware vocabulary epic shape — Phase 4+
- `SEE` decompiler / `TRAVERSE-WORDLIST` — Phase 4+
- Locals wordset, IN/OUT primitives — Phase 4+
- D.1–D.4 (DMA pool size-reduction, `.S` migration to pictured output, MARKER full-graph snapshot, WORDS scope-pick) — P3 deferred indefinitely; trigger-only

---

### Cross-Cutting Architectural Decisions

#### CCD-1, CCD-2, CCD-3, CCD-4 (Phase-2 carry-forward)

CCD-1 (return-stack frame taxonomy with dual chain discipline — `CATCH-TOP` 8-byte exception frames + `INCLUDE-TOP` 10-byte source frames), CCD-2 (THROW code allocation across the three ranges -1..-58 / -59..-255 / -256..-32767), CCD-3 (standards-citation discipline per word), and CCD-4 (per-epic benchmark/close-out gate) all carry forward unchanged from `architecture-phase2-epics-9-13.5.md`.

**Phase-3 reaffirmation of CCD-2:** the asm-error THROW code block has extended from the original Story-11.5 allocation `-258..-269` to `-258..-272` post-Story-11.5.6 (which split the generic `-271 range` into `-271 disp range` / `-272 bit range`). Phase 3 does not allocate any new THROW codes; A.2 closes the caught-form coverage gap for the existing `-258..-272` block (15 codes). The reservation discipline holds: `-256` is unallocated (reserved gap), `-257` is reserved for `THROW_ASM_LOAD_FAIL` (per `architecture.md:478,606` from Phase-2; never raised in v2.0; remains reserved). Future asm-error allocations must extend from `-272` downward contiguously.

**Phase-3 reaffirmation of CCD-3:** every word touched by an A.1 back-fill story carries its standards-citation comment (`; ANS Forth 1994 §<sec>` / `; Forth 2014 §<sec>` / `; antforth extension`). The A.1 audit walk re-verifies every existing citation against the new §-level rows; mismatches are surfaced and corrected as part of the audit story.

#### CCD-P3-1: §-level compliance-doc row schema (NEW)

**Decision:** every row in `docs/ans-forth-core-compliance.md` follows a 6-column format:

| Column | Content | Example |
|---|---|---|
| **§** | DPANS94 / Forth-2014 section number | `§6.1.0350` |
| **Rule** | Short text or pointer to the rule | `2@: ( a-addr -- x1 x2 ) high cell on TOS` |
| **Verdict** | One of `Implemented` / `Implemented-with-caveat` / `Accepted-with-rationale-N-A` / `Deliberately-omitted` | `Implemented` |
| **Source** | `file:line` where implementation lives, or `N-A` for non-implementation rows | `src/double.asm:120` |
| **Closure** | Story number for the closure | `Story 13.0.1` |
| **Notes** | Caveats, sub-§ refs, citation cross-checks | `revised by Story 13.0.1` |

A.1's audit walk produces these rows for every mandatory rule in DPANS94 §6.1 (Core), §6.2 (Core Extension), and structural §-rules (§3.1.4.1 high-on-TOS double-cell layout, §3.4.1.3 numeric-literal parser rule, plus any others surfaced by the walk). Future stories add rows in this format only.

**Rationale:** the schema is the contract that makes NFR-P3-13 ("checkable in under 10 minutes per row") structurally true. A reader has the rule text inline (no off-document lookup required for the verification path), the verdict, the source file:line (so they can read the implementation directly), the story-closure provenance, and the notes column for any caveats or revisions.

**Implications:**
- Rows for §-rules with no implementation site (e.g., a structural rule satisfied by absence-of-misbehaviour) carry `Source: N-A` with the verdict `Accepted-with-rationale-N-A`
- `Deliberately-omitted` rows carry an explicit rationale in the Notes column (no silent gaps per `feedback_no_preexisting_discharge.md`)
- The `Closure` column may read `v2.0 baseline` for rows verified pre-Phase-3 (e.g., the existing §3.1.4.1 / §3.4.1.3 closures from Stories 13.0 / 13.0.1)

#### CCD-P3-2: Process discipline lives in workflow files (NEW)

**Decision:** Story-template lints, HALT signals, pre-edit task additions, and Makefile sync targets are the single source of truth for Phase-3 process discipline. Lints fire structurally (template-level enforcement), not aspirationally.

**Workflow-file enforcement surface:**
- `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` — drafting `<critical>` blocks (B.2, B.4)
- `_bmad/bmm/workflows/4-implementation/create-story/template.md` — task-list entries in the dev-pass section (B.3)
- `_bmad/bmm/workflows/4-implementation/create-story/checklist.md` — drafting checklist updates if needed
- `_bmad/bmm/agents/dev.md`, `_bmad/bmm/agents/sm.md` — agent-definition extensions for cross-cutting commands (CR cadence, etc.)
- BMAD installer manifest — ensures structural edits survive installer re-runs
- `Makefile` — sync targets `make check-doc-sync` (B.5), `make check-tools` (B.6), test-numbering hygiene (B.8)
- `tests/README.md` — test-author convention documentation (B.1)

**Documentation surface (the *why*, not the enforcement):**
- `memory/feedback_*.md` — guidance memory entries
- `docs/PHASE-3-CARRY-FORWARD.md` — prioritised catalog with closure notes
- Per-story Dev Notes — individual closure context

**Rationale:** codifies S10 ("workflow > memory > prompt") at the architectural level. NFR-P3-18's "drafter does not need to remember to invoke them" is structurally true only if the lints live where the workflow runs. PD-1 (Story 13.5.0) proved this pattern at the Epic-13.5 scale via five mechanically-grep-able verdict criteria, all PASS; Phase-3's B.1–B.5 cluster reuses exactly this pattern.

**Implications for B.x verdict criteria:** each B.x lead-in story carries a verdict criterion that tests whether the new workflow-file edit would have caught the prior incident pattern that motivated it. If a lead-in fails its own verdict (synthesised "mirror" phrase doesn't surface the HALT signal, `wc -c` task isn't grep-able in the template, etc.), the lead-in doesn't ship — discipline-as-deliverable, not aspiration.

---

### Per-Item Decisions

#### A.1 — §-by-§ ANS Core + Core-Extension audit

**A.1-D1: Compliance-doc row schema** — formalised as CCD-P3-1 above.

**A.1-D2: Audit decomposition — single audit story.** One §-by-§ walk produces all rows for §6.1 + §6.2 + structural rules; back-fill stories (0–2 expected) spawn from the audit's verdict per gap. Rationale: per `docs/PHASE-3-CARRY-FORWARD.md` § "Suggested Phase-3 First-Epic Shape", the catalog explicitly frames A.1 as "1 audit story + 0–2 back-fill stories per gap surfaced". The audit is doc-only / zero binary delta — HALT discipline doesn't need fine-grained sub-stories. Risk-mitigation: if the audit surfaces > 5 gaps, propose sprint-change with a re-prioritised cut per the PRD's risk table (some gaps may be acceptable-with-rationale; some may be Phase-3-deferred to a Phase-3.5 micro-phase).

**A.1-D3: Back-fill story canonical shape.** Each back-fill story includes:

1. Implementation in the appropriate `src/*.asm` (or `tests/*.fth` for test-only closures)
2. Standards-citation comment on the affected DEFCODE per CCD-3
3. New row in `docs/ans-forth-core-compliance.md` per CCD-P3-1
4. REPL probes (positive path + at least one edge case)
5. S9 hardware smoke on real CP/M 2.2 / MicroBeast
6. **Pre-fix negative-result confirmation** — the story explicitly demonstrates that the pre-fix code fails the new probe, so the back-fill closes a real gap rather than papering over a non-issue (codifies the discipline informally exercised on Stories 11.5.x and 13.5.x)

#### A.2 — Asm-error caught-form coverage

**A.2-D1:** caught-form tests extend `tests/throw_migration_tests.fth`. Each of the 15 asm-error THROW codes (`-258..-272`) gets a `' WORD CATCH . CR` probe asserting the expected code lands on the data stack. Rationale: the original ABORT→THROW migration tests live in this harness; A.2 is gap-closure on the same migration. Splitting harnesses to scope-tag a closure is overhead.

#### A.3 — Unprefixed `NUMBER?` base-specialization

**A.3-D1: site.** The change lands in `w_NUMBER_Q_cf` in `src/strings.asm` (the existing `NUMBER?` implementation, post-Story-13.0 baseline). Precise behaviour spec is deferred to A.3's story-author (the story will read the current code and the standard, then specify the exact pre-/post-behaviour delta). Architectural decision is **the site**, not the spec.

**Test coverage:** HEX (unprefixed `FF .` → `255 ok`), DECIMAL (unprefixed `255 .` → `255 ok`), non-default base (`8 BASE !` then unprefixed `17 .` → `15 ok`); plus the prefix-overrides-BASE invariant from Phase-2 FR9 (`HEX` then `#100 .` → `100 ok`) — regression-only, must continue to hold.

#### B.1 — `PAD` as canonical transient-buffer for tests

**B.1-D1:** `tests/README.md` (new file) is the single source of truth. `Makefile`'s test section gets a one-line pointer comment to `tests/README.md` for discoverability. The README documents:

- PAD's purpose (transient buffer surviving one space-delimited parse, per ANS §6.2.2000)
- Historical alternatives that bit (`HERE` / `S"`-near-HERE collisions per Story-13.5.1's transient-buffer-collision incident)
- The canonical idiom for probe authoring (when to use PAD vs. ALLOT vs. dedicated user-area scratch)

#### B.2/B.3/B.4 — Story-template / drafting discipline edits

**B.2-D1: "Mirrors prior arm" HALT signal.** Edit lands in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` as a `<critical>` block per the PD-1 precedent. Block requires the drafter to itemise the new arm's parts independently when byte-budget rationale contains "mirrors", "same shape as", or equivalent comparison-to-prior-arm phrasing.

**B.3-D1: Story-to-story binary handoff (re-`wc -c`).** Edit lands in `_bmad/bmm/workflows/4-implementation/create-story/template.md`. The "Pre-edit baseline" task captures `wc -c src/antforth.com` (or the appropriate build artifact path) directly, not inheriting from the prior story's reported number.

**B.4-D1: PD-2 figure-drift discipline.** Edit lands in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (sibling of B.2) as a `<critical>` block. Block requires figures, tables, code blocks to be validated against the source-of-truth at draft time, not inherited from earlier stories or retros.

**Verdict-criterion meta-pattern (all four):**
- B.1 — `tests/README.md` exists, references PAD with the canonical-buffer convention; `Makefile` test section has the pointer comment
- B.2 — synthesised "mirror" phrase fed into the drafting workflow surfaces the HALT signal
- B.3 — the template's pre-edit task references `wc -c` directly, grep-able from `_bmad/bmm/workflows/4-implementation/create-story/template.md`
- B.4 — the figure-drift `<critical>` block exists in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` and is grep-able

If a lead-in story fails its own verdict, it doesn't ship.

#### B.5 — PRD-vs-architecture transcription-drift sync

**B.5-D1:** new `make check-doc-sync` target, invoking a project-local script in `tools/check-doc-sync/`. The script walks the planning artifacts and produces a drift report on stdout (exit 1 on drift; exit 0 on clean-pass with one-line `[ok] doc-sync: 0 drift`).

**Drift checks:**
1. Every `FR-P3-N` / `NFR-P3-N` reference in `architecture.md` exists as a label in `prd.md`
2. Every `Story X.Y` citation in `architecture.md` resolves to an actual story header in `epics.md` (or its predecessor `epics-phase1-epics-1-8.md` / `epics-phase2-epics-9-13.5.md` if the citation is historical)
3. Every `§X.Y.Z` reference in `architecture.md`'s compliance-related sections has a matching row in `docs/ans-forth-core-compliance.md` (post-A.1 invariant)
4. Section-name parity check — both docs share the agreed-on top-level sections

**Failure mode:** advisory-only on `make test-repl` (does not block); expected clean before any tag-applicable close-out (S11 sibling — version-surface audit reads cleanly only when doc-sync also reads cleanly).

#### B.6 — `make check-tools` (iz-cpm version stability)

**B.6-D1:** new `make check-tools` target reading expected versions from a project-local `.tool-versions` file (new — added by B.6's story). Compares `iz-cpm --version` and `sjasmplus --version` (or equivalents) against expected.

**Failure mode:** advisory-only by default (exit 0 with stderr advisory). Optional `make check-tools STRICT=1` exits 1 on mismatch. Hard-failing every minor version drift would create friction for contributors on slightly different hosts; advisory + opt-in strict is the right tradeoff.

**`.tool-versions` initial content:** the iz-cpm + sjasmplus versions used to certify the v2.0 baseline (commit `6599d73`, 973 PASS / 0 FAIL). Subsequent bumps are story-level decisions recorded in commit history.

#### B.7 + B.9 — Filesystem stress coverage (combined)

**B.7-D1: conditional probe story trigger.** B.7 has two dispositions tracked in `docs/PHASE-3-CARRY-FORWARD.md`'s Status column:

- **(a) "Evaluation suffices"** — `✅ Evaluated, none required`, with closure note citing the hardware-smoke run that exercised the filesystem under load and produced no surprises
- **(b) "Probe story spawned"** — fires on a hardware-revealed signal: a probe returning a wrong `ior`, leaving an orphaned FCB, corrupting a CP/M directory entry, or failing to recover the FCB pool

If (b) fires, the spawned story follows `feedback_verdict_only_audit.md`'s "verdict-only audit + standalone reproducer + fix-story" pattern.

**B.9-D1: disk-full probe location.** Extend `tests/file_access_tests.fth` with a disk-full stress block. Probe shape:

1. Fill B: ramdisk to capacity (deterministic procedure)
2. Assert WRITE-FILE returns disk-full `ior`
3. Assert FCB pool remains consistent (no orphaned handles)
4. Assert filesystem remains consistent (clean CLOSE-FILE / re-OPEN-FILE round-trip on an existing file succeeds)

**Combined close-out shape:** one S9 hardware-smoke task on one Phase-3 story exercises both. The same fill-disk-then-stress procedure that exercises disk-full also exercises directory-full (when CP/M's directory-entry budget is hit) and zero-byte READ-FILE (trivial to add to the same probe block). Result lands in:

- `docs/PHASE-3-CARRY-FORWARD.md` Status column: B.7 row + B.9 row both updated with closure notes
- `tests/file_access_tests.fth`: disk-full probe block added permanently (B.9); directory-full / zero-byte READ-FILE probes added if disposition (b) fires for B.7
- Hardware-smoke transcript filed alongside the close-out story

#### B.8 — Test-numbering hygiene

**Decision:** mechanical Makefile renumber on the next Makefile-touching Phase-3 story (most likely B.5 or B.6). Renumber preserves test-case content and identity — only the leading numeric ID changes. No new architectural surface; cosmetic close-out.

---

### Decision Impact Analysis

**Implementation sequence (locked by carry-forward catalog):**

Per `docs/PHASE-3-CARRY-FORWARD.md` § "Suggested Phase-3 First-Epic Shape":

1. **Lead-in (must land first):** B.1 + B.2 + B.3 + B.4 + B.5
2. **Strategic body:** A.1 (audit) → 0–2 back-fill stories per gap surfaced
3. **Hitch-hikers (fold opportunistically):** A.2, A.3, B.6, B.8, B.9
4. **Conditional:** B.7 if hardware-revealed need from B.9 / S9 cadence

The lead-in (B.1–B.5) shapes every subsequent dev-pass; landing it first is the load-bearing sequencing constraint. CCD-P3-2 makes this structural: post-lead-in, the BMAD workflow files themselves enforce the discipline that subsequent stories inherit.

**Cross-component dependencies:**

- A.1's audit walk re-verifies every CCD-3 citation; mismatches surfaced are corrected as part of the audit story (creates a small dependency: the audit story's diff may include `src/*.asm` citation-comment fixes alongside the new `docs/ans-forth-core-compliance.md` rows)
- B.5's `make check-doc-sync` references stories in `epics.md` (or predecessors); it must land before the first PRD/architecture-touching Phase-3 story to be useful (which is why it's in the lead-in cluster, not a hitch-hiker)
- B.6's `.tool-versions` references the v2.0 baseline; bumping it is a story-level decision, not architecturally pinned here
- B.7 + B.9 share a hardware run; their close-out is intrinsically coupled
- A.2 caught-form tests assume the CCD-2 asm-error block is `-258..-272`; if a future Phase-3 story (unlikely) allocates new asm-error codes, A.2's test suite must extend correspondingly

**Per-story binary delta envelopes:**

| Item | Expected delta (bytes) |
|---|---|
| B.1 | 0 (doc only) |
| B.2 / B.3 / B.4 | 0 (workflow-file only) |
| B.5 | 0 (Makefile + script only) |
| B.6 | 0 (Makefile + `.tool-versions` only) |
| B.7 | 0..+30 if probe story spawned; 0 if (a) |
| B.8 | 0 (Makefile renumber) |
| B.9 | 0 (probe-only) |
| A.1 audit story | 0 (doc only) |
| A.1 back-fill story (per gap) | +10..+50 (Story 13.0 / 13.0.1 / 13.5 precedent) |
| A.2 | 0 (test-only) |
| A.3 | +0..+30 (small surgery in `w_NUMBER_Q_cf`) |

**Cumulative target:** +0..+200 bytes (24,996 → ≤ 25,200), dominated by 0–2 expected A.1 back-fill stories. NFR-P3-2 enforces the cap; per-story envelope checked at each dev-pass; HALT signal if any single story would push cumulative over.

**Tag-applicable close-out gates (S11 / NFR-P3-32):**

Every Phase-3 antforth 2.x point-release tag passes the user-visible version surface audit:

- Banner string in binary: `make` produces a binary whose banner reads the new 2.x version
- README version reference: aligned to the tag being applied
- Memory-file `description` fields: any memory entry citing the antforth version (e.g., `project_phase2_scope.md`) reads the new 2.x version

S11 + B.5 (`make check-doc-sync`) together form the close-out gate's documentation arm; S9 (per-story hardware smoke) forms the hardware arm; the verdict-table walk (per Story 13.5.6 precedent) consolidates both at the close-out story.

## Implementation Patterns & Consistency Rules

> **Phase-2 carry-forward.** All naming, format, and inter-word communication patterns from `architecture-phase2-epics-9-13.5.md` § "Implementation Patterns & Consistency Rules" continue to apply unchanged in Phase 3. This section covers only the Phase-3-specific additions: compliance-doc row authoring (CCD-P3-1), back-fill story shape (A.1-D3), workflow-file edit patterns (CCD-P3-2), probe-authoring discipline (S12 / B.1), and drafter discipline (B.2 / B.3 / B.4).

### Conflict Points Identified (Phase-3-specific)

Where multiple AI agents could make different choices in Phase-3 work:

- **Compliance-doc row granularity** — agent A writes one row per ANS *word*; agent B writes one row per ANS *§-rule* (the spec includes a word in §6.1.0350 plus a structural rule in §3.1.4.1 — both must have rows)
- **Back-fill story shape** — agent A ships implementation + new probe + hardware smoke; agent B adds the citation comment but skips the pre-fix negative-result confirmation
- **Workflow-file edit format** — agent A writes a `<critical>` block; agent B adds an inline `<note>` at a similar spot; agent C adds it to the wrong instructions file
- **Probe transient-buffer choice** — agent A uses PAD; agent B uses HERE; agent C uses S" — each was acceptable historically but only PAD is correct post-Phase-3 (per B.1)
- **"Mirrors prior arm" lint trigger** — agent A treats only the literal word "mirrors" as a HALT signal; agent B treats any comparison-to-prior-work shorthand
- **Compliance-doc Source column** — agent A writes `src/double.asm:120`; agent B writes `src/double.asm:w_TWO_FETCH_cf`; agent C writes a relative path

### Naming & Structure Patterns (Phase-3-specific)

**Compliance-doc row labels.** Per CCD-P3-1's 6-column schema:

- **§ column** — full DPANS94 / Forth-2014 §-number with explicit standard prefix when ambiguous (`§6.1.0350` for DPANS94 / ANS Forth 1994; `§3.4.1.3 (Forth 2014)` if the rule is Forth-2014-only). Structural rules use `§3.1.4.1 (Forth 2014 — high-on-TOS)` form.
- **Source column** — `file:line` format using the assembly source line of the `cf:` label (not the body or the dictionary header). Example: `src/double.asm:120` where line 120 is `w_TWO_FETCH_cf:`. For test-only closures: `tests/throw_migration_tests.fth:t<test-number>`. For non-implementation rows (structural-rule satisfied by absence-of-misbehaviour): `N-A`.
- **Closure column** — `Story X.Y` form (or `Story X.Y.Z` for sub-stories), or `v2.0 baseline` for pre-Phase-3 closures. A.1 audit-story rows use `Story P3.A1` (or whatever the actual A.1 story number becomes); A.1 back-fills use their per-gap story number.
- **Notes column** — kept short (≤ 120 chars typical); links to a ground-truth reference document if a longer caveat is needed (e.g., `revised by Story 13.0.1; see _bmad-output/implementation-artifacts/13-0-1-double-cell-flip.md`).

**Back-fill story file naming.** Per Phase-2 convention: `_bmad-output/implementation-artifacts/<epic>-<story>-<short-slug>.md`. A.1 back-fills use the audit story's epic number; the slug names the §-rule being back-filled (e.g., `phase3-a1-§6.2.1342-evaluate-input-source-frame.md`).

**Workflow-file edit identity.** Edits land in named files, never inline in conversation transcripts:
- Drafting `<critical>` blocks → `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`
- Task-list entries → `_bmad/bmm/workflows/4-implementation/create-story/template.md`
- Drafting checklist additions → `_bmad/bmm/workflows/4-implementation/create-story/checklist.md`
- Agent-definition extensions → `_bmad/bmm/agents/{dev,sm}.md` (or other named agent file)
- Installer manifest → BMAD installer's expected list of files (so structural edits survive installer re-runs)

### Format Patterns (Phase-3-specific)

**Compliance-doc row format example:**

```markdown
| §6.1.0350 | `2@: ( a-addr -- x1 x2 )` high cell on TOS, low cell second-on-stack | Implemented | src/double.asm:120 | Story 13.0.1 | revised by Story 13.0.1 (was low-on-TOS pre-flip) |
```

**`<critical>` block format example (B.2 / B.4 pattern):**

```xml
<critical>
When drafting the byte-budget rationale for a new story, if the rationale text contains any of the following phrasings:
  - "mirrors arm X from Story Y"
  - "same shape as Story Z"
  - "this is the X arm of the pattern from Story Y"
  - any equivalent comparison-to-prior-work shorthand

HALT and itemise the new arm's parts independently before accepting the byte-budget estimate. The mirror analogy is a red flag, not a justification. (Lesson 13.5-C; B.2 closure.)
</critical>
```

**Pre-edit baseline task entry example (B.3 pattern):**

```markdown
### Pre-edit baseline tasks

- [ ] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - **Do not** inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F)
- [ ] Capture current `make test-repl` baseline pass count
- [ ] [...other pre-edit tasks per template...]
```

### Communication Patterns — Phase-3-specific (inter-word contracts unchanged from Phase 2)

Phase 3 adds no new inter-word contracts. The Phase-2 contracts (BC = TOS, EXX leaf-level rule, exception-frame layout, INCLUDE source-frame layout, IY-relative user-area access, FCB-pool acquire/release semantics, the `file_byte_read` tri-state contract from Story 13.5.2) all carry forward.

**A.3-specific contract:** the `w_NUMBER_Q_cf` modification preserves the established stack-effect `( c-addr u -- n true | c-addr u false )` and the established register-clobbering envelope; only the BASE-aware-parsing branch logic changes. Tests must verify both the new behaviour and the unchanged stack contract (regression).

**A.2-specific contract:** the asm-error THROW codes' caught-form path uses the standard CATCH frame layout from CCD-1 — no new frame fields, no new escape mechanism. Caught-form tests use the canonical `' WORD CATCH . CR` idiom.

### Process Patterns (Phase-3-specific)

**Probe-authoring discipline (S12 / NFR-P3-33).** Every smoke-batch destined for human typing on real hardware passes both pre-flight checks before being committed:

1. **Word-existence pre-flight** — every word referenced in the probe resolves in antforth's dictionary (or is an explicit new word being introduced by the same story). Mechanical check: extract the words, cross-reference against `WORDS` output or kernel source. Any missing word is a HALT (recall Story-13.5.6's `CMOVE`-instead-of-`MOVE` incident).
2. **TIB-128 line-length lint** — every line in the probe is ≤ 128 characters. Mechanical check: `awk 'length > 128'` returns no rows. Probes intended for hardware-typing-by-human must split logically across lines that fit the input buffer.

**Probe transient-buffer choice (B.1).** Per `tests/README.md`'s canonical guidance:
- **Default to PAD** for any one-shot scratch buffer surviving a single space-delimited parse (per ANS §6.2.2000)
- Use `ALLOTed` named buffers (`B45`, `B46`, etc. per Story 13.5.1's pattern) for buffers that must survive across multiple parses
- **Avoid HERE for transient writes** — Story-13.5.1 surfaced a transient-buffer-collision incident where `S"` allocates near HERE; HERE C@ post-READ-FILE returned the residual S" byte rather than the read byte
- **Avoid S"-near-HERE writes for the same reason** — use ALLOTed buffers for read destinations

**Hardware-smoke cadence (S9 / NFR-P3-7).** Every binary-delta Phase-3 story runs its own hardware-smoke task on real CP/M 2.2 / MicroBeast with a PASS verdict before being declared done. Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped.

**"Mirrors prior arm" lint scope (B.2).** Triggers on:
- Literal "mirrors" / "same shape as" / "this is the X arm" phrasings in byte-budget rationale
- Any "Story Y" reference in a byte-budget rationale paragraph (pattern-match: "Story" + capital-letter or digit + cardinal/ordinal)
- The lint requires the drafter to **count the parts of the new arm** independently — listing each component (load, store, branch, return-stack manipulation, etc.) with its byte cost — before the rationale is accepted.

**Pre-fix negative-result confirmation (A.1-D3 / per-back-fill).** Each A.1 back-fill story includes an explicit demonstration that the pre-fix code fails the new probe:
1. Build the pre-fix binary (current HEAD before back-fill)
2. Run the new probe against the pre-fix binary
3. Capture the failure (wrong output, missing behaviour, ABORT, etc.)
4. Apply the back-fill
5. Re-run the same probe; capture the now-PASS verdict

The diff between pre-fix-FAIL and post-fix-PASS is the back-fill's primary verdict-criterion artefact.

### Enforcement Guidelines

**All Phase-3 dev-pass agents MUST:**

1. Author compliance-doc rows in CCD-P3-1's 6-column format — no shorthand, no row-format drift
2. Use the A.1-D3 back-fill story shape verbatim — six steps, including pre-fix negative-result confirmation
3. Land workflow-file edits in their designated files (CCD-P3-2 mapping) — never inline in transcripts, never in memory entries, never in `feedback_*.md` (those document *why*, not *enforcement*)
4. Pass the S12 probe-authoring pre-flight (word-existence + TIB-128) before committing any hardware-typed probe
5. Default to PAD for transient-buffer needs in REPL-piped probes; ALLOT for cross-parse buffers; never write near HERE
6. Run S9 hardware-smoke per binary-delta story; document exemption explicitly for zero-binary-delta stories
7. Honour S5 PARTIAL→HALT — any AC not fully PASS triggers HALT in-pass; root-cause is handled in-pass or the story spawns a sibling
8. Honour S8 — "pre-existing" cannot discharge correctness defects (clobbers, lost writes, silent error swallowing); surface, file, fix
9. Re-`wc -c` at the start of every dev-pass — never inherit the prior story's reported binary size

**Pattern enforcement mechanisms:**

- **Structural lints** in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (B.2/B.4 `<critical>` blocks) catch drafting-discipline gaps at draft time
- **Pre-edit baseline tasks** in the story template (B.3) catch binary-handoff drift at dev-pass start
- **`make check-doc-sync`** (B.5) catches PRD-vs-architecture drift at any time the maintainer runs it
- **`make check-tools`** (B.6) catches host-toolchain drift at any time the contributor runs it
- **S9 hardware smoke per binary-delta story** catches kernel-regression at dev-pass close
- **S11 user-visible version surface audit** (NFR-P3-32) catches version-banner drift at tag close-out
- **Adversarial code review (`/CR`)** post-PD-1 fresh-context — eleven-plus consecutive epic finding-rate held; catches whatever the structural lints don't

### Concrete Examples

**Good — compliance-doc row:**

```markdown
| §6.1.1561 | `FM/MOD: ( d1 n1 -- n2 n3 )` floored division: signed double / signed single → signed remainder, signed quotient | Implemented | src/double.asm:480 | Story 10.6 | quotient rounds toward -∞; remainder sign matches divisor |
```

**Bad — compliance-doc row (anti-pattern):**

```markdown
| 6.1.1561 | FM/MOD | yes | double.asm | E10 | works |
```

(Missing § prefix and standard cite, missing rule text, non-canonical verdict, relative path, ambiguous closure label, vacuous notes.)

**Good — back-fill story shape (skeleton):**

```markdown
### Story P3.A1.1: Back-fill §X.Y.Z structural rule

**AC:**
- AC1: Implementation in src/<file>.asm at <line>; standards-citation comment per CCD-3
- AC2: New row in docs/ans-forth-core-compliance.md per CCD-P3-1
- AC3: REPL probes in tests/<harness>.fth — positive path + edge case
- AC4: S9 hardware smoke on real CP/M 2.2 / MicroBeast — PASS verdict
- AC5: Pre-fix negative-result confirmation — pre-fix binary fails new probe, post-fix passes; diff captured in Dev Notes
- AC6: ROM delta within +0..+50 bytes; HALT if outside envelope
```

**Bad — back-fill story shape (anti-pattern):**

```markdown
### Story P3.A1.1: Add the missing rule

**AC:**
- AC1: Implement the rule
- AC2: Tests pass
```

(Missing CCD-3 citation, missing CCD-P3-1 row, missing pre-fix negative-result confirmation, missing S9 hardware smoke, no envelope.)

**Good — `<critical>` workflow edit (file: `instructions.xml`):**

```xml
<critical>
B.2 / Lesson 13.5-C — "mirrors prior arm" HALT signal:

When drafting the byte-budget rationale for a new story, if the rationale text contains any of:
  - "mirrors arm X from Story Y"
  - "same shape as Story Z"
  - any equivalent comparison-to-prior-work shorthand
HALT and itemise the new arm's parts independently before accepting the estimate.

The mirror analogy is a red flag, not a justification. (TD-7 / Story 13.5.5 overshot pick (a) +50..+100 by 40 bytes via this exact shorthand.)
</critical>
```

**Bad — workflow edit (anti-pattern):**

In a memory entry `feedback_no_mirror_shorthand.md`:
> Don't use "mirrors prior arm" without itemising the parts.

(Lives in the *why* surface, not the *enforcement* surface. Drafter has to remember to invoke it. CCD-P3-2 / S10 violation.)

**Good — probe transient buffer:**

```forth
\ Test: PAD-based transient buffer (B.1 canonical idiom)
: T-PROBE-PAD
  PAD 64 ERASE
  S" hello" PAD SWAP CMOVE
  PAD C@ 'h' = ;
```

**Bad — probe transient buffer:**

```forth
\ Anti-pattern: HERE-based transient buffer (Story 13.5.1 collision)
: T-PROBE-HERE
  HERE 64 ERASE
  S" hello" HERE SWAP CMOVE   \ S" allocates near HERE — collision!
  HERE C@ 'h' = ;
```

## Project Structure & Boundaries

> **Phase-2 carry-forward.** The full project directory structure from `architecture-phase2-epics-9-13.5.md` § "Project Structure & Boundaries" carries forward unchanged. Phase 3 does not restructure the codebase — it adds a small set of new files and modifies a focused set of existing ones. This section enumerates only the **Phase-3 file-touch surface**.

### Phase-3 File-Touch Surface

#### New files created in Phase 3

| Path | Purpose | Carry-forward item |
|---|---|---|
| `tests/README.md` | Test-author guidance: PAD-as-canonical-transient-buffer, S12 probe-authoring discipline, hardware-typed probe lints | B.1 |
| `tools/check-doc-sync/check-doc-sync.<sh\|py>` | Project-local script: PRD↔architecture transcription-drift checker | B.5 |
| `tools/check-doc-sync/README.md` | Tool documentation (drift-check rules, exit codes, intended cadence) | B.5 |
| `.tool-versions` | Pinned `iz-cpm` and `sjasmplus` versions used to certify the v2.0 baseline | B.6 |
| `_bmad-output/implementation-artifacts/phase3-a1-<§-rule>-<slug>.md` | A.1 back-fill story files (one per §-level structural-rule gap surfaced; 0–2 expected) | A.1 back-fills |
| `_bmad-output/implementation-artifacts/<epic>-retro-<date>.md` | Phase-3 retrospective(s) at epic close-out | per-epic |

Path under `tools/check-doc-sync/` follows the `tools/bdos_probe/` precedent (Story 11.5.1 firmware reproducer); a self-contained subdirectory keeps tool logic separable from the kernel build.

#### Existing files modified in Phase 3

| Path | Changes | Carry-forward item |
|---|---|---|
| `Makefile` | Add `check-doc-sync` PHONY target (B.5); add `check-tools` PHONY target (B.6); renumber duplicate test IDs in `test-repl` recipe (B.8); add pointer comment to `tests/README.md` from test section (B.1) | B.5, B.6, B.8, B.1 |
| `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` | Add `<critical>` block for "mirrors prior arm" HALT signal (B.2); add `<critical>` block for figure-drift discipline (B.4) | B.2, B.4 |
| `_bmad/bmm/workflows/4-implementation/create-story/template.md` | Add `wc -c` task to "Pre-edit baseline" section (B.3) | B.3 |
| `_bmad/bmm/workflows/4-implementation/create-story/checklist.md` | Update drafting checklist for B.1–B.5 cluster awareness (if needed) | B.1–B.5 |
| `docs/ans-forth-core-compliance.md` | A.1 audit walk produces §-level rows for §6.1, §6.2, structural rules per CCD-P3-1 schema; row count grows from current word-count baseline to §-level coverage | A.1 |
| `docs/PHASE-3-CARRY-FORWARD.md` | Status column updated per item as each closes (`✅ Done` with closure note) | per-item |
| `tests/throw_migration_tests.fth` | Add caught-form probes for the `-258..-272` asm-error block (15 codes) per A.2 | A.2 |
| `tests/file_access_tests.fth` | Add disk-full stress block (B.9); add directory-full + zero-byte READ-FILE probes if B.7 disposition (b) fires | B.9, B.7 conditional |
| `src/strings.asm` | Modify `w_NUMBER_Q_cf` for unprefixed-numeral base-specialization (A.3); regression-only otherwise | A.3 |
| `src/antforth.asm` (banner string) | Update version banner for each Phase-3 antforth 2.x point-release (S11 / NFR-P3-32) | every tag |
| `README.md` | Update version reference for each Phase-3 antforth 2.x point-release (S11 / NFR-P3-32) | every tag |
| `memory/project_phase2_scope.md` (or successor) | Update `description` fields citing antforth version at each tag close-out (S11 / NFR-P3-32) | every tag |
| `_bmad-output/implementation-artifacts/sprint-status.yaml` | Story status updates per Phase-3 dev-pass close | every story |

#### Files explicitly NOT touched in Phase 3

| Path | Reason |
|---|---|
| `src/assembler.asm` | Per `project_assembler_keep_assembly.md` — assembler stays kernel-resident hard-coded; no ASSEMBLER wordlist; A.2 closes asm-error caught-form gap via test harness only, no kernel changes |
| `src/inner_interpreter.asm`, `src/outer_interpreter.asm` | Threading model and outer-interpreter loop frozen for Phase 3; no changes expected |
| `src/exception.asm` | Exception subsystem complete post-Story-11.7; A.2 is test-only |
| `src/file_access.asm` | File-access subsystem complete post-Epic-13.5; B.7/B.9 are test-only unless hardware reveals defects |
| `src/wordlists.asm`, `src/compiler.asm`, `src/dictionary.asm`, `src/hash.asm`, `src/control_flow.asm` | Phase-2 subsystems frozen for Phase 3 |
| `src/structures.asm` (UserArea layout) | Frozen for Phase 3; banking design (`docs/antforth-banking-design.md`) deferred to Phase 4 |
| `disk/`, `build/`, `examples/`, `blog/`, `images/`, `reference_docs/`, `node_modules/` | No Phase-3 surface |

#### A.1 back-fill conditional touch surface

If an A.1 back-fill story is spawned (0–2 expected), it may touch:
- One or more `src/*.asm` files (the implementation site for the §-rule being back-filled)
- `docs/ans-forth-core-compliance.md` (new row per CCD-P3-1)
- One or more `tests/*.fth` harnesses (depending on which subsystem the rule belongs to)
- `src/constants.asm` if the back-fill introduces a new EQU symbol (unlikely but possible)

The back-fill story shape (per A.1-D3) constrains the touch surface: implementation + citation comment + new compliance-doc row + REPL probes + S9 hardware smoke + pre-fix negative-result confirmation.

### Architectural Boundaries

**Kernel boundary (frozen for Phase 3):**

The Z80 assembly kernel surface (`src/*.asm` minus `src/strings.asm`'s A.3 surgery) is frozen for Phase 3 with one exception: A.1 back-fill stories may surface kernel surgery (constrained to the affected `cf:` label). Otherwise, the kernel is the v2.0 binary baseline; Phase-3 binary growth is dominated by 0–2 expected A.1 back-fills (~+10..+50 each) and the small A.3 surgery (~+0..+30).

**Test-harness boundary:**

Tests are REPL-piped Forth scripts in `tests/*.fth` (per S2). New probes added in Phase 3:
- `tests/throw_migration_tests.fth` extension — A.2 caught-form coverage for `-258..-272`
- `tests/file_access_tests.fth` extension — B.9 disk-full block, B.7 conditional probes
- A.1 back-fill stories add probes to the appropriate harness (`core_tests.fth`, `double_tests.fth`, `pictured_tests.fth`, etc., per §-rule subsystem)

No new test-harness file is created in Phase 3 — extension over creation.

**Documentation boundary:**

- **Standards-compliance doc** (`docs/ans-forth-core-compliance.md`) — A.1 produces §-level rows per CCD-P3-1; row format is the contract that makes NFR-P3-13 ("checkable in under 10 minutes per row") true
- **Phase-3 catalog** (`docs/PHASE-3-CARRY-FORWARD.md`) — status table updated per item; living document throughout the phase
- **Test-author guidance** (`tests/README.md`, NEW) — single source of truth for probe-authoring conventions (PAD-as-canonical, S12 lints)
- **Tool documentation** (`tools/check-doc-sync/README.md`, NEW) — drift-checker rules and intended cadence
- **`docs/dev_journal.md`** — engineering log; touched by author at his discretion, not architecturally pinned (per user preference, not loaded into this workflow)

**Tooling boundary:**

- **Makefile** is the build and test orchestrator; Phase-3 adds two PHONY targets (`check-doc-sync`, `check-tools`) and one renumber pass (B.8). Default `make` behaviour unchanged.
- **`.tool-versions`** is a pinned-versions manifest used by `make check-tools`. Format: `<tool> <version>` per line.
- **`tools/check-doc-sync/`** is a self-contained drift-checker; language choice (Bash, Python, etc.) deferred to B.5's story-author. Output format pinned: `[ok] doc-sync: 0 drift` on clean, line-per-drift on failure with exit 1.

**Workflow-file boundary (BMAD enforcement surface, per CCD-P3-2):**

- `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` — drafting `<critical>` blocks land here
- `_bmad/bmm/workflows/4-implementation/create-story/template.md` — task-list entries land here
- `_bmad/bmm/workflows/4-implementation/create-story/checklist.md` — drafting-checklist updates if any
- `_bmad/bmm/agents/dev.md`, `_bmad/bmm/agents/sm.md` — agent extensions for cross-cutting commands; Phase-3 may not touch these (no equivalent of PD-1's CR-cadence-extension expected)

### Requirements-to-Structure Mapping

| Carry-forward item | Touches |
|---|---|
| **A.1** §-by-§ audit | `docs/ans-forth-core-compliance.md` (audit-story rows); 0–2 back-fill stories conditionally touching `src/*.asm` + `tests/*.fth` |
| **A.2** caught-form coverage | `tests/throw_migration_tests.fth` |
| **A.3** NUMBER? base-spec | `src/strings.asm:w_NUMBER_Q_cf`; regression probes in `tests/number_prefixes_tests.fth` |
| **B.1** PAD doc | `tests/README.md` (NEW); `Makefile` test-section pointer comment |
| **B.2** "mirrors" HALT | `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` |
| **B.3** re-`wc -c` | `_bmad/bmm/workflows/4-implementation/create-story/template.md` |
| **B.4** figure-drift | `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` |
| **B.5** doc-sync | `tools/check-doc-sync/` (NEW); `Makefile` `check-doc-sync` target |
| **B.6** check-tools | `.tool-versions` (NEW); `Makefile` `check-tools` target |
| **B.7** stress-matrix | Conditional: `tests/file_access_tests.fth` (if hardware reveals defect) |
| **B.8** test renumber | `Makefile` (test-repl recipe) |
| **B.9** disk-full | `tests/file_access_tests.fth` |
| **S11** version surface | `src/antforth.asm` banner; `README.md`; `memory/project_phase2_scope.md` (or successor `description` fields) per tag |
| **S9** hardware smoke | Per-story closure transcript — filed alongside dev-pass story file |

### Integration Points

**Internal communication (no change from v2.0):**

The kernel's internal subsystem boundaries — outer interpreter ↔ compiler ↔ dictionary ↔ search-order ↔ exception subsystem ↔ file-access — all carry forward unchanged. Phase 3 does not introduce new internal communication paths. CCD-1 dual-chain frame discipline (CATCH-TOP / INCLUDE-TOP) and CCD-2 THROW code allocation continue to govern cross-subsystem error flow.

**External integrations:**

- **CP/M 2.2 BDOS** — function allow-list per NFR-P3-11 unchanged; Phase 3 does not add any new BDOS functions
- **iz-cpm emulator** — used by `make test-repl`; version pinned via `.tool-versions` (B.6)
- **sjasmplus assembler** — used by `make` for kernel build; version pinned via `.tool-versions` (B.6)
- **MicroBeast hardware** — used by S9 hardware smoke for every binary-delta story; transcript binary captured under `~/Downloads/bestialitty-<date>.bin` per established naming
- **GitHub releases** — antforth 2.x point-release tags published as github releases (S11 sibling)

**Data flow (no change from v2.0):**

User Forth source → REPL or `INCLUDE` → outer interpreter → compiler / interpreter → dictionary lookup (multi-vocabulary) → execution. Errors flow through CATCH/THROW per CCD-1; uncaught errors land in the inlined `.throw_uncaught` recovery chain (`src/exception.asm:412+`) and re-enter the REPL with state reset.

### File Organisation Patterns

**Kernel source:** `src/*.asm` — one file per subsystem (frozen for Phase 3 except A.3's `src/strings.asm` surgery and A.1 back-fill conditional touches).

**Test sources:** `tests/*.fth` — one file per subsystem-or-feature (extended in Phase 3, never new files).

**Documentation:** `docs/*.md` — flat directory; Phase-3 modifies `ans-forth-core-compliance.md` (A.1) and `PHASE-3-CARRY-FORWARD.md` (status); `tests/README.md` is colocated with the tests.

**Planning artifacts:** `_bmad-output/planning-artifacts/*.md` — PRD, architecture, epics, briefs, sprint-change proposals, readiness reports. Phase-3 archives the Phase-2 architecture (already done at workflow start) and writes the Phase-3 architecture (this document).

**Implementation artifacts:** `_bmad-output/implementation-artifacts/*.md` — per-story dev notes + retrospectives + sprint-status. Phase-3 adds back-fill story files and the eventual Phase-3 retrospective.

**Tools:** `tools/<tool-name>/` — self-contained tool subdirectories (per `tools/bdos_probe/` precedent); Phase-3 adds `tools/check-doc-sync/` (B.5).

### Development Workflow Integration

**Build:** `make` (or `make asm`) → `build/antforth.com`. Unchanged.

**Test:** `make test-repl` → runs the full `tests/*.fth` suite under iz-cpm. Phase-3 may add probes that extend the suite; the recipe is renumbered by B.8 once during the phase.

**Doc-sync (NEW, opt-in):** `make check-doc-sync` → runs `tools/check-doc-sync/` script; clean-pass is `[ok] doc-sync: 0 drift`; expected before any tag-applicable close-out (S11 sibling).

**Tool-version check (NEW, opt-in):** `make check-tools` → advisory by default; `make check-tools STRICT=1` exits 1 on mismatch.

**Hardware smoke (S9):** binary copied to MicroBeast via established serial / SD-card path; smoke probes typed by hand or piped from a hardware-typed Forth file. Transcript captured. Per-story closure references the transcript.

**Tag close-out (S11):** verdict-table walk per Story-13.5.6 precedent; banner / README / memory `description` fields all aligned to the new 2.x version; `make check-doc-sync` clean-pass; full `make test-repl` clean (973+ PASS / 0 FAIL); hardware smoke clean. Tag applied.

## Architecture Validation Results

### Coherence Validation

**Decision compatibility:** All Phase-3 decisions cohere with the v2.0 baseline:
- A.1 / A.2 / A.3 layer onto existing subsystems without restructuring; CCD-P3-1's row schema is consistent with the existing `docs/ans-forth-core-compliance.md` format extended for §-level granularity
- B.1–B.9 either touch new files (`tests/README.md`, `tools/check-doc-sync/`, `.tool-versions`) or extend existing files (`Makefile`, story-template files) — no replacement, no version conflict
- CCD-1..CCD-4 (Phase-2) carry forward unchanged; CCD-P3-1 and CCD-P3-2 are net additions, not overrides
- The "Phase 3 wins → Phase 2 → Phase 1" precedence chain is transitively correct (Phase 2 already governed by the same rule for its inheritance from Phase 1)

**Pattern consistency:** Phase-3 patterns extend Phase-2 patterns without contradiction. The only behavioural-change site is A.3's `w_NUMBER_Q_cf`; everything else is additive (new probes, new doc rows, new workflow-file entries).

**Structure alignment:** The Phase-3 file-touch surface is small and well-scoped; no two carry-forward items target overlapping kernel sites. A.1 back-fill stories may touch any `src/*.asm` based on which §-rule is back-filled, but each touch is constrained to a single `cf:` label per the back-fill story shape.

### Requirements Coverage Validation

**Functional Requirements (FR-P3-1..25 + Phase-2 carry-forward):**

| Coverage | Status |
|---|---|
| All 25 FR-P3-N requirements map to at least one architectural decision | ✅ verified via the Requirements-to-Structure Mapping table |
| Phase-2 FR1–FR47 preserved via FR-P3-22 | ✅ explicit carry-forward statement; A.3 is the only behavioural change and is documented as a refinement of Phase-2 FR9 / FR47 (unprefixed BASE-aware parsing) |
| All 12 P1 carry-forward items covered | ✅ A.1, A.2, A.3, B.1, B.2, B.3, B.4, B.5, B.6, B.7, B.8, B.9 — all addressed |

**Non-Functional Requirements (NFR-P3-1..33):**

| Coverage | Status |
|---|---|
| Performance NFR-P3-1..2 (Phase-2 envelopes + cumulative ROM cap) | ✅ per-story envelope table in Decision Impact Analysis enforces NFR-P3-2 |
| Reliability NFR-P3-3..7 | ✅ S9 cadence codified as NFR-P3-7; FCB-pool consistency in B.7/B.9 closure shape |
| Compatibility & Standards NFR-P3-8..13 | ✅ CCD-P3-1 schema delivers NFR-P3-13 row-checkability |
| Maintainability NFR-P3-14..18 | ✅ workflow-file enforcement surface in CCD-P3-2 delivers NFR-P3-18 |
| Integration NFR-P3-19..21 | ✅ no new BDOS functions, bank-0 only, terminal I/O unchanged |
| Process Discipline NFR-P3-22..33 (S1–S12) | ✅ each codified; B.1–B.5 lead-in cluster + verdict-criterion meta-pattern enforces structural hold |

**Cross-cutting concerns coverage:**

| Concern (from § "Cross-Cutting Concerns Identified") | Architectural address |
|---|---|
| §-level compliance documentation (A.1) | CCD-P3-1 (row schema) + A.1-D2 (decomposition) + A.1-D3 (back-fill shape) |
| Process discipline as workflow-file edits | CCD-P3-2 + B.1/B.2/B.3/B.4 per-item decisions |
| Standing-commitment hold (S1–S12) | NFR-P3-22..33 codified; verdict-criterion meta-pattern per B.x lead-in |
| Backward-compatibility / regression invariants | FR-P3-22..25 + NFR-P3-6 enforced per Phase-3 dev-pass close |
| ROM budget discipline | NFR-P3-2 + per-story envelope table |
| Asm-error THROW code block contiguity | CCD-2 reaffirmation (Phase-3-extended block -258..-272); A.2 caught-form coverage closes the block |

### Findings (genuine issues requiring resolution)

**Per the project's adversarial-review discipline (memory: "reviews MUST find things; zero findings is suspect"), surfacing the following before declaring ready-for-implementation:**

#### F1 — CCD-P3-1 verdict set: satisfied-behaviourally case

**Issue:** The 4-value verdict set (`Implemented` / `Implemented-with-caveat` / `Accepted-with-rationale-N-A` / `Deliberately-omitted`) doesn't cleanly cover §-rules that antforth satisfies *behaviourally* without a specific implementation site (e.g., a structural rule like "the system MUST NOT assume aligned cell addresses" — antforth satisfies this by construction, not by a specific code path).

**Resolution:** Reuse `Implemented` with `Source: N-A` and an explanatory Notes entry. The audit story's first verdict-criterion artefact establishes this as the canonical pattern via at least one example. No verdict-set expansion needed.

**Action:** A.1 audit story includes an explicit row-pattern example for the satisfied-behaviourally case in its Dev Notes; the example is `§3.1.4.1 alignment | 'cell access never assumes alignment' | Implemented | N-A | v2.0 baseline | satisfied behaviourally — every memory access in src/*.asm uses byte-or-cell ops with no alignment assumption`.

#### F2 — B.7+B.9 combined hardware run scope tightening

**Issue:** The Phase-3 architecture says "the same fill-disk-then-stress procedure that exercises disk-full also exercises directory-full". This conflates two different CP/M 2.2 failure modes — disk-full is exhaustion of *block storage*; directory-full is exhaustion of *directory entries* (CP/M directories are 64–128 entries). A single large file exhausts disk-full but not directory-full; many small files exhaust directory-full but maybe not disk-full.

**Resolution:** B.9's hardware probe procedure is split into two sub-steps:
- **Sub-step (a)** — disk-full: one large file written until WRITE-FILE returns disk-full ior
- **Sub-step (b)** — directory-full: many small files created until CREATE-FILE returns directory-full ior (or the equivalent CP/M ior code)

Both sub-steps assert FCB-pool consistency and filesystem consistency post-failure. The combined run resolves B.9 (disk-full sub-step) and B.7 disposition (directory-full sub-step + zero-byte READ-FILE single-call).

**Action:** B.9's story specifies the two sub-steps explicitly; the architecture's § "B.7 + B.9 — Filesystem stress coverage (combined)" is read with this clarification.

#### F3 — CCD-P3-2 "structural enforcement" overclaim in LLM-agent contexts

**Issue:** CCD-P3-2 says "Lints fire structurally (template-level enforcement), not aspirationally." In PD-1's precedent (Story 13.5.0), "structural" meant *file deletion* and *workflow-step retargeting* — workflow-as-runtime physically cannot run a step that no longer exists. In Phase-3's B.2/B.3/B.4, "structural" means *a `<critical>` block exists in instructions.xml* — but an LLM agent reading the instructions.xml could theoretically ignore the block. Enforcement is not the same as in PD-1's case.

**Resolution:** Clarify that CCD-P3-2's "structural" refers to *artifact existence* (grep-able verdict criteria), not automated-CI enforcement. The discipline is: the workflow-file edit makes the lint *visible to every drafter* without requiring memory recall; agent obedience to the visible lint is the residual softer discipline that adversarial review (`/CR`) catches.

**Action:** CCD-P3-2's wording is correct in spirit but read with this clarification. The verdict criteria for B.2/B.3/B.4 (grep-able artifacts) are the structural part; the agent-obedience part is the same as every other structural discipline in the project (S1, S2, S5, S8, S10).

#### F4 — B.6 `.tool-versions` initial content is undetermined

**Issue:** The architecture says `.tool-versions`'s initial content is "the iz-cpm + sjasmplus versions used to certify the v2.0 baseline (commit `6599d73`)". These versions aren't currently recorded anywhere in the v2.0 working tree.

**Resolution:** B.6's story includes an introspection task: capture `iz-cpm --version` and `sjasmplus --version` on the host that produced the certified `make test-repl` 973 PASS / 0 FAIL run, and pin those versions in `.tool-versions`. If the versions can't be retroactively determined (e.g., host has been updated), the story records the *current* host's versions as the new pinned baseline and notes the lack of v2.0 traceback.

**Action:** B.6's story has an explicit introspection sub-task and a fallback path for the un-traceable case.

#### F5 — A.3 site decision is load-bearing for FR-P3-24

**Issue:** A.3-D1's site decision (`w_NUMBER_Q_cf` in `src/strings.asm`) was framed as deferring the *spec* to the story-author. But the *site* is load-bearing: an alternative site (e.g., a new `w_NUMBER_QQ_cf` entry word) would change the dictionary layout and could violate FR-P3-24 (CODE-source byte-identical assembly under Phase-3 antforth) for any user code that calls NUMBER?.

**Resolution:** The site decision is binding — A.3's story implements the change in `w_NUMBER_Q_cf`; alternative-site proposals require sprint-change-proposal evaluation, not story-level discretion.

**Action:** A.3's story spec explicitly acknowledges the site decision is binding; story-author discretion is over the *behaviour delta* (precise BASE-validity rules), not the site.

#### F6 — A.1 audit story scope: citation-cleanup overflow

**Issue:** The architecture says A.1's audit walk "re-verifies every CCD-3 citation; mismatches are surfaced and corrected as part of the audit story". If the audit surfaces > 20 citation-comment mismatches, the audit story's diff blows up beyond reasonable single-story scope.

**Resolution:** Pin a sub-envelope: if A.1's audit walk surfaces > 20 citation-comment mismatches against the new §-level rows, those mismatches spawn a follow-up "citation cleanup" hitch-hiker story rather than landing in the audit story itself. The audit story's diff is bounded to: doc rows added + ≤ 20 in-pass citation fixes.

**Action:** A.1's story spec includes this sub-envelope. If the threshold fires, a follow-up "citation cleanup" story is spawned per the standing pattern (verdict-only audit + standalone reproducer + fix-story per `feedback_verdict_only_audit.md`).

#### F7 — A.1 row grain: word vs. structural-rule clarity

**Issue:** The architecture's CCD-P3-1 example rows mix word-rows (`§6.1.0350` for `2@`) and structural-rule-rows (`§3.1.4.1 (Forth 2014)` for high-on-TOS). A naive audit-walker might produce only one or the other.

**Resolution:** Audit walk produces a row for every mandatory §-rule (both word definitions and structural §-rules). Some §-numbers appear once (a word with no separate structural rule constraining it); others appear multiple times (the word's row + a structural rule that constrains its layout). This is consistent with DPANS94's structure but must be explicit in the audit story spec.

**Action:** A.1's story spec lists the expected rows from a walked-through example like §6.1.0350 (the `2@` word) — produces (a) a row for the word's stack-effect + standard reference and (b) a row for the §3.1.4.1 high-on-TOS structural constraint that applies to it. The two rows are linked via the Notes column.

### Gap Analysis

**Critical gaps (block implementation):** none. Findings F1–F7 are actionable in their owning stories without architectural change.

**Important gaps (could improve smoother implementation):**
- The architecture document doesn't enumerate the *exact* set of §6.2 (Core Extension) words antforth implements (the v2.0 baseline post-Epic-13.5 says 14/46 selectively but doesn't list which 14). A.1's audit walk produces this enumeration as a side-effect; until A.1 lands, the §6.2 coverage spec is under-specified. Mitigation: A.1 is the strategic body of Phase 3, so this gap closes as the phase progresses.
- The "back-fill story shape" (A.1-D3) doesn't explicitly cover *how* a §-level structural-rule-only back-fill (no specific word, no specific code site) is implemented. Story 13.0.1 was a structural-rule-only back-fill (§3.1.4.1) but it touched code (the double-cell-flip across `src/double.asm`). A back-fill that's *truly* structural (e.g., satisfied behaviourally) might land as a doc row + new probe + S9 hardware smoke without any kernel surgery. Mitigation: A.1-D3's six-step shape allows step 1 to be `tests/*.fth`-only for test-only closures; structural-rule closures use the same allowance.

**Nice-to-have gaps:**
- A `make clean-all-and-validate` target that runs `make clean && make && make test-repl && make check-doc-sync` in sequence as a single tag-applicable close-out gate. Could land as a B.5 hitch-hiker. Not gating any Phase-3 deliverable.
- A `tools/check-doc-sync/` CI integration (e.g., GitHub Actions). Out of scope for Phase 3 (no current CI in the repo); mention as a Phase-4+ candidate.

### Architecture Completeness Checklist

**Requirements Analysis:**
- [x] Project context thoroughly analyzed (25 FR-P3-N + carry-forward of 47 Phase-2 FRs; 33 NFR-P3-N across 6 categories)
- [x] Scale and complexity assessed (low; debt-cleanup interlude shape)
- [x] Technical constraints identified (bank-0 only, no new BDOS, +200-byte ROM cap, 973 PASS / 0 FAIL baseline)
- [x] Cross-cutting concerns mapped (6 concerns, each with architectural address)

**Architectural Decisions:**
- [x] Critical decisions documented (A.1-D1/D2/D3, A.2-D1, A.3-D1, B.1-D1, B.2/B.3/B.4-D1, B.5-D1, B.6-D1, B.7-D1, B.9-D1)
- [x] CCDs documented (CCD-1..CCD-4 carry-forward; CCD-P3-1, CCD-P3-2 new)
- [x] Integration patterns defined (no change from v2.0; documented as carry-forward)
- [x] Performance considerations addressed (NFR-P3-1 carry-forward + NFR-P3-2 cumulative ROM cap)

**Implementation Patterns:**
- [x] Naming conventions established (CCD-P3-1 row schema; back-fill story file naming; workflow-file edit identity)
- [x] Structure patterns defined (Phase-2 carry-forward; Phase-3 additions in Implementation Patterns section)
- [x] Communication patterns specified (no new inter-word contracts; A.3 preserves stack-effect; A.2 uses canonical CATCH idiom)
- [x] Process patterns documented (S1–S12 codified as NFR-P3-22..33; verdict-criterion meta-pattern)

**Project Structure:**
- [x] Phase-3 file-touch surface enumerated (new + modified + NOT-touched tables)
- [x] Component boundaries established (kernel frozen except A.3 + A.1 back-fills; tooling boundary; workflow-file boundary)
- [x] Integration points mapped (BDOS allow-list unchanged; iz-cpm/sjasmplus version-pinned via B.6)
- [x] Requirements-to-structure mapping complete (table maps every carry-forward item to specific files)

**Validation:**
- [x] Coherence validation complete
- [x] Requirements coverage verified
- [x] Implementation readiness assessed
- [x] **Findings F1–F7 surfaced and resolution paths assigned to owning stories**
- [x] Gap analysis completed (critical: 0; important: 2; nice-to-have: 2)

### Architecture Readiness Assessment

**Overall Status:** **READY FOR IMPLEMENTATION** with F1–F7 actionable in owning stories.

**Confidence Level:** **High**, on the following bases:
- 0 new subsystems means 0 new architectural surfaces with unknown failure modes
- All decisions are concrete (CCD-P3-1 row schema specific, A.1-D3 back-fill template specific, file-touch surface enumerated to file:item)
- v2.0 baseline (973 PASS / 0 FAIL on real hardware, eleven-plus epic standing-commitment hold) provides a known-good foundation
- The phase follows the proven Epic-13.5 pattern at phase scale (process-recovery vehicle → tag close-out)

**Key strengths:**
- Discipline-as-deliverable framing for B.x stories (verdict-criterion meta-pattern) prevents discipline-edits from regressing into aspirational documentation
- §-level compliance audit (A.1) closes the structural blindspot the Epic-13 retro identified ("Epic 10's '100% Core' claim was word-counted, not §-counted") at framework scale
- Combined B.7+B.9 hardware run consolidates two carry-forward items into one S9 task — denser per hardware run, lighter on phase ceremony
- Single-audit-story decision (A.1-D2) preserves momentum for the strategic body without over-decomposing
- All 12 standing commitments (S1–S12) codified as NFRs — process discipline is now an architectural quality attribute, not aspirational guidance

**Areas for future enhancement (Phase-4+):**
- Banking architecture (`docs/antforth-banking-design.md`) — strategic enabler for the ~25 KB binary ceiling; design exists but is explicitly Phase-4 deferred
- `make clean-all-and-validate` consolidated tag-close-out target (B.5 hitch-hiker candidate)
- CI integration for `tools/check-doc-sync/` (Phase-4+ candidate; no current CI in repo)
- §6.2 (Core Extension) coverage expansion as a side-effect of A.1 audit walk

### Implementation Handoff

**AI Agent Guidelines:**

- Follow all Phase-3 architectural decisions exactly as documented in this document; where Phase-3 is silent, consult `architecture-phase2-epics-9-13.5.md`; where Phase-2 is silent, consult `architecture-phase1-epics-1-8.md`
- Use Phase-3 implementation patterns consistently (CCD-P3-1 row schema, A.1-D3 back-fill shape, CCD-P3-2 workflow-file edit identity, B.1 PAD-as-canonical, S12 probe-authoring discipline)
- Respect the kernel-frozen-except-A.3-and-A.1-back-fills boundary — propose any other kernel surgery via sprint-change-proposal, not story-level discretion
- Honour S1–S12 standing commitments codified as NFR-P3-22..33; the verdict-criterion meta-pattern makes B.x lead-in stories discipline-as-deliverable
- Address findings F1–F7 in their owning stories' specs (the audit story carries F1, F6, F7; B.9's story carries F2; A.3's story acknowledges F5; B.6's story carries F4; CCD-P3-2's wording-clarification F3 is read with this section)
- Refer to this document for all Phase-3 architectural questions; do not improvise

**First Implementation Priority:**

The lead-in cluster (B.1 + B.2 + B.3 + B.4 + B.5) lands first per `docs/PHASE-3-CARRY-FORWARD.md` § "Suggested Phase-3 First-Epic Shape". Recommended sequencing within the lead-in:

1. **B.1** first — `tests/README.md` exists, PAD documented as canonical (closes Epic-12 retro A1 belatedly)
2. **B.2 + B.4** together — `<critical>` blocks added to `instructions.xml` (sibling edits, single dev-pass)
3. **B.3** — `wc -c` task added to `template.md` (single-file edit)
4. **B.5** — `tools/check-doc-sync/` script + Makefile target

After lead-in lands, **A.1 audit story** is the strategic-body kickoff. Hitch-hikers (A.2, A.3, B.6, B.8, B.9) fold opportunistically; B.7 is conditional on B.9's hardware run.
