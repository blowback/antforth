# Story 3.4: Counted Loops & RECURSE

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want counted loops (DO/LOOP/+LOOP/LEAVE/I/J) and recursion (RECURSE) in my definitions,
so that I can iterate over ranges and write recursive algorithms.

## Acceptance Criteria

1. **Given** a definition using DO/LOOP: `: TENS 10 0 DO I . LOOP ;` **When** `TENS` is executed **Then** `0 1 2 3 4 5 6 7 8 9` is printed

2. **Given** a definition using +LOOP: `: EVENS 10 0 DO I . 2 +LOOP ;` **When** `EVENS` is executed **Then** `0 2 4 6 8` is printed

3. **Given** a definition using LEAVE: `: FIND5 10 0 DO I 5 = IF I . LEAVE THEN LOOP ;` **When** `FIND5` is executed **Then** `5` is printed and the loop exits early (no subsequent iterations run)

4. **Given** a definition using I (inner loop index) **When** the loop body executes **Then** I pushes the current loop index to the parameter stack

5. **Given** nested DO/LOOPs using I and J: `: NEST 3 0 DO 3 0 DO J . I . LOOP LOOP ;` **When** executed **Then** each inner iteration prints the outer index (J) then the inner index (I)

6. **Given** a definition using RECURSE: `: FACTORIAL DUP 1 > IF DUP 1 - RECURSE * THEN ;` **When** `5 FACTORIAL .` is executed **Then** `120` is printed

7. **Given** DO, LOOP, +LOOP, LEAVE are IMMEDIATE words **When** used outside of a colon definition (in interpret mode) **Then** a compile-only error is reported (`? compile only`)

8. **Given** RECURSE is an IMMEDIATE word **When** used outside of a colon definition **Then** a compile-only error is reported

## Tasks / Subtasks

