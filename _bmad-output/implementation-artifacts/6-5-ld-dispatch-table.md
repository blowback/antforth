# Story 6.5: LD, Dispatch Table

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want the LD, dispatch preamble replaced with a class-indexed jump table and its nearly-identical handler pairs merged,
so that the binary shrinks by ~40-60 bytes and dispatch is cleaner.

## Acceptance Criteria

1. **Given** the current linear chain of CALL/JP pairs in the LD, dispatch preamble (lines 1507-1534 of `src/assembler.asm`) **When** it is replaced with a class-indexed dispatch that extracts the class field once and branches directly **Then** `make test && make test-repl` passes all regression tests with zero failures.

2. **Given** the three pairs of nearly-identical LD, handlers that differ only by an opcode byte **When** each pair is merged into a shared handler with parameterised entry points **Then** all tests pass and no observable behaviour changes.

3. **Given** both changes land **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 20 bytes smaller than the pre-story baseline (14,635 bytes).

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #3)
  - [x] 0.1 `make asm && wc -c build/antforth.com` -- confirm 14,635 bytes
  - [x] 0.2 `make test && make test-repl` -- confirm all tests pass

- [x] Task 1: Merge `.ldc_ibc_src` / `.ldc_ide_src` (AC: #2)
  - [x] 1.1 Replace the two separate handlers with a shared `.ldc_ind_a_src` handler using H as opcode parameter
  - [x] 1.2 `make asm && make test && make test-repl` -- confirm no regressions
  - [x] 1.3 Record binary size — 14,609 bytes (-26 from baseline)

- [x] Task 2: Merge `.ldc_ibc_dst` / `.ldc_ide_dst` (AC: #2)
  - [x] 2.1 Replace with shared `.ldc_ind_a_dst` handler using H as opcode parameter
  - [x] 2.2 `make asm && make test && make test-repl` -- confirm no regressions
  - [x] 2.3 Record binary size — 14,593 bytes (-42 from baseline)

- [x] Task 3: Merge `.ldc_i_dst` / `.ldc_r_dst` (AC: #2)
  - [x] 3.1 Replace with shared `.ldc_ir_dst` handler using H as second opcode byte (needed PUSH/POP HL around first asm_emit_byte since it clobbers HL)
  - [x] 3.2 `make asm && make test && make test-repl` -- confirm no regressions
  - [x] 3.3 Record binary size — 14,574 bytes (-61 from baseline)

- [x] Task 4: Replace dispatch preamble with class-indexed dispatch (AC: #1)
  - [x] 4.1 Replace linear CALL chain with single class extraction + branch chain
  - [x] 4.2 Create `.ldc_indirect_src` handler consolidating all INDIRECT sub-dispatch
  - [x] 4.3 Create `.ldc_reg8_src` handler consolidating REG8 + I/R sub-dispatch
  - [x] 4.4 `make asm && make test && make test-repl` -- confirm no regressions
  - [x] 4.5 Record binary size — 14,584 bytes (-51 from baseline)

- [x] Task 5: Final verification (AC: #3)
  - [x] 5.1 `make test && make test-repl` -- all tests green (265/265 REPL tests pass)
  - [x] 5.2 `wc -c build/antforth.com` -- 14,584 bytes, saved 51 bytes (>= 20 threshold)
  - [x] 5.3 Verify all LD, forms still assemble correctly — covered by REPL tests 86, 107-113, 164-166, 189-200b

## Dev Notes

### Current LD, Dispatch Preamble (59 bytes)

Lines 1504-1534 of `src/assembler.asm`. After `check_asm_mode` and `asm_check_tagged`, the source operand class is determined by a linear chain:

```
CALL asm_is_indirect_tag / JR NZ        → INDIRECT sub-dispatch (BC/DE/ABS)
CALL asm_get_class / JR NZ              → REG8 I/R sub-dispatch
CALL asm_is_imm_tag / JP Z              → .ldc_imm
CALL asm_is_ixiy_indexed / JP Z         → .ldc_idx_src
CALL asm_is_reg16_tag / JP Z            → .ldc_r16_src
(fallthrough)                           → reg-to-reg path
```

**Problems:** 5 CALL instructions (15 bytes). INDIRECT class is checked twice (once for (BC)/(DE)/(ABS), again later for IX+d/IY+d via `asm_is_ixiy_indexed`). (HL) source (class=INDIRECT, index=0) falls through the entire chain wastefully.

### Replacement: Class-Indexed Dispatch (actual: ~69 bytes incl. sub-handlers)

Extract the class field once and branch directly:

```asm
; After check_asm_mode / asm_check_tagged:
        LD      A, C
        AND     ASM_CLASS_MASK          ; A = 0x00/0x20/0x40/0x60/0x80/0xA0
        JR      Z, .ldc_reg8_src        ; REG8 (0x00) — most common
        CP      ASM_CLASS_INDIRECT
        JR      Z, .ldc_indirect_src    ; INDIRECT (0x80) — all indirect forms
        CP      ASM_CLASS_IMM
        JP      Z, .ldc_imm             ; IMM (0x40) — existing handler
        CP      ASM_CLASS_REG16
        JP      Z, .ldc_r16_src         ; REG16 (0x60) — existing handler
        JP      asm_bad_operand         ; COND/LABEL = error
```

This replaces 59 bytes of linear chain with ~23 bytes of class dispatch + two new sub-handlers.

### INDIRECT Sub-Handler (~32 bytes, replaces ~29 bytes)

Consolidates ALL indirect dispatch in one place (currently split across two locations):

```asm
.ldc_indirect_src:
        LD      A, C
        AND     ASM_INDEX_MASK
        OR      A
        JR      Z, .ldc_r8_cont         ; (HL) index=0 → reg-to-reg path
        CP      ASM_IND_IXD
        JP      Z, .ldc_idx_src
        CP      ASM_IND_IYD
        JP      Z, .ldc_idx_src
        CP      ASM_IND_BC
        JP      Z, .ldc_ibc_src
        CP      ASM_IND_DE
        JP      Z, .ldc_ide_src
        CP      ASM_IND_ABS
        JP      Z, .ldc_abs_src
        JP      asm_bad_operand
```

### REG8 Sub-Handler (~13 bytes, replaces ~18 bytes)

```asm
.ldc_reg8_src:
        LD      A, C
        AND     ASM_INDEX_MASK
        CP      ASM_REG8_I
        JP      Z, .ldc_ir_src
        CP      ASM_REG8_R
        JP      Z, .ldc_ir_src
.ldc_r8_cont:
        ; existing reg-to-reg code continues here (line 1536+)
        LD      H, B
        LD      L, C
        CALL    assert_8bit_reg_or_ihl
        ...
```

### Handler Merge 1: (BC)/(DE) Source (~26 bytes saved)

Current `.ldc_ibc_src` (31 bytes) and `.ldc_ide_src` (31 bytes) are identical except for the final opcode (0x0A vs 0x1A). Merge using H as parameter:

```asm
.ldc_ibc_src:
        LD      H, 0x0A                 ; LD A,(BC) opcode
        JR      .ldc_ind_a_src
.ldc_ide_src:
        LD      H, 0x1A                 ; LD A,(DE) opcode
        ; fall through
.ldc_ind_a_src:
        POP     BC
        CALL    asm_check_tagged
        CALL    asm_get_class
        JP      NZ, asm_bad_operand
        CALL    asm_get_index
        CP      7                       ; must be A
        JP      NZ, asm_bad_operand
        LD      A, H
        CALL    asm_emit_byte
        POP     BC
        NEXT
```

Current: 62 bytes. Merged: 36 bytes. **Savings: ~26 bytes.**

H is safe because `asm_check_tagged`, `asm_get_class`, and `asm_get_index` only touch A and flags (they read B/C).

### Handler Merge 2: (BC)/(DE) Destination (~16 bytes saved)

Current `.ldc_ibc_dst` (21 bytes) and `.ldc_ide_dst` (21 bytes) differ only by opcode (0x02 vs 0x12):

```asm
.ldc_ibc_dst:
        LD      H, 0x02                 ; LD (BC),A opcode
        JR      .ldc_ind_a_dst
.ldc_ide_dst:
        LD      H, 0x12                 ; LD (DE),A opcode
        ; fall through
.ldc_ind_a_dst:
        LD      A, (asm_tmp)
        CP      7
        JP      NZ, asm_bad_operand
        LD      A, H
        CALL    asm_emit_byte
        POP     BC
        NEXT
```

Current: 42 bytes. Merged: 26 bytes. **Savings: ~16 bytes.**

### Handler Merge 3: I/R Destination (~21 bytes saved)

Current `.ldc_i_dst` (26 bytes) and `.ldc_r_dst` (26 bytes) differ only by second opcode (0x47 vs 0x4F):

```asm
.ldc_i_dst:
        LD      H, 0x47                 ; LD I,A second byte
        JR      .ldc_ir_dst
.ldc_r_dst:
        LD      H, 0x4F                 ; LD R,A second byte
        ; fall through
.ldc_ir_dst:
        LD      A, (asm_tmp)
        CP      7
        JP      NZ, asm_bad_operand
        LD      A, 0xED
        CALL    asm_emit_byte
        LD      A, H
        CALL    asm_emit_byte
        POP     BC
        NEXT
```

Current: 52 bytes. Merged: 31 bytes. **Savings: ~21 bytes.**

### Estimated Byte Budget

| Change | Old | New | Est Delta | Actual Delta |
|---|---|---|---|---|
| Class dispatch (replaces preamble lines 1507-1534) | 59 | ~68 | +9 | +10 |
| (BC)/(DE) source merge | 62 | 36 | -26 | -26 |
| (BC)/(DE) destination merge | 42 | 26 | -16 | -16 |
| I/R destination merge | 52 | 31 | -21 | -19 (+2 for PUSH/POP HL) |
| **Total** | **215** | **161** | **-54** | **-51** |

Actual: **51 bytes saved** (well above the 20-byte AC). 3-byte variance from estimate due to PUSH/POP HL in .ldc_ir_dst (+2) and dispatch slightly larger than estimated (+1).

### Why H Is Safe in All Merges

- `asm_check_tagged`: reads B (must be 0xFF), does not write H
- `asm_get_class`: `LD A, C / AND mask / RET` — A-only
- `asm_get_index`: `LD A, C / AND mask / RET` — A-only
- `asm_emit_byte`: writes to memory via (HERE), uses HL internally but H is consumed before this call
- None of these touch H, so it survives as a parameter register through the merged handler

### (HL) Source Routing

(HL) has tag encoding class=INDIRECT (0x80), index=0. In the current code, it falls through ALL dispatch checks to the reg-to-reg path where `assert_8bit_reg_or_ihl` (line 1475) handles it.

With the new dispatch, class=INDIRECT routes to `.ldc_indirect_src`, which checks index=0 and jumps to `.ldc_r8_cont` — the entry point of the reg-to-reg path. `assert_8bit_reg_or_ihl` still handles the (HL) tag correctly (returns r-field=6).

### Tag Encoding Reference

```
ASM_TAG_HI          = 0xFF    (high byte of all tags)
ASM_CLASS_MASK      = 0xE0    (top 3 bits of low byte)
ASM_INDEX_MASK      = 0x1F    (bottom 5 bits of low byte)
ASM_CLASS_REG8      = 0x00    ASM_CLASS_COND     = 0x20
ASM_CLASS_IMM       = 0x40    ASM_CLASS_REG16    = 0x60
ASM_CLASS_INDIRECT  = 0x80    ASM_CLASS_LABEL    = 0xA0
```

INDIRECT sub-indices relevant to LD:
```
0 = (HL)    3 = (IX+d)    4 = (IY+d)
7 = (BC)    8 = (DE)      9 = () (absolute)
```

REG8 extended indices: 8 = I, 9 = R

### Ordering of Tasks

Do handler merges (Tasks 1-3) FIRST. Each is mechanical and independently testable. The dispatch table refactor (Task 4) then restructures the preamble with the merged handlers already in place. This avoids conflicting edits.

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Previous Story Learnings (6.4)

- Mechanical refactoring in `src/assembler.asm` has been clean and regression-free
- Build-test-verify after each task catches issues early
- Record baseline size before any changes
- sjasmplus local label scoping: `.label` is scoped per parent label; use unique label names or appropriate parent context
- XOR/AND shared tail pattern worked well for tag predicates; similar parameterisation-via-register technique applies here (but with H instead of A)

### Project Structure Notes

- All changes are within `src/assembler.asm` — no other files need modification
- `asm_is_ixiy_indexed` function (line 1134) is NOT removed — it's still called by `asm_arith_word` (line 2114) and other opcodes. Only its use in the LD, preamble is eliminated.
- NEXT macro expands to 7 bytes: `EX DE,HL / LD E,(HL) / INC HL / LD D,(HL) / INC HL / EX DE,HL / JP (HL)`

### References

- [Source: src/assembler.asm:1498-1534] — LD, word and dispatch preamble
- [Source: src/assembler.asm:1536-1579] — Register-to-register path
- [Source: src/assembler.asm:1812-1839] — .ldc_ibc_src / .ldc_ide_src handlers
- [Source: src/assembler.asm:1964-1983] — .ldc_ibc_dst / .ldc_ide_dst handlers
- [Source: src/assembler.asm:2063-2086] — .ldc_i_dst / .ldc_r_dst handlers
- [Source: src/assembler.asm:1094-1127] — Tag predicates and class/index helpers
- [Source: src/assembler.asm:1130-1144] — asm_is_ixiy_indexed
- [Source: src/assembler.asm:1475-1495] — assert_8bit_reg_or_ihl
- [Source: src/assembler.asm:140-171] — Tag encoding constants
- [Source: src/macros.asm:28-42] — NEXT / NEXTHL macro definitions
- [Source: _bmad-output/planning-artifacts/epic6-code-size-optimization.md#Story 6.5] — Epic specification
- [Source: _bmad-output/implementation-artifacts/6-4-tag-predicate-cleanup-dead-code-removal.md] — Previous story

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Task 3: `asm_emit_byte` clobbers HL (loads HERE into HL). Merged `.ldc_ir_dst` handler needed PUSH/POP HL to preserve H across the first `asm_emit_byte` call (ED prefix). Added 2 bytes vs spec estimate.

### Completion Notes List

- Task 0: Baseline 14,635 bytes, all tests pass
- Task 1: Merged `.ldc_ibc_src`/`.ldc_ide_src` → `.ldc_ind_a_src` with H as opcode param. -26 bytes.
- Task 2: Merged `.ldc_ibc_dst`/`.ldc_ide_dst` → `.ldc_ind_a_dst` with H as opcode param. -16 bytes.
- Task 3: Merged `.ldc_i_dst`/`.ldc_r_dst` → `.ldc_ir_dst` with H as 2nd opcode byte. Needed PUSH/POP HL around first asm_emit_byte. -19 bytes.
- Task 4: Replaced linear CALL chain with class-indexed dispatch (AND ASM_CLASS_MASK + comparisons). Created `.ldc_indirect_src` and `.ldc_reg8_src` sub-handlers. +10 bytes (sub-handlers larger than removed CALLs, but total net savings remain strong).
- Task 5: Final 14,584 bytes — 51 bytes saved from baseline (AC threshold: 20).

### Change Log

- 2026-04-13: Story 6.5 — LD, dispatch table refactored. Replaced 5-CALL linear preamble with class-indexed dispatch. Merged 3 pairs of near-identical handlers using H as opcode parameter. Net savings: 51 bytes.
- 2026-04-13: Code review (AI) — 0 HIGH, 1 MEDIUM, 4 LOW. All fixed: updated stale section comment in assembler.asm, corrected test count (265 not 258), annotated byte budget table with actuals, fixed dispatch size estimate. Status → done.

### File List

- src/assembler.asm (modified)
