# ANS Forth Core Word Set Compliance Report

**Date:** 2026-04-24 (Story 10.9 refresh — §6.1 Core gap closed)
**Last full audit:** 2026-04-13 (Story 5.3)
**Story 13.0 back-fill:** 2026-05-01 — §3.4.1.3 dot-marker recogniser (parser-level rule, not a word; missed by Epic 10's word-counted survey).
**Story 13.0.1 back-fill:** 2026-05-01 — §3.1.4.1 double-cell stack-layout (high-on-TOS) flipped from inverted convention. Two §-level structural-rule gaps closed by back-fills inside Epic 13 ahead of v2.0 (§3.4.1.3 + §3.1.4.1); both were structurally invisible to Epic 10's word-counted survey. A full §-by-§ pre-2.0 re-audit pass remains a wishlist item.
**System:** antforth (Z80 Forth for CP/M)
**Reference:** DPANS94 (ANSI X3.215-1994), §3.1.4.1 (Double-cell integers), §3.4.1.3 (Conversion of digit strings), §6.1 (Core), §6.1.0310 (`2!`), §6.1.0350 (`2@`), §6.2 (Core Extension); cross-referenced against §8.6 (Double-Number wordset) for Epic-10 scope reconciliation
**Source:** `src/*.asm`

## §3.1.4.1 — Double-cell integers (stack-layout rule)

| Rule | Status | Stories | Notes |
|---|---|---|---|
| **High cell on top of stack, low cell below** | **Implemented (post-flip)** | **13.0.1** | "On the stack, the cell containing the most significant part of a double-cell integer shall be above the cell containing the least significant part" |
| **High cell at lower address (`2@`/`2!` per §6.1.0310 + §6.1.0350)** | **Implemented (post-flip)** | **13.0.1** | x2 (= MSC = high cell) stored at a-addr; low cell at a-addr+2; cell-pair big-endian, each cell internally little-endian |

Pre-Story-13.0.1 the convention was inverted (low-on-TOS / low-at-low-address); Epic 10's word-counted survey missed §3.1.4.1 (a stack-layout rule, not a per-word rule). Closed 2026-05-01. The full §-by-§ re-audit is recorded as a post-2.0 carry-forward opportunity (see also Story 13.0 Task 10's identical note).

## §3.4.1.3 — Conversion of digit strings (parser-level rule)

| Rule | Status | Stories | Notes |
|---|---|---|---|
| Numeric prefix (`#`/`$`/`%`/`0x`) | Implemented | 9.1–9.5 | Forth 2014 §3.4.1.3 prefix forms |
| Leading sign `-<prefix><digits>` | Implemented | 9.4 | XOR-composes with in-body sign |
| Character literal `'c'` | Implemented | 9.3 | §3.4.1.3 character-code literal |
| **Dot-marker → double-cell** | **Implemented** | **9.1–9.5 + 13.0** | Trailing/leading/embedded dot triggers double-cell parse; DPL USER variable exposes digits-after-dot |

Pre-Story-13.0 the dot-marker form was missing from Epic 10's word-counted §6.1 survey ("100% Core" claim was structurally word-counted, not §-counted). Story 13.0 closes the gap; no broader §-level re-audit was in scope per project lead 2026-05-01. A full §-by-§ audit is recorded as a post-2.0 carry-forward opportunity.

## Summary

| Metric | Count | % of 133 |
|--------|-------|----------|
| Total §6.1 Core words in standard | 133 | 100.0% |
| Fully implemented | 133 | 100.0% |
| Partial | 0 | 0.0% |
| Missing | 0 | 0.0% |
| **Coverage** | **133 / 133** | **100.0%** |

**Post-Story-10.9 status: 133/133 §6.1 Core words implemented, zero deliberate omissions. FR15 / NFR10 satisfied as written.** The Partial / Missing categories are empty; the strict / lenient distinction has collapsed. Story 10.10 (Epic-10 close-out, CCD-4 benchmark gate) inherits a single-sentence FR15 / NFR10 verification.

| Gap Classification | Count |
|--------------------|-------|
| (a) Deliberately omitted | 0 |
| (b) Oversight — missing subsystem | 0 |
| (b) Oversight — moderate | 0 |
| (c) Partially implemented | 0 |

**All §6.1 Core gaps closed as of Story 10.9 (2026-04-24).**

| Core Extension bonus | Count |
|----------------------|-------|
| Core Extension words implemented (§6.2) | 12 of 46 |

### Epic-10 closure plan

Epic 10 closes the §6.1 gap. Per-story increments (§6.1 Core only — §8.6 Double-Number additions are bonus and tracked separately):

| Story | Sub-family | §6.1 words added | Notes |
|---|---|---|---|
| 10.2 | Double-cell stack & memory | 6 (`2DROP` `2DUP` `2OVER` `2SWAP` `2!` `2@`) | foundation |
| 10.3 | Single ↔ double conversions | 1 (`S>D`) ✓ + `>NUMBER` Partial→Full ✓ + `D>S` (§8.6 bonus) ✓ | Complete |
| 10.4 | Double arithmetic / compare / sign | 0 §6.1 ✓ | §8.6 bonus Complete (`D+` `D-` `DNEGATE` `DABS` `D=` `D<` `DMAX` `DMIN` `M+`) |
| 10.5 | Double multiplication | 2 ✓ (`M*` `UM*`) | §8.6 bonus `D*` Complete |
| 10.6 | Double / mixed division | 3 ✓ (`FM/MOD` `SM/REM` `UM/MOD`) | Complete |
| 10.7 | Pictured numeric output primitives | 6 ✓ (`<#` `#` `#S` `#>` `HOLD` `SIGN`) + `HOLDS` (§6.2 bonus) ✓ | Complete |
| 10.8 | Number-output rewrite on pictured foundation | 0 net new §6.1 ✓ | `.` `U.` `.R` rewritten on pictured foundation (`formatting.asm`); `D.` `U.R` `D.R` added as §8.6/§6.2 bonus. Complete |
| 10.9 | Remaining §6.1 Core gap words | 4 ✓ (`*/` `*/MOD` `EVALUATE` `ENVIRONMENT?`) | Complete — `ENVIRONMENT?` reclassified from deliberate-omission to gap-to-implement on 2026-04-20 (party-mode decision) |
| **Total §6.1 closed** | | **22 ✓** | + `>NUMBER` Partial → Full ✓ |

**Post-Epic-10 target:** 133 fully implemented, 0 deliberate omissions = **100.0% of §6.1 Core (133 / 133)**. Satisfies FR15 / NFR10 as written ("100% of the ANS Forth 1994 Core wordset") with no carve-out or asterisk.

**Epic-10 spec wrote "≈ 86%" baseline; the measured value was 83.5% (or 82.7% strict) pre-Story-10.2; after Story 10.2 the lenient figure is 88.0% (117/133), strict 87.2% (116/133).** The discrepancy versus the spec's estimate is drafting, not measurement. This document records the measured value and is the source of truth.

---

## Detailed Audit by Category

### Stack Operations

14 §6.1 Core words — 14 implemented, 0 missing. **100% complete.**

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `DUP` | `( x -- x x )` | Implemented | `stack_ops.asm:27` | |
| `DROP` | `( x -- )` | Implemented | `stack_ops.asm:37` | |
| `SWAP` | `( x1 x2 -- x2 x1 )` | Implemented | `stack_ops.asm:48` | |
| `OVER` | `( x1 x2 -- x1 x2 x1 )` | Implemented | `stack_ops.asm:62` | |
| `ROT` | `( x1 x2 x3 -- x2 x3 x1 )` | Implemented | `stack_ops.asm:77` | |
| `?DUP` | `( x -- 0 \| x x )` | Implemented | `stack_ops.asm:13` | |
| `2DROP` | `( x1 x2 -- )` | Implemented | `double.asm:87` | Story 10.2 |
| `2DUP` | `( x1 x2 -- x1 x2 x1 x2 )` | Implemented | `double.asm:70` | Story 10.2 |
| `2OVER` | `( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )` | Implemented | `double.asm:127` | Story 10.2 |
| `2SWAP` | `( x1 x2 x3 x4 -- x3 x4 x1 x2 )` | Implemented | `double.asm:102` | Story 10.2 |
| `DEPTH` | `( -- +n )` | Implemented | `stack_ops.asm:178` | |
| `>R` | `( x -- ) ( R: -- x )` | Implemented | `stack_ops.asm:249` | |
| `R>` | `( -- x ) ( R: x -- )` | Implemented | `stack_ops.asm:263` | |
| `R@` | `( -- x ) ( R: x -- x )` | Implemented | `stack_ops.asm:277` | |

