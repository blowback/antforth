# Story 5.0: Z80 Instruction Set Completeness Survey

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth assembler user,
I want a systematic audit of every documented Z80 opcode against the antforth assembler,
so that I know exactly which instructions are supported, which are missing, and the antforth syntax for each.

## Acceptance Criteria

1. **Given** the complete Z80 instruction set as documented in the Zilog Z80 CPU User Manual **When** each instruction is checked against the antforth assembler's available words **Then** a report is produced listing every Z80 opcode, whether it can be assembled, and the exact antforth syntax

2. **Given** the report is complete **When** reviewed **Then** it covers ALL instruction categories: 8-bit loads, 16-bit loads, 8-bit arithmetic/logic, 16-bit arithmetic, rotates/shifts, bit operations, jumps, calls/returns, I/O, block transfers, exchange, general-purpose AF ops, and miscellaneous (ED-prefix)

3. **Given** any gaps are identified **When** the report is reviewed by the project lead **Then** each gap includes the Z80 mnemonic, opcode bytes, and a note classifying it as: (a) deliberate omission, (b) oversight, or (c) expressible via existing words (workaround documented)

4. **Given** the report **When** reviewed **Then** it includes a summary with total instruction count, supported count, missing count, and a percentage coverage figure

5. **Given** every instruction marked "supported" **When** verified **Then** the antforth syntax shown in the report actually assembles the correct bytes (spot-check against known opcodes, not exhaustive re-testing of the full 178-test REPL suite)

## Tasks / Subtasks

