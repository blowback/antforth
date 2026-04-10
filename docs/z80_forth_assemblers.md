# Z80 Forth Implementations with Built-in Assemblers

A reference guide for the antforth development team covering historical and modern Z80 Forth
systems that included a genuine built-in assembler — one that runs *inside* the Forth environment
and generates opcodes directly into the dictionary, rather than relying on an external tool.

---

## The Key Distinction

Not all Z80 Forths that support `CODE` words have a built-in assembler. There is an important
spectrum:

- **Genuine built-in assembler**: `CODE` is followed by postfix mnemonic words (e.g. `H POP`,
  `D DAD`) that are themselves Forth words generating opcodes directly into dictionary memory.
  The assembler lives entirely within the Forth system.
- **External assembler hook only**: `CODE` creates a dictionary entry, but opcode generation
  is left to an external assembler or raw hex bytes. CamelForth/Z80 is the canonical example
  of this pattern.

The distinction matters for self-hosted systems: only the first category allows you to write
new `CODE`-level primitives from within the running Forth itself.

---

## Systems with a Genuine Built-in Z80 Assembler

### 1. fig-FORTH for Z80 (1980, FIG)

The canonical historical reference. The fig-FORTH installation model specified a built-in
assembler as a standard component, and the Z80 port implemented it.

**Assembler model**: Postfix, in the Forth style. Register names and conditions are Forth
constants; instruction mnemonics are Forth words that consume operands from the stack and emit
opcodes to the dictionary.

**Syntax example**:
```
CODE FOO ( n1 n2 -- n3 )
  H POP       \ pop TOS into HL
  D POP       \ pop NOS into DE
  D DAD       \ HL = HL + DE
  H PUSH      \ push result
  PCIX        \ jump to NEXT (return to Forth inner interpreter)
C;
```

**Coverage**: Based on the 8080 instruction set with Z80-specific extensions. Not a complete
Z80 assembler — the Z80-only instructions (bit ops, relative jumps, IX/IY addressing) were
partially covered depending on the port.

**Register constraints**: BC must be preserved across CODE words; IX and IY are reserved for
the inner interpreter and must not be touched.

**References**: William Ragsdale, *fig-FORTH Installation Manual* (FIG, 1980); the
`dimitrit/figforth` CP/M implementation on GitHub preserves this assembler faithfully.

---

### 2. MMSForth (Miller Microcomputer Services, early 1980s)

A commercial Z80 Forth product and probably the most complete Forth-integrated Z80 assembler
of the era. Ran on CP/M and bare Z80 hardware.

**Assembler model**: Postfix, Forth-like notation. Register names are stack constants;
instruction words (suffixed with `,`) pop operands and emit opcodes.

**Syntax example**:
```
A B LD,       \ ld a, b
A 42 LD#,     \ ld a, 42   (# suffix for immediate operands)
```

The `#` suffix convention solves a real problem: without it, a register constant and an
immediate integer are indistinguishable on the stack.

**Coverage**: Full Z80 instruction set. MMSForth's own documentation quantifies the complexity
cost: the 8080 assembler required ~1.2 KB; the full Z80 assembler required ~3.5 KB — nearly
3× larger, reflecting the IX/IY displacement modes, bit instructions, block instructions, and
extended opcode prefixes that the Z80 added over the 8080.

