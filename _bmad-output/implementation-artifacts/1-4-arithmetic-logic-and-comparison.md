# Story 1.4: Arithmetic, Logic & Comparison

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want all arithmetic, logic, and comparison CODE primitives,
so that I can perform calculations in threaded code and verify correctness.

## Acceptance Criteria

1. **Given** a hardcoded thread exercising arithmetic **When** `+` executes with 3 and 4 on stack **Then** the result is 7 **When** `-` executes with 10 and 3 on stack **Then** the result is 7 **When** `*` executes with 6 and 7 on stack **Then** the result is 42 **When** `/` executes with 42 and 6 on stack **Then** the result is 7 **When** `MOD` executes with 10 and 3 on stack **Then** the result is 1 **When** `/MOD` executes with 10 and 3 on stack **Then** the stack contains quotient 3 and remainder 1 **And** all arithmetic handles signed two's complement correctly including edge cases (division by zero behaviour, MIN_INT)

2. **Given** a hardcoded thread exercising logic **When** `AND` executes with 0xFF00 and 0x0FF0 **Then** the result is 0x0F00 **When** `OR` executes with 0xFF00 and 0x00FF **Then** the result is 0xFFFF **When** `XOR` executes with 0xFFFF and 0xFF00 **Then** the result is 0x00FF **When** `INVERT` executes with 0xFF00 **Then** the result is 0x00FF **When** `LSHIFT` shifts 1 left by 8 **Then** the result is 256 **When** `RSHIFT` shifts 256 right by 8 **Then** the result is 1

3. **Given** a hardcoded thread exercising comparisons **When** `=` compares 5 and 5 **Then** the result is -1 (TRUE) **When** `<` compares 3 and 5 (signed) **Then** the result is -1 (TRUE) **When** `>` compares 5 and 3 **Then** the result is -1 (TRUE) **When** `0=` tests 0 **Then** the result is -1 (TRUE); testing non-zero gives 0 (FALSE) **When** `0<` tests -1 **Then** the result is -1 (TRUE); testing 1 gives 0 (FALSE) **When** `U<` compares 1 and 0xFFFF (unsigned) **Then** the result is -1 (TRUE)

## Tasks / Subtasks

