# Story 2.2: Outer Interpreter & REPL Loop

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to type expressions at a prompt and see them execute,
so that I can interact with the system in real time.

## Acceptance Criteria

1. **Given** antforth boots on iz-cpm or MicroBeast **When** the cold start completes and QUIT enters the outer interpreter loop **Then** the system displays the ` ok` prompt and waits for input

2. **Given** the system is at the `ok` prompt **When** the user types a line of text and presses Enter **Then** ACCEPT fills the TIB via BDOS C_READSTR and sets >IN to 0

3. **Given** input text in the TIB **When** WORD parses the next whitespace-delimited token **Then** it advances >IN past the token and stores the counted string at HERE

4. **Given** a parsed token that matches a dictionary word (e.g., "DUP") **When** INTERPRET processes it in interpret mode (STATE=0) **Then** the word is executed immediately

5. **Given** a parsed token that does NOT match a dictionary word **When** INTERPRET attempts number conversion via >NUMBER **Then** if the token is a valid number in the current BASE, it is pushed to the parameter stack **And** if the token is neither a word nor a valid number, an error is raised

6. **Given** the user types `65 EMIT` **When** the line is interpreted **Then** 65 is pushed to the stack, EMIT executes outputting `A`, and ` ok` is displayed on the next line — **Note:** The full AC from epics (`2 3 + .`) requires `.` from Story 2.3; test with EMIT for this story

7. **Given** all tokens on a line have been processed **When** INTERPRET reaches the end of the input **Then** ` ok` is printed (in interpret mode) followed by CR, and the system waits for the next line

## Tasks / Subtasks

- [x] Task 1: Add constants and data areas (AC: supports all)
  - [x] 1.1 Add `C_READSTR = 10` to `src/constants.asm`
  - [x] 1.2 Add `rp_base: DW 0` to data area in `src/antforth.asm` (store initial IX during cold_start, like sp_base)
  - [x] 1.3 Add `bdos_input_buf: DS 1` and `bdos_input_len: DS 1` immediately before `tib_buffer` in `src/antforth.asm`
  - [x] 1.4 Add `str_ok: DB " ok"` and `STR_OK_LEN EQU 3` to data area
  - [x] 1.5 Store IX to `(rp_base)` during cold_start, after IX is initialised

- [x] Task 2: Implement user variable access words in `src/outer_interpreter.asm` (AC: supports all)
  - [x] 2.1 Implement `push_user_var` internal helper — shared by all user variable words
  - [x] 2.2 STATE ( -- addr ), BASE ( -- addr ), >IN ( -- addr ), #TIB ( -- addr )
  - [x] 2.3 SOURCE ( -- c-addr u ) — push TIB address and current input length
  - [x] 2.4 BL ( -- char ) — push space character 0x20

