# Story 2.4: Error Handling & Recovery

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want clear error messages and graceful recovery,
So that mistakes don't crash the system and I can continue working.

## Acceptance Criteria

1. **Given** the user types an undefined word (e.g., `FOO`) **When** INTERPRET fails to find it and it's not a valid number **Then** `FOO ?` is printed and ABORT is called **And** ABORT resets SP, falls through to QUIT, which resets IX + STATE, and displays `ok`

2. **Given** the user executes a word that causes stack underflow (e.g., `+` with empty stack) **When** the underflow is detected **Then** `? Stack underflow` is printed and ABORT is called **And** the system returns to the `ok` prompt ready for input

3. **Given** an error occurs during any operation **When** ABORT executes **Then** only SP is reset (not a full cold start -- hash table, HERE, dictionary remain intact) **And** any values on the stack are lost (expected ABORT behaviour)

4. **Given** the user types a line with mixed valid and invalid tokens (e.g., `2 3 + BADWORD`) **When** the invalid token is reached **Then** the error is reported for that specific token **And** earlier operations on that line have already executed (standard Forth -- no line-level transaction)

5. **Given** repeated errors **When** the user makes multiple consecutive mistakes **Then** the system recovers cleanly each time without memory leaks, dictionary corruption, or stack residue

## Tasks / Subtasks

