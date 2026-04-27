# Story 11.7: `ABORT` and `ABORT"` retargeted as THROW wrappers (capstone)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want `ABORT` and `ABORT"` to become standard ANS wrappers for `-1 THROW` and `-2 THROW` respectively (with the legacy `w_ABORT_cf` SP-reset / asm_cleanup / `JP w_QUIT_cf` chain folded into the uncaught-THROW handler so user-issued `ABORT` flows through the exception subsystem like every other error),
so that all kernel error emission — including the two legacy user-facing error words and the uncaught-THROW REPL-recovery chain itself — is fully unified under the exception mechanism (FR20). Story 11.7 is the **capstone** of Stories 11.4–11.7's E11-D3 word-by-word migration crawl: post-Story-11.6 the kernel has exactly **2 surviving `JP w_ABORT_cf` instruction-line hits** (`exception.asm:420` uncaught-recovery chain, `system.asm:137` `(ABORT")` `.paq_do_abort`) plus the `w_ABORT_cf:` entry-point label itself at `system.asm:266`. This story retargets all three: (a) `(ABORT")`'s `.paq_do_abort` raises `-2 THROW` (`THROW_ABORT_QUOTE` from `src/constants.asm:58`); (b) `ABORT`'s code body becomes the canonical `-1 THROW` raise (`THROW_ABORT` from `src/constants.asm:57`); (c) the uncaught-THROW handler at `exception.asm:420` is restructured to inline the `asm_cleanup` / SP-reset / `JP w_QUIT_cf` recovery chain (currently delegated to `w_ABORT_cf`) so that the chain `user-`ABORT` → -1 THROW → uncaught-handler → recovery` does not infinite-loop back through `w_ABORT_cf`. Post-Story-11.7 the post-edit grep `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` returns **zero** instruction-line hits — `w_ABORT_cf` is reachable only as the entry to ABORT's THROW-raise body, not as a target of any `JP` outside its own DEFCODE. The `(ABORT")` user-facing semantics remain identical (truthy flag → message + ABORT-equivalent reset + REPL recovery); the `ABORT` user-facing semantics remain identical (immediate REPL recovery with dictionary preserved). The new behaviour: catching `ABORT` (`' some-aborting-word CATCH .`) returns `-1`, and catching `ABORT"` returns `-2` — both per ANS §6.1.0670 / §6.1.0680 / Forth 2014 §9.6.2.0670 / §9.6.2.0680.

## Acceptance Criteria

1. **Given** the post-Story-11.6 kernel where `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE '^[^:]+:[0-9]+:\s*;'` returns exactly 2 instruction-line hits (`src/exception.asm:420` uncaught-recovery chain, `src/system.asm:137` `(ABORT")` `.paq_do_abort`) plus the `w_ABORT_cf:` entry-point label at `src/system.asm:266`, **when** Story 11.7 lands, **then** the same grep returns **zero** instruction-line hits — the only remaining textual occurrences of `w_ABORT_cf` are: (a) the `w_ABORT_cf:` label itself at `src/system.asm:266` (now the entry to ABORT's `-1 THROW` raise body), and (b) narrative comment-line mentions excluded by the `grep -v ':\s*;'` filter. Pre-edit baseline: 2 hits. Post-edit: 0 hits. Recorded in Completion Notes.

2. **Given** `(ABORT")` runtime helper at `src/system.asm:94-137` whose `.paq_do_abort` exit at `:136-137` currently reads `JP w_ABORT_cf      ; ABORT (never returns)` (the `.paq_abort` path at `:120-129` already prints the inline string via `bdos_print_str` before falling into `.paq_do_abort`), **when** Story 11.7 migrates the site, **then** the `JP w_ABORT_cf` is replaced with the kernel-internal raise pattern — body becomes:

    ```
    .paq_do_abort:
            ; -2 THROW (Story 11.7): ABORT" with truthy flag per
            ; ANS Forth 1994 §9.3.5 / §6.1.0680 / Forth 2014 §9.6.2.0680.
            ; Pre-Story-11.7 this site jumped to w_ABORT_cf (the legacy
            ; SP-reset + asm_cleanup + JP w_QUIT_cf chain); post-retarget
            ; the same recovery happens via the uncaught-THROW handler.
            LD      BC, THROW_ABORT_QUOTE
            JP      w_THROW_cf.kernel_entry
    ```

    The inline string print at `.paq_abort` (`:121-134`) is **preserved** — `(ABORT")` continues to emit the user's quoted message before raising the THROW, mirroring ANS semantics ("display the message and abort"). The `; ABORT (never returns)` trailing comment on the old `JP` line is removed (no longer accurate — `JP w_THROW_cf.kernel_entry` doesn't return either, but the comment is redundant with the citation block above). Caught semantics: `: T S" message" 1 ABORT" ;` then `' T CATCH .` returns `-2` with `message` printed before the `-2`. Uncaught semantics: same as today (message printed, REPL recovers). EXX state at the raise site: `(ABORT")` is a primary-set DEFCODE body (no `EXX` prior to `.paq_do_abort` — verify pre-edit via `grep -nE 'EXX' src/system.asm` for `:94-137`). No EXX-restore needed at the raise site.

