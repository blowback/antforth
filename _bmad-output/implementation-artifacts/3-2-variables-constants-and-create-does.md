# Story 3.2: Variables, Constants & CREATE/DOES>

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to create variables, constants, and custom defining words,
so that I can manage data and build higher-level data structures.

## Acceptance Criteria

1. **Given** the user types `VARIABLE COUNTER` **When** the definition completes **Then** COUNTER is added to the dictionary with `JP DOVAR` code field and a 2-byte body initialised to 0 **And** typing `COUNTER` pushes the address of the body to the stack **And** `42 COUNTER !` stores 42, and `COUNTER @` retrieves 42

2. **Given** the user types `99 CONSTANT LIMIT` **When** the definition completes **Then** LIMIT is added to the dictionary with `JP DOCON` code field and the value 99 in the body **And** typing `LIMIT .` outputs `99`

3. **Given** the user types `CREATE BUFFER 100 ALLOT` **When** the definition completes **Then** BUFFER is added to the dictionary with `JP DOVAR` code field **And** typing `BUFFER` pushes the address of the 100-byte allocated region

4. **Given** the user defines a custom defining word using CREATE/DOES> **When** e.g., `: ARRAY CREATE CELLS ALLOT DOES> SWAP CELLS + ;` **Then** `10 ARRAY MYDATA` creates a 10-cell array **And** `42 3 MYDATA !` stores 42 at index 3 **And** `3 MYDATA @ .` outputs `42`

5. **Given** DOES> executes within a defining word **When** a child word created by that defining word is called **Then** DOES> switches from CREATE-time behaviour to run-time behaviour, pushing the body address and executing the DOES> code

## Tasks / Subtasks

