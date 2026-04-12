# Story 4.4: Extended Z80 Opcodes

Status: done

## Story

As a Forth user,
I want the extended Z80 instruction set (CB/DD/FD/ED-prefixed) available in the assembler, plus INC/DEC/EX and I/O instructions,
so that I can use bit operations, rotates/shifts, IX/IY indexed addressing, block transfers, and port I/O in CODE words — completing the assembler's coverage of the Z80 instruction set for practical embedded programming.

## Acceptance Criteria

1. **IX/IY indexed addressing with displacement:** Given a CODE definition, when `(IX) 5 +D A LD,` (LD A, (IX+5)) is typed, then the correct DD-prefixed opcode with displacement byte is assembled (DD 7E 05). And `A (IX) 5 +D LD,` (LD (IX+5), A) emits DD 77 05. And `(IY) 3 +D B LD,` (LD B, (IY+3)) emits FD 46 03. And `(IX) 5 +D 42 # LD,` (LD (IX+5), 42) emits DD 36 05 2A. And displacements outside -128..+127 raise `range ?` at assemble time.

2. **IX/IY register pair operations:** Given a CODE definition, when `IX PUSH,` is typed, then DD E5 is assembled. And `IY POP,` emits FD E1. And `IX 0x1234 # LD,` emits DD 21 34 12 (LD IX, 0x1234). And `IY 0x5678 # LD,` emits FD 21 78 56.

3. **INC/DEC (8-bit register):** Given a CODE definition, when `B INC,` is typed, then 04 is assembled (INC B = 0x04 | (r<<3)). And `A DEC,` emits 3D. And all 7 registers (B,C,D,E,H,L,A) work for both INC, and DEC,.

4. **INC/DEC (16-bit register pair):** Given a CODE definition, when `BC INC,` is typed, then 03 is assembled (INC BC = 0x03 | (rr<<4)). And `SP DEC,` emits 3B. And `IX INC,` emits DD 23. And `IY DEC,` emits FD 2B.

5. **INC/DEC (indirect/indexed):** Given a CODE definition, when `(HL) INC,` is typed, then 34 is assembled. And `(IX) 5 +D INC,` emits DD 34 05. And `(IY) 3 +D DEC,` emits FD 35 03.

6. **Bit operations:** Given a CODE definition, when `3 # A BIT,` (BIT 3, A) is typed, then CB 5F is assembled. And `5 # B SET,` (SET 5, B) emits CB E8. And `7 # C RES,` (RES 7, C) emits CB B9. And bit numbers outside 0..7 raise `range ?` at assemble time.

7. **Bit operations on (HL):** Given a CODE definition, when `3 # (HL) BIT,` is typed, then CB 5E is assembled. And `5 # (HL) SET,` emits CB EE. And `7 # (HL) RES,` emits CB BE.

8. **Bit operations on indexed memory:** Given a CODE definition, when `3 # (IX) 5 +D BIT,` (BIT 3, (IX+5)) is typed, then the correct DDCB-prefixed sequence DD CB 05 5E is assembled. And `5 # (IY) 3 +D SET,` emits FD CB 03 EE. And the three-operand stack picture (bit-immediate + indexed-addr-tag + displacement-cell) is consumed correctly.

9. **Rotates and shifts:** Given a CODE definition, when `A RLC,`, `B RRC,`, `C RL,`, `D RR,`, `E SLA,`, `H SRA,`, `L SRL,` are typed, then the correct CB-prefixed opcodes are assembled: CB 07, CB 08, CB 11, CB 1A, CB 23, CB 2C, CB 3D. And `(HL)` forms work: `(HL) RLC,` emits CB 06. And indexed forms work: `(IX) 5 +D RLC,` emits DD CB 05 06.

10. **I/O instructions (register-indirect):** Given a CODE definition, when `(C) A IN,` (IN A, (C)) is typed, then ED 78 is assembled. And `A (C) OUT,` (OUT (C), A) emits ED 79. And all 7 registers work for both IN, and OUT, via (C).

11. **I/O instructions (immediate port):** Given a CODE definition, when `0x42 # A IN,` (IN A, (0x42)) is typed, then DB 42 is assembled. And `A 0x42 # OUT,` (OUT (0x42), A) emits D3 42. And immediate-port I/O is only valid with register A — other registers raise `bad operand ?`.

12. **Block transfer and search (repeat):** Given a CODE definition, when `LDIR,`, `LDDR,`, `CPIR,`, `CPDR,` are typed, then ED B0, ED B8, ED B1, ED B9 are assembled respectively. These are zero-operand words.

13. **Block transfer and search (single):** Given a CODE definition, when `LDI,`, `LDD,`, `CPI,`, `CPD,` are typed, then ED A0, ED A8, ED A1, ED A9 are assembled respectively. These are zero-operand words (single-step equivalents of the repeat variants).

