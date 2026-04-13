# Story 7.2: EXX for Recognizer

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want the register word recognizer's scratch-variable save/restore pattern replaced with EXX,
so that the binary shrinks by ~10-15 bytes and the recognizer uses the established shadow-register convention.

## Acceptance Criteria

1. **Given** `w_ASM_RECOGNIZE_cf` currently saves DE (IP) to `.recog_save_ip` (a 2-byte scratch variable) via `LD (.recog_save_ip), DE` at entry and restores via `LD DE, (.recog_save_ip)` at each exit path **When** the save/restore is replaced with EXX at entry and EXX before each exit **Then** `make test && make test-repl` passes all 265 regression tests with zero failures.

2. **Given** the two scratch variables `.recog_name` (2 bytes) and `.recog_len` (1 byte) are used to pass the search name pointer and length into the scan loop because BC/DE/HL are all occupied **When** EXX frees main BC/DE/HL for scratch use **Then** the `.recog_name` and `.recog_len` variables are eliminated, replaced by registers, and all tests pass.

3. **Given** the `.recog_save_ip` scratch variable (2 bytes data) is no longer referenced **When** it and any other eliminated scratch variables are removed **Then** the binary shrinks and all tests pass.

4. **Given** all changes land **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 8 bytes smaller than the pre-story baseline (14,181 bytes).

5. **Given** the `.recog_fast_false` early-exit path does NOT save DE (it short-circuits before the save) **When** EXX is used **Then** `.recog_fast_false` must NOT execute EXX (DE was never swapped), preserving the current fast-fail behavior.

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #4)
  - [x] 0.1 `make asm && wc -c build/antforth.com` — confirm 14,181 bytes
  - [x] 0.2 `make test && make test-repl` — confirm all 265 tests pass

