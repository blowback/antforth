---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-05-08.md
  - _bmad-output/planning-artifacts/prd-phase2-epics-9-13.5.md
  - _bmad-output/planning-artifacts/architecture-phase2-epics-9-13.5.md
  - _bmad-output/planning-artifacts/epics-phase2-epics-9-13.5.md
  - _bmad-output/planning-artifacts/epics-phase1-epics-1-8.md
  - docs/PHASE-3-CARRY-FORWARD.md
  - _bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md
phase: 3
phaseScope: 'Phase 3 — debt-cleanup interlude (carry-forward catalogue P1 close-out + §-by-§ ANS Core/Core-Extension audit)'
---

# antforth — Epic Breakdown (Phase 3)

## Overview

This document provides the epic and story breakdown for **antforth Phase 3** — a debt-cleanup interlude on top of the shipped v2.0 baseline (commit `6599d73`, tagged `v2.0.0` 2026-05-07, 24,996 bytes, 973 PASS / 0 FAIL on real CP/M 2.2 / MicroBeast). Phase 1 (Epics 1–8) is preserved in `epics-phase1-epics-1-8.md`; Phase 2 (Epics 9–13.5) is preserved in `epics-phase2-epics-9-13.5.md`.

The phase is structured as one or more "debt-cleanup" epics drawn from `docs/PHASE-3-CARRY-FORWARD.md` (12 P1 items: A.1–A.3 standards/compliance + B.1–B.9 stabilisation/process debt). Intermediate releases tag as **antforth 2.x**. The phase concludes when all P1 items close and the §-by-§ ANS Forth Core + Core-Extension audit completes.

The two phase-defining goals are mutually reinforcing:

1. **§-level standards-compliance defensibility** — replace word-counted compliance claims with §-by-§ verified ones (the framework that caught two §-level blindspots mid-Epic-13 applied systematically across DPANS94 + Forth 2014)
2. **Story-template / process-discipline cleanup landed before the next feature epic** — B.1–B.5 lead-in shapes every subsequent dev-pass; Phase 4 inherits improved discipline rather than re-discovering Epic 13.5's six lessons

Zero new feature scope. No new user-facing words (except possibly back-fills surfaced by the §-by-§ audit). All effort directed at making the v2.0 foundation production-defensible at the §-level.

## Requirements Inventory

### Functional Requirements

**Standards-Compliance Documentation (A.1)**
- FR-P3-1: A reader of `docs/ans-forth-core-compliance.md` can find a §-level row for every mandatory rule in DPANS94 §6.1 (Core wordset) — verdict (Implemented / Implemented-with-caveat / Accepted-with-rationale-N-A), source `file:line` for the implementation, story-number for the closure (or "v2.0 baseline" for pre-Phase-3 closures), and any caveats.
- FR-P3-2: A reader of `docs/ans-forth-core-compliance.md` can find a §-level row for every implemented word in DPANS94 §6.2 (Core Extension wordset) — same row-format as FR-P3-1.
- FR-P3-3: A reader of `docs/ans-forth-core-compliance.md` can find a §-level row for every structural §-rule that applies to antforth (e.g., §3.1.4.1 double-cell stack-layout, §3.4.1.3 numeric-literal parser rule, plus any other structural rules surfaced by the A.1 audit walk).
- FR-P3-4: A reader can confirm — for any DPANS94 §6.1 / §6.2 rule that is *not* implemented in antforth — an explicit "Accepted-with-rationale: N-A" or "Deliberately-omitted: rationale" row, never a silent gap (per `feedback_no_preexisting_discharge.md`).
- FR-P3-5: Any §-level structural-rule gap surfaced by the A.1 audit is either back-filled with a focused story (the Stories 13.0 / 13.0.1 / 13.5 template — implementation + new compliance-doc row + REPL probes + hardware smoke) or explicitly accepted-with-rationale per project-lead approval.
- FR-P3-6: Every word touched by an A.1 back-fill story carries a one-line standards-citation comment in its assembly source per CCD-3 (`; ANS Forth 1994 §<sec>` / `; Forth 2014 §<sec>` / `; antforth extension`).

**Asm-Error THROW Catchability (A.2)**
- FR-P3-7: Users can wrap any antforth assembler-error-raising operation in a `CATCH` frame and receive the corresponding asm-error THROW code (any of `-258` through `-269`, plus `-270` through `-272`) on the data stack, exactly as they receive ANS-standard codes (e.g. `-4`, `-13`).
- FR-P3-8: The `tests/throw_migration_tests.fth` (or equivalent harness) exercises the caught-form path (`' WORD CATCH . CR` idiom) for each asm-error THROW code in the `-258..-272` block; each test asserts that the expected code lands on the data stack.

**Base-Aware Numeric-Literal Parsing (A.3)**
- FR-P3-9: When the user has set `BASE` to an explicit value (via `HEX`, `DECIMAL`, or direct `BASE !`), unprefixed numeric literals parse per that BASE consistently — at the REPL, in compiled colon definitions, and in the built-in Z80 assembler source.
- FR-P3-10: Forth-2014 §3.4.1.3 prefixed numeric literals (`#`/`$`/`%`/`'c'`/`0x`) continue to parse in their declared base regardless of `BASE` (FR9 from the Phase-2 PRD continues to hold; A.3 adds nothing to prefixed parsing).

**Test-Author Documentation (B.1)**
- FR-P3-11: A test author can find documented guidance — in `tests/README.md` or an inline comment block in `Makefile`'s test section — establishing `PAD` (per ANS §6.2.2000) as the canonical transient-buffer word for use in REPL-piped Forth probes that need a scratch buffer surviving one space-delimited parse. The guidance acknowledges the historic alternatives (`HERE` and `S"` allocation) and explains why `PAD` is preferred.

**Story-Template / Drafting Discipline (B.2 + B.3 + B.4)**
- FR-P3-12: A story drafter using the project's story-template encounters a HALT-signal lint when the byte-budget rationale contains "mirrors", "same shape as", or equivalent language referencing a prior arm; the lint requires the drafter to itemise the new arm's parts independently before the byte-budget rationale is accepted (B.2 — extends Lesson 13-C as Lesson 13.5-C).
- FR-P3-13: A story drafter using the project's story-template encounters, in the "Pre-edit baseline" task, an explicit instruction to capture `wc -c` of the current binary itself rather than inheriting the prior story's reported number (B.3 — closes the 6-byte 13.5.5-close-out doc-drift gap).
- FR-P3-14: A story drafter using the project's story-template encounters figure-drift discipline (PD-2): figures, tables, and code blocks are validated against the source-of-truth at draft time, not inherited from an earlier story or retro (B.4).
- FR-P3-15: The story-template's discipline edits (B.2–B.4) carry their own verdict criteria in the lead-in stories that introduce them — each B.2/B.3/B.4 story tests that the new template would have caught the prior-incident pattern that motivated it (e.g. B.2 verifies the lint catches a synthesised "mirror" phrase; B.3 verifies the `wc -c` task captures the actual binary).

**Build-Tool Sync & Hygiene (B.5 + B.6 + B.8)**
- FR-P3-16: A maintainer running the project's build can invoke a sync target (Makefile rule, doc-build script, or equivalent) that detects PRD-vs-architecture transcription drift between this PRD and the next-revised architecture document; the target produces a drift report or a clean-pass verdict (B.5 — closes PD-3).
- FR-P3-17: A contributor running `make check-tools` (or equivalent target) can confirm the iz-cpm version installed on the host matches the version the project's test baseline is calibrated against; mismatches produce a clear advisory (B.6 — closes PD-6).
- FR-P3-18: The Makefile's `make test-repl` target uses unique numeric IDs across all probes; duplicate test numbers (the Story 11.3 cosmetic gap) are renumbered on the first Makefile-touching Phase-3 story (B.8).

**Filesystem Stress Coverage (B.7 + B.9)**
- FR-P3-19: Probe coverage for directory-full failure mode (writing past the maximum-files-per-directory CP/M 2.2 limit) exists in `tests/file_access_tests.fth` (or equivalent harness), exercising both the failed-write `ior` return path and the FCB-pool / filesystem-state consistency post-failure (B.7 — conditional on hardware-revealed need; otherwise B.7 evaluation suffices).
- FR-P3-20: Probe coverage for zero-byte `READ-FILE` exists in `tests/file_access_tests.fth` (or equivalent harness), exercising the `( c-addr 0 fileid -- 0 0 )` no-op path (B.7 — conditional, same disposition as FR-P3-19).
- FR-P3-21: Disk-full handling (writing past the B: ramdisk capacity) is verified clean on real CP/M 2.2 / MicroBeast hardware via a hardware-typed probe; the probe asserts a non-zero `ior` return, FCB-pool consistency, and filesystem consistency post-failure (B.9).

