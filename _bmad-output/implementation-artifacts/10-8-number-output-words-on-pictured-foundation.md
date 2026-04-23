# Story 10.8: Number-output words on pictured foundation (`.`, `U.`, `D.`, `.R`, `U.R`, `D.R`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the Core number-display words reimplemented on top of the new pictured-output primitives,
So that the whole display family behaves consistently with user-defined pictured formatters, and so Epic 10 removes the pre-phase hand-rolled decimal/hex-specific output paths.

## Acceptance Criteria

**Foundation (carried from epic spec `_bmad-output/planning-artifacts/epics.md:602-624`):**

1. **Given** the pictured-output primitives from Story 10.7 **When** `.`, `U.`, `D.`, `.R`, `U.R`, `D.R` are rewritten atop `<# ... #>` **Then** they produce byte-for-byte identical output to the pre-Epic-10 implementations for every input covered by the Epic 1–8 regression tests (zero regression per NFR9).

2. **Given** `src/formatting.asm` **When** edited to redirect these words onto pictured output **Then** the pre-Epic-10 hand-rolled DEFCODE bodies for `.` / `U.` / `.R` are removed (ROM size *contribution* toward the NFR5 negative target — the epic-wide direction, not a per-story mandate).

3. **Given** ANS semantics for `.R` **When** `.R n` is called with `n < string-width` **Then** the output is not truncated; `u < n` widths are left-padded with zero spaces (the `SPACES` primitive is a no-op for `n ≤ 0` per `src/io.asm:83`), matching §6.2.0210. (The epic text cites `§6.1.0310`; that is a drafting typo — `docs/ans-forth-core-compliance.md:334` and forth-standard.org both place `.R` at §6.2.0210 Core Extension. Use §6.2.0210 in the source citation.)

