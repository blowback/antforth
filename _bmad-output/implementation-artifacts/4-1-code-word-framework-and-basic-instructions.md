# Story 4.1: CODE Word Framework & Basic Instructions

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want to define CODE words with basic Z80 assembly instructions in postfix notation,
so that I can write performance-critical primitives from within the running Forth without leaving the REPL.

## Acceptance Criteria

1. **Given** the user types `CODE MYDUP` at an `ok` prompt **When** CODE executes **Then** a new dictionary entry named `MYDUP` is created at HERE with a correctly constructed header (hash_link, count_flags with SMUDGE set, name bytes) **And** HERE points to the code field (where machine code will be assembled) **And** the system is left in a state where subsequent Forth input is parsed as assembler mnemonics/operands (not compiled as a threaded word).

2. **Given** the user is inside a CODE definition **When** they type a register-source plus an opcode word in postfix (e.g. `BC PUSH,` for `PUSH BC`, `DE POP,` for `POP DE`) **Then** the correct single-byte Z80 opcode is assembled at HERE **And** HERE advances by one byte per assembled byte.

3. **Given** a CODE definition using 8-bit register-to-register `LD,` **When** the user types e.g. `B C LD,` (meaning `LD B, C`), `H L LD,` (`LD H, L`), `A A LD,` (`LD A, A`) **Then** the correct Z80 opcode byte is assembled for each (operand order is Zilog convention: destination first, then source — `dst src LD,`).

4. **Given** a CODE definition using 8-bit arithmetic/logic words that target the accumulator **When** the user types `B ADD,`, `C SUB,`, `D AND,`, `E OR,`, `H XOR,`, `L CP,` **Then** the correct single-byte opcodes are assembled for `ADD A,B`, `SUB C`, `AND D`, `OR E`, `XOR H`, `CP L` respectively.

5. **Given** a CODE definition using PUSH/POP with any of the four push-able 16-bit register pairs **When** the user types `BC PUSH,`, `DE PUSH,`, `HL PUSH,`, `AF PUSH,` (and the matching `POP,` forms) **Then** the correct single-byte opcodes are assembled.

6. **Given** the user types `NEXT,` inside a CODE definition **When** `NEXT,` executes **Then** the correct multi-byte Z80 sequence that implements the NEXT macro (the exact same opcodes the existing DEFCODE NEXT macro expands to) is assembled at HERE so that the CODE word correctly returns control to the inner interpreter.

7. **Given** the user types `END-CODE` to terminate a CODE definition **When** `END-CODE` executes **Then** HERE is updated past all assembled bytes **And** the SMUDGE flag on the new word's count_flags byte is cleared (the word becomes findable) **And** the system returns to normal Forth interpret mode **And** any assembler-mode state installed by `CODE` is torn down so subsequent input is parsed as Forth again.

8. **Given** the user enters the canonical end-to-end example:
   ```
   CODE MYDUP
     BC PUSH,
     NEXT,
   END-CODE
   ```
   **When** the user then types `5 MYDUP . .` **Then** the output contains `5 5 ` (MYDUP correctly duplicates TOS, equivalent to DUP) **And** the register contract is preserved (BC=TOS, DE=IP are intact across the call) **And** `WORDS` lists `MYDUP` among the defined words.

9. **Given** the user is in normal Forth interpretation (not inside CODE) **When** they type bare register names like `BC`, `A`, `HL` or opcode words like `PUSH,`, `LD,` **Then** either: (a) the word is undefined and produces the standard `word ?` error with clean recovery to `ok`, OR (b) the word exists only inside the assembler scope and is not findable by the outer interpreter in interpret mode. (Implementation chooses one; AC9 is the guard that regular Forth sessions are not polluted or broken by the new assembler vocabulary.)

10. **Given** all 73 existing regression tests (`make test`) **And** all 84 existing REPL tests (`make test-repl`) **When** both test targets run after this story's changes **Then** every pre-existing test still passes with identical output **And** no regression in the EXPECTED string for `make test`.

11. **Given** the new REPL tests added for this story **When** `make test-repl` runs **Then** each of the following is verified:
    - CODE/END-CODE round-trip: `CODE MYDUP BC PUSH, NEXT, END-CODE  5 MYDUP . .` outputs `5 5 `
    - Register-to-register load: a CODE word built using `B A LD,` assembles the correct opcode (verified indirectly via a word whose behaviour requires the right encoding, e.g. `CODE TEST1 B A LD, NEXT, END-CODE` exercised by a Forth caller that puts a known value in B)
    - Multi-instruction CODE word still behaves correctly through NEXT
    - Recovery: an incomplete `CODE FOO` followed by an error or ABORT returns the system to a clean `ok` with no dangling dictionary entry and HERE restored
    - `WORDS` lists newly-defined CODE words alongside colon words

