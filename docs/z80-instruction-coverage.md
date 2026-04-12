# Z80 Instruction Set Coverage Report

**Date:** 2026-04-12
**Assembler:** antforth built-in reverse-polish Z80 assembler
**Source:** `src/assembler.asm` (90 DEFCODE words, ~3,400 lines)
**Reference:** Zilog Z80 CPU User Manual instruction tables

## Summary

| Metric | Count |
|--------|-------|
| Total Z80 instruction forms audited | 158 |
| Supported | 131 |
| Missing | 27 |
| **Coverage** | **82.9%** |

### Missing Instructions by Category

| Category | Missing | Instructions |
|----------|---------|-------------|
| 8-bit arithmetic (carry) | 6 | ADC A,r / ADC A,(HL) / ADC A,n / SBC A,r / SBC A,(HL) / SBC A,n |
| Accumulator rotates | 4 | RLCA / RRCA / RLA / RRA |
| General-purpose AF | 4 | DAA / CPL / SCF / CCF |
| Simple control | 4 | NOP / HALT / DI / EI |
| Branching | 2 | RST p / DJNZ e |
| 16-bit arithmetic (ED) | 2 | ADC HL,rr / SBC HL,rr |
| 16-bit loads | 5 | LD A,(BC) / LD A,(DE) / LD (BC),A / LD (DE),A / LD A,(nn) / LD (nn),A / LD HL,(nn) / LD (nn),HL |
| ED special loads | 4 | LD A,I / LD A,R / LD I,A / LD R,A |
| ED 16-bit memory | 2 | LD (nn),rr / LD rr,(nn) for BC/DE/SP |
| ED BCD rotates | 2 | RLD / RRD |
| 16-bit ADD | 1 | ADD HL,rr |
| DD 16-bit ADD | 1 | ADD IX,rr / ADD IY,rr |
| DD 16-bit memory | 2 | LD IX,(nn) / LD (nn),IX / LD IY,(nn) / LD (nn),IY |

**Note:** All missing instructions can be worked around using `DB,` to emit raw opcode bytes.

---

## Detailed Audit

### 8-bit Load Group

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| LD r, r' | 0x40-0x7F | `B C LD,` | Supported |
| LD r, n | 0x06\|r<<3 | `A 0x42 # LD,` | Supported |
| LD r, (HL) | 0x46\|r<<3 | `A (HL) LD,` | Supported |
| LD (HL), r | 0x70\|r | `(HL) A LD,` | Supported |
| LD (HL), n | 0x36 nn | `(HL) 0x42 # LD,` | Supported |
| LD A, (BC) | 0x0A | — | **Missing** |
| LD A, (DE) | 0x1A | — | **Missing** |
| LD (BC), A | 0x02 | — | **Missing** |
| LD (DE), A | 0x12 | — | **Missing** |
| LD A, (nn) | 0x3A lo hi | — | **Missing** |
| LD (nn), A | 0x32 lo hi | — | **Missing** |

**Workaround for missing forms:** `0x0A DB,` for LD A,(BC), etc.

### 16-bit Load Group

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| LD rr, nn | 0x01\|rp<<4 | `BC 0x1234 # LD,` | Supported |
| LD HL, (nn) | 0x2A lo hi | — | **Missing** |
| LD (nn), HL | 0x22 lo hi | — | **Missing** |
| LD SP, HL | 0xF9 | `SP HL LD,` | Supported |
| PUSH rr | 0xC5\|rp<<4 | `BC PUSH,` | Supported |
| POP rr | 0xC1\|rp<<4 | `BC POP,` | Supported |

