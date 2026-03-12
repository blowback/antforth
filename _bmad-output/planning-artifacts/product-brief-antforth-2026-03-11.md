---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - "Fast word lookup for Z80 Forth interpreter.json"
date: 2026-03-11
author: Ant
---

# Product Brief: antforth

<!-- Content will be appended sequentially through collaborative workflow steps -->

## Executive Summary

antforth is an ANS-compliant Forth interpreter for the MicroBeast Z80 retrocomputer, built from scratch in Z80 assembly language. It transforms the MicroBeast from a machine limited to decades-old CP/M software into an interactive, extensible development platform. By providing a modern Forth REPL with native support for MicroBeast-specific hardware (14-segment LED displays, and future VideoBeast/AudioBeast expansion cards), antforth gives MicroBeast owners a powerful on-device programming environment that no existing CP/M Forth can offer.

The project follows Forth's bootstrapping philosophy: a minimal, performance-optimised Z80 assembler kernel provides the inner/outer interpreter and core primitives, from which the rest of the system is built in Forth itself. Key technical decisions include direct threading, XOR-rotate hashed vocabulary lookup with 64 buckets, TOS-in-register optimisation, and full double-precision arithmetic for ANS compliance.

antforth is initially a personal learning project — an opportunity to deepen expertise in both Forth and Z80 assembly — with the intention of sharing with the broader MicroBeast hobbyist community once mature.

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

**Success moment:** Writing a Forth word that drives a piece of MicroBeast hardware, testing it instantly, refining it in real-time — and realising they've done in 20 minutes what would have taken an afternoon of cross-compile cycles.

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
4. **Core usage:** Builds up a personal library of words. Prototypes hardware interactions, games concepts, or utility programs. Saves and loads source files from the ramdisk. Uses the built-in assembler for performance-critical sections
5. **Long-term value:** antforth becomes the default "turn on the MicroBeast and do something" environment. Personal word libraries grow. Community shares useful vocabularies. Platform expands as VideoBeast/AudioBeast support arrives

## Success Metrics

### Personal Learning Goals

- **Forth mastery:** Deep understanding of Forth internals through building an implementation from scratch — inner/outer interpreter, compiler, vocabulary management
- **Z80 assembly proficiency:** Significant improvement through writing performance-critical primitives, optimised hashing, and threading code
- **Measured by:** Completion of implementation milestones (these goals are inherently achieved through the building process)

### Technical Milestones

1. **First sign of life:** Outer interpreter successfully parses and executes its first word
2. **Bootstrapping threshold:** Colon definitions work — can define new words in Forth itself
3. **MVP complete:** Interactive REPL with ANS Core wordset operational on MicroBeast
4. **Platform integration:** MicroBeast-specific hardware words (LED display, I/O ports) functional
5. **Self-sustaining:** System is useful enough to develop further extensions in Forth itself

### ANS Compliance Targets

**Phase 1 (Core):**
- Core wordset — the foundation for ANS compliance
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
- **Growth indicator:** Community members sharing Forth word libraries or vocabularies
- **Stretch goal:** Adoption beyond MicroBeast to other Z80 retrocomputer platforms (leveraging inherent portability of the design)

### Business Objectives

N/A — antforth is a hobby/learning project with no commercial objectives. Value is measured in personal learning, community contribution, and the joy of building something from scratch.

### Key Performance Indicators

Given the hobby nature of the project, formal KPIs are replaced by milestone-based progress tracking:

| Indicator | Target |
|-----------|--------|
| Core wordset implementation | 100% of ANS Core words |
| REPL functional on MicroBeast hardware | Yes/No |
| CP/M file load/save operational | Yes/No |
| MicroBeast hardware vocabulary exists | Yes/No |
| At least one external user | 1+ community members |
| Portable to second Z80 platform | Stretch goal |

## MVP Scope

### Core Features

**1. Inner/Outer Interpreter**
- Direct-threaded inner interpreter (JP-based, NEXT/DOCOL/EXIT)
- Outer interpreter with text parsing, number recognition, interpret/compile mode switching
- Register allocation: HL=W, DE=IP, SP=parameter stack, IX=return stack, IY=user pointer, BC=TOS

