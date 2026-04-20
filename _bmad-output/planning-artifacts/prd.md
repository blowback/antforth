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
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-04-14.md
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-03-11.md
  - _bmad-output/planning-artifacts/prd-phase1-epics-1-8.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/epic6-code-size-optimization.md
  - _bmad-output/planning-artifacts/epic7-shadow-register-optimization.md
  - _bmad-output/planning-artifacts/epic8-shadow-register-followup.md
  - _bmad-output/planning-artifacts/implementation-readiness-report-2026-03-12.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-04-12.md
  - docs/ans-forth-core-compliance.md
  - docs/z80_forth_assemblers.md
  - docs/z80-instruction-coverage.md
  - docs/z80-instruction-coverage-reaudit.md
  - docs/WISHLIST.md
  - docs/shadow-register-survey.md
  - docs/shadow-register-followup-survey.md
  - docs/register-conventions.md
documentCounts:
  briefCount: 2
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 13
workflowType: 'prd'
---

# Product Requirements Document - antforth

**Author:** Ant
**Date:** 2026-04-14

## Executive Summary

antforth is an ANS-compliant Forth interpreter and interactive development environment built from scratch in Z80 assembly for the MicroBeast retrocomputer (8 MHz Z80, 512K banked RAM/ROM, CP/M 2.2). Epics 1–8 delivered the execution engine, interactive REPL, language-extension compiler, built-in Z80 assembler, MARKER state rollback, and shadow-register optimisation. This PRD scopes the **next phase** — five sequential epics (9–13) that culminate in the **antforth 2.0** release.

The phase pursues two mutually reinforcing goals:

1. **100% ANS Forth Core compliance** — driving from the current ~86% to full coverage, the headline credibility win for prospective users of the project
2. **On-device source development via the CP/M filesystem** — unblocking the edit / test / persist cycle directly on the MicroBeast hardware, the personal success moment for the project's primary persona

The phase ships as antforth 2.0 when both goals are met and all inter-epic infrastructure (numeric literal prefixes, Core gap words, CATCH/THROW, multi-vocabulary Search-Order + `ASSEMBLER` wordlist, File-Access) is operational and exercised by REPL-piped Forth test scripts against a real MicroBeast. The built-in Z80 assembler (Epics 4 / 4.3.5 / 4.4) is retained unchanged in Phase 2 and is simply wired under the new `ASSEMBLER` wordlist.

### What Makes This Special

- **Purpose-built for MicroBeast** — no generic CP/M Forth supports the platform's unique I/O and display hardware, or the upcoming VideoBeast / AudioBeast expansion modules
- **Modern ANS standard** (Forth 2014 for numeric literals specifically) — vs the FIG-Forth / Forth-79 implementations typically available for CP/M
- **Learning-driven quality** — the project exists to deepen expertise in Forth and Z80 simultaneously; every design decision is optimised for understanding, not just shipping
- **Standards-grounded** — numeric literal prefixes, Core wordset, Exception semantics, Search-Order, and File-Access all follow the ANS Forth 2014 standard text directly

## Project Classification

- **Project Type:** `developer_tool_embedded` — a programming language / interpreter (Forth, a developer tool) implemented for embedded 8-bit hardware (the MicroBeast Z80 retrocomputer)
- **Domain:** `general` — hobbyist / retrocomputing tool; not a regulated or specialised industry domain
- **Complexity:** `low` — well-understood scope, single-developer project, no compliance or regulatory constraints, no novel-technology risk; the technical intricacy lies in Z80 assembly minutiae rather than systemic complexity
- **Project Context:** `brownfield` — Epics 1–8 are shipped; this PRD scopes the next five epics (9–13) on top of the existing system, culminating in the antforth 2.0 release

## Success Criteria

### User Success

**For "The OG" (experienced retrocomputing enthusiast):**

- User loads a Forth source file from B: ramdisk via `INCLUDE`, modifies a word at the REPL, and saves it back — full edit / test / persist cycle on the device, no cross-compiler involved
- User defines `CODE` words using the inline assembler; opcode words are visible only inside `CODE`/`END-CODE` thanks to the `ASSEMBLER` wordlist auto-activation, and invisible outside (no accidental opcode-word collisions with user words)
- User catches and handles errors in their own code via `CATCH` rather than having the REPL `ABORT`
- User organises their own words into named vocabularies using `WORDLIST` and `DEFINITIONS`

**For "The Newb" (newcomer to retrocomputing):**

- Existing REPL and language-extension behaviour remains stable — no regressions in Epics 1–8 behaviour
- Error messages carry standardised `THROW` codes; errors are self-describing rather than opaque `?` responses
- Hex / binary literal prefixes (`0xFF`, `%1010`) match C-family muscle memory, reducing the friction of entering low-level constants

### Business Success

N/A — antforth is a hobby / learning project with no commercial objectives. Equivalent non-commercial framing:

- **Community signal growth:** from the current "mild interest" baseline (per the 2026-04-14 product brief) to at least one non-author MicroBeast community member actively using antforth
- **External-visibility credibility:** "100% ANS Forth Core compliant" is a specific, verifiable claim suitable for README, MicroBeast community forums, and retrocomputing-scene posts
- **Foundation laid for the phase after this one:** the file-access and wordlist infrastructure delivered here is prerequisite for the MicroBeast hardware vocabulary and the beginner's guide — both highest-value near-term post-2.0 items

### Technical Success

All items below are hard, verifiable acceptance criteria for the phase:

