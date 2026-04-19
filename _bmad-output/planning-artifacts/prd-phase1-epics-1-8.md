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
inputDocuments:
  - product-brief-antforth-2026-03-11.md
documentCounts:
  briefCount: 1
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 0
classification:
  projectType: developer_tool_embedded
  domain: general
  complexity: low
  projectContext: greenfield
workflowType: 'prd'
---

# Product Requirements Document - antforth

**Author:** Ant
**Date:** 2026-03-11

## Executive Summary

antforth is an ANS-compliant Forth interpreter and interactive development environment for the MicroBeast Z80 retrocomputer, written from scratch in Z80 assembly. It provides an on-device REPL that transforms the MicroBeast from a platform limited to legacy CP/M software into a machine you can sit at and build things interactively — prototyping hardware interactions, defining words, and extending the system in real time with no cross-compile cycle.

The system follows Forth's bootstrapping philosophy: a minimal, performance-optimised Z80 assembler kernel (direct threading, TOS-in-register, XOR-rotate hashed dictionary lookup) provides the inner/outer interpreter and core primitives, from which the rest of the system is built in Forth itself. The target is ANS Core wordset compliance, with a built-in reverse-polish Z80 assembler for defining CODE words when users need to drop to machine level.

antforth is a personal learning project — an excuse to go deep on both Forth internals and Z80 assembly — built with the intention of sharing with the MicroBeast hobbyist community once mature. It targets two audiences: experienced retrocomputing enthusiasts who want a productive on-device development tool, and newcomers who want an interactive, approachable way to learn how computers work at the bare metal.

## What Makes This Special

antforth exists because Forth is fascinating and building it from scratch is the point. Rather than porting an existing Forth implementation (a dry exercise), antforth is purpose-built for MicroBeast by someone with genuine enthusiasm for stack-based languages and the elegance of Forth's model. This produces an implementation optimised for the specific hardware — 8 MHz Z80, 512K banked RAM/ROM, 14-segment LED displays — with a design path toward future VideoBeast and AudioBeast expansion support that no generic CP/M Forth could offer.

Forth sits in the perfect sweet spot for this hardware: just above Z80 assembly, compact and elegant enough for an 8-bit machine, interactive enough to make on-device development genuinely enjoyable, and extensible enough to grow with the platform. The satisfaction comes from having built the whole thing — from NEXT to the outer interpreter to the REPL — and the learning is inseparable from the product.

## Project Classification

- **Project Type:** Developer tool / embedded system — a programming language implementation and interactive development environment running on dedicated hardware
- **Domain:** General (hobby/retrocomputing) — no regulatory or compliance concerns
- **Complexity:** Low (domain) — personal hobby project; technical complexity is high but domain complexity is minimal
- **Project Context:** Greenfield — built entirely from scratch

## Success Criteria

### User Success

- **First REPL interaction:** The system boots on MicroBeast hardware, presents a prompt, and correctly executes typed words with immediate feedback — the first real "it works" moment
- **Bootstrapping threshold:** Colon definitions work — the user can define new words in Forth and call them, unlocking the self-extending nature of the language
- **Self-sustaining development:** The system is stable and complete enough that extending it further happens in Forth itself, not just in the assembler kernel
- **Community usability:** At least one MicroBeast community member other than the author can load antforth, follow a guide, and do something useful with it

### Business Success

N/A — antforth is a hobby/learning project with no commercial objectives. Value is measured in personal learning, community contribution, and the joy of building something from scratch.

### Technical Success

- **ANS Core wordset compliance:** 100% of ANS Core words implemented and functionally correct (single-precision; double-precision deferred to post-MVP)
- **Correctness over speed:** All primitives produce correct results. Performance optimisation is welcome but never at the expense of correctness
- **Stability:** The REPL does not crash during normal interactive use — stack underflow, undefined words, and other errors are handled gracefully
- **Built-in assembler functional:** CODE words can be defined from within Forth using the reverse-polish Z80 assembler

### Measurable Outcomes

| Outcome | Target | Phase |
|---------|--------|-------|
| REPL runs on MicroBeast hardware | Yes | MVP |
| Colon definitions work | Yes | MVP |
| ANS Core wordset complete (single-precision) | 100% | MVP |
| Built-in Z80 assembler operational | Yes | MVP |
| MARKER snapshot/restore works | Yes | MVP |
| CP/M file load/save (INCLUDE) | Yes | Post-MVP |
| At least one external user | 1+ | Post-MVP |
| MicroBeast hardware vocabulary (LEDs, I/O) | Yes | Growth |
| Community sharing word libraries | Stretch | Vision |

