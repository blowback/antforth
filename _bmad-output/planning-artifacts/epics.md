---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - prd.md
  - architecture.md
---

# antforth - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for antforth, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

**Interpreter Core**
- FR1: User can enter text at an interactive REPL prompt and receive immediate execution results
- FR2: System can parse input text into whitespace-delimited tokens (words and numbers)
- FR3: System can look up words in the dictionary via hashed vocabulary search
- FR4: System can recognise and convert numeric literals (single-precision integers) from input text
- FR5: System can operate in interpret mode, executing words and pushing numbers to the stack
- FR6: System can operate in compile mode, compiling words and literals into new definitions
- FR7: System can switch between interpret and compile modes via `[` and `]`
- FR8: System can execute compiled threaded code via the direct-threaded inner interpreter

**Word Definition & Dictionary**
- FR9: User can define new colon definitions (`: name ... ;`)
- FR10: User can define CODE words using the built-in Z80 assembler
- FR11: User can create variables, constants, and user-defined data structures (CREATE/DOES>)
- FR12: User can mark words as IMMEDIATE for compile-time execution
- FR13: User can use POSTPONE to compile the compilation semantics of a word
- FR14: User can list all defined words in the dictionary (WORDS)
- FR15: User can snapshot dictionary state with MARKER and restore to that snapshot
- FR16: System can store and retrieve dictionary entries via XOR-rotate hashed lookup with 64 buckets

**Stack Operations**
- FR17: User can manipulate the parameter stack (DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH)
- FR18: User can inspect the current parameter stack contents (.S)
- FR19: User can manipulate the return stack (>R, R>, R@)

**Arithmetic & Logic**
- FR20: User can perform single-precision integer arithmetic (+, -, *, /, MOD, /MOD, NEGATE, ABS, MIN, MAX)
- FR21: User can perform comparison operations (=, <, >, 0=, 0<, U<)
- FR22: User can perform bitwise logic operations (AND, OR, XOR, INVERT, LSHIFT, RSHIFT)

**Memory Access**
- FR23: User can read and write cell-sized values in memory (@, !, +!)
- FR24: User can read and write byte-sized values in memory (C@, C!)
- FR25: User can allocate dictionary space (HERE, ALLOT, COMMA, C,, ALIGN, ALIGNED)
- FR26: User can fill and move memory regions (FILL, MOVE)

**Control Flow**
- FR27: User can use conditional branching in definitions (IF/ELSE/THEN)
- FR28: User can use indefinite loops (BEGIN/WHILE/REPEAT, BEGIN/UNTIL)
- FR29: User can use counted loops (DO/LOOP/+LOOP, LEAVE, I, J)
- FR30: User can use RECURSE for recursive word definitions

**I/O & String Handling**
- FR31: User can emit characters and strings to the console (EMIT, TYPE, CR, SPACE, SPACES)
- FR32: User can read keyboard input (KEY, KEY?)
- FR33: User can accept line input from the console (ACCEPT)
- FR34: User can format and display numbers (., U., .R)
- FR35: User can work with counted strings (COUNT, WORD, FIND)
- FR36: User can convert text to numbers (>NUMBER)
- FR37: User can define and use string literals (S", .")

**Built-in Assembler**
- FR38: User can write Z80 assembly instructions using reverse-polish notation within CODE definitions
- FR39: User can define new CODE primitives that integrate with the Forth threading model
- FR40: User can mix assembler and Forth in the same development session

**System & Platform**
- FR41: System can load and run as a CP/M 2.2 .COM application from A: or B: drive
- FR42: User can exit antforth cleanly back to CP/M (BYE)
- FR43: System can perform console I/O via CP/M BDOS calls
- FR44: User can set and query the numeric base for I/O (BASE, DECIMAL, HEX)

**Error Handling**
- FR45: System can detect and report undefined words without crashing
- FR46: System can detect and report stack underflow without crashing
- FR47: System can discard partial definitions on compilation errors without corrupting the dictionary
- FR48: System can recover gracefully from errors and return to the REPL prompt

### NonFunctional Requirements

**Performance**
- NFR1: REPL input-to-output latency must be imperceptible for interactive use — simple expressions should feel instantaneous at 8 MHz
- NFR2: Dictionary lookup must remain responsive as the dictionary grows — the 64-bucket hash table provides acceptable O(n/64) average-case lookup
- NFR3: Inner interpreter threading (NEXT/DOCOL/EXIT) must be cycle-efficient — these are the hottest code paths in the system
- NFR4: Stack operations (DUP, DROP, SWAP, OVER) must be minimal-cycle implementations — they dominate typical Forth code

**Stability & Correctness**
- NFR5: The system must never crash or hang due to user input errors — all errors must be caught and reported, returning control to the REPL
- NFR6: The dictionary must remain consistent after any error — partial definitions must be fully discarded without corruption
- NFR7: MARKER rollback must restore the system to an exact prior state — no residual side effects
- NFR8: All ANS Core wordset words must produce correct results per the ANS Forth specification — correctness is non-negotiable, performance is secondary

**Resource Constraints**
- NFR9: The complete system (kernel + core wordset + assembler) must fit within the CP/M TPA — approximately 56-58K including dictionary space for user definitions
- NFR10: The .COM binary must be deliverable on a single CP/M disk (≤230K capacity)
- NFR11: Stack depths (parameter and return) must be sufficient for typical Forth usage without requiring user configuration

### Additional Requirements

**From Architecture — Starter Template / Toolchain:**
- Project uses sjasmplus assembler, GNU Make build system, cpmtools for disk imaging, iz-cpm for automated testing
- Project initialisation (Makefile, directory structure, main assembly manifest) should be the first implementation story

**From Architecture — Cold Start Protocol:**
- .COM entry at 0x0100 must initialise SP, IX, IY, STATE, BASE, hash buckets (64 to 0), HERE, TIB/>IN before entering QUIT loop
- ABORT resets SP only and falls through to QUIT (not a full cold start)