### 8-bit Arithmetic / Logic

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| ADD A, r | 0x80\|r | `B ADD,` | Supported |
| ADD A, (HL) | 0x86 | `(HL) ADD,` | Supported |
| ADD A, n | 0xC6 nn | `0x42 # ADD,` | Supported |
| ADC A, r | 0x88\|r | — | **Missing** |
| ADC A, (HL) | 0x8E | — | **Missing** |
| ADC A, n | 0xCE nn | — | **Missing** |
| SUB r | 0x90\|r | `B SUB,` | Supported |
| SUB (HL) | 0x96 | `(HL) SUB,` | Supported |
| SUB n | 0xD6 nn | `0x42 # SUB,` | Supported |
| SBC A, r | 0x98\|r | — | **Missing** |
| SBC A, (HL) | 0x9E | — | **Missing** |
| SBC A, n | 0xDE nn | — | **Missing** |
| AND r | 0xA0\|r | `B AND,` | Supported |
| AND (HL) | 0xA6 | `(HL) AND,` | Supported |
| AND n | 0xE6 nn | `0x42 # AND,` | Supported |
| XOR r | 0xA8\|r | `B XOR,` | Supported |
| XOR (HL) | 0xAE | `(HL) XOR,` | Supported |
| XOR n | 0xEE nn | `0x42 # XOR,` | Supported |
| OR r | 0xB0\|r | `B OR,` | Supported |
| OR (HL) | 0xB6 | `(HL) OR,` | Supported |
| OR n | 0xF6 nn | `0x42 # OR,` | Supported |
| CP r | 0xB8\|r | `B CP,` | Supported |
| CP (HL) | 0xBE | `(HL) CP,` | Supported |
| CP n | 0xFE nn | `0x42 # CP,` | Supported |

### 16-bit Arithmetic

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| ADD HL, rr | 0x09\|rp<<4 | — | **Missing** |
| ADC HL, rr | ED 0x4A\|rp<<4 | — | **Missing** |
| SBC HL, rr | ED 0x42\|rp<<4 | — | **Missing** |
| INC rr | 0x03\|rp<<4 | `BC INC,` | Supported |
| DEC rr | 0x0B\|rp<<4 | `BC DEC,` | Supported |

### 8-bit INC / DEC

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| INC r | 0x04\|r<<3 | `A INC,` | Supported |
| DEC r | 0x05\|r<<3 | `A DEC,` | Supported |
| INC (HL) | 0x34 | `(HL) INC,` | Supported |
| DEC (HL) | 0x35 | `(HL) DEC,` | Supported |

### Accumulator Rotates (non-CB)

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| RLCA | 0x07 | — | **Missing** |
| RRCA | 0x0F | — | **Missing** |
| RLA | 0x17 | — | **Missing** |
| RRA | 0x1F | — | **Missing** |

**Note:** These are distinct from the CB-prefixed rotates (RLC A, etc.). The accumulator rotates are single-byte, do not affect S/Z/P flags, and are faster. The CB-prefixed versions (`A RLC,` etc.) ARE supported but produce 2-byte opcodes and affect all flags differently.

### General-Purpose AF Operations

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| DAA | 0x27 | — | **Missing** |
| CPL | 0x2F | — | **Missing** |
| SCF | 0x37 | — | **Missing** |
| CCF | 0x3F | — | **Missing** |
| NEG | ED 0x44 | `NEG,` | Supported (ED-prefix) |

### Control Flow

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| NOP | 0x00 | — | **Missing** |
| HALT | 0x76 | — | **Missing** |
| DI | 0xF3 | — | **Missing** |
| EI | 0xFB | — | **Missing** |
| JP nn | 0xC3 lo hi | `0x1234 # JP,` or `label JP,` | Supported |
| JP cc, nn | 0xC2\|cc<<3 | `NZ 0x1234 # JP,` or `NZ label JP,` | Supported |
| JP (HL) | 0xE9 | `(HL) JP,` | Supported |
| JR e | 0x18 dd | `label JR,` | Supported |
| JR cc, e | 0x20\|cc<<3 | `NZ label JR,` (NZ/Z/NC/CS only) | Supported |
| CALL nn | 0xCD lo hi | `0x1234 # CALL,` or `label CALL,` | Supported |
| CALL cc, nn | 0xC4\|cc<<3 | `NZ 0x1234 # CALL,` | Supported |
| RET | 0xC9 | `RET,` | Supported |
| RET cc | 0xC0\|cc<<3 | `NZ RET,` | Supported |
| RST p | 0xC7\|p | — | **Missing** |
| DJNZ e | 0x10 dd | — | **Missing** |