**Significance**: MMSForth's assembler design became an influential reference point. Modern
self-hosted Z80 Forths (e.g. Leah Ulmschneider's, described below) explicitly cite MMSForth
as the design inspiration for their postfix assembler notation.

---

### 3. PolyFORTH (Forth Inc., Z80/CP/M)

The commercial professional-grade Forth from Forth Inc., ported to Z80 under CP/M. PolyFORTH
was a full Forth-79 / Forth-83 class system and included assembler support as a standard
component.

**Coverage**: Varied by version; Z80-specific instruction coverage beyond the 8080 baseline
depended on the specific release. Sources are proprietary so full details are not publicly
documented.

**Notes**: PolyFORTH was used for serious production work on Z80 hardware. It is distinct from
the open fig-FORTH lineage and was a paid product; copies survive on physical media but are not
freely redistributable.

---

### 4. CollapseOS (2019–present)

A modern Z80 Forth designed for post-collapse computing on salvaged hardware. Takes the
self-hosting question seriously as a primary design goal, so the assembler is a first-class
concern.

**Assembler model**: Forth-integrated, self-hosting. The assembler is itself written in Forth
words and is capable of assembling itself from source.

**Resource envelope**: The complete system — Forth kernel, assembler, and tooling — fits in
approximately 5 KB ROM plus 8 KB RAM, sufficient to run on an RC2014 or similar minimal Z80
hardware. The assembler supports forward labels, includes, and other directives within that
footprint.

**Significance**: Demonstrates that a reasonably featured Z80 assembler (not just raw opcode
emission) can be implemented in Forth within tight constraints. The Collapse OS design essay
("Why Forth?") is worth reading for its analysis of why a Forth-integrated assembler achieves
parity with a standalone Z80 assembler in resource cost while gaining extensibility.

**Repository**: https://collapseos.org

---

### 5. Leah Ulmschneider's Self-Hosted Z80 Forth (modern hobbyist)

A contemporary self-hosted Z80 Forth for a custom Z80 computer (the ZI-28), documented in
detail. Notable for the explicit engineering discussion of what a complete Z80 assembler
in Forth actually requires.

**Assembler model**: Postfix, MMSForth-inspired notation. Full Z80 coverage.

**Key engineering observations**:
- The Z80 `LD` instruction alone has approximately 15 encoding variants, not counting immediate
  forms — this is the single most complex instruction to dispatch correctly.
- The `#` suffix convention (borrowed from MMSForth) is necessary because register identifiers
  and immediate integers are both plain integers on the stack; without a syntactic marker the
  assembler cannot distinguish `LD A,B` from `LD A,42`.
- A test harness using `T{`, `->`, `}T` words was built to verify opcode output for every
  instruction, because the complexity of the Z80 encoding table makes manual verification
  unreliable.
- The full Z80 assembler required approximately 3.5 KB — consistent with the MMSForth figure,
  suggesting this is close to the minimum for full coverage.

**Reference**: https://ulmschneider.ch/projects/forth/

---

## Notable Counterexample: CamelForth/Z80

CamelForth/Z80 (Brad Rodriguez, 1994/1995) is an ANSI-compliant Z80 Forth and an excellent
reference implementation, but it does **not** include a built-in assembler. It was assembled
using Z80MR (a CP/M macro assembler) as an external tool. `CODE` words can be added, but
opcode generation must be done externally or by emitting raw bytes manually.

This is worth noting because CamelForth is frequently cited as a Z80 Forth reference — its
DTC model, register assignments, and kernel structure are well documented — but it does not
demonstrate the assembler-in-Forth pattern.

---

## The Z80 Assembler Complexity Problem

All Z80 Forths with built-in assemblers had to solve the same problem: the Z80 instruction set
is substantially more complex to encode than its 8080 ancestor, and the standard Forth postfix
assembler model (where each mnemonic is a Forth word) must dispatch correctly across a large
and irregular opcode table.

The main sources of complexity:

| Problem | Notes |
|---|---|
| `LD` variants | ~15 register-to-register forms + immediate variants; single mnemonic, many encodings |
| IX/IY displacement | `(IX+d)` addressing adds a prefix byte (`0xDD`/`0xFD`) plus displacement byte |
| Extended opcodes | `CB`, `DD`, `ED`, `FD` prefix families each add a second dispatch table |
| Bit instructions | `BIT`, `SET`, `RES`, `RLC` etc. are all in the `CB`-prefixed space |
| Relative jumps | `JR` has a limited range; assembler must compute signed 8-bit displacement |
| Register constants vs. immediates | On a Forth stack, a register code and a small integer are identical — syntax must disambiguate |

The 3× size difference between an 8080 Forth assembler (~1.2 KB) and a full Z80 Forth
assembler (~3.5 KB) maps almost entirely to these Z80 additions.

---

## Design Patterns Across Implementations

**Postfix notation is universal.** Every built-in Z80 Forth assembler uses postfix: operands
are pushed as constants, the instruction word pops them and emits opcodes. This is natural
because the assembler words are just Forth words.

**Immediate vs. register disambiguation.** Two approaches were used:
- Suffix convention: `LD,` for register-to-register, `LD#,` for immediate (MMSForth style)
- Separate word per form: `LDA,` vs. `LDAI,` etc.

The suffix approach is more systematic; the separate-word approach is easier to implement but
produces a larger vocabulary.

**Termination word.** All fig-FORTH lineage systems use `C;` (or equivalent) to close a `CODE`
definition and return to Forth compilation mode. The word also typically emits a `JP (HL)` or
equivalent to hook back into the inner interpreter's NEXT.

**Register reservation.** Every system reserves certain registers for the inner interpreter
and documents which registers are safe to use in `CODE` words. In fig-FORTH for Z80, BC, IX,
and IY are reserved. In other DTC implementations, the specifics vary but the pattern is
consistent.

---

## Summary Table

| System | Era | Assembler Built-in | Coverage | Notes |
|---|---|---|---|---|
| fig-FORTH Z80 | 1980 | Yes | 8080 + partial Z80 | FIG standard model; postfix `CODE`/`C;` |
| MMSForth | ~1982 | Yes | Full Z80 | Most complete; ~3.5 KB; commercial |
| PolyFORTH Z80 | ~1982 | Yes | Z80 (varies) | Commercial; proprietary sources |
| CamelForth Z80 | 1994 | No | n/a | External assembler only; excellent DTC reference |
| CollapseOS | 2019+ | Yes | Full Z80 | Self-hosting; ~5 KB total system |
| Ulmschneider's Forth | ~2022 | Yes | Full Z80 | MMSForth-inspired; well-documented design |

---

*Compiled for the antforth development team. Primary sources: FIG Z80 installation manual;
MMSForth documentation; Brad Rodriguez's "Moving Forth" series; CollapseOS design notes;
Leah Ulmschneider's project writeup.*