## User Journeys

### Journey 1: The OG — A Productive Evening

**Dave**, 52, hardware engineer. Built his MicroBeast from the kit on a rainy weekend last year. He's got 30 years of embedded experience and a shelf of Forth books from the 80s. He's been cross-compiling Z80 assembly on his laptop and transferring via serial — functional, but joyless.

**Opening Scene:** Dave sits down at his MicroBeast after dinner. He's been thinking about a scrolling text routine for the 14-segment displays all day. He loads antforth from the A: drive. The familiar `ok` prompt appears.

**Rising Action:** He starts at the bottom — a word to write a single character to the display register. He types it at the REPL, tests it immediately. It works. He builds upward: a word to write a string, then one to scroll. Each layer takes minutes, not the hour-long cross-compile cycle he's used to. When his scroll timing is wrong, he redefines the delay word and tests again instantly.

**Climax:** Twenty minutes in, he types `S" HELLO MICROBEAST" SCROLL` and watches his message glide across the LEDs. He grins. He's done more in twenty minutes than an evening of cross-development would have achieved.

**Resolution:** Dave saves his display library to the B: ramdisk. Over the following weeks, his personal word library grows. The MicroBeast stops being a project he occasionally transfers code to and becomes a machine he *uses*. When VideoBeast arrives, he already knows exactly how he'll extend his vocabulary.

### Journey 2: The Newb — First Contact

**Mia**, 24, web developer. She backed the MicroBeast on a whim because she'd never built hardware before. The kit assembly was thrilling. But now it's sitting on her desk running CP/M, and she doesn't know what to do with it. She's never written assembly or used Forth.

**Opening Scene:** Mia sees a post on the MicroBeast Discord: "Try antforth — here's a beginner's guide." She loads it from the A: drive. A prompt appears. She types `2 3 + .` and sees `5 ok`. Her first bare-metal program.

**Rising Action:** Following the guide, she learns about the stack — `DUP`, `SWAP`, `.S` to peek at it. She defines her first word: `: SQUARE DUP * ;`. She types `7 SQUARE .` and sees `49`. Something clicks — she just *extended the language*. She defines `CUBE` using `SQUARE`. The bootstrapping nature of Forth starts making sense.

**Climax:** She writes a word that prints her name to the 14-segment LEDs. The physical display lights up with letters she put there — no framework, no browser, no abstraction. Just her and the hardware.

**Resolution:** Mia starts actually understanding how computers work at the register level. She tries `CODE` words with the assembler, stumbles, asks questions on Discord. antforth becomes the bridge between "I built a computer" and "I understand computers." She's hooked.

### Journey 3: The OG — When Things Go Wrong

**Dave** again, a few weeks later. He's building a more ambitious word — a memory dump utility. He's pushing the system harder now.

**Opening Scene:** Dave is deep in a session, defining nested words. He makes a typo in a colon definition — references a word that doesn't exist.

**Rising Action:** antforth catches the undefined word and reports the error clearly. The partial definition is discarded — no dictionary corruption. Dave fixes the typo and redefines. He then accidentally underflows the stack in a test. Again, a clear error message, no crash. He uses `.S` to inspect the stack state and traces the bug.

**Climax:** He realises his memory dump word has a subtle logic error. He uses `MARKER CHECKPOINT` before his next attempt, redefines the word, tests it — still wrong. He executes `CHECKPOINT` to roll back to known-good state and tries a different approach. The iteration cycle is seconds, not minutes.

**Resolution:** Dave's confidence in the system grows. He pushes harder because he knows errors are caught gracefully and he can always roll back. He starts writing more complex programs, trusting the environment to keep him safe.

### Journey 4: The Hardware Developer — Prototyping VideoBeast

**Sam**, the MicroBeast ecosystem creator, is designing the VideoBeast expansion card. He needs to test register mappings and validate that his VDP responds correctly to command sequences.

**Opening Scene:** Sam has a prototype VideoBeast plugged into the expansion slot. He needs to poke specific I/O ports in specific sequences and observe the results. Cross-compiled test programs mean a full recompile for every register value change.