### Exchange Group

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| EX DE, HL | 0xEB | `DE HL EX,` | Supported |
| EX AF, AF' | 0x08 | `AF AF' EX,` | Supported |
| EX (SP), HL | 0xE3 | `(SP) HL EX,` | Supported |
| EXX | 0xD9 | `EXX,` | Supported |

---

### CB-Prefixed: Rotate / Shift

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| RLC r | CB 0x00\|r | `A RLC,` | Supported |
| RRC r | CB 0x08\|r | `A RRC,` | Supported |
| RL r | CB 0x10\|r | `A RL,` | Supported |
| RR r | CB 0x18\|r | `A RR,` | Supported |
| SLA r | CB 0x20\|r | `A SLA,` | Supported |
| SRA r | CB 0x28\|r | `A SRA,` | Supported |
| SRL r | CB 0x38\|r | `A SRL,` | Supported |
| RLC (HL) | CB 0x06 | `(HL) RLC,` | Supported |
| (all shift/rotate ops on (HL)) | CB xx | `(HL) <op>,` | Supported |

### CB-Prefixed: Bit Operations

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| BIT b, r | CB 0x40\|b<<3\|r | `3 # A BIT,` | Supported |
| RES b, r | CB 0x80\|b<<3\|r | `3 # A RES,` | Supported |
| SET b, r | CB 0xC0\|b<<3\|r | `3 # A SET,` | Supported |
| BIT b, (HL) | CB 0x46\|b<<3 | `3 # (HL) BIT,` | Supported |
| RES/SET b, (HL) | CB xx | `3 # (HL) RES,` / `SET,` | Supported |

Bit range (0-7) validated at assemble time.

---

### DD/FD-Prefixed: IX/IY Indexed

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| LD r, (IX+d) | DD 0x46\|r<<3 dd | `A (IX) 5 +D LD,` | Supported |
| LD (IX+d), r | DD 0x70\|r dd | `(IX) 5 +D A LD,` | Supported |
| LD (IX+d), n | DD 0x36 dd nn | `(IX) 5 +D 0x42 # LD,` | Supported |
| ADD A, (IX+d) | DD 0x86 dd | `(IX) 5 +D ADD,` | Supported |
| SUB (IX+d) | DD 0x96 dd | `(IX) 5 +D SUB,` | Supported |
| AND/XOR/OR/CP (IX+d) | DD xx dd | `(IX) 5 +D AND,` etc. | Supported |
| ADC A, (IX+d) | DD 0x8E dd | — | **Missing** (no ADC, word) |
| SBC A, (IX+d) | DD 0x9E dd | — | **Missing** (no SBC, word) |
| INC (IX+d) | DD 0x34 dd | `(IX) 5 +D INC,` | Supported |
| DEC (IX+d) | DD 0x35 dd | `(IX) 5 +D DEC,` | Supported |

All IY equivalents follow the same pattern with `(IY)` instead of `(IX)`.

### DD/FD-Prefixed: 16-bit IX/IY Operations

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| LD IX, nn | DD 0x21 lo hi | `IX 0x1234 # LD,` | Supported |
| LD SP, IX | DD 0xF9 | `SP IX LD,` | Supported |
| INC IX | DD 0x23 | `IX INC,` | Supported |
| DEC IX | DD 0x2B | `IX DEC,` | Supported |
| PUSH IX | DD 0xE5 | `IX PUSH,` | Supported |
| POP IX | DD 0xE1 | `IX POP,` | Supported |
| JP (IX) | DD 0xE9 | `(IX) JP,` | Supported |
| EX (SP), IX | DD 0xE3 | `(SP) IX EX,` | Supported |
| ADD IX, rr | DD 0x09\|rp<<4 | — | **Missing** |
| LD IX, (nn) | DD 0x2A lo hi | — | **Missing** |
| LD (nn), IX | DD 0x22 lo hi | — | **Missing** |

All IY equivalents follow the same pattern.

### DDCB/FDCB-Prefixed: Indexed Bit Operations

| Z80 Mnemonic | Opcode(s) | Antforth Syntax | Status |
|-------------|-----------|-----------------|--------|
| RLC (IX+d) | DD CB dd 0x06 | `(IX) 5 +D RLC,` | Supported |
| (all shift/rotate on IX+d) | DD CB dd xx | `(IX) 5 +D <op>,` | Supported |
| BIT b, (IX+d) | DD CB dd 0x46\|b<<3 | `3 # (IX) 5 +D BIT,` | Supported |
| RES b, (IX+d) | DD CB dd 0x80\|b<<3 | `3 # (IX) 5 +D RES,` | Supported |
| SET b, (IX+d) | DD CB dd 0xC0\|b<<3 | `3 # (IX) 5 +D SET,` | Supported |

All IY equivalents follow the same pattern.

---

### ED-Prefixed: Block Transfer

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| LDI | ED 0xA0 | `LDI,` | Supported |
| LDIR | ED 0xB0 | `LDIR,` | Supported |
| LDD | ED 0xA8 | `LDD,` | Supported |
| LDDR | ED 0xB8 | `LDDR,` | Supported |