**Backward Compatibility & Regression (phase-wide constraint)**
- FR-P3-22: All functional behaviour delivered in Phase 1 (Epics 1–8) and Phase 2 (Epics 9–13.5) — the full Phase-2 FR1–FR47 set, including REPL behaviour, colon definitions, variables, constants, `CREATE`/`DOES>`, control flow, error reporting, `MARKER`, `CATCH`/`THROW`, multi-vocabulary Search-Order, File-Access wordset, Forth-2014 §3.4.1.3 numeric-literal prefixes including `0x`, double-precision arithmetic, pictured numeric output, the unchanged hard-coded inline assembler, and all existing word semantics — continues to work identically in every Phase-3 antforth 2.x point-release.
- FR-P3-23: All existing REPL-piped test scripts (the 1..952 baseline plus the 944..964 Epic-13.5 cleanup-slate probes) continue to pass against every Phase-3 antforth 2.x point-release. Zero regressions on either set is a release blocker (per Phase-2 NFR9, carried forward).
- FR-P3-24: All existing CODE-word source files written against pre-Phase-3 antforth assemble correctly and produce byte-identical output under every Phase-3 antforth 2.x point-release (extends Phase-2 FR31, NFR14).
- FR-P3-25: The unprefixed numeric-literal form (`<BASEnum>`) continues to be parsed per the current value of `BASE` identically to pre-Phase-3 antforth, *except* for the A.3 enhancement covered by FR-P3-9 (which is itself a refinement of the pre-Phase-3 behaviour to be more strictly base-aware in edge cases the pre-Phase-3 implementation handled inconsistently).

### NonFunctional Requirements

**Performance**
- NFR-P3-1 (carries Phase-2 NFR1–NFR5): All performance envelopes from the Phase-2 PRD continue to hold across every Phase-3 antforth 2.x point-release. Specifically: numeric-literal prefix parse overhead ≤ ~20 Z80 cycles over unprefixed (NFR1); multi-vocabulary lookup regression ≤ 10% vs single-vocabulary baseline (NFR2); uncaught CATCH frame overhead ≤ ~15 Z80 cycles (NFR3); per-epic ROM-footprint budget logged and justified (NFR4); double-precision primitives within ~20% of hand-rolled Z80 equivalents (NFR5). No Phase-3 work measurably regresses any of these envelopes; if any back-fill story would, sprint-change-proposal evaluation is triggered.
- NFR-P3-2 (Phase-3-specific cumulative ROM budget): Phase-3 cumulative binary growth is capped at +200 bytes (24,996 → ≤ 25,200). Per-story envelopes: B.1–B.5 ≈ 0; A.1 audit story ≈ 0; A.1 back-fill stories ~+10..+50 each (Story 13.0 / 13.0.1 / 13.5 precedent); A.2/A.3 ~+0..+30 each; B.6 ~0; B.7 conditional; B.8 ~0; B.9 ~0. Per-story envelopes are checked against the cumulative target; any single story that would push cumulative over the cap triggers a HALT signal and project-lead-approval before proceeding.

**Reliability**
- NFR-P3-3 (carries Phase-2 NFR6 — REPL survivability): The REPL survives any THROW, including stack overflow, division by zero, undefined-word invocation, and the asm-error THROW codes (-258..-272). User's dictionary, in-session definitions, and working state are preserved across errors.
- NFR-P3-4 (carries Phase-2 NFR7 — state integrity after error): No internal data structure (dictionary, wordlists, input buffer, pad, return stack, FCB pool, INCLUDE source frames) may be left in a corrupted or inconsistent state after a THROW. Standard ANS catch-frame cleanup semantics apply.
- NFR-P3-5 (carries Phase-2 NFR8 — filesystem error recovery): Failures during file operations (disk full, file locked, I/O error from BDOS, directory full, zero-byte read) raise a THROW or return an `ior` per the Story-13.2/13.5.1/13.5.2 split, leaving the filesystem in a consistent state — no partial writes that corrupt CP/M directory entries, no orphaned file handles. Phase-3 delta: B.7 + B.9 close the directory-full / zero-byte READ-FILE / disk-full coverage gaps.
- NFR-P3-6 (Phase-3 test-baseline regression guarantee — extends Phase-2 NFR9): The complete Phase-1 + Phase-2 + Epic-13.5 test suite (1..952 baseline plus 944..964 cleanup-slate probes = 973 PASS / 0 FAIL) passes on every Phase-3 antforth 2.x point-release candidate. A single regression on any of the 973 tests is a release blocker. Additional Phase-3 probes are welcome but additive — they do not replace the baseline.
- NFR-P3-7 (mid-epic hardware-smoke cadence per story — codifies S9): Every binary-delta Phase-3 story runs its own hardware-smoke task on real CP/M 2.2 / MicroBeast with a PASS verdict before the story is considered done. Zero-binary-delta stories (e.g. B.1–B.5 doc/template-only stories) document their S9 exemption explicitly. The cadence prevents Epic-13's "only the close-out story ran hardware smoke" anti-pattern.

**Compatibility & Standards Conformance**
- NFR-P3-8 (carries Phase-2 NFR10 — ANS Forth 1994 Core compliance): The Core wordset (DPANS94 §6.1) is implemented to 100% coverage with behaviour matching the ANS specification. Phase-3 delta: the compliance measurement is upgraded from word-counted to §-level — a §-by-§ audit walks every mandatory rule (not just every word), backed by per-rule rows. This is the A.1 strategic body.
- NFR-P3-9 (carries Phase-2 NFR11 — Forth 2014 §3.4.1.3 conformance): Numeric-literal prefix syntax is implemented verbatim per Forth 2014 §3.4.1.3 (carries forward from v2.0 baseline). Phase-3 delta: A.3 unprefixed `NUMBER?` base-specialization closes the residual edge case where the pre-Phase-3 implementation handled unprefixed parsing inconsistently against the BASE setting.
- NFR-P3-10 (carries Phase-2 NFR12 — extension discipline): The only non-standard additions to date are the `0x` hex-literal prefix (Epic 9), the `INCLUDE-TOP` / `CATCH-TOP` USER-variable extensions (Epic 11/13), and the asm-error THROW codes `-258..-272`. All clearly flagged in source per CCD-3. Phase 3 introduces no new extensions.
- NFR-P3-11 (carries Phase-2 NFR13 — CP/M 2.2 BDOS integration): antforth uses only CP/M 2.2 standard BDOS functions (the existing Phase-2 allow-list: 0, 1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 25, 26, 27, 33, 34, 35, 36, 40). No CP/M Plus, MP/M, or extended BIOS-level calls. Phase 3 does not add any new BDOS functions to the allow-list.
- NFR-P3-12 (carries Phase-2 NFR14 — CODE-word source file backward compatibility): CODE-word source files written against pre-Phase-3 antforth assemble correctly and produce byte-identical output under every Phase-3 antforth 2.x point-release.
- NFR-P3-13 (Phase-3 §-level compliance auditability): `docs/ans-forth-core-compliance.md` carries enough information per row (§-number, source `file:line`, story-number for closure, caveats) that an external Forth implementor can verify any single row against the standard text and the source code in under 10 minutes.

**Maintainability**
- NFR-P3-14 (carries Phase-2 NFR15 — code density and readability): Z80 assembly source favours readability over micro-optimisation, except where the epic explicitly targets performance. Comments on non-obvious logic are required; comments re-stating what assembly already says are forbidden. Phase 3 specifically: A.1 back-fill stories follow the Story 13.0 / 13.0.1 / 13.5 commenting style — every back-filled word carries its standards-citation comment per CCD-3.
- NFR-P3-15 (carries Phase-2 NFR16 — test-first discipline): Every new word, every behaviour change, and every defect closure introduced in Phase 3 has REPL-piped Forth test coverage before being declared done (per established project convention since Epic 3, codified by S2). Test scripts are the canonical regression surface.
- NFR-P3-16 (carries Phase-2 NFR17 — single-source-of-truth for standards references): Word behaviours that derive from a standard cite the standard section in the source comment per CCD-3 (`; ANS Forth 1994 §<sec>` etc.). Phase-3 delta: the A.1 audit walk re-verifies every existing citation against `docs/ans-forth-core-compliance.md`'s §-level rows; mismatches are surfaced and corrected as part of the audit story.
- NFR-P3-17 (carries Phase-2 NFR18 — epic-level decoupling): Each Phase-3 epic delivers an independently-shippable antforth 2.x point-release. Intermediate releases are legitimate release artifacts, not internal milestones. The Phase-3 close-out tag is the final 2.x version.
- NFR-P3-18 (Phase-3 story-template discipline as quality attribute): The story-template lints / HALT signals / pre-edit task additions established by B.1–B.5 fire automatically when triggered (lint catches "mirrors" phrase, `wc -c` task captures actual binary, figure-drift discipline applies at draft time, PRD-vs-architecture sync runs at doc-build time). A story drafter does not need to remember to invoke them; they are baked into the workflow.

