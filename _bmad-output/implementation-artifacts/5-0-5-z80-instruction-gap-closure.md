# Story 5.0.5: Z80 Instruction Gap Closure

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth assembler user,
I want every documented Z80 instruction to be assembler-supported,
so that I never need `DB,` workarounds for standard Z80 opcodes.

## Background

Story 5.0's completeness survey found 27 missing instruction forms out of 158 audited (82.9% coverage). This story closes all gaps to reach 100% coverage.

## Acceptance Criteria

1. **Given** the 12 missing single-byte zero-operand instructions **When** assembled in a CODE word **Then** each emits the correct single opcode byte:
   - `NOP,` → 0x00, `HALT,` → 0x76, `DI,` → 0xF3, `EI,` → 0xFB
   - `DAA,` → 0x27, `CPL,` → 0x2F, `SCF,` → 0x37, `CCF,` → 0x3F
   - `RLCA,` → 0x07, `RRCA,` → 0x0F, `RLA,` → 0x17, `RRA,` → 0x1F

2. **Given** the new `ADC,` and `SBC,` words **When** used with register, (HL), immediate, and indexed operands **Then** the correct opcodes are assembled:
   - `B ADC,` → 0x88, `(HL) ADC,` → 0x8E, `0x42 # ADC,` → 0xCE 0x42, `(IX) 5 +D ADC,` → 0xDD 0x8E 0x05
   - `B SBC,` → 0x98, `(HL) SBC,` → 0x9E, `0x42 # SBC,` → 0xDE 0x42, `(IX) 5 +D SBC,` → 0xDD 0x9E 0x05

3. **Given** the missing LD forms **When** assembled **Then** the correct opcodes are produced:
   - Indirect-register: LD A,(BC) / LD A,(DE) / LD (BC),A / LD (DE),A
   - Absolute-address: LD A,(nn) / LD (nn),A / LD HL,(nn) / LD (nn),HL
   - Antforth syntax to be determined during implementation (see Dev Notes for design options)

4. **Given** the missing 16-bit arithmetic **When** assembled **Then** correct opcodes are produced:
   - `HL BC ADD,` → 0x09 (ADD HL,BC), `HL DE ADD,` → 0x19, `HL HL ADD,` → 0x29, `HL SP ADD,` → 0x39
   - `HL BC ADC,` → 0xED 0x4A (ADC HL,BC)
   - `HL BC SBC,` → 0xED 0x42 (SBC HL,BC)
   - `IX BC ADD,` → 0xDD 0x09 (ADD IX,BC)

5. **Given** `DJNZ,` **When** used with a label or literal address **Then** the correct relative jump is assembled:
   - `DJNZ,` → 0x10 dd (signed displacement)
   - Label resolution and forward references work identically to `JR,`

6. **Given** `RST,` **When** used with a restart vector **Then** the correct opcode is assembled:
   - `0 RST,` → 0xC7, `8 RST,` → 0xCF, `0x10 RST,` → 0xD7, `0x18 RST,` → 0xDF
   - `0x20 RST,` → 0xE7, `0x28 RST,` → 0xEF, `0x30 RST,` → 0xF7, `0x38 RST,` → 0xFF
   - Non-standard vector values (not multiples of 8, or > 0x38) produce `bad operand ?`

7. **Given** the missing ED-prefix instructions **When** assembled **Then** correct opcodes are produced:
   - `RLD,` → 0xED 0x6F, `RRD,` → 0xED 0x67
   - `LD A,I` / `LD A,R` / `LD I,A` / `LD R,A` — syntax TBD (see Dev Notes)
   - `ADC HL,rr` / `SBC HL,rr` — covered by AC#4
   - ED-prefix 16-bit memory loads: `LD (nn),BC` / `LD BC,(nn)` etc. — syntax TBD

8. **Given** `ADD IX,rr` and `ADD IY,rr` **When** assembled **Then** the correct DD/FD-prefixed opcodes are produced

