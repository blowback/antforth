# Story 5.4: ANS Forth Core Quick Wins

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth programmer,
I want the missing trivial-to-moderate ANS Core words implemented,
so that antforth reaches ~83% Core compliance and portable Forth code works without modification.

## Acceptance Criteria

1. **Given** the 15 words listed below **When** each is implemented **Then** it is callable from the REPL and from colon definitions, with correct stack effects per DPANS94

2. **Given** each new word **When** tested **Then** at least one REPL-piped test in the Makefile exercises the word's primary behaviour and key edge case(s)

3. **Given** all new words are implemented **When** the existing test suite runs **Then** all 73 assembly tests and all existing REPL tests still pass (zero regressions)

4. **Given** story completion **When** the compliance report is updated **Then** `docs/ans-forth-core-compliance.md` reflects the new word count, updated statuses, source locations, and revised compliance percentage

## Word List (15 words)

### Tier 1 — Trivial DEFCODE (9 words)

| Word | Stack Effect | Implementation | Target File |
|------|-------------|----------------|-------------|
| `1+` | `( n -- n+1 )` | `INC BC` | `src/arithmetic.asm` |
| `1-` | `( n -- n-1 )` | `DEC BC` | `src/arithmetic.asm` |
| `2*` | `( x -- x*2 )` | `SLA C` / `RL B` | `src/arithmetic.asm` |
| `2/` | `( x -- x/2 )` | `SRA B` / `RR C` | `src/arithmetic.asm` |
| `?DUP` | `( x -- 0 \| x x )` | Test BC; if non-zero, PUSH BC | `src/stack_ops.asm` |
| `CELL+` | `( a-addr -- a-addr+2 )` | `INC BC; INC BC` (cell = 2 bytes on Z80) | `src/memory.asm` |
| `CHAR+` | `( c-addr -- c-addr+1 )` | `INC BC` (Z80: 1 char = 1 byte) | `src/memory.asm` |
| `CHARS` | `( n -- n )` | No-op, just NEXT (Z80: 1 char = 1 byte) | `src/memory.asm` |
| `>BODY` | `( xt -- a-addr )` | `INC BC; INC BC; INC BC` (skip 3-byte JP) | `src/compiler.asm` |

### Tier 2 — Simple DEFCODE (3 words)

| Word | Stack Effect | Implementation | Target File |
|------|-------------|----------------|-------------|
| `EXIT` | `( -- ) ( R: nest-sys -- )` | DEFCODE wrapping existing `EXIT_CODE` at `inner_interpreter.asm:23` | `src/inner_interpreter.asm` |
| `CHAR` | `( "<spaces>name" -- char )` | Call `w_BL_cf` + WORD, then C@ first byte of counted string | `src/strings.asm` |
| `'` (tick) | `( "<spaces>name" -- xt )` | Call WORD + FIND; error if not found; return xt | `src/compiler.asm` |

### Tier 3 — Compile-time DEFIMMED (2 words, depend on Tier 2)

| Word | Stack Effect | Implementation | Target File |
|------|-------------|----------------|-------------|
| `[']` | `( "<spaces>name" -- )` compile: `( -- xt )` | Call `'` at compile time, compile result as literal | `src/compiler.asm` |
| `[CHAR]` | `( "<spaces>name" -- )` compile: `( -- char )` | Call `CHAR` at compile time, compile result as literal | `src/compiler.asm` |

### Tier 4 — Moderate (1 word)

| Word | Stack Effect | Implementation | Target File |
|------|-------------|----------------|-------------|
| `ABORT"` | `( "ccc" x -- )` | DEFIMMED: compile inline string + runtime helper `(ABORT")` that checks flag, types message, calls ABORT | `src/system.asm` |

### Explicitly Deferred

- `EVALUATE` — requires input source save/restore; post-MVP
- Double-cell subsystem (13 words) — `2DROP`, `2DUP`, `2OVER`, `2SWAP`, `2!`, `2@`, `S>D`, `M*`, `UM*`, `UM/MOD`, `FM/MOD`, `SM/REM`, `*/`, `*/MOD`
- Pictured numeric output (6 words) — `<#`, `#`, `#S`, `#>`, `HOLD`, `SIGN`

