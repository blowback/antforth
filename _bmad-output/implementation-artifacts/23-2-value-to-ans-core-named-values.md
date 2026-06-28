# Story 23.2: `VALUE` / `TO` (ANS Core-Ext named values)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-28 by create-story workflow (context-engine pass).
     Story 23.2 is the second story of Epic 23 (Phase 5 — standards & I/O
     polish, → antforth v3.1.0). Deliverable: implement `VALUE` (a defining
     word for named mutable cells) and `TO` (the STATE-aware store-by-name),
     fully interoperable with the banked compiler.

     SEVEN load-bearing findings were resolved at DRAFT TIME by reading live
     source (B.4 / PD-2 figure-drift discipline) and confirmed against two
     source-mapping passes. Do NOT re-discover them at dev-pass:

       (1) ANS SECTION NUMBERS — the epic spec is WRONG; use these.
           The epic (epics-phase5-epic-23.md:191-204) cites "§6.1.2380 VALUE"
           and "§6.1.2295 TO". Those are misattributions: §6.1.2380 is
           `UNLOOP` (docs/ans-forth-core-compliance.md:292), and §6.1.2295
           does not exist. VALUE and TO are **Core-EXTENSION** words:
             • VALUE = §6.2.2405  (docs/ans-forth-core-compliance.md:458)
             • TO    = §6.2.2295  (docs/ans-forth-core-compliance.md:453)
           Both are currently `Deliberately-omitted | N-A | v2.0 baseline`.
           This story FLIPS those two existing rows to `Implemented` — it does
           NOT add §6.1 rows. (PD-2: validated against the compliance doc at
           draft time, not transcribed from the epic.)

       (2) VALUE NEEDS ITS OWN CODE-FIELD HANDLER (`DOVALUE`), NOT `DOCON`.
           `TO` must reject application to a non-VALUE (a CONSTANT, a `:`
           word, etc.) with a defined THROW (AC4). The only way `TO` can tell
           a VALUE apart from a CONSTANT is by the code field: a CONSTANT
           emits `JP DOCON` (compiler.asm:879-884 / inner_interpreter.asm:85).
           If VALUE also emitted `JP DOCON`, the two would be
           indistinguishable. Therefore VALUE emits `JP DOVALUE`, where
           DOVALUE is a NEW handler with a DISTINCT address. Runtime semantics
           are identical to DOCON (push the cell at cf+3), so the cheapest
           form is a 3-byte trampoline `DOVALUE: JP DOCON` (HL = code-field
           addr is preserved across the JP→JP, so DOCON's `cf+3` read still
           lands on the value cell — VERIFY empirically at dev-pass). A full
           clone of the DOCON body (~14 B) is the acceptable alternative if
           the trampoline indirection is undesirable; itemise whichever is
           chosen (B.2).

       (3) BANKED VALUE MUST EMIT A DESCRIPTOR STUB — CLONE `CREATE`, NOT
           `CONSTANT`. AC5 requires a VALUE defined in bank N>0 to be read
           AND written from any bank. CONSTANT (compiler.asm:872-906) does
           NOT emit a cross-bank descriptor stub — it has no stub-allocate
           block, so a bank-N>0 CONSTANT is only invocable from its home bank
           (same hazard as project_banked_marker_no_stub). CREATE
           (compiler.asm:822-851, the `.create_skip_stub` block added by
           Story 19.3) DOES emit the stub: if `current_bank > 0` it calls
           `stub_allocate` (banking.asm:1068-1083), overwrites the reserved
           xt-cell at `(bh_stub_xt_addr)` with the stub address, and points
           LATEST at the stub. VALUE MUST replicate that block verbatim so its
           xt is the stub (xt-stable across banks). Cloning CONSTANT and
           skipping the stub block is a SILENT AC5 failure.

       (4) FIND RETURNS A STUB-XT FOR BANKED WORDS; `TO` MUST RESOLVE IT.
           On the banked build, FIND (dictionary.asm:25-92; stub-xt extraction
           at :195-202) returns the descriptor-stub address for bank-N>0
           entries (those with F_HAS_STUB_XT_CELL set), and the raw CFA for
           bank-0 entries. A descriptor stub (banking.asm:1068-1083) is:
             byte 0 = 0xEF (RST $28 self-dispatch), byte 1 = target_bank,
             bytes 2-3 = target CFA in the bank.
           A bank-0 CFA begins with 0xC3 (`JP`). So `TO` discriminates on
           xt byte 0: 0xEF → stub (bank = xt+1, CFA = (xt+2..3));
           0xC3 → bank-0 (bank = 0, CFA = xt). The VALUE's data cell is at
           CFA+3 in its home bank.

       (5) THROW CODE −32 IS THE CORRECT, ALREADY-RESERVED CODE.
           docs/throw-codes.md:106 reserves `-32 = invalid name argument
           (e.g., TO xxx)` (ANS Forth 1994 §9.3.5), but it is NOT yet wired
           (`no` in the implemented column) and there is NO `THROW_*` EQU for
           it in src/constants.asm. This story adds the EQU (near
           constants.asm:148, cite "ANS Forth 1994 §9.3.5"), adds the message
           row to the `throw_desc_table` in src/exception.asm (the table runs
           ~:824-925; insert in code order, before the −37 entry), and flips
           the throw-codes.md:106 row to `done — Story 23.2`. `TO` on an
           UNDEFINED name reuses the tick path's −13 (undefined word); `TO`
           on a defined-but-not-a-VALUE name raises −32.

       (6) `TO` IS IMMEDIATE + STATE-AWARE (one word, two behaviours).
           `TO` must run during compilation to parse its name argument, so it
           is IMMEDIATE (DEFCODE with F_IMMEDIATE / DEFIMMED). It reads STATE
           (outer_interpreter.asm:30-37; the INTERPRET STATE branch pattern is
           at :191-211) to choose:
             • interpret (STATE==0): store TOS into the resolved cell NOW.
             • compile  (STATE!=0): compile `LIT <xt>` + `(TO)` so the store
               happens at run time. Compiling the XT (not a raw cell address)
               keeps the banked case correct — the xt is bank-stable, the raw
               cell address is a window address only valid when its bank is
               mapped.

       (7) FACTOR ONE RESOLVE+STORE ROUTINE, SHARED BY INTERPRET-`TO` AND THE
           `(TO)` RUNTIME. Both interpret-time `TO` and the compiled `(TO)`
           helper do the identical job: given ( x xt -- ), resolve xt →
           (bank, cell_addr), then store x into that cell bank-aware. Write it
           once. The bank-aware store maps the target bank into the window
           (reuse the FIND paging helpers `sw_map_bank` / `sw_restore_slot2`,
           dictionary.asm), writes the cell, restores. For bank 0 (or
           bank == current_bank) the map/restore is a no-op fast path. The
           cross-bank READ already works for free: executing the VALUE routes
           through the stub dispatcher (banking.asm:1305-1339), which maps the
           bank, runs DOVALUE→DOCON in-window, and returns via xbank_thunk.
