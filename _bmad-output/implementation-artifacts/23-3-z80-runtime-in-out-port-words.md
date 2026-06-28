# Story 23.3: Z80 runtime `IN` / `OUT` port words

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-28 by create-story workflow (context-engine pass).
     Story 23.3 is the third story of Epic 23 (Phase 5 — standards & I/O
     polish, → antforth v3.1.0). Deliverable: two tiny runtime CODE words —
     `IN ( port -- byte )` and `OUT ( x port -- )` — that expose raw Z80 I/O
     ports at the REPL. antforth extensions (not ANS), flagged per CCD-3.

     FIVE load-bearing findings were resolved at DRAFT TIME by reading live
     source (B.4 / PD-2 figure-drift discipline). Do NOT re-discover them at
     dev-pass:

       (1) TOS-IN-REGISTER MAKES THIS ALMOST FREE — `IN A,(C)`/`OUT (C),A`
           USE BC AS THE 16-BIT PORT, AND BC IS ALREADY TOS.
           antforth keeps TOS in BC (project_tos_in_register;
           src/memory.asm:43-97 `@`/`!`/`C@`/`C!` are the model). The Z80
           register-indirect I/O instructions take the FULL 16-bit port in BC
           (B → A8..A15, C → A0..A7):
             • `IN A,(C)`  = ED 78  — read port BC into A.
             • `OUT (C),A` = ED 79  — write A to port BC.
           So for `IN`, the port is ALREADY in BC = TOS; the result byte
           replaces it. For `OUT`, the port is in BC = TOS and the datum is
           NOS on the machine stack — exactly the `!` shape. No EXX, no BDOS,
           no shadow set: these never touch the alt registers (S7 = N/A,
           record it explicitly). The 16-bit-port-in-B requirement of AC1 is
           satisfied for free because BC (not just C) is the port.

       (2) ZERO-EXTENSION IS THE `C@` PATTERN, NOT A NEW IDIOM.
           `IN`'s result is one byte that must become a clean cell. Copy
           `C@`'s tail verbatim (src/memory.asm:75-82): `LD C,A` / `LD B,0`.
           B=0 makes AC1's "zero-extended to a cell" true by construction —
           the high byte of the returned cell is provably 0 regardless of the
           byte read. This is also what makes the AC4 probe assertion
           (`<port> IN 0x100 U<` → true) robust to whatever the live port
           value is.

       (3) UNDERFLOW GUARDS: `IN` → `check_underflow`, `OUT` →
           `check_underflow_2`. USE THE CALL FORM, NOT A HAND-ROLLED CHECK.
           `IN` needs 1 cell, `OUT` needs 2 (src/system.asm:584-621). Both
           helpers PRESERVE BC/DE/IX/IY/SP and clobber only AF/HL, so the
           `CALL check_underflow*` sits at the very top of the cf, before BC
           (the port) is touched — identical placement to `@`
           (src/memory.asm:46) and `!` (src/memory.asm:61). AC5 names this
           explicitly. NOTE: `C@`/`C!` are slightly inconsistent in the
           kernel (`C@` at :75 omits the check; `C!` at :91 has it) — do NOT
           copy `C@`'s omission; AC5 REQUIRES the guard on both `IN` and `OUT`.

       (4) ASSEMBLER `IN,`/`OUT,` ARE DISTINCT TOKENS — NO COLLISION, BUT
           VERIFY NO PRIOR `IN`/`OUT` WORD EXISTS.
           The inline assembler defines `IN,` (src/assembler.asm:3328-3330)
           and `OUT,` (:3389-3391) — names carry the trailing comma, so FIND
           treats `IN`/`OUT` (this story) and `IN,`/`OUT,` as different words
           (AC6). Confirmed at draft time: grep for `DEFCODE "IN"` / `"OUT"`
           (no comma) returns NOTHING — no pre-existing runtime `IN`/`OUT` to
           clash with. The assembler emits the SAME opcodes this story's
           runtime words use, which is the right mnemonic cross-check:
             • `IN,`  emits ED 78 (`IN A,(C)`) / DB nn (`IN A,(n)`)
               — assembler.asm:3381.
             • `OUT,` emits ED 79 (`OUT (C),A`) / D3 nn (`OUT (n),A`)
               — assembler.asm:3418/3436.
           The runtime `IN`/`OUT` use only the register-indirect ED 78 / ED 79
           forms (the port is a runtime value in BC, never an immediate).

       (5) PROBE-PORT SAFETY IS THE ONLY REAL RISK — MMU/BANKING PORTS
           (0x70-0x74) ARE OFF-LIMITS FOR `OUT`.
           Ports 0x70-0x73 are the MMU page registers (write-only; reads =
           open bus) and 0x74 is the MMU-mapping-enable (bit 0); writing any
           of them desyncs the BIOS MMU shadow or disconnects RAM
           (src/banking.asm:36-51; memory project_div1_mmu_port_readback,
           project_phase4_banking_off_emulator). The kernel itself only ever
           touches these via the BIOS MBB_* routines, never raw OUT/IN.
           Therefore:
             • `IN` READ target for the automated probe: **0x72** — READING it
               is side-effect-free (a read never remaps), and the
               iz-cpm-banking emulator models it deterministically (returns
               bank_map[2] for any read; tools/mmu_probe/mmu_probe.asm). At the
               antforth REPL, MMU mapping is always enabled (COLD does
               `OUT (0x74),1`), so 0x72 is live and readable. The probe asserts
               ZERO-EXTENSION (`0x72 IN 0x100 U<` → true), which is robust to
               the actual page value — it does NOT assert a specific byte.
             • `OUT` WRITE target: INERT ≠ LATCHING — an inert port does not
               store the byte, so a write→read-back of the same value against an
               inert port is a contradiction (resolved with Ant 2026-06-28).
               Therefore the automated probe does NOT attempt a value round-trip:
               it asserts `OUT` EXECUTES WITHOUT THROW and CONSUMES EXACTLY TWO
               CELLS, writing to a port that is undecoded (inert) on both
               iz-cpm-banking (unmodeled writes are silent no-ops) and the
               MicroBeast (recommended target 0xFE — confirm undecoded at
               dev-pass / HW-smoke). A genuine write→read-back round-trip would
               require a real *latching* peripheral (a non-inert device); that is
               an OPTIONAL S9 hardware-smoke activity at the operator's
               discretion, not part of automated acceptance.
