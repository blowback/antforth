---
date: 2026-05-08
project: antforth
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
verdict: READY
findings:
  critical: 0
  major: 0
  minor: 8
  prdClarifications: 6
filesIncluded:
  prd: prd.md
  architecture: architecture.md
  epics: epics.md
  ux: null
historicalContext:
  - prd-phase1-epics-1-8.md
  - prd-phase2-epics-9-13.5.md
  - architecture-phase1-epics-1-8.md
  - architecture-phase2-epics-9-13.5.md
  - epics-phase1-epics-1-8.md
  - epics-phase2-epics-9-13.5.md
  - epic6-code-size-optimization.md
  - epic7-shadow-register-optimization.md
  - epic8-shadow-register-followup.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-05-08
**Project:** antforth

## Step 1 — Document Discovery

### Documents Selected for Assessment

| Type | File | Size | Modified |
|---|---|---|---|
| PRD | `prd.md` | 86 KB | 2026-05-08 |
| Architecture | `architecture.md` | 80 KB | 2026-05-08 |
| Epics & Stories | `epics.md` | 80 KB | 2026-05-08 |
| UX Design | _(none — N/A for a CLI/Forth interpreter)_ | — | — |

### Historical Context (not part of assessment)

Phase archives retained for traceability; Phase 2 closed and v2.0.0 shipped 2026-05-07:

- `prd-phase1-epics-1-8.md`, `prd-phase2-epics-9-13.5.md`
- `architecture-phase1-epics-1-8.md`, `architecture-phase2-epics-9-13.5.md`
- `epics-phase1-epics-1-8.md`, `epics-phase2-epics-9-13.5.md`
- `epic6-code-size-optimization.md`, `epic7-shadow-register-optimization.md`, `epic8-shadow-register-followup.md`

### Discovery Issues

- **No strict duplicates** (no whole-vs-sharded conflict). Multiple whole versions exist but are phase-segregated and treated as archives.
- **No UX document** — accepted as N/A for this project type.
- **Filename hazard:** `epics-phase2-epics-9-13.5.md` contains `epic` twice; noted, non-blocking.

### Outcome

User selected option (a): assess the current canonical set (`prd.md` / `architecture.md` / `epics.md`). Phase archives excluded from validation.

## Step 2 — PRD Analysis

PRD `prd.md` is the Phase-3 PRD: a debt-cleanup interlude between v2.0 and Phase 4. It carries Phase-2 FR1–FR47 forward via FR-P3-22 and adds 25 Phase-3-specific FRs and 33 Phase-3-specific NFRs.

### Functional Requirements Extracted

**Standards-Compliance Documentation (A.1):**

- **FR-P3-1:** §-level row in `docs/ans-forth-core-compliance.md` for every mandatory rule in DPANS94 §6.1 (Core) — verdict (Implemented / Implemented-with-caveat / Accepted-with-rationale-N-A), source `file:line`, story-number, caveats.
- **FR-P3-2:** §-level row for every implemented word in DPANS94 §6.2 (Core Extension) — same row format as FR-P3-1.
- **FR-P3-3:** §-level row for every structural §-rule applicable to antforth (e.g., §3.1.4.1 double-cell stack-layout, §3.4.1.3 numeric-literal parser rule, plus any other structural rules surfaced).
- **FR-P3-4:** Any non-implemented DPANS94 §6.1/§6.2 rule has an explicit "Accepted-with-rationale: N-A" or "Deliberately-omitted: rationale" row — never a silent gap.
- **FR-P3-5:** Any §-level structural-rule gap surfaced by A.1 audit is back-filled with a focused story (Stories 13.0/13.0.1/13.5 template) or explicitly accepted-with-rationale per project-lead approval.
- **FR-P3-6:** Every word touched by an A.1 back-fill story carries a one-line standards-citation comment per CCD-3.

**Asm-Error THROW Catchability (A.2):**

- **FR-P3-7:** Users can wrap any antforth assembler-error-raising operation in `CATCH` and receive the corresponding asm-error THROW code (`-258..-272`) on the data stack, exactly as ANS-standard codes (e.g. `-4`, `-13`).
- **FR-P3-8:** `tests/throw_migration_tests.fth` (or equivalent) exercises caught-form path (`' WORD CATCH . CR`) for each asm-error THROW code in `-258..-272`; each test asserts the expected code lands on the data stack.

**Base-Aware Numeric-Literal Parsing (A.3):**

- **FR-P3-9:** When `BASE` is set explicitly (via `HEX`, `DECIMAL`, or `BASE !`), unprefixed numeric literals parse per that BASE consistently — at REPL, in compiled colon definitions, and in built-in Z80 assembler source.
- **FR-P3-10:** Forth-2014 §3.4.1.3 prefixed numeric literals (`#`/`$`/`%`/`'c'`/`0x`) continue to parse in their declared base regardless of `BASE` (FR9 Phase-2 carries forward).

**Test-Author Documentation (B.1):**

- **FR-P3-11:** Test author can find documented guidance — in `tests/README.md` or inline `Makefile` test-section comment block — establishing `PAD` as the canonical transient-buffer word for REPL-piped probes; acknowledges historic `HERE`/`S"` alternatives.

**Story-Template / Drafting Discipline (B.2 + B.3 + B.4):**

- **FR-P3-12:** Story-template HALT-signal lint catches "mirrors", "same shape as", or equivalent prior-arm-referencing language in byte-budget rationale (B.2 — Lesson 13.5-C).
- **FR-P3-13:** Story-template "Pre-edit baseline" task explicitly instructs `wc -c` capture of current binary, not inheriting prior story's reported number (B.3).
- **FR-P3-14:** Story-template figure-drift discipline (PD-2): figures, tables, code blocks validated against source-of-truth at draft time (B.4).
- **FR-P3-15:** B.2/B.3/B.4 lead-in stories carry their own verdict criteria — each tests that the new template would have caught the prior-incident pattern.

**Build-Tool Sync & Hygiene (B.5 + B.6 + B.8):**

- **FR-P3-16:** Maintainer can invoke a sync target (Makefile rule, doc-build script, or equivalent) detecting PRD-vs-architecture transcription drift; produces drift report or clean-pass verdict (B.5 — closes PD-3).
- **FR-P3-17:** Contributor running `make check-tools` confirms iz-cpm version matches the calibrated baseline; mismatches produce clear advisory (B.6 — closes PD-6).
- **FR-P3-18:** Makefile `make test-repl` uses unique numeric IDs across all probes; duplicate test numbers (Story 11.3 cosmetic gap) renumbered on first Makefile-touching Phase-3 story (B.8).

**Filesystem Stress Coverage (B.7 + B.9):**

- **FR-P3-19:** Probe coverage for directory-full failure mode in `tests/file_access_tests.fth` (or equivalent), exercising failed-write `ior` + FCB-pool/filesystem-state consistency post-failure (B.7 — conditional).
- **FR-P3-20:** Probe coverage for zero-byte `READ-FILE`, exercising `( c-addr 0 fileid -- 0 0 )` no-op path (B.7 — conditional).
- **FR-P3-21:** Disk-full handling verified clean on real CP/M 2.2 / MicroBeast hardware via hardware-typed probe; asserts non-zero `ior`, FCB-pool consistency, filesystem consistency post-failure (B.9).

