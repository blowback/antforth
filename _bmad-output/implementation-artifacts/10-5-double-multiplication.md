# Story 10.5: Double multiplication (`D*`, `M*`, `UM*`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the three ANS Core / §8.6 multiplication primitives — `UM*` (unsigned single × single → unsigned double), `M*` (signed single × single → signed double), and `D*` (signed double × signed double → signed double, truncating to 32 bits) —
so that after Story 10.4 landed the additive / sign / compare suite, I can compute 32-bit products from single- and double-cell operands using the standard ANS vocabulary, and Stories 10.6 (division) and 10.9 (`*/`, `*/MOD`) can consume `M*` as their mixed-precision foundation.

## Acceptance Criteria

1. **Given** `UM* ( u1 u2 -- ud )` per DPANS94 §6.1.2360 (verify §-number at implementation time per project memory `feedback_systematic_reference_check.md`) and the E10-D1 byte-order convention (low cell on TOS, high cell below; `architecture.md:248-252`), **When** `UM*` executes with `u1` second-on-stack and `u2` = BC = TOS, **Then** the unsigned 32-bit product `ud = u1 × u2` is left as `( ud-high ud-low )` with `ud-low` on TOS (BC) and `ud-high` second-on-stack (SP). Boundary values: `0 0 UM*` → `( 0 0 )`; `0 5 UM*` → `( 0 0 )` (anything × 0 = 0); `1 1 UM*` → `( 0 1 )`; `$FFFF $FFFF UM* .S` → `<2> -2 1` in decimal, i.e. high=$FFFE (-2 signed) + low=$0001 (the classic all-ones square); `$100 $100 UM*` → `( 1 0 )` (256 × 256 = 65536 = carries cleanly into the high cell); `$FFFF 2 UM*` → `( 1 -2 )` ($FFFF×2 = $1FFFE → high=1, low=$FFFE=-2 signed).

2. **Given** `M* ( n1 n2 -- d )` per DPANS94 §6.1.1810, **When** executed, **Then** the signed 32-bit product `d = n1 × n2` is produced with correct sign: the sign of `d` is `sign(n1) XOR sign(n2)` and its magnitude is `|n1| × |n2|`. Implementation is permitted to build on `UM*` by negating operands before and the result after. Boundary values: `0 0 M*` → `( 0 0 )`; `0 -5 M*` → `( 0 0 )`; `5 3 M*` → `( 0 15 )`; `-5 3 M*` → `( -1 -15 )` (= -15 as signed double, high=$FFFF low=$FFF1); `5 -3 M*` → `( -1 -15 )`; `-5 -3 M*` → `( 0 15 )`; `-32768 -32768 M* .S` → `<2> 16384 0` ($8000 × $8000 = $40000000, high=$4000=16384 low=0); `-32768 32767 M* .S` → `<2> -16384 -32768` in decimal (= -32768 × 32767 = -$3FFF8000, high=$C000=-16384 low=$8000=-32768); `32767 32767 M* .S` → `<2> 16383 1` ($7FFF × $7FFF = $3FFF0001). `M*` does NOT truncate — the full signed 32-bit product is returned.

3. **Given** `D* ( d1 d2 -- d3 )` per DPANS94 §8.6.1090, **When** executed, **Then** the low 32 bits of the 64-bit product `d1 × d2` are returned (ANS says the result is "the low 32 bits of the double-cell product"; truncation on overflow is silent and matches signed arithmetic in two's-complement). Algebraically, for `d1 = (a₁:hi, b₁:lo)` and `d2 = (a₂:hi, b₂:lo)` treated as unsigned:
   ```
   d3 = (b₁ × b₂) + ((b₁ × a₂ + a₁ × b₂) << 16)  mod 2³²
   ```
   The signed semantics emerge for free from two's-complement — no sign-tracking code is required (unlike `M*`). Boundary values: `0 0 0 0 D*` → `( 0 0 )`; `0 5 0 3 D*` → `( 0 15 )` (both operands fit in single cells, result fits in low cell); `0 -1 0 1 D*` → `( 0 -1 )` (d1 = 65535, d2 = 1, product = 65535 = $0000FFFF, low=-1 signed); `0 -1 0 -1 D*` → `( -2 1 )` (d1 = 65535, d2 = 65535, product = $FFFE0001, high=$FFFE=-2 low=$0001); `-1 -1 0 1 D*` → `( -1 -1 )` (d1 = -1 signed, d2 = 1, product = -1 = $FFFFFFFF); `-1 -1 -1 -1 D*` → `( 0 1 )` (d1 = -1 signed, d2 = -1 signed, product = 1 = $00000001 via two's-complement); `0 1 -1 0 D*` → `( -1 0 )` (d1 = 1 × 2¹⁶, d2 = $FFFF = 65535, product = 65535 × 65536 = $FFFF0000, truncated fits exactly: high=$FFFF=-1 low=$0000).

4. **Given** the BC-as-TOS convention (project memory `project_tos_in_register.md`) and the Story 10.4 IP-stash pattern (`src/double.asm:419-424` `double_ip_stash`; DE=IP is saved to memory or shadow-register across register-heavy arithmetic), **When** each of `UM*`, `M*`, `D*` is implemented, **Then** on entry BC holds the top-most single cell of the input signature (`u2` for UM*, `n2` for M*, low-cell of `d2` for D*) and on exit BC holds the low cell of the result (ud-low for UM*, d-low for M* and D*). `DE = IP` is preserved across every word — either left untouched or bracketed by memory-stash (`LD (double_ip_stash), DE` / `LD DE, (double_ip_stash)`) or `EXX` per the Epic 7/8 convention. The existing `double_ip_stash` cell is safe to reuse (no re-entry across NEXT).

5. **Given** stack-underflow discipline inherited from Epic 1 and Story 10.3's code-review-established rule that `check_underflow_N` counts **total user items including BC** (`src/system.asm:293-301`), **When** a §6.1/§8.6 multiplication primitive is invoked with insufficient depth, **Then** it calls the matching `check_underflow_N` helper:

    | Word | Cells consumed | Helper |
    |---|---|---|
    | `UM*` | 2 (`u1` + `u2`) | `check_underflow_2` |
    | `M*` | 2 (`n1` + `n2`) | `check_underflow_2` |
    | `D*` | 4 (`d1` + `d2`) | `check_underflow_4` |

    No new helpers are introduced — Stories 10.2 / 10.3 landed `_2`, `_3`, and `_4`. Pre-Epic-11 behaviour (ABORT + stack-underflow diagnostic + REPL recovery) is preserved bit-identically. Epic 11 will migrate to `THROW -4` later — **do NOT pre-migrate in this story**.