## Tasks / Subtasks

- [ ] Task 1: Implement Tier 1 trivial DEFCODE words (AC: #1)
  - [ ] 1.1 `1+` in `src/arithmetic.asm` — DEFCODE "1+", 0; INC BC; NEXT
  - [ ] 1.2 `1-` in `src/arithmetic.asm` — DEFCODE "1-", 0; DEC BC; NEXT
  - [ ] 1.3 `2*` in `src/arithmetic.asm` — DEFCODE "2*", 0; SLA C; RL B; NEXT
  - [ ] 1.4 `2/` in `src/arithmetic.asm` — DEFCODE "2/", 0; SRA B; RR C; NEXT
  - [ ] 1.5 `?DUP` in `src/stack_ops.asm` — DEFCODE "?DUP", 0; test BC zero; if non-zero PUSH BC; NEXT
  - [ ] 1.6 `CELL+` in `src/memory.asm` — DEFCODE "CELL+", 0; INC BC; INC BC; NEXT
  - [ ] 1.7 `CHAR+` in `src/memory.asm` — DEFCODE "CHAR+", 0; INC BC; NEXT (identical to 1+)
  - [ ] 1.8 `CHARS` in `src/memory.asm` — DEFCODE "CHARS", 0; NEXT (no-op)
  - [ ] 1.9 `>BODY` in `src/compiler.asm` — DEFCODE ">BODY", 0; INC BC; INC BC; INC BC; NEXT

- [ ] Task 2: Implement Tier 2 simple DEFCODE words (AC: #1)
  - [ ] 2.1 `EXIT` in `src/inner_interpreter.asm` — DEFCODE "EXIT", 0; JP EXIT_CODE (or inline the 6-instruction body)
  - [ ] 2.2 `CHAR` in `src/strings.asm` — DEFCODE "CHAR", 0; call BL WORD to parse next token; load first byte of counted string into C, zero B; NEXT
  - [ ] 2.3 `'` (tick) in `src/compiler.asm` — DEFCODE "'", 0; call BL WORD FIND; if FIND returns 0, call error handler (word not found); else push xt in BC; NEXT
- [ ] Task 3: Implement Tier 3 compile-time DEFIMMED words (AC: #1)
  - [ ] 3.1 `[']` in `src/compiler.asm` — DEFIMMED "[']"; thread: tick, w_LIT_cf (compile xt as literal), COMMA, EXIT_CODE. Or: DEFIMMED that calls `'` then compiles the result using LITERAL logic (compile LIT + value)
  - [ ] 3.2 `[CHAR]` in `src/compiler.asm` — DEFIMMED "[CHAR]"; thread: CHAR, then compile result as literal using LITERAL logic

- [ ] Task 4: Implement ABORT" (AC: #1)
  - [ ] 4.1 Create runtime helper `(ABORT")` in `src/system.asm` — DEFCODE that: pops flag from stack; if flag is zero, skip inline string and continue; if flag is non-zero, print inline counted string via TYPE, then call ABORT
  - [ ] 4.2 Create `ABORT"` in `src/system.asm` — DEFIMMED "ABORT\""; at compile time: compile reference to `(ABORT")`, then compile inline string (same pattern as `."` in `src/strings.asm:655`)

- [ ] Task 5: Add REPL-piped tests for all 15 words (AC: #2)
  - [ ] 5.1 Tests for `1+`, `1-`: `5 1+ .` expects `6`; `5 1- .` expects `4`; edge: `0 1- .` expects `-1`; `-1 1+ .` expects `0`
  - [ ] 5.2 Tests for `2*`, `2/`: `7 2* .` expects `14`; `14 2/ .` expects `7`; edge: `-6 2/ .` expects `-3` (arithmetic shift)
  - [ ] 5.3 Tests for `?DUP`: `5 ?DUP . .` expects `5 5`; `0 ?DUP .` expects `0` (only one value on stack)
  - [ ] 5.4 Tests for `CELL+`, `CHAR+`, `CHARS`: `1000 CELL+ .` expects `1002`; `1000 CHAR+ .` expects `1001`; `5 CHARS .` expects `5`
  - [ ] 5.5 Test for `EXIT`: `: TEST-EXIT 1 EXIT 2 ; TEST-EXIT .` expects `1` (2 never reached)
  - [ ] 5.6 Test for `CHAR`: `CHAR A .` expects `65`; `CHAR Z .` expects `90`
  - [ ] 5.7 Test for `'` (tick): `' DUP EXECUTE .` — define a test word, tick it, execute it
  - [ ] 5.8 Test for `>BODY`: `CREATE FOO 42 , FOO >BODY @ .` expects `42` (FOO's xt + 3 = data field containing 42, but note CREATE already points to body via DOVAR; verify correct offset)
  - [ ] 5.9 Test for `[']`: `: USE-TICK ['] DUP EXECUTE ; 7 USE-TICK . .` expects `7 7`
  - [ ] 5.10 Test for `[CHAR]`: `: GET-A [CHAR] A ; GET-A .` expects `65`
  - [ ] 5.11 Test for `ABORT"`: `: CHK 0= ABORT" nonzero" ; 0 CHK` should not abort; `1 CHK` should abort with message containing "nonzero"

- [ ] Task 6: Run full regression suite (AC: #3)
  - [ ] 6.1 `make test` — all 73 assembly thread tests pass
  - [ ] 6.2 `make test-repl` — all existing REPL tests pass
  - [ ] 6.3 New REPL tests pass

- [ ] Task 7: Update compliance report (AC: #4)
  - [ ] 7.1 In `docs/ans-forth-core-compliance.md`, change status of all 15 words from "Missing" to "Implemented" with correct source file and line number
  - [ ] 7.2 Update `EXIT` from "Partial" to "Implemented"
  - [ ] 7.3 Update summary table: Fully implemented count, Missing count, compliance percentage
  - [ ] 7.4 Update Gap Analysis section: remove implemented words from oversight lists
  - [ ] 7.5 Update Quick Wins section to reflect completion
  - [ ] 7.6 Move `CHAR+` and `CHARS` from "Deliberately omitted" to "Implemented" (they were omitted because they're trivial on Z80, but we now provide them for portability)

## Dev Notes

### Register Contract (critical — violating this will corrupt execution)

- `BC` = TOS (top of parameter stack). Always valid after any word returns.
- `DE` = IP (instruction pointer into threaded code). Never touch in CODE words except via NEXT.
- `SP` = parameter stack pointer (grows downward). PUSH/POP for stack operations.
- `IX` = return stack pointer (grows downward). Used by `>R`, `R>`, DOCOL, EXIT.
- `HL`, `AF` = scratch. Free to use within CODE words.

### DEFCODE Pattern

```asm
w_YOURWORD:
        DEFCODE "YOURWORD", 0
w_YOURWORD_cf:
        ; Z80 implementation here
        ; BC = TOS on entry and exit
        ; Must end with NEXT
        NEXT
```

### DEFWORD Pattern (colon definition in assembly)

```asm
w_YOURWORD:
        DEFWORD "YOURWORD", 0
w_YOURWORD_body:
w_YOURWORD_cf EQU w_YOURWORD_body - 3
        DW w_FIRST_cf
        DW w_SECOND_cf
        DW EXIT_CODE
```

The `w_XXX_cf EQU w_XXX_body - 3` line is **mandatory** for DEFWORD — it points back to the `JP DOCOL` instruction that the macro emits, which is 3 bytes before the body.

### DEFIMMED Pattern (immediate word)

```asm
w_YOURWORD:
        DEFIMMED "YOURWORD"
w_YOURWORD_body:
w_YOURWORD_cf EQU w_YOURWORD_body - 3
        DW w_ACTION_cf
        DW EXIT_CODE
```

DEFIMMED is shorthand for `DEFWORD "NAME", F_IMMEDIATE`.

### Key Implementation Details

**EXIT:** The code already exists as `EXIT_CODE` at `inner_interpreter.asm:23`. It pops IP from return stack (IX) and does NEXT. Just wrap it: `DEFCODE "EXIT", 0` then `JP EXIT_CODE`. The word must NOT have the IMMEDIATE flag — it is a normal word compiled into definitions.

**CHAR:** Parse the next word from input (call `w_BL_cf` logic then WORD), then extract first byte. The counted string from WORD has length at byte 0, first char at byte 1. Load byte at address+1 into C, zero B.

**' (tick):** Must work at interpret time only. Parse next word (BL WORD), call FIND. FIND returns `( c-addr 0 )` if not found, `( xt 1 )` if immediate, `( xt -1 )` if normal. If 0, print error. Otherwise xt is already on stack. Look at how POSTPONE (`compiler.asm:209`) calls FIND for reference pattern.

**>BODY:** On antforth, the code field of a CREATE'd word contains `JP DOVAR` (3 bytes). The data field (body) starts immediately after. So `>BODY` = xt + 3. Three `INC BC` instructions.

**['] and [CHAR]:** These are compile-time words. `[']` parses the next word (like `'`), gets the xt, then compiles it as an inline literal (compile `w_LIT_cf` then the xt value). `[CHAR]` parses the next word (like `CHAR`), gets the char value, then compiles it as a literal. Look at how `LITERAL` (`compiler.asm:496`) compiles inline literals for the exact pattern.

**ABORT":** Two parts:
1. Runtime `(ABORT")` — a DEFCODE. On entry, BC = flag. Pop flag. If zero: skip past inline string (read count byte, advance IP past string), load new TOS from stack, NEXT. If non-zero: extract inline string address and length, call TYPE, then JP to ABORT code. Study how `(.")` runtime in `strings.asm` handles inline strings — same skip pattern.
2. Compile-time `ABORT"` — a DEFIMMED. At compile time: compile `w_PAREN_ABORT_QUOTE_cf`, then compile the inline string bytes (same pattern as `."` at `strings.asm:655`).

### Source Files to Modify

| File | Words Added |
|------|------------|
| `src/arithmetic.asm` | `1+`, `1-`, `2*`, `2/` |
| `src/stack_ops.asm` | `?DUP` |
| `src/memory.asm` | `CELL+`, `CHAR+`, `CHARS` |
| `src/inner_interpreter.asm` | `EXIT` |
| `src/strings.asm` | `CHAR` |
| `src/compiler.asm` | `'`, `>BODY`, `[']`, `[CHAR]` |
| `src/system.asm` | `(ABORT")`, `ABORT"` |
| `Makefile` | New REPL test entries |
| `docs/ans-forth-core-compliance.md` | Updated statuses and counts |

### Testing Standards

- All tests are REPL-piped Forth scripts in the Makefile `test-repl` target
- Pattern: `printf 'forth code\r\nBYE\r\n' | $(IZCPM) $(TARGET)` then grep output
- Each test has PASS/FAIL messages and `exit 1` on failure
- Tests exercise actual Forth primitives through the full interpreter pipeline

### Project Structure Notes

- All source in `src/` directory, included by `src/antforth.asm` manifest
- Dictionary entry ordering matters — words in same file are linked via hash buckets at assembly time
- New words need `w_XXX` label, `w_XXX_cf` label (for threading references), DEFCODE/DEFWORD/DEFIMMED macro
- No separate header files needed — macros.asm handles dictionary construction

### References

- [Source: docs/ans-forth-core-compliance.md] — Full compliance audit with word list, stack effects, and gap analysis
- [Source: src/inner_interpreter.asm:23] — EXIT_CODE implementation
- [Source: src/strings.asm:655] — `."` compile-time pattern (model for ABORT")
- [Source: src/compiler.asm:496] — LITERAL pattern (model for ['] and [CHAR])
- [Source: src/compiler.asm:209] — POSTPONE FIND pattern (model for ')
- [Source: src/macros.asm:58-135] — DEFCODE/DEFWORD/DEFIMMED macro definitions
- [Source: src/bootstrap.asm] — DEFWORD examples (ABS, NEGATE, MIN, MAX, VARIABLE)

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
