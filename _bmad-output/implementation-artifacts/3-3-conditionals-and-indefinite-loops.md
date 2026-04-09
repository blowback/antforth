# Story 3.3: Conditionals & Indefinite Loops

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want conditional branching and indefinite loops in my definitions,
so that I can write logic that makes decisions and repeats.

## Acceptance Criteria

1. **Given** a definition using IF/THEN: `: TPOS DUP 0 > IF NEGATE THEN ;` **When** `5 TPOS .` is executed **Then** `-5` is printed **When** `-3 TPOS .` is executed **Then** `-3` is printed (the IF branch is skipped)

2. **Given** a definition using IF/ELSE/THEN: `: TSIGN 0< IF -1 ELSE 1 THEN ;` **When** `-5 TSIGN .` is executed **Then** `-1` is printed **When** `5 TSIGN .` is executed **Then** `1` is printed

3. **Given** a definition using BEGIN/UNTIL: `: TCNT 0 BEGIN 1 + DUP 5 = UNTIL ; TCNT .` **When** executed **Then** `5` is printed (loop runs until count equals 5)

4. **Given** a definition using BEGIN/WHILE/REPEAT: `: TSUM 0 5 BEGIN DUP 0 > WHILE SWAP OVER + SWAP 1 - REPEAT DROP ; TSUM .` **When** executed **Then** `15` is printed (sum of 5+4+3+2+1)

5. **Given** nested conditionals (IF inside IF) **When** executed **Then** each IF matches its correct THEN and branches resolve correctly

6. **Given** IF, ELSE, THEN, BEGIN, WHILE, REPEAT, UNTIL are all IMMEDIATE words **When** used outside of a colon definition (in interpret mode) **Then** a compile-only error is reported (e.g., `? compile only`)

## Tasks / Subtasks

