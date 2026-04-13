# Epic 6: Code Size Optimization

## Context

AntForth has reached MVP at **15,518 bytes**. The assembler (~50%) is feature-complete with 100% Z80 opcode coverage, excellent label/tag system, and clean architecture. Every kilobyte the compiler uses is a kilobyte less for user programs on a 64K machine. This epic trims mechanical repetition, dead code, and redundant patterns through refactoring — no feature cuts, no architectural compromises.

**Target: ~600-700 bytes saved** (~4% of binary).

**Build/test**: `make asm` builds with sjasmplus; `make test && make test-repl` runs all 531 regression tests.

---

## Story 6.1: BDOS Output Helpers

**Savings: ~160-180 bytes | Risk: Low | Effort: Medium**

The 3-byte sequence `LD C, C_WRITE / CALL BDOS_ENTRY` appears **47 times** across 9 source files. Every character output call site independently crafts its own BDOS invocation. On top of that, higher-level patterns (print-string loops, CRLF, error suffixes) are duplicated as inline code despite shared subroutines already existing in assembler.asm.

**Layer 1 — `bdos_putchar` (new, in `src/io.asm`)**

```asm
bdos_putchar:           ; Entry: E = character
    LD   C, C_WRITE     ; 2 bytes
    CALL BDOS_ENTRY     ; 3 bytes
    RET                 ; 1 byte — 6 bytes total
```

Every `LD C, C_WRITE / CALL BDOS_ENTRY` (5 bytes) becomes `CALL bdos_putchar` (3 bytes).
**47 sites x 2 bytes = 94 - 6 (subroutine) = ~88 bytes**

**Layer 2 — `bdos_crlf` (new, in `src/io.asm`)**

```asm
bdos_crlf:
    LD   E, 0x0D        ; 2 bytes
    CALL bdos_putchar   ; 3 bytes
    LD   E, 0x0A        ; 2 bytes
    JP   bdos_putchar   ; 3 bytes — 10 bytes, tail-call (no RET)
```

Inline CRLF (post-Layer-1: 10 bytes each) becomes `CALL bdos_crlf` (3 bytes). Sites:
- `compiler.asm:487-492`
- `dictionary.asm:235-240`
- `system.asm:379-384`
- `io.asm` w_CR_cf can simplify to `BDOS_SAVE / CALL bdos_crlf / BDOS_RESTORE / NEXT`

**~3-4 sites x 7 bytes = ~24 bytes**

**Layer 3 — Promote `bdos_print_str` (relocate from `assembler.asm:233` to `src/io.asm`)**

The subroutine `asm_print_str` already exists but is assembler-local. Promote to system-wide `bdos_print_str`. Six inline print-string loops across the codebase become `CALL bdos_print_str`:
- `compiler.asm:469-478` (comp_err_print)
- `control_flow.asm:19-28` (qcomp_print)
- `system.asm:368-377` (underflow print_loop)
- `dictionary.asm:199-209` (words_print)
- `formatting.asm:94-104` (eu_emit)
- `assembler.asm:400-409` (pen_pfx and pen_name — 2 inline loops in asm_print_error_with_name)

Each inline loop ~12 bytes becomes `CALL bdos_print_str` = 3 bytes.
**~6 sites x 9 bytes = ~54 bytes**

**Layer 4 — Promote `bdos_print_q_crlf` (relocate from `assembler.asm:259`)**

`asm_print_q_crlf` prints ` ?` + CRLF. Inline copies exist in:
- `compiler.asm:480-492` (24 bytes inline becomes 3 byte CALL = 21 saved)
- `assembler.asm:432-443` (second copy inside asm_print_error_with_name)

**~21 bytes**

**Interaction with other stories**: bdos_putchar also shrinks the bodies of bdos_print_str, bdos_crlf, and bdos_print_q_crlf themselves by 2 bytes each.

---

## Story 6.2: Return-Stack Push/Pop Subroutines

**Savings: ~245 bytes | Risk: Low | Effort: Medium**

Three inline 8-byte patterns repeated 57 times across 10 files:

| Pattern | Sites | Files |
|---------|-------|-------|
| Push DE to rstack | 26 | io, inner_interpreter, stack_ops, memory, compiler, formatting, outer_interpreter, strings, assembler, system |
| Pop DE from rstack | 18 | io, inner_interpreter, stack_ops, memory, compiler, formatting, strings |
| Push BC to rstack | 13 | system, inner_interpreter, compiler, formatting, outer_interpreter, control_flow, assembler |

**Implementation:**
1. Add 3 subroutines in `src/inner_interpreter.asm`:
   - `rpush_de` (9 bytes) — DEC IX / DEC IX / LD (IX+0),E / LD (IX+1),D / RET
   - `rpop_de` (9 bytes) — LD E,(IX+0) / LD D,(IX+1) / INC IX / INC IX / RET
   - `rpush_bc` (9 bytes) — DEC IX / DEC IX / LD (IX+0),C / LD (IX+1),B / RET