### Arithmetic

19 §6.1 Core words — 17 implemented, 2 missing.

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `+` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:55` | |
| `-` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:69` | |
| `*` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:86` | |
| `/` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:240` | |
| `MOD` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:256` | |
| `/MOD` | `( n1 n2 -- rem quot )` | Implemented | `arithmetic.asm:219` | |
| `*/` | `( n1 n2 n3 -- n4 )` | Implemented | `arithmetic.asm:296` | Story 10.9; DEFWORD wrapping `*/MOD SWAP DROP` (double-cell intermediate via `M*` / `SM/REM`) |
| `*/MOD` | `( n1 n2 n3 -- n4 n5 )` | Implemented | `arithmetic.asm:277` | Story 10.9; DEFWORD `>R M* R> SM/REM` (double-cell intermediate; symmetric remainder sign = dividend) |
| `1+` | `( n -- n+1 )` | Implemented | `arithmetic.asm:13` | |
| `1-` | `( n -- n-1 )` | Implemented | `arithmetic.asm:23` | |
| `2*` | `( x -- x*2 )` | Implemented | `arithmetic.asm:33` | |
| `2/` | `( x -- x/2 )` | Implemented | `arithmetic.asm:44` | |
| `ABS` | `( n -- u )` | Implemented | `bootstrap.asm:22` | DEFWORD |
| `NEGATE` | `( n -- -n )` | Implemented | `bootstrap.asm:9` | DEFWORD |
| `MAX` | `( n1 n2 -- n3 )` | Implemented | `bootstrap.asm:56` | DEFWORD |
| `MIN` | `( n1 n2 -- n3 )` | Implemented | `bootstrap.asm:38` | DEFWORD |
| `FM/MOD` | `( d n1 -- n2 n3 )` | Implemented | `double.asm:691` | Story 10.6; DEFWORD wrapping SM/REM + floor correction |
| `SM/REM` | `( d n1 -- n2 n3 )` | Implemented | `double.asm:638` | Story 10.6; DEFWORD wrapping UM/MOD + sign fixups |
| `S>D` | `( n -- d )` | Implemented | `double.asm:151` | Sign-extend single → double |

### Double-Cell and Mixed-Precision Multiplication

2 §6.1 Core words — 2 implemented, 0 missing. **100% complete.** (Story 10.5)

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `M*` | `( n1 n2 -- d )` | Implemented | `double.asm:468` | Signed mixed multiply (DEFWORD wrapping UM*) |
| `UM*` | `( u1 u2 -- ud )` | Implemented | `double.asm:430` | Unsigned mixed multiply (right-shift 32-bit accumulator) |

### Double-Cell Division

1 §6.1 Core word — 1 implemented, 0 missing. **100% complete.** (`FM/MOD` and `SM/REM` are listed in Arithmetic above; `UM/MOD` here.)

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `UM/MOD` | `( ud u1 -- u2 u3 )` | Implemented | `double.asm:566` | Story 10.6; 16-iteration shift-subtract with 33rd-bit force path |

### Logic and Comparison

12 §6.1 Core words — 12 implemented, 0 missing. **100% complete.**

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `AND` | `( x1 x2 -- x3 )` | Implemented | `logic.asm:18` | |
| `OR` | `( x1 x2 -- x3 )` | Implemented | `logic.asm:35` | |
| `XOR` | `( x1 x2 -- x3 )` | Implemented | `logic.asm:52` | |
| `INVERT` | `( x1 -- x2 )` | Implemented | `logic.asm:69` | |
| `LSHIFT` | `( x1 u -- x2 )` | Implemented | `logic.asm:84` | |
| `RSHIFT` | `( x1 u -- x2 )` | Implemented | `logic.asm:105` | |
| `=` | `( x1 x2 -- flag )` | Implemented | `logic.asm:127` | |
| `<` | `( n1 n2 -- flag )` | Implemented | `logic.asm:147` | |
| `>` | `( n1 n2 -- flag )` | Implemented | `logic.asm:172` | |
| `0=` | `( x -- flag )` | Implemented | `logic.asm:201` | |
| `0<` | `( n -- flag )` | Implemented | `logic.asm:216` | |
| `U<` | `( u1 u2 -- flag )` | Implemented | `logic.asm:231` | |

### Memory

17 §6.1 Core words — 17 implemented, 0 missing. **100% complete.**

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `!` | `( x a-addr -- )` | Implemented | `memory.asm:57` | |
| `@` | `( a-addr -- x )` | Implemented | `memory.asm:43` | |
| `C!` | `( char c-addr -- )` | Implemented | `memory.asm:87` | |
| `C@` | `( c-addr -- char )` | Implemented | `memory.asm:74` | |
| `2!` | `( x1 x2 a-addr -- )` | Implemented | `double.asm:45` | Story 10.2 |
| `2@` | `( a-addr -- x1 x2 )` | Implemented | `double.asm:20` | Story 10.2 |
| `+!` | `( n a-addr -- )` | Implemented | `memory.asm:102` | |
| `,` | `( x -- )` | Implemented | `memory.asm:150` | |
| `C,` | `( char -- )` | Implemented | `memory.asm:168` | |
| `HERE` | `( -- addr )` | Implemented | `memory.asm:123` | |
| `ALLOT` | `( n -- )` | Implemented | `memory.asm:135` | |
| `ALIGN` | `( -- )` | Implemented | `memory.asm:184` | |
| `ALIGNED` | `( addr -- a-addr )` | Implemented | `memory.asm:201` | |
| `CELLS` | `( n1 -- n2 )` | Implemented | `memory.asm:214` | |
| `CELL+` | `( a-addr1 -- a-addr2 )` | Implemented | `memory.asm:13` | |
| `FILL` | `( c-addr u char -- )` | Implemented | `memory.asm:225` | |
| `MOVE` | `( addr1 addr2 u -- )` | Implemented | `memory.asm:264` | |

### Character

3 §6.1 Core words — 3 implemented, 0 missing. **100% complete.**

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `CHAR` | `( "<spaces>name" -- char )` | Implemented | `strings.asm:161` | |
| `CHAR+` | `( c-addr1 -- c-addr2 )` | Implemented | `memory.asm:24` | INC BC; same as 1+ on Z80 (1 char = 1 byte) |
| `CHARS` | `( n1 -- n2 )` | Implemented | `memory.asm:34` | No-op on Z80 (1 char = 1 byte); provided for portability |

### I/O

8 §6.1 Core words — 8 implemented, 0 missing. **100% complete.**

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `EMIT` | `( x -- )` | Implemented | `io.asm:9` | |
| `KEY` | `( -- char )` | Implemented | `io.asm:153` | |
| `ACCEPT` | `( c-addr +n1 -- +n2 )` | Implemented | `io.asm:117` | |
| `CR` | `( -- )` | Implemented | `io.asm:61` | |
| `SPACE` | `( -- )` | Implemented | `io.asm:73` | |
| `SPACES` | `( n -- )` | Implemented | `io.asm:86` | |
| `TYPE` | `( c-addr u -- )` | Implemented | `io.asm:24` | |
| `BL` | `( -- char )` | Implemented | `outer_interpreter.asm:83` | |

### Numeric Output and Formatting

10 §6.1 Core words — 10 implemented, 0 missing. **100% complete.**

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `.` | `( n -- )` | Implemented | `formatting.asm:133` | Story 10.8 will rewrite atop pictured-output primitives, preserving observable behaviour |
| `."` | `( "ccc" -- )` | Implemented | `strings.asm:829` | IMMEDIATE — Story 13.5.3 (TD-5 closure 2026-05-06): interpret-mode tail now preserves caller's TOS (PUSH BC at `.dq_interpret`, POP BC at `.dq_i_end`), see Story 13.5.3 caveats below |
| `U.` | `( u -- )` | Implemented | `formatting.asm:154` | Story 10.8 rewrite (as `.`) |
| `DECIMAL` | `( -- )` | Implemented | `formatting.asm:383` | DEFWORD |
| `<#` | `( -- )` | Implemented | `pictured.asm` (Story 10.7) | Resets HLD to pic_buf sentinel |
| `#` | `( ud1 -- ud2 )` | Implemented | `pictured.asm` (Story 10.7) | Inline 32-by-8 divide. The §6.1 `#` coexists with the assembler's immediate-operand sigil at `assembler.asm:985`: both share the name, the asm entry is head-of-bucket and dispatches at run time — `asm_mode == 0` → pictured `#`, `asm_mode == 1` → sigil. Epic 12 (wordlists) retires this dispatch. |
| `#S` | `( ud1 -- ud2 )` | Implemented | `pictured.asm` (Story 10.7) | DEFWORD — canonical `BEGIN # 2DUP OR 0= UNTIL` |
| `#>` | `( xd -- c-addr u )` | Implemented | `pictured.asm` (Story 10.7) | Returns buffer `( c-addr u )` |
| `HOLD` | `( char -- )` | Implemented | `pictured.asm` (Story 10.7) | Underflow → `-17 THROW` (`pictured numeric output string overflow`) per ANS Forth 1994 §9.3.5 (Story 11.6) |
| `SIGN` | `( n -- )` | Implemented | `pictured.asm` (Story 10.7) | `BIT 7,B` inline — no extra (?1) helper |