- **100% ANS Forth Core wordset coverage** as measured by `docs/ans-forth-core-compliance.md` methodology (baseline: 86%). Not "near" — 100%.
- **Forth 2014 §3.4.1.3 numeric literal syntax** (`#dec`, `$hex`, `%bin`, `'c'`) accepted system-wide, plus the **antforth `0x` extension** for C-family familiarity. All prefixes case-insensitive. `BASE` is not mutated by parsing.
- **Double-precision arithmetic** (`D+`, `D-`, `D*`, `DNEGATE`, `DABS`, `D<`, `D=`, `DMAX`, `DMIN`, `2@`, `2!`, `2DUP`, `2DROP`, `2SWAP`, `2OVER`, `M*`, `UM*`, `M+`, `SM/REM`, `FM/MOD`, `UM/MOD`, `>D`, `S>D`, `D>S`) fully operational
- **Pictured numeric output** (`<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`, `HOLDS`) operational; `.`, `U.`, `D.`, `U.R`, `.R`, `D.R` reimplemented on top
- **`CATCH` / `THROW`** operational; **every internal error path** migrated through the exception mechanism — no remaining ABORT paths outside the standard `-1 THROW` / `-2 THROW` wrappers for `ABORT` / `ABORT"`
- **Multiple vocabularies** operational (`WORDLIST`, `SEARCH-WORDLIST`, `GET-ORDER`, `SET-ORDER`, `GET-CURRENT`, `SET-CURRENT`, `DEFINITIONS`, `ONLY`, `FORTH-WORDLIST`); the **`ASSEMBLER` wordlist auto-activates** inside `CODE` / `END-CODE` and deactivates afterwards; **all existing CODE-word source files continue to assemble correctly** (backward-compatibility AC)
- **File-Access wordset** operational against CP/M 2.2 BDOS (A: ROM, B: ramdisk); `INCLUDE` loads source files; source can be saved back to B:
- **All new functionality exercised by REPL-piped Forth test scripts** (per project testing conventions)
- **All existing Epic 1–8 test suites continue to pass** — regression guarantee
- **Kernel ROM footprint tracked per-epic** with a strict per-epic budget; any growth is justified against the Phase-2 capability added in that epic (see NFR4)

### Measurable Outcomes

| Indicator | Pre-phase baseline | antforth 2.0 target |
|---|---|---|
| ANS Core wordset coverage | 86% | 100% |
| Double-precision arithmetic | Not implemented | Full set operational |
| Pictured numeric output | Not implemented | Full set operational |
| CATCH / THROW | Not implemented | Operational, all internal errors migrated |
| Vocabulary model | Single flat | Full Search-Order + `ASSEMBLER` wordlist |
| CP/M file load/save | Not implemented | `INCLUDE` operational; save to B: operational |
| Assembler opcodes | Baked into kernel dictionary | Baked into kernel, reachable under `ASSEMBLER` wordlist inside `CODE`/`END-CODE` |
| External users | 0 (mild interest) | ≥ 1 active non-author user |
| Kernel ROM footprint | Current size | Tracked per-epic; per-epic budgets maintained |
| Numeric literal prefixes | Only `<BASEnum>` | Forth 2014 §3.4.1.3 + `0x` extension |

## Product Scope

### MVP — Minimum Viable Product

The **antforth 2.0** release (end of Epic 13) is the MVP for this phase. It ships when all items listed under *Technical Success* above pass as acceptance criteria — specifically: 100% ANS Core compliance, CATCH/THROW with full internal-error migration, Search-Order + `ASSEMBLER` wordlist auto-activation (with all pre-phase CODE sources assembling unchanged), File-Access operational against CP/M 2.2, numeric-literal prefixes system-wide, and all Epic 1–8 regressions intact.

### Growth Features (Post-MVP)

Near-term additions, built on the antforth 2.0 foundation, that move the product from "standards-compliant" to "genuinely useful on MicroBeast":

- **User-facing documentation** — beginner's guide, per-wordset reference, worked examples. Deferred during the phase per project decision ("no docs until features are done"); the first priority post-2.0.
- **MicroBeast hardware vocabulary** — 14-segment LED display words, I/O port access. The first consumer of both the new `ASSEMBLER` wordlist and the new file-load workflow.
- **Locals wordset** — `{: a b -- c :}`, `VALUE`, `TO`
- **SEE decompiler** + **`TRAVERSE-WORDLIST`** — enables xref tools and integrity checkers written in Forth itself
- **Built-in `IN` / `OUT` primitives** — today available only via user-defined CODE words

### Vision (Future)

Medium- and long-term platform evolution:

- **Cooperative multitasker** (PAUSE-based yield model, `TASK` / `ACTIVATE`) with `KEY` integrated so the REPL itself multitasks — opens the door to interrupt-driven on-device applications
- **Semaphores** (`SIGNAL` / `WAIT`, mutexes, mailbox primitives) for cooperating tasks
- **VideoBeast support** — sprite manipulation and graphics primitives for the upcoming expansion card
- **AudioBeast support** — instrument definition and sound-generation vocabulary
- **Float wordset**
- **Compilation to standalone `.com` binary** with tree-shaking — deliverable Forth apps for the wider MicroBeast and CP/M communities
- **Object orientation** — after study of Pountain's book and the NEON / Yerk / FOBJ literature
- **Portability to other Z80 retrocomputer platforms** — leveraging the design's inherent portability; a concrete second-platform port would validate this
- **Community word library sharing** — the ecosystem begins to form

## User Journeys

### Scope Note on User Types

antforth is a **single-user interactive REPL** running on personal retrocomputer hardware. There is no network surface, no multi-tenant model, no authentication, and no API layer. The traditional PRD categories of *admin*, *support*, *moderator*, and *API consumer* do not apply — the user **is** the admin of their own machine. Accordingly, the journeys below cover the two primary personas from the 2026-04-14 product brief ("The OG" and "The Newb") across happy-path and edge-case flows, plus the one secondary persona (the Hardware / Peripheral Developer). This is the full human-interaction surface of the product.

