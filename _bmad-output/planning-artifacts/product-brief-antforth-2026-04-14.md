---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - "_bmad-output/planning-artifacts/product-brief-antforth-2026-03-11.md"
date: 2026-04-14
author: Ant
---

# Product Brief: antforth

<!-- Content will be appended sequentially through collaborative workflow steps -->

## Executive Summary

antforth is an ANS-compliant Forth interpreter for the MicroBeast Z80 retrocomputer, built from scratch in Z80 assembly language. It transforms the MicroBeast from a machine limited to decades-old CP/M software into an interactive, extensible development platform. By providing a modern Forth REPL with native support for MicroBeast-specific hardware (14-segment LED displays, and future VideoBeast/AudioBeast expansion cards), antforth gives MicroBeast owners a powerful on-device programming environment that no existing CP/M Forth can offer.

The project follows Forth's bootstrapping philosophy: a minimal, performance-optimised Z80 assembler kernel provides the inner/outer interpreter and core primitives, from which the rest of the system is built in Forth itself. Key technical decisions include direct threading, XOR-rotate hashed vocabulary lookup with 64 buckets, TOS-in-register optimisation, and full double-precision arithmetic for ANS compliance. As of this brief, the kernel, outer interpreter, built-in Z80 assembler, MARKER, and a substantial portion of the ANS Core wordset are operational; this brief scopes the next wave of functionality to be added on top of that foundation.

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

**Already achieved (prior phases):**

1. ✅ **First sign of life** — outer interpreter parses and executes its first word
2. ✅ **Bootstrapping threshold** — colon definitions work; new words definable in Forth itself
3. ✅ **MVP complete** — interactive REPL with a substantial portion of the ANS Core wordset operational
4. ✅ **Built-in Z80 assembler** — CODE words definable from within Forth (Epic 4)
5. ✅ **MARKER / system state snapshots** — state rollback operational (Epic 5)
6. ✅ **Shadow-register & code-size optimisations** — kernel performance and footprint tuning (Epics 6–8)

**Forward-looking (this phase and beyond):**

- **ANS Core completion** — drive Core wordset coverage from 86% toward full compliance
- **File-Access wordset** — INCLUDE and source save/load against the CP/M filesystem
- **Search-Order wordset** — multiple vocabularies with per-vocabulary hash tables
- **Platform integration** — MicroBeast hardware vocabulary (14-segment LED display, I/O ports)
- Specific story-level milestones for the above will be pinned down in the MVP Scope section.

### ANS Compliance Targets

**Current state:** ~86% of the ANS Forth Core wordset is implemented. This phase is expected to improve Core coverage substantially, and to make meaningful progress into the extended wordsets.

**Phase 1 (Core + near-Core):**

- Core wordset — drive from 86% to 100% coverage
- Memory-Allocation wordset — dynamic memory management
- Search-Order wordset — vocabulary and wordlist management

**Phase 2 (Extended):**

- File-Access wordset — CP/M file integration
- Double wordset — double-precision number support
- Exception wordset — structured error handling
- Float wordset — floating-point arithmetic
- Locals wordset — local variables

### Community Success

- **Initial success:** Any MicroBeast community member other than the author using antforth
- **Current signal:** Mild community interest observed — a meaningful signal but not yet adoption
- **Growth indicator:** Community members sharing Forth word libraries or vocabularies
- **Stretch goal:** Adoption beyond MicroBeast to other Z80 retrocomputer platforms (leveraging inherent portability of the design)

### Business Objectives

N/A — antforth is a hobby/learning project with no commercial objectives. Value is measured in personal learning, community contribution, and the joy of building something from scratch.

### Key Performance Indicators

Given the hobby nature of the project, formal KPIs are replaced by milestone-based progress tracking:

| Indicator | Target | Current |
|-----------|--------|---------|
| ANS Core wordset coverage | 100% | 86% |
| REPL functional on MicroBeast hardware | Yes | Yes |
| Built-in Z80 assembler | Yes | Yes |
| MARKER / system rollback | Yes | Yes |
| CP/M file load/save operational | Yes | Not yet |
| Search-Order (multi-vocabulary) operational | Yes | Not yet |
| MicroBeast hardware vocabulary exists | Yes | Not yet |
| At least one external user | 1+ community members | 0 (mild interest observed) |
| Portable to second Z80 platform | Stretch goal | Not attempted |

## MVP Scope

This brief scopes the **next phase** of functionality, built on top of the already-shipped foundation (kernel, REPL, language extension, Z80 assembler, MARKER, compliance survey, optimisation epics 1–8). The phase pursues **two mutually reinforcing goals**: reaching **100% ANS Forth Core compliance** (the headline win for prospective users and for the project's credibility) and unlocking **on-device source development via the CP/M filesystem** (the personal north star — the OG's success moment).

