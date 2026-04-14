# Story 8.2: EXX for DOT and U.

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a system maintainer,
I want `DOT` (`.`) and `U.` converted from the `CALL rpush_de` / `CALL rpop_de` save/restore idiom to the Epic 7.3 Group A Path 1 EXX pattern (`PUSH BC / EXX / POP BC` at entry, `EXX / POP BC` at exit),
so that the binary shrinks by ~4 bytes and the formatting pipeline starts using shadow registers — proving the Path 1 pattern on the formatting helpers ahead of Story 8.3's larger `.R` / `.S` restructure.

## Acceptance Criteria

1. **Given** `w_DOT_cf` (src/formatting.asm:132–143) currently uses `CALL rpush_de` at entry (3 bytes) and `CALL rpop_de` at exit (3 bytes) to preserve DE (IP) across calls to `print_neg_prefix` + `emit_unsigned` (both of which clobber BC/DE/HL) **When** entry is converted to `PUSH BC / EXX / POP BC` (3 bytes) and exit to `EXX / POP BC` (1 byte replacing `CALL rpop_de` — the existing `POP BC` for new TOS stays) **Then** `make test && make test-repl` passes all 272 REPL + assembly regression tests with zero failures; `DOT` output is byte-identical for positive, negative, and zero inputs (REPL tests 107, 239, 240 already cover these paths).

2. **Given** `w_U_DOT_cf` (src/formatting.asm:151–160) currently uses `CALL rpush_de` at entry (3 bytes) and `CALL rpop_de` at exit (3 bytes) around `CALL emit_unsigned` **When** entry is converted to `PUSH BC / EXX / POP BC` (3 bytes) and exit to `EXX / POP BC` (1 byte replacing `CALL rpop_de` — the existing `POP BC` for new TOS stays) **Then** `make test && make test-repl` passes all 272 REPL + assembly regression tests with zero failures; `U.` output is byte-identical to pre-story behaviour.

3. **Given** EXX is a leaf-level technique (Epic 7 convention) **When** either `w_DOT_cf` or `w_U_DOT_cf` is converted **Then** the call graph beneath it is verified EXX-free: `check_underflow`, `print_neg_prefix`, `emit_unsigned`, `u_to_str`, `div_bc_by_e`, `digit_to_char`, `bdos_print_str`, `bdos_putchar`, `BDOS_ENTRY` contain no `EXX` or `EX AF,AF'` instructions. Verification: `grep -n "EXX\|EX\s*AF,AF'" src/formatting.asm src/io.asm src/system.asm` for the relevant helper bodies.

4. **Given** the conversion lands **When** `wc -c build/antforth.com` is measured **Then** the binary is at least 4 bytes smaller than the pre-story baseline (14,061 bytes → ≤14,057 bytes). Expected savings: exactly 4 bytes (2 per word).

5. **Given** the changes land **When** the full regression suite runs (`make test && make test-repl`) **Then** all 272 REPL tests + the assembly regression test pass with zero failures; no previously-passing test may regress.

## Tasks / Subtasks

