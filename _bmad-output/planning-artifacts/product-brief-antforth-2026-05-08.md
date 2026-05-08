---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - "_bmad-output/planning-artifacts/product-brief-antforth-2026-04-14.md"
  - "docs/PHASE-3-CARRY-FORWARD.md"
  - "_bmad-output/implementation-artifacts/epic-13.5-retro-2026-05-07.md"
  - "memory:project_phase2_scope.md"
date: 2026-05-08
author: Ant
---

# Product Brief: antforth

<!-- Content will be appended sequentially through collaborative workflow steps -->

## Executive Summary

antforth is an ANS-compliant Forth interpreter for the MicroBeast Z80 retrocomputer, built from scratch in Z80 assembly language. It transforms the MicroBeast from a machine limited to decades-old CP/M software into an interactive, extensible development platform. By providing a modern Forth REPL with native support for MicroBeast-specific hardware (14-segment LED displays, and future VideoBeast/AudioBeast expansion cards), antforth gives MicroBeast owners a powerful on-device programming environment that no existing CP/M Forth can offer.

The project follows Forth's bootstrapping philosophy: a minimal, performance-optimised Z80 assembler kernel provides the inner/outer interpreter and core primitives, from which the rest of the system is built in Forth itself. Key technical decisions include direct threading, XOR-rotate hashed vocabulary lookup with 64 buckets, TOS-in-register optimisation, and full double-precision arithmetic for ANS compliance. **As of this brief, antforth 2.0 has shipped** (git tag `v2.0.0` on commit `6599d73`, 2026-05-07): the kernel, outer interpreter, built-in Z80 assembler, MARKER, the full ANS Forth Core wordset (with §-level back-fills closing structural-rule gaps that word-counted surveys missed), the Exception subsystem (CATCH/THROW with all internal error paths migrated), the Search-Order wordset (multi-vocabulary), the File-Access wordset (INCLUDE/OPEN-FILE/READ-FILE/WRITE-FILE etc. against CP/M filesystems on real MicroBeast hardware), and the Phase-2 cleanup slate (Epic 13.5 — process-recovery vehicle that closed seven tag-blocking technical-debt items including a `."` BC-clobber, a real PAD word, and the EVALUATE arm of SAVE-INPUT/RESTORE-INPUT) are all operational. **This brief scopes Phase 3, which — like the Epic 13.5 cleanup interlude — is dedicated to clearing accumulated technical debt and closing standards-compliance gaps before any net-new feature work begins.** The intent is to clear the decks of baggage so that future feature epics start from a clean baseline.

antforth remains a personal learning project — an opportunity to deepen expertise in both Forth and Z80 assembly — with the intention of sharing with the broader MicroBeast hobbyist community once mature.

---

## Core Vision

### Problem Statement

The MicroBeast Z80 CP/M 2.2 retrocomputer lacks a modern, interactive on-device programming environment. Its current software ecosystem consists entirely of decades-old CP/M tools (such as Microsoft BASIC) that make the machine feel like a museum piece rather than a usable computer. There is no way to interactively develop, test, and extend software directly on the device in a productive and enjoyable way.

### Problem Impact

Without a capable on-device environment, MicroBeast users are limited to cross-development workflows or legacy CP/M software. The machine's unique hardware capabilities — including its 24-character 14-segment LED displays and upcoming expansion modules (VideoBeast, AudioBeast) — remain difficult to explore and exploit interactively. The MicroBeast community lacks a shared, extensible platform for building software that takes advantage of what makes their hardware special.

### Why Existing Solutions Fall Short

While Z80 CP/M Forth implementations exist, they suffer from key limitations:

