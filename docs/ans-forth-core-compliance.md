# ANS Forth Core Word Set Compliance Report

**Date:** 2026-04-13
**System:** antforth (Z80 Forth for CP/M)
**Reference:** DPANS94 (ANSI X3.215-1994), sections 6.1 (Core) and 6.2 (Core Extension)
**Source:** `src/*.asm`

## Summary

| Metric | Count |
|--------|-------|
| Total Core words in standard | 133 |
| Fully implemented | 111 |
| Partially implemented | 1 |
| Missing | 21 |
| **Core compliance** | **83.5%** |

| Gap Classification | Count |
|--------------------|-------|
| (a) Deliberately omitted | 1 |
| (b) Oversight — missing subsystem | 19 |
| (b) Oversight — moderate | 1 |
| (c) Partially implemented | 1 |

| Core Extension bonus | Count |
|----------------------|-------|
| Core Extension words implemented | 9 of 46 |

---

## Detailed Audit by Category

### Stack Operations

14 Core words — 10 implemented, 4 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `DUP` | `( x -- x x )` | Implemented | `stack_ops.asm:25` | |
| `DROP` | `( x -- )` | Implemented | `stack_ops.asm:35` | |
| `SWAP` | `( x1 x2 -- x2 x1 )` | Implemented | `stack_ops.asm:46` | |
| `OVER` | `( x1 x2 -- x1 x2 x1 )` | Implemented | `stack_ops.asm:60` | |
| `ROT` | `( x1 x2 x3 -- x2 x3 x1 )` | Implemented | `stack_ops.asm:75` | |
| `?DUP` | `( x -- 0 \| x x )` | Implemented | `stack_ops.asm:12` | |
| `2DROP` | `( x1 x2 -- )` | **Missing** | — | (b) Oversight; double-cell stack |
| `2DUP` | `( x1 x2 -- x1 x2 x1 x2 )` | **Missing** | — | (b) Oversight; double-cell stack |
| `2OVER` | `( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )` | **Missing** | — | (b) Oversight; double-cell stack |
| `2SWAP` | `( x1 x2 x3 x4 -- x3 x4 x1 x2 )` | **Missing** | — | (b) Oversight; double-cell stack |
| `DEPTH` | `( -- +n )` | Implemented | `stack_ops.asm:182` | |
| `>R` | `( x -- ) ( R: -- x )` | Implemented | `stack_ops.asm:253` | |
| `R>` | `( -- x ) ( R: x -- )` | Implemented | `stack_ops.asm:267` | |
| `R@` | `( -- x ) ( R: x -- x )` | Implemented | `stack_ops.asm:281` | |

### Arithmetic

