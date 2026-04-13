# Epic 7: Shadow Register Optimization

## Context

AntForth's binary stands at **14,313 bytes** after Epic 6's code size optimization (1,034 bytes saved) and the rpop_bc follow-up (172 bytes saved). The Z80's shadow register set (BC'/DE'/HL' via EXX, AF' via EX AF,AF') is **completely unused** in the codebase. Every CODE word that needs to preserve DE (IP) and/or BC (TOS) currently uses return-stack subroutines (rpush_de/rpop_de/rpush_bc/rpop_bc) at 3 bytes per CALL. A single EXX instruction (1 byte) saves and restores BC, DE, and HL simultaneously.

This epic replaces return-stack save/restore patterns with EXX where safe, establishing a shadow-register convention and shrinking the binary further.

**Target: ~120-150 bytes saved** (~0.9% of binary).

**Safety basis:** CP/M 2.2 BDOS does not touch shadow registers. AntForth has no interrupt handlers. The shadows are pristine throughout execution.

**Convention:** EXX is a **leaf-level technique**. A word that uses EXX must not call any subroutine that also uses EXX (the nested EXX would swap back to the main set). Words using EXX may still call rpush/rpop helpers (which use IX, not EXX), BDOS helpers, and any non-EXX subroutine.

**Build/test**: `make asm` builds with sjasmplus; `make test && make test-repl` runs all 265 regression tests.

---

## Story 7.1: EXX for Build-Header Words

**Savings: ~105 bytes | Risk: Low | Effort: Medium**

Eight words save both DE (IP) and BC (TOS) to the return stack before calling `build_header` or performing LDIR bulk copies. Each has a matched `CALL rpush_de / CALL rpush_bc` at entry and `CALL rpop_bc / CALL rpop_de` at exit (12 bytes). Five of these words also have error-handler paths that unwind the return stack (6 bytes each). A single EXX at entry and exit replaces all of this.

**Words (8):**

| File | Word | Entry (bytes) | Exit (bytes) | Error Path | Total Current |
|------|------|---------------|--------------|------------|---------------|
| compiler.asm | : (COLON) | 6 | 6 | .colon_no_name (6) | 18 |
| compiler.asm | CREATE | 6 | 6 | .create_no_name (6) | 18 |
| compiler.asm | CONSTANT | 6 | 6 | — | 12 |
| assembler.asm | CODE | 6 | 6 | .code_no_name (6) | 18 |
| assembler.asm | END-CODE | 6 | 6 | — | 12 |
| assembler.asm | NEXT, | 6 | 6 | — | 12 |
| assembler.asm | LABEL | 6 | 6 | .lbl_no_name (6) | 18 |
| system.asm | MARKER | 6 | 6 | .marker_no_name (6) | 18 |

**Current total: 126 bytes** of save/restore calls.

**With EXX:**
- 8 words x 2 bytes (EXX entry + EXX exit) = 16 bytes
- 5 error paths x 1 byte (EXX restore) = 5 bytes
- **New total: 21 bytes**
- **Net savings: ~105 bytes**

**Pattern:**
```asm
; BEFORE (12 bytes save/restore):
w_COLON_cf:
        CALL    rpush_de        ; 3 bytes
        CALL    rpush_bc        ; 3 bytes
        ; ... body (calls build_header, sets state, etc.) ...
        CALL    rpop_bc         ; 3 bytes
        CALL    rpop_de         ; 3 bytes
        NEXT

; AFTER (2 bytes save/restore):
w_COLON_cf:
        EXX                     ; 1 byte — BC'/DE'/HL' now hold TOS/IP/W
        ; ... body (works in main registers freely) ...
        EXX                     ; 1 byte — TOS/IP/W restored
        NEXT
```

Error path:
```asm
; BEFORE (6 bytes):
.colon_no_name:
        CALL    rpop_bc
        CALL    rpop_de
        JP      w_ABORT_cf

; AFTER (1 byte):
.colon_no_name:
        EXX
        JP      w_ABORT_cf
```

