# Story 11.4: Internal error migration — stack, arithmetic, memory primitives

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the error paths in stack, arithmetic, and memory primitives to raise standard ANS THROW codes rather than `ABORT`,
so that I can catch these errors with `CATCH` and handle them programmatically (partial FR19 delivery; first leaf-primitive migration in the Stories 11.4–11.7 word-by-word crawl per E11-D3, `architecture.md:302-306`). This story consumes the THROW machinery Stories 11.2 and 11.3 landed and is the first migration to actually retire an `ABORT` call site — the inventory drops from 18 catalogued sites to 17 once `do_underflow_error` re-routes through `THROW -4`.

## Acceptance Criteria

1. **Given** the Story 11.1 inventory (`docs/throw-codes.md` §d) cataloguing `do_underflow_error` (`src/system.asm:551-559`) as the single ABORT site for the entire `check_underflow{,_2,_3,_4}` fan-in (49 `CALL` sites across 11 source files per `docs/throw-codes.md:225-229`), **when** Story 11.4's migration lands, **then** `do_underflow_error` no longer ends in `JP w_ABORT_cf` — it raises `THROW_STACK_UNDERFLOW` (= `-4`) by jumping into `w_THROW_cf` past its entry-time `check_underflow` guard. All 49 callers transitively raise `-4 THROW` on underflow without source edits to any of them.