**Integration (CP/M and Platform — Phase 2 carry-forward)**
- NFR-P3-19 (carries Phase-2 NFR19 — terminal I/O portability): antforth uses only character-based BDOS console I/O (functions 1, 2, 6, 9). No assumption of ANSI escape codes, cursor positioning, line-mode vs raw-mode toggles, or colour support.
- NFR-P3-20 (carries Phase-2 NFR20 — file path conventions): `INCLUDE` and related words accept CP/M 2.2 file path syntax (optional drive letter + `:` + 8.3 filename) exactly. No wildcards in scope; no Unix-style paths.
- NFR-P3-21 (carries Phase-2 NFR21 — MicroBeast hardware dependency isolation): No MicroBeast-specific hardware word enters the kernel during Phase 3. The MicroBeast hardware vocabulary is a Phase-4+ epic and must be loadable as pure Forth source from disk, not kernel-resident.

**Process Discipline (NEW for Phase 3 — codifies S1–S12 standing commitments)**
- NFR-P3-22 (S1 — adversarial review fresh-context external): Code reviews are conducted via the `/CR` command (fresh-context external) per the post-PD-1 structural close, not in-pass within the dev-pass. Every Phase-3 retro confirms eleven-plus consecutive epics with structurally-fresh-context CR location.
- NFR-P3-23 (S2 — REPL-piped tests as default): New tests in Phase 3 are REPL-piped Forth scripts, not assembly test thread extensions. Probes follow S12 hardware-typed authoring discipline.
- NFR-P3-24 (S3 — real-byte-count estimation + capstone-aware drafting): Story byte-budget rationale is itemised per-part, not asserted via "mirrors prior arm" shorthand (extended by B.2 / Lesson 13.5-C). The story-template lint (FR-P3-12) catches the shorthand pattern.
- NFR-P3-25 (S4 — AC-composition validation): Story acceptance criteria are validated for composability — each AC stands alone or in composition with its named antecedents; no AC silently depends on another's side-effects.
- NFR-P3-26 (S5 — PARTIAL → HALT): PARTIAL verdicts (any AC not fully PASS) trigger a HALT signal at the dev-pass; root-cause is handled in-pass or the story spawns a sibling, with no carry-forward as tech debt.
- NFR-P3-27 (S6 — inventory grep covers helpers, not just leaves): Story inventory grep walks the helper layer (e.g. `asm_die` callers, `file_byte_read` callers, `check_underflow` callers) not just the user-facing word, ensuring fan-in completeness.
- NFR-P3-28 (S7 — EXX-hygiene per kernel-internal raise site): Kernel sites that raise THROW (the `-258..-272` block, the standard codes) preserve EXX state per the established §3 leaf-level rule and §7 EXX-using inventory in `docs/register-conventions.md`.
- NFR-P3-29 (S8 — "pre-existing" cannot discharge correctness defects): Per `feedback_no_preexisting_discharge.md`, correctness defects (clobbers, lost writes, silent error swallowing) cannot be marked "accepted-with-rationale: pre-existing" — they must be surfaced, filed, fixed (or explicitly re-prioritised down with project-lead approval).
- NFR-P3-30 (S9 — mid-epic hardware-smoke cadence per story): Codified as NFR-P3-7 above (binary-delta stories run their own S9 hardware-smoke).
- NFR-P3-31 (S10 — workflow > memory > prompt): Process / discipline fixes land in workflow files (BMAD step files, story templates, agent definitions) and codified-discipline files (memory entries, `feedback_*.md`), not in conversational prompts. The Phase-3 lead-in stories (B.1–B.5) themselves are workflow-file edits, not prompt edits.
- NFR-P3-32 (S11 — user-visible version surface audit row at tag-applicable epic close-out): Every Phase-3 antforth 2.x point-release tag passes the user-visible version surface audit (banner string in binary, README version reference, memory-file `description` fields). Mismatches against the tag being applied are HALT signals.
- NFR-P3-33 (S12 — hardware-typed probe authoring discipline): Every smoke-batch destined for human typing on real hardware passes (a) word-existence pre-flight (every word resolves in antforth's dictionary or is documented as a planned new word) and (b) TIB-128 line-length lint (every line ≤ 128 chars). The `tests/README.md` (or equivalent) per FR-P3-11 documents these conventions for test authors.

### Additional Requirements

These are technical and process requirements drawn from the Phase-3 Architecture document, the carry-forward catalogue, and the Epic-13.5 retrospective standing commitments. They shape epic and story decomposition without being raised to FR/NFR-level capability statements.

**Architectural decisions (CCD layer):**
- CCD-1, CCD-2, CCD-3, CCD-4 (Phase-2 carry-forward, unchanged): dual-chain return-stack frame discipline; THROW code allocation across `-1..-58` / `-59..-255` / `-256..-32767`; standards-citation discipline; per-epic benchmark/close-out gate. Phase-3 reaffirms CCD-2 with the asm-error block extended to `-258..-272` post-Story-11.5.6 (15 codes; A.2 closes caught-form for the full block).
- **CCD-P3-1** (NEW): every row in `docs/ans-forth-core-compliance.md` follows a 6-column schema — `§ | Rule | Verdict | Source (file:line) | Closure (story-number) | Notes`. Verdict values: `Implemented` / `Implemented-with-caveat` / `Accepted-with-rationale-N-A` / `Deliberately-omitted`. Structural rules satisfied behaviourally use `Source: N-A` with explanatory Notes (per finding F1).
- **CCD-P3-2** (NEW): Process discipline lives in workflow files (`_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`, `template.md`, `checklist.md`; agent definitions; Makefile sync targets; `tests/README.md`), not in conversational prompts or memory entries. Lints fire structurally (artifact-existence; grep-able verdict criteria), not aspirationally. Memory entries / `feedback_*.md` document *why*, workflow files enforce *how*.

**Per-item architectural decisions:**
- A.1-D2: One §-by-§ audit story produces all rows for §6.1 + §6.2 + structural rules; back-fill stories (0–2 expected) spawn from the audit's verdict per gap. If the audit surfaces > 5 gaps, propose sprint-change with re-prioritised cut.
- A.1-D3: Each back-fill story includes (1) implementation in `src/*.asm` or `tests/*.fth`, (2) standards-citation comment per CCD-3, (3) new row in `docs/ans-forth-core-compliance.md` per CCD-P3-1, (4) REPL probes (positive path + edge case), (5) S9 hardware smoke, (6) **pre-fix negative-result confirmation** — pre-fix code fails the new probe; diff captured in Dev Notes.
- A.2-D1: caught-form tests extend `tests/throw_migration_tests.fth`; one probe per asm-error code in `-258..-272`.
- A.3-D1: change lands in `w_NUMBER_Q_cf` in `src/strings.asm` — site is binding (per finding F5); behaviour-spec deferred to story-author.
- B.1-D1: `tests/README.md` (NEW) is the single source of truth; Makefile test section gets one-line pointer comment.
- B.2-D1: "Mirrors prior arm" HALT lands in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` as a `<critical>` block (PD-1 precedent). Triggers on "mirrors", "same shape as", "this is the X arm", or any "Story Y" reference in byte-budget rationale.
- B.3-D1: re-`wc -c` task lands in `_bmad/bmm/workflows/4-implementation/create-story/template.md` "Pre-edit baseline" section; explicit "do not inherit prior story's number".
- B.4-D1: PD-2 figure-drift lands in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` as a `<critical>` block (sibling of B.2).
- B.5-D1: new `make check-doc-sync` target, invoking project-local script in `tools/check-doc-sync/` (NEW). Drift checks: FR-P3-N / NFR-P3-N labels resolve PRD↔arch; Story X.Y citations resolve in epics docs; §X.Y.Z references match `ans-forth-core-compliance.md` rows; section-name parity. Advisory-only on `make test-repl`; expected clean before tag close-out.
- B.6-D1: new `make check-tools` target reading `.tool-versions` (NEW). Compares iz-cpm + sjasmplus versions. Advisory by default; opt-in `STRICT=1` exits 1. B.6 story includes introspection sub-task to populate `.tool-versions` (per finding F4).
- B.7-D1: conditional. Disposition (a) "Evaluation suffices" closes via hardware-smoke run with no surprises; disposition (b) "Probe story spawned" fires on hardware-revealed signal (wrong ior, orphaned FCB, directory corruption, FCB-pool recovery failure).
- B.7+B.9 combined: one S9 hardware-smoke task on one Phase-3 story exercises both. **Disk-full and directory-full are different failure modes** (block-storage vs directory-entry exhaustion; per finding F2) — B.9's procedure is split into sub-step (a) disk-full (one large file) and sub-step (b) directory-full (many small files); both assert FCB-pool + filesystem consistency. Zero-byte READ-FILE single-call adds trivially.
- B.9-D1: extend `tests/file_access_tests.fth` with disk-full stress block; same procedure resolves B.7 disposition.
- B.8: mechanical Makefile renumber on next Makefile-touching Phase-3 story (most likely B.5 or B.6).

**Sequencing constraint (locked by carry-forward catalogue):**
- **Lead-in (must land first):** B.1 + B.2 + B.3 + B.4 + B.5. Story-template / process-discipline edits that shape every subsequent dev-pass.
- **Strategic body:** A.1 audit story → 0–2 back-fill stories per §-level structural-rule gap surfaced.
- **Hitch-hikers (fold opportunistically):** A.2 (any THROW-test sprint), A.3 (any number-parsing sprint), B.6 (any tooling sprint), B.8 (next Makefile-touching story), B.9 (any hardware-touching story).
- **Conditional:** B.7 if hardware-revealed need from B.9 / S9 cadence; otherwise 2.x maintenance.

**Standing commitments (S1–S12) — codified as NFR-P3-22..33, must hold across every Phase-3 epic close-out:** S1 adversarial CR fresh-context; S2 REPL-piped tests; S3 real byte-count estimation (extended by Lesson 13.5-C); S4 AC-composition validation; S5 PARTIAL→HALT; S6 inventory grep covers helpers; S7 EXX-hygiene per raise site; S8 no "pre-existing" discharge for correctness defects; S9 per-story hardware smoke; S10 workflow > memory > prompt; S11 version-surface audit at tag close-out; S12 hardware-typed probe discipline.

**Findings F1–F7 from architecture validation, actionable in owning stories:**
- F1: CCD-P3-1 satisfied-behaviourally case → A.1 audit story carries example row pattern (`Source: N-A` + Implemented).
- F2: B.7+B.9 disk-full vs directory-full distinct failure modes → B.9 story splits procedure into two sub-steps.
- F3: CCD-P3-2 "structural" = artifact-existence (grep-able), not automated-CI; agent obedience is the residual softer discipline that adversarial review (`/CR`) catches.
- F4: B.6 `.tool-versions` initial content unknown → B.6 story includes introspection sub-task; fallback to current host's versions if v2.0 baseline can't be retraced.
- F5: A.3 site decision is binding; story-author discretion is over the behaviour delta, not the site.
- F6: A.1 citation-cleanup overflow → if audit surfaces > 20 mismatches, spawn follow-up "citation cleanup" hitch-hiker story; audit-story diff bounded to doc rows + ≤ 20 in-pass citation fixes.
- F7: A.1 row grain — produce rows for both word definitions AND structural §-rules; some §-numbers appear in multiple rows; audit-story spec lists worked example.

**File-touch surface for Phase 3 (from architecture):**

NEW files: `tests/README.md` (B.1); `tools/check-doc-sync/` script + README (B.5); `.tool-versions` (B.6); `_bmad-output/implementation-artifacts/phase3-a1-<§-rule>-<slug>.md` per back-fill (A.1 conditional); `_bmad-output/implementation-artifacts/<epic>-retro-<date>.md` per epic close.

MODIFIED files: `Makefile` (B.5 / B.6 / B.8 / B.1 pointer); `_bmad/bmm/workflows/4-implementation/create-story/{instructions.xml,template.md,checklist.md}` (B.2 / B.3 / B.4); `docs/ans-forth-core-compliance.md` (A.1); `docs/PHASE-3-CARRY-FORWARD.md` (status column per item); `tests/throw_migration_tests.fth` (A.2); `tests/file_access_tests.fth` (B.9 + B.7 conditional); `src/strings.asm` (A.3); `src/antforth.asm` banner + `README.md` + `memory/project_phase2_scope.md` `description` fields per Phase-3 tag (S11); `_bmad-output/implementation-artifacts/sprint-status.yaml` per story.

NOT touched: `src/assembler.asm`; `src/inner_interpreter.asm`; `src/outer_interpreter.asm`; `src/exception.asm`; `src/file_access.asm` (test-only B.7/B.9 unless hardware reveals defects); `src/wordlists.asm`, `src/compiler.asm`, `src/dictionary.asm`, `src/hash.asm`, `src/control_flow.asm`; `src/structures.asm` (UserArea); `disk/`, `build/`, `examples/`, `blog/`, `images/`, `reference_docs/`.

**Per-story binary delta envelopes (NFR-P3-2 cumulative cap +200 bytes):**

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

### FR Coverage Map

| FR-P3-N | Epic | Carry-forward item | Brief description |
|---|---|---|---|
| FR-P3-1 | Epic 15 | A.1 | DPANS94 §6.1 Core per-rule rows in `docs/ans-forth-core-compliance.md` |
| FR-P3-2 | Epic 15 | A.1 | DPANS94 §6.2 Core Extension per-rule rows |
| FR-P3-3 | Epic 15 | A.1 | Structural §-rule rows (§3.1.4.1, §3.4.1.3, plus any surfaced) |
| FR-P3-4 | Epic 15 | A.1 | "Accepted-with-rationale-N-A" / "Deliberately-omitted" rows for non-implemented rules — no silent gaps |
| FR-P3-5 | Epic 15 | A.1 | §-level structural-rule gaps back-filled (per A.1-D3 six-step shape) or explicitly accepted-with-rationale |
| FR-P3-6 | Epic 15 | A.1 | CCD-3 standards-citation comment on every back-filled word |
| FR-P3-7 | Epic 15 | A.2 | Caught-form CATCH path returns asm-error code (-258..-272) on data stack |
| FR-P3-8 | Epic 15 | A.2 | `tests/throw_migration_tests.fth` exercises caught-form for each of the 15 asm-error codes |
| FR-P3-9 | Epic 15 | A.3 | Unprefixed numerals parse per explicit BASE consistently |
| FR-P3-10 | Epic 15 | A.3 | Forth-2014 §3.4.1.3 prefixed literals continue to ignore BASE (regression-only) |
| FR-P3-11 | Epic 14 | B.1 | `tests/README.md` documents PAD as canonical transient-buffer per ANS §6.2.2000 |
| FR-P3-12 | Epic 14 | B.2 | Story-template "mirrors prior arm" HALT-signal lint |
| FR-P3-13 | Epic 14 | B.3 | Story-template "Pre-edit baseline" re-`wc -c` task |
| FR-P3-14 | Epic 14 | B.4 | Story-template figure-drift discipline (`<critical>` block) |
| FR-P3-15 | Epic 14 | B.2/B.3/B.4 | Verdict-criterion meta-pattern — each lead-in story tests its own enforcement |
| FR-P3-16 | Epic 14 | B.5 | `make check-doc-sync` PRD↔architecture transcription-drift target |
| FR-P3-17 | Epic 15 | B.6 | `make check-tools` iz-cpm version stability advisory |
| FR-P3-18 | Epic 15 | B.8 | Makefile test-numbering hygiene (renumber duplicates from Story 11.3) |
| FR-P3-19 | Epic 15 | B.7 conditional | Directory-full failure-mode probe coverage |
| FR-P3-20 | Epic 15 | B.7 conditional | Zero-byte READ-FILE probe coverage |
| FR-P3-21 | Epic 15 | B.9 | Disk-full hardware re-verification on real CP/M 2.2 / MicroBeast |
| FR-P3-22 | Both | Phase-wide regression | Phase-1 + Phase-2 + Epic-13.5 functional behaviour preserved |
| FR-P3-23 | Both | Phase-wide regression | 973 PASS / 0 FAIL test baseline maintained on every 2.x release candidate |
| FR-P3-24 | Both | Phase-wide regression | Pre-Phase-3 CODE-source byte-identical assembly under every 2.x |
| FR-P3-25 | Both | Phase-wide regression | Unprefixed numeric-literal form preserved (with A.3 base-aware refinement) |

**Coverage check:** all 25 FR-P3-N requirements mapped. All 12 P1 carry-forward items (A.1, A.2, A.3, B.1–B.9) covered. Phase-wide regression constraint (FR-P3-22..25 + NFR-P3-6) holds across every story in both epics. Standing commitments S1–S12 (codified as NFR-P3-22..33) held across both epic close-outs.

## Epic List

### Epic 14: Phase-3 Process Foundation

**Goal:** Land the story-template / drafting-discipline / build-tool sync cluster (B.1–B.5) before any non-lead-in Phase-3 story drafting begins. Establishes the structural lints + Makefile sync targets that shape every subsequent Phase-3 dev-pass and that Phase 4 inherits cleanly.

**User value delivered:**
- **Ant (project lead, internal user):** authoring Phase-3+ stories is structurally protected against the four traps Epic 13.5 surfaced — "mirrors prior arm" byte-budget shorthand (Lesson 13.5-C), inheriting prior story's `wc -c` (Lesson 13.5-F), figure drift (PD-2), and PRD-vs-architecture transcription drift (PD-3). Lints fire structurally per CCD-P3-2, not aspirationally.
- **Test authors (the OG and the Newb authoring their first probe):** PAD documented as canonical transient-buffer in `tests/README.md`; the Story-13.5.1 HERE-collision class is documented and avoidable.
- **Phase 4 (downstream):** improved discipline inherited from day one rather than re-discovered in another retro.

**FRs covered:** FR-P3-11 (B.1), FR-P3-12 (B.2), FR-P3-13 (B.3), FR-P3-14 (B.4), FR-P3-15 (verdict-criterion meta-pattern), FR-P3-16 (B.5). Phase-wide regression constraint (FR-P3-22..25) holds across every Epic-14 story.

**NFRs delivered:** NFR-P3-18 (story-template discipline as quality attribute); NFR-P3-31 (S10 workflow > memory > prompt — codified at architectural level via CCD-P3-2). All 33 NFR-P3-N continue to hold.

**Carry-forward items closed:** B.1, B.2, B.3, B.4, B.5 (5 of 12 P1 items).

**Shape:** 5 stories, all workflow-file / Makefile / `tests/README.md` edits. Per-story binary delta ≈ 0 (lead-in cluster is doc/template-only). Tag-applicable close-out (S11 audit) on Ant's call — banner-only point-release valid but optional. Files touched: `_bmad/bmm/workflows/4-implementation/create-story/{instructions.xml,template.md,checklist.md}`, `Makefile`, `tools/check-doc-sync/` (NEW), `tests/README.md` (NEW).

**Standalone:** complete on its own — process-foundation infrastructure landed; Epic 15 builds on it but doesn't require it to function (Epic 15 stories *would* execute without it, just without the lints catching drafting drift).

**Risk/dependencies:** Epic-14 lead-in stories carry their own verdict criteria — each B.2/B.3/B.4 story tests that the new template would have caught the prior incident pattern (synthesised "mirror" phrase surfaces HALT signal; pre-edit task references `wc -c` directly grep-able from template; figure-drift `<critical>` block exists). If a lead-in fails its own verdict, it doesn't ship. Discipline-as-deliverable, not aspiration.

---

### Epic 15: Phase-3 Standards Close-Out

**Goal:** Complete the §-by-§ ANS Forth Core + Core-Extension audit (the strategic body), close all standards/compliance gaps (A.2 caught-form THROW; A.3 base-aware NUMBER?), and fold in the remaining hitch-hikers (B.6 check-tools; B.7 conditional; B.8 test-numbering hygiene; B.9 disk-full hardware re-verification). Phase-3 close-out tag (final antforth 2.x version) applied at end after the verdict-table walk + S11 user-visible version surface audit.

**User value delivered:**
- **Hana the Forth auditor (Phase-3-specific external persona):** `docs/ans-forth-core-compliance.md` carries §-level rows for every mandatory rule in DPANS94 §6.1 + §6.2 + structural §-rules per CCD-P3-1's 6-column schema. Compliance claim becomes checkable rule-by-rule against the standard text in under 10 minutes per row (Journey 5; NFR-P3-13).
- **Mo the OG (caught-form closure):** asm-error THROW codes -258..-272 catchable via `' WORD CATCH . CR` exactly as ANS-standard codes; defensive harnesses around experimental CODE words work without asym (Journey 2).
- **Raj the Newb (base-aware HEX):** unprefixed numerals parse per explicit BASE consistently across REPL / colon body / assembler source; the "wait, why is decimal showing as hex?" gotcha doesn't happen (Journey 3).
- **Pete the hardware/peripheral dev:** disk-full / directory-full / zero-byte READ-FILE failure modes documented and FCB-pool-consistent on real CP/M 2.2 (Journey 4).
- **Mo (non-regression baseline holder):** v2.0 behaviour identical; 973 PASS / 0 FAIL maintained or extended; per-story S9 hardware smoke for every binary-delta story (Journey 1).
- **Contributors (Pete-adjacent):** `make check-tools` confirms iz-cpm + sjasmplus versions against the certified baseline.

**FRs covered:** FR-P3-1..6 (A.1 §-level docs + back-fills), FR-P3-7..8 (A.2 caught-form), FR-P3-9..10 (A.3 base-aware NUMBER?), FR-P3-17 (B.6), FR-P3-18 (B.8), FR-P3-19..20 (B.7 conditional), FR-P3-21 (B.9). Phase-wide regression constraint (FR-P3-22..25) holds across every Epic-15 story.

**NFRs delivered:** NFR-P3-2 (cumulative ROM cap +200 bytes enforced per-story); NFR-P3-7 / S9 (hardware smoke per binary-delta story); NFR-P3-8 (§-level Core compliance, upgraded from word-counted); NFR-P3-9 (A.3 strict base-aware refinement); NFR-P3-13 (compliance-doc row checkability under 10 minutes); NFR-P3-32 / S11 (version-surface audit at Phase-3 close-out tag). All 33 NFR-P3-N continue to hold.

**Carry-forward items closed:** A.1, A.2, A.3, B.6, B.7 (conditional), B.8, B.9 (7 of 12 P1 items; combined with Epic-14's 5 → 12 of 12 at Phase-3 close-out).

**Shape:** ≥7 stories — A.1 audit story + 0–2 conditional A.1 back-fill stories + A.2 + A.3 + B.6 + B.8 + B.9 + B.7 conditional + Phase-3 close-out gate (verdict-table walk per Story-13.5.6 precedent). Cumulative binary delta ≤ +200 bytes (dominated by 0–2 expected A.1 back-fills @ +10..+50 each + A.3 @ +0..+30). Files touched: `docs/ans-forth-core-compliance.md` (A.1 — the strategic doc), `tests/throw_migration_tests.fth` (A.2), `src/strings.asm:w_NUMBER_Q_cf` (A.3), `Makefile` + `.tool-versions` (B.6), `Makefile` (B.8), `tests/file_access_tests.fth` (B.9 + B.7 conditional), `docs/PHASE-3-CARRY-FORWARD.md` status column (every item), `src/antforth.asm` banner + `README.md` + memory `description` fields per Phase-3 close-out tag (S11). Conditional: `src/*.asm` for any A.1 back-fill (one `cf:` label per gap surfaced).

**Standalone:** Epic 15 builds on Epic 14's discipline lints but functions independently — A.1 / A.2 / A.3 / B.6 / B.7 / B.8 / B.9 each have their own kernel/test/doc surface and don't depend on Epic 14's outputs to execute. Epic 14 simply makes Epic 15's drafting smoother (lints fire when drafter writes "mirrors", `wc -c` task captures actual binary, `make check-doc-sync` flags PRD↔arch drift before tag).

**Risk/dependencies:**
- A.1 audit may surface > 5 gaps → sprint-change-proposal evaluation (some accepted-with-rationale; some Phase-3-deferred to Phase-3.5 micro-phase).
- A.1 may surface > 20 citation-comment mismatches → spawn follow-up "citation cleanup" hitch-hiker story (per finding F6); audit-story diff bounded to doc rows + ≤ 20 in-pass citation fixes.
- B.7 conditional disposition (a) "Evaluation suffices" closes via hardware-smoke run with no surprises; disposition (b) "Probe story spawned" fires on hardware-revealed signal per finding F2.
- B.9's hardware procedure splits into sub-step (a) disk-full (one large file) + sub-step (b) directory-full (many small files) — per finding F2; both assert FCB-pool + filesystem consistency post-failure.
- Per-story binary delta envelope checked at every dev-pass; HALT signal if any single story would push cumulative over +200-byte cap (NFR-P3-2).
- Every binary-delta Epic-15 story runs its own S9 hardware smoke before being declared done (NFR-P3-7); zero-binary-delta stories document S9 exemption explicitly.

---

**Cross-epic invariants:**

- **Phase-wide regression constraint** (FR-P3-22..25 + NFR-P3-6): every story in both epics maintains the 973 PASS / 0 FAIL baseline; zero regressions on 1..952 + 944..964 sets is a release blocker.
- **Standing commitments S1–S12** (codified as NFR-P3-22..33): hold across every story, every retro, every tag close-out in both epics. The verdict-criterion meta-pattern from Epic 14's lead-in cluster makes the S1..S12 hold structurally visible.
- **Cumulative ROM budget** (NFR-P3-2): +200 bytes phase-wide; per-story envelope table in PRD §"MVP Feature Set" + architecture §"Decision Impact Analysis"; checked at every dev-pass.
- **Hardware-smoke discipline** (S9 / NFR-P3-7): per-story for binary-delta stories; documented exemption for zero-binary-delta stories.
- **Tag-applicable close-out audit** (S11 / NFR-P3-32): banner / README / memory `description` fields aligned at every Phase-3 antforth 2.x point-release tag.
- **Findings F1–F7** from architecture validation are owned by specific stories — A.1's audit story carries F1 (satisfied-behaviourally case), F6 (citation-cleanup overflow), F7 (row grain word vs structural-rule); B.9's story carries F2 (disk-full vs directory-full distinction); A.3's story acknowledges F5 (site is binding); B.6's story carries F4 (.tool-versions introspection sub-task); F3 (CCD-P3-2 "structural" wording clarification) is read inline with this section.


## Epic 14: Phase-3 Process Foundation

Land the 5-item B.x lead-in cluster (B.1 + B.2 + B.3 + B.4 + B.5) before any non-lead-in Phase-3 story drafting begins. Establishes the structural lints + Makefile sync targets that shape every subsequent Phase-3 dev-pass and that Phase 4 inherits cleanly.

**User outcomes at epic close-out:**
- Ant (project lead) authoring Phase-3+ stories is structurally protected against the four traps Epic 13.5 surfaced — "mirrors prior arm" byte-budget shorthand (Lesson 13.5-C), inheriting prior story's `wc -c` (Lesson 13.5-F), figure drift (PD-2), and PRD-vs-architecture transcription drift (PD-3). Lints fire structurally per CCD-P3-2.
- Test authors find canonical PAD-as-transient-buffer guidance in `tests/README.md`; Story-13.5.1 HERE-collision class is documented and avoidable.
- Phase 4 (downstream) inherits improved discipline rather than re-discovering it.

**FRs covered:** FR-P3-11, FR-P3-12, FR-P3-13, FR-P3-14, FR-P3-15, FR-P3-16. Phase-wide regression constraint (FR-P3-22..25) holds across every Epic-14 story.

**NFRs delivered:** NFR-P3-18 (story-template discipline as quality attribute); NFR-P3-31 (S10 workflow > memory > prompt — codified at architectural level via CCD-P3-2). All 33 NFR-P3-N continue to hold.

**Carry-forward items closed at epic close-out:** B.1, B.2, B.3, B.4, B.5 (5 of 12 P1 items).

### Story 14.1: PAD documented as canonical transient-buffer for test authors

As a test author writing a REPL-piped Forth probe,
I want clear documented guidance on which transient-buffer word to use,
So that I avoid the Story-13.5.1 HERE-collision class and don't have to re-discover the convention every time.

**Acceptance Criteria:**

**Given** Phase-3 starts with no `tests/README.md`,
**When** Story 14.1 is dev-passed,
**Then** `tests/README.md` exists at the project root's `tests/` directory.
**And** AC2 — `tests/README.md` contains a section establishing PAD (per ANS §6.2.2000) as the canonical transient-buffer word for one-shot scratch surviving a single space-delimited parse.
**And** AC3 — the doc acknowledges that `HERE` and `S"`-near-HERE writes were used historically and explains *why* they're avoided post-Story-13.5.1 (the transient-buffer-collision incident — `S"` allocates near HERE; `HERE C@` post-`READ-FILE` returns the residual `S"` byte rather than the read byte).
**And** AC4 — the doc gives clear guidance for the three buffer classes — PAD for one-shot transient, `ALLOTed` named buffers (`B45`, `B46`, …) for buffers that must survive across multiple parses, and never write near HERE.
**And** AC5 — `Makefile`'s test section gains a one-line pointer comment to `tests/README.md` for discoverability (`# See tests/README.md for probe-authoring conventions`).
**And** AC6 — the doc references S12 (word-existence pre-flight + TIB-128 line-length lint) so probe authors find the full discipline in one place; FR-P3-33 / NFR-P3-33 captured.
**And** AC7 (FR-P3-15 verdict-criterion meta-pattern) — a grep of `tests/README.md` for `PAD` returns at least one occurrence in the canonical-buffer section; `Makefile` test section grep returns the pointer comment.
**And** AC8 — `wc -c build/antforth.com` unchanged from the post-Epic-13.5 baseline (24,996 bytes); S9 hardware-smoke documented as exempt (zero binary delta).
**And** AC9 — `make test-repl` reports ≥ 973 PASS / 0 FAIL; zero regressions.

**FRs covered:** FR-P3-11, FR-P3-15. **Carry-forward closed:** B.1.

### Story 14.2: "Mirrors prior arm" HALT-signal lint in story-template

As a story drafter (project lead Ant) authoring a Phase-3+ story,
I want the story-template to surface a HALT signal when my byte-budget rationale leans on "this mirrors arm X from Story Y" shorthand,
So that I count the parts of the new arm independently — preventing the Lesson-13.5-C calibration miss (TD-7 / Story 13.5.5 overshot pick (a) +50..+100 by 40 bytes via this exact shorthand).

**Acceptance Criteria:**

**Given** the v2.0 baseline `instructions.xml` lacks a "mirrors prior arm" lint,
**When** Story 14.2 is dev-passed,
**Then** a new `<critical>` block lands in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (the established PD-1 enforcement-surface file).
**And** AC2 — the block enumerates trigger phrases — "mirrors", "same shape as", "this is the X arm of Story Y", any "Story Y" reference in byte-budget rationale paragraphs (pattern: "Story" + capital-letter or digit + cardinal/ordinal).
**And** AC3 — the block requires the drafter to itemise the new arm's parts independently — listing each component (load, store, branch, return-stack manipulation, etc.) with its byte cost — before the byte-budget rationale is accepted.
**And** AC4 — the block cites Lesson 13.5-C as its motivating lesson and TD-7 / Story 13.5.5 as the concrete prior incident it prevents.
**And** AC5 (FR-P3-15 verdict-criterion meta-pattern) — a synthesised drafting attempt (e.g., "this story's byte budget mirrors arm A from Story 13.5.6") fed into the drafting workflow surfaces the HALT signal at the byte-budget-rationale review step.
**And** AC6 (verdict-criterion grep-able) — `grep -n 'mirrors prior arm' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` returns at least one match (or the equivalent canonical phrase the block uses; verdict tested with explicit phrase list).
**And** AC7 — the structural edit is recorded in the BMAD installer's expected-files list so subsequent installer re-runs preserve it (per CCD-P3-2's installer-manifest discipline).
**And** AC8 — `wc -c build/antforth.com` unchanged; S9 hardware-smoke documented as exempt.
**And** AC9 — `make test-repl` reports ≥ 973 PASS / 0 FAIL.

**FRs covered:** FR-P3-12, FR-P3-15. **NFR codified:** NFR-P3-24 (S3 — real-byte-count estimation, extended by Lesson 13.5-C). **Carry-forward closed:** B.2.

### Story 14.3: Story-to-story binary handoff — re-`wc -c` at dev-pass start

As a story drafter starting a new Phase-3+ dev-pass,
I want the story-template's "Pre-edit baseline" task to require me to re-`wc -c` the actual current build artefact,
So that I don't inherit the prior story's reported binary size — preventing the 6-byte 13.5.5-close-out doc-drift gap that surfaced as Lesson 13.5-F.

**Acceptance Criteria:**

**Given** the v2.0 baseline `template.md`'s "Pre-edit baseline" section lacks a re-`wc -c` task,
**When** Story 14.3 is dev-passed,
**Then** `_bmad/bmm/workflows/4-implementation/create-story/template.md` "Pre-edit baseline" section gains an explicit task: "Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes".
**And** AC2 — the task entry includes the explicit instruction "**Do not** inherit the prior story's reported number — re-`wc -c` from the actual current build artefact (B.3 / Lesson 13.5-F)".
**And** AC3 — the task lands at the top of the "Pre-edit baseline" section (or whichever position the drafter encounters first when filling out the template).
**And** AC4 — the task cites Lesson 13.5-F / Story 13.5.5 close-out as its motivating incident.
**And** AC5 (FR-P3-15 verdict-criterion meta-pattern) — `grep -n 'wc -c' _bmad/bmm/workflows/4-implementation/create-story/template.md` returns at least one match in the Pre-edit baseline section; the line referencing "Do not inherit the prior story's reported number" is grep-able from the same file.
**And** AC6 — the structural edit is recorded in the BMAD installer's expected-files list so subsequent installer re-runs preserve it (per CCD-P3-2's installer-manifest discipline).
**And** AC7 — `wc -c build/antforth.com` unchanged; S9 hardware-smoke documented as exempt.
**And** AC8 — `make test-repl` reports ≥ 973 PASS / 0 FAIL.

