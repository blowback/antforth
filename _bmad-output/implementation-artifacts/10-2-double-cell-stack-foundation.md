# Story 10.2: Double-cell stack foundation (`2@`, `2!`, `2DUP`, `2DROP`, `2SWAP`, `2OVER`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to push, drop, duplicate, swap, and copy double-cell values on the parameter stack — and store/fetch them through memory — using the standard `2*` wordset,
so that Stories 10.3–10.8 have a working double-cell stack/memory foundation to build all subsequent double-precision arithmetic and pictured-output work upon.

## Acceptance Criteria

1. **Given** the ANS Forth 1994 byte-order convention locked in by architecture decision **E10-D1** (`_bmad-output/planning-artifacts/architecture.md:248-252`) — low cell on top of stack, high cell below — **When** `2@` fetches a double-cell value from `a-addr`, **Then** the low cell ends on TOS and the high cell is second-on-stack: `(a-addr — x1 x2)` where `x2` is the cell read from `a-addr` (low) and `x1` is the cell read from `a-addr + 2` (high), per DPANS94 §6.1.0350.

2. **Given** a double-cell pair on the stack in E10-D1 order (`x1 x2`, `x2` on TOS = low cell) and an address below it, **When** `2!` executes with `( x1 x2 a-addr -- )`, **Then** it writes `x2` (low cell) to `a-addr` and `x1` (high cell) to `a-addr + 2` and consumes all three items, per DPANS94 §6.1.0310. `2! 2@` round-trips the same double-cell value byte-for-byte.

3. **Given** the remaining double-cell stack primitives `2DUP` (§6.1.0380), `2DROP` (§6.1.0370), `2SWAP` (§6.1.0430), `2OVER` (§6.1.0400) — §-numbers to be verified against DPANS94 at implementation time per project memory `feedback_systematic_reference_check.md` — **When** each is invoked against its specified stack signature, **Then** the ANS-specified effect is produced, preserving double-cell order integrity under E10-D1:
   - `2DUP    ( x1 x2 -- x1 x2 x1 x2 )`
   - `2DROP   ( x1 x2 -- )`
   - `2SWAP   ( x1 x2 x3 x4 -- x3 x4 x1 x2 )`
   - `2OVER   ( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )`

4. **Given** the BC-as-TOS convention (project memory `project_tos_in_register.md`), **When** each new word is implemented, **Then** on entry BC holds `x2` (top single cell of the pair / the last pushed cell) and the remaining cells are on the SP-addressed parameter stack; on exit the post-op TOS is in BC, consistent with the convention already enforced by `DUP` / `DROP` / `SWAP` / `OVER` (`src/stack_ops.asm:13-70`) and `@` / `!` (`src/memory.asm:43-67`).

5. **Given** stack-underflow discipline inherited from Epic 1 (see `system.asm:278` `check_underflow`, `system.asm:302` `check_underflow_2`), **When** a double-cell primitive is invoked with insufficient depth, **Then** it calls the appropriate `check_underflow_N` helper (adding a new `check_underflow_3` / `check_underflow_4` helper only if strictly required — BC + N cells on SP) so that pre-Epic-11 behaviour (ABORT + stack-underflow diagnostic + REPL recovery) is preserved bit-identically with existing primitives. Epic 11 will migrate these sites to `THROW -4` later — **do NOT pre-migrate in this story** (no ABORT-path reshaping).

6. **Given** architecture decision **E10-D3** (assembly for hot primitives; `architecture.md:260-264`) and source-file organisation (`architecture.md:434-447`), **When** the six words are implemented, **Then** they live in a new file **`src/double.asm`**, which is added to `src/antforth.asm`'s INCLUDE list in an appropriate location (after `memory.asm` / before `control_flow.asm` reads naturally; exact placement is a style choice — align with the epic source-file-organisation table).

7. **Given** the CCD-3 Standards-Citation Discipline (`architecture.md:206-216`, NFR17 `prd.md:478`), **When** each DEFCODE is written, **Then** its implementation carries (a) a one-line `; ANS Forth 1994 §<section>   <word>   — <short semantic note>` comment in the exact format used by the existing primitive sites, and (b) a stack-effect comment on the DEFCODE header line in the existing style (see `src/stack_ops.asm:9-10`, `src/memory.asm:39-41`). Cross-reference DPANS94 §6.1 for the authoritative §-numbers — do not enumerate from memory (per `feedback_systematic_reference_check.md`).

8. **Given** the REPL-test-preferred discipline (project memory `feedback_repl_tests_preferred.md`, NFR16 `prd.md:477`), **When** tests are written, **Then** (a) a new file **`tests/double_tests.fth`** is created capturing every test scenario as documented REPL-piped Forth one-liners with expected output, matching the style of `tests/number_prefixes_tests.fth`; and (b) the corresponding `test-repl` entries are added to the `Makefile` as the authoritative runners, using the established `printf … | $(IZCPM) $(TARGET) … grep -q` pattern — continuing the numbering from the final REPL test currently in `Makefile` (Story 9.5 ended at test 396; `make test-repl` reports 405 PASS total including lettered sub-variants per Story 10.1 regression baseline — use the next sequential integer).