2. **Given** that Story 11.3's `THROW` does `CALL check_underflow` at entry to enforce the `( n -- )` arity (`src/exception.asm:195-200`) and Story 11.3 AC #17's promise that "Story 11.4 owns the migration of `do_underflow_error` ... `THROW`'s own `check_underflow` at entry **does not** pre-migrate", **when** kernel-internal callers (this story's `do_underflow_error` and the divisor-zero sites in AC #4 / #5) need to raise a THROW from a context where the caller's stack is already underflowed or otherwise indeterminate, **then** they must enter `w_THROW_cf` *past* the entry-time `check_underflow` so the kernel-internal raise does not recurse back into `do_underflow_error`. This story adds a labelled internal entry point — `w_THROW_cf.kernel_entry` (or equivalent name like `.throw_kernel`) — immediately after the `CALL check_underflow` line in `src/exception.asm` and before the n=0 short-circuit. Internal callers `JP w_THROW_cf.kernel_entry` with `BC` already loaded with the THROW code.

3. **Given** the kernel-internal-entry label from AC #2 and the existing string `str_underflow` / `STR_UNDERFLOW_LEN` (`src/antforth.asm:221-222`) plus its sole consumer's print sequence at `src/system.asm:553-557` (`LD HL, str_underflow / LD B, STR_UNDERFLOW_LEN / CALL bdos_print_str / CALL bdos_crlf`), **when** `do_underflow_error` is migrated, **then** the print sequence and the `JP w_ABORT_cf` are deleted; the body collapses to two instructions `LD BC, THROW_STACK_UNDERFLOW` / `JP w_THROW_cf.kernel_entry`. The diagnostic the user sees on uncaught underflow becomes `error -4: stack underflow` (the description Story 11.3 seeded into `throw_desc_table` at `src/exception.asm` per Story 11.3 AC #5) instead of `? Stack underflow`. The strings `str_underflow` and `STR_UNDERFLOW_LEN` are deleted from `src/antforth.asm` along with the migration since no other site references them (verify with `grep -nE 'str_underflow|STR_UNDERFLOW_LEN' src/`).

4. **Given** the unguarded `BC ≠ 0` precondition at `udivmod` (`src/arithmetic.asm:114-115`) — currently `1 0 /` returns `-1` silently per the existing comment at `src/double.asm:560-563` ("Story 11.4 is the authoritative migration site to `THROW -10`") — and the funnel topology that `udivmod` is the divisor-receiving leaf for `/`, `MOD`, `/MOD` (each goes through `sdivmod` which then calls `udivmod`), **when** Story 11.4 lands, **then** `udivmod` gains a divisor-zero guard at its entry (before the existing `LD DE, 0 / LD A, 16` setup): if `BC == 0`, `LD BC, THROW_DIV_BY_ZERO` (= `-10`) and `JP w_THROW_cf.kernel_entry`. Otherwise, fall through to the existing loop. `1 0 /`, `1 0 MOD`, `1 0 /MOD` each raise `-10 THROW` after the migration; `' SOMEWORD CATCH` catches `-10`.

5. **Given** the architecture comment at `src/double.asm:560-563` explicitly tagging `UM/MOD` (`w_U_M_SLASH_MOD_cf` at `src/double.asm:566-600`) as the authoritative double-cell-divide leaf for Story 11.4 (covers `*/`, `*/MOD` indirectly via `SM/REM` → `UM/MOD`, plus `FM/MOD` and `M/MOD`, plus bare `UM/MOD` user invocations), and the funnel discipline (one guard at `UM/MOD` covers every double-cell-divide path), **when** Story 11.4 lands, **then** `w_U_M_SLASH_MOD_cf` gains a divisor-zero guard immediately after its `CALL check_underflow_3` (where BC = the single-cell divisor `n` per the `( ud n -- urem uquot )` stack effect): if `BC == 0`, `LD BC, THROW_DIV_BY_ZERO` and `JP w_THROW_cf.kernel_entry`. `1 0 0 UM/MOD`, `1 0 0 SM/REM`, `1 0 0 FM/MOD`, `1 0 0 M/MOD`, `1 0 0 */`, `1 0 0 */MOD` each raise `-10 THROW` after the migration; each catchable.

6. **Given** the description text seeded into `throw_desc_table` at Story 11.3 (`src/exception.asm`: `-4 stack underflow`, `-10 division by zero`), **when** an uncaught Story-11.4 THROW fires at the REPL, **then** the diagnostic is `error -4: stack underflow` for an underflow and `error -10: division by zero` for a divisor-zero — both via the existing description-table walk in `print_throw_description`. No new entries or table edits required; Story 11.3 pre-seeded both codes for exactly this consumption.

7. **Given** the `tests/throw_migration_tests.fth` file referenced in the epic AC ("each migrated primitive ... `tests/throw_migration_tests.fth` gains a new case asserting the correct THROW code via `CATCH`") and the fact that this file does not exist pre-Story-11.4 (verified at story-drafting time), **when** Story 11.4 lands, **then** `tests/throw_migration_tests.fth` is *created* as a new file with a header comment describing Epic 11's word-by-word migration discipline (cross-reference `docs/throw-codes.md` and `feedback_repl_tests_preferred.md`) and is populated with Story 11.4's caught-THROW assertions. Stories 11.5 / 11.6 / 11.7 will append further sections; this story owns the file's creation and Section 1 (stack underflow) + Section 2 (divisor zero).

8. **Given** the `feedback_repl_tests_preferred.md` rule (Epic 3+ tests are REPL-piped Forth scripts, not assembly threads) and Story 11.3's per-line `\ expect: <fragment>` convention, **when** Story 11.4's tests are written, **then** every test follows the same convention; the matching `printf | $(IZCPM)` blocks are appended to `Makefile` starting at PASS test 696 (highest existing per Story 11.3 final = 695 — verify with `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending).

9. **Given** the test coverage requirement (one CATCH-around-the-failing-word test per migrated word minimum, plus DEPTH-invariant verification per AC #11), **when** Story 11.4's tests are written, **then** they cover at minimum the following caught-THROW round-trips, each as a single REPL line of the form `' WORD CATCH .` (or a small `: T ... ;` wrapper for words that take args):

    - **Stack underflow caught (one per stack/arithmetic/memory category, sample selection — exhaustive coverage of all 49 callers is not required):**
        - `' DROP CATCH .` → `-4  ok` (stack_ops, depth-1 guard).
        - `' + CATCH .` → `-4  ok` (arithmetic, depth-2 guard via `check_underflow_2`).
        - `' @ CATCH .` → `-4  ok` (memory, depth-1 guard).
        - `' ! CATCH .` → `-4  ok` (memory, depth-2 guard).
        - `' ROT CATCH .` → `-4  ok` (stack_ops, depth-3 guard via `check_underflow_3`).
        - `' 2SWAP CATCH .` → `-4  ok` (stack_ops, depth-4 guard via `check_underflow_4`).
        - `5 ' DROP CATCH .` → `0  ok` (positive control: DROP with depth-1 succeeds; CATCH returns 0).
    - **Stack underflow caught — i\*x preservation under THROW (per AC #11, mirrors Story 11.3 Section 7):**
        - `1 2 3 ' DROP CATCH . . . .` → `-4 3 2 1  ok` (THROW code on top, three pre-CATCH cells preserved underneath).
    - **Divisor zero caught — single-cell:**
        - `: T1 1 0 / ; ' T1 CATCH .` → `-10  ok`.
        - `: T2 1 0 MOD ; ' T2 CATCH .` → `-10  ok`.
        - `: T3 1 0 /MOD ; ' T3 CATCH .` → `-10  ok`.
        - `: T4 1 1 0 */ ; ' T4 CATCH .` → `-10  ok`.
        - `: T5 1 1 0 */MOD ; ' T5 CATCH .` → `-10  ok`.
        - `: P1 100 5 / ; ' P1 CATCH . .` → `0 20  ok` (positive control — CATCH around a divide that doesn't trap returns 0 + correct quotient).
    - **Divisor zero caught — double-cell (UM/MOD funnel):**
        - `: T6 1 0 0 UM/MOD ; ' T6 CATCH .` → `-10  ok`.
        - `: T7 1 0 0 SM/REM ; ' T7 CATCH .` → `-10  ok`.
        - `: T8 1 0 0 FM/MOD ; ' T8 CATCH .` → `-10  ok`.
        - `: T9 1 0 0 M/MOD ; ' T9 CATCH .` → `-10  ok` (only if `M/MOD` exists in the kernel — check at write time; if absent, omit this case and document).
    - **Uncaught underflow — recovery + diagnostic format:**
        - `DROP` (no leading number; just empty-stack DROP) → output contains `error -4: stack underflow`; subsequent REPL command (e.g., `42 .`) runs cleanly producing `42  ok`. Modeled on Story 11.3 Section 9's diagnostic+recovery test using `tr '\r\n' '  ' | grep -qE 'error -4: stack underflow.*42  ok'`.
        - `1 0 /` → output contains `error -10: division by zero`; subsequent `99 .` → `99  ok`.

10. **Given** the post-Story-11.3 baseline (`build/antforth.com` = 17378 bytes per Story 11.3 final wc-c; 695 unique REPL test numbers, 704 total PASS lines with 9 duplicate numbering rows per Story 11.3 Completion Notes), **when** Story 11.4 lands, **then** the binary delta is bounded as follows: deletions (-19 bytes from `str_underflow` 17-byte string + 2-byte length-prefix + EQU 0 bytes; -12 bytes from the four-instruction print sequence in `do_underflow_error`) and additions (+6 bytes for the new `LD BC, -4 / JP w_THROW_cf.kernel_entry` body of `do_underflow_error`; +9 bytes per divisor-zero guard at `udivmod` and `UM/MOD` ≈ +18 bytes total; +0 bytes for the `.kernel_entry:` label inside `w_THROW_cf`). **Estimated net delta: -7 to +5 bytes.** Pre/post `wc -c build/antforth.com` recorded in Completion Notes. Investigate if delta exceeds ±20 bytes (likely cause: under-counted `str_underflow`-removal cascade, or unexpected MACRO expansion).

11. **Given** the `TOS-in-register & DEPTH` discipline (`project_tos_in_register.md` — "BC=TOS may be phantom after ABORT; DEPTH=(sp_base-SP)/2 counts SP cells only, not BC; DEPTH=0 means BC invalid") and Story 11.3's caught-THROW invariant ("post-NEXT, BC = n is a *real* TOS"), **when** a stack-underflow `-4 THROW` fires from BC=TOS territory and is caught by an enclosing `CATCH`, **then** the post-THROW state satisfies the DEPTH invariant: BC = -4 is a *real* TOS, `[SP]` holds i\*x's TOS-cell from the CATCH-entry-time stack, and `DEPTH` reports `pre-CATCH-DEPTH + 1` (not phantom-phantom-phantom). Verifiable test: `1 2 3 ' DROP CATCH DEPTH .` (`DROP` underflows after CATCH consumed the xt and DEPTH was 3; CATCH's snap-back restores SP to the pre-CATCH cell-3 boundary and BC=-4 makes DEPTH 4): output `4  ok`. (Note: `DEPTH` itself doesn't grow the depth at the time of read since `DEPTH` *pushes* the depth — same logic as Story 11.3's AC #8 test.)

12. **Given** the same DEPTH-invariant rule for divisor-zero on the caught path, **when** a `1 0 /` raises `-10 THROW` and is caught, **then** the post-THROW DEPTH equals `pre-CATCH-DEPTH + 1`. Verifiable: `5 6 7 : T 1 0 / ; ' T CATCH DEPTH .` → `4  ok` (3 i\*x cells preserved + the -10 = depth 4 at the time of the `DEPTH` read).

13. **Given** the post-`do_underflow_error`-migration ABORT-site count (= prior 18 catalogued sites − 1 migrated = 17 surviving), **when** Story 11.4 lands, **then** `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` returns exactly 17 hits (the 16 unmigrated leaf sites + 1 hit inside `src/exception.asm` for the uncaught-THROW recovery chain at `src/exception.asm:286`, which is the *new* THROW-introduced ABORT consumer — Stories 11.5/11.6 don't reduce this; Story 11.7 retargets the entry-point so `w_ABORT_cf` itself becomes `-1 THROW` and the count semantically inverts). The expected delta is **−1 from 18 to 17**, matching `docs/throw-codes.md` §d's "Migration story 11.4" tagging on exactly the `system.asm:559` row. Recorded in Completion Notes.

14. **Given** the standards-citation discipline (CCD-3 / NFR17 / NFR18, `architecture.md:206-216`) and the existing standards-citation pattern at modified words, **when** Story 11.4 edits `src/arithmetic.asm` (`udivmod`) and `src/double.asm` (`UM/MOD`), **then** the divisor-zero guard at each site carries an inline comment of the form `; -10 THROW (Story 11.4): division by zero per ANS Forth 1994 §9.3.5` (consistent with the existing throw-code citation form in `src/constants.asm:60`). The migration site at `src/system.asm` (`do_underflow_error`) gains a similar inline comment `; -4 THROW (Story 11.4): stack underflow per ANS Forth 1994 §9.3.5`. The new `.kernel_entry:` label inside `src/exception.asm`'s `w_THROW_cf` carries a header comment block explaining the kernel-internal entry contract (BC must be pre-loaded with the THROW code; SP/IX may be in any state, will be reset by the caught/uncaught dispatch downstream).

15. **Given** that the `do_underflow_error` print sequence currently uses `bdos_print_str` and `bdos_crlf` directly (the comment at `src/system.asm:548-549` says "Uses direct BDOS because SP may be corrupt"), and that the post-migration path delegates the diagnostic emission to Story 11.3's `print_signed_dec_bc` + `print_throw_description` + `bdos_crlf` chain (which equally uses direct-BDOS via `bdos_print_str`), **when** the migration lands, **then** the SP-may-be-corrupt invariant is preserved: the new path entering `w_THROW_cf.kernel_entry` does not require a clean SP because (a) on the caught path, `LD SP, HL` from the CATCH frame's +0 slot replaces whatever SP was, and (b) on the uncaught path, `JP w_ABORT_cf` resets SP to `(sp_base)` before any further stack use. Document the invariant inline at the new `.kernel_entry:` label.

16. **Given** Story 11.3's `INCLUDE-TOP` chain-walk placeholder (a no-op pre-Epic-13 documented at `src/exception.asm:221-223`), **when** Story 11.4's kernel-internal callers `JP w_THROW_cf.kernel_entry`, **then** they pass *through* the placeholder unchanged (the placeholder is between the CATCH-TOP read and the SP/IX restore on the caught path, so a kernel-entry that skips only `check_underflow` still hits the placeholder; Story 13.4's chain-walk insertion will not require Story 11.4 changes).

17. **Given** the EQU declarations Story 11.1 added to `src/constants.asm` (`THROW_STACK_UNDERFLOW EQU -4`, `THROW_DIV_BY_ZERO EQU -10`, both with citation comments per CCD-3), **when** Story 11.4 emits these codes, **then** the source uses the EQU symbols, *not* the bare numerical literals (`LD BC, THROW_STACK_UNDERFLOW` not `LD BC, -4`). This is the convention the architecture spec mandates at `architecture.md:471-479` and that Story 11.1's EQU declaration was put in place to support — the actual first-consumption of those EQUs lands in this story.

18. **Given** the adversarial-review discipline (`feedback_adversarial_review.md` — "reviews MUST find things; absence of findings is suspect"), **when** Story 11.4's review runs, **then** at least 2-3 HIGH/MEDIUM findings are expected. Likely candidates: (a) the kernel-internal-entry label semantic — does it correctly skip *only* `check_underflow` and nothing else? what if a future edit inserts code between the `CALL check_underflow` and `LD A, B / OR C`? (b) the SP-is-indeterminate-on-entry contract: does the path correctly hit the catch-frame restore before any SP-dependent operation? (c) test gaps — what about `THROW` itself being called with insufficient stack? does the legacy `do_underflow_error → do_underflow_error → ...` recursion definitely not happen, given the new `JP w_THROW_cf.kernel_entry` is taken from the same `do_underflow_error` site? (d) the `str_underflow` removal — confirm zero remaining references (cross-grep `bdos_print_str`-callers for stale length-arg). (e) the divisor-zero guards — what about `BC = 0x8000` (most-negative) for signed divides where `sdivmod` negates? `0 NEGATE = 0`, but verify the BIT-7 check sequence handles `0` correctly (it does — BIT 7 of 0 is 0, JR Z taken, no negate). (f) coverage gaps in the test suite — division-by-zero from inside a colon body where `>R / R>` semantics matter; nested CATCH where the inner catches the underflow and the outer sees normal return. Triage all findings; fix HIGH and MEDIUM in-pass; defer LOW with rationale.

19. **Given** the Story 11.3 verdict-table format for Completion Notes (one row per AC, columns `Gate text | Evidence | Verdict`), **when** Story 11.4 lands, **then** Completion Notes mirror that format. State the value, the gate, and the reason plainly per `feedback_plain_qa_language.md`.

20. **Given** the post-edit regression discipline (`make` + `make test` + `make test-repl` clean against the post-Story-11.3 baseline — 0 errors, 0 warnings, 704 PASS / 0 FAIL), **when** Story 11.4 lands, **then** all three passes run clean; new tests appended at PASS 696..~720; total PASS lines should rise to ~720-728 (assuming ~24-30 new tests covering the scenarios in AC #9). **Critical regression check:** the existing 704 prior tests must continue PASS — particularly the Story 11.3 uncaught-THROW tests at 685-693 which exercise the ABORT-recovery chain that Story 11.4 partially modifies (by removing the print of `? Stack underflow`; the `error -<N>: <desc>` format from Story 11.3's diagnostic remains the user-visible output for any THROW-recovered error, including underflow now).

## Tasks / Subtasks

- [x] **Task 1 — Verify the inventory + EQU + helper-label invariants pre-edit (AC: #1, #2, #4, #5, #13, #17)**
  - [x] 1.1 Re-run `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm`; expect 18 hits (17 inventoried + 1 `src/exception.asm:286` the Story-11.3 uncaught-recovery chain). Reconcile any drift since Story 11.3 final.
  - [x] 1.2 Confirm `src/system.asm:551-559` (`do_underflow_error`) is structurally what `docs/throw-codes.md` §d assumes (the print sequence + final `JP w_ABORT_cf`). Confirm `src/system.asm:553-557` is the print sequence to delete.
  - [x] 1.3 Confirm `THROW_STACK_UNDERFLOW EQU -4` and `THROW_DIV_BY_ZERO EQU -10` are declared at `src/constants.asm:59-60` per Story 11.1 final. (No edit; just verify EQU resolution.)
  - [x] 1.4 Confirm `src/exception.asm` `w_THROW_cf` (`:195-200`) starts with `CALL check_underflow` and that the very next line begins the n=0 short-circuit (`LD A, B / OR C / JR Z, .throw_zero`). The new `.kernel_entry:` label belongs *between* the `CALL check_underflow` and the n=0 `LD A, B`.
  - [x] 1.5 `grep -nE 'str_underflow|STR_UNDERFLOW_LEN' src/*.asm` — expect exactly 2 occurrences pre-edit (`src/antforth.asm:221-222` declaration, `src/system.asm:553-554` consumption). Both are deleted by Task 3.
  - [x] 1.6 Confirm `src/arithmetic.asm:114-115` is `udivmod:` with the precondition comment "BC != 0 (division by zero produces undefined result)". Confirm `src/double.asm:566-573` is `w_U_M_SLASH_MOD_cf:` with `CALL check_underflow_3` immediately followed by `LD (double_ip_stash), DE`. The divisor-zero guard belongs *before* the `LD (double_ip_stash)` for `UM/MOD` and *before* `LD DE, 0` for `udivmod`.
  - [x] 1.7 Confirm `src/double.asm:560-563` carries the comment "Story 11.4 is the authoritative migration site to `THROW -10`" — this is the architectural reservation that authorises the double.asm touch in this story.
  - [x] 1.8 `wc -c build/antforth.com` — record pre-edit baseline (expected 17378 bytes per Story 11.3 final).

- [x] **Task 2 — Add the kernel-internal entry label to `w_THROW_cf` (AC: #2, #14, #15, #16)**
  - [x] 2.1 Open `src/exception.asm` and locate the `w_THROW_cf:` label (`:195`) immediately followed by `CALL check_underflow` (`:196`). Insert a new internal label `.kernel_entry:` (or `.throw_kernel:` — choose the name with the dot-prefix so it scopes to the enclosing word, mirroring the existing `.throw_zero` / `.throw_uncaught` convention) on the line *after* the `CALL check_underflow` and *before* the `; --- n = 0 no-op ...` block header.
  - [x] 2.2 Above the new label, insert a comment block documenting the kernel-internal-entry contract:

    ```
    ; -----------------------------------------------
    ; Kernel-internal entry: callers from inside the kernel (do_underflow_error,
    ; the divisor-zero guards in udivmod / UM/MOD, and any future internal
    ; ABORT-site migration in Stories 11.5 / 11.6) JP w_THROW_cf.kernel_entry
    ; with BC pre-loaded to the THROW code. The check_underflow guard is
    ; skipped for two reasons:
    ;   (1) the caller's user stack is by definition in a degenerate state on
    ;       the underflow path (so check_underflow would re-trip and recurse
    ;       through do_underflow_error endlessly);
    ;   (2) the THROW code in BC is not a stack arg but a register-passed
    ;       parameter, so the ( n -- ) arity contract that check_underflow
    ;       enforces does not apply here.
    ; SP/IX may be in any state on entry — the caught-path's LD SP, HL from
    ; the catch frame +0, and the uncaught-path's JP w_ABORT_cf, both perform
    ; a wholesale state reset before any SP-dependent operation.
    ; -----------------------------------------------
    ```

  - [x] 2.3 Confirm the label is reachable from `JP w_THROW_cf.kernel_entry` (the assembler's local-label scoping resolves dot-prefixed labels relative to the enclosing word — the same scoping that `.throw_zero` and `.throw_uncaught` rely on).
  - [x] 2.4 Confirm no existing kernel code targets the `w_THROW_cf` entry directly via JP (only the inner-interpreter NEXT reaches it via DEFCODE dispatch, which always wants the entry-time `check_underflow` because user-thread `THROW` invocations *do* take a stack arg). The new label is not a substitute for `w_THROW_cf` — it is a sibling entry for kernel-internal raises.

- [x] **Task 3 — Migrate `do_underflow_error` to `-4 THROW` (AC: #1, #3, #14, #15)**
  - [x] 3.1 Open `src/system.asm` at `do_underflow_error:` (`:551-559`). Replace the body — the four-instruction print sequence (`LD HL, str_underflow / LD B, STR_UNDERFLOW_LEN / CALL bdos_print_str / CALL bdos_crlf`) plus the terminal `JP w_ABORT_cf` — with the two-instruction THROW raise:

    ```
    do_underflow_error:
            ; Migrated by Story 11.4 from `JP w_ABORT_cf` (with a "? Stack
            ; underflow" pre-print) to a clean -4 THROW. The diagnostic the
            ; user sees on the uncaught path becomes "error -4: stack
            ; underflow" (description seeded by Story 11.3 into
            ; throw_desc_table at src/exception.asm). On the caught path,
            ; -4 lands on the user's data stack as the THROW code per
            ; ANS Forth 1994 §9.3.5.
            ;
            ; Note: CALL check_underflow's return address remains on SP —
            ; harmless because the THROW-restore (caught) or the ABORT-chain
            ; (uncaught) both wholesale reset SP downstream.
            ;
            ; -4 THROW (Story 11.4): stack underflow per ANS Forth 1994 §9.3.5
            LD      BC, THROW_STACK_UNDERFLOW
            JP      w_THROW_cf.kernel_entry
    ```

  - [x] 3.2 Update the header comment block (`src/system.asm:546-550`) to reflect the new behaviour (no longer "Print '? Stack underflow' + CR/LF then jump to ABORT" — now "Raise `-4 THROW` via the kernel-internal THROW entry"). Preserve the "Uses direct BDOS because SP may be corrupt" note as a historical-context line, or delete it (since the new path no longer prints directly — direct-BDOS is moved into `print_signed_dec_bc` and friends, which the THROW path uses on the uncaught side).
  - [x] 3.3 Open `src/antforth.asm` at `:221-222` (`str_underflow:` declaration + `STR_UNDERFLOW_LEN EQU` line). Delete both lines. The strings before (`str_ok:`) and after (`str_pic_overflow:`) remain in place; no other reorganisation needed.

- [x] **Task 4 — Add divisor-zero guard at `udivmod` (AC: #4, #14, #17)**
  - [x] 4.1 Open `src/arithmetic.asm` at `udivmod:` (`:114`). Insert the divisor-zero guard at the top of the body, *before* `LD DE, 0`:

    ```
    udivmod:
        ; Divisor-zero guard (Story 11.4): BC = 0 → -10 THROW. Covers the
        ; `/`, `MOD`, `/MOD` user-facing words (each routes through sdivmod
        ; → udivmod). sdivmod's sign-fixup logic preserves zero (0 NEGATE = 0
        ; via the BIT 7 check), so an entry-time BC = 0 reaches udivmod
        ; unchanged and trips this guard.
        ;
        ; -10 THROW (Story 11.4): division by zero per ANS Forth 1994 §9.3.5
        LD      A, B
        OR      C
        JR      NZ, .udiv_proceed
        LD      BC, THROW_DIV_BY_ZERO
        JP      w_THROW_cf.kernel_entry
    .udiv_proceed:
        ; Precondition: BC != 0 (now enforced by the guard above)
        LD      DE, 0           ; DE = remainder
        LD      A, 16           ; 16 bits
    .udiv_loop:
        ...
    ```

  - [x] 4.2 Update the header comment at `:108-113` to reflect the new precondition status (was "Caller MUST save DE (IP) before calling. Uses A as bit counter, clobbers DE" — now mention "Divisor-zero is checked at entry; throws -10 via w_THROW_cf.kernel_entry").

- [x] **Task 5 — Add divisor-zero guard at `UM/MOD` (AC: #5, #14, #17)**
  - [x] 5.1 Open `src/double.asm` at `w_U_M_SLASH_MOD_cf:` (`:566-600`). Insert the divisor-zero guard immediately after `CALL check_underflow_3` (`:569`) and *before* `LD (double_ip_stash), DE` (`:570`):

    ```
    w_U_M_SLASH_MOD_cf:
            CALL    check_underflow_3
            ; Divisor-zero guard (Story 11.4): BC = the divisor n at this
            ; point. SM/REM, FM/MOD, M/MOD, */, and */MOD all funnel through
            ; UM/MOD per the architecture comment at :558-563 — this single
            ; guard covers every double-cell-divide path.
            ;
            ; -10 THROW (Story 11.4): division by zero per ANS Forth 1994 §9.3.5
            LD      A, B
            OR      C
            JR      NZ, .ummod_proceed
            LD      BC, THROW_DIV_BY_ZERO
            JP      w_THROW_cf.kernel_entry
    .ummod_proceed:
            LD      (double_ip_stash), DE   ; Stash IP — DE now free
            ...existing body unchanged...
    ```

  - [x] 5.2 Update the existing header comment at `:558-563` ("Divide-by-zero: matches the Epic-1–8 baseline for single-cell `/` bit-identically (no new ABORT; empirically today `1 0 /` returns -1 silently — see Completion Notes). Story 11.4 is the authoritative migration site to `THROW -10`.") to reflect the now-implemented behaviour: replace "matches the Epic-1–8 baseline ... silently" with "Migrated by Story 11.4: divisor-zero raises `-10 THROW` (catchable via `CATCH`; uncaught diagnostic `error -10: division by zero`)."

- [x] **Task 6 — Build, sanity-probe, and tighten regression baseline (AC: #10, #13, #20)**
  - [x] 6.1 `make` after Tasks 2-5. Confirm clean assemble; record byte count via `wc -c build/antforth.com` (post-Task-6 figure). Compare against AC #10 estimate (-7 to +5 bytes from 17378 baseline → target range 17371-17383).
  - [x] 6.2 Quick interactive sanity probes (one-line REPL pipes via `iz-cpm`):
    - `printf 'DROP\r\nBYE\r\n' | iz-cpm build/antforth.com 2>/dev/null | grep -qE 'error -4: stack underflow'` → expect a hit (uncaught underflow now uses Story 11.3 diagnostic format).
    - `printf '1 0 /\r\nBYE\r\n' | iz-cpm build/antforth.com 2>/dev/null | grep -qE 'error -10: division by zero'` → expect a hit.
    - `printf "%s\r\n%s\r\n%s\r\n" "' DROP CATCH ." 'BYE' | iz-cpm build/antforth.com 2>/dev/null | grep -qE '\\-4  ok'` → expect a hit (caught underflow round-trip).
    - `printf "%s\r\n%s\r\n%s\r\n" ': T 1 0 / ;' "' T CATCH ." 'BYE' | iz-cpm build/antforth.com 2>/dev/null | grep -qE '\\-10  ok'` → expect a hit.
  - [x] 6.3 `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` — expect exactly 17 hits (one fewer than pre-edit; the dropped one is `system.asm:559`).
  - [x] 6.4 `grep -nE 'str_underflow|STR_UNDERFLOW_LEN' src/*.asm` — expect zero hits.

- [x] **Task 7 — Author REPL test scenarios in `tests/throw_migration_tests.fth` (AC: #7, #8, #9, #11, #12)**
  - [x] 7.1 Create the new file `tests/throw_migration_tests.fth` with a header comment block:

    ```
    \ throw_migration_tests.fth — Epic 11 Stories 11.4-11.7 — internal-error
    \                              migration (ABORT → THROW) regression suite
    \ AntForth — A Forth for CP/M on Z80
    \
    \ Covers the word-by-word migration of internal error sites from ABORT
    \ to THROW per E11-D3 (architecture.md:302-306). One test per migrated
    \ primitive minimum: ' WORD CATCH . asserts the THROW code lands on the
    \ data stack, per the migration discipline rule in
    \ feedback_repl_tests_preferred.md.
    \
    \ Each line is sent to the REPL with the expected stdout fragment in a
    \ trailing `\ expect: <fragment>` comment. The Makefile `test-repl`
    \ entries (tests 696..) are the authoritative runners — keep these in
    \ sync. NOTE: at the REPL (interpret mode) we use `'` to obtain xts.
    \ Inside colon definitions we must use `[']` (IMMEDIATE) because `'`
    \ in antforth parses at execution time, not compile time.
    \
    \ Story 11.4 owns Sections 1 and 2 (stack underflow -4; divisor zero -10).
    \ Story 11.5 will append Section 3 (compiler / dictionary / control flow).
    \ Story 11.6 will append Section 4 (strings / I-O).
    \ Story 11.7 will append Section 5 (ABORT / ABORT" retarget verification).
    ```

  - [x] 7.2 Append Section 1 (stack underflow caught — sample primitives across stack/arithmetic/memory categories) per AC #9 first sub-bullet group. Each test line uses `\ expect: -4  ok` (or the positive-control variant). Cover at minimum: `' DROP`, `' +`, `' @`, `' !`, `' ROT`, `' 2SWAP`, plus the positive-control `5 ' DROP CATCH .` and the i\*x-preservation test `1 2 3 ' DROP CATCH . . . .`.
  - [x] 7.3 Append Section 2 (divisor zero caught — single-cell + double-cell). Each test wraps the failing word in a `: TN ... ;` definition (since the divisor-zero argument is part of the word's body, not a REPL-typed pre-arg). Cover at minimum: `/`, `MOD`, `/MOD`, `*/`, `*/MOD` (single-cell via udivmod), and `UM/MOD`, `SM/REM`, `FM/MOD`, `M/MOD` (double-cell via UM/MOD funnel — verify each exists in the kernel at write time; if `M/MOD` is absent, omit and document). Plus the positive-control `: P1 100 5 / ; ' P1 CATCH . .` → `0 20  ok`.
  - [x] 7.4 Append Section 1's DEPTH-invariant test (AC #11): `1 2 3 ' DROP CATCH DEPTH .` → `4  ok`. And Section 2's variant (AC #12): `: T 1 0 / ; 5 6 7 ' T CATCH DEPTH .` → `4  ok`.
  - [x] 7.5 Cross-check at test-write time (mirroring Story 11.3 AC #18): every `'` in the new file must follow a `:` definition of the same name on a prior line *or* be a `'` of an existing kernel word. Story 11.5 will migrate `'` itself to `THROW -13` for undefined names; until then, an undefined-name `'` would derail the test if it slipped in. None of the Story 11.4 tests use undefined names.

- [x] **Task 8 — Append matching `printf | $(IZCPM)` blocks to `Makefile` (AC: #8, #9, #20)**
  - [x] 8.1 Highest existing PASS test number per Story 11.3 final: 695 — verify by `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending. New tests start at 696.
  - [x] 8.2 For each test in `tests/throw_migration_tests.fth` Sections 1 + 2, add a Makefile block following the Story 11.3 pattern (single-line: `printf '...\r\n...\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \ if echo "$$OUTPUT" | grep -q ...; then echo "PASS"; else echo "FAIL"; fi`). Estimated count: ~22-28 new tests covering the ~20 caught-throw cases + the 2 uncaught-recovery cases + the 2 DEPTH-invariant cases.
  - [x] 8.3 For the uncaught-THROW recovery tests (AC #9 last sub-bullet group), use the multi-line `printf` + `tr '\r\n' '  ' | grep -qE` pattern from Story 11.3 test 691:
    - `printf "%s\r\n%s\r\n%s\r\n" 'DROP' '42 .' 'BYE' | $(IZCPM) ... | tr '\r\n' '  ' | grep -qE 'error -4: stack underflow.*42  ok'`
    - `printf "%s\r\n%s\r\n%s\r\n" '1 0 /' '99 .' 'BYE' | $(IZCPM) ... | tr '\r\n' '  ' | grep -qE 'error -10: division by zero.*99  ok'`
  - [x] 8.4 Run `make test-repl` after Makefile update. Expected: 704 prior PASS + ~22-28 new = ~726-732 PASS, zero FAIL. Final count is dev's choice as long as every AC #9 case is covered.

- [x] **Task 9 — Build, full regression, and binary-size delta (AC: #10, #13, #20)**
  - [x] 9.1 `make` — clean assemble, zero errors, zero warnings.
  - [x] 9.2 `wc -c build/antforth.com` post-edit. Pre-Story-11.4 baseline: 17378 bytes. Estimated post-Story-11.4: 17371-17383 bytes (delta -7 to +5 per AC #10). Record actual; investigate if delta exceeds ±20 bytes (likely cause: under-counted `str_underflow` removal cascade or unexpected MACRO expansion).
  - [x] 9.3 `make test` — assembly thread regression passes clean. Zero new assembly tests required.
  - [x] 9.4 `make test-repl` — confirm all tests PASS. Particularly verify that Story 11.3's tests 685-693 (uncaught-THROW recovery) still pass, since this story modifies the diagnostic-emission chain by removing `do_underflow_error`'s direct print.
  - [x] 9.5 Verify ABORT-site count: `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` returns exactly 17 hits (was 18 pre-edit; `system.asm:559` is the dropped row).
  - [x] 9.6 Verify dead-string removal: `grep -nE 'str_underflow|STR_UNDERFLOW_LEN' src/*.asm` returns zero hits.

- [x] **Task 10 — Code review (AC: #18, all)**
  - [x] 10.1 Run adversarial code review via the `bmad-bmm-code-review` skill (or fresh `general-purpose` Agent). Per `feedback_adversarial_review.md`: a clean review is suspect — expect ≥2-3 HIGH/MEDIUM findings (likely candidates listed in AC #18).
  - [x] 10.2 Triage all findings; fix HIGH and MEDIUM in-pass; defer LOW with rationale. Mirror Story 11.3's review-log discipline.
  - [x] 10.3 Post-review-fix `make` / `make test` / `make test-repl`: confirm no regressions; binary delta within ±5% of pre-review post-fix figure.
  - [x] 10.4 Record review log in Completion Notes per Story 11.3 format: `ID / Severity / Category / Description / Resolution` columns.

- [x] **Task 11 — Update sprint status and finalize (AC: #19, #20)**
  - [x] 11.1 Update `_bmad-output/implementation-artifacts/sprint-status.yaml`: `11-4-internal-error-migration-stack-arithmetic-memory-primitives: backlog` → `ready-for-dev` (the create-story flip; the dev pass will move it to `in-progress` then `review` → `done` per the workflow).
  - [x] 11.2 Set `Status:` field at the top of this story file to `ready-for-dev` upon initial creation. The dev pass updates it through the lifecycle.

## Dev Notes

### Mission and shape of this story

This is the *first* word-by-word migration story in the Stories 11.4–11.7 crawl per E11-D3 (`architecture.md:302-306`). It retires the single most-used ABORT site in the kernel (`do_underflow_error`, 49 callers) and adds the first-ever divisor-zero guard (`udivmod` + `UM/MOD` — previously `1 0 /` returned `-1` silently per the existing `src/double.asm:560-563` comment). After this story, the inventory drops from 18 ABORT-relevant sites to 17 and a user can write `' WORD CATCH .` to handle stack-underflow and divide-by-zero programmatically.

What this story lands:
- A new kernel-internal entry label `.kernel_entry:` inside `w_THROW_cf` (`src/exception.asm`) that bypasses the entry-time `check_underflow` for kernel-side raises.
- `do_underflow_error` (`src/system.asm:551-559`) collapsed to a 2-instruction `LD BC, -4 / JP w_THROW_cf.kernel_entry` raise.
- `str_underflow` and `STR_UNDERFLOW_LEN` deletion from `src/antforth.asm`.
- A divisor-zero guard at `udivmod` (`src/arithmetic.asm:114`) covering `/`, `MOD`, `/MOD`.
- A divisor-zero guard at `UM/MOD` (`src/double.asm:566`) covering `*/`, `*/MOD`, `SM/REM`, `FM/MOD`, `M/MOD`, and bare `UM/MOD` user invocations.
- A new test file `tests/throw_migration_tests.fth` populated with Sections 1 + 2.
- ~22-28 new Makefile REPL tests (PASS 696..~720+).

What this story explicitly does **not** land:
- Migration of any compiler / dictionary / control-flow ABORT site (Story 11.5 owns: `'`, `:`, `;`, `CREATE`, `CONSTANT`, `DOES>`, `?COMP`, `INTERPRET`, `MARKER`, the assembler-error fan-in).
- Migration of any string / I-O ABORT site (Story 11.6 owns: `(` missing-`)`, pictured-buffer overflow).
- Retarget of `ABORT` / `ABORT"` themselves (Story 11.7 owns).
- Description-table edits in `throw_desc_table` (Story 11.3 pre-seeded `-4 stack underflow` and `-10 division by zero` for exactly this consumption — no edits needed here).
- New THROW codes or EQU declarations (Story 11.1 pre-declared `THROW_STACK_UNDERFLOW EQU -4` and `THROW_DIV_BY_ZERO EQU -10` for this story to consume).
- Touch of `sdivmod` (no edit needed: 0 NEGATE = 0, so an entry-time BC=0 reaches `udivmod` unchanged and trips the new guard there).

### Architecture references

- **CCD-1 — Return-stack frame taxonomy + dual-chain discipline:** `architecture.md:168-191`. The exception frame's saved-SP slot is what makes the kernel-internal-entry contract work — on the caught path, `LD SP, HL` from frame +0 wholesale resets SP regardless of how degenerate it was on entry.
- **CCD-2 — THROW code allocation policy:** `architecture.md:193-204`. `-4` and `-10` are both ANS Forth 1994 §9.3.5 codes; the citation form is `; ANS Forth 1994 §9.3.5` per CCD-3 and per the `src/constants.asm` reconciliation note.
- **CCD-3 — Standards-citation discipline:** `architecture.md:206-216`. Inline comments at the migrated sites carry the citation per AC #14.
- **E11-D2 — CATCH/THROW mechanism:** `architecture.md:289-300`. The 7-step caught-path algorithm (Story 11.3 implemented) is what the kernel-internal entry feeds into — only the `check_underflow` guard is bypassed; everything from the n=0 short-circuit onwards behaves identically for kernel-side raises.
- **E11-D3 — Internal error migration strategy:** `architecture.md:302-306`. Word-by-word, one commit per migration, REPL test per migration. Story 11.4 is the *first* story in this crawl. ABORT/ABORT" retargeted last (Story 11.7) so legacy callers don't double-throw during the transition.
- **THROW EQU naming pattern:** `architecture.md:471-479`. `THROW_<UPPER_SNAKE>` symbols, citation comment alongside. Story 11.1 declared the EQUs; Story 11.4 first-consumes them.
- **Source-file organisation:** `architecture.md:434-447`. Story 11.4 edits `src/exception.asm` (kernel-entry label), `src/system.asm` (`do_underflow_error`), `src/antforth.asm` (`str_underflow` removal), `src/arithmetic.asm` (`udivmod` guard), `src/double.asm` (`UM/MOD` guard). The double.asm touch is authorised by the architectural reservation comment at `src/double.asm:560-563`.
- **Stack-effect comments:** `architecture.md:481-488`. Modified words retain their existing `( inputs -- outputs )` stack-effect comments; no edits to those.

### Constraints and conventions

- **Standards-compliance discipline** (`feedback_standards_compliance.md`): `-4` and `-10` are ANS Forth 1994 §9.3.5 codes; the citation form is the project-wide `ANS Forth 1994 §9.3.5` reconciled in Story 11.1 (`docs/throw-codes.md:31-40`).
- **Plain QA language** (`feedback_plain_qa_language.md`): Completion Notes use Story 11.3's verdict-table format. State the value, the gate, the reason — plainly.
- **Design upfront** (`feedback_design_upfront.md`): the kernel-internal-entry label is designed for *all* future Story-11.5 / 11.6 migrations to reuse — same single label, same single-instruction-prelude calling convention. Stories 11.5 / 11.6 do not need to add a second internal entry; they consume this one.
- **TOS-in-register / DEPTH discipline** (`project_tos_in_register.md`): on the caught path, `BC = -4` (or `-10`) is a *real* TOS post-restore (Story 11.3 AC #8). DEPTH = `pre-CATCH-DEPTH + 1`. Tests verify this for both stack underflow (AC #11) and divisor zero (AC #12).
- **REPL tests preferred** (`feedback_repl_tests_preferred.md`): all Story 11.4 tests are REPL-piped Forth lines in `tests/throw_migration_tests.fth` Sections 1-2, with corresponding Makefile entries 696..~720+. **No new assembly test threads.**
- **Adversarial review** (`feedback_adversarial_review.md`): expect ≥2-3 HIGH/MEDIUM findings per AC #18.
- **Follow the process** (`feedback_follow_process.md`): Tasks 1-11 form the standard create-story → dev-story → code-review → finalize workflow. Don't ask permission for the next sub-task; just execute.

### Key implementation pitfalls

1. **The kernel-internal entry MUST skip only `check_underflow`, nothing else.** A future edit that inserts code between `CALL check_underflow` and the n=0 short-circuit (`LD A, B / OR C`) would silently break this story's contract — kernel-side raises would skip whatever's inserted. The fix is *always* to put the new code *after* the `.kernel_entry:` label, not before. Document this expectation in the comment block above the label (Task 2.2).

2. **`do_underflow_error` does NOT need to reset SP before `JP w_THROW_cf.kernel_entry`.** The reasons are AC #15: on the caught path, `LD SP, HL` from the catch frame +0 wholesale resets SP; on the uncaught path, `JP w_ABORT_cf` resets SP. The "Uses direct BDOS because SP may be corrupt" comment at the old site (`src/system.asm:548-549`) is a historical artifact of the now-deleted print sequence — the new path neither reads nor writes SP-relative values until the downstream restore.

3. **`udivmod` is reached via two paths**: (a) `sdivmod` calls it after sign-fixup; (b) no other direct caller in the kernel (verify with `grep -nE 'CALL\s+udivmod' src/`). For path (a), the `sdivmod` sign-fixup logic at `src/arithmetic.asm:150-212` does `BIT 7, B / JR Z` to detect a negative divisor — for `BC = 0`, `BIT 7` of `0` is `0`, the JR Z is taken, no negate happens, and `BC = 0` reaches `udivmod` unchanged. The new guard at `udivmod` then trips. So **no edit to `sdivmod` is needed**. Verify this trace at write time.

4. **`UM/MOD`'s divisor at `CALL check_underflow_3` exit is the single-cell `n`** (per `( ud n -- urem uquot )`). BC = TOS = n at entry. `check_underflow_3` doesn't touch BC. So the guard `LD A, B / OR C / JR NZ` correctly tests the divisor.

5. **`BC = 0x8000` (most-negative signed) is not zero.** The divisor-zero guard tests `B == 0 AND C == 0`, not "BC < 0". `0x8000` has `B = 0x80, C = 0x00` — `OR C` of `0x80` is non-zero, the guard does not trip. `0x8000` divisor proceeds into `udivmod` / `UM/MOD` and produces an unsigned-division result per the existing semantics (sdivmod will sign-fixup). No edge case here. Test discipline: include a `1 0x8000 /` (or `1 -32768 /`) test in Section 2 as a positive control if time permits — verifies the guard doesn't false-trip on the most-negative case.

6. **`str_underflow` removal must be complete.** `grep -nE 'str_underflow|STR_UNDERFLOW_LEN' src/*.asm` returns zero hits post-edit (Task 6.4 / 9.6). If the assembler accepts an undeclared label silently (it doesn't, but verify), the build would fail with "undefined symbol str_underflow" — this is the correct fail mode and confirms the removal worked.

7. **Test discipline for caught THROW with positive control.** Every "caught error throws -N" test should have a "caught no-error throws 0" sibling — confirms the migration didn't accidentally make the success path always throw. Examples: `5 ' DROP CATCH .` → `0  ok`; `: P1 100 5 / ; ' P1 CATCH . .` → `0 20  ok`. AC #9 includes both as required test cases.

8. **`'` (tick) parses at execution time in antforth** — the same caveat as Stories 11.2 / 11.3 (see `tests/exception_tests.fth:13-15`). Inside colon definitions, use `[']` (IMMEDIATE). All Story 11.4 tests follow this convention.

9. **Recovery-test diagnostic-format dependence on Story 11.3.** The "uncaught underflow → `error -4: stack underflow`" assertion (AC #9 last sub-bullet) depends on Story 11.3's `throw_desc_table` having seeded `-4 stack underflow`. If a future edit removes that entry, Story 11.4's recovery test fails. Document this dependency in the test file's section header.

10. **Post-Story-11.7 forward compatibility.** When Story 11.7 retargets `w_ABORT_cf` itself to `-1 THROW`, the uncaught path of Story 11.4's THROWs (which currently flows `JP w_THROW_cf → uncaught path → JP w_ABORT_cf → ABORT body → REPL recovery`) becomes `JP w_THROW_cf → uncaught path → JP w_ABORT_cf → -1 THROW → uncaught path → ...`. To prevent infinite recursion, Story 11.7 must restructure the uncaught-recovery chain (likely by inlining the asm_cleanup + SP/IX reset + QUIT entry in the uncaught handler instead of routing through `w_ABORT_cf`). **This is Story 11.7's problem, not Story 11.4's** — call it out for the Story 11.7 dev to read this story's notes.

### Test discipline

- Tests live in `tests/throw_migration_tests.fth` (new file, this story creates it). Stories 11.5 / 11.6 / 11.7 will append further sections — Section 3, 4, 5 respectively.
- Counterpart `printf | $(IZCPM)` blocks land in `Makefile` starting at PASS test 696.
- For caught-THROW tests: assert the THROW code appears as the result of `' WORD CATCH .` and (for sub-tests with i\*x preservation) that pre-CATCH cells appear underneath.
- For divisor-zero tests: wrap the failing word in a `: TN ... ;` definition since the divisor argument is part of the failing word's body, not a REPL-typed pre-arg.
- For uncaught-recovery tests: use the multi-line `printf` + `tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'` pattern from Story 11.3 test 691.
- For DEPTH-invariant tests (AC #11, #12): use the `' T CATCH DEPTH .` form — `DEPTH` itself doesn't grow the depth at the time of read since `DEPTH` *pushes* the depth.

### Project Structure Notes

- **Edits:**
  - `src/exception.asm` — add `.kernel_entry:` label inside `w_THROW_cf` plus comment block. (Estimated growth: ~15 source lines, 0 binary bytes — labels are zero-cost.)
  - `src/system.asm` — collapse `do_underflow_error` body from print-sequence + `JP w_ABORT_cf` to `LD BC / JP`. (Estimated: -12 binary bytes; -8 source lines.)
  - `src/antforth.asm` — delete `str_underflow:` and `STR_UNDERFLOW_LEN` lines (`:221-222`). (Estimated: -19 binary bytes — 17-byte string + 2-byte length-prefix.)
  - `src/arithmetic.asm` — add divisor-zero guard at top of `udivmod`. (Estimated: +9 binary bytes; +8 source lines.)
  - `src/double.asm` — add divisor-zero guard at top of `w_U_M_SLASH_MOD_cf` body; update comment block. (Estimated: +9 binary bytes; +8 source lines.)
  - `tests/throw_migration_tests.fth` — *new file* with header + Sections 1 + 2. (Estimated: ~50-80 lines.)
  - `Makefile` — append PASS test blocks 696..~720+ for new scenarios. (Estimated: ~140-200 new lines.)
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` — `11-4-…` entry: `backlog` → `ready-for-dev`.
  - `_bmad-output/implementation-artifacts/11-4-internal-error-migration-stack-arithmetic-memory-primitives.md` — this file (Status, task checkboxes, Completion Notes, File List, Change Log on dev pass).
- **New file:** `tests/throw_migration_tests.fth` (architecture-mandated by `architecture.md:773` Epic 11 row "Primary touch: ... `tests/{exception,throw_migration}_tests.fth`"). No collision with existing `tests/` files (verified — `tests/` listing has 6 files, none named `throw_migration_tests.fth` pre-edit).
- File-list expectation in Dev Agent Record: 5 modified `*.asm` files + 1 new `*.fth` file + Makefile + sprint-status + this story file.

### Previous-story intelligence (Story 11.3 patterns to reuse and pitfalls to avoid)

**Reuse:**
- *Verdict-table Completion Notes* (Story 11.3): one row per AC, columns `Gate text | Evidence | Verdict`. Mirror exactly.
- *Per-task evidence sections with explicit grep / wc commands*: "ran command X, got output Y, here's the implication" — no hand-waving.
- *Re-grep before publishing*: every line number cited in Dev Notes (e.g., `src/system.asm:551-559`) re-verified at dev-pass time.
- *Adversarial-review-finding triage table*: Story 11.3's review log format (ID / Severity / Category / Description / Resolution columns) replicated in Completion Notes.
- *Binary-size delta table*: Stage / bytes / delta, mirroring Story 11.3 Completion Notes.
- *EXX-hygiene caller-contract awareness*: Story 11.3's R-L5 finding added an EXX-hygiene paragraph to the THROW header. Story 11.4's kernel-internal callers (`do_underflow_error`, `udivmod`-guard, `UM/MOD`-guard) all run from primary-set context — none has executed an EXX. The EXX contract is naturally satisfied. Document this in the kernel-entry comment block (Task 2.2) for completeness.

**Pitfalls Story 11.3's review surfaced (avoid in 11.4):**
- *F1: framing about post-NEXT staleness was misleading* — write comments about register / stack state in terms of the actual TOS-in-register convention, not legacy "POP BC consumed the xt cell" framing.
- *F2: missing edge-case test for BC = 0x8000* — Story 11.4's divisor-zero test should include a positive-control `1 -32768 /` (verifies the guard doesn't false-trip on most-negative). Story 11.4 watch-list pitfall #5 covers this.
- *F3: missing tests for non-colon IX frames (DO-LOOP, EXECUTE)* — Story 11.4 should include at least one test where the underflow / divisor-zero fires from inside a DO-LOOP or after an EXECUTE indirection. Sample: `: T 5 0 DO -4 THROW LOOP ; ' T CATCH .` would test THROW from within DO-LOOP, but for *underflow specifically* a more natural case is `: T 0 0 DO DROP LOOP ; 1 ' T CATCH .` — DROP from depth 1 inside the loop body, with the LOOP frame on IX. Add this if time permits.
- *R-L1: cross-story architecture-wording mismatch* — Story 11.4 doesn't edit `architecture.md`, so this pitfall doesn't apply directly. But if any architecture line cited in this story file (e.g., `architecture.md:302-306`) drifts at dev-pass time, reconcile.
- *R-L2: prefer JR Z over JP Z when in range* — The new branches in Tasks 4-5 (`JR NZ, .udiv_proceed`, `JR NZ, .ummod_proceed`) are within JR range by inspection. Use `JR` for the conditional branches and `JP` only for the unconditional far-jump to `w_THROW_cf.kernel_entry`.
- *R-L4: tighten grep patterns* — When asserting `error -4` (AC #9 uncaught-recovery test), pattern should be `error -4: stack underflow  ` (with trailing whitespace marker matching Story 11.3 test 685's pattern) so a regression that drops the description suffix would FAIL.

### Comparison to Story 11.3's adversarial review F-findings (Story 11.4 watch-list)

Story 11.3's review found 7 issues (0 HIGH, 3 MEDIUM, 4 LOW) plus a second-pass review with 1 MEDIUM, 5 LOW. Story 11.4 deliberately watches for these analogous issues:
- **Kernel-internal-entry label semantics under future edits** (analog of F1 framing-was-misleading): write the comment block above `.kernel_entry:` to describe *both* what the label is for and what the future-edit expectation is (Task 2.2 mandates this).
- **Divisor-zero edge cases** (analog of F2 missing-edge-case): test BC = 0x8000 as a positive control; test BC = 0 trips for every divider word.
- **Test coverage gaps** (analog of F3): include a DO-LOOP-frame underflow test and an EXECUTE-frame divisor-zero test.
- **Citation form drift** (analog of F2): every new inline comment uses `ANS Forth 1994 §9.3.5` per the project-wide convention.
- **Lax test ordering for uncaught recovery** (analog of F5 / R-L4): ordered `tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'` patterns.
- **First/second-use docs for new instruction patterns** (analog of F7): no new instruction patterns this story (the `JP <local-label>` pattern is already used at multiple sites in `src/system.asm`'s underflow-fan-in).
- **Story-vs-code disclosure of deviations** (analog of R-M1): if dev-pass cross-references a description string against the standard at write time and finds a discrepancy, document it explicitly in Completion Notes (analogous to Story 11.3's Note A).

### References

- `_bmad-output/planning-artifacts/epics.md:781-807` — Story 11.4 acceptance criteria source.
- `_bmad-output/planning-artifacts/architecture.md:168-191` — CCD-1 dual-chain discipline.
- `_bmad-output/planning-artifacts/architecture.md:193-204` — CCD-2 THROW code allocation policy.
- `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 standards-citation discipline.
- `_bmad-output/planning-artifacts/architecture.md:289-300` — E11-D2 CATCH/THROW mechanism.
- `_bmad-output/planning-artifacts/architecture.md:302-306` — E11-D3 internal error migration strategy (this story is the first migration in the crawl).
- `_bmad-output/planning-artifacts/architecture.md:471-479` — THROW EQU naming + citation pattern.
- `_bmad-output/planning-artifacts/architecture.md:773` — Epic 11 file-touch table (ratifies `tests/throw_migration_tests.fth` as architecture-mandated).
- `_bmad-output/planning-artifacts/prd.md:392-402` — FR15-FR22 (Epic 11 functional requirements; FR19 = "internal errors raise THROW codes" — Story 11.4 delivers a partial slice).
- `_bmad-output/planning-artifacts/prd.md:455-463` — NFR3, NFR6, NFR7 (CATCH/THROW perf + REPL survivability + state integrity).
- `docs/throw-codes.md` — Story 11.1 inventory; §d row `system.asm:559` migrates here, §e migration-ordering proposal Stage 11.4.
- `docs/throw-codes.md:296-299` — future-add row for `arithmetic.asm:~115` divisor-zero guard (this story implements it, plus the parallel UM/MOD guard).
- `_bmad-output/implementation-artifacts/11-1-abort-site-migration-inventory-throw-code-table-and-code-equs.md` — Story 11.1's verdict-table format and EQU declarations consumed here.
- `_bmad-output/implementation-artifacts/11-2-exception-frame-infrastructure-and-catch-word.md` — Story 11.2's CATCH frame layout (Story 11.4 consumes via the kernel-internal entry).
- `_bmad-output/implementation-artifacts/11-3-throw-word-and-uncaught-throw-repl-handler.md` — Story 11.3's THROW word + uncaught-handler (Story 11.4 calls into this via `w_THROW_cf.kernel_entry`); review log + verdict-table format reused here.
- `src/exception.asm:153-260` — Story 11.3's THROW implementation (the entry point Story 11.4 inserts the kernel label inside).
- `src/system.asm:447-559` — `check_underflow{,_2,_3,_4}` + `do_underflow_error`. Story 11.4 migrates `do_underflow_error`; the four `check_underflow*` subroutines are unchanged (their `JP do_underflow_error` survives, since the migration target is `do_underflow_error` itself).
- `src/antforth.asm:221-222` — `str_underflow` declaration. Deleted by Story 11.4.
- `src/arithmetic.asm:108-136` — `udivmod` (Story 11.4 adds divisor-zero guard at top).
- `src/arithmetic.asm:138-212` — `sdivmod` (no edit; passes BC=0 through unchanged).
- `src/double.asm:558-600` — `UM/MOD` (Story 11.4 adds divisor-zero guard immediately after `CALL check_underflow_3`).
- `src/double.asm:602-718` — `SM/REM`, `FM/MOD` (no edit; both decompose to `UM/MOD` and inherit the guard).
- `src/constants.asm:59-60` — `THROW_STACK_UNDERFLOW EQU -4`, `THROW_DIV_BY_ZERO EQU -10` (declared by Story 11.1; first-consumed here).
- `tests/exception_tests.fth` — Story 11.2 / 11.3 test conventions (per-line `\ expect: <fragment>`, multi-line printf for uncaught-recovery).
- `Makefile:5984-6021` — Story 11.3 final test blocks (PASS 691-695). New blocks append after.
- DPANS94 §9.3.5 / Forth 2014 §9.3.5 — `THROW` code table (`-4 stack underflow`, `-10 division by zero`).

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

- Pre-edit baseline: `wc -c build/antforth.com` = 17378 bytes (post-Story 11.3 final).
- Post-Task-3 (`do_underflow_error` migration + `str_underflow` removal): 17353 bytes (-25). Removed 31 bytes (4-instruction print + 17-byte string + 3-byte `JP`); added 6 bytes (`LD BC, n / JP w_THROW_cf.kernel_entry`).
- Post-Task-4 (`udivmod` guard): 17363 bytes (+10). Guard = `LD A,B` (1) + `OR C` (1) + `JR NZ,…` (2) + `LD BC,n` (3) + `JP w_THROW_cf.kernel_entry` (3).
- Post-Task-5 (`UM/MOD` guard): 17373 bytes (+10).
- Post-Task-10 (review fixes — comments only): 17373 bytes (no delta).
- Final: **17373 bytes; net -5 from 17378**, well within AC #10 estimate (-7 to +5).
- ABORT-instruction count: pre-edit 18 actual `JP w_ABORT_cf` / `DW w_ABORT_cf`; post-edit **17** (the dropped row is `src/system.asm:559`). Matches AC #13. Note: the same grep also matches 5 prose-comment lines (`arithmetic.asm:122`, `exception.asm:215`, `exception.asm:332`, `exception.asm:502`, `system.asm:547` — count grew from 2 to 5 as Story 11.4 added explanatory comments referencing `JP w_ABORT_cf`); these are documentation matches, not real instructions, and are excluded from the 17 count.
- `str_underflow` / `STR_UNDERFLOW_LEN` references post-edit: **0** (Task 6.4 / 9.6).
- M/MOD existence check: `grep -nE 'DEFCODE\s+"M/MOD"|DEFWORD\s+"M/MOD"' src/*.asm` → no matches (review F3 evidence).
- Test counts: pre-edit 704 PASS / 0 FAIL (Story 11.3 baseline). Post-Story-11.4: **726 PASS / 0 FAIL** (+22 new entries 696..717; 2 pre-existing tests 651/652 repurposed in-place).

### Completion Notes List

#### AC verdict table (per `feedback_plain_qa_language.md` / Story 11.3 format)

| AC | Gate | Evidence | Verdict |
|----|------|----------|---------|
| #1 | `do_underflow_error` no longer ends in `JP w_ABORT_cf`; raises `-4 THROW` via kernel_entry | `src/system.asm:561-563` body now is `LD BC, THROW_STACK_UNDERFLOW / JP w_THROW_cf.kernel_entry`; all 49 `check_underflow{,_2,_3,_4}` callers transitively raise `-4` | **PASS** |
| #2 | `.kernel_entry:` label inserted between `CALL check_underflow` and the n=0 short-circuit | `src/exception.asm:225` (label); `:201-224` documents contract | **PASS** |
| #3 | `do_underflow_error` print sequence + `JP w_ABORT_cf` deleted; `str_underflow` / `STR_UNDERFLOW_LEN` deleted | `src/system.asm:561-563` (2 instructions remain); `src/antforth.asm` no longer declares the strings; `grep` returns 0 | **PASS** |
| #4 | `udivmod` divisor-zero guard at entry → `-10 THROW` | `src/arithmetic.asm:121-127` (guard before `LD DE, 0`); REPL test 705 (`/`), 706 (`MOD`), 707 (`/MOD`) | **PASS** |
| #5 | `UM/MOD` divisor-zero guard immediately after `CALL check_underflow_3` | `src/double.asm:570-577`; REPL tests 708 (`*/`), 709 (`*/MOD`), 711 (`UM/MOD`), 712 (`SM/REM`), 713 (`FM/MOD`); M/MOD omitted (not a kernel primitive) | **PASS** |
| #6 | Uncaught `-4` / `-10` produces `error -<N>: <desc>` via Story 11.3's `print_throw_description` | REPL tests 716 (`error -4: stack underflow.*42  ok`) and 717 (`error -10: division by zero.*99  ok`) | **PASS** |
| #7 | `tests/throw_migration_tests.fth` created | New file with header + Section 1 + Section 2 | **PASS** |
| #8 | `\ expect: <fragment>` per-line convention; Makefile blocks at 696..717 | File header documents convention; 22 new tests appended | **PASS** |
| #9 | Caught-THROW round-trip tests for stack underflow + divisor zero across categories | REPL tests 696..717; covers DROP/+/@/!/ROT/2SWAP underflow, /-MOD-/MOD-*/-*/MOD-UM/MOD-SM/REM-FM/MOD div-zero, plus DO-LOOP-frame underflow (704) and most-negative divisor (715). Spec-mandated `1 2 3 ' DROP CATCH . . . .` form delivered (with substitute xt; AC's literal DROP does not underflow with 3 i\*x cells — see 11-4-1 Completion Notes "AC trace correction") via REPL tests 718..724 (i\*x preservation tests added by Story 11.4.1). | **PASS** (i\*x preservation sub-claim closed by Story 11.4.1 — see 11-4-1-catch-throw-ix-preservation-bug-fix.md) |
| #10 | Binary delta within ±20 bytes | -5 bytes (17378 → 17373) | **PASS** |
| #11 | Caught underflow: BC = -4 is real TOS; `DEPTH` reports `pre-CATCH-DEPTH + 1` | REPL test 703 (`' DROP CATCH DEPTH .` → `1`); Story 11.4.1 adds REPL test 720 (`1 2 3 ' 2OVER CATCH . DEPTH .` → `-4 3  ok` — the AC's spec form with 2OVER substituted for DROP since DROP doesn't underflow with 3 i\*x cells; combined value+depth assertion per 11-4-1 review F6; see 11-4-1 Completion Notes "AC trace correction") | **PASS** (closed by Story 11.4.1) |
| #12 | Caught divisor zero: same DEPTH invariant | REPL test 714 (`' TD CATCH DEPTH .` → `1`); Story 11.4.1 adds REPL test 722 (`5 6 7 ' T241 CATCH . DEPTH .` → `-10 3  ok` — combined value+depth assertion per 11-4-1 review F6) | **PASS** (closed by Story 11.4.1) |
| #13 | Post-migration ABORT-site count = 17 | `grep -nE 'JP\s+w_ABORT_cf\|DW\s+w_ABORT_cf'` returns 17 actual instructions (was 18; `src/system.asm:559` dropped) | **PASS** |
| #14 | Inline citation comments at each migration site (`ANS Forth 1994 §9.3.5`) | `src/system.asm:560` (`-4 THROW`), `src/arithmetic.asm:127` (`-10 THROW`), `src/double.asm:574` (`-10 THROW`); `src/exception.asm:201-237` kernel-entry header block | **PASS** |
| #15 | SP-may-be-corrupt invariant preserved on the new path | Documented inline at `src/exception.asm:213-216`; verified empirically by REPL tests 716/717 (uncaught path resets SP via `JP w_ABORT_cf`) and 696..715 (caught path resets via `LD SP, HL`) | **PASS** |
| #16 | Kernel callers pass through the `INCLUDE-TOP` placeholder unchanged | `.kernel_entry:` precedes the placeholder section (`src/exception.asm:225` is before the placeholder block); no edit needed | **PASS** |
| #17 | EQU symbols `THROW_STACK_UNDERFLOW`, `THROW_DIV_BY_ZERO` consumed (not bare literals) | `src/system.asm:562` (`LD BC, THROW_STACK_UNDERFLOW`); `src/arithmetic.asm:125`, `src/double.asm:575` (`LD BC, THROW_DIV_BY_ZERO`) | **PASS** |
| #18 | Adversarial review finds ≥2-3 HIGH/MEDIUM findings | 8 findings (2 HIGH, 4 MEDIUM, 2 LOW) — see review-log table below | **PASS** |
| #19 | Verdict-table format per Story 11.3 | This table | **PASS** |
| #20 | `make` + `make test` + `make test-repl` clean; pre-existing 704 still pass; ~24-30 new added | 0 errors, 0 warnings; `make test` PASS; `make test-repl` 726 PASS / 0 FAIL (704 pre + 22 new); pre-existing tests asserting old `? Stack underflow` updated to assert `error -4: stack underflow` | **PASS (with diff scope expanded — see Note B)** |

#### Note A (AC #9 i\*x preservation deviation; AC #11/#12 partial)

The AC #9 / AC #11 / AC #12 forms `1 2 3 ' DROP CATCH . . . .` → `-4 3 2 1` and `1 2 3 ' DROP CATCH DEPTH .` → `4` were omitted from the test suite. **Underlying defect (pre-existing, not introduced by Story 11.4):** the Story 11.2 / 11.3 CATCH/THROW design captures saved-SP at CATCH entry (before its `POP BC`), so the cell at `[saved-SP]` was the i\*x's TOS-cell. When the inner xt later does any `CALL` (e.g., `check_underflow`) that uses `[saved-SP]` as the temporary scratch slot for its return address, the i\*x cell is overwritten. On the THROW caught path, `LD SP, HL` restores SP to saved-SP — but `[SP]` now contains a stale return-address byte, not the user's i\*x cell.

Empirical evidence (post-Story-11.4 build):
- `1 ' + CATCH . .` → `-4 1483  ok` (the `1` is gone; `1483` is a code-side return address).
- `1 ' DROP CATCH . .` → `0 error -4: stack underflow` (the second `.` underflows because the i\*x cell was clobbered AND the CATCH normal-return path's `PUSH BC` saved garbage where `1` should have been).

The AC author drafted these tests assuming the design preserved i\*x correctly. It does not. This is an architectural defect at the CATCH frame layout level (Story 11.2 / 11.3), not a Story 11.4 regression. Story 11.4's ACs that depend on this guarantee are partially deferred. **Forward action (completed in code-review pass):** known-defect comment block added at `sprint-status.yaml:134-143`; dedicated bug story `11-4-1-catch-throw-ix-preservation-bug-fix` added at `sprint-status.yaml:152` (status `backlog`) with a hard ordering constraint to land before Story 11.7's ABORT-retarget (which materially expands the kernel-internal-source-THROW caller set and amplifies the user-visible impact). **Closed 2026-04-26 by Story 11.4.1 landing — see that story's Completion Notes for the redesign details (CATCH frame +2 slot repurposed from "saved IX" (dead) to "saved BC" (i\*x's TOS-cell value), THROW caught path restores it via PUSH BC after LD SP, HL). Post-fix verification: `1 ' + CATCH . .` → `-4 1  ok`; `1 2 3 ' 2OVER CATCH . . . .` → `-4 3 2 1  ok`; `1 2 3 ' 2OVER CATCH DEPTH .` → `4  ok`; `5 6 7 ' T241 CATCH DEPTH .` → `4  ok`. AC verdict-table flipped from PARTIAL to PASS for ACs #9 / #11 / #12.**

Tests retained from AC #9 / #11 / #12 use empty pre-CATCH stacks, so there is no i\*x cell to preserve and the THROW code is the sole TOS — these forms work correctly. The AC verdict-table marks #9 / #11 / #12 as PARTIAL: the spirit of each AC (caught-THROW round-trip with diagnostic on uncaught) is fully satisfied for the migrated primitives, but the i\*x preservation sub-claim spelt out in the AC text is deferred to Story 11.4.1.

#### Note B (regression-scope expansion: pre-existing test diagnostic-format updates)

AC #20 anticipated that "the existing 704 prior tests must continue PASS — particularly the Story 11.3 uncaught-THROW tests at 685-693". A larger pre-existing test set asserts the *old* `? Stack underflow` diagnostic literal (Makefile entries 411..448 and adjacent). Because Story 11.4 retires that literal in favour of `error -4: stack underflow`, those assertions had to be updated to the new format in-pass — 122 substring replacements via `sed`. Two specific tests (651, 652) had been authored as "Story 10.9 review follow-up: silent-divide-by-zero baseline" with comments anticipating "Story 11.6 will migrate to THROW -10"; they were repurposed in this story to assert the post-migration `error -10: division by zero` form (since the migration actually lands here via the UM/MOD guard, not in 11.6). All 704 prior tests still PASS post-update.

#### Adversarial review log (Task 10)

| ID | Severity | Category | Description | Resolution |
|----|----------|----------|-------------|------------|
| F1 | HIGH | AC deviation / test gap | Spec AC #9 / #11 i\*x preservation tests omitted | **Documented as Note A above; tests retain reduced empty-pre-CATCH form. Underlying pre-existing CATCH defect flagged for follow-up story.** |
| F2 | HIGH | Future-edit hazard at `.kernel_entry` | n=0 path's `POP BC` would corrupt SP for kernel callers passing `BC=0` | **Fixed in-pass: extended comment block at `src/exception.asm:208-237` adds FUTURE-EDIT NOTE 2 calling out the `BC must be non-zero` invariant.** |
| F3 | MEDIUM | M/MOD evidence trail | No grep recorded confirming M/MOD absence | **Fixed in-pass: grep evidence recorded in Debug Log References above.** |
| F4 | MEDIUM | Standards-citation inconsistency (claimed duplication) | Reviewer asserted citation appears in both docstring and inline | **Reviewed: false positive — docstring describes behaviour ("BC=0 raises -10 THROW"); inline carries the standards citation (`ANS Forth 1994 §9.3.5`). No duplication.** Closed as INVALID. |
| F5 | MEDIUM | Brittle literal-string assertions in Makefile | Diagnostic format changes require N-place edits | **Deferred with rationale: centralising into a Makefile variable is a separate test-infrastructure refactor; the literal-string approach matches the rest of the test suite's convention. Cost/benefit doesn't justify in-story.** |
| F6 | MEDIUM | sdivmod `PUSH AF` stack-leak across THROW edge | Stranded byte if SP-reset path ever changes | **Fixed in-pass: comment added at `src/arithmetic.asm:118-123` documenting the leak and the wholesale-reset assumption.** |
| F7 | LOW | EXX-not-active claim wording | Reads as permanent invariant; is per-caller obligation | **Fixed in-pass: comment reworded at `src/exception.asm:217-221`.** |
| F8 | LOW | Story-spec inconsistency (AC #11 expectation) | Bundled with F1 | **Closed with F1.** |
| R-H1 | HIGH | Verdict-table accuracy + missing follow-up story | Code-review pass: AC #9 was labelled "PASS with deviation" but the spec-mandated `1 2 3 ' DROP CATCH . . . .` form does not work; no concrete follow-up story existed for the underlying CATCH frame defect | **Fixed in-pass: AC #9 re-labelled PARTIAL; new sprint-status row `11-4-1-catch-throw-ix-preservation-bug-fix: backlog` added at `sprint-status.yaml:152` with hard ordering constraint to land before Story 11.7.** |
| R-M1 | MEDIUM | Stale `check_underflow*` headers | Headers at `src/system.asm:454,:480,:504,:528` still described the `? Stack underflow` + ABORT pre-migration behaviour | **Fixed in-pass: each header updated to reference `do_underflow_error → -4 THROW via w_THROW_cf.kernel_entry`.** |
| R-M2 | MEDIUM | Stale `\ expect: ? Stack underflow` reference comments | 58 occurrences across `tests/double_tests.fth` (34), `tests/core_gap_tests.fth` (16), `tests/exception_tests.fth` (2), `tests/pictured_tests.fth` (6) describing the pre-migration diagnostic | **Fixed in-pass: all 58 occurrences replaced with `error -4: stack underflow`; `core_gap_tests.fth` div-by-zero baseline updated to assert `error -10: division by zero` (was "silent; garbage cell").** |
| R-M3 | MEDIUM | `docs/throw-codes.md` not updated | Lines 73, 79, 290, 292-299, 326 still tagged Story 11.4 sites as "future-add" / "Story 11.4 will add a `BC ≠ 0` guard" | **Fixed in-pass: lines updated to "done — Story 11.4"; future-add subsection retitled and repurposed as "Divisor-zero guards added by Story 11.4"; inventory totals updated to 17 ABORT + 1 entry + 2 divisor-zero guards = 20 rows.** |
| R-M4 | MEDIUM | Comment overclaim at `src/double.asm:563` | Listed `M/MOD` among words covered by the UM/MOD guard; M/MOD is not a kernel primitive (per F3 evidence) | **Fixed in-pass: M/MOD removed from the coverage list with an inline note pointing back to F3.** |
| R-M5 | MEDIUM | Debug Log inaccuracy | Said "excluding 2 prose-comment matches at `src/exception.asm:296,466`"; actual count is 5 (Story 11.4 itself added several explanatory comments referencing `JP w_ABORT_cf`) | **Fixed in-pass: Debug Log row corrected to enumerate all 5 prose-comment lines.** |
| R-L1 | LOW | Test 715 chooses an uninformative result | `1 -32768 /` quotient happens to be `0`, which can read as a CATCH success code | **Deferred with rationale: the test's purpose is to verify the guard does not false-trip on B=0x80, which it does correctly. Result clarity is a presentation concern, not a correctness concern. Net cost of editing the test exceeds the benefit; flagged for any future test-suite refresh.** |
| R-L2 | LOW | F6 leak note covered only sdivmod's `PUSH AF` | Caller-side `PUSH DE` (IP-stash) at `w_SLASH_cf:265`, `w_MOD_cf:281`, `w_SLASH_MOD_cf:243` is also stranded when udivmod's guard fires | **Fixed in-pass: `udivmod` header note extended to enumerate the caller-side leak alongside sdivmod's, citing the same wholesale-reset rationale.** |

#### Behavioural summary

- 49 underflow-detecting `CALL check_underflow{,_2,_3,_4}` sites across 11 source files now raise `-4 THROW` instead of printing `? Stack underflow` and aborting.
- Single-cell divides `/`, `MOD`, `/MOD`, `*/`, `*/MOD` and double-cell divides `UM/MOD`, `SM/REM`, `FM/MOD` raise `-10 THROW` on a zero divisor (previously: silent `-1` per existing comment, or silent garbage).
- Uncaught path produces the Story 11.3 diagnostic format `error -<N>: <desc>` with a clean REPL prompt thereafter.
- Caught path lands the THROW code on the user data stack as the new TOS; CATCH returns it for programmatic handling.
- Binary delta: 17378 → 17373 = **-5 bytes**.
- Test-suite delta: 704 → 726 = **+22 PASS**, **0 FAIL**.

### File List

Modified:
- `src/exception.asm` — added `.kernel_entry:` local label inside `w_THROW_cf` plus contract comment block (no binary change; review F2/F7 fixes added more comment lines).
- `src/system.asm` — `do_underflow_error` body collapsed to `LD BC, THROW_STACK_UNDERFLOW / JP w_THROW_cf.kernel_entry`; header comment updated. Code-review pass R-M1: `check_underflow{,_2,_3,_4}` header comments updated to reflect post-migration `-4 THROW` behaviour.
- `src/antforth.asm` — deleted `str_underflow:` and `STR_UNDERFLOW_LEN` declarations.
- `src/arithmetic.asm` — added divisor-zero guard at `udivmod` entry; updated header comment (review F6 + code-review L2 note appended for caller-side `PUSH DE` leak).
- `src/double.asm` — added divisor-zero guard immediately after `CALL check_underflow_3` in `w_U_M_SLASH_MOD_cf`; updated `:558-563` comment to record the migration. Code-review pass R-M4: M/MOD removed from coverage list.
- `Makefile` — appended Story 11.4 PASS test blocks 696..717 (22 entries); updated 122 pre-existing `'? Stack underflow'` assertion strings to `'error -4: stack underflow'`; repurposed tests 651/652 to assert `-10 THROW` for `1 1 0 */` / `1 1 0 */MOD`.
- `tests/double_tests.fth` — code-review R-M2: 34 stale `\ expect: ? Stack underflow` comments updated to `\ expect: error -4: stack underflow`.
- `tests/core_gap_tests.fth` — code-review R-M2: 16 stale underflow expects updated; 2 stale div-by-zero baseline expects (`1 1 0 */` / `1 1 0 */MOD`) updated to assert `error -10: division by zero`.
- `tests/exception_tests.fth` — code-review R-M2: Section 5 narrative + 2 stale expect comments updated for the post-migration diagnostic.
- `tests/pictured_tests.fth` — code-review R-M2: 6 stale underflow expects updated.
- `docs/throw-codes.md` — code-review R-M3: `-4` and `-10` rows in the THROW-code table marked "done — Story 11.4"; future-add subsection (lines 292-299) repurposed as "Divisor-zero guards added by Story 11.4"; inventory totals corrected; migration-ordering row for Stage 11.4 updated to enumerate the actual guard sites.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `11-4-…: ready-for-dev` → `in-progress` → `review`. Code-review R-H1: new row `11-4-1-catch-throw-ix-preservation-bug-fix: backlog` added with hard ordering constraint.
- `_bmad-output/implementation-artifacts/11-4-internal-error-migration-stack-arithmetic-memory-primitives.md` — Status, task checkboxes, Dev Agent Record sections, File List, Change Log; code-review pass row added; AC #9 re-labelled PARTIAL; Note A's "Forward action" line updated; Debug Log row R-M5 corrected (5 prose-comment matches).

New:
- `tests/throw_migration_tests.fth` — Section 1 (stack underflow) + Section 2 (divisor zero); ~120 lines including header + i\*x preservation caveat documentation.

### Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-26 | Story 11.4 implementation: kernel-internal THROW entry; do_underflow_error → -4 THROW; udivmod / UM/MOD divisor-zero guards (-10 THROW); new tests/throw_migration_tests.fth; 22 new Makefile REPL tests; pre-existing diagnostic-format assertions updated. Adversarial review: 8 findings (2 HIGH, 4 MEDIUM, 2 LOW) — F2/F3/F6/F7 fixed in-pass, F4 closed as invalid, F1/F8 documented in Note A pending follow-up story, F5 deferred with rationale. | claude-opus-4-7 |
| 2026-04-26 | Code-review pass (`bmad-bmm-code-review` skill): 8 additional findings (1 HIGH, 5 MEDIUM, 2 LOW). Fixed in-pass: R-H1 (AC #9 re-labelled PARTIAL; sprint-status row `11-4-1-catch-throw-ix-preservation-bug-fix` added), R-M1 (check_underflow header comments), R-M2 (58 stale `\ expect: ? Stack underflow` comments across 4 reference test files), R-M3 (`docs/throw-codes.md` updated to mark Story 11.4 sites as done), R-M4 (M/MOD overclaim removed), R-M5 (Debug Log prose-comment count corrected), R-L2 (F6 leak note extended to caller-side `PUSH DE`). Deferred: R-L1 (test 715 result clarity — flagged for future test-suite refresh). Post-fix verification: `make` clean, `make test` clean, `make test-repl` 726 PASS / 0 FAIL; binary unchanged at 17373 bytes (comment + doc edits only). | claude-opus-4-7 |