-->

## Story

As a MicroBeast hacker,
I want built-in `IN` and `OUT` words,
so that I can read and poke raw Z80 I/O ports straight from the REPL without
dropping into a hand-assembled CODE word every time.

## Acceptance Criteria

1. **`IN ( port -- byte )` reads one byte via `IN A,(C)` with `BC = port`.** The
   full 16-bit port address is honoured (high byte in `B`, low in `C` — the
   register-indirect form puts B on A8..A15). The result byte is zero-extended
   to a cell (high byte provably `0`). antforth extension (not ANS).
2. **`OUT ( x port -- )` writes the low byte of `x` via `OUT (C),A` with
   `BC = port`.** Stack order matches `!` — datum (`x`) below address (`port`).
   `OUT` consumes both cells and pushes nothing. antforth extension (not ANS).
3. **Both flagged `; antforth extension` per CCD-3** with a one-line hardware-I/O
   design note at each word (the *why*, no provenance —
   `feedback_source_comment_discipline`).
4. **Automated REPL-piped probe exercises both words against documented inert
   ports — NO value round-trip is asserted on the automated gate** (an inert
   port does not latch, by definition, so a write→read-back of the same value is
   impossible against one). Specifically: `IN` reads a side-effect-free port
   (recommended `0x72`, the slot-2 MMU page register — reads never remap; modeled
   by iz-cpm-banking) and asserts zero-extension (`<port> IN 0x100 U<` → true).
   `OUT` writes a byte to a port confirmed inert on iz-cpm-banking + MicroBeast
   and asserts it completes without THROW and leaves the stack two cells
   shallower. The probe DOCUMENTS which ports it targets and why they are inert.
   (Any genuine write→read-back round-trip requires a real *latching* peripheral
   — i.e. a non-inert device — and is an optional S9 hardware-smoke activity, at
   the operator's discretion and risk; it is NOT part of this story's automated
   acceptance.)
