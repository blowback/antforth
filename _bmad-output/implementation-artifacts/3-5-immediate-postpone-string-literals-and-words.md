# Story 3.5: IMMEDIATE, POSTPONE, String Literals & WORDS

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to create compile-time words, use string literals, and browse the dictionary,
so that I can write sophisticated macros, use strings in my programs, and inspect the available vocabulary.

## Acceptance Criteria

1. **Given** the user defines a word and then types `IMMEDIATE` **When** the most recent definition is marked IMMEDIATE **Then** the IMMEDIATE flag (bit 7) is set in the dictionary entry's count+flags byte **And** when that word is encountered during compilation, it executes immediately instead of being compiled

2. **Given** a definition that uses POSTPONE with a non-IMMEDIATE word: `: COMP-DUP POSTPONE DUP ; IMMEDIATE` **When** `COMP-DUP` is used inside another definition **Then** DUP is compiled into that definition (POSTPONE defers the compilation)

3. **Given** a definition that uses POSTPONE with an IMMEDIATE word **When** POSTPONE is used **Then** the compilation semantics (not execution semantics) of the IMMEDIATE word are compiled

4. **Given** a definition using S": `: GREET S" Hello" TYPE ;` **When** `GREET` is executed **Then** `Hello` is printed **And** S" compiles an inline counted string (runtime word + count byte + string bytes) into the definition

5. **Given** a definition using .": `: HI ." Hello World" ;` **When** `HI` is executed **Then** `Hello World` is printed

6. **Given** S" used in interpret mode **When** `S" test" TYPE` is typed at the REPL **Then** `test` is printed (S" works in both interpret and compile mode per ANS)

7. **Given** the user types `WORDS` **When** WORDS executes **Then** all words in the dictionary are listed to the console (traversing all 64 hash buckets)

## Tasks / Subtasks

