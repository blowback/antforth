# Story 1.3: Stack & Memory Primitives

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want all stack and memory CODE primitives,
so that I can manipulate the parameter stack, return stack, and memory in threaded code sequences.

## Acceptance Criteria

1. **Given** a hardcoded thread exercising stack operations **When** DUP executes with value `x` on stack **Then** the stack contains `x x` **When** DROP executes with `x y` on stack **Then** the stack contains `x` **When** SWAP executes with `x y` on stack **Then** the stack contains `y x` **When** OVER executes with `x y` on stack **Then** the stack contains `x y x` **When** ROT executes with `x y z` on stack **Then** the stack contains `y z x` **And** PICK, ROLL, DEPTH all produce correct results per ANS spec

2. **Given** a hardcoded thread exercising return stack operations **When** `>R` executes with value on parameter stack **Then** the value is moved to the return stack (IX) **When** `R>` executes **Then** the value is moved back to the parameter stack **When** `R@` executes **Then** the top of return stack is copied to parameter stack without removing it

3. **Given** a hardcoded thread exercising memory operations **When** `!` stores a cell value at an address and `@` fetches it **Then** the fetched value matches the stored value **When** `C!` stores a byte and `C@` fetches it **Then** the fetched byte matches the stored byte **When** `+!` adds a value to a cell at an address **Then** the cell contains the original value plus the added value

4. **Given** a hardcoded thread exercising dictionary space allocation **When** `HERE` executes **Then** it pushes the current dictionary pointer **When** `ALLOT` allocates n bytes **Then** HERE advances by n **When** `,` (COMMA) compiles a cell and `C,` compiles a byte **Then** the values are stored at HERE and HERE advances accordingly **And** ALIGN and ALIGNED produce correctly aligned addresses

5. **Given** a hardcoded thread exercising FILL and MOVE **When** FILL fills a region with a byte value **Then** all bytes in the region contain that value **When** MOVE copies a region to another address **Then** the destination contains an exact copy (handling overlapping regions correctly)

## Tasks / Subtasks