- [x] Task 1: Implement DOVAR runtime handler in inner_interpreter.asm (AC: #1, #3)
  - [x] 1.1 DOVAR: push body address (HL+5, past does-addr slot) to parameter stack, NEXT
  - [x] 1.2 Add word-level comment with stack effect

- [x] Task 2: Implement DOCON runtime handler in inner_interpreter.asm (AC: #2)
  - [x] 2.1 DOCON: push cell value at body address (HL+3) to parameter stack, NEXT
  - [x] 2.2 Add word-level comment with stack effect

- [x] Task 3: Implement DODOES runtime handler in inner_interpreter.asm (AC: #4, #5)
  - [x] 3.1 DODOES: save IP to return stack, read does-addr from HL+3 into DE (new IP), push body address (HL+5) to parameter stack, NEXT
  - [x] 3.2 Add word-level comment with stack effect

- [x] Task 4: Implement CREATE as a CODE word in compiler.asm (AC: #1, #3)
  - [x] 4.1 Parse next word from input (reuse COLON's parsing pattern)
  - [x] 4.2 Build dictionary header at HERE: hash_link, count_flags (no SMUDGE), name
  - [x] 4.3 Emit code field: `JP DOVAR` (3 bytes) + `0x00, 0x00` (2-byte does-addr slot)
  - [x] 4.4 Update hash bucket head to point to this new entry
  - [x] 4.5 Update LATEST to point to this new entry
  - [x] 4.6 Update HERE to cf+5 (body starts after JP + does-addr slot — user can ALLOT after)
  - [x] 4.7 Do NOT enter compile mode — CREATE returns to interpret mode

- [x] Task 5: Implement VARIABLE as a DEFWORD in bootstrap.asm (AC: #1)
  - [x] 5.1 Forth-level: `CREATE 0 ,` — creates entry via CREATE, then zero-inits a 2-byte body via COMMA

- [x] Task 6: Implement CONSTANT as a CODE word in compiler.asm (AC: #2)
  - [x] 6.1 Parse name and build dictionary header (same as CREATE)
  - [x] 6.2 Emit code field: `JP DOCON` (instead of DOVAR)
  - [x] 6.3 Emit TOS value into body (2 bytes) — consumes TOS
  - [x] 6.4 Update hash bucket, LATEST, HERE

- [x] Task 7: Implement DOES> and (DOES>) in compiler.asm (AC: #4, #5)
  - [x] 7.1 DOES> (IMMEDIATE CODE word): compile `w_PAREN_DOES_cf` into the current definition. Continue compiling — `;` adds EXIT_CODE at end.
  - [x] 7.2 (DOES>) (CODE word): patches LATEST word's code field from `JP DOVAR` to `JP DODOES`, stores IP (DOES> body addr) at cf+3, then EXITs via return stack pop.

- [x] Task 8: Implement CELLS as a CODE word in memory.asm (AC: #4)
  - [x] 8.1 CELLS: `( n -- n*2 )` — `SLA C` / `RL B`

- [x] Task 9: Add REPL tests (AC: #1-#5)
  - [x] 9.1 Test VARIABLE: `VARIABLE X  42 X !  X @ .` expects `42`
  - [x] 9.2 Test CONSTANT: `99 CONSTANT LIMIT  LIMIT .` expects `99`
  - [x] 9.3 Test CREATE + ALLOT: `CREATE BUF 10 ALLOT  42 BUF !  BUF @ .` expects `42`
  - [x] 9.4 Test CELLS: `5 CELLS .` expects `10`
  - [x] 9.5 Test CREATE/DOES> (ARRAY pattern): `: ARRAY CREATE CELLS ALLOT DOES> SWAP CELLS + ; 10 ARRAY MD  42 3 MD !  3 MD @ .` expects `42`
  - [x] 9.6 Test CONSTANT in colon def: `99 CONSTANT LIM : CHKLIM LIM + ; 1 CHKLIM .` expects `100`
  - [x] 9.7 Test multiple VARIABLEs don't interfere: `VARIABLE A VARIABLE B  10 A !  20 B !  A @ B @ + .` expects `30`

- [x] Task 10: Verify no regressions
  - [x] 10.1 `make test` — all existing regression tests pass
  - [x] 10.2 `make test-repl` — all existing REPL tests pass (tests 1-24)
  - [x] 10.3 `make` — normal REPL build succeeds

## Dev Notes

### What Already Exists (verified from source)

**Ready infrastructure — no changes needed:**
- `DOCOL` (`inner_interpreter.asm:9-20`): Pushes IP to return stack, sets IP to body (HL+3). Fully working.
- `EXIT_CODE` (`inner_interpreter.asm:23-29`): Pops IP from return stack, continues. Label is `EXIT_CODE`.
- `LIT` (`inner_interpreter.asm:35-44`): Pushes inline literal from thread. Label is `w_LIT_cf`.
- `:` (`compiler.asm:15-241`): COLON — builds dictionary headers at runtime. Contains parse-name logic that can be studied/reused.
- `;` (`compiler.asm:322-355`): SEMICOLON — compiles EXIT, clears SMUDGE, exits compile mode.
- `]` (`compiler.asm:372-377`): Enters compile mode.
- `COMMA` / `,` (`memory.asm:119-131`): Stores cell at HERE and advances by 2. Label is `w_COMMA_cf`.
- `HERE` (`memory.asm:92-98`): Pushes current dictionary pointer. Label is `w_HERE_cf`.
- `ALLOT` (`memory.asm:104-113`): Advances HERE by n bytes. Label is `w_ALLOT_cf`.
- `FIND` (`dictionary.asm`): Hash-based lookup, skips SMUDGE'd entries.
- `ABORT` (`system.asm`): Resets SP, jumps to QUIT. Label is `w_ABORT_cf`.
- `hash_name` (`hash.asm`): Runtime hash computation. Call with HL=name addr, B=name len, returns A=bucket index.
- `hash_table` (`antforth.asm:155+`): 64 two-byte bucket head pointers.

**UserArea layout (`structures.asm:18-27`):**
- `UserArea.state` (offset 0): 0=interpret, non-zero=compile
- `UserArea.here` (offset 4): Next free dictionary address
- `UserArea.latest` (offset 6): Most recently defined word
- IY points to `user_area` at runtime

**Dictionary entry structure:**
```
[hash_link (2 bytes)][count_flags (1 byte)][name (n bytes)][code_field (3 bytes: JP xxxx)][body...]
```
- count_flags: bit 7=F_IMMEDIATE (0x80), bit 6=F_SMUDGE (0x40), bits 0-4=name length (F_LENMASK=0x1F)
- Constants: `F_IMMEDIATE=0x80`, `F_SMUDGE=0x40`, `F_LENMASK=0x1F` (`constants.asm:33-35`)

**DOVAR/DOCON/DODOES do NOT exist yet.** These must be created as new runtime handlers in `inner_interpreter.asm`. They are NOT dictionary words — they are bare code targets referenced by `JP` instructions in code fields.

**CELLS does NOT exist yet.** Must be created as a CODE word.

### Code Field Layout (Architecture Reference)

Per architecture.md, every word's code field is a 3-byte `JP xxxx`. HL points to the code field when the runtime handler executes.

**Colon definitions:** `JP DOCOL` — body (thread) at cf+3
**Constants:** `JP DOCON` — value at cf+3

**CREATE-family words** (VARIABLE, CREATE, DOES>-patched):
```
CFA+0: JP DOVAR/DODOES  (3 bytes)
CFA+3: does-addr         (2 bytes, reserved — 0000 if not patched by DOES>)
CFA+5: body data...      (user-visible PFA)
```

CREATE always reserves the 2-byte does-addr slot. DOVAR and DODOES both push cf+5 as the body address. The only difference: DODOES also reads the does-addr at cf+3 and enters the DOES> thread. `(DOES>)` patches `JP DOVAR` to `JP DODOES` and writes the does-addr — no body data is disturbed.

This costs 2 bytes per VARIABLE/CREATE word that never uses DOES>, but eliminates body-address discrepancies entirely.

### DOVAR Implementation

```z80
; === DOVAR — Push variable body address ===
; HL points to code field (JP DOVAR)
; Body = HL+5 (skips 3-byte JP + 2-byte does-addr slot)
DOVAR:
    PUSH    BC              ; Save old TOS
    LD      BC, 5
    ADD     HL, BC          ; HL = body address (cf+5)
    LD      B, H
    LD      C, L            ; BC = body address (new TOS)
    NEXT
```

### DOCON Implementation

```z80
; === DOCON — Push constant value ===
; HL points to code field (JP DOCON), body = HL+3 contains the value
DOCON:
    PUSH    BC              ; Save old TOS
    INC     HL
    INC     HL
    INC     HL              ; HL = body address
    LD      C, (HL)
    INC     HL
    LD      B, (HL)         ; BC = value at body (new TOS)
    NEXT
```

### DODOES Implementation

Same layout as DOVAR — CREATE always reserves the does-addr slot:
```
[header][JP DODOES (3 bytes)][does-addr (2 bytes)][body data...]
         ^cf                  ^cf+3                ^cf+5
```

DODOES pushes cf+5 (same body address as DOVAR) and enters the DOES> thread.

```z80
; === DODOES — Enter DOES> definition, push body address ===
; HL points to code field (JP DODOES)
; cf+3 = does-addr, cf+5 = body
DODOES:
    ; Save IP to return stack (entering a colon-like definition)
    DEC     IX
    DEC     IX
    LD      (IX+0), E
    LD      (IX+1), D
    ; Read does-addr at HL+3
    INC     HL
    INC     HL
    INC     HL              ; HL = &does-addr
    LD      E, (HL)
    INC     HL
    LD      D, (HL)         ; DE = does-addr (new IP)
    INC     HL              ; HL = body address (cf+5)
    ; Push body address as new TOS
    PUSH    BC              ; Save old TOS
    LD      B, H
    LD      C, L            ; BC = body address (new TOS)
    NEXT
```

### DOES> Implementation

DOES> has two components: a compile-time IMMEDIATE word and a `(DOES>)` runtime helper.

#### Compiled Thread of a Defining Word

`: ARRAY CREATE CELLS ALLOT DOES> SWAP CELLS + ;` compiles to:
```
[JP DOCOL]
[w_CREATE_cf]       ; CREATE — makes child with JP DOVAR
[w_CELLS_cf]        ; CELLS
[w_ALLOT_cf]        ; ALLOT
[w_PAREN_DOES_cf]   ; (DOES>) — patches child, then EXITs
[w_SWAP_cf]         ; DOES> body starts here (does-addr points here)
[w_CELLS_cf]
[w_PLUS_cf]
[EXIT_CODE]         ; end of DOES> body
```

#### Execution Flow: `10 ARRAY MYDATA`

1. DOCOL enters ARRAY's thread
2. CREATE makes MYDATA with `JP DOVAR` + `0000` (reserved does-addr) + body at cf+5, updates LATEST
3. CELLS converts 10 to 20, ALLOT advances HERE by 20 (body region: cf+5 to cf+25)
4. `(DOES>)` executes:
   - IP (DE) points to `w_SWAP_cf` — the DOES> body start
   - Finds LATEST's code field via `LATEST + 3 + name_len`
   - Overwrites `JP DOVAR` with `JP DODOES`
   - Writes IP (does-addr) at cf+3 (the reserved slot)
   - EXITs (pops IP from return stack, returns to caller)
5. MYDATA now has: `JP DODOES` + does-addr + 20 bytes body data. Body address unchanged at cf+5.

#### Execution Flow: `3 MYDATA @`

1. NEXT fetches MYDATA's code field -> `JP DODOES`
2. DODOES: saves IP to return stack, reads does-addr from cf+3, sets IP = does-addr, pushes cf+5 (body) as TOS
3. DOES> body executes: `SWAP CELLS +` computes body + 3*2 = address of element 3
4. `@` fetches the value, EXIT returns

#### DOES> Compile-Time Action

DOES> is IMMEDIATE. When encountered during compilation of the defining word, it simply compiles `w_PAREN_DOES_cf` into the thread. The DOES> body that follows continues to be compiled normally. `;` compiles EXIT_CODE at the end.

```z80
w_DOES:
    DEFCODE "DOES>", F_IMMEDIATE
w_DOES_cf:
    ; Compile (DOES>) into current definition
    LD      L, (IY+UserArea.here)
    LD      H, (IY+UserArea.here+1)
    LD      (HL), LOW w_PAREN_DOES_cf
    INC     HL
    LD      (HL), HIGH w_PAREN_DOES_cf
    INC     HL
    LD      (IY+UserArea.here), L
    LD      (IY+UserArea.here+1), H
    NEXT
```

#### (DOES>) Runtime Helper

Finding the code field from LATEST: LATEST points to the dictionary entry (hash_link). Code field = `LATEST + 2 (hash_link) + 1 (count_flags) + name_len` = `LATEST + 3 + name_len`. Read count_flags at LATEST+2, mask with F_LENMASK to get name_len.

```z80
; (DOES>) — Patches LATEST word to use DODOES, then EXITs
w_PAREN_DOES:
    DEFCODE "(DOES>)", 0
w_PAREN_DOES_cf:
    ; DE = IP = address of DOES> body (right after this word in the thread)
    ; Find LATEST word's code field
    LD      L, (IY+UserArea.latest)
    LD      H, (IY+UserArea.latest+1)   ; HL = LATEST (dict entry)
    INC     HL
    INC     HL                           ; HL = &count_flags
    LD      A, (HL)
    AND     F_LENMASK                    ; A = name length
    INC     HL                           ; HL = &name[0]
    ; Skip name bytes to reach code field
    ADD     A, L
    LD      L, A
    JR      NC, .no_carry
    INC     H
.no_carry:                               ; HL = code field address
    ; Overwrite code field with JP DODOES
    LD      (HL), 0xC3                   ; JP opcode
    INC     HL
    LD      (HL), LOW DODOES
    INC     HL
    LD      (HL), HIGH DODOES
    INC     HL
    ; Write does-addr (DE = IP = DOES> body start)
    LD      (HL), E
    INC     HL
    LD      (HL), D
    ; EXIT — return from defining word (pop IP from return stack)
    LD      E, (IX+0)
    LD      D, (IX+1)
    INC     IX
    INC     IX
    NEXT
```

### CREATE Implementation

CREATE builds a dictionary entry at runtime, similar to COLON but simpler:
- **No SMUDGE flag** — the word is immediately findable
- **Code field is `JP DOVAR`** (not `JP DOCOL`)
- **Emits 2 zero bytes** after code field (reserved does-addr slot)
- **Sets HERE to cf+5** (body starts after JP + does-addr slot)
- **Does NOT enter compile mode** — returns to interpreter
- **Does NOT save error recovery state**

CREATE emits 5 bytes total: `JP DOVAR` (3) + `0x00, 0x00` (2). HERE ends up at cf+5.

CREATE reuses the same parse-name + hash + header construction pattern from COLON (`compiler.asm:38-241`). Either duplicate the parsing code (safe, no regressions) or extract a shared `build_header` subroutine (cleaner but requires modifying COLON — run full regression tests if refactoring).

### VARIABLE Implementation

VARIABLE is a Forth-level DEFWORD in `bootstrap.asm`. CREATE already reserves the does-addr slot and sets HERE to cf+5, so VARIABLE just needs to zero-init the 2-byte body:
```
: VARIABLE CREATE 0 , ;
```

```z80
w_VARIABLE:
    DEFWORD "VARIABLE", 0
w_VARIABLE_body:
w_VARIABLE_cf EQU w_VARIABLE_body - 3
    DW w_CREATE_cf
    DW w_LIT_cf, 0
    DW w_COMMA_cf
    DW EXIT_CODE
```

### CONSTANT Implementation

CONSTANT is a CODE word in `compiler.asm` that:
1. Saves TOS (the value) temporarily
2. Parses name and builds dictionary header (same as CREATE)
3. Emits `JP DOCON` as code field (instead of DOVAR)
4. Emits the saved value into body (2 bytes)
5. Updates hash bucket, LATEST, HERE

### CELLS Implementation

```z80
; CELLS ( n -- n*2 )
;   Multiply TOS by cell size (2 bytes)
w_CELLS:
    DEFCODE "CELLS", 0
w_CELLS_cf:
    SLA     C
    RL      B               ; BC = BC * 2
    NEXT
```

### Runtime Handler Summary

| Handler | Location | Triggered by | Action |
|---------|----------|--------------|--------|
| DOVAR | `inner_interpreter.asm` | `JP DOVAR` in code field | Push cf+5 (body addr, past does-addr slot) |
| DOCON | `inner_interpreter.asm` | `JP DOCON` in code field | Push value at cf+3 (no does-addr slot) |
| DODOES | `inner_interpreter.asm` | `JP DODOES` in code field | Push cf+5 (body addr), enter DOES> thread at addr stored at cf+3 |

### Code Field Label Convention (CRITICAL)

Per project convention (memory: feedback_defword_cf_label.md):
- For **DEFWORD** words, `w_XXX_cf` must use `EQU body - 3` to point to `JP DOCOL`, not the body
- For **DEFCODE** words, `w_XXX_cf` is placed right after the DEFCODE macro call
- For **DEFIMMED** words (which expand to DEFWORD with F_IMMEDIATE), same `EQU body - 3` convention

VARIABLE (DEFWORD): follow the `EQU body - 3` pattern.
All new CODE words (CREATE, CONSTANT, DOES>, (DOES>), CELLS): place `w_XXX_cf` after DEFCODE.

### File Locations for New Code

| Word | Type | File | Rationale |
|------|------|------|-----------|
| DOVAR | Runtime handler (bare label) | `inner_interpreter.asm` | Next to DOCOL, EXIT_CODE — same architectural layer |
| DOCON | Runtime handler (bare label) | `inner_interpreter.asm` | Same as DOVAR |
| DODOES | Runtime handler (bare label) | `inner_interpreter.asm` | Same as DOVAR |
| CREATE | CODE word | `compiler.asm` | Dictionary construction, same file as `:` |
| CONSTANT | CODE word | `compiler.asm` | Dictionary construction with `JP DOCON` |
| DOES> | IMMEDIATE CODE word | `compiler.asm` | Compile-time word, near `;` and LITERAL |
| (DOES>) | CODE word | `compiler.asm` | Runtime helper for DOES> |
| VARIABLE | DEFWORD | `bootstrap.asm` | Forth-level word: `CREATE 0 ,` |
| CELLS | CODE word | `memory.asm` | Memory/sizing word, near ALIGNED |

### Parse-Name Reuse in CREATE/CONSTANT

Both CREATE and CONSTANT need to parse a name and build a dictionary header. The COLON word (`compiler.asm:38-241`) contains inline parse-name logic. Options:

1. **Duplicate the parsing code** in CREATE and CONSTANT (safe, no regressions)
2. **Extract a `build_header` subroutine** called by COLON, CREATE, and CONSTANT

If extracting a subroutine, the risk is modifying COLON and breaking Story 3.1. Run `make test` and `make test-repl` after the refactor, before adding new features. Duplication is also acceptable per Story 3.1 review (L2: accepted).

### Testing Strategy

**Primary: REPL-piped tests** (per memory: feedback_repl_tests_preferred.md)

New tests continue from test 25 onwards in Makefile's `test-repl` target.

**Do NOT add tests to the regression test thread** — REPL-piped tests only.

### Anti-Patterns to Avoid

1. **Do NOT forget DOVAR/DOCON/DODOES are bare labels, not dictionary words** — they don't use DEFCODE/DEFWORD. They're jumped to from code fields, not called from threads.
2. **Do NOT forget HL points to code field when runtime handlers execute** — DOVAR/DODOES body = HL+5 (past does-addr slot), DOCON value = HL+3 (no slot)
3. **Do NOT set SMUDGE on CREATE entries** — CREATE words are immediately findable (unlike `:` which hides during compilation)
4. **Do NOT enter compile mode in CREATE** — CREATE returns to interpret mode
5. **Do NOT forget to update LATEST** in CREATE and CONSTANT — `(DOES>)` uses LATEST to find the child word
6. **Do NOT modify COLON without running full regression** — if extracting a shared subroutine, verify all Story 3.1 tests still pass
7. **For DEFWORD words, w_XXX_cf must use `EQU body - 3`** — never point to the body directly (memory: feedback_defword_cf_label.md)
8. **Do NOT add tests to the regression test thread** — use REPL-piped tests only (memory: feedback_repl_tests_preferred.md)
9. **Do NOT use raw BDOS calls** — use BDOS_SAVE/BDOS_RESTORE macros
10. **Do NOT forget to save/restore DE (IP)** in CODE words that use DE as scratch

### Register Contract Reminders

Every CODE word must respect:
- **BC = TOS** on entry and exit
- **DE = IP** — preserve or save/restore
- **SP = parameter stack** — net effect matches stack signature
- **IX = return stack** — preserve unless doing return stack ops
- **IY = user pointer** — preserve unless accessing user variables
- **HL, AF** — free scratch

### Project Structure Notes

- `src/inner_interpreter.asm` — Add DOVAR, DOCON, DODOES after DOCOL/EXIT_CODE (bare labels, not DEFCODE)
- `src/compiler.asm` — Add CREATE, CONSTANT, DOES>, (DOES>) after existing `;`, `[`, `]`, LITERAL
- `src/bootstrap.asm` — Add VARIABLE after existing MAX definition
- `src/memory.asm` — Add CELLS after ALIGNED
- No new files needed — all changes go into existing files
- Include order in `antforth.asm` is already correct: inner_interpreter before compiler before bootstrap

### References

- [Source: src/inner_interpreter.asm:9-20] — DOCOL implementation (pattern for DOVAR/DOCON/DODOES)
- [Source: src/inner_interpreter.asm:23-29] — EXIT_CODE implementation
- [Source: src/compiler.asm:15-241] — COLON implementation (parse-name + header construction model)
- [Source: src/compiler.asm:322-355] — SEMICOLON implementation
- [Source: src/compiler.asm:384-404] — LITERAL implementation
- [Source: src/memory.asm:92-98] — HERE implementation
- [Source: src/memory.asm:104-113] — ALLOT implementation
- [Source: src/memory.asm:119-131] — COMMA implementation
- [Source: src/memory.asm:166-177] — ALIGNED implementation (place CELLS nearby)
- [Source: src/bootstrap.asm:1-68] — Existing DEFWORD definitions (NEGATE, ABS, MIN, MAX)
- [Source: src/structures.asm:18-27] — UserArea struct (state, here, latest offsets)
- [Source: src/constants.asm:33-35] — F_IMMEDIATE, F_SMUDGE, F_LENMASK
- [Source: src/macros.asm:58-94] — DEFCODE macro (dictionary entry construction model)
- [Source: src/macros.asm:96-127] — DEFWORD macro (code field = JP DOCOL)
- [Source: src/antforth.asm:155+] — hash_table runtime storage
- [Source: _bmad-output/planning-artifacts/architecture.md] — Code field layout, register contract, naming conventions
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.2] — Story requirements and BDD criteria

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None — clean implementation, no debug issues encountered.

### Completion Notes List

- Implemented DOVAR, DOCON, DODOES runtime handlers as bare labels in inner_interpreter.asm (not dictionary words — jumped to from code fields)
- Implemented CREATE as CODE word in compiler.asm — duplicated COLON's parse-name pattern (no refactor of COLON to avoid regressions)
- Implemented CONSTANT as CODE word in compiler.asm — same parse-name duplication, emits JP DOCON + value
- Implemented DOES> as IMMEDIATE CODE word — compiles w_PAREN_DOES_cf into definition
- Implemented (DOES>) as CODE word — patches LATEST's code field from JP DOVAR to JP DODOES, writes does-addr, then EXITs
- Implemented VARIABLE as DEFWORD in bootstrap.asm: `CREATE 0 ,`
- Implemented CELLS as CODE word in memory.asm: `SLA C / RL B`
- All 7 new REPL tests pass (tests 25-31), all 24 existing tests pass
- CREATE reserves 2-byte does-addr slot (zeroed) between JP opcode and body, consistent with architecture spec
- Code review fix: Added STATE guard to DOES> (compile-mode check, same as `;`)
- Code review fix: Added 3 REPL tests (32-34): VARIABLE in colon def, multiple DOES> children, VARIABLE overwrite

### Change Log

- 2026-04-06: Implemented Story 3.2 — VARIABLE, CONSTANT, CREATE, DOES>, (DOES>), CELLS, DOVAR, DOCON, DODOES. Added 7 REPL tests (25-31).
- 2026-04-06: Code review — Fixed DOES> missing STATE guard (H1). Added REPL tests 32-34 (M1-M3).

### File List

- src/inner_interpreter.asm — Added DOVAR, DOCON, DODOES runtime handlers
- src/compiler.asm — Added CREATE, CONSTANT, DOES>, (DOES>) words; added STATE guard to DOES>
- src/memory.asm — Added CELLS word
- src/bootstrap.asm — Added VARIABLE word
- Makefile — Added REPL tests 25-34