**2. ANS Core Wordset (Single-Precision Subset)**
- Stack operations (DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH, etc.)
- Arithmetic (+, -, *, /, MOD, /MOD, NEGATE, ABS, MIN, MAX, etc.)
- Comparison (=, <, >, 0=, 0<, U<, etc.)
- Logic (AND, OR, XOR, INVERT, LSHIFT, RSHIFT)
- Memory access (@, !, C@, C!, +!, FILL, MOVE, etc.)
- Control flow (IF/ELSE/THEN, BEGIN/WHILE/REPEAT, BEGIN/UNTIL, DO/LOOP/+LOOP, LEAVE)
- Compiler words (: ; IMMEDIATE POSTPONE LITERAL [ ] CREATE DOES> VARIABLE CONSTANT)
- I/O primitives (EMIT, KEY, KEY?, TYPE, CR, SPACE, SPACES, ., .S, U.)
- String support (COUNT, WORD, FIND, >NUMBER, ACCEPT)
- Dictionary (HERE, ALLOT, COMMA, C,, ALIGN, ALIGNED)
- Double-precision arithmetic deferred to post-MVP

**3. Interactive REPL**
- CP/M console I/O via BDOS calls
- Line input with ACCEPT
- Interpret/compile loop with standard "ok" prompt
- Error handling (undefined word, stack underflow, etc.)

**4. Memory Allocation Wordset**
- ALLOCATE, FREE, RESIZE
- Dynamic memory management within available RAM

**5. Vocabulary Lookup**
- XOR-rotate hash with 64 buckets (single vocabulary for MVP)
- Hash-linked dictionary entries for fast word lookup

**6. Built-in Assembler**
- Reverse-polish Z80 assembler words
- Ability to define CODE words from within Forth
- Essential for users extending the system with machine-code primitives

**7. Platform Foundation**
- CP/M 2.2 application (.COM file) loadable from A: or B: drive
- Standard CP/M terminal I/O
- MARKER for system state snapshots and rollback

### Out of Scope for MVP

- **Double-precision arithmetic** — deferred; single-precision sufficient for initial use
- **Search-Order wordset** — MVP ships with single flat vocabulary; multi-vocabulary support added shortly after
- **File-Access wordset** — INCLUDE/source file loading follows MVP within weeks
- **MicroBeast hardware words** — LED display, I/O port vocabularies come after core is stable
- **VideoBeast/AudioBeast support** — future expansion module support
- **Float wordset** — later phase
- **Exception wordset** — later phase
- **Locals wordset** — later phase
- **Beginner's guide / documentation** — after the system is stable and feature-complete enough to teach with

### MVP Success Criteria

- Outer interpreter parses and executes words correctly
- Colon definitions work — new words can be defined and called in Forth
- Built-in assembler can define CODE words
- REPL is usable interactively on MicroBeast hardware via CP/M console
- Core wordset passes basic functional tests (stack ops, arithmetic, control flow, memory)
- MARKER can snapshot and restore system state
- System is stable enough to begin writing higher-level words in Forth itself (bootstrapping threshold reached)

### Future Vision

**Near-term (post-MVP):**
- Search-Order wordset — multiple vocabularies with hash tables per vocabulary
- File-Access wordset — INCLUDE, source file loading/saving from CP/M filesystem
- Double-precision arithmetic for full ANS Core compliance
- FORGET (simplified, current vocabulary only, complementing MARKER)

**Medium-term:**
- MicroBeast hardware vocabulary — 14-segment LED display words, I/O port access
- Exception wordset
- Locals wordset
- Beginner's guide to AntForth on MicroBeast

**Long-term:**
- VideoBeast support — sprite manipulation, graphics primitives in Forth
- AudioBeast support — instrument definition, sound generation words
- Float wordset
- Community word library sharing
- Portability to other Z80 retrocomputer platforms
- Potential for the MicroBeast community to build games, demos, and hardware PoCs entirely in Forth
