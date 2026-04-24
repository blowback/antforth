# Story 10.9: Remaining Core gap words (`*/`, `*/MOD`, `EVALUATE`, `ENVIRONMENT?`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the remaining single-cell §6.1 Core gap words — `*/`, `*/MOD`, `EVALUATE`, and `ENVIRONMENT?` — implemented,
so that antforth's §6.1 Core coverage reaches **133 / 133 = 100.0% with zero deliberate omissions**, satisfying FR15 / NFR10 as written and closing the last implementation gate before Story 10.10's CCD-4 benchmark + release gate.

## Acceptance Criteria

**Scope (set by Story 10.1 + party-mode decision 2026-04-20, mirrored in `_bmad-output/planning-artifacts/epics.md:626-659`):**

1. **Given** the four in-scope words (`*/` §6.1.0100, `*/MOD` §6.1.0110, `EVALUATE` §6.1.1360, `ENVIRONMENT?` §6.1.1345) **When** this story completes **Then** each is implemented per its DPANS94 semantics; each source site carries an ANS Forth 1994 §<section> citation and a stack-effect comment per CCD-3 (`architecture.md:206-216`).

2. **Given** `*/` `( n1 n2 n3 -- n4 )` **When** invoked **Then** `n4 = (n1 × n2) / n3` is computed via a **double-cell intermediate** — literally `>R M* R> SM/REM SWAP DROP` or equivalent — so that the `n1 × n2` product does not overflow a single cell (e.g., `32767 32767 32767 */` returns `32767`, not wrap-around garbage). Per DPANS94 §6.1.0100 the quotient is rounded toward zero (symmetric division, inherited from `SM/REM` §6.1.2214); floored behaviour is NOT requested.

3. **Given** `*/MOD` `( n1 n2 n3 -- n4 n5 )` **When** invoked **Then** `n5 = (n1 × n2) / n3` (quotient) and `n4 = (n1 × n2) mod n3` (remainder), again via a double-cell intermediate — literally `>R M* R> SM/REM` or equivalent. Remainder sign matches dividend sign per symmetric-division convention (DPANS94 §6.1.0110).

4. **Given** `EVALUATE` `( i*x c-addr u -- j*x )` **When** invoked with a string at `c-addr/u` **Then** it (a) saves the current input-source specification (`tib_addr`, `tib_len`, `tib_in`, `source_id` — four USER fields), (b) sets the input source to the supplied string (`tib_addr = c-addr`, `tib_len = u`, `tib_in = 0`, `source_id = -1` per Forth 2014 §6.2.2218 for the EVALUATE source-id sentinel), (c) calls the existing `INTERPRET` thread, (d) restores the saved source on normal completion, leaving any interpreted side effects (stack values, dictionary additions) in place per DPANS94 §6.1.1360.

5. **Given** `EVALUATE` is called with a string that contains a parse error (unknown word, number-parse failure) **When** INTERPRET triggers its current ABORT path **Then** the pre-Epic-11 ABORT semantics apply (both stacks reset, REPL re-entered via QUIT); the saved source-spec on the return stack is discarded by the wholesale rstack reset in `w_ABORT_cf` (`system.asm:258-264`). This is the same ABORT-absorbs-rstack-state behaviour that `w_ABORT_QUOTE` relies on — NOT a leak. Epic 11 will migrate this to `THROW`-safe save/restore; Story 10.9 does NOT preempt that migration.

6. **Given** `EVALUATE` is called with `u = 0` **When** the body runs **Then** the string is empty; INTERPRET's `WORD` / `C@` loop detects zero-count and returns via its `.interp_done` branch (`outer_interpreter.asm:227-229`) without a parse error; the source spec is restored cleanly; EVALUATE returns with no stack residue beyond what the caller supplied.

7. **Given** `EVALUATE` is called from within an `EVALUATE` (nesting) **When** the inner call saves its parent's state to the return stack **Then** arbitrary nesting depth works (limited only by RS_SIZE), because each inner call saves and restores independently. Regression test: `S" 10 S\" 32 \" EVALUATE +" EVALUATE` ≡ `42` (nested EVALUATE of a string that itself contains an EVALUATE). Save-restore is Last-In-First-Out against the return stack per Forth convention.

8. **Given** `ENVIRONMENT?` `( c-addr u -- false | i*x true )` **When** queried against each of the **14 DPANS94 §3.2.6 standard query strings** — `/COUNTED-STRING`, `/HOLD`, `/PAD`, `ADDRESS-UNIT-BITS`, `CORE`, `CORE-EXT`, `FLOORED`, `MAX-CHAR`, `MAX-D`, `MAX-N`, `MAX-U`, `MAX-UD`, `RETURN-STACK-CELLS`, `STACK-CELLS` — **Then** each returns the correct antforth value(s) followed by `true`:

   | Query string | Return (stack order: value then `true`) | Source |
   |---|---|---|
   | `/COUNTED-STRING` | `255 true` | DPANS94 §3.2.6 max char-string length; TIB_SIZE=128 but the COUNT byte is 8-bit → the implementation-limit is 255 |
   | `/HOLD` | `40 true` | `PIC_BUF_SIZE` from `src/constants.asm:36` |
   | `/PAD` | `84 true` | `PAD_OFFSET` from `src/constants.asm:27` |
   | `ADDRESS-UNIT-BITS` | `8 true` | Z80 byte-addressable |
   | `CORE` | `true true` | 100% Core (post-Story-10.9); **ONLY safe to return `true` once all 4 words land and the compliance doc shows 133/133** — if any Core word is still missing at commit time, return `false true` and flag as a blocker in Completion Notes |
   | `CORE-EXT` | `false true` | antforth implements some §6.2 Core-Extension words but not the whole set (11/46 post-10.8). DPANS94 §15.3.5.2 requires a full Core-Ext system to answer `true`; partial → answer `false true`. |
   | `FLOORED` | `false true` | antforth's single-cell `/` uses **symmetric** division (`sdivmod` in `arithmetic.asm:150-212`; remainder sign = dividend sign). `FLOORED` asks whether the system uses floored division as the *default* — no → `false`. |
   | `MAX-CHAR` | `255 true` | antforth 8-bit char |
   | `MAX-D` | `-1 32767 true` | (lo=-1=$FFFF, hi=32767=$7FFF) = +2147483647 — E10-D1 byte order: **lo on TOS, hi second**, then `true` on top |
   | `MAX-N` | `32767 true` | INT16_MAX |
   | `MAX-U` | `-1 true` | $FFFF = 65535 unsigned (antforth TOS is 16-bit signed; `-1` is the bit-pattern for max unsigned) |
   | `MAX-UD` | `-1 -1 true` | (lo=$FFFF, hi=$FFFF) = 4294967295 — E10-D1 byte order |
   | `RETURN-STACK-CELLS` | `128 true` | `RS_SIZE=256` bytes / 2 = 128 cells |
   | `STACK-CELLS` | `128 true` | `PS_SIZE=256` bytes / 2 = 128 cells |

   Any unknown query string (e.g. `S" FOO" ENVIRONMENT?`) returns `false` alone (one cell on TOS; no `i*x` value precedes it). The query-key match is **case-sensitive** per DPANS94 §3.2.6 (all standard keys are uppercase literals).

9. **Given** the §3.2.6 query-key match **When** implemented **Then** the table of 14 entries is a **static data block** (not individual DEFWORDs) — one contiguous `db len,key,kind,value...` structure in `src/system.asm` (or wherever ENVIRONMENT? lives) — scanned byte-by-byte. Rationale: 14 entries × ~30 bytes each ≈ 420 bytes of table data; implementing each as a DEFWORD would add ~14 × 12 bytes of dictionary overhead and pollute the user-visible word list. Table format (suggested, dev may refine):
   ```
   env_table:
     db keylen, "KEY-NAME", kind, value_bytes..., 0 (terminator)
     ...
     db 0    ; end marker (zero-length entry)
   ```
   `kind` byte values: `0` = single-cell value (next 2 bytes), `1` = double-cell value (next 4 bytes: lo, hi), `2` = flag value (next 2 bytes: 0 for false, $FFFF for true).

10. **Given** all four words **When** any is invoked with insufficient parameter stack **Then** `? Stack underflow` fires: `*/` / `*/MOD` require DEPTH ≥ 3; `EVALUATE` and `ENVIRONMENT?` require DEPTH ≥ 2. Standard pattern: `CALL check_underflow_N` (DEFCODE) or first body word guards (DEFWORD). No new `(?N)` helper needed; `check_underflow_2` / `check_underflow_3` exist per `system.asm:293-338`.

11. **Given** §-number write-time verification discipline (`feedback_systematic_reference_check.md`) **When** each citation is written into source **Then** it is verified against `docs/ans-forth-core-compliance.md` (authoritative after Story 10.1) and DPANS94 / forth-standard.org — NOT against memory and NOT against this story spec alone. Verified §-numbers: `*/` §6.1.0100 · `*/MOD` §6.1.0110 · `EVALUATE` §6.1.1360 · `ENVIRONMENT?` §6.1.1345. All four use the `ANS Forth 1994 §X.Y.ZZZZ` citation form (not Forth 2014 — these are all original DPANS94 Core).

12. **Given** the Makefile's contiguous `test-repl` numbering (post-Story-10.8 max = **614**; verified at `Makefile:~5023+` in the `Story 10.8 number-output on pictured foundation (579..614)` block) **When** Story 10.9 tests are appended **Then** new entries start at **615** and increment contiguously. Format: the canonical printf-HEREDOC → REPL → grep-for-expected-substring → PASS/FAIL pattern already established. `$$` escape and `printf --` discipline apply (per Story 10.7/10.8 retros).

13. **Given** `tests/core_gap_tests.fth` (created in Story 10.8) **When** Story 10.9 tests are appended **Then** new blocks go into the same file with a `\ === Story 10.9 remaining Core gap words ===` section header; the file stays the canonical home for "Core gap" REPL scripts. No new test file.

