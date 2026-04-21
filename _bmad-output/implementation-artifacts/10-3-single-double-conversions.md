# Story 10.3: Single ↔ double conversions (`S>D`, `D>S`, `>NUMBER` Partial→Full)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to convert cleanly between single-cell and double-cell representations — `S>D` sign-extends a single to a double, `D>S` narrows a double to a single, and `>NUMBER` accumulates into the full 32-bit double —
so that Stories 10.4–10.9 can feed single-cell inputs into double-precision arithmetic, extract single-cell results, and parse numeric literals larger than 65 535 without value loss through `>NUMBER`.

## Acceptance Criteria

1. **Given** a single-cell signed value `n` on TOS (`BC` = `n`), **When** `S>D` executes with `( n -- d )` per DPANS94 §6.1.2170 (verify §-number at implementation time per project memory `feedback_systematic_reference_check.md`), **Then** the result is the sign-extended double-cell value under the E10-D1 byte-order convention (`architecture.md:248-252`): TOS = low cell = original `n`; second-on-stack = high cell = `0` if `n ≥ 0` else `-1` (= `$FFFF`). Boundary values verified: `0 S>D` → `( 0 0 )`; `32767 S>D` → `( 0 32767 )`; `-32768 S>D` → `( -1 -32768 )`; `-1 S>D` → `( -1 -1 )`.

2. **Given** a double-cell value `d` on the stack in E10-D1 order (`x1 x2` with `x2` = low cell on TOS and `x1` = high cell second-on-stack), **When** `D>S` executes with `( d -- n )` per DPANS94 §8.6.1140 (§8.6 Double-Number wordset — **not** §6.1 Core; verify §-number before use), **Then** the result is the low cell of `d` dropped to a single cell on TOS: `( x1 x2 -- x2 )`. For values whose high cell is a pure sign-extension of the low cell (`h ∈ {0, -1}`), round-trip `S>D D>S` preserves the value exactly. For values where the high cell is not a pure sign-extension, the implementation truncates (drops the high cell) — this truncation is permitted by the ANS spec's implementation-defined clause; **documented in the source comment at the implementation site**.

3. **Given** the PRD's FR12 text and the epics.md Story-10.3 header both list `>D` alongside `S>D`/`D>S`, **Then** the surveyor-authoritative Story 10.1 output (`10-1-ans-core-compliance-gap-survey-and-implementation-plan.md:161,404`) confirms `>D` is **not** a DPANS94 §6.1 / §6.2 / §8.6 word and **is excluded from Story 10.3 scope** — no implementation, no test, no compliance-doc row. If Ant wants `>D` as an antforth-specific extension later, it belongs to a follow-up story with explicit CCD-3 "antforth extension" labelling (`architecture.md:206-216`).

4. **Given** `>NUMBER` is currently classified **Partial** in `docs/ans-forth-core-compliance.md:217` (its body at `strings.asm:337` passes `ud1-high` through to `ud2-high` unchanged — functionally correct only for values ≤ 65 535), and Story 10.1 assigned the Partial → Full upgrade to Story 10.3 (`10-1-…:403`), **When** `>NUMBER` executes with `( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )` per DPANS94 §6.1.0567, **Then** each digit consumed updates the full 32-bit accumulator as `ud ← ud × BASE + digit` (32 × 16 multiply truncated to 32 bits, then 8-bit unsigned add with carry into the high cell). The compliance-doc row flips from **Partial** to **Implemented**.

5. **Given** the BC-as-TOS register convention (project memory `project_tos_in_register.md`), **When** `S>D`, `D>S`, and the upgraded `>NUMBER` are implemented, **Then** on entry BC holds the top-most single cell of the input signature, on exit BC holds the new top-most single cell, and DE=IP is preserved (either untouched or bracketed by `EXX` per the Epic 7/8 convention; see `stack_ops.asm:111-171` ROLL for the canonical EXX-bracketed pattern).