**From Architecture — Register Contract (inviolable):**
- BC=TOS, DE=IP, SP=parameter stack, IX=return stack, IY=user pointer, HL=W (scratch), AF=scratch
- Every CODE primitive must preserve this contract

**From Architecture — Dictionary Construction:**
- All word definitions via DEFCODE/DEFWORD/DEFIMMED macros — no manual header emission
- Dictionary entry: [hash-link 2B][count+flags 1B][name nB][code field 3B: JP xxxx][body...]

**From Architecture — BDOS Interaction:**
- All CP/M BDOS calls must use BDOS_SAVE/BDOS_RESTORE macro pair
- No BDOS calls from colon definitions — only from CODE words

**From Architecture — Implementation Sequence:**
1. Memory layout and constants
2. Threading macros (NEXT, DOCOL, EXIT)
3. Dictionary entry macros
4. Core CODE primitives
5. Outer interpreter (QUIT loop, INTERPRET, number parsing)
6. Compiler (:, ;, IMMEDIATE, control flow)
7. Remaining Forth-defined words
8. Built-in assembler
9. MARKER and system words

**From Architecture — Testing Strategy:**
- Three-track: on-device (source of truth), iz-cpm automated regression, Hayes ANS conformance suite
- `make test` for automated regression via emulator

### FR Coverage Map

FR1: Epic 2 - REPL prompt and immediate execution
FR2: Epic 2 - Parse input into tokens
FR3: Epic 2 - Dictionary lookup via hash
FR4: Epic 2 - Numeric literal conversion
FR5: Epic 2 - Interpret mode execution
FR6: Epic 3 - Compile mode
FR7: Epic 3 - Interpret/compile mode switching ([ and ])
FR8: Epic 1 - Direct-threaded inner interpreter
FR9: Epic 3 - Colon definitions
FR10: Epic 4 - CODE word definition via assembler
FR11: Epic 3 - Variables, constants, CREATE/DOES>
FR12: Epic 3 - IMMEDIATE words
FR13: Epic 3 - POSTPONE
FR14: Epic 3 - WORDS dictionary listing
FR15: Epic 5 - MARKER snapshot/restore
FR16: Epic 2 - XOR-rotate hashed dictionary lookup
FR17: Epic 1 - Parameter stack manipulation
FR18: Epic 2 - Stack inspection (.S)
FR19: Epic 1 - Return stack manipulation
FR20: Epic 1 (CODE: +, -, *, /, MOD, /MOD) + Epic 3 (Forth: NEGATE, ABS, MIN, MAX) - Single-precision arithmetic
FR21: Epic 1 - Comparison operations
FR22: Epic 1 - Bitwise logic operations
FR23: Epic 1 - Cell-sized memory access
FR24: Epic 1 - Byte-sized memory access
FR25: Epic 1 - Dictionary space allocation (HERE, ALLOT, etc.)
FR26: Epic 1 - FILL and MOVE
FR27: Epic 3 - IF/ELSE/THEN
FR28: Epic 3 - BEGIN/WHILE/REPEAT, BEGIN/UNTIL
FR29: Epic 3 - DO/LOOP/+LOOP, LEAVE, I, J
FR30: Epic 3 - RECURSE
FR31: Epic 1 - Console output (EMIT, TYPE, CR, SPACE, SPACES)
FR32: Epic 1 - Keyboard input (KEY, KEY?)
FR33: Epic 2 - Line input (ACCEPT)
FR34: Epic 2 - Number formatting (., U., .R)
FR35: Epic 2 - Counted strings (COUNT, WORD, FIND)
FR36: Epic 2 - Text to number conversion (>NUMBER)
FR37: Epic 3 - String literals (S", .")
FR38: Epic 4 - Z80 assembly in reverse-polish notation
FR39: Epic 4 - CODE primitives integrating with threading model
FR40: Epic 4 - Mix assembler and Forth in same session
FR41: Epic 1 - CP/M .COM application
FR42: Epic 1 - Clean exit via BYE
FR43: Epic 1 - Console I/O via BDOS
FR44: Epic 2 - Numeric base (BASE, DECIMAL, HEX)
FR45: Epic 2 - Undefined word detection
FR46: Epic 2 - Stack underflow detection
FR47: Epic 3 - Compilation error recovery (dictionary consistency)
FR48: Epic 2 - Graceful error recovery to REPL

## Epic List

### Epic 1: Execution Engine
Build the foundational execution engine — project scaffolding, toolchain, inner interpreter, and all CODE primitives. Testable via hardcoded threaded code sequences under iz-cpm. User can build the project, produce a .COM binary, and verify correct execution of primitives.
**FRs covered:** FR8, FR17, FR19, FR20, FR21, FR22, FR23, FR24, FR25, FR26, FR31, FR32, FR41, FR42, FR43

### Epic 2: Interactive REPL
Add the outer interpreter to make the system interactive. User can type expressions at an `ok` prompt, perform arithmetic, inspect the stack, and see results — with graceful error handling for undefined words and stack underflow.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR16, FR18, FR33, FR34, FR35, FR36, FR44, FR45, FR46, FR48

### Epic 3: Language Extension
Add the compiler and control flow. User can define new words (colon definitions, variables, constants, CREATE/DOES>), use conditionals and loops, and build layered abstractions — the self-extending language moment.
**FRs covered:** FR6, FR7, FR9, FR11, FR12, FR13, FR14, FR20 (partial: NEGATE, ABS, MIN, MAX), FR27, FR28, FR29, FR30, FR37, FR47

### Epic 4: Built-in Z80 Assembler
Add the reverse-polish Z80 assembler with labels and data definition support. User can define CODE words from within Forth, writing performance-critical routines at the machine level with proper labels (including forward references), data definitions, and the full Z80 instruction set.
**FRs covered:** FR10, FR38, FR39, FR40

### Epic 5: Safe Experimentation & System Maturity
Add MARKER for dictionary state snapshot/restore. User can checkpoint system state, experiment freely, and roll back to known-good state. System is complete and ready for community sharing.
**FRs covered:** FR15