- [x] Task 1: Implement `?COMP` compile-only guard in control_flow.asm (AC: #6)
  - [x] 1.1 CODE word that checks STATE; if STATE=0, prints "? compile only" + CR/LF and ABORTs
  - [x] 1.2 All subsequent DEFIMMED words start with `DW w_QCOMP_cf`

- [x] Task 2: Implement IF as DEFIMMED in control_flow.asm (AC: #1, #2)
  - [x] 2.1 Compile `w_QBRANCH_cf` at HERE via `,`
  - [x] 2.2 Push HERE (forward reference = address of offset cell)
  - [x] 2.3 Compile placeholder 0 at HERE via `,`

- [x] Task 3: Implement THEN as DEFIMMED in control_flow.asm (AC: #1, #2, #5)
  - [x] 3.1 Pop forward reference from stack
  - [x] 3.2 Calculate offset = HERE - fwd-ref
  - [x] 3.3 Store offset at fwd-ref via `!`

- [x] Task 4: Implement ELSE as DEFIMMED in control_flow.asm (AC: #2)
  - [x] 4.1 Compile `w_BRANCH_cf` at HERE (unconditional skip over ELSE clause)
  - [x] 4.2 Push HERE (new forward ref for THEN)
  - [x] 4.3 Compile placeholder 0
  - [x] 4.4 SWAP to bring IF's fwd-ref to top
  - [x] 4.5 Resolve IF's fwd-ref: offset = HERE - if-fwd, store at if-fwd

- [x] Task 5: Implement BEGIN as DEFIMMED in control_flow.asm (AC: #3, #4)
  - [x] 5.1 Push HERE to stack (backward target address)

- [x] Task 6: Implement UNTIL as DEFIMMED in control_flow.asm (AC: #3)
  - [x] 6.1 Compile `w_QBRANCH_cf` at HERE
  - [x] 6.2 Calculate backward offset = begin-addr - HERE (negative)
  - [x] 6.3 Compile offset

- [x] Task 7: Implement WHILE as DEFIMMED in control_flow.asm (AC: #4)
  - [x] 7.1 Compile `w_QBRANCH_cf` at HERE
  - [x] 7.2 Push HERE (forward ref for REPEAT to resolve)
  - [x] 7.3 Compile placeholder 0
  - [x] 7.4 SWAP to put forward ref under begin-addr: ( while-fwd begin-addr )

- [x] Task 8: Implement REPEAT as DEFIMMED in control_flow.asm (AC: #4)
  - [x] 8.1 Compile `w_BRANCH_cf` at HERE
  - [x] 8.2 Calculate backward offset = begin-addr - HERE
  - [x] 8.3 Compile offset
  - [x] 8.4 Resolve WHILE's forward ref: offset = HERE - while-fwd, store at while-fwd

- [x] Task 9: Add REPL tests (AC: #1-#6)
  - [x] 9.1 Test IF/THEN taken: `: TPOS DUP 0 > IF NEGATE THEN ; 5 TPOS .` expects `-5`
  - [x] 9.2 Test IF/THEN skipped: `-3 TPOS .` expects `-3`
  - [x] 9.3 Test IF/ELSE/THEN true: `: TSIGN 0< IF -1 ELSE 1 THEN ; -5 TSIGN .` expects `-1`
  - [x] 9.4 Test IF/ELSE/THEN false: `5 TSIGN .` expects `1`
  - [x] 9.5 Test nested IF: `: TNEST DUP 0 > IF DUP 10 > IF 2 ELSE 1 THEN ELSE 0 THEN ; 15 TNEST . 5 TNEST . -1 TNEST .` expects `2 .*1 .*0`
  - [x] 9.6 Test BEGIN/UNTIL: `: TCNT 0 BEGIN 1 + DUP 5 = UNTIL ; TCNT .` expects `5`
  - [x] 9.7 Test BEGIN/WHILE/REPEAT: `: TSUM 0 5 BEGIN DUP 0 > WHILE SWAP OVER + SWAP 1 - REPEAT DROP ; TSUM .` expects `15`
  - [x] 9.8 Test WHILE countdown to zero: `: TWH BEGIN DUP 0 > WHILE 1 - REPEAT ; 3 TWH .` expects `0`
  - [x] 9.9 Test compile-only guard: `IF` in interpret mode produces error and recovers
  - [x] 9.10 Test compile-only guard: `THEN` in interpret mode produces error and recovers
  - [x] 9.11 Test compile-only guard: `BEGIN` in interpret mode produces error and recovers
  - [x] 9.12 Test compile-only guard: `ELSE` in interpret mode produces error and recovers
  - [x] 9.13 Test compile-only guard: `WHILE` in interpret mode produces error and recovers
  - [x] 9.14 Test compile-only guard: `REPEAT` in interpret mode produces error and recovers
  - [x] 9.15 Test compile-only guard: `UNTIL` in interpret mode produces error and recovers
  - [x] 9.16 Test WHILE false on entry: `0 TWH .` expects `0` (loop body never executed)

- [x] Task 10: Verify no regressions
  - [x] 10.1 `make test` — all existing regression tests pass
  - [x] 10.2 `make test-repl` — all REPL tests pass (tests 1-50)
  - [x] 10.3 `make` — normal REPL build succeeds

## Dev Notes

### What Already Exists (verified from source)

**BRANCH and ?BRANCH are fully implemented** (`inner_interpreter.asm:101-135`):
- `w_BRANCH_cf` (line 103): Unconditional branch, adds inline offset to IP
- `w_QBRANCH_cf` (line 118): Conditional branch, pops TOS (BC); if 0 (FALSE) takes branch, else falls through

**Offset convention** (critical): Offset is relative to the **address of the offset cell itself**. The BRANCH handler reads the 2-byte offset, does `DEC HL` back to the start of the offset cell, then `ADD HL, DE`. So: `new_IP = offset_cell_addr + offset`.

**Verified by existing bootstrap.asm usage** (line 28): `DW .abs_done - $` where `$` = address of the DW = offset cell address. This produces `offset = target - offset_cell_addr`.

**Forward reference resolution formula**: `offset = HERE - fwd_ref_addr` (stored at fwd_ref_addr via `!`)
**Backward branch formula**: `offset = begin_addr - offset_cell_addr` (negative value, ADD wraps correctly in 16-bit)

**Compilation infrastructure ready:**
- `w_HERE_cf` (`memory.asm:92`): Push current HERE address
- `w_COMMA_cf` (`memory.asm:119`): Store cell at HERE, advance HERE by 2
- `w_STORE_cf` (`memory.asm`): `!` — store cell at address
- `w_LIT_cf` (`inner_interpreter.asm:87`): Inline literal
- `w_SWAP_cf`, `w_OVER_cf`, `w_DROP_cf`, `w_MINUS_cf` — all exist

**DEFIMMED macro** (`macros.asm:133-135`): Convenience for `DEFWORD name, F_IMMEDIATE`. Produces a Forth-level IMMEDIATE word with `JP DOCOL` code field.

**UserArea.state** (`structures.asm`): 2-byte STATE variable at IY+0. Non-zero = compile mode.

### Architecture Decision: Forth-Level DEFIMMED Words

Per architecture.md: *"Should be Forth (colon definitions): ... control flow compilers (IF, ELSE, THEN — IMMEDIATE words)"*

All control flow words are implemented as **DEFIMMED** (Forth-level IMMEDIATE colon definitions) in `control_flow.asm`, NOT as CODE words. They compose existing primitives (`,`, `HERE`, `!`, `-`, `SWAP`, `OVER`, `DROP`, `LIT`) to compile branches.

Only `?COMP` is a CODE word (needs direct register access for STATE check and BDOS calls for error message).

### `?COMP` Implementation

CODE word. Checks STATE via IY. If STATE=0, prints `? compile only` + CR/LF via raw BDOS calls (not BDOS_SAVE/RESTORE — we're about to ABORT anyway), then `JP w_ABORT_cf`.

```z80
w_QCOMP:
    DEFCODE "?COMP", 0
w_QCOMP_cf:
    LD      A, (IY+UserArea.state)
    OR      (IY+UserArea.state+1)
    JR      NZ, .qcomp_ok
    ; Print "? compile only" CR LF
    LD      HL, .comp_only_msg
    LD      B, 16               ; length
.qcomp_print:
    PUSH    HL
    PUSH    BC
    LD      E, (HL)
    LD      C, C_WRITE
    CALL    BDOS_ENTRY
    POP     BC
    POP     HL
    INC     HL
    DJNZ    .qcomp_print
    JP      w_ABORT_cf
.comp_only_msg:
    DB      "? compile only", 0x0D, 0x0A
.qcomp_ok:
    NEXT
```

### IF Implementation

```z80
w_IF:
    DEFIMMED "IF"
w_IF_body:
w_IF_cf EQU w_IF_body - 3
    DW w_QCOMP_cf               ; compile-only guard
    DW w_LIT_cf, w_QBRANCH_cf   ; push ?BRANCH xt
    DW w_COMMA_cf                ; compile ?BRANCH at HERE
    DW w_HERE_cf                 ; push HERE (fwd-ref = offset cell addr)
    DW w_LIT_cf, 0
    DW w_COMMA_cf                ; compile placeholder 0
    DW EXIT_CODE
```

Stack effect at compile time: `( -- fwd-ref )`

### THEN Implementation

```z80
w_THEN:
    DEFIMMED "THEN"
w_THEN_body:
w_THEN_cf EQU w_THEN_body - 3
    DW w_QCOMP_cf               ; compile-only guard
    ; ( fwd-ref -- )
    DW w_HERE_cf                 ; ( fwd-ref here )
    DW w_OVER_cf                 ; ( fwd-ref here fwd-ref )
    DW w_MINUS_cf                ; ( fwd-ref here-fwd-ref ) = offset
    DW w_SWAP_cf                 ; ( offset fwd-ref )
    DW w_STORE_cf                ; store offset at fwd-ref
    DW EXIT_CODE
```

### ELSE Implementation

```z80
w_ELSE:
    DEFIMMED "ELSE"
w_ELSE_body:
w_ELSE_cf EQU w_ELSE_body - 3
    DW w_QCOMP_cf               ; compile-only guard
    ; ( if-fwd -- else-fwd )
    DW w_LIT_cf, w_BRANCH_cf    ; push BRANCH xt
    DW w_COMMA_cf                ; compile BRANCH at HERE
    DW w_HERE_cf                 ; push HERE (else-fwd for THEN)
    DW w_LIT_cf, 0
    DW w_COMMA_cf                ; compile placeholder 0
    DW w_SWAP_cf                 ; ( else-fwd if-fwd )
    ; Resolve IF's forward reference
    DW w_HERE_cf                 ; ( else-fwd if-fwd here )
    DW w_OVER_cf                 ; ( else-fwd if-fwd here if-fwd )
    DW w_MINUS_cf                ; ( else-fwd if-fwd offset )
    DW w_SWAP_cf                 ; ( else-fwd offset if-fwd )
    DW w_STORE_cf                ; store offset at if-fwd; ( else-fwd )
    DW EXIT_CODE
```

### BEGIN Implementation

```z80
w_BEGIN:
    DEFIMMED "BEGIN"
w_BEGIN_body:
w_BEGIN_cf EQU w_BEGIN_body - 3
    DW w_QCOMP_cf               ; compile-only guard
    DW w_HERE_cf                 ; push HERE (backward target)
    DW EXIT_CODE
```

Stack effect at compile time: `( -- begin-addr )`

### UNTIL Implementation

```z80
w_UNTIL:
    DEFIMMED "UNTIL"
w_UNTIL_body:
w_UNTIL_cf EQU w_UNTIL_body - 3
    DW w_QCOMP_cf               ; compile-only guard
    ; ( begin-addr -- )
    DW w_LIT_cf, w_QBRANCH_cf
    DW w_COMMA_cf                ; compile ?BRANCH
    DW w_HERE_cf                 ; ( begin-addr here ) here = offset cell addr
    DW w_MINUS_cf                ; ( begin-addr - here ) negative backward offset
    DW w_COMMA_cf                ; compile offset
    DW EXIT_CODE
```

**Offset correctness**: After compiling ?BRANCH, HERE points to the offset cell. `begin-addr - HERE` is negative (backward). `,` stores this offset at HERE then advances HERE by 2. At runtime, BRANCH reads from offset_cell_addr and computes `offset_cell_addr + offset = HERE + (begin - HERE) = begin`. The offset is computed before `,` advances HERE, so offset_cell_addr matches the address where the value is stored.

### WHILE Implementation

```z80
w_WHILE:
    DEFIMMED "WHILE"
w_WHILE_body:
w_WHILE_cf EQU w_WHILE_body - 3
    DW w_QCOMP_cf               ; compile-only guard
    ; ( begin-addr -- while-fwd begin-addr )
    DW w_LIT_cf, w_QBRANCH_cf
    DW w_COMMA_cf                ; compile ?BRANCH
    DW w_HERE_cf                 ; ( begin-addr while-fwd )
    DW w_LIT_cf, 0
    DW w_COMMA_cf                ; compile placeholder 0
    DW w_SWAP_cf                 ; ( while-fwd begin-addr )
    DW EXIT_CODE
```

### REPEAT Implementation

```z80
w_REPEAT:
    DEFIMMED "REPEAT"
w_REPEAT_body:
w_REPEAT_cf EQU w_REPEAT_body - 3
    DW w_QCOMP_cf               ; compile-only guard
    ; ( while-fwd begin-addr -- )
    ; Compile BRANCH back to begin-addr
    DW w_LIT_cf, w_BRANCH_cf
    DW w_COMMA_cf                ; compile BRANCH
    DW w_HERE_cf                 ; ( while-fwd begin-addr here )
    DW w_MINUS_cf                ; ( while-fwd begin-addr-here ) backward offset
    DW w_COMMA_cf                ; compile backward offset; ( while-fwd )
    ; Resolve WHILE's forward reference
    DW w_HERE_cf                 ; ( while-fwd here )
    DW w_OVER_cf                 ; ( while-fwd here while-fwd )
    DW w_MINUS_cf                ; ( while-fwd here-while-fwd )
    DW w_SWAP_cf                 ; ( offset while-fwd )
    DW w_STORE_cf                ; store offset at while-fwd; ( )
    DW EXIT_CODE
```

### Compiled Thread Examples

**`: TPOS DUP 0 > IF NEGATE THEN ;`** compiles to:
```
[JP DOCOL]
[w_DUP_cf]
[w_LIT_cf][0]
[w_GREATER_cf]
[w_QBRANCH_cf]       ← IF compiles this
[offset to THEN]     ← THEN patches this
[w_NEGATE_cf]
[EXIT_CODE]          ← ; compiles this
```

**`: TCNT 0 BEGIN 1 + DUP 5 = UNTIL ;`** compiles to:
```
[JP DOCOL]
[w_LIT_cf][0]
← BEGIN records HERE here
[w_LIT_cf][1]
[w_PLUS_cf]
[w_DUP_cf]
[w_LIT_cf][5]
[w_EQUALS_cf]
[w_QBRANCH_cf]       ← UNTIL compiles this
[negative offset]    ← points back to BEGIN target
[EXIT_CODE]
```

**`: TSUM 0 5 BEGIN DUP 0 > WHILE SWAP OVER + SWAP 1 - REPEAT DROP ;`** compiles to:
```
[JP DOCOL]
[w_LIT_cf][0]
[w_LIT_cf][5]
← BEGIN records HERE here
[w_DUP_cf]
[w_LIT_cf][0]
[w_GREATER_cf]
[w_QBRANCH_cf]       ← WHILE compiles this
[fwd offset]         ← REPEAT patches this to point past BRANCH
[w_SWAP_cf]
[w_OVER_cf]
[w_PLUS_cf]
[w_SWAP_cf]
[w_LIT_cf][1]
[w_MINUS_cf]
[w_BRANCH_cf]        ← REPEAT compiles this
[backward offset]    ← points back to BEGIN target
← WHILE's fwd-ref resolves here
[w_DROP_cf]
[EXIT_CODE]
```

### Code Field Label Convention (CRITICAL)

Per project convention (memory: feedback_defword_cf_label.md):
- For **DEFIMMED** words (which expand to DEFWORD with F_IMMEDIATE), `w_XXX_cf` must use `EQU body - 3` to point to `JP DOCOL`, not the body
- For **DEFCODE** words (`?COMP`), `w_XXX_cf` is placed right after the DEFCODE macro call

### File Location

All new code goes in `src/control_flow.asm` (currently a stub with only a comment header).

| Word | Type | File |
|------|------|------|
| ?COMP | DEFCODE | control_flow.asm |
| IF | DEFIMMED | control_flow.asm |
| THEN | DEFIMMED | control_flow.asm |
| ELSE | DEFIMMED | control_flow.asm |
| BEGIN | DEFIMMED | control_flow.asm |
| UNTIL | DEFIMMED | control_flow.asm |
| WHILE | DEFIMMED | control_flow.asm |
| REPEAT | DEFIMMED | control_flow.asm |

### w_MINUS_cf Stack Behaviour (CRITICAL)

`-` (MINUS) does `( n1 n2 -- n1-n2 )`. The **second** on stack minus TOS. So:
- `HERE OVER -` with stack `( fwd-ref here fwd-ref )` → `here - fwd-ref` — **CORRECT** for forward offset
- `HERE -` with stack `( begin-addr here )` → `begin-addr - here` — **CORRECT** for backward offset (negative)

### Testing Strategy

**Primary: REPL-piped tests** (per memory: feedback_repl_tests_preferred.md)

New tests start from **test 35** onwards in Makefile's `test-repl` target. Do NOT add tests to the regression test thread.

Tests use existing arithmetic/stack/comparison words. Note: `."` and `S"` do NOT exist yet (Story 3.5), so tests must use `.` (dot) for output verification.

### Existing Label References Needed

| Label | File | Purpose |
|-------|------|---------|
| `w_QBRANCH_cf` | inner_interpreter.asm:118 | Compiled by IF, UNTIL, WHILE |
| `w_BRANCH_cf` | inner_interpreter.asm:103 | Compiled by ELSE, REPEAT |
| `w_HERE_cf` | memory.asm:94 | Get current dictionary pointer |
| `w_COMMA_cf` | memory.asm:121 | Store cell at HERE and advance |
| `w_STORE_cf` | memory.asm | `!` — store cell at address |
| `w_SWAP_cf` | stack_ops.asm | Stack manipulation |
| `w_OVER_cf` | stack_ops.asm | Stack manipulation |
| `w_DROP_cf` | stack_ops.asm | Stack manipulation |
| `w_MINUS_cf` | arithmetic.asm | Subtraction for offset calc |
| `w_LIT_cf` | inner_interpreter.asm:87 | Inline literal |
| `EXIT_CODE` | inner_interpreter.asm:23 | End of colon definition |
| `w_ABORT_cf` | system.asm | Error recovery target |
| `BDOS_ENTRY` | constants.asm | CP/M BDOS entry (0x0005) |
| `C_WRITE` | constants.asm | BDOS console write function |
| `UserArea.state` | structures.asm | Compile/interpret state |

### Include Order

`control_flow.asm` is already included in `antforth.asm` between `memory.asm` and `io.asm`. It appears AFTER `inner_interpreter.asm` (where BRANCH/?BRANCH live) and `memory.asm` (where HERE/COMMA live), so all referenced labels will be defined. The forward reference to `w_ABORT_cf` (in `system.asm`, included later) is fine because sjasmplus resolves labels in a multi-pass.

### Anti-Patterns to Avoid

1. **Do NOT implement these as CODE words** — architecture says Forth-level (DEFIMMED). Only `?COMP` is CODE.
2. **Do NOT forget `EQU body - 3`** for DEFIMMED words — the `_cf` label must point to `JP DOCOL`, not the body.
3. **Do NOT forget `?COMP` guard** at the start of every control flow DEFIMMED word.
4. **Do NOT use BDOS_SAVE/BDOS_RESTORE** in `?COMP` — we're about to ABORT, register preservation is irrelevant.
5. **Do NOT confuse offset direction**: forward = positive (HERE - fwd-ref), backward = negative (begin-addr - HERE).
6. **Do NOT add tests to the regression test thread** — use REPL-piped tests only (memory: feedback_repl_tests_preferred.md).
7. **For DEFIMMED words, `w_XXX_cf` must use `EQU body - 3`** — never point to the body directly.
8. **`0>` does NOT exist** — always use `0 >` (two separate words: LIT 0 then `>`). Verified: `w_ZERO_EQUALS_cf` and `w_ZERO_LESS_cf` exist, but there is no `0>` word.
9. **Do NOT forget that `,` (COMMA) stores a CELL (2 bytes)** — the offset is a 2-byte signed value, which is correct.
10. **Do NOT create separate `resolve_forward` or `resolve_backward` helper words** — the inline Forth sequences are short enough and creating helpers adds dictionary entries for no reuse benefit.

### Register Contract Reminders

Only `?COMP` is a CODE word. It must respect:
- **BC = TOS** — not modified on success (NEXT preserves)
- **DE = IP** — not explicitly used, but BDOS calls will clobber it (OK since we ABORT)
- **IY = user pointer** — used to read STATE

All DEFIMMED words execute as threaded code, so register contract is maintained automatically by the inner interpreter.

### Project Structure Notes

- `src/control_flow.asm` — Replace stub with all control flow words
- `Makefile` — Add REPL tests 35-44
- No other files need changes
- Include order in `antforth.asm` is already correct

### References

- [Source: src/inner_interpreter.asm:101-110] — BRANCH implementation (offset convention)
- [Source: src/inner_interpreter.asm:116-135] — ?BRANCH implementation
- [Source: src/inner_interpreter.asm:23-29] — EXIT_CODE
- [Source: src/inner_interpreter.asm:85-94] — LIT implementation
- [Source: src/bootstrap.asm:21-31] — ABS uses ?BRANCH with `DW .abs_done - $` (assembly-time offset model)
- [Source: src/compiler.asm:355-386] — SEMICOLON (STATE guard pattern, compile EXIT_CODE pattern)
- [Source: src/compiler.asm:415-435] — LITERAL (compile-time IMMEDIATE pattern)
- [Source: src/compiler.asm:569-590] — DOES> (IMMEDIATE CODE word with STATE guard)
- [Source: src/memory.asm:92-98] — HERE implementation
- [Source: src/memory.asm:119-131] — COMMA implementation
- [Source: src/macros.asm:133-135] — DEFIMMED macro
- [Source: src/macros.asm:100-127] — DEFWORD macro (code field = JP DOCOL)
- [Source: src/control_flow.asm] — Currently a stub, target for all new code
- [Source: src/structures.asm:18-27] — UserArea struct (state offset)
- [Source: _bmad-output/planning-artifacts/architecture.md] — Control flow words should be Forth (colon definitions)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.3] — Story requirements and BDD criteria

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No debug issues encountered — all implementations worked on first attempt.

### Completion Notes List

- Implemented `?COMP` as a CODE word checking STATE via IY; prints "? compile only" + CRLF and ABORTs when STATE=0
- Implemented IF, THEN, ELSE as DEFIMMED words composing ?BRANCH/BRANCH with forward reference resolution
- Implemented BEGIN, UNTIL, WHILE, REPEAT as DEFIMMED words for indefinite loops with backward/forward branching
- All DEFIMMED words use `EQU body - 3` for `_cf` labels per project convention
- All DEFIMMED words start with `DW w_QCOMP_cf` compile-only guard
- Added 10 REPL tests (tests 35-44) covering all acceptance criteria
- All 50 REPL tests pass, all regression tests pass, normal build succeeds

### File List

- `src/control_flow.asm` — Replaced stub with full implementation: ?COMP, IF, THEN, ELSE, BEGIN, UNTIL, WHILE, REPEAT
- `Makefile` — Added REPL tests 35-50 for conditionals, loops, nested IF, compile-only guards, and edge cases

### Change Log

- 2026-04-06: Implemented all control flow words (?COMP, IF, THEN, ELSE, BEGIN, UNTIL, WHILE, REPEAT) and added 10 REPL tests (35-44). All acceptance criteria satisfied.
- 2026-04-06: Code review fixes — added 6 REPL tests (45-50): compile-only guard tests for all 5 remaining words (BEGIN, ELSE, WHILE, REPEAT, UNTIL) and WHILE false-entry edge case. Added BDOS_SAVE skip rationale comment to ?COMP. Total: 50 REPL tests, all passing.