The phase is structured as **five sequential epics** (9 through 13), each a standalone value delivery. Intermediate releases ship as **antforth 1.x**; the phase concludes with **antforth 2.0**, in which the kernel no longer ships the assembler opcodes in ROM — they are lazy-loaded from disk on first use.

### North-Star Demo (antforth 2.0)

**A fresh boot of antforth loads with the assembler opcodes absent from the dictionary. The user types `CODE`. The system looks up `CODE`, discovers the ASSEMBLER wordlist is unpopulated, reads `ASSEMBLER.FTH` from the A: drive via `INCLUDED`, populates the ASSEMBLER wordlist, and execution continues transparently — the user sees only a tiny load pause.** This single demo exercises hex/binary literals (opcode constants), Core-gap words, CATCH/THROW (file-not-found path), Search-Order (`ASSEMBLER` wordlist auto-activation inside `CODE`/`END-CODE`), and File-Access (the load itself). Shipping this demo is the phase's acceptance criterion and tags the 2.0 release.

### Epics

#### Epic 9 — Numeric Literal Prefixes

Adopt Forth 2014 §3.4.1.3 in full, plus an antforth-specific `0x` extension:

| Form | Radix | Example |
|---|---|---|
| `<BASEnum>` | current BASE | `1234` |
| `#<decnum>` | 10 (decimal) | `#1234` |
| `$<hexnum>` | 16 (hex) | `$FF` |
| `%<binnum>` | 2 (binary) | `%1010` |
| `'<char>'` | value of `<char>` | `'A'` → 65 |
| `0x<hexnum>` | 16 (hex) | `0xFF` *(antforth extension — C-family familiarity)* |

- All forms support optional leading `-` per the standard
- All prefixes case-insensitive (`0X`, `0xFF`, `$ff`, `%1010` / `%0` all accepted)
- `BASE` is not mutated by parsing — each literal stands alone
- Applies system-wide: interpreter, compiler, and the built-in Z80 assembler
- Deliberately first in the phase: every subsequent epic's test scripts and opcode tables become more readable immediately

#### Epic 10 — ANS Core Compliance to 100%

- **Double-precision arithmetic:** `D+`, `D-`, `D*`, `DNEGATE`, `DABS`, `D<`, `D=`, `DMAX`, `DMIN`, `2@`, `2!`, `2DUP`, `2DROP`, `2SWAP`, `2OVER`, `M*`, `UM*`, `M+`, `SM/REM`, `FM/MOD`, `UM/MOD`, `>D`, `S>D`, `D>S`
- **Pictured numeric output:** `<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`, `HOLDS`; `.`, `U.`, `D.`, `U.R`, `.R`, `D.R` reimplemented on top
- **All remaining Core gap words** as enumerated by `docs/ans-forth-core-compliance.md`
- **Success criterion: 100% ANS Forth Core compliance** — the survey coverage figure must read 100% by the epic's close.

#### Epic 11 — Exception Wordset (CATCH / THROW)

- `CATCH`, `THROW`, and the ANS standard throw codes
- **All internal error paths migrated through the exception mechanism** — stack underflow, undefined word, division by zero, compile-state errors, and any future error site. A part-time exception system is worse than no exception system; this epic is not done until every internal error goes through THROW.
- Existing `ABORT`/`ABORT"` retargeted as `-1 THROW` / `-2 THROW` per the standard
- User code can now handle error conditions instead of always aborting the REPL

#### Epic 12 — Search-Order Wordset

- `WORDLIST`, `SEARCH-WORDLIST`, `GET-ORDER`, `SET-ORDER`, `GET-CURRENT`, `SET-CURRENT`, `DEFINITIONS`, `ONLY`, `FORTH-WORDLIST`
- Multiple vocabularies with per-vocabulary hash tables (the existing XOR-rotate 64-bucket scheme generalised)
- **Assembler opcodes migrate into a dedicated `ASSEMBLER` wordlist that is auto-activated inside `CODE`/`END-CODE` and deactivated afterwards.** Existing CODE-word source files must continue to assemble correctly — this is the epic's hardest AC.
- **Authorship of `ASSEMBLER.FTH`** (whether generated from the existing `src/assembler.asm`, hand-migrated, or produced by a build-time tool) is a story within this epic — the Forth-source form of the ASSEMBLER wordlist must exist by end of Epic 12 so Epic 13 can load it.

