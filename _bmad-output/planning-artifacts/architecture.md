---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-03-12'
inputDocuments:
  - prd.md
  - product-brief-antforth-2026-03-11.md
workflowType: 'architecture'
project_name: 'antforth'
user_name: 'Ant'
date: '2026-03-12'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
48 FRs across 10 categories. The architectural weight is concentrated in three areas: (1) the interpreter core (FR1-FR8) — the threading model, parse loop, and interpret/compile state machine that everything else depends on; (2) word definition and dictionary management (FR9-FR16) — the hashed vocabulary, CREATE/DOES>, MARKER rollback; and (3) the built-in Z80 assembler (FR38-FR40) — which must integrate cleanly with the threading model to produce valid CODE words.

The remaining FRs (stack ops, arithmetic, memory, control flow, I/O, strings) are largely independent primitives that conform to the threading and register contract. Their architectural impact is low individually but collectively they define the kernel/Forth boundary.

**Non-Functional Requirements:**
11 NFRs, with the most architecturally significant being:
- **NFR3/NFR4** (cycle-efficient NEXT, DOCOL, EXIT, stack ops) — these are the hottest paths and constrain the threading model choice
- **NFR5/NFR6** (crash-proof error recovery, dictionary consistency) — requires careful state management during compilation and a defined abort/recovery protocol
- **NFR9** (entire system in ~56-58K TPA) — the hard memory ceiling drives decisions about what lives in base memory vs banked RAM

**Scale & Complexity:**

- Primary domain: Embedded language implementation (Z80/CP/M)
- Complexity level: Low domain, high technical precision
- Estimated architectural components: ~6 (inner interpreter, outer interpreter/REPL, dictionary/vocabulary, compiler, assembler, CP/M I/O layer)

### Technical Constraints & Dependencies

- **CPU:** 8 MHz Z80 — no barrel shifter, no multiply instruction, 8-bit ALU with 16-bit register pairs
- **Memory:** ~56-58K TPA + 11x16K banked pages; bank switching via I/O port writes (no MMU)
- **OS:** CP/M 2.2 — BDOS for console and file I/O, CCP for command line, BIOS for hardware abstraction
- **Register contract:** HL=W, DE=IP, SP=parameter stack, IX=return stack, IY=user pointer, BC=TOS — this is immutable once set and affects every primitive
- **Disk:** ≤230K capacity per CP/M disk — total binary + source must fit
- **Threading model:** Direct threading (JP-based) — chosen for simplicity and reasonable Z80 performance

### Cross-Cutting Concerns Identified

- **Register discipline:** Every CODE primitive and every Forth-called routine must preserve the register contract. A single violation corrupts the threading model.
- **Memory layout:** The TPA must be partitioned between kernel code, dictionary space, stacks, buffers, and user workspace. This layout is a foundational decision.
- **Bank switching protocol:** Any code that accesses banked memory must follow a consistent switching discipline to avoid corruption, especially if interrupts are involved.
- **Error/abort recovery:** The abort path must unwind cleanly from any state (interpreting, compiling, executing) back to the REPL without dictionary corruption.
- **Kernel/Forth boundary:** Which words are assembler primitives vs. Forth definitions affects binary size, performance, and maintainability. This boundary needs explicit decision criteria.

## Starter Template Evaluation

### Primary Technology Domain

Z80 assembly language / embedded system — bare-metal language implementation targeting CP/M 2.2 on MicroBeast hardware. No web frameworks, package managers, or runtime dependencies. The "starter" is the toolchain and source organisation conventions.

### Toolchain Selection

| Tool | Choice | Role |
|------|--------|------|
| Assembler | **sjasmplus** (v1.22.0+, built from source) | Z80 macro assembler with structure facilities, multi-file includes, conditional assembly, LUA scripting |
| Build system | **GNU Make** | Dependency tracking, incremental builds, disk image generation |
| Disk imaging | **cpmtools** | Building CP/M disk images for deployment to MicroBeast |
| CP/M emulator | **iz-cpm** (v1.3.4) | Headless CP/M 2.2 emulator for automated regression testing on Linux |
| Testing | **On-device + iz-cpm** | Primary on MicroBeast hardware; automated regression via emulator |
| Containerisation | **Docker** | Reproducible build environment with pinned tool versions (multi-stage build) |