14. **Block I/O (single and repeat):** Given a CODE definition, when `INI,`, `INIR,`, `IND,`, `INDR,`, `OUTI,`, `OTIR,`, `OUTD,`, `OTDR,` are typed, then the correct ED-prefixed opcodes are assembled: INI,=ED A2, INIR,=ED B2, IND,=ED AA, INDR,=ED BA, OUTI,=ED A3, OTIR,=ED B3, OUTD,=ED AB, OTDR,=ED BB. All are zero-operand words.

15. **Miscellaneous ED-prefix instructions:** Given a CODE definition, when `NEG,` is typed, then ED 44 is assembled. And `RETN,` emits ED 45. And `RETI,` emits ED 4D. And `IM0,`, `IM1,`, `IM2,` emit ED 46, ED 56, ED 5E respectively. All are zero-operand words.

16. **EX family:** Given a CODE definition, when `DE HL EX,` is typed, then EB is assembled (EX DE,HL). And `(SP) HL EX,` emits E3 (EX (SP),HL). And `(SP) IX EX,` emits DD E3. And `(SP) IY EX,` emits FD E3. And `AF AF' EX,` emits 08 (EX AF,AF'). And `EXX,` (zero-operand) emits D9.

17. **ALU ops with indexed operands:** Given a CODE definition, when `(IX) 5 +D ADD,` is typed, then DD 86 05 is assembled (ADD A, (IX+5)). And all 6 ALU ops (ADD, SUB, AND, OR, XOR, CP) work with (IX+d) and (IY+d) operands.

18. **JP (IX) / JP (IY):** Given a CODE definition, when `(IX) JP,` is typed, then DD E9 is assembled. And `(IY) JP,` emits FD E9.

19. **Error handling:** All new error paths (range errors for bit numbers and displacements, bad operand combinations, bare integers) print descriptive messages via `asm_print_error`, ABORT cleanly, and `asm_cleanup` rolls back the in-progress CODE word. No orphan entries, no leaked labels.

20. **Full regression:** All existing tests (assembly thread tests via `make test` and REPL tests 1-139 via `make test-repl`) pass unchanged after this story's changes.

## Tasks / Subtasks

### Task 1: Extend tag encoding with IX/IY and (SP) operands (AC: #1, #2, #13)

- [x] 1.1 Add new tag constants to the assembler constants block:
  ```
  ; Reg16 extensions (class REG16 = 0x60)
  ASM_IX_INDEX    EQU 5   ; IX = 0xFF65
  ASM_IY_INDEX    EQU 6   ; IY = 0xFF66
  ASM_AFP_INDEX   EQU 7   ; AF' = 0xFF67

  ; Indirect extensions (class INDIRECT = 0x80)
  ; (HL) = index 0 (existing)
  ASM_IND_IX      EQU 1   ; bare (IX) = 0xFF81
  ASM_IND_IY      EQU 2   ; bare (IY) = 0xFF82
  ASM_IND_IXD     EQU 3   ; (IX+d) = 0xFF83, displacement cell below
  ASM_IND_IYD     EQU 4   ; (IY+d) = 0xFF84, displacement cell below
  ASM_IND_SP      EQU 5   ; (SP) = 0xFF85, for EX (SP),HL/IX/IY
  ```

- [x] 1.2 Define new parsing words — each is a DEFCODE gated by `check_asm_mode`:
  - `IX` → pushes 0xFF65 (reg16, index 5) via `asm_push_reg16_tag` or similar shared tail
  - `IY` → pushes 0xFF66 (reg16, index 6)
  - `AF'` → pushes 0xFF67 (reg16, index 7) — only valid in `EX,`
  - `(IX)` → pushes 0xFF81 (indirect, bare IX)
  - `(IY)` → pushes 0xFF82 (indirect, bare IY)
  - `(SP)` → pushes 0xFF85 (indirect, for EX)
  - `(C)` → pushes a tag for I/O port-indirect (could reuse existing (HL) pattern or new indirect index 6 = 0xFF86)

- [x] 1.3 Define `+D` word (displacement combiner):
  - Gated by `check_asm_mode`
  - Pop TOS = displacement (bare integer, check -128..+127 range)
  - Pop NOS = must be (IX) tag (0xFF81) or (IY) tag (0xFF82)
  - If NOS is (IX): push displacement, then push 0xFF83 (IX+d tag)
  - If NOS is (IY): push displacement, then push 0xFF84 (IY+d tag)
  - If NOS is neither: `bad operand ?` error
  - Range check: displacement must fit signed 8-bit (-128..+127); if not: `range ?`

- [x] 1.4 Add helper routines:
  - `asm_is_ixiy_indexed`: check if TOS tag is 0xFF83 or 0xFF84; returns Z flag + A=index
  - `asm_emit_ixiy_prefix`: given indirect index (3=IX+d, 4=IY+d, or 1=IX, 2=IY), emit 0xDD (IX) or 0xFD (IY) byte at HERE
  - `asm_pop_indexed_disp`: pop the displacement cell below an indexed tag, return in a register

### Task 2: INC, and DEC, words (AC: #3, #4, #5)

- [x] 2.1 Define `w_INC_COMMA` — DEFCODE `"INC,"`:
  - Pop TOS, check it's tagged (asm_check_tagged)
  - Dispatch on class:
    - REG8 (class 0x00): emit `0x04 | (r << 3)` where r = index. Reject r=6 (that's (HL) via the old encoding, but (HL) now has its own class)
    - INDIRECT index=0 (HL): emit `0x34` (INC (HL))
    - INDIRECT index=3 (IX+d): emit DD prefix, emit `0x34`, pop and emit displacement byte
    - INDIRECT index=4 (IY+d): emit FD prefix, emit `0x34`, pop and emit displacement byte
    - REG16 (class 0x60): dispatch on index:
      - 0-3 (BC,DE,HL,SP): emit `0x03 | (rr << 4)` where rr = index (BC=0, DE=1, HL=2, SP=3). Note: AF has no INC form → reject index=3? Wait, AF index is 3 in our encoding. Actually BC=0, DE=1, HL=2, AF=3, SP=4. INC only applies to BC(0),DE(1),HL(2),SP(4). AF has no INC → reject. SP uses rr=3 in the Z80 encoding despite being index 4 in our tag system. Map: tag-index 0→rr0, 1→rr1, 2→rr2, 4→rr3. Tag-index 3 (AF)→ reject.
      - 5 (IX): emit DD, emit `0x23` (INC HL with DD prefix = INC IX)
      - 6 (IY): emit FD, emit `0x23`
    - Anything else: `bad operand ?`

- [x] 2.2 Define `w_DEC_COMMA` — DEFCODE `"DEC,"`:
  - Same dispatch as INC, but:
    - REG8: emit `0x05 | (r << 3)`
    - (HL): emit `0x35`
    - (IX+d): DD 35 dd
    - (IY+d): FD 35 dd
    - REG16: `0x0B | (rr << 4)` for base pairs; DD 2B for IX; FD 2B for IY
    - AF: reject

- [x] 2.3 Factor shared INC/DEC dispatch into a helper `asm_inc_dec_word` parameterised by the base opcode bits, to avoid duplicating the entire dispatch tree.

### Task 3: CB-prefix rotate and shift words (AC: #9)

- [x] 3.1 Define shared helper `asm_cb_shift_word` parameterised by the CB sub-opcode base:
  - Pop TOS, check tagged
  - Dispatch:
    - REG8 (class 0x00): emit CB, emit `base | r` where r=index
    - INDIRECT index=0 (HL): emit CB, emit `base | 0x06`
    - INDIRECT index=3 (IX+d): emit DD CB, pop displacement, emit displacement, emit `base | 0x06`
    - INDIRECT index=4 (IY+d): emit FD CB, pop displacement, emit displacement, emit `base | 0x06`
    - Others: `bad operand ?`
  - **DDCB encoding note:** The Z80 DDCB/FDCB format is: prefix (DD/FD), CB, displacement, opcode. The displacement comes BEFORE the final opcode byte. This is unique to these prefixed CB instructions.

- [x] 3.2 Define 7 DEFCODE words, each calling `asm_cb_shift_word` with the appropriate base:
  - `RLC,` → base = 0x00 (CB 00+r)
  - `RRC,` → base = 0x08 (CB 08+r)
  - `RL,`  → base = 0x10 (CB 10+r)
  - `RR,`  → base = 0x18 (CB 18+r)
  - `SLA,` → base = 0x20 (CB 20+r)
  - `SRA,` → base = 0x28 (CB 28+r)
  - `SRL,` → base = 0x38 (CB 38+r)

### Task 4: CB-prefix bit operation words (AC: #6, #7, #8)

- [x] 4.1 Define shared helper `asm_bit_op_word` parameterised by the CB sub-opcode base:
  - Pop TOS (operand — register, (HL), or indexed tag)
  - Check tagged
  - The bit number is next: pop imm marker, validate it's an immediate, pop bit value
  - Validate bit value 0..7; if outside range: `range ?`
  - Dispatch on operand:
    - REG8: emit CB, emit `base | (bit << 3) | r`
    - (HL): emit CB, emit `base | (bit << 3) | 0x06`
    - (IX+d): pop displacement, emit DD CB displacement `base | (bit << 3) | 0x06`
    - (IY+d): pop displacement, emit FD CB displacement `base | (bit << 3) | 0x06`
    - Others: `bad operand ?`

- [x] 4.2 Define 3 DEFCODE words:
  - `BIT,` → base = 0x40 (CB 40+b*8+r)
  - `RES,` → base = 0x80 (CB 80+b*8+r)
  - `SET,` → base = 0xC0 (CB C0+b*8+r)

### Task 5: I/O instructions (AC: #10, #11)

- [x] 5.1 Define `w_IN_COMMA` — DEFCODE `"IN,"`:
  - Epics-defined operand order: `(C) A IN,` → IN A,(C); `0x42 # A IN,` → IN A,(0x42)
  - At entry: TOS = register tag (A), NOS = port tag or imm marker
  - Dispatch:
    - Pop TOS (register, check tagged). If TOS is REG8:
      - Peek NOS: if (C) tag → pop it, emit ED, emit `0x40 | (r << 3)` (IN r,(C))
      - Peek NOS: if imm marker → pop marker, pop port value, check register is A (index 7). If A: emit DB, emit port byte (IN A,(n)). If not A: `bad operand ?`
    - Others: `bad operand ?`

- [x] 5.2 Define `w_OUT_COMMA` — DEFCODE `"OUT,"`:
  - Epics-defined operand order: `A (C) OUT,` → OUT (C),A; `A 0x42 # OUT,` → OUT (0x42),A
  - At entry: TOS = port tag or imm marker, NOS = register tag (A)
  - Dispatch:
    - Pop TOS (check tagged). If (C) tag:
      - Pop NOS (register, check tagged REG8), emit ED, emit `0x41 | (r << 3)` (OUT (C),r)
    - If TOS is imm marker:
      - Pop marker, pop port value, pop register tag, check register is A. If A: emit D3, emit port byte (OUT (n),A). If not A: `bad operand ?`
    - Others: `bad operand ?`

### Task 6: ED-prefix zero-operand words (AC: #12, #13, #14, #15)

- [x] 6.1 Define block transfer/search words (repeat), each a zero-operand DEFCODE gated by `check_asm_mode`:
  - `LDIR,` → emit ED B0
  - `LDDR,` → emit ED B8
  - `CPIR,` → emit ED B1
  - `CPDR,` → emit ED B9

- [x] 6.2 Define block transfer/search words (single):
  - `LDI,` → emit ED A0
  - `LDD,` → emit ED A8
  - `CPI,` → emit ED A1
  - `CPD,` → emit ED A9

- [x] 6.3 Define block I/O words (single and repeat):
  - `INI,`  → emit ED A2
  - `INIR,` → emit ED B2
  - `IND,`  → emit ED AA
  - `INDR,` → emit ED BA
  - `OUTI,` → emit ED A3
  - `OTIR,` → emit ED B3
  - `OUTD,` → emit ED AB
  - `OTDR,` → emit ED BB

- [x] 6.4 Define miscellaneous ED-prefix words:
  - `NEG,`  → emit ED 44 (negate accumulator)
  - `RETN,` → emit ED 45 (return from NMI)
  - `RETI,` → emit ED 4D (return from maskable interrupt)
  - `IM0,`  → emit ED 46 (interrupt mode 0)
  - `IM1,`  → emit ED 56 (interrupt mode 1)
  - `IM2,`  → emit ED 5E (interrupt mode 2)

- [x] 6.5 Factor all ED-prefix zero-operand words to share a common pattern: `check_asm_mode`, emit 0xED at HERE, emit second byte at HERE+1, advance HERE by 2, NEXT. A macro or shared tail helper keeps the per-word code minimal (load second byte into register, jump to shared emitter).

### Task 7: EX family and EXX (AC: #13)

- [x] 7.1 Define `w_EX_COMMA` — DEFCODE `"EX,"`:
  - Pop TOS and NOS (both must be tagged)
  - Dispatch:
    - NOS=DE, TOS=HL (or vice versa): emit EB (EX DE,HL)
    - NOS=AF, TOS=AF': emit 08 (EX AF,AF')
    - NOS=(SP), TOS=HL: emit E3 (EX (SP),HL)
    - NOS=(SP), TOS=IX (reg16 index 5): emit DD E3 (EX (SP),IX)
    - NOS=(SP), TOS=IY (reg16 index 6): emit FD E3 (EX (SP),IY)
    - Others: `bad operand ?`

- [x] 7.2 Define `w_EXX_COMMA` — DEFCODE `"EXX,"`:
  - Zero-operand, gated by `check_asm_mode`
  - Emit D9

### Task 8: Extend LD, for IX/IY indexed forms (AC: #1, #2)

- [x] 8.1 Add indexed source path to `w_LD_COMMA_cf`:
  - After existing dispatch, check if TOS (source) is an indexed tag (IX+d or IY+d)
  - If indexed source, NOS (after popping displacement) must be REG8 destination
  - Emit DD/FD prefix, emit `0x46 | (dst_r << 3)`, emit displacement
  - LD r,(IX+d) = DD 46|r*8 dd, LD r,(IY+d) = FD 46|r*8 dd

- [x] 8.2 Add indexed destination path:
  - Check if NOS (destination, under TOS source) is an indexed tag
  - If TOS is REG8: LD (IX+d),r = DD 70|r dd
  - If TOS is immediate: LD (IX+d),n = DD 36 dd nn

- [x] 8.3 Add IX/IY 16-bit immediate LD path:
  - In the existing reg16 immediate dispatch, check for IX (index 5) or IY (index 6)
  - IX: emit DD, then emit 0x21 (LD HL,nn encoding), then little-endian value
  - IY: emit FD, then emit 0x21, then little-endian value

- [x] 8.4 Add LD SP,IX and LD SP,IY paths:
  - If dst=SP and src=IX: emit DD F9
  - If dst=SP and src=IY: emit FD F9

### Task 9: Extend ALU ops for indexed operands (AC: #14)

- [x] 9.1 In the shared `asm_arith_word` helper, add an indexed-operand path:
  - After the existing register and immediate checks, check if TOS is an indexed tag
  - If (IX+d): emit DD, pop displacement, emit `base_opcode | 0x06` (the (HL) r-field), emit displacement
  - If (IY+d): emit FD, same pattern
  - This extends ADD,/SUB,/AND,/OR,/XOR,/CP, to support `(IX) 5 +D ADD,` etc.

### Task 10: Extend PUSH,/POP, for IX/IY (AC: #2)

- [x] 10.1 In `asm_pushpop_word` helper, add IX/IY detection:
  - If reg16 index is 5 (IX): emit DD prefix, then emit 0xE5 (PUSH) or 0xE1 (POP)
  - If reg16 index is 6 (IY): emit FD prefix, then emit 0xE5/0xE1
  - All other reg16 indices: existing path (AF: use 0xF5/0xF1; BC/DE/HL/SP: existing encoding)

### Task 11: Extend JP, for JP (IX) / JP (IY) (AC: #15)

- [x] 11.1 In `w_JP_COMMA_cf`, add indirect-IX/IY path:
  - If TOS is bare (IX) tag (0xFF81): pop it, emit DD E9
  - If TOS is bare (IY) tag (0xFF82): pop it, emit FD E9
  - This is "JP (IX)" / "JP (IY)" — the only zero-displacement indirect JP forms

### Task 12: Write REPL tests (AC: #17, all ACs)

- [x] 12.1 Tests for INC,/DEC, (all forms):
  - Test 140: `B INC,` → 04, `A DEC,` → 3D, `(HL) INC,` → 34
  - Test 141: `BC INC,` → 03, `SP DEC,` → 3B
  - Test 142: `IX INC,` → DD 23, `IY DEC,` → FD 2B
  - Test 143: `(IX) 5 +D INC,` → DD 34 05, `(IY) 3 +D DEC,` → FD 35 03

- [x] 12.2 Tests for CB-prefix rotate/shift:
  - Test 144: `A RLC,` → CB 07, `B RRC,` → CB 08, `L SRL,` → CB 3D
  - Test 145: `(HL) RLC,` → CB 06, `(HL) SRA,` → CB 2E
  - Test 146: `(IX) 5 +D RLC,` → DD CB 05 06 (verify DDCB displacement-before-opcode encoding)

- [x] 12.3 Tests for BIT/SET/RES:
  - Test 147: `3 # A BIT,` → CB 5F, `5 # B SET,` → CB E8, `7 # C RES,` → CB B9
  - Test 148: `3 # (HL) BIT,` → CB 5E
  - Test 149: `3 # (IX) 5 +D BIT,` → DD CB 05 5E (DDCB indexed bit test)
  - Test 150: bit number 8 → `range ?` error, clean recovery

- [x] 12.4 Tests for I/O:
  - Test 151: `(C) A IN,` → ED 78, `A (C) OUT,` → ED 79
  - Test 152: `0x42 # A IN,` → DB 42, `A 0x42 # OUT,` → D3 42
  - Test 153: `(C) B IN,` → ED 40 (non-A register IN)
  - Test 154: `0x42 # B IN,` → `bad operand ?` (immediate-port IN only valid for A)

- [x] 12.5 Tests for block transfer (repeat):
  - Test 155: `LDIR,` → ED B0, `LDDR,` → ED B8, `CPIR,` → ED B1, `CPDR,` → ED B9

- [x] 12.5b Tests for block transfer (single):
  - Test 156: `LDI,` → ED A0, `LDD,` → ED A8, `CPI,` → ED A1, `CPD,` → ED A9

- [x] 12.5c Tests for block I/O:
  - Test 157: `INI,` → ED A2, `INIR,` → ED B2, `IND,` → ED AA, `INDR,` → ED BA
  - Test 158: `OUTI,` → ED A3, `OTIR,` → ED B3, `OUTD,` → ED AB, `OTDR,` → ED BB

- [x] 12.5d Tests for misc ED-prefix:
  - Test 159: `NEG,` → ED 44, `RETN,` → ED 45, `RETI,` → ED 4D
  - Test 160: `IM0,` → ED 46, `IM1,` → ED 56, `IM2,` → ED 5E

- [x] 12.6 Tests for EX/EXX:
  - Test 161: `DE HL EX,` → EB, `EXX,` → D9
  - Test 162: `(SP) HL EX,` → E3, `(SP) IX EX,` → DD E3
  - Test 163: `AF AF' EX,` → 08

- [x] 12.7 Tests for IX/IY LD forms:
  - Test 164: `(IX) 5 +D A LD,` → DD 7E 05, `A (IX) 5 +D LD,` → DD 77 05
  - Test 165: `IX 0x1234 # LD,` → DD 21 34 12, `IY 0x5678 # LD,` → FD 21 78 56
  - Test 166: `(IX) 5 +D 42 # LD,` → DD 36 05 2A (indexed immediate store)

- [x] 12.8 Tests for IX/IY PUSH/POP and JP:
  - Test 167: `IX PUSH,` → DD E5, `IY POP,` → FD E1
  - Test 168: `(IX) JP,` → DD E9, `(IY) JP,` → FD E9

- [x] 12.9 Tests for ALU ops with indexed operands:
  - Test 169: `(IX) 5 +D ADD,` → DD 86 05, `(IY) 3 +D CP,` → FD BE 03

- [x] 12.10 Tests for error cases:
  - Test 170: `+D` with bare integer (not (IX)/(IY)) → `bad operand ?`
  - Test 171: `(IX) 200 +D A LD,` → `range ?` (displacement out of range)
  - Test 172: `AF INC,` → `bad operand ?` (no INC AF instruction)

- [x] 12.11 Regression tests:
  - Test 173: Run a sampling of existing assembler patterns to confirm nothing broke (register LD, immediate LD, JP with labels, JR conditional, arith ops)

### Task 13: Full regression pass (AC: #17)

- [x] 13.1 Run `make test` — all assembly thread tests must pass with unchanged EXPECTED string
- [x] 13.2 Run `make test-repl` — all existing REPL tests (1-139) must pass unchanged
- [x] 13.3 New REPL tests (140-173) all pass

## Dev Notes

### Tag Encoding Extensions

The unified tag encoding from story 4.3.5 (high byte = 0xFF, low byte = class:3 | index:5) is extended with new entries in existing classes:

```
Class 011 (0x60) REG16 — extended:
  Index 0: BC  (existing)
  Index 1: DE  (existing)
  Index 2: HL  (existing)
  Index 3: AF  (existing)
  Index 4: SP  (existing)
  Index 5: IX  (NEW) → 0xFF65
  Index 6: IY  (NEW) → 0xFF66
  Index 7: AF' (NEW) → 0xFF67

Class 100 (0x80) INDIRECT — extended:
  Index 0: (HL)  (existing) — single cell, no displacement
  Index 1: (IX)  (NEW) — single cell, bare (for JP (IX) only)
  Index 2: (IY)  (NEW) — single cell, bare (for JP (IY) only)
  Index 3: (IX+d)(NEW) — TWO cells: displacement below, tag on TOS
  Index 4: (IY+d)(NEW) — TWO cells: displacement below, tag on TOS
  Index 5: (SP)  (NEW) — single cell (for EX (SP),r only)
  Index 6: (C)   (NEW) — single cell (for IN/OUT port-indirect only)
```

The two-cell layout for indexed operands follows the same pattern as immediates:
```
Stack after (IX) 5 +D:  ... | 5 | 0xFF83 |
                               ^     ^
                            signed   IX+d tag
                            disp
```

### DD/FD Prefix Strategy

All IX-prefixed Z80 instructions are the HL-equivalent instruction with a 0xDD prefix byte. All IY-prefixed instructions use 0xFD. This means:

- Helper `asm_emit_ixiy_prefix` takes the indirect index (1/3 for IX, 2/4 for IY) or reg16 index (5 for IX, 6 for IY) and emits the correct prefix byte
- After the prefix, the opcode byte uses the HL encoding (r-field 4/5 for H/L, rr-field 2 for HL, etc.)
- For DDCB/FDCB: prefix + CB + displacement + opcode (displacement comes before final opcode byte — unique Z80 quirk)

### DDCB/FDCB Encoding Quirk

The Z80's DDCB and FDCB prefix sequences have an unusual byte order:
```
DD CB dd oo    (IX-indexed CB instruction)
FD CB dd oo    (IY-indexed CB instruction)
```
Where `dd` is the signed displacement byte and `oo` is the CB-family opcode. The displacement comes BEFORE the opcode byte — this is different from DD-prefix non-CB instructions where the displacement comes AFTER the opcode.

This affects `asm_cb_shift_word` and `asm_bit_op_word`: when they detect an indexed operand, they must emit prefix+CB first, then displacement, then opcode. Non-indexed paths emit CB then opcode with no displacement.

### INC,/DEC, Operand Dispatch

INC, and DEC, are the only Z80 instructions that accept both 8-bit registers AND 16-bit register pairs with different encodings:
- INC B = 0x04 | (r<<3) — uses 8-bit r-field encoding
- INC BC = 0x03 | (rr<<4) — uses 16-bit rr-field encoding

The dispatch must check the tag class first: REG8 → 8-bit path, REG16 → 16-bit path, INDIRECT → (HL) or indexed path.

**Register pair index mapping for INC/DEC:** Our reg16 tag indices don't map 1:1 to Z80 rr fields:
| Tag index | Register | Z80 rr field |
|-----------|----------|-------------|
| 0         | BC       | 0           |
| 1         | DE       | 1           |
| 2         | HL       | 2           |
| 3         | AF       | INVALID     |
| 4         | SP       | 3           |
| 5         | IX       | (DD prefix + HL encoding) |
| 6         | IY       | (FD prefix + HL encoding) |

For tag index 4 (SP), the Z80 rr field is 3 (not 4). The mapping is: if index <= 2, rr = index; if index == 4, rr = 3; if index == 3 (AF), reject. If index == 5/6, emit DD/FD prefix and use rr = 2 (HL encoding).

### I/O Operand Order

The epics define I/O operand order as follows:
```
(C) A IN,     → IN A, (C)     TOS=A(reg), NOS=(C)
A (C) OUT,    → OUT (C), A    TOS=(C), NOS=A(reg)
0x42 # A IN,  → IN A, (0x42)  TOS=A(reg), NOS=imm-marker, NNOS=0x42
A 0x42 # OUT, → OUT (0x42), A TOS=imm-marker, NOS=0x42, NNOS=A(reg)
```

**Note:** This does NOT follow the same dst-src convention as LD,. For LD, TOS=source and NOS=destination. For IN,/OUT,, the convention matches the Zilog mnemonic argument order read left-to-right. Follow the epics specification exactly.

### Existing Helpers to Reuse (from stories 4.1-4.3.5)

Key helpers already in `src/assembler.asm` that this story builds on:

- `check_asm_mode` (~line 860): gates all assembler words, errors `not in CODE ?` if asm_mode=0
- `asm_push_tag` (~line 870): shared tail for 8-bit reg words — sets B=0xFF, C=L, pushes BC as new TOS
- `asm_push_cond_tag` (~line 993): shared tail for condition code words
- `asm_push_label_tag` (~line 1197): shared tail for label words
- `asm_check_tagged` (~line 1053): pop TOS, verify B==0xFF, else `bare integer ?` error
- `asm_get_class` (~line 1074): returns class bits (C AND 0xE0) in A
- `asm_get_index` (~line 1079): returns index bits (C AND 0x1F) in A
- `asm_is_imm_tag` (~line 1084): Z flag set if TOS class == IMM (0x40)
- `asm_is_cond_tag` (~line 1089): Z flag set if TOS class == COND (0x20)
- `asm_is_label_tag` (~line 1094): Z flag set if TOS class == LABEL (0xA0)
- `asm_is_reg16_tag` (~line 1099): Z flag set if TOS class == REG16 (0x60)
- `asm_is_indirect_tag` (~line 1104): Z flag set if TOS class == INDIRECT (0x80)
- `asm_arith_word` (~line 1450): shared dispatch for ADD,/SUB,/AND,/OR,/XOR,/CP, — parameterised by base opcode
- `asm_pushpop_word` (~line 1257): shared dispatch for PUSH,/POP, — parameterised by base opcode
- `assert_8bit_reg` / `assert_8bit_reg_or_ihl`: validate reg8 operand (reject r>=8 / allow (HL) r=6)
- `asm_bad_operand` / `asm_print_error` / `asm_cleanup`: error handling chain

New helpers needed for this story: `asm_emit_ixiy_prefix`, `asm_pop_indexed_disp`, `asm_cb_shift_word`, `asm_bit_op_word`, `asm_inc_dec_word`, `asm_emit_ed_byte` (shared emitter for zero-operand ED words).

### Key Architecture Constraints

- **Register contract (inviolable):** BC=TOS, DE=IP, SP=parameter stack, IX=return stack, IY=user pointer, HL=working register
- **Operand order:** Zilog dst-src convention for LD, and most ops; I/O follows epics-specified order (see above)
- **Direct threading:** Every word's code field is a literal `JP xxxx` (3 bytes)
- **Error handling:** All assembler errors flow through `asm_print_error` + `asm_cleanup` (restore HERE, unlink labels, reset mode)
- **Naming:** `w_` prefix for Forth word bodies, `h_` for headers, `UPPER_SNAKE_CASE` for constants
- **Testing:** REPL-piped Forth scripts (Epic 3+ convention), not assembly test thread extensions
- **All new DEFCODE words** must follow the pattern: `w_NAME:` label, `DEFCODE "name", 0`, `w_NAME_cf:` EQU label

### Previous Story Intelligence (4.3 + 4.3.5)

- Story 4.3 established: `#` immediate marker, condition codes (NZ/Z/NC/CS/PO/PE/P/M), conditional JP/CALL/JR/RET, immediate ALU ops, (HL) indirect loads
- Story 4.3.5 unified tag encoding: all tags use 0xFF high byte with class:3|index:5 low byte. Added `asm_check_tagged` bare-integer detection, `asm_get_class`/`asm_get_index` helpers, class-based dispatch throughout
- Key lesson from 4.3.5: don't share scratch slots across nesting boundaries (hence `asm_jp_op` separate from `asm_tmp`)
- `assert_8bit_reg_or_ihl` allows r=6 (HL) — used in LD, paths that accept (HL) operand
- Current assembler.asm is 2128 lines; this story will add significant code (estimate ~500-800 lines)

### Project Structure Notes

- All assembler code lives in `src/assembler.asm` (single file, included from main kernel via `src/antforth.asm`)
- Tests are REPL-piped Forth scripts defined in the `Makefile` `test-repl` target
- Last existing REPL test is test 139 (from story 4.3.5)
- Architecture doc at `_bmad-output/planning-artifacts/architecture.md` — update the tag encoding section with new class entries
- No project-context.md exists

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.4] — Acceptance criteria and background
- [Source: _bmad-output/planning-artifacts/architecture.md] — Register contract, naming conventions, tag encoding, error handling patterns
- [Source: _bmad-output/implementation-artifacts/4-3-basic-z80-opcodes.md] — Previous story tasks, dev notes, patterns established
- [Source: _bmad-output/implementation-artifacts/4-3-5-stack-tag-encoding-refactor.md] — Unified tag encoding, bare-integer detection, helper routines
- [Source: src/assembler.asm] — Current implementation (2128 lines), all tag constants, helpers, and opcode words
- [Source: docs/z80_forth_assemblers.md] — Survey of Z80 Forth assemblers for design patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed asm_emit_byte HL clobbering: values saved in H across emit_byte calls were destroyed (CB-shift r-field, OUT r-field)
- Fixed asm_pop_indexed_disp: return address management when popping from Forth param stack inside a CALL'd routine
- Fixed indexed LD operand convention: AC defines indexed operand position opposite to register LD convention (TOS=indexed→destination, NOS=indexed→source)
- Fixed Makefile test line length: 8+ C@ inspections exceeded terminal buffer, split across multiple input lines

