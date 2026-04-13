# ANS Forth Core Word Set Compliance Report

**Date:** 2026-04-12
**System:** antforth (Z80 Forth for CP/M)
**Reference:** DPANS94 (ANSI X3.215-1994), sections 6.1 (Core) and 6.2 (Core Extension)
**Source:** `src/*.asm`

## Summary

| Metric | Count |
|--------|-------|
| Total Core words in standard | 133 |
| Fully implemented | 96 |
| Partially implemented | 2 |
| Missing | 35 |
| **Core compliance** | **72.2%** |

| Gap Classification | Count |
|--------------------|-------|
| (a) Deliberately omitted | 3 |
| (b) Oversight — simple words | 14 |
| (b) Oversight — missing subsystem | 18 |
| (c) Partially implemented | 2 |

| Core Extension bonus | Count |
|----------------------|-------|
| Core Extension words implemented | 9 of 46 |

---

## Detailed Audit by Category

### Stack Operations

14 Core words — 9 implemented, 5 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `DUP` | `( x -- x x )` | Implemented | `stack_ops.asm:13` | |
| `DROP` | `( x -- )` | Implemented | `stack_ops.asm:23` | |
| `SWAP` | `( x1 x2 -- x2 x1 )` | Implemented | `stack_ops.asm:34` | |
| `OVER` | `( x1 x2 -- x1 x2 x1 )` | Implemented | `stack_ops.asm:48` | |
| `ROT` | `( x1 x2 x3 -- x2 x3 x1 )` | Implemented | `stack_ops.asm:63` | |
| `?DUP` | `( x -- 0 \| x x )` | **Missing** | — | (b) Oversight; simple to add |
| `2DROP` | `( x1 x2 -- )` | **Missing** | — | (b) Oversight; double-cell stack |
| `2DUP` | `( x1 x2 -- x1 x2 x1 x2 )` | **Missing** | — | (b) Oversight; double-cell stack |
| `2OVER` | `( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )` | **Missing** | — | (b) Oversight; double-cell stack |
| `2SWAP` | `( x1 x2 x3 x4 -- x3 x4 x1 x2 )` | **Missing** | — | (b) Oversight; double-cell stack |
| `DEPTH` | `( -- +n )` | Implemented | `stack_ops.asm:170` | |
| `>R` | `( x -- ) ( R: -- x )` | Implemented | `stack_ops.asm:241` | |
| `R>` | `( -- x ) ( R: x -- )` | Implemented | `stack_ops.asm:255` | |
| `R@` | `( -- x ) ( R: x -- x )` | Implemented | `stack_ops.asm:269` | |

### Arithmetic

19 Core words — 10 implemented, 9 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `+` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:13` | |
| `-` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:27` | |
| `*` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:44` | |
| `/` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:198` | |
| `MOD` | `( n1 n2 -- n3 )` | Implemented | `arithmetic.asm:214` | |
| `/MOD` | `( n1 n2 -- rem quot )` | Implemented | `arithmetic.asm:177` | |
| `*/` | `( n1 n2 n3 -- n4 )` | **Missing** | — | (b) Oversight; needs double-cell intermediate |
| `*/MOD` | `( n1 n2 n3 -- n4 n5 )` | **Missing** | — | (b) Oversight; needs double-cell intermediate |
| `1+` | `( n -- n+1 )` | **Missing** | — | (b) Oversight; trivial |
| `1-` | `( n -- n-1 )` | **Missing** | — | (b) Oversight; trivial |
| `2*` | `( x -- x*2 )` | **Missing** | — | (b) Oversight; single left shift |
| `2/` | `( x -- x/2 )` | **Missing** | — | (b) Oversight; arithmetic right shift |
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