9. **Given** `LD IX,(nn)` / `LD (nn),IX` / `LD IY,(nn)` / `LD (nn),IY` **When** assembled **Then** the correct DD/FD-prefixed opcodes are produced

10. **Given** the existing 178 REPL tests and 73 regression tests **When** run after implementation **Then** all pass with zero regressions

11. **Given** new REPL tests for all added instructions **When** `make test-repl` runs **Then** all new tests pass, verifying correct opcode bytes via `C@` inspection

12. **Given** the updated assembler **When** the Z80 completeness survey is re-checked **Then** coverage is 158/158 (100%)

## Tasks / Subtasks

- [x] Task 1: Add 12 single-byte zero-operand words (AC: #1)
  - [x] 1.1 Create shared `asm_emit_single` helper: `check_asm_mode`, emit A, NEXT
  - [x] 1.2 Add `NOP,` (0x00), `HALT,` (0x76), `DI,` (0xF3), `EI,` (0xFB)
  - [x] 1.3 Add `DAA,` (0x27), `CPL,` (0x2F), `SCF,` (0x37), `CCF,` (0x3F)
  - [x] 1.4 Add `RLCA,` (0x07), `RRCA,` (0x0F), `RLA,` (0x17), `RRA,` (0x1F)

- [x] Task 2: Add `ADC,` and `SBC,` (8-bit) (AC: #2)
  - [x] 2.1 Add `ADC,` — reuse `asm_arith_word` with base opcode 0x88
  - [x] 2.2 Add `SBC,` — reuse `asm_arith_word` with base opcode 0x98
  - [x] 2.3 Verify all 4 operand forms work: register, (HL), immediate, indexed

- [x] Task 3: Add 16-bit ADD/ADC/SBC (AC: #4, #8)
  - [x] 3.1 Extend `ADD,` to handle REG16 destination (ADD HL,rr): check if NOS is HL, emit 0x09|(rp<<4)
  - [x] 3.2 Extend `ADC,` to handle REG16 destination (ADC HL,rr): emit ED prefix + 0x4A|(rp<<4)
  - [x] 3.3 Extend `SBC,` to handle REG16 destination (SBC HL,rr): emit ED prefix + 0x42|(rp<<4)
  - [x] 3.4 Extend `ADD,` for ADD IX,rr / ADD IY,rr: emit DD/FD prefix + 0x09|(rp<<4)

- [x] Task 4: Add missing LD forms (AC: #3, #7, #9)
  - [x] 4.1 Design syntax for indirect-register loads (see Dev Notes for options)
  - [x] 4.2 Implement LD A,(BC) / LD A,(DE) / LD (BC),A / LD (DE),A
  - [x] 4.3 Implement LD A,(nn) / LD (nn),A
  - [x] 4.4 Implement LD HL,(nn) / LD (nn),HL (unprefixed 0x2A/0x22)
  - [x] 4.5 Implement ED-prefix LD (nn),rr / LD rr,(nn) for BC/DE/SP
  - [x] 4.6 Implement LD IX,(nn) / LD (nn),IX / LD IY,(nn) / LD (nn),IY (DD/FD 0x2A/0x22)
  - [x] 4.7 Implement LD A,I / LD A,R / LD I,A / LD R,A (ED-prefix)

- [x] Task 5: Add `DJNZ,` (AC: #5)
  - [x] 5.1 Implement `DJNZ,` — follow `JR,` pattern with fixed opcode 0x10
  - [x] 5.2 Support both label and literal-address operands
  - [x] 5.3 Forward reference resolution via fixup pool (same as JR,)

- [x] Task 6: Add `RST,` (AC: #6)
  - [x] 6.1 Implement `RST,` — pop TOS, validate it's one of {0x00,0x08,0x10,0x18,0x20,0x28,0x30,0x38}
  - [x] 6.2 Emit opcode 0xC7|p (where p is the restart vector)
  - [x] 6.3 Reject non-standard vectors with `bad operand ?`

- [x] Task 7: Add `RLD,` and `RRD,` (AC: #7)
  - [x] 7.1 Add `RLD,` → `asm_emit_ed_op` with 0x6F
  - [x] 7.2 Add `RRD,` → `asm_emit_ed_op` with 0x67

- [x] Task 8: Add REPL tests for all new instructions (AC: #10, #11)
  - [x] 8.1 Tests for single-byte ops: assemble each, verify byte with C@
  - [x] 8.2 Tests for ADC,/SBC,: register, (HL), immediate, indexed forms
  - [x] 8.3 Tests for 16-bit ADD/ADC/SBC: HL,rr and IX/IY variants
  - [x] 8.4 Tests for new LD forms: all indirect-register, absolute, ED-prefix, and I/R forms
  - [x] 8.5 Tests for DJNZ,: forward and backward labels
  - [x] 8.6 Tests for RST,: valid vectors and error on invalid
  - [x] 8.7 Tests for RLD,/RRD,

- [x] Task 9: Update coverage report (AC: #12)
  - [x] 9.1 Update `docs/z80-instruction-coverage.md` to reflect 100% coverage
  - [x] 9.2 Verify all 158 instruction forms are now marked "Supported"

- [x] Task 10: Verify no regressions (AC: #10)
  - [x] 10.1 `make test` — all 73 regression tests pass
  - [x] 10.2 `make test-repl` — all existing 178 + new tests pass

## Dev Notes

### What Already Exists (verified from source)

**Helpers to reuse:**

| Helper | Location | Purpose | For |
|--------|----------|---------|-----|
| `asm_emit_ed_op` | line 3147 | Emit 0xED + byte from A | RLD,, RRD,, LD A,I, LD A,R, LD I,A, LD R,A, ADC HL, SBC HL, ED LD forms |
| `asm_arith_word` | line 1830 | Shared ADD/SUB/AND/OR/XOR/CP dispatch | ADC, and SBC, (8-bit) — base opcodes 0x88 and 0x98 |
| `asm_emit_byte` | line 516 | Emit byte at HERE, advance HERE | Everything — preserves BC, DE |
| `asm_inc_dec_word` | line 2590 | 16-bit register pair dispatch | ADD HL,rr pattern (similar rp-field encoding) |
| `asm_jp_call_word` | line 2315 | Label/literal dispatch for JP,/CALL, | Not needed (DJNZ follows JR, pattern instead) |
| `w_JR_COMMA_cf` | line 2165 | Conditional/unconditional relative jump | DJNZ, — same structure, fixed opcode 0x10, no condition check |
| `check_asm_mode` | line 170 | Assert asm_mode=1 | All new words |
| `asm_check_tagged` | line 189 | Assert TOS high byte = 0xFF | All operand-consuming words |
| `asm_emit_ixiy_prefix` | line 1173 | Emit DD or FD based on index | ADD IX,rr / ADD IY,rr, LD IX,(nn) etc. |

### Design Decisions (LOCKED — confirmed by project lead 2026-04-12)

#### Single-Byte Ops Helper

Create `asm_emit_single`: `check_asm_mode` → `asm_emit_byte` → `NEXT`. Each word loads its opcode into A and JPs to the helper. ~3 lines per word. This mirrors `asm_emit_ed_op` but without the 0xED prefix.

```z80
asm_emit_single:
        LD      (asm_tmp), A
        CALL    check_asm_mode
        LD      A, (asm_tmp)
        CALL    asm_emit_byte
        NEXT
```

Note: A must be saved/restored via `asm_tmp` because `check_asm_mode` clobbers A.

#### ADC, and SBC, (8-bit)

Trivial — clone ADD,/SUB, stubs:
```z80
w_ADC_COMMA_cf:
        LD      A, 0x88     ; ADC base opcode
        JP      asm_arith_word

w_SBC_COMMA_cf:
        LD      A, 0x98     ; SBC base opcode
        JP      asm_arith_word
```

The `asm_arith_word` helper already handles register, (HL), immediate, and indexed dispatch. The immediate-form opcode computation (`AND 0x38` → `OR 0xC6`) produces:
- ADC: 0x88 AND 0x38 = 0x08, OR 0xC6 = 0xCE ✓
- SBC: 0x98 AND 0x38 = 0x18, OR 0xC6 = 0xDE ✓

#### 16-bit ADD/ADC/SBC

ADD,, ADC,, and SBC, need to check if the destination (NOS) is a REG16 tag. The current `asm_arith_word` only handles 8-bit operands.

**DECISION: Option A — Check before entering asm_arith_word.** Each of ADD,/ADC,/SBC, gets a small prologue that peeks at NOS. If REG16, handle the 16-bit path inline. Otherwise JP to `asm_arith_word`. This is cleaner because only ADD,/ADC,/SBC, have 16-bit forms; AND,/OR,/XOR,/CP, do not.

For ADD HL,rr: opcode = 0x09 | (rp<<4). Single unprefixed byte.
For ADD IX,rr / ADD IY,rr: emit DD/FD prefix, then 0x09 | (rp<<4).
For ADC HL,rr: emit ED, then 0x4A | (rp<<4).
For SBC HL,rr: emit ED, then 0x42 | (rp<<4).

Note: only HL (or IX/IY for ADD) can be the destination. ADC/SBC only work with HL, not IX/IY.

#### LD Indirect-Register Forms: `(BC)` and `(DE)` words

**DECISION:** Add `(BC)` and `(DE)` as new DEFCODE words that push INDIRECT class tags, consistent with existing `(HL)` / `(IX)` / `(IY)` / `(SP)` / `(C)` pattern. LD, dispatch adds checks for these specific indices.

New INDIRECT index values: (BC)=7, (DE)=8 (extending current range: (HL)=0, (IX)=1, (IY)=2, (IX+d)=3, (IY+d)=4, (SP)=5, (C)=6).

Syntax:
- `A (BC) LD,` → LD A,(BC) = 0x0A
- `A (DE) LD,` → LD A,(DE) = 0x1A
- `(BC) A LD,` → LD (BC),A = 0x02
- `(DE) A LD,` → LD (DE),A = 0x12

Note: Only A can be source/destination for these forms. LD, must reject non-A operands for (BC)/(DE) with `bad operand ?`.

#### LD Absolute-Address Forms: `()` word

**DECISION:** Add a `()` word that wraps a bare address as an indirect-memory tag, analogous to how `#` wraps a value as an immediate tag. Uses a two-cell layout: value below, tag on top (same pattern as `#`).

New INDIRECT index value: ()=9 (absolute memory reference).

Syntax:
- `A 0x1234 () LD,` → LD A,(0x1234) = 0x3A lo hi
- `0x1234 () A LD,` → LD (0x1234),A = 0x32 lo hi
- `HL 0x1234 () LD,` → LD HL,(0x1234) = 0x2A lo hi (unprefixed)
- `0x1234 () HL LD,` → LD (0x1234),HL = 0x22 lo hi (unprefixed)
- `BC 0x1234 () LD,` → LD BC,(0x1234) = ED 0x4B lo hi
- `0x1234 () BC LD,` → LD (0x1234),BC = ED 0x43 lo hi
- `IX 0x1234 () LD,` → LD IX,(0x1234) = DD 0x2A lo hi
- `0x1234 () IX LD,` → LD (0x1234),IX = DD 0x22 lo hi

The `()` word pops TOS (bare integer address), pushes it back, then pushes the `0xFF` + INDIRECT class + index 9 tag on top. LD, sees the () tag and extracts the address from the cell below.

#### LD A,I / LD A,R / LD I,A / LD R,A: `IREG` and `RREG` register words

**DECISION:** Add `IREG` and `RREG` as register tag words using REG8 class with new indices (I=8, R=9). Named `IREG`/`RREG` (not `I`/`R`) to avoid shadowing Forth's `I` loop index word. LD, handles `A IREG LD,` → ED 0x57.

These are NOT general-purpose registers — only LD A,I / LD I,A / LD A,R / LD R,A are valid. LD, must reject all non-A combinations with `bad operand ?`.

Syntax:
- `A IREG LD,` → LD A,I = ED 0x57
- `A RREG LD,` → LD A,R = ED 0x5F
- `IREG A LD,` → LD I,A = ED 0x47
- `RREG A LD,` → LD R,A = ED 0x4F

#### DJNZ,

Follow the JR, pattern exactly. Key differences:
- Fixed opcode 0x10 (no condition check needed)
- No condition operand to peek/pop
- Same label resolution and fixup pool mechanism

```z80
w_DJNZ_COMMA_cf:
        CALL    check_asm_mode
        LD      (asm_ip_save), DE
        LD      A, 0x10
        CALL    asm_emit_byte
        ; ... rest identical to JR, uncond path ...
```

#### RST, — bare integer operand

**DECISION:** RST, takes a **bare integer** (not tagged), following the `DB,` / `DS,` precedent. `#` is only needed to disambiguate when an opcode has multiple operand patterns; RST has only one. `asm_check_tagged` should NOT be called.

Syntax: `0x38 RST,` → 0xFF

Validates: operand must be a multiple of 8 in range 0x00-0x38. Non-standard vectors produce `bad operand ?`.

```z80
w_RST_COMMA_cf:
        CALL    check_asm_mode
        LD      A, B
        OR      A                       ; high byte must be 0
        JP      NZ, asm_bad_operand
        LD      A, C
        CP      0x39                    ; > 0x38?
        JP      NC, asm_bad_operand
        AND     0x07                    ; low 3 bits must be 0
        JP      NZ, asm_bad_operand
        LD      A, C
        OR      0xC7                    ; build RST opcode
        CALL    asm_emit_byte
        POP     BC
        NEXT
```

### Operand Order Convention

All existing multi-operand instructions use **Zilog dst-src order**: NOS=destination, TOS=source. New instructions must follow this convention.

For 16-bit ADD: `HL BC ADD,` means `ADD HL, BC` (destination=HL, source=BC).

### Tag Encoding Reference

Current INDIRECT class indices: (HL)=0, (IX)=1, (IY)=2, (IX+d)=3, (IY+d)=4, (SP)=5, (C)=6.

New entries this story: (BC)=7, (DE)=8, ()=9 (absolute memory address).

Current REG8 class indices: B=0, C=1, D=2, E=3, H=4, L=5, (unused=6), A=7.

New entries this story: I=8, R=9 (special-purpose registers, LD-only).

### Code Field Label Convention (CRITICAL)

For DEFCODE words, `w_XXX_cf` labels point directly to the machine code body (no JP DOCOL). Each new DEFCODE word follows this pattern exactly.

### Anti-Patterns to Avoid

1. **Do NOT touch `outer_interpreter.asm` or `system.asm`** — all changes in `assembler.asm` only
2. **Do NOT add tests to the regression test thread** — REPL-piped tests only
3. **Do NOT duplicate helper code** — reuse `asm_arith_word`, `asm_emit_ed_op`, `asm_emit_single`, etc.
4. **Do NOT break the 16-bit ADC/SBC → 8-bit ADC/SBC dispatch** — the word must handle both forms
5. **Do NOT assume BC is safe across `check_asm_mode` or helper calls** — follow save-restore patterns from 4.1/4.2
6. **Do NOT forget DE preservation** — dominant bug class in Epic 4; spill DE before any helper call that might clobber it
7. **Do NOT share scratch slots across nesting boundaries** — add new slots if existing ones conflict

### Previous Story Intelligence (from Epic 4)

**Register-contract violations** were the dominant bug class across Epic 4 (4/6 stories). Every new opcode word must:
1. Call `check_asm_mode` first
2. Save DE to `asm_ip_save` before any helper call that clobbers DE
3. Save BC to return stack if calling `build_header` or similar
4. Verify scratch slot sharing doesn't nest

**Interactive smoke testing is essential** — REPL tests alone won't catch register-contract violations. Test each new word interactively in a CODE word before relying on automated tests.

### Git Intelligence

Recent commits follow one-commit-per-story pattern:
```
3b48731 commit orphans
21c8d05 add examples
7f516da completed story 4.4
```

### Testing Strategy

**Primary: REPL-piped tests** (per memory: feedback_repl_tests_preferred.md)

New tests continue from test 179 onwards in Makefile's `test-repl` target.

Each new instruction should have at least one test that:
1. Assembles the instruction inside a CODE word
2. Reads the assembled bytes with `C@`
3. Verifies the expected opcode bytes

### References

- [Source: src/assembler.asm] — Complete assembler implementation
- [Source: src/assembler.asm:3147-3157] — `asm_emit_ed_op` helper
- [Source: src/assembler.asm:1830-1877] — `asm_arith_word` helper
- [Source: src/assembler.asm:2165-2242] — `w_JR_COMMA_cf` (pattern for DJNZ,)
- [Source: src/assembler.asm:2590-2665] — `asm_inc_dec_word` (pattern for ADD HL,rr)
- [Source: src/assembler.asm:516-523] — `asm_emit_byte` (preserves BC, DE)
- [Source: docs/z80-instruction-coverage.md] — Gap analysis from Story 5.0
- [Memory: feedback_assembler_operand_order.md] — Zilog dst-src order convention
- [Memory: feedback_design_upfront.md] — Design extensible encodings up front
- [Memory: feedback_systematic_reference_check.md] — Systematic reference cross-check

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- asm_emit_byte clobbers HL — all absolute-address LD forms initially had a bug where the high byte of the address was corrupted after the first asm_emit_byte call. Fixed by using BC (preserved by asm_emit_byte) to hold the address instead of HL.
- `I` register word shadowed Forth's `I` loop index — renamed to `IREG` / `RREG` to avoid conflict.
- REPL input line length limit — tests reading 8+ bytes needed to be split across multiple CODE definitions.

### Completion Notes List
- Task 1: Added `asm_emit_single` helper and 12 single-byte zero-operand words (NOP, HALT, DI, EI, DAA, CPL, SCF, CCF, RLCA, RRCA, RLA, RRA)
- Task 2: Added ADC, and SBC, (8-bit) via asm_arith_word with base opcodes 0x88/0x98
- Task 3: Extended ADD,/ADC,/SBC, with REG16 prologues for 16-bit forms. ADD supports HL/IX/IY destinations; ADC/SBC support HL only.
- Task 4: Added (BC), (DE), () tag words and IREG/RREG register words. Extended LD, dispatch with 11 new handler blocks for indirect-register loads, absolute-address loads (all rr+IX/IY variants), and I/R special register loads.
- Task 5: Added DJNZ, following JR, pattern with fixed opcode 0x10, label/literal operand support
- Task 6: Added RST, with bare integer operand validation (multiples of 8, 0x00-0x38)
- Task 7: Added RLD, and RRD, via asm_emit_ed_op
- Task 8: Added 35 new REPL tests (tests 179-207) covering all new instructions
- Task 9: Updated z80-instruction-coverage.md to reflect 100% coverage (158/158)
- Task 10: All 73 regression + 214 REPL tests pass with zero regressions

### Change Log
- 2026-04-12: Story 5.0.5 implementation complete — closed 27 instruction gaps, achieving 100% Z80 coverage
- 2026-04-12: Code review fixes — hardened assert_8bit_reg_or_ihl, added 5 error-path tests + HL HL ADC/SBC test, updated Dev Notes for IREG/RREG naming
- 2026-04-12: Second review fixes — fixed ADD IX,IX / ADD IY,IY (were rejected, now emit DD/FD 29), updated design overview comment with all tag indices, fixed Dev Notes asm_emit_single snippet

### File List
- src/assembler.asm — All new opcode words, tag constants, LD, extensions (~730 lines added); design overview comment updated; ADD IX,IX/IY,IY fix; assert_8bit_reg_or_ihl hardened
- Makefile — 43 new REPL tests (tests 179-214)
- docs/z80-instruction-coverage.md — Updated to 100% coverage
