# Story 6.2: Return-Stack Push/Pop Subroutines

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want repeated inline return-stack push/pop patterns extracted into shared subroutines,
so that the binary shrinks by ~200+ bytes without changing any observable behaviour.

## Acceptance Criteria

1. **Given** the new `rpush_de` subroutine in `src/inner_interpreter.asm` **When** any code calls it **Then** DE is pushed onto the return stack (IX), IX decremented by 2, and the subroutine returns. Clobbers: none (only IX modified).

2. **Given** the new `rpop_de` subroutine in `src/inner_interpreter.asm` **When** any code calls it **Then** DE is popped from the return stack (IX), IX incremented by 2, and the subroutine returns. Clobbers: none (only DE and IX modified).

3. **Given** the new `rpush_bc` subroutine in `src/inner_interpreter.asm` **When** any code calls it **Then** BC is pushed onto the return stack (IX), IX decremented by 2, and the subroutine returns. Clobbers: none (only IX modified).

4. **Given** all inline `DEC IX / DEC IX / LD (IX+0),E / LD (IX+1),D` sequences (except in DOCOL and DODOES) **When** each is replaced with `CALL rpush_de` **Then** `make test && make test-repl` passes all regression tests with zero failures.

5. **Given** all inline `LD E,(IX+0) / LD D,(IX+1) / INC IX / INC IX` sequences (except in EXIT_CODE) **When** each is replaced with `CALL rpop_de` **Then** all tests pass.

6. **Given** all inline `DEC IX / DEC IX / LD (IX+0),C / LD (IX+1),B` sequences **When** each is replaced with `CALL rpush_bc` **Then** all tests pass.

7. **Given** all replacements are complete **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 180 bytes smaller than the pre-story baseline (15,294 bytes).

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #7)
  - [x] 0.1 `make asm && wc -c build/antforth.com` — confirm 15,294 bytes
  - [x] 0.2 `make test && make test-repl` — confirm all tests pass before any changes