- [x] Task 1: Implement `IMMEDIATE` as a DEFCODE word in `src/compiler.asm` (AC: #1)
  - [x] 1.1 Stack effect: `( -- )` — no stack inputs or outputs
  - [x] 1.2 Load LATEST from `(IY+UserArea.latest)` into HL
  - [x] 1.3 Skip hash_link (2 bytes) to reach count_flags at HL+2
  - [x] 1.4 Load count_flags byte, OR with F_IMMEDIATE (0x80), store back
  - [x] 1.5 `NEXT`

- [x] Task 2: Implement `POSTPONE` as a DEFIMMED word in `src/compiler.asm` (AC: #2, #3)
  - [x] 2.1 Use `DEFIMMED "POSTPONE"` — threaded IMMEDIATE word using existing primitives
  - [x] 2.2 Compile-only guard: starts with `DW w_QCOMP_cf`
  - [x] 2.3 Parse the next word from the input stream: BL WORD FIND
  - [x] 2.4 If word not found (FIND returns 0): DROP DROP ABORT
  - [x] 2.5 If FIND returns flag=1 (IMMEDIATE word): compile xt directly via COMMA (standard compilation of its compilation semantics)
  - [x] 2.6 If FIND returns flag=-1 (non-IMMEDIATE word): compile `LIT xt COMPILE,` to defer compilation to runtime
  - [x] 2.7 `EXIT_CODE` (threaded implementation)

- [x] Task 3: Implement `COMPILE,` as a DEFCODE word in `src/compiler.asm` (AC: #2, #3)
  - [x] 3.1 Stack effect: `( xt -- )` — compiles execution token into current definition
  - [x] 3.2 Load HERE from IY, write BC (TOS = xt) at HERE, advance HERE by 2
  - [x] 3.3 Pop new TOS from parameter stack
  - [x] 3.4 `NEXT`
  - [x] 3.5 Note: `COMPILE,` is functionally identical to `,` (COMMA) for direct-threaded Forth, but is semantically distinct per ANS. Implement as a separate word for standards compliance.

- [x] Task 4: Implement string literal runtime `(S")` as a DEFCODE word in `src/strings.asm` (AC: #4, #5, #6)
  - [x] 4.1 Runtime behaviour: reads inline counted string from the thread (IP points to count byte after `(S")` cell)
  - [x] 4.2 Push c-addr (address of first character = IP+1) and u (count = byte at IP) to parameter stack
  - [x] 4.3 Advance IP past the string: IP = IP + 1 + count, then align to cell boundary (round up to even address)
  - [x] 4.4 Stack effect: `( -- c-addr u )`
  - [x] 4.5 `NEXT`

- [x] Task 5: Implement `S"` as a DEFCODE IMMEDIATE word in `src/strings.asm` (AC: #4, #6)
  - [x] 5.1 Use `DEFCODE 'S"', F_IMMEDIATE` — note: name is `S"` (2 chars)
  - [x] 5.2 **Compile mode** (STATE != 0): compile `(S")` xt at HERE, then parse characters up to closing `"` from the input stream and compile them as: count byte + string bytes at HERE, padding to cell-aligned boundary
  - [x] 5.3 **Interpret mode** (STATE = 0): parse the string to a transient buffer (s_quote_buf, 258 bytes), push c-addr u onto parameter stack
  - [x] 5.4 String parsing: skip one leading space after `S"`, read characters until `"` (or end of input), advance >IN past the closing `"`
  - [x] 5.5 For compile mode: advance HERE past count + string bytes + alignment padding

- [x] Task 6: Implement `."` as a DEFCODE IMMEDIATE word in `src/strings.asm` (AC: #5)
  - [x] 6.1 Use `DEFCODE '."', F_IMMEDIATE` — name is `."` (2 chars)
  - [x] 6.2 Compile-only: check STATE, JP to w_QCOMP_cf if interpret mode
  - [x] 6.3 Compile `(S")` xt at HERE (shared compile_string subroutine)
  - [x] 6.4 Parse string up to `"` and compile inline (shared compile_string subroutine)
  - [x] 6.5 Compile `TYPE` xt after the string — so at runtime, `(S")` pushes c-addr u, then TYPE prints it
  - [x] 6.6 `NEXT`

- [x] Task 7: Implement `WORDS` as a DEFCODE word in `src/dictionary.asm` (AC: #7)
  - [x] 7.1 Stack effect: `( -- )` — no inputs or outputs, side effect is console output
  - [x] 7.2 Loop through all 64 hash buckets (0 to HASH_BUCKETS-1)
  - [x] 7.3 For each non-empty bucket, walk the chain via hash_link pointers
  - [x] 7.4 For each entry: skip hash_link (2 bytes), read count_flags, mask with F_LENMASK for name length, skip SMUDGE'd entries
  - [x] 7.5 Print each word's name followed by a space (use BDOS C_WRITE for each character)
  - [x] 7.6 Stop when hash_link = 0 (end of chain)
  - [x] 7.7 After all buckets, output CR/LF
  - [x] 7.8 `NEXT`

- [x] Task 8: Register all new `w_*_cf` labels (AC: all)
  - [x] 8.1 CODE words (IMMEDIATE, COMPILE,, (S"), WORDS): label placed immediately after DEFCODE macro
  - [x] 8.2 DEFIMMED words (POSTPONE): w_POSTPONE_cf EQU w_POSTPONE_body - 3
  - [x] 8.3 DEFCODE IMMEDIATE words (S", ."): label placed immediately after DEFCODE macro

- [x] Task 9: Add REPL tests to `Makefile` starting at test 65 (AC: #1-#7)
  - [x] 9.1 Test 65: `: FOO ; IMMEDIATE` — define word, mark IMMEDIATE, verify no crash
  - [x] 9.2 Test 66: `: COMP-DUP POSTPONE DUP ; IMMEDIATE : DOUBLE COMP-DUP * ; 7 DOUBLE .` — outputs `49`
  - [x] 9.3 Test 67: `: COMP-IF POSTPONE IF ; IMMEDIATE : TEST 1 COMP-IF 42 THEN . ; TEST` — outputs `42`
  - [x] 9.4 Test 68: `: GREET S" Hello" TYPE ; GREET` — outputs `Hello`
  - [x] 9.5 Test 69: `: HI ." Hello World" ; HI` — outputs `Hello World`
  - [x] 9.6 Test 70: `S" test" TYPE` — outputs `test` (S" in interpret mode)
  - [x] 9.7 Test 71: `: LEN S" abcde" SWAP DROP . ; LEN` — outputs `5` (string length check; NIP replaced with SWAP DROP)
  - [x] 9.8 Test 72: `WORDS` — output contains DUP, DROP, SWAP
  - [x] 9.9 Test 73: `POSTPONE` in interpret mode — shows `? compile only` and recovers
  - [x] 9.10 Test 74: `."` in interpret mode — shows `? compile only` and recovers
  - [x] 9.11 Test 75: `: GREET2 ." Hi " ." There" ; GREET2` — outputs `Hi There`
  - [x] 9.12 Test 76: `: EMPTY S" " SWAP DROP . ; EMPTY` — outputs `0` (empty string; NIP replaced with SWAP DROP)
  - [x] 9.13 Test 77: `: LONG S" ABCDEFGHIJKLMNOPQRSTUVWXYZ" TYPE ; LONG` — outputs full alphabet

- [x] Task 10: Verify no regressions
  - [x] 10.1 `make test` — all existing regression tests pass
  - [x] 10.2 `make test-repl` — all REPL tests pass (1 through 77)
  - [x] 10.3 `make` — normal build succeeds

## Dev Notes

### What Already Exists (verified from source)

**IMMEDIATE flag infrastructure** (`src/constants.asm:33-35`):
- `F_IMMEDIATE EQU 0x80` — bit 7 of count_flags byte
- `F_SMUDGE EQU 0x40` — bit 6 (used during compilation)
- `F_LENMASK EQU 0x1F` — bits 0-4 (name length, max 31)

**FIND already checks IMMEDIATE** (`src/dictionary.asm:118-129`):
- Returns `xt 1` for IMMEDIATE words, `xt -1` for non-IMMEDIATE
- FIND result flag drives INTERPRET's compile-vs-execute decision

**INTERPRET already handles IMMEDIATE in compile mode** (`src/outer_interpreter.asm:166-180`):
- In compile mode, if FIND returns flag=1 (IMMEDIATE), executes the word immediately
- If flag=-1 (non-IMMEDIATE), compiles the word's xt into the definition
- This infrastructure is already complete — IMMEDIATE just needs to set the flag on LATEST

**STATE variable** (`src/structures.asm:19`):
- `UserArea.state` at IY+0 (2 bytes, 0=interpret, non-zero=compile)
- `[` sets STATE to 0, `]` sets STATE to non-zero
- Already used by `;`, `LITERAL`, `IF`, `ELSE`, `THEN`, `BEGIN`, `WHILE`, `REPEAT`, `UNTIL`, `DO`, `LOOP`, `+LOOP`, `LEAVE`, `RECURSE`

**LATEST pointer** (`src/structures.asm:22`, `src/compiler.asm:194-196`):
- `UserArea.latest` at IY+6 (2 bytes)
- Points to dictionary entry start of most recently defined word
- Updated by `build_header` in compiler.asm

**TYPE word** (`src/io.asm:24-56`):
- Stack effect: `( c-addr u -- )`
- Loops through u characters starting at c-addr, outputs each via BDOS C_WRITE
- Available as `w_TYPE_cf`

**WORD** (`src/strings.asm:10-163`):
- Parses whitespace-delimited token from TIB into counted string at HERE
- Available as `w_WORD_cf`

**Hash table** (`src/dictionary.asm:47`):
- `hash_table` label — 64 entries of 2 bytes each (128 bytes total)
- Each entry is head of a linked list via hash_link field
- Traversal: follow hash_link until 0

**Compile-only guard** (`src/control_flow.asm:10`):
- `w_QCOMP_cf` — prints `? compile only` and ABORTs when STATE=0

**HERE and COMMA** (`src/memory.asm:92-131`):
- `w_HERE_cf` pushes current HERE value
- `w_COMMA_cf` writes TOS at HERE, advances HERE by 2

**LIT** (`src/inner_interpreter.asm:85-94`):
- Pushes inline literal from thread — available as `w_LIT_cf`

**>IN variable** (`src/structures.asm:25`):
- `UserArea.tib_in` at IY+12 — parse position offset in TIB
- `tib_addr` at IY+8 — start of TIB
- `tib_len` at IY+10 — current input length

### IMMEDIATE Implementation

The simplest word in this story. IMMEDIATE just sets bit 7 on the most recently defined word's count_flags byte:

```z80
w_IMMEDIATE:
    DEFCODE "IMMEDIATE", 0
w_IMMEDIATE_cf:
    ; ( -- ) Set F_IMMEDIATE on LATEST word
    LD      L, (IY+UserArea.latest)
    LD      H, (IY+UserArea.latest+1)
    ; Skip hash_link (2 bytes) to count_flags
    INC     HL
    INC     HL
    LD      A, (HL)
    OR      F_IMMEDIATE         ; Set bit 7
    LD      (HL), A
    NEXT
```

Note: IMMEDIATE itself is NOT an IMMEDIATE word — it runs at interpret time, after the word definition is complete (e.g., `: FOO ... ; IMMEDIATE`). The `;` returns to interpret mode, then IMMEDIATE executes normally.

### COMPILE, Implementation

`COMPILE,` is the ANS standard word that compiles an xt into the current definition. In direct-threaded Forth, this is functionally identical to `,` (store cell at HERE and advance), but it's a separate word for semantic clarity and standards compliance.

```z80
w_COMPILE_COMMA:
    DEFCODE "COMPILE,", 0
w_COMPILE_COMMA_cf:
    ; ( xt -- ) Compile xt into current definition
    LD      L, (IY+UserArea.here)
    LD      H, (IY+UserArea.here+1)
    LD      (HL), C
    INC     HL
    LD      (HL), B
    INC     HL
    LD      (IY+UserArea.here), L
    LD      (IY+UserArea.here+1), H
    POP     BC                  ; new TOS
    NEXT
```

### POSTPONE Implementation

POSTPONE is an IMMEDIATE CODE word. It must:
1. Parse the next word name from the input stream
2. Look it up with FIND
3. Depending on whether the found word is IMMEDIATE or not, compile differently

**For non-IMMEDIATE words** (flag = -1): Simply compile the xt into the current definition. This is the same as normal compilation — POSTPONE just forces it even though we're in an IMMEDIATE word.

**For IMMEDIATE words** (flag = 1): We need to compile code that will, at runtime, compile the xt. This means compiling `LIT xt COMPILE,` into the thread — at runtime, LIT pushes the xt, then COMPILE, compiles it into whatever definition is being compiled at that point.

POSTPONE is most naturally implemented as a CODE word because it needs to:
- Call WORD and FIND (invoke threaded words from CODE)
- Actually, it's simpler to do the input parsing and FIND lookup in assembly directly

**Approach**: Implement POSTPONE as a DEFCODE IMMEDIATE word. Parse the next space-delimited token from TIB (reuse the same logic as INTERPRET's word parsing — read from TIB at >IN, advance >IN). Then look up in the dictionary using the same hash/chain search that FIND uses.

**Simpler approach**: POSTPONE can be a threaded DEFIMMED word that uses existing WORD, FIND, and conditional logic:

```
: POSTPONE  ( -- )
    ?COMP
    BL WORD FIND          ( xt flag | 0 )
    DUP 0= IF DROP ." ? undefined word" ABORT THEN
    1 = IF                ( xt ; IMMEDIATE word )
        LIT LIT ,         ( compile LIT )
        ,                 ( compile xt )
        LIT COMPILE, ,    ( compile COMPILE, )
    ELSE
        ,                 ( compile xt directly )
    THEN
; IMMEDIATE
```

However, this definition uses `."` which is also being implemented in this story. So use assembly error printing instead.

**Recommended approach**: Implement as DEFCODE IMMEDIATE. Use assembly to:
1. Save DE (IP) since we'll be doing work that may clobber it
2. Parse next token from TIB manually (read >IN, scan for space/end, extract name)
3. Call hash_name and walk the dictionary chain (reuse code patterns from FIND)
4. Based on IMMEDIATE flag, compile either `xt` or `LIT xt COMPILE,` at HERE

**Alternative cleaner approach**: Implement as a DEFIMMED (threaded IMMEDIATE) word using existing primitives. Use a different error reporting mechanism:

```z80
w_POSTPONE:
    DEFIMMED "POSTPONE"
w_POSTPONE_body:
w_POSTPONE_cf EQU w_POSTPONE_body - 3
    DW w_QCOMP_cf                ; compile-only guard
    DW w_LIT_cf, 32              ; BL (space character = 0x20)
    DW w_WORD_cf                 ; parse next token → counted string at HERE
    DW w_FIND_cf                 ; ( c-addr 0 | xt 1 | xt -1 )
    DW w_DUP_cf
    DW w_QBRANCH_cf              ; if flag=0 (not found)
    DW .postpone_notfound - $
    ; flag is non-zero: word found
    DW w_LIT_cf, 1
    DW w_EQUALS_cf               ; flag == 1? (IMMEDIATE?)
    DW w_QBRANCH_cf
    DW .postpone_normal - $
    ; IMMEDIATE word: compile LIT xt COMPILE,
    DW w_LIT_cf, w_LIT_cf
    DW w_COMMA_cf                ; compile LIT
    DW w_COMMA_cf                ; compile xt (already on stack)
    DW w_LIT_cf, w_COMPILE_COMMA_cf
    DW w_COMMA_cf                ; compile COMPILE,
    DW w_BRANCH_cf
    DW .postpone_done - $
.postpone_normal:
    ; Non-IMMEDIATE word: compile xt directly
    DW w_COMMA_cf
    DW w_BRANCH_cf
    DW .postpone_done - $
.postpone_notfound:
    DW w_DROP_cf                 ; drop the 0 flag (c-addr already consumed by FIND? no — FIND returns c-addr 0 when not found)
    ; FIND returns (c-addr 0) on failure — drop c-addr and flag
    DW w_DROP_cf
    DW w_ABORT_cf                ; ABORT (will print ? message from INTERPRET's error path)
.postpone_done:
    DW EXIT_CODE
```

**Critical note about FIND semantics**: Per `src/dictionary.asm:118-129`, FIND returns:
- `(c-addr 0)` if not found — c-addr is the original counted string address
- `(xt 1)` if found and IMMEDIATE
- `(xt -1)` if found and not IMMEDIATE

So the not-found branch needs to DROP both c-addr and 0. But there's a problem: `DUP` duplicates the flag, so after the `?BRANCH` we have `(xt flag flag)` or `(c-addr 0 0)`. Let me reconsider the thread:

```
?COMP BL WORD FIND     ( c-addr 0 | xt 1 | xt -1 )
DUP 0= IF              ( c-addr 0 | xt flag )
  ; not found path: ( c-addr 0 )
  DROP DROP ABORT       ; or better: call the error handler
ELSE
  ; found path: ( xt flag )
  1 = IF
    ; IMMEDIATE: compile [LIT xt COMPILE,]
    LIT w_LIT_cf ,      ; compile LIT
    ,                    ; compile xt
    LIT w_COMPILE_COMMA_cf ,  ; compile COMPILE,
  ELSE
    ; normal: compile xt
    ,
  THEN
THEN
```

Actually, the 0= test consumes the DUP'd flag and leaves a boolean. Let me write the thread more carefully using ?BRANCH:

```
( c-addr 0 | xt flag )       ; after FIND
DUP                           ; ( c-addr 0 0 | xt flag flag )
?BRANCH .notfound             ; branch if flag=0 → ( c-addr 0 ) or fall through → ( xt flag )
; Found path: ( xt flag )
LIT 1 =                      ; ( xt flag==1? )
?BRANCH .compile_normal       ; branch if not IMMEDIATE → ( xt )
; IMMEDIATE path: ( xt )
LIT w_LIT_cf ,                ; compile LIT at HERE
,                              ; compile xt at HERE
LIT w_COMPILE_COMMA_cf ,       ; compile COMPILE, at HERE
BRANCH .done
.compile_normal:               ; ( xt )
,                              ; compile xt directly
BRANCH .done
.notfound:                     ; ( c-addr 0 )
DROP DROP                      ; clean stack
; Print error — can't use ." yet. Use a CODE helper or just ABORT.
ABORT
.done:
EXIT
```

Wait, there's an issue. After `DUP ?BRANCH`:
- If flag=0: we branch to .notfound with `(c-addr 0)` on stack (DUP added a 0, ?BRANCH consumed it, leaving `c-addr 0`)
- If flag!=0: fall through with `(xt flag)` on stack (DUP added flag, ?BRANCH consumed the copy, leaving `xt flag`)

That's correct. Then `LIT 1 =` tests if flag=1:
- If flag=1 (IMMEDIATE): fall through with `(xt)` — wait, `=` consumes both operands and pushes a boolean. So stack is `(xt true/false)`. Then ?BRANCH consumes the boolean. If true (IMMEDIATE), fall through with `(xt)`. If false, branch with `(xt)`.

Hmm, that's wrong. `=` needs two operands: `flag` and `1`. Stack before `=` is `(xt flag 1)`, after `=` is `(xt flag==1?)`. Then ?BRANCH consumes the boolean, leaving `(xt)` in both paths. That's correct.

Let me trace through more carefully:

```
FIND                          ; ( c-addr 0 | xt 1 | xt -1 )
DUP                           ; ( c-addr 0 0 | xt 1 1 | xt -1 -1 )
?BRANCH .notfound             ; if TOS=0, branch; consumes TOS
                              ; fall-through: ( xt 1 | xt -1 )
                              ; branch: ( c-addr 0 )
LIT 1 =                      ; ( xt flag==1? )  ; true=-1 or false=0
?BRANCH .compile_normal       ; if false (not IMMEDIATE), branch
                              ; fall-through: ( xt )  — IMMEDIATE
                              ; branch: ( xt )  — normal
```

Yes, this is correct. Both paths after the second ?BRANCH have `(xt)` on the stack.

This approach works. Now let me think about whether to implement POSTPONE as DEFIMMED (threaded) or DEFCODE (assembly).

Given that Story 3.4 found that threaded DEFIMMED words work well (DO, LOOP, +LOOP, LEAVE), and POSTPONE composes existing primitives (WORD, FIND, COMMA, LIT), a **DEFIMMED** approach is cleaner and less error-prone. The only concern is error handling for the not-found case — for now, just ABORT (which will display whatever error context ABORT provides).

Actually, there's a subtle issue. After `WORD`, HERE has been modified (WORD writes the counted string at HERE). Then FIND uses that string. But then when we compile something at HERE using `,`, we're overwriting the string that WORD placed there. That's fine because FIND has already consumed it — FIND reads the counted string, searches the dictionary, and returns the xt. The string at HERE is transient.

Wait — but FIND takes `c-addr` (address of counted string) and searches. After FIND returns, we don't need the counted string anymore. When we call `,` (COMMA), it writes at HERE and advances HERE. The old counted string at HERE is overwritten, but that's fine.

Actually, let me reconsider. WORD writes the counted string at HERE. FIND takes c-addr (which is HERE). After FIND, we have xt and flag on the stack. Then `,` writes at HERE. But HERE hasn't moved after WORD — WORD writes TO HERE but doesn't advance HERE. So the first `,` after FIND would overwrite the start of the counted string. That's fine because we're done with it.

But there's another subtlety: `,` writes at HERE and advances HERE by 2. If we're inside a colon definition (which we must be, since POSTPONE is compile-only), we're compiling into the definition being built. The WORD buffer at HERE is being used as scratch — and `,` would write the xt over the first 2 bytes of the WORD buffer. Since we're done with the buffer, this is fine.

Actually wait — WORD writes to HERE, but in compile mode, the definition being built is at HERE. So WORD's output and the definition body share the same space? That seems wrong.

Let me re-read how WORD works in the existing code. From architecture: "WORD parses to HERE (standard transient buffer)". And from the existing INTERPRET flow: INTERPRET calls WORD, which writes the counted string at HERE. Then FIND looks it up. If found, and we're in compile mode, `,` writes the xt at HERE. But the counted string is still there...

Actually, this is standard Forth behaviour. HERE is used as a transient buffer by WORD. When you compile with `,`, the new cell is written at HERE and HERE advances. The transient string gets overwritten, but it's already been consumed by FIND. This is the normal Forth execution model — the same address space serves double duty.

So the DEFIMMED approach for POSTPONE works correctly.

Let me also think about the `S"` implementation more carefully.

### S" Implementation Details

S" is tricky because it needs dual-mode behaviour:

**Compile mode**: Compile `(S")` xt, then copy the string (count byte + characters) inline into the definition, then cell-align HERE.

**Interpret mode**: Copy the string to a transient buffer, push c-addr u. The standard says the string is valid until the next S" or buffer-affecting operation.

S" needs to parse characters from the input stream up to the closing `"`. This is NOT the same as WORD (which parses whitespace-delimited tokens). S" parsing:
1. Skip exactly one space after `S"` (per ANS standard)
2. Read all characters until `"` is encountered
3. The `"` itself is consumed but not included in the string

This parsing is best done in assembly because it requires direct TIB access and byte-level string manipulation. A CODE word is appropriate.

For compile mode, S" needs to:
1. Compile the `(S")` xt at HERE
2. Write the count byte at HERE
3. Copy string characters to HERE
4. Pad to cell alignment (even address)
5. Update HERE

For interpret mode, S" needs to:
1. Copy the string to a static buffer (e.g., `s_quote_buf` — a fixed-size buffer, say 256 bytes)
2. Push the buffer address + 1 (past count byte) and the count to the data stack

**Cell alignment**: After the count byte and string bytes, if the total byte count (1 + string_length) is odd, add a padding byte. This ensures the next compiled cell starts at an even address. Actually, for Z80 there's no alignment requirement — the Z80 handles unaligned 16-bit accesses. But it's conventional in threaded Forth to keep the thread cell-aligned. Let me check whether the existing code assumes alignment...

Looking at the architecture doc: "ALIGN ALIGNED" are listed in memory.asm's word list. But looking at how LIT, BRANCH, etc. work — they read 16-bit values from arbitrary IP positions using `LD E,(HL); INC HL; LD D,(HL)` byte-by-byte fetches, not 16-bit loads. So the thread does NOT require alignment on Z80. The inline string bytes can be an odd number without breaking anything.

However, the standard says the compiled form should be "implementation-defined". For simplicity and to match common Forth implementations, I'll use: count byte + string bytes, with NO alignment padding. The `(S")` runtime just reads the count, computes the end address, and sets IP to past the string. Since IP advances byte-by-byte through the inline data, no alignment is needed.

Wait, but the thread is made of cells (2 bytes each). After `(S")`, the inline data starts. The runtime needs to know where the next thread cell begins after the string. If the string is "Hello" (5 chars), the inline data is: 05 48 65 6C 6C 6F (6 bytes = count + chars). The next cell starts 6 bytes after the count byte. 6 is even, so it's naturally aligned. But "Hi" (2 chars) would be: 02 48 69 (3 bytes). The next cell starts 3 bytes after — odd offset. The thread cell at that odd address would still work on Z80 (byte-by-byte fetch), but it's unconventional.

To be safe and conventional, I'll pad to even: after count + chars, if total is odd, add one padding byte. This keeps the thread naturally cell-aligned.

### (S") Runtime

```z80
w_PAREN_S_QUOTE:
    DEFCODE '(S")', 0
w_PAREN_S_QUOTE_cf:
    ; ( -- c-addr u )
    ; IP (DE) points to count byte of inline string
    PUSH    BC                  ; save old TOS
    ; Read count byte
    LD      A, (DE)
    LD      C, A
    LD      B, 0                ; BC = u (count) = new TOS
    ; c-addr = DE + 1 (first char after count byte)
    INC     DE
    PUSH    DE                  ; push c-addr to stack (under TOS)
    ; Advance IP past string: DE = DE + count
    ADD     A, E
    LD      E, A
    JR      NC, .no_carry
    INC     D
.no_carry:
    ; Cell-align: if DE is odd, increment by 1
    BIT     0, E
    JR      Z, .aligned
    INC     DE
.aligned:
    ; DE = new IP, pointing to next thread cell
    NEXT
```

Wait, the stack order is wrong. We need `( -- c-addr u )` where u is TOS (BC). But I pushed old TOS, then pushed c-addr. So the stack (bottom to top) is: ...old_TOS, c-addr. And BC = u. So:
- BC = u (TOS)
- (SP) = c-addr (second on stack)
- (SP+2) = old TOS

But the calling word expects `c-addr u` — c-addr below u. So the stack is: ...old_things, c-addr, u(BC). This is `( -- c-addr u )`. Correct!

Wait, but `PUSH DE` pushes what? DE at that point is IP+1 (after the INC DE). We want c-addr to be the address of the first character, which IS IP+1 (DE after the INC). So PUSH DE pushes the correct c-addr. Then we advance DE past the string. BC has the count. This is correct.

Hmm, but there's a subtlety. After the PUSH BC (save old TOS), the parameter stack has old TOS on top. Then PUSH DE puts c-addr on top. So: SP -> [c-addr, old_TOS, ...]. And BC = u. This gives us:

Stack (with BC=TOS convention): u (BC), c-addr (SP), old_TOS (SP+2), ...

In Forth stack notation, reading bottom-up from where we started: old_items, c-addr, u(TOS). Which is `( -- c-addr u )`. Correct!

### ." Implementation

`."` compiles `(S")` + inline string + `TYPE`. It's compile-only (no interpret-mode behaviour per ANS — `."` is only valid in definitions).

Since both S" (compile mode) and ." share the same compilation logic (compile (S") + inline string), the dev should factor the string-compilation into a shared assembly subroutine called by both.

### WORDS Implementation

WORDS traverses all 64 hash buckets and prints every word name. This is a simple CODE word:

```z80
w_WORDS:
    DEFCODE "WORDS", 0
w_WORDS_cf:
    ; ( -- )
    ; Loop through all 64 hash buckets
    LD      HL, hash_table
    LD      A, HASH_BUCKETS     ; 64
.bucket_loop:
    PUSH    AF                  ; save bucket counter
    PUSH    HL                  ; save bucket pointer
    ; Load bucket head
    LD      E, (HL)
    INC     HL
    LD      D, (HL)             ; DE = chain head
    ; Walk chain
.chain_loop:
    LD      A, D
    OR      E
    JR      Z, .next_bucket     ; if DE=0, end of chain
    ; DE = entry address
    ; entry+2 = count_flags
    PUSH    DE                  ; save entry pointer
    INC     DE
    INC     DE
    LD      A, (DE)             ; A = count_flags
    ; Check SMUDGE — skip smudged entries
    BIT     6, A                ; F_SMUDGE = bit 6
    JR      NZ, .skip_entry
    AND     F_LENMASK           ; A = name length
    INC     DE                  ; DE = first name char
    ; Print A characters starting at DE
    LD      B, A                ; B = char count
.print_loop:
    PUSH    BC
    PUSH    DE
    BDOS_SAVE
    LD      A, (DE)
    LD      E, A
    LD      C, C_WRITE
    CALL    0x0005
    BDOS_RESTORE
    POP     DE
    POP     BC
    INC     DE
    DJNZ    .print_loop
    ; Print a space
    PUSH    DE
    BDOS_SAVE
    LD      E, ' '
    LD      C, C_WRITE
    CALL    0x0005
    BDOS_RESTORE
    POP     DE
.skip_entry:
    POP     DE                  ; restore entry pointer
    ; Follow hash_link: entry+0,1
    LD      A, (DE)
    INC     DE
    LD      D, (DE)
    LD      E, A                ; DE = next entry (via hash_link)
    JR      .chain_loop
.next_bucket:
    POP     HL                  ; restore bucket pointer
    INC     HL
    INC     HL                  ; advance to next bucket
    POP     AF                  ; restore counter
    DEC     A
    JR      NZ, .bucket_loop
    ; Print CR/LF
    BDOS_SAVE
    LD      E, 13
    LD      C, C_WRITE
    CALL    0x0005
    LD      E, 10
    LD      C, C_WRITE
    CALL    0x0005
    BDOS_RESTORE
    NEXT
```

Note: WORDS uses BDOS_SAVE/BDOS_RESTORE which saves/restores DE (IP) and BC (TOS). This is important because we're using DE and BC as scratch registers in the loop. The BDOS_SAVE at the start of each BDOS call saves the current DE/BC values; BDOS_RESTORE restores them. But DE isn't IP in this context — we're using it as a chain pointer. So we need to be careful.

Actually, looking at the BDOS_SAVE/BDOS_RESTORE macros (`src/macros.asm:137-148`), they push/pop BC and DE onto the parameter stack (SP). That means they save/restore whatever is in those registers at the time of the call. Since we're using DE as a chain pointer during WORDS, BDOS_SAVE/RESTORE will correctly save/restore our chain pointer across the BDOS call.

BUT: there's a subtlety. The real IP (DE during normal threading) needs to be preserved across the entire WORDS execution. Since WORDS is a CODE word, DE=IP on entry and must equal IP on exit (before NEXT). We need to save DE (IP) at the start of WORDS and restore it before NEXT. Use a scratch cell or PUSH to the return stack.

Wait — actually, BDOS_SAVE saves DE to the parameter stack. But we're also using PUSH/POP on SP for our own loop variables. This could get messy. Let me think about this more carefully.

WORDS as a CODE word needs to:
1. Save IP (DE) — stash somewhere safe
2. Use DE, HL, BC as scratch for the bucket/chain traversal
3. For each BDOS call, save/restore the scratch registers
4. Restore IP (DE) before NEXT

The cleanest approach: save DE (IP) to a scratch cell at the start, then freely use all registers. Before each BDOS call, manually save what we need (since BDOS_SAVE/RESTORE may not align with our register usage).

Actually, let me reconsider. BDOS_SAVE pushes DE then BC. BDOS_RESTORE pops BC then DE. If we:
1. Save real IP in `words_saved_ip`
2. Use DE freely as chain pointer
3. Before each BDOS call: BDOS_SAVE (pushes our DE/BC), do BDOS call, BDOS_RESTORE (restores our DE/BC)
4. Before NEXT: restore DE from `words_saved_ip`

This works because BDOS_SAVE/RESTORE save whatever is in DE/BC, which is our scratch values, not necessarily IP or TOS. The BDOS call clobbers registers, but BDOS_RESTORE puts our scratch values back.

This is the correct approach.

### S" Compile Mode — Shared String Compilation Routine

Both S" (compile mode) and ." need to:
1. Compile `(S")` xt at HERE
2. Parse characters from TIB up to `"`
3. Write count byte + string bytes at HERE
4. Pad to cell-aligned (even address)
5. Update HERE

Factor this into an assembly subroutine `compile_string`:

```z80
; compile_string — shared by S" and ."
; Input: none (reads from TIB at >IN)
; Output: string compiled at HERE; HERE updated
; Clobbers: A, HL, BC (caller must save as needed)
compile_string:
    ; Compile (S") xt at HERE
    LD      L, (IY+UserArea.here)
    LD      H, (IY+UserArea.here+1)
    LD      (HL), LOW w_PAREN_S_QUOTE_cf
    INC     HL
    LD      (HL), HIGH w_PAREN_S_QUOTE_cf
    INC     HL
    ; HL = address for count byte
    PUSH    HL                  ; save count byte address
    INC     HL                  ; HL = first char destination
    ; Parse from TIB: skip one leading space, copy until "
    ; Read >IN, TIB addr, TIB len
    LD      E, (IY+UserArea.tib_in)
    LD      D, (IY+UserArea.tib_in+1)
    ; DE = >IN offset; need TIB base address
    LD      C, (IY+UserArea.tib_addr)
    LD      B, (IY+UserArea.tib_addr+1)
    ; Source address = TIB + >IN
    PUSH    HL                  ; save dest
    LD      H, B
    LD      L, C
    ADD     HL, DE              ; HL = TIB + >IN = current parse position
    ; Skip one leading space (per ANS S" spec)
    LD      A, (HL)
    CP      ' '
    JR      NZ, .no_skip
    INC     HL
    INC     DE                  ; advance >IN
.no_skip:
    ; Now copy characters until " or end of input
    EX      (SP), HL            ; HL = dest, (SP) = source
    POP     BC                  ; BC = source (just swapped)
    ; Wait, this is getting messy. Let me use a cleaner register allocation.
    ...
```

This is getting complex. The dev should implement this as clean assembly with clear register allocation. The key operations are:
1. Read characters from TIB starting at current >IN
2. Skip one space
3. Copy characters to HERE+2 (past the (S") xt cell) until `"` found
4. Write count byte
5. Cell-align
6. Update HERE and >IN

### S" Interpret Mode

In interpret mode, S" copies the string to a static buffer and pushes c-addr u. Use a fixed buffer:

```z80
s_quote_buf: DS 258  ; 1 count byte + 256 chars + 1 padding
```

The string is valid until the next S" or buffer operation. Standard Forth behaviour.

### Project Structure Notes

- `src/compiler.asm` — Add IMMEDIATE, COMPILE, and POSTPONE
- `src/strings.asm` — Add (S"), S", ."
- `src/dictionary.asm` — Add WORDS
- `Makefile` — Append REPL tests 65–77
- No new source files needed
- No changes to `src/antforth.asm` include order

### Anti-Patterns to Avoid

1. **Do NOT implement IMMEDIATE as IMMEDIATE** — IMMEDIATE is a regular (non-IMMEDIATE) word. It runs at interpret time after `;`. Making it IMMEDIATE would be wrong.

2. **Do NOT forget `EQU body - 3`** for DEFIMMED words — per memory `feedback_defword_cf_label.md`, the `_cf` label must point to `JP DOCOL`, not the body. POSTPONE uses DEFIMMED and needs this.

3. **Do NOT clobber DE (IP) in CODE words** without saving/restoring — WORDS and S" both need extensive scratch register usage. Save IP to a scratch cell before using DE.

4. **Do NOT use `."` inside POSTPONE's error handling** — `."` is being implemented in the same story. Use ABORT (which already prints the error context) or a pre-existing error printing mechanism.

5. **Do NOT forget to skip the leading space** in S" parsing — per ANS standard, one space after the `S"` token is consumed as a delimiter, not included in the string.

6. **Do NOT assume cell alignment is required** — Z80 handles unaligned 16-bit reads fine, but pad to even addresses anyway for convention and cleanliness.

7. **Do NOT make `."` work in interpret mode** — per ANS, `."` is compile-only. Only S" has dual-mode behaviour.

8. **Do NOT compile tests into the regression test thread** — per memory `feedback_repl_tests_preferred.md`, new tests go into the `test-repl` Makefile target (starting at test 65).

9. **Do NOT create separate helper words** for string compilation — use an internal assembly subroutine (shared label, not a dictionary entry) called by both S" and ." for the compile-mode logic.

10. **Do NOT forget BDOS_SAVE/BDOS_RESTORE** in WORDS — every BDOS call must use the wrapper. WORDS makes many BDOS calls in a loop.

11. **Do NOT forget to handle the `"` character in word names** — S" is a word named `S"` (S followed by quote). The DEFCODE macro should handle this via the string argument. Verify sjasmplus handles the quote in `DEFCODE 'S"', F_IMMEDIATE` (use single quotes around the name if needed).

12. **Do NOT forget the `COMPILE,` word** — POSTPONE of IMMEDIATE words compiles `LIT xt COMPILE,` into the thread. COMPILE, must exist as a separate word.

13. **Do NOT assume WORD modifies HERE** — WORD writes a counted string AT HERE (using HERE as a transient buffer) but does not advance HERE. Subsequent `,` operations compile over the WORD buffer space, which is fine because FIND has already consumed the string.

### Register Contract Reminders

CODE words in this story that must preserve the register contract across `NEXT`:

| Word | Clobbers (OK) | Must preserve |
|------|----------------|---------------|
| `IMMEDIATE` | A, HL | BC=TOS, DE=IP, IX, IY |
| `COMPILE,` | A, HL, BC (new TOS from pop) | DE=IP, IX, IY |
| `(S")` | A, HL, DE (advanced as IP) | BC=new TOS, IX, IY |
| `S"` (compile) | A, HL, BC, DE (save/restore IP) | DE=IP (restore before NEXT), IX, IY |
| `S"` (interpret) | A, HL, BC, DE (save/restore IP) | DE=IP (restore before NEXT), IX, IY |
| `."` | Same as S" compile mode | DE=IP (restore before NEXT), IX, IY |
| `WORDS` | A, HL, BC, DE (save/restore IP) | DE=IP (restore before NEXT), IX, IY |

The threaded DEFIMMED words (POSTPONE) automatically preserve the register contract.

### File Locations

| Word | File | Type | Notes |
|------|------|------|-------|
| `IMMEDIATE` | `src/compiler.asm` | DEFCODE | Sets F_IMMEDIATE on LATEST |
| `COMPILE,` | `src/compiler.asm` | DEFCODE | Compiles xt at HERE |
| `POSTPONE` | `src/compiler.asm` | DEFIMMED | Compile-only, uses WORD/FIND |
| `(S")` | `src/strings.asm` | DEFCODE | String literal runtime |
| `S"` | `src/strings.asm` | DEFCODE F_IMMEDIATE | Dual-mode string literal |
| `."` | `src/strings.asm` | DEFCODE F_IMMEDIATE | Compile-only string print |
| `WORDS` | `src/dictionary.asm` | DEFCODE | Dictionary listing |

`Makefile` — append REPL tests 65–77.

### Testing Strategy

**Primary: REPL-piped tests** (per memory `feedback_repl_tests_preferred.md`).

New tests start at test **65** (test 64 was the last in Story 3.4). Do NOT add to the assembly regression thread.

For IMMEDIATE testing: define a word, call IMMEDIATE, then use the word inside a definition to verify it executes at compile time rather than being compiled.

For POSTPONE testing: use POSTPONE with both IMMEDIATE and non-IMMEDIATE words to verify deferred compilation behaviour.

For S" testing: test both compile mode (inside `:` definitions) and interpret mode (at the REPL). Verify string contents and lengths.

For `."` testing: test inside definitions only (it's compile-only). Test error message when used in interpret mode.

For WORDS testing: run WORDS and verify output contains known word names.

### Previous Story Intelligence (from Story 3.4)

- DEFIMMED words work correctly when following `EQU body - 3` convention and starting with `DW w_QCOMP_cf`.
- The LEAVE-chain approach (using a dedicated assembly cell rather than pure compile-time stack) solved a nesting issue with IF/THEN inside loops. If POSTPONE's threaded implementation hits similar issues with compile-time stack interference, consider a similar dedicated-cell approach.
- CODE IMMEDIATE words (like RECURSE) that need direct IY/HERE access work well as assembly implementations with a scratch cell for IP preservation.
- All REPL tests use `grep -q` with specific patterns; for string tests, anchor patterns to avoid substring false positives (lesson from code review round in 3.4).

### Git Intelligence

Recent commits (last 5):
- `78a1c45` completed story 3.4
- `a839099` completed story 3.3
- `38c7c02` completed story 3.2
- `8859897` code review story 3.1
- `6321680` completed story 3.1

Story 3.4 is the most recent work. All tests pass (1-64).

### References

- [Source: src/compiler.asm:349-386] — `;` (SEMICOLON) with F_IMMEDIATE flag
- [Source: src/compiler.asm:389-408] — `[` and `]` words
- [Source: src/compiler.asm:411-435] — LITERAL (IMMEDIATE CODE word pattern)
- [Source: src/compiler.asm:194-196] — LATEST updated by build_header
- [Source: src/constants.asm:33-35] — F_IMMEDIATE, F_SMUDGE, F_LENMASK
- [Source: src/dictionary.asm:19-153] — FIND with IMMEDIATE flag checking
- [Source: src/dictionary.asm:47] — hash_table label (64 buckets)
- [Source: src/outer_interpreter.asm:144-229] — INTERPRET handling STATE and IMMEDIATE
- [Source: src/outer_interpreter.asm:236-271] — QUIT loop
- [Source: src/strings.asm:10-163] — WORD (parse to HERE)
- [Source: src/io.asm:24-56] — TYPE (c-addr u --)
- [Source: src/memory.asm:92-131] — HERE and COMMA
- [Source: src/inner_interpreter.asm:85-94] — LIT
- [Source: src/control_flow.asm:10] — ?COMP (compile-only guard)
- [Source: src/structures.asm:18-27] — UserArea layout (state, here, latest, tib_in, tib_addr, tib_len)
- [Source: src/macros.asm:58-135] — DEFCODE, DEFWORD, DEFIMMED macros
- [Source: src/macros.asm:137-148] — BDOS_SAVE/BDOS_RESTORE
- [Source: _bmad-output/planning-artifacts/architecture.md#Kernel/Forth Boundary] — WORDS, control-flow compilers are Forth-level
- [Source: _bmad-output/planning-artifacts/architecture.md#String Storage] — Inline strings with count byte
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.5] — Story requirements and BDD criteria
- [Source: _bmad-output/implementation-artifacts/3-4-counted-loops-and-recurse.md] — Previous story intelligence

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Initial POSTPONE had IMMEDIATE/non-IMMEDIATE semantics swapped: was compiling xt directly for IMMEDIATE words and LIT/COMPILE, for non-IMMEDIATE. Corrected per ANS standard: non-IMMEDIATE gets LIT xt COMPILE, (deferred compilation), IMMEDIATE gets xt directly (compilation semantics = execute).
- sjasmplus does not support `LD DE, (addr)` — used `LD HL, (addr)` + register moves for WORDS chain following.
- NIP word not available — tests 71 and 76 use SWAP DROP instead.

### Completion Notes List

- IMMEDIATE: Simple DEFCODE that ORs F_IMMEDIATE onto LATEST's count_flags byte
- COMPILE,: DEFCODE that writes TOS (xt) at HERE and advances HERE by 2 (functionally identical to COMMA but semantically distinct per ANS)
- POSTPONE: Implemented as DEFIMMED (threaded IMMEDIATE word) using BL WORD FIND to parse and look up the next token, then conditionally compiles xt directly (IMMEDIATE words) or LIT xt COMPILE, (non-IMMEDIATE words)
- (S"): DEFCODE runtime that reads inline counted string from thread, pushes c-addr u, advances IP past string with cell alignment
- S": DEFCODE IMMEDIATE with dual-mode behaviour. Compile mode uses shared compile_string subroutine. Interpret mode copies string to static s_quote_buf (258 bytes)
- .": DEFCODE IMMEDIATE, compile-only. Uses shared compile_string subroutine then compiles TYPE xt after the string
- WORDS: DEFCODE that traverses all 64 hash buckets, walks each chain, prints non-smudged word names with spaces, ends with CR/LF. Uses scratch cells for IP preservation and loop state.
- compile_string: Internal assembly subroutine shared by S" and ." for compile-mode string compilation. Compiles (S") xt + count byte + string bytes + cell alignment padding at HERE.
- 15 REPL tests (65-79) covering all acceptance criteria

### Change Log

- 2026-04-10: Implemented story 3.5 — IMMEDIATE, POSTPONE, COMPILE,, (S"), S", .", WORDS + 13 REPL tests
- 2026-04-10: Code review fixes — POSTPONE not-found uses COMP-ERROR for proper cleanup; 16-bit safe remaining count in compile_string and S" interpret mode; S" interpret buffer bounds check; added tests 78-79

### Senior Developer Review (AI)

**Reviewer:** Ant (via Claude Opus 4.6)
**Date:** 2026-04-10

**Issues Found & Fixed:**

1. **[HIGH] POSTPONE not-found path used ABORT instead of COMP-ERROR** — Left corrupted dictionary state (smudged entry, wrong HERE). Fixed: now calls COMP-ERROR which properly restores HERE, unlinks hash entry, prints error message, and aborts.

2. **[MEDIUM] No test for POSTPONE with undefined word** — Added test 78: `: BAD POSTPONE XYZZY ;` verifies error message and recovery.

3. **[MEDIUM] POSTPONE not-found gave no diagnostic** — Fixed by #1 (COMP-ERROR prints `XYZZY ?`).

4. **[MEDIUM] compile_string/S" interpret only used low byte for remaining count** — Used 8-bit `SUB` on 16-bit tib_len/tib_in fields. Fixed with 16-bit subtraction + clamp to 255.

5. **[LOW] COMPILE, not directly tested** — Added test 79: COMP-SWAP via POSTPONE exercises the LIT/COMPILE, path.

6. **[LOW] S" interpret buffer had no bounds check** — Added B<255 guard to prevent s_quote_buf overrun.

**Outcome:** All issues fixed. All 79 REPL tests + regression tests pass.

### File List

- src/compiler.asm (modified) — added POSTPONE, COMPILE,, IMMEDIATE; review fix: POSTPONE not-found uses COMP-ERROR
- src/strings.asm (modified) — added (S"), compile_string, S", .", s_quote_buf; review fix: 16-bit remaining count, buffer bounds check
- src/dictionary.asm (modified) — added WORDS
- Makefile (modified) — added REPL tests 65-79