9. **Given** coverage must exhaust the ACs above, **When** `make test-repl` is run, **Then** the new test block includes **at minimum**:
   - `2@` round-trip read of a known 32-bit value: write bytes via `C!` / `!` (or `, ,`) to reserved storage, read with `2@`, verify low cell on TOS and high cell second via `.S` + two `.` calls.
   - `2!` round-trip write: build a double, `2!` into reserved storage, then `2@` back; assert byte-for-byte equivalence.
   - `2!` / `2@` round-trip at high/low boundary values (0, `$FFFF` in both cells, `$8000` in each cell) — exercises E10-D1 ordering.
   - `2DUP` depth + values check: `1 2 2DUP .S` asserts `<4> 1 2 1 2 ` (E10-D1: `2` is TOS).
   - `2DROP` depth check: `1 2 3 4 2DROP .S` asserts `<2> 1 2 `.
   - `2SWAP` ordering check: `1 2 3 4 2SWAP .S` asserts `<4> 3 4 1 2 ` (high/low order preserved within each pair).
   - `2OVER` ordering check: `1 2 3 4 2OVER .S` asserts `<6> 1 2 3 4 1 2 `.
   - Stack-underflow recovery: `2DUP`, `2DROP`, `2SWAP`, `2OVER`, `2@`, `2!` each invoked on insufficient depth produces the ABORT stack-underflow diagnostic and recovers to the REPL (same behaviour as existing underflow sites — match the existing pattern at `Makefile:` test 10 onwards).

10. **Given** NFR9 (zero regressions `prd.md:464`) and FR46 (all Epic 1–8 REPL tests continue to pass `prd.md:435`), **When** the full test suite (`make test` + `make test-repl`) is run after this story's changes, **Then** every pre-existing test still passes, the new double-cell tests all pass, and the final REPL test count increases by exactly the number of new entries added — no hidden regressions, no baseline drift (Epic 9 closure reported 405 PASS; the new count is `405 + <new tests added>` with 0 FAIL).

11. **Given** CCD-4 (Per-Epic Benchmark Gate, `architecture.md:218-226`) sets the benchmark/size-delta gate at **Story 10.10**, not here, **When** this story completes, **Then** the ROM size delta is recorded in the Completion Notes (informational — no gate), but no benchmark numbers are required (10.10 will run the full CCD-4 measurement).

## Tasks / Subtasks