**Rising Action:** Sam loads antforth on the MicroBeast. He defines simple words to write to the VideoBeast's control port and read the status register. He tests different initialisation sequences interactively, adjusting values at the REPL. When a register doesn't respond as expected, he tries different bit patterns immediately.

**Climax:** Sam gets the VDP initialised and displaying a test pattern — all from the REPL. He uses the built-in assembler to write a performance-critical sprite blitting word as a CODE definition, testing it in-situ alongside his Forth words.

**Resolution:** Sam documents his findings as a Forth source file — a sequence of word definitions that initialise and exercise the VideoBeast. This becomes the seed of the future VideoBeast vocabulary. What would have been days of cross-compile iteration was accomplished in an afternoon.

### Journey Requirements Summary

| Journey | Key Capabilities Revealed |
|---------|--------------------------|
| The OG — Productive Evening | REPL responsiveness, word definition, I/O port access, file save to ramdisk, immediate feedback loop |
| The Newb — First Contact | Clear error messages, `.S` stack inspection, approachable REPL, colon definitions, hardware I/O words |
| The OG — Error Recovery | Graceful error handling (undefined word, stack underflow), MARKER/rollback, dictionary integrity on failed definitions |
| Hardware Developer — Prototyping | I/O port read/write, CODE word definition via built-in assembler, interactive register-level testing, source file save |

**Common across all journeys:** Fast REPL response, correct ANS Core wordset, stable system that doesn't crash on errors, CP/M file I/O for persistence.

## Developer Tool / Embedded Specific Requirements

### Project-Type Overview

antforth is a Forth interpreter delivered as a CP/M 2.2 .COM application for the MicroBeast Z80 retrocomputer. It operates within the standard CP/M memory model (TPA below BDOS) with access to 11 additional 16K banked RAM pages via the MicroBeast's 512K memory architecture. The system is a single binary with no external dependencies beyond the CP/M environment.

### Technical Architecture Considerations

**Memory Model:**
- Standard CP/M TPA (Transient Program Area) — approximately 56-58K below BDOS, available for the Forth kernel, dictionary, stacks, and user workspace
- 11 additional 16K banked RAM pages (176K) available for extended dictionary, block storage, or user data
- Parameter stack: SP (hardware stack pointer)
- Return stack: IX register as stack pointer
- Key register allocation: HL=W, DE=IP, BC=TOS, IX=return stack, IY=user pointer

**Delivery:**
- Single CP/M .COM file, loadable from A: (ROM filesystem) or B: (ramdisk)
- If single-file delivery proves impractical, fallback to a CP/M disk image built with cpmtools
- Maximum disk capacity approximately 230K — the entire system (binary + any source files) must fit within this constraint

**Platform Abstraction:**
- Standard CP/M layering: CCP/BDOS/BIOS separation
- Only BIOS is device-specific — kernel portability to other CP/M Z80 systems comes via BDOS abstraction
- MicroBeast-specific hardware words (LED display, I/O ports, expansion cards) are bespoke vocabularies layered on top of the portable kernel
- Porting to another Z80 CP/M platform requires only replacing hardware-specific vocabularies, not modifying the core

**Dictionary and Word Lookup:**
- XOR-rotate hash with 64 buckets (single vocabulary for MVP)
- Hash-linked dictionary entries for fast word resolution
- WORDS available for dictionary listing
- No built-in help system — all documentation external/online due to memory constraints

### Implementation Considerations

**CP/M Integration:**
- Console I/O via BDOS function calls (C_READ, C_WRITE, C_READSTR)
- File I/O via BDOS sequential file access (post-MVP INCLUDE support)
- System exits cleanly back to CCP on BYE
- .COM file entry point at 0100h per CP/M convention

**Banked Memory Strategy:**
- Bank switching mechanism for accessing the 11 additional 16K pages
- Strategy for what lives in banked memory vs. base TPA to be determined during architecture phase
- Potential uses: extended dictionary space, block buffers, user program storage

**Constraints:**
- No floating-point hardware — Float wordset (future) will be software-emulated
- 8 MHz Z80 clock — performance-sensitive primitives (NEXT, dictionary lookup, stack operations) must be cycle-efficient
- No MMU — bank switching is manual via I/O port writes
- Terminal I/O limited to CP/M console capabilities (no cursor addressing unless terminal supports it)

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Platform MVP — build the minimum self-sustaining Forth system that can bootstrap everything else. The MVP is complete when a user can sit at the MicroBeast, define words, write CODE definitions with the assembler, and interactively develop software. Every feature in Phase 2+ builds on this foundation using Forth itself.

