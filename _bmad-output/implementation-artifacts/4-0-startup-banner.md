# Story 4.0: Startup Banner

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to see a startup banner when antforth boots,
so that I know which version I'm running and how much memory is available for definitions.

## Acceptance Criteria

1. **Given** the user starts antforth in normal mode (not TEST_MODE) **When** the cold start completes **Then** a banner is displayed before the first `ok` prompt showing:
   ```
   AntForth v1.00 (C) ant.org 2026
   MicroBeast - xxxx bytes free
   Type BYE to exit
   ```
   **And** `xxxx` is the actual number of free dictionary bytes available

2. **Given** the banner has been displayed **When** the user continues typing at the `ok` prompt **Then** the system behaves identically to before — REPL works normally, all words function correctly

3. **Given** the system is built in TEST_MODE (`make test`) **When** the test binary runs **Then** no banner is displayed **And** all 73 regression tests produce identical output **And** the EXPECTED string is unchanged

4. **Given** all 79 existing REPL tests **When** `make test-repl` runs **Then** all 84 tests pass (79 existing + 5 new banner tests; banner text appears in output but does not affect test matching)

5. **Given** the free memory value displayed in the banner **When** compared to the actual dictionary space **Then** the value accurately reflects the bytes available between HERE and the bottom of the stack area (accounting for both parameter and return stack reservations)

## Tasks / Subtasks

