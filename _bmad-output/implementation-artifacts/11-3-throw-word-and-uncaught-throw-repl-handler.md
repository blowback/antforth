# Story 11.3: `THROW` word + uncaught-THROW REPL handler

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to raise a non-zero THROW code and have it caught by the nearest enclosing `CATCH` — or, if uncaught, see a clean diagnostic and return to a live REPL with my session and dictionary intact,
so that error handling is composable and the REPL survives any error (FR21, FR22, NFR3, NFR7, NFR8). This story consumes the frame layout that Story 11.2 established and is the foundation that Stories 11.4–11.7 build on (every internal-error migration in 11.4–11.6 raises a `THROW` that this story dispatches; Story 11.7's retarget of `ABORT`/`ABORT"` becomes a one-line `-1 THROW` / `-2 THROW` once this story lands).

## Acceptance Criteria

1. **Given** E11-D2's THROW algorithm (`architecture.md:289-300`) — O(1) `CATCH-TOP` access plus a (currently empty) `INCLUDE-TOP` chain walk per CCD-1 (`architecture.md:168-191`) — **when** `THROW` is invoked with a non-zero code `n` and `CATCH-TOP ≠ 0`, **then** the algorithm: (i) walks the `INCLUDE-TOP` chain to the target frame (no-op pre-Epic-13 since `INCLUDE-TOP` is not yet defined; the loop is omitted from this story's code with a comment forward-pointing at Story 13.4 owning the walk insertion), (ii) restores `SP` from the target frame's `+0` slot, (iii) restores `CATCH-TOP` from the target frame's `+6` slot, (iv) reads `catching-IP` from the target frame's `+4` slot into `DE`, (v) pops the 8-byte exception frame from the IX rstack (i.e., `IX = frame_base + 8`), (vi) installs `BC = n` as the new TOS, and (vii) `NEXT`s into the caller's thread. The IX rstack between the THROW site and the target frame's base — colon return-addr frames, DO-LOOP frames, etc. — is *abandoned wholesale* by the IX restore, per E11-D2's "snap back" semantic (`architecture.md:300`).