4. **Given** `tests/core_gap_tests.fth` (new file) **When** it runs **Then** every display word has a regression suite that was green pre-Epic-10 and stays green post-Epic-10; new cases exercise the pictured-output path explicitly (including the `HOLD`-redefinition standard-compliance check described in AC #8).

**Story-level (Story 10.8-specific):**

5. **Given** DEFWORD bodies for the six display words **When** each is written **Then** each source carries an ANS / Forth 2014 citation per CCD-3 (`architecture.md:206-216`) and a stack-effect comment on its DEFWORD line. **Verified §-numbers** (using the `docs/ans-forth-core-compliance.md` 3-part rendering; DPANS94 itself renders §8.6 entries in 4-part form — e.g., `§8.6.1.1060` ≡ `§8.6.1060` here): `.` §6.1.0180 · `U.` §6.1.2320 · `D.` §8.6.1060 · `.R` §6.2.0210 · `U.R` §6.2.2330 · `D.R` §8.6.1070.

6. **Given** E10-D1 byte-order (`architecture.md:250` — low cell on TOS, high cell second) **When** `D.` / `D.R` process a signed double `( hi lo )` **Then** the HIGH cell's sign bit drives `SIGN`. Verified by: `-1 -1 D.` → `-1 ` and `-1 -1 10 D.R` → `        -1` (8 spaces + `-1`).

7. **Given** `.S` (in `src/formatting.asm:262`) still calls `u_to_str`, `emit_unsigned`, `print_neg_prefix`, `div_bc_by_e`, `digit_to_char`, and uses `num_buf` **When** the DEFCODE bodies for `.` / `U.` / `.R` are deleted **Then** `u_to_str` / `div_bc_by_e` / `print_neg_prefix` / `emit_unsigned` / `digit_to_char` / `num_buf` are **preserved**; `.S` behaviour is unchanged (`1 2 3 .S` → `<3> 1 2 3 `). Do not delete these helpers without first rewriting `.S`, which is explicitly out-of-scope for Story 10.8.

8. **Given** the epic AC #4 clause "redefine `HOLD` in a user wordlist and see `.` unaffected — standard-compliance check" **When** a Forth `:` definition redefines `HOLD` at run time (`: HOLD DROP ;`) **Then** `42 .` continues to print `42 ` via the ORIGINAL `HOLD`. Antforth's behaviour here is early-binding-by-construction: (a) `.`'s DEFWORD body compiles the xt of `#>` / `#S` / `SIGN` / etc. at build time, not of user-level `HOLD`; (b) the pictured DEFCODE primitives (`#`, `SIGN`, `HOLDS`) directly `CALL hold_common` — a Z80-level helper — not the dictionary `HOLD` cf. Redefining `HOLD` in Forth cannot reach into either path. This test both documents the behaviour and is a positive-evidence regression gate.

9. **Given** underflow discipline parity with Story 10.7 **When** `.` / `U.` / `D.` / `.R` / `U.R` / `D.R` are called with insufficient parameter stack **Then** `? Stack underflow` fires through the factor primitives (each factor's own `check_underflow` / `_2` guards trip before any pictured-output state is mutated). **No new** `(?N)` guard is required for the six DEFWORDs — the factor chain guards every entry. Specifically:
   - `.` / `U.`: first body cell is `S>D` (resp. `LIT 0` → `SWAP`); `S>D` / `SWAP` underflow-guard themselves.
   - `D.`: first cell `OVER` → 2-cell guard.
   - `.R` / `U.R`: first cell `>R` (1-cell); second path reaches `OVER` or `SWAP` (2-cell).
   - `D.R`: first cell `>R` (1-cell); next `OVER` (2-cell with +n already on R-stack); `ABORT` path resets both stacks, so no R-stack leak.

10. **Given** the ROM size accounting for NFR5 (informational — CCD-4 gate is Story 10.10) **When** the build completes after Story 10.8 **Then** `build/antforth.com` delta vs. the post-Story-10.7 baseline (16209 bytes) is recorded in the Dev Agent Record. **Direction estimate:** slight negative to slight positive, within ±40 bytes — the three DEFCODE deletions save ~140 bytes of straight-line code but the six DEFWORD bodies (160 bytes of threaded cells) plus three new dictionary entries (3 × ~12 bytes ≈ 36 bytes) cost ~196 bytes. Net ~+56 bytes is plausible; acceptable because Epic-wide NFR5 direction is what CCD-4 gates, not Story 10.8 alone.

11. **Given** §-number write-time verification discipline (per `feedback_systematic_reference_check.md`) **When** citations are written into source **Then** each is verified against `docs/ans-forth-core-compliance.md` (authoritative after Story 10.1) and DPANS94 / forth-standard.org — NOT against memory and NOT against the epic spec (which mis-cites `.R` as `§6.1.0310`; the correct reference is `§6.2.0210` per the compliance doc line 334).

12. **Given** the Makefile's contiguous `test-repl` numbering (post-Story-10.7 max = **578**) **When** Story 10.8 tests are appended **Then** new entries start at **579** and increment contiguously, following the Story 10.7 format (printf-HEREDOC → REPL → grep-for-expected-substring → PASS/FAIL). `$$` escape and `printf --` discipline apply (per Story 10.7 retro).

13. **Given** `docs/ans-forth-core-compliance.md` **When** Story 10.8 completes **Then** the doc is refreshed:
    - line **46** (Epic-10 closure-plan row for 10.8): mark complete.
    - line **334** (`.R` in §6.2 bonus coverage): source reference updated from `formatting.asm:174` (DEFCODE) to the new DEFWORD line number.
    - line **350** (`U.R` in "Will gain via Epic 10"): mark `10.8 ✓ Implemented (formatting.asm)`.
    - line **368** (`D.` in §8.6 table): update Story field to `10.8 ✓ Implemented (formatting.asm)`.
    - line **369** (`D.R` in §8.6 table): same pattern.
    - line **330** §6.2 bonus counter: `10 of 46` → `11 of 46` (adds `U.R`; `.R` already counted).
    - line **352+** §8.6 bonus counter implied (currently "13 §8.6 additions planned" → implemented count advances by 2 for `D.` / `D.R`; adjust the prose at line 372 accordingly).
    - date header: refreshed to Story 10.8 refresh date.
    - §6.1 counter (line 11-18 Summary table): **unchanged** at 129/133 (97.0%) — `.R` is §6.2 Core Extension, not §6.1, so rewriting does not affect §6.1 count; `U.R` / `D.` / `D.R` are §6.2 / §8.6 bonus, also outside §6.1.

14. **Given** REPL test coverage (AC #4, #12) **When** Story 10.8 completes **Then** Makefile `test-repl` has ~23 new entries at **579..~601** covering: (a) `.` regression byte-for-byte; (b) `U.` regression; (c) `.R` regression including `n < string-width` no-truncation; (d) `D.` new with zero, positive, negative, and worst-case `-1 -1` across base 10 / hex; (e) `U.R` new; (f) `D.R` new with zero, positive, negative, width ≤ string; (g) pictured-path explicit (custom recipe matching `.`'s output byte-for-byte); (h) early-binding `HOLD`-redefinition; (i) `.S` preservation smoke; (j) underflow-path parity (one per word).

15. **Given** adversarial self-review discipline (per `feedback_adversarial_review.md`) **When** Story 10.8 closes **Then** the Dev Agent Record includes a trap-table covering at minimum: byte-for-byte regression, double-cell SIGN path (E10-D1 high-cell-drives-SIGN), `.R` no-truncation edges (`width = 0`, `width < string-width`), `.S` / `u_to_str` / `num_buf` preservation, early-binding demonstration, underflow chain through factor primitives, `DABS($80000000)` corner case (`$80000000 $FFFF8000 D.` / the `-2147483648` boundary), and ROM delta direction.

## Tasks / Subtasks

- [x] **Task 1: Standards verification** (AC #5, #11)
  - [x] 1.1 Cross-reference §-numbers against `docs/ans-forth-core-compliance.md` — record the exact §-numbers for each of the six words in a Dev-Notes table before writing any source.
  - [x] 1.2 Spot-check at least two (`D.`, `D.R`) against forth-standard.org to catch any residual drift from the compliance doc — §8.6.1060 → `D.`; §8.6.1070 → `D.R`; §6.2.0210 → `.R`; §6.2.2330 → `U.R`.
  - [x] 1.3 Record the epic-spec §6.1.0310 typo for `.R` as a Dev-Notes callout, following Story 10.7's HOLDS-typo precedent — this prevents a re-introduction via copy-paste.

- [x] **Task 2: Rewrite `.`, `U.`, `.R` as DEFWORD threaded bodies in `src/formatting.asm`** (AC #1, #2, #3, #5, #9)
  - [x] 2.1 Delete DEFCODE body `w_DOT_cf` (`formatting.asm:132-147`) entirely, including the `CALL check_underflow` + shadow-register dance + `CALL print_neg_prefix` + `CALL emit_unsigned` + `NEXT`.
  - [x] 2.2 Delete DEFCODE body `w_U_DOT_cf` (`formatting.asm:155-166`) entirely.
  - [x] 2.3 Delete DEFCODE body `w_DOT_R_cf` (`formatting.asm:175-247`) entirely, **including** its scratch state `.dotr_neg` / `.dotr_str` / `.dotr_len` (`formatting.asm:249-251`).
  - [x] 2.4 Add DEFWORD `.` at the same source location:
    ```
    ; . ( n -- )   Display signed n in free-field format, trailing space.
    ; ANS Forth 1994 §6.1.0180   .   — print signed number
    w_DOT:
            DEFWORD ".", 0
    w_DOT_body:
    w_DOT_cf    EQU     w_DOT_body - 3
            DW      w_S_TO_D_cf     ; S>D    ( n -- d )
            DW      w_D_DOT_cf      ; D.     ( d -- )
            DW      EXIT_CODE
    ```
  - [x] 2.5 Add DEFWORD `U.` at the `.`-adjacent position:
    ```
    ; U. ( u -- )   Display unsigned u in free-field format, trailing space.
    ; ANS Forth 1994 §6.1.2320   U.   — print unsigned number
    w_U_DOT:
            DEFWORD "U.", 0
    w_U_DOT_body:
    w_U_DOT_cf  EQU     w_U_DOT_body - 3
            DW      w_LIT_cf, 0     ; 0      ( u 0 )
            DW      w_SWAP_cf       ; SWAP   ( 0 u )  — E10-D1: hi=0, lo=u
            DW      w_D_DOT_cf      ; D.
            DW      EXIT_CODE
    ```
  - [x] 2.6 Add DEFWORD `.R` (same `w_DOT_R` name):
    ```
    ; .R ( n +n -- )   Display signed n right-aligned in +n-char field.
    ; ANS Forth 1994 §6.2.0210   .R   — print signed, right-aligned (Core Extension)
    w_DOT_R:
            DEFWORD ".R", 0
    w_DOT_R_body:
    w_DOT_R_cf  EQU     w_DOT_R_body - 3
            DW      w_TO_R_cf       ; >R     ( n ; R:+n )
            DW      w_S_TO_D_cf     ; S>D    ( d ; R:+n )
            DW      w_R_FROM_cf     ; R>     ( d +n )
            DW      w_D_DOT_R_cf    ; D.R
            DW      EXIT_CODE
    ```
  - [x] 2.7 **Preserve** `u_to_str` / `div_bc_by_e` / `print_neg_prefix` / `emit_unsigned` / `digit_to_char` (still used by `.S` at `formatting.asm:262`). **Do not** delete `num_buf` from `antforth.asm:234`.
  - [x] 2.8 **Preserve** `w_DOT_S` (`.S` at `formatting.asm:262`) entirely. Verify by running `1 2 3 .S` after the edit and observing `<3> 1 2 3 ` (AC #7).

- [x] **Task 3: Add `D.`, `U.R`, `D.R` DEFWORD bodies in `src/formatting.asm`** (AC #1, #5, #6)
  - [x] 3.1 DEFWORD `D.` — place immediately above `w_DOT` (so `.` can reference `w_D_DOT_cf`; forward `_cf` refs also work, but reverse order is cleaner):
    ```
    ; D. ( d -- )   Display signed double d in free-field format, trailing space.
    ; ANS Forth 1994 §8.6.1.1060   D.   — print signed double (Double-Number set)
    w_D_DOT:
            DEFWORD "D.", 0
    w_D_DOT_body:
    w_D_DOT_cf  EQU     w_D_DOT_body - 3
            DW      w_OVER_cf       ; OVER   ( hi lo hi )         — copy hi-cell (carries sign)
            DW      w_TO_R_cf       ; >R     ( hi lo ; R:hi )
            DW      w_D_ABS_cf      ; DABS   ( uhi ulo ; R:hi )
            DW      w_PIC_LESS_HASH_cf      ; <#
            DW      w_PIC_HASH_S_cf         ; #S     ( 0 0 ; R:hi )
            DW      w_R_FROM_cf     ; R>     ( 0 0 hi )
            DW      w_PIC_SIGN_cf   ; SIGN   ( 0 0 )              — HOLD '-' if hi<0
            DW      w_PIC_GREATER_HASH_cf   ; #>     ( c-addr u )
            DW      w_TYPE_cf       ; TYPE
            DW      w_SPACE_cf      ; SPACE
            DW      EXIT_CODE
    ```
  - [x] 3.2 DEFWORD `U.R` — place near `.R`:
    ```
    ; U.R ( u +n -- )   Display unsigned u right-aligned in +n-char field.
    ; Forth 2014 §6.2.2330   U.R   — print unsigned, right-aligned (Core Extension)
    w_U_DOT_R:
            DEFWORD "U.R", 0
    w_U_DOT_R_body:
    w_U_DOT_R_cf EQU    w_U_DOT_R_body - 3
            DW      w_TO_R_cf       ; >R     ( u ; R:+n )
            DW      w_LIT_cf, 0     ; 0      ( u 0 )
            DW      w_SWAP_cf       ; SWAP   ( 0 u )
            DW      w_R_FROM_cf     ; R>     ( 0 u +n )
            DW      w_D_DOT_R_cf    ; D.R
            DW      EXIT_CODE
    ```
  - [x] 3.3 DEFWORD `D.R` — place just above `D.`:
    ```
    ; D.R ( d +n -- )   Display signed double d right-aligned in +n-char field.
    ; ANS Forth 1994 §8.6.1.1070   D.R   — print signed double, right-aligned
    w_D_DOT_R:
            DEFWORD "D.R", 0
    w_D_DOT_R_body:
    w_D_DOT_R_cf EQU    w_D_DOT_R_body - 3
            DW      w_TO_R_cf       ; >R     ( hi lo ; R:+n )
            DW      w_OVER_cf       ; OVER   ( hi lo hi ; R:+n )
            DW      w_TO_R_cf       ; >R     ( hi lo ; R:+n hi )
            DW      w_D_ABS_cf      ; DABS   ( uhi ulo ; R:+n hi )
            DW      w_PIC_LESS_HASH_cf      ; <#
            DW      w_PIC_HASH_S_cf         ; #S     ( 0 0 ; R:+n hi )
            DW      w_R_FROM_cf     ; R>     ( 0 0 hi ; R:+n )
            DW      w_PIC_SIGN_cf   ; SIGN   ( 0 0 ; R:+n )
            DW      w_PIC_GREATER_HASH_cf   ; #>     ( c-addr u ; R:+n )
            DW      w_R_FROM_cf     ; R>     ( c-addr u +n )
            DW      w_OVER_cf       ; OVER   ( c-addr u +n u )
            DW      w_MINUS_cf      ; -      ( c-addr u pad )   pad = +n - u
            DW      w_SPACES_cf     ; SPACES ( c-addr u )       — no-op if pad ≤ 0
            DW      w_TYPE_cf       ; TYPE
            DW      EXIT_CODE
    ```
  - [x] 3.4 Verify label names against `src/double.asm`, `src/pictured.asm`, `src/stack_ops.asm`, `src/io.asm`, `src/arithmetic.asm`, `src/dictionary.asm` — the labels referenced above must resolve. Known-good: `w_S_TO_D_cf` (`double.asm:157`), `w_D_ABS_cf` (`double.asm:297`), `w_OVER_cf` (`stack_ops.asm:63`), `w_SWAP_cf` (`stack_ops.asm:49`), `w_TO_R_cf` (`stack_ops.asm:250`), `w_R_FROM_cf` (`stack_ops.asm:264`), `w_MINUS_cf` (`arithmetic.asm:70`), `w_TYPE_cf` (`io.asm:25`), `w_SPACE_cf` (`io.asm:74`), `w_SPACES_cf` (`io.asm:87`), `w_LIT_cf` (`compiler.asm` / `dictionary.asm` — grep), `w_PIC_LESS_HASH_cf` / `w_PIC_HASH_S_cf` / `w_PIC_SIGN_cf` / `w_PIC_GREATER_HASH_cf` (`pictured.asm`).

- [x] **Task 4: Create `tests/core_gap_tests.fth`** (AC #4, #14)
  - [x] 4.1 File banner per Story 10.7 convention (`tests/pictured_tests.fth:1-16`); section headers `\ === Story 10.8 number-output on pictured foundation ===`.
  - [x] 4.2 `.` regression block — `0 .` `1234 .` `-5 .` `32767 .` `-32768 .` `HEX 255 .` (+ DECIMAL reset after).
  - [x] 4.3 `U.` regression block — `0 U.` `1234 U.` `65535 U.` `HEX 65535 U.` (+ DECIMAL reset).
  - [x] 4.4 `.R` regression block — `42 10 .R` (8 spaces + "42"), `-5 10 .R` (8 spaces + "-5"), `1234 3 .R` (no truncation → `1234`), `0 0 .R` (no pad → `0`), `0 5 .R` (4 spaces + `0`).
  - [x] 4.5 `D.` block — 0/+/-, `-1 -1` worst case, and `32768 0 D.` as the INT_MIN/$80000000 corner (simpler construction than `HEX 8000 0 DECIMAL D.`; same semantics — hi=$8000, lo=0 → DABS preserves $80000000, SIGN fires on hi, output `-2147483648 `).
  - [x] 4.6 `U.R` block — `42 10 U.R` → 8 spaces + `42`; `65535 10 U.R` → 5 spaces + `65535`; `0 0 U.R` → `0`; `65535 8 HEX U.R DECIMAL` → 4 spaces + `FFFF`.
  - [x] 4.7 `D.R` block — `0 0 10 D.R` → 9 spaces + `0`; `0 123 10 D.R` → 7 spaces + `123`; `-1 -1 10 D.R` → 8 spaces + `-1`; `-1 -1 0 D.R` → `-1` (no truncation).
  - [x] 4.8 Pictured-path explicit block — `: DOT-VIA-PICT S>D OVER >R DABS <# #S R> SIGN #> TYPE SPACE ;` then `1234 DOT-VIA-PICT` → `1234 ` (byte-identical to `1234 .`).
  - [x] 4.9 Early-binding `HOLD`-redefinition block — `: HOLD DROP ;` then `42 .` → `42 ` (unchanged).
  - [x] 4.10 `.S` preservation smoke — `1 2 3 .S` → `<3> 1 2 3 ` (AC #7 positive evidence).
  - [x] 4.11 Underflow-parity block — invoke each of the six words on an empty stack; verify `? Stack underflow` (AC #9).

- [x] **Task 5: Makefile `test-repl` entries 579..611** (AC #12, #14) — 33 new entries (original estimate ~23 expanded to cover E10-D1 byte-order sanity cases and HEX discipline).
  - [x] 5.1 Follow the canonical printf-HEREDOC + grep format from `Makefile:4971-5023` (Story 10.7 retro-pass).
  - [x] 5.2 One entry per `tests/core_gap_tests.fth` scenario; keep numbering contiguous.
  - [x] 5.3 Apply `$$` escape (hex literals, `$`-prefixed banners) and `printf --` terminator for inputs that begin with `-` (e.g., `-5 .`).
  - [x] 5.4 Add a Story-10.8 banner line above the block: `@# --- Story 10.8 number-output on pictured foundation (579..610) ---`.

- [x] **Task 6: Update `docs/ans-forth-core-compliance.md`** (AC #13)
  - [x] 6.1 Line 46: mark Epic-10 closure-plan row for 10.8 as complete.
  - [x] 6.2 Line 334 `.R` row: update source reference from `formatting.asm:174` to `formatting.asm:203` (new DEFWORD location).
  - [x] 6.3 Line 350 `U.R` row: update to `10.8 ✓ Implemented (formatting.asm:217)`.
  - [x] 6.4 Line 368 `D.` row: update to `10.8 ✓ Implemented (formatting.asm:156)`.
  - [x] 6.5 Line 369 `D.R` row: update to `10.8 ✓ Implemented (formatting.asm:132)`.
  - [x] 6.6 Line 330 §6.2 bonus counter: `10 of 46` → `11 of 46` (adds `U.R`; `.R` already counted).
  - [x] 6.7 Line 372 §8.6 prose: updated to "all 13 implemented post-Story-10.8 — `D.` and `D.R` landed with this refresh".
  - [x] 6.8 Date header: refreshed to 2026-04-23 (Story 10.8 refresh).
  - [x] 6.9 §6.1 Summary table (line 11-18) and Gap Classification (line 23-28) unchanged — `.R` is §6.2 Core Extension, `U.R` / `D.` / `D.R` are §6.2 / §8.6, so none affect the §6.1 129/133 count.

- [x] **Task 7: ROM size accounting** (AC #10, informational)
  - [x] 7.1 Measured `build/antforth.com` before edits: **16209 bytes** (matches post-10.7 baseline).
  - [x] 7.2 Measured after all edits: **16202 bytes**.
  - [x] 7.3 Delta: **−7 bytes**. Breakdown: three DEFCODE deletions (`w_DOT_cf` ~27 bytes body, `w_U_DOT_cf` ~17 bytes body, `w_DOT_R_cf` ~120 bytes body including `.dotr_neg/.dotr_str/.dotr_len` scratch, ~164 bytes total) plus dictionary-header savings (old DEFCODE headers have the `JP cf` replaced with a `JP DOCOL` in DEFWORDs — comparable). Offset by six new DEFWORDs' threaded bodies (~82 bytes) and three new dictionary entries for `D.` / `U.R` / `D.R` (~36 bytes) plus `JP DOCOL` overhead (~9 bytes × 6 = but three of those reuse existing header slots for `.` / `U.` / `.R`). Net: well within the spec's ±40-byte estimate; direction is slightly negative (favourable for NFR5).

- [x] **Task 8: Adversarial self-review** (AC #15, per `feedback_adversarial_review.md`) — see trap-table in Completion Notes.
  - [x] 8.1 Byte-for-byte regression: `make test-repl` — all 587 pre-existing tests pass (1 amended, see Completion Notes §Test 573).
  - [x] 8.2 Double-cell SIGN path: `-1 -1 D.` → `-1 ` (test 594); `-1 -1 10 D.R` → 8 spaces + `-1` (test 601); `32768 0 D.` → `-2147483648 ` (test 597, INT_MIN / DABS($80000000) corner).
  - [x] 8.3 `.R` no-truncation: `1234 3 .R` → `1234` (test 591); `0 0 .R` → `0` (test 592); `-1 -1 0 D.R` → `-1` (test 602).
  - [x] 8.4 `.S` preservation: `1 2 3 .S` → `<3> 1 2 3 ` (test 605).
  - [x] 8.5 Early-binding: `: HOLD DROP ; 42 .` → `42 ` (test 604).
  - [x] 8.6 Underflow chain: all six words (tests 606–611).
  - [x] 8.7 HEX discipline: `255 HEX . DECIMAL` → `FF ` (584); `65535 HEX U. DECIMAL` → `FFFF ` (588); `0 -1 HEX D. DECIMAL` → `FFFF ` (596).
  - [x] 8.8 Trap-table in Completion Notes.

- [x] **Task 9: Finalise Dev Agent Record** (AC #15)
  - [x] 9.1 Agent Model Used / Debug Log References / Completion Notes / File List filled.
  - [x] 9.2 Trap-table recorded (AC #15).
  - [x] 9.3 Post-story `make test-repl` count: **620 passing, 0 failing** (587 pre-existing + 33 new for Story 10.8).
  - [x] 9.4 Status managed by `dev-story` workflow (`ready-for-dev → in-progress → review`).

- [x] **Task 10: Code-review follow-ups (2026-04-23)** — fixed in review pass; see Completion Notes §Review follow-ups.
  - [x] 10.1 [M1] Add Makefile entry for `32768 0 15 D.R` → 4 spaces + `-2147483648` (D.R × INT_MIN regression gate — previously only covered in `tests/core_gap_tests.fth`).
  - [x] 10.2 [M2] Add Makefile entry for `0 12345 D.` → `12345 ` (typical positive double — AC #14d "positive" leg was thin).
  - [x] 10.3 [M3] Align AC #5 §-number rendering with the compliance doc (3-part form) and source (same); parenthetical notes the DPANS94 4-part form is equivalent.
  - [x] 10.4 [L1] Fix Makefile banner off-by-one: `(579..610)` → `(579..614)`.
  - [x] 10.5 [L2] Drop the degenerate `HEX 255 . DECIMAL` line from `tests/core_gap_tests.fth` (tautological — both bases yield `255` for this input; adjacent `255 HEX . DECIMAL → FF` is the real HEX-discipline test).
  - [x] 10.6 [L4] Add inline underflow-chain comments to `.R` / `U.R` / `D.R` DEFWORD bodies.
  - [x] 10.7 [L6] Add `.R` negative-width sanity test (`42 -5 .R` → `42`) in both .fth and Makefile.

## Dev Notes

### Story Purpose and Epic-10 Position

Story 10.8 is the **seventh implementation story in Epic 10** and the **last code-writing story before Story 10.10's CCD-4 benchmark gate** (Story 10.9 adds the remaining four non-display gap words). It consumes the `<# # #S #> SIGN HOLD HOLDS` wordset delivered by Story 10.7 and rebuilds the antforth number-display family on top of that foundation.

Three things fall out of this story:

1. **Observable output of `.` / `U.` / `.R` is preserved byte-for-byte** (AC #1, #2). This is the NFR9 zero-regression contract — any Epic-1–8 program that prints numbers sees the same characters after Story 10.8.

2. **Three new words — `D.` / `U.R` / `D.R` — are added** as bonus Core Extension / Double-Number coverage. Combined with Story 10.7's `HOLDS`, antforth's §6.2 Core Extension bonus count advances from 9 (pre-10.7) → 10 (post-10.7) → 11 (post-10.8, adds `U.R`). §8.6 Double-Number implemented count advances by 2 (`D.` / `D.R`).

3. **Six DEFCODE-to-DEFWORD conversions** remove the hand-rolled hex/decimal-specific output paths. This is the AC #2 contribution to NFR5's negative ROM target. Net ROM delta for *this* story is expected near-zero (within ±40 bytes); the negative target is an epic-wide aspiration that the CCD-4 gate evaluates at Story 10.10.

### Architectural Decisions That Apply to This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§206-216 CCD-3 (Standards-Citation Discipline):** every DEFWORD cites its DPANS94 §-number. Non-negotiable — see AC #5, #11. Cross-reference against `docs/ans-forth-core-compliance.md` at write-time.
- **§218-226 CCD-4 (Per-Epic Benchmark Gate):** gate is at **Story 10.10**, not here. Record ROM delta informationally (AC #10).
- **§246-252 E10-D1 (Byte-Order):** low cell on TOS, high cell second. For `D.` / `D.R`: `d` on entry is `( hi lo )` with `lo = BC` (TOS). The HIGH cell drives `SIGN`. Non-negotiable (AC #6).
- **§254-258 E10-D2 (Pictured-output buffer placement):** already consumed in Story 10.7 — the 40-byte `pic_buf` is large enough for the worst-case 32-bit-signed formatted output (20 digits decimal + sign + radix-2 expansion fits); Story 10.8 never writes more than `D.` / `D.R` already require, so the buffer-overflow boundary is unreached in normal use.
- **§260-264 E10-D3 (Implementation split):** pictured's hot primitives are already in assembly (Story 10.7); Story 10.8 adds *only* thin threaded wrappers in Forth-inside-ASM. This is the E10-D3 "thin wrapper" category.
- **§434-447 Source-file organisation:** `src/formatting.asm` is the established home for number-display words. `D.` / `U.R` / `D.R` live here, not in `src/double.asm`. Rationale: cohesion with `.` / `U.` / `.R` (one neighbourhood) and the epic spec's explicit "**Given** `src/formatting.asm`" phrasing.

### Canonical Threaded Bodies

Keep these in your editor. They were derived from DPANS94 reference bodies and then **adjusted for E10-D1 byte-order** (the classic literature assumes high-on-TOS; antforth uses low-on-TOS):

| Word | Threaded Body (informal) | Cell count + EXIT |
|---|---|---|
| `.` | `S>D D.` | 3 |
| `U.` | `0 SWAP D.` | 4 (LIT+0, SWAP, D., EXIT) |
| `D.` | `OVER >R DABS <# #S R> SIGN #> TYPE SPACE` | 11 |
| `.R` | `>R S>D R> D.R` | 5 |
| `U.R` | `>R 0 SWAP R> D.R` | 6 (LIT+0 is 2 cells) |
| `D.R` | `>R OVER >R DABS <# #S R> SIGN #> R> OVER - SPACES TYPE` | 15 |

**Why factor via `D.` / `D.R`?** The single-cell and unsigned variants reduce to double-cell calls by zero-extending (`U.` / `U.R`) or sign-extending (`.` / `.R`). Factoring keeps the six words coherent, saves ~8-12 bytes of threaded cells, and matches the classical Forth idiom.

### E10-D1 Byte-Order — the Canonical-Body Trap

**This is the single most important trap in Story 10.8.** DPANS94 does not mandate a cell order for double-cell values on the stack; implementations choose. The classical canonical body `: D. TUCK DABS <# #S ROT SIGN #> TYPE SPACE ;` **assumes HIGH cell on TOS**. Antforth's E10-D1 puts LOW on TOS. If you copy-paste the classical body verbatim:

- Entry `( hi lo )` — lo TOS
- `TUCK` → `( lo hi lo )`
- `DABS` operates on top double `( hi lo )` which *is* the original double; returns `( uhi ulo )` → stack `( lo uhi ulo )`.
- `<# #S` → `( lo 0 0 )` — emits digits of the (correctly-signed-absolute) double.
- `ROT` → `( 0 0 lo )` — brings `lo` to TOS.
- `SIGN` — looks at bit 15 of `lo`, **but the sign lives in `hi`** in E10-D1. **WRONG.**

The correct body is `OVER >R DABS <# #S R> SIGN #> TYPE SPACE`:
- `OVER` copies `hi` to TOS → `( hi lo hi )`.
- `>R` stashes `hi` on R-stack → `( hi lo ; R: hi )`.
- `DABS` on `( hi lo )` → `( uhi ulo ; R: hi )`.
- `<# #S` → `( 0 0 ; R: hi )`.
- `R>` → `( 0 0 hi )`. Now `hi` (which carries the sign bit) is on TOS for `SIGN`.

**Verification fixture (must pass):** `-1 -1 D.` → `-1 `. Trace:
- Entry `( hi=-1 lo=-1 )` — represents double $FFFFFFFF = -1 signed.
- `OVER` → `( -1 -1 -1 )`.
- `>R` → `( -1 -1 ; R: -1 )`.
- `DABS` negates to absolute: `( 0 1 ; R: -1 )` (|−1| = 1 as an unsigned double).
- `<# #S` → emits `1`, stack `( 0 0 ; R: -1 )`.
- `R>` → `( 0 0 -1 )`.
- `SIGN` — bit 15 of TOS (`-1`) is set → HOLD `'-'` → stack `( 0 0 )`.
- `#>` → `( c-addr 2 )` pointing to `"-1"`.
- `TYPE SPACE` → stdout `-1 `.

If you see `1 ` (no minus), you copied the classical body and `ROT` brought `lo` instead of `hi` — redo the body.

### `.R` / `U.R` / `D.R` — No-Truncation Per §6.2.0210

DPANS94 §6.2.0210 `.R`: "*If the number of characters required to display ud is greater than n, all digits are displayed with no leading spaces.*"

The DEFWORD body handles this naturally via `SPACES`'s no-op-for-n<=0 behaviour (`src/io.asm:83-91`). Trace `1234 3 .R`:
- `>R S>D R>` → `( 0 1234 3 )` (d = single 1234 zero-extended, width = 3).
- Enter D.R: `>R OVER >R DABS <# #S R> SIGN #>` → `( c-addr 4 ; R: 3 )` (4-char string "1234").
- `R> OVER -` → `( c-addr 4 3 4 )` → `( c-addr 4 -1 )` (pad = 3 − 4 = -1).
- `SPACES` on -1 → no-op; stack → `( c-addr 4 )`.
- `TYPE` → emits `"1234"` (4 chars, no truncation, no leading space).

**Don't add an `IF pad > 0 … THEN` guard around `SPACES` — it's redundant.**

### Preservation Boundary — `.S` Keeps `u_to_str` / `num_buf`

`.S` (`src/formatting.asm:262`) is **out of scope** for Story 10.8. It uses `u_to_str` → `div_bc_by_e` → `digit_to_char` → `num_buf`, plus `print_neg_prefix` and `emit_unsigned`. When the `.` / `U.` / `.R` DEFCODEs are deleted, these helpers look unused — **do not delete them**. They are still called from:

- `.S`: `u_to_str` (line 284), `emit_unsigned` via `.dots_print_signed` (line 359), `print_neg_prefix` (line 358).
- Pictured `#`: `digit_to_char` (`pictured.asm:99`).

The canonical regression signal: after the Task 2 deletions, run `1 2 3 .S` before adding any new DEFWORD bodies. If it fails, a helper was deleted prematurely; restore it before proceeding. The helpers are designed to be shared — they are not an "old path" to be cleaned up by this story.

A future story *could* rewrite `.S` on top of pictured output and retire `u_to_str` / `num_buf` / `emit_unsigned` / `div_bc_by_e` (saving ~90 bytes). That story is **not 10.8** and is not on the Epic-10 plan.

### Correctness Traps (by word)

**`.`:**

- No trap beyond the factoring path. `S>D` handles sign-extension correctly across `-1`, `$8000`, and `$FFFF`.

**`U.`:**

- E10-D1 trap: after `0 SWAP`, stack is `( 0 u )` (hi=0, lo=u, lo on TOS). **Don't** swap to `( u 0 )` — that would pass `u * 65536` as the double to `D.`. The test `65535 U.` → `65535 ` catches this immediately (if you got it wrong, you'd see `4294901760 `).

**`D.`:**

- **HIGH-cell-drives-SIGN trap** — see §E10-D1 Byte-Order above. Use `OVER >R` to preserve `hi`, **not** `TUCK`.
- **DABS($80000000) corner** — DABS's own trap (from Story 10.4): $80000000 is its own absolute value (|INT_MIN| is unrepresentable in 32-bit signed, so DABS returns $80000000 unchanged with bit 31 still set). The subsequent `#S` emits digits of $80000000 interpreted as unsigned = 2147483648; then SIGN fires on the original HIGH cell (`$8000`, bit 15 set) → HOLD `'-'`. Final output: `-2147483648 `. This is the correct ANS behaviour for INT_MIN. Test `HEX 8000 0 D. DECIMAL` (AC #15).

**`.R`:**

- Factored through `D.R`; no trap beyond the S>D composition.

**`U.R`:**

- E10-D1 trap as for `U.` — after `>R 0 SWAP R>`, stack is `( 0 u +n )`. Verified by `65535 10 U.R` → 5 spaces + `65535`.

**`D.R`:**

- All three `D.` traps apply (high-cell sign, DABS($80000000)).
- **Two >R / R> pairs** — one for `+n`, one for `hi`. The inner pair (for `hi`) is consumed before `SIGN`; the outer pair (for `+n`) is consumed before `OVER - SPACES TYPE`. Verify R-stack discipline: each `>R` pairs with exactly one `R>` on every code path. No ABORT mid-body; the only exit is the trailing `EXIT_CODE`.
- **Width arithmetic** — `R> OVER - SPACES`: `+n` comes off the R-stack to TOS, `OVER` duplicates `u` from second-from-top, `-` computes `+n − u`. `SPACES` no-ops on ≤0.

### Stories 10.2–10.7 Carry-Forwards

From `_bmad-output/implementation-artifacts/10-{2..7}-*.md`:

1. **CCD-3 template locked.** Format: `; ANS Forth 1994 §<n>   <word>   — <note>`. For Forth-2014 additions: `; Forth 2014 §<n>   <word>   — <note>`. `.R` at §6.2 uses the DPANS94 Core Extension line (not Forth 2014).
2. **No new underflow helpers.** AC #9 verifies the factor chain guards every DEFWORD entry. No `(?1)` / `(?2)` / `(?3)` needed here.
3. **`src/double.asm` / `src/formatting.asm` style precedent.** Opening comment, per-word section separator, CCD-3 + stack-effect header, `w_NAME:` / `DEFWORD` / `w_NAME_body:` / `w_NAME_cf EQU w_NAME_body - 3` idiom. See `feedback_defword_cf_label.md` — for DEFWORDs, `w_XXX_cf = w_XXX_body - 3` points at the macro-generated `JP DOCOL`, NOT at the body's first cell.
4. **Tests live in dedicated files.** `tests/core_gap_tests.fth` is new; use the `tests/pictured_tests.fth` banner/section style.
5. **Makefile test numbering contiguous.** Post-10.7 max = **578**; start at **579**.
6. **Different-LLM code-review expected.** Story 10.8's attack surfaces (E10-D1 byte-order, .R no-truncation, .S preservation, DABS($80000000) corner) are all canonical defect sites. Assume your self-review missed something.
7. **Makefile `$$` escaping + `printf --` discipline** — hex literals in banners need `$$`; REPL inputs beginning with `-` need `printf --`.
8. **§-number write-time verification non-negotiable** — the epic's §6.1.0310 for `.R` is the known typo. `docs/ans-forth-core-compliance.md:334` and forth-standard.org agree on §6.2.0210.

### Early-Binding Standard-Compliance Check

Epic AC #4 asks for `HOLD` redefinition to leave `.` unaffected. Antforth's implementation is doubly safe:

1. **Threaded-body early binding.** `.`'s DEFWORD body (`S>D D. EXIT`) contains the xt (`w_D_DOT_cf`) of `D.`, resolved at kernel-build time. Similarly `D.`'s body contains `w_PIC_SIGN_cf`, `w_PIC_HASH_S_cf`, etc. User-level Forth `:` definitions append new entries to the dictionary but **do not rewrite already-compiled threaded bodies**. Re-defining `HOLD` inserts a new entry above the original in the hash chain; `.`'s body still points to the original xts.

2. **Direct Z80 `CALL` inside DEFCODE primitives.** `#` (`pictured.asm:100`) and `SIGN` (`pictured.asm:167`) emit `CALL hold_common` — a literal Z80 opcode resolving to the helper's address at assembly time. The user dictionary's `HOLD` entry is **never consulted** by these primitives. Even if the threaded-body path were late-binding (it isn't), the pictured primitives would still bypass the user dictionary.

Test `: HOLD DROP ; 42 .` → `42 `. Pre-edit: trivially passes (current `.` uses `u_to_str`, never touches `HOLD`). Post-edit: still passes because the DEFWORD body uses pictured primitives that `CALL hold_common` directly. The test confirms both pre- and post-edit behaviour — AC #8 is a positive-evidence regression gate.

### Project Structure Notes

- **Files modified:**
  - `src/formatting.asm` (EDIT — delete 3 DEFCODEs + 3 scratch vars; add 6 DEFWORDs).
  - `tests/core_gap_tests.fth` (NEW — REPL-piped Forth test file).
  - `Makefile` (EDIT — new `test-repl` entries 579..~601).
  - `docs/ans-forth-core-compliance.md` (EDIT — `.R` source ref update, `U.R` / `D.` / `D.R` flipped to implemented, §6.2 bonus counter +1, §8.6 prose delta, date header).
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` (EDIT — status transitions handled by dev-story workflow).
  - `_bmad-output/implementation-artifacts/10-8-number-output-words-on-pictured-foundation.md` (THIS FILE — Dev Agent Record + Completion Notes at close).
- **No files created** beyond `tests/core_gap_tests.fth`.
- **No files deleted.**
- **Alignment with unified structure:** all edits sit in established homes per `architecture.md:434-447`. `src/formatting.asm` is the sanctioned number-display file; the six words remain there. No source-tree structural change.
- **Detected conflicts or variances:** one — the epic spec at `epics.md:620` cites `§6.1.0310` for `.R`, but the authoritative reference (`docs/ans-forth-core-compliance.md:334` + forth-standard.org) is `§6.2.0210`. Dev must use §6.2.0210 in the source citation and surface the typo in the Dev Agent Record (precedent: Story 10.7's HOLDS §6.2.1625 typo at `10-7-pictured-numeric-output-primitives.md:416`).

### References

- **Authoritative standard:**
  - DPANS94 §6.1.0180 `.` — print signed number, free-field
  - DPANS94 §6.1.2320 `U.` — print unsigned, free-field
  - DPANS94 §8.6.1.1060 `D.` — print signed double, free-field (Double-Number set)
  - DPANS94 §6.2.0210 `.R` — print signed, right-aligned (Core Extension; epic's §6.1.0310 is a typo)
  - Forth 2014 §6.2.2330 `U.R` — print unsigned, right-aligned (Core Extension)
  - DPANS94 §8.6.1.1070 `D.R` — print signed double, right-aligned (Double-Number set)
  - DPANS94 §6.1.2220 `SPACES` — no-op for n ≤ 0 (AC #3 depends on this)
  - **Verify all §-numbers at implementation time** against `docs/ans-forth-core-compliance.md` and forth-standard.org before committing comments (NFR17/CCD-3, `feedback_systematic_reference_check.md`).
- **Planning artefacts:**
  - `_bmad-output/planning-artifacts/epics.md:602-624` — Story 10.8 epic spec (note §6.1.0310 typo for `.R`)
  - `_bmad-output/planning-artifacts/epics.md:574-600` — Story 10.7 spec (upstream producer)
  - `_bmad-output/planning-artifacts/epics.md:426-448` — Epic 10 overview
  - `_bmad-output/planning-artifacts/architecture.md:246-264` — E10-D1 / E10-D2 / E10-D3 decisions
  - `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 Standards-Citation Discipline
  - `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 Per-Epic Benchmark Gate (Story 10.10, not here)
  - `_bmad-output/planning-artifacts/architecture.md:434-447` — Source-file organisation table (formatting.asm is the home)
  - `_bmad-output/planning-artifacts/prd.md` — FR13 (pictured output wordset consumed), NFR5 (ROM size), NFR9 (regression), NFR10 (Core compliance), NFR17 (standards citations)
- **Precedent stories:**
  - `_bmad-output/implementation-artifacts/10-7-pictured-numeric-output-primitives.md` — **closest precedent**; delivered the foundation, set the `pic_buf` + `HLD` machinery, established adversarial self-review trap-table format, Makefile `$$` / `printf --` discipline
  - `_bmad-output/implementation-artifacts/10-4-double-precision-arithmetic-additive-sign-compare-mixed.md` — DABS semantics including the $80000000 corner
  - `_bmad-output/implementation-artifacts/10-3-single-double-conversions.md` — S>D sign-extension pattern
  - `_bmad-output/implementation-artifacts/10-2-double-cell-stack-foundation.md` — E10-D1 byte-order convention
  - `_bmad-output/implementation-artifacts/10-1-ans-core-compliance-gap-survey-and-implementation-plan.md` — authoritative gap list + §-number table
- **Source-tree anchors:**
  - `src/formatting.asm:11-18` — `digit_to_char` (shared with pictured `#`; keep)
  - `src/formatting.asm:27-41` — `div_bc_by_e` (used by `u_to_str` → `.S`; keep)
  - `src/formatting.asm:55-79` — `u_to_str` (used by `.S`; keep)
  - `src/formatting.asm:92-107` — `print_neg_prefix` (used by `.S`; keep)
  - `src/formatting.asm:118-126` — `emit_unsigned` (used by `.S`; keep)
  - `src/formatting.asm:132-147` — `w_DOT_cf` DEFCODE (delete, replace with DEFWORD)
  - `src/formatting.asm:155-166` — `w_U_DOT_cf` DEFCODE (delete, replace)
  - `src/formatting.asm:175-247` — `w_DOT_R_cf` DEFCODE (delete, replace)
  - `src/formatting.asm:249-251` — `.dotr_neg` / `.dotr_str` / `.dotr_len` scratch (delete with DEFCODE)
  - `src/formatting.asm:262-363` — `w_DOT_S` DEFCODE (`.S`; **preserve unchanged**)
  - `src/formatting.asm:365-389` — `w_HEX` / `w_DECIMAL` DEFWORDs (structural reference for DEFWORD pattern in this file)
  - `src/double.asm:155-170` — `w_S_TO_D_cf` (S>D)
  - `src/double.asm:288-310` — `w_D_ABS_cf` (DABS), including the $80000000 preservation comment
  - `src/pictured.asm:37-48` — `w_PIC_LESS_HASH_cf` (<#)
  - `src/pictured.asm:112-123` — `w_PIC_HASH_S_cf` (#S)
  - `src/pictured.asm:131-151` — `w_PIC_GREATER_HASH_cf` (#>)
  - `src/pictured.asm:160-170` — `w_PIC_SIGN_cf` (SIGN)
  - `src/pictured.asm:220-238` — `hold_common` helper (direct-CALL target; isolates `HOLD` from user redefinition)
  - `src/stack_ops.asm:27` / 48-75 / 248-280 — DUP / SWAP / OVER / ROT / >R / R>
  - `src/arithmetic.asm:68-80` — `w_MINUS_cf` (−)
  - `src/io.asm:23-108` — TYPE / SPACE / SPACES (SPACES at :83 is no-op for n ≤ 0 — AC #3)
  - `src/macros.asm:60-127` — DEFCODE / DEFWORD / DEFIMMED macros
  - `src/antforth.asm:234` — `num_buf` (preserve; used by `u_to_str` → `.S`)
- **Test-tree anchors:**
  - `tests/pictured_tests.fth:1-16` — banner style template for `tests/core_gap_tests.fth`
  - `tests/double_tests.fth` — alternative precedent
  - `Makefile:4971-5023` — Story 10.7 review-pass test-repl block (574..578) = canonical entry format for appending to
- **Compliance doc (all edits in `docs/ans-forth-core-compliance.md`):**
  - line 46 — Epic-10 closure-plan row for 10.8
  - line 334 — `.R` row (update source ref)
  - line 350 — `U.R` "Will gain via Epic 10" row
  - lines 368-369 — `D.` / `D.R` §8.6 rows
  - line 330 — §6.2 bonus counter
  - line 372 — §8.6 prose
  - date header
- **Project memories applicable:**
  - `feedback_systematic_reference_check.md` — cross-reference DPANS94/compliance doc (AC #11; epic's §6.1.0310 for `.R` is the trap)
  - `feedback_standards_compliance.md` — investigate the standard; never rationalise
  - `feedback_adversarial_review.md` — reviews MUST find things (Task 8; Story 10.7 trap-table precedent)
  - `feedback_plain_qa_language.md` — diagnostic Completion Notes
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth scripts (AC #4, Task 4)
  - `feedback_follow_process.md` — execute the workflow without asking for permission for obvious next steps
  - `feedback_defword_cf_label.md` — `w_XXX_cf EQU w_XXX_body - 3` for DEFWORDs (non-negotiable). All six new bodies use this idiom.
  - `project_tos_in_register.md` — BC-as-TOS / DE-as-IP discipline; DEPTH convention. DEFWORDs don't need to worry about BC-as-TOS directly — the factor primitives handle it; but the underflow-chain reasoning (AC #9) depends on knowing the DEPTH semantics.
  - `project_epic5_scope.md` — (reference only — Epic 5 retired)

### Project Structure Notes

- Alignment with unified project structure: story file lives in `_bmad-output/implementation-artifacts/` per `config.yaml:implementation_artifacts`. The edit target `src/formatting.asm` is the sanctioned number-display file per `architecture.md:442`. The new `tests/core_gap_tests.fth` mirrors the convention of one dedicated `tests/*_tests.fth` per subsystem (same as `tests/double_tests.fth`, `tests/pictured_tests.fth`).
- No detected conflicts with unified structure beyond the epic §-number typo noted above.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context) via Claude Code / BMAD dev-story workflow.

### Debug Log References

- Pre-edit baseline build: `make asm` → `build/antforth.com` = 16209 bytes (matches post-10.7 baseline per `10-7-pictured-numeric-output-primitives.md:558`).
- Post-edit build: `make asm` → 16202 bytes (delta −7).
- Pre-edit `make test-repl`: all 578 existing tests pass.
- First post-edit `make test-repl`: 1 failure (test 573 — `HLD @ <# HLD @ = .` no longer returned `-1` because the startup banner's `U.` now goes through pictured output and mutates HLD before the REPL prompt). See Completion Notes §Test 573 amendment for the fix.
- Post-fix `make test-repl`: 620 passing, 0 failing (587 pre-existing + 33 new Story-10.8 entries 579–611).
- Smoke traces used during development (verbatim REPL output):
  - `-1 -1 D.` → `-1 ` (confirms high-cell-drives-SIGN per E10-D1).
  - `0 -1 D.` → `65535 ` (confirms E10-D1 low-on-TOS — would be `4294901760 ` if the byte-order were flipped).
  - `32768 0 D.` → `-2147483648 ` (INT_MIN corner; DABS($80000000) is fixed-point, SIGN still fires).
  - `1234 3 .R` → `1234` (no-truncation per §6.2.0210; SPACES(-1) no-ops).
  - `: HOLD DROP ; 42 .` → `42 ` (early-binding check holds).
  - `1 2 3 .S` → `<3> 1 2 3 ` (u_to_str / num_buf preserved).
- Assembly regression: `make test` → PASS (embedded test bridge unchanged).

### Completion Notes List

**Summary.** Story 10.8 rebuilds the six Forth number-display words atop the pictured-output primitives from Story 10.7. `.` / `U.` / `.R` are preserved byte-for-byte; `D.` / `U.R` / `D.R` land as new §6.2 / §8.6 bonus coverage. The rewrite replaces ~164 bytes of hand-rolled DEFCODE with six thin DEFWORD threaded bodies. Net ROM change: −7 bytes.

**§-number discipline (AC #5, #11).** Every new DEFWORD carries a verified ANS / Forth-2014 citation:
- `.` §6.1.0180
- `U.` §6.1.2320
- `D.` §8.6.1060
- `.R` §6.2.0210 (epic spec's §6.1.0310 is a drafting typo — §6.1.0310 is actually `2!`. Source cites §6.2.0210 per `docs/ans-forth-core-compliance.md:334` and forth-standard.org; a header comment in `src/formatting.asm` records the typo inline so copy-paste cannot re-introduce it — Story 10.7 HOLDS-typo precedent.)
- `U.R` §6.2.2330 (Forth 2014 Core Extension)
- `D.R` §8.6.1070

Style matches `src/double.asm` — `ANS Forth 1994 §X.Y.ZZZZ   <word>   — <note>` (no extra period between the 1. and the word-number part of §8.6 refs).

**E10-D1 byte-order (AC #6).** The high cell drives `SIGN`. Body template for `D.`:
`OVER >R DABS <# #S R> SIGN #> TYPE SPACE`. The `OVER >R` pair preserves `hi` across `DABS` so it can re-enter `SIGN` with `hi` on TOS — the classical `TUCK … ROT` body would surface `lo` to `SIGN` instead and is wrong for this convention. Regression guard: test 594 (`-1 -1 D.` → `-1 `) would fail as `4294967295 ` if the body were flipped.

**INT_MIN / DABS($80000000) corner (AC #15).** `32768 0 D.` → `-2147483648 `. DABS of $80000000 returns $80000000 unchanged (fixed-point, per Story 10.4); digit emission treats $80000000 as unsigned 2147483648; `SIGN` still fires because hi = $8000 has bit 15 set; trailing `TYPE SPACE` yields `-2147483648 `. This is the ANS behaviour. Covered by test 597.

**.R / D.R no-truncation (AC #3).** `1234 3 .R` → `1234` with no leading space and no digits dropped. `SPACES` is a no-op for `n ≤ 0` (`src/io.asm:83-91`), so the body's `OVER - SPACES` path naturally handles `u > +n` without an explicit `IF pad > 0 … THEN` guard. Covered by tests 591, 592, 602.

**.S / num_buf / u_to_str preservation (AC #7).** `w_DOT_S` at `src/formatting.asm:276` still uses `u_to_str` → `div_bc_by_e` → `digit_to_char` → `num_buf` and `print_neg_prefix` / `emit_unsigned`. Those helpers look unused after deleting `.` / `U.` / `.R` DEFCODEs, but `.S` and pictured `#` still call them — they must be kept alive. Test 605 (`1 2 3 .S` → `<3> 1 2 3 `) is the preservation gate. A future story could rewrite `.S` on pictured output and retire the helpers (~90 bytes saved); explicitly out of scope for 10.8.

**Early-binding HOLD-redefinition (AC #8).** `: HOLD DROP ; 42 .` → `42 `. Antforth's protection is doubly belt-and-braces:
1. `.`'s DEFWORD body compiles the xt of `D.` at kernel-build time; `D.` compiles xts of `<#`, `#S`, `SIGN`, `#>` similarly. User-level `: HOLD … ;` inserts a new dictionary entry but does not rewrite already-compiled threaded bodies.
2. The pictured DEFCODE primitives (`#`, `HOLD`, `SIGN`, `HOLDS`) emit literal `CALL hold_common` — a Z80-level helper address resolved at assembly time. The dictionary's `HOLD` entry is never consulted by those primitives. Even if the threaded-body path were late-binding (it isn't), the pictured primitives would still bypass the user dictionary.

Test 604 is the positive-evidence regression gate.

**Underflow-chain parity (AC #9).** The six DEFWORDs do not add any new `(?N)` guard word. Every entry reaches an underflow-checked factor primitive before any observable state mutation:
- `.` / `U.`: first body word is `S>D` / `LIT,0,SWAP`; `S>D` guards 1 cell, `SWAP` guards 2 cells.
- `D.`: first body word is `OVER` — 2-cell guard.
- `.R` / `U.R`: first word is `>R` (no guard) but `>R` pops to R-stack; the next body word is `S>D` or `LIT,0,SWAP` which guards the remaining stack. If initial DEPTH < 2, `>R` pops fine but then the `S>D` / `SWAP` guard trips, ABORT resets both stacks, and no pictured state has been mutated (`<#` hasn't been called yet).
- `D.R`: first body word is `>R` (pops `+n` to R-stack), then `OVER` (2-cell guard on `( hi lo )`). If DEPTH was initially < 3 the `OVER` trip aborts before DABS runs; ABORT's stack reset cleans up the R-stack entry for `+n`.

No new `(?N)` DEFCODE is introduced; the factor chain covers every case. Tests 606–611 exercise each of the six words at its exact-underflow depth.

**Test 573 amendment.** Pre-10.8, `HLD @ <# HLD @ = .` returned `-1` because `.` (DEFCODE) never touched HLD — the startup banner's `U.` used `u_to_str` / `num_buf`, leaving HLD unchanged at its cold-start sentinel. Post-10.8, the banner's `U.` goes through pictured output (`<# #S #> TYPE`) which resets HLD; when the user's first `HLD @` runs, it reads the value left over from the banner's `#>` — no longer equal to the sentinel. The test's true invariant is "`<#` is idempotent" (two consecutive `<#` yield the same HLD). Rewrote as `<# HLD @ <# HLD @ = .` → `-1 ok`, preserving the original intent. Updated both `Makefile` (test 573) and `tests/pictured_tests.fth`.

**ROM delta.** Pre-edit `build/antforth.com` = 16209 bytes (post-10.7 baseline). Post-edit = 16202 bytes. Net **−7 bytes**. Within the spec's ±40-byte estimate; direction is slightly negative (favours NFR5). Breakdown: ~164 bytes of DEFCODE bodies and scratch removed; ~82 bytes of threaded cells added for six DEFWORDs; ~36 bytes for three new dictionary entries (`D.`, `U.R`, `D.R`); `JP DOCOL` overhead per DEFWORD reuses the space that held DEFCODE entry labels for `.` / `U.` / `.R`.

**Compliance doc refresh (AC #13).**
- Date header → 2026-04-23 (Story 10.8 refresh).
- §6.2 bonus counter 10 → 11 (adds `U.R`; `.R` already counted).
- `U.R`, `D.`, `D.R` rows marked `10.8 ✓ Implemented` with source line references.
- `.R` row source ref updated from `formatting.asm:174` → `formatting.asm:203`.
- §8.6 prose updated: all 13 Epic-10 additions now implemented.
- §6.1 Summary (129/133 = 97.0%) **unchanged** — all Story-10.8 deltas are §6.2 / §8.6.

**Adversarial trap-table (AC #15).**

| Trap / attack surface | Guard test | Status |
|---|---|---|
| `.` / `U.` / `.R` byte-for-byte regression vs pre-10.8 | tests 579–592 + all earlier banner / number tests | PASS — output identical |
| E10-D1 byte-order (high-cell-drives-SIGN) | test 594 `-1 -1 D.` → `-1 ` | PASS |
| E10-D1 byte-order (low-on-TOS sanity) | tests 595, 587, 599 (65535 family) | PASS |
| DABS($80000000) INT_MIN fixed-point corner | test 597 `32768 0 D.` → `-2147483648 ` | PASS |
| `.R` / `U.R` / `D.R` no-truncation (u > +n) | tests 591, 592, 602 | PASS |
| `.S` / `u_to_str` / `num_buf` preservation | test 605 `1 2 3 .S` → `<3> 1 2 3 ` | PASS |
| Early-binding HOLD redefinition | test 604 `: HOLD DROP ; 42 .` → `42 ` | PASS |
| Underflow chain — factor primitives guard every entry | tests 606–611 (one per word) | PASS — `? Stack underflow` + REPL recovery |
| HEX/DECIMAL discipline through pictured output | tests 584, 588, 596 | PASS |
| HLD side-effect (banner U. now touches HLD) | test 573 amended to `<# HLD @ <# HLD @ = .` | PASS — invariant preserved |
| Pictured-path reachability (user recipe matches `.`) | test 603 DOT-VIA-PICT | PASS — byte-identical to `1234 .` |
| ROM delta direction | −7 bytes vs 16209 baseline | Within ±40 target |
| §-number citations verified at write time | grep `src/formatting.asm` vs `docs/ans-forth-core-compliance.md` | All six citations match the compliance doc |
| Epic-spec `.R` §6.1.0310 typo | Called out in `src/formatting.asm` DEFWORD comment and Dev Notes | Documented, not re-introduced |

**Assumption to flag for review.** The spec's AC #15 literal probe `HEX 8000 0 D. DECIMAL` expects `-2147483648 ` — but with HEX active during `D.`, the actual output is `-80000000 ` (hex). I interpreted the intent as "construct INT_MIN, then display in decimal" and covered it via `32768 0 D.` (same double value, BASE=10 active). I also spot-checked `HEX 8000 0 DECIMAL D.` which also yields `-2147483648 `. If a reviewer prefers the original literal, the test would need to read as `HEX 8000 0 DECIMAL D.` (DECIMAL moved before `D.`).

**Review follow-ups (2026-04-23 adversarial pass, fixed in-place).** Six medium/low findings from a code-review read were closed out as part of Task 10:

- **M1 — D.R × INT_MIN corner unit-gated.** The trap-table originally claimed INT_MIN coverage via test 597, but 597 is `D.`, not `D.R`. The `32768 0 15 D.R → 4 spaces + -2147483648` case existed only in `tests/core_gap_tests.fth:58`, not in the authoritative Makefile runner. Added as test **612**. Exercises DABS($80000000) fixed-point + SIGN on hi + R-stack width arithmetic in one probe.
- **M2 — D. typical-positive leg thin.** 593..597 cover zero, `-1 -1` negative, `0 -1` (prints as unsigned 65535), HEX, and INT_MIN. Added test **613** `0 12345 D. → 12345 ` for a plain positive double in BASE=10.
- **M3 — §-number rendering mismatch.** AC #5 literal used the DPANS94 4-part form (`§8.6.1.1060`) but the source and compliance doc use the 3-part form (`§8.6.1060`). AC #5 updated to the 3-part form with an explicit parenthetical equating it to the DPANS94 4-part rendering. Source was already correct per AC #11.
- **L1 — Makefile banner off-by-one.** `(579..610)` → `(579..614)` after adding the three new tests.
- **L2 — Degenerate `HEX 255 . DECIMAL` line in `tests/core_gap_tests.fth`.** The parsed value (`0x255` = decimal 597) prints as `255` in HEX base — same as the literal in DECIMAL — so the test didn't distinguish bases. Removed; adjacent `255 HEX . DECIMAL → FF` remains as the real HEX-discipline gate.
- **L4 — Inline underflow-chain comments missing.** Added short `; Underflow:` annotations on the `.R` / `U.R` / `D.R` DEFWORD bodies so the `>R`-unchecked-then-guarded rationale lives next to the code, not only in this story file.
- **L6 — No `.R` negative-width test.** Added `42 -5 .R → 42` (.fth line 38 + Makefile test **614**). Confirms the `SPACES` no-op path handles an out-of-spec `+n < 0` benignly without truncation.

Post-review `make test-repl`: **623 passing, 0 failing** (587 pre-existing + 36 Story-10.8 entries 579..614). Post-review ROM size unchanged at 16202 bytes — no code-size impact from the review edits (comments and Makefile tests only).

### File List

- `src/formatting.asm` (MODIFIED) — deleted DEFCODEs for `.` / `U.` / `.R` (~164 bytes incl. scratch); added DEFWORDs for `D.R` / `D.` / `.` / `U.` / `.R` / `U.R`. `.S`, `HEX`, `DECIMAL`, `digit_to_char`, `div_bc_by_e`, `u_to_str`, `print_neg_prefix`, `emit_unsigned` preserved unchanged.
- `tests/core_gap_tests.fth` (NEW) — Forth-source REPL tests covering all six words, INT_MIN corner, no-truncation edges, `.S` preservation, early-binding check, pictured-path explicit recipe, underflow parity.
- `Makefile` (MODIFIED) — added 33 new `test-repl` entries 579–611 for Story 10.8; amended test 573 to match the new HLD side-effect surface (banner `U.` now touches HLD).
- `tests/pictured_tests.fth` (MODIFIED) — updated the HLD smoke test to the `<#`-idempotent form (parallel change to Makefile test 573).
- `docs/ans-forth-core-compliance.md` (MODIFIED) — date header → 2026-04-23; §6.2 bonus counter 10 → 11; `.R` source ref updated to `formatting.asm:203`; `U.R` / `D.` / `D.R` rows marked implemented with source lines; §8.6 prose advanced to "all 13 implemented post-Story-10.8"; Epic-10 closure-plan row for 10.8 marked complete.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MODIFIED) — `10-8-number-output-words-on-pictured-foundation: ready-for-dev → in-progress` (will transition to `review` at story close).
- `_bmad-output/implementation-artifacts/10-8-number-output-words-on-pictured-foundation.md` (MODIFIED — this file) — task checkboxes marked complete; Dev Agent Record / Completion Notes / File List filled; trap-table recorded.

### Change Log

- 2026-04-23 — Story 10.8 implemented. 6 DEFCODE → DEFWORD conversions for `.` / `U.` / `.R`; new DEFWORDs for `D.` / `U.R` / `D.R`. 33 new `test-repl` entries (579–611). Compliance doc refreshed to 11/46 §6.2 bonus + 13/13 §8.6 implemented. ROM delta −7 bytes (16209 → 16202). Test 573 amended to `<#`-idempotent form after banner `U.` now touches HLD.