6. **Given** architecture decision E10-D3 (assembly for hot primitives; colon-compiled Forth permitted for thin wrappers; `architecture.md:260-264`) and the source-file organisation table (`architecture.md:434-447`), **When** the three words are implemented, **Then** they **all land in `src/double.asm`**, appended after `w_D_MIN` (currently the file's last DEFWORD at `src/double.asm:417`, followed by the `double_ip_stash` cell at `src/double.asm:423`). Suggested source ordering: `UM*` → `M*` → `D*` (builds complexity incrementally: unsigned is the core multiplier, signed mixed adds a sign tracker around it, double×double either inlines three unsigned multiplies or chains three `UM*` calls). `double_ip_stash` must remain the final item in the file so its address is stable. No other source files are modified.

7. **Given** CCD-3 Standards-Citation Discipline (`architecture.md:206-216`, NFR17 at `prd.md:478`) and the format template established by Stories 10.2 / 10.3 / 10.4 (`src/double.asm:19-22, 44-47, 68-72, 84-89, 99-104, 124-129, 149-153, 167-174, 183-189, 211-217, 237-240, 263-268, 287-293, 308-313, 339-348, 375-380, 396-402`), **When** each DEFCODE / DEFWORD is written, **Then** its implementation carries (a) a one-line `; ANS Forth 1994 §<section>   <word>   — <short semantic note>` comment in the established template format and (b) a stack-effect comment on the appropriate line in the existing style. **§-numbers are verified against DPANS94 / forth-standard.org at implementation time** — do NOT enumerate from memory (per `feedback_systematic_reference_check.md`; reinforced by Story 10.2's M1 finding, Story 10.3's self-review gap, and Story 10.4's code-review pass). The expected numbers to verify: `UM* §6.1.2360`, `M* §6.1.1810`, `D* §8.6.1090`.

8. **Given** the REPL-test-preferred discipline (project memory `feedback_repl_tests_preferred.md`, NFR16 at `prd.md:477`) and the Story-10.2 / 10.3 / 10.4 house style (`tests/double_tests.fth`), **When** tests are written, **Then** (a) new scenarios are **appended** to `tests/double_tests.fth` under a new section header `\ === Story 10.5 double-cell multiplication (UM*, M*, D*) ===`, matching the existing style (one-line Forth expression + `\ expect: <fragment>` comment), with per-word sub-headers; and (b) the corresponding `test-repl` entries are added to the `Makefile` as the authoritative runners, using the established `@OUTPUT=$$(printf … | $(IZCPM) $(TARGET)) && grep -q` pattern — continuing the numbering from the final REPL test currently in `Makefile` (Story 10.4 ended at **501** after the code-review follow-ups; the new Story-10.5 block starts at **502**).

9. **Given** coverage must exhaust ACs #1–#3 (plus underflow AC #5), **When** `make test-repl` is run, **Then** the new test block includes **at minimum** (numbering suggested, final is dev's choice):

    **`UM*` (AC #1) — 6 tests:**
    - `0 0 UM* .S 2DROP` → `<2> 0 0` (zero × zero)
    - `0 5 UM* .S 2DROP` → `<2> 0 0` (zero × nonzero)
    - `1 1 UM* .S 2DROP` → `<2> 0 1` (trivial product fits in low cell)
    - `$100 $100 UM* .S 2DROP` → `<2> 1 0` (= 65536, clean carry into high cell)
    - `$FFFF $FFFF UM* .S 2DROP` → `<2> -2 1` (= $FFFE0001; all-ones-squared — max unsigned case)
    - `$FFFF 2 UM* .S 2DROP` → `<2> 1 -2` (= $1FFFE; check low-cell wrap)

    **`M*` (AC #2) — 8 tests (sign cross-product):**
    - `0 0 M* .S 2DROP` → `<2> 0 0`
    - `5 3 M* .S 2DROP` → `<2> 0 15` (positive × positive)
    - `-5 3 M* .S 2DROP` → `<2> -1 -15` (negative × positive → negative; = -15 as signed double)
    - `5 -3 M* .S 2DROP` → `<2> -1 -15` (positive × negative → negative)
    - `-5 -3 M* .S 2DROP` → `<2> 0 15` (negative × negative → positive)
    - `-32768 -32768 M* .S 2DROP` → `<2> 16384 0` (= $40000000; corner — product just fits in unsigned 32)
    - `32767 32767 M* .S 2DROP` → `<2> 16383 1` (= $3FFF0001; max positive × max positive)
    - `-32768 32767 M* .S 2DROP` → `<2> -16384 -32768` (= -$3FFF8000; sign and magnitude both non-trivial)

    **`D*` (AC #3) — 7 tests:**
    - `0 0 0 0 D* .S 2DROP` → `<2> 0 0`
    - `0 5 0 3 D* .S 2DROP` → `<2> 0 15` (product fits in single cell)
    - `0 -1 0 1 D* .S 2DROP` → `<2> 0 -1` (= 65535 × 1 = 65535 = $0000FFFF)
    - `0 -1 0 -1 D* .S 2DROP` → `<2> -2 1` (= 65535 × 65535 = $FFFE0001; same bit pattern as `$FFFF $FFFF UM*` but via D*)
    - `-1 -1 0 1 D* .S 2DROP` → `<2> -1 -1` (= −1 × 1 as signed doubles = −1)
    - `-1 -1 -1 -1 D* .S 2DROP` → `<2> 0 1` (= −1 × −1 as signed doubles = 1 — the classic two's-complement identity)
    - `0 1 -1 0 D* .S 2DROP` → `<2> -1 0` (= 65536 × 65535 = $FFFF_0000; exact fit, high cell = $FFFF = −1 signed, low = 0)

    **Underflow recovery (AC #5) — one test per word at its minimum-insufficient depth:**
    - `1 UM*` → `? Stack underflow` + `ok` (DEPTH=1, UM* needs 2)
    - `1 M*` → `? Stack underflow` + `ok` (DEPTH=1, M* needs 2)
    - `1 2 3 D*` → `? Stack underflow` + `ok` (DEPTH=3, D* needs 4)

    Total estimated test count: **24** (6 + 8 + 7 + 3). Block range **502..525** (adjust to the actual final count).

10. **Given** NFR9 (zero regressions, `prd.md:464`) and FR46 (all Epic 1–8 REPL tests continue to pass, `prd.md:435`), **When** the full test suite (`make test` + `make test-repl`) is run after this story's changes, **Then** every pre-existing test still passes, the new Story-10.5 tests all pass, and the final REPL test count increases by exactly the number of new entries added — no hidden regressions, no baseline drift. Post-Story-10.4-close-out baseline is **501 PASS** — the new count is `501 + <new entries>` with 0 FAIL. No word modified outside `src/double.asm` means the regression surface is narrow; spot-check adjacent words for byte-for-byte output stability: `*` (single-cell multiply, `src/arithmetic.asm:86`), `D+`, `D-`, `M+`, `DNEGATE`, `DABS`, `D=`, `D<`, `S>D`, `D>S`, `2@`, `2!`, and the single-cell `+ - NEGATE ABS = <`.

11. **Given** NFR10 (100% §6.1 Core compliance target, `prd.md:461-476`) and the explicit scope note in `docs/ans-forth-core-compliance.md:105-112` that **`M*` and `UM*` are §6.1 Core gap words**, whereas `D*` is a §8.6 Double-Number bonus word, **When** this story completes, **Then** the compliance doc is updated in three places:
    - The **§6.1 Core § "Double-Cell and Mixed-Precision Multiplication"** table at `ans-forth-core-compliance.md:107-112`: the two rows for `M*` and `UM*` flip from `**Gap → Story 10.5**` to `Implemented (`double.asm:<line>`)`.
    - The **§6.1 Summary table** at `ans-forth-core-compliance.md:11-18` increments "Fully implemented" by 2 (from 118 to 120) and decrements "Missing" by 2 (from 15 to 13); the coverage percentage rises from 88.7% to **90.2%** (120 / 133).
    - The **§8.6 Double-Number bonus** table at `ans-forth-core-compliance.md:359-374`: the `D*` row flips from `10.5` to `Implemented (`double.asm:<line>`)`. The `(13 §8.6 additions planned; none on the §6.1 critical path.)` footer stays factually correct — 11 of 13 §8.6 words become Implemented after this story (M+ D+ D- DNEGATE DABS D= D< DMAX DMIN from 10.4 + D>S from 10.3 + D* from 10.5 = 11 of 13; the remaining 2 — `D.`, `D.R` — belong to Story 10.8).
    - The **Epic-10 closure plan row** for 10.5 (`ans-forth-core-compliance.md:43`) updates from `2 (`M*` `UM*`)` to `2 ✓ (`M*` `UM*`) | §8.6 bonus `D*` Complete` (or equivalent "Complete" marker matching the 10.4 row's style at `ans-forth-core-compliance.md:42`).
    - The Gap Classification table at `ans-forth-core-compliance.md:23-28` decrements "(b) Oversight — missing subsystem" by 2 (13 → 11) to reflect the two §6.1 words moving to Implemented; other rows unchanged. (Check this matches reality — the subsystem labels may be grouped; if `M*` and `UM*` are counted under a different sub-label, update that sub-label's count instead.)

12. **Given** CCD-4 (Per-Epic Benchmark Gate, `architecture.md:218-226`) sets the benchmark / size-delta gate at **Story 10.10**, not here, **When** this story completes, **Then** the ROM size delta is recorded in the Completion Notes (informational — no gate). Rough estimate: `UM*` ~40 bytes (16-iteration shift-and-add loop, similar to single-cell `*` at `arithmetic.asm:86-106` which is ~35 bytes, plus the extra-wide accumulator register dance) + `M*` ~40 bytes (unsigned `UM*` body + ~20 bytes of sign-tracking negate-and-remember wrapper) + `D*` ~60-80 bytes (three `UM*` intermediate products + cross-term shift-and-add assembly, OR a DEFWORD thread of ~12 cells = ~24 bytes plus header) + dictionary headers (3 × ~12 bytes) ~36 bytes = **~160-200 bytes** net. Acceptable margin: ±50%. Story 10.10 measures formally.

## Tasks / Subtasks

- [x] **Task 1 — Verify §-numbers against DPANS94 + scope sanity** (AC: #1–#3, #7, #11)
  - [x] 1.1 Verify `UM* §6.1.2360`, `M* §6.1.1810`, `D* §8.6.1090` by cross-reference to `docs/ans-forth-core-compliance.md:111-112,370` and (if unsure) forth-standard.org. **Do not enumerate from memory.**
  - [x] 1.2 Confirm `M*` and `UM*` are §6.1 Core (count toward FR15 / NFR10) and `D*` is §8.6 bonus (does not count toward §6.1 target but lights up the §8.6 table end-to-end). Compliance doc summary at `ans-forth-core-compliance.md:11-18` should increment "Implemented" by **2**, not 3, after this story.
  - [x] 1.3 Confirm CCD-3 template matches `src/double.asm:17-22, 44-47, 67-72, 84-89, 99-104, 124-129, 149-153, 167-174, 183-189, 211-217, 237-240, 263-268, 287-293, 308-313, 339-348, 375-380, 396-402` (Stories 10.2 + 10.3 + 10.4 house style).

- [x] **Task 2 — Implement `UM*` in `src/double.asm`** (AC: #1, #4, #5, #6, #7)
  - [x] 2.1 Append DEFCODE block after `w_D_MIN` (currently ends at `src/double.asm:417`; the `double_ip_stash` cell at 423 must remain the file's final item — insert new code **before** `double_ip_stash`).
  - [x] 2.2 `CALL check_underflow_2` at entry (AC #5).
  - [x] 2.3 Body: 16-iteration shift-and-add building a 32-bit accumulator. Pattern options:
    - **Option A (HL:DE accumulator, BC=multiplier, scratch DE):** save IP to `double_ip_stash`; POP multiplicand into HL; load accumulator HL:DE = 0:0; loop 16 times, each iteration: shift HL:DE left (SLA E / RL D / RL L / RL H), shift BC left (SLA C / RL B), if carry-out of BC is set then add multiplicand into accumulator (ADD DE,<multiplicand-lo> / ADC HL,<multiplicand-hi> — but multiplicand is 16-bit so hi=0 and this becomes "ADC HL, 0" via ADC HL,BC-style trick with BC cleared). Exit: PUSH HL (high cell); BC = DE (low cell → TOS); restore IP.
    - **Option B (HL = high, BC = low, multiplicand held in shadow):** use EXX to park multiplicand in BC' and cycle count in B'; main set holds running accumulator HL:<something>. Similar structure but leverages the 10.2 `2SWAP` EXX-sandwich idiom at `src/double.asm:111-122`.
    - **Option C (re-use single-cell `*`'s inner loop):** `src/arithmetic.asm:94-102` is the 16-bit shift-and-add. Widening to 32 bits requires an extra register pair for the accumulator high half. Simplest to write from scratch in Option A style; re-use as conceptual template, not by calling the existing routine (which truncates).
    - **Recommended:** Option A. Single DEFCODE, no EXX, ~40 bytes. Mirrors the style of the existing `*` in arithmetic.asm but with a 32-bit accumulator. Memory-stash IP to `double_ip_stash` per the D+ / D- precedent.
  - [x] 2.4 CCD-3 comment: `; ANS Forth 1994 §6.1.2360   UM*   — unsigned mixed multiply (single × single → double)`.
  - [x] 2.5 Stack-effect comment on header line: `; UM* ( u1 u2 -- ud )`.

- [x] **Task 3 — Implement `M*` in `src/double.asm`** (AC: #2, #4, #5, #6, #7)
  - [x] 3.1 DEFCODE block after `w_U_M_STAR`. Body approach options:
    - **Option A (negate-UM*-negate):** track sign of `n1 × n2` in a sticky bit (A register low bit), conditionally negate each operand to absolute value before entering a `UM*`-equivalent inner loop, then conditionally negate the double result if the sign bit is set. `DNEGATE`-equivalent for the result; single-cell negate for each operand. Roughly 20 bytes of pre/post around the shared inner loop. **Call / inline / or refactor `UM*`'s inner loop as a shared sub-routine** — dev's choice:
      - **Sub-option A1 (refactor):** factor the 16-iteration shift-and-add body out of `UM*` as a static sub-routine `umstar_core` with a documented register contract (e.g., HL:DE = 0:0 on entry, BC = multiplier, multiplicand already in a shadow register or local scratch). Both `UM*` and `M*` call it. DRY-est; ~10 bytes saved total vs duplicating.
      - **Sub-option A2 (inline / fall-through):** `M*`'s body flows into the same inner-loop bytes as `UM*`'s via a shared label — e.g., `M*` sign-extracts, negates operands, then jumps into the middle of `UM*`'s body. Complicates labels in the DEFCODE; workable but fragile.
      - **Sub-option A3 (duplicate):** independent inner loops. Simplest; ~25 extra bytes.
    - **Option B (DEFWORD on UM*):** compile `M*` as `2DUP XOR 0< >R ABS SWAP ABS SWAP UM* R> IF DNEGATE THEN` — a Forth colon body. Correctness follows from UM* and DNEGATE. Cost: ~14 cells in the DEFWORD body = ~28 bytes + ~12-byte header = ~40 bytes. Speed hit is irrelevant (M* is not in an inner loop for anything in antforth today). **This is probably the shortest correct path and matches E10-D3's permission for thin-wrapper words.** Precedent: Story 10.4 DMAX/DMIN at `src/double.asm:382-417` — both DEFWORDs over D<, same pattern.
    - **Recommended:** Option B (DEFWORD). Copy the DMAX/DMIN template exactly. One less piece of sign-tracking assembly to get wrong. The adversarial review should still catch the `-32768 -32768 M*` case which is the single trickiest input because `ABS(-32768)` returns `-32768` (fixed-point trap in single-cell ABS).
  - [x] 3.2 **Watch the `-32768 × -32768` trap.** Single-cell `ABS` of `$8000` returns `$8000` unchanged (Z80 single-cell fixed-point case). If M* is built as `ABS SWAP ABS SWAP UM* ... DNEGATE` under Option B, the input `-32768 -32768 M*` will compute `$8000 $8000 UM*` = `$40000000` with sign flag = `sign(-1) XOR sign(-1) = 0` → no final DNEGATE → result `$40000000 = 16384:0` which is the CORRECT answer for `-32768 × -32768 = +1073741824`. Verify this flows through by hand, and ensure the sign-XOR logic genuinely uses `sign(n)` = `bit 15`, not some derived "is ABS(n) == n" check. Test case `-32768 -32768 M* .S` → `<2> 16384 0` is non-negotiable for AC #2.
  - [x] 3.3 `CALL check_underflow_2` at entry (DEFCODE option) OR inherit from the first word in the DEFWORD thread (DEFWORD option — `2DUP` needs 2, the body's first word provides the guard).
  - [x] 3.4 CCD-3 comment: `; ANS Forth 1994 §6.1.1810   M*   — signed mixed multiply (single × single → double)`.
  - [x] 3.5 Stack-effect comment on header line: `; M* ( n1 n2 -- d )`.

- [x] **Task 4 — Implement `D*` in `src/double.asm`** (AC: #3, #4, #5, #6, #7)
  - [x] 4.1 DEFCODE or DEFWORD block after `w_M_STAR`. Implementation approach options:
    - **Option A (three-UM* DEFCODE):** direct inline assembly. Given `d1 = (a₁:hi, b₁:lo)`, `d2 = (a₂:hi, b₂:lo)`, compute:
      1. `full_product_lo = b₁ × b₂` via a `UM*`-equivalent inner loop → 32-bit (hi_carry, lo)
      2. `cross = b₁ × a₂ + a₁ × b₂` (low 16 bits only — upper 16 bits fall beyond 2³²)
      3. final high = `full_product_hi + cross` (low 16 bits)
      4. final low = `full_product_lo`
      Carry propagation out of step 3 also falls beyond 2³² and is discarded.
      Register pressure: 4 input cells + 2-cell accumulator + 16-bit cross-term + loop counter. Requires EXX or heavy memory-stash. ~70 bytes.
    - **Option B (DEFWORD composing UM* + single-cell * + cross-term):** compile D* as:
      ```
      : D*  ( d1 d2 -- d3 )
          >R                \ stash d2-hi, R: ( -- a2 )
          2DUP              \ ( a1 b1 a2 b2 a1 b1 -- ) wait — need careful stack choreography
          ...
      ```
      Actually, the clean DEFWORD for `D* = low32(d1 × d2)` is:
      ```
      : D*  ( a1 b1 a2 b2 -- lo hi' )
          2DUP UM*          \ full b1*b2 on stack under the doubles; ( a1 b1 a2 b2 c_hi c_lo )
          ...
      ```
      This gets complex quickly. The Forth community usually writes D* as assembly because the stack choreography for a three-partial-product sum is noisy in colon form. Estimate: 20-30 cells in DEFWORD body = 40-60 bytes.
    - **Option C (call M* + cross-term helper):** factor the cross-term logic out; maybe share with a future `*/` implementation in Story 10.9. Probably premature abstraction — the cross-term is small.
    - **Option D (single-cell helper `cross_term`):** a new private assembly subroutine that computes `b × a'` truncated to a single cell (the upper 16 bits of `b × a'` are discarded because they contribute beyond 2³² in the D* context). This is just the existing single-cell `*` op (truncating multiply) — already exists at `src/arithmetic.asm:86-106`. Reuse it.
      ```
      D* ≡ UM*(b1,b2) + (single_star(b1,a2) + single_star(a1,b2)) shifted into the high cell
      ```
      Since `single_star` already truncates to 16 bits, the cross-term is just `(b1×a2 + a1×b2) & $FFFF`, which is added to `full_product_hi` (the high 16 bits of `UM*(b1,b2)`).
      Clean DEFWORD formulation:
      ```
      : D*  ( a1 b1 a2 b2 -- lo hi )
          2DUP UM*          \ ( a1 b1 a2 b2 hi_full lo_full )
          2SWAP             \ ( a1 b1 hi_full lo_full a2 b2 )
          SWAP              \ ( a1 b1 hi_full lo_full b2 a2 )   ← careful
          ...
      ```
      — Still complex. Dev should prototype this on paper first.
    - **Recommended:** **Option A** (DEFCODE with three explicit 16×16-bit multiplies), because:
      1. It has the cleanest register dance — all operands live in named registers during the computation.
      2. Performance is better (no NEXT overhead between partial products).
      3. D* is not heavily used by upstream words (only Story 10.9's `*/` would build on it, and `*/` uses `M*` + `SM/REM` — not `D*`).
      4. Byte count is similar to DEFWORD option once the stack-juggle cells are counted.
      A reasonable structure:
      ```
      w_D_STAR_cf:
          CALL check_underflow_4
          LD (double_ip_stash), DE
          ; stack now: ( a1 b1 a2 b2 -- ) with b2 in BC
          ; Step 1: b1 × b2 (UM*) → full 32-bit in DE:HL (or EXX partition)
          ; Step 2: b1 × a2 (single-cell truncating *) → HL or scratch
          ; Step 3: a1 × b2 (single-cell truncating *) → HL or scratch
          ; Step 4: high_result = high(Step 1) + Step 2 + Step 3, low_result = low(Step 1)
          ...
      ```
      Expect ~70-90 bytes. If it sprawls, fall back to Option B (DEFWORD) — correctness matters more than code size for this story.
  - [x] 4.2 `CALL check_underflow_4` at entry (DEFCODE option) OR inherit from the first word in the DEFWORD thread.
  - [x] 4.3 CCD-3 comment: `; ANS Forth 1994 §8.6.1090   D*   — double-cell signed multiply (truncating)`.
  - [x] 4.4 Stack-effect comment on header line: `; D* ( d1 d2 -- d3 )`.
  - [x] 4.5 **Two's-complement identity check.** The test `-1 -1 -1 -1 D* .S` → `<2> 0 1` is the cleanest verification that the unsigned/signed convergence works: in signed two's-complement, −1 × −1 = +1, and the algebraic formula `low32(A × B)` (treating A and B as unsigned) produces the same bit pattern. If this test fails, the implementation has a sign-propagation error that shouldn't be there — `D*` is a pure-unsigned truncating multiply, no sign tracking required.

- [x] **Task 5 — Extend `tests/double_tests.fth`** (AC: #8, #9)
  - [x] 5.1 Append section header: `\ === Story 10.5 double-cell multiplication (UM*, M*, D*) ===`.
  - [x] 5.2 Sub-section headers per word: `\ --- UM* (§6.1.2360) unsigned mixed multiply ---`, `\ --- M* (§6.1.1810) signed mixed multiply ---`, `\ --- D* (§8.6.1090) double-cell signed multiply (truncating) ---`, `\ --- Story 10.5 underflow recovery ---`.
  - [x] 5.3 Forth one-liners with `\ expect: <fragment>` comments for every AC #9 scenario. For multi-cell outputs, use `.S 2DROP` pattern to surface a stable `.S` fragment (as in Story 10.4 tests 122-180).
  - [x] 5.4 Total ≥ 21 test scenarios, covering at minimum the AC #9 list (6 UM* + 8 M* + 7 D* + 3 underflow). Delivered 24.

- [x] **Task 6 — Wire up Makefile `test-repl` entries** (AC: #8, #9, #10)
  - [x] 6.1 Section banner: `@# --- Story 10.5 double-cell multiplication (502..<end>) — DPANS94 §6.1.{1810,2360} + §8.6.1090 ---`.
  - [x] 6.2 Canonical `printf … | $(IZCPM) $(TARGET) | grep -q` pattern (see tests 450..501 for the exact template — Story 10.4's block is the most recent / most relevant precedent).
  - [x] 6.3 Numbering: start at **502** (Story 10.4 closed at 501 post-code-review). Use contiguous integer numbering; no gaps. Range delivered: 502..525.
  - [x] 6.4 Watch for `printf` option-terminator gotcha with negative literals: `printf '-1 -1 M* .S\r\nBYE\r\n' | ...` MAY need `printf -- '-1 -1 M* .S\r\nBYE\r\n' | ...` because shells can interpret the leading `-1` as a flag. Story 10.4's tests 453, 459, 462, 466, 467 all use `--`; copy that convention.
  - [x] 6.5 Watch for unescaped `$<hex>` in PASS banners: any literal `$FFFF` or `$8000` in a PASS/FAIL echo line must be written as `$$FFFF` / `$$8000` to survive the Makefile → shell double-expansion. Story 10.4's code-review pass caught six such issues; do not repeat. (Test *inputs* in the `printf` body are fine — the shell there sees `$FFFF` as a literal, not a variable, because there's no matching `${FFFF}` expansion — but echo lines going through Makefile interpolation need the `$$`.)
  - [x] 6.6 Underflow tests: one per word at its minimum insufficient depth (DEPTH = N − 1). Follow the Story 10.4 pattern at `Makefile:4326-4382`.

- [x] **Task 7 — Regression verification** (AC: #10, #12)
  - [x] 7.1 `make clean && make test` — must PASS.
  - [x] 7.2 `make test-repl` — must show `N` unique test numbers PASS, 0 FAIL, where `N = 501 + <count of new entries>`. Result: 525 distinct PASS, 0 FAIL.
  - [x] 7.3 Spot-check regression on adjacent words: `*`, `D+`, `D-`, `M+`, `DNEGATE`, `DABS`, `D=`, `D<`, `S>D`, `D>S`, `2@`, `2!`, `+ - NEGATE ABS = <` — all output byte-identical to pre-story baseline. Confirmed via full regression (tests 1..501 unchanged).
  - [x] 7.4 ROM size delta: record pre-edit and post-edit `.com` size in Completion Notes (informational per AC #12; CCD-4 gate is 10.10). Pre 15472 → post 15606 = +134 bytes.

- [x] **Task 8 — Update `docs/ans-forth-core-compliance.md`** (AC: #11)
  - [x] 8.1 In the §6.1 Core "Double-Cell and Mixed-Precision Multiplication" table at `ans-forth-core-compliance.md:107-112`, flip both rows (`M*`, `UM*`) from `**Gap → Story 10.5**` to `Implemented (`double.asm:<line>`)`. Line numbers resolve at write-time.
  - [x] 8.2 In the §6.1 Summary table at `ans-forth-core-compliance.md:11-18`, update:
    - "Fully implemented" 118 → 120
    - "Missing" 15 → 13
    - Coverage "118 / 133" → "120 / 133"; percentage 88.7% → 90.2%
  - [x] 8.3 In the Gap Classification table at `ans-forth-core-compliance.md:23-28`, decrement "(b) Oversight — missing subsystem" by 2 (13 → 11). Verify the decrement goes to the correct sub-category — the doc's "Missing subsystem: Double-cell operations — 14 §6.1 words" at line 304 will now read "12 §6.1 words" (or equivalent); scan for any count references that need updating. (Used `5 §6.1 words remaining` since that is the accurate post-Story-10.5 figure — 14 was the pre-Epic-10 subsystem total; remaining gap is FM/MOD SM/REM UM/MOD `*/` `*/MOD` = 5.)
  - [x] 8.4 In the §8.6 Double-Number bonus table at `ans-forth-core-compliance.md:370`, flip the `D*` row from `10.5` to `Implemented (`double.asm:<line>`)`.
  - [x] 8.5 Update the Epic-10 closure plan row for 10.5 at `ans-forth-core-compliance.md:43`: from `| 10.5 | Double multiplication | 2 (`M*` `UM*`) | `D*` is §8.6 bonus |` to something like `| 10.5 | Double multiplication | 2 ✓ (`M*` `UM*`) | §8.6 bonus `D*` Complete |` matching the Story-10.4 row's style at `ans-forth-core-compliance.md:42`.
  - [x] 8.6 Update the "big gaps" observation paragraph at `ans-forth-core-compliance.md:407` — the "14 §6.1 words" count for the double-cell subsystem drops to 12 after this story, and the bullet list of feeding stories can note 10.5 as done.
  - [x] 8.7 Do NOT touch §6.1 tables unrelated to multiplication — the Summary-table numbers are the only non-multiplication edits.

- [x] **Task 9 — Self-review (adversarial) + code-review handoff** (AC: all)
  - [x] 9.1 Before marking the story complete, run an **adversarial self-review** (per project memory `feedback_adversarial_review.md`) looking specifically for:
    - **`UM*` shift-and-add off-by-one:** 16 iterations, not 15 or 17; test `$FFFF $FFFF UM*` = `$FFFE_0001` catches a one-bit drift immediately.
    - **`UM*` accumulator-shift direction:** shifting left (ADD HL,HL) not right; test `1 1 UM*` = `( 0 1 )` vs the wrong-direction `( 1 0 )` is diagnostic.
    - **`M*` `-32768 -32768` fixed-point trap:** if built on ABS + UM* + DNEGATE, the `ABS(-32768) = -32768` singularity must collapse cleanly because sign-XOR gives positive; result must be `$40000000 = ( 16384 0 )` not garbage.
    - **`D*` two's-complement identity:** `-1 -1 -1 -1 D*` must return `( 0 1 )`, not `( -1 -1 )` or `( 0 -1 )`. This is the cleanest "did I get the unsigned-arithmetic-reinterpreted-as-signed thing right" check.
    - **`D*` cross-term overflow discard:** only the low 16 bits of `(b₁ × a₂ + a₁ × b₂)` contribute to the result; any higher bits fall off 2³² and must be silently discarded. Test `0 1 -1 0 D*` → `( -1 0 )` verifies the cross-term path carries correctly (b₁=1, a₂=0 → first cross = 0; a₁=0, b₂=0 → second cross = 0; UM*(b₁=1, b₂=0) = (0,0); high = 0 + 0 + 0 = 0; low = 0 — but that's the WRONG expected, so this test actually exercises a DIFFERENT path). Check carefully: `d1 = (a₁=0, b₁=1) = 1`, `d2 = (a₂=-1, b₂=0) = $FFFF0000` as unsigned = 4294901760; product = 4294901760 mod 2³² = $FFFF0000 = high $FFFF = -1 low 0. So `D* = ( -1 0 )`. Correct. The cross-term contribution: `b₁×a₂ = 1 × $FFFF = $FFFF`, `a₁×b₂ = 0 × 0 = 0`, sum = $FFFF. UM*(b₁, b₂) = UM*(1, 0) = (0, 0). High = 0 + $FFFF = $FFFF = -1. Low = 0. ✓
    - **Check-underflow N mismatches** (Stories 10.3 and 10.4 both had related trap cases — recompute N per-word from the AC #5 table, don't guess; `UM*` and `M*` take TWO cells each = `_2`, `D*` takes FOUR = `_4`).
    - **Missing CCD-3 §-number citations, drifted §-numbers, or stack-effect comments.**
    - **Regressions in single-cell `* + - NEGATE ABS = < MAX MIN`** — those share mental pattern with the new ones and can be accidentally altered in cross-editing.
  - [x] 9.2 Fill Completion Notes with plain diagnostic prose (per memory `feedback_plain_qa_language.md`) — measured values, gates, reasons, no florid framing.
  - [x] 9.3 Different-LLM second-pass review recommended — `/bmad-bmm-code-review 10.5` is the natural hook. Stories 10.2, 10.3, 10.4 all caught real defects in that pass (10.3 off-by-one underflow; 10.4 wrong-arithmetic AC boundary + Makefile `$` escaping). This story's trap-rich surface (the `-32768 × -32768` fixed-point case for M*, the two's-complement identity for D*, the cross-term shift accounting for D*) is a similar target.

## Dev Notes

### Story Purpose and Epic-10 Position

Story 10.5 is the **fourth implementation story in Epic 10** and closes the multiplication leg of the double-cell subsystem. Two things fall out of this story that subsequent stories depend on:

1. **`M*` existence** — directly required by Story 10.9's `*/` and `*/MOD`: the canonical ANS implementation of `*/` is `M* SM/REM`, where `M*` produces the mixed double-precision intermediate and `SM/REM` (Story 10.6) consumes it. `*/` is on the §6.1 critical path to 100% Core (Story 10.9 dependency chain).
2. **`UM*` existence** — Story 10.7's pictured numeric output inner loop uses `UM/MOD` (Story 10.6) which can be derived from `UM*` or written independently; several ANS reference implementations of pictured output use `UM*` transitively. Less tight a coupling than `M*`'s, but still present.

`D*` is §8.6 bonus — not on the §6.1 critical path. Its inclusion here is convenience: the three multiplication words clump naturally, and `D*` rounds out the §8.6 Double-Number wordset's arithmetic leg. After 10.5, only `D.` / `D.R` (both §8.6, routed to Story 10.8) remain in the §8.6 bonus scope.

### Architectural Decisions That Apply to This Story

From `_bmad-output/planning-artifacts/architecture.md`:

- **§206-216 CCD-3 (Standards-Citation Discipline):** every word cites its DPANS94 §-number. Format is non-negotiable — match Stories 10.2 / 10.3 / 10.4's template (`src/double.asm:17-22, 44-47, 67-72, 84-89, 99-104, 124-129, 149-153, 167-174, 183-189, 211-217, 237-240, 263-268, 287-293, 308-313, 339-348, 375-380, 396-402`).
- **§218-226 CCD-4 (Per-Epic Benchmark Gate):** gate is at **Story 10.10**, not here. Record ROM delta informationally in Completion Notes.
- **§248-252 E10-D1 (Byte-Order):** low cell on TOS, high cell below. For `UM*` and `M*`, the single operand `u2`/`n2` = BC (TOS). For `D*`, the stack on entry is `( a₁-hi b₁-lo a₂-hi b₂-lo )` with `b₂-lo = BC`. For all three, on exit, result low cell = BC (TOS), high cell = second-on-stack. Non-negotiable — don't flip the convention for "convenience".
- **§260-264 E10-D3 (Implementation split):** multiplication primitives are arithmetically hot but not in antforth's inner interpreter — they're called by user Forth code. Implement the inner loop (`UM*`) in assembly; `M*` and `D*` can be either assembly or DEFWORD as the dev prefers, per E10-D3's thin-wrapper permission. **Option-B DEFWORD is permitted** for `M*`; **Option-A DEFCODE is recommended** for `D*` (see Task 4.1).
- **§434-447 Source-file organisation:** `src/double.asm` is the home for Epic-10 double-cell primitives — all three Story-10.5 words live there.

### BC-as-TOS Convention (Project Memory: `project_tos_in_register.md`)

Every existing stack / arithmetic primitive treats BC as TOS on entry and exit:

| Word | Entry BC | Exit BC |
|---|---|---|
| `UM*` | `u2` | `ud-low` |
| `M*` | `n2` | `d-low` |
| `D*` | `b₂` (low of `d2`) | `d₃-low` |

`DE = IP` throughout. Any body that needs DE for arithmetic must `EXX`-bracket or memory-stash IP via the existing `double_ip_stash` cell (`src/double.asm:423`). Precedents:

- **Memory-stash:** `src/double.asm:223,246,274,319,354` (D+, D-, DNEGATE, D=, D<). This is the established 10.4 pattern; use it.
- **PUSH/POP IP:** `src/arithmetic.asm:90,105` (single-cell `*`). Also workable; `double_ip_stash` is cheaper than PUSH/POP by a couple of cycles and uses zero extra rstack room.
- **EXX-sandwich:** `src/double.asm:110-122` (2SWAP). Use when you need the shadow BC'/DE'/HL' set as full second-class registers; probably overkill for this story.

For this story, memory-stash is likely the cleaner option (all three words are register-pressured but none need the full shadow set).

### Stories 10.2 / 10.3 / 10.4 Carry-Forwards

From `_bmad-output/implementation-artifacts/10-{2,3,4}-*.md` (all `done`):

1. **CCD-3 template locked.** Format: `; ANS Forth 1994 §<n>   <word>   — <note>`. Every §-number verified at write-time.
2. **`check_underflow_2` and `check_underflow_4` exist** in `src/system.asm:~326-362`. Use them directly; **do not introduce new helpers**. `N` = total user cells consumed (including BC), not SP-only cells.
3. **`src/double.asm` file is appended-to, not rewritten.** Add the three new words **before** the `double_ip_stash` cell at the tail (keep that cell as the file's final item so its address stays stable).
4. **Tests live in `tests/double_tests.fth`** — extend, don't create a new file. Section header style: `\ === Story 10.X <topic> ===`.
5. **Makefile test numbering is contiguous.** Current max is **501** (post-Story-10.4-code-review). Do not leave gaps. Start at 502.
6. **Different-LLM second-pass review is expected** for Epic-10 stories that write new code. Stories 10.2 / 10.3 / 10.4 each caught defects in that pass that self-review missed. This story's trap-rich surface (`-32768 × -32768` for M*; two's-complement identity for D*; shift-loop iteration count for UM*) is a similar target.
7. **`double_ip_stash` is the one shared scratch cell.** Never held across NEXT; never re-entered. Safe to reuse across all three new words. Do not add a second scratch cell unless one shared cell is demonstrably insufficient (highly unlikely for this story's shape).

### Stack-Underflow Discipline

Pre-Epic-11 convention: `check_underflow_N` at entry, falls through to ABORT on fail, REPL recovers via the existing ABORT-path. Epic 11 will migrate every site to `THROW -4` wholesale — **do NOT pre-migrate**.

Per-word mapping table is in AC #5 above. **The rule is: `N = total user cells consumed` (including BC).** Story 10.3's `H1` finding was entirely caused by applying the wrong rule — do not repeat the mistake.

### Correctness Traps (by word)

**`UM*`:**

- **Loop iteration count:** exactly 16. Test case `$FFFF $FFFF UM*` → `( -2 1 )` (= $FFFE_0001) catches a one-bit drift immediately because any 15-or-17-iteration bug produces a result off by a factor of 2 or ½. This is the canonical regression test for any shift-and-add multiplier.
- **Accumulator width:** 32 bits. Single-cell `*` at `src/arithmetic.asm:86-106` uses 16-bit HL — widening for `UM*` requires HL:DE or HL:<scratch-memory> as the running accumulator. If the accumulator is only 16 bits, the high word of the result is lost silently and you get a truncated answer (same as single-cell `*`). Test `$100 $100 UM*` = `( 1 0 )` catches this — 256 × 256 = 65536 doesn't fit in 16 bits, so a 16-bit accumulator gives `( 0 0 )`.
- **Shift direction:** accumulator shifts LEFT (into higher bits) as the multiplier shifts left. A right-shift is the division template, not multiplication.
- **Carry bit on partial adds:** when adding multiplicand into accumulator, a carry from the low-half ADD must propagate to the high-half ADC. Standard Z80 idiom `ADD HL, rr` followed by `ADC HL, rr'` where rr / rr' are the two halves of a wide operand — except here the multiplicand is only 16 bits (no high half), so the ADC is against 0 (use `LD rr', 0` then `ADC HL, rr'`, or more compactly `EX DE, HL / ADC HL, 0` if DE is the high half of the accumulator). Work this out on paper before typing.
- **Carry preservation across POPs:** as in D+/D-, POP preserves CF on Z80; arithmetic ops (ADD, SUB, OR) destroy it. Order operations so the CF from a low-half add survives to the high-half ADC.

**`M*`:**

- **Sign-XOR:** the sign of `n₁ × n₂` is `sign(n₁) XOR sign(n₂)`. Extract sign via bit 7 of the high byte (B register of each operand). Do NOT use `<0` tests that include zero — zero has sign bit 0 and the XOR still works correctly (`0 XOR 0 = 0` = positive, correct; `0 XOR 1 = 1` = negative, but `0 × n < 0` is false — the multiply returns `( 0 0 )` regardless of the sign-XOR outcome, so the final DNEGATE branch is harmlessly taken on a zero result, which is still `( 0 0 )`). Self-check: for `0 -5 M*`, the sign-XOR returns 1 (positive XOR negative = negative flag set); UM* on absolute values gives `( 0 0 )`; DNEGATE of `( 0 0 )` is `( 0 0 )`. ✓
- **`$8000` fixed-point trap:** single-cell `ABS($8000)` returns `$8000` (Z80 two's-complement fixed-point case). If M* is built on `ABS SWAP ABS SWAP UM* ... DNEGATE`, the input `-32768 -32768 M*` produces: `ABS(-32768) = -32768 = $8000`; `UM*($8000, $8000) = $40000000` (treating $8000 as unsigned = 32768); sign-XOR = `sign(-1) XOR sign(-1) = 0` (both negative → positive result); no final DNEGATE; result = `$40000000 = ( 16384 0 )`. Which is the correct `-32768 × -32768 = +1073741824`. **This works BY ACCIDENT** — the fixed-point value's "absolute" interpretation as unsigned still gives the right magnitude when multiplied unsigned. Verify end-to-end with the test case; do not rationalise any deviation.
- **Sign-XOR must use bit 15 of operand, not bit 15 of absolute-value result:** if you compute sign from the ABS'd operand, you've lost the information. Extract the sign BEFORE the ABS.

**`D*`:**

- **Two's-complement unification:** low-32-bit product of two signed doubles equals low-32-bit product of the same bit patterns treated as unsigned. NO sign tracking required for D*. This is the single cleanest aspect of the word. Test `-1 -1 -1 -1 D*` → `( 0 1 )` confirms: d₁ = $FFFFFFFF = unsigned 2³²−1 = signed −1; d₁² = (2³²−1)² = 2⁶⁴ − 2³³ + 1; low 32 bits = `low32(2⁶⁴ − 2³³ + 1) = 0 − 0 + 1 = 1` (because 2⁶⁴ ≡ 0, 2³³ ≡ 0 mod 2³²) → correct ✓.
- **Cross-term formula:** `D* = low32(b₁×b₂) + ((b₁×a₂ + a₁×b₂) mod 2¹⁶) × 2¹⁶`. The middle term uses only the LOW 16 bits of `b₁×a₂` and `a₁×b₂` — the HIGH 16 bits fall beyond 2³² and are discarded silently. The existing single-cell `*` (`src/arithmetic.asm:86-106`) is exactly a 16×16 → low-16-bits truncating multiply; call it or inline its body.
- **Full multiply is NOT required:** D* is TRUNCATING. Do not compute the full 64-bit product and then truncate — compute only what's needed (three 16×16 multiplies, two of which feed only the low 16 bits).
- **Carry propagation between partial products:** the three partial products sum with potential carries: `high_result = high(b₁×b₂ as UM*) + low(b₁×a₂) + low(a₁×b₂)`, where each addend is 16 bits and the sum is truncated to 16 bits. Any carry out of this 16-bit sum falls beyond 2³² and is discarded. Verify with the `0 1 -1 0 D*` test case (see Task 9.1).

### Epic 10 Dependencies Not Yet Landed

Nothing blocks Story 10.5:

- Epic 1–8 parameter-stack + memory + arithmetic primitives ✓
- Story 10.1 gap survey ✓ (assigned `M*` `UM*` `D*` to 10.5)
- Story 10.2 double-cell stack foundation ✓ (`src/double.asm` file, CCD-3 template, `check_underflow_N` helpers, test file, `2OVER 2SWAP 2DROP 2DUP` available for DEFWORD wrappers)
- Story 10.3 single↔double conversions ✓ (`S>D` if M* builds on `S>D D+ D+ ...` — not the recommended path, but available)
- Story 10.4 double arithmetic ✓ (`DNEGATE` available for Option-B M*; `D+` available for any accumulator-based D* variant; `double_ip_stash` cell to reuse)

Story 10.6 (double/mixed division) uses `D-` and `D<` from Story 10.4 directly and does NOT depend on Story 10.5. Story 10.9 (`*/`, `*/MOD`) depends on **this** story's `M*` and Story 10.6's `SM/REM`.

### Epic 10 Retro — Action Items Relevant to This Story

From Stories 10.2 / 10.3 / 10.4's code-review passes and the project memories they established / reinforced:

- **Plain QA prose:** apply to Completion Notes — state measured values, gates, reasons plainly (memory `feedback_plain_qa_language.md`).
- **AC-drafting trace-check:** every AC in this story maps to at least one Makefile test entry. Traceability is explicit in AC #9.
- **Adversarial self-review that actually finds things:** Story 10.4's dev self-review declared findings; the code-review pass found more (the AC #2 wrong-arithmetic, the six `$`-escaping bugs, the missing word list in the compliance-doc row). For this story, the obvious attack surfaces are `UM*` (loop count / accumulator width), `M*` (`-32768 × -32768`), `D*` (two's-complement identity + cross-term carry), and `check_underflow_N` mapping. **Assume your self-review missed something. The code-review pass is the second chance.**
- **Makefile `$$` escaping:** any hex literal or `$`-prefixed string in an echo'd PASS/FAIL banner needs `$$` to survive Make's first-pass expansion into the shell. Story 10.4 code-review fix at tests ~455, 459, 462, 466, 467 (where the hex literal appears in the banner, not just in the printf input).
- **`printf --` option terminator:** tests whose input begins with a `-` literal need `printf --` to prevent the shell from interpreting the leading dash as a flag. Story 10.4 tests 453, 459, 462, 466, 467 use this pattern.

### Project Structure Notes

- **Files touched:**
  - `src/double.asm` (EDIT — append 3 DEFCODE/DEFWORD blocks before `double_ip_stash`)
  - `tests/double_tests.fth` (EDIT — append Story 10.5 section)
  - `Makefile` (EDIT — new `test-repl` entries starting at 502)
  - `docs/ans-forth-core-compliance.md` (EDIT — 2 §6.1 row flips + 1 §8.6 row flip + Summary-table increment + Gap Classification decrement + Epic-10 closure-plan row update + big-gaps paragraph count update)
  - `_bmad-output/implementation-artifacts/sprint-status.yaml` (EDIT — status transitions, handled by dev-story workflow)
  - `_bmad-output/implementation-artifacts/10-5-double-multiplication.md` (this file — Dev Agent Record + Completion Notes at close)
- **No new files created.** Stories 10.2–10.4 set up `src/double.asm` and `tests/double_tests.fth`; Story 10.5 extends both.
- **Alignment with unified structure:** all edits sit in established homes per `architecture.md:434-447`. No source-tree structural change.
- **Detected conflicts or variances:** none at story-write time. The §-numbers (`M* §6.1.1810`, `UM* §6.1.2360`, `D* §8.6.1090`) are consistent across epics.md (§8.6 noted in line 534-537), architecture.md, and the compliance doc. Verify each against DPANS94 at write-time anyway (Task 1.1). Cross-check: Story 10.4 surfaced one upstream typo (`§8.6.1.1830` in epics.md vs canonical `§8.6.1830`); scan 10.5's epics.md entries (`epics.md:518-545`) for similar drift before committing CCD-3 comments.

### References

- **Authoritative standard:**
  - DPANS94 §6.1.1810 `M*` — signed mixed multiply (single × single → double)
  - DPANS94 §6.1.2360 `UM*` — unsigned mixed multiply (single × single → double)
  - DPANS94 §8.6.1090 `D*` — signed double multiply (truncating to low 32 bits)
  - **Verify all three §-numbers at implementation time** against DPANS94 / forth-standard.org before committing comments.
- **Planning artefacts:**
  - `_bmad-output/planning-artifacts/epics.md:518-544` — Story 10.5 epic spec
  - `_bmad-output/planning-artifacts/epics.md:426-448` — Epic 10 overview
  - `_bmad-output/planning-artifacts/architecture.md:246-264` — E10-D1 / E10-D2 / E10-D3 decisions
  - `_bmad-output/planning-artifacts/architecture.md:206-216` — CCD-3 Standards-Citation Discipline
  - `_bmad-output/planning-artifacts/architecture.md:218-226` — CCD-4 Per-Epic Benchmark Gate (at Story 10.10, not here)
  - `_bmad-output/planning-artifacts/architecture.md:434-447` — Source-file organisation table
  - `_bmad-output/planning-artifacts/prd.md:387-389` — FR10 / FR11 / FR12 (double-cell + conversions + arithmetic)
  - `_bmad-output/planning-artifacts/prd.md:460-479` — NFR9 (regression), NFR10 (Core compliance), NFR16 (test-first), NFR17 (standards citations)
- **Precedent stories:**
  - `_bmad-output/implementation-artifacts/10-2-double-cell-stack-foundation.md` — established `src/double.asm`, `tests/double_tests.fth`, CCD-3 template, underflow helpers
  - `_bmad-output/implementation-artifacts/10-3-single-double-conversions.md` — `S>D` sign-extend idiom, `>NUMBER` memory-stash pattern, code-review findings on underflow helper counting
  - `_bmad-output/implementation-artifacts/10-4-double-precision-arithmetic-additive-sign-compare-mixed.md` — **closest precedent**; D+/D- register dance, DMAX/DMIN DEFWORD template, `double_ip_stash` cell usage, Makefile escaping / `printf --` fixes
  - `_bmad-output/implementation-artifacts/10-1-ans-core-compliance-gap-survey-and-implementation-plan.md` — surveyor-authoritative scope
- **Source-tree anchors for pattern matching:**
  - `src/double.asm:1-424` — Stories 10.2 + 10.3 + 10.4 DEFCODEs / DEFWORDs = style template for all three new words
  - `src/double.asm:419-424` — `double_ip_stash` cell; must remain the file's final item; reuse for IP-stash in Story 10.5 DEFCODEs
  - `src/arithmetic.asm:86-106` — single-cell `*` shift-and-add loop; **conceptual template for UM*'s inner loop** (widen the accumulator from 16 to 32 bits)
  - `src/arithmetic.asm:108-136` — `udivmod` subroutine; 16-iteration shift-and-subtract; structurally analogous to UM*'s shift-and-add
  - `src/double.asm:382-394` — DMAX DEFWORD template; copy for M* Option-B (DEFWORD on UM* + DNEGATE)
  - `src/double.asm:405-417` — DMIN DEFWORD template; structurally similar to DMAX
  - `src/system.asm:~278-362` — `check_underflow` / `_2` / `_3` / `_4` helpers (do NOT add new helpers; `_2` and `_4` are the ones needed)
  - `src/strings.asm:~338-434` — `>NUMBER` (memory-stash worked example, though UM*'s simpler shape probably doesn't need that much state)
  - `src/macros.asm:~26-94` — `NEXT` / `DEFCODE` / `DEFWORD` macros (DEFWORD needed only if M* goes the Option-B colon-compilation route; DEFCODE for UM* and D*)
- **Test-tree anchors:**
  - `tests/double_tests.fth` — Story 10.2 / 10.3 / 10.4 sections = style template for the Story 10.5 extension
  - `Makefile:3956-4382` — Stories 10.4 `test-repl` block (tests 450..501) = canonical entry-format template; the closest precedent for numbering, escaping conventions, and banner style
- **Compliance doc:**
  - `docs/ans-forth-core-compliance.md:105-112` — Double-Cell and Mixed-Precision Multiplication §6.1 table (M*, UM* rows to flip)
  - `docs/ans-forth-core-compliance.md:359-374` — §8.6 Double-Number bonus table (D* row to flip)
  - `docs/ans-forth-core-compliance.md:11-18` — §6.1 Summary table (increment Implemented by 2)
  - `docs/ans-forth-core-compliance.md:23-28` — Gap Classification table (decrement (b) "missing subsystem" by 2)
  - `docs/ans-forth-core-compliance.md:43` — Epic-10 closure plan row for Story 10.5
  - `docs/ans-forth-core-compliance.md:304` — "Missing subsystem: Double-cell operations — 14 §6.1 words" paragraph (update count to 12 post-story)
  - `docs/ans-forth-core-compliance.md:407` — "big gaps" Observations paragraph (refresh the count and status language for the double-cell subsystem)
- **Project memories applicable to this story:**
  - `feedback_systematic_reference_check.md` — cross-reference DPANS94, not memory (AC #1, #7, Task 1)
  - `feedback_standards_compliance.md` — investigate the standard; never rationalise (AC all)
  - `feedback_adversarial_review.md` — reviews MUST find things (Task 9; Story 10.4 precedent)
  - `feedback_plain_qa_language.md` — diagnostic Completion Notes
  - `feedback_repl_tests_preferred.md` — REPL-piped Forth scripts (AC #8, Task 5)
  - `feedback_design_upfront.md` — land the full §6.1 multiplication closure + §8.6 D* now so Stories 10.6 (division), 10.9 (`*/ */MOD`) consume a conformant multiplicative foundation from day one
  - `feedback_follow_process.md` — execute the workflow without asking for permission for obvious next steps
  - `feedback_defword_cf_label.md` — if M* lands as DEFWORD, `w_M_STAR_cf EQU w_M_STAR_body - 3` (pointing at the `JP DOCOL`), not at the body. Precedent: `src/double.asm:385,407` (DMAX, DMIN).
  - `project_tos_in_register.md` — BC-as-TOS discipline; DE=IP; DEPTH convention (AC #4, Dev Notes)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — model ID `claude-opus-4-7[1m]`

### Debug Log References

None — implementation passed assembly, smoke-test, and full regression on first build (no failed iterations).

### Completion Notes List

**Implementation choices**

- `UM*` — DEFCODE, ~37 bytes. Right-shift schoolbook (16-iteration shift-and-add) with 32-bit accumulator HL:BC and multiplicand DE. Carry-out of `ADD HL, DE` captured by `RR H` so the algorithm behaves as a 33-bit shift register, settling `$FFFF × $FFFF = $FFFE0001` correctly. IP stashed via `double_ip_stash` (the existing shared scratch cell — no new cells added). `OR A` clears CF on the no-add path so `RR H` rotates a known 0 into HL's MSB.
- `M*` — DEFWORD wrapper (Option B per Task 3.1 recommendation). Body: `2DUP XOR 0< >R ABS SWAP ABS SWAP UM* R> ?BRANCH skip DNEGATE THEN`. ~14 cells = 28 bytes body + ~10 bytes header. The `-32768 × -32768` ABS-fixed-point trap collapses correctly: sign-XOR returns 0 for two negatives → no `DNEGATE`, and `UM*($8000, $8000) = $40000000 = (16384, 0)` is the right answer for `+1073741824`. Underflow guard from first body word `2DUP` (calls `check_underflow_2`).
- `D*` — DEFWORD (Task 4.1 Option D variant), ~21 cells = 42 bytes body. Body: `2OVER 2DROP >R OVER R@ UM* 2SWAP * ROT + R> 3 PICK * SWAP + ROT DROP SWAP`. Front-loaded `2OVER 2DROP` provides the `check_underflow_4` guard (2 cells / 4 bytes overhead) without polluting the post-guard stack shape. Algebra: `result_low = low(b1*b2)`, `result_high = high(b1*b2) + (b1*a2 + a1*b2) mod 2^16`. The two cross-term multiplies use the existing single-cell truncating `*`; the full 32-bit product uses the new `UM*`. Two's-complement signed semantics emerge for free — no sign tracking required (verified by `-1 -1 -1 -1 D* → ( 0 1 )`).

**ROM size**

Pre-Story-10.5 baseline: `build/antforth.com` = 15472 bytes. Post-Story-10.5: 15606 bytes. Delta: **+134 bytes** (story estimate 160-200 bytes ± 50%; actual sits in the lower band of that envelope). Informational only — CCD-4 benchmark gate is at Story 10.10.

**Test coverage**

Story-10.5 adds 24 REPL tests (Makefile range 502..525): 6 UM* + 8 M* + 7 D* + 3 underflow. All pass on first run. Full `make test-repl` reports 525 distinct PASS, 0 FAIL — exact match to baseline (501) + new (24). No regressions in adjacent words (`*`, `D+`, `D-`, `M+`, `DNEGATE`, `DABS`, `D=`, `D<`, `S>D`, `D>S`, `2@`, `2!`, `+`, `-`, `NEGATE`, `ABS`, `=`, `<`).

**Adversarial self-review findings (Task 9.1 hunt)**

| Trap | Defense / Witness test |
|---|---|
| UM* shift-loop iteration off-by-one | `LD A, 16` literal; `$FFFF × $FFFF = $FFFE0001` (test 506) catches one-bit drift |
| UM* 32-bit accumulator width | HL:BC pair; `$100 × $100 = $10000` (test 505) catches 16-bit-only accumulator |
| UM* 33rd-bit carry capture | `RR H` after `ADD HL, DE`; verified by `$FFFF × $FFFF` and `$FFFF × 2` |
| M* `-32768 × -32768` ABS-fixed-point trap | Sign-XOR uses bit 15 of original operand pair (via `XOR 0<` before any ABS). Both-negative case → flag 0 → no DNEGATE → unsigned ABS interpretation gives correct $40000000. Witness test 513. |
| D* two's-complement identity | Algebra is sign-agnostic; `-1 -1 -1 -1 D* → ( 0 1 )` (test 521) confirms |
| D* cross-term carry / overflow discard | `0 1 -1 0 D* → ( -1 0 )` (test 522): `b1*a2 = 1*$FFFF = $FFFF` contributes to high cell only |
| `check_underflow_N` mismatches | UM* directly calls `_2`; M* inherits via 2DUP's `_2`; D* inherits via 2OVER's `_4`. Tested 523/524/525 |
| CCD-3 §-number drift | Cross-checked against compliance doc (`ans-forth-core-compliance.md:111,112,370`): `UM* §6.1.2360`, `M* §6.1.1810`, `D* §8.6.1090` — all correct in source comments |
| Makefile `$$`-escaping | Hex literals in PASS banners use `$$FFFF` / `$$100` etc.; verified PASS lines render `$FFFF` correctly |
| `printf --` for negative literals | Lines for `-5`, `-32768`, `-1` use `printf --` (e.g., test 510, 513, 520) |

No defects found by self-review. Code-review (different LLM) recommended via `/bmad-bmm-code-review 10.5`.

### File List

- `src/double.asm` — Modified. Added DEFCODE `UM*` at line 430, DEFWORD `M*` at line 468, DEFWORD `D*` at line 510. `double_ip_stash` cell shifted to line 535 (still file's final item). +~134 ROM bytes.
- `tests/double_tests.fth` — Modified. Appended Story 10.5 section (24 REPL test scenarios, 4 sub-headers).
- `Makefile` — Modified. Appended 24 `test-repl` entries (502..525) plus a section banner. Convention: `printf --` for negative literals; `$$<hex>` in PASS banners.
- `docs/ans-forth-core-compliance.md` — Modified. Summary 118→120 (88.7%→90.2%); Missing 15→13; Gap Classification (b) subsystem 13→11; §6.1 Multiplication table M*/UM* rows flipped to Implemented; Multiplication sub-section intro at line 107 updated `0 impl, 2 missing` → `2 impl, 0 missing` (code-review fix); Gap Analysis "(b) Oversight" heading at line 292 refreshed `22 words (20 subsystem)` → `13 words (11 subsystem)` (code-review fix); §8.6 D* row flipped to Implemented; Epic-10 closure plan row updated; Missing-subsystem header updated to `5 §6.1 words remaining`; "big gaps" observation paragraph rewritten.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — Modified. `10-5-double-multiplication`: ready-for-dev → in-progress → review → done.
- `_bmad-output/implementation-artifacts/10-5-double-multiplication.md` — Modified (this file). Status: ready-for-dev → in-progress → review → done. All Tasks/Subtasks marked complete. Dev Agent Record populated.

### Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-22 | Implemented `UM*` `M*` `D*` per AC #1–#3; added 24 REPL tests (502..525); updated compliance doc; +134 ROM bytes; 525 distinct PASS / 0 FAIL on full regression. | Claude Opus 4.7 (1M) — dev-story workflow |
| 2026-04-22 | Code review: fixed 2 LOW findings (stale section-header counts at `ans-forth-core-compliance.md:107,292`). No code changes. Full regression re-run: 525 PASS / 0 FAIL. | Claude Opus 4.7 (1M) — code-review workflow |
