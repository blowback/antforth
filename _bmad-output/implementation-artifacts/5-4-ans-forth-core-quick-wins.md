# Story 5.4: ANS Forth Core Quick Wins

Status: done

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
| `>BODY` | `( xt -- a-addr )` | 5x `INC BC` (skip 3-byte JP + 2-byte does-addr) | `src/compiler.asm` |

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

- [x] Task 1: Implement Tier 1 trivial DEFCODE words (AC: #1)
  - [x] 1.1 `1+` in `src/arithmetic.asm` — DEFCODE "1+", 0; INC BC; NEXT
  - [x] 1.2 `1-` in `src/arithmetic.asm` — DEFCODE "1-", 0; DEC BC; NEXT
  - [x] 1.3 `2*` in `src/arithmetic.asm` — DEFCODE "2*", 0; SLA C; RL B; NEXT
  - [x] 1.4 `2/` in `src/arithmetic.asm` — DEFCODE "2/", 0; SRA B; RR C; NEXT
  - [x] 1.5 `?DUP` in `src/stack_ops.asm` — DEFCODE "?DUP", 0; test BC zero; if non-zero PUSH BC; NEXT
  - [x] 1.6 `CELL+` in `src/memory.asm` — DEFCODE "CELL+", 0; INC BC; INC BC; NEXT
  - [x] 1.7 `CHAR+` in `src/memory.asm` — DEFCODE "CHAR+", 0; INC BC; NEXT (identical to 1+)
  - [x] 1.8 `CHARS` in `src/memory.asm` — DEFCODE "CHARS", 0; NEXT (no-op)
  - [x] 1.9 `>BODY` in `src/compiler.asm` — DEFCODE ">BODY", 0; INC BC x5; NEXT (xt+5 = skip JP + does-addr)

- [x] Task 2: Implement Tier 2 simple DEFCODE words (AC: #1)
  - [x] 2.1 `EXIT` in `src/inner_interpreter.asm` — DEFCODE "EXIT", 0; JP EXIT_CODE
  - [x] 2.2 `CHAR` in `src/strings.asm` — DEFCODE "CHAR", 0; inline parsing of next space-delimited token, return first char
  - [x] 2.3 `'` (tick) in `src/compiler.asm` — DEFWORD "'", 0; BL WORD FIND, error if not found, DROP flag keeping xt
- [x] Task 3: Implement Tier 3 compile-time DEFIMMED words (AC: #1)
  - [x] 3.1 `[']` in `src/compiler.asm` — DEFIMMED "[']"; threads: TICK, LITERAL, EXIT_CODE
  - [x] 3.2 `[CHAR]` in `src/compiler.asm` — DEFIMMED "[CHAR]"; threads: CHAR, LITERAL, EXIT_CODE

- [x] Task 4: Implement ABORT" (AC: #1)
  - [x] 4.1 Create runtime helper `(ABORT")` in `src/system.asm` — DEFCODE; pops flag, if zero skip inline string, if non-zero print via BDOS then JP ABORT
  - [x] 4.2 Create `ABORT"` in `src/system.asm` — DEFCODE with F_IMMEDIATE; compiles (ABORT") xt + inline counted string (same pattern as `."` in strings.asm)

- [x] Task 5: Add REPL-piped tests for all 15 words (AC: #2)
  - [x] 5.1 Tests for `1+`, `1-`: tests 238-241 (including edge cases -1, 0)
  - [x] 5.2 Tests for `2*`, `2/`: tests 242-244 (including arithmetic shift -6 2/ = -3)
  - [x] 5.3 Tests for `?DUP`: tests 245-246 (non-zero and zero cases)
  - [x] 5.4 Tests for `CELL+`, `CHAR+`, `CHARS`: tests 247-249
  - [x] 5.5 Test for `EXIT`: test 250 (1 EXIT 2 in colon def returns 1)
  - [x] 5.6 Test for `CHAR`: tests 251-252 (CHAR A = 65, CHAR Z = 90)
  - [x] 5.7 Test for `'` (tick): test 256 (7 ' DUP EXECUTE . outputs 7)
  - [x] 5.8 Test for `>BODY`: test 255 (' FOO >BODY @ . outputs 42; corrected to use tick since FOO pushes body not xt)
  - [x] 5.9 Test for `[']`: test 253 (compiles xt of DUP, EXECUTE duplicates 7)
  - [x] 5.10 Test for `[CHAR]`: test 254 (GET-A [CHAR] A ; GET-A . outputs 65)
  - [x] 5.11 Test for `ABORT"`: tests 257-258 (0 CHK no abort; 1 CHK aborts with "nonzero" and recovers)

- [x] Task 6: Run full regression suite (AC: #3)
  - [x] 6.1 `make test` — all 73 assembly thread tests pass
  - [x] 6.2 `make test-repl` — all 237 existing REPL tests pass
  - [x] 6.3 All 21 new REPL tests pass (tests 238-258)

- [x] Task 7: Update compliance report (AC: #4)
  - [x] 7.1 In `docs/ans-forth-core-compliance.md`, changed status of all 15 words from Missing/Partial to Implemented with correct source file and line numbers
  - [x] 7.2 Updated `EXIT` from "Partial" to "Implemented"
  - [x] 7.3 Updated summary table: 111 fully implemented, 1 partial, 21 missing, 83.5% compliance
  - [x] 7.4 Updated Gap Analysis: removed implemented words, simplified to 1 deliberate omission + 20 oversight (1 moderate + 19 subsystem)
  - [x] 7.5 Removed Quick Wins section (completed)
  - [x] 7.6 Moved `CHAR+` and `CHARS` from "Deliberately omitted" to "Implemented" in Character section

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

Claude Opus 4.6 (1M context)

### Debug Log References

- CHAR initially failed (stack underflow) — root cause: PUSH BC to save old TOS was incorrectly POP'd before setting new TOS; fix: keep the PUSH (needed for ( -- char ) stack effect), only set BC = result
- >BODY initially used xt+3 (per story spec) — root cause: CREATE layout includes 2-byte does-addr slot after JP DOVAR, so body = xt+5 not xt+3; fix: 5x INC BC
- >BODY test initially used `FOO >BODY` — root cause: executing FOO pushes body address (not xt); fix: use `' FOO >BODY` to get xt first
- ['] test had shell quoting issue with `'"'"'` in Makefile recipe — fix: switched to printf "%s" with double-quoted string

### Completion Notes List

- Implemented 15 ANS Core words across 7 source files
- Tier 1 (9 trivial DEFCODE): 1+, 1-, 2*, 2/, ?DUP, CELL+, CHAR+, CHARS, >BODY
- Tier 2 (3 simple DEFCODE/DEFWORD): EXIT (JP EXIT_CODE), CHAR (inline parsing), ' (DEFWORD threading BL WORD FIND)
- Tier 3 (2 DEFIMMED): ['] and [CHAR] both thread through LITERAL
- Tier 4 (1 moderate): ABORT" with runtime (ABORT") handler and compile-time string compilation
- Added 21 new REPL tests (tests 238-258) covering all words with edge cases
- Updated compliance report: 72.2% → 83.5% (96 → 111 fully implemented)
- Zero regressions: all 73 assembly tests and all 258 REPL tests pass

### Change Log

- 2026-04-13: Story 5.4 implemented — 15 ANS Core words added, compliance raised from 72.2% to 83.5%
- 2026-04-13: Code review — Fixed ABORT" tests (inverted 0= logic), corrected >BODY spec table (xt+5 not xt+3), documented BDOS convention deviation in (ABORT"), added sprint-status.yaml to File List

### File List

- `src/arithmetic.asm` — Added 1+, 1-, 2*, 2/ (4 DEFCODE words)
- `src/stack_ops.asm` — Added ?DUP (1 DEFCODE word)
- `src/memory.asm` — Added CELL+, CHAR+, CHARS (3 DEFCODE words)
- `src/inner_interpreter.asm` — Added EXIT (1 DEFCODE wrapping EXIT_CODE)
- `src/strings.asm` — Added CHAR (1 DEFCODE word)
- `src/compiler.asm` — Added >BODY, ' (tick), ['], [CHAR] (4 words: 1 DEFCODE, 1 DEFWORD, 2 DEFIMMED)
- `src/system.asm` — Added (ABORT") runtime helper, ABORT" compile-time word (2 words)
- `Makefile` — Added 21 REPL tests (tests 238-258)
- `docs/ans-forth-core-compliance.md` — Updated statuses, counts, gap analysis, observations
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — Updated story status