2. Replace all 57 inline sequences with `CALL rpush_de` / `CALL rpop_de` / `CALL rpush_bc`
3. **Exception**: Keep DOCOL and EXIT inline — hottest paths in the system

**Savings math**: 57 x 5 = 285 - 27 (subroutine bodies) = **~258 bytes**

**Performance**: +17 T-states per call (~4us at 4MHz). Negligible outside DOCOL/EXIT.

---

## Story 6.3: IX/IY Prefix Pair Merges

**Savings: ~70-90 bytes | Risk: Medium | Effort: Medium**

Nine code pairs in `src/assembler.asm` differ only by `0xDD` vs `0xFD` prefix. `asm_emit_ixiy_prefix` (line 1224) already exists.

**In LD, (6 pairs):**

| Pair | Lines | Saves |
|------|-------|-------|
| `.ldc_imm16_ix`/`_iy` | 1838-1862 | ~10 |
| `.ldc_imm_ixd`/`_iyd` | 1890-1918 | ~16 |
| `.ldabs_ix`/`_iy` | 2037-2063 | ~12 |
| `.ldr16abs_ix`/`_iy` | 2179-2202 | ~12 |
| `.ldc_ibc_src`/`_ide_src` | 1925-1952 | ~12 |
| `.ldc_ibc_dst`/`_ide_dst` | 2092-2111 | ~7 |

**Outside LD, (3 pairs):**

| Pair | Lines | Saves |
|------|-------|-------|
| `.jp_iix`/`_iiy` | 2784-2799 | ~8 |
| `.bop_ixd`/`_iyd` (BIT/SET/RES) | 3458-3503 | ~28 |
| `.ex_sp_ix`/`_iy` | 3856-3870 | ~8 |

**Approach**: Merge each pair into a single handler that calls `asm_emit_ixiy_prefix` then shared emit sequence. For (BC)/(DE) pairs, compute opcode arithmetically from the indirect index.

---

## Story 6.4: Tag Predicate Cleanup + Dead Code Removal

**Savings: ~11 bytes | Risk: Low | Effort: Low**

- **`asm_is_cond_tag` (line 1167) is dead code** — defined but never called. Remove: **6 bytes**.
- Remaining 4 predicates share identical body. Refactor to JR-into-shared-tail: **~5 bytes**.

**Files**: `assembler.asm` only (lines 1157-1199).

---

## Story 6.5: LD, Dispatch Table

**Savings: ~25-50 bytes | Risk: Medium-High | Effort: Medium**

The LD, dispatch preamble (lines 1587-1618) is a linear chain of CALL/JP pairs. Replace with a class-indexed jump table:

```asm
    LD   A, C
    AND  ASM_CLASS_MASK      ; extract class
    RRCA / RRCA / RRCA / RRCA ; shift to 0-5 range
    ADD  A, A                ; x2 for word offsets
    LD   HL, .ld_class_table
    ADD  A, L / LD L, A
    LD   A, (HL) / INC HL / LD H, (HL) / LD L, A
    JP   (HL)

.ld_class_table:             ; 12 bytes
    DW  .ldc_reg8_dispatch   ; class 0: REG8
    DW  asm_bad_operand      ; class 1: COND
    DW  .ldc_imm             ; class 2: IMM
    DW  .ldc_r16_src         ; class 3: REG16
    DW  .ldc_indirect_dispatch ; class 4: INDIRECT
    DW  asm_bad_operand      ; class 5: LABEL
```

Dispatch ~18 bytes + table 12 bytes = 30 bytes vs current ~55 bytes. Sub-dispatchers within INDIRECT/REG8 remain as CP/JR chains.

**Dependency**: Story 6.4 (tag predicates) should land first.

---

## Story 6.6: Register Word Recognizer

**Savings: ~130-140 bytes | Risk: High | Effort: High**

Replace 32 individual DEFCODE dictionary entries (register, indirect, condition-code words) with a single recognizer checked during INTERPRET.

**Current cost**: 32 words x ~10.7 bytes avg (header + 5-byte body) + 15 bytes shared tails = **~343 bytes**

**New design:**

1. **Recognizer word** `w_ASM_RECOGNIZE` (~50-60 bytes), signature `( c-addr -- value true | c-addr false )`:
   - Fast-fail: if `asm_mode` == 0, return false immediately (zero overhead outside CODE)
   - Load counted string, scan compact table for matching (length, name, tag)
   - If found: push tag as `0xFFxx` and return true
   - If not found: return original c-addr and false

