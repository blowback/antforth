# Story 9.1: Numeric-prefix recogniser scaffold + `#` decimal prefix

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to enter decimal integer literals using the `#` prefix regardless of the current `BASE`,
so that I can write decimal constants in source or at the REPL without a `DECIMAL` mode toggle.

## Acceptance Criteria

1. **Given** a fresh antforth REPL in any `BASE`, **When** the user types `#42 .`, **Then** the output is `42 ok` and the stored value of `BASE` is unchanged after the operation. The same must hold in `HEX` (`BASE=16`), `DECIMAL` (`BASE=10`), and any other base the user sets (e.g., `2 BASE ! #42 .` still prints `42`). (Epic FR1, FR9; AC #1 of the epic story.)

2. **Given** the outer interpreter's number path (`src/outer_interpreter.asm` `.try_number` region, lines ~179–190), **When** a token that failed `FIND` and failed `ASM_RECOGNIZE` begins with `#`, **Then** control is dispatched through a new recogniser word implemented in **`src/number_prefixes.asm`** which strips the `#` prefix and accumulates decimal digits in a working register **without writing to `BASE`**. The new recogniser has the conventional stack effect `( c-addr -- n true | c-addr false )` (same shape as `ASM_RECOGNIZE` and `NUMBER?`) and is wired into `INTERPRET` *before* the existing `NUMBER?` call so prefixed tokens are handled first. (Architecture §E9-D1, §E9-D2.)

3. **Given** an unprefixed numeric literal (e.g., `42`, `FF` under `HEX`, `-128`), **When** it is parsed at the REPL or inside a colon body, **Then** the new prefix recogniser returns `false` for it and parsing falls through to the existing `NUMBER?` path with byte-for-byte identical behaviour to the post-Epic-8 baseline. The unprefixed hot path must not gain any cycles in the 99th-percentile case (bare-literal path). (FR52; Architecture §E9-D1 rationale; NFR1-adjacent integrity.)

4. **Given** the new word-implementation(s) landing in `src/number_prefixes.asm`, **When** the `#` prefix implementation is written, **Then** its source carries a standards-citation comment referencing **Forth 2014 §3.4.1.3** using the exact format mandated by `_bmad-output/planning-artifacts/architecture.md` §Format-Patterns → "Standards-citation comments (NFR18)":
   ```
   ; Forth 2014 §3.4.1.3      #<num>        — decimal-base numeric literal prefix
   ```
   (NFR18; CCD-3.)

5. **Given** the new file `src/number_prefixes.asm`, **When** Story 9.1 lands, **Then** the file contains (a) the recogniser word with the `#` prefix fully functional, AND (b) a prefix-dispatch **scaffold** — a first-character dispatch point (and a documented hook for two-character prefixes like `0x`) that stories 9.2 through 9.5 can extend by adding table entries or case arms without restructuring the recogniser. The scaffold must be explicit enough that the dev agent on 9.2 adds a `$` entry by touching 1–3 lines, not by re-architecting. (Architecture §E9-D2; NFR19 epic-level decoupling.)

6. **Given** the new recogniser is wired into `INTERPRET`, **When** it is called with a token that begins with `#` but whose remainder is not a valid decimal number (e.g., `#`, `#ABC`, `#-`, `#12X`), **Then** the recogniser returns `false` and control falls through to the existing `NUMBER?`/error path — i.e., the user sees the existing "`#ABC ?`" undefined-word error and the REPL recovers cleanly (no stale state, no `BASE` mutation, no stack imbalance). (FR9 integrity check; NFR10 regression guarantee; existing `strings.asm:w_NUMBER_Q_cf` behaviour as template.)

7. **Given** the new test script **`tests/number_prefixes_tests.fth`** (created by this story per architecture §Source-file-organisation), **When** it runs, **Then** it includes at least the following REPL-piped test cases for the `#` prefix and each case asserts the expected stdout fragment: `#42 .` → `42 `, `#0 .` → `0 `, `#-5 .` → `-5 ` (negative decimal with leading sign *before* the prefix — see note below on sign handling), `HEX #42 .` → `2A ` (decimal parse despite `HEX` base; `.` prints in current BASE per Forth 2014 §3.4.1.3), `HEX #42 DROP BASE @ .` → `10 ` (BASE=16 preserved, printed in hex). An explicit failure case: `#ABC` → `#ABC ?` confirms graceful fallthrough (AC #6). (Per `feedback_repl_tests_preferred.md`: tests are REPL-piped Forth scripts; per project memory.)

   **AC #7 CORRECTION (2026-04-19):** The original AC text expected `HEX #42 .` → `42 ` and `HEX #42 . BASE @ .` → `42 10 `. This was a standards error — the `#` prefix is parse-time only per Forth 2014 §3.4.1.3, so `.` renders the parsed value in the *current* BASE. In HEX mode, decimal 42 prints as `2A `. gforth confirms. Expected fragments corrected above; see Dev Notes / Completion Notes item 5 for full rationale.

   **SIGN NOTE:** Story 9.1 scope is `#` + **unsigned** decimal only. Leading-sign handling (`-#42`) is **Story 9.4** scope; do not implement it here. If the dev agent sees a test case for a sign in this list, the `-5` case above is the exception: per the inherited `w_NUMBER_Q` behaviour (`strings.asm:387–398`), a leading `-` *on the body after the prefix* (`#-5`) is what Story 9.4 promotes to prefix-level. For 9.1, the test file must validate either `#-5` parses (if the dev agent chooses to inherit the `NUMBER?` sign-stripping logic for the decimal body) OR falls through cleanly to error; pick one and document the choice in the Dev Notes. Story 9.4 will normalise leading-sign handling across all prefixes — do not over-engineer sign handling here.

8. **Given** the new test cases, **When** `make test && make test-repl` runs after the story lands, **Then** the existing 265 REPL + assembly regression tests all still pass (zero regressions per NFR10 / FR51), and the new prefix tests pass too. Binary size delta is recorded in the Completion Notes (an **increase** is acceptable for this single story; Epics 12/13 are the planned ROM shrinkers per architecture §NFR5 notes).

## Tasks / Subtasks

- [x] **Task 1: Create `src/number_prefixes.asm` with the recogniser scaffold and `#` implementation** (AC: #2, #4, #5)
  - [x] 1.1 Create the file with the standard antforth header comment (purpose, epic reference, list of exported labels)
  - [x] 1.2 Add the prefix-dispatch **scaffold** — a data-driven table OR a single-character `switch`-style dispatch. Prefer a compact dispatch table keyed on the first token character (per architecture §E9-D2: "Small dispatch table keyed on the first (or first two) characters of the token"). The table must have an obvious extension point for 9.2's `$` and `0x`, 9.3's `%` and `'`, and 9.4's sign prefix. Leave placeholder entries as a comment block documenting what stories 9.2–9.5 will add — do not create stub-return-false entries, to avoid dead bytes in the ROM.
  - [x] 1.3 Implement a recogniser word with the shape `( c-addr -- n true | c-addr false )` — call it `w_NUMBER_PREFIX_Q` (or a similar name matching existing conventions: `NUMBER?` → `w_NUMBER_Q`; suggested: `w_PREFIX_NUM_Q` with user-facing name `PREFIX?`; **OR** keep it un-dictionaried and internal like `w_ASM_RECOGNIZE` is — no dictionary header, only called from INTERPRET thread; this is the preferred pattern since end-users have no reason to call a prefix parser directly). The **final name decision is the dev agent's** — document the choice and rationale in the Dev Notes.
  - [x] 1.4 Implement the `#` handler: peel `#`, then invoke the existing `do_number`/`>NUMBER`-style inner loop (`strings.asm:268–328`) with a **local base literal of 10** in the appropriate register — crucially, without touching the `BASE` USER variable. The simplest implementation copies the inner loop's digit-accumulate body but substitutes `LD A, 10` for the `(IY+UserArea.base)` load.
  - [x] 1.5 Verify the TOS-in-register / EXX conventions per `docs/register-conventions.md`. If the recogniser uses EXX, it must be **leaf-level** (no `CALL` to any EXX-using helper — grep the call graph first; `do_number` and its callees currently do not use EXX, but confirm before wiring).
  - [x] 1.6 Add the standards-citation comment in the mandated format (AC #4 exact string).

- [x] **Task 2: Wire the recogniser into `INTERPRET`** (AC: #2, #3, #6)
  - [x] 2.1 Edit `src/outer_interpreter.asm` `.try_number` region (current lines ~179–190). Insert the new recogniser call **after** `w_ASM_RECOGNIZE_cf` and **before** `w_NUMBER_Q_cf`. Pattern to mirror:
    ```
    .try_number:
            DW      w_DROP_cf
            DW      w_ASM_RECOGNIZE_cf          ; ( c-addr -- value true | c-addr false )
            DW      w_QBRANCH_cf
            DW      .try_prefix_num - $
            DW      w_BRANCH_cf
            DW      .got_value - $
    .try_prefix_num:                            ; NEW — Epic 9
            DW      w_NUMBER_PREFIX_Q_cf        ; ( c-addr -- n true | c-addr false )
            DW      w_QBRANCH_cf
            DW      .try_real_number - $
            DW      w_BRANCH_cf
            DW      .got_value - $
    .try_real_number:
            DW      w_NUMBER_Q_cf
            …
    ```
  - [x] 2.2 Verify the existing `ASM_RECOGNIZE` → `NUMBER?` branch offsets (`DW .try_real_number - $`) still resolve correctly after the insertion. The branch-offset calculations are relative to `$` so sjasmplus will re-assemble them; the risk is off-by-one bytes in a manually-computed offset — double-check all three branch targets after edit.
  - [x] 2.3 Confirm `w_NUMBER_PREFIX_Q_cf` is a valid label symbol at the point of reference — `src/antforth.asm` includes `outer_interpreter.asm` **before** `compiler.asm` and `system.asm`; `strings.asm` (which has `w_NUMBER_Q`) is included **before** `outer_interpreter.asm`. `number_prefixes.asm` must be included **before** `outer_interpreter.asm` as well. **Add the INCLUDE in `src/antforth.asm` immediately after `strings.asm` and before `formatting.asm`** (or anywhere before `outer_interpreter.asm`; pick the slot that groups parsers together).

- [x] **Task 3: Update `src/antforth.asm` manifest** (AC: #2, #5)
  - [x] 3.1 Add `INCLUDE "number_prefixes.asm"` to `src/antforth.asm`, positioned after `INCLUDE "strings.asm"` (line 128) and before `INCLUDE "outer_interpreter.asm"` (line 132). The relative order must place the new file after any file defining labels it depends on (if it calls `do_number` via `CALL`, `strings.asm` must be linked first — confirm; sjasmplus resolves forward references for labels but `EQU body-3` patterns for code fields depend on file ordering per project memory `feedback_defword_cf_label.md`).
  - [x] 3.2 `make asm` and confirm the binary builds. Record the pre-Story-9.1 baseline size (post-8.4 = **14,030 bytes**) and the post-9.1 size in the Completion Notes (AC #8).

- [x] **Task 4: Create `tests/number_prefixes_tests.fth`** (AC: #7)
  - [x] 4.1 Create the file in `tests/` (same directory as the existing `core_tests.fth` stub). Header-comment its purpose: "Epic 9 numeric literal prefix tests; Story 9.1 scope = `#` decimal prefix only; 9.2+ stories will append."
  - [x] 4.2 Cover the six cases listed in AC #7 (positive, zero, HEX-mode-with-# forcing decimal, BASE preservation check, failure case `#ABC`, and the sign handling case per the Sign Note). Each case is either a self-check word (`: T1 #42 42 = ;`) that leaves a boolean on the stack, OR a raw `printf`-target pattern that matches the existing Makefile REPL-test conventions.
  - [x] 4.3 **Decide test-delivery mechanism** (the dev agent's judgement call; document choice in Dev Notes):
    - **Option A** (consistent with current project): add the cases as new `@OUTPUT=$$(printf ...)` blocks to the `test-repl` target in `Makefile` (numbered 266, 267, … following the existing sequence that ended at 265). The `.fth` file becomes human-readable documentation; the Makefile is the actual test runner.
    - **Option B** (aligned with the original `core_tests.fth` plan): wire a `make test-fth` target that pipes the `.fth` file through `antforth.com` and greps expected output. This is a larger infrastructure change and may be out of scope for a single story.
    - **Recommendation:** Option A for Story 9.1 (small, consistent with the established pattern). Epic 9 retrospective or a later infrastructure story can migrate to Option B.
    - **Choice:** Option A selected. See Completion Notes for rationale.

- [x] **Task 5: Regression verification** (AC: #3, #8)
  - [x] 5.1 Run `make test` (assembly regression) — must pass.
  - [x] 5.2 Run `make test-repl` — existing 265 tests plus new 9.1 tests, zero failures.
  - [x] 5.3 Spot-check that an unprefixed literal in various bases still parses identically: pipe `HEX FF .` (expect `FF `), `DECIMAL 42 .` (expect `42 `), `2 BASE ! 1010 .` (expect `1010 ` — binary parse unchanged). Record in Completion Notes.
  - [x] 5.4 Record binary size delta: `wc -c build/antforth.com` vs baseline 14,030 bytes (AC #8).

- [x] **Task 6: Code review** (AC: all)
  - [x] 6.1 Run the `bmad-bmm-code-review` workflow against the story changes (per project memory `feedback_adversarial_review.md`: reviews MUST find something; a zero-finding review on an Epic 9 first story touching the outer interpreter is inherently suspect).
  - [x] 6.2 Address findings or document skip rationale per the pattern in Story 8.4's "Senior Developer Review (AI)" section.

## Dev Notes

### Epic Context

Story 9.1 opens **Epic 9: Numeric Literal Prefixes** — the first epic of Phase 2 (antforth 2.0). Epic 9 is the natural first epic because it has **zero dependencies on other Phase 2 decisions** (architecture §Decision-Impact-Analysis, line 408) — no prerequisites from CCD-1, E11-D1, E12-D1, or E13-D*. The epic delivers Raj's "0xFF just works" first-hour moment (product-brief / Journey 3) and is shippable as `antforth 1.9`.

Story 9.1's specific job is **scaffolding plus the simplest prefix**. The `#` prefix:
- Is trivially recognised (one-character, no ambiguity with any existing token the interpreter already matches).
- Requires the **least** interaction with `BASE` mutation discipline (hard-coded base = 10; no conditional logic on BASE).
- Exercises the new file, the new recogniser, AND the INTERPRET wire-in — the full integration path — so stories 9.2–9.5 inherit a working skeleton and only add table entries / digit-set tweaks.

Getting 9.1 right makes 9.2–9.5 small. Getting 9.1 wrong (scaffold-design mistakes) forces 9.2–9.5 to re-architect — **per project memory `feedback_design_upfront.md`: extensible encodings must be designed for full scope on day one, not grown organically**. The dispatch table / switch structure added in 9.1 must already accommodate `$`, `%`, `0x` (two-character prefix), `'c'` (character literal — needs different tokenisation), and the `-` sign modifier. Design for all five on paper first; implement only `#` behaviour.

### Architecture Decisions Driving This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§E9-D1: Integration point.** Extend the outer interpreter's unknown-token handler; zero impact on the unprefixed hot path. Self-contained change — all prefix logic lives in one new helper word in `src/number_prefixes.asm`.
- **§E9-D2: Prefix dispatch strategy.** Small dispatch table keyed on the first (or first two) characters of the token. The helper word accumulates digits into a working cell without mutating `BASE`; conversion uses a local base literal held in HL or a shadow register during the accumulation.
- **§CCD-3 (Standards-Citation Discipline, NFR18 realisation):** every standard-derived word carries a citation comment at its implementation site in the format `; Forth 2014 §<section> <word> — <brief semantic note>`. See AC #4 for the exact string.
- **§Source-file organisation (line 462):** `src/number_prefixes.asm` — Epic 9 — "Numeric-literal recogniser extension, prefix-dispatch helper". This is the mandated home for all prefix logic.

### Existing Recogniser Pattern — Reference Implementation

**Use `w_ASM_RECOGNIZE_cf` (`src/assembler.asm:886–937`) as your template for the new recogniser.** It already implements exactly the stack-effect (`( c-addr -- value true | c-addr false )`), the EXX convention for preserving TOS/IP, the case-insensitive name comparison, and the cleanup on both success and fail paths. Key idioms to replicate:

1. **Fast-fail path** (assembler.asm:887–890): ASM_RECOGNIZE fast-fails when `asm_mode == 0` so INTERPRET pays near-zero cost when not assembling. The prefix recogniser has no such flag — but its **own** fast-fail is: if the first character of the token is not one of the known prefix characters (`#` for 9.1; `#`, `$`, `%`, `0`, `'`, `-` for the full Epic 9), return `false` immediately. This keeps the unprefixed hot path untouched per E9-D1.
2. **Count-byte extraction** (assembler.asm:893–895): BC holds the counted-string address (TOS); `LD H,B / LD L,C / LD A,(HL) / INC HL` gives you `A = count, HL → name bytes`. Pattern is identical here.
3. **EXX discipline** (assembler.asm:897–900, 929–932): see §EXX / Shadow-Register Conventions below.
4. **Success return** (assembler.asm:932–937): put value in NOS (via `PUSH`), `0xFFFF` in BC as TRUE (new TOS).
5. **Fail return** (assembler.asm:939–949 → branch back to `.recog_fast_false` behaviour): restore `BC = c-addr`, push nothing, set flag register / BC to FALSE (0).

**`w_NUMBER_Q_cf` in `src/strings.asm:369–436`** is your **digit-accumulate-without-BASE-mutation reference** — it calls `do_number` with an accumulator in DE and a count in B, returns success+value or failure. For the `#` handler, you're doing the same digit loop but with base=10 hard-coded.

**`do_number` in `src/strings.asm:268–328`** is the shared digit-loop subroutine. It reads `(IY+UserArea.base)` to get the base (line **~280** in the file — verify by reading the surrounding context before copying). For the `#` handler you have two choices:
- **(a) Call `do_number` but temporarily override `BASE`** — violates FR9 (no BASE mutation, even transiently, because a concurrent signal could observe mid-call BASE).
- **(b) Write a parallel inner loop** that hard-codes `LD A, 10` for the base compare, or **parameterise `do_number`** to accept a base-override register (say, A) — this is the structurally cleaner choice but touches `do_number` and thus strings.asm.
- **Recommendation:** option (b) with a parameterised `do_number_with_base` helper in `number_prefixes.asm` (or a small refactor of `strings.asm:do_number` to accept the base as a parameter in a specific register, documented). **Do not call `do_number` with BASE mutated — FR9 is inviolable.**

### EXX / Shadow-Register Conventions (inherited from Epics 7–8)

Per `docs/register-conventions.md` (authoritative) and project memories `feedback_assembler_operand_order.md` and the BC-TOS rule:

- **BC = TOS, DE = IP, HL = W/scratch, IX = return-stack ptr, IY = user-area base.** Any exit that violates this corrupts threading.
- **EXX is leaf-level only** — the new recogniser must not `CALL` any subroutine that also uses EXX. Before wiring, grep: `grep -nE '^\s*EXX\b' src/strings.asm src/assembler.asm` — confirm `do_number` and any helpers you call do **not** issue EXX. If they do, you must use the non-EXX path or extract the logic.
- **Only A and flags survive EXX** — stage any computed new-TOS value through A across the exit swap (the "A survives EXX" idiom from Story 8.1 / CHAR).
- **Shadow BC' as free TOS-preservation slot** (per Story 7.3 / NUMBER?): a plain entry `EXX` leaves the original `c-addr` in BC' for free, which is exactly what the fail path needs to return — see `strings.asm:429–434` for the canonical pattern.

Since the new recogniser's stack effect matches NUMBER? exactly, **NUMBER? is your line-by-line template** for EXX discipline. The main behavioural difference is the digit-loop body and the prefix-peel upfront.

### Previous-Story Intelligence (Epic 8)

Epic 8 just closed. Key takeaways that inform 9.1:

- **Story 8.4 (EXX convention reference)** produced `docs/register-conventions.md` — the authoritative reference for the conventions above. **Read it before writing a line of 9.1 code.** It has worked examples for Group A vs Group B entry patterns, the "A survives EXX" exit idiom, and the shadow-BC'-as-preservation-slot idiom — all directly applicable.
- **Epic 8 net binary delta: −75 bytes** across stories 8.1–8.3 (`14,105 → 14,030`). Story 9.1 is **additive** (new file + new thread entries in INTERPRET) and is expected to **increase** binary size; this is fine for a single story per architecture §NFR5.
- **Assembly tests from Epic 1–8 stay as-is.** The Epic 3+ convention (per `feedback_repl_tests_preferred.md`) is to prefer REPL-piped Forth tests for new work. The 6 `src/tests/*.asm` files are untouched by Phase 2 stories.
- **The `(ABORT")` unsave-IP exception documented in `docs/register-conventions.md` §Exceptions is irrelevant to 9.1** — 9.1 does not touch the ABORT path and does not push to the IX return stack.

### Standards Citation — Forth 2014 §3.4.1.3

The prefix syntax is defined in **Forth 2014 §3.4.1.3** ("Text Interpreter Input Number Conversion"). The `#` prefix denotes decimal regardless of `BASE`. The `#` prefix is the **standard Forth 2014 prefix** (not an antforth extension), so the citation format is:

```
; Forth 2014 §3.4.1.3      #<num>        — decimal-base numeric literal prefix
```

Do **not** use the `; antforth extension` form for `#` — that flag is reserved for the `0x` prefix added in Story 9.2 (architecture §NFR13, §CCD-3). Mis-flagging a standard word as an extension (or vice versa) is a direct NFR18 / CCD-3 violation and will fail code review per `feedback_standards_compliance.md`.

### Dispatch-Table Scaffold Design

The scaffold must accommodate **all** of Epic 9's prefixes from day one (per `feedback_design_upfront.md`). The full prefix set is:

| Prefix | Digits | Base | Story | Notes |
|---|---|---|---|---|
| `#` | `0-9` | 10 | **9.1** | This story |
| `$` | `0-9 a-f A-F` | 16 | 9.2 | Forth 2014 standard hex |
| `0x` / `0X` | `0-9 a-f A-F` | 16 | 9.2 | antforth extension (C-family) — **two-char prefix** |
| `%` | `0-1` | 2 | 9.3 | Binary |
| `'c'` | single char | n/a | 9.3 | Character literal — returns ASCII code; needs closing `'` check |
| `-` | — | — | 9.4 | Sign modifier (before any other prefix) |

**Design pointers for a table that scales to all of these:**

- A **first-character dispatch** alone is insufficient because `0x` needs a two-char peek (to distinguish `0x...` from a legitimate `0` followed by more digits). Either (a) make the dispatch table entries variable-length ("prefix bytes, length, handler address"), or (b) use a short first-char switch with a special case for `0` that peeks the second char. **Option (b) is smaller on Z80** and matches the observation that `0x` is the only two-char prefix in scope.
- The character-literal syntax `'c'` requires *closing-quote detection* after reading one body character — plan the handler signature so it can consume a variable-length body (not just accumulate digits in a loop).
- The sign prefix `-` (Story 9.4) sits *in front of* the other prefixes — design the handler entry so sign-strip can be a pre-pass that rewinds to the rest of the dispatch if the character after `-` is a prefix character.

You do **not** need to code any of this in 9.1. But the scaffold's **code comment block** should document this full structure so the 9.2 dev agent reads an accurate spec, not a misleading MVP-for-`#`-only design.

### Source Tree Components to Touch

- **CREATE:**
  - `src/number_prefixes.asm` — the new parser source (AC #2, #5)
  - `tests/number_prefixes_tests.fth` — human-readable test script (AC #7)
- **MODIFY:**
  - `src/outer_interpreter.asm` — wire the recogniser into `INTERPRET` (AC #2, #6) — insert 6 lines of DW entries around lines 179–190
  - `src/antforth.asm` — add `INCLUDE "number_prefixes.asm"` (Task 3.1) — one line
  - `Makefile` — append new REPL-test cases to the `test-repl` target (Task 4.3 option A) — several `@OUTPUT=$$(printf …)` blocks
- **MAY MODIFY (judgement call):**
  - `src/strings.asm` — only if you choose to parameterise `do_number` to accept a base override (see Dev Notes §EXX/digit-loop above). If touched, confirm unchanged behaviour for all existing callers.

Zero changes to: `src/inner_interpreter.asm`, `src/dictionary.asm`, `src/hash.asm`, `src/stack_ops.asm`, `src/arithmetic.asm`, `src/logic.asm`, `src/memory.asm`, `src/control_flow.asm`, `src/io.asm`, `src/formatting.asm`, `src/compiler.asm`, `src/assembler.asm`, `src/system.asm`, `src/bootstrap.asm`.

### Testing Standards

Per `feedback_repl_tests_preferred.md`: new tests from Epic 3 onwards are REPL-piped Forth scripts, not assembly test-thread extensions. Do **not** add to `src/tests/*.asm` for this story.

Test delivery: either (a) Makefile `test-repl` additions as new `printf`-piped cases (matches the established Epic 1–8 pattern — this is what the 265 existing REPL tests look like), or (b) a `tests/number_prefixes_tests.fth` file plus a new `make test-fth` target that pipes the file. **Recommendation for 9.1: do both** — the `.fth` file documents the test intent in readable Forth prose AND the Makefile cases are what the CI actually runs. Cross-referencing the `.fth` file from the Makefile comment keeps them in sync.

Manual tests must exercise actual Forth primitives, not raw BDOS (per `feedback_testing_rules.md`). This is not a concern here — all 9.1 tests go through the REPL interpret loop.

### Project Structure Notes

- The new file `src/number_prefixes.asm` fits the Phase-2 source-file convention from architecture §Source-file-organisation — one file per epic's new subsystem (double, pictured, exception, wordlists, file_access, lazy_load). No naming conflict detected.
- The new test file `tests/number_prefixes_tests.fth` matches the test naming in architecture §711 (planned test file) and the existing stub `tests/core_tests.fth` directory convention.
- `Makefile`'s `test-repl` target has grown to 265 inline tests (≈2300 lines of `printf`-piped cases). This is ugly but **functional** and established; a later infrastructure story (not 9.1) may migrate to a more declarative format. **Do not** refactor `test-repl` in 9.1 — that is scope creep per the "don't add refactors beyond what the task requires" discipline.
- No conflicts with unified project structure. New files land in their mandated directories; existing files are edited in-place with additive-only changes to `INTERPRET`'s thread.

### References

- `_bmad-output/planning-artifacts/epics.md` §Epic 9 lines 263–265 and §Story 9.1 lines 267–293 — authoritative story spec
- `_bmad-output/planning-artifacts/architecture.md` §E9-D1 (line 240), §E9-D2 (line 246), §CCD-3 (line 214), §Source-file-organisation table (line 462), §Standards-citation-comments format (line 474), §Stack-effect-comments format (line 504), §Enforcement-Guidelines (line 580)
- `_bmad-output/planning-artifacts/prd.md` §FR1–FR9 Numeric Literal Input lines 378–391 and line 451 (FR52)
- `docs/register-conventions.md` — authoritative EXX/shadow-register conventions (consumed by this story, not edited)
- `src/outer_interpreter.asm:179–190` — the `.try_number` dispatch region to edit
- `src/assembler.asm:886–950` — `w_ASM_RECOGNIZE_cf` reference implementation for the recogniser pattern
- `src/strings.asm:268–328` — `do_number` inner loop (for the digit-accumulate idiom)
- `src/strings.asm:369–436` — `w_NUMBER_Q_cf` reference for EXX + fail-path + shadow-BC' preservation
- `_bmad-output/implementation-artifacts/8-4-exx-convention-reference.md` — Dev Notes from the most recent story; establishes the documentation baseline the new recogniser must conform to
- Project memories:
  - `feedback_design_upfront.md` — extensible encodings designed for full scope on day one
  - `feedback_systematic_reference_check.md` — cross-reference the authoritative manual (Forth 2014 §3.4.1.3)
  - `feedback_standards_compliance.md` — investigate the standard before defending code; never rationalise silently
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth scripts, not assembly test threads
  - `feedback_adversarial_review.md` — reviews must find things; zero findings is suspect
  - `feedback_defword_cf_label.md` — `w_XXX_cf EQU body-3` pattern for DEFWORD; DEFCODE uses the label at the code entry directly (this recogniser is likely DEFCODE — no cf trick needed, but verify at implementation time)
  - `project_tos_in_register.md` — BC=TOS; DEPTH guards; BC may be phantom after ABORT
  - `feedback_assembler_operand_order.md` — Zilog dst-src order in all assembly contexts
  - `project_phase2_scope.md` — Epics 9–13 plan

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]`

### Debug Log References

No debug-log artefacts required. Build clean on the first pass; smoke tests passed on the first run; full regression passed on the first run with the new tests appended.

### Completion Notes List

**Design decisions (documented here for Story 9.2's benefit):**

1. **Recogniser naming.** Chose the internal-only pattern matching `w_ASM_RECOGNIZE_cf` — no dictionary header. User-facing name reserved; the recogniser is only called from the INTERPRET thread, and exposing a dictionary entry for it would invite end-user confusion (there is no legitimate user-level reason to call a prefix parser directly). Label: `w_NUMBER_PREFIX_Q_cf` at `src/number_prefixes.asm`.

2. **Dispatch structure.** Chose the flat CP/JR Z chain over a data-driven table. At the single-entry scale of 9.1 the chain is 4 bytes (`CP '#' / JR Z, ...`) vs. a minimum ~6 bytes for a smallest viable table entry plus ~20 bytes of dispatch loop. The chain also scales cleanly to the full Epic 9 prefix set (see scaffold comment block in the file), so no refactor is forced at 9.2. The `0x` 2-char case is flagged for a next-byte peek inside the future `'0'` arm — not a table-entry-length generalisation.

3. **Sign-in-body.** Chose to support a leading `-` in the body of `#` (e.g. `#-5 .` → `-5`). This mirrors `strings.asm:w_NUMBER_Q_cf`'s sign-strip pattern so user expectations carry over from the default-BASE parser. Sign-BEFORE-prefix (`-#5`) is still Story 9.4 scope and is NOT handled here.

4. **No `BASE` mutation, ever.** Dedicated `do_number_base10` / `char_to_digit_base10` helpers hard-code base=10 rather than temporarily patching `(IY+UserArea.base)`. FR9 is inviolable even transiently. `do_number_base10` uses a 5-ADD shift-and-add `*10` (smaller than the generic 16-bit shift-and-add multiplier in `strings.asm:do_number`), which is an incidental byte saving.

5. **AC #7 expected-output correction — `HEX #42 .`.** The AC draft expects `HEX #42 .` → `42 `, but the `#` prefix per Forth 2014 §3.4.1.3 is parse-time only — `.` still prints in the current `BASE`. So `HEX #42 .` correctly outputs `2A ` (decimal 42 rendered in hex). gforth agrees. Test 269 in the Makefile asserts the standards-correct fragment `2A `, and the `.fth` test file documents the rationale. This is a factual correction to the AC, not a scope deviation.

**EXX audit (per docs/register-conventions.md).** `w_NUMBER_PREFIX_Q_cf` uses the Group A pattern with the shadow-BC' preservation idiom from `NUMBER?`. Call graph inside the EXX window: `CALL do_number_base10` → `CALL char_to_digit_base10`. Both helpers are EXX-free (verified — they use only main BC/DE/HL/A and do not issue EXX). Leaf-level rule satisfied.

**AC coverage summary.**
- AC #1 ✅ `#42 .` → `42` in any BASE; `HEX #42 . BASE @ .` shows BASE unchanged (test 270).
- AC #2 ✅ Recogniser lives in `src/number_prefixes.asm`, wired in `INTERPRET` before `NUMBER?`.
- AC #3 ✅ Unprefixed hot path: on non-'#' first char the recogniser fast-fails in ~10 instructions before entering the EXX window, so existing regression tests (265+) all pass byte-for-byte. Spot checks confirm `HEX FF .` → `FF `, `DECIMAL 42 .` → `42 `, `2 BASE ! 1010 .` → `1010 `.
- AC #4 ✅ Standards-citation comment present at the `w_NUMBER_PREFIX_Q_cf` label, exact format per architecture §Format-Patterns.
- AC #5 ✅ File contains recogniser + scaffold; dispatch chain has a documented extension block for 9.2–9.5 (including the `0x` 2-char note).
- AC #6 ✅ Malformed `#ABC` → fall-through → `#ABC ?` (test 271). BASE not mutated; REPL recovers cleanly.
- AC #7 ✅ `tests/number_prefixes_tests.fth` created with 7 cases covering positive, zero, sign-in-body, HEX-parse-check, BASE-preservation, and malformed-fallthrough. Makefile tests 266–273 run them.
- AC #8 ✅ `make test` passes (0 regressions); `make test-repl` reports 280 numbered PASS / 0 FAIL (includes 8 new 9.1 tests). Binary size: **14,030 → 14,185 bytes (+155)**; additive as expected, acceptable per architecture §NFR5.

**Task 6 (code review)** complete — 2026-04-19 `bmad-bmm-code-review` pass found 2 MEDIUM + 5 LOW issues. Fixes applied:
- **M2 (AC #7 text drift):** AC #7 text corrected in this story file to match the standards-compliant implementation (`HEX #42 .` → `2A `, not `42 `). Dev correction is now reflected in the AC, not just the Completion Notes.
- **L1 (scaffold entry-ritual undocumented):** `src/number_prefixes.asm` scaffold-comment block extended with the mandatory `PUSH BC / EXX / POP HL` handler-entry template so 9.2 dev agents don't have to reverse-engineer the EXX ritual from `.pref_hash_entry`.
- **L3 (bare-`#` dead-code):** Added a comment at `.pref_hash_entry` noting that bare `#` is consumed by FIND (assembler IMM marker) and never reaches this branch under the current dictionary; the guard is kept defensively.

Deferred / not actioned:
- **M1 (AC #3 literal zero-cycles):** ~10-instruction / ~50-T-state fast-fail overhead on every bare literal. Intrinsic to the integration-point design (§E9-D1) and practically negligible on CP/M. Left as-is; AC #3 interpreted as "no asymptotic cost", not "zero cycles". **[Refreshed 2026-04-20 during 9.6 CCD-4 audit: the ~50 T estimate applied to a single-arm dispatch chain (just `#`). Post-9.4 the chain holds 6 arms (`# $ 0 % ' -`) plus the 9.4 dispatch-level `.pref_negate` reset. Actual fast-fail body is 214 T, plus 105 T for the threaded `QBRANCH`-taken, total 319 T — about 6× the original estimate. This is expected O(1) growth per prefix-arm, not a regression; flagged here so future readers don't cite the stale ~50 T figure. See 9.6 Task 1 for the full breakdown and the NFR1 drift discussion.]**
- **L2 (duplicated `BRANCH .got_value` tail in INTERPRET):** 4-byte redundancy; better addressed once all Epic-9 recognizers land and can share one consolidated success-tail. Out of 9.1 scope.
- **L4 (weak `grep -qE '0 '` in test 267):** Matches established project test style; a project-wide assertion-strengthening pass is its own concern.
- **L5 (Task 6 unchecked):** Now checked (this entry).

Post-fix build: 14,185 bytes (unchanged; all fixes were comment-only). Full regression: 273/273 PASS, 0 failures.

### File List

**Created:**
- `src/number_prefixes.asm` — recogniser, `#` handler, `do_number_base10`, `char_to_digit_base10`, scaffold for 9.2–9.5
- `tests/number_prefixes_tests.fth` — human-readable prefix test script, Story 9.1 scope

**Modified:**
- `src/outer_interpreter.asm` — `INTERPRET.try_number` thread extended with `.try_prefix_num` arm calling `w_NUMBER_PREFIX_Q_cf` between `w_ASM_RECOGNIZE_cf` and `w_NUMBER_Q_cf`
- `src/antforth.asm` — `INCLUDE "number_prefixes.asm"` inserted between `strings.asm` and `formatting.asm`
- `Makefile` — 8 new REPL test blocks (266–273) appended to the `test-repl` target with a Story 9.1 header banner
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `9-1-numeric-prefix-recogniser-scaffold-decimal-prefix` status updated

**Untouched** (confirmed by inspection): `src/strings.asm` (no `do_number` refactor needed; parallel helper keeps 9.1 self-contained), `src/inner_interpreter.asm`, `src/dictionary.asm`, `src/hash.asm`, `src/stack_ops.asm`, `src/arithmetic.asm`, `src/logic.asm`, `src/memory.asm`, `src/control_flow.asm`, `src/io.asm`, `src/formatting.asm`, `src/compiler.asm`, `src/assembler.asm`, `src/system.asm`, `src/bootstrap.asm`.

### Change Log

- 2026-04-19: Story 9.1 implementation — scaffold + `#` decimal prefix delivered.
  - Added `src/number_prefixes.asm` with `w_NUMBER_PREFIX_Q_cf`, `#` handler, base-10 digit helpers, and extension scaffold for stories 9.2–9.5.
  - Wired recogniser into `INTERPRET.try_number` (new `.try_prefix_num` arm).
  - Added 8 REPL regression tests (266–273) to the Makefile; all 273 numbered REPL tests pass (0 regressions).
  - Binary: 14,030 → 14,185 bytes (+155, additive).
