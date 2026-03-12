---
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
documentsIncluded:
  - prd.md
  - architecture.md
  - epics.md
documentsNotFound:
  - UX Design (none found)
---

# Implementation Readiness Assessment Report

**Date:** 2026-03-12
**Project:** antforth

## Document Inventory

| Document Type | File | Size | Modified |
|---|---|---|---|
| PRD | prd.md | 24,186 bytes | 2026-03-12 |
| Architecture | architecture.md | 29,762 bytes | 2026-03-12 |
| Epics & Stories | epics.md | 40,074 bytes | 2026-03-12 |
| UX Design | *Not found* | — | — |

**Additional:** product-brief-antforth-2026-03-11.md (reference)

## PRD Analysis

### Functional Requirements

**Interpreter Core:**
- FR1: User can enter text at an interactive REPL prompt and receive immediate execution results
- FR2: System can parse input text into whitespace-delimited tokens (words and numbers)
- FR3: System can look up words in the dictionary via hashed vocabulary search
- FR4: System can recognise and convert numeric literals (single-precision integers) from input text
- FR5: System can operate in interpret mode, executing words and pushing numbers to the stack
- FR6: System can operate in compile mode, compiling words and literals into new definitions
- FR7: System can switch between interpret and compile modes via `[` and `]`
- FR8: System can execute compiled threaded code via the direct-threaded inner interpreter

**Word Definition & Dictionary:**
- FR9: User can define new colon definitions (`: name ... ;`)
- FR10: User can define CODE words using the built-in Z80 assembler
- FR11: User can create variables, constants, and user-defined data structures (CREATE/DOES>)
- FR12: User can mark words as IMMEDIATE for compile-time execution
- FR13: User can use POSTPONE to compile the compilation semantics of a word
- FR14: User can list all defined words in the dictionary (WORDS)
- FR15: User can snapshot dictionary state with MARKER and restore to that snapshot
- FR16: System can store and retrieve dictionary entries via XOR-rotate hashed lookup with 64 buckets

**Stack Operations:**
- FR17: User can manipulate the parameter stack (DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH)
- FR18: User can inspect the current parameter stack contents (.S)
- FR19: User can manipulate the return stack (>R, R>, R@)

**Arithmetic & Logic:**
- FR20: User can perform single-precision integer arithmetic (+, -, *, /, MOD, /MOD, NEGATE, ABS, MIN, MAX)
- FR21: User can perform comparison operations (=, <, >, 0=, 0<, U<)
- FR22: User can perform bitwise logic operations (AND, OR, XOR, INVERT, LSHIFT, RSHIFT)

**Memory Access:**
- FR23: User can read and write cell-sized values in memory (@, !, +!)
- FR24: User can read and write byte-sized values in memory (C@, C!)
- FR25: User can allocate dictionary space (HERE, ALLOT, COMMA, C,, ALIGN, ALIGNED)
- FR26: User can fill and move memory regions (FILL, MOVE)

**Control Flow:**
- FR27: User can use conditional branching in definitions (IF/ELSE/THEN)
- FR28: User can use indefinite loops (BEGIN/WHILE/REPEAT, BEGIN/UNTIL)
- FR29: User can use counted loops (DO/LOOP/+LOOP, LEAVE, I, J)
- FR30: User can use RECURSE for recursive word definitions

**I/O & String Handling:**
- FR31: User can emit characters and strings to the console (EMIT, TYPE, CR, SPACE, SPACES)
- FR32: User can read keyboard input (KEY, KEY?)
- FR33: User can accept line input from the console (ACCEPT)
- FR34: User can format and display numbers (., U., .R)
- FR35: User can work with counted strings (COUNT, WORD, FIND)
- FR36: User can convert text to numbers (>NUMBER)
- FR37: User can define and use string literals (S", .")

**Built-in Assembler:**
- FR38: User can write Z80 assembly instructions using reverse-polish notation within CODE definitions
- FR39: User can define new CODE primitives that integrate with the Forth threading model
- FR40: User can mix assembler and Forth in the same development session

