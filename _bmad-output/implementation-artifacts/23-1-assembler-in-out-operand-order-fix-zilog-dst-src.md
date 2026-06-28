# Story 23.1: Assembler `IN,` / `OUT,` operand-order fix (Zilog dst-src)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-28 by create-story workflow.
     Story 23.1 is the FIRST story of Epic 23 (Phase 5 — standards & I/O
     polish, → antforth v3.1.0). It has ONE deliverable: correct the inline
     assembler's `IN,` and `OUT,` to the project's documented Zilog dst-src
     operand order, then migrate every existing call site.

     FIVE load-bearing findings were resolved at DRAFT TIME by reading live
     source (B.4 / PD-2 figure-drift discipline). Do NOT re-discover them at
     dev-pass:

       (1) BOTH WORDS ARE GENUINELY REVERSED — confirmed against the bodies.
           `w_IN_COMMA_cf`  (src/assembler.asm:3330) reads TOS = register
           (destination), then `POP BC` = NOS = port (source). So today the
           user must type `<port> <reg> IN,` (src-dst), e.g. `(C) A IN,` or
           `$74 # A IN,`. `w_OUT_COMMA_cf` (src/assembler.asm:3382) reads
           TOS = port, then `POP BC` = NOS = register, so today the user types
           `<reg> <port> OUT,` (src-dst), e.g. `A (C) OUT,` or `A $74 # OUT,`.
           The project convention (feedback_assembler_operand_order) is Zilog
           dst-src: `B C LD,` = `LD B,C` → dst = NOS, src = TOS. After the fix:
             • `A (C) IN,`  → `IN A,(C)`   (ED 78)
             • `A $74 # IN,`→ `IN A,(n)`   (DB 74)
             • `(C) A OUT,` → `OUT (C),A`  (ED 79)
             • `$74 # A OUT,`→`OUT (n),A`  (D3 74)

       (2) THE CHEAPEST CORRECT FIX IS A 2-OPERAND STACK SWAP PREPENDED TO EACH
           BODY — NOT a rewrite of the emit logic. The TOS-in-register model
           (BC = TOS, NOS = top of SP; project_tos_in_register) means a swap of
           the two operands at entry makes the existing, already-validated emit
           code see operands in the new order with ZERO change to the emit/
           validation paths. The swap (HL scratch):
             POP  HL      ; HL = NOS (operand1), BC = TOS (operand2)
             PUSH BC      ; operand2 back onto stack
             LD   B, H
             LD   C, L    ; BC = operand1   → operands now exchanged
           ≈ 4 bytes per word. Rationale that this is correct: after the swap,
           `A (C) IN,` lands reg=A in BC (TOS) and (C) on the stack (NOS) —
           exactly what the *unchanged* `w_IN_COMMA_cf` body already expects.
           Symmetric for OUT,. This keeps the operand-class validation, the
           A-only immediate constraint, and the (C)-only indirect constraint
           byte-identical. (A full restructure is an acceptable alternative but
           costs more bytes and more risk for no benefit — see Dev Notes.)

       (3) THE BLOCK-I/O FAMILY IS NOT AFFECTED — DO NOT TOUCH IT. `INI,`
           `INIR,` `IND,` `INDR,` `OUTI,` `OTIR,` (src/assembler.asm:3507-3539)
           are single-opcode ED-prefixed instructions that take NO operands.
           They have no dst-src order to fix. Scope is EXACTLY `IN,` and `OUT,`.

       (4) EXACTLY THREE FILES HAVE CALL SITES (grep at draft time, 2026-06-28):
             • tests/banking_tests.fth:15  `$74 # A IN,`  \ IN A,(74h)
             • disk/a/DIV1RB.FTH:41        `A 72 # OUT,`  \ OUT (0x72),A
             • disk/a/DIV1RB.FTH:42        `72 # A IN,`   \ IN  A,(0x72)
             • disk/a/DIV1RB.FTH:45        `A 72 # OUT,`  \ OUT (0x72),A
           There is NO dedicated assembler test file in tests/ — the AC5 probe
           establishes the pattern. The banking_tests.fth site is in the LIVE
           975-PASS suite: it is coupled to the fix and MUST be migrated in the
           same pass or the baseline regresses (the test currently relies on
           the OLD src-dst order). The DIV1RB.FTH site is a CP/M MMU-readback
           diagnostic (div1_mmu_port_readback) — migrate it preserving the same
           emitted bytes (its comments already state intent).

       (5) THIS IS SOURCE-BREAKING BY DESIGN, AND THAT'S CORRECT (S8). The old
           order was the bug (docs/dev_journal.md:10-13). No "accept pre-
           existing" disposition applies (feedback_no_preexisting_discharge):
           surface, fix, sweep. The assembler is an antforth extension, so
           there is no ANS conformance bearing — only internal-convention
           conformance.
