# Story 11.6: Internal error migration — strings, I/O, remaining error sites

Status: in-progress

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the remaining kernel error paths (`(` running off the end of the input buffer, the pictured numeric output buffer overflow, and the residual assembler `asm_die` fan-in left behind by Story 11.5's D1 deviation) to raise standard ANS THROW codes (`-17` pictured numeric output string overflow, `-58` unexpected end of input) and antforth-extension codes for the two ex-`asm_die` callers (`-270 THROW_ASM_NOT_IN_CODE`, `-271 THROW_ASM_RANGE`) rather than `ABORT`,
so that all kernel error emission is uniformly THROW-based before `ABORT` / `ABORT"` are retargeted in Story 11.7 (completes FR19's pre-`ABORT`-retarget delivery; closes Stories 11.4–11.6 — the leaf-primitive / compiler-and-dictionary / strings-and-I-O migration crawl per E11-D3, `architecture.md:302-306`). This story consumes Story 11.1's pre-declared standard EQUs (`THROW_PIC_OVERFLOW EQU -17`, `THROW_END_OF_INPUT EQU -58` — both in `src/constants.asm:64-66`), declares two new antforth-extension EQUs to retire `asm_die`'s last two callers, and removes the inline pre-print sequences (`? Pictured buffer overflow`, `? missing )`, `not in CODE ?`, `range ?`) in favour of the unified `error -<N>: <desc>` diagnostic produced by Story 11.3's `print_throw_description`. The migration retires the 2 surviving non-`ABORT`/`ABORT"` `JP w_ABORT_cf` instruction-line sites (`pictured.asm:251`, `strings.asm:953`) plus the Story 11.5 D1 residual (`assembler.asm:280` `asm_die`), bringing the post-Story-11.6 ABORT instruction-line count to **2 hits** — both in Story 11.7's scope (`exception.asm:420` uncaught-recovery chain, `system.asm:137` `(ABORT")`).

## Acceptance Criteria

1. **Given** the Story 11.1 inventory (`docs/throw-codes.md` §d) cataloguing `pictured.asm:251` (`do_pic_overflow_error` fan-in: `HOLD` `:238`, plus the `#` / `SIGN` paths via `hold_common`) → `-17 THROW`, and `strings.asm:953` (`(` `.paren_missing`) → `-58 THROW`, plus the Story 11.5 D1 deviation forward-pointer noting that `asm_die` retained two non-fan-in callers (`check_asm_mode` `assembler.asm:478`, `asm_range_err` `assembler.asm:1216`) due to inventory drift, **when** Story 11.6 lands, **then** all 4 catalogued ABORT-target lines no longer end in `JP w_ABORT_cf` — each raises the catalogued THROW code via `LD BC, code / JP w_THROW_cf.kernel_entry` (DEFCODE/raw-asm sites; pictured + strings + the two ex-`asm_die` callers). Post-edit `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` returns exactly **2 instruction-line hits**: `exception.asm:420` (uncaught-recovery chain, Story 11.7), `system.asm:137` (`(ABORT")` `.paq_do_abort`, Story 11.7). Comment-line matches are excluded per the Story 11.5 AC #18 distinction. The entry-point label `w_ABORT_cf:` at `src/system.asm:260` continues to exist as a target — Story 11.7 retargets it. Note: line numbers above are post-Story-11.5 (pictured.asm and strings.asm were unchanged by 11.5; system.asm:131 drifted to :137 due to 11.5's compiler.asm-side EXX additions and ?COMP pre-print deletion ripple-effects — re-grep at dev-pass time and reconcile drift).

2. **Given** `do_pic_overflow_error` at `src/pictured.asm:246-251` — currently `LD HL, str_pic_overflow / LD B, STR_PIC_OVERFLOW_LEN / CALL bdos_print_str / CALL bdos_crlf / JP w_ABORT_cf` (prints `? Pictured buffer overflow` + CR/LF then ABORT), invoked from `hold_common`'s overflow path (`src/pictured.asm:238` `JP do_pic_overflow_error`) which is itself called from `HOLD` (`:61`) and `SIGN` (`:167`); also called via the `#` underflow guard at `:230-231`, **when** Story 11.6 migrates the site, **then** the entire pre-print sequence is **deleted** (the four-instruction print + CR/LF chain at `:247-250`); the body becomes:

    ```
    do_pic_overflow_error:
            ; -17 THROW (Story 11.6): pictured numeric output string
            ; overflow per ANS Forth 1994 §9.3.5. Pre-Story-11.6 this site
            ; printed "? Pictured buffer overflow" CR/LF before ABORT;
            ; the unified `error -17: pictured numeric output string
            ; overflow` diagnostic from Story 11.3's throw_desc_table
            ; replaces the pre-print (mirrors Story 11.4's removal of
            ; "? Stack underflow" and Story 11.5's removal of
            ; "? compile only").
            LD      BC, THROW_PIC_OVERFLOW
            JP      w_THROW_cf.kernel_entry
    ```

    The pre-print's helper-string declarations `str_pic_overflow` and `STR_PIC_OVERFLOW_LEN` at `src/antforth.asm:221-222` are **deleted** (no remaining caller — they were used only by `do_pic_overflow_error`'s pre-print path; verify with `grep -nE 'str_pic_overflow|STR_PIC_OVERFLOW' src/*.asm` returning zero hits post-edit). Caught: `' WORD-WHICH-OVERFLOWS-HOLD CATCH .` returns `-17`. Uncaught: `error -17: pictured numeric output string overflow` followed by REPL prompt.

3. **Given** the `(` IMMEDIATE word's `.paren_missing` exit at `src/strings.asm:945-953` — currently `LD HL, .paren_err_msg / LD B, .paren_err_len / CALL bdos_print_str / EXX / JP w_ABORT_cf` (prints `? missing )` + CR/LF, then `EXX` to restore primary set since the `w_PAREN_cf` body entered EXX-active context at `:909`, then `JP w_ABORT_cf`), **when** Story 11.6 migrates, **then** the pre-print sequence is **deleted** (the three-instruction `LD HL/B/CALL` chain at `:949-951`); the existing `EXX` at `:952` is **preserved** (it restores primary set before the kernel-internal raise — same pattern as the Story 11.5 no-name sites' `EXX`-before-`LD BC` discipline). The body becomes:

    ```
    .paren_missing:
            EXX                              ; Restore primary set (kernel-internal
                                             ; THROW entry contract; matches Story
                                             ; 11.5 :/CREATE/CONSTANT/MARKER pattern)
            ; -58 THROW (Story 11.6): unexpected end of input per ANS Forth 1994 §9.3.5.
            ; Pre-Story-11.6 this site printed "? missing )" CR/LF before ABORT;
            ; the unified `error -58: unexpected end of input` diagnostic from
            ; Story 11.3's throw_desc_table replaces the pre-print.
            LD      BC, THROW_END_OF_INPUT
            JP      w_THROW_cf.kernel_entry
    ```

    The local-label declarations `.paren_err_msg` / `.paren_err_len` at `src/strings.asm:955-957` are **deleted** (local-scope labels — verify with `grep -nE '\.paren_err_msg|\.paren_err_len' src/*.asm` returning zero hits post-edit). Caught: `: T S\" foo (\" EVALUATE ; ' T CATCH .` (or equivalent feeder) returns `-58`. Uncaught: `( unterminated` followed by `error -58: unexpected end of input` and REPL prompt. **Note on diagnostic information**: pre-Story-11.6 the user saw `? missing )`, which more clearly identified the syntactic cause; post-Story-11.6 the user sees `error -58: unexpected end of input`, which is the standard ANS text and is more generic. This is a deliberate trade per the Story 11.5 unified-diagnostic discipline (mirrors `?COMP`'s "? compile only" → `error -14: interpreting a compile-only word` migration). If a future requirement values the syntactic specificity, a later refactor can re-introduce a `(` -specific extension code or a per-code prefix; out of scope for this story.

4. **Given** the Story 11.5 D1 deviation noted in `_bmad-output/implementation-artifacts/11-5-internal-error-migration-dictionary-compiler-control-flow.md` (Completion Notes §Deviations) — `asm_die` body at `src/assembler.asm:278-280` (`CALL asm_print_error / JP w_ABORT_cf`) was retained because two non-fan-in callers (`check_asm_mode` `:472-478`, `asm_range_err` `:1213-1216`) were missed by Story 11.1's enumerated inventory and Story 11.5's migration scope — **when** Story 11.6 lands, **then** two new antforth-extension EQUs are declared in `src/constants.asm`:

    ```
    THROW_ASM_NOT_IN_CODE       EQU -270 ; antforth extension — see docs/throw-codes.md
    THROW_ASM_RANGE             EQU -271 ; antforth extension — see docs/throw-codes.md
    ```

    Each carries the standard one-line citation comment per CCD-3 / NFR17. The new codes extend the assembler-error contiguous block from `-258..-269` (Story 11.5) to `-258..-271` (Story 11.6), preserving the grep-ability rationale documented in `docs/throw-codes.md` §c.

5. **Given** `check_asm_mode` at `src/assembler.asm:472-478` — currently `LD A, (asm_mode) / OR A / RET NZ / LD HL, str_asm_notcode / LD B, STR_ASM_NOTCODE_LEN / JP asm_die` — **when** Story 11.6 migrates, **then** the pass path (`RET NZ`) is preserved; the failure path's `LD HL/B/JP asm_die` chain is replaced with `LD BC, THROW_ASM_NOT_IN_CODE / JP w_THROW_cf.kernel_entry` plus an inline citation comment (`; -270 THROW (Story 11.6): not in CODE per antforth extension — see docs/throw-codes.md`). The `str_asm_notcode` and `STR_ASM_NOTCODE_LEN` declarations at `:203-204` are **deleted** (no remaining caller — verify post-edit). EXX state at the raise site: callers of `check_asm_mode` are typically DEFCODE bodies entering in primary set (e.g., the opcode-emission DEFCODEs at `:1028 / 1149 / 1334 / 1432 / 2031 / 2093` etc., all of which `CALL check_asm_mode` as their first instruction) — no EXX-restore is needed at the raise site (mirrors Story 11.5 F12 second-pass review's primary-set discipline for `asm_add_fixup` / `asm_jr_disp`). **Verification at dev-pass**: spot-check 3 representative `CALL check_asm_mode` callers and confirm each enters in primary set (no prior `EXX` since the DEFCODE entry); document the verification evidence in Completion Notes.

6. **Given** `asm_range_err` at `src/assembler.asm:1211-1216` — currently `LD HL, str_asm_range / LD B, STR_ASM_RANGE_LEN / JP asm_die`, called by `+D` at `:1160 / 1163 / 1168` and by the relative-jump emitters at `:3095 / 3132 / 3164` — **when** Story 11.6 migrates, **then** the body is replaced with `LD BC, THROW_ASM_RANGE / JP w_THROW_cf.kernel_entry` plus citation. The `str_asm_range` and `STR_ASM_RANGE_LEN` declarations at `:218-219` are **deleted** (no remaining caller). EXX state: `+D` (`w_PLUS_D_cf` `:1146-1208`) is a DEFCODE body in primary set — `CALL check_asm_mode` is its first action, then `JP NZ, asm_range_err` etc., with no intervening EXX. The other three callers (relative-jump emitters at `:3095/:3132/:3164`) are likewise DEFCODE bodies — verify each spot at dev-pass via `grep -nB5 'JP\s+(NZ|Z|NC|C|P|M)?,?\s*asm_range_err\b' src/assembler.asm` to confirm primary-set context. No EXX-restore needed at the raise site.