**System & Platform:**
- FR41: System can load and run as a CP/M 2.2 .COM application from A: or B: drive
- FR42: User can exit antforth cleanly back to CP/M (BYE)
- FR43: System can perform console I/O via CP/M BDOS calls
- FR44: User can set and query the numeric base for I/O (BASE, DECIMAL, HEX)

**Error Handling:**
- FR45: System can detect and report undefined words without crashing
- FR46: System can detect and report stack underflow without crashing
- FR47: System can discard partial definitions on compilation errors without corrupting the dictionary
- FR48: System can recover gracefully from errors and return to the REPL prompt

**Total FRs: 48**

### Non-Functional Requirements

**Performance:**
- NFR1: REPL input-to-output latency must be imperceptible for interactive use — simple expressions should feel instantaneous at 8 MHz
- NFR2: Dictionary lookup must remain responsive as the dictionary grows — the 64-bucket hash table provides acceptable O(n/64) average-case lookup
- NFR3: Inner interpreter threading (NEXT/DOCOL/EXIT) must be cycle-efficient — these are the hottest code paths in the system
- NFR4: Stack operations (DUP, DROP, SWAP, OVER) must be minimal-cycle implementations — they dominate typical Forth code

**Stability & Correctness:**
- NFR5: The system must never crash or hang due to user input errors — all errors must be caught and reported, returning control to the REPL
- NFR6: The dictionary must remain consistent after any error — partial definitions must be fully discarded without corruption
- NFR7: MARKER rollback must restore the system to an exact prior state — no residual side effects
- NFR8: All ANS Core wordset words must produce correct results per the ANS Forth specification — correctness is non-negotiable, performance is secondary

**Resource Constraints:**
- NFR9: The complete system (kernel + core wordset + assembler) must fit within the CP/M TPA — approximately 56-58K including dictionary space for user definitions
- NFR10: The .COM binary must be deliverable on a single CP/M disk (≤230K capacity)
- NFR11: Stack depths (parameter and return) must be sufficient for typical Forth usage without requiring user configuration

**Total NFRs: 11**

### Additional Requirements

**Constraints & Assumptions:**
- No floating-point hardware — Float wordset deferred to Phase 3
- 8 MHz Z80 clock — performance-sensitive primitives must be cycle-efficient
- No MMU — bank switching is manual via I/O port writes
- Terminal I/O limited to CP/M console capabilities
- Single vocabulary for MVP (no Search-Order wordset)
- Double-precision arithmetic excluded from MVP
- Dynamic memory allocation excluded from MVP (HERE/ALLOT suffices)

**Integration Requirements:**
- CP/M 2.2 BDOS integration for console and (future) file I/O
- .COM file entry point at 0100h per CP/M convention
- Clean exit back to CCP on BYE
- MicroBeast banked memory (11 additional 16K pages) accessible for extended storage

### PRD Completeness Assessment

The PRD is well-structured and thorough. Key observations:
- **48 functional requirements** clearly numbered and categorized across 8 domains
- **11 non-functional requirements** covering performance, stability, and resource constraints
- Clear MVP vs. post-MVP scoping with explicit exclusions
- User journeys are detailed and map well to capability requirements
- Project classification and constraints are clearly documented
- No UX document exists, but this is appropriate — the "UX" is a text-mode REPL, and the user journeys in the PRD adequately describe the interaction model

## Epic Coverage Validation

### Coverage Matrix

