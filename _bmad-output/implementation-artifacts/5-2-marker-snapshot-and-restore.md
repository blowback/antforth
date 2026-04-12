# Story 5.2: MARKER Snapshot & Restore

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to snapshot the dictionary state and restore to it later,
so that I can experiment freely knowing I can undo everything and return to a known-good state.

## Acceptance Criteria

1. **Given** the user types `MARKER CHECKPOINT`
   **When** MARKER executes
   **Then** a new word CHECKPOINT is added to the dictionary
   **And** CHECKPOINT records the current HERE value and the current state of all 64 hash bucket head pointers

2. **Given** the user has created CHECKPOINT and then defines additional words (e.g., `: TEST1 ... ;`, `: TEST2 ... ;`)
   **When** the user types `CHECKPOINT`
   **Then** HERE is restored to the value saved at MARKER creation time
   **And** all 64 hash bucket head pointers are restored to their saved values
   **And** TEST1, TEST2, and CHECKPOINT itself are effectively removed from the dictionary
   **And** the memory they occupied is reclaimed (available for new definitions)

3. **Given** the user creates nested markers: `MARKER M1`, defines words, `MARKER M2`, defines more words
   **When** `M2` is executed
   **Then** only the state back to M2's creation is restored (M1 and words defined before M2 remain)
   **When** `M1` is then executed
   **Then** state is restored to M1's creation point (everything after M1 is removed, including M2)

4. **Given** MARKER has saved the system state
   **When** the user restores to that state
   **Then** no residual side effects remain — the system behaves identically to how it did at the moment MARKER was created
   **And** user variables (BASE, STATE) are NOT affected by MARKER restore (MARKER covers dictionary state only)

5. **Given** the user creates a MARKER, defines words that include VARIABLE and CONSTANT definitions
   **When** the MARKER is executed to restore
   **Then** those variables and constants are removed from the dictionary along with all other definitions made after the marker

## Tasks / Subtasks