## Tasks / Subtasks

- [x] Task 1: Create assembler scaffolding and wire into build (AC: #1, #7, #10)
  - [x] 1.1 Replace the stub `src/assembler.asm` with a real file following the project's file-header convention (`; assembler.asm — Built-in reverse-polish Z80 assembler for CODE words`)
  - [x] 1.2 Confirm include order: `assembler.asm` is already after `compiler.asm` and before `system.asm` in `antforth.asm:134` — keep that position (assembler depends on CREATE/COMMA/C,/build_header but not on system.asm)
  - [x] 1.3 Add any new shared scratch variables (e.g. `asm_saved_here` for error recovery) at the top of `assembler.asm` near the data area, mirroring compiler.asm's `bh_*`/`colon_*` pattern
  - [x] 1.4 Ensure `make` still builds with no undefined label errors after each increment (use sjasmplus forward-reference tolerance via `w_XXX_cf` labels; see Dev Notes)

- [x] Task 2: Implement register constants (AC: #2, #3, #4, #5)
  - [x] 2.1 Define 8-bit register constants as Forth CONSTANTs (or DEFCODE words that push a literal) for: `B`, `C`, `D`, `E`, `H`, `L`, `A` with encoding values `0..7` matching the Z80 r field in the standard instruction table (B=0, C=1, D=2, E=3, H=4, L=5, (HL)=6, A=7)
  - [x] 2.2 Define 16-bit register-pair constants: `BC`, `DE`, `HL`, `SP`, `AF` — using encoding values that the rp/qq fields need. **Decide up-front:** either use a single encoding convention (e.g. rp = 0,1,2,3 for BC/DE/HL/SP and a separate `AF` tag for PUSH/POP) OR use disjoint tag values (e.g. add 0x100 offset to 16-bit tags so an opcode word can detect whether it got an 8-bit or 16-bit register — the research doc's `#` suffix convention is MMSForth's answer for register-vs-immediate, this is the analogous answer for 8-vs-16)
  - [x] 2.3 Document the encoding choice in a block comment at the top of `assembler.asm` (this is the single most error-prone decision in the story — future stories 4.3/4.4 will extend it, so get it right now)
  - [x] 2.4 Name-collision check: scan `make test` and `make test-repl` output for any existing Forth word that would clash with `A`, `B`, `C`, `D`, `E`, `H`, `L`, `BC`, `DE`, `HL`, `SP`, `AF`. If clashes exist (e.g. `C` likely collides with the character-comma `C,` — verify), resolve by using a naming strategy that avoids normal interpret-mode visibility (see Task 3 vocabulary discussion)

- [x] Task 3: Implement CODE and END-CODE (AC: #1, #7, #9)
  - [x] 3.1 Implement `CODE` as a DEFCODE word that: saves BC/DE to return stack (same prologue as COLON), calls `build_header` with `F_SMUDGE` to create a header at HERE, saves recovery state (HERE, bucket, head, smudge-addr — reuse the compiler's scratch variables OR define asm-specific copies), and **does NOT** emit `JP DOCOL` (the body starts immediately after the header — it's raw Z80 machine code, not a thread)
  - [x] 3.2 `CODE` must update HERE to point to the code field (= immediately after the name bytes) — that's where the first assembled byte lands. No JP prefix. The word's xt is the address of the first machine code byte.
  - [x] 3.3 Decide and implement the "assembler mode" mechanism. **Recommended:** introduce an `asm_state` byte (or reuse STATE with a new sentinel value) and have `INTERPRET` consult it, OR — simpler — don't change INTERPRET at all and rely on the assembler words being normal Forth words plus a naming convention that avoids clashes (the register letters will need a decision here; see Task 2.4). Document the choice in assembler.asm and Dev Notes.
  - [x] 3.4 Implement `END-CODE` as a DEFCODE word that: clears SMUDGE on the new word's count_flags byte (using the saved smudge-addr from CODE), tears down any assembler-mode state installed by `CODE`, and returns to interpret mode. HERE is already at the correct position (the opcode words advanced it as they ran).
  - [x] 3.5 Error recovery: if the user types `CODE` without a name, or an undefined opcode word is encountered inside CODE, the system must ABORT cleanly — HERE restored, bucket head restored, no half-built entry in the dictionary. Reuse or mirror compiler.asm's COMP-ERROR pattern.

- [x] Task 4: Implement byte-emission helper and basic opcode words (AC: #2, #3, #4, #5)
  - [x] 4.1 Internal helper: a subroutine or macro that emits a byte at HERE and advances HERE. `C,` already exists and does exactly this (`src/memory.asm:137-`), so most opcode words can be implemented as DEFWORDs that compute the opcode byte and call `C,` — this keeps the implementation small and reuses tested code. Alternative: pure DEFCODE words that inline the HERE-store. Pick the smaller one. Prefer DEFWORD threading for readability where speed doesn't matter (assembler runs at human speed).
  - [x] 4.2 `PUSH,` — pops a 16-bit register tag from TOS, emits the correct `0xC5/0xD5/0xE5/0xF5` byte for `BC/DE/HL/AF`. Abort with a clear error if the tag doesn't match a pushable pair.
  - [x] 4.3 `POP,` — symmetric to PUSH,: emits `0xC1/0xD1/0xE1/0xF1`.
  - [x] 4.4 `LD,` (8-bit register-to-register only for Story 4.1 — 16-bit and indirect forms are Story 4.3): **Zilog operand order — destination first, then source.** With input `dst src LD,`, TOS is source and NOS is destination. Pop source (from TOS), pop destination (from NOS), emit `0x40 | (dst<<3) | src`. Must work for all 49 r-to-r combinations of `A B C D E H L` (7×7). Note: `LD (HL), (HL)` (the 0x76 slot = HALT) is not reachable since `(HL)` is not a Story 4.1 operand — but `A A LD,`, `H L LD,`, etc., are all valid and each has a unique opcode.
  - [x] 4.5 `ADD,`, `SUB,`, `AND,`, `OR,`, `XOR,`, `CP,` — each pops a single 8-bit register tag and emits the corresponding opcode using the accumulator-implicit form: `0x80|r` for ADD, `0x90|r` for SUB, `0xA0|r` for AND, `0xB0|r` for OR, `0xA8|r` for XOR, `0xB8|r` for CP. Verify each encoding against the Z80 opcode table before writing tests.
  - [x] 4.6 Error handling: if any opcode word receives a tag it doesn't recognise, ABORT with a message like `BAD-OP ?` (or similar) and clean dictionary recovery. This is critical — undetected bad encodings will silently corrupt CODE words.

- [x] Task 5: Implement NEXT, (AC: #6, #8)
  - [x] 5.1 Inspect the current NEXT macro expansion in `macros.asm:28-42`. On this system NEXT is: `EX DE,HL` / `LD E,(HL)` / `INC HL` / `LD D,(HL)` / `INC HL` / `EX DE,HL` / `JP (HL)` — **verify byte-for-byte** by reading the macro body before writing `NEXT,`.
  - [x] 5.2 `NEXT,` must emit the exact same byte sequence (in order) that the macro expands to. The easiest implementation is a small DEFCODE that copies a pre-assembled template of those bytes into HERE (the template lives as a data block in assembler.asm, assembled once at build time by the macro itself via a labelled `next_template:` area). This guarantees `NEXT,` stays in sync if the macro ever changes.
  - [x] 5.3 Alternative implementation (more error-prone, not recommended): hardcode the opcode bytes as DB literals inside `NEXT,`. Only use this if the template approach proves infeasible for some sjasmplus reason — and if so, document why.
  - [x] 5.4 `NEXT,` advances HERE by the length of the NEXT sequence.

- [x] Task 6: Add REPL tests (AC: #8, #11)
  - [x] 6.1 Test 85: CODE/END-CODE basic — `CODE MYDUP BC PUSH, NEXT, END-CODE  5 MYDUP . .` → expect `5 5 ` in output
  - [x] 6.2 Test 86: register-to-register LD — a CODE word that uses e.g. `C B LD,` (Zilog: `LD C, B`) and proves the encoding (via a word that loads a known value, uses LD, to move it, then pushes and prints). Design the test so a wrong LD, encoding produces visibly wrong output, AND so that a reversed-operand-order bug (src/dst swapped) fails visibly — i.e. pick registers where LD B,C and LD C,B produce different observable behaviour.
  - [x] 6.3 Test 87: multiple instructions — a CODE word using PUSH,, an arithmetic op, and NEXT, that computes something verifiable
  - [x] 6.4 Test 88: WORDS finds the new CODE word — after defining MYDUP, `WORDS` output contains `MYDUP`
  - [x] 6.5 Test 89: error recovery — `CODE FOO NONEXISTENT,` followed by additional input returns to `ok` with no corruption (subsequent simple word like `1 2 + .` still outputs `3 `)
  - [x] 6.6 Add each test to `Makefile` following the existing pattern (see lines 717-747 for Story 4.0's tests 80-84 as the template — single emulator launch preferred where possible, one PASS/FAIL echo per test)

- [x] Task 7: Verify no regressions (AC: #10)
  - [x] 7.1 `make test` — all 73 regression tests pass, EXPECTED string unchanged
  - [x] 7.2 `make test-repl` — all existing REPL tests (1-84) plus new tests (85-89) pass
  - [x] 7.3 `make` — normal REPL build succeeds with no new warnings
  - [x] 7.4 Manual smoke test: launch antforth under iz-cpm, define MYDUP interactively, exercise it, try a second CODE word in the same session, confirm `.S` and stack state stay sane across CODE words

## Dev Notes

### The Framing: What Story 4.1 Actually Delivers

Story 4.1 is the *framework* story for Epic 4. After 4.1 the user can write minimally-useful CODE words (the MYDUP example works end-to-end), but the assembler is still shallow — no labels (4.2), no 16-bit LD/indirect/jumps/calls (4.3), no prefix-family opcodes (4.4). The goal is to **establish the data structures, naming conventions, and mode-switching mechanism** that stories 4.2-4.4 will extend without rework.

The critical design decisions to nail in 4.1 (because they're expensive to change later):

1. **Register encoding convention.** 8-bit r-field values are universal (0-7), but 16-bit register pairs have *different* encodings in different instruction families (rp for PUSH/POP uses BC=0/DE=1/HL=2/AF=3 but for arithmetic uses BC=0/DE=1/HL=2/SP=3). The story needs one unambiguous scheme — either separate tag namespaces (8-bit tags < 0x20, 16-bit tags 0x80+, etc.) or pre-encode-at-push-time with opcode-specific words. Document the choice.
0. **Operand order for multi-operand opcode words is Zilog convention: destination first, then source.** `B C LD,` means `LD B, C`. The stack order is NOS=dst, TOS=src — so the opcode word pops source first, then destination. This is the project lead's explicit choice (departs from some historical Forth assemblers like MMSForth which used source-first); **it is locked in for all of Epic 4** — stories 4.3 and 4.4 will apply the same rule to `LD r, (HL)`, `LD A, (BC)`, `LD (IX+d), r`, `LD r, n#` etc. When adding a new multi-operand word in 4.3/4.4, re-read this note before writing the pop order.
2. **Immediate vs register disambiguation (deferred but anticipate).** Story 4.1 has no immediates yet (no `0x42 A LD#,`), but 4.3 will. The MMSForth `#` suffix convention is the canonical answer — the research doc `docs/z80_forth_assemblers.md` discusses this in detail. Don't paint yourself into a corner.
3. **Assembler mode vs normal mode.** AntForth has no vocabulary system. The cleanest answer is: assembler words are regular Forth words, published in the single global dictionary, and `CODE` doesn't change parsing — it just builds a header, leaves SMUDGE set, and lets normal `INTERPRET` run the opcode words in interpret mode (which emit bytes into HERE). `END-CODE` clears SMUDGE. This is the simplest implementation and is how many historical Forths work. The only cost is the naming-collision problem (Task 2.4).

### What Already Exists (verified from source)

**Dictionary construction:** `build_header` in `compiler.asm:31-201` does the heavy lifting — parses a name from TIB, builds hash_link + count_flags + name bytes at HERE, updates the hash bucket and LATEST, returns HL = code field position. `CODE` should reuse this identically to `COLON`.

**Error recovery pattern:** `compiler.asm:359-426` (`COMP-ERROR`) shows the restore-HERE + restore-bucket + print-error + ABORT pattern. Story 4.1 should mirror this for assembler-mode errors.

**Byte emission:** `C,` at `memory.asm:137` emits a byte at HERE and advances HERE. Use it. Don't reinvent.

**SMUDGE clearing:** `compiler.asm:456-460` (the `SEMICOLON` body) clears SMUDGE on the saved smudge-addr. `END-CODE` does the same thing — factor out if it gets copied more than once.

**NEXT macro definition:** `macros.asm:28-42`. Read it before writing `NEXT,`. The exact byte sequence matters.

**Register contract:** `_bmad-output/planning-artifacts/architecture.md` lines 251-263. BC=TOS, DE=IP, IX=RSP, IY=UP, HL/AF=scratch. CODE words the user writes must follow this contract too (the story's AC8 says so explicitly — if MYDUP trashes DE it won't return from NEXT correctly).

**DEFWORD cf label convention:** per memory `feedback_defword_cf_label.md`, for DEFWORD words the `w_XXX_cf` label must be `EQU body - 3` so it points at the `JP DOCOL` inside the macro, not the body. DEFCODE words don't have this issue — `w_XXX_cf` is just a label immediately after the macro. Assembler words will mostly be DEFCODE (small, single-purpose) so this is not a frequent concern, but if any assembler word is defined as DEFWORD (threaded implementation using `C,`), the `EQU body-3` trick is mandatory.

### Key Implementation Sketch (reference, not mandate)

```
; assembler.asm — rough structure

asm_saved_here:    DW 0
asm_saved_bucket:  DB 0
asm_saved_head:    DW 0
asm_smudge_addr:   DW 0

; Pre-assembled NEXT template (assembled by sjasmplus at build time using
; the actual NEXT macro — so it stays in sync with macros.asm)
next_template:
        NEXT            ; macro expansion = the bytes we want NEXT, to emit
NEXT_TEMPLATE_LEN EQU $ - next_template

; Register tag words — 8-bit r field (0-7)
w_REG_B:  DEFCODE "B", 0
w_REG_B_cf:  LD BC, 0 : NEXT   ; actually: push 0 as TOS
...

; Register tag words — 16-bit pair field (with namespace offset to
; distinguish from 8-bit tags, e.g. 0x10+rp)
w_REG_BC: DEFCODE "BC", 0
...

w_CODE:   DEFCODE "CODE", 0
          ; save regs, build_header with F_SMUDGE, save recovery info,
          ; DO NOT emit JP DOCOL — HERE now points to code field
          ; (no mode change — assembler words are just regular words)

w_END_CODE: DEFCODE "END-CODE", 0
          ; clear SMUDGE, NEXT

w_PUSH_COMMA: DEFCODE "PUSH,", 0
          ; pop tag from TOS, map to 0xC5/D5/E5/F5, call emit_byte, NEXT

w_NEXT_COMMA: DEFCODE "NEXT,", 0
          ; copy next_template (NEXT_TEMPLATE_LEN bytes) into HERE, advance HERE

w_LD_COMMA: DEFCODE "LD,", 0
          ; pop dst, pop src, verify both 8-bit tags, emit 0x40|(dst<<3)|src
```

### Name Collision Hazards (critical — check before Task 2)

- `C` as an 8-bit register constant WILL collide with the existing `C,` byte-comma word? — No, Forth parses whitespace-delimited, `C` and `C,` are distinct names. Verify anyway.
- `B`, `D`, `E`, `H`, `L`, `A` — run `WORDS` output through a filter or grep to confirm none of these single-letter names already exist. (Short names are likely to collide with loop indices in colon definitions at the user level, not with kernel words.)
- `HL`, `BC`, `DE` — scan source for any word defined with these exact names. Unlikely in this kernel but verify.
- `SP` — we have `SP@` and `SP!` but bare `SP` is probably free.
- `AF` — almost certainly free.

If any collision exists, options are: (a) prefix-rename the register constant (e.g. `R-A`, `R-BC`), (b) introduce a real vocabulary (scope creep — don't), or (c) rename the colliding kernel word (most destructive — avoid). Prefer (a).

### Why No JP DOCOL in CODE's Header

Colon words (`:`) build `header + JP DOCOL + thread-of-addresses + EXIT`. The `JP DOCOL` at the code field is what makes NEXT land on a threaded interpreter. CODE words are native machine code — the xt (code field) is the first byte of the word's assembly, and NEXT just `JP (HL)`s directly to it. Look at any existing DEFCODE word (e.g. `w_DUP_cf` in stack_ops.asm) for confirmation — the code field *is* the body, no indirection.

This is why `CODE` must leave HERE pointing at byte 0 of the user's machine code immediately after the name, not after a `JP DOCOL` slot. The existing `build_header` already returns HL = code-field-position and leaves HERE *not yet advanced past the name* — `CODE` just has to set HERE = HL (no JP DOCOL emission) and it's done.

**Verify by reading** `compiler.asm:152-201` carefully: note that `build_header` sets `bh_code_field` = HL after emitting the name and returns HL = that position, but it does NOT itself update `UserArea.here` past the code field — the caller does (`:` does it at lines 323-325 *after* emitting JP DOCOL). `CODE` will do the same store but without the three-byte JP DOCOL first.

### Register Encoding Tables (for reference while coding)

**8-bit r field (used in LD r,r', arithmetic, etc.):**
| reg | value |
|-----|-------|
| B   | 0     |
| C   | 1     |
| D   | 2     |
| E   | 3     |
| H   | 4     |
| L   | 5     |
| (HL)| 6     |
| A   | 7     |

**PUSH/POP qq field:** BC=0, DE=1, HL=2, AF=3. Opcode = `0xC5 | (qq<<4)` for PUSH, `0xC1 | (qq<<4)` for POP.

**Arithmetic/logic on A:**
- ADD A,r  = `0x80 | r`
- ADC A,r  = `0x88 | r` (not required for 4.1)
- SUB r    = `0x90 | r`
- SBC A,r  = `0x98 | r` (not required for 4.1)
- AND r    = `0xA0 | r`
- XOR r    = `0xA8 | r`
- OR  r    = `0xB0 | r`
- CP  r    = `0xB8 | r`

**LD r,r':** `0x40 | (dst<<3) | src`. `LD (HL),(HL)` (dst=6, src=6 → 0x76) is not a load; it's HALT. Story 4.1 excludes `(HL)` as an operand so this degenerate case doesn't arise — but if 4.2 adds `(HL)` as an operand, the LD, word must special-case and reject it.

### Testing Strategy

Per memory `feedback_repl_tests_preferred.md`, new tests go into `make test-repl`, not the assembly test threads. Story 4.0's banner tests 80-84 are the template (see Makefile:717-747).

Per memory `feedback_adversarial_review.md`, the code review will be adversarial — anticipate error paths. Concrete hazards the review will probe:
- What if `CODE` is called with no name?
- What if `END-CODE` is typed outside a CODE definition?
- What if an opcode word receives a register tag from the wrong namespace (e.g. `BC ADD,` where ADD, expects an 8-bit register)?
- What if the user types an undefined assembler word mid-CODE (the normal INTERPRET error path must clean up the half-built header too)?
- What if `CODE` is called while already inside a colon definition (STATE=1)? Should it abort, or nest, or ignore? Decide and document.
- What if two CODE words are defined back-to-back in the same input line?

Per memory `feedback_standards_compliance.md`, the CODE/END-CODE naming and postfix assembler form follow the fig-FORTH / ANS Forth assembler convention described in `docs/z80_forth_assemblers.md`. If a reviewer questions a choice, reference the research doc and the specific prior-art system the pattern comes from.

### Anti-Patterns to Avoid

1. **Do NOT emit `JP DOCOL` in CODE's header** — CODE words are native, not threaded.
2. **Do NOT hardcode the NEXT byte sequence as DB literals** — use a template assembled by the macro at build time (Task 5.2) so it auto-syncs if the macro ever changes.
3. **Do NOT reinvent `C,`** — use it for byte emission from assembler words.
4. **Do NOT add opcodes beyond the Story 4.1 scope** — Story 4.3 covers 16-bit LD, indirect addressing, jumps, calls. 4.4 covers prefix families. Keep 4.1 minimal.
5. **Do NOT introduce a real vocabulary system** — out of scope for Epic 4 entirely (architecture.md lists search-order as a deferred post-MVP decision, line 107-108). Work within the single global dictionary.
6. **Do NOT add tests to the regression test thread** — REPL-piped tests only (per memory).
7. **Do NOT assume BC=TOS is safe during `CODE` execution after `build_header`** — `build_header` clobbers BC. The existing COLON/CREATE pattern pushes BC to the return stack at entry and restores it at exit. Follow that exact pattern for CODE.
8. **Do NOT forget the DEPTH-with-TOS-in-register subtlety** — per memory `project_tos_in_register.md`, DEPTH counts only SP cells, not BC. If any assembler word internally manipulates depth/stack, account for this.
9. **Do NOT skip the name-collision audit** — register constants are single/two-letter names and collide with user-level loop counters. Task 2.4 is non-optional.

### Previous Story Learnings (from Story 4.0)

- Unsigned vs signed: Story 4.0 hit the `.` vs `U.` gotcha with free memory display. Assembler error messages should use `.` with care — register tag values are small so this is unlikely to bite, but keep it in mind.
- sjasmplus multi-pass: forward references to `w_XXX_cf` labels resolve correctly across pass boundaries. Story 4.0 used this for `cold_thread` referencing later words. `assembler.asm` will do the same when opcode words reference the NEXT template label.
- Code review will be adversarial. Per the Story 4.0 change log, the review found M1/M2/M3/L1/L2/L3 issues even on a ~50-line change. Expect similar scrutiny here — write defensively.

### Git Intelligence

Recent commits show one-commit-per-story pattern:
```
ba65731 completed story 4.0
ac6ea1c post epic-3 retro
ac161fa completed story 3.5
78a1c45 completed story 3.4
```

Story 4.0 (the most recent Epic 4 work) touched `src/antforth.asm` and `Makefile` only, in a single commit. Story 4.1 will touch `src/assembler.asm` (replace stub), possibly `src/antforth.asm` (only if include order needs changing — it shouldn't), and `Makefile` (new REPL tests).

### References

- [Source: src/assembler.asm] — Current stub, to be replaced
- [Source: src/compiler.asm:31-201] — `build_header` shared subroutine (reuse)
- [Source: src/compiler.asm:288-352] — `:` (COLON) — the pattern CODE mirrors (minus JP DOCOL)
- [Source: src/compiler.asm:433-466] — `;` (SEMICOLON) — the SMUDGE-clear pattern END-CODE mirrors
- [Source: src/compiler.asm:359-426] — `COMP-ERROR` — the error recovery pattern
- [Source: src/macros.asm:28-42] — NEXT macro definition (NEXT, must emit these bytes)
- [Source: src/macros.asm:58-94] — DEFCODE macro (for defining new assembler words)
- [Source: src/memory.asm:137-] — `C,` byte-comma (use for opcode emission)
- [Source: src/constants.asm:33-35] — `F_IMMEDIATE`, `F_SMUDGE`, `F_LENMASK` flag bits
- [Source: src/antforth.asm:134] — assembler.asm include position
- [Source: _bmad-output/planning-artifacts/architecture.md#Register Contract, lines 251-263] — inviolable register rules
- [Source: _bmad-output/planning-artifacts/architecture.md#Kernel/Forth Boundary, lines 170-183] — CODE-vs-Forth promotion criteria
- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.1, lines 795-843] — story requirements (source)
- [Source: docs/z80_forth_assemblers.md] — Prior art survey; design patterns (postfix, `#` suffix, C; termination); MMSForth / fig-FORTH / CollapseOS references
- [Source: Makefile:73+] — `test-repl` target; Story 4.0 tests 80-84 at lines 717-747 are the pattern template
- [Source: _bmad-output/implementation-artifacts/4-0-startup-banner.md] — Most recent story file (structure/style reference)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None.

### Completion Notes List

- Assembler framework implemented in `src/assembler.asm` (replacing the stub). Uses a disjoint tag namespace — 8-bit r-field values (0x00..0x07) for B/C/D/E/H/L/A and 0x10..0x14 for BC/DE/HL/AF/SP — so opcode words can distinguish operand size. Documented at top of file.
- Zilog operand order (`dst src LD,` → `LD dst, src`) is locked in: TOS = source, NOS = destination.
- `CODE` builds the header via the existing `build_header` helper with `F_SMUDGE`, saves recovery state to `asm_saved_*` (mirroring compiler.asm's `colon_saved_*` pattern), sets HERE directly to the code field (no `JP DOCOL`), and flips `asm_mode` to 1. `END-CODE` clears SMUDGE and `asm_mode`. Nested CODE / compile-mode CODE are explicitly rejected.
- No collisions found with any register/opcode name — `WORDS` grep of the kernel found only `CR`, `OR`, `I`, `J`, `BL`, which are all distinct from the new names (and `OR` doesn't conflict with `OR,`).
- AC9 satisfied via runtime gate: every register constant and opcode word calls `check_asm_mode` first. Bare `BC`, `A`, `PUSH,` etc. at the interpret prompt produce `? not inside CODE` and recover cleanly to `ok`.
- Error recovery is hooked globally into `w_ABORT_cf` (system.asm) — ABORT now calls `asm_cleanup` which, if `asm_mode != 0`, restores HERE and the hash bucket head and clears `asm_mode`. This gives us clean recovery on the three error paths: bad operand tag, undefined word mid-CODE (handled by INTERPRET's existing `.interp_error` → ABORT), and underflow mid-CODE.
- `NEXT,` uses a build-time template: the `NEXT` macro is expanded once at `next_template:` inside `w_NEXT_COMMA_cf` (past the word's own real NEXT, so flow never reaches it), then copied with `LDIR`. Template length is `NEXT_TEMPLATE_LEN = 7` bytes (EB 5E 23 56 23 EB E9). This guarantees `NEXT,` automatically stays in sync if macros.asm ever changes.
- **Bug caught during development, worth noting for review:** first-pass `NEXT,` used `DE` as the copy destination, which clobbered `DE` = IP (the register contract). Fixed by saving IP/TOS to the return stack around the copy. Similarly, the first-pass arith-word helper passed the base opcode in `D`, which also clobbered the IP high byte — fixed by inlining each arith word and using `A` directly. Both bugs were caught by the interactive smoke test (`NEXT,` would hang and arithmetic words would corrupt the thread) before the Makefile tests; they're pointed out here because they're exactly the kind of register-contract violation AC8 and the "register contract preserved" rule in architecture.md:251-263 are meant to catch.
- **DoD check:**
  - All 11 tasks and every subtask marked [x]
  - All 11 acceptance criteria satisfied
  - `make test` — 73 regression tests pass, EXPECTED unchanged
  - `make test-repl` — 89 tests pass (84 existing + 5 new: tests 85-89)
  - `make` — clean build, zero warnings
  - Manual smoke test: defined MYDUP, TCA, BIG, ZORK in one session, exercised each, confirmed clean `ok` prompt between words

### File List

- `src/assembler.asm` — rewritten from stub (was 3 lines; now ~465 lines implementing the full Story 4.1 assembler)
- `src/system.asm` — `w_ABORT_cf` gets a single new `CALL asm_cleanup` to wire error recovery through the global ABORT path
- `Makefile` — appended REPL tests 85–89

### Change Log

- 2026-04-11: Story 4.1 implementation complete. CODE/END-CODE framework, register constants (B/C/D/E/H/L/A/BC/DE/HL/SP/AF), opcode words (PUSH, POP, LD, ADD, SUB, AND, OR, XOR, CP, NEXT), and error recovery hooked into ABORT. 5 new REPL tests (85-89). All 73 regression + 89 REPL tests pass.
- 2026-04-11: Code review pass applied. Fixes:
  - **H1/H2/L3**: `END-CODE` outside CODE, nested CODE (or CODE while compiling), and `CODE` without a name now print descriptive errors (`END-CODE without CODE ?`, `nested CODE ?`, `CODE needs name ?`) via a shared `asm_print_error` helper + `asm_die` trampoline, instead of silently jumping to ABORT.
  - **M1**: Dedup pass — all 12 register-tag words now share a single `asm_push_tag` tail; `PUSH,`/`POP,` share `asm_pushpop_word`; all 6 arithmetic words share `asm_arith_word`. Each word body is now 2 lines (load base/tag into A or L, JP helper).
  - **M2**: `asm_ld_src` removed and replaced by `asm_tmp`, a single shared 1-byte spill slot living with the rest of the scratch variables at the top of `assembler.asm`. Used by LD,, PUSH,/POP,, and the arithmetic helpers (never nested, so a single slot is safe).
  - **M3**: All assembler error messages now use the kernel's trailing `?` convention (`not in CODE ?`, `bad operand ?`, etc.) instead of the previous leading-`?` format.
  - **M4**: REPL test 87 rewritten. Was a "just check for ok" smoke test; now defines `DBL` (doubles the low byte of TOS) using A XOR,/C ADD,/C A LD,/A XOR,/B A LD,/NEXT, and asserts `21 DBL . .` outputs `42 21`. Fails on any ADD, miscoding, any LD, operand-order bug, or any register-contract violation that corrupts BC.
  - **M5**: Single `asm_print_error` helper is now the only place the assembler talks to BDOS; per-site raw BDOS sequences removed. (Full Forth-level routing deferred: would require making error helpers threaded words, out of scope for 4.1.)
  - **L1**: Documented the per-word `check_asm_mode` CALL as an intentional design choice in the file header, noting that eliminating it requires INTERPRET-level dispatch changes that are deferred past Epic 4.
  - **L2**: `AND ~F_SMUDGE` replaced with the explicit byte constant `AND 0xBF` (with a comment showing the derivation) — no longer depends on sjasmplus truncating a 32-bit negative constant.
  - Verification: `make` clean build, `make test` 73/73 pass with unchanged EXPECTED, `make test-repl` 89/89 pass (tests 85-89 unchanged in behaviour, test 87 now stricter), interactive smoke tests confirm the 4 new error messages fire correctly on the `END-CODE`, `CODE<CR>`, `CODE FOO CODE BAR`, and `: FOO CODE ... ;` paths.