| FR | PRD Requirement | Epic Coverage | Status |
|---|---|---|---|
| FR1 | Interactive REPL prompt with immediate execution | Epic 2 (Story 2.2) | ✓ Covered |
| FR2 | Parse input into whitespace-delimited tokens | Epic 2 (Story 2.2) | ✓ Covered |
| FR3 | Dictionary lookup via hashed vocabulary search | Epic 2 (Story 2.1) | ✓ Covered |
| FR4 | Numeric literal conversion (single-precision) | Epic 2 (Story 2.2) | ✓ Covered |
| FR5 | Interpret mode — executing words and pushing numbers | Epic 2 (Story 2.2) | ✓ Covered |
| FR6 | Compile mode — compiling words and literals | Epic 3 (Story 3.1) | ✓ Covered |
| FR7 | Switch interpret/compile modes via `[` and `]` | Epic 3 (Story 3.1) | ✓ Covered |
| FR8 | Direct-threaded inner interpreter | Epic 1 (Story 1.2) | ✓ Covered |
| FR9 | Colon definitions (`: name ... ;`) | Epic 3 (Story 3.1) | ✓ Covered |
| FR10 | CODE words using built-in Z80 assembler | Epic 4 (Story 4.1) | ✓ Covered |
| FR11 | Variables, constants, CREATE/DOES> | Epic 3 (Story 3.2) | ✓ Covered |
| FR12 | IMMEDIATE words for compile-time execution | Epic 3 (Story 3.5) | ✓ Covered |
| FR13 | POSTPONE compilation semantics | Epic 3 (Story 3.5) | ✓ Covered |
| FR14 | WORDS dictionary listing | Epic 3 (Story 3.5) | ✓ Covered |
| FR15 | MARKER snapshot/restore | Epic 5 (Story 5.1) | ✓ Covered |
| FR16 | XOR-rotate hashed lookup with 64 buckets | Epic 2 (Story 2.1) | ✓ Covered |
| FR17 | Parameter stack manipulation (DUP, DROP, SWAP, etc.) | Epic 1 (Story 1.3) | ✓ Covered |
| FR18 | Stack inspection (.S) | Epic 2 (Story 2.3) | ✓ Covered |
| FR19 | Return stack manipulation (>R, R>, R@) | Epic 1 (Story 1.3) | ✓ Covered |
| FR20 | Single-precision arithmetic (+, -, *, /, etc.) | Epic 1 (Story 1.4) | ✓ Covered |
| FR21 | Comparison operations (=, <, >, 0=, 0<, U<) | Epic 1 (Story 1.4) | ✓ Covered |
| FR22 | Bitwise logic (AND, OR, XOR, INVERT, LSHIFT, RSHIFT) | Epic 1 (Story 1.4) | ✓ Covered |
| FR23 | Cell-sized memory access (@, !, +!) | Epic 1 (Story 1.3) | ✓ Covered |
| FR24 | Byte-sized memory access (C@, C!) | Epic 1 (Story 1.3) | ✓ Covered |
| FR25 | Dictionary space allocation (HERE, ALLOT, etc.) | Epic 1 (Story 1.3) | ✓ Covered |
| FR26 | FILL and MOVE | Epic 1 (Story 1.3) | ✓ Covered |
| FR27 | Conditional branching (IF/ELSE/THEN) | Epic 3 (Story 3.3) | ✓ Covered |
| FR28 | Indefinite loops (BEGIN/WHILE/REPEAT, BEGIN/UNTIL) | Epic 3 (Story 3.3) | ✓ Covered |
| FR29 | Counted loops (DO/LOOP/+LOOP, LEAVE, I, J) | Epic 3 (Story 3.4) | ✓ Covered |
| FR30 | RECURSE for recursive definitions | Epic 3 (Story 3.4) | ✓ Covered |
| FR31 | Console output (EMIT, TYPE, CR, SPACE, SPACES) | Epic 1 (Story 1.5) | ✓ Covered |
| FR32 | Keyboard input (KEY, KEY?) | Epic 1 (Story 1.5) | ✓ Covered |
| FR33 | Line input (ACCEPT) | Epic 2 (Story 2.2) | ✓ Covered |
| FR34 | Number formatting (., U., .R) | Epic 2 (Story 2.3) | ✓ Covered |
| FR35 | Counted strings (COUNT, WORD, FIND) | Epic 2 (Story 2.1/2.2) | ✓ Covered |
| FR36 | Text to number conversion (>NUMBER) | Epic 2 (Story 2.2) | ✓ Covered |
| FR37 | String literals (S", .") | Epic 3 (Story 3.5) | ✓ Covered |
| FR38 | Z80 assembly in reverse-polish notation | Epic 4 (Story 4.1/4.2) | ✓ Covered |
| FR39 | CODE primitives integrating with threading model | Epic 4 (Story 4.1) | ✓ Covered |
| FR40 | Mix assembler and Forth in same session | Epic 4 (Story 4.2) | ✓ Covered |
| FR41 | CP/M .COM application from A: or B: drive | Epic 1 (Story 1.1) | ✓ Covered |
| FR42 | Clean exit via BYE | Epic 1 (Story 1.1) | ✓ Covered |
| FR43 | Console I/O via CP/M BDOS calls | Epic 1 (Story 1.5) | ✓ Covered |
| FR44 | Numeric base (BASE, DECIMAL, HEX) | Epic 2 (Story 2.3) | ✓ Covered |
| FR45 | Undefined word detection | Epic 2 (Story 2.4) | ✓ Covered |
| FR46 | Stack underflow detection | Epic 2 (Story 2.4) | ✓ Covered |
| FR47 | Compilation error recovery (dictionary consistency) | Epic 3 (Story 3.1) | ✓ Covered |
| FR48 | Graceful error recovery to REPL | Epic 2 (Story 2.4) | ✓ Covered |

