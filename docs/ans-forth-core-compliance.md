# ANS Forth Core Word Set Compliance Report

**Date:** 2026-04-20 (Story 10.1 refresh)
**Last full audit:** 2026-04-13 (Story 5.3)
**System:** antforth (Z80 Forth for CP/M)
**Reference:** DPANS94 (ANSI X3.215-1994), §6.1 (Core), §6.2 (Core Extension); cross-referenced against §8.6 (Double-Number wordset) for Epic-10 scope reconciliation
**Source:** `src/*.asm`

## Summary

| Metric | Count | % of 133 |
|--------|-------|----------|
| Total §6.1 Core words in standard | 133 | 100.0% |
| Fully implemented | 118 | 88.7% |
| Partial | 0 | 0.0% |
| Missing | 15 | 11.3% |
| **Coverage** | **118 / 133** | **88.7%** |

**Note on counts:** The previous (2026-04-13) audit's Summary reported 111 / 1 / 21 — that totals 133 only by double-counting `>NUMBER`. Per-category sums show 22 missing, not 21. This refresh corrects the off-by-one and reports both compliance numbers. The 83.5% headline figure is preserved (lenient convention) for continuity with the Epic-10 baseline; the strict 82.7% is recorded for transparency.

**Which figure feeds FR15 / NFR10?** The **lenient 111 / 133 = 83.5%** is the canonical baseline measurement for the Epic-10 entry gate. The Epic-10 close-out gate (Story 10.10, NFR10) measures **133 fully-implemented = 100% Core with zero deliberate omissions**, at which point the Partial classification becomes empty (`>NUMBER` upgraded by Story 10.3) and the strict / lenient distinction collapses. (See 2026-04-20 party-mode decision note in Gap Analysis: `ENVIRONMENT?` is reclassified from deliberate-omission to Story 10.9 deliverable.)

| Gap Classification | Count |
|--------------------|-------|
| (a) Deliberately omitted | 0 |
| (b) Oversight — missing subsystem | 13 |
| (b) Oversight — moderate | 2 |
| (c) Partially implemented | 0 |

| Core Extension bonus | Count |
|----------------------|-------|
| Core Extension words implemented (§6.2) | 9 of 46 |

### Epic-10 closure plan

Epic 10 closes the §6.1 gap. Per-story increments (§6.1 Core only — §8.6 Double-Number additions are bonus and tracked separately):

| Story | Sub-family | §6.1 words added | Notes |
|---|---|---|---|
| 10.2 | Double-cell stack & memory | 6 (`2DROP` `2DUP` `2OVER` `2SWAP` `2!` `2@`) | foundation |
| 10.3 | Single ↔ double conversions | 1 (`S>D`) ✓ + `>NUMBER` Partial→Full ✓ + `D>S` (§8.6 bonus) ✓ | Complete |
| 10.4 | Double arithmetic / compare / sign | 0 §6.1 | All §8.6 bonus (`D+` `D-` `DNEGATE` `DABS` `D=` `D<` `DMAX` `DMIN` `M+`) |
| 10.5 | Double multiplication | 2 (`M*` `UM*`) | `D*` is §8.6 bonus |
| 10.6 | Double / mixed division | 3 (`FM/MOD` `SM/REM` `UM/MOD`) | |
| 10.7 | Pictured numeric output primitives | 6 (`<#` `#` `#S` `#>` `HOLD` `SIGN`) + `HOLDS` (§6.2 bonus) | |
| 10.8 | Number-output rewrite on pictured foundation | 0 net new §6.1 | `.` `U.` `.R` rewritten; `D.` `U.R` `D.R` are §6.2/§8.6 bonus |
| 10.9 | Remaining §6.1 Core gap words | 4 (`*/` `*/MOD` `EVALUATE` `ENVIRONMENT?`) | `ENVIRONMENT?` added to 10.9 scope on 2026-04-20 (party-mode decision); reclassified from deliberate-omission to gap-to-implement |
| **Total §6.1 closed** | | **22** | + `>NUMBER` Partial → Full |

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