-->

## Story

As an antforth inline-assembler user,
I want `IN,` and `OUT,` to follow the same Zilog dst-src operand order as every
other mnemonic,
so that `A (C) IN,` and `(C) A OUT,` read like `IN A,(C)` / `OUT (C),A` and I
don't hit "bad operand" typing the natural order.

## Acceptance Criteria

1. **`IN,` reads dst-src.** `A (C) IN,` assembles `IN A,(C)` (`ED 78`);
   `A $74 # IN,` assembles `IN A,(n)` (`DB 74`). The old src-dst order
   (`(C) A IN,`) no longer assembles a valid `IN`.
2. **`OUT,` reads dst-src.** `(C) A OUT,` assembles `OUT (C),A` (`ED 79`);
   `$74 # A OUT,` assembles `OUT (n),A` (`D3 74`). The old src-dst order
   (`A (C) OUT,`) no longer assembles a valid `OUT`.
3. **Validation paths preserved.** Immediate port remains valid for `A` only
   (`IN r,(n)` / `OUT (n),r` with r≠A still raises `asm_bad_operand`); `(C)` is
   still the only valid indirect register; a non-REG8 destination/source still
   raises `asm_bad_operand`. Net stack effect stays −2 cells.
4. **Call-site sweep complete.** The three files in finding (4) are migrated to
   the new order with their emitted bytes unchanged; a fresh
   `grep -rn -E '\bIN,|\bOUT,' tests/ disk/ examples/` shows no surviving
   old-order usage. `disk/a/DIV1RB.FTH` re-terminated with 0x1A per
   feedback_cpm_0x1a_eof_marker if re-saved.
5. **New REPL-piped assembler probe** (`tests/asm_in_out_tests.fth` or
   equivalent) asserts the emitted bytes for all four forms (`IN A,(C)`,
   `IN A,(n)`, `OUT (C),A`, `OUT (n),A`) and asserts one `bad operand` round
   (e.g. `B $74 # IN,` → THROW). The probe passes word-existence pre-flight and
   the TIB-128 line-length lint (S12).
6. **Docs reconciled.** `docs/dev_journal.md:10-13` (the OUT/IN convention note)
   is resolved/removed; `docs/z80-instruction-coverage*.md` updated if either
   documents `IN,`/`OUT,` operand order.
7. **No regression.** Full `make test-repl` (iz-cpm) holds at the 975-PASS
   baseline after the banking_tests.fth migration; banking-capable-emulator and
   the new asm probe green.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev Notes.
  - Re-measured at dev-pass start: **28499 B** (matched the draft-time reference).
- [x] Capture current `make test-repl` baseline pass count (expect 975/0). Confirmed 975/0.

### Story tasks