- [x] Task 0: Record baseline (AC: #4, #5)
  - [x] 0.1 `make asm && wc -c build/antforth.com` — 14,061 bytes confirmed
  - [x] 0.2 `make test && make test-repl` — all tests pass (PASS: REPL test 265, assembly regression PASS)

- [x] Task 1: Verify leaf-level EXX-freeness of the DOT/U. call graph (AC: #3)
  - [x] 1.1 grep formatting.asm — no EXX matches anywhere in formatting.asm (zero hits)
  - [x] 1.2 grep io.asm — only matches at lines 122–143 (ACCEPT body); `bdos_print_str` (204), `bdos_putchar` (188), `BDOS_ENTRY` are EXX-free
  - [x] 1.3 grep system.asm — only matches at lines 24, 75, 79 (MARKER body); `check_underflow` (line 278) is EXX-free
  - [x] 1.4 Verification recorded — see Completion Notes

- [x] Task 2: Convert `w_DOT_cf` to EXX Group A Path 1 (AC: #1)
  - [x] 2.1 Replaced `CALL rpush_de` with `PUSH BC` / `EXX` / `POP BC`
  - [x] 2.2 Replaced `CALL rpop_de` with `EXX`
  - [x] 2.3 Existing `POP BC` retained for new TOS
  - [x] 2.4 Updated comments to describe shadow-register pattern
  - [x] 2.5 Build + tests green
  - [x] 2.6 DOT delta: 2 bytes saved (0 entry, −2 exit)

- [x] Task 3: Convert `w_U_DOT_cf` to EXX Group A Path 1 (AC: #2)
  - [x] 3.1 Replaced `CALL rpush_de` with `PUSH BC` / `EXX` / `POP BC`
  - [x] 3.2 Replaced `CALL rpop_de` with `EXX`
  - [x] 3.3 Existing `POP BC` retained
  - [x] 3.4 Updated comments
  - [x] 3.5 Build + tests green
  - [x] 3.6 U. delta: 2 bytes saved (0 entry, −2 exit)

- [x] Task 4: Final verification (AC: #4, #5)
  - [x] 4.1 `make test && make test-repl` — all 272 REPL + assembly regression tests pass
  - [x] 4.2 Final binary: 14,057 bytes (delta = −4 bytes; matches predicted exactly)
  - [x] 4.3 REPL tests 107, 239, 240 covered DOT positive/negative/zero paths — all pass within full suite

## Dev Notes

### Epic Context

Story 8.2 is the second story of Epic 8 (Shadow Register Follow-Up). It converts `DOT` and `U.` — the two simplest formatting words — to the Group A Path 1 EXX pattern established in Epic 7.3 MOVE. This is a mechanical, low-risk story that proves Path 1 works on the formatting pipeline before Story 8.3 tackles the larger `.R` / `.S` restructure.

### Pre-Story Baseline

- Binary: 14,061 bytes (post-Story 8.1 including code-review fixes)
- Tests: 272 REPL tests + 1 assembly regression = all green
- EXX users (all leaf-level, non-nested):
  - 7.1: COLON, CREATE, CONSTANT, CODE, END-CODE, NEXT,, LABEL, MARKER
  - 7.2: ASM_RECOGNIZE (partial — `.recog_fast_false` path does not EXX)
  - 7.3: FILL, MOVE, ROLL, ACCEPT, WORD, >NUMBER, NUMBER?, `(`
  - 8.1: CHAR

### Why Path 1 (not plain EXX)

Both `DOT` and `U.` call `emit_unsigned` / `print_neg_prefix` with **BC = value to print**. A naive `EXX` at entry would swap the live TOS out of main BC into BC' — the downstream helpers would then see BC' garbage. The Group A Path 1 pattern from Epic 7.3 MOVE resolves this:

```asm
PUSH    BC          ; Save old TOS to parameter stack (so we can retrieve post-EXX)
EXX                 ; IP parked in DE'; main BC now holds BC' garbage
POP     BC          ; Recover old TOS into main BC — helpers get the value they need
```

At exit:
```asm
EXX                 ; IP restored from DE' into main DE
POP     BC          ; New TOS from parameter stack (this POP was already present)
```

### Exact Code Transform

**Current `w_DOT_cf` (src/formatting.asm:130–143):**
```asm
w_DOT:
        DEFCODE ".", 0
w_DOT_cf:
        CALL    check_underflow
        ; Save DE (IP) to return stack
        CALL    rpush_de
        ; Handle sign: emit '-' and negate if negative
        CALL    print_neg_prefix
        CALL    emit_unsigned
        ; Restore DE (IP) from return stack
        CALL    rpop_de
        ; Pop new TOS from parameter stack
        POP     BC
        NEXT
```

**Target:**
```asm
w_DOT:
        DEFCODE ".", 0
w_DOT_cf:
        CALL    check_underflow
        ; Park IP in DE' via shadow registers; TOS stays in main BC for helpers
        PUSH    BC
        EXX
        POP     BC
        ; Handle sign: emit '-' and negate if negative
        CALL    print_neg_prefix
        CALL    emit_unsigned
        ; Restore IP from DE'
        EXX
        ; Pop new TOS from parameter stack
        POP     BC
        NEXT
```

**Byte accounting (DOT):**
- Entry: `CALL rpush_de` (3) → `PUSH BC` (1) + `EXX` (1) + `POP BC` (1) = 3 bytes. **Net: 0.**
- Exit: `CALL rpop_de` (3) → `EXX` (1) = 1 byte. **Net: −2.**
- **Total DOT savings: 2 bytes.**

**Current `w_U_DOT_cf` (src/formatting.asm:149–160):**
```asm
w_U_DOT:
        DEFCODE "U.", 0
w_U_DOT_cf:
        CALL    check_underflow
        ; Save DE (IP) to return stack
        CALL    rpush_de
        CALL    emit_unsigned
        ; Restore DE (IP) from return stack
        CALL    rpop_de
        ; Pop new TOS from parameter stack
        POP     BC
        NEXT
```

**Target:** Same transform — 3-instruction entry block + 1-instruction exit. **U. savings: 2 bytes.**

**Combined savings: 4 bytes.**

### Leaf-Level Audit Expectations

The DOT/U. call graph is:

```
w_DOT_cf / w_U_DOT_cf
  ├── check_underflow            (src/system.asm:278)
  ├── print_neg_prefix           (src/formatting.asm:91) — DOT only
  │     └── bdos_putchar         (src/io.asm)
  └── emit_unsigned              (src/formatting.asm:116)
        ├── u_to_str             (src/formatting.asm, upstream of line 70)
        │     ├── div_bc_by_e
        │     └── digit_to_char
        ├── bdos_print_str       (src/io.asm:204)
        └── bdos_putchar         (src/io.asm)
              └── BDOS_ENTRY
```

All of these were verified EXX-free in Epic 7.3 Task 1.2 (`bdos_print_str`, `bdos_putchar`, `BDOS_ENTRY`) and by inspection in the Epic 8 spec (remaining helpers). Re-run the grep in Task 1 as a regression check — the survey is dated, and someone could plausibly have added EXX to a helper during Epic 7/8 work.

### Register Contract Reminder

- `BC` = TOS, `DE` = IP, `SP` = parameter stack, `IX` = return stack, `IY` = user pointer, `HL`/`AF` = scratch
- After EXX: BC'/DE'/HL' preserved in shadows, main BC/DE/HL become free scratch (swapped with whatever was in shadows)
- A (and AF) survive EXX — canonical idiom for exit-staging a computed byte value (not needed here; TOS comes from parameter stack via `POP BC`)

### Previous Story Learnings (7.1, 7.2, 7.3, 8.1)

**From 7.1 (build-header words):**
- Code review caught a vestigial `INC IX` in `w_QUERY_cf` left over from rpop_bc refactoring — **always audit for leftover stack-management instructions after refactoring**. This story doesn't use IX, but the habit applies: verify no orphaned `CALL rpop_*` or `INC IX` remains after the edit.

**From 7.2 (recognizer):**
- When EXX frees registers, hunt for scratch-variable eliminations. For DOT/U. there are no word-local scratch variables (the scratch lives in `u_to_str` / `emit_unsigned` which are unchanged), so no additional eliminations apply.

**From 7.3 (DE-only words):**
- Group A Path 1 (`PUSH BC / EXX / POP BC` entry, `EXX` exit) is proven in MOVE — this story reuses it exactly.
- Shadow BC' as free TOS-preservation slot — not applicable here (DOT/U. consume TOS, they don't need to preserve it across the body).

**From 8.1 (CHAR + ABORT"):**
- CHAR used the `( -- char )` variant of the pattern (entry `PUSH BC / EXX` with no matching `POP BC`, because the stack was being grown rather than save/restored). DOT/U. are different — they are `( n -- )` and `( u -- )`, so the pre-existing `POP BC` at the end is correctly consuming the new TOS that sits below the old TOS after the entry `PUSH BC`.
- Be paranoid about the register state after the exit EXX — main BC holds BC'-garbage from the entry swap. Confirm the `POP BC` at line 142 / line 159 overwrites it before `NEXT`.

### What Not To Change

- **`print_neg_prefix`, `emit_unsigned`, `u_to_str`, `div_bc_by_e`, `digit_to_char`** — helper bodies remain untouched. They must stay EXX-free so other EXX-using words can continue to call them.
- **`check_underflow`** — untouched.
- **`rpush_de` / `rpop_de`** — still used by `.R`, `.S`, and other words not in this story's scope. Do not remove the symbols.
- **The `POP BC` at src/formatting.asm:142 and src/formatting.asm:159** — this is the new-TOS pop. It stays.

### Build/Test Commands

```bash
make asm                    # Assemble with sjasmplus
make test                   # Run assembly-level regression test
make test-repl              # Run 272 REPL-piped Forth regression tests
wc -c build/antforth.com    # Check binary size
```

### Byte Budget

| Change                         | Old (bytes) | New (bytes) | Savings |
|--------------------------------|-------------|-------------|---------|
| DOT entry CALL rpush_de → PUSH BC / EXX / POP BC | 3 | 3 | 0 |
| DOT exit CALL rpop_de → EXX    | 3 | 1 | 2 |
| U. entry CALL rpush_de → PUSH BC / EXX / POP BC  | 3 | 3 | 0 |
| U. exit CALL rpop_de → EXX     | 3 | 1 | 2 |
| **Total**                      |   |   | **4 bytes** |

AC target: ≥ 4 bytes (matches predicted exactly — no slack).

### References

- [Source: _bmad-output/planning-artifacts/epic8-shadow-register-followup.md#Story 8.2] — epic spec for this story
- [Source: docs/shadow-register-followup-survey.md] — authoritative survey, categorises DOT/U. under "Group A Path 1 formatting"
- [Source: _bmad-output/implementation-artifacts/7-3-exx-for-de-only-words.md] — Group A Path 1 pattern (MOVE, ROLL)
- [Source: _bmad-output/implementation-artifacts/8-1-exx-for-char-and-abort-quote.md] — previous Epic 8 story; baseline binary size and leaf-level audit precedent
- [Source: src/formatting.asm:91–106] — `print_neg_prefix` (verify EXX-free)
- [Source: src/formatting.asm:116–124] — `emit_unsigned` (verify EXX-free)
- [Source: src/formatting.asm:130–143] — `w_DOT_cf` (edit target)
- [Source: src/formatting.asm:149–160] — `w_U_DOT_cf` (edit target)
- [Source: src/io.asm:204] — `bdos_print_str` (EXX-free, verified Epic 7.3)
- [Source: src/system.asm:278] — `check_underflow` (verify EXX-free)
- [Source: src/inner_interpreter.asm] — rpush_de/rpop_de reference (NOT modified)

### Project Structure Notes

- `src/formatting.asm` — only file modified (DOT + U. bodies)
- No new files, no new subroutines, no data scratch changes

## Dev Agent Record

### Agent Model Used

claude-opus-4-6 (1M context)

### Debug Log References

None — clean implementation, no debug iterations required.

### Completion Notes List

- Converted `w_DOT_cf` and `w_U_DOT_cf` to Group A Path 1 EXX pattern (`PUSH BC / EXX / POP BC` entry, `EXX` exit) per Epic 7.3 MOVE precedent.
- Leaf-level audit confirmed: only EXX users in the three searched files are `w_MARKER_cf` (system.asm:24,75,79) and `w_ACCEPT_cf` (io.asm:122–143) — neither is in the DOT/U. call graph. `print_neg_prefix`, `emit_unsigned`, `u_to_str`, `div_bc_by_e`, `digit_to_char`, `bdos_print_str`, `bdos_putchar`, `BDOS_ENTRY`, `check_underflow` all verified EXX-free.
- Binary: 14,061 → 14,057 bytes (−4 bytes, exactly matches AC #4 predicted savings).
- Tests: 272 REPL tests + 1 assembly regression — all pass, zero regressions.
- `rpush_de` / `rpop_de` symbols retained (still used by `.R`, `.S`, others — Story 8.3 will address `.R`/`.S`).
- Code review (2026-04-14): 1 MEDIUM, 4 LOW findings; MEDIUM addressed. `u_to_str` (src/formatting.asm:52) and `emit_unsigned` (src/formatting.asm:111) header comments updated from "save DE to return stack" to "preserve DE via rpush_de or EXX" — they previously misrepresented the callee contract and would have misled Story 8.3 (the `.R` / `.S` conversion). Binary unchanged (14,057 bytes — comment-only); all 272 REPL + 1 assembly regression still pass.

### File List

- src/formatting.asm (modified — `w_DOT_cf` lines 132–145, `w_U_DOT_cf` lines 153–164)

### Change Log

| Date       | Change                                                                                              |
|------------|-----------------------------------------------------------------------------------------------------|
| 2026-04-14 | Converted `w_DOT_cf` and `w_U_DOT_cf` to EXX Group A Path 1 pattern; binary −4 bytes; status: review |
| 2026-04-14 | Code review: MEDIUM comment-contract fix on `u_to_str` (line 52) and `emit_unsigned` (line 111) headers — now describe rpush_de/EXX duality instead of stale "save DE to return stack"; binary unchanged; status: done |