19 Core words — 14 implemented, 5 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `+` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:55` | |
| `-` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:69` | |
| `*` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:86` | |
| `/` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:240` | |
| `MOD` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:256` | |
| `/MOD` | `( n1 n2 -- rem quot )` | Implemented | `arithmetic.asm:219` | |
| `*/` | `( n1 n2 n3 -- n4 )` | **Missing** | — | (b) Oversight; needs double-cell intermediate |
| `*/MOD` | `( n1 n2 n3 -- n4 n5 )` | **Missing** | — | (b) Oversight; needs double-cell intermediate |
| `1+` | `( n -- n+1 )` | Implemented | `arithmetic.asm:12` | |
| `1-` | `( n -- n-1 )` | Implemented | `arithmetic.asm:22` | |
| `2*` | `( x -- x*2 )` | Implemented | `arithmetic.asm:32` | |
| `2/` | `( x -- x/2 )` | Implemented | `arithmetic.asm:43` | |
| `ABS` | `( n -- u )` | Implemented | `bootstrap.asm:9` | DEFWORD |
| `NEGATE` | `( n -- -n )` | Implemented | `bootstrap.asm:22` | DEFWORD |
| `MAX` | `( n1 n2 -- n3 )` | Implemented | `bootstrap.asm:56` | DEFWORD |
| `MIN` | `( n1 n2 -- n3 )` | Implemented | `bootstrap.asm:38` | DEFWORD |
| `FM/MOD` | `( d n1 -- n2 n3 )` | **Missing** | — | (b) Oversight; floored division, needs double-cell |
| `SM/REM` | `( d n1 -- n2 n3 )` | **Missing** | — | (b) Oversight; symmetric division, needs double-cell |
| `S>D` | `( n -- d )` | **Missing** | — | (b) Oversight; sign-extend to double |

### Double-Cell and Mixed Arithmetic

3 Core words — 0 implemented, 3 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `M*` | `( n1 n2 -- d )` | **Missing** | — | (b) Oversight; mixed multiply producing double result |
| `UM*` | `( u1 u2 -- ud )` | **Missing** | — | (b) Oversight; unsigned mixed multiply |
| `UM/MOD` | `( ud u1 -- u2 u3 )` | **Missing** | — | (b) Oversight; unsigned double-cell division |

### Logic and Comparison

12 Core words — 12 implemented, 0 missing

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

17 Core words — 15 implemented, 2 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `!` | `( x a-addr -- )` | Implemented | `memory.asm:58` | |
| `@` | `( a-addr -- x )` | Implemented | `memory.asm:44` | |
| `C!` | `( char c-addr -- )` | Implemented | `memory.asm:88` | |
| `C@` | `( c-addr -- char )` | Implemented | `memory.asm:75` | |
| `2!` | `( x1 x2 a-addr -- )` | **Missing** | — | (b) Oversight; double-cell store |
| `2@` | `( a-addr -- x1 x2 )` | **Missing** | — | (b) Oversight; double-cell fetch |
| `+!` | `( n a-addr -- )` | Implemented | `memory.asm:103` | |
| `,` | `( x -- )` | Implemented | `memory.asm:151` | |
| `C,` | `( char -- )` | Implemented | `memory.asm:169` | |
| `HERE` | `( -- addr )` | Implemented | `memory.asm:124` | |
| `ALLOT` | `( n -- )` | Implemented | `memory.asm:136` | |
| `ALIGN` | `( -- )` | Implemented | `memory.asm:185` | |
| `ALIGNED` | `( addr -- a-addr )` | Implemented | `memory.asm:202` | |
| `CELLS` | `( n1 -- n2 )` | Implemented | `memory.asm:215` | |
| `CELL+` | `( a-addr1 -- a-addr2 )` | Implemented | `memory.asm:12` | |
| `FILL` | `( c-addr u char -- )` | Implemented | `memory.asm:226` | |
| `MOVE` | `( addr1 addr2 u -- )` | Implemented | `memory.asm:271` | |

### Character

3 Core words — 3 implemented, 0 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `CHAR` | `( "<spaces>name" -- char )` | Implemented | `strings.asm:169` | |
| `CHAR+` | `( c-addr1 -- c-addr2 )` | Implemented | `memory.asm:23` | INC BC; same as 1+ on Z80 (1 char = 1 byte) |
| `CHARS` | `( n1 -- n2 )` | Implemented | `memory.asm:33` | No-op on Z80 (1 char = 1 byte); provided for portability |

### I/O

8 Core words — 8 implemented, 0 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `EMIT` | `( x -- )` | Implemented | `io.asm:9` | |
| `KEY` | `( -- char )` | Implemented | `io.asm:173` | |
| `ACCEPT` | `( c-addr +n1 -- +n2 )` | Implemented | `io.asm:128` | |
| `CR` | `( -- )` | Implemented | `io.asm:63` | |
| `SPACE` | `( -- )` | Implemented | `io.asm:82` | |
| `SPACES` | `( n -- )` | Implemented | `io.asm:96` | |
| `TYPE` | `( c-addr u -- )` | Implemented | `io.asm:25` | |
| `BL` | `( -- char )` | Implemented | `outer_interpreter.asm:83` | |

### Numeric Output and Formatting

10 Core words — 4 implemented, 6 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `.` | `( n -- )` | Implemented | `formatting.asm:116` | |
| `."` | `( "ccc" -- )` | Implemented | `strings.asm:655` | IMMEDIATE |
| `U.` | `( u -- )` | Implemented | `formatting.asm:156` | |
| `DECIMAL` | `( -- )` | Implemented | `formatting.asm:459` | DEFWORD |
| `<#` | `( -- )` | **Missing** | — | (b) Oversight; pictured output subsystem absent |
| `#` | `( ud1 -- ud2 )` | **Missing** | — | (b) Oversight; pictured output subsystem absent |
| `#S` | `( ud1 -- ud2 )` | **Missing** | — | (b) Oversight; pictured output subsystem absent |
| `#>` | `( xd -- c-addr u )` | **Missing** | — | (b) Oversight; pictured output subsystem absent |
| `HOLD` | `( char -- )` | **Missing** | — | (b) Oversight; pictured output subsystem absent |
| `SIGN` | `( n -- )` | **Missing** | — | (b) Oversight; pictured output subsystem absent |

