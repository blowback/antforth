# Story 6.4: Tag Predicate Cleanup + Dead Code Removal

Status: done

## Story

As a system maintainer,
I want the dead `asm_is_cond_tag` predicate removed and the remaining four tag predicates refactored to share a common tail,
so that the binary shrinks by ~11 bytes without changing any observable behaviour.

## Acceptance Criteria

1. **Given** `asm_is_cond_tag` is defined but never called **When** it is removed **Then** `make asm` succeeds and `make test && make test-repl` passes all regression tests with zero failures.

2. **Given** the four remaining predicates (`asm_is_imm_tag`, `asm_is_label_tag`, `asm_is_reg16_tag`, `asm_is_indirect_tag`) share identical body structure **When** they are refactored to use JR-into-shared-tail **Then** all 21 call sites continue to work correctly, Z flag semantics are preserved, and `make test && make test-repl` passes all regression tests.

3. **Given** both changes land **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 8 bytes smaller than the pre-story baseline (14,647 bytes).

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #3)
  - [x] 0.1 `make asm && wc -c build/antforth.com` -- confirm 14,647 bytes ✓
  - [x] 0.2 `make test && make test-repl` -- confirm all tests pass ✓ (258 REPL + asm regression)

- [x] Task 1: Remove dead code `asm_is_cond_tag` (AC: #1)
  - [x] 1.1 Delete the `asm_is_cond_tag` label and its 4-instruction body (lines 1104-1108)
  - [x] 1.2 `make asm && make test && make test-repl` -- confirm no regressions ✓
  - [x] 1.3 Record binary size: 14,641 bytes (6 bytes saved)

- [x] Task 2: Refactor remaining 4 predicates to shared tail (AC: #2)
  - [x] 2.1 Replace the 4 predicate bodies with JR-into-shared-tail using XOR/AND technique
  - [x] 2.2 `make asm && make test && make test-repl` -- confirm no regressions ✓
  - [x] 2.3 Record binary size: 14,635 bytes (6 additional bytes saved)

- [x] Task 3: Final verification (AC: #3)
  - [x] 3.1 `make test && make test-repl` -- all tests green ✓
  - [x] 3.2 `wc -c build/antforth.com` -- final size 14,635 bytes, delta = -12 bytes from 14,647 baseline
  - [x] 3.3 Verify savings >= 8 bytes ✓ (12 bytes saved)

## Dev Notes

### Current State (lines 1094-1131 of `src/assembler.asm`)

Five tag predicates plus `asm_get_class`, all testing class bits of C:

```asm
asm_is_imm_tag:          ; 6 bytes — called 7 times
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_IMM
        RET

asm_is_cond_tag:         ; 6 bytes — DEAD CODE (0 call sites)
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_COND
        RET

asm_is_label_tag:        ; 6 bytes — called 3 times
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_LABEL
        RET

asm_is_reg16_tag:        ; 6 bytes — called 6 times
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_REG16
        RET

asm_is_indirect_tag:     ; 6 bytes — called 5 times
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_INDIRECT
        RET
```

Total: 5 predicates x 6 bytes = 30 bytes.

### Refactored Design (XOR/AND shared tail)

```asm
asm_is_imm_tag:
        LD      A, ASM_CLASS_IMM        ; 2 bytes
        JR      .is_class_check         ; 2 bytes

asm_is_label_tag:
        LD      A, ASM_CLASS_LABEL      ; 2 bytes
        JR      .is_class_check         ; 2 bytes

asm_is_reg16_tag:
        LD      A, ASM_CLASS_REG16      ; 2 bytes
        JR      .is_class_check         ; 2 bytes

asm_is_indirect_tag:
        LD      A, ASM_CLASS_INDIRECT   ; 2 bytes
        ; fall through

.is_class_check:
        XOR     C                       ; 1 byte — zero in class bits if match
        AND     ASM_CLASS_MASK          ; 2 bytes — isolate class bits
        RET                             ; 1 byte
```

Total: 3 x 4 + 2 + 4 = 18 bytes. Savings vs current 4 predicates (24 bytes): **6 bytes**.
Combined with dead code removal (6 bytes): **12 bytes total**.

### Why XOR/AND Works

- `XOR C` compares the expected class (in A) against the full tag byte (in C). Where the class bits match, those bits become 0.
- `AND ASM_CLASS_MASK` isolates just the class bits, discarding index bits.
- Result is 0 (Z set) if and only if the class bits match. Exactly the same Z-flag contract as the current `CP` approach.

### Caller Contract

All 21 call sites use only the Z flag after calling a predicate (`JP Z`, `JR Z`, `JP NZ`, `JR NZ`). None depend on A's value after the call. The XOR/AND approach leaves A=0 when Z is set (vs A=class_value with the current CP approach), but this is safe since callers don't use A post-call.

### `asm_get_class` Is Unchanged

`asm_get_class` (line 1128) returns the class in A — different contract from the predicates. Leave it as-is. It cannot share the XOR/AND tail.

### Register Contract

- `BC` = TOS, `DE` = IP, `SP` = parameter stack, `IX` = return stack, `HL`/`AF` = scratch
- These changes only affect predicate helper functions. A and flags are scratch. No risk to the register contract.

### Ordering of Predicates

Place predicates in order of call frequency (most-called last, to fall through):
1. `asm_is_label_tag` (3 calls) — JR to tail
2. `asm_is_reg16_tag` (6 calls) — JR to tail
3. `asm_is_imm_tag` (7 calls) — JR to tail
4. `asm_is_indirect_tag` (5 calls) — fall through

Actually, ordering doesn't affect size. The last one saves 2 bytes by falling through. Any ordering works. Keep the current order for minimal diff, with `asm_is_indirect_tag` last (it's already last).

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Previous Story Learnings (6.3)

- Mechanical refactoring in `src/assembler.asm` has been clean — 6.3 merged 10 IX/IY pairs with zero regressions
- Build-test-verify after each task catches issues early
- Record baseline size before any changes
- All changes in this story are within `src/assembler.asm` only

### Project Structure Notes

- All changes are within `src/assembler.asm` — no other files need modification
- This is a prerequisite for Story 6.5 (LD, dispatch table)
- Test suites: assembly regression tests (`make test`) + REPL Forth tests (`make test-repl`)

### References

- [Source: src/assembler.asm:1094-1131] — Tag predicates and asm_get_class
- [Source: src/assembler.asm:142-149] — ASM_CLASS_* constant definitions
- [Source: _bmad-output/planning-artifacts/epic6-code-size-optimization.md#Story 6.4] — Epic specification
- [Source: _bmad-output/implementation-artifacts/6-3-ix-iy-prefix-pair-merges.md] — Previous story patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- sjasmplus local label scoping: `.is_class_check` was scoped per parent label; fixed by using global `asm_is_class_check` label

### Completion Notes List

- Baseline confirmed at 14,647 bytes, all 258 REPL tests + asm regression suite passing
- Removed dead `asm_is_cond_tag` (0 call sites) — saved 6 bytes (14,647 → 14,641)
- Refactored 4 remaining predicates (`asm_is_imm_tag`, `asm_is_label_tag`, `asm_is_reg16_tag`, `asm_is_indirect_tag`) to use XOR/AND shared tail via `asm_is_class_check` — saved 6 more bytes (14,641 → 14,635)
- Total savings: 12 bytes, exceeding the 8-byte AC threshold
- All 21 call sites continue to work; Z-flag contract preserved
- `asm_get_class` left unchanged as specified

### Change Log

- 2026-04-13: Removed dead `asm_is_cond_tag` predicate and refactored 4 remaining tag predicates to shared XOR/AND tail. Binary: 14,647 → 14,635 bytes (-12).

### File List

- src/assembler.asm (modified)