### Journey 1 — Mo's On-Device Session (OG, happy path)

**Opening scene.** Mo has been building and hacking on 8-bit machines for thirty years. She helped eight other people on the MicroBeast forum build their own kits. She's been following antforth's development on the project's Discord and downloaded the 2.0 release this morning. She boots it cold on her MicroBeast.

**Rising action.** The banner reads `antforth 2.0 — ok`. Second nature: she types `HEX`, then `: BLINK 0xF0 @ 1 XOR 0xF0 ! ;`. Hits return. `ok`. She types `BLINK BLINK BLINK` and sees the LED on the bench flick three times. No disk activity — the opcode definitions live in the kernel as they always have, but now they're only visible inside `CODE`/`END-CODE` thanks to the `ASSEMBLER` wordlist's auto-activation. Outside a `CODE` block, her user words can't collide with opcode names anymore.

**Climax.** She loads her own work-in-progress driver from B: with `INCLUDE B:SPRITES.FTH`, picks up where she left off yesterday. Edits a word at the REPL — `MARKER -OLD`, redefines, tests. It works. Saves the updated source back to B: with `SAVE-SOURCE`. Tomorrow she'll `INCLUDE` it again. The machine is finally a development environment, not a relic.

**Resolution.** Later in the afternoon, a bug in her ring-buffer code surfaces. Instead of the ABORT that would have wiped her session on pre-2.0 antforth, she wraps the failing word in `CATCH`, gets a clean error code back, fixes the issue, re-tests — all without losing her dictionary. Errors are survivable.

**Requirements surfaced:** Epic 9 (hex prefixes in her CODE definition), Epic 11 (CATCH for error survivability), Epic 12 (`ASSEMBLER` wordlist auto-activation, no opcode leakage outside `CODE`/`END-CODE`), Epic 13 (`INCLUDE` / `SAVE-SOURCE` for on-device edit/test/persist).

### Journey 2 — Mo Catches a Bug (OG, edge case)

**Opening scene.** Mo is writing a word that manipulates a ring buffer. Something's off — `BUFFER-PUSH` returns garbage after ten calls. On pre-2.0 antforth, she'd narrow it down by hand, and one stack underflow would ABORT her REPL, losing all her in-session definitions.

**Rising action.** This time she writes: `: SAFE-TEST  ['] BUFFER-PUSH CATCH  ?DUP IF  ." error: " . CR  THEN ;` She runs `SAFE-TEST` ten times. On the eleventh call it prints `error: -4` — stack underflow. The REPL is still there. Her definitions are intact. She drops into `SEE BUFFER-PUSH`... wait, no, SEE is post-2.0. She drops into her own source file on B:, fixes the off-by-one, `INCLUDE`s it again, retries.

**Climax.** The fix sticks. No lost session, no re-type of forty minutes of exploratory work, no cursing.

**Resolution.** She reflects that CATCH/THROW is the single feature that turns antforth from "interesting toy" into "tool I'd actually live in." Error recovery is quality of life.

**Requirements surfaced:** Epic 11 (`CATCH`, `THROW`, standardised THROW codes), Epic 13 (`INCLUDE` re-load workflow, saving state across sessions).

### Journey 3 — Raj's First Hour (Newb, happy path)

**Opening scene.** Raj is twenty-four, a web developer by day, building a MicroBeast kit on weekends because retro computing looks like magic. He's just loaded antforth 2.0 following the beginner's guide from the community wiki (not authored by the project yet, but written by another community member — the mild-interest signal paying out). Prompt sitting there: `ok`.

**Rising action.** Guide says: "Let's light up the LED display." First step: understand numbers. Raj types `0xFF .` and sees `255 ok`. He's at home instantly — same syntax as every language he writes professionally. No `HEX` / `DECIMAL` mode-toggle ritual, no learning `$FF` when his muscles want `0xFF`. Types `%1010 .` → `10 ok`. Types `#1234 .` → `1234 ok`. The numeric-literal grammar feels transparent.

**Climax.** He types a word from the guide: `: HELLO  S" HI " 0 DISPLAY! ;`. Runs it. The 14-segment LEDs spell `HI`. His face lights up in exactly the way the display does. He took a bare-metal computer from off to "programmed" in one hour, and hex-literal friction was zero.

**Resolution.** Raj keeps going. Redefines the word with `0xAA` as the pattern byte, sees the LED segments light differently. Starts to grasp *hardware*, not just *syntax*. Goes to bed at 2am with a personal notebook of Forth words he half-understands, full of joy.

**Requirements surfaced:** Epic 9 (Forth 2014 prefixes, `0x` extension, case-insensitive), Epic 10 (`.` and formatted output working correctly for all bases), stable REPL UX inherited from Epics 1–8.

### Journey 4 — Pete Validates a Prototype (Hardware / Peripheral Developer, secondary)

**Opening scene.** Pete is the MicroBeast's creator. He has a bare-board prototype of VideoBeast on his bench — registers, sprite DMA, palette memory — and he needs to know whether the tile-scroll register actually behaves the way the schematic says. Pre-2.0: cross-compile a minimal test harness in Z80 assembly, burn a ROM, plug it in, observe, iterate. Hours per variation.