### Completion Notes List

- Task 1: Added 10 new tag constants (ASM_IX_INDEX through ASM_IND_C), 7 new parsing words (IX, IY, AF', (IX), (IY), (SP), (C)), +D displacement combiner with range validation, and 3 helper routines (asm_is_ixiy_indexed, asm_emit_ixiy_prefix, asm_pop_indexed_disp)
- Task 2: INC,/DEC, with shared asm_inc_dec_word dispatcher handling REG8, REG16 (including IX/IY via DD/FD prefix), INDIRECT (HL), and indexed (IX+d)/(IY+d) operands
- Task 3: 7 CB-prefix rotate/shift words (RLC, RRC, RL, RR, SLA, SRA, SRL) with shared asm_cb_shift_word helper supporting REG8, (HL), and DDCB/FDCB indexed forms
- Task 4: 3 CB-prefix bit operation words (BIT, SET, RES) with shared asm_bit_op_word helper, bit range validation (0..7), and DDCB/FDCB indexed forms
- Task 5: IN,/OUT, with register-indirect (C) and immediate port forms, A-only restriction for immediate port I/O
- Task 6: 22 ED-prefix zero-operand words with shared asm_emit_ed_op emitter (block transfer, block I/O, NEG, RETN, RETI, IM0/1/2)
- Task 7: EX, (DE↔HL, AF↔AF', (SP)↔HL/IX/IY) and EXX, zero-operand word
- Task 8: Extended LD, for IX/IY indexed source/destination, IX/IY 16-bit immediate, LD SP,IX/IY, and LD (IX+d),n immediate store
- Task 9: Extended asm_arith_word for (HL) and indexed operands (all 6 ALU ops)
- Task 10: Extended asm_pushpop_word for IX/IY via DD/FD prefix
- Task 11: Extended JP, for JP (IX) / JP (IY) indirect forms
- Task 12: 34 new REPL tests (140-173) covering all new instruction forms and error cases
- Task 13: Full regression pass — all assembly thread tests and 173 REPL tests pass

### Change Log

- 2026-04-12: Implemented all 13 tasks for Story 4.4 (extended Z80 opcodes). Added ~600 lines to assembler.asm and 34 new REPL tests to Makefile.
- 2026-04-12: Code review fixes — Fixed bug in +D where negative displacements (B=0xFF) were rejected as tags. Added 5 new REPL tests (174-178): FDCB shift, FDCB bit op, negative displacement, boundary displacements, expanded regression. Fixed misleading comment at asm_bit_op_word. Added architecture.md to File List.

### File List

- src/assembler.asm — Extended with IX/IY/SP/C tag encoding, +D combiner, INC/DEC, rotate/shift, bit ops, I/O, block transfer, EX/EXX, and extensions to LD/ALU/PUSH/POP/JP words
- Makefile — Added REPL tests 140-178
- _bmad-output/planning-artifacts/architecture.md — Updated tag encoding table with IX/IY/AF' reg16 entries and new indirect class entries
- _bmad-output/implementation-artifacts/sprint-status.yaml — Status updated to review
- _bmad-output/implementation-artifacts/4-4-extended-z80-opcodes.md — Story file updated