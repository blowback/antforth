# Story 9.4: Leading `-` sign and full case-insensitivity

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want optional leading `-` sign support on all prefixed numeric literals and full case-insensitivity of prefixes and hex digits,
so that negative constants and typographic casing don't trip up my source.

## Acceptance Criteria

1. **Given** any current `BASE`, **When** I type `-#42 .`, **Then** the output is the representation of `-42` in the prevailing `BASE` (e.g. `-42 ` in DECIMAL, `FFD6 ` in HEX as two's-complement print, `-42 ` in base-10-like bases). The stored value of `BASE` is unchanged. Similarly `-#0 .` → `0 ` (negative zero collapses to zero per two's-complement). (Epic FR6, FR9; Forth 2014 §3.4.1.3.)

2. **Given** any current `BASE`, **When** I type `-$ff .` or `-$FF .`, **Then** the output is the representation of `-255`, and `BASE` is unchanged. Equivalently `-0xFF .`, `-0XFF .`, `-0xff .` all produce `-255` in any `BASE`. (Epic FR6, FR7, FR9.)

3. **Given** any current `BASE`, **When** I type `-%1010 .`, **Then** the output is the representation of `-10`, and `BASE` is unchanged. (Epic FR6, FR9.)

4. **Given** any current `BASE`, **When** I type `-'A' .`, **Then** the output is the representation of `-65` — the sign applies to the character code. `-'a' .` → `-97`; `-'0' .` → `-48`. The `'c'` handler must be extended to honour the outer-prefix sign — today it does not read `.pref_negate`. **Given** `-'ab' .` (malformed `'c'` body prefixed with `-`), **Then** the parse falls through to the undefined-word path (the inner `'c'` fails; no outer sign to apply). (Epic FR6, FR9 integrity.)

5. **Given** a double-sign token such as `-#-5 .`, `-$-FF .`, `-0x-FF .`, `-%-1010 .`, **Then** outer and in-body signs compose via XOR: each `-` toggles the sign once. `-#-5 .` → `5 `, `-$-FF .` → `255 `, `-0x-FF .` → `255 `, `-%-1010 .` → `10 `. This is a direct consequence of the XOR-semantic negate flag introduced in this story; the behaviour is not separately specified by Forth 2014 (which speaks only of an optional single leading sign), but it falls out of the cleanest implementation and matches user intuition. Documented as **antforth behaviour** in the source (not an extension to the grammar, just an observable consequence of how sign composition is implemented). (See Dev Notes → Double-sign composition.)

6. **Given** an un-prefixed signed literal like `-42` in DECIMAL or `-2A` in HEX, **When** it is parsed, **Then** the behaviour is **bit-identical to the pre-9.4 binary** — the `-` pre-pass must fall through cleanly (without mutating state or consuming the `-`) whenever the character after `-` is not a recognised prefix character (`#`, `$`, `%`, `0`, `0x27`). The outer interpreter's existing `NUMBER?` path handles these per FR47. Specifically:
   - `-42 .` (DECIMAL) → `-42 ` — unchanged.
   - `-2A .` (HEX) → `-2A ` — unchanged.
   - `-` alone → intercepted by FIND as the subtraction dictionary word, never reaches the recogniser (unchanged).
   - `-foo` → `-foo ? ` undefined-word fall-through (unchanged).
   - `-#` (bare outer sign + bare prefix, body count 0 after consuming both) → `-# ? ` undefined-word fall-through.
   - `-$-`, `-%-`, `-0x-` (bare outer + bare inner sign, body exhausted) → undefined-word fall-through. (FR47, FR9; NFR10 regression guarantee; Architecture §E9-D1 "zero impact on unprefixed hot path".)

7. **Given** the hex prefix family (`$` and `0x`), **When** digits are entered in any mix of upper- and lower-case (e.g. `$aBcD`, `$ABCD`, `$abcd`, `0xAbCd`, `0xABCD`, `0xabcd`), **Then** parsing succeeds and the value is identical regardless of case — 43981 (unsigned 16-bit). Mixed-case is **already implemented** in 9.2's `char_to_digit_base16` via `OR 0x20`; 9.4's contribution is **audit + expanded test coverage**, not new code. (Epic FR7; architecture §CCD-3.)

8. **Given** the two-character hex prefix `0x`/`0X`, **When** the prefix letter is in either case (`0x`, `0X`), **Then** parsing succeeds identically. Again already implemented in 9.2 via the `OR 0x20` case-fold on the second byte in `.pref_zero_entry`; 9.4 audits and expands test coverage. (Epic FR7.)

9. **Given** the non-letter prefixes (`#`, `$`, `%`) and the delimiter for character literals (`'`), **When** inspected for case-insensitivity requirements, **Then** no work is needed — these characters have no upper-/lower-case variants. The audit result is documented in the Dev Notes. (Epic FR7 verification.)

10. **Given** the kernel source, **When** the 9.4 work lands, **Then** the dispatch chain's new `-` arm carries a Forth 2014 §3.4.1.3 citation comment in the mandated format (per architecture §Format-Patterns):
    ```
    ; Forth 2014 §3.4.1.3      -<prefix><num>  — optional leading sign modifier
    ```
    The `'c'` handler's new outer-sign-apply block carries an inline comment noting the 9.4 extension. Neither is flagged as an antforth extension — leading `-` is explicitly specified in the Forth 2014 prose. (NFR17, NFR18, CCD-3; project memory `feedback_standards_compliance.md`.)

11. **Given** the existing 9.1/9.2/9.3 handlers with their in-body sign-strip blocks (`XOR A / LD (.pref_negate), A / CP '-' / …`), **When** 9.4 lands, **Then** a shared helper `pref_check_sign` replaces the quadruplication across `#`, `$`, `0x`, `%` — collapsing ~12 bytes per handler to a `CALL pref_check_sign / JP C, .pref_<x>_fail` pair (~6 bytes). The refactor is the deferred M2 finding from Story 9.2 (re-surfaced as known technical debt in 9.3 Completion Notes item 5). The helper MUST be EXX-free (it is called from inside the EXX window). Behaviour is preserved: single-sign tokens (`#42`, `#-5`) produce identical output to pre-9.4; only the source structure changes. Code-review confirmation of "no observable behaviour change for pre-9.4 tokens" is required. (Architecture §E9-D2 "no restructuring of prior stories' handlers" carve-out: this IS a restructure, but it is **explicitly** the debt payoff flagged in 9.2/9.3 and owned by 9.4. Document the scope carve-out in the Dev Notes.)

