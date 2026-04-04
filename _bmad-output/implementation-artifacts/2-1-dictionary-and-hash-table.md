# Story 2.1: Dictionary & Hash Table

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want words stored in a searchable dictionary,
so that the system can look up built-in words by name for execution.

## Acceptance Criteria

1. **Given** the cold start protocol runs **When** the hash table is initialised **Then** all 64 hash buckets are set to 0 (empty chains) **And** all CODE words defined via DEFCODE/DEFWORD macros in Epic 1 are linked into the hash table at assembly time

2. **Given** a word name (e.g., "DUP") **When** the XOR-rotate hash function processes it **Then** it produces a consistent bucket index in the range 0-63 **And** the hash is case-insensitive per ANS Forth standard

3. **Given** a word name that exists in the dictionary (e.g., "SWAP") **When** FIND searches for it **Then** it returns the execution token (code field address) and a flag indicating found (+1 for immediate, -1 for non-immediate)

4. **Given** a word name that does NOT exist in the dictionary **When** FIND searches for it **Then** it returns the original string address and 0 (not found)

5. **Given** multiple words hashing to the same bucket **When** FIND searches for any of them **Then** it traverses the hash-link chain and finds the correct entry **And** lookup time remains responsive due to the 64-bucket distribution

## Tasks / Subtasks

