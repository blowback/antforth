# Story 6.3: IX/IY Prefix Pair Merges

Status: done

## Story

As a system maintainer,
I want the duplicated IX/IY code pairs in the assembler merged into shared handlers,
So that the binary shrinks by ~70-90 bytes without changing any observable behaviour.

## Acceptance Criteria

1. **Given** duplicated code pairs in `src/assembler.asm` that differ only by `0xDD` vs `0xFD` prefix **When** each pair is merged into a single handler that calls `asm_emit_ixiy_prefix` then a shared emit sequence **Then** `make test && make test-repl` passes all regression tests with zero failures.

2. **Given** all LD-family pairs and non-LD pairs are merged **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 60 bytes smaller than the pre-story baseline (14,949 bytes).

## Tasks / Subtasks

- [x] Task 0: Record baseline and survey (AC: #1, #2)
  - [x] 0.1 `make asm && wc -c build/antforth.com` -- confirm 14,949 bytes
  - [x] 0.2 `make test && make test-repl` -- confirm all tests pass
  - [x] 0.3 Complete survey: grep for all inline `0xDD`/`0xFD` pairs and all duplicate handlers that call `asm_emit_ixiy_prefix` but remain as two separate code blocks. Record each pair's label names, line numbers, and byte cost.

- [x] Task 1: Merge inline 0xDD/0xFD LD-family pairs (AC: #1)
  - [x] 1.1 `.ldc_imm16_ix` / `.ldc_imm16_iy` (lines ~1763/~1776) -- LD IX,nn / LD IY,nn. Merge into single `.ldc_imm16_ixiy` that calls `asm_emit_ixiy_prefix`, then emits `0x21 lo hi`.
  - [x] 1.2 `.ldc_imm_ixd` / `.ldc_imm_iyd` (lines ~1815/~1830) -- LD (IX+d),n / LD (IY+d),n. Merge into single handler.
  - [x] 1.3 `.ldabs_ix` / `.ldabs_iy` (lines ~1962/~1976) -- LD IX,(nn) / LD IY,(nn). Merge into single handler.
  - [x] 1.4 `.ldr16abs_ix` / `.ldr16abs_iy` (lines ~2104/~2116) -- LD (nn),IX / LD (nn),IY. Merge into single handler.
  - [x] 1.5 Build and test: `make asm && make test && make test-repl`

- [x] Task 2: Merge inline 0xDD/0xFD non-LD pairs (AC: #1)
  - [x] 2.1 `.jp_iix` / `.jp_iiy` (lines ~2697/~2705) -- JP (IX) / JP (IY). Merge into single handler.
  - [x] 2.2 `.bop_ixd` / `.bop_iyd` (lines ~3354/~3389) -- BIT/SET/RES (IX+d) / (IY+d). Merge into single handler. This is the largest pair (~35 lines each).
  - [x] 2.3 `.ex_sp_ix` / `.ex_sp_iy` (lines ~3769/~3777) -- EX (SP),IX / EX (SP),IY. Merge into single handler.
  - [x] 2.4 Build and test: `make asm && make test && make test-repl`

- [x] Task 3: Merge already-helper-calling duplicate pairs (AC: #1)
  - [x] 3.1 `.idc_ix16` / `.idc_iy16` (lines ~3056/~3071) -- INC/DEC IX / INC/DEC IY. Both call `asm_emit_ixiy_prefix` but are separate blocks. Merge into one.
  - [x] 3.2 `.idc_ixd` / `.idc_iyd` (lines ~3098/~3108) -- INC/DEC (IX+d) / INC/DEC (IY+d). Merge into one.
  - [x] 3.3 `.cbs_ixd` / `.cbs_iyd` (lines ~3190/~3203) -- shift/rotate (IX+d) / (IY+d) (DDCB/FDCB prefix). Merge into one.
  - [x] 3.4 Build and test: `make asm && make test && make test-repl`

- [x] Task 4: Update dispatch jump targets (AC: #1)
  - [x] 4.1 For each merged pair, update the two JR/JP branch instructions that previously jumped to separate `_ix` / `_iy` labels to both jump to the single merged label.
  - [x] 4.2 Build and test: `make asm && make test && make test-repl`

- [x] Task 5: Final verification (AC: #2)
  - [x] 5.1 `make test && make test-repl` -- all tests green
  - [x] 5.2 `wc -c build/antforth.com` -- record final size, compute delta from 14,949 baseline
  - [x] 5.3 Verify savings >= 60 bytes

## Dev Notes

### Existing Infrastructure

`asm_emit_ixiy_prefix` (line ~1161) already exists and works correctly. It takes the operand tag index in A and emits `0xDD` for IX or `0xFD` for IY. Several handlers already use it successfully: `.pp_ixiy`, `.ldc_idx_dst`, `.ldc_sp_ixiy`, `.ldc_idx_src`, `.add16_dst_ixiy`.

### Merge Pattern

For each pair, the merge follows this pattern:

```asm
; BEFORE: Two separate handlers
.handler_ix:
        LD      A, 0xDD             ; or LD A, ASM_IX_INDEX
        ; ... shared body ...
        NEXT

.handler_iy:
        LD      A, 0xFD             ; or LD A, ASM_IY_INDEX
        ; ... identical body ...
        NEXT

; AFTER: Single merged handler
.handler_ixiy:
        CALL    asm_emit_ixiy_prefix  ; A already holds tag index from dispatch
        ; ... shared body (emit opcode, operands) ...
        NEXT
```

The key insight: by the time dispatch branches to the IX or IY handler, the tag index is typically already available in A or can be loaded from the operand. The `asm_emit_ixiy_prefix` helper uses that index to decide which prefix byte to emit.

### Dispatch Update Pattern

The dispatch code typically looks like:
```asm
        CP      ASM_IX_INDEX
        JR      Z, .handler_ix
        CP      ASM_IY_INDEX
        JR      Z, .handler_iy
```

After merge, both branches target the same label:
```asm
        CP      ASM_IX_INDEX
        JR      Z, .handler_ixiy
        CP      ASM_IY_INDEX
        JR      Z, .handler_ixiy
```

### Savings Per Pair

Each merge eliminates one duplicate handler body. Savings depend on handler size:
- Small pairs (JP, EX): ~6-8 bytes saved per pair
- Medium pairs (LD forms, INC/DEC, CBS): ~10-15 bytes saved per pair
- Large pair (BOP): ~30-40 bytes saved

### Register Contract (critical)

- `BC` = TOS, `DE` = IP, `SP` = parameter stack, `IX` = return stack, `HL`/`AF` = scratch
- These merges only affect the assembler's code-generation handlers, not the Forth runtime. The register contract is not at risk.
- `asm_emit_ixiy_prefix` clobbers A and HL (scratch). This is safe in all merge sites.

### Critical Gotcha: Tag Index vs Literal Prefix

Some handlers receive the tag index (ASM_IX_INDEX=5, ASM_IY_INDEX=6, ASM_IND_IXD=3, ASM_IND_IYD=4) from the dispatch path. Others hardcode `0xDD`/`0xFD`. When merging handlers that previously hardcoded the prefix byte, you must instead pass the tag index to `asm_emit_ixiy_prefix` -- the tag index is available from the dispatch comparison that routed to the handler.

### Critical Gotcha: BOP Pair is the Largest and Most Complex

`.bop_ixd` / `.bop_iyd` (BIT/SET/RES indexed) is the biggest pair (~35 lines each). It uses the DDCB/FDCB 4-byte encoding. Verify carefully that the displacement byte and opcode byte order is preserved after merge.

### Critical Gotcha: Handlers That Already Call asm_emit_ixiy_prefix

The `.idc_ix16`/`.idc_iy16`, `.idc_ixd`/`.idc_iyd`, and `.cbs_ixd`/`.cbs_iyd` pairs already call the helper but are still separate blocks that differ only by the initial `LD A, <constant>`. These merge by having both dispatch branches jump to the same label and passing the tag index through A.

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Learnings from Story 6.2

- Mechanical substitution works cleanly -- 6.2 had 54 sites across 10 files with zero regressions
- Build-test-verify after each task group catches issues early
- sjasmplus multi-pass assembler handles forward references -- no include reorder needed
- Record baseline size before any changes

### Project Structure Notes

- All changes are within `src/assembler.asm` -- no other files should need modification
- `asm_emit_ixiy_prefix` and all affected handlers are in `src/assembler.asm`
- Test suites: assembly regression tests (`make test`) + REPL Forth tests (`make test-repl`)

### References

- [Source: src/assembler.asm:1156-1172] -- asm_emit_ixiy_prefix helper
- [Source: src/assembler.asm:1763-1787] -- .ldc_imm16_ix / .ldc_imm16_iy pair
- [Source: src/assembler.asm:1815-1843] -- .ldc_imm_ixd / .ldc_imm_iyd pair
- [Source: src/assembler.asm:1962-1988] -- .ldabs_ix / .ldabs_iy pair
- [Source: src/assembler.asm:2104-2127] -- .ldr16abs_ix / .ldr16abs_iy pair
- [Source: src/assembler.asm:2697-2712] -- .jp_iix / .jp_iiy pair
- [Source: src/assembler.asm:3056-3078] -- .idc_ix16 / .idc_iy16 pair
- [Source: src/assembler.asm:3098-3116] -- .idc_ixd / .idc_iyd pair
- [Source: src/assembler.asm:3190-3213] -- .cbs_ixd / .cbs_iyd pair
- [Source: src/assembler.asm:3354-3417] -- .bop_ixd / .bop_iyd pair
- [Source: src/assembler.asm:3769-3783] -- .ex_sp_ix / .ex_sp_iy pair
- [Source: _bmad-output/implementation-artifacts/6-2-return-stack-push-pop-subroutines.md] -- Previous story patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None required — all merges were mechanical substitutions with clean test passes.

### Completion Notes List

- Baseline: 14,949 bytes, all 258 REPL tests + regression tests pass
- Task 1: Merged 4 LD-family inline pairs → 14,829 bytes (−120)
- Task 2: Merged 3 non-LD inline pairs (JP, BOP, EX) → 14,728 bytes (−221)
- Task 3: Merged 3 already-helper-calling pairs (IDC r16, IDC ixd, CBS) → 14,641 bytes (−308)
- Task 4: Dispatch updates done inline with each merge (all old labels eliminated)
- Task 5: Final size 14,647 bytes, delta = −302 bytes (exceeds 60-byte threshold by 5x)
- Merge technique: call `asm_emit_ixiy_prefix` with tag index from dispatch (already in A at handler entry). For JP pair, saved A across `check_asm_mode`. For BOP pair, saved tag to `asm_ip_save`, validated operands first, then emitted prefix. For EX pair, masked class bits with `AND ASM_INDEX_MASK`.
- Zero regressions across all test suites.
- Code review fix: BOP handler restructured to validate operands before emitting prefix byte (was emitting DD/FD before checking imm-marker and bit range).
- Code review fix: Restored explanatory opcode-derivation comment in `.idc_ixiy16`.

### Change Log

- 2026-04-13: Merged 10 duplicate IX/IY handler pairs into shared handlers using `asm_emit_ixiy_prefix`. Binary: 14,949 → 14,647 (−302 bytes).
- 2026-04-13: Code review fixes — BOP validate-before-emit, restored INC/DEC opcode comment.

### File List

- src/assembler.asm (modified)