- [x] Task 1 — Fix `w_IN_COMMA_cf` (AC: 1, 3)
  - [x] **Deviation from finding (2): the 2-operand prepend-swap was empirically
        refuted and replaced by a body restructure (the story's permitted
        alternative).** The immediate operand `n #` occupies TWO stack cells
        (`#` pushes value as NOS, `0xFF40` tag as TOS — `src/assembler.asm:1097`),
        so a fixed TOS↔NOS swap corrupts the immediate forms (`A $74 # IN,` →
        `-267 bare integer`, observed). `w_IN_COMMA_cf` now reads the src port
        from TOS first (mirror of the old OUT, structure), emitting IN opcodes.
  - [x] Added a `why` source comment (dst-src order + the 2-cell-immediate
        reason the naive swap fails), no provenance.
  - [x] `.in_indirect` / `.in_imm` emit logic preserved (opcodes/validation unchanged).
- [x] Task 2 — Fix `w_OUT_COMMA_cf` (AC: 2, 3)
  - [x] Restructured symmetrically: reads src register from TOS first (mirror of
        the old IN, structure), emitting OUT opcodes. Same 2-cell-immediate
        rationale as Task 1.
  - [x] `.out_indirect` / `.out_imm` emit logic preserved.
- [x] Task 3 — Verify EXX / register hygiene (AC: 3)
  - [x] Restructure uses no extra scratch beyond the pre-existing A/BC/HL usage;
        EXX/shadow state untouched. The only THROW path remains `asm_bad_operand`
        (−258), verified unchanged for non-A immediate, non-(C) indirect, and
        non-REG8 operands.
- [x] Task 4 — Migrate call sites (AC: 4)
  - [x] `tests/banking_tests.fth:15`: `$74 # A IN,` → `A $74 # IN,`.
  - [x] `disk/a/DIV1RB.FTH:41,45`: `A 72 # OUT,` → `72 # A OUT,`.
  - [x] `disk/a/DIV1RB.FTH:42`: `72 # A IN,` → `A 72 # IN,`.
  - [x] **Survey gap found at regression: finding (4) missed FOUR inline-assembler
        call sites in `Makefile` (REPL tests 151–154).** Migrated all four to the
        new order (emitted-byte expectations unchanged); these are part of the
        live 975 gate. Re-grepped repo-wide (`.fth/.FTH/Makefile/docs`): zero
        old-order survivors. DIV1RB.FTH 0x1A EOF preserved.
- [x] Task 5 — New assembler probe (AC: 5)
  - [x] Authored `tests/asm_in_out_tests.fth`: one CODE word per form, reads the
        first two emitted bytes via `xt C@` / `xt 1+ C@`, asserts `ED 78` /
        `DB 74` / `ED 79` / `D3 74`.
  - [x] Bad-operand round via an UNCAUGHT `B $74 # IN,` (→ `-258`). **Note: CATCH
        was rejected** — a caught `asm_bad_operand` leaves `asm_mode` set (the
        cleanup hook only runs on the uncaught path; observed `-259 nested CODE`
        on the next CODE after a caught throw). Uncaught lets `asm_cleanup` recover.
  - [x] Wired as a dedicated `make test-repl-asm` target (`test-repl` uses inline
        printf probes, not a file list); added to `.PHONY`.
- [x] Task 6 — Docs (AC: 6)
  - [x] `docs/dev_journal.md:10-13` resolved (marked RESOLVED with the new-order
        examples); `docs/z80-instruction-coverage.md` + `-reaudit.md` syntax
        columns updated to dst-src order.
- [x] Task 7 — Regression + close (AC: 7)
  - [x] `make test-repl` 975/0 · `test-repl-banking` 62/0 · `test-repl-asm` 5/0 ·
        `test-straddle-regression` 3/3 · `test-file-sanity` pass · `check-doc-sync`
        0 drift. Final `wc -c` = **28499 B**, delta **+0 B** vs baseline (the
        restructure is byte-neutral; the +8 B estimate assumed the prepend-swap).

## Dev Notes

### Recommended approach (prepend-swap)

