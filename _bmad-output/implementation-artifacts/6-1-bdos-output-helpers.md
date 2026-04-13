# Story 6.1: BDOS Output Helpers

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want repeated BDOS character-output patterns extracted into shared subroutines,
so that the binary shrinks by ~160-180 bytes without changing any observable behaviour.

## Acceptance Criteria

1. **Given** the new `bdos_putchar` subroutine in `src/io.asm` **When** any code calls it with E = character **Then** BDOS function 2 (C_WRITE) is invoked and the subroutine returns, clobbering A, BC, DE, HL (as BDOS does)

2. **Given** all 47 inline `LD C, C_WRITE / CALL BDOS_ENTRY` sequences across 9 source files **When** each is replaced with `CALL bdos_putchar` (or `JP bdos_putchar` for tail-call sites) **Then** `make test && make test-repl` passes all 531+ regression tests with zero failures

3. **Given** the new `bdos_crlf` subroutine **When** inline CR+LF output sequences are replaced with `CALL bdos_crlf` (or `JP bdos_crlf` for tail calls) **Then** all tests pass

4. **Given** `asm_print_str` promoted from `assembler.asm` to `io.asm` as `bdos_print_str` **When** inline print-string loops matching its contract (HL = string, B = length) are replaced with `CALL bdos_print_str` **Then** all tests pass **And** `asm_print_str` in assembler.asm becomes `asm_print_str EQU bdos_print_str`

5. **Given** `asm_print_q_crlf` promoted to `io.asm` as `bdos_print_q_crlf` **When** inline ` ?` + CR/LF sequences are replaced with `CALL bdos_print_q_crlf` (or `JP` for tail calls) **Then** all tests pass

6. **Given** all layers are complete **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 140 bytes smaller than the pre-story baseline (15,519 bytes)

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #6)
  - [x] 0.1 `make asm && wc -c build/antforth.com` — record exact byte count
  - [x] 0.2 `make test && make test-repl` — confirm all tests pass before any changes