### String and Parsing

4 Core words — 4 implemented, 0 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `S"` | `( "ccc" -- c-addr u )` | Implemented | `strings.asm:543` | IMMEDIATE |
| `COUNT` | `( c-addr1 -- c-addr2 u )` | Implemented | `dictionary.asm:9` | |
| `WORD` | `( char -- c-addr )` | Implemented | `strings.asm:11` | |
| `>NUMBER` | `( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )` | Implemented | `strings.asm:266` | See semantic note below |

**Semantic note — `>NUMBER`:** Accepts the standard double-cell stack signature, but the high cell of `ud` is passed through unchanged. Functionally correct for single-cell number conversion. Full double-cell accumulation is not implemented.

### Control Flow

16 Core words — 16 implemented, 0 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `IF` | `( x -- )` | Implemented | `control_flow.asm:40` | DEFIMMED |
| `THEN` | `( -- )` | Implemented | `control_flow.asm:56` | DEFIMMED |
| `ELSE` | `( -- )` | Implemented | `control_flow.asm:73` | DEFIMMED |
| `BEGIN` | `( -- )` | Implemented | `control_flow.asm:97` | DEFIMMED |
| `UNTIL` | `( x -- )` | Implemented | `control_flow.asm:109` | DEFIMMED |
| `WHILE` | `( x -- )` | Implemented | `control_flow.asm:126` | DEFIMMED |
| `REPEAT` | `( -- )` | Implemented | `control_flow.asm:144` | DEFIMMED |
| `DO` | `( n1 n2 -- )` | Implemented | `control_flow.asm:367` | DEFIMMED |
| `LOOP` | `( -- )` | Implemented | `control_flow.asm:385` | DEFIMMED |
| `+LOOP` | `( n -- )` | Implemented | `control_flow.asm:424` | DEFIMMED |
| `I` | `( -- n )` | Implemented | `control_flow.asm:342` | |
| `J` | `( -- n )` | Implemented | `control_flow.asm:354` | |
| `LEAVE` | `( -- )` | Implemented | `control_flow.asm:462` | DEFIMMED |
| `UNLOOP` | `( -- )` | Implemented | `control_flow.asm:329` | |
| `EXIT` | `( -- )` | Implemented | `inner_interpreter.asm:26` | DEFCODE wrapping `EXIT_CODE` |
| `RECURSE` | `( -- )` | Implemented | `control_flow.asm:483` | IMMEDIATE flag |

### Compiler and Defining Words