### String and Parsing

4 §6.1 Core words — 3 fully implemented, 1 partial.

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `S"` | `( "ccc" -- c-addr u )` | Implemented | `strings.asm:589` | IMMEDIATE |
| `COUNT` | `( c-addr1 -- c-addr2 u )` | Implemented | `dictionary.asm:9` | |
| `WORD` | `( char -- c-addr )` | Implemented | `strings.asm:11` | |
| `>NUMBER` | `( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )` | Implemented | `strings.asm:341` | Full 32-bit accumulation (`ud ← ud × BASE + digit`) with carry propagation across both cells; guards DEPTH ≥ 4. Upgraded from Partial in Story 10.3. **antforth implementation limit:** `u1` is truncated to 8 bits (strings longer than 255 chars are processed only to the first 255); practical for CP/M TIB but a deviation from the 16-bit `u1` signature. |

### Control Flow

16 §6.1 Core words — 16 implemented, 0 missing. **100% complete.**

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `IF` | `( x -- )` | Implemented | `control_flow.asm:32` | DEFIMMED |
| `THEN` | `( -- )` | Implemented | `control_flow.asm:48` | DEFIMMED |
| `ELSE` | `( -- )` | Implemented | `control_flow.asm:65` | DEFIMMED |
| `BEGIN` | `( -- )` | Implemented | `control_flow.asm:89` | DEFIMMED |
| `UNTIL` | `( x -- )` | Implemented | `control_flow.asm:101` | DEFIMMED |
| `WHILE` | `( x -- )` | Implemented | `control_flow.asm:118` | DEFIMMED |
| `REPEAT` | `( -- )` | Implemented | `control_flow.asm:136` | DEFIMMED |
| `DO` | `( n1 n2 -- )` | Implemented | `control_flow.asm:356` | DEFIMMED |
| `LOOP` | `( -- )` | Implemented | `control_flow.asm:374` | DEFIMMED |
| `+LOOP` | `( n -- )` | Implemented | `control_flow.asm:413` | DEFIMMED |
| `I` | `( -- n )` | Implemented | `control_flow.asm:331` | |
| `J` | `( -- n )` | Implemented | `control_flow.asm:343` | |
| `LEAVE` | `( -- )` | Implemented | `control_flow.asm:451` | DEFIMMED |
| `UNLOOP` | `( -- )` | Implemented | `control_flow.asm:318` | |
| `EXIT` | `( -- )` | Implemented | `inner_interpreter.asm:32` | DEFCODE wrapping `EXIT_CODE` |
| `RECURSE` | `( -- )` | Implemented | `control_flow.asm:472` | F_IMMEDIATE |

### Compiler and Defining Words

14 §6.1 Core words — 14 implemented, 0 missing. **100% complete.**

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `:` | `( "<spaces>name" -- )` | Implemented | `compiler.asm:359` | |
| `;` | `( -- )` | Implemented | `compiler.asm:459` | F_IMMEDIATE |
| `CONSTANT` | `( x "<spaces>name" -- )` | Implemented | `compiler.asm:585` | |
| `VARIABLE` | `( "<spaces>name" -- )` | Implemented | `bootstrap.asm:74` | DEFWORD |
| `CREATE` | `( "<spaces>name" -- )` | Implemented | `compiler.asm:549` | |
| `DOES>` | `( -- )` | Implemented | `compiler.asm:632` | F_IMMEDIATE |
| `IMMEDIATE` | `( -- )` | Implemented | `compiler.asm:339` | |
| `LITERAL` | `( x -- )` | Implemented | `compiler.asm:521` | F_IMMEDIATE |
| `POSTPONE` | `( "<spaces>name" -- )` | Implemented | `compiler.asm:279` | DEFIMMED |
| `[` | `( -- )` | Implemented | `compiler.asm:498` | F_IMMEDIATE |
| `]` | `( -- )` | Implemented | `compiler.asm:509` | |
| `STATE` | `( -- a-addr )` | Implemented | `outer_interpreter.asm:26` | |
| `[']` | `( "<spaces>name" -- xt )` | Implemented | `compiler.asm:55` | DEFIMMED |
| `[CHAR]` | `( "<spaces>name" -- char )` | Implemented | `compiler.asm:67` | DEFIMMED |

### System and Interpreter

13 §6.1 Core words — 11 implemented, 2 missing.

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `EXECUTE` | `( xt -- )` | Implemented | `inner_interpreter.asm:224` | |
| `FIND` | `( c-addr -- c-addr 0 \| xt 1 \| xt -1 )` | Implemented | `dictionary.asm:22` | Hash-table lookup |
| `ABORT` | `( -- )` | Implemented | `system.asm:259` | |
| `QUIT` | `( -- )` | Implemented | `outer_interpreter.asm:237` | |
| `>IN` | `( -- a-addr )` | Implemented | `outer_interpreter.asm:46` | |
| `BASE` | `( -- a-addr )` | Implemented | `outer_interpreter.asm:36` | |
| `SOURCE` | `( -- c-addr u )` | Implemented | `outer_interpreter.asm:66` | |
| `(` | `( "ccc)" -- )` | Implemented | `strings.asm:821` | F_IMMEDIATE |
| `'` | `( "<spaces>name" -- xt )` | Implemented | `compiler.asm:26` | DEFWORD |
| `>BODY` | `( xt -- a-addr )` | Implemented | `compiler.asm:11` | xt+5 (skips JP + does-addr) |
| `ABORT"` | `( "ccc" x -- )` | Implemented | `system.asm:139` | F_IMMEDIATE; runtime `(ABORT")` at `system.asm:89` |
| `EVALUATE` | `( i*x c-addr u -- j*x )` | Implemented | `outer_interpreter.asm:366` | Story 10.9; DEFWORD `(SAVE-INPUT) INTERPRET (RESTORE-INPUT)`; saves four USER source-spec cells (tib_addr, tib_len, tib_in, source_id) on R-stack across INTERPRET; source_id = -1 during EVALUATE per Forth 2014 §6.2.2218. Distinct surfaces: the (paren) helpers here are EVALUATE's R-stack plumbing (install/uninstall semantics); the user-facing CORE-EXT counterparts `SAVE-INPUT` (§6.2.2182) and `RESTORE-INPUT` (§6.2.2148) — added by Story 13.5.5 — are data-stack snapshot/rewind words. See Core Extension table below + Story 13.5.5 caveats. |
| `ENVIRONMENT?` | `( c-addr u -- false \| i*x true )` | Implemented | `system.asm:277` | Story 10.9; DEFCODE walking a 14-entry static `env_table` of DPANS94 §3.2.6 standard query keys (case-sensitive); supports single, double, and flag value kinds |

---

## Gap Analysis

### (a) Deliberately Omitted — 0 words

No §6.1 Core word is deliberately omitted from antforth.

**Historical note (2026-04-20 party-mode decision):** `ENVIRONMENT?` was previously classified as "deliberately omitted (low value-to-effort)" by Story 5.3 and upheld by the Story 10.1 surveyor. On 2026-04-20 the implementation cost was re-estimated at ~80–120 bytes and the classification was overturned: `ENVIRONMENT?` was added to Story 10.9 scope and is now implemented. This keeps the FR15 / NFR10 claim literal — 133 / 133 words, no carve-out, no asterisk.