**Risk:** Low. These words do EXX, call build_header or LDIR (which work in the main register set and don't touch shadows), then EXX back. The body never needs the original BC or DE. Clean, mechanical substitution.

**Verification:** Each word's body must be audited to confirm it does not:
1. Read BC expecting TOS (TOS is in BC', not BC)
2. Read DE expecting IP (IP is in DE', not DE)
3. Call any subroutine that itself uses EXX

---

## Story 7.2: EXX for Recognizer

**Savings: ~10-15 bytes | Risk: Medium | Effort: Medium**

The register word recognizer (`w_ASM_RECOGNIZE_cf` in assembler.asm) currently saves DE to a local memory scratch variable (`.recog_save_ip`) because the table-scan loop needs DE for string comparison. With EXX:

- Entry: EXX saves BC (c-addr TOS), DE (IP), HL to shadows (1 byte)
- Table scan: uses main BC/DE/HL freely for length comparison, name matching, pointer arithmetic
- Match exit: read tag from table, EXX to restore, set up `( tag-value true )` result
- No-match exit: EXX to restore, set up `( c-addr false )` result

This eliminates the `.recog_save_ip` scratch variable (2 bytes data) and the `LD (.recog_save_ip), DE` / `LD DE, (.recog_save_ip)` pairs (4 bytes each).

**Risk:** Medium. The recognizer has complex control flow (scan loop, match/miss branches, case-insensitive comparison). Each exit path must EXX before touching BC or DE. The UPPER macro (used for case-insensitive comparison) only touches A — safe with EXX.

---

## Story 7.3: EXX for DE-Only Words

**Savings: ~30-40 bytes | Risk: Medium-High | Effort: Medium**

Eight words currently save only DE (IP) via `CALL rpush_de` / `CALL rpop_de` (6 bytes). EXX would replace this with 2 bytes, but **EXX also swaps BC and HL**. Each word must be analysed to determine whether swapping BC (TOS) and HL (scratch) is safe or requires compensation.

**Feasible candidates (word body consumes TOS early, doesn't need original BC after EXX):**

| File | Word | Current (bytes) | Analysis Needed |
|------|------|-----------------|-----------------|
| memory.asm | FILL | 6 | LDIR clobbers BC — TOS already consumed |
| memory.asm | MOVE | 6 | LDIR/LDDR clobbers BC — TOS consumed |
| stack_ops.asm | ROLL | 6 | LDDR — TOS consumed into count register |
| io.asm | ACCEPT | 6 | BDOS call — TOS consumed into buffer setup |

**Needs deeper analysis (word body references BC as TOS throughout):**

| File | Word | Current (bytes) | Analysis Needed |
|------|------|-----------------|-----------------|
| strings.asm | WORD | 6 | BC = c-addr used as delimiter throughout scan |
| strings.asm | >NUMBER | 6 | BC = part of double-number accumulator |
| strings.asm | NUMBER? | 6 | BC = c-addr passed to >NUMBER |
| strings.asm | ( | 6 | BC = TOS, but word is ( -- ), TOS may be consumed early |

For words where BC is needed after EXX, options include:
1. `PUSH BC / EXX` at entry (2 bytes) and `EXX / POP BC` at exit (2 bytes) — saves 2 bytes vs current 6
2. Restructure the word body to consume BC before EXX
3. Leave as CALL rpush_de/rpop_de (no change)

**Formatting words (., U., .R, .S) are excluded** — they call print helpers that use BC for values and DE as scratch throughout the output chain. EXX would require restructuring the entire print pipeline. Not worth the complexity for 4 bytes per word.

**Risk:** Medium-High. Each word requires individual analysis of register flow. The "consumes TOS early" words (FILL, MOVE, ROLL, ACCEPT) are straightforward. The string/parsing words need careful verification.

---

## Story Ordering and Dependencies

```
7.1 (build_header words) ──> establishes EXX convention, validates on real hardware
7.2 (recognizer) ──────────> independent, but benefits from 7.1 proving EXX is safe
7.3 (DE-only words) ───────> last, highest analysis effort, depends on 7.1 convention
```

Story 7.1 must land first — it establishes that EXX works correctly in the AntForth register environment. Stories 7.2 and 7.3 can proceed in either order after 7.1.

## Savings Summary

| Story | Savings | Risk | Cumulative |
|-------|---------|------|------------|
| 7.1 EXX for build_header words | ~105 bytes | Low | ~105 |
| 7.2 EXX for recognizer | ~12 bytes | Medium | ~117 |
| 7.3 EXX for DE-only words | ~20-40 bytes | Medium-High | **~137-157** |

**Realistic total: ~120-150 bytes** (~0.9% of 14,313-byte binary).

Combined with Epic 6: 15,519 → ~14,170 = **~1,350 bytes total optimization** across both epics (~8.7% of original binary).

## Verification Strategy

1. **Before epic**: `wc -c build/antforth.com` = 14,313 bytes (baseline)
2. **After each story**: Record binary size, verify delta matches estimate
3. **Regression**: `make test && make test-repl` — all 265 tests green after every story
4. **Manual hardware test**: Verify on MicroBeast after each story — EXX correctness cannot be fully validated by emulator alone if BDOS behavior differs

## Key Files

- `src/compiler.asm` — COLON, CREATE, CONSTANT (7.1)
- `src/assembler.asm` — CODE, END-CODE, NEXT,, LABEL, recognizer (7.1, 7.2)
- `src/system.asm` — MARKER (7.1)
- `src/memory.asm` — FILL, MOVE (7.3)
- `src/stack_ops.asm` — ROLL (7.3)
- `src/io.asm` — ACCEPT (7.3)
- `src/strings.asm` — WORD, >NUMBER, NUMBER?, ( (7.3)
- `src/inner_interpreter.asm` — rpush_de/rpop_de/rpush_bc/rpop_bc (reference, NOT modified)