- **No MicroBeast hardware support** — existing ports are generic CP/M Forths with no awareness of the MicroBeast's unique I/O devices and display hardware
- **Older standards** — most available CP/M Forths target FIG-Forth or Forth-79, not the modern ANS Forth standard
- **No expansion path** — no existing Forth is positioned to support upcoming MicroBeast peripherals like VideoBeast and AudioBeast
- **Missing the point** — porting an existing Forth skips the learning value and the opportunity to optimise specifically for the MicroBeast's 8 MHz Z80 with 512K banked RAM/ROM architecture

### Proposed Solution

antforth is a from-scratch ANS Forth built in Z80 assembly, purpose-built for the MicroBeast platform. Its architecture follows a bootstrapping approach:

1. **Minimal assembler kernel** — inner/outer interpreter, core ANS primitives, and platform I/O in optimised Z80 assembly
2. **Self-extending system** — higher-level words written in Forth itself, bootstrapping from the assembler kernel upward
3. **Interactive REPL** — immediate, on-device development with the full power of Forth's interpret/compile duality
4. **CP/M integration** — file loading/saving via CP/M 2.2 BDOS for source management on the ROM filesystem (A:) and ramdisk (B:)
5. **MicroBeast hardware words** — native Forth vocabulary for the LED displays and future expansion modules

Key technical foundations: direct threading (JP-based), XOR-rotate hashed vocabulary lookup (64 buckets), TOS-in-BC register optimisation, IX return stack, IY user pointer, and double-precision arithmetic.

### Key Differentiators

- **Purpose-built for MicroBeast** — native hardware support for the platform's unique I/O, displays, and future expansion cards (VideoBeast, AudioBeast) that no generic CP/M Forth can offer
- **ANS Forth compliance** — modern standard compliance (core wordset) vs the FIG-Forth/Forth-79 implementations typically available for CP/M
- **Performance-optimised Z80** — hashed dictionary lookup, TOS-in-register, and direct threading tuned for the MicroBeast's 8 MHz Z80
- **Extensible platform** — designed from day one as a foundation that grows with the MicroBeast ecosystem and community
- **Learning-driven quality** — built with deep understanding of both Forth and Z80, not just a mechanical port

## Target Users

### Primary Users

#### "The OG" — Experienced Retrocomputing Enthusiast

**Profile:** Seasoned programmer with 8-bit nostalgia or deep electronics background. Built their MicroBeast from the kit and probably helped others build theirs. Comfortable with Z80 assembly, familiar with CP/M, and may have used Forth before (or at least knows of it). Could be a hardware designer, games developer, firmware author, or all three.

**Current frustration:** The MicroBeast is capable hardware — 8 MHz Z80, 512K RAM, unique peripherals — but the software ecosystem is stuck in 1985. Developing anything interesting means cross-compiling on a modern PC, transferring, testing, repeating. There's no way to just sit at the machine and *build things* interactively.

**What antforth gives them:** An interactive development environment where they can prototype directly on the hardware. Poke I/O ports, test display routines on the 14-segment LEDs, move sprites on VideoBeast, define AudioBeast instruments — all from the REPL with immediate feedback. The built-in assembler means they can drop down to machine code when needed without leaving the environment. Drastically shortens the development cycle for PoCs before (optionally) taking learnings back to a cross-compiler.

**Success moment:** Sitting at the MicroBeast, typing a few lines to INCLUDE a Forth source file from the B: ramdisk, tweaking a word interactively, SAVEing it back — and realising they've done a full edit/test/persist cycle on the device itself, with no cross-compiler in the loop.

#### "The Newb" — Newcomer to Retrocomputing

**Profile:** Younger enthusiast drawn to retro computing culture. Built their MicroBeast kit as a learning experience and wants to understand "the old ways" — how computers really work at the hardware level. May have modern programming experience but limited Z80/assembly/Forth knowledge.

**Current frustration:** After the excitement of building the kit, the MicroBeast feels intimidating. CP/M is unfamiliar, Z80 assembly has a steep learning curve, and there's no gentle on-ramp to doing interesting things with the hardware they just built.

