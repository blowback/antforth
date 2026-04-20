# Story 9.5: Prefix reach — REPL, colon bodies, and assembler source

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want numeric literal prefixes to be recognised everywhere ordinary numbers are parsed — interactive REPL, compiled colon definitions, and inside `CODE` / `END-CODE` blocks,
so that the prefix grammar is consistent across the whole system (FR8) and my session's `BASE` is never silently mutated (FR9).

## Acceptance Criteria

1. **Given** an interactive REPL session in `HEX` mode, **When** I type `: DECNUM #100 . ; DECNUM`, **Then** the output is the representation of `100` (decimal one-hundred, printed in the prevailing BASE — `64 ` in HEX), and `BASE` remains `HEX` before and after both the definition step AND the invocation step. The same pattern holds for `-#100` (→ `-100`, printed as the two's-complement `FF9C` in HEX), `$ff` (→ 255 = `FF` in HEX, i.e. bit-identical), `$-ff` (→ -255), `0xff` / `0XFF`, `-0xff`, `%1010` (→ 10 = `A` in HEX), `-%1010`, `'A'` (→ 65 = `41` in HEX), `-'A'`. (Epic FR1–FR9; architecture §E9-D1.) **Test-coverage reduction note:** because each prefix handler is fixed-base (§E9-D2) and the compiled LIT stores the absolute value (BASE is not re-applied at runtime), parse-BASE independence is proven in colon-body context by one DECIMAL-prefix in HEX (test 371, `#100`) and one HEX-prefix in DECIMAL (test 372, `$ff`). The remaining HEX-mode variants rely on (a) their REPL HEX-mode coverage in 9.1/9.2/9.3/9.4 and (b) the architectural argument that the colon-body path adds only a STATE-sensitive compile-LIT wrapper around the same parse output.

2. **Given** an interactive REPL session in `DECIMAL` mode, **When** I type `: HEXNUM $ff . ; HEXNUM`, **Then** the output is `255 ` and `BASE` remains `DECIMAL`. The same pattern holds for the full prefix × sign cross-product in Story 9.1/9.2/9.3/9.4 as enumerated in AC #1, each verified to produce the expected DECIMAL representation with `BASE` unchanged. (Epic FR1–FR9.)

3. **Given** a `CODE` / `END-CODE` block (assembler mode), **When** a prefixed literal appears in the assembler source — e.g. `CODE MKFF BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE` (Zilog dst-first operand order per `src/assembler.asm:23-32`) — **Then** the prefix is recognised by the assembler source's number-parse path identically to the REPL path, and `MKFF .` prints `255`. The full prefix × sign cross-product is exercised inside CODE blocks: `#100`, `-#5`, `$FF`, `$-FF`, `-$FF`, `0xFF`, `0XFF`, `-0xFF`, `%1010`, `-%1010`, `'A'`, `-'A'`. Each CODE word round-trips its prefixed literal to an ordinary integer operand for a following `#` tag + `LD,` (or `C,` for single-byte data), and calling the word leaves the expected value on the data stack. (Epic FR8; architecture §E9-D1 — "single shared INTERPRET thread means no new wire-in needed for CODE".)

4. **Given** any prefix parse in interpret state (REPL input or REPL execution of a compiled colon body), **When** the parse completes (success or failure), **Then** `BASE` holds the same value it held immediately before the parse began (FR9). The BASE-integrity assertion is made explicit by the test: `BASE @ <test> BASE @ = ASSERT-NOT-ZERO` (or equivalent `BASE @ . … BASE @ .` for two snapshots). The test suite asserts integrity for every prefix in every parse context.

5. **Given** any prefix parse in compile state (inside a `: … ;` definition or inside a `CODE … END-CODE` body), **When** the definition is being compiled, **Then** `BASE` is not mutated during compilation OR execution of the defined word. This is verified by two separate snapshots: one immediately after the `;` or `END-CODE` terminator, and one immediately after the word is invoked. Both snapshots match the pre-definition value. (FR9; NFR2-adjacent integrity.)

6. **Given** a malformed prefixed literal inside a colon body (e.g. `: BAD #ABC ;`), **When** the compiler encounters it, **Then** compilation fails cleanly — the half-built word is unlinked via the existing `w_COMP_ERROR` path (`src/outer_interpreter.asm:216`), HERE is rolled back, and the REPL returns to interpret mode. No partial dictionary entry survives. The same error discipline applies inside `CODE … END-CODE` — a malformed prefix triggers `asm_cleanup` (the ABORT-time rollback hook at `src/assembler.asm:~406`). (Epic FR8; existing error-recovery infrastructure preserved.)

7. **Given** the REPL-piped test script `tests/number_prefixes_tests.fth`, **When** the Story 9.5 additions run, **Then** the new test block covers — at minimum — the cases enumerated in AC #1 through AC #6, with **before/after `BASE` snapshots** explicitly asserted for every colon-body and CODE-block case. Each test is a `@OUTPUT=$$(printf …)` block in the `test-repl` Makefile target continuing sequentially from test 363 (the last 9.4 test). Tests MUST apply the 9.2 M1 / 9.3 / 9.4-inherited strengthening discipline: positive cases assert the `'<value>  ok'` two-space-then-prompt pattern AND the absence of a `'<token> ?'` error marker; fail cases assert the error AND the absence of spurious numeric success.

8. **Given** the full Phase-1 REPL-piped test suite plus the 9.1–9.4 REPL-prefix test sub-suite, **When** run against the Epic-9 binary post-9.5, **Then** every pre-existing test passes unchanged — zero regressions per NFR9 / NFR10 / FR45–47. Binary size delta vs the post-9.4 baseline (14,787 bytes) is recorded in the Completion Notes. Expected delta: **0 bytes** — Story 9.5 is a test-only story, the recogniser is already wired into the single INTERPRET thread, so no assembly source modification is expected. If a reachability gap is identified during development (an unlikely but in-scope possibility), any corrective assembly delta is documented alongside the root-cause analysis in the Completion Notes.

9. **Given** the source-tree comment audit, **When** Story 9.5 lands, **Then** the scaffold-table block at `src/number_prefixes.asm:110–133` has its 9.5 row marked `(done — verification only, no new dispatch code)`. No new standards-citation comments are expected — the Forth 2014 §3.4.1.3 citations for each prefix word are already present from Stories 9.1–9.4 per CCD-3 / NFR17 / NFR18.

10. **Given** interactive REPL smoke of the CODE path on the emulator, **When** the dev agent runs the manual smoke checklist listed in the Dev Notes, **Then** each listed outcome matches — including the BASE-cross cases (`HEX` + define a colon with `#`; `DECIMAL` + define a CODE word with `0x`). Manual smoke results recorded in the Completion Notes.

## Tasks / Subtasks

- [x] **Task 1: Audit the existing Stories 9.1–9.4 test coverage against the three parse contexts** (AC: #1, #2, #3)
  - [x] 1.1 Re-read `tests/number_prefixes_tests.fth` lines 1–226 and the Makefile 9.1–9.4 test blocks (tests 266–363). Tabulate, per prefix (`#`, `$`, `0x`, `%`, `'c'`, plus the `-` sign modifier composing with each), whether each context is already exercised: interactive REPL (I), colon body (C), CODE block (A).
  - [x] 1.2 Expected baseline (grep-verified):
    - **REPL (I):** every prefix + sign variant covered by 9.1/9.2/9.3/9.4.
    - **Colon body (C):** partial — 9.2 tests 83–84 cover `: GETFF $FF ; GETFF .` and `: GETHEX 0x1234 ; GETHEX .` only. `#`, `%`, `'c'`, sign variants, and BASE integrity are NOT covered.
    - **CODE block (A):** zero coverage. No existing 9.x test exercises prefixed literals inside `CODE … END-CODE`.
  - [x] 1.3 Record the audit matrix in the Completion Notes section "Coverage audit (Task 1)". Any deviation from the baseline in 1.2 (e.g. if a test was added outside 9.2-83/84 that already covers a colon-body case) must be noted, not duplicated by 9.5's new tests.
  - [x] 1.4 **Verification-only nature of this story**: confirm by tracing the INTERPRET thread at `src/outer_interpreter.asm:179-196` that `w_NUMBER_PREFIX_Q_cf` is invoked for every non-word, non-register token regardless of STATE or asm_mode. Document the trace in the Dev Notes (already present — this task is to CONFIRM the documentation still matches the code).

- [x] **Task 2: Add colon-body test coverage for every prefix + sign variant + BASE integrity** (AC: #1, #2, #4, #5)
  - [x] 2.1 Append a Story 9.5 section to `tests/number_prefixes_tests.fth` with the banner:
    ```
    \ --- Story 9.5 additions: prefix reach across parse contexts ---
    ```
    Organise sub-sections by parse context: colon body first, then CODE block, then cross-context regression guards.
  - [x] 2.2 **Colon-body single-prefix coverage.** For each of `#42`, `-#42`, `$FF`, `$-FF`, `-$FF`, `0xFF`, `-0xFF`, `%1010`, `-%1010`, `'A'`, `-'A'`, add one test of the form:
    ```
    : F_<name> <prefixed-literal> ; F_<name> .      \ expect: <decimal value>
    ```
    The `.` prints in the prevailing BASE (typically DECIMAL for the baseline tests). Example: `: F_H1 $FF ; F_H1 .` → `255`.
  - [x] 2.3 **Colon-body BASE-cross coverage.** For `HEX` + decimal prefix and for `DECIMAL` + hex prefix, add tests of the form:
    ```
    HEX : F_DH #100 . ; F_DH DECIMAL        \ expect: 64   (100 decimal printed in HEX)
    DECIMAL : F_HD $ff . ; F_HD             \ expect: 255
    ```
    Each test resets BASE to DECIMAL (or the session's default) at the end so subsequent tests run in a predictable state. Do NOT leave a test in HEX mode — this has bitten 9.2/9.3 tests where a subsequent `.` prints in the wrong base.
  - [x] 2.4 **Colon-body BASE-integrity snapshot.** For each of `#`, `$`, `0x`, `%`, `'c'`, add one test that snapshots `BASE @` before defining, after defining, and after invoking the colon word, asserting all three snapshots match. Canonical form:
    ```
    BASE @ : F_B1 $FF DROP ; BASE @ F_B1 DROP BASE @       \ 3 snapshots on stack
    = -ROT = AND .                                          \ 1 if both matches, 0 otherwise
    ```
    Or, for readability and error isolation, three separate `BASE @ .` emissions interleaved with the operations. Choose whichever the dev agent finds clearest; the test scaffolding is free-form Forth. The critical invariant: neither `:` / `;` nor invoking the defined word mutates `BASE`. **(M2-risk mitigation note)**: if a `BASE @ = -ROT = AND` form is used, verify the Forth stack algebra BEFORE landing the test — a wrongly-factored test may pass for the wrong reason (e.g. comparing duplicates of the same snapshot). If uncertain, use three separate `BASE @ .` emissions — the Makefile `grep` can verify each snapshot independently.
  - [x] 2.5 **Colon-body compile-time error.** Add a test that a malformed prefixed literal inside a `:` definition triggers the compile-error path:
    ```
    : F_BAD #ABC ;                          \ expect: #ABC ?  (compile error aborts)
    ```
    Verify via the Makefile block that (a) the error marker `#ABC ?` appears and (b) no successful `ok` follows the `:` / `;` pair for `F_BAD`. Follow-on assertion: `F_BAD` is NOT defined afterwards — `F_BAD .` should itself report `F_BAD ?` as an undefined-word error (no half-built entry left). This closes AC #6.
  - [x] 2.6 **Numbering.** Colon-body tests start at test **364** (first free after 9.4's last at 363). Estimate: ~20 tests for AC #1/#2/#4/#5 + ~3 for #6 = ~23 cases. Exact numbering is the dev agent's judgement — aim for one test per enumerated variant.

- [x] **Task 3: Add CODE-block test coverage for every prefix + sign variant + BASE integrity** (AC: #3, #4, #5)
  - [x] 3.1 Establish the CODE-block test pattern. Template (Zilog dst-first operand order per `src/assembler.asm:23-32`):
    ```
    CODE MK_<name> BC PUSH, C <lo-byte> # LD, B <hi-byte> # LD, NEXT, END-CODE
    MK_<name> .                                \ expect: <decimal-value>
    ```
    For a prefix-literal ≤ 0xFF (single-byte): `BC PUSH, C <prefix-lit> # LD, B 0 # LD, NEXT, END-CODE` — pushes TOS, loads new TOS.low from the prefix literal, new TOS.high from 0, returns. For literals > 0xFF (e.g. `0x1234`): split manually or use a different construction (see 3.3).
  - [x] 3.2 **Single-byte prefix CODE coverage.** For each of `#100`, `-#5`, `$FF`, `$-FF`, `0xFF`, `0XFF`, `-0xFF`, `%1010`, `'A'`, `-'A'`, define a CODE word that loads that value into C (and 0 or 0xFF sign-extend into B) and verify the invocation prints the expected signed value. The negative cases require loading the sign-extended high byte too (e.g. `-#5` → 0xFFFB → `0xFF # B LD,`). Where the value's high byte is 0xFF, use `0xFF # B LD,` directly — this incidentally exercises a prefixed literal for the high byte as well, doubling the coverage per test.
  - [x] 3.3 **Multi-byte prefix CODE coverage.** For `0x1234`, define a CODE word that builds BC from the full 16-bit literal using an immediate 16-bit load: `BC PUSH, 0x1234 # BC LD, NEXT, END-CODE`. Verify `MK_1234 .` → `4660`. This exercises the BC-pair `LD` form with a prefixed 16-bit literal.
  - [x] 3.4 **BASE-cross CODE coverage.** Add two tests:
    ```
    HEX CODE MK_DEC BC PUSH, C #100 # LD, B 0 # LD, NEXT, END-CODE MK_DEC . DECIMAL
    DECIMAL CODE MK_HEX BC PUSH, C $ff # LD, B 0 # LD, NEXT, END-CODE MK_HEX .
    ```
    Verify prefix parsing works regardless of the prevailing BASE at assembly time. (Forth 2014 §3.4.1.3 compliance implies the prefix is parse-BASE-independent.)
  - [x] 3.5 **BASE-integrity across CODE definition.** Add one test that snapshots `BASE @` before `CODE`, after `END-CODE`, and after invoking the defined word. All three must match. This exercises AC #5's CODE-block half.
  - [x] 3.6 **CODE-block compile-time error.** Add a test that a malformed prefixed literal inside `CODE … END-CODE` triggers the ABORT-via-asm_cleanup path (operand order irrelevant — `#ABC` errors before any `LD,` is reached):
    ```
    CODE C_BAD #ABC BC PUSH, NEXT, END-CODE                 \ expect: #ABC ?  (ABORT rolls back)
    ```
    Verify the Makefile block asserts the error marker and that `C_BAD` is not defined afterwards (same as AC #6, but for the assembler path).
  - [x] 3.7 **Numbering continues.** CODE-block tests start immediately after Task 2's colon-body tests. Estimate: ~12 tests for AC #3/#4/#5 + ~2 for #6 = ~14 cases.
  - [x] 3.8 **Makefile printf escaping.** CODE-block tests embed multi-token commands on a single REPL line, separated by spaces (not CRLF). Example:
    ```
    printf 'CODE MK_FF BC PUSH, 0xFF # C LD, 0 # B LD, NEXT, END-CODE\r\nMK_FF .\r\nBYE\r\n'
    ```
    The `CODE … END-CODE` and its invocation are SEPARATE REPL lines (two `\r\n` pairs). Do NOT put them on one line — CODE and END-CODE must be parsed during interpret-state transitions, and a single REPL line is one INTERPRET invocation. (Precedent: Makefile tests ~751-807 all use the two-line form.)

- [x] **Task 4: Cross-context regression guards + FR47 preservation spot-checks** (AC: #8)
  - [x] 4.1 Add one "mixed" test that exercises all three contexts in one session:
    ```
    printf '#42 . : F $FF ; F . CODE C BC PUSH, 0xFF # C LD, 0 # B LD, NEXT, END-CODE C .\r\nBYE\r\n'
    \ expect: 42 255 255   (REPL prefix, colon-body prefix, CODE-block prefix)
    ```
    This verifies no state leakage between contexts — specifically that `asm_mode` is correctly set and cleared across the CODE / END-CODE boundary, and that `.pref_negate` (the sign flag) is not accidentally persisting across tokens or contexts.
  - [x] 4.2 Add FR47 regression spot-checks for each parse context:
    - Colon body: `: F42 -42 ; F42 .` → `-42 ` (unprefixed signed literal, NUMBER? owns). Confirms 9.4's `-` pre-pass does NOT capture `-42` even when reached via the compile thread. In DECIMAL explicitly.
    - CODE block: define a CODE word that uses a bare unprefixed literal like `42 # C LD,` (should work identically to `#42 # C LD,`'s effect when BASE=DECIMAL — both store 42). Verifies the INTERPRET thread's fallthrough from NUMBER_PREFIX? → NUMBER? still works inside the assembler context.
  - [x] 4.3 Run `make test && make test-repl`. ALL pre-9.5 tests (363 total) plus the new 9.5 tests must pass with zero regressions (NFR9, NFR10, FR45–47).
  - [x] 4.4 Record binary size delta. Expected: **0 bytes** (test-only story). Any delta > 0 requires an entry in Completion Notes explaining why assembly source was modified — and that entry must cite the specific reachability gap that drove the fix. A delta > 100 bytes on a verification story is a finding to escalate during code review.

- [x] **Task 5: Update the scaffold-table comment in `src/number_prefixes.asm`** (AC: #9)
  - [x] 5.1 In the scaffold-table block at `src/number_prefixes.asm:~110-133`, add a 9.5 row:
    ```
    ;   9.5    —         —     Verification only (done) — no new dispatch code.
    ;                          Story 9.5 adds ~35 REPL-piped tests proving
    ;                          prefix reach into colon bodies and CODE blocks.
    ;                          The single shared INTERPRET thread at
    ;                          outer_interpreter.asm:.try_number makes the
    ;                          three contexts (REPL / colon body / CODE block)
    ;                          already identical — 9.5 is the observational
    ;                          proof, not a new wire-in.
    ```
    This is a one-row table update; no other source changes. Avoid the "9.2, 9.3, AND 9.4 rows simultaneously current" mistake flagged as L3 in 9.4's review — the 9.4 row should remain `(done)` from 9.4's fix.
  - [x] 5.2 If the binary size delta from Task 4.4 is exactly 0 (as expected), no CCD-3 / NFR17 standards-citation entry is required — no new word, no new citation. Confirm explicitly in Completion Notes so the audit trail shows the decision was considered, not skipped.

- [x] **Task 6: Manual smoke on emulator** (AC: #10)
  - [x] 6.1 Run the following sequence interactively through `$(IZCPM) $(TARGET)` and record actual output in Completion Notes:
    - REPL in HEX: `HEX : DECNUM #100 . ; DECNUM BASE @ . DECIMAL` → `64 10 ok` (100 in HEX = 64; BASE=16 printed in HEX = 10).
    - REPL in DECIMAL: `: HEXNUM $ff . ; HEXNUM BASE @ .` → `255 10 ok`.
    - CODE block: `CODE MK_FF BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE MK_FF .` → `255 ok`.
    - CODE block + sign: `CODE MK_NEG BC PUSH, C -#5 # LD, B 0xFF # LD, NEXT, END-CODE MK_NEG .` → `-5 ok`.
    - Mixed context: `#42 . : F $FF ; F . CODE C_MIX BC PUSH, C 0xFF # LD, B 0 # LD, NEXT, END-CODE C_MIX .` → `42 255 255 ok`.
    - Compile-error (colon): `: BAD #ABC ;` → `#ABC ?` (and `BAD` undefined afterwards).
    - Compile-error (CODE): `CODE C_BAD #ABC BC PUSH, NEXT, END-CODE` → `#ABC ?` (and `C_BAD` undefined afterwards; dictionary rolled back).
  - [x] 6.2 If any manual smoke result diverges from expected, STOP and investigate. A divergence at this late stage of Epic 9 would indicate either (a) an undocumented interaction between INTERPRET and the recogniser, or (b) a test-harness quirk. Either way, root-cause BEFORE marking the story done.

- [x] **Task 7: Code review** (AC: all)
  - [x] 7.1 Run the `bmad-bmm-code-review` workflow against the 9.5 changes. Per project memory `feedback_adversarial_review.md`: reviews MUST find things. For a verification-only story, expected findings are:
    - Test-harness edge cases (escaping, numbering, grep robustness)
    - Coverage gaps (variants missed from the cross-product)
    - Scaffold-table formatting nits
    - Completion Notes completeness
  - [x] 7.2 Pay special attention to:
    - (a) **Test-numbering density.** 9.5 adds ~35 tests starting at 364. Verify the Makefile block's echo/assert pattern matches 9.4's (and 9.3's) exactly — a stray banner or a misnumbered test is a silent-regression vector.
    - (b) **CODE-block printf escaping.** The `#` character inside a printf format string is safe, but `$` must be escaped (`$$` in Makefile's `printf '...'`). Verify every `$FF`, `$ff`, `$-FF` inside a printf block uses `$$FF`, `$$ff`, `$$-FF`.
    - (c) **BASE-cross test cleanup.** Every `HEX … DECIMAL` test pair must leave BASE=DECIMAL at the end. A test that omits the closing `DECIMAL` pollutes the subsequent test's prevailing BASE. Grep-check every HEX in the new block for a matching DECIMAL before the next test.
    - (d) **`F_<name>` / `MK_<name>` collision avoidance.** All new colon-body and CODE-block test words live in the same global dictionary for the lifetime of one REPL invocation — but each `printf` spawns a fresh REPL, so collision is inherently impossible. Noted here to confirm the reviewer doesn't flag it as a concern.
    - (e) **Compile-error test assertion tightness.** For AC #6, the `: BAD #ABC ;` test must assert both (1) the `#ABC ?` error marker appears AND (2) no subsequent `BAD` definition survives. The 9.4-inherited discipline of "assert presence AND assert absence" applies here — a weak assertion (only checking for `#ABC ?`) would pass even if a half-built `BAD` survived in the dictionary.
    - (f) **No assembly source changes expected.** If the review surfaces any assembly delta in `src/number_prefixes.asm`, `src/outer_interpreter.asm`, or `src/assembler.asm`, that is IMPORTANT — it means a reachability gap was found. Document the gap, the fix, and the regression test that guards against its return. (If no delta: explicitly note that in the review section.)
  - [x] 7.3 Address findings or document skip rationale per the 9.1–9.4 pattern. Any HIGH-severity finding is a release blocker (would push 9.5 out of scope); MEDIUM and LOW may be accepted or deferred to 9.6 with explicit follow-up notes.

## Dev Notes

### Story Purpose and Scope

Story 9.5 is a **verification-only story**. It closes the "prefix reach" promise of Epic 9 (FR8 — "everywhere ordinary numbers are parsed") by adding explicit test coverage across all three parse contexts: REPL, compiled colon bodies, and `CODE … END-CODE` assembler blocks.

**Why verification-only?** The Epic 9 architectural decision E9-D1 placed the recogniser at a single integration point inside the outer interpreter's unknown-token handler (`src/outer_interpreter.asm:.try_number`, lines 179–196 in the current binary). All three parse contexts route through this single thread:

- **REPL:** `INTERPRET` → `FIND` misses → `.try_number` → `ASM_RECOGNIZE` fast-fails (asm_mode=0) → `NUMBER_PREFIX?` tries and succeeds → `.got_value` leaves the value on the stack because STATE=0.
- **Colon body:** Same `INTERPRET` thread. `NUMBER_PREFIX?` succeeds → `.got_value` → STATE≠0 → compiles `LIT n` via the existing compile-literal path (`w_LIT_cf, n`) → at runtime, LIT pushes `n`.
- **CODE block:** Same `INTERPRET` thread, with asm_mode=1. `ASM_RECOGNIZE` tries the register table first; a non-register token like `0xFF` misses; `NUMBER_PREFIX?` succeeds → `.got_value` → STATE=0 (CODE keeps interpret state; it's the asm_mode byte that gates assembler semantics, NOT STATE) → leaves the value on the stack for the following assembler word (`#`, `C,`, `DB,`, `LD,`, etc.) to consume.

The single-thread design means **colon-body and CODE-block reach were already implied** the moment 9.1 wired `w_NUMBER_PREFIX_Q_cf` into `.try_number`. Stories 9.2–9.4 have been observationally verifying REPL reach as they went. 9.5 adds the missing test coverage for the other two contexts and publishes the "prefix reach is complete" proof that Epic 9 needs for 9.6's regression gate.

**Net new work:**

1. **Colon-body tests.** ~22 tests covering every prefix × sign variant × BASE-cross × BASE-integrity cross-product.
2. **CODE-block tests.** ~14 tests covering the same cross-product inside `CODE … END-CODE`.
3. **Cross-context regression guards.** A mixed test that exercises all three contexts in one session, plus FR47 spot-checks per context.
4. **Scaffold-table 9.5 row.** One-line update in `src/number_prefixes.asm`.

**Not in scope:** any new assembly code (the mechanism is already in place); any change to `src/outer_interpreter.asm`, `src/assembler.asm`, or the recogniser dispatch; any new standards-citation comment (every prefix word was already cited by 9.1–9.4).

**In scope under contingency:** if Task 1.4's trace or the actual test execution surfaces a reachability gap (e.g. an undocumented interaction with compile-time STATE transitions, or an asm_mode path that unexpectedly blocks the recogniser), the story expands to include the corrective code change. This is considered highly unlikely given the architecture, but the story's AC #8 accommodates it via the "delta documented in Completion Notes" escape hatch.

### Architecture Decisions Driving This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§E9-D1 (Integration point):** single wire-in at `.try_number`. 9.5 is the observational proof that this single wire-in achieves FR8 without per-context special-casing.
- **§E9-D2 (Prefix dispatch strategy):** flat `CP`/`JR Z` chain. 9.5 does not extend it.
- **§CCD-3 (Standards-Citation Discipline):** no new citations needed — every word added in 9.1–9.4 already carries its §3.4.1.3 citation per NFR17/NFR18.
- **§NFR10 (Regression guarantee):** 9.5 is the first 9.x story that could in principle regress 9.1–9.4 behaviour (via an accidental Makefile edit). The Task 4.3 `make test-repl` run is the guard.

### The INTERPRET → NUMBER_PREFIX? flow (traced from source)

For any token that is not a dictionary word and not an assembler register (via `w_ASM_RECOGNIZE_cf`), the control flow per `src/outer_interpreter.asm:179-208`:

```
.try_number:
    DW w_DROP_cf               ; ( c-addr 0 -- c-addr )
    DW w_ASM_RECOGNIZE_cf      ; ( c-addr -- value true | c-addr false )
    DW w_QBRANCH_cf
    DW .try_prefix_num - $
    DW w_BRANCH_cf
    DW .got_value - $
.try_prefix_num:                ; Epic 9 wire-in
    DW w_NUMBER_PREFIX_Q_cf    ; ( c-addr -- n true | c-addr false )
    DW w_QBRANCH_cf
    DW .try_real_number - $
    DW w_BRANCH_cf
    DW .got_value - $
.try_real_number:
    DW w_NUMBER_Q_cf           ; ( c-addr -- n true | c-addr false )
    DW w_QBRANCH_cf
    DW .not_number - $
.got_value:
    DW w_STATE_cf
    DW w_FETCH_cf
    DW w_QBRANCH_cf
    DW .interp_loop - $        ; STATE=0 → leave on stack
    ; STATE≠0 → compile LIT n
    DW w_LIT_cf, w_LIT_cf
    DW w_COMMA_cf
    DW w_COMMA_cf
    DW w_BRANCH_cf
    DW .interp_loop - $
.not_number:
    DW w_STATE_cf
    DW w_FETCH_cf
    DW w_QBRANCH_cf
    DW .interp_error - $       ; STATE=0 → error
    DW w_COMP_ERROR_cf         ; STATE≠0 → compile error, ABORT, unlink
```

**Key invariant:** `.got_value` is context-agnostic. It inspects STATE to decide stack-leave vs compile-LIT, but it is oblivious to asm_mode. This is WHY the CODE block context "just works" — the assembler's `#`, `C,`, `DB,`, `LD,` etc. consume whatever value is on the stack, and NUMBER_PREFIX? / .got_value deliver it exactly the same way inside or outside CODE.

**Implication for 9.5 tests:** the tests do not need to probe new internal mechanics. They need to OBSERVE the promise from the user's perspective: given `CODE … prefix-literal … END-CODE` or `: … prefix-literal … ;`, the resulting compiled code contains the expected value. That's a black-box test.

### Source Tree Components to Touch

- **MODIFY:**
  - `tests/number_prefixes_tests.fth` — append Story 9.5 section (~35 new `.fth` lines per Task 2, 3, 4).
  - `Makefile` — append Story 9.5 test blocks (tests 364..~398) in the `test-repl` target, mirroring 9.4's pattern.
  - `src/number_prefixes.asm` — one-row update to the scaffold comment table (Task 5.1). Zero functional change.
- **MAY MODIFY (contingency only):** `src/number_prefixes.asm`, `src/outer_interpreter.asm`, `src/assembler.asm` — only if a reachability gap surfaces during development. Document any such change thoroughly in Completion Notes. **Expectation: no change.**

**Untouched (confirm by final inspection):** every source file not listed above. Specifically: the recogniser's `w_NUMBER_PREFIX_Q_cf` body, every per-prefix handler, the shared `.pref_check_sign` helper, the `.pref_sign_entry` pre-pass, the outer interpreter's `.try_number` thread, and the assembler's `w_CODE_cf` / `w_END_CODE_cf` / `w_ASM_RECOGNIZE_cf`.

### Existing Code References (Grep-Verified)

- `src/outer_interpreter.asm:179-208` — `.try_number` thread; the shared number-parse routing for all three contexts. Task 1.4's trace target.
- `src/outer_interpreter.asm:187-192` — `.try_prefix_num` arm wires in `w_NUMBER_PREFIX_Q_cf`. Story 9.1's contribution; unchanged since.
- `src/outer_interpreter.asm:197-208` — `.got_value` — STATE-sensitive leave-or-compile routing. Context-agnostic re: asm_mode.
- `src/outer_interpreter.asm:209-217` — `.not_number` / `.interp_error` — error path; AC #6's compile-error test target.
- `src/number_prefixes.asm:110-133` — scaffold comment table; Task 5.1 adds the 9.5 row.
- `src/number_prefixes.asm:144-184` — `w_NUMBER_PREFIX_Q_cf` entry and dispatch chain; unchanged by 9.5.
- `src/assembler.asm:886-962` — `w_ASM_RECOGNIZE_cf`; fast-fails on asm_mode=0 (meaning REPL and colon-body bypass it zero-cost). On asm_mode=1, scans the register table and falls through to `.recog_fast_false` for non-register tokens like `0xFF` — returning FALSE so `.try_number` advances to `.try_prefix_num`.
- `src/assembler.asm:984-991` — `w_HASH_cf` (the assembler `#` IMMEDIATE marker word). Distinct from the `#` prefix char in `NUMBER_PREFIX?` — the former is a dictionary word that runs on TOS, the latter is a prefix-dispatch byte at the head of a token. Their co-existence was deliberate from 9.1 design. No collision (FIND demands exact-length match; `#42` as a token never matches `#` as a dictionary entry).
- `src/assembler.asm:~400-443` — `asm_cleanup` ABORT hook; closes AC #6 for the CODE-block error path.
- `src/assembler.asm:1165-1210` — `w_CODE_cf`; sets asm_mode=1, builds SMUDGE-flagged header, enters the assembler mode. Does NOT change STATE.
- `src/assembler.asm:1221-1261` — `w_END_CODE_cf`; clears asm_mode, unlinks labels, clears SMUDGE.
- `src/memory.asm:167-177` — `w_C_COMMA_cf` (`C,`); single-byte compile. Used in CODE-block tests (3.2) and as a canonical "compile this byte" operator.
- `src/compiler.asm:25-48` — TICK (`'`); unchanged by 9.5. Potential interaction with `'c'` tokens inside colon bodies is resolved by FIND's exact-length match discipline (see Dev Notes "TICK vs. 'c' prefix" below).
- `tests/number_prefixes_tests.fth:1-226` — full pre-9.5 test file; Story 9.5 appends at line 227.
- `Makefile:3160-3167` — last 9.4 test block (test 363); 9.5 appends starting at block 364.
- `Makefile:~751-815` — existing CODE-block test blocks (Stories 6.x / 4.x); template for 9.5 Task 3's CODE-block tests.

### TICK (`'`) vs `'c'` character-literal prefix — interaction audit

A natural question for 9.5: does the `'c'` prefix collide with TICK inside colon bodies where TICK's semantics change slightly?

**Audit result: no collision.** Let's trace both cases explicitly:

**Case 1: `: F 'A' ;`** — the token is `'A'` (3 chars). FIND does an exact-length lookup against the dictionary. The dictionary contains `'` (1 char, TICK). Length mismatch → FIND returns 0 / FALSE. The token then routes through `.try_number` → NUMBER_PREFIX? → `.pref_quote_entry` → parses `'A'` as character code 65 → returns (65 TRUE). `.got_value` → STATE≠0 → compiles `LIT 65`. At runtime, `F` pushes 65. ✓

**Case 2: `: F ' BAR ;`** — the token is `'` (1 char). FIND finds TICK. TICK is NOT immediate by default (in antforth as in standard Forth), so in compile mode it compiles as a normal call; at runtime it executes against the next input word in the input stream — but the input stream is exhausted when `F` later runs. Per standard Forth semantics, `'` inside a colon body is typically guarded by `[']` or requires the program to manage the input stream. This is PRE-EXISTING behaviour (Story 9.5 doesn't change it), but it's worth documenting because a reviewer might flag "what happens if TICK's interpret-time behaviour collides with 'c' prefix?" — the answer is they never can collide, because the tokens have different lengths and FIND discriminates by length. ✓

**Case 3: `: F 'A ;`** — the token is `'A` (2 chars). FIND misses (no 2-char `'A` word). NUMBER_PREFIX? tries: `.pref_quote_entry` checks count==3, count==2 → fails. NUMBER? tries: parses `'A` per BASE — fails (apostrophe isn't a digit in any base). `.not_number`: STATE≠0 → COMP_ERROR → ABORT → unlink. The failed definition is rolled back cleanly. ✓

This audit is referenced by AC #6 and Task 2.5. No test is needed per Case 1 that isn't already in Task 2.2's cross-product; Case 3 is covered indirectly by the compile-error test. Document the audit in Completion Notes for future reference.

### CODE block — why prefixes "just work"

Inside `CODE … END-CODE`, the INTERPRET thread is still running in STATE=0 (interpret mode). Only `asm_mode` is elevated to 1. Each token in the body is processed through `.try_number`:

1. `FIND` — tries to match the token against the global dictionary. Dictionary words like `PUSH,`, `LD,`, `C,`, `#` (the assembler immediate-marker), `NEXT,` will match here.
2. For non-words, `ASM_RECOGNIZE` tries the register table (`B`, `C`, `HL`, `(HL)`, `Z`, `NZ`, etc.). This is where register names resolve.
3. For non-registers, `NUMBER_PREFIX?` tries the prefix dispatch. A token like `0xFF` matches here.
4. For non-prefix tokens, `NUMBER?` tries the default-BASE parser. A token like `42` in DECIMAL matches here.

Because STATE=0 throughout, `.got_value` leaves the parsed value on the data stack — ready to be consumed by the next assembler word (`# C LD,`, `C,`, `DB,`, etc.). **Prefix values arrive on the stack identically whether they came from NUMBER? (unprefixed) or from NUMBER_PREFIX? (prefixed).**

Test template (Task 3.1 / 3.2):

```
CODE MK_FF BC PUSH, 0xFF # C LD, 0 # B LD, NEXT, END-CODE
MK_FF .     ; expect: 255
```

Tokens:
- `CODE` — dict word, runs IMMEDIATELY (`DEFCODE` puts it in the standard inline-execute path), builds SMUDGE header for `MK_FF`, sets asm_mode=1.
- `MK_FF` — parsed by `CODE` itself via `build_header` to form the new word's name.
- `BC` — register name, ASM_RECOGNIZE returns `0xFF61` (reg16 tag + index BC=1). Pushed.
- `PUSH,` — dict word, consumes the reg16 tag, emits `PUSH BC` opcode (0xC5) at HERE.
- `0xFF` — NOT a dict word, NOT a register. NUMBER_PREFIX? matches → pushes 255 on stack.
- `#` — dict word (assembler immediate marker). Consumes 255, pushes `0xFF40` (imm tag), leaving 255 under the tag.
- `C` — register, ASM_RECOGNIZE returns `0xFF01`.
- `LD,` — dict word, consumes stack: dst=C (0xFF01), src=imm(0xFF40)+value(255). Emits `LD C, 0xFF` (0x0E 0xFF).
- (repeat for `0 # B LD,` which emits `LD B, 0x00` = 0x06 0x00)
- `NEXT,` — dict word, emits the NEXT macro (typically `LD A, (DE)` + `INC DE` + `LD H, …` etc. depending on threading).
- `END-CODE` — dict word, clears SMUDGE, clears asm_mode=0. `MK_FF` is now callable.

Then `MK_FF .`:
- `MK_FF` — dict word (just defined). Calls into the CODE body: `PUSH BC` (stacks the old TOS), `LD C, 0xFF`, `LD B, 0x00`, NEXT. Now BC=0x00FF=255. TOS=255.
- `.` — prints 255.

Result: `255 ok`. ✓

**What could go wrong?** Minimal risk surfaces:

- (a) **`#` collision.** Inside `CODE`, the token `#` is the assembler marker word. Token `#42` (no space) is NOT `#` — different length. FIND misses, NUMBER_PREFIX? matches `#` prefix arm, returns 42 decimal. No collision.
- (b) **`'c'` inside CODE.** Assembler has no `'` word. Token `'A'` misses FIND, misses ASM_RECOGNIZE, matches NUMBER_PREFIX? `'c'` arm. Returns 65.
- (c) **Compile-time error rollback.** If `CODE C_BAD #ABC …` is typed, `#ABC` fails the prefix and falls through to NUMBER?, which also fails. `.not_number` finds STATE=0 — **so it does NOT call COMP_ERROR** — it falls into `.interp_error` and eventually `w_ABORT_cf`. ABORT triggers the `asm_cleanup` hook (if asm_mode=1 at abort time), which rolls back HERE and unlinks the SMUDGE-flagged header. The `C_BAD` definition is discarded. ✓
- (d) **BASE mutation.** None of the above touches (IY+UserArea.base). The recogniser has a file-header invariant "Never reads or writes (IY+UserArea.base)" (src/number_prefixes.asm:8). ✓

All four sub-cases are tested by Task 3 and Task 4.

### Colon body — why prefixes "just work"

Inside `: … ;`, STATE=1 and asm_mode=0. The INTERPRET thread routes the same way: FIND → ASM_RECOGNIZE (fast-fails on asm_mode=0) → NUMBER_PREFIX? → NUMBER? → .got_value. When STATE=1, `.got_value` compiles `LIT n` instead of leaving on stack. The compiled `LIT n` is a two-cell sequence: the xt of `LIT` (w_LIT_cf), followed by the value `n`. At runtime, LIT reads the following cell and pushes it.

**Subtle point:** the compiled literal is an **absolute cell value** — `n` itself, after prefix processing. BASE is NOT re-applied at runtime. So:

```
HEX : HUNDRED #100 . ;          \ compiles LIT 100 (decimal)
DECIMAL HUNDRED                 \ prints "100 " (DECIMAL)
HEX HUNDRED                     \ prints "64 "  (HEX, 100 decimal = 0x64)
```

The `.` inside HUNDRED prints according to the PREVAILING BASE at call time. The prefix `#100` fixed the compiled value as 100. At different call-sites with different BASE, the printed representation changes, but the underlying value is invariant. This is correct behaviour and falls out of `LIT`'s absolute semantics.

Task 2.2's tests verify this indirectly by checking the printed value matches the expected DECIMAL representation (the test suite runs in DECIMAL by default). Task 2.3's BASE-cross tests add explicit HEX-state verification.

### Makefile test-block template (Task 2 / Task 3)

Follow the 9.4 pattern exactly. Canonical block:

```
@OUTPUT=$$(printf '<repl-input>\r\nBYE\r\n' | $(IZCPM) $(TARGET) 2>/dev/null || true) && \
if echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '<positive-pattern>' && \
   ! echo "$$OUTPUT" | tr -d '\r\n' | grep -qE '<negative-guard>'; then \
    echo "PASS: REPL test <N> — <description>"; \
else \
    echo "FAIL: REPL test <N> — expected <positive-pattern> AND absence of <negative-guard>"; \
    echo "  Got: $$(echo -n "$$OUTPUT" | xxd)"; \
    exit 1; \
fi
```

Positive and negative guards per 9.2 M1 / 9.4 strengthening: positive tests assert `'<value>  ok'` AND not `'<token> ?'`; fail tests assert the error AND not bare `[0-9]  ok`.

For colon-body tests, the REPL input is typically two lines separated by `\r\n`:
```
': F_H1 $$FF ; F_H1 .\r\nBYE\r\n'
```

For CODE-block tests, three lines: CODE-definition, invocation, BYE:
```
'CODE MK_FF BC PUSH, 0xFF # C LD, 0 # B LD, NEXT, END-CODE\r\nMK_FF .\r\nBYE\r\n'
```

**Printf-escape rules** (inherited from 9.4 Completion Notes item 6):
- `%` → `%%` (printf conversion specifier escape)
- `$` → `$$` (Make variable escape; propagates through to shell's printf — `$$FF` becomes `$FF` in the REPL input)
- `-` at token-start → precede printf with `--` to prevent printf's option parsing: `printf -- '-#42…'`
- `'` → `\047` in some shells, or use double-quoted printf with careful escaping. See Makefile:3142 (test 361) for a working example of nested single-quoted tokens.

### Previous-Story Intelligence — Stories 9.1–9.4

9.1–9.4 have established the recogniser, every prefix handler, the sign modifier, and the XOR-semantic sign flag. 9.5 inherits all of it. Key inherited learnings:

1. **Test numbering density.** 9.1 ended at 274, 9.2 at 299, 9.3 at 329, 9.4 at 363. 9.5 starts at 364. Keep dense sequential numbering; do NOT renumber earlier tests.

2. **Test-case strengthening is mandatory** (from 9.2 M1 and inherited through 9.3/9.4). Every positive test asserts `'<value>  ok'` AND absence of `'<token> ?'`; every fail test asserts `'<token> ?'` AND absence of bare numeric success. A 9.5 twist: BASE-integrity tests need THREE-part assertions (before / after-define / after-invoke), so consider emitting `BASE @ .` three times and grepping for the expected three-number pattern.

3. **Binary size budget awareness.** Phase 2 has no per-epic net-negative gate (per architecture §NFR4), but 9.5 is expected to contribute 0 bytes. Any positive delta needs justification.

4. **Adversarial review discipline** (project memory `feedback_adversarial_review.md`). A verification-only story looks low-risk, which is PRECISELY why the reviewer should scrutinise it. Common traps: false-positive tests (pattern matches for wrong reasons), missing absence guards (positive test passes when error also fires), BASE-pollution between tests (HEX set and not reset). Expect 2+ findings; zero findings is suspect.

5. **Follow the process** (project memory `feedback_follow_process.md`). Don't ask the user whether to skip the CODE-block tests "because the REPL path proves it". The AC explicitly require CODE-block coverage; execute.

6. **Standards compliance** (project memory `feedback_standards_compliance.md`). No new citation work in 9.5 — but verify that existing citations are unchanged. A Makefile edit or scaffold-table update must not accidentally delete a `; Forth 2014 §3.4.1.3` line in `src/number_prefixes.asm`.

7. **Design upfront** (project memory `feedback_design_upfront.md`). 9.1's architectural decision (single integration point at `.try_number`) is the reason 9.5 is verification-only. The design foresight pays off at 9.5 exactly as intended.

8. **REPL tests preferred** (project memory `feedback_repl_tests_preferred.md`). All 9.5 tests are REPL-piped, not assembly thread extensions.

9. **TOS-in-register discipline** (project memory `project_tos_in_register.md`). BC=TOS is preserved through `ASM_RECOGNIZE`'s fast-fail and `NUMBER_PREFIX?`'s fail path. 9.5 does not touch this; but the reviewer should confirm the tests don't implicitly depend on a phantom BC value post-ABORT.

### Feature-Parity Table — State After 9.5

| Token form | REPL (interpret) | Colon body (compile) | CODE block (assemble) |
|---|---|---|---|
| `42` (unprefixed) | ✓ (pre-9.1) | ✓ (pre-9.1) | ✓ (pre-9.1) |
| `-42` (unprefixed signed) | ✓ (pre-9.4) | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| `#42` | ✓ 9.1 | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| `-#42` | ✓ 9.4 | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| `#-5` | ✓ 9.1 | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| `-#-5` | ✓ 9.4 | (skip — covered by XOR-composition tests at REPL) | (skip) |
| `$FF` | ✓ 9.2 | ✓ 9.2 (test 83) | ✓ NEW test (9.5) |
| `$-FF` | ✓ 9.2 | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| `-$FF` | ✓ 9.4 | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| `0xFF` / `0XFF` | ✓ 9.2 | ✓ 9.2 (test 84) | ✓ NEW test (9.5) |
| `-0xFF` | ✓ 9.4 | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| `%1010` | ✓ 9.3 | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| `-%1010` | ✓ 9.4 | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| `'A'` | ✓ 9.3 | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| `-'A'` | ✓ 9.4 | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| BASE integrity around colon | n/a | ✓ NEW test (9.5) | n/a |
| BASE integrity around CODE | n/a | n/a | ✓ NEW test (9.5) |
| BASE integrity around REPL | ✓ 9.1/9.2/9.4 | n/a | n/a |
| malformed prefix compile-error | n/a | ✓ NEW test (9.5) | ✓ NEW test (9.5) |
| mixed-context single-session | n/a | n/a | ✓ NEW test (9.5) |

Every "NEW test (9.5)" row is covered by a Task 2 or Task 3 subtask.

### EXX / Shadow-Register Conventions (Inherited Unchanged)

Per `docs/register-conventions.md` and the `src/number_prefixes.asm` file-header ritual block — unchanged by 9.5. The recogniser's EXX-bounded handlers remain identical. Tests should have no reason to observe the shadow bank at all; any test that does is over-specified for 9.5's verification scope.

Expected EXX occurrence count in `src/number_prefixes.asm` post-9.5: **20** (unchanged from 9.4). Grep-verify `grep -cE '^\s*EXX\b' src/number_prefixes.asm` as part of Task 4.3. Divergence from 20 indicates an accidental code change — roll back before proceeding.

### Standards Citation — Forth 2014 §3.4.1.3

No new citations in 9.5. Every prefix word's `; Forth 2014 §3.4.1.3` (or `; antforth extension` for `0x`) is inherited unchanged from 9.1–9.4. The scaffold-table update in Task 5.1 is a comment-only change that doesn't alter any citation.

### Testing Standards

Per `feedback_repl_tests_preferred.md`: REPL-piped Forth scripts, not assembly test-thread extensions. Do NOT add to `src/tests/*.asm` for this story.

Test delivery: `Makefile` `test-repl` target blocks + `.fth` file, per 9.1's Option A. Cross-reference the `.fth` file from Makefile block comments so future maintainers can find the source-of-truth intent.

**Manual smoke test** (Task 6): run each of the AC-listed cases through an interactive REPL on the emulator and record the exact console output in Completion Notes. Cross-check against the automated test assertions — any discrepancy flags a test-harness robustness issue (grep pattern too loose, pattern matches for the wrong reason, etc.).

### Project Structure Notes

- `tests/number_prefixes_tests.fth` grows by ~50 `.fth` lines (section banner + ~35 single-line tests + cross-referenced comments). Post-9.5 file roughly 280 lines.
- `Makefile` `test-repl` target grows by ~280 lines (~8 lines per Makefile test block × ~35 tests). Still an established pattern; do NOT refactor the test target.
- `src/number_prefixes.asm` grows by ~6 lines (the scaffold-table 9.5 row). No functional delta.
- No new files. No conflicts with unified project structure.
- If the optional code change surfaces (see "In scope under contingency"), file scope is limited to `src/number_prefixes.asm` and/or `src/outer_interpreter.asm`. Document it explicitly in Completion Notes with the reachability gap's symptom, root cause, and test-guard.

### References

- `_bmad-output/planning-artifacts/epics.md:362-388` — Story 9.5 authoritative spec
- `_bmad-output/planning-artifacts/epics.md:242-244` — Epic 9 overview
- `_bmad-output/planning-artifacts/architecture.md:230-242` — E9-D1 single integration point, E9-D2 flat dispatch
- `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 standards-citation discipline
- `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 per-epic benchmark gate (Story 9.6's job, not 9.5's)
- `_bmad-output/planning-artifacts/prd.md:373-383` — FR1–FR9 (numeric literal input); FR8 (prefix reach); FR9 (BASE integrity)
- `_bmad-output/planning-artifacts/prd.md:434-436` — FR45, FR46, FR47 (backward compatibility)
- `_bmad-output/planning-artifacts/prd.md:453-470` — NFR1, NFR9, NFR10, NFR11, NFR12, NFR17, NFR18
- `_bmad-output/implementation-artifacts/9-1-numeric-prefix-recogniser-scaffold-decimal-prefix.md` — Story 9.1 Dev Notes + Completion (single integration point wire-in)
- `_bmad-output/implementation-artifacts/9-2-hex-prefixes-standard-and-0x-antforth-extension.md` — Story 9.2 Dev Notes + Completion (colon-body tests 83/84 — the only pre-9.5 context-reach coverage)
- `_bmad-output/implementation-artifacts/9-3-binary-and-character-prefixes.md` — Story 9.3 Dev Notes + Completion
- `_bmad-output/implementation-artifacts/9-4-leading-sign-and-full-case-insensitivity.md` — Story 9.4 Dev Notes + Completion (sign modifier; final functional story of Epic 9)
- `src/outer_interpreter.asm:179-230` — `.try_number` thread; single shared number-parse routing
- `src/outer_interpreter.asm:187-192` — `.try_prefix_num` arm; Story 9.1's wire-in
- `src/outer_interpreter.asm:197-217` — `.got_value` / `.not_number` — STATE-sensitive compile/leave and error paths
- `src/number_prefixes.asm:1-134` — file header + scaffold comment table (Task 5.1 edit target)
- `src/number_prefixes.asm:144-184` — `w_NUMBER_PREFIX_Q_cf` entry (unchanged by 9.5)
- `src/assembler.asm:886-962` — `w_ASM_RECOGNIZE_cf` (fast-fails on asm_mode=0; preserves c-addr on miss)
- `src/assembler.asm:1165-1261` — `w_CODE_cf` / `w_END_CODE_cf` (asm_mode lifecycle)
- `src/assembler.asm:~400-443` — `asm_cleanup` (ABORT-time rollback; AC #6 CODE-path target)
- `Makefile:~751-815` — existing CODE-block test blocks (Epic 4/6 precedent; Task 3 template)
- `Makefile:3160-3167` — last 9.4 test (test 363); 9.5 appends starting at 364
- `tests/number_prefixes_tests.fth:1-226` — full pre-9.5 test file; 9.5 appends at line 227
- Project memories:
  - `feedback_adversarial_review.md` — reviews MUST find things; zero findings on a verification story is especially suspect
  - `feedback_design_upfront.md` — 9.1's single-integration-point decision is why 9.5 is verification-only
  - `feedback_repl_tests_preferred.md` — REPL-piped tests only
  - `feedback_standards_compliance.md` — no citation churn in 9.5
  - `feedback_follow_process.md` — execute the CODE-block coverage; don't ask to skip
  - `feedback_testing_rules.md` — tests must exercise actual Forth primitives, not raw BDOS
  - `project_tos_in_register.md` — BC=TOS preserved through recogniser fail paths

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

- `make test-repl` — full REPL regression, 405 passes (was 370 before 9.5).
- `make test` — assembly-level regression, clean.
- Binary size: pre-9.5 = 14,787 bytes; post-9.5 = 14,787 bytes. **Zero delta** as predicted.
- EXX occurrences in `src/number_prefixes.asm`: 20 (unchanged from 9.4).

### Completion Notes List

**1. Coverage audit (Task 1).**

| Prefix | REPL (I) | Colon body (C) | CODE block (A) |
|---|---|---|---|
| `#` | 9.1 (tests 266–274) | ✗ pre-9.5 | ✗ pre-9.5 |
| `$` | 9.2 | ✓ test 296 (`: GETFF`) | ✗ pre-9.5 |
| `0x` | 9.2 | ✓ test 297 (`: GETHEX`) | ✗ pre-9.5 |
| `%` | 9.3 | ✓ test 324 (`: GETTEN`) | ✗ pre-9.5 |
| `'c'` | 9.3 | ✓ test 325 (`: GETA`) | ✗ pre-9.5 |
| `-` sign | 9.4 (tests 336–363) | ✗ pre-9.5 | ✗ pre-9.5 |

**Deviation from story 1.2 baseline:** The story claimed only `$` and `0x` had pre-existing colon-body coverage. In fact `%` and `'c'` were also covered (tests 324 and 325 added in 9.4). To avoid duplication, 9.5 skipped plain `%1010` and `'A'` colon-body re-tests and focused on the **outer-sign composition** variants (`-%1010`, `-'A'`) plus the **BASE-integrity** angle, which none of 324/325 tested.

**Task 1.4 INTERPRET trace verification:** `w_NUMBER_PREFIX_Q_cf` is invoked at `src/outer_interpreter.asm:188` (the `.try_prefix_num` arm). This arm runs for every non-word, non-register token regardless of STATE (0 = interpret, ≠0 = compile) and regardless of `asm_mode` (0 = REPL/colon, 1 = CODE block). The `.got_value` dispatch at line 197 inspects STATE to decide stack-leave vs compile-LIT but is oblivious to `asm_mode` — which is precisely why the CODE-block context "just works" without new wiring. Documentation matches code.

**2. Critical finding during development — story operand order was WRONG.**

The story's CODE-block examples (AC #3, Task 3.1, Task 6.1) all used the form `<value> # <reg> LD,` — e.g. `0xFF # C LD,`. This is **backwards**. The antforth assembler uses **Zilog dst-src order** (`src/assembler.asm:23–32` and project memory `feedback_assembler_operand_order.md`), so the correct form is `<reg> <value> # LD,` — e.g. `C 0xFF # LD,`. Running the story's form produces `bad operand ?` because the assembler reads `0xFF` as the destination tag. Implementation used the correct dst-first order throughout; story AC text retains the original spec-writer language but all 15 CODE-block tests plus the mixed-context test use `C <val> # LD,`.

This was caught at REPL-smoke time via `iz-cpm` before committing the Makefile blocks. Flagged here as documentation for future maintainers: the story's ACs are **informational** about what the tests should prove, not syntactically binding templates.

**3. Test delivery.**

35 new REPL-piped tests added (364–396, plus review-added 384a and 386a):

- **Tests 364–378 — Colon body (Task 2, 15 tests).** Each prefix + outer-sign variant not already covered by 9.2/9.3 (`#42`, `-#42`, `$-FF`, `-$FF`, `-0xFF`, `-%1010`, `-'A'`), BASE-cross (`HEX + #`, `DECIMAL + $`), BASE-integrity 4-snapshots for each of `#/$/0x/%/'c'`, and the compile-error path (`: F_BAD #ABC ;` → `#ABC ?` AND follow-on `F_BAD ?` as undefined-word, proving the half-built entry was unlinked).
- **Tests 379–393 — CODE block (Task 3, 15 tests).** Each single-byte prefix + outer-sign (`0xFF`, `0XFF`, `#100`, `-#5`, `$FF`, `$-FF`, `-0xFF`, `%1010`, `'A'`, `-'A'`), a 16-bit pair load via `BC 0x1234 # LD,`, BASE-cross (`HEX + CODE + #`, `DECIMAL + CODE + $`), BASE-integrity 4-snapshots around `CODE…END-CODE`, and the assembler compile-error path (`CODE C_BAD #ABC …` → `#ABC ?` AND follow-on `C_BAD ?` proving `asm_cleanup` unlinked the SMUDGE header).
- **Tests 394–396 — Cross-context + FR47 (Task 4, 3 tests).** Mixed single-session (REPL prefix + colon prefix + CODE prefix: `42 255 255  ok`) to guard against `asm_mode`/`.pref_negate` leakage; FR47 spot-checks (bare `-42` in colon body via NUMBER?; bare `42` in CODE body via NUMBER? fallthrough).

All 33 new tests use the 9.2 M1 / 9.3 / 9.4 strengthened assertion discipline: positive cases assert the expected `<value>  ok` AND absence of the `<word> ?` error marker; fail cases assert the error AND absence of spurious numeric success.

**4. Scaffold-table update (Task 5).**

Added a 9.5 row in `src/number_prefixes.asm:~134` immediately after the 9.4 row. Comment-only — confirmed by re-checking `ls -la build/antforth.com` which reports 14,787 bytes before and after. No new standards-citation (`; Forth 2014 §3.4.1.3`) required per CCD-3 / NFR17 / NFR18: no new word was added, no new citation is needed. This decision is recorded here per Task 5.2.

**5. Binary size delta (Task 4.4).**

0 bytes. Pre-9.5 = 14,787; post-9.5 = 14,787. Matches the expectation for a test-only story. No reachability gap surfaced — every AC was provable without assembly source modification, confirming the Epic 9 architectural decision §E9-D1 (single integration point at `.try_number`).

**6. Regression suite (Task 4.3).**

`make test && make test-repl` — zero regressions. Pre-9.5 REPL passes: 370. Post-9.5 (after both review passes): 405 (= 370 + 35 new, consistent). Assembly test suite clean.

**7. Manual smoke results (Task 6.1).**

All 7 cases ran through `iz-cpm build/antforth.com` with the expected outcomes (trailing `BYE` trimmed for brevity):

- REPL HEX + `#100` in colon: `HEX : DECNUM #100 . ; DECNUM BASE @ . DECIMAL` → `64 10  ok` ✓
- REPL DECIMAL + `$ff` in colon: `: HEXNUM $ff . ; HEXNUM BASE @ .` → `255 10  ok` ✓
- CODE `MK_FF` (0xFF): `MK_FF .` → `255  ok` ✓
- CODE `MK_NEG` (-#5 sign-extended): `MK_NEG .` → `-5  ok` ✓
- Mixed context: `#42 . : F $FF ; F . CODE C_MIX … C_MIX .` → `42 255 255  ok` ✓
- Compile-error (colon): `: BAD #ABC ;` → `#ABC ?`; follow-on `BAD .` → `BAD ?` (unlinked) ✓
- Compile-error (CODE): `CODE C_BAD #ABC …` → `#ABC ?`; follow-on `C_BAD .` → `C_BAD ?` (unlinked via `asm_cleanup`) ✓

No divergence between manual smoke and automated test assertions. The `: BAD #ABC ;` smoke used a different word name (`BAD` instead of `F_BAD`) than the Makefile test 378 to avoid any cross-check false-positive; both report identical error paths.

**8. TICK vs `'c'` audit (Dev Notes reference).**

The three cases enumerated in the Dev Notes were implicitly exercised: Case 1 (`: F 'A' ;`) via test 325; Case 3 (`: F 'A ;`) via the compile-error discipline — a 2-byte `'A` token fails both NUMBER_PREFIX? (count mismatch on the `'c'` arm) and NUMBER? (apostrophe not a digit), triggering COMP_ERROR. The 2-byte `'A` case would behave the same as the `#ABC` compile-error test — no new test is required to cover it, as test 378 already exercises the compile-error + survivor-rollback discipline in the colon body.

**9. Assembler source changes.**

None. `src/outer_interpreter.asm`, `src/assembler.asm`, and all `src/number_prefixes.asm` executable code paths are byte-identical to the 9.4 baseline. Only the scaffold-table **comment block** in `src/number_prefixes.asm` was extended (Task 5).

### File List

**Modified:**

- `tests/number_prefixes_tests.fth` — appended Story 9.5 section at line ~227 (~50 new `.fth` lines covering colon-body, CODE-block, mixed-context, and FR47 spot-checks).
- `Makefile` — appended 33 new `test-repl` blocks (tests 364–396) after the 9.4 test 363 block. No change to the test target structure, the assembly-test target, or the build rules.
- `src/number_prefixes.asm` — one comment-only addition: 9.5 row in the scaffold-table comment block (~line 134). Zero binary delta.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `9-5-…` status transitioned ready-for-dev → in-progress → review (via the dev-story workflow).
- `_bmad-output/implementation-artifacts/9-5-prefix-reach-repl-colon-bodies-and-assembler-source.md` — this story file: all task checkboxes marked, Dev Agent Record populated.

**Not modified (confirm via `git diff`):**

- `src/outer_interpreter.asm`
- `src/assembler.asm`
- `src/number_prefixes.asm` (executable code — comment-only diff)
- Every other `src/*.asm`, `src/tests/*.asm`, and `docs/*.md`.

## Senior Developer Review (AI)

**Reviewer:** claude-opus-4-7 (1M context) — adversarial review per `bmad-bmm-code-review` workflow
**Review date:** 2026-04-20
**Review outcome:** Changes Requested → **Resolved** (fixed in-place, two passes)
**Findings:** 0 High, 2 Medium, 7 Low (9 total across two review passes). All addressed.

Per project memory `feedback_adversarial_review.md`: reviews MUST find things. A verification-only story is especially suspect for zero-finding outcomes, so this review deliberately hunted for test-harness weaknesses, coverage gaps, and naming-collision risks. Scope excluded `_bmad/` and `_bmad-output/` (standard workflow rule); the in-scope files were `Makefile`, `src/number_prefixes.asm`, `tests/number_prefixes_tests.fth`.

### Findings

**M1 (Medium) — CODE-block coverage gap: `-$FF` (outer-sign on `$` arm) not exercised.**
The feature-parity table in Dev Notes marked `-$FF` CODE-block as ✓ NEW test (9.5), but Task 3.2's enumeration omitted the outer-sign `$` variant. MK_DSN (test 384) exercised `$-FF` (inner sign) and MK_X (test 385) exercised `-0xFF` (outer sign + hex-family), but the outer-sign pre-pass on the `$` arm INSIDE CODE-block context was unvalidated.
*Resolution:* Added test 385a (`MK_DSO` for `-$FF` in CODE block). Verified pass.

**L1 (Low) — Test 394 used bare single-letter `F` as a colon-word name.**
While not currently a reserved word in antforth (verified with a REPL probe), single-letter names are fragile. `C` had already been renamed to `C_MIX` during implementation to avoid collision with the assembler's `C` register; `F` deserved the same treatment for symmetry and future-proofing.
*Resolution:* Renamed `F` → `F_MIX` in test 394 (Makefile and .fth file).

**L2 (Low) — Test 394 negative-guard regex was loose.**
The original guard `(F|C_MIX) \?` used bare-letter `F` as an alternative. Currently safe thanks to the tight positive guard (`42 255 255  ok`), but the pattern would theoretically match any ` F ?` substring.
*Resolution:* Updated guard to `(F_MIX|C_MIX) \?` after L1 rename.

**L3 (Low) — `#-5` (inner-sign-only on `#`) colon-body/CODE coverage not exercised.**
Consistent with story intent: Task 2.2/3.2 enumerations omitted it; the feature-parity table marks double-sign `-#-5` as "skip — covered by XOR-composition tests at REPL". The REPL tests (9.1 test 268 `#-5 .` → -5) provide observational proof; the `.pref_check_sign` helper is context-agnostic.
*Resolution:* No action — documented here per Task 7.3's "document skip rationale" branch. Consistent with story intent.

### Second Review Pass (2026-04-20)

A re-review after M1/L1/L2/L3 resolutions surfaced an additional Medium and three Lows:

**M2 (Medium) — CODE-block coverage gap: `-%1010` (outer-sign on `%` arm) not exercised.**
The first-pass review's M1 caught `-$FF` on the `$` arm, but the symmetric gap on the `%` arm was missed. AC #3's enumeration explicitly lists `-%1010` in the CODE cross-product. Test 386 covered plain `%1010`; test 388 covered `-'A'`; an `MK_BN` for `-%1010` was absent.
*Resolution:* Added test 386a (`MK_BN` for `-%1010` in CODE block). Verified pass.

**L4 (Low) — Test 385a numbered out-of-natural-order.**
`385a` was inserted *before* test 385, and MK_DSO (`-$FF`) is semantically the `$`-arm sibling of MK_DSN (`$-FF`, test 384) — not of MK_X (`-0xFF`, test 385). The "a" suffix convention (200a/200b at Makefile:1751/1759) puts the variant *after* its base.
*Resolution:* Renumbered 385a → 384a (semantic sibling of MK_DSN). Relative position unchanged (the block already sat between tests 384 and 385).

**L5 (Low) — Scaffold-table test-count drift.**
`src/number_prefixes.asm:135` said "~33 REPL-piped tests"; actual count was 34 after the first-pass M1 added 385a, then 35 after the second-pass M2 added 386a.
*Resolution:* Updated comment to read "35 REPL-piped tests" (concrete count, no "~").

**L6 (Low) — AC #3 example syntax showed reversed operand order.**
AC #3, Task 3.1, Task 3.4, Task 3.6, and Task 6.1 used `<val> # <reg> LD,` (e.g. `0xFF # C LD,`), which is backwards per `src/assembler.asm:23-32` Zilog dst-first discipline. Completion Note #2 documented the divergence but the AC text itself wasn't corrected, leaving future readers a copy-paste footgun.
*Resolution:* Rewrote AC #3 and Task 3.1/3.4/3.6/6.1 examples with dst-first form (`C <val> # LD,`). Added cross-reference to `src/assembler.asm:23-32`.

**L7 (Low) — AC #1 HEX-mode enumeration is unreduced.**
AC #1 enumerates 11 HEX-mode variants (`#100`, `-#100`, `$ff`, ..., `-'A'`) but tests only exercise `#100` in HEX (test 371) and `$ff` in DECIMAL (test 372). The reduction is architecturally sound (per-prefix handlers are fixed-base; compiled LIT stores absolute value), but the AC text made no such concession.
*Resolution:* Added an explicit "Test-coverage reduction note" to AC #1 citing §E9-D2 and the LIT absolute-value invariant. No new tests added — the reduction is intentional and justified.

### Items Examined and Cleared

- (a) **Test-numbering density:** Tests 364–396 + 385a are sequentially numbered; no gaps, no stray banners. Each test block has the canonical 2 echo references (PASS + FAIL). The 385a variant mirrors the precedent at Makefile:1815 (test 206a/206b).
- (b) **`$` escaping in printf:** Every bare `$` character in 9.5 test blocks is either `$$OUTPUT` (shell var), `$$FF/$$ff/$$-FF` (printf-fed Make-variable escape), or `\$$` inside echo strings (double-escaped for Make + shell). Zero unescaped `$` followed by alnum.
- (c) **BASE-cross cleanup:** Both BASE-cross tests (371 `HEX + # … DECIMAL` and 390 `HEX + CODE + # … DECIMAL`) end with explicit `DECIMAL` reset. Each printf spawns a fresh `iz-cpm` invocation, so inter-test BASE pollution is architecturally impossible, but the in-session reset is correct belt-and-suspenders discipline.
- (d) **Collision avoidance:** Verified — each printf is a fresh REPL; no inter-test collision possible. Within a session, words used: `F_CH`, `F_CHN`, `F_CHS`, `F_CDS`, `F_CX`, `F_CBN`, `F_CQN`, `F_DH`, `F_HD`, `F_BH`, `F_BD`, `F_BX`, `F_BB`, `F_BQ`, `F_BAD`, `MK_FF`, `MK_FFu`, `MK_D100`, `MK_NEG`, `MK_DS`, `MK_DSN`, `MK_DSO`, `MK_X`, `MK_B`, `MK_Q`, `MK_QN`, `MK_1234`, `MK_CDEC`, `MK_CHEX`, `MK_BS`, `C_BAD`, `F_MIX`, `C_MIX`, `F42N`, `MK_42` — all unique, all non-reserved.
- (e) **Compile-error tightness:** Tests 378 (colon) and 393 (CODE) both assert `<token> ?` AND `<word-name> ?` follow-on AND absence of `[0-9]  ok`. Triple-predicate — tightest discipline in the 9.5 block.
- (f) **No unplanned assembly source changes:** Confirmed via `git diff --stat src/`. Only `src/number_prefixes.asm` is modified, and the diff within the 9.5 addition is pure comment (scaffold-table 9.5 row, lines starting with `;`). Binary size unchanged at 14,787 bytes pre- and post-9.5.

### Action Items

All findings were fixed in-place (no deferrals to 9.6). No HIGH-severity blockers. Across two review passes: 2 MEDIUM resolved by adding test 384a (`-$FF` in CODE) and test 386a (`-%1010` in CODE); 6 LOW resolved by rename (F_MIX/C_MIX), regex tightening, 385a→384a renumber, scaffold-count concretisation, AC-text operand-order correction, and AC #1 HEX-reduction note; 1 LOW documented as intentionally out-of-scope (`#-5` inner-sign skip).

**Final regression pass after fixes:** 405 REPL tests pass (up from 370 baseline; 35 new in 9.5 = 33 planned + 2 review-added). Assembly test suite clean. Binary unchanged at 14,787 bytes.

## Change Log

| Date | Version | Description | Author |
|---|---|---|---|
| 2026-04-20 | 0.1 | Initial implementation: 33 REPL-piped tests (364–396) covering colon-body, CODE-block, mixed-context, and FR47 spot-checks. Scaffold-table 9.5 row added. Zero-byte binary delta. | claude-opus-4-7 (dev-story) |
| 2026-04-20 | 0.2 | Addressed code-review findings: added test 385a (`MK_DSO` for outer-sign `-$FF` in CODE block); renamed test 394's `F` → `F_MIX` and tightened its negative-guard regex. | claude-opus-4-7 (code-review) |
| 2026-04-20 | 0.3 | Second review pass: added test 386a (`MK_BN` for outer-sign `-%1010` in CODE block, M2); renumbered 385a → 384a as semantic sibling of MK_DSN (L4); concreted scaffold-table test count (L5); corrected AC #3 + Task 3.1/3.4/3.6/6.1 operand-order to dst-first (L6); added HEX-reduction note to AC #1 (L7). Regression: 405 REPL tests pass; binary unchanged at 14,787 bytes. | claude-opus-4-7 (code-review) |
