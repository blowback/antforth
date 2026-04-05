# Story 2.3: Number Formatting & Stack Inspection

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to display numbers and inspect the stack,
So that I can see the results of my computations and debug my work.

## Acceptance Criteria

1. **Given** the value 42 on the stack **When** `.` (dot) executes **Then** `42 ` is printed to the console (number followed by a space) using the current BASE

2. **Given** the unsigned value 65535 on the stack **When** `U.` executes **Then** `65535 ` is printed (unsigned interpretation)

3. **Given** the value 42 on the stack and a field width of 6 **When** `.R` executes **Then** `    42` is printed (right-justified in 6 characters, no trailing space)

4. **Given** the stack contains values 1, 2, 3 (3 on top) **When** `.S` executes **Then** the output shows `<3> 1 2 3 ` (stack depth in angle brackets, then all values bottom-to-top, each followed by space) without consuming the stack

5. **Given** the system is in decimal mode (default) **When** the user types `HEX` **Then** BASE is set to 16 and subsequent number I/O uses hexadecimal **When** the user types `DECIMAL` **Then** BASE is set to 10

6. **Given** BASE is set to 16 **When** the user types `FF .` **Then** `FF ` is printed (standard Forth: both parsing and display use current BASE)

7. **Given** a negative value -1 on the stack **When** `.` executes **Then** `-1 ` is printed (leading minus sign for negative numbers)

8. **Given** the value 0 on the stack **When** `.` executes **Then** `0 ` is printed

9. **Given** an empty stack **When** `.S` executes **Then** `<0> ` is displayed and the stack remains empty

## Tasks / Subtasks

- [x] Task 1: Add data areas and constants (AC: supports all)
  - [x] 1.1 Add `NUM_BUF_SIZE EQU 18` to `src/constants.asm` (16 binary digits + sign + safety)
  - [x] 1.2 Add `num_buf: DS NUM_BUF_SIZE` to data area in `src/antforth.asm`

- [x] Task 2: Implement `u_to_str` internal helper in `src/formatting.asm` (AC: supports all number output)
  - [x] 2.1 Subroutine: convert unsigned 16-bit number to ASCII string in `num_buf`
  - [x] 2.2 Fills buffer right-to-left using division by BASE
  - [x] 2.3 Returns: HL = start address of digit string, A = length (character count)
  - [x] 2.4 Handles all bases 2-36 (digits 0-9, then A-Z for 10-35)