- [x] Task 1: Analyze register flow and plan EXX conversion (AC: #1, #2, #5)
  - [x] 1.1 Map the current register usage through every path of w_ASM_RECOGNIZE_cf:
    - Entry: BC = c-addr (TOS), DE = IP, HL = scratch
    - After asm_mode check: DE still = IP
    - After saving IP: DE freed for scratch use
    - Scan loop: HL = table pointer, DE = name pointer (from .recog_name), B = loop counter, C = comparison char, A = scratch
    - Match exit: reads tag from table, restores DE from scratch, pushes result
    - No-match exit: restores DE from scratch, restores c-addr from .recog_name
    - Fast-false exit: BC = c-addr (untouched), DE = IP (untouched)
  - [x] 1.2 Plan EXX register mapping:
    - After EXX at entry: BC' = c-addr, DE' = IP, HL' = W (all in shadows). Main BC/DE/HL free.
    - Use a main register (e.g., D or E) to hold the search length instead of .recog_len
    - Use a main register pair (e.g., DE initially, then save to stack when DE needed for comparison) for name pointer instead of .recog_name
    - Or: keep name pointer in a register pair throughout since main set is fully free
  - [x] 1.3 Verify UPPER macro safety: UPPER only touches A register (CP, JR, SUB) — confirmed safe with EXX.
  - [x] 1.4 Verify no subroutines are called from the recognizer body — confirmed: the loop is entirely inline, no CALL instructions. EXX leaf-level rule is satisfied.

- [x] Task 2: Convert w_ASM_RECOGNIZE_cf to use EXX (AC: #1, #2, #3)
  - [x] 2.1 Add EXX after the asm_mode fast-fail check (line 893 area). The EXX must be AFTER the `JR Z, .recog_fast_false` so the fast path never touches shadows.
  - [x] 2.2 Replace `LD (.recog_save_ip), DE` with nothing (EXX already saved DE to DE')
  - [x] 2.3 Replace `LD (.recog_len), A` and `LD (.recog_name), HL` with register assignments — main BC/DE/HL are now free scratch:
    - Store length in a register (e.g., keep in a register that survives the loop, or push to stack)
    - Store name pointer in a register pair
  - [x] 2.4 Update the scan loop to use registers instead of memory loads:
    - Replace `LD A, (.recog_len)` with register read
    - Replace `LD DE, (.recog_name)` with register load (may need PUSH/POP around the comparison loop since DE is used for name pointer during char compare)
  - [x] 2.5 Update match exit path: replace `LD DE, (.recog_save_ip)` with `EXX` to restore BC (c-addr consumed — not needed), DE (IP), HL (W)
  - [x] 2.6 Update no-match exit path: replace `LD DE, (.recog_save_ip)` and `LD HL, (.recog_name) / DEC HL` reconstruction of c-addr with: `EXX` to restore BC = original c-addr, DE = IP
  - [x] 2.7 Verify .recog_fast_false is UNCHANGED — it must not EXX since no EXX was done on entry in that path
  - [x] 2.8 Remove `.recog_save_ip`, `.recog_len`, `.recog_name` scratch variable declarations (5 bytes of data eliminated)
  - [x] 2.9 `make asm && make test && make test-repl` — all tests pass

- [x] Task 3: Final verification (AC: #4)
  - [x] 3.1 `make test && make test-repl` — all 265 tests green
  - [x] 3.2 `wc -c build/antforth.com` — record final size, compute delta from 14,181 baseline: 14,141 bytes (−40 bytes, includes review fix)
  - [x] 3.3 Verify savings >= 8 bytes — PASS: 40 bytes saved

## Dev Notes

### Current Code Analysis (src/assembler.asm lines 886-975)

The recognizer has this structure:

```
w_ASM_RECOGNIZE_cf:
    asm_mode check → fast_false (BC=c-addr, DE=IP untouched)
    LD (.recog_save_ip), DE     ; 4 bytes — save IP to scratch
    HL = c-addr from BC
    A = (HL) = name length
    LD (.recog_len), A          ; 3 bytes — save length to scratch
    INC HL
    LD (.recog_name), HL        ; 3 bytes — save name ptr to scratch
    HL = asm_reg_table

.recog_next:                     ; scan loop
    A = (HL) = entry length
    JR Z, .recog_no_match
    B = entry length
    A = (.recog_len)             ; 3 bytes — reload length from scratch
    CP B → skip if mismatch
    PUSH HL / INC HL
    DE = (.recog_name)           ; 4 bytes — reload name ptr from scratch
    compare loop (DJNZ)

match:
    C = tag, POP HL
    DE = (.recog_save_ip)        ; 4 bytes — restore IP from scratch
    PUSH BC, BC = TRUE, NEXT

.recog_cmp_fail:
    POP HL, B = (HL), fall through to skip

.recog_skip:
    advance HL past entry, JR .recog_next

.recog_no_match:
    DE = (.recog_save_ip)        ; 4 bytes — restore IP from scratch
    HL = (.recog_name)           ; 4 bytes — restore name ptr from scratch
    DEC HL → c-addr
    BC = HL, PUSH BC, BC = 0, NEXT

.recog_fast_false:               ; NO scratch access — BC/DE untouched
    PUSH BC, BC = 0, NEXT

; Scratch data (5 bytes):
.recog_len:       DB 0           ; 1 byte
.recog_name:      DW 0           ; 2 bytes
.recog_save_ip:   DW 0           ; 2 bytes
```

### Byte Savings Breakdown

**Eliminated (current cost):**
- `LD (.recog_save_ip), DE` at entry: 4 bytes
- `LD (.recog_len), A` at entry: 3 bytes
- `LD (.recog_name), HL` at entry: 3 bytes
- `LD A, (.recog_len)` in scan loop: 3 bytes
- `LD DE, (.recog_name)` in scan loop: 4 bytes
- `LD DE, (.recog_save_ip)` in match exit: 4 bytes
- `LD DE, (.recog_save_ip)` in no-match exit: 4 bytes
- `LD HL, (.recog_name)` in no-match exit: 4 bytes
- `.recog_len` data: 1 byte
- `.recog_name` data: 2 bytes
- `.recog_save_ip` data: 2 bytes
- **Total eliminated: ~34 bytes**

**Added (new cost):**
- `EXX` at entry (after fast-fail check): 1 byte
- `EXX` at match exit: 1 byte
- `EXX` at no-match exit: 1 byte
- Register shuffling to hold length and name pointer: variable (depends on register allocation strategy)
- **Estimated new cost: ~12-18 bytes**

**Estimated net savings: ~10-20 bytes** (depends on register allocation approach)

### EXX Conversion Strategy

After EXX at entry, the main register set is completely free:
- BC' = c-addr (TOS), DE' = IP, HL' = W — all safe in shadows
- Main BC, DE, HL, A — all available for scratch

**Recommended register allocation after EXX:**

Before EXX, BC = c-addr. So we need to extract the name length and name pointer from c-addr before or after EXX.

**Approach:**
1. After the fast-fail check, extract length and name pointer from BC (c-addr) into registers
2. Then EXX
3. Or: EXX first, then access c-addr from BC' by doing a brief EXX swap back

**Simpler approach:**
1. Keep BC = c-addr until we extract what we need
2. `LD H, B / LD L, C` — HL = c-addr
3. `LD A, (HL)` — A = length
4. `INC HL` — HL = name pointer
5. Now EXX — saves BC (c-addr, but we already extracted what we need), DE (IP), HL (name pointer — wait, this gets saved too)

**Best approach — EXX AFTER extracting name info:**
```asm
w_ASM_RECOGNIZE_cf:
    LD A, (asm_mode) / OR A / JR Z, .recog_fast_false
    ; BC = c-addr, extract name info while BC is live
    LD H, B / LD L, C          ; HL = c-addr
    LD A, (HL)                 ; A = name length
    INC HL                     ; HL = name pointer
    EXX                        ; BC' = c-addr, DE' = IP, HL' = name pointer
    ; Main registers now free. A still = length (not affected by EXX).
    ; Store length: use E or another register
    LD E, A                    ; E = search length (persists across loop iterations)
    LD HL, asm_reg_table       ; HL = table scan pointer

.recog_next:
    LD A, (HL)                 ; table entry length
    OR A
    JR Z, .recog_no_match
    LD B, A                    ; B = entry length / loop counter
    CP E                       ; compare with search length (in E)
    JR NZ, .recog_skip

    ; Lengths match — compare names
    PUSH HL                    ; save table position
    INC HL                     ; HL → table name bytes
    EXX                        ; HL = name pointer (from shadows)
    PUSH HL                    ; save name pointer on stack
    EXX                        ; back to main set
    POP DE                     ; DE = name pointer (from shadow HL')
    ; ...or use a different approach to get name pointer into DE
```

**Note:** The dev agent should find the most byte-efficient register allocation. The key insight is:
- After EXX, HL' holds the name pointer (saved automatically by EXX)
- A is not affected by EXX, so the length survives the swap
- The scan loop needs: table pointer (HL), name pointer (DE for comparison), length (B for DJNZ and a register for the search length)

**Alternative:** Instead of putting name pointer in HL before EXX, put it elsewhere:
```asm
    LD H, B / LD L, C         ; HL = c-addr
    LD D, (HL)                ; D = name length
    INC HL                    ; HL → name bytes
    ; Don't EXX yet — push name pointer
    PUSH HL                   ; save name pointer on machine stack
    EXX                       ; BC' = c-addr, DE' = IP, HL' now irrelevant
    ; Main registers free. D from before EXX is now in D' (shadow).
    ; Hmm, that swapped D away too...
```

This shows the challenge: whatever you put in D/E/B/C/H/L before EXX gets swapped into shadows. **A is the only register that survives EXX.** So the pattern must be:
1. Extract name length into A
2. Push name pointer to machine stack (SP, not affected by EXX)
3. EXX
4. Move A to a main register for persistent storage
5. POP name pointer from stack

Or restructure to avoid the stack by using IY-relative storage (but IY is the user pointer — not free).

**The dev agent must work out the optimal byte-efficient approach.** The savings come from eliminating the 5 bytes of scratch data and the repeated memory loads/stores (replaced by register operations and a couple of PUSH/POPs).

### Critical Exit Path Rules

1. **Match exit:** Must EXX to restore DE = IP before NEXT. BC will become the original c-addr from shadows, but it's overwritten with TRUE anyway. The tag value must be assembled before EXX (it comes from the table which is in main-set HL).
2. **No-match exit:** Must EXX to restore BC = original c-addr and DE = IP. After EXX, BC = c-addr (already correct from shadows!). No need to reconstruct c-addr from .recog_name.
3. **Fast-false exit (.recog_fast_false):** Must NOT EXX — this path is taken before EXX entry. BC = c-addr and DE = IP are already in the main set.

### UPPER Macro Safety

The UPPER macro (src/macros.asm:17-23) operates exclusively on register A:
```asm
    CP 'a'
    JR C, .not_lower
    CP 'z' + 1
    JR NC, .not_lower
    SUB 0x20
.not_lower:
```
No other registers are touched. Fully safe to use between EXX pairs.

### Leaf-Level Rule

No CALL instructions exist in the recognizer body — the entire scan loop is inline code. The EXX leaf-level convention is trivially satisfied. The only subroutine calls in the file (build_header, etc.) are in other words, not the recognizer.

### Register Contract

- `BC` = TOS, `DE` = IP, `SP` = parameter stack, `IX` = return stack, `IY` = user pointer, `HL`/`AF` = scratch
- After EXX: BC' = TOS, DE' = IP, HL' = whatever HL held. Main BC/DE/HL free.
- IY, IX, SP, AF are NOT affected by EXX.

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Previous Story Learnings (7.1)

- EXX is safe in AntForth: CP/M 2.2 BDOS does not touch shadows, no ISRs, no existing EXX users.
- The EXX convention is now established: 8 words in 7.1 use EXX successfully. All 265 tests pass.
- After EXX at entry: main BC/DE/HL are free scratch. Subroutines like build_header work in the main set — no shadow interference.
- Error paths only need a single EXX to restore all three register pairs, replacing multi-instruction unwind sequences.
- Code review caught a stray INC IX in w_QUERY_cf left from rpop_bc refactoring — always audit for vestigial instructions after refactoring.
- Binary went 14,313 → 14,181 (−132 bytes) in 7.1.

### Key Existing Tests for Recognizer

The following REPL tests exercise the recognizer and must all continue passing:
- Test 261: case-insensitive register names (`b a LD,` same as `B A LD,`)
- Test 262: condition codes (`NZ RET,` produces correct opcode)
- Test 263: recognizer fast-fails outside CODE context
- Test 264: indirect register names (`(HL) INC,`)
- Test 265: AF' register (`AF AF' EX,`)

### Project Structure Notes

- `src/assembler.asm` — w_ASM_RECOGNIZE_cf (lines 886-975): the only file modified in this story
- `src/macros.asm` — UPPER macro definition (reference only, NOT modified)
- `src/inner_interpreter.asm` — rpush/rpop subroutines (reference only, NOT modified)
- No new files or subroutines needed

### Byte Budget

| Change | Current (bytes) | New (bytes) | Savings |
|--------|-----------------|-------------|---------|
| IP save/restore (entry + 2 exits) | 4 + 4 + 4 = 12 | 1 + 1 + 1 = 3 (EXX) | 9 |
| Name length save/reload | 3 + 3 = 6 | ~1-2 (register) | ~4-5 |
| Name pointer save/reload (entry + loop + no-match) | 3 + 4 + 4 = 11 | ~3-5 (PUSH/POP or register) | ~6-8 |
| c-addr reconstruction in no-match | 4 (LD HL, DEC HL, LD B,H, LD L,C) | 0 (BC' = c-addr via EXX) | ~4 |
| Scratch data elimination | 5 bytes data | 0 | 5 |
| **Estimated total** | **~34** | **~10-16** | **~12-20** |

Conservative target: 8+ bytes saved.

### References

- [Source: src/assembler.asm:886-975] — w_ASM_RECOGNIZE_cf + scratch variables
- [Source: src/assembler.asm:840-878] — asm_reg_table (register/condition lookup table)
- [Source: src/macros.asm:17-23] — UPPER macro definition
- [Source: _bmad-output/planning-artifacts/epic7-shadow-register-optimization.md#Story 7.2] — Epic specification
- [Source: _bmad-output/implementation-artifacts/7-1-exx-for-build-header-words.md] — Previous story (EXX convention established)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None — clean implementation, no issues encountered.

### Completion Notes List

- Baseline confirmed: 14,181 bytes, 265/265 tests pass
- Replaced all 3 scratch variables (.recog_save_ip, .recog_len, .recog_name) with EXX shadow registers and main-set register allocation
- Register allocation: C = search length (persistent), DE = name pointer (PUSH/POP around comparison), A = length transfer (survives EXX)
- Replaced `LD C, A / LD A, (HL) / CP C` with `CP (HL)` — required because C now holds the persistent search length (not optional)
- Replaced `LD C, B / LD B, 0 / ADD HL, BC` skip advance with DJNZ loop (saves 1 byte, avoids clobbering C)
- No-match exit simplified from 10 instructions to 4 (EXX restores BC = c-addr, DE = IP directly)
- .recog_fast_false unchanged — correctly avoids EXX since no swap was done on that path
- Code review merged `.recog_no_match` / `.recog_fast_false` duplicate tails via fall-through (−11 bytes)
- Final binary: 14,141 bytes (−40 bytes from baseline, exceeds 8-byte target by 5x)
- All 265 tests pass (assembly + REPL), including all 7 recognizer-specific tests (259-265)

### Change Log

- 2026-04-13: Replaced scratch-variable save/restore pattern in w_ASM_RECOGNIZE_cf with EXX shadow registers. Eliminated .recog_save_ip, .recog_len, .recog_name. Binary: 14,181 → 14,152 (−29 bytes).
- 2026-04-13: Code review: merged duplicate `.recog_no_match`/`.recog_fast_false` tails via fall-through; fixed CP (HL) completion note; restored UPPER macro warning comment. Binary: 14,152 → 14,141 (−11 bytes).

### File List

- src/assembler.asm (modified) — w_ASM_RECOGNIZE_cf rewritten to use EXX; scratch variables removed