- [x] Task 1: Add DOMARKER runtime handler in `inner_interpreter.asm` (AC: #2, #4)
  - [x] 1.1 Add `DOMARKER` after `DODOES` (line ~80): restore HERE from body, copy 128 bytes from body+2 to `hash_table`, no stack effect
  - [x] 1.2 Save/restore DE (IP) and BC (TOS) to return stack around LDIR (LDIR clobbers both)

- [x] Task 2: Add MARKER word as DEFCODE in `system.asm` (AC: #1, #2, #3)
  - [x] 2.1 Save DE (IP) and BC (TOS) to return stack
  - [x] 2.2 Call `build_header` with flags=0 (no SMUDGE — word is immediately findable)
  - [x] 2.3 Emit `JP DOMARKER` code field (3 bytes)
  - [x] 2.4 Emit saved HERE value (2 bytes) from `bh_entry_start` (the pre-header HERE)
  - [x] 2.5 Copy 128 bytes from `hash_table` to body (LDIR, save/restore DE around it)
  - [x] 2.6 Fixup: write `bh_old_bucket_head` at body offset `bh_bucket_index * 2` (undo build_header's bucket modification)
  - [x] 2.7 Update HERE past the body (130 bytes total: 2 + 128)
  - [x] 2.8 Restore BC (TOS) and DE (IP), NEXT
  - [x] 2.9 Handle no-name error: restore registers, JP w_ABORT_cf

- [x] Task 3: Add static variable `marker_saved_here` (not needed — use `bh_entry_start` directly)

- [x] Task 4: Add REPL tests (AC: #1-#5)
  - [x] 4.1 Test 226: Basic MARKER creation and use — `MARKER M1 : FOO 42 ; FOO .` outputs `42`
  - [x] 4.2 Test 227: MARKER restore removes definitions — `MARKER M1 : FOO 42 ; M1 FOO` outputs `FOO ?` (error)
  - [x] 4.3 Test 228: Redefine after restore — `MARKER M1 : FOO 42 ; M1 : FOO 99 ; FOO .` outputs `99`
  - [x] 4.4 Test 229: MARKER removes itself — `MARKER M1 M1 M1` outputs `M1 ?` (error)
  - [x] 4.5 Test 230: Nested markers (M2 partial restore, BB2 removed) — word names changed to AA1/BB2 to avoid Z80 assembler register conflicts
  - [x] 4.6 Test 231: Nested markers (M1 full restore) — word names changed to AA1/BB2 to avoid Z80 assembler register conflicts
  - [x] 4.7 Test 232: VARIABLE removed by MARKER — `MARKER M1 VARIABLE X 42 X ! X @ . M1 X` outputs `42` then `X ?`
  - [x] 4.8 Test 233: CONSTANT removed by MARKER — `MARKER M1 77 CONSTANT K K . M1 K` outputs `77` then `K ?`
  - [x] 4.9 Test 234: BASE not affected by MARKER — uses `BASE @ DECIMAL .` to verify BASE stays hex (16) after restore
  - [x] 4.10 Test 235: HERE restored correctly — `HERE MARKER M1 : FOO ; M1 HERE = .` outputs `-1` (TRUE)

- [x] Task 5: Verify no regressions (AC: #4)
  - [x] 5.1 `make test` — all 73 regression tests pass
  - [x] 5.2 `make test-repl` — all 237 tests pass (225 existing + 12 new)

### Review Follow-ups (AI) — FIXED
- [x] [AI-Review][MEDIUM] Test 230: Added BB2 removal verification (was only checking AA1 survived) [Makefile:2013]
- [x] [AI-Review][MEDIUM] Test 236: Added MARKER TOS preservation test (BC register) [Makefile:2062]
- [x] [AI-Review][LOW] Test 237: Added MARKER no-name error path test (abort and recovery) [Makefile:2070]

## Dev Notes

### Implementation Design

MARKER is a defining word implemented as a DEFCODE that creates child words with a `JP DOMARKER` code field. The body stores a complete snapshot of dictionary state: the HERE pointer and all 64 hash bucket head pointers.

#### Body Layout (130 bytes per marker word)

```
Offset 0-1:     saved HERE value (2 bytes, little-endian)
Offset 2-129:   saved hash_table contents (128 bytes = 64 buckets x 2 bytes)
```

#### MARKER Word (DEFCODE in system.asm)

The MARKER word:
1. Calls `build_header` to create the dictionary entry (parses name, builds header at HERE, updates hash bucket)
2. Uses `bh_entry_start` as the saved HERE (this is the HERE value BEFORE build_header ran — exactly what we need)
3. Emits `JP DOMARKER` as the code field
4. Emits the saved HERE value (2 bytes)
5. Copies the current hash_table (128 bytes) into the body
6. **Critical fixup**: build_header modified one hash bucket (to add the marker word). The saved hash table must have the PRE-modification value for that bucket. Use `bh_bucket_index` and `bh_old_bucket_head` to patch the single modified entry in the body copy.
7. Updates HERE past the 130-byte body

```z80
; Temp variable for marker (placed at top of system.asm with other data)
marker_saved_here:  DW 0

w_MARKER:
        DEFCODE "MARKER", 0
w_MARKER_cf:
        ; Save DE (IP) and BC (TOS) to return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B

        ; Build dictionary header (flags=0, no SMUDGE)
        XOR     A
        CALL    build_header
        JR      C, .marker_no_name

        ; HL = code field — emit JP DOMARKER
        LD      (HL), 0xC3              ; JP opcode
        INC     HL
        LD      (HL), LOW DOMARKER
        INC     HL
        LD      (HL), HIGH DOMARKER
        INC     HL

        ; Emit saved HERE (2 bytes) — bh_entry_start is pre-header HERE
        LD      DE, (bh_entry_start)
        LD      (HL), E
        INC     HL
        LD      (HL), D
        INC     HL

        ; Save body hash start address for fixup later
        PUSH    HL                      ; body_hash_start on stack

        ; Copy 128 bytes from hash_table to body
        ; Need LDIR: HL=src, DE=dst, BC=count
        ; Currently HL = body dest, need to swap
        EX      DE, HL                  ; DE = body dest
        LD      HL, hash_table          ; HL = source
        LD      BC, 128
        LDIR                            ; DE = past end of body

        ; Fixup: restore pre-MARKER bucket value in body copy
        ; Body hash copy starts at (saved on stack)
        ; Modified bucket = bh_bucket_index, old value = bh_old_bucket_head
        POP     HL                      ; HL = body_hash_start
        LD      A, (bh_bucket_index)
        LD      C, A
        LD      B, 0
        ADD     HL, BC
        ADD     HL, BC                  ; HL = body_hash_start + bucket_index * 2
        LD      BC, (bh_old_bucket_head)
        LD      (HL), C
        INC     HL
        LD      (HL), B

        ; Update HERE = DE (past end of body, from LDIR)
        LD      (IY+UserArea.here), E
        LD      (IY+UserArea.here+1), D

        ; Restore BC (TOS) and DE (IP) from return stack
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX
        NEXT

.marker_no_name:
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX
        JP      w_ABORT_cf
```

**Note on DE (IP) preservation**: The LDIR in MARKER uses DE as the destination register, which overwrites IP. But IP is already saved on the return stack (at entry to MARKER) and restored at exit. The LDIR destination (body in dictionary space) is unrelated to IP.

#### DOMARKER Runtime (in inner_interpreter.asm)

When a marker word (e.g., CHECKPOINT) is executed:
1. Inner interpreter dispatches to the code field: `JP DOMARKER`
2. DOMARKER reads saved HERE from body, restores it
3. Copies 128 bytes from body to hash_table, restoring all bucket heads
4. The marker word itself (and everything defined after it) is now unreachable — its memory will be reclaimed by the next allocation

```z80
; === DOMARKER — Restore dictionary state from marker body ===
; HL points to code field (JP DOMARKER)
; Body at cf+3: [saved_here(2)][saved_hash_table(128)]
; ( -- ) no stack effect
DOMARKER:
        ; Skip code field to reach body
        INC     HL
        INC     HL
        INC     HL                      ; HL = &saved_here

        ; Save DE (IP) to return stack — LDIR uses DE
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D

        ; Read saved HERE from body
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        INC     HL                      ; DE = saved_here, HL = &saved_hash_data

        ; Restore HERE
        LD      (IY+UserArea.here), E
        LD      (IY+UserArea.here+1), D

        ; Copy 128 bytes from body to hash_table
        ; HL = source (saved hash data in body)
        LD      DE, hash_table          ; DE = destination
        LD      BC, 128
        LDIR                            ; Restore all 64 hash bucket heads

        ; Restore IP from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        NEXT
```

**Critical observation**: After DOMARKER runs, the body data we just read from is still in memory (not yet overwritten). But HERE has been rolled back, so the next allocation will overwrite it. This is safe — we've already finished reading.

### Why Not CREATE/DOES>

A pure Forth `CREATE ... DOES>` approach would require:
- Exposing `hash_table` address as a Forth constant (currently assembly-only label)
- Working around the fact that CREATE modifies the hash table before we can snapshot it
- Extra Forth-level complexity for the bucket fixup

A DEFCODE implementation is cleaner: direct access to `build_header` scratch variables (`bh_entry_start`, `bh_bucket_index`, `bh_old_bucket_head`) makes the pre-modification fixup trivial.

### Where to Add the Code

**`src/system.asm`**: Add MARKER after BYE (line 13) and before ABORT (line 20). system.asm's header comment already lists MARKER as a planned word.

**`src/inner_interpreter.asm`**: Add DOMARKER after DODOES (line ~80), following the same pattern as the other runtime handlers.

### Register Contract

**MARKER** ( -- ): No stack effect.
- BC (TOS): saved/restored via return stack
- DE (IP): saved/restored via return stack (clobbered by LDIR)
- SP: untouched
- IX: temporarily used for return stack saves, fully restored
- IY: read-only access to UserArea

**DOMARKER** ( -- ): No stack effect.
- BC (TOS): **preserved** (LDIR clobbers BC to 0 after the copy, but BC=TOS was not modified — wait, LDIR sets BC=0! We need to save/restore BC)

**IMPORTANT**: LDIR decrements BC to 0. If BC holds TOS, we must save BC before LDIR and restore after. DOMARKER has no stack effect, so BC (TOS) must be preserved.

**Corrected DOMARKER**:
```z80
DOMARKER:
        INC     HL
        INC     HL
        INC     HL                      ; HL = body

        ; Save DE (IP) and BC (TOS) — LDIR clobbers both DE and BC
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B

        ; Read saved HERE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        INC     HL                      ; DE = saved_here, HL = hash data

        ; Restore HERE
        LD      (IY+UserArea.here), E
        LD      (IY+UserArea.here+1), D

        ; Copy 128 bytes from body to hash_table
        LD      DE, hash_table
        LD      BC, 128
        LDIR

        ; Restore BC (TOS) and DE (IP)
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        NEXT
```

Similarly, **MARKER's LDIR** also clobbers BC. But in MARKER, BC (TOS) was already saved to the return stack at entry and restored at exit, so this is handled. However, between the LDIR and the fixup code, we use BC to load `bh_old_bucket_head` — that's a fresh load, not the clobbered LDIR value, so it's fine.

### ANS Forth Compliance

MARKER is ANS Forth CORE EXT word 6.2.1850. The standard specifies:
- "Parse name. Create a definition for name with the execution semantics defined below."
- Execution: "Restore all dictionary allocation and search order pointers to the state they had just prior to the definition of name."

This implementation saves/restores HERE and all 64 hash bucket heads, which fully covers dictionary allocation and search order for antforth's single-vocabulary, hash-based dictionary. The standard also mentions "search order" — antforth has only one search order (the single hash table), so restoring the 64 buckets is complete.

**Deliberate deviation**: The standard says MARKER should also restore the compilation word list. In antforth, there is only one word list (the hash table), so this is automatically covered.

### REPL Test Numbering

Tests continue from **226** onwards (last existing test is 225).

### Testing Strategy

**Primary: REPL-piped tests** (per project convention).

Multi-line tests use `\r\n` separators in printf. Error recovery tests check for `?` in output (same pattern as existing tests 3, 222, etc.).

Key scenarios:
1. MARKER creates a findable word that can be used after definitions
2. Executing the marker removes definitions made after it
3. Executing the marker removes the marker itself
4. Nested markers restore to correct intermediate/full states
5. VARIABLE and CONSTANT definitions are removed
6. BASE (user variable) is not affected by restore
7. HERE is restored to exact pre-MARKER value

### Anti-Patterns to Avoid

1. **Do NOT use CREATE/DOES>** — DEFCODE with `build_header` is the correct approach for direct access to pre-modification state
2. **Do NOT forget to fixup the hash bucket in the body copy** — build_header modifies one bucket to add the marker word; the saved snapshot must have the PRE-modification value
3. **Do NOT forget to save/restore BC around LDIR** — LDIR decrements BC to 0, destroying TOS
4. **Do NOT save/restore LATEST** — it's not needed for correctness; the next `:` or `CREATE` will set it
5. **Do NOT modify `outer_interpreter.asm`** — MARKER is a self-contained word
6. **Do NOT add tests to the regression test thread** — REPL-piped tests only
7. **Do NOT save BASE, STATE, or other user variables** — AC#4 explicitly states MARKER covers dictionary state only

### Previous Story Intelligence (from Story 5.1)

**Register-contract violations** are the dominant bug class. Story 5.1 had to fix a BC (TOS) preservation bug in `(` where the initial implementation forgot to save/restore BC. LDIR is especially dangerous — it zeroes BC.

**REPL test patterns**: Multi-line input uses `\r\n` separators. Error detection checks for `?` in output. TOS preservation should be explicitly tested.

**Error print pattern**: For `.marker_no_name`, follow the same pattern as `.create_no_name` in compiler.asm (restore registers from return stack, JP w_ABORT_cf). No custom error message needed — ABORT handles recovery.

**BDOS C_WRITE loop**: Not needed here (no custom error messages for MARKER — a missing name just ABORTs).

### Git Intelligence

Recent commits follow one-commit-per-story pattern. Most recent:
```
69d87df completed story 5.1
1f07b30 completed story 5.0.5
```

### Project Structure Notes

- DOMARKER runtime handler goes in `src/inner_interpreter.asm` after DODOES (line ~80)
- MARKER word goes in `src/system.asm` after BYE, before ABORT
- REPL tests appended to Makefile `test-repl` target starting at test 226
- No new files needed
- No changes to antforth.asm include order

### References

- [Source: src/inner_interpreter.asm:31-79] — DOVAR, DOCON, DODOES runtime handlers (pattern for DOMARKER)
- [Source: src/compiler.asm:4-13] — build_header scratch variables (bh_entry_start, bh_bucket_index, bh_old_bucket_head)
- [Source: src/compiler.asm:31-201] — build_header subroutine (creates dictionary entries)
- [Source: src/compiler.asm:517-576] — CREATE implementation (similar pattern for MARKER)
- [Source: src/compiler.asm:354-420] — COMP-ERROR (hash bucket restore pattern for error recovery)
- [Source: src/memory.asm:192-233] — FILL implementation (LDIR + DE save/restore pattern)
- [Source: src/memory.asm:239-284] — MOVE implementation (LDIR/LDDR + DE save/restore pattern)
- [Source: src/antforth.asm:185-190] — hash_table label (64 buckets, 128 bytes)
- [Source: src/antforth.asm:226] — kernel_end label (initial HERE value)
- [Source: src/structures.asm:16-27] — UserArea struct (here at offset 4)
- [Source: src/system.asm:1] — Header comment already lists MARKER as planned word
- [Source: src/hash.asm:14-31] — hash_name subroutine (used by build_header)
- [Memory: feedback_repl_tests_preferred.md] — REPL-piped tests only, no assembly test threads
- [Memory: feedback_standards_compliance.md] — Investigate the standard before defending code

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Test 230/231: Word names `A`/`B` conflicted with Z80 assembler register words — renamed to `AA1`/`BB2`
- Test 234: BASE output was `10` (hex) not `16` (decimal) — added `DECIMAL` before `.` to print in base 10

### Completion Notes List

- Implemented DOMARKER runtime handler in inner_interpreter.asm after DODOES: restores HERE and all 64 hash bucket heads from marker body, saves/restores both DE (IP) and BC (TOS) around LDIR
- Implemented MARKER defining word as DEFCODE in system.asm: calls build_header, emits JP DOMARKER + 130-byte body (2 bytes saved HERE + 128 bytes hash table copy), with critical fixup to restore pre-modification bucket value using bh_old_bucket_head
- No-name error path restores registers and jumps to w_ABORT_cf (same pattern as CREATE)
- All 10 REPL tests pass covering: basic create/use, restore removes definitions, redefine after restore, marker removes itself, nested markers (partial and full restore), VARIABLE/CONSTANT removal, BASE preservation, HERE restoration
- No regressions: 73 assembly tests + 237 REPL tests all pass

### Change Log

- 2026-04-12: Implemented MARKER snapshot & restore (Story 5.2) — DOMARKER runtime + MARKER defining word + 10 REPL tests
- 2026-04-12: Code review fixes — strengthened test 230 (verify BB2 removed), added test 236 (TOS preservation), added test 237 (no-name error recovery)

### File List

- src/inner_interpreter.asm (modified) — Added DOMARKER runtime handler after DODOES
- src/system.asm (modified) — Added MARKER DEFCODE word before ABORT
- Makefile (modified) — Added REPL tests 226-235 for MARKER functionality