**Docker build container:** All three build tools (sjasmplus, iz-cpm, cpmtools) are packaged in a Docker image (`antforth-toolchain`) via a multi-stage Dockerfile. This ensures reproducible builds regardless of host environment and simplifies future CI/CD (e.g., GitHub Actions). Usage: `make docker-build` to build the image, then `make docker` / `make docker-test` / `make docker-disk` to build inside the container. Local toolchain targets (`make`, `make test`, etc.) remain available for developers who prefer native builds.

### Assembler Conventions

- **Mnemonics:** UPPER-CASE (`LD`, `CALL`, `JP`, `PUSH`, `POP`, etc.)
- **Address/hex format:** `0x` prefix notation (`0xFFFF`, `0x0100`)
- **Macro usage:** Extensive use of sjasmplus macros and structures — threading primitives (NEXT, DOCOL, EXIT), dictionary entry construction, and word header generation should all be macro-driven for consistency and readability
- **Multi-file source:** Code split across multiple `.asm` files via `INCLUDE`, organised by functional area

### Source Organisation Approach

Multi-file with includes, structured by architectural component. The main file acts as an assembly manifest that includes components in dependency order. This keeps individual files manageable and maps cleanly to the architectural components identified in the context analysis (inner interpreter, outer interpreter, dictionary, compiler, assembler, CP/M I/O).

### Architectural Decisions Provided by Toolchain

- **sjasmplus macros** enable defining dictionary headers, threading primitives, and word definitions as structured macros — reducing boilerplate and enforcing consistency across hundreds of word definitions
- **sjasmplus structures** can formally define dictionary entry layout, user area layout, and other data structures — making the memory model explicit in code rather than implicit in magic offsets
- **Multi-file includes** establish a natural mapping between source files and architectural components
- **GNU Make** enables incremental rebuilds and a single `make` command to go from source to bootable CP/M disk image

**Note:** Project initialisation (creating the Makefile, directory structure, and main assembly manifest) should be the first implementation story.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
All resolved — memory layout, dictionary entry format, code field layout, error handling protocol, kernel/Forth boundary criteria.

**Important Decisions (Shape Architecture):**
All resolved — banked memory strategy, input buffer/parsing, number representation, string storage.

**Deferred Decisions (Post-MVP):**
- Banked memory usage strategy (extended dictionary, block storage)
- Search-Order wordset (multiple vocabularies, per-vocabulary hash tables)
- File-Access wordset implementation details
- Double-precision number representation

### Memory Layout

- Kernel code at bottom of TPA (0x0100 upward)
- Dictionary grows upward from end of kernel code (HERE pointer)
- Parameter stack (SP) at top of TPA, just below BDOS, growing downward
- Return stack (IX) below parameter stack region, growing downward
- Free dictionary space = gap between HERE and return stack floor
- PAD = scratch area above HERE (moves with HERE)
- Fixed 128-byte Terminal Input Buffer at known address
- Banked memory ignored for MVP — TPA only. Layout designed so banking can be layered on later without kernel rework

### Cold Start Protocol

The .COM entry point at 0x0100 must explicitly initialise the Forth environment before entering the QUIT loop:

1. Set SP to parameter stack base (top of TPA, just below BDOS)
2. Set IX to return stack base (below parameter stack region)
3. Set IY to user variable area base
4. Zero STATE (interpret mode)
5. Set BASE to 10 (decimal)
6. Initialise all 64 hash buckets to 0 (empty chains)
7. Set HERE to end of kernel code (start of free dictionary space)
8. Initialise TIB pointer and >IN to 0
9. Jump to QUIT (enter the outer interpreter loop)

This sequence runs once at load time. ABORT does *not* repeat the full cold start — it only resets SP and falls through to QUIT. Cold start is the only path that initialises the hash table and system variables.

### Dictionary Entry Format

- Counted string name with flags in count byte (high bits: IMMEDIATE, SMUDGE; low 5 bits: name length)
- Inline name storage within dictionary entry
- Entry structure: `[hash-link (2 bytes)][count+flags (1 byte)][name (n bytes)][code field (3 bytes: JP xxxx)][body...]`
- 64 hash buckets, each a linked list of entries via hash-link field
- XOR-rotate hash function over name characters

