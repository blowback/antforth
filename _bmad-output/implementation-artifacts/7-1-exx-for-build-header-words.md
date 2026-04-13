# Story 7.1: EXX for Build-Header Words

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want the return-stack save/restore patterns in build-header words replaced with the Z80 EXX instruction,
so that the binary shrinks by ~100+ bytes while establishing the shadow-register convention for future stories.

## Acceptance Criteria

1. **Given** the 7 standard words (COLON, CREATE, CODE, END-CODE, NEXT,, LABEL, MARKER) each using `CALL rpush_de / CALL rpush_bc` at entry and `CALL rpop_bc / CALL rpop_de` at exit **When** each pair is replaced with `EXX` (1 byte) at entry and `EXX` (1 byte) at exit **Then** `make test && make test-repl` passes all 265 regression tests with zero failures.

2. **Given** the 5 error-handler paths (.colon_no_name, .create_no_name, .code_no_name, .lbl_no_name, .marker_no_name) each using `CALL rpop_bc / CALL rpop_de` to unwind **When** each is replaced with a single `EXX` **Then** all tests pass.

3. **Given** w_CONSTANT_cf uses a non-standard exit pattern (manual IX unwind to access the saved value mid-body) **When** it is converted to use EXX with appropriate mid-body register access **Then** all tests pass and CONSTANT still emits the correct value into the dictionary body.

4. **Given** all changes land **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 80 bytes smaller than the pre-story baseline (14,313 bytes). **Actual: 14,181 bytes (−132 bytes).**

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #4)
  - [x] 0.1 `make asm && wc -c build/antforth.com` — confirm 14,313 bytes
  - [x] 0.2 `make test && make test-repl` — confirm all tests pass

