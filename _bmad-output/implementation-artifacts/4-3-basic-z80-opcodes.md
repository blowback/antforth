# Story 4.3: Basic Z80 Opcodes

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want the core Z80 instruction set available in the assembler — 16-bit immediate loads, indirect-via-(HL) loads, jumps, calls, returns (with conditional forms), relative jumps with conditions, and immediate-operand variants of the 8-bit ALU ops,
so that I can write the bulk of useful CODE words (loops, hardware probes, dispatch tables) without dropping back to hand-counting bytes or stubbing in DB,.

## Acceptance Criteria

1. **Given** the user is inside a CODE definition **When** they type `A 0x42 # LD,` **Then** the literal-marker word `#` pushes a sentinel tag (`0xFD00`) on top of the stack without consuming the value below it, leaving stack `[..., A-tag, 0x42, 0xFD00]`; `LD,` then sees TOS = `0xFD00` immediate marker, NOS = `0x42`, NNOS = A register tag, recognises the immediate-load form, consumes all three cells, and emits `LD A, n` = `0x3E 0x42` at HERE (HERE advances by 2). **And** every other 8-bit register (`B`, `C`, `D`, `E`, `H`, `L`) works the same way: `B 0x55 # LD,` emits `0x06 0x55` (LD B, 0x55), encoded as `0x06 | (r<<3)` followed by the byte. **And** the operand order is uniformly Zilog dst-src (destination first, then source), matching the register-to-register form `dst src LD,` — no per-form inconsistency. **And** if the value is > 0xFF, the low byte is truncated silently (consistent with Story 4.2's `DB,` decision and `feedback_assembler_operand_order.md`'s sjasmplus alignment).

2. **Given** the user is inside a CODE definition **When** they type `BC 0x1234 # LD,` **Then** `#` again pushes `0xFD00`, and `LD,` sees TOS = `0xFD00`, NOS = `0x1234`, NNOS = BC register-pair tag (`0x0010`), recognises the 16-bit immediate-load form, and emits `LD BC, nn` = `0x01 0x34 0x12` (3 bytes, opcode `0x01 | (qq<<4)` then little-endian operand). **And** the same works for `DE`, `HL`, and `SP` (`0x01 | (qq<<4)` with qq ∈ {0,1,2,3} respectively → opcodes 0x01, 0x11, 0x21, 0x31). **And** `AF 0x1234 # LD,` is rejected with `bad operand ?` because Z80 has no `LD AF, nn` instruction.

3. **Given** the user is inside a CODE definition **When** they type `A (HL) LD,` **Then** the parsing word `(HL)` pushes the existing 8-bit register tag with the special r-value `0x06`, and `LD,` (Zilog `dst src` order — NOS is destination, TOS is source) sees source TOS = `0x0006`, destination NOS = A register tag (`0x0007`), and emits `LD A, (HL)` = `0x7E` (the standard `0x40 | (dst<<3) | src` encoding with `src = 6`). **And** `(HL) A LD,` with destination `(HL)` and source A emits `LD (HL), A` = `0x77` (`0x40 | (6<<3) | 7`). **And** the general pattern holds for every 8-bit register: `B (HL) LD,` → `LD B, (HL)` = `0x46`, `(HL) B LD,` → `LD (HL), B` = `0x70`, etc. **And** the degenerate `(HL) (HL) LD,` (which would encode as `0x76`, the `HALT` opcode rather than a real LD) is explicitly rejected with `bad operand ?` and ABORTs cleanly. **And** the existing register-only `LD,` paths (`B C LD,` etc.) from Story 4.1 still work unchanged.

4. **Given** the user is inside a CODE definition **When** they type `0x1234 JP,` **Then** `JP,` consumes TOS = `0x1234`, peeks at the new TOS to see whether a condition tag is on the stack (high byte ≠ `0xFE` → no condition), and emits unconditional `JP nn` = `0xC3 0x34 0x12` (3 bytes, little-endian operand). **And** if the operand is a label tag (high byte `0xFF`), `JP,` resolves it: for a *resolved* slot, the slot's address is emitted little-endian; for an *unresolved* slot, two `0x00` placeholders are emitted and a fixup of new kind `ASM_FIXUP_JP` is queued so that the eventual `FIX` patches in the absolute address. **And** the `asm_apply_jp_fixup` helper emits/patches the absolute target address with no displacement arithmetic — it is the absolute analogue of `asm_apply_dw_fixup` from Story 4.2 (in fact it can share the same fixup kind as `DW,` since both are absolute 2-byte writes — see Dev Notes for the share-vs-split decision).

5. **Given** the user is inside a CODE definition **When** they type `NZ 0x1234 JP,` **Then** the parsing word `NZ` pushes the condition tag `0xFE00` (high byte = `0xFE` sentinel, low byte = condition code 0), the literal `0x1234` is then pushed as a plain integer, then `JP,` runs: pop TOS = `0x1234` (target), peek new TOS = `0xFE00` → recognise condition tag, pop it, extract cc=0, emit `JP cc, nn` = `0xC2 0x34 0x12` (`0xC2 | (cc<<3)` then little-endian operand). **And** the same dispatch works for every condition: `Z` (cc=1), `NC` (cc=2), `CS` (cc=3 — replaces the Zilog `C` spelling to avoid collision with the register `C`; see Q2/Task 3 for naming rationale), `PO` (cc=4), `PE` (cc=5), `P` (cc=6), `M` (cc=7). **And** conditional JP also accepts label tags as the target — `NZ` + label tag works exactly like the unconditional case but with the conditional opcode prefix.

6. **Given** the user is inside a CODE definition **When** they type `0x1234 CALL,` **Then** `CALL,` emits unconditional `CALL nn` = `0xCD 0x34 0x12`. **And** `Z 0x1234 CALL,` emits conditional `CALL cc, nn` = `0xCC 0x34 0x12` (`0xC4 | (cc<<3)` with cc=1). **And** label tags as the target work for both conditional and unconditional CALL via the same fixup mechanism as `JP,`. **And** all 8 conditions (`NZ`, `Z`, `NC`, `CS`, `PO`, `PE`, `P`, `M`) are accepted (cc = 0..7).

7. **Given** the user is inside a CODE definition **When** they type `RET,` **Then** `RET,` peeks at TOS: if it is *not* a condition tag (high byte ≠ `0xFE`), emit unconditional `RET` = `0xC9` (1 byte) and **do not** pop TOS — `RET,` consumes nothing. **And** if TOS *is* a condition tag, pop it, extract cc, and emit conditional `RET cc` = `0xC0 | (cc<<3)` (1 byte), valid for all 8 conditions. **And** the user-visible spelling matches the AC sample from epics.md: `Z RET,` → `RET Z` = `0xC8`, `NZ RET,` → `RET NZ` = `0xC0`, `M RET,` → `RET M` = `0xF8`. **And** the case where the user accidentally has an unrelated value on TOS that happens to look like a condition tag is documented (anti-pattern: condition tags have a unique high-byte sentinel `0xFE` that no plausible address ever reaches — same rationale as label tags, see Dev Notes).

8. **Given** the user is inside a CODE definition **When** they type `NZ TOP JR,` (where `TOP` is a label declared via `LABEL TOP`) **Then** `JR,` pops TOS = label tag, peeks new TOS = condition tag `0xFE00` (NZ), pops it, and emits conditional `JR cc, e` = `0x20 | (cc<<3)` followed by the signed displacement byte (`0x20` for NZ, `0x28` for Z, `0x30` for NC, `0x38` for CS). The displacement computation, range check, and forward-fixup queueing are identical to Story 4.2's `JR,` — the only change is the opcode byte prefix. **And** conditional JR is **only** valid for the 4 single-flag conditions `NZ`, `Z`, `NC`, and `CS` (cc=0..3). Trying `PO TOP JR,`, `M TOP JR,`, etc. errors with `bad operand ?` because the Z80 has no JR forms for those parity/sign conditions. **And** the unconditional `JR,` form (no condition prefix) from Story 4.2 still works unchanged — adding the conditional path must not break any of the Story 4.2 JR tests.

9. **Given** the user is inside a CODE definition **When** they type `0x0F # AND,` **Then** `#` pushes `0xFD00`, then `AND,` sees TOS = `0xFD00` immediate marker, NOS = `0x0F`, recognises the immediate form, pops both cells, and emits `AND n` = `0xE6 0x0F` (2 bytes). **And** the same dispatch works for every Story 4.1 arith op: `ADD,` → `ADD A, n` = `0xC6 nn`, `SUB,` → `SUB n` = `0xD6 nn`, `XOR,` → `XOR n` = `0xEE nn`, `OR,` → `OR n` = `0xF6 nn`, `CP,` → `CP n` = `0xFE nn`. **And** the existing register-operand paths (`B ADD,` etc.) from Story 4.1 still work unchanged — the dispatch is "if TOS is `0xFD00`, immediate path; else assume register tag and run the existing path."

