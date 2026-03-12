# Story 1.1: Project Scaffolding & Build Toolchain

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a complete project structure with build toolchain,
So that I can assemble Z80 source into a CP/M .COM binary and test it under emulation.

## Acceptance Criteria

1. **Given** a fresh clone of the repository **When** I run `make` **Then** sjasmplus assembles `src/antforth.asm` into `build/antforth.com` **And** the .COM binary entry point is at 0x0100 per CP/M convention

2. **Given** the assembled .COM binary **When** I run it under iz-cpm **Then** it exits cleanly back to CP/M via BDOS function 0 (P_TERMCPM)

3. **Given** the project directory **When** I inspect the structure **Then** all source files from the architecture spec exist:
   - `src/antforth.asm` — main assembly manifest (includes all components in dependency order)
   - `src/constants.asm` — memory layout equates (TPA start, stack bases, TIB address, HASH_BUCKETS, BDOS_ENTRY)
   - `src/macros.asm` — NEXT, DOCOL, EXIT, DEFCODE, DEFWORD, DEFIMMED, BDOS_SAVE, BDOS_RESTORE macros
   - `src/structures.asm` — sjasmplus STRUCT definitions (DictEntry, UserArea)
   - Remaining source stubs for all architecture-specified files (empty or minimal)

4. **Given** the project directory **When** I inspect `.gitignore` **Then** `build/` is excluded

5. **Given** a source file change **When** I run `make` again **Then** only changed files trigger reassembly (incremental build via Make dependency tracking)

## Tasks / Subtasks