### Code Field Layout (Direct Threading)

- Every word's code field contains a literal `JP xxxx` instruction (3 bytes)
- Colon definitions: `JP DOCOL` — pushes IP to return stack, sets IP to body
- Variables: `JP DOVAR` — pushes address of body to parameter stack
- Constants: `JP DOCON` — pushes value from body to parameter stack
- CODE words: machine code follows directly (or replaces the JP)
- NEXT fetches the next cell from the instruction pointer (DE), loads into HL, and executes `JP (HL)` — landing on the code field's JP instruction

### Banked Memory Strategy

- MVP: All code and data in base TPA. No bank switching in kernel.
- Users can access banked memory manually via I/O port writes if desired.
- Post-MVP: Extended dictionary in banked pages. Architecture does not hardcode assumptions about contiguous dictionary space that would prevent future banking support.

### Error Handling & Abort Protocol

- **Two-level ANS model:** ABORT and QUIT
- **QUIT:** Resets return stack (IX to initial value), sets STATE to interpret, enters outer interpreter loop (accept, interpret, "ok", repeat)
- **ABORT:** Resets parameter stack (SP to initial value), falls through to QUIT
- **Error handler:** Prints error message (e.g., "? undefined word"), then calls ABORT
- **Compilation guard:** HERE saved at entry to `:`. On compilation error, HERE restored to saved value (discarding partial definition) before ABORT

### Kernel/Forth Boundary

**Boundary principle:** If it can't be expressed in Forth, or if the Forth version would be noticeably slow for interactive use, it's CODE. Everything else starts as Forth. Promote to CODE later based on on-device profiling.

**Must be CODE (assembly primitives):**
Threading: NEXT, DOCOL, EXIT, LIT, BRANCH, ?BRANCH, EXECUTE
Stack: DUP, DROP, SWAP, OVER, ROT, >R, R>, R@, DEPTH, SP@, SP!, RP@, RP!
Arithmetic: +, -, AND, OR, XOR, INVERT, LSHIFT, RSHIFT
Memory: @, !, C@, C!, +!
Comparison: =, <, >, 0=, 0<, U<
I/O: EMIT, KEY, KEY? (CP/M BDOS calls)

**Should be CODE (performance-sensitive):**
\*, /, MOD, /MOD, FILL, MOVE, CMOVE, hash function

**Should be Forth (colon definitions):**
NEGATE, ABS, MIN, MAX, SPACES, .S, WORDS, number formatting (., U., .R), MARKER, control flow compilers (IF, ELSE, THEN, DO, LOOP — IMMEDIATE words), ACCEPT, QUIT, ABORT, INTERPRET

### Input Buffer & Parsing

- Fixed 128-byte Terminal Input Buffer (TIB) at known address
- ACCEPT fills TIB via CP/M BDOS function 10 (C_READSTR)
- >IN variable tracks current parse position as offset into TIB
- WORD and PARSE advance >IN to extract whitespace-delimited tokens
- WORD parses to HERE (standard transient buffer)

### Number Representation

- Cell size: 16-bit (2 bytes) — native Z80 word size
- Signed integers: two's complement
- TRUE flag: -1 (0xFFFF), FALSE flag: 0 — per ANS standard
- Numeric base: variable via BASE, default decimal. HEX and DECIMAL as convenience words
- Single-precision only for MVP; double-precision deferred

### String Storage

- Compiled string literals (S", ."): inline in dictionary — runtime word (e.g., DOSTRING) followed by count byte then string bytes
- WORD buffer: parses to HERE (transient, safe during interpretation)
- PAD: scratch area for string/number formatting, 84 bytes above HERE, moves as HERE moves
- Counted strings throughout (addr of count byte, or addr+len pair on stack per ANS)

### Decision Impact Analysis