**Backward Compatibility & Regression (phase-wide constraint):**

- **FR-P3-22:** All Phase-1 (Epics 1–8) + Phase-2 (Epics 9–13.5) functional behaviour — full FR1–FR47 set including REPL, colon defs, variables, CREATE/DOES>, control flow, errors, MARKER, CATCH/THROW, multi-vocabulary Search-Order, File-Access, numeric literal prefixes including `0x`, double precision, pictured output, hard-coded inline assembler — continues identically.
- **FR-P3-23:** All existing REPL-piped test scripts (1..952 baseline + 944..964 Epic-13.5 cleanup-slate probes) pass against every 2.x release. Zero regressions is a release blocker.
- **FR-P3-24:** Pre-Phase-3 CODE-word source files assemble correctly and produce byte-identical output under every Phase-3 2.x release.
- **FR-P3-25:** Unprefixed numeric-literal form continues to parse per BASE identically to pre-Phase-3, except for the A.3 enhancement (FR-P3-9 — refines the base-aware edge case).

**Total FRs: 25 Phase-3-specific + (Phase-2 FR1–FR47 carried forward via FR-P3-22) = 72 effective**

### Non-Functional Requirements Extracted

**Performance:**

- **NFR-P3-1** (carries Phase-2 NFR1–NFR5): All performance envelopes hold — numeric-literal prefix parse ≤ ~20 Z80 cycles overhead, multi-vocabulary lookup regression ≤ 10%, uncaught CATCH frame overhead ≤ ~15 Z80 cycles, per-epic ROM-footprint logged, double-precision primitives within ~20% of hand-rolled equivalents.
- **NFR-P3-2** (Phase-3-specific cumulative ROM budget): cumulative binary growth ≤ +200 bytes (24,996 → ≤ 25,200). Per-story envelopes: B.1–B.5 ≈ 0; A.1 audit ≈ 0; A.1 back-fills ~+10..+50; A.2/A.3 ~+0..+30; B.6/B.8/B.9 ~0; B.7 conditional.

**Reliability:**

- **NFR-P3-3** (Phase-2 NFR6 — REPL survivability): REPL survives any THROW including stack overflow, division by zero, undefined-word invocation, asm-error codes (-258..-272). Dictionary, in-session definitions, working state preserved across errors.
- **NFR-P3-4** (Phase-2 NFR7 — state integrity after error): No internal data structure (dictionary, wordlists, input buffer, pad, return stack, FCB pool, INCLUDE source frames) corrupted/inconsistent after THROW.
- **NFR-P3-5** (Phase-2 NFR8 — filesystem error recovery): File-op failures (disk full, file locked, BDOS I/O error, directory full, zero-byte read) raise THROW or return `ior` per Story-13.2/13.5.1/13.5.2 split; filesystem stays consistent. Phase-3 delta: B.7 + B.9 close gaps.
- **NFR-P3-6** (extends Phase-2 NFR9): full Phase-1 + Phase-2 + Epic-13.5 test suite (973 PASS / 0 FAIL) passes on every Phase-3 candidate. Single regression = release blocker.
- **NFR-P3-7** (codifies S9): every binary-delta Phase-3 story runs hardware-smoke task on real CP/M 2.2 / MicroBeast with PASS verdict. Zero-binary-delta stories document S9 exemption explicitly.

**Compatibility & Standards Conformance:**

- **NFR-P3-8** (Phase-2 NFR10 — ANS Forth 1994 Core 100% — upgraded to §-level): Core (DPANS94 §6.1) implemented to 100% with §-by-§ audit per A.1.
- **NFR-P3-9** (Phase-2 NFR11 — Forth 2014 §3.4.1.3): numeric-literal prefix syntax verbatim per spec; A.3 closes residual unprefixed edge case.
- **NFR-P3-10** (Phase-2 NFR12 — extension discipline): only `0x`, `INCLUDE-TOP`/`CATCH-TOP`, asm-error codes `-258..-272` are non-standard. Phase 3 introduces no new extensions.
- **NFR-P3-11** (Phase-2 NFR13 — CP/M 2.2 BDOS allow-list): only standard CP/M 2.2 BDOS (the existing functions: 0,1,2,6,9,10–22,25–27,33–36,40). Phase 3 adds no new BDOS functions.
- **NFR-P3-12** (Phase-2 NFR14 — CODE-word source backward compat): pre-Phase-3 CODE files assemble byte-identically.
- **NFR-P3-13** (Phase-3 §-level compliance auditability): per-row info enables external implementor to verify any single row against standard text + source code in under 10 minutes.

**Maintainability:**

- **NFR-P3-14** (Phase-2 NFR15 — code density and readability): Z80 source favours readability; comments on non-obvious logic required; comments re-stating assembly forbidden. Back-fill stories use Story 13.0/13.0.1/13.5 commenting style.
- **NFR-P3-15** (Phase-2 NFR16 — test-first discipline): every new word, behaviour change, defect closure has REPL-piped Forth test coverage before "done".
- **NFR-P3-16** (Phase-2 NFR17 — single-source-of-truth standards refs): standard-derived behaviours cite section in source comment per CCD-3. A.1 walk re-verifies every existing citation against compliance-doc rows.
- **NFR-P3-17** (Phase-2 NFR18 — epic-level decoupling): each Phase-3 epic delivers an independently-shippable 2.x point-release.
- **NFR-P3-18** (Phase-3 story-template discipline as quality attribute): B.1–B.5 lints/HALT signals/pre-edit task additions fire automatically when triggered; drafter doesn't need to remember.

**Integration:**

- **NFR-P3-19** (Phase-2 NFR19 — terminal I/O portability): only character-based BDOS console (functions 1, 2, 6, 9). No ANSI escapes, cursor positioning, line-mode/raw-mode toggles, colour.
- **NFR-P3-20** (Phase-2 NFR20 — file path conventions): `INCLUDE` and related accept CP/M 2.2 syntax (drive letter + `:` + 8.3 filename) exactly. No wildcards. No Unix-style paths.
- **NFR-P3-21** (Phase-2 NFR21 — MicroBeast hardware dependency isolation): no MicroBeast-specific hardware word enters kernel during Phase 3. MicroBeast hardware vocabulary is Phase-4+ — must be loadable as pure Forth source from disk.

**Process Discipline (NEW for Phase 3 — codifies S1–S12):**

