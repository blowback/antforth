---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
partyModeNotes:
  - 'Epic 11: Add a "migration inventory + ordering" story at the front so the ABORT→THROW crawl scope is visible before word-by-word commits begin (E11-D3).'
  - 'Sprint change 2026-04-20: Retained built-in Z80 assembler; removed ASSEMBLER.FTH authorship and lazy-load capstone (FR45–49, NFR3, NFR22, E13-D4/D5). See sprint-change-proposal-2026-04-20.md.'
inputDocuments:
  - prd.md
  - architecture.md
  - prd-phase1-epics-1-8.md
  - architecture-phase1-epics-1-8.md
  - epics-phase1-epics-1-8.md
  - product-brief-antforth-2026-04-14.md
phase: 2
phaseScope: 'Epics 9-13 — antforth 2.0 release'
---

# antforth - Epic Breakdown (Phase 2: Epics 9–13)

## Overview

This document provides the epic and story breakdown for **antforth 2.0** (Phase 2), decomposing the PRD and Architecture into implementable stories for Epics 9 through 13. Phase 1 (Epics 1–8) is complete and preserved in `epics-phase1-epics-1-8.md`; its kernel, REPL, language-extension compiler, built-in Z80 assembler, MARKER, and shadow-register optimisations are the foundation on which Phase 2 builds.

The phase delivers two mutually reinforcing goals — **100% ANS Forth Core compliance** and **on-device source development via the CP/M filesystem**. The built-in Z80 assembler is retained unchanged; Epic 12 wires the existing opcode words under a new `ASSEMBLER` wordlist with auto-activation inside `CODE`/`END-CODE`. The 2.0 release is tagged when the Epic 13 regression gate passes against a real MicroBeast.

## Requirements Inventory

### Functional Requirements

**Numeric Literal Input (Epic 9)**
- FR1: Users can enter decimal integer literals using the `#` prefix, regardless of the current `BASE`
- FR2: Users can enter hexadecimal integer literals using the `$` prefix, regardless of the current `BASE`
- FR3: Users can enter binary integer literals using the `%` prefix, regardless of the current `BASE`
- FR4: Users can enter character literals using the `'c'` syntax, yielding the character's numeric value
- FR5: Users can enter hexadecimal literals using the `0x` prefix as an antforth-specific alternative to `$`
- FR6: All prefixed numeric literals accept an optional leading `-` sign
- FR7: All numeric literal prefixes (`#`, `$`, `%`, `0x`) and their hex digits (a–f) are case-insensitive
- FR8: The interpreter recognises numeric-literal prefixes everywhere ordinary numbers are parsed — interactive REPL, compiled colon definitions, and the built-in Z80 assembler source
- FR9: Entering a prefixed literal does not mutate the value of the `BASE` variable

**Core Arithmetic & Numeric Output (Epic 10)**
- FR10: Users can perform double-precision signed and unsigned integer arithmetic using the ANS Core double-cell word set (`D+`, `D-`, `D*`, `DNEGATE`, `DABS`, `D<`, `D=`, `DMAX`, `DMIN`, `M*`, `UM*`, `M+`, `SM/REM`, `FM/MOD`, `UM/MOD`)
- FR11: Users can store, fetch, and manipulate double-cell values on the parameter stack using `2@`, `2!`, `2DUP`, `2DROP`, `2SWAP`, `2OVER`
- FR12: Users can convert between single-cell and double-cell representations using `>D`, `S>D`, `D>S`
- FR13: Users can construct formatted numeric output using the ANS pictured numeric output wordset (`<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`, `HOLDS`)
- FR14: Users can output numbers using the Core display words (`.`, `U.`, `D.`, `.R`, `U.R`, `D.R`), which are implemented on top of the pictured output system
- FR15: Users can rely on 100% of the ANS Forth 1994 Core wordset being implemented and behaving per the standard

**Exception Handling (Epic 11)**
- FR16: Users can wrap the execution of a word in a `CATCH` frame and receive a THROW code in the event of an error
- FR17: Users can raise an exception using `THROW` with an arbitrary non-zero integer code
- FR18: The system defines and honours the ANS standard THROW codes for common errors (stack underflow, undefined word, division by zero, etc.)
- FR19: Every internal error path in the interpreter, compiler, and primitive words routes through the `THROW` mechanism rather than through `ABORT`
- FR20: `ABORT` and `ABORT"` behave as wrappers for `-1 THROW` and `-2 THROW` respectively, per the ANS standard
- FR21: An uncaught THROW returns control to the REPL top level with a diagnostic message that includes the THROW code and (where applicable) a human-readable description
- FR22: The REPL itself survives any THROW — the user's session, dictionary, and definitions are preserved across errors

**Vocabulary & Namespace Management (Epic 12)**
- FR23: Users can create a new wordlist with `WORDLIST`, receiving a wordlist identifier on the stack
- FR24: Users can query the current search order with `GET-ORDER` and set it with `SET-ORDER`
- FR25: Users can query and change the current compilation wordlist with `GET-CURRENT` and `SET-CURRENT`
- FR26: Users can direct subsequent definitions into the top-of-search-order wordlist using `DEFINITIONS`
- FR27: Users can reduce the search order to a minimal set with `ONLY`
- FR28: Users can reference the built-in Forth wordlist with `FORTH-WORDLIST`
- FR29: Users can search a specific wordlist for a word with `SEARCH-WORDLIST`
- FR30: The `ASSEMBLER` wordlist is automatically activated on entry to `CODE` and deactivated on exit from `END-CODE`
- FR31: Users with existing CODE-word source files authored against pre-phase antforth can assemble those files unchanged

**Source File I/O (Epic 13)**
- FR32: Users can load a source file from the CP/M filesystem using `INCLUDE <filename>`
- FR33: Users can load a source file by explicit file identifier using `INCLUDE-FILE`
- FR34: Users can load a named source file using `INCLUDED`
- FR35: Users can open a file with `OPEN-FILE`, specifying an access mode (`R/O`, `R/W`, `W/O`, `BIN`)
- FR36: Users can create a file with `CREATE-FILE`, specifying an access mode
- FR37: Users can delete a file with `DELETE-FILE`
- FR38: Users can read bytes from a file with `READ-FILE`
- FR39: Users can write bytes to a file with `WRITE-FILE`
- FR40: Users can query and set the current file position with `FILE-POSITION` and `REPOSITION-FILE`
- FR41: Users can query the size of a file with `FILE-SIZE`
- FR42: Users can close a file with `CLOSE-FILE`
- FR43: File operations raise a THROW (not ABORT) on errors such as file-not-found, permission-denied, or disk-full
- FR44: Users can load source files from either drive A: (ROM filesystem) or B: (ramdisk) without syntactic distinction

**Backward Compatibility & Regression (phase-wide constraint)**
- FR45: All functional behaviour delivered in Epics 1–8 continues to work identically in antforth 2.0 — REPL, colon definitions, variables, constants, `CREATE`/`DOES>`, control flow, error reporting, `MARKER`, and existing word semantics
- FR46: All existing REPL-piped test scripts from Epics 1–8 continue to pass against the antforth 2.0 binary
- FR47: The unprefixed numeric literal form (`<BASEnum>`) continues to be parsed per the current value of `BASE`, identically to pre-phase antforth

### NonFunctional Requirements

**Performance**
- NFR1: Numeric literal prefix parsing overhead — recognition of a prefixed literal adds no more than ~20 Z80 cycles over the unprefixed parse path for the 99th-percentile literal
- NFR2: Word lookup across multiple vocabularies — with a search order of up to 8 wordlists, lookup shall not regress by more than 10% of cycle count versus the pre-phase single-vocabulary baseline
- NFR3: CATCH/THROW overhead — an uncaught `CATCH` frame adds no more than ~15 Z80 cycles; successful THROW unwind completes in bounded time proportional to return-stack depth at THROW time
- NFR4: Kernel ROM footprint budget — each Phase-2 epic logs its kernel-size delta and justifies any increase against the capability delivered; net-of-Phase-2 delta is expected to be positive; size-reduction opportunities spawned as dedicated follow-up stories
- NFR5: Double-precision arithmetic performance — Core double-precision primitives execute within ~20% of hand-rolled Z80 equivalents

**Reliability**
- NFR6: REPL shall survive any THROW, including stack overflow, division by zero, and undefined-word invocation; dictionary and in-session definitions are preserved
- NFR7: State integrity after error — no internal data structure (dictionary, wordlists, input buffer, pad, return stack) may be left corrupted after a THROW
- NFR8: Filesystem error recovery — failures during file operations raise THROW with a specific code and leave the filesystem consistent; no partial writes that corrupt CP/M directory entries; no orphaned file handles
- NFR9: Regression guarantee — the complete Epic 1–8 test suite shall pass on every antforth 2.0 candidate release; a single regression is a release blocker

**Compatibility & Standards Conformance**
- NFR10: ANS Forth 1994 Core wordset implemented to 100% coverage with behaviour matching the ANS specification (baseline 86% → 100% target)
- NFR11: Numeric literal prefix syntax implemented verbatim as Forth 2014 §3.4.1.3
- NFR12: Extension discipline — only non-standard addition this phase is the `0x` hex prefix; clearly flagged as an antforth extension; no silent divergence from standards
- NFR13: CP/M 2.2 BDOS integration — antforth uses only CP/M 2.2 standard BDOS functions (1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 25, 26, 27, 33, 34, 35, 36, 40)
- NFR14: CODE-word source file backward compatibility — pre-phase source files assemble correctly and produce byte-identical output under antforth 2.0

**Maintainability**
- NFR15: Z80 assembly source favours readability over micro-optimisation except where an epic explicitly targets performance; comments on non-obvious logic required; comments re-stating obvious assembly forbidden
- NFR16: Test-first discipline — every new word in Epics 9–13 has REPL-piped Forth test coverage before being declared done
- NFR17: Single-source-of-truth for standards references — word behaviours derived from a standard cite the standard section in the source comment
- NFR18: Epic-level decoupling — each of Epics 9–13 delivers an independently-shippable `antforth 1.x` increment

**Integration (CP/M and Platform)**
- NFR19: Terminal I/O portability — antforth uses only character-based BDOS console I/O (functions 1, 2, 6, 9); no ANSI escape codes, cursor positioning, or colour
- NFR20: File path conventions — `INCLUDE` and related words accept CP/M 2.2 file path syntax (optional drive letter + `:` + 8.3 filename); no wildcards; no Unix-style paths
- NFR21: MicroBeast hardware dependency isolation — no MicroBeast-specific hardware word enters the kernel or ASSEMBLER wordlist during this phase

### Additional Requirements

**Starter template (Architecture §Starter Template Evaluation):**
- Not applicable — the existing Phase 1 kernel is the "starter." All phase-2 architectural decisions build on the Epic 1–8 foundation without replacing any part of it. No new scaffolding, no new toolchain.