- [x] Task 1: Implement runtime primitive `(DO)` as a DEFCODE word in `src/control_flow.asm` (AC: #1)
  - [x] 1.1 Stack effect: `( limit start -- ) ( R: -- limit start )`
  - [x] 1.2 Pop limit from data stack (start is in BC=TOS)
  - [x] 1.3 Push limit then index (start) to return stack
  - [x] 1.4 Pop new TOS into BC
  - [x] 1.5 `NEXT`

- [x] Task 2: Implement runtime primitive `(LOOP)` as a DEFCODE word in `src/control_flow.asm` (AC: #1)
  - [x] 2.1 Stack effect: `( -- ) ( R: limit index -- limit index' | )` — inline backward offset follows
  - [x] 2.2 Increment index (bottom of return stack, at `IX+0`/`IX+1`)
  - [x] 2.3 Compare new index with limit (`IX+2`/`IX+3`)
  - [x] 2.4 If equal: drop limit+index from return stack (add 4 to IX), skip inline offset (IP += 2), `NEXT`
  - [x] 2.5 Else: take the backward branch (same sequence as `BRANCH`: read offset cell, ADD to IP_at_offset_cell_addr), `NEXT`

- [x] Task 3: Implement runtime primitive `(+LOOP)` as a DEFCODE word in `src/control_flow.asm` (AC: #2)
  - [x] 3.1 Stack effect: `( n -- ) ( R: limit index -- limit index' | )` — inline backward offset follows
  - [x] 3.2 Compute `old = index`, `new = old + n`
  - [x] 3.3 Crossing check: exit loop if the sign of `(old - limit)` differs from sign of `(new - limit)` (i.e. the step crossed the limit boundary). Equivalent fast test: `((old - limit) XOR (new - limit)) AND 0x8000 ≠ 0`.
  - [x] 3.4 Store `new` back into index slot regardless
  - [x] 3.5 Pop step `n` from data stack into new TOS (BC)
  - [x] 3.6 On exit: drop limit+index from return stack, skip inline offset, `NEXT`
  - [x] 3.7 On continue: take the backward branch, `NEXT`

- [x] Task 4: Implement `UNLOOP` as a DEFCODE word in `src/control_flow.asm` (AC: #3)
  - [x] 4.1 Stack effect: `( -- ) ( R: limit index -- )`
  - [x] 4.2 Add 4 to IX (drop two cells)
  - [x] 4.3 `NEXT`

- [x] Task 5: Implement `I` as a DEFCODE word in `src/control_flow.asm` (AC: #4, #5)
  - [x] 5.1 Stack effect: `( -- index )` — push innermost DO/LOOP index
  - [x] 5.2 Push current BC (save old TOS)
  - [x] 5.3 Load BC from return stack top: `C=(IX+0), B=(IX+1)`
  - [x] 5.4 `NEXT`

- [x] Task 6: Implement `J` as a DEFCODE word in `src/control_flow.asm` (AC: #5)
  - [x] 6.1 Stack effect: `( -- index )` — push next-outer DO/LOOP index
  - [x] 6.2 Push current BC (save old TOS)
  - [x] 6.3 Load BC from return stack at offset 4: `C=(IX+4), B=(IX+5)` (skip inner index+limit, 4 bytes)
  - [x] 6.4 `NEXT`

- [x] Task 7: Implement `DO` as a DEFIMMED word in `src/control_flow.asm` (AC: #1, #7)
  - [x] 7.1 Start with `DW w_QCOMP_cf` compile-only guard
  - [x] 7.2 Compile `(DO)` xt at HERE: `DW w_LIT_cf, w_PAREN_DO_cf` then `DW w_COMMA_cf`
  - [x] 7.3 Push HERE (backward-branch target = address after `(DO)`) onto compile-time data stack
  - [x] 7.4 Push `0` (initial empty LEAVE chain head) onto compile-time data stack
  - [x] 7.5 Compile-time stack effect: `( -- do-addr 0 )`
  - [x] 7.6 `DW EXIT_CODE`

- [x] Task 8: Implement `LOOP` as a DEFIMMED word in `src/control_flow.asm` (AC: #1, #7)
  - [x] 8.1 Start with `DW w_QCOMP_cf`
  - [x] 8.2 Compile-time stack effect at entry: `( do-addr leave-chain -- )`
  - [x] 8.3 `SWAP` to bring do-addr on top: `( leave-chain do-addr )`
  - [x] 8.4 Compile `(LOOP)` xt: `LIT w_PAREN_LOOP_cf , `
  - [x] 8.5 Compute and compile backward offset = `do-addr - HERE` (negative), same pattern as UNTIL in Story 3.3: `HERE - ,` — leaves `( leave-chain )`
  - [x] 8.6 Walk LEAVE chain, patching each placeholder to branch to HERE (end of loop):

    ```
    BEGIN DUP WHILE                  ( leave-chain )
      DUP @                          ( cell next-link )
      SWAP                           ( next-link cell )
      HERE OVER -                    ( next-link cell offset )
      SWAP !                         ( next-link ) ; store offset at cell
    REPEAT DROP
    ```

    Note: this uses `BEGIN WHILE REPEAT` from Story 3.3 and requires `@`, `!`, `DUP`, `SWAP`, `DROP`, `OVER`, `HERE`, `-`, all of which exist.

  - [x] 8.7 `DW EXIT_CODE`

- [x] Task 9: Implement `+LOOP` as a DEFIMMED word in `src/control_flow.asm` (AC: #2, #7)
  - [x] 9.1 Identical structure to `LOOP` but compiles `(+LOOP)` xt instead of `(LOOP)`
  - [x] 9.2 Same LEAVE-chain patching logic

- [x] Task 10: Implement `LEAVE` as a DEFIMMED word in `src/control_flow.asm` (AC: #3, #7)
  - [x] 10.1 Start with `DW w_QCOMP_cf`
  - [x] 10.2 Compile-time stack effect: `( do-addr leave-chain -- do-addr leave-chain' )`
  - [x] 10.3 Compile `UNLOOP` xt: `LIT w_UNLOOP_cf ,`
  - [x] 10.4 Compile `BRANCH` xt: `LIT w_BRANCH_cf ,`
  - [x] 10.5 Push HERE (address of placeholder = new chain head)
  - [x] 10.6 Compile placeholder cell whose value is the OLD chain head (walks to previous LEAVE, or 0):
    - Stack needed: `( do-addr leave-chain new-head )`
    - Bring `leave-chain` to top via `SWAP OVER SWAP` or `ROT`... actually simpler sequence:
      - After HERE: `( do-addr leave-chain here )`
      - `SWAP`: `( do-addr here leave-chain )`
      - `,` compiles leave-chain as the placeholder cell (placeholder body = previous chain link); `( do-addr here )`
      - `here` is now the new chain head → this is the new `leave-chain`
  - [x] 10.7 `DW EXIT_CODE`

- [x] Task 11: Implement `RECURSE` as a DEFCODE IMMEDIATE word in `src/control_flow.asm` (AC: #6, #8)
  - [x] 11.1 Use `DEFCODE "RECURSE", F_IMMEDIATE` (CODE word, not DEFIMMED — needs direct IY/HERE access and dictionary header traversal)
  - [x] 11.2 Check STATE via IY. If STATE=0, `JP w_QCOMP_cf` (or print error and `JP w_ABORT_cf` — prefer jumping to `?COMP` body logic by refactoring its guard into a callable helper; simplest: replicate the state check and jump to a shared error routine)
  - [x] 11.3 Load LATEST from `(IY+UserArea.latest)` → HL = dict entry address
  - [x] 11.4 Compute code-field address: `cfa = entry + 3 + (count_flags & F_LENMASK)`
    - entry+0,1 = hash_link (2 bytes)
    - entry+2 = count_flags
    - entry+3 = first name byte
    - cfa = entry + 3 + namelen
  - [x] 11.5 Compile cfa as a cell at HERE, advance HERE by 2
  - [x] 11.6 `NEXT`

- [x] Task 12: Register all new `w_*_cf` labels in the existing label convention
  - [x] 12.1 CODE words use label placed immediately after DEFCODE macro (no `- 3` EQU)
  - [x] 12.2 DEFIMMED words (DO, LOOP, +LOOP, LEAVE) use `w_XXX_cf EQU w_XXX_body - 3`
  - [x] 12.3 Each DEFIMMED starts with `DW w_QCOMP_cf`

- [x] Task 13: Add REPL tests to `Makefile` starting at test 51 (AC: #1–#8)
  - [x] 13.1 Test 51: `: TENS 10 0 DO I . LOOP ; TENS` — expect `0 1 2 3 4 5 6 7 8 9`
  - [x] 13.2 Test 52: `: EVENS 10 0 DO I . 2 +LOOP ; EVENS` — expect `0 2 4 6 8`
  - [x] 13.3 Test 53: `: FIND5 10 0 DO I 5 = IF I . LEAVE THEN LOOP ; FIND5` — expect `5` (and verify no `6 7 8 9` follow it)
  - [x] 13.4 Test 54: `: NEST 3 0 DO 3 0 DO J . I . LOOP LOOP ; NEST` — expect `0 0 0 1 0 2 1 0 1 1 1 2 2 0 2 1 2 2`
  - [x] 13.5 Test 55: `: FACT DUP 1 > IF DUP 1 - RECURSE * THEN ; 5 FACT .` — expect `120`
  - [x] 13.6 Test 56: `: FACT7 DUP 1 > IF DUP 1 - RECURSE * THEN ; 7 FACT7 .` — expect `5040`
  - [x] 13.7 Test 57: `DO` in interpret mode → expect `? compile only` and recovery
  - [x] 13.8 Test 58: `LOOP` in interpret mode → expect `? compile only` and recovery
  - [x] 13.9 Test 59: `+LOOP` in interpret mode → expect `? compile only` and recovery
  - [x] 13.10 Test 60: `LEAVE` in interpret mode → expect `? compile only` and recovery
  - [x] 13.11 Test 61: `RECURSE` in interpret mode → expect `? compile only` and recovery
  - [x] 13.12 Test 62: DO/LOOP with zero iterations — `: ZERO 5 5 DO I . LOOP ; ZERO` (our impl: with post-increment-then-equal-check, starting index = limit will loop 65536 times; document chosen behaviour and test an *unambiguous* boundary case instead — e.g., `: ONE 1 0 DO 42 . LOOP ; ONE` expecting a single `42`)
  - [x] 13.13 Test 63: Multiple LEAVEs in one DO-LOOP — `: TWOL 10 0 DO I 3 = IF LEAVE THEN I 7 = IF LEAVE THEN LOOP 99 . ; TWOL` expects `99` printed once (loop exits at I=3; second LEAVE never reached, but both compile-time chain links must be patched)
  - [x] 13.14 Test 64: Countdown with negative +LOOP — `: DN 0 10 DO I . -1 +LOOP ; DN` expects `10 9 8 7 6 5 4 3 2 1 0` (11 values — the trailing `0` is ANS-correct: the boundary-crossing test exits only when stepping from `0` to `-1`, after `0` has already been printed; see Debug Log)

- [x] Task 14: Verify no regressions
  - [x] 14.1 `make test` — all existing regression tests pass
  - [x] 14.2 `make test-repl` — all REPL tests pass (1 through 64)
  - [x] 14.3 `make` — normal build succeeds

## Dev Notes

### What Already Exists (verified from source)

**Return stack primitives** (`src/stack_ops.asm`):
- `>R` / `R>` / `R@` — available as `w_TO_R_cf`, `w_R_FROM_cf`, `w_R_FETCH_cf`
- Return stack grows downward in IX. `(IX+0)` = low byte of top-of-return-stack, `(IX+1)` = high byte.

**Register contract** (from architecture and Story 3.3):
- BC = TOS, DE = IP, SP = parameter stack, IX = return stack, IY = user area pointer
- CODE words must preserve register contract across `NEXT`
- `NEXT` macro defined in `src/macros.asm`

**Inline branches** (`src/inner_interpreter.asm:101-135`):
- `w_BRANCH_cf` — unconditional, offset relative to offset cell address
- `w_QBRANCH_cf` — conditional on BC=0, pops new TOS
- Offset convention: `new_IP = offset_cell_addr + offset` (offset stored as 2-byte signed cell)

**Compilation primitives** (used identically to Story 3.3):
- `w_HERE_cf` (`memory.asm:92`), `w_COMMA_cf` (`memory.asm:119`)
- `w_STORE_cf`, `w_FETCH_cf`, `w_SWAP_cf`, `w_OVER_cf`, `w_DROP_cf`, `w_DUP_cf`, `w_MINUS_cf`
- `w_LIT_cf` (`inner_interpreter.asm:87`) for inline literal xts
- `EXIT_CODE` (`inner_interpreter.asm:23`)
- BEGIN/WHILE/REPEAT (Story 3.3) — needed by LOOP/+LOOP to walk the LEAVE chain at compile time

**Compile-only guard**:
- `w_QCOMP_cf` (`control_flow.asm:10`) — already implemented in Story 3.3; prints `? compile only` and ABORTs when STATE=0

**LATEST pointer** (`src/structures.asm:22`, `src/compiler.asm:194-196`):
- Stored in user area at `UserArea.latest` (IY offset)
- Points to the dictionary entry start of the most recently defined word
- `:` sets F_SMUDGE on LATEST's count_flags byte; SMUDGE is cleared by `;` (`compiler.asm:376-380`)
- RECURSE uses LATEST directly; the SMUDGE flag hides the word from FIND but does NOT prevent direct compilation by CFA

**Dictionary entry layout** (`src/structures.asm:10-14`):
```
entry+0,1  hash_link
entry+2    count_flags  (bits 7=IMMEDIATE, 6=SMUDGE, 4-0=length via F_LENMASK)
entry+3..  name bytes (name_len = count_flags & F_LENMASK)
entry+3+namelen   code_field (starts with JP DOCOL for DEFWORD/DEFIMMED)
```

**`F_LENMASK`** is defined in `src/constants.asm` as `0x1F` (verify on read).

### Architectural Split: CODE runtime + DEFIMMED compilers

Per `_bmad-output/planning-artifacts/architecture.md`:
> "Should be Forth (colon definitions): ... control flow compilers (IF, ELSE, THEN, DO, LOOP — IMMEDIATE words)"

And:
> "Must be CODE (assembly primitives): Threading: NEXT, DOCOL, EXIT, LIT, BRANCH, ?BRANCH, EXECUTE"

Runtime primitives that touch the return stack directly (`(DO)`, `(LOOP)`, `(+LOOP)`, `UNLOOP`, `I`, `J`) are **CODE** words — they need direct IX manipulation and are hot-path.

Compile-time IMMEDIATE words (`DO`, `LOOP`, `+LOOP`, `LEAVE`) are **DEFIMMED** Forth words — they compose existing primitives.

`RECURSE` is a **DEFCODE IMMEDIATE** word because it needs to read `UserArea.latest` and walk the dictionary header to compute the CFA — more convenient in assembly than assembling a long DEFIMMED thread.

### `(DO)` Runtime Implementation

```z80
w_PAREN_DO:
    DEFCODE "(DO)", 0
w_PAREN_DO_cf:
    ; ( limit start -- ) ( R: -- limit start )
    ; BC = start (TOS), SP -> [limit, ...]
    POP     HL              ; HL = limit
    ; Push limit to return stack
    DEC     IX
    DEC     IX
    LD      (IX+0), L
    LD      (IX+1), H
    ; Push index (start) to return stack
    DEC     IX
    DEC     IX
    LD      (IX+0), C
    LD      (IX+1), B
    POP     BC              ; New TOS
    NEXT
```

Return stack layout after (DO): `IX+0,1 = index`, `IX+2,3 = limit`.

### `(LOOP)` Runtime Implementation

```z80
w_PAREN_LOOP:
    DEFCODE "(LOOP)", 0
w_PAREN_LOOP_cf:
    ; ( -- ) ( R: limit index -- limit index' | )
    ; Inline backward offset follows in thread.
    ; Increment index
    INC     (IX+0)
    JR      NZ, .loop_check
    INC     (IX+1)
.loop_check:
    ; Compare index (IX+0/1) with limit (IX+2/3)
    LD      A, (IX+0)
    CP      (IX+2)
    JR      NZ, .loop_take
    LD      A, (IX+1)
    CP      (IX+3)
    JR      NZ, .loop_take
    ; index == limit → exit
    ; Drop index+limit (4 bytes) from return stack
    INC     IX
    INC     IX
    INC     IX
    INC     IX
    ; Skip inline offset cell
    INC     DE
    INC     DE
    NEXT
.loop_take:
    ; Take backward branch (same as BRANCH)
    EX      DE, HL          ; HL = IP (points to offset cell)
    LD      E, (HL)
    INC     HL
    LD      D, (HL)
    DEC     HL              ; HL = offset_cell_addr
    ADD     HL, DE          ; HL = new IP = offset_cell_addr + offset
    NEXTHL
```

**Termination semantics chosen:** Increment THEN compare-equal. This matches classic Forth for positive steps of 1 and the range-nonempty case. Known edge case: `start == limit` on entry will wrap and iterate 65536 times. This is implementation-defined per ANS and acceptable for MVP. Document in Dev Notes but do not add test coverage — tests use only unambiguous ranges.

### `(+LOOP)` Runtime Implementation

Uses the boundary-crossing test. Classic algorithm:

```
old_index = R[top]           ; 2 bytes at IX+0,1
step      = TOS              ; BC
new_index = old_index + step
diff_old  = old_index - limit
diff_new  = new_index - limit
crossed   = (diff_old XOR diff_new) sign bit  ; bit 15
```

If the sign bit of `diff_old XOR diff_new` is set, the step crossed the limit boundary → exit the loop. Otherwise store `new_index` and branch back.

Pseudocode (z80-ish):

```z80
w_PAREN_PLUS_LOOP:
    DEFCODE "(+LOOP)", 0
w_PAREN_PLUS_LOOP_cf:
    ; BC = step (TOS)
    ; Read old_index from R[0]
    LD      L, (IX+0)
    LD      H, (IX+1)       ; HL = old_index
    ; Save old_index for diff_old
    PUSH    HL              ; (use data stack as scratch)
    ; new_index = old + step
    ADD     HL, BC          ; HL = new_index
    ; Store new_index back
    LD      (IX+0), L
    LD      (IX+1), H
    ; Compute diff_new = new - limit
    LD      E, (IX+2)
    LD      D, (IX+3)       ; DE = limit
    OR      A               ; clear carry
    SBC     HL, DE          ; HL = new - limit
    EX      DE, HL          ; DE = diff_new, preserves limit in HL? no — limit is gone; reload below
    POP     HL              ; HL = old_index
    ; Need diff_old = old - limit. Reload limit.
    LD      C, (IX+2)
    LD      B, (IX+3)       ; BC = limit (clobbers step; that's OK because we no longer need step)
    OR      A
    SBC     HL, BC          ; HL = diff_old
    ; Crossing test: (diff_old XOR diff_new) & 0x8000
    LD      A, H
    XOR     D               ; A = high_byte(diff_old XOR diff_new)
    BIT     7, A
    JR      NZ, .ploop_exit
    ; Continue: take backward branch. Restore DE = IP first.
    ; DE already clobbered; IP is in the caller's DE which we overwrote. CRITICAL:
    ; The dev MUST save DE (IP) on entry before any EX DE,HL or OP that clobbers DE.
    ; Suggestion: use a scratch memory cell or push DE to return stack at entry.
```

**Implementation note**: Because DE = IP must be preserved, the dev should save IP at entry (e.g., `PUSH DE` on the CPU stack is NOT safe here because SP is the Forth parameter stack; instead, use a dedicated 2-byte scratch memory cell like `ploop_saved_ip: DW 0`, or a spare slot in the user area). Re-load IP before taking the branch or falling through. Pop the new TOS (old step is gone; next param-stack cell becomes TOS).

After crossing-test decision:
- **Continue branch**: reload IP from scratch, execute BRANCH-style add (read inline offset, ADD to IP at offset_cell_addr), pop new TOS, `NEXTHL`.
- **Exit branch**: drop 4 bytes from IX, reload IP from scratch, advance IP past the offset cell (`INC DE INC DE`), pop new TOS, `NEXT`.

The dev is free to implement this differently (e.g., use the return stack as scratch, or structure the compare before clobbering DE). The algorithm is what matters; the register juggling is implementation detail.

### `UNLOOP`, `I`, `J` Runtime Implementation

```z80
w_UNLOOP:
    DEFCODE "UNLOOP", 0
w_UNLOOP_cf:
    ; ( -- ) ( R: limit index -- )
    INC     IX
    INC     IX
    INC     IX
    INC     IX
    NEXT

w_I:
    DEFCODE "I", 0
w_I_cf:
    ; ( -- index ) ; push innermost DO index
    PUSH    BC              ; save old TOS
    LD      C, (IX+0)
    LD      B, (IX+1)
    NEXT

w_J:
    DEFCODE "J", 0
w_J_cf:
    ; ( -- index ) ; push next-outer DO index (skip inner index+limit = 4 bytes)
    PUSH    BC
    LD      C, (IX+4)
    LD      B, (IX+5)
    NEXT
```

### `DO` Compile-Time Implementation (DEFIMMED)

```z80
w_DO:
    DEFIMMED "DO"
w_DO_body:
w_DO_cf EQU w_DO_body - 3
    DW w_QCOMP_cf                ; compile-only guard
    ; Compile (DO) xt
    DW w_LIT_cf, w_PAREN_DO_cf
    DW w_COMMA_cf
    ; Push HERE (backward branch target for LOOP/+LOOP)
    DW w_HERE_cf
    ; Push 0 (empty LEAVE chain head)
    DW w_LIT_cf, 0
    ; Compile-time stack now: ( do-addr 0 )
    DW EXIT_CODE
```

### `LOOP` Compile-Time Implementation (DEFIMMED)

Compile-time stack at entry: `( do-addr leave-chain -- )`.

Approach:
1. Swap to `( leave-chain do-addr )`.
2. Compile `(LOOP)` xt.
3. Compute and compile backward offset `do-addr - HERE` via `HERE -` then `,` (same pattern as UNTIL in Story 3.3).
4. Compile-time stack: `( leave-chain )`.
5. Walk LEAVE chain using BEGIN/WHILE/REPEAT, patching each cell's content to `HERE - cell_addr` (forward offset from that cell to loop end).

```z80
w_LOOP:
    DEFIMMED "LOOP"
w_LOOP_body:
w_LOOP_cf EQU w_LOOP_body - 3
    DW w_QCOMP_cf
    ; ( do-addr leave-chain -- )
    DW w_SWAP_cf                 ; ( leave-chain do-addr )
    ; Compile (LOOP)
    DW w_LIT_cf, w_PAREN_LOOP_cf
    DW w_COMMA_cf
    ; Backward offset = do-addr - HERE; compile
    DW w_HERE_cf                 ; ( leave-chain do-addr here )
    DW w_MINUS_cf                ; ( leave-chain do-addr-here )
    DW w_COMMA_cf                ; ( leave-chain )
    ; Walk LEAVE chain: patch each cell to branch to HERE
    ;   : walk ( chain -- )
    ;     BEGIN DUP WHILE
    ;       DUP @                ( cell next )
    ;       SWAP                 ( next cell )
    ;       HERE OVER -          ( next cell offset )
    ;       SWAP !               ( next )
    ;     REPEAT DROP ;
    ;
    ; Inline thread — uses BEGIN/WHILE/REPEAT primitives (w_BRANCH_cf, w_QBRANCH_cf)
    ; embedded by hand at assembly time. Pattern:
.walk_begin:
    DW w_DUP_cf
    DW w_QBRANCH_cf
    DW .walk_end - $             ; forward to DROP+EXIT
    DW w_DUP_cf
    DW w_FETCH_cf                ; DUP @
    DW w_SWAP_cf
    DW w_HERE_cf
    DW w_OVER_cf
    DW w_MINUS_cf
    DW w_SWAP_cf
    DW w_STORE_cf
    DW w_BRANCH_cf
    DW .walk_begin - $           ; backward to begin
.walk_end:
    DW w_DROP_cf
    DW EXIT_CODE
```

**Offset convention reminder** (verified in Story 3.3): `DW target - $` where `$` is the address of the `DW` (the offset cell itself). This produces `offset = target - offset_cell_addr`, which `BRANCH` interprets correctly because it computes `new_IP = offset_cell_addr + offset`.

### `+LOOP` Compile-Time Implementation (DEFIMMED)

Identical to `LOOP` except it compiles `w_PAREN_PLUS_LOOP_cf` instead of `w_PAREN_LOOP_cf`. All other logic (swap, backward offset, LEAVE chain walk) is the same. The dev may factor the chain-walk into a shared internal label pair to avoid duplication, or simply duplicate the thread — duplication is acceptable and matches the style of Story 3.3 (no premature abstraction for 2 call sites).

### `LEAVE` Compile-Time Implementation (DEFIMMED)

Compile-time stack: `( do-addr leave-chain -- do-addr leave-chain' )`.

Each LEAVE:
1. Compiles `UNLOOP` xt (runtime drops loop frame from return stack).
2. Compiles `BRANCH` xt.
3. Compiles a placeholder cell whose initial value is the current chain head (`leave-chain`). This turns the placeholder cell into a linked-list node.
4. Updates `leave-chain` to point at the newly compiled placeholder cell.

```z80
w_LEAVE:
    DEFIMMED "LEAVE"
w_LEAVE_body:
w_LEAVE_cf EQU w_LEAVE_body - 3
    DW w_QCOMP_cf
    ; ( do-addr leave-chain -- do-addr leave-chain' )
    DW w_LIT_cf, w_UNLOOP_cf
    DW w_COMMA_cf                ; compile UNLOOP
    DW w_LIT_cf, w_BRANCH_cf
    DW w_COMMA_cf                ; compile BRANCH
    ; ( do-addr leave-chain ) ; HERE = placeholder position
    DW w_HERE_cf                 ; ( do-addr leave-chain here )
    DW w_SWAP_cf                 ; ( do-addr here leave-chain )
    DW w_COMMA_cf                ; store leave-chain as placeholder cell content; ( do-addr here )
    ; 'here' is the new chain head (address of the placeholder cell)
    ; Stack is now ( do-addr here ) = ( do-addr leave-chain' ) — correct
    DW EXIT_CODE
```

**Chain semantics**: Each placeholder cell stores a pointer to the previous LEAVE's placeholder (or 0 for end of chain). When LOOP/+LOOP walks the chain, it overwrites each cell's content with the forward branch offset to loop-end. After patching, the cells no longer hold chain links; they hold correct BRANCH offsets.

### `RECURSE` Implementation (DEFCODE IMMEDIATE)

```z80
w_RECURSE:
    DEFCODE "RECURSE", F_IMMEDIATE
w_RECURSE_cf:
    ; Compile-only guard
    LD      A, (IY+UserArea.state)
    OR      (IY+UserArea.state+1)
    JP      Z, w_QCOMP_cf       ; STATE=0 → error via ?COMP path
    ; Note: w_QCOMP_cf re-checks STATE (that's fine) and either returns or ABORTs.
    ; Alternative: JP directly to the error-print routine inside ?COMP.
    ; Simplest is to just fall through the ?COMP check again.
    ;
    ; Load LATEST into HL
    LD      L, (IY+UserArea.latest)
    LD      H, (IY+UserArea.latest+1)
    ; HL = dict entry start
    ; Skip hash_link (2 bytes) → HL+2 points to count_flags
    INC     HL
    INC     HL
    LD      A, (HL)             ; A = count_flags
    AND     F_LENMASK           ; A = name length
    ; Advance HL past count_flags and name: HL = HL + 1 + namelen
    INC     HL                  ; past count_flags
    LD      C, A
    LD      B, 0
    ADD     HL, BC              ; HL = code field address (cfa)
    ; Compile cfa as a cell at HERE
    LD      E, (IY+UserArea.here)
    LD      D, (IY+UserArea.here+1)
    LD      A, L
    LD      (DE), A
    INC     DE
    LD      A, H
    LD      (DE), A
    INC     DE
    LD      (IY+UserArea.here), E
    LD      (IY+UserArea.here+1), D
    NEXT
```

**Why LATEST works during colon compilation**: `:` sets F_SMUDGE, hiding the word from FIND, but LATEST still points at the new entry (`compiler.asm:194-196`). The entry header (hash_link, count_flags, name) is already laid down; only the body is still being compiled. The code field (`JP DOCOL`) is already emitted at offset `3 + namelen`. RECURSE just compiles that address as a call target.

**Register clobbering**: This CODE word uses A, BC, DE, HL. DE = IP is clobbered — BUT RECURSE is IMMEDIATE, so it runs from INTERPRET, not from a colon-definition thread. INTERPRET calls EXECUTE which does `JP (HL)`, meaning DE (IP) is whatever INTERPRET's caller set it to. INTERPRET is in `outer_interpreter.asm` and restores its own state. **However**, IMMEDIATE words compiled into colon definitions still execute via NEXT from a thread (e.g., if RECURSE is itself called from within another IMMEDIATE word's thread). For safety, save DE on entry and restore before NEXT — or structure the code to avoid clobbering DE.

**Simpler register-safe version**: Use `PUSH DE` / `POP DE` on the CPU stack (which IS the Forth parameter stack, so this juggling works as long as the cell count nets to zero). Alternatively, do the HERE writes via IY without touching DE at all — compute cfa in HL, then write HL via a loop using (IX) scratch or a static scratch cell.

**Cleanest approach**: keep IP (DE) untouched by using only HL and a static scratch variable:

```z80
w_RECURSE_cf:
    LD      A, (IY+UserArea.state)
    OR      (IY+UserArea.state+1)
    JP      Z, w_QCOMP_cf
    LD      L, (IY+UserArea.latest)
    LD      H, (IY+UserArea.latest+1)
    INC     HL
    INC     HL                  ; HL -> count_flags
    LD      A, (HL)
    AND     F_LENMASK
    INC     HL                  ; HL -> first name byte
    ; Add A to HL
    ADD     A, L
    LD      L, A
    JR      NC, .rec_no_carry
    INC     H
.rec_no_carry:
    ; HL = cfa. Compile it at HERE.
    LD      (recurse_scratch), HL
    LD      L, (IY+UserArea.here)
    LD      H, (IY+UserArea.here+1)
    LD      A, (recurse_scratch)
    LD      (HL), A
    INC     HL
    LD      A, (recurse_scratch+1)
    LD      (HL), A
    INC     HL
    LD      (IY+UserArea.here), L
    LD      (IY+UserArea.here+1), H
    NEXT

recurse_scratch: DW 0
```

This keeps DE untouched entirely. The 2-byte scratch cell lives in the BSS-equivalent section near the word definition.

### Compile-Time Stack Discipline (CRITICAL)

DO/LOOP/+LOOP/LEAVE push and pop items on the **data stack at compile time**. This is how Forth control flow compilers communicate. The developer must track the stack effect across the full `DO ... LEAVE? ... LOOP` sequence:

```
DO        ( -- do-addr 0 )
  ...                             ( do-addr chain )
LEAVE     ( do-addr chain -- do-addr chain' )
  ...                             ( do-addr chain )
LOOP      ( do-addr chain -- )
```

If a LEAVE appears nested inside IF/THEN within the loop body, the IF/ELSE/THEN forward-refs also pile up on this same compile-time data stack. The developer must ensure IF/ELSE/THEN are fully balanced (and consumed by a matching THEN) before the LOOP executes, so the LEAVE chain stays on top. This is handled naturally by Forth's LIFO discipline — no special machinery needed — but the dev should understand the convention before writing tests with nested control flow.

### Nested DO/LOOPs

Each nested DO creates its own `(do-addr 0)` pair on the compile-time data stack. The innermost DO's pair is on top; outer LOOPs see the outer DO's pair after the inner LOOP consumes its own. Runtime return stack holds nested frames: inner `index/limit` at IX+0..3, outer at IX+4..7. `J` reads from IX+4..5 (outer index), which is why Task 6.3 uses that specific offset.

### RECURSE and SMUDGE

`:` sets F_SMUDGE on the LATEST entry so that FIND skips it — preventing accidental recursion via name lookup during compilation. RECURSE sidesteps FIND entirely by reading LATEST directly, so SMUDGE is irrelevant to it. After `;` clears SMUDGE, the word becomes visible; subsequent calls by name work normally.

### Include Order

`src/control_flow.asm` is already included in `src/antforth.asm` between `memory.asm` and `io.asm`. All labels referenced (LIT, BRANCH, ?BRANCH, HERE, COMMA, STORE, FETCH, SWAP, OVER, DUP, DROP, MINUS, QCOMP, UNLOOP, paren-DO/LOOP/+LOOP, I, J) will be either already defined (from earlier files) or forward-referenced within the same file (sjasmplus resolves multi-pass).

`RECURSE`'s forward reference to `w_QCOMP_cf` is fine — `?COMP` is in the same file, just defined earlier.

### Anti-Patterns to Avoid

1. **Do NOT implement DO/LOOP/+LOOP/LEAVE as CODE words** — architecture says these are Forth-level DEFIMMED compilers. Only the *runtime* `(DO) (LOOP) (+LOOP)` and the *accessors* `I J UNLOOP` are CODE.

2. **Do NOT forget `EQU body - 3`** for DEFIMMED words — per memory `feedback_defword_cf_label.md`, the `_cf` label must point to `JP DOCOL`, not the body. This bit Story 3.3 if the convention wasn't followed; follow it here.

3. **Do NOT forget `?COMP` guard** at the start of every control-flow DEFIMMED word (DO, LOOP, +LOOP, LEAVE). RECURSE gets its own inline STATE check (it's a CODE word).

4. **Do NOT clobber DE (IP) in CODE words** without saving/restoring — every CODE word must `NEXT` with DE = IP intact. RECURSE in particular must be careful because it also clobbers HL. Use a scratch memory cell rather than juggling DE.

5. **Do NOT assume `(LOOP)` step size is always 1** — only `(LOOP)` does simple increment; `(+LOOP)` MUST use the crossing test for correctness with negative and non-unit steps.

6. **Do NOT forget to pop step from data stack in `(+LOOP)`** — step is consumed as part of the runtime, unlike `(LOOP)` which takes no data-stack input.

7. **Do NOT write the LEAVE-chain walk as a separate helper word** — inline the BEGIN/WHILE/REPEAT thread inside LOOP and +LOOP (duplicating ~15 cells is fine; creating a helper dict entry is not worth it for 2 call sites — consistent with Story 3.3 anti-pattern #10).

8. **Do NOT compile tests into the regression test thread** — per memory `feedback_repl_tests_preferred.md`, new tests go into the `test-repl` Makefile target (starting at test 51 for this story).

9. **Do NOT use BDOS calls from DEFIMMED words** — they execute as threaded code, not CODE. Any BDOS work (error messages) belongs to `?COMP` which is already a CODE word.

10. **Do NOT add separate dictionary entries for `>CFA` or `>BODY`** just to implement RECURSE — RECURSE computes the CFA inline. Don't over-generalise.

11. **Do NOT assume `J` works at 3 cells deep** — it's 2 cells (4 bytes) deep (past inner index + inner limit). `IX+4/IX+5` is the outer index.

12. **Do NOT test `start == limit` edge case** — our `(LOOP)` uses post-increment-then-equal-compare, which wraps to 65536 iterations in that case. Document the behaviour; write tests only for well-defined ranges (limit > start with step 1, or a correctly-matched range for +LOOP).

13. **Do NOT define the runtime words as internal-only labels** — make them DEFCODE words (`(DO)`, `(LOOP)`, `(+LOOP)`) so they follow the same dictionary-entry pattern as BRANCH/?BRANCH. This matches the architecture's consistency goal and makes the runtime words discoverable via WORDS.

### Register Contract Reminders

CODE words in this story that must preserve the register contract across `NEXT`:

| Word | Clobbers (OK) | Must preserve |
|------|----------------|---------------|
| `(DO)` | A, HL, BC (new TOS from pop) | DE=IP, IX (decremented, not corrupted), IY |
| `(LOOP)` | A, HL, DE (as IP manipulation) | BC=TOS, IY, IX (net 0 change or -4) |
| `(+LOOP)` | A, HL, DE scratch (RESTORE before NEXT) | BC=new TOS (pop), IY |
| `UNLOOP` | (none — IX advance only) | all |
| `I`, `J` | (just push old BC and load new BC from IX) | DE, HL, IX, IY |
| `RECURSE` | A, HL, BC scratch | DE=IP (critical), IX, IY |

The threaded DEFIMMED words (DO, LOOP, +LOOP, LEAVE) automatically preserve the register contract because the inner interpreter maintains it around every call.

### File Locations

All new code goes in `src/control_flow.asm` (extending the file from Story 3.3):

| Word | Type | Notes |
|------|------|-------|
| `(DO)` | DEFCODE | runtime primitive |
| `(LOOP)` | DEFCODE | runtime primitive, inline backward offset |
| `(+LOOP)` | DEFCODE | runtime primitive with crossing test |
| `UNLOOP` | DEFCODE | drop loop frame from IX |
| `I` | DEFCODE | innermost index |
| `J` | DEFCODE | next-outer index |
| `DO` | DEFIMMED | compile-only compiler |
| `LOOP` | DEFIMMED | compile-only compiler, walks LEAVE chain |
| `+LOOP` | DEFIMMED | compile-only compiler, walks LEAVE chain |
| `LEAVE` | DEFIMMED | compile-only, pushes to LEAVE chain |
| `RECURSE` | DEFCODE IMMEDIATE | compiles LATEST's cfa |

`Makefile` — append REPL tests 51–64.

### Testing Strategy:

**Primary: REPL-piped tests** (per memory `feedback_repl_tests_preferred.md`).

New tests start at test **51** (test 50 was the last in Story 3.3). Do NOT add to the assembly regression thread.

Tests use existing arithmetic/stack/comparison/IF primitives and `.` for output verification. `."` and `S"` are NOT yet available (Story 3.5).

For LEAVE testing, verify BOTH that:
- The loop exits at the first LEAVE (iterations after the LEAVE do not run), AND
- The compile-time chain correctly patches multiple LEAVEs in the same loop (test 63).

For RECURSE testing, verify a recursive definition produces correct results AND the word is callable by name after compilation finishes (standard FACTORIAL test).

Quick sanity script pattern (same as Story 3.3):

```
printf ': TENS 10 0 DO I . LOOP ;\r\nTENS\r\nBYE\r\n' | iz-cpm antforth.com
```

Expected output contains: `0 1 2 3 4 5 6 7 8 9` (space-separated, per `.` formatting).

### Previous Story Intelligence (from Story 3.3)

- All DEFIMMED words worked correctly on first attempt when following `EQU body - 3` convention and starting with `DW w_QCOMP_cf`.
- The compile-time data stack pattern for forward/backward references works cleanly with `HERE`, `,`, `!`, `-`, `OVER`, `SWAP`, `DROP`.
- No debug issues in Story 3.3 — the same pattern should work here.
- REPL tests were added 35–50 incrementally; code review added 6 more tests (45–50) for guard coverage and edge cases. **Anticipate the same**: add comprehensive compile-only guard tests from the start to avoid a code-review round-trip.

### Git Intelligence

Recent commits (last 5):
- `38c7c02` completed story 3.2
- `8859897` code review story 3.1
- `6321680` completed story 3.1
- `0c87806` completed story 3.0
- `bff479b` completed story 2.4

Story 3.3 is in the working tree but not yet committed (per `git status`: `M src/control_flow.asm`, `M Makefile`, new `3-3-...md` untracked). Story 3.4 builds directly on Story 3.3's control_flow.asm and BEGIN/WHILE/REPEAT infrastructure.

### Project Structure Notes

- `src/control_flow.asm` — Append all new words after existing Story 3.3 code
- `Makefile` — Append REPL tests 51–64
- No other files need changes
- Include order in `src/antforth.asm` is already correct (no new INCLUDEs needed)

### References

- [Source: src/control_flow.asm:1-162] — Existing ?COMP, IF/THEN/ELSE, BEGIN/UNTIL/WHILE/REPEAT (Story 3.3)
- [Source: src/inner_interpreter.asm:23-29] — EXIT_CODE
- [Source: src/inner_interpreter.asm:85-94] — LIT implementation (for inline xt loads)
- [Source: src/inner_interpreter.asm:101-135] — BRANCH / ?BRANCH (offset convention)
- [Source: src/compiler.asm:183-201] — build_header (LATEST update at lines 194-196)
- [Source: src/compiler.asm:208-272] — COLON sets F_SMUDGE, enters compile mode
- [Source: src/compiler.asm:353-386] — SEMICOLON clears SMUDGE, compiles EXIT_CODE
- [Source: src/compiler.asm:415-435] — LITERAL pattern for an IMMEDIATE CODE word that writes to HERE
- [Source: src/compiler.asm:594-634] — DOES> as an IMMEDIATE CODE word with direct IY/HERE manipulation (closest analogue for RECURSE's style)
- [Source: src/memory.asm:92-98] — HERE
- [Source: src/memory.asm:119-131] — COMMA
- [Source: src/stack_ops.asm:237-275] — >R, R>, R@ (return stack layout reference)
- [Source: src/macros.asm:100-135] — DEFWORD / DEFIMMED macros (code field = JP DOCOL)
- [Source: src/structures.asm:10-27] — DictEntry and UserArea layouts
- [Source: src/constants.asm] — F_IMMEDIATE, F_SMUDGE, F_LENMASK flag definitions (verify F_LENMASK = 0x1F)
- [Source: _bmad-output/planning-artifacts/architecture.md#Should be Forth] — DO, LOOP are IMMEDIATE Forth words
- [Source: _bmad-output/planning-artifacts/architecture.md#Must be CODE] — Threading primitives stay in assembly
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.4] — Story requirements and BDD criteria
- [Source: _bmad-output/implementation-artifacts/3-3-conditionals-and-indefinite-loops.md] — Previous story intelligence and DEFIMMED patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6, 1M context)

### Debug Log References

- First implementation used the story-spec approach of passing `leave-chain` on the compile-time data stack. This broke when LEAVE was nested inside IF/THEN, because at LEAVE time the top-of-stack was the IF's forward-ref, not the chain head — so LEAVE corrupted both structures. Confirmed with `: FIND5 10 0 DO I 5 = IF I . LEAVE THEN LOOP ;` which hung the interpreter.
- Fix: kept the LEAVE-chain head in a dedicated assembly cell (`leave_chain_head`), with DO/LOOP saving/restoring the outer value via the data stack (`old-lc`). LEAVE then doesn't touch the compile-time data stack at all, so it works cleanly when nested inside any other control-flow construct. Added two internal CODE helpers `w_LCFETCH_cf` / `w_LCSTORE_cf` (no dictionary header) used only by DO/LOOP/+LOOP/LEAVE.
- The REPL test 64 countdown `: DN 0 10 DO I . -1 +LOOP ; DN` outputs 11 values (`10 9 8 7 6 5 4 3 2 1 0`) under the standard ANS boundary-crossing test. The story originally expected 10 values without the `0`; adjusted the test to match the ANS-correct result.

### Completion Notes List

- Added 11 new words to `src/control_flow.asm`: `(DO)`, `(LOOP)`, `(+LOOP)`, `UNLOOP`, `I`, `J` (CODE runtimes) plus `DO`, `LOOP`, `+LOOP`, `LEAVE` (DEFIMMED compilers) and `RECURSE` (CODE IMMEDIATE).
- Runtime return-stack frame layout after `(DO)`: `(IX+0,1)=index`, `(IX+2,3)=limit`. `J` reads `(IX+4,5)` (outer index).
- `(+LOOP)` preserves DE=IP by stashing it in `ploop_saved_ip` scratch cell, and uses the canonical boundary-crossing test `(diff_old XOR diff_new) & 0x8000` where `diff = index - limit`.
- `RECURSE` reads LATEST via IY, walks past `hash_link` (2 bytes) and `count_flags+name` (`1 + namelen`) to compute the code-field address, then writes it at HERE. It uses `recurse_scratch` so that DE=IP is never touched.
- LEAVE chain is kept in the assembly cell `leave_chain_head`; DO saves the old value to the data stack and resets the global to 0, LOOP/+LOOP walks the chain then restores the old value. This keeps LEAVE compatible with nesting inside IF/ELSE/THEN and BEGIN/WHILE/REPEAT.
- All 14 new REPL tests (51–64) pass, and the full regression suite (assembly `make test` + REPL 1–64) passes with no regressions.

### File List

- `src/control_flow.asm` — extended (Story 3.4 section appended with 11 new words + 2 internal helpers + 3 scratch cells)
- `Makefile` — appended REPL tests 51–64 to `test-repl` target
- `_bmad-output/implementation-artifacts/3-4-counted-loops-and-recurse.md` — this story file
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — status updated to `review`

### Change Log

- 2026-04-09: Implemented counted-loop primitives and RECURSE; added REPL tests 51–64; all tests green.
- 2026-04-09: Code review applied — tightened REPL test 53/55/56 grep patterns to line-anchored matches (`^…  ok$`) to eliminate false-positive risk from substring leaks (e.g. `15 ` matching the test for `5 `); updated task 13.14 description so it matches the as-shipped 11-value ANS-correct expectation. Story moved to done.
