# Story 4.0: Startup Banner

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to see a startup banner when antforth boots,
so that I know which version I'm running and how much memory is available for definitions.

## Acceptance Criteria

1. **Given** the user starts antforth in normal mode (not TEST_MODE) **When** the cold start completes **Then** a banner is displayed before the first `ok` prompt showing:
   ```
   AntForth v1.00 (c) ant.org 2026
   MicroBeast - xxxx bytes free
   ```
   **And** `xxxx` is the actual number of free dictionary bytes available

2. **Given** the banner has been displayed **When** the user continues typing at the `ok` prompt **Then** the system behaves identically to before — REPL works normally, all words function correctly

3. **Given** the system is built in TEST_MODE (`make test`) **When** the test binary runs **Then** no banner is displayed **And** all 73 regression tests produce identical output **And** the EXPECTED string is unchanged

4. **Given** all 79 existing REPL tests **When** `make test-repl` runs **Then** all 79 tests still pass (banner text appears in output but does not affect test matching)

5. **Given** the free memory value displayed in the banner **When** compared to the actual dictionary space **Then** the value accurately reflects the bytes available between HERE and the bottom of the stack area (accounting for both parameter and return stack reservations)

## Tasks / Subtasks

- [ ] Task 1: Define banner strings in antforth.asm data area (AC: #1)
  - [ ] 1.1 Add `str_banner1` — `"AntForth v1.00 (c) ant.org 2026"` and its length EQU
  - [ ] 1.2 Add `str_banner2` — `"MicroBeast - "` and its length EQU
  - [ ] 1.3 Add `str_banner3` — `" bytes free"` and its length EQU
  - [ ] 1.4 Place near existing `str_ok` and `str_underflow` in the data area (after `rp_base`)

- [ ] Task 2: Create banner thread and modify cold start (AC: #1, #2, #3)
  - [ ] 2.1 Create a `cold_thread` — a short threaded code sequence that prints the banner then enters QUIT
  - [ ] 2.2 Modify the normal-mode cold start path (antforth.asm:78-81) to execute `cold_thread` via NEXT instead of `JP w_QUIT_cf`
  - [ ] 2.3 The cold_thread must:
    - Print `str_banner1` + CR (version line)
    - Print `str_banner2` (platform prefix)
    - Calculate and print free bytes (see Dev Notes for calculation)
    - Print `str_banner3` + CR (suffix)
    - Enter QUIT (via `w_QUIT_cf` word or JP directly — QUIT resets return stack and STATE, so it's safe to call)
  - [ ] 2.4 TEST_MODE path (antforth.asm:74-77) must remain unchanged — banner is normal-mode only

- [ ] Task 3: Add REPL tests (AC: #1, #4, #5)
  - [ ] 3.1 Test 80: Banner version string — start antforth, check output contains `AntForth v1.00`
  - [ ] 3.2 Test 81: Banner free memory — start antforth, check output contains `bytes free`
  - [ ] 3.3 Test 82: Banner platform — start antforth, check output contains `MicroBeast`

- [ ] Task 4: Verify no regressions (AC: #2, #3, #4)
  - [ ] 4.1 `make test` — all 73 regression tests pass, EXPECTED string unchanged
  - [ ] 4.2 `make test-repl` — all 79 existing REPL tests pass (banner in output doesn't break grep patterns)
  - [ ] 4.3 `make` — normal REPL build succeeds
  - [ ] 4.4 Verify existing REPL test grep patterns still work — banner text appears before the first `ok` but existing tests grep for specific output patterns that won't match banner strings

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
; Modified normal mode (antforth.asm):
        LD      BC, 0           ; Clean TOS
        LD      DE, cold_thread
        NEXT                    ; Enter banner thread

cold_thread:
        ; Line 1: "AntForth v1.00 (c) ant.org 2026"
        DW      w_LIT_cf, str_banner1
        DW      w_LIT_cf, STR_BANNER1_LEN
        DW      w_TYPE_cf
        DW      w_CR_cf
        ; Line 2: "MicroBeast - XXXX bytes free"
        DW      w_LIT_cf, str_banner2
        DW      w_LIT_cf, STR_BANNER2_LEN
        DW      w_TYPE_cf
        ; Calculate free bytes: (sp_base - PS_SIZE - RS_SIZE) - HERE
        DW      w_LIT_cf, sp_base
        DW      w_FETCH_cf              ; ( sp_base_value )
        DW      w_LIT_cf, PS_SIZE + RS_SIZE
        DW      w_MINUS_cf              ; ( sp_base - 512 = bottom of stack area )
        DW      w_HERE_cf               ; ( stack_bottom here )
        DW      w_MINUS_cf              ; ( free_bytes )
        DW      w_DOT_cf                ; print number + space
        DW      w_LIT_cf, str_banner3
        DW      w_LIT_cf, STR_BANNER3_LEN
        DW      w_TYPE_cf
        DW      w_CR_cf
        ; Enter QUIT
        DW      w_LIT_cf, w_QUIT_cf
        DW      w_EXECUTE_cf
```

**Note on entering QUIT:** QUIT is a CODE word — we can't use `DW w_QUIT_cf` directly in the thread (that would try to interpret the address as an xt, but QUIT's code field contains Z80 machine code, not a `JP DOCOL`). The correct pattern is `w_LIT_cf, w_QUIT_cf, w_EXECUTE_cf` which pushes the xt and executes it. Alternatively, the cold_thread could end with a direct `JP w_QUIT_cf` in assembly, but that breaks the threading model. The EXECUTE approach is cleaner.

**Actually — simpler:** QUIT is a CODE word, so its cf label IS its xt. `DW w_QUIT_cf` in a thread IS valid — NEXT fetches the cell at (DE), loads it into HL, then `JP (HL)`. Since w_QUIT_cf points to CODE (starts with assembly), `JP (HL)` lands directly in the assembly code. This is how all CODE words work in threads. So `DW w_QUIT_cf` at the end of cold_thread is correct and simplest.

```z80
        ; Enter QUIT (CODE word — NEXT will JP to its assembly directly)
        DW      w_QUIT_cf
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

The `cold_thread` DW sequence should be placed in the normal-mode section of antforth.asm, after the cold start assembly code but before the INCLUDEs. It only needs to be in the non-TEST_MODE build — but since it references word labels defined in included files, it should go AFTER those includes or rely on sjasmplus multi-pass resolution (which handles forward references to `w_XXX_cf` labels — the existing test threads at line 119+ already do this).

**Recommended placement:** Right after the cold start code (line 82), inside an `IFNDEF TEST_MODE` block (or the existing ELSE branch). Since sjasmplus resolves forward DW references on second pass, the thread can reference any `w_XXX_cf` label.

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

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