### Missing Requirements

No missing FRs identified. All 48 functional requirements have traceable coverage in the epics.

### Coverage Statistics

- Total PRD FRs: 48
- FRs covered in epics: 48
- Coverage percentage: **100%**

## UX Alignment Assessment

### UX Document Status

**Not Found** — No UX design document exists in the planning artifacts.

### Alignment Issues

None. A separate UX document is not required for this project.

### Assessment

antforth is a text-mode REPL (command-line Forth interpreter) running on Z80 retrocomputer hardware with 14-segment LED display output. The entire "user interface" is a terminal prompt — there are no web, mobile, or graphical UI components. The interaction model is:
- User types text at an `ok` prompt
- System executes and displays results as text
- Errors are reported as text messages
- System returns to the prompt

The PRD's 4 detailed user journeys (The OG, The Newb, Error Recovery, Hardware Developer) fully describe all user interactions. The architecture supports these through CP/M BDOS console I/O primitives.

### Warnings

None — UX documentation is appropriately absent for a text-mode REPL project.

## Epic Quality Review

### Epic Structure Validation

#### User Value Focus

| Epic | Title | User Value? | Notes |
|---|---|---|---|
| Epic 1 | Execution Engine | ⚠️ Borderline | Technical title, but for a language runtime the inner interpreter and primitives ARE the product. Testable via emulator. |
| Epic 2 | Interactive REPL | ✓ Yes | User types at prompt, sees results. Clear user value. |
| Epic 3 | Language Extension | ✓ Yes | User defines words, uses control flow, builds abstractions. |
| Epic 4 | Built-in Z80 Assembler | ✓ Yes | User writes CODE words in assembly. |
| Epic 5 | Safe Experimentation | ✓ Yes | User can snapshot/rollback dictionary state. |

#### Epic Independence

- Epic 1: Stands alone (produces testable .COM binary)
- Epic 2: Depends on Epic 1 only (correct)
- Epic 3: Depends on Epic 1+2 only (correct)
- Epic 4: Depends on Epic 1+2+3 only (correct)
- Epic 5: Depends on Epic 1+2+3 only (correct)
- **No forward dependencies found.**

### Story Quality Assessment

All 14 stories across 5 epics use proper Given/When/Then acceptance criteria format. Stories are:
- Testable with specific expected outcomes
- Sequenced correctly within each epic (no forward dependencies)
- Traceable to FRs via the coverage map

**Story Count by Epic:**
- Epic 1: 5 stories (1.1–1.5)
- Epic 2: 4 stories (2.1–2.4)
- Epic 3: 5 stories (3.1–3.5)
- Epic 4: 2 stories (4.1–4.2)
- Epic 5: 1 story (5.1)

### Findings by Severity

#### 🟠 Major Issues

**1. Epic 1 title is technical ("Execution Engine")**
- Describes an implementation component rather than user value
- Defensible for a language runtime where primitives ARE the product
- Recommendation: Consider renaming to "Core Forth Primitives" — cosmetic, not structural