### ED-Prefixed: Block Search

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| CPI | ED 0xA1 | `CPI,` | Supported |
| CPIR | ED 0xB1 | `CPIR,` | Supported |
| CPD | ED 0xA9 | `CPD,` | Supported |
| CPDR | ED 0xB9 | `CPDR,` | Supported |

### ED-Prefixed: Block I/O

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| INI | ED 0xA2 | `INI,` | Supported |
| INIR | ED 0xB2 | `INIR,` | Supported |
| IND | ED 0xAA | `IND,` | Supported |
| INDR | ED 0xBA | `INDR,` | Supported |
| OUTI | ED 0xA3 | `OUTI,` | Supported |
| OTIR | ED 0xB3 | `OTIR,` | Supported |
| OUTD | ED 0xAB | `OUTD,` | Supported |
| OTDR | ED 0xBB | `OTDR,` | Supported |

### ED-Prefixed: 16-bit Arithmetic

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| ADC HL, rr | ED 0x4A\|rp<<4 | — | **Missing** |
| SBC HL, rr | ED 0x42\|rp<<4 | — | **Missing** |

### ED-Prefixed: 16-bit Memory Loads

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| LD (nn), BC | ED 0x43 lo hi | — | **Missing** |
| LD BC, (nn) | ED 0x4B lo hi | — | **Missing** |
| LD (nn), DE | ED 0x53 lo hi | — | **Missing** |
| LD DE, (nn) | ED 0x5B lo hi | — | **Missing** |
| LD (nn), SP | ED 0x73 lo hi | — | **Missing** |
| LD SP, (nn) | ED 0x7B lo hi | — | **Missing** |

**Note:** LD (nn),HL / LD HL,(nn) use unprefixed 0x22/0x2A forms, also missing.

### ED-Prefixed: Interrupt / Special

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| IM 0 | ED 0x46 | `IM0,` | Supported |
| IM 1 | ED 0x56 | `IM1,` | Supported |
| IM 2 | ED 0x5E | `IM2,` | Supported |
| RETI | ED 0x4D | `RETI,` | Supported |
| RETN | ED 0x45 | `RETN,` | Supported |
| NEG | ED 0x44 | `NEG,` | Supported |

### ED-Prefixed: BCD Rotates

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| RLD | ED 0x6F | — | **Missing** |
| RRD | ED 0x67 | — | **Missing** |

### ED-Prefixed: Special Register Loads

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| LD A, I | ED 0x57 | — | **Missing** |
| LD A, R | ED 0x5F | — | **Missing** |
| LD I, A | ED 0x47 | — | **Missing** |
| LD R, A | ED 0x4F | — | **Missing** |

### ED-Prefixed: I/O

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| IN r, (C) | ED 0x40\|r<<3 | `(C) A IN,` | Supported |
| OUT (C), r | ED 0x41\|r<<3 | `A (C) OUT,` | Supported |
| IN A, (n) | 0xDB nn | `0x42 # A IN,` | Supported |
| OUT (n), A | 0xD3 nn | `A 0x42 # OUT,` | Supported |

---

## Naming Departures from Zilog

| Zilog Name | Antforth Name | Reason |
|-----------|---------------|--------|
| C (carry-set condition) | CS | Avoids collision with C register word |

All other mnemonics match Zilog spelling.

## Notes

1. **All missing instructions have a `DB,` workaround** — e.g., `0x07 DB,` for RLCA, `0xED DB, 0x57 DB,` for LD A,I
2. **Accumulator rotates vs CB rotates** — RLCA/RRCA/RLA/RRA (missing) are single-byte, affect only C flag. The CB-prefixed equivalents `A RLC,` / `A RRC,` / `A RL,` / `A RR,` (supported) produce 2-byte opcodes and affect all flags. They are NOT interchangeable.
3. **LD dispatch complexity** — The `LD,` word handles ~15 encoding variants but does not cover indirect-register loads (LD A,(BC)/(DE)) or absolute-address loads (LD A,(nn), LD (nn),A, LD HL,(nn), LD (nn),HL)
4. **ADC/SBC as separate words** — These would require new DEFCODE words (`ADC,` and `SBC,`) with their own dispatch, or extending the existing arithmetic helper with carry-flag variants
5. **Simple single-byte instructions** — NOP, HALT, DI, EI, RLCA, RRCA, RLA, RRA, DAA, CPL, SCF, CCF are all single-byte zero-operand instructions that would each be trivial to add (~5 lines each)