**FRs covered:** FR-P3-13, FR-P3-15. **Carry-forward closed:** B.3.

### Story 14.4: PD-2 figure-drift discipline `<critical>` block

As a story drafter quoting figures, tables, or code blocks from a prior story or retrospective,
I want the story-template to require me to validate those artefacts against their source-of-truth at draft time,
So that I don't inherit drift that has accumulated since the original artefact was authored — closing PD-2 (Epic 13 retro #1).

**Acceptance Criteria:**

**Given** the v2.0 baseline `instructions.xml` lacks a figure-drift discipline `<critical>` block,
**When** Story 14.4 is dev-passed,
**Then** a new `<critical>` block lands in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` (sibling of B.2's "mirrors" block from Story 14.2).
**And** AC2 — the block applies to figures, tables, and code blocks; trigger pattern: any quoted/copied artefact from a prior story or retro that the new story relies on for its rationale.
**And** AC3 — the block requires the drafter to validate the artefact against the source-of-truth at draft time (e.g., re-read the cited file:line, re-run the cited command, re-extract the cited table from the cited document) before quoting.
**And** AC4 — the block cites PD-2 (Epic 13 retro #1) as its motivating PD item.
**And** AC5 (FR-P3-15 verdict-criterion meta-pattern) — `grep -n -E '(figure[- ]drift|PD-2)' _bmad/bmm/workflows/4-implementation/create-story/instructions.xml` returns at least one match in the new `<critical>` block.
**And** AC6 — the B.4 block lands adjacent to (immediately before or after) the B.2 "mirrors" block in `instructions.xml` so the discipline cluster is visually grouped — a future drafter encountering one encounters both. (B.2 / B.4 sibling sequencing per architecture's "Recommended sequencing within the lead-in: B.2 + B.4 together".)
**And** AC7 — the structural edit is recorded in the BMAD installer's expected-files list per CCD-P3-2.
**And** AC8 — `wc -c build/antforth.com` unchanged; S9 hardware-smoke documented as exempt.
**And** AC9 — `make test-repl` reports ≥ 973 PASS / 0 FAIL.

**FRs covered:** FR-P3-14, FR-P3-15. **Carry-forward closed:** B.4.

### Story 14.5: PRD↔architecture transcription-drift sync target — `make check-doc-sync`

As a maintainer (project lead Ant) about to apply a Phase-3 antforth 2.x point-release tag,
I want a Makefile target that detects PRD-vs-architecture transcription drift,
So that the docs ship aligned at every tag close-out (S11 sibling) — closing PD-3 (Epic 13 retro #2).

**Acceptance Criteria:**

**Given** the v2.0 baseline lacks a `tools/check-doc-sync/` directory and a `make check-doc-sync` target,
**When** Story 14.5 is dev-passed,
**Then** a new self-contained tool subdirectory exists at `tools/check-doc-sync/` (per `tools/bdos_probe/` precedent — Story 11.5.1.2's firmware reproducer).
**And** AC2 — a project-local Bash script at `tools/check-doc-sync/check-doc-sync.sh` implements the drift checks; tool documentation at `tools/check-doc-sync/README.md` (drift-check rules, exit codes, intended cadence).
**And** AC3 — drift checks implemented (4 categories): (a) every `FR-P3-N` / `NFR-P3-N` reference in `architecture.md` exists as a label in `prd.md` and vice versa; (b) every `Story X.Y` citation in `architecture.md` resolves to an actual story header in the current `epics.md` or its predecessor `epics-phase1-epics-1-8.md` / `epics-phase2-epics-9-13.5.md` if the citation is historical; (c) every `§X.Y.Z` reference in `architecture.md`'s compliance-related sections has a matching row in `docs/ans-forth-core-compliance.md` (post-A.1 invariant — verdict criterion: clean before any tag close-out); (d) section-name parity check — both PRD and architecture share the agreed-on top-level sections.
**And** AC4 — clean-pass produces `[ok] doc-sync: 0 drift` to stdout and exits 0; failure prints one line per drift item to stderr and exits 1.
**And** AC5 — `Makefile` gains a `check-doc-sync` PHONY target invoking the script; target is **advisory-only** on `make test-repl` (does not block test runs); expected clean before any tag-applicable close-out (S11 sibling).
**And** AC6 (FR-P3-15 verdict-criterion meta-pattern) — running `make check-doc-sync` against the current Phase-3 PRD + architecture pair (commit at story start) produces a known-state verdict (clean-pass or a small enumerable drift list); the verdict is documented in the story's Dev Notes.
**And** AC7 — `tools/check-doc-sync/README.md` enumerates the four drift checks (AC3), exit codes, and intended cadence ("run before any antforth 2.x tag close-out; advisory at any other time").
**And** AC8 — `wc -c build/antforth.com` unchanged (Makefile + script edits, no kernel touch); S9 hardware-smoke documented as exempt.
**And** AC9 — `make test-repl` reports ≥ 973 PASS / 0 FAIL.

**FRs covered:** FR-P3-16. **Carry-forward closed:** B.5.


## Epic 15: Phase-3 Standards Close-Out

Complete the §-by-§ ANS Forth Core + Core-Extension audit (the strategic body), close all standards/compliance gaps (A.2 caught-form THROW; A.3 base-aware NUMBER?), and fold in the remaining hitch-hikers (B.6 check-tools; B.7 conditional; B.8 test-numbering hygiene; B.9 disk-full hardware re-verification). Phase-3 close-out tag (final antforth 2.x version) applied at end after the verdict-table walk + S11 user-visible version surface audit.

**User outcomes at epic close-out:**
- Hana the Forth auditor finds `docs/ans-forth-core-compliance.md` with §-level rows for every mandatory rule in DPANS94 §6.1 + §6.2 + structural §-rules; compliance claim becomes checkable rule-by-rule against the standard text in under 10 minutes per row (Journey 5; NFR-P3-13).
- Mo the OG can wrap any asm-error operation in `' WORD CATCH . CR` and receive the asm-error code on the data stack exactly as ANS-standard codes; defensive harnesses around experimental CODE words work without asym (Journey 2).
- Raj the Newb sees unprefixed numerals parse per the explicit BASE consistently; the "wait, why is decimal showing as hex?" gotcha doesn't happen (Journey 3).
- Pete the hardware/peripheral developer finds disk-full / directory-full / zero-byte READ-FILE failure modes documented and FCB-pool-consistent on real CP/M 2.2 (Journey 4).
- Mo (non-regression baseline holder) sees v2.0 behaviour identical; 973 PASS / 0 FAIL maintained or extended; S9 hardware smoke per binary-delta story (Journey 1).
- Contributors find `make check-tools` confirms iz-cpm + sjasmplus versions against the certified baseline.