7. **Given** the `asm_die` body at `src/assembler.asm:278-280` (`CALL asm_print_error / JP w_ABORT_cf`) and `asm_print_error` at `:228-230` (`CALL bdos_print_str / JP bdos_print_q_crlf`), **when** Tasks 5 and 6 retire the last two `asm_die` callers (`check_asm_mode`, `asm_range_err`), **then** the `asm_die` body, label, and surrounding docstring header at `:262-280` are **deleted** in their entirety. `asm_print_error` becomes dead code (no remaining caller — verify with `grep -nE '\basm_print_error\b' src/*.asm` after deletion; the only matches should be inside docstring comments referencing the helper for historical context, which can be left or scrubbed at the dev's discretion. The `asm_print_error` body at `:228-230` should be deleted too if no caller references it; the `asm_print_q_crlf EQU bdos_print_q_crlf` alias at `:232` is **preserved** because `asm_err_bare_int` at `:346` calls it directly via `CALL asm_print_q_crlf`). Post-deletion: `grep -nE '\basm_die\b' src/*.asm` returns zero hits, and `grep -nE '\basm_print_error\b' src/*.asm` returns at most comment-line matches.

8. **Given** the description-table at `src/exception.asm:560-635` (post-Story-11.5 layout: 10 standard codes through `-58`, plus 12 antforth-extension codes `-258..-269`, plus the `DW 0` terminator at `:635`), and Story 11.3's pre-seeding of `-17` at `:582-584` (`DW -17 / DB 39 / DB "pictured numeric output string overflow"`) and `-58` at `:588-590` (`DW -58 / DB 23 / DB "unexpected end of input"`), **when** Story 11.6 lands, **then** **no edits** are made to the standard-code rows for `-17` and `-58` — Story 11.3's seeding is exactly the text Story 11.6's uncaught path will produce. Verification: `grep -nE 'DW\s+-17|DW\s+-58' src/exception.asm` returns the two pre-existing rows unchanged.

9. **Given** the antforth-extension codes `-270` and `-271` declared by Task 4 in `src/constants.asm`, neither of which is currently in `throw_desc_table`, **when** Story 11.6 lands, **then** **2 new entries** are appended to `throw_desc_table` at `src/exception.asm` (immediately before the `DW 0` terminator at `:635`), in code order:

    | Code | Description text | Length |
    |---:|---|---:|
    | -270 | `not in CODE` | 11 |
    | -271 | `range` | 5 |

    Description text matches the legacy `str_asm_notcode` / `str_asm_range` strings exactly, so the user-visible diagnostic carries the same information as the pre-edit pre-print (just under the unified `error -<N>: <desc>` framing). Length bytes are hand-counted at edit time per Story 11.5 AC #12 discipline (a length-byte mismatch silently misaligns the table walk per Story 11.3 design). Format: `DW THROW_ASM_NOT_IN_CODE / DB 11 / DB "not in CODE"` and `DW THROW_ASM_RANGE / DB 5 / DB "range"`. Use the EQU symbols, not the bare numerical literals, per Story 11.5 AC #13.

10. **Given** Story 11.4's kernel-internal-entry contract at `src/exception.asm:288-296` (BC carries the THROW code; SP/IX may be in any state; **caller must enter from primary set** — Story 11.4 review F7 / R-M1; Story 11.5 review F1/F2/F12 reaffirmed), **when** Story 11.6's 4 new raise sites land, **then** each site is verified to call `JP w_THROW_cf.kernel_entry` from primary-set context. Verified call-site contexts:
    - `do_pic_overflow_error` (`pictured.asm`): callers (`hold_common.hc_overflow` JP-falls into it; `HOLD` / `SIGN` / `#` are primary-set DEFCODE bodies) all enter in primary set. No EXX-restore needed.
    - `(` `.paren_missing` (`strings.asm`): the `EXX` at `:952` (preserved by AC #3) explicitly restores primary set before the kernel-internal raise. Matches Story 11.5 no-name sites' `EXX`-before-`LD BC` idiom.
    - `check_asm_mode` (`assembler.asm`): callers are DEFCODE-body opcode-emitters that `CALL check_asm_mode` as their first instruction. Primary set on entry. No EXX-restore needed (mirrors Story 11.5 F12).
    - `asm_range_err` (`assembler.asm`): callers (`w_PLUS_D_cf`, the three relative-jump emitters) are likewise primary-set DEFCODE bodies. No EXX-restore needed.

    Document the verification evidence per site in Completion Notes (one line each: file:line, caller, "primary-set verified by …").

11. **Given** the EQU declarations Story 11.1 added to `src/constants.asm` for the codes Story 11.6 consumes (`THROW_PIC_OVERFLOW EQU -17` at `:64`, `THROW_END_OF_INPUT EQU -58` at `:66`) plus the two new EQUs Task 4 declares (`THROW_ASM_NOT_IN_CODE EQU -270`, `THROW_ASM_RANGE EQU -271`), **when** Story 11.6 emits these codes, **then** the source uses the EQU symbols, **not** the bare numerical literals (`LD BC, THROW_PIC_OVERFLOW` not `LD BC, -17`; `DW THROW_ASM_RANGE` not `DW -271`). Per `architecture.md:471-479` and the Story 11.4 / 11.5 first-consumption convention. Verify post-edit: `grep -nE 'LD\s+BC,\s*-(17|58|270|271)\b' src/*.asm` returns zero hits; `grep -nE 'THROW_(PIC_OVERFLOW|END_OF_INPUT|ASM_NOT_IN_CODE|ASM_RANGE)' src/*.asm` finds the declarations + every consumption site.

12. **Given** the standards-citation discipline (CCD-3 / NFR17, `architecture.md:206-216`) and the Stories 11.4 / 11.5 inline-citation convention, **when** Story 11.6 edits each migration site, **then** an inline citation comment of the matching form is added immediately above the `LD BC, code` instruction:
    - `-17`, `-58`: `; -<N> THROW (Story 11.6): <description> per ANS Forth 1994 §9.3.5`
    - `-270`, `-271`: `; -<N> THROW (Story 11.6): <description> per antforth extension — see docs/throw-codes.md`

    Verify at edit time that each citation matches the EQU's own citation comment (no drift between the EQU declaration and the consumption-site citation).

13. **Given** the test discipline established by Stories 11.4 and 11.5 (REPL-piped Forth in `tests/throw_migration_tests.fth`; matching `printf | $(IZCPM)` blocks in `Makefile` per `feedback_repl_tests_preferred.md`) and the post-Story-11.5 high-water mark of test 744 (verify at dev-pass via `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending), **when** Story 11.6 lands, **then** a new "Section 4 — Strings / I-O / asm-die-residual (Story 11.6)" header block is appended to `tests/throw_migration_tests.fth` with caught-form coverage where natural and uncaught-recovery coverage where the parsing mechanics make caught form awkward:

    - **Pictured-overflow `-17` (caught form):** define a colon word that `<#`-opens, `HOLD`s enough chars to overflow (the pic_buf is `PIC_BUF_SIZE = 40` bytes per `src/constants.asm:36`, so HOLDing 41+ chars from a pre-opened pictured session triggers the overflow), then `' WORD CATCH .` returns `-17`. Sample shape:
        ```
        : T17 0. <#  41 0 DO  CHAR X HOLD  LOOP  #> 2DROP ;
        \ expect -17  ok
        ' T17 CATCH .
        ```
        **Verify at write time** that 41 iterations is enough to trigger overflow (the buffer holds 40 bytes; after 40 successful HOLDs, the 41st should hit `.hc_overflow`). Adjust the iteration count if the off-by-one differs in practice.

    - **Pictured-overflow `-17` (uncaught form):** REPL pipes `0. <#  41 0 DO  CHAR X HOLD  LOOP  #> 2DROP` then `99 .` then `BYE` and asserts `error -17: pictured numeric output string overflow.*99  ok`.

    - **`(` missing-`)` `-58` (caught form):** because `(` is IMMEDIATE and consumes input within the current line/source, the natural caught test feeds source through `EVALUATE`. Sample:
        ```
        : T58 S" ( unterminated " EVALUATE ;
        \ expect -58  ok
        ' T58 CATCH .
        ```
        **Caveat (mirror of Story 11.5 AC #15 EVALUATE caveat)**: confirm `EVALUATE` is a kernel primitive at write time via `grep -nE 'DEFCODE\s+"EVALUATE"|DEFWORD\s+"EVALUATE"' src/*.asm`. If absent, fall back to the uncaught form below for `-58` coverage.

    - **`(` missing-`)` `-58` (uncaught form):** REPL pipes `( unterminated` then `99 .` then `BYE` and asserts `error -58: unexpected end of input.*99  ok`. The trailing-space-after-`(` is NOT optional (per the antforth `(` parsing); the unterminated-comment scenario fires when `(` reaches end-of-line without finding `)`.

    - **`check_asm_mode` `-270` (uncaught form):** trigger by typing an inline assembler word (e.g., `NOP,`) outside a `CODE` block. Sample: `NOP,` then `99 .` then `BYE` → `error -270: not in CODE.*99  ok`. Verify at write time that `NOP,` is a kernel-primitive opcode word that begins with `CALL check_asm_mode`. Caught form deferred per the Story 11.5 D2 deferral rationale (assembler-error CATCH harness is non-trivial).

    - **`asm_range_err` `-271` (uncaught form):** trigger by emitting a relative-jump opcode with an out-of-8-bit-range displacement, or a `+D` with such a displacement. Sample: `CODE TRANGE 200 (IX) +D NOP, END-CODE` (where `200` is a bare integer outside −128..+127 — the exact incantation depends on `+D`'s tag/range rules; verify by experiment at write time). Then `99 .` then `BYE` → `error -271: range.*99  ok`. Caught form deferred (same rationale as `-270`).

    - **i\*x preservation across the new migration sites** — at least one test per category showing kernel-internal THROW from the new sites correctly preserves the i\*x cells underneath (Story 11.4.1 contract). Sample: `1 2 3 ' T17 CATCH . . . .` → `-17 3 2 1  ok` (3 i\*x cells preserved across the pictured-overflow THROW). Mirror the Story 11.5 AC #15 i\*x test pattern.

    - **Positive controls** — verify CATCH around each migrated word's success path returns `0`. Sample: a successful pictured-output round-trip (`: TPIC 1234 0. <# # # # # #> TYPE ;` then `' TPIC CATCH .` → `1234  0  ok`); a properly-closed `(` (`: TOK ( ok ) 5 ;` then `' TOK CATCH .` → `0  ok`).

14. **Given** the per-line `\ expect: <fragment>` convention from Story 11.4 / 11.5 Section header pattern and the matching Makefile `printf | $(IZCPM)` block convention (single-line caught tests; multi-line uncaught-recovery tests with `tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'`), **when** Story 11.6's tests are written, **then** every test follows the same convention; the matching Makefile blocks are appended starting at the highest existing PASS test number + 1 (verify with `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending — Story 11.5 final landed at 744; with any 11.5 follow-up patches the high-water mark may have moved — the dev re-checks at write time).

15. **Given** the post-Story-11.5 baseline (`build/antforth.com` ≈ 17481 bytes per current `wc -c` — verify at dev-pass), **when** Story 11.6 lands, **then** the binary delta is bounded by the following budget table:

    | Change | Estimated byte delta |
    |---|---:|
    | `do_pic_overflow_error` body shrink: 4-instruction pre-print chain (~13B: 3 + 3 + 3 + 4) + `JP w_ABORT_cf` (3B) → `LD BC,n / JP` (6B) | −10 |
    | `str_pic_overflow` "? Pictured buffer overflow" + EQU 0B (string is 26B per `STR_PIC_OVERFLOW_LEN EQU 26` at `antforth.asm:222`) | −26 |
    | `(` `.paren_missing` body shrink: 3-instruction pre-print chain (~9B: 3 + 2 + 4) + `EXX` retained (1B) + `JP w_ABORT_cf` (3B) → `EXX` retained (1B) + `LD BC,n / JP` (6B) | −5 |
    | `.paren_err_msg` "? missing )" CR LF (13B) + `.paren_err_len` EQU 0B | −13 |
    | `check_asm_mode` body shrink: `LD HL,str / LD B,len / JP asm_die` (3 + 2 + 3 = 8B) → `LD BC,n / JP` (6B) | −2 |
    | `str_asm_notcode` "not in CODE" (11B) + EQU 0B | −11 |
    | `asm_range_err` body shrink: `LD HL,str / LD B,len / JP asm_die` (8B) → `LD BC,n / JP` (6B) | −2 |
    | `str_asm_range` "range" (5B) + EQU 0B | −5 |
    | `asm_die` body removal: `CALL asm_print_error / JP w_ABORT_cf` (3 + 3 = 6B) | −6 |
    | `asm_print_error` body removal (assuming dead post-asm_die deletion): `CALL bdos_print_str / JP bdos_print_q_crlf` (6B) | −6 |
    | 2 description-table entries: -270 (DW + DB len + 11B text = 14B), -271 (DW + DB + 5B text = 8B) | +22 |
    | 2 new EQU declarations in `constants.asm` | 0 (declarations) |
    | Inline citation comments | 0 (comments only) |
    | **Estimated net** | **−64** |

    Pre/post `wc -c build/antforth.com` recorded in Completion Notes. **Investigate if delta exceeds ±150 bytes** (likely cause: an over-counted string deletion, a missed caller of `asm_print_error` keeping it alive, or additional dead-code visibility from removing `asm_die`). Net-negative delta is the expected outcome — this story is the final pre-print-removal pass before `ABORT` retarget, and it's removing more bytes than it adds.

16. **Given** the post-migration ABORT-site count target — from 5 grep hits today (`exception.asm:420`, `pictured.asm:251`, `strings.asm:953`, `system.asm:137`, `assembler.asm:280`) drops to **2 grep hits** post-Story-11.6 — **when** Story 11.6 lands, **then** `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` returns exactly 2 instruction-line hits (`exception.asm:420`, `system.asm:137`). Recorded in Completion Notes. Comment-line matches excluded per Story 11.5 AC #18 distinction. Verify with `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm | grep -vE '^\s*src/[^:]+:[0-9]+:\s*;'`.

17. **Given** the Story 11.4 / 11.5 REPL-recovery-test pattern (`tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'`) for verifying that an uncaught THROW returns the REPL to a live prompt, **when** Story 11.6 lands, **then** at least the following uncaught-recovery tests are added (one per THROW code in this story's scope):
    - **`-17` pictured overflow:** `printf "%s\r\n%s\r\n%s\r\n" '0. <# 41 0 DO CHAR X HOLD LOOP #> 2DROP' '99 .' 'BYE' | $(IZCPM) ... | tr ... | grep -qE 'error -17: pictured numeric output string overflow.*99  ok'` — covers the HOLD overflow path (uncaught).
    - **`-58` `(` missing-`)`:** `printf "%s\r\n%s\r\n%s\r\n" '( unterminated' '99 .' 'BYE' | ... | grep -qE 'error -58: unexpected end of input.*99  ok'` — covers the `(` parser running off end-of-input.
    - **`-270` not in CODE:** `printf "%s\r\n%s\r\n%s\r\n" 'NOP,' '99 .' 'BYE' | ... | grep -qE 'error -270: not in CODE.*99  ok'` — covers `check_asm_mode` triggering outside any CODE block.
    - **`-271` range:** craft an out-of-range relative-jump or `+D` displacement (verify the exact incantation by experiment at write time); `printf ... | grep -qE 'error -271: range.*99  ok'`.

    Each recovery test asserts (a) the diagnostic format and (b) that a subsequent simple REPL command (`99 .`) runs cleanly (REPL-survivability per FR22 / NFR7).

18. **Given** the adversarial-review discipline (`feedback_adversarial_review.md`) and Stories 11.4 / 11.5 review yields (8 + 5 + 11 + 4 findings respectively across two passes apiece), **when** Story 11.6's review runs, **then** **at least 2-3 HIGH/MEDIUM findings are expected**. Likely candidates the review must investigate:
    - **(a)** Diagnostic-text drift: pre-Story-11.6 `(` printed `? missing )`, which carries syntactic specificity ("the `)` is missing"). Post-migration the user sees `error -58: unexpected end of input`, which is more generic. Acceptable trade per the unified-diagnostic discipline (mirrors `?COMP`'s `? compile only` → `error -14: ...`); document the trade explicitly in the migrated word's docstring so future maintainers don't "fix" the regression.
    - **(b)** EXX-hygiene cross-check at all 4 raise sites — verify each call-site enters primary set; confirm `(`'s `EXX` is correctly placed BEFORE `LD BC, code`; confirm no `check_asm_mode` or `asm_range_err` caller is accidentally post-EXX (the same hazard Story 11.5 review F1/F2/F12 chased).
    - **(c)** Description-table length-byte mismatches — hand-counted bytes in AC #9 must be verified against the actual string content during the edit. A length-byte mismatch silently misaligns the table walk per Story 11.3 design (Story 11.3 AC #5 length-counting discipline).
    - **(d)** Test gaps — pictured-overflow caught coverage depends on a known-overflowing sequence; verify by direct experiment that 41 HOLDs is the right count (off-by-one would silently turn a `-17`-asserting test into a passing `0`-asserting one if HOLD count were too low). At least one DO-LOOP / EXECUTE shape per code where natural (mirror Story 11.5 review F3 hazard).
    - **(e)** Asm-die deletion completeness — verify `asm_die` and `asm_print_error` are gone (`grep -nE '\basm_die\b|\basm_print_error\b' src/*.asm` returns zero hits or only comment-line hits). Verify the `asm_print_q_crlf` alias (used by `asm_err_bare_int`) is preserved.
    - **(f)** Forward compatibility with Story 11.7's `(ABORT")` / `ABORT` retarget — does Story 11.6's reuse of `w_THROW_cf.kernel_entry` interact with Story 11.7's planned `w_ABORT_cf` retarget? (Story 11.5 forward-pointer noted the same hazard; Story 11.6 inherits without amplification.) Verify the post-Story-11.6 ABORT instruction-line count is exactly the 2 hits Story 11.7 expects to retarget.
    - **(g)** Stale `\ expect:` / Makefile diagnostic literals — pre-edit `grep -nE '\? Pictured buffer overflow|\? missing \)|not in CODE \?|range \?' tests/ Makefile` and reconcile each occurrence to the post-migration form. Mirror Story 11.5 R-M2 / Story 11.4 R-M2 stale-expect cleanup.
    - **(h)** Stale docstring sweep — every word migrated (`HOLD`, `#`, `SIGN`, `(`, `+D`, all `check_asm_mode` callers' docstring "Errors: ..." lines if present) must be updated in-pass; mirror Story 11.5 R-M1.
    - **(i)** Stale `docs/throw-codes.md` row tags — §b row for `-17` and `-58` should flip from `yes — Story 11.6` to `done — Story 11.6`; §c new rows for `-270` / `-271` are added with `done — 11.6` tags; §d per-file inventory rows for `pictured.asm:251` and `strings.asm:953` flip to `**done — 11.6**`; §d should gain new rows for `assembler.asm:478 check_asm_mode` and `assembler.asm:1216 asm_range_err` (which were missed by Story 11.1 — flag this as a Story-11.1-inventory drift; record in §d's "Drafting reconciliation" notes mirroring Story 11.5's pattern).
    - Triage all findings; fix HIGH and MEDIUM in-pass; defer LOW with rationale (mirror Story 11.5's review log discipline).

19. **Given** the Stories 11.4 / 11.5 verdict-table format for Completion Notes (one row per AC, columns `Gate text | Evidence | Verdict`), **when** Story 11.6 lands, **then** Completion Notes mirror that format. State the value, the gate, and the reason plainly per `feedback_plain_qa_language.md`.

20. **Given** the post-edit regression discipline (`make` + `make test` + `make test-repl` clean against the post-Story-11.5 baseline — 0 errors, 0 warnings, current PASS count from the high-water-mark grep), **when** Story 11.6 lands, **then** all three passes run clean; new tests appended (estimated ~10-15 new tests covering Section 4's caught-THROW round-trips + uncaught-recovery cases per AC #13 and AC #17). **Critical regression check**: any pre-existing test asserting the literal `? Pictured buffer overflow`, `? missing )`, `not in CODE ?`, or `range ?` must migrate to the new `error -<N>: <desc>` form (mirror Story 11.5 R-M2 / Task 12.5 cleanup). Pre-edit `grep -nE '\? Pictured buffer overflow|\? missing \)|not in CODE \?|range \?' tests/ Makefile` — replace each occurrence with the post-migration form. Verify test-by-test at edit time.

## Tasks / Subtasks

- [x] **Task 1 — Pre-edit verification + baseline (AC: #1, #8, #11, #15, #16, #20)**
  - [x] 1.1 Re-run `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` — expect 5 instruction-line hits (`exception.asm:420`, `pictured.asm:251`, `strings.asm:953`, `system.asm:137`, `assembler.asm:280`). Reconcile any drift since Story 11.5's final landing.
  - [x] 1.2 Confirm `src/exception.asm` `throw_desc_table` still contains entries for `-17` (`:582-584`) and `-58` (`:588-590`). Story 11.6 does **not** touch the standard-code rows. `grep -nE 'DW\s+-17|DW\s+-58' src/exception.asm`.
  - [x] 1.3 Confirm `THROW_PIC_OVERFLOW EQU -17` and `THROW_END_OF_INPUT EQU -58` are declared in `src/constants.asm:64-66` (Story 11.1 pre-declaration; first-consumed by this story).
  - [x] 1.4 Confirm `src/exception.asm` `w_THROW_cf.kernel_entry:` label exists and the FUTURE-EDIT NOTE 1/2 contract documentation is intact (Stories 11.4 / 11.5 added; Story 11.6 reuses without modification).
  - [x] 1.5 Re-check the highest existing PASS test number: `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1`. Story 11.6's new tests start at this number + 1 (Story 11.5 final was 744 — verify post-Story-11.5).
  - [x] 1.6 `wc -c build/antforth.com` — record pre-edit baseline (post-Story-11.5 figure; expected ≈ 17481 bytes — verify).
  - [x] 1.7 Pre-edit literal-expect cross-check: `grep -nE '\? Pictured buffer overflow|\? missing \)|not in CODE \?|range \?' tests/ Makefile` — record every occurrence; these are AC #20 candidates for the post-migration sweep.
  - [x] 1.8 Verify Story 11.5 D1 deviation context: re-read `_bmad-output/implementation-artifacts/11-5-internal-error-migration-dictionary-compiler-control-flow.md` Completion Notes §Deviations to confirm the asm_die residual scope (`check_asm_mode`, `asm_range_err`) matches this story's Tasks 4-7.

- [x] **Task 2 — Migrate `do_pic_overflow_error` (`src/pictured.asm:246-251`) (AC: #2, #11, #12)**
  - [x] 2.1 Open `src/pictured.asm`. The body's docstring at `:241-245` mentions "Epic 11 will migrate this to THROW -17" — update it to the post-migration form ("Migrated by Story 11.6 to raise -17 THROW per ANS Forth 1994 §9.3.5").
  - [x] 2.2 Replace the body at `:246-251`:
    ```
    do_pic_overflow_error:
            ; -17 THROW (Story 11.6): pictured numeric output string
            ; overflow per ANS Forth 1994 §9.3.5. Pre-Story-11.6 this site
            ; printed "? Pictured buffer overflow" CR/LF before ABORT;
            ; the unified `error -17: pictured numeric output string
            ; overflow` diagnostic from Story 11.3's throw_desc_table
            ; replaces the pre-print.
            LD      BC, THROW_PIC_OVERFLOW
            JP      w_THROW_cf.kernel_entry
    ```
  - [x] 2.3 Update the docstring of `HOLD` at `:51-54` from "Underflow (writing below pic_buf) → do_pic_overflow_error + ABORT." to "Underflow (writing below pic_buf) → -17 THROW per ANS Forth 1994 §9.3.5." Mirror updates for `#` (`:65-72`), `SIGN` (`:153-159`), and any other word whose docstring mentions ABORT in the overflow context.
  - [x] 2.4 Open `src/antforth.asm:221-222` and **delete** `str_pic_overflow` and `STR_PIC_OVERFLOW_LEN`. Verify with `grep -nE 'str_pic_overflow|STR_PIC_OVERFLOW' src/*.asm` returning zero hits post-edit.

- [x] **Task 3 — Migrate `(` `.paren_missing` (`src/strings.asm:945-957`) (AC: #3, #11, #12)**
  - [x] 3.1 Open `src/strings.asm` at `.paren_missing:` (`:945`). Pre-edit body:
    ```
    .paren_missing:
            ; Print "missing )" CR LF then ABORT. Restore shadows defensively
            ; before ABORT (ABORT resets SP/RSP and re-enters QUIT which reloads IP,
            ; but matching the 7.1 convention keeps reasoning simple).
            LD      HL, .paren_err_msg
            LD      B, .paren_err_len
            CALL    bdos_print_str
            EXX
            JP      w_ABORT_cf
    ```
  - [x] 3.2 Replace with:
    ```
    .paren_missing:
            EXX                              ; Restore primary set (kernel-internal
                                             ; THROW entry contract; matches Story
                                             ; 11.5 :/CREATE/CONSTANT/MARKER pattern)
            ; -58 THROW (Story 11.6): unexpected end of input per ANS Forth 1994 §9.3.5.
            ; Pre-Story-11.6 this site printed "? missing )" CR/LF before ABORT;
            ; the unified `error -58: unexpected end of input` diagnostic from
            ; Story 11.3's throw_desc_table replaces the pre-print.
            LD      BC, THROW_END_OF_INPUT
            JP      w_THROW_cf.kernel_entry
    ```
  - [x] 3.3 **Delete** the local-label declarations at `:955-957`:
    ```
    .paren_err_msg:
            DB      "? missing )", 0x0D, 0x0A
    .paren_err_len  EQU     $ - .paren_err_msg
    ```
    Verify with `grep -nE '\.paren_err_msg|\.paren_err_len' src/*.asm` returning zero hits post-edit.
  - [x] 3.4 Update the docstring of `(` (`w_PAREN` at `:893-896`) — replace any ABORT mention with the new "raises -58 THROW per ANS Forth 1994 §9.3.5" form. Per Story 11.5's R-M1 in-pass header sweep.

- [x] **Task 4 — Declare new EQUs `THROW_ASM_NOT_IN_CODE` and `THROW_ASM_RANGE` (AC: #4)**
  - [x] 4.1 Open `src/constants.asm`. Append below the existing `-269` declaration (`:93`):
    ```
    THROW_ASM_NOT_IN_CODE       EQU -270 ; antforth extension — see docs/throw-codes.md
    THROW_ASM_RANGE             EQU -271 ; antforth extension — see docs/throw-codes.md
    ```
  - [x] 4.2 Verify the `-258..-269` block comment (`:75-80`) is updated to reflect the extension to `-271` (e.g., "Allocated as one contiguous block for grep-ability; one code per error entry point in src/assembler.asm. The block extends to -271 per Story 11.6's asm_die-residual cleanup."). Cross-reference `docs/throw-codes.md` §c.

- [x] **Task 5 — Migrate `check_asm_mode` (`src/assembler.asm:472-478`) (AC: #5, #10, #11, #12)**
  - [x] 5.1 Open `src/assembler.asm` at `check_asm_mode:` (`:472`). Pre-edit body:
    ```
    check_asm_mode:
            LD      A, (asm_mode)
            OR      A
            RET     NZ
            LD      HL, str_asm_notcode
            LD      B, STR_ASM_NOTCODE_LEN
            JP      asm_die
    ```
  - [x] 5.2 Replace the failure path's `LD HL/B/JP asm_die` chain at `:476-478` with:
    ```
            ; -270 THROW (Story 11.6): not in CODE per antforth extension —
            ; see docs/throw-codes.md
            LD      BC, THROW_ASM_NOT_IN_CODE
            JP      w_THROW_cf.kernel_entry
    ```
    Preserve the pass path (`RET NZ` at `:475`) unchanged.
  - [x] 5.3 Update the docstring at `:467-471` — replace "abort unless asm_mode is set" with "raise -270 THROW unless asm_mode is set" and replace "Fail path: prints 'not in CODE ?' and jumps to ABORT" with "Fail path: raises -270 THROW per antforth extension."
  - [x] 5.4 Open `src/assembler.asm:203-204` and **delete** `str_asm_notcode` and `STR_ASM_NOTCODE_LEN`. Verify with `grep -nE 'str_asm_notcode|STR_ASM_NOTCODE_LEN' src/*.asm` returning zero hits post-edit.
  - [x] 5.5 EXX-context spot-check (AC #10): grep 3 representative `CALL check_asm_mode` callers (e.g., `:1028`, `:1334`, `:2031`) and confirm each enters from primary set (no preceding `EXX` at the DEFCODE entry). Document the spot-check evidence in Completion Notes.

- [x] **Task 6 — Migrate `asm_range_err` (`src/assembler.asm:1213-1216`) (AC: #6, #10, #11, #12)**
  - [x] 6.1 Open `src/assembler.asm` at `asm_range_err:` (`:1213`). Pre-edit body:
    ```
    asm_range_err:
            LD      HL, str_asm_range
            LD      B, STR_ASM_RANGE_LEN
            JP      asm_die
    ```
  - [x] 6.2 Replace with:
    ```
    asm_range_err:
            ; -271 THROW (Story 11.6): range per antforth extension —
            ; see docs/throw-codes.md
            LD      BC, THROW_ASM_RANGE
            JP      w_THROW_cf.kernel_entry
    ```
  - [x] 6.3 Update the docstring at `:1210-1211` — replace "Print 'range ?' and ABORT" with "Raise -271 THROW per antforth extension."
  - [x] 6.4 Open `src/assembler.asm:218-219` and **delete** `str_asm_range` and `STR_ASM_RANGE_LEN`. Verify with `grep -nE 'str_asm_range\b|STR_ASM_RANGE_LEN' src/*.asm` returning zero hits post-edit.
  - [x] 6.5 EXX-context spot-check (AC #10): grep `JP\s+asm_range_err` callers (`:1160`, `:1163`, `:1168`, `:3095`, `:3132`, `:3164`) and confirm each enters from primary set. Document evidence in Completion Notes.

- [x] **Task 7 — Retire `asm_die` body and dead helper `asm_print_error` (AC: #7)**
  - [x] 7.1 Verify Tasks 5 and 6 retired the last two `asm_die` callers: `grep -nE 'JP\s+asm_die\b' src/*.asm` returns zero hits.
  - [x] 7.2 Open `src/assembler.asm` at `:262-280` (the `asm_die` docstring header + body). **Delete** the entire docstring header at `:262-277` and the `asm_die:` label / body at `:278-280` (`CALL asm_print_error / JP w_ABORT_cf`).
  - [x] 7.3 Verify `asm_print_error` is dead: `grep -nE '\basm_print_error\b' src/*.asm` returns at most comment-line hits (the helper was only called by `asm_die`). **Delete** the `asm_print_error:` body at `:228-230` (`CALL bdos_print_str / JP bdos_print_q_crlf`) and its docstring at `:223-227`.
  - [x] 7.4 **Preserve** the `asm_print_q_crlf EQU bdos_print_q_crlf` alias at `:232` — `asm_err_bare_int` at `:346` still calls it via `CALL asm_print_q_crlf`. Verify with `grep -nE '\basm_print_q_crlf\b' src/*.asm` showing the alias declaration plus the `CALL` at `asm_err_bare_int`.
  - [x] 7.5 Update the comment block at `src/assembler.asm:187-201` (the error-message-strings header) — Story 11.5's note about `str_asm_notcode` / `str_asm_range` retention is now stale; replace with a note explaining that Story 11.6 retired the asm_die residual and deleted both strings.
  - [x] 7.6 Verify post-deletion: `grep -nE '\basm_die\b' src/*.asm` returns zero hits (or only comment-line hits in unrelated narrative).

- [x] **Task 8 — Append 2 description-table entries (AC: #8, #9)**
  - [x] 8.1 Open `src/exception.asm` at `throw_desc_table:` (`:560`). The post-Story-11.5 layout ends with `-269 "already fixed"` at `:632-634`, then `DW 0` terminator at `:635`.
  - [x] 8.2 **Insert** the 2 antforth-extension entries immediately before the `DW 0` terminator, in code order (`-270` then `-271`):
    ```
            DW      THROW_ASM_NOT_IN_CODE       ; -270
            DB      11
            DB      "not in CODE"
            DW      THROW_ASM_RANGE             ; -271
            DB      5
            DB      "range"
            DW      0                       ; terminator
    ```
  - [x] 8.3 Verify each length byte by inspection — count characters: `not in CODE` is 11 (n-o-t-space-i-n-space-C-O-D-E), `range` is 5. A length-byte mismatch silently misaligns the table walk per Story 11.3 design.
  - [x] 8.4 Update the comment block at `:591-598` (Story 11.5's "antforth extension codes -258..-269" header) to extend the range to `-271` and credit Story 11.6 for the appendage.

- [x] **Task 9 — Build, sanity-probe, and verify ABORT-site count (AC: #1, #15, #16, #20)**
  - [x] 9.1 `make` after Tasks 2-8. Confirm clean assemble; record byte count via `wc -c build/antforth.com`. Compare against AC #15 estimate (~−64 bytes from baseline → target range ~17400-17430 bytes). Investigate if delta exceeds ±150 bytes.
  - [x] 9.2 `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` — expect exactly 2 instruction-line hits per AC #16 (`exception.asm:420`, `system.asm:137`). Comment-line matches excluded.
  - [x] 9.3 Quick interactive sanity probes (one-line REPL pipes via `iz-cpm`):
    - `printf "0. <# 41 0 DO CHAR X HOLD LOOP #> 2DROP\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null | grep -qE 'error -17: pictured numeric output string overflow'` → expect a hit.
    - `printf "( unterminated\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null | grep -qE 'error -58: unexpected end of input'` → expect a hit.
    - `printf "NOP,\r\nBYE\r\n" | iz-cpm build/antforth.com 2>/dev/null | grep -qE 'error -270: not in CODE'` → expect a hit.
    - Caught: `printf "%s\r\n%s\r\n" '0. <# 41 0 DO CHAR X HOLD LOOP #> 2DROP CATCH .' 'BYE' | iz-cpm build/antforth.com 2>/dev/null | grep -qE '\\-17  ok'` → expect a hit (caught form for `-17`).
  - [x] 9.4 Verify deletions: `grep -nE 'str_pic_overflow|STR_PIC_OVERFLOW|str_asm_notcode|STR_ASM_NOTCODE_LEN|str_asm_range\b|STR_ASM_RANGE_LEN|\.paren_err_msg|\.paren_err_len|\basm_die\b|\basm_print_error\b' src/*.asm` returns zero hits (or only comment-line narrative).

- [x] **Task 10 — Author REPL test scenarios in `tests/throw_migration_tests.fth` Section 4 (AC: #13, #14)**
  - [x] 10.1 Open `tests/throw_migration_tests.fth` and append a new "Section 4 — Strings / I-O / asm-die-residual (-17/-58/-270/-271) (Story 11.6)" header block. Mirror Story 11.5 Section 3's pattern, with caveats noting the EVALUATE-availability check for `-58` caught form and the deferred caught form for `-270` / `-271`.
  - [x] 10.2 Append Section 4.1 (-17 pictured overflow — caught + i\*x preservation): `: T17 0. <#  41 0 DO  CHAR X HOLD  LOOP  #> 2DROP ;` then `' T17 CATCH .` → `-17  ok`; plus i\*x: `1 2 3 ' T17 CATCH . . . .` → `-17 3 2 1  ok`. **Verify HOLD-count off-by-one at write time.**
  - [x] 10.3 Append Section 4.2 (-58 `(` missing-`)` — caught form if EVALUATE is available, else uncaught only): `: T58 S" ( unterminated " EVALUATE ;` then `' T58 CATCH .` → `-58  ok`. Pre-check `EVALUATE` availability via `grep -nE 'DEFCODE\s+"EVALUATE"|DEFWORD\s+"EVALUATE"' src/*.asm` (existing Epic 9/10 wordset).
  - [x] 10.4 Append Section 4.3 (positive controls): a successful pictured-output round-trip (`: TPIC 1234 0. <# # # # # #> TYPE ;` then `' TPIC CATCH . CR`); a properly-closed paren (`: TOK ( ok ) 5 ;` then `' TOK CATCH . CR` and the result on stack).
  - [x] 10.5 Cross-check at test-write time: every defined word in Section 4 is uniquely-named (avoid name collisions with kernel words / earlier test sections).

- [x] **Task 11 — Append matching `printf | $(IZCPM)` blocks to `Makefile` (AC: #14, #17, #20)**
  - [x] 11.1 Highest existing PASS test number per Story 11.5 final — re-check via `grep -oE 'PASS: REPL test [0-9]+' Makefile | awk '{print $4}' | sort -n -u | tail -1` immediately before appending. Story 11.6 numbers begin at this + 1 (Story 11.5 final was 744).
  - [x] 11.2 For each test in Section 4.1-4.3 (caught), add a single-line Makefile block following the Story 11.4 / 11.5 pattern.
  - [x] 11.3 For uncaught-recovery tests (AC #17): use the multi-line `printf` + `tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'` pattern from Story 11.3 / 11.4 / 11.5. At minimum the AC #17 enumerated cases (one per code: `-17`, `-58`, `-270`, `-271`).
  - [x] 11.4 Run `make test-repl` after Makefile update. Expected: pre-existing PASS count + new tests, zero FAIL.
  - [x] 11.5 Pre-existing test diagnostic-format updates per AC #20: `grep -nE '\? Pictured buffer overflow|\? missing \)|not in CODE \?|range \?' tests/ Makefile` — replace each with the post-migration form. Mirror Story 11.5 Task 12.5 / Story 11.4 R-M2's pre-edit-string sweep.

- [x] **Task 12 — Update `docs/throw-codes.md` row tags (AC: #18 (i))**
  - [x] 12.1 Open `docs/throw-codes.md`. §b row for `-17` (`:86`) — update `Migrating from` cell tag from `yes — Story 11.6` to `done — Story 11.6` and update `Used this epic?` to `done — Story 11.6`.
  - [x] 12.2 §b row for `-58` (`:127`) — same flip from `yes — Story 11.6` to `done — Story 11.6`.
  - [x] 12.3 §c — append two new rows for `-270` `THROW_ASM_NOT_IN_CODE` and `-271` `THROW_ASM_RANGE`, marked `done — 11.6`. Update the §c header comment about the contiguous-block extent (now `-258..-271`).
  - [x] 12.4 §d — `pictured.asm:251` row: flip migration-story tag to `**done — 11.6**`. `strings.asm:953` row: same. **Add new rows** to §d for `assembler.asm:478 check_asm_mode` (Story-11.1-inventory drift — record in §d's "Drafting reconciliation" notes mirroring Story 11.5 §c reconciliation) and `assembler.asm:1216 asm_range_err`. Both new rows tagged `done — 11.6`.
  - [x] 12.5 §e migration-ordering proposal — update Story 11.6 row to mark all sites `**done**` with the codes-used cell expanded to `-17, -58, -270, -271`.
  - [x] 12.6 Update §a "Reservations inside the antforth-extension range" paragraph to note the `-258..-271` extent (was `-258..-269` in Story 11.5).

- [x] **Task 13 — Build, full regression, and binary-size delta (AC: #15, #16, #20)**
  - [x] 13.1 `make` — clean assemble, zero errors, zero warnings.
  - [x] 13.2 `wc -c build/antforth.com` post-edit. Pre-edit baseline ≈ 17481 bytes; post-edit estimated ~17400-17430 bytes (delta ~−64 per AC #15). Record actual; investigate if delta exceeds ±150 bytes.
  - [x] 13.3 `make test` — assembly thread regression passes clean. Zero new assembly tests required.
  - [x] 13.4 `make test-repl` — confirm all tests PASS. Particularly verify pre-existing tests asserting the old `? Pictured buffer overflow` / `? missing )` / `not in CODE ?` / `range ?` formats have been migrated to `error -<N>: ...` form (AC #20).
  - [x] 13.5 Verify ABORT-site count: `grep -nE 'JP\s+w_ABORT_cf|DW\s+w_ABORT_cf' src/*.asm` returns exactly 2 instruction-line hits per AC #16.
  - [x] 13.6 Verify deleted-string / dead-code count: `str_pic_overflow`, `str_asm_notcode`, `str_asm_range`, `.paren_err_msg`, `asm_die`, `asm_print_error` all gone (Tasks 2.4, 3.3, 5.4, 6.4, 7.2, 7.3).

- [x] **Task 14 — Code review (AC: #18, all)**
  - [x] 14.1 Run adversarial code review via the `bmad-bmm-code-review` skill (or fresh `general-purpose` Agent). Per `feedback_adversarial_review.md`: a clean review is suspect — expect ≥2-3 HIGH/MEDIUM findings.
  - [x] 14.2 Triage all findings; fix HIGH and MEDIUM in-pass; defer LOW with rationale. Mirror Story 11.5's review-log discipline.
  - [x] 14.3 Post-review-fix `make` / `make test` / `make test-repl`: confirm no regressions; binary delta within ±5% of pre-review post-fix figure.
  - [x] 14.4 Record review log in Completion Notes per Story 11.5 format: `ID / Severity / Category / Description / Resolution` columns.

- [x] **Task 15 — Update sprint status and finalize (AC: #19, #20)**
  - [x] 15.1 Update `_bmad-output/implementation-artifacts/sprint-status.yaml`: `11-6-internal-error-migration-strings-io-remaining-error-sites: backlog` → `ready-for-dev` (the create-story flip; the dev pass will move it to `in-progress` then `review` → `done` per the workflow).
  - [x] 15.2 Set `Status:` field at the top of this story file to `ready-for-dev` upon initial creation. The dev pass updates it through the lifecycle.

## Dev Notes

### Mission and shape of this story

This is the **third and final word-by-word migration story** in the Stories 11.4–11.7 crawl per E11-D3 (`architecture.md:302-306`). Where Story 11.4 retired the most-used ABORT site (`do_underflow_error` and the divisor-zero guards) and Story 11.5 retired the largest contiguous block (13 sites across compiler / control-flow / assembler-internal-state), Story 11.6 retires the **last 4 internal-error sites** plus completes the Story 11.5 D1 deviation (asm_die-residual cleanup):

- 1 standard-code migration in `src/pictured.asm` (`do_pic_overflow_error` → `-17`).
- 1 standard-code migration in `src/strings.asm` (`(` `.paren_missing` → `-58`).
- 2 antforth-extension migrations in `src/assembler.asm` (`check_asm_mode` → `-270`, `asm_range_err` → `-271`) with 2 new EQU declarations in `src/constants.asm`.
- 1 asm_die body retirement (the dead-code cleanup enabled by the 2 migrations above) plus 1 dead-helper `asm_print_error` deletion.
- 4 string-pool deletions: `str_pic_overflow`, `.paren_err_msg`, `str_asm_notcode`, `str_asm_range` (and matching `_LEN` EQUs).
- 2 new description-table entries in `throw_desc_table` (`-270`, `-271`).

After this story, the kernel has zero `JP w_ABORT_cf` / `DW w_ABORT_cf` instruction-line hits *except* the two Story 11.7 capstone targets (`exception.asm:420` uncaught-recovery chain, `system.asm:137` `(ABORT")`). FR19 ("internal errors raise THROW codes") is fully delivered pre-`ABORT`-retarget; Story 11.7 retargets `ABORT` / `ABORT"` themselves, completing the exception subsystem.

What this story explicitly does **not** land:

- Any retarget of `ABORT` / `ABORT"` themselves (Story 11.7).
- Edits to `throw_desc_table` for standard codes `-17` / `-58` (Story 11.3 pre-seeded these; verified in AC #8).
- Any new mechanism (the kernel-internal entry was designed in Story 11.4 and reused by Story 11.5 / 11.6 — Story 11.6 is the third-use, mirroring `feedback_design_upfront.md`).
- Any update to architecture.md (no architectural decisions change; CCD-1 / CCD-2 / CCD-3 / E11-D1 / E11-D2 / E11-D3 all still apply unchanged).

### Architecture references

- **CCD-1 — Return-stack frame taxonomy + dual-chain discipline:** `architecture.md:168-191`. The kernel-internal entry contract from Stories 11.4 / 11.5 (BC carries the THROW code; SP/IX may be in any state; caller enters from primary set) holds for all 4 sites. Each site's documentation in this story re-affirms it.
- **CCD-2 — THROW code allocation policy:** `architecture.md:193-204`. `-17` / `-58` are ANS Forth 1994 §9.3.5 codes; `-270` / `-271` extend the antforth extension contiguous block from Story 11.5's `-258..-269` to `-258..-271`. Citation forms: `; ANS Forth 1994 §9.3.5` for standard, `; antforth extension — see docs/throw-codes.md` for extension.
- **CCD-3 — Standards-citation discipline:** `architecture.md:206-216`. Inline citation comments at every migration site per AC #12.
- **E11-D2 — CATCH/THROW mechanism:** `architecture.md:289-300`. The kernel-internal entry feeds into the post-Story-11.4.1 caught-path algorithm; Story 11.6 just adds 4 new caller sites — no new mechanism.
- **E11-D3 — Internal error migration strategy:** `architecture.md:302-306`. Word-by-word, REPL test per migration. Story 11.6 closes the migration crawl per the deliverable schedule (`-17` + `-58` for AC topic alignment with the strings/I-O theme; `-270` / `-271` as a coherent batch for the Story 11.5 D1 cleanup). Story 11.7 caps the epic by retargeting `ABORT` / `ABORT"`.
- **THROW EQU naming pattern:** `architecture.md:471-479`. Story 11.6 first-consumes `THROW_PIC_OVERFLOW` / `THROW_END_OF_INPUT` (declared by Story 11.1) and first-declares `THROW_ASM_NOT_IN_CODE` / `THROW_ASM_RANGE`.
- **Source-file organisation:** `architecture.md:434-461`. Story 11.6 edits `src/pictured.asm`, `src/strings.asm`, `src/assembler.asm`, `src/constants.asm`, `src/exception.asm` (description-table additions only — NOT the THROW code path itself), and `src/antforth.asm` (string-pool deletion).
- **Kernel-internal entry label:** `src/exception.asm:226-237` (Story 11.4 added; Story 11.5 reused). Story 11.6 reuses the same label — no new entry point needed. The FUTURE-EDIT NOTE 1 / 2 contract stays in place; verify pre-edit (Task 1.4).

### Constraints and conventions

- **Standards-compliance discipline** (`feedback_standards_compliance.md`): `-17` / `-58` are ANS §9.3.5 codes — non-negotiable. Description text in `throw_desc_table` (already seeded by Story 11.3) matches the standard's verbatim text. The `-270` / `-271` extension descriptions match the legacy `str_asm_notcode` / `str_asm_range` text — they ARE the project's own definition.
- **Plain QA language** (`feedback_plain_qa_language.md`): Completion Notes use the verdict-table format. State the value, the gate, the reason — plainly.
- **Design upfront** (`feedback_design_upfront.md`): Story 11.6 declares two extension EQUs that should have been allocated in Story 11.1 had the inventory caught the asm_die non-fan-in callers. The Story 11.5 D1 deviation forward-pointer (in `_bmad-output/implementation-artifacts/11-5-…md` Completion Notes) authorised this delayed allocation; document the inventory drift in `docs/throw-codes.md` §c and §d (Task 12).
- **TOS-in-register / DEPTH discipline** (`project_tos_in_register.md`): post-Story-11.4.1, BC = THROW code is a real TOS post-NEXT, with i\*x cells preserved underneath. Story 11.6's caught tests verify this with the `1 2 3 ' T17 CATCH . . . .` form (AC #13).
- **REPL tests preferred** (`feedback_repl_tests_preferred.md`): all Story 11.6 tests are REPL-piped Forth lines in `tests/throw_migration_tests.fth` Section 4, with corresponding Makefile entries. **No new assembly test threads.**
- **Adversarial review** (`feedback_adversarial_review.md`): expect ≥2-3 HIGH/MEDIUM findings per AC #18.
- **Follow the process** (`feedback_follow_process.md`): Tasks 1-15 form the standard create-story → dev-story → code-review → finalize workflow. No deviation from the established crawl pattern.

### Key implementation pitfalls

1. **`(`'s preserved `EXX` is non-negotiable.** The `w_PAREN_cf` body enters EXX-active context at `:909` (saving primary TOS/IP/W to shadows so the parse loop can use BC/DE/HL freely). The `.paren_missing` exit must restore primary set BEFORE the kernel-internal raise — the existing `EXX` at `:952` does exactly this. Task 3's edit moves the `EXX` to be the FIRST instruction of `.paren_missing` (clearer pairing with the `LD BC, code / JP` raise). Pre-edit it sat *between* the `CALL bdos_print_str` and `JP w_ABORT_cf`; post-edit it sits BEFORE the `LD BC, code`. Either ordering works for the kernel-internal contract — the post-edit ordering is cleaner.

2. **HOLD-count off-by-one in the pictured-overflow test.** AC #13's `: T17 0. <# 41 0 DO CHAR X HOLD LOOP #> 2DROP ;` test depends on 41 HOLDs being enough to trigger overflow. The pic_buf is 40 bytes (`PIC_BUF_SIZE EQU 40` per `src/constants.asm:36`); HLD starts at the *one-past-end sentinel* per the file-header comment at `src/pictured.asm:7-9`, so the first HOLD writes at HLD = sentinel - 1 = pic_buf + 39. The 40th HOLD writes at pic_buf + 0. The 41st HOLD attempts to decrement HLD below pic_buf — `.hc_overflow` fires. So 41 is the correct count. **Verify by direct experiment at write time** before committing the test (a wrong count silently passes the test as `0` instead of `-17`).

3. **`asm_print_error` deletion completeness.** Task 7.3 deletes the helper assuming it's dead post-`asm_die` deletion. Pre-edit verification: `grep -nE '\basm_print_error\b' src/*.asm` should show only two sources — the body at `:228-230` and the call at `asm_die:279`. Post-Task-7.2 (asm_die deletion), only the body remains; Task 7.3 removes that. **Caveat**: if any code outside `assembler.asm` calls `asm_print_error` (unlikely but possible — it has no leading underscore so could be inadvertently exposed), the deletion would break the build. The build will catch this — investigate any unresolved-reference assembler error and reconcile.

4. **`asm_print_q_crlf EQU bdos_print_q_crlf` alias preservation.** Even after `asm_print_error` deletion, the `asm_print_q_crlf` alias at `:232` is **kept** because `asm_err_bare_int` at `:346` calls it directly. Don't delete the alias by mistake during the dead-code sweep.

5. **`do_pic_overflow_error` callers.** The function is a helper called via `JP do_pic_overflow_error` (no return path expected). Callers: `hold_common.hc_overflow` at `pictured.asm:238` (which `JR Z` and `JR C` from `:230-231` fall into); also any direct caller from `#`'s underflow guard or similar. **Verify call-site enumeration** at dev-pass via `grep -nE 'JP\s+do_pic_overflow_error\b' src/*.asm` — the migration target is the helper body itself, but understanding the caller fan-in helps verify the EXX-context AC #10 claim.

6. **EVALUATE availability for `-58` caught test.** The Section 4.2 caught test uses `S" ( unterminated " EVALUATE`. Verify EVALUATE exists at write time. If absent, fall back to uncaught-only coverage for `-58` and document the deferral mirroring Story 11.5's similar caveats.

7. **Diagnostic-text drift trade documentation.** The pre-Story-11.6 `(` printed `? missing )` — syntactically specific. Post-migration the user sees `error -58: unexpected end of input` — generic ANS text. This is a deliberate trade per the unified-diagnostic discipline (mirrors `?COMP`'s `? compile only` → `error -14` migration in Story 11.5). Document the trade in `(`'s docstring AND in this story's Completion Notes so a future maintainer doesn't "regress-fix" by re-introducing the syntactic pre-print.

8. **`docs/throw-codes.md` inventory drift recording.** Story 11.1's inventory missed the `check_asm_mode` and `asm_range_err` `asm_die` callers (delegating via `JP asm_die` made them invisible to the `JP w_ABORT_cf` grep). Story 11.5's D1 deviation flagged this; Story 11.6's Task 12 records the drift in `docs/throw-codes.md` §c (the new rows for `-270` / `-271`) and §d (the new per-file entries). Match Story 11.5's "Drafting reconciliation" framing — call it out explicitly so future reviewers see the inventory's evolution.

9. **Length-byte hand-counting.** AC #9's `not in CODE` is 11 bytes (n-o-t-space-i-n-space-C-O-D-E = 11 characters); `range` is 5. Hand-count at edit time. The Story 11.3 description-table-walk relies on these length bytes — a mismatch silently misaligns subsequent entries.

10. **Forward compatibility with Story 11.7.** When Story 11.7 retargets `w_ABORT_cf` itself to `-1 THROW`, the uncaught path of Story 11.6's THROWs flows through the same `JP w_ABORT_cf` chain at `exception.asm:420`. Story 11.7 must restructure that chain to avoid infinite recursion (the same hazard Stories 11.4 / 11.5 noted). Story 11.6 doesn't change this — just adds 4 more callers to `w_THROW_cf.kernel_entry`. The post-Story-11.6 ABORT instruction-line count is exactly the 2 sites Story 11.7 will retarget.

### Test discipline

- Tests live in `tests/throw_migration_tests.fth` Section 4 (this story appends to the file). Story 11.7 will append Section 5 (`-1` / `-2` round-trips against the retargeted ABORT / ABORT").
- Counterpart `printf | $(IZCPM)` blocks land in `Makefile` starting at the highest existing PASS test number + 1 (re-checked at write time per Story 11.4 / 11.5 convention; Story 11.5 final = 744).
- For caught-THROW tests: assert the THROW code appears as the result of `' WORD CATCH .` and (for sub-tests with i\*x preservation) that pre-CATCH cells appear underneath.
- For asm-error tests (`-270`, `-271`): prefer the uncaught-recovery form (mirror Story 11.5 D2 deferral rationale) — caught form requires nested-compile shapes that introduce more test-engineering risk than the coverage value.
- For uncaught-recovery tests: use the multi-line `printf` + `tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'` pattern from Story 11.3 / 11.4 / 11.5.
- Pre-existing test diagnostic-format updates: run `grep -nE '\? Pictured buffer overflow|\? missing \)|not in CODE \?|range \?' tests/ Makefile` pre-edit; replace each occurrence with `error -<N>: <desc>` form (mirrors Story 11.5 R-M2).

### Project Structure Notes

- **Edits:**
  - `src/pictured.asm` — `do_pic_overflow_error` body migrated to -17 raise; pre-print sequence deleted; HOLD / # / SIGN docstring sweep. (Estimated: −10 binary bytes from pre-print removal + raise-pattern shorter; +6 from raise pattern; net −4 per AC #15. Pre-print message lives in `antforth.asm:221-222` — see below.)
  - `src/strings.asm` — `(` `.paren_missing` migration to -58 raise; pre-print sequence + local-label declarations deleted. (Estimated: −5 binary bytes net.)
  - `src/antforth.asm` — `str_pic_overflow` + `STR_PIC_OVERFLOW_LEN` deletion (the message string lives in this file by historical accident; verified at `:221-222`). Estimated: −26 binary bytes.
  - `src/assembler.asm` — `check_asm_mode` migration (-270); `asm_range_err` migration (-271); `asm_die` body deletion; `asm_print_error` body deletion; `str_asm_notcode` + `str_asm_range` (and `_LEN` EQUs) deleted; comment-block update. (Estimated: −40 to −50 binary bytes net.)
  - `src/constants.asm` — `THROW_ASM_NOT_IN_CODE EQU -270` + `THROW_ASM_RANGE EQU -271` declarations; comment-block update on the `-258..-271` block. (No binary impact — declarations only.)
  - `src/exception.asm` — `throw_desc_table` extended with 2 antforth-extension entries (-270, -271). (Estimated: +22 binary bytes.)
  - `tests/throw_migration_tests.fth` — appended Section 4 with caught + uncaught tests. (Estimated: +30-50 lines.)
  - `Makefile` — appended Story 11.6 PASS test blocks; ~10-15 new test entries. Pre-existing diagnostic-format string updates (mirror Story 11.5 Task 12.5).
  - `docs/throw-codes.md` — §a / §b / §c / §d / §e tag flips + new rows for `-270` / `-271` + per-file inventory rows for `assembler.asm:478` / `:1216`.
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` — `11-6-…` entry: `backlog` → `ready-for-dev`.
  - `_bmad-output/implementation-artifacts/11-6-internal-error-migration-strings-io-remaining-error-sites.md` — this file (Status, task checkboxes, Completion Notes, File List, Change Log on dev pass).
- **No new files.** Story 11.6 appends to existing files only.
- **File-list expectation in Dev Agent Record:** 6 modified `*.asm` files + 1 modified `*.fth` file + Makefile + `docs/throw-codes.md` + sprint-status + this story file.

### Previous-story intelligence (Stories 11.4 / 11.4.1 / 11.5 patterns to reuse and pitfalls to avoid)

**Reuse:**

- *Verdict-table Completion Notes* (Stories 11.4 / 11.5): one row per AC, columns `Gate text | Evidence | Verdict`. Mirror exactly.
- *Per-task evidence sections with explicit grep / wc commands*: "ran command X, got output Y, here's the implication" — no hand-waving.
- *Re-grep before publishing*: every line number cited in this story (e.g., `src/pictured.asm:251`, `src/strings.asm:953`, `src/assembler.asm:478`) re-verified at dev-pass time. Files have been edited since story-drafting (specifically: `src/exception.asm` and `tests/throw_migration_tests.fth` by Stories 11.4 / 11.4.1 / 11.5; `src/system.asm`, `src/compiler.asm`, `src/control_flow.asm`, `src/outer_interpreter.asm`, `src/assembler.asm` by Stories 11.4 / 11.5). Drift is expected; reconcile at write time.
- *Adversarial-review-finding triage table*: Story 11.5's review log format (ID / Severity / Category / Description / Resolution columns) replicated in Completion Notes.
- *Binary-size delta table*: Stage / bytes / delta, mirroring Stories 11.4 / 11.5 Completion Notes.
- *Inline citation comment form*: `; -<N> THROW (Story 11.6): <desc> per ANS Forth 1994 §9.3.5` (or `per antforth extension — see docs/throw-codes.md` for `-270` / `-271`).
- *Diagnostic-format propagation discipline*: Story 11.5's R-M2 review found 19 stale `\ expect:` references. Story 11.6's pre-print removals (4 sites) will trigger a similar sweep — search the entire `tests/` and `Makefile` for legacy diagnostic literals (`? Pictured buffer overflow`, `? missing )`, `not in CODE ?`, `range ?`).

**Pitfalls Stories 11.4 / 11.4.1 / 11.5 reviews surfaced (avoid in 11.6):**

- *F1 / F2 / F12 (11.5): EXX-set inversion at kernel-internal raise sites* — Story 11.6 spot-checks each of the 4 new raise sites' caller contexts (AC #10) and documents the verification evidence per site.
- *D1 (11.5): out-of-scope callers missed by the inventory* — Story 11.6 addresses the D1 deviation by Tasks 4-7. To avoid creating a new D1-equivalent: spot-check `JP\s+w_ABORT_cf` / `DW\s+w_ABORT_cf` callers at **all transitive levels** (not just direct), and likewise verify `JP do_pic_overflow_error` callers, `JP asm_die` callers (zero post-Tasks-5/6), `CALL check_asm_mode` callers, `JP asm_range_err` callers all enter from primary set per AC #10.
- *F3 (11.5 / 11.4): test gaps in non-colon IX frames* — Story 11.6's caught tests should include at least one DO-LOOP shape (e.g., the pictured-overflow test naturally uses DO-LOOP — `41 0 DO CHAR X HOLD LOOP`).
- *R-M1 (11.4 / 11.5): stale headers* — every site this story migrates has a docstring comment that currently describes the pre-migration ABORT behaviour. Each docstring must be updated in-pass to reflect the post-migration THROW behaviour.
- *R-M2 (11.4 / 11.5): stale `\ expect:` reference comments* — pre-edit grep + Task 11.5 sweep.
- *R-M3 (11.4 / 11.5): docs/throw-codes.md not updated* — Task 12 explicitly handles all five sub-rows (§a, §b, §c, §d, §e).
- *R-M4 (11.4): comment overclaim* — be careful about the description text in the new `throw_desc_table` entries. The text matches `str_asm_notcode` / `str_asm_range` content verbatim; cross-check.
- *F10 (11.5): TICK-of-undefined-name fires at REPL execute time* — Story 11.6 doesn't migrate any TICK-related path, so this gotcha doesn't apply. (Mentioned for completeness — the unified caught-test pattern still uses `' WORD CATCH .` for migrated kernel words.)
- *F14 (11.5): broken caught-test forms* — verify each Section 4 caught test actually triggers the migration site at its intended phase (compile vs execute). The pictured-overflow test (`: T17 ... ;` then `' T17 CATCH .`) places HOLD inside T17's body, so the overflow fires at T17's execute time, inside the CATCH frame. Confirm by direct REPL experiment before committing.
- *F12 (11.5 second-pass): spurious EXX adds inverting register sets* — Story 11.6's sites (`do_pic_overflow_error`, `(` `.paren_missing`, `check_asm_mode`, `asm_range_err`) all need careful EXX-set analysis. Don't add EXX restores defensively; confirm each site enters in primary set and only insert EXX where the caller's pre-edit code was post-EXX (only `(` `.paren_missing` falls into this category — the other three callers are primary-set DEFCODE bodies).

### Comparison to Stories 11.4 / 11.5 adversarial review F-findings (Story 11.6 watch-list)

Stories 11.4 / 11.5 reviews found 13 + 15 issues respectively. Story 11.6 deliberately watches for these analogous issues:

- **Future-edit hazard at the new raise sites** (analog of 11.4 F2): write the comment block above each new raise site to describe the kernel-internal entry contract and the EXX-restore precondition (only one of the 4 sites needs EXX).
- **Edge cases at the migration boundaries** (analog of 11.4 F2 BC=0 case): the new raise sites pass non-zero THROW codes; verify each `LD BC, THROW_<NAME>` evaluates to a non-zero EQU value. (All Story 11.6 codes are non-zero — `-17`, `-58`, `-270`, `-271`. None match `BC=0`.)
- **Test coverage gaps** (analog of 11.5 F3 / F6): include at least one DO-LOOP shape (the pictured-overflow test inherently uses DO-LOOP); positive-control tests confirming success path returns 0.
- **Citation form drift** (analog of 11.5 F2): every new inline comment uses `ANS Forth 1994 §9.3.5` for standard codes; `antforth extension — see docs/throw-codes.md` for extensions. Cross-check at edit time.
- **Lax test ordering for uncaught recovery** (analog of 11.4 F5 / R-L4): ordered `tr '\r\n' '  ' | grep -qE 'error -<N>: <desc>.*<recovery-marker>'` patterns.
- **First/second-use docs for new instruction patterns** (analog of 11.5 F7): no new instruction patterns this story (the `JP w_THROW_cf.kernel_entry` pattern is established in Story 11.4; the description-table pattern is established in Story 11.3).
- **Story-vs-code disclosure of deviations** (analog of 11.5 D1): if dev-pass cross-references a description string against the standard at write time and finds a discrepancy, document it explicitly in Completion Notes.
- **Asm-die residual completeness** (Story 11.6 specific watch-item): post-deletion, `grep -nE '\basm_die\b' src/*.asm` returns zero hits OR only narrative-comment hits; `grep -nE '\basm_print_error\b' src/*.asm` similarly. If any remain, investigate (a stale `JP asm_die` somewhere would have failed the build, but a stale `; … via asm_die …` comment is a documentation drift to fix).
- **Diagnostic-text trade visibility** (Story 11.6 specific watch-item): the `(` `? missing )` → `error -58: unexpected end of input` migration sacrifices syntactic specificity for unified-diagnostic uniformity. Document the trade in `(`'s docstring + Completion Notes so a future "fix the regression" PR doesn't undo the discipline.

### References

- `_bmad-output/planning-artifacts/epics.md:833-859` — Story 11.6 acceptance criteria source.
- `_bmad-output/planning-artifacts/architecture.md:168-191` — CCD-1 dual-chain discipline.
- `_bmad-output/planning-artifacts/architecture.md:193-204` — CCD-2 THROW code allocation policy.
- `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 standards-citation discipline.
- `_bmad-output/planning-artifacts/architecture.md:289-300` — E11-D2 CATCH/THROW mechanism (post-Story-11.4.1).
- `_bmad-output/planning-artifacts/architecture.md:302-306` — E11-D3 internal error migration strategy (this story is the third + final in the crawl, completing the pre-`ABORT`-retarget delivery).
- `_bmad-output/planning-artifacts/architecture.md:471-479` — THROW EQU naming + citation pattern.
- `_bmad-output/planning-artifacts/architecture.md:773` — Epic 11 file-touch table.
- `_bmad-output/planning-artifacts/prd.md:392-402` — FR15-FR22 (Epic 11 functional requirements; FR19 = "internal errors raise THROW codes" — Story 11.6 closes the pre-ABORT-retarget partial of this requirement).
- `_bmad-output/planning-artifacts/prd.md:455-463` — NFR3, NFR6, NFR7 (CATCH/THROW perf + REPL survivability + state integrity).
- `docs/throw-codes.md` — Story 11.1 inventory; §d rows for `pictured.asm:251` / `strings.asm:953` migrate here; §c gains 2 new rows for `-270` / `-271`; §d gains 2 new rows for `assembler.asm:478` / `:1216`; §e migration-ordering proposal Stage 11.6 marks `done`.
- `_bmad-output/implementation-artifacts/11-1-abort-site-migration-inventory-throw-code-table-and-code-equs.md` — Story 11.1's verdict-table format and EQU declarations (consumed here).
- `_bmad-output/implementation-artifacts/11-2-exception-frame-infrastructure-and-catch-word.md` — Story 11.2's CATCH frame.
- `_bmad-output/implementation-artifacts/11-3-throw-word-and-uncaught-throw-repl-handler.md` — Story 11.3's THROW word + uncaught-handler + description-table seeding (Story 11.6 extends with -270 / -271 + relies on the seeded -17 / -58 entries).
- `_bmad-output/implementation-artifacts/11-4-internal-error-migration-stack-arithmetic-memory-primitives.md` — Story 11.4's pattern (kernel-internal entry, in-pass header sweep, R-M2 stale-expect cleanup, verdict-table format) replicated here.
- `_bmad-output/implementation-artifacts/11-4-1-catch-throw-ix-preservation-bug-fix.md` — Story 11.4.1's i\*x preservation contract (inherited by every kernel-internal THROW raise site this story adds).
- `_bmad-output/implementation-artifacts/11-5-internal-error-migration-dictionary-compiler-control-flow.md` — Story 11.5's pattern + the D1 deviation forward-pointer that Tasks 4-7 of this story address.
- `src/exception.asm:226-237` — Story 11.4's kernel-internal entry label `w_THROW_cf.kernel_entry` (reused by Story 11.6).
- `src/exception.asm:560-635` — `throw_desc_table` (Story 11.6 appends 2 entries before the `DW 0` terminator).
- `src/exception.asm:582-590` — pre-seeded `-17` / `-58` rows (Story 11.3; not touched by Story 11.6).
- `src/constants.asm:64-93` — `THROW_*` EQUs (declared by Story 11.1; Story 11.6 first-consumes `-17` / `-58` and adds `-270` / `-271`).
- `src/pictured.asm:241-251` — `do_pic_overflow_error` (Task 2 site).
- `src/pictured.asm:51-72`, `:153-159` — HOLD / # / SIGN docstrings (Task 2.3 sweep).
- `src/strings.asm:893-953` — `(` IMMEDIATE word, `.paren_missing` exit (Task 3 site).
- `src/strings.asm:955-957` — local-label `.paren_err_msg` / `.paren_err_len` (Task 3.3 deletion).
- `src/antforth.asm:221-222` — `str_pic_overflow` / `STR_PIC_OVERFLOW_LEN` (Task 2.4 deletion).
- `src/assembler.asm:262-280` — `asm_die` body + docstring (Task 7 deletion).
- `src/assembler.asm:223-230` — `asm_print_error` body + docstring (Task 7.3 deletion).
- `src/assembler.asm:472-478` — `check_asm_mode` (Task 5 site).
- `src/assembler.asm:1213-1216` — `asm_range_err` (Task 6 site).
- `src/assembler.asm:203-204`, `:218-219` — `str_asm_notcode` / `str_asm_range` declarations (Task 5.4 / 6.4 deletion).
- `tests/throw_migration_tests.fth` — Sections 1 / 2 (Story 11.4); Section 3 (Story 11.5); Story 11.6 appends Section 4.
- `tests/exception_tests.fth:13-15` — TICK execute-time-parsing convention.
- `Makefile` — pre-existing diagnostic-format strings (`? Pictured buffer overflow`, `? missing )`, `not in CODE ?`, `range ?`) updated per Task 11.5.
- DPANS94 §9.3.5 / Forth 2014 §9.3.5 — `THROW` code table (`-17` pictured numeric output string overflow, `-58` unexpected end of input).

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

- Pre-edit ABORT-site grep: 5 instruction-line hits (`assembler.asm:280`, `exception.asm:420`, `pictured.asm:251`, `strings.asm:953`, `system.asm:137`). Post-edit: 2 (`exception.asm:420`, `system.asm:137`). Comment-line matches excluded.
- Pre-edit binary: 17481 bytes. Post-edit: 17419 bytes. Delta: **−62** (predicted −64; within budget).
- Pre-edit PASS test high-water mark: 744 (Story 11.5 final). Post-edit: 753 (+9 new Story 11.6 tests).
- `make`: clean assemble, 0 errors, 0 warnings.
- `make test`: clean (assembly thread regression — output matches expected).
- `make test-repl`: 762 PASS, 0 FAIL.
- Sanity probes (interactive REPL):
  - `error -17: pictured numeric output string overflow` ✓ (40-byte buffer + 41 HOLDs)
  - `error -58: unexpected end of input` ✓ (`( unterminated`)
  - `error -270: not in CODE` ✓ (`NOP,` outside CODE)
  - `error -271: range` ✓ (`8 # B BIT,` inside CODE)
  - Caught: `' T17 CATCH .` returns `-17  ok` ✓
  - i*x preserved: `1 2 3 ' T17 CATCH . . . .` returns `-17 3 2 1  ok` ✓
- EXX-context spot-checks (AC #10):
  - `do_pic_overflow_error` reached only via `hold_common` from primary-set DEFCODE bodies (HOLD/`#`/SIGN/HOLDS) — no EXX involved at the raise.
  - `(` `.paren_missing` body at `strings.asm:945` enters via JR Z from EXX-active context (primary saved in shadows at `:901`); the `EXX` at `:946` correctly restores primary set BEFORE `LD BC, code`.
  - `check_asm_mode` callers spot-checked at `:1003/:1124/:1313/:1411/:2010` — entering primary set with `CALL check_asm_mode` first (`:1003/:1124/:1411` are DEFCODE bodies; `:1313 asm_pushpop_word` and `:2010 asm_arith_word` are shared helpers invoked from DEFCODE bodies — no EXX precedes either CALL).
  - `asm_range_err` callers at `:1135/:1138/:1143` (in `+D`) and `:3076/:3113/:3145` (in bit-op guards) — all primary-set DEFCODE-body sites.

### Completion Notes List

#### Verdict table (one row per AC)

| AC # | Gate text | Evidence | Verdict |
|---|---|---|---|
| 1 | 4 catalogued lines no longer end in `JP w_ABORT_cf`; ABORT count = 2 (`exception.asm:420`, `system.asm:137`) | `grep -nE 'JP\s+w_ABORT_cf\|DW\s+w_ABORT_cf' src/*.asm \| grep -vE '^[^:]+:[0-9]+:\s*;'` returns 2 lines exactly | **PASS** |
| 2 | `do_pic_overflow_error` body replaced with `LD BC, THROW_PIC_OVERFLOW / JP w_THROW_cf.kernel_entry`; `str_pic_overflow` deleted | `src/pictured.asm:246-263` shows new body; `grep str_pic_overflow src/*.asm` returns zero hits | **PASS** |
| 3 | `(` `.paren_missing` body replaced; pre-print + `.paren_err_msg`/`.paren_err_len` deleted; existing `EXX` preserved (now placed FIRST per story Pitfall 1) | `src/strings.asm:945-959`; `grep \.paren_err_msg\|\.paren_err_len src/*.asm` returns zero hits | **PASS** |
| 4 | Two new EQUs `THROW_ASM_NOT_IN_CODE = -270` / `THROW_ASM_RANGE = -271` added with citation comment | `src/constants.asm:94-95` | **PASS** |
| 5 | `check_asm_mode` failure path migrated; pass path preserved; `str_asm_notcode` deleted | `src/assembler.asm:446-453` shows new body; `grep str_asm_notcode src/*.asm` returns zero hits | **PASS** |
| 6 | `asm_range_err` body migrated; `str_asm_range` deleted | `src/assembler.asm:1185-1196`; `grep str_asm_range\b src/*.asm` returns zero hits | **PASS** |
| 7 | `asm_die` body deleted; `asm_print_error` body deleted; `asm_print_q_crlf` alias preserved | `grep -nE '\basm_die\b\|\basm_print_error\b' src/*.asm` returns only narrative-comment hits; `asm_print_q_crlf EQU bdos_print_q_crlf` at `:217` preserved and consumed at `:317` (asm_err_bare_int) | **PASS** |
| 8 | No edits to standard-code rows for -17/-58 in `throw_desc_table` | `grep -nE 'DW\s+-17\|DW\s+-58' src/exception.asm` returns the two pre-existing rows unchanged | **PASS** |
| 9 | 2 new entries appended (`-270 "not in CODE" / 11`, `-271 "range" / 5`) | `src/exception.asm:639-644` shows the two new rows in code order before `DW 0` terminator at `:645`. Length bytes hand-counted: `not in CODE` = 11, `range` = 5 | **PASS** |
| 10 | All 4 raise sites verified primary-set at entry | EXX spot-checks documented in Debug Log References above. `(`'s `EXX` placed BEFORE `LD BC, code` per story Pitfall 1 | **PASS** |
| 11 | EQU symbols used (not bare numerical literals) | `grep -nE 'LD\s+BC,\s*-(17\|58\|270\|271)\b' src/*.asm` returns zero hits; consumption sites use `THROW_PIC_OVERFLOW`, `THROW_END_OF_INPUT`, `THROW_ASM_NOT_IN_CODE`, `THROW_ASM_RANGE` | **PASS** |
| 12 | Inline citation comments at all 4 raise sites match the prescribed form | `pictured.asm:255-256`, `strings.asm:949-957`, `assembler.asm:447-448`, `assembler.asm:1192-1193` all carry `; -<N> THROW (Story 11.6): <desc> per ANS Forth 1994 §9.3.5` (or `per antforth extension — see docs/throw-codes.md`) | **PASS** |
| 13 | Section 4 added to `tests/throw_migration_tests.fth` covering -17 caught + i*x + DEPTH + positive controls + deferral notes for -58/-270/-271 caught | `tests/throw_migration_tests.fth:202-260`. Closure 2026-04-28 by Story 11.5.3: F8 / Review Follow-up #1 fixed by EVALUATE CATCH wrapper + QUERY defensive reset; -58 caught coverage added at Section 4.0 (REPL tests 783-785), -258..-271 caught coverage extended at Section 4.3 (REPL tests 786-796, 11 of 14 codes — -263/-264/-265 deferred per Story 11.5.3 AC #6.4 due to BDOS line-buffer constraints). See `_bmad-output/implementation-artifacts/11.5-3-paren-evaluate-source-frame-fix.md` | **PASS** (closed by Story 11.5.3 — was PARTIAL pending F8 fix) |
| 14 | Per-line `\ expect:` convention + matching Makefile blocks; new tests start at high-water-mark + 1 | New tests 745–753 in `Makefile:6418-6504` follow Story 11.4/11.5 conventions | **PASS** |
| 15 | Binary delta within budget (target ≈ −64; investigate if > ±150) | Pre: 17481 → Post: 17419 → Δ = −62. Within budget | **PASS** |
| 16 | Post-Story-11.6 ABORT-instruction-line count = 2 | Confirmed via `grep -nE 'JP\s+w_ABORT_cf\|DW\s+w_ABORT_cf' src/*.asm \| grep -vE ':\s*;'` returning exactly `exception.asm:420` and `system.asm:137` | **PASS** |
| 17 | At least one uncaught-recovery test per code (-17, -58, -270, -271) | Tests 750/751/752/753 cover all four; each asserts `error -<N>: <desc>.*99  ok` | **PASS** |
| 18 | Adversarial review yields ≥2-3 HIGH/MEDIUM findings | 5 findings raised (4 MEDIUM + 1 LOW). F1/F2/F3 fixed in-pass; F4 deferred with documentation; F5 fixed in-pass. See Review Log below | **PASS** |
| 19 | Verdict-table format used in Completion Notes | This table | **PASS** |
| 20 | `make` / `make test` / `make test-repl` clean post-edit; pre-existing literal-expect tests migrated | `make`: 0 errors / 0 warnings. `make test`: PASS. `make test-repl`: 762 PASS / 0 FAIL. Pre-existing literal-expect tests 100/150/171/207/222/566 migrated to `error -<N>: <desc>` form | **PASS** |

#### Adversarial review log (Task 14)

| ID | Severity | Category | Description | Resolution |
|---|---|---|---|---|
| F1 | MEDIUM | docstring drift | `asm_range_err` docstring cited stale caller line numbers (`:1160/:1163/:1168` and `:3095/:3132/:3164`); actual sites are `:1135/:1138/:1143` and `:3074/:3111/:3143` | Fixed: docstring at `src/assembler.asm:1186-1190` updated with correct line numbers |
| F2 | MEDIUM | docstring drift | `LABEL`'s `Errors:` block at `assembler.asm:2227-2230` named pre-Story-11.6 literal diagnostics (`not in CODE ?`, `LABEL must precede opcodes ?`, `too many labels ?`) | Fixed: replaced with THROW-code form (-270, -262, -264) |
| F3 | MEDIUM | docstring drift | `docs/ans-forth-core-compliance.md:204` HOLD row's Notes column still framed `-17 THROW` as Epic 11 future work | Fixed: row updated to "Underflow → -17 THROW (...) per ANS Forth 1994 §9.3.5 (Story 11.6)" |
| F4 | MEDIUM | semantic encoding | `THROW_ASM_RANGE = -271` collapses two distinct conditions (`+D` displacement / `BIT,` bit-number); diagnostic gives no locality. Pre-existing defect inherited from legacy `range ?` literal | Deferred: AC #4 committed to single `-271` allocation; the principled split (-271 / -272) requires story-spec amendment. Logged in `docs/throw-codes.md` §c with `feedback_design_upfront.md` rationale and a future-work pointer for the split |
| F5 | LOW | test honesty | Test 749 description "properly-closed `(` CATCH returns 0" overstates coverage — `(` is IMMEDIATE so it ran at compile time, the colon body has no `(` at runtime | Fixed: assertion message rewritten to "no-throw colon body containing compile-time paren-comment returns 0" + matching note in `tests/throw_migration_tests.fth` Section 4 |
| F6 | MEDIUM | docstring drift (Review-2) | `asm_range_err` docstring at `src/assembler.asm:1187-1188`, `docs/throw-codes.md:220` Note on -271 collapse, and Debug Log References in this file all cited bit-op range-guard line numbers as `:3074/:3111/:3143`; actual lines are `:3076/:3113/:3145` (off by 2). F1 fixed the +D portion and overlooked the bit-op portion | Fixed: corrected to `:3076/:3113/:3145` in all three locations |
| F7 | MEDIUM | partial implementation (Review-2) | AC #13 caught-form for -58 deferred without spec authorisation: AC #13 only authorised falling back to uncaught-only if `EVALUATE` was absent; EVALUATE is present at `outer_interpreter.asm:387`. Verdict table previously claimed AC #13 PASS | Partial-resolved: AC #13 verdict downgraded to PARTIAL; -58 caught coverage deferred to follow-up F8 |
| F8 | MEDIUM | latent defect (Review-2) | `(` does not respect EVALUATE's source-frame boundary: `: T58 S" ( unterminated " EVALUATE ; ' T58 CATCH . CR DEPTH .` produces no output (CATCH/`.`/CR/DEPTH/`.` apparently consumed by `(` reading past EVALUATE's source into the outer REPL line); the `-58` only fires when a subsequent line is parsed. Worse than the dev's "silent CATCH return" description. Pre-existing antforth-`(` defect surfaced by Story 11.6's caught-test attempt | Deferred: filed as Review Follow-up #1 below; Story 11.6 does not introduce the defect, and addressing it requires changes to `w_PAREN_cf`/EVALUATE source-frame plumbing that are out of scope. -58 caught coverage waits on the fix |
| F9 | MEDIUM | verdict-table drift (Review-2) | AC #5 verdict cited `src/assembler.asm:436-453` for `check_asm_mode` body; actual location is `:446-453` | Fixed: verdict updated to `:446-453` |
| F10 | LOW | Debug Log overclaim (Review-2) | check_asm_mode caller spot-check claimed all 5 cited sites are "DEFCODE bodies entering primary set"; `:1313 asm_pushpop_word` and `:2010 asm_arith_word` are shared helpers, not DEFCODE bodies (primary-set entry contract is still satisfied — no EXX precedes either CALL) | Fixed: Debug Log Reference rewritten to distinguish the three DEFCODE bodies from the two shared helpers |

Three passes through review (Story 11.5 pattern + Review-2 pass triggered by code-review skill). F1–F5 from Review-1; F6–F10 from Review-2. F4 split decision and F8 EVALUATE source-frame defect remain future-work. No HIGH findings — the EXX-hygiene cross-check (the highest-risk angle per Story 11.5 review F1/F2/F12) came back clean across all 4 sites. Length-byte hand-counts verified.

#### Review Follow-ups

1. **`(` / EVALUATE source-frame defect (F8).** ~~When `(` is invoked inside `EVALUATE`'s source frame and reaches end-of-source without `)`, it should raise `-58` against EVALUATE's frame. Observed: the parser walks past EVALUATE's source into whatever input is next provided to the outer REPL, swallowing subsequent commands until it finally hits a line where parsing fails. Affects any code that wraps user-supplied source in `EVALUATE` and tries to `CATCH` parser errors. Out-of-scope for Story 11.6; candidate for an Epic-11 follow-up story or a separate bug-fix story. Reproduction: `: T58 S" ( unterminated " EVALUATE ; ' T58 CATCH .` then any subsequent line — the next line gets eaten and `-58` fires against *its* parsing.~~ **CLOSED 2026-04-28 by Story 11.5.3** (`_bmad-output/implementation-artifacts/11.5-3-paren-evaluate-source-frame-fix.md`). Root cause: not `(` itself but EVALUATE's lack of THROW-safe (RESTORE-INPUT). Fix: option (b)+(c) hybrid — EVALUATE wraps INTERPRET in CATCH so (RESTORE-INPUT) runs on both success and THROW paths; QUERY also defensively re-asserts `tib_addr = tib_buffer` and `source_id = 0`. AC #13 verdict above flipped from PARTIAL to PASS.

#### Diagnostic-text trade documentation (AC #18(a))

Pre-Story-11.6, `(` printed `? missing )` — syntactically specific. Post-Story-11.6, the user sees `error -58: unexpected end of input` — generic ANS text. The trade is deliberate per the unified-diagnostic discipline (mirrors `?COMP`'s `? compile only` → `error -14: interpreting a compile-only word` migration in Story 11.5). Documented in `(`'s docstring at `src/strings.asm:889-902` and in this completion note so a future "fix the regression" PR doesn't undo the discipline. If a syntactic-specificity requirement re-emerges, a future refactor can introduce a `(`-specific extension code or a per-code prefix mechanism.

#### Inventory drift documentation (AC #18(i))

Story 11.1's enumerated inventory (`grep -nE 'JP\s+w_ABORT_cf'`) missed the two non-fan-in `asm_die` callers (`check_asm_mode`, `asm_range_err`) because they routed through `asm_die` rather than to `w_ABORT_cf` directly — invisible to the grep. Story 11.5's adversarial review surfaced the residual; Story 11.5 D1 deviation forward-pointer authorised Story 11.6 to handle the cleanup. The drift is now recorded in `docs/throw-codes.md` §c (the new -270/-271 rows) and §d (the new per-file rows for `assembler.asm:472`/`:1213`). Pattern matches Story 11.5's "Drafting reconciliation" framing.

### File List

Modified:
- `src/pictured.asm` — `do_pic_overflow_error` migrated to -17 raise; HOLD/hold_common docstrings updated.
- `src/strings.asm` — `(` `.paren_missing` migrated to -58 raise; pre-print + local labels deleted; `(` docstring updated.
- `src/assembler.asm` — `check_asm_mode` migrated to -270 raise; `asm_range_err` migrated to -271 raise; `asm_die` body deleted; `asm_print_error` body deleted; `str_asm_notcode` and `str_asm_range` (and `_LEN` EQUs) deleted; comment block at `:187-201` updated; LABEL `Errors:` docstring updated; `.fix_already` comment updated; asm_print_error_with_name docstring updated.
- `src/constants.asm` — added `THROW_ASM_NOT_IN_CODE EQU -270` and `THROW_ASM_RANGE EQU -271`; updated -258..-269 block comment to extend to -271.
- `src/exception.asm` — appended 2 antforth-extension entries to `throw_desc_table` (-270, -271); updated header comment to extend range to -271.
- `src/antforth.asm` — `str_pic_overflow` and `STR_PIC_OVERFLOW_LEN` deleted.
- `tests/throw_migration_tests.fth` — appended Section 4 with caught + i*x + positive-control tests + deferral caveats.
- `tests/pictured_tests.fth` — OV41 test updated from `? Pictured buffer overflow` literal to `error -17: pictured numeric output string overflow`.
- `Makefile` — appended Story 11.6 PASS tests 745–753; pre-existing literal-expect tests migrated (100/150/171/207/222/566).
- `docs/throw-codes.md` — §a paragraph extended to -271; §b -17/-58 rows flipped to `done — Story 11.6`; §c +2 rows for -270/-271 with collapse-rationale note; §d per-file rows updated for `assembler.asm:472/:1213` + `pictured.asm:251` + `strings.asm:953`; §e migration-ordering row 11.6 expanded.
- `docs/ans-forth-core-compliance.md` — HOLD row Notes column updated to post-Story-11.6 form.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `11-6-…` flipped from `ready-for-dev` to `review`.
- `_bmad-output/implementation-artifacts/11-6-internal-error-migration-strings-io-remaining-error-sites.md` — this file (Status, task checkboxes, Dev Agent Record, Change Log).

No new files.

### Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-26 | Story 11.6 created from epics.md:833-859 + Story 11.1 inventory + Story 11.5 D1 deviation forward-pointer. Status: backlog → ready-for-dev. | Ant (claude-opus-4-7) |
| 2026-04-26 | Dev pass: migrated 4 internal-error sites to kernel-internal THROW (-17, -58, -270, -271); retired asm_die residual; deleted 4 obsolete strings; added 2 EQUs + 2 description-table entries; appended 9 REPL tests (745–753); migrated 6 pre-existing literal-expect tests; updated docs/throw-codes.md and docs/ans-forth-core-compliance.md. Adversarial review yielded 5 findings (4 MEDIUM + 1 LOW); F1/F2/F3/F5 fixed in-pass, F4 (range-collapse) deferred with documented rationale. Binary delta: −62 bytes. ABORT-instruction-line count: 5 → 2 (Story 11.7 capstone scope). 0 regressions; 762 PASS / 0 FAIL on `make test-repl`. Status: in-progress → review. | Ant (claude-opus-4-7) |
| 2026-04-27 | Code-review pass (bmad-bmm-code-review skill, Review-2): 5 additional findings (4 MEDIUM + 1 LOW). F6 fixed bit-op range-guard line-number drift in `asm_range_err` docstring + `docs/throw-codes.md:220` + Debug Log References (`:3074/:3111/:3143` → `:3076/:3113/:3145`). F7 downgraded AC #13 verdict from PASS to PARTIAL (caught -58 deferral exceeds spec authorisation). F8 filed `(` / EVALUATE source-frame defect as Review Follow-up #1 (out-of-scope; pre-existing). F9 corrected AC #5 verdict location (`:436-453` → `:446-453`). F10 tightened Debug Log Reference for check_asm_mode caller spot-check. No code/test regressions; binary unchanged. | Ant (claude-opus-4-7) |