- [ ] Task 1: Establish the authoritative Z80 instruction set reference (AC: #1, #2)
  - [ ] 1.1 Use the Zilog Z80 CPU User Manual instruction tables as the canonical source
  - [ ] 1.2 Enumerate every instruction category and count total unique instructions per category
  - [ ] 1.3 Include all prefix classes: unprefixed, CB-prefixed, DD-prefixed, FD-prefixed, ED-prefixed, DDCB-prefixed, FDCB-prefixed

- [ ] Task 2: Audit unprefixed instructions (AC: #1, #2, #5)
  - [ ] 2.1 8-bit load group: LD r,r' / LD r,n / LD r,(HL) / LD (HL),r / LD (HL),n / LD A,(BC) / LD A,(DE) / LD (BC),A / LD (DE),A / LD A,(nn) / LD (nn),A
  - [ ] 2.2 16-bit load group: LD rr,nn / LD HL,(nn) / LD (nn),HL / LD SP,HL / PUSH rr / POP rr
  - [ ] 2.3 8-bit arithmetic/logic: ADD/ADC/SUB/SBC/AND/XOR/OR/CP with r/(HL)/n operands
  - [ ] 2.4 16-bit arithmetic: ADD HL,rr / INC rr / DEC rr
  - [ ] 2.5 8-bit INC/DEC: INC r / DEC r / INC (HL) / DEC (HL)
  - [ ] 2.6 General-purpose AF: DAA / CPL / SCF / CCF / RLCA / RRCA / RLA / RRA
  - [ ] 2.7 Control: NOP / HALT / DI / EI / JP / JR / CALL / RET / RST / DJNZ
  - [ ] 2.8 Exchange: EX DE,HL / EX AF,AF' / EX (SP),HL / EXX

- [ ] Task 3: Audit CB-prefixed instructions (AC: #1, #2, #5)
  - [ ] 3.1 Rotate/shift: RLC/RRC/RL/RR/SLA/SRA/SRL with r/(HL) operands
  - [ ] 3.2 Bit operations: BIT/RES/SET with bit 0-7 and r/(HL) operands

- [ ] Task 4: Audit DD/FD-prefixed instructions (IX/IY) (AC: #1, #2, #5)
  - [ ] 4.1 Indexed loads: LD r,(IX+d) / LD (IX+d),r / LD (IX+d),n (and IY equivalents)
  - [ ] 4.2 Indexed arithmetic: ADD/ADC/SUB/SBC/AND/XOR/OR/CP A,(IX+d) (and IY)
  - [ ] 4.3 Indexed INC/DEC: INC (IX+d) / DEC (IX+d) (and IY)
  - [ ] 4.4 16-bit IX/IY ops: ADD IX,rr / LD IX,nn / LD IX,(nn) / LD (nn),IX / INC IX / DEC IX / PUSH IX / POP IX / JP (IX) / EX (SP),IX (and IY)
  - [ ] 4.5 DDCB/FDCB indexed bit ops: RLC/RRC/RL/RR/SLA/SRA/SRL (IX+d) / BIT/RES/SET b,(IX+d) (and IY)

- [ ] Task 5: Audit ED-prefixed instructions (AC: #1, #2, #5)
  - [ ] 5.1 Block transfer: LDI/LDIR/LDD/LDDR
  - [ ] 5.2 Block search: CPI/CPIR/CPD/CPDR
  - [ ] 5.3 Block I/O: INI/INIR/IND/INDR/OUTI/OTIR/OUTD/OTDR
  - [ ] 5.4 16-bit arithmetic: ADC HL,rr / SBC HL,rr
  - [ ] 5.5 16-bit load: LD (nn),rr / LD rr,(nn) (for BC/DE/SP — HL uses unprefixed form)
  - [ ] 5.6 Interrupt/special: IM 0/1/2 / RETI / RETN / NEG / RLD / RRD / LD A,I / LD A,R / LD I,A / LD R,A
  - [ ] 5.7 I/O: IN r,(C) / OUT (C),r / IN A,(n) / OUT (n),A

- [ ] Task 6: Compile the report (AC: #1, #2, #3, #4, #5)
  - [ ] 6.1 Create report document at `docs/z80-instruction-coverage.md`
  - [ ] 6.2 For each instruction: Z80 mnemonic, opcode bytes, antforth syntax (if supported), status (supported/missing/workaround)
  - [ ] 6.3 For each gap: classify as deliberate omission, oversight, or workaround-available
  - [ ] 6.4 Summary section with total/supported/missing counts and percentage
  - [ ] 6.5 Spot-check a selection of supported instructions by assembling them in a CODE word and verifying bytes with C@

- [ ] Task 7: Verify no regressions (AC: #5)
  - [ ] 7.1 `make test` — all 73 regression tests pass
  - [ ] 7.2 `make test-repl` — all 178 REPL tests pass
  - [ ] 7.3 No source code changes expected (this is an audit story)

## Dev Notes

### This Is an Audit/Report Story

This story produces a **report document only** — no assembler code changes. If gaps are found, they are documented but NOT implemented. The project lead will decide later which gaps (if any) to address.

The output is a markdown document at `docs/z80-instruction-coverage.md`.

### What Already Exists (verified from source)

**Assembler words defined in `src/assembler.asm` (90 DEFCODE entries):**

**Operands (30 words):**
- 8-bit registers: `B C D E H L A`
- 16-bit registers: `BC DE HL AF SP IX IY AF'`
- Indirect modes: `(HL) (IX) (IY) (SP) (C)`
- Condition codes: `NZ Z NC CS PO PE P M`
- Markers: `#` (immediate), `+D` (displacement)

**Infrastructure (4 words):**
- `CODE END-CODE LABEL FIX`

**Opcode words (34 words):**
- Data movement: `LD, PUSH, POP,`
- Arithmetic/logic: `ADD, SUB, AND, XOR, OR, CP, INC, DEC,`
- Rotate/shift: `RLC, RRC, RL, RR, SLA, SRA, SRL,`
- Bit operations: `BIT, RES, SET,`
- Control flow: `JP, JR, CALL, RET, NEXT,`
- I/O: `IN, OUT,`
- Exchange: `EX, EXX,`

**Zero-operand ED-prefix (22 words):**
- Block transfer: `LDI, LDIR, LDD, LDDR,`
- Block search: `CPI, CPIR, CPD, CPDR,`
- Block I/O: `INI, INIR, IND, INDR, OUTI, OTIR, OUTD, OTDR,`
- Misc: `NEG, RETN, RETI, IM0, IM1, IM2,`

**Data definition (4 words):**
- `DB, DW, DS, EQU`

### Known Potential Gaps to Investigate

The following Z80 instructions are NOT obviously covered by the existing word set and need verification:

1. **DAA** (Decimal Adjust Accumulator) — no `DAA,` word visible
2. **CPL** (Complement Accumulator) — no `CPL,` word visible
3. **SCF** (Set Carry Flag) — no `SCF,` word visible
4. **CCF** (Complement Carry Flag) — no `CCF,` word visible
5. **NOP** — no `NOP,` word visible
6. **HALT** — no `HALT,` word visible
7. **DI** (Disable Interrupts) — no `DI,` word visible
8. **EI** (Enable Interrupts) — no `EI,` word visible
9. **RLCA/RRCA/RLA/RRA** — accumulator-specific rotates (distinct from CB-prefixed `RLC, A` etc.)
10. **RST n** — restart instructions (RST 0x00 through RST 0x38)
11. **DJNZ** — decrement B and jump if not zero
12. **ADC HL,rr** / **SBC HL,rr** — 16-bit arithmetic with carry (ED-prefix)
13. **LD (nn),rr** / **LD rr,(nn)** — ED-prefix 16-bit memory loads for BC/DE/SP
14. **RLD/RRD** — rotate digit left/right (ED-prefix BCD ops)
15. **LD A,I** / **LD A,R** / **LD I,A** / **LD R,A** — interrupt vector and refresh register loads
16. **ADC A,r** / **SBC A,r** — arithmetic with carry (8-bit) — check if `ADD,` handles carry variants
17. **LD (HL),n** — immediate store to indirect (may already be covered by `LD,` dispatch)
18. **LD HL,(nn)** / **LD (nn),HL** — check if covered by existing `LD,` 16-bit paths
19. **LD SP,HL** — check if covered
20. **ADD HL,rr** — 16-bit addition (check if `ADD,` handles 16-bit pairs)

### Operand Order Convention

Antforth uses **Zilog dst-src order uniformly**: `B C LD,` means `LD B, C`. This applies to all forms including immediates: `A 0x42 # LD,` means `LD A, 0x42`.

### Tag Encoding Reference

All operands use unified `0xFF` high byte with class/index low byte:
- Class 000: 8-bit registers (B=0..A=7)
- Class 001: Condition codes (NZ=0..M=7)
- Class 010: Immediate marker
- Class 011: 16-bit registers (BC=0..AF'=7)
- Class 100: Indirect/indexed ((HL)=0..(C)=6)
- Class 101: Labels (slot 0..15)

Bare integers (high byte != 0xFF) are rejected with `bare integer ?` error.

### Report Format

The report should use a table format per category:

```markdown
## 8-bit Load Group

| Z80 Mnemonic | Opcode | Antforth Syntax | Status |
|-------------|--------|-----------------|--------|
| LD B, C     | 0x41   | `B C LD,`       | Supported |
| LD A, (nn)  | 0x3A   | —               | Missing (oversight) |
```

With a summary at the top:
```markdown
## Summary
- Total Z80 instructions: XXX
- Supported: XXX (XX%)
- Missing: XXX
- Workaround available: XXX
```

### Spot-Check Method

To verify that a reported syntax actually assembles correctly:
```forth
CODE TEST  <instruction>  END-CODE
' TEST >BODY C@  \ read first assembled byte
```

Use `>BODY` (if available) or `' TEST` + offset to get to the code field and read bytes with `C@`. The exact offset depends on dictionary entry format — code field is at name + 3 bytes (JP instruction), and the actual machine code follows.

Actually, the simplest approach: `HERE` before and after assembling, then use `C@` to read the bytes between.

### Anti-Patterns to Avoid

1. **Do NOT implement missing instructions** — this is audit only, report gaps for project lead decision
2. **Do NOT modify `src/assembler.asm`** — no source changes in this story
3. **Do NOT add new REPL tests** — existing 178 tests are the regression baseline; this story adds no new functionality
4. **Do NOT guess about coverage** — verify each instruction by checking the assembler source or testing interactively
5. **Do NOT count operand variants as separate instructions** — e.g., `LD B,C` and `LD B,D` are both covered by `LD,` with register operands; count `LD r,r'` once
6. **Do NOT use `CS` where Zilog says `C`** without noting the naming departure — the report should document that antforth uses `CS` for carry-set condition (6502-style) instead of Zilog's `C`

### Previous Story Intelligence (from Story 4.4)

Story 4.4 was the last implementation story. Key learnings relevant to this audit:
- DDCB/FDCB encoding has unusual byte order: `DD CB dd oo` (displacement before opcode)
- I/O instructions don't follow dst-src convention — they match Zilog mnemonic order
- Some Z80 instructions have no direct antforth word but may be expressible via `DB,` (e.g., `0xED DB, 0x67 DB,` for RLD)
- The `LD,` dispatcher handles ~15 encoding variants but may not cover all Z80 LD forms
- `ADD,` may only handle 8-bit forms — 16-bit `ADD HL,rr` and `ADC HL,rr` / `SBC HL,rr` need checking

### Git Intelligence

Recent commits follow one-commit-per-story pattern:
```
3b48731 commit orphans
21c8d05 add examples
7f516da completed story 4.4
55ee9e3 completed story 4.3.5
32cd2d7 completed story 4.3
```

### Testing Strategy

**This story has no new tests.** The deliverable is a report document. Verification consists of:
1. `make test` — 73 regression tests still pass (no source changes)
2. `make test-repl` — 178 REPL tests still pass (no source changes)
3. Spot-check a handful of "supported" instructions interactively to confirm the report is accurate

### References

- [Source: src/assembler.asm] — Complete assembler implementation (3,373+ lines, 90 DEFCODE words)
- [Source: docs/z80_forth_assemblers.md] — Prior art survey of Z80 Forth assemblers
- [Source: _bmad-output/planning-artifacts/architecture.md#Assembler Tag-Cell Encoding] — Tag encoding reference
- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.0] — Story requirements
- [Reference: Zilog Z80 CPU User Manual] — Authoritative instruction set reference
- [Memory: feedback_assembler_operand_order.md] — Zilog dst-src order convention
- [Memory: feedback_systematic_reference_check.md] — Systematic reference cross-check (this story IS that checklist)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Agent report on unprefixed instructions initially claimed LD A,(BC)/LD A,(DE)/LD (BC),A/LD (DE),A/LD A,(nn)/LD (nn),A and ADD HL,rr were supported — manual verification against assembler.asm opcode emission proved they are NOT supported. The agent confused internal Z80 instructions used by the assembler code with instructions the assembler can produce for the user.

### Completion Notes List

- Audited 158 Z80 instruction forms across all prefix classes (unprefixed, CB, DD, FD, ED, DDCB, FDCB)
- Found 131 supported (82.9%) and 27 missing
- Report saved to `docs/z80-instruction-coverage.md`
- All 73 regression tests + 178 REPL tests pass (no source changes made)
- Missing instructions grouped into clear categories for project lead review
- All missing instructions have `DB,` workarounds documented

### Change Log

- 2026-04-12: Z80 instruction set completeness survey completed — report at docs/z80-instruction-coverage.md

### File List

- docs/z80-instruction-coverage.md — Survey report (new)