- [x] Task 1: Create 3 subroutines in `src/inner_interpreter.asm` (AC: #1, #2, #3)
  - [x] 1.1 Add subroutines after DOMARKER (before w_LIT), with section comment:
    ```asm
    ; -----------------------------------------------
    ; Internal return-stack helpers (not Forth words)
    ; -----------------------------------------------
    rpush_de:                       ; Push DE onto return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        RET                         ; 9 bytes

    rpop_de:                        ; Pop DE from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        RET                         ; 9 bytes

    rpush_bc:                       ; Push BC onto return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B
        RET                         ; 9 bytes
    ```
  - [x] 1.2 Build passes: `make asm`

- [x] Task 2: Replace rpush_de sites in `src/assembler.asm` (AC: #4)
  - [x] 2.1 `w_CODE_cf` (~L1291) — replace inline rpush_de with `CALL rpush_de`
  - [x] 2.2 `w_END_CODE_cf` (~L1367) — replace inline rpush_de
  - [x] 2.3 `w_NEXT_COMMA_cf` (~L2363) — replace inline rpush_de
  - [x] 2.4 `w_LABEL_cf` (~L2431) — replace inline rpush_de
  - [x] 2.5 Build and test: `make asm && make test && make test-repl`

- [x] Task 3: Replace rpush_bc sites in `src/assembler.asm` (AC: #6)
  - [x] 3.1 `w_CODE_cf` (~L1295) — replace inline rpush_bc with `CALL rpush_bc`
  - [x] 3.2 `w_END_CODE_cf` (~L1371) — replace inline rpush_bc
  - [x] 3.3 `w_NEXT_COMMA_cf` (~L2367) — replace inline rpush_bc
  - [x] 3.4 `w_LABEL_cf` (~L2435) — replace inline rpush_bc
  - [x] 3.5 Build and test: `make asm && make test && make test-repl`

- [x] Task 4: Replace rpush_de + rpush_bc sites in `src/compiler.asm` (AC: #4, #6)
  - [x] 4.1 `w_COLON_cf` (~L362) — replace rpush_de + rpush_bc pair
  - [x] 4.2 `w_CREATE_cf` (~L576) — replace rpush_de + rpush_bc pair
  - [x] 4.3 `w_CONSTANT_cf` (~L636) — replace rpush_de + rpush_bc pair
  - [x] 4.4 Build and test: `make asm && make test && make test-repl`

- [x] Task 5: Replace rpop_de site in `src/compiler.asm` (AC: #5)
  - [x] 5.1 `w_PAREN_DOES_cf` (~L756) — replace inline rpop_de with `CALL rpop_de`
  - [x] 5.2 Build and test: `make asm && make test && make test-repl`

- [x] Task 6: Replace sites in `src/formatting.asm` (AC: #4, #5, #6)
  - [x] 6.1 `w_DOT_cf` (~L110) — rpush_de; (~L132) — rpop_de
  - [x] 6.2 `w_U_DOT_cf` (~L149) — rpush_de; (~L155) — rpop_de
  - [x] 6.3 `w_DOT_R_cf` (~L174) — rpush_de; (~L180) — rpush_bc; (~L252) — rpop_de
  - [x] 6.4 `w_DOT_S_cf` (~L277) — rpush_de; (~L283) — rpush_bc; (~L373) — rpop_de
  - [x] 6.5 Build and test: `make asm && make test && make test-repl`

- [x] Task 7: Replace sites in `src/strings.asm` (AC: #4, #5)
  - [x] 7.1 `w_WORD_cf` (~L15) — rpush_de; (~L78, ~L155) — 2x rpop_de
  - [x] 7.2 `w_CHAR_cf` (~L176) — rpush_de; (~L264) — rpop_de
  - [x] 7.3 `w_TO_NUMBER_cf` (~L377) — rpush_de; (~L403) — rpop_de
  - [x] 7.4 `w_NUMBER_Q_cf` (~L419) — rpush_de; (~L479, ~L491) — 2x rpop_de
  - [x] 7.5 `w_PAREN_cf` (~L888) — rpush_de; (~L932) — rpop_de
  - [x] 7.6 Build and test: `make asm && make test && make test-repl`

- [x] Task 8: Replace sites in remaining files (AC: #4, #5, #6)
  - [x] 8.1 `src/io.asm` — `w_ACCEPT_cf` (~L123) rpush_de; (~L150) rpop_de
  - [x] 8.2 `src/memory.asm` — `w_FILL_cf` (~L229) rpush_de, (~L257) rpop_de; `w_MOVE_cf` (~L274) rpush_de, (~L308) rpop_de
  - [x] 8.3 `src/stack_ops.asm` — `w_ROLL_cf` (~L125) rpush_de, (~L172) rpop_de
  - [x] 8.4 `src/outer_interpreter.asm` — `w_QUERY_cf` (~L99) rpush_de, (~L103) rpush_bc
  - [x] 8.5 `src/control_flow.asm` — `w_PAREN_DO_cf` (~L207) rpush_bc
  - [x] 8.6 `src/system.asm` — `w_MARKER_cf` (~L25) rpush_de, (~L29) rpush_bc; `w_PAREN_ABORT_QUOTE_cf` (~L144) rpush_de
  - [x] 8.7 Build and test: `make asm && make test && make test-repl`

- [x] Task 9: Replace sites in `src/inner_interpreter.asm` — DOMARKER only (AC: #4, #6)
  - [x] 9.1 `DOMARKER` (~L101-108) — replace rpush_de + rpush_bc pair with `CALL rpush_de / CALL rpush_bc`
  - [x] 9.2 `DOMARKER` (~L130-133) — replace rpop_de with `CALL rpop_de`
  - [x] 9.3 **DO NOT TOUCH** DOCOL (L9-14), EXIT_CODE (L32-37), or DODOES (L72-75) — these are the hottest paths
  - [x] 9.4 Build and test: `make asm && make test && make test-repl`

- [x] Task 10: Final verification (AC: #7)
  - [x] 10.1 `make test && make test-repl` — all tests green
  - [x] 10.2 `wc -c build/antforth.com` — record final size, compute delta from 15,294 baseline
  - [x] 10.3 Verify savings >= 180 bytes (actual: 345 bytes saved)

## Dev Notes

### Register Contract (critical — violating this will corrupt execution)

- `BC` = TOS (top of parameter stack). Always valid after any Forth word returns.
- `DE` = IP (instruction pointer into threaded code). Never touch in CODE words except via NEXT.
- `SP` = parameter stack pointer (grows downward). PUSH/POP for stack operations.
- `IX` = return stack pointer (grows downward). Used by `>R`, `R>`, DOCOL, EXIT.
- `HL`, `AF` = scratch. Free to use within CODE words.
- **BDOS clobbers ALL registers** (A, BC, DE, HL, F). Any register needed after a BDOS call must be saved/restored.

### New Subroutine Contracts

| Subroutine | Entry | Exit | Clobbers | Size |
|---|---|---|---|---|
| `rpush_de` | DE = value to push | IX decremented by 2 | (none besides IX) | 9 bytes |
| `rpop_de`  | IX points to saved DE | DE restored, IX incremented by 2 | (none besides DE, IX) | 9 bytes |
| `rpush_bc` | BC = value to push | IX decremented by 2 | (none besides IX) | 9 bytes |

**Total subroutine cost: 27 bytes**

### Mechanical Substitution Pattern

```asm
; BEFORE (8 bytes) — rpush_de:
    DEC     IX
    DEC     IX
    LD      (IX+0), E
    LD      (IX+1), D

; AFTER (3 bytes):
    CALL    rpush_de
```

Each site saves 5 bytes (8 inline → 3 CALL).

### Exclusions — DO NOT CONVERT

These are the hottest paths in the system. The +17 T-state overhead per CALL/RET is unacceptable here:

| Label | File | Line | Pattern | Reason |
|-------|------|------|---------|--------|
| `DOCOL` | inner_interpreter.asm | ~L11 | rpush_de | Called on every colon word entry |
| `EXIT_CODE` | inner_interpreter.asm | ~L34 | rpop_de | Called on every colon word return |
| `DODOES` | inner_interpreter.asm | ~L72 | rpush_de | Called on every DOES> word execution |

### rpop_bc — Missed Optimization (Review Finding)

~~One `rpop_bc` pattern exists at `stack_ops.asm:~L272` (in `w_R_FROM_cf`). Adding a 9-byte subroutine for 1 call-site would cost 4 bytes net. Leave it inline.~~

**Code review correction:** The initial survey was wrong. There are **16 inline rpop_bc sites** (14 convertible + DOMARKER + R>), not 1. A 9-byte `rpop_bc` subroutine converting the 14 non-excluded sites would save ~61 bytes. The survey missed that every rpush_bc call-site has a corresponding rpop_bc. Tracked as follow-up for Story 6.7.

### Critical Gotcha: DOMARKER Push/Pop Order

DOMARKER at inner_interpreter.asm:~L100 pushes DE then BC (both to rstack), then pops BC then DE (LIFO order). After conversion:
```asm
; Push phase:
    CALL    rpush_de        ; Save IP first
    CALL    rpush_bc        ; Save TOS second

; ... LDIR clobbers DE and BC ...

; Pop phase (reverse order):
    LD      B, (IX+1)       ; rpop_bc left INLINE here (DOMARKER is excluded hot-ish path)
    LD      C, (IX+0)
    INC     IX
    INC     IX
    CALL    rpop_de         ; Restore IP
```

### Critical Gotcha: w_WORD_cf Has Two rpop_de Sites

`w_WORD_cf` in strings.asm has two separate exit paths (~L78 and ~L155) each with an inline rpop_de. Both must be converted.

### Critical Gotcha: w_NUMBER_Q_cf Has Two rpop_de Sites

`w_NUMBER_Q_cf` in strings.asm has two exit paths (~L479 success and ~L491 failure) each with rpop_de. Both must be converted.

### Performance Impact

+17 T-states per call (10 for CALL + 10 for RET - 3 for removed instructions). At 8 MHz, this is ~2.1us per call. Negligible for all converted sites — these are not inner-loop primitives. The excluded DOCOL/EXIT/DODOES paths are the only ones where this matters.

### Savings Estimate

| Item | Count | Bytes |
|---|---|---|
| rpush_de sites (excl. DOCOL, DODOES) | 24 | 24 x 5 = 120 |
| rpop_de sites (excl. EXIT_CODE) | 17 | 17 x 5 = 85 |
| rpush_bc sites | 13 | 13 x 5 = 65 |
| Subroutine bodies | 3 | -27 |
| **Net savings** | **54 sites** | **243 bytes** |
| **Actual measured savings** | | **345 bytes** |

*Note: Actual savings exceed estimate because IX-prefixed instructions are multi-byte (3-4 bytes each), so the 8-byte inline patterns undercount the real cost. Measured delta: 15,294 → 14,949 = 345 bytes.*

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Learnings from Story 6.1

- Mechanical substitution works cleanly — 6.1 had 48 sites across 9 files with zero regressions
- sjasmplus multi-pass assembler handles forward references — no include reorder needed
- Build-test-verify after each file group catches issues early
- Tail-call variants (JP instead of CALL) don't apply here — rstack operations are always mid-word, never at word boundaries
- The `EQU` alias pattern used for promoted subroutines in 6.1 is NOT needed here — rpush_de/rpop_de/rpush_bc are new names, no backward compatibility aliases required

### Project Structure Notes

- Subroutines live in `src/inner_interpreter.asm` because they are part of the inner interpreter's return-stack management
- They are NOT Forth words (no DEFCODE/dictionary entry) — just assembler labels
- Placement after DOMARKER and before w_LIT keeps them grouped with other return-stack infrastructure
- All source in `src/` directory, included by `src/antforth.asm` manifest

### References

- [Source: src/inner_interpreter.asm:9-14] — DOCOL (rpush_de, EXCLUDED)
- [Source: src/inner_interpreter.asm:32-38] — EXIT_CODE (rpop_de, EXCLUDED)
- [Source: src/inner_interpreter.asm:72-75] — DODOES (rpush_de, EXCLUDED)
- [Source: src/inner_interpreter.asm:100-133] — DOMARKER (rpush_de + rpush_bc + rpop_bc + rpop_de, partially convertible)
- [Source: src/stack_ops.asm:272-276] — w_R_FROM_cf (rpop_bc, leave inline)
- [Source: _bmad-output/planning-artifacts/epic6-code-size-optimization.md#Story 6.2] — Epic specification
- [Source: _bmad-output/implementation-artifacts/6-1-bdos-output-helpers.md] — Previous story patterns and learnings

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No issues encountered. All substitutions were mechanical and passed tests on first attempt.

### Completion Notes List

- Baseline: 15,294 bytes, 258 REPL tests + assembly regression suite all passing
- Created 3 subroutines (rpush_de, rpop_de, rpush_bc) in inner_interpreter.asm after DOMARKER, before w_LIT — 27 bytes total subroutine cost
- Replaced 54 inline sites across 10 source files with CALL subroutine equivalents (24 rpush_de + 17 rpop_de + 13 rpush_bc)
- Excluded DOCOL, EXIT_CODE, DODOES (hot paths)
- 14 inline rpop_bc sites remain unconverted — missed optimization identified during code review, tracked for Story 6.7
- Final binary: 14,949 bytes — **345 bytes saved** (92% above 180-byte minimum)
- All tests pass: assembly regression + 258 REPL tests, zero regressions

### Change Log

- 2026-04-13: Story 6.2 implemented — extracted rpush_de/rpop_de/rpush_bc subroutines, replaced 54 inline sites across 10 files, binary reduced by 345 bytes
- 2026-04-13: Code review — corrected rpop_bc survey (16 sites, not 1), updated site counts (54 actual vs 51 estimated), flagged rpop_bc as follow-up for 6.7

### File List

- src/inner_interpreter.asm (added rpush_de, rpop_de, rpush_bc subroutines; converted DOMARKER inline patterns)
- src/assembler.asm (converted w_CODE_cf, w_END_CODE_cf, w_NEXT_COMMA_cf, w_LABEL_cf)
- src/compiler.asm (converted w_COLON_cf, w_CREATE_cf, w_CONSTANT_cf, w_PAREN_DOES_cf)
- src/formatting.asm (converted w_DOT_cf, w_U_DOT_cf, w_DOT_R_cf, w_DOT_S_cf)
- src/strings.asm (converted w_WORD_cf, w_CHAR_cf, w_TO_NUMBER_cf, w_NUMBER_Q_cf, w_PAREN_cf)
- src/io.asm (converted w_ACCEPT_cf)
- src/memory.asm (converted w_FILL_cf, w_MOVE_cf)
- src/stack_ops.asm (converted w_ROLL_cf)
- src/outer_interpreter.asm (converted w_QUERY_cf)
- src/control_flow.asm (converted w_PAREN_DO_cf)
- src/system.asm (converted w_MARKER_cf, w_PAREN_ABORT_QUOTE_cf)