- [x] Task 1: Define banner strings in antforth.asm data area (AC: #1)
  - [x] 1.1 Add `str_banner1` — `"AntForth v1.00 (C) ant.org 2026"` and its length EQU
  - [x] 1.2 Add `str_banner2` — `"MicroBeast - "` and its length EQU
  - [x] 1.3 Add `str_banner3` — `"bytes free"` and its length EQU
  - [x] 1.4 Add `str_banner4` — `"Type BYE to exit"` and its length EQU
  - [x] 1.5 Place near existing `str_ok` and `str_underflow` in the data area (after `rp_base`)

- [x] Task 2: Create banner thread and modify cold start (AC: #1, #2, #3)
  - [x] 2.1 Create a `cold_thread` — a short threaded code sequence that prints the banner then enters QUIT
  - [x] 2.2 Modify the normal-mode cold start path (antforth.asm:78-81) to execute `cold_thread` via NEXT instead of `JP w_QUIT_cf`
  - [x] 2.3 The cold_thread must:
    - Print `str_banner1` + CR (version line)
    - Print `str_banner2` (platform prefix)
    - Calculate and print free bytes (see Dev Notes for calculation)
    - Print `str_banner3` + CR (suffix)
    - Print `str_banner4` + CR (exit hint)
    - Enter QUIT (via `w_QUIT_cf` — CODE word, NEXT JPs directly to its assembly)
  - [x] 2.4 TEST_MODE path (antforth.asm:74-77) must remain unchanged — banner is normal-mode only

- [x] Task 3: Add REPL tests (AC: #1, #4, #5)
  - [x] 3.1 Test 80: Banner version string — start antforth, check output contains `AntForth v1.00`
  - [x] 3.2 Test 81: Banner free memory — start antforth, check output contains numeric value before `bytes free`
  - [x] 3.3 Test 82: Banner platform — start antforth, check output contains `MicroBeast`
  - [x] 3.4 Test 83: Banner unsigned guard — verify no negative sign before `bytes free`
  - [x] 3.5 Test 84: Banner exit hint — check output contains `Type BYE to exit`

- [x] Task 4: Verify no regressions (AC: #2, #3, #4)
  - [x] 4.1 `make test` — all 73 regression tests pass, EXPECTED string unchanged
  - [x] 4.2 `make test-repl` — all 84 REPL tests pass (79 existing + 5 new; banner in output doesn't break grep patterns)
  - [x] 4.3 `make` — normal REPL build succeeds
  - [x] 4.4 Verify existing REPL test grep patterns still work — banner text appears before the first `ok` but existing tests grep for specific output patterns that won't match banner strings

## Dev Notes

### What Already Exists (verified from source)

**Cold start (antforth.asm:18-82):**
```z80
; Normal mode (line 78-81):
        LD      BC, 0           ; Clean TOS
        JP      w_QUIT_cf       ; Enter QUIT directly
```

At this point, all initialization is complete: SP, IX, IY, user area (STATE, BASE, HERE, TIB), hash table — everything ready. The system can execute threaded code immediately.

**QUIT (outer_interpreter.asm:236-271):**
- Resets return stack from `rp_base`, sets STATE=0
- Enters `.quit_loop`: QUERY → INTERPRET → check STATE → print "ok" + CR → loop

**String infrastructure available at cold start:**
- `w_TYPE_cf` (io.asm) — print c-addr u
- `w_CR_cf` (io.asm) — print CR+LF
- `w_DOT_cf` (formatting.asm) — print signed number followed by space
- `w_LIT_cf` (inner_interpreter.asm) — push literal
- `w_FETCH_cf` (memory.asm) — fetch from address
- `w_HERE_cf` (memory.asm) — pushes current HERE **value** (not address)
- `w_MINUS_cf` (arithmetic.asm) — subtract

**Existing data strings (antforth.asm:162-167):**
```z80
sp_base:        DW      0               ; at line 162
rp_base:        DW      0               ; at line 163
str_ok:         DB      " ok"           ; at line 164
STR_OK_LEN      EQU     3
str_underflow:  DB      "? Stack underflow"
STR_UNDERFLOW_LEN EQU  17
```

### Design: Cold Thread Approach

Instead of `JP w_QUIT_cf`, the cold start will `LD DE, cold_thread` then `NEXT` into a short thread that prints the banner and then enters QUIT.

```z80
; Modified normal mode (antforth.asm, inside ELSE branch):
        LD      BC, 0           ; Clean TOS
        LD      DE, cold_thread
        NEXT                    ; Enter banner thread
cold_thread:
        DW      w_LIT_cf, str_banner1       ; "AntForth v1.00 (C) ant.org 2026"
        DW      w_LIT_cf, STR_BANNER1_LEN
        DW      w_TYPE_cf, w_CR_cf
        DW      w_LIT_cf, str_banner2       ; "MicroBeast - "
        DW      w_LIT_cf, STR_BANNER2_LEN
        DW      w_TYPE_cf
        DW      w_LIT_cf, sp_base           ; Calculate free bytes
        DW      w_FETCH_cf
        DW      w_LIT_cf, PS_SIZE + RS_SIZE
        DW      w_MINUS_cf
        DW      w_HERE_cf
        DW      w_MINUS_cf
        DW      w_U_DOT_cf                  ; print unsigned
        DW      w_LIT_cf, str_banner3       ; "bytes free"
        DW      w_LIT_cf, STR_BANNER3_LEN
        DW      w_TYPE_cf, w_CR_cf
        DW      w_LIT_cf, str_banner4       ; "Type BYE to exit"
        DW      w_LIT_cf, STR_BANNER4_LEN
        DW      w_TYPE_cf, w_CR_cf
        DW      w_QUIT_cf                   ; CODE word — NEXT JPs directly
```

### Free Memory Calculation

**Memory layout (low to high):**
```
TPA_START (0x100) → [kernel code] → kernel_end (initial HERE) → [free dictionary space] → ... → [return stack ↓ RS_SIZE] → [parameter stack ↓ PS_SIZE] → sp_base (BDOS entry)
```

Free dictionary bytes = (sp_base - PS_SIZE - RS_SIZE) - HERE

This is the space available for new definitions before colliding with the return stack. With PS_SIZE = RS_SIZE = 256, this subtracts 512 from sp_base.

On a typical CP/M system with BDOS at ~0xDC00, kernel_end around ~0x1B00:
- Free ≈ 0xDC00 - 512 - 0x1B00 ≈ ~48KB (will vary by system)

### Where to Place the Cold Thread

The `cold_thread` DW sequence is placed inside the ELSE branch of the `IFDEF TEST_MODE` block, immediately after the `NEXT` macro. Execution never falls through to the DW data because NEXT ends with `JP (HL)`. sjasmplus multi-pass resolution handles forward references to `w_XXX_cf` labels.

### REPL Test Considerations

The banner prints before the first `ok` prompt. Existing REPL tests pipe Forth input and grep for specific output. The banner text (`AntForth`, `MicroBeast`, `bytes free`) won't match any existing test grep patterns, so existing tests should pass unchanged.

**Verify by checking a few existing patterns:**
- Test 1 greps for `A` in output from `65 EMIT` — banner doesn't interfere
- Test 4 greps for `5 ` in output from `2 3 + .` — banner doesn't match
- Test 17 greps for `49` — banner doesn't match

New tests (80-82) should grep for banner-specific strings.

### Code Field Label Convention (CRITICAL)

No new DEFWORD words in this story. cold_thread is raw DW data, not a Forth word. No `w_XXX_cf` labels to create.

### Anti-Patterns to Avoid

1. **Do NOT modify QUIT** — QUIT's behaviour must remain unchanged. The banner is printed BEFORE entering QUIT.
2. **Do NOT use raw BDOS calls for the banner** — use the threaded TYPE/CR/DOT infrastructure, which is fully initialised by cold_start.
3. **Do NOT add banner to TEST_MODE path** — regression tests must produce identical output.
4. **Do NOT hardcode the free memory value** — it must be calculated at runtime.
5. **Do NOT add tests to the regression test thread** — use REPL-piped tests only (memory: feedback_repl_tests_preferred.md).
6. **Do NOT create a new source file** — all changes go into existing antforth.asm (banner data + cold_thread + cold_start modification).
7. **Do NOT forget to account for stack reservations** — free bytes is NOT `sp_base - HERE` (that would overcount by 512 bytes of stack space).

### Previous Story Learnings (from Story 3.5)

- sjasmplus does NOT support `LD DE, (addr)` — use `LD HL, (addr)` + register moves if needed
- REPL tests use `grep -q` patterns — ensure banner text doesn't accidentally match existing test patterns
- Code review will be adversarial — anticipate error paths and edge cases

### Git Intelligence

Recent commits show one-commit-per-story pattern:
```
ac161fa completed story 3.5
78a1c45 completed story 3.4
a839099 completed story 3.3
38c7c02 completed story 3.2
8859897 code review story 3.1
```

### Testing Strategy

**Primary: REPL-piped tests** (per memory: feedback_repl_tests_preferred.md)

New tests continue from test 80 onwards in Makefile's `test-repl` target.

**Secondary:** `make test` — all 73 regression tests pass, EXPECTED string unchanged.

**Verification approach:**
1. Before changes: run `make test` and `make test-repl`, confirm all pass
2. After implementation: run both, confirm no regressions
3. New REPL tests validate banner content
4. Manual verification: run `make` and launch antforth interactively to see the banner

### References

- [Source: src/antforth.asm:18-82] — Cold start sequence
- [Source: src/antforth.asm:78-81] — Normal mode entry (`LD BC, 0` / `JP w_QUIT_cf`)
- [Source: src/antforth.asm:162-167] — Existing data strings (sp_base, rp_base, str_ok, str_underflow)
- [Source: src/antforth.asm:188] — `kernel_end` label
- [Source: src/outer_interpreter.asm:236-271] — QUIT implementation
- [Source: src/io.asm] — TYPE, CR, EMIT implementations
- [Source: src/formatting.asm] — DOT (`.`) implementation
- [Source: src/memory.asm:92-98] — HERE implementation
- [Source: src/constants.asm:17-18] — PS_SIZE=256, RS_SIZE=256
- [Source: Makefile:52-71] — `make test` target with EXPECTED string
- [Source: Makefile:73+] — `make test-repl` target (79 REPL tests)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.0] — Story requirements

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Initial implementation used `w_DOT_cf` (signed `.`) for free memory — produced negative values on systems with >32KB free dictionary space. Fixed by switching to `w_U_DOT_cf` (unsigned `U.`).
- `str_banner3` initially had leading space `" bytes free"` — caused double space after `U.` trailing space. Removed leading space.

### Completion Notes List

- Added 4 banner strings (str_banner1-4) with length EQUs in antforth.asm data area
- Created `cold_thread` threaded code sequence inside ELSE branch that prints version line, platform + free memory line, exit hint, then enters QUIT
- Modified normal-mode cold start to `LD DE, cold_thread` / `NEXT` instead of `JP w_QUIT_cf`
- Free memory calculated as `(sp_base_value - PS_SIZE - RS_SIZE) - HERE` using threaded Forth words
- Used `U.` instead of `.` for unsigned display of free bytes (can exceed 32767)
- Added REPL tests 80-84: banner version, numeric free memory, platform, unsigned guard, exit hint (single emulator launch)
- All 73 regression tests pass (EXPECTED unchanged), all 84 REPL tests pass

### Change Log

- 2026-04-10: Implemented startup banner (Story 4.0) — banner strings, cold_thread, cold start modification, 3 new REPL tests
- 2026-04-10: Code review fixes — consolidated IFNDEF into ELSE branch (M1), combined REPL tests into single launch (M2), strengthened free memory grep to require numeric value (M3), added unsigned guard test 83 (L2), added "Type BYE to exit" banner line + test 84, changed (c) to (C) (L1), cleaned up stale dev notes (L3)

### File List

- src/antforth.asm — Added banner strings, cold_thread, modified cold start
- Makefile — Added REPL tests 80-82