#### Epic 13 — File-Access Wordset (culminates in antforth 2.0)

- `INCLUDE`, `INCLUDE-FILE`, `INCLUDED`, `OPEN-FILE`, `CLOSE-FILE`, `READ-FILE`, `WRITE-FILE`, `CREATE-FILE`, `DELETE-FILE`, `FILE-POSITION`, `REPOSITION-FILE`, `FILE-SIZE`, `R/O`, `R/W`, `W/O`, `BIN`
- CP/M 2.2 BDOS integration for source load/save against A: (ROM filesystem) and B: (ramdisk)
- File errors raise through `THROW` (leveraging Epic 11), not ABORT
- **Final story — ASSEMBLER lazy-load (antforth 2.0):** the kernel boots *without* assembler opcodes resident. First mention of `CODE` triggers `INCLUDED` of `ASSEMBLER.FTH` from A:, populating the `ASSEMBLER` wordlist on demand. There is no dual kernel and no conditional flag — this is the new default and only boot behaviour. Kernel ROM shrinks; the system justifies its own new infrastructure; **antforth 2.0 ships**.

### Out of Scope for This Phase (Deferred)

Explicitly deferred to a later phase:

- **Locals wordset** (`{: a b -- c :}`, `VALUE`, `TO`)
- **Built-in IN/OUT primitives** — still possible via CODE words
- **SEE decompiler** and **TRAVERSE-WORDLIST**
- **MicroBeast hardware vocabulary** (14-segment LED display words, I/O port access)
- **Cooperative multitasker** (`PAUSE` / `TASK` / `ACTIVATE`) and **semaphores**
- **Float wordset**
- **VideoBeast / AudioBeast support**
- **Compilation to standalone `.com` binary** (tree-shaken Forth apps)
- **Object orientation** (NEON / Yerk / FOBJ-style)
- **User-facing documentation (all of it)** — beginner's guide, per-wordset usage docs, reference material. Deferred until the feature surface is stable. *("Until we've finished adding features.")*

Rationale for deferral: each is either a significant subsystem in its own right, depends on infrastructure not yet present, or is orthogonal to the ANS-compliance + on-device-development axis that defines this phase.

### MVP Success Criteria

The phase is successful (antforth 2.0 ships) when ALL of the following hold:

- **100% ANS Forth Core wordset compliance** as measured by `docs/ans-forth-core-compliance.md` methodology
- **Numeric literal prefixes per Forth 2014 §3.4.1.3 + the `0x` extension** accepted system-wide
- **Double-precision integers** and **pictured numeric output** fully operational
- **CATCH / THROW** operational, with **every** internal error path migrated through the exception mechanism
- **Multiple vocabularies** operational; the **`ASSEMBLER` wordlist** auto-activates inside `CODE`/`END-CODE`; all existing CODE-word source files continue to assemble correctly
- **`INCLUDE` loads a source file** from the CP/M filesystem; source can be saved back to B:
- **The north-star demo passes end-to-end**: assembler opcodes absent from a fresh boot, `CODE` triggers a transparent on-demand load of `ASSEMBLER.FTH` from A:, and subsequent CODE-word definitions assemble as before
- All new functionality exercised by REPL-piped Forth test scripts (per project testing conventions)
- Existing test suites from Epics 1–8 continue to pass

### Future Vision

**Near-term (post-2.0):**
- **User-facing documentation** — beginner's guide to antforth on MicroBeast, per-wordset reference, worked examples. Now justified by a stable feature surface.
- **MicroBeast hardware vocabulary** — 14-segment LED display words, I/O port access, built on top of the new ASSEMBLER wordlist and the new file-load workflow
- **Locals wordset** and/or `VALUE` / `TO`
- **SEE decompiler** + `TRAVERSE-WORDLIST` — enables xref tools and integrity checkers written in Forth itself
- **Built-in IN/OUT primitives**

**Medium-term:**
- **Cooperative multitasker** — PAUSE-based task yielding, with `KEY` integration so the REPL multitasks for free; `TASK` / `ACTIVATE` Task Control Blocks; system-timer ISR integration
- **Semaphores** — `SIGNAL` / `WAIT`, mutexes, mailbox primitives
- **Exception wordset extensions** beyond Core

**Long-term:**
- **VideoBeast support** — sprite manipulation, graphics primitives
- **AudioBeast support** — instrument definition, sound generation
- **Float wordset**
- **Compilation to `.com` binary** — standalone apps, possibly with tree-shaking
- **Object orientation** — after reading Pountain; study NEON / Yerk and FOBJ
- **Community word library sharing**
- **Portability to other Z80 retrocomputer platforms**