17 Core words — 14 implemented, 3 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `!` | `( x a-addr -- )` | Implemented | `memory.asm:27` | |
| `@` | `( a-addr -- x )` | Implemented | `memory.asm:13` | |
| `C!` | `( char c-addr -- )` | Implemented | `memory.asm:57` | |
| `C@` | `( c-addr -- char )` | Implemented | `memory.asm:44` | |
| `2!` | `( x1 x2 a-addr -- )` | **Missing** | — | (b) Oversight; double-cell store |
| `2@` | `( a-addr -- x1 x2 )` | **Missing** | — | (b) Oversight; double-cell fetch |
| `+!` | `( n a-addr -- )` | Implemented | `memory.asm:72` | |
| `,` | `( x -- )` | Implemented | `memory.asm:120` | |
| `C,` | `( char -- )` | Implemented | `memory.asm:138` | |
| `HERE` | `( -- addr )` | Implemented | `memory.asm:93` | |
| `ALLOT` | `( n -- )` | Implemented | `memory.asm:105` | |
| `ALIGN` | `( -- )` | Implemented | `memory.asm:154` | |
| `ALIGNED` | `( addr -- a-addr )` | Implemented | `memory.asm:171` | |
| `CELLS` | `( n1 -- n2 )` | Implemented | `memory.asm:184` | |
| `CELL+` | `( a-addr1 -- a-addr2 )` | **Missing** | — | (b) Oversight; trivial (2 +) |
| `FILL` | `( c-addr u char -- )` | Implemented | `memory.asm:195` | |
| `MOVE` | `( addr1 addr2 u -- )` | Implemented | `memory.asm:240` | |

### Character

3 Core words — 0 implemented, 3 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `CHAR` | `( "<spaces>name" -- char )` | **Missing** | — | (b) Oversight; parse word, return first char |
| `CHAR+` | `( c-addr1 -- c-addr2 )` | **Missing** | — | (a) On Z80 (1 char = 1 byte), equivalent to `1+` |
| `CHARS` | `( n1 -- n2 )` | **Missing** | — | (a) On Z80 (1 char = 1 byte), this is a no-op |

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

16 Core words — 15 implemented, 0 missing, 1 partial

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
| `EXIT` | `( -- )` | **Partial** | `inner_interpreter.asm:23` | (c) `EXIT_CODE` label exists but has no dictionary entry; cannot be called from Forth |
| `RECURSE` | `( -- )` | Implemented | `control_flow.asm:483` | IMMEDIATE flag |

### Compiler and Defining Words

14 Core words — 12 implemented, 2 missing

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `:` | `( "<spaces>name" -- )` | Implemented | `compiler.asm:289` | |
| `;` | `( -- )` | Implemented | `compiler.asm:434` | IMMEDIATE |
| `CONSTANT` | `( x "<spaces>name" -- )` | Implemented | `compiler.asm:584` | |
| `VARIABLE` | `( "<spaces>name" -- )` | Implemented | `bootstrap.asm:74` | DEFWORD |
| `CREATE` | `( "<spaces>name" -- )` | Implemented | `compiler.asm:524` | |
| `DOES>` | `( -- )` | Implemented | `compiler.asm:650` | IMMEDIATE |
| `IMMEDIATE` | `( -- )` | Implemented | `compiler.asm:269` | |
| `LITERAL` | `( x -- )` | Implemented | `compiler.asm:496` | IMMEDIATE |
| `POSTPONE` | `( "<spaces>name" -- )` | Implemented | `compiler.asm:209` | DEFIMMED |
| `[` | `( -- )` | Implemented | `compiler.asm:473` | IMMEDIATE |
| `]` | `( -- )` | Implemented | `compiler.asm:484` | |
| `STATE` | `( -- a-addr )` | Implemented | `outer_interpreter.asm:26` | |
| `[']` | `( "<spaces>name" -- xt )` | **Missing** | — | (b) Oversight; compile-time tick |
| `[CHAR]` | `( "<spaces>name" -- char )` | **Missing** | — | (b) Oversight; compile-time char |

### System and Interpreter

13 Core words — 8 implemented, 4 missing, 1 partial

| Word | Stack Effect | Status | Source | Notes |
|------|-------------|--------|--------|-------|
| `EXECUTE` | `( xt -- )` | Implemented | `inner_interpreter.asm:188` | |
| `FIND` | `( c-addr -- c-addr 0 \| xt 1 \| xt -1 )` | Implemented | `dictionary.asm:22` | Hash-table lookup |
| `ABORT` | `( -- )` | Implemented | `system.asm:112` | |
| `QUIT` | `( -- )` | Implemented | `outer_interpreter.asm:237` | |
| `>IN` | `( -- a-addr )` | Implemented | `outer_interpreter.asm:46` | |
| `BASE` | `( -- a-addr )` | Implemented | `outer_interpreter.asm:36` | |
| `SOURCE` | `( -- c-addr u )` | Implemented | `outer_interpreter.asm:66` | |
| `(` | `( "ccc)" -- )` | Implemented | `strings.asm:776` | IMMEDIATE |
| `'` | `( "<spaces>name" -- xt )` | **Missing** | — | (b) Oversight; fundamental for metaprogramming |
| `>BODY` | `( xt -- a-addr )` | **Missing** | — | (b) Oversight; introspect CREATE'd words |
| `ABORT"` | `( "ccc" x -- )` | **Missing** | — | (b) Oversight; conditional abort with message |
| `EVALUATE` | `( c-addr u -- )` | **Missing** | — | (b) Oversight; requires input source switching |
| `ENVIRONMENT?` | `( c-addr u -- false \| true )` | **Missing** | — | (a) Deliberately omitted; complex query system, rarely used |