3. **Given** `ABORT` itself at `src/system.asm:259-270` whose body currently reads `CALL asm_cleanup / LD HL, (sp_base) / LD SP, HL / JP w_QUIT_cf` (the legacy "reset SP, restart QUIT" recovery chain), **when** Story 11.7 retargets `ABORT`, **then** the body becomes the canonical `-1 THROW` raise — body becomes:

    ```
    w_ABORT:
            DEFCODE "ABORT", 0
    w_ABORT_cf:
            ; -1 THROW (Story 11.7): ABORT per ANS Forth 1994 §9.3.5 /
            ; §6.1.0670 / Forth 2014 §9.6.2.0670. Capstone of Epic 11's
            ; E11-D3 internal-error migration: every prior internal
            ; ABORT call site has been migrated to a direct THROW raise
            ; (Stories 11.4-11.6); ABORT itself is now the user-facing
            ; entry point that raises -1 THROW. The legacy SP-reset /
            ; asm_cleanup / JP w_QUIT_cf recovery chain has moved into
            ; the uncaught-THROW handler at src/exception.asm:.throw_uncaught
            ; (post-Story-11.7 layout) — when -1 THROW is uncaught, the
            ; same recovery semantics apply.
            LD      BC, THROW_ABORT
            JP      w_THROW_cf.kernel_entry
    ```

    The `w_ABORT_cf:` label is preserved (no rename) so any future code or external references resolve to the same entry. The `; Reset parameter stack and restart QUIT / ;   Never returns` docstring at `:260-262` is updated to reflect the new behaviour — replace with `;   Raise -1 THROW per ANS §6.1.0670 / Forth 2014 §9.6.2.0670. Uncaught: REPL recovery via the uncaught-THROW handler. Caught: -1 lands on the data stack as the THROW code.` Caught semantics: `' ABORT CATCH .` returns `-1`; the user-supplied wrapper `: ABORTING ABORT ;` then `' ABORTING CATCH .` also returns `-1`. Uncaught semantics: `ABORT` at the REPL prints `error -1: ABORT` then returns to the prompt with dictionary preserved (matches the pre-existing diagnostic format from Story 11.3's `throw_desc_table` row at `src/exception.asm:561-563` which is **already seeded** with the `-1 ABORT` description). EXX state at the raise: `ABORT`'s DEFCODE body is primary-set (no `EXX` in the original `:266-270` body); no EXX-restore needed.

4. **Given** the legacy recovery chain currently embedded in `w_ABORT_cf`'s body (`asm_cleanup` / `LD SP, (sp_base)` / `JP w_QUIT_cf`) — which the uncaught-THROW handler at `src/exception.asm:420` delegates to via `JP w_ABORT_cf` — **when** Story 11.7 retargets `w_ABORT_cf` itself to `-1 THROW`, **then** the recovery chain MUST be **moved into the uncaught-THROW handler** to avoid the chain `uncaught -1 THROW → JP w_ABORT_cf → JP w_THROW_cf.kernel_entry → CATCH-TOP=0 → JP w_ABORT_cf → ...` (infinite recursion). The post-Story-11.7 `.throw_uncaught` body at `src/exception.asm:396-420` becomes:

    ```
    .throw_uncaught:
            ; Stash n; needed across bdos_print_str calls (BDOS helper
            ; takes the length arg in B, clobbering BC).
            LD      (throw_saved_n), BC
            ; --- Print "error " ---
            LD      HL, str_throw_prefix
            LD      B, STR_THROW_PREFIX_LEN
            CALL    bdos_print_str
            ; --- Print n in signed decimal (BASE-independent: FR21, AC #13) ---
            LD      BC, (throw_saved_n)
            CALL    print_signed_dec_bc
            ; --- Look up description; print ": <desc>" on hit, nothing on miss ---
            LD      BC, (throw_saved_n)
            CALL    print_throw_description
            ; --- Trailing CR/LF ---
            CALL    bdos_crlf
            ; --- State reset + REPL recovery (inlined from the pre-Story-11.7
            ;     w_ABORT_cf body — moved here so that user-issued ABORT
            ;     (now -1 THROW per Story 11.7) routes through the
            ;     uncaught-handler chain rather than recursing through
            ;     w_ABORT_cf which now BCsides as a THROW raise). ---
            CALL    asm_cleanup             ; If asm_mode set, restore HERE/bucket
            LD      HL, (sp_base)
            LD      SP, HL                  ; Reset parameter stack
            JP      w_QUIT_cf               ; Enter QUIT (resets return stack + STATE
                                            ; + CATCH-TOP per outer_interpreter.asm:252-255)
    ```

    The previous `JP w_ABORT_cf` at `:420` is **deleted**. The `;     Story 11.7 will retarget w_ABORT_cf itself to -1 THROW —` forward-pointer comment at `:417-419` is **deleted** (the retarget has now happened). The header comment at `:212-220` is updated to reflect that the uncaught-handler now owns the recovery chain directly rather than delegating to `w_ABORT_cf`. Verification: post-Story-11.7 grep `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` returns zero instruction-line hits (AC #1).

5. **Given** the post-Story-11.7 chain `user-ABORT → JP w_THROW_cf.kernel_entry → CATCH-TOP=0 → .throw_uncaught → asm_cleanup / SP-reset / JP w_QUIT_cf`, **when** any code path that previously ended in `JP w_ABORT_cf` runs (Stories 11.4–11.6 migrated those to `JP w_THROW_cf.kernel_entry` — uncaught-with-CATCH-TOP=0 routes here), **then** the recovery semantics are **identical** to the pre-Story-11.7 behaviour: parameter stack reset to empty, `asm_mode` cleared if set (HERE/bucket restored), return stack reset (via `w_QUIT_cf`'s `LD IX, (rp_base)` at `outer_interpreter.asm:245-247`), STATE = 0, CATCH-TOP = 0, `.quit_loop` re-entered. Verified by re-running every existing pre-Story-11.7 REPL-recovery test (Stories 11.3 / 11.4 / 11.5 / 11.6 — uncaught-recovery tests for `-1`, `-4`, `-10`, `-13`, `-14`, `-16`, `-17`, `-22`, `-58`, `-258..-271`) and confirming each still passes the `tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'` pattern. Recorded in Completion Notes per AC #19.

6. **Given** `(ABORT")` invoked with a **zero** flag at runtime, **when** the body executes, **then** it skips the inline string and continues without raising any THROW (per ANS §6.1.0680: "Display the message ... if any bit of flag is true, ... otherwise, do nothing more than to discard the parameters and continue"). The flag-zero path at `src/system.asm:103-118` is **untouched** by Story 11.7 — only the truthy `.paq_do_abort` exit changes. Verified by running existing Makefile test 257 (`': CHK ABORT" nonzero" ; 0 CHK\r\nBYE\r\n'` expects no `nonzero` output and a clean `ok` REPL line) post-edit; expect PASS unchanged.

7. **Given** the post-Story-11.7 caught-`ABORT` semantic, **when** `' ABORT CATCH .` is invoked at the REPL, **then** the data stack receives `-1` (the THROW code) and the REPL prints `-1  ok` — the i\*x cells underneath the ABORT raise are preserved per the Story 11.4.1 contract (`src/exception.asm:226-264`). Test: `1 2 3 ' ABORT CATCH . . . .` produces `-1 3 2 1  ok`. Test: `' ABORT CATCH DEPTH .` produces `1  ok` (only the THROW code on stack). Test: a wrapper `: ABORTING ABORT ;` then `' ABORTING CATCH .` produces `-1  ok` — confirms ABORT is callable from a colon body and CATCH-able through the wrapper.

8. **Given** the post-Story-11.7 caught-`ABORT"` semantic, **when** the test wrapper `: T S" message" 1 ABORT" abort msg" ;` … or equivalent feeder that compiles `(ABORT")` into a colon body … is `CATCH`-ed, **then**: (a) the inline string `abort msg` is printed to the console (the print at `src/system.asm:121-134` happens **before** the `.paq_do_abort` raise — preserved by AC #2); (b) the data stack receives `-2`; (c) the test fixture's wrapper-CATCH . produces `-2  ok` after the printed message. Sample (verify exact incantation at write time — `ABORT"` is IMMEDIATE compile-only, so the test must compile a colon body that contains the runtime call):

    ```forth
    : TAB1 1 ABORT" message" ;
    ' TAB1 CATCH .              \ expects: message-2  ok
                                \ (the message has no CR/LF after — the
                                \  -2 prints immediately after; observed
                                \  output is literally "message-2  ok" or
                                \  "message" CRLF "-2  ok" depending on
                                \  whether (ABORT") emits a trailing CRLF.
                                \  Verify at write time — the pre-Story-
                                \  11.7 (ABORT") does NOT emit CRLF after
                                \  the inline message; only w_ABORT_cf's
                                \  recovery path printed CRLF via
                                \  bdos_print_str. Post-Story-11.7 the
                                \  uncaught-handler emits CRLF; the
                                \  caught path does NOT — so the output
                                \  is "message-2  ok" with no CRLF
                                \  between message and -2.
    ```

    **Verify by direct REPL experiment at dev-pass.** Document the exact observed output in Completion Notes; if a CRLF interjects, add a `CR` to the test or assert with `tr '\r\n' '  '` normalization (mirror the Story 11.3 / 11.4 / 11.5 uncaught-recovery test pattern). Note for adversarial review: the **caught path through `(ABORT")` MUST still print the inline message** — this is the ANS contract ("display the message"). If the post-edit caught test shows the `-2` lands but the message is suppressed, that's a regression.

9. **Given** `THROW_ABORT EQU -1` at `src/constants.asm:57` and `THROW_ABORT_QUOTE EQU -2` at `src/constants.asm:58` (declared upfront by Story 11.1, **first-consumed by Story 11.7**), **when** Story 11.7 emits these codes, **then** the source uses the EQU symbols, not the bare numerical literals (`LD BC, THROW_ABORT` not `LD BC, -1`; `LD BC, THROW_ABORT_QUOTE` not `LD BC, -2`). Per `architecture.md:471-479` and the Story 11.4 / 11.5 / 11.6 first-consumption convention. Verify post-edit: `grep -nE 'LD\s+BC,\s*-(1|2)\b' src/*.asm` returns zero hits at the migrated sites (existing `-1` / `-2` literals elsewhere are out of scope); `grep -nE 'THROW_ABORT\b|THROW_ABORT_QUOTE\b' src/*.asm` finds the two declarations and the two consumption sites (one each).

10. **Given** the standards-citation discipline (CCD-3 / NFR17, `architecture.md:206-216`) and the Stories 11.4 / 11.5 / 11.6 inline-citation convention, **when** Story 11.7 edits each migration site, **then** an inline citation comment of the matching form is added immediately above the `LD BC, code` instruction:
    - `(ABORT")` `.paq_do_abort`: `; -2 THROW (Story 11.7): ABORT" with truthy flag per ANS Forth 1994 §9.3.5 / §6.1.0680 / Forth 2014 §9.6.2.0680.`
    - `w_ABORT_cf`: `; -1 THROW (Story 11.7): ABORT per ANS Forth 1994 §9.3.5 / §6.1.0670 / Forth 2014 §9.6.2.0670.`

    The `§6.1.xxx` / `§9.6.2.xxx` references identify the user-facing word definitions (where ABORT and ABORT" are specified); `§9.3.5` identifies the THROW-code table entries. Both apply — the citation form mirrors `architecture.md:208-214` Example 1's joint `Forth 2014 §9.6.1.0875 / §6.1.0875` form.

11. **Given** the description-table at `src/exception.asm:560-644` (post-Story-11.6 layout: standard codes `-1..-58` plus antforth-extension codes `-258..-271` plus `DW 0` terminator at `:644`), and Story 11.3's pre-seeding of `-1 "ABORT"` at `:561-563` (`DW -1 / DB 5 / DB "ABORT"`) and `-2 "ABORT\""` at `:564-566` (`DW -2 / DB 6 / DB "ABORT", 0x22`), **when** Story 11.7 lands, **then** **no edits** are made to the standard-code rows for `-1` and `-2` — Story 11.3's seeding is exactly the text Story 11.7's uncaught path will produce. Verification: `grep -nE 'DW\s+-1\b|DW\s+-2\b' src/exception.asm` returns the two pre-existing rows unchanged.

12. **Given** the kernel-internal-entry contract at `src/exception.asm:288-296` (BC carries the THROW code; SP/IX may be in any state; **caller must enter from primary set** — Stories 11.4 / 11.5 / 11.6 review F1/F2/F12 reaffirmed), **when** Story 11.7's 2 new raise sites land, **then** each site is verified to call `JP w_THROW_cf.kernel_entry` from primary-set context. Verified call-site contexts:
    - `(ABORT")` `.paq_do_abort` (`src/system.asm`): the `(ABORT")` DEFCODE body at `:96-137` enters primary set (no `EXX` in the body — verify pre-edit). The `bdos_print_str` call at `:134` is documented as IX-preserving and primary-set-preserving (per `src/system.asm:124-125` comment). The `POP BC` at `:100` consumes the flag from TOS; subsequent `BC` value is irrelevant (`(ABORT")` then proceeds either to skip the string or to print + raise). At `.paq_do_abort` entry, primary set is active. No EXX-restore needed.
    - `w_ABORT_cf` (`src/system.asm`): `ABORT` is a DEFCODE, primary-set body. The pre-Story-11.7 body did `CALL asm_cleanup / LD HL, (sp_base) / LD SP, HL / JP w_QUIT_cf` — all primary-set instructions. The post-Story-11.7 body is `LD BC, THROW_ABORT / JP w_THROW_cf.kernel_entry` — also primary-set. No EXX-restore needed.

    Document the verification evidence per site in Completion Notes (one line each: file:line, caller, "primary-set verified by …").

13. **Given** the test discipline established by Stories 11.4 / 11.5 / 11.6 (REPL-piped Forth in `tests/throw_migration_tests.fth`; matching `printf | $(IZCPM)` blocks in `Makefile` per `feedback_repl_tests_preferred.md`) and the post-Story-11.6 high-water mark of test 753 (verify at dev-pass via `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending), **when** Story 11.7 lands, **then** a new "Section 5 — `ABORT` / `ABORT"` retarget verification (Story 11.7)" header block is appended to `tests/throw_migration_tests.fth` covering:

    - **`-1` `ABORT` caught:** `' ABORT CATCH .` → `-1  ok` (sample shape — verify exact incantation works at write time; ABORT may need to be wrapped in a colon body if direct `'` lookup misbehaves at the REPL).
    - **`-1` `ABORT` caught via colon-body wrapper:** `: ABORTING ABORT ; ' ABORTING CATCH .` → `-1  ok`.
    - **`-1` i\*x preservation:** `1 2 3 ' ABORT CATCH . . . .` → `-1 3 2 1  ok` (3 i\*x cells preserved across the kernel-internal -1 raise).
    - **`-1` DEPTH-invariant after caught ABORT:** `' ABORT CATCH DEPTH .` → `1  ok` (Story 11.4.1 i\*x-restore gives DEPTH=1 because only the THROW code is visible after caught).
    - **`-2` `ABORT"` caught (from compiled colon body):** `: TAB1 1 ABORT" message" ; ' TAB1 CATCH .` → `message-2  ok` or `message<CRLF>-2  ok` (verify CRLF interleaving at write time per AC #8). Document the exact observed output in Completion Notes.
    - **`-2` `ABORT"` flag-zero positive control:** `: TAB0 0 ABORT" message" ; ' TAB0 CATCH .` → `0  ok` (no print, no raise, CATCH returns 0).
    - **`-2` i\*x preservation:** `1 2 3 ' TAB1 CATCH . . . .` → `message-2 3 2 1  ok` (3 i\*x cells preserved).
    - **Positive controls — caught path with no abort:** a colon body that does *not* invoke ABORT, wrapped in CATCH, returns 0. Sample: `: TNOAB 5 ; ' TNOAB CATCH .` → `0  ok`.
    - **Capstone re-verification — recovery chain identity:** verify the legacy recovery semantics are intact post-edit. The Story 11.3 / 11.4 / 11.5 / 11.6 uncaught-recovery tests (already in the Makefile) collectively cover this — Story 11.7 adds **at least one new** uncaught-`ABORT` test using the same `tr '\r\n' '  ' | grep -qE 'error -1: ABORT.*<recovery-marker>'` pattern (Story 11.3 test 687 already covers `-1 THROW` directly; Story 11.7 adds the `ABORT`-word equivalent: `printf "ABORT\r\n99 .\r\nBYE\r\n" | $(IZCPM) ... | grep -qE 'error -1: ABORT.*99  ok'`).
    - **Capstone re-verification — `asm_cleanup` integrity inside CODE block:** before the migration the legacy chain was `w_ABORT_cf → asm_cleanup → SP-reset → JP w_QUIT_cf`. Post-edit, `asm_cleanup` runs from inside the uncaught-handler. Verify by triggering an in-CODE error: e.g., `CODE BAD UNDEFINED-WORD END-CODE` should raise `-13 THROW`, recover to a clean dictionary state (asm_mode cleared, HERE rolled back via `asm_cleanup`), and survive — confirm with a follow-up `WORDS` that the partial CODE word is not present. Mirror Makefile test 3464's pattern (search for `asm_cleanup rollback` in the Makefile).

14. **Given** the per-line `\ expect: <fragment>` convention from Stories 11.4 / 11.5 / 11.6 and the matching Makefile `printf | $(IZCPM)` block convention (single-line caught tests; multi-line uncaught-recovery tests with `tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'`), **when** Story 11.7's tests are written, **then** every test follows the same convention; the matching Makefile blocks are appended starting at the highest existing PASS test number + 1 (verify with `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending — Story 11.6 final landed at 753; verify at write time).

15. **Given** the post-Story-11.6 baseline (`build/antforth.com` = 17419 bytes per current `wc -c` — verify at dev-pass), **when** Story 11.7 lands, **then** the binary delta is bounded by the following budget table:

    | Change | Estimated byte delta |
    |---|---:|
    | `w_ABORT_cf` body shrink: `CALL asm_cleanup / LD HL,(sp_base) / LD SP,HL / JP w_QUIT_cf` (3 + 3 + 1 + 3 = 10B) → `LD BC,n / JP` (3 + 3 = 6B) | −4 |
    | `(ABORT")` `.paq_do_abort` body: `JP w_ABORT_cf` (3B) → `LD BC,n / JP` (3 + 3 = 6B) | +3 |
    | `.throw_uncaught` recovery chain inlining: pre-edit `JP w_ABORT_cf` (3B); post-edit `CALL asm_cleanup / LD HL,(sp_base) / LD SP,HL / JP w_QUIT_cf` (10B); net | +7 |
    | Inline citation comments (3 sites: `.paq_do_abort`, `w_ABORT_cf`, `.throw_uncaught`) | 0 (comments only) |
    | Header-comment sweeps in `(ABORT")`, `ABORT`, `.throw_uncaught`, `EVALUATE` (`outer_interpreter.asm:376-382` mentions Story 11.6 migrating to THROW-safe save/restore — update to reflect 11.7) | 0 (comments only) |
    | **Estimated net** | **+6** |

    Pre/post `wc -c build/antforth.com` recorded in Completion Notes. **Investigate if delta exceeds ±100 bytes** (this is a small story; a large delta likely indicates a missed dead-helper deletion or an unintended duplication of the recovery chain). Net-positive delta (~+6 bytes) is the expected outcome — Story 11.7 inlines a chain that was previously a single `JP`. The +7 inlining cost is offset by the −4 ABORT body shrink and +3 `(ABORT")` change.

16. **Given** the post-migration ABORT-site count target — from 2 grep hits today (`exception.asm:420`, `system.asm:137`) drops to **0 grep hits** post-Story-11.7 — **when** Story 11.7 lands, **then** `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE '^[^:]+:[0-9]+:\s*;'` returns exactly 0 instruction-line hits. Recorded in Completion Notes. Comment-line matches excluded per Story 11.5 AC #18 distinction. The `w_ABORT_cf:` label itself at `src/system.asm:266` continues to exist as the ABORT DEFCODE entry point — `grep -nE '^w_ABORT_cf:' src/*.asm` returns exactly 1 hit (the label).

17. **Given** the Stories 11.4 / 11.5 / 11.6 REPL-recovery-test pattern (`tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'`) for verifying that an uncaught THROW returns the REPL to a live prompt, **when** Story 11.7 lands, **then** at least the following uncaught-recovery tests are added:
    - **`-1` uncaught via `ABORT` word:** `printf "ABORT\r\n99 .\r\nBYE\r\n" | $(IZCPM) ... | tr '\r\n' '  ' | grep -qE 'error -1: ABORT.*99  ok'` — covers the user-issued ABORT (now `-1 THROW`) flowing through the uncaught-handler (Story 11.3's test 687 covers raw `-1 THROW`; this test covers `ABORT` as the user-facing word).
    - **`-2` uncaught via `ABORT"`:** `printf ': T ABORT\" boom\" ; T\r\n99 .\r\nBYE\r\n' | $(IZCPM) ... | tr '\r\n' '  ' | grep -qE 'boom.*error -2: ABORT\".*99  ok'` — covers the user-issued `ABORT"` (now `-2 THROW` after the inline-message print) flowing through the uncaught-handler.
    - **CODE-block ABORT recovery (asm_cleanup integrity):** verify the asm_cleanup-inside-uncaught path. Sample: `printf "CODE TRY BAD-OP END-CODE\r\nWORDS\r\nBYE\r\n" | $(IZCPM) ... | tr '\r\n' '  '` — assert that the `BAD-OP` triggers a -13 (or -267 bare-int) THROW, the partial `TRY` word is not visible in the subsequent `WORDS`, and the REPL has recovered. Mirror Makefile test 3464's pattern.

    Each recovery test asserts (a) the diagnostic format and (b) that a subsequent simple REPL command runs cleanly (REPL-survivability per FR22 / NFR7).

18. **Given** the adversarial-review discipline (`feedback_adversarial_review.md`) and Stories 11.4 / 11.5 / 11.6 review yields (8 + 5 + 11 + 4 + 5 findings respectively across multiple passes), **when** Story 11.7's review runs, **then** **at least 2-3 HIGH/MEDIUM findings are expected**. Likely candidates the review must investigate:
    - **(a)** Recovery-chain identity: verify the post-Story-11.7 `.throw_uncaught` produces byte-for-byte identical user-visible behaviour for every pre-existing uncaught-recovery test (Stories 11.3/11.4/11.5/11.6). A missed step in the inlined chain (e.g., forgetting `asm_cleanup`, or running `LD SP,(sp_base)` before `asm_cleanup` rather than after — actually the original is `CALL asm_cleanup` first per `system.asm:267`, so order matters) silently breaks `asm_mode` recovery.
    - **(b)** Forward-pointer comment cleanup: every Story 11.4/11.5/11.6 site that mentioned "Story 11.7 will retarget …" must be swept (`grep -nE 'Story 11\.7' src/*.asm` pre-edit; reconcile each occurrence — most should flip from "will" to "did" or be removed entirely). Mirror Story 11.6 R-M2 stale-expect cleanup.
    - **(c)** Caught-`ABORT"` message-print observation: ANS contract says display message THEN abort. Verify the migration preserves the print order (the `bdos_print_str` at `system.asm:134` happens **before** the `LD BC, THROW_ABORT_QUOTE / JP w_THROW_cf.kernel_entry`). A re-ordering would silently regress the user-facing semantic.
    - **(d)** EVALUATE comment drift (`src/outer_interpreter.asm:376-382`): the Story 11.6-era forward-pointer comment "Story 11.6 will migrate to a THROW-safe save/restore" is now stale (Story 11.6 did not migrate EVALUATE — Story 11.6 review F8 filed it as a follow-up; Story 11.7 also does not migrate EVALUATE). Update the comment to reflect the actual state: EVALUATE remains pre-Epic-11 baseline; the THROW-safe save/restore is filed as a Review Follow-up (Story 11.6 §F8, carried forward).
    - **(e)** Test gaps — caught `ABORT` round-trip; `: WRAPPER ABORT ; ' WRAPPER CATCH .` should also work; positive controls (success path returns 0); i\*x preservation across the new sites (mirror Story 11.4.1 contract).
    - **(f)** Stale `\ expect:` / Makefile diagnostic literals — pre-edit `grep -nE 'JP\s+w_ABORT_cf' tests/ Makefile` and reconcile each occurrence. The pre-existing tests should already use `error -1: ABORT` / `error -2: ABORT"` form per Story 11.3 — but verify nothing leaked through. Mirror Story 11.6 R-M2 stale-expect cleanup. Also `grep -nE 'restart QUIT|reset.*stack.*restart' tests/ Makefile src/*.asm` for stale ABORT-body docstring references.
    - **(g)** Stale docstring sweep — every site that previously mentioned "ABORT" in the sense of "the recovery chain" must be updated. Particular attention: `src/exception.asm:212-220` `(THROW`'s docstring — currently mentions `then route through w_ABORT_cf for state reset`; needs updating to "then run the recovery chain (asm_cleanup + SP-reset + JP w_QUIT_cf) inline". `src/exception.asm:417-419` forward-pointer comment must be deleted.
    - **(h)** Stale `docs/throw-codes.md` row tags — §b row for `-1` and `-2` should flip from `yes — Story 11.7` to `done — Story 11.7`; §d per-file inventory rows for `system.asm:131` (`(ABORT")`) and `system.asm:260` (`w_ABORT_cf`) flip to `**done — 11.7**`; §e migration-ordering row 11.7 flips to `done` with codes-used cell expanded.
    - **(i)** Docstring drift in `outer_interpreter.asm:241-258` (QUIT) — verify `CATCH-TOP = 0` reset at `:252-255` is still correct under the new flow. (It is — QUIT is invoked from the inlined recovery chain and it still resets CATCH-TOP. Verify and document.)
    - **(j)** Verify Story 11.4.1 i\*x preservation contract still holds for `-1 THROW` raised from `ABORT`. The kernel-internal raise pattern is identical to every other Story 11.4–11.6 site; the i\*x cells are preserved by the catch-frame +2 saved-BC slot. Test: `1 2 3 ' ABORT CATCH . . . .` → `-1 3 2 1  ok`.
    - Triage all findings; fix HIGH and MEDIUM in-pass; defer LOW with rationale (mirror Stories 11.4/11.5/11.6 review log discipline).

19. **Given** the Stories 11.4 / 11.5 / 11.6 verdict-table format for Completion Notes (one row per AC, columns `Gate text | Evidence | Verdict`), **when** Story 11.7 lands, **then** Completion Notes mirror that format. State the value, the gate, and the reason plainly per `feedback_plain_qa_language.md`.

20. **Given** the post-edit regression discipline (`make` + `make test` + `make test-repl` clean against the post-Story-11.6 baseline — 0 errors, 0 warnings, current PASS count from the high-water-mark grep), **when** Story 11.7 lands, **then** all three passes run clean; new tests appended (estimated ~8-12 new tests covering Section 5's caught-`ABORT` / caught-`ABORT"` round-trips + uncaught-recovery cases per AC #13 and AC #17). **Critical regression check**: every pre-existing uncaught-recovery test (tests covering `-1` / `-2` / `-4` / `-10` / `-13` / `-14` / `-16` / `-17` / `-22` / `-58` / `-258..-271`) must continue to PASS — the recovery semantics are preserved by AC #4's inline of the legacy chain. Pre-edit `grep -nE 'restart QUIT|JP\s+w_ABORT_cf' tests/ Makefile` to surface any test that relied on the textual structure of the recovery chain (rather than its observable behaviour); none expected, but verify.

21. **Given** Epic 11's full scope (Stories 11.1–11.8 per `_bmad-output/planning-artifacts/epics.md:693-927`), **when** Story 11.7 lands, **then** the kernel state with respect to FR19 ("internal errors raise THROW codes") and FR20 ("ABORT/ABORT" become THROW wrappers") is **fully delivered** — every internal kernel error path (FR19, Stories 11.4-11.6) AND the two user-facing legacy error words (FR20, Story 11.7) raise standard ANS THROW codes. The remaining Epic 11 work is the benchmark / survivability stress / regression gate (Story 11.8). Recorded in Completion Notes as a milestone marker per the capstone framing.

## Tasks / Subtasks

- [x] **Task 1 — Pre-edit verification + baseline (AC: #1, #11, #15, #16, #20)**
  - [x] 1.1 Re-run `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE '^[^:]+:[0-9]+:\s*;'` — expect exactly 2 instruction-line hits (`exception.asm:420`, `system.asm:137`). Reconcile any drift since Story 11.6's final landing.
  - [x] 1.2 Confirm `src/exception.asm` `throw_desc_table` still contains entries for `-1` (`:561-563`) and `-2` (`:564-566`). Story 11.7 does **not** touch the standard-code rows. `grep -nE 'DW\s+-1\b|DW\s+-2\b' src/exception.asm`.
  - [x] 1.3 Confirm `THROW_ABORT EQU -1` and `THROW_ABORT_QUOTE EQU -2` are declared in `src/constants.asm:57-58` (Story 11.1 pre-declaration; first-consumed by this story).
  - [x] 1.4 Confirm `src/exception.asm` `w_THROW_cf.kernel_entry:` label exists and the FUTURE-EDIT NOTE 1/2 contract documentation is intact (Stories 11.4 / 11.5 / 11.6 reuse without modification; Story 11.7 reuses again — third+fourth use).
  - [x] 1.5 Re-check the highest existing PASS test number: `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1`. Story 11.7's new tests start at this number + 1 (Story 11.6 final was 753 — verify post-Story-11.6).
  - [x] 1.6 `wc -c build/antforth.com` — record pre-edit baseline (post-Story-11.6 figure; expected = 17419 bytes — verify).
  - [x] 1.7 Pre-edit forward-pointer-comment cross-check: `grep -nE 'Story 11\.7' src/*.asm tests/ Makefile` — record every occurrence; these are AC #18(b) candidates for the post-migration sweep. Most should flip from "will" to "did" or be removed.
  - [x] 1.8 Pre-edit verify the `(ABORT")` truthy-flag print path is intact: `grep -nA2 '\.paq_abort:' src/system.asm` should show the `bdos_print_str` call at `:134` followed by fall-through to `.paq_do_abort`. The migration preserves this path; only the `.paq_do_abort` exit changes.
  - [x] 1.9 Pre-edit verify the legacy recovery chain in `w_ABORT_cf:` (`src/system.asm:266-270`): `CALL asm_cleanup / LD HL,(sp_base) / LD SP, HL / JP w_QUIT_cf`. Record exact instructions for inlining in Task 4.
  - [x] 1.10 Pre-edit cross-check `outer_interpreter.asm:376-382` (EVALUATE)'s Story-11.6 forward-pointer comment — confirm it's stale and update per AC #18(d). Also pre-edit verify `src/exception.asm:212-220` (`THROW` docstring) mentions `route through w_ABORT_cf` — record for Task 4.5.

- [x] **Task 2 — Migrate `(ABORT")` `.paq_do_abort` (`src/system.asm:120-137`) (AC: #2, #6, #9, #10, #12)**
  - [x] 2.1 Open `src/system.asm` at `.paq_do_abort:` (`:136`). Pre-edit body:
    ```
    .paq_do_abort:
            JP      w_ABORT_cf      ; ABORT (never returns)
    ```
  - [x] 2.2 Replace with:
    ```
    .paq_do_abort:
            ; -2 THROW (Story 11.7): ABORT" with truthy flag per
            ; ANS Forth 1994 §9.3.5 / §6.1.0680 / Forth 2014 §9.6.2.0680.
            ; Pre-Story-11.7 this site jumped to w_ABORT_cf (the legacy
            ; SP-reset + asm_cleanup + JP w_QUIT_cf chain); post-retarget
            ; the same recovery happens via the uncaught-THROW handler.
            LD      BC, THROW_ABORT_QUOTE
            JP      w_THROW_cf.kernel_entry
    ```
  - [x] 2.3 Confirm the flag-zero path at `:103-118` is unchanged (only `.paq_do_abort` changes). Per AC #6, this preserves the ANS "do nothing" semantic on flag = 0.
  - [x] 2.4 Update the `(ABORT")` docstring at `:89-93` — replace the `print inline string via TYPE, then ABORT` description with `print inline string then raise -2 THROW per ANS Forth 1994 §9.3.5 / §6.1.0680. Truthy flag → message + raise; zero flag → skip string and continue.` Mirror Stories 11.4/11.5/11.6 in-pass header sweep discipline.
  - [x] 2.5 Update the `.paq_abort` comment at `:120-125` — replace `Non-zero flag: print string then ABORT.` with `Non-zero flag: print string then raise -2 THROW.` and replace `No IP save needed: w_ABORT_cf resets SP wholesale and re-enters QUIT` with `No IP save needed: -2 THROW's uncaught-handler resets SP wholesale and re-enters QUIT (or, if caught, the catching frame's SP_safe + IP discard the partial state).` Verify the `bdos_print_str preserves IX` invariant comment at `:124-125` is intact and still accurate.

- [x] **Task 3 — Retarget `w_ABORT_cf` to `-1 THROW` (`src/system.asm:259-270`) (AC: #3, #5, #9, #10, #12, #16)**
  - [x] 3.1 Open `src/system.asm` at `w_ABORT:` (`:264`). Pre-edit body:
    ```
    ; -----------------------------------------------
    ; ABORT ( -- )
    ;   Reset parameter stack and restart QUIT
    ;   Never returns
    ; -----------------------------------------------
    w_ABORT:
            DEFCODE "ABORT", 0
    w_ABORT_cf:
            CALL    asm_cleanup             ; If asm_mode set, restore HERE/bucket
            LD      HL, (sp_base)
            LD      SP, HL                  ; Reset parameter stack
            JP      w_QUIT_cf               ; Enter QUIT (resets return stack + STATE)
    ```
  - [x] 3.2 Replace with:
    ```
    ; -----------------------------------------------
    ; ABORT ( -- )
    ;   Raise -1 THROW per ANS §6.1.0670 / Forth 2014 §9.6.2.0670.
    ;   Uncaught: REPL recovery via the uncaught-THROW handler
    ;   (src/exception.asm:.throw_uncaught — post-Story-11.7 this
    ;   handler owns the asm_cleanup / SP-reset / JP w_QUIT_cf chain
    ;   directly rather than delegating to w_ABORT_cf).
    ;   Caught: -1 lands on the data stack as the THROW code; i*x
    ;   cells underneath are preserved per the Story 11.4.1 contract.
    ;
    ;   Story 11.7 capstone: completes Epic 11's E11-D3 word-by-word
    ;   internal-error migration. Every prior internal ABORT call
    ;   site has been migrated to a direct THROW raise (Stories
    ;   11.4-11.6); ABORT itself is now the user-facing entry point
    ;   that raises -1 THROW.
    ; -----------------------------------------------
    w_ABORT:
            DEFCODE "ABORT", 0
    w_ABORT_cf:
            ; -1 THROW (Story 11.7): ABORT per ANS Forth 1994 §9.3.5 /
            ; §6.1.0670 / Forth 2014 §9.6.2.0670.
            LD      BC, THROW_ABORT
            JP      w_THROW_cf.kernel_entry
    ```
  - [x] 3.3 The `w_ABORT_cf:` label is **preserved** (no rename). External callers in the kernel (none post-Story-11.6 — verified in AC #16) and any future references resolve to the same entry point. The inlined recovery chain moves to `.throw_uncaught` per Task 4.
  - [x] 3.4 EXX-context spot-check (AC #12): `ABORT` is a DEFCODE primary-set body. The pre-edit body had no `EXX` instructions — only `CALL asm_cleanup / LD HL,(sp_base) / LD SP, HL / JP w_QUIT_cf` — all primary-set. The post-edit body is also primary-set. No EXX-restore needed.

- [x] **Task 4 — Move recovery chain into `.throw_uncaught` (`src/exception.asm:396-420`) (AC: #4, #5, #15, #16, #18(a))**
  - [x] 4.1 Open `src/exception.asm` at `.throw_uncaught:` (`:396`). Pre-edit body ends with:
    ```
            ; --- State reset + REPL recovery via the legacy ABORT chain.
            ;     w_ABORT_cf calls asm_cleanup (clears asm_mode, restores
            ;     HERE/bucket if mid-CODE), resets SP, then JP w_QUIT_cf
            ;     (which resets IX, STATE, CATCH-TOP, then re-enters the
            ;     .quit_loop REPL prompt). FR22 / NFR7 / NFR8.
            ;     Story 11.7 will retarget w_ABORT_cf itself to -1 THROW —
            ;     at which point this becomes a tail of ABORT's own
            ;     machinery, with the same recovery semantics either way. ---
            JP      w_ABORT_cf
    ```
  - [x] 4.2 Replace the trailing `JP w_ABORT_cf` and its preceding comment block (`:412-420`) with the **inlined** recovery chain (the pre-Story-11.7 `w_ABORT_cf` body, now folded directly here):
    ```
            ; --- State reset + REPL recovery (Story 11.7 inline).
            ;     Pre-Story-11.7 this was `JP w_ABORT_cf` and the chain
            ;     lived in w_ABORT_cf's body; Story 11.7 retargets
            ;     w_ABORT_cf itself to -1 THROW so the chain `user-ABORT
            ;     → -1 THROW → uncaught (CATCH-TOP=0) → JP w_ABORT_cf`
            ;     would otherwise infinite-loop. The chain is moved
            ;     here; w_QUIT_cf's IX/STATE/CATCH-TOP reset
            ;     (outer_interpreter.asm:243-258) closes the recovery.
            ;     FR22 / NFR7 / NFR8. ---
            CALL    asm_cleanup             ; If asm_mode set, restore HERE/bucket
            LD      HL, (sp_base)
            LD      SP, HL                  ; Reset parameter stack
            JP      w_QUIT_cf               ; Enter QUIT (resets return stack + STATE
                                            ; + CATCH-TOP per outer_interpreter.asm:252-255)
    ```
  - [x] 4.3 Verify post-edit `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE '^[^:]+:[0-9]+:\s*;'` returns **zero** instruction-line hits per AC #1 / AC #16.
  - [x] 4.4 Update the THROW-word docstring at `src/exception.asm:212-220` — currently says `then route through w_ABORT_cf for state reset and REPL recovery (FR21, FR22, NFR3, NFR7, NFR8)`. Replace with `then run the recovery chain (asm_cleanup + SP-reset + JP w_QUIT_cf) inline; routes back to the .quit_loop REPL prompt with dictionary preserved (FR21, FR22, NFR3, NFR7, NFR8)`.
  - [x] 4.5 Sweep additional `src/exception.asm` comments mentioning `JP w_ABORT_cf` as the post-uncaught path: `:290-291`, `:430`, `:653` (per pre-edit grep in Task 1.10). Reconcile each — most should be updated to "the inlined recovery chain at .throw_uncaught" or removed entirely.

- [x] **Task 5 — Sweep stale forward-pointer comments and docstrings (AC: #18(b), #18(d), #18(g), #18(i))**
  - [x] 5.1 Pre-edit `grep -nE 'Story 11\.7' src/*.asm` — every occurrence is a forward-pointer that should now flip from "will" to "did" or be removed. Examples expected: forward-pointer in `src/exception.asm:417-419` (deleted by Task 4.2), references in `src/control_flow.asm`, `src/compiler.asm`, `src/arithmetic.asm` ABORT-chain comments. Reconcile each at edit time.
  - [x] 5.2 Update `src/outer_interpreter.asm:376-382` (EVALUATE comment) — pre-edit text: `This is the pre-Epic-11 baseline; Story 11.6 will migrate to a THROW-safe save/restore.` Post-edit: replace with text reflecting the actual state — Story 11.6 did NOT migrate EVALUATE (Review Follow-up #1 from Story 11.6 §F8); Story 11.7 also does not touch EVALUATE. Suggested replacement: `This is the pre-Epic-11 baseline. A THROW-safe save/restore (where (RESTORE-INPUT) runs even when INTERPRET raises) is filed as a post-Epic-11 follow-up — the (-58 caught form) bug it would fix is documented in 11-6's Review Follow-up #1.`
  - [x] 5.3 Sweep `src/system.asm` for any remaining ABORT-chain narrative — particular attention: `aq_saved_ip` / `aq_src` storage at `:255-257` is still relevant (`(ABORT")` still uses them); the `; ABORT" scratch storage` header is still accurate.
  - [x] 5.4 Pre-edit `grep -nE 'JP\s+w_ABORT_cf' src/*.asm tests/ Makefile` (cast wide net) — record any remaining textual reference (comments only, post-Tasks 2-4). Reconcile each: description-style references can stay if accurate ("the legacy ABORT chain"); structural references must be updated.
  - [x] 5.5 Update `docs/throw-codes.md`: §b row for `-1` (`:72`) — update from `yes — Story 11.7` to `done — Story 11.7`. §b row for `-2` (`:73`) — same flip. §d per-file row `system.asm:131` (`(ABORT")`) — flip migration tag from `**11.7 (capstone — retarget)**` to `**done — 11.7**`. §d per-file row `system.asm:260` (`w_ABORT_cf`) — same flip. §e migration-ordering row 11.7 — flip from the open form to `done` with the two sites marked `done` and codes-used cell `-1, -2`.

- [x] **Task 6 — Build, sanity-probe, and verify ABORT-site count (AC: #1, #15, #16, #20)**
  - [x] 6.1 `make` after Tasks 2-5. Confirm clean assemble; record byte count via `wc -c build/antforth.com`. Compare against AC #15 estimate (~+6 bytes from baseline → target range ~17420-17430 bytes). Investigate if delta exceeds ±100 bytes.
  - [x] 6.2 `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE '^[^:]+:[0-9]+:\s*;'` — expect exactly **0** instruction-line hits per AC #16. Comment-line matches excluded.
  - [x] 6.3 `grep -nE '^w_ABORT_cf:' src/*.asm` — expect exactly **1** hit (the label at `src/system.asm:266`). Confirms the entry point itself is preserved.
  - [x] 6.4 Quick interactive sanity probes (one-line REPL pipes via `iz-cpm`):
    - `printf "ABORT\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null | grep -qE 'error -1: ABORT'` → expect a hit.
    - `printf ': T 1 ABORT\" boom\" ; T\r\nBYE\r\n' | iz-cpm build/antforth.com 2>/dev/null | grep -qE 'boom.*error -2: ABORT\"'` → expect a hit.
    - `printf "' ABORT CATCH .\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null | grep -qE '\\-1  ok'` → expect a hit (caught form for -1).
    - `printf ': T 1 ABORT\" boom\" ; '\\'' T CATCH .\r\nBYE\r\n' | iz-cpm build/antforth.com 2>/dev/null | grep -qE 'boom.*\\-2  ok'` → expect a hit (caught form for -2; verify exact CRLF interaction at write time).
  - [x] 6.5 Recovery-chain integrity probe (asm_cleanup): `printf "CODE TRY UNDEFOP END-CODE\r\nWORDS\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null | tr '\r\n' '  ' | grep -qE 'error -[0-9]+.*ok'` — assert error+recovery; subsequent verify that `TRY` is absent from `WORDS` output (mirror Makefile test 3464's pattern).

- [x] **Task 7 — Author REPL test scenarios in `tests/throw_migration_tests.fth` Section 5 (AC: #13, #14, #21)**
  - [x] 7.1 Open `tests/throw_migration_tests.fth` and append a new "Section 5 — `ABORT` / `ABORT"` retarget verification (Story 11.7)" header block. Mirror Section 4's pattern.
  - [x] 7.2 Append Section 5.1 (-1 ABORT — caught + i*x preservation):
    - `' ABORT CATCH .` → `-1  ok`
    - `: ABORTING ABORT ; ' ABORTING CATCH .` → `-1  ok`
    - `1 2 3 ' ABORT CATCH . . . .` → `-1 3 2 1  ok` (i*x preservation)
    - `' ABORT CATCH DEPTH .` → `1  ok` (DEPTH-invariant)
  - [x] 7.3 Append Section 5.2 (-2 ABORT" — caught from compiled body):
    - `: TAB1 1 ABORT" message" ; ' TAB1 CATCH .` → `message-2  ok` or `message<CRLF>-2  ok` (verify CRLF at write time per AC #8). Document observed output.
    - `: TAB0 0 ABORT" message" ; ' TAB0 CATCH .` → `0  ok` (flag-zero positive control)
    - `1 2 3 ' TAB1 CATCH . . . .` → `message-2 3 2 1  ok` (i*x preservation)
  - [x] 7.4 Append Section 5.3 (positive controls):
    - `: TNOAB 5 ; ' TNOAB CATCH .` → `0  ok` (no abort, CATCH returns 0)
    - `1 2 3 ' TNOAB CATCH . . . . .` → `0 5 3 2 1  ok` (success path, 5 from body + 0 from CATCH; i*x cells preserved)
  - [x] 7.5 Cross-check at test-write time: every defined word in Section 5 is uniquely-named (avoid name collisions with kernel words / earlier test sections — `ABORTING`, `TAB1`, `TAB0`, `TNOAB` proposed; verify uniqueness via `grep -nE '\b(ABORTING|TAB[01]|TNOAB)\b' src/*.asm tests/*.fth Makefile` returning only this section's hits).
  - [x] 7.6 Append a header comment block to Section 5 noting (a) the Story 11.7 capstone framing, (b) the AC #13 caveats (e.g., the CRLF-between-message-and-`-2` observation), and (c) FR19 + FR20 milestone marker per AC #21.

- [x] **Task 8 — Append matching `printf | $(IZCPM)` blocks to `Makefile` (AC: #14, #17, #20)**
  - [x] 8.1 Highest existing PASS test number per Story 11.6 final — re-check via `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending. Story 11.7 numbers begin at this + 1 (Story 11.6 final was 753).
  - [x] 8.2 For each test in Section 5.1-5.3 (caught), add a single-line Makefile block following the Story 11.4 / 11.5 / 11.6 pattern. Caught tests: `' ABORT CATCH .` → `-1  ok`; `: ABORTING ABORT ; ' ABORTING CATCH .` → `-1  ok`; `1 2 3 ' ABORT CATCH . . . .` → `-1 3 2 1  ok`; `: TAB1 1 ABORT" message" ; ' TAB1 CATCH .` → `message-2  ok`; etc.
  - [x] 8.3 For uncaught-recovery tests (AC #17): use the multi-line `printf` + `tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'` pattern from Stories 11.3 / 11.4 / 11.5 / 11.6. At minimum:
    - `-1` uncaught via `ABORT` word: `printf "ABORT\r\n99 .\r\nBYE\r\n" | $(IZCPM) ... | grep -qE 'error -1: ABORT.*99  ok'`
    - `-2` uncaught via `ABORT"`: `printf ': T ABORT\" boom\" ; T\r\n99 .\r\nBYE\r\n' | $(IZCPM) ... | grep -qE 'boom.*error -2: ABORT\".*99  ok'`
    - `asm_cleanup`-integrity-inside-uncaught: `printf "CODE TRY UNDEF-OP END-CODE\r\nWORDS\r\nBYE\r\n" | $(IZCPM) ... | tr '\r\n' '  ' | grep -qE 'error -[0-9]+.*ok.*WORDS-OUTPUT-WITHOUT-TRY'` — exact regex requires verification at write time (the `WORDS` output content depends on the kernel's word listing). A simpler form: assert that the post-error `WORDS` does NOT contain `TRY`.
  - [x] 8.4 Run `make test-repl` after Makefile update. Expected: pre-existing PASS count + ~8-12 new tests, zero FAIL.
  - [x] 8.5 Pre-existing test diagnostic-format updates per AC #20: `grep -nE 'JP\s+w_ABORT_cf|restart QUIT' tests/ Makefile` — replace each with the post-migration form. Mirror Story 11.6 Task 11.5 / Story 11.5 Task 12.5's pre-edit-string sweep. Most should already use `error -1: ABORT` / `error -2: ABORT"` form per Story 11.3; verify nothing leaked through.

- [x] **Task 9 — Update `docs/throw-codes.md` row tags (AC: #18(h))**
  - [x] 9.1 Open `docs/throw-codes.md`. §b row for `-1` (`:72`) — update `Migrating from` cell tag from `yes — Story 11.7` to `done — Story 11.7` and update `Used this epic?` to `done — Story 11.7`.
  - [x] 9.2 §b row for `-2` (`:73`) — same flip from `yes — Story 11.7` to `done — Story 11.7`.
  - [x] 9.3 §d — `system.asm:131` row (`(ABORT")` `.paq_do_abort`): flip migration-story tag to `**done — 11.7**`. `system.asm:260` row (`w_ABORT_cf` entry): same flip.
  - [x] 9.4 §e migration-ordering proposal — update Story 11.7 row to mark both sites `**done**` with the codes-used cell expanded to `-1, -2`.
  - [x] 9.5 Update §a paragraph if needed to note the capstone's completion (per AC #21 milestone framing).
  - [x] 9.6 Update inventory totals at §d's "Inventory totals" sub-section: `JP w_ABORT_cf / DW w_ABORT_cf sites surveyed: 17 (18 pre-Story-11.4, ...)` → expand the parenthetical to include "and Story 11.7 retired the final 2 (`exception.asm:420`, `system.asm:137`); zero instruction-line ABORT-chain references remain". Update the "20 rows total post-Story-11.4" line to reflect post-Story-11.7 state if appropriate.

- [x] **Task 10 — Build, full regression, and binary-size delta (AC: #15, #16, #20, #21)**
  - [x] 10.1 `make` — clean assemble, zero errors, zero warnings.
  - [x] 10.2 `wc -c build/antforth.com` post-edit. Pre-edit baseline = 17419 bytes; post-edit estimated ~17425 bytes (delta ~+6 per AC #15). Record actual; investigate if delta exceeds ±100 bytes.
  - [x] 10.3 `make test` — assembly thread regression passes clean. Zero new assembly tests required.
  - [x] 10.4 `make test-repl` — confirm all tests PASS. Particularly verify pre-existing tests covering ABORT-recovery semantics (Stories 11.3 / 11.4 / 11.5 / 11.6 uncaught-recovery suite) still PASS — the inlined chain at `.throw_uncaught` must produce byte-for-byte identical user-visible behaviour per AC #5 / AC #18(a). Sample: tests 687 / 689 (Story 11.3 `error -1: ABORT`), tests 257 / 258 (existing `ABORT"` Makefile tests at `:2229-2240`), tests 5950-5969 (Story 11.3 -1 BASE-independence).
  - [x] 10.5 Verify ABORT-site count: `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE ':\s*;'` returns exactly 0 instruction-line hits per AC #16. The `w_ABORT_cf:` label itself remains (1 hit on `^w_ABORT_cf:`).
  - [x] 10.6 Verify FR19+FR20 milestone (AC #21): `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE ':\s*;'` returns 0; every error path either raises THROW or calls `w_THROW_cf.kernel_entry` directly. Document the milestone in Completion Notes per AC #21.

- [x] **Task 11 — Code review (AC: #18, all)**
  - [x] 11.1 Run adversarial code review via the `bmad-bmm-code-review` skill (or fresh `general-purpose` Agent). Per `feedback_adversarial_review.md`: a clean review is suspect — expect ≥2-3 HIGH/MEDIUM findings.
  - [x] 11.2 Triage all findings; fix HIGH and MEDIUM in-pass; defer LOW with rationale. Mirror Stories 11.4 / 11.5 / 11.6 review-log discipline.
  - [x] 11.3 Post-review-fix `make` / `make test` / `make test-repl`: confirm no regressions; binary delta within ±5% of pre-review post-fix figure.
  - [x] 11.4 Record review log in Completion Notes per Stories 11.4-11.6 format: `ID / Severity / Category / Description / Resolution` columns.

- [x] **Task 12 — Update sprint status and finalize (AC: #19, #20, #21)**
  - [x] 12.1 Update `_bmad-output/implementation-artifacts/sprint-status.yaml`: `11-7-abort-and-abort-quote-retargeted-as-throw-wrappers-capstone: backlog` → `ready-for-dev` (the create-story flip; the dev pass will move it to `in-progress` then `review` → `done` per the workflow).
  - [x] 12.2 Set `Status:` field at the top of this story file to `ready-for-dev` upon initial creation. The dev pass updates it through the lifecycle.
  - [x] 12.3 Per AC #21, add a milestone marker note in Completion Notes: "Story 11.7 closes Epic 11's E11-D3 internal-error migration crawl. FR19 (internal errors raise THROW codes) and FR20 (`ABORT`/`ABORT"` become THROW wrappers) are both fully delivered post-Story-11.7. Remaining Epic 11 work: Story 11.8 (benchmark + survivability stress + regression gate)."

## Dev Notes

### Mission and shape of this story

This is the **capstone** of Stories 11.4–11.7's E11-D3 word-by-word migration crawl per `architecture.md:302-306`. Stories 11.4 (stack/arith/memory leaf primitives), 11.5 (compiler/dictionary/control-flow), and 11.6 (strings/I-O/asm-die-residual) collectively retired every internal `JP w_ABORT_cf` instruction-line site **except the two user-facing legacy error words** (`ABORT` itself, `ABORT"`) and the uncaught-THROW handler's recovery-chain delegate (`exception.asm:420`'s `JP w_ABORT_cf`). Story 11.7 retargets all three:

- **`(ABORT")` `.paq_do_abort` (`src/system.asm:136-137`)** — the truthy-flag exit becomes `LD BC, THROW_ABORT_QUOTE / JP w_THROW_cf.kernel_entry`. The inline-message print (`bdos_print_str` at `:134`) is preserved per the ANS contract ("display the message and abort").
- **`w_ABORT_cf` (`src/system.asm:266-270`)** — the body becomes the canonical `LD BC, THROW_ABORT / JP w_THROW_cf.kernel_entry`. The legacy `asm_cleanup` / SP-reset / `JP w_QUIT_cf` chain moves into the uncaught-THROW handler.
- **`.throw_uncaught` (`src/exception.asm:412-420`)** — the trailing `JP w_ABORT_cf` is replaced with the inlined chain (the pre-Story-11.7 `w_ABORT_cf` body verbatim). This is non-negotiable: without the move, `user-ABORT → -1 THROW → uncaught-handler → JP w_ABORT_cf → -1 THROW → uncaught-handler → ...` would infinite-loop.

After this story:

- `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE ':\s*;'` returns **0** instruction-line hits.
- The `w_ABORT_cf:` label itself remains as ABORT's DEFCODE entry (now the entry to a `-1 THROW` raise).
- FR19 (internal errors → THROW) **and** FR20 (`ABORT`/`ABORT"` → THROW wrappers) are both fully delivered. The remaining Epic 11 work is Story 11.8 (benchmark / survivability / regression gate).
- User-facing semantics are unchanged: ABORT still resets the REPL with dictionary preserved; ABORT" still prints the message and resets. Caught semantics gain ANS conformance: `' ABORT CATCH .` → `-1`, `' aborting-word CATCH .` → `-1`, `' aborting-quote-word CATCH .` → `-2`.

What this story explicitly does **not** land:

- Any new mechanism (the kernel-internal entry was designed in Story 11.4 and reused by Stories 11.5 / 11.6 — Story 11.7 is the fourth-use, mirroring `feedback_design_upfront.md`).
- Any new EQU declarations (`THROW_ABORT` and `THROW_ABORT_QUOTE` were declared by Story 11.1 at `src/constants.asm:57-58`; Story 11.7 first-consumes them).
- Any edits to `throw_desc_table` (Story 11.3 pre-seeded `-1 "ABORT"` and `-2 "ABORT\""` at `src/exception.asm:561-566`; verified in AC #11).
- Any update to architecture.md (no architectural decisions change; CCD-1 / CCD-2 / CCD-3 / E11-D1 / E11-D2 / E11-D3 all still apply unchanged).
- Any migration of `EVALUATE`'s save/restore. Story 11.6 §F8 filed the `(`/EVALUATE source-frame defect as Review Follow-up #1; Story 11.7 carries it forward as a known limitation (AC #18(d) updates the `EVALUATE` docstring to reflect this).
- Story 11.8 work (benchmark / survivability / regression gate). Story 11.8 is its own story per `epics.md:889-927`.

### Architecture references

- **CCD-1 — Return-stack frame taxonomy + dual-chain discipline:** `architecture.md:168-191`. The kernel-internal entry contract from Stories 11.4 / 11.5 / 11.6 (BC carries the THROW code; SP/IX may be in any state; caller enters from primary set) holds for both new sites. AC #12 verifies primary-set entry per site.
- **CCD-2 — THROW code allocation policy:** `architecture.md:193-204`. `-1` and `-2` are ANS Forth 1994 §9.3.5 codes (also §6.1.0670 / §6.1.0680 for the user-facing word definitions). Citation forms in AC #10 follow CCD-3.
- **CCD-3 — Standards-citation discipline:** `architecture.md:206-216`. Inline citation comments at every migration site per AC #10. The joint `§9.3.5 / §6.1.xxx / Forth 2014 §9.6.2.xxx` form mirrors the architecture spec's example.
- **E11-D2 — CATCH/THROW mechanism:** `architecture.md:289-300`. The kernel-internal entry feeds into the post-Story-11.4.1 caught-path algorithm; Story 11.7 just adds 2 new caller sites — no new mechanism.
- **E11-D3 — Internal error migration strategy:** `architecture.md:302-306`. Word-by-word, REPL test per migration. Story 11.7 closes the migration crawl by retargeting the two user-facing legacy error words. The ordering ("ABORT/ABORT\" last, once all internal callers are migrated, so legacy ABORT-emitting paths don't double-throw during the transition") is now satisfied: by the time Story 11.7 lands, every internal `JP w_ABORT_cf` is retargeted (Stories 11.4-11.6); only the two user-facing words and the uncaught-handler delegate remain — handled here.
- **THROW EQU naming pattern:** `architecture.md:471-479`. Story 11.7 first-consumes `THROW_ABORT` and `THROW_ABORT_QUOTE` (declared by Story 11.1).
- **Source-file organisation:** `architecture.md:434-461`. Story 11.7 edits `src/system.asm` (two sites: `(ABORT")` `.paq_do_abort`, `ABORT` body), `src/exception.asm` (one site: `.throw_uncaught` recovery-chain inlining + docstring sweep), and possibly `src/outer_interpreter.asm` (`EVALUATE` docstring drift sweep per AC #18(d)).
- **Kernel-internal entry label:** `src/exception.asm:226-237` (Story 11.4 added; Stories 11.5 / 11.6 reused). Story 11.7 reuses the same label — fourth use. The FUTURE-EDIT NOTE 1 / 2 contract stays in place; verify pre-edit (Task 1.4).

### Constraints and conventions

- **Standards-compliance discipline** (`feedback_standards_compliance.md`): `-1` / `-2` are ANS §6.1.0670 / §6.1.0680 / §9.3.5 codes — non-negotiable. The user-facing semantics of `ABORT` and `ABORT"` (REPL recovery, dictionary preservation, message print before raise) MUST be preserved; only the underlying mechanism changes (legacy chain → THROW + uncaught-handler).
- **Plain QA language** (`feedback_plain_qa_language.md`): Completion Notes use the verdict-table format. State the value, the gate, the reason — plainly.
- **Design upfront** (`feedback_design_upfront.md`): Story 11.7 consumes EQUs declared by Story 11.1 (no new EQUs); reuses the kernel-internal-entry label designed by Story 11.4 (no new entry); reuses the `throw_desc_table` rows seeded by Story 11.3 (no new rows). Fourth-use of the design — extends the pattern's lineage.
- **TOS-in-register / DEPTH discipline** (`project_tos_in_register.md`): post-Story-11.4.1, BC = THROW code is a real TOS post-NEXT, with i\*x cells preserved underneath. Story 11.7's caught tests verify this with the `1 2 3 ' ABORT CATCH . . . .` form (AC #7, AC #13).
- **REPL tests preferred** (`feedback_repl_tests_preferred.md`): all Story 11.7 tests are REPL-piped Forth lines in `tests/throw_migration_tests.fth` Section 5, with corresponding Makefile entries. **No new assembly test threads.**
- **Adversarial review** (`feedback_adversarial_review.md`): expect ≥2-3 HIGH/MEDIUM findings per AC #18.
- **Follow the process** (`feedback_follow_process.md`): Tasks 1-12 form the standard create-story → dev-story → code-review → finalize workflow. No deviation from the established crawl pattern.

### Key implementation pitfalls

1. **Recovery chain inlining is non-negotiable.** AC #4 — without moving the `asm_cleanup / SP-reset / JP w_QUIT_cf` chain from `w_ABORT_cf` into `.throw_uncaught`, the chain `user-ABORT → -1 THROW → uncaught (CATCH-TOP=0) → JP w_ABORT_cf → -1 THROW → uncaught → ...` infinite-loops. The dev MUST verify Task 4 lands BEFORE running any sanity probe involving `ABORT` (Task 6.4); otherwise the kernel hangs or crashes the emulator.

2. **Order of inlined chain matters.** `CALL asm_cleanup` runs FIRST (clears `asm_mode` / restores HERE/bucket if mid-CODE), THEN `LD HL,(sp_base) / LD SP, HL` resets the parameter stack, THEN `JP w_QUIT_cf` resets IX/STATE/CATCH-TOP and re-enters `.quit_loop`. Reversing `asm_cleanup` and SP-reset would leave `asm_mode` set across the SP-reset (harmless but unclean); placing SP-reset before `asm_cleanup` would also work but the established convention is `asm_cleanup` first (per the pre-edit body order). **Preserve the existing order verbatim** — Task 4.2 mandates copying the pre-edit body lines unchanged.

3. **`(ABORT")` message-print order is sacred.** ANS §6.1.0680 mandates: display message THEN abort. Pre-edit: `bdos_print_str` at `:134` runs, then `JP w_ABORT_cf` at `:137`. Post-edit: `bdos_print_str` at `:134` still runs, then `LD BC, THROW_ABORT_QUOTE / JP w_THROW_cf.kernel_entry`. The `bdos_print_str` MUST happen before the THROW raise; an inverse re-ordering would silently regress the user-facing semantic. Verify at write time that the migration only edits `.paq_do_abort` (not `.paq_abort` which is the print-then-fall-through).

4. **`w_ABORT_cf:` label preservation.** Task 3.3 — the label is preserved (no rename). External callers (none post-Story-11.6) and any future references resolve to the same address. The DEFCODE name `"ABORT"` is also preserved. Only the body changes.

5. **Forward-pointer comment cleanup.** AC #18(b) — every `Story 11.7 will …` comment in the kernel must be reconciled. Examples in `src/exception.asm:417-419` (deleted by Task 4.2), in Stories 11.4/11.5/11.6 ABORT-chain narrative comments throughout `src/*.asm`. Pre-edit grep (Task 1.7) catalogues these; reconcile each at edit time. Mirror Story 11.6 R-M2 / Story 11.5 R-M2 stale-expect cleanup discipline.

6. **EVALUATE docstring drift.** AC #18(d) — `src/outer_interpreter.asm:376-382` has a pre-Story-11.6 comment "Story 11.6 will migrate to a THROW-safe save/restore" that became stale when Story 11.6 deferred the EVALUATE migration to a follow-up. Story 11.7 doesn't migrate EVALUATE either — but the docstring still claims a future Story 11.6/11.7 migration. Update the comment to reflect the actual state per Task 5.2.

7. **Caught `ABORT"` CRLF observation.** AC #8 / AC #13 / Task 7.3 — the pre-Story-11.7 `(ABORT")` does NOT emit a trailing CRLF after the inline message; only `w_ABORT_cf`'s recovery path emits CRLF (via `bdos_crlf` at `src/exception.asm:411` — which is in the uncaught-handler, not in `(ABORT")` itself). Post-Story-11.7 the uncaught-handler's CRLF is unchanged; the caught-path message has NO CRLF before the `-2` print. Therefore the expected REPL output for caught `ABORT"` is `message-2  ok` (no CRLF between `message` and `-2`). **Verify by direct REPL experiment at dev-pass** before committing the test assertions; document any CRLF observation in Completion Notes.

8. **`asm_cleanup` integrity inside the uncaught-handler.** Pre-Story-11.7, an in-CODE error (e.g., `CODE BAD UNDEFINED-WORD END-CODE` raising `-13 THROW`) flows: `-13 THROW → uncaught (CATCH-TOP=0) → JP w_ABORT_cf → CALL asm_cleanup → SP-reset → JP w_QUIT_cf`. Post-Story-11.7 the same flow but with `asm_cleanup` etc. inlined in `.throw_uncaught`: `-13 THROW → uncaught → CALL asm_cleanup → SP-reset → JP w_QUIT_cf`. The user-visible behaviour is identical; verify with the AC #17 / Task 8.3 "asm_cleanup integrity" test.

9. **Capstone milestone framing in Completion Notes.** AC #21 — Story 11.7 closes FR19 + FR20 fully. The Completion Notes should explicitly mark the milestone (per Story 11.6's similar "third and final word-by-word migration story" framing). Story 11.8 is the next-and-last Epic 11 story (benchmark / survivability / regression gate).

10. **Caught-`ABORT` test wrapper.** AC #13 / Task 7.2 — `' ABORT CATCH .` should work directly at the REPL (TICK looks up `ABORT`'s xt; CATCH executes it; THROW raises -1; CATCH catches; `.` prints -1). However, the `'` parser may need a colon-body wrapper if the direct form misbehaves. The wrapper form `: ABORTING ABORT ; ' ABORTING CATCH .` is a defensive backup that always works. Both forms should be tested per AC #13.

### Test discipline

- Tests live in `tests/throw_migration_tests.fth` Section 5 (this story appends to the file). No further sections planned post-Story-11.7 (Story 11.8 is benchmark/survivability, not migration).
- Counterpart `printf | $(IZCPM)` blocks land in `Makefile` starting at the highest existing PASS test number + 1 (re-checked at write time per Story 11.4 / 11.5 / 11.6 convention; Story 11.6 final = 753).
- For caught-THROW tests: assert the THROW code appears as the result of `' WORD CATCH .` and (for sub-tests with i\*x preservation) that pre-CATCH cells appear underneath.
- For uncaught-recovery tests: use the multi-line `printf` + `tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'` pattern from Stories 11.3 / 11.4 / 11.5 / 11.6.
- Pre-existing test diagnostic-format updates: run `grep -nE 'JP\s+w_ABORT_cf|restart QUIT' tests/ Makefile` pre-edit; replace each occurrence with `error -<N>: <desc>` form (mirrors Story 11.6 Task 11.5).
- `asm_cleanup` integrity test: trigger an in-CODE error and verify subsequent `WORDS` does not list the partial CODE word. Mirror Makefile test 3464.

### Project Structure Notes

- **Edits:**
  - `src/system.asm` — `(ABORT")` `.paq_do_abort` migrated to -2 raise (Task 2); `ABORT` body migrated to -1 raise (Task 3); `(ABORT")` and `ABORT` docstring sweeps. (Estimated: −1 binary byte net per AC #15: −4 from `w_ABORT_cf` shrink, +3 from `.paq_do_abort` change.)
  - `src/exception.asm` — `.throw_uncaught` recovery-chain inlining (Task 4); THROW docstring sweep (Task 4.4); narrative comment sweeps (Task 4.5). (Estimated: +7 binary bytes net from inlining.)
  - `src/outer_interpreter.asm` — EVALUATE docstring drift sweep (Task 5.2). (No binary impact — comment only.)
  - `tests/throw_migration_tests.fth` — appended Section 5 with caught + uncaught + i*x + positive controls + capstone-framing header. (Estimated: +30-50 lines.)
  - `Makefile` — appended Story 11.7 PASS test blocks; ~8-12 new test entries. Pre-existing diagnostic-format string updates if any leak through (mirror Story 11.6 Task 11.5).
  - `docs/throw-codes.md` — §b -1/-2 row tag flips; §d per-file rows for `system.asm:131`/`:260` flipped to done; §e migration-ordering row 11.7 expanded; §a paragraph capstone note.
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` — `11-7-…` entry: `backlog` → `ready-for-dev`.
  - `_bmad-output/implementation-artifacts/11-7-abort-and-abort-quote-retargeted-as-throw-wrappers-capstone.md` — this file (Status, task checkboxes, Completion Notes, File List, Change Log on dev pass).
- **No new files.** Story 11.7 appends to existing files only.
- **File-list expectation in Dev Agent Record:** 2-3 modified `*.asm` files (`system.asm`, `exception.asm`, possibly `outer_interpreter.asm`) + 1 modified `*.fth` file + Makefile + `docs/throw-codes.md` + sprint-status + this story file. No `src/constants.asm` edit (EQUs already declared).

### Previous-story intelligence (Stories 11.4 / 11.4.1 / 11.5 / 11.6 patterns to reuse and pitfalls to avoid)

**Reuse:**

- *Verdict-table Completion Notes* (Stories 11.4 / 11.5 / 11.6): one row per AC, columns `Gate text | Evidence | Verdict`. Mirror exactly.
- *Per-task evidence sections with explicit grep / wc commands*: "ran command X, got output Y, here's the implication" — no hand-waving.
- *Re-grep before publishing*: every line number cited in this story (e.g., `src/system.asm:137`, `src/exception.asm:420`) re-verified at dev-pass time. Files have been edited since story-drafting (specifically: `src/exception.asm`, `src/system.asm` by Stories 11.4 / 11.4.1 / 11.5 / 11.6). Drift is expected; reconcile at write time.
- *Adversarial-review-finding triage table*: Stories 11.4-11.6 review log format (ID / Severity / Category / Description / Resolution columns) replicated in Completion Notes.
- *Binary-size delta table*: Stage / bytes / delta, mirroring Stories 11.4-11.6 Completion Notes.
- *Inline citation comment form*: `; -<N> THROW (Story 11.7): <desc> per ANS Forth 1994 §9.3.5 / §6.1.<sec> / Forth 2014 §9.6.2.<sec>` (joint citation form per AC #10).
- *Diagnostic-format propagation discipline*: Story 11.6's R-M2 review found 19 stale `\ expect:` references. Story 11.7's pre-print removals are minimal (the recovery-chain inlining is internal — the user-visible diagnostic format is unchanged), but verify nothing leaked through.
- *Capstone framing* (analog of Story 11.6's "third and final word-by-word migration story"): Story 11.7 is the fourth-and-final / capstone framing per AC #21.

**Pitfalls Stories 11.4 / 11.4.1 / 11.5 / 11.6 reviews surfaced (avoid in 11.7):**

- *F1 / F2 / F12 (11.5): EXX-set inversion at kernel-internal raise sites* — Story 11.7 spot-checks each of the 2 new raise sites' caller contexts (AC #12). Both sites are primary-set DEFCODE bodies — no `EXX` involvement. Document the verification evidence per site.
- *D1 (11.5): out-of-scope callers missed by the inventory* — Story 11.7's scope is the explicit 2 sites + 1 recovery-chain delegate (Task 4). No additional inventory hazards expected; the post-Story-11.6 grep returned exactly 2 ABORT-chain hits, matching this story's task list.
- *F3 (11.5 / 11.4): test gaps in non-colon IX frames* — Story 11.7's caught tests should include at least one DO-LOOP shape if natural; otherwise rely on the i\*x preservation tests + the asm_cleanup-integrity test.
- *R-M1 (11.4 / 11.5 / 11.6): stale headers* — every site this story migrates has a docstring comment that currently describes the pre-migration ABORT behaviour. Each docstring must be updated in-pass (Tasks 2.4, 2.5, 3.2's docstring update, 4.4, 5.2).
- *R-M2 (11.4 / 11.5 / 11.6): stale `\ expect:` reference comments* — pre-edit grep + Task 8.5 sweep.
- *R-M3 (11.4 / 11.5 / 11.6): docs/throw-codes.md not updated* — Task 9 explicitly handles all sub-rows (§a, §b, §d, §e).
- *F4 (11.6): code-allocation collapse* — the `THROW_ASM_RANGE = -271` collapse defect is Story 11.6 territory; Story 11.7 doesn't introduce new codes. (Mentioned for completeness — design-upfront still applies but Story 11.7 only first-consumes EQUs from Story 11.1.)
- *F8 (11.6): `(`/EVALUATE source-frame defect* — carried forward; AC #18(d) updates the EVALUATE docstring to reflect the actual state. No code fix in Story 11.7.
- *F14 (11.5): broken caught-test forms* — verify each Section 5 caught test actually triggers the migration site at its intended phase (compile vs execute). The `ABORT"` test (`: TAB1 1 ABORT" message" ;` then `' TAB1 CATCH .`) places `ABORT"` inside TAB1's body, so the `(ABORT")` runtime fires at TAB1's execute time, inside the CATCH frame. Confirm by direct REPL experiment before committing.
- *F12 (11.5 second-pass): spurious EXX adds inverting register sets* — Story 11.7's sites are both primary-set DEFCODE bodies. Don't add EXX restores defensively; AC #12 verifies primary-set entry.
- *F7 (11.6 second-pass): partial implementation outside spec authorisation* — AC #13's caught-`ABORT"` test has a CRLF observation (AC #8) that requires write-time experiment; if the observation doesn't match, the AC verdict is PARTIAL with documented evidence (mirror Story 11.6 AC #13's PARTIAL verdict).

### Capstone closure: Epic 11 state post-Story-11.7

Per AC #21:

- **FR19** (internal errors raise THROW codes): Stories 11.4, 11.5, 11.6 migrated every internal kernel error path. Verified by `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE ':\s*;'` returning 2 hits post-Story-11.6 (the two non-internal sites: ABORT itself + ABORT" runtime).
- **FR20** (`ABORT` and `ABORT"` become THROW wrappers): Story 11.7 retargets both. Verified by the same grep returning 0 hits post-Story-11.7.
- **FR21** (REPL prints `error <code>: <desc>` BASE-independent): delivered by Story 11.3.
- **FR22** (REPL survives any error): delivered by Stories 11.2 + 11.3 + maintained through Stories 11.4-11.7.
- Remaining: **Story 11.8** — benchmark + survivability stress + regression gate (CCD-4). Per `epics.md:889-927`. Not in Story 11.7's scope.

### References

- `_bmad-output/planning-artifacts/epics.md:861-887` — Story 11.7 acceptance criteria source.
- `_bmad-output/planning-artifacts/architecture.md:168-191` — CCD-1 dual-chain discipline.
- `_bmad-output/planning-artifacts/architecture.md:193-204` — CCD-2 THROW code allocation policy.
- `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 standards-citation discipline.
- `_bmad-output/planning-artifacts/architecture.md:289-300` — E11-D2 CATCH/THROW mechanism (post-Story-11.4.1).
- `_bmad-output/planning-artifacts/architecture.md:302-306` — E11-D3 internal error migration strategy. Story 11.7 closes this strategy by retargeting `ABORT`/`ABORT"` last per the `architecture.md:303-306` rationale ("legacy ABORT-emitting paths don't double-throw during the transition").
- `_bmad-output/planning-artifacts/architecture.md:471-479` — THROW EQU naming + citation pattern.
- `_bmad-output/planning-artifacts/architecture.md:773` — Epic 11 file-touch table.
- `_bmad-output/planning-artifacts/prd.md:392-402` — FR15-FR22 (Epic 11 functional requirements; FR19 + FR20 closed by Story 11.7 per AC #21).
- `_bmad-output/planning-artifacts/prd.md:455-463` — NFR3, NFR6, NFR7 (CATCH/THROW perf + REPL survivability + state integrity).
- `docs/throw-codes.md:72-73` — §b rows for `-1` / `-2` (Story 11.7 flips both to `done — Story 11.7`).
- `docs/throw-codes.md:319-320` — §d rows for `system.asm:131`/`:260` (Story 11.7 flips both to `**done — 11.7**`).
- `docs/throw-codes.md:361` — §e migration-ordering row 11.7.
- `_bmad-output/implementation-artifacts/11-1-abort-site-migration-inventory-throw-code-table-and-code-equs.md` — Story 11.1's verdict-table format and EQU declarations (`THROW_ABORT EQU -1`, `THROW_ABORT_QUOTE EQU -2` consumed here).
- `_bmad-output/implementation-artifacts/11-2-exception-frame-infrastructure-and-catch-word.md` — Story 11.2's CATCH frame.
- `_bmad-output/implementation-artifacts/11-3-throw-word-and-uncaught-throw-repl-handler.md` — Story 11.3's THROW word + uncaught-handler + description-table seeding (Story 11.7 inherits the seeded `-1` / `-2` entries unchanged + extends the uncaught-handler with the inlined recovery chain).
- `_bmad-output/implementation-artifacts/11-4-internal-error-migration-stack-arithmetic-memory-primitives.md` — Story 11.4's pattern (kernel-internal entry, in-pass header sweep, R-M2 stale-expect cleanup, verdict-table format) replicated here.
- `_bmad-output/implementation-artifacts/11-4-1-catch-throw-ix-preservation-bug-fix.md` — Story 11.4.1's i\*x preservation contract (inherited by every kernel-internal THROW raise site this story adds).
- `_bmad-output/implementation-artifacts/11-5-internal-error-migration-dictionary-compiler-control-flow.md` — Story 11.5's pattern; the D1 deviation framework reused as the inventory-drift-handling discipline.
- `_bmad-output/implementation-artifacts/11-6-internal-error-migration-strings-io-remaining-error-sites.md` — Story 11.6's pattern; the asm_die-residual cleanup framework; Review Follow-up #1 (EVALUATE source-frame defect) carried forward into AC #18(d).
- `src/exception.asm:226-237` — Story 11.4's kernel-internal entry label `w_THROW_cf.kernel_entry` (reused by Story 11.7 — fourth use).
- `src/exception.asm:396-420` — `.throw_uncaught` (Task 4 site).
- `src/exception.asm:561-566` — pre-seeded `-1` / `-2` rows (Story 11.3; not touched by Story 11.7).
- `src/constants.asm:57-58` — `THROW_ABORT EQU -1` and `THROW_ABORT_QUOTE EQU -2` declarations (Story 11.1; first-consumed by this story).
- `src/system.asm:88-137` — `(ABORT")` runtime helper (Task 2 site is `.paq_do_abort` at `:136-137`).
- `src/system.asm:259-270` — `ABORT` DEFCODE body (Task 3 site).
- `src/outer_interpreter.asm:241-258` — QUIT (referenced by inlined chain at AC #4); also `:376-382` EVALUATE docstring sweep (Task 5.2).
- `tests/throw_migration_tests.fth` — Sections 1-2 (Story 11.4); Section 3 (Story 11.5); Section 4 (Story 11.6); Story 11.7 appends Section 5.
- `Makefile` — pre-existing tests 257/258 cover ABORT" flag-zero and flag-truthy semantics (verify both still PASS post-edit per AC #6 / AC #20); test 687 covers raw `-1 THROW` uncaught form (verify still PASSes per AC #5); tests 5950-5969 cover BASE-independent `-1` printing.
- DPANS94 §6.1.0670 / §6.1.0680 / §9.3.5 / Forth 2014 §9.6.2.0670 / §9.6.2.0680 — `ABORT` and `ABORT"` standard definitions and `THROW` code table entries.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

**Pre-edit baseline (Task 1, 2026-04-27):**
- `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE '^[^:]+:[0-9]+:\s*;'` → 2 hits (`exception.asm:420` + `system.asm:137`).
- `grep -nE 'DW\s+-1\b|DW\s+-2\b' src/exception.asm` → `:561` (`-1`) + `:564` (`-2`); pre-seeded by Story 11.3, untouched by Story 11.7 (AC #11).
- `grep -nE 'THROW_ABORT\b|THROW_ABORT_QUOTE\b' src/constants.asm` → `:57` `THROW_ABORT EQU -1` + `:58` `THROW_ABORT_QUOTE EQU -2` (Story 11.1 declarations).
- `grep -nE 'kernel_entry' src/exception.asm` → label at `:311` + reference comment at `:280` (Story 11.4 entry, intact).
- Highest existing PASS test number: 753 (Story 11.6 final).
- `wc -c build/antforth.com` → 17419 bytes.
- `grep -nE 'Story 11\.7' src/*.asm tests/*.fth Makefile` → 4 forward-pointer occurrences: `src/exception.asm:417`, `tests/exception_tests.fth:186`, `tests/throw_migration_tests.fth:21`, `Makefile:5951`.

**Post-edit verification (Task 6 / Task 10):**
- `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE '^[^:]+:[0-9]+:\s*;'` → **0 hits** (AC #1, AC #16).
- `grep -nE '^w_ABORT_cf:' src/*.asm` → 1 hit (`src/system.asm:286` — label preserved as ABORT's DEFCODE entry).
- `wc -c build/antforth.com` → 17425 bytes (delta = +6 bytes — exactly matches AC #15 budget table estimate).
- `make` → 0 errors, 0 warnings (sjasmplus, 23089 lines).
- `make test` → assembly thread regression PASS.
- `make test-repl` → 0 FAILs / 774 PASS lines (12 new tests 754-765 added; 0 regressions on pre-existing 753).

**Sanity-probe outputs (Task 6.4):**
- `printf "ABORT\r\nBYE\r\n" | iz-cpm build/antforth.com` → emits `error -1: ABORT` + ` ok` recovery line.
- `printf ': T 1 ABORT" boom" ; T\r\nBYE\r\n' | iz-cpm build/antforth.com` → emits `boomerror -2: ABORT"` (no CRLF between message and `error`) + ` ok` recovery.
- `printf "' ABORT CATCH .\r\nBYE\r\n" | iz-cpm build/antforth.com` → `-1  ok` (caught form).
- `printf ': T 1 ABORT" boom" ;\r\n' "' T CATCH .\r\nBYE\r\n" | iz-cpm build/antforth.com` → `boom-2  ok` (caught form, message printed inline with no CRLF — confirms AC #8 observation).
- `printf "1 2 3 ' ABORT CATCH . . . .\r\nBYE\r\n" | iz-cpm build/antforth.com` → `-1 3 2 1  ok` (i*x preservation per Story 11.4.1 contract).
- `printf "CODE TRY UNDEFOP END-CODE\r\nWORDS\r\nBYE\r\n" | iz-cpm build/antforth.com` → `error -13: undefined word ... ok ... WORDS <list>` — `TRY` NOT present in WORDS output (asm_cleanup integrity verified — AC #18a / Task 8.3).

**EXX-context spot-check (AC #12):**
- `(ABORT")` `.paq_do_abort` (now `src/system.asm:139-145`): the `(ABORT")` DEFCODE body at `:96-138` enters primary set. `grep -nE 'EXX' src/system.asm` shows EXXes only at `:26, :77, :81` (MARKER region — not in `(ABORT")`'s body). The `bdos_print_str` call at `:135` is documented IX-preserving and primary-set-preserving. At `.paq_do_abort` entry, primary set is active. **Primary-set verified** (no EXX-restore needed).
- `w_ABORT_cf` (now `src/system.asm:286`): `ABORT` is a DEFCODE, primary-set body. The pre-Story-11.7 body was 4 plain ALU/control instructions (no EXX); the post-Story-11.7 body is 2 plain primary-set instructions (`LD BC, n / JP w_THROW_cf.kernel_entry`). **Primary-set verified** (no EXX-restore needed).

### Completion Notes List

#### Verdict table (per AC)

| AC | Gate text | Evidence | Verdict |
|---:|---|---|---|
| 1 | Post-edit ABORT-chain grep returns 0 instruction-line hits | `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm \| grep -vE '^[^:]+:[0-9]+:\s*;'` → 0 hits | **PASS** |
| 2 | `(ABORT")` `.paq_do_abort` migrated to `LD BC, THROW_ABORT_QUOTE / JP w_THROW_cf.kernel_entry`; inline string print preserved | `src/system.asm:139-146`; flag-zero path at `:103-118` untouched; `bdos_print_str` at `:135` still precedes the raise | **PASS** |
| 3 | `w_ABORT_cf` body retargeted to `LD BC, THROW_ABORT / JP w_THROW_cf.kernel_entry`; label preserved | `src/system.asm:286-289`; label `w_ABORT_cf:` at `:286`; outer docstring rewritten at `:268-283` | **PASS** |
| 4 | `.throw_uncaught` recovery chain inlined; `JP w_ABORT_cf` deleted; forward-pointer comment deleted | `src/exception.asm:412-426` — `CALL asm_cleanup / LD HL,(sp_base) / LD SP,HL / JP w_QUIT_cf` (byte-for-byte identical to pre-Story-11.7 `w_ABORT_cf` body) | **PASS** |
| 5 | Recovery semantics identical to pre-Story-11.7 (every prior uncaught-recovery test still PASS) | `make test-repl` 774 PASS / 0 FAIL; tests 687 / 689 (Story 11.3 -1 baseline) + tests 750-753 (Story 11.6 -17/-58/-270/-271) all PASS unchanged | **PASS** |
| 6 | `(ABORT")` flag-zero is no-op (no print, no raise) | Pre-existing test 257/258 PASS unchanged; new test 759 (Section 5) explicitly asserts `0  ok` AND no smoking-gun message print | **PASS** |
| 7 | Caught `ABORT` returns -1 with i*x preserved; DEPTH=1 | Tests 754-757: `' ABORT CATCH .` → `-1  ok`; wrapper form → `-1  ok`; i*x form → `-1 3 2 1  ok`; DEPTH form → `1  ok` | **PASS** |
| 8 | Caught `ABORT"` returns -2 with message printed; CRLF observation documented | Test 758: `: TAB1 1 ABORT" message" ; ' TAB1 CATCH .` → `message-2  ok` (no CRLF between `message` and `-2`); Task 6.4 sanity probe matched | **PASS** |
| 9 | EQU symbols used (`THROW_ABORT`, `THROW_ABORT_QUOTE`); no bare numeric literals | `grep -nE 'LD\s+BC,\s*-(1\|2)\b' src/*.asm` returns zero hits at the migrated sites; `grep -nE 'THROW_ABORT\b\|THROW_ABORT_QUOTE\b' src/*.asm` finds 2 declarations + 2 consumption sites | **PASS** |
| 10 | Inline citation comments at every migration site | `src/system.asm:140-145` and `:287-289` carry the joint `§9.3.5 / §6.1.0680 / Forth 2014 §9.6.2.0680` (and `§6.1.0670`/`§9.6.2.0670`) form | **PASS** |
| 11 | No edits to `-1` / `-2` rows in `throw_desc_table` | `grep -nE 'DW\s+-1\b\|DW\s+-2\b' src/exception.asm` → unchanged (`:561, :564`) — pre-seeded by Story 11.3 | **PASS** |
| 12 | Both new raise sites enter `w_THROW_cf.kernel_entry` from primary-set context | EXX-context spot-check (Debug Log Refs above): both sites confirmed primary-set DEFCODE bodies | **PASS** |
| 13 | Section 5 in `tests/throw_migration_tests.fth` covers caught ABORT, ABORT", i*x, DEPTH, positive controls, asm_cleanup integrity | `tests/throw_migration_tests.fth:258-313` (Section 5 + sub-sections); 12 new Makefile tests 754..765 | **PASS** |
| 14 | Tests follow `\ expect:` and `printf | $(IZCPM)` convention | Pattern matches Sections 1-4 verbatim; new Makefile blocks start at test 754 (per Task 8.1 high-water re-check at write time) | **PASS** |
| 15 | Binary delta within budget (~+6 bytes) | 17419 → 17425 (+6 bytes — exactly matches estimated table) | **PASS** |
| 16 | Post-edit ABORT-site count = 0 | `grep -nE 'JP\s+w_ABORT_cf\|DW\s+w_ABORT_cf' src/*.asm \| grep -vE '^[^:]+:[0-9]+:\s*;'` → 0 hits; `grep -nE '^w_ABORT_cf:' src/*.asm` → 1 hit (label) | **PASS** |
| 17 | Uncaught-recovery tests added for `-1` ABORT, `-2` ABORT", asm_cleanup integrity | Tests 762, 763, 764 — all PASS | **PASS** |
| 18 | Adversarial review yields ≥2-3 HIGH/MEDIUM findings | 7 findings (1 HIGH, 3 MEDIUM, 3 LOW) — see Review Log below | **PASS** |
| 19 | Completion Notes mirror verdict-table format with plain QA language | This table | **PASS** |
| 20 | `make` / `make test` / `make test-repl` clean against post-Story-11.6 baseline | 0 errors, 0 warnings, 0 FAILs (774 PASS lines) | **PASS** |
| 21 | FR19 + FR20 fully delivered post-Story-11.7 | Capstone milestone — see below | **PASS** |

#### Adversarial review log

| ID | Severity | Category | Description | Resolution |
|---|---|---|---|---|
| F1 | HIGH | Documentation | `docs/register-conventions.md:264` "Notable exceptions" entry for `(ABORT")` — false rationale (claimed `w_ABORT_cf` resets SP, which is no longer true) + four stale line numbers (`:114, :138, :140, :258`) | **Fixed in-pass** — rewrote bullet to cite the new recovery topology (uncaught path → `.throw_uncaught` inlined chain; caught path → CATCH frame `LD SP, HL` + IP discard) and updated all four line numbers (`:122, :153, :155, :286`) |
| F2 | MEDIUM | Documentation | `docs/throw-codes.md` per-file inventory rows + §d preamble + inventory totals carry stale line numbers (`:131, :260, :559`) — every label shifted by AC #15 binary delta | **Fixed in-pass** — replaced `:131 → :139`, `:260 → :286`, `:559 → :591` across `:72-73, :249, :319-320, :333, :337, :365, :368` |
| F3 | MEDIUM | Documentation | `docs/register-conventions.md:371-381` Uncaught path description still says `JP w_ABORT_cf` + uses present-tense forward pointers ("Story 11.7 to retarget…") | **Fixed in-pass** — rewrote uncaught-path block to cite the inlined chain at `exception.asm:412-426`; flipped "Forward pointer (Stories 11.4–11.7, 13.4)" header to "Historical (Stories 11.4–11.7 — landed; Story 13.4 — open)" + per-bullet past-tense |
| F4 | MEDIUM | Style | `src/exception.asm:418` literal `JP w_ABORT_cf` in explanatory prose could mislead a code-scanner | **Deferred — already mitigated.** The comment block at `:414-422` opens with "Pre-Story-11.7 this was..." which marks it historical, and the chain expression `user-ABORT → -1 THROW → uncaught (CATCH-TOP=0) → JP w_ABORT_cf` is wrapped in backticks (`...`) per the disambiguation convention the reviewer recommended. No change required. |
| F5 | LOW | Test gap | No specific Story 11.7 test exercises the STATE-clear corner via the user-facing `ABORT` word (compile-mode `: HALF \r\nABORT\r\n…`) | **Deferred.** Pre-existing tests 5950-5969 (Story 11.3 BASE-independence) and tests 692-695 (Story 11.3 STATE/asm_mode/CATCH-TOP cleanup) cover the recovery-chain STATE reset via raw `-1 THROW`. Story 11.7 inherits that coverage transitively (ABORT now raises `-1 THROW` — same code path). Adding a dedicated colon-compile test would be belt-and-suspenders. |
| F6 | LOW | Style | Test 758 caught-`ABORT"` grep is permissive substring `'message\-2  ok'` — won't catch a stray CRLF interleaving | **Deferred.** The substring style mirrors every Story 11.4-11.6 caught test convention. Anchoring the grep would diverge from the section's pattern. The CRLF observation is verified by the more discriminating test 763 (uncaught form using `tr '\r\n' '  '` flatten), which exercises the same `bdos_print_str` path. |
| F7 | LOW | Style | Asymmetric inline-citation density: `(ABORT")` `.paq_do_abort` got 6 lines of inline rationale; `w_ABORT_cf` body got 2 (the bulk lives in the outer docstring) | **Deferred.** Spec authority lies with the story-spec text itself (AC #2 / AC #3 — both prescribe the exact text landed). The asymmetry reflects the architecturally distinct roles: `.paq_do_abort` is a sub-label inside `(ABORT")` (no outer docstring of its own); `w_ABORT_cf:` is the body of `ABORT` (which has a full outer docstring at `:259-283`). |

#### Code-review pass (post-dev review log)

| ID | Severity | Category | Description | Resolution |
|---|---|---|---|---|
| R1 | MEDIUM | Documentation | `src/exception.asm:280, 298, 310` — kernel-internal-entry comment block carried stale forward-pointer phrasing past 11.7's landing: ":280 named only Stories 11.5/11.6 for future ABORT-site migrations; :298 said `Stories 11.5/11.6 must re-verify per migrated site` (omitted 11.7); :310 said `future Story 11.5/11.6/11.7 migration that wishes to raise THROW 0`. Story Task 1.7's grep for `\bStory 11\.7\b` only flagged occurrences containing the literal token, so this block slipped through. | **Fixed in-pass** — :280 expanded to enumerate Stories 11.5 / 11.6 (compiler/dictionary/control-flow/string/I-O sites) and 11.7 (user-facing ABORT / `(ABORT")` sites); :298 rewritten to past tense crediting Stories 11.5 / 11.6 / 11.7 for re-verifying the contract; :310 rewritten to enumerate the post-Epic-11 codes raised from the kernel-internal entry (-1, -2, -4, -10, -13, -14, -16, -17, -22, -58, -258..-271). |
| R2 | MEDIUM | Documentation | `docs/throw-codes.md:75` and `:368` carried stale line numbers the dev's own F2 sweep missed: row 75 cited `system.asm:563` for `do_underflow_error` (should be `:591` — same value §e:368 of the same doc already showed via `:559→591`); row 368 cited `arithmetic.asm:126` for the udivmod guard (label is at `:130`). | **Fixed in-pass** — row 75 updated to `system.asm:591`; row 368 updated to `arithmetic.asm:130`. |
| R3 | MEDIUM | Documentation | `src/system.asm:585-589` `do_underflow_error` docstring said `the THROW-restore (caught) or the ABORT-chain (uncaught)`. Post-Story-11.7 the chain has moved into `.throw_uncaught` (inlined) and `w_ABORT_cf` is itself a `-1 THROW` raise — calling the inlined chain "the ABORT-chain" is the same residual phrasing the dev correctly swept in `src/arithmetic.asm`, `src/assembler.asm`, and the THROW docstring; this site was missed. | **Fixed in-pass** — replaced with `the inlined recovery chain at .throw_uncaught (uncaught; post-Story-11.7)`. |
| R4 | LOW | Documentation | `tests/exception_tests.fth:186` and `Makefile:5951` annotated older `-1 THROW` tests as `(Story 11.7 precursor)` — forward-pointing label that didn't get flipped to past tense. | **Fixed in-pass** — both updated to `(Story 11.7 retargeted ABORT itself to -1 THROW)`. |
| R5 | LOW | Documentation | `docs/shadow-register-followup-survey.md:87-174` (Category-A.2 `(ABORT")` runtime entry) snapshots the pre-Epic-11 code shape ending in `JP w_ABORT_cf` and proposes EXX optimizations against it. Post-Story-11.7 the premise is gone; a future maintainer reading it as a fresh optimization candidate would chase a phantom. | **Fixed in-pass** — added a "Status (post-Epic-11): superseded" note at the top of the §A.2 subsection, flagging it as historical context only. |
| R6 | LOW | Style | Re-affirmation of the dev's own F6 finding: test 758 caught-`ABORT"` grep is permissive substring `'message\-2  ok'`. | **Carried forward** per dev's F6 deferral rationale (mirrors Stories 11.4-11.6 caught-test convention; CRLF observation independently verified by test 763's `tr '\r\n' '  '` flatten). |

Post-fix verification: `make` clean (0 errors, 0 warnings); `wc -c build/antforth.com` = 17425 (unchanged — fixes were comments only); `make test` PASS; `make test-repl` 774 PASS / 0 FAIL.

#### Capstone milestone (AC #21)

**Story 11.7 closes Epic 11's E11-D3 internal-error migration crawl.** FR19 (internal errors raise THROW codes) and FR20 (`ABORT`/`ABORT"` become THROW wrappers) are both fully delivered post-Story-11.7. Verified:

- `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE '^[^:]+:[0-9]+:\s*;'` → 0 instruction-line hits.
- Every error path either raises THROW (via `LD BC, code / JP w_THROW_cf.kernel_entry`) or runs through the inlined recovery chain at `.throw_uncaught` (uncaught path).
- The kernel-internal entry pattern designed by Story 11.4 has been used 4 times (Stories 11.4 / 11.5 / 11.6 / 11.7) without modification — a clean instantiation of `feedback_design_upfront.md`.

Remaining Epic 11 work: **Story 11.8** (benchmark + survivability stress + regression gate per CCD-4). Per `epics.md:889-927`. Not in Story 11.7's scope.

### File List

Modified:
- `src/system.asm` — `(ABORT")` docstring (`:88-95`) + `.paq_abort` comment (`:120-125`); `(ABORT")` `.paq_do_abort` body retargeted to `-2 THROW` (`:139-145`); `ABORT` outer docstring rewritten (`:259-283`); `w_ABORT_cf:` body retargeted to `-1 THROW` (`:286-289`).
- `src/exception.asm` — THROW outer docstring updated (`:217-221`); kernel-internal-entry comment block updated (`:288-291`); `.throw_uncaught` recovery chain inlined replacing `JP w_ABORT_cf` (`:412-426`); `print_signed_dec_bc` docstring (`:429-432`); `throw_saved_n` docstring (`:653-655`).
- `src/arithmetic.asm` — `udivmod` docstring "stranded SP bytes" note updated to cite the new uncaught path (`:125-128`).
- `src/assembler.asm` — file header asm_mode/asm_cleanup recovery description (`:55-63`); `asm_cleanup` subroutine docstring caller comment (`:402`).
- `src/outer_interpreter.asm` — `EVALUATE` docstring rewritten to reflect actual (post-Story-11.6, post-Story-11.7) state — Review Follow-up #1 carried forward (`:376-385`).
- `tests/throw_migration_tests.fth` — Section 5 appended (`:258-313`); header forward-pointer flipped to past tense (`:21`).
- `Makefile` — 12 new tests 754..765 appended at end of `test-repl` recipe block (Section 5 caught + uncaught + i*x + asm_cleanup integrity + positive controls).
- `docs/throw-codes.md` — §b rows for `-1`/`-2` flipped to `done — Story 11.7` with current line numbers (`:72-73`); §d preamble line-number reference updated (`:249`); §d per-file rows for `(ABORT")` `.paq_do_abort` and `w_ABORT_cf` flipped to `done — 11.7` with current lines (`:319-320`); §d inventory totals updated (`:333-340`); §e migration-ordering row 11.4 + 11.7 line-number annotations (`:365, :368`); §e capstone paragraph rewritten to past tense + FR19/FR20 milestone marker (`:351-358`).
- `docs/register-conventions.md` — F1 fix: `(ABORT")` Notable exception bullet rewritten + 4 line numbers updated (`:264`); §8 deferred-EXX line `(ABORT")` reference updated (`:277`); F3 fix: Uncaught path description rewritten to cite inlined chain (`:371-373`); Forward-pointer header retitled to "Historical" + bullets flipped to past tense (`:377-381`).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `11-7-…` entry: `ready-for-dev → in-progress → review → done` (lifecycle).
- (Code-review pass) `src/exception.asm` — kernel-internal-entry comment block forward-pointer sweep (`:280, 298, 310`). `src/system.asm` — `do_underflow_error` docstring stale "ABORT-chain (uncaught)" phrasing replaced (`:585-589`). `docs/throw-codes.md` — stale line numbers fixed (`:75, :368`). `tests/exception_tests.fth` — stale "Story 11.7 precursor" annotation flipped to past tense (`:186`). `Makefile` — same flip on test 687's PASS message (`:5951`). `docs/shadow-register-followup-survey.md` — added "post-Epic-11 superseded" note to Category A.2 `(ABORT")` entry (`:87`).
- `_bmad-output/implementation-artifacts/11-7-abort-and-abort-quote-retargeted-as-throw-wrappers-capstone.md` — this story file (Status, task checkboxes, Dev Agent Record, File List, Change Log).

No new files created. No `src/constants.asm` edit (EQUs declared by Story 11.1, first-consumed here).

### Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-27 | Story 11.7 dev pass: `(ABORT")` `.paq_do_abort` migrated to `-2 THROW`; `w_ABORT_cf` body retargeted to `-1 THROW`; legacy recovery chain inlined into `.throw_uncaught`; in-pass docstring + comment sweep across `src/system.asm`, `src/exception.asm`, `src/arithmetic.asm`, `src/assembler.asm`, `src/outer_interpreter.asm`; Section 5 tests + Makefile blocks 754-765; `docs/throw-codes.md` row tag flips; `docs/register-conventions.md` F1+F3 fixes from review. Binary 17419 → 17425 (+6 bytes — exactly matches AC #15 budget). FR19 + FR20 capstone milestone closed. | Ant + claude-opus-4-7 |
| 2026-04-27 | Code-review pass — fixed R1 (kernel-internal entry comment block forward-pointer sweep at `src/exception.asm:280, 298, 310`), R2 (stale line numbers in `docs/throw-codes.md:75, 368`), R3 (stale "ABORT-chain (uncaught)" wording in `src/system.asm:585-589` `do_underflow_error` docstring), R4 ("Story 11.7 precursor" annotations at `tests/exception_tests.fth:186` and `Makefile:5951`), R5 (post-Epic-11 superseded note added to `docs/shadow-register-followup-survey.md` §A.2). All comment-only changes; binary unchanged at 17425 bytes. Status flipped review → done. | Ant + claude-opus-4-7 |
| 2026-04-27 | Story 11.7 created from epics.md:861-887 + Story 11.1 EQU declarations + Stories 11.4/11.5/11.6 migration crawl context. Capstone of Epic 11's E11-D3 migration; retargets ABORT/ABORT" + inlines recovery chain into uncaught-handler. Status: backlog → ready-for-dev. | Ant (claude-opus-4-7) |