- [x] Task 1: Implement parameter stack primitives in `src/stack_ops.asm` (AC: #1)
  - [x] 1.1 DUP ( x -- x x )
  - [x] 1.2 DROP ( x -- )
  - [x] 1.3 SWAP ( x1 x2 -- x2 x1 )
  - [x] 1.4 OVER ( x1 x2 -- x1 x2 x1 )
  - [x] 1.5 ROT ( x1 x2 x3 -- x2 x3 x1 )
  - [x] 1.6 PICK ( xu ... x1 x0 u -- xu ... x1 x0 xu )
  - [x] 1.7 ROLL ( xu xu-1 ... x0 u -- xu-1 ... x0 xu )
  - [x] 1.8 DEPTH ( -- n )
  - [x] 1.9 SP@ ( -- addr ) and SP! ( addr -- )
  - [x] 1.10 RP@ ( -- addr ) and RP! ( addr -- )
- [x] Task 2: Implement return stack primitives in `src/stack_ops.asm` (AC: #2)
  - [x] 2.1 >R ( x -- ) ( R: -- x )
  - [x] 2.2 R> ( -- x ) ( R: x -- )
  - [x] 2.3 R@ ( -- x ) ( R: x -- x )
- [x] Task 3: Implement memory access primitives in `src/memory.asm` (AC: #3)
  - [x] 3.1 @ ( addr -- x ) — fetch cell
  - [x] 3.2 ! ( x addr -- ) — store cell
  - [x] 3.3 C@ ( addr -- char ) — fetch byte
  - [x] 3.4 C! ( char addr -- ) — store byte
  - [x] 3.5 +! ( n addr -- ) — add n to cell at addr
- [x] Task 4: Implement dictionary space allocation in `src/memory.asm` (AC: #4)
  - [x] 4.1 HERE ( -- addr ) — push dictionary pointer from UserArea
  - [x] 4.2 ALLOT ( n -- ) — advance HERE by n
  - [x] 4.3 , (COMMA) ( x -- ) — compile cell at HERE, advance HERE by 2
  - [x] 4.4 C, ( char -- ) — compile byte at HERE, advance HERE by 1
  - [x] 4.5 ALIGN ( -- ) — align HERE to cell boundary (even address)
  - [x] 4.6 ALIGNED ( addr -- addr ) — return aligned address (round up to even)
- [x] Task 5: Implement bulk memory operations in `src/memory.asm` (AC: #5)
  - [x] 5.1 FILL ( addr u char -- ) — fill u bytes at addr with char
  - [x] 5.2 MOVE ( addr1 addr2 u -- ) — copy u bytes from addr1 to addr2, handling overlap correctly
- [x] Task 6: Create test threads and verify all primitives (AC: #1-5)
  - [x] 6.1 Add test threads to `antforth.asm` exercising each stack primitive with observable output via EMIT
  - [x] 6.2 Add test threads exercising return stack round-trip (>R / R> / R@)
  - [x] 6.3 Add test threads exercising memory store/fetch (@, !, C@, C!, +!)
  - [x] 6.4 Add test threads exercising HERE, ALLOT, COMMA, C,
  - [x] 6.5 Add test threads exercising FILL and MOVE
  - [x] 6.6 Update `make test` expected output to include new test characters
  - [x] 6.7 Verify all tests pass under iz-cpm

## Dev Notes

### What Already Exists (from Stories 1.1 and 1.2)

The following are already implemented and **must not be modified** unless there's a bug:

- **Inner interpreter** (`inner_interpreter.asm`): DOCOL, EXIT_CODE, LIT, BRANCH, ?BRANCH, EXECUTE — all working and tested
- **EMIT** (`io.asm`): Console output via BDOS C_WRITE — working, used for test observability
- **BYE** (`system.asm`): Clean exit to CP/M
- **NEXT/NEXTHL macros** (`macros.asm`): Threading dispatch. NEXTHL is the optimised form when HL already holds the updated IP
- **DEFCODE/DEFWORD/DEFIMMED macros** (`macros.asm`): Dictionary header construction with LUA-based XOR-rotate hash
- **BDOS_SAVE/BDOS_RESTORE** (`macros.asm`): Push DE+BC / Pop BC+DE around BDOS calls
- **Cold start** (`antforth.asm:18-68`): Full initialisation — SP, IX, IY, user variables, hash table pre-populated at assembly time
- **Constants** (`constants.asm`): PS_SIZE=256, RS_SIZE=256, HASH_BUCKETS=64, TIB_SIZE=128, PAD_OFFSET=84, F_IMMEDIATE=0x80, F_SMUDGE=0x40, F_LENMASK=0x1F, BDOS_ENTRY=0x0005, C_WRITE=2, P_TERMCPM=0
- **Structures** (`structures.asm`): UserArea (state, base, here, latest, tib_addr, tib_len, tib_in, source_id), DictEntry (hash_link, count_flags, name, code_field)

**Current test thread** (`antforth.asm:100-165`): Outputs "ABCDE" testing LIT, EMIT, DOCOL/EXIT, BRANCH, ?BRANCH, EXECUTE. This thread must be **extended** (not replaced) to add new primitive tests. Append new tests after the existing EXECUTE test but before the final BYE.

**Current binary size**: ~54 bytes (Story 1.1) + inner interpreter primitives. Will grow significantly with stack and memory primitives.

### Register Contract (Inviolable)

| Register | Role | CODE word rules |
|----------|------|----------------|
| BC | TOS | Contains TOS on entry; must contain new TOS on exit |
| DE | IP | Must be preserved — never use as scratch without save/restore |
| SP | Parameter stack | Second-of-stack and below. PUSH/POP for stack operations |
| IX | Return stack pointer | Preserve unless doing return stack operations (>R, R>, R@) |
| IY | User pointer | Points to UserArea struct. Preserve unless accessing user variables |
| HL | W (scratch) | Free within CODE words |
| AF | Scratch | Free within CODE words |

**Anti-pattern**: Any CODE word that modifies DE, IX, or IY without saving/restoring (unless that's the word's defined purpose).

### Implementation Guide — Stack Primitives

All stack primitives go in `src/stack_ops.asm`. Each word uses DEFCODE macro with `w_NAME:` label before and `w_NAME_cf:` label at the code field. End every CODE word with `NEXT`.

**TOS-in-BC convention**: The top of the parameter stack is always in BC, not on SP. Second-of-stack is at (SP). This means:
- DUP = PUSH BC (copy TOS to stack, BC unchanged)
- DROP = POP BC (load new TOS from stack)
- SWAP = POP HL / PUSH BC / LD B,H / LD C,L (or EX (SP),HL trick)

```z80
; -----------------------------------------------
; DUP ( x -- x x )
;   Duplicate top of stack
; -----------------------------------------------
w_DUP:
    DEFCODE "DUP", 0
w_DUP_cf:
    PUSH    BC              ; Push TOS copy to parameter stack
    NEXT                    ; BC (TOS) unchanged

; -----------------------------------------------
; DROP ( x -- )
;   Remove top of stack
; -----------------------------------------------
w_DROP:
    DEFCODE "DROP", 0
w_DROP_cf:
    POP     BC              ; Load new TOS from parameter stack
    NEXT

; -----------------------------------------------
; SWAP ( x1 x2 -- x2 x1 )
;   Exchange top two stack items
; -----------------------------------------------
w_SWAP:
    DEFCODE "SWAP", 0
w_SWAP_cf:
    POP     HL              ; HL = x1 (second on stack)
    PUSH    BC              ; Push x2 (old TOS) to stack
    LD      B, H
    LD      C, L            ; BC = x1 (new TOS)
    NEXT

; -----------------------------------------------
; OVER ( x1 x2 -- x1 x2 x1 )
;   Copy second item to top
; -----------------------------------------------
w_OVER:
    DEFCODE "OVER", 0
w_OVER_cf:
    POP     HL              ; HL = x1
    PUSH    HL              ; Restore x1 on stack
    PUSH    BC              ; Push x2 (old TOS)
    LD      B, H
    LD      C, L            ; BC = x1 (new TOS)
    NEXT

; -----------------------------------------------
; ROT ( x1 x2 x3 -- x2 x3 x1 )
;   Rotate third item to top
; -----------------------------------------------
w_ROT:
    DEFCODE "ROT", 0
w_ROT_cf:
    ; BC = x3 (TOS), (SP) = x2, (SP+2) = x1
    POP     HL              ; HL = x2
    EX      (SP), HL        ; HL = x1, (SP) = x2
    PUSH    BC              ; Push x3
    LD      B, H
    LD      C, L            ; BC = x1 (new TOS)
    NEXT
```

### PICK and ROLL — Indexed Stack Access

**PICK** ( xu ... x1 x0 u -- xu ... x1 x0 xu ): `0 PICK` = DUP, `1 PICK` = OVER. BC holds u. Calculate byte offset = u*2, index into SP. Note: SP points at second-of-stack (x0 is at SP+0 when u=0 means TOS which is BC).

Wait — per ANS: `0 PICK` is equivalent to DUP (copies TOS). TOS is in BC, so `0 PICK` means push BC and BC stays the same. For `1 PICK` (OVER), we need (SP+0). For `u PICK`, we need (SP + (u-1)*2). But since BC=TOS:
- u=0: result = BC (TOS) — just PUSH BC, BC unchanged
- u=1: result = (SP+0) — second on stack
- u=2: result = (SP+2) — third on stack
- u=n: result = (SP + (n-1)*2)

```z80
; PICK ( xu ... x1 x0 u -- xu ... x1 x0 xu )
w_PICK:
    DEFCODE "PICK", 0
w_PICK_cf:
    LD      H, B
    LD      L, C            ; HL = u
    ADD     HL, HL          ; HL = u * 2 (byte offset)
    ADD     HL, SP          ; HL = SP + u*2
    PUSH    BC              ; Save old TOS
    LD      C, (HL)
    INC     HL
    LD      B, (HL)         ; BC = value at stack position u
    NEXT
```

**Wait — correction**: When we ADD HL,SP, SP currently points at second-of-stack. So for u=0, we want TOS (BC). For u=1, we want (SP+0). The formula should be: address = SP + (u-1)*2 for u>=1, and BC for u=0. Alternatively, PUSH BC first to normalise the stack, then index at SP + u*2:

```z80
w_PICK:
    DEFCODE "PICK", 0
w_PICK_cf:
    LD      H, B
    LD      L, C            ; HL = u
    ADD     HL, HL          ; HL = u * 2
    ADD     HL, SP          ; HL points to xu on stack (after TOS is in BC, SP has x0..xu)
    LD      C, (HL)
    INC     HL
    LD      B, (HL)         ; BC = xu (new TOS, old TOS replaced)
    NEXT
```

Actually this is correct without the PUSH. Since BC=TOS and SP points at second-of-stack: SP+0 = x0 (which is "1 PICK"/OVER), SP+2 = next deeper. So SP + u*2 for u=0 gives SP+0 which is the second item — that's `1 PICK` semantics. We need to handle the off-by-one. The cleanest approach:

```z80
w_PICK:
    DEFCODE "PICK", 0
w_PICK_cf:
    ; u is in BC. Push TOS to normalise stack, then index.
    PUSH    BC              ; Stack now: x0 x1 ... xu ... (all on SP)
    LD      H, B
    LD      L, C            ; HL = u
    ADD     HL, HL          ; HL = u * 2
    ADD     HL, SP          ; HL = &stack[u]
    LD      C, (HL)
    INC     HL
    LD      B, (HL)         ; BC = xu
    ; Remove the pushed copy: we need to "unpush" but leave BC as new TOS
    ; Actually we want: push BC replaced TOS on stack. But now BC=xu.
    ; Stack has one extra value. Pop it to discard old u.
    INC     SP              ; Discard the pushed u (2 bytes)
    INC     SP
    NEXT
```

Hmm, this is getting fiddly. The cleanest approach for PICK with TOS-in-register:

```z80
w_PICK:
    DEFCODE "PICK", 0
w_PICK_cf:
    ; BC = u (index). 0 PICK = DUP (return TOS)
    ; Stack: ... xu ... x1 x0 <SP>  (TOS = u in BC)
    ; We want xu. x0 is at (SP), x1 at (SP+2), xu at (SP + u*2)
    ; But wait, before PICK runs, the stack is: xu...x0 u
    ; With TOS-in-BC: BC=u, SP points to x0.
    ; 0 PICK wants x0 which = DUP of what's below u... no.
    ; ANS: "0 PICK is equivalent to DUP" — DUP copies TOS.
    ; But TOS is u itself... No. PICK consumes u.
    ; The stack before PICK: xu ... x1 x0 u
    ; BC=u. (SP)=x0, (SP+2)=x1, ... (SP+u*2)=xu
    ; Result: xu ... x1 x0 xu (u consumed, xu pushed as TOS)
    LD      H, B
    LD      L, C            ; HL = u
    ADD     HL, HL          ; HL = u * 2
    ADD     HL, SP          ; HL = SP + u*2 = address of xu
    LD      C, (HL)
    INC     HL
    LD      B, (HL)         ; BC = xu (replaces u as TOS)
    NEXT
```

This is correct. u is consumed (overwritten by xu in BC). `0 PICK`: HL=0, ADD HL,SP = SP, reads (SP) = x0 — but `0 PICK` should be DUP which returns the current TOS... Wait. Let me re-read ANS. Before PICK executes, the stack is `xu ... x1 x0 u`. With TOS-in-BC, BC=u and SP points to x0. After PICK, the stack should be `xu ... x1 x0 xu`. For `0 PICK`, the stack before is `x0 0`, so BC=0, SP points to x0. We want result x0 in BC. HL=0, ADD HL,SP=SP, read (SP)=x0 into BC. Correct! For `1 PICK` (= OVER), stack before is `x1 x0 1`. BC=1, SP points to x0 (at SP+0), x1 at SP+2. HL=2, ADD HL,SP = SP+2, read x1. Correct!

**ROLL** is more complex — it requires shifting stack elements. It can be implemented with a loop.

**DEPTH** needs to know the initial SP value (parameter stack base). This is stored implicitly — it's the BDOS address read at cold start. Store it in a known location or compute from the UserArea.

**Important**: The initial SP value (stack base) must be accessible for DEPTH. Options:
1. Store initial SP in a user variable or known memory location during cold start
2. Compute from BDOS address pointer (re-read 0x0006)

Option 2 is simplest — BDOS address doesn't change. DEPTH = (BDOS_addr - SP) / 2, but we also need to account for TOS being in BC (+1 if stack is non-empty). Actually: after cold start, SP = BDOS_addr. Each PUSH decrements SP by 2. Number of items on SP = (initial_SP - current_SP) / 2. Total stack depth = items_on_SP + 1 (for TOS in BC). But if stack is empty (SP = initial), then depth should be 0... except there's no clean way to know if BC holds a valid TOS. In practice, DEPTH is called when there's at least DEPTH's own expectations. Standard approach: depth = (SP_base - SP) / 2 + 1 if we always count TOS. Hmm, but right after cold start before anything is pushed, SP = base and BC is garbage. This needs care.

**Pragmatic approach**: Store SP_base during cold start. DEPTH = (SP_base - SP) / 2. This counts only items on the hardware stack (not TOS in BC). But ANS DEPTH includes TOS. So if any items exist, add 1. The issue is distinguishing "empty stack" from "one item". Standard Forth convention: after cold start, depth is 0 and BC is undefined. First LIT puts something in BC and doesn't push to SP, so depth should be 1 but (SP_base - SP)/2 = 0. The fix: DEPTH = (SP_base - SP) / 2 + 1... but that gives 1 when stack is empty.

**Best approach**: Initialise SP to SP_base - 2 (one slot below base) during cold start, effectively "pre-pushing" a dummy. Then DEPTH = (SP_base - SP) / 2 always works including TOS. Actually simpler: just always count TOS. DEPTH = (SP_base - SP) / 2 + 1 if anything has been pushed. But we can't distinguish.

**Simplest correct approach**: Store `sp_base` during cold start. DEPTH = (sp_base - SP) / 2. This gives the number of items below TOS. Since DEPTH itself pushes a result (the count), the caller can rely on this. Actually... let's just follow what other TOS-in-register Forths do: **DEPTH pushes BC (old TOS), then computes (sp_base - SP) / 2, loads result into BC**. This way the count includes everything that was on the stack before DEPTH ran.

```z80
w_DEPTH:
    DEFCODE "DEPTH", 0
w_DEPTH_cf:
    PUSH    BC              ; Save TOS — now full stack is on SP
    LD      HL, (sp_base)   ; HL = initial SP value
    OR      A               ; Clear carry
    SBC     HL, SP          ; HL = sp_base - SP (bytes used)
    SRL     H
    RR      L               ; HL = HL / 2 (number of cells)
    LD      B, H
    LD      C, L            ; BC = depth (new TOS)
    NEXT
```

**Requirement**: Add `sp_base` storage. During cold start, after setting SP, store SP value: `LD (sp_base), SP` (note: Z80 has `LD (nn), SP` instruction). Reserve 2 bytes for `sp_base` in the runtime data area.

### Implementation Guide — Return Stack Primitives

```z80
; -----------------------------------------------
; >R ( x -- ) ( R: -- x )
;   Move top of parameter stack to return stack
; -----------------------------------------------
w_TO_R:
    DEFCODE ">R", 0
w_TO_R_cf:
    DEC     IX              ; Grow return stack
    DEC     IX
    LD      (IX+1), B       ; Store high byte
    LD      (IX+0), C       ; Store low byte
    POP     BC              ; New TOS from parameter stack
    NEXT

; -----------------------------------------------
; R> ( -- x ) ( R: x -- )
;   Move top of return stack to parameter stack
; -----------------------------------------------
w_R_FROM:
    DEFCODE "R>", 0
w_R_FROM_cf:
    PUSH    BC              ; Save current TOS
    LD      C, (IX+0)       ; Low byte
    LD      B, (IX+1)       ; High byte
    INC     IX              ; Shrink return stack
    INC     IX
    NEXT

; -----------------------------------------------
; R@ ( -- x ) ( R: x -- x )
;   Copy top of return stack to parameter stack
; -----------------------------------------------
w_R_FETCH:
    DEFCODE "R@", 0
w_R_FETCH_cf:
    PUSH    BC              ; Save current TOS
    LD      C, (IX+0)
    LD      B, (IX+1)       ; BC = top of return stack (copied, not removed)
    NEXT
```

**Critical warning for >R/R>**: These manipulate IX (return stack pointer). This is their defined purpose — the register contract explicitly allows this. However, >R and R> must ALWAYS be used in matched pairs within a single definition, or the return stack will be corrupted and EXIT will jump to garbage.

### Implementation Guide — Memory Primitives

```z80
; -----------------------------------------------
; @ ( addr -- x )
;   Fetch cell from memory
; -----------------------------------------------
w_FETCH:
    DEFCODE "@", 0
w_FETCH_cf:
    LD      H, B
    LD      L, C            ; HL = addr
    LD      C, (HL)
    INC     HL
    LD      B, (HL)         ; BC = cell at addr (little-endian)
    NEXT

; -----------------------------------------------
; ! ( x addr -- )
;   Store cell to memory
; -----------------------------------------------
w_STORE:
    DEFCODE "!", 0
w_STORE_cf:
    LD      H, B
    LD      L, C            ; HL = addr (TOS)
    POP     BC              ; BC = x (value to store)... wait, we need to store x then pop new TOS
    ; Actually: TOS = addr (BC), second = x. We store x at addr, then pop new TOS.
    ; But after POP BC, BC = x and we've lost addr. Need to save addr first.
    ; Correction:
    LD      H, B
    LD      L, C            ; HL = addr
    POP     BC              ; BC = x (value)
    LD      (HL), C
    INC     HL
    LD      (HL), B         ; Store x at addr (little-endian)
    POP     BC              ; New TOS (! consumes both items)
    NEXT

; -----------------------------------------------
; C@ ( addr -- char )
;   Fetch byte from memory
; -----------------------------------------------
w_C_FETCH:
    DEFCODE "C@", 0
w_C_FETCH_cf:
    LD      H, B
    LD      L, C            ; HL = addr
    LD      C, (HL)         ; C = byte
    LD      B, 0            ; Zero-extend to cell
    NEXT

; -----------------------------------------------
; C! ( char addr -- )
;   Store byte to memory
; -----------------------------------------------
w_C_STORE:
    DEFCODE "C!", 0
w_C_STORE_cf:
    LD      H, B
    LD      L, C            ; HL = addr
    POP     BC              ; BC = char
    LD      (HL), C         ; Store low byte only
    POP     BC              ; New TOS
    NEXT

; -----------------------------------------------
; +! ( n addr -- )
;   Add n to cell at addr
; -----------------------------------------------
w_PLUS_STORE:
    DEFCODE "+!", 0
w_PLUS_STORE_cf:
    LD      H, B
    LD      L, C            ; HL = addr
    POP     BC              ; BC = n
    LD      A, (HL)
    ADD     A, C
    LD      (HL), A         ; Low byte
    INC     HL
    LD      A, (HL)
    ADC     A, B
    LD      (HL), A         ; High byte (with carry)
    POP     BC              ; New TOS
    NEXT
```

### Implementation Guide — Dictionary Space Allocation

HERE and ALLOT access `UserArea.here` via IY:

```z80
; -----------------------------------------------
; HERE ( -- addr )
;   Push current dictionary pointer
; -----------------------------------------------
w_HERE:
    DEFCODE "HERE", 0
w_HERE_cf:
    PUSH    BC              ; Save old TOS
    LD      C, (IY+UserArea.here)
    LD      B, (IY+UserArea.here+1)   ; BC = HERE value
    NEXT

; -----------------------------------------------
; ALLOT ( n -- )
;   Advance HERE by n bytes
; -----------------------------------------------
w_ALLOT:
    DEFCODE "ALLOT", 0
w_ALLOT_cf:
    LD      L, (IY+UserArea.here)
    LD      H, (IY+UserArea.here+1)   ; HL = current HERE
    ADD     HL, BC                     ; HL = HERE + n
    LD      (IY+UserArea.here), L
    LD      (IY+UserArea.here+1), H
    POP     BC              ; New TOS (n consumed)
    NEXT

; -----------------------------------------------
; , (COMMA) ( x -- )
;   Compile cell at HERE, advance HERE by 2
; -----------------------------------------------
w_COMMA:
    DEFCODE ",", 0
w_COMMA_cf:
    LD      L, (IY+UserArea.here)
    LD      H, (IY+UserArea.here+1)   ; HL = HERE
    LD      (HL), C
    INC     HL
    LD      (HL), B         ; Store cell (little-endian)
    INC     HL              ; HL = HERE + 2
    LD      (IY+UserArea.here), L
    LD      (IY+UserArea.here+1), H
    POP     BC              ; New TOS
    NEXT

; -----------------------------------------------
; C, ( char -- )
;   Compile byte at HERE, advance HERE by 1
; -----------------------------------------------
w_C_COMMA:
    DEFCODE "C,", 0
w_C_COMMA_cf:
    LD      L, (IY+UserArea.here)
    LD      H, (IY+UserArea.here+1)
    LD      (HL), C         ; Store byte
    INC     HL              ; HERE + 1
    LD      (IY+UserArea.here), L
    LD      (IY+UserArea.here+1), H
    POP     BC              ; New TOS
    NEXT
```

### ALIGN and ALIGNED

On Z80, cell size is 2 bytes. ALIGN ensures HERE is even-aligned. ALIGNED rounds an address up to cell alignment.

```z80
; -----------------------------------------------
; ALIGN ( -- )
;   Align HERE to cell boundary (even address)
; -----------------------------------------------
w_ALIGN:
    DEFCODE "ALIGN", 0
w_ALIGN_cf:
    LD      L, (IY+UserArea.here)
    LD      H, (IY+UserArea.here+1)
    BIT     0, L            ; Test if odd
    JR      Z, .already_aligned
    INC     HL              ; Round up to even
    LD      (IY+UserArea.here), L
    LD      (IY+UserArea.here+1), H
.already_aligned:
    NEXT

; -----------------------------------------------
; ALIGNED ( addr -- addr' )
;   Round address up to cell alignment
; -----------------------------------------------
w_ALIGNED:
    DEFCODE "ALIGNED", 0
w_ALIGNED_cf:
    BIT     0, C            ; Test if addr is odd
    JR      Z, .ok
    INC     BC              ; Round up
.ok:
    NEXT
```

### FILL and MOVE — Bulk Memory Operations

FILL and MOVE are performance-sensitive (architecture says "should be CODE"). Use Z80 block instructions (LDIR, LDDR) for efficiency.

```z80
; -----------------------------------------------
; FILL ( addr u char -- )
;   Fill u bytes starting at addr with char
; -----------------------------------------------
w_FILL:
    DEFCODE "FILL", 0
w_FILL_cf:
    ; BC = char (TOS), (SP) = u, (SP+2) = addr
    LD      A, C            ; A = fill byte
    POP     BC              ; BC = u (count)
    POP     HL              ; HL = addr (destination)
    ; Handle u=0 case
    LD      D, B
    LD      E, C            ; DE = u (save count)
    LD      A, B
    OR      C
    JR      Z, .fill_done   ; If count=0, skip
    LD      A, E            ; Restore fill byte... wait, we lost it
    ; Redo: save char first
    ; Let me restructure:
    POP     DE              ; DE = u
    POP     HL              ; HL = addr
    ; BC still has char (nope, we popped it)
    ; Need to rethink register allocation
    NEXT
```

**Corrected FILL** — careful register management:

```z80
w_FILL:
    DEFCODE "FILL", 0
w_FILL_cf:
    ; Stack: addr u char  (BC=char=TOS)
    LD      A, C            ; A = fill byte (save before popping)
    POP     HL              ; HL = u (count) — was second on stack
    POP     DE              ; DE = addr — was third on stack
    ; Now: A=char, HL=count, DE=addr
    LD      B, H
    LD      C, L            ; BC = count
    LD      H, D
    LD      L, E            ; HL = addr
    ; Check count > 0
    LD      D, B
    OR      C               ; Oops, wrong test. Use:
    LD      A, B
    OR      C
    JR      Z, .fill_done
    LD      (HL), A         ; Hmm, A was clobbered. Need char back.
```

This is getting tangled. Let me provide the correct implementation cleanly:

```z80
w_FILL:
    DEFCODE "FILL", 0
w_FILL_cf:
    ; Stack: addr u char   BC=char(TOS)
    PUSH    BC              ; Save char on stack temporarily
    POP     AF              ; A = char (low byte of BC = C, but POP AF puts C->F, B->A)
    ; Actually POP AF: F = low byte (C), A = high byte (B). That's wrong for char.
    ; Use LD A,C instead:
    LD      A, C            ; A = char
    POP     BC              ; BC = u (count)
    POP     HL              ; HL = addr
    OR      A               ; (doesn't help, need to test BC=0)
    LD      E, A            ; E = char (save)
    LD      A, B
    OR      C
    JR      Z, .fill_done   ; count = 0, skip
    LD      (HL), E         ; Store first byte
    LD      D, H
    LD      E, L            ; DE = addr (source for LDIR)
    INC     DE              ; DE = addr+1 (destination)
    DEC     BC              ; BC = count-1 (remaining)
    LD      A, B
    OR      C
    JR      Z, .fill_done   ; count was 1, done
    LDIR                    ; Copy (HL)→(DE), BC times: propagates fill byte
.fill_done:
    POP     BC              ; New TOS
    NEXT
```

**MOVE** — must handle overlapping regions. If addr2 > addr1, copy backwards (LDDR). If addr2 <= addr1, copy forwards (LDIR). ANS MOVE specifies correct overlap handling.

```z80
w_MOVE:
    DEFCODE "MOVE", 0
w_MOVE_cf:
    ; Stack: addr1 addr2 u   BC=u(TOS)
    ; MOVE copies u address units from addr1 to addr2
    LD      A, B
    OR      C
    JR      Z, .move_zero   ; u=0, nothing to do
    POP     DE              ; DE = addr2 (destination)
    POP     HL              ; HL = addr1 (source)
    ; Determine direction: if DE > HL, copy backwards
    PUSH    HL
    OR      A               ; Clear carry
    SBC     HL, DE          ; HL = addr1 - addr2
    POP     HL              ; Restore HL = addr1
    JR      NC, .move_fwd   ; addr1 >= addr2: forward copy is safe
    ; Backward copy: start from end
    ADD     HL, BC
    DEC     HL              ; HL = addr1 + u - 1 (last source byte)
    EX      DE, HL          ; DE = last source, HL = addr2
    ADD     HL, BC
    DEC     HL              ; HL = addr2 + u - 1 (last dest byte)
    EX      DE, HL          ; HL = last source, DE = last dest
    LDDR                    ; Copy backwards
    JR      .move_done
.move_fwd:
    LDIR                    ; Copy forwards
    JR      .move_done
.move_zero:
    POP     DE              ; Discard addr2
    POP     HL              ; Discard addr1
.move_done:
    POP     BC              ; New TOS
    NEXT
```

### ROLL Implementation

ROLL is the most complex stack primitive. `u ROLL` rotates the u-th item to TOS. `1 ROLL` = SWAP, `2 ROLL` = ROT.

```z80
w_ROLL:
    DEFCODE "ROLL", 0
w_ROLL_cf:
    ; BC = u. 0 ROLL = no-op. 1 ROLL = SWAP. 2 ROLL = ROT.
    LD      A, B
    OR      C
    JR      Z, .roll_done   ; 0 ROLL: no-op
    ; Save u, get the u-th item, shift stack down
    LD      H, B
    LD      L, C            ; HL = u
    ADD     HL, HL          ; HL = u * 2 (byte offset)
    ADD     HL, SP          ; HL = address of xu on stack
    ; Read xu
    LD      E, (HL)
    INC     HL
    LD      D, (HL)         ; DE = xu (the item to bring to top)... but DE is IP!
    ; PROBLEM: DE is the instruction pointer. Cannot use DE as scratch.
    ; Must save DE first.
    ; Restructure using different registers:
    ; Save IP
    PUSH    DE              ; Save IP on parameter stack temporarily
    ; Recalculate: now SP has shifted by 2
    LD      H, B
    LD      L, C            ; HL = u
    ADD     HL, HL          ; HL = u * 2
    ADD     HL, SP          ; HL = address of xu (accounting for pushed IP)
    INC     HL
    INC     HL              ; Skip over the saved IP
    ; Wait, this is getting complicated. Let me use a different approach.
    ; Store IP to a temp variable instead of pushing.
    POP     DE              ; Restore IP (undo the push)

    ; Alternative: use IX-indexed temp storage? No, IX is return stack.
    ; Use IY-indexed? We could use a scratch field in UserArea.
    ; Or: use the return stack to save IP.
    DEC     IX
    DEC     IX
    LD      (IX+0), E
    LD      (IX+1), D       ; Save IP to return stack

    LD      H, B
    LD      L, C            ; HL = u
    ADD     HL, HL          ; HL = u*2
    ADD     HL, SP          ; HL = &stack[u] (xu)
    ; Read xu into DE
    LD      E, (HL)
    INC     HL
    LD      D, (HL)         ; DE = xu
    ; Now shift items up: move stack[u-1] to stack[u], ..., stack[0] to stack[1]
    ; HL points to high byte of xu. We need to shift downward in memory (toward higher addresses)
    ; Source: HL-2 (xu-1), Dest: HL (xu), count: u-1 words = (u-1)*2 bytes
    ; Use LDDR: copy from lower to higher addresses
    DEC     HL              ; HL = &xu (low byte)
    LD      B, C            ; Save u low byte... wait, BC = u still.
    ; BC = u, we need count = u*2 bytes, source = HL - u*2, dest = HL
    ; Actually: we want to shift the block [x0, x1, ..., xu-1] up by one cell
    ; That means copy from (SP) to (SP+2), count = u*2 bytes, backwards
    ; Easier with a loop:
    PUSH    DE              ; Save xu on stack temporarily
    ; Now shift: for i = u-1 downto 0, stack[i+1] = stack[i]
    ; HL currently points to the slot where xu was (we want to fill toward SP)
    ; Let me use a simpler loop approach:
    LD      H, B
    LD      L, C            ; HL = u (loop counter)
    ; Build source pointer: SP + (u-1)*2 ... but SP moved because of PUSH DE
    ; This is getting unwieldy. ROLL with TOS-in-register on Z80 is inherently messy.
    ; ... (implementation continues in actual dev work)
    POP     DE              ; Retrieve xu
    ; Restore IP from return stack
    LD      E_temp, (IX+0)
    LD      D_temp, (IX+1)
    INC     IX
    INC     IX
    ; Set BC = xu (new TOS)
    LD      B, D
    LD      C, E
.roll_done:
    NEXT
```

**Dev agent note on ROLL**: This is the hardest primitive to implement with TOS-in-register. The implementation above is a sketch — the dev agent should implement it carefully with a loop, saving IP to the return stack for the duration. A correct approach:

1. Save IP (DE) to return stack
2. Read the u-th item from the parameter stack into a temp register pair
3. Use a loop to shift stack items: for i = u down to 1, copy stack[i-1] to stack[i]
4. Write the saved value as new TOS (BC)
5. Restore IP from return stack
6. NEXT

### SP@ / SP! / RP@ / RP!

These are system words for stack pointer access:

```z80
; SP@ ( -- addr ) — return current stack pointer
w_SP_FETCH:
    DEFCODE "SP@", 0
w_SP_FETCH_cf:
    PUSH    BC
    LD      HL, 0
    ADD     HL, SP          ; HL = SP (Z80 has no LD HL,SP; use ADD)
    LD      B, H
    LD      C, L
    NEXT

; SP! ( addr -- ) — set stack pointer
w_SP_STORE:
    DEFCODE "SP!", 0
w_SP_STORE_cf:
    LD      H, B
    LD      L, C
    LD      SP, HL
    POP     BC              ; New TOS from new stack position
    NEXT

; RP@ ( -- addr ) — return stack pointer
w_RP_FETCH:
    DEFCODE "RP@", 0
w_RP_FETCH_cf:
    PUSH    BC
    PUSH    IX
    POP     BC              ; BC = IX (return stack pointer)
    NEXT

; RP! ( addr -- ) — set return stack pointer
w_RP_STORE:
    DEFCODE "RP!", 0
w_RP_STORE_cf:
    PUSH    BC
    POP     IX              ; IX = addr
    POP     BC              ; New TOS
    NEXT
```

### Cold Start Modification Required

Add `sp_base` storage for DEPTH. During cold start in `antforth.asm`, after setting SP:

```z80
    LD      (sp_base), SP   ; Z80 supports LD (nn),SP directly? No — LD (nn),SP is not a Z80 instruction.
    ; Use: LD HL,0 / ADD HL,SP / LD (sp_base),HL
    LD      HL, 0
    ADD     HL, SP
    LD      (sp_base), HL   ; Store initial SP for DEPTH calculation
```

Reserve in runtime data area:
```
sp_base:    DW 0            ; Initial SP value, set during cold start
```

### Testing Strategy

Since the outer interpreter doesn't exist yet, all testing continues via hardcoded threads in `antforth.asm`. Extend the existing test thread (currently outputs "ABCDE") to also test new primitives.

**Test approach**: Each test outputs a known character on success. The `make test` expected string grows with each story. Use single-character codes to keep tests compact.

**Suggested test sequence** (appended after existing "ABCDE"):

- 'F' — DUP test: LIT 'F', DUP, DROP, EMIT (DUP then DROP should leave original, EMIT outputs 'F')
- 'G' — SWAP test: LIT 'X', LIT 'G', SWAP, DROP, EMIT (SWAP brings 'G' under 'X', DROP 'X', EMIT 'G')
- 'H' — OVER test: LIT 'H', LIT 0, OVER, EMIT, DROP, DROP (OVER copies 'H' over 0, EMIT it)
- 'I' — >R/R> test: LIT 'I', >R, R>, EMIT (round-trip through return stack)
- 'J' — @ and ! test: LIT 'J', LIT test_cell, !, LIT test_cell, @, EMIT (store and fetch)
- 'K' — +! test: LIT 1, LIT test_cell2, !, LIT 74, LIT test_cell2, +!, LIT test_cell2, @, EMIT (1+74=75='K')
- 'L' — HERE test: HERE, DROP, LIT 'L', EMIT (just verify HERE doesn't crash, output 'L')
- 'M' — DEPTH test: LIT 1, LIT 2, DEPTH, EMIT_as_char, ... (verify depth=3 then clean up... simpler: just output 'M' after a DEPTH/DROP sequence)

**Reserve test memory cells** in the data area:
```
test_cell:  DW 0
test_cell2: DW 0
```

**Expected make test output**: "ABCDEFGHIJKLM" (or similar — extend as needed during implementation)

### Naming Convention Reminders

- Word labels: `w_DUP`, `w_DROP`, `w_SWAP`, etc.
- Code field labels: `w_DUP_cf`, `w_DROP_cf`, etc.
- Special char mapping: `w_FETCH` (@), `w_STORE` (!), `w_C_FETCH` (C@), `w_C_STORE` (C!), `w_PLUS_STORE` (+!), `w_TO_R` (>R), `w_R_FROM` (R>), `w_R_FETCH` (R@), `w_COMMA` (,), `w_C_COMMA` (C,)
- File header comment block is mandatory per architecture spec

### Project Structure Notes

- **`src/stack_ops.asm`**: All parameter stack operations (DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH, SP@, SP!, RP@, RP!) plus return stack operations (>R, R>, R@)
- **`src/memory.asm`**: All memory access (@, !, C@, C!, +!), dictionary allocation (HERE, ALLOT, COMMA, C,, ALIGN, ALIGNED), and bulk operations (FILL, MOVE)
- **`src/antforth.asm`**: Extended test threads, `sp_base` storage, `test_cell`/`test_cell2` in runtime data area
- **`src/constants.asm`**: No new constants expected (existing ones are sufficient)
- No new source files needed — all work goes into existing stubs

### Previous Story Intelligence

**From Story 1.2 (Inner Interpreter & Threading):**

- **Label convention confirmed**: `w_NAME:` before DEFCODE, `w_NAME_cf:` after code field entry. The `_cf` suffix is the established project convention because sjasmplus `.code_field` local labels are not accessible externally.
- **NEXTHL optimisation**: Any CODE word where HL already contains the updated IP should use NEXTHL instead of NEXT. For stack/memory primitives, most will use plain NEXT since they don't manipulate IP.
- **BDOS_SAVE/BDOS_RESTORE**: Pushes DE then BC / Pops BC then DE. Only needed for words that call BDOS (not applicable to stack/memory primitives in this story).
- **iz-cpm test pattern**: Test threads output known characters, `make test` pipes output and validates expected string. Current expected output is "ABCDE".
- **sjasmplus quirks**: `sj.insert_label` (not `sj.add_label`), `#name` for string length in LUA, `--raw` flag for binary output.
- **Cold start already initialises**: SP, IX, IY, STATE, BASE, HERE, TIB, >IN, hash table. Story 1.3 needs to add `sp_base` storage after SP initialisation.

**From Story 1.2 debug log:**
- `.code_field` local labels not accessible externally — use explicit `w_NAME_cf` global labels
- Branch offsets are relative to the offset cell address itself
- DEFWORD generates JP DOCOL + body; reference the code field address in threads
- CR/LF from iz-cpm can cause test string mismatch — keep test output clean

### Git Intelligence

**Recent commits (most recent first):**
1. `7891f46` — implement inner interpreter and threading (story 1-2): Full cold start, LIT, BRANCH, ?BRANCH, EXECUTE, EMIT, comprehensive test thread
2. `55e9474` — add NEXTHL optimisation: Split NEXT into EX DE,HL + NEXTHL for cases where HL already holds IP
3. `67b7527` — initial project scaffolding: Full Story 1.1

**Patterns to follow:**
- Commit messages are descriptive, reference story number
- Each story produces a working, testable binary
- Code review fixes are applied in the same story commit

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3] — acceptance criteria, user story, stack effect specifications
- [Source: _bmad-output/planning-artifacts/architecture.md#Register Usage Discipline] — register contract table, anti-patterns
- [Source: _bmad-output/planning-artifacts/architecture.md#Kernel/Forth Boundary] — all stack/memory words listed as CODE primitives
- [Source: _bmad-output/planning-artifacts/architecture.md#Naming Patterns] — w_ prefix, special character mapping, label conventions
- [Source: _bmad-output/planning-artifacts/architecture.md#Comment Conventions] — mandatory stack effect + description for every word
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns] — DEFCODE usage, NEXT termination rule
- [Source: _bmad-output/planning-artifacts/architecture.md#Memory Layout] — parameter stack at TPA top, return stack below, HERE grows upward
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure] — stack_ops.asm and memory.asm file locations
- [Source: _bmad-output/implementation-artifacts/1-2-inner-interpreter-and-threading.md] — previous story learnings, existing code state, label conventions, NEXTHL pattern

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- FILL and MOVE initially clobbered DE (IP register) by using `POP DE` for addr without saving IP first. Fixed by saving/restoring IP via the return stack (IX), following the same pattern used by ROLL.

### Completion Notes List

- Implemented 12 parameter stack primitives (DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH, SP@, SP!, RP@, RP!) in `src/stack_ops.asm`
- Implemented 3 return stack primitives (>R, R>, R@) in `src/stack_ops.asm`
- Implemented 5 memory access primitives (@, !, C@, C!, +!) in `src/memory.asm`
- Implemented 6 dictionary allocation primitives (HERE, ALLOT, COMMA, C,, ALIGN, ALIGNED) in `src/memory.asm`
- Implemented 2 bulk memory operations (FILL, MOVE) in `src/memory.asm` with LDIR/LDDR optimisation
- Added `sp_base` storage to cold start for DEPTH calculation
- Added `test_cell` and `test_cell2` scratch memory in runtime data area
- Extended test thread from "ABCDE" to "ABCDEFGHIJKLMNOPQRSTUVWXYZ" (21 new test cases covering all primitives)
- All primitives follow the register contract: BC=TOS, DE=IP preserved, IX=return stack, IY=user pointer
- ROLL uses return stack to save IP since it needs DE for scratch — correct approach per register contract

### Change Log

- 2026-04-03: Implemented all stack, return stack, memory, dictionary, and bulk memory primitives (Story 1.3)
- 2026-04-03: Code review fixes — added 10 missing test threads (PICK, ROLL, DEPTH, COMMA, ALLOT, C,, ALIGNED, MOVE, SP@, RP@), cleaned up ROLL dead code and comments, fixed misleading test comment

### Senior Developer Review (AI)

**Review Date:** 2026-04-03
**Reviewer:** Claude Opus 4.6

**Findings fixed:**
- H1-H4: Added missing test threads for PICK, ROLL, DEPTH, ALLOT, COMMA, C,, ALIGNED, MOVE, SP@, RP@ (tests Q-Z)
- M1: Removed dead code in ROLL (lines that computed HL/DE values immediately overwritten)
- M2: Fixed orphaned "Test 6: EXECUTE" comment referencing nonexistent test_emit_F
- L2: Replaced ROLL development-process comments with clean algorithm description
- Updated expected output from "ABCDEFGHIJKLMNOP" to "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
- All 26 tests pass under iz-cpm

**Not fixed (accepted):**
- L1: File header format uses project-established convention (differs from architecture spec example but consistent with all other source files)
- M3: sprint-status.yaml not in File List (standard workflow artifact, not application code)

### File List

- `src/stack_ops.asm` — New: all parameter/return stack primitives (was stub); ROLL dead code cleaned up
- `src/memory.asm` — New: all memory/dictionary/bulk primitives (was stub)
- `src/antforth.asm` — Modified: added sp_base storage in cold start, test_cell/test_cell2 in data area, extended test thread with 21 new tests (A-Z), fixed misleading comments
- `Makefile` — Modified: updated expected test output from "ABCDE" to "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