**Resource Requirements:** Solo developer (Ant), working in hobby time. No external dependencies, no team coordination overhead. The constraint is time, not capability.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- The OG — Productive Evening (fully supported)
- The Newb — First Contact (fully supported)
- The OG — Error Recovery (fully supported)
- Hardware Developer — Prototyping (partially — I/O port access via raw Forth, no dedicated hardware vocabulary yet)

**Must-Have Capabilities:**
- Inner/outer interpreter (direct-threaded, JP-based NEXT/DOCOL/EXIT)
- ANS Core wordset (single-precision) — stack ops, arithmetic, comparison, logic, memory, control flow, compiler words, I/O primitives, string support, dictionary management
- Interactive REPL with interpret/compile loop, "ok" prompt, line input via ACCEPT
- Error handling — undefined word, stack underflow, compile-only word misuse, graceful recovery without crash
- XOR-rotate hashed vocabulary lookup (64 buckets, single vocabulary)
- Built-in reverse-polish Z80 assembler for CODE word definitions
- MARKER for system state snapshot/rollback
- WORDS for dictionary listing
- Static dictionary allocation (HERE, ALLOT, COMMA, C,)
- CP/M 2.2 .COM application, clean exit via BYE

**Explicitly excluded from MVP:**
- Dynamic memory allocation (ALLOCATE/FREE/RESIZE) — HERE/ALLOT suffices
- Double-precision arithmetic — single-precision sufficient initially
- File-Access wordset (INCLUDE) — no source file loading yet
- Search-Order wordset — single flat vocabulary only
- MicroBeast hardware vocabulary — users can access I/O ports directly with raw Forth/assembler
- Exception wordset, Locals wordset, Float wordset

### Post-MVP Features

**Phase 2 (Growth):**
- File-Access wordset — INCLUDE, source file loading/saving from CP/M filesystem
- Search-Order wordset — multiple vocabularies with per-vocabulary hash tables
- Double-precision arithmetic for full ANS Core compliance
- Memory-Allocation wordset (ALLOCATE, FREE, RESIZE)
- FORGET (simplified, current vocabulary only)
- MicroBeast hardware vocabulary — 14-segment LED display words, I/O port access
- Exception wordset

**Phase 3 (Expansion):**
- Locals wordset
- Beginner's guide to antforth on MicroBeast
- VideoBeast support — sprite manipulation, graphics primitives
- AudioBeast support — instrument definition, sound generation words
- Float wordset (software-emulated, expected to be technically challenging)
- Community word library sharing and distribution
- Portability to other Z80 CP/M platforms

### Risk Mitigation Strategy

**Technical Risks:** Low for MVP. All core Forth implementation techniques are well-understood, solved problems from the 1970s-80s. The work is re-discovery and careful Z80 implementation, not novel research. Higher-risk features (double-precision, floating-point) are deliberately deferred to post-MVP.

**Market Risks:** Minimal. The "market" is the MicroBeast hobbyist community, and the primary user is the author. There's no validation needed — if it works and is enjoyable to use, it succeeds.

**Resource Risks:** Solo hobby project with no deadline pressure. The main risk is loss of momentum. Mitigation: the MVP is scoped tightly enough to reach a satisfying "it works" milestone without requiring months of sustained effort. Each milestone (REPL working, colon definitions, assembler) provides its own motivational reward.

## Functional Requirements

### Interpreter Core

- FR1: User can enter text at an interactive REPL prompt and receive immediate execution results
- FR2: System can parse input text into whitespace-delimited tokens (words and numbers)
- FR3: System can look up words in the dictionary via hashed vocabulary search
- FR4: System can recognise and convert numeric literals (single-precision integers) from input text
- FR5: System can operate in interpret mode, executing words and pushing numbers to the stack
- FR6: System can operate in compile mode, compiling words and literals into new definitions
- FR7: System can switch between interpret and compile modes via `[` and `]`
- FR8: System can execute compiled threaded code via the direct-threaded inner interpreter

### Word Definition & Dictionary