**FRs covered:** FR-P3-1..10, FR-P3-17, FR-P3-18, FR-P3-19..21, FR-P3-22..25.

**NFRs delivered:** NFR-P3-2 (cumulative ROM cap +200 bytes enforced per-story); NFR-P3-7 / S9 (hardware smoke per binary-delta story); NFR-P3-8 (§-level Core compliance, upgraded from word-counted); NFR-P3-9 (A.3 strict base-aware refinement); NFR-P3-13 (compliance-doc row checkability under 10 minutes); NFR-P3-32 / S11 (version-surface audit at Phase-3 close-out tag). All 33 NFR-P3-N continue to hold.

**Carry-forward items closed at epic close-out:** A.1, A.2, A.3, B.6, B.7 (conditional), B.8, B.9 (7 of 12 P1 items; combined with Epic-14's 5 → 12 of 12 at Phase-3 close-out).

### Story 15.1: ANS Forth Core compliance audit (A.1)

As a Forth implementor verifying antforth's compliance claim,
I want a per-§-rule pass over DPANS94 §6.1 + §6.2 + the structural §-rules,
So that "100% Core" is checkable rule-by-rule rather than word-counted — the framework that caught Stories 13.0 / 13.0.1's §-level blindspots applied systematically.

**Acceptance Criteria:**

**Given** the v2.0 baseline `docs/ans-forth-core-compliance.md` carries word-by-word §6.1 rows + ad-hoc §-level coverage,
**When** Story 15.1 is dev-passed,
**Then** AC1 — every mandatory rule in DPANS94 §6.1 (Core, ~133 rules) and every implemented word in §6.2 (Core Extension) has a row in `docs/ans-forth-core-compliance.md` with verdict: `Implemented` / `Implemented-with-caveat` / `Deliberately-omitted` / `Accepted-with-rationale-N-A`.
**And** AC2 — known structural §-rules (§3.1.4.1 high-on-TOS double-cell layout, §3.4.1.3 numeric-literal parser rule) are covered as rows; any other structural §-rules surfaced during the walk are added.
**And** AC3 — every gap (`Implemented-with-caveat` or surfaced-but-not-yet-implemented) is either spawned as a back-fill story (15.1.X) or carries a one-sentence rationale in Notes. No silent gaps.
**And** AC4 — `wc -c build/antforth.com` unchanged (audit story is doc-only); `make test-repl` reports ≥ 973 PASS / 0 FAIL.
**And** AC5 — `docs/PHASE-3-CARRY-FORWARD.md` A.1 row updated at story close-out with verdict summary and back-fill spawn list.

**FRs covered:** FR-P3-1, FR-P3-2, FR-P3-3, FR-P3-4. **Carry-forward (partial):** A.1 audit-walk component closed; back-fill closures via 15.1.X if surfaced.

### Story 15.1.X: A.1 back-fill — gap N (CONDITIONAL; 0–2 expected, spawned from Story 15.1's verdict)

Each back-fill story conditionally exists if Story 15.1 surfaces a §-level structural-rule gap that warrants implementation rather than accepted-with-rationale. Each follows the A.1-D3 six-step canonical shape; the actual title and AC body depend on the specific §-rule being back-filled. Story file naming: `_bmad-output/implementation-artifacts/phase3-a1-§<rule>-<slug>.md`.

As a Forth user expecting full DPANS94 / Forth 2014 §-level compliance,
I want the §-level structural-rule gap N (surfaced by Story 15.1's audit) closed,
So that antforth's compliance claim is §-level defensible at this rule, not just word-counted around it.

**Acceptance Criteria (canonical A.1-D3 six-step shape):**

**Given** Story 15.1's audit surfaced gap N as a §-level structural-rule gap requiring implementation,
**When** Story 15.1.X is dev-passed,
**Then** AC1 — the §-rule is implemented in the appropriate `src/*.asm` (or `tests/*.fth` for test-only closures) at a specific `cf:` label.
**And** AC2 (CCD-3 standards-citation comment) — the affected DEFCODE carries `; ANS Forth 1994 §<sec>` / `; Forth 2014 §<sec>` / `; antforth extension`.
**And** AC3 — a new row in `docs/ans-forth-core-compliance.md` per CCD-P3-1 6-column schema; story-number references this back-fill story.
**And** AC4 — REPL probes (positive path + at least one edge case) added in the appropriate `tests/*.fth` harness.
**And** AC5 (S9) — hardware smoke runs on real CP/M 2.2 / MicroBeast — PASS verdict; transcript filed.
**And** AC6 (pre-fix negative-result confirmation) — pre-fix binary fails the new probe (build pre-fix HEAD, run new probe, capture failure); post-fix binary passes; diff captured in Dev Notes.
**And** AC7 — ROM delta within +0..+50 bytes (Story 13.0 / 13.0.1 / 13.5 precedent); HALT signal if outside envelope.
**And** AC8 — `make test-repl` reports ≥ 973 PASS / 0 FAIL.
**And** AC9 — `docs/PHASE-3-CARRY-FORWARD.md` A.1 row's closure note appended with the gap-N back-fill summary.

**FRs covered:** FR-P3-5, FR-P3-6 (one row per back-fill closure).

### Direct-commit work items (no story file)

Per the Epic 14 retrospective (2026-05-09): items below are tracked in `docs/PHASE-3-CARRY-FORWARD.md` and committed directly without create-story ceremony. Each lands as one or more focused commits with a meaningful message; verdict criterion is the test/probe passing on real CP/M 2.2 / MicroBeast where applicable.

**A.2 — caught-form THROW coverage (FR-P3-7, FR-P3-8).** Add 15 `' WORD CATCH . CR` probes to `tests/throw_migration_tests.fth`, one per asm-error code in the −258..−272 block. Each probe asserts the expected code lands on the data stack. Unique numeric IDs across the existing `test-repl` recipe. Run `make test-repl` green. Commit.

**A.3 — base-aware unprefixed `NUMBER?` (FR-P3-9, FR-P3-10).** In `src/strings.asm:w_NUMBER_Q_cf`, fix the unprefixed-numeral parsing branch so it honours the current `BASE` (DPANS94 §6.1.0570 + Forth 2014 §3.4.1.3 prefixed literals continue to ignore `BASE` per FR9). Add positive probes (HEX `FF .` → 255; DECIMAL `255 .` → 255; `8 BASE !` then `17 .` → 15) and a regression probe (HEX `#100 .` → 100). Add `; ANS Forth 1994 §6.1.0570 NUMBER? — BASE-aware unprefixed parse` citation on the affected `cf:` label. Update `docs/ans-forth-core-compliance.md` row for §6.1.0570. ROM delta ≤ +30 bytes; if delta > 0, hardware smoke required.

**B.6 (`make check-tools`) and B.8 (test-numbering hygiene) — dropped from Phase 3 scope.** Both are tooling-on-tooling; if iz-cpm version drift or duplicate test IDs ever bite, fix them then. `docs/PHASE-3-CARRY-FORWARD.md` rows updated to "Deferred indefinitely — Epic 14 retro 2026-05-09."

### Story 15.5: Filesystem stress hardware sprint — disk-full + directory-full + zero-byte READ-FILE (B.7 + B.9)

As Pete the hardware/peripheral developer (Journey 4),
I want disk-full / directory-full / zero-byte READ-FILE failure modes verified clean on real CP/M 2.2 / MicroBeast hardware,
So that documented failure-mode behaviour is hardware-real, not just iz-cpm-real.

**Acceptance Criteria:**

**Given** the v2.0 baseline lacks dedicated probe coverage for disk-full, directory-full, and zero-byte READ-FILE failure modes,
**When** Story 15.5 is dev-passed,
**Then** AC1 (B.9 disk-full) — fill B: ramdisk to capacity with one large file written until `WRITE-FILE` returns disk-full `ior`. Asserts non-zero `ior`, no orphaned FCB handles, and a clean `CLOSE-FILE` / re-`OPEN-FILE` round-trip on an existing file post-failure.
**And** AC2 (F2 directory-full) — fill B: directory entries with many small files until `CREATE-FILE` returns directory-full `ior`. Same consistency assertions as AC1. Distinct failure mode (directory-entry exhaustion vs block-storage exhaustion).
**And** AC3 (zero-byte READ-FILE) — `( c-addr 0 fileid -- 0 0 )` no-op path returns `0 0` with no FCB-pool or filesystem state mutation.
**And** AC4 — probes added to `tests/file_access_tests.fth`; transcript captured on real hardware under `~/Downloads/bestialitty-<date>.bin`.
**And** AC5 (B.7 fork) — if hardware reveals a defect (wrong `ior`, orphaned FCB, directory corruption, FCB-pool recovery failure), Story 15.5.1 is spawned per `feedback_verdict_only_audit.md`. Otherwise B.7 closes "evaluation suffices."
**And** AC6 — `make test-repl` ≥ baseline + new probes / 0 FAIL; binary delta typically 0 (probe-only).

**FRs covered:** FR-P3-19, FR-P3-20, FR-P3-21. **Carry-forward closed:** B.9; B.7 (disposition (a) or spawns Story 15.5.1).

### Story 15.5.1: B.7 conditional probe story (CONDITIONAL — only if Story 15.5 reveals a defect)

Spawned only if Story 15.5's hardware run surfaces a kernel defect requiring surgery. Follows `feedback_verdict_only_audit.md` shape: verdict-only audit (the 15.5 transcript) + standalone reproducer + fix.

**Acceptance Criteria (canonical template):**

**Given** Story 15.5's hardware run surfaced a specific defect,
**When** Story 15.5.1 is dev-passed,
**Then** AC1 — standalone Forth reproducer exhibits the defect on real hardware.
**And** AC2 — fix implemented in the appropriate `src/*.asm`; pre-fix binary fails reproducer, post-fix passes; diff captured.
**And** AC3 — probe added permanently to `tests/file_access_tests.fth`.
**And** AC4 — hardware smoke runs on real CP/M 2.2 / MicroBeast — PASS; transcript filed.
**And** AC5 — binary delta ≤ +30 bytes; `make test-repl` ≥ baseline + probes / 0 FAIL.

**FRs covered (conditionally):** FR-P3-19, FR-P3-20.

### Phase-3 close-out (replaces Story 15.6 — checklist, no story file)

When Story 15.1 (and any 15.1.X back-fills) + the A.2 / A.3 direct-commit items + Story 15.5 (and 15.5.1 if spawned) are all landed, close Phase 3 with this checklist as one commit:

- `make test-repl` green; `wc -c build/antforth.com` recorded.
- If binary moved from 24,996, run hardware smoke on real CP/M 2.2 / MicroBeast; file transcript.
- Bump banner string in `src/antforth.asm` and `README.md` version reference if shipping a 2.x point release.
- Run `make check-doc-sync`; resolve any strict drift items.
- Tag the close-out commit; publish GitHub release.
- Mark `docs/PHASE-3-CARRY-FORWARD.md` P1 rows `✅ Done` (B.6 / B.8 → `❌ Deferred indefinitely` per Epic 14 retro decision).
- Run a Phase-3 retrospective.

### REMOVED: Story 15.2, Story 15.3, Story 15.4, Story 15.6 (per Epic 14 retro 2026-05-09)

Removed from story scope per Epic 14 retrospective scope-tightening:
- **15.2 (caught-form THROW probes)** — demoted to direct-commit work item (above).
- **15.3 (base-aware NUMBER?)** — demoted to direct-commit work item (above).
- **15.4 (B.6 + B.8 Makefile tooling sprint)** — dropped entirely (tooling-on-tooling cargo).
- **15.6 (close-out gate)** — replaced by the checklist above (no story file).