**What antforth gives them:** A welcoming interactive environment where they can start simple and build up. Forth's incremental nature — define a word, test it, build on it — is a natural teaching tool. Combined with a beginner's guide, antforth becomes the bridge between "I built a computer" and "I understand how computers work." The LED display provides immediate, tangible feedback for their first programs.

**Success moment:** Typing a few words at the REPL, seeing the 14-segment LEDs light up with their message, and realising they just programmed a computer at the bare metal — no OS, no framework, just them and the hardware.

### Secondary Users

#### Hardware/Peripheral Developers

The MicroBeast ecosystem creator and expansion module designers (VideoBeast, AudioBeast) benefit from antforth as a rapid prototyping and testing tool. While they overlap significantly with the OG persona, their specific use case — validating hardware designs and writing proof-of-concept drivers interactively — makes antforth particularly valuable for shortening the hardware development feedback loop.

### User Journey

1. **Discovery:** User hears about antforth through the MicroBeast community (forums, Discord, word of mouth from the creator)
2. **Onboarding:** Loads antforth from the CP/M filesystem. Greeted by a REPL prompt. A beginner's guide walks newcomers through their first words; OGs dive straight in
3. **First win:** Writes a simple word that interacts with the hardware — LED display output, port manipulation, or basic arithmetic. Immediate feedback, no compile cycle
4. **Core usage:** Builds up a personal library of words. Prototypes hardware interactions, games concepts, or utility programs. Loads source from and saves source to the CP/M filesystem (A: ROM, B: ramdisk) via INCLUDE and save words. Uses the built-in assembler for performance-critical sections
5. **Long-term value:** antforth becomes the default "turn on the MicroBeast and do something" environment. Personal word libraries grow and persist across sessions on disk. Community shares useful vocabularies. Platform expands as VideoBeast/AudioBeast support arrives

## Success Metrics

### Personal Learning Goals

- **Forth mastery:** Deep understanding of Forth internals through building an implementation from scratch — inner/outer interpreter, compiler, vocabulary management
- **Z80 assembly proficiency:** Significant improvement through writing performance-critical primitives, optimised hashing, and threading code
- **Measured by:** Completion of implementation milestones (these goals are inherently achieved through the building process)

### Technical Milestones

**Already achieved (Phases 1 + 2):**

1. ✅ **First sign of life** — outer interpreter parses and executes its first word (Phase 1)
2. ✅ **Bootstrapping threshold** — colon definitions work; new words definable in Forth itself (Phase 1)
3. ✅ **MVP complete** — interactive REPL with substantial portion of ANS Core wordset (Phase 1)
4. ✅ **Built-in Z80 assembler** — CODE words definable from within Forth (Epic 4)
5. ✅ **MARKER / system state snapshots** — state rollback operational (Epic 5)
6. ✅ **Shadow-register & code-size optimisations** — kernel performance and footprint tuning (Epics 6–8)
7. ✅ **Numeric literal prefixes** — Forth 2014 §3.4.1.3 + `0x` extension (Epic 9)
8. ✅ **Double-precision arithmetic + pictured numeric output** (Epic 10)
9. ✅ **Exception subsystem** — `CATCH` / `THROW` with all internal error paths migrated (Epic 11)
10. ✅ **Search-Order wordset / multi-vocabulary** — `WORDLIST`, `SEARCH-WORDLIST`, `GET-ORDER`, `SET-ORDER`, `FORTH-WORDLIST`, `GET-CURRENT`, `SET-CURRENT`, `DEFINITIONS`, `ONLY` (Epic 12)
11. ✅ **File-Access wordset** — `INCLUDE` / `OPEN-FILE` / `READ-FILE` / `WRITE-FILE` etc. on real CP/M 2.2 / MicroBeast hardware (Epic 13)
12. ✅ **§-level Core compliance back-fills** — §3.4.1.3 dot-marker parser rule + §3.1.4.1 high-on-TOS double-cell stack-layout (Stories 13.0 / 13.0.1)
13. ✅ **Phase-2 cleanup slate / process-recovery** — PD-1 workflow alignment + TD-1..TD-7 tag-blocking debt closure (Epic 13.5)
14. ✅ **antforth 2.0 SHIPPED** — git tag `v2.0.0` on commit `6599d73`, banner bumped, README updated, github release published (2026-05-07)