- FR9: User can define new colon definitions (`: name ... ;`)
- FR10: User can define CODE words using the built-in Z80 assembler
- FR11: User can create variables, constants, and user-defined data structures (CREATE/DOES>)
- FR12: User can mark words as IMMEDIATE for compile-time execution
- FR13: User can use POSTPONE to compile the compilation semantics of a word
- FR14: User can list all defined words in the dictionary (WORDS)
- FR15: User can snapshot dictionary state with MARKER and restore to that snapshot
- FR16: System can store and retrieve dictionary entries via XOR-rotate hashed lookup with 64 buckets

### Stack Operations

- FR17: User can manipulate the parameter stack (DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH)
- FR18: User can inspect the current parameter stack contents (.S)
- FR19: User can manipulate the return stack (>R, R>, R@)

### Arithmetic & Logic

- FR20: User can perform single-precision integer arithmetic (+, -, *, /, MOD, /MOD, NEGATE, ABS, MIN, MAX)
- FR21: User can perform comparison operations (=, <, >, 0=, 0<, U<)
- FR22: User can perform bitwise logic operations (AND, OR, XOR, INVERT, LSHIFT, RSHIFT)

### Memory Access

- FR23: User can read and write cell-sized values in memory (@, !, +!)
- FR24: User can read and write byte-sized values in memory (C@, C!)
- FR25: User can allocate dictionary space (HERE, ALLOT, COMMA, C,, ALIGN, ALIGNED)
- FR26: User can fill and move memory regions (FILL, MOVE)

### Control Flow

- FR27: User can use conditional branching in definitions (IF/ELSE/THEN)
- FR28: User can use indefinite loops (BEGIN/WHILE/REPEAT, BEGIN/UNTIL)
- FR29: User can use counted loops (DO/LOOP/+LOOP, LEAVE, I, J)
- FR30: User can use RECURSE for recursive word definitions

### I/O & String Handling

- FR31: User can emit characters and strings to the console (EMIT, TYPE, CR, SPACE, SPACES)
- FR32: User can read keyboard input (KEY, KEY?)
- FR33: User can accept line input from the console (ACCEPT)
- FR34: User can format and display numbers (., U., .R)
- FR35: User can work with counted strings (COUNT, WORD, FIND)
- FR36: User can convert text to numbers (>NUMBER)
- FR37: User can define and use string literals (S", .")

### Built-in Assembler

- FR38: User can write Z80 assembly instructions using reverse-polish notation within CODE definitions
- FR39: User can define new CODE primitives that integrate with the Forth threading model
- FR40: User can mix assembler and Forth in the same development session

### System & Platform

- FR41: System can load and run as a CP/M 2.2 .COM application from A: or B: drive
- FR42: User can exit antforth cleanly back to CP/M (BYE)
- FR43: System can perform console I/O via CP/M BDOS calls
- FR44: User can set and query the numeric base for I/O (BASE, DECIMAL, HEX)

### Error Handling

- FR45: System can detect and report undefined words without crashing
- FR46: System can detect and report stack underflow without crashing
- FR47: System can discard partial definitions on compilation errors without corrupting the dictionary
- FR48: System can recover gracefully from errors and return to the REPL prompt

## Non-Functional Requirements

### Performance

- NFR1: REPL input-to-output latency must be imperceptible for interactive use — simple expressions should feel instantaneous at 8 MHz
- NFR2: Dictionary lookup must remain responsive as the dictionary grows — the 64-bucket hash table provides acceptable O(n/64) average-case lookup
- NFR3: Inner interpreter threading (NEXT/DOCOL/EXIT) must be cycle-efficient — these are the hottest code paths in the system
- NFR4: Stack operations (DUP, DROP, SWAP, OVER) must be minimal-cycle implementations — they dominate typical Forth code

### Stability & Correctness

- NFR5: The system must never crash or hang due to user input errors — all errors must be caught and reported, returning control to the REPL
- NFR6: The dictionary must remain consistent after any error — partial definitions must be fully discarded without corruption
- NFR7: MARKER rollback must restore the system to an exact prior state — no residual side effects
- NFR8: All ANS Core wordset words must produce correct results per the ANS Forth specification — correctness is non-negotiable, performance is secondary

### Resource Constraints

- NFR9: The complete system (kernel + core wordset + assembler) must fit within the CP/M TPA — approximately 56-58K including dictionary space for user definitions
- NFR10: The .COM binary must be deliverable on a single CP/M disk (≤230K capacity)
- NFR11: Stack depths (parameter and return) must be sufficient for typical Forth usage without requiring user configuration