## Epic 1: Execution Engine

Build the foundational execution engine — project scaffolding, toolchain, inner interpreter, and all CODE primitives. Testable via hardcoded threaded code sequences under iz-cpm.

### Story 1.1: Project Scaffolding & Build Toolchain

As a developer,
I want a complete project structure with build toolchain,
So that I can assemble Z80 source into a CP/M .COM binary and test it under emulation.

**Acceptance Criteria:**

**Given** a fresh clone of the repository
**When** I run `make`
**Then** sjasmplus assembles `src/antforth.asm` into `build/antforth.com`
**And** the .COM binary entry point is at 0x0100 per CP/M convention

**Given** the assembled .COM binary
**When** I run it under iz-cpm
**Then** it exits cleanly back to CP/M (BYE via BDOS function 0)

**Given** the project directory
**When** I inspect the structure
**Then** all source files from the architecture spec exist (`constants.asm`, `macros.asm`, `structures.asm`, `antforth.asm`, etc.)
**And** `constants.asm` defines memory layout equates (TPA start, stack bases, TIB address, HASH_BUCKETS, BDOS_ENTRY)
**And** `macros.asm` defines NEXT, DOCOL, EXIT, DEFCODE, DEFWORD, DEFIMMED, BDOS_SAVE, BDOS_RESTORE macros
**And** `.gitignore` excludes `build/`

**Given** a source file change
**When** I run `make` again
**Then** only changed files trigger reassembly (incremental build)

### Story 1.2: Inner Interpreter & Threading

As a developer,
I want a working direct-threaded inner interpreter,
So that I can execute threaded code sequences and verify the core execution model.

**Acceptance Criteria:**

**Given** the .COM binary loads under iz-cpm
**When** the cold start protocol runs
**Then** SP is set to parameter stack base (top of TPA, below BDOS), IX to return stack base, IY to user variable area, STATE to 0, BASE to 10, HERE to end of kernel, and TIB/>IN to 0

**Given** a hardcoded thread `LIT 42, LIT 10, EXECUTE(BYE)`
**When** the inner interpreter runs it
**Then** NEXT fetches the next cell via DE (IP), loads into HL (W), and jumps via `JP (HL)` to the code field

**Given** a hardcoded thread with a colon definition (DOCOL/EXIT)
**When** the inner interpreter runs it
**Then** DOCOL pushes IP to the return stack (IX) and sets IP to the body
**And** EXIT pops IP from the return stack and resumes via NEXT

**Given** a hardcoded thread with `LIT`
**When** LIT executes
**Then** it fetches the inline literal from the thread, pushes it to the parameter stack, and advances IP past the literal

**Given** a hardcoded thread with `BRANCH` and `?BRANCH`
**When** BRANCH executes
**Then** it adds the inline offset to IP (unconditional jump)
**When** ?BRANCH executes with 0 (false) on stack
**Then** it branches; with non-zero (true) it falls through

### Story 1.3: Stack & Memory Primitives

As a developer,
I want all stack and memory CODE primitives,
So that I can manipulate the parameter stack, return stack, and memory in threaded code sequences.

**Acceptance Criteria:**

**Given** a hardcoded thread exercising stack operations
**When** DUP executes with value `x` on stack
**Then** the stack contains `x x`
**When** DROP executes with `x y` on stack
**Then** the stack contains `x`
**When** SWAP executes with `x y` on stack
**Then** the stack contains `y x`
**When** OVER executes with `x y` on stack
**Then** the stack contains `x y x`
**When** ROT executes with `x y z` on stack
**Then** the stack contains `y z x`
**And** PICK, ROLL, DEPTH all produce correct results per ANS spec

**Given** a hardcoded thread exercising return stack operations
**When** `>R` executes with value on parameter stack
**Then** the value is moved to the return stack (IX)
**When** `R>` executes
**Then** the value is moved back to the parameter stack
**When** `R@` executes
**Then** the top of return stack is copied to parameter stack without removing it

**Given** a hardcoded thread exercising memory operations
**When** `!` stores a cell value at an address and `@` fetches it
**Then** the fetched value matches the stored value
**When** `C!` stores a byte and `C@` fetches it
**Then** the fetched byte matches the stored byte
**When** `+!` adds a value to a cell at an address
**Then** the cell contains the original value plus the added value

**Given** a hardcoded thread exercising dictionary space allocation
**When** `HERE` executes
**Then** it pushes the current dictionary pointer
**When** `ALLOT` allocates n bytes
**Then** HERE advances by n
**When** `,` (COMMA) compiles a cell and `C,` compiles a byte
**Then** the values are stored at HERE and HERE advances accordingly
**And** ALIGN and ALIGNED produce correctly aligned addresses

**Given** a hardcoded thread exercising FILL and MOVE
**When** FILL fills a region with a byte value
**Then** all bytes in the region contain that value
**When** MOVE copies a region to another address
**Then** the destination contains an exact copy (handling overlapping regions correctly)

### Story 1.4: Arithmetic, Logic & Comparison

As a developer,
I want all arithmetic, logic, and comparison CODE primitives,
So that I can perform calculations in threaded code and verify correctness.

**Acceptance Criteria:**

**Given** a hardcoded thread exercising arithmetic
**When** `+` executes with 3 and 4 on stack
**Then** the result is 7
**When** `-` executes with 10 and 3 on stack
**Then** the result is 7
**When** `*` executes with 6 and 7 on stack
**Then** the result is 42
**When** `/` executes with 42 and 6 on stack
**Then** the result is 7
**When** `MOD` executes with 10 and 3 on stack
**Then** the result is 1
**When** `/MOD` executes with 10 and 3 on stack
**Then** the stack contains quotient 3 and remainder 1
**And** all arithmetic handles signed two's complement correctly including edge cases (division by zero behaviour, MIN_INT)

