# Story 6.6: Register Word Recognizer

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want the 32 individual DEFCODE register/condition-code dictionary entries replaced with a single recognizer checked during INTERPRET,
so that the binary shrinks by ~130-140 bytes without any change in assembler behaviour.

## Acceptance Criteria

1. **Given** the 32 DEFCODE register words currently in `src/assembler.asm:857-1092` **When** they are replaced by a compact lookup table + recognizer word **Then** `make test && make test-repl` passes all regression tests with zero failures.

2. **Given** the recognizer is inserted into the INTERPRET loop in `src/outer_interpreter.asm` **When** `asm_mode == 0` (normal Forth, outside CODE..END-CODE) **Then** the recognizer fast-fails immediately, adding zero observable overhead to normal interpretation.

3. **Given** both changes land **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 80 bytes smaller than the pre-story baseline (14,584 bytes).

4. **Given** register words are no longer dictionary entries **When** `WORDS` is executed **Then** register names no longer appear (acceptable — they only work inside CODE blocks).

5. **Given** the recognizer handles all 32 register/condition words **When** any existing assembler test exercises register operands **Then** behaviour is identical to the dictionary-based approach (same tag values pushed).

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #3)
  - [x] 0.1 `make asm && wc -c build/antforth.com` — confirm 14,584 bytes ✅
  - [x] 0.2 `make test && make test-repl` — confirm all tests pass (1 asm PASS, 265 REPL PASS) ✅

