---
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-04-14.md
archivedDocuments:
  - _bmad-output/planning-artifacts/prd-phase1-epics-1-8.md
  - _bmad-output/planning-artifacts/architecture-phase1-epics-1-8.md
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-03-11.md
  - _bmad-output/planning-artifacts/implementation-readiness-report-2026-03-12.md
workflowType: 'implementation-readiness'
date: '2026-04-14'
---

# Implementation Readiness Assessment Report

**Date:** 2026-04-14
**Project:** antforth (phase 2 / antforth 2.0)

## Document Discovery

### PRD Documents

**Whole Documents:**
- `prd.md` (49,851 bytes) — **current phase, in scope for this assessment**
- `prd-phase1-epics-1-8.md` (24,186 bytes) — archived, reference only

**Sharded Documents:** none

### Architecture Documents

**Whole Documents:**
- `architecture.md` (69,592 bytes) — **current phase, in scope for this assessment**
- `architecture-phase1-epics-1-8.md` (33,457 bytes) — archived, reference only; cited by phase-2 architecture as canonical for inherited subsystems

**Sharded Documents:** none

### Epics & Stories Documents

**Whole Documents:**
- `epics.md` (69,523 bytes) — **primary epic breakdown document**, covers Epics 1–8. Phase-2 Epics 9–13 are **not yet authored in this file** — this is an expected gap (epics/stories step is the NEXT workflow).
- `epic6-code-size-optimization.md` — detail doc for a shipped epic
- `epic7-shadow-register-optimization.md` — detail doc for a shipped epic
- `epic8-shadow-register-followup.md` — detail doc for a shipped epic

**Sharded Documents:** none

### UX Design Documents

**None found** — **N/A for this project.** antforth is a CLI / REPL-only tool with no UI surface. This is a known and accepted gap, not a deficiency.

### Other Relevant Artefacts Present

- `product-brief-antforth-2026-04-14.md` — current phase brief (input to PRD)
- `sprint-change-proposal-2026-04-12.md` — Epic 4.3.5 refactor (shipped, reference only)
- `implementation-readiness-report-2026-03-12.md` — prior phase readiness report (archive)

### Issues Identified

