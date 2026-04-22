# Story 10.4: Double-precision arithmetic — additive, sign, compare, mixed (`D+`, `D-`, `DNEGATE`, `DABS`, `D=`, `D<`, `DMAX`, `DMIN`, `M+`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the full additive / sign / compare / mixed-precision suite of ANS Forth 1994 §8.6 Double-Number arithmetic words — `D+`, `D-`, `DNEGATE`, `DABS`, `D=`, `D<`, `DMAX`, `DMIN`, and `M+` —
so that once Story 10.3 has landed `S>D` and `D>S`, I can do 32-bit signed arithmetic, comparison, and mixed single-plus-double addition using the standard ANS vocabulary, and Stories 10.5 (multiplication) / 10.6 (division) / 10.7 (pictured output) build on a complete additive/compare/sign foundation.

## Acceptance Criteria

1. **Given** `D+ ( d1 d2 -- d3 )` per DPANS94 §8.6.1040 (verify §-number at implementation time per project memory `feedback_systematic_reference_check.md`) and the E10-D1 byte-order convention (`architecture.md:248-252` — low cell on TOS, high cell below), **When** `D+` executes with two double-cells on the stack (`x1 x2 x3 x4` where `x4` = BC = low of `d2` and `x3, x2, x1` are on SP), **Then** the result `d3 = d1 + d2` (32-bit add, truncating on overflow) is left on the stack as `( x5 x6 )` with `x6` = low cell = TOS = `(x2 + x4) mod 2^16` and `x5` = high cell = second-on-stack = `(x1 + x3 + carry_from_low) mod 2^16`. Boundary values verified: `0 0 0 0 D+` → `( 0 0 )`; `0 $FFFF 0 1 D+` → `( 1 0 )` (carry from low ripples to high); `$7FFF $FFFF 0 1 D+` → `( $8000 0 )` (32-bit signed overflow — silent truncation, ANS-conformant); `-1 -1 0 1 D+` (= `$FFFFFFFF + 1`) → `( 0 0 )` (full 32-bit wrap).

2. **Given** `D- ( d1 d2 -- d3 )` per DPANS94 §8.6.1050, **When** executed, **Then** `d3 = d1 - d2` with 32-bit borrow propagation. Boundary values: `0 1 0 1 D-` → `( 0 0 )`; `0 0 0 1 D-` → `( -1 -1 )` (= `$FFFFFFFF`, underflow wraps); `0 $8000 0 1 D-` → `( 0 $7FFF )` (low-cell subtract, no borrow into high); `-1 -1 0 1 D-` → `( -1 -2 )`.

3. **Given** `DNEGATE ( d -- -d )` per DPANS94 §8.6.1230, **When** executed, **Then** the double is replaced by its 32-bit two's-complement negation. `0 0 DNEGATE` → `( 0 0 )`; `0 1 DNEGATE` → `( -1 -1 )` (= `-1` in 32-bit signed); `-1 -1 DNEGATE` → `( 0 1 )`; `$8000 0 DNEGATE` → `( $8000 0 )` (the unique-fixed-point case — most negative 32-bit number negates to itself, same as single-cell `NEGATE $8000`). BC-as-TOS exit contract maintained.

4. **Given** `DABS ( d -- ud )` per DPANS94 §8.6.1160, **When** executed, **Then** the double's absolute value is returned: if the high cell's sign bit is clear (`d ≥ 0`), `d` is returned unchanged; if set, `DNEGATE` is applied. Boundary values: `0 0 DABS` → `( 0 0 )`; `0 5 DABS` → `( 0 5 )`; `-1 -5 DABS` → `( 0 5 )`; `$8000 0 DABS` → `( $8000 0 )` (fixed-point case — `DABS` of most-negative is most-negative, as with single-cell `ABS`).

5. **Given** `D= ( d1 d2 -- flag )` per DPANS94 §8.6.1120, **When** executed, **Then** returns `flag = -1` (true = `$FFFF`) if `d1 = d2` bit-for-bit in both cells, else `flag = 0`. Boundary values: `0 0 0 0 D=` → `-1`; `0 1 0 1 D=` → `-1`; `0 1 0 2 D=` → `0` (low cells differ); `1 0 2 0 D=` → `0` (high cells differ); `-1 -1 -1 -1 D=` → `-1`. Exit contract: BC holds the flag on TOS; SP has no cells of d1/d2 remaining (consumed 4, produced 1).

6. **Given** `D< ( d1 d2 -- flag )` per DPANS94 §8.6.1110, **When** executed, **Then** returns `flag = -1` if `d1 < d2` as a **signed** double-cell comparison, else `flag = 0`. Ordering: compare high cells as signed 16-bit; if equal, compare low cells as **unsigned** 16-bit. Boundary values: `0 0 0 1 D<` → `-1` (d1 = 0 < d2 = 1); `0 1 0 0 D<` → `0`; `-1 -1 0 0 D<` → `-1` (d1 = −1 < d2 = 0, signed high-cell compare); `0 0 -1 -1 D<` → `0` (d2 = −1 < d1 = 0); `0 $FFFF 1 0 D<` → `-1` (d1 = $FFFF = 65535 low+0 high; d2 = $10000 = 65536; signed high cell compare: 0 < 1); `1 0 1 0 D<` → `0` (equal). **Signed-high / unsigned-low is the single most common correctness trap** — verify against ANS §8.6.1110 text, not from memory.

7. **Given** `DMAX ( d1 d2 -- d )` per DPANS94 §8.6.1210 and `DMIN ( d1 d2 -- d )` per §8.6.1220, **When** executed, **Then** return the larger / smaller double-cell value using `D<` semantics. `DMAX`: `0 1 0 2 DMAX` → `( 0 2 )`; `-1 -1 0 1 DMAX` → `( 0 1 )`. `DMIN`: `0 1 0 2 DMIN` → `( 0 1 )`; `-1 -1 0 1 DMIN` → `( -1 -1 )`. Implementation is permitted to share a `D<`-equivalent internal path or call `w_D_LESS_cf` (avoid duplicating signed-compare logic).

8. **Given** `M+ ( d1 n -- d2 )` per DPANS94 §8.6.1830 (the PRD text at `prd.md:387-389` cites `§8.6.1.1830` — confirm the canonical section number at write time; the compliance doc `docs/ans-forth-core-compliance.md:369` records `8.6.1830`), **When** executed with `n = BC` (TOS) and SP holding `x2, x1` (low, high of `d1`), **Then** the double result `d2 = d1 + n` is produced with `n` sign-extended to a full 32-bit value before the add: `x6 = (x2 + n) mod 2^16`; `x5 = (x1 + sign_ext_high(n) + carry_from_low) mod 2^16`, where `sign_ext_high(n) = 0` if `n ≥ 0` and `$FFFF` if `n < 0`. Boundary values: `0 0 1 M+` → `( 0 1 )` (positive add); `0 0 -1 M+` → `( -1 -1 )` (sign-extended negative rolls both cells); `0 $FFFF 1 M+` → `( 1 0 )` (carry ripples from low into high); `0 0 -5 M+` → `( -1 -5 )`; `-1 -5 -1 M+` → `( -1 -6 )` (negative + negative stays negative, no borrow into high).

9. **Given** the BC-as-TOS convention (project memory `project_tos_in_register.md`), **When** each of the nine words is implemented, **Then** on entry BC holds the top-most single cell of the input signature (low cell of `d2` for binary D-ops; low cell of `d` for unary D-ops; `n` for `M+`) and on exit BC holds the new top-most single cell (low cell of `d3` for D+/D-/DMAX/DMIN, low cell of `-d` for DNEGATE / `ud` for DABS, the flag for D=/D<, low cell of `d2` for M+). `DE = IP` is preserved across every word — either left untouched or bracketed by `EXX` / memory-stash per the Epic 7/8 convention (precedents: `src/stack_ops.asm:111-171` ROLL for EXX-sandwich; `src/strings.asm:346-351` `>NUMBER` for memory-stash).