14 Core words — 14 implemented, 0 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `:` | `( "<spaces>name" -- )` | Implemented | `compiler.asm:331` | |
| `;` | `( -- )` | Implemented | `compiler.asm:476` | IMMEDIATE |
| `CONSTANT` | `( x "<spaces>name" -- )` | Implemented | `compiler.asm:626` | |
| `VARIABLE` | `( "<spaces>name" -- )` | Implemented | `bootstrap.asm:74` | DEFWORD |
| `CREATE` | `( "<spaces>name" -- )` | Implemented | `compiler.asm:566` | |
| `DOES>` | `( -- )` | Implemented | `compiler.asm:692` | IMMEDIATE |
| `IMMEDIATE` | `( -- )` | Implemented | `compiler.asm:311` | |
| `LITERAL` | `( x -- )` | Implemented | `compiler.asm:538` | IMMEDIATE |
| `POSTPONE` | `( "<spaces>name" -- )` | Implemented | `compiler.asm:251` | DEFIMMED |
| `[` | `( -- )` | Implemented | `compiler.asm:515` | IMMEDIATE |
| `]` | `( -- )` | Implemented | `compiler.asm:526` | |
| `STATE` | `( -- a-addr )` | Implemented | `outer_interpreter.asm:26` | |
| `[']` | `( "<spaces>name" -- xt )` | Implemented | `compiler.asm:54` | DEFIMMED |
| `[CHAR]` | `( "<spaces>name" -- char )` | Implemented | `compiler.asm:66` | DEFIMMED |

### System and Interpreter

13 Core words — 11 implemented, 2 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `EXECUTE` | `( xt -- )` | Implemented | `inner_interpreter.asm:194` | |
| `FIND` | `( c-addr -- c-addr 0 \| xt 1 \| xt -1 )` | Implemented | `dictionary.asm:22` | Hash-table lookup |
| `ABORT` | `( -- )` | Implemented | `system.asm:218` | |
| `QUIT` | `( -- )` | Implemented | `outer_interpreter.asm:237` | |
| `>IN` | `( -- a-addr )` | Implemented | `outer_interpreter.asm:46` | |
| `BASE` | `( -- a-addr )` | Implemented | `outer_interpreter.asm:36` | |
| `SOURCE` | `( -- c-addr u )` | Implemented | `outer_interpreter.asm:66` | |
| `(` | `( "ccc)" -- )` | Implemented | `strings.asm:838` | IMMEDIATE |
| `'` | `( "<spaces>name" -- xt )` | Implemented | `compiler.asm:25` | DEFWORD |
| `>BODY` | `( xt -- a-addr )` | Implemented | `compiler.asm:10` | xt+5 (skips JP + does-addr) |
| `ABORT"` | `( "ccc" x -- )` | Implemented | `system.asm:178` | IMMEDIATE; runtime `(ABORT")` at `system.asm:112` |
| `EVALUATE` | `( c-addr u -- )` | **Missing** | — | (b) Oversight; requires input source switching |
| `ENVIRONMENT?` | `( c-addr u -- false \| true )` | **Missing** | — | (a) Deliberately omitted; complex query system, rarely used |

---

## Gap Analysis

### (a) Deliberately Omitted — 1 word

| Word | Rationale |
|------|-----------|
| `ENVIRONMENT?` | Complex metadata query system for implementation-defined limits. Rarely used by portable programs. Low value-to-effort ratio. |

### (b) Oversight — 20 words

#### System — 1 word

| Word | Complexity | Notes |
|------|-----------|-------|
| `EVALUATE` | Moderate | Save/restore input source, then interpret from string |

#### Missing subsystem: Pictured numeric output — 6 words

antforth uses `.` and `U.` directly without the ANS pictured output subsystem. The following 6 words form a single cohesive subsystem:

`<#` `#` `#S` `#>` `HOLD` `SIGN`

These provide user-customisable number formatting (e.g., formatted currency, leading zeroes, field padding). Adding these requires a pictured output buffer and the conversion loop.

#### Missing subsystem: Double-cell operations — 13 words