10. **Given** any of the new error paths fire — `LD AF, nn` rejection, `(HL) (HL) LD,` rejection, conditional JR with non-JR condition (PO/PE/P/M), unresolved JP/CALL fixup at END-CODE, immediate marker with no value below it (stack underflow on # itself or on the consuming opcode), conditional opcode word seeing a corrupted condition tag, label-tag JP/CALL with a slot index out of range — **When** the offending word runs **Then** it prints a descriptive `subject ?` message via `asm_print_error` (or `asm_print_error_with_name` for label-name errors), jumps through `asm_die`, ABORTs, and `asm_cleanup` rolls back the in-progress CODE word (unlinking labels, restoring HERE, resetting `asm_label_count` / `asm_fixup_count` / `asm_label_dict_ptr`, clearing `asm_mode`). The user is left at a clean `ok` prompt with no orphan dictionary entry, no leaked label words, and no stale immediate-marker state. **Critical:** the `#` immediate-marker has no persistent state — it lives entirely on the data stack — so there is no flag to clear on cleanup. This is the primary reason the design uses an on-stack tag rather than a global `asm_imm_pending` byte (see Dev Notes).

11. **Given** the user writes the canonical end-to-end example from epics.md (an LED-poke style CODE word using stack juggling, immediate loads, indirect-(HL) loads, register-to-register loads, and an `OUT (C), A` style sequence — but `OUT,` itself is Story 4.4, so substitute a register-load sequence for this story) **Or simpler**: the user writes
    ```
    CODE PEEKBYTE      ( addr -- byte )
      L C LD,          \ save addr lo
      H B LD,          \ save addr hi  (BC now = addr — was TOS)
      \ Now BC=TOS already held the addr, that was redundant; rewrite:
      \ Actually: pop to HL, fetch via (HL).
      C L LD,
      B H LD,
      (HL) C LD,       \ C = byte at addr  (BC = byte in low byte)
      B 0 # LD,        \ zero high byte
      NEXT,
    END-CODE
    ```
    **When** `0x1234 PEEKBYTE .` is executed (assuming address 0x1234 holds a known byte) **Then** the byte at 0x1234 is left on the data stack and printed. **And** the new immediate-load (`B 0 # LD,`), indirect-(HL) load (`(HL) C LD,`), and register-to-register loads from Story 4.1 all coexist correctly within the same CODE word.

12. **Given** the user writes a CODE word using a forward conditional JR with a label (the most common pattern for "skip if not zero" loops):
    ```
    CODE NZSKIP        ( -- )
      LABEL DONE
      A A OR,          \ test A (A OR A sets/clears Z flag without changing A)
      Z DONE JR,       \ if Z, skip ahead
      B 0xAA # LD,
      DONE FIX
      NEXT,
    END-CODE
    ```
    Wait — `OR,` from Story 4.1 takes a register operand, not zero operands. The actual idiom is `A OR,` (OR A), which sets the Z flag from A. **When** `END-CODE` runs **Then** the body assembles cleanly, the forward `Z DONE JR,` is patched correctly when `DONE FIX` runs, and the resulting bytes verify against the expected encoding when read back via `' NZSKIP <offset> + C@`.

13. **Given** the user writes a CODE word that uses both conditional CALL and a labelled JP target:
    ```
    CODE COND
      LABEL HANDLER
      NZ HANDLER CALL,      \ conditional call to local handler
      RET,
      HANDLER FIX
      A 0xFF # LD,
      NEXT,
    END-CODE
    ```
    **When** `END-CODE` runs **Then** the body assembles cleanly: `NZ HANDLER CALL,` emits `0xC4 + 2-byte placeholder + fixup queued`; `RET,` emits `0xC9`; `HANDLER FIX` patches the 2-byte placeholder with the correct absolute address; `A 0xFF # LD,` emits `0x3E 0xFF`; `NEXT,` emits the inner-interpreter return. **And** every byte verifies via `' COND <offset> + C@` REPL inspection.

14. **Given** the existing 73 regression tests (`make test`) **And** the existing 106 REPL tests (`make test-repl` after Story 4.2's tests 90-106) **When** both test targets run after this story's changes **Then** every pre-existing test still passes with identical output **And** the EXPECTED string for `make test` is unchanged. **Critical:** Story 4.3 makes no changes to `outer_interpreter.asm` and no changes to `system.asm` (the existing `w_ABORT_cf` → `asm_cleanup` chain from Story 4.1 covers all new error paths). The diff is confined to `src/assembler.asm` (mostly additions, minimal edits to `assert_8bit_reg`/`asm_arith_word`/`w_LD_COMMA_cf`/`w_JR_COMMA_cf` for the new dispatch branches) and `Makefile` (REPL tests 107+).

15. **Given** the new REPL tests added for this story **When** `make test-repl` runs **Then** each of the following is verified end-to-end through the actual Forth REPL by reading the assembled body bytes via `' word` + `C@` (or `@` for the 2-byte address operands of JP/CALL):
    - **Test 107 — `LD r, n` (8-bit immediate)**: `CODE I8 B 0x55 # LD, C 0x66 # LD, A 0x77 # LD, NEXT, END-CODE` (Zilog dst-src: destination first, value next, `#` marks it as immediate); assert offset 0 = `0x06`, offset 1 = `0x55`, offset 2 = `0x0E`, offset 3 = `0x66`, offset 4 = `0x3E`, offset 5 = `0x77`.
    - **Test 108 — `LD rr, nn` (16-bit immediate)**: `CODE I16 BC 0x1234 # LD, DE 0x5678 # LD, HL 0xABCD # LD, SP 0xFFFE # LD, NEXT, END-CODE`; assert the body bytes form `0x01 0x34 0x12 0x11 0x78 0x56 0x21 0xCD 0xAB 0x31 0xFE 0xFF`.
    - **Test 109 — `LD rr, nn` rejects AF**: `CODE BADAF AF 0x1234 # LD, NEXT, END-CODE` produces `bad operand ?`, clean recovery, no `BADAF` in `WORDS`.
    - **Test 110 — `LD r, (HL)`**: `CODE LDHL A (HL) LD, B (HL) LD, C (HL) LD, NEXT, END-CODE` (Zilog `dst src` order: NOS is destination, TOS is source); assert offset 0 = `0x7E` (LD A,(HL)), offset 1 = `0x46` (LD B,(HL)), offset 2 = `0x4E` (LD C,(HL)).
    - **Test 111 — `LD (HL), r`**: `CODE STHL (HL) A LD, (HL) B LD, (HL) C LD, NEXT, END-CODE`; assert offset 0 = `0x77`, offset 1 = `0x70`, offset 2 = `0x71`.
    - **Test 112 — `(HL) (HL) LD,` rejected**: `CODE BADHH (HL) (HL) LD, NEXT, END-CODE` produces `bad operand ?`, clean recovery, no `BADHH` in `WORDS`.
    - **Test 113 — Story 4.1 register-to-register LD, regression**: `CODE RR B C LD, NEXT, END-CODE`; assert offset 0 = `0x41` (LD B,C — Zilog `dst src` order per `feedback_assembler_operand_order.md`). Belt-and-braces against the LD dispatch refactor breaking the register path.
    - **Test 114 — Unconditional `JP, nn`**: `CODE JP1 0x1234 JP, END-CODE` (no NEXT, since JP transfers control); assert offset 0 = `0xC3`, offset 1 = `0x34`, offset 2 = `0x12`.
    - **Test 115 — Conditional `JP cc, nn`**: `CODE JP2 NZ 0x1234 JP, Z 0x5678 JP, NC 0x9ABC JP, CS 0xDEF0 JP, END-CODE`; assert the body bytes form `0xC2 0x34 0x12 0xCA 0x78 0x56 0xD2 0xBC 0x9A 0xDA 0xF0 0xDE`.
    - **Test 116 — `JP,` with label tag (resolved + unresolved paths)**: Define `CODE JL LABEL TGT TGT JP, TGT FIX NEXT, END-CODE`; the `TGT JP,` runs while `TGT` is unresolved, emits `0xC3` + 2 placeholder bytes + queues a JP-absolute fixup; `TGT FIX` patches the placeholders to the body offset 3 (the address right after the 3-byte JP). Assert `' JL @ ' JL 3 + =` is true (body starts with the JP target address pointing at body+3, but wait — `' JL @` reads bytes 0-1 as a 16-bit value, that's `0xC3` followed by the lo byte of the target. Adjust: read the address from offsets 1-2 via two `C@` calls and combine, OR use `' JL 1 + @` which reads the 16-bit at offset 1 directly. The latter is simpler.) Final assertion: `' JL 1 + @ ' JL 3 + = .` prints `-1` (true).
    - **Test 117 — Unconditional `CALL, nn`**: `CODE C1 0x1234 CALL, END-CODE`; assert bytes `0xCD 0x34 0x12`.
    - **Test 118 — Conditional `CALL cc, nn` (all 8 conditions)**: `CODE C2 NZ 0x1111 CALL, Z 0x2222 CALL, NC 0x3333 CALL, CS 0x4444 CALL, PO 0x5555 CALL, PE 0x6666 CALL, P 0x7777 CALL, M 0x8888 CALL, END-CODE`; assert the 8 opcodes are `0xC4 0xCC 0xD4 0xDC 0xE4 0xEC 0xF4 0xFC` at offsets 0, 3, 6, 9, 12, 15, 18, 21 respectively.
    - **Test 119 — Unconditional `RET,`**: `CODE R1 RET, END-CODE`; assert offset 0 = `0xC9`. Stack-state hygiene: `.S` after definition prints `<0> ` (no spurious push by RET,).
    - **Test 120 — Conditional `RET cc` (all 8)**: `CODE R2 NZ RET, Z RET, NC RET, CS RET, PO RET, PE RET, P RET, M RET, NEXT, END-CODE`; assert offsets 0..7 = `0xC0 0xC8 0xD0 0xD8 0xE0 0xE8 0xF0 0xF8`.
    - **Test 121 — Conditional `JR cc, e`**: `CODE JR1 LABEL TOP TOP FIX A A OR, NZ TOP JR, NEXT, END-CODE`; assert offset 0 = `0xB7` (OR A, from Story 4.1), offset 1 = `0x20` (JR NZ), offset 2 = `0xFD` (-3 displacement = `0 - (1+2) = -3` from the byte after the JR opcode at offset 1 → patch_addr is at offset 2, target is offset 0, disp = `0 - (2+1) = -3`). **Note**: re-derive the displacement carefully against the existing `asm_jr_disp` formula in `assembler.asm`.
    - **Test 122 — Conditional JR rejects PO**: `CODE BADJR LABEL T T FIX PO T JR, NEXT, END-CODE` produces `bad operand ?`, clean recovery, no `BADJR` or `T` in `WORDS`.
    - **Test 123 — `AND n` immediate (and one of every other arith)**: `CODE AI 0x0F # AND, 0xF0 # OR, 0xAA # XOR, 0x10 # ADD, 0x20 # SUB, 0x30 # CP, NEXT, END-CODE`; assert body bytes `0xE6 0x0F 0xF6 0xF0 0xEE 0xAA 0xC6 0x10 0xD6 0x20 0xFE 0x30`.
    - **Test 124 — Story 4.1 arith register-form regression**: `CODE AR B AND, NEXT, END-CODE`; assert offset 0 = `0xA0` (AND B). Confirms the immediate dispatch refactor didn't break the register path.
    - **Test 125 — Unresolved JP fixup at END-CODE**: `CODE BADJP LABEL X X JP, NEXT, END-CODE` produces `unresolved label X ?`, clean recovery, no `BADJP` or `X` in `WORDS`.
    - **Test 126 — Unresolved CALL fixup at END-CODE**: `CODE BADCALL LABEL Y Y CALL, NEXT, END-CODE` produces `unresolved label Y ?`, clean recovery, no `BADCALL` or `Y` in `WORDS`.
    - **Test 127 — `#` outside CODE rejected**: `0x42 #` at the prompt produces `not in CODE ?` and clean recovery.
    - **Test 128 — `(HL)` outside CODE rejected**: `(HL)` at the prompt produces `not in CODE ?` and clean recovery.
    - **Test 129 — Conditions outside CODE rejected**: `NZ Z NC CS PO PE P M` at the prompt — each produces `not in CODE ?` and clean recovery (verify count of `?` errors ≥ 8 — all 8 conditions). **Also**: in BASE=16, type bare `CC` at the prompt and assert it parses cleanly as the integer 204 (no `?` error, `.` prints `204` in decimal or `CC` in hex). This confirms `CC` is **not** shadowed by any dictionary word — the carry-clear condition is spelled `NC`, not `CC`, precisely so this hex literal remains usable.
    - **Test 130 — Story 4.2 JR regression**: re-run `CODE BL1 LABEL TOP TOP FIX A A LD, TOP JR, NEXT, END-CODE  ' BL1 2 + C@ .` and assert `253 ` (the AC4 / Test 90 backward-JR encoding). Belt-and-braces against the conditional-JR dispatch refactor regressing the unconditional path.
    - **Test 131 — Story 4.1 banner / cold start regression spot-check**: simply boot the REPL, type `1 2 + .`, and assert `3 ` is printed. (Catches catastrophic regressions where the new opcode words push something into the wrong dictionary slot or corrupt the cold-start path.)

## Tasks / Subtasks

- [x] Task 1: Define new tag sentinels and add the immediate-marker word `#` (AC: #1, #2, #9, #10)
  - [x] 1.1 In the constants block at the top of `assembler.asm` (just after `ASM_LABEL_TAG_HI EQU 0xFF` at line 106), add:
    ```
    ASM_IMM_TAG_HI       EQU 0xFD     ; immediate-marker tag, low byte irrelevant (use 0x00)
    ASM_COND_TAG_HI      EQU 0xFE     ; condition-code tag, low byte = cc (0..7)
    ```
    Document the tag-encoding scheme in the existing label-tag block comment so all three sentinels (`0xFD`, `0xFE`, `0xFF`) are described in one place. Cross-reference Story 4.2's "Caveat to verify" — the same logic that ruled out `0x80` (because BDOS sits ~0xE400) confirms that `0xFD..0xFF` are all safe sentinel ranges.
  - [x] 1.2 Add the new fixup kind constant for absolute JP/CALL targets:
    ```
    ASM_FIXUP_KIND_JP    EQU 2        ; absolute 2-byte address, same emit as DW
    ```
    **Decision Q1 (see Open Questions below)**: do we share `ASM_FIXUP_KIND_DW` for both `DW,` and `JP,`/`CALL,` patches, or split them? Default: **share** — the patch operation is byte-for-byte identical (write target lo at patch_addr, target hi at patch_addr+1). The only reason to split would be if the error message wanted to distinguish "unresolved label X (used by JP)" from "unresolved label X (used by DW)" — Story 4.2's error message just says `unresolved label X ?` without naming the operation, so sharing is fine. **If sharing, do NOT add `ASM_FIXUP_KIND_JP` at all** — `JP,`/`CALL,` use the existing `ASM_FIXUP_KIND_DW`. Update Task 2 accordingly.
  - [x] 1.3 Define `w_HASH` — a DEFCODE word with the name `#`. Gated by `check_asm_mode` (errors `not in CODE ?` outside CODE). Behaviour: pushes the literal-marker tag on top of the data stack without consuming the value below it. Implementation:
    ```
    w_HASH:
            DEFCODE "#", 0
    w_HASH_cf:
            CALL    check_asm_mode
            PUSH    BC                      ; old TOS becomes NOS
            LD      C, 0                    ; low byte irrelevant
            LD      B, ASM_IMM_TAG_HI       ; B = 0xFD → BC = 0xFD00
            NEXT
    ```
    Mirrors `asm_push_tag` exactly except the high byte is `ASM_IMM_TAG_HI` instead of 0. Note: this means after `0x42 #` runs, the data stack reads `[..., 0x42, 0xFD00]` with TOS = `0xFD00`.
  - [x] 1.4 Add a small helper `asm_is_imm_tag` (entry: BC = TOS-style cell; exit: Z flag set if it is the immediate-marker tag, A clobbered) — used by every opcode word that supports an immediate variant. Implementation is one byte test:
    ```
    asm_is_imm_tag:
            LD      A, B
            CP      ASM_IMM_TAG_HI
            RET
    ```
    Use it via `CALL asm_is_imm_tag / JR Z, .imm_path`. This keeps the test in one place — if the encoding ever changes, only one constant moves.

- [x] Task 2: Add the indirect-(HL) parsing word and relax the LD assertion (AC: #3, #10)
  - [x] 2.1 Define `w_REG_IHL` — a DEFCODE word with the name `(HL)`. Gated by `check_asm_mode`. Pushes tag value `0x06` (the existing 8-bit r-field value for memory-via-HL):
    ```
    w_REG_IHL:
            DEFCODE "(HL)", 0
    w_REG_IHL_cf:
            LD      L, 0x06
            JP      asm_push_tag
    ```
    This reuses `asm_push_tag` from Story 4.1 (line 763), so no new helper is needed. The high byte is 0, just like every other 8-bit register tag.
  - [x] 2.2 The current `assert_8bit_reg` (line 1046) has a hard-coded `CP 6 / JP Z, asm_bad_operand` — that line was added in Story 4.1 with the comment "(HL) not exposed in 4.1". This story exposes it, but only for `LD,`. Solution: create a second permissive variant `assert_8bit_reg_or_ihl` that performs the same checks **without** the `CP 6 / JP Z` rejection. Use the new variant inside `w_LD_COMMA_cf`'s register-tag path; leave the existing `assert_8bit_reg` (and `asm_get_r8`) untouched so the arith ops continue to reject `(HL)` (which would be `ADD A, (HL)` etc. — Z80-valid but Story 4.4 territory).
    ```
    assert_8bit_reg_or_ihl:
            LD      A, H
            OR      A
            JP      NZ, asm_bad_operand
            LD      A, L
            CP      8
            JP      NC, asm_bad_operand     ; >= 8 → 16-bit tag or garbage
            RET                              ; allow 0..7 including 6 = (HL)
    ```
    Add this immediately after `assert_8bit_reg` (line 1055) so the two variants live side by side and the difference is obvious.
  - [x] 2.3 In `w_LD_COMMA_cf` (line 1063), after the new immediate-form dispatch (Task 4) and the new 16-bit immediate dispatch (Task 5), the register-to-register fall-through path uses `assert_8bit_reg_or_ihl` for **both** the source and destination tags. After both register r-fields are computed, add a final guard: if both r-values equal 6, `JP asm_bad_operand` (rejects `LD (HL), (HL)` = 0x76 HALT). The guard goes immediately before the `OR 0x40` opcode-assembly step.

- [x] Task 3: Add the condition-code parsing words (AC: #5, #6, #7, #8, #10)
  - [x] 3.1 Add a new shared tail helper `asm_push_cond_tag` (mirrors `asm_push_tag` and `asm_push_label_tag`):
    ```
    asm_push_cond_tag:
            CALL    check_asm_mode
            PUSH    BC                      ; save old TOS
            LD      C, L                    ; C = cc (0..7)
            LD      B, ASM_COND_TAG_HI      ; B = 0xFE
            NEXT
    ```
    Place it just after `asm_push_label_tag` (line 1206).
  - [x] 3.2 Define 8 condition-code DEFCODE words, each one a 2-line stub that loads its cc into L and jumps to the shared tail. **Naming departs from the Z80 manual at one position to avoid the `C` register/condition collision** — see Q2 resolution below. The carry-set spelling is borrowed from 6502 assembly (`CS` = "carry set"):
    ```
    w_COND_NZ:  DEFCODE "NZ", 0       (cc = 0)
    w_COND_Z:   DEFCODE "Z", 0        (cc = 1)
    w_COND_NC:  DEFCODE "NC", 0       (cc = 2)
    w_COND_CS:  DEFCODE "CS", 0       (cc = 3 — replaces Zilog "C", "carry set")
    w_COND_PO:  DEFCODE "PO", 0       (cc = 4)
    w_COND_PE:  DEFCODE "PE", 0       (cc = 5)
    w_COND_P:   DEFCODE "P", 0        (cc = 6)
    w_COND_M:   DEFCODE "M", 0        (cc = 7)
    ```
    Each body is two lines — `LD L, <cc>` then `JP asm_push_cond_tag`. Place this block immediately after the existing register-tag block (after `w_REG_SP_cf` at line 844). The cc encoding matches the Z80 manual (used directly in the `0xC0 | (cc<<3)` family of opcodes — RET cc, JP cc, CALL cc, JR cc); only the *spelling* of cc=3 changes from `C` to `CS`. **Do NOT add `CC` as an alias for `NC`** — `CC` is a valid hex literal in BASE=16 (= 204) and shadowing it with a dict word silently breaks any code that expected the literal. The 6502 borrow is asymmetric here: we take `CS` because it has no hex collision; `NC` keeps its Z80 spelling. See Q2 resolution and Q8 (number-shadow audit) below.
  - [x] 3.3 Add a small helper `asm_is_cond_tag` (mirror of `asm_is_imm_tag`):
    ```
    asm_is_cond_tag:
            LD      A, B
            CP      ASM_COND_TAG_HI
            RET
    ```
    Usage: `CALL asm_is_cond_tag / JR Z, .cond_path`. **Q2 resolution — collision-free naming via partial 6502 borrow**: the project lead has chosen to rename the carry-set condition `C` (cc=3) to `CS` (carry set, borrowed from 6502). The carry-clear condition keeps its Zilog spelling `NC` (the 6502 spelling `CC` was rejected on second look — see Q8 — because `CC` parses as integer `0xCC` in BASE=16 and shadowing it with a dictionary word silently breaks numeric literals). The result: the register `C` (tag `0x0001`) is preserved unmodified — every existing Story 4.1 test using `C` as a register (`B C LD,`, etc.) continues to work — and only one Zilog spelling changes (`C` → `CS`). The assembler reference doc should call out the single departure explicitly. See Q2 and Q8 in Open Questions for the rationale.

- [x] Task 4: Extend `LD,` with immediate variants (AC: #1, #2, #10)
  - [x] 4.1 In `w_LD_COMMA_cf` (line 1063), the very first action after `check_asm_mode` is now to call `asm_is_imm_tag` on TOS. If it is the immediate marker (the source operand is `... value # destreg LD,` meaning the TOS is the destination register, NOS is the marker, NNOS is the value)... wait — that's wrong. Let me re-check.
  - [x] 4.2 Re-deriving the stack discipline for `0x42 # A LD,`:
    - After `0x42`: stack = `[..., 0x42]`, TOS = `0x42`.
    - After `#`: stack = `[..., 0x42, 0xFD00]`, TOS = `0xFD00` (immediate marker pushed on top).
    - After `A`: stack = `[..., 0x42, 0xFD00, 0x0007]`, TOS = `0x0007` (A register tag).
    - `LD,` runs: TOS = A reg, NOS = `0xFD00` marker, NNOS = `0x42` value.
    - `LD,` must check NOS (the cell *below* TOS) for the immediate marker. TOS itself is the destination register tag.
  - [x] 4.3 Implementation: at the top of `w_LD_COMMA_cf` (after `check_asm_mode`), peek NOS by reading the top of the data stack memory (since SP points just past TOS-in-register BC, the top memory cell IS the second cell). Use `LD HL, (SP+0)` style — actually Z80 lacks SP-indexed addressing for HL, so use `POP HL / PUSH HL` to peek without permanent damage, OR use the easier pattern: `POP HL` (HL = NOS), then check `H` against `ASM_IMM_TAG_HI`. If yes → immediate path (don't push HL back; HL holds the discarded marker). If no → `PUSH HL` (restore the stack) and continue with the existing register-to-register path.
  - [x] 4.4 The immediate path (after popping the `0xFD00` marker into HL): TOS (BC) is the destination register tag. Check whether it is an 8-bit register (`H==0, L<8`) or a 16-bit register pair (`H==0, L>=0x10`). Branch:
    - **8-bit destination** (`L < 8`): for `(HL)` (`L == 6`), reject with `bad operand ?` (Z80 has `LD (HL), n` = 0x36 nn — actually that *is* valid, see Q3). Default: **reject** for now and add `LD (HL), n` in Story 4.4 if needed. For real registers (`L != 6`): pop the value (POP HL → L = value lo, H = value hi; we only use L because LD r, n is byte-immediate). Emit opcode `0x06 | (r<<3)` then the value byte. Pop new TOS. NEXT.
    - **16-bit destination** (`L >= 0x10`): translate tag `0x10/0x11/0x12/0x13/0x14` → qq `0/1/2/3` for BC/DE/HL/SP. Reject `AF` (tag `0x13`) with `bad operand ?` because Z80 has no `LD AF, nn`. Pop the value (POP HL → HL = the 16-bit value). Emit opcode `0x01 | (qq<<4)` then HL low then HL high. Pop new TOS. NEXT.
  - [x] 4.5 The non-immediate fall-through (NOS was not the marker, HL was pushed back) continues with the existing register-to-register code (line 1065 onward), with one change: replace `assert_8bit_reg` with `assert_8bit_reg_or_ihl` for both src and dst, and add the `(HL),(HL)` reject from Task 2.3.
  - [x] 4.6 **Critical**: the existing `w_LD_COMMA_cf` does not save DE/IP. The new immediate-path POPs and reads memory but does not call any helper that clobbers DE. Verify the existing path still preserves DE and add the save-DE-to-RS prologue **only** if the verification fails. The `asm_emit_byte` helper preserves DE (per its existing contract — assembler.asm:187 comment), so straight-line emit sequences are safe without an explicit save.
  - [x] 4.7 Edge case: what if TOS is `0xFD00` (the user typed `# LD,` with no value or no destination)? Then NOS-pop reads garbage from below the value the user intended. Defence: after popping the marker, check that the new TOS (the value) and the dst tag both exist — but Forth has no built-in stack-depth check inside word execution. The standard Forth answer is "stack underflow is the user's responsibility" and we let it crash. Story 4.2 made the same decision for `FIX` with empty stack. **Match Story 4.2's behaviour**: no defensive depth check, document the limitation in Dev Notes.

- [x] Task 5: Extend the arith ops with immediate variants (AC: #9, #10)
  - [x] 5.1 In `asm_arith_word` (line 1102), the entry sequence is currently:
    ```
    asm_arith_word:
            LD      (asm_tmp), A            ; spill base opcode
            CALL    check_asm_mode
            CALL    asm_get_r8              ; A = r-field
            ...
    ```
    Add an immediate-tag check **before** `asm_get_r8`. If TOS is the immediate marker, branch to a new immediate path. The immediate path uses different base opcodes than the register path:
    - Register form base: `0x80 + 0x10*op_idx` (ADD=0x80, SUB=0x90, AND=0xA0, XOR=0xA8, OR=0xB0, CP=0xB8) — these are passed in via the per-word entry stub (`w_ADD_COMMA_cf` etc.)
    - Immediate form base: `0xC6 + 0x08*op_idx_alt` — wait, that's not a clean transformation. Z80 immediate ALU opcodes:
      - ADD A, n = 0xC6
      - ADC A, n = 0xCE  (Story 4.4)
      - SUB n     = 0xD6
      - SBC A, n  = 0xDE  (Story 4.4)
      - AND n     = 0xE6
      - XOR n     = 0xEE
      - OR  n     = 0xF6
      - CP  n     = 0xFE
    - The pattern is: register form `0x80 + (alu<<3)` where alu = 0..7 for ADD/ADC/SUB/SBC/AND/XOR/OR/CP. Immediate form is the same `(alu<<3)` field, but the high bits change to `0xC6` (i.e., `0xC6 | (alu<<3)`). So the transformation from reg base to imm base is: `imm_base = 0xC6 | (reg_base & 0x38)` where `0x38` extracts the alu field. Verify with examples: ADD reg base 0x80, alu = (0x80>>3)&7 = 0, imm base = 0xC6|0 = 0xC6 ✓. AND reg base 0xA0, alu = 4, imm base = 0xC6|0x20 = 0xE6 ✓. CP reg base 0xB8, alu = 7, imm base = 0xC6|0x38 = 0xFE ✓. Pattern holds.
  - [x] 5.2 Implementation sketch for the new shared tail:
    ```
    asm_arith_word:
            LD      (asm_tmp), A            ; spill register-form base opcode
            CALL    check_asm_mode
            CALL    asm_is_imm_tag
            JR      Z, .arith_imm
            ; --- existing register path ---
            CALL    asm_get_r8
            LD      HL, asm_tmp
            OR      (HL)
            CALL    asm_emit_byte
            POP     BC
            NEXT
    .arith_imm:
            ; TOS = 0xFD00 marker; pop it and read NOS = value.
            POP     BC                      ; new TOS = value (the n)
            ; Compute imm_base = 0xC6 | (reg_base & 0x38)
            LD      A, (asm_tmp)
            AND     0x38                    ; isolate alu field
            OR      0xC6
            CALL    asm_emit_byte
            ; Emit the n byte (low byte of value).
            LD      A, C
            CALL    asm_emit_byte
            POP     BC                      ; new TOS
            NEXT
    ```
    Verify: `0x0F # AND,` — value = 0x0F, AND reg base = 0xA0, imm base = 0xC6|0x20 = 0xE6, emits 0xE6 0x0F ✓.
  - [x] 5.3 Edge case: what if the value is > 0xFF? Same as `DB,` from Story 4.2: silent low-byte truncation, document in Dev Notes. (Q4 — open question. Default: silent truncation.)

- [x] Task 6: Implement `JP,` with conditional and label-tag dispatch (AC: #4, #5, #10)
  - [x] 6.1 Define `w_JP_COMMA` (DEFCODE name `JP,`). Gated by `check_asm_mode`. Spill DE/IP to `asm_ip_save` (per Story 4.2 retrospective lesson #3 — JR,/FIX/DW, didn't preserve DE; the same pitfall applies here).
  - [x] 6.2 Pop TOS into a working register (HL): the target operand. It is one of:
    - **Label tag** (high byte = `ASM_LABEL_TAG_HI` = 0xFF): label-driven JP. Save the slot index in a scratch byte.
    - **Plain 16-bit address**: literal target. Save the 16-bit value in a 2-byte scratch.
  - [x] 6.3 Peek the new TOS (which is now the cell that *was* NOS — the cell below the target). Check whether it is a condition tag (high byte = `ASM_COND_TAG_HI` = 0xFE):
    - **Yes — conditional JP**: pop the condition tag, extract cc from the low byte (range-check 0..7 — it should always be valid because the condition words always push 0..7, but defence in depth catches forged tags). Compute the opcode `0xC2 | (cc<<3)`. Emit it.
    - **No — unconditional JP**: do NOT pop. Emit opcode `0xC3`.
  - [x] 6.4 Now emit the 2-byte target operand:
    - **Literal target**: emit lo byte then hi byte via two `asm_emit_byte` calls.
    - **Label tag, resolved**: look up the slot, read its target address, emit lo then hi.
    - **Label tag, unresolved**: save patch_addr = HERE (= the address where the lo byte will go), emit `0x00 0x00` placeholders, then queue a fixup via `asm_add_fixup` with kind `ASM_FIXUP_KIND_DW` (per Task 1.2 default — sharing with DW). The existing `asm_apply_dw_fixup` will patch absolutely correctly because `JP nn` and `DW <addr>` write the same 2-byte little-endian absolute value.
  - [x] 6.5 After all emits, restore DE from `asm_ip_save`, pop new TOS (the cell below the original NOS, OR the cell below the original TOS-target if there was no condition — the condition-pop step affects how many cells were consumed). Be precise about the stack discipline:
    - **Unconditional, literal**: consumed 1 cell (target). Pop new TOS once.
    - **Unconditional, label**: consumed 1 cell. Pop once.
    - **Conditional, literal**: consumed 2 cells (target + condition). Pop new TOS twice.
    - **Conditional, label**: consumed 2 cells. Pop twice.
    The cleanest implementation is to count in a single byte at routine entry and pop the right number of times at exit.
  - [x] 6.6 **Critical structural choice**: rather than write `w_JP_COMMA_cf` and `w_CALL_COMMA_cf` as duplicated 100-line bodies, factor the common logic into a shared tail `asm_jp_call_word` that takes the unconditional opcode in A (0xC3 for JP, 0xCD for CALL) and computes the conditional form internally. Both `w_JP_COMMA_cf` and `w_CALL_COMMA_cf` become 2-line stubs that load A and tail-jump to the helper. This mirrors the `asm_arith_word` / `asm_pushpop_word` patterns from Story 4.1.

- [x] Task 7: Implement `CALL,` (AC: #6, #10)
  - [x] 7.1 Define `w_CALL_COMMA` (DEFCODE name `CALL,`). Two-line body that loads `A = 0xCD` and `JP asm_jp_call_word` (the helper from Task 6.6).
  - [x] 7.2 Inside the helper, the conditional opcode for CALL is `0xC4 | (cc<<3)`. The helper distinguishes JP vs CALL via the entry value of A (0xC3 → JP family, 0xCD → CALL family). Store A in a 1-byte scratch at entry; at the conditional branch, the conditional opcode is computed as: if `A == 0xC3` then `0xC2 | (cc<<3)`; if `A == 0xCD` then `0xC4 | (cc<<3)`. Or more cleanly: the unconditional opcode determines the conditional family by a fixed offset — `JP: 0xC3 - 1 = 0xC2`, `CALL: 0xCD - 1 = ??` — wait, `0xCD - 1 = 0xCC` which is `CALL Z`, not the cc=0 form. So the offset trick doesn't work cleanly. Better: branch on `A == 0xC3` once at the top of the helper and store the appropriate conditional base in the scratch.
  - [x] 7.3 All other behaviour (label-tag dispatch, fixup queueing, stack consumption) is identical to JP. The helper covers both.

- [x] Task 8: Implement `RET,` with optional condition (AC: #7, #10)
  - [x] 8.1 Define `w_RET_COMMA` (DEFCODE name `RET,`). Gated by `check_asm_mode`. Spill DE/IP to `asm_ip_save` (defence — `asm_emit_byte` preserves DE but the pop-and-test sequence is safer with a save).
  - [x] 8.2 Peek TOS (BC): is it a condition tag (high byte = `ASM_COND_TAG_HI`)?
    - **Yes**: pop TOS, extract cc from C, range-check 0..7, emit `0xC0 | (cc<<3)`, pop new TOS, restore DE, NEXT.
    - **No**: emit `0xC9` (unconditional RET), do **not** pop TOS, restore DE, NEXT.
  - [x] 8.3 The "do not pop TOS in the unconditional case" is the key behavioural difference from every other opcode word. Document this in the Dev Notes and add a stack-state hygiene assertion to Test 119 (`.S` after `CODE R1 RET, END-CODE` should show the same depth as before the definition).

- [x] Task 9: Extend `JR,` with conditional dispatch (AC: #8, #10)
  - [x] 9.1 In `w_JR_COMMA_cf` (line 1395), the current first action after `check_asm_mode` is `LD (asm_ip_save), DE` followed by emitting the JR opcode `0x18`. Insert a conditional-check pass *before* the opcode emit:
    ```
    w_JR_COMMA_cf:
            CALL    check_asm_mode
            LD      (asm_ip_save), DE
            ; TOS = target (label tag or literal). Peek NOS for condition.
            POP     HL                      ; HL = NOS (was previous TOS pre-target)
            LD      A, H
            CP      ASM_COND_TAG_HI
            JR      Z, .jrc_cond
            ; No condition; restore NOS and run the existing unconditional path.
            PUSH    HL
            LD      A, 0x18                 ; unconditional JR opcode
            JR      .jrc_emit_op
    .jrc_cond:
            ; HL = condition tag; extract cc, validate range 0..3 (JR has
            ; only NZ/Z/NC/C — reject PO/PE/P/M).
            LD      A, L
            CP      4
            JP      NC, asm_bad_operand
            ; Conditional JR opcode = 0x20 | (cc<<3)
            ADD     A, A                    ; cc << 1
            ADD     A, A                    ; cc << 2
            ADD     A, A                    ; cc << 3
            OR      0x20
            ; A = conditional opcode, BC = target (unchanged), HL = popped condition (discarded).
    .jrc_emit_op:
            CALL    asm_emit_byte
            ; ... continue with the existing displacement emit / fixup logic.
    ```
    The rest of `w_JR_COMMA_cf` (lines 1402-1451) runs unchanged: the displacement / fixup machinery doesn't care which JR variant was emitted — it patches the byte after the opcode regardless.
  - [x] 9.2 **Critical**: the unconditional path now goes through an extra POP/PUSH compared to the current Story 4.2 implementation. Verify that this doesn't break Story 4.2's tests 90-91 (backward + forward JR encoding) — see Test 130 in this story for the regression spot-check. The byte pattern emitted should be byte-identical.
  - [x] 9.3 The conditional path consumes 2 cells (target + condition) instead of 1. The existing `POP BC` at the end of `w_JR_COMMA_cf` (lines 1418, 1438, 1450) pops the next cell as the new TOS — that's correct for the unconditional case (1 cell consumed) but for the conditional case we've already popped the condition into HL above. So the existing single `POP BC` at the bottom is correct for *both* cases as long as the condition pop in `.jrc_cond` *replaces* (not adds to) one of the existing pops. Walk through the stack state on paper to confirm before implementing.

- [x] Task 10: Wire `JP,`/`CALL,` fixup unresolved-error reporting (AC: #10)
  - [x] 10.1 The existing `asm_check_unresolved` (assembler.asm — search for it; it's in the label/fixup helper block) walks the fixup pool and prints `unresolved label NAME ?` for each remaining fixup. It does *not* care about the kind. Since Story 4.3's `JP,`/`CALL,` use the existing `ASM_FIXUP_KIND_DW` (per the Task 1.2 default), the unresolved-fixup error message at END-CODE is identical to what Story 4.2 produces for unresolved `DW,` references. **No change needed to `asm_check_unresolved`.** Verify by walking the call chain after Task 6.4 is implemented.
  - [x] 10.2 If Q1 is decided the other way (split kinds for DW vs JP/CALL), then `asm_check_unresolved` needs a kind-aware branch. Don't take this path unless Q1 is explicitly resolved as "split."

- [x] Task 11: Add new error message strings (AC: #10)
  - [x] 11.1 Most new error paths reuse the existing strings (`bad operand`, `not in CODE`, `unresolved label NAME`) — no new strings needed for the bulk of the dispatch errors.
  - [x] 11.2 **One new string is needed**: when `JR,` rejects a non-JR condition (PO/PE/P/M), the user benefits from a more specific message than `bad operand ?`. **Default**: stick with `bad operand ?` to avoid string-pool growth. **Alternative** (Q5): add `str_asm_bad_jr_cond: DB "JR cannot use this condition"` and a corresponding `asm_err_bad_jr_cond` trampoline. Pick one.

- [x] Task 12: Add REPL tests 107-131 (AC: #15)
  - [x] 12.1 The next free test number is 107 (Story 4.2 added through 106, verified via `Makefile:951`). Append the new test block to the `test-repl` target in `Makefile`, following the same one-emulator-launch-per-test pattern Story 4.2 used (or batch where convenient — see `Makefile` lines 717+ for the existing batching style).
  - [x] 12.2 For each test specified in AC15 (Tests 107-131), implement the test case in the Makefile. Verify the expected byte sequences against the Z80 instruction encoding manual before committing — Z80 opcodes are easy to mis-derive on paper. Useful cross-check: build and disassemble a tiny `.bin` via `sjasmplus` and compare against the AntForth assembler output.
  - [x] 12.3 Each test prints `PASS: REPL test N — <description>` on success, `FAIL: REPL test N — expected <bytes>` on failure. Mirrors the Story 4.2 pattern (Makefile lines 943-953).

- [x] Task 13: Verify no regressions (AC: #14)
  - [x] 13.1 `make test` — all 73 regression tests pass, EXPECTED string unchanged.
  - [x] 13.2 `make test-repl` — all existing tests 1-106 pass, plus new tests 107-131. **Especially watch Tests 90, 91, 102 (Story 4.2 JR), Test 113 (Story 4.1 reg-to-reg LD), and Test 124 (Story 4.1 reg arith)** — these are the regression-risk hotspots from the LD/arith/JR dispatch refactors.
  - [x] 13.3 `make` — clean build, no new sjasmplus warnings.
  - [x] 13.4 `outer_interpreter.asm` and `system.asm` are **untouched** in this story. Verify with `git diff --stat` after implementation that no lines have changed in either file. If any change appears, it is a bug in the implementation approach.
  - [x] 13.5 Manual smoke test under iz-cpm: define a CODE word using the LED-poke style example from the Dev Notes, exercise it, then exercise every error path interactively (`AF` reject, `(HL)(HL)` reject, conditional JR with PO, unresolved JP fixup, condition outside CODE, # outside CODE). Confirm error messages are readable and the prompt recovers cleanly after each.
  - [x] 13.6 **`C`-register preservation smoke test**: per Q2 the carry-set condition is spelled `CS`, never `C`, so the register `C` from Story 4.1 must remain fully functional. Define `CODE NOOPC C C LD, NEXT, END-CODE` (a no-op `LD C, C` = opcode `0x49`) and assert offset 0 = `0x49`. **And** repeat with `B C LD,` (Zilog dst-src → `LD B, C` = `0x41`) and `C B LD,` (→ `LD C, B` = `0x48`) to triangulate. If any of these emit `bad operand ?`, the condition word has accidentally been spelled `C` somewhere — bug in Task 3.2.
  - [x] 13.7 Stack-state hygiene: after every error path, confirm `.S` shows the expected baseline depth (0 immediately after a clean recovery; per memory `project_tos_in_register.md`, BC=TOS is "phantom" after ABORT and DEPTH should report 0).

### Review Follow-ups (AI)

- [x] **[AI-Review][HIGH][SHOWSTOPPER] Immediate-form operand order is inconsistent with register-to-register (blocks story completion).** Register form follows Zilog dst-src (`B C LD,` → `LD B, C`, NOS=dst, TOS=src). Immediate form currently reads src-first (`0x42 # A LD,` → `LD A, 0x42`, NOS=marker, TOS=dst) — src is NNOS, dst is TOS. A user who has internalised `dst src LD,` naturally types `A 0x42 # LD,` and gets `bad operand ?`. Postfix notation is hard enough without a per-form ordering flip. The project lead has ruled operand order must be uniformly Zilog dst-src across every opcode form. **Required changes:**
  1. `w_LD_COMMA_cf` immediate-form dispatch (`src/assembler.asm:1174` onward): detect the marker on **TOS** (check `B` high byte for `0xFD`), not on NOS. Pop the marker, pop the value as new TOS, read the destination tag from the next cell down.
  2. `asm_arith_word` immediate-form dispatch (`src/assembler.asm:1291` onward): same inversion — marker is now expected NOS, value is NNOS. Actually the arith immediate form has only one operand plus marker (`0x0F # AND,` → `AND 0x0F`), so re-derive the stack discipline: `value # AND,` means TOS=marker, NOS=value. Pop marker, then value. (Arith immediate is single-operand so it does not have a dst-src issue — only LD, does. Verify no change is needed to `asm_arith_word` and document that.)
  3. AC1, AC2, AC9, AC15 Tests 107/108/109/123 in this file: rewrite syntax to `dst value # LD,` order — e.g. `B 0x55 # LD,` → `LD B, 0x55` (0x06 0x55); `BC 0x1234 # LD,` → `LD BC, 0x1234` (0x01 0x34 0x12); `AF 0x1234 # LD,` → rejected.
  4. AC15 Task 13.6 also has a dst-src swap bug: it claims `B C LD,` → `LD C, B` = 0x48 and `C B LD,` → `LD B, C` = 0x41. Per Zilog dst-src, it's the other way round (`B C LD,` = LD B,C = 0x41). Fix in the same pass.
  5. `Makefile` Tests 107/108/109/123: rewrite to match the new syntax. Expected byte sequences stay identical — only the Forth input strings change.
  6. Dev Notes "LD, Dispatch Tree (After Story 4.3)" (around line 395): rewrite the pseudo-code to check NOS for the marker, not NNOS. The dispatch becomes: "if TOS high byte == 0xFD: immediate path; pop marker, pop value, pop dst".
  7. The footgun doc in `src/assembler.asm` file header: the examples must be inverted. `A 0 LD,` (forgotten `#`) now becomes the natural bad counter-example. Update the table with the dst-first reading and re-derive what silently mis-assembles (a single integer in NOS gets re-interpreted as the source register, not the destination).
  8. Re-run `make test` and `make test-repl` — all 73 regression + 131 REPL tests must still pass.
  9. Save a project memory `feedback_assembler_operand_order.md` update: the existing entry covers reg-to-reg Zilog dst-src; extend it to "ALL forms including immediate, indirect-(HL), and any Story 4.4 extensions — no per-opcode exceptions."

  **Why:** postfix notation is already cognitively expensive. An internal inconsistency (some forms dst-first, others src-first) forces users to remember which is which per-opcode, defeating the Zilog convention entirely. Story 4.4 extended opcodes will multiply the inconsistency if this is not fixed now. This finding reverts the story from `done` back to `in-progress`.

## Dev Notes

### What Story 4.3 Delivers

Story 4.3 turns the assembler from "interesting toy" into "actually useful." After 4.3 the user can write the bulk of typical CODE words: hardware probes (LD A, n; OUT — but `OUT,` itself waits for 4.4), table lookups (LD HL, table; LD A, (HL)), control flow (conditional JR/JP/RET, CALL into subroutines), and inline ALU constants (AND 0x0F, CP 0x20). Story 4.4 then adds the extended-prefix instructions (CB-prefix bit ops, DD/FD-prefix IX/IY, ED-prefix block transfers, port I/O) which round out the instruction set but are rarely needed for the kind of code AntForth users will write at the prompt.

### Tag Encoding Map (After Story 4.3)

| Tag type | High byte | Low byte | Source |
|----------|-----------|----------|--------|
| 8-bit register | `0x00` | `0x00..0x07` (B,C,D,E,H,L,(HL),A) | Story 4.1 + Story 4.3 (HL) |
| 16-bit register pair | `0x00` | `0x10..0x14` (BC,DE,HL,AF,SP) | Story 4.1 |
| Immediate marker | `0xFD` | `0x00` (irrelevant) | Story 4.3 — pushed by `#` |
| Condition code | `0xFE` | `0x00..0x07` (NZ,Z,NC,CS,PO,PE,P,M) | Story 4.3 |
| Label tag | `0xFF` | `0x00..0x0F` (slot index) | Story 4.2 |

The high-byte sentinel scheme is **the** dispatch primitive in this assembler — every opcode word that takes a typed operand starts by reading B (the high byte of TOS). The sentinels were chosen so that no realistic dictionary or stack address ever matches them: BDOS lives ~`0xE400+` on iz-cpm, and the user dictionary stays well below `0xE400`, so anything `0xE400+` is "system area" and anything `0xFD..0xFF` in the high byte is unambiguously a tag. **Verify against `architecture.md` "Memory Layout"** (lines 112-122) before relying on this — the verification was done in Story 4.2 and the answer was "safe", but Story 4.3 introduces two more sentinel ranges and the verification should be re-confirmed.

### Why `#` Pushes a Stack Marker (Not a Global Flag)

An earlier draft of this story used a global `asm_imm_pending` byte: `#` would set it, opcode words would check it, and `asm_cleanup` would clear it. This was rejected because:

1. **`asm_cleanup` would have to know about every flag.** Story 4.2's design carefully kept all per-CODE state in two fixed-size pools (label slots, fixup records) plus the side-area top pointer. Adding flag bytes makes cleanup harder to reason about.
2. **Stack-marker discipline is uniform with the rest of the assembler.** Register tags, label tags, and condition codes are all "this stack cell carries a special meaning, recognised by its high byte." Adding a global flag for the immediate case would be inconsistent — the only stateful exception in an otherwise stateless dispatch.
3. **The marker can never accidentally persist across CODE words.** If the user types `0x42 # END-CODE`, the marker on the stack at END-CODE time is just a garbage 16-bit value — it doesn't affect the next CODE word (the marker is consumed when the next opcode word that uses it runs, OR it stays on the stack as an inert value). A global flag, by contrast, would have to be explicitly cleared at END-CODE.
4. **Errors are self-cleaning.** When an opcode word ABORTs partway through dispatch, the stack is reset by ABORT (SP returned to baseline), so any stray marker is wiped along with the rest of the user's transient state. No special cleanup logic needed.

The cost is one extra cell of stack pressure during the brief window between `#` and the consuming opcode. That's negligible.

### `RET,` and the Peek-TOS Convention

`RET,` is the only opcode word in Story 4.3 (or Story 4.1) that *peeks* TOS rather than popping it. The reason: unconditional `RET,` takes zero operands, so it must not consume anything. Conditional `RET,` (`Z RET,`, etc.) takes one operand (the condition). The dispatch logic peeks: if TOS is a condition tag, pop and consume; otherwise, leave TOS alone and emit unconditional RET.

This means the user's stack discipline is sensitive: if there happens to be a condition tag on TOS from earlier code (e.g., they typed `Z ... <some sequence that left Z on stack> RET,`), `RET,` will silently consume it as if it were intended. This is the same risk Forth has with any peek-and-decide word and is consistent with Almy's Z80 Forth assembler convention (per `docs/z80_forth_assemblers.md`). Document the gotcha clearly in the assembler module's file header.

The alternative — requiring explicit `?RET,` for conditional and `RET,` for unconditional — was rejected because the AC text in `epics.md` (lines 877-924) shows `Z RET,` as the canonical syntax. Stick with the AC text.

### `LD,` Dispatch Tree (After Story 4.3)

The `LD,` word's dispatch grows from "two register operands" to a 4-way decision:

```
LD,:
  if TOS.hi == ASM_IMM_TAG_HI (0xFD):        ; immediate form
    pop marker → new TOS = value
    pop dst tag                              ; NNOS at entry
    if dst is 8-bit reg (L < 8):
      reject (HL) (Story 4.4 territory) → bad operand
      else emit LD r, n  (0x06 | r<<3, then n)
    else if dst is 16-bit reg pair (L >= 0x10):
      reject AF → bad operand
      else emit LD rr, nn  (0x01 | qq<<4, then lo, then hi)
    else: bad operand
  else (no immediate marker):                ; reg-to-reg form
    src = TOS tag   (assert_8bit_reg_or_ihl)
    pop dst tag     (assert_8bit_reg_or_ihl)
    if src == 6 AND dst == 6: bad operand (would be HALT)
    emit LD r, r'  (0x40 | dst<<3 | src)
```

All forms share the same Zilog dst-src reading direction: whatever the
user types leftmost is the destination. The register form `B C LD,`
assembles `LD B, C`; the immediate form `B 0x42 # LD,` assembles
`LD B, 0x42`; the 16-bit form `BC 0x1234 # LD,` assembles
`LD BC, 0x1234`. There is no per-form operand-order flip.

The 16-bit-immediate path (`LD rr, nn`) is functionally distinct from the 8-bit immediate path (`LD r, n`) — different opcode pattern, different operand size. They share entry through the immediate-marker check, then diverge on the destination tag's high nibble.

### Anti-Patterns to Avoid

1. **Do NOT rebuild the existing `assert_8bit_reg`.** Add a new permissive variant `assert_8bit_reg_or_ihl` for the LD, path. The existing strict variant (which rejects 6) must continue to gate the arith ops, because allowing `(HL)` in arith is Story 4.4 territory (CB-prefix shifts also use the (HL) operand, and the dispatch is shared).
2. **Do NOT add `LD (HL), n`** in this story. The Z80 has it (`0x36 nn`) but the AC text doesn't list it and adding it now creates a 3rd dispatch branch in the immediate path — small but enough to delay this story for a Q&A round. Story 4.4 can add it.
3. **Do NOT add `LD A, (BC)` / `LD A, (DE)` / `LD (nn), A` / `LD A, (nn)` / `LD (nn), HL` etc.** in this story. These are all single-byte or 3-byte direct-address forms that the AC text mentions only via the catch-all `(HL)` example. Wait for explicit user request.
4. **Do NOT touch `outer_interpreter.asm` or `system.asm`.** Story 4.2's "no INTERPRET surgery" rule extends here. The condition words (`NZ`, `Z`, `NC`, `C`, `PO`, `PE`, `P`, `M`), `(HL)`, and `#` are all normal Forth dictionary entries created by DEFCODE — no INTERPRET hooks, no parsing tricks.
5. **Do NOT add tests to the regression test thread.** REPL-piped tests only (per memory `feedback_repl_tests_preferred.md`).
6. **Do NOT split `JP,` and `CALL,` into duplicated 100-line bodies.** Use the shared `asm_jp_call_word` helper (Task 6.6). Duplication invites maintenance drift between the two paths.
7. **Do NOT forget to spill DE/IP in the new opcode words.** Story 4.2 retrospective bug #3 was JR,/FIX/DW, not preserving DE. The new `w_JP_COMMA_cf`, `w_CALL_COMMA_cf`, and `w_RET_COMMA_cf` all need the same defensive spill — add it preemptively, don't wait for the smoke test to find it.
8. **Do NOT assume the existing `w_JR_COMMA_cf` POP discipline is unchanged after adding the conditional path.** The conditional case consumes 2 cells; the unconditional case consumes 1. Walk through the stack states on paper before implementing Task 9.
9. **Do NOT spell the carry-set condition word `C`, and do NOT add `CC` as an alias for `NC`.** Q2 is resolved: the carry-set condition is `CS` (carry set, 6502-style). The Zilog spelling `C` would shadow the register `C` from Story 4.1 and silently break every existing test that uses `C` as an 8-bit register operand. The 6502-style alias `CC` for carry-clear was rejected because `CC` parses as integer `0xCC` = 204 in BASE=16, and adding it as a dictionary word silently shadows the hex literal — see Q8. The carry-clear condition is spelled **`NC` only** (Zilog manual). There is no circumstance under which a condition word in this assembler should be named `C` or `CC`.
10. **Do NOT use a global `asm_imm_pending` flag.** The stack-marker design is the canonical answer (see "Why `#` Pushes a Stack Marker" above).
11. **Do NOT skip the `(HL),(HL)` reject** in `LD,`. Encoding `0x76` is HALT, not LD — silently accepting it would emit a runtime trap in the user's CODE word.
12. **Do NOT extend conditional JR to PO/PE/P/M.** The Z80 hardware has no JR for those conditions. Reject explicitly with `bad operand ?` (or the optional new error string from Q5).

### Open Questions for the Project Lead

The following are decisions where the AC text is silent or where two reasonable answers exist; surface them to the project lead before or during implementation. **Save these for the end of implementation, do not block on them up front** — pick a reasonable default, document it, and confirm.

- **Q1: Share `ASM_FIXUP_KIND_DW` for both `DW,` and `JP,`/`CALL,` patches, or split them?** The patch operation is byte-for-byte identical (write 16-bit absolute address little-endian). Sharing keeps the fixup pool simpler and the unresolved-error message uniform. Splitting allows a more precise error message (`unresolved label X (used by JP) ?` vs `unresolved label X (used by DW) ?`) and is marginally more debuggable. **Default: share** — uniform error message matches Story 4.2's existing convention.
- **Q2: How do we resolve the `C` register vs `C` condition name collision?** **RESOLVED by project lead 2026-04-12**: rename the carry-set condition (cc=3) from Zilog `C` to 6502-style `CS` (carry set). The carry-clear condition (cc=2) keeps its Zilog spelling `NC` — the 6502 spelling `CC` was initially proposed as an alias but rejected on second look (see Q8): `CC` is a valid integer literal in BASE=16 (= 0xCC = 204), and shadowing it with a dictionary word silently breaks any code that relied on the literal. The register `C` (tag `0x0001`) is preserved unchanged. Net effect: a single Zilog spelling departs (`C` → `CS`), every other condition keeps its manual name, and no number-literal is shadowed. Document the single departure in `docs/z80_forth_assemblers.md` so future maintainers understand why `CS` appears where the Zilog manual shows `C`.

- **Q8: Number-literal shadowing audit for new dictionary words.** Any new word whose name parses as a valid number in BASE=16 (or in the user's likely working base) silently shadows that literal once the word is defined. The Story 4.3 candidates were:
  - `CC` (originally proposed Q2 alias) — `0xCC` = 204 in BASE=16 → **rejected, see Q2**
  - `CS`, `NC`, `NZ`, `PO`, `PE`, `Z`, `P`, `M` — none are valid hex (each contains a non-hex letter; `Z` is only a digit in BASE≥36)
  - `(HL)` — contains parentheses, never a number
  - `#` — single non-alphanumeric, never a number
  - `JP,`, `CALL,`, `RET,` — contain commas, never numbers
  - **All Story 4.3 words are safe except `CC`, which is excluded.**
  
  Story 4.1's existing register words `A`, `B`, `C`, `D`, `E` are *also* valid hex digits (10..14) that are silently shadowed in BASE=16 — but that shadow has been live since Story 4.1 and is intentional (the register meaning dominates the number meaning inside CODE). The asymmetry: those single-letter shadows were grandfathered by Story 4.1; Story 4.3 should not introduce new ones because the number-literal use case is more important the longer the multi-letter token. **Rule**: any future word whose name is a valid number in any reasonable base must be justified explicitly. `CC` failed this rule.
- **Q3: Add `LD (HL), n`** (= `0x36 nn`)? It's the natural completion of the immediate-load family and trivial to add. **Default: defer to Story 4.4** — keeps Story 4.3 scope tight. Reconsider if a user asks for it.
- **Q4: How should `0x1234 # AND,` behave when the immediate value is > 0xFF?** Silent low-byte truncation (emit `AND 0x34`) is consistent with Story 4.2's `DB,` decision. Strict rejection (`bad operand ?`) is more defensive. **Default: silent truncation**, matching Story 4.2 and sjasmplus.
- **Q5: Add a dedicated error string for `JR cc` with non-JR condition** (PO/PE/P/M)? Specific message: `JR cannot use this condition ?`. Generic message: `bad operand ?`. **Default: generic** — saves ~30 bytes of string pool and the user can figure it out.
- **Q6: Add the parsing words `(BC)` and `(DE)`** for `LD A,(BC)` (= 0x0A) and `LD A,(DE)` (= 0x1A)? These are 1-byte single-purpose opcodes — easy to add but not in the AC text. **Default: defer** — wait for explicit demand.
- **Q7: Add `JP (HL)`** (= `0xE9`, the indirect-via-HL absolute jump used for jump tables)? Useful for dispatch tables but not in the AC text. **Default: defer to Story 4.4** along with `JP (IX)` / `JP (IY)`.

### Previous Story Intelligence (from Stories 4.1 and 4.2)

**From the Story 4.1 retrospective** (4-1-code-word-framework-and-basic-instructions.md, the "Code Review Follow-ups" and "Debug Log References" sections):

1. **Register-contract violations were the dominant bug class.** The first-pass NEXT, used DE as the LDIR destination, clobbering IP. Apply this lesson to every new opcode word in Story 4.3: assume DE will be clobbered by every helper call unless the helper's contract explicitly says otherwise. Spill DE to `asm_ip_save` (or to the return stack) at the top of `w_JP_COMMA_cf`, `w_CALL_COMMA_cf`, `w_RET_COMMA_cf`, and around the new branches in `w_LD_COMMA_cf` and `w_JR_COMMA_cf`.
2. **Spill slot reuse is safe only if call paths don't nest.** Story 4.1 introduced `asm_tmp` (1 byte); Story 4.2 added `asm_tmp2` (2 bytes), `asm_ip_save` (2 bytes), and `asm_resolve_target` (2 bytes). Story 4.3's new dispatch branches reuse `asm_tmp` (already used by `asm_arith_word` for the base opcode) and `asm_ip_save` (already used by `w_JR_COMMA_cf`). The new helper `asm_jp_call_word` needs its own scratch for the conditional opcode — add a 1-byte `asm_jp_op` slot to keep it separate from `asm_tmp` (which `asm_arith_word` also uses). Don't share scratch across nesting boundaries.
3. **Code review will find issues — anticipate them.** Per memory `feedback_adversarial_review.md`, the review MUST find things. Likely Story 4.3 review findings:
   - `LD,`'s 4-way dispatch is the most complex word in the assembler. Cyclomatic complexity will be flagged. Consider extracting `asm_ld_imm8`, `asm_ld_imm16`, `asm_ld_reg_reg` as named subroutines with one-line summaries.
   - The `RET,` peek-TOS convention is a footgun — flag it in the assembler module's file header and add a smoke-test for "C tag from earlier code accidentally consumed by RET,".
   - Conditional-JR test 121's displacement arithmetic must be derived against the existing `asm_jr_disp` formula in `assembler.asm` — re-deriving it on paper is error-prone.
   - The `C` register / `C` condition collision (Q2) is the highest-priority finding and should be resolved before code review starts.
4. **Use `asm_print_error` everywhere** — never raw BDOS write sequences. Story 4.3 doesn't add new error strings (Q5 is open) but the existing trampolines (`asm_err_*`) are the only call path.
5. **Don't use `~F_SMUDGE`** — sjasmplus rejects it. Use `AND 0xBF` with a derivation comment, per Story 4.1's L2 fix. (Story 4.3 doesn't touch SMUDGE handling, but the same rule applies to any flag-clear operation.)

**From the Story 4.2 retrospective** (4-2-labels-and-data-definition-words.md, "Debug Log References"):

1. **`LD DE, (asm_body_start)` clobbered DE before save** — the save-DE-to-RS prologue must run BEFORE any DE use. Apply to the new opcode words in this story: spill DE *first*, then read scratch.
2. **END-CODE didn't preserve DE/BC across helper calls.** Story 4.3's new opcode words don't add helper calls in END-CODE itself, but the reasoning generalises: any helper that touches DE/BC must be either bracketed by save/restore or known to preserve them. Audit the new helpers (`asm_jp_call_word`) for this.
3. **JR,/FIX/DW, didn't preserve DE.** The same root cause for `w_JP_COMMA_cf` and `w_CALL_COMMA_cf` — both need explicit DE spill via `asm_ip_save`.
4. **`POP HL` after displacement computation overwrote the displacement.** This is a sequencing trap — when both HL is the result of an arithmetic step AND HL is needed as a fresh value from the stack, order the operations so the result is read out (`LD A, L`) BEFORE the POP. Apply to the new conditional-JR path in Task 9: read whatever you need from HL before any `POP HL` clears it.

### Git Intelligence

Recent commits show one-commit-per-story pattern with the message form `completed story X.Y`:
```
500e81b Merge branch 'main' of github.com:blowback/antforth
e7c64c6 completed story 4.2
9660e44 Create LICENSE
7606d0c completed story 4.1
e1fca6a add WISHLIST.md
```

Story 4.2 touched `src/assembler.asm` (~+1100 lines net), `Makefile` (REPL tests 90-106), `_bmad-output/implementation-artifacts/4-2-*.md` (status update), and `_bmad-output/implementation-artifacts/sprint-status.yaml` (status flip to done). **Story 4.3 will touch:**
- `src/assembler.asm` — extend with the new tag constants, the new parsing words (`#`, `(HL)`, 8 condition codes), the new opcode words (`JP,`, `CALL,`, `RET,`), the extended `LD,`/`JR,`/arith dispatches, and the shared `asm_jp_call_word` helper. Estimated +400-500 lines.
- `Makefile` — append REPL tests 107-131. Estimated +120-140 lines.
- **NOT** `src/outer_interpreter.asm` — explicitly excluded by the design.
- **NOT** `src/system.asm` — `w_ABORT_cf` already calls `asm_cleanup` from Story 4.1; Story 4.2 already extended `asm_cleanup`; no further `system.asm` change needed for Story 4.3.
- **NOT** any other `.asm` file — the assembler module is self-contained.

Expected diff size: ~500 lines added to `assembler.asm`, ~130 lines added to `Makefile`. Net change to other files: zero (except the story file and sprint-status.yaml).

### Testing Strategy

Per memory `feedback_repl_tests_preferred.md`, all new tests are REPL-piped Forth scripts in `make test-repl`, not assembly test threads. The Story 4.2 tests 90-106 are the structural template.

Per memory `feedback_adversarial_review.md`, code review will find issues — anticipate:
- **What if `#` is called with empty stack?** Standard underflow — system behaves as it does for any other word with insufficient operands. Match Story 4.2's "no defensive depth check" decision.
- **What if `(HL)` is called outside CODE?** `check_asm_mode` rejects it cleanly. Story 4.1's register-tag words use the same gate; this is uniform.
- **What if a condition word is followed by a non-conditional opcode** (e.g., `Z A B LD,`)? The condition tag stays on the stack as a phantom NOS that the LD, will see when it pops the destination. Result: LD, sees TOS = B reg, NOS = A reg, NNOS = 0xFE01. The first two pops succeed; the LD, completes and emits `LD A, B`. The condition tag is left dangling on the stack. On the next opcode word, it becomes TOS (or NOS) and may cause spurious behaviour. **This is a user error**, and it's structurally identical to leaving any other unconsumed tag on the stack. The standard `.S` debugging path catches it. Document in the assembler reference but don't add defensive checks.
- **What if `(HL)` and `(HL)` are used in `LD,`?** Caught by Task 2.3's explicit guard — `bad operand ?`.
- **What if `LD AF, nn` is attempted?** Caught by Task 4.4's AF reject — `bad operand ?`.
- **What if a conditional JR uses PO?** Caught by Task 9.1's range check — `bad operand ?`.
- **What if a JP/CALL fixup is unresolved at END-CODE?** Caught by the existing `asm_check_unresolved` (no change needed, per Task 10).
- **What if two opcode words share scratch byte `asm_tmp` across nested calls?** Per memory `project_tos_in_register.md` and Story 4.1 retrospective lesson #2, this is safe IFF the call paths don't nest. Audit the new dispatch branches: `asm_arith_word` uses `asm_tmp` for the base opcode; the new immediate path inside `asm_arith_word` uses `asm_tmp` for the same purpose, doesn't nest. `asm_jp_call_word` should NOT touch `asm_tmp` — use a new `asm_jp_op` byte instead.
- **What if the user types `# #`?** First `#` pushes 0xFD00 (TOS). Second `#` pushes another 0xFD00 (new TOS). Stack: `[..., 0xFD00, 0xFD00]`. The next opcode word that consumes a marker pops one 0xFD00; if it then expects a value below, it reads the second 0xFD00 (treating it as the value). Garbage in, garbage out — same standard as other Forth assemblers. No defensive check needed.
- **What if the user types `0x42 # NEXT,`?** `NEXT,` doesn't consume any operand from the stack. The 0xFD00 marker and the 0x42 value are left dangling. Next opcode word sees garbage. User error; same standard as above.

Per memory `feedback_standards_compliance.md`, the design departs from historical fig-FORTH/MMSForth in three places:
- Explicit `LABEL`/`FIX` (Story 4.2) instead of anonymous mark/resolve.
- Stack-marker `#` for immediates (this story) instead of state flags or context-sensitive opcode words.
- Peek-TOS for `RET,` (this story) — actually, this *matches* Almy's convention. Document as "matches prior art" not "departure."

Reference `docs/z80_forth_assemblers.md` for the prior art; update its "departures from prior art" section after Story 4.3 ships.

### References

- [Source: src/assembler.asm] — Story 4.2's assembler module; this story extends it
- [Source: src/assembler.asm:94-106] — existing tag constants block; Task 1.1 adds `ASM_IMM_TAG_HI` and `ASM_COND_TAG_HI` here
- [Source: src/assembler.asm:759-844] — `asm_push_tag` and the existing register-tag words; Task 2.1 ((HL)) and Task 3.2 (condition codes) add words alongside this block
- [Source: src/assembler.asm:1046-1055] — `assert_8bit_reg`; Task 2.2 adds `assert_8bit_reg_or_ihl` next to it
- [Source: src/assembler.asm:1061-1081] — `w_LD_COMMA_cf`; Task 4 extends it with the immediate-form dispatch branches
- [Source: src/assembler.asm:1102-1146] — `asm_arith_word` and the 6 arith opcode words; Task 5 extends `asm_arith_word` with the immediate-form branch
- [Source: src/assembler.asm:1153-1190] — `w_NEXT_COMMA_cf` and `next_template`; reference for the IX/RS save-restore prologue pattern that the new opcode words may need
- [Source: src/assembler.asm:1393-1451] — `w_JR_COMMA_cf`; Task 9 inserts the conditional-prefix dispatch
- [Source: src/assembler.asm:1453-1460] — `asm_apply_jr_fixup_emit` / `asm_jr_disp`; Test 121 and Task 9.1 reuse this without modification
- [Source: src/assembler.asm:1465-1543] — `w_DB_COMMA_cf`, `w_DW_COMMA_cf`; reference for the label-tag detection pattern used by `JP,`/`CALL,`
- [Source: src/assembler.asm:1571-end] — `w_EQU_cf` and the asm_die error trampolines; reference for the asm_die / asm_err_* convention
- [Source: src/macros.asm:58-94] — DEFCODE / DEFWORD / DEFIMMED macros for new word definitions
- [Source: src/memory.asm] — `C@` and `@` (used by all the new REPL tests for byte/word inspection)
- [Source: src/dictionary.asm] — `find_word`, hash table layout (relevant for the C-register/C-condition collision diagnosis in Task 13.6)
- [Source: src/constants.asm] — flag bits used by `build_header` (no changes in this story)
- [Source: _bmad-output/planning-artifacts/architecture.md#Memory Layout, lines 112-122] — memory map (verify high-byte sentinel ranges 0xFD/0xFE/0xFF are above any plausible HERE/dictionary address)
- [Source: _bmad-output/planning-artifacts/architecture.md#Code Field Layout, lines 147-154] — direct threading and CODE word layout
- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3, lines 877-924] — story requirements (source of truth for AC1-AC11)
- [Source: _bmad-output/implementation-artifacts/4-2-labels-and-data-definition-words.md] — Story 4.2 final state including all anti-patterns, tag encoding decisions, and code review follow-ups
- [Source: _bmad-output/implementation-artifacts/4-1-code-word-framework-and-basic-instructions.md] — Story 4.1 final state, register-tag table, retrospective lessons
- [Source: docs/z80_forth_assemblers.md] — prior-art survey; Almy's `RET,` peek-TOS convention referenced in Dev Notes
- [Source: Makefile, lines 717+] — `test-repl` target with Story 4.0 / 4.1 / 4.2 test patterns (new tests follow the same shape)
- [Source: Makefile, lines 943-953] — Story 4.2's tests 105-106 — the most recent test additions, exact pattern to mirror

## Dev Agent Record

### Agent Model Used

claude-opus-4-6 (1M context)

### Debug Log References

- Bug found during test 108: `asm_emit_byte` clobbers HL but the
  16-bit immediate path was reading H after the first emit. Fixed by
  spilling the 16-bit value to `asm_tmp2` before emitting the lo byte
  and re-fetching the hi byte from `(asm_tmp2 + 1)`.
- Test fixture issue: existing REPL test 97 used `LABEL Z` to assert
  cleanup unlinked the label, which now collides with the new
  permanent `Z` condition word. Renamed the test's label to `ZED`.
- Hex-literal parsing collision: in HEX mode, single hex digits
  `A B C D E F` are looked up in the dictionary first and resolve to
  the register words from Story 4.1. Tests reading byte offsets ≥ 10
  use leading-zero forms (`0A 0B 0C 0F`) to bypass dict lookup.
- REPL input buffer is ~128 chars; long byte-read sequences in tests
  108 / 118 / 123 are split across multiple input lines and matched
  against the joined output via separate substring checks.
- Test 110 / 111 had swapped expected operand positions in the AC
  text. Per the Story 4.1 convention `dst src LD,`, the corrected
  forms are `A (HL) LD,` → `LD A, (HL)` (= 0x7E) for loads from
  memory and `(HL) A LD,` → `LD (HL), A` (= 0x77) for stores.

### Completion Notes List

- All 13 tasks (subtasks 1.1 through 13.7) implemented and verified.
- New constants: `ASM_IMM_TAG_HI = 0xFD`, `ASM_COND_TAG_HI = 0xFE`.
  JP,/CALL, share `ASM_FIXUP_KIND_DW` per Q1 default.
- New parsing words: `#`, `(HL)`, `NZ Z NC CS PO PE P M`. Carry-set
  is spelled `CS` (6502-style) per Q2; `CC` rejected per Q8.
- New opcode words: `JP,`, `CALL,`, `RET,`. JP and CALL share helper
  `asm_jp_call_word`; RET, peeks TOS to support unconditional (zero
  operand) and conditional forms.
- Extended dispatches: `LD,` handles `LD r,n`, `LD rr,nn` (AF
  rejected), and indirect-(HL) forms (`(HL),(HL)` rejected = HALT).
  Arith ops gain immediate variants via `asm_is_imm_tag`.
  `JR,` gains conditional dispatch with PO/PE/P/M rejected.
- New permissive helper `assert_8bit_reg_or_ihl` for the LD path;
  arith ops keep strict `assert_8bit_reg`.
- All 73 regression tests pass (`make test`); all 131 REPL tests
  pass (`make test-repl`), including Story 4.1/4.2 regression
  spot-checks (tests 113, 124, 130).
- `src/outer_interpreter.asm` and `src/system.asm` untouched.

### File List

- src/assembler.asm — modified (+430/-12 per `git diff --stat`): new
  tag constants, scratch slot `asm_jp_op`, parsing words `#`/`(HL)`/
  8 condition codes, opcode words `JP,`/`CALL,`/`RET,`, extended
  `LD,`/`JR,`/arith dispatch, helpers `asm_is_imm_tag`/
  `asm_is_cond_tag`/`asm_push_cond_tag`/`assert_8bit_reg_or_ihl`/
  `asm_jp_call_word`.
- Makefile — modified (+225/-0 per `git diff --stat`): added REPL
  tests 107-131 (25 new tests), renamed test 97's label from `Z` to
  `ZED` to avoid collision with the new condition word.

### Change Log

- 2026-04-12: Story 4.3 implemented. Added Z80 immediate-load
  forms, indirect-(HL) loads, conditional/unconditional JP/CALL/
  RET, conditional JR, and immediate arith forms. All tests pass.
- 2026-04-12: Code review completed. Fixes applied:
  * `w_RET_COMMA_cf` — added depth guard so an empty-stack phantom
    BC matching 0xFE** cannot take the conditional path and POP
    from underflow; also removed dead `asm_ip_save` save/restore.
  * `asm_jp_call_word` — moved unconditional-opcode scratch from
    shared `asm_tmp` to a dedicated `asm_jp_op` slot, honouring
    the "don't share scratch across nesting boundaries" rule.
  * `.jpc_label` — removed unnecessary `PUSH HL/POP HL` around the
    slot-index range check (HL discarded moments later).
  * Clarified the pop-vs-peek comment in `asm_jp_call_word`.
  * Story AC3 and AC15 Tests 110/111/113 corrected: operand order
    now matches the Zilog `dst src` convention (per memory
    `feedback_assembler_operand_order.md`) and the implementation.
  * File List line counts updated against `git diff --stat`.
  All 73 regression tests + 131 REPL tests still pass.
- 2026-04-12: Story reopened (done → in-progress). Code review
  surfaced a SHOWSTOPPER: immediate-form `LD,` operand order reads
  src-first (`value # dst LD,`) while register-to-register reads
  dst-first (`dst src LD,`, Zilog convention). Project lead ruled
  this an unacceptable inconsistency for postfix syntax. See
  "Review Follow-ups (AI)" for the required fix. The footgun
  documentation added to this story and to `src/assembler.asm` has
  been reverted — it baked the wrong order into the file header.
- 2026-04-12: SHOWSTOPPER review finding resolved. Immediate `LD,`
  dispatch in `w_LD_COMMA_cf` now detects the marker on TOS (not
  NOS): it pops the marker, pops the value into BC, then pops the
  destination tag from the cell below. Public syntax is uniformly
  Zilog dst-src across every form — `A 0x42 # LD,`, `BC 0x1234 # LD,`,
  `B C LD,`, `A (HL) LD,`, `(HL) A LD,`. The 16-bit immediate path
  no longer needs an `asm_tmp2` spill because BC holds the value and
  `asm_emit_byte` preserves BC. AC1/AC2/AC11/AC12/AC13/AC15 Tests
  107/108/109 and Makefile tests 107/108/109 were rewritten to the
  new syntax; the expected byte sequences are unchanged. The file
  header operand-order block was rewritten with dst-src examples
  for every form. Memory `feedback_assembler_operand_order.md` was
  already updated during review. All 73 regression tests and 131
  REPL tests pass. Status: review.
- 2026-04-12: Second code review pass. Three medium-severity findings
  fixed:
  * `assembler.asm` file header — added a "reserved single-letter
    dictionary words" block listing A B C D E H L (registers) and
    Z P M (single-letter conditions) plus the two-letter NZ NC CS PO
    PE conditions, so future story authors and users see the full
    namespace at a glance instead of having to grep DEFCODE.
  * `w_LD_COMMA_cf` register-to-register path — added an inline
    comment at the `LD (asm_tmp), A` spill noting the slot is shared
    with `asm_arith_word` and the sharing is safe because LD, and
    arith opcode words never nest. Cheap insurance against the next
    refactor breaking the no-nest assumption silently.
  * `asm_jp_call_word` `.jpc_label` resolved branch — replaced the
    redundant second `asm_slot_addr` lookup with a single read of
    slot+1/slot+2 into DE before any emit (DE is already spilled to
    `asm_ip_save` at the top of the helper, so clobbering it here is
    safe and the save/restore at `.jpc_done` covers it). Saves one
    helper call and three bytes of code per resolved JP/CALL label
    target.
  All 73 regression tests + all REPL tests still pass. Status: done.
  It will be rewritten after the operand-order fix lands.