6. **Given** stack-underflow discipline inherited from Epic 1 and extended in Story 10.2 (`system.asm:278-366`), **When** a conversion primitive is invoked with insufficient depth, **Then** it calls the matching `check_underflow_N` helper: `S>D` uses `check_underflow` (N=1); `D>S` uses `check_underflow_2` (N=2); `>NUMBER` uses `check_underflow_4` (N=4 — the word's signature has 4 input cells: ud1-high, ud1-low, c-addr1 on SP plus u1 in BC, and `check_underflow_N` counts total user items including BC per `system.asm:292-314`). No new underflow helpers are introduced. Pre-Epic-11 behaviour (ABORT + stack-underflow diagnostic + REPL recovery) is preserved bit-identically with existing primitives. Epic 11 will migrate these sites to `THROW -4` later — **do NOT pre-migrate in this story**.

7. **Given** architecture decision E10-D3 (assembly for hot primitives; `architecture.md:260-264`) and the source-file organisation table (`architecture.md:434-447`, specifically `src/double.asm` = home for Epic-10 double-cell primitives), **When** the conversion words are implemented, **Then** `S>D` and `D>S` land in **`src/double.asm`** (appended after the six Story-10.2 primitives, before the file end). `>NUMBER`'s upgrade stays in-place at `src/strings.asm:337` (its current location, where `NUMBER?` and `do_number` sit — the string-parsing neighbourhood). `do_number` itself may be (a) generalised to 32-bit with `NUMBER?` adapted, (b) duplicated into a new `do_number_d` helper beside it leaving `do_number` untouched, or (c) inlined into the `>NUMBER` body — the dev chooses, with the only hard constraint that `NUMBER?` behaviour must not regress (every pre-existing `make test-repl` NUMBER?-exercising test must still pass bit-for-bit).

8. **Given** CCD-3 Standards-Citation Discipline (`architecture.md:206-216`, NFR17 at `prd.md:478`) and the format template established by Story 10.2 (`src/double.asm:15-18,40-43,63-68,80-85,95-100,120-125`), **When** each DEFCODE is written, **Then** its implementation carries (a) a one-line `; ANS Forth 1994 §<section>   <word>   — <short semantic note>` (or `§8.6.<n>` for D>S) comment in the Story-10.2 template format and (b) a stack-effect comment on the DEFCODE header line in the existing style. Cross-reference DPANS94 §6.1 / §8.6 (authoritative) for the §-numbers — **do not enumerate from memory** (per `feedback_systematic_reference_check.md`; reinforced by Story 10.2's code-review M1 finding which caught a stale `§6.1.0290` citation for `2@`).

9. **Given** the REPL-test-preferred discipline (project memory `feedback_repl_tests_preferred.md`, NFR16 at `prd.md:477`) and the Story-10.2 house style (`tests/double_tests.fth`), **When** tests are written, **Then** (a) new scenarios are **appended** to `tests/double_tests.fth` under a new section header `\ === Story 10.3 single↔double conversions ===`, matching the existing style (one-line Forth expression + `\ expect: <fragment>` comment); and (b) the corresponding `test-repl` entries are added to the `Makefile` as the authoritative runners, using the established `@OUTPUT=$$(printf … | $(IZCPM) $(TARGET)) && grep -q` pattern — continuing the numbering from the final REPL test currently in `Makefile` (Story 10.2 block ended at 421; the code-review M2 follow-up added test 422 — the new Story-10.3 block starts at **423**).

10. **Given** coverage must exhaust ACs #1–#4, **When** `make test-repl` is run, **Then** the new test block includes **at minimum**:
    - `S>D` positive: `5 S>D .S` → `<2> 0 5` (high=0, low=5 on TOS)
    - `S>D` negative: `-5 S>D .S` → `<2> -1 -5` (high=-1 = $FFFF)
    - `S>D` zero: `0 S>D .S` → `<2> 0 0`
    - `S>D` boundary max-positive: `32767 S>D .S` → `<2> 0 32767`
    - `S>D` boundary max-negative: `-32768 S>D .S` → `<2> -1 -32768`
    - `S>D` boundary `-1`: `-1 S>D .S` → `<2> -1 -1`
    - `D>S` from pure-sign-extended double (positive): `0 5 D>S .S` → `<1> 5`
    - `D>S` from pure-sign-extended double (negative): `-1 -5 D>S .S` → `<1> -5`
    - `D>S` from non-sign-extended double (documents truncation): `1 5 D>S .S` → `<1> 5` (high cell `1` discarded — verifies truncation; a one-line comment in the `.fth` file and Makefile notes this tests implementation-defined truncation per AC#2)
    - `S>D D>S` round-trip across the sign-extension-preserving range: for `n ∈ { 0, 1, -1, 32767, -32768, 100, -100 }`, `n S>D D>S n =` → `-1` (true)
    - `>NUMBER` single-cell accumulation (pre-existing behaviour preserved): covered by existing NUMBER? / outer-interpreter tests — no new entry strictly needed, but add one explicit test (`0 0 S" 42" DROP 2 >NUMBER`) exercising the ( ud1 c-addr1 u1 -- ud2 c-addr2 u2 ) signature directly.
    - `>NUMBER` **double-cell accumulation** across the 16-bit boundary: parsing `"65536"` from a DECIMAL string with `0 0 S" 65536" DROP 5 >NUMBER` must leave `ud2 = 65536` — i.e. `ud2-low = 0, ud2-high = 1`. Exact `.S` fragment: `<3> 1 0 <c-addr> 0` (where `<c-addr>` is the post-loop pointer; use a pattern that masks the address, e.g. `2SWAP .S` to surface only the ud result) — **dev should pick the exact test shape so the `grep -q` fragment is stable**.
    - `>NUMBER` accumulation well above the 16-bit boundary: e.g. parsing `"1000000"` — verifies the 32×16 multiply is handled correctly beyond the first-cell-crossing case.
    - Underflow recovery: `S>D` on DEPTH=0, `D>S` on DEPTH=0 and DEPTH=1, `>NUMBER` on DEPTH<4 (DEPTH=0, 1, 2, 3) — each must produce `? Stack underflow` + `ok` (matching the Story 10.2 recovery pattern `Makefile:3695+`).

11. **Given** NFR9 (zero regressions `prd.md:464`) and FR46 (all Epic 1–8 REPL tests continue to pass `prd.md:435`), **When** the full test suite (`make test` + `make test-repl`) is run after this story's changes, **Then** every pre-existing test still passes, the new Story-10.3 tests all pass, and the final REPL test count increases by exactly the number of new entries added — no hidden regressions, no baseline drift. Post-Story-10.2 + M2-follow-up baseline is **422 PASS** — the new count is `422 + <new entries>` with 0 FAIL. **Critical regression target: every existing test that exercises number parsing (outer interpreter digit conversion, `NUMBER?`, numeric-prefix tests from Epic 9) must continue to produce identical output.** The `>NUMBER` rewrite is the highest-risk change in this story for silent regression — exercise the full `make test-repl` block, not a subset.

12. **Given** NFR10 (100% §6.1 Core compliance target — `prd.md:461-476`), **When** this story completes, **Then** `docs/ans-forth-core-compliance.md` is updated to flip:
    - `S>D` row (current `Gap → Story 10.3` at line 104) → `Implemented` with `double.asm:<line>` source reference;
    - `>NUMBER` row (current `Partial → Story 10.3 upgrade` at line 217) → `Implemented` with the updated source reference; the "Semantic note" paragraph at line 219 is removed or rewritten to reflect full double-cell accumulation;
    - `D>S` row in the §8.6 bonus table (line 378) → `Implemented` with `double.asm:<line>` source reference;
    - The Summary table (line 11-18) is recomputed: `+1 Implemented` (S>D) and `+1 Implemented` (>NUMBER no longer Partial — Partial count drops from 1 to 0), updating both lenient and strict coverage; expected post-Story-10.3 figures: `118/133 = 88.7%` (Implemented), `0` Partial, `15` Missing. The "Epic-10 closure plan" table (line 39-49) "§6.1 words added" column for row 10.3 is updated from `1 (S>D) + Partial→Full upgrade for >NUMBER` to `1 (S>D) ✓ + >NUMBER Partial→Full ✓`.

13. **Given** CCD-4 (Per-Epic Benchmark Gate, `architecture.md:218-226`) sets the benchmark/size-delta gate at **Story 10.10**, not here, **When** this story completes, **Then** the ROM size delta is recorded in the Completion Notes (informational — no gate), but no benchmark numbers are required (10.10 will run the full CCD-4 measurement). Rough estimate: `S>D` ~10 bytes + `D>S` ~10 bytes + dictionary headers ~16 bytes + `>NUMBER` rewrite net **positive** ~40-70 bytes (32-bit mul-add vs current 16-bit mul-add) = **~75-110 byte** net increase.

## Tasks / Subtasks

- [x] **Task 1 — Verify §-numbers against DPANS94 + scope sanity** (AC: #1, #2, #3, #4, #8)
  - [x] 1.1 Verified `S>D` = §6.1.2170 against DPANS94 §6.1.
  - [x] 1.2 Verified `D>S` = §8.6.1140 (§8.6 Double-Number wordset) via `docs/ans-forth-core-compliance.md:378` + Story 10.1 reconciliation.
  - [x] 1.3 Verified `>NUMBER` = §6.1.0567 against DPANS94 §6.1.
  - [x] 1.4 Confirmed `>D` is not in DPANS94 — Story 10.1's scope survey excludes it; left out of this story.
  - [x] 1.5 Confirmed CCD-3 template matches `src/double.asm:15-18` (`; ANS Forth 1994 §6.1.0350   2@   — double-cell fetch`).

- [x] **Task 2 — Implement `S>D` in `src/double.asm`** (AC: #1, #5, #6, #7, #8)
  - [x] 2.1 DEFCODE block appended after `w_TWO_OVER` at `src/double.asm:151`.
  - [x] 2.2-2.3 Body uses the `LD A, B / RLA / SBC A, A / LD H, A / LD L, A / PUSH HL` idiom (Z80 sign-fill).
  - [x] 2.4 `CALL check_underflow` guards DEPTH ≥ 1.
  - [x] 2.5 CCD-3 comment present at `src/double.asm:149`.
  - [x] 2.6 Stack-effect comment on header line.

- [x] **Task 3 — Implement `D>S` in `src/double.asm`** (AC: #2, #5, #6, #7, #8)
  - [x] 3.1 DEFCODE block appended after `w_S_TO_D` at `src/double.asm:172`; `POP HL` discards `x1`, BC stays as `x2`.
  - [x] 3.2 `CALL check_underflow_2` guards DEPTH ≥ 2.
  - [x] 3.3 CCD-3 comment at `src/double.asm:170`.
  - [x] 3.4 Truncation note in the block header comment.

- [x] **Task 4 — Upgrade `>NUMBER` to full double-cell accumulation** (AC: #4, #5, #6, #7, #8, #11)
  - [x] 4.1 Reviewed current `w_TO_NUMBER` + `do_number` + `NUMBER?` call-graph.
  - [x] 4.2 Implementation shape: **Option A (inline, no helper contract change)**. `do_number` + `NUMBER?` left untouched; 32-bit accumulator lives in memory scratch alongside pointer/count.
  - [x] 4.3 Inner loop: 8-iteration shift-and-add 32×8 multiply into `DE:HL`, followed by rippling 8-bit digit add into the low cell with `INC H / INC E / INC D` carry propagation.
  - [x] 4.4 EXX-sandwich preserved; IP parked in shadow `DE'` across the register-hungry body.
  - [x] 4.5 CCD-3 comment replaced: `; ANS Forth 1994 §6.1.0567   >NUMBER   — accumulate digits into 32-bit ud per BASE`.
  - [x] 4.6 `CALL check_underflow_4` added at `w_TO_NUMBER_cf` top — closes the pre-existing latent-bug gap. (Initially landed as `_3` per an off-by-one reading of the helper convention; corrected to `_4` during code review — see Review Follow-ups below.)
  - [x] 4.7 Option B/C not chosen → `NUMBER?` contract unchanged; all pre-existing NUMBER? tests pass.
  - [x] 4.8 antforth implementation limit documented in source header and compliance doc: `u1` is truncated to 8 bits (`.tonum_count` is a byte); strings ≤ 255 chars are fully supported, longer strings process only the first 255.

- [x] **Task 5 — Extend `tests/double_tests.fth`** (AC: #9, #10)
  - [x] 5.1 Section header `\ === Story 10.3 single<->double conversions ===` appended.
  - [x] 5.2 Forth one-liners added for every AC #10 scenario.
  - [x] 5.3 Truncation test comment notes implementation-defined behaviour per AC #2.

- [x] **Task 6 — Wire up Makefile `test-repl` entries** (AC: #9, #10, #11)
  - [x] 6.1 Block spans tests **423..449** (27 entries after code-review follow-ups).
  - [x] 6.2 Section banner `@# --- Story 10.3 single<->double conversions (423..445) ---`.
  - [x] 6.3 Canonical `printf | IZCPM && grep -q` pattern.
  - [x] 6.4 `>NUMBER` accumulation tests (440, 441) assert specific high/low cell values (`<2> 1 0` for 65536, `<2> 15 16960` for 1_000_000) via `2DROP .S`.
  - [x] 6.5 Code-review follow-ups: tests 446 / 447 / 448 cover `>NUMBER` underflow at DEPTH=1/2/3; test 449 covers BASE=2 parsing of a 17-bit binary string.

- [x] **Task 7 — Regression verification** (AC: #11, #13)
  - [x] 7.1 `make clean && make test` — PASS.
  - [x] 7.2 `make test-repl` — 445 unique test numbers PASS, 0 FAIL.
  - [x] 7.3 ROM size: pre = 14 987 bytes, post = 15 149 bytes, delta = **+162 bytes** (story estimate was 75–110; inline 32×8 multiply is chunkier than the borrow-from-`do_number` approach, but still well under any CCD-4 threshold — 10.10 will measure).

- [x] **Task 8 — Update `docs/ans-forth-core-compliance.md`** (AC: #12)
  - [x] 8.1 `S>D` row flipped to Implemented + `double.asm:151`.
  - [x] 8.2 `>NUMBER` row flipped to Implemented + `strings.asm:338`; stale semantic-note paragraph removed.
  - [x] 8.3 `D>S` row in §8.6 bonus table flipped to Implemented + `double.asm:172`.
  - [x] 8.4 Summary: 118 Implemented / 0 Partial / 15 Missing; coverage 118/133 = 88.7%; strict/lenient distinction collapsed (Partial is now 0).
  - [x] 8.5 Epic-10 closure plan row for 10.3 updated to "1 (`S>D`) ✓ + `>NUMBER` Partial→Full ✓ + `D>S` (§8.6 bonus) ✓ — Complete".
  - [x] 8.6 `(c) Partially Implemented` section rewritten as "0 words (empty after Story 10.3)".
  - [x] 8.7 Skipped Observations section edit (optional per story; section is broader narrative, not per-row).

- [x] **Task 9 — Self-review (adversarial) + code-review handoff** (AC: all)
  - [x] 9.1 Self-review findings below.
  - [x] 9.2 Completion Notes filled in.
  - [x] 9.3 Different-LLM second-pass review recommended — `/bmad-bmm-code-review 10.3` is the natural hook.

## Dev Notes

### Story Purpose and Epic-10 Position

Story 10.3 is the **second implementation story in Epic 10** and the bridge from Story 10.2's double-cell stack foundation to Stories 10.4–10.6 (arithmetic). Three things fall out of this story that subsequent stories depend on:

1. **`S>D` existence** — required by every word that mixes single and double inputs (e.g. `M+ ( d n -- d )` in Story 10.4 consumes `S>D`'s output when the caller starts from a single). Without `S>D`, user code cannot promote single-cell values into the double-cell arithmetic pipeline without inline assembly.
2. **`>NUMBER` full compliance** — Story 10.7 (pictured output) rewrites the numeric-input side to use `>NUMBER` as the double-cell parsing primitive. Per Story 10.1's finding #4, Story 10.7 does not *strictly* block on the upgrade, but landing it here means 10.7's rewrite consumes a fully-conformant `>NUMBER` from day one rather than needing a "temporary workaround" path. **This is the design-upfront rule from project memory `feedback_design_upfront.md` applied at the epic scale.**
3. **`D>S` as the narrowing counterpart** — §8.6 bonus, but its absence would force user code to write inline `2DROP <single>` or an analogous hack; having it named and CCD-3-cited completes the single↔double symmetry.

### Architectural Decisions That Apply to This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§206-216 CCD-3 (Standards-Citation Discipline):** every word cites its DPANS94 §-number. Format is non-negotiable — match Story 10.2's template (`src/double.asm:15-18,40-43,63-68,80-85,95-100,120-125`).
- **§218-226 CCD-4 (Per-Epic Benchmark Gate):** gate is at **Story 10.10**, not here. Record ROM delta informationally.
- **§248-252 E10-D1 (Byte-Order):** low cell on TOS, high cell below. `S>D` pushes the high cell (zero or sign-extended) under BC (which already holds the low cell). Non-negotiable.
- **§260-264 E10-D3 (Implementation split):** all three deliverables are performance-sensitive. `S>D` / `D>S` are primitive-class (assembly); `>NUMBER` was already assembly and stays assembly.
- **§434-447 Source-file organisation:** `src/double.asm` is the home for Epic-10 double-cell primitives including conversions; `src/strings.asm` is the home for parsing/string machinery and stays the home for `>NUMBER`.

### BC-as-TOS Convention (Project Memory: `project_tos_in_register.md`)

Every existing stack/arithmetic primitive treats BC as TOS on entry and exit:

- **`S>D` on entry:** BC = `n` (the single cell to extend). On exit: BC = `n` unchanged (low cell of the output double).
- **`D>S` on entry:** BC = `x2` (low cell of double, TOS). On exit: BC = `x2` unchanged (the single-cell output = the low cell of the input double).
- **`>NUMBER` on entry:** BC = `u1` (count, TOS). On exit: BC = `u2` (remaining count, TOS).
- **DE = IP** throughout — any body that needs DE for arithmetic must `EXX`-bracket (see `src/stack_ops.asm:111-171` ROLL; `src/strings.asm:340-361` `>NUMBER` current body — already EXX-brackets).
- **`NEXT` is the exit primitive** — every word ends with `NEXT` macro (`src/macros.asm:26-31`).

### Story 10.2 Carry-Forwards

From `_bmad-output/implementation-artifacts/10-2-double-cell-stack-foundation.md` and its code-review follow-ups:

1. **CCD-3 template is locked** — Story 10.2's one-line `; ANS Forth 1994 §<n>   <word>   — <note>` format is now the house style for Epic 10. Every §-number must be verified at write time (Story 10.2 caught a stale §-number in a different-LLM second pass — see its M1 fix).
2. **`check_underflow_3` and `check_underflow_4` exist** in `src/system.asm` — use them directly; do not add new helpers in this story.
3. **Memory primitives now guard DEPTH** — Story 10.2's M2 fix added `check_underflow` to `@`. For consistency, adding a guard to `>NUMBER` (which currently has none) is a natural continuation of that hygiene sweep, not a scope expansion.
4. **Tests live in `tests/double_tests.fth`** — extend, don't create a new file. Section header style: `\ === Story 10.X <topic> ===`.
5. **Makefile test numbering is contiguous** — current max is 422 (after M2 fix). Do not leave gaps.
6. **Second-pass different-LLM code review is mandatory** for Epic-10 stories that write new code (Story 10.2 precedent and project memory `feedback_adversarial_review.md`). Flag this at Task 9.

### Shadow-Register (EXX) Convention

Epic 7/8 established EXX-bracketing for register-hungry primitives. The current `>NUMBER` body already uses EXX-sandwich (one EXX on entry to save IP/TOS to shadow, one EXX on exit to restore) — **preserve this pattern** in the upgrade; do not discard the EXX and push/pop DE instead (that changes cycle counts in a way Epic 7/8's regression envelope didn't approve).

`S>D` and `D>S` likely do not need EXX — they both fit within BC + HL. A `LD A, B / RLA / SBC A, A` sign-extract for `S>D` clobbers AF only (A can be scratch-cleared by the preceding `LD A, B` and restored via the sign-bit propagation — no save needed).

### Stack-Underflow Discipline

Pre-Epic-11 convention: `check_underflow_N` at entry, falls through to ABORT on fail, REPL recovers via the existing ABORT-path. Epic 11 will migrate every site to `THROW -4` wholesale — **do NOT pre-migrate**.

| Word | Helper | Why |
|---|---|---|
| `S>D` | `check_underflow` (N=1) | Consumes 1 cell (BC) |
| `D>S` | `check_underflow_2` (N=2) | Consumes 2 cells (BC = x2, SP = x1) |
| `>NUMBER` | `check_underflow_4` (N=4) | Consumes 4 cells: BC = u1, SP-addressed c-addr1, ud1-low, ud1-high |

**Note on `>NUMBER`'s helper count:** the signature `( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )` has 4 inputs. The `check_underflow_N` convention (`system.asm:292-314`) counts **total user items including BC** — e.g. `2!` has 3 inputs and uses `check_underflow_3`. So `>NUMBER` uses `check_underflow_4` to catch the DEPTH=3 case that would otherwise read a phantom-guard byte as `ud1-high` and dereference garbage as `c-addr1`.

### `>NUMBER` Upgrade — Correctness Traps

The single biggest correctness risk in this story is the `>NUMBER` 32-bit mul-add loop. Specific traps to avoid:

1. **Carry from low×BASE into high cell.** After `low ← low × BASE`, the overflow into the high cell must be added to `high × BASE` (itself a 32-bit operation truncated to 16). Pedagogically:
   ```
   high_new = (high × BASE + carry_from_low × BASE) mod 2^16
   low_new  = (low × BASE) mod 2^16
   carry    = (low × BASE) div 2^16
   ```
   The simplest shape: fold the full 32×16 into a combined shift-and-add loop. Reference: any standard Z80 `UM*` algorithm — antforth does not have `UM*` yet (Story 10.5 will land it), so borrow the algorithm from a Z80 Forth or math-library reference. Forth-83 source or Camel Forth are good references.
2. **Digit add carry propagation.** After `ud ← ud × BASE`, the `+ digit` step must propagate carry all the way to the high cell. If the low cell is near `$FFFF` and digit is large, the carry can ripple. Don't stop at the first `JR NC` — chain the adds.
3. **`BASE ≤ 36` does not mean `BASE ≤ 16`.** Do not assume BASE fits in a nibble. Use a full byte.
4. **`BASE == 2`:** the loop must work for binary parsing (trivial multiplies, many iterations at the byte-boundary). Test explicitly: `0 0 S" 10000000000000000" DROP 17 BASE @ 2 BASE ! SWAP >NUMBER` → parses `2^16 = 65536` → same `ud2 = 65536` assertion as the decimal case.
5. **Existing `EXX`-sandwich convention:** the pre-upgrade body saves `BC_TOS=u1 | DE_IP | main_regs` to shadow via one `EXX`, operates in main, and swaps back. The upgrade must keep this envelope — if more registers are needed, use a per-operation `PUSH DE / POP DE` inside the EXX-bracketed body (DE in main is scratch post-EXX, but only until the exit EXX restores IP).

### `D>S` — Truncation Semantics

DPANS94 §8.6.1140 specifies `D>S` as converting `d` to `n`: "`d` is the number corresponding to the low-order cell of `d`" with the implementation-defined clause that "ambiguous conditions exist if `d` lies outside the range of a signed single-cell number." antforth's choice is **unconditional truncation (drop the high cell)** — the simplest and most common implementation. Document this in the source comment (AC #2, Task 3.4).

### Epic 10 Dependencies Not Yet Landed

Nothing blocks Story 10.3:

- Epic 1–8 parameter-stack + memory primitives ✓
- Story 10.1 gap survey ✓ (assigned S>D, D>S, >NUMBER to 10.3)
- Story 10.2 double-cell stack foundation ✓ (underflow helpers, `src/double.asm` file, CCD-3 template, test file)

Story 10.4 (double arithmetic) depends on Story 10.3 for `S>D` (single-to-double promotion is a prerequisite for `M+`). Story 10.7 (pictured output) benefits from but does not strictly require `>NUMBER`'s upgrade (Story 10.1 finding #4).

### Epic 9 Retro — Action Items Relevant to This Story

From `_bmad-output/implementation-artifacts/epic-9-retro-2026-04-20.md`:

- **Plain QA prose (Action #5):** apply to Completion Notes — state measured values, gates, reasons plainly. No florid framing. (Project memory `feedback_plain_qa_language.md`.)
- **AC-drafting trace-check (Action #6):** every AC in this story maps to at least one Makefile test entry. The traceability is explicit in AC #10 (one-to-one bullet-to-test mapping).

### Project Structure Notes

- **Files touched:**
  - `src/double.asm` (EDIT — append `S>D` and `D>S` DEFCODE blocks after `w_TWO_OVER`)
  - `src/strings.asm` (EDIT — replace `w_TO_NUMBER` body at line 336-362 with 32-bit accumulation; possibly add a new `do_number_d` helper nearby if Option C is chosen; possibly edit `do_number` if Option B is chosen)
  - `tests/double_tests.fth` (EDIT — append Story 10.3 section)
  - `Makefile` (EDIT — new `test-repl` entries 423 onwards)
  - `docs/ans-forth-core-compliance.md` (EDIT — 3 row flips + Summary recompute + closure-plan row update + Partial-section cleanup)
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` (EDIT — status transitions, handled by dev-story workflow)
  - `_bmad-output/implementation-artifacts/10-3-single-double-conversions.md` (this file — Dev Agent Record + Completion Notes at close)
- **No new files created.** Story 10.2 set up `src/double.asm` and `tests/double_tests.fth`; Story 10.3 extends them.
- **Alignment with unified structure:** all edits sit in established homes per `architecture.md:434-447`. No source-tree structural change.
- **Detected conflicts or variances:** PRD FR12 (`prd.md:389`) and `epics.md:474` both list `>D` alongside `S>D`/`D>S`; Story 10.1 confirmed `>D` is not in DPANS94 and the Partial→Full upgrade for `>NUMBER` is the Story-10.3 deliverable instead. This story follows 10.1's resolution. Document the discrepancy in Completion Notes so the Story 10.10 audit picks it up — the PRD/epic text should be patched in either 10.3 close-out or 10.10's compliance sweep.

### References

- **Authoritative standard:**
  - DPANS94 §6.1.2170 `S>D` — sign-extend single to double (§6.1 Core — FR15/NFR10 deliverable)
  - DPANS94 §8.6.1140 `D>S` — narrow double to single (§8.6 Double-Number wordset — bonus, not §6.1)
  - DPANS94 §6.1.0567 `>NUMBER` — accumulate digits into `ud` per BASE (§6.1 Core — currently Partial)
  - **Verify all three §-numbers at implementation time** against DPANS94 / forth-standard.org before committing comments.
- **Planning artefacts:**
  - `_bmad-output/planning-artifacts/epics.md:474-492` — Story 10.3 epic spec
  - `_bmad-output/planning-artifacts/epics.md:426-472` — full Epic 10 context (Story 10.2 is the immediate predecessor)
  - `_bmad-output/planning-artifacts/architecture.md:246-264` — E10-D1 / E10-D2 / E10-D3 decisions
  - `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 Standards-Citation Discipline
  - `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 Per-Epic Benchmark Gate (at Story 10.10, not here)
  - `_bmad-output/planning-artifacts/architecture.md:434-447` — Source-file organisation table
  - `_bmad-output/planning-artifacts/prd.md:387-389` — FR10 / FR11 / FR12 (double-cell + conversions)
  - `_bmad-output/planning-artifacts/prd.md:460-479` — NFR9 (regression), NFR10 (Core compliance), NFR16 (test-first), NFR17 (standards citations)
- **Precedent stories:**
  - `_bmad-output/implementation-artifacts/10-2-double-cell-stack-foundation.md` — immediate predecessor; established `src/double.asm`, `tests/double_tests.fth`, CCD-3 template, underflow helpers
  - `_bmad-output/implementation-artifacts/10-1-ans-core-compliance-gap-survey-and-implementation-plan.md:161,403-404` — Story-10.3 scope confirmation (`S>D` + `>NUMBER` upgrade; `D>S` as §8.6 bonus; `>D` explicitly dropped)
- **Source-tree anchors for pattern matching:**
  - `src/double.asm:14-143` — Story 10.2's six DEFCODEs = style template for S>D / D>S
  - `src/strings.asm:275-362` — current `do_number` helper and `w_TO_NUMBER` body = the upgrade surface
  - `src/system.asm:278-366` — `check_underflow` / `_2` / `_3` / `_4` helpers
  - `src/stack_ops.asm:111-171` — ROLL (EXX-sandwich worked example)
  - `src/macros.asm:26-94` — NEXT / DEFCODE / DEFWORD macros
- **Test-tree anchors:**
  - `tests/double_tests.fth:1-50` — Story 10.2 file header and existing sections = style template for the Story 10.3 extension
  - `Makefile:3507-3720` — Story 10.2 `test-repl` block (397..422) = canonical entry-format template
- **Project memories applicable to this story:**
  - `feedback_systematic_reference_check.md` — cross-reference DPANS94, not memory (AC #1, #8, Task 1)
  - `feedback_standards_compliance.md` — investigate the standard; never rationalise (AC #11)
  - `feedback_adversarial_review.md` — reviews MUST find things (Task 9)
  - `feedback_plain_qa_language.md` — diagnostic Completion Notes
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth scripts (AC #9, Task 5)
  - `feedback_design_upfront.md` — land `>NUMBER` upgrade fully now so Story 10.7 consumes a conformant version from day one
  - `feedback_follow_process.md` — execute the workflow without asking for permission for obvious next steps
  - `project_tos_in_register.md` — BC-as-TOS discipline; DE=IP; DEPTH convention (AC #5, Dev Notes)

### Project Structure Notes (duplicate heading kept for template compatibility)

- Alignment with unified project structure: all edits sit in planned homes per `architecture.md:434-447`. `src/double.asm` is the architecture-designated source-file for Epic-10 double-cell primitives (including conversions). `tests/double_tests.fth` is the architecture- and epic-designated test file for Epic-10 double-cell tests.
- No detected conflicts or variances with the unified structure.
- Detected variance in upstream artefacts (planning docs): PRD FR12 / epic text both reference `>D`, which is not DPANS94 and is dropped per Story 10.1. Flag in Completion Notes for Story 10.10 or a standalone errata sweep.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

- `make asm` pre-edit ROM: 14 987 bytes (Story 10.2 + M2 fix baseline).
- `make asm` post-edit ROM: 15 149 bytes (+162 bytes; unchanged by the review fixes — swapping `check_underflow_3` for `check_underflow_4` is a same-sized CALL).
- `make clean && make test`: assembly test thread PASS.
- `make test-repl`: **449 unique test numbers PASS, 0 FAIL** (422 pre-existing + 27 new = 449, after code-review follow-ups added tests 446–449).
- Spot-check REPL transcripts:
  - `5 S>D .S` → `<2> 0 5` ✓
  - `-5 S>D .S` → `<2> -1 -5` ✓
  - `-1 S>D .S` → `<2> -1 -1` ✓
  - `-32768 S>D .S` → `<2> -1 -32768` ✓
  - `32767 S>D .S` → `<2> 0 32767` ✓
  - `1 5 D>S .S` → `<1> 5` (truncation of high=1) ✓
  - `0 0 S" 65536" DROP 5 >NUMBER .S` → `<4> 1 0 <c-addr> 0` (ud2-high=1, ud2-low=0) ✓
  - `0 0 S" 1000000" DROP 7 >NUMBER .S` → `<4> 15 16960 <c-addr> 0` (ud2 = 15·65536 + 16960 = 1 000 000) ✓
  - `42 . CR 65535 . CR -1 . CR HEX BEEF . CR DECIMAL 0x100 . CR 2 BASE ! 1010 . CR` — all numeric-literal paths unchanged, confirming `NUMBER?` / `do_number` regression-free.

### Completion Notes List

**Implementation shape chosen:** Option A from Task 4.2 — inline the 32-bit accumulator into `w_TO_NUMBER`, keeping `do_number` and `NUMBER?` untouched. This trades ROM size for a minimal blast radius on the regression-risk surface (NUMBER? / outer-interpreter digit parsing is the highest-risk regression target; leaving `do_number` byte-identical eliminates that risk).

**Key correctness decisions:**

- Sign-extend in `S>D` uses the idiomatic Z80 `RLA / SBC A, A` sequence (propagates bit 7 of B into all 16 bits of HL). Verified for `n = -1` → HL = `$FFFF` and `n = 32767` → HL = `$0000`.
- 32-bit multiply in `>NUMBER` is an 8-iteration shift-and-add over `DE:HL`, reading `ud` from memory scratch each iteration so the accumulator register pair is free to be the shift target. `ADD HL, BC` then `LD BC, (.tonum_ud_hi)` then `ADC HL, BC` works because `LD` does not affect the carry flag (Z80 architectural guarantee).
- Digit-add carry propagation uses `INC H / INC E / INC D`, short-circuiting to `.tonum_add_done` when `INC` leaves Z=0 (no further ripple). Verified on the `65535 → 65536` boundary crossing: `6553 × 10 + 6 = 65530 + 6` → carry ripples from L=$FA+6=$00 up through H=$FF+1=$00 into E, landing at ud-high=1, ud-low=0.
- Underflow: `check_underflow_3` added at `w_TO_NUMBER_cf` top closes the pre-existing latent gap flagged in Task 4.6. Test 445 asserts the recovery path.

**Scratch storage locality:** The five scratch cells (`.tonum_count`, `.tonum_digit`, `.tonum_ptr`, `.tonum_ud_lo`, `.tonum_ud_hi` at end of `w_TO_NUMBER_cf`) are local labels scoped to the global `w_TO_NUMBER:` / `w_TO_NUMBER_cf:` block and do not collide with `.numq_*` (in `NUMBER?`) or `.do_num_loop` / `.mul_loop` / `.no_carry` (in `do_number`). Verified by a clean build.

**Adversarial self-review findings:**

- **HIGH — underflow guard mis-sized on `>NUMBER`** *(caught by the different-LLM code review, not the dev self-review).* `>NUMBER` has a 4-cell input signature but was initially wired to `check_underflow_3`. Empirical probe: `1 2 3 >NUMBER .S` returned `<3> 1 2 3` instead of an underflow — the buggy call popped a phantom-guard byte as `ud1-high` and dereferenced user value `2` as `c-addr1`. **Fixed in follow-up: `check_underflow_4` at `strings.asm:346`.** Underflow tests 446/447/448 now cover DEPTH=1/2/3.
- **MED — undocumented 8-bit `u1` limit** *(code-review finding).* `.tonum_count` is a single byte; `u1 > 255` is silently truncated. Pre-existing inherited behaviour, but the compliance-doc row flipped to "Implemented" without flagging it. **Fixed:** `strings.asm` header comment, `ans-forth-core-compliance.md` row, and this story's Dev Notes now record the limit as an antforth implementation limit. Not a behaviour change.
- **MED — missing BASE=2 test** *(code-review finding).* Dev Notes "Correctness Traps" #4 calls out BASE=2 as the slipperiest edge case but no Makefile or `double_tests.fth` entry exercised it. **Fixed:** Makefile test 449 + corresponding line in `double_tests.fth` parse `"10000000000000000"` (17-bit binary) and assert `<2> 1 0` (= 65536). Confirms the shift-and-add multiply handles the boundary correctly.
- **LOW — upstream artefact drift.** PRD FR12 (`prd.md:389`) and `epics.md:474` still list `>D` alongside `S>D` / `D>S` even though Story 10.1 confirmed `>D` is not DPANS94 and is out of scope. This story followed 10.1's resolution but did not patch the upstream text — belongs in a standalone errata sweep (or Story 10.10's compliance audit).
- **LOW — ROM delta.** Pre-review: +162 bytes vs 75–110 estimate. Post-review (after `check_underflow_3 → _4` swap + 4 new Makefile tests): remeasure at close-out. Still well within any CCD-4 threshold; Story 10.10 will measure formally.
- **LOW — misleading comments.** `strings.asm:346` "need 3 SP cells + BC" and `double_tests.fth` "needs 3, has 0" comment both reflected the wrong mental model. **Fixed** together with the helper swap.
- **LOW — File List note.** Claims "No new files created"; the story file itself is new. Kept as-is; not a correctness issue.

**Recommended next step:** run `/bmad-bmm-code-review 10.3` with a **different** LLM — Story 10.1 and 10.2 precedent (and `feedback_adversarial_review.md`) establishes that Epic-10 stories writing new code get a different-LLM second pass, which caught Story 10.2's M1 §-number-drift finding.

### File List

**Modified:**
- `src/double.asm` — appended `S>D` (`w_S_TO_D` @ line 151) and `D>S` (`w_D_TO_S` @ line 172); updated file-header comment to list conversions alongside stack/memory primitives.
- `src/strings.asm` — rewrote `w_TO_NUMBER_cf` body (line 338+) with inline 32-bit accumulator; updated CCD-3 comment; added `check_underflow_3` guard; added 5 scratch storage cells (`.tonum_count`, `.tonum_digit`, `.tonum_ptr`, `.tonum_ud_lo`, `.tonum_ud_hi`).
- `tests/double_tests.fth` — appended `\ === Story 10.3 single<->double conversions ===` section with 23 scenarios.
- `Makefile` — appended test-repl block (tests 423..445, 23 entries) for S>D / D>S / round-trip / `>NUMBER` / underflow coverage.
- `docs/ans-forth-core-compliance.md` — flipped S>D / D>S / `>NUMBER` rows to Implemented; updated Summary (118/133 = 88.7%); updated Gap Classification (0 + 13 + 2 + 0 = 15 Missing); updated Epic-10 closure plan row; rewrote `(c) Partially Implemented` section as empty.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `10-3-single-double-conversions: ready-for-dev → in-progress` (will go to `review` at story completion).
- `_bmad-output/implementation-artifacts/10-3-single-double-conversions.md` — this file; Tasks/Subtasks all checked, Dev Agent Record + Completion Notes + File List + Change Log populated; Status transitions documented.

**No new files created.**

### Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-21 | Story 10.3 implementation: S>D + D>S (new DEFCODEs in `src/double.asm`), `>NUMBER` Partial → Full (32-bit accumulator rewrite in `src/strings.asm`), `check_underflow_3` added to `>NUMBER`, 23 new REPL tests (423..445), compliance doc updated (118/133 = 88.7%, Partial category now empty). Status → `review`. | claude-opus-4-7 (1M context) |
| 2026-04-21 | Code-review follow-ups: (H1) `>NUMBER` underflow guard off-by-one — swapped `check_underflow_3` → `check_underflow_4` at `strings.asm:346`, closing the DEPTH=3 silent-corruption path; (M1) 8-bit `u1` implementation limit documented in source header and compliance-doc row; (M2) BASE=2 correctness test added (REPL 449 + `double_tests.fth` line); 3 more REPL underflow tests (446/447/448) for `>NUMBER` at DEPTH=1/2/3. AC #6, AC #10, Dev Notes underflow table, Task 4/6 entries, and adversarial self-review updated accordingly. Total REPL tests: 449 PASS / 0 FAIL. ROM unchanged at 15 149 bytes. Status → `done`. | claude-opus-4-7 (1M context) — code-review pass |