5. **Stack-depth underflow guarded.** `IN` calls `check_underflow` (needs 1),
   `OUT` calls `check_underflow_2` (needs 2), at the top of the code field before
   `BC` is consumed — per the existing `@`/`!` discipline. `IN` on an empty
   stack and `OUT` with fewer than 2 cells each raise `-4` (stack underflow).
6. **No collision with the assembler's `IN,` / `OUT,`.** `IN`/`OUT` (this story)
   and `IN,`/`OUT,` (`src/assembler.asm`) are distinct dictionary entries
   (names differ by the trailing comma); both remain usable. Confirmed no
   pre-existing runtime `IN`/`OUT` word is redefined.
7. **Docs reconciled.** `docs/ans-forth-core-compliance.md` gains rows recording
   `IN`/`OUT` as antforth extensions (non-ANS, so flagged as extension rows, not
   `§`-numbered Core rows). `docs/z80-instruction-coverage.md` updated if it
   tracks the runtime I/O words. CCD-3 extension flagging present in source.
8. **No regression.** Full `make test-repl` (iz-cpm) holds at the 975-PASS
   baseline; `test-repl-asm`, `test-repl-value-to`, `test-repl-banking`,
   `test-straddle-regression`, and the new `IN`/`OUT` probe all green;
   `make check-doc-sync` 0-drift. Binary delta recorded and itemised at close.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev
      Notes.
  - Confirmed live committed baseline = **28816 B** (`git diff --stat` shows
    `src/`, `Makefile`, `docs/`, `tests/` all clean, so the working-tree build
    IS committed source). The 28809 B in 23.2's close was a slightly earlier
    artifact; 28816 is the true pre-edit baseline for this story.
- [x] Capture current `make test-repl` baseline (975/0) and
      `test-repl-banking` count (62/0) — both confirmed green pre-edit.

### Story tasks

- [x] Task 1 — Implement `IN` runtime word (AC: 1, 3, 5)
  - [x] Add `w_IN` / `w_IN_cf` (`DEFCODE "IN", 0`) in `src/io.asm` under a new
        section header `Z80 hardware port I/O (antforth extensions)`. Home-file
        decision: **`src/io.asm`** (lowest ceremony — no new file in the
        `antforth.asm` INCLUDE list / no Makefile OBJ edit; io.asm already owns
        the I/O primitives). See Project Structure Notes for the rationale.
  - [x] Body: `CALL check_underflow` (preserves BC=port); `IN A,(C)` (ED 78,
        reads port BC into A); `LD C,A` / `LD B,0` (zero-extend — the `C@`
        tail, src/memory.asm:80-81); `NEXT`. No EXX/BDOS (S7 = N/A).
  - [x] Add the `; antforth extension — raw Z80 port read; BC=port (B=A8..A15)`
        why-comment (CCD-3, no provenance).

- [x] Task 2 — Implement `OUT` runtime word (AC: 2, 3, 5)
  - [x] Add `w_OUT` / `w_OUT_cf` (`DEFCODE "OUT", 0`) adjacent to `IN` in
        `src/io.asm`.
  - [x] Body (the `!` shape, src/memory.asm:58-69): `CALL check_underflow_2`
        (preserves BC=port); `POP HL` (HL = x = NOS); `LD A,L` (low byte of x);
        `OUT (C),A` (ED 79, writes A to port BC); `POP BC` (new TOS — `OUT`
        consumed both x and port); `NEXT`.
  - [x] Add the `; antforth extension — raw Z80 port write; ( x port -- ),
        datum below address like !` why-comment (CCD-3).