**Given** a hardcoded thread exercising logic
**When** `AND` executes with 0xFF00 and 0x0FF0
**Then** the result is 0x0F00
**When** `OR` executes with 0xFF00 and 0x00FF
**Then** the result is 0xFFFF
**When** `XOR` executes with 0xFFFF and 0xFF00
**Then** the result is 0x00FF
**When** `INVERT` executes with 0xFF00
**Then** the result is 0x00FF
**When** `LSHIFT` shifts 1 left by 8
**Then** the result is 256
**When** `RSHIFT` shifts 256 right by 8
**Then** the result is 1

**Given** a hardcoded thread exercising comparisons
**When** `=` compares 5 and 5
**Then** the result is -1 (TRUE)
**When** `<` compares 3 and 5 (signed)
**Then** the result is -1 (TRUE)
**When** `>` compares 5 and 3
**Then** the result is -1 (TRUE)
**When** `0=` tests 0
**Then** the result is -1 (TRUE); testing non-zero gives 0 (FALSE)
**When** `0<` tests -1
**Then** the result is -1 (TRUE); testing 1 gives 0 (FALSE)
**When** `U<` compares 1 and 0xFFFF (unsigned)
**Then** the result is -1 (TRUE)

### Story 1.5: Console I/O Primitives

As a developer,
I want console I/O CODE primitives,
So that I can output characters and strings and read keyboard input via CP/M BDOS.

**Acceptance Criteria:**

**Given** a hardcoded thread that calls EMIT with character 65 ('A')
**When** it runs under iz-cpm
**Then** the character 'A' appears on the console output
**And** BDOS_SAVE/BDOS_RESTORE macros preserve DE (IP) and BC (TOS) around the BDOS call

**Given** a hardcoded thread that calls TYPE with an address and length
**When** it runs
**Then** the specified string is output to the console character by character

**Given** a hardcoded thread that calls CR
**When** it runs
**Then** a carriage return and line feed are output

**Given** a hardcoded thread that calls SPACE
**When** it runs
**Then** a single space character is output
**And** SPACES with count n outputs n space characters

**Given** a hardcoded thread that calls KEY
**When** a character is available from the console
**Then** KEY pushes the character value to the stack (via BDOS C_READ)

**Given** a hardcoded thread that calls KEY?
**When** no key is pressed
**Then** KEY? pushes 0 (FALSE)
**When** a key is pressed
**Then** KEY? pushes -1 (TRUE)

## Epic 2: Interactive REPL

Add the outer interpreter to make the system interactive. User can type expressions at an `ok` prompt, perform arithmetic, inspect the stack, and see results — with graceful error handling.

### Story 2.1: Dictionary & Hash Table

As a Forth user,
I want words stored in a searchable dictionary,
So that the system can look up built-in words by name for execution.

**Acceptance Criteria:**

**Given** the cold start protocol runs
**When** the hash table is initialised
**Then** all 64 hash buckets are set to 0 (empty chains)
**And** all CODE words defined via DEFCODE/DEFWORD macros in Epic 1 are linked into the hash table at assembly time

**Given** a word name (e.g., "DUP")
**When** the XOR-rotate hash function processes it
**Then** it produces a consistent bucket index in the range 0-63
**And** the hash is case-insensitive per ANS Forth standard

**Given** a word name that exists in the dictionary (e.g., "SWAP")
**When** FIND searches for it
**Then** it returns the dictionary entry address and a flag indicating found (+1 for immediate, -1 for non-immediate)

**Given** a word name that does NOT exist in the dictionary
**When** FIND searches for it
**Then** it returns the original string address and 0 (not found)

**Given** multiple words hashing to the same bucket
**When** FIND searches for any of them
**Then** it traverses the hash-link chain and finds the correct entry
**And** lookup time remains responsive due to the 64-bucket distribution

### Story 2.2: Outer Interpreter & REPL Loop

As a Forth user,
I want to type expressions at a prompt and see them execute,
So that I can interact with the system in real time.

**Acceptance Criteria:**

**Given** antforth boots on iz-cpm or MicroBeast
**When** the cold start completes and QUIT enters the outer interpreter loop
**Then** the system displays the `ok` prompt and waits for input

**Given** the system is at the `ok` prompt
**When** the user types a line of text and presses Enter
**Then** ACCEPT fills the TIB via BDOS C_READSTR and sets >IN to 0

**Given** input text in the TIB
**When** WORD parses the next whitespace-delimited token
**Then** it advances >IN past the token and stores the counted string at HERE

**Given** a parsed token that matches a dictionary word (e.g., "DUP")
**When** INTERPRET processes it in interpret mode (STATE=0)
**Then** the word is executed immediately

**Given** a parsed token that does NOT match a dictionary word
**When** INTERPRET attempts number conversion via >NUMBER
**Then** if the token is a valid number in the current BASE, it is pushed to the parameter stack
**And** if the token is neither a word nor a valid number, an error is raised

**Given** the user types `2 3 + .`
**When** the line is interpreted
**Then** 2 and 3 are pushed to the stack, `+` adds them, `.` prints `5`, and `ok` is displayed on the next prompt

**Given** all tokens on a line have been processed
**When** INTERPRET reaches the end of the input
**Then** `ok` is printed (in interpret mode) and the system waits for the next line

### Story 2.3: Number Formatting & Stack Inspection

As a Forth user,
I want to display numbers and inspect the stack,
So that I can see the results of my computations and debug my work.

**Acceptance Criteria:**

**Given** the value 42 on the stack
**When** `.` (dot) executes
**Then** `42 ` is printed to the console (number followed by a space) using the current BASE

**Given** the unsigned value 65535 on the stack
**When** `U.` executes
**Then** `65535 ` is printed (unsigned interpretation)

**Given** the value 42 on the stack and a field width of 6
**When** `.R` executes
**Then** `    42` is printed (right-justified in 6 characters)

**Given** the stack contains values 1, 2, 3 (3 on top)
**When** `.S` executes
**Then** the output shows the stack depth and contents (e.g., `<3> 1 2 3`) without consuming the stack