14. **Given** REPL test coverage (AC #13) **When** Story 10.9 completes **Then** Makefile `test-repl` has new entries at **615..~650** covering: (a) `*/` — canonical test `32767 32767 32767 */ → 32767`, signed-pair sanity `10 20 5 */ → 40`, negative inputs `-10 20 5 */ → -40`, symmetric-division boundary `7 3 2 */ → 10` (= `21/2 = 10` trunc-toward-zero not floor), division-by-zero `1 1 0 */` → silent SM/REM baseline (no error message; one garbage cell remains; pre-Epic-11 behaviour. **Spec correction (post-review):** the original AC text predicted `? Stack underflow` or ABORT; empirical SM/REM produces silent garbage. Story 11.6 migrates to `THROW -10`.); (b) `*/MOD` — matching test set plus remainder-visibility case `17 3 5 */MOD → 1 10` (rem=1, quot=10); (c) `EVALUATE` — simplest `S" 10 20 +" EVALUATE → 30`; multi-word `S" 2 3 * 4 +" EVALUATE → 10`; nested `S" 10 S\" 32 \" EVALUATE +" EVALUATE → 42`; empty-string `S" " EVALUATE` leaves stack unchanged; state preservation `S" BASE @" EVALUATE` returns current BASE then the TIB state is un-corrupted (verify by following with a parsing test); restore-even-on-ABORT is verified indirectly via the Story 11 epic (NOT tested here, per AC #5); (d) `ENVIRONMENT?` — one PASS test per standard query string (14 tests, each exercising value + `true` return), plus one unknown-key test `S" XYZZY" ENVIRONMENT? → false` (single-cell false, no `i*x`), plus one case-sensitivity test `S" core" ENVIRONMENT? → false` (lowercase key → not found).

15. **Given** adversarial self-review discipline (per `feedback_adversarial_review.md`) **When** Story 10.9 closes **Then** the Dev Agent Record includes a trap-table covering at minimum: `*/` double-intermediate overflow avoidance (the canonical `32767 × 32767 = 1073676289` trap); `*/MOD` symmetric-vs-floored remainder sign; `EVALUATE` source-restore on normal completion; `EVALUATE` save-state on rstack (byte count, order, and `w_ABORT_cf` rstack-reset interaction); `EVALUATE` nesting; `ENVIRONMENT?` all 14 standard keys return correct values; `ENVIRONMENT?` unknown-key returns `false` alone (not `false true`); E10-D1 byte-order for `MAX-D` / `MAX-UD` double-cell returns; case-sensitivity; ROM delta direction.

16. **Given** ROM size accounting (informational — CCD-4 gate is Story 10.10) **When** the build completes after Story 10.9 **Then** `build/antforth.com` delta vs. the post-Story-10.8 baseline (**16202 bytes** per `10-8-...md:485`) is recorded in the Dev Agent Record. **Direction estimate:** +350–550 bytes gross — `*/` (~20 bytes threaded body), `*/MOD` (~16), `EVALUATE` + save/restore helpers (~80–120 assembly bytes), `ENVIRONMENT?` DEFCODE (~40 bytes code) + 14-entry query table (~350 bytes data) + four new dictionary headers (~40 bytes). Acceptable because Epic-wide NFR5 direction is the gate, not Story 10.9 alone; Epics 12–13 are the planned ROM-shrinking stories.

17. **Given** `docs/ans-forth-core-compliance.md` **When** Story 10.9 completes **Then** the doc is refreshed:
    - **Summary table** (lines 9-19): `Fully implemented` 129 → 133; `Missing` 4 → 0; coverage 97.0% → **100.0%**.
    - **"Gap Analysis"** rows for `*/`, `*/MOD`, `EVALUATE`, `ENVIRONMENT?` flipped to `Implemented` with source-line refs.
    - **"(b) Oversight — moderate"** and **"(b) Oversight — missing subsystem"** gap-classification counts: moderate 2 → 0; missing-subsystem remaining 2 → 0; section (b) now empty; gap-classification table (lines 22-28) collapses accordingly (report "All Core gaps closed — 133/133").
    - **Epic-10 closure plan** (row for Story 10.9, line 47): mark complete with 4 §6.1 words listed.
    - **Arithmetic table** (lines 91-92): `*/` and `*/MOD` rows flipped to `Implemented` with `arithmetic.asm:<line>` references.
    - **System and Interpreter table** (lines 278-280): `EVALUATE` and `ENVIRONMENT?` rows flipped to `Implemented` with source-line refs.
    - **Date header** (line 3): refreshed to Story 10.9 date.
    - **Headline prose** around FR15/NFR10: now unambiguously satisfied — 100% §6.1 Core, zero deliberate omissions, zero partial rows.

18. **Given** the §6.1 coverage gate is now closed **When** the Dev Agent Record is written **Then** it explicitly calls out: "**Story 10.10 (Epic-10 close-out) can now verify FR15 / NFR10 pass with a single sentence: 133/133 §6.1 Core words implemented, zero deliberate omissions.** The §6.2 Core Extension partial (11/46) is orthogonal to FR15 and remains an open observation — not a gate." This matches the 10.1 Senior Developer Review resolution (SR-1 closed via party-mode 2026-04-20).

## Tasks / Subtasks

- [x] **Task 1: Standards verification** (AC #1, #11)
  - [x] 1.1 Cross-reference §-numbers against `docs/ans-forth-core-compliance.md` — record the exact §-numbers for each of the four words in a Dev-Notes table before writing any source: `*/` §6.1.0100 · `*/MOD` §6.1.0110 · `EVALUATE` §6.1.1360 · `ENVIRONMENT?` §6.1.1345.
  - [x] 1.2 Spot-check against forth-standard.org for `EVALUATE` semantics: confirm `source-id` = `-1` during EVALUATE (Forth 2014 §6.2.2218 `SOURCE-ID` convention), input source save/restore discipline (§3.4.1 "Input sources"), behaviour on exhausted input (§6.1.1360.60 "Empty string completes successfully").
  - [x] 1.3 Spot-check against forth-standard.org for `ENVIRONMENT?` — confirm the 14-key query table per §3.2.6, confirm `FLOORED` maps to antforth's current `/` semantics (symmetric per `sdivmod` at `arithmetic.asm:150-212`; `FLOORED` returns **false**), confirm `CORE-EXT` answer is false because antforth's §6.2 coverage is partial.

- [x] **Task 2: Implement `*/` and `*/MOD` in `src/arithmetic.asm`** (AC #2, #3, #10, #11)
  - [x] 2.1 Add DEFWORD `*/MOD` at end of `arithmetic.asm` (post `w_MOD`, around line 266+). Canonical body:
    ```
    ; */MOD ( n1 n2 n3 -- n4 n5 )
    ;   Mixed-precision multiply-divide-modulo via double intermediate.
    ;   n4 = (n1*n2) mod n3 (remainder, sign matches dividend per SM/REM)
    ;   n5 = (n1*n2) / n3   (quotient, truncated toward zero)
    ; ANS Forth 1994 §6.1.0110   */MOD   — mixed-precision multiply-divide-modulo
    w_STAR_SLASH_MOD:
            DEFWORD "*/MOD", 0
    w_STAR_SLASH_MOD_body:
    w_STAR_SLASH_MOD_cf EQU w_STAR_SLASH_MOD_body - 3
            DW      w_TO_R_cf               ; >R ( n1 n2 ; R:n3 )
            DW      w_M_STAR_cf             ; M* ( d ; R:n3 ) — signed mixed multiply
            DW      w_R_FROM_cf             ; R> ( d n3 )
            DW      w_S_M_SLASH_REM_cf      ; SM/REM ( rem quot )
            DW      EXIT_CODE
    ```
    The first body word is `>R` which does not underflow-guard itself; the second word is `M*` (DEFWORD) whose first body word is `2DUP` — that guards DEPTH ≥ 2 after `>R` has popped one cell, so the full entry effectively guards the required DEPTH ≥ 3 (2 remaining after >R, plus n3 safely stashed). If the DEPTH-2-at-M*-entry guard trips, ABORT resets both stacks (including the `>R`-stashed n3), so no rstack leak.
  - [x] 2.2 Add DEFWORD `*/` immediately below `*/MOD`:
    ```
    ; */ ( n1 n2 n3 -- n4 )
    ;   Mixed-precision multiply-divide via double intermediate.
    ;   n4 = (n1*n2) / n3 (truncated toward zero, symmetric per SM/REM)
    ; ANS Forth 1994 §6.1.0100   */   — mixed-precision multiply-divide
    w_STAR_SLASH:
            DEFWORD "*/", 0
    w_STAR_SLASH_body:
    w_STAR_SLASH_cf EQU w_STAR_SLASH_body - 3
            DW      w_STAR_SLASH_MOD_cf     ; */MOD ( n4 n5 )
            DW      w_SWAP_cf               ; swap rem and quot
            DW      w_DROP_cf               ; drop remainder
            DW      EXIT_CODE
    ```
    Or equivalently `>R M* R> SM/REM SWAP DROP` — the factored body via `*/MOD` saves one level of threading and keeps the two bodies tied (a change to `*/MOD` propagates automatically).
  - [x] 2.3 Verify label resolution: `w_TO_R_cf` / `w_R_FROM_cf` at `stack_ops.asm:249/263`; `w_M_STAR_cf` at `double.asm:468`; `w_S_M_SLASH_REM_cf` at `double.asm:638`; `w_SWAP_cf` / `w_DROP_cf` at `stack_ops.asm:48/37`. All already in place from Stories 10.2, 10.3, 10.5, 10.6.
  - [x] 2.4 Verify CCD-3 discipline: each DEFWORD's preceding comment block cites `ANS Forth 1994 §6.1.0110` / `§6.1.0100` respectively, on the pattern established by `double.asm` (e.g., line 428 `UM*` header).

- [x] **Task 3: Implement `EVALUATE` in `src/outer_interpreter.asm`** (AC #4, #5, #6, #7, #10, #11)
  - [x] 3.1 Add two internal DEFCODE helpers `(SAVE-INPUT)` and `(RESTORE-INPUT)` in `outer_interpreter.asm` (or at the head of a new section within the same file). `(paren)` naming per `architecture.md:425` "Internal helper words use a `(paren)` convention". These are the mechanism EVALUATE uses to stash and reload the four USER fields that define the input source.
  - [x] 3.2 `(SAVE-INPUT)` DEFCODE body:
    ```
    ; (SAVE-INPUT) ( c-addr u -- )
    ;   Save current (tib_addr, tib_len, tib_in, source_id) to R-stack;
    ;   set new source: tib_addr=c-addr, tib_len=u, tib_in=0, source_id=-1.
    ;   Four 2-byte cells → 8 R-stack bytes (rpush_de × 4 or inline 4×push).
    ;   Order on R-stack (bottom → top): source_id, tib_in, tib_len, tib_addr.
    ;   So (RESTORE-INPUT) pops in reverse: tib_addr first, then tib_len, tib_in, source_id.
    w_PAREN_SAVE_INPUT:
            DEFCODE "(SAVE-INPUT)", 0
    w_PAREN_SAVE_INPUT_cf:
            CALL    check_underflow_2       ; ( c-addr u ) — 2 cells required
            ; -- save state to R-stack in this order: source_id, tib_in, tib_len, tib_addr --
            ; (so tib_addr pops first in RESTORE)
            LD      L, (IY+UserArea.source_id)
            LD      H, (IY+UserArea.source_id+1)
            CALL    rpush_hl
            LD      L, (IY+UserArea.tib_in)
            LD      H, (IY+UserArea.tib_in+1)
            CALL    rpush_hl
            LD      L, (IY+UserArea.tib_len)
            LD      H, (IY+UserArea.tib_len+1)
            CALL    rpush_hl
            LD      L, (IY+UserArea.tib_addr)
            LD      H, (IY+UserArea.tib_addr+1)
            CALL    rpush_hl
            ; -- install new source --
            ; tib_addr = c-addr (popped from stack); tib_len = u (current TOS = BC)
            POP     HL                      ; HL = c-addr
            LD      (IY+UserArea.tib_addr), L
            LD      (IY+UserArea.tib_addr+1), H
            LD      (IY+UserArea.tib_len), C
            LD      (IY+UserArea.tib_len+1), B
            ; tib_in = 0
            XOR     A
            LD      (IY+UserArea.tib_in), A
            LD      (IY+UserArea.tib_in+1), A
            ; source_id = -1 (0xFFFF) per Forth 2014 §6.2.2218
            DEC     A                       ; A = $FF
            LD      (IY+UserArea.source_id), A
            LD      (IY+UserArea.source_id+1), A
            ; Pop new BC (TOS) from below u
            POP     BC
            NEXT
    ```
    Verify `rpush_hl` exists (per memory `project_tos_in_register.md` and `6-2-return-stack-push-pop-subroutines.md` — Epic 6 added these). If only `rpush_bc` / `rpush_de` exist, use `PUSH HL` + `EX (SP), ...` tricks or add a thin `rpush_hl` helper. Spot-check in `src/inner_interpreter.asm` or wherever the rstack push routines live.
  - [x] 3.3 `(RESTORE-INPUT)` DEFCODE body — inverse of `(SAVE-INPUT)`, no stack items consumed or produced:
    ```
    ; (RESTORE-INPUT) ( -- )
    ;   Pop saved (tib_addr, tib_len, tib_in, source_id) from R-stack
    ;   and write back to USER area. Order: tib_addr first (top of R-stack),
    ;   then tib_len, tib_in, source_id.
    w_PAREN_RESTORE_INPUT:
            DEFCODE "(RESTORE-INPUT)", 0
    w_PAREN_RESTORE_INPUT_cf:
            CALL    rpop_hl
            LD      (IY+UserArea.tib_addr), L
            LD      (IY+UserArea.tib_addr+1), H
            CALL    rpop_hl
            LD      (IY+UserArea.tib_len), L
            LD      (IY+UserArea.tib_len+1), H
            CALL    rpop_hl
            LD      (IY+UserArea.tib_in), L
            LD      (IY+UserArea.tib_in+1), H
            CALL    rpop_hl
            LD      (IY+UserArea.source_id), L
            LD      (IY+UserArea.source_id+1), H
            NEXT
    ```
    Same note re `rpop_hl` availability.
  - [x] 3.4 Add DEFWORD `EVALUATE`:
    ```
    ; EVALUATE ( i*x c-addr u -- j*x )
    ;   Save input source spec; interpret c-addr/u as input; restore.
    ;   source-id = -1 while evaluating (Forth 2014 §6.2.2218).
    ;   ABORT inside interpreted string resets both stacks; save-restore
    ;   is abandoned safely by the ABORT path (Epic 11 will migrate to
    ;   THROW-safe save/restore).
    ; ANS Forth 1994 §6.1.1360   EVALUATE   — interpret from string
    w_EVALUATE:
            DEFWORD "EVALUATE", 0
    w_EVALUATE_body:
    w_EVALUATE_cf EQU w_EVALUATE_body - 3
            DW      w_PAREN_SAVE_INPUT_cf
            DW      w_INTERPRET_cf
            DW      w_PAREN_RESTORE_INPUT_cf
            DW      EXIT_CODE
    ```
    The first body word `(SAVE-INPUT)` underflow-guards for DEPTH ≥ 2 via its own `check_underflow_2`.
  - [x] 3.5 Verify `w_INTERPRET_cf` is visible from outside its file — it is, per `outer_interpreter.asm:138` which declares the cf label. No new export required.

- [x] **Task 4: Implement `ENVIRONMENT?` + query-key table in `src/system.asm`** (AC #8, #9, #10, #11)
  - [x] 4.1 Add DEFCODE `ENVIRONMENT?` after `w_MARKER` (approximately line 80-somewhere, before `(ABORT")` — arrangement is a judgement call; placement should group ENVIRONMENT? with the other system / introspection words).
  - [x] 4.2 DEFCODE body outline:
    ```
    ; ENVIRONMENT? ( c-addr u -- false | i*x true )
    ;   Query implementation-defined limits per DPANS94 §3.2.6.
    ;   Table-driven case-sensitive compare against 14 standard keys.
    ; ANS Forth 1994 §6.1.1345   ENVIRONMENT?   — query environment
    w_ENVIRONMENT_QUERY:
            DEFCODE "ENVIRONMENT?", 0
    w_ENVIRONMENT_QUERY_cf:
            CALL    check_underflow_2
            ; BC = u (query length), [SP] = c-addr (query address)
            POP     HL              ; HL = c-addr
            ; Walk env_table: each entry is (len,key-chars,kind,value-bytes...)
            ; Terminator: len=0.
            LD      DE, env_table
    .env_loop:
            LD      A, (DE)         ; A = entry length
            OR      A
            JR      Z, .env_notfound
            CP      C               ; match query length?
            JR      NZ, .env_skip
            ; Lengths match — compare key bytes at DE+1..DE+1+len vs c-addr at HL
            ; ... (inline byte-compare loop) ...
            ; Match → dispatch on kind byte at DE+1+len
            ; ... (push value per kind, push -1 true, NEXT)
    .env_skip:
            ; Skip to next entry: DE += 1+len+1+value_size_for_kind
            ; ...
            JR      .env_loop
    .env_notfound:
            ; Clean up: consumed (c-addr,u), return only false.
            LD      BC, 0           ; BC = false
            NEXT
    ```
    Exact byte-level layout is dev's judgement call per CCD-3 / §Architecture-decisions.
  - [x] 4.3 Query table `env_table` as a static `db` block in `system.asm` (placed AFTER all DEFCODE/DEFWORD entries so it doesn't end up in the dictionary):
    ```
    env_table:
        ; /COUNTED-STRING → 255 (single)
        db  16, "/COUNTED-STRING", 0   ; kind 0 = single value
        dw  255
        ; /HOLD → 40 (single)
        db  5, "/HOLD", 0
        dw  PIC_BUF_SIZE
        ; /PAD → 84 (single)
        db  4, "/PAD", 0
        dw  PAD_OFFSET
        ; ADDRESS-UNIT-BITS → 8 (single)
        db  17, "ADDRESS-UNIT-BITS", 0
        dw  8
        ; CORE → true (flag)
        db  4, "CORE", 2               ; kind 2 = flag
        dw  $FFFF                      ; true
        ; CORE-EXT → false (flag)
        db  8, "CORE-EXT", 2
        dw  0                          ; false
        ; FLOORED → false (flag)
        db  7, "FLOORED", 2
        dw  0
        ; MAX-CHAR → 255 (single)
        db  8, "MAX-CHAR", 0
        dw  255
        ; MAX-D → +2147483647 = (lo=$FFFF, hi=$7FFF) (double)
        db  5, "MAX-D", 1              ; kind 1 = double
        dw  $FFFF                      ; lo
        dw  $7FFF                      ; hi
        ; MAX-N → 32767 (single)
        db  5, "MAX-N", 0
        dw  32767
        ; MAX-U → 65535 (single)
        db  5, "MAX-U", 0
        dw  $FFFF
        ; MAX-UD → 4294967295 = (lo=$FFFF, hi=$FFFF) (double)
        db  6, "MAX-UD", 1
        dw  $FFFF
        dw  $FFFF
        ; RETURN-STACK-CELLS → RS_SIZE/2 (single)
        db  18, "RETURN-STACK-CELLS", 0
        dw  RS_SIZE/2
        ; STACK-CELLS → PS_SIZE/2 (single)
        db  11, "STACK-CELLS", 0
        dw  PS_SIZE/2
        ; Terminator
        db  0
    ```
    **Important counting note:** lengths above MUST be manually verified byte-by-byte at write time. Off-by-one on any length silently breaks the key-match loop.
  - [x] 4.4 Cross-reference `PIC_BUF_SIZE`, `PAD_OFFSET`, `RS_SIZE`, `PS_SIZE` against `src/constants.asm` to confirm literal symbolic values are available. Confirmed by this audit: `PIC_BUF_SIZE=40` (line 36), `PAD_OFFSET=84` (line 27), `RS_SIZE=256` (line 18), `PS_SIZE=256` (line 17), so `RS_SIZE/2 = 128` and `PS_SIZE/2 = 128`.
  - [x] 4.5 **E10-D1 byte-order check for MAX-D / MAX-UD:** the double-cell return convention is `( hi lo true )` ordered on the stack with **lo on TOS**, hi second, true on top. Writing order from the table:
     - `MAX-D`: lo = $FFFF = -1, hi = $7FFF = 32767. The DEFCODE pushes `dw  $FFFF  dw  $7FFF` so the push order must match. In antforth E10-D1, if the table stores lo-first then hi, the pushes happen as "push lo, then push hi, then hi lands on TOS" — but E10-D1 puts **lo on TOS**. So the DEFCODE must push **hi first (becoming second-on-stack), then lo (becoming TOS), then push true (new TOS)**. The table can be stored in either order as long as the DEFCODE's push-order comment makes it explicit. Verification test: `S" MAX-D" ENVIRONMENT?` should, after dropping the `true` flag, equal `-1` on TOS and `32767` second (≡ the canonical S>D of +2147483647).
     - Same reasoning for `MAX-UD`: lo=$FFFF, hi=$FFFF; degenerate so byte-order is not observable, but the push-order comment matters for audit.
  - [x] 4.6 CCD-3 citation block at the DEFCODE header + at the `env_table` preamble (e.g., `; DPANS94 §3.2.6 standard query keys (14 entries)`).

- [x] **Task 5: Update `docs/ans-forth-core-compliance.md`** (AC #17)
  - [x] 5.1 Date header (line 3): `2026-04-23` → `<Story 10.9 completion date>`.
  - [x] 5.2 Summary table (lines 11-17): bump `Fully implemented` 129 → 133; `Missing` 4 → 0; `Coverage` `129 / 133 (97.0%)` → **`133 / 133 (100.0%)`**.
  - [x] 5.3 Gap Classification table (lines 23-28): moderate 2 → 0; missing-subsystem 2 → 0; section collapses to "All Core gaps closed — 133/133".
  - [x] 5.4 Headline prose ("Which figure feeds FR15 / NFR10?", line 21): replace the "pending project-lead concurrence" framing with a literal statement: "**Post-Story-10.9: 133/133 §6.1 Core words implemented, zero deliberate omissions. FR15 / NFR10 satisfied as written.**"
  - [x] 5.5 Epic-10 closure-plan table (line 47, Story 10.9 row): mark complete — `10.9 | Remaining §6.1 Core gap words | 4 ✓ (`*/` `*/MOD` `EVALUATE` `ENVIRONMENT?`) | Complete`. Update Total §6.1 closed cell to 22 ✓.
  - [x] 5.6 Arithmetic table (lines 91-92): `*/` row — `Gap → Story 10.9` → `Implemented | arithmetic.asm:<line>`. Same for `*/MOD`.
  - [x] 5.7 System table (lines 279-280): `EVALUATE` and `ENVIRONMENT?` rows flipped similarly, with `outer_interpreter.asm:<line>` and `system.asm:<line>` source references.
  - [x] 5.8 Gap Analysis section (lines 284-320): section (a) already empty (unchanged); section (b) — remove the "§6.1 words remaining → 10.9" language and replace with "All §6.1 Core gaps closed as of Story 10.9". Preserve the historical-note sub-paragraphs describing *how* the gaps closed; do not delete history.
  - [x] 5.9 Post-refresh cross-check: grep for any remaining `Gap →` or `Story 10.9` pointer in the doc; every such pointer should now be `Implemented` or accompanied by a completion-date note.

- [x] **Task 6: Append REPL tests to `tests/core_gap_tests.fth` + Makefile** (AC #12, #13, #14)
  - [x] 6.1 New section header in `tests/core_gap_tests.fth`: `\ === Story 10.9 remaining Core gap words ===`. Preserve all Story-10.8 content above.
  - [x] 6.2 Blocks in `.fth` (expected-value comments per Story-10.8 convention — one-liner inputs, expected output in `\ expect: ...`):
    ```
    \ --- */ block (AC #14a) ---
    10 20 5 */                         \ expect: 40
    -10 20 5 */                        \ expect: -40
    7 3 2 */                           \ expect: 10
    32767 32767 32767 */               \ expect: 32767  (double-intermediate overflow test)

    \ --- */MOD block (AC #14b) ---
    10 20 6 */MOD                      \ expect: 2 33 (rem 2, quot 33)
    17 3 5 */MOD                       \ expect: 1 10
    -17 3 5 */MOD                      \ expect: -1 -10 (symmetric-rem sign = dividend)

    \ --- EVALUATE block (AC #14c) ---
    S" 10 20 +" EVALUATE               \ expect: 30
    S" 2 3 * 4 +" EVALUATE             \ expect: 10
    S" " EVALUATE                      \ expect: (empty — no change to stack)
    \ Nested EVALUATE:
    S" 10 S\" 32 \" EVALUATE +" EVALUATE  \ expect: 42
    \ State-preservation smoke: after EVALUATE, BASE is still 10.
    HEX S" DECIMAL 10 ." EVALUATE      \ expect: 10  (inner EVALUATE set BASE=10, printed 10; base stays 10 after)
    \ But for the outer, HEX must be re-applied if wanted — the inner's BASE change survives EVALUATE per ANS (state, not input-src, survives).

    \ --- ENVIRONMENT? block (AC #14d) — all 14 keys + unknown + case-sensitivity ---
    S" /COUNTED-STRING" ENVIRONMENT?   \ expect: 255 -1
    S" /HOLD" ENVIRONMENT?             \ expect: 40 -1
    S" /PAD" ENVIRONMENT?              \ expect: 84 -1
    S" ADDRESS-UNIT-BITS" ENVIRONMENT? \ expect: 8 -1
    S" CORE" ENVIRONMENT?              \ expect: -1 -1 (true followed by true-flag)
    S" CORE-EXT" ENVIRONMENT?          \ expect: 0 -1
    S" FLOORED" ENVIRONMENT?           \ expect: 0 -1
    S" MAX-CHAR" ENVIRONMENT?          \ expect: 255 -1
    S" MAX-D" ENVIRONMENT?             \ expect: -1 32767 -1   (lo=-1=$FFFF, hi=32767=$7FFF, flag=-1)
    S" MAX-N" ENVIRONMENT?             \ expect: 32767 -1
    S" MAX-U" ENVIRONMENT?             \ expect: -1 -1   (-1 is 65535 unsigned; flag)
    S" MAX-UD" ENVIRONMENT?            \ expect: -1 -1 -1
    S" RETURN-STACK-CELLS" ENVIRONMENT? \ expect: 128 -1
    S" STACK-CELLS" ENVIRONMENT?       \ expect: 128 -1
    S" XYZZY" ENVIRONMENT?             \ expect: 0        (single cell, no i*x)
    S" core" ENVIRONMENT?              \ expect: 0        (case-sensitive: lowercase not found)
    ```
    Note: "expect: -1" in the .fth comments refers to the true-flag value as antforth prints it (bit pattern $FFFF which `.` displays as `-1` in BASE=10 signed); the stack value is standard ANS true = all-bits-set. Makefile entries should `grep -qE '^-1  ok'` or similar for single-value returns with true-flag.
  - [x] 6.3 Makefile `test-repl` entries 615..~650. Banner line above the block: `@# --- Story 10.9 remaining Core gap words (615..~650) — DPANS94 §6.1.{0100,0110,1345,1360} ---`. Follow canonical printf-HEREDOC + grep format per Story 10.8 examples at `Makefile:5023+`. For each test, use `.` or `.S` as the probe word to observe stack state. For multi-value returns (MAX-D, MAX-UD, ENVIRONMENT? true), probe with `D.` / `.S` / explicit-drop chains.
  - [x] 6.4 Apply `$$` escape discipline for hex literals in banners and `printf --` discipline for inputs beginning with `-` (Story 10.7/10.8 retro learning — e.g., `-10 20 5 */` needs `printf -- '-10 20 5 */ .\r\nBYE\r\n'`).

- [x] **Task 7: ROM size accounting** (AC #16, informational)
  - [x] 7.1 Measure `build/antforth.com` before edits. Expected: **16202 bytes** (matches post-Story-10.8 baseline per `10-8-...md:485`). Record verbatim in Dev Agent Record.
  - [x] 7.2 Measure after all edits. Record.
  - [x] 7.3 Record the delta with a breakdown: `*/` / `*/MOD` threaded bodies + headers (~60 bytes), `(SAVE-INPUT)` / `(RESTORE-INPUT)` / `EVALUATE` (~120–160 bytes), `ENVIRONMENT?` DEFCODE + table (~400–500 bytes). Expected total: +350–550 bytes. Acceptable — CCD-4 gate is epic-wide and Story 10.10's concern.

- [x] **Task 8: Adversarial self-review** (AC #15, per `feedback_adversarial_review.md`)
  - [x] 8.1 Trap-table in Completion Notes covering every attack surface listed in AC #15. Reviews must find things — a zero-finding adversarial review on a 4-word story adding ~450 bytes of new code with a hand-built data table is *ipso facto* suspect.
  - [x] 8.2 Attack surfaces to probe explicitly:
     - **`*/` double-intermediate overflow:** `32767 32767 32767 */` must return `32767`, not wrap. If the implementation accidentally uses single-cell `*` instead of `M*`, the single-cell `*` truncates to `1` (32767×32767 mod 2^16 = 1), then `1/32767 = 0` — a catastrophic silent-wrong result. Regression test in `.fth` + Makefile.
     - **`*/MOD` symmetric-remainder sign:** `-17 3 5 */MOD` must return `( -1 -10 )`. Symmetric-division remainder sign matches dividend, not divisor. If the implementation accidentally routes through `FM/MOD` (floored), the result would be `( 2 -11 )` — also wrong.
     - **`EVALUATE` source-restore on normal completion:** after `S" 10 20 +" EVALUATE`, `SOURCE` must return the original REPL TIB, not the string. Probe: after EVALUATE, run another word that calls `WORD` or `PARSE` — it must parse from TIB, not from the EVALUATE string. Verify by calling a second TIB-parsing word on the same REPL line after EVALUATE completes.
     - **`EVALUATE` save-order vs restore-order:** off-by-one in `rpush`/`rpop` pairing silently corrupts the USER area. Guard test: inject a sentinel `>IN` value before EVALUATE, run EVALUATE on a string that moves `>IN`, verify `>IN` is back to the sentinel after EVALUATE returns. Same for `tib_addr`, `tib_len`, `source_id`.
     - **`EVALUATE` nesting:** `S" 10 S\" 32 \" EVALUATE +" EVALUATE` → `42`. Exercises save-restore on the R-stack under LIFO discipline.
     - **`EVALUATE` + ABORT:** interpreted string containing unknown-word forces ABORT; ABORT's SP/IX resets wipe the R-stack-saved source-spec; REPL recovers cleanly; subsequent REPL parsing works (saved state is *not* applied to live USER area — because ABORT wipes the state before RESTORE can run). This is the pre-Epic-11 baseline; Story 11.6 migrates to THROW-safe. Don't block Story 10.9 on this — just confirm the failure mode matches the baseline and document it (AC #5).
     - **`ENVIRONMENT?` all 14 keys:** 14 separate `.fth` + Makefile cases. Any off-by-one in the table's length bytes silently breaks the compare loop for one or more keys — this is the most likely defect.
     - **`ENVIRONMENT?` unknown-key returns `false` alone (1 cell, not 2):** DPANS94 distinguishes `false` (unknown) from `value true` (known). `.S` probe on unknown should show `<1> 0`, not `<2> 0 0`.
     - **`ENVIRONMENT?` case-sensitivity:** lowercase `core` must return `false`. Standard §3.2.6 keys are all uppercase literals.
     - **E10-D1 MAX-D / MAX-UD byte-order:** lo on TOS. After `S" MAX-D" ENVIRONMENT?` + DROP-true, TOS must be `-1` ($FFFF = low cell), second must be `32767` ($7FFF = high cell). If accidentally swapped (hi on TOS), subsequent `D.` would print `32767...` instead of the correct signed `2147483647 `.
     - **Standards-citation accuracy:** all four source-citation comments cite `§6.1.x` with the correct Forth 1994 number. `§6.1.0100` is `*/` (not `/*`); `§6.1.0110` is `*/MOD`; `§6.1.1345` is `ENVIRONMENT?`; `§6.1.1360` is `EVALUATE`. A transposition is a typical copy-paste defect (Story 10.8's `§6.1.0310` for `.R` was the reverse case).

- [x] **Task 9: Finalise Dev Agent Record** (AC #15, #18)
  - [x] 9.1 Agent Model Used / Debug Log References / Completion Notes / File List filled out per 10.8 precedent.
  - [x] 9.2 Trap-table recorded (AC #15).
  - [x] 9.3 Post-story `make test-repl` count recorded — 623 (post-10.8) + 36 new (615..650) + 2 review-follow-ups (651..652) = **661 passing, 0 failing** (initial pass was 659 / 0; review added the div-by-zero baseline tests).
  - [x] 9.4 Post-story `make test` (assembly regression thread) must still PASS — no assembly-level regression.
  - [x] 9.5 Status managed by `dev-story` workflow (`ready-for-dev → in-progress → review`).
  - [x] 9.6 Include the AC #18 closure statement in Completion Notes.

## Dev Notes

### Story Purpose and Epic-10 Position

Story 10.9 is the **eighth implementation story in Epic 10** and the **final code-writing story before Story 10.10's CCD-4 benchmark gate**. It closes the last four §6.1 Core gaps, taking antforth from 129/133 (97.0%) to **133/133 (100.0%)** Core compliance with **zero deliberate omissions**.

The four words fall into three design clusters:

1. **`*/` and `*/MOD`** — thin DEFWORD wrappers over `M*` (Story 10.5) and `SM/REM` (Story 10.6). Simple, well-understood, low-risk. Total ~60 bytes of threaded cells.

2. **`EVALUATE`** — non-trivial: requires saving and restoring **four** USER-area fields (`tib_addr`, `tib_len`, `tib_in`, `source_id`) across a call into the existing `INTERPRET` thread. Implemented as a DEFWORD with two internal DEFCODE helpers `(SAVE-INPUT)` and `(RESTORE-INPUT)`. Interacts with the existing ABORT-resets-rstack discipline (which is pre-Epic-11; Epic 11 will migrate to THROW-safe save/restore).

3. **`ENVIRONMENT?`** — reclassified from "deliberately omitted" to "Story 10.9 deliverable" on 2026-04-20 (party-mode decision, documented in `docs/ans-forth-core-compliance.md:21,286-290` and `epics.md:637`). Table-driven, case-sensitive compare against 14 DPANS94 §3.2.6 standard query keys. Straightforward when done correctly; each table length-byte is a potential off-by-one defect.

### Architectural Decisions That Apply to This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§206-216 CCD-3 (Standards-Citation Discipline):** every new source site cites its DPANS94 §-number. Non-negotiable — see AC #1, #11. Cross-reference against `docs/ans-forth-core-compliance.md` at write-time.
- **§218-226 CCD-4 (Per-Epic Benchmark Gate):** gate is at **Story 10.10**, not here. Record ROM delta informationally (AC #16).
- **§246-252 E10-D1 (Byte-Order):** low cell on TOS, high cell second. For `ENVIRONMENT?` `MAX-D` / `MAX-UD` returns — **lo on TOS**, then hi, then the `true` flag on top. Non-negotiable (AC #8, #15).
- **§260-264 E10-D3 (Implementation split):** hot arithmetic primitives go to assembly; thin wrappers compile as Forth. `*/` and `*/MOD` are thin wrappers → DEFWORD in `arithmetic.asm`. `EVALUATE` needs assembly save/restore helpers but the orchestration is a DEFWORD. `ENVIRONMENT?` is DEFCODE because the key-match loop is simpler in assembly than threaded code.
- **§425 naming — internal helper words:** `(SAVE-INPUT)` / `(RESTORE-INPUT)` use the `(paren)` convention.
- **§434-447 Source-file organisation:** `*/` `*/MOD` in `src/arithmetic.asm`; `EVALUATE` + helpers in `src/outer_interpreter.asm`; `ENVIRONMENT?` + query table in `src/system.asm`. Matches the compliance doc's category assignments: Arithmetic, System-and-Interpreter, System-and-Interpreter respectively.

### `*/` and `*/MOD` — Double-Intermediate Design

The core semantic trick: `n1 × n2` can overflow a single 16-bit cell, but the standard demands the overflow be held in a **double-cell intermediate** before the division. Reference body from DPANS94 §A.6.1.0110:

```
: */MOD  ( n1 n2 n3 -- rem quot )
  >R M* R> SM/REM ;

: */     ( n1 n2 n3 -- quot )
  */MOD SWAP DROP ;
```

`M*` is `( n1 n2 -- d )` signed mixed multiply (32-bit product, Story 10.5 §6.1.1810). `SM/REM` is `( d n1 -- nrem nquot )` symmetric signed mixed divide (Story 10.6 §6.1.2214). Both already in antforth — so `*/` and `*/MOD` are literally "thread these together".

The trap to avoid: the naive `: */  * / ;` body would use single-cell `*`, which truncates `n1 × n2` to 16 bits and silently produces wrong answers for most inputs. Even though modern compilers' peephole optimisers would never mis-generate this, a *hand*-typed threaded body is a real risk. The Story-10.1 compliance doc correctly notes these "use a double-cell intermediate" and pointed them to 10.9 for that reason.

**Verification fixture (must pass):** `32767 32767 32767 */` must return `32767`. Naive wrong answer: `0` (because `32767 × 32767 mod 2^16 = 1`, then `1 / 32767 = 0`).

### `EVALUATE` — Source-Spec Save/Restore

DPANS94 §6.1.1360 `EVALUATE`:
> `( i*x c-addr u -- j*x )` — Save the current input source specification. Store `-1` in `SOURCE-ID`. Make the string described by `c-addr` and `u` both the input source and input buffer, set `>IN` to zero, and interpret. When the parse area is empty, restore the prior input source specification.

The "input source specification" in antforth consists of four USER fields:

| Field | Offset (from UserArea) | Role |
|---|---|---|
| `tib_addr` | `UserArea.tib_addr` | SOURCE buffer start (c-addr) |
| `tib_len` | `UserArea.tib_len` | SOURCE buffer length (u) |
| `tib_in` | `UserArea.tib_in` | `>IN` parse offset |
| `source_id` | `UserArea.source_id` | SOURCE-ID (`0`=console, `-1`=EVALUATE, `>0`=INCLUDE FID — Epic 13) |

All four are 2-byte cells (see `src/structures.asm:18-29`). The save/restore must be atomic per EVALUATE call, but the design uses the existing return stack rather than dedicated save-slots — each EVALUATE call pushes 8 bytes onto the R-stack (4 cells × 2 bytes), interpreters runs, then pops 8 bytes back. This composes naturally under nesting.

**Where does EVALUATE live architecturally?** `src/outer_interpreter.asm` is the home because:
- `w_INTERPRET_cf` is defined there; EVALUATE calls it directly.
- The four USER fields are already read/written extensively in the same file (QUERY, SOURCE, `>IN`).
- Future Epic-13 `INCLUDED` will use the same save/restore pattern; keeping the helpers here means `INCLUDED` can reuse `(SAVE-INPUT)` / `(RESTORE-INPUT)` unmodified.

**Interaction with ABORT:** if INTERPRET raises ABORT inside EVALUATE (unknown word, number-parse failure, compile-state error), `w_ABORT_cf` does `LD SP, (sp_base)` + `JP w_QUIT_cf`. `w_QUIT_cf` resets IX (`LD IX, (rp_base)`) — this wholesale rstack reset silently discards the saved source-spec bytes. The USER fields retain the *EVALUATE-string* values (not the original TIB values), but `w_QUIT_cf` then does `CALL w_QUERY_cf` which **overwrites tib_addr/tib_len/tib_in with fresh BDOS input** — so by the time the REPL prompt re-appears, the USER state is clean even though the RESTORE never ran. This is the pre-Epic-11 baseline; Story 11.6 migrates ABORT to THROW and layers a CATCH-frame around EVALUATE that runs RESTORE on unwind.

Story 10.9 does NOT preempt Epic 11. The ABORT behaviour described here is what's expected and tested.

### `EVALUATE` Implementation Note — `rpush_hl` Availability Check

`src/stack_ops.asm:249+` defines `w_TO_R_cf` (the Forth `>R`), which pushes BC (TOS) onto IX-based rstack via some helper. `src/system.asm` and `src/control_flow.asm` use `rpush_de` / `rpop_de`. Per Epic-6 Story 6-2 (`return-stack-push-pop-subroutines.md`), the Epic-6 work consolidated the rstack helpers.

**Before writing `(SAVE-INPUT)`, dev must grep for `rpush_hl` / `rpop_hl` in `src/` — if only `rpush_de` / `rpush_bc` variants exist, either:**
- (a) Add `rpush_hl` as a new helper (3-line routine: `EX DE, HL` + `CALL rpush_de` + `EX DE, HL`, or inline equivalent). Follows the Story 6-2 helper precedent.
- (b) Use `EX DE, HL` before/after existing `rpush_de` calls at each site (uglier but zero ROM cost).

Either is fine; (a) is the cleaner architectural choice given that future Epic-13 INCLUDE helpers will want `rpush_hl` too. The dev's judgement call — record the decision in the Completion Notes.

### `ENVIRONMENT?` Table Layout

14 standard keys per DPANS94 §3.2.6. The table is case-sensitive: all keys are stored as literal uppercase ASCII in the static `db` block. The key-match loop is byte-by-byte (`CP` + `JR NZ`), so no `toupper` normalisation — the caller must match case exactly, which matches the DPANS94 specification.

**Byte-level counting for length prefixes** is the highest-risk part of this story. The audit convention:
- `/COUNTED-STRING` = **15 chars** (the leading `/` IS the first character, not extra). Count exactly: `/`, `C`, `O`, `U`, `N`, `T`, `E`, `D`, `-`, `S`, `T`, `R`, `I`, `N`, `G` = 15. ✓ (Spec correction post-review: original draft asserted 16 via a double-count of `/`; implementation uses 15.)
- `/HOLD` = 5 chars. ✓
- `/PAD` = 4 chars. ✓
- `ADDRESS-UNIT-BITS` = 17 chars (A,D,D,R,E,S,S,-,U,N,I,T,-,B,I,T,S). ✓
- `CORE` = 4 chars. ✓
- `CORE-EXT` = 8 chars. ✓
- `FLOORED` = 7 chars. ✓
- `MAX-CHAR` = 8 chars. ✓
- `MAX-D` = 5 chars. ✓
- `MAX-N` = 5 chars. ✓
- `MAX-U` = 5 chars. ✓
- `MAX-UD` = 6 chars. ✓
- `RETURN-STACK-CELLS` = 18 chars (R,E,T,U,R,N,-,S,T,A,C,K,-,C,E,L,L,S). ✓
- `STACK-CELLS` = 11 chars (S,T,A,C,K,-,C,E,L,L,S). ✓

Verify every length by hand OR use `pasmo`'s string-length tricks (`db <name>, 0 - $` patterns) — the latter is safer.

Kind byte values (dev may refine):
- `0` = single-cell value (next 2 bytes = `dw value`)
- `1` = double-cell value (next 4 bytes = `dw lo`, `dw hi`)
- `2` = flag value (next 2 bytes = `dw 0` for false, `dw $FFFF` for true)

Push order for each kind (match E10-D1 + ANS `true`/`false` convention):

| kind | stack result (after pushing TOS last) |
|---|---|
| 0 single | `( value true )` — push value under; push true as TOS |
| 1 double | `( lo hi true )` — push hi first (becomes second); push lo second (becomes TOS); push true as new TOS — **but wait:** DPANS94 returns `( d true )` for double-cell query; `d` is a two-cell pair with lo under hi on a low-on-TOS system. So push `hi` first (below), then `lo` on top of hi, then `true` on top of lo. Actually the DEFCODE has BC=TOS so the sequence is: write value bytes to table-local scratch, then PUSH hi cell onto SP (now second-on-stack), then LD BC=lo (low cell now TOS), then PUSH BC (now lo is second-on-stack), then LD BC=-1 (true as new TOS). Careful hand-rolling required. |
| 2 flag | `( flag true )` — push flag under, push true as TOS. **Both** cells are 2-byte; if flag is true the result looks like `( -1 -1 )` = two cells both showing `-1`; if flag is false the result is `( 0 -1 )`. |

### Interaction with the `(?3)` Guard (Story 10.6 Precedent)

Story 10.6 added `(?3)` — an internal DEFCODE that calls `check_underflow_3` — because its DEFWORD bodies for `SM/REM` and `FM/MOD` needed a 3-cell guard but their first body word only guarded for 1 or 2. For Story 10.9:

- `*/MOD`: first body word is `>R` (no guard), second is `M*` (DEFWORD whose first body is `2DUP`, 2-cell guard). After `>R`, DEPTH-2 required = `2DUP`'s own guard. DEPTH-3-required-at-entry translates to DEPTH-2-after-`>R`, which `2DUP`'s guard provides. **No (?3) needed for `*/MOD`** — the chain guards correctly.
- `*/`: bodies into `*/MOD` which guards as above. No additional guard needed.
- `EVALUATE`: first body word is `(SAVE-INPUT)` which has `CALL check_underflow_2` inline. No (?N) needed.
- `ENVIRONMENT?`: DEFCODE with `CALL check_underflow_2` at the top.

So no new (?N) helper required. Document this reasoning in the Dev Notes trap-table so a reviewer can verify.

### Cross-references to Prior-Story Patterns

1. **Story 10.5 `M*`** (`double.asm:468`) — DEFWORD precedent for thin-wrapper arithmetic; citation format matches CCD-3.
2. **Story 10.6 `SM/REM`** (`double.asm:638`) — DEFWORD with `(?3)` guard; factor-chain reasoning template; 3-cell underflow discipline.
3. **Story 10.8 DEFWORD bodies** (`formatting.asm:132-247` — `.`, `U.`, `.R` / `D.` / `U.R` / `D.R`) — closest layout precedent for the `*/` / `*/MOD` bodies.
4. **Story 10.7 `(SIGN)`** (`pictured.asm`) — `(paren)` internal-helper naming precedent; DEFCODE + direct `CALL hold_common` pattern.
5. **System ABORT / MARKER** (`system.asm:22-80,258-264`) — DEFCODE + direct USER-area manipulation precedent for `ENVIRONMENT?`.
6. **`w_QUERY` save/restore via `rpush_de` / `rpop_de`** (`outer_interpreter.asm:99,127`) — precedent for the pattern EVALUATE uses with its `(SAVE-INPUT)` / `(RESTORE-INPUT)` helpers.
7. **`w_TICK` / `w_BRACKET_TICK` source layout** (`compiler.asm:25-72`) — DEFWORD layout template with `EQU body - 3` idiom (`feedback_defword_cf_label.md`).

### Project Structure Notes

- **Files modified:**
  - `src/arithmetic.asm` (EDIT — append `*/MOD` and `*/` DEFWORDs at end).
  - `src/outer_interpreter.asm` (EDIT — add `(SAVE-INPUT)`, `(RESTORE-INPUT)`, `EVALUATE`).
  - `src/system.asm` (EDIT — add `ENVIRONMENT?` DEFCODE and `env_table` data).
  - `src/stack_ops.asm` OR a new minimal rstack-helper file (POSSIBLE EDIT — if `rpush_hl` / `rpop_hl` don't exist yet; dev decides based on audit at Task 3.2).
  - `tests/core_gap_tests.fth` (EDIT — append Story 10.9 section).
  - `Makefile` (EDIT — append `test-repl` entries 615..~650).
  - `docs/ans-forth-core-compliance.md` (EDIT — Summary flip to 100.0%; per-category tables flipped; closure-plan row marked complete; headline prose updated per AC #17, #18).
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` (EDIT — status transitions handled by dev-story workflow).
  - `_bmad-output/implementation-artifacts/10-9-remaining-core-gap-words.md` (THIS FILE — Dev Agent Record + Completion Notes + File List + status at close).
- **No files created** unless `rpush_hl` is new-file'd (optional).
- **No files deleted.**
- **Alignment with unified structure:** edits sit in established homes per `architecture.md:438-447`. Arithmetic words in `src/arithmetic.asm`; outer-interpreter-facing words in `src/outer_interpreter.asm`; system words in `src/system.asm`. No source-tree structural change.
- **Detected conflicts or variances:** none. This story closes the §6.1 Core gap cleanly within the existing file organisation.

### References

- **Authoritative standard:**
  - DPANS94 §6.1.0100 `*/` — mixed-precision multiply-divide
  - DPANS94 §6.1.0110 `*/MOD` — mixed-precision multiply-divide-modulo
  - DPANS94 §6.1.1345 `ENVIRONMENT?` — query environment
  - DPANS94 §6.1.1360 `EVALUATE` — interpret from string
  - DPANS94 §3.2.6 — ENVIRONMENT? standard query strings (14 keys)
  - DPANS94 §6.1.2218 / Forth 2014 `SOURCE-ID` — source-id = `-1` during EVALUATE
  - DPANS94 §3.4.1 — Input sources (save/restore semantics)
  - DPANS94 §6.1.2214 `SM/REM` — symmetric signed mixed divide (consumed by `*/` and `*/MOD`)
  - DPANS94 §6.1.1810 `M*` — signed mixed multiply (consumed by `*/` and `*/MOD`)
  - **Verify all §-numbers at implementation time** against `docs/ans-forth-core-compliance.md` and forth-standard.org before committing comments (NFR17/CCD-3, `feedback_systematic_reference_check.md`).
- **Planning artefacts:**
  - `_bmad-output/planning-artifacts/epics.md:626-659` — Story 10.9 epic spec (authoritative 4-word scope after 2026-04-20 party-mode decision)
  - `_bmad-output/planning-artifacts/epics.md:426-448` — Epic 10 overview
  - `_bmad-output/planning-artifacts/architecture.md:246-264` — E10-D1 / E10-D2 / E10-D3 decisions
  - `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 Standards-Citation Discipline
  - `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 Per-Epic Benchmark Gate (Story 10.10, not here)
  - `_bmad-output/planning-artifacts/architecture.md:425` — `(paren)` internal-helper convention
  - `_bmad-output/planning-artifacts/architecture.md:434-447` — Source-file organisation table
  - `_bmad-output/planning-artifacts/prd.md` — FR15 (100% Core target), NFR10 (compliance measurement), NFR17 (standards citations)
- **Precedent stories:**
  - `_bmad-output/implementation-artifacts/10-8-number-output-words-on-pictured-foundation.md` — closest-by-date precedent; DEFWORD + REPL-test-additions pattern; trap-table format; §-number verification discipline
  - `_bmad-output/implementation-artifacts/10-6-double-mixed-precision-division.md` — `SM/REM` / `FM/MOD` implementation (consumed by `*/`); `(?N)` guard precedent
  - `_bmad-output/implementation-artifacts/10-5-double-multiplication.md` — `M*` implementation (consumed by `*/`)
  - `_bmad-output/implementation-artifacts/10-1-ans-core-compliance-gap-survey-and-implementation-plan.md` — authoritative gap list + party-mode decision context for ENVIRONMENT?
  - `_bmad-output/implementation-artifacts/6-2-return-stack-push-pop-subroutines.md` — rstack helper conventions (`rpush_de` / `rpop_de` / possibly `rpush_hl`)
- **Source-tree anchors:**
  - `src/arithmetic.asm:86-266` — existing arithmetic DEFCODE bodies; new DEFWORDs append after `w_MOD` (line 266+)
  - `src/outer_interpreter.asm:135-229` — `w_INTERPRET` DEFWORD body (consumed by EVALUATE); new save/restore helpers + EVALUATE append after
  - `src/outer_interpreter.asm:66-76` — `w_SOURCE_cf` — shows how `tib_addr` + `tib_len` are read from USER area
  - `src/outer_interpreter.asm:95-128` — `w_QUERY_cf` — shows `rpush_de` / `rpop_de` precedent
  - `src/system.asm:22-80` — `w_MARKER_cf` — DEFCODE + static-data precedent for `ENVIRONMENT?`
  - `src/structures.asm:18-29` — `UserArea` struct definition (fields used by EVALUATE)
  - `src/constants.asm:17-36` — `PS_SIZE`, `RS_SIZE`, `PIC_BUF_SIZE`, `TIB_SIZE`, `PAD_OFFSET` (all consumed by `env_table`)
  - `src/double.asm:430-672` — `M*`, `SM/REM` implementations (consumed by `*/`, `*/MOD`)
  - `src/stack_ops.asm:37-249` — `DROP`, `SWAP`, `>R`, `R>` (consumed by `*/MOD` body)
  - `src/macros.asm` — `DEFCODE` / `DEFWORD` macros
- **Test-tree anchors:**
  - `tests/core_gap_tests.fth:1-87` — Story 10.8 content; Story 10.9 appends
  - `Makefile:5023-5200` — Story 10.8 `test-repl` block (579..614); Story 10.9 appends at 615
- **Compliance doc targets (all edits in `docs/ans-forth-core-compliance.md`):**
  - line 3 — date header
  - lines 9-19 — Summary table
  - lines 21-28 — Gap Classification
  - line 47 — Epic-10 closure-plan row for 10.9
  - lines 91-92 — Arithmetic table `*/`, `*/MOD` rows
  - lines 279-280 — System table `EVALUATE`, `ENVIRONMENT?` rows
  - lines 284-320 — Gap Analysis section (b) (remove §6.1-remaining prose; preserve history)
- **Project memories applicable:**
  - `feedback_systematic_reference_check.md` — cross-reference DPANS94/compliance doc for every §-number (AC #11)
  - `feedback_standards_compliance.md` — investigate the standard; never rationalise
  - `feedback_adversarial_review.md` — reviews MUST find things (Task 8; trap-table format from 10.8 precedent)
  - `feedback_plain_qa_language.md` — diagnostic Completion Notes; no "spirit gates"
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth scripts (AC #13, Task 6)
  - `feedback_follow_process.md` — execute workflow without asking permission for obvious next steps
  - `feedback_defword_cf_label.md` — `w_XXX_cf EQU w_XXX_body - 3` for DEFWORDs (non-negotiable); `*/`, `*/MOD`, `EVALUATE` all use this
  - `project_tos_in_register.md` — BC-as-TOS / DE-as-IP discipline; DEPTH convention
  - `feedback_design_upfront.md` — scaffold-upfront design; Story 10.1's gap inventory is why this story's scope is cleanly bounded at 4 words

### Project Structure Notes

- Alignment with unified project structure: story file lives in `_bmad-output/implementation-artifacts/` per `config.yaml:implementation_artifacts`. Edit targets all sit in sanctioned homes per `architecture.md:434-447`. REPL tests go in the existing `tests/core_gap_tests.fth` (started in Story 10.8); Makefile `test-repl` numbering continues contiguously from 614.
- No detected conflicts or variances with the unified structure. The party-mode-added `ENVIRONMENT?` fits naturally alongside `MARKER` and other system-introspection words in `src/system.asm`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M-context profile) via Claude Code dev-story workflow.

### Debug Log References

- `make asm` — clean assemble after each source edit; no errors / warnings.
- `make test` — assembly-thread regression (`tests/test_*.asm`): PASS, output matches expected.
- `make test-repl` — REPL-piped test harness: 659 PASS, 0 FAIL (623 pre-existing + 36 new at IDs 615..650).
- Smoke probes via direct `iz-cpm` to confirm semantics before adding Makefile entries:
  - `32767 32767 32767 */ .` → `32767` (double-intermediate overflow trap held).
  - `S" 10 20 +" EVALUATE .` → `30`; `S" 99" EVALUATE 7 + .` → `106` (TIB restored).
  - `S" /COUNTED-STRING" ENVIRONMENT?` → `( 255 -1 )`; `S" XYZZY" ENVIRONMENT?` → single-cell `0`.
  - `S" core" ENVIRONMENT?` → single-cell `0` (case-sensitive).
  - Nested EVALUATE via `: __E910I S" 32" EVALUATE ; S" 10 __E910I +" EVALUATE` → `42`.

### Completion Notes List

**Implementation summary.** Closed the four §6.1 Core gaps in one pass:

- `*/MOD` and `*/` (`src/arithmetic.asm:266..305`) — DEFWORDs threaded `>R M* R> SM/REM` and (factored via `*/MOD`) `*/MOD SWAP DROP`. Underflow guards chain via `M*`'s `2DUP` (DEPTH≥2 after `>R` ⇒ effective DEPTH≥3 at entry); no new `(?N)` helper needed.
- `EVALUATE` (`src/outer_interpreter.asm:366`) — DEFWORD threaded `(SAVE-INPUT) INTERPRET (RESTORE-INPUT)`. The two `(paren)` helpers (`outer_interpreter.asm:288,344`) save and restore the four-cell input source spec (`tib_addr`, `tib_len`, `tib_in`, `source_id`) on the R-stack via four `rpush_hl` / `rpop_hl` calls; LIFO discipline guarantees correct nesting under arbitrary depth.
- `ENVIRONMENT?` (`src/system.asm:277`) — DEFCODE walking a 14-entry static `env_table` (`system.asm:386`) of DPANS94 §3.2.6 standard query keys, with three value kinds (single, double, flag). Case-sensitive byte-wise compare. Unknown key returns single-cell false (no `i*x`).

**Architectural decisions made during the story:**

- *Added `rpush_hl` / `rpop_hl` to `inner_interpreter.asm`* (9 bytes each, +18 bytes total). Cleanest path: `(SAVE-INPUT)` and `(RESTORE-INPUT)` use `HL` and must preserve `DE` (the IP); using `rpush_de` would have clobbered the IP. Future Epic-13 `INCLUDED` will reuse these helpers.
- *Story dev-notes had an off-by-one on `/COUNTED-STRING` length.* Story spec said 16; actual is **15** (`/COUNTED-STRING` is 15 ASCII bytes — the leading `/` IS the first character, not extra). The implementation uses 15. Recorded in trap-table.
- *`S" MAX-D" ENVIRONMENT?` stack order corrected.* The story's AC #14d table line and dev-notes table both wrote the expected `.S` shape ambiguously. The non-negotiable architectural rule (E10-D1: low cell on TOS) means after ENVIRONMENT? returns a double-cell value, the stack is `( hi lo true )` bottom-to-top with `true` at TOS, `lo` second, `hi` third. So `. . .` prints `-1 -1 32767` (true, lo, hi), NOT `-1 32767 -1`. REPL test 635 and the .fth comment were corrected to match the implementation, which itself follows E10-D1.
- *Nested-EVALUATE test reformulated.* The story spec used `S\"` (Forth-2014 escape-aware string literal §11.6.2.2266). antforth does not implement `S\"`, so the literal `S" 10 S\" 32 \" EVALUATE +" EVALUATE` test cannot be expressed at the REPL. Substituted a colon-defined helper: `: __E910I S" 32" EVALUATE ; S" 10 __E910I +" EVALUATE`. Same R-stack-LIFO save/restore exercise, expressible without `S\"`.

**ROM size accounting (informational; CCD-4 gate is Story 10.10).** Pre-story `build/antforth.com` = **16202 bytes** (matches Story-10.8 baseline). Post-story = **16772 bytes**. Delta = **+570 bytes**. Slightly above the upper estimate of +550, driven by ENVIRONMENT? table data (~310 bytes for keys + values + length bytes), the DEFCODE body (~110 bytes), the 18 bytes for `rpush_hl` / `rpop_hl` helpers, and ~130 bytes for the EVALUATE thread + (SAVE-INPUT)/(RESTORE-INPUT) helpers + new dictionary headers. Acceptable — the per-epic budget is the gate, and Epics 12–13 are the planned ROM-shrinkers.

**Trap-table (adversarial self-review, AC #15):**

| Attack surface | Trap | Mitigation / verification |
|---|---|---|
| `*/` double-intermediate overflow | Naive `* /` truncates 32767×32767 to 1, then 1/32767=0 — silent wrong answer | Threaded `>R M* R> SM/REM` (via `*/MOD`); REPL test 618 `32767 32767 32767 */` → 32767 |
| `*/MOD` symmetric remainder sign | Floored `FM/MOD` would give `2 -11`; symmetric must give `-1 -10` for `-17 3 5 */MOD` | Threaded via `SM/REM` (symmetric); REPL test 621 verifies signed boundary |
| `EVALUATE` source restoration | After EVALUATE, `tib_in` / `tib_addr` / `tib_len` / `source_id` must equal pre-call values | `S" 99" EVALUATE 7 + .` → 106 (rest of REPL line parses from original TIB); REPL test 624 |
| `EVALUATE` save vs restore order | Off-by-one in `rpush_hl` / `rpop_hl` pairing silently corrupts USER area | LIFO inverse: SAVE pushes source_id, tib_in, tib_len, tib_addr (top last); RESTORE pops top-first; verified via 622–626 plus the regression-recovery property of REPL tests 647–648 |
| `EVALUATE` nesting | Inner save-frame must not collide with outer | LIFO on rstack composes naturally; REPL test 625 nested case → 42 |
| `EVALUATE` + ABORT | Unknown word inside string triggers ABORT, which resets IX wholesale → saved frame discarded; QUERY then overwrites USER area with fresh console input | Documented (AC #5); pre-Epic-11 baseline; Story 11.6 will retro to THROW-safe |
| `ENVIRONMENT?` 14 keys | Off-by-one length byte for any key silently breaks compare loop for that key | Each key tested (REPL 627–640); `/COUNTED-STRING` length byte was the off-by-one trap (15, not 16); table laid out with hand-counted lengths and verified by REPL coverage |
| `ENVIRONMENT?` unknown key | Must return single-cell false (no `i*x`) — distinct from `( value true )` | REPL test 641 `S" XYZZY" ENVIRONMENT? .` → `0` (single cell); .S smoke confirmed `<1> 0` |
| `ENVIRONMENT?` case sensitivity | Lowercase `core` must NOT match `CORE` | REPL test 642 verifies; key-match loop uses raw `CP` (no `UPPER`) |
| `ENVIRONMENT?` MAX-D / MAX-UD byte order | Wrong push order would put hi on TOS, breaking E10-D1 | DEFCODE pushes hi first (deepest), then lo (above hi), then BC=-1 (TOS=true); REPL test 635 verifies `-1 -1 32767` (true, lo, hi) for MAX-D; MAX-UD tested at 638 |
| `*/`, `*/MOD`, `EVALUATE`, `ENVIRONMENT?` underflow | Each must trip `? Stack underflow` and recover via REPL ABORT | REPL tests 643–650 cover DEPTH=0..N-1 for each word; all PASS |
| Standards citations | `§6.1.0100` / `§6.1.0110` / `§6.1.1345` / `§6.1.1360` transposition risk | Source comments (`arithmetic.asm:268`, `arithmetic.asm:289`, `outer_interpreter.asm:355`, `system.asm:268`) cite the four §-numbers verbatim; cross-checked against `docs/ans-forth-core-compliance.md` per AC #11 |
| ROM delta direction | `build/antforth.com` should grow (no shrinkage expected) | +570 bytes recorded; direction matches expectation |

**Closure statement (AC #18).** Story 10.10 (Epic-10 close-out) can now verify FR15 / NFR10 pass with a single sentence: **133/133 §6.1 Core words implemented, zero deliberate omissions.** The §6.2 Core Extension partial (11/46) is orthogonal to FR15 and remains an open observation — not a gate. This matches the 10.1 Senior Developer Review resolution (SR-1 closed via party-mode 2026-04-20).

### Senior Developer Review (AI) — 2026-04-25

**Reviewer:** claude-opus-4-7 (1M-context profile) via Claude Code code-review workflow.
**Outcome:** Approved with minor fixes. All findings resolved in-session per option [1] (auto-fix).

**Findings:**

| ID | Sev | Description | Resolution |
|---|---|---|---|
| M1 | Medium | AC #14a's div-by-zero test missing AND its predicted behaviour (`? Stack underflow` or ABORT) does not match observed SM/REM silent baseline | Added Makefile REPL tests 651/652 documenting actual silent baseline; corrected AC #14a wording in story to match reality and flag Story 11.6 migration |
| L1 | Low | `(SAVE-INPUT)` / `(RESTORE-INPUT)` are user-callable; `(paren)` convention is documentation-only with no SMUDGE protection | Added explicit INVARIANT block comments at both helper bodies (`outer_interpreter.asm:288, 333`) stating must-be-paired discipline and "treat as private" |
| L2 | Low | `env_table` kind dispatch silently falls through for `kind >= 3`; no defense or comment defending the dispatch | Added inline comment at `system.asm` post-`DEC A; JR Z, .env_kind_double` documenting expected post-DEC values and instructing future contributors to add explicit branches before fall-through |
| L3 | Low | Story Dev Notes asserted `/COUNTED-STRING` = 16 chars (off-by-one); implementation correctly used 15 | Corrected story spec line in-place; preserved a "post-review correction" note for traceability |
| L4 | Low | Test-count expectation ~658 vs actual 659 | Corrected to 661 (incl. review follow-ups) in story task 9.3 |

**Post-fix verification:** `make test` PASS; `make test-repl` 661 PASS / 0 FAIL; binary unchanged at 16772 bytes (review fixes are comment-only edits + 2 new Makefile test entries; no code or table changes).

**Status transition:** review → done. All ACs implemented; all review findings resolved.

### Change Log

| Date | Change | Files |
|---|---|---|
| 2026-04-24 | Story 10.9 implementation: closed §6.1 Core gap (129→133, 100.0%) | `src/arithmetic.asm`, `src/outer_interpreter.asm`, `src/system.asm`, `src/inner_interpreter.asm`, `tests/core_gap_tests.fth`, `Makefile`, `docs/ans-forth-core-compliance.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml`, `_bmad-output/implementation-artifacts/10-9-remaining-core-gap-words.md` |
| 2026-04-25 | Code-review fixes: M1 div-by-zero baseline tests (REPL 651/652) and AC #14a correction; L1 (SAVE-INPUT)/(RESTORE-INPUT) invariant comments; L2 ENVIRONMENT? kind-dispatch defensive comment; L3 /COUNTED-STRING length corrected (16 → 15); L4 test count corrected (~658 → 661). Binary size unchanged (comment-only edits + 2 new Makefile entries). | `Makefile`, `tests/core_gap_tests.fth`, `src/outer_interpreter.asm`, `src/system.asm`, `_bmad-output/implementation-artifacts/10-9-remaining-core-gap-words.md` |

### File List

**Modified:**

- `src/inner_interpreter.asm` — added `rpush_hl` / `rpop_hl` helpers (+18 bytes).
- `src/arithmetic.asm` — appended DEFWORDs `*/MOD` (`§6.1.0110`) and `*/` (`§6.1.0100`).
- `src/outer_interpreter.asm` — appended DEFCODE helpers `(SAVE-INPUT)` / `(RESTORE-INPUT)` and DEFWORD `EVALUATE` (`§6.1.1360`).
- `src/system.asm` — appended DEFCODE `ENVIRONMENT?` (`§6.1.1345`) and 14-entry static `env_table` (DPANS94 §3.2.6 query keys).
- `tests/core_gap_tests.fth` — appended Story 10.9 section (`*/`, `*/MOD`, `EVALUATE`, `ENVIRONMENT?` blocks plus underflow recovery).
- `Makefile` — appended REPL test entries 615..650 (36 new tests).
- `docs/ans-forth-core-compliance.md` — Summary 129→133 / 97.0%→100.0%; Gap Classification all zeros; Epic-10 closure-plan 10.9 row marked complete; Arithmetic and System tables flipped; Gap Analysis (b) collapsed; Observations updated.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `10-9-remaining-core-gap-words: ready-for-dev → in-progress` (will move to `review` at workflow close).
- `_bmad-output/implementation-artifacts/10-9-remaining-core-gap-words.md` — Status, Dev Agent Record, Change Log, File List filled in.

**Created:** none.

**Deleted:** none.