### (b) Oversight — 0 words (all closed by Stories 10.2–10.9)

**All §6.1 Core gaps closed as of Story 10.9 (2026-04-24).** This subsection records how each closed:

#### Closed subsystem: Pictured numeric output — 6 §6.1 words + `HOLDS` (§6.2 bonus) → Story 10.7 ✓

Story 10.7 delivered `<#` `#` `#S` `#>` `HOLD` `SIGN` (the 6 §6.1 Core primitives) plus `HOLDS` (Forth-2014 §6.2.1675) in `src/pictured.asm`, backed by a 40-byte `pic_buf` and the `HLD` USER variable in `UserArea` (architecture decision E10-D2, `architecture.md:254-258`). `HLD` is also exposed as a user-facing DEFCODE (antforth extension following Gforth / SwiftForth precedent).

Story 10.8 rewrote `.` / `U.` / `.R` on top of this foundation and added `D.` / `U.R` / `D.R` as §6.2/§8.6 bonus, preserving observable `.` / `U.` / `.R` output byte-for-byte.

#### Closed subsystem: Double-cell operations — 13 §6.1 words across Stories 10.2–10.6, 10.9

antforth is a single-cell (16-bit) system. The following §6.1 Core words operate on double-cell (32-bit) values, all now implemented:

| Sub-group | §6.1 words | Story |
|-----------|------------|-------|
| Double-cell stack | `2DROP` `2DUP` `2OVER` `2SWAP` | 10.2 ✓ |
| Double-cell memory | `2!` `2@` | 10.2 ✓ |
| Single → double | `S>D` | 10.3 ✓ |
| Double / mixed multiplication | `M*` `UM*` | 10.5 ✓ |
| Double / mixed division | `FM/MOD` `SM/REM` `UM/MOD` | 10.6 ✓ |
| Mixed-precision (double intermediate) | `*/` `*/MOD` | 10.9 ✓ |

**`*/` and `*/MOD` use a double-cell intermediate** (n1×n2 as 32-bit before dividing by n3), so Story 10.9 was sequenced after Stories 10.5 (`M*`) and 10.6 (`SM/REM`) had landed.

#### Closed moderate single-word gaps — 2 words → Story 10.9 ✓

| Word | Story | Complexity | Notes |
|------|-------|-----------|-------|
| `EVALUATE` | 10.9 ✓ | Moderate | DPANS94 §6.1.1360. Save/restore input source via 4-cell R-stack frame across INTERPRET. |
| `ENVIRONMENT?` | 10.9 ✓ | Low | DPANS94 §6.1.1345. 14-entry static query table per §3.2.6 (`/COUNTED-STRING`, `/HOLD`, `/PAD`, `ADDRESS-UNIT-BITS`, `CORE`, `CORE-EXT`, `FLOORED`, `MAX-CHAR`, `MAX-D`, `MAX-N`, `MAX-U`, `MAX-UD`, `RETURN-STACK-CELLS`, `STACK-CELLS`). Story 13.5.4 (TD-6 closure 2026-05-06): the `/PAD` query (returning `( 84 -1 )`) is now backed by a real `PAD` word at `memory.asm` per §6.2.2000 — see Core Extension Bonus Coverage table and Story 13.5.4 caveats below. |

### (c) Partially Implemented — 0 words (empty after Story 10.3)

`>NUMBER` was the sole Partial entry. Story 10.3 upgraded it to full 32-bit accumulation at `strings.asm:338`, so this category is now empty and the lenient / strict coverage distinction collapses.

---

## Core Extension Bonus Coverage