- [ ] Task 1: Create project directory structure (AC: #3, #4)
  - [ ] 1.1 Create `src/`, `tests/`, `build/`, `disk/`, `docs/` directories
  - [ ] 1.2 Create `.gitignore` excluding `build/`
- [ ] Task 2: Create `Makefile` with build targets (AC: #1, #5)
  - [ ] 2.1 `make` / `make asm` — assemble `src/antforth.asm` → `build/antforth.com`
  - [ ] 2.2 `make disk` — build CP/M disk image via cpmtools → `build/antforth.img`
  - [ ] 2.3 `make test` — assemble then run test suite under iz-cpm
  - [ ] 2.4 `make clean` — remove `build/` artifacts
  - [ ] 2.5 Dependency tracking: sjasmplus include scanning so incremental builds work
- [ ] Task 3: Create `src/constants.asm` — memory layout and system equates (AC: #3)
  - [ ] 3.1 TPA_START (0x0100), BDOS_ENTRY (0x0005)
  - [ ] 3.2 Parameter stack base (top of TPA, below BDOS — use CP/M convention: read word at 0x0006 for BDOS address)
  - [ ] 3.3 Return stack base (below parameter stack region)
  - [ ] 3.4 User variable area base (IY)
  - [ ] 3.5 TIB address and TIB_SIZE (128 bytes)
  - [ ] 3.6 HASH_BUCKETS (64)
  - [ ] 3.7 Stack sizes, PAD offset, and other system constants
- [ ] Task 4: Create `src/macros.asm` — threading and dictionary macros (AC: #3)
  - [ ] 4.1 NEXT macro (fetch via DE, load HL, JP (HL))
  - [ ] 4.2 DOCOL routine (push IP to return stack IX, set IP to body)
  - [ ] 4.3 EXIT routine (pop IP from return stack, NEXT)
  - [ ] 4.4 DEFCODE macro (dictionary header + inline CODE body)
  - [ ] 4.5 DEFWORD macro (dictionary header + JP DOCOL + thread body)
  - [ ] 4.6 DEFIMMED macro (dictionary header with IMMEDIATE flag + JP DOCOL)
  - [ ] 4.7 BDOS_SAVE / BDOS_RESTORE macros (save/restore DE and BC around BDOS calls)
  - [ ] 4.8 XOR-rotate hash computation within macros for link-chain insertion at assembly time
- [ ] Task 5: Create `src/structures.asm` — sjasmplus STRUCT definitions (AC: #3)
  - [ ] 5.1 DictEntry structure
  - [ ] 5.2 UserArea structure
- [ ] Task 6: Create `src/antforth.asm` — main assembly manifest (AC: #1, #2)
  - [ ] 6.1 ORG 0x0100 (CP/M .COM entry point)
  - [ ] 6.2 Include all source files in dependency order per architecture
  - [ ] 6.3 Cold start: minimal init that calls BYE (BDOS function 0) to exit cleanly
- [ ] Task 7: Create stub files for remaining architecture source files (AC: #3)
  - [ ] 7.1 `inner_interpreter.asm`, `outer_interpreter.asm`, `compiler.asm`
  - [ ] 7.2 `dictionary.asm`, `hash.asm`
  - [ ] 7.3 `stack_ops.asm`, `arithmetic.asm`, `logic.asm`, `memory.asm`
  - [ ] 7.4 `control_flow.asm`, `io.asm`, `strings.asm`, `formatting.asm`
  - [ ] 7.5 `assembler.asm`, `system.asm`, `bootstrap.asm`
- [ ] Task 8: Verify build and clean exit (AC: #1, #2)
  - [ ] 8.1 `make` succeeds and produces `build/antforth.com`
  - [ ] 8.2 Run under iz-cpm and confirm clean CP/M exit (return code 0)
  - [ ] 8.3 `make clean` removes artifacts, `make` rebuilds from scratch

## Dev Notes

### Toolchain Status

- **sjasmplus v1.21.0** is installed at `/usr/local/bin/sjasmplus`
- **iz-cpm** is NOT installed. Install via: `cargo install iz-cpm` (Rust cargo v1.91.1 is available)
- **cpmtools** is NOT installed. Install via `apt install cpmtools` or equivalent. Required for `make disk` target only — not needed for `make` or `make test`

### Architecture Patterns & Constraints

**Register Contract (inviolable — applies to ALL future CODE words):**

| Register | Role | Rules |
|----------|------|-------|
| BC | TOS (top of parameter stack) | Contains TOS on entry; must contain new TOS on exit |
| DE | IP (instruction pointer) | Must be preserved — NEXT reads through DE |
| SP | Parameter stack | Standard Z80 stack pointer, grows downward |
| IX | Return stack pointer | Preserved unless doing return stack ops |
| IY | User pointer | Points to user variable area |
| HL | W (working register) | Free scratch |
| AF | Flags/accumulator | Free scratch |

**Memory Layout (define in constants.asm):**
```
0x0000-0x00FF  CP/M zero page (vectors, FCBs, command tail)
0x0005         BDOS entry point
0x0006-0x0007  BDOS address (read at runtime for TPA top)
0x0100         .COM entry point / kernel code starts here
  ...          Kernel code grows upward
[HERE]         End of kernel → dictionary grows upward from here
  ...          Free dictionary space
[PAD]          84 bytes above HERE (moves with HERE)
  ...          Gap (free space)
[RS_FLOOR]     Return stack floor (IX grows downward from RS_BASE)
[RS_BASE]      Return stack base
[PS_FLOOR]     Parameter stack floor (SP grows downward from PS_BASE)
[PS_BASE]      Top of TPA, just below BDOS (read from 0x0006)
[BDOS]         CP/M BDOS
```

**Cold Start Protocol (implement in antforth.asm for this story — minimal version):**
For this story, cold start only needs to call BYE (BDOS function 0). Full cold start (SP, IX, IY, STATE, BASE, hash buckets, HERE, TIB) will be implemented in Story 1.2.

**CP/M .COM binary requirements:**
- Entry at ORG 0x0100
- No header — raw binary loaded by CCP
- BYE = `LD C, 0` then `JP 0x0005` (BDOS P_TERMCPM, function 0)

**sjasmplus-specific notes:**
- Use `--fullpath` flag for include dependency tracking if available
- Output binary with `--raw=build/antforth.com` or `DEVICE NONE` + `SAVEBIN`
- sjasmplus uses `INCLUDE "file.asm"` directive
- sjasmplus supports `MACRO`/`ENDM`, `STRUCT`/`ENDS`, `DUP`/`EDUP` (repeat), conditional assembly via `IF`/`ENDIF`
- sjasmplus hash computation at assembly time: use `LUA` block or repeated `MACRO` expansion with arithmetic expressions
- For assembly-time hash: sjasmplus supports string functions and arithmetic in expressions. The XOR-rotate hash can be computed character-by-character using nested macros or LUA scripting within sjasmplus

**Makefile notes:**
- sjasmplus does not have a built-in dependency output mode like gcc's `-M`. For incremental builds, depend on ALL `.asm` files in `src/` — this is sufficient since sjasmplus assembles fast
- `make test` target should: (1) build, (2) invoke iz-cpm with the .COM binary. For this story, a minimal smoke test is sufficient: run antforth.com and check it exits cleanly
- iz-cpm invocation: `iz-cpm antforth.com` runs the .COM file. It maps the current directory as drive A:. Exit code 0 = clean termination

**Dictionary header macros (DEFCODE/DEFWORD/DEFIMMED) — critical design:**
The macros must:
1. Compute XOR-rotate hash of the word name at assembly time
2. Emit hash-link (2 bytes) pointing to previous entry in same bucket, update bucket head
3. Emit count+flags byte (low 5 bits = name length, bit 7 = IMMEDIATE, bit 6 = SMUDGE)
4. Emit name string (n bytes)
5. For DEFCODE: label the code field, body follows inline
6. For DEFWORD/DEFIMMED: emit `JP DOCOL`, body is a thread of DW addresses

The hash bucket heads must be maintained as assembly-time variables (one per bucket, 64 total). Each DEFCODE/DEFWORD/DEFIMMED invocation updates the appropriate bucket head.

**XOR-rotate hash algorithm:**
```
hash = 0
for each character c in name (case-insensitive, uppercase):
    hash = hash XOR c
    hash = (hash << 1) | (hash >> 7)   ; 8-bit rotate left
hash = hash AND 63                       ; mod 64 for bucket index
```

**Stub files:** Create all architecture-specified `.asm` files with just a file header comment. They must assemble without errors (empty content is fine — sjasmplus handles empty includes).

### Project Structure Notes

- Directory structure matches architecture spec exactly: `src/`, `tests/`, `build/`, `disk/`, `docs/`
- `build/` is gitignored — all build artifacts go here
- `tests/core_tests.fth` can be created as an empty stub for now
- No conflicts with existing files — this is a greenfield project, no files exist in `src/` yet

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Starter Template Evaluation] — toolchain selection and conventions
- [Source: _bmad-output/planning-artifacts/architecture.md#Core Architectural Decisions] — memory layout, cold start, dictionary format, code field layout
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns & Consistency Rules] — naming, register discipline, BDOS interaction, comment conventions
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries] — complete directory structure, include order, build process
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1] — acceptance criteria and user story
- [Source: _bmad-output/planning-artifacts/architecture.md#Testing Strategy] — iz-cpm automated regression, make test

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