**Implementation Sequence:**
1. Memory layout and constants (defines all addresses)
2. Threading macros (NEXT, DOCOL, EXIT) — everything depends on these
3. Dictionary entry macros (header construction)
4. Core CODE primitives (stack, arithmetic, memory)
5. Outer interpreter (QUIT loop, INTERPRET, number parsing)
6. Compiler (`:`, `;`, IMMEDIATE, control flow words)
7. Remaining Forth-defined words
8. Built-in assembler
9. MARKER and system words

**Cross-Component Dependencies:**
- Register contract is inviolable — all CODE primitives must preserve it
- Dictionary entry format drives both the hash lookup code and the header-construction macros
- Error handling (ABORT/QUIT) must be in place before the outer interpreter is testable
- The kernel/Forth boundary means the assembler kernel must be complete before Forth bootstrapping can begin

## Implementation Patterns & Consistency Rules

### Critical Conflict Points Identified

7 areas where AI agents could make different choices, all resolved with explicit patterns below.

### Naming Patterns

**Assembly Labels:**
- Forth word implementations: `w_DUP`, `w_DROP`, `w_SWAP` — `w_` prefix + Forth word name in caps. Special characters mapped: `w_FETCH` (@), `w_STORE` (!), `w_PLUS` (+), `w_MINUS` (-), `w_STAR` (*), `w_SLASH` (/), `w_EQUALS` (=), `w_LESS` (<), `w_GREATER` (>), `w_ZERO_EQUALS` (0=), `w_ZERO_LESS` (0<), `w_TO_R` (>R), `w_R_FROM` (R>), `w_R_FETCH` (R@), `w_COMMA` (,), `w_C_COMMA` (C,), `w_DOT` (.), `w_DOT_S` (.S), `w_QBRANCH` (?BRANCH)
- Dictionary header labels: `h_DUP`, `h_DROP` — `h_` prefix for dictionary entry point
- Internal/helper labels: `inner_label` — lowercase with underscores, no leading underscore
- Constants/equates: `UPPER_SNAKE_CASE` — `TIB_SIZE`, `HASH_BUCKETS`, `BDOS_ENTRY`
- Macros: `UPPER_SNAKE_CASE` — `DEFWORD`, `DEFCODE`, `NEXT`, `BDOS_SAVE`, `BDOS_RESTORE`
- sjasmplus structures: `PascalCase` — `DictEntry`, `UserArea`

**Source Files:**
- Lowercase with underscores: `inner_interpreter.asm`, `stack_ops.asm`, `dictionary.asm`

### Register Usage Discipline

**Register Contract (inviolable):**

| Register | Role | CODE word rules |
|----------|------|----------------|
| BC | TOS (top of parameter stack) | Contains TOS on entry; must contain new TOS on exit |
| DE | IP (instruction pointer) | Must be preserved or saved/restored before NEXT |
| SP | Parameter stack | Net effect must match word's stack signature |
| IX | Return stack pointer | Preserve unless doing return stack operations |
| IY | User pointer | Preserve unless accessing user variables |
| HL | W (working register) | Free scratch within CODE words |
| AF | Flags/accumulator | Free scratch within CODE words |

**Anti-pattern:** Any CODE word that modifies DE, IX, or IY without saving/restoring (unless that's the word's defined purpose, e.g., >R modifies IX).

### Assembler Tag-Cell Encoding (Story 4.3.5)

Every tagged operand in the built-in assembler uses a unified two-byte cell with high byte `0xFF` and a low byte encoding a 3-bit class (bits 7-5) and a 5-bit index (bits 4-0):

```
Tag cell:  0xFF <CCCIIIII>
                │   │
                │   └── 5-bit index (0..31 per class)
                └────── 3-bit class (0..7)

Class 000 (0x00)  8-bit register     B=0 C=1 D=2 E=3 H=4 L=5 A=7
Class 001 (0x20)  Condition code     NZ=0 Z=1 NC=2 CS=3 PO=4 PE=5 P=6 M=7
Class 010 (0x40)  Immediate marker   value lives in next stack cell
Class 011 (0x60)  16-bit register    BC=0 DE=1 HL=2 AF=3 SP=4 IX=5 IY=6 AF'=7
Class 100 (0x80)  Indexed/indirect   (HL)=0, (IX)=1, (IY)=2, (IX+d)=3, (IY+d)=4, (SP)=5, (C)=6
Class 101 (0xA0)  Label              forward & backward refs (slot index 0..15)
Class 110         RESERVED
Class 111         RESERVED
```

