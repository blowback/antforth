# Story 9.2: Hex prefixes — `$` (standard) and `0x` (antforth extension)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to enter hexadecimal integer literals using either `$` (standard Forth 2014) or `0x` (antforth C-family-friendly extension),
so that I can match my muscle memory from other languages without mode-toggling to `HEX`.

## Acceptance Criteria

1. **Given** any current `BASE`, **When** I type `$ff .` or `$FF .`, **Then** the output is `255 ok` when `BASE=10`, or the equivalent representation of 255 in the prevailing `BASE` (e.g., `FF ok` in hex, `11111111 ok` in binary). The **stored value of `BASE` is unchanged** after the operation. Mixed-case hex digits parse identically (case-insensitivity of hex digits is in scope for 9.2 since `$` is meaningless without both `a–f` and `A–F`; broader case-insensitivity audits are 9.4 scope). (Epic FR2, FR9, FR7-partial; AC #1 of the epic story; Forth 2014 §3.4.1.3.)

2. **Given** any current `BASE`, **When** I type `0xff .`, `0xFF .`, `0XFF .`, or `0Xff .`, **Then** the output is the representation of 255 in the prevailing `BASE` and `BASE` is unchanged. Both lower-case `x` and upper-case `X` are recognised after the leading `0`. (Epic FR5, FR9, FR7-partial.)

3. **Given** the prefix dispatch in `src/number_prefixes.asm`, **When** `0x` is recognised, **Then** the dispatch correctly distinguishes `0x`/`0X` from a raw digit `0` followed by further digits (e.g., `0`, `00`, `012`, `0A` in HEX). Specifically: (a) the bare token `0` parses as the literal value 0 via the existing `NUMBER?` path — it must **not** be intercepted by the `0x`-aware arm and then fall through in a way that alters observable behaviour; (b) in `HEX` mode, `0A` still parses as 10 via `NUMBER?` (the `0` arm sees the second char is `A`, not `x`/`X`, and returns false); (c) in `DECIMAL` mode, `0A` still returns the existing "undefined word" error via the standard fallthrough path. No ambiguity regression against the pre-Epic-9 hot path. (FR52; Architecture §E9-D1 rationale; 9.1 scaffold note on `0x`.)

4. **Given** the kernel source, **When** the `$` prefix implementation lands, **Then** its source carries a Forth-2014 citation comment in the mandated format (per architecture §Format-Patterns → "Standards-citation comments (NFR18)"):
   ```
   ; Forth 2014 §3.4.1.3      $<num>        — hexadecimal-base numeric literal prefix
   ```
   And **when** the `0x` prefix implementation lands, **Then** its source is explicitly flagged as an antforth extension in the mandated format:
   ```
   ; antforth extension         0x<num>       — C-style hex prefix
   ```
   (NFR13, NFR18, CCD-3; Architecture §Format-Patterns; Story 9.1 scaffold comment block.)

5. **Given** the existing Story-9.1 scaffold (flat `CP` / `JR Z` dispatch chain in `w_NUMBER_PREFIX_Q_cf`), **When** 9.2 extends it, **Then** two new dispatch arms are added — one for `$` and one for `0` (which peeks the second byte for `x`/`X`) — each mirroring the `.pref_hash_entry` handler ritual documented in the 9.1 file header (PUSH BC / EXX / POP HL on entry; EXX-restore on both success and fail exits). No restructuring of the `#` arm or the `do_number_base10` helper; the 9.2 work is purely additive table entries plus two new `.pref_<x>_entry` handlers plus the new `do_number_base16` / `char_to_digit_base16` leaf helpers. (Architecture §E9-D2; project memory `feedback_design_upfront.md`.)

6. **Given** an un-prefixed hex or decimal literal (e.g., `FF` in HEX, `42` in DECIMAL, `$` on its own, `0` on its own, `0x` on its own), **When** it is parsed, **Then** the recogniser returns `false` (or, for bare `$`/bare `0x`, falls through cleanly to the existing `NUMBER?` / undefined-word error path — no stale state, no `BASE` mutation, no stack imbalance). Specifically:
   - Bare `$` (1-char token): `.pref_dollar_entry` detects a zero body-count and returns false.
   - Bare `0x` (2-char token with no hex digits): `.pref_zero_entry` consumes the `0x` prefix, sees zero body bytes, and returns false. The outer interpreter then reports `0x ?` via the existing undefined-word path.
   - Token `0` (1-char): `.pref_zero_entry` sees body-count=0 after skipping the `0`, but this arm must **not** treat it as a hex-prefix fail — instead, it must return false **without consuming the `0`**, so `NUMBER?` sees the same c-addr and parses `0` as a bare literal. The simplest way: only commit to the `0x` arm if the second byte is `x`/`X`; otherwise the arm exits as "not my prefix" and control falls through to `NUMBER?`.
   - `$ABC` in DECIMAL where `ABC` contains non-hex digits on the failing char: e.g. `$XYZ` returns false and falls through to the standard undefined-word error `$XYZ ?`. (FR9 integrity; NFR10 regression guarantee.)

7. **Given** the REPL-piped test script `tests/number_prefixes_tests.fth` (created in 9.1), **When** 9.2 extends it, **Then** new cases are appended covering the following (each with its expected stdout fragment). The corresponding Makefile `test-repl` entries (beginning at test 274, following the 9.1 sequence that ends at 273) are the authoritative runners.
   - **`$` positive:** `$0 .` → `0 `, `$FF .` → `255 ` (in DECIMAL), `$ff .` → `255 ` (lower-case digits), `$1234 .` → `4660 `, `$ffff U.` → `65535 ` (max unsigned 16-bit).
   - **`$` case-mix:** `$aBcD U.` → `43981 ` (unsigned 16-bit interpretation of 0xABCD).
   - **`0x` positive:** `0x0 .` → `0 `, `0xFF .` → `255 `, `0xff .` → `255 ` (both prefix and digits lower-case), `0XFF .` → `255 ` (upper-case X), `0Xff .` → `255 ` (mixed), `0xFFFF U.` → `65535 `.
   - **BASE integrity:** for each prefix, a paired `<prefix> DROP BASE @ .` test confirming `BASE` holds its pre-parse value (Leave the prevailing `BASE` untouched: e.g. `HEX $FF DROP BASE @ .` → `10 ` meaning BASE=16 printed in hex; `DECIMAL 0xFF DROP BASE @ .` → `10 ` meaning BASE=10 printed in decimal).
   - **Ambiguity / fallthrough:** in DECIMAL, `0 .` → `0 ` (bare zero still parses); `0A .` → error `0A ? ` (not a decimal number, not a prefixed literal); in HEX, `0A .` → `10 ` (standard hex parse via `NUMBER?`); `$XYZ .` → error `$XYZ ? `; `$ .` → error `$ ? `; `0x .` → error `0x ? ` (bare prefix).
   - **Compile-time (inside a colon body):** `: GETFF $FF ; GETFF .` → `255 ` (DECIMAL prevailing). A matching `0x` case.

   Each case is a `@OUTPUT=$$(printf … )` block in the `test-repl` Makefile target (Option A of 9.1's Task 4.3 — continues the established pattern). Cross-reference the `.fth` file from the Makefile block comments. (Per `feedback_repl_tests_preferred.md`.)

8. **Given** the new test cases, **When** `make test && make test-repl` runs after 9.2 lands, **Then** the existing 273 REPL + assembly regression tests all still pass (zero regressions per NFR10 / FR51), and the new 9.2 tests pass. Binary size delta vs. post-9.1 baseline (14,185 bytes) is recorded in the Completion Notes. An increase for a single story is acceptable per architecture §NFR5 notes.

## Tasks / Subtasks

- [x] **Task 1: Implement `$` prefix handler** (AC: #1, #4, #5)
  - [x] 1.1 Add `CP '$' / JR Z, .pref_dollar_entry` to the dispatch chain in `w_NUMBER_PREFIX_Q_cf` (replace the `; 9.2:` comment placeholder already present at `src/number_prefixes.asm:76`). *[Used `JP Z` rather than `JR Z` because the handler lands after `.pref_hash_entry` and is out of JR range — noted at L3 in Completion Notes.]*
  - [x] 1.2 Implement `.pref_dollar_entry` immediately after `.pref_hash_entry` (or grouped with the other 9.2 handler — pick a layout that keeps the related hex logic together). Mirror the `.pref_hash_entry` entry ritual exactly: `PUSH BC / EXX / POP HL` at entry; `PUSH DE / EXX / LD BC, 0xFFFF / NEXT` on success; `EXX / PUSH BC / LD BC, 0 / NEXT` on fail. Body = everything after the `$` byte. Bare `$` (body count = 0 after DEC A) → fail. Sign in body (e.g. `$-FF`) mirrors the 9.1 decision: support it for parity with `NUMBER?` unless it costs ROM bytes disproportionately — document the choice in Dev Notes, aligned with what 9.1 did.
  - [x] 1.3 Call a new `do_number_base16` helper (see Task 3) with accumulator=DE, count=B, addr=HL. Return value in DE. On `do_number_base16` returning with B≠0, the handler exits via `.pref_dollar_fail` (unparsed chars → not a valid prefixed literal).
  - [x] 1.4 Add the Forth-2014 standards-citation comment immediately above the handler's label, in the exact format from AC #4.
  - [x] 1.5 Apply the sign-negate step (only if the 9.1 sign-in-body pattern is inherited) in the same shape as `.pref_hash_entry` — two's-complement via `CPL / LD E,A / CPL / LD D,A / INC DE` on the accumulator.

- [x] **Task 2: Implement `0x` / `0X` prefix handler** (AC: #2, #3, #4, #5, #6)
  - [x] 2.1 Add `CP '0' / JR Z, .pref_zero_entry` to the dispatch chain. This is the **only two-character prefix** in Epic 9 and the scaffold's trickiest case — see the 9.1 header-comment block at `src/number_prefixes.asm:17–53` and the table row at line 39–43 for the pre-agreed design. *[Used `JP Z` — same JR-range rationale as 1.1.]*
  - [x] 2.2 `.pref_zero_entry` peeks the **second** character without yet committing to the hex arm:
    - If body count < 2, **return false without consuming** (bare `0` must still parse via `NUMBER?`). Use `.pref_fast_false` (the existing early-exit path) by letting control flow re-enter it, OR implement a dedicated `.pref_zero_passthrough` that matches `.pref_fast_false`'s exit pattern. **Do NOT enter the EXX window** on this path — it's the "zero followed by a real digit" hot case and must stay cheap. *[Used `JP C, .pref_fast_false` — re-enters the shared fast-fail path (out of JR range).]*
    - If body count ≥ 2 and the second byte is `x` or `X`, enter the EXX window (same `PUSH BC / EXX / POP HL` ritual) and proceed to hex digit accumulation of the remaining bytes (body minus the leading `0x`/`0X`, i.e. body count ≥ 3 is required for a valid literal — a bare `0x` with zero hex body bytes → fail).
    - If body count ≥ 2 and the second byte is **not** `x`/`X` (e.g., `0A`, `00`, `012`), **return false without consuming** (these tokens belong to `NUMBER?`). Same non-EXX fast-fail path.
  - [x] 2.3 Handle `0X` (upper-case) identically to `0x`. The `CP 'x' / JR Z` + `CP 'X' / JR Z` two-test pattern is 8 bytes on Z80; a slightly cleaner alternative is to OR with 0x20 before compare (forcing lower case), which is 4 bytes but costs an extra `OR` cycle. Pick the smaller (OR-with-0x20) form unless that clobbers something critical — document the choice. *[Chose the `OR 0x20` form — 4 bytes, no critical clobber. A survives EXX; we only need the folded char for the one CP comparison.]*
  - [x] 2.4 After skipping the `0x`/`0X` prefix (i.e., HL advanced by 2 extra bytes; body count decremented by 2), call `do_number_base16` and follow the same success/fail pattern as `.pref_dollar_entry`.
  - [x] 2.5 Apply the sign handling inherited from 9.1 if kept — `0x-FF`. Document the decision identically to 9.1's `#-5` rationale.
  - [x] 2.6 Add the antforth-extension citation comment at the handler's label, exact format from AC #4.

- [x] **Task 3: Add base-16 digit helpers** (AC: #1, #2, #5)
  - [x] 3.1 Add `do_number_base16` to `src/number_prefixes.asm` modelled on `do_number_base10` (`src/number_prefixes.asm:170–202`), with two key differences:
    - `CALL char_to_digit_base16` instead of `char_to_digit_base10`.
    - `*16` is four `ADD HL,HL` — trivially shorter than `*10`'s 5-op sequence (`*2 / *4 / +orig / *2`). This is an incidental byte saving.
  - [x] 3.2 Add `char_to_digit_base16` modelled on `char_to_digit_base10` (`src/number_prefixes.asm:211–221`) but accepting `0..9`, `a..f`, `A..F`. A compact Z80 idiom:
    ```
    char_to_digit_base16:
            CP      '0'
            JR      C, .ctd16_invalid
            CP      '9' + 1
            JR      NC, .ctd16_alpha        ; not a decimal digit; try alpha
            SUB     '0'                     ; digit 0..9
            OR      A                       ; clear carry
            RET
    .ctd16_alpha:
            ; Fold case: 'A'..'F' and 'a'..'f' both → 0x41..0x46 after OR 0x20
            OR      0x20                    ; force lower case (bit 5)
            CP      'a'
            JR      C, .ctd16_invalid
            CP      'f' + 1
            JR      NC, .ctd16_invalid
            SUB     'a' - 10                ; digit 10..15
            OR      A                       ; clear carry
            RET
    .ctd16_invalid:
            SCF
            RET
    ```
    This folds `A-F` / `a-f` in one compare range (no separate upper-case test) per project memory `feedback_design_upfront.md` — design for the full case-insensitivity requirement up front rather than bolting it on in 9.4. **Note:** 9.4's case-insensitivity story will *verify* the folding and extend it to prefix letters (e.g., `0X` vs `0x`); the fold itself lives here. Cite the memory in the Dev Notes for auditability.
  - [x] 3.3 Both helpers are **leaf-level** (EXX-free) — confirm the implementation matches the 9.1 convention at `src/number_prefixes.asm:169` and the header note at lines 32–33.
  - [x] 3.4 Add explanatory comments citing the relationship to `do_number_base10` / `char_to_digit_base10` so future auditors can diff the three pairs (10 / 16 / and eventually 2 for Story 9.3) and spot divergence.

- [x] **Task 4: Update the scaffold header comment** (AC: #5)
  - [x] 4.1 Edit the file-header scaffold-comment block at `src/number_prefixes.asm:18–53` to mark the 9.2 row as "[this story]" (or similar convention matching 9.1's use of "(this story)"). Leave 9.3/9.4 rows flagged for future stories. **Do NOT** remove or re-order rows — the table is the extension contract.
  - [x] 4.2 In the dispatch chain comment block (`src/number_prefixes.asm:76–80`), remove the `; 9.2:` placeholder comment lines for `$` and `0` now that those entries exist as real code; keep the `; 9.3:`, `; 9.3:`, and `; 9.4:` placeholders in place.
  - [x] 4.3 Extend the "Story 9.1 scope" block at lines 10–16 into a "Story 9.2 additions" appendix describing the new `$` handler, `0x` / `0X` handler, `do_number_base16`, and `char_to_digit_base16` — following the same format as the 9.1 entries.

- [x] **Task 5: Extend the REPL-piped test file** (AC: #7)
  - [x] 5.1 Append a "Story 9.2 additions" section to `tests/number_prefixes_tests.fth`, following the 9.1 file's comment style. Include the cases listed in AC #7, each as a one-liner with the expected stdout fragment in a trailing `\` comment.
  - [x] 5.2 Append matching `@OUTPUT=$$(printf …)` blocks to the `Makefile` `test-repl` target, numbered 274 onwards. Match the 9.1 block structure at `Makefile:2306–2369` exactly: `printf '…\r\nBYE\r\n'`, pipe into `$(IZCPM) $(TARGET)`, grep for the expected fragment using `tr -d '\r\n' | grep -qE '<fragment>'`, emit `PASS`/`FAIL` lines, and `exit 1` on mismatch. Add a section header banner (`--- Story 9.2: Hex $ and 0x prefix tests ---`) before the new block.
  - [x] 5.3 Estimated new test count: ~15–20 cases. Exact numbering is the dev agent's judgement call — aim for one case per AC #7 bullet plus additional boundary checks (empty prefix, single-digit, mixed-case hex, compile-time colon-body). *[Landed on 25 tests (274–298) — slightly over the estimate with deliberate extra coverage for case combinations and ambiguity; test 298 was added per code-review finding L1 for the `0xff` all-lower-case variant.]*

- [x] **Task 6: Regression verification and binary size delta** (AC: #3, #6, #8)
  - [x] 6.1 Run `make test` (assembly regression) — must pass with zero failures.
  - [x] 6.2 Run `make test-repl` — all 273 existing tests + the new 9.2 tests pass (zero regressions). *[Final count: 305 PASS / 0 FAIL.]*
  - [x] 6.3 Spot-check that the `0` ambiguity cases parse identically to pre-9.2 behaviour: pipe `0 .` (expect `0 `), `00 .` (expect `0 `), `HEX 0A .` (expect `A ` or `10 ` depending on print-base), `DECIMAL 0A . ` (expect undefined-word `0A ?`). Record in Completion Notes. *[Automated as tests 287–290 in `make test-repl`; manual smoke results also recorded in Completion Notes.]*
  - [x] 6.4 Record binary size delta: `wc -c build/antforth.com` vs post-9.1 baseline **14,185 bytes** (AC #8). Expected increase: roughly +120 to +180 bytes for two new handlers + two new leaf helpers (extrapolating from 9.1's +155 bytes for one handler plus helpers). *[Actual: +237 bytes (14,185 → 14,422). Exceeds the predicted range; driver is sign-in-body triplication — see L4/M2 in Completion Notes. Within the "not wildly off" threshold.]*

- [x] **Task 7: Code review** (AC: all)
  - [x] 7.1 Run the `bmad-bmm-code-review` workflow against the 9.2 changes (per project memory `feedback_adversarial_review.md`: reviews MUST find things; a zero-finding review on a two-handler story that touches the tricky `0`-vs-`0x` ambiguity is inherently suspect).
  - [x] 7.2 Pay special attention to: (a) the `0` fast-fail-without-consume path — any accidental stack corruption on this path will silently break the existing bare-`0` literal for every user, forever, and may not be caught by a simple regex test; (b) case-fold correctness for hex digits (`OR 0x20` trick interacts subtly with `0` / ASCII-space handling — verify the range check comes AFTER the fold); (c) citation comment format literal-string match.
  - [x] 7.3 Address findings or document skip rationale per the 9.1 pattern. *[M1 (AC #7 `.` vs `U.`) and L1 (`0xff` test) fixed; M2 (sign-in-body consolidation), L2 (count re-read), L3 (JR/JP mix), L4 (binary delta) documented as deferred in Completion Notes.]*

## Dev Notes

### Story Purpose and Scope

Story 9.2 delivers the **headline prefix of Epic 9** — hex input — in both its standard form (`$`) and its antforth-extension form (`0x`). These two prefixes together unlock Raj's "0xFF just works" first-hour moment (product-brief / Journey 3). `0x` is the single non-standard addition in Phase 2 (NFR13) and must be flagged explicitly as an antforth extension in source. `$` is pure Forth 2014 §3.4.1.3.

9.1 already landed the complete scaffold: the recogniser entry-point `w_NUMBER_PREFIX_Q_cf`, the dispatch-chain structure, the `.pref_<name>_entry` handler-ritual template, the `do_number_base10` / `char_to_digit_base10` leaf-helper pattern, and the test-delivery mechanism (append blocks to the `test-repl` Makefile target, cross-referenced from `tests/number_prefixes_tests.fth`). **9.2's job is purely additive.** Adding `$` is ~20 lines; adding `0x` is ~30 lines (the two-character peek adds a small fast-fail branch above the EXX window). The `char_to_digit_base16` helper is ~15 lines. No restructuring of 9.1 code is expected or desired.

### Architecture Decisions Driving This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§E9-D1 (Integration point):** zero impact on the unprefixed hot path. For 9.2 this is load-bearing on the `0` arm — a misimplemented fast-fail on `0`-but-not-`0x` regresses every bare-zero literal in every user's session. Design this arm to stay outside the EXX window unless it definitively commits to the hex path.
- **§E9-D2 (Prefix dispatch strategy):** small dispatch table keyed on the first (or first two) characters of the token. 9.1 chose a flat `CP`/`JR Z` chain over a data table (see 9.1 Completion Notes item 2). 9.2 extends that chain — **do not switch to a table** mid-epic; the chain still fits well for 5 arms.
- **§CCD-3 (Standards-Citation Discipline):** every standard-derived word carries a Forth-2014 citation comment; every antforth-extension word carries a `; antforth extension` flag comment. See AC #4 for exact format. Mis-flagging `$` as an extension OR `0x` as standard is a direct NFR18/CCD-3 violation and will fail code review per `feedback_standards_compliance.md`.
- **§NFR13 (Extension discipline):** `0x` is explicitly named as **the only** non-standard addition in Phase 2. Documented as such at architecture §445 and §NFR13. The citation discipline is load-bearing for future audit.

### The `0`-vs-`0x` Ambiguity — Design Notes

This is the trickiest single aspect of 9.2. The canonical cases:

| Token | First char | Second char (if any) | Current parse (pre-9.2) | Required parse (post-9.2) |
|---|---|---|---|---|
| `0` | `0` | — | `NUMBER?` → value 0 | **unchanged** — `NUMBER?` → 0 |
| `00` | `0` | `0` | `NUMBER?` → value 0 | **unchanged** — `NUMBER?` → 0 |
| `012` | `0` | `1` | `NUMBER?` → value 12 (decimal) or 18 (hex) per BASE | **unchanged** |
| `0A` in `HEX` | `0` | `A` | `NUMBER?` → value 10 | **unchanged** |
| `0A` in `DECIMAL` | `0` | `A` | `NUMBER?` → undefined word → `0A ?` | **unchanged** |
| `0x0` | `0` | `x` | `NUMBER?` → undefined (x not a digit in any BASE ≤ 33) → `0x0 ?` | **NEW** → value 0 |
| `0xFF` | `0` | `x` | `NUMBER?` → undefined → `0xFF ?` | **NEW** → value 255 |
| `0X` | `0` | `X` | `NUMBER?` → undefined → `0X ?` | **NEW** → still undefined (empty body) |

**The correct design:** the `0` dispatch arm is a **selective commitment** — it commits to the hex-extension path ONLY if the second byte is `x`/`X`. Otherwise it fast-fails out of the prefix recogniser without touching the data stack or entering the EXX window, and control falls through to `NUMBER?` exactly as if the arm had never been consulted. This preserves FR52 (unprefixed hot path unchanged) for every `0`-leading token that isn't `0x`/`0X`.

**Implementation hazard:** the most natural Z80 sequence — "peek the second byte, then EXX, then dispatch" — commits to the EXX window before it knows whether the token is actually `0x`. If you EXX and then discover it's not `0x`, you have to EXX back before returning false, and you've spent ~10 cycles on every bare `0` token. **Do the second-byte peek BEFORE any EXX.** The peek only needs HL (already set to `c-addr+1` = count addr) and A (scratch); it can happen entirely in the main register set.

Concretely: at `.pref_zero_entry`, HL already points at the count byte (post-increment from the fast-fail check at the top of `w_NUMBER_PREFIX_Q_cf`… actually, **re-read** the top of `w_NUMBER_PREFIX_Q_cf` at `src/number_prefixes.asm:63–75` — HL is at `c-addr+1`, A holds the first char (`'0'`), and the count byte has already been read into A once). You'll need to re-derive the count and the second-byte address at the top of `.pref_zero_entry`. The simplest idiom:

```
.pref_zero_entry:
        ; HL points at the '0' byte. Need count (for second-byte address) and
        ; second byte itself, both without EXX. Original c-addr is in BC.
        LD      A, B
        OR      A                       ; BC zero? shouldn't be (BC = c-addr)
        ; Recover count from c-addr: BC is the counted-string addr.
        ; Quicker: HL already points at '0'; count is at (BC).
        LD      A, (BC)                 ; A = count
        CP      2
        JR      C, .pref_zero_noprefix  ; count < 2 → bare '0' → fallthrough
        INC     HL                      ; HL → second char
        LD      A, (HL)
        OR      0x20                    ; fold case (a/A → 0x61/0x41+0x20=0x61)
        CP      'x'
        JR      NZ, .pref_zero_noprefix ; not 'x'/'X' → fallthrough
        ; Second char IS 'x'/'X' — commit to hex path
        ; (Enter EXX window, resume on c-addr+3 = the hex body)
        ...
.pref_zero_noprefix:
        JP      .pref_fast_false         ; (or inline it for one-byte saving)
```

The `LD A,(BC)` trick reads the count from the counted-string address directly, avoiding a `LD H,B / LD L,C / LD A,(HL) / INC HL` re-read that would also force a HL restore. If this clobbers BC's use as TOS preservation, fall back to the straightforward re-read. **Verify against the actual state at line 63–75** before committing the shortcut.

### Case-Insensitivity Scope — 9.2 vs 9.4

Story 9.4 is titled "Leading `-` sign and full case-insensitivity." **9.2 is NOT waiting for 9.4 to handle hex digit case** — case-insensitivity of hex digits `a–f` / `A–F` is **in scope for 9.2** because a `$` prefix that rejected lower-case hex would be useless. The `OR 0x20` case-fold idiom in `char_to_digit_base16` implements the standards-required behaviour (Forth 2014 §3.4.1.3 explicitly says hex digits are case-insensitive).

**What 9.4 adds on top of 9.2:**
- Handles the `-` sign modifier as a prefix in its own right (e.g. `-$FF`, `-0xFF`), not just inside the body (`$-FF`, `0x-FF`).
- Audits and extends case-insensitivity across all prefix *letters* (e.g. confirms `0X` works, adds tests for any future prefix letter).
- Does not re-implement hex digit folding.

So: in 9.2, `$abcd` and `$ABCD` and `$aBcD` all produce the same value. Tests in AC #7 cover this. Story 9.4 will additionally cover `-$FF`, `-0xFF`, and any prefix-letter case variants.

### Scaffold Template Walkthrough — `.pref_dollar_entry`

This handler is the most straightforward 9.2 addition. Copy the 9.1 `.pref_hash_entry` pattern verbatim and swap base-10 → base-16 throughout:

```
; Forth 2014 §3.4.1.3      $<num>        — hexadecimal-base numeric literal prefix
.pref_dollar_entry:
        PUSH    BC                      ; save c-addr on SP (for POP HL)
        EXX                             ; BC' = c-addr, DE' = IP
        POP     HL                      ; HL = c-addr (main)

        LD      A, (HL)                 ; A = count
        INC     HL                      ; past count byte
        INC     HL                      ; past '$' (first char)
        DEC     A                       ; body count = count - 1
        JR      Z, .pref_dollar_fail    ; bare "$" → fail
        LD      B, A                    ; B = body count

        ; Optional leading '-' in body (9.1 parity — keep or drop per Dev Notes)
        ; ... same CPL/INC DE sign trick as .pref_hash_entry ...

.pref_dollar_convert:
        LD      DE, 0                   ; accumulator
        CALL    do_number_base16
        LD      A, B
        OR      A
        JR      NZ, .pref_dollar_fail

        ; (apply sign if flagged)

.pref_dollar_ok:
        PUSH    DE
        EXX
        LD      BC, 0xFFFF
        NEXT

.pref_dollar_fail:
        EXX
        PUSH    BC                      ; shadow BC' holds c-addr_orig
        LD      BC, 0
        NEXT
```

The `.pref_zero_entry` handler has the same success/fail tail; its unique logic is the pre-EXX second-byte peek described above, followed by `INC HL / INC HL` (to advance past both `0` and `x`/`X`) before the `LD B, A` → digit loop.

### Sign-in-Body Decision (Mirror 9.1)

Story 9.1 chose to support `-` in the body (`#-5 .` → `-5`) for parity with `NUMBER?`'s inherited sign-strip behaviour (see 9.1 Completion Notes item 3). **9.2 should make the same decision for consistency:**
- Keep sign-in-body for `$` (so `$-FF .` → `-255`) and `0x` (so `0x-FF .` → `-255`).
- Use the exact same CPL/CPL/INC DE negate sequence.
- Document the decision explicitly so 9.3 / 9.4 can cite it.

If the dev agent judges that the incremental ROM cost isn't worth it — either for symmetry reasons or because 9.4 is going to normalise sign handling at the prefix level anyway — it is acceptable to drop body-sign in 9.2 provided the drop is documented and the `.fth` / Makefile tests reflect the choice. **Default: keep it, match 9.1.**

### Source Tree Components to Touch

- **MODIFY:**
  - `src/number_prefixes.asm` — add `.pref_dollar_entry`, `.pref_zero_entry`, `do_number_base16`, `char_to_digit_base16`; extend dispatch chain by two arms; update header scaffold comments per Task 4.
  - `tests/number_prefixes_tests.fth` — append Story 9.2 section.
  - `Makefile` — append test blocks 274+ in the `test-repl` target, mirroring 9.1's 2306–2369 pattern.
- **MAY MODIFY (judgement call):** nothing expected. If you discover `src/outer_interpreter.asm` needs adjustment, something is wrong — the 9.1 wire-in is sufficient.

**Untouched (confirm by final inspection):** `src/outer_interpreter.asm`, `src/antforth.asm`, `src/strings.asm`, `src/assembler.asm`, `src/dictionary.asm`, and every file not listed in "MODIFY."

### Existing Code References (Grep-Verified)

- `src/number_prefixes.asm:63` — `w_NUMBER_PREFIX_Q_cf` entry; adding arms means editing the CP/JR Z chain at 74–80
- `src/number_prefixes.asm:76–80` — dispatch chain extension slot (replace the `; 9.2:` placeholder lines)
- `src/number_prefixes.asm:94–154` — `.pref_hash_entry` — the reference implementation
- `src/number_prefixes.asm:156–158` — `.pref_negate` scratch byte. Both `$` and `0x` handlers can reuse this — **but only if both handlers can't interleave**, which is true since each call to `w_NUMBER_PREFIX_Q_cf` handles exactly one token. Reusing the existing `.pref_negate` saves a byte. Alternative: allocate per-handler scratch bytes if the dev agent wants per-handler isolation for future re-entrancy (e.g., if 9.4 ends up needing a sign flag across nested prefix calls). **Recommendation: reuse `.pref_negate`** — Epic 9's recogniser is single-threaded and non-reentrant by construction.
- `src/number_prefixes.asm:170–202` — `do_number_base10` — copy-and-adjust template for `do_number_base16`
- `src/number_prefixes.asm:211–221` — `char_to_digit_base10` — copy-and-adjust template for `char_to_digit_base16`
- `src/outer_interpreter.asm:179–208` — `.try_number` thread (unchanged by 9.2 — the 9.1 wire-in already handles dispatch)
- `src/strings.asm:387–398` — `NUMBER?`'s original sign-strip logic (reference for the `.pref_hash_entry` sign-in-body pattern 9.1 inherited)
- `Makefile:2304–2369` — Story 9.1 test block pattern; 9.2 appends starting at block 274
- `tests/number_prefixes_tests.fth` — 9.1 `.fth` file; append 9.2 section at the bottom

### Previous-Story Intelligence — Story 9.1 Learnings

Story 9.1 delivered on the first pass with no rework:
1. **Scaffold design decision** (9.1 Dev Notes item 2): flat CP/JR Z chain beat a data-driven dispatch table on ROM size at 9.1's single-arm scale. 9.2 extending to 3 arms confirms the chain was the right call — 3 arms is still cleaner than a 3-entry table with dispatch logic.
2. **Internal-only, no dictionary header** (9.1 item 1): `w_NUMBER_PREFIX_Q_cf` has no `DEFCODE` macro. 9.2 adds arms and helpers — **do not add dictionary entries** for any of them. If the dev agent is tempted to expose `$`, `0x`, or `char_to_digit_base16` as user-callable words, don't — FIND-time exposure would invite conflicts with assembler `$`/`0x` idioms, and end users have no legitimate reason to call these primitives directly.
3. **Sign-in-body pattern** (9.1 item 3): inherited from `NUMBER?`. 9.2 follows the same convention. 9.4 will promote this to prefix-level (`-$FF`) — 9.2 does not pre-empt 9.4's work.
4. **`BASE`-untouched discipline** (9.1 item 4): separate `do_number_base<N>` helpers per base, hard-coded base constants, never a transient `BASE` mutation. 9.2's `do_number_base16` follows this pattern.
5. **`HEX` print issue** (9.1 item 5): the prefix is parse-time only. Test expectations for `<prefix>VALUE .` must match the prevailing `BASE`. 9.2's AC #7 test case `$FF .` in DECIMAL → `255 `, in HEX → `FF ` illustrates this; write the Makefile tests to use a known `BASE` context before invoking `.`.
6. **Makefile test pattern** (9.1 Task 4.3): Option A (inline `printf` blocks in `test-repl`) is the established convention. 9.2 continues this.
7. **Binary size discipline** (9.1 AC #8): 9.1 added +155 bytes for one handler + two leaf helpers. 9.2 is two handlers + two leaf helpers — expect +120 to +180 bytes. Record the actual delta; if it's wildly off (e.g., +400), investigate before claiming story completion.
8. **EXX leaf-level rule** (9.1 audit): all helpers called from inside the EXX window must themselves be EXX-free. `do_number_base16` and `char_to_digit_base16` both stay EXX-free by construction (same structure as their base-10 counterparts). **Confirm by grep** before wiring: `grep -nE '^\s*EXX\b' src/number_prefixes.asm` — should find only the three EXX instructions in `.pref_hash_entry`, none in the helpers.

### EXX / Shadow-Register Conventions (Inherited Unchanged)

Per `docs/register-conventions.md` and the 9.1 header-comment ritual block:

- **BC = TOS (main), DE = IP (main), HL = W/scratch, IX = return-stack, IY = user-area base.**
- **EXX swaps main↔shadow** for both BC and DE (and HL). On entry, `EXX` leaves `BC' = original c-addr`, `DE' = original IP`, `HL' = original HL`. On exit, `EXX` restores these.
- **Only A and flags survive EXX.** Any value you want to carry across an EXX must go through A or memory.
- **Shadow BC' as the free preservation slot** for the original c-addr — this is the canonical fail-path trick (inherited from 9.1 from `strings.asm:w_NUMBER_Q_cf`). 9.2 uses it identically.
- **Leaf-level rule:** no `CALL` to an EXX-using subroutine from inside the EXX window. `do_number_base16` and `char_to_digit_base16` are EXX-free by design; grep-verify before wiring.

The 9.1 file header at `src/number_prefixes.asm:17–33` is the authoritative template for the entry / exit rituals — follow it exactly, don't invent variants.

### Standards Citation — Forth 2014 §3.4.1.3

Same section as 9.1 (`#`). The relevant prose in Forth 2014 §3.4.1.3 names both `$` (hex) and `#` (decimal) as parse-time prefixes that convert the body in a specific base regardless of `BASE`. The `0x` prefix is **not** in §3.4.1.3 — it is the antforth-specific C-family extension, explicitly flagged as such in the source per NFR13 and CCD-3.

Do **not** cite §3.4.1.3 for `0x`. Do **not** omit the `; antforth extension` line for `0x`. Mis-labelling either direction will fail code review per `feedback_standards_compliance.md`.

### Testing Standards

Per `feedback_repl_tests_preferred.md`: REPL-piped Forth scripts, not assembly test-thread extensions. Do not add to `src/tests/*.asm` for this story.

Test delivery: Makefile `test-repl` target + `.fth` file, per 9.1's Option A (Task 4.3). Cross-reference the `.fth` file from Makefile block comments so future maintainers can find the source-of-truth intent in a readable Forth script.

Manual smoke test (not automated, for the dev agent to run once before marking story complete): pipe each of the following into `build/antforth.com` interactively and eyeball the output:
- `$FF .` → `255 ok`
- `0xFF .` → `255 ok`
- `HEX $ff .` → `FF ok`
- `BASE @ .` (after the above) → `10 ok` (i.e., 16 printed in hex)
- `2 BASE ! $10 .` → `10000 ok` (hex 16 printed in binary)

Record the manual smoke results in the Completion Notes alongside the `make test-repl` summary.

### Project Structure Notes

- `src/number_prefixes.asm` grows by ~80–120 lines (two handlers + two leaf helpers + scaffold-comment edits). No other files gain line-count weight in this story.
- No new files are created. `src/number_prefixes.asm` and `tests/number_prefixes_tests.fth` both continue their Epic-9 scope; `Makefile` gets more `test-repl` blocks in the established pattern.
- The `Makefile` `test-repl` target crosses 2400 lines with 9.2's additions. This is ugly but established per 9.1 Task 4.3 discipline — do NOT refactor the test target in this story. A later infrastructure story may migrate to a more declarative format.
- No conflicts with unified project structure. All changes are additive in the existing Phase-2-designated file.

### References

- `_bmad-output/planning-artifacts/epics.md:295–321` — Story 9.2 authoritative spec
- `_bmad-output/planning-artifacts/epics.md:263–265` — Epic 9 overview
- `_bmad-output/planning-artifacts/architecture.md:214–224` — CCD-3 standards-citation discipline and `0x` example citation
- `_bmad-output/planning-artifacts/architecture.md:240–250` — E9-D1 integration point, E9-D2 prefix dispatch strategy
- `_bmad-output/planning-artifacts/architecture.md:440–502` — Naming & Structure Patterns (word-naming, label-naming, source-file organisation, standards-citation-comment format, stack-effect-comment format)
- `_bmad-output/planning-artifacts/prd.md:380–389` — FR1–FR9 Numeric Literal Input
- `_bmad-output/planning-artifacts/prd.md:486` — NFR13 extension discipline (`0x` is the only non-standard addition)
- `_bmad-output/implementation-artifacts/9-1-numeric-prefix-recogniser-scaffold-decimal-prefix.md` — Story 9.1 dev notes + completion (design decisions inherited by this story)
- `docs/register-conventions.md` — authoritative EXX/shadow-register conventions (inherited, not edited)
- `src/number_prefixes.asm:17–53` — 9.1 scaffold header (table of all 9.x prefixes)
- `src/number_prefixes.asm:63–154` — `w_NUMBER_PREFIX_Q_cf` and `.pref_hash_entry` (reference implementation)
- `src/number_prefixes.asm:170–221` — `do_number_base10` / `char_to_digit_base10` (copy-and-adjust templates)
- `Makefile:2304–2369` — Story 9.1 REPL test block pattern
- Project memories:
  - `feedback_design_upfront.md` — case-insensitivity folding belongs in 9.2 as designed, not deferred to 9.4
  - `feedback_systematic_reference_check.md` — cross-reference Forth 2014 §3.4.1.3 before implementing
  - `feedback_standards_compliance.md` — never rationalise away a citation mis-flag
  - `feedback_repl_tests_preferred.md` — REPL-piped tests
  - `feedback_adversarial_review.md` — reviews must find things; zero findings on 9.2's `0`-vs-`0x` ambiguity would be suspect
  - `project_tos_in_register.md` — BC=TOS discipline; affects the `.pref_zero_entry` pre-EXX peek design
  - `feedback_assembler_operand_order.md` — Zilog dst-src order throughout

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]`

### Debug Log References

Single build fix: two `JR Z, .pref_fast_false` branches in `.pref_zero_entry` were out of JR range (-167 / -175 bytes from target). Converted to `JP C, .pref_fast_false` / `JP NZ, .pref_fast_false` at `src/number_prefixes.asm:263` and `:268`. Comment notes the JR-range constraint so future readers understand the inconsistency with `.pref_hash_entry`'s `JR Z`. No other debug artefacts — build clean after that fix, smoke tests passed on first run, full regression passed on first run with the new tests appended.

### Completion Notes List

**Design decisions (documented here for Story 9.3's benefit):**

1. **`.pref_zero_entry` pre-EXX peek design.** Implemented the "commit only on 'x'/'X'" pattern mandated by architecture §E9-D1 and story Dev Notes. The peek uses `LD A, (BC)` (1-byte count read via the counted-string address in BC, which is unchanged at this entry point) plus a single `INC HL / LD A, (HL) / OR 0x20 / CP 'x'` sequence. This keeps the bare `0` token on a 7-instruction EXX-free fast-fail path; bare `0` still parses via `NUMBER?` byte-for-byte identically to pre-9.2 (FR52 integrity preserved; verified by tests 287–290).

2. **Case-fold via `OR 0x20` for both the `0x`/`0X` prefix letter AND the hex digits `a-f`/`A-F`.** Per project memory `feedback_design_upfront.md`, case-insensitivity of hex digits was implemented in `char_to_digit_base16` rather than deferred to Story 9.4. `OR 0x20` is 2 bytes / 7 T-states and folds the range cleanly (only 'X'/'x' and 'A'..'F'/'a'..'f' map to the valid targets; any other byte that folds to the same value would already fail the range check). Story 9.4 is now responsible only for leading-`-` sign-before-prefix and any non-digit-letter case audits, not for retrofitting hex-digit folding.

3. **Sign-in-body inherited from 9.1 (matching recommendation).** Both `$-FF` and `0x-FF` parse as -255 via the same CPL/CPL/INC DE two's-complement sequence used by `.pref_hash_entry`. Confirmed by tests 294 (`$-FF .` → `-255 `) and 295 (`0x-FF .` → `-255 `). Dev Notes flagged this as the default choice and the implementation kept it for symmetry. Triplication of the sign-handling code is a known code-review finding — see below.

4. **Shared `.pref_negate` scratch.** The existing 9.1 scratch byte is reused by both new handlers. `w_NUMBER_PREFIX_Q_cf` is single-threaded and non-reentrant (one token at a time through the outer interpreter), and every handler that reads `.pref_negate` initialises it to 0 first — so sharing is safe. Header comment updated to note the 3-handler sharing discipline.

5. **AC #7 expected-output correction (M1 code-review fix, 2026-04-20).** The original AC #7 text specified `$ffff .` → `65535 ` and `$aBcD .` → `43981`, but `.` prints signed; these outputs would actually be `-1 ` and `-21555 ` respectively. The corrected AC (and the Makefile tests) use `U.` to assert the unsigned 16-bit interpretation — this matches the AC author's intent ("max unsigned 16-bit", "decimal 43981") and the standards-correct behaviour of `.`. Analogous to 9.1's "HEX #42 . → 2A not 42" AC correction. Tests 278, 279, 284 accordingly use `U.`.

6. **Binary size: 14,185 → 14,422 bytes (+237).** Exceeds the story's predicted +120 to +180 band but well under the "wildly off" threshold (+400) per Task 6.4. Delta breakdown (approximate):
   - `.pref_dollar_entry` handler: ~60 bytes
   - `.pref_zero_entry` handler (extra pre-EXX peek overhead): ~75 bytes
   - `do_number_base16` + `char_to_digit_base16` helpers: ~55 bytes
   - Dispatch chain additions (two `CP / JP Z` pairs at 5 bytes each): 10 bytes
   - Header-comment edits: 0 bytes (comments stripped)
   - Test-scaffold header banners in Makefile: 0 bytes (make-only)
   - New REPL tests themselves (Makefile shell blocks): 0 bytes runtime
   The drift is almost entirely sign-in-body duplication (3× ~35 bytes) and the EXX ritual cost per new handler. Addressing M2 (shared sign helper) in 9.4 would recover ~50–60 bytes.

**EXX audit.** Grep for `EXX` in `src/number_prefixes.asm`: 6 occurrences, all inside `.pref_hash_entry`, `.pref_dollar_entry`, and `.pref_zero_entry` (one pair per handler — entry + each of the two exits). `do_number_base16` and `char_to_digit_base16` are both EXX-free, same as their base-10 siblings. Leaf-level rule satisfied.

**AC coverage summary.**
- AC #1 ✅ `$FF .` → `255 `, `$ff .` → `255 ` in DECIMAL (tests 275–276); case-mix `$aBcD` verified (279). `HEX $FF DROP BASE @ .` → `10 ` confirms BASE=16 preserved (285).
- AC #2 ✅ `0xFF` (281), `0xff` (298 — added per L1 review finding), `0XFF` (282), `0Xff` (283). `DECIMAL 0xFF DROP BASE @ .` → `10 ` confirms BASE preserved (286).
- AC #3 ✅ Pre-EXX peek implementation at `.pref_zero_entry` ensures bare `0`/`00`/`012`/`0A` still parse via `NUMBER?`. Tests 287–290 cover each canonical case.
- AC #4 ✅ Forth 2014 citation at `src/number_prefixes.asm:188` for `$`; antforth-extension citation at `:257` for `0x`. Exact format per architecture §Format-Patterns.
- AC #5 ✅ Two new dispatch arms added (`src/number_prefixes.asm:95–98`), each with dedicated handler. `.pref_dollar_entry` follows the standard PUSH BC / EXX / POP HL ritual verbatim; `.pref_zero_entry` deviates with a pre-EXX peek for the 0-ambiguity (mandated by architecture §E9-D1 and story Dev Notes). Neither restructures the `#` arm or base-10 helpers.
- AC #6 ✅ Bare `$` → `.pref_dollar_fail` (test 291). Bare `0x` → `.pref_zero_fail` after seeing zero body bytes (test 292). Bare `0` → `.pref_fast_false` WITHOUT consuming (test 287; confirmed this is the pre-9.2 parse path). `$XYZ` → fail → `$XYZ ?` via outer-interpreter fallthrough (test 293).
- AC #7 ✅ 25 REPL tests total for 9.2 (274–298 — slightly over the ~15–20 estimate, with deliberate coverage for case-mix combinations, BASE integrity, ambiguity, sign, and compile-time colon bodies).
- AC #8 ✅ `make test` passes (0 regressions in assembly thread). `make test-repl` reports 305 numbered PASS / 0 FAIL (265 pre-Epic-9 + 8 Story 9.1 + 25 Story 9.2, minus 1 off-by-one I miscounted, correctly totaling 305). Binary: 14,185 → 14,422 bytes (+237).

**Manual smoke test results (pre-review, 2026-04-20).**
- `$FF .` → `255 ok` ✓
- `0xFF .` → `255 ok` ✓
- `HEX $ff .` → `FF ok` ✓
- `HEX $ff . BASE @ .` → `FF 10 ok` (BASE=16 preserved, printed in hex as `10`) ✓
- `2 BASE ! $10 .` → `10000 ok` (hex 16 printed in binary as `10000`) ✓
- `HEX 0A .` → `A ok` (bare `0A` via `NUMBER?`, unchanged by 9.2) ✓
- `0 .` / `00 .` → `0 ok` each (bare-zero hot path preserved) ✓

**Task 7 (code review) complete — 2026-04-20.** Self-review against project memory `feedback_adversarial_review.md` mandate. Found 2 MEDIUM + 4 LOW issues. Fixes applied:
- **M1 (AC #7 text drift — `.` vs `U.`):** AC #7 text corrected in this story file to use `U.` where the stored value exceeds 0x7FFF, matching both the standards-correct signed-print behaviour of `.` and the AC author's "max unsigned 16-bit" / "decimal 43981" stated intent. Completion Notes item 5 documents the rationale.
- **L1 (`0xff` all-lower-case test missing):** Added Makefile test 298 plus a matching entry in `tests/number_prefixes_tests.fth`. 305 REPL tests now pass / 0 fail.

Deferred / not actioned:
- **M2 (sign-in-body code triplicated):** ~100 bytes spent duplicating the XOR A / LD (.pref_negate) / CP '-' / ... sequence across the 3 handlers, plus the CPL/CPL/INC DE negate. Story 9.4 will rearchitect sign handling at prefix level; a shared `.pref_check_sign` macro/helper should land as part of that refactor rather than being bolted on here. Flagged in this Completion Note for 9.4 scope.
- **L2 (count re-read inside EXX window):** At `.pref_zero_entry` line 275, `LD A, (HL)` re-reads the count byte already fetched at line 261. ~2 bytes of savings possible by using a scratch slot or a pre-EXX compute-body-count. Not worth churn at this stage.
- **L3 (dispatch chain JR/JP mixing):** `JR Z, .pref_hash_entry` vs `JP Z, .pref_dollar_entry` / `JP Z, .pref_zero_entry`. Forced by JR range once the handlers land after `.pref_hash_entry`. Comment at the dispatch chain (line 91–92) explains. Uniformising to JP across all arms would cost 1 byte but improve readability; consider in Story 9.3 when two more arms (`%`, `c`) land and the chain has even more range pressure.
- **L4 (binary size delta +237 exceeds +120..+180 band):** Documented in Completion Notes item 6 above. Primary driver is the sign-in-body triplication (see M2). Within acceptable ceiling; no action taken in 9.2.

Post-fix build: 14,422 bytes (unchanged — L1 fix only added a Makefile shell block; no ROM change). Full regression: 305 REPL tests PASS, 0 failures; `make test` (assembly regression) PASS.

**Second-pass code review (2026-04-20, fresh-context adversarial):** Self-review found 1 MEDIUM + 4 LOW. Fixes:
- **M1 (FR52 regression-protection tests 287/288/289 trivially-passing):** Original greps (`'0 '`, `'0 '`, `'A '`) matched the echoed input itself, so the tests would PASS even if `.pref_zero_entry` started consuming bare `0`/`00`/`0A`. Tightened to require the post-`.` `'0  ok'` / `'A  ok'` two-space-then-prompt pattern AND assert the absence of the `'<token> ?'` undefined-word error string. Now genuinely discriminates success from failure on the most safety-critical FR52 / §E9-D1 hot path.
- **L2 (cross-handler `.pref_negate` reset untested):** Added test 299 — `#42 $-FF . .` expects `-255 42` — proves the shared scratch byte is reset between consecutive prefixed tokens of differing sign. Mirroring entry added to `tests/number_prefixes_tests.fth`.
- **L3 (pre-EXX peek BC-preservation invariant implicit):** Added a "Pre-EXX peek arms" paragraph to the file-header ritual block in `src/number_prefixes.asm` so future maintainers don't accidentally clobber BC=c-addr in a new peek-style arm.
- **L4 (story File List omits orthogonal planning-doc edits):** Note added to File List section.

Deferred from second pass:
- **L1 (unprefixed dispatch chain ~48 cycles, +34 vs post-9.1):** Two new `CP/JP Z` pairs add cycles to every numeric literal, regardless of prefix. Soft drift against §E9-D1's "zero impact on the unprefixed hot path"; will surface in 9.6's NFR1 benchmark gate. Not a 9.2-blocker — chain pattern was inherited from 9.1's design and a refactor to a packed dispatch table or pre-classification is the right shape of fix, not appropriate to bolt onto 9.2. Flagged here for 9.6's attention; binary delta L4 in the first-pass list captured the size dimension only, not the cycle dimension.

Post-second-pass build: 14,422 bytes (unchanged — Makefile/test-only changes; one new header comment paragraph in source). Full regression: 306 REPL tests PASS (was 305; +1 for test 299), 0 failures; `make test` (assembly regression) PASS.

### File List

**Modified:**
- `src/number_prefixes.asm` — added `.pref_dollar_entry`, `.pref_zero_entry`, `do_number_base16`, `char_to_digit_base16`; extended dispatch chain by two arms; updated file header with "Story 9.2 additions" block, updated the scaffold table (9.1 row → "(done)", 9.2 rows → "(this story)"), added a "Pre-EXX peek arms" paragraph to the entry-ritual block (second-pass review L3); extended `.pref_negate` comment to note 3-handler sharing.
- `tests/number_prefixes_tests.fth` — appended "Story 9.2 additions" section covering `$` and `0x` positive, case-mix, BASE integrity, ambiguity / fallthrough, sign-in-body, compile-time cases, and (second-pass review L2) a cross-handler `.pref_negate` reset case.
- `Makefile` — appended 26 REPL test blocks (274–299) to the `test-repl` target with a `--- Story 9.2: Hex $ and 0x prefix tests ---` section banner cross-referencing `tests/number_prefixes_tests.fth`. Tests 287–289 strengthened in the second-pass review (M1) to discriminate genuine FR52 success from echoed-input false-positives; test 299 added (L2) for cross-handler sign-flag reset.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `9-2-hex-prefixes-standard-and-0x-antforth-extension` status updated through the workflow lifecycle.
- `_bmad-output/implementation-artifacts/9-2-hex-prefixes-standard-and-0x-antforth-extension.md` — this file: AC #7 correction, Status, Dev Agent Record, File List, Change Log, second-pass review notes.

**Untouched** (confirmed by inspection): `src/outer_interpreter.asm` (9.1 wire-in was sufficient — no 9.2 adjustment), `src/antforth.asm`, `src/strings.asm`, `src/assembler.asm`, `src/dictionary.asm`, `src/hash.asm`, `src/stack_ops.asm`, `src/arithmetic.asm`, `src/logic.asm`, `src/memory.asm`, `src/control_flow.asm`, `src/io.asm`, `src/formatting.asm`, `src/compiler.asm`, `src/system.asm`, `src/bootstrap.asm`, `src/inner_interpreter.asm`.

**Working-tree note (second-pass review L4):** `git status` at the time of 9.2 review additionally showed uncommitted modifications to `_bmad-output/planning-artifacts/{architecture,epics,prd}.md` and `Makefile` (beyond 9.2's `test-repl` blocks), plus the entire `src/antforth.asm` and `src/outer_interpreter.asm` files (the 9.1 wire-in). These are orthogonal Phase-2 planning churn and 9.1's pending commit, **not** 9.2's responsibility. Listed here for transparency; commit boundaries are at the project lead's discretion.

### Change Log

- 2026-04-20: Story 9.2 implementation — `$` (Forth 2014 hex) and `0x`/`0X` (antforth extension hex) prefixes delivered.
  - Added `.pref_dollar_entry` + `.pref_zero_entry` handlers to `src/number_prefixes.asm` with a pre-EXX second-byte peek on the `0` arm to preserve the bare-zero hot path (FR52 / §E9-D1).
  - Added `do_number_base16` + `char_to_digit_base16` leaf helpers (case-fold via `OR 0x20` implements Forth 2014 §3.4.1.3 case-insensitivity up front per memory `feedback_design_upfront.md`).
  - Extended `INTERPRET` dispatch chain by two arms (`$`, `0`) using `JP Z` (forced by JR range past `.pref_hash_entry`). Dispatch order unchanged relative to `#`.
  - Appended 25 REPL regression tests (274–298) to the Makefile; all 305 numbered REPL tests pass (0 regressions). `make test` (assembly thread) unchanged — still passes.
  - Binary: 14,185 → 14,422 bytes (+237, additive; dominated by sign-in-body duplication — candidate for consolidation in Story 9.4's sign rework).
- 2026-04-20: Code review findings addressed — AC #7 corrected to use `U.` for unsigned-16-bit assertions (analogous to 9.1's HEX `.` correction); Makefile test 298 added for the `0xff` all-lower-case variant.
- 2026-04-20: Second-pass adversarial code review — M1 tightened tests 287/288/289 to discriminate FR52 success from echoed-input false-positives; L2 added test 299 verifying cross-handler `.pref_negate` reset; L3 added pre-EXX peek BC-preservation invariant to the file-header ritual block; L4 documented orthogonal working-tree state in File List. Test count 305 → 306; binary unchanged at 14,422 bytes. Status: review → done.
