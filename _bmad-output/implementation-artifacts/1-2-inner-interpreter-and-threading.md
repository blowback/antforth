# Story 1.2: Inner Interpreter & Threading

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a working direct-threaded inner interpreter,
So that I can execute threaded code sequences and verify the core execution model.

## Acceptance Criteria

1. **Given** the .COM binary loads under iz-cpm **When** the cold start protocol runs **Then** SP is set to parameter stack base (top of TPA, below BDOS), IX to return stack base, IY to user variable area, STATE to 0, BASE to 10, HERE to end of kernel, and TIB/>IN to 0

2. **Given** a hardcoded thread `LIT 42, LIT 10, EXECUTE(BYE)` **When** the inner interpreter runs it **Then** NEXT fetches the next cell via DE (IP), loads into HL (W), and jumps via `JP (HL)` to the code field

3. **Given** a hardcoded thread with a colon definition (DOCOL/EXIT) **When** the inner interpreter runs it **Then** DOCOL pushes IP to the return stack (IX) and sets IP to the body **And** EXIT pops IP from the return stack and resumes via NEXT

4. **Given** a hardcoded thread with `LIT` **When** LIT executes **Then** it fetches the inline literal from the thread, pushes it to the parameter stack, and advances IP past the literal

5. **Given** a hardcoded thread with `BRANCH` and `?BRANCH` **When** BRANCH executes **Then** it adds the inline offset to IP (unconditional jump) **When** ?BRANCH executes with 0 (false) on stack **Then** it branches; with non-zero (true) it falls through

## Tasks / Subtasks

