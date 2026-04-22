# Story 10.6: Double/mixed-precision division (`SM/REM`, `FM/MOD`, `UM/MOD`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the ANS Core double/mixed-precision division primitives — `UM/MOD` (unsigned double ÷ unsigned single → unsigned remainder + unsigned quotient), `SM/REM` (signed symmetric — quotient truncates toward zero, remainder sign matches dividend), and `FM/MOD` (signed floored — quotient rounds toward negative infinity, remainder sign matches divisor) —
so that after Story 10.5 landed the double-multiplication family, I can compute 32/16 → 16-remainder + 16-quotient math in all three standard sign regimes using the ANS vocabulary; Story 10.9's `*/` and `*/MOD` can consume `SM/REM` as their mixed-precision divisor-foundation; and the §6.1 Core "Double / mixed division" sub-family (the final §6.1 arithmetic gap before pictured output) closes.

## Acceptance Criteria

> **AC errata (post-review, 2026-04-22 code-review pass):** two arithmetic slips in the AC text below are corrected in-place:
> - AC #1's `-2 -1 -1 UM/MOD` now reads `( -2 -1 )` (was `( -1 -1 )`). The quotient is `$FFFF` = `-1` and the remainder is `$FFFE` = `-2`; printed order is `rem quot`.
> - AC #2's `0 -10 3 SM/REM` boundary case now reads `-1 -10 3 SM/REM`. Stacking `0 -10` places `0` on the high cell of the double, yielding unsigned 65526, not signed -10; `-1 -10` is the correct two-cell encoding of signed -10.
> - AC #3's `0 -10 3 FM/MOD` boundary case now reads `-1 -10 3 FM/MOD` for the same reason.
> - AC #10's REPL-test expectations mirror these corrections.
> Corrections were first flagged by the dev agent in Completion Notes during implementation; tests (Makefile 532, 534, 541) use the corrected inputs.

