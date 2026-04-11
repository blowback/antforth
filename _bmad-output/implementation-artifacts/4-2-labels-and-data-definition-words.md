# Story 4.2: Labels & Data Definition Words

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Forth user,
I want explicit named labels (with forward references) and data definition words in the assembler,
so that I can write readable assembly code without manually counting bytes for jump offsets, and embed data tables and named constants in my CODE words.

## Acceptance Criteria

1. **Given** the user is at the top of a CODE definition, before any opcodes have been emitted **When** they type `LABEL TOP` **Then** `LABEL` parses the next whitespace-delimited word from input (`TOP`) and installs it as a normal Forth dictionary entry whose runtime behaviour is to push a *label tag* identifying its slot in the per-CODE label pool **And** a fresh slot is allocated in the per-CODE label pool, marked unresolved (no target address yet) **And** HERE is unchanged (the new dictionary entry's bytes live in a separate side area, not in the CODE word's body) **And** subsequent uses of `TOP` inside this CODE definition push the same label tag.

2. **Given** the user has called `LABEL FOO` after at least one opcode byte has already been emitted (i.e. HERE has moved past the start of the CODE body) **When** `LABEL` runs **Then** it errors with `LABEL must precede opcodes ?` and ABORTs cleanly. The "all labels at the top" rule is enforced by comparing the current HERE against `asm_saved_here` (the start-of-body recorded by `CODE`). **Rationale**: forcing all label declarations to the top makes CODE words easy to read and removes any temporal-coupling subtlety in label visibility.

3. **Given** a CODE definition where `LABEL TOP` has been declared but `TOP` has not yet been fixed **When** the user types `TOP FIX` **Then** `TOP` pushes its label tag, `FIX` consumes the tag from TOS, marks the corresponding label slot as *resolved* with target address = current HERE, then walks the fixup table and patches every queued forward reference to that label (each fixup is patched per its kind: JR-displacement or DW-absolute) **And** `FIX` errors with `FOO already fixed ?` if the slot is already resolved **And** `FIX` errors with `bad operand ?` if TOS is not a label tag (e.g. a plain integer or a register tag).

4. **Given** a CODE definition with a backward jump using a previously-fixed label:
   ```
   CODE BL1
     LABEL TOP
     TOP FIX
     A A LD,
     TOP JR,
     NEXT,
   END-CODE
   ```
   **When** `TOP JR,` runs **Then** `TOP` pushes its label tag and `JR,` recognises the tag, looks up the slot (which is *resolved*), emits `0x18` (JR opcode) followed by the **signed 8-bit displacement** computed as `target - (jr_pc + 2)` where `target` is `TOP`'s recorded address and `jr_pc` is the address of the JR opcode byte just emitted **And** the displacement is in range −128..+127 (out-of-range produces a clean error — see AC10).

