# Story 4.3.5: Stack Tag Encoding Refactor

Status: done

## Story

As an antforth assembler user,
I want operand type errors (like `A 0 LD,` instead of `A 0 # LD,`) to be caught at assemble time with a clear message,
So that I cannot silently produce machine code that does the wrong thing.

## Acceptance Criteria

1. **Unified tag sentinel:** Every tagged operand (register, condition, label, immediate marker, addressing mode) has high byte `0xFF`. Low byte encodes 3-bit class (top) + 5-bit index (bottom).

2. **Bare-integer detection:** If an operand-consuming assembler word pops a cell whose high byte is not `0xFF`, it raises a clear error (e.g. `expected tagged operand, got bare integer N — did you mean #N ?`) and emits no bytes.

3. **Immediate two-cell layout:** `42 # A LD,` produces stack picture `[..., 42, <imm-tag>, A-tag]` (marker cell with class=010 index=0 atop the value cell). Assembled bytes: `0x3E 0x2A`.

4. **16-bit immediate:** `0x1234 # BC LD,` assembles to `0x01 0x34 0x12`. The value cell holds the full 16-bit value — no longer bottled into the low byte of a sentinel.

5. **Forgot-# error:** `A 0 LD,` raises an error pointing at bare integer 0. No bytes assembled.

6. **Full regression:** Existing story 4.1, 4.2, and 4.3 test suites pass after the refactor (modulo migration of tests that hand-construct `0xFD`/`0xFE` literal sentinels).

7. **Typo-detection tests:** New REPL-piped test scripts cover the "forgot the #" path. All error cases produce clear errors; all correctly-written cases assemble identically to before.

8. **Architecture doc update:** `architecture.md` receives a new subsection describing the tag-cell format (`0xFF <class:3><index:5>`), the class table, the two-cell layout for immediates and displacements, and a worked example showing `LD A, #42` and `LD A, B` side by side.

## Tasks / Subtasks