- **No duplicate document format issues** — archived files carry phase-1 suffix; no ambiguity between current and archived.
- **UX design missing** — N/A for CLI/REPL project (accepted).
- **Phase-2 epics/stories not yet in `epics.md`** — expected gap; will be addressed by the next workflow (`create-epics-and-stories`). This affects the depth of assessment possible in Steps 3 and 4 below — they will assess readiness of the PRD and architecture *to drive* epic/story creation, rather than assessing existing phase-2 stories (which don't exist yet).

### Assessment Scope Note

For this phase-2 readiness check, the core documents under assessment are:

- **`prd.md`** (2026-04-14, complete, 12 steps) — single source of truth for phase-2 requirements
- **`architecture.md`** (2026-04-14, complete, 8 steps, all 4 findings resolved) — single source of truth for phase-2 design decisions
- **`epics.md`** — will be evaluated for Epics 1–8 rigour as a template; phase-2 epic content doesn't exist yet

All phase-2-relevant documents are present, unambiguous, and ready for assessment.

## PRD Analysis

The PRD (`prd.md`, 2026-04-14) specifies **52 Functional Requirements** organised into 7 capability areas and **23 Non-Functional Requirements** across 5 categories. Rather than duplicate the full text of each (the PRD is ~50 KB and its numbering is stable), this analysis extracts the requirement inventory by ID with one-line summaries, for use in subsequent coverage validation.

### Functional Requirements

**Numeric Literal Input (Epic 9) — FR1 through FR9:**

- FR1: `#` decimal prefix
- FR2: `$` hex prefix
- FR3: `%` binary prefix
- FR4: `'c'` character literal
- FR5: `0x` hex prefix (antforth extension)
- FR6: optional leading `-` on all prefixed forms
- FR7: case-insensitive prefixes and hex digits
- FR8: recognisers active in REPL, colon definitions, and built-in assembler source
- FR9: BASE not mutated by parsing

**Core Arithmetic & Numeric Output (Epic 10) — FR10 through FR15:**

- FR10: ANS Core double-precision arithmetic word set (`D+`, `D-`, `D*`, `DNEGATE`, `DABS`, `D<`, `D=`, `DMAX`, `DMIN`, `M*`, `UM*`, `M+`, `SM/REM`, `FM/MOD`, `UM/MOD`)
- FR11: Double-cell stack operations (`2@`, `2!`, `2DUP`, `2DROP`, `2SWAP`, `2OVER`)
- FR12: Single/double conversions (`>D`, `S>D`, `D>S`)
- FR13: Pictured numeric output (`<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`, `HOLDS`)
- FR14: Display words (`.`, `U.`, `D.`, `.R`, `U.R`, `D.R`) on top of pictured output
- FR15: 100% ANS Forth 1994 Core wordset compliance

**Exception Handling (Epic 11) — FR16 through FR22:**

- FR16: `CATCH` frame + THROW code result
- FR17: `THROW` with arbitrary non-zero code
- FR18: ANS standard THROW codes honoured
- FR19: All internal error paths route through THROW
- FR20: `ABORT` = `-1 THROW`, `ABORT"` = `-2 THROW`
- FR21: Uncaught THROW returns to REPL with diagnostic (code + description)
- FR22: REPL survives any THROW; session/dictionary preserved

**Vocabulary & Namespace Management (Epic 12) — FR23 through FR31:**

- FR23: `WORDLIST` creates new wordlist, returns wid
- FR24: `GET-ORDER`, `SET-ORDER`
- FR25: `GET-CURRENT`, `SET-CURRENT`
- FR26: `DEFINITIONS`
- FR27: `ONLY`
- FR28: `FORTH-WORDLIST`
- FR29: `SEARCH-WORDLIST`
- FR30: `ASSEMBLER` auto-activates inside `CODE`/`END-CODE`
- FR31: Pre-phase CODE-word source files assemble unchanged

**Source File I/O (Epic 13) — FR32 through FR44:**

- FR32: `INCLUDE <filename>`
- FR33: `INCLUDE-FILE`
- FR34: `INCLUDED`
- FR35: `OPEN-FILE` with access mode
- FR36: `CREATE-FILE` with access mode
- FR37: `DELETE-FILE`
- FR38: `READ-FILE`
- FR39: `WRITE-FILE`
- FR40: `FILE-POSITION`, `REPOSITION-FILE`
- FR41: `FILE-SIZE`
- FR42: `CLOSE-FILE`
- FR43: File errors raise THROW, not ABORT
- FR44: Source files load from A: or B: with no syntactic distinction

**System Extensibility & Self-Hosting (Epic 13 capstone) — FR45 through FR49:**

- FR45: Fresh boot has empty `ASSEMBLER` wordlist
- FR46: First `CODE` auto-loads `ASSEMBLER.FTH` from resolved path
- FR46a: Path resolution — `ASSEMBLER-PATH` if non-sentinel, else current drive + `ASSEMBLER.FTH`
- FR46b: `ASSEMBLER-PATH` user-settable
- FR47: Lazy load is transparent — same CODE semantics as baked-in
- FR48: Subsequent `CODE` calls in session do no additional loading
- FR49: Load failure raises THROW with path in diagnostic

**Backward Compatibility & Regression (phase-wide) — FR50 through FR52:**

- FR50: All Epic 1–8 functional behaviour preserved
- FR51: All existing REPL-piped test scripts pass against 2.0
- FR52: Unprefixed `<BASEnum>` continues to parse per BASE

**Total FRs: 52** (note: FR46a and FR46b are sub-FRs of FR46 as originally written; counted as 3 distinct acceptance criteria)

### Non-Functional Requirements

**Performance — NFR1 through NFR6:**

- NFR1: Prefix parse overhead ≤ ~20 Z80 cycles over unprefixed path
- NFR2: Multi-vocab lookup regression ≤ 10% vs single-vocab baseline
- NFR3: First-CODE lazy-load ≤ 3 seconds (revised from 1 s per Finding 3 resolution)
- NFR4: CATCH frame overhead ≤ ~15 cycles uncaught path
- NFR5: Kernel ROM strictly smaller than pre-phase baseline
- NFR6: Double-precision primitives within ~20% of hand-rolled Z80 equivalents

**Reliability — NFR7 through NFR10:**

- NFR7: REPL survives any THROW
- NFR8: State integrity after error (no corrupted structures)
- NFR9: Filesystem error recovery (no orphan handles, no partial writes)
- NFR10: Epic 1–8 regression suite passes on every 2.0 candidate

**Compatibility & Standards — NFR11 through NFR15:**

- NFR11: 100% ANS Forth 1994 Core compliance
- NFR12: Forth 2014 §3.4.1.3 numeric literal prefix conformance
- NFR13: Extensions (only `0x`) flagged explicitly
- NFR14: CP/M 2.2 BDOS function allow-list (1, 2, 6, 9, 10–21, 25, 26–27, 33–36, 40)
- NFR15: Existing CODE-word source files byte-identical output under 2.0

**Maintainability — NFR16 through NFR19:**

- NFR16: Readability over micro-optimisation (except where explicitly perf-focused)
- NFR17: REPL-piped Forth test coverage for every new word
- NFR18: Standards-citation comments on every standard-derived word
- NFR19: Each epic independently shippable as antforth 1.x

**Integration — NFR20 through NFR23:**

- NFR20: Terminal I/O portability (char-based BDOS only; no ANSI)
- NFR21: CP/M 8.3 filename convention; no wildcards, no Unix paths
- NFR22: `ASSEMBLER-PATH` variable with current-drive sentinel default
- NFR23: No MicroBeast hardware dependencies in kernel or ASSEMBLER wordlist

**Total NFRs: 23**

### Additional Requirements & Constraints

- **Phase-wide acceptance criterion:** The north-star demo passes end-to-end — assembler opcodes absent from fresh-boot dictionary, first `CODE` transparently loads `ASSEMBLER.FTH`, subsequent CODE-word definitions assemble identically to pre-phase behaviour.
- **Release-versioning commitment:** Epics 9–12 ship as `antforth 1.x` increments; Epic 13 completion tags `antforth 2.0`.
- **Hardware-validation gate:** No release tag without a pass on real MicroBeast hardware (not just emulator).
- **Documentation deferral:** All user-facing documentation (beginner's guide, per-wordset reference) deferred post-2.0 per explicit project decision.

### PRD Completeness Assessment

**Strengths:**

- Every FR is tagged with its delivering epic — full traceability from requirement to scope
- Every NFR sits in a clear category with measurable thresholds (cycles, bytes, percentages, seconds)
- Backward-compatibility constraints are explicit FRs, not afterthoughts
- Out-of-scope list is explicit with rationale; scope boundaries are clean
- North-star demo is a single unambiguous acceptance test
- Numbering is stable; no orphan requirements; no vague language like "fast" or "user-friendly"

**Potential gaps surfaced during extraction:**

- None material. FR46/FR46a/FR46b is a three-part requirement; some readers may prefer them renumbered as FR46/FR47/FR48 with the rest shifting, but the current ID scheme is clear and traceable.
- NFR3 was recently revised (1 s → 3 s); the revision note is present in the PRD body.

**Readiness for epic breakdown:** The PRD is ready. Epic 9–13 authoring can proceed with the FR list as the story-level acceptance criteria target, one-to-several mapping (one FR may produce multiple stories; one story typically satisfies one or two FRs).

## Epic Coverage Validation

### Assessment Context

**Phase-2 epics (9–13) have not yet been authored as story-level breakdowns in `epics.md` — that is the next workflow in sequence.** This step's validation therefore checks a different, more forward-looking question: **does the PRD + architecture together provide unambiguous coverage planning, such that subsequent story authoring can deliver 100% of the requirement surface?**

Both documents answer this affirmatively:

- **PRD** tags every FR with its delivering epic (§ Functional Requirements, subsection headings name the epic)
- **Architecture** confirms the mapping in three independent places:
  - "Decision Impact Analysis → Implementation sequence" (§ Core Architectural Decisions)
  - "Epic-to-file mapping (phase-2 additions)" (§ Project Structure)
  - "Key capabilities by Epic" (§ MVP Feature Set, in PRD scoping)

These three views agree. The coverage map below is the consolidated view.

### Planning-Level FR Coverage Matrix

| FR ID | Requirement (summary) | Delivering Epic | Architectural Decisions |
|---|---|---|---|
| FR1–FR9 | Numeric literal prefixes (`#`, `$`, `%`, `0x`, `'c'`), case-insensitive, no BASE mutation | **Epic 9** | E9-D1, E9-D2 |
| FR10 | Double-precision arithmetic word set | Epic 10 | E10-D1, E10-D3 |
| FR11 | Double-cell stack operations | Epic 10 | E10-D1 |
| FR12 | Single/double conversions | Epic 10 | E10-D1 |
| FR13 | Pictured numeric output | Epic 10 | E10-D2 |
| FR14 | Display words on pictured output | Epic 10 | E10-D2, E10-D3 |
| FR15 | 100% ANS Core compliance | Epic 10 | NFR11, CCD-4 gate |
| FR16 | `CATCH` frame + THROW result | **Epic 11** | E11-D1, E11-D2 |
| FR17 | `THROW` with arbitrary code | Epic 11 | E11-D2, CCD-2 |
| FR18 | ANS standard THROW codes | Epic 11 | CCD-2 |
| FR19 | All internal error paths via THROW | Epic 11 | E11-D3 |
| FR20 | `ABORT`/`ABORT"` as THROW wrappers | Epic 11 | E11-D3 |
| FR21 | Uncaught THROW diagnostic | Epic 11 | E11-D2 |
| FR22 | REPL survives THROW | Epic 11 | E11-D2, NFR7 |
| FR23 | `WORDLIST` creation | **Epic 12** | E12-D1, E12-D3 |
| FR24 | `GET-ORDER`/`SET-ORDER` | Epic 12 | E12-D2 |
| FR25 | `GET-CURRENT`/`SET-CURRENT` | Epic 12 | E12-D2 |
| FR26 | `DEFINITIONS` | Epic 12 | E12-D2 |
| FR27 | `ONLY` | Epic 12 | E12-D2 |
| FR28 | `FORTH-WORDLIST` | Epic 12 | E12-D1 |
| FR29 | `SEARCH-WORDLIST` | Epic 12 | E12-D1 |
| FR30 | `ASSEMBLER` auto-activation in CODE | Epic 12 | E12-D4 |
| FR31 | Pre-phase CODE source assembles unchanged | Epic 12 | E12-D4, NFR15 |
| FR32 | `INCLUDE <filename>` | **Epic 13** | E13-D2, E13-D3 |
| FR33 | `INCLUDE-FILE` | Epic 13 | E13-D3 |
| FR34 | `INCLUDED` | Epic 13 | E13-D3 |
| FR35 | `OPEN-FILE` | Epic 13 | E13-D1, E13-D3 |
| FR36 | `CREATE-FILE` | Epic 13 | E13-D1, E13-D3 |
| FR37 | `DELETE-FILE` | Epic 13 | E13-D3 |
| FR38 | `READ-FILE` | Epic 13 | E13-D3 |
| FR39 | `WRITE-FILE` | Epic 13 | E13-D3 |
| FR40 | `FILE-POSITION`/`REPOSITION-FILE` | Epic 13 | E13-D3 |
| FR41 | `FILE-SIZE` | Epic 13 | E13-D3 |
| FR42 | `CLOSE-FILE` | Epic 13 | E13-D1 |
| FR43 | File errors raise THROW | Epic 13 | E13-D3, CCD-2 |
| FR44 | Source load from A: or B: | Epic 13 | E13-D3 |
| FR45 | Empty ASSEMBLER wordlist at boot | Epic 13 capstone | E13-D5 |
| FR46 | First `CODE` auto-loads ASSEMBLER.FTH | Epic 13 capstone | E13-D5 |
| FR46a | Path resolution via ASSEMBLER-PATH + current drive | Epic 13 capstone | E13-D4, E13-D5 |
| FR46b | User can set ASSEMBLER-PATH | Epic 13 capstone | E13-D4 |
| FR47 | Lazy load is transparent | Epic 13 capstone | E13-D5 |
| FR48 | Subsequent CODE calls skip load | Epic 13 capstone | E13-D5 |
| FR49 | Load failure raises THROW | Epic 13 capstone | E13-D5, CCD-2 |
| FR50 | All Epic 1–8 behaviour preserved | phase-wide | NFR10 |
| FR51 | Epic 1–8 test suite passes | phase-wide | NFR10, CCD-4 |
| FR52 | Unprefixed numeric literal unchanged | Epic 9 constraint | E9-D1 |

### Missing Requirements

**None.** Every PRD FR (all 52) has:
1. An explicitly named delivering epic in the PRD body
2. At least one architectural decision that specifies how it will be realised
3. A concrete source-file destination in the architecture's Epic-to-file mapping table

### Coverage Statistics

| Metric | Count | Notes |
|---|---|---|
| Total PRD FRs | 52 | (counting FR46a and FR46b as distinct ACs of FR46) |
| FRs with assigned epic | 52 | 100% |
| FRs with architectural decision(s) supporting implementation | 52 | 100% |
| FRs currently authored as stories in `epics.md` | **0** | Phase-2 stories not yet written (expected) |
| Planning-level coverage | **100%** | |
| Story-level coverage | **0%, expected** | Drives next workflow (`create-epics-and-stories`) |

### Coverage Statistics — NFRs (out of scope for this step but noted)

All 23 NFRs are tagged to architectural mechanisms in `architecture.md` (§ Architecture Validation → Requirements Coverage Validation). No orphan NFRs.

### Coverage Validation Verdict

**Planning-level coverage is complete.** No FR is missing a delivering epic or architectural support. The `create-epics-and-stories` workflow can proceed with full confidence that every requirement has a home.

**Story-level authoring is pending** — this is an expected state for a phase where PRD and architecture are newly completed but story breakdown has not yet run. Flagging it here is for report honesty, not a defect.

### Auto-Proceeding

Epic coverage validation complete at planning level. Loading next step for UX alignment check.

## UX Alignment Assessment

### UX Document Status

**Not Found — N/A.**

### Is UX Implied?

**No.** antforth is a command-line / REPL-only programming language interpreter for CP/M. It is interacted with exclusively through text — keyboard input, character output to the CP/M console. Specifically:

- **No web or mobile UI** — the project runs on an 8-bit Z80 retrocomputer under CP/M 2.2
- **No graphical output** — CP/M 2.2 consoles are character-based; antforth does not assume ANSI, colour, or cursor addressing (NFR20)
- **MicroBeast 14-segment LED display** is the only "display" hardware — but access to it is **explicitly out of scope** for phase 2 (NFR23, deferred to the post-2.0 MicroBeast hardware vocabulary epic)
- **The user journeys documented in the PRD** (Journeys 1–4) are all text-at-the-REPL interactions with no visual component

### Alignment Issues

**None.** The PRD's § User Journeys explicitly addresses the absence of UI surface under "Scope Note on User Types," which states: "antforth is a single-user interactive REPL running on personal retrocomputer hardware. There is no network surface, no multi-tenant model, no authentication, and no API layer. The traditional PRD categories of admin, support, moderator, and API consumer do not apply." The architecture document also contains no UX-relevant decisions — appropriate for the project type.

### Warnings

**None.** The absence of UX documentation is correct and intentional for this project type (`developer_tool_embedded`, `general` domain, CLI-only interaction). Flagging the absence as a warning would be a false positive.

### Auto-Proceeding

UX alignment assessment complete. Loading next step for epic quality review.

## Epic Quality Review

### Assessment Context

Phase-2 epic/story content is not yet authored in `epics.md` (the next workflow's job). This review applies the best-practice standards to two proxies:

1. **Phase-2 epic descriptions as they appear in PRD § MVP Scope and architecture § Core Architectural Decisions** — checking whether those descriptions satisfy the best-practice tests well enough to guide subsequent story authoring without structural defects
2. **Phase-1 epics in `epics.md`** — as a template, to confirm that the next workflow will inherit a healthy pattern from shipped work

### Part 1 — Phase-2 Epic Descriptions (prospective review)

#### Epic 9 — Numeric Literal Prefixes

- **User-value focus:** ✅ Clear. Users type `0xFF`, `$FF`, `%1010` directly rather than toggling BASE. This matches Journey 3 (Raj's first hour) verbatim.
- **Epic title:** user-centric phrasing is already used in PRD.
- **Independence:** ✅ Zero dependencies on Epics 10–13. Sole dependency is on existing outer-interpreter parse path.
- **Sizing indicators:** PRD + architecture identify **one new source file** (`src/number_prefixes.asm`), **one existing file edited** (`outer_interpreter.asm`), and **9 FRs**. Plausibly 2–4 stories.
- **Dependency health:** No forward references. Integration point (E9-D1) is a single well-defined helper-word extension.
- **Red flags:** None.

#### Epic 10 — ANS Core Compliance to 100%

- **User-value focus:** ⚠️ **Borderline — the epic title names the metric, not the user outcome.** Users benefit from *using double-precision arithmetic* and *formatted output*; "compliance to 100%" is how we measure those benefits. Recommend the next workflow re-title this as something like **"Epic 10 — Double-Precision Arithmetic & Numeric Formatting"** with the 100% target framed as the epic's completion criterion rather than its purpose.
- **Independence:** ✅ Depends only on existing kernel conventions.
- **Sizing indicators:** Two new source files (`double.asm`, `pictured.asm`), three existing files edited, **six FRs**. Larger than Epic 9 — possibly 4–6 stories (one per arithmetic group, one for pictured-output words, one for display-word reimplementation, one for Core-gap cleanup).
- **Dependency health:** No forward references. Double-precision primitives are prerequisite for pictured output (E10-D2), which is prerequisite for display words (E10-D3) — within-epic ordering.
- **Red flags:** Risk of "implement all remaining Core gap words" ballooning in scope. The PRD names the specific words for double and pictured output; the residual "all remaining Core gap words" is enumerated by `docs/ans-forth-core-compliance.md` but the actual list isn't inline in the PRD. The next workflow must enumerate this list in the Epic 10 story structure — a story-authoring concern, not an epic-description concern.

#### Epic 11 — Exception Wordset (CATCH/THROW)

- **User-value focus:** ✅ Clear. Users catch errors in their own code (Journey 2 — Mo catching a bug); REPL survives errors without losing session state.
- **Independence:** ✅ Depends only on existing Forth machinery.
- **Sizing indicators:** One new source file (`exception.asm`), **one new doc** (`docs/throw-codes.md`), **seven FRs**, plus a **cross-cutting internal error migration** touching every existing `*.asm` file with ABORT paths. Hard to pre-size — phased word-by-word migration (E11-D3) is the right shape, but the number of ABORT sites across the kernel isn't enumerated anywhere yet.
- **Dependency health:** No forward references. Precedes Epics 12–13 (both consume CATCH/THROW).
- **Red flags:** **ABORT-site enumeration is missing.** The architecture says "every internal error path migrates" without giving a count. If there are 10 ABORT sites the epic is one sprint; if there are 60 it's three. The next workflow's Epic 11 first story should be **"Survey and enumerate every existing ABORT call site, produce a migration checklist,"** making subsequent per-primitive migration stories well-sized and trackable.

#### Epic 12 — Search-Order Wordset

- **User-value focus:** ✅ Users organise their words into named vocabularies; ASSEMBLER opcodes auto-activate inside CODE (Journey 1, 4).
- **Independence:** ✅ Depends only on existing dictionary + hash machinery, which it generalises.
- **Sizing indicators:** One new source file (`wordlists.asm`), **one new Forth source file** (`examples/ASSEMBLER.FTH` — meaningful work), three existing files edited, **nine FRs**.
- **Dependency health:** ✅ No forward refs. E12-D1 (hash layout) + E12-D4 (ASSEMBLER auto-activation) are prerequisites for Epic 13's lazy-load story.
- **Red flags:** **The `ASSEMBLER.FTH` authorship story is one of the hardest tasks in the whole phase** — it's not a routine "write some Forth" — it's migrating ~168 opcodes from highly-optimised Z80 assembly into Forth source, staying within the 8 KB soft budget (Finding 3), preserving existing CODE-word source file compatibility (FR31). PRD and architecture flag this but it's worth emphasising during story authoring: **this story probably needs its own sub-breakdown** (e.g., "authoring framework + test harness first, then opcode-family-by-opcode-family migration").

#### Epic 13 — File-Access Wordset (culminating in antforth 2.0)

- **User-value focus:** ✅ Strongest user value of the phase — on-device source development (Journeys 1, 2, 4) + the north-star demo.
- **Independence:** ⚠️ **Depends on Epic 11 (for THROW-based file error handling, FR43) and Epic 12 (for ASSEMBLER wordlist, E13-D5).** These are *sequencing* dependencies (Epic 13 cannot ship meaningfully before them), not *forward* dependencies in the forbidden sense. Epic 13 as written references only work that must *already* be done — so when the epic itself starts, all prereqs exist. ✅ Valid under the best-practice rule "Epic N cannot require Epic N+1."
- **Sizing indicators:** Two new source files (`file_access.asm`, `lazy_load.asm`), two existing files edited, **13 FRs** in the file-access wordset + **5 FRs** in the capstone = 18 FRs — the largest epic by FR count. 6–10 stories likely.
- **Dependency health:** Within-epic ordering is clear: basic file primitives → INCLUDE → save/load workflow → **capstone**. The capstone must be last.
- **Red flags:** **CP/M 128-byte record-to-byte impedance** (E13-D3) is a notorious source of Forth-on-CP/M bugs (off-by-one at record boundaries, EOF detection). The architecture allocates "a dedicated file I/O sanity story at the start of Epic 13 before implementing INCLUDE" — this is explicit mitigation, good. Story authoring must preserve it. **Second concern:** the capstone story's acceptance test is the north-star demo; that test requires a *real working ASSEMBLER.FTH* (from Epic 12). If Epic 12's `ASSEMBLER.FTH` is still being iterated when the capstone story starts, validation is blocked. The next workflow should explicitly gate the capstone story on Epic 12's full completion, not just "Epic 12 mostly done."

### Part 2 — Phase-1 Epics as Template (retrospective review of `epics.md`)

Spot-checked the phase-1 epic structure in `epics.md` as a template for the next workflow to follow:

- **Epic titles** are user-value phrased (e.g., "Execution Engine," "Interactive REPL," "Language Extension," "System Maturity & Compliance"). ✅ Good template.
- **Stories within epics** use numbered `Story N.M: Title` with acceptance criteria in Given/When/Then format. ✅ Good template.
- **Dependencies** are stated explicitly in each story; forward dependencies are not seen (mid-course corrections like the 4.3.5 stack-tag refactor were handled via the `sprint-change-proposal` workflow, not by retroactively editing the original epic to reference future work). ✅ Good template — this discipline should continue.
- **Retrospectives** are present for completed epics (e.g., "retro 8" commit; `epic6/7/8-*.md` detail documents). ✅ Good pattern; the next workflow should set up retrospective slots for Epics 9–13 accordingly.

### Findings — Prospective Concerns for Story Authoring

These are not defects in the PRD or architecture; they are flags for the next workflow (`create-epics-and-stories`) to address during story breakdown.

#### 🟡 Minor: Epic 10 title is metric-focused

**Issue:** "ANS Core Compliance to 100%" names the measurement, not the user outcome.
**Recommendation:** When the next workflow authors Epic 10, re-title as "Double-Precision Arithmetic & Numeric Formatting (Core to 100%)" or similar. 100% becomes the DoD metric, not the epic's identity.
**Severity:** cosmetic; does not block authoring.

#### 🟠 Important: Epic 10 residual Core-gap word list is by-reference only

**Issue:** PRD says "all remaining Core gap words as enumerated by `docs/ans-forth-core-compliance.md`" — the canonical list is in a separate file, not inline.
**Recommendation:** The first story of Epic 10 should be "Re-audit `docs/ans-forth-core-compliance.md`; produce a concrete story-level checklist of residual gap words with story assignments." This protects Epic 10 from scope creep during authoring.
**Severity:** important; unblocks rigorous story sizing.

#### 🟠 Important: Epic 11 ABORT-site count is unknown

**Issue:** "All internal error paths migrate to THROW" is universally quantified without a concrete count of sites.
**Recommendation:** Epic 11's first story must be **"Survey and enumerate every existing ABORT call site in the kernel; produce a migration checklist."** Without this, Epic 11's sizing is a guess.
**Severity:** important; directly affects epic sizeability.

#### 🟠 Important: Epic 12 ASSEMBLER.FTH authorship is a mini-epic in itself

**Issue:** Converting ~168 Z80 opcodes from hand-optimised assembly into ≤ 8 KB of Forth source (preserving existing CODE-word source compatibility) is a multi-story effort masquerading as "a story within Epic 12."
**Recommendation:** The next workflow should break ASSEMBLER.FTH authorship into its own sub-sequence of stories within Epic 12: (a) authoring framework + per-opcode test harness, (b) data-transfer + arithmetic opcode families, (c) control-flow opcode families, (d) prefix / indexed addressing families, (e) size-budget verification. Or consider promoting it to its own mini-epic between Epic 12 and Epic 13.
**Severity:** important; directly affects Epic 13 capstone schedule.

#### 🟠 Important: Capstone-story gating on Epic 12 completion

**Issue:** The Epic 13 capstone story (north-star demo) cannot be validated until `ASSEMBLER.FTH` is real and loadable. If story authoring places the capstone before Epic 12 is fully done, validation is blocked.
**Recommendation:** Add explicit gating language to the Epic 13 capstone story's prerequisites: "Depends on: Epic 12 fully complete, `ASSEMBLER.FTH` at release-candidate quality."
**Severity:** important; prevents ordering mistake.

### 🔴 Critical Violations

**None identified.** No phase-2 epic description in PRD/architecture violates user-value focus, epic independence, or no-forward-dependency rules.

### Best-Practices Compliance (at epic-description level)

For each phase-2 epic as described in PRD + architecture:

| Criterion | Epic 9 | Epic 10 | Epic 11 | Epic 12 | Epic 13 |
|---|---|---|---|---|---|
| Delivers user value | ✅ | ✅ (with minor title tweak) | ✅ | ✅ | ✅ |
| Functions independently of later epics | ✅ | ✅ | ✅ | ✅ | ✅ |
| Traces to PRD FRs | ✅ (FR1–9) | ✅ (FR10–15) | ✅ (FR16–22) | ✅ (FR23–31) | ✅ (FR32–49) |
| Has architectural decisions supporting implementation | ✅ (E9-D1, D2) | ✅ (E10-D1–D3) | ✅ (E11-D1–D3 + CCD-1) | ✅ (E12-D1–D4 + CCD-1) | ✅ (E13-D1–D5 + CCDs) |
| Size is plausibly a real epic (neither single story nor multi-month) | ✅ | ✅ | ⚠️ (unbounded without ABORT survey) | ✅ (with ASSEMBLER.FTH break-out) | ✅ |

### Auto-Proceeding

Epic quality review complete. Loading next step for final readiness assessment.

## Summary and Recommendations

### Overall Readiness Status

**READY** — conditional on the five prospective concerns below being addressed as the first stories of their respective epics during the next workflow (`create-epics-and-stories`).

The PRD (`prd.md`, 2026-04-14) and architecture (`architecture.md`, 2026-04-14) together constitute a complete, internally consistent, and actionable basis for story breakdown. All 52 FRs trace to delivering epics; all 23 NFRs trace to architectural mechanisms; no forward dependencies; no orphan requirements; no violated best-practice rules at the epic-description level. The four architectural findings surfaced by adversarial review in the architecture workflow are resolved inline in the architecture document.

Phase-2 stories have not been authored — this is the expected state and the reason the next workflow exists. This report has reviewed the planning artefacts that will *feed* story authoring; it does not pretend to have reviewed stories that do not exist.

### Critical Issues Requiring Immediate Action

**None.**

No critical gaps, no document conflicts, no unresolved architectural findings, no forward dependencies, no user-value violations at the epic-description level.

### Important Concerns to Address During Story Authoring

These are forward-looking recommendations for the `create-epics-and-stories` workflow. They prevent avoidable rework, not defects in current artefacts.

1. **Epic 10 — residual Core-gap word list:** make "re-audit `docs/ans-forth-core-compliance.md` and enumerate residual gap words" Epic 10's first story. Protects against scope creep during authoring.
2. **Epic 11 — ABORT-site enumeration:** make "survey every existing ABORT call site; produce a migration checklist" Epic 11's first story. Makes the phased migration story-sizable.
3. **Epic 12 — ASSEMBLER.FTH as sub-sequence:** break ASSEMBLER.FTH authorship into its own sub-sequence within Epic 12 (authoring framework + per-opcode-family migration + size-budget verification). Possibly promote to its own mini-epic between Epic 12 and Epic 13 if sizing warrants.
4. **Epic 13 — capstone gating:** add explicit "depends on Epic 12 fully complete (not merely mostly done)" language to the north-star demo story's prerequisites.
5. **Epic 10 — title:** consider re-titling Epic 10 during authoring to centre the user outcome ("Double-Precision Arithmetic & Numeric Formatting") with 100% compliance as the DoD rather than the identity. Cosmetic but aligns with best practice.

### Minor Concerns

- None beyond the cosmetic Epic 10 title note above.

### Recommended Next Steps

1. **Run `/bmad-bmm-create-epics-and-stories`** — author Epic 9 through Epic 13 at story level, incorporating the five concerns above as specific story AC or sequencing rules.
2. **After epic/story authoring: run `/bmad-bmm-sprint-planning`** — generate `sprint-status.yaml` covering Epics 9–13.
3. **Begin implementation at Epic 9 Story 1** — lowest-risk epic, delivers immediate value, unblocks better test-script readability for all subsequent epics.
4. **Re-run `/bmad-bmm-check-implementation-readiness` after Epic 9 completes** — this step will re-assess the maturing picture once stories exist.

### Assessment Counts

- Critical findings: **0**
- Important (addressable during story authoring): **4**
- Minor (cosmetic): **1**
- Documents validated: 4 (PRD, architecture, phase-1 epics as template, phase-2 product brief)
- FRs traced to architectural support: **52 / 52 (100%)**
- NFRs traced to architectural support: **23 / 23 (100%)**
- Architectural findings still open: **0** (all 4 resolved inline in architecture.md)

### Final Note

This assessment identified **5 prospective concerns across 2 categories** (4 important + 1 cosmetic), zero critical issues, zero blocking gaps. The phase-2 planning artefacts are ready to drive story authoring. Address the important concerns as first-story AC during the `create-epics-and-stories` workflow; the cosmetic concern can be addressed or ignored as preferred.

The PRD and architecture are **ready to proceed to epic breakdown.**

---

**Assessment date:** 2026-04-14
**Assessed by:** Claude Code PM/SM workflow (`check-implementation-readiness`)
**Phase:** antforth 2.0 (Epics 9–13)
**Prior assessment:** `implementation-readiness-report-2026-03-12.md` (phase-1 closure)