- **NFR-P3-22 (S1):** code reviews via `/CR` (fresh-context external) per post-PD-1 structural close.
- **NFR-P3-23 (S2):** new tests are REPL-piped Forth scripts, not assembly test thread extensions; probes follow S12.
- **NFR-P3-24 (S3):** byte-budget rationale itemised per-part, not asserted via "mirrors prior arm". FR-P3-12 lint enforces.
- **NFR-P3-25 (S4):** AC-composition validation — each AC stands alone or in composition with named antecedents.
- **NFR-P3-26 (S5):** PARTIAL → HALT signal at dev-pass; root-cause handled in-pass or sibling story spawned.
- **NFR-P3-27 (S6):** inventory grep walks helper layer (e.g. `asm_die`, `file_byte_read`, `check_underflow` callers), not just user-facing word.
- **NFR-P3-28 (S7):** kernel raise sites preserve EXX state per `docs/register-conventions.md` §3 leaf-level rule + §7 EXX-using inventory.
- **NFR-P3-29 (S8):** "pre-existing" cannot discharge correctness defects (clobbers, lost writes, silent error swallowing).
- **NFR-P3-30 (S9):** mid-epic hardware-smoke per binary-delta story (codified as NFR-P3-7).
- **NFR-P3-31 (S10):** workflow > memory > prompt — process/discipline fixes land in workflow files + codified-discipline files, not conversational prompts.
- **NFR-P3-32 (S11):** every 2.x point-release tag passes user-visible version-surface audit (banner, README, memory-file `description` fields).
- **NFR-P3-33 (S12):** hardware-typed probe authoring — every smoke batch passes word-existence pre-flight + TIB-128 line-length lint.

**Total NFRs: 33 Phase-3-specific (most carry forward Phase-2 NFR1–NFR21; "Process Discipline" category is new).**

### Additional Requirements

- **Cumulative ROM budget:** 24,996 → ≤ 25,200 bytes (+200 envelope).
- **Test baseline:** 973 PASS / 0 FAIL maintained or extended; zero regressions on 1..952 + 944..964.
- **Regression fence:** S9 hardware-smoke per binary-delta story; zero-binary-delta stories document S9 exemption.
- **Phase-3 decomposition (suggested):** Lead-in B.1+B.2+B.3+B.4+B.5 → Strategic body A.1 (+ 0–2 back-fills per gap surfaced) → Hitch-hikers A.2/A.3/B.6/B.8/B.9 → Conditional B.7. Final 2.x point-release = Phase-3 close-out tag.
- **Boundary held:** kernel/Forth source-of-truth boundary frozen for Phase 3; no new ASSEMBLER.FTH (per `project_assembler_keep_assembly.md`).
- **Phase-3 carry-forward catalogue:** P1 set frozen at phase start (post-A1 re-baseline 2026-05-07). Mid-phase additions go to catalogue but don't extend phase.

### PRD Completeness Assessment

**Strengths:**

- Self-validation summary at end of FR section explicitly checks Coverage, Traceability, Altitude, Testability, Independence, Completeness — author has run their own gate.
- Every FR is tagged with the carry-forward item driving it (A.x or B.x). Journey Requirements Summary table maps journeys → FRs → carry-forward items.
- NFR section is selective — explicit "still holds" for Phase-2 NFRs, with Phase-3 deltas called out at the NFR-by-NFR level.
- Risk matrix covers technical, market/adoption, and resource risks with mitigations rooted in concrete project artifacts (sprint-change-proposal, retro discipline, S1–S12).
- All 12 P1 carry-forward items map to at least one FR (B.8 cosmetic-only is explicitly noted as the no-journey exception, but still has FR-P3-18).
- Phase-2 carry-forward FRs covered by single explicit FR-P3-22 plus regression FR-P3-23/24/25 — clean handoff, not handwaved.
- Per-story binary-delta envelopes published (B.1–B.5 ≈ 0; A.1 ≈ 0; back-fills +10..+50; A.2/A.3 +0..+30; etc.) — gives the story-drafter concrete numbers to calibrate against.

**Gaps / risks for downstream epic-coverage validation:**

- **B.5 sync target — testability ambiguity.** FR-P3-16 specifies "produces drift report or clean-pass verdict" but doesn't pin the trigger ("at doc-build time", "on any PR touching prd.md or architecture.md", "manual invocation"). Epic story should make the trigger explicit.
- **A.1 audit-gap envelope.** PRD says "0–2 back-fill stories per §-level structural-rule gap surfaced" with cumulative cap +200 bytes. If A.1 surfaces > 5 gaps the risk-matrix mitigation is `bmad-bmm-correct-course`, but no concrete trigger threshold (3 gaps? 5 gaps?) is defined for sprint-change. Worth confirming epic-level.
- **B.7 conditionality.** FR-P3-19 / FR-P3-20 are conditional ("hardware-revealed need") and FR-P3-21 (B.9) is the trigger. If B.9 reveals nothing, the FRs evaluate as "evaluated, none required" — but the FR text doesn't make that explicit; it says "exists in tests/file_access_tests.fth". Risk is downstream stories interpret FR-P3-19/20 as unconditional. Worth a one-line "conditional on B.9 outcome" hardening.
- **NFR-P3-13 "under 10 minutes" verifiability.** The NFR is stated as a quality attribute but no story is named that tests it (e.g. "have a third party walk one row end-to-end"). Soft, but still measurable.
- **Phase-2 FR1–FR47 not enumerated in this PRD.** FR-P3-22 carries them by reference; they live in `prd-phase2-epics-9-13.5.md`. Epic-coverage validation will need to cross-load that PRD to confirm regression coverage. (Acceptable for a debt-cleanup PRD; flagging as a cross-doc coupling.)
- **No explicit MVP scope-cut threshold.** PRD says "partial delivery is a legitimate 2.x point-release but does not constitute Phase-3 close-out". For a debt-cleanup phase this is reasonable, but a concrete "Phase 3 closes when N of 12 P1 items closed (where N may be < 12 if re-prioritised)" threshold is absent. Project-lead-controlled, which the risk matrix calls out — but downstream sprint planning may need a sharper rule.
- **No UX section** — appropriate for a debt-cleanup phase with no new user-facing surface, but the workflow's UX-alignment step (Step 4) will likely evaluate as N-A.

**Verdict:** PRD is **substantially complete and traceable**. No FR/NFR coverage holes; gaps above are *clarification opportunities*, not missing requirements. Author's self-validation gate is genuine, not boilerplate. Ready for epic-coverage validation.

## Step 3 — Epic Coverage Validation

### Epics Decomposition (extracted from `epics.md`)

`epics.md` decomposes Phase 3 into **2 epics + 11 stories** (8 firm + 3 conditional/spawned):

**Epic 14 — Phase-3 Process Foundation** (lead-in cluster, must land first):

| Story | Title | FRs covered |
|---|---|---|
| 14.1 | PAD documented as canonical transient-buffer for test authors | FR-P3-11, FR-P3-15 |
| 14.2 | "Mirrors prior arm" HALT-signal lint in story-template | FR-P3-12, FR-P3-15 |
| 14.3 | Story-to-story binary handoff — re-`wc -c` at dev-pass start | FR-P3-13, FR-P3-15 |
| 14.4 | PD-2 figure-drift discipline `<critical>` block | FR-P3-14, FR-P3-15 |
| 14.5 | PRD↔architecture transcription-drift sync target — `make check-doc-sync` | FR-P3-16 |

