# Story 5.1: Comment Words

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want comment words available during interactive sessions,
so that I can annotate my code inline and write readable definitions.

## Acceptance Criteria

1. **Given** the user types `( this is a comment )` at the Forth prompt or inside a definition
   **When** `(` executes
   **Then** all text up to and including the next `)` is consumed and ignored
   **And** the closing `)` is required (missing `)` raises an error)
   **And** `(` is an IMMEDIATE word (works in both interpret and compile mode)

2. **Given** the user types `\ this is a line comment` at the Forth prompt or inside a definition
   **When** `\` executes
   **Then** all text from `\` to the end of the current input line is consumed and ignored
   **And** `\` is an IMMEDIATE word (works in both interpret and compile mode)

3. **Given** comment words are used inside colon definitions
   **When** the definition is compiled and executed
   **Then** the comments have no effect on the compiled code — they are purely parse-time

4. **Given** comment words are used inside CODE definitions
   **When** the assembler is active
   **Then** comments work identically (they consume input text, not assembled bytes)

## Tasks / Subtasks

- [x] Task 1: Implement `\` (backslash line comment) (AC: #2, #3, #4)
  - [x] 1.1 Add DEFCODE `\` with F_IMMEDIATE in `strings.asm`
  - [x] 1.2 Implementation: set >IN = #TIB, NEXT

- [x] Task 2: Implement `(` (paren comment) (AC: #1, #3, #4)
  - [x] 2.1 Add DEFCODE `(` with F_IMMEDIATE in `strings.asm`
  - [x] 2.2 Save BC (TOS) to parameter stack and DE (IP) to return stack (parsing clobbers both)
  - [x] 2.3 Scan TIB from >IN for `)`, advancing >IN for each character consumed
  - [x] 2.4 On `)` found: restore DE and BC, NEXT
  - [x] 2.5 On end-of-input without `)`: print error message, JP w_ABORT_cf
  - [x] 2.6 Add error string `str_missing_paren` ("? missing )") in strings.asm

- [x] Task 3: Add REPL tests for `\` (AC: #2, #3)
  - [x] 3.1 Test 215: `\ this is ignored` followed by `42 .` — outputs 42
  - [x] 3.2 Test 216: `\ ` at end of line (nothing after backslash) — no error
  - [x] 3.3 Test 217: `: COMMENTED \ this is ignored` (newline) `3 + ; 10 COMMENTED .` — outputs 13 (note: removed spurious `5` from spec to match expected output)
  - [x] 3.4 Test 218: `\ ` inside a CODE word body — assembly continues on next line

- [x] Task 4: Add REPL tests for `(` (AC: #1, #3, #4)
  - [x] 4.1 Test 219: `( hello world ) 42 .` — outputs 42
  - [x] 4.2 Test 220: `( nested parens are not special ) 55 .` — literal `)` ends comment
  - [x] 4.3 Test 221: `: COMMENTED2 5 ( add three ) 3 + ; 10 COMMENTED2 .` — outputs 8
  - [x] 4.4 Test 222: `( missing paren` — error message "? missing )" and recovery
  - [x] 4.5 Test 223: `( ) 99 .` — empty comment, outputs 99
  - [x] 4.6 Test 224: `( comment inside CODE )` — paren comment inside CODE body, no interference
  - [x] 4.7 Test 225: `5 ( comment ) .` — outputs 5 (TOS preserved across paren comment)

- [x] Task 5: Verify no regressions (AC: #3, #4)
  - [x] 5.1 `make test` — all 73 regression tests pass
  - [x] 5.2 `make test-repl` — all 225 tests pass (214 existing + 11 new)

## Dev Notes

### Implementation Design

#### `\` (Backslash) — Line Comment

Trivially simple. `\` is an IMMEDIATE DEFCODE word that sets >IN equal to #TIB, consuming the remainder of the input line. No scanning needed.

```z80
w_BACKSLASH:
        DEFCODE "\", F_IMMEDIATE
w_BACKSLASH_cf:
        ; Set >IN = #TIB (consume rest of line)
        LD      A, (IY+UserArea.tib_len)
        LD      (IY+UserArea.tib_in), A
        LD      A, (IY+UserArea.tib_len+1)
        LD      (IY+UserArea.tib_in+1), A
        NEXT
```

5 instructions. Does not clobber DE (IP) or BC (TOS) — no save/restore needed.

#### `(` (Paren) — Delimited Comment

IMMEDIATE DEFCODE word. Scans TIB from current >IN position looking for `)`. Advances >IN for each character consumed (including the closing `)`). If end-of-input is reached without finding `)`, prints an error and ABORTs.

**Key register usage:**
- DE (IP) must be saved/restored — parsing code uses DE as scratch
- BC (TOS) is untouched — `(` has no stack effect
- HL = current scan position in TIB
- BC (repurposed after save) = remaining character count

**Save DE to return stack** (same pattern as WORD in strings.asm):
```z80
DEC     IX
DEC     IX
LD      (IX+0), E
LD      (IX+1), D
```

**Scan loop pattern** (follows WORD's >IN advancement pattern from strings.asm:46-68):
1. Compute HL = tib_addr + >IN, BC = tib_len - >IN
2. Loop: if BC=0, error (missing paren). Load (HL), advance >IN, INC HL, DEC BC. If char = `)`, done.
3. Restore DE from return stack, NEXT.

**Error path** follows `?COMP` pattern (control_flow.asm:17-29): inline print loop via direct BDOS C_WRITE calls, then JP w_ABORT_cf. This is safe because on the abort path registers don't matter.

**Error string:** `"missing )"` with ` ?` CR LF suffix. Two options:
- Option A: Reuse `asm_print_error` (prints HL/B then " ?" CR LF). Requires the assembler include to precede this code. Since `strings.asm` is INCLUDEd before `assembler.asm`, this won't work.
- Option B: Self-contained print loop like `?COMP`. Define `str_missing_paren: DB "missing )", 0x0D, 0x0A` with length constant. **Use this option.**

### Where to Add the Code

**File: `src/strings.asm`** — after the WORD implementation (around line 140). This is the natural home: strings.asm already contains WORD (the primary parsing word), S", and .".

Add both `\` and `(` consecutively, with `\` first (simpler, no dependencies).

### ANS Forth Compliance Notes

- `(` is ANS Forth CORE word 6.1.0080. The standard says "Parse ccc delimited by )" — if `)` is absent, standard behavior is to consume to end of input without error. **This implementation is stricter**: missing `)` raises an error per AC#1. This is intentional for a single-line REPL where a missing `)` is almost certainly a typo.
- `\` is ANS Forth CORE EXT word 6.2.2535. Standard says "parse and discard the remainder of the parse area". Implementation matches exactly.
- Both words must have `( ` (paren-space) as the standard delimiter after the word name when invoked. The INTERPRET loop already handles this — BL WORD skips leading spaces, finds `(` or `\`, then FIND+EXECUTE runs the word. At that point >IN is positioned just past the word name.

### Register Contract

Neither word has a stack effect. Both must preserve:
- BC (TOS) — no stack changes
- DE (IP) — `\` doesn't touch it; `(` saves/restores via return stack
- SP (parameter stack) — untouched
- IX (return stack) — `(` uses 2 bytes temporarily, fully restored
- IY (user area pointer) — read-only access

### REPL Test Numbering

Tests continue from **215** onwards (last existing test is 214).

### Testing Strategy

**Primary: REPL-piped tests** (per project convention).

Key test scenarios:
1. `\` consumes to end of line — verify code after `\` on same line is ignored
2. `\` inside colon definition — verify compilation continues on next line
3. `(` consumes to `)` — verify code after `)` executes normally
4. `(` with missing `)` — verify error message and ABORT recovery
5. Empty `( )` — edge case, should work fine
6. Comments inside colon definitions — verify no impact on compiled code

**Note on `\` inside colon definitions:** Testing `\` inside a colon definition requires a multi-line input (the comment consumes the rest of line 1, and `;` must be on line 2). The REPL test harness supports multi-line input via `\r\n` separators in printf.

### Anti-Patterns to Avoid

1. **Do NOT modify `outer_interpreter.asm`** — comment words are self-contained IMMEDIATE words, no changes to the interpret loop needed
2. **Do NOT use WORD internally** — `(` doesn't need to copy text to HERE, just advance >IN. A simple scan is more efficient and avoids cluttering the HERE buffer.
3. **Do NOT add tests to the regression test thread** — REPL-piped tests only
4. **Do NOT forget DE preservation in `(`** — DE is the instruction pointer; clobbering it without save/restore will crash the threading model
5. **Do NOT use `asm_print_error`** — it's defined in assembler.asm which is INCLUDEd after strings.asm. Use self-contained BDOS print loop.

### Previous Story Intelligence (from Story 5.0.5)

**Register-contract violations** remain the dominant bug class. Story 5.0.5 notes:
- Save DE to `asm_ip_save` or return stack before any code that clobbers DE
- `\` doesn't need this (doesn't touch DE), but `(` absolutely does

**REPL input line length limit** — tests with long input may need splitting across multiple lines.

**Interactive smoke testing** is recommended before relying on automated tests alone.

### Git Intelligence

Recent commits follow one-commit-per-story pattern:
```
1f07b30 completed story 5.0.5
33c7747 add re-audit report for z80 opcodes
```

### Project Structure Notes

- All new code goes in `src/strings.asm` — no new files needed
- Error string defined alongside the code in strings.asm (local to the parsing section)
- REPL tests appended to Makefile `test-repl` target starting at test 215
- No changes to antforth.asm include order or any other source file

### References

- [Source: src/strings.asm:10-140] — WORD implementation (parsing pattern to follow for `(`)
- [Source: src/strings.asm:538-647] — S" implementation (IMMEDIATE parse-time word pattern)
- [Source: src/control_flow.asm:8-33] — `?COMP` (error printing + ABORT pattern for `(`)
- [Source: src/outer_interpreter.asm:148-229] — INTERPRET loop (how IMMEDIATE words execute)
- [Source: src/structures.asm:23-26] — UserArea fields: tib_addr, tib_len, tib_in, source_id
- [Source: src/macros.asm:58-95] — DEFCODE macro (for defining new CODE words)
- [Source: src/constants.asm:33] — F_IMMEDIATE = 0x80
- [Source: src/system.asm:80-106] — do_underflow_error (direct BDOS error print pattern)
- [Memory: feedback_repl_tests_preferred.md] — REPL-piped tests only, no assembly test threads
- [Memory: feedback_standards_compliance.md] — Investigate the standard before defending code

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- sjasmplus DEFCODE macro requires single quotes for `\` name (backslash is escape in double-quoted strings)
- Story spec test 3.3 had incorrect expected output (13) — `: COMMENTED 5 \ ...` / `3 + ;` compiles as `5 3 +` (pushes 8), not `3 +` (adds 3 to TOS). Fixed test to omit spurious `5` so COMMENTED = `3 +` and `10 COMMENTED .` outputs 13 as intended.
- Story spec test 4.3 expected output (13) was also incorrect for same reason — `5 ( add three ) 3 +` compiles as `5 3 +` = 8. Test expects 8 (correct behavior).

### Completion Notes List

- `\` (backslash) implemented as 5-instruction IMMEDIATE DEFCODE word: copies tib_len to tib_in, consuming rest of parse area. Does not touch DE (IP) or BC (TOS).
- `(` (paren) implemented as IMMEDIATE DEFCODE word: saves BC (TOS) to parameter stack and DE (IP) to return stack, scans TIB from >IN for `)` advancing >IN each char, restores DE and BC on success, prints "? missing )" + ABORT on failure.
- Error printing uses self-contained BDOS C_WRITE loop (same pattern as ?COMP in control_flow.asm), avoiding dependency on asm_print_error which is defined later in include order. Error message follows project `? description` format.
- 11 REPL tests added (215-225) covering: line comment, empty backslash, backslash in colon def, backslash inside CODE body, paren comment, non-nested parens, paren in colon def, missing paren error, empty paren comment, paren inside CODE body, TOS preservation across paren comment.
- All 73 regression tests pass. All 225 tests pass (232 test lines including a/b sub-variants).

### File List

- `src/strings.asm` — Added `\` and `(` word implementations after `."` (lines 756-851)
- `Makefile` — Added REPL tests 215-225 in test-repl target

### Change Log

- 2026-04-12: Implemented comment words `\` and `(` with 9 REPL tests. All ACs satisfied.
- 2026-04-12: [Code Review] Fixed BC (TOS) register contract violation in `(` — added PUSH BC/POP BC. Fixed error message to "? missing )" format. Fixed test 218 to test `\` inside CODE body (not after END-CODE). Added tests 224 (paren in CODE) and 225 (TOS preservation). All 225 tests pass.