antforth is a single-cell (16-bit) system. The following words operate on double-cell (32-bit) values and form an interdependent group:

| Sub-group | Words |
|-----------|-------|
| Double-cell stack | `2DROP` `2DUP` `2OVER` `2SWAP` |
| Double-cell memory | `2!` `2@` |
| Double-cell arithmetic | `S>D` `M*` `UM*` `UM/MOD` `FM/MOD` `SM/REM` |
| Mixed-precision | `*/` `*/MOD` |

`*/` and `*/MOD` use a double-cell intermediate (n1*n2 as 32-bit before dividing by n3), so they depend on the double-cell arithmetic primitives.

### (c) Partially Implemented — 1 word

| Word | Status | Details |
|------|--------|---------|
| `>NUMBER` | Single-cell only | `strings.asm:266` accepts the standard double-cell stack signature `( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )` but the high cell of `ud` is passed through unchanged. Number conversion accumulates into the low cell only. Functionally correct for values that fit in 16 bits. |

---

## Core Extension Bonus Coverage

9 of 46 DPANS94 Core Extension words are implemented, listed below. These are optional and do not affect Core compliance.

| Word | Stack Effect | Source | Notes |
|------|-------------|--------|-------|
| `.R` | `( n1 n2 -- )` | `formatting.asm:180` | Right-aligned numeric output |
| `COMPILE,` | `( xt -- )` | `compiler.asm:251` | Append execution semantics |
| `HEX` | `( -- )` | `formatting.asm:446` | Set BASE to 16 |
| `MARKER` | `( "<spaces>name" -- )` | `system.asm:22` | Snapshot/restore dictionary state |
| `PICK` | `( xu...x0 u -- xu...x0 xu )` | `stack_ops.asm:80` | |
| `ROLL` | `( xu...x0 u -- xu-1...x0 xu )` | `stack_ops.asm:98` | |
| `\` | `( "ccc" -- )` | `strings.asm:761` | Line comment; IMMEDIATE |
| `#TIB` | `( -- a-addr )` | `outer_interpreter.asm:56` | Obsolescent in Forth-2012 |
| `QUERY` | `( -- )` | `outer_interpreter.asm:96` | Obsolescent in Forth-2012 |

### Non-standard words (not in Core or Core Extension)

antforth also defines words that are useful but outside the Core word sets:

| Word | Source | Standard word set |
|------|--------|-------------------|
| `WORDS` | `dictionary.asm:160` | TOOLS |
| `.S` | `formatting.asm:297` | TOOLS |
| `KEY?` | `io.asm:189` | FACILITY |
| `SP@` `SP!` `RP@` `RP!` | `stack_ops.asm` | Non-standard (common extension) |
| Z80 assembler (107 words) | `assembler.asm` | Non-standard (antforth extension) |

---

## Observations

### What antforth does well

- **Logic and comparison** — 100% Core compliance (12/12).
- **I/O** — 100% Core compliance (8/8).
- **String and parsing** — 100% Core compliance (4/4).
- **Control flow** — 100% Core compliance (16/16).
- **Compiler** — 100% Core compliance (14/14).
- **Character** — 100% Core compliance (3/3).
- **Memory** — Near-complete (15/17); only double-cell `2!` and `2@` missing.
- **System** — Near-complete (11/13); only `EVALUATE` and `ENVIRONMENT?` missing.

### The two big gaps

1. **Double-cell operations (13 words):** antforth has no 32-bit arithmetic. This is the single largest gap and affects stack, memory, arithmetic, and mixed-precision categories. Adding the double-cell primitives (`M*`, `UM*`, `UM/MOD`, `S>D`) would unblock `FM/MOD`, `SM/REM`, `*/`, and `*/MOD` as well.

2. **Pictured numeric output (6 words):** The `<# # #S #> HOLD SIGN` subsystem is entirely absent. antforth prints numbers with `.` and `U.` directly. Adding pictured output enables user-customisable number formatting.