**Forward-looking (Phase 3 — debt cleanup interlude #2):**

Phase 3, like Epic 13.5, is dedicated to clearing accumulated debt before any net-new feature work. Specific milestones tracked in `docs/PHASE-3-CARRY-FORWARD.md`:

- **§-by-§ ANS Forth Core re-audit** — walk DPANS94 + Forth 2014 chapter-by-chapter; back-fill any structural-rule gaps surfaced (the framework that caught §3.4.1.3 / §3.1.4.1 mid-Epic-13 applied systematically)
- **Standalone compliance gaps** — caught-form coverage for asm-error THROW codes −258..−269; unprefixed `NUMBER?` base-specialization
- **Story-template / drafting-discipline cleanup** — PD-2 figure drift; "mirrors prior arm" HALT signal (Epic 13.5 A3); story-to-story binary-handoff `wc -c` discipline (Epic 13.5 A4); `PAD` documented as canonical transient-buffer for test authors (Epic 13.5 A2)
- **Process / tooling housekeeping** — PRD-vs-architecture transcription drift fix (PD-3); iz-cpm version stability (`make check-tools`, PD-6); test-numbering hygiene
- **Compliance / hardware** — NFR8 stress-matrix coverage gaps (directory-full, zero-byte READ-FILE; F-7); disk-full hardware re-verification

Specific story-level milestones for the Phase-3 epic(s) will be pinned down in the PRD that follows this brief.

### ANS Compliance Targets

**Current state (post-v2.0):**

- **Core wordset:** 100% coverage by both word count and §-level structural rules verified to date. Phase-3 §-by-§ re-audit may surface 0–2 additional structural gaps for back-fill (low likelihood, framework already proven).
- **Core Extension:** substantial coverage shipped — `."`, `\`, parenthesised comments, `SAVE-INPUT` / `RESTORE-INPUT` (user-facing as of TD-7), `MARKER`, `WITHIN`, etc.
- **Search-Order:** full §16.6.1 wordset + `ONLY` (§16.6.2) — shipped Epic 12
- **File-Access:** §11.6 wordset shipped Epic 13 (16 user-facing words: OPEN-FILE / CREATE-FILE / READ-FILE / WRITE-FILE / CLOSE-FILE / DELETE-FILE / FILE-POSITION / REPOSITION-FILE / FILE-SIZE / INCLUDED / INCLUDE-FILE / INCLUDE / R/O / R/W / W/O / BIN + SOURCE-ID / FILE-STATUS)
- **Exception:** §9.6.1 wordset (CATCH / THROW + standard codes) shipped Epic 11
- **Double-Number:** §8.6.1 wordset shipped Epic 10

**Phase 3 (compliance close-out):**

- Complete §-by-§ Core + Core-Extension re-audit; back-fill any §-level gaps; close standalone compliance gaps (NUMBER? base-spec, asm-error THROW caught-form coverage)

**Phase 4+ (deferred):**

- **Memory-Allocation wordset** — dynamic memory management
- **Locals wordset** — local variables (`{: a b -- c :}` or `VALUE` / `TO`)
- **Float wordset** — floating-point arithmetic
- **Programming-Tools** — `SEE` decompiler, `TRAVERSE-WORDLIST`, xref tools

### Community Success

- **Initial success:** Any MicroBeast community member other than the author using antforth
- **Current signal:** Mild community interest observed — a meaningful signal but not yet adoption
- **Growth indicator:** Community members sharing Forth word libraries or vocabularies
- **Stretch goal:** Adoption beyond MicroBeast to other Z80 retrocomputer platforms (leveraging inherent portability of the design)

### Business Objectives

N/A — antforth is a hobby/learning project with no commercial objectives. Value is measured in personal learning, community contribution, and the joy of building something from scratch.

### Key Performance Indicators

| Indicator | Target | Current |
|-----------|--------|---------|
| ANS Core wordset coverage | 100% | **100%** (with Phase-3 §-by-§ re-audit pending to verify §-level coverage) |
| REPL functional on MicroBeast hardware | Yes | **Yes** |
| Built-in Z80 assembler | Yes | **Yes** |
| MARKER / system rollback | Yes | **Yes** |
| CP/M file load/save operational | Yes | **Yes** (Epic 13, real hardware verified) |
| Search-Order (multi-vocabulary) operational | Yes | **Yes** (Epic 12) |
| Exception subsystem (CATCH/THROW) operational | Yes | **Yes** (Epic 11) |
| Double-precision arithmetic + pictured output | Yes | **Yes** (Epic 10) |
| §-by-§ ANS Core compliance audit complete | Yes | **Pending** (Phase-3 P1) |
| Phase-3 carry-forward catalogue closed | All P1 items closed | **Pending** (Phase-3 active scope) |
| MicroBeast hardware vocabulary exists | Yes | **Not yet** (Phase-4+ feature work) |
| At least one external user | 1+ community members | **0** (mild interest observed) |
| Portable to second Z80 platform | Stretch goal | **Not attempted** |

## MVP Scope

This brief scopes **Phase 3** of antforth, building on top of the already-shipped v2.0 foundation (Phases 1 + 2: kernel, REPL, language extension, Z80 assembler, MARKER, full ANS Core wordset, Exception subsystem, Search-Order, File-Access, Phase-2 cleanup slate). Phase 3 is **dedicated to clearing accumulated technical debt and closing standards-compliance gaps before any net-new feature work begins**. Like Epic 13.5 within Phase 2, Phase 3 is an interlude: zero new feature scope, no new user-facing words, all effort directed at making the v2.0 foundation production-defensible at the §-level.

The phase is structured as **one or more "debt-cleanup" epics** drawn from `docs/PHASE-3-CARRY-FORWARD.md` (the prioritised carry-forward catalogue authored 2026-05-07). Intermediate releases ship as **antforth 2.x** points. The phase concludes when the Phase-3 carry-forward catalogue's P1 items are closed and the §-level standards-compliance audit is complete.

### North-Star Acceptance Criterion (Phase 3)

**"AntForth's standards-compliance claims are §-level defensible, not word-counted."** This means: a systematic walk through DPANS94 and Forth 2014 chapter-by-chapter has been completed; any §-level structural-rule gaps surfaced have been back-filled with focused stories (mirroring the Epic-13 §3.4.1.3 / §3.1.4.1 back-fill template); the `docs/ans-forth-core-compliance.md` document carries a §-level-by-§-level row for every mandatory rule. The Epic-13 retro lesson — *"Epic 10's '100% Core' claim was word-counted, not §-counted"* — is closed by demonstration: the audit framework that caught two §-level blindspots mid-Epic-13 has been applied systematically across the entire Core + Core-Extension specification.

This north-star directly extends the project lead's verdict at the Epic 13.5 retro: *"AntForth feels more stable, and more 'defensible' from a standards point of view."*

### Core Features (Phase 3 active scope)

Phase 3's "features" are debt-discharge items, not user-facing words. The carry-forward catalogue at `docs/PHASE-3-CARRY-FORWARD.md` lists **12 P1 items in two categories**:

**Category A — Standards / Compliance (3 items):**
- A.1 — Systematic §-by-§ ANS Forth Core + Core-Extension re-audit (the strategic Phase-3 piece; 1 audit story + 0–2 back-fill stories per gap surfaced)
- A.2 — Caught-form coverage gap for asm-error THROW codes −258..−269 (test-only; ½-story; can hitch-hike)
- A.3 — Unprefixed `NUMBER?` base-specialization (small; standalone)

**Category B — Stabilisation / Process Debt (9 items):**
- B.1 — Document `PAD` as canonical transient-buffer word for test authors (Epic-13.5 A2; closes belated Epic-12 retro A1; doc-only)
- B.2 — "Mirrors prior arm" drafting HALT signal in story-template (Epic-13.5 A3; small template edit)
- B.3 — Story-to-story binary handoff: re-`wc -c` at next story start (Epic-13.5 A4; small template edit)
- B.4 — PD-2 story-drafter figure drift (Epic-13 retro #1; medium template/process)
- B.5 — PD-3 PRD-vs-architecture transcription drift fix (Epic-13 retro #2; medium process/Makefile)
- B.6 — PD-6 iz-cpm version stability (`make check-tools`, small)
- B.7 — F-7 NFR8 stress-matrix coverage gaps (directory-full, zero-byte READ-FILE; ~1 story; conditional on hardware-revealed issues)
- B.8 — Test-numbering hygiene (Makefile duplicate test numbers from Story 11.3; cosmetic)
- B.9 — Disk-full hardware re-verification on real CP/M 2.2 (small hardware test)

**Suggested first-epic shape** (mirroring Epic-13.5's PD-1-first sequencing pattern):
- **Lead-in (must land first):** B.1 + B.2 + B.3 + B.4 + B.5 — story-template / process-discipline edits that shape every subsequent dev-pass in the epic
- **Strategic body:** A.1 §-by-§ Core re-audit — one audit story + 0–2 back-fill stories per gap
- **Hitch-hikers:** A.2, A.3, B.6, B.8, B.9 fold into appropriate stories opportunistically
- **Conditional:** B.7 if hardware-revealed issues surface; otherwise 2.x maintenance

The exact epic decomposition will be pinned down in the PRD that follows this brief.

### Out of Scope for Phase 3 (Deferred)

**No new feature work.** All of the following are explicitly deferred to Phase 4 or later:

- **Banked RAM awareness** — strategic enabler for growing past the ~25KB binary ceiling without sacrificing built-in surface (see `docs/antforth-banking-design.md`)
- **STARTUP.FTH** — boot-time auto-load of user library
- **MicroBeast hardware vocabulary** — 14-segment LED display, system timer ISR, GPIO, beeper, UART, I2C, RTC, memory-banking control
- **Cooperative multitasker** + **semaphores** — `PAUSE` / `TASK` / `ACTIVATE`; `SIGNAL` / `WAIT`
- **Z80 IN / OUT primitives**
- **Locals wordset** (`{: a b -- c :}` or `VALUE` / `TO`)
- **`SEE` decompiler** + **`TRAVERSE-WORDLIST`** (and Forth-side xref tools they enable)
- **Memory-Allocation wordset** (dynamic memory management)
- **Float wordset**
- **Programming-Tools extensions** beyond what the §-by-§ audit may surface
- **Compilation to standalone `.com` binary** (turnkey Forth apps)
- **Object orientation** (NEON / Yerk / FOBJ-style)
- **Beginner's guide + per-wordset reference docs** (deferred until feature surface stabilises further; some doc work may land opportunistically alongside Phase-3 stories)
- **VideoBeast / AudioBeast support**
- **Tooling beyond stabilisation** — `make bench` infrastructure, ROM-pressure-only optimisations (`.S` migration to pictured output, DMA pool size-reduction)

Rationale for deferral: Phase 3's job is to stabilise the v2.0 foundation, not extend it. Every feature epic adds new debt; Phase 3 exists to keep that ratio honest. Project lead direction at the Epic 13.5 retro: *"I am trying to clear the decks of baggage, before we embark on new features."*

### MVP Success Criteria (Phase 3)

Phase 3 is successful (and a v2.x close-out tag becomes a candidate) when ALL of the following hold:

- **§-by-§ ANS Forth Core + Core-Extension audit complete** — `docs/ans-forth-core-compliance.md` carries §-level rows; any gaps surfaced are back-filled or explicitly accepted-with-rationale (per `feedback_no_preexisting_discharge.md` correctness defects must be closed, not rationalised)
- **All P1 items in `docs/PHASE-3-CARRY-FORWARD.md` closed** (or explicitly re-prioritised down with project-lead approval)
- **Story-template / drafting-discipline cleanup landed** (B.1–B.5; the next epic's stories should not re-discover any of the Epic-13.5 retro's six lessons)
- **All 12 standing process commitments (S1–S12)** continue to hold across the Phase-3 epic(s) — eleventh-plus consecutive epic with adversarial review surfacing things via fresh-context CR; no PARTIAL ships; no "pre-existing" discharge for correctness defects; mid-epic hardware-smoke per story; user-visible version surface audit row at any tag-applicable close-out; hardware-typed probe authoring discipline (word-existence + TIB-128 line-length lint)
- **Existing test suites continue to pass** — 973 PASS / 0 FAIL baseline maintained or extended; zero regressions on 1..952 baseline
- **Hardware smoke continues clean** on real CP/M 2.2 / MicroBeast for any binary-delta story
- **Phase-3 cumulative ROM delta is small** — Phase 3 is debt discharge, not feature work; net-positive byte delta should be modest (estimate +0..+200 bytes for the catalogue close-out, dominated by any §-level back-fill stories surfaced)

### Future Vision

**Phase 4 (next feature phase, post-v2.x):**

Phase 4 is the first feature phase since v2.0 and is unscoped at this brief's writing — to be defined when Phase 3 closes. Candidate themes (drawn from `docs/PHASE-3-CARRY-FORWARD.md` category E and `docs/WISHLIST.md`), in rough order of strategic interest:

- **Banked RAM awareness** — the strategic enabler. Available user RAM is getting tight as antforth grows; the banking design (`docs/antforth-banking-design.md`) proposes bank swapping to make more memory available to users without sacrificing the core wordset or built-in assembler. Likely the first Phase-4 epic.
- **STARTUP.FTH** — small but high-value affordance: a file that, if present, runs at startup before the interactive REPL. Allows loading custom wordlists, beginner-friendly setup, etc.
- **MicroBeast hardware vocabulary** — system timer ISR, GPIO, 24×14-segment LED matrix, beeper, UART, I²C, memory-banking control, RTC, anything else board-specific. Strong fit with the multitasker via timer-driven `PAUSE`. Closes the gap between "antforth runs on MicroBeast" and "antforth makes the MicroBeast's hardware accessible".

**Medium-term (Phase 5+):**

- **Cooperative multitasker** — PAUSE-based task yielding, with `KEY` integration so the REPL multitasks for free; `TASK` / `ACTIVATE`; system-timer ISR integration
- **Semaphores** — `SIGNAL` / `WAIT`, mutexes, mailbox primitives
- **`SEE` decompiler** + **`TRAVERSE-WORDLIST`** — enables xref tools and integrity checkers written in Forth itself
- **Locals wordset** and/or `VALUE` / `TO`
- **Built-in IN/OUT primitives**
- **User-facing documentation** — beginner's guide, per-wordset reference, worked examples (now justified by a stable feature surface)

**Long-term:**

- **Turnkey compilation to `.com` binary** — standalone Forth apps, possibly with tree-shaking
- **VideoBeast support** — sprite manipulation, graphics primitives
- **AudioBeast support** — instrument definition, sound generation
- **Float wordset**
- **Object orientation** — after reading Pountain (book acquired); study NEON / Yerk and FOBJ
- **Community word library sharing**
- **Portability to other Z80 retrocomputer platforms**