**Given** the system is in decimal mode (default)
**When** the user types `HEX`
**Then** BASE is set to 16 and subsequent number I/O uses hexadecimal
**When** the user types `DECIMAL`
**Then** BASE is set to 10 and subsequent number I/O uses decimal

**Given** BASE is set to 16
**When** the user types `FF .`
**Then** `255 ` is printed (interpreting FF as hex, displaying in current base)

### Story 2.4: Error Handling & Recovery

As a Forth user,
I want clear error messages and graceful recovery,
So that mistakes don't crash the system and I can continue working.

**Acceptance Criteria:**

**Given** the user types an undefined word (e.g., `FOO`)
**When** INTERPRET fails to find it in the dictionary and it's not a valid number
**Then** the system prints `FOO ?` and calls ABORT
**And** ABORT resets the parameter stack (SP to initial value) and falls through to QUIT
**And** QUIT resets the return stack (IX to initial value), sets STATE to interpret, and displays `ok`

**Given** the user executes a word that causes stack underflow (e.g., `+` with empty stack)
**When** the underflow is detected
**Then** the system prints `? Stack underflow` and calls ABORT
**And** the system returns to the `ok` prompt ready for input

**Given** an error occurs during any operation
**When** ABORT executes
**Then** only SP is reset (not a full cold start — hash table, HERE, dictionary remain intact)
**And** any values the user had on the stack are lost (expected ABORT behaviour)

**Given** the user types a line with mixed valid and invalid tokens (e.g., `2 3 + BADWORD`)
**When** the invalid token is reached
**Then** the error is reported for that specific token
**And** earlier operations on that line have already executed (standard Forth behaviour — no line-level transaction)

**Given** repeated errors
**When** the user makes multiple consecutive mistakes
**Then** the system recovers cleanly each time without memory leaks, dictionary corruption, or stack residue

## Epic 3: Language Extension

Add the compiler and control flow. User can define new words, use conditionals and loops, and build layered abstractions — the self-extending language moment.

### Story 3.0: Test Thread Modularisation

As a developer,
I want the monolithic test thread broken into multiple smaller independent test groups,
So that a failure in one group doesn't block all subsequent tests and test maintenance is manageable.

**Acceptance Criteria:**

**Given** the current single test_thread in antforth.asm with 62+ sequential test characters
**When** the test infrastructure is modularised
**Then** tests are split into logical groups (e.g., per-module or per-epic)
**And** each group can fail independently without blocking others
**And** `make test` still runs all groups and reports pass/fail
**And** all existing tests continue to pass

**Given** the REPL test infrastructure from Epic 2
**When** new tests are considered
**Then** REPL-piped Forth scripts are the preferred approach for new word testing going forward

### Story 3.1: Colon Definitions & Compiler

As a Forth user,
I want to define new words using colon definitions,
So that I can extend the language and build abstractions.

**Acceptance Criteria:**

**Given** the user types `: SQUARE DUP * ;`
**When** the definition completes
**Then** SQUARE is added to the dictionary and `ok` is displayed
**And** typing `7 SQUARE .` outputs `49`

**Given** `:` is executed
**When** the compiler begins a new definition
**Then** STATE is set to compile mode, HERE is saved for error recovery, and the SMUDGE flag is set on the new header (hiding it from FIND during compilation)

**Given** the system is in compile mode
**When** the user types a known word (e.g., `DUP`)
**Then** the word's execution token is compiled into the definition (appended as a cell at HERE)
**And** when the user types a number (e.g., `42`)
**Then** `LIT` followed by the number value is compiled into the definition

**Given** `;` is executed
**When** the definition completes successfully
**Then** `EXIT` is compiled, the SMUDGE flag is cleared (making the word findable), and STATE is set back to interpret mode

**Given** the user types `[` during compilation
**When** it executes
**Then** STATE switches to interpret mode temporarily
**And** when `]` is typed, STATE returns to compile mode

**Given** a compilation error occurs (e.g., undefined word inside a definition)
**When** the error is detected
**Then** HERE is restored to the saved value (discarding the partial definition), the SMUDGE flag entry is removed from the hash chain, and ABORT is called
**And** the dictionary remains consistent with no residual partial entries

**Given** the user defines `: CUBE DUP SQUARE * ;` (using a previously defined word)
**When** CUBE is called with `3 CUBE .`
**Then** the output is `27` (nested colon definitions work correctly)

**Given** the compiler is working
**When** the Forth-defined arithmetic words are loaded (NEGATE, ABS, MIN, MAX)
**Then** `5 NEGATE .` outputs `-5` and `-3 NEGATE .` outputs `3`
**And** `-7 ABS .` outputs `7` and `7 ABS .` outputs `7`
**And** `3 5 MIN .` outputs `3` and `3 5 MAX .` outputs `5`

### Story 3.2: Variables, Constants & CREATE/DOES>

As a Forth user,
I want to create variables, constants, and custom defining words,
So that I can manage data and build higher-level data structures.

**Acceptance Criteria:**

**Given** the user types `VARIABLE COUNTER`
**When** the definition completes
**Then** COUNTER is added to the dictionary with `JP DOVAR` code field and a 2-byte body initialised to 0
**And** typing `COUNTER` pushes the address of the body to the stack
**And** `42 COUNTER !` stores 42, and `COUNTER @` retrieves 42

**Given** the user types `99 CONSTANT LIMIT`
**When** the definition completes
**Then** LIMIT is added to the dictionary with `JP DOCON` code field and the value 99 in the body
**And** typing `LIMIT .` outputs `99`

**Given** the user types `CREATE BUFFER 100 ALLOT`
**When** the definition completes
**Then** BUFFER is added to the dictionary with `JP DOVAR` code field
**And** typing `BUFFER` pushes the address of the 100-byte allocated region

**Given** the user defines a custom defining word using CREATE/DOES>
**When** e.g., `: ARRAY CREATE CELLS ALLOT DOES> SWAP CELLS + ;`
**Then** `10 ARRAY MYDATA` creates a 10-cell array
**And** `42 3 MYDATA !` stores 42 at index 3
**And** `3 MYDATA @ .` outputs `42`