Both bodies already validate and emit correctly given their *current* operand
order. The minimal, lowest-risk fix is to exchange the two operands at entry so
the unchanged body sees them in dst-src order (finding (2)). Per-word the prepend
is `POP HL / PUSH BC / LD B,H / LD C,L`. Alternative (rewrite each body to pop in
the opposite order) is acceptable but costs more bytes + more diff surface for no
behavioural gain — prefer the swap unless it obscures the body, in which case add
the explanatory comment rather than restructure.

### Byte-budget rationale (itemised — B.2, no "mirrors" shorthand)

Per-word prepend, costed by opcode:
- `POP HL` — 1 byte
- `PUSH BC` — 1 byte
- `LD B, H` — 1 byte
- `LD C, L` — 1 byte
- per-word subtotal: **4 bytes**

Two words (`IN,`, `OUT,`): 4 × 2 = **8 bytes**. One short explanatory comment per
word adds 0 binary bytes. New test file and call-site edits add 0 binary bytes.
**Story total ≈ +8 B** (epic estimate was ≈ 0 ±15 B → within envelope; the
"byte-neutral" wording in the epic is refined to ≈ +8 B here). Re-measure actual
delta at close (AC7); if a body rewrite is chosen instead, re-itemise.

### Source tree components to touch

- `src/assembler.asm` — `w_IN_COMMA_cf` (:3330), `w_OUT_COMMA_cf` (:3382) ONLY.
  Do NOT touch the block-I/O family (:3507-3539, finding (3)).
- `tests/banking_tests.fth` (:15) — live-suite call site, coupled to the fix.
- `disk/a/DIV1RB.FTH` (:41,42,45) — CP/M diagnostic; preserve emitted bytes;
  0x1A EOF.
- `tests/asm_in_out_tests.fth` — NEW probe (AC5).
- `docs/dev_journal.md`, `docs/z80-instruction-coverage*.md` — doc reconcile.

### Testing standards summary

REPL-piped Forth probes are the default (S2). Assert *emitted bytes*, not just
"assembles without error" — read the CODE word body with `C@` and compare to the
opcode constants (finding (1)). Keep every probe line ≤ TIB_SIZE=128 (S12,
feedback_tib_size_inline_comments). This is a binary-delta story → S9 hardware-
smoke on real CP/M 2.2 / MicroBeast required before done; post the smoke recipe
in the closing chat message (feedback_post_hw_smoke_steps_at_review).

### Project Structure Notes

- No new kernel file; no UserArea cells; no banking interaction (assembler words
  run during ASM-mode parsing, MMU-agnostic). Assembler stays kernel-resident
  per project_assembler_keep_assembly.
- Pure internal-convention fix — no ANS conformance row needed (assembler is an
  antforth extension; CCD-3 flagging already present on the words).

### References

- [Source: src/assembler.asm:3328-3378] — `w_IN_COMMA` / `w_IN_COMMA_cf` current body
- [Source: src/assembler.asm:3380-3436] — `w_OUT_COMMA` / `w_OUT_COMMA_cf` current body
- [Source: src/assembler.asm:185] — `ASM_IND_C EQU 6` (the `(C)` indirect tag index)
- [Source: src/assembler.asm:1108,1120] — `asm_is_imm_tag` / `asm_is_indirect_tag`
- [Source: src/assembler.asm:3507-3539] — block-I/O family (out of scope)
- [Source: docs/dev_journal.md:10-13] — the OUT/IN operand-order note this story resolves
- [Source: tests/banking_tests.fth:15] — live-suite call site to migrate
- [Source: disk/a/DIV1RB.FTH:41-45] — diagnostic call sites to migrate
- [Source: _bmad-output/planning-artifacts/epics-phase5-epic-23.md#Story-23.1] — epic spec (FR-P5-11)
- [Memory: feedback_assembler_operand_order] — `B C LD,` = `LD B,C`, dst=NOS src=TOS
- [Memory: project_tos_in_register] — BC = TOS; NOS on SP
- [Memory: feedback_no_preexisting_discharge] — source-breaking bug must be fixed, not accepted
- [Memory: feedback_cpm_0x1a_eof_marker] — 0x1A-terminate disk/a files
- [Memory: feedback_source_comment_discipline] — comment the why, never provenance

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story workflow)