- [x] Task 1: Convert w_COLON_cf and w_CREATE_cf in `src/compiler.asm` (AC: #1, #2)
  - [x] 1.1 w_COLON_cf: Replace `CALL rpush_de / CALL rpush_bc` (6 bytes) with `EXX` (1 byte) at entry
  - [x] 1.2 w_COLON_cf: Replace `CALL rpop_bc / CALL rpop_de` (6 bytes) with `EXX` (1 byte) at exit
  - [x] 1.3 .colon_no_name: Replace `CALL rpop_bc / CALL rpop_de` (6 bytes) with `EXX` (1 byte)
  - [x] 1.4 w_CREATE_cf: Same entry/exit pattern as COLON
  - [x] 1.5 .create_no_name: Same as .colon_no_name
  - [x] 1.6 `make asm && make test && make test-repl` — all tests pass

- [x] Task 2: Convert w_CONSTANT_cf in `src/compiler.asm` (AC: #3)
  - [x] 2.1 Replace entry `CALL rpush_de / CALL rpush_bc` with `EXX`
  - [x] 2.2 Replace mid-body value access: instead of reading from return stack via IX, use `PUSH HL / EXX` to swap back to access BC (value), then set up and swap again (see Dev Notes for approach)
  - [x] 2.3 Replace manual exit unwind (INC IX x4 + LD D/E from IX + INC IX x2 + POP BC) with the much shorter EXX-based exit
  - [x] 2.4 .const_no_name: Replace manual unwind with EXX + POP BC
  - [x] 2.5 `make asm && make test && make test-repl` — all tests pass

- [x] Task 3: Convert w_CODE_cf and w_END_CODE_cf in `src/assembler.asm` (AC: #1, #2)
  - [x] 3.1 w_CODE_cf: Replace entry/exit CALL pairs with EXX
  - [x] 3.2 .code_no_name: Replace unwind with EXX
  - [x] 3.3 w_END_CODE_cf: Replace entry/exit CALL pairs with EXX (note: helpers asm_check_unresolved, asm_unlink_labels, asm_reset_label_state "clobber DE/BC freely" per comment — this is fine, they clobber MAIN registers, not shadows)
  - [x] 3.4 `make asm && make test && make test-repl` — all tests pass

- [x] Task 4: Convert w_NEXT_COMMA_cf and w_LABEL_cf in `src/assembler.asm` (AC: #1, #2)
  - [x] 4.1 w_NEXT_COMMA_cf: Replace entry/exit with EXX. LDIR in body uses main BC/DE/HL — all free after EXX.
  - [x] 4.2 w_LABEL_cf: Replace entry/exit with EXX. Note: body uses main DE for HERE check (line ~2233) and main BC for bh_old_bucket_head loads — all fine, main registers are scratch after EXX.
  - [x] 4.3 .lbl_no_name: Replace unwind with EXX
  - [x] 4.4 `make asm && make test && make test-repl` — all tests pass

- [x] Task 5: Convert w_MARKER_cf in `src/system.asm` (AC: #1, #2)
  - [x] 5.1 w_MARKER_cf: Replace entry/exit with EXX. LDIR in body uses main BC/DE/HL — all free. Post-LDIR DE value used for HERE update before EXX exit.
  - [x] 5.2 .marker_no_name: Replace unwind with EXX
  - [x] 5.3 `make asm && make test && make test-repl` — all tests pass

- [x] Task 6: Final verification (AC: #4)
  - [x] 6.1 `make test && make test-repl` — all tests green
  - [x] 6.2 `wc -c build/antforth.com` — record final size, compute delta from 14,313 baseline
  - [x] 6.3 Verify savings >= 80 bytes

## Dev Notes

### The EXX Convention

**EXX** (opcode 0xD9, 1 byte) simultaneously swaps BC/DE/HL with BC'/DE'/HL'. This means:
- **After EXX at entry**: BC' = TOS, DE' = IP, HL' = W (all preserved in shadows). Main BC/DE/HL are free scratch.
- **After EXX at exit**: BC = TOS, DE = IP, HL = W (restored from shadows). Whatever was in the main registers is swapped away.

**Why this is safe:**
- CP/M 2.2 BDOS does not touch shadow registers
- AntForth has no interrupt handlers
- No existing code uses EXX — shadows are pristine
- `build_header`, `asm_check_unresolved`, `asm_unlink_labels`, `asm_reset_label_state` all work in the MAIN register set — they cannot affect the shadow registers

**Leaf-level rule:** Words using EXX must NOT call any subroutine that also uses EXX. Currently no subroutines use EXX, so this is trivially satisfied. The rpush/rpop helpers use IX (return stack), not EXX — they remain callable from EXX-using words if needed.

### Conversion Pattern (Standard — 7 words)

```asm
; BEFORE (12 bytes save/restore):
w_COLON_cf:
        CALL    rpush_de        ; 3 bytes
        CALL    rpush_bc        ; 3 bytes
        ; ... body ...
        CALL    rpop_bc         ; 3 bytes
        CALL    rpop_de         ; 3 bytes
        NEXT

; AFTER (2 bytes save/restore):
w_COLON_cf:
        EXX                     ; 1 byte — TOS/IP/W safe in shadows
        ; ... body (main BC/DE/HL are free scratch) ...
        EXX                     ; 1 byte — TOS/IP/W restored
        NEXT
```

Savings per word: 10 bytes. Error path savings: 5 bytes each.

### Conversion Pattern (CONSTANT — special case)

w_CONSTANT_cf is unique: it needs to access the saved TOS value (the constant's value) DURING the body to emit it into the dictionary. With return-stack save, this was `LD B,(IX+1) / LD C,(IX+0)`. With EXX, the value is in BC' and can only be accessed by swapping back.

**Approach:**

```asm
w_CONSTANT_cf:
        EXX                             ; Save TOS (value), IP, W to shadows
        ; Main registers now free for build_header
        XOR     A
        CALL    build_header
        JR      C, .const_no_name

        ; HL = code field — emit JP DOCON
        LD      (HL), 0xC3
        INC     HL
        LD      (HL), LOW DOCON
        INC     HL
        LD      (HL), HIGH DOCON
        INC     HL

        ; Need the constant value from BC' (shadow).
        ; Save current HL (body pointer) to stack, swap to get value.
        PUSH    HL                      ; save body pointer (main stack)
        EXX                             ; BC = value, DE = IP, HL = old W
        LD      A, C                    ; A = value low byte
        LD      D, B                    ; D = value high byte (temp)
        POP     HL                      ; HL = body pointer (from main stack)
        ; Now we have value in A/D and body pointer in HL.
        ; But we're back in the "real" register set. We need to emit
        ; and then we're done — TOS was consumed by CONSTANT.
        LD      (HL), A                 ; Store low byte
        INC     HL
        LD      D, B                    ; Wait, we already have D=high from above... 
        ; Actually let me rethink.
```

**Alternative approach (simpler):**

```asm
w_CONSTANT_cf:
        EXX                             ; Save TOS (value), IP, W
        XOR     A
        CALL    build_header
        JR      C, .const_no_name

        ; Emit JP DOCON
        LD      (HL), 0xC3
        INC     HL
        LD      (HL), LOW DOCON
        INC     HL
        LD      (HL), HIGH DOCON
        INC     HL

        ; Emit constant value: swap back briefly to get it
        EXX                             ; BC = saved value (TOS)
        LD      A, C                    ; save low byte
        EXX                             ; back to main set, HL still = body pos
        LD      (HL), A                 ; emit low byte
        INC     HL
        EXX                             ; BC = saved value again
        LD      A, B                    ; save high byte
        EXX                             ; back to main
        LD      (HL), A                 ; emit high byte
        INC     HL

        ; Update HERE
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; Restore IP — EXX back to real registers
        EXX                             ; BC = value (consumed), DE = IP
        ; TOS consumed, pop new TOS from parameter stack
        POP     BC
        NEXT

.const_no_name:
        EXX                             ; restore DE = IP, BC = value (consumed)
        POP     BC                      ; pop new TOS
        JP      w_ABORT_cf
```

This uses 4 extra EXX instructions (4 bytes) for the mid-body value access. The dev agent should find the most byte-efficient approach — the key constraint is that the constant value is in BC' and must be emitted to the body via HL (which is in the main set after build_header).

**Important:** The current code's error path (.const_no_name) has manual IX unwind (INC IX x4) plus manual DE restore from IX. With EXX, ALL of that becomes just `EXX / POP BC / JP w_ABORT_cf`.

### Register Contract (critical)

- `BC` = TOS, `DE` = IP, `SP` = parameter stack, `IX` = return stack, `IY` = user pointer, `HL`/`AF` = scratch
- After EXX: BC' = TOS, DE' = IP, HL' = W (preserved). Main BC/DE/HL are free scratch.
- IY and IX are NOT affected by EXX — they are the same in both register sets.
- AF is NOT affected by EXX — only EX AF,AF' swaps AF.
- SP is NOT affected by EXX.

### What Not to Convert

- **DOCOL, EXIT, DODOES** — hot paths, already optimized inline. Do not touch.
- **DOMARKER** — uses LDIR that clobbers BC/DE in a way that requires explicit IX-based restore. Not a clean EXX candidate.
- Any subroutine that might be called from another EXX-using word (violates leaf-level rule).

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Previous Story Learnings (6.7 + rpop_bc conversion)

- IX-prefixed instructions are 3 bytes (LD r,(IX+d)) and 2 bytes (INC/DEC IX), not the 1-2 bytes often assumed. This is why rpop_bc conversion saved 172 bytes instead of the estimated 61.
- Build-test-verify after each task catches issues early.
- Record baseline size before any changes.
- sjasmplus local label scoping: `.label` is scoped per parent label.
- All 265 REPL tests + assembly tests should pass at each checkpoint.

### Project Structure Notes

- `src/compiler.asm` — COLON, CREATE, CONSTANT (Task 1-2)
- `src/assembler.asm` — CODE, END-CODE, NEXT,, LABEL (Task 3-4)
- `src/system.asm` — MARKER (Task 5)
- `src/inner_interpreter.asm` — rpush_de/rpop_de/rpush_bc/rpop_bc subroutines (reference only, NOT modified)
- No new subroutines needed for EXX itself — EXX is a single Z80 instruction. However, a `rpop_bc` subroutine was introduced as a companion to the existing `rpop_de`, and two non-EXX call sites (w_DOT_S_cf, w_QUERY_cf) were refactored to use it

### Byte Budget

| Change | Sites | Old (bytes) | New (bytes) | Savings |
|--------|-------|-------------|-------------|---------|
| Standard entry (7 words) | 7 | 7 × 6 = 42 | 7 × 1 = 7 | 35 |
| Standard exit (7 words) | 7 | 7 × 6 = 42 | 7 × 1 = 7 | 35 |
| Error paths (5) | 5 | 5 × 6 = 30 | 5 × 1 = 5 | 25 |
| CONSTANT entry | 1 | 6 | 1 | 5 |
| CONSTANT exit + value access | 1 | ~21 | ~8 | ~13 |
| CONSTANT error path | 1 | ~15 | ~4 | ~11 |
| **Total** | | **~156** | **~33** | **~124** |

Note: CONSTANT savings estimate depends on the mid-body approach. Actual savings will be measured. Conservative target: 80+ bytes.

### References

- [Source: src/compiler.asm:360-404] — w_COLON_cf + .colon_no_name
- [Source: src/compiler.asm:558-591] — w_CREATE_cf + .create_no_name
- [Source: src/compiler.asm:598-647] — w_CONSTANT_cf + .const_no_name
- [Source: src/assembler.asm:1180-1233] — w_CODE_cf + .code_no_name
- [Source: src/assembler.asm:1244-1284] — w_END_CODE_cf
- [Source: src/assembler.asm:2160-2177] — w_NEXT_COMMA_cf
- [Source: src/assembler.asm:2224-2303] — w_LABEL_cf + .lbl_no_name
- [Source: src/system.asm:23-80] — w_MARKER_cf + .marker_no_name
- [Source: docs/shadow-register-survey.md] — Full shadow register survey
- [Source: _bmad-output/planning-artifacts/epic7-shadow-register-optimization.md] — Epic specification

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no failures.

### Completion Notes List

- Task 0: Baseline confirmed at 14,313 bytes, all 265 tests passing.
- Task 1: Converted w_COLON_cf and w_CREATE_cf entry/exit/error paths from rpush/rpop pairs to EXX. Saved 30 bytes. All tests pass.
- Task 2: Converted w_CONSTANT_cf — used alternating EXX swaps to access shadow BC (constant value) mid-body for dictionary emission. Replaced complex IX-based exit unwind with simple EXX + POP BC. Saved 31 bytes (61 cumulative). All tests pass.
- Task 3: Converted w_CODE_cf and w_END_CODE_cf. END-CODE's helpers (asm_check_unresolved, asm_unlink_labels, asm_reset_label_state) clobber main registers only — shadow registers safe. Saved 25 bytes (86 cumulative). All tests pass.
- Task 4: Converted w_NEXT_COMMA_cf and w_LABEL_cf. Removed vestigial INC IX from .lbl_no_name error path (ABORT resets IX). Saved 27 bytes (113 cumulative). All tests pass.
- Task 5: Converted w_MARKER_cf. Removed vestigial INC IX from .marker_no_name error path. Saved 17 bytes (130 cumulative). All tests pass.
- Task 6: Final verification — 14,181 bytes (132 bytes saved, exceeds 80-byte target). All 265 REPL + assembly tests pass.
- Code Review Fix: Removed stray INC IX in w_QUERY_cf (outer_interpreter.asm) left over from inline-to-subroutine rpop_bc refactoring — was corrupting return stack by +1 byte per QUERY call (masked by QUIT's RP! reset). Saved 2 additional bytes.

### Change Log

- 2026-04-13: Replaced rpush_de/rpush_bc/rpop_bc/rpop_de call pairs with EXX in 8 words (COLON, CREATE, CONSTANT, CODE, END-CODE, NEXT,, LABEL, MARKER) and 5 error paths. Also introduced rpop_bc subroutine and refactored 2 non-EXX call sites. Binary reduced 14,313 → 14,181 bytes (−132 bytes).
- 2026-04-13: [Code Review] Fixed stray INC IX bug in w_QUERY_cf (outer_interpreter.asm:128) — return stack was misaligned +1 byte per QUERY call, masked by QUIT's RP! reset.

### File List

- src/compiler.asm — w_COLON_cf, w_CREATE_cf, w_CONSTANT_cf converted to EXX
- src/assembler.asm — w_CODE_cf, w_END_CODE_cf, w_NEXT_COMMA_cf, w_LABEL_cf converted to EXX
- src/system.asm — w_MARKER_cf converted to EXX
- src/inner_interpreter.asm — Added rpop_bc subroutine (companion to existing rpop_de)
- src/formatting.asm — w_DOT_S_cf .dots_done: inline rpop_bc replaced with CALL rpop_bc
- src/outer_interpreter.asm — w_QUERY_cf inline rpop_bc/rpop_de replaced with CALL rpop_bc/rpop_de
