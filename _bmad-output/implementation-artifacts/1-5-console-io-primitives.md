# Story 1.5: Console I/O Primitives

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want console I/O CODE primitives,
so that I can output characters and strings and read keyboard input via CP/M BDOS.

## Acceptance Criteria

1. **Given** a hardcoded thread that calls EMIT with character 65 ('A') **When** it runs under iz-cpm **Then** the character 'A' appears on the console output **And** BDOS_SAVE/BDOS_RESTORE macros preserve DE (IP) and BC (TOS) around the BDOS call

2. **Given** a hardcoded thread that calls TYPE with an address and length **When** it runs **Then** the specified string is output to the console character by character

3. **Given** a hardcoded thread that calls CR **When** it runs **Then** a carriage return (0x0D) and line feed (0x0A) are output

4. **Given** a hardcoded thread that calls SPACE **When** it runs **Then** a single space character (0x20) is output **And** SPACES with count n outputs n space characters

5. **Given** a hardcoded thread that calls KEY **When** a character is available from the console **Then** KEY pushes the character value to the stack (via BDOS C_READ, function 1)

6. **Given** a hardcoded thread that calls KEY? **When** no key is pressed **Then** KEY? pushes 0 (FALSE) **When** a key is pressed **Then** KEY? pushes -1 (TRUE) (via BDOS C_STATUS, function 11)

## Tasks / Subtasks