- [x] Task 1: Create the compact register lookup table (AC: #1, #5)
  - [x] 1.1 Add `asm_reg_table` in `src/assembler.asm` — format: `DB name_len, "NAME", tag_byte` per entry, terminated by `DB 0` ✅
  - [x] 1.2 Include all 32 entries: 7 REG8 + 8 REG16 + 7 INDIRECT + 2 extended REG8 + 8 COND ✅
  - [x] 1.3 Do NOT include `()` or `#` — they have unique stack-manipulation bodies and must remain as DEFCODE entries ✅
  - [x] 1.4 Verify table size (~137 bytes) by assembling ✅ (14721 - 14584 = 137 bytes)

- [x] Task 2: Create `w_ASM_RECOGNIZE` DEFCODE word (AC: #1, #2, #5)
  - [x] 2.1 Implement as DEFCODE with signature `( c-addr -- value true | c-addr false )` ✅
  - [x] 2.2 Fast-fail: `LD A, (asm_mode) / OR A / JR Z, .recog_fast_false` — zero overhead outside CODE ✅
  - [x] 2.3 Load counted string from c-addr (first byte = length) ✅
  - [x] 2.4 Scan `asm_reg_table`: for each entry, compare length then name bytes (case-insensitive using UPPER macro) ✅
  - [x] 2.5 If match: push tag as `0xFFxx` (B=0xFF, C=tag_byte), push TRUE, NEXT ✅
  - [x] 2.6 If no match: leave c-addr on stack, push FALSE, NEXT ✅
  - [x] 2.7 Assemble and verify word compiles (~124 bytes body + scratch, no dictionary header) ✅

- [x] Task 3: Insert recognizer into INTERPRET loop (AC: #1, #2)
  - [x] 3.1 Modify `src/outer_interpreter.asm` at `.try_number` ✅
  - [x] 3.2 After `w_DROP_cf`, before `w_NUMBER_Q_cf`: ASM_RECOGNIZE + QBRANCH + BRANCH to share number path ✅
  - [x] 3.3 If true, share the existing number/STATE handling path via .got_value label ✅
  - [x] 3.4 `make asm` — assembly succeeds with both old DEFCODE entries AND new recognizer ✅
  - [x] 3.5 `make test && make test-repl` — all 265+1 tests pass ✅

- [x] Task 4: Remove 32 DEFCODE entries + shared tails (AC: #1, #4)
  - [x] 4.1 Remove `asm_push_tag` and `asm_push_cond_tag` shared tails ✅
  - [x] 4.2 Remove all 7 REG8 DEFCODE words (w_REG_B through w_REG_A) ✅
  - [x] 4.3 Remove all 8 REG16 DEFCODE words (w_REG_BC through w_REG_AFP) ✅
  - [x] 4.4 Remove 7 INDIRECT DEFCODE words (w_REG_IHL through w_REG_IDE) — kept `()` ✅
  - [x] 4.5 Remove 2 extended REG8 words (w_REG_I/IREG, w_REG_R/RREG) ✅
  - [x] 4.6 Remove 8 COND DEFCODE words (w_COND_NZ through w_COND_M) ✅
  - [x] 4.7 Kept `w_HASH` and `w_ABS_PAREN` — unique bodies ✅
  - [x] 4.8 `make asm && make test && make test-repl` — all 265+1 tests pass ✅
  - [x] 4.9 `wc -c build/antforth.com` — 14,498 bytes (86 bytes saved) ✅

- [x] Task 5: Add REPL regression tests (AC: #5)
  - [x] 5.1 Add REPL tests 259-262 verifying register words produce correct tags inside CODE blocks ✅
  - [x] 5.2 Test case-insensitivity: test 261 verifies `b a LD,` == `B A LD,` ✅
  - [x] 5.3 Test 263 verifies register words outside CODE fail gracefully with `<word> ?` error; updated tests 128-129 for new error format ✅
  - [x] 5.4 [AI-Review] Test 264 verifies (HL) via recognizer inside CODE: `(HL) INC,` = 0x34 ✅
  - [x] 5.5 [AI-Review] Test 265 verifies AF' via recognizer inside CODE: `AF AF' EX,` = 0x08 ✅

- [x] Task 6: Final verification (AC: #3)
  - [x] 6.1 `make test && make test-repl` — all tests green (1 asm + 272 REPL) ✅
  - [x] 6.2 `wc -c build/antforth.com` — 14,498 bytes, savings = 14,584 - 14,498 = 86 bytes ✅
  - [x] 6.3 Verify savings >= 80 bytes — 86 ≥ 80 ✅

## Dev Notes

### Architecture: Recognizer Design

The recognizer is a native-code (DEFCODE) word inserted into the INTERPRET thread. It acts as a fallback between FIND and NUMBER?:

```
INTERPRET loop:
  BL WORD → c-addr
  FIND → ( c-addr 0 | xt flag )
  if found → execute/compile
  if not found:
    DROP (the 0)
    ASM_RECOGNIZE → ( value true | c-addr false )   ← NEW
    if true → treat value like a number (STATE check, compile LIT if needed)
    if false:
      NUMBER? → ( n true | c-addr false )
      ...existing path...
```

### Stack Protocol

The recognizer follows the same two-result signature as NUMBER?:
- **Match**: `( c-addr -- tag-value true )` — c-addr consumed, tag pushed
- **No match**: `( c-addr -- c-addr false )` — c-addr preserved for NUMBER?

Tag values are 16-bit: `B = 0xFF` (ASM_TAG_HI), `C = class|index byte`.

### Compact Table Format

```
asm_reg_table:
    ; REG8 (class 0x00)
    DB 1, "B", 0x00
    DB 1, "C", 0x01
    DB 1, "D", 0x02
    DB 1, "E", 0x03
    DB 1, "H", 0x04
    DB 1, "L", 0x05
    DB 1, "A", 0x07
    ; REG16 (class 0x60)
    DB 2, "BC", 0x60
    DB 2, "DE", 0x61
    DB 2, "HL", 0x62
    DB 2, "AF", 0x63
    DB 2, "SP", 0x64
    DB 2, "IX", 0x65
    DB 2, "IY", 0x66
    DB 3, "AF'", 0x67
    ; INDIRECT (class 0x80)
    DB 4, "(HL)", 0x80
    DB 4, "(IX)", 0x81
    DB 4, "(IY)", 0x82
    DB 4, "(SP)", 0x85
    DB 3, "(C)", 0x86
    DB 4, "(BC)", 0x87
    DB 4, "(DE)", 0x88
    ; Extended REG8
    DB 4, "IREG", 0x08
    DB 4, "RREG", 0x09
    ; COND (class 0x20)
    DB 2, "NZ", 0x20
    DB 1, "Z", 0x21
    DB 2, "NC", 0x22
    DB 2, "CS", 0x23
    DB 2, "PO", 0x24
    DB 2, "PE", 0x25
    DB 1, "P", 0x26
    DB 1, "M", 0x27
    DB 0                ; sentinel
```

**Table size**: 7×(1+1+1) + 7×(1+2+1) + 1×(1+3+1) + 7×(1+4+1) + 2×(1+4+1) + 1×(1+3+1) + 6×(1+2+1) + 2×(1+1+1) + 1 = **~137 bytes**

### Recognizer Pseudocode (Z80 native)

```asm
w_ASM_RECOGNIZE:
        DEFCODE "ASM-RECOGNIZE", 0
w_ASM_RECOGNIZE_cf:
        ; ( c-addr -- value true | c-addr false )
        ; Fast-fail if not in assembler mode
        LD      A, (asm_mode)
        OR      A
        JR      Z, .recog_false

        ; BC = c-addr (TOS). Load counted string.
        LD      H, B
        LD      L, C            ; HL = c-addr
        LD      A, (HL)         ; A = name length from counted string
        LD      D, A            ; D = search length
        INC     HL              ; HL = start of name chars
        PUSH    HL              ; save name pointer for table scan
        PUSH    DE              ; save D (length)

        ; Scan table
        LD      HL, asm_reg_table
.recog_next:
        LD      A, (HL)         ; table entry length
        OR      A
        JR      Z, .recog_miss  ; sentinel — no match

        ; Compare lengths
        CP      D               ; entry length vs search length
        JR      NZ, .recog_skip ; length mismatch

        ; Lengths match — compare name bytes (case-insensitive)
        PUSH    HL              ; save table position
        INC     HL              ; point to table name
        ; ... compare D bytes with UPPER on both sides ...
        ; if match: pop/clean stack, push tag, push TRUE, NEXT
        ; if mismatch: pop table position, skip entry

.recog_skip:
        ; Advance HL past this entry: HL += 1 (len already read) + entry_len + 1 (tag)
        INC     HL              ; skip len byte (already at it)
        ADD     A, L / LD L, A / JR NC, $+3 / INC H  ; HL += name_len
        INC     HL              ; skip tag byte
        JR      .recog_next

.recog_miss:
        ; Restore original c-addr and push FALSE
        POP     DE
        POP     HL              ; discard saved name pointer
        ; BC still = c-addr (never modified)
        PUSH    BC              ; push c-addr as TOS
        LD      BC, 0           ; FALSE
        NEXT

.recog_found:
        ; HL points to tag byte after successful name match
        LD      C, (HL)         ; C = tag byte
        POP     DE              ; discard saved values
        POP     HL
        PUSH    BC              ; push old TOS (c-addr, don't need it)
        LD      B, ASM_TAG_HI   ; B = 0xFF
        ; Now need to push TRUE on top
        ; ... (push BC as tag value, then push TRUE)
```

**Note**: The pseudocode above is approximate. The dev agent should implement the actual byte-efficient Z80 code. Key constraints:
- BC = TOS (Forth calling convention)
- PUSH BC saves old TOS, new TOS goes in BC
- Need to push both the tag value AND a true flag — that's two stack items replacing one (c-addr)
- On match: stack goes from `( c-addr )` to `( tag-value true )` — need PUSH twice
- On miss: stack stays `( c-addr false )` — need one PUSH for false

### Behaviour Change: Error Message Outside CODE

**Current behaviour**: Typing `BC` outside CODE produces "not in CODE ?" (from `check_asm_mode`).

**New behaviour**: Typing `BC` outside CODE → recognizer returns false (asm_mode==0) → falls to NUMBER? → not a number → prints "BC ?" error.

This is an acceptable trade-off per the epic spec. The error is still caught; only the message differs. If preserving the exact error message is desired, the recognizer could check asm_mode only AFTER a table match (but this adds ~2 bytes per lookup to the hot path).

### Words NOT Removed (Unique Bodies)

1. **`()` (w_ABS_PAREN)** — lines 997-1005: Wraps TOS as indirect-memory tag. Has `PUSH BC` then sets BC to tag. The recognizer can't replicate this because it doesn't know the address value already on stack.

2. **`#` (w_HASH)** — lines 1023-1030: Marks TOS as immediate value. Same issue — wraps existing TOS with tag on top.

Both remain as DEFCODE dictionary entries.

### Byte Budget

| Component | Estimated | Actual |
|---|---|---|
| **Removed**: 32 DEFCODE entries (headers + bodies) | -343 | -343 |
| **Removed**: `asm_push_tag` shared tail | -6 | -6 |
| **Removed**: `asm_push_cond_tag` shared tail | -8 | -8 |
| **Added**: `w_ASM_RECOGNIZE` body + scratch (no header) | +65 est | +124 |
| **Added**: `asm_reg_table` compact table | +137 | +137 |
| **Added**: INTERPRET thread modification (5 DW entries) | +6 est | +10 |
| **Net savings** | **~149 est** | **86 actual** |

Estimation miss: recognizer body was ~2x larger than pseudocode suggested (DE save/restore, scratch variables, full comparison loop with UPPER). AC threshold (80 bytes) still met.

### Tag Encoding Reference (from story 6.5)

```
ASM_TAG_HI          = 0xFF    (high byte of all tags)
ASM_CLASS_MASK      = 0xE0    (top 3 bits of low byte)
ASM_INDEX_MASK      = 0x1F    (bottom 5 bits of low byte)
ASM_CLASS_REG8      = 0x00    ASM_CLASS_COND     = 0x20
ASM_CLASS_IMM       = 0x40    ASM_CLASS_REG16    = 0x60
ASM_CLASS_INDIRECT  = 0x80    ASM_CLASS_LABEL    = 0xA0
```

### INTERPRET Insertion Detail

Inserted between FIND failure and NUMBER? in `src/outer_interpreter.asm`. The shared-path design avoids duplicating number/STATE handling:

```asm
.try_number:
        DW      w_DROP_cf               ; ( c-addr 0 -- c-addr )
        DW      w_ASM_RECOGNIZE_cf      ; ( c-addr -- value true | c-addr false )
        DW      w_QBRANCH_cf
        DW      .try_real_number - $    ; if false, try NUMBER?
        DW      w_BRANCH_cf
        DW      .got_value - $          ; if true, share number handling
.try_real_number:
        DW      w_NUMBER_Q_cf           ; ( c-addr -- n true | c-addr false )
        DW      w_QBRANCH_cf
        DW      .not_number - $
.got_value:
        ; Stack: ( value ) — from recognizer or NUMBER?
        DW      w_STATE_cf              ; existing number handling path
        ...
```

This adds **10 bytes** to the INTERPRET thread (5 DW entries = 10 bytes: ASM_RECOGNIZE_cf, QBRANCH, offset, BRANCH, offset).

### Case Sensitivity

The UPPER macro (in `src/macros.asm:14-24`) converts lowercase a-z to uppercase. The recognizer table stores names in uppercase. During comparison, apply UPPER to the input character before comparing. This matches FIND's behaviour.

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Previous Story Learnings (6.5)

- Handler merges using H as opcode parameter worked cleanly
- `asm_emit_byte` clobbers HL — be aware when using HL as temp
- Build-test-verify after each task catches issues early
- Record baseline size before any changes
- sjasmplus local label scoping: `.label` is scoped per parent label
- NEXT macro expands to 7 bytes
- All 265 REPL tests + assembly tests should pass at each checkpoint

### Project Structure Notes

- `src/assembler.asm` — remove 32 DEFCODE entries, add recognizer + table
- `src/outer_interpreter.asm` — insert recognizer call in INTERPRET thread
- `src/macros.asm` — UPPER macro (reference only, no changes needed)
- `src/dictionary.asm` — FIND case-insensitive comparison (reference for pattern)
- No other files need modification

### References

- [Source: src/assembler.asm:848-1092] — Current register DEFCODE entries to remove
- [Source: src/assembler.asm:997-1005] — () word (keep)
- [Source: src/assembler.asm:1023-1030] — # word (keep)
- [Source: src/assembler.asm:140-171] — Tag encoding constants
- [Source: src/assembler.asm:448-454] — check_asm_mode helper
- [Source: src/assembler.asm:76] — asm_mode variable
- [Source: src/outer_interpreter.asm:141-220] — INTERPRET thread
- [Source: src/outer_interpreter.asm:185-190] — .try_number insertion point
- [Source: src/macros.asm:14-24] — UPPER macro
- [Source: src/macros.asm:62-94] — DEFCODE macro structure
- [Source: src/dictionary.asm:85-104] — FIND case-insensitive comparison pattern
- [Source: _bmad-output/planning-artifacts/epic6-code-size-optimization.md#Story 6.6] — Epic specification
- [Source: _bmad-output/implementation-artifacts/6-5-ld-dispatch-table.md] — Previous story

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- DE clobber bug: recognizer used DE as scratch for name comparison, corrupting the threaded IP. Fixed by saving/restoring DE in scratch variable.
- QBRANCH skip bug: `.recog_cmp_fail` used DJNZ-decremented B to skip remaining bytes but POP'd back to entry start. Fixed by re-reading entry length from table.
- Size optimization: removed DEFCODE dictionary header (not needed), merged skip paths, removed unnecessary empty-name check to reach 86-byte savings.

### Completion Notes List

- Replaced 32 DEFCODE register/condition-code dictionary entries with compact 137-byte lookup table + recognizer
- Recognizer inserted between FIND and NUMBER? in INTERPRET loop with zero overhead outside CODE blocks (fast-fail on asm_mode=0)
- Case-insensitive matching via UPPER macro, consistent with FIND behaviour
- Kept () and # as DEFCODE entries (unique stack-manipulation bodies)
- Behaviour change: register words outside CODE now produce "<word> ?" instead of "not in CODE ?" — acceptable per epic spec
- Updated tests 128-129 for new error message format
- Added 7 new REPL regression tests (259-265): register tags, case insensitivity, outside-CODE error recovery, indirect registers, AF' apostrophe handling
- Binary size: 14,584 → 14,498 = 86 bytes saved (AC threshold: 80)

### File List

- src/assembler.asm — added asm_reg_table (compact lookup), w_ASM_RECOGNIZE_cf (recognizer), removed 32 DEFCODE entries + shared tails
- src/outer_interpreter.asm — inserted recognizer call between DROP and NUMBER? in INTERPRET loop
- Makefile — updated tests 128-129 for new error messages, added tests 259-263