- [x] Task 3: Implement ACCEPT in `src/io.asm` (AC: #2)
  - [x] 3.1 ACCEPT ( c-addr +n1 -- +n2 ) — CODE word via DEFCODE
  - [x] 3.2 Use BDOS function 10 (C_READSTR) with `bdos_input_buf` header
  - [x] 3.3 Emit LF after BDOS returns (BDOS 10 echoes CR but not LF)
  - [x] 3.4 Return actual character count

- [x] Task 4: Implement WORD in `src/strings.asm` (AC: #3)
  - [x] 4.1 WORD ( char -- c-addr ) — CODE word via DEFCODE
  - [x] 4.2 Skip leading delimiters, copy token to HERE as counted string
  - [x] 4.3 Advance >IN past parsed token

- [x] Task 5: Implement >NUMBER and NUMBER? in `src/strings.asm` (AC: #5)
  - [x] 5.1 >NUMBER ( ud1 c-addr1 u1 -- ud2 c-addr2 u2 ) — CODE word
  - [x] 5.2 NUMBER? ( c-addr -- n true | c-addr false ) — CODE word (helper for INTERPRET)
  - [x] 5.3 Handle leading `-` for negative numbers in NUMBER?

- [x] Task 6: Implement INTERPRET as DEFWORD in `src/outer_interpreter.asm` (AC: #4, #5, #7)
  - [x] 6.1 INTERPRET — DEFWORD with manual BRANCH/?BRANCH offsets
  - [x] 6.2 Loop: BL WORD, check empty, FIND, execute-or-number, error-or-continue

- [x] Task 7: Implement ABORT and QUIT (AC: #1, #7)
  - [x] 7.1 ABORT — CODE word in `src/system.asm`: reset SP, JP to QUIT
  - [x] 7.2 QUIT — CODE word in `src/outer_interpreter.asm`: reset IX + STATE, enter threaded loop
  - [x] 7.3 QUIT loop thread: ACCEPT → store #TIB → reset >IN → INTERPRET → print " ok" → CR → loop

- [x] Task 8: Transition cold_start and update tests (AC: #1-7)
  - [x] 8.1 Add compile-time `IFDEF TEST_MODE` to cold_start — test_thread when defined, QUIT when not
  - [x] 8.2 Update Makefile: `make test` assembles with `-DTEST_MODE` for existing regression
  - [x] 8.3 Add `make test-repl` target: assembles without TEST_MODE, pipes REPL commands, checks output
  - [x] 8.4 REPL test: pipe `65 EMIT` → verify 'A' in output; pipe `BYE` → verify clean exit
  - [x] 8.5 REPL test: pipe undefined word → verify error message and recovery
  - [x] 8.6 Verify all existing regression tests still pass under `make test`

## Dev Notes

### What Already Exists (from Epic 1 + Story 2.1)

**Must not be modified** unless there's a bug:

- **Inner interpreter** (`inner_interpreter.asm`): DOCOL, EXIT_CODE, LIT, BRANCH, ?BRANCH, EXECUTE
- **FIND and COUNT** (`dictionary.asm`): Full dictionary lookup. FIND ( c-addr -- c-addr 0 | xt 1 | xt -1 )
- **Hash function** (`hash.asm`): `hash_name` subroutine
- **56+ CODE primitives**: stack_ops (15), arithmetic (6 + helpers), logic (12), memory (13), io (7), dictionary (2)
- **I/O words** (`io.asm`): EMIT, TYPE, CR, SPACE, SPACES, KEY, KEY? — all use BDOS_SAVE/BDOS_RESTORE
- **BYE** (`system.asm`): `JP BDOS_ENTRY` with C=P_TERMCPM
- **DEFWORD macro** (`macros.asm`): Works for assembly-time colon definitions. Emits header + `JP DOCOL`. Body is DW addresses terminated by EXIT_CODE
- **Cold start** (`antforth.asm:18-72`): Initialises SP, IX, IY, STATE=0, BASE=10, HERE=kernel_end, TIB, >IN=0
- **UserArea struct** (`structures.asm`): state, base, here, latest, tib_addr, tib_len, tib_in, source_id
- **Constants** (`constants.asm`): P_TERMCPM=0, C_READ=1, C_WRITE=2, C_STATUS=11, TIB_SIZE=128, HASH_BUCKETS=64, F_IMMEDIATE=0x80, F_SMUDGE=0x40, F_LENMASK=0x1F, PS_SIZE=256, RS_SIZE=256

### UserArea Offsets (IY-based)

| Offset | Field | Size | Access Pattern |
|--------|-------|------|----------------|
| IY+UserArea.state | STATE | 2B | 0=interpret, non-zero=compile |
| IY+UserArea.base | BASE | 2B | Number base (default 10) |
| IY+UserArea.here | HERE | 2B | Next free dictionary address |
| IY+UserArea.latest | LATEST | 2B | Most recently defined word |
| IY+UserArea.tib_addr | TIB | 2B | Text input buffer address |
| IY+UserArea.tib_len | #TIB | 2B | Current input length |
| IY+UserArea.tib_in | >IN | 2B | Parse position in TIB |
| IY+UserArea.source_id | SOURCE-ID | 2B | 0=console |

Use struct field names (e.g., `IY+UserArea.tib_in`), not raw offsets.

### Register Contract (Inviolable)

| Register | Role | Rules |
|----------|------|-------|
| BC | TOS | Contains TOS on entry; must contain new TOS on exit |
| DE | IP | Must be preserved — save/restore if used as scratch |
| SP | Parameter stack | Net effect must match stack signature |
| IX | Return stack | Preserve unless doing return stack ops |
| IY | User pointer | Preserve unless accessing user variables |
| HL, AF | Scratch | Free within CODE words |

### New Constant Needed

Add to `src/constants.asm`:
```z80
C_READSTR       EQU     10              ; BDOS function 10: read console buffer
```

### New Data Areas Needed

In `src/antforth.asm` data area:

```z80
rp_base:        DW      0               ; Initial IX value, set during cold start (for QUIT)
str_ok:         DB      " ok"
STR_OK_LEN      EQU     3

; BDOS function 10 input buffer — MUST be immediately before tib_buffer
bdos_input_buf: DS      1               ; max_len (set by ACCEPT before BDOS call)
bdos_input_len: DS      1               ; actual_len (filled by BDOS after call)
tib_buffer:     DS      TIB_SIZE        ; Character data lands here directly
```

**Critical:** `bdos_input_buf` must be at `tib_buffer - 2` so BDOS writes character data directly into the TIB. The current `tib_buffer` label remains correct — it's the same label, just preceded by 2 new bytes.

During cold_start, after IX is initialised, store it:
```z80
        ; Store initial return stack pointer for QUIT
        PUSH    IX
        POP     HL
        LD      (rp_base), HL
```

### User Variable Access Words — Shared Helper Pattern

All user variable words follow the same pattern. Use a shared helper to minimise code:

```z80
; Internal helper: push address of user variable at IY+offset
; Entry: A = offset into UserArea, BC = previous TOS
; Exit:  BC = IY + offset (address of user variable), previous TOS pushed to stack
push_user_var:
        PUSH    BC              ; Save current TOS
        PUSH    IY
        POP     HL              ; HL = IY (user area base)
        LD      C, A
        LD      B, 0            ; BC = offset
        ADD     HL, BC          ; HL = IY + offset
        LD      B, H
        LD      C, L            ; BC = address (new TOS)
        NEXT
```

Then each word is just:
```z80
w_STATE:
        DEFCODE "STATE", 0
w_STATE_cf:
        LD      A, UserArea.state
        JP      push_user_var

w_BASE:
        DEFCODE "BASE", 0
w_BASE_cf:
        LD      A, UserArea.base
        JP      push_user_var

w_TO_IN:
        DEFCODE ">IN", 0
w_TO_IN_cf:
        LD      A, UserArea.tib_in
        JP      push_user_var

w_TIB_LEN:
        DEFCODE "#TIB", 0
w_TIB_LEN_cf:
        LD      A, UserArea.tib_len
        JP      push_user_var
```

**SOURCE** ( -- c-addr u ) is different — it pushes two values:
```z80
w_SOURCE:
        DEFCODE "SOURCE", 0
w_SOURCE_cf:
        PUSH    BC                      ; Save TOS
        ; Push TIB address
        LD      L, (IY+UserArea.tib_addr)
        LD      H, (IY+UserArea.tib_addr+1)
        PUSH    HL                      ; c-addr on stack
        ; TOS = tib_len
        LD      C, (IY+UserArea.tib_len)
        LD      B, (IY+UserArea.tib_len+1)
        NEXT
```

**BL** ( -- char ) pushes space character:
```z80
w_BL:
        DEFCODE "BL", 0
w_BL_cf:
        PUSH    BC
        LD      BC, 0x0020
        NEXT
```

### ACCEPT Implementation Design

**Stack effect:** `ACCEPT ( c-addr +n1 -- +n2 )`

**CP/M BDOS function 10 (C_READSTR):**
- Input: DE = address of buffer with format [max_len DB][actual_len DB][chars...]
- BDOS reads characters, echoes them, handles backspace
- After user presses Enter: actual_len is set, CR is echoed but LF is NOT
- Characters do NOT include the terminating CR

**Algorithm:**
1. `BDOS_SAVE` (saves DE=IP and BC=TOS to parameter stack)
2. Pop +n1 from stack (it was second-on-stack, now on top after BDOS_SAVE pushes)
   - Actually: after BDOS_SAVE, stack has `[...] c-addr +n1 BC_saved DE_saved`. Need to access +n1.
   - **Simpler approach:** Don't use BDOS_SAVE. Manually save DE to return stack, then work with the stack directly.
3. Save DE (IP) to return stack: `DEC IX / DEC IX / LD (IX+0), E / LD (IX+1), D`
4. BC = +n1 (TOS). Store as max_len: `LD A, C / LD (bdos_input_buf), A`
5. Pop c-addr from stack (second argument): `POP HL` — HL = c-addr
   - Note: if c-addr ≠ tib_buffer, we'd need to copy. For MVP, assert c-addr == tib_buffer (the BDOS buffer header is placed before tib_buffer).
6. `LD DE, bdos_input_buf / LD C, C_READSTR / CALL BDOS_ENTRY`
7. After BDOS returns: emit LF (BDOS echoed CR but not LF):
   `LD E, 0x0A / LD C, C_WRITE / CALL BDOS_ENTRY`
8. Read actual_len: `LD A, (bdos_input_len) / LD C, A / LD B, 0` → BC = +n2
9. Restore DE from return stack: `LD E, (IX+0) / LD D, (IX+1) / INC IX / INC IX`
10. NEXT

**Critical notes:**
- BDOS function 10 echoes typed characters to stdout. When iz-cpm pipes stdin, characters are still echoed to stdout. The test output will include echoed input — account for this in expected output.
- BDOS 10 echoes CR when Enter is pressed. We must emit LF (0x0A) ourselves so the cursor advances to the next line. Do NOT emit CR+LF — only LF, since BDOS already echoed the CR.
- If BDOS 10 on iz-cpm does NOT echo the CR, then emit both CR+LF. **Test empirically under iz-cpm** and adjust.
- The c-addr argument is technically ignored in this implementation — BDOS always writes to bdos_input_buf+2 = tib_buffer. This is fine because QUIT always passes tib_buffer. Document this limitation.

### WORD Implementation Design

**Stack effect:** `WORD ( char -- c-addr )`

**Input:** char = delimiter (typically BL = space = 0x20).

**Output:** c-addr = address of counted string at HERE.

**Algorithm:**
1. Save DE (IP) to return stack
2. C = delimiter character (from BC, TOS)
3. Load parse state: HL = tib_addr + >IN, compute remaining = tib_len - >IN
4. **Skip leading delimiters:** While remaining > 0 and (HL) == delimiter: INC HL, DEC remaining, INC >IN
5. **Start of word found.** Get HERE address into DE. Set count = 0.
6. **Copy characters:** While remaining > 0 and (HL) != delimiter: copy (HL) to (DE+1+count), INC count, INC HL, DEC remaining, INC >IN
7. Skip one trailing delimiter if remaining > 0 and (HL) == delimiter: INC >IN
8. Store count byte at (DE+0) — the HERE address
9. Update >IN in UserArea
10. Restore DE (IP) from return stack
11. BC = HERE address (the counted string), NEXT

**Critical details:**
- WORD stores the result at HERE. This is transient — valid until HERE is modified (COMMA, ALLOT, etc.)
- If no token is found (all delimiters or empty input), the count byte is 0
- >IN must be updated in the UserArea after parsing: `LD (IY+UserArea.tib_in), new_in_low / LD (IY+UserArea.tib_in+1), new_in_high`
- The name stored at HERE is NOT null-terminated — it's a counted string (count byte + name bytes)
- WORD needs HERE address. Read from `(IY+UserArea.here)`.

### >NUMBER Implementation Design

**Stack effect:** `>NUMBER ( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )`

ANS Forth >NUMBER converts characters to a number using the current BASE. It processes left-to-right, stopping at the first non-digit.

**Single-precision simplification:** ud is two cells (unsigned double). For MVP, carry the high cell through but only accumulate into the low cell. The high cell stays 0. This limits numbers to 0-65535, which is correct for 16-bit Forth.

**Stack layout on entry:** BC = u1 (TOS), stack has: `... ud1-high ud1-low c-addr1`

**Algorithm:**
1. Save DE (IP) to return stack
2. Pop c-addr1 from stack into a register pair (HL works, but we need HL for multiply)
3. Get BASE from `(IY+UserArea.base)` — store in a scratch location
4. **Loop:** While u1 (BC) > 0:
   a. Load byte from (c-addr1): digit character
   b. Convert to digit value:
      - '0'-'9' → 0-9
      - 'A'-'Z' → 10-35 (uppercase first if 'a'-'z')
      - Anything else → not a digit, stop
   c. If digit >= BASE → stop
   d. Multiply ud-low by BASE: `ud-low = ud-low * BASE`
   e. Add digit: `ud-low = ud-low + digit`
   f. Advance c-addr1, decrement u1 (BC)
5. Push c-addr2 back to stack
6. Restore DE (IP)
7. BC = u2 (remaining count), NEXT

**Register allocation is tight.** Key approach:
- Use return stack (IX) to save DE (IP)
- Use stack to shuttle values between steps
- The 16-bit multiply (ud * BASE) can reuse the multiply pattern from arithmetic.asm (`w_STAR`)
- Alternatively, for small bases (2-36), shift-and-add is efficient

**Digit conversion subroutine** (internal, not a Forth word):
```z80
; Convert ASCII char in A to digit value
; Input: A = ASCII character
; Output: A = digit value (0-35), Carry set if invalid
; Clobbers: F
char_to_digit:
        SUB     '0'             ; A = char - '0'
        RET     C               ; char < '0' → invalid (carry set)
        CP      10
        RET     C               ; 0-9 → valid (carry clear, A = 0-9)
        ; Not 0-9, try A-Z
        AND     0xDF            ; uppercase (clear bit 5)... wait, we already subtracted '0'
```

Actually, better approach:
```z80
char_to_digit:
        ; Input: A = ASCII char. Output: A = digit, Carry = invalid
        CP      '0'
        RET     C               ; < '0' → invalid
        SUB     '0'             ; A = char - '0'
        CP      10
        RET     C               ; 0-9 → valid (A = 0-9, carry clear... wait, CP 10 sets carry if A < 10)
```

Hmm, the carry logic is tricky. Let the dev agent work out the exact digit conversion. The key contract is:
- Input: A = ASCII character
- Output: A = digit value (0-35), Carry flag clear = valid, Carry flag set = invalid
- Must handle 0-9 and A-Z/a-z (case-insensitive)

### NUMBER? Implementation Design

**Stack effect:** `NUMBER? ( c-addr -- n true | c-addr false )`

Internal helper for INTERPRET. Takes a counted string address, tries to convert to a number.

**Algorithm:**
1. Save c-addr (for failure return)
2. Load count byte: `LD A, (BC)` — if count = 0, fail immediately
3. Set name_addr = BC + 1, count = A
4. Check for leading '-': if first char of name = '-', set negate flag, advance name_addr, decrement count
5. If count = 0 after stripping '-' (bare "-"), fail
6. Set accumulator = 0. Call >NUMBER logic inline (or call >NUMBER CODE directly)
7. If remaining count = 0 (all chars consumed): negate if flag, push n, push TRUE (0xFFFF)
8. If remaining count > 0 (unconvertible chars): push original c-addr, push FALSE (0)

**Return values:**
- Success: second-on-stack = n, BC = 0xFFFF (TRUE), NEXT
- Failure: second-on-stack = original c-addr, BC = 0 (FALSE), NEXT

**Note:** NUMBER? does NOT use >NUMBER as a Forth word call (that would require threading). It calls the conversion logic directly as a subroutine or inlines it. The dev agent should decide whether to:
- (a) Inline the conversion loop in NUMBER? and make >NUMBER a thin wrapper, or
- (b) Implement >NUMBER as a callable subroutine with a register-level interface, and have both the CODE word and NUMBER? call it

Option (b) is cleaner. Define an internal `do_number` subroutine:
```z80
; do_number: convert string to number using BASE
; Input:  HL = string address, B = char count, DE' = accumulator (0 initially)
; Output: DE' = result, HL advanced, B = remaining count
; Clobbers: A, F, C
```

Then both `>NUMBER` (the Forth word) and `NUMBER?` call `do_number`.

### INTERPRET Implementation Design

**INTERPRET as DEFWORD** with manual BRANCH/?BRANCH offsets. This works because BRANCH and ?BRANCH are already implemented and sjasmplus computes `label - $` at assembly time.

```z80
; -----------------------------------------------
; INTERPRET ( -- )
;   Parse and execute all words in the input buffer
; -----------------------------------------------
w_INTERPRET:
        DEFWORD "INTERPRET", 0
w_INTERPRET_cf:
.interp_loop:
        DW      w_BL_cf                 ; ( -- 32 )
        DW      w_WORD_cf               ; ( 32 -- c-addr )
        DW      w_DUP_cf                ; ( c-addr -- c-addr c-addr )
        DW      w_C_FETCH_cf            ; ( c-addr c-addr -- c-addr count )
        DW      w_QBRANCH_cf            ; if count=0, done
        DW      .interp_done - $
        ; Non-empty token — try FIND
        DW      w_FIND_cf               ; ( c-addr -- c-addr 0 | xt flag )
        DW      w_DUP_cf                ; ( ... x -- ... x x )
        DW      w_QBRANCH_cf            ; if flag=0 (not found), try number
        DW      .try_number - $
        ; Found: ( xt flag ) — drop flag, execute
        DW      w_DROP_cf               ; ( xt flag -- xt )
        DW      w_EXECUTE_cf            ; execute the word
        DW      w_BRANCH_cf             ; loop back
        DW      .interp_loop - $
.try_number:
        ; Stack: ( c-addr 0 ) — not found
        DW      w_DROP_cf               ; ( c-addr 0 -- c-addr )
        DW      w_NUMBER_Q_cf           ; ( c-addr -- n true | c-addr false )
        DW      w_QBRANCH_cf            ; if false, error
        DW      .not_number - $
        ; Valid number on stack, continue
        DW      w_BRANCH_cf
        DW      .interp_loop - $
.not_number:
        ; Stack: ( c-addr ) — not a word, not a number
        DW      w_COUNT_cf              ; ( c-addr -- addr len )
        DW      w_TYPE_cf               ; print the unknown word
        DW      w_LIT_cf, ' '
        DW      w_EMIT_cf               ; space
        DW      w_LIT_cf, '?'
        DW      w_EMIT_cf               ; question mark
        DW      w_CR_cf                 ; newline
        DW      w_ABORT_cf              ; reset and restart QUIT (never returns)
.interp_done:
        DW      w_DROP_cf               ; drop the empty c-addr
        DW      w_EXIT_cf               ; return to caller (QUIT loop)
```

**Critical: verify ?BRANCH offset computation.** For each `DW .label - $`:
- `$` = address of this DW (where the offset value is stored)
- `.label` = target address
- BRANCH/QBRANCH adds the offset to the offset cell's address, arriving at `.label`
- sjasmplus computes this correctly at assembly time

**Note on STATE handling:** In this story, STATE is always 0 (interpret mode). The compiler (Story 3.1) will add compile-mode logic to INTERPRET. For now, all words are executed immediately regardless of STATE. When Story 3.1 adds compilation, INTERPRET will need to check STATE and either execute or compile words. The current structure makes this easy to extend — add a STATE check between FIND and EXECUTE.

### QUIT Implementation Design

**QUIT as CODE word** — the CODE entry resets IX and STATE, then enters a threaded loop body:

```z80
; -----------------------------------------------
; QUIT ( -- )
;   Reset return stack, set interpret mode, enter REPL loop
;   Never returns — loops forever (or until BYE)
; -----------------------------------------------
w_QUIT:
        DEFCODE "QUIT", 0
w_QUIT_cf:
        ; Reset return stack
        LD      HL, (rp_base)
        PUSH    HL
        POP     IX
        ; STATE = 0 (interpret mode)
        XOR     A
        LD      (IY+UserArea.state), A
        LD      (IY+UserArea.state+1), A
        ; Enter the QUIT loop thread
        LD      DE, .quit_loop
        NEXT

.quit_loop:
        ; Read line of input into TIB
        DW      w_LIT_cf, tib_buffer    ; ( -- tib-addr )
        DW      w_LIT_cf, TIB_SIZE      ; ( tib-addr -- tib-addr size )
        DW      w_ACCEPT_cf             ; ( tib-addr size -- n )
        ; Store n as #TIB (current input length)
        DW      w_TIB_LEN_cf            ; ( n -- n addr )
        DW      w_STORE_cf              ; ( n addr -- )
        ; Reset >IN to 0
        DW      w_LIT_cf, 0             ; ( -- 0 )
        DW      w_TO_IN_cf              ; ( 0 -- 0 addr )
        DW      w_STORE_cf              ; ( 0 addr -- )
        ; Interpret the line
        DW      w_INTERPRET_cf
        ; Print " ok" and newline
        DW      w_LIT_cf, str_ok        ; ( -- addr )
        DW      w_LIT_cf, STR_OK_LEN    ; ( addr -- addr len )
        DW      w_TYPE_cf               ; print " ok"
        DW      w_CR_cf                 ; newline
        ; Loop forever
        DW      w_BRANCH_cf
        DW      .quit_loop - $
```

**Why QUIT is CODE, not DEFWORD:** QUIT must reset IX (return stack pointer) before entering the loop. If QUIT were DEFWORD, DOCOL would push IP to the return stack — then the first thing in the body would RP! to reset the return stack, wiping that saved IP. While this technically works (QUIT never returns), it's cleaner to do the reset in CODE and then set IP directly.

**ABORT → QUIT flow:** ABORT resets SP and JPs to `w_QUIT_cf`. QUIT's CODE resets IX and STATE, sets DE = `.quit_loop`, NEXT. This cleanly restarts the REPL with both stacks reset and STATE = interpret.

### ABORT Implementation Design

```z80
; -----------------------------------------------
; ABORT ( -- )
;   Reset parameter stack and restart QUIT
;   Never returns
; -----------------------------------------------
w_ABORT:
        DEFCODE "ABORT", 0
w_ABORT_cf:
        LD      HL, (sp_base)
        LD      SP, HL                  ; Reset parameter stack
        JP      w_QUIT_cf               ; Enter QUIT (resets return stack + STATE)
```

**Note:** `LD SP, HL` (not `LD SP, (sp_base)` directly — Z80 does support `LD SP, (nn)` but loading via HL is more portable across assemblers).

### Cold Start Transition

**Compile-time dual mode** using sjasmplus `IFDEF`:

```z80
        ; 10. Enter execution
        IFDEF TEST_MODE
            ; Regression test mode: run test thread, exit via BYE
            LD      DE, test_thread
        ELSE
            ; Normal mode: enter QUIT (interactive REPL)
            ; Push 0 as initial TOS (BC) — QUIT expects clean state
            LD      BC, 0
            LD      DE, quit_entry
            ; quit_entry is a mini thread that just calls QUIT
        ENDIF
        NEXT
```

For normal mode, need a small entry thread:
```z80
quit_entry:
        DW      w_QUIT_cf       ; Enter QUIT — never returns
```

Or simpler: QUIT is a CODE word, so `LD DE` can point to a thread containing just `DW w_QUIT_cf`. Or since QUIT's CODE entry doesn't use DE as IP (it sets DE = .quit_loop internally), you can just `JP w_QUIT_cf` directly.

**Simplest approach:**
```z80
        IFDEF TEST_MODE
            LD      DE, test_thread
            NEXT
        ELSE
            LD      BC, 0           ; Clean TOS
            JP      w_QUIT_cf       ; Enter QUIT directly
        ENDIF
```

**Makefile changes:**
```makefile
# Regression test: assembles with TEST_MODE, checks character output
test: $(TARGET)
	@echo "Running regression tests..."
	@cd $(SRCDIR) && $(ASM) $(ASMFLAGS) -DTEST_MODE antforth.asm --raw=../$(BUILDDIR)/antforth_test.com
	@OUTPUT=$$($(IZCPM) $(BUILDDIR)/antforth_test.com) && \
	EXPECTED=... && \
	...

# REPL test: assembles normally, pipes commands via stdin
test-repl: $(TARGET)
	@echo "Running REPL tests..."
	@OUTPUT=$$(printf '65 EMIT\r\nBYE\r\n' | $(IZCPM) $(TARGET)) && \
	...
```

**Note:** The existing `$(TARGET)` build (without TEST_MODE) produces the interactive REPL binary. A separate `antforth_test.com` is built with TEST_MODE for regression.

### Testing Strategy

**Three test tracks for this story:**

1. **Regression (`make test`):** Existing test_thread runs with TEST_MODE defined. All 58+ tests pass. Output matches existing EXPECTED string exactly. No changes to test_thread needed.

2. **REPL integration (`make test-repl`):** Pipes commands to interactive binary via stdin. Tests:
   - `65 EMIT` → output includes 'A' (number parsing + word execution)
   - Multi-word: `72 EMIT 73 EMIT` → output includes "HI"
   - Undefined word: `XYZZY` → output includes "XYZZY ?" error, then recovery
   - Clean exit: `BYE` → program terminates cleanly
   - Multi-line: verify ` ok` appears between successful lines

3. **REPL output format:** Be aware that BDOS function 10 **echoes input characters** to stdout. When piping `65 EMIT\r\n` via stdin, the output will include:
   - Echoed characters: `65 EMIT` (echoed by BDOS 10)
   - CR from Enter (echoed by BDOS 10)
   - LF from ACCEPT
   - `A` from EMIT execution
   - ` ok` from QUIT
   - CR+LF from CR word
   
   **The exact output format must be determined empirically** by running under iz-cpm. The dev agent should build, run, capture output with xxd, and adjust the EXPECTED string accordingly.

### File Structure

| File | New Words | Notes |
|------|-----------|-------|
| `src/constants.asm` | — | Add C_READSTR = 10 |
| `src/io.asm` | ACCEPT | Alongside EMIT, KEY, etc. |
| `src/strings.asm` | WORD, >NUMBER, NUMBER? | Parsing/conversion primitives |
| `src/outer_interpreter.asm` | INTERPRET, QUIT, STATE, BASE, >IN, #TIB, SOURCE, BL, push_user_var | Main outer interpreter |
| `src/system.asm` | ABORT | Alongside BYE |
| `src/antforth.asm` | — | Add rp_base, bdos_input_buf, str_ok; modify cold_start; add IFDEF TEST_MODE |
| `Makefile` | — | Add -DTEST_MODE to test target; add test-repl target |

**Include order is already correct** — strings.asm (Task 4-5) is included before outer_interpreter.asm (Task 6-7), which is included before system.asm (Task 7).

### Naming Convention for Labels

| Forth word | Label prefix | Code field label |
|-----------|-------------|-----------------|
| ACCEPT | w_ACCEPT | w_ACCEPT_cf |
| WORD | w_WORD | w_WORD_cf |
| >NUMBER | w_TO_NUMBER | w_TO_NUMBER_cf |
| NUMBER? | w_NUMBER_Q | w_NUMBER_Q_cf |
| INTERPRET | w_INTERPRET | w_INTERPRET_cf |
| QUIT | w_QUIT | w_QUIT_cf |
| ABORT | w_ABORT | w_ABORT_cf |
| STATE | w_STATE | w_STATE_cf |
| BASE | w_BASE | w_BASE_cf |
| >IN | w_TO_IN | w_TO_IN_cf |
| #TIB | w_TIB_LEN | w_TIB_LEN_cf |
| SOURCE | w_SOURCE | w_SOURCE_cf |
| BL | w_BL | w_BL_cf |

Internal helpers (NOT Forth words):
| Function | Label |
|----------|-------|
| User var address helper | push_user_var |
| Digit conversion helper | char_to_digit |
| Number conversion core | do_number (optional, if factored out) |

### Anti-Patterns to Avoid

1. **Do NOT use BDOS_SAVE/BDOS_RESTORE in ACCEPT** — the macro pair assumes standard CODE word entry (BC=TOS, DE=IP). ACCEPT needs custom register management because it must set up the BDOS buffer from stack arguments. Save DE (IP) to the return stack manually.
2. **Do NOT assume BDOS 10 echoes CR+LF** — it echoes CR only (or possibly nothing). Test under iz-cpm and emit the missing newline characters explicitly.
3. **Do NOT modify the DEFWORD macro** — use it as-is for INTERPRET. Local labels (`.interp_loop`, etc.) work within the scope of the preceding non-local label (`w_INTERPRET_cf`).
4. **Do NOT use control flow words** (IF, ELSE, THEN, BEGIN, AGAIN) in DEFWORD bodies — those are IMMEDIATE words from Epic 3. Use BRANCH and ?BRANCH with manual `DW .label - $` offsets.
5. **Do NOT hardcode UserArea offsets** — always use `UserArea.fieldname` struct access (e.g., `IY+UserArea.tib_in`).
6. **Do NOT forget to emit LF after ACCEPT** — without it, the REPL output will be garbled (cursor stays on the same line).
7. **Do NOT forget to update >IN in WORD** — if >IN isn't advanced, INTERPRET loops forever on the same token.
8. **Do NOT forget to handle empty input in WORD** — when >IN >= tib_len, return count=0 so INTERPRET exits the parse loop.
9. **Do NOT make INTERPRET a CODE word** unless the DEFWORD approach proves unworkable — the threaded version is more maintainable and extensible for Story 3.1 (compile mode).
10. **Do NOT break the existing test_thread** — it must remain functional under `make test` with TEST_MODE.
11. **Do NOT use IX or IY as scratch** in WORD, >NUMBER, or NUMBER? without save/restore. IX = return stack, IY = user area.
12. **Do NOT forget negative number handling in NUMBER?** — a leading `-` must be stripped before conversion and the result negated after.

### Previous Story Learnings (from Story 2.1)

- **DEFCODE/DEFWORD macro bugs were fixed** in Story 2.1: quote stripping in name, LUA global bucket table for hash_link emission, `sj.calc()` for flags. These macros now work correctly — no further fixes expected.
- **Test thread pattern is well-established:** emit a known character on success, '!' on failure. Each test occupies a predictable range of DW instructions.
- **BDOS calling convention works:** BDOS_SAVE/BDOS_RESTORE correctly saves DE (IP) and BC (TOS). For ACCEPT, manual save/restore is needed instead (see anti-pattern #1).
- **Case-insensitive comparison works** in FIND — reuse the UPPER macro pattern for any new case-insensitive code (e.g., digit conversion A-Z/a-z in >NUMBER).
- **Label convention is consistent:** w_NAME before DEFCODE, w_NAME_cf after. Internal helpers use lowercase_with_underscores.
- **Bug found in Story 2.1:** `tonumber()` in LUA couldn't resolve EQU symbols — replaced with `sj.calc()`. This fix means DEFIMMED now works correctly (F_IMMEDIATE flag is properly set). This will matter for Story 3.1 but confirms the macro infrastructure is solid.

### Git Intelligence

Recent commits show a clean one-commit-per-story pattern:
```
0054157 completed story 2.1
b57363d completed story 1.5 plus retro
0f66341 implemented story 1.4 - arithmetic and logic ops
155855b implemented story 1.3 - stack and memory ops
7891f46 implement inner interpreter and threading (story 1-2)
```

Codebase is stable — all tests pass. Story 2.1 added FIND, COUNT, hash_name to the 56 CODE words from Epic 1. No regressions.

### Implementation Order Recommendation

Build and test incrementally:

1. **Constants + data areas** (Task 1) — non-functional, just setup
2. **User variable words + BL** (Task 2) — simple, testable in test_thread
3. **ACCEPT** (Task 3) — test manually by adding a simple thread that calls ACCEPT then BYE
4. **WORD** (Task 4) — depends on user var words for >IN access
5. **>NUMBER + NUMBER?** (Task 5) — self-contained conversion logic
6. **INTERPRET** (Task 6) — depends on WORD, FIND, NUMBER?, EXECUTE
7. **ABORT + QUIT** (Task 7) — depends on INTERPRET, ACCEPT
8. **Cold start + test update** (Task 8) — integration and verification

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.2] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture.md#Input Buffer & Parsing] — TIB, >IN, WORD, PARSE
- [Source: _bmad-output/planning-artifacts/architecture.md#Error Handling & Abort Protocol] — ABORT/QUIT two-level model
- [Source: _bmad-output/planning-artifacts/architecture.md#Cold Start Protocol] — initialisation sequence
- [Source: _bmad-output/planning-artifacts/architecture.md#Kernel/Forth Boundary] — ACCEPT=CODE, QUIT/ABORT/INTERPRET=Forth
- [Source: _bmad-output/planning-artifacts/architecture.md#Register Usage Discipline] — register contract
- [Source: _bmad-output/planning-artifacts/architecture.md#BDOS Interaction Pattern] — BDOS_SAVE/RESTORE
- [Source: src/structures.asm:18-27] — UserArea struct with all field offsets
- [Source: src/macros.asm:100-127] — DEFWORD macro (assembly-time colon definitions)
- [Source: src/inner_interpreter.asm:51-60] — BRANCH implementation (relative offset)
- [Source: src/inner_interpreter.asm:66-85] — ?BRANCH implementation
- [Source: src/dictionary.asm] — FIND implementation (case-insensitive, SMUDGE-aware)
- [Source: src/io.asm] — EMIT, TYPE, CR, SPACE, KEY patterns (BDOS usage)
- [Source: src/antforth.asm:18-72] — cold_start initialisation code
- [Source: src/antforth.asm:1060-1082] — data area (hash_table, sp_base, user_area, tib_buffer)
- [Source: src/constants.asm] — all current constants (C_READSTR missing, to be added)
- [Source: Makefile:52-63] — current test infrastructure

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- DEFWORD code field bug: `w_INTERPRET_cf:` placed after DEFWORD macro pointed to the body (DW thread data) instead of the code field (JP DOCOL). When used in threaded code (`DW w_INTERPRET_cf`), the inner interpreter JP'd to thread data rather than DOCOL, causing infinite loops. Fixed by using `EQU w_INTERPRET_body - 3` to correctly point to JP DOCOL. This is a pattern that future DEFWORD words must follow.
- iz-cpm BDOS 10 pipe behavior: iz-cpm crashes with `UnexpectedEof` when stdin is a pipe and the program terminates (or BDOS 10 hits EOF). Workaround: `2>/dev/null || true` in Makefile test targets.
- BDOS 10 echo and newlines: Under iz-cpm with piped stdin, BDOS 10 echoes characters including CR. ACCEPT emits only LF (0x0A) since BDOS already echoes CR. A stray LF from `\r\n` pipe sequences causes an extra empty-line " ok" cycle — cosmetic only.
- ACCEPT emits LF only (not CR+LF) as task 3.3 originally said "CR+LF" but empirical testing showed BDOS 10 already echoes CR.

### Completion Notes List

- Task 1: Added C_READSTR constant, rp_base, bdos_input_buf/len before tib_buffer, str_ok, and IX save in cold_start
- Task 2: Implemented push_user_var helper + STATE, BASE, >IN, #TIB, SOURCE, BL — all tested via threading in test_thread
- Task 3: Implemented ACCEPT using BDOS 10 with manual IX save/restore (not BDOS_SAVE) per dev notes anti-pattern #1
- Task 4: Implemented WORD with leading delimiter skip, char copy to HERE, trailing delimiter skip, >IN advancement — tested via threading
- Task 5: Implemented char_to_digit helper, do_number subroutine (used by both >NUMBER and NUMBER?), >NUMBER CODE word, NUMBER? with negative number handling — tested positive, negative, and invalid strings
- Task 6: Implemented INTERPRET as DEFWORD with manual BRANCH/?BRANCH offsets per dev notes pattern. Handles FIND→EXECUTE for known words, NUMBER? for numbers, error→ABORT for unknown tokens
- Task 7: ABORT resets SP via sp_base and JP's to QUIT. QUIT resets IX via rp_base, clears STATE, enters threaded REPL loop
- Task 8: Added IFDEF TEST_MODE dual-mode cold_start. make test uses -DTEST_MODE with separate antforth_test.com binary. Added make test-repl with 4 piped REPL tests. All 62+ regression tests and 4 REPL tests pass

### Change Log

- 2026-04-04: Implemented Story 2.2 — outer interpreter, REPL loop, and all supporting words (ACCEPT, WORD, >NUMBER, NUMBER?, INTERPRET, ABORT, QUIT, STATE, BASE, >IN, #TIB, SOURCE, BL, push_user_var)
- 2026-04-04: Code review fixes — removed dead push/pop in WORD, added SOURCE test to test thread, improved do_number documentation

### File List

- `src/constants.asm` — Added C_READSTR EQU 10
- `src/antforth.asm` — Added rp_base, str_ok, bdos_input_buf/len data areas; IX save in cold_start; IFDEF TEST_MODE dual boot; test_thread additions (user var tests, WORD test, NUMBER? tests, INTERPRET test)
- `src/io.asm` — Added ACCEPT (BDOS function 10)
- `src/strings.asm` — Added WORD, char_to_digit, do_number, >NUMBER, NUMBER?
- `src/outer_interpreter.asm` — Added push_user_var, STATE, BASE, >IN, #TIB, SOURCE, BL, INTERPRET (DEFWORD), QUIT
- `src/system.asm` — Added ABORT
- `Makefile` — Updated test target to use -DTEST_MODE and separate binary; added test-repl target with 4 REPL integration tests
