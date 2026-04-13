# Story 7.3: EXX for DE-Only Words

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want the `CALL rpush_de`/`CALL rpop_de` save/restore pattern replaced with EXX (or `PUSH BC`/EXX combinations) in words where the body can tolerate BC and HL also being swapped,
so that the binary shrinks by ~20-40 bytes while preserving the established shadow-register convention from stories 7.1 and 7.2.

## Acceptance Criteria

1. **Given** the eight candidate DE-save words listed in epic 7.3 (FILL, MOVE, ROLL, ACCEPT, WORD, >NUMBER, NUMBER?, `(`) each currently use `CALL rpush_de` (3 bytes) at entry and `CALL rpop_de` (3 bytes) at one or more exit paths **When** each word is individually audited against the EXX leaf-level rule **Then** every word either (a) is converted to use EXX or `PUSH BC / EXX` (entry) and `EXX` or `EXX / POP BC` (exit) with matching exit-path coverage including error paths, or (b) is documented in Dev Notes with a specific reason it could not be converted.

2. **Given** the "consumes TOS early" words FILL, MOVE, ROLL, and ACCEPT already destroy or transfer BC into working registers before DE must be freed **When** converted to EXX **Then** these four words compile without a pre-EXX `PUSH BC` (they do not need to preserve the original BC after EXX) and `make test && make test-repl` passes all 265 regression tests.

3. **Given** EXX is a leaf-level technique (a word using EXX must not call any subroutine that also uses EXX) **When** converting each word **Then** every CALL target in the converted body is verified not to use EXX itself; this includes `do_number`, `bdos_putchar`, `bdos_print_str`, `BDOS_ENTRY`, and any helpers reached from the converted path.

4. **Given** `(` (PAREN) currently saves BC via `PUSH BC` *before* `CALL rpush_de` because the word has stack effect `( -- )` **When** converted **Then** the pattern becomes `PUSH BC / EXX` at entry (2 bytes) and `EXX / POP BC` at match exit (2 bytes), saving 2 bytes per pair versus the current 3+3+1=7 bytes (existing `PUSH BC` + rpush_de + POP BC at exit); error path `.paren_missing` must EXX before `JP w_ABORT_cf` to restore DE (same pattern as the 7.1 error-path words).

5. **Given** `NUMBER?` currently saves the original c-addr via `PUSH BC` on the parameter stack after entry to support the failure path **When** EXX is used **Then** the shadow BC' holds the original c-addr automatically; the explicit `PUSH BC` may be removed if the fail path EXXes back before building the `( c-addr 0 )` result (dev agent to choose the byte-minimal structure).

6. **Given** all conversions land **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 16 bytes smaller than the 14,141-byte post-7.2 baseline (conservative half of the ~20-40 byte epic estimate, accounting for words that may be deferred to "no-change" status after analysis).

7. **Given** any word is determined during analysis to be infeasible (e.g., the body truly needs BC and HL simultaneously throughout and the PUSH/POP overhead eliminates the savings) **When** documenting that decision **Then** Dev Notes records the specific register-flow reason and the word is left using the existing `CALL rpush_de`/`CALL rpop_de` pattern; this is an acceptable outcome per AC #1(b).

8. **Given** the changes land **When** the full regression suite runs (`make test && make test-repl`) **Then** all 265 tests pass with zero failures; no previously-passing test may regress.

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #6)
  - [x] 0.1 `make asm && wc -c build/antforth.com` — confirmed 14,141 bytes
  - [x] 0.2 `make test && make test-repl` — confirmed all 265 REPL tests + assembly tests pass

