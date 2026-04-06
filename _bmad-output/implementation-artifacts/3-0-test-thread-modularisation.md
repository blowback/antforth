# Story 3.0: Test Thread Modularisation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want the monolithic test thread broken into multiple smaller independent test groups,
so that a failure in one group doesn't block all subsequent tests and test maintenance is manageable.

## Acceptance Criteria

1. **Given** the current single test_thread in `src/antforth.asm` with 73 sequential tests **When** the test infrastructure is modularised **Then** tests are split into logical groups in separate source files **And** each group has a clearly labeled entry point

2. **Given** a test failure (wrong output character) in one group **When** `make test` runs **Then** subsequent test groups still execute and produce their expected output **And** it is clear from the output which group contains the failure

3. **Given** the modularised test infrastructure **When** `make test` runs **Then** all 73 existing tests still execute and produce the same overall output **And** the build succeeds with zero regressions

4. **Given** all 16 existing REPL tests **When** `make test-repl` runs **Then** all 16 tests still pass unchanged

5. **Given** test data (counted strings, scratch cells) used by test threads **When** the test code is split into separate files **Then** shared test data remains accessible to all test groups **And** no duplicate data definitions exist

## Tasks / Subtasks

- [x] Task 1: Create test group source files (AC: #1, #5)
  - [x] 1.1 Create `src/tests/test_inner.asm` — inner interpreter & control flow tests (current lines ~120-168, tests A-E)
  - [x] 1.2 Create `src/tests/test_stack.asm` — stack & memory primitive tests (current lines ~173-349, tests F-Z + compilation primitives)
  - [x] 1.3 Create `src/tests/test_arithmetic.asm` — arithmetic, logic & comparison tests (current lines ~351-667)
  - [x] 1.4 Create `src/tests/test_io.asm` — I/O primitive tests (current lines ~865-915, TYPE/CR/SPACE/SPACES)
  - [x] 1.5 Create `src/tests/test_dictionary.asm` — FIND, COUNT tests (current lines ~917-1052)
  - [x] 1.6 Create `src/tests/test_outer.asm` — outer interpreter tests: user vars, WORD, NUMBER?, formatting (current lines ~1054-1305)
  - [x] 1.7 Keep shared test data (counted strings, scratch cells) in `src/antforth.asm` data area — accessible to all groups

- [x] Task 2: Implement test group chaining with stack reset (AC: #2, #3)
  - [x] 2.1 Each test group file defines a labeled entry point (e.g., `test_group_inner:`, `test_group_stack:`)
  - [x] 2.2 Create a master test runner in the TEST_MODE block that chains groups with stack resets between them
  - [x] 2.3 Between each group: reset SP from `(sp_base)`, clean BC (LD BC, 0) to prevent cascade failures
  - [x] 2.4 Final group ends with `DW w_LIT_cf, w_BYE_cf, w_EXECUTE_cf` (existing termination pattern)
  - [x] 2.5 INCLUDE all test group files in `src/antforth.asm` (within or near the TEST_MODE block)

- [x] Task 3: Update Makefile EXPECTED string (AC: #3)
  - [x] 3.1 Verify the overall output is identical to the current EXPECTED string
  - [x] 3.2 Add comments to Makefile showing which portion of EXPECTED maps to which test group
  - [x] 3.3 Ensure `make test` passes with the modularised test infrastructure

- [x] Task 4: Verify no regressions (AC: #3, #4)
  - [x] 4.1 Run `make test` — all 73 regression tests pass
  - [x] 4.2 Run `make test-repl` — all 16 REPL tests pass unchanged
  - [x] 4.3 Run `make` (normal build) — REPL binary builds and runs correctly
  - [x] 4.4 Verify test binary size is reasonable (not bloated by restructuring)

## Dev Notes

### What Already Exists

**The current test infrastructure has two modes:**

1. **Regression tests (`make test`):** Assembles with `-DTEST_MODE`, creates `build/antforth_test.com`. Cold start at `antforth.asm:74-82` routes to `test_thread` instead of QUIT. Output is compared against a single EXPECTED string.

2. **REPL tests (`make test-repl`):** 16 independent piped tests using the normal `antforth.com` binary. Already modular — no changes needed.

**The monolithic test_thread (`antforth.asm:119-1305`):**
- 73 individual tests across ~1186 lines
- Sequential DW-based threaded code
- Each test emits a pass character on success, '!' on failure
- Tests are logically grouped by story/module but not separated
- Terminates with `DW w_LIT_cf, w_BYE_cf, w_EXECUTE_cf`

**Test data (`antforth.asm:1319-1345`):**
- `test_cell`, `test_cell2` — scratch cells for memory ops
- `test_find_dup`, `test_find_lc_dup`, `test_find_plus`, `test_find_bad`, `test_find_immed` — counted strings for FIND tests
- `test_num_42`, `test_num_neg7`, `test_num_bad` — counted strings for NUMBER? tests
- `test_str_s`, `test_str_t`, `test_str_multi` — TYPE test strings
- `test_colon_header` + `test_colon_cfa` — manual colon definition for DOCOL test

**Current EXPECTED string (Makefile line 56):**
```
ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstu\r\nv w  xyz{|}~#$$%%&()*42 0 -1 -32768 65535     42<3> 1 2 3 FF A
```

**Current TEST_MODE entry point (`antforth.asm:74-82`):**
```z80
        IFDEF TEST_MODE
            LD      DE, test_thread
            NEXT
        ELSE
            LD      BC, 0
            JP      w_QUIT_cf
        ENDIF
```

### Design: Test Group Chaining with Stack Reset

**The key insight:** A test failure (wrong character emitted) doesn't crash the system — it just produces wrong output. But a wrong stack effect in one test CAN cascade into subsequent tests, causing false failures. The fix is to **reset the stack between groups**.

**Master test runner pattern:**
```z80
        IFDEF TEST_MODE
            ; === Test Group 1: Inner interpreter ===
            LD      SP, (sp_base)       ; Reset parameter stack
            LD      BC, 0               ; Clean TOS
            LD      DE, test_group_inner
            NEXT                        ; Run group — returns via...

            ; Control returns here after group completes
            ; (each group's last word must somehow return control)
```

**Problem:** Threaded code doesn't "return" to assembly. Once you `NEXT` into a thread, control stays in the inner interpreter until BYE or ABORT.

**Solution — use a bridge word:** Create a small CODE word or inline pattern that chains to the next group. At the end of each test group thread (except the last), instead of BYE, use a custom `TEST_NEXT_GROUP` code word that:
1. Resets SP from `(sp_base)`
2. Cleans BC to 0
3. Loads DE with the next group's thread address
4. Executes NEXT

```z80
; Internal CODE word: bridge to next test group
; Stack effect: resets everything, starts next group
; Usage: DW w_LIT_cf, test_group_XXX, w_TEST_BRIDGE_cf
w_TEST_BRIDGE:
        DEFCODE "TEST-BRIDGE", 0
w_TEST_BRIDGE_cf:
        ; BC = address of next test group thread (from LIT)
        LD      H, B
        LD      L, C                    ; HL = next group address
        LD      SP, (sp_base)           ; Reset parameter stack
        LD      BC, 0                   ; Clean TOS (phantom)
        EX      DE, HL                  ; DE = next group address (new IP)
        NEXT                            ; Start next group
```

**Each test group ends with:**
```z80
; End of group (chains to next):
        DW      w_LIT_cf, test_group_next
        DW      w_TEST_BRIDGE_cf

; End of LAST group (terminates):
        DW      w_LIT_cf, w_BYE_cf
        DW      w_EXECUTE_cf
```

**Cold start TEST_MODE entry becomes simply:**
```z80
        IFDEF TEST_MODE
            LD      DE, test_group_inner    ; Start with first group
            NEXT
        ENDIF
```

**Alternative simpler approach:** If the bridge word feels heavy, each group can simply end by jumping to a reset stub that's defined in assembly (not threaded). But the CODE word approach is cleaner since it stays within the threading model per our testing rules.

### Test Group Breakdown

Based on the current test_thread structure:

| Group | File | Entry Label | Tests | Approx Lines | Expected Output Portion |
|-------|------|-------------|-------|-------------|------------------------|
| 1 | test_inner.asm | test_group_inner | Inner interpreter, DOCOL, EXIT, BRANCH, ?BRANCH | 120-168 | `ABCDE` |
| 2 | test_stack.asm | test_group_stack | Stack ops, memory ops, compilation primitives | 173-349 | `FGHIJKLMNOPQRSTUVWXYZ` |
| 3 | test_arithmetic.asm | test_group_arithmetic | +, -, *, /, MOD, /MOD, logic, comparisons | 351-667 | `0123456789abcdefghijklmnopqrstu` |
| 4 | test_io.asm | test_group_io | TYPE, CR, SPACE, SPACES | 865-915 | `\r\nv w  xyz{|}~` |
| 5 | test_dictionary.asm | test_group_dictionary | FIND, COUNT | 917-1052 | `#$$%%&()` |
| 6 | test_outer.asm | test_group_outer | User vars, WORD, NUMBER?, formatting | 1054-1305 | `*42 0 -1 -32768 65535     42<3> 1 2 3 FF A` |

**Note:** The exact line ranges and output portions are approximate. The dev agent must trace through the current test_thread carefully and split at clean boundaries between test groups. Each group should be self-contained — no test in group N should depend on stack state left by group N-1 (the bridge word handles this).

### File Organisation

**New directory:** `src/tests/`

```
src/
  tests/
    test_inner.asm          — Group 1: inner interpreter
    test_stack.asm          — Group 2: stack & memory
    test_arithmetic.asm     — Group 3: arithmetic & logic
    test_io.asm             — Group 4: I/O primitives
    test_dictionary.asm     — Group 5: dictionary lookup
    test_outer.asm          — Group 6: outer interpreter & formatting
  antforth.asm              — INCLUDEs test files in TEST_MODE block
```

**Include pattern in antforth.asm:**
```z80
        IFDEF TEST_MODE
            INCLUDE "tests/test_inner.asm"
            INCLUDE "tests/test_stack.asm"
            INCLUDE "tests/test_arithmetic.asm"
            INCLUDE "tests/test_io.asm"
            INCLUDE "tests/test_dictionary.asm"
            INCLUDE "tests/test_outer.asm"
        ENDIF
```

The INCLUDEs should be placed AFTER all word definitions (so test code can reference any word's `_cf` label) but BEFORE the data area. Or they can go within the existing test_thread location since all word INCLUDEs precede it. Check the current include order — the test_thread at line 119 is AFTER the cold_start but BEFORE the word INCLUDEs at lines 85+. **This means the test thread currently uses forward references to `w_XXX_cf` labels** — sjasmplus resolves these on its second pass. The same will work for separate files.

**Actually, looking more carefully:** The test_thread at line 119 is between the cold_start (line 18-82) and the first INCLUDE (line 85). But sjasmplus multi-pass resolution means DW forward references work fine. The test group files can be INCLUDEd at the same location.

### Register Contract for Test Groups

Each test group must assume:
- BC = 0 (clean TOS, set by bridge word or initial entry)
- DE = group thread address (set by bridge word or cold start)
- SP = sp_base (clean parameter stack)
- IX, IY = unchanged from cold start (return stack, user area)

Each test group must NOT assume any particular stack contents from a previous group.

### What NOT to Change

- **REPL tests (`make test-repl`):** 16 tests, already modular. No changes.
- **Normal build (`make` / `make asm`):** No TEST_MODE, REPL binary. No changes.
- **Word implementations:** No changes to any Forth word source files.
- **Test data in antforth.asm data area:** Keep shared test data where it is — all test files can reference these labels.
- **EXPECTED output:** The combined output must be identical. The test groups just produce their portions sequentially.

### Anti-Patterns to Avoid

1. **Do NOT duplicate test data.** Counted strings, scratch cells, and the test colon header stay in `antforth.asm` data area. Test group files reference them.
2. **Do NOT change the test output.** The combined EXPECTED string must be byte-identical to the current one. This is a refactoring story — behaviour must not change.
3. **Do NOT modify any Forth word implementations.** This story only touches test infrastructure.
4. **Do NOT add new tests.** This story modularises existing tests. New tests belong in future stories.
5. **Do NOT break the REPL tests.** `make test-repl` must pass unchanged.
6. **Do NOT add TEST_BRIDGE to the normal (non-TEST_MODE) build.** It should only exist in the test binary. Use `IFDEF TEST_MODE` to guard it if needed, or place it within the test include block.
7. **Do NOT use raw BDOS calls in test bridge code.** Stay within the threading model per testing rules (memory: feedback_testing_rules.md).
8. **Do NOT forget to handle the test_colon_header/test_colon_cfa** at `antforth.asm:1309-1317`. This is test data used by the inner interpreter test group — it must remain accessible.

### Previous Story Learnings (from Story 2.4 / Epic 2 Retro)

- **All tests must go through the threading model** — no standalone assembly bypassing NEXT/DOCOL (memory: feedback_testing_rules.md)
- **DEFWORD cf label pattern:** `w_XXX_cf EQU w_XXX_body - 3` for any DEFWORD words. TEST_BRIDGE is a CODE word (DEFCODE) so this doesn't apply, but be aware.
- **iz-cpm pipe behavior:** iz-cpm crashes with UnexpectedEof when stdin is a pipe — `2>/dev/null || true` in Makefile test targets (already handled, don't break it)
- **TOS-in-register:** BC=TOS may be phantom after reset. DEPTH=0 means BC invalid. The bridge word sets BC=0 explicitly.

### Git Intelligence

Recent commits show one-commit-per-story pattern:
```
bff479b completed story 2.4
8b6b87e commit stories 2.2 and 2.3 (whoops)
0054157 completed story 2.1
b57363d completed story 1.5 plus retro
0f66341 implemented story 1.4 - arithmetic and logic ops
```

Codebase is stable — all tests pass. This is a pure refactoring story with no functional changes.

### Testing Strategy

**Primary verification:** `make test` output must be byte-identical to the current EXPECTED string. Run before and after to confirm.

**Secondary verification:** `make test-repl` all 16 tests pass unchanged.

**Tertiary verification:** `make` builds the normal REPL binary without errors.

**Approach:**
1. Before making any changes, run `make test` and capture the exact output
2. After modularisation, run `make test` and verify output is identical
3. Run `make test-repl` to verify no REPL regressions
4. Run `make` to verify normal build

### References

- [Source: src/antforth.asm:74-82] — TEST_MODE IFDEF branching
- [Source: src/antforth.asm:119-1305] — Current monolithic test_thread (73 tests)
- [Source: src/antforth.asm:1309-1317] — test_colon_header/test_colon_cfa (DOCOL test data)
- [Source: src/antforth.asm:1319-1345] — Shared test data (counted strings, scratch cells)
- [Source: Makefile:52-64] — `make test` target with EXPECTED string
- [Source: Makefile:66-195] — `make test-repl` target (16 REPL tests)
- [Source: _bmad-output/implementation-artifacts/epic-2-retro-2026-04-06.md] — Epic 2 retro action items
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.0] — Story definition and acceptance criteria

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No issues encountered. Clean implementation with all tests passing on first attempt.

### Completion Notes List

- Split monolithic test_thread (~1186 lines) into 6 independent test group files under `src/tests/`
- Created TEST_BRIDGE CODE word to chain between groups with stack reset (SP from sp_base, BC=0)
- Each group defines a labeled entry point and chains to the next via `DW w_LIT_cf, next_group, w_TEST_BRIDGE_cf`
- Last group (test_outer) terminates with `DW w_LIT_cf, w_BYE_cf, w_EXECUTE_cf` (existing pattern)
- Cold start TEST_MODE entry now points to `test_group_inner` instead of `test_thread`
- All test code and TEST_BRIDGE guarded by `IFDEF TEST_MODE` — excluded from normal build
- Shared test data (counted strings, scratch cells, test_colon_header) remains in antforth.asm data area
- EXPECTED output is byte-identical; no functional changes
- Test binary: 6091 bytes (small overhead from TEST_BRIDGE CODE word + DEFCODE header + IX reset)
- Normal binary: 3847 bytes (41 bytes smaller — TESTIMM and test_colon_header moved inside IFDEF TEST_MODE)

### Review Follow-ups (AI)

- [ ] [AI-Review][LOW] No regression test verifies group isolation (AC #2). TEST_BRIDGE resets SP, IX, and BC between groups, but there is no test that deliberately injects a stack corruption in one group to prove subsequent groups survive. Adding such a test would require a dedicated test mode or a future story — out of scope for this refactoring story.

### Change Log

- 2026-04-06: Modularised test thread into 6 independent test groups with stack-resetting bridge word
- 2026-04-06: Code review fixes — TEST_BRIDGE now resets IX from rp_base; TESTIMM and test_colon_header moved inside IFDEF TEST_MODE; Makefile comment clarified

### File List

- src/tests/test_inner.asm (new) — Group 1: inner interpreter tests (A-E)
- src/tests/test_stack.asm (new) — Group 2: stack & memory tests (F-Z)
- src/tests/test_arithmetic.asm (new) — Group 3: arithmetic, logic & comparison tests (0-r)
- src/tests/test_io.asm (new) — Group 4: I/O primitive tests (s-|)
- src/tests/test_dictionary.asm (new) — Group 5: dictionary lookup tests (}~#$%&)
- src/tests/test_outer.asm (new) — Group 6: outer interpreter tests
- src/antforth.asm (modified) — Replaced monolithic test_thread with TEST_BRIDGE + INCLUDEs
- Makefile (modified) — Added test source glob and EXPECTED string group comments