**14** of 46 DPANS94 §6.2 Core Extension words are implemented (SAVE-INPUT + RESTORE-INPUT added by Story 13.5.5 — TD-7 closure 2026-05-06; PAD added by Story 13.5.4 — TD-6 closure 2026-05-06). (Forth-2012 / Forth-2014 added several §6.2 entries beyond DPANS94 1994 — `HOLDS` at §6.2.1675 is one — which is why `forth-standard.org` shows a higher §6.2 count than DPANS94 itself. This report's measurement uses the DPANS94 1994 baseline (46) for the bonus tally; the Forth-2014 additions implemented (or planned) are noted in the "Will gain via Epic 10" sub-section.)

| Word | Stack Effect | Source | Notes |
|------|-------------|--------|-------|
| `.R` | `( n1 n2 -- )` | `formatting.asm:203` | Right-aligned numeric output; DEFWORD on pictured foundation (Story 10.8) |
| `COMPILE,` | `( xt -- )` | `compiler.asm:321` | Append execution semantics |
| `HEX` | `( -- )` | `formatting.asm:370` | Set BASE to 16 |
| `HOLDS` | `( c-addr u -- )` | `pictured.asm` (Story 10.7) | Forth-2014 addition; inserts counted string into pictured buffer |
| `MARKER` | `( "<spaces>name" -- )` | `system.asm:22` | Snapshot/restore dictionary state |
| `PAD` | `( -- c-addr )` | `memory.asm` (Story 13.5.4) | DPANS94 §6.2.2000. Returns transient region address at HERE+`PAD_OFFSET` (84 bytes). Survives parsing of one space-delimited name per §3.3.3.6 (WORD writes ≤32 bytes at HERE+1, leaving HERE+33..+84+ untouched). TD-6 closure (Epic 13.5 Tag-Blocking Slate) — see Story 13.5.4 caveats below. |
| `PICK` | `( xu...x0 u -- xu...x0 xu )` | `stack_ops.asm:94` | |
| `RESTORE-INPUT` | `( xn ... x1 n -- flag )` | `outer_interpreter.asm` (Story 13.5.5) | DPANS94 §6.2.2148. User-facing CORE-EXT counterpart of `SAVE-INPUT`. flag = 0 on clean restore (count == 4 AND saved SOURCE-ID matches current); flag = -1 on count or SOURCE-ID mismatch (§6.2.2148 ambiguous condition). TD-7 closure (Epic 13.5 Tag-Blocking Slate) — see Story 13.5.5 caveats below. Distinct from the EVALUATE-private R-stack `(RESTORE-INPUT)` plumbing helper at `outer_interpreter.asm:445-460`. |
| `ROLL` | `( xu...x0 u -- xu-1...x0 xu )` | `stack_ops.asm:112` | |
| `SAVE-INPUT` | `( -- xn ... x1 n )` | `outer_interpreter.asm` (Story 13.5.5) | DPANS94 §6.2.2182. Pushes a uniform-quadruple description of the current input source spec: `( -- tib_addr tib_len >IN SOURCE-ID 4 )`. Same shape across all SOURCE-ID classes (0 keyboard / -1 EVALUATE / >0 INCLUDE-FILE). Primary scope: EVALUATE arm round-trip per TD-7 closure (Epic 13.5 Tag-Blocking Slate) — see Story 13.5.5 caveats below. Distinct from the EVALUATE-private R-stack `(SAVE-INPUT)` plumbing helper at `outer_interpreter.asm:395-431`. |
| `\` | `( "ccc" -- )` | `strings.asm:806` | Line comment; F_IMMEDIATE |
| `#TIB` | `( -- a-addr )` | `outer_interpreter.asm:56` | Obsolescent in Forth-2012 |
| `QUERY` | `( -- )` | `outer_interpreter.asm:96` | Obsolescent in Forth-2012 |

### §6.2 Will gain via Epic 10

| Word | §-number | Story | Notes |
|------|----------|-------|-------|
| `HOLDS` | 6.2.1675 | 10.7 ✓ Implemented (`pictured.asm`) | Forth-2014 addition; counterpart of `HOLD` for strings |
| `U.R` | 6.2.2330 | 10.8 ✓ Implemented (`formatting.asm:217`) | Right-aligned unsigned print on pictured foundation |

### §8.6 Double-Number wordset — bonus coverage planned by Epic 10

These words are **not in §6.1 Core** and therefore are NOT part of the FR15 100%-Core target. Epic 10's Stories 10.4 / 10.5 / 10.8 add them as bonus coverage atop the §6.1 foundation. Listed here so the audit trail records the §6.1-vs-§8.6 distinction explicitly.

| Word | §-number | Story | Notes |
|------|----------|-------|-------|
| `D+` | 8.6.1040 | Implemented (`double.asm:216`) | Double-cell add |
| `D-` | 8.6.1050 | Implemented (`double.asm:239`) | Double-cell subtract |
| `DNEGATE` | 8.6.1230 | Implemented (`double.asm:267`) | Double-cell negate |
| `DABS` | 8.6.1160 | Implemented (`double.asm:292`) | Double-cell abs |
| `D=` | 8.6.1120 | Implemented (`double.asm:312`) | Double-cell equality |
| `D<` | 8.6.1110 | Implemented (`double.asm:347`) | Double-cell signed less-than |
| `DMAX` | 8.6.1210 | Implemented (`double.asm:379`) | Double-cell max |
| `DMIN` | 8.6.1220 | Implemented (`double.asm:401`) | Double-cell min |
| `M+` | 8.6.1830 | Implemented (`double.asm:188`) | Mixed add (d + n → d) |
| `D*` | 8.6.1090 | Implemented (`double.asm:510`) | Double-cell multiply (truncating) |
| `D.` | 8.6.1060 | 10.8 ✓ Implemented (`formatting.asm:156`) | Double-cell signed print |
| `D.R` | 8.6.1070 | 10.8 ✓ Implemented (`formatting.asm:132`) | Double-cell right-aligned print |
| `D>S` | 8.6.1140 | Implemented (`double.asm:172`) | Double-narrow → single (truncating) |

(13 §8.6 additions planned; all 13 implemented post-Story-10.8 — `D.` and `D.R` landed with this refresh. None on the §6.1 critical path.)

### §11.6 File-Access wordset — bonus coverage from Epic 13

Story 13.2 lands the user-facing core File-Access primitives atop
Story 13.1's FCB pool + BDOS wrapper layer. Story 13.3 extends with
file-positioning words; Story 13.4 wires source-input nesting.

| Word | §-number | Source | Notes |
|------|---------:|--------|-------|
| `R/O` | 11.6.1.2054 | `file_access.asm` (Story 13.2) | File-access mode constant — read-only |
| `R/W` | 11.6.1.2055 | `file_access.asm` (Story 13.2) | File-access mode constant — read-write |
| `W/O` | 11.6.1.2425 | `file_access.asm` (Story 13.2) | File-access mode constant — write-only |
| `BIN` | 11.6.1.0865 | `file_access.asm` (Story 13.2) | Binary modifier (no-op on CP/M 2.2 — text/binary undistinguished) |
| `OPEN-FILE` | 11.6.1.1970 | `file_access.asm` (Story 13.2) | `( c-addr u fam -- fileid ior )` |
| `CREATE-FILE` | 11.6.1.1010 | `file_access.asm` (Story 13.2) | `( c-addr u fam -- fileid ior )` — truncates if exists |
| `CLOSE-FILE` | 11.6.1.0900 | `file_access.asm` (Story 13.2) | `( fileid -- ior )` — flush + close + pool_release |
| `DELETE-FILE` | 11.6.1.1190 | `file_access.asm` (Story 13.2) | `( c-addr u -- ior )` — F_DELETE via transient FCB |
| `READ-FILE` | 11.6.1.2080 | `file_access.asm` (Story 13.2 + 13.5.2) | `( c-addr u1 fileid -- u2 ior )` — clean EOF returns `ior=0` with `u2 < u1` (Story 13.2); BDOS F_READ I/O error returns non-zero `ior` (Story 13.5.2 — TD-3 closure; helper-layer tri-state signal) |
| `WRITE-FILE` | 11.6.1.2480 | `file_access.asm` (Story 13.2) | `( c-addr u1 fileid -- ior )` — R/O guard via fcb_fam |
| `FILE-POSITION` | 11.6.1.1520 | `file_access.asm` (Story 13.3) | `( fileid -- ud ior )` — high cell on TOS per §3.1.4.1 |
| `REPOSITION-FILE` | 11.6.1.2142 | `file_access.asm` (Story 13.3 + 13.5.1) | `( ud fileid -- ior )` — auto-flush via dirty gate (Story 13.5.1); ior=5 if ≥ 16 MB; ior=6 if flush fails |
| `FILE-SIZE` | 11.6.1.1522 | `file_access.asm` (Story 13.3) | `( fileid -- ud ior )` — record-rounded (see Story 13.3 caveat below) |
| `INCLUDED` | 11.6.1.1718 | `file_access.asm` (Story 13.4 v2) | `( i*x c-addr u -- j*x )` — load source from file; CCD-1 INCLUDE-TOP framed; -38 if not found |
| `INCLUDE-FILE` | 11.6.1.1717 | `file_access.asm` (Story 13.4 v2) | `( i*x fileid -- j*x )` — load source from open FID; caller retains FID on clean EOF; FID closed on THROW path (deviation) |
| `INCLUDE` | 11.6.2.1717.40 | `file_access.asm` (Story 13.4 v2) | `( "name" -- )` — token-form INCLUDE; = `BL WORD COUNT INCLUDED` |
| `INCLUDE-TOP` | antforth ext | `exception.asm` (Story 13.4 v2) | `( -- a-addr )` — CCD-1 chain head USER variable; pushes user-area cell address |

**Story 13.2 + 13.3 + 13.4 ior/THROW split:**
- ior (recoverable): file not found, malformed filename, R/O write
  attempt, disk-full, EOF mid-read, REPOSITION-FILE 24-bit overflow
  (ior=5), REPOSITION-FILE flush-fail (ior=6, Story 13.5.1).
- THROW (unrecoverable): `-37 THROW_FILE_IO` (file I/O error — Story 13.5.2
  TD-3 closure 2026-05-05; raised by `(file-refill)` on BDOS F_READ
  return `A > 1` via the helper-layer tri-state signal), `-38 THROW_FILE_NOT_FOUND`
  (raised by INCLUDED when OPEN-FILE returns non-zero ior, Story 13.4 v2),
  `-69 THROW_FCB_EXHAUSTED` (FCB pool full), `-70 THROW_FILE_INVALID_FID`
  (closed/stale FID — antforth re-purpose of Forth 2014 §9.3.5 `-70 FREE`;
  see `docs/throw-codes.md` §b.1).

**Story 13.3 caveats:**
- `FILE-SIZE` reports size rounded UP to the nearest 128-byte CP/M
  record boundary (CP/M 2.2 tracks file size in records, not bytes;
  partial-record files are padded with `0x1A` on close). A 100-byte
  file reports as 128. ANS §11.6.1.1522 says "the size, in characters,
  of the file"; on CP/M 2.2 this is the record-rounded equivalent.
- `REPOSITION-FILE` auto-flushes pending partial-record writes as of
  Story 13.5.1 (TD-2 closure). The Story-13.3 silent-discard discipline
  is removed. `file_flush` is gated by a per-FCB `fcb_dirty` bit (set
  in `file_byte_write` entry; cleared at `pool_acquire` / `pool_release`
  / `file_byte_read` refill / `bdos_write_seq` A==0 success), so the
  flush is a no-op when DMA holds read-loaded bytes — closing the
  Story-13.3 (t13)-probe corruption mechanism that originally retracted
  the auto-flush attempt. Flush failure → ior=6; cursor untouched.
- `FILE-POSITION` on R/W FIDs reports the byte cursor accurately in
  all states as of Story 13.5.1 (TD-1 closure). The formula's
  buffer-loaded decrement now consults `fcb_dirty == 0` (universal
  across FAM modes — closing the +128 mid-read miss on R/W FIDs)
  rather than the Story-13.3 `fam_masked == 0` (R/O-only). An
  underflow guard prevents the SUB 1 chain from underflowing for
  fresh-OPEN FCBs (record_count_seq = 0, pos = 0, dirty = 0 →
  reports `0 0 0` correctly). FCB.S2 is masked with `0x3F` before
  use in `record_count_seq` build (Story 13.5.1 hardware smoke,
  CR-010): real CP/M 2.2 BDOS sets §5.4-reserved S2 bit 7
  (modified-extent flag) after F_OPEN / F_READ_SEQ; iz-cpm zeros
  it. Without the mask, FILE-POSITION reported byte-position +64 MB
  on real hardware after every refill. CP/M 2.2 max-file extent
  fits in S2 bits 0..3; the mask is permissive (clears only bits
  6..7, leaving bits 4..5 for CP/M 3 32 MB extension if anyone
  ever runs antforth there).
- **Known Story 13.5.1 latent (CR-006, R/W mid-stream-mid-record
  dirty-DMA loss):** if a user writes < 128 bytes at the start of a
  record and then reads past the record boundary on the same FID
  without an intervening `REPOSITION-FILE` or `CLOSE-FILE`,
  `file_byte_read`'s refill arm overwrites the dirty DMA with the
  next record's contents and clears `fcb_dirty`. The user's pending
  partial-record write is silently lost. AC #6 (Story 13.5.1) flagged
  this as accepted-out-of-scope: the canonical mixed-mode path lands
  via REPOSITION-FILE (which now auto-flushes via the dirty gate).
  Programs that interleave R/W reads and writes without REPOSITION
  are pathological; the probe matrix (944..948) does not cover this
  path. Forward-pointed for a future TD-N if it turns up in the
  field. Workaround: REPOSITION-FILE between a write and a subsequent
  read that crosses the record boundary, which forces auto-flush.
- **Known Story 13.5.1 latent (CR-004, REPOSITION-FILE flush-fail
  byte-cursor reset):** when `REPOSITION-FILE`'s auto-flush fails
  (returns ior = 6), `file_flush.ff_err` (review F2 hardening)
  resets `fcb_byte_pos` to 0 even though the user's logical cursor
  was elsewhere. The record cursor (R0..R2 / CR / EX / S2) stays at
  its pre-REPOSITION value, but `fcb_byte_pos` is clobbered. Users
  receiving ior = 6 should treat byte_pos as undefined and
  CLOSE-FILE / re-OPEN-FILE before relying on FILE-POSITION.
  Pre-13.5.1 the discard discipline never invoked file_flush from
  REPOSITION, so the .ff_err pos-reset never bit a REPOSITION
  caller; the auto-flush in this story made it reachable.

**Story 13.4 v2 caveats:**
- Source-line truncation at TIB_SIZE = 128 bytes is silent: lines
  exceeding 128 bytes are truncated to the first 128 bytes; the rest
  of the line up to the next LF/0x1A is consumed without storage
  (gforth / SwiftForth precedent; Lesson 12-D).
- Line-ending discipline: LF (0x0A) and 0x1A (CP/M soft EOF) terminate
  a line; CR (0x0D) is silently dropped (treated as whitespace).
  Handles CRLF, LF-only, and CP/M soft-EOF mid-record formats.
- Per-FCB private slab buffer ownership (PD-1): each of the 8 FCB pool
  slots gets a private 128-byte slab via `slab[i] = include_line_pool
  + (i << 7)`. Children's INCLUDE writes to their own slab — clobber
  across nesting levels is structurally impossible (no shared
  `include_buffer`).
- INCLUDE-FILE THROW-path FID-close deviation: ANS Forth 1994
  §11.6.1.1717 says "INCLUDE-FILE does not close the FID." On the
  clean-EOF path antforth honours this (caller retains FID ownership).
  On the THROW path antforth deviates: the FID is closed (gforth /
  SwiftForth precedent — deterministic cleanup beats handle leak).
- (close-current-fid) skipping file_flush is now redundant defence-in-
  depth as of Story 13.5. file_flush itself is mode-aware via a per-FCB
  `fcb_has_written` bit (set inside `file_byte_write` entry and
  `bdos_write_seq` A==0 success; cleared at `pool_acquire` /
  `pool_release`). R/O reads never touch `file_byte_write`, so the bit
  stays 0 and `file_flush` skips the destructive pad-and-F_WRITE path.
  R/W FCBs that have not been written likewise skip. Story 13.5.1
  added a second per-FCB `fcb_dirty` bit (transient counterpart) that
  conjunctively gates `file_flush`: the flush only fires when DMA holds
  pending writes AND the FCB has ever been written. The `fcb_dirty`
  bit clears on read refill — closing TD-2's R/W mid-read REPOSITION
  silent-discard hazard — and clears on `bdos_write_seq` A==0 success
  — closing the post-flush double-flush edge. The user-facing
  `CLOSE-FILE` (Story 13.2) is now safe on R/O FIDs in all states.
  Audit anchor: Makefile test 938 flipped 2026-05-04 from expects-bug
  (SZ ≠ 128 — first observed `SZ=1507456`, an artefact of the F2 BC-
  clobber and F1 stale-FCB pollution in the original probe; the actual
  host-side delta is +128 per cycle, so a single uncorrected cycle
  records `SZ=256`) to expects-fix (`SZ=128` — the source-file size
  before the partial-read close cycle). Tests 944..948 (Story 13.5.1)
  pin TD-1/TD-2/TD-4 closures.
- EVALUATE-absorb explicitly out-of-scope (PD-11): EVALUATE keeps its
  private `(SAVE-INPUT)` / `(RESTORE-INPUT)` plumbing in
  `outer_interpreter.asm:395-460`. Future absorption into the INCLUDE-
  TOP frame layout is a Story 13.6 candidate, not pursued here.

**Story 13.5.2 caveats (TD-3 closure 2026-05-05):**
- `READ-FILE` and `(file-refill)` previously collapsed BDOS F_READ EOF
  (`A=1`) and I/O error (`A>1`) onto a single `CY=1` no-byte signal — the
  Story 13.2 AC #17(h) deviation. Story 13.5.2 rewrites `file_byte_read`
  to a tri-state signal: `CY=0,A=byte` (success), `CY=1,A=0` (clean EOF),
  `CY=1,A!=0` (I/O error, A = BDOS return - 1). `READ-FILE` now reports
  non-zero `ior` on real I/O error per ANS §11.6.1.2080; `(file-refill)`
  raises `-37 THROW_FILE_IO` rather than silently truncating the source.
- The I/O-error path is **dormant in practice** under iz-cpm (host-FS
  errors surface via process signals, not by-record A>1 returns) and
  under MicroBeast firmware as-of-2026-05-05 (no Story 13.x hardware run
  has observed F_READ A>1 on healthy SD media). The Story 13.5.2 fix is
  structural — the helper signals correctly when the path fires; no
  hardware reproducer is in scope (impractical without a synthetic
  media-fault injector).
- `READ-FILE`'s I/O-error encoder mirrors `WRITE-FILE`'s `.wf_io_err`
  shape (sign-extend `A=0xFF` to `ior=0xFFFF` per Code Review L5). For
  READ-FILE, the helper applies `DEC A` so the helper-A range on CY=1 is
  0..254 — the 0xFF sign-extend is dead code in current call paths but
  retained for pattern-consistency with WRITE-FILE / CLOSE-FILE.

**Story 13.5.3 caveats (TD-5 closure 2026-05-06):**
- ANS §6.2.0190 `."` requires net stack effect `( -- )`. Pre-13.5.3 the
  interpret-mode tail of `w_DOT_QUOTE_cf` (at `src/strings.asm`'s
  `.dq_interpret` block) loaded the loop counter `C` with the
  remaining-TIB byte-count and decremented it on every iteration —
  destroying BC (the TOS-in-register cell per
  `docs/register-conventions.md`) without saving and restoring it. The
  defect was reachable from any interpret-mode invocation: REPL input,
  top level of an `INCLUDED` source file, or `EVALUATE`d strings outside
  a colon body. Compile-mode invocations (the `."` inside a `:` body
  case) were always TOS-safe — the compile-mode tail at
  `strings.asm:817/828` already wraps `compile_string` with
  `PUSH BC / POP BC`, and the runtime form `(S")` + inline string +
  `TYPE` net to `( -- )` correctly.
- Story 13.5.3 lands a `PUSH BC / POP BC` envelope around the
  interpret-mode work — `PUSH BC` at `.dq_interpret` entry, `POP BC` at
  `.dq_i_end` (single-exit, serves both the loop-exhaust path and the
  terminator-found path). Mirrors the existing compile-mode tail of the
  same word (`:817/828`) and the interpret-mode tail of `S"` at
  `src/strings.asm:715`. Code delta +2 bytes (1 × PUSH BC + 1 × POP BC),
  data delta 0 — at the floor of the Epic 13.5 +50..+200 envelope.
- The bug was **silent under all pre-13.5.3 regression probes**: every
  existing `."` test in the Makefile (REPL tests 69, 74, 75, plus the
  file-access harness use of `."` inside `:` definitions) either
  exercised compile mode (TOS-safe via the compile-mode tail's existing
  envelope) or did not assert TOS preservation across the interpret-mode
  call. Story 13.5.3 closes the regression-coverage gap with REPL tests
  952..955 (single-cell, multi-cell with intervening operations,
  empty-string, INCLUDED-file top-level interpret-mode), each
  verdict-modulated to assert post-fix behaviour. The pre-fix tree fails
  every one of (p1)..(p4); the post-fix tree passes all four.
- Origin lineage: surfaced as Story 13.5 adversarial review F2 (catalogue
  at
  `_bmad-output/implementation-artifacts/13-5-r-o-close-file-destructive-flush-audit-and-fix.md:217`),
  re-classified upward from "MED, accepted-with-rationale: pre-existing"
  to a tag-blocking correctness defect by the Epic 13 retrospective
  2026-05-05 (Tag-Blocking Slate row 13.5.3) under
  `feedback_no_preexisting_discharge.md` Lesson 13-B — the worked example
  cited in the project-lead reframe codifying the standing commitment.

**Story 13.5.4 caveats (TD-6 closure 2026-05-06):**
- ANS §6.2.2000 `PAD ( -- c-addr )` returns the address of a transient
  region for intermediate processing; per §3.3.3.6 the contents are
  unaffected by the application's parsing of any one space-delimited
  name. Pre-13.5.4 antforth shipped `/PAD ENVIRONMENT?` returning
  `( 84 -1 )` (claiming an 84-byte PAD region per §3.2.6) but **no
  `PAD` word existed** — calling `PAD` at the REPL threw -13 (undefined).
  The compliance claim diverged from the delivered surface. Story 13.5.4
  closes that gap by adding a real `PAD` word that returns
  `HERE + PAD_OFFSET` (84). The pad-at-HERE+84 location structurally
  satisfies the §3.3.3.6 single-parse survival guarantee because `WORD`
  stages its counted-string output at `HERE+0..HERE+u` (count byte at
  `HERE+0`, ≤31 chars at `HERE+1..HERE+u` per `F_LENMASK`; see
  `src/strings.asm:145` storing count and `:85` `INC HL` before char
  emission), leaving `HERE+32..HERE+84+` untouched by any single parse
  step. The 84-byte buffer at `[PAD, PAD+84)` is guaranteed stable
  across one WORD parse.
- **Canonical cross-line transient-buffer guidance** (added with
  Story 13.5.4, applies project-wide):
    - **`PAD`** = single-line transient region, up to 84 bytes,
      survives one WORD parse per §3.3.3.6. Use for short scratch
      buffers that need to survive across REPL lines.
    - **`CREATE BUF N ALLOT` named buffers** = permanent (until
      `MARKER` rollback or program exit), survive arbitrary parse /
      compile / `,` / `ALLOT` operations. Use for buffers larger than
      84 bytes or that need to survive across multiple parse steps,
      colon-definition compilation, or dictionary mutation.
    - **`HERE`** = volatile dictionary-boundary cursor; every `WORD`
      parse writes the counted-string output at `HERE+0..HERE+u`
      (count byte at `HERE+0`, ≤31 chars at `HERE+1..HERE+u` per
      F_LENMASK). HERE-as-buffer is **wrong for cross-line use** —
      the data at `HERE+0..HERE+31` is destroyed on the next REPL
      line's first parsed token. Same-line use (store
      and consume on one source line) is correct and idiomatic; the
      WORD/S" inner-interpreter consumers rely on this.