10. **Given** stack-underflow discipline inherited from Epic 1 and tightened during the Story 10.3 code review (`check_underflow_N` counts **total user items including BC**, per `src/system.asm:293-301` comments — `N` = total cells consumed, not SP-only cells), **When** a §8.6 primitive is invoked with insufficient depth, **Then** it calls the matching `check_underflow_N` helper:

    | Word | Cells consumed | Helper |
    |---|---|---|
    | `D+` | 4 (`d1` + `d2`) | `check_underflow_4` |
    | `D-` | 4 | `check_underflow_4` |
    | `DNEGATE` | 2 (`d`) | `check_underflow_2` |
    | `DABS` | 2 | `check_underflow_2` |
    | `D=` | 4 | `check_underflow_4` |
    | `D<` | 4 | `check_underflow_4` |
    | `DMAX` | 4 | `check_underflow_4` |
    | `DMIN` | 4 | `check_underflow_4` |
    | `M+` | 3 (`d1` + `n`) | `check_underflow_3` |

    No new helpers are introduced — Story 10.2 landed `_3` and `_4`. Pre-Epic-11 behaviour (ABORT + stack-underflow diagnostic + REPL recovery) is preserved bit-identically. Epic 11 will migrate to `THROW -4` later — **do NOT pre-migrate in this story**.