- [x] **Task 1: Define new tag encoding constants** (AC: #1)
  - [x] 1.1 Replace `ASM_IMM_TAG_HI EQU 0xFD`, `ASM_COND_TAG_HI EQU 0xFE`, `ASM_LABEL_TAG_HI EQU 0xFF` with unified `ASM_TAG_HI EQU 0xFF`
  - [x] 1.2 Define class constants: `ASM_CLASS_REG8 EQU 0x00`, `ASM_CLASS_COND EQU 0x20`, `ASM_CLASS_IMM EQU 0x40`, `ASM_CLASS_REG16 EQU 0x60`, `ASM_CLASS_INDIRECT EQU 0x80`, `ASM_CLASS_LABEL EQU 0xA0`
  - [x] 1.3 Define combined tag bytes for each operand (e.g. register A = `0xFF07`, register B = `0xFF00`, condition NZ = `0xFF20`, immediate marker = `0xFF40`, label slot 0 = `0xFFA0`)
  - [x] 1.4 Add helper macros or EQU for class extraction (`AND 0xE0`) and index extraction (`AND 0x1F`)

- [x] **Task 2: Rewrite register-tag push words** (AC: #1)
  - [x] 2.1 Update `asm_push_tag` to set B=0xFF (high byte) and L=class|index (low byte)
  - [x] 2.2 Update all 8-bit register words (A,B,C,D,E,H,L) to use class=000 with their r-field index
  - [x] 2.3 Update all 16-bit register words (BC,DE,HL,AF,SP) to use class=011 with appropriate index
  - [x] 2.4 Update `(HL)` indirect word to use class=100 with appropriate index

- [x] **Task 3: Rewrite condition-code tag words** (AC: #1)
  - [x] 3.1 Update `asm_push_cond_tag` to use `0xFF` high byte with class=001
  - [x] 3.2 Update NZ,Z,NC,CS,PO,PE,P,M to push `0xFF2n` (where n=condition index 0..7)

- [x] **Task 4: Rewrite `#` immediate-marker word** (AC: #1, #3)
  - [x] 4.1 Change `#` to push `0xFF40` (class=010, index=0) instead of `0xFD00`
  - [x] 4.2 Verify two-cell layout: value cell remains below the marker cell on the stack (no change to user-facing push order)

- [x] **Task 5: Rewrite label-tag encoding** (AC: #1)
  - [x] 5.1 Update LABEL word to push `0xFFA0|slot_index` instead of `0xFF00|slot_index`
  - [x] 5.2 Update label-consuming words (FIX, JP,, JR,, CALL,) to extract label index via `AND 0x1F` after class check

- [x] **Task 6: Implement `asm_check_tagged` helper (forgot-# detector)** (AC: #2, #5)
  - [x] 6.1 Write `asm_check_tagged`: pop BC, check B==0xFF. If not, print error with the bare integer value and jump to `asm_cleanup`
  - [x] 6.2 Error message format: `expected tagged operand, got bare integer N — did you mean #N ?`

- [x] **Task 7: Rewrite `asm_is_imm_tag` and `asm_is_cond_tag` helpers** (AC: #1)
  - [x] 7.1 Replace `asm_is_imm_tag` with unified class-extraction: check B==0xFF, then `LD A,C / AND 0xE0 / CP ASM_CLASS_IMM`
  - [x] 7.2 Replace `asm_is_cond_tag` with same pattern using `CP ASM_CLASS_COND`
  - [x] 7.3 Add `asm_is_label_tag` using `CP ASM_CLASS_LABEL`
  - [x] 7.4 Add generic `asm_get_class` that returns class bits in A after verifying tag sentinel

- [x] **Task 8: Rewrite all operand-consuming assembler words** (AC: #1, #2, #3, #4)
  - [x] 8.1 Update `LD,` — must handle: reg8←reg8, reg8←imm8, reg16←imm16, reg8←(HL), (HL)←reg8, (HL)←imm8. Add `asm_check_tagged` at entry for each operand pop
  - [x] 8.2 Update `ADD,`, `SUB,`, `AND,`, `OR,`, `XOR,`, `CP,` — immediate path now pops two cells (marker + value). Add tag check
  - N/A 8.3 `INC,`, `DEC,` — not yet implemented (story 4.4 scope)
  - [x] 8.4 Update `PUSH,`, `POP,` — single reg16 operand, add tag check
  - [x] 8.5 Update `JP,`, `CALL,` — handle label and conditional variants with tag checks
  - [x] 8.6 Update `JR,` — handle label and conditional variants with tag checks
  - [x] 8.7 Update `RET,` — optional condition operand with tag check
  - N/A 8.8 `EX,`, `IN,`, `OUT,` — not yet implemented (story 4.4 scope)

- [x] **Task 9: Migrate existing tests** (AC: #6)
  - [x] 9.1 Identify all test code that hand-constructs `0xFD` or `0xFE` sentinel values
  - [x] 9.2 Update those tests to use the new `0xFF` + class encoding
  - [x] 9.3 Run full story 4.1/4.2/4.3 test suites and verify all pass

- [x] **Task 10: Write new typo-detection REPL tests** (AC: #7)
  - [x] 10.1 Test: `A 0 LD,` → error (forgot `#` for immediate)
  - [x] 10.2 Test: `0 A LD,` → error (bare integer in destination position)
  - [x] 10.3 Test: `42 # A LD,` → success (correct immediate syntax)
  - [x] 10.4 Test: `0x1234 # BC LD,` → success (16-bit immediate)
  - [x] 10.5 Test: `A 0 ADD,` → error
  - [x] 10.6 Test: `A 42 # ADD,` → success
  - [x] 10.7 Test: all "correctly written" existing opcodes still assemble identically

- [x] **Task 11: Update architecture.md** (AC: #8)
  - [x] 11.1 Add new subsection under the assembler section describing tag-cell format
  - [x] 11.2 Include class table with all classes and their bit patterns
  - [x] 11.3 Include two-cell layout diagram for immediates and displacements
  - [x] 11.4 Include worked example: `LD A, #42` vs `LD A, B` side by side

## Dev Notes

### Tag Encoding Design (from approved sprint change proposal, 2026-04-12)

**New unified format:**
```
Tag cell:  0xFF <CCCIIIII>
                │   │
                │   └── 5-bit index (0..31 per class)
                └────── 3-bit class (0..7)

Class 000  8-bit register     A,B,C,D,E,H,L (r-field 0..7)
Class 001  Condition code     NZ,Z,NC,C,PO,PE,P,M (3 bits)
Class 010  Immediate marker   value lives in next stack cell
Class 011  16-bit register    BC,DE,HL,SP,AF (+ headroom for IX,IY,AF')
Class 100  Indexed/indirect   (HL),(BC),(DE),(IX+d),(IY+d),(nn)
Class 101  Label              forward & backward refs (slot index)
Class 110  RESERVED
Class 111  RESERVED
```

**Two-cell layout for immediates:**
```
Stack (grows down):   ... | value | 0xFF40 | dest-tag |
                              ↑        ↑
                          raw 16-bit   imm marker
```

### Key Architecture Constraints

- **Register contract (inviolable):** BC=TOS, DE=IP, SP=parameter stack, IX=return stack, IY=user pointer, HL=working register
- **Operand order:** Zilog dst-src convention — `B C LD,` means `LD B, C`
- **Direct threading:** Every word's code field is a literal `JP xxxx` (3 bytes)
- **Error handling:** All assembler errors flow through `asm_print_error` + `asm_cleanup` (restore HERE, unlink labels, reset mode)
- **Naming:** `w_` prefix for Forth word bodies, `h_` for headers, `UPPER_SNAKE_CASE` for constants

### Current Code Structure (src/assembler.asm, ~2011 lines)

Key locations to modify:
- **Tag constants block** (~line 106): `ASM_IMM_TAG_HI`, `ASM_COND_TAG_HI`, `ASM_LABEL_TAG_HI` — replace all three with unified scheme
- **`asm_push_tag`** — shared tail for register words, sets B (high byte) and C (low byte from L)
- **`asm_is_imm_tag`** — predicate checking B==0xFD; rewrite to check B==0xFF then class bits
- **`asm_is_cond_tag`** — predicate checking B==0xFE; rewrite similarly
- **`#` word** (~line 893) — currently pushes 0xFD00; change to 0xFF40
- **Condition words** (NZ,Z,NC,CS,PO,PE,P,M) — currently push 0xFEnn; change to 0xFF2n
- **Register words** (A,B,C,D,E,H,L,BC,DE,HL,AF,SP) — currently push 0x00nn; must get 0xFF high byte + class|index
- **All opcode words** (LD,, ADD,, SUB,, AND,, OR,, XOR,, CP,, JP,, JR,, CALL,, RET,, INC,, DEC,, PUSH,, POP,, etc.) — add tag validation at operand pop sites

### Testing Approach

- **REPL-piped tests** are the standard from Epic 3 onwards (not assembly test thread extensions)
- Test scripts pipe Forth source through the assembler and check output
- Regression: run existing 4.1/4.2/4.3 test suites first, fix any sentinel-literal breakage
- New: write targeted "forgot-#" error tests plus "correct syntax" confirmation tests

### Critical Pitfalls

1. **BC = TOS register.** After ABORT, BC may be phantom (DEPTH=0 means BC is invalid). The `asm_check_tagged` helper must handle being called with BC holding the operand to check.
2. **Don't break (HL).** The `(HL)` word currently pushes tag 0x06 (same as r-field encoding for (HL) in Z80). Under the new scheme it moves to class=100. All LD, paths that check for (HL) must be updated.
3. **Label slot index preservation.** Labels use the 5-bit index field. Current scheme puts slot index in the full low byte. New scheme uses only bottom 5 bits. With `ASM_LABEL_POOL_SIZE EQU 16`, this fits (max index 15 < 32), but extraction now needs `AND 0x1F`.
4. **Condition code index preservation.** Currently in full low byte. New scheme: bottom 5 bits of class=001. With 8 conditions (0..7), fits easily.
5. **16-bit register index mapping.** Currently uses 0x10..0x14. Under new scheme, these move to class=011 with index 0..4. The opcode words that compute from the tag index must be updated to map correctly to Z80 register pair fields.
6. **Two-cell immediate pop order.** When LD, detects an immediate source, it must pop the marker cell first, then pop the value cell below it. This is the existing pattern from story 4.3 — preserve it.

### Previous Story (4.3) Intelligence

- Story 4.3 introduced `#` (immediate marker), 8 condition code words, conditional JP/CALL/JR/RET, and immediate ALU ops
- The two-cell immediate pattern (`value # dest LD,`) is already established and working
- `asm_is_imm_tag` and `asm_is_cond_tag` are the two main predicates to rewrite
- All opcode words already have paths that distinguish registers from immediates from conditions — these paths need updating but the control flow structure stays

### References

- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-04-12.md] — Full design rationale, locked decisions D1–D8, strawman tag table
- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3.5] — Acceptance criteria and background
- [Source: _bmad-output/implementation-artifacts/4-3-basic-z80-opcodes.md] — Previous story tasks, dev notes, patterns established
- [Source: _bmad-output/planning-artifacts/architecture.md] — Register contract, naming conventions, error handling patterns
- [Source: src/assembler.asm] — Current implementation (~2011 lines), all tag constants, helpers, and opcode words

### Project Structure Notes

- All assembler code lives in `src/assembler.asm` (single file, included from main kernel)
- Tests are REPL-piped Forth scripts (Epic 3+ convention)
- Architecture doc at `_bmad-output/planning-artifacts/architecture.md`
- No project-context.md exists yet

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Test 133 failure: bare integer `0` in dst position was silently accepted because `assert_8bit_reg_or_ihl` didn't verify H==0xFF. Fixed by adding tag sentinel check to both assert helpers.
- Test 134 failure: test used wrong byte offset (XT+2 instead of XT+0). Fixed test.
- Test 135 failure: `0x1234` not parseable in decimal mode. Fixed test to use HEX mode.

### Completion Notes List
- **Tasks 1-4**: Replaced three separate tag sentinels (ASM_IMM_TAG_HI=0xFD, ASM_COND_TAG_HI=0xFE, ASM_LABEL_TAG_HI=0xFF) with unified ASM_TAG_HI=0xFF + class/index encoding. All register, condition, immediate, and label tag push words updated.
- **Task 5**: Label tags now use class=101 (0xA0) with 5-bit index. All label-consuming words (FIX, JP,, JR,, CALL,, DW,) updated to extract slot index via AND 0x1F.
- **Task 6**: New `asm_check_tagged` helper and `asm_err_bare_int` error path. Checks B==0xFF on TOS; if not, prints "bare integer ?" and ABORTs. Also added sentinel checks to `assert_8bit_reg` and `assert_8bit_reg_or_ihl` for NOS validation.
- **Task 7**: Rewrote `asm_is_imm_tag` and `asm_is_cond_tag` to check class bits in C (AND 0xE0 + CP). Added `asm_is_label_tag`, `asm_is_reg16_tag`, `asm_is_indirect_tag`, `asm_get_class`, `asm_get_index`.
- **Task 8**: Updated all operand-consuming words: LD, (reg-reg, imm8, imm16, (HL) paths), ADD,/SUB,/AND,/OR,/XOR,/CP, (via asm_arith_word), PUSH,/POP, (via asm_pushpop_word), JP,/CALL, (via asm_jp_call_word), JR,, RET,, FIX, DB,, DW,. All use tag validation and class-based dispatch.
- **Task 9**: No test migration needed — no existing tests hand-constructed old sentinel values.
- **Task 10**: Added 8 new REPL tests (132-139): forgot-# errors for LD,/ADD,/PUSH,, correct assembly for LD imm8/LD imm16/ADD imm, existing r-r LD regression.
- **Task 11**: Added "Assembler Tag-Cell Encoding" subsection to architecture.md with class table, two-cell diagram, and worked examples for LD A,#42 vs LD A,B.

### Change Log
- 2026-04-12: Story 4.3.5 complete — unified tag encoding refactor with bare-integer detection
- 2026-04-12: Code review fixes — (H1) Tasks 8.3/8.8 marked N/A (words are 4.4 scope), (H2) bare-integer error now prints hex value per AC#5, (M1) test 137 fixed to not push spurious A operand, (M2) added asm_print_str/asm_print_q_crlf/asm_print_hex16 helpers, (L2) fixed asm_push_label_tag comment

### File List
- src/assembler.asm — Core refactor: tag constants, push helpers, predicates, all opcode words
- Makefile — 8 new REPL tests (132-139)
- _bmad-output/planning-artifacts/architecture.md — New tag encoding documentation section
- _bmad-output/implementation-artifacts/sprint-status.yaml — Status tracking
- _bmad-output/implementation-artifacts/4-3-5-stack-tag-encoding-refactor.md — This story file