-->

## Story

As a Forth programmer,
I want `VALUE` and `TO`,
so that I can declare a named mutable cell that is read by name (`X` pushes its
value) and rewritten with `TO` (`99 TO X`) — without the `@` / `!` box dance —
and have it work transparently across memory banks.

## Acceptance Criteria

1. **`VALUE` defines a self-fetching named cell.** `42 VALUE X` defines `X`;
   executing `X` pushes `42`. (§6.2.2405.) `VALUE` consumes one cell `x` and
   parses one name; a zero-length name raises `-16` (per CONSTANT/CREATE, ANS
   §9.3.5).
2. **`TO` updates a `VALUE` (interpret).** `99 TO X` stores `99` into `X`; `X`
   now pushes `99`. (§6.2.2295.) Net stack effect of `TO` at interpret time is
   `( x -- )`.
3. **`TO` is STATE-aware (compile).** `: BUMP X 1 + TO X ;` compiles a store;
   running `BUMP` increments `X`'s stored value by 1 at run time. Repeated
   `BUMP` invocations are cumulative (proves the compiled store hits the cell,
   not a copy).
4. **`TO` on a non-`VALUE` raises `-32`.** `TO` applied where the next token
   resolves to a non-`VALUE` (e.g. a `CONSTANT`, a `:`-defined word, `VARIABLE`)
   raises `-32` (`invalid name argument`) — not silent corruption. `TO` on an
   UNDEFINED token raises `-13` (undefined word, via the existing tick path).
   The `-32` row in `docs/throw-codes.md:106` is wired (EQU + message) and
   flipped to implemented.
5. **Banked interoperability.** `5 BANK! 7 VALUE Y` defines `Y` in bank 5;
   `0 BANK!` then `Y` pushes `7` (cross-bank READ), and `8 TO Y` from bank 0
   updates it so a subsequent `Y` (from bank 0 or bank 5) pushes `8` (cross-bank
   WRITE). The xt is stub-stable (VALUE emits a descriptor stub in bank N>0,
   per finding (3) / Story 19.3 precedent). Verified on the banked build.
6. **REPL-piped tests** cover: interpret-time get + set (AC1, AC2); compile-time
   `TO` via a `: BUMP …` definition with cumulative re-run (AC3); the
   not-a-VALUE `-32` THROW (against a CONSTANT and a `:` word) and the
   undefined-name `-13` THROW (AC4); and a banked round (AC5: define in bank N,
   read + write cross-bank). Each probe line ≤ TIB_SIZE=128 and passes
   word-existence pre-flight (S12).