**Epic 15 — Phase-3 Standards Close-Out** (strategic body + hitch-hikers + close-out gate):

| Story | Title | FRs covered |
|---|---|---|
| 15.1 | §-by-§ ANS Forth Core + Core-Extension audit (A.1) | FR-P3-1, FR-P3-2, FR-P3-3, FR-P3-4 |
| 15.1.X | A.1 back-fill — gap N (CONDITIONAL; 0–2 expected, spawned from 15.1's verdict) | FR-P3-5, FR-P3-6 |
| 15.2 | Caught-form THROW coverage for asm-error block −258..−272 (A.2) | FR-P3-7, FR-P3-8 |
| 15.3 | Unprefixed `NUMBER?` base-specialization (A.3) | FR-P3-9, FR-P3-10, FR-P3-25 (refinement) |
| 15.4 | Makefile tooling sprint — `make check-tools` + test-numbering hygiene (B.6 + B.8) | FR-P3-17, FR-P3-18 |
| 15.5 | Filesystem stress hardware sprint — disk-full + directory-full + zero-byte READ-FILE (B.7 + B.9) | FR-P3-19, FR-P3-20, FR-P3-21 |
| 15.5.1 | B.7 conditional probe story (CONDITIONAL — only if 15.5 surfaces a defect) | FR-P3-19, FR-P3-20 (kernel-surgery-backed) |
| 15.6 | Phase-3 close-out gate | FR-P3-22, FR-P3-23, FR-P3-24, FR-P3-25 (phase-wide regression verdict-walk) |

### FR Coverage Matrix

| FR | PRD Requirement (abbrev.) | Epic / Story | Status |
|---|---|---|---|
| FR-P3-1 | DPANS94 §6.1 Core per-rule rows | Epic 15 / Story 15.1 (AC1, AC2, AC5) | ✓ Covered |
| FR-P3-2 | DPANS94 §6.2 Core Ext per-rule rows | Epic 15 / Story 15.1 (AC1, AC2) | ✓ Covered |
| FR-P3-3 | Structural §-rule rows | Epic 15 / Story 15.1 (AC1, AC4) | ✓ Covered |
| FR-P3-4 | "Accepted-with-rationale-N-A" / "Deliberately-omitted" rows — no silent gaps | Epic 15 / Story 15.1 (AC5) | ✓ Covered |
| FR-P3-5 | §-level structural-rule gaps back-filled or accepted | Epic 15 / Story 15.1.X (CONDITIONAL — fires per Story 15.1 AC8 verdict) | ✓ Covered (conditional) |
| FR-P3-6 | CCD-3 standards-citation comment on every back-filled word | Epic 15 / Story 15.1.X (AC2 canonical template) | ✓ Covered (conditional) |
| FR-P3-7 | Caught-form CATCH path returns asm-error code | Epic 15 / Story 15.2 (AC1, AC2) | ✓ Covered |
| FR-P3-8 | `tests/throw_migration_tests.fth` exercises caught-form for `-258..-272` | Epic 15 / Story 15.2 (AC1, AC4) | ✓ Covered |
| FR-P3-9 | Unprefixed numerals parse per explicit BASE consistently | Epic 15 / Story 15.3 (AC3, AC4, AC6) | ✓ Covered |
| FR-P3-10 | Forth-2014 §3.4.1.3 prefixed literals continue to ignore BASE | Epic 15 / Story 15.3 (AC5 regression) | ✓ Covered |
| FR-P3-11 | `tests/README.md` documents PAD as canonical transient-buffer | Epic 14 / Story 14.1 (AC2, AC3, AC4, AC5) | ✓ Covered |
| FR-P3-12 | Story-template "mirrors prior arm" HALT-signal lint | Epic 14 / Story 14.2 (AC1, AC2, AC3, AC5, AC6) | ✓ Covered |
| FR-P3-13 | Story-template re-`wc -c` task | Epic 14 / Story 14.3 (AC1, AC2, AC5) | ✓ Covered |
| FR-P3-14 | Story-template figure-drift discipline `<critical>` block | Epic 14 / Story 14.4 (AC1, AC2, AC3, AC5, AC6) | ✓ Covered |
| FR-P3-15 | Verdict-criterion meta-pattern in lead-in stories | Epic 14 / Stories 14.1–14.5 (each has an explicit FR-P3-15 AC: 14.1 AC7, 14.2 AC5/AC6, 14.3 AC5, 14.4 AC5, 14.5 AC6) | ✓ Covered |
| FR-P3-16 | `make check-doc-sync` PRD↔architecture drift target | Epic 14 / Story 14.5 (AC1–AC7) | ✓ Covered |
| FR-P3-17 | `make check-tools` iz-cpm + sjasmplus version stability advisory | Epic 15 / Story 15.4 (AC1–AC4) | ✓ Covered |
| FR-P3-18 | Makefile test-numbering hygiene (renumber duplicates) | Epic 15 / Story 15.4 (AC6, AC7, AC8) | ✓ Covered |
| FR-P3-19 | Directory-full failure-mode probe coverage (conditional) | Epic 15 / Story 15.5 (AC2) + Story 15.5.1 (CONDITIONAL — kernel-surgery if hardware reveals defect) | ✓ Covered (conditional disposition logic in Story 15.5 AC6) |
| FR-P3-20 | Zero-byte READ-FILE probe coverage (conditional) | Epic 15 / Story 15.5 (AC3) + Story 15.5.1 (CONDITIONAL) | ✓ Covered (conditional disposition logic in Story 15.5 AC6) |
| FR-P3-21 | Disk-full hardware re-verification on real CP/M 2.2 / MicroBeast | Epic 15 / Story 15.5 (AC1, AC5) | ✓ Covered |
| FR-P3-22 | Phase-1+2 functional behaviour preserved | Both epics (every story has S9 hardware smoke + `make test-repl ≥ 973 PASS / 0 FAIL` AC); Phase-3 close-out walks at Story 15.6 (AC4, AC5) | ✓ Covered (phase-wide invariant) |
| FR-P3-23 | 973 PASS / 0 FAIL test baseline maintained | Both epics (every story's `make test-repl ≥ 973 PASS / 0 FAIL` AC); close-out at Story 15.6 (AC4) | ✓ Covered (phase-wide invariant) |
| FR-P3-24 | Pre-Phase-3 CODE-source byte-identical assembly | Both epics (implicit in regression baseline; Story 15.6 close-out walks the constraint at AC4) | ✓ Covered (phase-wide invariant) |
| FR-P3-25 | Unprefixed numeric-literal parsing preserved (with A.3 base-aware refinement) | Epic 15 / Story 15.3 (AC6 explicit invariant); both epics regression discipline | ✓ Covered |

### NFR Coverage Cross-Check

The 33 NFR-P3-N requirements are explicitly mapped at epic level:
- **Epic 14** delivers NFR-P3-18 (story-template discipline as quality attribute), NFR-P3-31 (S10 — codified at architectural level via CCD-P3-2). All 33 NFR-P3-N continue to hold.
- **Epic 15** delivers NFR-P3-2 (cumulative ROM cap +200 bytes per-story enforcement), NFR-P3-7 (S9 hardware smoke per binary-delta story), NFR-P3-8 (§-level Core compliance), NFR-P3-9 (A.3 strict refinement), NFR-P3-13 (compliance-doc row checkability), NFR-P3-32 (S11 version-surface audit). All 33 NFR-P3-N continue to hold.
- The S1–S12 standing commitments are codified as NFR-P3-22..NFR-P3-33 and Story 15.6 AC6 explicitly walks each at Phase-3 close-out.

### Missing FR Coverage

**None.** All 25 FR-P3-N requirements have an owning epic + story and at least one explicit acceptance criterion realising the requirement. Phase-2 carry-forward FR1–FR47 (covered through FR-P3-22) is enforced phase-wide via every story's regression-baseline AC + Story 15.6's close-out walk.

### Conditional-Coverage Audit

Two FRs route through conditional stories that may not exist after dev-pass. Both have explicit closure logic that the requirement is still satisfied even if the story doesn't fire:

- **FR-P3-5 / FR-P3-6** (back-fill stories): Story 15.1 AC8 — "any §-level structural-rule gap surfaced is either back-filled with a focused sub-story (Story 15.1.1, 15.1.2, …) per the A.1-D3 six-step shape, **or explicitly accepted-with-rationale** per project-lead approval." If 0 gaps surface, FR-P3-5 is closed by the accepted-with-rationale branch via the Story 15.1 close-out audit-verdict summary (AC9). FR-P3-6 only fires if a back-fill exists; if none do, the FR is vacuously held. **Disposition: clean.**
- **FR-P3-19 / FR-P3-20** (B.7 conditional probes): Story 15.5 AC6 — "B.7 disposition fork — if hardware reveals a defect, B.7 disposition (b) 'Probe story spawned' fires (Story 15.5.1)... if hardware reveals no defect, B.7 disposition (a) 'Evaluation suffices' closes the row with a closure note." Probe coverage exists either way (AC2 directory-full + AC3 zero-byte READ-FILE land in `tests/file_access_tests.fth`); 15.5.1 only fires for kernel-surgery. **Disposition: clean.** This resolves the PRD ambiguity I flagged earlier (FR-P3-19/20 read as unconditional in the PRD; the epic adds the explicit conditional-disposition branch).

### FRs in Epics Not in PRD

**None.** Epic stories do not introduce capability beyond what FR-P3-N defines. Story 15.6 (close-out gate) has process-discipline ACs (S11 audit, S1–S12 walk, retro skeleton) that map cleanly to NFR-P3-32 / NFR-P3-22..33 — not new FRs.

### Coverage Statistics

- Total Phase-3 PRD FRs (FR-P3-N): **25**
- FRs covered in epics: **25**
- Coverage percentage: **100%**
- Total Phase-3 PRD NFRs (NFR-P3-N): **33** (5 Performance, 5 Reliability, 6 Compatibility, 5 Maintainability, 3 Integration, 12 Process Discipline + 2 cross-cuts; some are explicit deliveries, some are "continues to hold")
- NFRs covered: **33** (Story 15.6 AC6 walks S1–S12 codifications NFR-P3-22..33; remaining NFRs delivered by named epics)
- Phase-2 FR1–FR47 carry-forward: covered as a single regression invariant via FR-P3-22 + every story's `make test-repl ≥ 973 PASS / 0 FAIL` AC

### Coverage-Specific Observations

- The epics document includes its own "FR Coverage Map" table at lines 195–222 — author has run their own traceability gate. That map aligns with this audit's matrix (no discrepancies).
- Each Epic-14 lead-in story (14.1–14.5) explicitly includes an FR-P3-15 verdict-criterion AC. This *over-covers* FR-P3-15 (one AC per lead-in story rather than a single AC anywhere), which is the right shape for a meta-pattern requirement.
- Story 15.6 (close-out gate) does not introduce new FRs; it walks the phase-wide invariants and tag discipline. This is the appropriate mirror of Story 13.5.6 close-out precedent.
- The architecture findings F1–F7 are explicitly owned by stories (F1/F6/F7 → 15.1; F2 → 15.5; F4 → 15.4; F5 → 15.3; F3 → cross-epic). No orphan findings.

**Verdict:** epic coverage is **complete** with explicit conditional-disposition logic on the two FR pairs that route through conditional stories. Ready for UX alignment step.

## Step 4 — UX Alignment Assessment

### UX Document Status

**Not Found.** No `*ux*.md` file exists in `_bmad-output/planning-artifacts/` (Step 1 confirmed). Search of `prd.md` and `architecture.md` for UI-implying terms (`UI`, `interface`, `screen`, `component`, `frontend`, `widget`, `design system`) returns no hits suggesting a missing UX surface.

### Is UX/UI Implied?

**No.** The PRD's "Project Classification" section explicitly states:

- **Project Type:** `developer_tool_embedded` — Z80 retrocomputer Forth interpreter on CP/M 2.2.
- The `.COM` file IS the package; the REPL IS the IDE.
- PRD's "Explicitly Out of Scope for Project-Type Requirements" section explicitly excludes: *"Visual design / store compliance / browser support — explicitly skipped per CSV `skip_sections` for both `developer_tool` (`visual_design;store_compliance`) and `iot_embedded` (`visual_ui;browser_support`)."*
- PRD's "User Journeys / Scope Note on User Types" section: *"antforth is a single-user interactive REPL running on personal retrocomputer hardware. There is no network surface, no multi-tenant model, no authentication, no API layer."*
- The only "user interface" surface is character-based BDOS console I/O (functions 1, 2, 6, 9 — see NFR-P3-19); no ANSI escapes, cursor positioning, line-mode/raw-mode toggles, or colour. This is a deliberate portability constraint.
- Phase 3 explicitly ships **zero new user-facing features** — it is a debt-cleanup interlude.

The closest thing to a "UX requirement" is the user-error / error-recovery experience (NFR-P3-3 REPL survivability across THROW; A.2 caught-form THROW closure), and these are appropriately captured as Reliability NFRs and Functional Requirements rather than as UX-document content.

### Alignment Issues

**None identified.** With no UX surface to align against, there are no UX↔PRD or UX↔Architecture misalignments to enumerate. All user-facing concerns that *would* live in a UX document (the six User Journeys with personas Mo / Raj / Pete / Hana / Ant) are captured directly in the PRD's "User Journeys" section, traceable to FRs via the Journey Requirements Summary table at PRD lines 313–331.

### Warnings

**None.** UX-document absence is appropriate-by-design for a CLI/Forth-interpreter project type. The workflow's UX-alignment step evaluates as **N/A** for this project.

### Cross-Reference: Architecture Hold of UX-Equivalent Constraints

Architecture document holds the only "UX-equivalent" constraints as platform invariants:
- Character-based BDOS-only I/O (no terminal-feature assumptions) — reaffirmed under "Target Platform Requirements" (Phase 2 carry-forward, Phase 3 unchanged).
- TIB-128 line-length lint for hardware-typed probe authoring (NFR-P3-33 / S12) — codified in `tests/README.md` per Story 14.1.
- The REPL prompt + banner string — touched under S11 user-visible version-surface audit (NFR-P3-32).

These are appropriately filed as platform / process constraints, not as a "UX surface" requiring its own document.

**Verdict:** UX alignment step is **N/A by design** for antforth. No findings, no warnings, no follow-up work surfaced. Ready for epic quality review.

## Step 5 — Epic Quality Review

This review applies the create-epics-and-stories workflow's best-practice gates rigorously. Per project standing rule, reviews are adversarial by design — absence of findings is suspect. Findings below are graded by severity.

### Epic Structure Validation

#### Epic 14 — Phase-3 Process Foundation

**User Value Focus:**
- Title: "Phase-3 Process Foundation" — process-cluster framing, not strictly user-centric.
- Goal: lands story-template / drafting-discipline / Makefile sync targets (B.1–B.5).
- "User" = the project lead (Ant) authoring stories + test authors writing probes. PRD's "User Journeys / Scope Note on User Types" explicitly identifies Ant as a Phase-3-internal user (Journey 6); test authors are the audience for `tests/README.md` (B.1). PRD's "Project Type" classification frames the project as `developer_tool_embedded` and notes "the REPL IS the IDE", which makes internal-tooling-as-user-value defensible for this project class.
- **Verdict:** PASS for this project class. Epic 14 delivers value to internal-tooling users (the project lead + future test authors); the framing is appropriate for a debt-cleanup interlude where the deliverable is process-discipline rather than feature.

**Epic Independence:**
- Architecture / epic header: "Standalone — complete on its own; process-foundation infrastructure landed; Epic 15 builds on it but doesn't require it to function (Epic 15 stories *would* execute without it, just without the lints catching drafting drift)."
- Verified by inspection: every Epic-14 story produces an artifact (workflow-file edit, doc, Makefile target) that stands alone. None reference outputs from Epic 15.
- **Verdict:** PASS.

#### Epic 15 — Phase-3 Standards Close-Out

**User Value Focus:**
- Title: "Phase-3 Standards Close-Out" — closes the carry-forward catalogue's Standards/Compliance items.
- Goal: §-by-§ audit + caught-form THROW + base-aware NUMBER? + hitch-hikers.
- Maps to 5 of 6 PRD User Journeys (Hana, Mo×2, Raj, Pete) — every story serves a named persona's outcome. Strong user-value-per-story alignment.
- **Verdict:** PASS.

**Epic Independence:**
- Architecture / epic header: "Epic 15 builds on Epic 14's discipline lints but functions independently — A.1/A.2/A.3/B.6/B.7/B.8/B.9 each have their own kernel/test/doc surface and don't depend on Epic 14's outputs to execute."
- Story 15.6 close-out gate AC3 invokes `make check-doc-sync` (delivered by Story 14.5). This is a within-phase sequencing dependency (Epic 14 must precede Epic 15's close-out gate), not a forward inter-epic dependency in the no-skip sense.
- **Verdict:** PASS for independence; Epic 14 → Epic 15 ordering is correct lead-in → strategic-body sequence per the carry-forward catalogue.

### Story Quality Assessment

All 11 stories use Given/When/Then BDD form for ACs. Each story has a regression invariant AC (`make test-repl ≥ 973 PASS / 0 FAIL`) and a binary-delta envelope AC (`wc -c build/antforth.com` constraint). Hardware-smoke ACs are explicit (PASS verdict + transcript-filed) for binary-delta stories; zero-binary-delta stories document S9 exemption.

**Common patterns observed:**
- Verdict-criterion meta-pattern (FR-P3-15) lands as one explicit AC per Epic-14 lead-in story (14.1 AC7, 14.2 AC5/AC6, 14.3 AC5, 14.4 AC5, 14.5 AC6).
- Pre-fix negative-result confirmation (A.1-D3 / S6 discipline) lands in 15.1.X AC6 and 15.3 AC7.
- CCD-3 standards-citation pattern enforced in 15.1.X AC2, 15.3 AC8, 15.6 close-out walk.
- `docs/PHASE-3-CARRY-FORWARD.md` row updates are explicit ACs in every story (status column transitions to `✅ Done` etc.).

### Findings

#### 🔴 Critical Violations
**None.**

#### 🟠 Major Issues
**None.**

#### 🟡 Minor Concerns

**Q1 — Soft forward dependency: Story 14.5 → Story 15.1.** The `make check-doc-sync` target shipped in Story 14.5 implements drift-check (c) — "every `§X.Y.Z` reference in `architecture.md`'s compliance-related sections has a matching row in `docs/ans-forth-core-compliance.md`". That matching row set is materially populated by Story 15.1 (the §-by-§ audit). Pre-15.1 the check passes vacuously (only 5 §-rows to validate); post-15.1 the check has full diagnostic power. The architecture explicitly anticipates this with parenthetical "(post-A.1 invariant — verdict criterion: clean before any tag close-out)" in Story 14.5 AC3, and the target is *advisory-only* on `make test-repl` so this doesn't gate any normal dev-pass. **Disposition:** acknowledged in spec; flagging as a soft within-phase sequencing observation rather than a defect. The verdict-criterion meta-pattern (Story 14.5 AC6) verifies the *target ships and produces a known verdict*, not that the verdict is necessarily clean — which is correct for a tool that ships before the data it ultimately validates.

**Q2 — Story 15.2 → Story 15.4 ID-collision risk.** Story 15.2 (caught-form THROW probes, +15 probes) ships *before* Story 15.4 (B.8 renumber). Story 15.2 AC5 explicitly states: "no duplicates with the 1..952 baseline or 944..964 cleanup-slate range; B.8 renumber arrives via Story 15.4". This means Story 15.2 must pick 15 new probe IDs that avoid (a) the 1..952 baseline, (b) the 944..964 cleanup-slate range, AND (c) the existing Story-11.3 duplicates that B.8 will later eliminate. **Risk:** the dev-pass author may inadvertently pick an ID that conflicts with a Story-11.3 duplicate, only for B.8 to then renumber the Story-11.3 duplicate to a value that re-collides. **Mitigation suggested:** Story 15.2's dev-pass note should enumerate the existing Story-11.3 duplicate IDs explicitly (or recommend picking IDs in a fresh range, e.g. 1000..1014, that has no collisions in either current state OR post-B.8 state). Worth a one-line clarification in Story 15.2 AC5 before dev-pass starts.

**Q3 — Within-Epic-14 soft sequencing: 14.4 references 14.2's artifact.** Story 14.4 AC6 says "the B.4 block lands adjacent to (immediately before or after) the B.2 'mirrors' block in `instructions.xml`". This requires Story 14.2's `<critical>` block to exist when 14.4 dev-passes. The epics document Epic-14 story order is 14.1 → 14.2 → 14.3 → 14.4 → 14.5, so this works in practice — but the within-epic sequencing constraint isn't called out as an explicit Story 14.4 dependency note. Minor — order is implicit in story numbering.

**Q4 — Story 15.1 size variance.** Story 15.1 is the "single largest discrete piece of work in the phase" per architecture. AC1 says "~133 rules" for §6.1 — an under-estimate, since AC4 acknowledges "at least one §-number appears in multiple rows" (one §-number can yield multiple rule rows for word-stack-effect + structural-constraint linkage). Net rule count post-walk could be 150–200+. Architecture and PRD both call out the size with explicit decomposability mitigation ("the audit can proceed §-by-§ across multiple sittings without losing state"). **Disposition:** acknowledged in risk matrix. Worth flagging as a story-size variance candidate; if the audit scope blows past 250+ rows, the dev-pass author should consider sprint-change-proposal evaluation.

**Q5 — Story 15.3 process-discipline AC drift.** Story 15.3 has 12 ACs — at the high end of "single dev-pass" sizing. AC2 states "the dev-pass author reads the current `w_NUMBER_Q_cf` code and the standard text (DPANS94 §6.1.0570 + Forth 2014 §3.4.1.3), then specifies the precise pre-/post-behaviour delta in the story's Dev Notes before implementing." This is a *process instruction to the dev agent*, not a verifiable outcome AC — the Dev Notes will exist either way. Soft AC; the verifiability lives in AC4 (positive REPL probes) and AC7 (pre-fix negative-result confirmation). **Disposition:** acceptable as process-discipline scaffolding; not a defect.

**Q6 — Story 14.1 AC7 verifies presence, not behaviour.** AC7 is "a grep of `tests/README.md` for `PAD` returns at least one occurrence... `Makefile` test section grep returns the pointer comment". This proves the doc *exists* with PAD content — it does not prove the doc *teaches* the convention well, nor that future test authors actually find it. Compare to Story 14.2 AC5 which uses a synthesised drafting attempt to surface the HALT signal — a behaviour test. The grep-AC pattern in 14.1 is appropriate for a doc-only story (behavioural validation of doc clarity is hard to mechanise) but weaker than the lint-fires-on-input pattern of 14.2. **Disposition:** acceptable trade-off given the artifact type.

**Q7 — Per-story regression-baseline AC threshold variance.** Most stories use `≥ 973 PASS / 0 FAIL` as the regression-baseline AC. Story 15.2 AC7 uses `≥ 973 + 15 = 988 PASS / 0 FAIL` (additive). Story 15.5 AC9 uses `≥ baseline + new probes / 0 FAIL`. Story 15.6 AC4 uses `≥ 973 PASS + Phase-3 additive probes / 0 FAIL`. These are consistent in spirit but the explicit numeric anchor varies. **Disposition:** consistent enough; no action needed.

**Q8 — Story 15.4's two-item shape.** Story 15.4 combines B.6 (`make check-tools`) and B.8 (test-numbering renumber) into one "Makefile tooling sprint". The combination is reasonable (both Makefile-touching, both small) but the 11 ACs split 5 to B.6 and 4 to B.8, with a single combined regression AC. A future drafter might prefer to split this into two stories if either grows. **Disposition:** acceptable; combined story is appropriate for a tooling sprint.

### Best Practices Compliance Checklist

For each epic:

| Gate | Epic 14 | Epic 15 |
|---|---|---|
| Epic delivers user value | ✓ (internal-tooling users — Ant + test authors) | ✓ (5 of 6 PRD personas) |
| Epic can function independently | ✓ | ✓ |
| Stories appropriately sized | ✓ (lead-in cluster — small) | ✓ with caveat (Story 15.1 large but decomposable; risk-matrix-mitigated) |
| No forward dependencies | ✓ (no out-of-order or inter-epic-skip dependencies) | ✓ (15.6 → 14.5 is correct phase ordering, not a forward dep) |
| Database tables created when needed | N/A (no database) | N/A (no database) |
| Clear acceptance criteria | ✓ (BDD form, testable, regression-baseline ACs explicit) | ✓ (BDD form, testable, regression-baseline ACs explicit) |
| Traceability to FRs maintained | ✓ (explicit FR-P3-N tags per story) | ✓ (explicit FR-P3-N + NFR-P3-N + Findings-F1..F7 tags per story) |

### Brownfield-Specific Checks

PRD Project Context: `brownfield`. Phase 3 builds on shipped v2.0 (commit `6599d73`). Epic structure is appropriate:
- No initial-project-setup story needed (kernel exists; Phase-3 is incremental).
- Integration with existing systems: every story explicitly cites the v2.0 baseline as its starting state ("Given v2.0 baseline X..." in Given clauses).
- Migration / compatibility: FR-P3-22..25 enforce backward compatibility; every story has the regression-baseline AC.
- Architecture's "NOT touched" file list explicitly enumerates kernel files frozen for the phase (`src/inner_interpreter.asm`, `src/outer_interpreter.asm`, `src/exception.asm`, `src/wordlists.asm`, `src/compiler.asm`, `src/dictionary.asm`, `src/hash.asm`, `src/control_flow.asm`, `src/structures.asm`, `src/assembler.asm`).

### Architecture-to-Epic Traceability

Architecture finding F1–F7 are all explicitly owned by stories:
- F1 (CCD-P3-1 satisfied-behaviourally case) → Story 15.1 AC3
- F2 (B.7+B.9 disk-full vs directory-full distinct failure modes) → Story 15.5 AC1, AC2
- F3 (CCD-P3-2 "structural" wording) → cross-epic invariant; not a single-story owner
- F4 (B.6 .tool-versions introspection) → Story 15.4 AC1, AC4
- F5 (A.3 site is binding) → Story 15.3 AC1
- F6 (A.1 citation-cleanup overflow) → Story 15.1 AC7
- F7 (A.1 row grain word vs structural-rule) → Story 15.1 AC4

No orphan findings; no orphan stories.

### Adversarial Walk Summary

This review walked every epic, every story, every AC, every cross-reference. Findings are concentrated in the **Minor Concerns** band (Q1–Q8). No critical or major issues surfaced. The two notable items worth dev-pass-time attention are:

- **Q1** (acknowledged in spec): Story 14.5's `make check-doc-sync` ships pre-A.1 with vacuous diagnostic power on the §X.Y.Z drift check; full power post-15.1.
- **Q2** (suggested clarification): Story 15.2's probe-ID picks should be drawn from a fresh range (e.g. 1000..1014) to avoid Story-11.3 duplicate-collision risk pre-B.8 renumber.

**Verdict:** epic and story decomposition is **implementation-ready** with two soft clarification opportunities (Q1, Q2). Ready for final assessment.

## Summary and Recommendations

### Overall Readiness Status

**READY** — proceed to implementation (Phase 3 dev-pass execution).

### Findings by Severity

| Severity | Count | Owner | Step |
|---|---:|---|---|
| 🔴 Critical | 0 | — | — |
| 🟠 Major | 0 | — | — |
| 🟡 Minor | 8 | Q1–Q8 (Step 5) | epic quality review |
| Clarification ops | 6 | Step 2 | PRD analysis |
| Coverage gaps | 0 | — | — |

### What's Solid

- **PRD↔Epic↔Story traceability is complete.** All 25 FR-P3-N requirements have an owning epic, story, and acceptance criterion. All 33 NFR-P3-N requirements are explicitly delivered or codified-as-quality-attribute. The epics document includes its own FR Coverage Map at lines 195–222 that aligns with this audit's matrix without discrepancy.
- **Conditional-coverage logic is sound.** FR-P3-5/6 (back-fills) and FR-P3-19/20 (B.7 conditional) both have explicit disposition-fork ACs in their owning stories, so the FR is closed in either branch (back-fill landed *or* explicitly-accepted-with-rationale; probe-permanent *or* B.7-evaluation-suffices).
- **Architecture findings F1–F7 have story owners.** No orphan findings; no orphan stories.
- **Brownfield discipline is properly applied.** Every story uses "Given v2.0 baseline X..." Given clauses; every binary-delta story has S9 hardware-smoke + `make test-repl ≥ 973 PASS / 0 FAIL` regression ACs; cumulative ROM cap (NFR-P3-2) +200-byte envelope tracked per-story with HALT signal at the boundary.
- **Standing commitments S1–S12 codified as NFR-P3-22..33.** Story 15.6 (close-out gate) AC6 explicitly walks each one at Phase-3 close-out.
- **Self-validation gates already in the source documents.** PRD has its own coverage / traceability / altitude / testability / independence / completeness checklist at lines 547–555. Epics document has its own FR Coverage Map. Both authors ran their own gate before this readiness check.

### Items Worth Dev-Pass-Time Attention (no blockers)

These are **clarification opportunities**, not implementation blockers. Phase 3 can start dev-pass execution immediately; these can be addressed inline during the relevant story's drafting.

1. **(Q2 from Step 5) Story 15.2 probe-ID range guidance.** Recommend the Story 15.2 dev-pass author pick the 15 new caught-form-THROW probe IDs from a fresh range (e.g. 1000..1014) to avoid collision with both the 1..952 baseline AND the existing Story-11.3 duplicates (which B.8 will renumber via Story 15.4 *after* 15.2 ships). One-line clarification in Story 15.2 AC5 before dev-pass starts.
2. **(Q4 from Step 5) Story 15.1 size-variance guard.** Architecture and PRD already mitigate the §-by-§ audit's variability via "decomposable across multiple sittings". If the audit walk surfaces > 250 rule-rows, the dev-pass author should evaluate sprint-change-proposal — extending the existing > 5-gap risk-matrix trigger to include a row-count trigger.
3. **(PRD Step 2 gap) FR-P3-19/20 conditionality wording.** The PRD's FR-P3-19/20 read as unconditional ("exists in tests/file_access_tests.fth"). The epic resolves this with explicit disposition logic (Story 15.5 AC4), but a one-line "(conditional on B.7 disposition per epic)" hardening in the PRD FR text would close the cross-doc transcription gap that B.5 (`make check-doc-sync`) is meant to detect. Could be folded into the Story 15.1 → 15.6 PRD-edit flow opportunistically.
4. **(PRD Step 2 gap) B.5 sync-target trigger pinning.** FR-P3-16 specifies "produces drift report or clean-pass verdict" but doesn't pin the trigger ("at doc-build time", "on PR touching prd.md/architecture.md", "manual"). Story 14.5 AC5 resolves this concretely as "advisory-only on `make test-repl` (does not block test runs); expected clean before any tag-applicable close-out (S11 sibling)". The trigger pinning is in the story; the PRD could be hardened post-14.5 ships.
5. **(PRD Step 2 gap) Phase-3 close-out scope-cut threshold.** PRD says "partial delivery is a legitimate 2.x point-release but does not constitute Phase-3 close-out" — but doesn't define an N-of-12 threshold for "Phase 3 closes when N items closed". The risk matrix calls this out as project-lead-controlled and suggests `bmad-bmm-correct-course` as the mechanism for re-prioritisation. Acceptable as-is; a threshold pin (e.g., "Phase 3 closes when ≥ 10 of 12 P1 items closed *or* explicit re-prioritisation per project-lead approval") could be added if desired.
6. **(Q1 from Step 5) Soft within-phase sequencing — Story 14.5 → Story 15.1.** `make check-doc-sync` ships pre-A.1 with vacuous diagnostic power on the §X.Y.Z drift check. Acknowledged in Story 14.5 AC3 parenthetical — flagging as observable, not a defect.

### Critical Issues Requiring Immediate Action

**None.** No critical or major issues surfaced across all 5 review steps. The project is in a healthy state to proceed with Phase 3 implementation.

### Recommended Next Steps

1. **Begin Phase 3 dev-pass execution starting with the Epic 14 lead-in cluster** (Stories 14.1 → 14.2 → 14.3 → 14.4 → 14.5 in that order, per architecture's sequencing). The lead-in cluster lands the structural lints + sync targets that shape every subsequent dev-pass.
2. **Apply clarification Q2** (Story 15.2 probe-ID range) before Story 15.2 dev-pass starts — fold a single-line AC update into Story 15.2 AC5 specifying the fresh 1000..1014 range.
3. **(Optional) Apply clarification PRD-3, PRD-4** to harden PRD FR-P3-19/20 conditionality and B.5 trigger pinning. These can be deferred to a post-Story-14.5 PRD touch-up, since `make check-doc-sync` will detect transcription drift between PRD and architecture going forward.
4. **(Optional) Apply clarification PRD-5** if a concrete Phase-3 close-out threshold is desired. The current "all 12 P1 or explicit re-prioritise" framing is workable; a pinned threshold is a nice-to-have.
5. **Run `bmad-bmm-sprint-planning`** (or equivalent) to generate the Phase-3 sprint-status tracking from `epics.md`. This is the natural follow-on workflow once readiness is confirmed.
6. **At Story 15.6 close-out time, walk this readiness report's findings** alongside the standing-commitment S1–S12 audit to confirm no new gaps surfaced during dev-pass execution.

### Final Note

This assessment identified **0 critical, 0 major, and 8 minor concerns plus 6 PRD clarification opportunities** across **5 review categories** (document discovery, PRD analysis, epic coverage validation, UX alignment, epic quality review). All findings are concentrated in the **Minor / Clarification** band — no blockers exist. The PRD, Architecture, and Epics documents are well-aligned, traceable, and ready for Phase 3 implementation. Phase 3 is a debt-cleanup interlude with concrete carry-forward catalogue items, explicit conditional-disposition logic for hardware-revealed paths, and standing-commitment hold codified as NFR-P3-22..33.

The project's self-validation discipline is genuine: both PRD and epics carry their own coverage gates, and the architecture document explicitly enumerates findings F1–F7 with story owners. This readiness review's job was to verify that discipline rather than substitute for it; the verification passed.

**Assessor:** Claude Code (Opus 4.7) acting as Implementation Readiness reviewer
**Date completed:** 2026-05-08
**Workflow:** `_bmad/bmm/workflows/3-solutioning/check-implementation-readiness`