- [x] Task 1: Implement full cold start protocol in `antforth.asm` (AC: #1)
  - [x] 1.1 Read BDOS address from 0x0006 to determine TPA top
  - [x] 1.2 Set SP = TPA top (parameter stack base, just below BDOS)
  - [x] 1.3 Set IX = SP - PS_SIZE (return stack base, below parameter stack region)
  - [x] 1.4 Set IY = user variable area base (fixed address after kernel)
  - [x] 1.5 Initialise STATE=0 (interpret mode) via IY+UserArea.state
  - [x] 1.6 Initialise BASE=10 (decimal) via IY+UserArea.base
  - [x] 1.7 Initialise HERE to `kernel_end` label (end of assembled kernel code)
  - [x] 1.8 Initialise TIB pointer and >IN=0 via UserArea fields
  - [x] 1.9 Hash table pre-populated via LUA at assembly time (no runtime zeroing needed)
  - [x] 1.10 Set DE (IP) to point at a test thread, then execute NEXT to begin
- [x] Task 2: Implement LIT in `inner_interpreter.asm` (AC: #4)
  - [x] 2.1 Define `w_LIT` via DEFCODE "LIT" — fetch inline cell from (DE), push old BC (TOS) to SP, load new BC from inline, advance DE by 2
- [x] Task 3: Implement BRANCH in `inner_interpreter.asm` (AC: #5)
  - [x] 3.1 Define `w_BRANCH` via DEFCODE — fetch inline offset from (DE), add offset to DE (IP), NEXT
- [x] Task 4: Implement ?BRANCH (0BRANCH) in `inner_interpreter.asm` (AC: #5)
  - [x] 4.1 Define `w_QBRANCH` via DEFCODE "?BRANCH" — pop TOS (BC), test if zero; if zero, branch (add offset to DE); if non-zero, skip offset (advance DE by 2), NEXT
- [x] Task 5: Implement EXECUTE in `inner_interpreter.asm` (AC: #2)
  - [x] 5.1 Define `w_EXECUTE` via DEFCODE "EXECUTE" — pop execution token from stack into HL, JP (HL)
- [x] Task 6: Create hardcoded test threads and verify (AC: #1-5)
  - [x] 6.1 Create a test thread in `antforth.asm` that exercises LIT, EMIT, BYE — cold start sets IP to this thread and runs NEXT
  - [x] 6.2 Verify .COM builds and iz-cpm exits cleanly (proving NEXT + LIT + BYE work)
  - [x] 6.3 Create a test colon definition that calls EXIT_CODE, verify DOCOL/EXIT round-trip works
  - [x] 6.4 Create a test thread exercising BRANCH (unconditional jump over code)
  - [x] 6.5 Create a test thread exercising ?BRANCH (conditional branch with true/false)
- [x] Task 7: Add EMIT primitive to `io.asm` for observable test output (AC: #2)
  - [x] 7.1 Define `w_EMIT` via DEFCODE "EMIT" — pop char from TOS, output via BDOS C_WRITE (function 2), using BDOS_SAVE/BDOS_RESTORE
  - [x] 7.2 Update test thread to print a character before BYE, confirming stack and threading work visually
- [x] Task 8: Update `make test` to validate (AC: #1-5)
  - [x] 8.1 Ensure `make test` runs antforth.com under iz-cpm and confirms clean exit
  - [x] 8.2 Pipe output and check for expected characters (ABCDE)

## Dev Notes

### What Already Exists (from Story 1.1)

The following are already implemented and **must not be modified** unless there's a bug:

- **DOCOL** (`inner_interpreter.asm:10-21`): Pushes IP (DE) to return stack (IX), sets IP to body (HL+3 past JP DOCOL), uses NEXTHL optimisation
- **EXIT_CODE** (`inner_interpreter.asm:24-30`): Pops IP from return stack (IX), calls NEXT
- **NEXT macro** (`macros.asm:14-17`): EX DE,HL then NEXTHL
- **NEXTHL macro** (`macros.asm:21-28`): Optimised NEXT when HL already holds IP — fetches [HL] into DE, increments HL by 2, EX DE,HL, JP (HL)
- **DEFCODE/DEFWORD/DEFIMMED macros** (`macros.asm`): Full dictionary header construction with LUA-based XOR-rotate hash
- **BDOS_SAVE/BDOS_RESTORE** (`macros.asm:121-130`): Push DE then BC / Pop BC then DE
- **BYE** (`system.asm`): DEFCODE "BYE" — LD C,P_TERMCPM / JP BDOS_ENTRY
- **constants.asm**: All memory layout equates, BDOS function numbers, stack sizes, dictionary flags
- **structures.asm**: DictEntry and UserArea STRUCT definitions

### Cold Start Protocol — Full Implementation Required

The current cold start (`antforth.asm:17-19`) is minimal — it just calls BYE. This story must replace it with the full cold start as specified in the architecture:

```
cold_start:
    ; 1. Read BDOS address from 0x0006 for TPA top
    LD      HL, (BDOS_ADDR_PTR)     ; HL = BDOS base = top of TPA
    ; 2. SP = TPA top (parameter stack base)
    LD      SP, HL
    ; 3. IX = SP - PS_SIZE (return stack base)
    ;    Need to subtract PS_SIZE from HL and load into IX
    LD      DE, PS_SIZE
    SBC     HL, DE                  ; HL = return stack base (note: clear carry first!)
    PUSH    HL
    POP     IX                      ; IX = return stack base
    ; 4. IY = user variable area
    LD      IY, user_area           ; fixed address label
    ; 5. STATE = 0
    LD      (IY+UserArea.state), 0
    LD      (IY+UserArea.state+1), 0
    ; 6. BASE = 10
    LD      (IY+UserArea.base), 10
    LD      (IY+UserArea.base+1), 0
    ; 7. HERE = kernel_end
    LD      HL, kernel_end
    LD      (IY+UserArea.here), L
    LD      (IY+UserArea.here+1), H
    ; 8. TIB and >IN
    LD      HL, tib_buffer
    LD      (IY+UserArea.tib_addr), L
    LD      (IY+UserArea.tib_addr+1), H
    LD      (IY+UserArea.tib_in), 0
    LD      (IY+UserArea.tib_in+1), 0
    ; 9. Zero 64 hash buckets (runtime copy)
    ;    ... loop to zero hash_table area ...
    ; 10. Set IP (DE) to test thread, begin
    LD      DE, test_thread
    NEXT
```

**Important notes for cold start:**
- The hash bucket heads from macros.asm are assembly-time tracking only (for linking dictionary entries). At runtime, the hash table is a 128-byte block (64 x 2-byte pointers) that must be zeroed, then populated from the assembly-time bucket heads. **Alternative approach**: emit the hash bucket table directly as assembled data (DW values from LUA), so cold start doesn't need to copy — the hash table is already populated in the binary. This is simpler and faster.
- `user_area` must be defined as a labelled memory region (use `DS` or reserve space)
- `tib_buffer` must be defined as a 128-byte reserved region
- `kernel_end` label must be placed after all assembled code and data

### LIT Implementation

```z80
; LIT ( -- x )
;   Push inline literal to stack
DEFCODE "LIT", 0
    PUSH    BC              ; Push current TOS to parameter stack
    EX      DE, HL          ; HL = IP
    LD      C, (HL)         ; Load low byte of inline literal
    INC     HL
    LD      B, (HL)         ; Load high byte
    INC     HL              ; IP past the literal
    EX      DE, HL          ; DE = new IP
    NEXT                    ; But note: we just did EX DE,HL; NEXT does EX DE,HL again!
```

**Optimisation note**: Since NEXT starts with `EX DE,HL`, and we just did `EX DE,HL` to put IP back in DE, we should use NEXTHL instead to avoid the double swap:

```z80
DEFCODE "LIT", 0
    PUSH    BC              ; Push current TOS to parameter stack
    EX      DE, HL          ; HL = IP
    LD      C, (HL)
    INC     HL
    LD      B, (HL)
    INC     HL              ; HL = IP past literal
    NEXTHL                  ; Use HL directly as IP
```

### BRANCH Implementation

```z80
; BRANCH ( -- )
;   Unconditional branch: add inline offset to IP
DEFCODE "BRANCH", 0
    EX      DE, HL          ; HL = IP
    LD      E, (HL)
    INC     HL
    LD      D, (HL)         ; DE = offset
    DEC     HL              ; HL = IP (back to start of offset)
    ADD     HL, DE          ; HL = IP + offset (new IP)
    NEXTHL
```

**Note on branch offsets**: The offset is relative to the address of the offset cell itself, not the address after it. This is the standard Forth convention — `BRANCH` with offset 0 is an infinite loop (jumps back to itself), offset 2 is a no-op (falls through). Ensure all branch offset calculations are consistent with this convention.

### ?BRANCH Implementation

```z80
; ?BRANCH ( flag -- )
;   Conditional branch: if flag is 0 (FALSE), branch; else fall through
DEFCODE "?BRANCH", 0
    ; Pop TOS for the flag test
    LD      A, B
    OR      C               ; Test if BC (TOS) is zero
    POP     BC              ; Pop new TOS from stack regardless
    EX      DE, HL          ; HL = IP
    JR      Z, .do_branch   ; If flag was 0, take the branch
    ; Fall through: skip the offset
    INC     HL
    INC     HL              ; IP past the offset
    NEXTHL
.do_branch:
    ; Take the branch: add inline offset to IP
    LD      E, (HL)
    INC     HL
    LD      D, (HL)
    DEC     HL
    ADD     HL, DE          ; HL = IP + offset
    NEXTHL
```

### EXECUTE Implementation

```z80
; EXECUTE ( xt -- )
;   Execute the word whose execution token (code field address) is on the stack
DEFCODE "EXECUTE", 0
    LD      H, B
    LD      L, C            ; HL = xt (code field address)
    POP     BC              ; Pop new TOS
    JP      (HL)            ; Jump to code field
```

### EMIT Implementation (for test observability)

```z80
; EMIT ( char -- )
;   Output character to console via BDOS C_WRITE
DEFCODE "EMIT", 0
    BDOS_SAVE
    LD      E, C            ; E = character (from TOS low byte)
    LD      C, 2            ; BDOS function 2: C_WRITE
    CALL    BDOS_ENTRY
    BDOS_RESTORE
    POP     BC              ; Pop new TOS (EMIT consumes char)
    NEXT
```

**Wait — BDOS_SAVE pushes DE then BC. BDOS_RESTORE pops BC then DE. But after the BDOS call, we need to pop the *consumed* TOS too. Let me reconsider...**

BDOS_SAVE saves: PUSH DE (IP), PUSH BC (TOS). BDOS_RESTORE: POP BC, POP DE. So after BDOS_RESTORE, BC = original TOS (the char we already emitted), DE = original IP. We still need to pop the next stack value into BC as the new TOS:

```z80
DEFCODE "EMIT", 0
    BDOS_SAVE               ; Save DE (IP), BC (TOS=char)
    LD      E, C            ; E = character to output
    LD      C, 2            ; BDOS C_WRITE function
    CALL    BDOS_ENTRY
    BDOS_RESTORE            ; Restore BC (old TOS), DE (IP)
    POP     BC              ; New TOS from parameter stack (EMIT consumes the char)
    NEXT
```

**Correction**: We need to grab E from TOS *before* BDOS_SAVE, or extract it after. Since BDOS_SAVE pushes BC (which holds the char), and then BDOS clobbers everything, we need to get the char into E before the CALL:

```z80
DEFCODE "EMIT", 0
    LD      A, C            ; A = char (save from TOS before BDOS clobbers)
    BDOS_SAVE               ; PUSH DE, PUSH BC
    LD      E, A            ; E = char for BDOS
    LD      C, 2            ; BDOS C_WRITE
    CALL    BDOS_ENTRY
    BDOS_RESTORE            ; POP BC, POP DE — restores IP and old TOS
    POP     BC              ; Pop new TOS (char consumed)
    NEXT
```

### Register Contract Reminders

| Register | Role | Notes |
|----------|------|-------|
| BC | TOS | Top of parameter stack. CODE words receive TOS in BC, must leave new TOS in BC |
| DE | IP | Instruction pointer into threaded code. MUST be preserved or saved/restored |
| SP | Parameter stack | Second-of-stack and below. PUSH/POP for stack operations |
| IX | Return stack | DOCOL pushes, EXIT pops. >R/R> words manipulate this |
| IY | User pointer | Points to UserArea struct. Preserved unless accessing user variables |
| HL | W (scratch) | Free within CODE words. Used by NEXT for dispatch |
| AF | Scratch | Free within CODE words |

### Testing Strategy

Since the outer interpreter doesn't exist yet, testing is done via **hardcoded threads** — DW sequences assembled directly into the binary. The cold start sets IP to a test thread, and NEXT begins execution.

**Test approach for iz-cpm:**
- A test thread that calls LIT to push a value, then EMIT to output a known character, then BYE to exit
- iz-cpm captures stdout — check for expected output character(s)
- If the output matches, the inner interpreter (NEXT, LIT, DOCOL, EXIT) and BDOS interaction all work

**Minimal verification thread:**
```
test_thread:
    DW w_LIT, 'A'       ; Push 65 (character 'A')
    DW w_EMIT            ; Output 'A' to console
    DW w_LIT, 0x0A       ; Push newline
    DW w_EMIT            ; Output newline
    DW w_BYE             ; Exit to CP/M
```

**DOCOL/EXIT test:**
```
; Test colon definition
test_colon:
    DEFWORD "TEST-COLON", 0
    DW w_LIT, 'B'
    DW w_EMIT
    DW EXIT_CODE

test_thread2:
    DW test_colon_code_field  ; Call the test colon definition
    DW w_BYE
```

**BRANCH test:**
```
test_branch_thread:
    DW w_BRANCH            ; Unconditional branch
    DW 4                   ; Skip 4 bytes (jump over the next DW)
    DW w_BYE               ; This should be skipped
    DW w_LIT, 'C'          ; Land here
    DW w_EMIT
    DW w_BYE
```

### Labels and Naming

Per architecture conventions, all word implementations use `w_` prefix labels. The DEFCODE/DEFWORD macros generate `.code_field` local labels. To reference a word's code field from a thread (DW list), use the `.code_field` local label from the DEFCODE/DEFWORD invocation. **However**, since sjasmplus local labels (prefixed with `.`) are scoped to the nearest non-local label, you need to ensure the DEFCODE/DEFWORD is preceded by a global label.

The standard pattern is:
```
w_LIT:
    DEFCODE "LIT", 0
    ...
```

This means `w_LIT.code_field` is the execution token for LIT. Threads reference `w_LIT.code_field`:
```
test_thread:
    DW w_LIT.code_field, 42
    DW w_BYE.code_field
```

**Verify this pattern works with sjasmplus** — the `.code_field` label inside DEFCODE is a local label that should be accessible as `w_LIT.code_field` externally. If not, an alternative is to add explicit `w_NAME` labels inside the DEFCODE macro itself, or use a global label convention.

### BDOS Function Numbers Needed

Add to `constants.asm`:
```
C_WRITE     EQU     2       ; BDOS function 2: console output (E = char)
C_READ      EQU     1       ; BDOS function 1: console input (returns char in A)
C_STATUS    EQU     11      ; BDOS function 11: console status (A = 0 or FF)
```

### Memory Regions to Reserve

At the end of all assembled code (after bootstrap.asm include), reserve:
```
; === Runtime data areas ===
hash_table:     DS  HASH_BUCKETS * 2    ; 128 bytes: 64 hash bucket pointers
user_area:      DS  UserArea            ; User variable area (IY points here)
tib_buffer:     DS  TIB_SIZE            ; 128-byte terminal input buffer
kernel_end:                             ; Label marking end of kernel
```

**Hash table initialisation strategy**: Rather than zeroing the hash table at runtime and copying assembly-time bucket heads, emit the final bucket head values directly using LUA:
```
hash_table:
    LUA ALLPASS
        for i = 0, 63 do
            _pc(string.format("DW 0x%04X", sj.get_label("_hash_bucket_" .. i)))
        end
    ENDLUA
```
This way the hash table is pre-populated in the binary and cold start only needs to set up registers and user variables — no hash table initialisation loop needed.

### Project Structure Notes

- All new code goes into existing files per architecture spec — no new files needed
- `inner_interpreter.asm`: Add LIT, BRANCH, ?BRANCH, EXECUTE (below existing DOCOL/EXIT_CODE)
- `antforth.asm`: Replace minimal cold start with full protocol
- `io.asm`: Add EMIT (first I/O primitive)
- `constants.asm`: Add BDOS function numbers for console I/O
- `kernel_end` label and reserved data areas go at the bottom of `antforth.asm` after all includes
- The test threads are temporary — they'll be replaced by the outer interpreter in Story 2.2

### Previous Story Intelligence

**From Story 1.1 completion:**
- sjasmplus v1.21.0 is installed locally; Docker has v1.22.0+
- iz-cpm v1.3.4 is installed (downloaded pre-built binary from GitHub releases)
- LUA in sjasmplus: `sj.insert_label` works (not `sj.add_label`). `sj.get_define` for reading DEFINE values. String length uses `#name` in LUA (not sjasmplus LEN operator)
- Binary output uses `--raw` CLI flag (SAVEBIN requires DEVICE emulation mode, which we don't use — we use `DEVICE NONE`)
- Current binary is 54 bytes — will grow significantly with new primitives
- DOCOL was moved from macros.asm to inner_interpreter.asm during code review — it's a runtime routine, not a macro

### Git Intelligence

**Recent commits (most recent first):**
1. `55e9474` — add NEXTHL optimisation: Split NEXT into EX DE,HL + NEXTHL, allowing DOCOL (and other code that already has IP in HL) to skip the redundant EX. This pattern should be used in LIT and BRANCH implementations where HL already contains the updated IP.
2. `67b7527` — initial project scaffolding: Full Story 1.1 implementation

**Key pattern**: The NEXTHL optimisation is an established project convention. Any CODE word that computes the new IP in HL should call NEXTHL rather than putting IP back in DE and calling NEXT.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.2] — acceptance criteria and user story
- [Source: _bmad-output/planning-artifacts/architecture.md#Cold Start Protocol] — full cold start sequence
- [Source: _bmad-output/planning-artifacts/architecture.md#Core Architectural Decisions] — memory layout, direct threading, register contract
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns & Consistency Rules] — naming conventions, register discipline, BDOS interaction, comment conventions
- [Source: _bmad-output/planning-artifacts/architecture.md#Code Field Layout] — JP-based direct threading, DOCOL/DOVAR/DOCON
- [Source: _bmad-output/planning-artifacts/architecture.md#Kernel/Forth Boundary] — LIT, BRANCH, ?BRANCH, EXECUTE are CODE words
- [Source: _bmad-output/planning-artifacts/architecture.md#Error Handling & Abort Protocol] — ABORT resets SP only, QUIT resets IX and STATE
- [Source: _bmad-output/implementation-artifacts/1-1-project-scaffolding-and-build-toolchain.md] — previous story learnings, toolchain notes, existing code state

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed sjasmplus label scoping: `.code_field` local labels from DEFCODE macro not accessible externally as `w_NAME.code_field`. Resolution: added explicit `w_NAME_cf` global labels at each code field entry point.
- Fixed BRANCH offset calculation in test threads: offsets must be relative to the offset cell address (label AT the DW, not after it).
- Fixed test colon definition: DEFWORD macro generates JP DOCOL + body, but test thread needs code field address (JP DOCOL), not body address. Built test colon manually without DEFWORD to control labeling.
- Fixed `make test` validation: CR/LF output from iz-cpm caused string comparison mismatch. Removed trailing CR/LF from test thread output.

### Completion Notes List

- **Cold start protocol**: Full implementation replacing Story 1.1 minimal stub. Reads BDOS address for TPA top, initialises SP (parameter stack), IX (return stack), IY (user area), all user variables (STATE=0, BASE=10, HERE=kernel_end, TIB, >IN=0). Hash table pre-populated at assembly time via LUA (no runtime copy needed).
- **LIT**: Pushes inline literal to parameter stack using NEXTHL optimisation.
- **BRANCH**: Unconditional branch with offset relative to offset cell address. Uses NEXTHL.
- **?BRANCH**: Conditional branch — branches on zero (false), falls through on non-zero (true). Uses NEXTHL.
- **EXECUTE**: Pops execution token from stack and jumps to code field.
- **EMIT**: Console output via BDOS C_WRITE with proper register save/restore protocol.
- **Test verification**: Comprehensive test thread outputs "ABCDE" — each character validates a different primitive. `make test` pipes output and validates expected string.

### File List

- `src/antforth.asm` — Full cold start protocol, test threads, hash table, runtime data areas (user_area, tib_buffer, kernel_end)
- `src/inner_interpreter.asm` — Added LIT, BRANCH, ?BRANCH, EXECUTE; updated file header comment
- `src/io.asm` — Added EMIT primitive (was stub)
- `src/system.asm` — Added w_BYE and w_BYE_cf labels for code field access
- `src/constants.asm` — Added C_WRITE BDOS function number
- `Makefile` — Enhanced `make test` to validate expected output "ABCDE"
- `_bmad-output/planning-artifacts/architecture.md` — Updated thread reference examples to use `_cf` suffix convention
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — Sprint status tracking

### Change Log

- 2026-03-15: Story 1.2 implementation complete — inner interpreter primitives (LIT, BRANCH, ?BRANCH, EXECUTE, EMIT), full cold start protocol, comprehensive test thread verification
- 2026-03-15: Code review fixes — (1) Added EXECUTE test to thread (LIT w_BYE_cf + EXECUTE replaces direct BYE call), (2) Cold start now initializes all UserArea fields (LATEST, tib_len, source_id), (3) inner_interpreter.asm word headers updated to dashed-line format, (4) Architecture doc updated with _cf label convention