2. **Given** the BC-as-TOS contract (`project_tos_in_register.md`) and the saved-SP slot stored at frame `+0` by Story 11.2 (which is `SP` *before* `CATCH`'s `POP BC` consumed the xt cell — see `src/exception.asm:65-67` Story 11.2 implementation), **when** `THROW` restores SP from `+0`, **then** `[SP]` (the cell at the new top of the parameter stack) holds the value of i*x's TOS at CATCH-entry time. The new TOS is `n` (THROW code) installed into BC, and the value at `[SP]` becomes second-on-stack — making the post-THROW data stack `( i*x n )` per the standard's `( k*x n -- k*x | i*x n )` semantic. **Do NOT** `POP BC` after `LD SP, HL` and re-push it; the saved-SP value is exactly the SP that puts i*x's TOS at `[SP]` ready to be the new second-on-stack underneath BC=n.

3. **Given** the standard's `THROW 0` semantic (Forth 2014 §9.6.1.2275 / ANS Forth 1994 §9.6.1.2275 — "If any bits of *n* are non-zero, …"), **when** `THROW` is invoked with `n = 0`, **then** it is a no-op that consumes the zero from the parameter stack: `BC` becomes the cell that was second-on-stack before the call, SP advances by one cell, and execution proceeds to the next word in the caller's thread. **No** CATCH-TOP read, **no** frame access, **no** uncaught-handler invocation. Test: `1 2 0 THROW . .` prints `2 1  ok` (depth was 3, dropped to 2 after THROW; then `.` `.` consumes both leaving an empty stack).

4. **Given** `CATCH-TOP = 0` semantically meaning "no enclosing CATCH" (per Story 11.2's cold-start init at `src/antforth.asm:70-72` and the QUIT chain reset at `src/outer_interpreter.asm:247-250`), **when** `THROW` is invoked with a non-zero code and `CATCH-TOP = 0`, **then** the uncaught-THROW handler runs: (a) prints a diagnostic of the form `error <N>` followed by `: <description>` if a description is registered for that code, then a CR/LF; (b) routes through `JP w_ABORT_cf` for state reset — which calls `asm_cleanup` (clears `asm_mode`, restores HERE/bucket on partial CODE def), resets `SP` to `(sp_base)`, and `JP w_QUIT_cf`; (c) `w_QUIT_cf` resets the return stack (IX = `(rp_base)`), zeroes `STATE`, zeroes `CATCH-TOP`, and re-enters the `.quit_loop` REPL prompt. Per FR22 / NFR7, the REPL survives.

5. **Given** the diagnostic format required by FR21 ("a diagnostic message that includes the THROW code and (where applicable) a human-readable description") and the `docs/throw-codes.md` table from Story 11.1, **when** the uncaught handler prints the description, **then** the lookup uses a small in-kernel description table — `throw_desc_table` in `src/exception.asm` — populated with entries for the standard codes Epic 11 will issue. Minimum populated entries (seeded by this story so Stories 11.4–11.7 can verify diagnostic strings as part of their migration tests): `-1 ABORT`, `-2 ABORT"`, `-4 stack underflow`, `-10 division by zero`, `-13 undefined word`, `-14 interpreting a compile-only word`, `-16 attempt to use zero-length name string`, `-17 pictured numeric output overflow`, `-22 control structure mismatch`, `-58 unexpected end of input`. Codes outside the table (positive user codes, ANS codes not yet referenced, and the antforth assembler-error extensions `-258..-269` whose diagnostic strings are filled in by Story 11.5) print only `error <N>` with no `: <description>` — the `: ` prefix is omitted entirely. Table format and walk are documented inline; the table terminator is a `DW 0` row (THROW 0 is unreachable as an uncaught-path lookup since it's no-op'd at AC #3, so 0 as terminator is unambiguous).

6. **Given** the regression discipline (`feedback_repl_tests_preferred.md`, NFR9, NFR16) and the per-line `\ expect: <fragment>` convention (`tests/double_tests.fth`, `tests/exception_tests.fth` Story 11.2 sections 1-5), **when** Story 11.3's tests are added to `tests/exception_tests.fth`, **then** new sections cover four scenario classes:

    - **Section 6 — `THROW 0` no-op:** `1 2 0 THROW . .` → `2 1  ok`; `0 0 THROW .` → `0  ok` (BC=0 from the THROW becomes new TOS via `POP BC`).
    - **Section 7 — caught THROW round-trip:** `: T1 42 THROW ;` then `' T1 CATCH .` → `42  ok`; std-code variant `: T2 -13 THROW ;` then `' T2 CATCH .` → `-13  ok`; i*x preservation `1 2 3 ' T1 CATCH . . . .` → `42 3 2 1  ok` (n on top, i*x preserved underneath).
    - **Section 8 — nested CATCH semantics:**
        - **Inner catches:** `: T3 -5 THROW ; : N3 ['] T3 CATCH ;` then `' N3 CATCH . .` → `0 -5  ok` (inner catches `-5`, outer sees normal return adding `0` on top).
        - **Outer catches when inner has none:** `: T4 -5 THROW ; : N4 T4 ;` then `' N4 CATCH .` → `-5  ok` (THROW propagates to the only CATCH frame, which is the outer one).
        - **Three-deep, only outermost catches:** `: T5 -5 THROW ; : M5 T5 ; : N5 M5 ;` then `' N5 CATCH .` → `-5  ok`.
        - **Inner catches and rethrows (re-THROW):** `: T6 -5 THROW ; : M6 ['] T6 CATCH DROP -7 THROW ;` then `' M6 CATCH .` → `-7  ok` (inner catches `-5`, drops it, throws `-7`; outer catches `-7`).
        - **Three-deep middle catches:** `: T7 -5 THROW ; : M7 ['] T7 CATCH ; : N7 M7 ;` then `' N7 CATCH . .` → `0 -5  ok` (middle catches the inner THROW; outer sees normal return).
    - **Section 9 — uncaught THROW + diagnostic + REPL recovery:**
        - **User code (no description):** `42 THROW` → output contains `error 42` followed by REPL recovery to `ok`.
        - **Std code (description present):** `-13 THROW` → output contains `error -13: undefined word` followed by recovery to `ok`.
        - **Std code -1 (ABORT semantics):** `-1 THROW` → output contains `error -1: ABORT` + recovery (precursor to Story 11.7's ABORT retarget).
        - **Dictionary intact post-uncaught-THROW:** `: HELLO 99 ;` then `-13 THROW` then `HELLO .` → diagnostic + recovery + `99  ok` (HELLO defined before the THROW must still be findable after recovery — verifies `LATEST` and the hash table survived).
        - **BASE intact post-uncaught-THROW:** `HEX -1 THROW` then `BASE @ DECIMAL .` → `error -1: ABORT` + recovery + `16  ok` (HEX = base 16 in decimal).
        - **`asm_mode` cleaned post-uncaught-THROW:** confirm that an uncaught THROW *while inside* a `CODE` block (i.e., `asm_mode = 1`) routes through `asm_cleanup` so the next REPL command is not in `asm_mode`. Concrete test: `CODE BAD` then `-13 THROW` then `END-CODE` (which would now error on its own check_asm_mode if asm_mode were unclean) — instead, after the diagnostic, the next line `HELLO .` (using HELLO from the dictionary-intact test above) runs cleanly, and later `CODE GOOD END-CODE` succeeds since asm_mode was reset.
        - **CATCH-TOP zero post-uncaught-THROW:** `-13 THROW` then `CATCH-TOP @ .` → diagnostic + recovery + `0  ok` (`w_QUIT_cf`'s catch_top reset from Story 11.2 already handles this; the test confirms the integration).

    Each test follows the existing per-line `\ expect: <fragment>` convention; uncaught-THROW tests use multi-line `printf` blocks in the Makefile (one block per scenario) with `tr '\r\n' '  '` + ordered `grep -qE` patterns to enforce diagnostic-then-recovery sequencing, modelled on Story 11.2's test 672.

7. **Given** the post-Story-11.2 baseline (binary 16918 bytes, 673 REPL tests passing per `_bmad-output/implementation-artifacts/11-2-…md` Completion Notes), **when** Story 11.3 lands, **then** the kernel binary grows by the size of: (a) `THROW` DEFCODE (~80 bytes — caught path, n=0 path, uncaught path), (b) the `print_signed_dec_bc` helper (~30 bytes), (c) the `print_throw_description` helper (~25 bytes), (d) the `throw_desc_table` (~280 bytes — 10 entries seeded × ~28 bytes avg), (e) the `str_throw_prefix` and `str_colon_space` strings (~10 bytes), and (f) one scratch cell `throw_saved_n` (2 bytes BSS). Estimated total ROM delta: **~430 bytes**, putting kernel total around 17,350 bytes (~46 KB free in TPA). Pre-/post-edit `wc -c build/antforth.com` recorded in Completion Notes per Story 11.2's discipline. `make test` and `make test-repl` continue clean against the post-11.2 baseline (673 tests passing).

8. **Given** the BC-may-be-phantom rule on the THROW path (`project_tos_in_register.md`: "BC=TOS may be phantom after ABORT; DEPTH=(sp_base-SP)/2 counts SP cells only, not BC"), **when** the caught-THROW path completes its SP restore and BC reload, **then** the post-THROW `DEPTH` (as computed by `DEPTH`) equals `pre-CATCH-DEPTH + 1` — i.e., the i*x cells at frame-setup time, plus the THROW code `n` on top. Verifiable test: `1 2 3 4 ' T1 CATCH DEPTH .` (where T1 is `: T1 42 THROW ;`) → `5  ok` (4 cells of i*x + the 42 on top = depth 5; `DEPTH` itself doesn't grow the depth at the time of read since `DEPTH` *pushes* the depth, so the printed `5` reflects the state just after CATCH returned and just before `DEPTH` ran).

9. **Given** Story 11.2 left the saved-SP slot at `+0` populated but never read (`docs/register-conventions.md:338`: "the frame's `+0` (saved SP) and `+2` (saved IX) slots are written but never read by Story 11.2 — they exist purely as the contract for Story 11.3's THROW-time restore"), **when** Story 11.3 implements the THROW-time restore, **then** the `+0`-read is the *only* time the saved-SP slot is consumed, and it correctly recovers the SP value that CATCH captured at frame-setup time (Z80 `LD HL, 0 / ADD HL, SP` pattern, see `src/exception.asm:66-67`). The Story 11.2 inline comment at `src/exception.asm:137-141` explaining "the saved-SP slot becomes stale on normal-return, but Story 11.3's THROW reads +0 directly" is consistent with this story's behaviour: THROW reads `+0` *before* the normal-return path could re-clobber SP, since on the THROW path the normal-return code at `catch_resume_cf` is bypassed entirely.

10. **Given** the `(CATCH-RESUME)` continuation thread is reached only via NEXT-from-xt (Story 11.2 AC #5) and the THROW-time restore is reached via direct flow (no NEXT), **when** Story 11.3's THROW completes its 7-step algorithm (AC #1) and runs `NEXT`, **then** the `NEXT` lands on the cell *after* `CATCH` in the original caller's thread — i.e., the same continuation point that `(CATCH-RESUME)` would have reached on normal return, but with `BC = n` instead of `BC = 0`. This is by construction: the catching-IP at frame `+4` was set by Story 11.2's `CATCH` to the caller's DE-at-CATCH-entry, which points at `caller_thread + 1_cell` (the cell right after `CATCH`'s code-field address in the caller's compiled thread). Both the normal-return path and the THROW path restore DE to this same value before `NEXT`.

11. **Given** the standards-citation discipline (CCD-3, NFR17/NFR18) and the existing `src/exception.asm` file header (Story 11.2), **when** `THROW` is implemented in `src/exception.asm`, **then** its source carries:
    - A standard-citation comment line in the project-convention form: `; ANS Forth 1994 §9.6.1.2275   THROW          — raise an exception` (single line; project-wide convention is `ANS Forth 1994` for §9.x codes per Story 11.1 reconciliation; see `docs/throw-codes.md` §a, lines 31-40).
    - A stack-effect comment on the DEFCODE line per `architecture.md:481-488`: `( k*x n -- k*x | i*x n )` — the standard form, *not* an abbreviated `( n -- )` (which would lose the i*x/k*x semantic; same lesson as Story 11.2's adversarial F3 finding).
    - Forward-pointer comments at the `INCLUDE-TOP` chain-walk placeholder (currently a no-op) explaining that Story 13.4 will insert the chain walk between the CATCH-TOP read and the SP/IX restore.
    - Inline comments documenting the BC-may-be-phantom invariant on the post-restore state (AC #8), referencing `project_tos_in_register.md`.

12. **Given** `src/exception.asm` is the architecture-prescribed home for `THROW` (`architecture.md:443, 686`) and Story 11.2 left the file populated with `CATCH-TOP`, `CATCH`, and `catch_resume_cf`, **when** Story 11.3 lands, **then** the file gains `THROW` immediately *after* the existing words (preserving the order CATCH-TOP → CATCH → catch_resume_cf → THROW → throw helpers → throw_desc_table). The `print_signed_dec_bc` and `print_throw_description` helpers and the `throw_desc_table` are placed at the end of the file, after `THROW`, since they are private to the exception subsystem and not referenced from elsewhere. The `str_throw_prefix` / `str_colon_space` strings live alongside the table at the end of the file, not in `antforth.asm`'s string pool — keeping exception-subsystem strings co-located with their consumers.

13. **Given** the dependency that `print_signed_dec_bc` reuses `digit_to_char` and `div_bc_by_e` from `src/formatting.asm` (`formatting.asm:11-18`, `formatting.asm:27-41`), **when** the helper is implemented, **then** it does **not** consume `(IY+UserArea.base)` — instead it hardcodes `LD E, 10` so the diagnostic always prints in decimal *regardless of the user's BASE setting at THROW time*. This is essential for FR21 (the diagnostic must be readable) and for the BASE-preservation test in AC #6 Section 9 (`HEX -1 THROW` must still print `error -1: ABORT` in decimal, then BASE = HEX is preserved across recovery). The dedicated helper avoids the alternative of save-restore-BASE-around-print, which is both more code and more error-prone (a re-entrant THROW would corrupt the saved BASE).

14. **Given** that `print_signed_dec_bc` reuses the existing `num_buf` buffer at `src/formatting.asm` (defined inside `u_to_str` as scratch), **when** the helper writes its digit string, **then** it uses the same `num_buf + NUM_BUF_SIZE - 1` end-pointer pattern that `u_to_str` uses (`formatting.asm:55-79`); `num_buf` is in BSS (`antforth.asm` data section) and is shared by all signed/unsigned print paths — **not** reentrant across nested calls, but also not held across NEXT, so the THROW path's single use is safe. **Dev note:** if a future story needs to print numbers from a context where `u_to_str` might already be mid-flight (e.g., a print-during-print), this assumption breaks; document it and use a private scratch buffer if so. For Story 11.3, the THROW path is the terminal action before `JP w_ABORT_cf`, so reentrancy is impossible.

15. **Given** the plain-QA-language discipline (`feedback_plain_qa_language.md`) and Story 11.2's verdict-table format for Completion Notes (per-AC rows: `Gate text | Evidence | Verdict`), **when** Story 11.3 lands, **then** Completion Notes mirror that format: one row per AC, evidence cited by file:line, no florid audit phrasing.

16. **Given** the adversarial-review discipline (`feedback_adversarial_review.md` — "reviews MUST find things; absence of findings is suspect"), **when** Story 11.3's review runs, **then** at least 2-3 HIGH/MEDIUM findings are expected (likely candidates: register clobbers in the multi-step caught-path restore; the saved-SP-vs-pre-`POP-BC` semantics being subtle; `ADD IX, BC=8` reuse of Story 11.2's pattern needing comment for second-time use; the `INCLUDE-TOP` placeholder's documentation; description-table ordering / lookup performance for hot paths; the `print_signed_dec_bc` clobber documentation; missing edge cases in the test scenarios — particularly `THROW` from inside a DOES> body, or `THROW` mid-EXECUTE, or `THROW` from a deeply-nested compound xt). Triage all findings; fix HIGH and MEDIUM in-pass; defer LOW with rationale.

17. **Given** that Story 11.4 owns the migration of `do_underflow_error` (`system.asm:559`) to `THROW -4`, **when** Story 11.3 implements `THROW`'s underflow guard, **then** `THROW`'s own `check_underflow` at entry **does not** pre-migrate to `THROW -4` (which would be circular — `THROW`'s underflow handler can't itself call `THROW`). Instead, `THROW` calls the existing `check_underflow` helper, which routes empty-stack-`THROW` into `do_underflow_error` → `JP w_ABORT_cf` (the legacy ABORT path) — *exactly the same behaviour as `CATCH`'s underflow guard* per Story 11.2 AC #3. Story 11.4's migration touches `do_underflow_error` directly, not `THROW`'s entry guard, so `THROW`'s check_underflow call site remains stable. **Reasoning:** even when 11.4 migrates `do_underflow_error` to `-4 THROW`, that migration is a *different* THROW invocation from the user-code `THROW` we're implementing here — the underflow path's THROW will recurse cleanly into the *same* `THROW` word's caught/uncaught dispatch, since by then `THROW` is bulletproof.

18. **Given** that the existing `'` (tick) word at `src/compiler.asm:48` raises `JP w_ABORT_cf` for an undefined word (per Story 11.1 inventory) and this story's tests use `'` to obtain xts of user-defined words, **when** the test `: T1 42 THROW ; ' T1 CATCH .` runs, **then** the tick succeeds (T1 is defined right before) — the migration of tick's `JP w_ABORT_cf` to `-13 THROW` is Story 11.5's responsibility and doesn't affect Story 11.3's tests so long as every `'` in the test file references a previously-defined word. Cross-check at test-write time: every `'` in `tests/exception_tests.fth` Sections 6-9 follows a `:` definition of the same name on a prior line.

19. **Given** the docs/register-conventions.md Story 11.2 forward-pointer (`register-conventions.md:340-346`) and the section's "extended by Stories 11.3-11.7" promise, **when** Story 11.3 lands, **then** §9 of `docs/register-conventions.md` gains a new sub-section **"Story 11.3 contract — THROW-time restore"** documenting:
    - The 7-step caught-path algorithm from AC #1 (with the same enumeration: read CATCH-TOP, INCLUDE-TOP no-op, restore SP from +0, restore CATCH-TOP from +6, read catching-IP from +4 into DE, pop frame via IX += 8, install BC = n, NEXT).
    - The uncaught-path semantic (AC #4) and the `JP w_ABORT_cf` chain it shares with the legacy ABORT recovery.
    - The `BC = n` post-restore note from AC #8 referencing the BC-may-be-phantom rule.
    - The forward pointer to Stories 11.4–11.7 (which extend the *use* of THROW but do not modify its mechanism) and to Story 13.4 (which inserts the INCLUDE-TOP chain walk into THROW's caught path).

    The "Forward pointer (Stories 11.3-11.7)" sub-section is updated: the Story 11.3 entry — currently a one-line "adds THROW, the uncaught-throw REPL handler, and the THROW-time restore" — moves *into* the body of the Story 11.3 sub-section as the section header / lead, and the Forward pointer's Story 11.3 line is replaced by a back-reference like *"see Story 11.3 contract — THROW-time restore (above)"*.

20. **Given** that THROW from inside a `CODE` block is a real edge case (the `assembler.asm:281` `asm_die` site is one of the Story 11.5 migrations to `THROW <antforth-extension>`), **when** Story 11.3 *foundationally* tests the asm_mode-cleanup integration, **then** AC #6 Section 9's "asm_mode cleaned" test exercises the path *without* requiring Story 11.5's migration to be in place — the test enters CODE mode (sets `asm_mode = 1`), then the user issues `-13 THROW` (which is uncaught at the REPL), the uncaught handler prints the diagnostic, `JP w_ABORT_cf` runs `asm_cleanup` which clears `asm_mode`, and the next REPL command runs cleanly. **No Story 11.5 work is required for this test.** This forward-validates that 11.5's migrations of the `asm_die` family will integrate correctly with Story 11.3's uncaught path.

## Tasks / Subtasks

- [x] **Task 1 — Verify §-numbers, frame-layout consistency, and Story 11.2 invariants (AC: #1, #9, #10, #11)**
  - [x] 1.1 Cross-reference Forth 2014 §9.6.1.2275 and ANS Forth 1994 §9.6.1.2275 for `THROW` against forth-standard.org or local DPANS94 / Forth-2014 PDF at implementation time (per `feedback_systematic_reference_check.md` — verify at write time, not from memory). Confirm both numbers are §9.6.1.2275 (the EXCEPTION wordset's `THROW` retains the same number across both standards).
  - [x] 1.2 Re-read CCD-1 (`architecture.md:168-191`), E11-D1 (`architecture.md:270-287`), E11-D2 (`architecture.md:289-300`); confirm the 7-step algorithm in AC #1 is verbatim from E11-D2.
  - [x] 1.3 Re-read Story 11.2's `src/exception.asm` (in particular the frame-build sequence at lines 65-103 and the `(CATCH-RESUME)` continuation at lines 127-151) to confirm the saved-SP semantic at `+0` is "SP at CATCH entry, before POP BC". This is critical for AC #2's contract.
  - [x] 1.4 Re-read `src/system.asm` for `w_ABORT_cf` (lines 258-264) and `src/outer_interpreter.asm` for `w_QUIT_cf` (lines 236-275) to confirm the ABORT → QUIT chain still resets `STATE`, `CATCH-TOP`, IX, and SP — this is what the uncaught-THROW handler relies on (AC #4).
  - [x] 1.5 Re-read `src/assembler.asm` for `asm_cleanup` (lines 405-441) to confirm it's idempotent and safe to call when `asm_mode = 0` (RET Z at line 412 — yes it is). The uncaught-THROW handler's `JP w_ABORT_cf` chain triggers asm_cleanup automatically.
  - [x] 1.6 Re-read `src/formatting.asm` for `digit_to_char` (lines 11-18), `div_bc_by_e` (lines 27-41), and confirm they preserve IX and IY (yes — div_bc_by_e clobbers AF/D only; digit_to_char clobbers F only).

- [x] **Task 2 — Implement `THROW` caught path in `src/exception.asm` (AC: #1, #2, #3, #8, #9, #10, #11, #17)**
  - [x] 2.1 Add a single scratch cell `throw_saved_n: DW 0` at the end of `src/exception.asm` (BSS-style, like Story 11.2's `aq_saved_ip` at `src/system.asm:250`). Used to park `n` across the `bdos_print_str`-driven uncaught path (where BC gets clobbered by `LD B, len`) and across the caught-path's `LD BC, 8` for the `ADD IX, BC` frame-pop. Document: "stash cell — never held across NEXT; never re-entered (THROW is the terminal call before NEXT or JP w_ABORT_cf); safe by single-threaded invariant."
  - [x] 2.2 Implement `THROW` DEFCODE at the appropriate position (after `catch_resume_cf`, before any helpers) per AC #12. Source skeleton:

    ```
    ; -----------------------------------------------
    ; THROW ( k*x n -- k*x | i*x n )
    ;   Raise an exception. n=0 is a no-op (consumes the 0 from stack).
    ;   Non-zero n: if CATCH-TOP != 0, restore SP/IX/CATCH-TOP/IP from
    ;     the target exception frame, install BC = n, NEXT into caller's
    ;     thread (resumes one cell after the CATCH that wraps this THROW).
    ;   Non-zero n with CATCH-TOP = 0: uncaught — print diagnostic and
    ;     route through w_ABORT_cf for state reset + REPL recovery.
    ;
    ;   See architecture.md:289-300 (E11-D2 algorithm).
    ;
    ; ANS Forth 1994 §9.6.1.2275   THROW          — raise an exception
    ; -----------------------------------------------
    w_THROW:
            DEFCODE "THROW", 0              ; ( k*x n -- k*x | i*x n )
    w_THROW_cf:
            CALL    check_underflow         ; AC #17: existing 1-cell guard;
                                            ; Story 11.4 migrates do_underflow_error,
                                            ; not THROW's entry call.
            ; --- n=0 no-op (AC #3) ---
            LD      A, B
            OR      C
            JR      Z, .throw_zero
            ; --- Read CATCH-TOP into HL ---
            LD      L, (IY+UserArea.catch_top)
            LD      H, (IY+UserArea.catch_top+1)
            LD      A, H
            OR      L
            JP      Z, .throw_uncaught       ; CATCH-TOP=0: uncaught
            ; --- Caught: HL = target frame address; switch IX → frame for
            ;     IX-relative reads. n is in BC; stash before BC reuse. ---
            LD      (throw_saved_n), BC
            PUSH    HL
            POP     IX                       ; IX = target frame base
            ; (Pre-Epic-13: INCLUDE-TOP chain walk is a no-op — Story 13.4
            ; will insert the loop here, between the CATCH-TOP read above and
            ; the SP/CATCH-TOP/IP restores below.)
            ; --- Restore CATCH-TOP from frame +6 ---
            LD      A, (IX+6)
            LD      (IY+UserArea.catch_top), A
            LD      A, (IX+7)
            LD      (IY+UserArea.catch_top+1), A
            ; --- Read catching-IP from +4 into DE ---
            LD      E, (IX+4)
            LD      D, (IX+5)
            ; --- Read saved-SP from +0 into HL (don't apply yet — IX still
            ;     needs to be the frame base for the +0 read) ---
            LD      L, (IX+0)
            LD      H, (IX+1)
            ; --- Pop the 8-byte frame: IX = frame base + 8 ---
            ;     (saved IX at +2 = frame base — same as IX itself; just adjust)
            ;     ADD IX, BC = DD 09 (second kernel use; first was Story 11.2's
            ;     catch_resume_cf at src/exception.asm:147-148)
            LD      BC, 8
            ADD     IX, BC
            ; --- Restore SP from HL (saved at frame +0 by CATCH; the SP value
            ;     before CATCH's POP BC consumed xt — so [SP] = i*x's TOS-cell,
            ;     which is exactly what we want as new second-on-stack) ---
            LD      SP, HL
            ; --- Install BC = n (THROW code, new TOS) ---
            LD      BC, (throw_saved_n)
            ; --- NEXT into caller's thread (DE = catching-IP, one cell after
            ;     the CATCH that wraps this THROW) ---
            NEXT

    .throw_zero:
            ; n = 0: pop n, restore prior TOS. BC was 0; POP BC overwrites
            ; with the cell below. Stack depth drops by 1.
            POP     BC
            NEXT
    ```

  - [x] 2.3 Verify the operation order at restore: CATCH-TOP must be restored *before* the `LD BC, 8 / ADD IX, BC` step (because we need IX = frame base to read +6; once we increment IX, the +6 displacement reaches a different address). The draft above gets this right — CATCH-TOP read happens first while IX = frame base.
  - [x] 2.4 Verify the operation order at restore: catching-IP read into DE must happen *before* the `LD SP, HL` step (because once SP is restored, SP-relative reads might be needed in some later refactor — but more importantly, no instruction should depend on the old SP after the LD SP, HL). The draft above gets this right — DE is fully resolved before SP is touched.
  - [x] 2.5 Verify that `LD BC, 8 / ADD IX, BC` followed by `LD SP, HL` followed by `LD BC, (throw_saved_n) / NEXT` is *the* correct order. Counter-cases to check:
    - If we did `LD SP, HL` before `LD BC, 8`, would BC corruption matter? No — `LD SP, HL` doesn't touch BC. But the order in the draft is fine.
    - If we did `LD BC, (throw_saved_n)` before `LD SP, HL`, would SP corruption matter? No — `LD BC, ...` doesn't touch SP. But the order in the draft is fine.
    - The only critical ordering is: read all frame fields *before* IX advances, then advance IX, then SP, then BC, then NEXT. Document this in inline comments.
  - [x] 2.6 Inline comment the BC-may-be-phantom note (AC #8): "Post-NEXT, BC = n is a *real* TOS (not phantom): the SP-restore put i*x's TOS-cell at [SP] as second-on-stack, so DEPTH = (sp_base - SP)/2 includes that cell, and BC = n is the cell above. Total post-THROW DEPTH = pre-CATCH-DEPTH + 1."

- [x] **Task 3 — Implement uncaught-THROW path in `src/exception.asm` (AC: #4, #5, #11, #13, #14)**
  - [x] 3.1 Implement the `.throw_uncaught` label after `.throw_zero`:

    ```
    .throw_uncaught:
            ; n in BC; stash for use across the bdos_print_str calls (which
            ; clobber BC via LD B, <len> arg)
            LD      (throw_saved_n), BC
            ; --- Print "error " ---
            LD      HL, str_throw_prefix
            LD      B, STR_THROW_PREFIX_LEN
            CALL    bdos_print_str
            ; --- Print n (signed decimal) ---
            LD      BC, (throw_saved_n)
            CALL    print_signed_dec_bc
            ; --- Lookup description; print ": <desc>" if found, else nothing ---
            LD      BC, (throw_saved_n)
            CALL    print_throw_description
            ; --- CR/LF ---
            CALL    bdos_crlf
            ; --- Reset state via the legacy ABORT chain:
            ;     w_ABORT_cf calls asm_cleanup (clears asm_mode, restores
            ;     HERE/bucket if mid-CODE), then LD SP, (sp_base), then
            ;     JP w_QUIT_cf (which resets IX, STATE, CATCH-TOP, then enters
            ;     .quit_loop for fresh REPL input). Per FR22 / NFR7 / NFR8.
            JP      w_ABORT_cf
    ```

  - [x] 3.2 Implement `print_signed_dec_bc` helper (AC #13, #14) at the end of `src/exception.asm`:

    ```
    ; -----------------------------------------------
    ; print_signed_dec_bc — Print BC as signed decimal via BDOS.
    ;   Hardcodes base 10 (does NOT read UserArea.base) — diagnostic must
    ;   be readable regardless of user's BASE setting (FR21 / AC #13).
    ;   Reuses div_bc_by_e and digit_to_char from src/formatting.asm.
    ;   Output via bdos_print_str using the shared num_buf (formatting.asm).
    ;
    ;   Input:  BC = signed 16-bit integer
    ;   Output: ASCII representation emitted to console
    ;   Clobbers: AF, BC, DE, HL
    ;   Preserves: IX, IY, SP
    ; -----------------------------------------------
    print_signed_dec_bc:
            BIT     7, B                    ; BC negative? (high bit of high byte)
            JR      Z, .psd_pos
            ; Negative: emit '-' and negate BC = 0 - BC
            PUSH    BC
            LD      E, '-'
            CALL    bdos_putchar
            POP     BC
            XOR     A
            SUB     C
            LD      C, A
            SBC     A, A
            SUB     B
            LD      B, A                    ; BC = |BC|
    .psd_pos:
            LD      HL, num_buf + NUM_BUF_SIZE - 1
            XOR     A
            LD      (.psd_count), A
            LD      E, 10                   ; force decimal — DO NOT read BASE
    .psd_loop:
            CALL    div_bc_by_e             ; BC = quotient, A = remainder
            CALL    digit_to_char           ; A = ASCII digit
            LD      (HL), A
            ; count++
            PUSH    AF
            LD      A, (.psd_count)
            INC     A
            LD      (.psd_count), A
            POP     AF
            ; Done if quotient is 0
            LD      A, B
            OR      C
            JR      Z, .psd_done
            DEC     HL
            JR      .psd_loop
    .psd_done:
            LD      A, (.psd_count)
            LD      B, A
            JP      bdos_print_str          ; tail-call

    .psd_count: DB 0
    ```

    **Implementation notes:**
    - The `XOR A / SUB C / LD C, A / SBC A, A / SUB B / LD B, A` sequence is the canonical Z80 16-bit-negate idiom; matches the pattern at `src/formatting.asm:101-106` (`print_neg_prefix`). Verify at code-write time that the local copy here matches that template byte-for-byte.
    - **Edge case:** `BC = $8000` (= -32768) is the most-negative 16-bit signed value; `0 - $8000 = $8000` (overflow), so `|BC| = $8000` after negate, and the loop prints "32768" (all 5 decimal digits). Confirmed correct: `div_bc_by_e` is *unsigned*-aware, so it sees `$8000 / 10 = $0CCC r 8`, etc., correctly producing "32768". The diagnostic is `error -32768` followed by description lookup (no entry → no `: <desc>`). Test: `-32768 THROW` (which requires `S\>D D-` or `MIN-N -1 -` to construct, but is reachable in test scripts via `MIN-N THROW` or `-32768 THROW` if the literal parses).
    - The `.psd_count` scratch byte is internal to the helper; like `u_to_str`'s `.uts_count`, it's not held across NEXT (the helper completes synchronously between NEXT-points on the THROW path).

  - [x] 3.3 Implement `print_throw_description` helper (AC #5):

    ```
    ; -----------------------------------------------
    ; print_throw_description — Look up BC (THROW code) in throw_desc_table.
    ;   On match: prints ": <description>" via BDOS.
    ;   On miss (or table terminator): prints nothing.
    ;
    ;   Table format per entry: code (DW 2 bytes), len (DB 1 byte), text (n bytes).
    ;   Terminator: code = 0 (THROW 0 is no-op'd before any uncaught lookup, so 0
    ;   is unambiguous as terminator).
    ;
    ;   Input:  BC = THROW code (signed 16-bit)
    ;   Output: ": <desc>" emitted on match; nothing on miss.
    ;   Clobbers: AF, BC, DE, HL
    ;   Preserves: IX, IY, SP
    ; -----------------------------------------------
    print_throw_description:
            LD      HL, throw_desc_table
    .ptd_loop:
            LD      E, (HL)
            INC     HL
            LD      D, (HL)                  ; DE = table entry's code
            INC     HL
            ; Terminator?
            LD      A, D
            OR      E
            RET     Z                        ; end of table — no match, return silently
            ; Compare DE with BC
            LD      A, E
            CP      C
            JR      NZ, .ptd_skip
            LD      A, D
            CP      B
            JR      NZ, .ptd_skip
            ; Match — HL points at length byte
            ; Print ": " prefix
            PUSH    HL
            LD      HL, str_colon_space
            LD      B, 2
            CALL    bdos_print_str
            POP     HL
            ; Print description: length at (HL), text follows
            LD      A, (HL)
            LD      B, A
            INC     HL
            JP      bdos_print_str          ; tail-call
    .ptd_skip:
            ; Advance HL past length-byte and string
            LD      A, (HL)
            INC     HL                       ; HL → first text byte
            ADD     A, L
            LD      L, A
            JR      NC, .ptd_loop
            INC     H
            JR      .ptd_loop
    ```

    **Implementation notes:**
    - The 8-bit `ADD A, L / INC H` carry handling assumes string length ≤ 255, which is enforced by all entries (max description length seeded is 32 bytes). Verify at table-population time (Task 3.4) that no entry exceeds 255 bytes — none do.
    - Linear search is fine for ~10-15 entries; the THROW path is cold (only fires on errors) and a hash table would cost more bytes than it saves cycles.

  - [x] 3.4 Define the description table and string constants at the end of `src/exception.asm`. Seed with the 10 standard codes Epic 11 will issue (per AC #5):

    ```
    str_throw_prefix:    DB "error "
    STR_THROW_PREFIX_LEN EQU 6
    str_colon_space:     DB ": "

    ; Description table — seeded with the standard codes Epic 11 will issue
    ; (per docs/throw-codes.md inventory). antforth-extension codes -258..-269
    ; (assembler errors) are added here by Story 11.5 when those migrations
    ; land. -69 / -257 are reserved for Epic 13 (file-access; see
    ; docs/throw-codes.md §c) and added at that epic's first migration story.
    ;
    ; Format: DW <code>, DB <len>, DB "<description>"
    ; Terminator: DW 0 (THROW 0 is no-op, never reaches lookup)
    throw_desc_table:
            DW -1
            DB 5, "ABORT"
            DW -2
            DB 6, "ABORT\""
            DW -4
            DB 15, "stack underflow"
            DW -10
            DB 16, "division by zero"
            DW -13
            DB 14, "undefined word"
            DW -14
            DB 32, "interpreting a compile-only word"
            DW -16
            DB 36, "attempt to use zero-length name string"
            DW -17
            DB 32, "pictured numeric output overflow"
            DW -22
            DB 25, "control structure mismatch"
            DW -58
            DB 22, "unexpected end of input"
            DW 0                            ; terminator
    ```

    **Critical at write time:** verify each `DB <len>` matches the actual byte count of the following string. Use a one-shot script or a count-by-hand step (the strings are short). Mismatch causes the table walk to mis-align — the next entry's code-DW would be read from a misaligned offset.

  - [x] 3.5 Cross-reference each seeded description against `docs/throw-codes.md` Section (b) row for that code; the description text should be the standard's *short* name (column "Name (verbatim)") with minor lowercasing for sentence-style. Verify at write time: e.g., `-1 ABORT` matches; `-13 undefined word` matches; etc.

- [x] **Task 4 — Build and unit-test `THROW` against Story 11.2's CATCH (AC: #1, #2, #3, #6, #7, #8)**
  - [x] 4.1 Run `make` after `src/exception.asm` is updated. Confirm clean assemble; record byte count.
  - [x] 4.2 Quick interactive sanity probe: `printf '0 THROW .\r\nBYE\r\n' | iz-cpm build/antforth.com` should emit `0 THROW . 0  ok` (or similar — the `THROW 0` no-op leaves nothing extra; `.` prints the 0 that was on stack… wait no. Let me re-trace: at REPL, `0 THROW` pushes 0, then THROW consumes it (no-op). Stack is empty. Then `.` would underflow. Reword: `1 0 THROW .` → BC=0, then THROW pops the 0 (BC=1 from below), stack now has just BC=1. `.` prints `1  ok`. So the sanity probe should be `printf '1 0 THROW .\r\nBYE\r\n' | iz-cpm build/antforth.com` → expect `1 0 THROW . 1  ok` substring.
  - [x] 4.3 Caught-path probe: `printf "%s\r\n%s\r\n%s\r\n" ': T1 42 THROW ;' "' T1 CATCH ." 'BYE' | iz-cpm build/antforth.com 2>/dev/null | grep -q '42  ok'` — expect a clean grep hit.
  - [x] 4.4 Uncaught-path probe: `printf '42 THROW\r\nBYE\r\n' | iz-cpm build/antforth.com 2>/dev/null | grep -E 'error 42'` — expect a hit (no `:` since 42 has no description).
  - [x] 4.5 Recovery probe: `printf "%s\r\n%s\r\n%s\r\n" ': HELLO 99 ;' '-13 THROW' 'HELLO .' 'BYE' | iz-cpm build/antforth.com 2>/dev/null | tr '\r\n' '  ' | grep -qE 'error -13: undefined word.*99  ok'` — expect a hit.

- [x] **Task 5 — Author REPL test scenarios in `tests/exception_tests.fth` (AC: #6, #18)**
  - [x] 5.1 Append four new sections to `tests/exception_tests.fth` (Sections 6-9 per AC #6). Section 6: `THROW 0` no-op cases. Section 7: caught THROW round-trip cases. Section 8: nested CATCH semantics (5 sub-cases per AC #6). Section 9: uncaught THROW + diagnostic + recovery (7 sub-cases per AC #6).
  - [x] 5.2 Each test line uses `\ expect: <fragment>` per the existing convention. For uncaught-THROW tests (which span multiple REPL lines), use *block* tests where the `.fth` file groups several lines under one expect-block comment header — and the corresponding Makefile entry uses `tr '\r\n' '  '` + ordered-pattern `grep -qE` per Story 11.2's test 672 model.
  - [x] 5.3 Cross-check at test-write time (per AC #18): every `'` in the new sections must follow a `:` definition of the same name on a prior line. Story 11.5 will migrate `'` to `THROW -13` for undefined names; until then, `'` of an undefined name aborts via the legacy path, which would derail the test if it's hit unintentionally.

- [x] **Task 6 — Append matching `printf | $(IZCPM)` blocks to `Makefile` (AC: #6, #7)**
  - [x] 6.1 Highest existing PASS test number (per Story 11.2 final): 673. New tests start at 674. Verify by `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending.
  - [x] 6.2 Each test block follows the existing Story-11.2 form: `@OUTPUT=$$(printf "..." | $(IZCPM) $(TARGET) 2>/dev/null || true) && \\` then the `if echo "$$OUTPUT" | grep -q '<fragment>'` then `echo PASS:` else `echo FAIL: ... ; exit 1`.
  - [x] 6.3 For the uncaught-THROW tests where ordering matters (diagnostic then recovery), use the `tr '\r\n' '  ' | grep -qE 'error <N>(: <desc>)?.* ok'` pattern from Story 11.2's test 672 (Makefile lines 5830-5837).
  - [x] 6.4 Estimated new test count: 18-22 (one per Section 6/7/8/9 sub-case, plus a few state-integrity composites). Final count is dev's choice as long as every AC #6 sub-case is covered.
  - [x] 6.5 Run `make test-repl` after Makefile update: confirm zero regressions and all new tests pass. Total tests should rise from 673 to ~691-695.

- [x] **Task 7 — Update `docs/register-conventions.md` §9 (AC: #19)**
  - [x] 7.1 Read existing §9 (lines 291-346) — confirms current Story 11.2 contract sub-section and Forward pointer.
  - [x] 7.2 Insert new sub-section **"### Story 11.3 contract — THROW-time restore"** between the existing "Story 11.2 contract" sub-section and the "Forward pointer" sub-section. Content per AC #19: 7-step caught-path algorithm, uncaught-path semantic + ABORT-chain reuse, BC-may-be-phantom note, forward pointer to Stories 11.4-11.7 (uses) and Story 13.4 (INCLUDE-TOP chain walk).
  - [x] 7.3 Update the "Forward pointer (Stories 11.3-11.7)" sub-section: replace the current Story 11.3 line (one-liner "adds THROW...") with a back-reference like *"see Story 11.3 contract — THROW-time restore (above)"*. Keep the Story 11.4-11.7 forward pointers intact.
  - [x] 7.4 Estimated section length growth: ~40 lines.

- [x] **Task 8 — Build, regression, and binary-size delta (AC: #7)**
  - [x] 8.1 `make` — clean assemble, zero errors, zero warnings.
  - [x] 8.2 `wc -c build/antforth.com` post-edit. Pre-11.3 baseline (post-11.2 final): 16918 bytes. Estimated post-11.3: ~17350 bytes (delta ~430 bytes per AC #7). Record actual; investigate if delta exceeds estimate by >20% (likely cause: under-counted description-table bytes or inline-comment growth).
  - [x] 8.3 `make test` — assembly thread regression passes clean. Zero new assembly tests.
  - [x] 8.4 `make test-repl` — confirm 673 prior tests + ~18-22 new tests = ~691-695 PASS, zero FAIL.
  - [x] 8.5 Spot-grep `grep -nE 'JP\s+w_ABORT_cf' src/exception.asm` — exactly **one** new occurrence (the uncaught-THROW handler's terminal `JP w_ABORT_cf`); pre-existing call sites in other files are unchanged in count and form (verified per Story 11.1's inventory: 17 sites).

- [x] **Task 9 — Code review (AC: #16, all)**
  - [x] 9.1 Run adversarial code review via fresh subagent (general-purpose Agent or `bmad-bmm-code-review` skill). Per `feedback_adversarial_review.md`: a clean review is suspect — expect ≥2-3 HIGH/MEDIUM findings (likely candidates listed in AC #16).
  - [x] 9.2 Triage all findings; fix HIGH and MEDIUM in-pass; defer LOW with rationale (mirroring Story 11.2's review-log discipline).
  - [x] 9.3 Post-review-fix `make` / `make test` / `make test-repl`: confirm no regressions; binary delta within ±5% of pre-review post-fix figure.
  - [x] 9.4 Record review log in Completion Notes (per Story 11.2 format: ID / Severity / Category / Description / Resolution columns).

- [x] **Task 10 — Update sprint status and finalize**
  - [x] 10.1 Update `_bmad-output/implementation-artifacts/sprint-status.yaml`: `11-3-throw-word-and-uncaught-throw-repl-handler` from `backlog` → `ready-for-dev` (initial story creation; dev pass will move to `review` per the workflow).
  - [x] 10.2 Set Status field at the top of this story file to `ready-for-dev`.

## Dev Notes

### Mission and shape of this story

This story completes the user-facing CATCH/THROW pair started in Story 11.2: `THROW` itself, the uncaught-THROW REPL handler, and the diagnostic-with-description format (FR21). Together, Stories 11.2 and 11.3 deliver Mo's "catch a bug without losing the session" moment — by the end of this story, a user can write defensive code that catches errors and a careless user can ride out errors at the REPL without losing their dictionary or BASE setting.

What this story lands:
- The `THROW` DEFCODE in `src/exception.asm` (caught path + n=0 no-op + uncaught path + terminal ABORT-chain reuse).
- The `print_signed_dec_bc` helper (BASE-independent decimal printing, reusing `digit_to_char`/`div_bc_by_e` from `src/formatting.asm`).
- The `print_throw_description` helper and the `throw_desc_table` (seeded with 10 standard codes; antforth extensions are filled in by Story 11.5 when those migrations land).
- The `tests/exception_tests.fth` Sections 6-9 covering THROW scenarios.
- The Makefile additions (~18-22 new tests).
- `docs/register-conventions.md` §9's new "Story 11.3 contract — THROW-time restore" sub-section.

What this story explicitly does **not** land:
- Any ABORT-site migration to THROW (Stories 11.4–11.6 own those).
- Retarget of `ABORT` / `ABORT"` themselves (Story 11.7 owns).
- INCLUDE-TOP chain walk (Story 13.4 owns; the placeholder is documented in code).
- Description-table entries for antforth assembler-error codes -258..-269 (Story 11.5 adds those when migrating the assembler).
- File-access THROW codes -69 / file-related descriptions (Epic 13).

### Architecture references

- **CCD-1 — Return-stack frame taxonomy + dual-chain discipline:** `architecture.md:168-191`. The exception-frame chain is rooted at `CATCH-TOP`; THROW reads it directly (O(1)) and walks the (currently empty) `INCLUDE-TOP` chain. INCLUDE arrives in Epic 13 — for Story 11.3 the walk is a no-op with a code comment forward-pointing at Story 13.4.
- **E11-D1 — Exception frame layout:** `architecture.md:270-287`. Frame: +0 SP, +2 IX, +4 catching-IP, +6 prev-CATCH-TOP. Story 11.2 implemented the push; Story 11.3 implements the symmetric pop on the THROW path.
- **E11-D2 — CATCH/THROW mechanism:** `architecture.md:289-300`. The THROW algorithm in 7 steps; Story 11.3 implements steps 1, 2 (no-op pre-Epic-13), 3, 4, 5 in this story's AC #1 enumeration.
- **CCD-3 — Standards-citation discipline:** `architecture.md:206-216`. THROW carries `; ANS Forth 1994 §9.6.1.2275   THROW          — raise an exception` (one line; project convention is `1994` per Story 11.1 reconciliation; see `docs/throw-codes.md` §a, lines 31-40).
- **CCD-2 — THROW code allocation:** `architecture.md:193-204`. The seeded description table covers 10 ANS Forth 1994 §9.3.5 codes; antforth extensions are added by later stories within the `-256..-32767` range.
- **Source-file organisation:** `architecture.md:443, 686`. `src/exception.asm` is the architecture-prescribed home for THROW. **Do not** place THROW or its helpers in `src/system.asm` or anywhere else.

### Constraints and conventions

- **Standards-compliance discipline** (`feedback_standards_compliance.md`): the `THROW` word's semantics must match Forth 2014 §9.6.1.2275 / ANS Forth 1994 §9.6.1.2275 verbatim — `( k*x n -- k*x | i*x n )`. n = 0 is a no-op (the standard's "If any bits of *n* are non-zero" clause means non-zero triggers; zero is silent). All three behaviours (n=0, caught, uncaught) are implemented in this story.
- **Plain QA language** (`feedback_plain_qa_language.md`): Completion Notes use Story 11.2's verdict-table format. State the value, the gate, and the reason plainly.
- **Design upfront** (`feedback_design_upfront.md`): the 8-byte frame layout was locked at Story 11.2; Story 11.3 reads it without modification. The description-table format is locked at this story (3-byte header per entry: 2 bytes code + 1 byte length); Stories 11.5, 11.7, and Epic 13 stories add entries without changing the format.
- **Adversarial review** (`feedback_adversarial_review.md`): expect ≥2-3 HIGH/MEDIUM findings. Likely candidates per AC #16: subtle SP-restore-vs-POP-BC semantics; register-clobber sequencing; second-time `ADD IX, BC` documentation; description-table edge cases (negative max-int, table overflow).
- **TOS-in-register / DEPTH discipline** (`project_tos_in_register.md`): on the caught-path NEXT, BC = n is a *real* TOS, not phantom. The SP-restore from frame +0 places i*x's TOS-cell at [SP] (the second-on-stack position), so DEPTH counts it correctly. On the uncaught path, BC is irrelevant past the diagnostic — `JP w_ABORT_cf` resets SP and QUIT resets IX/STATE/CATCH-TOP/BC-as-TOS-irrelevant.
- **REPL tests preferred** (`feedback_repl_tests_preferred.md`): all Story 11.3 tests are REPL-piped Forth lines in `tests/exception_tests.fth` Sections 6-9, with corresponding Makefile entries 674..~695. **No new assembly test threads.**

### Key implementation pitfalls

1. **The saved-SP semantic at +0 is "SP at CATCH entry, before POP BC."** Story 11.2's CATCH did `LD HL, 0 / ADD HL, SP` *before* `POP BC` (see `src/exception.asm:65-67, 100`). So the saved value is the SP that has i*x's TOS-cell at [SP]. After Story 11.3's THROW restores SP from this value, [SP] holds i*x's TOS. We then install BC = n. The post-THROW stack is `( i*x_below ... i*x_TOS n )` — exactly the standard's `( i*x n )`. **DO NOT** add a `POP BC` after `LD SP, HL` and re-push — that would discard i*x's TOS and corrupt the stack.

2. **Order of operations in the caught path:** read all frame fields (CATCH-TOP from +6, catching-IP from +4, saved-SP from +0) *before* advancing IX past the frame; advance IX (`LD BC, 8 / ADD IX, BC`); restore SP (`LD SP, HL`); install BC = n (`LD BC, (throw_saved_n)`); NEXT. Reordering is mostly safe but the IX-relative reads must precede the IX advance.

3. **`LD BC, 8 / ADD IX, BC`** is the second use of `ADD IX, BC` in the kernel. Story 11.2 documented the first use at `src/exception.asm:144-146`. Comment at this story's site: "second kernel use; first at catch_resume_cf src/exception.asm:147-148". A future audit-grep would surface both.

4. **The `INCLUDE-TOP` chain-walk placeholder** is a comment, not a no-op loop. Story 13.4 will *insert* the walk between the CATCH-TOP read and the SP/IX restore — i.e., between AC #1 step (i) (no-op now) and step (ii). The comment must say so explicitly: "Story 13.4 inserts the INCLUDE-TOP chain-walk loop here, between the CATCH-TOP-read above and the SP-restore below."

5. **`print_signed_dec_bc` must NOT read `(IY+UserArea.base)`.** The diagnostic is required to be readable in decimal (FR21); user may have BASE = HEX or other. Hardcoding `LD E, 10` solves this without save-restore-around-print (which is more code and re-entrancy-fragile).

6. **`bdos_print_str` clobbers BC** (it takes `B = length` as an arg). Across the three print calls in `.throw_uncaught` (prefix, sign-then-digits, then-description), the THROW code must be parked in `(throw_saved_n)` and reloaded into BC before each call that needs it. The draft above does this correctly: load before each use.

7. **The description-table terminator is `DW 0` only.** This is unambiguous because `THROW 0` is no-op'd before any uncaught lookup (AC #3 short-circuits at the n=0 test). Future-proofing: if some future code needs a "code 0" entry, the format would need to change (e.g., a length=0 sentinel). Document.

8. **`asm_cleanup` invocation via `JP w_ABORT_cf`** is the standard route for any "wholesale state reset" the kernel does. Routing the uncaught-THROW path through `JP w_ABORT_cf` rather than duplicating the SP/IX/STATE/CATCH-TOP reset code is *both* cleaner and more correct: it gives uncaught-THROW the exact same recovery semantics as ABORT, including asm_cleanup, which means a user who does `CODE BAD ... -13 THROW ... END-CODE` doesn't end up with a half-built CODE word in the dictionary. Story 11.7's eventual ABORT retarget will reroute `w_ABORT_cf` itself to `-1 THROW` — at which point ABORT's recovery becomes uncaught-THROW's recovery (same code path), so this story's choice is forward-compatible.

9. **Test discipline for uncaught THROW:** the diagnostic must be observed *and* the recovery must be observed. Modeled on Story 11.2's test 672, use multi-line `printf` blocks where the THROW line is followed by a recovery-checking line, then `BYE`; pipe through `iz-cpm`, `tr '\r\n' '  '` to flatten, `grep -qE` for ordered patterns. Each test asserts "diagnostic appeared *and* the next REPL line ran cleanly *and* state X was preserved."

10. **`'` (tick) parses at execution time in antforth** — the same caveat as Story 11.2 (see `tests/exception_tests.fth:13-15`). Inside colon definitions, use `[']` (IMMEDIATE). Story 11.3's tests follow the same convention.

### Test discipline

- Tests live in `tests/exception_tests.fth` Sections 6-9 (extensions of the Story 11.2 file, not a new file).
- Counterpart `printf | $(IZCPM)` blocks land in `Makefile` starting at PASS test 674.
- For uncaught-THROW tests: the diagnostic must include the substring `error <N>` (case-sensitive); for codes with seeded descriptions, the substring `error <N>: <desc>` must appear. Recovery is asserted by the next REPL command running cleanly (e.g., `99  ok` after a deliberate `: HELLO 99 ;` predefinition).
- For caught-THROW tests: assert the THROW code appears as the result of `' WORD CATCH .` and that i*x cells underneath are preserved.
- For `THROW 0` tests: assert depth dropped by 1 and BC adopted the cell below.

### Project Structure Notes

- **Edits:**
  - `src/exception.asm` — add `THROW` DEFCODE, `print_signed_dec_bc`, `print_throw_description`, `throw_desc_table`, `str_throw_prefix` / `STR_THROW_PREFIX_LEN`, `str_colon_space`, `throw_saved_n`. (Estimated growth: ~430 bytes; story file from ~150 lines to ~330-350 lines.)
  - `tests/exception_tests.fth` — append Sections 6-9 (~30-50 new lines).
  - `Makefile` — append PASS test blocks 674..~695 for new scenarios (~120-180 new lines depending on per-test verbosity).
  - `docs/register-conventions.md` — extend §9 with "Story 11.3 contract — THROW-time restore" sub-section (~40 new lines).
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` — `11-3-…` entry: `backlog` → `ready-for-dev`.
  - `_bmad-output/implementation-artifacts/11-3-throw-word-and-uncaught-throw-repl-handler.md` — this file (Status, task checkboxes, Completion Notes, File List, Change Log on dev pass).
- **No new files** — Story 11.2 already established `src/exception.asm` and `tests/exception_tests.fth`.
- File-list expectation in Dev Agent Record: 5 modified files + sprint-status + this story file + (optional) implementation notes.

### Previous-story intelligence (Story 11.2 patterns to reuse and pitfalls to avoid)

**Reuse:**
- *Verdict-table Completion Notes* (Story 11.2): one row per AC, columns `Gate text | Evidence | Verdict`. Mirror exactly.
- *Per-task evidence sections with explicit grep / wc commands*: "ran command X, got output Y, here's the implication."
- *Re-grep before publishing*: every line number cited in Dev Notes (e.g., `architecture.md:289-300`) re-verified at dev-pass time.
- *Adversarial-review-finding triage table*: Story 11.2's review log format (ID / Severity / Category / Description / Resolution) replicated in Completion Notes.
- *Binary-size delta table*: Stage / bytes / delta, mirroring Story 11.2 Completion Notes.

**Pitfalls Story 11.2's review surfaced (avoid in 11.3):**
- *F1: undocumented post-NEXT staleness* — comment any non-obvious post-call invariants explicitly.
- *F2: doubled citations* — one citation line per word; project convention is `ANS Forth 1994` for §9 codes.
- *F3: abbreviated stack-effect comment* — use the standard form, not a shorthand.
- *F4: missing test for non-zero prev-of-prev chain link* — Story 11.3's nested-CATCH tests must include depth ≥ 3 to exercise the chain-link discipline (AC #6 Section 8 covers this).
- *F5: lax grep patterns* — uncaught-THROW tests use ordered `grep -qE` patterns to enforce diagnostic-then-recovery sequencing.
- *F8: register-conventions.md numbering* — confirm §9 still numbers sequentially (it does); insert sub-section, don't introduce a §10.
- *Independent-review surfacing of ABORT/QUIT-related state issues* (Story 11.2's R1 fix): Story 11.3's uncaught-path test must verify the same chain invariants — CATCH-TOP zeroed, asm_mode cleared, dictionary intact, BASE intact. AC #6 Section 9 covers all four.

### Comparison to Story 11.2's adversarial review F-findings (Story 11.3 watch-list)

Story 11.2's review found 10 issues (4 MEDIUM, 6 LOW). Story 11.3 deliberately watches for these analogous issues:
- **CATCH-TOP slot ordering on restore** (analog of F1 staleness): document the order CATCH-TOP-read → IP-read → SP-read → IX-advance → SP-restore → BC-install.
- **Citation drift** (analog of F2): single citation line per word; one per helper if the helper is standards-derived (none of the helpers here are).
- **Stack-effect abbreviation** (analog of F3): full standard form `( k*x n -- k*x | i*x n )`.
- **Test coverage gaps** (analog of F4): include the 3-deep nested cases (AC #6 Section 8) and the rethrow case to exercise paths the simpler nested test does not.
- **Lax test ordering** (analog of F5): use `tr '\r\n' '  ' | grep -qE` for sequential-pattern enforcement.
- **First/second-use docs for new instruction patterns** (analog of F7): the second use of `ADD IX, BC` gets a comment cross-referencing Story 11.2's first use.
- **Register-conventions.md numbering** (analog of F8): re-confirm before editing.
- **Test deferrals with explicit rationale** (analogs of F9, F10): if any test is deferred, give a non-handwavy reason.

### References

- `_bmad-output/planning-artifacts/epics.md:753-779` — Story 11.3 acceptance criteria source.
- `_bmad-output/planning-artifacts/architecture.md:168-191` — CCD-1 dual-chain discipline.
- `_bmad-output/planning-artifacts/architecture.md:270-300` — E11-D1 frame layout + E11-D2 mechanism.
- `_bmad-output/planning-artifacts/architecture.md:418-446` — naming + source-file organisation for Epic-11 additions.
- `_bmad-output/planning-artifacts/architecture.md:481-488` — stack-effect + standards-citation comment pattern.
- `_bmad-output/planning-artifacts/prd.md:394-402` — FR16–FR22 (FR21 / FR22 = Story 11.3's primary delivery).
- `_bmad-output/planning-artifacts/prd.md:455` — NFR3 (CATCH/THROW overhead — bounded; Story 11.8 measures).
- `_bmad-output/planning-artifacts/prd.md:457-460` — NFR7 (REPL survives any THROW), NFR8 (state integrity post-error).
- `docs/throw-codes.md` — Story 11.1 inventory; Story 11.3 seeds the description table from §b's standard codes used by Epic 11.
- `docs/register-conventions.md:289-346` — §9 Exception Frames; Story 11.3 extends.
- `_bmad-output/implementation-artifacts/11-2-exception-frame-infrastructure-and-catch-word.md` — verdict-table format; review log structure; F-finding watch-list source.
- `src/exception.asm` (Story 11.2) — frame-build pattern (lines 65-103), `(CATCH-RESUME)` continuation (lines 127-151), `ADD IX, BC` first kernel use (lines 144-148).
- `src/system.asm:258-264` (`w_ABORT_cf`) and `src/outer_interpreter.asm:236-275` (`w_QUIT_cf`) — the ABORT-chain that uncaught-THROW reuses.
- `src/assembler.asm:405-441` (`asm_cleanup`) — the asm_mode reset that the ABORT chain triggers.
- `src/formatting.asm:11-18` (`digit_to_char`), `src/formatting.asm:27-41` (`div_bc_by_e`), `src/formatting.asm:55-79` (`u_to_str` template), `src/formatting.asm:92-107` (`print_neg_prefix` template) — the helpers `print_signed_dec_bc` reuses or models after.
- `src/io.asm:193-225` (`bdos_crlf`, `bdos_print_str`) — BDOS-print primitives the uncaught-handler uses.
- DPANS94 §9.6.1.2275 / Forth 2014 §9.6.1.2275 — `THROW` standard text.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m] (Claude Code dev-story workflow, 2026-04-25).

### Debug Log References

- Pre-edit baseline `wc -c build/antforth.com` = 16918 bytes (matches AC #7 baseline; equals post-Story-11.2 final binary size).
- Post-Story-11.3 `wc -c build/antforth.com` = 17379 bytes (Δ = +461 bytes, within ±20% of the AC #7 ~430-byte estimate).
- Post-edit `make test` (assembly thread) — clean; 0 errors / 0 warnings; "Output matches expected".
- Post-edit `make test-repl` — 704 PASS / 0 FAIL (was 700 pre-Story-11.3 = 691 unique numbers + 9 pre-existing duplicate-number lines; Story 11.3 added 22 new tests → 713 unique numbers… actual count: 691 prior unique numbers + 22 new = 695 unique, 704 raw = 695 + 9 duplicates).
- ABORT-site inventory after edit: `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` returns 20 hits = 18 code instructions (17 pre-existing + 1 new at `src/exception.asm:267`) + 2 doc-comment mentions in `src/exception.asm`. Matches AC #8.5 expectation of "exactly one new occurrence".

### Completion Notes List

#### AC verdict table

| AC | Gate text (abbrev.) | Evidence | Verdict |
|----|----|----|----|
| #1 | 7-step caught-path algorithm (E11-D2) | `src/exception.asm:171-235`; comments explicit on each step | PASS |
| #2 | Saved-SP at +0 → [SP] = i*x's TOS post-restore; no spurious POP BC | `src/exception.asm:217-225` (LD SP, HL with no follow-up POP BC); REPL test 678 (`42 3 2 1 ok`) | PASS |
| #3 | THROW 0 is a no-op consuming only the zero | `src/exception.asm:237-241` (.throw_zero); REPL tests 674-675 | PASS |
| #4 | Uncaught path prints diagnostic and routes through w_ABORT_cf | `src/exception.asm:243-267` (.throw_uncaught + JP w_ABORT_cf); REPL tests 685-691 | PASS |
| #5 | Description table seeded with 10 standard codes | `src/exception.asm:throw_desc_table` (DW -1 ABORT, DW -2 ABORT", DW -4..-58); REPL tests 686-687, 692-693 | PASS (see note A) |
| #6 | tests/exception_tests.fth Sections 6-9 + Makefile blocks | `tests/exception_tests.fth:78-149`; `Makefile:5846-5984` (REPL tests 674-695) | PASS |
| #7 | Binary delta within ~430-byte estimate | 16918 → 17379 = +461 bytes (delta +7% over estimate, well within the AC's "investigate if >20% over" threshold) | PASS |
| #8 | Post-THROW DEPTH = pre-CATCH-DEPTH + 1 | REPL test 679 (`1 2 3 4 ' T1 CATCH DEPTH .` → `5  ok`) | PASS |
| #9 | Saved-SP slot read only by THROW; consistent with Story 11.2 forward-pointer | `src/exception.asm:215-217` (LD L,(IX+0)/LD H,(IX+1) — only +0 read in the kernel) | PASS |
| #10 | Caught-path NEXT lands on caller's continuation post-CATCH | `src/exception.asm:213-214` (LD E,(IX+4)/LD D,(IX+5) → DE=catching-IP, NEXT lands one cell after CATCH) | PASS |
| #11 | Standards citation, stack-effect comment, forward-pointer comment, BC-may-be-phantom note | `src/exception.asm:178` citation; `:181` stack-effect; `:204-206` Story-13.4 forward-pointer; `:163-170` BC-as-real-TOS note | PASS |
| #12 | THROW + helpers + table at end of src/exception.asm; helpers/strings co-located | `src/exception.asm` ordering: CATCH-TOP → CATCH → catch_resume_cf → THROW → print_signed_dec_bc → print_throw_description → strings → throw_desc_table → throw_saved_n | PASS |
| #13 | print_signed_dec_bc hardcodes base 10 | `src/exception.asm:295` (LD E, 10 — comment "force decimal — DO NOT read BASE"); REPL test 689 (HEX -1 THROW → "error -1: ABORT" decimal + BASE=16 preserved) | PASS |
| #14 | Reuses num_buf with end-pointer pattern; non-reentrant safe | `src/exception.asm:289` (LD HL, num_buf + NUM_BUF_SIZE - 1); reentrancy explicitly impossible per inline doc | PASS |
| #15 | Verdict-table format for Completion Notes | This table | PASS |
| #16 | Adversarial review with ≥2-3 HIGH/MEDIUM findings expected | 7 findings: 0 HIGH, 3 MEDIUM (F1, F2, F3), 4 LOW (F4-F7); MEDIUM all fixed in pass | PASS |
| #17 | THROW's check_underflow does NOT pre-migrate to -4 THROW | `src/exception.asm:185` (CALL check_underflow — unchanged from existing helper); REPL test 691 confirms uncaught path through legacy ABORT chain | PASS |
| #18 | Every `'` in test file follows a `:` definition on prior line | `tests/exception_tests.fth` Sections 6-9: every `' Tn` follows `: Tn ...` on prior line | PASS |
| #19 | docs/register-conventions.md §9 extended with Story 11.3 sub-section + forward pointer rewrite | `docs/register-conventions.md:340-379` (new "Story 11.3 contract — THROW-time restore" sub-section + rewritten "Forward pointer (Stories 11.4–11.7, 13.4)") | PASS |
| #20 | asm_mode-cleanup integration test exercises path without Story-11.5 migration | REPL test 690 (CODE BAD → -13 THROW → CODE GOOD → END-CODE all clean) | PASS |

**Note A (AC #5 description-text deviation from story spec):** Story AC #5 enumerates abbreviated description strings for codes -16 (`attempt to use zero-length name string`) and -17 (`pictured numeric output overflow`). At code-write time the dev cross-referenced DPANS94 §9.3.5 per `feedback_systematic_reference_check.md` and substituted the standard's verbatim text:

| Code | Story AC #5 spec text | Implementation text (DPANS94 §9.3.5 verbatim) |
|---|---|---|
| -16 | `attempt to use zero-length name string` | `attempt to use zero-length string as a name` |
| -17 | `pictured numeric output overflow` | `pictured numeric output string overflow` |

Implementation wins (matches the standard); the story spec's text was an abbreviation lapse. Diagnostic output is therefore standards-conformant: `error -16: attempt to use zero-length string as a name` / `error -17: pictured numeric output string overflow`. The other 8 entries match the spec verbatim.

#### Binary-size delta table

| Stage | Bytes | Delta from prior |
|----|---:|---:|
| Post-Story-11.2 final (baseline) | 16918 | — |
| Post-Story-11.3 implementation | 17379 | +461 |
| Post-Story-11.3 review fixes (F1 doc only) | 17379 | 0 |
| Post-second-review fixes (R1-R6; L2 JR optimisation) | 17378 | -1 |

#### Test-count delta

| Stage | Total PASS lines | Unique test numbers |
|----|---:|---:|
| Post-Story-11.2 final | 682 | 673 |
| Post-Story-11.3 (tests 674-691) | 700 | 691 |
| Post-review-fix (tests 692-695) | 704 | 695 |

#### Adversarial review log

| ID | Severity | Category | Description | Resolution |
|----|----|----|----|----|
| F1 | MEDIUM | Doc | "BEFORE CATCH's POP BC consumed the xt cell" framing was misleading: at CATCH entry xt was in BC (TOS-in-register), not on the memory stack — POP BC consumed the i*x's TOS-cell, never xt. | **Fixed in pass.** Reworded comments at `src/exception.asm:163-170` (THROW header) and `:227-232` (inline at SP restore) to clarify TOS-in-register semantics. The Story 11.2 comment at `:138-141` was left untouched (its framing about "stale after PUSH" is correct in context). |
| F2 | MEDIUM | Test | No coverage for BC = 0x8000 (-32768) most-negative case despite header-comment edge-case documentation. | **Fixed in pass.** Added `tests/exception_tests.fth:107-111` (`: T8 -32768 THROW ; ' T8 CATCH .`) and Makefile REPL tests 692-693 (caught + uncaught -32768 paths). |
| F3 | MEDIUM | Test | No coverage for THROW from non-colon IX frames (DO-LOOP, EXECUTE) — the load-bearing "snap back" semantic was unverified for those frame types. | **Fixed in pass.** Added `tests/exception_tests.fth:113-122` (DO-LOOP and EXECUTE scenarios) and Makefile REPL tests 694-695. |
| F4 | LOW | Doc | "Read all frame fields before IX advances or SP changes" rule asserted but not anchored to architecture decision. | **Deferred.** Pre-Epic-13 the placeholder is a no-op; tag for Story 13.4 review when INCLUDE-TOP walk lands and the rule actually has a hazard to anchor to. |
| F5 | LOW | Doc | `print_signed_dec_bc` "Preserves: IY" claim inherits the codebase-wide unstated BDOS-preserves-IX/IY assumption. | **Deferred.** Codebase-wide convention; out-of-scope to rewrite all clobber tables. Note for future hardening (e.g., real-CP/M-BIOS audit). |
| F6 | LOW | Doc | INCLUDE-TOP placeholder lacks "between which two lines" register-state contract for Story 13.4 dev. | **Deferred.** Story 13.4 will read this story's spec for context anyway; the placeholder + `architecture.md:289-300` cross-reference is sufficient. |
| F7 | LOW | Style | `.psd_count` is mutable static state in the helper; same pattern as `formatting.asm`'s `u_to_str.uts_count`. Could use B register instead. | **Deferred.** Style consistency with codebase precedent in `formatting.asm`; reentrancy is explicitly impossible per AC #14 / `src/exception.asm:284-287`. |

#### Second-pass adversarial review (post-completion)

A fresh `bmad-bmm-code-review` pass on 2026-04-26 against the post-F1/F2/F3-fix code surfaced 1 MEDIUM (story-vs-code disclosure) and 5 LOW. M1 was a documentation gap (the verdict-table row didn't disclose the dev's correct cross-reference to DPANS94); fixed via Note A in the AC verdict table above. L1-L6 were mechanical/doc-grade improvements; L1 (Saved-IX architecture-vs-Story-11.2 wording mismatch) was deferred as cross-story. L2-L6 were fixed in-pass.

| ID | Severity | Category | Description | Resolution |
|----|----|----|----|----|
| R-M1 | MEDIUM | Doc | AC #5 verdict-table cell marked PASS without disclosing that the dev replaced the story's abbreviated description strings for -16 / -17 with DPANS94 verbatim text. | **Fixed in pass.** Added Note A under the AC verdict table documenting the dev-time correction and showing the spec-vs-implementation diff. Implementation is standards-correct; story spec was abbreviated. |
| R-L1 | LOW | Doc | `architecture.md:277` describes saved-IX as "absolute rstack pointer at CATCH entry" but Story 11.2 writes the *post-push* IX (frame base) at `+2`. Off by 8 bytes. | **Deferred.** Cross-story (Story 11.2 / architecture-edit territory). Story 11.3 doesn't read +2, so behaviour is unaffected. Flag for the Epic 11 retro. |
| R-L2 | LOW | Code-size | `JP Z, .throw_uncaught` at line 201 fits JR range (~76-byte body) — saves 1 ROM byte. | **Fixed in pass.** Changed to `JR Z, .throw_uncaught` with a forward-pointer comment to revert to JP Z if future edits push the displacement past +127. Binary 17379 → 17378 (-1 byte). |
| R-L3 | LOW | Doc | `throw_saved_n` cell described as "BSS-style" but it is in fact 2 bytes of initialised data baked into the .COM image. | **Fixed in pass.** Reworded the storage-note comment block at the bottom of `src/exception.asm` to explain the CP/M `.COM` load model (image loaded at $0100, all writable RAM after load). |
| R-L4 | LOW | Test | Test 693 grep `'error -32768'` did not assert the absence of a `: <description>` suffix; a regression that added -32768 to `throw_desc_table` would silently pass. | **Fixed in pass.** Tightened to `'error -32768  '` (matching the trailing-double-space pattern of test 685). Confirmed `make test-repl` passes. |
| R-L5 | LOW | Doc | THROW header at lines 153-182 lacked an EXX-hygiene caller-contract note for upcoming Stories 11.4-11.6 migrations. | **Fixed in pass.** Added a "Caller contract (Stories 11.4-11.6 watch-list)" paragraph to the THROW header documenting that callers must EXX-restore before falling into THROW. Cross-references `docs/register-conventions.md` §1. |
| R-L6 | LOW | Doc | `print_throw_description`'s 8-bit `ADD A, L / INC H` walk would wrap if HL ≈ $FF00 — currently safe (kernel ~17KB) but undocumented growth risk. | **Fixed in pass.** Added a comment in the helper's header noting the assumption and the 16-bit `ADD HL, A` replacement pattern for use if the kernel grows past 32KB and the table relocates near the top of memory. |

### File List

| File | Status | Note |
|----|----|----|
| `src/exception.asm` | modified | Added `w_THROW` DEFCODE (caught + n=0 + uncaught paths), `print_signed_dec_bc`, `print_throw_description`, `throw_desc_table`, `str_throw_prefix`, `STR_THROW_PREFIX_LEN`, `str_colon_space`, `throw_saved_n`. F1 review fix reworded two comment blocks. Second-review fixes: R-L2 (JP Z → JR Z at line 201), R-L3 (throw_saved_n storage-note rewording), R-L5 (added EXX-hygiene caller-contract paragraph to THROW header), R-L6 (added 32KB-growth comment to print_throw_description). |
| `tests/exception_tests.fth` | modified | Appended Sections 6-9 (THROW 0 no-op, caught round-trip, nested CATCH, uncaught + recovery) plus F2/F3 review additions (-32768, DO-LOOP, EXECUTE). |
| `Makefile` | modified | Appended REPL tests 674-695 (22 new tests; tests 674-691 cover AC #6, tests 692-695 cover review F2/F3). Second-review fix R-L4 tightened test 693 grep to assert no description suffix on uncaught -32768. |
| `docs/register-conventions.md` | modified | Inserted "Story 11.3 contract — THROW-time restore" sub-section under §9; rewrote "Forward pointer" to reference Stories 11.4-11.7 (uses) and Story 13.4 (INCLUDE-TOP walk). |
| `_bmad-output/implementation-artifacts/sprint-status.yaml` | modified | `11-3-throw-word-and-uncaught-throw-repl-handler` flipped to `review` (was `in-progress` during dev, `ready-for-dev` at story creation). |
| `_bmad-output/implementation-artifacts/11-3-throw-word-and-uncaught-throw-repl-handler.md` | modified | Status → `review`; task checkboxes ticked; Dev Agent Record / Completion Notes / File List / Change Log populated. |

### Change Log

| Date | Change | Reason |
|----|----|----|
| 2026-04-25 | Implemented `w_THROW` DEFCODE (caught + n=0 no-op + uncaught paths) in `src/exception.asm`. | Story 11.3 AC #1, #2, #3, #4. |
| 2026-04-25 | Added `print_signed_dec_bc` (BASE-independent decimal helper) and `print_throw_description` (description-table walk). | Story 11.3 AC #5, #13, #14. |
| 2026-04-25 | Seeded `throw_desc_table` with 10 standard ANS Forth 1994 §9.3.5 codes. | Story 11.3 AC #5; Epic 11 migrations will reference these. |
| 2026-04-25 | Extended `tests/exception_tests.fth` Sections 6-9 and added Makefile REPL tests 674-691. | Story 11.3 AC #6, #18. |
| 2026-04-25 | Extended `docs/register-conventions.md` §9 with Story 11.3 contract sub-section + rewritten forward pointer. | Story 11.3 AC #19. |
| 2026-04-25 | Adversarial review (general-purpose subagent) found 0 HIGH / 3 MEDIUM (F1 doc, F2 test, F3 test) / 4 LOW. F1-F3 fixed in pass; F4-F7 deferred with rationale. | `feedback_adversarial_review.md` discipline. |
| 2026-04-25 | Added Makefile REPL tests 692-695 covering most-negative -32768 + DO-LOOP/EXECUTE THROW scenarios. | Adversarial-review F2 / F3 fixes. |
| 2026-04-26 | Second-pass `bmad-bmm-code-review` (1 MEDIUM, 5 LOW). R-M1 disclosed AC #5 description-text correction via Note A; R-L2 swapped JP Z to JR Z (-1 ROM byte); R-L3/R-L5/R-L6 doc-grade comment improvements in `src/exception.asm`; R-L4 tightened test 693 grep to assert no description suffix. R-L1 (saved-IX architecture wording mismatch) deferred as cross-story. Binary 17379 → 17378 bytes; `make test` clean; `make test-repl` 704 PASS / 0 FAIL. | `feedback_adversarial_review.md` discipline; second-pass surfaces remaining doc/style work after F1-F3 fixes consolidated. |