**Inherited register conventions (Architecture §Technical Constraints):**
- BC = TOS; SP = parameter stack pointer; IX = return stack pointer; IY = user area pointer; DE = IP; HL = working register (W)
- Shadow registers used per Epic 7/8 conventions
- Direct threading (JP-based) preserved; DEFWORD cf label via `EQU body-3` pointing to `JP DOCOL`

**Cross-cutting architectural decisions (Architecture §CCD-1 through CCD-4):**
- CCD-1: Return-stack frame taxonomy with dual chain discipline — `CATCH-TOP` and `INCLUDE-TOP` USER variables; exception frames 8 bytes, INCLUDE source frames 10 bytes
- CCD-2: THROW code allocation — `-1` to `-58` reserved for ANS standard codes; `-59` to `-255` reserved for future ANS extensions; `-256` to `-32767` for antforth-specific extensions; `+n` reserved for user codes
- CCD-3: Standards-citation discipline — every standard-derived word carries a one-line comment citing the spec section (e.g., `; Forth 2014 §6.2.2270 CATCH`)
- CCD-4: Per-epic benchmark gate — each epic includes a final "benchmarks + size delta" story gating completion on NFR envelopes

**Source-file layout (Architecture §Source file organisation):**
- `src/number_prefixes.asm` (Epic 9); `src/double.asm`, `src/pictured.asm` (Epic 10); `src/exception.asm` (Epic 11); `src/wordlists.asm` (Epic 12); `src/file_access.asm` (Epic 13)
- Existing `src/*.asm` edited in-place for ABORT→THROW migration, multi-vocabulary changes, and `ASSEMBLER` wordlist registration
- New tests under `tests/*.fth` (REPL-piped Forth); no new assembly test threads
- New docs: `docs/throw-codes.md` (Epic 11); `docs/ans-forth-core-compliance.md` revised (Epic 10)

**Platform constraints (PRD §Target Platform):**
- Z80 instruction set only — no Z80N, eZ80, or Z180 extensions
- CP/M 2.2 TPA (`0100h`–`FFFFh` minus BDOS/CCP); kernel lives in bank 0
- Real-hardware validation required for every epic's final story; no release tag without a pass on real MicroBeast

**Process conventions (Architecture §Process Patterns; inherited memory):**
- All new error sites use `THROW`, not `ABORT`; existing `ABORT` call sites migrate during Epic 11 (one per commit, each with its own REPL test)
- REPL-piped Forth scripts are the canonical test format; no new assembly test-thread extensions in phase 2
- Standards compliance: investigate the standard before defending existing code; never rationalise divergence silently
- Adversarial review: reviews MUST find things; zero findings is itself suspect

**Implementation sequence (locked by dependencies, Architecture §Decision Impact):**
- Epic 9 → Epic 10 → Epic 11 → Epic 12 → Epic 13
- CCD-1 prerequisite to Epic 11 and Epic 13
- E11-D1 (exception frame) prerequisite to E13-D2 (INCLUDE source frame)

### FR Coverage Map