**Two-cell layout for immediates:**
```
Stack (grows down):   ... | value | 0xFF40 | dest-tag |
                              ^        ^
                          raw 16-bit   imm marker (class=010)
```

**Worked example — `LD A, #42` vs `LD A, B`:**
```
LD A, #42  (Forth: A 42 # LD,)
  Stack after A:       ... | 0xFF07 |              (A = class 000, index 7)
  Stack after 42:      ... | 0xFF07 | 0x002A |     (raw value)
  Stack after #:       ... | 0xFF07 | 0x002A | 0xFF40 |  (imm marker)
  LD, detects imm marker on TOS → pops marker, pops value, pops A tag
  Emits: 0x3E 0x2A  (LD A, 42)

LD A, B  (Forth: A B LD,)
  Stack after A:       ... | 0xFF07 |              (A tag)
  Stack after B:       ... | 0xFF07 | 0xFF00 |     (B tag: class 000, index 0)
  LD, sees class=REG8 on TOS → register-to-register path
  Emits: 0x78  (LD A, B = 0x40 | (7<<3) | 0)
```

**Bare-integer detection:** If an operand-consuming word pops a cell whose high byte is not `0xFF`, it raises `bare integer ?` and emits no bytes. This catches the common mistake of omitting `#` for immediate operands.

### Dictionary Entry Construction

**Rule:** No word is ever defined by manually emitting header bytes. Always use macros.

**DEFCODE** — CODE primitives (body is assembly):
```
DEFCODE "DUP", 0           ; name, flags
    PUSH BC
    NEXT
```

**DEFWORD** — colon definitions (body is a thread):
```
DEFWORD "NEGATE", 0         ; name, flags
    DW w_LIT_cf, 0
    DW w_SWAP_cf
    DW w_MINUS_cf
    DW w_EXIT_cf
```

**DEFIMMED** — IMMEDIATE colon definitions:
```
DEFIMMED "IF", 0
    DW w_COMPILE_QBRANCH_cf
    DW w_HERE_cf, w_FETCH_cf
    DW w_LIT_cf, 0, w_COMMA_cf
    DW w_EXIT_cf
```

**Note:** Thread bodies reference `w_NAME_cf` labels (the code field address), not the `w_NAME` label (which points to the dictionary header). The `_cf` suffix is required because sjasmplus local labels (`.code_field`) inside DEFCODE/DEFWORD macros are not accessible externally. Each word definition must include both a `w_NAME:` label before the DEFCODE/DEFWORD macro and a `w_NAME_cf:` label immediately after it.

Macros handle: hash computation, hash-link chain insertion, count byte + flags + name emission, code field emission (`JP DOCOL` for DEFWORD/DEFIMMED, inline body for DEFCODE).

### Comment Conventions

**Word-level documentation (mandatory for every word):**
```
; -----------------------------------------------
; DUP ( x -- x x )
;   Duplicate top of stack
; -----------------------------------------------
DEFCODE "DUP", 0
    PUSH BC
    NEXT
```

**Inline comments:** Explain *why* or *what register state results*, not restatements of the instruction. Comments default to the right-hand column but may span the mnemonic column or use multi-line blocks when code complexity warrants it.

**File-level header (mandatory for every source file):**
```
; ================================================
; stack_ops.asm — Parameter stack manipulation words
; Part of antforth — ANS Forth for MicroBeast Z80
; ================================================
```

### BDOS Interaction Pattern

**Rule:** Every CP/M BDOS call must use the `BDOS_SAVE` / `BDOS_RESTORE` macro pair. No direct BDOS calls without the wrapper.

```
    BDOS_SAVE
    LD C,func               ; BDOS function number
    LD DE,param              ; parameter if needed
    CALL 0x0005
    BDOS_RESTORE
```

The macros save/restore DE (IP) and BC (TOS) to the parameter stack. If additional registers need saving later, the fix is in the macros only.

**Rule:** No BDOS calls from colon definitions — only from CODE words. Colon definitions needing I/O go through CODE primitives (EMIT, KEY, KEY?).