2. **Compact table** (~137 bytes): `DB name_len, "NAME", tag_byte` entries, sentinel `DB 0`:
   - 7 REG8 (21 bytes) + 8 REG16 (33 bytes) + 7 INDIRECT (41 bytes) + 2 SPECIAL (12 bytes) + 8 COND (29 bytes) + sentinel (1 byte) = ~137 bytes

3. **INTERPRET modification** (~10 bytes in `src/outer_interpreter.asm:192`):
   Insert between FIND failure and NUMBER?:
   ```
   .try_number:
       DW w_DROP_cf               ; drop 0 from FIND
       DW w_ASM_RECOGNIZE_cf      ; ( c-addr -- value true | c-addr false )
       DW w_QBRANCH_cf
       DW .try_real_number - $    ; if false, try NUMBER?
       DW w_BRANCH_cf
       DW .got_number - $         ; share existing number/STATE handling
   .try_real_number:
       DW w_NUMBER_Q_cf           ; existing path
   ```

4. **Remove 32 DEFCODE entries** from `assembler.asm:920-1155`. Keep `()` and `#` (unique stack-manipulation bodies).

**New total**: ~60 (recognizer) + 137 (table) + 10 (INTERPRET) = **~207 bytes**
**Savings**: 343 - 207 = **~136 bytes**

**Trade-offs**:
- `WORDS` no longer shows register names (acceptable — they only work inside CODE)
- INTERPRET gets one extra step, but fast-fail on `asm_mode` means zero cost in normal Forth
- Case-insensitive comparison needed — reuse UPPER macro from FIND

**Dependency**: Stories 6.1-6.5 should land first (capstone story).

---

## Story 6.7: Misc Dedup

**Savings: ~15-25 bytes | Risk: Low | Effort: Low**

- **Sign-negation** in `formatting.asm`: `w_DOT` (lines 125-139) and `.dots_print_signed` (lines 418-432) duplicate BIT 7 test + emit '-' + negate BC. Extract helper: **~8 bytes**.
- **Opportunistic JP to JR conversions** found during earlier stories (1 byte each).
- **Tail-call optimizations**: `CALL foo / RET` becomes `JP foo` (saves 1-2 bytes per site).

---

## Story Ordering and Dependencies

```
6.1 (BDOS helpers) ────┐
                       ├──> 6.7 (misc dedup, opportunistic finds)
6.2 (rstack helpers) ──┘

6.4 (tag predicates) ──> 6.5 (LD, dispatch table)

6.3 (IX/IY merges) ────> independent

6.1-6.5 complete ──────> 6.6 (register recognizer — capstone)
```

Stories 6.1, 6.2, 6.3, 6.4 can proceed in any order. Story 6.5 depends on 6.4. Story 6.6 is last.

## Savings Summary

| Story | Savings | Risk | Cumulative |
|-------|---------|------|------------|
| 6.1 BDOS output helpers | ~165 bytes | Low | ~165 |
| 6.2 Return-stack helpers | ~258 bytes | Low | ~423 |
| 6.3 IX/IY prefix merges | ~75 bytes | Medium | ~498 |
| 6.4 Tag predicate cleanup | ~11 bytes | Low | ~509 |
| 6.5 LD, dispatch table | ~35 bytes | Medium-High | ~544 |
| 6.6 Register recognizer | ~136 bytes | High | **~680** |
| 6.7 Misc dedup | ~20 bytes | Low | **~700** |

**Realistic total: ~600-700 bytes** (~4% of 15,518-byte binary).

## Verification Strategy

1. **Before epic**: `wc -c build/antforth.com` = 15,518 bytes (baseline)
2. **After each story**: Record binary size, verify delta matches estimate
3. **Regression**: `make test && make test-repl` — all 531 tests green after every story
4. **Story 6.6 extra**: Add REPL tests verifying register words still work via recognizer

## Key Files

- `src/io.asm` — new bdos_putchar, bdos_crlf, promoted bdos_print_str/bdos_print_q_crlf (6.1)
- `src/inner_interpreter.asm` — new rpush_de, rpop_de, rpush_bc (6.2)
- `src/assembler.asm` — IX/IY pairs (6.3), tag predicates at 1157-1199 (6.4), LD, dispatch at 1585-1618 (6.5), register words at 920-1155 (6.6)
- `src/compiler.asm` — inline BDOS print loops + CRLF (6.1)
- `src/formatting.asm` — inline BDOS loops (6.1), sign-negate dedup (6.7)
- `src/control_flow.asm` — inline print loop (6.1)
- `src/system.asm` — inline print loop + CRLF (6.1)
- `src/dictionary.asm` — inline print loop + CRLF (6.1)
- `src/outer_interpreter.asm` — INTERPRET thread modification (6.6)
- `src/macros.asm` — BDOS_SAVE/BDOS_RESTORE macros (reference), DEFCODE macro (reference)