- [x] **Task 1 — Verify §-numbers against DPANS94** (AC: #1, #2, #3, #7)
  - [x] 1.1 Verified §-numbers against `docs/ans-forth-core-compliance.md` (Story 10.1 refresh, DPANS94-authoritative): 2! §6.1.0310, 2@ §6.1.0350, 2DROP §6.1.0370, 2DUP §6.1.0380, 2OVER §6.1.0400, 2SWAP §6.1.0430.
  - [x] 1.2 Byte-order semantics confirmed from DPANS94 2@/2! stack diagrams and the equivalent reference sequences (`DUP CELL+ @ SWAP @` for 2@; `SWAP OVER ! CELL+ !` for 2!) — low cell at a-addr, high cell at a-addr+2. Matches E10-D1.

- [x] **Task 2 — Create `src/double.asm` and wire it into the build** (AC: #4, #6)
  - [x] 2.1 Created `src/double.asm` with file-header block declaring "Epic 10 double-cell primitives" and the E10-D1 byte-order convention.
  - [x] 2.2 Added `INCLUDE "double.asm"` to `src/antforth.asm` immediately after `INCLUDE "memory.asm"`.
  - [x] 2.3 `make asm` passed on empty-body file before adding bodies.

- [x] **Task 3 — Implement `2@`** (AC: #1, #4, #5, #7)
  - [x] 3.1–3.4 Implemented at `src/double.asm:20`. BC preserved as a-addr throughout; reads high cell (at a-addr+2) into HL via A-register for the low byte, PUSH HL, then reads low cell into BC. Guard: `check_underflow`. CCD-3 §6.1.0350 comment inline.

- [x] **Task 4 — Implement `2!`** (AC: #2, #4, #5, #7)
  - [x] 4.1–4.4 Implemented at `src/double.asm:45`. Uses BC and HL only; DE untouched. Pops x2 (low, stored at a-addr), x1 (high, stored at a-addr+2), then new TOS. `check_underflow_3` added to `src/system.asm` matching `check_underflow_2` style (threshold 8 bytes). CCD-3 §6.1.0310 comment inline.

- [x] **Task 5 — Implement `2DUP`** (AC: #3, #4, #5, #7)
  - [x] 5.1–5.4 Implemented at `src/double.asm:70`. POP HL / PUSH HL to peek x1, PUSH BC (x2 copy), PUSH HL (x1 copy); BC unchanged. Guard: `check_underflow_2`. CCD-3 §6.1.0380 comment inline.

- [x] **Task 6 — Implement `2DROP`** (AC: #3, #4, #5, #7)
  - [x] 6.1–6.4 Implemented at `src/double.asm:87`. POP HL (discard x1), POP BC (new TOS). **Deviation from task 6.3's suggestion:** used `check_underflow_2` (DEPTH ≥ 2) not `check_underflow_3`. Rationale: the existing helpers guard N cells on SP = N POPs = ANS DEPTH ≥ N. DROP does 1 POP with `check_underflow`; 2DROP does 2 POPs, so `check_underflow_2` is the parallel. Using `_3` would reject the legal ANS DEPTH=2 case. Verified against ANS 2DROP: input stack need only contain (x1 x2), nothing deeper. CCD-3 §6.1.0370 comment inline.

- [x] **Task 7 — Implement `2SWAP`** (AC: #3, #4, #5, #7)
  - [x] 7.1–7.4 Implemented at `src/double.asm:102` using EXX-sandwich pattern consistent with ROLL (`stack_ops.asm:111`). One initial EXX, pops x3/x2/x1 into main BC/HL/DE (main scratch after EXX, shadow preserves original BC=x4 and DE=IP); then 4 pushes interleaved with 2 EXX toggles to interleave the correct values onto SP in (guard, x3, x4, x1, x2-staged) order; final EXX retrieves IP and POP BC pulls x2 into TOS. `check_underflow_4` added to `src/system.asm` matching existing helper style (threshold 10). CCD-3 §6.1.0430 comment inline.

- [x] **Task 8 — Implement `2OVER`** (AC: #3, #4, #5, #7)
  - [x] 8.1–8.4 Implemented at `src/double.asm:127` without EXX. PUSH BC (x4) moves x4 to SP; then `LD HL, 6 / ADD HL, SP` accesses x1 at SP+6, reads into BC, PUSH BC; then same indexed read at new SP+6 to fetch x2 into BC. `check_underflow_4` (shared with 2SWAP). CCD-3 §6.1.0400 comment inline.

- [x] **Task 9 — Underflow-helper additions** (AC: #5)
  - [x] 9.1 Added `check_underflow_3` (threshold 8) and `check_underflow_4` (threshold 10) to `src/system.asm` immediately after `check_underflow_2`. Structure matches `check_underflow_2` byte-for-byte with the CP-N value adjusted.
  - [x] 9.2 Kept helpers as unrolled fixed-N (not parameterised) so Epic 11's planned THROW -4 migration can drop them all wholesale.

- [x] **Task 10 — Write `tests/double_tests.fth`** (AC: #8, #9)
  - [x] 10.1–10.3 Created `tests/double_tests.fth` with header, grouped sections per word, and a byte-order anchor using `HEX CREATE D1 BEEF , DEAD , D1 2@ .S` expecting `<2> -2153 -4111` (= DEAD BEEF in signed hex) — unambiguously demonstrates low cell (BEEF at D1) lands on TOS.

- [x] **Task 11 — Wire up Makefile `test-repl` entries** (AC: #8, #9, #10)
  - [x] 11.1 Numbering continues from Story 9.5's max integer test (396) → new block runs 397..421 (25 tests).
  - [x] 11.2 Each entry uses the canonical `@OUTPUT=$$(printf ... | $(IZCPM) $(TARGET)) && grep -q ...` pattern.
  - [x] 11.3 Block prepended with `@# --- Story 10.2 double-cell stack foundation (397..421) ---`.
  - [x] 11.4 Underflow-recovery tests assert both `? Stack underflow` and `ok`.

- [x] **Task 12 — Regression verification** (AC: #10, #11)
  - [x] 12.1 `make test` → "PASS: Output matches expected". Assembly thread green.
  - [x] 12.2 `make test-repl` → 430 PASS, 0 FAIL. Delta 405 → 430 = +25 (exactly matches the 25 new entries).
  - [x] 12.3 ROM size: 14787 → 14984 bytes = **+197 bytes**. Within story's ~200-300 byte estimate. Recorded in Completion Notes (informational; CCD-4 gate is Story 10.10).

- [x] **Task 13 — Update compliance doc** (AC: per Story 10.1's pattern)
  - [x] 13.1 Flipped 6 rows from "Gap → Story 10.2" to "Implemented" with `double.asm:<line>` references.
  - [x] 13.2 Summary: Implemented 110→116, Missing 22→16, coverage 83.5%→88.0% lenient (82.7%→87.2% strict). Updated Observations section (Stack ops and Memory both at 100%). Tagged the 10.2 row in the Epic-10 closure plan as ✓ Implemented.
  - [x] 13.3 Gap Analysis sections left intact.

- [x] **Task 14 — Code review** (AC: all)
  - [x] 14.5 Second-pass adversarial review (different LLM) completed 2026-04-21. Findings + fixes:
    - **M1 (Medium, fixed):** stale `§6.1.0290` citation for `2@` in `architecture.md:252`, `epics.md:460`, `epics.md:484` — not backported when dev used correct `§6.1.0350` in `double.asm`. Fixed all three sites to `§6.1.0350` (and `epics.md:484` corrected to `§6.1.2170` for `S>D`).
    - **M2 (Medium, fixed):** `2@` called `check_underflow` but the single-cell `@` in `memory.asm` did not — inconsistent DEPTH=0 semantics for parallel words. Added `CALL check_underflow` to `@` (+CCD-3 citation `§6.1.0650`). ROM +3 bytes (one CALL). New REPL test 422 (`@` on empty stack → underflow + ok). Test count 430 → 431.
    - **L1 (Low, noted):** Makefile test 406 uses `.S` only rather than AC#9's prescribed ".S + two . calls"; functionally equivalent (signed-hex value ordering already proves low-on-TOS). Accepted; test retained as-is.
    - **L2 (Low, noted):** CCD-3 format differs from Epic 9's `number_prefixes.asm` pattern. Story 10.2's format is internally consistent (6/6) and matches architecture.md:211 example shape. Stories 10.3–10.9 should match 10.2's template.
    - **L3 (Low, accepted):** 2SWAP leaves (x3, x1, x2) in shadow on exit — same disposition as first-pass review.
    - **L4 (Low, cosmetic):** 2SWAP line-106 comment calls caller's HL "junk"; cleanup on next touch.
  - [x] 14.1–14.3 First-pass adversarial self-review completed. Findings:
    - **M1 (Medium, resolved by documentation):** Deviated from story Task 6.3's `check_underflow_3` suggestion for 2DROP; used `check_underflow_2`. Rationale: helper index = number of POPs = ANS DEPTH requirement. DROP's 1-POP / `check_underflow` is the parallel. `_3` would reject legal DEPTH=2. Documented in Task 6 note and inline code comment.
    - **L1 (Low, non-blocking):** 2SWAP leaves (x3, x1, x2) in shadow registers on exit. Shadow is convention-scratch; no word relies on pre-call shadow. Accepted.
    - **L2 (Low, style):** 2@ uses A register as byte scratch while other memory primitives favor HL-only. Correct and efficient. Accepted.
    - **Self-catch:** Test 407 expected output was initially `<2> -2153 -4111`; actual round-trip returns `<2> -4111 -2153` (= original push order BEEF, DEAD). Fixed to match actual + added clarifying comment explaining the push-order ↔ memory-order relation.
    - **Checks that found nothing:** all six §-number citations verified against `docs/ans-forth-core-compliance.md` (DPANS94-authoritative), no byte-order inversion, DE=IP preserved on all six words, all DEFCODEs have CCD-3 and stack-effect comments, Makefile numbering contiguous 397..421, every .fth test scenario has a Makefile runner.
  - [x] 14.4 Second-pass review by a different LLM is still **recommended** per Story 10.1 precedent and project memory `feedback_adversarial_review.md`. Flagged for the Story 10.2 code-review workflow runner.

## Dev Notes

### Story Purpose and Epic-10 Position

Story 10.2 is the **first implementation story in Epic 10** and the first code-writing story for any of Epics 9–13's new files (the `src/` directory gains `double.asm`). It establishes three things for every subsequent Epic-10 story:

1. **E10-D1 byte-order grounding** — once `2@` / `2!` land with the low-on-TOS / high-below convention, every subsequent double-cell word (`D+`, `M*`, `UM/MOD`, pictured output, `>NUMBER` upgrade) reads stack layouts consistently. Get this wrong once and every downstream story silently corrupts.
2. **`src/double.asm` as the Epic-10 arithmetic home** — the file created here is the destination for Stories 10.3–10.6. Its file header, INCLUDE slot in `src/antforth.asm`, and internal convention (CCD-3 comments, stack-effect annotations, BC-TOS discipline) set the template.
3. **`tests/double_tests.fth` as the Epic-10 double-cell test surface** — Stories 10.3–10.6 append to this file; Story 10.7 starts `tests/pictured_tests.fth`; Story 10.9 starts `tests/core_gap_tests.fth`. The house style established here propagates.

### Architectural Decisions That Apply to This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§206-216 CCD-3 (Standards-Citation Discipline):** every one of the six words cites its DPANS94 §-number in a one-line comment above the body. Format is non-negotiable — match `src/stack_ops.asm` / `src/memory.asm`'s existing sites.
- **§218-226 CCD-4 (Per-Epic Benchmark Gate):** gate is at **Story 10.10**, not here. Record ROM delta in Completion Notes as informational data only; do NOT run the full benchmark suite or treat size growth as a blocker.
- **§248-252 E10-D1 (Byte-Order):** low cell on TOS, high cell below. This is the ANS convention; locked by the standard (DPANS94 §6.1.0350 stack diagram); deviation breaks portability of user code. Non-negotiable.
- **§260-264 E10-D3 (Implementation split):** hot primitives in assembly, thin wrappers as compiled Forth. All six Story-10.2 words are stack-/memory-primitive hot paths — all assembly, all in `src/double.asm`.
- **§434-447 Source-file organisation:** `src/double.asm` is the target file for Epic-10 double-cell primitives. The file is new — this story creates it.

### BC-as-TOS Convention (Project Memory: `project_tos_in_register.md`)

Every existing stack/memory primitive treats BC as TOS on entry and exit. When writing these six new words:

- **On entry:** BC = top-most single cell as specified in the word's stack signature.
- **On exit:** BC = the new top-most single cell.
- **DO NOT** load the new TOS from BDOS or memory and leave it in HL or DE "for speed" — that breaks the calling convention and every downstream word will misread the stack.
- **DE = IP** (the inner-interpreter instruction pointer). Any word that needs DE for operand manipulation must either (a) bracket with `EXX` to swap to the shadow set, or (b) `PUSH DE` / `POP DE` around the clobbering section. See `src/stack_ops.asm:111-171` (ROLL) for a worked `EXX`-bracketed example.
- **`NEXT` is the exit primitive** — the macro is defined in `src/macros.asm:26-31`. Every word ends with `NEXT` (no `RET` — Forth threading is not subroutine calls).

### Shadow-Register (EXX) Convention — Epic 7/8 Inheritance

Epic 7/8 established EXX-bracketing for any primitive that needs the full main register set. Applies here mainly to `2SWAP` (4-cell shuffle benefits from the shadow set) and potentially `2OVER`. If used, follow the existing pattern: `EXX` on entry, stage TOS via `PUSH BC` / `POP BC` bracketing the EXX if needed, `EXX` on exit. Reference: project memory `feedback_exx_convention` (if saved) and the Epic 8 retro for the pattern justification. `src/stack_ops.asm:111-171` (ROLL) is a canonical worked example.

If the shuffle fits in BC + HL + a PUSH/POP of DE, EXX adds more cost than it saves — use the simpler path. Benchmark is not gated on this story (CCD-4 is at 10.10), but don't leak EXX pairs for no reason.

### Stack-Underflow Discipline

All existing primitives that consume stack cells call a `check_underflow_N` helper at entry. The helper family in `src/system.asm`:

- `check_underflow` (N=1): for words consuming 1 cell (DROP, @, many arithmetic ops).
- `check_underflow_2` (N=2): for 2-cell consumers (!, SWAP, OVER, +, …).

Story 10.2 likely needs `check_underflow_3` (for `2!` and possibly `2DROP`) and `check_underflow_4` (for `2SWAP`, `2OVER`). Add them in the same file in the same style — DO NOT parameterise or refactor the existing helpers, because Epic 11 will migrate every call site to `THROW -4` (ANS stack-underflow code) wholesale, and any refactor now would be thrown away.

The underflow path pre-Epic-11 emits the stack-underflow diagnostic and falls through to `ABORT`. Post-Epic-11 it'll be `THROW -4`. **Story 10.2 must use the pre-Epic-11 pattern** — no pre-migration.

### Standards Citations — Authoritative §-Number Verification

The epic spec in `epics.md:458-472` cites `§6.1.0290` for `2@`, but Story 10.1's refreshed compliance doc in `docs/ans-forth-core-compliance.md` uses §6.1.0350 (the DPANS94 authoritative §-number). **Story 10.2's implementation must use the DPANS94 §-numbers** — not the epic-spec shorthand. The likely correct citations are:

| Word | DPANS94 § (verify before use) |
|---|---|
| `2!` | §6.1.0310 |
| `2@` | §6.1.0350 |
| `2DROP` | §6.1.0370 |
| `2DUP` | §6.1.0380 |
| `2OVER` | §6.1.0400 |
| `2SWAP` | §6.1.0430 |

Confirm each §-number against DPANS94 §6.1 or forth-standard.org's §6.1 listing before committing the comment. Project memory `feedback_systematic_reference_check.md`: cross-reference the authoritative manual, not memory.

### Source File Organisation

```
src/
├─ double.asm      ← NEW — this story creates it
├─ antforth.asm    ← EDIT — add INCLUDE "double.asm" line
├─ system.asm      ← EDIT IF NEEDED — add check_underflow_3 / _4 helpers
├─ stack_ops.asm   ← unchanged
├─ memory.asm      ← unchanged (2@ / 2! go in double.asm per architecture)
└─ …
```

`architecture.md:441` is explicit that `src/double.asm` is the home for double-cell primitives **including** `2@` / `2!`, even though those are arguably "memory" ops. Respect the architecture — don't scatter `2@` / `2!` into `memory.asm`.

### Test Delivery — REPL-Piped Pattern

Per project memory `feedback_repl_tests_preferred.md`: new tests from Epic 3 onwards are REPL-piped Forth scripts, not assembly test-thread extensions. Story 10.2's tests follow this:

1. `tests/double_tests.fth` — documentation file with one-line Forth test expressions + `\ expect: <fragment>` comments. Style: match `tests/number_prefixes_tests.fth:1-80`.
2. `Makefile` — the authoritative runners. One `@OUTPUT=$$(printf '…' | $(IZCPM) $(TARGET)) && grep -q '…'` entry per test. Style: match `Makefile:3407-3414` (a typical post-Story-9.5 entry).

The two must stay in sync — every `.fth` line with an `\ expect:` comment maps to exactly one `test-repl` entry and vice versa. Doc drift is a finding per AC #8.

### ROM Size Expectation (informational, for CCD-4 reference at 10.10)

Rough estimate for six primitive DEFCODEs, each ~10-20 bytes of body + 6-byte dictionary header + 1-3 byte name: **~150-200 bytes** net contribution. Plus 2 new underflow helpers ~30 bytes each. Plus `tests/double_tests.fth` (not in binary). Total binary delta expected: **~200-300 bytes**. Record measured value in Completion Notes; no gate.

### Epic 10 Dependencies Not Yet Landed

Nothing blocks Story 10.2. All its dependencies are satisfied:

- Epic 1–8 parameter-stack + memory primitives ✓
- Epic 9 numeric prefix recogniser (unrelated — 10.2 doesn't parse numbers)
- Story 10.1 gap survey ✓ (established `src/double.asm` as the target file)

Epic 10 Stories 10.3–10.9 all depend on Story 10.2 for E10-D1 grounding and `src/double.asm` existence. If this story misbehaves, they all inherit the defect.

### Previous-Story Intelligence — Story 10.1 Carry-Forwards

Relevant takeaways from `_bmad-output/implementation-artifacts/10-1-ans-core-compliance-gap-survey-and-implementation-plan.md`:

1. **§6.1 vs §8.6 reconciliation** — Story 10.1 found the epic spec conflates §6.1 Core with §8.6 Double-Number wordset. All six Story-10.2 words are **§6.1 Core** (not §8.6), so this story is on the main Core-compliance critical path. No reclassification concerns.
2. **Line-number drift discipline** — Story 10.1 patched 110 drifted line refs in the compliance doc. Story 10.2 adds new rows; its source-line citations should be checked again at Story 10.10 (Story 10.1 recommendation in Finding #3).
3. **Plain QA prose** (project memory `feedback_plain_qa_language.md`, reinforced by Epic 9 retro Action #5). Completion Notes state numbers, gates, and reasons. No florid framing.
4. **Adversarial review rigour on "small" stories** — Story 10.1 was a pure audit and still surfaced 2 HIGH + 2 MED + 2 LOW findings across two passes. Story 10.2 writes new code paths; expect findings to be denser. Strongly recommend a second-pass review with a different LLM.

### Epic 9 Retro — Action Items Relevant to This Story

From `_bmad-output/implementation-artifacts/epic-9-retro-2026-04-20.md`:

- **Plain QA prose (Action #5):** applies directly. Completion Notes are diagnostic, not celebratory.
- **AC-drafting trace-check (Action #6):** Epic-10 Story 10.8 will rewrite `.` / `U.` / `.R` on the pictured foundation. Story 10.2's tests for `.S` output become the regression anchor those rewrites preserve — make sure the `.S` expected fragments (e.g., `<4> 1 2 1 2 `) exactly match the current `.S` formatting. A silent `.S` format shift in Story 10.8 would break these tests; that's the retro's concern, not this story's problem — but: keep the expected fragments precise so the anchor is usable.

### Project Structure Notes

- **Files touched:** 
  - `src/double.asm` (NEW)
  - `src/antforth.asm` (EDIT — INCLUDE line)
  - `src/system.asm` (EDIT — new `check_underflow_3` / `_4` helpers if needed)
  - `tests/double_tests.fth` (NEW)
  - `Makefile` (EDIT — new `test-repl` entries)
  - `docs/ans-forth-core-compliance.md` (EDIT — flip 6 rows from Gap to Implemented; update summary)
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` (EDIT — status transitions, handled by dev-story)
  - `_bmad-output/implementation-artifacts/10-2-double-cell-stack-foundation.md` (this file — Dev Agent Record + Completion Notes at close)
- **Alignment with unified structure:** all files sit in their established homes per `architecture.md:434-447`. No source-tree structural change; `src/double.asm` is a planned file per architecture, not an ad-hoc addition.
- **Detected conflicts or variances:** none.

### References

- **Authoritative standard:**
  - DPANS94 §6.1 Core — `2!` (§6.1.0310), `2@` (§6.1.0350), `2DROP` (§6.1.0370), `2DUP` (§6.1.0380), `2OVER` (§6.1.0400), `2SWAP` (§6.1.0430) — **verify at implementation time**.
- **Planning artefacts:**
  - `_bmad-output/planning-artifacts/epics.md:450-472` — Story 10.2 epic spec (this story)
  - `_bmad-output/planning-artifacts/epics.md:426-472` — full Epic 10 context (10.2 is first implementation story)
  - `_bmad-output/planning-artifacts/architecture.md:246-264` — E10-D1 / E10-D2 / E10-D3 decisions
  - `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 Standards-Citation Discipline
  - `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 Per-Epic Benchmark Gate (at Story 10.10, not here)
  - `_bmad-output/planning-artifacts/architecture.md:434-447` — Source-file organisation table
  - `_bmad-output/planning-artifacts/prd.md:380-392` — FR10, FR11 (double-cell stack words), FR15 (100% Core)
  - `_bmad-output/planning-artifacts/prd.md:460-479` — NFR9 (regression), NFR10 (Core compliance), NFR16 (test-first), NFR17 (standards citations)
- **Precedent stories:**
  - `_bmad-output/implementation-artifacts/10-1-ans-core-compliance-gap-survey-and-implementation-plan.md` — immediate predecessor; gap survey; story-pointer assignment table
  - `_bmad-output/implementation-artifacts/9-6-epic-9-benchmark-standards-citation-audit-and-regression-gate-ccd-4.md` — CCD-4 gate pattern (informational precedent for 10.10, not 10.2)
  - `_bmad-output/implementation-artifacts/epic-9-retro-2026-04-20.md` — plain QA prose, AC trace-check
- **Source-tree anchors for pattern matching:**
  - `src/stack_ops.asm:13-70` — existing stack primitives (DEFCODE pattern, check_underflow_N guard pattern, BC-as-TOS)
  - `src/memory.asm:43-67` — existing memory primitives (`@` / `!`, HL addressing, POP BC for new TOS)
  - `src/stack_ops.asm:111-171` — ROLL (EXX bracketing worked example)
  - `src/system.asm:278-320` — `check_underflow` / `check_underflow_2` helpers (style template for `_3` / `_4`)
  - `src/macros.asm:26-94` — NEXT / DEFCODE / DEFWORD macro definitions
- **Test-tree anchors:**
  - `tests/number_prefixes_tests.fth:1-80` — REPL-piped test file style template
  - `Makefile:3407-3414` — canonical single REPL test entry pattern
  - `Makefile:3475-3506` — Story 9.5 block header and mixed-context test pattern
  - `Makefile:52-71` — `make test` (assembly thread) structure
- **Project memories applicable to this story:**
  - `feedback_systematic_reference_check.md` — cross-reference DPANS94, not memory (AC #1, #7)
  - `feedback_standards_compliance.md` — investigate the standard; never rationalise (AC #10)
  - `feedback_adversarial_review.md` — reviews MUST find things (Task 14)
  - `feedback_plain_qa_language.md` — diagnostic Completion Notes (Task 12.3)
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth scripts (AC #8, Task 10)
  - `feedback_design_upfront.md` — get the Epic-10 scaffold right in 10.2 so 10.3–10.9 don't rediscover
  - `feedback_follow_process.md` — execute the workflow without asking for permission for obvious next steps
  - `feedback_defword_cf_label.md` — N/A (this story defines DEFCODEs, not DEFWORDs)
  - `project_tos_in_register.md` — BC-as-TOS discipline; DE=IP; DEPTH convention (AC #4, Dev Notes)
  - `feedback_assembler_operand_order.md` — Zilog dst-src order in inline assembly (relevant only if Tasks 5–8 invoke the assembler at all; they don't — these are raw sjasmplus source, not CODE-word bodies)

### Project Structure Notes

- Alignment with unified project structure: all new files sit in planned homes per `architecture.md:434-447`. `src/double.asm` matches the architecture-designated source-file for Epic 10 double-cell primitives. `tests/double_tests.fth` matches the architecture- and epic-designated test file for Epic-10 double-cell tests.
- No detected conflicts or variances with the unified structure.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

- Initial test-repl run: test 407 FAIL. Actual output `<2> -4111 -2153 ` vs expected `<2> -2153 -4111 `. Root cause: expected value was written assuming 2!-then-2@ reverses the pair, but the correct round-trip returns the pair in original push order. Fix: corrected expected value + inline rationale comment in both `Makefile` and `tests/double_tests.fth`. Re-run: 430/430 PASS.

### Completion Notes List

1. **Scope delivered:** 6 DEFCODE primitives (`2@`, `2!`, `2DUP`, `2DROP`, `2SWAP`, `2OVER`) in a new `src/double.asm`; 2 new underflow helpers (`check_underflow_3`, `check_underflow_4`) in `src/system.asm`; `INCLUDE` wiring in `src/antforth.asm`; `tests/double_tests.fth` with 25 scenarios; 25 new REPL test-runner entries in `Makefile` (tests 397..421); compliance doc updated (Stack ops and Memory now 100% §6.1 Core).
2. **Regression result:** `make test` green; `make test-repl` 430 PASS / 0 FAIL (baseline 405 + 25 new, exact match; no silent drift).
3. **ROM size delta:** 14787 → 14984 bytes = **+197 bytes** (informational; CCD-4 gate at Story 10.10 per `architecture.md:218-226`).
4. **Byte-order convention (E10-D1):** verified end-to-end via symmetric round-trip tests (BEEF/DEAD) and boundary-value tests (0/0, FFFF/FFFF, 8000/8000). Low cell on TOS, high cell below; low cell at `a-addr`, high cell at `a-addr+2`. Matches DPANS94 §6.1.0350 stack diagram exactly.
5. **Underflow-guard mapping (documented for Epic 10 followers):** `check_underflow_N` guards ANS `DEPTH >= N` = N cells available on SP = N POPs possible. 2@ uses `check_underflow` (N=1), 2DUP/2DROP use `check_underflow_2` (N=2), 2! uses `check_underflow_3` (N=3), 2SWAP/2OVER use `check_underflow_4` (N=4). Deviated from Task 6.3's suggestion of `_3` for 2DROP — rationale: 2DROP does 2 POPs to satisfy ANS DEPTH≥2, matching DROP's 1-POP ↔ `check_underflow` pattern.
6. **2SWAP implementation note:** uses 4 EXX toggles to shuffle 4 cells between main/shadow without DE=IP clobbering. Leaves (x3, x1, x2) in shadow on exit; no downstream word depends on pre-call shadow state. ~16 bytes of code body (plus CALL + NEXT).
7. **2OVER implementation note:** avoids EXX entirely via `LD HL, 6 / ADD HL, SP` indexed loads after pushing x4. Cleaner than 2SWAP since no rearrangement is needed — just copies two cells to the top.
8. **Code-review follow-up:** a second-pass review by a different LLM is recommended before marking the story Done (per Story 10.1 precedent and memory `feedback_adversarial_review.md`).
9. **Forward-looking handoff:** Stories 10.3–10.9 now have `src/double.asm` as the home for further double-cell words, `tests/double_tests.fth` as the home for double-cell test scenarios, and `check_underflow_3`/`_4` helpers available. The E10-D1 convention is anchored by tests 406–410.

### File List

- `src/double.asm` (NEW) — 6 DEFCODEs
- `src/antforth.asm` — added `INCLUDE "double.asm"`
- `src/system.asm` — added `check_underflow_3` and `check_underflow_4`
- `src/memory.asm` — code-review M2 fix: added `CALL check_underflow` to `@`, CCD-3 §6.1.0650 comment
- `tests/double_tests.fth` (NEW) — 25 REPL test scenarios
- `Makefile` — 25 new `test-repl` entries (397..421), plus test 422 for `@` underflow guard (M2 fix)
- `docs/ans-forth-core-compliance.md` — 6 row flips, Summary patch, Observations update
- `_bmad-output/planning-artifacts/architecture.md` — code-review M1 fix: §6.1.0290 → §6.1.0350 citation for 2@
- `_bmad-output/planning-artifacts/epics.md` — code-review M1 fix: §6.1.0290 → §6.1.0350 (2@); §6.1.0290 → §6.1.2170 (S>D reference in 10.3 AC)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 10-2 status transitions
- `_bmad-output/implementation-artifacts/10-2-double-cell-stack-foundation.md` — this file

### Change Log

- 2026-04-20: Story 10.2 implementation complete. All 14 tasks executed. 25 new REPL tests added (397..421). ROM +197 bytes. Stack ops and Memory §6.1 Core both at 100% coverage post-landing. Status: in-progress → review.
- 2026-04-21: Second-pass code review (code-review workflow) fixed M1 (stale §-number citations in architecture.md / epics.md: §6.1.0290 → §6.1.0350 for 2@; §6.1.2170 for S>D reference) and M2 (added `check_underflow` to `@` + CCD-3 §6.1.0650 citation; new REPL test 422). `make test` green; `make test-repl` 431 PASS / 0 FAIL. ROM 14984 → 14987 = +3 bytes. Status: review → done.