| FR | Epic | Description |
|---|---|---|
| FR1 | Epic 9 | `#` decimal prefix |
| FR2 | Epic 9 | `$` hex prefix |
| FR3 | Epic 9 | `%` binary prefix |
| FR4 | Epic 9 | `'c'` character literal |
| FR5 | Epic 9 | `0x` hex prefix (antforth extension) |
| FR6 | Epic 9 | Leading `-` sign on prefixed literals |
| FR7 | Epic 9 | Case-insensitive prefixes and hex digits |
| FR8 | Epic 9 | Prefixes recognised in REPL, colon bodies, and assembler source |
| FR9 | Epic 9 | `BASE` not mutated by parsing |
| FR10 | Epic 10 | Double-cell arithmetic primitives (`D+`, `D-`, `D*`, etc.) |
| FR11 | Epic 10 | Double-cell stack manipulation (`2@`/`2!`/`2DUP`/`2DROP`/`2SWAP`/`2OVER`) |
| FR12 | Epic 10 | Single/double conversions (`>D`/`S>D`/`D>S`) |
| FR13 | Epic 10 | Pictured numeric output wordset (`<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`, `HOLDS`) |
| FR14 | Epic 10 | `.`/`U.`/`D.`/`.R`/`U.R`/`D.R` reimplemented on top of pictured output |
| FR15 | Epic 10 | 100% ANS Forth 1994 Core compliance |
| FR16 | Epic 11 | `CATCH` frame execution |
| FR17 | Epic 11 | `THROW` with arbitrary non-zero code |
| FR18 | Epic 11 | Standard ANS THROW codes honoured |
| FR19 | Epic 11 | Internal errors routed through THROW (full migration) |
| FR20 | Epic 11 | `ABORT`/`ABORT"` as `-1 THROW`/`-2 THROW` wrappers |
| FR21 | Epic 11 | Uncaught THROW returns to REPL with diagnostic |
| FR22 | Epic 11 | REPL survives any THROW |
| FR23 | Epic 12 | `WORDLIST` creates a new wordlist |
| FR24 | Epic 12 | `GET-ORDER`/`SET-ORDER` |
| FR25 | Epic 12 | `GET-CURRENT`/`SET-CURRENT` |
| FR26 | Epic 12 | `DEFINITIONS` |
| FR27 | Epic 12 | `ONLY` |
| FR28 | Epic 12 | `FORTH-WORDLIST` |
| FR29 | Epic 12 | `SEARCH-WORDLIST` |
| FR30 | Epic 12 | `ASSEMBLER` wordlist auto-activation on `CODE`/`END-CODE` |
| FR31 | Epic 12 | Pre-phase CODE-word source files assemble unchanged |
| FR32 | Epic 13 | `INCLUDE <filename>` |
| FR33 | Epic 13 | `INCLUDE-FILE` |
| FR34 | Epic 13 | `INCLUDED` |
| FR35 | Epic 13 | `OPEN-FILE` with access-mode argument |
| FR36 | Epic 13 | `CREATE-FILE` |
| FR37 | Epic 13 | `DELETE-FILE` |
| FR38 | Epic 13 | `READ-FILE` |
| FR39 | Epic 13 | `WRITE-FILE` |
| FR40 | Epic 13 | `FILE-POSITION`/`REPOSITION-FILE` |
| FR41 | Epic 13 | `FILE-SIZE` |
| FR42 | Epic 13 | `CLOSE-FILE` |
| FR43 | Epic 13 | File-operation errors raise THROW |
| FR44 | Epic 13 | Drives A: and B: are equivalent to `INCLUDE`/file ops |
| FR45 | Cross-epic regression AC | Phase-1 behavioural compatibility (enforced on every epic's regression story) |
| FR46 | Cross-epic regression AC | Phase-1 REPL-piped test scripts continue to pass |
| FR47 | Cross-epic regression AC | Unprefixed `<BASEnum>` numeric-literal form preserved |

## Epic List

### Epic 9: Numeric Literal Prefixes
Users can enter decimal / hex / binary / character literals using Forth 2014 §3.4.1.3 prefixes (`#`, `$`, `%`, `'c'`) plus the antforth `0x` extension — everywhere numbers are parsed (REPL, colon bodies, assembler source), case-insensitive, with optional sign, without mutating `BASE`. Delivers Raj's first-hour "0xFF just works" moment. Standalone release as antforth 1.9.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR8, FR9

### Epic 10: Double-Cell Arithmetic, Pictured Output & 100% Core Compliance
Users can do double-precision signed/unsigned arithmetic, manipulate double-cell stack values, build formatted numeric output via the pictured-output wordset, and rely on 100% of the ANS Forth 1994 Core wordset behaving per the standard (baseline 86% → 100%). `.`/`U.`/`D.`/`.R`/`U.R`/`D.R` reimplemented on pictured-output foundation. Drives the headline "100% ANS Core compliant" release claim. Standalone release as antforth 1.10.
**FRs covered:** FR10, FR11, FR12, FR13, FR14, FR15

### Epic 11: Exception Subsystem & Internal Error Migration
Users can catch errors with `CATCH`/`THROW`, receive standard ANS THROW codes, and keep their REPL session alive across any error; every internal error path in the interpreter, compiler, and primitives is migrated from `ABORT` to `THROW` (word-by-word per E11-D3); `ABORT`/`ABORT"` become standard wrappers for `-1 THROW`/`-2 THROW`. A migration-inventory story at the front of the epic makes the crawl scope visible before the word-by-word work begins. Delivers Mo's "catch a bug without losing the session" moment. Standalone release as antforth 1.11.
**FRs covered:** FR16, FR17, FR18, FR19, FR20, FR21, FR22

### Epic 12: Multi-Vocabulary Search-Order & ASSEMBLER Wordlist
Users can create and manage multiple wordlists, control the search order, direct definitions into specific wordlists, and benefit from automatic `ASSEMBLER` wordlist activation inside `CODE`/`END-CODE` — all while existing CODE source files assemble unchanged. The `ASSEMBLER` wordlist is populated from the existing kernel-resident opcode words; opcodes are not relocated to a Forth-source file during Phase 2. Standalone release as antforth 1.12.
**FRs covered:** FR23, FR24, FR25, FR26, FR27, FR28, FR29, FR30, FR31

### Epic 13: File-Access
Users can load and save source files against the CP/M 2.2 filesystem (`INCLUDE`/`INCLUDED`/`INCLUDE-FILE`/`OPEN-FILE`/`CREATE-FILE`/`READ-FILE`/`WRITE-FILE`/`FILE-POSITION`/`REPOSITION-FILE`/`FILE-SIZE`/`CLOSE-FILE`/`DELETE-FILE`). File errors raise `THROW`. Closes with the Phase-2 release gate — full regression of Epics 1–12, BDOS-function-allow-list audit, filesystem-error stress suite, kernel ROM-delta accounting, and MicroBeast hardware validation. Passing the gate tags **antforth 2.0**.
**FRs covered:** FR32, FR33, FR34, FR35, FR36, FR37, FR38, FR39, FR40, FR41, FR42, FR43, FR44

### Phase-wide regression constraint (not a standalone epic)
FR45, FR46, FR47 — enforced as cross-cutting acceptance criteria on every epic's regression story per NFR9 and the per-epic benchmark gate (CCD-4). No dedicated "regression epic" — each epic owns its own regression passage.

### Implementation Sequence (locked)
Epic 9 → Epic 10 → Epic 11 → Epic 12 → Epic 13, per Architecture §Decision Impact Analysis. Dependencies: CCD-1 prerequisite to Epic 11 and Epic 13; E11-D1 prerequisite to E13-D2. Each epic independently shippable as an `antforth 1.x` release per NFR18.

## Epic 9: Numeric Literal Prefixes

Users can enter decimal / hex / binary / character literals using Forth 2014 §3.4.1.3 prefixes (`#`, `$`, `%`, `'c'`) plus the antforth `0x` extension — everywhere numbers are parsed (REPL, colon bodies, assembler source), case-insensitive, with optional sign, without mutating `BASE`. Delivers Raj's first-hour "0xFF just works" moment. Shippable as antforth 1.9.

### Story 9.1: Numeric-prefix recogniser scaffold + `#` decimal prefix

As a Forth user,
I want to enter decimal integer literals using the `#` prefix regardless of the current `BASE`,
So that I can write decimal constants in source or at the REPL without a `DECIMAL` mode toggle.

**Acceptance Criteria:**

**Given** a fresh antforth REPL in any `BASE`
**When** I type `#42 .`
**Then** the output is `42 ok` and `BASE` is unchanged after the operation.

**Given** the outer interpreter's unknown-token handler
**When** a token beginning with `#` reaches the number path
**Then** control is dispatched through a new `src/number_prefixes.asm` recogniser that strips the prefix and accumulates digits in a working register without writing to `BASE`.

**Given** an unprefixed numeric literal (e.g., `42`)
**When** it is parsed at the REPL
**Then** the prefix recogniser is bypassed and parsing proceeds exactly as in the pre-Epic-9 code path (FR47 preserved).

**Given** the kernel source
**When** the `#` prefix is implemented
**Then** the `w_` word-implementation carries a standards-citation comment referencing Forth 2014 §3.4.1.3 (per NFR17/CCD-3).

**Given** the new file `src/number_prefixes.asm`
**When** the epic proceeds to stories 9.2+
**Then** the file contains the extensible prefix-dispatch table ready for additional prefix entries.

### Story 9.2: Hex prefixes — `$` (standard) and `0x` (antforth extension)

As a Forth user,
I want to enter hexadecimal integer literals using either `$` (standard Forth 2014) or `0x` (antforth C-family-friendly extension),
So that I can match my muscle memory from other languages without mode-toggling to `HEX`.

**Acceptance Criteria:**

**Given** any current `BASE`
**When** I type `$ff .` or `$FF .`
**Then** the output is `255 ok` and `BASE` is unchanged.

**Given** any current `BASE`
**When** I type `0xff .` or `0xFF .` or `0XFF .`
**Then** the output is `255 ok` and `BASE` is unchanged.

**Given** the kernel source
**When** the `0x` prefix is implemented
**Then** its source comment explicitly flags it as `; antforth extension — C-style hex prefix` per NFR12/CCD-3; the `$` prefix cites Forth 2014 §3.4.1.3.

**Given** the prefix dispatch table
**When** a two-character prefix (`0x`) is recognised
**Then** the dispatch correctly distinguishes `0x` from a raw digit `0` followed by a token `x…` — no ambiguity regression against the unprefixed path.

**Given** the REPL-piped test script `tests/number_prefixes_tests.fth`
**When** it runs
**Then** it covers `$0`, `$FF`, `$ff`, `$1234`, `0x0`, `0xFF`, `0xFFFF` with expected outputs, and verifies `BASE` integrity before/after each case.

### Story 9.3: Binary `%` and character `'c'` prefixes

As a Forth user,
I want to enter binary literals via `%` and character-code literals via `'c'` using Forth 2014 syntax,
So that I can express bit patterns and ASCII codes directly without helper words.

**Acceptance Criteria:**

**Given** any current `BASE`
**When** I type `%1010 .`
**Then** the output is `10 ok` and `BASE` is unchanged.

**Given** any current `BASE`
**When** I type `'A' .`
**Then** the output is `65 ok` and `BASE` is unchanged.

**Given** a binary literal containing non-binary digits (e.g., `%102`)
**When** it is parsed
**Then** it fails the number path and is reported as an undefined word via the existing error path (unchanged behaviour).

**Given** a character literal with an unterminated or overly long sequence (e.g., `'ab'`)
**When** it is parsed
**Then** it fails the number path and is reported as an undefined word.

**Given** the kernel source
**When** `%` and `'c'` are implemented
**Then** both carry Forth 2014 §3.4.1.3 citation comments per NFR17/CCD-3.

**Given** the REPL test script
**When** it runs
**Then** it covers `%0`, `%1`, `%1010`, `%11111111`, `'A'`, `'0'`, `' '`, and a failure case per prefix.

### Story 9.4: Leading `-` sign and full case-insensitivity

As a Forth user,
I want optional leading `-` sign support on all prefixed numeric literals and full case-insensitivity of prefixes and hex digits,
So that negative constants and typographic casing don't trip up my source.

**Acceptance Criteria:**

**Given** any current `BASE`
**When** I type `-#42 .`, `-$ff .`, `-%1010 .`, or `-0xFF .`
**Then** the outputs are `-42 ok`, `-255 ok`, `-10 ok`, and `-255 ok` respectively.

**Given** the `'c'` syntax
**When** I type `-'A' .`
**Then** the result is `-65 ok` (sign applies to the character code per FR6).

**Given** a hex literal in either style (`$` or `0x`)
**When** the digits include any mix of upper- and lower-case (e.g., `$aBcD`, `0xAbCd`)
**Then** parsing succeeds and the value is identical regardless of case.

**Given** prefix characters themselves
**When** upper-case variants are used (`0X`, uppercase sensitivity on prefix letters)
**Then** parsing succeeds identically to the lower-case form; non-letter prefixes (`#`, `$`, `%`) are already case-free.

**Given** the REPL test script
**When** it runs
**Then** it covers every prefix with negative variants and mixed-case variants for `$` / `0x` hex.

### Story 9.5: Prefix reach — REPL, colon bodies, and assembler source

As a Forth user,
I want numeric literal prefixes to be recognised everywhere ordinary numbers are parsed — interactive REPL, compiled colon definitions, and inside `CODE` / `END-CODE` blocks,
So that the prefix grammar is consistent across the whole system (FR8) and my session's `BASE` is never silently mutated (FR9).

**Acceptance Criteria:**

**Given** an interactive REPL session in `HEX` mode
**When** I type `: DECNUM #100 . ; DECNUM`
**Then** the output is `100 ok` (decimal 100), and `BASE` remains `HEX` before and after the definition and call.

**Given** an interactive REPL session in `DECIMAL` mode
**When** I type `: HEXNUM $ff . ; HEXNUM`
**Then** the output is `255 ok`, and `BASE` remains `DECIMAL`.

**Given** a `CODE` / `END-CODE` block
**When** a prefixed literal appears in the assembler source (e.g., a byte constant `0xFF C,`)
**Then** the prefix is recognised by the assembler source's number-parse path identically to the REPL path.

**Given** any prefix parse in either interpret or compile state
**When** the parse completes (success or failure)
**Then** `BASE` holds the same value it held immediately before the parse began (FR9, NFR2-adjacent integrity check).

**Given** the REPL test script
**When** it runs
**Then** it includes cases for each parse context (interactive, colon body, `CODE` block) with before/after `BASE` snapshots asserted equal.

### Story 9.6: Epic 9 benchmark, standards citation audit, and regression gate (CCD-4)

As an antforth maintainer,
I want Epic 9 to close with explicit benchmark measurements, a standards-citation audit, and a full regression pass on the Phase-1 test suite,
So that NFR1 (prefix overhead), NFR4 (ROM delta), NFR9 (regression guarantee), NFR11 (spec conformance), NFR17 (citation discipline), and FR45–47 (backward compatibility) are verified before the epic is marked done and `antforth 1.9` can be tagged.

**Acceptance Criteria:**

**Given** the pre-Epic-9 baseline cycle counts for the unprefixed parse path
**When** the Epic-9 benchmark thread runs on the emulator against the same inputs
**Then** the unprefixed parse path's cycle count is unchanged within noise (≤ ~1% drift) — unprefixed hot path untouched per E9-D1.

**Given** the prefixed parse path cycle measurement
**When** a representative prefix (e.g., `#42`) is benchmarked against an equivalent unprefixed literal
**Then** the delta is **≤ 20 Z80 cycles** per NFR1 — recorded in the epic's benchmark notes.

**Given** the Epic-9 kernel ROM size
**When** measured against the post-Epic-8 baseline
**Then** the delta is recorded (contribution toward NFR5 net-negative target; an *increase* is permitted for a single epic as long as later epics can recover it).

**Given** the full Phase-1 REPL-piped test suite (`tests/core_tests.fth` + all Epic 1–8 tests)
**When** run against the Epic-9 binary
**Then** every test passes — zero regressions per NFR9 / FR46.

**Given** an unprefixed numeric literal like `42` in any `BASE`
**When** parsed under the Epic-9 binary
**Then** behaviour is bit-identical to the post-Epic-8 baseline — FR47 verified by dedicated regression test.

**Given** every word added in `src/number_prefixes.asm`
**When** audited by a reviewer
**Then** each standard-derived word carries a Forth 2014 §3.4.1.3 citation; the `0x` extension carries the `; antforth extension` flag — NFR17 / CCD-3 compliance verified.

**Given** a real-MicroBeast-hardware smoke test
**When** `tests/number_prefixes_tests.fth` is piped into the `.COM` on real hardware
**Then** it passes — PRD MVP rule satisfied; `antforth 1.9` release can be tagged.

## Epic 10: Double-Cell Arithmetic, Pictured Output & 100% Core Compliance

Users can do double-precision signed/unsigned arithmetic, manipulate double-cell stack values, build formatted numeric output via the pictured-output wordset, and rely on 100% of the ANS Forth 1994 Core wordset behaving per the standard (baseline 86% → 100%). `.`/`U.`/`D.`/`.R`/`U.R`/`D.R` are reimplemented on the pictured-output foundation. Drives the headline "100% ANS Core compliant" release claim. Shippable as antforth 1.10.

### Story 10.1: ANS Core compliance gap survey + implementation plan

As an antforth maintainer,
I want a systematic survey of the remaining ~14% of the ANS Forth 1994 Core wordset not yet implemented,
So that Epic 10's implementation stories are driven by an authoritative, cross-referenced inventory rather than partial memory (per `feedback_systematic_reference_check`).

**Acceptance Criteria:**

**Given** the current `docs/ans-forth-core-compliance.md`
**When** the surveyor cross-references every Core word against the current antforth dictionary
**Then** a categorised inventory is produced — (a) double-cell family, (b) pictured-output family, (c) other single-cell gaps — with every missing Core word named, specified to its ANS §, and assigned an implementation story (10.2–10.9).

**Given** the inventory
**When** reviewed
**Then** every Core word is either marked "present" (with its source location) or "gap — assigned to Story 10.x"; nothing is left as "unsure."

**Given** the refreshed `docs/ans-forth-core-compliance.md`
**When** the epic starts
**Then** the file records the pre-Epic-10 baseline coverage percentage (expected ≈ 86%) and the per-story coverage increments that will take it to 100%.

### Story 10.2: Double-cell stack foundation (`2@`, `2!`, `2DUP`, `2DROP`, `2SWAP`, `2OVER`)

As a Forth user,
I want to push, drop, duplicate, swap, and copy double-cell values on the parameter stack using the standard `2*` wordset,
So that I have a working stack foundation for all subsequent double-precision work.

**Acceptance Criteria:**

**Given** E10-D1's byte-order decision (low cell on TOS, high cell below)
**When** `2@` fetches a 32-bit value from an address
**Then** the low cell is on top of stack and the high cell is second on stack — ANS Forth 1994 §6.1.0350 behaviour.

**Given** `2DUP`, `2DROP`, `2SWAP`, `2OVER`
**When** executed against a two-cell pair
**Then** each produces the standard ANS-specified result, preserving double-cell order integrity.

**Given** the new `src/double.asm` or modified `src/stack_ops.asm`
**When** each word is implemented
**Then** its source carries an ANS Forth 1994 §<section> citation per NFR17/CCD-3, and a stack-effect comment on its DEFCODE line.

**Given** `tests/double_tests.fth`
**When** run
**Then** it verifies every double-cell stack op with known-value round-trip tests (write via `2!`, read via `2@`, confirm both cells via `2SWAP`/`2DROP` patterns).

### Story 10.3: Single ↔ double conversions (`S>D`, `D>S`, `>D` if applicable)

As a Forth user,
I want to convert cleanly between single-cell and double-cell representations,
So that I can feed single-cell inputs into double-precision arithmetic and extract single-cell results out.

**Acceptance Criteria:**

**Given** a single-cell signed value `n` on TOS
**When** I execute `S>D`
**Then** the result is the sign-extended double-cell value (low cell = original, high cell = 0 if `n ≥ 0` else `-1`) per ANS §6.1.2170 (`S>D`) behaviour.

**Given** a double-cell value whose high cell is a pure sign extension of the low cell
**When** I execute `D>S`
**Then** the result is the original signed single cell; when the high cell does not represent a pure sign extension, behaviour matches ANS semantics (implementation-defined truncation — documented in source).

**Given** `tests/double_tests.fth`
**When** it runs
**Then** it covers positive, negative, and zero boundary values for every conversion; round-trip `S>D D>S` preserves value.

### Story 10.4: Double-precision arithmetic — additive, sign, compare, mixed (`D+`, `D-`, `DNEGATE`, `DABS`, `D=`, `D<`, `DMAX`, `DMIN`, `M+`)

As a Forth user,
I want the full additive/comparison suite of ANS double-precision arithmetic words,
So that I can do 32-bit signed and unsigned math using the standard vocabulary.

**Acceptance Criteria:**

**Given** each implemented word
**When** invoked against boundary inputs (zero, max positive, max negative, equal-magnitude pair)
**Then** results match the ANS §6.1.* spec exactly; `D=` returns standard true/false flag convention.

**Given** `M+` (mixed single + double → double)
**When** the single is added to the double
**Then** the result matches the ANS §8.6.1.1830 spec including sign-extended carry propagation.

**Given** the source
**When** each word is implemented
**Then** ANS Forth 1994 §<section> citations per NFR17/CCD-3 appear; stack-effect comments appear on every DEFCODE.

**Given** `tests/double_tests.fth`
**When** it runs
**Then** every additive/compare/sign word has a table-driven test with at least 6 inputs covering positive/negative/zero/overflow/equality/inequality.

### Story 10.5: Double multiplication (`D*`, `M*`, `UM*`)

As a Forth user,
I want standard Core multiplication primitives for double-cell and mixed-precision values,
So that I can compute 32-bit products from single- and double-cell inputs per ANS semantics.

**Acceptance Criteria:**

**Given** `M*` (signed single × signed single → signed double)
**When** invoked
**Then** ANS §6.1.1810 behaviour is satisfied including correct sign of the double result.

**Given** `UM*` (unsigned single × unsigned single → unsigned double)
**When** invoked
**Then** ANS §6.1.2360 behaviour is satisfied.

**Given** `D*` (signed double × signed double → signed double, truncating to 32 bits)
**When** invoked
**Then** ANS §8.6.1.1140 behaviour is satisfied.

**Given** the source
**When** the implementations are written
**Then** they use the existing Z80 register conventions (BC-TOS discipline preserved; EXX convention followed per Epic 7/8 memory entries); citations + stack-effect comments present.

**Given** `tests/double_tests.fth`
**When** it runs
**Then** multiplications are verified by `M*` `UM*` `D*` with pairs whose expected results span: zero, one-operand zero, signed-positive, signed-negative, unsigned overflow crossing the single-cell boundary.

### Story 10.6: Double/mixed-precision division (`SM/REM`, `FM/MOD`, `UM/MOD`)

As a Forth user,
I want the ANS Core division primitives for double-cell dividends,
So that I can do 32/16 → 16 remainder+quotient math in both signed (symmetric and floored) and unsigned forms.

**Acceptance Criteria:**

**Given** `SM/REM` (symmetric division: signed double ÷ signed single → signed remainder, signed quotient)
**When** invoked against a mixed-sign dividend/divisor pair
**Then** ANS §6.1.2214 symmetric-division rules are satisfied (quotient rounded toward zero; remainder's sign matches dividend).

**Given** `FM/MOD` (floored division: same signature)
**When** invoked against a mixed-sign pair
**Then** ANS §6.1.1561 floored-division rules are satisfied (quotient rounded toward negative infinity; remainder's sign matches divisor).

**Given** `UM/MOD` (unsigned double ÷ unsigned single → unsigned remainder, unsigned quotient)
**When** invoked
**Then** ANS §6.1.2370 is satisfied.

**Given** division by zero on any of these primitives
**When** invoked
**Then** the behaviour matches the Epic-1–8 baseline (ABORT pre-Epic-11; Epic 11 will migrate this path to `THROW -10` per ANS §9.3.5).

**Given** `tests/double_tests.fth`
**When** it runs
**Then** division cases cover: positive/positive, positive/negative, negative/positive, negative/negative, boundary-magnitude dividends, plus the symmetric-vs-floored discrimination case required by the standard.

### Story 10.7: Pictured numeric output primitives (`<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`, `HOLDS`)

As a Forth user,
I want the ANS pictured-numeric-output wordset so I can build formatted number strings,
So that I can author custom display formats and so the Core `.`/`U.`/`D.`/`.R` family can be rebuilt on a standards-compliant foundation.

**Acceptance Criteria:**

**Given** E10-D2's design (40-byte buffer in user area, USER variable `HLD`, IY-relative addressing)
**When** `<#` is invoked
**Then** `HLD` is reset to the buffer's high end; subsequent `#` / `#S` / `HOLD` / `SIGN` / `HOLDS` calls build leftward into the buffer.

**Given** a number of any supported type (single or double) on the stack
**When** `<# #S #>` is invoked
**Then** a `(c-addr u)` pair is returned pointing to the formatted digit string per ANS §6.1.0490 / §6.1.0030 / §6.1.2210 / §6.1.0750 / §6.1.0040.

**Given** the 40-byte buffer size
**When** the longest double-precision decimal output (20 digits + sign + radix) is formatted
**Then** no overflow occurs; a test case exercises a 20-digit worst-case.

**Given** new file `src/pictured.asm`
**When** each word is implemented
**Then** ANS citations + stack-effect comments per NFR17/CCD-3; Forth 2014's `HOLDS` carries a Forth 2014 §6.2.1625 citation (it is a 2014 addition to the standard).

**Given** `tests/pictured_tests.fth`
**When** it runs
**Then** it covers single and double values, positive/negative, base-2/-10/-16 output, custom format patterns, and the 20-digit worst case.

### Story 10.8: Number-output words on pictured foundation (`.`, `U.`, `D.`, `.R`, `U.R`, `D.R`)

As a Forth user,
I want the Core number-display words reimplemented on top of the new pictured-output primitives,
So that the whole display family behaves consistently with user-defined pictured formatters, and so Epic 10 removes the pre-phase hand-rolled decimal/hex-specific output paths.

**Acceptance Criteria:**

**Given** the pictured-output primitives from Story 10.7
**When** `.`, `U.`, `D.`, `.R`, `U.R`, `D.R` are rewritten atop `<# ... #>`
**Then** they produce byte-for-byte identical output to the pre-Epic-10 implementations for all input cases covered by the Epic 1–8 regression tests (zero regression per NFR9).

**Given** `src/formatting.asm`
**When** edited to redirect these words onto pictured output
**Then** the pre-Epic-10 hand-rolled paths are removed (ROM size contribution toward NFR5 negative target).

**Given** ANS Core semantics
**When** `.R n` is called with `n < string-width`
**Then** the output is not truncated; `u < n` widths are left-padded with spaces per §6.1.0310.

**Given** `tests/core_gap_tests.fth` (or extended `tests/core_tests.fth`)
**When** it runs
**Then** every display word has a regression suite that was green pre-Epic-10 and stays green post-Epic-10; new cases exercise the pictured-output path explicitly (e.g., redefine `HOLD` in a user wordlist and see `.` unaffected — standard-compliance check).

### Story 10.9: Remaining Core gap words (inventory-driven from Story 10.1)

As a Forth user,
I want the remaining single-cell Core gap words identified by Story 10.1's survey (outside the double-cell and pictured-output families) implemented — specifically `*/`, `*/MOD`, `EVALUATE`, and `ENVIRONMENT?` —
So that the §6.1 Core wordset reaches 100% coverage (133 of 133 words) with behaviour matching ANS Forth 1994, with no deliberate omissions.

**Scope (set by Story 10.1 + party-mode decision 2026-04-20):**

- `*/` (§6.1.0100) — mixed-precision multiply-divide; depends on Stories 10.5 (`M*`) and 10.6 (`SM/REM`).
- `*/MOD` (§6.1.0110) — mixed-precision multiply-divide-modulo; same dependency.
- `EVALUATE` (§6.1.1360) — interpret from a string; save/restore input source.
- `ENVIRONMENT?` (§6.1.1345) — query implementation-defined limits. Previously classified "deliberately omitted" by Story 5.3 and upheld by Story 10.1; **reclassified as an in-scope Story 10.9 deliverable on 2026-04-20** (party-mode decision) so that FR15 / NFR10's "100% of the ANS Forth 1994 Core wordset" claim holds without deliberate-omission asterisks.

**Acceptance Criteria:**

**Given** the inventory produced by Story 10.1 (four words: `*/`, `*/MOD`, `EVALUATE`, `ENVIRONMENT?`)
**When** this story begins
**Then** each of the four gap words is implemented in the epic-appropriate source file per Architecture §Source-file organisation; each carries an ANS §<section> citation and stack-effect comment per NFR17/CCD-3.

**Given** each newly implemented word
**When** exercised against the behaviour specified in its ANS clause
**Then** a REPL-piped test case in `tests/core_gap_tests.fth` passes, asserting the standard-specified behaviour (happy path + at least one edge case).

**Given** `ENVIRONMENT?` specifically
**When** queried against the DPANS94 §3.2.6 standard query keys — `/COUNTED-STRING`, `/HOLD`, `/PAD`, `ADDRESS-UNIT-BITS`, `CORE`, `CORE-EXT`, `FLOORED`, `MAX-CHAR`, `MAX-D`, `MAX-N`, `MAX-U`, `MAX-UD`, `RETURN-STACK-CELLS`, `STACK-CELLS` —
**Then** each known key returns the correct implementation-defined value and `true`; any unknown key returns `false`; the query-key table lives alongside the word and is citable in the compliance doc.

**Given** `docs/ans-forth-core-compliance.md`
**When** updated at the end of this story
**Then** every previously-"gap" word is marked "present" with its source location; the `ENVIRONMENT?` row is moved from Gap Analysis (a) to the implemented list; Gap Analysis (a) (deliberate omissions) is deleted entirely; the post-Epic-10 count is 133 / 133 (100.0%).

**Given** the story scope is bounded at four words
**When** development proceeds
**Then** sharding is not anticipated; if complexity surfaces a larger scope, the story may be sharded into 10.9a / 10.9b by capability sub-family (each independently completable; shard boundaries recorded in sprint-status tracking).

### Story 10.10: Epic 10 compliance audit, benchmark + regression gate (CCD-4)

As an antforth maintainer,
I want Epic 10 to close with a verified 100% Core compliance measurement, a double-precision benchmark, and a full Phase-1 + Epic-9 regression pass,
So that NFR5 (double-precision performance), NFR9 (regression), NFR10 (100% Core), NFR4 (ROM delta), and FR15 are demonstrably satisfied and `antforth 1.10` can be tagged as the "100% ANS Core" release.

**Acceptance Criteria:**

**Given** the updated `docs/ans-forth-core-compliance.md`
**When** the compliance methodology is re-run
**Then** coverage is **100%** of the ANS Forth 1994 Core wordset — the headline FR15/NFR10 deliverable.

**Given** representative double-precision primitives (`D+`, `D-`, `M*`, `UM/MOD`)
**When** benchmarked against hand-rolled Z80 equivalents
**Then** the measured cycle counts are within ~20% of the hand-rolled baselines per NFR6; results recorded in the epic's benchmark notes.

**Given** the kernel ROM size after Epic 10
**When** compared against the post-Epic-9 baseline
**Then** the delta is recorded; Epic 10 adds net functionality, so a temporary increase is acceptable (Epics 12 and 13 are the planned ROM-shrinking epics).

**Given** the full Phase-1 + Epic-9 REPL-piped test suites
**When** run against the Epic-10 binary
**Then** every test passes — zero regressions per NFR9 / FR45 / FR46.

**Given** the `.`/`U.`/`D.`/`.R`/`U.R`/`D.R` family reimplemented on pictured output
**When** run against the Epic 1–8 display-output test cases
**Then** output is byte-identical to the pre-Epic-10 baseline — FR45 verified.

**Given** a real-MicroBeast-hardware smoke test
**When** the full Epic-10 test suite is piped into the `.COM` on hardware
**Then** it passes — PRD MVP rule satisfied; `antforth 1.10` release can be tagged.

## Epic 11: Exception Subsystem & Internal Error Migration

Users can catch errors with `CATCH`/`THROW`, receive standard ANS THROW codes, and keep their REPL session alive across any error; every internal error path in the interpreter, compiler, and primitives is migrated from `ABORT` to `THROW` (word-by-word per E11-D3); `ABORT`/`ABORT"` become standard wrappers for `-1 THROW`/`-2 THROW`. A migration-inventory story at the front of the epic makes the crawl scope visible before the word-by-word work begins. Delivers Mo's "catch a bug without losing the session" moment. Shippable as antforth 1.11.

### Story 11.1: ABORT-site migration inventory + THROW code table + code EQUs

As an antforth maintainer,
I want the full inventory of every existing `ABORT` call site across all `*.asm` files, a complete ANS + antforth THROW code table, and the THROW code EQUs pre-populated in `src/constants.asm`,
So that the word-by-word migration in stories 11.4–11.6 has clear, non-colliding numerical references and predictable ordering, and so Epic 11's scope is visible before the crawl begins (party-mode note).

**Acceptance Criteria:**

**Given** every file under `src/*.asm`
**When** surveyed for `ABORT`, `ABORT"`, or equivalent error-emission paths
**Then** each call site is catalogued by file, word, error condition, and proposed ANS THROW code (or antforth extension code); the inventory is recorded in `docs/throw-codes.md`.

**Given** the ANS Forth 2014 §9.3.5 THROW code table
**When** transcribed into `docs/throw-codes.md`
**Then** all 58 standard codes (`-1` through `-58`) appear with their human-readable names and brief descriptions per CCD-2.

**Given** any antforth-specific THROW code identified by the survey
**When** allocated
**Then** it lands in the `-256` to `-32767` antforth extension range per CCD-2 with a one-line rationale in `docs/throw-codes.md`.

**Given** `src/constants.asm`
**When** updated
**Then** it contains EQU symbols for every THROW code used in the codebase (e.g., `THROW_STACK_UNDERFLOW EQU -4`, each with a citation comment per NFR17/CCD-3).

**Given** the inventory
**When** complete
**Then** it proposes a migration ordering (leaf primitives → compiler/dictionary → REPL → `ABORT`/`ABORT"` last per E11-D3 rationale) that is consumed by Stories 11.4–11.7.

### Story 11.2: Exception frame infrastructure + `CATCH` word

As a Forth user,
I want to wrap the execution of any execution token in a `CATCH` frame and receive `0` when the word exits normally,
So that I have a safety harness around user code — the foundation for every subsequent error-handling workflow.

**Acceptance Criteria:**

**Given** CCD-1's dual-chain discipline
**When** the kernel boots
**Then** a new USER variable `CATCH-TOP` exists, initialised to `0`.

**Given** E11-D1's 8-byte exception frame layout (saved SP, saved BC = i*x's TOS-cell value per Story 11.4.1, catching-IP, previous-CATCH-TOP)
**When** `CATCH` is invoked with an xt on TOS
**Then** it pushes an 8-byte frame onto the IX return stack in that layout, sets `CATCH-TOP` to the new frame's address, and executes the xt.

**Given** the xt returns normally (no THROW)
**When** `CATCH` resumes
**Then** it restores `CATCH-TOP` from the frame's prev-link, pops the 8-byte frame, and pushes `0` onto the parameter stack per ANS §6.1.0875 / Forth 2014 §9.6.1.0875.

**Given** new file `src/exception.asm`
**When** `CATCH` is implemented
**Then** its source carries a Forth 2014 §9.6.1.0875 / §6.1.0875 citation per NFR17/CCD-3; stack-effect comment `( xt -- exception-code | 0 )` on its DEFCODE.

**Given** `tests/exception_tests.fth`
**When** it runs
**Then** `CATCH` is tested with normal-return xts of varying stack effects (pure, producing, consuming), nested CATCH frames (inner then outer both normal-return), and empty-body xts — all must return 0 and leave `CATCH-TOP` at its entry-time value.

### Story 11.3: `THROW` word + uncaught-THROW REPL handler

As a Forth user,
I want to raise a non-zero THROW code and have it caught by the nearest enclosing `CATCH` — or, if uncaught, see a clean diagnostic and return to a live REPL with my session and dictionary intact,
So that error handling is composable and the REPL survives any error (FR22, NFR7).

**Acceptance Criteria:**

**Given** E11-D2's THROW algorithm (O(1) `CATCH-TOP` access; `INCLUDE-TOP` chain walk — empty at this epic, per CCD-1 designed-for-future)
**When** `THROW` is invoked with a non-zero code and `CATCH-TOP` ≠ 0
**Then** the algorithm walks the (currently empty) `INCLUDE-TOP` chain to the target frame (a no-op), restores SP and IX from the target frame, pushes the THROW code, restores `CATCH-TOP` from the frame's prev-link, pops the exception frame, and resumes at the frame's catching-IP.

**Given** `CATCH-TOP = 0`
**When** `THROW` is invoked with a non-zero code
**Then** the uncaught-THROW handler: (a) prints a diagnostic of the form `error N: <description>` using `docs/throw-codes.md` table entries; (b) resets the parameter stack to empty, return stack to empty, input buffer to fresh state; (c) prints the REPL prompt; (d) dictionary and in-session definitions remain intact (NFR7, NFR8).

**Given** `THROW 0`
**When** invoked
**Then** nothing happens (ANS §9.6.1.2275 no-op for zero).

**Given** `src/exception.asm`
**When** `THROW` is implemented
**Then** Forth 2014 §9.6.1.2275 citation per NFR17/CCD-3; stack-effect `( n -- )`.

**Given** `tests/exception_tests.fth`
**When** it runs
**Then** it covers: (a) `' word CATCH THROW` round-trip returning the code on stack; (b) nested `CATCH`es where the inner catches and the outer doesn't see anything; (c) nested `CATCH`es where only the outer catches; (d) uncaught THROW re-enters the REPL with session state verified intact by subsequent `WORDS` / constant-value checks.

### Story 11.4: Internal error migration — stack, arithmetic, memory primitives

As a Forth user,
I want the error paths in stack, arithmetic, and memory primitives to raise standard ANS THROW codes rather than `ABORT`,
So that I can catch these errors with `CATCH` and handle them programmatically (partial FR19 delivery).

**Acceptance Criteria:**

**Given** every stack primitive (`DUP`, `DROP`, `SWAP`, `OVER`, `ROT`, etc.) in `src/stack_ops.asm`
**When** invoked with insufficient stack depth
**Then** the word raises `-4 THROW` (stack underflow, ANS §9.3.5); `CATCH`-ing it yields `-4` on stack.

**Given** arithmetic primitives in `src/arithmetic.asm` (division, mod, and any division-producing-word)
**When** invoked with a zero divisor
**Then** the word raises `-10 THROW` (division by zero, ANS §9.3.5); `CATCH`-ing it yields `-10`.

**Given** memory primitives in `src/memory.asm` (`@`, `!`, `C@`, `C!`, `+!`, `FILL`, `MOVE`) where stack-underflow is possible
**When** invoked with insufficient arguments
**Then** `-4 THROW` is raised consistently.

**Given** each migrated primitive (per E11-D3 one-commit-per-migration discipline)
**When** the migration commit lands
**Then** `tests/throw_migration_tests.fth` gains a new case asserting the correct THROW code via `CATCH`; all prior tests continue to pass.

**Given** the `TOS-in-register & DEPTH` discipline (project memory)
**When** a stack-underflow THROW fires from BC=TOS territory
**Then** the post-THROW state satisfies the DEPTH invariant (BC may be phantom; `DEPTH = 0` semantics preserved).

### Story 11.5: Internal error migration — dictionary, compiler, control flow

As a Forth user,
I want error paths in dictionary lookup, the compiler, and control-flow constructs to raise standard ANS THROW codes,
So that compile-time errors and lookup failures compose with `CATCH` (partial FR19 delivery).

**Acceptance Criteria:**

**Given** an undefined word at the outer interpreter
**When** encountered during INTERPRET
**Then** `-13 THROW` (undefined word, ANS §9.3.5) is raised; `CATCH`-ing around `EVALUATE` or `INTERPRET` yields `-13`.

**Given** compile-state violations in `src/compiler.asm` (attempt to compile outside a definition, `;` without matching `:`, etc.)
**When** encountered
**Then** appropriate ANS THROW codes are raised (e.g., `-14` interpreting a compile-only word, `-22` control structure mismatched, etc., per `docs/throw-codes.md`).

**Given** control-flow words in `src/control_flow.asm` (`IF`/`ELSE`/`THEN`, `BEGIN`/`UNTIL`, `DO`/`LOOP` at compile time)
**When** mismatched (e.g., `ELSE` without `IF`, `LOOP` without `DO`)
**Then** `-22 THROW` (control structure mismatched) is raised; `CATCH`-ing it in a compilation test yields `-22`.

**Given** each migrated site
**When** the migration commit lands
**Then** `tests/throw_migration_tests.fth` gains cases asserting the correct code; all prior tests continue to pass.

### Story 11.6: Internal error migration — strings, I/O, remaining error sites

As a Forth user,
I want the remaining error paths (string operations, I/O, any uncovered sites) to raise standard ANS THROW codes,
So that all kernel error emission is uniformly THROW-based before `ABORT` is retargeted in Story 11.7 (completes FR19 pre-`ABORT`-retarget).

**Acceptance Criteria:**

**Given** the inventory from Story 11.1 filtered to remaining unmigrated sites
**When** the survey is re-run after Stories 11.4 and 11.5
**Then** only string-ops, I/O, and miscellaneous sites remain; this story migrates each.

**Given** string-op primitives in `src/strings.asm` where bounds violations are possible
**When** a bounds violation occurs
**Then** the appropriate ANS THROW code is raised (e.g., `-18` parse-string range error).

**Given** I/O paths in `src/io.asm`, `src/formatting.asm` that raise errors (e.g., invalid radix in `BASE`)
**When** an error condition arises
**Then** a documented THROW code is raised.

**Given** `tests/throw_migration_tests.fth`
**When** Story 11.6 is complete
**Then** every site in Story 11.1's inventory (except `ABORT` and `ABORT"` themselves — Story 11.7) is represented by a catch-and-assert test case.

**Given** Story 11.1's inventory
**When** re-checked after this story
**Then** zero ABORT sites remain outside of `ABORT` and `ABORT"` themselves — the migration is complete except for the last step.

### Story 11.7: `ABORT` and `ABORT"` retargeted as THROW wrappers (capstone)

As a Forth user,
I want `ABORT` and `ABORT"` to become standard ANS wrappers for `-1 THROW` and `-2 THROW` respectively,
So that all kernel error emission, including the two legacy user-facing error words, is fully unified under the exception mechanism (FR20).

**Acceptance Criteria:**

**Given** `src/system.asm`
**When** `ABORT` is reimplemented
**Then** it is equivalent to `-1 THROW` per ANS §6.1.0670 / Forth 2014 §9.6.2.0670; any prior ad-hoc stack/state resets embedded in `ABORT` are gone (now handled by the uncaught-THROW REPL handler from Story 11.3).

**Given** `ABORT"` at runtime
**When** invoked with a truthy flag
**Then** it emits the stored message and raises `-2 THROW` per ANS §6.1.0680 / Forth 2014 §9.6.2.0680.

**Given** the full regression suite (Phase-1 + Epic-9 + Epic-10 + Epic-11 prior stories)
**When** run
**Then** every test passes — previously-ABORT-emitting code paths now go through `-1 THROW` / `-2 THROW` and end up in the same REPL-reset behaviour.

**Given** `CATCH`-ing `ABORT`
**When** invoked (`' some-word-that-ABORTs CATCH`)
**Then** `-1` is returned on stack — caught-ABORT now just works per ANS.

**Given** this story being explicitly *last* in the migration sequence per E11-D3
**When** it lands
**Then** no path in the kernel double-throws (no `ABORT` → `-1 THROW` → second `ABORT`).

### Story 11.8: Epic 11 benchmark, survivability stress + regression gate (CCD-4)

As an antforth maintainer,
I want Epic 11 to close with an NFR4 overhead measurement, a REPL-survivability stress suite (NFR7), a state-integrity verification (NFR8), and a full regression pass,
So that the exception subsystem's performance, correctness, and safety envelopes are verified before `antforth 1.11` is tagged.

**Acceptance Criteria:**

**Given** an empty-body xt wrapped in `CATCH` with normal return
**When** the NFR4 benchmark thread runs against it on the emulator
**Then** the measured CATCH-frame push + pop + `CATCH-TOP` update overhead is **≤ ~15 Z80 cycles** per NFR4; recorded in the epic's benchmark notes.

**Given** a `THROW` triggered from nested depth N
**When** the unwind completes
**Then** the cycle count is bounded and proportional to N (no hidden exponential paths per NFR4 bounded-time requirement).

**Given** a REPL survivability stress test (`tests/exception_tests.fth` extended)
**When** each of the following errors is induced: stack underflow, stack overflow, division by zero, undefined word, compile-state mismatch, `ABORT"` with truthy flag
**Then** every error returns the REPL to a live prompt; `WORDS` still lists user definitions; `MARKER`-saved state is recoverable; `BASE` is unchanged (FR22 / NFR7 / NFR8).

**Given** the post-THROW integrity audit
**When** checked after each induced error
**Then** input buffer, dictionary HERE, parameter stack, return stack, `CATCH-TOP`, and USER-area invariants are all in consistent states (NFR8).

**Given** the kernel ROM size
**When** compared against post-Epic-10 baseline
**Then** delta recorded; Epic 11 is expected to add some ROM (exception subsystem); Epics 12/13 plan to recover it per NFR5 phase-wide negative target.

**Given** the full Phase-1 + Epic-9 + Epic-10 test suites
**When** run against the Epic-11 binary
**Then** every test passes — zero regressions per NFR9 / FR45 / FR46.

**Given** a real-MicroBeast-hardware smoke test
**When** the full Epic-11 test suite (including the stress suite) is piped into the `.COM` on hardware
**Then** it passes — PRD MVP rule satisfied; `antforth 1.11` release can be tagged.

## Epic 12: Multi-Vocabulary Search-Order & ASSEMBLER Wordlist

Users can create and manage multiple wordlists, control the search order, direct definitions into specific wordlists, and benefit from automatic `ASSEMBLER` wordlist activation inside `CODE`/`END-CODE` — all while existing CODE source files assemble unchanged. The `ASSEMBLER` wordlist is populated from the existing kernel-resident opcode words (no migration to a Forth-source file is planned for Phase 2). Shippable as antforth 1.12.

### Story 12.1: Wordlist struct + hash parameterisation + `FORTH-WORDLIST` bootstrap

As an antforth maintainer,
I want the per-wordlist 130-byte struct defined, the dictionary hash lookup parameterised on a wordlist-struct address, and the existing flat dictionary migrated to live inside a canonical `FORTH-WORDLIST`,
So that the kernel has a working multi-vocabulary infrastructure before any user-facing wordlist words are introduced (FR28 delivered; FR23–FR30 unblocked).

**Acceptance Criteria:**

**Given** E12-D1's layout (2-byte next-wordlist chain pointer + 64-entry × 2-byte hash-bucket array)
**When** the kernel boots
**Then** a pre-built `FORTH-WORDLIST` struct exists in known-address kernel memory, populated with all existing kernel primitives' dictionary entries across its 64 buckets.

**Given** `src/hash.asm`
**When** the XOR-rotate 64-bucket lookup is refactored
**Then** it takes a wordlist-struct address as a parameter (HL or equivalent per register conventions) and hashes into *that* struct's bucket array — no global fixed bucket table remaining.

**Given** `src/dictionary.asm`
**When** word insertion runs
**Then** it inserts into a caller-supplied wordlist struct (by default `FORTH-WORDLIST`); no more hard-wired single-table assumptions.

**Given** the kernel at boot
**When** FORTH-WORDLIST is the only wordlist in the initial search order
**Then** every pre-Epic-12 word is findable exactly as before — zero lookup regression for the single-wordlist case (NFR2 tested as a per-story gate, full envelope in Story 12.8).

**Given** new file `src/wordlists.asm`
**When** the struct and supporting macros are defined
**Then** `WORDLIST_SIZE EQU 130`, `WORDLIST_BUCKETS EQU 64`, and layout-offset constants are defined for use by subsequent stories; each has a citation comment per NFR17/CCD-3 where applicable.

**Given** `tests/wordlist_tests.fth`
**When** it runs at this story's completion
**Then** it confirms `FORTH-WORDLIST` (implemented in Story 12.3 as a user-facing word — for now accessed via its known address) is the current compilation and search wordlist; every Phase-1 + Epic-9/10/11 test still passes (NFR9).

### Story 12.2: `WORDLIST` and `SEARCH-WORDLIST`

As a Forth user,
I want to create new empty wordlists at runtime and search any specific wordlist by identifier,
So that I can partition my definitions into named namespaces (FR23) and perform targeted lookups (FR29).

**Acceptance Criteria:**

**Given** `WORDLIST` per ANS §16.6.1.2460
**When** I invoke `WORDLIST`
**Then** it `ALLOT`s 130 bytes at `HERE`, initialises all 64 bucket entries to `$0000` and the next-wordlist chain pointer to `0`, and returns the struct's address on TOS as the wordlist identifier (`wid`).

**Given** `SEARCH-WORDLIST` per ANS §16.6.1.2192
**When** I invoke `c-addr u wid SEARCH-WORDLIST`
**Then** it searches only the specified wordlist (not the search order) and returns either `(xt 1 | -1 | 0)` per the standard's stack effect.

**Given** a freshly created wordlist
**When** it is searched before any definitions are added to it
**Then** `SEARCH-WORDLIST` returns `0` (not found).

**Given** the source
**When** both words are implemented
**Then** ANS §16.6.1.2460 and §16.6.1.2192 citations appear per NFR17/CCD-3; stack-effect comments on DEFCODE lines.

**Given** `tests/wordlist_tests.fth`
**When** it runs
**Then** it covers: creating a wordlist, attempting lookup (miss), adding a definition (via SET-CURRENT + `:` — Story 12.4) or via low-level primitive, re-lookup (hit, returns correct xt), and lookup collision-chain behaviour.

### Story 12.3: Search-order infrastructure — `GET-ORDER`, `SET-ORDER`, `FORTH-WORDLIST`

As a Forth user,
I want to read and write the current search order and reference the built-in Forth wordlist by name,
So that I can compose multi-wordlist lookup strategies (FR24, FR28).

**Acceptance Criteria:**

**Given** E12-D2's design (16-slot array in user area + `SEARCH-ORDER-DEPTH` USER variable)
**When** the kernel boots
**Then** the array holds `FORTH-WORDLIST` at slot 0 and `SEARCH-ORDER-DEPTH` = 1.

**Given** `GET-ORDER` per ANS §16.6.1.1647
**When** invoked
**Then** it pushes the wordlists onto the parameter stack top-of-search-order-first followed by the depth (count): `( -- widn ... wid1 n )`.

**Given** `SET-ORDER` per ANS §16.6.1.2195
**When** invoked with `( widn ... wid1 n -- )`
**Then** it writes those wordlists back into the search-order array in the same order and updates `SEARCH-ORDER-DEPTH`; a depth > 16 raises `-49 THROW` (search-order overflow, ANS §9.3.5).

**Given** `SET-ORDER -1`
**When** invoked
**Then** the implementation-defined minimum search order is installed — for antforth, this is `FORTH-WORDLIST` at slot 0, depth 1 per ANS option.

**Given** `FORTH-WORDLIST` per ANS §16.6.1.1595
**When** invoked
**Then** it pushes the canonical Forth wordlist's struct address onto TOS.

**Given** the outer interpreter's word-lookup path
**When** a token is parsed
**Then** the lookup walks the search order from top (slot 0) down, hashing into each wordlist's bucket array and stopping at the first hit; NFR2's 10% regression budget is measured in Story 12.8 against this path.

**Given** `tests/wordlist_tests.fth`
**When** extended
**Then** it covers: `GET-ORDER` initial state; `SET-ORDER` round-trip; search with 2+ wordlists where the same word name lives in multiple and top-of-order wins; attempt to set depth > 16 catches `-49`.

### Story 12.4: Compilation wordlist control — `GET-CURRENT`, `SET-CURRENT`, `DEFINITIONS`

As a Forth user,
I want to control which wordlist new definitions are added to,
So that I can partition my definitions by subsystem without polluting the default `FORTH-WORDLIST` (FR25, FR26).

**Acceptance Criteria:**

**Given** a USER variable `CURRENT-WORDLIST` (or equivalent) that tracks the compilation wordlist
**When** the kernel boots
**Then** it is set to `FORTH-WORDLIST`.

**Given** `GET-CURRENT` per ANS §16.6.1.1643
**When** invoked
**Then** it returns the current compilation wordlist's wid on TOS.

**Given** `SET-CURRENT` per ANS §16.6.1.2193
**When** invoked with a wid on TOS
**Then** subsequent definitions (`:`, `CODE`, `CREATE`, `VARIABLE`, `CONSTANT`, `MARKER`, etc.) are placed into that wordlist's hash table.

**Given** `DEFINITIONS` per ANS §16.6.1.1180
**When** invoked
**Then** `SET-CURRENT` is called with the wid at slot 0 of the search order — i.e., "direct subsequent definitions into the top wordlist."

**Given** a freshly created wordlist `W` and sequence `W SET-CURRENT : FOO ; FORTH-WORDLIST SET-CURRENT`
**When** `FOO` is looked up with only `FORTH-WORDLIST` in the search order
**Then** lookup fails; when `W` is added to the search order, lookup succeeds — confirming the definition landed in `W` rather than `FORTH-WORDLIST`.

**Given** `tests/wordlist_tests.fth`
**When** extended
**Then** it covers the round-trip above, `DEFINITIONS`-driven partitioning with 2+ wordlists, and that standard word definitions (e.g., `VARIABLE`, `CONSTANT`) all honour the current compilation wordlist.

### Story 12.5: `ONLY`

As a Forth user,
I want to reduce my search order to a minimal standards-specified set,
So that I can clear out accumulated cruft and reset namespace visibility (FR27).

**Acceptance Criteria:**

**Given** `ONLY` per ANS §16.6.2.1965
**When** invoked
**Then** it sets the search order to the implementation-defined minimal set; for antforth, this is `FORTH-WORDLIST` at slot 0 with depth 1 (per ANS option).

**Given** `ONLY` is in the ANS Search-Order Extension wordset (§16.6.2)
**When** the source is authored
**Then** its citation comment is `; ANS Forth 1994 §16.6.2.1965 ONLY` per NFR17/CCD-3.

**Given** `tests/wordlist_tests.fth`
**When** extended
**Then** it confirms `SET-ORDER` to a 5-wordlist state followed by `ONLY` yields a depth of 1 with `FORTH-WORDLIST` at slot 0.

### Story 12.6: `ASSEMBLER` wordlist + auto-activation in `CODE`/`END-CODE`

As a Forth user,
I want the `ASSEMBLER` wordlist to activate automatically inside `CODE`/`END-CODE` blocks and deactivate cleanly afterwards,
So that opcode words are visible exactly where they're needed — no `ALSO ASSEMBLER` incantation required at every `CODE` site (FR30).

**Acceptance Criteria:**

**Given** the kernel boot sequence
**When** it completes
**Then** an `ASSEMBLER` wordlist struct exists (created via `WORDLIST`); every built-in Z80 opcode word from `src/assembler.asm` is registered under the `ASSEMBLER` wordlist rather than `FORTH-WORDLIST`. Opcodes remain kernel-resident for the life of Phase 2 — no relocation to a Forth-source file is planned.

**Given** E12-D4's save/restore pattern
**When** `CODE` is invoked
**Then** it pushes the current `SEARCH-ORDER-DEPTH` onto the rstack (or a dedicated save slot), adds `ASSEMBLER` to the top of the search order, and sets `CURRENT-WORDLIST` to `ASSEMBLER` so assembler-level CODE helpers compile into it.

**Given** `END-CODE`
**When** invoked
**Then** it restores the pre-`CODE` search order and `CURRENT-WORDLIST`.

**Given** nested `CODE`/`END-CODE` blocks (unusual but well-defined)
**When** invoked
**Then** the save/restore composes correctly — outer restores pre-outer state, inner restores outer state.

**Given** `tests/assembler_wordlist_tests.fth`
**When** it runs
**Then** it verifies: (a) assembler opcodes are invisible outside `CODE`/`END-CODE`; (b) they are visible inside; (c) `END-CODE` correctly restores pre-block search order; (d) every pre-phase CODE source file assembles unchanged (FR31, NFR14 — full coverage in Story 12.7).

**Given** the Story 10.7 asm-`#` dispatch hack at `src/assembler.asm` (`w_HASH_cf` dispatches on `asm_mode`: clear → `JP w_PIC_HASH_cf` for the §6.1 pictured-output `#`, set → immediate-operand sigil)
**When** Story 12.6 lands
**Then** the hack **must be removed** — with the assembler `#` registered in the `ASSEMBLER` wordlist and the pictured `#` in `FORTH-WORDLIST`, the two words no longer share a name in the lookup path. Restore `w_HASH_cf` to its pre-Story-10.7 form (single `CALL check_asm_mode` preamble; sigil body unchanged). Verify by: (a) `asm_mode`-based `JP Z, w_PIC_HASH_cf` line is gone from `src/assembler.asm`; (b) `#` outside `CODE` resolves to the pictured word via normal search-order lookup (not via run-time dispatch); (c) Story 10.7's REPL tests 550..572 still pass byte-identically; (d) `tests/number_prefixes_tests.fth` CODE-block tests using `#` still pass. Record net kernel-size delta from hack removal (expected: −4 bytes).

### Story 12.7: Epic 12 benchmark, CODE backward-compat suite + regression gate (CCD-4)

As an antforth maintainer,
I want Epic 12 to close with NFR2 measurement, an exhaustive CODE-source-file backward-compat suite, ROM delta accounting, and a full regression pass,
So that multi-vocabulary lookup performance, byte-identical CODE assembly, and overall correctness are verified before `antforth 1.12` is tagged.

**Acceptance Criteria:**

**Given** a benchmark with the search order populated to 8 wordlists (most lookups missing the top wordlists and falling through to `FORTH-WORDLIST`)
**When** the word-lookup cycle count is measured
**Then** the regression vs the pre-Epic-12 single-vocabulary baseline is **≤ 10%** per NFR2; results recorded in the epic's benchmark notes.

**Given** a benchmark with a hit at slot 0 of the search order
**When** measured
**Then** the regression vs the pre-Epic-12 baseline is near-zero (the common case should not suffer).

**Given** every pre-phase-2 CODE source file in the project's test corpus
**When** assembled against the Epic-12 binary
**Then** output is byte-identical to the pre-phase-2 reference — FR31, NFR14 verified comprehensively.

**Given** the kernel ROM size
**When** measured against the post-Epic-11 baseline
**Then** the Epic-12 kernel-size delta is recorded; the additions (Search-Order machinery, per-wordlist hash layout, `ASSEMBLER` wordlist registration, `CODE`/`END-CODE` auto-activation hooks) are expected to grow the kernel, and the growth is justified line-by-line against NFR4 (per-epic budget, not a net-negative gate).

**Given** the full Phase-1 + Epics 9/10/11 test suites
**When** run against the Epic-12 binary
**Then** every test passes — zero regressions per NFR9 / FR45 / FR46.

**Given** a real-MicroBeast-hardware smoke test
**When** the full Epic-12 test suite runs on hardware
**Then** it passes — PRD MVP rule satisfied; `antforth 1.12` release can be tagged.

## Epic 13: File-Access

Users can load and save source files against the CP/M 2.2 filesystem (`INCLUDE`/`INCLUDED`/`INCLUDE-FILE`/`OPEN-FILE`/`CREATE-FILE`/`READ-FILE`/`WRITE-FILE`/`FILE-POSITION`/`REPOSITION-FILE`/`FILE-SIZE`/`CLOSE-FILE`/`DELETE-FILE`). File errors raise `THROW`. Closes with the Phase-2 release gate — full regression of Epics 1–12, BDOS-function-allow-list audit, filesystem-error stress suite, kernel ROM-delta accounting, and MicroBeast hardware validation. Passing the gate tags **antforth 2.0**.

### Story 13.1: File I/O sanity — FCB pool + BDOS wrapper layer (PRD risk mitigation)

As an antforth maintainer,
I want the 288-byte FCB pool and the internal BDOS wrapper layer implemented and exercised against a known-good CP/M image *before* any user-facing file-access words are introduced,
So that CP/M 128-byte record boundaries, EOF handling, and BDOS call conventions are validated on their own terms — avoiding mid-epic surprises called out in the PRD risk table.

**Acceptance Criteria:**

**Given** E13-D1's decision (kernel-resident static array)
**When** new file `src/file_access.asm` is built
**Then** it contains `fcb_pool: ds 288` (8 × 36-byte FCBs) as a labelled byte region, linked into the `.COM` binary at build time, accessed by absolute address; `FCB_SIZE EQU 36` and `FCB_POOL_COUNT EQU 8` are defined.

**Given** E13-D3's BDOS wrapper layer
**When** `src/file_access.asm` is authored
**Then** it exposes private helpers for: open (BDOS 15), close (16), delete (19), create (22), read sequential record (20), write sequential record (21), read random record (33), write random record (34), compute file size (35), get current drive (25); plus a byte-oriented read/write layer that handles the 128-byte record impedance using an in-FCB buffer.

**Given** NFR13 (BDOS allow-list)
**When** the wrapper layer is authored
**Then** every BDOS call uses a function number from the NFR13 allow-list; a source-level comment at each call site cites the BDOS function number and its purpose.

**Given** the pool-acquire primitive
**When** invoked with all 8 FCBs in use
**Then** it raises `-69 THROW` (ANS §9.3.5 "file access method") with citation per CCD-2 / NFR17.

**Given** a known-good CP/M 2.2 disk image in the project's `disk/` directory
**When** an internal test thread exercises: open, read 200 bytes (spans a record boundary), seek via internal primitive, read across EOF, close, delete
**Then** every step behaves exactly as the CP/M 2.2 BDOS spec documents; the test thread's output matches a pre-recorded reference trace.

**Given** any wrapper that holds an FCB across a BDOS call
**When** the call returns
**Then** the FCB state is well-defined — either fully opened, fully closed, or returned to the pool's free list; no intermediate leaks.

**Given** `tests/file_access_tests.fth` stub
**When** it runs at this story's completion
**Then** user-facing file-access words are not yet present (those are Story 13.2+), but the story's own internal-primitive test harness prints a pass summary and halts.

### Story 13.2: Core File-Access wordset — `OPEN-FILE`, `CREATE-FILE`, `CLOSE-FILE`, `DELETE-FILE`, `READ-FILE`, `WRITE-FILE`

As a Forth user,
I want the core ANS File-Access wordset for opening, closing, creating, deleting, and byte-oriented reading/writing of files against the CP/M 2.2 filesystem,
So that I can read and write source files and data files from my antforth session (FR35–FR39, FR42).

**Acceptance Criteria:**

**Given** `OPEN-FILE` per ANS §11.6.1.1970 with stack effect `( c-addr u fam -- fileid ior )`
**When** I open an existing file with mode `R/O`, `R/W`, `W/O`, or `BIN`
**Then** a FID is returned with `ior = 0` on success, or `0 <error>` with an ANS-standard `ior` code on failure.

**Given** `CREATE-FILE` per ANS §11.6.1.1010
**When** invoked with a non-existent filename and an access mode
**Then** the file is created (or truncated if it exists) and a valid FID is returned.

**Given** `DELETE-FILE` per ANS §11.6.1.1190
**When** invoked with a filename
**Then** the file is deleted if present; the appropriate `ior` is returned per the standard.

**Given** `READ-FILE` per ANS §11.6.1.2080 `( c-addr u1 fileid -- u2 ior )`
**When** reading `u1` bytes across a 128-byte record boundary
**Then** `u2` bytes (≤ `u1`) are returned in the user buffer with `ior = 0`; on EOF, `u2` reflects the number actually read (may be zero) with `ior = 0`.

**Given** `WRITE-FILE` per ANS §11.6.1.2480
**When** writing into a R/W or W/O file
**Then** bytes are buffered through the wrapper layer's in-FCB buffer, flushed on record boundaries, and on `CLOSE-FILE`; a subsequent read of the same file returns the written bytes verbatim.

**Given** `CLOSE-FILE` per ANS §11.6.1.0900
**When** invoked on a FID
**Then** buffered writes (if any) are flushed, the FCB is returned to the pool, and the FID becomes invalid; subsequent operations on that FID raise `-70 THROW` (file access method).

**Given** FR43 (file-op errors use THROW, not ABORT)
**When** a lower-level BDOS error occurs during any File-Access word
**Then** the word raises a THROW with an ANS-standard code from `docs/throw-codes.md`; `ior` return values are non-zero only for recoverable-by-design cases (not for catastrophic errors which throw).

**Given** `tests/file_access_tests.fth`
**When** it runs
**Then** it covers: create + write + close + reopen + read-back (round-trip integrity); delete + reopen (confirm gone); read across record boundary; read across EOF; pool-exhaustion (open 9 files → 9th catches `-69`); R/O-write-attempt (catches standard ior).

### Story 13.3: File positioning — `FILE-POSITION`, `REPOSITION-FILE`, `FILE-SIZE`

As a Forth user,
I want to query and set the current byte position in a file and query a file's size,
So that I can do random-access reads/writes and progress-bar-style file consumption (FR40, FR41).

**Acceptance Criteria:**

**Given** `FILE-POSITION` per ANS §11.6.1.1520 `( fileid -- ud ior )`
**When** invoked on an open FID
**Then** it returns the current byte position as a double-cell unsigned value.

**Given** `REPOSITION-FILE` per ANS §11.6.1.2142 `( ud fileid -- ior )`
**When** invoked with a byte position within the file
**Then** subsequent `READ-FILE` / `WRITE-FILE` operate starting at that position.

**Given** `FILE-SIZE` per ANS §11.6.1.1522 `( fileid -- ud ior )`
**When** invoked
**Then** it returns the file's size in bytes as a double-cell unsigned value.

**Given** CP/M's 128-byte record model
**When** `REPOSITION-FILE` crosses a record boundary
**Then** the in-FCB buffer is correctly invalidated/reloaded so the subsequent byte-oriented read returns the correct byte.

**Given** `tests/file_access_tests.fth` extended
**When** it runs
**Then** it covers: write known bytes at known offsets, `REPOSITION-FILE` + `READ-FILE` round-trip, `FILE-SIZE` matches the total bytes written, boundary positions at record edges (127/128/129 bytes).

### Story 13.4: Source-input nesting — `INCLUDED` / `INCLUDE-FILE` / `INCLUDE` with INCLUDE-TOP chain discipline

As a Forth user,
I want to load Forth source from a file into my running session — with nested `INCLUDE` support, correct EOF handling, and guaranteed file-handle cleanup on any THROW (no orphaned FIDs),
So that I can build sessions from multiple source files and recover cleanly from errors (FR32, FR33, FR34, NFR9).

**Acceptance Criteria:**

**Given** E13-D2's 10-byte INCLUDE source frame layout (prev-link + saved SOURCE-ID + saved input-buffer-addr + saved input-buffer-length + saved `>IN`)
**When** `INCLUDED` per ANS §11.6.1.1718 is invoked with `c-addr u` (filename)
**Then** it opens the file, pushes the 10-byte frame, links via `INCLUDE-TOP`, switches SOURCE-ID to the new FID, and returns control to the outer interpreter which now parses from the file.

**Given** EOF during `INCLUDED`
**When** the outer interpreter hits end-of-file
**Then** the current FID is closed, parent input state is restored from the frame, `INCLUDE-TOP` is set to the frame's prev-link, the 10-byte frame is popped, and parsing resumes on the parent source.

**Given** `INCLUDE-FILE` per ANS §11.6.1.1717
**When** invoked with an already-open FID
**Then** the same frame-push sequence happens but without an initial `OPEN-FILE`; the caller retains ownership of the FID for ongoing file operations but the outer interpreter reads it as SOURCE.

**Given** `INCLUDE` per ANS §11.6.2.1717 (Forth 2014 extension)
**When** invoked with a filename token (parsed from the input stream)
**Then** it behaves as `BL WORD COUNT INCLUDED`.

**Given** a THROW occurring mid-INCLUDE
**When** Story 11.3's THROW algorithm walks the `INCLUDE-TOP` chain to the target exception frame
**Then** each INCLUDE source frame above the target is cleaned up: FID closed, frame popped, `INCLUDE-TOP` chain relinked — satisfying NFR9 (no orphaned FIDs after THROW).

**Given** FR44 (drive equivalence)
**When** the filename argument contains a CP/M drive letter (`A:FOO.FTH`, `B:FOO.FTH`) or no drive letter
**Then** `INCLUDE` / `INCLUDED` work identically across drives with no syntactic distinction.

**Given** NFR21 (CP/M path syntax)
**When** filenames are passed
**Then** CP/M 2.2 8.3 syntax + optional drive letter is accepted; wildcards and Unix-style paths are not supported; malformed paths raise an appropriate THROW.

**Given** `tests/file_access_tests.fth` extended
**When** it runs
**Then** it covers: single `INCLUDE` of a known file; nested `INCLUDE` (A includes B includes C); `INCLUDE` that runs a THROW mid-file → FID closed, REPL live, state intact; `INCLUDED` with a bad filename → `-38 THROW` (file not found); pool stress — deep nesting up to 8 FIDs.

### Story 13.5: Epic 13 FS stress, BDOS audit, ROM delta + antforth 2.0 release gate (CCD-4)

As an antforth maintainer,
I want Epic 13 to close with a filesystem-error stress suite (NFR8), a BDOS-function-allow-list audit (NFR13), ROM delta accounting for the phase as a whole (NFR4), and a full Phase-1 + Epics 9–12 regression pass on real MicroBeast hardware,
So that every quantitative envelope set by the PRD is verified and `antforth 2.0` can be tagged — completing the phase.

**Acceptance Criteria:**

**Given** a filesystem-error stress suite (`tests/file_access_tests.fth` extended)
**When** each of the following is induced: disk-full during `WRITE-FILE`; attempt to open 9th file (pool exhausted, `-69`); read from a closed FID (`-70`); `WRITE-FILE` to an `R/O` file; `DELETE-FILE` on a non-existent file
**Then** each error raises a descriptive THROW, the filesystem remains consistent (no corrupted directory entries), and no FID is orphaned in the FCB pool (NFR8).

**Given** an `INCLUDE`-mid-THROW stress test
**When** a THROW fires inside a file being `INCLUDED` from inside another file being `INCLUDED`
**Then** the `INCLUDE-TOP` chain walk closes both FIDs in order, the FCB pool returns to its pre-INCLUDE state, and the REPL is live with state intact (E11+E13 coordination verified).

**Given** NFR13's BDOS function allow-list (1, 2, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 25, 26, 27, 33, 34, 35, 36, 40)
**When** the final binary is audited for BDOS call sites
**Then** every call uses a function number from the allow-list; any call outside the list is a blocker.

**Given** the kernel ROM size
**When** compared against the pre-phase (post-Epic-8) baseline
**Then** the Phase-2 kernel-size delta is recorded; it is expected to be positive (the additions — double-cell + pictured output, exception wordset, Search-Order, File-Access — all add code with no offsetting migration). Per-epic deltas are summed and justified against NFR4 (per-epic budget discipline, not a net-negative gate).

**Given** the full Phase-1 + Epics 9–12 REPL-piped test suites
**When** run against the Epic-13 binary
**Then** every test passes — zero regressions per NFR9 / FR45 / FR46.

**Given** a "define / save-source / INCLUDE-back" round-trip on real hardware
**When** the user defines words, saves source to B: via `WRITE-FILE`, reboots, and `INCLUDE`s the saved file
**Then** the words are restored identically — the on-device edit/test/persist loop is demonstrated working (Journey 1 PRD success criterion).

**Given** a phase-wide compliance re-audit
**When** `docs/ans-forth-core-compliance.md` is re-run
**Then** coverage remains 100% — no Epic-13 change regressed Core compliance.

**Given** a real-MicroBeast hardware smoke test
**When** the full Epic-13 test suite runs on hardware (Phase-1 regressions + Epics 9–12 regressions + new Epic-13 file-access tests + FS stress suite)
**Then** every test passes — PRD MVP rule satisfied.

**Given** all the above AC met
**When** the release is tagged
**Then** the project is **antforth 2.0** — the five-epic phase is complete.