**Rising action.** Post-2.0: he boots antforth 2.0, types `INCLUDE VIDEOBEAST-PROTO.FTH` from a file on B: that he edited five minutes ago. The file contains rough driver words: `VB-TILE!`, `VB-SCROLL!`, `VB-SPRITE@`. He starts poking. `5 VB-SCROLL!` — nothing moves. Hmm. Wraps it: `' VB-SCROLL! CATCH` — no throw, so no logic error, it's hardware behaviour. He types `VB-SCROLL? .` and sees the register reads back as 0 regardless of write. Ah — the `WE` line is inverted on his prototype.

**Climax.** Edits the source file to toggle the write-enable polarity. `INCLUDE` again. `5 VB-SCROLL!`. The scroll happens. He spent twelve minutes where he used to spend two hours.

**Resolution.** He opens the MicroBeast community Discord and posts: "VideoBeast rev-0.3 works with antforth 2.0, driver on my GitHub." The "mild interest" signal ticks up by one.

**Requirements surfaced:** Epic 11 (CATCH for distinguishing logic vs hardware errors), Epic 13 (INCLUDE for rapid edit-reload, file-I/O from the working directory), Epic 12 (wordlist separation to isolate prototype drivers from kernel words).

### Journey Requirements Summary

The four journeys above collectively surface the following PRD-level capability requirements:

| Capability | Journey 1 | Journey 2 | Journey 3 | Journey 4 | Epic |
|---|---|---|---|---|---|
| Numeric literal prefixes (Forth 2014 + `0x`) | ✓ | | ✓ | | Epic 9 |
| ANS Core compliance (no regressions, formatted output) | ✓ | ✓ | ✓ | ✓ | Epic 10 |
| `CATCH` / `THROW` + THROW codes | | ✓ | | ✓ | Epic 11 |
| Multiple vocabularies / `ASSEMBLER` wordlist | ✓ | | | ✓ | Epic 12 |
| `INCLUDE` / `SAVE-SOURCE` on CP/M filesystem | ✓ | ✓ | | ✓ | Epic 13 |
| Existing REPL / compiler behaviour stable | ✓ | ✓ | ✓ | ✓ | Regression AC |

Every capability delivered by Epics 9–13 traces to at least one journey; every journey is covered by a coherent set of Epic deliverables. No orphan requirements, no uncovered users.

## Developer-Tool-Embedded Requirements

antforth is a compound `developer_tool` (programming-language implementation) + `iot_embedded` (single-purpose 8-bit hardware platform). Most generic SDK questions (package managers, IDE integration, OTA updates) do not apply — the interpreter IS the package, the device IS the IDE, and updates are delivered by copying a new `.COM` file to the CP/M filesystem. The requirements below focus on what is genuinely specific to this product shape.

### Project-Type Overview

antforth is distributed as a **CP/M 2.2 `.COM` executable** that runs on the MicroBeast Z80 retrocomputer. It is simultaneously (a) an implementation of the ANS / Forth 2014 programming language and (b) a self-hosted interactive development environment. It has no external build chain, no package dependency graph, no network surface, and no multi-user runtime. The user installs by copying the `.COM` file to the CP/M A: (ROM) or B: (ramdisk) drive and runs it like any other CP/M program.

### Target Platform Requirements

- **CPU:** Zilog Z80 @ 8 MHz (MicroBeast spec). Z80 instruction-set compliance only — no Z80N, no eZ80, no Z180 extensions
- **Memory:** 512 KB banked RAM/ROM, MicroBeast bank-switching scheme. antforth kernel + dictionary live in bank 0 under CP/M's TPA
- **Host OS:** CP/M 2.2. All I/O (console, file system, drive select) is routed through BDOS calls; no direct hardware I/O beyond the BIOS-level abstractions CP/M provides, except for explicit MicroBeast hardware words (post-phase — deferred)
- **Storage:** A: (ROM filesystem, read-only practically) and B: (ramdisk, read-write) as the two canonical drives. Other CP/M drives are supported generically via BDOS but not specifically tested
- **Terminal:** standard CP/M console (character I/O via BDOS functions 1, 2, 6, 9); no assumption of ANSI escape sequences, cursor addressing, or colour
- **Display hardware (post-phase):** 24-character 14-segment LED displays on the MicroBeast. Not consumed by this phase; reserved for the post-2.0 MicroBeast hardware vocabulary epic

### Language / Standard Compliance

- **Primary standard:** ANS Forth 1994 (ANSI X3.215-1994) — Core wordset to 100% coverage by end of Epic 10
- **Secondary standard:** Forth 2014 — specifically §3.4.1.3 for numeric-literal prefix syntax (`#dec`, `$hex`, `%bin`, `'c'`) adopted verbatim in Epic 9
- **antforth extensions beyond standards:** the `0x` hex-literal prefix (Epic 9); any future non-standard extensions must be clearly flagged in source and documentation
- **Word-set coverage within Core:** all Core wordset words. Extended wordsets (Double, Search-Order, Exception, File-Access) are partial — only those required for the Epic 9–13 scope are in for this phase. Locals, Float, Memory-Allocation, Programming-Tools, String, Tools-Ext are out of scope for this phase.

### Installation & Distribution

- **Artifact:** single `.COM` file, Z80 machine code, assembled from the antforth source tree
- **Installation:** copy `ANTFORTH.COM` to a CP/M drive (typically A: ROM or B: ramdisk) via whatever file-transfer mechanism the user has available (serial transfer, EPROM programmer, SD-card adapter, etc.). Single-file install.
- **Update mechanism:** replace the `.COM` file. No in-place upgrade, no migration tooling. Because antforth's state is user-source on disk, sessions survive interpreter updates as long as the dictionary layout is compatible
- **Versioning:** semantic versioning. Epics 9–12 ship as 1.x incremental releases; Epic 13 completion tags 2.0. Breaking dictionary layout changes require a major version bump

### Runtime Model

