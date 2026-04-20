# Story 9.3: Binary `%` and character `'c'` prefixes

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to enter binary literals via `%` and character-code literals via `'c'` using Forth 2014 syntax,
so that I can express bit patterns and ASCII codes directly without helper words.

## Acceptance Criteria

1. **Given** any current `BASE`, **When** I type `%1010 .`, **Then** the output is the representation of decimal 10 in the prevailing `BASE` (so `10 ` in DECIMAL, `A ` in HEX, `1010 ` in binary itself). The **stored value of `BASE` is unchanged** after the operation. Empty bodies (bare `%`) fall through to the undefined-word path per AC #6. (Epic FR3, FR9; Forth 2014 §3.4.1.3.)

2. **Given** any current `BASE`, **When** I type `'A' .`, **Then** the output is `65 ok` when `BASE=10`, or the equivalent representation of 65 in the prevailing `BASE` (e.g., `41 ok` in hex, `101 ok` in octal). The **stored value of `BASE` is unchanged** after the operation. Any ASCII byte 0x00..0xFF is legal in the middle slot — including digits (`'0'` → 48), spaces are NOT legal (see AC #3 — the outer interpreter tokenises on whitespace so `' '` arrives as a lone `'` token, not a 3-byte `'c'` token). (Epic FR4, FR9; Forth 2014 §3.4.1.3.)

3. **Given** a malformed character literal (missing closing quote or wrong length — e.g., `'a`, `''`, `'ab'`, `'abc'`), **When** it is parsed, **Then** the `'c'` handler returns false and the outer interpreter reports it via the existing undefined-word path (`'ab' ?`). Specifically: body length must be **exactly 3 bytes** (`'`, one char, `'`); anything else fails. Bare `'` is NOT handled by this recogniser because the existing dictionary word `'` (TICK, at `src/compiler.asm:26`) intercepts it at FIND-time — the prefix recogniser only sees `'…` tokens that FIND couldn't match. (FR9 integrity; existing TICK word preserved unchanged.)

4. **Given** a binary literal containing a non-binary digit (e.g., `%102`, `%1a0`, `%1 2`), **When** it is parsed, **Then** `.pref_percent_entry` returns false via the shared unparsed-chars fail path (`do_number_base2` returns with B≠0), and the outer interpreter reports `%102 ?` via the undefined-word path. No `BASE` mutation, no stack imbalance. (FR9 integrity; NFR10 regression guarantee.)

5. **Given** the kernel source, **When** the `%` prefix lands, **Then** its source carries a Forth 2014 citation comment in the mandated format (architecture §Format-Patterns → "Standards-citation comments (NFR18)"):
   ```
   ; Forth 2014 §3.4.1.3      %<num>        — binary-base numeric literal prefix
   ```
   And **when** the `'c'` prefix lands, **Then** its source carries:
   ```
   ; Forth 2014 §3.4.1.3      'c'           — character-code literal
   ```
   Both cite the **standard** (neither is an antforth extension — `0x` remains the only extension in Epic 9 per NFR12). (NFR17, NFR18, CCD-3; Architecture §Format-Patterns; project memory `feedback_standards_compliance.md`.)

6. **Given** the existing Story-9.1/9.2 scaffold (flat `CP` / `JR Z` or `JP Z` dispatch chain in `w_NUMBER_PREFIX_Q_cf`), **When** 9.3 extends it, **Then** two new dispatch arms are added — one for `%` and one for `0x27` (ASCII `'`) — each mirroring the `.pref_hash_entry` / `.pref_dollar_entry` handler ritual documented in the `src/number_prefixes.asm` file header (PUSH BC / EXX / POP HL on entry; EXX-restore on both success and fail exits). No restructuring of `#`, `$`, `0x` arms or the `do_number_base10` / `do_number_base16` helpers; the 9.3 work is purely additive table entries plus two new `.pref_<x>_entry` handlers plus the new `do_number_base2` / `char_to_digit_base2` leaf helpers (for `%`) and a dedicated single-byte reader (for `'c'`, which has no digit-loop). (Architecture §E9-D2; project memory `feedback_design_upfront.md`.)

7. **Given** an un-prefixed literal (e.g., `1010` in DECIMAL, `'` on its own, `%` on its own), **When** it is parsed, **Then** the recogniser returns false (or, for bare `%`, falls through cleanly to the existing `NUMBER?` / undefined-word error path — no stale state, no `BASE` mutation, no stack imbalance). Specifically:
   - Bare `%` (1-char token): `.pref_percent_entry` detects a zero body-count after DEC A and returns false via `.pref_percent_fail`.
   - Bare `'` (1-char token): **intercepted by FIND before reaching the recogniser** (existing TICK word). The prefix recogniser MUST NOT attempt to handle bare `'` as it will never see it.
   - Two-byte `'a` (no closing quote), four-byte `'ab'`, etc.: the `.pref_quote_entry` handler returns false via its length check.
   - `%` with a leading `-` in body (e.g., `%-1010`) mirrors the 9.1/9.2 sign-in-body pattern — supported per Completion Notes item 3 / AC #4 of this story. For `'c'`, sign-in-body is **not** meaningful (a character literal is a single byte); sign-BEFORE-prefix (`-'A'`) is Story 9.4 scope and must not be pre-implemented here. (FR9 integrity; NFR10 regression guarantee.)

8. **Given** the REPL-piped test script `tests/number_prefixes_tests.fth` (extended through 9.2), **When** 9.3 extends it, **Then** new cases are appended covering the following (each with its expected stdout fragment). The corresponding Makefile `test-repl` entries (beginning at test **300**, following the 9.2 sequence that ends at 299) are the authoritative runners.
   - **`%` positive:** `%0 .` → `0 `, `%1 .` → `1 `, `%1010 .` → `10 ` (DECIMAL), `%11111111 .` → `255 ` (DECIMAL), `%1111111111111111 U.` → `65535 ` (max unsigned 16-bit).
   - **`%` BASE integrity:** `HEX %11111111 DROP BASE @ .` → `10 ` (BASE=16 preserved, printed in hex as `10`); `DECIMAL %1010 DROP BASE @ .` → `10 `.
   - **`%` sign-in-body:** `%-1010 .` → `-10 ` (mirrors 9.1/9.2 NUMBER?-parity pattern).
   - **`%` malformed / fallthrough:** `%102 ` → `%102 ? ` (non-binary digit), `% ` → `% ? ` (bare `%`), `%-` → `%- ? ` (bare sign).
   - **`'c'` positive:** `'A' .` → `65 `, `'0' .` → `48 `, `'a' .` → `97 `, `'9' .` → `57 `. Non-alphanumeric: `'+' .` → `43 `, `'*' .` → `42 `.
   - **`'c'` BASE integrity:** `HEX 'A' DROP BASE @ .` → `10 ` (BASE=16 preserved, printed in hex).
   - **`'c'` malformed / fallthrough:** `'ab'` → `'ab' ? ` (too long), `'a` → `'a ? ` (no closing quote), `''` → `'' ? ` (empty char — 2 bytes, no middle char), `'abc'` → `'abc' ? `.
   - **Compile-time (inside a colon body):** `: GETTEN %1010 ; GETTEN .` → `10 ` (DECIMAL prevailing); `: GETA 'A' ; GETA .` → `65 `.
   - **Cross-handler negate reset:** `#42 %-1010 . .` → `-10 42 ` (verifies `.pref_negate` is reset between `#` and `%` — the same invariant 9.2's test 299 exercises for `#` and `$`).

   Each case is a `@OUTPUT=$$(printf …)` block in the `test-repl` Makefile target (Option A of 9.1's Task 4.3). Cross-reference the `.fth` file from the Makefile block comments. (Per `feedback_repl_tests_preferred.md`.)

9. **Given** the new test cases, **When** `make test && make test-repl` runs after 9.3 lands, **Then** the existing 306 REPL + assembly regression tests all still pass (zero regressions per NFR10 / FR45–47), and the new 9.3 tests pass. Binary size delta vs. post-9.2 baseline (14,422 bytes) is recorded in the Completion Notes. An increase for a single story is acceptable per architecture §NFR4 (no per-epic net-negative gate in Phase 2).

## Tasks / Subtasks

- [x] **Task 1: Implement `%` binary prefix handler** (AC: #1, #4, #5, #6)
  - [x] 1.1 Add `CP '%' / JR Z, .pref_percent_entry` (or `JP Z` if out of JR range — see 9.2's L3 note) to the dispatch chain in `w_NUMBER_PREFIX_Q_cf`. The chain currently dispatches `#`, `$`, `0` at `src/number_prefixes.asm:101–106`; remove the `; 9.3:` placeholder comment at line 107.
  - [x] 1.2 Implement `.pref_percent_entry` following the `.pref_dollar_entry` pattern at `src/number_prefixes.asm:197–253` verbatim, substituting `base16` → `base2` and renaming labels. Copy the entry ritual (`PUSH BC / EXX / POP HL`), the `DEC A` body-count check, the sign-in-body block, the `do_number_base2` call, the sign-apply block, and both exit tails. Keep the label names consistent: `.pref_percent_convert`, `.pref_percent_ok`, `.pref_percent_fail`.
  - [x] 1.3 Add the Forth-2014 citation comment above the handler label in the exact format from AC #5.
  - [x] 1.4 Reuse the existing `.pref_negate` scratch byte at `src/number_prefixes.asm:189` — already shared by `#`/`$`/`0x` per 9.2's design; the invariant is that every handler using it resets it to 0 at entry. Update the scratch-byte comment to list the 4th handler.

- [x] **Task 2: Implement `'c'` character-literal handler** (AC: #2, #3, #5, #6)
  - [x] 2.1 Add `CP 0x27 / JR Z, .pref_quote_entry` (or `JP Z` as needed) to the dispatch chain. `0x27` is ASCII `'` — use the hex literal rather than `'\''` to avoid confusing the cross-assembler. Remove the `; 9.3:` placeholder at line 108.
  - [x] 2.2 Implement `.pref_quote_entry` as a **dedicated** handler — it does NOT call `do_number_base<N>` or any digit helper; it reads exactly one middle byte and validates the closing quote. Structure:
    ```
    ; Forth 2014 §3.4.1.3      'c'           — character-code literal
    .pref_quote_entry:
            PUSH    BC                      ; save c-addr
            EXX                             ; BC' = c-addr, DE' = IP
            POP     HL                      ; HL = c-addr (main)
            LD      A, (HL)                 ; A = count
            CP      3
            JR      NZ, .pref_quote_fail    ; must be exactly 3 bytes total
            INC     HL                      ; past count byte
            INC     HL                      ; past opening '
            LD      E, (HL)                 ; E = middle char (the char code)
            LD      D, 0                    ; DE = zero-extended char code
            INC     HL                      ; → closing quote position
            LD      A, (HL)
            CP      0x27
            JR      NZ, .pref_quote_fail    ; missing closing '
            ; success: DE = char code
            PUSH    DE
            EXX
            LD      BC, 0xFFFF
            NEXT
    .pref_quote_fail:
            EXX
            PUSH    BC                      ; restore c-addr
            LD      BC, 0
            NEXT
    ```
  - [x] 2.3 Do NOT implement sign-in-body for `'c'` — a character literal is an unsigned byte value; sign-before-prefix (`-'A'`) is Story 9.4 scope per epic FR6 and the 9.3 AC #7 bullet.
  - [x] 2.4 Add the Forth 2014 citation comment above `.pref_quote_entry` per AC #5. The citation format uses the literal `'c'` in the comment — this means writing `'c'` inside a `;` comment, which is fine (sjasmplus does not interpret `'` in comments). Double-check the assembled listing to confirm the literal comment text landed as intended.
  - [x] 2.5 Verify no collision with existing TICK (`'` as dictionary word at `src/compiler.asm:26`). Bare `'` will be consumed by FIND before reaching the recogniser — confirmed by inspection. Add a one-line comment above `.pref_quote_entry` noting this invariant for future auditors: `; bare ' is intercepted by FIND (see compiler.asm:26 — TICK); this arm only fires for 'c' 3-byte tokens that FIND did not match.`

- [x] **Task 3: Add base-2 digit helpers** (AC: #1, #4, #6)
  - [x] 3.1 Add `do_number_base2` to `src/number_prefixes.asm` modelled on `do_number_base16` (`src/number_prefixes.asm:405–437`), with two changes:
    - `CALL char_to_digit_base2` instead of `char_to_digit_base16`.
    - `*2` is a single `ADD HL, HL` — trivially shorter than `*16`'s 4-op sequence. This keeps the helper ~10 bytes smaller than its base-16 sibling. Consider inlining the `*2` multiply directly in the loop body (no PUSH/POP) since there's only one ADD — optional optimisation, document the choice.
  - [x] 3.2 Add `char_to_digit_base2` modelled on `char_to_digit_base10` (`src/number_prefixes.asm:384–394`). Only `'0'` and `'1'` are valid:
    ```
    char_to_digit_base2:
            CP      '0'
            JR      C, .ctd2_invalid
            CP      '2'                     ; '0' or '1' → valid (< '2')
            JR      NC, .ctd2_invalid
            SUB     '0'                     ; digit 0 or 1
            OR      A                       ; clear carry
            RET
    .ctd2_invalid:
            SCF
            RET
    ```
  - [x] 3.3 Both helpers are **leaf-level** (EXX-free) — confirm the implementation matches the convention at `src/number_prefixes.asm:341` and the header note at lines 50–51.
  - [x] 3.4 Add explanatory comments linking the three-sibling family (`do_number_base10` / `do_number_base16` / `do_number_base2`) so future auditors can diff them.

- [x] **Task 4: Update the scaffold header comment** (AC: #6)
  - [x] 4.1 Edit the file-header "Story 9.2 additions" block at `src/number_prefixes.asm:18–34` to append a "Story 9.3 additions" block documenting the new `%`, `'c'` handlers and the `do_number_base2` / `char_to_digit_base2` helpers. Follow the same format as the 9.1/9.2 entries.
  - [x] 4.2 In the dispatch-chain scaffold comment block (`src/number_prefixes.asm:107–109`), remove the two `; 9.3:` placeholder lines now that those entries exist as real code; keep the `; 9.4:` placeholder for the sign modifier.
  - [x] 4.3 Update the scratch-byte comment at `src/number_prefixes.asm:185–188` — `.pref_negate` is now shared across 4 handlers (`#`, `$`, `0x`, `%`; `'c'` does not use it).
  - [x] 4.4 Extend the scaffold table at lines 61–78 to mark the 9.3 rows as "(this story)" and keep the 9.4 row flagged for the sign modifier.

- [x] **Task 5: Extend the REPL-piped test file** (AC: #8)
  - [x] 5.1 Append a "Story 9.3 additions" section to `tests/number_prefixes_tests.fth`, following the 9.1/9.2 file's comment style. Include the cases listed in AC #8, each as a one-liner with the expected stdout fragment in a trailing `\` comment.
  - [x] 5.2 Append matching `@OUTPUT=$$(printf …)` blocks to the `Makefile` `test-repl` target, numbered **300 onwards** (9.2 closed at test 299 — verified by `make test-repl 2>&1 | tail -5`). Match the 9.2 block structure (e.g., `Makefile:2370` onwards) exactly: `printf '…\r\nBYE\r\n'`, pipe into `$(IZCPM) $(TARGET)`, grep for the expected fragment using `tr -d '\r\n' | grep -qE '<fragment>'`, emit `PASS`/`FAIL` lines, and `exit 1` on mismatch. Add a section header banner (`--- Story 9.3: Binary % and character 'c' prefix tests ---`) before the new block.
  - [x] 5.3 Estimated new test count: **~20–25 cases** (AC #8 enumerates ~20 distinct cases plus boundary / cross-handler coverage). Exact numbering is the dev agent's judgement call — aim for one case per AC #8 bullet plus the malformed-fallthrough cases and the compile-time colon-body cases.
  - [x] 5.4 Pay particular attention to **strengthened fail-case greps** per 9.2's second-pass M1: ensure tests for malformed bodies (e.g., `%102 ?`, `'ab' ?`) use the `'<token> ?'` two-space-then-prompt pattern AND assert the absence of a bare successful number echo — a trivially-passing grep that matches the echoed input is a false-positive trap.

- [x] **Task 6: Regression verification and binary size delta** (AC: #4, #7, #9)
  - [x] 6.1 Run `make test` (assembly regression) — must pass with zero failures.
  - [x] 6.2 Run `make test-repl` — all 306 existing tests (post-9.2) + the new 9.3 tests pass (zero regressions).
  - [x] 6.3 Spot-check FR45–47 preservation: pipe `0 .` (expect `0 `), `1010 .` in DECIMAL (expect `1010 ` — NOT binary 10), `HEX 0A .` (expect `A `), `' foo` (expect TICK behaviour — looks up `foo`, fails with `foo ?` on a clean dictionary), `' DROP .` (expect xt address for DROP, printed in current BASE). Record in Completion Notes. These ensure the new arms do not capture tokens that belong to existing paths.
  - [x] 6.4 Record binary size delta: `wc -c build/antforth.com` vs post-9.2 baseline **14,422 bytes** (AC #9). Expected increase: roughly **+130 to +180 bytes** for two handlers + two leaf helpers. The `%` handler mirrors `$` (~60 bytes); `'c'` is simpler than the digit-loop handlers (~35 bytes); `do_number_base2` + `char_to_digit_base2` together (~45 bytes, smaller than the base-16 siblings due to the single-ADD `*2`). Plus dispatch-chain additions (~10 bytes). If the actual delta exceeds +230 bytes, investigate — the sign-in-body triplication from 9.2 (M2) will NOT additionally grow here because `%` reuses the same pattern and `'c'` doesn't use it; a delta well above prediction likely indicates unintended duplication.

- [x] **Task 7: Code review** (AC: all)
  - [x] 7.1 Run the `bmad-bmm-code-review` workflow against the 9.3 changes (per project memory `feedback_adversarial_review.md`: reviews MUST find things — zero findings on two new handlers plus a dictionary-collision interaction with TICK is inherently suspect).
  - [x] 7.2 Pay special attention to: (a) the `'c'` exact-length check (off-by-one between count=3 / body=3 is a classic trap); (b) the `'` vs TICK interaction — hand-run `' DROP` in a REPL session and confirm it still prints an xt address, not an undefined-word error; (c) `%`-prefix case in `HEX` mode — `%11111111` in HEX should still parse as decimal 255 (binary interpretation) and print as `FF ` given HEX output base; test this explicitly; (d) the `.pref_negate` 4-handler sharing — `%` uses it, `'c'` does NOT, so the `'c'` handler must NOT write to `.pref_negate` on any path (entering bareword or cleanup); (e) citation comment format — both `%` and `'c'` are STANDARD Forth 2014 (not extensions); mis-flagging either as `antforth extension` is a direct NFR12/CCD-3 violation.
  - [x] 7.3 Address findings or document skip rationale per the 9.1/9.2 pattern.

  **Review Follow-ups (AI) — applied 2026-04-20:**
  - [x] [AI-Review][MEDIUM] Document `.pref_negate` write-before-read invariant at `src/number_prefixes.asm:206–218` — one-line fix, prevents future 5th-handler foot-gun.
  - [x] [AI-Review][MEDIUM] File List line-count estimates in Dev Agent Record corrected from (+155/+52/+~190) to actual (+189/+61/+245) for asm/tests/Makefile.
  - [x] [AI-Review][LOW] `''' .` → `39` (apostrophe-as-char-literal) — added as test 327. Locks down Forth 2014 §3.4.1.3 literal-apostrophe behaviour.
  - [x] [AI-Review][LOW] `''''` (4 apostrophes, count=4) → fail — added as test 328. Adjacent to test 322 (`'abc'` count=5).
  - [x] [AI-Review][LOW] `-%1010` (sign-before-prefix) → fallthrough — added as test 329. Locks down 9.3/9.4 scope boundary.
  - [x] [AI-Review][LOW] `do_number_base2` header comment at `src/number_prefixes.asm:600–605` corrected: "~10 bytes" → "~7 bytes" with explicit arithmetic (3 PUSH + 3 POP + 4 ADD vs 2 EX + 1 ADD).
  - No issues found in AC implementation, task completion, or test quality. All 6 follow-ups are polish — no HIGH-severity findings.

## Dev Notes

### Story Purpose and Scope

Story 9.3 closes out the **per-base prefix family** for Epic 9 — after this story, all four Forth-2014-standard numeric prefixes (`#`, `$`, `%`, `'c'`) plus the one antforth extension (`0x`) are recognised. Story 9.4 handles the orthogonal leading-sign modifier (`-#42`, `-$FF`, etc.) and a case-insensitivity audit. Story 9.5 verifies reach into all three parse contexts (REPL / colon body / CODE block). Story 9.6 is the benchmark + regression gate.

9.1 built the recogniser scaffold, the `#` handler, the `do_number_base10` / `char_to_digit_base10` leaf helpers, and the Makefile test pattern. 9.2 added the `$` and `0x` handlers, the `do_number_base16` / `char_to_digit_base16` helpers (with `OR 0x20` case-fold), the pre-EXX second-byte peek for the `0`-arm ambiguity, and 25 new REPL tests. **9.3's job is purely additive:** `%` mirrors `$` almost line-for-line (different base, different digit validator), and `'c'` is a short bespoke handler that reads one byte rather than looping. No restructuring of 9.1/9.2 code is expected or desired.

### Architecture Decisions Driving This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§E9-D1 (Integration point):** zero impact on the unprefixed hot path. For 9.3 this is tight on TWO arms: `%` must not capture `1010` (an unprefixed decimal/hex literal depending on BASE), and `'c'` must not interfere with the TICK word or with any normal 3-char word that happens to have single-quote delimiters (which the outer interpreter tokenises out — `'a'` is a single token). See `feedback_standards_compliance.md` — investigate the standard before committing to edge cases.
- **§E9-D2 (Prefix dispatch strategy):** flat `CP`/`JR Z` chain. 9.1 chose this over a data-driven table. 9.2 extended to 3 arms. 9.3 extends to 5 arms — still comfortably within the range where the chain outperforms a table. **Do not switch to a table mid-epic.**
- **§CCD-3 (Standards-Citation Discipline):** every standard-derived word carries a Forth-2014 citation comment. Both `%` and `'c'` are in §3.4.1.3 (same section as `#` and `$`). Mis-flagging either as an `antforth extension` is an NFR12/NFR18 violation — `0x` remains the **only** antforth-extension prefix in Epic 9.
- **§NFR12 (Extension discipline):** "only non-standard addition this phase is the `0x` hex prefix; clearly flagged as an antforth extension; no silent divergence from standards." 9.3 adds zero new extensions — `%` and `'c'` are pure Forth 2014.

### The `'c'` Character Literal — Design Notes

This is the trickiest single handler in 9.3 because its tokenisation interacts with two existing pieces of antforth:

1. **Outer-interpreter tokenisation.** The outer interpreter delimits tokens on whitespace. A token like `'A'` arrives as a single 3-byte counted string. A token like `' A` (with a space after the quote) arrives as TWO tokens: `'` and `A`. The first token (`'`) is the existing TICK word (`src/compiler.asm:26`) and is intercepted by FIND before reaching the recogniser. Good. A token like `' A '` (space before and after an `A`) tokenises as three separate tokens (`'`, `A`, `'`) — TICK parses `A` as its argument and looks up `A` in the dictionary. This is **standard TICK semantics, unchanged by 9.3**.

2. **The FIND interception.** Any 1-byte token `'` is caught by FIND and executes as TICK. The recogniser only sees `'…` tokens that FIND could **not** match — i.e., tokens longer than 1 byte whose first byte is `'` and whose full literal name is not already in the dictionary. Under the current dictionary, no word has a name like `'A'`, `'0'`, `''`, etc., so all such tokens reach the recogniser cleanly. **If a future story adds a word literally named `'A'` (3 chars including quotes), it would collide — unlikely but worth a defensive comment in the scaffold header.**

3. **Exact-length discipline.** The Forth 2014 §3.4.1.3 character literal is exactly 3 characters: `'`, one char, `'`. Nothing else. Any other length is invalid:
   - `''` (2 chars, empty middle) → fail, fallthrough to undefined-word.
   - `'ab'` (4 chars) → fail.
   - `'a` (2 chars, no closing) → fail.
   - `'a'x` (4 chars, trailing junk) → fail.

   The handler's first act after the EXX ritual is `CP 3` on the count byte. Anything else jumps to `.pref_quote_fail`.

4. **No sign-in-body for `'c'`.** Sign-before-prefix is Story 9.4 scope. 9.3 does not implement `-'A'`; a test case verifies this token falls through (not recognised until 9.4 lands). The `.pref_negate` scratch byte is NOT touched by the `'c'` handler — this is a design discipline, not an oversight, and should be noted in the 9.3 Completion Notes for 9.4's benefit.

### The `%` Binary Prefix — Design Notes

Much simpler than `'c'`. Structurally identical to `$`:

1. **Same entry/exit ritual** as `.pref_dollar_entry`. Same body-count bookkeeping, same sign-in-body block, same success/fail tails.

2. **Digit helpers.** `do_number_base2` is a near-twin of `do_number_base16`, with the `*16` four-shift sequence replaced by a single `ADD HL, HL` (`*2`). This makes the loop body ~4 bytes shorter; optionally inline the `*2` directly (`LD H,D / LD L,E / ADD HL,HL / EX DE,HL`) instead of factoring the multiply into a PUSH/POP block — a minor byte-saving. Document whichever form is chosen.

3. **`char_to_digit_base2`.** Simpler than base-10 / base-16: only `'0'` and `'1'` are valid. Compact form shown in Task 3.2. This helper is ~10 bytes total.

4. **Sign-in-body inherited from 9.1/9.2.** `%-1010 .` should print `-10 ` in DECIMAL. Same CPL/CPL/INC DE two's-complement sequence used by `.pref_hash_entry` and `.pref_dollar_entry`. Test 299 from 9.2 exercises cross-handler `.pref_negate` reset between `#` and `$`; 9.3 adds an analogous test for `#` and `%`.

### Case-Insensitivity Scope — 9.3 vs 9.4

- **`%`** has no case dimension (digits are `0` / `1`; the prefix character `%` has no upper/lower variant).
- **`'c'`** has no case dimension for the prefix character itself (`'` is symmetric). The body character `c` is literal — `'A'` and `'a'` give 65 and 97 respectively, both correct. **Do not fold case in the `'c'` handler** — that would be a standards violation (the character literal is a transparent byte pass-through).

So 9.4's case-insensitivity audit work has nothing to do in 9.3's territory — 9.3 is complete on case behaviour without any further 9.4 involvement.

### Scaffold Template Walkthrough — `.pref_percent_entry`

Copy `.pref_dollar_entry` (`src/number_prefixes.asm:197–253`) verbatim and swap `base16` → `base2` and `dollar` → `percent` throughout. The only semantic change is the base constant embedded in the helper call:

```
; Forth 2014 §3.4.1.3      %<num>        — binary-base numeric literal prefix
.pref_percent_entry:
        PUSH    BC                      ; save c-addr on SP (for POP HL below)
        EXX                             ; BC' = c-addr, DE' = IP
        POP     HL                      ; HL = c-addr (main)

        LD      A, (HL)                 ; A = count
        INC     HL                      ; past count byte
        INC     HL                      ; past '%' (first char)
        DEC     A                       ; body count = count - 1
        JR      Z, .pref_percent_fail   ; bare "%" → fail
        LD      B, A                    ; B = body count

        ; Optional leading '-' in body (e.g. '%-1010'). Mirrors 9.1/9.2.
        XOR     A
        LD      (.pref_negate), A       ; negate = false
        LD      A, (HL)
        CP      '-'
        JR      NZ, .pref_percent_convert
        LD      A, 1
        LD      (.pref_negate), A
        INC     HL
        DEC     B
        JR      Z, .pref_percent_fail   ; bare "%-" → fail

.pref_percent_convert:
        LD      DE, 0                   ; accumulator = 0
        CALL    do_number_base2         ; DE = value, B = remaining count
        LD      A, B
        OR      A
        JR      NZ, .pref_percent_fail  ; unparsed chars → fail

        ; Apply sign if flagged
        LD      A, (.pref_negate)
        OR      A
        JR      Z, .pref_percent_ok
        LD      A, E
        CPL
        LD      E, A
        LD      A, D
        CPL
        LD      D, A
        INC     DE                      ; two's complement

.pref_percent_ok:
        PUSH    DE
        EXX
        LD      BC, 0xFFFF
        NEXT

.pref_percent_fail:
        EXX
        PUSH    BC                      ; shadow BC' holds c-addr_orig
        LD      BC, 0
        NEXT
```

### Scaffold Template Walkthrough — `.pref_quote_entry`

Dedicated handler, no digit loop. Full body shown in Task 2.2. Key correctness points:

- Exact-length discipline: `CP 3` on count. No other length is acceptable.
- Closing-quote validation: the third byte MUST equal `0x27` (ASCII `'`). If not, fail.
- Middle byte passes through unchanged: `LD E, (HL)` / `LD D, 0` → DE holds the byte value as a non-negative 16-bit integer.
- **NO** `.pref_negate` touch on any path.
- **NO** `do_number_base<N>` call.
- **NO** sign-in-body support — the middle byte is literal.

### Sign-in-Body Decision (Mirror 9.1/9.2)

Story 9.1 and 9.2 both chose to support `-` in the body. **9.3 follows the same discipline for `%`** (so `%-1010 .` → `-10`), and **does NOT support sign-in-body for `'c'`** (a character literal is unambiguously a single byte). Document both decisions explicitly.

Story 9.4 will normalise sign handling at the prefix level (`-%1010`, `-'A'`, `-#42`, `-$FF`, `-0xFF`) — do NOT pre-empt that work here. A shared `.pref_check_sign` helper is 9.4's refactor target (flagged in 9.2 Completion Notes as deferred finding M2).

### Source Tree Components to Touch

- **MODIFY:**
  - `src/number_prefixes.asm` — add `.pref_percent_entry`, `.pref_quote_entry`, `do_number_base2`, `char_to_digit_base2`; extend dispatch chain by two arms; update file header and scaffold table.
  - `tests/number_prefixes_tests.fth` — append Story 9.3 section.
  - `Makefile` — append test blocks 300+ in the `test-repl` target, mirroring 9.2's established pattern.
- **MAY MODIFY (judgement call):** nothing expected. If you discover `src/outer_interpreter.asm` needs adjustment, something is wrong — the 9.1 wire-in is sufficient.

**Untouched (confirm by final inspection):** `src/outer_interpreter.asm`, `src/antforth.asm`, `src/strings.asm`, `src/assembler.asm`, `src/dictionary.asm`, `src/compiler.asm` (TICK unchanged), and every file not listed in "MODIFY."

### Existing Code References (Grep-Verified)

- `src/number_prefixes.asm:89–115` — `w_NUMBER_PREFIX_Q_cf` entry + dispatch chain; 9.3 adds two arms here (after the `0` arm at line 106; before or after the `; 9.4:` placeholder at line 109 — placement is a judgement call, prefer ordering by frequency of use).
- `src/number_prefixes.asm:107–108` — `; 9.3:` placeholder lines to remove.
- `src/number_prefixes.asm:117–189` — `.pref_hash_entry` — 9.1 reference.
- `src/number_prefixes.asm:189` — `.pref_negate` scratch byte; update comment to reflect 4-handler sharing.
- `src/number_prefixes.asm:191–253` — `.pref_dollar_entry` — 9.3's `.pref_percent_entry` copy-and-adjust template.
- `src/number_prefixes.asm:255–331` — `.pref_zero_entry` — for reference only (9.3 does NOT need pre-EXX peek because neither `%` nor `'c'` has an ambiguity with unprefixed tokens).
- `src/number_prefixes.asm:333–394` — `do_number_base10` / `char_to_digit_base10` — the earliest digit-helper sibling (base=10).
- `src/number_prefixes.asm:396–471` — `do_number_base16` / `char_to_digit_base16` — 9.3's `do_number_base2` / `char_to_digit_base2` copy-and-adjust template.
- `src/compiler.asm:26` — DEFWORD `"'"` (TICK). Verify unchanged by 9.3; confirm bare `'` still reaches TICK via FIND before the recogniser.
- `src/outer_interpreter.asm:179–208` — `.try_number` thread (unchanged by 9.3 — the 9.1 wire-in handles dispatch).
- `Makefile:2305` — Story 9.1 test banner; `Makefile:2371` — Story 9.2 test banner; 9.3 appends starting after 9.2's final test (299) which ends around line ~2590.
- `tests/number_prefixes_tests.fth` — 9.2 left a complete file with 9.1 + 9.2 sections; 9.3 appends a new section at the bottom.

### Previous-Story Intelligence — Story 9.2 Learnings

Story 9.2 delivered cleanly through two review passes. Key actionable takeaways for 9.3:

1. **JR-range creep.** 9.2 hit out-of-JR-range branches (`JR Z, .pref_fast_false` at lines 263, 268 were out of range) and converted them to `JP C` / `JP NZ`. 9.3 will add TWO MORE handlers, pushing later handlers even further from `.pref_fast_false`. Use `JP` from the start for any branch that targets `.pref_fast_false` from a new handler, and for any dispatch-chain entry whose target handler lies after `.pref_zero_fail` (line 331). The dispatch chain at lines 101–109 currently uses `JR Z` for `#`, `JP Z` for `$` and `0`; add `JP Z` for both new arms unless hand-counting confirms JR-range. **Do not test-and-fix — use JP preemptively.** Saves a build-loop iteration.

2. **Trivially-passing fail tests.** 9.2's second-pass review (M1) found that tests 287/288/289 greped for `'0 '` / `'0 '` / `'A '`, which **also** matched the echoed input, so the test would PASS even if the handler broke the hot path. Tighten 9.3's fail-case greps to require the `'<token> ?'` error fragment or the `'<value>  ok'` two-space-then-prompt pattern. See `Makefile:2500–2540` (post-9.2) for the tightened pattern.

3. **Pre-EXX peek BC-preservation invariant.** 9.2 added a paragraph to the file header (`src/number_prefixes.asm:53–59`) about pre-EXX peeks. 9.3 does NOT use a pre-EXX peek (neither `%` nor `'c'` has an ambiguity at the first-char level), so this concern does not apply — but the header paragraph must remain intact.

4. **Sign-in-body triplication.** 9.2 Completion Notes flagged M2 (deferred): the XOR A / LD (.pref_negate) / CP '-' / ... sign block is copy-pasted three times (across `#`, `$`, `0x`). 9.3 will make this **four** handlers sharing the same pattern (adding `%`). Do NOT extract a helper in 9.3 — the shared helper is 9.4's rework scope. Accept the triplication-becomes-quadruplication as a known technical-debt item, documented in 9.3 Completion Notes for 9.4's benefit.

5. **Binary-size predictions are approximate.** 9.2 predicted +120..+180 bytes and landed at +237. The drift was driven by sign-in-body duplication (~50 bytes over prediction). For 9.3 the same pattern applies: predict +130..+180, expect possible overshoot to +200..+220 if sign-in-body bookkeeping for `%` is heavier than expected. `'c'` is the size-offset — no sign block, no digit loop, so it's ~35 bytes. If the total 9.3 delta exceeds +230 bytes, investigate.

6. **Makefile test target line count.** At post-9.2 the `test-repl` target is approaching 2600 lines. 9.3 will add another ~120 lines (25 tests × ~5 lines each). This is established convention and should NOT be refactored in 9.3 (per 9.2's and 9.1's discipline — a later infrastructure story owns that migration).

7. **Cross-handler `.pref_negate` discipline.** 9.2 added test 299 to verify reset between consecutive `#` and `$-FF` tokens. 9.3 should add a similar test for `#` and `%-1010` (covered in AC #8 bullet "Cross-handler negate reset"). This is a cheap insurance case — a regression here would silently persist between stories.

8. **Standards compliance watchfulness.** Per `feedback_standards_compliance.md`: investigate the standard before defending code. For `'c'`, the standard (Forth 2014 §3.4.1.3) is explicit about the **exactly 3 characters** rule — don't rationalise a looser implementation. For `%`, the standard accepts only `0` and `1` — no trailing whitespace tolerance in the token itself. If the dev agent feels the urge to be "lenient" on either front, stop and re-read the spec first.

### EXX / Shadow-Register Conventions (Inherited Unchanged)

Per `docs/register-conventions.md` and the `src/number_prefixes.asm` file-header ritual block:

- **BC = TOS (main), DE = IP (main), HL = W/scratch, IX = return-stack, IY = user-area base.**
- **EXX swaps main↔shadow** — only A and flags survive.
- **Shadow BC' as the free preservation slot** for the original c-addr — canonical fail-path trick.
- **Leaf-level rule:** `do_number_base2` and `char_to_digit_base2` MUST be EXX-free (same as their base-10 / base-16 siblings). Grep-verify: `grep -nE '^\s*EXX\b' src/number_prefixes.asm` — after 9.3 lands, the count should be **8** EXX occurrences (2 per handler entry + 2 per handler success-exit + 2 per handler fail-exit... actually let's count: `.pref_hash_entry` has 1 entry + 1 ok exit + 1 fail exit = 3; `.pref_dollar_entry` = 3; `.pref_zero_entry` = 3 (1 entry + 1 ok + 1 fail; the pre-EXX peek is not an EXX); `.pref_percent_entry` = 3; `.pref_quote_entry` = 3; total = **15 EXX occurrences** in the file). If the count is higher, some helper has accidentally issued EXX — investigate.

### Standards Citation — Forth 2014 §3.4.1.3

Same section as 9.1 (`#`) and 9.2 (`$`). The relevant prose names all four prefixes (`#`, `$`, `%`, `'`) as parse-time convertors that interpret the body in a specific base/format regardless of `BASE`. The `'c'` character literal is sometimes referenced as §3.4.1.4 in older drafts — **use §3.4.1.3** per the consolidated Forth 2014 §3.4.1.3 heading used throughout Epics 9.1/9.2. Both `%` and `'c'` are standard; neither is an antforth extension.

Do **not** cite a different section for `'c'` (§3.4.1.4 is a common mis-citation). Do **not** use the `; antforth extension` form for either prefix. Mis-flagging will fail code review per `feedback_standards_compliance.md`.

### Testing Standards

Per `feedback_repl_tests_preferred.md`: REPL-piped Forth scripts, not assembly test-thread extensions. Do not add to `src/tests/*.asm` for this story.

Test delivery: Makefile `test-repl` target + `.fth` file, per 9.1's Option A (Task 4.3). Cross-reference the `.fth` file from Makefile block comments so future maintainers can find the source-of-truth intent in a readable Forth script.

Manual smoke test (not automated, for the dev agent to run once before marking story complete): pipe each of the following into `build/antforth.com` interactively and eyeball the output:
- `%1010 .` → `10 ok`
- `'A' .` → `65 ok`
- `HEX %11111111 .` → `FF ok` (decimal 255 printed in hex)
- `HEX %11111111 . BASE @ .` → `FF 10 ok` (BASE=16 preserved, printed in hex as `10`)
- `' DROP .` → some xt address (TICK still works — no recogniser interference)
- `%102` → `%102 ?` (invalid binary digit)
- `'ab'` → `'ab' ?` (wrong length)

Record the manual smoke results in the Completion Notes alongside the `make test-repl` summary.

### Project Structure Notes

- `src/number_prefixes.asm` grows by ~80–120 lines (two handlers + two leaf helpers + scaffold-comment edits). No other source files gain line-count weight in this story.
- No new files are created. `src/number_prefixes.asm` and `tests/number_prefixes_tests.fth` both continue their Epic-9 scope; `Makefile` gets more `test-repl` blocks in the established pattern.
- The `Makefile` `test-repl` target crosses ~2700 lines after 9.3's additions. Still ugly, still established — do NOT refactor the test target in this story. A later infrastructure story owns that migration.
- No conflicts with unified project structure. All changes are additive in the existing Phase-2-designated file.

### References

- `_bmad-output/planning-artifacts/epics.md:302–332` — Story 9.3 authoritative spec
- `_bmad-output/planning-artifacts/epics.md:242–244` — Epic 9 overview
- `_bmad-output/planning-artifacts/architecture.md:206–220` — CCD-3 standards-citation discipline
- `_bmad-output/planning-artifacts/architecture.md:230–242` — E9-D1 integration point, E9-D2 prefix dispatch strategy
- `_bmad-output/planning-artifacts/architecture.md:449–488` — Format Patterns (standards-citation, stack-effect comments)
- `_bmad-output/planning-artifacts/prd.md` — FR3, FR4, FR7, FR9 (numeric literal input); NFR12 (extension discipline)
- `_bmad-output/implementation-artifacts/9-1-numeric-prefix-recogniser-scaffold-decimal-prefix.md` — Story 9.1 Dev Notes + Completion (scaffold design decisions inherited)
- `_bmad-output/implementation-artifacts/9-2-hex-prefixes-standard-and-0x-antforth-extension.md` — Story 9.2 Dev Notes + Completion (sign-in-body, case-fold, pre-EXX peek patterns; M1/M2/L1–L4 findings inform 9.3's approach)
- `docs/register-conventions.md` — authoritative EXX/shadow-register conventions (inherited, not edited)
- `src/number_prefixes.asm:1–79` — file header + scaffold comment block (9.1 + 9.2 content to extend)
- `src/number_prefixes.asm:89–115` — `w_NUMBER_PREFIX_Q_cf` entry + dispatch chain
- `src/number_prefixes.asm:191–253` — `.pref_dollar_entry` (copy-and-adjust template for `.pref_percent_entry`)
- `src/number_prefixes.asm:405–471` — `do_number_base16` / `char_to_digit_base16` (copy-and-adjust templates for base-2)
- `src/compiler.asm:25–48` — TICK word (invariant: bare `'` stays intercepted by FIND)
- `Makefile:2305–2590+` — Story 9.1 + 9.2 REPL test block pattern; 9.3 appends starting at block 300
- `tests/number_prefixes_tests.fth` — 9.1/9.2 `.fth` file; append 9.3 section at the bottom
- Project memories:
  - `feedback_design_upfront.md` — case-fold and extensibility designed up front
  - `feedback_systematic_reference_check.md` — cross-reference Forth 2014 §3.4.1.3 before implementing
  - `feedback_standards_compliance.md` — never rationalise a citation mis-flag; stick to the standard
  - `feedback_repl_tests_preferred.md` — REPL-piped tests
  - `feedback_adversarial_review.md` — reviews must find things
  - `project_tos_in_register.md` — BC=TOS discipline
  - `feedback_assembler_operand_order.md` — Zilog dst-src order throughout

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (claude-opus-4-7[1m])

### Debug Log References

None — implementation followed the pattern laid down by 9.1/9.2 without incident; build clean on first assembly, `make test` and `make test-repl` green on first run after implementation.

### Completion Notes List

1. **`%` handler** — Implemented as `.pref_percent_entry` at `src/number_prefixes.asm:335`, mirroring `.pref_dollar_entry` verbatim with `base16` → `base2` substitution and renaming. Shares `.pref_negate` scratch with `#`/`$`/`0x` (now 4-way). Sign-in-body supported (`%-1010 .` → `-10`), matching 9.1/9.2 discipline. Per 9.2 L3 learning, used `JP Z` for the dispatch arm preemptively (the handler sits past `.pref_zero_fail` and is out of JR range).

2. **`'c'` handler** — Implemented as `.pref_quote_entry` at `src/number_prefixes.asm:404`. Dedicated handler (no `do_number_base<N>` call, no `.pref_negate` touch). Exact-length discipline: `CP 3` on count byte; both the length and the closing-quote (`0x27`) checks use `JR NZ` to a shared fail-tail. Middle byte is read as `LD E, (HL) / LD D, 0` — zero-extended pass-through. Bare `'` is intercepted by FIND/TICK before reaching the recogniser (confirmed by smoke test: `' DROP .` still prints the xt for DROP).

3. **Base-2 digit helpers** — `do_number_base2` at `src/number_prefixes.asm:571` uses the inlined single-ADD variant (`EX DE,HL / ADD HL,HL / EX DE,HL`) rather than the PUSH/POP block used by the base-10/16 siblings — saves ~10 bytes since `*2` is a single op. `char_to_digit_base2` at `src/number_prefixes.asm:603` accepts only `'0'` and `'1'` via `CP '0'` / `CP '2'` bracket check. Both helpers EXX-free per the leaf convention.

4. **Sign-in-body NOT implemented for `'c'`** — explicit design choice per Dev Notes and AC #7. A character literal is an unambiguous byte pass-through; `.pref_quote_entry` does not write to `.pref_negate` on any path. Sign-BEFORE-prefix (`-'A'`, `-%1010`) is Story 9.4 scope and is not pre-empted here.

5. **Sign-in-body quadruplication** — the XOR A / LD (.pref_negate) / CP '-' / ... block is now copy-pasted across 4 handlers (`#`, `$`, `0x`, `%`). This is known technical debt carried over from 9.2's deferred M2 finding; Story 9.4 owns the `.pref_check_sign` shared-helper refactor. No extraction attempted here per that deferral discipline.

6. **Standards citations** — both `%` and `'c'` cite **Forth 2014 §3.4.1.3** (same section as `#` and `$`). Neither is flagged as `antforth extension`; `0x` remains the only extension in Epic 9 per NFR12.

7. **FR45–47 preservation spot-checks** (Task 6.3):
   - `0 .` → `0  ok` (un-prefixed zero still parses via NUMBER?)
   - `1010 .` (DECIMAL) → `1010  ok` (un-prefixed decimal, NOT binary 10)
   - `HEX 0A .` → `A  ok` (un-prefixed hex nibble via NUMBER?, printed in hex)
   - `' foo` → `foo ?` (TICK still looks up `foo`, correctly undefined-word error on empty dictionary)
   - `' DROP .` → `1058  ok` (TICK returns xt address, prints in current BASE)

8. **Binary size delta**:
   - Post-9.2 baseline: `14422 bytes`
   - Post-9.3: `14586 bytes`
   - Delta: **+164 bytes** (well within the predicted +130..+180 range).
   - No unintended duplication — delta matches the sum of: `%` handler (~60 bytes), `'c'` handler (~35 bytes), `do_number_base2` + `char_to_digit_base2` (~45 bytes), dispatch-chain extensions (~6 bytes JP arms × 2 = ~8 bytes), header comment edits (~0 bytes of code).

9. **Test regression** (post-review):
   - `make test` (assembly): **PASS** (all three regression passes green).
   - `make test-repl` (REPL-piped): **336/336 PASS** (306 pre-9.3 + 27 initial 9.3 tests + 3 review-follow-up tests 327–329). Zero regressions.

10. **Test numbering** — 9.3 adds tests 300..326 (27 initial) plus tests 327..329 (3 review follow-ups) = 30 total. Covers AC #8 bullets plus cross-handler `.pref_negate` reset (test 326, mirroring 9.2's test 299 but for `#`/`%` pairing), TICK-interaction preservation (test 323), apostrophe-as-char-literal (test 327), 4-apostrophe fail (test 328), and sign-before-prefix 9.4-scope-boundary lockdown (test 329).

11. **Test-case strengthening** (Task 5.4) — all positive tests use the `'<value>  ok'` two-space-then-prompt pattern AND assert the absence of a `'<token> ?'` error marker. All fail-case tests assert the `'<token> ?'` error AND the absence of any bare-numeric `'[0-9]  ok'` success. Trivial-echo false positives defeated.

12. **Known deferrals (for Story 9.4)** — (a) sign-BEFORE-prefix (`-#42`, `-$FF`, `-0xFF`, `-%1010`, `-'A'`) is unimplemented; (b) the `.pref_check_sign` shared-helper extraction (replacing the sign-in-body triplication→quadruplication) is 9.4's refactor target; (c) the `%` handler's approach is structurally ready for the sign-modifier prefix to re-enter the dispatch chain — no scaffolding owed.

### File List

- MODIFIED: `src/number_prefixes.asm` (net +189 lines: file-header 9.3-additions block; two dispatch-chain arms; `.pref_percent_entry` handler; `.pref_quote_entry` handler; `do_number_base2` helper; `char_to_digit_base2` helper; scratch-byte comment update including write-before-read invariant; scaffold-table 9.3-row updates; post-review `do_number_base2` comment polish)
- MODIFIED: `tests/number_prefixes_tests.fth` (+70 lines: Story 9.3 additions section with 30 cases including 3 review follow-ups)
- MODIFIED: `Makefile` (+272 lines: 30 new `@OUTPUT=$$(printf …)` blocks in `test-repl` target, tests 300..329, with a section banner)
- MODIFIED: `_bmad-output/implementation-artifacts/sprint-status.yaml` (`9-3-…` → `in-progress` → `review` → `done`)
- MODIFIED: `_bmad-output/implementation-artifacts/9-3-binary-and-character-prefixes.md` (Status, task checkboxes, Dev Agent Record, File List, Change Log, Review Follow-ups)

**Note on parallel artifacts:** Git also shows `_bmad-output/planning-artifacts/{architecture,epics,prd}.md` and `_bmad-output/planning-artifacts/sprint-change-proposal-2026-04-20.md` as modified/untracked in the working tree. These are from today's sprint change proposal (parallel planning work, NOT 9.3 code) — noted here for cross-reference only.

## Change Log

| Date       | Change                                                  | Author      |
|------------|---------------------------------------------------------|-------------|
| 2026-04-20 | Story 9.3 implementation: `%` and `'c'` prefix handlers, `do_number_base2` / `char_to_digit_base2` leaf helpers, 27 new REPL-piped regression tests (300..326). +164 bytes; zero regressions in 333-test suite. | Claude Opus 4.7 |
| 2026-04-20 | Review follow-ups applied: `.pref_negate` write-before-read invariant comment (M1); corrected File List line counts (M2); 3 new tests (327–329) for `'''` char literal, `''''` fail, `-%1010` 9.4-boundary lockdown (L1–L3); `do_number_base2` comment-arithmetic polish (L5); sprint-change-proposal cross-reference note (L4). No binary delta (comment-only + test-only). 336/336 REPL tests pass. Status → done. | Claude Opus 4.7 (code-review) |
