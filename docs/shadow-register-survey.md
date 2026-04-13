# Shadow Register (EXX / EX AF,AF') Optimization Survey

**Date:** 2026-04-13
**Context:** Epic 6 retrospective identified Z80 shadow registers as completely unused in the AntForth codebase.

## Background

The Z80 has a shadow register set accessible via two 1-byte instructions:
- **EXX** (1 byte, opcode 0xD9): swaps BC/DE/HL with BC'/DE'/HL'
- **EX AF,AF'** (1 byte, opcode 0x08): swaps AF with AF'

These are safe to use in AntForth because:
- CP/M 2.2 BDOS does not use shadow registers
- AntForth has no interrupt handlers
- The shadow registers are pristine throughout execution

## Convention

EXX must be a **leaf-level technique**: if a word uses EXX, it must not call any subroutine that also uses EXX (the second EXX would swap back to the main set). This means:
- Words using EXX cannot call rpush_de/rpop_de/rpush_bc/rpop_bc (which use IX, not EXX — these remain safe)
- Words using EXX cannot call other EXX-using words
- BDOS calls are safe (BDOS doesn't touch shadows), but BDOS_SAVE/BDOS_RESTORE use PUSH/POP on the main registers, which is fine

## Category 1: DE-Only Save/Restore (rpush_de + rpop_de pairs)

These words save DE (IP) to the return stack at entry and restore at exit. EXX would replace both calls (6 bytes) with 2 bytes (EXX at entry, EXX at exit), saving 4 bytes per word.

**However:** EXX swaps BC too. If the word modifies BC between the two EXX instructions, the original BC (TOS) would be lost. These words would need to handle TOS carefully — either work entirely in shadow registers, or save/restore BC separately.

**Feasible candidates (word body does NOT call BDOS-touching helpers):**

| File | Word | Current (bytes) | Notes |
|------|------|-----------------|-------|
| strings.asm | WORD | 6 | Pure parsing, no BDOS |
| strings.asm | >NUMBER | 6 | Character conversion loop |
| strings.asm | NUMBER? | 6 | Number parsing |
| strings.asm | ( | 6 | Comment scanning |
| memory.asm | FILL | 6 | LDIR block operation |
| memory.asm | MOVE | 6 | LDIR/LDDR block copy |
| stack_ops.asm | ROLL | 6 | LDDR stack rotate |
| io.asm | ACCEPT | 6 | Direct BDOS call (safe) |

**Conditional candidates (word body calls BDOS-touching helpers — need deeper analysis):**

| File | Word | Current (bytes) | Notes |
|------|------|-----------------|-------|
| formatting.asm | . (DOT) | 6 | Calls print_neg_prefix, emit_unsigned → BDOS |
| formatting.asm | U. | 6 | Calls emit_unsigned → BDOS |
| formatting.asm | .R | 6 | Calls u_to_str, bdos_putchar |
| formatting.asm | .S | 6 | Calls bdos_putchar in print loop |

For the formatting words, EXX would swap DE away from IP *and* swap BC away from TOS. The print helpers receive values in BC and use DE as scratch. With EXX, the helpers would see shadow-BC (not TOS) and shadow-DE (not IP). This requires the helpers to be designed for shadow-register context, which is a deeper refactor.

## Category 2: DE+BC Paired Save/Restore (rpush_de + rpush_bc + rpop_bc + rpop_de)

These words save both DE (IP) and BC (TOS) before calling `build_header` or similar helpers that clobber all registers. A single EXX at entry/exit would save both simultaneously.

| File | Word | Current (bytes) | EXX (bytes) | Savings |
|------|------|-----------------|-------------|---------|
| compiler.asm | : (COLON) | 6 (2 CALLs) | 2 | **4** |
| compiler.asm | CREATE | 6 | 2 | **4** |
| compiler.asm | CONSTANT | 6 | 2 | **4** |
| assembler.asm | CODE | 6 | 2 | **4** |
| assembler.asm | END-CODE | 6 | 2 | **4** |
| assembler.asm | NEXT, | 6 | 2 | **4** |
| assembler.asm | LABEL | 6 | 2 | **4** |
| system.asm | MARKER | 6 | 2 | **4** |

These are the **strongest candidates** — EXX naturally saves both BC and DE in one instruction, and the word bodies call helpers that work entirely in the main register set.

**Error handler paths** (.colon_no_name, .create_no_name, .code_no_name, .lbl_no_name, .marker_no_name) would also use EXX to restore before jumping to ABORT.

**Estimated savings from Category 2 alone: ~32 bytes**

## Category 3: Recognizer (w_ASM_RECOGNIZE_cf)

The recognizer in assembler.asm currently saves DE to a local memory scratch variable (.recog_save_ip). With EXX:
- Entry: EXX saves BC/DE/HL to shadows (1 byte vs 4+ bytes of memory save)
- The entire table scan works in fresh registers
- Exit (match): restore from shadows with EXX, then set up match result
- Exit (no match): restore from shadows with EXX

**Estimated savings: 10-15 bytes** (memory save/restore instructions eliminated)

## Category 4: NOT Feasible

| File | Word | Reason |
|------|------|--------|
| inner_interpreter.asm | DOCOL | Hot path — 1 EXX + 1 EXX = 2 bytes vs 0 current overhead (already optimized inline) |
| inner_interpreter.asm | EXIT | Hot path |
| inner_interpreter.asm | DODOES | Hot path |
| inner_interpreter.asm | DOMARKER | Uses LDIR which clobbers BC/DE — needs explicit register management |

## Summary

| Category | Sites | Savings Per Site | Total Estimate |
|----------|-------|-----------------|----------------|
| 2: DE+BC paired (build_header etc.) | 8 words + 5 error paths | 4 bytes | ~32 bytes |
| 3: Recognizer memory spill | 1 | 10-15 bytes | ~12 bytes |
| 1: DE-only (feasible subset) | ~8 words | 4 bytes | ~32 bytes |
| 1: DE-only (conditional/formatting) | ~4 words | 4 bytes | ~16 bytes (needs deeper analysis) |
| **Total estimated** | | | **~76-92 bytes** |

## Recommended Implementation Order

1. **Category 2 first** (lowest risk, highest confidence) — COLON, CREATE, CONSTANT, CODE, END-CODE, NEXT,, LABEL, MARKER. These words do EXX → call build_header/LDIR → EXX back. Clean, mechanical, well-understood.

2. **Category 3** (recognizer) — Single word, biggest per-word savings, eliminates memory scratch variable.

3. **Category 1 feasible** — WORD, >NUMBER, NUMBER?, (, FILL, MOVE, ROLL, ACCEPT. Need careful analysis of each word's register usage between the two EXX points.

4. **Category 1 conditional** — Formatting words. Deepest analysis needed due to BDOS call chains.

## Interaction with rpop_bc

The rpop_bc subroutine was added in this session (14 sites converted, 172 bytes saved). If EXX is adopted for Category 2 words, those words would no longer use rpush_de/rpop_de/rpush_bc/rpop_bc at all — the return stack save/restore is replaced entirely by EXX. The rpop_bc subroutine would still be used by remaining sites (formatting.asm .dots_done, and any future CODE words that save only BC).