- **Boot flow:** `.COM` loaded by CP/M → banner → REPL prompt. Assembler opcodes baked into the kernel dictionary, reachable under the `ASSEMBLER` wordlist (auto-activated inside `CODE`/`END-CODE`). Unchanged across pre-2.0 and 2.0.
- **Persistence:** user words live in RAM until the machine is powered off. Persistence across sessions is achieved by saving source to B: and `INCLUDE`-ing on next boot. There is no image-save mechanism; this is by design (keeps the source-of-truth in the user's files, not in the interpreter's state)
- **MARKER:** still the in-session rollback mechanism. Unchanged by this phase.

### Explicitly Out of Scope for Project-Type Requirements

The following generic `developer_tool` and `iot_embedded` concerns are not applicable to antforth and will not be documented:

- **Package managers / dependency resolution** — antforth has no package ecosystem; the unit of sharing is a `.FTH` source file
- **IDE integration** — the REPL IS the IDE; syntax highlighting / completion are out of scope for this phase
- **OTA updates** — replace the `.COM` file; no over-the-air mechanism required or planned
- **Power management / sleep modes** — mains-powered retrocomputer, not battery-constrained
- **Network security** — no network surface on the platform
- **Multi-platform language-support matrix** — antforth targets Z80 + CP/M specifically. Portability is listed as a long-term stretch goal but not in this phase's scope.

### Implementation Considerations

- **Source-of-truth boundary:** kernel written in Z80 assembly (builds with the external cross-assembler toolchain); system words written in Forth that the running interpreter reads on boot (post-2.0). The boundary of what is kernel vs what is Forth source shifts leftward over time — Epic 13 moves the assembler across this boundary
- **Test harness:** REPL-piped Forth test scripts (per established project testing conventions since Epic 3). Continues as the canonical test format for all new functionality in Epics 9–13
- **Cross-tooling:** build and test happen on a modern host (emulator + cross-assembler); final validation happens on real MicroBeast hardware. Both surfaces must be exercised before a release is tagged
- **ROM-size budget:** strict per-epic. Each epic logs its kernel-size delta and justifies increases against the Phase-2 capability added. Phase-2 additions will grow the kernel relative to the Epic-8 baseline; size-reduction opportunities are spawned as dedicated follow-up stories (Epic-6 precedent).

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach: Platform MVP.** antforth 2.0 is a platform release — its job is to establish a credible, standards-compliant foundation and a functional on-device development workflow on which future epics can build. It is not a revenue MVP (no revenue), not an experience MVP (core UX was already shipped in Epics 1–8), and not a problem-validation MVP (the problem space is confirmed by the existing user/persona work). It is the platform-credibility release: when 2.0 ships, the project can claim "100% ANS Forth Core" and "on-device source development" as unqualified facts.

**Resource Requirements:** single developer (Ant), supported by the BMAD agent workflow for planning, story authoring, dev execution, and QA. No external dependencies, no contractor time, no third-party integrations to schedule.

**Success Philosophy:** ship the complete five-epic sequence — 9, 10, 11, 12, 13 — in order, with the Epic-13 release gate (100% Core + CATCH/THROW + Search-Order + File-Access + full regression) as the acceptance signal. Partial delivery (e.g., Core to 100% without File-Access) is a legitimate 1.x release but does not constitute MVP delivery for this phase. The phase is defined by the 2.0 gate.

### MVP Feature Set (Phase 1 — antforth 2.0)

**Core user journeys supported at MVP:**