**Given** DOES> executes within a defining word
**When** a child word created by that defining word is called
**Then** DOES> switches from CREATE-time behaviour to run-time behaviour, pushing the body address and executing the DOES> code

### Story 3.3: Conditionals & Indefinite Loops

As a Forth user,
I want conditional branching and indefinite loops in my definitions,
So that I can write logic that makes decisions and repeats.

**Acceptance Criteria:**

**Given** a definition using IF/THEN: `: POS? DUP 0> IF ." POSITIVE" THEN ;`
**When** `5 POS?` is executed
**Then** `POSITIVE` is printed
**When** `-3 POS?` is executed
**Then** nothing is printed (the IF branch is skipped)

**Given** a definition using IF/ELSE/THEN: `: SIGN DUP 0< IF ." NEG" ELSE ." POS" THEN ;`
**When** `-1 SIGN` is executed
**Then** `NEG` is printed
**When** `1 SIGN` is executed
**Then** `POS` is printed

**Given** a definition using BEGIN/UNTIL: `: COUNTDOWN BEGIN DUP . 1 - DUP 0= UNTIL DROP ;`
**When** `5 COUNTDOWN` is executed
**Then** `5 4 3 2 1` is printed (loop runs until condition is true)

**Given** a definition using BEGIN/WHILE/REPEAT: `: COUNTUP BEGIN DUP 5 < WHILE DUP . 1 + REPEAT DROP ;`
**When** `1 COUNTUP` is executed
**Then** `1 2 3 4` is printed (loop runs while condition is true)

**Given** nested conditionals (IF inside IF)
**When** executed
**Then** each IF matches its correct THEN and branches resolve correctly

**Given** IF, ELSE, THEN, BEGIN, WHILE, REPEAT, UNTIL are all IMMEDIATE words
**When** used outside of a colon definition (in interpret mode)
**Then** a compile-only error is reported (e.g., `IF ? compile only`)

### Story 3.4: Counted Loops & RECURSE

As a Forth user,
I want counted loops and recursion in my definitions,
So that I can iterate over ranges and write recursive algorithms.

**Acceptance Criteria:**

**Given** a definition using DO/LOOP: `: TENS 10 0 DO I . LOOP ;`
**When** `TENS` is executed
**Then** `0 1 2 3 4 5 6 7 8 9` is printed

**Given** a definition using +LOOP: `: EVENS 10 0 DO I . 2 +LOOP ;`
**When** `EVENS` is executed
**Then** `0 2 4 6 8` is printed

**Given** a definition using LEAVE: `: FIND5 10 0 DO I 5 = IF I . LEAVE THEN LOOP ;`
**When** `FIND5` is executed
**Then** `5` is printed and the loop exits early

**Given** a definition using I (inner loop index)
**When** the loop body executes
**Then** I pushes the current loop index to the parameter stack

**Given** nested DO/LOOPs using I and J
**When** the inner loop body executes
**Then** I returns the inner loop index and J returns the outer loop index

**Given** a definition using RECURSE: `: FACTORIAL DUP 1 > IF DUP 1 - RECURSE * THEN ;`
**When** `5 FACTORIAL .` is executed
**Then** `120` is printed

**Given** DO, LOOP, +LOOP, LEAVE are IMMEDIATE words
**When** used outside of a colon definition
**Then** a compile-only error is reported

### Story 3.5: IMMEDIATE, POSTPONE, String Literals & WORDS

As a Forth user,
I want to create compile-time words, use string literals, and browse the dictionary,
So that I can write sophisticated macros and use strings in my programs.

**Acceptance Criteria:**

**Given** the user defines a word and then types `IMMEDIATE`
**When** the most recent definition is marked IMMEDIATE
**Then** the IMMEDIATE flag is set in the dictionary entry's count+flags byte
**And** when that word is encountered during compilation, it executes immediately instead of being compiled

**Given** a definition that uses POSTPONE with a non-IMMEDIATE word: `: COMP-DUP POSTPONE DUP ; IMMEDIATE`
**When** `COMP-DUP` is used inside another definition
**Then** DUP is compiled into that definition (POSTPONE defers the compilation)

**Given** a definition that uses POSTPONE with an IMMEDIATE word
**When** POSTPONE is used
**Then** the compilation semantics (not execution semantics) of the IMMEDIATE word are compiled

**Given** a definition using S": `: GREET S" Hello" TYPE ;`
**When** `GREET` is executed
**Then** `Hello` is printed
**And** S" compiles an inline counted string (runtime word + count byte + string bytes) into the definition

**Given** a definition using .": `: HI ." Hello World" ;`
**When** `HI` is executed
**Then** `Hello World` is printed