19 §6.1 Core words — 14 implemented, 5 missing.

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `+` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:55` | |
| `-` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:69` | |
| `*` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:86` | |
| `/` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:240` | |
| `MOD` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:256` | |
| `/MOD` | `( n1 n2 -- rem quot )` | Implemented | `arithmetic.asm:219` | |
| `*/` | `( n1 n2 n3 -- n4 )` | **Gap → Story 10.9** | — | Needs double-cell intermediate; depends on Stories 10.5/10.6 primitives |
| `*/MOD` | `( n1 n2 n3 -- n4 n5 )` | **Gap → Story 10.9** | — | Needs double-cell intermediate; depends on Stories 10.5/10.6 primitives |
| `1+` | `( n -- n+1 )` | Implemented | `arithmetic.asm:13` | |
| `1-` | `( n -- n-1 )` | Implemented | `arithmetic.asm:23` | |
| `2*` | `( x -- x*2 )` | Implemented | `arithmetic.asm:33` | |
| `2/` | `( x -- x/2 )` | Implemented | `arithmetic.asm:44` | |
| `ABS` | `( n -- u )` | Implemented | `bootstrap.asm:22` | DEFWORD |
| `NEGATE` | `( n -- -n )` | Implemented | `bootstrap.asm:9` | DEFWORD |
| `MAX` | `( n1 n2 -- n3 )` | Implemented | `bootstrap.asm:56` | DEFWORD |
| `MIN` | `( n1 n2 -- n3 )` | Implemented | `bootstrap.asm:38` | DEFWORD |
| `FM/MOD` | `( d n1 -- n2 n3 )` | **Gap → Story 10.6** | — | Floored division on double dividend |
| `SM/REM` | `( d n1 -- n2 n3 )` | **Gap → Story 10.6** | — | Symmetric division on double dividend |
| `S>D` | `( n -- d )` | Implemented | `double.asm:151` | Sign-extend single → double |

### Double-Cell and Mixed-Precision Multiplication

2 §6.1 Core words — 0 implemented, 2 missing.

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `M*` | `( n1 n2 -- d )` | **Gap → Story 10.5** | — | Signed mixed multiply, single×single → double |
| `UM*` | `( u1 u2 -- ud )` | **Gap → Story 10.5** | — | Unsigned mixed multiply |

### Double-Cell Division

1 §6.1 Core word — 0 implemented, 1 missing. (`FM/MOD` and `SM/REM` are listed in Arithmetic above; `UM/MOD` here.)

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `UM/MOD` | `( ud u1 -- u2 u3 )` | **Gap → Story 10.6** | — | Unsigned double / single → single quotient + remainder |

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

10 §6.1 Core words — 4 implemented, 6 missing.

| Word | Stack Effect | Status | Source / Story | Notes |
|------|-------------|--------|----------------|-------|
| `.` | `( n -- )` | Implemented | `formatting.asm:133` | Story 10.8 will rewrite atop pictured-output primitives, preserving observable behaviour |
| `."` | `( "ccc" -- )` | Implemented | `strings.asm:701` | IMMEDIATE |
| `U.` | `( u -- )` | Implemented | `formatting.asm:154` | Story 10.8 rewrite (as `.`) |
| `DECIMAL` | `( -- )` | Implemented | `formatting.asm:383` | DEFWORD |
| `<#` | `( -- )` | **Gap → Story 10.7** | — | Pictured-output subsystem foundation |
| `#` | `( ud1 -- ud2 )` | **Gap → Story 10.7** | — | Pictured-output subsystem. (Note: `assembler.asm:985` defines a DEFCODE `#` as the assembler's immediate-operand sigil — that is a non-standard antforth-extension word, **not** the §6.1 pictured-output `#`.) |
| `#S` | `( ud1 -- ud2 )` | **Gap → Story 10.7** | — | Pictured-output subsystem |
| `#>` | `( xd -- c-addr u )` | **Gap → Story 10.7** | — | Pictured-output subsystem |
| `HOLD` | `( char -- )` | **Gap → Story 10.7** | — | Pictured-output subsystem |
| `SIGN` | `( n -- )` | **Gap → Story 10.7** | — | Pictured-output subsystem |

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
| `EVALUATE` | `( c-addr u -- )` | **Gap → Story 10.9** | — | Requires input source switching |
| `ENVIRONMENT?` | `( c-addr u -- false \| true )` | **Gap → Story 10.9** | — | DPANS94 §6.1.1345. Reclassified from deliberate-omission to Story 10.9 scope on 2026-04-20 (party-mode decision — ~80–120 byte cost; query table per §3.2.6). |

---

## Gap Analysis

### (a) Deliberately Omitted — 0 words

No §6.1 Core word is deliberately omitted from antforth. Every §6.1 word is either implemented, partial (→ Story 10.3), or a gap routed to one of Stories 10.2–10.9 for implementation.

**Historical note (2026-04-20 party-mode decision):** `ENVIRONMENT?` was previously classified as "deliberately omitted (low value-to-effort)" by Story 5.3 and upheld by the Story 10.1 surveyor. On 2026-04-20, the implementation cost was re-estimated at ~80–120 bytes (straight §3.2.6 query-key table) and the classification was overturned: `ENVIRONMENT?` is now a Story 10.9 deliverable. This keeps FR15 / NFR10's "100% of the ANS Forth 1994 Core wordset" claim literal — 133 / 133 words, no carve-out, no asterisk.

### (b) Oversight — 22 words (20 in two missing subsystems + 2 moderate single-word gaps)

#### Missing subsystem: Pictured numeric output — 6 words → Story 10.7

antforth uses `.` and `U.` directly (`formatting.asm:133`, `:154`) without the ANS pictured-output subsystem. The following 6 words form a single cohesive subsystem owned by **Story 10.7**:

`<#` `#` `#S` `#>` `HOLD` `SIGN`

These provide user-customisable number formatting (e.g., formatted currency, leading zeroes, field padding). Adding these requires a pictured-output buffer (architecture decision E10-D2 at `architecture.md:254-258`) and a double-cell conversion loop. Story 10.7 also adds the Forth-2014 `HOLDS` (§6.2.1675) as a §6.2 Core Extension bonus.

Story 10.8 then rewrites `.` / `U.` / `.R` (and adds `D.` `U.R` `D.R` as §6.2/§8.6 bonus) atop this foundation.

#### Missing subsystem: Double-cell operations — 14 §6.1 words → Stories 10.2 / 10.3 / 10.5 / 10.6 / 10.9

antforth is a single-cell (16-bit) system. The following §6.1 Core words operate on double-cell (32-bit) values:

| Sub-group | §6.1 words | Story |
|-----------|------------|-------|
| Double-cell stack | `2DROP` `2DUP` `2OVER` `2SWAP` | 10.2 ✓ Implemented |
| Double-cell memory | `2!` `2@` | 10.2 ✓ Implemented |
| Single → double | `S>D` | 10.3 ✓ Implemented |
| Double / mixed multiplication | `M*` `UM*` | 10.5 |
| Double / mixed division | `FM/MOD` `SM/REM` `UM/MOD` | 10.6 |
| Mixed-precision (need double intermediate) | `*/` `*/MOD` | 10.9 |

**`*/` and `*/MOD` use a double-cell intermediate** (n1×n2 as 32-bit before dividing by n3), so they depend on Stories 10.5 (`M*`) and 10.6 (`SM/REM` or `FM/MOD`) being complete. They are routed to Story 10.9 (which absorbs all post-foundation §6.1 stragglers).

#### Moderate single-word gaps — 2 words → Story 10.9

| Word | Story | Complexity | Notes |
|------|-------|-----------|-------|
| `EVALUATE` | 10.9 | Moderate | DPANS94 §6.1.1360. Save/restore input source, then interpret from string. Independent of double-cell infrastructure. |
| `ENVIRONMENT?` | 10.9 | Low | DPANS94 §6.1.1345. Query table of 14 implementation-defined limits per §3.2.6 (`/COUNTED-STRING`, `/HOLD`, `/PAD`, `ADDRESS-UNIT-BITS`, `CORE`, `CORE-EXT`, `FLOORED`, `MAX-CHAR`, `MAX-D`, `MAX-N`, `MAX-U`, `MAX-UD`, `RETURN-STACK-CELLS`, `STACK-CELLS`). Added to Story 10.9 on 2026-04-20 (party-mode decision). |

### (c) Partially Implemented — 0 words (empty after Story 10.3)

`>NUMBER` was the sole Partial entry. Story 10.3 upgraded it to full 32-bit accumulation at `strings.asm:338`, so this category is now empty and the lenient / strict coverage distinction collapses.

---

## Core Extension Bonus Coverage

9 of 46 DPANS94 §6.2 Core Extension words are implemented. (Forth-2012 / Forth-2014 added several §6.2 entries beyond DPANS94 1994 — `HOLDS` at §6.2.1675 is one — which is why `forth-standard.org` shows a higher §6.2 count than DPANS94 itself. This report's measurement uses the DPANS94 1994 baseline (46) for the bonus tally; the Forth-2014 additions implemented (or planned) are noted in the "Will gain via Epic 10" sub-section.)

| Word | Stack Effect | Source | Notes |
|------|-------------|--------|-------|
| `.R` | `( n1 n2 -- )` | `formatting.asm:174` | Right-aligned numeric output; Story 10.8 rewrites on pictured foundation |
| `COMPILE,` | `( xt -- )` | `compiler.asm:321` | Append execution semantics |
| `HEX` | `( -- )` | `formatting.asm:370` | Set BASE to 16 |
| `MARKER` | `( "<spaces>name" -- )` | `system.asm:22` | Snapshot/restore dictionary state |
| `PICK` | `( xu...x0 u -- xu...x0 xu )` | `stack_ops.asm:94` | |
| `ROLL` | `( xu...x0 u -- xu-1...x0 xu )` | `stack_ops.asm:112` | |
| `\` | `( "ccc" -- )` | `strings.asm:806` | Line comment; F_IMMEDIATE |
| `#TIB` | `( -- a-addr )` | `outer_interpreter.asm:56` | Obsolescent in Forth-2012 |
| `QUERY` | `( -- )` | `outer_interpreter.asm:96` | Obsolescent in Forth-2012 |

### §6.2 Will gain via Epic 10

| Word | §-number | Story | Notes |
|------|----------|-------|-------|
| `HOLDS` | 6.2.1675 | 10.7 | Forth-2014 addition; counterpart of `HOLD` for strings |
| `U.R` | 6.2.2330 | 10.8 | Right-aligned unsigned print on pictured foundation |

### §8.6 Double-Number wordset — bonus coverage planned by Epic 10

These words are **not in §6.1 Core** and therefore are NOT part of the FR15 100%-Core target. Epic 10's Stories 10.4 / 10.5 / 10.8 add them as bonus coverage atop the §6.1 foundation. Listed here so the audit trail records the §6.1-vs-§8.6 distinction explicitly.

| Word | §-number | Story | Notes |
|------|----------|-------|-------|
| `D+` | 8.6.1040 | 10.4 | Double-cell add |
| `D-` | 8.6.1050 | 10.4 | Double-cell subtract |
| `DNEGATE` | 8.6.1230 | 10.4 | Double-cell negate |
| `DABS` | 8.6.1160 | 10.4 | Double-cell abs |
| `D=` | 8.6.1120 | 10.4 | Double-cell equality |
| `D<` | 8.6.1110 | 10.4 | Double-cell signed less-than |
| `DMAX` | 8.6.1210 | 10.4 | Double-cell max |
| `DMIN` | 8.6.1220 | 10.4 | Double-cell min |
| `M+` | 8.6.1830 | 10.4 | Mixed add (d + n → d) |
| `D*` | 8.6.1090 | 10.5 | Double-cell multiply (truncating) |
| `D.` | 8.6.1060 | 10.8 | Double-cell signed print |
| `D.R` | 8.6.1070 | 10.8 | Double-cell right-aligned print |
| `D>S` | 8.6.1140 | Implemented (`double.asm:172`) | Double-narrow → single (truncating) |

(13 §8.6 additions planned; none on the §6.1 critical path.)

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
- **System** — Near-complete (11/13); `EVALUATE` and `ENVIRONMENT?` remaining, both routed to Story 10.9.
- **Stack ops** — 100% Core compliance (14/14). Double-cell quartet (Story 10.2) closed the last gap.
- **Arithmetic single-cell** — 14/14 single-cell complete; the 5 missing words all need a double-cell substrate.

### The two big gaps

1. **Double-cell operations (14 §6.1 words):** antforth has no 32-bit arithmetic. This is the single largest §6.1 gap and feeds Stories 10.2 (stack/memory foundation), 10.3 (single↔double conversion), 10.5 (multiplication), 10.6 (division), and 10.9 (mixed-precision `*/`/`*/MOD`). Adding the double-cell primitives also unblocks `>NUMBER`'s Partial → Full upgrade.

2. **Pictured numeric output (6 §6.1 words + `HOLDS` §6.2 bonus):** The `<# # #S #> HOLD SIGN` subsystem is entirely absent. Story 10.7 adds it; Story 10.8 then rewrites the existing `.` `U.` `.R` to use it (and adds the §6.2/§8.6 bonus print words `D.` `U.R` `D.R`).

### §6.1 vs §8.6 — important Epic-10 scope distinction

DPANS94 separates §6.1 (Core) from §8.6 (Double-Number wordset). antforth's 100%-Core target (FR15 / NFR10) is measured against §6.1 only. Epic 10 implements both:

- §6.1 Core gap closure (22 words + `>NUMBER` upgrade) — the FR15 deliverable.
- §8.6 Double-Number bonus (13 words across Stories 10.4 / 10.5 / 10.8) — bonus coverage that lights up the double-cell substrate end-to-end.

The Epic-10 spec's headline "≈ 14% of §6.1 missing" maps to this report's 22-word gap inventory; the spec's broader "double-cell arithmetic" deliverable folds in §8.6 additions, which this report tracks separately so the §6.1 measurement remains clean.