- **Pre-fix bug shape was dormant under regression tests:** no probe
  exercised (i) `PAD`-the-word directly (would have caught the missing
  word — would throw -13) or (ii) cross-line transient-buffer survival
  (the F-9 hardware-finding shape: line N stores READ-FILE output at
  HERE; line N+1 reads it back, gets the next-line WORD's counted
  string instead of file content). All Makefile and `tests/*.fth`
  HERE-as-buffer probes use HERE same-line — store, consume, discard
  on one source line — which is correct usage. Story 13.5.4 closes the
  regression-coverage gap with REPL tests 956..959, each
  verdict-modulated to assert post-fix behaviour: (p1) `PAD` returns a
  valid c-addr (pre-fix throws -13); (p2) PAD survives three
  intervening WORD parses across four REPL lines per §3.3.3.6;
  (p3) PAD across READ-FILE consume cycle pins the F-9 hardware-finding
  shape against the post-fix surface (`Hello!` from disk fixture survives
  the line-N+1 WORD parse for `PAD 6 TYPE`); (p4) HERE-vs-PAD
  volatility distinguishability — orthogonal regression sentinel that
  fails if either HERE somehow starts surviving parsing or PAD becomes
  volatile.
- **F-9 hardware reproducer fixed-on-hardware:** Story 13.6 hardware
  run-1 surfaced a smoke-batch probe shape `READ-FILE` at HERE on line
  N + `." SZ="` (counted-string TYPE) on line N+1 that emitted
  `\x04type\x1A` on real CP/M 2.2 (MicroBeast SD) instead of the file
  content — the line-N+1 parsed `." SZ="` had clobbered HERE+1..HERE+5
  with its counted-string output. Same shape latent on iz-cpm but
  no test caught it. Probe (p3) re-runs the F-9 reproducer shape against
  the post-fix `PAD` surface; AC #11 hardware smoke confirms the fix
  takes on real CP/M.