**Given** S" used in interpret mode
**When** `S" test" TYPE` is typed at the REPL
**Then** `test` is printed (S" works in both interpret and compile mode per ANS)

**Given** the user types `WORDS`
**When** WORDS executes
**Then** all words in the dictionary are listed to the console (traversing all 64 hash buckets)

## Epic 4: Built-in Z80 Assembler

Add the reverse-polish Z80 assembler with labels and data definition support. User can define CODE words from within Forth, writing performance-critical routines at the machine level with proper labels (including forward references), data definitions, and the full Z80 instruction set.

### Story 4.0: Startup Banner

As a Forth user,
I want to see a startup banner when the system boots,
So that I know which version I'm running and how much memory is available.

**Acceptance Criteria:**

**Given** the user starts antforth (either on iz-cpm or MicroBeast hardware)
**When** the cold start completes
**Then** a banner is displayed before the first `ok` prompt:
```
AntForth v1.00 (c) ant.org 2026
MicroBeast - xxxx bytes available
```
**And** `xxxx` shows the actual number of free bytes (dictionary space between HERE and the stack area)

### Story 4.1: CODE Word Framework & Basic Instructions

As a Forth user,
I want to define CODE words with basic Z80 assembly,
So that I can write performance-critical primitives from within Forth.

**Acceptance Criteria:**

**Given** the user types `CODE MYDUP`
**When** CODE executes
**Then** a new dictionary entry is created with the name MYDUP
**And** the assembler vocabulary becomes active for subsequent input
**And** HERE points to where machine code will be assembled

**Given** the user is inside a CODE definition
**When** they type Z80 instructions in reverse-polish notation (e.g., `BC PUSH,` for `PUSH BC`)
**Then** the correct Z80 opcode bytes are assembled at HERE and HERE advances

**Given** a CODE definition with basic register-to-register loads
**When** e.g., `B A LD,` is typed
**Then** the correct opcode for `LD A, B` is assembled

**Given** a CODE definition with 8-bit arithmetic
**When** e.g., `B ADD,` (ADD A, B), `C SUB,` (SUB C), `D AND,` (AND D), `E OR,` (OR E), `H XOR,` (XOR H), `L CP,` (CP L) are typed
**Then** the correct opcodes are assembled for each instruction

**Given** a CODE definition with stack push/pop
**When** e.g., `BC PUSH,`, `DE POP,` are typed
**Then** the correct opcodes for PUSH BC and POP DE are assembled

**Given** the user types `END-CODE` (or `NEXT,` followed by `END-CODE`)
**When** the CODE definition completes
**Then** the word is finalised in the dictionary and the assembler vocabulary is deactivated
**And** the word is callable from Forth like any other word

**Given** the user defines a working CODE word:
```
CODE MYDUP
  BC PUSH,
  NEXT,
END-CODE
```
**When** `5 MYDUP . .` is executed
**Then** `5 5` is printed (MYDUP duplicates TOS, equivalent to DUP)
**And** the register contract is preserved (BC=TOS, DE=IP intact through NEXT)

**Given** a CODE word that doesn't end with NEXT (or JP/RET equivalent)
**When** it executes
**Then** behaviour is undefined (this is the user's responsibility, matching standard Forth assembler conventions)

### Story 4.2: Labels & Data Definition Words

As a Forth user,
I want labels (including forward references) and data definition words in the assembler,
So that I can write readable assembly code without manually counting bytes for jump offsets, and embed data tables in CODE words.

**Acceptance Criteria:**

**Given** a CODE definition using a backward label
**When** e.g., `L: LOOP-START` defines a label and `LOOP-START JR,` jumps back to it
**Then** the correct signed displacement is calculated and assembled

**Given** a CODE definition using a forward label
**When** e.g., `SKIP JR,` references a label before it is defined, and `L: SKIP` later defines it
**Then** the forward reference is resolved and the correct displacement is patched in

**Given** a CODE definition using `DB`
**When** e.g., `0x42 DB,` is typed
**Then** the byte 0x42 is assembled at HERE and HERE advances by 1

**Given** a CODE definition using `DW`
**When** e.g., `0x1234 DW,` is typed
**Then** the 16-bit value 0x1234 is assembled at HERE (little-endian) and HERE advances by 2

**Given** a CODE definition using `DS`
**When** e.g., `10 DS,` is typed
**Then** 10 bytes of space are reserved at HERE (filled with 0) and HERE advances by 10

**Given** the user uses `EQU` to define a named constant
**When** e.g., `0x42 EQU PORT-A`
**Then** PORT-A is available as a constant value in subsequent assembler expressions

### Story 4.3: Basic Z80 Opcodes

As a Forth user,
I want the core Z80 instruction set available in the assembler,
So that I can write most common CODE words with loads, arithmetic, jumps, and calls.

**Acceptance Criteria:**

**Given** a CODE definition using 16-bit loads
**When** e.g., `0x1234 # BC LD,` (LD BC, 0x1234) is typed
**Then** the correct 3-byte opcode sequence is assembled

**Given** a CODE definition using indirect addressing
**When** e.g., `(HL) A LD,` (LD A, (HL)), `A (HL) LD,` (LD (HL), A) are typed
**Then** the correct opcodes for indirect memory access are assembled

**Given** a CODE definition using jumps and calls
**When** e.g., `0x1234 JP,`, `NZ 0x1234 JP,` (conditional JP NZ), `0x1234 CALL,`, `RET,`, `Z RET,` (conditional RET) are typed
**Then** the correct opcode sequences are assembled for each

**Given** a CODE definition using relative jumps
**When** e.g., forward and backward `JR,` instructions are used with labels
**Then** the correct signed displacement byte is calculated and assembled

**Given** a CODE definition using immediate operands
**When** `0x42 # A LD,` (LD A, 0x42), `0x0F # AND,` (AND 0x0F) are typed
**Then** the correct opcodes with inline immediate bytes are assembled

**Given** the user writes a non-trivial CODE word for hardware interaction:
```
CODE LED!  ( char port -- )
  BC PUSH,          \ save TOS (port)
  SP 2 +D L LD,     \ get char from stack
  C A LD,            \ port number to A
  A C LD,            \ port to C for OUT
  L A LD,            \ char to A
  (C) A OUT,         \ output to port
  BC POP,            \ restore stack
  BC POP,            \ pop to new TOS
  NEXT,
END-CODE
```
**When** `65 0x42 LED!` is executed
**Then** the byte 65 is written to I/O port 0x42

**Given** the user is in a normal Forth session (not inside CODE)
**When** they use assembler words alongside Forth words
**Then** the assembler vocabulary is only active inside CODE/END-CODE and does not interfere with normal Forth interpretation

### Story 4.3.5: Stack Tag Encoding Refactor

As an antforth assembler user,
I want operand type errors (like `A 0 LD,` instead of `A 0 # LD,`) to be caught at assemble time with a clear message,
So that I cannot silently produce machine code that does the wrong thing.

**Background:**
The original tag encoding (story 4.1/4.2/4.3) used three sentinel high bytes
(`0xFF` label, `0xFE` condition, `0xFD` immediate) and tagged 8-bit registers as
`0x00nn`. This made bare integer 0 indistinguishable from register B and burned
~768 reserved cell values. This story unifies the encoding and adds typo
detection without changing user-facing syntax.

**Acceptance Criteria:**

**Given** any tagged operand (register, condition, label, immediate marker,
addressing mode) on the data stack
**When** examined
**Then** the high byte of the cell is exactly `0xFF` and the low byte holds a
3-bit class field (top) and a 5-bit index field (bottom)

**Given** an operand-consuming assembler word receives an operand
**When** the operand cell's high byte is not `0xFF`
**Then** the word raises a clear error (e.g. `expected tagged operand, got
bare integer N — did you mean #N ?`) and does not assemble any bytes

**Given** an immediate operand
**When** `42 # A LD,` is typed
**Then** the stack picture during `LD,` execution is `[..., 42, <imm-tag>, A-tag]`
(two cells for the immediate: marker cell with class=immediate, value cell
directly below) and the assembled bytes are `0x3E 0x2A`

**Given** a 16-bit immediate operand
**When** `0x1234 # BC LD,` is typed
**Then** the assembled bytes are `0x01 0x34 0x12` (the value cell holds the
full 16-bit value, no longer bottled into the low byte of a sentinel)

**Given** the user types `A 0 LD,` (forgetting the `#`)
**When** `LD,` examines its operands
**Then** an error is raised pointing at the bare integer 0, and no bytes are
assembled

**Given** the existing story 4.1, 4.2, and 4.3 test suite
**When** re-run after the encoding refactor
**Then** every existing test continues to pass (modulo migration of any test
that hand-constructs `0xFD`/`0xFE` literal sentinels)

**Given** new REPL-piped test scripts covering the typo-detection path
**When** run against the refactored assembler
**Then** all "forgot the #" cases produce clear errors and all "correctly
written" cases assemble identically to before

**Given** the architecture document
**When** updated as part of this story
**Then** it contains a new subsection describing the tag-cell format
(`0xFF <class:3><index:5>`), the class table, the two-cell layout for
immediates and displacements, and a worked example showing `LD A, #42` and
`LD A, B` side by side

### Story 4.4: Extended Z80 Opcodes

As a Forth user,
I want the extended Z80 instruction set (CB/DD/FD-prefixed) available in the assembler,
So that I can use bit operations, rotates/shifts, and IX/IY indexed addressing in CODE words.

**Acceptance Criteria:**

**Given** a CODE definition using IX/IY indexed addressing with displacement
**When** e.g., `(IX) 5 +D A LD,` (LD A, (IX+5)) is typed
**Then** the correct DD-prefixed opcode with displacement byte is assembled

**Given** a CODE definition using bit operations
**When** `3 # A BIT,` (BIT 3, A), `5 # B SET,` (SET 5, B), `7 # C RES,` (RES 7, C) are typed
**Then** the correct CB-prefixed opcodes are assembled
**And** bit numbers outside 0..7 raise a clear range error at assemble time

**Given** a CODE definition using bit operations on indexed memory
**When** e.g., `3 # (IX) 5 +D BIT,` (BIT 3, (IX+5)) is typed
**Then** the correct DDCB-prefixed opcode sequence is assembled
**And** the three-operand stack picture (bit-immediate + indexed-addr-tag + displacement-cell)
is consumed correctly by `BIT,` / `SET,` / `RES,`

**Given** a CODE definition using rotates and shifts
**When** `A RLC,`, `B RRC,`, `C RL,`, `D RR,`, `E SLA,`, `H SRA,`, `L SRL,` are typed
**Then** the correct CB-prefixed opcodes are assembled

**Given** a CODE definition using I/O instructions
**When** `(C) A IN,` (IN A, (C)), `A (C) OUT,` (OUT (C), A), `0x42 # A IN,` (IN A, (0x42)) are typed
**Then** the correct opcodes are assembled for port I/O

**Given** a CODE definition using block transfer and search instructions
**When** `LDIR,`, `LDDR,`, `CPIR,`, `CPDR,` are typed
**Then** the correct ED-prefixed opcodes are assembled

## Epic 5: Safe Experimentation & System Maturity

Add MARKER for dictionary state snapshot/restore. User can checkpoint, experiment freely, and roll back to known-good state.

### Story 5.1: MARKER Snapshot & Restore

As a Forth user,
I want to snapshot the dictionary state and restore to it later,
So that I can experiment freely knowing I can undo everything and return to a known-good state.

**Acceptance Criteria:**

**Given** the user types `MARKER CHECKPOINT`
**When** MARKER executes
**Then** a new word CHECKPOINT is added to the dictionary
**And** CHECKPOINT records the current HERE value and the current state of all 64 hash bucket head pointers

**Given** the user has created CHECKPOINT and then defines additional words (e.g., `: TEST1 ... ;`, `: TEST2 ... ;`)
**When** the user types `CHECKPOINT`
**Then** HERE is restored to the value saved at MARKER creation time
**And** all 64 hash bucket head pointers are restored to their saved values
**And** TEST1, TEST2, and CHECKPOINT itself are effectively removed from the dictionary
**And** the memory they occupied is reclaimed (available for new definitions)

**Given** the user creates nested markers: `MARKER M1`, defines words, `MARKER M2`, defines more words
**When** `M2` is executed
**Then** only the state back to M2's creation is restored (M1 and words defined before M2 remain)
**When** `M1` is then executed
**Then** state is restored to M1's creation point (everything after M1 is removed, including M2)

**Given** MARKER has saved the system state
**When** the user restores to that state
**Then** no residual side effects remain — the system behaves identically to how it did at the moment MARKER was created
**And** user variables (BASE, STATE) are NOT affected by MARKER restore (MARKER covers dictionary state only)

**Given** the user creates a MARKER, defines words that include VARIABLE and CONSTANT definitions
**When** the MARKER is executed to restore
**Then** those variables and constants are removed from the dictionary along with all other definitions made after the marker