- [x] Task 3 — Author the REPL-piped probe (AC: 4, 5, 6)
  - [x] Create `tests/in_out_tests.fth` (self-printing PASS/FAIL probe). Cover:
    - [x] **IN zero-extension** — `72 IN 100 U<` (HEX) → assert true
          (`PASS: io-in-zero-extend`). Documents in a comment: 0x72 = slot-2
          MMU page register; reads are side-effect-free; modeled by
          iz-cpm-banking; MMU mapping is on at the REPL.
    - [x] **OUT executes + stack effect** — `DEPTH >R 0 FE OUT DEPTH R> =`
          (0xFE = inert/undecoded target — confirmed iz-cpm silently no-ops
          unmodeled writes), assert `DEPTH` unchanged (2 pushed, 2 consumed) and
          no THROW (`PASS: io-out-no-throw`). No value read-back — inert ≠ latch.
    - [x] **IN underflow** — `IN` on an empty stack raises `-4`, UNCAUGHT at the
          probe tail so the REPL prints `error -4: stack underflow`. Uncaught
          chosen (per Story 23.1's caught-path-residue gotcha): the second tail
          throw needs a clean stack, and uncaught also exercises the user-facing
          message row. No residue question to resolve since nothing is caught.
    - [x] **OUT underflow** — `0 OUT` (one cell) raises `-4` (uncaught tail).
    - [x] **Distinctness (AC6)** — `' IN DROP ' IN, DROP ' OUT DROP ' OUT, DROP`
          at INTERPRET level (tick parses from the input buffer, so it must NOT
          be inside a colon body — that throws -13 at runtime with no input;
          discovered at dev-pass). A miss on any of the four throws -13 before
          the verdict, so reaching `PASS: io-distinct-words` proves all four
          resolve as distinct entries. Doubles as the word-existence pre-flight.
  - [x] Word-existence pre-flight (the distinctness line, run first) + TIB-128
        line lint (longest probe line = 100 chars). Verdict greps COLUMN-0-
        ANCHORED (`^PASS:` / `^FAIL:` / `^error -4`) to dodge the echoed-source
        false-green that bit 23.2 (the comment quoting `error -4` is mid-line,
        not col 0, so the anchored count stays exactly 2).
  - [x] Wire a `make` target `test-repl-in-out` mirroring `test-repl-value-to`:
        `IN_OUT_PROBE = tests/in_out_tests.fth`, added to `.PHONY`, run under
        `$(IZCPM) $(IZCPM_DISKS)`.

- [x] Task 4 — Docs + CCD-3 flagging (AC: 3, 7)
  - [x] `docs/ans-forth-core-compliance.md`: added `IN` (`io.asm:199`) and `OUT`
        (`io.asm:213`) as **antforth-extension** rows in the "Non-standard words
        (not in Core or Core Extension)" table (NOT `§`-numbered Core rows).
        Notes record raw Z80 port I/O, BC=port, zero-extended read / low-byte
        write, distinctness from `IN,`/`OUT,`, and underflow → -4.
  - [x] `docs/z80-instruction-coverage.md`: **no edit** — it is the inline-
        *assembler* instruction-coverage report (Instruction | Opcode | antforth
        syntax | Status), tracking only assembler mnemonics. Its `ED-Prefixed:
        I/O` section already covers `A (C) IN,` / `(C) A OUT,`. The runtime
        `IN`/`OUT` are not assembler mnemonics, so they do not belong there.
  - [x] Confirmed the `; antforth extension` flag is present at both words (CCD-3).

- [x] Task 5 — Regression + close (AC: 8)
  - [x] `make test-repl` (975/0) · `test-repl-asm` (5 assertions) ·
        `test-repl-value-to` (7/7) · `test-repl-banking` (62/0) ·
        `test-straddle-regression` (3/3) · the new `test-repl-in-out` (4
        assertions) · `make check-doc-sync` 0-drift (31 pre-existing advisories,
        unrelated). All green. Final `wc -c` = **28859 B**; delta **+43 B** vs
        the 28816 B baseline (itemised in Dev Notes — bodies + two DEFCODE
        headers; 1 B over the 36–42 B estimate band).
  - [ ] S9 hardware-smoke (binary-delta story) — **DEFERRED to operator** (no
        real silicon in the dev environment). Recipe posted in the closing chat
        message per `feedback_post_hw_smoke_steps_at_review` (STRONG). On real
        CP/M 2.2 / MicroBeast: verify `IN` reads `0x72` with mapping on, `OUT`
        writes the inert target without disturbing the system, and both
        underflow throws fire. A true write→read-back round-trip is OPTIONAL and
        only meaningful against a real *latching* peripheral (operator's choice
        / risk; an inert port cannot round-trip, by definition).

## Dev Notes

### Recommended implementation (synthesised from the live kernel map)

Both words are ~5 instructions. TOS-in-BC (`project_tos_in_register`) makes the
16-bit port available with zero marshalling: the Z80 register-indirect I/O forms
(`IN A,(C)` / `OUT (C),A`) take the full port in `BC`, and `BC` is already TOS.

```
; ---- IN ( port -- byte )   antforth extension ----
w_IN:
        DEFCODE "IN", 0
w_IN_cf:
        CALL    check_underflow         ; needs 1 cell (port); preserves BC
        IN      A, (C)                  ; ED 78 — read port BC (B=A8..A15) into A
        LD      C, A                    ; zero-extend to a cell (cf. C@)
        LD      B, 0
        NEXT

; ---- OUT ( x port -- )     antforth extension ----
w_OUT:
        DEFCODE "OUT", 0
w_OUT_cf:
        CALL    check_underflow_2       ; needs 2 cells (x, port); preserves BC
        POP     HL                      ; HL = x (NOS); BC still = port (TOS)
        LD      A, L                    ; A = low byte of x
        OUT     (C), A                  ; ED 79 — write A to port BC
        POP     BC                      ; new TOS (OUT consumed x and port)
        NEXT
```

This is the `@`/`!` shape with the memory access swapped for a port access:
`IN` mirrors `@` (read into TOS, here narrowed to a byte like `C@`); `OUT`
mirrors `!` (datum below address, both consumed). The `IN A,(C)`/`OUT (C),A`
mnemonics are standard Z80 — the build assembler emits them as ED 78 / ED 79
(the same opcodes the inline assembler's `IN,`/`OUT,` produce — finding (4)).

### Home-file decision (epic left it open: "Decide home file at spec")

**`src/io.asm`.** Rationale: io.asm is the existing I/O primitive home (EMIT,
TYPE, KEY, ...). Two ~7-byte CODE words do not justify a new `src/hardware.asm`
— a new file means a new INCLUDE in `src/antforth.asm` and (if it had its own
object) a Makefile edit, pure ceremony against the standing solo-dev lesson
(`feedback_ceremony_diminishing_returns`). Add a clear section header
`Z80 hardware port I/O (antforth extensions)` so the raw-port words are visually
distinct from the BDOS console words above them. (If the dev finds a strong
reason to split — e.g. a planned ISR/timer family — re-raise at dev-pass; the
default is io.asm.)

### Byte-budget rationale (itemised — B.2, no "mirrors prior arm" shorthand)

Per-component opcode/data estimate (fixed memory). Each line is an independent
itemisation of the new component:

- **`IN` body** — `CALL check_underflow` (3 B) + `IN A,(C)` (2 B, ED 78) +
  `LD C,A` (1 B) + `LD B,0` (2 B) + `NEXT` (the macro's bytes, ~1-2 B inline).
  Code subtotal ≈ **9-10 B**.
- **`OUT` body** — `CALL check_underflow_2` (3 B) + `POP HL` (1 B) + `LD A,L`
  (1 B) + `OUT (C),A` (2 B, ED 79) + `POP BC` (1 B) + `NEXT` (~1-2 B). Code
  subtotal ≈ **9-10 B**.
- **Headers** — two `DEFCODE` headers (`IN` = 2 chars, `OUT` = 3 chars) + the
  per-header link/flag/name-length overhead. Subtotal ≈ **18-22 B** (confirm
  against the DEFCODE macro's actual header layout at dev-pass).

**Story total ≈ 36-42 B**, in line with the epic's rough ≈ 50 B figure
(epics-phase5-epic-23.md:238). No bank-aware machinery (these are
MMU-agnostic, fixed-memory code words — NFR-P4-26), so none of the cross-bank
overage that inflated 23.2 applies here. Re-measure the real delta at close
(Task 5). The aggregate Epic-23 budget (≈ 300 B, epic :147-149) is already
mostly consumed by 23.1+23.2 (+310 B for 23.2 alone) — flag the running
aggregate at the 23.5 CCD-4 gate, but this story's own contribution is small.

### `OUT` probe-port decision (resolved with Ant, 2026-06-28)

**Axiom that settles AC4: an inert port does not latch, by definition.** A
write→read-back of the same value is therefore impossible against an inert port.
So the automated `OUT` probe does NOT attempt a value round-trip — it asserts
only *no-throw + 2-cell consumption* against an inert (undecoded) port:

- **0x70-0x74 are OFF-LIMITS** (MMU page registers + mapping-enable — writing
  them desyncs the MMU / disconnects RAM; src/banking.asm:36-51).
- iz-cpm-banking silently ignores writes to unmodeled ports, so on the emulator
  any undecoded port is a safe no-op.
- On real hardware, "inert" means a port the MicroBeast does not decode.

**Decision:** the automated probe writes to a high undecoded port — **target
`0xFE`** (confirm at dev-pass / HW-smoke that the MicroBeast does not decode it;
substitute another undecoded port if 0xFE is claimed) — and asserts no-throw +
2-cell consumption only. A genuine write→read-back round-trip is NOT in scope: it
would need a real *latching* peripheral (a non-inert device), which is an
optional, operator-discretion HW-smoke activity, not an automated AC.

### Source tree components to touch

- `src/io.asm` — add `w_IN`/`w_IN_cf` and `w_OUT`/`w_OUT_cf` under a new
  `Z80 hardware port I/O` section (after the console words, before the internal
  `bdos_*` helpers at :186).
- `tests/in_out_tests.fth` — NEW self-asserting probe (AC4).
- `Makefile` — add `IN_OUT_PROBE` + `test-repl-in-out` target + `.PHONY` entry
  (model on `test-repl-value-to`, :141-174).
- `docs/ans-forth-core-compliance.md` — add `IN`/`OUT` antforth-extension rows.
- `docs/z80-instruction-coverage.md` — add runtime `IN`/`OUT` if it tracks them.

### Testing standards summary

REPL-piped Forth probes are the default (S2). Assert OBSERVABLE behaviour:
`IN` returns a zero-extended cell (high byte 0), `OUT` executes without throw and
consumes two cells, and underflow raises `-4`. Prefer UNCAUGHT throws for the
`-4` rounds (verify a caught `-4` leaves no residue — cf. Story 23.1's
CATCH-leaves-`asm_mode` gotcha — and document the choice). Keep every probe line
≤ TIB_SIZE=128 (S12); word-existence pre-flight every new word before use.
Column-0-anchor the verdict greps (`^PASS:`/`^FAIL:`) so echoed source can't
false-green (the 23.2 lesson, Makefile:133-140). Binary-delta story → S9
hardware-smoke on real CP/M 2.2 / MicroBeast required before done; post the
recipe in the closing chat message (`feedback_post_hw_smoke_steps_at_review`).

### Banking / hardware gotchas (carried-forward, verify empirically)

- `IN`/`OUT` are MMU-agnostic, fixed-memory CODE words — they run identically
  from bank 0 or a banked colon body and do NOT interact with the MMU/banking
  subsystem (NFR-P4-26). No descriptor-stub / cross-bank machinery (contrast
  23.2's VALUE, which needed it). They take the bank-0 CFA path like any kernel
  CODE word.
- **Never write 0x70-0x74 from a probe** (finding (5)) — that is the one way
  these words can crash the kernel. The `OUT` probe target must be undecoded.
- The `IN A,(C)` register form (ED 78) puts B on A8..A15; the immediate form
  `IN A,(n)` (DB nn) puts the accumulator there instead. The runtime word uses
  ONLY the register form, so the high-byte-decode subtlety that caused DIV-1
  (`project_div1_mmu_port_readback`) does not apply — but it's why AC1 specifies
  "high byte in B" and the probe reads via the register-indirect path.

### Project Structure Notes

- No new kernel file (io.asm reused); no new UserArea cells; no new THROW codes
  (underflow reuses the existing `-4` via `check_underflow*`).
- `IN`/`OUT` are antforth EXTENSIONS, not ANS — the compliance doc rows are
  extension rows, not `§6.x`-numbered Core rows. This differs from 23.2 (VALUE/TO
  were Core-Ext `§6.2` words). Do not invent a `§` number for them.
- Names deliberately mirror the assembler's `IN,`/`OUT,` minus the comma, so the
  runtime port words and the assembler mnemonics read consistently.

### References

- [Source: src/io.asm:1-183] — I/O primitive home (EMIT/TYPE/KEY model); add
  `IN`/`OUT` after the console words, before `bdos_*` helpers (:186).
- [Source: src/memory.asm:43-52] — `@` (read-into-TOS model; `CALL check_underflow` placement)
- [Source: src/memory.asm:58-69] — `!` (datum-below-address two-cell consume; the `OUT` shape)
- [Source: src/memory.asm:75-82] — `C@` (zero-extend tail `LD C,A`/`LD B,0` for `IN`)
- [Source: src/memory.asm:88-97] — `C!` (low-byte store, two-cell consume; cross-check)
- [Source: src/system.asm:584-621] — `check_underflow` / `check_underflow_2` (preserve BC/DE/IX/IY; clobber AF/HL)
- [Source: src/assembler.asm:3328-3387] — `w_IN_COMMA_cf` (`IN,`; ED 78 / DB nn) — distinct name (AC6)
- [Source: src/assembler.asm:3389-3445] — `w_OUT_COMMA_cf` (`OUT,`; ED 79 / D3 nn) — distinct name (AC6)
- [Source: src/banking.asm:36-51] — port 0x74 mapping-enable; why 0x70-0x74 must not be written by a probe (finding (5))
- [Source: tools/mmu_probe/mmu_probe.asm:1-60] — 0x72 readback behaviour; iz-cpm-banking returns bank_map[2] for any read; reads are non-mutating (probe IN target)
- [Source: Makefile:19-31] — `IZCPM = iz-cpm-banking` (the plain target IS the banking fork; superset runs non-banking probes); `IZCPM_DISKS`
- [Source: Makefile:127-174] — `test-repl-value-to` target (model for `test-repl-in-out`); column-0-anchored verdict-grep lesson (:133-140)
- [Source: Makefile:52] — `.PHONY` list (add `test-repl-in-out`)
- [Source: docs/ans-forth-core-compliance.md] — extension-row convention for non-ANS words (AC7)
- [Source: _bmad-output/planning-artifacts/epics-phase5-epic-23.md#Story-23.3] — epic spec (FR-P5-9 `IN`, FR-P5-10 `OUT`); ≈ 50 B estimate
- [Source: _bmad-output/implementation-artifacts/23-2-value-to-ans-core-named-values.md] — prior story (probe wiring + column-0 anchor lesson; binary 28499→28809)
- [Memory: project_tos_in_register] — BC = TOS; port-in-BC makes `IN A,(C)`/`OUT (C),A` free (finding (1))
- [Memory: project_div1_mmu_port_readback] — 0x70-0x73 write-only; use BIOS MBB; IN A,(n) vs IN A,(C) high-byte decode (finding (5))
- [Memory: project_phase4_banking_off_emulator] — 0x74 OFF disconnects RAM; emulator port modelling caveats
- [Memory: feedback_source_comment_discipline] — comment the why (CCD-3 extension note), never provenance
- [Memory: feedback_no_preexisting_discharge] — `C@`'s missing underflow check is NOT a precedent to copy; guard both `IN`/`OUT` (finding (3))
- [Memory: feedback_post_hw_smoke_steps_at_review] — STRONG: post HW-smoke recipe in the closing chat message
- [Memory: feedback_tib_size_inline_comments] — probe lines ≤ TIB_SIZE=128
- [Memory: feedback_ceremony_diminishing_returns] — no new file for two tiny words (home-file decision)
- [Memory: project_epic17_envelope] — epic byte estimates run low; re-derive per-component (here the estimate matches — no cross-bank machinery)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Opus 4.8)

### Debug Log References

- **`'` (tick) inside a colon body throws -13** — the first cut of the AC6
  distinctness check wrapped `' IN DROP ...` in a colon (`_io-distinct`). Tick
  parses its name from the input buffer, so at runtime (no pending input) it
  threw `-13 undefined word`. Fix: run the distinctness/pre-flight line at
  INTERPRET level (where `'` belongs). The behavioural IN/OUT verdicts stay in
  colon bodies (they print at column 0 after the REPL's input-echo newline).
- **iz-cpm raw output carries NUL bytes** — file-captured probe output is
  classified `data` by `file(1)`, so a plain `grep '^PASS:'` on the saved file
  silently matched nothing (binary-file suppression); `grep -a` fixed the local
  check. NOT a harness issue: the Makefile gates capture via `$(...)` command
  substitution, which strips NULs, so `echo "$OUTPUT" | grep` is unaffected.
- **Echoed comment quoting `error -4`** — the probe's header comment quotes the
  literal `error -4: stack underflow`, which the REPL echoes mid-line. An
  unanchored count would read 3. Anchoring the gate to `^error -4` keeps the
  runtime count at exactly 2 (the two col-0 uncaught throws).
- **HW-smoke recipe stack-hygiene correction** — the first smoke recipe handed
  to the operator measured OUT's stack effect with `DEPTH 0 FE OUT DEPTH`, which
  leaves both DEPTH results on the stack; the subsequent `IN`/`0 OUT` underflow
  probes then ran on a NON-empty stack and (correctly) did not throw, masquerading
  as a defect. `IN`/`OUT` were correct throughout — the recipe was buggy. Fixed
  recipe uses `.S 0 FE OUT .S` (shows `<0>` before and after = 2-consumed, no
  throw) and runs the underflow probes on a guaranteed-empty stack (both `-4`
  fire). Operator-facing lesson, not a kernel change.

### Completion Notes List

- Implemented two ~10-byte runtime CODE words in `src/io.asm` under a new
  `Z80 hardware port I/O (antforth extensions)` section: `IN ( port -- byte )`
  (`IN A,(C)`, ED 78, zero-extended via the `C@` tail) and `OUT ( x port -- )`
  (`OUT (C),A`, ED 79, the `!` datum-below-address shape). TOS-in-BC makes the
  full 16-bit port (B=A8..A15) available with zero marshalling — confirmed all
  five draft findings held: no EXX/BDOS (S7 N/A), guards via `check_underflow`
  (IN) / `check_underflow_2` (OUT) at the top of each cf before BC is touched.
- Verified empirically at the REPL: `0x72 IN 0x100 U<` → `-1` (zero-extension);
  `0 0xFE OUT` consumes exactly 2 cells, no throw; `IN`/`0 OUT` on a short stack
  → `error -4: stack underflow`; `' IN`/`' IN,`/`' OUT`/`' OUT,` all resolve
  (AC6 — no collision; the assembler's comma-suffixed words are distinct).
- New gate `make test-repl-in-out` (4 assertions, all green), column-0-anchored
  verdict grep per the 23.2 lesson.
- Docs: `IN`/`OUT` added as antforth-extension rows in the compliance doc's
  Non-standard table; `z80-instruction-coverage.md` left untouched (assembler-
  only report — rationale in Task 4).
- Binary +43 B (28816 → 28859), within ~1 B of the 36–42 B estimate; no bank-
  aware machinery (MMU-agnostic fixed-memory code words, NFR-P4-26).
- Full regression green: test-repl 975/0 · test-repl-asm 5 · test-repl-value-to
  7/7 · test-repl-in-out 4 · test-repl-banking 62/0 · test-straddle 3/3 ·
  check-doc-sync 0-drift. S9 hardware-smoke deferred to operator (recipe in the
  closing chat message).

### File List

- `src/io.asm` — added `w_IN`/`w_IN_cf` and `w_OUT`/`w_OUT_cf` under a new
  `Z80 hardware port I/O (antforth extensions)` section (modified)
- `tests/in_out_tests.fth` — NEW self-asserting REPL probe (AC4/AC5/AC6)
- `Makefile` — added `IN_OUT_PROBE` var, `test-repl-in-out` target, `.PHONY`
  entry (modified)
- `docs/ans-forth-core-compliance.md` — added `IN`/`OUT` antforth-extension
  rows to the Non-standard words table (modified)

### Change Log

- 2026-06-28 — Story 23.3 implemented: runtime `IN`/`OUT` Z80 port words in
  `src/io.asm`, new `tests/in_out_tests.fth` probe + `test-repl-in-out` gate,
  compliance-doc extension rows. Binary 28816 → 28859 B (+43 B). All gates
  green; S9 hardware-smoke deferred to operator. Status → review.