- [x] Task 1: Verify leaf-level safety for every candidate (AC: #3)
  - [x] 1.1 `do_number` (src/strings.asm:303-349) contains no EXX
  - [x] 1.2 `bdos_putchar`, `bdos_print_str`, `BDOS_ENTRY` (src/io.asm) contain no EXX; BDOS_SAVE/BDOS_RESTORE use PUSH/POP only
  - [x] 1.3 LDIR/LDDR are instructions (not subroutines); they operate on main BC/DE/HL which is exactly the scratch set we want after entry EXX
  - [x] 1.4 Repo-wide EXX survey shows only 7.1 words (compiler.asm, system.asm, assembler.asm LABEL/MARKER/CODE/END-CODE), 7.2 recognizer, and the new 7.3 words defined by this story

- [x] Task 2: Convert FILL (AC: #1, #2, #8)
  - [x] 2.1 Replaced `CALL rpush_de` with `EXX` (3 → 1 byte) after moving `LD A, C` ahead of the EXX
  - [x] 2.2 Replaced `CALL rpop_de` at `.fill_done` with `EXX`
  - [x] 2.3 `LD A, C` now precedes the entry EXX — char preserved in A across the swap
  - [x] 2.4 Body uses main BC/DE/HL as scratch for LDIR; exit `POP BC` is stack-only (no register dependency)
  - [x] 2.5 `make asm && make test && make test-repl` — all pass; -4 bytes (14141 → 14137)

- [x] Task 3: Convert MOVE (AC: #1, #2, #8)
  - [x] 3.1 Entry: `PUSH BC; EXX; POP BC` preserves u into main BC so the zero-check and LDIR/LDDR still have count
  - [x] 3.2 Exit at `.move_done`: `EXX` replaces `CALL rpop_de`
  - [x] 3.3 Both `.move_fwd` (LDIR) and `.move_zero` paths funnel into `.move_done`; exit is shared
  - [x] 3.4 u is recovered into main BC via `POP BC` immediately after the entry EXX so `LD A, B / OR C` still works
  - [x] 3.5 `make asm && make test && make test-repl` — all pass; -2 bytes (14137 → 14135)

- [x] Task 4: Convert ROLL (AC: #1, #2, #8)
  - [x] 4.1 u=0 fast path remains unchanged (no EXX entered)
  - [x] 4.2 At `.roll_work`: `PUSH BC; EXX; POP HL` (u → HL in main) replaces `CALL rpush_de; LD H, B; LD L, C` (saves 2 bytes)
  - [x] 4.3 Exit: `POP BC` replaces `POP HL / LD B, H / LD C, L` (saves 2 bytes), then `PUSH BC; EXX; POP BC` stages new TOS across the exit swap
  - [x] 4.4 u is loaded into main HL via `POP HL` right after entry EXX (no stale-BC read)
  - [x] 4.5 LDDR uses main BC/DE/HL which are precisely the scratch set after EXX — shadow set is untouched
  - [x] 4.6 `make asm && make test && make test-repl` — all pass; -4 bytes (14135 → 14131)

- [x] Task 5: Convert ACCEPT (AC: #1, #2, #3, #8)
  - [x] 5.1 Entry `EXX` replaces `CALL rpush_de`, preceded by `LD A, C` to preserve max-chars across the swap
  - [x] 5.2 Exit `EXX` replaces `CALL rpop_de`, with `LD A, (bdos_input_len)` issued BEFORE the exit EXX and `LD C, A / LD B, 0` AFTER (the "A survives EXX" staging pattern from 7.2)
  - [x] 5.3 BDOS_ENTRY / bdos_putchar verified EXX-free (Task 1.2)
  - [x] 5.4 Max-chars (C) is captured into A before entry EXX — BC being swapped thereafter is immaterial
  - [x] 5.5/5.6/5.7 Confirmed the 7.2 recognizer pattern: stage the computed value into A (which survives EXX), perform the exit EXX to restore IP, then rebuild BC in the now-restored main set. Applied to ACCEPT.
  - [x] 5.8 `make asm && make test && make test-repl` — all pass; -4 bytes (14131 → 14127)

- [x] Task 6: Convert WORD (AC: #1, #7, #8)
  - [x] 6.1 Traced `.word_empty` and `.word_finish` exits — both set BC=HERE from a main-HL register; no error paths
  - [x] 6.2 Scan/copy loops are rewritten to run in the post-EXX main set (which is the scratch set); IY-relative loads of UserArea fields are unaffected by EXX
  - [x] 6.3 `.word_delim` scratch retained — the copy phase overwrites D via `POP DE` (line 86) so delim must be re-read from memory. Eliminating the scratch would require additional register juggling for no net savings. Documented as out-of-scope optimization.
  - [x] 6.4 Full conversion applied: entry uses `LD A, C / EXX`; both exits stage HERE through HL via `PUSH HL / EXX / POP BC`
  - [x] 6.5 `make asm && make test && make test-repl` — all pass; -6 bytes (14127 → 14121)

- [x] Task 7: Convert >NUMBER (AC: #1, #7, #8)
  - [x] 7.1 Entry BC=u1: captured via `LD A, C` before EXX (count has well-defined low-byte semantics in practice)
  - [x] 7.2 After entry EXX, main DE is free and used as the do_number accumulator as before
  - [x] 7.3 `do_number` is EXX-free (Task 1.1 — confirmed by reading src/strings.asm:303-349)
  - [x] 7.4 Exit: `LD A, B` stages remaining count, `EXX` restores IP, `LD C, A / LD B, 0` rebuilds TOS
  - [x] 7.5 Entry `CALL rpush_de` and exit `CALL rpop_de` both replaced
  - [x] 7.6 `make asm && make test && make test-repl` — all pass; -2 bytes (14121 → 14119)

- [x] Task 8: Convert NUMBER? (AC: #1, #5, #7, #8)
  - [x] 8.1 Traced both `.numq_ok` and `.numq_fail`; also `.numq_fail` reached via count=0, bare "-", and remaining-chars paths
  - [x] 8.2 AC #5 applied: explicit `PUSH BC` at entry eliminated. Shadow BC' implicitly holds the original c-addr (swapped in by entry EXX). The fail path simply does `EXX; PUSH BC; LD BC, 0` — c-addr_orig surfaces in main BC for free.
  - [x] 8.3 Byte delta: removal of entry `PUSH BC`, removal of both `POP AF` (ok) and `POP BC; PUSH BC` (fail), plus the usual CALL rpush_de/rpop_de → EXX swap. Body also shortened: using HL as c-addr cursor drops `LD H, B / LD L, C` from the body.
  - [x] 8.4 `make asm && make test && make test-repl` — all pass; -8 bytes (14119 → 14111) — best per-word savings of the story

- [x] Task 9: Convert `(` (PAREN) (AC: #1, #4, #8)
  - [x] 9.1 Current pattern identified: `PUSH BC + CALL rpush_de` entry, `CALL rpop_de + POP BC` success exit, `JP w_ABORT_cf` in error path
  - [x] 9.2 New pattern applied: `PUSH BC + EXX` entry (2 bytes vs 4); `EXX + POP BC` success (2 vs 4); error path `CALL bdos_print_str / EXX / JP w_ABORT_cf`
  - [x] 9.3 w_ABORT_cf (src/system.asm:266) resets SP to sp_base and JPs into w_QUIT_cf, which reloads DE explicitly from `.quit_loop` — so shadow-register state is genuinely irrelevant after ABORT. The `EXX` before `JP w_ABORT_cf` is retained defensively to match the 7.1 convention and keep reasoning simple (1 byte cost)
  - [x] 9.4 `make asm && make test && make test-repl` — all pass; -3 bytes (14111 → 14108)

- [x] Task 10: Final verification (AC: #6, #8)
  - [x] 10.1 Final size: 14108 bytes
  - [x] 10.2 Delta from 14141 baseline: **-33 bytes** (target ≥ 16)
  - [x] 10.3 `make test` passes (assembly regression); `make test-repl` passes all 265 numbered REPL tests, zero failures
  - [x] 10.4 Completion Notes updated below

## Dev Notes

### Epic Context

This is the final story of Epic 7 (Shadow Register Optimization). Stories 7.1 (build-header words, −132 bytes) and 7.2 (recognizer, −40 bytes) established the EXX convention. Story 7.3 applies the same technique to words that currently save **only DE** via `CALL rpush_de` / `CALL rpop_de`, where the challenge is that EXX additionally swaps BC (TOS) and HL — so each word's body must tolerate (or explicitly compensate for) those swaps.

### Post-7.2 Baseline

- Binary: 14,141 bytes
- Tests: 265/265 pass (assembly + REPL)
- EXX users (all leaf-level, non-nested):
  - 7.1: w_COLON_cf, w_CREATE_cf, w_CONSTANT_cf, w_CODE_cf, w_END_CODE_cf, w_NEXT_COMMA_cf, w_LABEL_cf, w_MARKER_cf
  - 7.2: w_ASM_RECOGNIZE_cf (partial — not the fast-false path)

### Candidate Words (from Epic 7 spec)

**Group A — "Consumes TOS early" (low risk, ~4 bytes each):**

| Word | File | Lines | Why straightforward |
|------|------|-------|---------------------|
| FILL | memory.asm | 226-257 | `LD A, C` consumes TOS (char) immediately; LDIR runs in main set |
| MOVE | memory.asm | 265-302 | `LD A, B / OR C` consumes TOS (u) for zero-check; LDIR/LDDR run in main set |
| ROLL | stack_ops.asm | 111-171 | `LD H, B / LD L, C` moves u into HL before EXX needed; LDDR runs in main set |
| ACCEPT | io.asm | 116-148 | `LD A, C` consumes TOS (max chars) immediately; BDOS runs in main set |

**Group B — "Needs deeper analysis" (medium risk, savings depend on structure):**

| Word | File | Lines | Complication |
|------|------|-------|--------------|
| WORD | strings.asm | 10-76+ | BC = delim held in `.word_delim` scratch; scan loop uses BC as remaining-count. After EXX the main BC is free scratch — this is actually a NET WIN because the scratch variable can potentially be eliminated. |
| >NUMBER | strings.asm | 357-386 | BC = u1 count, body does `LD B, C` then POP c-addr / POP ud-low into DE (DE was IP — that's why rpush_de is there). After EXX, main DE is free. |
| NUMBER? | strings.asm | 393-466 | Has explicit `PUSH BC` to preserve c-addr for fail path. With EXX, BC' holds original c-addr for free. |
| ( | strings.asm | 851-908 | Has stack effect `( -- )`, so original BC must be preserved (already `PUSH BC`). New pattern: `PUSH BC / EXX`. |

### CRITICAL: Post-EXX TOS Construction Pattern

The #1 subtle bug risk in this story. A word that rebuilds TOS before exit must place the new TOS value in the correct location so that, after the exit EXX, the main BC register holds the new TOS.

**Wrong pattern (loses new TOS):**
```asm
    ; ... body runs in main set after entry EXX ...
    LD C, A         ; Build new TOS in main BC
    LD B, 0
    EXX             ; EXIT — swaps: main BC (our new TOS) goes to BC', and BC' (original TOS) comes back to main BC
    NEXT            ; NEXT uses main BC as TOS — but that's the ORIGINAL TOS, not our computed value!
```

**Correct patterns (either works):**

Option 1 — build new TOS in shadow BC before exit:
```asm
    ; ... body runs in main set ...
    ; When ready to set new TOS, write it into BC' via EXX-swap-write-swap, or
    ; simply compute directly in shadow by EXXing first:
    EXX             ; Swap to shadow: main now has original TOS_in in BC, DE has IP
    LD C, A         ; Can't easily — A doesn't survive EXX cleanly in some paths
```
Option 1 is awkward because A is the only register preserved across EXX. Usually simpler:

Option 2 — EXX first, then overwrite main BC with new TOS:
```asm
    ; ... body runs in main set, computes value destined for TOS into some register, say the stack or a temp ...
    LD A, <new-tos-low>   ; stage low byte
    EXX                   ; Exit swap — BC/DE/HL restored from shadow
    LD C, A               ; Overwrite BC (now restored) with new TOS — A survives EXX
    LD B, 0
    NEXT
```

**This is exactly what 7.2 recognizer does.** Before converting Group A/B words with computed TOS results, **read src/assembler.asm w_ASM_RECOGNIZE_cf match/no-match exits** and replicate the idiom. The key property: A (and AF) survive EXX; all other registers swap. So stage the result into A across the EXX, then rebuild BC from A after.

For ACCEPT specifically: the new TOS (+n2) comes from `bdos_input_len`, which is a memory read. Easiest: do the memory read into A after the exit EXX, then build BC:
```asm
    ; ... body ...
    EXX                   ; Restore IP (DE) from shadow
    LD A, (bdos_input_len)
    LD C, A
    LD B, 0
    NEXT
```

For `>NUMBER` exit: new TOS = `u2 = remaining count` which was left in B by do_number. B is main-set register, so EXX would swap it to B'. Solution: `LD A, B` before EXX, then `LD C, A / LD B, 0` after EXX.

### Leaf-Level Audit Checklist

EXX words must not call subroutines that also use EXX. For each candidate:

- **FILL, MOVE, ROLL**: no CALLs in the converted body (LDIR/LDDR are instructions, not subroutines) ✓ pending verify
- **ACCEPT**: calls `BDOS_ENTRY` (src/io.asm, just a JP to BDOS — does not use EXX; CP/M itself preserves shadows per Epic 7 safety basis) and `bdos_putchar` (needs verify — it is in src/io.asm near BDOS_SAVE/BDOS_RESTORE macros which use PUSH/POP, not EXX)
- **WORD**: no external CALLs in the scan loop (it uses inline logic and IY-relative loads)
- **>NUMBER, NUMBER?**: both call `do_number` — must verify do_number does not use EXX (Task 1.1)
- **(**: calls `bdos_print_str` in error path (before `JP w_ABORT_cf`) — verify does not use EXX

### ABORT Behavior (relevant to `(` error path)

`w_ABORT_cf` clears both parameter and return stacks. If `(` pushed BC onto the parameter stack and jumps to ABORT, the push is harmless (ABORT resets SP). Similarly, any shadow-register state is irrelevant after ABORT since ABORT re-initializes the interpreter loop. However, if ABORT internally calls any word that uses EXX, our shadow state could corrupt its behavior — **verify w_ABORT_cf path does not depend on shadow registers having specific contents** before skipping the pre-ABORT EXX.

Conservative approach: do `EXX` before `JP w_ABORT_cf` in the error paths (as 7.1 does — see `.colon_no_name`, `.marker_no_name`, etc.). Cost: 1 byte per error path. Benefit: no reasoning about shadow-register invariants across ABORT.

### Byte-Savings Estimate

| Word | Entry current | Exit current | Entry new | Exit new | Saved |
|------|---------------|--------------|-----------|----------|-------|
| FILL | 3 | 3 | 1 | 1 | 4 |
| MOVE | 3 | 3 | 1 | 1 | 4 |
| ROLL | 3 | 3 | 1 | 1 | 4 |
| ACCEPT | 3 | 3 | 1 | 1 | 4 |
| WORD | 3 | 3 (×2 exits?) | 1 | 1 (×2) | 4-6 (+ potential `.word_delim` elimination) |
| >NUMBER | 3 | 3 | 1 | 1 | 4 |
| NUMBER? | 3 | 3 (×2) | 1 | 1 (×2) | 4-6 (+ potential `PUSH BC` elimination = +2) |
| ( | 3 | 3 | 1 | 1 | 4 (+ error path: 0 if simple, −1 if EXX needed) |

**Conservative total**: 8 words × 4 bytes = 32 bytes saved. AC target: ≥ 16 bytes (allows 50% deferrals).

**Optimistic total**: with WORD scratch elimination and NUMBER? PUSH elimination: ~40-45 bytes.

### Register Contract Reminder

- `BC` = TOS, `DE` = IP, `SP` = parameter stack, `IX` = return stack, `IY` = user pointer, `HL`/`AF` = scratch
- EXX swaps BC↔BC', DE↔DE', HL↔HL'. IX, IY, SP, AF, flags are unaffected.
- A register is preserved across EXX (part of AF).
- After EXX, main BC/DE/HL are free scratch (holding previous shadow contents — meaningless junk initially).

### Previous Story Learnings (7.1, 7.2)

**From 7.1:**
- EXX is safe in AntForth (BDOS doesn't touch shadows, no ISRs)
- Error paths need a single EXX before `JP w_ABORT_cf` to restore DE=IP
- Always audit for vestigial instructions after refactoring (review caught `INC IX` leftover)

**From 7.2:**
- Register allocation with EXX can eliminate scratch variables entirely (`.recog_save_ip`, `.recog_len`, `.recog_name` all removed → 5 bytes of data saved)
- The post-EXX exit pattern: stage result through A or memory, EXX, rebuild BC — do not build TOS in main set *before* the exit EXX
- Code review found additional savings (merging duplicate tail blocks via fall-through, −11 bytes beyond initial 29)
- Binary went 14,181 → 14,141 (−40 bytes) in 7.2

### Project Structure Notes

Files modified by this story:
- `src/memory.asm` — FILL, MOVE
- `src/stack_ops.asm` — ROLL
- `src/io.asm` — ACCEPT
- `src/strings.asm` — WORD, >NUMBER, NUMBER?, `(`

Files read but NOT modified (reference/verification):
- `src/inner_interpreter.asm` — rpush_de/rpop_de reference
- `src/assembler.asm` — 7.2 recognizer exit pattern reference
- `src/macros.asm` — BDOS_SAVE/BDOS_RESTORE (verify no EXX)
- `src/system.asm` — w_ABORT_cf (verify no shadow dependency)

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### References

- [Source: _bmad-output/planning-artifacts/epic7-shadow-register-optimization.md#Story 7.3] — Epic specification with candidate table
- [Source: _bmad-output/implementation-artifacts/7-1-exx-for-build-header-words.md] — EXX convention established; error-path pattern
- [Source: _bmad-output/implementation-artifacts/7-2-exx-for-recognizer.md] — Post-EXX TOS construction pattern; scratch-variable elimination
- [Source: src/memory.asm:220-302] — FILL, MOVE current implementation
- [Source: src/stack_ops.asm:111-171] — ROLL current implementation
- [Source: src/io.asm:116-148] — ACCEPT current implementation
- [Source: src/strings.asm:10-76] — WORD current implementation
- [Source: src/strings.asm:357-386] — >NUMBER current implementation
- [Source: src/strings.asm:393-466] — NUMBER? current implementation
- [Source: src/strings.asm:851-908] — ( current implementation
- [Source: src/inner_interpreter.asm:130-144] — rpush_de/rpop_de reference (NOT modified — still used by formatting words and others excluded from 7.3)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context) — claude-opus-4-6[1m]

### Debug Log References

None — all conversions succeeded first-try after a careful design pass informed by the 7.2 "stage-through-A" pattern. The only subtlety encountered was ensuring that TOS-consuming registers (C for FILL/ACCEPT/>NUMBER, BC for MOVE/ROLL, BC for NUMBER?) are captured BEFORE the entry EXX — via either `LD A, C` (single byte survives EXX) or `PUSH BC; EXX; POP BC/HL` (when the full 16-bit value is needed).

### Completion Notes List

**Per-word conversion status** (all converted, none deferred):

| Word   | Bytes saved | Pattern |
|--------|-------------|---------|
| FILL   | -4 | `LD A, C` before entry EXX; exit EXX; new TOS from `POP BC` (stack-only) |
| MOVE   | -2 | `PUSH BC; EXX; POP BC` at entry (needs u in main BC for LDIR/LDDR); exit EXX |
| ROLL   | -4 | `PUSH BC; EXX; POP HL` at entry (u → main HL); exit `PUSH BC; EXX; POP BC` to stage new TOS |
| ACCEPT | -4 | `LD A, C` before entry EXX; stage result through A across exit EXX |
| WORD   | -6 | `LD A, C` entry; both exits stage HERE via `PUSH HL; EXX; POP BC` |
| >NUMBER| -2 | `LD A, C` entry → `LD B, A` for do_number; stage remaining count through A on exit |
| NUMBER?| -8 | Shadow BC' implicitly holds c-addr_orig for the fail path — eliminates the explicit `PUSH BC` at entry (AC #5 bonus) |
| (      | -3 | `PUSH BC + EXX` entry; `EXX + POP BC` success; defensive `EXX` before `JP w_ABORT_cf` |
| **Total** | **-36 bytes** | Binary: 14,141 → 14,105 (after code review M1+M2) |

**Code review fixes applied (2026-04-14):**
- **M1 — `(` (PAREN)**: Removed redundant `PUSH BC` entry / `POP BC` exit. Shadow BC' already preserves TOS for free across EXX (matches the 7.1 COLON/CREATE/CONSTANT convention for `( -- )` words). −2 bytes.
- **M2 — `NUMBER?` `.numq_ok`**: Replaced `LD A, 0xFF; EXX; LD B, A; LD C, A` (stage-through-A pattern) with `EXX; LD BC, 0xFFFF`. Stage-through-A is only needed when the new TOS is computed from a value living in main set before EXX; for a literal constant, just load BC after the EXX. −1 byte.
- L1 (defensive `EXX` before `JP w_ABORT_cf` in `(` error path) was deferred — it's a deliberate 7.1 convention; changing one site without project-wide reassessment would create inconsistency.

**AC verification:**
- AC #1: All 8 candidates converted to EXX (none deferred under clause (b))
- AC #2: Group A (FILL, MOVE, ROLL, ACCEPT) all pass regression; FILL/ROLL/ACCEPT use plain EXX entry (A-staging for captured TOS bytes), MOVE uses `PUSH BC; EXX; POP BC` to preserve the 16-bit count for LDIR/LDDR
- AC #3: do_number, bdos_putchar, bdos_print_str, BDOS_ENTRY all verified EXX-free
- AC #4: `(` converted to `PUSH BC / EXX` entry and `EXX / POP BC` exit; error path has defensive EXX before JP w_ABORT_cf
- AC #5: NUMBER?'s explicit entry `PUSH BC` removed — shadow BC' implicitly preserves c-addr_orig, making the fail path a clean `EXX / PUSH BC / LD BC, 0`
- AC #6: 14,141 → 14,108 = -33 bytes, exceeds the 16-byte minimum by over 2×
- AC #7: No deferrals — all 8 candidates converted cleanly
- AC #8: Full regression passes — 265/265 REPL tests, zero failures

**Design notes:**
- The "stage through A across EXX" idiom from 7.2's recognizer is now the canonical Group-B exit pattern; it's used by ACCEPT, >NUMBER, and NUMBER? (ok path)
- NUMBER? is the stand-out: by treating shadow BC' as a free c-addr-preservation slot, 4 instructions (`PUSH BC` at entry, `POP AF`/`POP BC`/`PUSH BC` at exits) collapse into just the entry+exit EXX. This pattern generalizes: any word that needs to preserve its original TOS for one specific exit path can do so for free by letting it ride in BC'.

### File List

- src/memory.asm (FILL, MOVE)
- src/stack_ops.asm (ROLL)
- src/io.asm (ACCEPT)
- src/strings.asm (WORD, >NUMBER, NUMBER?, `(`)
- _bmad-output/implementation-artifacts/sprint-status.yaml (status: ready-for-dev → review)
- _bmad-output/implementation-artifacts/7-3-exx-for-de-only-words.md (this file)

## Change Log

| Date       | Change |
|------------|--------|
| 2026-04-13 | Story 7.3 implemented: 8 DE-only words converted from `CALL rpush_de / CALL rpop_de` to `EXX`-based shadow-register save/restore. Binary 14,141 → 14,108 (-33 bytes). NUMBER? additionally leverages shadow BC' to eliminate its explicit entry `PUSH BC`. All 265 regression tests pass. |
| 2026-04-14 | Code review fixes applied: (M1) PAREN `PUSH BC`/`POP BC` removed — shadow BC' preserves TOS for free; (M2) NUMBER? `.numq_ok` simplified to `EXX; LD BC, 0xFFFF`. Binary 14,108 → 14,105 (-3 additional bytes; total -36 from baseline). All 265 regression tests still pass. Status → done. |