1. **Given** `UM/MOD ( ud u1 -- urem uquot )` per DPANS94 §6.1.2370 (**verify §-number at implementation time** per project memory `feedback_systematic_reference_check.md`) and the E10-D1 byte-order convention (low cell on TOS, high cell below — `architecture.md:248-252`), **When** `UM/MOD` executes with the double dividend `ud` occupying the two cells under TOS (`ud-high` deepest, `ud-low` second-on-stack) and the single divisor `u1` = BC = TOS, **Then** the unsigned 32-bit ÷ 16-bit division result is left as `( urem uquot )` with `urem` (16-bit unsigned remainder) second-on-stack and `uquot` (16-bit unsigned quotient) on TOS (BC). Boundary values: `0 0 1 UM/MOD` → `( 0 0 )` (zero dividend); `0 1 1 UM/MOD` → `( 0 1 )` (unity/unity — one remainder zero, quotient 1); `0 10 3 UM/MOD` → `( 1 3 )` (10 ÷ 3 = 3 rem 1 — single-cell-range dividend); `0 -1 1 UM/MOD` → `( 0 -1 )` (= 65535 ÷ 1 = 65535 rem 0; `-1` is `$FFFF` unsigned); `1 0 2 UM/MOD` → `( 0 -32768 )` (= 65536 ÷ 2 = 32768 rem 0; `$8000` prints as `-32768` signed); `-1 -1 -1 UM/MOD` → `( 0 -1 )` (= `$FFFFFFFF ÷ $FFFF = $10001 quotient? NO — wait, $FFFFFFFF ÷ $FFFF = $10001 which overflows 16 bits`; see AC #7 overflow rule — this input is specifically NOT a valid UM/MOD input because the quotient would not fit in a single cell); `-1 0 -1 UM/MOD` → `( -1 0 )` (= `$FFFF0000 ÷ $FFFF = $10000` — also overflows — same exclusion). The **valid** overflow-boundary cases are: `0 -1 -1 UM/MOD` → `( 0 1 )` (= `$0000FFFF ÷ $FFFF = 1 rem 0`) and `-2 -1 -1 UM/MOD` → `( -2 -1 )` (= `$FFFE_FFFF ÷ $FFFF = $FFFF rem $FFFE`; printed `rem quot` = `-2 -1` — max-quotient case just-barely-fits). Pre-Epic-11 divide-by-zero behaviour matches today's single-cell `/` `MOD` `/MOD` baseline — **no new divide-by-zero check is introduced** (AC #8 below; Story 11.4 migrates all arithmetic divide-by-zero sites to `THROW -10`).

2. **Given** `SM/REM ( d n1 -- nrem nquot )` per DPANS94 §6.1.2214 (symmetric — quotient truncates toward zero; remainder's sign matches dividend), **When** executed on a signed double dividend and signed single divisor, **Then** the signed 32/16 → 16+16 division result is left as `( nrem nquot )` with `nrem` (signed remainder) second-on-stack and `nquot` (signed quotient) on TOS. The symmetric sign rule: for `d = q·n₁ + r`, `sign(r) == sign(d)` (i.e., remainder matches dividend sign) and `|q| == trunc(|d|/|n₁|)`. Boundary values — all four sign quadrants plus the boundary cases:
    - `0 10 3 SM/REM` → `( 1 3 )` (`+10 ÷ +3 = +3 rem +1`)
    - `-1 -10 3 SM/REM` → `( -1 -3 )` (`-10 ÷ +3 = -3 rem -1` — remainder matches dividend sign; double form `$FFFFFFF6 = -10 signed`)
    - `0 10 -3 SM/REM` → `( 1 -3 )` (`+10 ÷ -3 = -3 rem +1` — remainder matches dividend sign)
    - `-1 -10 -3 SM/REM` → `( -1 3 )` (`-10 ÷ -3 = +3 rem -1` — double dividend `$FFFFFFF6 = -10` signed; remainder matches dividend)
    - `0 0 7 SM/REM` → `( 0 0 )` (zero dividend)
    - `-1 -5 10 SM/REM` → `( -5 0 )` (`-5 ÷ +10 = 0 rem -5` — magnitude smaller than divisor; symmetric convention preserves sign on the remainder via the zero quotient)
    - `0 -32768 1 SM/REM` → wait — this dividend is the single-cell `-32768` sign-extended? Careful: `0 -32768 1 SM/REM` parses as `d-high = 0, d-low = -32768 = $8000, n1 = 1` → unsigned dividend = `$00008000 = 32768` → quotient 32768, which overflows signed 16-bit — exclude this case (see AC #7 overflow note). Use `-1 -32768 1 SM/REM` instead: `d = $FFFF8000 = -32768 signed` → `-32768 ÷ 1 = -32768 rem 0` → `( 0 -32768 )` — verifies that `$8000` as a quotient is representable (`$8000` is a valid signed 16-bit value, equal to `-32768`).

3. **Given** `FM/MOD ( d n1 -- nrem nquot )` per DPANS94 §6.1.1561 (floored — quotient rounds toward negative infinity; remainder's sign matches divisor), **When** executed on a signed double dividend and signed single divisor, **Then** the signed 32/16 → 16+16 division result is left as `( nrem nquot )` with `nrem` second-on-stack and `nquot` on TOS. The floored sign rule: for `d = q·n₁ + r`, `sign(r) == sign(n₁)` (remainder matches divisor sign) and `q = floor(d/n₁)`. **The symmetric-vs-floored discrimination cases are the mixed-sign ones where a non-zero remainder exists** — for those, `FM/MOD`'s quotient is 1 less than `SM/REM`'s quotient, and the remainder shifts by `n₁` to compensate. Canonical ANS derivation: `FM/MOD = SM/REM, then if rem ≠ 0 and sign(rem) ≠ sign(n₁), quot := quot - 1; rem := rem + n₁`. Boundary values:
    - `0 10 3 FM/MOD` → `( 1 3 )` (same-sign — identical to SM/REM)
    - `-1 -10 3 FM/MOD` → `( 2 -4 )` (`-10 ÷ 3` floored = `-4 rem 2`; remainder matches divisor `+`; vs SM/REM's `( -1 -3 )`; double form `$FFFFFFF6 = -10 signed`) — **canonical floored-vs-symmetric witness**
    - `0 10 -3 FM/MOD` → `( -2 -4 )` (`+10 ÷ -3` floored = `-4 rem -2`; remainder matches divisor `-`; vs SM/REM's `( 1 -3 )`) — **second witness**
    - `-1 -10 -3 FM/MOD` → `( -1 3 )` (same-sign negative — identical to SM/REM)
    - `0 0 7 FM/MOD` → `( 0 0 )` (zero dividend — both conventions agree)
    - `0 9 3 FM/MOD` → `( 0 3 )` (exact division — both conventions agree; rem = 0 triggers no correction)
    - `-1 -9 3 FM/MOD` → `( 0 -3 )` (exact negative — both conventions agree)

4. **Given** the BC-as-TOS convention (project memory `project_tos_in_register.md`) and the Story 10.4 / 10.5 IP-stash pattern (shared scratch cell `double_ip_stash` at `src/double.asm:540`; `LD (double_ip_stash), DE` / `LD DE, (double_ip_stash)` brackets the register-heavy section), **When** each of `UM/MOD`, `SM/REM`, `FM/MOD` is implemented, **Then** on entry BC holds the single divisor (`u1` or `n1`) and on exit BC holds the quotient (low cell of the two-result pair, which is TOS per ANS signature `( d n1 -- rem quot )` — `quot` is rightmost and thus TOS). `DE = IP` is preserved across every word — either left untouched or bracketed by memory-stash via the existing `double_ip_stash` cell (reuse — do not add a new scratch cell; the cell is never held across `NEXT` and is never re-entered). `SM/REM` and `FM/MOD` as DEFWORD threads inherit the DE-preservation discipline automatically (each threaded word saves / restores its own DE); only the DEFCODE `UM/MOD` needs explicit memory-stash.

5. **Given** stack-underflow discipline (Story 10.3 code-review-established rule that `check_underflow_N` counts total user items **including BC**; `src/system.asm:~278-362`), **When** any of the three Story-10.6 division primitives is invoked with insufficient depth, **Then** it calls the matching `check_underflow_N` helper:

    | Word | Cells consumed | Helper |
    |---|---|---|
    | `UM/MOD` | 3 (`ud-hi` + `ud-lo` + `u1`) | `check_underflow_3` |
    | `SM/REM` | 3 (`d-hi` + `d-lo` + `n1`) | `check_underflow_3` |
    | `FM/MOD` | 3 (`d-hi` + `d-lo` + `n1`) | `check_underflow_3` |

    No new helpers are introduced — `check_underflow_3` already exists and is used by `2!` and `M+`. Pre-Epic-11 behaviour (ABORT + stack-underflow diagnostic + REPL recovery) is preserved bit-identically. Epic 11 (Story 11.4) will migrate to `THROW -4` wholesale — **do NOT pre-migrate in this story**. For the DEFWORD options (`SM/REM` / `FM/MOD` via threaded body), the guard can be inherited from the first body word if and only if that word's own underflow-N meets the 3-cell requirement — e.g., `2DUP` needs 2 (insufficient), but `>R` needs 1 (insufficient), so **neither** inherits correctly. **Prefer an explicit front-loaded `check_underflow_3` via a cheap depth-peek construct** (e.g., compile `(?STACK-UNDERFLOW-3)` as a leading opcode, or — simpler — make `SM/REM` and `FM/MOD` start with a `DROP` / `DUP` pair whose internal underflow guard is `_3`; dev to choose). Cleanest: land a small DEFCODE guard word `(?3)` that just calls `check_underflow_3` and NEXTs, then thread it as the first opcode in the DEFWORDs. Alternative: write `SM/REM` as DEFCODE too (it would be ~40 bytes — not large).

6. **Given** architecture decision E10-D3 (assembly for hot primitives; colon-compiled Forth permitted for thin wrappers; `architecture.md:260-264`) and the source-file organisation table (`architecture.md:438-446`), **When** the three words are implemented, **Then** they **all land in `src/double.asm`**, appended after `w_D_STAR` (currently the file's last DEFWORD at `src/double.asm:510-534`) and **before** the `double_ip_stash` cell (which must remain the file's final item so its address is stable — same discipline as Stories 10.2 / 10.3 / 10.4 / 10.5). Suggested source ordering: `UM/MOD` → `SM/REM` → `FM/MOD` (builds complexity: unsigned inner primitive first; signed symmetric composes `UM/MOD` + sign-fixup; signed floored composes `SM/REM` + floor-correction). Recommended implementation split per E10-D3:
    - `UM/MOD` — **DEFCODE** (hot inner primitive; shift-and-subtract is tight enough that assembly beats threaded overhead by ≥3×). Approach: mirror `udivmod` at `src/arithmetic.asm:114-136` but widen the input-dividend side to 32 bits (the existing `udivmod` takes a 16-bit dividend in HL; we need a 32-bit dividend, with the high 16 pre-loaded into the remainder register at loop start). See Task 2 for register-assignment detail.
    - `SM/REM` — **DEFWORD**. Canonical ANS Forth body: track sign of dividend `d`; track sign of divisor `n1`; compute `DABS` of `d`; compute `ABS` of `n1`; call `UM/MOD`; fixup-negate quotient if signs differed; fixup-negate remainder if dividend was negative. (Reference implementation: DPANS94 §A.6.1.2214; GForth `sm/rem` in `prim`.)
    - `FM/MOD` — **DEFWORD**. Canonical ANS Forth body: call `SM/REM`; if remainder ≠ 0 and `sign(remainder) XOR sign(divisor)` < 0, decrement quotient and add divisor to remainder. (Reference implementation: DPANS94 §A.6.1.1561; well-documented idiom.)
    - The 10.5 precedent (DEFCODE `UM*`, DEFWORD `M*`, DEFWORD `D*`) explicitly endorses this pattern — hot primitive in assembly, sign/floor wrappers as threaded Forth. **Do not re-invent the inner division loop for `SM/REM` / `FM/MOD`** — compose via `UM/MOD`.

7. **Given** CCD-3 Standards-Citation Discipline (`architecture.md:206-216`, NFR17 at `prd.md:478`) and the format template established by Stories 10.2 / 10.3 / 10.4 / 10.5 (every DEFCODE and DEFWORD in `src/double.asm` carries a `; ANS Forth 1994 §<section>   <word>   — <short semantic note>` header comment + a stack-effect comment on the header line), **When** each of the three words is implemented, **Then** its implementation carries (a) the one-line §-citation comment in the established template format and (b) a stack-effect comment on the appropriate line in the existing style. **§-numbers are verified against DPANS94 / forth-standard.org at implementation time** — do NOT enumerate from memory (per `feedback_systematic_reference_check.md`; reinforced by Story 10.2's M1 finding, Story 10.3's self-review gap, Story 10.4's code-review pass, Story 10.5's full cross-check against `docs/ans-forth-core-compliance.md`). Expected numbers to verify: `UM/MOD §6.1.2370`, `SM/REM §6.1.2214`, `FM/MOD §6.1.1561`. Additionally, each word's header comment should note the **quotient-overflow caveat**: per DPANS94 §3.2.2.1 and §6.1.2370, the behaviour of `UM/MOD` / `SM/REM` / `FM/MOD` when the quotient does not fit in a single cell is implementation-defined (the spec says "If the quotient lies outside the range of a single-cell signed integer, the result is implementation-defined"). antforth's convention for Story 10.6: silently truncate to low 16 bits (matches the single-cell `/` convention). Document this in the header comment (one line) and reference the §3.2.2.1 range rule.

8. **Given** the Epic-10 spec's AC #4 for Story 10.6 (`epics.md:566-568`) which reads "division by zero ... behaviour matches the Epic-1–8 baseline (ABORT pre-Epic-11; Epic 11 will migrate this path to `THROW -10` per ANS §9.3.5)", **When** the dev agent investigates the actual Epic-1–8 baseline for the single-cell `/` / `MOD` / `/MOD` primitives (`src/arithmetic.asm:219-266`), **Then** the dev agent **verifies what the baseline actually does today** (the `udivmod` comment at `arithmetic.asm:115` reads "Precondition: BC != 0 (division by zero produces undefined result)", suggesting no ABORT — but this must be empirically confirmed, not inferred). Whatever the baseline actually is — ABORT, undefined-but-non-fatal, REPL-survivable garbage — the three new Story-10.6 primitives reproduce it bit-identically. **Do NOT introduce a new divide-by-zero check if the existing single-cell division primitives do not have one.** **Do NOT pre-migrate to `THROW -10`** — Epic 11 Story 11.4 (`epics.md:793-795`) is the authoritative migration story; pre-migrating here would violate Epic 10's scope envelope. Record the empirical baseline behaviour in the story's Completion Notes so Epic 11 has a documented "migrate from X to `THROW -10`" starting point. If the empirical baseline disagrees with the epic spec's ABORT framing, flag the discrepancy (per project memory `feedback_standards_compliance.md` — investigate rather than defend).

9. **Given** the REPL-test-preferred discipline (project memory `feedback_repl_tests_preferred.md`, NFR16 at `prd.md:477`) and the Story-10.2 / 10.3 / 10.4 / 10.5 house style (`tests/double_tests.fth` extended per-story; Makefile `test-repl` entries numbered contiguously), **When** tests are written, **Then** (a) new scenarios are **appended** to `tests/double_tests.fth` under a new section header `\ === Story 10.6 double/mixed-precision division (UM/MOD, SM/REM, FM/MOD) ===`, with per-word sub-headers matching the 10.5 style (one-line Forth expression + `\ expect: <fragment>` comment; use `.S 2DROP` to surface a stable `<2> rem quot` fragment for multi-cell outputs); and (b) the corresponding `test-repl` entries are added to `Makefile` as the authoritative runners, using the established `@OUTPUT=$$(printf … | $(IZCPM) $(TARGET)) && grep -q` pattern — continuing the numbering from the final REPL test currently in `Makefile` (**Story 10.5 ended at 525**; new Story-10.6 block starts at **526**).

10. **Given** coverage must exhaust ACs #1–#3 (plus underflow AC #5 and the symmetric-vs-floored discrimination case called out in `epics.md:572`), **When** `make test-repl` is run, **Then** the new test block includes **at minimum** (numbering suggested; final count is dev's choice):

    **`UM/MOD` (AC #1) — 6–8 tests:**
    - `0 0 1 UM/MOD .S 2DROP` → `<2> 0 0` (zero dividend)
    - `0 1 1 UM/MOD .S 2DROP` → `<2> 0 1` (unit / unit → quot 1, rem 0)
    - `0 10 3 UM/MOD .S 2DROP` → `<2> 1 3` (single-range 10 ÷ 3 = 3 rem 1)
    - `0 -1 1 UM/MOD .S 2DROP` → `<2> 0 -1` (`$FFFF ÷ 1 = $FFFF rem 0`; print `-1`)
    - `1 0 2 UM/MOD .S 2DROP` → `<2> 0 -32768` (`$00010000 ÷ 2 = $8000 rem 0`; `$8000` prints `-32768`)
    - `0 -1 -1 UM/MOD .S 2DROP` → `<2> 0 1` (`$0000FFFF ÷ $FFFF = 1 rem 0`)
    - `-2 -1 -1 UM/MOD .S 2DROP` → `<2> -2 -1` (`$FFFE_FFFF ÷ $FFFF = $FFFF rem $FFFE`; printed `rem quot` = `-2 -1` — max-quot just-fits)
    - *(optional — to exercise the 32-bit-dividend carry path)* `-1 -2 -1 UM/MOD .S 2DROP` → `<2> -2 0` (verify the shift picks up the correct high-cell bits during the 16-iteration inner loop — compute by hand first)

    **`SM/REM` (AC #2) — 7–8 tests (sign cross-product):**
    - `0 10 3 SM/REM .S 2DROP` → `<2> 1 3` (+ ÷ + = + rem +)
    - `-1 -10 3 SM/REM .S 2DROP` → `<2> -1 -3` (− ÷ + = − rem −; remainder-matches-dividend; double form `$FFFFFFF6 = -10 signed`)
    - `0 10 -3 SM/REM .S 2DROP` → `<2> 1 -3` (+ ÷ − = − rem +; remainder-matches-dividend)
    - `-1 -10 -3 SM/REM .S 2DROP` → `<2> -1 3` (− ÷ − = + rem −; double dividend form `$FFFFFFF6 = -10 signed`)
    - `0 0 7 SM/REM .S 2DROP` → `<2> 0 0` (zero dividend)
    - `-1 -5 10 SM/REM .S 2DROP` → `<2> -5 0` (magnitude < divisor, quot=0 rem=-5; double form of signed `-5`)
    - `-1 -32768 1 SM/REM .S 2DROP` → `<2> 0 -32768` (min-int quotient representable in signed 16 — verifies `$8000` is a valid output; double dividend `$FFFF8000 = -32768 signed`)
    - *(optional)* `0 15 4 SM/REM .S 2DROP` → `<2> 3 3` (positive-positive non-zero remainder — rounds toward zero)

    **`FM/MOD` (AC #3) — 7–8 tests, with canonical symmetric-vs-floored discrimination:**
    - `0 10 3 FM/MOD .S 2DROP` → `<2> 1 3` (same-sign — identical to SM/REM)
    - `-1 -10 3 FM/MOD .S 2DROP` → `<2> 2 -4` (− ÷ + — **floored vs symmetric witness**: SM/REM gives `( -1 -3 )`, FM/MOD gives `( 2 -4 )`; double form `$FFFFFFF6 = -10 signed`)
    - `0 10 -3 FM/MOD .S 2DROP` → `<2> -2 -4` (+ ÷ − — **second witness**: SM/REM gives `( 1 -3 )`, FM/MOD gives `( -2 -4 )`)
    - `-1 -10 -3 FM/MOD .S 2DROP` → `<2> -1 3` (same-sign negative — identical to SM/REM)
    - `0 0 7 FM/MOD .S 2DROP` → `<2> 0 0` (zero dividend)
    - `0 9 3 FM/MOD .S 2DROP` → `<2> 0 3` (exact division — no correction applied — identical to SM/REM)
    - `-1 -9 3 FM/MOD .S 2DROP` → `<2> 0 -3` (exact negative — no correction — identical to SM/REM)
    - *(optional — tight floor case)* `-1 -1 5 FM/MOD .S 2DROP` → `<2> 4 -1` (`-1 ÷ 5` floored = `-1 rem 4`; double dividend `$FFFFFFFF = -1 signed`)

    **Underflow recovery (AC #5) — one test per word at its minimum-insufficient depth:**
    - `1 2 UM/MOD` → `? Stack underflow` + `ok` (DEPTH=2, UM/MOD needs 3)
    - `1 2 SM/REM` → `? Stack underflow` + `ok` (DEPTH=2, SM/REM needs 3)
    - `1 2 FM/MOD` → `? Stack underflow` + `ok` (DEPTH=2, FM/MOD needs 3)

    Total estimated test count: **23–27** (6–8 UM/MOD + 7–8 SM/REM + 7–8 FM/MOD + 3 underflow). Block range **526..<end>** (adjust to actual final count).

11. **Given** NFR9 (zero regressions, `prd.md:464`) and FR46 (all Epic 1–8 REPL tests continue to pass, `prd.md:435`), **When** the full test suite (`make test` + `make test-repl`) is run after this story's changes, **Then** every pre-existing test still passes, the new Story-10.6 tests all pass, and the final REPL test count increases by exactly the number of new entries added — no hidden regressions, no baseline drift. Post-Story-10.5 baseline is **525 PASS**; the new count is `525 + <new entries>` with 0 FAIL. No word modified outside `src/double.asm` means the regression surface is narrow — spot-check adjacent words for byte-for-byte output stability: single-cell `/`, `MOD`, `/MOD` (`src/arithmetic.asm:219-266`) and all Stories-10.2-through-10.5 double-cell primitives (`2@`, `2!`, `2DUP`, `2DROP`, `2SWAP`, `2OVER`, `S>D`, `D>S`, `D+`, `D-`, `M+`, `DNEGATE`, `DABS`, `D=`, `D<`, `DMAX`, `DMIN`, `UM*`, `M*`, `D*`). Canonical regression signal: `make test-repl` reports exactly `525 + N` PASS, 0 FAIL.

12. **Given** NFR10 (100% §6.1 Core compliance target, `prd.md:461-476`) and the pre-Story-10.6 state documented in `docs/ans-forth-core-compliance.md:11-18` (**120 / 133 implemented = 90.2%**), **When** this story completes, **Then** the compliance doc is updated in the following places (each edit mechanical — all three words are §6.1 Core, no §8.6 bonus):
    - **§6.1 "Arithmetic" table** at `ans-forth-core-compliance.md:83-103`: the two rows for `FM/MOD` and `SM/REM` flip from `**Gap → Story 10.6**` to `Implemented (`double.asm:<line>`)`.
    - **§6.1 "Double-Cell Division" table** at `ans-forth-core-compliance.md:114-120`: the row for `UM/MOD` flips from `**Gap → Story 10.6**` to `Implemented (`double.asm:<line>`)`; heading count updates from "0 implemented, 1 missing" to "1 implemented, 0 missing — 100% complete" (match the 10.5 sub-section-heading style at line 107).
    - **§6.1 Summary table** at `ans-forth-core-compliance.md:11-18`:
        - "Fully implemented" 120 → 123
        - "Missing" 13 → 10
        - Coverage "120 / 133" → "123 / 133"; percentage 90.2% → **92.5%** (123 / 133)
    - **Gap Classification table** at `ans-forth-core-compliance.md:23-28`: decrement "(b) Oversight — missing subsystem" by 3 (11 → 8). Sub-category labels at line 304 update from "Double-cell operations — 5 §6.1 words remaining" to "Double-cell operations — 2 §6.1 words remaining" (only `*/` and `*/MOD` remain, both routed to 10.9). Line 314's "Double / mixed division" sub-table row flips to `Story 10.6 ✓ Implemented`.
    - **Epic-10 closure plan row** for 10.6 at `ans-forth-core-compliance.md:44`: from `| 10.6 | Double / mixed division | 3 (`FM/MOD` `SM/REM` `UM/MOD`) | |` to `| 10.6 | Double / mixed division | 3 ✓ (`FM/MOD` `SM/REM` `UM/MOD`) | Complete |` (or equivalent `✓` marker matching Story 10.4 / 10.5 rows).
    - **"Arithmetic" sub-section heading count** at line 81: "19 §6.1 Core words — 14 implemented, 5 missing" → "19 §6.1 Core words — 16 implemented, 3 missing" (`*/` `*/MOD` remaining in Arithmetic sub-section; `UM/MOD` is in the separate Double-Cell-Division sub-section and does not count here).
    - **"big gaps" observation paragraph** at `ans-forth-core-compliance.md:407`: the "5 §6.1 words remaining" count drops to 2; the bullet can note that 10.6 is done and the remaining gap is `*/` + `*/MOD` via Story 10.9.
    - Do NOT touch §6.2 or §8.6 tables — all three words are §6.1 Core; Story 10.6 makes no §8.6 contributions (unlike 10.4 / 10.5 which added `DNEGATE` / `D*` etc. as §8.6 bonus). **This keeps Story 10.6's compliance-doc delta the cleanest of any Epic-10 story so far** — only §6.1 numbers move.

13. **Given** CCD-4 (Per-Epic Benchmark Gate, `architecture.md:218-226`) sets the benchmark / size-delta gate at **Story 10.10**, not here, **When** this story completes, **Then** the ROM size delta is recorded in the Completion Notes (informational — no gate). Rough estimate: `UM/MOD` ~45-55 bytes (16-iteration shift-subtract loop with 32-bit dividend; slightly longer than `UM*` at ~37 bytes because the shift direction reverses and the subtract-test adds a conditional SET-bit step) + `SM/REM` DEFWORD ~20 cells = 40 bytes body + ~10 header = ~50 bytes + `FM/MOD` DEFWORD ~14 cells = ~28 bytes body + ~10 header = ~38 bytes = **~130-150 bytes** net. Acceptable margin: ±50%. Story 10.10 measures formally. Pre-edit baseline: `build/antforth.com` = **15606 bytes** (post-Story-10.5). Record pre/post sizes in the Dev Agent Record.

## Tasks / Subtasks

- [x] **Task 1 — Verify §-numbers against DPANS94 + scope sanity** (AC: #1–#3, #7, #12)
  - [x] 1.1 Verify `UM/MOD §6.1.2370`, `SM/REM §6.1.2214`, `FM/MOD §6.1.1561` by cross-reference to `docs/ans-forth-core-compliance.md:101,102,120` and forth-standard.org. **Do not enumerate from memory.**
  - [x] 1.2 Confirm all three words are §6.1 Core (count toward FR15 / NFR10); none are §8.6 bonus. The compliance doc §6.1 Summary increment is **+3**, §8.6 unaffected.
  - [x] 1.3 Confirm CCD-3 template matches Stories 10.2 / 10.3 / 10.4 / 10.5 house style (see `src/double.asm:17-22, 44-47, 67-72, 84-89, 99-104, 124-129, 149-153, 167-174, 183-189, 211-217, 237-240, 263-268, 287-293, 308-313, 339-348, 375-380, 396-402, 419-428, 455-466, 488-508`).
  - [x] 1.4 Re-read DPANS94 §6.1.2214 and §6.1.1561 for the **exact** sign-convention language. The symmetric vs. floored distinction is the critical correctness hinge — paraphrase the spec's `d = q·n + r` relation in a Dev Notes sub-section for reference during implementation.
  - [x] 1.5 Re-read DPANS94 §3.2.2.1 (arithmetic range) to confirm the quotient-overflow caveat (§6.1.2370 declares behaviour implementation-defined when quotient does not fit). Document antforth's choice (silent-truncate-to-low-16 — matching single-cell `/`) in the header comment of `UM/MOD`.

- [x] **Task 2 — Implement `UM/MOD` in `src/double.asm`** (AC: #1, #4, #5, #6, #7, #8)
  - [x] 2.1 Append DEFCODE block after `w_D_STAR` (currently ends at `src/double.asm:534`; the `double_ip_stash` cell at 540 must remain the file's final item — insert new code **before** `double_ip_stash`).
  - [x] 2.2 `CALL check_underflow_3` at entry (AC #5).
  - [x] 2.3 Body: 16-iteration shift-and-subtract with 32-bit dividend + 16-bit divisor → 16-bit quotient + 16-bit remainder. Pattern options:
    - **Option A (register-only, HL = remainder, BC' or scratch = divisor, DE = partial-quotient accumulator, 32-bit dividend split across HL and DE):** Pre-load HL = `ud-hi` (second on stack POP), DE = `ud-lo` (third POP); BC = `u1` divisor (TOS, already in BC). Shift [HL:DE] left by one bit each iteration (32-bit left shift: `ADD HL, HL; RL E; RL D` — careful with carry chain — actually the idiom is `SLA E; RL D; RL L; RL H; RL <33rd-bit>` — need a 33rd overflow bit to capture a remainder that overshoots); try `SBC HL, BC` on the remainder; if no borrow, keep subtraction and set bit 0 of the partial-quotient (DE's low bit). After 16 iterations: HL = remainder, DE = quotient. Push remainder, move quotient into BC (TOS), restore IP.
    - **Option B (use `udivmod` as a template + pre-seed):** Read `src/arithmetic.asm:114-136` — that routine does 16-bit / 16-bit → (quotient, remainder) with a 16-bit dividend in HL. The shift-subtract inner loop is structurally identical; the only extension is that `UM/MOD`'s dividend is 32-bit, which means the initial remainder register is pre-loaded with `ud-hi` (instead of starting at 0). Each iteration then shifts `[remainder : ud-lo-serving-as-quotient-accumulator]` left by one bit — effectively a 33-bit shift-subtract. **Do not call `udivmod` directly** — the pre-seed condition differs; write a fresh inner loop modelled on it.
    - **Option C (full-software-divide-by-hand — from scratch):** straightforward long-division algorithm in assembly. ~55 bytes. Use this if Options A/B get tangled.
    - **Recommended:** Option A or B (they converge to the same code). Single DEFCODE, ~45-55 bytes. Memory-stash IP to `double_ip_stash` per Stories 10.2–10.5 precedent.
  - [x] 2.4 **Quotient-overflow handling:** per §6.1.2370, if `ud / u1` does not fit in a single cell, the result is implementation-defined. antforth truncates silently (returns low 16 of quotient; remainder may be incorrect). Document in the header comment. **Do not add overflow-detection code** — the epic baseline matches single-cell `/`'s truncation convention.
  - [x] 2.5 **Divide-by-zero:** empirically verify what single-cell `/` does today when executed as `1 0 /` — does it ABORT? Produce garbage? Hang? Record the answer in the Dev Notes during implementation, then match that behaviour bit-identically (per AC #8). Do not add new divide-by-zero handling; Epic 11 Story 11.4 is the migration site.
  - [x] 2.6 CCD-3 comment: `; ANS Forth 1994 §6.1.2370   UM/MOD   — unsigned mixed divide (double ÷ single → single rem + single quot)`.
  - [x] 2.7 Stack-effect comment on header line: `; UM/MOD ( ud u1 -- urem uquot )`.

- [x] **Task 3 — Implement `SM/REM` in `src/double.asm`** (AC: #2, #4, #5, #6, #7, #8)
  - [x] 3.1 DEFWORD block after `w_U_M_SLASH_MOD` (or chosen DEFCODE-name equivalent — tentatively `w_U_M_SLASH_MOD`). Body approach options:
    - **Option A (pure-DEFWORD on UM/MOD):** canonical ANS §A.6.1.2214 reference:
      ```
      : SM/REM   ( d n1 -- r q )
          OVER >R         \ stash dividend sign (high cell of d; bit 15 = sign)
          2DUP XOR >R     \ stash quotient sign ( sign(d-hi) XOR sign(n1) on R-stack as `sign-XOR`)
          ?DUP 0< IF NEGATE THEN    \ ABS(n1) — nope, 0 matters — simpler: DUP ABS SWAP 0<… (see below)
          ...
      ```
      Actually the cleanest canonical body (see GForth / SwiftForth) is:
      ```
      : SM/REM   ( d n1 -- r q )
          2DUP XOR >R     \ sign of quot on R: (d-hi XOR n1 — top bit reflects sign-XOR-of-dividend-sign-and-divisor-sign)
          OVER >R         \ sign of rem on R (under sign of quot): (d-hi alone — top bit = sign of dividend)
          ABS >R          \ |n1| on R
          DABS R>         \ |d| then restore |n1| to TOS — now ( |d| |n1| )
          UM/MOD          \ ( |rem| |quot| )
          SWAP R>         \ ( |quot| |rem| sign(d-hi) )
          0< IF NEGATE THEN   \ fix remainder sign: negate iff dividend was negative
          SWAP R>         \ ( |rem-fixed| |quot| sign-XOR )
          0< IF NEGATE THEN   \ fix quotient sign: negate iff signs differed
      ;
      ```
      ~20 cells body. Relies on single-cell `ABS`, `NEGATE`, `0<`, `DABS`, `UM/MOD`, `SWAP`, `XOR`, `OVER`, `>R`, `R>`. All already available post-10.5.
    - **Option B (DEFCODE with explicit register-level sign tracking):** write the full algorithm inline with per-operand ABS + UM/MOD inner loop + DNEGATE post-fix. ~65 bytes. More fragile; no significant cycle savings given `SM/REM` is not in a hot inner loop.
    - **Recommended:** **Option A (DEFWORD)**. Matches the 10.5 precedent for `M*` (DEFWORD on UM*). Copy the M* template exactly and adapt.
  - [x] 3.2 **Watch the `$8000` fixed-point trap.** Single-cell `ABS($8000)` returns `$8000` (Z80 fixed-point case). But for `SM/REM`, the analogous "gotcha" is `DABS($80000000)` which also returns `$80000000` unchanged. In practice this is a non-issue because: (a) the only input where `DABS` fails is `d = $80000000 = -2^31`, and (b) for that input, `SM/REM` with any single-cell divisor would produce a quotient magnitude ≥ `2^15 / n1`; the interesting case `d = -2^31, n1 = 1` gives `quot = -2^31` which does not fit in 16 bits anyway — quotient-overflow territory per AC #7, so the result is implementation-defined. Don't try to fix this corner. The **required-to-work** test inputs (AC #2) stay within single-cell-quotient range and hit `DABS` only on values whose absolute exists (`-10 -5 -32768` but always with a divisor large enough that the quotient fits).
  - [x] 3.3 Underflow guard: DEFWORD thread's first body word must guard for depth 3. `OVER` needs 2; `2DUP` needs 2; `DABS` needs 2 — **none reach 3**. Options: (a) prepend an explicit `check_underflow_3` via a small DEFCODE helper; (b) restructure the thread so the first-accessed word's N matches (e.g., `2DUP` followed by underflow_N re-verification is not cheap); (c) front-load with a DROP/DUP pair that exercises depth 3 implicitly — contrived. **Cleanest: land a small `(?3)` guard DEFCODE that `CALL check_underflow_3 / NEXT` and thread it as the first opcode of both SM/REM and FM/MOD.** Alternatively, rewrite `SM/REM` as DEFCODE — see Option B of Task 3.1.
  - [x] 3.4 CCD-3 comment: `; ANS Forth 1994 §6.1.2214   SM/REM   — symmetric signed mixed divide (quotient truncates toward zero, remainder sign matches dividend)`.
  - [x] 3.5 Stack-effect comment on header line: `; SM/REM ( d n1 -- nrem nquot )`.

- [x] **Task 4 — Implement `FM/MOD` in `src/double.asm`** (AC: #3, #4, #5, #6, #7, #8)
  - [x] 4.1 DEFWORD block after `w_S_M_SLASH_REM`. Canonical ANS §A.6.1.1561 reference:
    ```
    : FM/MOD   ( d n1 -- r q )
        DUP >R          \ stash divisor for correction check
        SM/REM          \ ( r q )
        OVER DUP        \ ( r q r r )
        IF              \ r != 0
            R@ XOR 0<   \ sign(r) XOR sign(divisor) < 0 → correction needed
            IF
                1- SWAP R@ + SWAP   \ quot := quot - 1 ; rem := rem + divisor
            ELSE
                R> DROP
            THEN
        ELSE
            DROP R> DROP
        THEN
    ;
    ```
    That's the "untidy" form — cleaner variants exist. GForth's `fm/mod` is:
    ```
    : FM/MOD   ( d n -- r q )
        DUP >R
        2DUP XOR 0< >R         \ sign of rem-divisor-XOR on R
        OVER 0< IF DNEGATE THEN
        R> IF NEGATE THEN       \ … hmm, this is the direct form, not SM/REM-based
    ;
    ```
    — but the **SM/REM-then-correction** form (the DPANS94 §A.6.1.1561 reference) is shorter and more literal, so use it.
  - [x] 4.2 **Sign-correction trap:** the condition for applying the decrement-and-add correction is (a) remainder is nonzero AND (b) sign of remainder differs from sign of divisor. `sign(r) XOR sign(n1) < 0` captures both halves of (b) correctly (XOR's sign bit is 1 iff the two signs disagree), and the separate `IF r != 0` guard handles (a). Get these two guards right — conflating them causes the `0 9 3 FM/MOD` (exact-division) case to corrupt. Witness test: `0 9 3 FM/MOD` → `( 0 3 )` — NOT `( 3 2 )`.
  - [x] 4.3 Underflow guard: same issue as SM/REM — thread's first body word (`DUP`) needs 1; insufficient. Use the same `(?3)` guard DEFCODE or prepend any primitive whose `check_underflow_3` call does reach.
  - [x] 4.4 CCD-3 comment: `; ANS Forth 1994 §6.1.1561   FM/MOD   — floored signed mixed divide (quotient rounds toward -∞, remainder sign matches divisor)`.
  - [x] 4.5 Stack-effect comment on header line: `; FM/MOD ( d n1 -- nrem nquot )`.
  - [x] 4.6 **Discrimination witness check:** after building, hand-verify that `0 -10 3 SM/REM` and `0 -10 3 FM/MOD` produce **different** results (`( -1 -3 )` vs. `( 2 -4 )`). If both produce the same answer, the floor-correction is silently skipped — the most likely defect mode for this word.

- [x] **Task 5 — Extend `tests/double_tests.fth`** (AC: #9, #10)
  - [x] 5.1 Append section header: `\ === Story 10.6 double/mixed-precision division (UM/MOD, SM/REM, FM/MOD) ===`.
  - [x] 5.2 Sub-section headers per word: `\ --- UM/MOD (§6.1.2370) unsigned mixed divide ---`, `\ --- SM/REM (§6.1.2214) symmetric signed mixed divide ---`, `\ --- FM/MOD (§6.1.1561) floored signed mixed divide ---`, `\ --- Story 10.6 underflow recovery ---`.
  - [x] 5.3 Forth one-liners with `\ expect: <fragment>` comments for every AC #10 scenario. Use `.S 2DROP` for multi-cell outputs (as in Story 10.4 / 10.5 tests).
  - [x] 5.4 Total ≥ 23 test scenarios, covering at minimum the AC #10 list (6-8 UM/MOD + 7-8 SM/REM + 7-8 FM/MOD + 3 underflow).
  - [x] 5.5 **Include the symmetric-vs-floored discrimination case as explicitly paired adjacent tests** (one SM/REM + one FM/MOD on the same input) so the ±1-quotient-difference is visible on a code read of the test block. This directly satisfies `epics.md:572`'s "symmetric-vs-floored discrimination case required by the standard".

- [x] **Task 6 — Wire up Makefile `test-repl` entries** (AC: #9, #10, #11)
  - [x] 6.1 Section banner: `@# --- Story 10.6 double/mixed-precision division (526..<end>) — DPANS94 §6.1.{1561,2214,2370} ---`.
  - [x] 6.2 Canonical `printf … | $(IZCPM) $(TARGET) | grep -q` pattern (copy template from Story 10.5 tests 502..525 — `Makefile:4383-4578`).
  - [x] 6.3 Numbering: start at **526** (Story 10.5 closed at 525 per `Makefile:4572-4579`). Contiguous integer numbering; no gaps.
  - [x] 6.4 Watch for `printf` option-terminator gotcha with negative literals: tests with leading `-` need `printf --` (e.g., `-1 -10 -3 SM/REM`). Story 10.4 / 10.5's precedent at tests 453, 459, 462, 466, 467, 510, 513 etc. shows the `printf --` idiom.
  - [x] 6.5 Watch for unescaped `$<hex>` in PASS/FAIL echo banners: any literal `$FFFF`, `$8000`, `$FFFE` etc. in an echo line must be written as `$$FFFF` / `$$8000` / `$$FFFE` to survive Make → shell double-expansion. Story 10.5 code-review confirmed this discipline across tests 504-507, 519-520.
  - [x] 6.6 Underflow tests: one per word at DEPTH = 2 (N - 1 = 3 - 1). Template: Story 10.5's tests 523..525 at `Makefile:4547-4579`.

- [x] **Task 7 — Regression verification** (AC: #11, #13)
  - [x] 7.1 `make clean && make test` — must PASS.
  - [x] 7.2 `make test-repl` — must show `N` unique test numbers PASS, 0 FAIL, where `N = 525 + <count of new entries>`.
  - [x] 7.3 Spot-check regression on adjacent words: `/`, `MOD`, `/MOD`, `*`, `D+`, `D-`, `M+`, `DNEGATE`, `DABS`, `D=`, `D<`, `S>D`, `D>S`, `2@`, `2!`, `UM*`, `M*`, `D*`, `+ - NEGATE ABS = <` — all output byte-identical to pre-story baseline. Critical regression risk: the shared `double_ip_stash` cell is now reused by five DEFCODEs (D+, D-, DNEGATE, D=, D<, UM*, UM/MOD) — if any of those alias inside a thread, corruption appears. Verify with adjacency tests.
  - [x] 7.4 ROM size delta: record pre-edit (`build/antforth.com` = 15606 pre-story) and post-edit `.com` size in Completion Notes (informational per AC #13; CCD-4 gate is 10.10).
  - [x] 7.5 **Divide-by-zero empirical baseline check** (AC #8): run `1 0 /` and `1 0 MOD` and `1 0 /MOD` against the pre-edit build and record the exact output (e.g., "? Stack underflow", "0 ok", "hang", garbage value, etc.). Then repeat with `1 2 0 UM/MOD` / `0 -10 0 SM/REM` / `0 -10 0 FM/MOD` against the post-edit build and confirm byte-identical behaviour. Document in the Dev Agent Record.

- [x] **Task 8 — Update `docs/ans-forth-core-compliance.md`** (AC: #12)
  - [x] 8.1 In the §6.1 "Arithmetic" table at `ans-forth-core-compliance.md:83-103`, flip the `FM/MOD` row (line 101) and the `SM/REM` row (line 102) from `**Gap → Story 10.6**` to `Implemented (`double.asm:<line>`)`. Line numbers resolve at write-time.
  - [x] 8.2 In the §6.1 "Double-Cell Division" table at `ans-forth-core-compliance.md:114-120`, flip the `UM/MOD` row (line 120) from `**Gap → Story 10.6**` to `Implemented (`double.asm:<line>`)`; update the sub-section heading at line 116 from "0 implemented, 1 missing" to "1 implemented, 0 missing. **100% complete.**"
  - [x] 8.3 In the §6.1 "Arithmetic" sub-section heading at line 81, update the count from "19 §6.1 Core words — 14 implemented, 5 missing" to "19 §6.1 Core words — 16 implemented, 3 missing" (`*/` `*/MOD` remain in the Arithmetic section; `UM/MOD` is in the separate Double-Cell-Division section).
  - [x] 8.4 In the §6.1 Summary table at `ans-forth-core-compliance.md:11-18`, update:
      - "Fully implemented" 120 → 123
      - "Missing" 13 → 10
      - Coverage "120 / 133" → "123 / 133"; percentage 90.2% → **92.5%**
  - [x] 8.5 In the Gap Classification table at `ans-forth-core-compliance.md:23-28`, decrement "(b) Oversight — missing subsystem" by 3 (11 → 8).
  - [x] 8.6 Update the "Missing subsystem: Double-cell operations" sub-heading at line 304 from "5 §6.1 words remaining" to "2 §6.1 words remaining" (`*/` and `*/MOD` only; both routed to Story 10.9).
  - [x] 8.7 In the "Double-cell operations" breakdown table at lines 308-315, flip the "Double / mixed division" row's Story column from `10.6` to `10.6 ✓ Implemented` (match Story 10.5's "✓ Implemented" marker for the "Double / mixed multiplication" row).
  - [x] 8.8 Update the Epic-10 closure plan row for 10.6 at line 44: from `| 10.6 | Double / mixed division | 3 (`FM/MOD` `SM/REM` `UM/MOD`) | |` to `| 10.6 | Double / mixed division | 3 ✓ (`FM/MOD` `SM/REM` `UM/MOD`) | Complete |` (match Story 10.4 / 10.5 row style).
  - [x] 8.9 Update the "big gaps" observation paragraph at `ans-forth-core-compliance.md:407` — the "5 §6.1 words remaining" count drops to 2; note that Story 10.6 is done; remaining gap is `*/` + `*/MOD` via Story 10.9.
  - [x] 8.10 Do NOT touch §6.2 or §8.6 tables — all three words are §6.1 Core; Story 10.6 adds nothing to §8.6. Confirm by grep: "Story 10.6" should appear **only** in §6.1 tables after the edits.

- [x] **Task 9 — Self-review (adversarial) + code-review handoff** (AC: all)
  - [x] 9.1 Before marking the story complete, run an **adversarial self-review** (per project memory `feedback_adversarial_review.md`) looking specifically for:
    - **UM/MOD inner-loop direction:** the shift-subtract algorithm shifts the [remainder:quotient-accumulator] register pair LEFT each iteration (opposite to `UM*`'s RIGHT shift). Test `0 10 3 UM/MOD` → `( 1 3 )` catches a wrong-direction bug immediately (wrong direction gives a number that looks nothing like 3 rem 1).
    - **UM/MOD quotient-overflow silent truncation:** verify the convention per AC #7 matches single-cell `/` by hand-computing an overflow case (e.g., `1 0 2 UM/MOD` = `$10000 / 2 = $8000` — this fits; try `-2 -1 1 UM/MOD` = `$FFFE_FFFF / 1` which overflows — document what antforth produces). Do NOT add overflow detection.
    - **UM/MOD subtract-with-borrow discipline:** the trial-subtract `SBC HL, BC` in the inner loop must zero CF before each SBC (`OR A`), because an un-cleared CF from a prior iteration's RR corrupts the subtract. `udivmod` at `arithmetic.asm:123` uses `OR A` before `SBC`; follow the pattern.
    - **SM/REM sign-fixup pairing:** quotient sign = sign(d-hi) XOR sign(n1); remainder sign = sign(d-hi). Both are tracked independently on the return stack. Cross-verification: for `0 -10 3 SM/REM`: d = +10 → no wait, `d-hi = 0, d-lo = -10` means d is the 32-bit value `$0000FFF6 = +65526`? No — `-10` as the second token is the signed single-cell value `$FFF6`; so `0 -10 SM/REM` reads d as `(high=0, low=$FFF6)` = unsigned `65526` = NOT `-10` signed double! **This is a common AC-drafter trap.** To express `d = -10` as a signed double, use `-1 -10` (which gives d = `$FFFF_FFF6 = -10 signed` since `-1 = $FFFF` and `-10 = $FFF6`). **Re-verify every AC #2 / #3 test case arithmetically** before claiming the answers.
    - **FM/MOD correction guard order:** the correction applies only when `rem ≠ 0 AND sign(rem) XOR sign(n1) < 0`. Getting the order wrong (applying correction unconditionally when rem = 0) breaks the exact-division tests (e.g., `0 9 3 FM/MOD` → wrong result).
    - **FM/MOD discrimination witness test at input `0 -10 3`:** SM/REM gives `( -1 -3 )`, FM/MOD gives `( 2 -4 )`. If both produce `( -1 -3 )`, the correction path is never taken — the most likely defect.
    - **Underflow counts:** all three primitives need `check_underflow_3` (three user cells: 2-cell dividend + 1-cell divisor). Stories 10.3 / 10.4 caught related trap cases; don't guess — recompute N.
    - **Divide-by-zero bit-identical preservation:** empirically compare pre-edit `1 0 /` output vs post-edit `1 0 UM/MOD` / `SM/REM` / `FM/MOD` outputs. Record the exact byte stream in the Dev Agent Record.
    - **Missing CCD-3 §-number citations or drifted §-numbers.**
    - **Regressions in single-cell `/ MOD /MOD`** — these share mental model with the new words and can be accidentally altered in cross-editing. Run the full regression; do not rely on spot-checks alone.
  - [x] 9.2 Fill Completion Notes with plain diagnostic prose (per memory `feedback_plain_qa_language.md`) — measured values, gates, reasons, no florid framing.
  - [x] 9.3 Different-LLM second-pass review recommended — `/bmad-bmm-code-review 10.6` is the natural hook. Stories 10.2, 10.3, 10.4, 10.5 all caught real defects in that pass (10.3 off-by-one underflow; 10.4 wrong-arithmetic AC boundary + Makefile `$` escaping; 10.5 stale section-header counts). This story's trap-rich surface (sign-fixup for SM/REM, floor-correction guard for FM/MOD, shift-subtract carry chain for UM/MOD, quotient-overflow implementation-defined case) is a similar target.

## Dev Notes

### Story Purpose and Epic-10 Position

Story 10.6 is the **fifth implementation story in Epic 10** and closes the division leg of the double-cell subsystem. It completes the §6.1 Core "Double-Cell Division" sub-category (`UM/MOD` was the sole entry) and the last two §6.1 Core Arithmetic entries (`SM/REM` and `FM/MOD`). After this story lands, the only remaining §6.1 Core Arithmetic gaps are `*/` and `*/MOD`, both routed to Story 10.9 — and both depending on `SM/REM` from **this** story as their mixed-precision divisor.

One thing falls out of this story that subsequent stories depend on:

1. **`SM/REM` existence** — directly required by Story 10.9's `*/` and `*/MOD`: the canonical ANS implementation of `*/` is `M* SM/REM`, where `M*` (Story 10.5) produces the mixed double-precision intermediate and `SM/REM` (this story) consumes it.

None of the three Story-10.6 words are §8.6 bonus — all three are §6.1 Core. This is the **cleanest-scope Story in Epic 10 so far** in terms of compliance-doc edits: only §6.1 tables move.

### Architectural Decisions That Apply to This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§206-216 CCD-3 (Standards-Citation Discipline):** every word cites its DPANS94 §-number. Format is non-negotiable — match Stories 10.2 / 10.3 / 10.4 / 10.5 template (`src/double.asm` house style across all existing DEFCODEs / DEFWORDs).
- **§218-226 CCD-4 (Per-Epic Benchmark Gate):** gate is at **Story 10.10**, not here. Record ROM delta informationally in Completion Notes.
- **§248-252 E10-D1 (Byte-Order):** low cell on TOS, high cell below. For all three Story-10.6 words, the stack on entry is `( d-high d-low n1 )` with `n1 = BC` (TOS). On exit: `( rem quot )` with `quot = BC` (TOS). Non-negotiable — don't flip the convention.
- **§260-264 E10-D3 (Implementation split):** division primitives are in the same category as multiplication (Story 10.5): `UM/MOD` is the hot inner primitive (DEFCODE); `SM/REM` and `FM/MOD` are thin wrappers composing `UM/MOD` + sign/floor fixup (DEFWORD permitted).
- **§434-447 Source-file organisation:** `src/double.asm` is the home for Epic-10 double-cell primitives — all three Story-10.6 words live there, appended before `double_ip_stash`.

### BC-as-TOS Convention (Project Memory: `project_tos_in_register.md`)

Every existing stack / arithmetic primitive treats BC as TOS on entry and exit:

| Word | Entry BC | Exit BC |
|---|---|---|
| `UM/MOD` | `u1` (divisor) | `uquot` (quotient) |
| `SM/REM` | `n1` (divisor) | `nquot` (quotient) |
| `FM/MOD` | `n1` (divisor) | `nquot` (quotient) |

`DE = IP` throughout. For the DEFCODE `UM/MOD`, memory-stash IP via the existing `double_ip_stash` cell (`src/double.asm:540`). For the DEFWORD `SM/REM` and `FM/MOD`, DE-preservation is automatic (each threaded primitive in the body handles its own DE).

### Stories 10.2 / 10.3 / 10.4 / 10.5 Carry-Forwards

From `_bmad-output/implementation-artifacts/10-{2,3,4,5}-*.md` (all `done`):

1. **CCD-3 template locked.** Format: `; ANS Forth 1994 §<n>   <word>   — <note>`. Every §-number verified at write-time.
2. **`check_underflow_3` exists** in `src/system.asm:~278-362`. Used today by `2!` and `M+`. Use directly; do not introduce new helpers.
3. **`src/double.asm` file is appended-to.** Add the three new words **before** the `double_ip_stash` cell at the tail (keep that cell as the file's final item so its address stays stable — the cell is currently at line 540).
4. **Tests live in `tests/double_tests.fth`** — extend, don't create. Section header style: `\ === Story 10.X <topic> ===`.
5. **Makefile test numbering is contiguous.** Current max is **525** (post-Story-10.5). Start at **526**. Do not leave gaps.
6. **Different-LLM second-pass review is expected** for Epic-10 stories that write new code. Stories 10.2–10.5 each caught defects in that pass that self-review missed. This story's sign-fixup / floor-correction / shift-subtract surface is a similar target.
7. **`double_ip_stash` is the one shared scratch cell.** Never held across NEXT; never re-entered. Safe for `UM/MOD`'s DEFCODE. `SM/REM` and `FM/MOD` (DEFWORDs) don't need it — the shadow state lives on the return stack across `>R` / `R>`.
8. **The house pattern for "hot primitive + sign wrappers" is:** DEFCODE inner, DEFWORD wrapper(s). See Story 10.5's `UM*` (DEFCODE) + `M*` (DEFWORD on UM*) + `D*` (DEFWORD on UM*). Story 10.6 mirrors: `UM/MOD` (DEFCODE) + `SM/REM` (DEFWORD on UM/MOD) + `FM/MOD` (DEFWORD on SM/REM).

### Stack-Underflow Discipline

Pre-Epic-11 convention: `check_underflow_N` at entry, falls through to ABORT on fail, REPL recovers. Epic 11 migrates to `THROW -4` in Story 11.4. **Do NOT pre-migrate.**

Per-word mapping table: all three Story-10.6 words consume 3 user cells and call `check_underflow_3`.

**DEFWORD underflow subtlety:** the DEFWORD options for `SM/REM` and `FM/MOD` cannot inherit the guard from their first body word because none of the candidate first-words (`OVER`, `DUP`, `2DUP`, `DABS`) need 3 cells. Options:

- **Small guard DEFCODE `(?3)`** that just `CALL check_underflow_3 / NEXT`, threaded as the first opcode. Adds ~10 bytes for the guard itself (one-time), then 2 bytes per DEFWORD that uses it. Total cost: ~14 bytes over rewriting both as DEFCODEs.
- **Rewrite `SM/REM` as DEFCODE:** ~65 bytes of sign-tracking + UM/MOD inner loop reuse. Heavier but avoids introducing a new internal word.
- **Inline-compile a literal `3` and call `?STACK` directly** — not currently exposed as a threaded primitive.

**Recommended: the `(?3)` guard helper.** It's the smallest increment and composes for any future DEFWORDs that need a depth-3 guard (none currently planned, but also not costly if introduced now).

### Divide-by-Zero — Empirical Baseline and Epic-11 Migration

Per epic AC #4 (`epics.md:566-568`), divide-by-zero behaviour matches the Epic-1–8 baseline, with Epic 11 Story 11.4 migrating to `THROW -10`. However, the epic's parenthetical "ABORT pre-Epic-11" appears to describe an aspirational baseline rather than the measured one — the actual `udivmod` comment at `src/arithmetic.asm:115` reads "Precondition: BC != 0 (division by zero produces undefined result)", implying no ABORT. **Dev agent must empirically verify** what `1 0 /` produces today (Task 7.5) and reproduce it bit-identically for the three new primitives — **not** introduce new ABORT behaviour that contradicts the existing single-cell baseline.

Per project memory `feedback_standards_compliance.md`: if empirical behaviour disagrees with the epic spec, flag the discrepancy. Don't rationalise. Epic 11 Story 11.4 is the authoritative migration site; documenting the real-today baseline there is more valuable than pretending it's already ABORT.

### Correctness Traps (by word)

**`UM/MOD`:**

- **Loop iteration count:** exactly 16. Test `0 10 3 UM/MOD` → `( 1 3 )` (= 10 ÷ 3 = 3 rem 1). A 15-iteration bug produces a quotient half the correct magnitude; 17-iteration bug produces roughly double. The canonical diagnostic is `-2 -1 -1 UM/MOD` → `( -1 -1 )` which exercises the full 16 bits of both dividend and divisor.
- **33-bit shift register:** the shift-subtract algorithm treats [remainder : dividend-low] as a 32-bit register that shifts left each iteration. A 33rd bit (the CF from each left shift) must participate in the subsequent SBC compare: if the high bit that shifted out of the remainder is 1, the remainder is conceptually ≥ 2^16 and the divisor always fits in it (subtract and set quotient bit). Handle this via `ADD HL, HL / RL E / RL D / JR NC, ...; OR A; SBC HL, BC; ...`. The `udivmod` precedent at `arithmetic.asm:114-136` shows the pattern for 16-bit dividends; widening to 32 adds the pre-seed (HL starts with d-hi, not 0).
- **Trial-subtract restore:** when the trial SBC produces a borrow (remainder < divisor), restore with `ADD HL, BC`. Do NOT leave the subtracted-but-wrong value in HL. The `udivmod` precedent handles this at `arithmetic.asm:125-126`.
- **Quotient-overflow silent truncation:** per AC #7, antforth truncates to low 16 bits if the quotient does not fit. The algorithm naturally does this (the quotient-accumulator is only 16 bits wide; overflow bits fall off). **Do NOT add overflow detection.** If future compliance wants a THROW on overflow, that's an Epic-11+ concern.
- **CF preservation across the 16-iteration loop:** each iteration's shift uses CF; each iteration's SBC uses CF. Order operations so CF from the previous step is consumed before being overwritten.

**`SM/REM`:**

- **Sign-XOR for quotient sign:** `sign(d-hi) XOR sign(n1)` — the top bit of (`d-hi XOR n1`) captures this. Extract BEFORE any NEGATE/DABS call mangles the sign bits. Stash on return stack.
- **Sign of dividend for remainder sign:** extracted from `sign(d-hi)` alone (symmetric convention: remainder matches dividend). Stash independently on return stack.
- **`DABS($80000000)` fixed-point trap:** returns `$80000000` unchanged (same as single-cell `ABS($8000)` in the Z80 fixed-point case). In practice, the test cases in AC #2 don't hit this (every dividend magnitude is within `UM/MOD`'s safe range), and the `$80000000 / any-n1-except-1` cases produce quotients too large to fit in 16 bits — quotient-overflow territory per AC #7. Don't fix; note.
- **Return-stack discipline:** two sign flags pushed, two popped, order matters. Quotient sign pushed first (deepest), popped last. Stash of `|n1|` on rstack (between sign flags) keeps |n1| available after `DABS` consumes the two dividend cells. Test the order carefully — wrong order corrupts both signs.

**`FM/MOD`:**

- **Correction-guard order (the canonical defect):** correction applies iff `rem ≠ 0 AND sign(rem) XOR sign(n1) < 0`. Both halves must be checked. Skipping the `rem ≠ 0` guard corrupts exact-division cases (`0 9 3 FM/MOD` → would produce `( 3 2 )` instead of `( 0 3 )`). Skipping the sign-differ guard corrupts same-sign cases (`0 10 3 FM/MOD` → would produce `( -2 4 )` instead of `( 1 3 )`).
- **Witness test for correction path taken:** `0 -10 3 FM/MOD` → `( 2 -4 )` is the cleanest discrimination-from-SM/REM signal (SM/REM produces `( -1 -3 )`). If the dev sees the same output from both words on this input, the correction path is a no-op.
- **Preserve divisor across SM/REM call:** the correction needs `n1`, but `SM/REM` consumes it. Stash on rstack before SM/REM via `DUP >R`; recover via `R>`.

### Epic 10 Dependencies Not Yet Landed

Nothing blocks Story 10.6:

- Epic 1–8 parameter-stack + memory + arithmetic primitives ✓ (including single-cell `/`, `MOD`, `/MOD`, `NEGATE`, `ABS`, `XOR`, `0<`)
- Story 10.1 gap survey ✓ (assigned `FM/MOD` `SM/REM` `UM/MOD` to 10.6)
- Story 10.2 double-cell stack foundation ✓ (`src/double.asm` file, CCD-3 template, `check_underflow_3` helper available, test file, `2DUP 2SWAP 2DROP 2OVER` available for DEFWORD wrappers)
- Story 10.3 single↔double conversions ✓ (`S>D` for symmetric derivations; `D>S` for narrowing)
- Story 10.4 double arithmetic ✓ (`D+`, `D-`, `DNEGATE`, `DABS` — **`DABS` is directly consumed** by SM/REM's DEFWORD body)
- Story 10.5 double multiplication ✓ (nothing directly consumed by 10.6, but the DEFCODE-inner + DEFWORD-wrapper house pattern is established)

Story 10.9 (`*/`, `*/MOD`) depends on **this** story's `SM/REM`. Story 10.7 (pictured numeric output) depends on **this** story's `UM/MOD` for the pictured-output digit-extraction inner loop (classical ANS formulation: `<# # >` uses `UM/MOD BASE @` to peel digits).

### Epic 10 Retro — Action Items Relevant to This Story

From Stories 10.2–10.5's code-review passes:

- **Plain QA prose:** apply to Completion Notes — state measured values, gates, reasons plainly (memory `feedback_plain_qa_language.md`).
- **AC-drafting trace-check:** every AC in this story maps to at least one Makefile test entry. Traceability is explicit in AC #10.
- **Adversarial self-review that actually finds things:** Stories 10.4 and 10.5 both had self-reviews declare "no findings" while code-review found multiple. For this story, the obvious attack surfaces are UM/MOD (loop count / shift-subtract carry / quotient-overflow silent truncation), SM/REM (sign-fixup pairing + return-stack discipline + `$80000000` singular input), FM/MOD (two-part correction guard), and the cross-word divide-by-zero baseline preservation. **Assume your self-review missed something.**
- **Makefile `$$` escaping:** any hex literal or `$`-prefixed string in an echo'd PASS/FAIL banner needs `$$`. Story 10.5 code-review confirmed the convention across tests 504-507.
- **`printf --` option terminator:** tests whose input begins with a `-` literal need `printf --`. Story 10.4 / 10.5 established this; AC #10 has several such inputs (`-1 -10 -3 SM/REM`, `-1 -5 10 SM/REM`, etc.).

### Project Structure Notes

- **Files touched:**
  - `src/double.asm` (EDIT — append 1 DEFCODE + 2 DEFWORDs + possibly 1 `(?3)` guard DEFCODE before `double_ip_stash`)
  - `tests/double_tests.fth` (EDIT — append Story 10.6 section)
  - `Makefile` (EDIT — new `test-repl` entries starting at 526)
  - `docs/ans-forth-core-compliance.md` (EDIT — 2 Arithmetic row flips + 1 Double-Cell-Division row flip + 2 sub-section heading count updates + Summary-table increment + Gap Classification decrement + Epic-10 closure-plan row update + big-gaps paragraph count update)
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` (EDIT — status transitions, handled by dev-story workflow)
  - `_bmad-output/implementation-artifacts/10-6-double-mixed-precision-division.md` (this file — Dev Agent Record + Completion Notes at close)
- **No new files created.** Stories 10.2–10.5 set up `src/double.asm` and `tests/double_tests.fth`; Story 10.6 extends both.
- **Alignment with unified structure:** all edits sit in established homes per `architecture.md:434-447`. No source-tree structural change.
- **Detected conflicts or variances:** one potential discrepancy — the epic AC #4 at `epics.md:566-568` describes the Epic-1–8 divide-by-zero baseline as "ABORT pre-Epic-11", but the actual `udivmod` precondition comment at `src/arithmetic.asm:115` reads "division by zero produces undefined result" (no ABORT). Dev agent must empirically verify what today's `1 0 /` produces and reproduce it; do not invent ABORT behaviour that doesn't exist. Flag discrepancy in Completion Notes (per memory `feedback_standards_compliance.md`). The §-numbers (`UM/MOD §6.1.2370`, `SM/REM §6.1.2214`, `FM/MOD §6.1.1561`) are consistent across epics.md (§-numbers in ACs 2, 3), compliance doc, and DPANS94. Verify at write-time anyway (Task 1.1).

### References

- **Authoritative standard:**
  - DPANS94 §6.1.2370 `UM/MOD` — unsigned mixed divide (double ÷ single → single rem + single quot)
  - DPANS94 §6.1.2214 `SM/REM` — symmetric signed mixed divide (quotient truncates toward zero; remainder matches dividend sign)
  - DPANS94 §6.1.1561 `FM/MOD` — floored signed mixed divide (quotient rounds toward -∞; remainder matches divisor sign)
  - DPANS94 §3.2.2.1 — integer range and quotient-overflow implementation-defined clause
  - DPANS94 §A.6.1.2214 — reference implementation of `SM/REM` (informative)
  - DPANS94 §A.6.1.1561 — reference implementation of `FM/MOD` (informative; `SM/REM`-then-correction form)
  - **Verify all §-numbers at implementation time** against DPANS94 / forth-standard.org before committing comments.
- **Planning artefacts:**
  - `_bmad-output/planning-artifacts/epics.md:546-572` — Story 10.6 epic spec
  - `_bmad-output/planning-artifacts/epics.md:426-448` — Epic 10 overview
  - `_bmad-output/planning-artifacts/epics.md:793-795` — Epic 11 Story 11.4 divide-by-zero migration acceptance (downstream)
  - `_bmad-output/planning-artifacts/architecture.md:246-264` — E10-D1 / E10-D2 / E10-D3 decisions
  - `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 Standards-Citation Discipline
  - `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 Per-Epic Benchmark Gate (at Story 10.10, not here)
  - `_bmad-output/planning-artifacts/architecture.md:434-447` — Source-file organisation table
  - `_bmad-output/planning-artifacts/prd.md:387-389` — FR10 / FR11 / FR12 (double-cell + conversions + arithmetic)
  - `_bmad-output/planning-artifacts/prd.md:460-479` — NFR9 (regression), NFR10 (Core compliance), NFR16 (test-first), NFR17 (standards citations)
- **Precedent stories:**
  - `_bmad-output/implementation-artifacts/10-2-double-cell-stack-foundation.md` — `src/double.asm`, `tests/double_tests.fth`, CCD-3 template, underflow helpers
  - `_bmad-output/implementation-artifacts/10-3-single-double-conversions.md` — `S>D` sign-extend idiom, `>NUMBER` memory-stash pattern, code-review findings on underflow helper counting
  - `_bmad-output/implementation-artifacts/10-4-double-precision-arithmetic-additive-sign-compare-mixed.md` — `DABS` / `DNEGATE` for SM/REM's DEFWORD body; `D+` for FM/MOD's correction step
  - `_bmad-output/implementation-artifacts/10-5-double-multiplication.md` — **closest precedent**; DEFCODE-inner + DEFWORD-wrapper pattern (UM* / M* / D*); `double_ip_stash` reuse; Makefile `$$` + `printf --` discipline; self-review trap table format
  - `_bmad-output/implementation-artifacts/10-1-ans-core-compliance-gap-survey-and-implementation-plan.md` — surveyor-authoritative scope
- **Source-tree anchors for pattern matching:**
  - `src/double.asm:1-534` — Stories 10.2 + 10.3 + 10.4 + 10.5 DEFCODEs / DEFWORDs = style template for all three new words
  - `src/double.asm:419-453` — `UM*` (DEFCODE) = closest structural template for `UM/MOD` (both shift-based inner-loop 16-iteration primitives; UM/MOD shifts the opposite direction and uses SBC-with-restore instead of ADD)
  - `src/double.asm:468-486` — `M*` (DEFWORD on UM* + sign tracking) = closest structural template for `SM/REM` (same pattern: DEFWORD wrapper compositing UM-word + sign-fixup)
  - `src/double.asm:510-534` — `D*` (DEFWORD on UM*) = structural reference for how to arrange a longer DEFWORD thread with register-stash discipline
  - `src/double.asm:540` — `double_ip_stash` cell; must remain file's final item; reuse for IP-stash in UM/MOD
  - `src/arithmetic.asm:86-106` — single-cell `*` shift-and-add loop; structural mirror of the shift-subtract direction
  - `src/arithmetic.asm:108-136` — `udivmod` subroutine (16/16 → 16-quot + 16-rem); **direct structural template for UM/MOD inner loop** — widen the dividend from 16 to 32 bits by pre-seeding the remainder register with d-hi
  - `src/arithmetic.asm:139-212` — `sdivmod` subroutine (single-cell signed symmetric division) — **structural template for SM/REM's sign-tracking** if the DEFCODE option is taken; conceptually identical, just wider dividend
  - `src/arithmetic.asm:219-266` — `/MOD`, `/`, `MOD` single-cell wrappers — **divide-by-zero baseline reference**; Task 7.5 compares new primitives against these
  - `src/system.asm:~278-362` — `check_underflow` / `_2` / `_3` / `_4` helpers (use `_3`; do NOT add new helpers)
  - `src/macros.asm:~26-94` — `NEXT` / `DEFCODE` / `DEFWORD` macros
- **Test-tree anchors:**
  - `tests/double_tests.fth:193-225` — Story 10.5 section = style template for Story 10.6 extension
  - `Makefile:4383-4578` — Stories 10.5 `test-repl` block (tests 502..525) = canonical entry-format template; closest precedent for numbering, escaping, banner style
- **Compliance doc:**
  - `docs/ans-forth-core-compliance.md:83-103` — Arithmetic §6.1 table (FM/MOD, SM/REM rows to flip)
  - `docs/ans-forth-core-compliance.md:114-120` — Double-Cell Division §6.1 table (UM/MOD row to flip; heading to update)
  - `docs/ans-forth-core-compliance.md:11-18` — §6.1 Summary table (increment Implemented by 3)
  - `docs/ans-forth-core-compliance.md:23-28` — Gap Classification table (decrement (b) "missing subsystem" by 3)
  - `docs/ans-forth-core-compliance.md:44` — Epic-10 closure plan row for Story 10.6
  - `docs/ans-forth-core-compliance.md:304-314` — "Double-cell operations" sub-heading and breakdown table
  - `docs/ans-forth-core-compliance.md:407` — "big gaps" observation paragraph
- **Project memories applicable to this story:**
  - `feedback_systematic_reference_check.md` — cross-reference DPANS94, not memory (AC #7, Task 1)
  - `feedback_standards_compliance.md` — investigate the standard; never rationalise (divide-by-zero baseline AC #8, Task 7.5)
  - `feedback_adversarial_review.md` — reviews MUST find things (Task 9; Story 10.5 precedent trap table)
  - `feedback_plain_qa_language.md` — diagnostic Completion Notes
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth scripts (AC #9, Task 5)
  - `feedback_design_upfront.md` — close the full §6.1 division sub-family in one story so Story 10.7 (pictured output) and Story 10.9 (`*/ */MOD`) consume a conformant division foundation from day one
  - `feedback_follow_process.md` — execute the workflow without asking for permission for obvious next steps
  - `feedback_defword_cf_label.md` — for SM/REM and FM/MOD DEFWORDs: `w_S_M_SLASH_REM_cf EQU w_S_M_SLASH_REM_body - 3` (pointing at `JP DOCOL`), not at the body. Precedent: `src/double.asm:385, 407, 471, 513` (DMAX, DMIN, M*, D*).
  - `project_tos_in_register.md` — BC-as-TOS discipline; DE=IP; DEPTH convention (AC #4, Dev Notes)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — model ID `claude-opus-4-7[1m]`

### Debug Log References

- Pre-edit build: `build/antforth.com` = 15606 bytes (Story 10.5 close-out).
- Post-edit build: `build/antforth.com` = 15812 bytes. Delta: **+206 bytes** (UM/MOD DEFCODE + `(?3)` guard + SM/REM / FM/MOD DEFWORDs + three dictionary headers). Story estimate 130–150 bytes; measured 206. Overshoot is largely the `(?3)` guard DEFCODE (name-string + header ≈ 20 bytes on top of the 6-byte body) and the 2 PICK ×2 cells per SM/REM (three cells per PICK = six bytes × 2 sites = 12 bytes beyond an idealised minimum). Within AC #13's ±50% tolerance; CCD-4 formal gate is Story 10.10.
- REPL test count: pre-edit 534 PASS → post-edit **558 PASS, 0 FAIL**. Added 24 entries numbered 526..549 in `Makefile`.
- `make test` (regression suite) passes; `make test-repl` passes.

### Completion Notes List

- **§-number verification.** `UM/MOD §6.1.2370`, `SM/REM §6.1.2214`, `FM/MOD §6.1.1561` confirmed against `docs/ans-forth-core-compliance.md` (Arithmetic table and Double-Cell Division table) and DPANS94 section numbering. All three words are §6.1 Core (not §8.6 bonus); the compliance-doc §6.1 increment is +3, §8.6 unaffected. Coverage moves 120/133 (90.2%) → 123/133 (92.5%).
- **UM/MOD algorithm.** DEFCODE at `src/double.asm:566`. Sixteen-iteration restoring shift-subtract. DE pre-seeds with `ud-hi`; HL holds `ud-lo` and doubles as quotient accumulator; each iteration shifts `[DE:HL]` left one bit via `ADD HL, HL / RL E / RL D`. The CF after `RL D` is the 33rd bit (remainder overflow from the shift); when set, the force path subtracts unconditionally and sets the quotient bit. Normal path trials `SBC HL, BC` (with `OR A` to clear CF); on success sets the quotient bit, on borrow restores via `ADD HL, BC`. `double_ip_stash` reused for DE across the DEFCODE body (same scratch cell used by D+, D-, D=, D<, DNEGATE, UM*).
- **SM/REM algorithm.** DEFWORD at `src/double.asm:638`. Body: `(?3) 2 PICK OVER XOR 0< >R   2 PICK 0< >R   ABS >R   DABS R>   UM/MOD   SWAP R>   IF NEGATE THEN   SWAP R>   IF NEGATE THEN`. Quotient-sign flag = sign(d-hi XOR n1); remainder-sign flag = sign(d-hi) — stashed on R-stack in that order, with `|n1|` pushed on top, so `DABS R>` recovers `|n1|` and leaves the two sign flags underneath for the post-UM/MOD fixups.
- **FM/MOD algorithm.** DEFWORD at `src/double.asm:691`. Body: `(?3) DUP >R   SM/REM   OVER   IF   R@ 2 PICK XOR 0<   IF   SWAP R@ + SWAP 1-   THEN   THEN   R> DROP`. Two nested guards: `rem ≠ 0` (outer), `sign(rem) XOR sign(n1) < 0` (inner). If both hold, decrement quotient and add divisor to remainder. Divisor stashed on R before SM/REM and recovered via two `R@`s; unconditionally discarded at end via `R> DROP`.
- **(?3) helper.** New DEFCODE at `src/double.asm:628` named `(?3)`. Single `CALL check_underflow_3 / NEXT` body. Threaded as the first opcode of SM/REM and FM/MOD so the 3-cell guard fires before any body word runs — none of the candidate body-starter words (`OVER`, `2DUP`, `DABS`, `DUP`) has an individual underflow-3 check. The `()`-wrapped name follows the existing internal-word convention (`(DO)`, `(LOOP)`, `(DOES>)`).
- **Quotient-overflow behaviour.** Per DPANS94 §3.2.2.1 / §6.1.2370, implementation-defined when quotient does not fit. antforth's algorithm produces the natural residual of the shift-subtract loop, not a clean "low 16 of the true quotient" truncation. Measured corner: `-1 -2 -1 UM/MOD` (true quotient 65536, overflows) yields `urem=32766 uquot=-32768` on antforth — documented here as the implementation-defined value. Not a defect; AC #7 permits any result.
- **Divide-by-zero empirical baseline.** Pre-edit `1 0 /` → `-1` (silently, no ABORT). Post-edit: `1 2 0 UM/MOD` → `(urem=2 uquot=-1)`; `0 -10 0 SM/REM` → `(-10 -1)`; `0 -10 0 FM/MOD` → `(-10 -2)` (FM/MOD applies its floor correction because rem=-10 and sign(rem) XOR sign(n1=0) is negative; this is the algorithm's natural behaviour, not new divide-by-zero handling). All three new primitives produce `uquot = -1` matching the single-cell `/` baseline. No new divide-by-zero check introduced; Epic 11 Story 11.4 is the authoritative migration site to `THROW -10`. **Discrepancy with epic spec:** `epics.md:566-568` describes the baseline as "ABORT pre-Epic-11" — measured behaviour is silent -1 quotient, not ABORT. Flagged here per `feedback_standards_compliance.md`; Story 11.4 should treat the real-today baseline as the migration source, not the aspirational ABORT in the epic text.
- **AC-text arithmetic errata identified during implementation.** Two AC test-case expected values drift from the real math; corrected in the Makefile and `tests/double_tests.fth`:
  1. AC #1's `-2 -1 -1 UM/MOD` is listed as `(-1 -1)` but the arithmetic is `$FFFEFFFF ÷ $FFFF = $FFFF quot rem $FFFE`, which prints as `-2 -1` (remainder then quotient). antforth returns `-2 -1`; Makefile test 532 uses this value.
  2. AC #2's `0 -10 3 SM/REM` claims `(-1 -3)` — but `0 -10` as a stacked double is `(high=0, low=$FFF6)` = unsigned 65526, not signed -10. (The story's own Task 9.1 adversarial-review note calls this trap out explicitly.) Test 534 uses the corrected input `-1 -10 3 SM/REM` which does give `(-1 -3)`. Same correction applied to AC #2's `-1 -5 10`, `-1 -32768 1`, and to AC #3 FM/MOD's `-1 -10 3`, `-1 -10 -3`, `-1 -9 3` cases.
- **Underflow coverage.** All three primitives use `check_underflow_3`. UM/MOD calls it directly from its DEFCODE entry; SM/REM and FM/MOD inherit via the `(?3)` guard opcode at body position 0. REPL tests 547–549 verify DEPTH=2 triggers the error and the REPL recovers.
- **CCD-3 compliance.** All three new dictionary entries carry the `; ANS Forth 1994 §<n>   <WORD>   — <note>` header comment and a stack-effect comment in the established `src/double.asm` house style (matches Stories 10.2 / 10.3 / 10.4 / 10.5). `(?3)` is internal scaffolding (not an ANS word) and is documented with a purpose comment only; no §-number applies.
- **Regression surface.** Edits confined to `src/double.asm`, `tests/double_tests.fth`, `Makefile`, `docs/ans-forth-core-compliance.md`. Single-cell `/` `MOD` `/MOD` untouched; `double_ip_stash` addition (UM/MOD is the 7th consumer) remains correct because the cell is never held across NEXT. Full `make test-repl` reports 558 PASS, 0 FAIL; `make test` passes.
- **Discrimination witness observed.** `-1 -10 3 SM/REM` → `(-1 -3)` vs `-1 -10 3 FM/MOD` → `(2 -4)` (Makefile tests 534 and 541). `0 10 -3 SM/REM` → `(1 -3)` vs `0 10 -3 FM/MOD` → `(-2 -4)` (tests 535 and 542). The floor correction is demonstrably exercised on both sign asymmetries.

### File List

- `src/double.asm` (modified — appended `UM/MOD` DEFCODE, `(?3)` DEFCODE helper, `SM/REM` DEFWORD, `FM/MOD` DEFWORD before the `double_ip_stash` cell; updated stash-consumer comment)
- `tests/double_tests.fth` (modified — appended Story 10.6 section with 24 scenarios: 7 UM/MOD + 7 SM/REM + 7 FM/MOD + 3 underflow)
- `Makefile` (modified — appended 24 REPL test entries numbered 526..549)
- `docs/ans-forth-core-compliance.md` (modified — Summary counts 120→123 / 13→10 / 90.2%→92.5%; Gap Classification "missing subsystem" 11→8; Arithmetic sub-heading 14→16 implemented / 5→3 missing; Arithmetic table FM/MOD & SM/REM rows flipped to Implemented; Double-Cell Division sub-heading 0→1 implemented / 1→0 missing; UM/MOD row flipped; Double-cell operations sub-heading 5→2 words remaining; breakdown table "Double / mixed division" marker added; Epic-10 closure plan row marked Complete; big-gaps paragraph updated; date header refreshed to 2026-04-22)
- `_bmad-output/implementation-artifacts/10-6-double-mixed-precision-division.md` (this file — tasks marked complete; Dev Agent Record filled; Status → review)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified — `10-6-double-mixed-precision-division` transitions ready-for-dev → in-progress → review)

### Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-22 | Implemented `UM/MOD` (DEFCODE), `SM/REM` (DEFWORD), `FM/MOD` (DEFWORD) + `(?3)` underflow-3 helper; 24 REPL tests added (526..549); compliance doc updated (90.2%→92.5%); divide-by-zero baseline documented; AC arithmetic errata flagged. | Dev agent (Claude Opus 4.7) |
| 2026-04-22 | Code-review pass: fixed Arithmetic heading count (16→17 implemented, 3→2 missing); refreshed stale "Arithmetic single-cell" observation paragraph; amended AC #1 / AC #2 / AC #3 / AC #10 text in-place for the `-2 -1 -1 UM/MOD → (-2 -1)` and `-1 -10 3 SM/REM / FM/MOD` errata dev had flagged in Completion Notes. Status → done. | Code-review agent (Claude Opus 4.7) |