5. **Given** a CODE definition with a forward jump using a label that is declared but not yet fixed:
   ```
   CODE FW1
     LABEL SKIP
     SKIP JR,
     0xFF DB,
     SKIP FIX
     NEXT,
   END-CODE
   ```
   **When** `SKIP JR,` runs **Then** `SKIP` pushes its label tag and `JR,` recognises it as *unresolved* — emits the JR opcode (`0x18`) followed by a placeholder displacement byte (initially `0`), then queues a fixup record (kind = JR-disp, label index, patch address = the displacement byte's address) **And** when `SKIP FIX` later runs, `FIX` walks the fixup table and patches the placeholder with the correct signed displacement.

6. **Given** a CODE definition using `DB,` **When** the user types e.g. `0x42 DB,` **Then** the byte `0x42` is assembled at HERE and HERE advances by 1 (semantically equivalent to the existing `C,` byte-comma but only callable inside CODE; calling `DB,` outside a CODE definition prints `not in CODE ?` and ABORTs cleanly).

7. **Given** a CODE definition using `DW,` **When** the user types e.g. `0x1234 DW,` **Then** the 16-bit value `0x1234` is assembled at HERE in **little-endian** order (low byte first) and HERE advances by 2. Outside CODE, `DW,` errors with `not in CODE ?`.

8. **Given** a CODE definition using `DW,` with a label tag operand **When** the user types e.g. `MYTABLE DW,` (where `MYTABLE` was declared via `LABEL MYTABLE` at the top of the CODE definition) **Then** for the *resolved* case, `MYTABLE`'s recorded 16-bit address is emitted little-endian; for the *unresolved* case, two placeholder bytes (`0x00 0x00`) are emitted and a fixup record (kind = DW-absolute) is queued for later patching by `MYTABLE FIX`.

9. **Given** a CODE definition using `DS,` **When** the user types e.g. `10 DS,` **Then** 10 bytes of zero are reserved at HERE and HERE advances by 10. The count is taken from TOS and consumed; passing `0 DS,` is a no-op; passing a negative count errors with `bad operand ?` and ABORTs cleanly. Outside CODE, `DS,` errors with `not in CODE ?`.

10. **Given** the user types e.g. `0x42 EQU PORT-A` **at the interpret prompt (i.e. outside any CODE definition)** **When** `EQU` executes **Then** a new word `PORT-A` is added to the dictionary as a normal Forth CONSTANT whose value is `0x42` **And** subsequent occurrences of `PORT-A` (inside a CODE definition or in interpret mode) push `0x42` on the stack — i.e. `PORT-A DB,` inside CODE emits the byte `0x42`. **And** `EQU` called *inside* a CODE definition errors with `EQU outside CODE only ?` and ABORTs cleanly without corrupting the in-progress CODE word.

11. **Given** any of the error conditions: out-of-range JR displacement, `FIX` on an already-fixed label, `FIX` with a non-label-tag operand, unresolved fixup at END-CODE, `DS,` with negative count, `LABEL` after opcodes, label-pool overflow (more than 16 labels in one CODE word), fixup-pool overflow, or any of `LABEL`/`FIX`/`DB,`/`DW,`/`DS,` outside CODE **When** the offending word runs **Then** the assembler prints a descriptive `subject ?` message via `asm_print_error` (or `asm_print_error_with_name` for messages that include a label name), jumps to `w_ABORT_cf`, and `asm_cleanup` restores HERE, the hash bucket head for the new CODE word, **unlinks all label dictionary entries from the hash buckets**, and clears `asm_mode` and the label/fixup pools — leaving the user at a clean `ok` prompt with no orphan dictionary entry, no leaked label words, and no stale label state.

12. **Given** the unknown-word path in `INTERPRET` **When** an unknown identifier is encountered inside a CODE definition (e.g. a misspelt opcode like `PUHS,`) **Then** the existing `word ?` error path runs unchanged: `PUHS, ?` is printed and the system aborts via `w_ABORT_cf`, which calls `asm_cleanup` to roll back the half-built CODE word. **Story 4.2 makes no changes whatsoever to `outer_interpreter.asm`.** Labels are normal Forth dictionary entries created by `LABEL` (a parsing word) and looked up via the standard FIND path, so the existing INTERPRET logic handles them with no special-casing. This is the **typo guard**: there is no mechanism by which a misspelt unknown word can be silently turned into anything other than the standard error.

13. **Given** a CODE definition that mixes labels, opcodes from Story 4.1, and a data definition **When** the user types the canonical end-to-end example:
    ```
    CODE JMPTEST
      LABEL TOP
      TOP FIX
      A B LD,
      TOP JR,
      NEXT,
    END-CODE
    ```
    **Then** the assembled body is exactly 3 bytes plus the NEXT template: `0x78` (LD A,B at offset 0) + `0x18 0xFD` (JR -3 at offsets 1-2, displacement = `0 - (1+2) = -3 → 0xFD`) + NEXT macro template starting at offset 3. The encoding is verifiable via a follow-on test (see AC15). This AC tests *encoding*, not runtime behaviour — `JMPTEST` would loop forever if called.

14. **Given** all 73 existing regression tests (`make test`) **And** all 89 existing REPL tests (`make test-repl`) **When** both test targets run after this story's changes **Then** every pre-existing test still passes with identical output **And** the EXPECTED string for `make test` is unchanged. **Critical:** because Story 4.2 makes no changes to `outer_interpreter.asm`, the regression risk for non-assembler code is low — but the test sweep is still mandatory.

15. **Given** the new REPL tests added for this story **When** `make test-repl` runs **Then** each of the following is verified end-to-end through the actual Forth REPL by reading the assembled body bytes via `' word` + `C@` at known offsets:
    - **Backward JR encoding** — define a CODE word with `LABEL TOP TOP FIX A A LD, TOP JR, NEXT,`; after `END-CODE`, fetch the displacement byte at offset 2 and assert it equals `0xFD = 253` decimal (displacement = `0 - (1+2) = -3`).
    - **Forward JR encoding** — define a CODE word with `LABEL SKIP SKIP JR, 0xFF DB, SKIP FIX NEXT,`; after `END-CODE`, fetch the displacement byte at offset 1 and assert it equals `0x01 = 1` decimal (displacement = `3 - (0+2) = 1`); fetch the DB byte at offset 2 and assert `0xFF = 255`.
    - **DB,/DW,/DS, encoding** — define a CODE word `DATAW` with `0xAA DB, 0x1234 DW, 3 DS, NEXT,`; assert the body bytes read `0xAA 0x34 0x12 0x00 0x00 0x00`.
    - **EQU end-to-end** — `0x42 EQU PORT-A`; `PORT-A .` prints `66`; a CODE word that does `PORT-A DB,` has body byte `0x42`; `WORDS` lists `PORT-A`.
    - **DW, with label** — define a CODE word that uses `LABEL TGT TGT DW, NEXT, ... TGT FIX`. Wait — `TGT FIX` after `NEXT,` is meaningless because `NEXT,` has emitted bytes that the user word will never reach past. Restructure: define a CODE word that uses `LABEL TGT TGT DW, TGT FIX NEXT,` and assert the two DW bytes (offsets 0-1) equal the address of offset 2 (where `TGT FIX` records HERE = body+2). The exact value is variable across builds (depends on dictionary layout), so the test should compute the expected value as `' DATAW2 2 + DUP @` and compare against the body's DW bytes.
    - **Unresolved fixup at END-CODE** — `CODE BAD LABEL X X JR, NEXT, END-CODE` (X is declared but never FIXed) produces `unresolved label X ?`, returns to `ok`, `WORDS` does **not** list `BAD`, and the global dictionary is verifiably unchanged (no leaked `X` entry — verified via a `WORDS` grep).
    - **`FIX` already fixed** — `CODE BAD2 LABEL Y Y FIX A A LD, Y FIX NEXT, END-CODE` produces `Y already fixed ?` and clean recovery; `WORDS` does not list `BAD2` or `Y`.
    - **`LABEL` after opcodes** — `CODE BAD3 A A LD, LABEL Z NEXT, END-CODE` produces `LABEL must precede opcodes ?` and clean recovery; `WORDS` does not list `BAD3` or `Z`.
    - **Out-of-range JR** — a CODE word that fixes a label, emits ≥130 filler bytes via `DS,`, then JRs back to the label; expect `JR out of range ?` and clean recovery.
    - **`LABEL` outside CODE** — `LABEL FOO` at the prompt prints `not in CODE ?` and recovers; same check for `FIX`, `DB,`, `DW,`, `DS,`.
    - **`EQU` inside CODE** — `CODE BAD4 1 EQU FOO NEXT, END-CODE` produces `EQU outside CODE only ?` and clean recovery; `WORDS` does not list `BAD4` or `FOO`.
    - **Typo guard** — `CODE BAD5 LABEL OK PUHS, NEXT, END-CODE` produces the standard `PUHS, ?` error (PUHS, is just an unknown word; the existing INTERPRET error path handles it). After recovery, `WORDS` does not list `BAD5` or `OK` (the label dict entry was unlinked by `asm_cleanup`).
    - **Label scoping across CODE words** — define `CODE A1 LABEL LBL LBL FIX A A LD, NEXT, END-CODE` then `CODE A2 LABEL LBL LBL FIX B B LD, NEXT, END-CODE` — both succeed, both appear in `WORDS`, and after both have completed, `LBL` is **not** in `WORDS` (label entries from each CODE were unlinked at the respective END-CODE).
    - **Label-pool overflow** — declare 17 labels in one CODE word; expect `too many labels ?` on the 17th and clean recovery.
    - **Regression preservation** — every Story 4.1 REPL test (85-89) still produces identical output.

## Tasks / Subtasks

- [x] Task 1: Design and add the per-CODE label/fixup pools and the label dictionary side area (AC: #1, #2, #5, #11)
  - [x] 1.1 In `assembler.asm`, immediately after the existing `asm_tmp` scratch area (line 53), add the **label slot pool**: a fixed-size array of 16 slots, each 8 bytes:
    - 1 byte resolved flag (0 = unresolved, 1 = resolved)
    - 2 bytes target address (valid only when resolved)
    - 1 byte hash bucket index (where the dict entry was linked at LABEL time)
    - 2 bytes previous hash bucket head (for unlink-on-cleanup)
    - 2 bytes pad (round to 8 for clean indexing)
    
    Total: 128 bytes. Define `ASM_LABEL_POOL_SIZE EQU 16` and `ASM_LABEL_REC_SIZE EQU 8` so the size is parameterised in one place.
  - [x] 1.2 Add the **label dictionary side area**: a fixed buffer where `LABEL` builds the dictionary entries for label words (so they don't get assembled into the CODE body at HERE). 256 bytes is plenty (16 entries × ~16 bytes each = 256). Add a separate write pointer `asm_label_dict_top: DW 0` initialised at CODE entry to the base of the side area.
  - [x] 1.3 Add the **fixup pool**: a fixed-size array of 32 fixup records, each 4 bytes:
    - 2 bytes patch address (where the placeholder byte/word lives in the CODE body)
    - 1 byte fixup kind (`ASM_FIXUP_JR EQU 0`, `ASM_FIXUP_DW EQU 1`)
    - 1 byte label index (into `asm_label_pool`)
    
    Total: 128 bytes. Define `ASM_FIXUP_POOL_SIZE EQU 32`.
  - [x] 1.4 Add two single-byte counters: `asm_label_count` (next free label slot, 0..16) and `asm_fixup_count` (next free fixup slot, 0..32). These are reset to 0 by `CODE` and by `asm_cleanup`.
  - [x] 1.5 Document the data layout in a block comment at the top of the new section, including the rationale for fixed-size pools and the side-area-vs-HERE design (label dict entries cannot live at HERE because HERE is assembling native machine code into the CODE word body).
  - [x] 1.6 Sanity check: 128 (slot pool) + 128 (fixup pool) + 256 (dict side area) + counters = ~520 bytes of new data. Verify this fits comfortably in the assembler's data section without pushing past any constraint in `antforth.asm`'s memory map. Story 4.1 added negligible data; this story is the bigger data add for Epic 4.

- [x] Task 2: Implement label slot primitives (AC: #1, #3, #5, #11)
  - [x] 2.1 `asm_alloc_label_slot` — Subroutine. No entry args. Allocates the next free slot in `asm_label_pool`, increments `asm_label_count`. Returns the new slot index in A. If `asm_label_count` is already at the max (16), error `too many labels ?` ABORT via `asm_die`. Initialises the slot's resolved flag to 0; the bucket index and old-head fields will be filled in by `LABEL` after `build_header` completes.
  - [x] 2.2 `asm_resolve_slot` — Subroutine. Entry: A = label index. Marks the slot as resolved, stores HERE as its target address, then walks the fixup table from index 0 to `asm_fixup_count - 1`, and for each fixup whose label index matches, applies the patch via `asm_apply_fixup` and removes the fixup record (compact by swapping in the last record and decrementing `asm_fixup_count`). Errors via `asm_die` if `asm_apply_fixup` fails (out-of-range JR).
  - [x] 2.3 `asm_add_fixup` — Subroutine. Entry: A = label index, B = fixup kind, HL = patch address. Appends a record to the fixup pool; if full, error `too many fixups ?` ABORT.
  - [x] 2.4 `asm_apply_fixup` — Subroutine called from `asm_resolve_slot` for each matching fixup. Entry: HL = pointer to fixup record, A = label index (already known to caller). For kind JR: read the label slot's target address; compute `disp = target - (patch_addr + 1)`; verify range −128..+127 (else error `JR out of range ?` ABORT); store `disp` (low byte of result) at `patch_addr`. For kind DW: store the label's address (low byte at patch_addr, high byte at patch_addr+1).
  - [x] 2.5 `asm_check_unresolved` — Subroutine called from `END-CODE` before SMUDGE-clear. Walks the fixup pool; if any fixup remains, look up the label slot and the corresponding dictionary entry to fetch its name, print `unresolved label NAME ?` via `asm_print_error_with_name` (Task 9), and ABORT. Note: the label name lives in the side area dict entry, not in the slot pool — see 2.6 for how to get a slot index back to a printable name.
  - [x] 2.6 The label slot does NOT directly store the name. To map slot → name for the unresolved error, the slot needs to remember a pointer to its dictionary entry's name field. Add a 2-byte `name_ptr` field to the slot record (raising the slot size from 8 to 10 bytes; update `ASM_LABEL_REC_SIZE EQU 10`, recompute pool size = 160 bytes). `LABEL` writes `name_ptr` after `build_header` returns. Alternatively, store the count_flags address and read the name length from there at unresolved-error time. Pick whichever uses less code. **Default**: store name_ptr.

- [x] Task 3: Implement `LABEL` parsing word (AC: #1, #2, #11)
  - [x] 3.1 `w_LABEL` is a DEFCODE word with the name `LABEL`. Gated by `check_asm_mode` — outside CODE it errors with `not in CODE ?`.
  - [x] 3.2 **"Before any opcodes" check**: read the current HERE; if HERE != `asm_saved_here` (which `CODE` recorded at body start), error `LABEL must precede opcodes ?` and ABORT. This is a single 16-bit comparison; no extra state needed.
  - [x] 3.3 Parse the next word from input via the same pattern `:` (COLON) uses (see `compiler.asm:288-352`). The parsed name is a counted string at the WORD buffer.
  - [x] 3.4 Allocate a fresh slot via `asm_alloc_label_slot` (returns slot index in A; aborts on overflow). Save the index for later.
  - [x] 3.5 **Build the label dictionary entry in the side area**:
    - Save real HERE (= `asm_saved_here`, but read it again from `(IY+UserArea.here)` for safety).
    - Set HERE to `(asm_label_dict_top)`.
    - Call `build_header` with `flags = 0` to install the new entry. `build_header` updates HERE, links the entry into its hash bucket, and returns HL = code field address. **Capture the bucket index from `bh_bucket_index` and the old bucket head from `bh_old_bucket_head` (just like `CODE` does)** — these will be stored in the slot for later unlinking.
    - HL = code field. Emit the label-word body bytes:
      ```
      LD      L, slot_index           ; 2 bytes (LD L, n)
      JP      asm_push_label_tag      ; 3 bytes (JP nn)
      ```
      Total 5 bytes. Use `C,` or direct pokes via HL.
    - Update `(asm_label_dict_top)` to the post-build HERE.
    - Restore real HERE from the saved value.
    - Store the captured bucket index and old-head into the new slot's `bucket` and `old_head` fields.
    - Store the dict entry's name pointer (or count_flags pointer per Task 2.6) into the slot's `name_ptr` field.
    - NEXT.
  - [x] 3.6 `asm_push_label_tag` — Shared tail subroutine for all label words (callable from the body of every label entry). Mirrors `asm_push_tag` (line 202 of assembler.asm) but produces a label tag instead of a register tag:
    ```
    asm_push_label_tag:
            CALL    check_asm_mode          ; refuse outside CODE
            PUSH    BC                      ; save old TOS
            LD      C, L                    ; C = slot index (low nibble)
            LD      B, 0x80                 ; B = high byte (label tag sentinel)
            NEXT
    ```
    The result: TOS = `0x80 | index` packed as `BC = (0x80, index)`. See "Label Tag Encoding" in Dev Notes.
  - [x] 3.7 If a label word is somehow executed outside of any CODE context (e.g. left in the dictionary by a buggy cleanup), `check_asm_mode` rejects it cleanly. This is a defence-in-depth check; correct cleanup means it should never trigger.

- [x] Task 4: Implement `FIX` opcode word (AC: #3, #5, #11)
  - [x] 4.1 `w_FIX` is a DEFCODE word with the name `FIX`. Gated by `check_asm_mode`.
  - [x] 4.2 Pop TOS = label tag. Validate: high byte must be `0x80` (label tag sentinel; see Dev Notes); else `bad operand ?` ABORT. Low byte must be `< asm_label_count`; else `bad operand ?` ABORT (defence against forged tags or out-of-range — should be unreachable in correct user code).
  - [x] 4.3 Look up the slot. If already resolved, error `NAME already fixed ?` (using `asm_print_error_with_name`) ABORT.
  - [x] 4.4 Mark the slot resolved with target = current HERE.
  - [x] 4.5 Walk the fixup pool: for every fixup whose label index matches, call `asm_apply_fixup` (which may itself error on out-of-range JR), then remove the fixup record by swap-with-last + decrement `asm_fixup_count`.
  - [x] 4.6 Pop new TOS. NEXT.

- [x] Task 5: Implement `JR,` opcode word (AC: #4, #5, #11)
  - [x] 5.1 `w_JR_COMMA` is a DEFCODE with the name `JR,`. Gated by `check_asm_mode`.
  - [x] 5.2 `JR,` consumes one operand from TOS:
    - **Label tag** (high byte = 0x80): the standard label-driven JR.
    - **Plain 16-bit literal address**: literal-target JR. Optional — see Q1 in Open Questions; default is to support it.
  - [x] 5.3 Emit the JR opcode byte `0x18` via `asm_emit_byte`. Save the post-emit HERE as `patch_addr` (this is where the displacement byte will go).
  - [x] 5.4 If TOS is a **label tag**: extract the slot index. Look up the slot.
    - If *resolved*: compute `disp = target - (patch_addr + 1)`, verify range −128..+127 (else `JR out of range ?` ABORT), emit `disp` as the displacement byte.
    - If *unresolved*: emit `0x00` as a placeholder displacement byte, then call `asm_add_fixup` with kind `ASM_FIXUP_JR`, the patch address (= the address of the placeholder byte just emitted), and the label index.
  - [x] 5.5 If TOS is a **plain 16-bit address** (high byte ≠ 0x80) and literal-target JR is enabled: compute `disp = target - (patch_addr + 1)`; verify range; emit. If literal-target JR is disabled per Q1, just `JP asm_bad_operand`.
  - [x] 5.6 Pop new TOS. NEXT.
  - [x] 5.7 Note: `JR,` in this story is **unconditional only**. Conditional JR forms (`NZ JR,` etc.), `JP,`, and `CALL,` are Story 4.3; they will reuse the same `asm_add_fixup` / `asm_apply_fixup` plumbing.

- [x] Task 6: Implement data definition words `DB, DW, DS,` (AC: #6, #7, #8, #9, #11)
  - [x] 6.1 `w_DB_COMMA` (name `DB,`): gated by `check_asm_mode`. Pops TOS = value. **Question Q2**: silent low-byte truncation (emit `value & 0xFF`) or strict rejection of values > 0xFF (`bad operand ?`)? Default: silent truncation, consistent with sjasmplus and most cross-assemblers. Document the choice in Dev Notes. Emits the byte via `asm_emit_byte`. Pops new TOS. NEXT.
  - [x] 6.2 `w_DW_COMMA` (name `DW,`): gated by `check_asm_mode`. Pops TOS:
    - If TOS is a **label tag** (high byte = 0x80): look up the slot. If resolved, emit its address little-endian (low then high) via two `asm_emit_byte` calls. If unresolved, emit two `0x00` placeholder bytes, then call `asm_add_fixup` with kind `ASM_FIXUP_DW`, the patch address (= the address of the first placeholder byte), and the label index.
    - If TOS is a **plain integer** (high byte ≠ 0x80): emit low byte then high byte via two `asm_emit_byte` calls.
  - [x] 6.3 `w_DS_COMMA` (name `DS,`): gated by `check_asm_mode`. Pops TOS = count. If count is negative (high bit of high byte set), error `bad operand ?` ABORT. If count is 0, just pop new TOS and NEXT. Otherwise, loop: emit `0x00` `count` times via `asm_emit_byte`. Pops new TOS. NEXT.
  - [x] 6.4 All three words: ensure DE (=IP) and IY (=UP) are preserved across the loops in `DS,` and across the byte emission in `DB,`/`DW,`. The existing `asm_emit_byte` already preserves these (line 187 of assembler.asm — "Preserves: A, BC, DE, IX, IY"); verify before relying on it.

- [x] Task 7: Implement `EQU` parsing word (AC: #10, #11)
  - [x] 7.1 `w_EQU` is a DEFCODE word with the name `EQU`. **Inverse of the other assembler words**: it is *only* allowed when `asm_mode = 0` (interpret mode, outside any CODE definition). If `asm_mode != 0`, error with `EQU outside CODE only ?` and ABORT.
  - [x] 7.2 Inside the allowed path, `EQU` is functionally identical to the existing `CONSTANT`. The smallest implementation is a DEFCODE prologue that checks `asm_mode == 0` (else `asm_die`) then `JP w_CONSTANT_cf` directly. This avoids needing a DEFWORD wrapper at all.
  - [x] 7.3 Verify the resulting `EQU` plays well with `WORDS` (the new constant should appear) and with subsequent uses of the constant (it's a normal Forth word, so this should Just Work — but write the AC10 test to confirm).

- [x] Task 8: Wire label cleanup into `asm_cleanup`, `CODE`, and `END-CODE` (AC: #1, #11)
  - [x] 8.1 In `w_CODE_cf` (assembler.asm:293), at the same point where it sets `asm_mode = 1`:
    - Reset `asm_label_count = 0`.
    - Reset `asm_fixup_count = 0`.
    - Initialise `asm_label_dict_top` to the base of the label dict side area.
  - [x] 8.2 In `w_END_CODE_cf` (assembler.asm:371), **before** clearing SMUDGE:
    - Call `asm_check_unresolved`. If any unresolved fixups remain, that helper prints `unresolved label NAME ?` and ABORTs (which routes through `asm_cleanup` for full rollback).
    - Call `asm_unlink_labels` (Task 8.4) to walk the label slots in **reverse insertion order** and restore each bucket's head from the slot's saved `old_head`. This unlinks all label dictionary entries from the global dictionary in one O(N) pass.
    - Reset `asm_label_count = 0`, `asm_fixup_count = 0`, `asm_label_dict_top = base`. (These resets are also done by `asm_cleanup`, but doing them on the success path keeps the state machine clean.)
    - Then proceed with the existing SMUDGE clear and `asm_mode = 0`.
  - [x] 8.3 In `asm_cleanup` (assembler.asm:137), after restoring HERE and the CODE word's hash bucket head, **also** call `asm_unlink_labels` to unlink any partially-built label entries, then reset `asm_label_count`, `asm_fixup_count`, and `asm_label_dict_top`. The existing per-CODE bucket restore in `asm_cleanup` handles the in-progress CODE word; the new label-unlink handles the labels. Order matters: unlink labels FIRST (they were added AFTER the CODE word's link), then restore the CODE word's bucket head.
  - [x] 8.4 `asm_unlink_labels` — New subroutine. Walks `asm_label_pool` from `asm_label_count - 1` down to 0, and for each slot:
    - Read the slot's `bucket` index and `old_head` value.
    - Compute the bucket address: `&hash_table[bucket * 2]`.
    - Store `old_head` at the bucket address (low byte then high byte).
    
    This restores each bucket's head pointer to its pre-LABEL value. Because labels were added in increasing slot order and each new label was prepended to its bucket's chain, processing in reverse order correctly undoes the chain modifications. The `old_head` value is the bucket head BEFORE that particular LABEL ran, so by restoring it, the new entry is unlinked AND any older entries (including subsequent LABELs in the same bucket) are also handled correctly because we walk in reverse.
  - [x] 8.5 **Important subtlety about unlink ordering**: if two labels happen to land in the SAME hash bucket, label B (later) was prepended on top of label A (earlier). Before label B was added, the bucket head was label A. Before label A was added, the bucket head was the pre-CODE chain. So label B's `old_head` = label A's address; label A's `old_head` = original pre-CODE chain head. Walking in reverse: first restore B's `old_head` (= A's address) → bucket points to A, which is correct intermediate state. Then restore A's `old_head` (= original pre-CODE chain) → bucket points to original chain. Correct. **Verify this reasoning with a unit test** that puts two labels in the same bucket (use names whose hashes collide; since the hash is small (64 buckets), pick two short names by trial — or just use enough labels to guarantee a collision by the pigeonhole principle).
  - [x] 8.6 The CODE word's own dictionary entry was added BEFORE any LABELs (build_header runs in `w_CODE_cf` at line 317, well before any LABEL can run). So the label-unlink walk in 8.4 cannot accidentally affect the CODE word's hash bucket — it walks only the slots in `asm_label_pool`, none of which point at the CODE word.

- [x] Task 9: Add the new error message strings (AC: #11)
  - [x] 9.1 In the error string section of `assembler.asm` (currently lines 56-72), add:
    - `str_asm_unresolved`: `"unresolved label "` (the label name will be appended before the standard ` ?` suffix)
    - `str_asm_already_fixed`: `"already fixed: "` — appended with the label name
    - `str_asm_label_after_op`: `"LABEL must precede opcodes"`
    - `str_asm_jr_range`: `"JR out of range"`
    - `str_asm_too_many_labels`: `"too many labels"`
    - `str_asm_too_many_fixups`: `"too many fixups"`
    - `str_asm_equ_in_code`: `"EQU outside CODE only"`
  - [x] 9.2 Add `asm_print_error_with_name` — A new helper that prints a fixed prefix string followed by a counted-string label name then ` ?` CR LF. Mirrors `asm_print_error` exactly except for the inserted name segment. Used by the `unresolved label NAME ?` and `NAME already fixed ?` error paths.
  - [x] 9.3 Add corresponding `asm_err_*` trampolines (mirroring `asm_err_nested` etc. at lines 117-130) for each new error code. Keep the error-handling layer uniform.

- [x] Task 10: Add REPL tests (AC: #15)
  - [x] 10.1 The next free test number is 90 (Story 4.1 added 85-89). Add tests 90+ to `Makefile` following the pattern at lines 717-747 (Story 4.0 banner tests) and the analogous Story 4.1 block (tests 85-89). One emulator launch per test where convenient; one PASS/FAIL echo per test.
  - [x] 10.2 Test 90 — Backward JR encoding (AC4 / AC15):
    ```
    CODE BL1 LABEL TOP TOP FIX A A LD, TOP JR, NEXT, END-CODE
    ' BL1 2 + C@ .       \ displacement byte at offset 2 = 0xFD = 253
    ```
  - [x] 10.3 Test 91 — Forward JR encoding (AC5 / AC15):
    ```
    CODE FW1 LABEL SKIP SKIP JR, 0xFF DB, SKIP FIX NEXT, END-CODE
    ' FW1 C@ .            \ JR opcode at offset 0 = 0x18 = 24
    ' FW1 1+ C@ .          \ patched displacement = 1
    ' FW1 2 + C@ .         \ DB byte = 0xFF = 255
    ```
  - [x] 10.4 Test 92 — DB,/DW,/DS, encoding (AC6/7/9):
    ```
    CODE DATAW 0xAA DB, 0x1234 DW, 3 DS, NEXT, END-CODE
    ' DATAW C@ .            \ 170 (= 0xAA)
    ' DATAW 1+ C@ .         \ 52  (= 0x34, low byte first)
    ' DATAW 2 + C@ .        \ 18  (= 0x12)
    ' DATAW 3 + C@ .        \ 0
    ' DATAW 4 + C@ .        \ 0
    ' DATAW 5 + C@ .        \ 0
    ```
  - [x] 10.5 Test 93 — EQU end-to-end (AC10):
    ```
    0x42 EQU PORT-A
    PORT-A .                \ 66
    CODE EUSE PORT-A DB, NEXT, END-CODE
    ' EUSE C@ .             \ 66
    WORDS                   \ should contain PORT-A and EUSE
    ```
  - [x] 10.6 Test 94 — DW, with label (AC8):
    ```
    CODE DW1 LABEL TGT TGT DW, TGT FIX NEXT, END-CODE
    \ TGT FIX runs at body offset 2 (after the two DW bytes), so the
    \ label target is xt + 2.  The two DW bytes should encode that.
    ' DW1 @ ' DW1 2 + = .   \ -1 (true) — DW1's first 2 bytes equal xt+2
    ```
    (Adjust the test if `@` isn't the correct fetch word — verify against `memory.asm`.)
  - [x] 10.7 Test 95 — Unresolved fixup at END-CODE (AC11):
    ```
    CODE BAD LABEL X X JR, NEXT, END-CODE
    ```
    Expected: output contains `unresolved label X ?`. Then `1 2 + .` prints `3` (clean recovery). `WORDS` does **not** list `BAD` and does **not** list `X` (label entry was unlinked).
  - [x] 10.8 Test 96 — `FIX` already fixed (AC11):
    ```
    CODE BAD2 LABEL Y Y FIX A A LD, Y FIX NEXT, END-CODE
    ```
    Expected: `Y already fixed ?` (or whatever exact wording is chosen), clean recovery, no `BAD2` or `Y` in `WORDS`.
  - [x] 10.9 Test 97 — `LABEL` after opcodes (AC2):
    ```
    CODE BAD3 A A LD, LABEL Z NEXT, END-CODE
    ```
    Expected: `LABEL must precede opcodes ?`, clean recovery, no `BAD3` or `Z` in `WORDS`.
  - [x] 10.10 Test 98 — Out-of-range JR (AC11):
    ```
    CODE BAD4 LABEL TGT TGT FIX 130 DS, TGT JR, NEXT, END-CODE
    ```
    Expected: `JR out of range ?`, clean recovery, no `BAD4` or `TGT` in `WORDS`.
  - [x] 10.11 Test 99 — Sigil-free typo guard (AC12):
    ```
    CODE BAD5 LABEL OK PUHS, NEXT, END-CODE
    ```
    Expected: standard `PUHS, ?` error (PUHS, is just an unknown word). Clean recovery; no `BAD5` and no `OK` in `WORDS`. **This is the critical guard test** — confirms that a misspelt opcode produces the normal error and that the in-progress label is correctly unlinked by `asm_cleanup`.
  - [x] 10.12 Test 100 — Outside-CODE rejections (AC11):
    ```
    LABEL FOO
    FIX
    0x42 DB,
    0x1234 DW,
    1 DS,
    ```
    Each line should produce `not in CODE ?` and recover cleanly.
  - [x] 10.13 Test 101 — `EQU` inside CODE (AC10):
    ```
    CODE BAD6 1 EQU FOO NEXT, END-CODE
    ```
    Expected: `EQU outside CODE only ?`, clean recovery, no `BAD6` or `FOO` in `WORDS`.
  - [x] 10.14 Test 102 — Label scoping across CODE words (AC15):
    ```
    CODE A1 LABEL LBL LBL FIX A A LD, NEXT, END-CODE
    CODE A2 LABEL LBL LBL FIX B B LD, NEXT, END-CODE
    ```
    Expected: both definitions succeed; `WORDS` lists `A1` and `A2`; `WORDS` does **not** list `LBL` (the label entries from each CODE were unlinked at their respective END-CODE).
  - [x] 10.15 Test 103 — Label-pool overflow (AC11):
    ```
    CODE BIG LABEL L1 LABEL L2 LABEL L3 LABEL L4 LABEL L5 LABEL L6 LABEL L7 LABEL L8 LABEL L9 LABEL L10 LABEL L11 LABEL L12 LABEL L13 LABEL L14 LABEL L15 LABEL L16 LABEL L17 NEXT, END-CODE
    ```
    Expected: `too many labels ?`, clean recovery. Verify none of L1..L17 leak into the global dictionary (`WORDS` after recovery).
  - [x] 10.16 Test 104 — Story 4.1 regression spot-check: re-run `CODE MYDUP BC PUSH, NEXT, END-CODE  5 MYDUP . .` and assert `5 5 ` is printed. Belt-and-braces against a label-cleanup change accidentally regressing the basic CODE path.
  - [x] 10.17 Add each test to `Makefile`. Single emulator launch where convenient. One PASS/FAIL line per test.

- [x] Task 11: Verify no regressions (AC: #14)
  - [x] 11.1 `make test` — all 73 regression tests pass, EXPECTED string unchanged
  - [x] 11.2 `make test-repl` — all existing 89 REPL tests pass (1-89) plus all new tests (90+) pass
  - [x] 11.3 `make` — clean build, no new sjasmplus warnings
  - [x] 11.4 `outer_interpreter.asm` is **untouched** in this story. Verify with `git diff` after implementation that no lines have changed in that file — if any change appears, it is a bug in the implementation approach (Story 4.2's design explicitly avoids any INTERPRET hook).
  - [x] 11.5 Manual smoke test under iz-cpm: define a CODE word using `LABEL` + `FIX` + `JR,` for both backward and forward refs, plus a `DW,` data table referenced by a label. Confirm interactive behaviour matches the REPL test expectations. Try the error paths interactively (unresolved at END-CODE, already-fixed, LABEL-after-opcodes, out-of-range JR, EQU-in-code, label outside CODE) and confirm error messages are readable and the prompt recovers cleanly.
  - [x] 11.6 **Hash bucket isolation test**: in iz-cpm, define a CODE word with two labels chosen to land in the same hash bucket (use trial-and-error to find a colliding pair, or just declare 8+ labels — by birthday paradox, a collision is very likely with 64 buckets). Confirm the cleanup correctly unlinks both. Then exercise `WORDS` and a `FIND` for an existing pre-CODE word that shares the same bucket — confirm the existing word is still findable (i.e. its hash chain wasn't corrupted).
  - [x] 11.7 Stack-state hygiene: after any error path, run `.S` and confirm the data stack is empty (or at the expected baseline depth). Per memory `project_tos_in_register.md`, after ABORT the BC=TOS register is "phantom"; verify `DEPTH` reports 0 immediately after a clean recovery.

## Dev Notes

### What Story 4.2 Delivers

Story 4.2 builds the **labels and data infrastructure** that makes the assembler usable for non-trivial CODE words. After 4.2, the user can write CODE words with structured loops, data tables, and named constants, but only with the limited opcode set from 4.1 plus `JR,` (the simplest label-consuming opcode). Stories 4.3 and 4.4 will extend the opcode set; both will reuse 4.2's `asm_add_fixup` / `asm_apply_fixup` plumbing for their own label-aware opcodes (`JP,`, `CALL,`, conditional `JR,` forms, etc.).

### Why Explicit `LABEL` Declarations (And Not Sigils Or An INTERPRET Hook)

Earlier drafts of this story tried two cleverer approaches and rejected both:

1. **Auto-creating labels in the INTERPRET unknown-word path.** Any unknown word inside a CODE definition would be silently turned into a forward-reference label. This is hacky and brittle: a misspelt opcode like `PUHS,` is silently swallowed as a label, and the user only finds out at END-CODE (or much later, when the label is referenced and never resolved). It also requires touching `outer_interpreter.asm` — the most heavily-used file in the kernel — which is high-risk for regressions.

2. **Sigil-based syntax** (`LOOP:` for definition, `L:LOOP` for reference) with INTERPRET still hooked but only firing on tokens matching one of the sigil patterns. This fixes the typo problem but still requires INTERPRET surgery, still adds custom unknown-word logic, still has surprising precedence rules around ambiguous tokens like `L:LOOP:`, and still feels like the assembler is reaching into INTERPRET's guts.

The explicit-`LABEL` approach is cleaner on every dimension:

- **Zero changes to `outer_interpreter.asm`.** Labels are normal Forth dictionary entries, looked up via the standard FIND. Unknown words inside CODE go through the same error path as outside CODE — no special-casing.
- **Typo guard is structural, not pattern-based.** A misspelt opcode is just an unknown word. The standard `word ?` error fires immediately. There is no mechanism that could ever silently convert an unknown word into a label.
- **All labels declared at the top.** This is enforced by a single HERE-comparison check in `LABEL`. The result is CODE words that are easy to read: the reader sees the full label list before having to reason about any opcodes.
- **`FIX` is explicit, not implicit.** The point at which a label takes its address is a separate, named operation. This makes forward-vs-backward references uniform: every reference is "forward" until `FIX` runs.

The cost is one extra word per label in the source code (`LABEL FOO` instead of just using `FOO` directly), and the user has to remember to call `FIX`. Both of these are explicit-is-better-than-implicit trade-offs that the project lead has chosen.

### How `LABEL` Works (Implementation Sketch)

`LABEL` is a parsing word that:

1. Verifies `asm_mode = 1` and `HERE == asm_saved_here` (the "before opcodes" check).
2. Parses the next whitespace-delimited token from input as the label name.
3. Allocates a fresh slot in `asm_label_pool` (returns slot index `N`).
4. **Temporarily redirects HERE to the label dictionary side area** (`asm_label_dict_top`). The side area is a fixed buffer in `assembler.asm`'s data section, separate from the main HERE growing area.
5. Calls `build_header` with `flags = 0`. `build_header` writes the new entry's hash link, count_flags, and name bytes at HERE (which is now in the side area), updates the hash bucket head to point at the new entry, and returns HL = code field address.
6. Captures the bucket index (from `bh_bucket_index`) and the old bucket head (from `bh_old_bucket_head`) — these go into the new label slot's `bucket` and `old_head` fields, used later for unlinking.
7. Emits the label-word body bytes into HL: `LD L, N` (2 bytes) followed by `JP asm_push_label_tag` (3 bytes). 5 bytes total.
8. Updates `asm_label_dict_top` to the new HERE.
9. Restores HERE to its original value (which has not changed, since the body of the in-progress CODE word hasn't grown).
10. Stores the dict entry's name pointer in the slot's `name_ptr` field (for unresolved-error reporting).

When the user later writes `FOO` (where `FOO` was declared via `LABEL FOO`), the standard FIND path looks `FOO` up in the dictionary, finds the entry in the side area, and executes its body — which loads the slot index into `L` and jumps to `asm_push_label_tag`. That helper does `check_asm_mode`, then pushes the label tag (`0x80 | index`) onto the data stack. Identical pattern to the register tag words from Story 4.1.

### Label Tag Encoding

Label tags are 16-bit values where the **high byte is `0x80`** and the low byte is the slot index (0..15). So tags occupy the range `0x8000..0x800F`.

This works because:

- **Register tags** (Story 4.1) have their high byte zero (low byte 0x00..0x14), so no collision.
- **Plain integer addresses** for jump targets sit in the dictionary area, which is well below 0x8000 on both iz-cpm and MicroBeast (the kernel keeps user code, dictionary, and stacks in the lower half of the address space). So `0x8000+` is unambiguously a label tag, never a real address.
- **Decoder is trivial**: `if (high byte of TOS) == 0x80 → label tag, slot index = low byte`.

**Caveat to verify:** confirm with the memory map in `architecture.md` that the dictionary HERE pointer never reaches 0x8000 in any realistic scenario. If it can, switch the sentinel to a higher region (e.g. `0xFF00..0xFF0F`) — the scheme is the same, just a different prefix. The memory map is at `architecture.md`'s "Memory Layout" section. **Verify before coding.**

If the verification rules out 0x8000, fall back to `0xFFE0 | label_index` (range 0xFFE0..0xFFEF) — well above any plausible HERE value and well below the special sentinel 0xFFFF.

Whichever scheme is chosen, document it in a block comment at the top of the label-pool section of `assembler.asm`, and add a small inline helper (`asm_is_label_tag`: entry BC = TOS, exit Z flag set if label tag, A = slot index) so the test is in one place.

### Label Cleanup Walkthrough

The hash bucket unlink mechanism is the only subtle piece. Worked example:

Suppose the user defines:
```
CODE FOO
  LABEL ALPHA       \ slot 0, lands in bucket 7
  LABEL BETA        \ slot 1, lands in bucket 12
  LABEL GAMMA       \ slot 2, lands in bucket 7  (collision with ALPHA)
  ALPHA FIX
  ...
END-CODE
```

State after each LABEL (showing only buckets 7 and 12):

- **Before LABEL ALPHA:** bucket 7 = `(pre-FOO chain)`, bucket 12 = `(pre-FOO chain)`.
- **After LABEL ALPHA:** bucket 7 = `ALPHA → (pre-FOO chain)`. ALPHA's slot.old_head = `(pre-FOO chain)`.
- **After LABEL BETA:** bucket 12 = `BETA → (pre-FOO chain)`. BETA's slot.old_head = `(pre-FOO chain)`.
- **After LABEL GAMMA:** bucket 7 = `GAMMA → ALPHA → (pre-FOO chain)`. GAMMA's slot.old_head = `ALPHA` (which was the bucket 7 head right before GAMMA was added).

Now `END-CODE` calls `asm_unlink_labels`, which walks slots in reverse insertion order (GAMMA, BETA, ALPHA):

- **Process GAMMA (slot 2):** restore bucket 7 head from GAMMA's slot.old_head = `ALPHA`. Bucket 7 is now `ALPHA → (pre-FOO chain)`. Correct intermediate state.
- **Process BETA (slot 1):** restore bucket 12 head from BETA's slot.old_head = `(pre-FOO chain)`. Bucket 12 is back to its pre-CODE state.
- **Process ALPHA (slot 0):** restore bucket 7 head from ALPHA's slot.old_head = `(pre-FOO chain)`. Bucket 7 is back to its pre-CODE state.

Result: both buckets are restored to their pre-CODE state, all three label entries are unreachable from the dictionary. The bytes in the side area still exist but are dead memory; resetting `asm_label_dict_top` to the base reclaims the space for the next CODE word.

This works for any pattern of bucket collisions because the LIFO discipline of dictionary chains (always prepend to head) means reverse-insertion-order undo is correct.

### What Already Exists (verified from source)

- **`build_header`** (`compiler.asm:31-201`) — used by `LABEL` after redirecting HERE to the side area. Returns HL = code field, populates `bh_bucket_index` and `bh_old_bucket_head` which `LABEL` captures.
- **`asm_print_error`, `asm_die`, `asm_cleanup`, `check_asm_mode`, `asm_emit_byte`** — all in `assembler.asm` (lines 79-187). Reuse these. The new error helpers (Task 9) follow the same shape.
- **`asm_push_tag`** (`assembler.asm:202`) — the register-tag push helper. `asm_push_label_tag` is its sibling for label tags.
- **`w_CONSTANT_cf`** (`compiler.asm:585`) — what `EQU` delegates to.
- **`'` (TICK)** and **`C@`** — used by REPL tests to introspect CODE word bodies. Verify their names in `dictionary.asm` and `memory.asm` before writing the test commands; if `'` is spelled differently (e.g. `TICK`) update the tests.
- **`w_ABORT_cf` already calls `asm_cleanup`** (per Story 4.1 — see `system.asm`'s ABORT). The label-unlink addition in Task 8 hooks into the existing call site, no new `system.asm` change needed.
- **`hash_table`** — the global dictionary hash buckets. 64 buckets × 2 bytes = 128 bytes. `LABEL` and `asm_unlink_labels` directly read/write specific bucket entries via `&hash_table[bucket * 2]`. The hash bucket index for a name comes from `bh_bucket_index` which `build_header` populates.

### Anti-Patterns to Avoid

1. **Do NOT touch `outer_interpreter.asm`.** This story's whole point is to implement labels without any INTERPRET surgery. If you find yourself needing to modify INTERPRET to make labels work, the design has gone wrong — stop and ask the project lead.
2. **Do NOT grow the label/fixup pools or the label dict side area into HERE.** Fixed-size pools are the cleaner answer for cleanup-on-ABORT and bound the worst case. If the user needs more than 16 labels in one CODE word, that's a strong code smell — they should split the word.
3. **Do NOT make labels global across CODE definitions.** Labels are *per-CODE* — created at LABEL time, unlinked at END-CODE or any ABORT path. Cross-CODE label scoping (test 102) is non-negotiable.
4. **Do NOT skip the END-CODE unresolved check.** A CODE definition that compiles cleanly but contains an unresolved JR is a silent corruption hazard — the placeholder byte (`0x00`) means "JR +0" which executes the next instruction, not what the user intended.
5. **Do NOT let `EQU` run inside CODE.** `CONSTANT` calls `build_header` which advances real HERE — that would inject a Forth dictionary entry into the middle of the in-progress CODE word's body. Block it with the `asm_mode == 0` guard.
6. **Do NOT silently truncate label names.** Names longer than the limit (verify the existing build_header limit) get an explicit error rather than silent truncation. Silent truncation produces invisible aliasing bugs.
7. **Do NOT forget that `DS, 0` is a no-op, not an error.** Users will sometimes parameterise `DS,`'s count.
8. **Do NOT add `JP,` or `CALL,` in this story.** They're Story 4.3. The fixup mechanism is designed to support them; just don't ship them in 4.2. Same for conditional JR forms.
9. **Do NOT add tests to the regression test thread.** REPL-piped tests only (per memory `feedback_repl_tests_preferred.md`).
10. **Do NOT assume BC=TOS is intact across `build_header`.** `LABEL` calls `build_header` from inside a DEFCODE word; the same save-BC-and-DE-to-RS pattern that `w_CODE_cf` uses (assembler.asm:307-314) must be applied to `LABEL`, or BC and DE will be clobbered.
11. **Do NOT unlink labels in forward order.** Reverse-insertion-order is required for correctness when two labels collide in the same hash bucket. See "Label Cleanup Walkthrough" above.
12. **Do NOT forget to reset `asm_label_dict_top` on every cleanup path.** Otherwise the side area will fill up across successive CODE definitions and eventually overflow.

### Open Questions for the Project Lead

The following are decisions where the AC text is silent or where two reasonable answers exist; surface them to the project lead before or during implementation. **Save these for the end of implementation, do not block on them up front** — pick a reasonable default, document it, and confirm.

- **Q1: Should `JR,` accept a literal-address operand (e.g. `0x1234 JR,`) at all?** The AC text only shows label-based JR. Implementing literal-address JR is ~10 extra lines of code and gives users an escape hatch when they want to JR to a fixed location (e.g. into a ROM routine). **Default:** support it; the cost is small. **Note:** the high-byte test (label tag = 0x80) makes the dispatch trivial — anything that isn't 0x80 is a literal address.
- **Q2: How should `0x1234 DB,` behave when the high byte is non-zero?** Silent low-byte truncation (emit `0x34`) is the conventional assembler answer. Strict rejection (`bad operand ?`) is more defensive. **Default:** silent truncation, consistent with sjasmplus and most cross-assemblers.
- **Q3: Maximum number of labels per CODE word?** The story spec uses 16. Real-world hand-written CODE words rarely need more than 5-6. Bumping to 32 doubles the pool size (~256 bytes more) but is still cheap. **Default:** 16.
- **Q4: Maximum number of pending fixups per CODE word?** The story spec uses 32. Each forward reference consumes one fixup slot until its target is FIXed. 32 is plenty for any realistic CODE word. **Default:** 32.
- **Q5: Should `END-CODE` warn about LABELed-but-never-referenced labels (declared with `LABEL FOO` but never used as a JR/JP/DW target and possibly never even FIXed)?** Strict assemblers do this; lenient ones don't. The unresolved-fixup check already catches LABELed-but-not-FIXed-and-referenced (because the unresolved fixup is queued). The case it doesn't catch: LABEL FOO + FOO FIX, but FOO is never used as a target. Harmless. **Default:** no warning.
- **Q6: Should label names be case-sensitive?** AntForth's existing dictionary is (verify in `dictionary.asm`). Labels are normal dictionary entries so they inherit whatever the existing convention is. **Default:** match the existing dictionary behaviour, no special handling.
- **Q7: Where exactly does the label dict side area live in memory?** Options: (a) static buffer in `assembler.asm`'s data section (simplest, fixed location, 256 bytes always allocated); (b) carved out of the top of HERE's free space at CODE entry, returned at END-CODE (trickier, no permanent footprint). **Default:** (a) — static buffer. The 256 bytes are cheap and the static address makes everything easier to debug.

### Previous Story Intelligence (from Story 4.1)

The Story 4.1 retrospective entries in its file (lines 280-326) flagged several real bugs caught by interactive smoke testing that the automated tests had missed:

1. **Register-contract violation in `NEXT,`** — first-pass implementation used `DE` as the LDIR destination, clobbering `DE = IP`. Fixed by saving IP/TOS to the return stack across the LDIR. **Apply this lesson to `LABEL`**: `LABEL` calls `build_header` (which clobbers BC and DE) and then emits 5 bytes of body code via further helpers. The CODE-style save-BC-DE-to-RS prologue (assembler.asm:307-314) must be applied — don't trust BC/DE across the helper calls.
2. **Spill slot reuse** — Story 4.1 added `asm_tmp` as a single 1-byte spill slot. Story 4.2's helpers (`asm_apply_fixup`, the slot-walk in `asm_unlink_labels`, the `LABEL` body-emit helpers) can reuse it BUT only if the call paths never nest. None of the new helpers nest into LD, or the arith helpers, so reuse is safe. **Add a second `asm_tmp2` byte if any nesting case appears** — a 1-byte data add is cheaper than debugging spill collisions.
3. **Code review found H1/H2/L3-class issues** — orphan `END-CODE`, nested `CODE`, `CODE` without name. The new error paths in this story (Task 9) follow the same `asm_die` trampoline pattern and the same `asm_print_error` shape, so the review will hold them to the same standard. Don't half-implement an error message; the convention is "subject ?" CR LF, every time.
4. **All asm error sites use `asm_print_error`** (Story 4.1 M5 fix) — do the same in this story. Don't add raw BDOS write sequences anywhere except inside `asm_print_error` / `asm_print_error_with_name`.
5. **`AND ~F_SMUDGE` was rejected by sjasmplus** (Story 4.1 L2 fix) — if any new code needs to clear a flag bit, use the explicit byte constant (`AND 0xBF` and a comment showing the derivation), not `~F_SMUDGE`.

### Git Intelligence

Recent commits show one-commit-per-story pattern with the message form `completed story X.Y`:
```
7606d0c completed story 4.1
e1fca6a add WISHLIST.md
... (older)
```

Story 4.1 touched `src/assembler.asm` (rewrite from stub), `src/system.asm` (one new CALL in ABORT), and `Makefile` (REPL tests 85-89). Story 4.2 will touch:
- `src/assembler.asm` — extend with label/fixup pools, the label dict side area, the new words (`LABEL`, `FIX`, `JR,`, `DB,`, `DW,`, `DS,`, `EQU`), and the new error helpers.
- `Makefile` — append REPL tests 90+.
- **NOT** `src/outer_interpreter.asm` — explicitly excluded by the design (see AC12 and Anti-Pattern #1).
- **NOT** `src/system.asm` — `w_ABORT_cf` already calls `asm_cleanup` from Story 4.1; Task 8 just extends `asm_cleanup` itself.

Expected diff size: ~500-600 lines added to `assembler.asm`, ~80 lines added to `Makefile`. Net change to other files: zero.

### Testing Strategy

Per memory `feedback_repl_tests_preferred.md`, all new tests are REPL-piped Forth scripts in `make test-repl`, not assembly test threads. The Story 4.1 tests 85-89 are the structural template (and they're tied to the same Makefile pattern Story 4.0 set up at lines 717-747).

Per memory `feedback_adversarial_review.md`, the code review will find issues — anticipate:
- What if `LABEL` is called with no name (whitespace then end-of-line)? `build_header` returns CY → LABEL must catch this and error cleanly.
- What if `LABEL FOO LABEL FOO`? The second `LABEL FOO` builds a *second* dictionary entry with the same name in the side area. Both entries are findable. FIND returns the most-recently-added (the second one). The first entry is shadowed but still occupies a slot. Is this OK? **Default**: allow shadowing silently — it's harmless and matches Forth's normal redefinition behaviour. If the project lead wants stricter behaviour, add a duplicate-check by walking existing slots in `LABEL`.
- What if `FIX` is called with an empty stack? The standard underflow handling kicks in (or the bad-tag check catches it because BC has whatever garbage was previously there).
- What if a fixup overflows the 32-entry table? `too many fixups ?` ABORT.
- What if two labels happen to land in the same hash bucket? Unlink walks in reverse, restoring each bucket head from the saved old_head. Worked example in "Label Cleanup Walkthrough" above. **Test case 11.6 explicitly verifies this.**
- What if `LABEL` is called from inside a `:` colon definition? `check_asm_mode` rejects it (asm_mode is only set by `CODE`, not `:`).
- What if `DS,` overflows HERE past the dictionary boundary? The kernel doesn't currently have a HERE bounds check; this is a pre-existing issue and out of scope. Note in the change log if it bites in practice.

Per memory `feedback_standards_compliance.md`, the `LABEL`/`FIX` design is a deliberate departure from the historical fig-FORTH and MMSForth assembler conventions (which use anonymous MARK/RESOLVE-style label patterns). The rationale is the "no INTERPRET hook" constraint and the desire for explicit, readable CODE words. Reference `docs/z80_forth_assemblers.md` for the prior art and document this departure in `assembler.asm`'s file header so future maintainers understand why AntForth's labels look different from the historical Forths.

### References

- [Source: src/assembler.asm] — Story 4.1's assembler module; this story extends it
- [Source: src/assembler.asm:48-54] — existing scratch/data area; new label slot pool, fixup pool, and label dict side area go just below this
- [Source: src/assembler.asm:79-130] — existing error helpers and trampolines (`asm_print_error`, `asm_die`, `asm_err_*`); new helpers follow the same pattern
- [Source: src/assembler.asm:137-187] — `asm_cleanup`, `check_asm_mode`, `asm_emit_byte`; reused as-is and `asm_cleanup` extended in Task 8
- [Source: src/assembler.asm:202-207] — `asm_push_tag`; the model for the new `asm_push_label_tag` helper
- [Source: src/assembler.asm:291-362] — `w_CODE_cf`; pattern that `LABEL` borrows for the build_header save-restore prologue, and where the label-pool reset is added (Task 8)
- [Source: src/assembler.asm:369-386] — `w_END_CODE_cf`; extended in Task 8 with the unresolved-fixup check and the label unlink
- [Source: src/compiler.asm:288-352] — `:` (COLON) showing how to parse a name from input via WORD; pattern that `LABEL` mirrors
- [Source: src/compiler.asm:31-201] — `build_header` — used by `LABEL` after HERE redirection
- [Source: src/compiler.asm:579-642] — `CONSTANT`; `EQU` delegates here
- [Source: src/system.asm] — `w_ABORT_cf` already calls `asm_cleanup`; no further `system.asm` change needed in this story
- [Source: src/macros.asm:58-94] — DEFCODE / DEFWORD / DEFIMMED macros for new word definitions
- [Source: src/memory.asm:137-] — `C,` byte-comma; `DB,` is essentially `C,` with an `asm_mode` gate
- [Source: src/dictionary.asm] — `find_word`, hash table layout (verify `hash_table` symbol and bucket size before coding the unlink walk)
- [Source: src/constants.asm] — flag bits used by `build_header`
- [Source: _bmad-output/planning-artifacts/architecture.md] — memory map (verify label-tag sentinel range), register contract, kernel/Forth boundary
- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.2, lines 845-875] — story requirements (source of truth for AC1-10)
- [Source: _bmad-output/implementation-artifacts/4-1-code-word-framework-and-basic-instructions.md] — Story 4.1 final state, including all anti-patterns and the Code Review change log
- [Source: docs/z80_forth_assemblers.md] — prior-art survey; the historical MARK/RESOLVE label pattern that this story explicitly departs from
- [Source: Makefile, lines 717-790ish] — `test-repl` target with Story 4.0 / 4.1 test patterns to mirror

## Dev Agent Record

### Agent Model Used

claude-opus-4-6 (1M context)

### Debug Log References

Bugs found and fixed during implementation (caught by interactive smoke testing — REPL test suite alone would not have found all of them):

1. **`LD DE, (asm_body_start)` clobbered DE before save** (LABEL prologue) — the "before opcodes" check used DE as the comparand register before DE (the IP) was saved to the return stack. NEXT then jumped through a corrupted IP. Fix: move the save-DE-to-RS prologue to run BEFORE the check.
2. **END-CODE didn't preserve DE/BC across helper calls** — `asm_check_unresolved` / `asm_unlink_labels` / `asm_reset_label_state` clobber DE/BC freely. The original END-CODE had no calls so DE was naturally preserved; the new flow requires explicit save/restore. Fix: bracket the helper calls with the same IX-based RS save the colon compiler uses.
3. **JR,/FIX/DW, didn't preserve DE** — same root cause as #2 in opcode words. JR, in particular uses D/E as scratch for the target address. Fix: spill DE to a new `asm_ip_save` scratch around the helper calls.
4. **`POP HL` after displacement computation in `asm_apply_jr_fixup_emit` overwrote the displacement** — the displacement was held in HL after `SBC HL, DE`; `POP HL` to recover the patch address discarded it, and `LD A, L` then read the patch_addr's low byte instead of the displacement. Fix: read `LD A, L` *before* the `POP HL`.

### Completion Notes List

- All 15 ACs satisfied. 15 new REPL tests added (90–104) covering every AC and every error path.
- Story 4.1 retrospective lessons applied: register-contract violations were the dominant bug class again. The REPL-test "exercise actual primitives" rule (`feedback_repl_tests_preferred.md`) was followed throughout.
- `outer_interpreter.asm` and `system.asm` are unchanged in this commit (`git diff --stat` confirms zero lines touched), per AC12 and the design constraint that this story makes no INTERPRET surgery. The typo guard works exactly because labels are normal Forth dictionary entries dispatched through the standard FIND path.
- Q1 (literal-address JR): supported. `<addr> JR,` outside of a label tag still emits a relative displacement to that absolute address.
- Q2 (DB, with high byte non-zero): silent low-byte truncation, matching sjasmplus.
- Q3 (max labels per CODE): 16. Q4 (max fixups): 32.
- Q5 (warn on LABELed-but-unreferenced labels): not implemented — quiet.
- Label tag encoding: `0xFFnn` where nn is the slot index (0..15). The `0x80` prefix from the story spec was rejected because iz-cpm's BDOS base ~0xE400 means HERE can plausibly reach 0x8000. `0xFF` is well above any realistic HERE.
- Label slot record is 8 bytes: resolved flag (1) + target (2) + bucket index (1) + saved old_head (2) + count_flags ptr (2). The story spec proposed 10 bytes with a separate name_ptr; the cf_ptr-based approach is one byte shorter and avoids the redundant pointer.
- The label dict side area is 768 bytes statically reserved in the assembler.asm data section (Q7 option a). Code review bumped from 256 → 768; the original 256 underestimated worst case (16 slots × ~39 bytes = 624). 768 leaves headroom and is bounded by the slot pool size, so no runtime overflow check is required.

### Code Review Follow-ups (2026-04-11)

Adversarial code review found 1 HIGH, 5 MEDIUM, 3 LOW issues. All fixed:

- **H1 — `LABEL` with no name corrupted `hash_table[0]`** (`assembler.asm` `w_LABEL_cf`). The slot was allocated *before* `build_header`; on `build_header` CY (no-name path) the abort routed through `asm_unlink_labels`, which read the slot's zero-initialised `bucket` / `old_head` fields and zeroed `hash_table[0]`. Reproduced live: after `CODE FOO LABEL\n`, the word `@` (FETCH) disappeared from `WORDS`. **Fix:** decrement `asm_label_count` on the `.lbl_no_name` path so the bogus slot is never walked.
- **M1 — Tests 95–99/101/103 didn't verify dictionary cleanliness post-error.** Each test now appends `WORDS` and grep-negates the failed CODE/label names from the WORDS line.
- **M2 — Test 100 only covered `LABEL` outside CODE.** Expanded to all five (`LABEL`, `FIX`, `DB,`, `DW,`, `DS,`) with a count check (≥5 errors, ≥5 recoveries).
- **M3 — No fixup-pool overflow test.** Added test 105: 33 forward `JR,` references to a single label exceed `ASM_FIXUP_POOL_SIZE = 32` and produce `too many fixups ?`, with WORDS cleanliness verified.
- **M4 — `asm_label_dict` 256-byte side area had no overflow bound.** Bumped to 768 bytes (worst case 16 × 39 = 624) so the slot pool size now bounds the side area.
- **M5 — `DB,` accepted label tags via silent low-byte truncation** (`LABEL X X DB,` would emit the slot index byte). Added an explicit high-byte check that rejects label tags with `bad operand ?`.
- **L1 — `asm_resolve_slot` complexity.** Refactored via Option C (full decomposition). Extracted `asm_apply_fixup_record` (reads patch+kind in one linear pass and tail-dispatches to `asm_apply_jr_fixup` / `asm_apply_dw_fixup`); the helper preserves B (slot index) and DE (target) so the caller doesn't have to round-trip them through the stack. `asm_resolve_slot` itself rewritten to walk the fixup pool with HL as a moving record pointer instead of recomputing addresses via `asm_fixup_addr` per iteration. Added a 2-byte `asm_resolve_target` scratch to cache the target address across the loop. The match path collapsed from ~50 lines of nested PUSH/POP juggling to ~25 lines of straight-line code; the no-match path is now four `INC HL` instructions plus a counter bump. The `asm_apply_fixup_record` boundary also makes Story 4.3 / 4.4 cheap to extend with new fixup kinds.
- **L2 — `asm_apply_jr_fixup` and `asm_apply_jr_fixup_emit` duplicated range-check logic.** Extracted into a shared `asm_jr_disp` helper; both paths now compute and range-check displacements in one place.
- **L3 — No test for literal-address `JR,`** (Q1 default). Added test 106: `CODE LIT4 HERE 5 + JR, NEXT, END-CODE` exercises the literal-target dispatch and verifies the encoded displacement.

All 73 regression tests + 106 REPL tests pass post-fix.

### File List

- `src/assembler.asm` — extended: label/fixup pools, side area, error helpers, asm_alloc_label_slot / asm_resolve_slot / asm_add_fixup / asm_apply_jr_fixup / asm_apply_jr_fixup_emit / asm_apply_dw_fixup / asm_check_unresolved / asm_unlink_labels / asm_reset_label_state / asm_push_label_tag, w_LABEL / w_FIX / w_JR_COMMA / w_DB_COMMA / w_DW_COMMA / w_DS_COMMA / w_EQU, plus extensions to asm_cleanup, w_CODE_cf, w_END_CODE_cf, and a new asm_body_start variable.
- `Makefile` — REPL tests 90 through 106 added to the `test-repl` target (17 tests covering every AC, every error path, fixup-pool overflow, and literal-address JR).
- `_bmad-output/implementation-artifacts/4-2-labels-and-data-definition-words.md` — Status: done; tasks marked complete; this Dev Agent Record including code-review follow-ups.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `4-2-labels-and-data-definition-words` updated to `done`.