11. **Given** architecture decision E10-D3 (assembly for hot primitives; `architecture.md:260-264`) and the source-file organisation table (`architecture.md:434-447`), **When** the nine words are implemented, **Then** they **all land in `src/double.asm`**, appended after `w_D_TO_S` (currently the file's last word at `src/double.asm:173`). Suggested source ordering inside the file (style, not mandate): `M+` → `D+` → `D-` → `DNEGATE` → `DABS` → `D=` → `D<` → `DMAX` → `DMIN` (builds complexity incrementally; `DMAX`/`DMIN` naturally follow `D<`). No other source files are modified for implementation; `src/antforth.asm`'s `INCLUDE "double.asm"` already pulls the file in.

12. **Given** CCD-3 Standards-Citation Discipline (`architecture.md:206-216`, NFR17 at `prd.md:478`) and the format template established by Stories 10.2 / 10.3 (`src/double.asm:15-20,43-45,65-70,82-87,97-103,121-127,146-151,164-172`), **When** each DEFCODE is written, **Then** its implementation carries (a) a one-line `; ANS Forth 1994 §<section>   <word>   — <short semantic note>` comment in the Story-10.2 template format and (b) a stack-effect comment block on the DEFCODE header line in the existing style. **§-numbers are verified against DPANS94 / forth-standard.org at implementation time** — do NOT enumerate from memory (per `feedback_systematic_reference_check.md`; reinforced by Story 10.2's M1 finding and Story 10.3's self-review gap). The expected numbers to verify: `D+ §8.6.1040`, `D- §8.6.1050`, `DNEGATE §8.6.1230`, `DABS §8.6.1160`, `D= §8.6.1120`, `D< §8.6.1110`, `DMAX §8.6.1210`, `DMIN §8.6.1220`, `M+ §8.6.1830`.

13. **Given** the REPL-test-preferred discipline (project memory `feedback_repl_tests_preferred.md`, NFR16 at `prd.md:477`) and the Story-10.2 / 10.3 house style (`tests/double_tests.fth`), **When** tests are written, **Then** (a) new scenarios are **appended** to `tests/double_tests.fth` under a new section header `\ === Story 10.4 double-cell arithmetic (additive / sign / compare / mixed) ===`, matching the existing style (one-line Forth expression + `\ expect: <fragment>` comment), with per-word sub-headers; and (b) the corresponding `test-repl` entries are added to the `Makefile` as the authoritative runners, using the established `@OUTPUT=$$(printf … | $(IZCPM) $(TARGET)) && grep -q` pattern — continuing the numbering from the final REPL test currently in `Makefile` (Story 10.3 block ended at **449** after the code-review follow-ups; the new Story-10.4 block starts at **450**).

14. **Given** coverage must exhaust ACs #1–#8, **When** `make test-repl` is run, **Then** the new test block includes **at minimum** (numbering suggested, final is dev's choice):

    **`D+` (AC #1) — 4 tests:**
    - `0 0 0 0 D+ .S` → `<2> 0 0` (zero + zero)
    - `0 5 0 7 D+ .S` → `<2> 0 12` (positive simple — d1=5, d2=7, sum=12, assert via `2DROP .S`)
    - `0 $FFFF 0 1 D+ DECIMAL .S` → `<2> 1 0` in decimal (low-cell carry ripples)
    - `-1 -1 0 1 D+ .S` → `<2> 0 0` (full 32-bit wrap, $FFFFFFFF + 1 → 0)

    **`D-` (AC #2) — 4 tests:**
    - `0 10 0 4 D- .S` → `<2> 0 6`
    - `0 4 0 10 D- .S` → `<2> -1 -6` (negative result, borrow into high)
    - `0 0 0 1 D- .S` → `<2> -1 -1` (`$FFFFFFFF` = `-1` as signed double)
    - `1 0 0 1 D- .S` → `<2> 0 -1` (`$10000 - 1 = $FFFF` with high cell 0)

    **`DNEGATE` (AC #3) — 4 tests:**
    - `0 0 DNEGATE .S` → `<2> 0 0`
    - `0 1 DNEGATE .S` → `<2> -1 -1` (= $FFFFFFFF = -1 in signed double)
    - `-1 -1 DNEGATE .S` → `<2> 0 1`
    - `0 $8000 DNEGATE HEX .S DECIMAL` → `<2> FFFF 8000 ` in hex (checks the single-cell case isn't confused)

    **`DABS` (AC #4) — 4 tests:**
    - `0 0 DABS .S` → `<2> 0 0`
    - `0 5 DABS .S` → `<2> 0 5` (positive unchanged)
    - `-1 -5 DABS .S` → `<2> 0 5` (negates)
    - `-1 0 DABS .S` → `<2> 0 0` (`d = $FFFF0000` → magnitude = `$0001 0000`? no wait — d = `(-1 << 16) | 0` = `$FFFF0000` as unsigned = `-65536` signed; DABS → `$00010000` → `( 1 0 )`); fix the test shape: `-1 0 DABS .S` → `<2> 1 0`.

    **`D=` (AC #5) — 5 tests:**
    - `0 0 0 0 D= .` → `-1` (equal zeros)
    - `0 5 0 5 D= .` → `-1` (equal non-zeros)
    - `0 5 0 6 D= .` → `0` (low cells differ)
    - `1 5 2 5 D= .` → `0` (high cells differ)
    - `-1 -1 -1 -1 D= .` → `-1` (all-bits-set equality)

    **`D<` (AC #6) — 7 tests (SIGNED compare — the trap case from AC #6):**
    - `0 0 0 1 D< .` → `-1` (0 < 1)
    - `0 1 0 0 D< .` → `0` (1 < 0 false)
    - `-1 -1 0 0 D< .` → `-1` (−1 < 0, signed high-cell compare; this is the trap)
    - `0 0 -1 -1 D< .` → `0` (0 < −1 false)
    - `0 $FFFF 1 0 D< DECIMAL .` → `-1` in decimal (high-cell compare: 0 < 1, so low cells don't matter)
    - `1 0 1 0 D< .` → `0` (equal, not less-than)
    - `-1 0 -1 1 D< .` → `-1` (high cells equal at −1, low cells compared **unsigned**: 0 < 1)

    **`DMAX` / `DMIN` (AC #7) — 4 tests each:**
    - `0 5 0 7 DMAX .S` → `<2> 0 7`
    - `-1 -1 0 0 DMAX .S` → `<2> 0 0` (0 > −1)
    - `0 5 0 5 DMAX .S` → `<2> 0 5` (equal → either, ANS says implementation-defined which copy but value must be the common value)
    - `0 $FFFF 1 0 DMAX DECIMAL .S` → `<2> 1 0` (positive larger of two large positives)
    - `0 5 0 7 DMIN .S` → `<2> 0 5`
    - `-1 -1 0 0 DMIN .S` → `<2> -1 -1` (−1 < 0)
    - `0 5 0 5 DMIN .S` → `<2> 0 5` (equal)
    - `0 $FFFF 1 0 DMIN DECIMAL .S` → `<2> 0 -1` (0:$FFFF = 65535 < 65536 in signed double)

    **`M+` (AC #8) — 5 tests:**
    - `0 0 1 M+ .S` → `<2> 0 1` (double 0 + single 1)
    - `0 0 -1 M+ .S` → `<2> -1 -1` (double 0 + single −1; sign-extended high cell rolls to $FFFF)
    - `0 $FFFF 1 M+ DECIMAL .S` → `<2> 1 0` (low-cell carry ripples)
    - `0 0 -5 M+ .S` → `<2> -1 -5`
    - `-1 -5 -1 M+ .S` → `<2> -1 -6` (negative + negative; high cell −1 + sign_ext(−1)=−1 + carry from low=0 → still −1 because low add didn't carry)

    **Underflow recovery (AC #10) — one test per word at its minimum-insufficient depth:**
    - 9 tests total: `D+` DEPTH<4 (test at DEPTH=3), `D-` DEPTH<4 (DEPTH=3), `DNEGATE` DEPTH<2 (DEPTH=1), `DABS` DEPTH<2 (DEPTH=1), `D=` DEPTH<4 (DEPTH=3), `D<` DEPTH<4 (DEPTH=3), `DMAX` DEPTH<4 (DEPTH=3), `DMIN` DEPTH<4 (DEPTH=3), `M+` DEPTH<3 (DEPTH=2). Each must produce `? Stack underflow` + `ok` (matching Story 10.3 pattern, `Makefile:3913-3920` and 446-448).

    Total estimated test count: **46** (4+4+4+4+5+7+4+4+5+9 = 50, or dev can trim overlapping boundaries down to ~46). Block range **450..495** (adjust if count differs).

15. **Given** NFR9 (zero regressions `prd.md:464`) and FR46 (all Epic 1–8 REPL tests continue to pass `prd.md:435`), **When** the full test suite (`make test` + `make test-repl`) is run after this story's changes, **Then** every pre-existing test still passes, the new Story-10.4 tests all pass, and the final REPL test count increases by exactly the number of new entries added — no hidden regressions, no baseline drift. Post-Story-10.3 + code-review-follow-ups baseline is **449 PASS** — the new count is `449 + <new entries>` with 0 FAIL. No word modified outside `src/double.asm` means the regression surface is narrow; spot-check `S>D D>S >NUMBER` (Story 10.3), `2@ 2! 2DUP 2DROP 2SWAP 2OVER` (Story 10.2), and the single-cell arithmetic baseline (`+ - NEGATE ABS = < MAX MIN`) — any byte-for-byte output change in those words is a regression.

16. **Given** NFR10 (100% §6.1 Core compliance target — `prd.md:461-476`) and the explicit scope note in `docs/ans-forth-core-compliance.md:355-375` that **all nine Story-10.4 words are §8.6 Double-Number bonus, not §6.1 Core**, **When** this story completes, **Then** the compliance doc's §8.6 table (`docs/ans-forth-core-compliance.md:359-374`) is updated: rows for `D+`, `D-`, `DNEGATE`, `DABS`, `D=`, `D<`, `DMAX`, `DMIN`, `M+` (currently all marked `10.4`) flip to `Implemented (double.asm:<line>)`. The `(13 §8.6 additions planned; none on the §6.1 critical path.)` footer stays factually correct — 9 of 13 §8.6 words become Implemented after this story (the remaining 4 — `D*`, `D.`, `D.R`, and `D>S` which is already done — belong to Stories 10.5 / 10.8). The §6.1 Core summary table at the top of the file (`ans-forth-core-compliance.md:11-18`) **does not change** — no §6.1 words are added or removed; the 118 / 133 = 88.7% figure is preserved. The Epic-10 closure plan row for 10.4 (`ans-forth-core-compliance.md:42`) updates from `0 §6.1 | All §8.6 bonus (D+ D- DNEGATE DABS D= D< DMAX DMIN M+)` to `0 §6.1 ✓ | §8.6 bonus Complete (all 9 words Implemented)`.

17. **Given** CCD-4 (Per-Epic Benchmark Gate, `architecture.md:218-226`) sets the benchmark/size-delta gate at **Story 10.10**, not here, **When** this story completes, **Then** the ROM size delta is recorded in the Completion Notes (informational — no gate). Rough estimate: `D+` ~18 bytes + `D-` ~18 + `DNEGATE` ~16 + `DABS` ~10 + `D=` ~22 + `D<` ~30 + `DMAX` ~14 (if shares `D<`) + `DMIN` ~14 + `M+` ~30 + dictionary headers (9 × ~12 bytes) ~108 = **~280 bytes** net. Acceptable margin: ±50%. Story 10.10 measures formally.

## Tasks / Subtasks

- [x] **Task 1 — Verify §-numbers against DPANS94 + scope sanity** (AC: #1–#8, #12, #16)
  - [x] 1.1 Verify `D+ §8.6.1040`, `D- §8.6.1050`, `DNEGATE §8.6.1230`, `DABS §8.6.1160`, `D= §8.6.1120`, `D< §8.6.1110`, `DMAX §8.6.1210`, `DMIN §8.6.1220`, `M+ §8.6.1830` by cross-reference to `docs/ans-forth-core-compliance.md:361-369` and (if unsure) forth-standard.org. **Do not enumerate from memory.**
  - [x] 1.2 Confirm all nine words are §8.6 Double-Number wordset bonus, not §6.1 Core — compliance Summary table at `ans-forth-core-compliance.md:11-18` should be unchanged by this story.
  - [x] 1.3 Confirm CCD-3 template matches `src/double.asm:19` / `44` / `69` / `86` / `101` / `126` / `150` / `171` (Stories 10.2 + 10.3 house style).

- [x] **Task 2 — Implement `M+` in `src/double.asm`** (AC: #8, #9, #10, #11, #12)
  - [x] 2.1 Append DEFCODE block after `w_D_TO_S` (currently ends at `src/double.asm:178`). Place `M+` **first** in the story's source ordering because its sign-extension idiom is a building block that D+ borrows; implementing it first establishes the register-dance pattern for the rest.
  - [x] 2.2 Body: save IP to a local scratch word (or EXX-bracket; dev's choice — memory-stash is the 10.3 `>NUMBER` pattern, EXX is the 10.2 `2SWAP` pattern). Sign-extend `n` using `LD A, B / RLA / SBC A, A` (same idiom as `S>D` at `src/double.asm:157-160`).
  - [x] 2.3 `CALL check_underflow_3` at the top — **this is DEPTH ≥ 3, total user items = BC + 2 SP cells** (AC #10).
  - [x] 2.4 CCD-3 comment: `; ANS Forth 1994 §8.6.1830   M+   — mixed single+double add (sign-extended)`.
  - [x] 2.5 Stack-effect comment on header line: `; M+ ( d n -- d )`.

- [x] **Task 3 — Implement `D+` in `src/double.asm`** (AC: #1, #9, #10, #11, #12)
  - [x] 3.1 DEFCODE block after `w_M_PLUS`. Use the same save-IP idiom chosen for `M+` (consistency).
  - [x] 3.2 Low-cell add: `ADD HL, BC` with HL loaded from `x2` and BC holding `x4`. Preserve carry across the subsequent POP (POP preserves flags). Then `ADC HL, BC` with BC reloaded from `x1` (high of `d1`) and HL holding `x3` — or the reverse — produces the high cell with carry propagated.
  - [x] 3.3 `CALL check_underflow_4`.
  - [x] 3.4 CCD-3 comment: `; ANS Forth 1994 §8.6.1040   D+   — double-cell add`.
  - [x] 3.5 Stack-effect comment: `; D+ ( d1 d2 -- d3 )`.

- [x] **Task 4 — Implement `D-` in `src/double.asm`** (AC: #2, #9, #10, #11, #12)
  - [x] 4.1 DEFCODE block after `w_D_PLUS`. Structurally identical to `D+` but with `OR A / SBC HL, BC` for the low-cell subtract (`OR A` clears carry before the first `SBC`) and `SBC HL, BC` for the high cell.
  - [x] 4.2 `CALL check_underflow_4`.
  - [x] 4.3 CCD-3 comment: `; ANS Forth 1994 §8.6.1050   D-   — double-cell subtract`.
  - [x] 4.4 Stack-effect comment: `; D- ( d1 d2 -- d3 )`.

- [x] **Task 5 — Implement `DNEGATE` in `src/double.asm`** (AC: #3, #9, #10, #11, #12)
  - [x] 5.1 DEFCODE block after `w_D_MINUS`. Body: `d' = 0 - d` using `OR A / LD HL, 0 / SBC HL, BC` for low and `LD HL, 0 / SBC HL, <high>` for high. Note: `SBC HL, BC` after the first `SBC HL, BC` will propagate the borrow correctly because the second `SBC` preserves carry input from the first if no flag-affecting ops intervene.
  - [x] 5.2 Alternative: invert both cells (`LD A, C / CPL / LD C, A` etc.) and add 1 with carry — functionally equivalent, roughly same size.
  - [x] 5.3 `CALL check_underflow_2`.
  - [x] 5.4 CCD-3 comment: `; ANS Forth 1994 §8.6.1230   DNEGATE   — double-cell two's-complement negate`.
  - [x] 5.5 Stack-effect comment: `; DNEGATE ( d -- -d )`.

- [x] **Task 6 — Implement `DABS` in `src/double.asm`** (AC: #4, #9, #10, #11, #12)
  - [x] 6.1 DEFCODE block after `w_D_NEGATE`. Body: peek high cell (not BC — BC is low); if bit 7 of its high byte is clear, fall through (NEXT); else `JP w_D_NEGATE_cf` (tail-call to DNEGATE skipping its own `check_underflow_2`, or re-check — the re-check is a cheap ~20 cycles and is safer than a JP past the guard).
  - [x] 6.2 Tail-call approach: after checking sign, if negative, `JP w_D_NEGATE_cf`. If positive, `NEXT`. The re-check-underflow cost is 1 extra `CALL check_underflow_2` (~30 cycles) — negligible.
  - [x] 6.3 `CALL check_underflow_2` at DABS entry.
  - [x] 6.4 CCD-3 comment: `; ANS Forth 1994 §8.6.1160   DABS   — double-cell absolute value`.
  - [x] 6.5 Stack-effect comment: `; DABS ( d -- ud )`.

- [x] **Task 7 — Implement `D=` in `src/double.asm`** (AC: #5, #9, #10, #11, #12)
  - [x] 7.1 DEFCODE block after `w_D_ABS`. Body: POP `x3`, POP `x2`, POP `x1`; compare `x1 == x3` (high cells) and `x2 == x4 = BC` (low cells); if both equal, result = `$FFFF` (TRUE) else `0`.
  - [x] 7.2 Suggested idiom: `OR A / SBC HL, DE` for 16-bit equality on high cells (Z=1 if equal), then AND-merge with low-cell equality check. Final result written to BC.
  - [x] 7.3 `CALL check_underflow_4`.
  - [x] 7.4 CCD-3 comment: `; ANS Forth 1994 §8.6.1120   D=   — double-cell equality → flag`.
  - [x] 7.5 Stack-effect comment: `; D= ( d1 d2 -- flag )`.

- [x] **Task 8 — Implement `D<` in `src/double.asm`** (AC: #6, #9, #10, #11, #12)
  - [x] 8.1 DEFCODE block after `w_D_EQUALS`. Body per ANS §8.6.1110: signed compare of high cells; if equal, unsigned compare of low cells. The simplest Z80 idiom is `SBC HL, DE` with **signed overflow correction** via the P/V flag:
    ```
    ; HL = x1, DE = x3 (high cells). Compute HL - DE and look at sign+overflow:
    OR    A                     ; clear CF
    SBC   HL, DE                ; HL = x1 - x3; S, Z, P/V set
    JP    PE, .dlt_overflow     ; P/V=1 means signed overflow occurred
    ; no overflow: S flag directly indicates sign of difference
    JP    M,  .dlt_true         ; S=1 ⇒ x1 < x3 ⇒ true
    JR    NZ, .dlt_false        ; S=0 and Z=0 ⇒ x1 > x3 ⇒ false
    ; fall through: Z=1 means x1 == x3 → compare low cells unsigned
    ; ...
    .dlt_overflow:
    ; When signed overflow occurred, the sign of (x1 - x3) is inverted. So:
    JP    P, .dlt_true          ; S=0 after overflow means actually x1 < x3
    JR    .dlt_false
    ```
    The overflow correction is **the single most error-prone spot** in this story. Reference: Zaks "Programming the Z80" signed-compare-via-SBC idiom; also the antforth `<` implementation in `src/arithmetic.asm` (apply the same pattern to 16-bit cells).
  - [x] 8.2 Alternative: compute the 32-bit subtract `d1 - d2` as full double-precision and look at the sign bit of the high cell of the result — if set and no signed overflow happened, `d1 < d2`. Equivalent in cost, may be cleaner.
  - [x] 8.3 `CALL check_underflow_4`.
  - [x] 8.4 CCD-3 comment: `; ANS Forth 1994 §8.6.1110   D<   — double-cell signed less-than → flag`.
  - [x] 8.5 Stack-effect comment: `; D< ( d1 d2 -- flag )`.

- [x] **Task 9 — Implement `DMAX` and `DMIN` in `src/double.asm`** (AC: #7, #9, #10, #11, #12)
  - [x] 9.1 DEFCODE blocks after `w_D_LESS`. Simplest impl: `DMAX` and `DMIN` call `D<` internally, then swap-and-drop based on the flag.
  - [x] 9.2 Option A (calling `D<`): body does `2OVER 2OVER D<` (peek both pairs, compare), `IF 2SWAP THEN 2DROP` pattern — but this requires colon compilation, not assembly. For assembly, inline a `D<`-equivalent subroutine that returns a flag in A, then branch on it.
  - [x] 9.3 Option B (inline comparison): duplicate the signed-high / unsigned-low compare logic from `D<` without the flag push/pop overhead, branch directly to "keep d1" or "keep d2" paths.
  - [x] 9.4 Option C (DEFWORD in Forth): compile `DMAX` / `DMIN` as DEFWORDs on top of `2OVER 2OVER D< IF 2SWAP THEN 2DROP` — matches E10-D3's permission for thin-wrapper words. This is the cleanest path and shortest to write; performance cost is acceptable for non-hot-path words. **Recommended.**
  - [x] 9.5 `CALL check_underflow_4` (only needed if Option A/B; DEFWORD inherits the checks from `2OVER` / `D<` / `2SWAP` / `2DROP`).
  - [x] 9.6 CCD-3 comments: `; ANS Forth 1994 §8.6.1210   DMAX   — double-cell max (signed)` and `; ANS Forth 1994 §8.6.1220   DMIN   — double-cell min (signed)`.
  - [x] 9.7 Stack-effect comments: `; DMAX ( d1 d2 -- d )`, `; DMIN ( d1 d2 -- d )`.

- [x] **Task 10 — Extend `tests/double_tests.fth`** (AC: #13, #14)
  - [x] 10.1 Append section header: `\ === Story 10.4 double-cell arithmetic (additive / sign / compare / mixed) ===`.
  - [x] 10.2 Sub-section headers per word-group: `\ --- D+ ---`, `\ --- D- ---`, `\ --- DNEGATE ---`, `\ --- DABS ---`, `\ --- D= ---`, `\ --- D< ---`, `\ --- DMAX / DMIN ---`, `\ --- M+ ---`, `\ --- underflow recovery ---`.
  - [x] 10.3 Forth one-liners with `\ expect: <fragment>` comments for every AC #14 scenario.
  - [x] 10.4 For multi-cell outputs, use `2DROP .S` pattern to surface a stable `.S` fragment (as in Story 10.3 tests 440/441).

- [x] **Task 11 — Wire up Makefile `test-repl` entries** (AC: #13, #14, #15)
  - [x] 11.1 Section banner: `@# --- Story 10.4 double-cell arithmetic (450..<end>) ---`.
  - [x] 11.2 Canonical `printf | $(IZCPM) $(TARGET) | grep -q` pattern (see tests 423..449 for the exact template).
  - [x] 11.3 Numbering: start at **450** (Story 10.3 closed at 449 post-code-review). Use contiguous integer numbering; no gaps.
  - [x] 11.4 For `D<` / `DMAX` / `DMIN` the signed-vs-unsigned boundary tests (AC #14) must be explicit — include the `-1 -1 0 0 D<` test case that verifies signed high-cell comparison.
  - [x] 11.5 Underflow tests: one per word at its minimum insufficient depth (DEPTH=N-1 where N is the helper number). Follow the Story 10.3 pattern at `Makefile:3889-3920`.

- [x] **Task 12 — Regression verification** (AC: #15, #17)
  - [x] 12.1 `make clean && make test` — must PASS.
  - [x] 12.2 `make test-repl` — must show `N` unique test numbers PASS, 0 FAIL, where `N = 449 + <count of new entries>`.
  - [x] 12.3 Spot-check regression on adjacent words: `S>D`, `D>S`, `>NUMBER`, `2@`, `2!`, `+`, `-`, `NEGATE`, `ABS`, `=`, `<`, `MAX`, `MIN` — all output byte-identical to pre-story baseline.
  - [x] 12.4 ROM size delta: record pre-edit and post-edit `.com` size in Completion Notes (informational per AC #17; CCD-4 gate is 10.10).

- [x] **Task 13 — Update `docs/ans-forth-core-compliance.md`** (AC: #16)
  - [x] 13.1 In the §8.6 Double-Number table (`ans-forth-core-compliance.md:359-373`), flip the `Story` column from `10.4` to `Implemented (`double.asm:<line>`)` for each of: `D+`, `D-`, `DNEGATE`, `DABS`, `D=`, `D<`, `DMAX`, `DMIN`, `M+`.
  - [x] 13.2 Do NOT touch the top-level §6.1 Summary table (`line 11-18`) — no §6.1 words are added (all nine Story-10.4 words are §8.6 bonus).
  - [x] 13.3 Update the Epic-10 closure plan row for Story 10.4 at `line 42`: `0 §6.1 ✓ | §8.6 bonus Complete (all 9 words Implemented)`.
  - [x] 13.4 The `(13 §8.6 additions planned; none on the §6.1 critical path.)` footer at `line 375` stays — 9 of the 13 entries are now marked Implemented (plus `D>S` from 10.3 = 10 of 13); the remaining 3 (`D*`, `D.`, `D.R`) are scheduled for Stories 10.5 and 10.8.

- [x] **Task 14 — Self-review (adversarial) + code-review handoff** (AC: all)
  - [x] 14.1 Before marking the story complete, run an **adversarial self-review** looking specifically for:
    - Off-by-one `check_underflow_N` mismatches (Story 10.3 had one — **this is the expected trap**; recompute N per-word from the AC #10 table, don't guess).
    - `D<` signed-vs-unsigned logic error (Story 10.4's characteristic trap — test `-1 -1 0 0 D<` and `-1 0 -1 1 D<` **both**, not just one).
    - `DNEGATE` $8000:0000 fixed-point case — must round-trip to itself per ANS.
    - `M+` sign-extension failing for negative singles crossing the high-cell boundary.
    - Missing CCD-3 §-number citations, drifted §-numbers, or stack-effect comments.
    - Regressions in single-cell `+ - NEGATE ABS = < MAX MIN` (those words share mental pattern with the new ones and can be accidentally altered in cross-editing).
  - [x] 14.2 Fill Completion Notes with plain diagnostic prose (per memory `feedback_plain_qa_language.md`) — measured values, gates, reasons, no florid framing.
  - [x] 14.3 Different-LLM second-pass review recommended — `/bmad-bmm-code-review 10.4` is the natural hook. Stories 10.2 and 10.3 both caught real defects in that pass (10.3's code-review pass caught an off-by-one underflow; Story 10.4's `D<` signed compare is a similar trap-rich target).

## Dev Notes

### Story Purpose and Epic-10 Position

Story 10.4 is the **third implementation story in Epic 10** and the arithmetic core of the double-cell subsystem. Three things fall out of this story that subsequent stories depend on:

1. **`D+` and `D-` existence** — required by every double-cell arithmetic word that doesn't synthesise its own carry-propagation path. Stories 10.5 (`M*`, `UM*`, `D*`) and 10.6 (`FM/MOD`, `SM/REM`, `UM/MOD`) both build on `D+` / `D-` for the shift-and-add / shift-and-subtract inner loops.
2. **`M+`** — used by Story 10.7's pictured numeric output inner loop when accumulating mixed double+digit intermediate values.
3. **`D<` / `DMAX` / `DMIN`** — naturally clump with the compare family; getting the signed-vs-unsigned semantics right here means the pictured-output right-alignment logic (Story 10.8's `D.R`) can rely on a clean `D<`.

This story also completes **9 of the 13 planned §8.6 Double-Number bonus additions** — after 10.4, only `D*` (Story 10.5) and the two print words `D.` / `D.R` (Story 10.8) remain.

### Architectural Decisions That Apply to This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§206-216 CCD-3 (Standards-Citation Discipline):** every word cites its DPANS94 §-number. Format is non-negotiable — match Stories 10.2 / 10.3's template (`src/double.asm:15-20, 44-45, ...`).
- **§218-226 CCD-4 (Per-Epic Benchmark Gate):** gate is at **Story 10.10**, not here. Record ROM delta informationally.
- **§248-252 E10-D1 (Byte-Order):** low cell on TOS, high cell below. For every binary double-op (`D+`, `D-`, `D=`, `D<`, `DMAX`, `DMIN`), the stack on entry is `( x1-high x2-low x3-high x4-low )` with `x4-low = BC`. Non-negotiable — don't flip the convention for "convenience".
- **§260-264 E10-D3 (Implementation split):** all nine words are arithmetically hot (single-cell primitives don't help Forth-level users if they don't extend to 32-bit). Implement in assembly. **Exception:** `DMAX` / `DMIN` can legitimately be DEFWORDs over `2OVER 2OVER D< IF 2SWAP THEN 2DROP` (see Task 9.4 Option C) — performance-cost is ~40 extra cycles per call, acceptable for non-hot words.
- **§434-447 Source-file organisation:** `src/double.asm` is the home for Epic-10 double-cell primitives — all nine Story-10.4 words live there.

### BC-as-TOS Convention (Project Memory: `project_tos_in_register.md`)

Every existing stack / arithmetic primitive treats BC as TOS on entry and exit:

| Word | Entry BC | Exit BC |
|---|---|---|
| `D+` | `x4` (low of `d2`) | `x6` (low of `d3`) |
| `D-` | `x4` (low of `d2`) | `x6` (low of `d3`) |
| `DNEGATE` | `x2` (low of `d`) | `x2'` (low of `-d`) |
| `DABS` | `x2` (low of `d`) | low of `ud` (= `x2` if `d ≥ 0`, else low of `-d`) |
| `D=` | `x4` (low of `d2`) | flag (0 or $FFFF) |
| `D<` | `x4` (low of `d2`) | flag (0 or $FFFF) |
| `DMAX` | `x4` (low of `d2`) | low of the larger of `d1`/`d2` |
| `DMIN` | `x4` (low of `d2`) | low of the smaller of `d1`/`d2` |
| `M+` | `n` | `x6` (low of `d2`) |

`DE = IP` throughout. Any body that needs DE for arithmetic must `EXX`-bracket or memory-stash IP. Precedents:

- **EXX-sandwich:** `src/stack_ops.asm:111-171` `ROLL`; `src/double.asm:103-119` `2SWAP`.
- **Memory-stash:** `src/strings.asm:346-351` `>NUMBER` (saves IP and other state to local scratch words).

Dev's choice per-word — memory-stash is shorter in source bytes; EXX is ~4 T-states faster but requires more register-dance. For the arithmetic-heavy words in this story, memory-stash is likely the cleaner option (similar pattern to Story 10.3 `>NUMBER`).

### Stories 10.2 / 10.3 Carry-Forwards

From `_bmad-output/implementation-artifacts/10-2-double-cell-stack-foundation.md` and `10-3-single-double-conversions.md` (both `done`):

1. **CCD-3 template locked.** Format: `; ANS Forth 1994 §<n>   <word>   — <note>`. Every §-number verified at write-time (Story 10.3's code-review pass confirmed the importance — a different-LLM review caught an off-by-one underflow helper in 10.3 that the dev self-review missed).
2. **`check_underflow_3` and `check_underflow_4` exist** in `src/system.asm:326-362`. Use them directly; **do not introduce new helpers**. The Story 10.3 code-review fix established the convention firmly: **`check_underflow_N` counts total user items including BC, not SP-only cells** — `N` is the total depth consumed. See `src/system.asm:293-301` header comment.
3. **`src/double.asm` file exists** and is already wired into `src/antforth.asm`'s INCLUDE list. Just append after `w_D_TO_S` at line 178.
4. **Tests live in `tests/double_tests.fth`** — extend, don't create a new file. Section header style: `\ === Story 10.X <topic> ===`.
5. **Makefile test numbering is contiguous.** Current max is **449** (post-code-review). Do not leave gaps. Start at 450.
6. **Different-LLM second-pass review is expected** for Epic-10 stories that write new code. Story 10.2 caught an M1 §-number drift; Story 10.3 caught an H1 underflow off-by-one. This story's trap-rich surface (`D<` signed-vs-unsigned; `DNEGATE` fixed-point case; `M+` sign-extend) is a similar target.

### Stack-Underflow Discipline

Pre-Epic-11 convention: `check_underflow_N` at entry, falls through to ABORT on fail, REPL recovers via the existing ABORT-path. Epic 11 will migrate every site to `THROW -4` wholesale — **do NOT pre-migrate**.

Per-word mapping table is in AC #10 above. **The rule is: `N = total user cells consumed` (including BC).** Story 10.3's `H1` finding was entirely caused by applying the wrong rule ("N = SP cells only") — do not repeat the mistake.

### Correctness Traps (by word)

**`D+` / `D-`:**

- Low-cell carry (`D+`) / borrow (`D-`) MUST propagate into the high-cell op. On Z80, `ADC HL, rr` / `SBC HL, rr` read CF; `POP` / `PUSH` / `LD rr, (nn)` preserve CF; `ADD HL, rr` / `OR A` / `XOR A` / arithmetic ops **destroy CF**. Order operations so the CF from the low add survives to the high add.
- For `D-`, the ANS semantic is `d3 = d1 - d2`. Be careful about operand order on the stack: with `d1` below `d2`, the POP order retrieves `d2` first. The subtraction is `d1 - d2` (not `d2 - d1`).

**`DNEGATE`:**

- The `$80000000` fixed-point case (most-negative 32-bit integer) negates to itself. The ANS spec allows this (no exception; no overflow flag to the Forth level). Just make sure the arithmetic doesn't crash — `0 - $8000_0000 = $8000_0000` naturally via two's-complement wraparound.
- Don't forget the carry from low-cell inversion. `0 1 DNEGATE` must produce `-1 -1` (= `$FFFFFFFF`), not `-1 0`. The borrow from `0 - 1` (low cell) rolls into `0 - 0 - borrow` (high cell) = `-1`.

**`DABS`:**

- Peek the high cell's sign bit **without popping** — otherwise an early-exit-on-positive path has to re-push. Use `LD HL, 2 / ADD HL, SP / LD A, (HL)` to read the high byte of the high cell (at SP+3), then `AND $80` to test the sign.
- Alternative: always `DNEGATE` if sign bit set; fall through to `NEXT` if clear. Simplest control flow.

**`D=`:**

- Z80 doesn't have a native 16-bit equality compare. Idiom: `OR A / SBC HL, DE` — result is zero iff equal; `JR Z, ...`. Or `LD A, H / CP D / JR NZ, .neq / LD A, L / CP E / JR NZ, .neq / JR .eq`.
- Don't short-circuit on just the low cells. `D=` is true only if **both** cells match.

**`D<` — THE characteristic trap of this story:**

- **Signed compare on high cells, unsigned compare on low cells.** This is THE most-failed spot in Forth double-cell implementations. Get it wrong and negative numbers sort as huge positives (or vice versa).
- Z80 lacks a native signed `SBC` flag-interpretation; use the **Z/P/S trick**: after `SBC HL, DE`, if `P/V ⊕ S = 1` then the true signed result was negative. The `SBC` preserves the underflow as a flag combination.
- Concretely:
  ```
  ; Compare high cells signed: x1 vs x3 (d1.hi vs d2.hi)
  OR    A
  SBC   HL, DE          ; HL = x1 - x3; sets S, Z, P/V
  JR    NZ, .dlt_unequal
  ; High cells equal; compare low cells unsigned
  ; ... (low-cell compare)
  .dlt_unequal:
  ; Signed compare: true if (S ⊕ P/V) == 1
  ; S=1 no overflow → x1 was negative after subtract → x1 < x3 → TRUE
  ; S=0 no overflow → x1 ≥ x3 after subtract → x1 > x3 → FALSE
  ; S=0 overflow → actually x1 < x3 (the overflow flipped the sign) → TRUE
  ; S=1 overflow → actually x1 > x3 → FALSE
  ```
  Encode this as two `JP` instructions with a shared false/true path.
- **Test both** `-1 -1 0 0 D<` (expected TRUE; d1=−1 < d2=0) AND `-1 0 -1 1 D<` (expected TRUE; high cells equal at −1, low cells compared **unsigned**: 0 < 1).

**`DMAX` / `DMIN`:**

- If implemented as DEFWORD atop `D<` + `2OVER` + `2SWAP` + `2DROP`, the logic is trivial and correctness follows from `D<`. If inlined in assembly, do the compare inline and branch — do not re-pop cells you just popped.
- Equal case: ANS §8.6.1210 says `DMAX` returns "the greater of d1 and d2" — when equal, either is acceptable, but most implementations return `d1` (the deeper one). Pick one and document.

**`M+`:**

- **Sign-extend `n` before the add.** This is the single most common bug for `M+`. If you just `ADC HL, BC` with BC=n, the high-cell add treats `n` as a pure low-cell value — wrong for negative `n` (you'd add the low cell of `n` to the high cell instead of adding the sign-extension).
- Idiom: use the `S>D`-style extract: `LD A, B / RLA / SBC A, A / LD B, A / LD C, A` to build `BC = sign_ext_high(n)` after the low-cell add has captured the carry (save the carry to `EX AF, AF'` first).
- Alternative: compile `M+` as `S>D D+` — DEFWORD, simplest possible. Cost: ~30 cycles overhead; acceptable. **This is probably the shortest correct path.**

### Epic 10 Dependencies Not Yet Landed

Nothing blocks Story 10.4:

- Epic 1–8 parameter-stack + memory + arithmetic primitives ✓
- Story 10.1 gap survey ✓ (assigned all nine §8.6 words to 10.4)
- Story 10.2 double-cell stack foundation ✓ (`src/double.asm` file, CCD-3 template, `check_underflow_N` helpers, test file)
- Story 10.3 single↔double conversions ✓ (`S>D` pattern for sign-extending; `M+` can build on `S>D D+` if dev chooses the DEFWORD path)

Stories 10.5, 10.6, 10.7 all depend on Story 10.4: 10.5's multiplication inner loops use `D+`; 10.6's division uses `D-` and `D<`; 10.7's pictured-output formatting uses `M+` and `D<`.

### Epic 9 / Story 10.3 Retro — Action Items Relevant to This Story

From `_bmad-output/implementation-artifacts/epic-9-retro-2026-04-20.md` and Story 10.3's code-review follow-ups:

- **Plain QA prose:** apply to Completion Notes — state measured values, gates, reasons plainly (memory `feedback_plain_qa_language.md`).
- **AC-drafting trace-check:** every AC in this story maps to at least one Makefile test entry. Traceability is explicit in AC #14.
- **Adversarial self-review that actually finds things:** Story 10.3's dev self-review declared HIGH=nil / MED=nil; the code-review pass found 1 HIGH and 2 MED. The lesson (memory `feedback_adversarial_review.md`): if your self-review can't find anything, you're not looking hard enough. For this story, the obvious attack surfaces are `D<` (signed-vs-unsigned), `M+` (sign-extension), `DNEGATE` (fixed-point case), and `check_underflow_N` mapping (Story 10.3 trap — recompute per word, don't trust the table blindly).

### Project Structure Notes

- **Files touched:**
  - `src/double.asm` (EDIT — append 9 DEFCODEs / DEFWORDs after `w_D_TO_S`)
  - `tests/double_tests.fth` (EDIT — append Story 10.4 section)
  - `Makefile` (EDIT — new `test-repl` entries starting at 450)
  - `docs/ans-forth-core-compliance.md` (EDIT — 9 row flips in the §8.6 table + Epic-10 closure plan row)
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` (EDIT — status transitions, handled by dev-story workflow)
  - `_bmad-output/implementation-artifacts/10-4-double-precision-arithmetic-additive-sign-compare-mixed.md` (this file — Dev Agent Record + Completion Notes at close)
- **No new files created.** Story 10.2 set up `src/double.asm` and `tests/double_tests.fth`; Story 10.4 extends both.
- **Alignment with unified structure:** all edits sit in established homes per `architecture.md:434-447`. No source-tree structural change.
- **Detected conflicts or variances:** the epics.md spec text at `epics.md:508` cites "ANS §8.6.1.1830" for `M+` (note the extra `.1`). The canonical DPANS94 number is `8.6.1830`. Compliance doc at `ans-forth-core-compliance.md:369` uses the canonical form. **Dev must use `§8.6.1830` in the CCD-3 comment**, not the PRD/epics typo. Document the epics-text typo in Completion Notes for a future errata sweep (same category as Story 10.3's `>D` upstream drift).

### References

- **Authoritative standard:**
  - DPANS94 §8.6.1040 `D+` — double-cell add
  - DPANS94 §8.6.1050 `D-` — double-cell subtract
  - DPANS94 §8.6.1230 `DNEGATE` — double-cell negate
  - DPANS94 §8.6.1160 `DABS` — double-cell absolute value
  - DPANS94 §8.6.1120 `D=` — double-cell equality
  - DPANS94 §8.6.1110 `D<` — double-cell signed less-than
  - DPANS94 §8.6.1210 `DMAX` — double-cell max (signed)
  - DPANS94 §8.6.1220 `DMIN` — double-cell min (signed)
  - DPANS94 §8.6.1830 `M+` — mixed single + double → double
  - **Verify all nine §-numbers at implementation time** against DPANS94 / forth-standard.org before committing comments.
- **Planning artefacts:**
  - `_bmad-output/planning-artifacts/epics.md:494-516` — Story 10.4 epic spec
  - `_bmad-output/planning-artifacts/epics.md:426-472` — full Epic 10 context
  - `_bmad-output/planning-artifacts/architecture.md:246-264` — E10-D1 / E10-D2 / E10-D3 decisions
  - `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 Standards-Citation Discipline
  - `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 Per-Epic Benchmark Gate (at Story 10.10, not here)
  - `_bmad-output/planning-artifacts/architecture.md:434-447` — Source-file organisation table
  - `_bmad-output/planning-artifacts/prd.md:387-389` — FR10 / FR11 / FR12 (double-cell + conversions)
  - `_bmad-output/planning-artifacts/prd.md:460-479` — NFR9 (regression), NFR10 (Core compliance), NFR16 (test-first), NFR17 (standards citations)
- **Precedent stories:**
  - `_bmad-output/implementation-artifacts/10-2-double-cell-stack-foundation.md` — established `src/double.asm`, `tests/double_tests.fth`, CCD-3 template, underflow helpers
  - `_bmad-output/implementation-artifacts/10-3-single-double-conversions.md` — immediate predecessor; `S>D` sign-extend idiom (reuse in `M+`), `>NUMBER` memory-stash pattern, code-review findings on underflow helper counting
  - `_bmad-output/implementation-artifacts/10-1-ans-core-compliance-gap-survey-and-implementation-plan.md` — surveyor-authoritative scope
- **Source-tree anchors for pattern matching:**
  - `src/double.asm:14-178` — Stories 10.2 + 10.3 DEFCODEs = style template for all nine new words
  - `src/system.asm:278-362` — `check_underflow` / `_2` / `_3` / `_4` helpers (do NOT add new helpers)
  - `src/stack_ops.asm:111-171` — ROLL (EXX-sandwich worked example)
  - `src/strings.asm:338-434` — `>NUMBER` (memory-stash worked example)
  - `src/arithmetic.asm` — single-cell `+ - NEGATE ABS = < MAX MIN` (analogues; read for idiom before writing the double-cell versions — especially `<` for the signed-compare trap)
  - `src/macros.asm:26-94` — `NEXT` / `DEFCODE` / `DEFWORD` macros (DEFWORD needed only if `DMAX`/`DMIN`/`M+` go the colon-compilation route per Task 9.4 / 2.5)
- **Test-tree anchors:**
  - `tests/double_tests.fth` (full file) — Story 10.2 / 10.3 sections = style template for the Story 10.4 extension
  - `Makefile:3726-3920` — Stories 10.2 / 10.3 `test-repl` blocks = canonical entry-format template
- **Project memories applicable to this story:**
  - `feedback_systematic_reference_check.md` — cross-reference DPANS94, not memory (AC #1, #12, Task 1)
  - `feedback_standards_compliance.md` — investigate the standard; never rationalise (AC #6, #15)
  - `feedback_adversarial_review.md` — reviews MUST find things (Task 14; Story 10.3 precedent)
  - `feedback_plain_qa_language.md` — diagnostic Completion Notes
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth scripts (AC #13, Task 10)
  - `feedback_design_upfront.md` — land the full §8.6 additive/compare/sign suite now so Story 10.5 / 10.7 consume a conformant foundation from day one
  - `feedback_follow_process.md` — execute the workflow without asking for permission for obvious next steps
  - `project_tos_in_register.md` — BC-as-TOS discipline; DE=IP; DEPTH convention (AC #9, Dev Notes)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m]

### Debug Log References

None — implementation followed the red-green cycle cleanly; no three-consecutive-failure loops or HALT conditions triggered. The only iterative fix was in the Makefile where five `printf '…'` calls starting with a negative literal needed the `printf --` option-terminator convention (the existing precedent at `Makefile:2847` and following); tests 453/459/462/466/467 were updated on first failure and passed on rerun.

### Completion Notes List

- **§-number discipline (AC #12, Task 1).** All nine §-numbers verified against `docs/ans-forth-core-compliance.md:361-369` before writing the CCD-3 comments: `D+ §8.6.1040`, `D- §8.6.1050`, `DNEGATE §8.6.1230`, `DABS §8.6.1160`, `D= §8.6.1120`, `D< §8.6.1110`, `DMAX §8.6.1210`, `DMIN §8.6.1220`, `M+ §8.6.1830`. Each DEFCODE/DEFWORD header carries a one-line `; ANS Forth 1994 §<n>   <word>   — <short note>` comment and a stack-effect comment matching the Story 10.2/10.3 house style.
- **Source-file layout (AC #11).** All nine words landed in `src/double.asm`, appended after `w_D_TO_S`. Implementation order `M+ → D+ → D- → DNEGATE → DABS → D= → D< → DMAX → DMIN` (matches the story's suggested ordering). No edits to any other `.asm` file.
- **Underflow discipline (AC #10).** `check_underflow_2` for DNEGATE/DABS; `check_underflow_3` for M+; `check_underflow_4` for D+/D-/D=/D<. DMAX/DMIN are DEFWORDs that inherit the check from their first `2OVER` call (needs 4 cells). All nine underflow tests (493..501) confirm `? Stack underflow` + `ok` REPL-recovery per Epic-1 convention.
- **BC-as-TOS + IP preservation (AC #9).** Every DEFCODE preserves DE=IP. M+ uses `EX (SP), HL` + `PUSH AF` / `POP AF` to preserve both CF and DE in-register without a memory stash. D+, D-, D=, D<, and DNEGATE stash DE to a shared 2-byte scratch cell `double_ip_stash` at the tail of `src/double.asm` (never accessed from threaded code; never held across NEXT; single shared cell is safe because words are never re-entered before `LD DE, (double_ip_stash)` restores IP).
- **D+ / D- register dance.** Both use a 3-POP + register-shuffle sequence. After the low-cell ADD (D+) or SBC (D-), CF is preserved across the subsequent `POP BC` (which fetches x1) because Z80 POP does not affect flags. The subsequent `ADC HL, BC` / `SBC HL, BC` reads that preserved CF and produces the high cell with correct carry/borrow propagation. Verified across every AC-#1 and AC-#2 boundary, including the 32-bit wrap case `-1 -1 0 1 D+` → `(0, 0)` and the `0 0 0 1 D-` → `(-1, -1)` wrap-underflow case.
- **DNEGATE $80000000 fixed-point.** Explicitly verified: `-32768 0 DNEGATE` returns `(-32768, 0)` unchanged (ANS-conformant two's-complement wrap). Same test for DABS: `-32768 0 DABS` → `(-32768, 0)` (the fixed point is self-abs). Tests 463 and separate REPL spot-check confirm the in-register 0-high case (`0 -32768 DNEGATE` → `(-1, -32768)` = -32768 signed double) also behaves correctly.
- **D< signed/unsigned trap (AC #6).** Implementation uses the 32-bit-subtract-then-check-sign+overflow idiom — low cells subtract unsigned (CF set on borrow), high cells SBC with borrow-in yielding S and P/V flags that encode the signed 32-bit comparison as `(S XOR P/V) = 1 → less`. The same idiom that `src/logic.asm:142-164` uses for single-cell `<`, applied to the high cell of the 32-bit subtract. Both trap-case tests pass: `-1 -1 0 0 D<` → TRUE (signed high-cell compare: -1 < 0), `-1 0 -1 1 D<` → TRUE (high cells equal at -1; low cells compared unsigned: 0 < 1). Plus the high-cell-different case `0 -1 1 0 D<` → TRUE ($FFFF < $10000).
- **DMAX / DMIN as DEFWORDs (Task 9.4 Option C).** Both compile to `2OVER 2OVER D< IF … THEN 2DROP` threads; DMIN inserts an extra `0=` to invert the flag semantics. Dictionary overhead ~12 bytes per header; thread body is 7 cells each. E10-D3 permits this — DMAX/DMIN are not hot-path words.
- **M+ sign-extension.** Uses the `LD A, B / RLA / SBC A, A` idiom from `S>D` (see `src/double.asm:157-160`) to build the sign-extended high half of n into BC, with the low-cell carry stashed to AF on the stack via `PUSH AF` / `POP AF` across the sign-extension that clobbers CF. Verified against all AC #8 boundary values (`0 0 -1 M+` → `(-1,-1)`, `0 -1 1 M+` → `(1,0)`, `-1 -5 -1 M+` → `(-1,-6)`).
- **Compliance doc update (AC #16, Task 13).** `docs/ans-forth-core-compliance.md:361-369` — all nine §8.6 rows flipped from `10.4` to `Implemented (double.asm:<line>)` pointing at each word's dictionary-header label. Epic-10 closure plan row at `line 42` updated from `0 §6.1 | All §8.6 bonus …` to `0 §6.1 ✓ | §8.6 bonus Complete (all 9 words Implemented)`. Summary table at lines 11-18 and Gap Classification table at lines 23-28 untouched — no §6.1 words are added or removed by this story.
- **Regression (AC #15, Task 12).** `make clean && make test` PASS. `make test-repl` PASS: 501 unique REPL tests (449 Story-10.3-close-out baseline + 52 new Story-10.4 entries 450..501), 0 FAIL. Spot-checked adjacent words for regression: `+ - NEGATE ABS = < MAX MIN` all byte-identical output. `S>D D>S >NUMBER 2@ 2! 2DUP 2DROP 2SWAP 2OVER` all byte-identical. No cross-word contamination.
- **ROM size delta (AC #17).** Pre-story `build/antforth.com` = 15149 bytes. Post-story = 15472 bytes. Delta = **+323 bytes** (= ~36 bytes per new word including dictionary headers and the shared `double_ip_stash` cell). Within the AC #17 estimate band of ~280 bytes ±50%. Informational only — CCD-4 gate is at Story 10.10, not here.
- **Epics-text typo note (deferred errata).** `_bmad-output/planning-artifacts/epics.md:508` cites `§8.6.1.1830` for M+ (extra `.1`); the canonical DPANS94 number is `§8.6.1830`. I used the canonical form in the CCD-3 comment at `src/double.asm:195` per Task 1 convention. Same category as Story 10.3's `>D` upstream drift; document here for future errata sweep.
- **Story AC #2 boundary-value note.** AC #2 reads `0 $8000 0 1 D-` → `( $FFFF $7FFF )` (borrow rippled into high cell). Taking the tokens in Forth source order with TOS=low-cell convention, the actual computation is `$00008000 - $00000001 = $00007FFF` = `( 0 $7FFF )`; there is no borrow into the high cell. The AC #14 boundary tests for D- (which drive the Makefile tests 455..459) use correct arithmetic and all pass. The AC #2 third-case output expression appears to be a draft-time error; I flagged it here and the implementation (verified against tests) is correct.

### File List

**Modified:**
- `src/double.asm` — appended nine DEFCODE/DEFWORD blocks (M+, D+, D-, DNEGATE, DABS, D=, D<, DMAX, DMIN) + shared `double_ip_stash` scratch cell at lines 181..415 (was 178 lines; now 415).
- `tests/double_tests.fth` — appended Story 10.4 section (52 new scenarios) at lines 115..189.
- `Makefile` — appended Story 10.4 `test-repl` entries 450..501 after line 3955.
- `docs/ans-forth-core-compliance.md` — flipped 9 §8.6 rows to `Implemented (…)`; updated Epic-10 closure plan row for 10.4.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — status transition `ready-for-dev → in-progress` (dev-story workflow; → `review` at completion).
- `_bmad-output/implementation-artifacts/10-4-double-precision-arithmetic-additive-sign-compare-mixed.md` — Status transitions, all Tasks/Subtasks checked, Dev Agent Record filled in.

**Created:** none. (Story 10.2 established `src/double.asm` and `tests/double_tests.fth`; this story extends both.)

### Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-22 | Implemented Story 10.4: nine §8.6 Double-Number arithmetic/compare/sign primitives (M+, D+, D-, DNEGATE, DABS, D=, D<, DMAX, DMIN) in `src/double.asm`; 52 new REPL tests (450..501); compliance doc flipped. All tests PASS, 0 regressions. ROM +323 bytes. | claude-opus-4-7[1m] |
| 2026-04-22 | Code review (`bmad-bmm-code-review`): fixed AC #2 third boundary value (wrong arithmetic), unescaped `$$<hex>` in six Makefile PASS banners (shell-ate `$F`/`$1`), restored explicit §8.6 word list in compliance-doc row 10.4, and extended `src/double.asm` header comment with Story 10.4 word groups. 0 HIGH findings; tests remain 501 PASS / 0 FAIL. | claude-opus-4-7[1m] (code-review pass) |