- Journey 1 (Mo's on-device session) — full support at 2.0 (Epic 9 + Epic 11 + Epic 12 + Epic 13)
- Journey 2 (Mo catching a bug) — full support when Epic 11 + 13 ship
- Journey 3 (Raj's first hour) — full support when Epic 9 ships (earliest value delivery of the phase)
- Journey 4 (Pete validates prototype) — full support when Epics 11, 12, 13 ship

**Must-have capabilities, grouped by epic:**

| Epic | Capability | Sequencing rationale |
|---|---|---|
| **Epic 9** | Forth 2014 §3.4.1.3 numeric literals + `0x` extension; case-insensitive; system-wide | First — every subsequent epic's test scripts and source benefit immediately |
| **Epic 10** | Double-precision arithmetic; pictured numeric output; all remaining Core gap words; 100% Core compliance | Second — pictured output depends on double-precision; Core gaps unblock tests for later epics |
| **Epic 11** | `CATCH` / `THROW`; all internal error paths migrated; standard THROW codes | Third — File-Access and Search-Order both benefit from throw-based error handling |
| **Epic 12** | `WORDLIST`, `SEARCH-WORDLIST`, `GET-ORDER`, `SET-ORDER`, `GET-CURRENT`, `SET-CURRENT`, `DEFINITIONS`, `ONLY`, `FORTH-WORDLIST`; `ASSEMBLER` wordlist created with all built-in opcodes registered; `ASSEMBLER` auto-activation inside `CODE` / `END-CODE`; all pre-phase CODE source files assemble unchanged | Fourth — consumes the exception infrastructure from Epic 11; delivers the vocabulary/namespace capability called out in Mo's and Pete's journeys |
| **Epic 13** | Full File-Access wordset; `INCLUDE` / `SAVE-SOURCE` against B: ramdisk and A: ROM; Phase-2 regression gate; BDOS-function-allow-list audit; ROM-delta accounting | Fifth — consumes everything above; tags antforth 2.0 on pass |

**MVP rule:** no epic is considered done until its tests pass on real MicroBeast hardware (not just emulator) AND all prior epics' tests still pass. Regression is a blocker, not a deferrable.

### Post-MVP Features

**Phase 2 (post-2.0, near-term — 3 to 6 months after 2.0 ships):**

- **User-facing documentation epic** — beginner's guide to antforth on MicroBeast, per-wordset reference pages, worked examples. First priority because the mild-interest signal becomes active adoption only when newcomers can onboard themselves.
- **MicroBeast hardware vocabulary epic** — 14-segment LED display words, I/O port access, timer words. First consumer of the new `ASSEMBLER` wordlist and file-load workflow. High-value for both personas.
- **Locals / `VALUE` / `TO` epic** — small scope, significant ergonomic win for complex colon definitions.
- **SEE decompiler + `TRAVERSE-WORDLIST` epic** — makes the system self-inspectable, unlocks xref tools written in Forth.
- **Built-in `IN` / `OUT` primitives epic** — promotes commonly-used hardware access from user CODE words into kernel-level words.

**Phase 3 (post-2.0, long-term — 6 to 18 months and beyond):**

- **Cooperative multitasker epic** — PAUSE-based yield, `TASK` / `ACTIVATE`, `KEY`-hooked REPL multitasking, timer-ISR integration. Significant subsystem.
- **Semaphores epic** — complement to the multitasker.
- **Exception wordset extensions beyond Core** — non-Core THROW codes, `ABORT` customisation.
- **VideoBeast support epic** — sprite and graphics vocabulary. Depends on VideoBeast hardware availability.
- **AudioBeast support epic** — instrument and sound-generation vocabulary. Depends on AudioBeast hardware availability.
- **Float wordset epic** — significant size and complexity.
- **Compilation to `.com` binary** — tree-shaken standalone apps. Architecturally interesting.
- **Object orientation epic** — after Pountain study; unbounded-scope research work.
- **Portability epic** — second Z80 platform port.

### Risk Mitigation Strategy

**Technical risks:**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Core gap words require more effort than estimated (scope creep inside Epic 10) | Medium | Medium | Mid-Epic-10 survey against `docs/ans-forth-core-compliance.md`; if >30% over estimate, propose sprint-change with reduced scope + follow-up epic |
| Internal error migration to CATCH/THROW breaks many untested edge paths | Medium | High | Regression test suites from Epics 1–8 are the net; migration proceeds word-by-word, not en-masse; each migration is a distinct commit with dedicated REPL tests |
| Multi-vocabulary dictionary changes regress existing word lookup performance | Low | Medium | Benchmark kernel-speed tests from Epic 7/8 are retained; any >10% degradation is a blocker |
| CP/M file I/O edge cases (record boundaries, 128-byte blocks, EOF handling) burn Epic 13 time | Medium | Medium | Allocate a dedicated "file I/O sanity" story at the start of Epic 13 before implementing INCLUDE; tests against a known-good CP/M image |
| Kernel ROM footprint grows materially from Phase-2 additions without offset opportunities | Medium | Low | Per-epic ROM-size budget; size-reduction opportunities spawned as dedicated stories (Epic-6 precedent); the Phase-2 additions are strictly ANS-Core-compliance + standards-grounded capability, not optional features |
| Real-hardware bugs surface late (emulator-only development misses Z80 edge cases) | Medium | Medium | Each epic's final story includes a hardware-validation task; no release tag without a pass on real MicroBeast |

**Market / adoption risks:**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| No community adoption despite 2.0 release | Medium | Low (hobby project, no revenue) | Nothing to mitigate actively — adoption is a bonus, not a requirement. The project's business success criteria explicitly frame current "mild interest" as the baseline and one external user as the target |
| MicroBeast platform itself loses community momentum before 2.0 ships | Low | High | Outside project's control; mitigated by designing for portability (long-term vision item) so antforth survives platform transitions |

**Resource risks:**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Developer (Ant) loses interest / hits a burnout patch | Low | High | The project is intentionally shaped as a learning project with no deadline pressure; velocity can flex to zero without killing the project. Epics are independently shippable (each an `antforth 1.x` release) so any stopping point is a legitimate release |
| Scope creep within an epic (e.g., CATCH/THROW pulls in Exception Extensions) | Medium | Medium | The project lead has a strong track record of scope discipline (cf. 2026-04-12 sprint change proposal); mid-epic scope changes go through the `bmad-bmm-correct-course` workflow |
| "Just one more small feature" between epics | Medium | Low | Phase-2 backlog is explicit; incoming ideas go to WISHLIST, not to the current epic |

## Functional Requirements

> **Capability contract notice.** This list defines the complete set of capabilities that antforth 2.0 must deliver. Downstream work (epics, stories, tests) will be authored against this list. Any capability not listed here will not exist in the final product unless explicitly added.

### Numeric Literal Input (Epic 9)

- **FR1:** Users can enter decimal integer literals using the `#` prefix, regardless of the current `BASE`
- **FR2:** Users can enter hexadecimal integer literals using the `$` prefix, regardless of the current `BASE`
- **FR3:** Users can enter binary integer literals using the `%` prefix, regardless of the current `BASE`
- **FR4:** Users can enter character literals using the `'c'` syntax, yielding the character's numeric value
- **FR5:** Users can enter hexadecimal literals using the `0x` prefix as an antforth-specific alternative to `$`
- **FR6:** All prefixed numeric literals accept an optional leading `-` sign
- **FR7:** All numeric literal prefixes (`#`, `$`, `%`, `0x`) and their hex digits (a–f) are case-insensitive
- **FR8:** The interpreter recognises numeric-literal prefixes everywhere ordinary numbers are parsed — interactive REPL, compiled colon definitions, and the built-in Z80 assembler source
- **FR9:** Entering a prefixed literal does not mutate the value of the `BASE` variable

### Core Arithmetic & Numeric Output (Epic 10)

- **FR10:** Users can perform double-precision signed and unsigned integer arithmetic using the ANS Core double-cell word set (`D+`, `D-`, `D*`, `DNEGATE`, `DABS`, `D<`, `D=`, `DMAX`, `DMIN`, `M*`, `UM*`, `M+`, `SM/REM`, `FM/MOD`, `UM/MOD`)
- **FR11:** Users can store, fetch, and manipulate double-cell values on the parameter stack using `2@`, `2!`, `2DUP`, `2DROP`, `2SWAP`, `2OVER`
- **FR12:** Users can convert between single-cell and double-cell representations using `>D`, `S>D`, `D>S`
- **FR13:** Users can construct formatted numeric output using the ANS pictured numeric output wordset (`<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`, `HOLDS`)
- **FR14:** Users can output numbers using the Core display words (`.`, `U.`, `D.`, `.R`, `U.R`, `D.R`), which are implemented on top of the pictured output system
- **FR15:** Users can rely on 100% of the ANS Forth 1994 Core wordset being implemented and behaving per the standard

### Exception Handling (Epic 11)

- **FR16:** Users can wrap the execution of a word in a `CATCH` frame and receive a THROW code in the event of an error
- **FR17:** Users can raise an exception using `THROW` with an arbitrary non-zero integer code
- **FR18:** The system defines and honours the ANS standard THROW codes for common errors (stack underflow, undefined word, division by zero, etc.)
- **FR19:** Every internal error path in the interpreter, compiler, and primitive words routes through the `THROW` mechanism rather than through `ABORT`
- **FR20:** `ABORT` and `ABORT"` behave as wrappers for `-1 THROW` and `-2 THROW` respectively, per the ANS standard
- **FR21:** An uncaught THROW returns control to the REPL top level with a diagnostic message that includes the THROW code and (where applicable) a human-readable description
- **FR22:** The REPL itself survives any THROW — the user's session, dictionary, and definitions are preserved across errors

### Vocabulary & Namespace Management (Epic 12)

- **FR23:** Users can create a new wordlist with `WORDLIST`, receiving a wordlist identifier on the stack
- **FR24:** Users can query the current search order with `GET-ORDER` and set it with `SET-ORDER`
- **FR25:** Users can query and change the current compilation wordlist with `GET-CURRENT` and `SET-CURRENT`
- **FR26:** Users can direct subsequent definitions into the top-of-search-order wordlist using `DEFINITIONS`
- **FR27:** Users can reduce the search order to a minimal set with `ONLY`
- **FR28:** Users can reference the built-in Forth wordlist with `FORTH-WORDLIST`
- **FR29:** Users can search a specific wordlist for a word with `SEARCH-WORDLIST`
- **FR30:** The `ASSEMBLER` wordlist is automatically activated on entry to `CODE` and deactivated on exit from `END-CODE`
- **FR31:** Users with existing CODE-word source files authored against pre-phase antforth can assemble those files unchanged

### Source File I/O (Epic 13)

- **FR32:** Users can load a source file from the CP/M filesystem using `INCLUDE <filename>`
- **FR33:** Users can load a source file by explicit file identifier using `INCLUDE-FILE`
- **FR34:** Users can load a named source file using `INCLUDED`
- **FR35:** Users can open a file with `OPEN-FILE`, specifying an access mode (`R/O`, `R/W`, `W/O`, `BIN`)
- **FR36:** Users can create a file with `CREATE-FILE`, specifying an access mode
- **FR37:** Users can delete a file with `DELETE-FILE`
- **FR38:** Users can read bytes from a file with `READ-FILE`
- **FR39:** Users can write bytes to a file with `WRITE-FILE`
- **FR40:** Users can query and set the current file position with `FILE-POSITION` and `REPOSITION-FILE`
- **FR41:** Users can query the size of a file with `FILE-SIZE`
- **FR42:** Users can close a file with `CLOSE-FILE`
- **FR43:** File operations raise a THROW (not ABORT) on errors such as file-not-found, permission-denied, or disk-full
- **FR44:** Users can load source files from either drive A: (ROM filesystem) or B: (ramdisk) without syntactic distinction

### Backward Compatibility & Regression (phase-wide constraint)

- **FR45:** All functional behaviour delivered in Epics 1–8 continues to work identically in antforth 2.0 — REPL, colon definitions, variables, constants, `CREATE`/`DOES>`, control flow, error reporting, `MARKER`, and existing word semantics
- **FR46:** All existing REPL-piped test scripts from Epics 1–8 continue to pass against the antforth 2.0 binary
- **FR47:** The unprefixed numeric literal form (`<BASEnum>`) continues to be parsed per the current value of `BASE`, identically to pre-phase antforth

**Self-validation summary:**

- ✅ **Coverage** — every capability surfaced in the Executive Summary, Success Criteria, User Journeys, and Project-Type sections is represented by at least one FR
- ✅ **Traceability** — every FR is tagged with the epic(s) that deliver it; every epic has FRs covering its acceptance criteria
- ✅ **Altitude** — FRs describe WHAT users can do, not HOW the system implements it; many FRs could be implemented multiple ways
- ✅ **Testability** — every FR can be verified by an observable outcome (word exists, word does X on input Y, error arrives with expected code)
- ✅ **Independence** — each FR is understandable in isolation; no FR depends on reading another to be intelligible
- ✅ **Completeness bar** — if the system satisfies all 47 FRs, antforth 2.0 ships

## Non-Functional Requirements

> **Selective approach:** antforth is a single-user, single-machine, offline, hobby-scale retrocomputing tool. Categories that do not apply — **Security** (no network, no sensitive data, no auth), **Scalability** (one user, one 8-bit CPU), **Accessibility** (hardware-constrained; LED display is outside software control) — are explicitly omitted to avoid requirement bloat.

### Performance

- **NFR1: Numeric literal prefix parsing overhead.** Recognition of a prefixed numeric literal (`#`, `$`, `%`, `0x`, `'c'`) adds no more than **~20 Z80 cycles** over the unprefixed parse path for the 99th-percentile literal (bare integer with no prefix). Measured at the `INTERPRET` / number-conversion hot path against the Epic 7/8 benchmark suite.
- **NFR2: Word lookup across multiple vocabularies.** With a search order of up to 8 wordlists, word lookup shall not regress by more than **10%** of cycle count versus the pre-phase single-vocabulary baseline. Baseline is the existing XOR-rotate 64-bucket hash lookup benchmark. Measured with the standard benchmark script on real MicroBeast hardware.
- **NFR3: CATCH / THROW overhead.** An uncaught `CATCH` frame adds no more than **~15 Z80 cycles** to the protected word's execution (frame setup + teardown on normal exit). A successful THROW unwind back to the catching frame shall complete in bounded time proportional to the return-stack depth at THROW time.
- **NFR4: Kernel ROM footprint budget.** Each Phase-2 epic logs its kernel-size delta and justifies any increase against the capability delivered. Net-of-Phase-2 delta is expected to be positive (the new Phase-2 capabilities — double-cell + pictured output, exception wordset, Search-Order, File-Access — all add code that was not in the Epic-8 baseline). Size-reduction opportunities are spawned as dedicated follow-up stories rather than gated per epic.
- **NFR5: Double-precision arithmetic performance.** Core double-precision primitives (`D+`, `D-`, `M*`, `UM/MOD`) execute in time comparable to hand-rolled Z80 equivalents (within ~20% — no algorithmic-class gap).

### Reliability

- **NFR6: REPL survivability.** The REPL shall survive any THROW, including stack overflow, division by zero, and undefined-word invocation. User's dictionary, in-session definitions, and working state are preserved across errors. (Corollary of FR22, re-stated as a quality attribute.)
- **NFR7: State integrity after error.** No internal data structure (dictionary, wordlists, input buffer, pad, return stack) may be left in a corrupted or inconsistent state after a THROW. Standard ANS catch-frame cleanup semantics apply.
- **NFR8: Filesystem error recovery.** Failures during file operations (disk full, file locked, I/O error from BDOS) raise a THROW with a specific code and leave the filesystem in a consistent state — no partial writes that corrupt CP/M directory entries, no orphaned file handles.
- **NFR9: Regression guarantee.** The complete Epic 1–8 test suite shall pass on every antforth 2.0 candidate release. A single regression is a release blocker.

### Compatibility & Standards Conformance

- **NFR10: ANS Forth 1994 Core compliance.** The Core wordset (as enumerated in `docs/ans-forth-core-compliance.md`) is implemented to **100%** coverage with behaviour matching the ANS specification. Compliance is measured by the existing survey methodology; 86% → 100% is the phase's compliance progression.
- **NFR11: Forth 2014 §3.4.1.3 conformance.** Numeric literal prefix syntax is implemented verbatim as specified in the Forth 2014 standard, section 3.4.1.3.
- **NFR12: Extension discipline.** The only non-standard addition in this phase is the `0x` hex prefix. It is clearly flagged as an antforth-specific extension in all source comments and (post-phase) in user documentation. No silent divergence from the standards.
- **NFR13: CP/M 2.2 BDOS integration.** antforth uses only CP/M 2.2 standard BDOS functions (1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 25, 26, 27, 33, 34, 35, 36, 40). No CP/M Plus, MP/M, or extended BIOS-level calls. Portability across CP/M 2.2 implementations is preserved.
- **NFR14: CODE-word source file backward compatibility.** CODE-word source files written against pre-phase antforth assemble correctly and produce byte-identical output under antforth 2.0.

### Maintainability

- **NFR15: Code density and readability.** Z80 assembly source shall favour readability over micro-optimisation, except where the epic explicitly targets performance (Epics 7–8 precedent). Comments on non-obvious logic are required; comments re-stating what assembly already says are forbidden.
- **NFR16: Test-first discipline.** Every new word introduced in Epics 9–13 has REPL-piped Forth test coverage before being declared done (per established project convention since Epic 3). Test scripts are the canonical regression surface.
- **NFR17: Single-source-of-truth for standards references.** Word behaviours that derive from a standard cite the standard section in the source comment (e.g., `; Forth 2014 §6.2.2270 CATCH`). This enables future re-audits.
- **NFR18: Epic-level decoupling.** Each of Epics 9–13 delivers an independently-shippable `antforth 1.x` increment. Intermediate releases after Epics 9, 10, 11, 12 are each a legitimate release artifact — not merely an internal milestone.

### Integration (CP/M and Platform)

- **NFR19: Terminal I/O portability.** antforth uses only character-based BDOS console I/O (functions 1, 2, 6, 9). No assumption of ANSI escape codes, cursor positioning, line-mode vs raw-mode toggles, or colour support. The interpreter runs on any CP/M 2.2 terminal.
- **NFR20: File path conventions.** `INCLUDE` and related words accept CP/M 2.2 file path syntax (optional drive letter + `:` + 8.3 filename) exactly. No wildcards in the PRD-scoped implementation; no Unix-style paths.
- **NFR21: MicroBeast hardware dependency isolation.** No MicroBeast-specific hardware word enters the kernel or the ASSEMBLER wordlist during this phase. The MicroBeast hardware vocabulary is a post-2.0 epic and must be loadable as pure Forth source from disk, not kernel-resident.