### Error Message Format

**Hybrid format:** Terse but informative, following Forth conventions.

- Undefined word: `FOO ?` (shows offending word)
- Stack underflow: `? Stack underflow`
- Compile-only word in interpret mode: `WORD ? compile only`
- Other errors: `? description`

### Enforcement Guidelines

**All AI agents MUST:**
- Use DEFCODE/DEFWORD/DEFIMMED macros for every word definition — no manual header emission
- Preserve the register contract — save/restore DE, IX, IY if used as scratch
- Use BDOS_SAVE/BDOS_RESTORE for all CP/M system calls
- Include stack effect comment and description for every word
- Follow the naming conventions exactly (w_ prefix, h_ prefix, UPPER_SNAKE constants)
- End every CODE word with NEXT

## Project Structure & Boundaries

### Complete Project Directory Structure

```
antforth/
├── Dockerfile                      # Multi-stage Docker build for reproducible toolchain
├── .dockerignore                   # Excludes build/, .git/, _bmad*, blog/ from Docker context
├── Makefile                        # Build system: asm → .COM → disk image (local + Docker targets)
├── README.md
├── .gitignore
│
├── src/
│   ├── antforth.asm                # Main assembly manifest — includes all components in order
│   │
│   ├── constants.asm               # Memory layout, system constants, equates
│   ├── macros.asm                  # DEFCODE, DEFWORD, DEFIMMED, NEXT, BDOS_SAVE/RESTORE
│   ├── structures.asm              # sjasmplus STRUCT definitions (DictEntry, UserArea, etc.)
│   │
│   ├── inner_interpreter.asm       # NEXT, DOCOL, EXIT, LIT, BRANCH, ?BRANCH, EXECUTE
│   ├── outer_interpreter.asm       # QUIT loop, INTERPRET, ACCEPT, number parsing, FIND
│   ├── compiler.asm                # : ; IMMEDIATE POSTPONE [ ] CREATE DOES> STATE
│   │
│   ├── dictionary.asm              # Hash table, lookup, header construction runtime
│   ├── hash.asm                    # XOR-rotate hash function
│   │
│   ├── stack_ops.asm               # DUP DROP SWAP OVER ROT PICK ROLL DEPTH .S >R R> R@
│   ├── arithmetic.asm              # + - * / MOD /MOD NEGATE ABS MIN MAX
│   ├── logic.asm                   # AND OR XOR INVERT LSHIFT RSHIFT = < > 0= 0< U<
│   ├── memory.asm                  # @ ! C@ C! +! FILL MOVE HERE ALLOT , C, ALIGN ALIGNED
│   ├── control_flow.asm            # IF ELSE THEN BEGIN WHILE REPEAT UNTIL DO LOOP +LOOP LEAVE I J
│   ├── io.asm                      # EMIT KEY KEY? TYPE CR SPACE SPACES ACCEPT
│   ├── strings.asm                 # COUNT WORD FIND >NUMBER S" ." PAD
│   ├── formatting.asm              # . U. .R BASE DECIMAL HEX number output
│   │
│   ├── assembler.asm               # Built-in reverse-polish Z80 assembler for CODE words
│   ├── system.asm                  # BYE MARKER WORDS ABORT QUIT error handling
│   │
│   └── bootstrap.asm               # High-level Forth definitions compiled at build time
│                                   # (colon defs that are part of the core system)
│
├── tests/                          # Forth test suite (run under iz-cpm)
│   └── core_tests.fth              # ANS Core wordset tests
│
├── build/                          # Build output directory (gitignored)
│   ├── antforth.com                # Assembled CP/M binary
│   └── antforth.img                # CP/M disk image
│
├── disk/                           # Files to include on the CP/M disk image
│   └── (future: example .fth source files)
│
└── docs/                           # Project documentation
    └── (future: beginner's guide, word reference)
```

### Architectural Boundaries

**Kernel boundary (assembly):** Everything in `src/` except `bootstrap.asm` is Z80 assembly CODE primitives and system infrastructure. These files define the machine-level foundation.