---

## Gap Analysis

### (a) Deliberately Omitted — 3 words

These words are absent for clear platform or design reasons:

| Word | Rationale |
|------|-----------|
| `ENVIRONMENT?` | Complex metadata query system for implementation-defined limits. Rarely used by portable programs. Low value-to-effort ratio. |
| `CHAR+` | On Z80 where 1 char = 1 byte, `CHAR+` is equivalent to `1+` (which is also missing but trivial to add). |
| `CHARS` | On Z80 where 1 char = 1 byte, `CHARS` is a no-op by definition. |

### (b) Oversight — 32 words

#### Simple words (trivial to implement) — 9 words

| Word | Complexity | Notes |
|------|-----------|-------|
| `?DUP` | Trivial | Conditional duplicate; a few Z80 instructions |
| `1+` | Trivial | `INC BC` |
| `1-` | Trivial | `DEC BC` |
| `2*` | Trivial | Shift left (add BC to itself) |
| `2/` | Trivial | Arithmetic shift right |
| `CELL+` | Trivial | `2 +` on 16-bit system |
| `CHAR` | Simple | Parse next word, return first character |
| `'` | Simple | Interpret-time version of tick — parse and look up xt |
| `>BODY` | Simple | Return data-field address from xt |

#### Compile-time words — 2 words

| Word | Complexity | Notes |
|------|-----------|-------|
| `[']` | Simple | Compile-time tick; depends on `'` |
| `[CHAR]` | Simple | Compile-time char; depends on `CHAR` |

#### Error handling — 1 word

| Word | Complexity | Notes |
|------|-----------|-------|
| `ABORT"` | Moderate | Conditional abort with compiled message string |

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

### (c) Partially Implemented — 2 words

| Word | Status | Details |
|------|--------|---------|
| `EXIT` | Code exists, no dictionary entry | `EXIT_CODE` at `inner_interpreter.asm:23` implements the return-from-colon-definition logic. It is used internally by `;` and the threading model. However, it has no dictionary header, so Forth code cannot call `EXIT` by name. Adding a DEFCODE wrapper around the existing label is straightforward. |
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
- **Control flow** — Near-complete (15/16); only `EXIT` lacks a dictionary entry.
- **Compiler** — Strong coverage (12/14); only `[']` and `[CHAR]` missing.
- **Memory** — Strong coverage (14/17); only double-cell and `CELL+` missing.

### The two big gaps

1. **Double-cell operations (13 words):** antforth has no 32-bit arithmetic. This is the single largest gap and affects stack, memory, arithmetic, and mixed-precision categories. Adding the double-cell primitives (`M*`, `UM*`, `UM/MOD`, `S>D`) would unblock `FM/MOD`, `SM/REM`, `*/`, and `*/MOD` as well.

2. **Pictured numeric output (6 words):** The `<# # #S #> HOLD SIGN` subsystem is entirely absent. antforth prints numbers with `.` and `U.` directly. Adding pictured output enables user-customisable number formatting.

### Quick wins

Adding these 10 words would raise compliance from 72.2% to 79.7%:

| Word | Effort |
|------|--------|
| `EXIT` | Wrap existing `EXIT_CODE` in DEFCODE |
| `1+` | Single `INC BC` |
| `1-` | Single `DEC BC` |
| `2*` | `SLA C / RL B` or `ADD HL,HL` pattern |
| `2/` | `SRA B / RR C` |
| `CELL+` | DEFWORD: `2 +` |
| `?DUP` | Test BC, conditionally push |
| `CHAR` | Parse word, load first byte |
| `'` | Parse word, call FIND, validate |
| `>BODY` | Compute data field offset from xt |