7. **Compliance + journal docs reconciled.** `docs/ans-forth-core-compliance.md`
   rows §6.2.2405 (`VALUE`, line 458) and §6.2.2295 (`TO`, line 453) flipped
   from `Deliberately-omitted` to `Implemented` with Source file:line, Closure
   `Story 23.2`, and Notes (code-field layout + banked-stub note + `-32`
   validation). `docs/throw-codes.md:106` `-32` row flipped to
   `done — Story 23.2` with the EQU citation.
8. **No regression.** Full `make test-repl` (iz-cpm) holds at the 975-PASS
   baseline; `test-repl-banking`, `test-straddle-regression`, and the new
   VALUE/TO probe all green. Binary delta recorded and itemised at close.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev Notes.
  - Do NOT inherit Story 23.1's reported number — re-`wc -c` from the actual
    current build artifact (B.3 / Lesson 13.5-F). 23.1 reported 28499 B at its
    close; confirm the live value before editing. **Confirmed live baseline =
    28499 B (clean `make` from committed source).**
- [x] Capture current `make test-repl` baseline pass count (expect 975/0) and
      `test-repl-banking` count. **975/0 · banking 62/0 (incl. CL-tail + iron-spike).**

### Story tasks

- [x] Task 1 — Add `DOVALUE` runtime handler (AC: 1, 4)
  - [x] In `src/inner_interpreter.asm`, add `DOVALUE` adjacent to `DOCON`
        (:85-97). Recommended: 3-byte trampoline `DOVALUE: JP DOCON` (distinct
        address for TO's type-check; shared runtime). VERIFY under NEXT that
        HL (= code-field addr) survives the JP→JP so DOCON reads cf+3 correctly.
  - [x] If the trampoline misbehaves, fall back to a full DOCON-body clone;
        re-itemise the byte cost (B.2).
  - [x] Add a `why` comment (distinct handler enables `TO` type discrimination),
        no provenance (feedback_source_comment_discipline).

- [x] Task 2 — Implement `VALUE` defining word (AC: 1, 5)
  - [x] Add `w_VALUE` / `w_VALUE_cf` (DEFCODE "VALUE", 0) in `src/compiler.asm`,
        adjacent to `w_CONSTANT_cf` (:872-906). Structure = CONSTANT's body but
        emit `JP DOVALUE` (not `JP DOCON`) and store the cell value `x`.
  - [x] **MUST include the CREATE-style bank-aware stub block** (clone
        `w_CREATE_cf` :822-851): if `current_bank > 0`, call `stub_allocate`,
        overwrite the reserved xt-cell at `(bh_stub_xt_addr)` with the stub
        address, point LATEST at the stub. Do NOT skip this (finding (3) —
        skipping is a silent AC5 failure). The EXX register discipline must
        match CONSTANT/CREATE (TOS/value in shadow set; body scratch is
        alt-set) — audit per S7.
  - [x] Zero-length name → `-16` THROW (reuse the CONSTANT `.const_no_name`
        tail / `THROW_ZERO_LEN_NAME`).

- [x] Task 3 — Implement the shared resolve+store routine (AC: 2, 5)
  - [x] Write one routine `( x xt -- )`: discriminate xt byte 0 (0xEF stub vs
        0xC3 bank-0 CFA, finding (4)); compute (target_bank, cell_addr=CFA+3);
        store `x` bank-aware (fast path when bank==0 or bank==current_bank;
        else map via `sw_map_bank` / restore via `sw_restore_slot2`, the FIND
        paging helpers in `src/dictionary.asm`).
  - [x] This routine is the single source of truth for the store; Task 4
        (interpret `TO`) and Task 5 (`(TO)` runtime) both call it.

- [x] Task 4 — Implement `TO` (IMMEDIATE, STATE-aware) (AC: 2, 3, 4)
  - [x] Add `w_TO` / `w_TO_cf` (DEFCODE F_IMMEDIATE / DEFIMMED) in
        `src/compiler.asm`. Parse the next name via the tick path
        (`BL WORD FIND`, cf. `w_TICK_cf` :29-54); undefined → `-13` (reuse the
        tick miss handler).
  - [x] Verify the resolved target is a VALUE: page in its bank if it's a stub,
        read the CFA's `JP` operand, compare to `DOVALUE`'s address; mismatch →
        `-32` (`THROW_INVALID_NAME_ARG`). Restore any bank paging on every exit
        path (S7).
  - [x] Read STATE (`IY+UserArea.state`): if interpreting, call the Task 3
        routine with `x = TOS`; if compiling, compile `LIT <xt>` + `(TO)`
        (finding (6) — compile the xt, never a raw cell address).

- [x] Task 5 — Implement `(TO)` runtime helper (AC: 3, 5)
  - [x] Add `w_PAREN_TO` / `w_PAREN_TO_cf` (DEFCODE "(TO)", 0) — a non-IMMEDIATE
        runtime word `( x xt -- )` that calls the Task 3 routine. Compiled by
        `TO` in compile mode. Name it `(TO)` per the kernel's paren-internal
        convention (cf. `(stub-allocate)`, `(BANK-PROMPT)`).

- [x] Task 6 — Wire THROW `-32` (AC: 4, 7)
  - [x] `src/constants.asm` (near :148): `THROW_INVALID_NAME_ARG EQU -32` with
        the comment `; ANS Forth 1994 §9.3.5` (CCD-3 citation discipline).
  - [x] `src/exception.asm` `throw_desc_table` (~:824-925): insert in code order
        (before the `-37` entry) `DW -32 / DB <len> / DB "invalid name argument"`.
        Confirm `len` matches the string exactly.
  - [x] `docs/throw-codes.md:106`: flip the `-32` row to `done — Story 23.2`
        with the EQU reference.

- [x] Task 7 — REPL-piped probe (AC: 6)
  - [x] Author `tests/value_to_tests.fth` (or wire into the banking suite for
        the banked round): interpret get/set; `: BUMP X 1 + TO X ;` with two
        runs asserting cumulative increment; `-32` round (`42 CONSTANT K   1 TO K`
        → −32, and `TO` on a `:` word → −32); `-13` round (`TO UNDEFINEDXYZ`);
        banked round (`5 BANK! 7 VALUE Y   0 BANK!   Y` → 7, `8 TO Y   Y` → 8).
  - [x] Bad-operand/THROW rounds: prefer UNCAUGHT throws if any caught-path
        cleanup is stateful (cf. Story 23.1's CATCH-leaves-asm_mode gotcha) —
        verify whether a caught `-32`/`-13` leaves residue; document the choice.
  - [x] Word-existence pre-flight + TIB-128 line lint (S12). Wire a `make`
        target if `test-repl` can't reach a file list (cf. 23.1's
        `test-repl-asm`).

- [x] Task 8 — Compliance doc rows (AC: 7)
  - [x] `docs/ans-forth-core-compliance.md`: flip §6.2.2405 (`VALUE`, :458) and
        §6.2.2295 (`TO`, :453) to `Implemented`, Source `src/compiler.asm:<line>`
        / `src/inner_interpreter.asm:<line>`, Closure `Story 23.2`, Notes per
        the row schema (`§ | Rule | Verdict | Source | Closure | Notes`,
        doc :12). Keep the `i*x "<spaces>name"` signatures already in the rows.
  - [x] Update the line-873 cross-reference note (which states VALUE/TO are
        `Deliberately-omitted`) if it is now stale.

- [x] Task 9 — Regression + close (AC: 8)
  - [x] `make test-repl` (975/0) · `test-repl-banking` · `test-straddle-regression`
        · the new VALUE/TO probe · `check-doc-sync` 0-drift. Record final
        `wc -c` and the itemised delta vs the pre-edit baseline in Dev Notes.
  - [x] S9 hardware-smoke (binary-delta story): run the banked-VALUE probe on
        real CP/M 2.2 / MicroBeast; post the smoke recipe in the CLOSING CHAT
        MESSAGE (feedback_post_hw_smoke_steps_at_review — STRONG).

## Dev Notes

### Recommended design (synthesised from the live kernel map)

**VALUE** = a defining word shaped like `CONSTANT` (`w_CONSTANT_cf`,
compiler.asm:872-906) — `build_header`, emit code field, store the cell — with
two deliberate differences:
1. Emit `JP DOVALUE` instead of `JP DOCON`, so `TO` can recognise a VALUE by its
   code field (finding (2)).
2. Append the CREATE-style bank-aware stub block (`w_CREATE_cf`:822-851), so a
   bank-N>0 VALUE gets a descriptor stub and a bank-stable xt (finding (3)).
   CONSTANT lacks this block — do not be misled by VALUE's surface similarity to
   CONSTANT.

**DOVALUE** runtime = push the cell at cf+3 (identical to `DOCON`,
inner_interpreter.asm:85-97). Cheapest: `DOVALUE: JP DOCON` (3 bytes, distinct
address). Verify HL survives the double-JP under NEXT.

**TO** = IMMEDIATE + STATE-aware. Parse name (tick path, compiler.asm:29-54),
resolve xt (stub vs CFA, finding (4)), verify DOVALUE (else −32), then branch on
STATE: store-now (interpret) or compile `LIT <xt> (TO)` (compile). Both store
routes funnel through one resolve+store routine (finding (7)).

**Cross-bank store**: map the target bank into the window with the FIND paging
helpers (`sw_map_bank` / `sw_restore_slot2`), write cell = CFA+3, restore. The
cross-bank READ is already free via the stub dispatcher
(banking.asm:1305-1339). The compiled XT (not a raw cell address) is what keeps
the banked compile path correct.

### Byte-budget rationale (itemised — B.2, no "mirrors" shorthand)

Per-component opcode/data estimate (fixed memory). Each line is an independent
itemisation of the new component, not a comparison to a prior story:

- **DOVALUE handler** — `JP DOCON` trampoline: 3 B. (Full clone alt ≈ 14 B.)
- **VALUE code-field emit** — `LD (HL),0xC3` + 2× (`INC HL` / `LD (HL),imm`) for
  the JP DOVALUE: ≈ 9 B; value-cell emit via the EXX/`LD A` dance (as CONSTANT):
  ≈ 12 B; HERE update (4× `LD (IY+d),r`): ≈ 8 B; entry/exit `EXX` + `POP BC` +
  `NEXT`: ≈ 6 B. VALUE core subtotal ≈ **35 B**.
- **VALUE bank-stub block** (clone of w_CREATE_cf :822-851): `LD A,(current_bank)`
  + `OR A` + `JR Z` guard ≈ 6 B; `stub_allocate` call + cell-overwrite +
  LATEST-update (`LD HL,(bh_stub_xt_addr)` / `INC`×2 / `EX DE,HL` / `CALL` /
  reload / store cell / store LATEST): ≈ 28 B. Subtotal ≈ **34 B**.
- **TO body** — parse-name (reuse tick: `CALL`/threaded ≈ 6 B); xt-resolve
  branch (test byte0 0xEF, load bank+CFA or fall through): ≈ 14 B; DOVALUE
  verify (page-in if stub, read JP operand, `LD HL,DOVALUE` + 16-bit compare,
  −32 raise): ≈ 22 B; STATE branch (`LD A,(state)` / `OR` / `JR`): ≈ 6 B;
  compile arm (compile LIT xt + compile (TO) xt): ≈ 12 B; interpret arm (call
  resolve+store): ≈ 4 B. Subtotal ≈ **64 B**.
- **(TO) runtime helper** — DEFCODE wrapper `( x xt -- )` calling the shared
  routine: ≈ 8 B.
- **Shared resolve+store routine** — xt discriminate (reuse part of TO's resolve
  or factor it here): bank fast-path test ≈ 8 B; map/store/restore (`sw_map_bank`
  / `LD (cell)` / `sw_restore_slot2`): ≈ 22 B. Subtotal ≈ **30 B**.
- **THROW −32**: EQU = 0 binary B; `throw_desc_table` row = `DW`(2) + `DB len`(1)
  + `"invalid name argument"`(21) = **24 B**.
- Header name strings (`VALUE`, `TO`, `(TO)`) via DEFCODE macro: ≈ 5+2+4 + per-
  header overhead ≈ **20 B**.

**Story total ≈ 35 + 34 + 64 + 8 + 30 + 24 + 20 ≈ 215 B** (recommended
trampoline DOVALUE). **This exceeds the epic's rough ≈120 B figure**
(epics-phase5-epic-23.md:210) — the overage is the cross-bank machinery the epic
estimate did not fully price: the bank-stub block (~34 B, finding (3)) and the
bank-aware resolve+store (~30 B). This is consistent with the Epic-17 envelope-
reality calibration (estimates run low; project_epic17_envelope). Re-measure the
actual delta at close (Task 9) and record the real per-component breakdown; if a
DOCON-clone is chosen over the trampoline, add ~11 B. The aggregate Epic-23
budget (≈300 B, epic :147-149) absorbs this; flag at the 23.5 CCD-4 gate if the
aggregate is threatened.

### Source tree components to touch

- `src/inner_interpreter.asm` — add `DOVALUE` near `DOCON` (:85-97).
- `src/compiler.asm` — add `w_VALUE_cf` (near CONSTANT :872-906), `w_TO_cf`,
  `w_PAREN_TO_cf`, and the shared resolve+store routine. Reuse the tick path
  (:29-54), `w_LITERAL_cf` (:772-792), `w_COMPILE_COMMA_cf` (:485-497).
- `src/constants.asm` — `THROW_INVALID_NAME_ARG EQU -32` (near :148).
- `src/exception.asm` — `throw_desc_table` `-32` message row (~:824-925).
- `tests/value_to_tests.fth` — NEW probe (AC6); + `make` target if needed.
- `tests/banking_tests.fth` — banked round (AC5) if the banked probe lands here.
- `docs/ans-forth-core-compliance.md` — flip rows :453 (TO), :458 (VALUE);
  fix the :873 cross-ref note.
- `docs/throw-codes.md` — flip the `-32` row (:106).

### Testing standards summary

REPL-piped Forth probes are the default (S2). Assert OBSERVABLE behaviour: that
`X` pushes the stored value, that `TO` changes it, that `BUMP` is cumulative,
that the wrong target THROWs the right code. For the banked round, assert the
value survives a `BANK!` round-trip (read AND write cross-bank). Keep every probe
line ≤ TIB_SIZE=128 (S12, feedback_tib_size_inline_comments); word-existence
pre-flight every new word before use. Binary-delta story → S9 hardware-smoke on
real CP/M 2.2 / MicroBeast required before done; post the recipe in the closing
chat message (feedback_post_hw_smoke_steps_at_review).

### Banking gotchas (carried-forward, verify empirically)

- A defining word in bank N>0 needs an explicit descriptor stub or its xt is
  home-bank-only (project_banked_marker_no_stub). VALUE follows the Story 19.3
  CREATE precedent (finding (3)).
- bank-0 runtime words have no stub xt — for them `TO`'s resolve path takes the
  0xC3/raw-CFA branch (finding (4); cf. the memory note "use `'` not `LATEST @`"
  in project_phase4_scope for bank-0 xt access).
- Per-bank triple = (HERE, LATEST, wordlist-head) only; the shared bucket array
  is NOT swapped (project_bank_triple_excludes_buckets) — relevant if any
  "corruption" symptom appears during the banked round; verify before chasing.
- The `#` immediate gotcha (2-cell operand) bit Story 23.1; not expected here
  (VALUE/TO take normal single cells), but be alert if any operand surprises.

### Project Structure Notes

- No new kernel file; no new UserArea cells. VALUE/TO live in `src/compiler.asm`
  with the rest of the defining/compiling words; DOVALUE with the other DO*
  handlers in `src/inner_interpreter.asm`.
- `TO` is the first STATE-aware *parsing* word added since the Phase-4 recogniser
  work; it composes with the banked compiler via the descriptor-stub xt contract
  (Story 18.x/19.x/20.1), not by special-casing.
- ANS bearing: Core-Extension word set (§6.2). The compliance doc rows are the
  source of truth for the §-numbers (NOT the epic — finding (1)).

### References

- [Source: src/inner_interpreter.asm:85-97] — `DOCON` (VALUE runtime model)
- [Source: src/inner_interpreter.asm:63-79] — `DOVAR`; :99-126 `DODOES`
- [Source: src/compiler.asm:872-906] — `w_CONSTANT_cf` (VALUE body model)
- [Source: src/compiler.asm:802-853] — `w_CREATE_cf`; :822-851 the bank-stub block VALUE must clone
- [Source: src/compiler.asm:314-362] — `build_header` stub-xt cell reservation (`bh_stub_xt_addr`, `F_HAS_STUB_XT_CELL`)
- [Source: src/compiler.asm:685-731] — colon `;` descriptor-stub allocation (stub-xt contract reference)
- [Source: src/compiler.asm:29-54] — `w_TICK_cf` (BL WORD FIND + −13 on miss; TO's name-parse model)
- [Source: src/compiler.asm:60-66] — `w_BRACKET_TICK_cf` (TICK + LITERAL; compile-an-xt model)
- [Source: src/compiler.asm:772-792] — `w_LITERAL_cf`; :485-497 `w_COMPILE_COMMA_cf`
- [Source: src/compiler.asm:930-940] — STATE compile-only guard pattern (−14 example)
- [Source: src/dictionary.asm:25-92] — `FIND`; :113-233 `search_wid_for_name`; :195-202 stub-xt extraction; `sw_map_bank`/`sw_restore_slot2` paging
- [Source: src/banking.asm:1068-1083] — `stub_allocate` (4-byte stub: 0xEF/bank/addr)
- [Source: src/banking.asm:1305-1339] — `stub_dispatch` (cross-bank read path); :1219 `IN-BANK`; :149-162 `BANK@`; :211-318 `BANK!`
- [Source: src/outer_interpreter.asm:30-37] — `STATE`; :191-211 INTERPRET STATE branch
- [Source: src/constants.asm:~148] — THROW EQU insertion point
- [Source: src/exception.asm:824-925] — `throw_desc_table` (message-row insertion)
- [Source: docs/throw-codes.md:106] — `-32 invalid name argument (e.g., TO xxx)` (ANS §9.3.5; currently unwired)
- [Source: docs/ans-forth-core-compliance.md:453] — §6.2.2295 `TO` row to flip; :458 §6.2.2405 `VALUE` row to flip; :12 row schema; :873 stale cross-ref
- [Source: _bmad-output/implementation-artifacts/19-3-create-does-cross-bank-explicit-doer-stub-data-cell-pfa-layout.md] — CREATE cross-bank doer-stub precedent (finding (3))
- [Source: _bmad-output/planning-artifacts/epics-phase5-epic-23.md#Story-23.2] — epic spec (FR-P5-1, FR-P5-2); note §-number errata (finding (1))
- [Memory: project_story20_1_fat_pointers] — bank-aware FIND via inline 24-bit fat pointers; stub-xt contract
- [Memory: project_banked_marker_no_stub] — a defining word in bank N>0 needs a stub or its xt is home-bank-only
- [Memory: project_bank_triple_excludes_buckets] — per-bank triple is (HERE,LATEST,head) only; buckets shared
- [Memory: project_tos_in_register] — BC = TOS; NOS on SP
- [Memory: feedback_source_comment_discipline] — comment the why, never provenance
- [Memory: feedback_no_preexisting_discharge] — correctness defects surfaced + fixed, not accepted
- [Memory: feedback_post_hw_smoke_steps_at_review] — STRONG: post HW-smoke recipe in the closing chat message
- [Memory: feedback_tib_size_inline_comments] — probe lines ≤ TIB_SIZE=128
- [Memory: project_epic17_envelope] — epic byte estimates run low; re-derive per-component

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Opus 4.8)

### Debug Log References

- Pre-edit baseline: `wc -c build/antforth.com` = **28499 B** (clean build from
  committed source); `make test-repl` = **975/0**; `make test-repl-banking` = 62/0.
- All 7 ACs smoke-verified interactively under `iz-cpm-banking` before the formal
  probe was wired (interpret get/set → 42/99; compiled `BUMP` ×3 → 3; `1 TO K`
  (CONSTANT) and `1 TO FOO` (`:` word) → -32; `5 TO NOSUCHWORD` → -13; banked
  `5 BANK! 7 VALUE Y / 0 BANK! Y → 7 / 8 TO Y / 5 BANK! Y → 8`).
- **Banking-gate halt root-caused (NOT a VALUE/TO defect):** the +310 B kernel
  growth pushed `tests/banking_tests.fth`'s bank-0 dictionary so HERE at
  `_probe-plus-bank-cap` moved $7F30 → $8066. The probe's colon body then
  straddled the $8000 slot-2 window; after the 29-bank seed + cap ops, the IP
  crossing into the body's >$8000 tail tripped the F1-unguardable straddle halt
  (the class `test-straddle-regression` enumerates). Confirmed empirically: the
  same probe run in isolation (HERE=$7378, body <$8000) completes; the full run
  (HERE=$8066) halts exactly at the >$8000 crossing. Per user direction, fixed
  the TEST PROBE (not the feature): drove the cap orchestration at INTERPRET
  level so the running IP stays kernel-resident (<$8000), matching Probe-A/C's
  deliberate design. (Note: `[']` is compile-only — switched to `'` for the
  interpret-level tick.)

### Implementation Plan

VALUE = a CONSTANT-shaped defining word with two changes: emit `JP DOVALUE` (new
3-byte `JP DOCON` trampoline at a distinct address, so TO can type-check by code
field) and append the CREATE-style bank-aware descriptor-stub block (so a bank-N>0
VALUE has a bank-stable xt and is read+written cross-bank). TO = threaded
`DEFIMMED` word: `'` (name parse, -13 on miss) → `to_verify` (require the code
field to be `JP DOVALUE`, else -32) → `STATE @ ?BRANCH` → interpret arm calls
`(TO)`, compile arm emits `LITERAL <xt>` + `(TO)`. `(TO)` and `to_verify` both
funnel through one resolver `to_resolve_map_hl` (discriminate stub-xt $EF vs
bank-0 CFA; compute CFA; page the home bank into slot 2 via `to_map_target` only
when the CFA is window-resident and the bank ≠ current), with `to_unmap`
restoring the caller's slot-2 page. Cross-bank READ is already free via the
descriptor stub's `stub_dispatch`. -32 wired: `THROW_INVALID_NAME_ARG EQU -32`
(constants) + `throw_desc_table` row (exception). Compile-mode compiles the
bank-stable XT, never a raw window cell address.

### Completion Notes List

- All 8 ACs satisfied and verified. New `make test-repl-value-to` probe: 7/7
  (interpret get/set; compiled cumulative `BUMP`; banked cross-bank read+write
  inside a compiled colon body; two -32 rounds (CONSTANT + `:` word); one -13).
- Regression gates green: `test-repl` 975/0 (baseline held); `test-repl-banking`
  62/0; `test-repl-asm` 5/0 (Story 23.1 untouched); `test-straddle-regression`
  3/3; `test-repl-banking-isolated` 6/0; `…-21-3` 6/0; `check-doc-sync` 0 drift.
- **Binary: 28499 → 28809 B = +310 B.** Itemised (exact, sums to +310):
  DOVALUE 3, VALUE 88 (hdr 9 + body 79 incl. stub block), TO 35 (hdr+DOCOL 9 +
  13-cell thread 26), (TO) 33 (hdr 8 + body 25), to_verify 40, to_resolve_map_hl
  46, to_map_target 24, to_unmap 15, scratch 2, throw_desc_table -32 row 24,
  EQU 0. Over the epic's
  rough ~120 B and the story's ~215 B estimate: the overage is the bank-aware
  resolve/map/unmap trio (85 B) + to_verify (40 B) coming in heavier than the
  ~30+22 B sketched — consistent with `project_epic17_envelope` (estimates run
  low). Aggregate Epic-23 budget (~300 B) is now mostly consumed by 23.2+23.1;
  flag at the 23.5 CCD-4 gate.
- DOVALUE trampoline verified empirically: `JP DOVALUE → JP DOCON` leaves HL (=
  code-field addr) intact, so DOCON's cf+3 read lands on the value cell (chosen
  over the ~14 B full clone).
- **Test-probe restructure (in scope per user decision):** `_probe-plus-bank-cap`
  is now interpret-level driven; the verdict is asserted by the Makefile on the
  printed witnesses `seeded: 29` / `cap-catch-code: -2` / `cap-banks-after: 29` +
  end sentinel (no compile-mode IF/THEN, hence no straddle-prone verdict body).
  This makes the probe robust to future kernel growth. The underlying
  bank-0-dictionary-vs-$8000 envelope pressure is a recurring structural issue
  (not unique to 23.2) and is surfaced for a possible test-infra follow-up.

### File List

- `src/inner_interpreter.asm` — added `DOVALUE` (`JP DOCON` trampoline) after DOCON.
- `src/compiler.asm` — added `w_VALUE`/`w_VALUE_cf`, `w_TO` (threaded DEFIMMED),
  `w_PAREN_TO`/`w_PAREN_TO_cf` (`(TO)`), `to_verify`, `to_resolve_map_hl`,
  `to_map_target`, `to_unmap`, scratch cells `to_saved_page`/`to_switched`.
- `src/constants.asm` — added `THROW_INVALID_NAME_ARG EQU -32` (ANS §9.3.5 cite).
- `src/exception.asm` — added `-32 "invalid name argument"` row to `throw_desc_table`.
- `tests/value_to_tests.fth` — NEW self-asserting VALUE/TO probe (AC6).
- `tests/banking_tests.fth` — restructured `_probe-plus-bank-cap` to interpret-level
  driving (straddle-robust; AC8 banking gate).
- `Makefile` — added `VALUE_TO_PROBE` + `test-repl-value-to` target (and `.PHONY`);
  updated the plus-bank-cap assertion to the new interpret-level witnesses.
- `docs/ans-forth-core-compliance.md` — flipped §6.2.2405 (VALUE) and §6.2.2295 (TO)
  to Implemented; refreshed the BANKS row cross-reference note.
- `docs/throw-codes.md` — flipped the -32 row to `done — Story 23.2`.

### Change Log

- 2026-06-28 — Story 23.2 implemented: `VALUE` / `TO` (ANS Core-Ext §6.2.2405 /
  §6.2.2295) with full banked interoperability (descriptor-stub xt; bank-aware
  cross-bank store; cross-bank read via the stub dispatcher). Wired THROW -32
  (`invalid name argument`) for `TO` on a non-VALUE; -13 reused for undefined
  names. Added `test-repl-value-to` probe. Restructured the banking-suite
  +BANK-cap probe to interpret-level driving so it is robust to the $8000
  straddle boundary. Binary 28499 → 28809 B (+310 B). All gates green.
- 2026-06-28 — Code-review resolution (4 findings fixed): (1) `test-repl-value-to`
  verdict greps anchored to column 0 (`^PASS:`) + `^FAIL:` negative guard — the
  prior `."`-prefix strip missed the indented colon-body echo, so the five
  `value-*` assertions could false-PASS on echoed source even if the runtime
  printed FAIL. (2) `to_resolve_map_hl` now guards the `$EF` stub-marker read on
  HL being fixed-memory; a window-resident xt is a bank-0 portal CFA (never a
  stub), closing a data-dependent foreign-bank misread → wild cross-bank write
  when `TO`-ing a bank-0 window VALUE from another bank. (3) refreshed the stale
  banking_tests.fth cap-probe comment (removed `test-repl-banking-skip` /
  `cap-check-fired-after-29-seed` references). (4) removed the dead `CP $FF`
  branch in `to_resolve_map_hl`. Findings #4 (forged `JP DOVALUE` CODE word)
  left as accepted — contrived, standard type-check idiom. Rebuilt clean; main
  regression + banking + value/to probes all green.