- **Origin lineage:** TD-6 was surfaced first as Story 13.5 adversarial
  review F3 (catalogue at
  `_bmad-output/implementation-artifacts/13-5-r-o-close-file-destructive-flush-audit-and-fix.md:217`,
  disposition row at `:306`: "LOW (out-of-scope, documented): F3 (PAD
  undefined). … Recommend separate stories for F2 (proper `."` fix)
  and F3 (add PAD per ANS Forth §6.2.2000)."), and again as Story 13.6
  hardware-finding F-9 at
  `_bmad-output/implementation-artifacts/13-6-epic-13-fs-stress-bdos-audit-and-antforth-2-0-release-gate-ccd-4.md:1192`
  (downgraded from HIGH-CANDIDATE to LOW after `src/strings.asm:85`
  inspection; revised diagnosis: "antforth's `WORD` writes counted-string
  output at HERE+1, clobbering whatever READ-FILE wrote there on the
  previous line. **HERE is volatile across REPL lines.**"). Both
  dispositions ("LOW out-of-scope" and "LOW NOT-a-kernel-defect") were
  retroactively re-classified upward at the Epic 13 retrospective
  2026-05-05 (Tag-Blocking Slate row 13.5.4) under
  `feedback_no_preexisting_discharge.md` Lesson 13-B — TD-6 was the
  second worked example (alongside TD-5) cited in the project-lead
  reframe codifying the "pre-existing is not a discharge for correctness"
  standing commitment.
- **Fix shape pick (c) chosen over (a) and (b)** because the catalogue
  evidence showed zero production-code cross-line transient-buffer needs
  but the `/PAD ENVIRONMENT?` compliance claim already presupposes
  PAD-the-word per §3.2.6. Pick (c) closes the surface gap at minimal
  byte cost (+26 bytes total: header 6 + body 20 — see Story 13.5.4
  Completion Notes Task 9) without disturbing UserArea slots (pick (a)
  HALT trigger) and without regressing the compliance claim by
  returning `( 0 0 )` from `/PAD ENVIRONMENT?` (pick (b) sub-clause).

**Story 13.5.5 caveats (TD-7 closure 2026-05-06):**
- DPANS94 §6.2.2182 `SAVE-INPUT ( -- xn ... x1 n )` and §6.2.2148
  `RESTORE-INPUT ( xn ... x1 n -- flag )` are user-facing CORE-EXT
  words for snapshotting and rewinding the input source spec.
  Pre-13.5.5 antforth shipped EVALUATE on top of private
  `(SAVE-INPUT)` / `(RESTORE-INPUT)` R-stack plumbing helpers
  (`outer_interpreter.asm:395-460`) but **no user-facing
  `SAVE-INPUT` or `RESTORE-INPUT` words existed** — calling either
  at the REPL threw -13 (undefined). The Core Extension count
  showed 12 of 46 even though both `EVALUATE` (§6.1.1360) and the
  underlying R-stack frame mechanism were already in place.
  Story 13.5.5 closes that gap by adding two new DEFCODE words
  with data-stack semantics that snapshot and restore the four
  USER-area source-spec cells (`tib_addr`, `tib_len`, `tib_in`,
  `source_id`) directly. The (paren) helpers are NOT modified
  (Story 13.4 v2 PD-11 / AC #14 leave-as-is in force).
- **Pick (a) uniform-quadruple description shape** (chosen from
  AC #2's two options): `SAVE-INPUT` pushes 5 cells —
  `( -- tib_addr tib_len >IN SOURCE-ID 4 )` — regardless of the
  current SOURCE-ID class. `RESTORE-INPUT` pops 5 cells, validates
  count == 4 then validates saved SOURCE-ID == current SOURCE-ID,
  writes back the four UserArea cells atomically, returns flag = 0.
  On count mismatch returns -1 (and the bogus cells remain on the
  stack — §6.2.2148 ambiguous condition). On SOURCE-ID mismatch
  drops the remaining 3 description cells, leaves UserArea
  unchanged, returns -1.
- **EVALUATE-arm primary scope** per the Tag-Blocking Slate row:
  within an EVALUATEd string, save → mutate-`>IN` → restore
  round-trips cleanly because the EVALUATEd string buffer doesn't
  rotate during INTERPRET (it's the c-addr / u the user passed;
  it lives until EVALUATE returns). The keyboard and INCLUDE-FILE
  arms work structurally with the cross-REFILL caveat below.
- **Cross-REFILL impl-defined deviation (keyboard / INCLUDE-FILE):**
  the SOURCE-ID-match check is necessary but NOT sufficient for
  cross-REFILL correctness. If a user calls `SAVE-INPUT` during
  keyboard input, `REFILL` rotates the TIB content, then
  `RESTORE-INPUT`, the SOURCE-ID still matches (0 = 0) but the
  bytes at `tib_addr` have changed since the SAVE-INPUT call —
  same shape for INCLUDE-FILE across a record refill. ANS allows
  this as an ambiguous condition (§6.2.2148: "An ambiguous
  condition exists if the input source represented by the
  arguments is not the same as the current input source");
  antforth's behaviour is honest — the flag mechanism flags the
  SOURCE-ID delta but cannot detect content rotation.
- **Story-spec §-citation correction:** the original Story 13.5.5
  spec (`13.5-5-…md`) cited DPANS94 §6.2.2148 for SAVE-INPUT and
  §6.2.2125 for RESTORE-INPUT. Both citations are inverted /
  wrong: per `reference_docs/DPANS94.txt:2747-2763`, §6.2.2148 =
  RESTORE-INPUT, §6.2.2182 = SAVE-INPUT, and §6.2.2125 = REFILL.
  The implementation, header comments, and this compliance doc
  use the correct DPANS94 citations per `feedback_standards_compliance.md`
  ("investigate the standard before defending code; the DPANS94
  text is binding"). No code consequence — only the section-number
  strings in comments and docs were affected.
- **Byte-budget envelope adjustment (AC #8 verdict-with-rationale):**
  pick (a) actual cost +134 bytes (production + filesanity binaries
  both moved by the same delta); above the `epics.md:1828` +50..+100
  estimate but below the +180 ceiling for pick (b). Project-lead
  authorisation 2026-05-06 to accept the +34 overshoot —
  Z80-arithmetic minimums dominate (29-byte DEFCODE headers for
  the two long names; 3-byte `(IY+d)` accesses; 7-byte NEXT macro
  shared once between success and fail paths). No scope creep;
  every byte maps to a §6.2.2148/§6.2.2182-mandated semantic
  step. Compactions applied: shared NEXT epilogue between the
  success path and the count-mismatch / src-mismatch fail paths
  (-5 bytes); count-mismatch path returns flag = -1 without
  cleaning the bogus description cells (impl-defined per ambiguous
  condition; -22 bytes vs a counted-drop loop); RESTORE-INPUT
  success path skips the redundant `(IY+UA.source_id) ← L/H`
  write-back since the preceding `CP L` / `CP H` comparisons
  already proved equality (-6 bytes; code-review follow-up
  2026-05-06).
- **Origin lineage:** TD-7 surfaced first as Story 13.4 v2 PD-11
  (`_bmad-output/implementation-artifacts/13-4-source-input-nesting-include-top-chain-discipline-v2.md:194-196`)
  / AC #14 (`:308-310`) with the disposition "EVALUATE-absorb scope:
  out of Story 13.4". The disposition was retroactively re-classified
  upward at the Epic 13 retrospective 2026-05-05 (Tag-Blocking Slate
  row 13.5.5) under `feedback_no_preexisting_discharge.md` Lesson
  13-B — the seventh worked example cited in the project-lead
  reframe codifying the "pre-existing / out-of-scope is not a
  discharge for compliance defects" standing commitment. Story
  13.5.5 closes the EVALUATE arm of TD-7; the keyboard /
  INCLUDE-FILE arms are closed structurally with the cross-REFILL
  caveat noted above.

### Non-standard words (not in Core or Core Extension)

antforth also defines words that are useful but outside the Core word sets:

| Word | Source | Standard word set |
|------|--------|-------------------|
| `WORDS` | `dictionary.asm:160` | TOOLS |
| `.S` | `formatting.asm:263` | TOOLS |
| `KEY?` | `io.asm:169` | FACILITY |
| `SP@` `SP!` `RP@` `RP!` | `stack_ops.asm:198,212,225,237` | Non-standard (common extension) |
| Z80 assembler (107 words) | `assembler.asm` | Non-standard (antforth extension) |

---

## Observations

### What antforth does well

- **Logic and comparison** — 100% Core compliance (12/12).
- **I/O** — 100% Core compliance (8/8).
- **Character** — 100% Core compliance (3/3).
- **Control flow** — 100% Core compliance (16/16).
- **Compiler** — 100% Core compliance (14/14).
- **Memory** — 100% Core compliance (17/17). Double-cell `2!` and `2@` landed in Story 10.2.
- **System** — 100% Core compliance (13/13). `EVALUATE` and `ENVIRONMENT?` landed in Story 10.9.
- **Stack ops** — 100% Core compliance (14/14). Double-cell quartet (Story 10.2) closed the last gap.
- **Arithmetic** — 100% Core compliance. Double-cell-substrate words: `FM/MOD` `SM/REM` `UM/MOD` landed in Story 10.6; `*/` and `*/MOD` (mixed-precision via double intermediate) landed in Story 10.9.

### Historical big gaps — all CLOSED by Epic 10

1. **Double-cell operations — CLOSED:** Stories 10.2–10.6 delivered the full double-cell foundation (stack/memory, `S>D`/`D>S`, §8.6 arithmetic / sign / compare, multiplication, division). Story 10.9 added the last two §6.1 mixed-precision words `*/` and `*/MOD` on top of `M*` (10.5) and `SM/REM` (10.6).

2. **Pictured numeric output — CLOSED by Story 10.7:** `<# # #S #> HOLD SIGN` (6 §6.1) plus `HOLDS` (§6.2 bonus) landed in `src/pictured.asm` backed by a 40-byte `pic_buf` in `UserArea` and the `HLD` USER variable. Story 10.8 rewrote `.` / `U.` / `.R` on this foundation and added `D.` / `U.R` / `D.R` (§6.2/§8.6 bonus) — the §6.1 display path preserved byte-for-byte.

3. **System single-word gaps — CLOSED by Story 10.9:** `EVALUATE` and `ENVIRONMENT?`. EVALUATE saves the four-cell input source spec (`tib_addr`, `tib_len`, `tib_in`, `source_id`) on the R-stack across an `INTERPRET` call. ENVIRONMENT? walks a 14-entry static §3.2.6 query-key table.

### §6.1 vs §8.6 — important Epic-10 scope distinction

DPANS94 separates §6.1 (Core) from §8.6 (Double-Number wordset). antforth's 100%-Core target (FR15 / NFR10) is measured against §6.1 only. Epic 10 implements both:

- §6.1 Core gap closure (22 words + `>NUMBER` upgrade) — the FR15 deliverable.
- §8.6 Double-Number bonus (13 words across Stories 10.4 / 10.5 / 10.8) — bonus coverage that lights up the double-cell substrate end-to-end.

The Epic-10 spec's headline "≈ 14% of §6.1 missing" maps to this report's 22-word gap inventory; the spec's broader "double-cell arithmetic" deliverable folds in §8.6 additions, which this report tracks separately so the §6.1 measurement remains clean.