- [x] Task 1: Implement arithmetic primitives in `src/arithmetic.asm` (AC: #1)
  - [x] 1.1 + ( n1 n2 -- n3 ) — add
  - [x] 1.2 - ( n1 n2 -- n3 ) — subtract
  - [x] 1.3 * ( n1 n2 -- n3 ) — multiply (16-bit signed)
  - [x] 1.4 / ( n1 n2 -- n3 ) — divide (signed, floored or symmetric — see dev notes)
  - [x] 1.5 MOD ( n1 n2 -- n3 ) — modulus
  - [x] 1.6 /MOD ( n1 n2 -- rem quot ) — divide with remainder
- [x] Task 2: Implement logic primitives in `src/logic.asm` (AC: #2)
  - [x] 2.1 AND ( x1 x2 -- x3 )
  - [x] 2.2 OR ( x1 x2 -- x3 )
  - [x] 2.3 XOR ( x1 x2 -- x3 )
  - [x] 2.4 INVERT ( x1 -- x2 )
  - [x] 2.5 LSHIFT ( x1 u -- x2 ) — logical left shift
  - [x] 2.6 RSHIFT ( x1 u -- x2 ) — logical right shift
- [x] Task 3: Implement comparison primitives in `src/logic.asm` (AC: #3)
  - [x] 3.1 = ( x1 x2 -- flag )
  - [x] 3.2 < ( n1 n2 -- flag ) — signed less-than
  - [x] 3.3 > ( n1 n2 -- flag ) — signed greater-than
  - [x] 3.4 0= ( x -- flag ) — equals zero
  - [x] 3.5 0< ( n -- flag ) — less than zero (negative)
  - [x] 3.6 U< ( u1 u2 -- flag ) — unsigned less-than
- [x] Task 4: Create test threads and verify all primitives (AC: #1-3)
  - [x] 4.1 Add test threads for +, -, *, /, MOD, /MOD
  - [x] 4.2 Add test threads for AND, OR, XOR, INVERT, LSHIFT, RSHIFT
  - [x] 4.3 Add test threads for =, <, >, 0=, 0<, U<
  - [x] 4.4 Update Makefile expected test output
  - [x] 4.5 Verify all tests pass under iz-cpm

## Dev Notes

### What Already Exists (from Stories 1.1-1.3)

The following are implemented and **must not be modified** unless there's a bug:

- **Inner interpreter** (`inner_interpreter.asm`): DOCOL, EXIT_CODE, LIT, BRANCH, ?BRANCH, EXECUTE
- **Stack primitives** (`stack_ops.asm`): DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH, SP@, SP!, RP@, RP!, >R, R>, R@
- **Memory primitives** (`memory.asm`): @, !, C@, C!, +!, HERE, ALLOT, COMMA, C,, ALIGN, ALIGNED, FILL, MOVE
- **I/O** (`io.asm`): EMIT (console output via BDOS C_WRITE)
- **System** (`system.asm`): BYE (clean exit to CP/M)
- **Macros** (`macros.asm`): NEXT, NEXTHL, DEFCODE, DEFWORD, DEFIMMED, BDOS_SAVE, BDOS_RESTORE
- **Cold start** (`antforth.asm:18-72`): SP, IX, IY, user variables, sp_base, hash table
- **Constants** (`constants.asm`): PS_SIZE=256, RS_SIZE=256, HASH_BUCKETS=64, F_IMMEDIATE=0x80, F_SMUDGE=0x40, F_LENMASK=0x1F, BDOS_ENTRY=0x0005, C_WRITE=2, P_TERMCPM=0
- **Structures** (`structures.asm`): UserArea, DictEntry

**Current test thread** (`antforth.asm:104-338`): Outputs "ABCDEFGHIJKLMNOPQRSTUVWXYZ" testing all primitives from stories 1.1-1.3. The thread ends with EXECUTE of BYE. **Extend by inserting new tests before the final EXECUTE(BYE)**, continuing the alphabetic pattern or switching to a numeric/symbol scheme.

**Current expected output**: "ABCDEFGHIJKLMNOPQRSTUVWXYZ" (Makefile line 48).

### Register Contract (Inviolable)

| Register | Role | CODE word rules |
|----------|------|----------------|
| BC | TOS | Contains TOS on entry; must contain new TOS on exit |
| DE | IP | Must be preserved — never use as scratch without save/restore |
| SP | Parameter stack | Net effect must match word's stack signature |
| IX | Return stack pointer | Preserve unless doing return stack operations |
| IY | User pointer | Preserve unless accessing user variables |
| HL | W (scratch) | Free within CODE words |
| AF | Scratch | Free within CODE words |

**Anti-pattern**: Any CODE word that modifies DE, IX, or IY without saving/restoring (unless that's the word's defined purpose).

### Implementation Guide — Arithmetic Primitives

All arithmetic words go in `src/arithmetic.asm`. Replace the stub file. Add the mandatory file header.

**+ (PLUS)** — simplest: pop second from stack, add to TOS.

```z80
; -----------------------------------------------
; + ( n1 n2 -- n3 )
;   Add top two stack items
; -----------------------------------------------
w_PLUS:
    DEFCODE "+", 0
w_PLUS_cf:
    POP     HL              ; HL = n1
    ADD     HL, BC          ; HL = n1 + n2
    LD      B, H
    LD      C, L            ; BC = result
    NEXT
```

**- (MINUS)** — n1 - n2, where BC=n2(TOS), (SP)=n1.

```z80
; -----------------------------------------------
; - ( n1 n2 -- n3 )
;   Subtract n2 from n1
; -----------------------------------------------
w_MINUS:
    DEFCODE "-", 0
w_MINUS_cf:
    POP     HL              ; HL = n1
    OR      A               ; Clear carry
    SBC     HL, BC          ; HL = n1 - n2
    LD      B, H
    LD      C, L            ; BC = result
    NEXT
```

**\* (STAR)** — 16-bit signed multiply. Z80 has no MUL instruction. Use shift-and-add algorithm. Architecture says this "should be CODE" for performance.

```z80
; -----------------------------------------------
; * ( n1 n2 -- n3 )
;   Multiply (16-bit, low 16 bits of result)
; -----------------------------------------------
w_STAR:
    DEFCODE "*", 0
w_STAR_cf:
    POP     HL              ; HL = n1 (multiplicand)
    ; Multiply HL * BC, result in HL (low 16 bits)
    ; Use shift-and-add: iterate over bits of BC
    PUSH    DE              ; Save IP
    LD      D, H
    LD      E, L            ; DE = n1 (multiplicand)
    LD      HL, 0           ; HL = accumulator (result)
    LD      A, 16           ; 16-bit iteration
.mul_loop:
    ADD     HL, HL          ; Shift result left
    RL      B               ; Shift multiplier left through carry
    RL      C               ; (MSB of BC into carry)
    ; Wait — we want to shift BC left and test the bit that falls out.
    ; Actually, we want to test each bit of BC from MSB to LSB.
    ; Standard approach: shift BC left, if carry set, add multiplicand.
    ; But RL shifts through carry: bit 7 → carry, carry → bit 0.
    ; For clean MSB-to-LSB traversal: SLA C / RL B (shift left arithmetic)
```

**Correction — clean 16-bit multiply:**

The standard approach for 16-bit multiply on Z80 (shift-and-add, MSB first):

```z80
w_STAR:
    DEFCODE "*", 0
w_STAR_cf:
    POP     HL              ; HL = n1
    PUSH    DE              ; Save IP!
    EX      DE, HL          ; DE = n1 (multiplicand)
    LD      HL, 0           ; HL = accumulator
    LD      A, 16           ; bit counter
.mul_loop:
    ADD     HL, HL          ; shift accumulator left
    SLA     C               ; shift multiplier (BC) left
    RL      B               ; MSB falls into carry
    JR      NC, .mul_skip
    ADD     HL, DE          ; add multiplicand if bit was set
.mul_skip:
    DEC     A
    JR      NZ, .mul_loop
    LD      B, H
    LD      C, L            ; BC = result (low 16 bits)
    POP     DE              ; Restore IP
    NEXT
```

**Critical**: `*` uses DE as scratch (multiplicand), so **IP must be saved/restored**. Use `PUSH DE` / `POP DE` on the parameter stack. This is safe because SP doesn't need to be clean during the multiply — we won't do any Forth stack operations.

**/ and MOD and /MOD** — 16-bit signed division. Z80 has no DIV instruction. Implement a single `divmod` helper that both `/`, `MOD`, and `/MOD` call. Use unsigned division on absolute values, then fix signs.

Division semantics: ANS Forth specifies **symmetric division** for `/` and `MOD` (truncation toward zero). This means:
- `7 / 2` = 3, `7 MOD 2` = 1
- `-7 / 2` = -3, `-7 MOD 2` = -1
- `7 / -2` = -3, `7 MOD -2` = 1

The internal `udivmod` routine does unsigned 16-bit division (dividend / divisor → quotient, remainder). The signed wrappers negate operands as needed.

```z80
; -----------------------------------------------
; Internal: udivmod ( -- )
;   Unsigned 16-bit division: HL / BC → HL=quotient, DE=remainder
;   (DE is clobbered — caller must save IP before calling)
;   Uses A as bit counter
; -----------------------------------------------
udivmod:
    ; HL = dividend, BC = divisor
    ; Result: HL = quotient, A:DE or similar = remainder
    ; Standard Z80 restoring division:
    LD      DE, 0           ; DE = remainder
    LD      A, 16           ; 16 bits
.udiv_loop:
    ADD     HL, HL          ; Shift dividend left (MSB into carry)
    RL      E               ; Shift carry into remainder
    RL      D
    EX      DE, HL          ; HL = remainder, DE = partial quotient
    SBC     HL, BC          ; Try subtract divisor (carry clear from RL)
    JR      NC, .udiv_1     ; Subtraction succeeded
    ADD     HL, BC          ; Restore remainder
    EX      DE, HL          ; DE = remainder, HL = partial quotient
    JR      .udiv_next
.udiv_1:
    EX      DE, HL          ; DE = remainder, HL = partial quotient
    SET     0, L            ; Set quotient bit
.udiv_next:
    DEC     A
    JR      NZ, .udiv_loop
    ; HL = quotient, DE = remainder
    RET
```

**Note on SBC after RL**: The RL instruction does NOT affect the carry flag in the way SUB/SBC expects. After `RL D`, carry reflects the MSB of the old D. You may need `OR A` (clear carry) or `AND A` before the SBC. **The dev agent must verify carry flag state carefully.** An alternative is to use `SUB`/`SBC` pair (SBC HL,BC with carry cleared by `OR A` first):

```z80
    OR      A               ; Clear carry before SBC
    SBC     HL, BC          ; remainder -= divisor
```

**/MOD** builds on `udivmod`:

```z80
; -----------------------------------------------
; /MOD ( n1 n2 -- rem quot )
;   Signed symmetric division with remainder
; -----------------------------------------------
w_SLASH_MOD:
    DEFCODE "/MOD", 0
w_SLASH_MOD_cf:
    ; BC = n2 (divisor, TOS), (SP) = n1 (dividend)
    POP     HL              ; HL = n1
    PUSH    DE              ; Save IP
    ; Determine signs, work with absolute values
    ; ... (sign handling, call udivmod, fix signs)
    ; BC = quotient (TOS), push remainder below
    POP     DE              ; Restore IP
    NEXT
```

**/ (SLASH)** — calls /MOD logic, drops remainder:

```z80
; -----------------------------------------------
; / ( n1 n2 -- quot )
;   Signed symmetric division
; -----------------------------------------------
w_SLASH:
    DEFCODE "/", 0
w_SLASH_cf:
    ; Same as /MOD but only keep quotient in BC
    NEXT
```

**MOD** — calls /MOD logic, drops quotient:

```z80
; -----------------------------------------------
; MOD ( n1 n2 -- rem )
;   Signed symmetric modulus
; -----------------------------------------------
w_MOD:
    DEFCODE "MOD", 0
w_MOD_cf:
    ; Same as /MOD but only keep remainder in BC
    NEXT
```

**Recommended approach for division**: Implement a single internal routine `sdivmod` that takes HL=dividend, BC=divisor (both signed), saves/restores IP via `PUSH DE`/`POP DE`, and returns quotient in HL and remainder in DE (or similar). Then `/MOD` pushes remainder, sets BC=quotient. `/` just sets BC=quotient. `MOD` just sets BC=remainder. This avoids code duplication.

**Division by zero**: ANS Forth says the result is undefined. On Z80, the division loop will just produce 0xFFFF or similar garbage. No need to check — but if you want to be safe, you can check `BC=0` and skip to push 0/0. The architecture says crash-proof is important (NFR5), but division by zero during interactive use won't happen until the outer interpreter exists (Epic 2). For now, undefined behaviour on div-by-zero is acceptable.

### Implementation Guide — Logic Primitives

Logic and comparison words go in `src/logic.asm`. Replace the stub file.

**AND, OR, XOR** — straightforward 16-bit bitwise operations:

```z80
; -----------------------------------------------
; AND ( x1 x2 -- x3 )
;   Bitwise AND
; -----------------------------------------------
w_AND:
    DEFCODE "AND", 0
w_AND_cf:
    POP     HL              ; HL = x1
    LD      A, H
    AND     B
    LD      B, A            ; High byte AND
    LD      A, L
    AND     C
    LD      C, A            ; Low byte AND
    NEXT

; -----------------------------------------------
; OR ( x1 x2 -- x3 )
;   Bitwise OR
; -----------------------------------------------
w_OR:
    DEFCODE "OR", 0
w_OR_cf:
    POP     HL
    LD      A, H
    OR      B
    LD      B, A
    LD      A, L
    OR      C
    LD      C, A
    NEXT

; -----------------------------------------------
; XOR ( x1 x2 -- x3 )
;   Bitwise XOR
; -----------------------------------------------
w_XOR:
    DEFCODE "XOR", 0
w_XOR_cf:
    POP     HL
    LD      A, H
    XOR     B
    LD      B, A
    LD      A, L
    XOR     C
    LD      C, A
    NEXT
```

**INVERT** — one's complement of TOS:

```z80
; -----------------------------------------------
; INVERT ( x1 -- x2 )
;   Bitwise complement (one's complement)
; -----------------------------------------------
w_INVERT:
    DEFCODE "INVERT", 0
w_INVERT_cf:
    LD      A, B
    CPL
    LD      B, A
    LD      A, C
    CPL
    LD      C, A
    NEXT
```

**LSHIFT and RSHIFT** — shift x1 left/right by u positions. Z80 has no barrel shifter, so use a loop.

```z80
; -----------------------------------------------
; LSHIFT ( x1 u -- x2 )
;   Logical shift left by u bits
; -----------------------------------------------
w_LSHIFT:
    DEFCODE "LSHIFT", 0
w_LSHIFT_cf:
    ; BC = u (shift count), (SP) = x1
    LD      A, C            ; A = shift count (only low byte matters, max useful = 16)
    POP     HL              ; HL = x1
    OR      A
    JR      Z, .lshift_done
.lshift_loop:
    ADD     HL, HL          ; Shift HL left by 1 (same as SLA L / RL H)
    DEC     A
    JR      NZ, .lshift_loop
.lshift_done:
    LD      B, H
    LD      C, L
    NEXT

; -----------------------------------------------
; RSHIFT ( x1 u -- x2 )
;   Logical shift right by u bits
; -----------------------------------------------
w_RSHIFT:
    DEFCODE "RSHIFT", 0
w_RSHIFT_cf:
    LD      A, C            ; A = shift count
    POP     HL              ; HL = x1
    OR      A
    JR      Z, .rshift_done
.rshift_loop:
    SRL     H               ; Shift H right, bit 0 → carry
    RR      L               ; Rotate carry into L bit 7
    DEC     A
    JR      NZ, .rshift_loop
.rshift_done:
    LD      B, H
    LD      C, L
    NEXT
```

### Implementation Guide — Comparison Primitives

**Flag values**: TRUE = -1 (0xFFFF), FALSE = 0 (0x0000) per ANS standard.

A common helper pattern for setting BC to flag:
```z80
; Set BC = TRUE (-1)
    LD      BC, 0xFFFF
; Set BC = FALSE (0)
    LD      BC, 0
```

**= (EQUALS)** — compare two values:

```z80
; -----------------------------------------------
; = ( x1 x2 -- flag )
;   TRUE if x1 equals x2
; -----------------------------------------------
w_EQUALS:
    DEFCODE "=", 0
w_EQUALS_cf:
    POP     HL              ; HL = x1
    OR      A               ; Clear carry
    SBC     HL, BC          ; HL = x1 - x2
    LD      BC, 0           ; Assume FALSE
    LD      A, H
    OR      L
    JR      NZ, .eq_done    ; Not equal
    DEC     BC              ; BC = 0xFFFF = TRUE
.eq_done:
    NEXT
```

**< (LESS)** — signed comparison. On Z80, signed comparison uses the overflow flag. After `SBC HL, BC`: if sign flag XOR overflow flag = 1, then HL < BC (i.e., n1 < n2).

```z80
; -----------------------------------------------
; < ( n1 n2 -- flag )
;   TRUE if n1 < n2 (signed)
; -----------------------------------------------
w_LESS:
    DEFCODE "<", 0
w_LESS_cf:
    POP     HL              ; HL = n1
    OR      A
    SBC     HL, BC          ; HL = n1 - n2, sets S and V flags
    ; Signed less: S XOR V = 1
    LD      BC, 0           ; Assume FALSE
    JP      PO, .less_no_ov ; P/V = 0 (no overflow): check sign only
    ; Overflow set: result is opposite of sign
    JP      M, .less_done   ; S=1, V=1: NOT less (S XOR V = 0)
    DEC     BC              ; S=0, V=1: less (S XOR V = 1)
    JR      .less_done
.less_no_ov:
    JP      P, .less_done   ; S=0, V=0: NOT less
    DEC     BC              ; S=1, V=0: less (S XOR V = 1)
.less_done:
    NEXT
```

**> (GREATER)** — can be implemented as swap-then-less, or directly. For a CODE word, implement directly for efficiency. Alternatively, swap the operands: n1 > n2 is the same as n2 < n1. Since BC=n2 and (SP)=n1, just swap which is which in the subtraction:

```z80
; -----------------------------------------------
; > ( n1 n2 -- flag )
;   TRUE if n1 > n2 (signed)
; -----------------------------------------------
w_GREATER:
    DEFCODE ">", 0
w_GREATER_cf:
    POP     HL              ; HL = n1
    ; We want n1 > n2, same as n2 < n1
    ; So compute n2 - n1 and check S XOR V
    PUSH    HL              ; Save n1
    LD      H, B
    LD      L, C            ; HL = n2
    POP     BC              ; BC = n1
    OR      A
    SBC     HL, BC          ; HL = n2 - n1
    LD      BC, 0
    JP      PO, .gt_no_ov
    JP      M, .gt_done
    DEC     BC
    JR      .gt_done
.gt_no_ov:
    JP      P, .gt_done
    DEC     BC
.gt_done:
    NEXT
```

**0= (ZERO_EQUALS)** — unary, only consumes TOS:

```z80
; -----------------------------------------------
; 0= ( x -- flag )
;   TRUE if x is zero
; -----------------------------------------------
w_ZERO_EQUALS:
    DEFCODE "0=", 0
w_ZERO_EQUALS_cf:
    LD      A, B
    OR      C               ; Z flag set if BC = 0
    LD      BC, 0
    JR      NZ, .zeq_done
    DEC     BC              ; BC = TRUE
.zeq_done:
    NEXT
```

**0< (ZERO_LESS)** — TRUE if n is negative (bit 15 set):

```z80
; -----------------------------------------------
; 0< ( n -- flag )
;   TRUE if n is negative
; -----------------------------------------------
w_ZERO_LESS:
    DEFCODE "0<", 0
w_ZERO_LESS_cf:
    LD      BC, 0
    BIT     7, B            ; Wait — B was clobbered. Need to test BEFORE resetting BC.
    ; Correction: test B bit 7 first, then set BC
```

**Corrected 0<:**

```z80
w_ZERO_LESS:
    DEFCODE "0<", 0
w_ZERO_LESS_cf:
    LD      A, B            ; Save high byte
    LD      BC, 0           ; Assume FALSE
    BIT     7, A            ; Test sign bit
    JR      Z, .zlt_done    ; Not negative
    DEC     BC              ; BC = TRUE (0xFFFF)
.zlt_done:
    NEXT
```

Or more compactly using `RLA`:

```z80
w_ZERO_LESS_cf:
    LD      A, B            ; A = high byte of n
    LD      BC, 0
    RLA                     ; Bit 7 → carry
    JR      NC, .zlt_done
    DEC     BC
.zlt_done:
    NEXT
```

**U< (UNSIGNED_LESS)** — unsigned comparison, simpler than signed:

```z80
; -----------------------------------------------
; U< ( u1 u2 -- flag )
;   TRUE if u1 < u2 (unsigned)
; -----------------------------------------------
w_U_LESS:
    DEFCODE "U<", 0
w_U_LESS_cf:
    POP     HL              ; HL = u1
    OR      A               ; Clear carry
    SBC     HL, BC          ; HL = u1 - u2 (unsigned subtraction)
    LD      BC, 0
    JR      NC, .ult_done   ; No borrow: u1 >= u2
    DEC     BC              ; Borrow: u1 < u2, BC = TRUE
.ult_done:
    NEXT
```

### Naming Convention Reminders

- Word labels: `w_PLUS`, `w_MINUS`, `w_STAR`, `w_SLASH`, `w_MOD`, `w_SLASH_MOD`, `w_AND`, `w_OR`, `w_XOR`, `w_INVERT`, `w_LSHIFT`, `w_RSHIFT`, `w_EQUALS`, `w_LESS`, `w_GREATER`, `w_ZERO_EQUALS`, `w_ZERO_LESS`, `w_U_LESS`
- Code field labels: append `_cf` to each (e.g., `w_PLUS_cf`, `w_MINUS_cf`)
- File header comment blocks are mandatory per architecture spec
- Every word must have stack effect comment and description

### Testing Strategy

Continue the test thread approach from Story 1.3. The current output is "ABCDEFGHIJKLMNOPQRSTUVWXYZ" (26 chars). New tests should be appended before the final `EXECUTE(BYE)`.

**Test encoding scheme**: Since we've exhausted A-Z, use lowercase letters starting from 'a', or digits, or compute results and compare with ?BRANCH. Recommended: use digits '0'-'9' and then lowercase 'a'-'z' for up to 36 more test characters.

**Suggested test sequence** (appended after the 'Z' test, before the EXECUTE/BYE block):

Each test computes a result and uses ?BRANCH to either emit a pass character or '!' (fail).

- **'0'**: + test — LIT 3, LIT 4, +, LIT 7, =, ?BRANCH to fail, LIT '0', EMIT
- **'1'**: - test — LIT 10, LIT 3, -, LIT 7, =, ?BRANCH, LIT '1', EMIT
- **'2'**: * test — LIT 6, LIT 7, *, LIT 42, =, ?BRANCH, LIT '2', EMIT
- **'3'**: / test — LIT 42, LIT 6, /, LIT 7, =, ?BRANCH, LIT '3', EMIT
- **'4'**: MOD test — LIT 10, LIT 3, MOD, LIT 1, =, ?BRANCH, LIT '4', EMIT
- **'5'**: /MOD test — LIT 10, LIT 3, /MOD, LIT 3, =, ?BRANCH to fail (check quot), then check rem: SWAP, LIT 1, =, ?BRANCH, LIT '5', EMIT
- **'6'**: AND test — LIT 0xFF00, LIT 0x0FF0, AND, LIT 0x0F00, =, ?BRANCH, LIT '6', EMIT
- **'7'**: OR test — LIT 0xFF00, LIT 0x00FF, OR, LIT 0xFFFF, =, ?BRANCH, LIT '7', EMIT
- **'8'**: XOR test — LIT 0xFFFF, LIT 0xFF00, XOR, LIT 0x00FF, =, ?BRANCH, LIT '8', EMIT
- **'9'**: INVERT test — LIT 0xFF00, INVERT, LIT 0x00FF, =, ?BRANCH, LIT '9', EMIT
- **'a'**: LSHIFT test — LIT 1, LIT 8, LSHIFT, LIT 256, =, ?BRANCH, LIT 'a', EMIT
- **'b'**: RSHIFT test — LIT 256, LIT 8, RSHIFT, LIT 1, =, ?BRANCH, LIT 'b', EMIT
- **'c'**: = test (true case) — LIT 5, LIT 5, =, 0= (should be FALSE since = returns TRUE), 0=, ?BRANCH... Actually simpler: LIT 5, LIT 5, =, ?BRANCH(skip_if_false), LIT 'c', EMIT, BRANCH(end)
  - When `=` returns TRUE (-1), ?BRANCH falls through (non-zero). Emit 'c'.
- **'d'**: < test — LIT 3, LIT 5, <, ?BRANCH, LIT 'd', EMIT
- **'e'**: > test — LIT 5, LIT 3, >, ?BRANCH, LIT 'e', EMIT
- **'f'**: 0= test — LIT 0, 0=, ?BRANCH, LIT 'f', EMIT
- **'g'**: 0< test — LIT -1, 0<, ?BRANCH, LIT 'g', EMIT  (use LIT 0xFFFF for -1)
- **'h'**: U< test — LIT 1, LIT 0xFFFF, U<, ?BRANCH, LIT 'h', EMIT

**Updated expected output**: `"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefgh"`

**Test pattern for self-verifying tests using ?BRANCH:**

```z80
        ; Test '0': + — 3 + 4 = 7
        DW      w_LIT_cf, 3
        DW      w_LIT_cf, 4
        DW      w_PLUS_cf           ; Stack: 7
        DW      w_LIT_cf, 7
        DW      w_EQUALS_cf         ; Stack: TRUE (-1)
        DW      w_QBRANCH_cf        ; If FALSE (0), branch to fail
.t0_off:
        DW      .t0_fail - .t0_off
        DW      w_LIT_cf, '0'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t0_jmp:
        DW      .t0_end - .t0_jmp
.t0_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t0_end:
```

This pattern requires `=` to work before it can be used in tests for other words. **Implement and test `=` first**, or use a simpler approach for early arithmetic tests: compute a value that maps directly to an ASCII char and EMIT it.

**Alternative simpler test approach** (no dependency on `=`):

```z80
        ; Test '0': + — 3 + 4 = 7, and 7 + 41 = 48 = '0'
        DW      w_LIT_cf, 3
        DW      w_LIT_cf, 4
        DW      w_PLUS_cf           ; Stack: 7
        DW      w_LIT_cf, 41
        DW      w_PLUS_cf           ; Stack: 48 = '0'
        DW      w_EMIT_cf
```

**Choose whichever approach you prefer.** The ?BRANCH approach is more rigorous. The direct-emit approach is simpler but less robust (could emit wrong char without detection).

### Division Sign Handling

For signed `/MOD`: work with absolute values, then fix signs for symmetric (truncation toward zero) semantics:

1. Record signs of dividend and divisor
2. Negate operands to positive if negative
3. Call unsigned `udivmod`
4. If dividend was negative: negate remainder
5. If signs differ (one neg, one pos): negate quotient

Use a flag byte to track original signs. Example:

```z80
    ; HL = dividend, BC = divisor
    LD      A, 0            ; sign flag
    BIT     7, H            ; Test dividend sign
    JR      Z, .div_pos1
    XOR     1               ; Mark dividend negative
    ; Negate HL: HL = 0 - HL
    PUSH    BC
    LD      BC, 0
    OR      A
    SBC     HL, BC          ; Hmm, wrong order
    ; Use: LD DE,HL / LD HL,0 / SBC HL,DE
    ; Or: XOR A / SUB L / LD L,A / SBC A,A / SUB H / LD H,A
    POP     BC
.div_pos1:
    BIT     7, B            ; Test divisor sign
    JR      Z, .div_pos2
    XOR     1               ; Toggle sign flag
    ; Negate BC
    LD      D, A            ; Save sign flag
    LD      A, 0
    SUB     C
    LD      C, A
    SBC     A, A
    SUB     B
    LD      B, A
    LD      A, D            ; Restore sign flag
.div_pos2:
    ; A = sign flag (bit 0 set if quotient should be negated)
    ; HL and BC are now positive
    PUSH    AF              ; Save sign info
    CALL    udivmod         ; HL = quotient, DE = remainder
    POP     AF
    ; ... fix signs based on A
```

**The dev agent should implement this carefully.** The 16-bit negate pattern for HL on Z80 (without clobbering other registers) is:

```z80
    ; Negate HL (HL = 0 - HL)
    XOR     A
    SUB     L
    LD      L, A
    SBC     A, A
    SUB     H
    LD      H, A
```

And for BC:

```z80
    ; Negate BC (BC = 0 - BC)
    XOR     A
    SUB     C
    LD      C, A
    SBC     A, A
    SUB     B
    LD      B, A
```

### Project Structure Notes

- **`src/arithmetic.asm`**: Replace stub — all arithmetic primitives (+, -, *, /, MOD, /MOD) plus internal `udivmod` helper
- **`src/logic.asm`**: Replace stub — all logic (AND, OR, XOR, INVERT, LSHIFT, RSHIFT) and comparison (=, <, >, 0=, 0<, U<) primitives
- **`src/antforth.asm`**: Extended test thread with new tests after 'Z', before EXECUTE(BYE)
- **`Makefile`**: Updated expected test output
- No new source files needed

### Previous Story Intelligence

**From Story 1.3 (Stack & Memory Primitives):**

- **Label convention confirmed**: `w_NAME:` before DEFCODE, `w_NAME_cf:` after code field entry
- **DE (IP) saving**: When a CODE word needs DE as scratch (like ROLL, FILL, MOVE in Story 1.3), save IP to the return stack via `DEC IX; DEC IX; LD (IX+0),E; LD (IX+1),D` and restore after. For `*`, using `PUSH DE` / `POP DE` on the parameter stack is also acceptable since the stack state is known
- **iz-cpm test pattern**: Test threads output known characters, `make test` checks expected string. Current output: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
- **FILL initially clobbered DE (IP)** — this was a bug found during 1.3 dev. Multiply (*) will have the same risk since it uses a loop with DE as multiplicand. Save IP first
- **sjasmplus quirks**: `sj.insert_label`, `#name` for string length in LUA, `--raw` flag. Local labels use `.name` prefix within DEFCODE blocks
- **Code review lesson**: Story 1.3 was initially missing 10 test threads. Ensure every primitive has a test

### Git Intelligence

**Recent commits (most recent first):**
1. `155855b` — implemented story 1.3 - stack and memory ops
2. `7891f46` — implement inner interpreter and threading (story 1-2)
3. `55e9474` — add NEXTHL optimisation
4. `67b7527` — initial project scaffolding

**Patterns to follow:**
- Commit messages are descriptive, reference story number
- Each story produces a working, testable binary
- Code review fixes included in same commit

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.4] — acceptance criteria, BDD specifications
- [Source: _bmad-output/planning-artifacts/architecture.md#Register Usage Discipline] — register contract
- [Source: _bmad-output/planning-artifacts/architecture.md#Kernel/Forth Boundary] — +, -, AND, OR, XOR, INVERT, LSHIFT, RSHIFT as "must be CODE"; *, /, MOD, /MOD as "should be CODE"
- [Source: _bmad-output/planning-artifacts/architecture.md#Naming Patterns] — w_PLUS, w_MINUS, w_STAR, w_SLASH, w_EQUALS, etc.
- [Source: _bmad-output/planning-artifacts/architecture.md#Comment Conventions] — mandatory stack effect + description
- [Source: _bmad-output/planning-artifacts/architecture.md#Number Representation] — 16-bit, two's complement, TRUE=-1, FALSE=0
- [Source: _bmad-output/implementation-artifacts/1-3-stack-and-memory-primitives.md] — previous story learnings, DE saving patterns, test thread conventions

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented 6 arithmetic primitives in `src/arithmetic.asm`: +, -, *, /, MOD, /MOD
- Implemented internal `udivmod` (unsigned 16-bit division) and `sdivmod` (signed symmetric division) helper routines
- `*` uses shift-and-add algorithm with DE (IP) saved/restored via PUSH/POP
- Division uses symmetric (truncate toward zero) semantics per ANS Forth
- Implemented 6 logic primitives in `src/logic.asm`: AND, OR, XOR, INVERT, LSHIFT, RSHIFT
- Implemented 6 comparison primitives in `src/logic.asm`: =, <, >, 0=, 0<, U<
- Signed comparison (<, >) uses Sign XOR Overflow flag technique
- Flag values: TRUE = -1 (0xFFFF), FALSE = 0 (0x0000) per ANS standard
- Added 18 self-verifying test threads using ?BRANCH pattern (tests '0'-'9', 'a'-'h')
- Test '5' (/MOD) verifies both quotient and remainder using AND to combine two flag checks
- Updated Makefile expected output to "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefgh"
- All 44 test characters pass, zero regressions
- [Code Review] Added 10 additional test threads ('i'-'r') covering FALSE-case comparisons, signed division, and signed overflow edge cases
- [Code Review] Optimised `>` (GREATER) operand swap from PUSH/POP to register moves (29→24 T-states)
- [Code Review] Fixed stale test thread header comment to reflect Stories 1.2-1.4 scope
- [Code Review] Added division-by-zero precondition comment to udivmod
- [Code Review] Updated Makefile expected output to 54 characters
- All 54 test characters pass, zero regressions

### File List

- `src/arithmetic.asm` — replaced stub with +, -, *, /, MOD, /MOD, udivmod, sdivmod; added div-by-zero comment
- `src/logic.asm` — replaced stub with AND, OR, XOR, INVERT, LSHIFT, RSHIFT, =, <, >, 0=, 0<, U<; optimised `>` swap
- `src/antforth.asm` — added 28 test threads for story 1.4 primitives (18 original + 10 review additions)
- `Makefile` — updated expected test output string (54 chars)

## Change Log

- 2026-04-03: Implemented all 18 arithmetic, logic, and comparison primitives with self-verifying test threads. All tests pass (44 chars output).
- 2026-04-03: Code review fixes — added 10 FALSE-case/edge-case/signed-division tests, optimised `>`, fixed stale comments. All 54 tests pass.