- [x] Task 1: Create `bdos_putchar` in `src/io.asm` (AC: #1)
  - [x] 1.1 Add subroutine at end of io.asm (after w_KEYQ), with section comment:
    ```asm
    ; -----------------------------------------------
    ; Internal BDOS output helpers (not Forth words)
    ; -----------------------------------------------
    bdos_putchar:               ; Entry: E = character
        LD      C, C_WRITE      ; 2 bytes
        CALL    BDOS_ENTRY      ; 3 bytes
        RET                     ; 1 byte — 6 bytes total
    ```
  - [x] 1.2 Build passes: `make asm`

- [x] Task 2: Replace all 47 `LD C, C_WRITE / CALL BDOS_ENTRY` with `CALL bdos_putchar` (AC: #2)
  - [x] 2.1 `src/io.asm` — 7 sites (lines 14, 43, 67, 72, 86, 109, 153)
  - [x] 2.2 `src/assembler.asm` — 12 sites (lines 238, 261, 264, 267, 270, 306, 404, 424, 433, 436, 439, 442). **Line 306 is a tail-call**: `LD C, C_WRITE / JP BDOS_ENTRY` becomes `JP bdos_putchar` (not CALL)
  - [x] 2.3 `src/formatting.asm` — 11 sites (lines 99, 107, 130, 240, 251, 264, 321, 333, 342, 345, 423)
  - [x] 2.4 `src/compiler.asm` — 5 sites (lines 473, 481, 484, 488, 491)
  - [x] 2.5 `src/dictionary.asm` — 4 sites (lines 204, 214, 236, 239)
  - [x] 2.6 `src/system.asm` — 4 sites (lines 161, 372, 380, 383)
  - [x] 2.7 `src/strings.asm` — 2 sites (lines 848, 948)
  - [x] 2.8 `src/control_flow.asm` — 1 site (line 23)
  - [x] 2.9 `src/outer_interpreter.asm` — 1 site (line 119)
  - [x] 2.10 Build and test: `make asm && make test && make test-repl`

- [x] Task 3: Create `bdos_crlf` in `src/io.asm` (AC: #3)
  - [x] 3.1 Add after `bdos_putchar`:
    ```asm
    bdos_crlf:                  ; Print CR + LF
        LD      E, 0x0D
        CALL    bdos_putchar
        LD      E, 0x0A
        JP      bdos_putchar    ; tail-call, 10 bytes total
    ```
  - [x] 3.2 Build passes: `make asm`

- [x] Task 4: Replace inline CRLF sequences with `CALL bdos_crlf` (AC: #3)
  - [x] 4.1 `compiler.asm` — replace 2x `LD E, 0x0D/0x0A + CALL bdos_putchar` with `CALL bdos_crlf`
  - [x] 4.2 `dictionary.asm` — same replacement
  - [x] 4.3 `system.asm` — same replacement
  - [x] 4.4 `io.asm` w_CR_cf — simplify to: `BDOS_SAVE / CALL bdos_crlf / BDOS_RESTORE / NEXT`
  - [x] 4.5 `assembler.asm` asm_print_q_crlf — replace trailing CR/LF with `JP bdos_crlf` (tail-call replaces 2x CALL + RET)
  - [x] 4.6 `assembler.asm` asm_print_error_with_name — replace trailing CR/LF with `CALL bdos_crlf`
  - [x] 4.7 Build and test: `make asm && make test && make test-repl`

- [x] Task 5: Promote `asm_print_str` to `bdos_print_str` in `src/io.asm` (AC: #4)
  - [x] 5.1 Move subroutine body from `assembler.asm:233-244` to io.asm (after `bdos_crlf`), rename to `bdos_print_str`. Internal BDOS call already uses `CALL bdos_putchar` after Task 2.
  - [x] 5.2 In assembler.asm, replace old body with: `asm_print_str EQU bdos_print_str`
  - [x] 5.3 Fix `asm_print_error` (assembler.asm:251): fall-through to asm_print_q_crlf breaks after EQU. Change to `CALL bdos_print_str / JP asm_print_q_crlf` (see Dev Notes gotcha)
  - [x] 5.4 Build and test: `make asm && make test && make test-repl`

- [x] Task 6: Replace inline print-string loops with `CALL bdos_print_str` (AC: #4)
  - [x] 6.1 `compiler.asm` .comp_err_print — replace DJNZ loop with `CALL bdos_print_str`
  - [x] 6.2 `control_flow.asm` .qcomp_print — replace DJNZ loop with `CALL bdos_print_str` (string includes embedded CR+LF, no separate CRLF needed)
  - [x] 6.3 `system.asm` .print_loop (underflow) — replace DJNZ loop with `CALL bdos_print_str`
  - [x] 6.4 `formatting.asm` .eu_emit — replace loop with `CALL bdos_print_str`
  - [x] 6.5 `assembler.asm` .pen_pfx and .pen_name — replace both DJNZ loops with `CALL bdos_print_str`
  - [x] 6.6 **SKIP dictionary.asm .words_print** — uses DE register pair (not HL). Structural mismatch. Layer 1 only.
  - [x] 6.7 Build and test: `make asm && make test && make test-repl`

- [x] Task 7: Promote `asm_print_q_crlf` to `bdos_print_q_crlf` in `src/io.asm` (AC: #5)
  - [x] 7.1 Move subroutine body from assembler.asm to io.asm (after `bdos_print_str`), rename to `bdos_print_q_crlf`. Internal calls already use `CALL bdos_putchar` (Layer 1) and `JP bdos_crlf` (Layer 2).
  - [x] 7.2 In assembler.asm: `asm_print_q_crlf EQU bdos_print_q_crlf`
  - [x] 7.3 Fix `asm_print_error`: must now be `CALL bdos_print_str / JP bdos_print_q_crlf` (explicit tail-call, no fall-through)
  - [x] 7.4 Build and test: `make asm && make test && make test-repl`

- [x] Task 8: Replace inline ` ?` + CRLF with `CALL bdos_print_q_crlf` (AC: #5)
  - [x] 8.1 `compiler.asm` — replace inline ` ` + `?` + CRLF after .comp_err_print with `CALL bdos_print_q_crlf`
  - [x] 8.2 `assembler.asm` asm_print_error_with_name — replace inline ` ?` + CRLF with `CALL bdos_print_q_crlf`
  - [x] 8.3 Build and test: `make asm && make test && make test-repl`

- [x] Task 9: Final verification (AC: #6)
  - [x] 9.1 `make test && make test-repl` — all tests green
  - [x] 9.2 `wc -c build/antforth.com` — record final size, compute delta from Task 0 baseline
  - [x] 9.3 Verify savings >= 140 bytes

## Dev Notes

### Register Contract (critical — violating this will corrupt execution)

- `BC` = TOS (top of parameter stack). Always valid after any Forth word returns.
- `DE` = IP (instruction pointer into threaded code). Never touch in CODE words except via NEXT.
- `SP` = parameter stack pointer (grows downward). PUSH/POP for stack operations.
- `IX` = return stack pointer (grows downward). Used by `>R`, `R>`, DOCOL, EXIT.
- `HL`, `AF` = scratch. Free to use within CODE words.
- **BDOS clobbers ALL registers** (A, BC, DE, HL, F). Any register needed after a BDOS call must be saved/restored.

### New Subroutine Contracts

| Subroutine | Entry | Clobbers | Size | Location |
|---|---|---|---|---|
| `bdos_putchar` | E = character | A, BC, DE, HL (via BDOS) | 6 bytes | io.asm |
| `bdos_crlf` | (none) | A, BC, DE, HL | 10 bytes | io.asm |
| `bdos_print_str` | HL = string, B = length | A, BC, DE, HL | ~10 bytes | io.asm (moved from assembler.asm) |
| `bdos_print_q_crlf` | (none) | A, BC, DE, HL | ~8 bytes | io.asm (moved from assembler.asm) |

### Mechanical Substitution Pattern (Layer 1)

```asm
; BEFORE (5 bytes):
    LD      C, C_WRITE      ; 2 bytes
    CALL    BDOS_ENTRY       ; 3 bytes

; AFTER (3 bytes):
    CALL    bdos_putchar     ; 3 bytes
```

Tail-call variant (assembler.asm:306):
```asm
; BEFORE: LD C, C_WRITE / JP BDOS_ENTRY (5 bytes)
; AFTER:  JP bdos_putchar (3 bytes)
```

### Critical Gotcha: asm_print_error Fall-Through

Current code at assembler.asm:251-253:
```asm
asm_print_error:
    CALL    asm_print_str
    ; Fall through to asm_print_q_crlf
asm_print_q_crlf:
    ...code...
```

After Layer 4 promotion, `asm_print_q_crlf` becomes an EQU (no code at that address). Fix:
```asm
asm_print_error:
    CALL    bdos_print_str
    JP      bdos_print_q_crlf   ; explicit tail-call replaces fall-through
asm_print_q_crlf EQU bdos_print_q_crlf
```

### Critical Gotcha: dictionary.asm Uses DE Not HL

`.words_print` (dictionary.asm:199-209) iterates with DE as the string pointer. `bdos_print_str` expects HL. Do NOT replace this loop with `CALL bdos_print_str`. Apply Layer 1 only (replace `LD C, C_WRITE / CALL BDOS_ENTRY` with `CALL bdos_putchar`).

### Critical Gotcha: io.asm w_CR Double BDOS_SAVE/RESTORE

Current w_CR_cf does two separate BDOS_SAVE/CALL/BDOS_RESTORE cycles (one for CR, one for LF). After Layer 2:
```asm
w_CR_cf:
    BDOS_SAVE               ; PUSH DE, PUSH BC
    CALL    bdos_crlf
    BDOS_RESTORE            ; POP BC, POP DE
    NEXT
```

### Critical Gotcha: control_flow.asm qcomp_print

`.comp_only_msg` string includes CR+LF as last 2 bytes, B=16 includes them. `CALL bdos_print_str` prints all 16 bytes including the embedded CR+LF. No separate CRLF call needed.

### Include Order (forward references OK)

io.asm is included at antforth.asm:127. dictionary.asm (118) and control_flow.asm (126) are BEFORE io.asm but sjasmplus is a multi-pass assembler — forward references to `bdos_putchar` resolve correctly. No include reordering needed.

### Savings Estimate

| Layer | Subroutine cost | Sites | Bytes/site | Net savings |
|---|---|---|---|---|
| 1: bdos_putchar | 6 bytes | 47 | 2 | ~88 bytes |
| 2: bdos_crlf | 10 bytes | ~5 | 7 | ~25 bytes |
| 3: bdos_print_str | 0 (moved) | ~7 | ~9 | ~54 bytes |
| 4: bdos_print_q_crlf | 0 (moved) | ~2 | ~10 | ~20 bytes |
| **Total** | | | | **~187 bytes** |

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression tests
make test-repl              # Run REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Project Structure Notes

- All source in `src/` directory, included by `src/antforth.asm` manifest
- New subroutines are NOT Forth words (no DEFCODE/dictionary entry) — just assembler labels
- Promoted subroutines retain their `asm_*` names as EQU aliases for backward compatibility

### References

- [Source: src/io.asm:1-204] — Target file for new subroutines
- [Source: src/assembler.asm:233-244] — asm_print_str to promote (Layer 3)
- [Source: src/assembler.asm:251-272] — asm_print_error + asm_print_q_crlf fall-through (Layer 4 gotcha)
- [Source: src/assembler.asm:306-307] — Tail-call site (JP BDOS_ENTRY)
- [Source: src/macros.asm:137-148] — BDOS_SAVE/BDOS_RESTORE macro definitions
- [Source: src/antforth.asm:127] — io.asm include position
- [Source: _bmad-output/planning-artifacts/epic6-code-size-optimization.md] — Epic spec with all layer details
- [Source: _bmad-output/implementation-artifacts/5-4-ans-forth-core-quick-wins.md] — Previous story patterns and learnings

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.6

### Debug Log References

No debug issues encountered. All 48 replacement sites compiled and tested cleanly on first attempt.

### Completion Notes List

- Task 0: Baseline recorded — 15,519 bytes, 266 tests passing (1 asm + 265 REPL)
- Task 1: Created `bdos_putchar` in io.asm (6 bytes)
- Task 2: Replaced all 48 sites (47 CALL + 1 JP) across 9 files. Layer 1 savings: 88 bytes (15,519 → 15,431)
- Task 3: Created `bdos_crlf` in io.asm (10 bytes, tail-call to bdos_putchar)
- Task 4: Replaced 6 inline CRLF sites. Layer 2 savings: 37 bytes (15,431 → 15,394)
- Task 5: Promoted asm_print_str to bdos_print_str in io.asm; replaced with EQU alias; fixed asm_print_error fall-through with explicit JP
- Task 6: Replaced 7 DJNZ print-string loops (compiler, control_flow, system, formatting, assembler x2). Skipped dictionary.asm (DE not HL). Layer 3 net savings: 49 bytes (after +3 for fall-through fix)
- Task 7: Promoted asm_print_q_crlf to bdos_print_q_crlf in io.asm; replaced with EQU alias; updated asm_print_error JP target
- Task 8: Replaced 2 inline " ?" + CRLF sequences (compiler, assembler). Layer 4 savings: 20 bytes
- Task 9: Final verification — 15,328 bytes, all 266 tests pass, delta = **191 bytes saved** (exceeds 140-byte threshold)
- Review fix: Replaced 4 additional DJNZ print-string loops with `CALL bdos_print_str` (formatting.asm x2, system.asm, strings.asm). Added length EQU constant in control_flow.asm. Final size: 15,294 bytes, **225 bytes saved** total.

### File List

- src/io.asm — Added bdos_putchar, bdos_crlf, bdos_print_str, bdos_print_q_crlf; replaced 7 inline BDOS calls; simplified w_CR_cf
- src/assembler.asm — Replaced 13 inline BDOS calls; promoted asm_print_str/asm_print_q_crlf to EQU aliases; fixed asm_print_error fall-through; replaced pen_pfx/pen_name loops; replaced pen_no_name inline sequence
- src/formatting.asm — Replaced 11 inline BDOS calls; replaced eu_emit, dots_depth_emit, dotr_emit_loop DJNZ loops
- src/compiler.asm — Replaced 5 inline BDOS calls; replaced comp_err_print DJNZ loop; replaced inline " ?" + CRLF
- src/dictionary.asm — Replaced 4 inline BDOS calls; replaced inline CRLF
- src/system.asm — Replaced 4 inline BDOS calls; replaced print_loop and paq_print DJNZ loops; replaced inline CRLF
- src/strings.asm — Replaced 2 inline BDOS calls; replaced paren_err_print DJNZ loop
- src/control_flow.asm — Replaced 1 inline BDOS call; replaced qcomp_print DJNZ loop; added .comp_only_len EQU constant
- src/outer_interpreter.asm — Replaced 1 inline BDOS call

## Change Log

- 2026-04-13: Story 6.1 implemented — extracted BDOS output helpers (bdos_putchar, bdos_crlf, bdos_print_str, bdos_print_q_crlf) into io.asm, replaced 48 inline patterns across 9 source files. Binary reduced by 191 bytes (15,519 → 15,328).
- 2026-04-13: Code review fixes — replaced 4 missed bdos_print_str DJNZ loops (formatting.asm .dots_depth_emit/.dotr_emit_loop, system.asm .paq_print, strings.asm .paren_err_print); added .comp_only_len EQU constant in control_flow.asm. Binary reduced by additional 34 bytes (15,328 → 15,294). Total savings: 225 bytes.