**Bootstrap boundary (Forth-in-assembly):** `bootstrap.asm` contains colon definitions expressed as `DEFWORD` macros — Forth words that are part of the core system but implemented in Forth (compiled at assembly time as threads of addresses). This is where NEGATE, ABS, MIN, MAX, .S, WORDS, number formatting, and IMMEDIATE control-flow compilers live.

**Include order matters:** `antforth.asm` includes files in dependency order:
1. `constants.asm` — addresses and equates (no code generated)
2. `macros.asm` — macro definitions (no code generated)
3. `structures.asm` — struct definitions (no code generated)
4. `dictionary.asm` — hash table storage and lookup routines
5. `hash.asm` — hash function
6. `inner_interpreter.asm` — NEXT, DOCOL, EXIT (everything else depends on these)
7. `stack_ops.asm` through `system.asm` — CODE primitives (order within this group is flexible)
8. `outer_interpreter.asm` — QUIT, INTERPRET (depends on primitives)
9. `compiler.asm` — colon compiler (depends on outer interpreter)
10. `assembler.asm` — built-in assembler (depends on compiler)
11. `bootstrap.asm` — Forth definitions (depends on everything above)

**Data flow:** User types at CP/M console → BDOS → ACCEPT fills TIB → INTERPRET parses tokens → FIND looks up in hash table → execute (interpret mode) or compile (compile mode) → results to console via EMIT/TYPE → BDOS → CP/M console.

### FR Category to File Mapping

| FR Category | Primary File(s) |
|-------------|-----------------|
| FR1-FR8: Interpreter Core | `inner_interpreter.asm`, `outer_interpreter.asm` |
| FR9-FR16: Word Definition & Dictionary | `dictionary.asm`, `hash.asm`, `compiler.asm` |
| FR17-FR19: Stack Operations | `stack_ops.asm` |
| FR20-FR22: Arithmetic & Logic | `arithmetic.asm`, `logic.asm` |
| FR23-FR26: Memory Access | `memory.asm` |
| FR27-FR30: Control Flow | `control_flow.asm` |
| FR31-FR37: I/O & Strings | `io.asm`, `strings.asm`, `formatting.asm` |
| FR38-FR40: Built-in Assembler | `assembler.asm` |
| FR41-FR44: System & Platform | `system.asm`, `constants.asm` |
| FR45-FR48: Error Handling | `system.asm`, `outer_interpreter.asm` |

### Build Process

```
# Local toolchain
make              # Assemble → build/antforth.com
make asm          # Assemble only → build/antforth.com
make disk         # Build disk image → build/antforth.img
make test         # Assemble, then run Forth test suite under iz-cpm
make clean        # Remove build artifacts

# Docker toolchain (reproducible, CI-ready)
make docker-build # Build the antforth-toolchain Docker image
make docker       # Assemble inside Docker
make docker-test  # Build and run under iz-cpm inside Docker
make docker-disk  # Build disk image inside Docker
```

The Makefile depends on all `src/*.asm` files, so changing any source file triggers a rebuild. sjasmplus assembles fast enough that this coarse dependency is sufficient.

## Architecture Validation Results

### Coherence Validation

**Decision Compatibility:** All architectural decisions are internally consistent. Direct threading + register contract + code field layout align correctly. Memory layout supports the dictionary format and error handling protocol. BDOS_SAVE/RESTORE correctly accounts for the register contract.

**Pattern Consistency:** Naming conventions are uniform across all areas. DEFCODE/DEFWORD/DEFIMMED macros enforce dictionary entry format consistency. Comment conventions are standardised.

**Structure Alignment:** File organisation maps 1:1 to architectural components. Include order respects the dependency chain. Build output matches Makefile targets.

### Requirements Coverage

**Functional Requirements:** All 48 FRs across 10 categories are fully covered by architectural decisions and mapped to specific source files.

**Non-Functional Requirements:** All 11 NFRs are addressed — cycle-efficient hot paths via CODE primitives, crash-proof error recovery via ABORT/QUIT protocol, TPA memory ceiling respected via MVP-only banked memory strategy.

**Minor gap noted:** Stack region sizes (parameter and return) not specified as exact byte counts. These will be defined as tunable constants in `constants.asm` during implementation — typical Forth systems use 256-512 bytes per stack.

### Testing Strategy