- [x] Task 1: Implement runtime XOR-rotate hash function in `src/hash.asm` (AC: #2)
  - [x] 1.1 Implement `hash_name` subroutine: input HL=string address, B=length; output A=bucket index (0-63). Must be case-insensitive (convert to uppercase before XOR). Must match the LUA assembly-time hash function in `src/macros.asm:33-41`.
  - [x] 1.2 The hash function is a CALL-able subroutine, NOT a DEFCODE word. It's an internal helper used by FIND.
- [x] Task 2: Implement FIND word in `src/dictionary.asm` (AC: #3, #4, #5)
  - [x] 2.1 FIND ( c-addr -- c-addr 0 | xt 1 | xt -1 ) — CODE word via DEFCODE
  - [x] 2.2 Algorithm: extract name+length from counted string, call `hash_name`, index into `hash_table` array (hash_table + bucket*2), load bucket head address, traverse chain comparing names case-insensitively
  - [x] 2.3 Name comparison must mask the count byte with F_LENMASK (0x1F) to ignore IMMEDIATE and SMUDGE flags; skip entries with SMUDGE flag set (F_SMUDGE = 0x40)
  - [x] 2.4 On match: compute code field address (skip past hash_link + count_flags + name bytes) and push xt; check IMMEDIATE flag to return +1 or -1
  - [x] 2.5 On no match (chain ends with 0x0000 link): return original c-addr and 0
- [x] Task 3: Implement COUNT word in `src/dictionary.asm` (AC: supports FIND usage)
  - [x] 3.1 COUNT ( c-addr -- c-addr+1 u ) — extracts length from counted string
  - [x] 3.2 Simple CODE word: load byte at c-addr, increment address, push both
- [x] Task 4: Create test threads and verify all words (AC: #1-5)
  - [x] 4.1 Test hash function consistency: hash "DUP" and verify it matches the assembly-time computed bucket (verify by looking up DUP and finding it)
  - [x] 4.2 Test FIND with known word: FIND "DUP" → should return w_DUP_cf and -1 (non-immediate)
  - [x] 4.3 Test FIND with unknown word: FIND "ZZZZZ" → should return c-addr and 0
  - [x] 4.4 Test FIND case-insensitivity: FIND "dup" → should find DUP (same result as uppercase)
  - [x] 4.5 Test FIND with single-character word: FIND "+" → should return w_PLUS_cf and -1
  - [x] 4.6 Test COUNT: apply COUNT to a counted string, verify address+1 and length
  - [x] 4.7 Update Makefile EXPECTED string to include test output characters
  - [x] 4.8 Verify all tests pass under `make test`

## Dev Notes

### What Already Exists (from Epic 1)

The following are implemented and **must not be modified** unless there's a bug:

- **Hash table (assembly-time)**: 64-bucket hash table fully built at assembly time via LUA in `src/macros.asm:6-10,30-42`. All 58 CODE words from Epic 1 are already linked. The `hash_table` label at `src/antforth.asm:918-923` emits 64 DW entries containing bucket head addresses.
- **DEFCODE/DEFWORD macros** (`src/macros.asm:48-109`): Already compute XOR-rotate hash and link entries into bucket chains at assembly time. No changes needed.
- **Dictionary entry format**: `[hash_link 2B][count_flags 1B][name nB][code_field ...]`. Hash_link points to previous entry in the same bucket (0x0000 = end of chain). Count_flags byte: bit 7 = IMMEDIATE, bit 6 = SMUDGE, bits 4-0 = name length.
- **Inner interpreter** (`inner_interpreter.asm`): DOCOL, EXIT_CODE, LIT, BRANCH, ?BRANCH, EXECUTE
- **All CODE primitives**: stack_ops, arithmetic, logic, memory, io, system — all 58 words with DEFCODE headers already in hash table
- **Cold start** (`antforth.asm:18-72`): Initialises SP, IX, IY, STATE, BASE, HERE, TIB. Hash table is pre-populated in the binary — no runtime initialisation needed (AC #1 is already satisfied).
- **Constants** (`constants.asm`): HASH_BUCKETS=64, F_IMMEDIATE=0x80, F_SMUDGE=0x40, F_LENMASK=0x1F
- **Structures** (`structures.asm`): DictEntry struct (hash_link, count_flags), UserArea struct

### What AC #1 Means in Practice

AC #1 says "all 64 hash buckets are set to 0 (empty chains)" — this refers to the initial state before words are linked. At assembly time, the LUA code in `macros.asm` starts all buckets at 0, then each DEFCODE/DEFWORD updates the bucket head. By the time the binary is assembled, the `hash_table` array contains the final bucket head addresses (0x0000 for empty buckets, non-zero for buckets with words). **No runtime zeroing is needed** — the binary already contains the correct values.

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

### Runtime Hash Function Design

The LUA hash function at assembly time (`macros.asm:33-41`) does:
```lua
function forth_hash(name)
    local h = 0
    local upper = string.upper(name)
    for i = 1, #upper do
        h = h ~ string.byte(upper, i)
        h = ((h << 1) | (h >> 7)) & 0xFF
    end
    return h & 63
end
```

The Z80 runtime version in `hash.asm` must produce **identical results**. Algorithm in Z80 terms:
1. A = 0 (accumulator for hash)
2. For each byte of the name (HL = address, B = count):
   a. Load byte from (HL), convert to uppercase (if 'a'-'z', subtract 0x20)
   b. XOR with A
   c. Rotate A left 1 bit (RLC A — this rotates through bit 0, not through carry)
   d. Advance HL, decrement B
3. AND 63 to get bucket index

**Critical:** Use `RLC A` (rotate left circular), NOT `RLA` (rotate left through carry). `RLC A` does: bit 7 → carry AND bit 0, bits 0-6 shift left. This matches the LUA `((h << 1) | (h >> 7)) & 0xFF`.

**Subroutine interface:**
```
hash_name:
; Input:  HL = pointer to name string (NOT counted — raw characters)
;         B  = name length
; Output: A  = bucket index (0-63)
; Clobbers: HL (advanced past name), B (decremented to 0), C, F
; Preserves: DE, IX, IY, SP
```

### FIND Implementation Design

**Stack effect:** `FIND ( c-addr -- c-addr 0 | xt 1 | xt -1 )`

**Input:** c-addr points to a counted string (first byte = length, then name bytes).

**Algorithm:**
1. Save c-addr (for not-found return) and DE (IP)
2. Load length from (c-addr), compute name address = c-addr + 1
3. Call `hash_name` with name address and length → A = bucket index
4. Compute bucket head address: hash_table + A*2
5. Load bucket head: LD HL, (bucket_addr) → HL = first entry in chain (or 0)
6. **Chain traversal loop:**
   a. If HL = 0 → not found, return original c-addr and 0
   b. HL points to dict entry: load count_flags from HL+2
   c. Check SMUDGE flag (bit 6) — if set, skip entry (follow hash_link)
   d. Mask length: count_flags AND F_LENMASK → entry name length
   e. Compare length with search length — if different, skip to next entry
   f. Compare name bytes case-insensitively — if different, skip to next entry
   g. **Match found:** compute xt = HL + 2 + 1 + name_length (skip hash_link + count_flags + name)
   h. Check IMMEDIATE flag (bit 7 of count_flags): if set, push +1; else push -1
   i. Replace c-addr on stack with xt, push flag
7. **Skip to next:** Load hash_link from (HL) → HL = next entry. Goto step 6a.

**Critical details:**
- FIND must save/restore DE (IP). The subroutine uses HL extensively as scratch.
- Case-insensitive comparison: for each byte pair, convert both to uppercase before comparing.
- The code field address (xt) calculation: entry_start + 2 (hash_link) + 1 (count_flags) + name_length = first byte of code field.
- FIND consumes c-addr from the stack when the word is found (replaces with xt) or leaves it when not found.

### COUNT Implementation Design

**Stack effect:** `COUNT ( c-addr -- c-addr+1 u )`

Simple word: load the byte at c-addr (the count byte), increment the address, push both.

```z80
w_COUNT:
        DEFCODE "COUNT", 0
w_COUNT_cf:
        ; BC = c-addr (TOS)
        LD      A, (BC)         ; A = count byte
        INC     BC              ; BC = c-addr+1 (name start)
        PUSH    BC              ; Push c-addr+1 (second on stack)
        AND     F_LENMASK       ; Mask off flags — only length
        LD      C, A
        LD      B, 0            ; BC = length (new TOS)
        NEXT
```

**Note:** COUNT masks with F_LENMASK to strip IMMEDIATE/SMUDGE flags, returning only the name length. This is important because FIND may be called on dictionary entry count bytes. However, when COUNT is used on user-provided counted strings (e.g., from WORD), the high bits will be 0 anyway, so masking is harmless.

### Test Thread Strategy

**Current test output pattern:** Characters emitted as pass/fail indicators. Current EXPECTED string is checked by Makefile.

**Test approach for FIND:**
1. Store counted strings in the data area (e.g., `test_find_dup: DB 3, "DUP"`)
2. Push address of counted string, call FIND
3. Compare returned xt against known w_DUP_cf address (using LIT and =)
4. Compare returned flag against expected value (using LIT and =)
5. Use existing pattern: emit a known character on success, '!' on failure

**Test counted strings needed:**
```z80
test_find_dup:    DB 3, "DUP"         ; Known word, non-immediate
test_find_lc_dup: DB 3, "dup"         ; Lowercase — test case-insensitivity
test_find_plus:   DB 1, "+"           ; Single-char word
test_find_bad:    DB 5, "ZZZZZ"       ; Unknown word
```

**Test sequence for "FIND DUP returns correct xt":**
```
LIT test_find_dup       ; Push address of counted string
FIND                    ; ( -- xt flag ) or ( -- c-addr 0 )
LIT -1                  ; Expected flag for non-immediate
=                       ; Check flag
?BRANCH .fail           ; If flag wrong, fail
LIT w_DUP_cf            ; Expected xt
=                       ; Check xt
?BRANCH .fail           ; If xt wrong, fail
LIT 'X'                 ; Pass character (pick unused letter)
EMIT
BRANCH .done
.fail:
DROP                    ; Clean up stack
LIT '!'
EMIT
.done:
```

**Note:** The actual test characters to use depend on what's unused in the current expected output string. Check the Makefile EXPECTED at implementation time. If running low on simple ASCII, consider using `}`, `~`, etc.

### Naming Convention for Labels

| Forth word | Label prefix | Code field label |
|-----------|-------------|-----------------|
| FIND | w_FIND | w_FIND_cf |
| COUNT | w_COUNT | w_COUNT_cf |

Internal helper:
| Function | Label |
|----------|-------|
| Hash function | hash_name |

### File Structure

- `src/hash.asm` — Implement `hash_name` subroutine (replace stub). Add file header comment.
- `src/dictionary.asm` — Implement FIND and COUNT as DEFCODE words (replace stub). Add file header comment.
- `src/antforth.asm` — Add test counted strings to data area, add test threads for FIND/COUNT before EXECUTE(BYE). Update EXPECTED string in Makefile.
- `Makefile` — Update EXPECTED string to include new test output characters.
- No new files needed.

### Project Structure Notes

- `hash.asm` and `dictionary.asm` are already INCLUDEd in `antforth.asm` (lines 78-79) after `inner_interpreter.asm` and before the primitives. This is the correct position — FIND and hash_name will be available to all subsequent code.
- The `hash_table` label is at `antforth.asm:918` in the data area — `hash_name` and FIND reference it at runtime.
- Dictionary entry traversal depends on the entry format established by DEFCODE/DEFWORD macros — this format is fixed and must not change.

### Anti-Patterns to Avoid

1. **Do NOT modify the DEFCODE/DEFWORD macros** — they already handle assembly-time hash table linking correctly.
2. **Do NOT add runtime hash table initialisation to cold_start** — the table is pre-populated in the binary.
3. **Do NOT use RLA instead of RLC A** in the hash function — RLA rotates through carry, giving wrong results.
4. **Do NOT forget case-insensitive comparison** in both hash_name and FIND's name matching.
5. **Do NOT forget to mask count_flags with F_LENMASK** when comparing name lengths.
6. **Do NOT forget to skip SMUDGE'd entries** in FIND — entries being compiled are hidden.
7. **Do NOT use IX or IY as scratch** in hash_name or FIND.
8. **Do NOT forget to save/restore DE (IP)** in FIND — it uses HL and other registers extensively.
9. **Do NOT create hash_name as a DEFCODE word** — it's an internal subroutine called by FIND, not a Forth-visible word.
10. **Do NOT assume the hash table is at a fixed address** — always reference the `hash_table` label.

### Previous Story Learnings (from Story 1.5)

- The BDOS_SAVE/BDOS_RESTORE macro pair works correctly and is well-tested (not directly needed for this story, but confirms macro infrastructure is solid)
- Test thread pattern is well-established: emit pass character on success, '!' on failure
- The `test_colon_header` at `antforth.asm:907-915` demonstrates manual dictionary entry construction — useful as reference for understanding the entry format, but FIND should use the standard DEFCODE-generated entries
- Current EXPECTED string handling uses printf in the Makefile for special characters — may need similar treatment if test output includes non-printable characters

### Git Intelligence

Recent commits show a clean pattern: one commit per story, descriptive messages. All 5 Epic 1 stories completed successfully. The codebase is stable — all tests pass.

Most recent commit `b57363d` completed story 1.5 with I/O primitives. The I/O words (EMIT, TYPE, CR, SPACE, SPACES, KEY, KEY?) are now available and tested — FIND's test threads can use EMIT for pass/fail output.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.1] — acceptance criteria and story definition
- [Source: _bmad-output/planning-artifacts/architecture.md#Dictionary Entry Format] — entry structure: [hash-link 2B][count+flags 1B][name nB][code field]
- [Source: _bmad-output/planning-artifacts/architecture.md#Dictionary Entry Construction] — DEFCODE/DEFWORD/DEFIMMED macro usage
- [Source: _bmad-output/planning-artifacts/architecture.md#Register Usage Discipline] — inviolable register contract
- [Source: src/macros.asm:30-42] — LUA XOR-rotate hash function (runtime version MUST match)
- [Source: src/macros.asm:48-76] — DEFCODE macro: dictionary entry format and hash linking
- [Source: src/antforth.asm:918-923] — hash_table runtime label (64 DW entries)
- [Source: src/constants.asm:20-31] — HASH_BUCKETS, F_IMMEDIATE, F_SMUDGE, F_LENMASK
- [Source: src/structures.asm] — DictEntry struct definition
- [Source: src/dictionary.asm] — current stub (to be replaced)
- [Source: src/hash.asm] — current stub (to be replaced)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed pre-existing bug in DEFCODE/DEFWORD macros: `sj.get_define()` returned name WITH quotes, causing wrong count bytes (e.g. "DUP" had count=5 instead of 3) and wrong hash bucket assignments
- Fixed `sj.insert_label`/`sj.get_label` timing issue: labels set in LUA blocks weren't visible to assembly instructions or other LUA blocks in the same pass. Replaced with LUA global table `_hash_buckets[]` for bucket heads and direct `_pc()` emission for hash_link and count_flags bytes
- Fixed `OR B` clobbering hash accumulator A in hash_name: replaced `XOR A; OR B; JR Z` with `LD A,B; OR A; LD A,0; JR Z` to test B for zero without modifying A
- [Review] Fixed `tonumber()` in DEFCODE/DEFWORD LUA unable to resolve EQU symbols (e.g. F_IMMEDIATE): replaced with `sj.calc()` which evaluates assembler expressions. Without this fix, flags passed to DEFCODE/DEFWORD were silently dropped — DEFIMMED would have been broken in Epic 3

### Completion Notes List

- Implemented `hash_name` subroutine in `src/hash.asm` — runtime XOR-rotate hash matching the LUA assembly-time function
- Implemented FIND word in `src/dictionary.asm` — full dictionary lookup with case-insensitive comparison, SMUDGE flag handling, IMMEDIATE flag detection
- Implemented COUNT word in `src/dictionary.asm` — counted string extraction with F_LENMASK
- Fixed DEFCODE/DEFWORD macros in `src/macros.asm` — three bugs corrected: quote stripping, label timing, and direct byte emission via LUA
- Added 6 test threads covering: FIND known word, FIND unknown word, FIND case-insensitive, FIND single-char, COUNT, FIND IMMEDIATE word (+1 flag)
- All 58 existing Epic 1 tests continue to pass (no regressions)

### Change Log

- 2026-04-04: Implemented story 2.1 — dictionary hash function, FIND, COUNT. Fixed pre-existing DEFCODE/DEFWORD macro bugs.
- 2026-04-04: [Review] Fixed DEFCODE/DEFWORD flags bug (tonumber→sj.calc). Added IMMEDIATE FIND test. Added cross-reference comments for duplicated uppercase logic.

### File List

- src/hash.asm — Implemented hash_name subroutine (was stub)
- src/dictionary.asm — Implemented FIND and COUNT CODE words (was stub)
- src/macros.asm — Fixed DEFCODE/DEFWORD: quote stripping, LUA global bucket table, direct byte emission; [Review] fixed tonumber→sj.calc for flags
- src/antforth.asm — Added test counted strings and 6 test threads for FIND/COUNT; hash_table LUA reads from `_hash_buckets[]`
- Makefile — Updated EXPECTED string with new test output characters