- [x] Task 1: Add missing BDOS constants to `src/constants.asm` (AC: #1, #5, #6)
  - [x] 1.1 Add `C_READ EQU 1` — BDOS function 1: console input (waits, echoes)
  - [x] 1.2 Add `C_STATUS EQU 11` — BDOS function 11: console status (non-blocking)
- [x] Task 2: Implement output primitives in `src/io.asm` (AC: #1-4)
  - [x] 2.1 EMIT already exists — verify it works, no changes needed
  - [x] 2.2 TYPE ( c-addr u -- ) — loop calling EMIT for each character
  - [x] 2.3 CR ( -- ) — emit 0x0D then 0x0A
  - [x] 2.4 SPACE ( -- ) — emit 0x20
  - [x] 2.5 SPACES ( n -- ) — emit n spaces (handle n <= 0 as no-op)
- [x] Task 3: Implement input primitives in `src/io.asm` (AC: #5-6)
  - [x] 3.1 KEY ( -- char ) — blocking console read via BDOS function 1
  - [x] 3.2 KEY? ( -- flag ) — non-blocking console status via BDOS function 11
- [x] Task 4: Create test threads and verify all primitives (AC: #1-6)
  - [x] 4.1 Add test threads for TYPE (output a known string, verify character sequence)
  - [x] 4.2 Add test threads for CR (output CR+LF, verify in expected output)
  - [x] 4.3 Add test threads for SPACE and SPACES
  - [x] 4.4 Update Makefile EXPECTED string to include new test output characters
  - [x] 4.5 Verify all tests pass under `make test`
- [x] Task 5: Create manual test program for KEY and KEY? (AC: #5-6)
  - [x] 5.1 Create `src/test_key.asm` — standalone .COM program that builds to `build/test_key.com`
  - [x] 5.2 Program behaviour: echo loop — reads a character with KEY, emits it back with EMIT, repeats forever. Ctrl-C (0x03) exits via BYE (BDOS function 0). This exercises both KEY and EMIT in a tight loop.
  - [x] 5.3 Optionally use KEY? to display a waiting indicator or simply use the blocking KEY approach (simpler)
  - [x] 5.4 Add `test_key` target to Makefile: `make test_key` assembles `src/test_key.asm` → `build/test_key.com`
  - [x] 5.5 Add `build/test_key.com` to `make disk` so it's available on the CP/M disk image for on-device testing

## Dev Notes

### What Already Exists (from Stories 1.1-1.4)

The following are implemented and **must not be modified** unless there's a bug:

- **Inner interpreter** (`inner_interpreter.asm`): DOCOL, EXIT_CODE, LIT, BRANCH, ?BRANCH, EXECUTE
- **Stack primitives** (`stack_ops.asm`): DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH, SP@, SP!, RP@, RP!, >R, R>, R@
- **Memory primitives** (`memory.asm`): @, !, C@, C!, +!, HERE, ALLOT, COMMA, C,, ALIGN, ALIGNED, FILL, MOVE
- **Arithmetic** (`arithmetic.asm`): +, -, *, /, MOD, /MOD
- **Logic & comparison** (`logic.asm`): AND, OR, XOR, INVERT, LSHIFT, RSHIFT, =, <, >, 0=, 0<, U<
- **I/O** (`io.asm`): EMIT only (this is the file you're extending)
- **System** (`system.asm`): BYE (clean exit to CP/M)
- **Macros** (`macros.asm`): NEXT, NEXTHL, DEFCODE, DEFWORD, DEFIMMED, BDOS_SAVE, BDOS_RESTORE
- **Constants** (`constants.asm`): PS_SIZE=256, RS_SIZE=256, HASH_BUCKETS=64, TIB_SIZE=128, PAD_OFFSET=84, F_IMMEDIATE=0x80, F_SMUDGE=0x40, F_LENMASK=0x1F, BDOS_ENTRY=0x0005, C_WRITE=2, P_TERMCPM=0

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

**Anti-pattern**: Any CODE word that modifies DE, IX, or IY without saving/restoring.

### BDOS Interaction Pattern (Mandatory)

Every BDOS call **must** use the BDOS_SAVE / BDOS_RESTORE macro pair:

```z80
    BDOS_SAVE               ; PUSH DE (IP), PUSH BC (TOS)
    LD      C, function     ; BDOS function number
    LD      E, param        ; parameter (if needed)
    CALL    BDOS_ENTRY      ; 0x0005
    BDOS_RESTORE            ; POP BC (TOS), POP DE (IP)
```

**BDOS clobbers ALL registers** — the macros save/restore IP and TOS. After BDOS_RESTORE, BC and DE are restored to pre-call values. Any return value from BDOS is in A register (captured before BDOS_RESTORE if needed).

**Rule:** No BDOS calls from colon definitions — only from CODE words.

### BDOS Functions Needed

| Function | Constant | Input | Output | Notes |
|----------|----------|-------|--------|-------|
| C_WRITE (2) | Already exists | E = char | — | Console output, already used by EMIT |
| C_READ (1) | **Add to constants.asm** | — | A = char | Blocking console input, waits for keypress, echoes character |
| C_STATUS (11) | **Add to constants.asm** | — | A = 0x00 (no key) or 0xFF (key ready) | Non-blocking status check |

### Implementation Guide

#### EMIT (already implemented — reference pattern)

```z80
w_EMIT:
    DEFCODE "EMIT", 0
w_EMIT_cf:
    LD      A, C            ; A = char (save from TOS low byte)
    BDOS_SAVE               ; PUSH DE, PUSH BC
    LD      E, A            ; E = char for BDOS
    LD      C, C_WRITE      ; BDOS function 2
    CALL    BDOS_ENTRY
    BDOS_RESTORE            ; POP BC, POP DE
    POP     BC              ; Pop new TOS (char consumed from stack)
    NEXT
```

Key pattern: save the value from BC before BDOS_SAVE clobbers it, then POP BC at the end to consume the parameter from the stack.

#### TYPE ( c-addr u -- )

Output u characters starting at address c-addr. Loop calling BDOS C_WRITE for each character.

```z80
w_TYPE:
    DEFCODE "TYPE", 0
w_TYPE_cf:
    ; BC = u (count, TOS), (SP) = c-addr
    POP     HL              ; HL = c-addr
    ; BC = count — if count is 0, skip entirely
    LD      A, B
    OR      C
    JR      Z, .type_done
    PUSH    DE              ; Save IP (DE used as scratch in loop)
.type_loop:
    PUSH    HL              ; Save address
    PUSH    BC              ; Save count
    LD      A, (HL)         ; A = next char
    PUSH    DE              ; BDOS_SAVE equivalent (IP already saved above)
    LD      E, A
    LD      C, C_WRITE
    CALL    BDOS_ENTRY
    POP     DE              ; Restore scratch (not IP — that's saved deeper)
    POP     BC              ; Restore count
    POP     HL              ; Restore address
    INC     HL              ; Next character
    DEC     BC
    LD      A, B
    OR      C
    JR      NZ, .type_loop
    POP     DE              ; Restore IP
.type_done:
    POP     BC              ; New TOS
    NEXT
```

**Critical:** TYPE consumes both c-addr and u, so after the loop, POP BC loads the new TOS from whatever was below c-addr on the stack. DE (IP) must be saved/restored across the loop since BDOS clobbers it. Note the nested PUSH/POP structure — be careful with stack balance.

**Alternative simpler approach:** Save IP once, use IX-relative or memory for loop state. But the PUSH/POP approach above matches the project's existing pattern and avoids touching IX.

**Warning:** Do NOT use BDOS_SAVE/BDOS_RESTORE inside the loop body if IP is already saved outside the loop — the macros push/pop DE and BC, which could unbalance the stack if nested incorrectly. Either manage saves manually or restructure.

#### CR ( -- )

Output carriage return (0x0D) then line feed (0x0A). No stack parameters consumed.

```z80
w_CR:
    DEFCODE "CR", 0
w_CR_cf:
    BDOS_SAVE
    LD      E, 0x0D         ; Carriage return
    LD      C, C_WRITE
    CALL    BDOS_ENTRY
    BDOS_RESTORE
    BDOS_SAVE
    LD      E, 0x0A         ; Line feed
    LD      C, C_WRITE
    CALL    BDOS_ENTRY
    BDOS_RESTORE
    NEXT
```

CR does NOT consume or produce stack items — BC (TOS) is preserved by BDOS_SAVE/BDOS_RESTORE.

#### SPACE ( -- )

Output a single space (0x20).

```z80
w_SPACE:
    DEFCODE "SPACE", 0
w_SPACE_cf:
    BDOS_SAVE
    LD      E, 0x20         ; Space character
    LD      C, C_WRITE
    CALL    BDOS_ENTRY
    BDOS_RESTORE
    NEXT
```

#### SPACES ( n -- )

Output n space characters. If n <= 0, do nothing.

```z80
w_SPACES:
    DEFCODE "SPACES", 0
w_SPACES_cf:
    ; BC = n (count)
    LD      A, B
    OR      A               ; Check if high byte is negative (bit 7 set)
    JP      M, .spaces_done ; n < 0, skip (signed check)
    LD      A, B
    OR      C
    JR      Z, .spaces_done ; n == 0, skip
    PUSH    DE              ; Save IP
.spaces_loop:
    PUSH    BC              ; Save count
    BDOS_SAVE
    LD      E, 0x20
    LD      C, C_WRITE
    CALL    BDOS_ENTRY
    BDOS_RESTORE
    POP     BC              ; Restore count (NOT the BDOS_RESTORE BC!)
    ; Wait — BDOS_RESTORE already POPs BC. So the POP BC here pops the count.
    ; Actually: BDOS_SAVE pushes DE then BC. BDOS_RESTORE pops BC then DE.
    ; So the stack after BDOS_RESTORE has: [saved count] [saved IP] [rest of pstack]
    ; The POP BC here gets the saved count. Correct.
    DEC     BC
    LD      A, B
    OR      C
    JR      NZ, .spaces_loop
    POP     DE              ; Restore IP
.spaces_done:
    POP     BC              ; New TOS (n consumed)
    NEXT
```

**Critical stack analysis for SPACES loop body:**
- Before loop: PUSH DE (saves IP). Stack: [IP][...rest...]
- Loop iteration: PUSH BC (saves count). Stack: [count][IP][...rest...]
- BDOS_SAVE: PUSH DE, PUSH BC. Stack: [BC_tos][DE_ip][count][IP][...rest...]
- CALL BDOS_ENTRY
- BDOS_RESTORE: POP BC, POP DE. Stack: [count][IP][...rest...] — BC and DE restored to pre-BDOS values
- POP BC: gets saved count. Stack: [IP][...rest...]
- DEC BC, loop check
- After loop: POP DE (restores IP). Stack: [...rest...]
- POP BC: new TOS

**This is correct** — but verify the nesting carefully in implementation. The BDOS_SAVE/BDOS_RESTORE pair is self-contained within each iteration.

#### KEY ( -- char )

Blocking read of a single character from console via BDOS function 1 (C_READ).

```z80
w_KEY:
    DEFCODE "KEY", 0
w_KEY_cf:
    PUSH    BC              ; Push old TOS to make room
    BDOS_SAVE
    LD      C, C_READ       ; BDOS function 1
    CALL    BDOS_ENTRY      ; Returns char in A
    LD      B, A            ; Save char before BDOS_RESTORE
    BDOS_RESTORE            ; Pops BC (clobbers our saved char!) and DE
```

**Wait — problem:** BDOS_RESTORE pops BC, which overwrites the char we just saved in B. Fix: save A to a temporary location, or restructure:

```z80
w_KEY:
    DEFCODE "KEY", 0
w_KEY_cf:
    PUSH    BC              ; Push old TOS to make room for new value
    BDOS_SAVE
    LD      C, C_READ       ; BDOS function 1: console input
    CALL    BDOS_ENTRY      ; A = character read
    BDOS_RESTORE            ; Restores old BC and DE (we don't need them)
    LD      C, A            ; C = char (low byte of new TOS)
    LD      B, 0            ; B = 0 (high byte — char is 0-127)
    NEXT
```

**Note:** After BDOS_RESTORE, BC contains the old TOS that was pushed by BDOS_SAVE — but we immediately overwrite BC with the new character value. The old TOS is safely on the parameter stack (from the initial PUSH BC). BDOS function 1 echoes the character to console — this is standard CP/M behaviour.

#### KEY? ( -- flag )

Non-blocking console status check via BDOS function 11 (C_STATUS).

```z80
w_KEYQ:
    DEFCODE "KEY?", 0
w_KEYQ_cf:
    PUSH    BC              ; Push old TOS to make room
    BDOS_SAVE
    LD      C, C_STATUS     ; BDOS function 11: console status
    CALL    BDOS_ENTRY      ; A = 0x00 (no char) or 0xFF (char ready)
    BDOS_RESTORE
    ; Convert BDOS result to Forth flag: 0 → 0, 0xFF → -1 (0xFFFF)
    OR      A
    JR      Z, .keyq_false
    LD      BC, 0xFFFF      ; TRUE (-1)
    NEXT
.keyq_false:
    LD      BC, 0            ; FALSE (0)
    NEXT
```

**Critical:** BDOS function 11 returns 0x00 or 0xFF in A, but Forth TRUE is 0xFFFF (16-bit). Must extend the 8-bit result to 16-bit. Don't assume A=0xFF means BC should be 0x00FF — it must be 0xFFFF.

### Naming Convention for Labels

Follow established pattern from architecture doc:

| Forth word | Label prefix | Code field label |
|-----------|-------------|-----------------|
| TYPE | w_TYPE | w_TYPE_cf |
| CR | w_CR | w_CR_cf |
| SPACE | w_SPACE | w_SPACE_cf |
| SPACES | w_SPACES | w_SPACES_cf |
| KEY | w_KEY | w_KEY_cf |
| KEY? | w_KEYQ | w_KEYQ_cf |

### Test Thread Strategy

**Current test output:** `"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqr"` (Makefile line 48)

**Current test thread** (`antforth.asm:104-851`): Tests emit single characters on success or '!' on failure. Extend by inserting new test cases before the final EXECUTE(BYE).

**Words testable via iz-cpm (automated):**
- **TYPE**: Store a known string in memory, call TYPE, verify output characters appear in expected string
- **CR**: Call CR, verify 0x0D 0x0A appear in output (note: iz-cpm may translate CR+LF — test accordingly)
- **SPACE**: Call SPACE, verify 0x20 appears in output
- **SPACES**: Call SPACES with a count, verify correct number of spaces appear

**Words NOT testable via iz-cpm (manual only):**
- **KEY**: Requires interactive keyboard input — iz-cpm runs non-interactively. Document as manual test.
- **KEY?**: Requires interactive keyboard status — same constraint. Document as manual test.

**Test output approach for I/O words:** Since these words output specific characters/strings rather than pass/fail letters, consider one of:
1. Have test threads that use TYPE/CR/SPACE to output specific characters that become part of the EXPECTED string
2. Use existing arithmetic/comparison words to verify TYPE outputs the right length, then emit a pass/fail letter

**Recommended:** Use approach (1) — have TYPE output a short known string (e.g., "s") as part of the expected test output, CR output its characters, SPACE output a space. Adjust EXPECTED string accordingly. Keep pass/fail character pattern where possible.

**Important:** CR outputs `\r\n` which iz-cpm may or may not pass through. Test with care — if iz-cpm strips CR and only passes LF, the EXPECTED string must account for that. Run a test with just CR first to see what iz-cpm captures.

### File Structure

All new words go in `src/io.asm`. The file currently has only the file header and EMIT (19 lines). Add new words below EMIT in this order: TYPE, CR, SPACE, SPACES, KEY, KEY?.

Add BDOS constants to `src/constants.asm` in the existing "BDOS function numbers" section (after line 11).

### Manual Test Program (`test_key.com`)

Create `src/test_key.asm` as a **standalone** .COM program (not part of antforth itself). This is a minimal echo loop for manual verification of KEY and KEY? on real hardware or under interactive iz-cpm.

**Requirements:**
- Self-contained — INCLUDEs only `constants.asm` for BDOS equates (does NOT include macros.asm or any Forth infrastructure)
- ORG at 0x0100 (CP/M .COM entry)
- Simple loop: call BDOS C_READ (function 1) → check for Ctrl-C (0x03) → if yes, exit via BDOS P_TERMCPM → otherwise loop (C_READ already echoes, so no explicit EMIT needed)
- No Forth threading, no register contract — this is pure CP/M assembly

```z80
; ================================================
; test_key.asm — Manual test for KEY / KEY? primitives
; Echoes typed characters. Ctrl-C to exit.
; Part of antforth — ANS Forth for MicroBeast Z80
; ================================================

    INCLUDE "constants.asm"

    ORG     TPA_START       ; 0x0100

echo_loop:
    LD      C, C_READ       ; BDOS function 1: read console (blocking, echoes)
    CALL    BDOS_ENTRY      ; A = character typed
    CP      0x03            ; Ctrl-C?
    JR      NZ, echo_loop   ; No — keep looping (char already echoed by BDOS)
    LD      C, P_TERMCPM    ; BDOS function 0: exit to CP/M
    JP      BDOS_ENTRY
```

That's the entire program — ~10 lines of assembly. Add a Makefile target:

```makefile
TESTKEY = $(BUILDDIR)test_key.com

test_key: $(TESTKEY)

$(TESTKEY): src/test_key.asm src/constants.asm | $(BUILDDIR)
	$(ASM) --raw=$(TESTKEY) src/test_key.asm
```

And add `$(TESTKEY)` to the `disk` target's file list so it ends up on the CP/M disk image alongside antforth.com.

### Anti-Patterns to Avoid

1. **Do NOT use IX or IY as scratch** in any I/O word — they are return stack pointer and user pointer respectively.
2. **Do NOT nest BDOS_SAVE/BDOS_RESTORE** — each BDOS call must have exactly one matched pair. For TYPE's loop, either save IP once outside and manage BDOS saves per-iteration, or use a completely manual save/restore approach.
3. **Do NOT assume BDOS preserves any registers** — it clobbers everything. Always use BDOS_SAVE/BDOS_RESTORE.
4. **Do NOT use DEFWORD for these primitives** — all I/O words must be CODE words (DEFCODE) because they make BDOS calls directly.
5. **Do NOT forget to consume/produce stack items** — check stack effect comment matches actual PUSH/POP count.
6. **Do NOT leave stale values on the stack** — after consuming parameters, the final POP BC must load the correct new TOS.

### Previous Story Learnings (from Story 1.4)

- EMIT already exists and works (confirmed by test output from stories 1.1-1.4)
- The multiplication primitive (`*`) demonstrates the pattern for saving/restoring DE (IP) when using it as scratch: `PUSH DE` at start, `POP DE` at end — this same pattern is needed for TYPE's loop
- Test threads follow alphabetic/numeric character emission pattern; extend naturally
- All existing tests pass — current EXPECTED string is 52 characters long

### Project Structure Notes

- All changes confined to `src/io.asm` (new words) and `src/constants.asm` (new BDOS constants)
- Test thread extensions in `src/antforth.asm` (after existing tests, before EXECUTE(BYE))
- Makefile EXPECTED string update (line 48)
- No new files needed — no structural changes

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.5] — acceptance criteria and story definition
- [Source: _bmad-output/planning-artifacts/architecture.md#BDOS Interaction Pattern] — mandatory BDOS_SAVE/BDOS_RESTORE pattern
- [Source: _bmad-output/planning-artifacts/architecture.md#Register Usage Discipline] — inviolable register contract
- [Source: _bmad-output/planning-artifacts/architecture.md#Kernel/Forth Boundary] — EMIT, KEY, KEY? must be CODE words
- [Source: src/io.asm] — existing EMIT implementation (reference pattern)
- [Source: src/constants.asm] — existing BDOS constants (C_WRITE=2, P_TERMCPM=0)
- [Source: src/macros.asm:119-130] — BDOS_SAVE/BDOS_RESTORE macro definitions

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None — clean implementation with no errors.

### Completion Notes List

- Task 1: Added C_READ (EQU 1) and C_STATUS (EQU 11) to constants.asm BDOS section
- Task 2: Implemented TYPE, CR, SPACE, SPACES in io.asm following BDOS_SAVE/BDOS_RESTORE pattern. TYPE uses manual DE save outside loop with per-iteration BDOS saves. SPACES handles n<=0 as no-op with signed check.
- Task 3: Implemented KEY and KEY? in io.asm. KEY uses BDOS C_READ (function 1), captures char from A after BDOS_RESTORE. KEY? uses BDOS C_STATUS (function 11), converts 0x00/0xFF result to Forth FALSE (0) / TRUE (0xFFFF).
- Task 4: Added 7 test threads: TYPE with 1-char strings ('s', 't'), TYPE with 0 length (no-op), CR, SPACE, SPACES(2), SPACES(0). All automated tests pass under `make test`. Updated EXPECTED string with printf to handle CR+LF bytes.
- Task 5: Created src/test_key.asm — minimal echo loop for manual KEY testing. Added `test_key` Makefile target and included test_key.com in disk image. Used simpler blocking KEY approach (subtask 5.3).

### Change Log

- 2026-04-04: Implemented all console I/O primitives (TYPE, CR, SPACE, SPACES, KEY, KEY?) and automated + manual test infrastructure
- 2026-04-04: Code review fixes — removed redundant PUSH/POP in SPACES loop, added multi-char TYPE test, added negative SPACES test, added clarifying comments to TYPE/KEY/KEY?

### File List

- src/constants.asm — added C_READ and C_STATUS BDOS constants
- src/io.asm — added TYPE, CR, SPACE, SPACES, KEY, KEY? primitives; review: removed redundant PUSH/POP in SPACES, added comments
- src/antforth.asm — added test threads for I/O primitives, test string data; review: added multi-char TYPE and negative SPACES tests
- src/test_key.asm — new standalone manual test program for KEY
- Makefile — updated EXPECTED string, added test_key target, added test_key.com to disk target