- [x] Task 1: Add stack underflow check infrastructure (AC: #2)
  - [x] 1.1 Add error message strings to data area in `src/antforth.asm`: `str_underflow: DB "? Stack underflow"` + length constant
  - [x] 1.2 Implement `check_underflow` subroutine in `src/system.asm` that compares SP against sp_base and triggers error if SP >= sp_base (underflow)
  - [x] 1.3 Implement `do_underflow_error` subroutine in `src/system.asm` that prints the underflow message and calls ABORT

- [x] Task 2: Add stack underflow checks to critical words (AC: #2, #5)
  - [x] 2.1 Add underflow check to arithmetic words that consume stack items: `+`, `-`, `*`, `/`, `MOD`, `/MOD` in `src/arithmetic.asm`
  - [x] 2.2 Add underflow check to binary stack ops: `SWAP`, `OVER`, `ROT`, `DROP` in `src/stack_ops.asm`
  - [x] 2.3 Add underflow check to memory words: `!`, `+!` in `src/memory.asm` (@ only reads BC, no POP needed)
  - [x] 2.4 Add underflow check to comparison words: `=`, `<`, `>`, `U<` plus `AND`, `OR`, `XOR`, `LSHIFT`, `RSHIFT` in `src/logic.asm`
  - [x] 2.5 Add underflow check to output words: `.`, `U.`, `.R` in `src/formatting.asm`

- [x] Task 3: Verify existing undefined word handling (AC: #1, #4)
  - [x] 3.1 Verify INTERPRET's `.not_number` path outputs `WORD ?` + CR + calls ABORT (confirmed via REPL tests 3, 9, 11)
  - [x] 3.2 Verify ABORT resets SP only (not full cold start) -- confirmed, dictionary/hash/HERE intact after ABORT
  - [x] 3.3 Verify QUIT resets IX, sets STATE=0, enters REPL loop -- confirmed via recovery to `ok` prompt

- [x] Task 4: Add regression tests for error handling (AC: #1-5)
  - [x] 4.1 Underflow testing done via REPL tests (test_thread ABORT hijacks flow — per Dev Notes, REPL tests are recommended approach)
  - [x] 4.2 Verify all existing regression tests still pass under `make test` — PASS
  - [x] 4.3 Verify all existing REPL tests still pass under `make test-repl` — PASS (all 8 original tests pass)

- [x] Task 5: Add REPL tests for error scenarios (AC: #1-5)
  - [x] 5.1 REPL test 9: `FOO` -> verify `FOO ?` appears in output, then system shows `ok` (undefined word recovery)
  - [x] 5.2 REPL test 10: `+` on empty-ish stack -> verify `? Stack underflow` appears, then `ok` prompt
  - [x] 5.3 REPL test 11: `2 3 + BADWORD` -> verify partial execution happened and error reported for BADWORD
  - [x] 5.4 REPL test 12: Multiple consecutive errors recover cleanly (`FOO`, `BAR`, then `42 .` -> verify `42 ` appears after errors)

## Dev Notes

### What Already Exists (from Epic 1 + Stories 2.1-2.3)

**Must not be modified** unless adding underflow checks or fixing a bug:

- **ABORT** (`system.asm:20-25`): Resets SP to sp_base, jumps to QUIT. Already correct per AC#3.
- **QUIT** (`outer_interpreter.asm:197-224`): Resets IX, sets STATE=0, loops QUERY/INTERPRET/ok. Already correct.
- **INTERPRET** (`outer_interpreter.asm:148-190`): Parses tokens, tries FIND then NUMBER?, on failure prints `word ?` + CR + calls ABORT. Already correct per AC#1.
- **BYE** (`system.asm:8-13`): Exit to CP/M. Do not touch.
- **Inner interpreter** (`inner_interpreter.asm`): DOCOL, EXIT_CODE, LIT, BRANCH, ?BRANCH, EXECUTE
- **I/O words** (`io.asm`): EMIT, TYPE, CR, SPACE, SPACES, KEY, KEY?, ACCEPT
- **Stack words** (`stack_ops.asm`): DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH, SP@, SP!, RP@, RP!
- **Arithmetic** (`arithmetic.asm`): +, -, *, /, MOD, /MOD
- **Memory** (`memory.asm`): @, !, +!, C@, C!
- **Logic** (`logic.asm`): AND, OR, XOR, =, <, >, 0=, 0<, U<
- **Formatting** (`formatting.asm`): `.`, `U.`, `.R`, `.S`, HEX, DECIMAL
- **56+ CODE primitives** from all previous stories

### What Needs to Be Built

The main new work is **stack underflow detection**. AC#1 (undefined word errors) and AC#3 (ABORT behaviour) are already implemented and passing in REPL test 3.

**New components:**
1. `check_underflow` -- assembly subroutine (NOT a Forth word)
2. `do_error_msg` -- assembly subroutine (NOT a Forth word) 
3. Error message string(s) in data area
4. Underflow check calls injected into existing CODE words

### Register Contract (Inviolable)

| Register | Role | Rules |
|----------|------|-------|
| BC | TOS | Contains TOS on entry; must contain new TOS on exit |
| DE | IP | Must be preserved -- save to return stack (IX) if used as scratch |
| SP | Parameter stack | Net effect must match stack signature |
| IX | Return stack | Preserve unless doing return stack ops |
| IY | User pointer | Preserve unless accessing user variables |
| HL, AF | Scratch | Free within CODE words |

### Stack Underflow Detection Design

**Strategy: Use DEPTH = (sp_base - SP) / 2 to determine stack validity, then check before consuming.**

**TOS-in-register semantics (critical context):**

AntForth keeps TOS in BC. After cold start or ABORT, BC holds a phantom/garbage value (0 from cold start). DEPTH = (sp_base - SP) / 2 counts only cells on the machine stack (SP), NOT BC.

- **DEPTH = 0:** SP == sp_base. BC is phantom/leftover — not a valid user item. Any word that POPs from SP would read below sp_base (real underflow).
- **DEPTH >= 1:** User has pushed at least one real value. BC holds the real TOS. The machine stack holds previous items (including the phantom 0 that was pushed when the first LIT/push executed).

**What "underflow" means in this architecture:**

Any word that does `POP` from SP (to consume an item or load a new TOS) needs at least 1 cell on the machine stack, i.e., DEPTH >= 1 (sp_base - SP >= 2). When DEPTH = 0, a POP reads below sp_base — this is the actual underflow.

| Word needs N items total | BC provides 1 | POPs from SP | Check needed |
|--------------------------|---------------|--------------|--------------|
| N = 1 (`.`, `DROP`) | BC = the item | POP for new TOS | DEPTH >= 1 |
| N = 2 (`+`, `SWAP`, `!`) | BC = one operand | POP 1 operand | DEPTH >= 1 |
| N = 3 (`ROT`) | BC = one | POP 2 | DEPTH >= 2 |

Note: For N = 1 words like `.` and `DROP`, the check ensures there's a valid cell to POP as the new TOS after consuming BC. Without this check, after ABORT the user could type `.` and the final `POP BC` would read garbage below sp_base.

**`check_underflow` subroutine (checks DEPTH >= 1):**

```z80
; check_underflow: Verify DEPTH >= 1 (at least 1 cell on machine stack)
; This means sp_base - SP >= 2 (one cell = 2 bytes)
;
; Call convention: CALL at START of CODE words that POP from SP
; The CALL itself pushes 2 bytes (return address) onto SP, so at the
; point of comparison, SP is 2 less than the "real" SP.
; Therefore: sp_base - SP_measured = (sp_base - SP_real) + 2
; We need sp_base - SP_real >= 2, so sp_base - SP_measured >= 4
;
; On underflow: prints "? Stack underflow", calls ABORT (never returns)
; On success: returns normally
; Clobbers: AF, HL (both are scratch per register contract)
; Preserves: BC (TOS), DE (IP), IX, IY, SP
check_underflow:
        LD      HL, (sp_base)
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP_measured
        ; HL < 4 means underflow (0 or 2 real bytes = DEPTH 0)
        ; HL >= 4 means OK (at least 2 real bytes = DEPTH >= 1)
        JR      C, .underflow   ; sp_base < SP = corrupt, definitely underflow
        LD      A, H
        OR      A
        RET     NZ              ; HL >= 256, plenty of stack — fast exit
        LD      A, L
        CP      4               ; Need >= 4 (2 for CALL ret addr + 2 for one cell)
        RET     NC              ; HL >= 4, OK — fast exit
.underflow:
        JP      do_underflow_error
```

**Why threshold is 4, not 2:** The `CALL check_underflow` instruction pushes a 2-byte return address onto SP before the body executes. So SP_measured = SP_real - 2. If the real stack had DEPTH = 0 (SP_real == sp_base), then sp_base - SP_measured = 2. If DEPTH = 1 (one real cell), sp_base - SP_measured = 4. So >= 4 means DEPTH >= 1.

**`do_underflow_error`** (in `system.asm`):
```z80
do_underflow_error:
        ; Print "? Stack underflow" and ABORT
        ; At this point SP is corrupt, so just use BDOS directly
        ; DE (IP) may be valid but doesn't matter — we're aborting
        LD      HL, str_underflow
        LD      B, STR_UNDERFLOW_LEN
.print_loop:
        LD      E, (HL)
        PUSH    HL
        PUSH    BC
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC
        POP     HL
        INC     HL
        DJNZ    .print_loop
        ; Newline
        LD      E, 0x0D
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        LD      E, 0x0A
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        ; ABORT resets SP and enters QUIT
        JP      w_ABORT_cf
```

### Where to Add Underflow Checks

**Principle:** Only check words that POP from the parameter stack (consume items beyond TOS in BC). Words that only read BC or push to the stack need no check.

**Words needing DEPTH >= 1** (1 POP from SP — CALL check_underflow once):
- `+`, `-`, `AND`, `OR`, `XOR` — binary ops (BC = x2, POP x1 from SP)
- `SWAP`, `OVER` — binary stack ops (POP x1)
- `=`, `<`, `>`, `U<` — comparisons (POP x1)
- `!`, `+!` — memory store (POP address)
- `*`, `/`, `MOD`, `/MOD` — arithmetic (POP x1)
- `.R` — formatting (BC = width, POP n)
- `.`, `U.` — consume BC as the value, then POP new TOS. The POP at the end reads below sp_base if DEPTH = 0. Check protects this.
- `DROP` — POP new TOS from SP. Without check, reads below sp_base on empty stack.

**Words needing DEPTH >= 2** (2 POPs from SP):
- `ROT` — needs BC + 2 from SP. Pragmatic approach: call check_underflow once (catches DEPTH = 0 case). Won't catch DEPTH = 1 (one item short of three), but that's an edge case. A `check_underflow_2` variant could be added if needed, using threshold 6 instead of 4.

**Words needing NO check** (only PUSH to SP or only read BC):
- `DUP` — PUSH BC, no POP. Pushes phantom BC if DEPTH = 0, but that's harmless.
- `LIT`, `BRANCH`, `?BRANCH` — inner interpreter words, don't consume parameter stack.
- `EMIT`, `KEY`, `CR`, `SPACE` — I/O, no parameter stack POP (EMIT uses BC then POPs, so it actually DOES need a check — see below).

**Re-evaluation of EMIT:** `EMIT ( c -- )` consumes BC then does `POP BC` for new TOS. Same pattern as `.` — needs DEPTH >= 1. However, EMIT is used internally by error printing and the QUIT loop. Adding a check here could interfere with error recovery. **Decision: Do NOT check EMIT** — it's a low-level primitive used in the error path itself. If the user calls EMIT on an empty stack, the garbage TOS gets emitted and the new TOS is garbage. Not ideal but not a crash.

**Summary:** Add `CALL check_underflow` as the **first instruction** in CODE words that POP from SP to consume operands. This uses DEPTH >= 1 (sp_base - SP >= 2 real bytes) as the threshold, catching the most common underflow case: operating on an empty or near-empty stack after ABORT.

### Where to Place check_underflow

Add it to `src/system.asm` after the ABORT definition. It's an internal subroutine, not a Forth word — no dictionary entry needed.

### Error Message Strings

Add to the data area in `src/antforth.asm` near `str_ok`:

```z80
str_underflow:  DB      "? Stack underflow"
STR_UNDERFLOW_LEN EQU   17
```

### How to Inject Checks into Existing CODE Words

Example for `+` in `arithmetic.asm`:

```z80
; Before:
w_PLUS:
        DEFCODE "+", 0
w_PLUS_cf:
        POP     HL
        ADD     HL, BC
        LD      B, H
        LD      C, L
        NEXT

; After:
w_PLUS:
        DEFCODE "+", 0
w_PLUS_cf:
        CALL    check_underflow   ; Verify stack has items to pop
        POP     HL
        ADD     HL, BC
        LD      B, H
        LD      C, L
        NEXT
```

This is a 3-byte, ~17-cycle overhead per checked word on the fast path. Acceptable for an interactive Forth.

### Anti-Patterns to Avoid

1. **Do NOT add underflow checks to EVERY word.** Only words that POP from SP need protection. DUP, DROP, LIT, BRANCH, ?BRANCH, EMIT, etc. don't need it.
2. **Do NOT use BDOS_SAVE/BDOS_RESTORE** in the error path. The error path leads to ABORT which resets SP — the standard save/restore pattern won't work with a corrupt stack.
3. **Do NOT modify ABORT or QUIT** unless there's a bug. They already work correctly.
4. **Do NOT modify INTERPRET's error path.** The `word ?` + ABORT pattern already works per REPL test 3.
5. **Do NOT add full depth checking** (comparing DEPTH against each word's exact stack requirement). It's too expensive and non-standard for a small Forth. A simple SP vs sp_base check catches the common case.
6. **Do NOT break the DEFWORD cf EQU pattern** — no new DEFWORD words in this story, but if adding any, use `w_XXX_cf EQU w_XXX_body - 3`.
7. **Do NOT break existing tests.** All 58+ regression tests and 8 REPL tests must still pass.
8. **Do NOT change the `str_ok` string or its position** — other code depends on it.
9. **Do NOT use IX or IY as scratch** in check_underflow. The subroutine must preserve all registers except AF and HL on the success path.
10. **Do NOT add underflow checks inside INTERPRET or the QUIT loop.** These are DEFWORD (threaded code) — the checks go in the individual CODE word implementations.

### Previous Story Learnings (from Stories 2.1-2.3)

- **DEFWORD cf label bug:** `w_XXX_cf:` after DEFWORD points to body, not code field. Fixed with `EQU body - 3`. No new DEFWORDs expected in this story.
- **BDOS calling convention:** For complex register needs, save DE (IP) to return stack manually — don't use BDOS_SAVE/BDOS_RESTORE. The error print path needs direct BDOS calls since the stack may be corrupt.
- **Test thread pattern:** Emit known character on success, '!' on failure. Each test is a block of DW instructions in test_thread. Update EXPECTED in Makefile.
- **iz-cpm pipe behavior:** iz-cpm crashes with UnexpectedEof when stdin is a pipe — use `2>/dev/null || true` in Makefile test targets.
- **Phantom 0 on REPL stack:** Story 2.3 noted that QUIT's first INTERPRET loop pushes initial TOS (0) onto the stack. This means the REPL stack isn't truly empty at the start. `check_underflow` must account for this — the phantom 0 means SP is 2 bytes below sp_base, so the first `+` on a "user-empty" REPL stack won't trigger underflow (it'll add 0 to TOS). This is acceptable Forth behaviour.
- **REPL test 3 already tests undefined word recovery:** `XYZZY` -> `XYZZY ?` in output. This confirms AC#1 works.

### Git Intelligence

Recent commits show one-commit-per-story pattern:
```
8b6b87e commit stories 2.2 and 2.3 (whoops)
0054157 completed story 2.1
b57363d completed story 1.5 plus retro
```

Codebase is stable — all tests pass. Story 2.3 added number formatting. The REPL is fully functional with error recovery for undefined words. This story adds stack underflow detection as the remaining error handling requirement.

### Testing Strategy

**All words must be tested through the threading model** — no standalone assembly bypassing NEXT/DOCOL. See memory feedback rule.

**Three test tracks:**

1. **Regression (`make test`):** The underflow check is hard to test in test_thread because triggering it calls ABORT which hijacks the test flow. Options:
   - Test the success path: verify that `+` with valid operands still works (already covered by existing tests)
   - If a dedicated underflow test is added, it must be isolated (e.g., at the end of test_thread, after all other tests, since ABORT will terminate the test sequence)
   - **Recommended:** Keep regression tests focused on success paths. Test underflow via REPL tests.

2. **REPL integration (`make test-repl`):** Add piped REPL tests:
   - Undefined word: already tested (REPL test 3: `XYZZY` -> `XYZZY ?`)
   - Stack underflow: `+` on near-empty stack -> verify `? Stack underflow` appears
   - Recovery after error: error -> `42 .` -> verify `42 ` appears (system recovered)
   - Partial line execution: `2 3 + BADWORD` -> verify `BADWORD ?` appears
   - Multiple consecutive errors: two bad words, then valid computation

3. **Empirical verification:** After building, test under iz-cpm:
   - Type several undefined words in a row, verify recovery each time
   - Type `+` on empty stack, verify underflow message
   - Verify REPL works normally after all errors

### File Structure

| File | Changes | Notes |
|------|---------|-------|
| `src/system.asm` | Add `check_underflow` subroutine, `do_underflow_error` | Error infrastructure |
| `src/arithmetic.asm` | Add `CALL check_underflow` to `+`, `-`, `*`, `/`, `MOD`, `/MOD` | Binary arithmetic protection |
| `src/stack_ops.asm` | Add `CALL check_underflow` to `SWAP`, `OVER`, `ROT`, `DROP` | Stack op protection |
| `src/memory.asm` | Add `CALL check_underflow` to `!`, `+!` | Memory store protection |
| `src/logic.asm` | Add `CALL check_underflow` to `=`, `<`, `>`, `U<` | Comparison protection |
| `src/formatting.asm` | Add `CALL check_underflow` to `.`, `U.`, `.R` | Formatting protection (all POP new TOS) |
| `src/antforth.asm` | Add `str_underflow` string + length constant to data area | Error message string |
| `Makefile` | Add REPL tests for underflow and multi-error recovery | Test infrastructure |

**Include order unchanged** — `system.asm` is already included in antforth.asm. Verify that `check_underflow` in system.asm is accessible from arithmetic.asm etc. at assembly time. Since sjasmplus resolves labels across files (all included into one assembly unit), forward/backward references work fine.

### Project Structure Notes

- No new files needed — all changes are additions to existing files
- `check_underflow` and `do_underflow_error` are internal subroutines in `system.asm`, not Forth words
- Error message strings go in the data area at the end of `antforth.asm`, near `str_ok`
- No changes to include order or project structure

### Implementation Order Recommendation

Build and test incrementally:

1. **Error message strings** (Task 1.1) — add string to data area
2. **check_underflow + do_underflow_error** (Task 1.2-1.3) — error infrastructure in system.asm
3. **Add check to `+` only** (Task 2.1 partial) — test with REPL before proceeding
4. **Add checks to remaining words** (Task 2.1-2.5) — batch the rest
5. **Verify existing tests pass** (Task 4.2-4.3) — regression safety
6. **Add REPL error tests** (Task 5.1-5.4) — new test coverage
7. **Final verification** (Task 3) — confirm all ACs met

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.4] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/prd.md#Error Handling] — FR45, FR46, FR48
- [Source: _bmad-output/planning-artifacts/architecture.md#Error Handling & Abort Protocol] — ABORT/QUIT two-level model
- [Source: _bmad-output/planning-artifacts/architecture.md#Register Usage Discipline] — register contract
- [Source: _bmad-output/planning-artifacts/architecture.md#Error Message Format] — `? description` format
- [Source: src/system.asm:20-25] — current ABORT implementation
- [Source: src/outer_interpreter.asm:197-224] — current QUIT implementation
- [Source: src/outer_interpreter.asm:178-187] — INTERPRET's undefined word error path
- [Source: src/stack_ops.asm:165-179] — DEPTH implementation (sp_base reference pattern)
- [Source: src/constants.asm] — system constants, sp_base usage
- [Source: src/arithmetic.asm] — words needing underflow checks
- [Source: src/logic.asm] — comparison words needing underflow checks
- [Source: src/memory.asm] — memory words needing underflow checks
- [Source: Makefile:52-131] — test infrastructure, EXPECTED string, test-repl target
- [Source: _bmad-output/implementation-artifacts/2-3-number-formatting-and-stack-inspection.md] — previous story learnings

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None — clean implementation, no debugging needed.

### Completion Notes List

- Implemented `check_underflow` subroutine in system.asm: compares SP against sp_base accounting for CALL return address (+2 bytes), threshold >= 4 means DEPTH >= 1
- Implemented `do_underflow_error` in system.asm: prints "? Stack underflow" via direct BDOS calls (safe with corrupt SP), then jumps to ABORT
- Added `str_underflow` string + `STR_UNDERFLOW_LEN` constant to data area in antforth.asm
- Added `CALL check_underflow` as first instruction in 25 CODE words across 5 files: arithmetic (6), stack_ops (4), memory (3), logic (9), formatting (3)
- Did NOT add check to `@` (only reads BC, no POP from SP) or `EMIT` (used in error path itself)
- Added checks to `AND`, `OR`, `XOR`, `LSHIFT`, `RSHIFT` in logic.asm (all POP from SP)
- All 5 ACs satisfied: undefined word error (AC#1 already worked), stack underflow detection (AC#2 new), ABORT SP-only reset (AC#3 already worked), partial line execution (AC#4 already worked), repeated error recovery (AC#5 verified)
- Added 7 new REPL tests (tests 9-15) covering all error scenarios across word categories
- All tests pass: regression tests (PASS), 15 REPL tests (all PASS)

### Change Log

- 2026-04-06: Story 2.4 implementation complete — stack underflow detection and error recovery
- 2026-04-06: Code review fixes — added missing C! underflow check, added ROT limitation comment, added REPL tests 13-15 for cross-category underflow coverage, fixed completion notes count (22→25)

### File List

- `src/system.asm` — Added `check_underflow` and `do_underflow_error` subroutines after ABORT
- `src/antforth.asm` — Added `str_underflow` string and `STR_UNDERFLOW_LEN` constant in data area
- `src/arithmetic.asm` — Added `CALL check_underflow` to `+`, `-`, `*`, `/`, `MOD`, `/MOD`
- `src/stack_ops.asm` — Added `CALL check_underflow` to `DROP`, `SWAP`, `OVER`, `ROT`
- `src/memory.asm` — Added `CALL check_underflow` to `!`, `+!`, `C!`
- `src/logic.asm` — Added `CALL check_underflow` to `AND`, `OR`, `XOR`, `LSHIFT`, `RSHIFT`, `=`, `<`, `>`, `U<`
- `src/formatting.asm` — Added `CALL check_underflow` to `.`, `U.`, `.R`
- `Makefile` — Added REPL tests 9-15 for error handling scenarios (including cross-category underflow tests)