**Three-track approach:**

1. **On-device testing (primary, source of truth):** Manual verification on MicroBeast hardware. The real environment, the final arbiter of correctness. Used during development and for hardware-specific validation.

2. **Automated regression testing (emulator-based):** iz-cpm (Rust-based CP/M 2.2 emulator, https://github.com/ivanizag/iz-cpm) runs antforth.com headless on Linux. Integrated into the build system via `make test`. Test input piped via stdin, output captured and checked for PASS/FAIL. Covers all non-hardware-specific functionality — which is 100% of the MVP scope.

3. **ANS conformance testing:** The Hayes ANS Forth test suite is an established, Forth-level conformance test suite. Run under iz-cpm once the outer interpreter and basic I/O are functional, providing systematic ANS compliance validation.

**Test infrastructure:**
- Test suite written in Forth (`tests/` directory), exercising each primitive with expected results
- Stack effect verification: test words check DEPTH before and after each primitive to catch the most common class of Forth implementation bugs
- `make test` assembles, launches iz-cpm with antforth.com, pipes test source, and checks output for failures
- iz-cpm maps host directories to CP/M drives, so test .fth files are accessible without disk image creation

**Emulator limitations (acceptable for MVP):**
- No MicroBeast-specific I/O port emulation (LED display, bank switching, expansion cards) — these are out of MVP scope
- No cycle-accurate timing — performance testing requires real hardware
- BDOS emulation may differ subtly from MicroBeast's BIOS — on-device testing remains the source of truth

### Architecture Completeness Checklist

**Requirements Analysis**
- [x] Project context thoroughly analysed
- [x] Scale and complexity assessed
- [x] Technical constraints identified (Z80, CP/M, TPA, 8 MHz)
- [x] Cross-cutting concerns mapped (register discipline, memory layout, error recovery, kernel/Forth boundary)

**Architectural Decisions**
- [x] All critical decisions documented (memory layout, threading, dictionary format, code field, error handling, cold start)
- [x] Technology stack fully specified (sjasmplus, GNU Make, cpmtools)
- [x] Integration patterns defined (BDOS interaction, include order)
- [x] Performance considerations addressed (CODE vs Forth boundary, cycle-efficient hot paths)

**Implementation Patterns**
- [x] Naming conventions established (w_, h_, UPPER_SNAKE, PascalCase, lower_snake)
- [x] Structure patterns defined (DEFCODE/DEFWORD/DEFIMMED)
- [x] Communication patterns specified (BDOS_SAVE/RESTORE)
- [x] Process patterns documented (error messages, comment conventions)

**Project Structure**
- [x] Complete directory structure defined
- [x] Component boundaries established (kernel vs bootstrap)
- [x] Integration points mapped (include order, data flow)
- [x] Requirements to structure mapping complete (FR-to-file table)

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — the architecture is well-defined, internally consistent, and covers all 48 FRs and 11 NFRs. The domain (Forth implementation) is well-understood with 50 years of prior art, and the decisions made are conventional and proven.

**Key Strengths:**
- Clean separation of concerns across source files
- Macro-driven consistency for the most error-prone operations (dictionary headers, BDOS calls)
- Explicit register contract that can be mechanically verified
- Clear kernel/Forth boundary with a pragmatic "start in Forth, promote to CODE" principle
- Memory layout designed for future banking without requiring kernel rework
- Cold start protocol explicitly documented

**Areas for Future Enhancement (Post-MVP):**
- Bank switching protocol details
- Search-Order wordset architecture (multiple vocabulary hash tables)
- File-Access wordset integration with CP/M FCBs

**First Implementation Priority:**
Project initialisation — create Makefile, directory structure, `constants.asm`, `macros.asm`, and a minimal `antforth.asm` that assembles to a .COM file and exits cleanly via BYE. Second priority: minimal REPL that can execute a hardcoded word, providing a test harness for everything that follows.

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect project structure and boundaries
- Preserve the register contract in every CODE word — no exceptions
- Use DEFCODE/DEFWORD/DEFIMMED macros for all word definitions
- Use BDOS_SAVE/BDOS_RESTORE for all CP/M system calls
- Refer to this document for all architectural questions