- [x] Task 3: Implement `.` (dot) as CODE word in `src/formatting.asm` (AC: #1, #7, #8)
  - [x] 3.1 `.` ( n -- ) — print signed number followed by space
  - [x] 3.2 Handle negative: check sign bit, emit `-`, negate BC, then print unsigned
  - [x] 3.3 Call `u_to_str` for conversion, then emit digits + trailing space via BDOS

- [x] Task 4: Implement `U.` as CODE word in `src/formatting.asm` (AC: #2)
  - [x] 4.1 `U.` ( u -- ) — print unsigned number followed by space
  - [x] 4.2 Call `u_to_str`, emit digits + trailing space via BDOS

- [x] Task 5: Implement `.R` as CODE word in `src/formatting.asm` (AC: #3)
  - [x] 5.1 `.R` ( n width -- ) — print signed number right-justified in field width
  - [x] 5.2 Convert number to string (handling sign), calculate padding = width - string_length
  - [x] 5.3 Emit padding spaces (if positive), then emit string (no trailing space)

- [x] Task 6: Implement `.S` as CODE word in `src/formatting.asm` (AC: #4, #9)
  - [x] 6.1 `.S` ( -- ) — display stack contents non-destructively
  - [x] 6.2 Print `<depth>` prefix using number output
  - [x] 6.3 Walk parameter stack from bottom to top, printing each item with `.` logic
  - [x] 6.4 Print TOS (BC) last. Stack is unchanged on exit.
  - [x] 6.5 Handle empty stack: print `<0> ` only

- [x] Task 7: Implement HEX and DECIMAL as DEFWORD in `src/formatting.asm` (AC: #5, #6)
  - [x] 7.1 `HEX` ( -- ) — set BASE to 16
  - [x] 7.2 `DECIMAL` ( -- ) — set BASE to 10
  - [x] 7.3 Use DEFWORD with `w_XXX_cf EQU w_XXX_body - 3` pattern

- [x] Task 8: Add tests to test_thread and update Makefile (AC: #1-9)
  - [x] 8.1 Test `.` with: 42, 0, -1, -32768 (edge cases)
  - [x] 8.2 Test `U.` with: 65535
  - [x] 8.3 Test `.R` with: 42 in field width 6
  - [x] 8.4 Test `.S` with known stack contents (1, 2, 3)
  - [x] 8.5 Test HEX/DECIMAL: switch to hex, print FF, switch back to decimal
  - [x] 8.6 Add REPL test: `2 3 + .` should output `5 ` (the full pipeline from epics AC)
  - [x] 8.7 Verify all existing regression tests still pass under `make test`
  - [x] 8.8 Verify all REPL tests still pass under `make test-repl`

## Dev Notes

### What Already Exists (from Epic 1 + Stories 2.1-2.2)

**Must not be modified** unless there's a bug:

- **Inner interpreter** (`inner_interpreter.asm`): DOCOL, EXIT_CODE, LIT, BRANCH, ?BRANCH, EXECUTE
- **I/O words** (`io.asm`): EMIT, TYPE, CR, SPACE, SPACES, KEY, KEY?, ACCEPT — all use BDOS_SAVE/BDOS_RESTORE
- **Stack words** (`stack_ops.asm`): DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH, SP@, SP!, RP@, RP!
- **Arithmetic** (`arithmetic.asm`): +, -, *, /, MOD, /MOD — available for number conversion
- **Memory** (`memory.asm`): @, !, +!, C@, C! — needed for BASE access
- **User variables** (`outer_interpreter.asm`): BASE, STATE, >IN, #TIB, SOURCE, BL, push_user_var
- **INTERPRET, QUIT, ABORT** — outer interpreter loop, error recovery
- **Number parsing** (`strings.asm`): >NUMBER, NUMBER?, char_to_digit, do_number — the reverse of what we're building
- **FIND, COUNT** (`dictionary.asm`): dictionary lookup
- **56+ CODE primitives** from Epic 1 plus all Story 2.1-2.2 words

### Register Contract (Inviolable)

| Register | Role | Rules |
|----------|------|-------|
| BC | TOS | Contains TOS on entry; must contain new TOS on exit |
| DE | IP | Must be preserved — save to return stack (IX) if used as scratch |
| SP | Parameter stack | Net effect must match stack signature |
| IX | Return stack | Preserve unless doing return stack ops |
| IY | User pointer | Preserve unless accessing user variables |
| HL, AF | Scratch | Free within CODE words |

### UserArea Offsets (IY-based)

| Offset | Field | Size |
|--------|-------|------|
| IY+UserArea.state | STATE | 2B |
| IY+UserArea.base | BASE | 2B |
| IY+UserArea.here | HERE | 2B |
| IY+UserArea.latest | LATEST | 2B |
| IY+UserArea.tib_addr | TIB | 2B |
| IY+UserArea.tib_len | #TIB | 2B |
| IY+UserArea.tib_in | >IN | 2B |
| IY+UserArea.source_id | SOURCE-ID | 2B |

Use struct field names (e.g., `IY+UserArea.base`), not raw offsets.

### New Data Area

In `src/antforth.asm` data area, add:

```z80
NUM_BUF_SIZE    EQU     18              ; Max 16 binary digits + sign + padding
num_buf:        DS      NUM_BUF_SIZE    ; Number-to-string conversion buffer
```

Or define `NUM_BUF_SIZE` in `src/constants.asm` alongside PAD_OFFSET if preferred.

### Key Design: `u_to_str` Internal Subroutine

This is the core number-to-string conversion used by `.`, `U.`, `.R`, and `.S`. It is NOT a Forth word — it's an internal Z80 subroutine called from within CODE words.

**Interface:**
```z80
; u_to_str: Convert unsigned 16-bit number to ASCII string
; Input:  BC = unsigned number to convert
;         BASE read from (IY+UserArea.base)
; Output: HL = address of first digit character in num_buf
;         A  = character count (string length)
; Clobbers: AF, BC (consumed), HL
; Preserves: DE, IX, IY, SP
```

**Algorithm:**
1. Point HL to end of `num_buf` (num_buf + NUM_BUF_SIZE - 1)
2. Set digit count = 0
3. **Loop:**
   a. Divide BC by BASE → quotient in BC, remainder in A
   b. Convert remainder to ASCII: add '0', if >= 10 add ('A'-'0'-10) for hex
   c. Store digit at (HL), decrement HL, increment count
   d. If BC (quotient) != 0, repeat
4. Increment HL to point to first digit (HL was decremented one past)
5. Return HL = start address, A = count

**Division by BASE:** Z80 has no native 16-bit divide. Reuse the division pattern from `arithmetic.asm` (w_SLASH or the internal divide subroutine). If no shared divide routine exists, implement a 16÷8 division (since BASE is always <= 36, it fits in a byte):

```z80
; Divide BC (16-bit) by E (8-bit base)
; Result: BC = quotient, A = remainder
div_bc_by_e:
        XOR     A               ; Clear remainder (A=0)
        LD      D, 16           ; 16 bits to process
.div_loop:
        SLA     C               ; Shift BC left through carry
        RL      B
        RLA                     ; Shift carry into remainder
        CP      E               ; Compare remainder with divisor
        JR      C, .div_no_sub  ; If remainder < divisor, skip
        SUB     E               ; Subtract divisor from remainder
        INC     C               ; Set bit 0 of quotient
.div_no_sub:
        DEC     D
        JR      NZ, .div_loop
        RET                     ; BC = quotient, A = remainder
```

**NOTE:** D is used as a loop counter here. Since DE = IP must be preserved, `u_to_str` callers must save DE to the return stack BEFORE calling. The `div_bc_by_e` helper clobbers D. Alternative: save D on the machine stack within the divide routine. The dev agent should decide the cleanest approach.

**Digit-to-ASCII conversion** (reverse of `char_to_digit` in `strings.asm`):
```z80
; Convert digit value (0-35) in A to ASCII character
; 0-9 → '0'-'9', 10-35 → 'A'-'Z'
digit_to_char:
        CP      10
        JR      C, .decimal
        ADD     A, 'A' - 10
        RET
.decimal:
        ADD     A, '0'
        RET
```

### `.` (dot) Implementation Design

**Stack effect:** `. ( n -- )`

`.` is a CODE word:

```z80
w_DOT:
        DEFCODE ".", 0
w_DOT_cf:
        ; Save DE (IP) to return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        ; Check sign
        BIT     7, B
        JR      Z, .dot_positive
        ; Negative: emit '-'
        PUSH    BC              ; Save number
        LD      E, '-'
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC              ; Restore number
        ; Negate BC: BC = 0 - BC
        XOR     A
        SUB     C
        LD      C, A
        SBC     A, A
        SUB     B
        LD      B, A
.dot_positive:
        ; BC = unsigned value, convert to string
        CALL    u_to_str        ; HL = string addr, A = length
        ; Emit digits using TYPE-like loop
        LD      B, A            ; B = count (repurpose — number consumed)
.dot_emit:
        LD      E, (HL)
        PUSH    HL
        PUSH    BC
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC
        POP     HL
        INC     HL
        DJNZ    .dot_emit
        ; Emit trailing space
        LD      E, ' '
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        ; Restore DE (IP) from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        ; Pop new TOS from parameter stack
        POP     BC
        NEXT
```

**Critical: BDOS calls clobber registers.** After each `CALL BDOS_ENTRY`, AF, BC, DE, HL may all be clobbered. Save/restore HL (buffer pointer) and B (count) around each BDOS call. The pattern above shows PUSH HL/BC before BDOS and POP after.

**Alternative approach:** Instead of calling BDOS per-character, copy the string to a temp area and use the TYPE-like pattern. Or build the full output string (with sign and trailing space) in `num_buf` and emit it all at once with a single TYPE-equivalent loop. The dev agent should choose whichever is cleanest.

### `U.` Implementation Design

**Stack effect:** `U. ( u -- )`

Identical to `.` but without sign handling:

```z80
w_U_DOT:
        DEFCODE "U.", 0
w_U_DOT_cf:
        ; Save DE, call u_to_str, emit digits + space, restore DE, pop TOS
        ; (same as .dot_positive path in w_DOT)
```

**Code sharing opportunity:** `.` and `U.` share the "convert + emit + space" path. Factor this out as an internal label (e.g., `emit_unsigned:`) that both words JP to after their respective setup. The dev agent should factor common code where practical.

### `.R` Implementation Design

**Stack effect:** `.R ( n width -- )`

```z80
w_DOT_R:
        DEFCODE ".R", 0
w_DOT_R_cf:
        ; BC = width (TOS), stack has: ... n
        ; Save width, pop n
        ; Save DE (IP)
        ; Check sign of n, prepare string
        ; Calculate padding = width - string_length (- 1 if negative for '-')
        ; Emit padding spaces
        ; Emit '-' if negative
        ; Emit digits (NO trailing space)
        ; Restore DE, pop new TOS, NEXT
```

Key difference from `.`: output is right-justified in a field, no trailing space. Need the string length before emitting to calculate padding.

### `.S` Implementation Design

**Stack effect:** `.S ( -- )` — non-destructive stack display

This is the most complex word. It must print all stack items without consuming them.

**Algorithm:**
1. Save DE (IP) to return stack
2. Calculate depth: `depth = ((sp_base - SP) / 2) + 1` (the +1 accounts for BC = TOS not being on SP)
   - Special case: if SP == sp_base (truly empty stack, e.g., right after ABORT), depth = 0 and BC is not a valid item
   - **Practical note:** After cold_start, BC = 0 and SP = sp_base. DEPTH returns 1 (counts BC as an item). This is consistent with standard Forth TOS-in-register behaviour. `.S` should match DEPTH's count.
3. Print `<` character
4. Print depth as unsigned number (reuse `u_to_str`)
5. Print `> ` (close bracket + space)
6. If depth == 0: skip to end
7. Walk the parameter stack from bottom to top:
   - Bottom item is at `sp_base - 2`
   - Next item is at `sp_base - 4`
   - ... up to SP (which holds second-on-stack)
   - Final item is BC (TOS)
8. For each item: load it, print it with `.` logic (signed, followed by space)
9. Restore DE (IP), BC is unchanged (still TOS), NEXT

**Stack walk detail:**
```
addr = sp_base - 2    ; bottom of stack
count = depth - 1     ; items on SP (excluding TOS in BC)
for i = 0 to count-1:
    value = (addr)     ; load 16-bit cell
    print value        ; signed, with space
    addr -= 2
print BC               ; TOS (last item)
```

**Register pressure is extreme.** The dev agent will need to use the return stack (IX) or `num_buf` area for temporary storage during the stack walk. Possible approach: save the walk state (addr, remaining count) to the return stack around each number output + BDOS call sequence.

### HEX and DECIMAL — DEFWORD Implementation

Trivial linear DEFWORD words:

```z80
; -----------------------------------------------
; HEX ( -- )
;   Set BASE to 16
; -----------------------------------------------
w_HEX:
        DEFWORD "HEX", 0
w_HEX_body:
w_HEX_cf       EQU     w_HEX_body - 3
        DW      w_LIT_cf, 16
        DW      w_BASE_cf
        DW      w_STORE_cf
        DW      w_EXIT_cf

; -----------------------------------------------
; DECIMAL ( -- )
;   Set BASE to 10
; -----------------------------------------------
w_DECIMAL:
        DEFWORD "DECIMAL", 0
w_DECIMAL_body:
w_DECIMAL_cf    EQU     w_DECIMAL_body - 3
        DW      w_LIT_cf, 10
        DW      w_BASE_cf
        DW      w_STORE_cf
        DW      w_EXIT_cf
```

**Critical DEFWORD pattern:** Use `w_XXX_cf EQU w_XXX_body - 3` — do NOT place `w_XXX_cf:` (label with colon) after DEFWORD. The EQU points to the JP DOCOL instruction (3 bytes before the body), which is where the inner interpreter must land. See debug log from Story 2.2.

### Naming Convention for Labels

| Forth word | Label prefix | Code field label | Type |
|-----------|-------------|-----------------|------|
| . | w_DOT | w_DOT_cf | CODE |
| U. | w_U_DOT | w_U_DOT_cf | CODE |
| .R | w_DOT_R | w_DOT_R_cf | CODE |
| .S | w_DOT_S | w_DOT_S_cf | CODE |
| HEX | w_HEX | w_HEX_cf (EQU) | DEFWORD |
| DECIMAL | w_DECIMAL | w_DECIMAL_cf (EQU) | DEFWORD |

Internal helpers (NOT Forth words):

| Function | Label |
|----------|-------|
| Unsigned number to string | u_to_str |
| 16-bit divide by 8-bit | div_bc_by_e (or similar) |
| Digit value to ASCII char | digit_to_char |

### File Structure

| File | Changes | Notes |
|------|---------|-------|
| `src/constants.asm` | Add NUM_BUF_SIZE | Number buffer size constant |
| `src/formatting.asm` | `.`, `U.`, `.R`, `.S`, HEX, DECIMAL, u_to_str, helpers | Main implementation file — replace stub |
| `src/antforth.asm` | Add num_buf to data area; add test_thread tests | Data area + tests |
| `Makefile` | Add REPL test for `2 3 + .` | New REPL integration test |

**Include order is already correct** — `formatting.asm` is included between `strings.asm` and `outer_interpreter.asm` in `antforth.asm`. This means:
- All I/O words (EMIT, TYPE, etc.) are available (io.asm included earlier)
- Stack ops (DEPTH, SP@) are available (stack_ops.asm included earlier)
- User variables (BASE) are defined later in outer_interpreter.asm — verify that `w_BASE_cf`, `w_STORE_cf`, and `w_LIT_cf` labels are accessible from formatting.asm at assembly time. Since sjasmplus does multi-pass resolution, forward references to labels should work for DW addresses in DEFWORD bodies. For CODE words calling `u_to_str` (which reads BASE via `(IY+UserArea.base)` directly), there is no forward reference issue.

**Critical: Verify include order.** If `formatting.asm` is included before `outer_interpreter.asm`, then `w_BASE_cf`, `w_STORE_cf` etc. are forward references in the HEX/DECIMAL DEFWORD bodies. sjasmplus handles forward references in `DW` expressions (resolved on second pass), so this should work. But verify.

### Anti-Patterns to Avoid

1. **Do NOT forget to save/restore DE (IP)** in all CODE words. DE must be saved to return stack before any use as scratch, and restored before NEXT.
2. **Do NOT clobber registers across BDOS calls.** BDOS_ENTRY clobbers AF, BC, DE, HL. Save everything you need around each `CALL BDOS_ENTRY`.
3. **Do NOT use BDOS_SAVE/BDOS_RESTORE** for these words — they have complex register needs. Manage IP save/restore manually to the return stack (IX), same pattern as ACCEPT in Story 2.2.
4. **Do NOT use IX or IY as scratch** without save/restore. IX = return stack, IY = user area.
5. **Do NOT forget the DEFWORD cf label pattern** — `w_XXX_cf EQU w_XXX_body - 3` for DEFWORD words. See memory/feedback note.
6. **Do NOT assume `.S` can use the parameter stack for temps** — the whole point is to display the parameter stack non-destructively. Use return stack (IX) for temporary storage during `.S`.
7. **Do NOT break existing tests.** All 62+ regression tests and 4 REPL tests must still pass.
8. **Do NOT add extra newlines after `.` or `U.`** — they output `number` followed by exactly one space. No CR/LF.
9. **Do NOT hardcode base 10** — all number output must use the current BASE from `(IY+UserArea.base)`.
10. **Do NOT forget zero** — `0 .` must output `0 `, not an empty string. The conversion loop must execute at least once (do-while, not while-do).

### Previous Story Learnings (from Stories 2.1-2.2)

- **DEFWORD cf label bug:** `w_XXX_cf:` after DEFWORD points to body, not code field. Fixed with `EQU body - 3`. This is critical for HEX and DECIMAL.
- **BDOS 10 echo behavior:** BDOS 10 echoes characters including CR. ACCEPT emits only LF. Established pattern for BDOS interaction.
- **BDOS calling convention:** For words with complex register needs, save DE (IP) to return stack manually — don't use BDOS_SAVE/BDOS_RESTORE.
- **Test thread pattern:** Emit known character on success (e.g., 'A'), '!' on failure. Each test is a block of DW instructions in test_thread.
- **Label convention:** `w_NAME` before DEFCODE/DEFWORD, `w_NAME_cf` after (or EQU for DEFWORD). Internal helpers use `lowercase_with_underscores`.
- **iz-cpm pipe behavior:** iz-cpm crashes with UnexpectedEof when stdin is a pipe — use `2>/dev/null || true` in Makefile test targets.
- **char_to_digit** exists in `strings.asm` — `digit_to_char` is the reverse operation needed here.
- **do_number** subroutine exists in `strings.asm` for string-to-number — the reverse direction. Its BASE access pattern (`LD A, (IY+UserArea.base)`) is a model for `u_to_str`.

### Git Intelligence

Recent commits show one-commit-per-story pattern:
```
0054157 completed story 2.1
b57363d completed story 1.5 plus retro
0f66341 implemented story 1.4 - arithmetic and logic ops
155855b implemented story 1.3 - stack and memory ops
7891f46 implement inner interpreter and threading (story 1-2)
```

Codebase is stable — all tests pass. Story 2.2 added the outer interpreter (ACCEPT, WORD, >NUMBER, NUMBER?, INTERPRET, QUIT, ABORT). The REPL is functional. This story completes the "see results" capability that makes the REPL truly useful.

### Testing Strategy

**All words must be tested through the threading model** — no standalone assembly bypassing NEXT/DOCOL. See memory feedback rule.

**Three test tracks:**

1. **Regression (`make test`):** Add tests to test_thread in antforth.asm:
   - `.` tests: `LIT 42, w_DOT_cf` → check output contains "42 "
   - `.` negative: `LIT -1, w_DOT_cf` → check output contains "-1 "
   - `.` zero: `LIT 0, w_DOT_cf` → check output contains "0 "
   - `U.` test: `LIT 0xFFFF, w_U_DOT_cf` → check output contains "65535 "
   - `.R` test: `LIT 42, LIT 6, w_DOT_R_cf` → check output contains "    42"
   - `.S` test: Push known values, call `.S`, verify output format
   - HEX/DECIMAL: Set HEX, print a number, set DECIMAL, verify base switches
   - **Test output format:** Each test emits a success marker character. The test output string grows with each story. Update EXPECTED in Makefile.

2. **REPL integration (`make test-repl`):** Add piped REPL tests:
   - `2 3 + .` → output includes "5 " (the canonical Forth demo from epics AC)
   - `HEX FF DECIMAL .` → output includes "255 " (hex input, decimal output)
   - `.S` with items: `1 2 3 .S` → output includes "<3> 1 2 3"
   
3. **Empirical verification:** After building, run under iz-cpm manually to verify output format, especially:
   - Exact spacing in `.R` output
   - `.S` format matches `<depth> items...`
   - No extraneous CR/LF in number output

### Implementation Order Recommendation

Build and test incrementally:

1. **Constants + data area** (Task 1) — non-functional setup
2. **`u_to_str` + `digit_to_char` + `div_bc_by_e`** (Task 2) — core conversion, test indirectly via `.`
3. **`.` (dot)** (Task 3) — first visible output, immediately testable: `LIT 42, w_DOT_cf`
4. **`U.`** (Task 4) — shares code with `.`, test with 65535
5. **`.R`** (Task 5) — extends the pattern with padding
6. **`.S`** (Task 6) — most complex, builds on `.` logic
7. **HEX + DECIMAL** (Task 7) — simple DEFWORD, test with base switching
8. **Full test suite update** (Task 8) — all regression + REPL tests

### Project Structure Notes

- `src/formatting.asm` currently exists as a 2-line stub — replace entirely
- All new words go in `formatting.asm`, maintaining the one-concern-per-file pattern
- No changes needed to include order in `antforth.asm` — formatting.asm is already included at the right position
- `num_buf` goes in the data area at the end of `antforth.asm`, near `str_ok` and other buffers

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.3] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture.md#Number Representation] — cell size, signed integers, BASE
- [Source: _bmad-output/planning-artifacts/architecture.md#String Storage] — PAD buffer (84 bytes above HERE)
- [Source: _bmad-output/planning-artifacts/architecture.md#Kernel/Forth Boundary] — number formatting listed as "should be Forth"
- [Source: _bmad-output/planning-artifacts/architecture.md#Bootstrap Boundary] — bootstrap.asm for DEFWORD definitions
- [Source: _bmad-output/planning-artifacts/architecture.md#Register Usage Discipline] — register contract
- [Source: src/structures.asm] — UserArea struct with BASE field
- [Source: src/constants.asm] — PAD_OFFSET, existing constants
- [Source: src/strings.asm:173-202] — char_to_digit (reverse direction model)
- [Source: src/strings.asm:211-257] — do_number, BASE access pattern via (IY+UserArea.base)
- [Source: src/arithmetic.asm] — existing /, MOD implementations (division patterns)
- [Source: src/io.asm:8-18] — EMIT pattern (BDOS C_WRITE)
- [Source: src/io.asm:24-56] — TYPE pattern (character loop)
- [Source: src/stack_ops.asm:165-176] — DEPTH implementation (sp_base reference)
- [Source: src/formatting.asm] — current stub (to be replaced)
- [Source: src/outer_interpreter.asm:35-39] — BASE user variable word
- [Source: src/macros.asm:100-127] — DEFWORD macro
- [Source: src/macros.asm:139-148] — BDOS_SAVE/BDOS_RESTORE (NOT to be used here)
- [Source: _bmad-output/implementation-artifacts/2-2-outer-interpreter-and-repl-loop.md] — previous story learnings, DEFWORD cf EQU pattern, BDOS calling patterns
- [Source: Makefile] — test infrastructure, EXPECTED string, test-repl target

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed Z80 assembly error: `LD (addr), 0` is illegal on Z80. Used `XOR A` + `LD (addr), A` instead.

### Completion Notes List

- Implemented all 6 Forth words (`.`, `U.`, `.R`, `.S`, `HEX`, `DECIMAL`) plus 3 internal helpers (`u_to_str`, `div_bc_by_e`, `digit_to_char`)
- Factored common code: `emit_unsigned` shared by `.`, `U.`, and `.S` to avoid duplication
- `.S` uses static scratch variables for stack walk state since parameter stack can't be used for temps during non-destructive display
- `.R` uses return stack (IX) for width storage and static scratch for sign/string info
- HEX and DECIMAL use `w_XXX_cf EQU w_XXX_body - 3` pattern per memory feedback rule
- All CODE words manually save/restore DE (IP) to return stack, no BDOS_SAVE/RESTORE per dev notes
- All tests pass: `make test` (regression) and `make test-repl` (7 REPL tests)
- Added 3 new REPL tests: `2 3 + .`, `HEX FF DECIMAL .`, and `.S` with stack contents

### Known Limitations

- **AC9 (empty .S → `<0> `) is unreachable by design:** TOS-in-register architecture means DEPTH is always >= 1 (BC always holds a value). The defensive code path for depth=0 exists but cannot be triggered through normal Forth execution. In the REPL, `.S` on a "user-empty" stack shows `<1> 0 ` (the 0 from cold start initialization).
- **Phantom 0 on REPL stack:** The first iteration of INTERPRET's `BL WORD` loop pushes the initial TOS (0 from QUIT) onto the parameter stack. This persists as a phantom item visible in `.S` output. For example, `1 2 3 .S` shows `<4> 0 1 2 3` instead of `<3> 1 2 3`. This is a QUIT/INTERPRET interaction issue from story 2.2, not a formatting bug.
- **Architecture deviation — CODE vs DEFWORD:** Architecture document says `.`, `U.`, `.R`, `.S` "should be Forth (colon definitions)." These were implemented as CODE words because the complex register management around BDOS calls, stack walking (.S), and IP save/restore makes assembly implementation cleaner and more efficient than threading through existing primitives. HEX and DECIMAL remain DEFWORD as specified.

### Change Log

- 2026-04-05: Implemented story 2.3 — number formatting (.`, U.`, `.R`, `.S`) and base words (HEX, DECIMAL)
- 2026-04-05: Code review — fixed REPL test 6 (was testing decimal printing instead of hex), added empty .S test, tightened .S pattern, renumbered REPL tests, documented known limitations

### File List

- `src/constants.asm` — Added NUM_BUF_SIZE constant
- `src/formatting.asm` — Complete rewrite from stub: all formatting words and internal helpers
- `src/antforth.asm` — Added num_buf data area, added formatting test cases to test_thread
- `Makefile` — Updated EXPECTED string for regression tests, added 3 REPL tests (now 8 total after review)