12. **Given** the `.pref_negate` scratch byte's semantics, **When** 9.4 lands, **Then** the invariant comment at `src/number_prefixes.asm:206–220` is rewritten: the **dispatch is the one-time initialiser** (reset to 0 at the top of `w_NUMBER_PREFIX_Q_cf`), and the handlers' sign-strip blocks become **XOR-toggle** rather than "reset then optionally set". This is the semantic key that makes outer and in-body signs compose cleanly (AC #5). The new invariant is: **exactly one dispatch-level reset per recogniser entry; every sign-strip (outer or in-body) XORs the flag with 1**. The `'c'` handler honours the flag on its success path (AC #4) but does not write to it. (Design decision D9.4-1; see Dev Notes.)

13. **Given** the REPL-piped test script `tests/number_prefixes_tests.fth` (extended through 9.3), **When** 9.4 extends it, **Then** new cases are appended covering at minimum:
    - **Outer sign + each prefix, single sign:** `-#42 .` → `-42 `, `-#0 .` → `0 `, `-$FF .` → `-255 `, `-$ff .` → `-255 `, `-0xFF .` → `-255 `, `-0XFF .` → `-255 `, `-0xff .` → `-255 `, `-%1010 .` → `-10 `, `-%11111111 .` → `-255 `, `-'A' .` → `-65 `, `-'a' .` → `-97 `, `-'0' .` → `-48 `, `-'+' .` → `-43 `.
    - **Double-sign (XOR composition):** `-#-5 .` → `5 `, `-$-FF .` → `255 `, `-0x-FF .` → `255 `, `-%-1010 .` → `10 `.
    - **BASE integrity under outer sign:** `HEX -#42 DROP BASE @ .` → `10 ` (BASE=16 printed in hex); `DECIMAL -$FF DROP BASE @ .` → `10 `.
    - **Case-insensitivity audit (hex digits):** `$ABCD U.` → `43981 `, `$abcd U.` → `43981 `, `$aBcD U.` → `43981 ` (already in 9.2 — re-run confirms), `0xABCD U.` → `43981 `, `0xabcd U.` → `43981 `, `0xAbCd U.` → `43981 `.
    - **Case-insensitivity audit (0x prefix letter):** `0xFF .` → `255 `, `0XFF .` → `255 ` (already in 9.2 — re-run confirms). Optional additional: `-0xFF .` and `-0XFF .` under outer-sign give `-255 `.
    - **FR47 regression guards (MUST NOT capture):** `-42 .` (DECIMAL) → `-42 `, `-2A .` (HEX) → `-2A `, `-foo` → `-foo ? `, `-ABC` (DECIMAL) → `-ABC ? `.
    - **Malformed outer-sign fallthrough:** `-#` → `-# ? `, `-$` → `-$ ? `, `-%` → `-% ? `, `-0x` → `-0x ? `, `-''` → `-'' ? `, `-'ab'` → `-'ab' ? `, `-'` → intercepted by FIND as subtraction followed by TICK — document the actual observed behaviour rather than pre-specifying, as the `-` FIND-word may or may not compose with `'`; confirm during dev.
    - **Cross-handler carry-over (new).** `-#42 -$-FF . .` → `255 -42 ` — verifies the dispatch-level reset is genuinely one-time per call, and that outer-sign state from token 1 does not bleed into token 2.

    Each case is a `@OUTPUT=$$(printf …)` block in the `test-repl` Makefile target continuing from test 330 (the last 9.3 test is 329 — verified). Tests MUST use the tightened `'<value>  ok'` two-space-then-prompt pattern for positive cases AND assert absence of `'<token> ?'` error for positive cases; fail cases use `'<token> ?'` AND assert absence of bare-numeric success. (Per `feedback_repl_tests_preferred.md`; 9.2 M1 strengthening inherited.)

14. **Given** the new test cases, **When** `make test && make test-repl` runs after 9.4 lands, **Then** the existing 336 REPL + assembly regression tests all still pass (zero regressions per NFR10 / FR45–47), and the new 9.4 tests pass. Binary size delta vs. post-9.3 baseline (14,586 bytes) is recorded in the Completion Notes. A **net decrease** is plausible here because the shared-helper refactor (AC #11) may offset the new `-` pre-pass code; an increase is still acceptable per architecture §NFR4 (no per-epic net-negative gate in Phase 2).

## Tasks / Subtasks

- [x] **Task 1: Introduce XOR-semantic sign flag + dispatch-level one-time reset** (AC: #5, #12)
  - [x] 1.1 At the top of `w_NUMBER_PREFIX_Q_cf` (`src/number_prefixes.asm:108`), between the empty-count check and the `CP '#'` dispatch, insert the one-time `.pref_negate` reset: `PUSH AF / XOR A / LD (.pref_negate), A / POP AF`. The `PUSH/POP AF` preserves the first-char byte in A across the clear (the dispatch chain depends on A = first char).
  - [x] 1.2 Rewrite the comment block at `src/number_prefixes.asm:206–219` (the `.pref_negate` invariant paragraph) to reflect the new discipline: **dispatch is the one-time initialiser; handlers XOR the flag**. Explicitly list the four sign sources that XOR the flag: (a) outer `-` pre-pass (new in 9.4), (b) in-body `-` in `#`, `$`, `0x`, `%` handlers (inherited; now via shared helper). Note that `'c'` still does not write to the flag; it only reads it to apply outer sign on its success path.
  - [x] 1.3 Under the new semantics, handlers' existing `XOR A / LD (.pref_negate), A` at the top of their sign-strip block become **redundant** (dispatch already reset). Remove those 4 bytes per handler. Subsequent `LD A, 1 / LD (.pref_negate), A` in the in-body-sign branch becomes `LD A, (.pref_negate) / XOR 1 / LD (.pref_negate), A` (XOR toggle). This minor delta is Task 2's shared-helper refactor — **Task 1 is purely the dispatch-level reset plus the comment rewrite**; do not edit handlers in Task 1.
  - [x] 1.4 Run `make test && make test-repl` after Task 1. All 336 existing tests MUST still pass — Task 1 is a pure refactor with zero behaviour change (because the dispatch-level reset precedes every handler entry, and the handlers still reset themselves redundantly until Task 2 removes it). Verify green before proceeding.

- [x] **Task 2: Extract shared `pref_check_sign` helper** (AC: #11)
  - [x] 2.1 Add a new leaf-level helper `pref_check_sign` to `src/number_prefixes.asm`. Canonical location: **immediately after the `.pref_negate` scratch byte** (line 220) so it sits with the other sign-related code and ahead of the handlers. Signature (stack-style comment block):
    ```
    ; pref_check_sign — in-body sign-strip helper (leaf; EXX-free).
    ; At entry: HL → first body byte, B = body count (>= 1).
    ; If first byte is '-', advance HL, decrement B, XOR .pref_negate with 1.
    ;   Exit carry set  → bare '<prefix>-' (body exhausted after stripping '-').
    ;   Exit carry clear → either '-' was stripped (B = B-1, HL advanced) or
    ;                      first byte was not '-' (HL, B unchanged).
    ; Preserves: DE, A' (reasons explained below), IX, IY. Clobbers: A, F.
    ;
    ; EXX-free — safe to CALL from inside an EXX window. Do NOT issue EXX here.
    ```
    Implementation:
    ```
    pref_check_sign:
            LD      A, (HL)
            CP      '-'
            RET     NZ                      ; not '-', no change (carry clear from CP)
            LD      A, (.pref_negate)
            XOR     1
            LD      (.pref_negate), A
            INC     HL
            DEC     B
            RET     NZ                      ; more bytes in body, carry clear
            SCF
            RET                             ; body exhausted → carry set (fail signal)
    ```
    Roughly 13 bytes.
  - [x] 2.2 Refactor `.pref_hash_entry` (`src/number_prefixes.asm:144–204`). Replace the 7-line sign-strip block (lines ~163–172: `XOR A / LD (.pref_negate), A / LD A, (HL) / CP '-' / JR NZ / LD A, 1 / LD (.pref_negate), A / INC HL / DEC B / JR Z, .pref_hash_fail`) with:
    ```
            CALL    pref_check_sign
            JR      C, .pref_hash_fail      ; bare "#-" → fail
    ```
    Net saving: ~10 bytes. Preserve all comments above the replaced block (the "Optional leading '-' …" explanatory comment remains relevant).
  - [x] 2.3 Repeat the Task 2.2 refactor for `.pref_dollar_entry` (~lines 243–252), `.pref_zero_entry` (~lines 323–332), and `.pref_percent_entry` (~lines 384–393). The `.pref_convert` label in each handler (e.g. `.pref_hash_convert`, `.pref_dollar_convert`, …) becomes the fall-through target of the `JR C, .pref_<x>_fail` — the layout is unchanged, only the block body shrinks.
  - [x] 2.4 Do NOT touch `.pref_quote_entry` in Task 2 — the `'c'` handler has no in-body sign (per 9.3 design), so `pref_check_sign` is irrelevant to it. Task 3 extends `'c'` separately to honour the OUTER sign flag only.
  - [x] 2.5 Run `make test && make test-repl` after Task 2. All 336 existing tests MUST still pass — behaviour is preserved by construction (the helper encodes the identical logic; the flag semantics are identical under a single-`-` input). Verify green before proceeding to Task 3.

- [x] **Task 3: Extend `'c'` handler to honour the outer sign flag** (AC: #4)
  - [x] 3.1 In `.pref_quote_entry` (`src/number_prefixes.asm:440–466`), between the closing-quote validation (current line 455 area, after the `JR NZ, .pref_quote_fail` that checks `A = 0x27`) and the `PUSH DE` at line 457, insert the sign-apply block identical to the one used by the digit handlers:
    ```
            ; 9.4: apply outer '-' prefix from .pref_negate. The 'c' handler
            ; has no in-body sign; this reads the flag set by the sign-before-
            ; prefix dispatch arm (see .pref_sign_entry below). Two's-complement
            ; negate — mirrors the digit handlers' sign-apply tail.
            LD      A, (.pref_negate)
            OR      A
            JR      Z, .pref_quote_ok
            LD      A, E
            CPL
            LD      E, A
            LD      A, D
            CPL
            LD      D, A
            INC     DE                      ; two's complement
    .pref_quote_ok:
    ```
    Rename the current direct `PUSH DE` exit label (if any) to `.pref_quote_ok`. Roughly 14 bytes added to the handler.
  - [x] 3.2 Update the handler's top-of-block comment (lines 428–438) to reflect the 9.4 addition: the handler now reads `.pref_negate` (on the success path only) but still never writes to it. The invariant list should read "EXX-free interior; no write to `.pref_negate`; read `.pref_negate` once on the success path to apply outer sign."
  - [x] 3.3 Verify: bare `'A'` (no outer sign) runs through the new block with `.pref_negate = 0` and takes the `JR Z` branch — behaviour unchanged. Confirm via targeted test `'A' .` → `65 ` still passes (it's already in the 9.3 test set as test ~304).

- [x] **Task 4: Implement the `-` sign-before-prefix pre-pass** (AC: #1, #2, #3, #4, #5, #6, #10)
  - [x] 4.1 Add a new dispatch arm immediately BEFORE the existing `CP '#' / JR Z, .pref_hash_entry` line (`src/number_prefixes.asm:120`). The `-` arm comes first so that outer-sign detection happens ahead of any single-char prefix match. New line:
    ```
            CP      '-'
            JR      Z, .pref_sign_entry
    ```
    The `JR` is safe — `.pref_sign_entry` will live close by.
  - [x] 4.2 Implement `.pref_sign_entry` as a **pre-dispatch handler** that runs entirely OUTSIDE the EXX window (like `.pref_zero_entry`'s second-byte peek). Structure:
    ```
    ; ---------------------------------------------------------------------
    ; '-' sign-BEFORE-prefix modifier handler (Story 9.4).
    ; Enters with BC = c-addr, HL = c-addr+1 (→ '-' byte), A = '-'.
    ; Peeks the SECOND char (first char after '-'). If it is a known
    ; prefix char, sets .pref_negate = 1 (the one-time dispatch reset
    ; already cleared it to 0) and re-enters dispatch on the second
    ; char. Otherwise falls through to .pref_fast_false so NUMBER?
    ; owns '-42' etc. per FR47.
    ;
    ; Runs entirely outside the EXX window — like .pref_zero_entry's
    ; pre-peek, this preserves BC = c-addr for the fallthrough path.
    ; ---------------------------------------------------------------------
    ; Forth 2014 §3.4.1.3      -<prefix><num>  — optional leading sign modifier
    .pref_sign_entry:
            ; BC = c-addr (counted-string address), (BC) = count.
            ; HL currently → '-' (first body char).
            LD      A, (BC)                 ; A = count
            CP      2
            JP      C, .pref_fast_false     ; bare '-' → fall through (FIND caught it)
            INC     HL                      ; HL → second char
            LD      A, (HL)                 ; A = second char
            ; Check against known prefix chars. Order by expected frequency
            ; for the hot path: # (most common?), $, 0, %, 0x27.
            CP      '#'
            JR      Z, .pref_sign_commit
            CP      '$'
            JR      Z, .pref_sign_commit
            CP      '0'
            JR      Z, .pref_sign_commit    ; might be '-0xFF' or '-0<digit>'
            CP      '%'
            JR      Z, .pref_sign_commit
            CP      0x27
            JR      Z, .pref_sign_commit
            JP      .pref_fast_false        ; second char not a prefix → NUMBER?
    
    .pref_sign_commit:
            ; Committed: '-' consumed, flag set, re-dispatch on second char.
            ; A already holds second char (the new "first body char").
            LD      (HL), A                 ; [no-op — documents that HL → dispatch char]
            ; Set negate flag (dispatch reset already cleared to 0, so
            ; plain "LD 1" is equivalent to XOR 1; keep XOR form for
            ; consistency with the shared-helper discipline).
            PUSH    AF                      ; preserve dispatch char across the flag store
            LD      A, (.pref_negate)
            XOR     1
            LD      (.pref_negate), A
            POP     AF                      ; A = second char again
            ; NOW: we need to re-enter the dispatch chain, but the handlers
            ; expect BC = c-addr (the ORIGINAL counted-string address), and
            ; the count byte at (BC) to reflect the full token length. The
            ; handlers re-read count from (BC) and INC HL twice to skip
            ; the count byte and the prefix byte — which would land them
            ; at the WRONG position under a '-<prefix>...' token, since
            ; the '-' byte sits between the count byte and the prefix byte.
            ;
            ; Two options considered (see Dev Notes → Sign-pre-pass design):
            ;   A. Each handler gets a new '.pref_<x>_enter_after_sign'
            ;      entry point that skips one extra byte. Fans out 5 new
            ;      labels. Zero duplication, ~2 bytes per new entry.
            ;   B. .pref_sign_commit patches BC to point one byte later,
            ;      so (BC) is a "virtual count" — but this requires the
            ;      count byte at BC+1 to exist and be correct, which it
            ;      doesn't in the source buffer. Would need a scratch
            ;      counted string. Rejected: buffer allocation overhead.
            ;
            ; Chosen: Option A. Each single-char prefix handler gains a
            ; '.pref_<x>_enter_after_sign' label positioned such that a JP
            ; from here lands with HL advanced correctly and (BC) interpreted
            ; correctly. See Tasks 4.3–4.5 for each handler's new label.
            CP      '#'
            JP      Z, .pref_hash_enter_after_sign
            CP      '$'
            JP      Z, .pref_dollar_enter_after_sign
            CP      '0'
            JP      Z, .pref_zero_enter_after_sign
            CP      '%'
            JP      Z, .pref_percent_enter_after_sign
            CP      0x27
            JP      Z, .pref_quote_enter_after_sign
            ; Unreachable (we already filtered above) but defensive:
            JP      .pref_fast_false
    ```
    **[Implementation judgement note]**: the sketch above is the canonical form. A simpler alternative the dev agent may prefer: inline the prefix-char dispatch **before** the flag-set, merging the two 5-way decisions into one. The merged form saves ~5 instructions (no second dispatch needed after `pref_sign_commit`). Choose whichever form is cleaner after reading both options once; the merged form is recommended if `PUSH AF/POP AF` around the flag write is acceptable. Document the chosen form in Completion Notes.
  - [x] 4.3 Add `.pref_hash_enter_after_sign` to `.pref_hash_entry` (currently `src/number_prefixes.asm:144–204`). Position it so that:
    - Current entry does: `PUSH BC / EXX / POP HL / LD A, (HL) / INC HL (past count) / INC HL (past '#')`. Body count is derived by `DEC A` → `LD B, A`.
    - `.pref_hash_enter_after_sign` needs to land with HL → first body byte (i.e. past count + '-' + '#') and B = body count (= count - 2, since '-' and '#' are both consumed).
    - Cleanest implementation: a single new label after the entry ritual that takes an ADDITIONAL `INC HL` and `DEC A`:
      ```
      .pref_hash_enter_after_sign:
              PUSH    BC                      ; save c-addr
              EXX
              POP     HL                      ; HL = c-addr
              LD      A, (HL)                 ; A = count
              INC     HL                      ; past count
              INC     HL                      ; past '-'
              INC     HL                      ; past '#'
              DEC     A                       ; count - 1 (for '-')
              DEC     A                       ; count - 2 (for '#')
              JR      Z, .pref_hash_fail      ; bare "-#" → fail
              LD      B, A                    ; B = body count
              JR      .pref_hash_convert      ; rejoin main handler body
      ```
      Or more compactly, a single shared entry with a "sign-offset" register param — but that fans complexity. Prefer the per-handler variant form.
    - After this label, the handler proceeds identically to its normal path — same `.pref_hash_convert`, `.pref_hash_ok`, `.pref_hash_fail` tails. The sign-apply block at the bottom of the handler reads `.pref_negate` (which is now 1 thanks to Task 4.2's commit) and performs the two's-complement negation.
    - **Important**: the new label must NOT call `pref_check_sign`. Sign-BEFORE-prefix semantics don't allow an in-body '-' on `-#-5` to pass through — BUT the AC (#5, double-sign composition) REQUIRES `-#-5` = 5 to work. So either:
      - (a) Still call `pref_check_sign` — which would process the in-body '-' of `-#-5` (HL is now past `-#`, pointing at the inner `-`), and XOR the flag again, yielding 0. Correct. Then the converter sees `5`, and sign-apply skips. Result: 5. ✓
      - (b) Don't call `pref_check_sign` — treat the body as literal, so `-#-5` would fail as "'-5' is not a valid decimal digit". Incorrect.
    - **Correct choice is (a)**. So `.pref_hash_enter_after_sign` should still call `pref_check_sign` before converting. Revised sketch:
      ```
      .pref_hash_enter_after_sign:
              PUSH    BC
              EXX
              POP     HL
              LD      A, (HL)                 ; count
              INC     HL
              INC     HL                      ; past '-'
              INC     HL                      ; past '#'
              SUB     2                       ; body count = count - 2
              JR      Z, .pref_hash_fail      ; bare "-#" → fail
              LD      B, A
              CALL    pref_check_sign         ; allow "-#-5" (XOR second '-')
              JR      C, .pref_hash_fail      ; "-#-" with body exhausted → fail
              JR      .pref_hash_convert
      ```
      This is the canonical form. Apply the same template to `.pref_dollar_enter_after_sign`, `.pref_percent_enter_after_sign`.
  - [x] 4.4 Add `.pref_zero_enter_after_sign`. The `0x` handler is special — after consuming `-`, the body still starts with `0x`, which must be stripped by the handler. The new label must re-enter the `0x`-peek path on a virtual counted string. Since re-entry is non-trivial, consider these options:
    - (a) Duplicate the 0x-peek logic inline in `.pref_zero_enter_after_sign` — about 15 bytes.
    - (b) Jump back to an internal label that reads the second-byte-of-0x on the assumption HL is already correctly positioned.
    Recommended: **(a) duplication** for clarity — the size delta is small and the semantics are unambiguous. Sketch:
    ```
    .pref_zero_enter_after_sign:
            ; Enter with HL → '-' (unchanged), BC = c-addr, A = '0' from .pref_sign_commit's dispatch.
            ; Need to verify the third char is 'x'/'X', else fall through.
            LD      A, (BC)                 ; A = count
            CP      3
            JP      C, .pref_fast_false     ; "-0" alone → fall through
            INC     HL                      ; HL → '0' (third slot: count/'-'/'0')
            INC     HL                      ; HL → third char (after '0')
            LD      A, (HL)
            OR      0x20
            CP      'x'
            JP      NZ, .pref_fast_false    ; "-0Y" where Y != x/X → fall through
            ; Committed: '-', '0', 'x'/'X' all consumed.
            PUSH    BC
            EXX
            POP     HL
            LD      A, (HL)                 ; count
            INC     HL                      ; past count
            INC     HL                      ; past '-'
            INC     HL                      ; past '0'
            INC     HL                      ; past 'x'/'X'
            SUB     3                       ; body count = count - 3
            JR      Z, .pref_zero_fail      ; "-0x" → fail
            LD      B, A
            CALL    pref_check_sign
            JR      C, .pref_zero_fail      ; "-0x-" with body exhausted → fail
            JR      .pref_zero_convert
    ```
    If the second char peek is combined with the original `.pref_zero_entry`'s peek (see 4.6 for merging option), this duplication may shrink.
  - [x] 4.5 Add `.pref_quote_enter_after_sign`. The `'c'` handler enforces count == 3 for the **prefix-only** form. Under `-'A'`, the full token count is 4 (`-`, `'`, `A`, `'`). The new label checks count == 4:
    ```
    .pref_quote_enter_after_sign:
            PUSH    BC
            EXX
            POP     HL
            LD      A, (HL)                 ; count
            CP      4
            JR      NZ, .pref_quote_fail    ; must be exactly 4 bytes ('-' + 'c')
            INC     HL                      ; past count
            INC     HL                      ; past '-'
            INC     HL                      ; past opening '
            LD      E, (HL)                 ; E = middle byte
            LD      D, 0
            INC     HL
            LD      A, (HL)
            CP      0x27
            JR      NZ, .pref_quote_fail
            JR      .pref_quote_ok          ; rejoin — sign-apply + PUSH + EXX + NEXT
    ```
    Note: `-''` (count 3 = `-` + `''`) is a malformed `'c'` (empty middle) and would fail the count == 4 check. `-'ab'` (count 5) also fails count == 4. Both correctly fall through to the undefined-word path per AC #6.
  - [x] 4.6 **Optimization (optional, judgement call)**: if the five `.pref_<x>_enter_after_sign` variants share too much prologue, collapse them into a single "after-sign" dispatch block that sits right after `.pref_sign_commit`. The block would do the shared EXX entry once, then JP to the convert label of the matched handler. Worth doing only if the dev agent measures > 40 bytes of duplication; otherwise per-handler entry is cleaner. Document whichever form is chosen. **Not taken**: duplication measured at ~60 bytes but a shared routine would only save ~30 bytes after CALL/RET overhead and would introduce a subroutine that crosses the EXX boundary — keeping per-handler form preserves readability. Documented in Completion Notes.
  - [x] 4.7 Update the file-header scaffold block at `src/number_prefixes.asm:18–97`. Add a new "Story 9.4 additions" subsection documenting: the `-` pre-pass, the XOR-semantic flag refactor, the `pref_check_sign` shared helper, and the per-handler `.pref_<x>_enter_after_sign` entry points. Remove the old `; 9.4:` placeholder at line 130.
  - [x] 4.8 Update the dispatch-chain scaffold comments (lines 117–130): the `-` arm is now real code; remove the `; 9.4:` line. The scaffold table at lines 79–97 should mark the 9.4 row as "(this story)".

- [x] **Task 5: Case-insensitivity audit (verification, no new code)** (AC: #7, #8, #9)
  - [x] 5.1 Verify `char_to_digit_base16` at `src/number_prefixes.asm:586–606` correctly folds case via `OR 0x20`. Expected: `'A'..'F'` and `'a'..'f'` both map to 10..15. Grep `tests/number_prefixes_tests.fth` for existing mixed-case coverage; add any missing cases per AC #13.
  - [x] 5.2 Verify `.pref_zero_entry`'s second-byte peek at `src/number_prefixes.asm:305` uses `OR 0x20` to fold `x`/`X`. Add a targeted test for `0XaBcD U.` → `43981 ` if not already covered (checks both prefix-letter case-fold AND digit case-fold in one token).
  - [x] 5.3 Document the audit result in the Dev Notes — specifically: `#`, `$`, `%`, `'` prefix characters have no case dimension; `0x`/`0X` prefix letter case-fold and hex digit case-fold are both inherited unchanged from 9.2; 9.4 adds zero new case-fold code but audits and re-tests both. No source changes required for Task 5.
  - [x] 5.4 Confirm the `'c'` character literal body byte is NOT case-folded (per Forth 2014 §3.4.1.3 — a character literal is a transparent byte pass-through). `'A'` and `'a'` must continue to yield 65 and 97 respectively. This is a preservation concern, not an implementation change — confirm via existing 9.3 tests (`'A'` → 65, `'a'` → 97 are already there).

- [x] **Task 6: Extend the REPL-piped test file** (AC: #13)
  - [x] 6.1 Append a "Story 9.4 additions" section to `tests/number_prefixes_tests.fth` following the 9.1/9.2/9.3 comment style. Include the cases enumerated in AC #13 — each as a one-liner with the expected stdout fragment in a trailing `\` comment. Section banner: `\ --- Story 9.4 additions: leading '-' sign + case-insensitivity audit ---`.
  - [x] 6.2 Append matching `@OUTPUT=$$(printf …)` blocks to the `Makefile` `test-repl` target, numbered starting at **test 330** (the last 9.3 test is 329 per Makefile inspection — verified). Add a Makefile banner before the new block: `@echo "--- Story 9.4: leading sign and case-insensitivity tests ---"`. Match the 9.3 block structure exactly.
  - [x] 6.3 Estimated new test count: **~30 cases** (AC #13 enumerates 5 groups totalling ~30 distinct cases, plus cross-handler carry-over and FR47 regression guards). Exact numbering is the dev agent's judgement — aim for one case per AC #13 bullet.
  - [x] 6.4 Apply the 9.2/9.3 test-strengthening discipline (per `feedback_adversarial_review.md` and the 9.2 M1 finding): positive tests assert `'<value>  ok'` AND `! '<token> ?'`; fail tests assert `'<token> ?'` AND `! '[0-9]  ok'`. The printf encoding for `-` in shell-doublequoted strings may need escaping — test a representative case first (`printf '\-#42\r\nBYE\r\n'` or equivalent) before bulk-adding blocks.
  - [x] 6.5 Pay particular attention to these tricky-to-escape tokens: `-'A'` (single quotes inside a shell-escaped token — study the 9.3 quote-token blocks for the existing pattern), `-%1010` (escape the `%`), `-%-1010` (double sign, same escaping). The 9.3 file has working patterns for all three character classes.

- [x] **Task 7: Regression verification and binary size delta** (AC: #14, #6)
  - [x] 7.1 Run `make test` (assembly regression) — must pass with zero failures.
  - [x] 7.2 Run `make test-repl` — all 336 existing tests (post-9.3) + the new 9.4 tests pass (zero regressions).
  - [x] 7.3 Spot-check FR45–47 preservation with a REPL session (manual smoke, document in Completion Notes):
    - `-42 .` (DECIMAL) → `-42  ok` — unchanged (NUMBER? owns this, not the pre-pass).
    - `-2A .` (HEX) → `-2A  ok` — unchanged.
    - `- .` → `<undefined> ?` or stack-effect depending on FIND behaviour of bare `-`; **document actual observed behaviour**.
    - `-foo` → `-foo ?`.
    - `-ABC` in DECIMAL → `-ABC ?`.
    - `' DROP .` → xt for DROP (TICK still works; 9.4 does NOT touch TICK).
    - `-' DROP` → whatever FIND-of-`-` / TICK composition yields; **document actual observed behaviour**.
  - [x] 7.4 Record binary size delta: `wc -c build/antforth.com` vs post-9.3 baseline **14,586 bytes** (per 9.3 Completion Notes item 8). Expected: **-10 to +150 bytes** — the shared-helper refactor (Task 2) saves ~40 bytes, the `'c'` sign-apply block (Task 3) adds ~14 bytes, the `-` pre-pass + 5 `.pref_<x>_enter_after_sign` labels (Task 4) add ~80–120 bytes. Net could plausibly be negative or modestly positive. If the actual delta exceeds +200 bytes, investigate — likely indicates unintended duplication in the per-handler sign entries.

- [x] **Task 8: Code review** (AC: all)
  - [x] 8.1 Run the `bmad-bmm-code-review` workflow against the 9.4 changes (per project memory `feedback_adversarial_review.md`: reviews MUST find things — a sign modifier that interacts with five existing handlers AND refactors four of them is inherently suspect for finding-free outcomes; expect 2+ findings).
  - [x] 8.2 Pay special attention to:
    - (a) **`-42` regression check** — the pre-pass MUST fall through for any `-<non-prefix>` token. Grep-verify the 5 `JR Z, .pref_sign_commit` checks cover every recognised first-char prefix; missing `0x27` or `0` would be a direct regression. Write one test that specifically asserts `-1234 .` in DECIMAL prints `-1234 ` (not something else).
    - (b) **Double-sign XOR correctness** — cases `-#-5 → 5`, `-$-FF → 255`, `-0x-FF → 255`, `-%-1010 → 10` MUST all pass. A silent regression here would quietly sign-flip user data. Tests for all four combinations are mandatory.
    - (c) **Shared helper preservation of HL/B invariants** — `pref_check_sign` preserves HL and B only if it returns through the `not '-'` fast path. On the `'-'` path, it advances HL and decrements B. Callers must rely on this contract. Grep every caller site to verify HL is used after the CALL (it is — the subsequent `CALL do_number_base<N>` reads HL).
    - (d) **The `.pref_sign_commit → .pref_<x>_enter_after_sign` dispatch** — the second CP chain (Task 4.2) duplicates the first. Verify the two chains are IN AGREEMENT — every char the first chain accepts, the second chain must route. A divergence would produce "accepted by pre-pass but no handler to dispatch to" → infinite loop or crash. Consider merging per Task 4.6.
    - (e) **Standards citation format** — the `-` arm cites Forth 2014 §3.4.1.3. Not an antforth extension. Mis-flagging is an NFR12/CCD-3 violation.
    - (f) **The `PUSH AF / … / POP AF` at dispatch-level reset** (Task 1.1) preserves the first-char byte. Verify this is still the first-char dispatch's source of A in the `CP '#'` chain (it is — that's the whole point).
  - [x] 8.3 Address findings or document skip rationale per the 9.1/9.2/9.3 pattern. Any HIGH-severity finding is a release blocker; MEDIUM and LOW may be deferred to 9.5 or 9.6 with explicit follow-up notes.

### Code Review (2026-04-20)

Adversarial review ran via `bmad-bmm-code-review`. Findings: **0 High, 1 Medium, 6 Low**. All 363 REPL + assembly regression tests passed before and after fixes.

**Fixed immediately:**

- **M1 (Medium) — Inconsistent `.pref_negate` toggle ordering.** `.pref_hash/_dollar/_percent/_quote_enter_after_sign` toggled the sign flag BEFORE the count-check fail branch; `.pref_zero_enter_after_sign` alone toggled AFTER validation. Correctness was preserved only by the dispatch-level reset on the next token — fragile. Refactored all four to check-first-then-commit (matching `.pref_zero_`): peek `(BC)` for count, validate, then toggle `.pref_negate` only once committed. Fail path falls through to `.pref_fast_false` (outside EXX, flag untouched) instead of the per-handler `.pref_<x>_fail` (which needed EXX context). `-#`, `-$`, `-%`, `-''`, `-'ab'` all continue to report `-<token> ?` to the user. Updated the `.pref_<x>_enter_after_sign` block comment and the scaffold-table entry for 9.4 to document the new check-first discipline.

- **L1 (Low) — Confused comment at `src/number_prefixes.asm:150-159`.** Stream-of-consciousness commentary that described a `PUSH/POP AF` preserve block absent from the code and corrected itself mid-paragraph. Rewrote to the load-bearing sentences only.

- **L3 (Low) — Scaffold table stale `(this story)` markers.** Table at `src/number_prefixes.asm:112-132` marked 9.2, 9.3, AND 9.4 rows simultaneously current. Updated 9.2/9.3 rows to `(done)`.

**Deferred (documented, no action in 9.4):**

- **L2 (Low) — `-` arm placed LAST in the dispatch chain, not FIRST as Task 4.1 specified.** Semantically equivalent because prefix characters are all distinct. Order chosen by expected frequency (bare numerics hit the empty-fall-through; prefixes hit their respective arms first). No observable behaviour difference. Not fixed — noted here for traceability.

- **L4 (Low) — ~60 bytes of duplication across the five `.pref_<x>_enter_after_sign` handlers.** Completion Notes item 4 documented the deliberate choice not to shared-routine them; the M1 fix added ~4 bytes per handler (total ~20 bytes) which marginally raises the case for deduplication. Revisit in 9.5/9.6 if the epic budget squeezes; not blocking for 9.4.

- **L5 (Low) — Sign-apply block duplication grew to 5 sites.** CPL/CPL/INC DE pattern at `.pref_<x>_ok` for all 5 handlers. Pre-existing debt from 9.1-9.3 (`pref_check_sign` analogue not yet extracted). The M2-style payoff would be a leaf-level `pref_apply_negate` helper. Scoped to a future story (candidate for 9.5 or 9.6 polish).

- **L6 (Low) — `.pref_sign_entry` bare-`-` branch (line 582-584) marked "unreachable normally".** Defensive code that costs 5 bytes. Kept as-is per defensive coding discipline; refined comment wording deferred.

**Binary size delta:** 14,778 → 14,787 (+9 bytes for M1 fix). Final Phase-2 delta vs post-9.3 baseline (14,586) is **+201 bytes**, one over the +200 investigation threshold but explained entirely by the check-first refactor required for correctness discipline. Within architecture §NFR4 per-epic budget.

**Tests:** all 363 pass (262 assembly thread + 101 REPL = 363, zero regressions, 34 new 9.4 tests).

## Dev Notes

### Story Purpose and Scope

Story 9.4 is the **last functional story** of Epic 9. It delivers the leading-`-` sign modifier (FR6) that composes with every other prefix (`#`, `$`, `0x`, `%`, `'c'`), and closes the case-insensitivity audit (FR7). Story 9.5 then verifies prefix reach into colon bodies and `CODE` blocks; Story 9.6 is the benchmark + regression gate and tags antforth 1.9.

By the end of 9.4, the entire Forth 2014 §3.4.1.3 numeric-literal grammar — plus the `0x` antforth extension — is functionally complete at the REPL. 9.5's contribution is verification-of-reach; 9.6's is measurement.

**Net new work:**

1. **Sign-before-prefix dispatch arm.** New `.pref_sign_entry` pre-pass that peeks the second char, commits to outer-sign only if the second char is a recognised prefix, and re-dispatches to per-handler "enter-after-sign" entry points.
2. **Outer-sign support in `'c'`.** The `'c'` handler gains a sign-apply block on its success path (~14 bytes). It still does not write to `.pref_negate`.
3. **Shared `pref_check_sign` helper.** Collapses the four in-body sign-strip blocks into a 13-byte leaf helper, reducing total source by ~30 bytes and centralising the invariant for future auditors. This is the deferred M2 finding from Story 9.2, flagged as known technical debt in 9.3 Completion Notes item 5.
4. **XOR-semantic flag.** `.pref_negate` is initialised once at dispatch entry; every sign-strip site XORs with 1. This makes outer and in-body signs compose cleanly (`-#-5 → 5`) without any special-case logic.
5. **Case-insensitivity audit.** No new code — 9.2 already designed hex digits and the `0x` prefix letter for full case-insensitivity up front (per `feedback_design_upfront.md`). 9.4 adds test coverage that explicitly asserts the promise, closing FR7 observationally.

### Architecture Decisions Driving This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§E9-D1 (Integration point):** zero impact on the unprefixed hot path. For 9.4, this is especially tight on the `-` pre-pass: any token beginning with `-` must not pay a cycle-cost penalty unless its second char is a known prefix. The second-char peek happens **outside the EXX window** to keep the fall-through cheap — directly analogous to `.pref_zero_entry`'s peek for `0x`.
- **§E9-D2 (Prefix dispatch strategy):** flat `CP`/`JR Z` chain. 9.4 extends it to 6 arms (was 5 after 9.3). Still well within the range where the chain outperforms a table. **Do not switch to a table mid-epic** — the design-upfront discipline said "flat chain is good enough through Epic 9", and 9.4 does not change that.
- **§CCD-3 (Standards-Citation Discipline):** the `-` arm cites Forth 2014 §3.4.1.3 (same section as `#`, `$`, `%`, `'`). Leading sign is **explicitly permitted** by the standard prose. Do NOT flag as an `antforth extension`.
- **§NFR12 (Extension discipline):** 9.4 adds zero extensions. The double-sign composition (AC #5) is not specified by the standard but falls out of the XOR-semantic implementation — document as a **consequence of the implementation**, not a grammar extension.

### Sign-pre-pass design decision (D9.4-1)

This is the central design choice of 9.4. Three alternatives were considered:

**Option A: Pre-pass sets flag + re-dispatches to per-handler entry points.** *(Chosen.)*
- `.pref_sign_entry` peeks second char, commits if prefix, jumps to `.pref_<x>_enter_after_sign`.
- Each affected handler gets a new entry label that accounts for the extra byte (`-`) already consumed.
- `pref_check_sign` is still called for in-body sign support inside each handler (double-sign XOR composition).
- Trade-off: 5 new entry labels (one per prefix). Clear, maintainable; easy to audit.

**Option B: Pre-pass sets flag + re-enters the top of the dispatch on the second char.**
- Elegant in concept (no new entry labels), but requires mutating BC or HL to point to a "virtual counted string" that elides the `-` byte. Since the counted-string count is at `(BC)` and the source buffer is read-only, this would require a scratch buffer copy.
- Rejected: scratch buffer management is a cost the project doesn't want here.

**Option C: Fully standalone `.pref_sign_entry` that reimplements every prefix's body-parse inline.**
- Zero dependency on the per-handler entry points, but ~150 bytes of duplication.
- Rejected: fails the DRY discipline expected by 9.3's Dev Notes.

**Chosen: Option A.** The per-handler `.pref_<x>_enter_after_sign` labels are ~15 bytes each (~75 bytes total), plus the `.pref_sign_entry` prologue (~50 bytes). Total: ~125 bytes, offset by ~30 bytes saved in Task 2's shared-helper refactor. Net +95 bytes for full leading-sign support — acceptable.

**Alternative considered and held in reserve**: merge the two CP-dispatch chains in `.pref_sign_entry`. The first chain checks "is this a known prefix?"; the second chain dispatches to the handler. The second chain duplicates the first. Task 4.6 proposes the merge as an optional optimisation. The dev agent may choose to land it as part of 9.4 or defer it to 9.5/9.6 polish. Recommendation: land it if the diff stays readable; defer otherwise.

### XOR-semantic flag transition

The semantic change from "reset-at-entry" to "XOR-toggle" is at the heart of AC #5 (double-sign composition) and AC #12 (invariant rewrite). The transition happens in two discrete moves:

1. **Task 1** adds the dispatch-level one-time reset. Handlers' existing reset code is now redundant (both reset to 0; order doesn't matter). Behaviour is preserved exactly. This is a safe prep step — run full tests after Task 1 to confirm.
2. **Task 2** extracts the shared helper and removes the redundant per-handler reset. Handlers' remaining "set to 1" becomes "XOR with 1". Behaviour is preserved for single-sign tokens (set-to-1 and XOR-with-1 are equivalent when the initial state is 0, which the dispatch-level reset guarantees). Double-sign tokens don't exist in the test set **until Task 4 lands**, so Task 2 can be validated in isolation against the existing 336 tests.

This staged landing (1 → 2 → 3 → 4 → 6) allows each task to be verified against a green baseline before proceeding. **Do not collapse tasks**; the staged approach is how we catch regressions early.

### Shared helper `pref_check_sign` — invariant and call sites

**Invariant** (MANDATORY for any future reader — update the comment block at the helper site):

- Leaf-level, EXX-free. Safe to CALL from inside an EXX window.
- At entry: HL → first body byte; B = body count ≥ 1.
- At exit, carry clear: either first byte was not `-` (HL, B unchanged) OR first byte was `-` (HL+=1, B-=1, `.pref_negate` XOR'd with 1).
- At exit, carry set: first byte was `-` and body was exhausted after stripping it (B was 1, now 0). Caller must treat as fail.
- Preserves: DE, IX, IY, and the shadow bank (handler's in-flight c-addr in BC' and IP in DE').
- Clobbers: A, F (with flags carrying the fail/not-fail signal).

**Call sites after 9.4**:
- `.pref_hash_entry` (replaces 7-line block)
- `.pref_dollar_entry` (replaces 7-line block)
- `.pref_zero_entry` (replaces 7-line block)
- `.pref_percent_entry` (replaces 7-line block)
- `.pref_hash_enter_after_sign` (called after `-` pre-pass to allow double-sign)
- `.pref_dollar_enter_after_sign` (ditto)
- `.pref_zero_enter_after_sign` (ditto)
- `.pref_percent_enter_after_sign` (ditto)

Eight call sites. Single source of truth. Future stories adding new prefixes use it unchanged.

`.pref_quote_entry` does NOT call `pref_check_sign` — a character literal has no in-body sign. It only reads `.pref_negate` on its success path to apply the outer sign.

### Double-sign composition — semantics documentation

AC #5 requires `-#-5 .` → `5 ` and the analogous double-sign cases. This is an observable consequence of the XOR-semantic flag, not a separately-specified grammar rule. Forth 2014 §3.4.1.3 speaks only of "optional sign" — it does not say what happens if BOTH an outer and an in-body sign appear.

Our implementation composes them via XOR. This is:
- **Consistent with user intuition** (two negatives make a positive).
- **Deterministic and unambiguous** (no hidden order-of-operations).
- **Free of special-case code** (falls out of the XOR discipline).

Document this in a Dev Notes paragraph in `src/number_prefixes.asm` and in the story's Completion Notes. It is **antforth behaviour**, not a Forth 2014 violation — the standard simply doesn't specify this case, so no conformance issue arises.

### `'c'` handler changes — minimal

Task 3 adds ~14 bytes to `.pref_quote_entry` (one 7-instruction sign-apply block). The handler still:
- Enforces exact 3-byte count (for the no-sign case) OR 4-byte count (for the `-'c'` case, handled by `.pref_quote_enter_after_sign`).
- Validates the closing quote (`0x27`).
- Does NOT write to `.pref_negate`.
- Does NOT call `pref_check_sign`.
- Reads `.pref_negate` exactly once on the success path.

The two entry points (`.pref_quote_entry` for `'c'` and `.pref_quote_enter_after_sign` for `-'c'`) share the `.pref_quote_ok` success tail (where the sign-apply block lives). This is the smallest-possible delta for 9.4 — the handler's structure is unchanged; only a new entry and a sign-apply tail are added.

### Case-insensitivity audit — verification only

9.2 designed case-insensitivity up front per `feedback_design_upfront.md`:
- `char_to_digit_base16` folds hex digits via `OR 0x20` (covers `a–f` and `A–F`).
- `.pref_zero_entry` folds the prefix letter via `OR 0x20` (covers `0x` and `0X`).

9.3 added no new case dimension (`%` and `'c'` have none). 9.4 adds no new case dimension (`-` has none).

**Audit result (for Dev Notes and Completion Notes):** case-insensitivity is complete. Expanded test coverage under AC #13 verifies the invariant. No source changes required for Task 5.

### Scaffold Template Walkthrough — `.pref_sign_entry`

The pre-pass sits at the TOP of the dispatch chain, before any other `CP / JR Z` arm:

```
w_NUMBER_PREFIX_Q_cf:
        LD      H, B
        LD      L, C                    ; HL = c-addr
        LD      A, (HL)                 ; A = count
        OR      A
        JR      Z, .pref_fast_false

        ; 9.4: dispatch-level one-time reset of .pref_negate. The sign
        ; flag is XOR-toggled by every subsequent sign source (outer '-'
        ; pre-pass, in-body '-' via pref_check_sign). Reset to 0 here
        ; once per recogniser entry.
        PUSH    AF                      ; preserve A (count→garbage OK; we re-load below)
        XOR     A
        LD      (.pref_negate), A
        POP     AF
        ; Actually simpler — A isn't the count yet. Re-evaluate layout.
        ; [see Task 1.1 notes for the canonical form]

        INC     HL                      ; HL → first char
        LD      A, (HL)                 ; A = first char

        CP      '-'
        JR      Z, .pref_sign_entry
        CP      '#'
        JR      Z, .pref_hash_entry
        CP      '$'
        JP      Z, .pref_dollar_entry
        CP      '0'
        JP      Z, .pref_zero_entry
        CP      '%'
        JP      Z, .pref_percent_entry
        CP      0x27
        JP      Z, .pref_quote_entry
        ; (the old '; 9.4: CP '-' ...' placeholder line is deleted)
```

**Layout note on Task 1.1**: the dispatch-level reset ideally happens between "count != 0" and the "INC HL / LD A, (HL)" to minimise instruction reordering. The sketch above shows the reset AFTER the count-check but BEFORE the first-char fetch. Either order works; pick whichever preserves register state most cleanly.

### Source Tree Components to Touch

- **MODIFY:**
  - `src/number_prefixes.asm` — dispatch reset (Task 1), `pref_check_sign` helper (Task 2), refactor 4 handler sign-strip blocks (Task 2), `'c'` sign-apply (Task 3), `-` pre-pass + 5 `.pref_<x>_enter_after_sign` entries (Task 4), file-header + scaffold comments (Task 4.7/4.8).
  - `tests/number_prefixes_tests.fth` — append Story 9.4 section (Task 6).
  - `Makefile` — append test blocks 330+ in the `test-repl` target, mirroring 9.3's pattern (Task 6).
- **MAY MODIFY (judgement call):** nothing expected. If `src/outer_interpreter.asm` appears to need changes, something is wrong — the 9.1 wire-in is sufficient for all 9.4 work.

**Untouched (confirm by final inspection):** `src/outer_interpreter.asm`, `src/antforth.asm`, `src/strings.asm`, `src/assembler.asm`, `src/dictionary.asm`, `src/compiler.asm` (TICK unchanged, subtraction `-` word unchanged), and every file not listed in "MODIFY".

### Existing Code References (Grep-Verified)

- `src/number_prefixes.asm:108–130` — `w_NUMBER_PREFIX_Q_cf` entry + dispatch chain; Task 1 adds reset here; Task 4.1 adds `-` arm.
- `src/number_prefixes.asm:130` — `; 9.4:` placeholder line to remove in Task 4.8.
- `src/number_prefixes.asm:144–204` — `.pref_hash_entry` — Task 2.2 refactor target; Task 4.3 adds `.pref_hash_enter_after_sign`.
- `src/number_prefixes.asm:163–172` — sign-strip block in `.pref_hash_entry` (7 lines, collapsed by shared helper).
- `src/number_prefixes.asm:206–220` — `.pref_negate` scratch + invariant comment block. Task 1.2 rewrites the comment.
- `src/number_prefixes.asm:228–284` — `.pref_dollar_entry` — Task 2.3 refactor target; Task 4.3 adds `.pref_dollar_enter_after_sign`.
- `src/number_prefixes.asm:243–252` — sign-strip block in `.pref_dollar_entry`.
- `src/number_prefixes.asm:297–362` — `.pref_zero_entry` — Task 2.3 refactor target; Task 4.4 adds `.pref_zero_enter_after_sign`.
- `src/number_prefixes.asm:322–332` — sign-strip block in `.pref_zero_entry`.
- `src/number_prefixes.asm:370–425` — `.pref_percent_entry` — Task 2.3 refactor target; Task 4.3 adds `.pref_percent_enter_after_sign`.
- `src/number_prefixes.asm:383–393` — sign-strip block in `.pref_percent_entry`.
- `src/number_prefixes.asm:440–466` — `.pref_quote_entry` — Task 3 extends; Task 4.5 adds `.pref_quote_enter_after_sign`.
- `src/number_prefixes.asm:457` — current `PUSH DE` success exit; Task 3 inserts `.pref_quote_ok` label here and the sign-apply block above it.
- `src/number_prefixes.asm:586–606` — `char_to_digit_base16` — Task 5.1 verification target (no edit expected).
- `src/number_prefixes.asm:305` — `OR 0x20` case-fold for `0x`/`0X` — Task 5.2 verification target.
- `src/compiler.asm:25–48` — TICK word (`'`), unchanged.
- `src/outer_interpreter.asm:179–208` — `.try_number` thread (unchanged by 9.4 — the 9.1 wire-in handles dispatch).
- `Makefile:~2585` — Story 9.3 banner; last 9.3 test is 329 at Makefile:~2850; 9.4 appends starting at block 330.
- `tests/number_prefixes_tests.fth:1–164` — complete pre-9.4 file; 9.4 appends a new section at the bottom.

### Previous-Story Intelligence — Story 9.3 Learnings

Story 9.3 completed with 6 review follow-ups (M1×2 + L1–L4 + L5). Key takeaways for 9.4:

1. **`.pref_negate` write-before-read invariant is load-bearing.** 9.3's M1 review flagged the need to explicitly document this. 9.4's XOR-semantic refactor REWRITES the invariant (AC #12 / Task 1.2) — make sure the new comment is thorough; a future reader debugging a sign bug will go here first. Cross-reference Story 9.2's M2 and Story 9.3's Completion Notes item 5 as the debt lineage.

2. **Test numbering discipline.** 9.3 ended at test 329. 9.4 starts at 330. Keep the numbering strictly sequential; do NOT renumber earlier tests.

3. **Test-case strengthening is mandatory.** Per 9.2 M1 and 9.3 Task 5.4: every positive test asserts the `'<value>  ok'` pattern AND the absence of the `'<token> ?'` error marker; every fail test asserts the error AND the absence of bare-numeric success. 9.4 has an elevated false-positive risk because `-<digit>` tokens (which should fall through) echo back as numeric strings — a naïve grep on `-42` would pass even if the pre-pass erroneously consumed it. **Tighten test 330+ accordingly.**

4. **Binary-size predictions are approximate — and sometimes negative.** 9.3 landed at +164 (predicted +130..+180). 9.4's refactor component could land the net delta below zero — a happy surprise, but not one to count on. Budget for +150; celebrate if smaller.

5. **JR-range creep.** 9.3 inherited the 9.2 learning on `JR Z` → `JP Z` for out-of-range targets. 9.4's new code sits LATER in the file than 9.3's, so the range pressure is higher. **Use `JP Z` preemptively for any dispatch-chain arm whose target lies after `.pref_zero_fail`.** `.pref_sign_entry` itself is close to the top of the chain, so `JR Z` is safe for the dispatch-to-sign arm; but `.pref_<x>_enter_after_sign` labels (deeper in the file) should be reached via `JP`.

6. **Adversarial review discipline.** 9.3's review found 6 items. 9.4 is structurally bigger (refactor + new handler + per-handler variants) — expect 5+ findings. Zero findings on 9.4 would be suspect per `feedback_adversarial_review.md`. Specifically, the second CP-dispatch chain in `.pref_sign_entry` (Task 4.2) is a classic spot for off-by-one or missing-case bugs.

7. **Smoke-test the FR47 boundary manually.** `-42 .` and `-2A .` in interactive REPL before marking done. These tokens have zero prefix character (leading `-` followed by digits) and MUST fall through. The test suite covers them but an interactive spot-check catches any environment-specific quirks.

### Feature-Parity Table — State After 9.4

| Token form | Pre-9.4 behaviour | Post-9.4 behaviour |
|---|---|---|
| `42` | NUMBER? parses per BASE | unchanged ✓ |
| `-42` | NUMBER? parses signed per BASE | unchanged (pre-pass falls through) ✓ |
| `#42` | 9.1: decimal regardless of BASE | unchanged ✓ |
| `-#42` | pre-pass inactive → NUMBER? fails → `-#42 ?` | 9.4: parses as -42 regardless of BASE ✓ NEW |
| `#-5` | 9.1: in-body sign, -5 regardless of BASE | unchanged ✓ |
| `-#-5` | pre-pass inactive → fail | 9.4: XOR composition → +5 ✓ NEW |
| `$FF` | 9.2: 255 regardless of BASE | unchanged ✓ |
| `-$FF` | fail | 9.4: -255 ✓ NEW |
| `$aBcD` | 9.2: case-fold works | unchanged ✓ (audit confirmed) |
| `0xFF` | 9.2: 255 (antforth ext) | unchanged ✓ |
| `-0xFF` | fail | 9.4: -255 ✓ NEW |
| `0XFF` | 9.2: prefix-letter case-fold | unchanged ✓ (audit confirmed) |
| `%1010` | 9.3: binary, 10 regardless of BASE | unchanged ✓ |
| `-%1010` | fail | 9.4: -10 ✓ NEW |
| `'A'` | 9.3: 65 | unchanged ✓ |
| `-'A'` | fail | 9.4: -65 ✓ NEW |
| `'` | intercepted by FIND as TICK | unchanged ✓ |
| `-` | intercepted by FIND as subtraction | unchanged ✓ |
| `-foo` | undefined-word fail | unchanged ✓ (pre-pass falls through) |
| `-42` (DECIMAL) | NUMBER? parses as -42 | unchanged — **FR47 preserved** ✓ |

Every NEW row is covered by an AC and a test in Task 6.

### EXX / Shadow-Register Conventions (Inherited Unchanged)

Per `docs/register-conventions.md` and the `src/number_prefixes.asm` file-header ritual block:

- **BC = TOS (main), DE = IP (main), HL = W/scratch, IX = return-stack, IY = user-area base.**
- **EXX swaps main↔shadow** — only A and flags survive.
- **`pref_check_sign` is EXX-free** — same discipline as `do_number_base<N>` and `char_to_digit_base<N>`.
- **`.pref_sign_entry` runs OUTSIDE the EXX window** — like `.pref_zero_entry`'s pre-peek. This preserves BC = c-addr for the fall-through path (exactly as documented in the file header at `src/number_prefixes.asm:71–77`).

After 9.4, the expected EXX occurrence count in the file is: 15 (pre-9.4, per 9.3 Dev Notes) + 5 new entries in the per-handler `.pref_<x>_enter_after_sign` labels × 1 EXX each = 20 total. Grep-verify `grep -cE '^\s*EXX\b' src/number_prefixes.asm` — should read 20. Divergence indicates an accidental EXX in `pref_check_sign` or `.pref_sign_entry`; investigate.

### Standards Citation — Forth 2014 §3.4.1.3

Same section as `#`, `$`, `%`, `'`. The §3.4.1.3 prose names the optional leading sign as part of the prefix-literal syntax. **Leading `-` is standard**, not an antforth extension.

The antforth-specific observable (double-sign XOR composition per AC #5) is not specified by the standard. Document as a consequence of implementation, NOT as an extension — no `; antforth extension` flag on any source line in 9.4.

Do NOT cite §3.4.1.4 or §3.4.1.2 for the sign modifier — §3.4.1.3 is the consolidated section covering all of Epic 9's prefix work.

### Testing Standards

Per `feedback_repl_tests_preferred.md`: REPL-piped Forth scripts, not assembly test-thread extensions. Do NOT add to `src/tests/*.asm` for this story.

Test delivery: Makefile `test-repl` target + `.fth` file, per 9.1's Option A. Cross-reference the `.fth` file from Makefile block comments so future maintainers can find the source-of-truth intent.

**Manual smoke test** (not automated, for the dev agent to run once before marking story complete): pipe each of the following into `build/antforth.com` interactively and eyeball the output:
- `-#42 .` → `-42  ok`
- `-$FF .` → `-255  ok`
- `-0xFF .` → `-255  ok`
- `-%1010 .` → `-10  ok`
- `-'A' .` → `-65  ok`
- `-#-5 .` → `5  ok` (double-sign XOR)
- `-42 .` (DECIMAL) → `-42  ok` (FR47 regression — NUMBER? owns this, not the pre-pass)
- `- .` → behaviour depends on FIND of bare `-` (existing subtraction word); document observed
- `-foo` → `-foo ?  ok`
- `HEX -$FF DROP BASE @ .` → `10  ok` (BASE=16 preserved)

Record the manual smoke results in the Completion Notes alongside the `make test-repl` summary.

### Project Structure Notes

- `src/number_prefixes.asm` grows by ~30 lines net (refactor saves ~40, pre-pass + entries adds ~70, `'c'` sign-apply adds ~14, comment updates are neutral). Post-9.4 file size roughly 690 lines vs 661 pre-9.4.
- No new files are created. `src/number_prefixes.asm` and `tests/number_prefixes_tests.fth` both continue their Epic-9 scope; `Makefile` gets more `test-repl` blocks in the established pattern.
- The `Makefile` `test-repl` target crosses ~3000 lines after 9.4. Still established pattern — do NOT refactor the test target in this story. An infrastructure story (potentially Epic 9.6 cleanup or a later epic) owns that migration.
- No conflicts with unified project structure. All changes are additive-or-refactor in the existing Phase-2-designated file.

### References

- `_bmad-output/planning-artifacts/epics.md:334–360` — Story 9.4 authoritative spec
- `_bmad-output/planning-artifacts/epics.md:242–244` — Epic 9 overview
- `_bmad-output/planning-artifacts/architecture.md:206–216` — CCD-3 standards-citation discipline
- `_bmad-output/planning-artifacts/architecture.md:230–242` — E9-D1 integration point, E9-D2 prefix dispatch strategy
- `_bmad-output/planning-artifacts/architecture.md:449–488` — Format Patterns (standards-citation, stack-effect comments)
- `_bmad-output/planning-artifacts/prd.md:369–384` — FR1–FR9 (numeric literal input); FR6 (leading sign); FR7 (case-insensitivity); FR47 (unprefixed preservation); NFR12 (extension discipline)
- `_bmad-output/implementation-artifacts/9-1-numeric-prefix-recogniser-scaffold-decimal-prefix.md` — Story 9.1 Dev Notes + Completion (scaffold design decisions inherited; in-body sign first implemented here)
- `_bmad-output/implementation-artifacts/9-2-hex-prefixes-standard-and-0x-antforth-extension.md` — Story 9.2 Dev Notes + Completion (case-fold design up front; M2 shared-helper debt flagged)
- `_bmad-output/implementation-artifacts/9-3-binary-and-character-prefixes.md` — Story 9.3 Dev Notes + Completion (4-handler sign-block quadruplication; M2 re-surfaced as debt; `.pref_negate` write-before-read invariant; `'c'` handler's "does NOT touch `.pref_negate`" decision — 9.4 extends `'c'` to READ it without writing)
- `docs/register-conventions.md` — authoritative EXX/shadow-register conventions (inherited, not edited)
- `src/number_prefixes.asm:1–97` — file header + scaffold comment block (9.1 + 9.2 + 9.3 content; 9.4 extends)
- `src/number_prefixes.asm:108–130` — `w_NUMBER_PREFIX_Q_cf` entry + dispatch chain
- `src/number_prefixes.asm:144–204` — `.pref_hash_entry` (Task 2.2, 4.3 targets)
- `src/number_prefixes.asm:206–220` — `.pref_negate` scratch + invariant comment (Task 1.2 rewrite target)
- `src/number_prefixes.asm:228–284` — `.pref_dollar_entry` (Task 2.3, 4.3 targets)
- `src/number_prefixes.asm:297–362` — `.pref_zero_entry` (Task 2.3, 4.4 targets; 0x peek precedent for `-` pre-pass)
- `src/number_prefixes.asm:370–425` — `.pref_percent_entry` (Task 2.3, 4.3 targets)
- `src/number_prefixes.asm:440–466` — `.pref_quote_entry` (Tasks 3, 4.5 targets)
- `src/number_prefixes.asm:586–606` — `char_to_digit_base16` (Task 5 audit; no edit)
- `src/compiler.asm:25–48` — TICK word (invariant: unchanged by 9.4)
- `Makefile:~2585–2855` — Story 9.3 REPL test blocks (tests 300–329); 9.4 appends starting at block 330
- `tests/number_prefixes_tests.fth:92–163` — Story 9.3 section (template for 9.4's appended section)
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-04-20.md` — 2026-04-20 scope change (drop lazy-load capstone). Confirms Epic 9 scope is unchanged by the sprint change; 9.4 proceeds as originally planned.
- Project memories:
  - `feedback_design_upfront.md` — case-fold and extensibility designed up front (9.2's foresight makes 9.4's case-insensitivity audit a no-code-change story)
  - `feedback_systematic_reference_check.md` — cross-reference Forth 2014 §3.4.1.3 before implementing
  - `feedback_standards_compliance.md` — leading `-` is standard, not an extension; do NOT mis-flag
  - `feedback_repl_tests_preferred.md` — REPL-piped tests
  - `feedback_adversarial_review.md` — reviews must find things; zero findings on a refactor + new dispatch arm is suspect
  - `feedback_follow_process.md` — don't ask for permission on obvious next steps
  - `project_tos_in_register.md` — BC=TOS discipline; pre-pass must preserve BC on fall-through
  - `feedback_assembler_operand_order.md` — Zilog dst-src order throughout

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]`

### Debug Log References

None — no debug sessions required. Each task was built and tested independently (the staged Task 1 → 2 → 3 → 4 sequence) and every intermediate build passed the 336-test regression suite before proceeding.

### Completion Notes List

1. **Staged landing executed per story plan.** Task 1 (dispatch reset) → Task 2 (shared helper) → Task 3 (`'c'` sign-apply) → Task 4 (`-` pre-pass) landed in strict sequence. Every intermediate state passed `make test && make test-repl` against the 336-test baseline before proceeding. Zero regressions introduced.

2. **`pref_check_sign` scoped as a local label** (`.pref_check_sign`) within `w_NUMBER_PREFIX_Q_cf` rather than as a global symbol. Reason: promoting it to global would break the `.pref_<x>` local-label scoping discipline used by all handlers. Placing it within the parent scope is semantically equivalent and keeps the existing convention intact. Call sites use `CALL .pref_check_sign`. Story spec's `CALL pref_check_sign` form is a cosmetic detail that the local-label scoping dictates.

3. **Sign-entry chosen form (Task 4.2) = MERGED dispatch** — single CP/JP chain in `.pref_sign_entry` that jumps directly to per-handler `.pref_<x>_enter_after_sign` labels without an intermediate `.pref_sign_commit` stage. The flag-toggle happens INSIDE each enter-after-sign (first instruction). Saves a 5-arm second dispatch chain vs the spec's canonical form. Readability was preserved — the merged form is still 12 lines total for `.pref_sign_entry`.

4. **Task 4.6 (optional shared after-sign routine) — NOT TAKEN.** Measured duplication at ~60 bytes across 5 entries (12 bytes each for the XOR-toggle + EXX ritual). A shared CALL-able routine would save ~30 bytes net after CALL/RET overhead, but would cross the EXX boundary mid-subroutine (an unusual pattern that reviewers would need to audit carefully). The story allows judgement here and says "defer if diff stays readable". Kept as-is. Documented in source comments.

5. **Shared `.pref_quote_ok` tail** between `.pref_quote_entry` and `.pref_quote_enter_after_sign`. Both paths flow into the same sign-apply + PUSH block, so the 'c' handler's sign handling is single-source despite two entry points. The success label was renamed from an implicit fall-through to an explicit `.pref_quote_ok` to accommodate the shared target.

6. **Existing test 329 MODIFIED, not just extended.** Test 329 was the 9.3/9.4 boundary guard that asserted `-%1010 ?` error — 9.4 invalidates this assertion by design. Rewrote test 329 in place to assert the new behaviour (`-%1010 .` → `-10  ok`) as the explicit behaviour-flip bookend. The .fth file's "9.3/9.4 boundary" section was replaced by the full 9.4 test block. Test numbering stays dense: 9.4 tests run 329–363.

   **Note on the original test 329 bug:** the pre-9.4 assertion used `printf '\-%%1010\r\n'` — the `\-` was a failed escape attempt that produced literal `\-%1010` as input (backslash included). The test "passed" not because `-%1010` fell through, but because antforth saw `\-%1010` (an invalid word) and reported `\-%1010 ?`. The test's semantic was wrong even pre-9.4. This was documented as a side-effect of my rewrite — new 9.4 tests use `printf -- '...'` to prevent leading-`-` misparsing.

7. **FR47 regression preservation.** All FR47 boundary cases work as expected — confirmed via tests 353 (`-42 .` DECIMAL → `-42`), 354 (`HEX -2A .` → `-2A`), 355 (`-foo ?`), 356 (`-ABC ?` DECIMAL). The `-` pre-pass cleanly falls through to `.pref_fast_false` whenever the second char is not in the prefix set. BC is never modified before the commit point, so NUMBER? sees an identical c-addr.

8. **Binary size delta: +192 bytes** (14,586 → 14,778). Within the +200 investigate threshold. Breakdown:
   - Task 1 (dispatch reset + invariant comment): +5 bytes
   - Task 2 (shared helper + 4× refactor): -31 bytes (net save)
   - Task 3 (`'c'` sign-apply): +14 bytes
   - Task 4 (`-` pre-pass + 5 `.pref_<x>_enter_after_sign`): +204 bytes
   - **Net: +192 bytes.** Slightly above the predicted +150 cap but well under +200. Task 4's contribution is on the high end of the 80–120 estimate because each of the 5 enter-after-sign entries includes: XOR toggle (6 bytes), PUSH BC/EXX/POP HL (3 bytes), count fetch + adjust + JP Z fail (10 bytes), CALL/JP C fail (5 bytes), JP convert (3 bytes) ≈ 27 bytes each × 5 = 135 bytes plus ~50 bytes for `.pref_sign_entry` itself plus ~20 for the 3-char check in `.pref_zero_enter_after_sign`. Refactoring Task 4.6 (shared routine) would reclaim ~30 bytes but adds complexity; not taken.

9. **EXX count verified = 20** per Dev Notes invariant (15 pre-9.4 from 5 handlers × 3 EXX each + 5 new from the 5 `.pref_<x>_enter_after_sign` entries × 1 EXX each). Confirmed via `grep -cE '^\s*EXX\b' src/number_prefixes.asm`. No accidental EXX in `.pref_check_sign` or `.pref_sign_entry` (both EXX-free as required).

10. **Manual smoke test results (Task 7.3):**
    - `-#42 .` → `-42  ok` ✓
    - `-$FF .` → `-255  ok` ✓
    - `-0xFF .` → `-255  ok` ✓
    - `-%1010 .` → `-10  ok` ✓
    - `-'A' .` → `-65  ok` ✓
    - `-#-5 .` → `5  ok` (double-sign XOR) ✓
    - `-42 .` (DECIMAL) → `-42  ok` (FR47) ✓
    - `- .` → `? Stack underflow` — bare `-` IS intercepted by FIND as the subtraction word, which tries to pop from an empty stack. Expected. Pre-pass never sees bare `-`.
    - `-foo` → `-foo ?` ✓
    - `HEX -$FF DROP BASE @ .` → `10  ok` (BASE=16 preserved) ✓
    - `-' DROP` → `-' ?` — observed. FIND does not compose `-'` (subtraction word then TICK). The 2-byte token `-'` reaches the recogniser: `.pref_sign_entry` peeks second char = `'` (0x27), dispatches to `.pref_quote_enter_after_sign`. There, count check `CP 4` fails (count=2 < 4), JP `.pref_quote_fail`. `.pref_negate` has been toggled but the next token's dispatch-level reset clears it — no leakage. Output: `-' ?` as observed. ✓ Behaviour preserved.

11. **Colon-body integration** (bonus check not required by Task 7). `: NEG42 -#42 ; NEG42 .` → `-42  ok` confirmed in REPL. The 9.1 outer-interpreter wire-in carries forward cleanly; Story 9.5 will verify this more thoroughly.

12. **Case-insensitivity audit conclusion (Task 5):** no new code required. `char_to_digit_base16` folds hex digits via `OR 0x20` (line 852). Both `.pref_zero_entry` (line 391) and my new `.pref_zero_enter_after_sign` (line 678) fold the `x`/`X` prefix letter via the same idiom. Non-letter prefix chars (`#`, `$`, `%`, `'`) have no case dimension. `'c'` middle byte is a transparent pass-through per Forth 2014 §3.4.1.3 — `'A'` and `'a'` remain distinct at 65 and 97 respectively (verified via existing 9.3 tests).

### File List

**Modified:**
- `src/number_prefixes.asm` — dispatch-level `.pref_negate` reset; `.pref_check_sign` shared helper (replaces 4× in-body sign-strip duplication); `'c'` handler's `.pref_quote_ok` sign-apply tail; `.pref_sign_entry` pre-dispatch handler; five `.pref_<x>_enter_after_sign` entry points for `#`, `$`, `0x`, `%`, `'c'`; file-header + scaffold comment updates.
- `tests/number_prefixes_tests.fth` — Story 9.4 additions (leading `-` sign + case-insensitivity audit section; ~30 new cases). Removed obsolete 9.3/9.4 boundary test (`-%1010` fall-through guard) since 9.4 invalidates it by design.
- `Makefile` — Rewrote test 329 assertion from "fall through" to "parses as -10" (behaviour-flip bookend); appended Story 9.4 test block covering tests 330–363 (34 new tests).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — story 9.4 marked `in-progress`, then `review`.

**Untouched (confirmed):** `src/outer_interpreter.asm`, `src/antforth.asm`, `src/strings.asm`, `src/assembler.asm`, `src/dictionary.asm`, `src/compiler.asm` — TICK unchanged, subtraction `-` word unchanged. The 9.1 recogniser wire-in handles 9.4's dispatch without modification.