### Debug Log References

- Scratch byte-readback under iz-cpm confirmed all four forms post-fix:
  `A (C) IN,`→`237 120` (ED 78), `A $74 # IN,`→`219 116` (DB 74),
  `(C) A OUT,`→`237 121` (ED 79), `$74 # A OUT,`→`211 116` (D3 74).
- Old-order + validation rejections all `-258 bad operand`: `(C) A IN,`,
  `A (C) OUT,`, `B $74 # IN,`, `$74 # B OUT,`, `HL (C) IN,`.

### Completion Notes List

- **Approach deviation (empirically justified).** The story's recommended
  prepend-swap (finding (2), ≈+8 B) is incorrect for the immediate forms: `#`
  pushes the immediate as a 2-cell operand (value + `0xFF40` tag,
  `src/assembler.asm:1097`), so a fixed TOS↔NOS swap puts the bare value on TOS
  (`-267 bare integer`, reproduced). Used the story-permitted alternative — a
  body restructure. Because IN dst-src and OUT dst-src are mirror images, each
  body now adopts the other's operand-reading structure (IN reads port-from-TOS,
  OUT reads reg-from-TOS) with the opcode constants adjusted. Size-aware by
  construction (each branch pops its own operand) and **byte-neutral (+0 B)**.
- **Survey gap surfaced & fixed.** Finding (4)'s call-site grep scoped only
  `tests/ disk/ examples/` and missed four inline-assembler sites in the
  `Makefile` (REPL tests 151–154, part of the live 975 gate). Found via
  regression (test 151 failed), migrated all four, then re-swept repo-wide.
- **Bad-operand probe uses an uncaught throw, not CATCH.** `asm_cleanup` (which
  clears `asm_mode` + rolls back HERE/bucket) runs only on the uncaught-THROW
  recovery chain; a caught `-258` leaves `asm_mode` set and the next `CODE`
  fails `-259 nested CODE`. The probe therefore lets the REPL handle the throw.
- Net binary delta **+0 B** (28499 → 28499). All gates green (see Task 7).
- **Hardware smoke still required (S9, binary-delta story).** See closing message.

### File List

- `src/assembler.asm` — `w_IN_COMMA_cf` / `w_OUT_COMMA_cf` bodies restructured to
  Zilog dst-src operand order (mirror-swapped, byte-neutral).
- `tests/asm_in_out_tests.fth` — NEW probe: asserts emitted bytes for all four
  IN,/OUT, forms + one bad-operand round.
- `tests/banking_tests.fth` — `FETCH-74` migrated (`A $74 # IN,`).
- `disk/a/DIV1RB.FTH` — three sites migrated to dst-src order; 0x1A EOF preserved.
- `Makefile` — new `test-repl-asm` target + `.PHONY` entry; REPL tests 151–154
  migrated to dst-src order (emitted-byte expectations unchanged).
- `docs/dev_journal.md` — operand-order gap marked RESOLVED.
- `docs/z80-instruction-coverage.md`, `docs/z80-instruction-coverage-reaudit.md`
  — IN,/OUT, syntax columns updated to dst-src order.

### Change Log

- 2026-06-28 — Story 23.1: `IN,`/`OUT,` corrected to Zilog dst-src operand order
  via body restructure (prepend-swap refuted on 2-cell immediates). Call sites
  swept (tests/disk/Makefile), new `test-repl-asm` probe + gate, docs reconciled.
  Net +0 B; 975/0 · banking 62/0 · asm 5/0 · straddle 3/3 · doc-sync 0 drift.
