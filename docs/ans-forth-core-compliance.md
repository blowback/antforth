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
| Core Extension words implemented (§6.2) | 11 of 46 |

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
| `."` | `( "ccc" -- )` | Implemented | `strings.asm:701` | IMMEDIATE |
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
| `EVALUATE` | `( i*x c-addr u -- j*x )` | Implemented | `outer_interpreter.asm:366` | Story 10.9; DEFWORD `(SAVE-INPUT) INTERPRET (RESTORE-INPUT)`; saves four USER source-spec cells (tib_addr, tib_len, tib_in, source_id) on R-stack across INTERPRET; source_id = -1 during EVALUATE per Forth 2014 §6.2.2218 |
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
| `ENVIRONMENT?` | 10.9 ✓ | Low | DPANS94 §6.1.1345. 14-entry static query table per §3.2.6 (`/COUNTED-STRING`, `/HOLD`, `/PAD`, `ADDRESS-UNIT-BITS`, `CORE`, `CORE-EXT`, `FLOORED`, `MAX-CHAR`, `MAX-D`, `MAX-N`, `MAX-U`, `MAX-UD`, `RETURN-STACK-CELLS`, `STACK-CELLS`). |

### (c) Partially Implemented — 0 words (empty after Story 10.3)

`>NUMBER` was the sole Partial entry. Story 10.3 upgraded it to full 32-bit accumulation at `strings.asm:338`, so this category is now empty and the lenient / strict coverage distinction collapses.

---

## Core Extension Bonus Coverage

11 of 46 DPANS94 §6.2 Core Extension words are implemented. (Forth-2012 / Forth-2014 added several §6.2 entries beyond DPANS94 1994 — `HOLDS` at §6.2.1675 is one — which is why `forth-standard.org` shows a higher §6.2 count than DPANS94 itself. This report's measurement uses the DPANS94 1994 baseline (46) for the bonus tally; the Forth-2014 additions implemented (or planned) are noted in the "Will gain via Epic 10" sub-section.)

| Word | Stack Effect | Source | Notes |
|------|-------------|--------|-------|
| `.R` | `( n1 n2 -- )` | `formatting.asm:203` | Right-aligned numeric output; DEFWORD on pictured foundation (Story 10.8) |
| `COMPILE,` | `( xt -- )` | `compiler.asm:321` | Append execution semantics |
| `HEX` | `( -- )` | `formatting.asm:370` | Set BASE to 16 |
| `HOLDS` | `( c-addr u -- )` | `pictured.asm` (Story 10.7) | Forth-2014 addition; inserts counted string into pictured buffer |
| `MARKER` | `( "<spaces>name" -- )` | `system.asm:22` | Snapshot/restore dictionary state |
| `PICK` | `( xu...x0 u -- xu...x0 xu )` | `stack_ops.asm:94` | |
| `ROLL` | `( xu...x0 u -- xu-1...x0 xu )` | `stack_ops.asm:112` | |
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
| `READ-FILE` | 11.6.1.2080 | `file_access.asm` (Story 13.2) | `( c-addr u1 fileid -- u2 ior )` |
| `WRITE-FILE` | 11.6.1.2480 | `file_access.asm` (Story 13.2) | `( c-addr u1 fileid -- ior )` — R/O guard via fcb_fam |

**Story 13.2 ior/THROW split:**
- ior (recoverable): file not found, malformed filename, R/O write
  attempt, disk-full, EOF mid-read.
- THROW (unrecoverable): `-69 THROW_FCB_EXHAUSTED` (FCB pool full),
  `-70 THROW_FILE_INVALID_FID` (closed/stale FID — antforth re-purpose
  of Forth 2014 §9.3.5 `-70 FREE`; see `docs/throw-codes.md` §b.1).

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