#### 🟡 Minor Concerns

**1. Story 4.2 is large** — "Full Z80 Instruction Set & Addressing Modes" covers the entire remaining Z80 instruction set. Could be split into 2-3 smaller stories. Pragmatic for solo developer on hobby project.

**2. Epic 5 has only one story** — MARKER is the sole story. Small but focused epic delivering clear user value. Acceptable.

**3. NEGATE, ABS, MIN, MAX traceability gap** — These words are listed in FR20 but not explicitly in Story 1.4 acceptance criteria. **RESOLVED:** These are Forth-defined words (not CODE primitives), so they belong in Epic 3 once the compiler is available. Epics document should be updated to note this.

### Best Practices Compliance

| Check | E1 | E2 | E3 | E4 | E5 |
|---|---|---|---|---|---|
| Delivers user value | ⚠️ | ✓ | ✓ | ✓ | ✓ |
| Functions independently | ✓ | ✓ | ✓ | ✓ | ✓ |
| Stories appropriately sized | ✓ | ✓ | ✓ | ⚠️ | ✓ |
| No forward dependencies | ✓ | ✓ | ✓ | ✓ | ✓ |
| Clear acceptance criteria | ✓ | ✓ | ✓ | ✓ | ✓ |
| FR traceability maintained | ✓ | ✓ | ✓ | ✓ | ✓ |

## Summary and Recommendations

### Overall Readiness Status

**READY** — with minor items to address at your discretion.

The antforth project planning artifacts are in excellent shape for implementation. The PRD is thorough and well-scoped, the architecture is detailed and aligned, and the epics provide complete FR coverage with clear, testable stories. No critical blockers were identified.

### Issues Summary

| Severity | Count | Description |
|---|---|---|
| Critical | 0 | None |
| Major | 1 | Epic 1 title is technical rather than user-centric |
| Minor | 3 | Story 4.2 sizing, Epic 5 single story, NEGATE/ABS/MIN/MAX traceability |

### Critical Issues Requiring Immediate Action

None. There are no blocking issues preventing implementation from starting.

### Recommended Next Steps

1. **Update epics for NEGATE, ABS, MIN, MAX** — These FR20 words are Forth-defined (confirmed by user), not CODE primitives. They should be added to an Epic 3 story (e.g., Story 3.1 or a dedicated "Forth-defined arithmetic" story) so FR20 traceability is complete.

2. **Optionally rename Epic 1** — "Execution Engine" is a technical title. Consider "Core Forth Primitives" or "Foundational Forth System" to better express the user value. This is cosmetic and won't affect implementation.

3. **Optionally split Story 4.2** — The full Z80 instruction set story is large. Consider splitting into (a) basic addressing modes + loads, (b) jumps/calls/bit ops, (c) I/O instructions. Not required for a solo developer but would improve tracking.

4. **Proceed to implementation** — Start with Epic 1, Story 1.1 (Project Scaffolding & Build Toolchain). The planning artifacts provide clear, actionable specifications for every story.

### Strengths Noted

- **100% FR coverage** — All 48 functional requirements map to specific epics and stories
- **Excellent acceptance criteria** — Every story uses proper Given/When/Then format with specific test cases and expected values
- **Clear architecture alignment** — The epics document includes additional requirements extracted from the architecture (register contract, BDOS interaction rules, implementation sequence)
- **Appropriate scoping** — MVP scope is tight and achievable; post-MVP features are clearly delineated
- **Strong error handling coverage** — Error scenarios (undefined words, stack underflow, compilation errors) are treated as first-class requirements with dedicated stories
- **Testing strategy** — Three-track testing (on-device, iz-cpm emulator, Hayes ANS suite) provides confidence in correctness

### Final Note

This assessment identified 4 issues across 2 severity categories (1 major, 3 minor). None are blocking. The planning artifacts demonstrate strong requirements discipline — particularly notable for a hobby project. The antforth implementation can proceed with confidence.

**Assessed by:** Implementation Readiness Workflow
**Date:** 2026-03-12
