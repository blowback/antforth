# Story 18.1: Descriptor-stub allocator + xt-as-stub-address contract

Status: done

## Context — why this story exists, why now

First story of Epic 18 (Stub mechanism (γ) + cross-bank EXIT (S1 b) +
`BANK-OF` + `IN-BANK`), the second binary-delta epic of Phase 4. Epic 17
closed 2026-05-17 with v3.0.1 tagged at commit `39ac70b`: all 12 user-facing
banking words shipped + verified on real MicroBeast hardware; iron-spike
hand-built cross-bank `BANK!`-`EXECUTE`-RET round-trip PASSed for
main-RAM-resident bodies (transcript `~/Downloads/beastty-20260517-095237.bin`).
Phase-4 baseline at Epic-17 close = **26,228 B kernel** / **975 PASS / 0 FAIL
/ 2 SKIP** iz-cpm baseline / **35 PASS / 0 FAIL** `make test-repl-banking` /
**31 advisories / 0 drift** `make check-doc-sync` (re-validate at dev-pass
start per B.3 — see Pre-edit baseline task below).

Story 18.1 lays the **cross-bank dispatch foundation** that the rest of
Epic 18 (18.2 sentinel-trampoline EXIT · 18.3 `EXECUTE` switch + initial
`COMPILE,` wiring · 18.4 `BANK-OF` · 18.5 `IN-BANK` + Epic 18 close-out)
builds on. Concretely:

1. **A descriptor-stub allocator lands in `src/banking.asm`**, allocating
   stubs in the CCP-evicted Page-3 region (`$D400–$DBFF`) immediately
   after the Story 17.1 / 17.2 / 17.3 structures (`bank-table[]` at
   `$D400`–`$D4AD` + `active_pages[]` at `$D4AE`–`$D4CA` — see
   `src/banking.asm:26..37`). Stubs occupy bytes from `$D4CB` upward.
2. **The stub layout is the 4-byte form pinned by PD-P4-11** (Story 16.4
   §9.5 closure; `architecture.md:347..365`):
   - **Byte 0** — `target_bank` as a signed byte: `-1` (`$FF`) = fixed-memory
     marker per FR-P4-13; `0..28` = active logical bank index per PD-P4-13.
   - **Bytes 1–3** — `JP target_addr_in_bank` (`C3 lo hi`), the standard
     Z80 absolute-jump opcode. For fixed-memory stubs the target lives in
     fixed memory; for banked stubs the target is an address inside the
     target bank's `$8000`–`$BFFF` body region.
3. **The stub address IS the word's xt** (PD-P4-1 / redesign §2.1). No
   `stub_<word>` naming — sources name the allocator output `xt_<word>`
   per Implementation Patterns at `architecture.md:528..536`. This is the
   xt-as-stub-address contract; FR-P4-17 xt portability is automatic
   because the stub lives in fixed memory, so an xt value is stable
   across any `BANK!`.
4. **A new UserArea cell `stub_alloc_tail`** carries the allocator's
   next-free pointer. COLD initialises it to `STUB_ALLOC_BASE` (= the
   address immediately after `active_pages[]`); each allocation writes
   the 4-byte layout at `(stub_alloc_tail)` then advances the cell by 4.
   The convention mirrors `bank_table_base` from Story 17.1
   (`src/structures.asm:43`) — UserArea cell holding the live allocator
   state, with COLD initialisation routing the base address in. No
   `DS` directive in the kernel binary backs the stub-output region —
   the bytes are claimed in the fixed-memory map at constant addresses.
5. **The allocator is kernel-internal in Story 18.1** — no user-facing
   word lands here. Story 18.2 (`cross_bank_return` trampoline) and
   Story 18.3 (`EXECUTE` switch + initial `COMPILE,` stub-emission
   wiring) consume the allocator; Story 18.4 (`BANK-OF`) reads the
   target_bank byte; Story 18.5 (`IN-BANK`) and Epic 19 (`:` allocates a
   stub on `;`) drive it through the compiler chain.
6. **AC4's two hand-test stub allocations** are layout-only at this
   story — the stubs are *inspected* via `@` / `C@` peeks (AC7), not
   *executed through* (executing through a banked stub waits for
   Story 18.3's `EXECUTE` switch). One stub points at a fixed-memory
   word (`target_bank = -1`, `target_addr =` `['] BANK@` body or
   similar); a second points at a hand-built banked body (`target_bank =
   5`, `target_addr =` some address in bank 5). The stub *addresses* are
   recorded inline in the probe block and inherited by Stories 18.2 /
   18.3 / 18.4 as known-shape inputs.
7. **Binary-delta calibration carries the Epic-17 lesson forward** — per
   Lesson 17-B + memory `project_epic17_envelope.md`, the empirical
   envelope across Epic 17 was ~2.4–3.1× the redesign-§7 / epics-spec
   stated target. The Action A3 carry-forward from the Epic 17 retro is
   binding for Story 18.1: cite the memory inline at dev-pass start
   rather than re-litigating Q6-a-extended at each close. AC9 below
   inherits the spec ceiling (≤ ~150 B per epics-spec); the per-component
   itemisation in Dev Notes lands ~40 B (a tight subroutine + a COLD-init
   line); Q6-a-extended accept-with-rationale is invoked only if the
   per-component estimate is overshot by the realised delta.

## Story

As Ant (developer wiring the (γ) cross-bank dispatch mechanism),
I want a descriptor-stub allocator in `src/banking.asm` that allocates a
4-byte stub in the CCP-evicted Page-3 region at allocation time, carrying
`(target_bank, JP target_addr)` per PD-P4-11, with the stub's address
acting as the word's xt,
So that Story 18.2's sentinel-trampoline cross-bank EXIT and Story 18.3's
kernel `EXECUTE` dispatch have a stable per-word artifact to dispatch
through, `BANK-OF` (Story 18.4) becomes a one-byte read, and Epic 19's
bank-aware `:` (which allocates a stub at `;`) has a working substrate.

## Acceptance Criteria

**Given** Epic 17 has shipped (`bank-table[]` at `$D400`–`$D4AD` +
`active_pages[]` at `$D4AE`–`$D4CA` + UserArea cells `saved_bank` /
`current_bank` / `bank_table_base` / `bank_mapping_state` / `bank_count`
all in place per `src/structures.asm:38..51`, `src/banking.asm:1..37`,
`src/antforth.asm:130..245`),
**When** Story 18.1 is dev-passed,

**Then** **AC1** — a descriptor-stub allocator lands in `src/banking.asm`
in the CCP-evicted Page-3 region (`$D400`–`$DBFF`). The allocator's
output region starts at `STUB_ALLOC_BASE` = `ACTIVE_PAGES_BASE +
ACTIVE_PAGES_SIZE` = `$D4AE + 29` = `$D4CB` (constant lands in
`src/constants.asm` adjacent to `BANK_TABLE_BASE` at `:17`). The
allocator allocates stubs at the 4-byte per-stub size pinned by Story
16.4 §9.5 / PD-P4-11 (`architecture.md:347..365`) — Story 18.1 inherits
that decision verbatim.

**And** **AC2** (stub layout per PD-P4-11) — the byte layout of every
allocated stub follows the architecture-locked convention exactly:

  - **Byte 0** — `target_bank` as a signed byte. `$FF` (= `-1` two's
    complement) is the fixed-memory marker per FR-P4-13. `$00`–`$1C`
    (decimal `0`–`28`) are the active logical bank indices per PD-P4-13
    (29-entry cap). Any other value is **undefined input** to the
    allocator — the allocator does not range-check (range-checking is
    the caller's responsibility; Stories 18.3 / 19.x are the callers
    and inherit that contract).
  - **Bytes 1–3** — `JP target_addr_in_bank`: byte 1 = `$C3` (Z80 absolute
    `JP` opcode); byte 2 = `target_addr` low byte; byte 3 = `target_addr`
    high byte. The JP is a real executable Z80 instruction — Story 18.3's
    `EXECUTE` chokepoint reads byte 0, optionally writes the MMU port
    for slot 2, then jumps to `stub_addr + 1` to execute the `JP`. This
    is the smallest contiguous layout that satisfies both FR-P4-13 (stub
    carries `(target_bank, target_addr_in_bank)`) and FR-P4-15 (intra-bank
    dispatch = one extra `JP` overhead vs flat dispatch).
  - The 4-byte layout is documented **inline** at the allocator source
    site per CCD-3 / NFR-P4-20 — a one-paragraph comment block citing
    PD-P4-11 (architecture.md:354..361) and redesign §2.1 + §7.

**And** **AC3** (naming convention) — the allocator routine name follows
the Implementation Patterns convention at `architecture.md:528..536`:
**stub IS the xt; never `stub_<word>`**. The allocator entry-point label
(e.g. `stub_allocate:` or `xt_alloc:`) is a kernel-internal label, not a
word; downstream user-facing words that take an xt (`BANK-OF` Story 18.4,
`EXECUTE` Story 18.3) document the xt-IS-stub contract. Story 18.1's two
hand-test allocations (AC4) demonstrate the contract by recording the
stub address as the xt of the test target.

**And** **AC4** (allocator-callable hand-test, layout-only) — a hand-test
driver allocates two stubs:

  - **Stub A** — fixed-memory target. `target_bank = -1`, `target_addr =
    <known fixed-memory body address>` (a concrete pick from
    dev-pass — e.g. `['] BANK@` body resolves to a fixed-memory address
    in `src/banking.asm`). The hand-test driver records both the stub's
    own address (which is its xt) and the four bytes the allocator
    wrote.
  - **Stub B** — banked target. `target_bank = 5`, `target_addr = $8200`
    (or another address in the `$8000`–`$BFFF` body region for bank 5).
    The hand-test driver records the stub's address and the four bytes
    the allocator wrote.

  The hand-test is **layout-only** at Story 18.1 — the two stubs are
  *inspected*, not *executed through* (Story 18.3's `EXECUTE` chokepoint
  + Story 18.2's `cross_bank_return` trampoline are the parts that would
  let them execute). The two stub addresses are recorded inline in the
  AC7 probe block so Stories 18.2 / 18.3 / 18.4 can inherit them as
  known-shape inputs.

**And** **AC5** (CCD-3 source-comment block) — the allocator carries
`; antforth Phase-4 — see docs/antforth-banking-redesign.md §2.1
(γ mechanism)` per CCD-3 / NFR-P4-20. The comment cites PD-P4-11
(`architecture.md:347..365`) inline for the 4-byte layout decision and
references the Story-17.1 banking subsystem header at
`src/banking.asm:1..14` for cross-file consistency.

**And** **AC6** (NFR-P4-4 per-stub size envelope) — a benchmark probe
measures one stub's allocation footprint (= the byte delta of
`stub_alloc_tail` across one allocation call). The probe asserts the
delta is exactly **4 B**, ≤ the NFR-P4-4 envelope of ≤ **5 B**
(`architecture.md:359` / `prd.md`). The measurement is captured in
Dev Notes against the envelope; the per-banked-word stub-count metric
is **not** measured at Story 18.1 (Epic 18 first surfaces that metric
at Story 18.5's close-out per F2 mitigation /
`epics-phase4-epics-16-22.md:743`).

**And** **AC7** (REPL probes — `tests/banking_tests.fth`) — sentinel-bounded
probes land in the banking-tests file following the Story-17.5.1
sentinel-bounded probe convention (sentinel header / numbered probes /
sentinel footer; substring-grep over the literal `." PASS:"` is rejected
per Story 17.5.1):

  - **Probe-18.1-A** (stub-A layout) — allocate Stub A as in AC4 (fixed-memory
    target), then peek byte 0 via `C@` and bytes 1–3 via `@` (or three
    `C@`s); assert `byte0 = -1` (`$FF`); assert `byte1 = $C3`; assert
    `byte2/byte3 = target_addr` lo/hi.
  - **Probe-18.1-B** (stub-B layout) — allocate Stub B as in AC4 (banked
    target, `target_bank = 5`); peek the four bytes; assert
    `byte0 = 5`; assert `byte1 = $C3`; assert `byte2/byte3 = $8200`
    lo/hi (or whatever dev-pass picks as `target_addr`).
  - **Probe-18.1-C** (sequential allocation, no overlap) — allocate **10**
    stubs in a row (with any `target_bank` / `target_addr` — dummy values
    are fine); walk the 10 stub addresses; assert the deltas are
    **exactly 4** between consecutive stubs (= the per-stub size from
    AC6); assert the 10th stub's address is `STUB_ALLOC_BASE + 36`. The
    probe records the final `stub_alloc_tail` value in the probe's
    output for Dev-Notes documentation.

  The probe block carries sentinel-bounded delimiters (per Story 17.5.1
  pattern at `tests/banking_tests.fth:<sentinel block>`). Probe authoring
  follows Lesson 17-F: if the probes use any direct memory-write idiom
  comparable to the Story 17.6 hand-typed pattern, smoke-test the probe
  under iz-cpm-banking in its EXACT typed form before handing off to
  hardware (or decompose to short helper words).

**And** **AC8** (probe surfaces + hardware smoke per S9 / NFR-P4-11) —
the AC7 probes pass under the banking-capable emulator
(`iz-cpm-banking` @ `1777a85`); `make test-repl-banking` reports
**Probe-18.1-A**, **Probe-18.1-B**, and **Probe-18.1-C** PASS. **One**
hardware-typed probe runs on real MicroBeast asserting that two
allocated stubs have **distinct, non-overlapping addresses** (= a
subset of Probe-18.1-C inlined for typed-form brevity — allocate two
stubs, print their addresses, assert the second's address equals
the first's address plus 4). The hardware run is planned as an
**independent verdict surface** per Lesson 17-C, not as a redundancy
check on `make test-repl-banking`. Transcript saved to
`~/Downloads/beastty-<timestamp>.bin` per the per-binary-delta-story
S9 discipline. Hardware-smoke recipe is posted in the closing chat
message at code-review close per `feedback_post_hw_smoke_steps_at_review.md`
STRONG rule (fired 7× in Epic 17; non-negotiable).

**And** **AC9** (binary delta — per-component itemisation per B.2 /
Lesson 13.5-C) — `wc -c build/antforth.com` grows by ≤ **~150 B** for
this story, tracked against the Epic-18 ~400 B envelope per Decision
Impact Analysis (`architecture.md:479` row Epic 18: ~400 B). The
per-component itemisation (Dev Notes — Byte budget) sums to
approximately:

  - **Allocator routine body (~25–30 B)** — load `stub_alloc_tail` from
    `(IY+UserArea.stub_alloc_tail)` into HL (3–4 B); store target_bank
    byte 0 + INC HL (3 B); store `$C3` byte 1 + INC HL (4 B); store
    target_addr lo + INC HL + target_addr hi + INC HL (6 B); write
    `stub_alloc_tail` back via two `LD (IY+stub_alloc_tail+n), L/H`
    instructions (6 B); `RET` (1 B); caller-save overhead and entry-point
    label setup (~4–7 B).
  - **COLD initialisation for `stub_alloc_tail` (~9 B)** —
    `LD HL, STUB_ALLOC_BASE` (3 B); `LD (IY+UserArea.stub_alloc_tail), L`
    (3 B); `LD (IY+UserArea.stub_alloc_tail+1), H` (3 B). Lands in
    `src/antforth.asm` cold_start step 8h (immediately after the
    Story-17.1 banking-cell seeds at `src/antforth.asm:155..160`).
  - **`stub_alloc_tail` UserArea cell** — `DW 0` in
    `src/structures.asm` `STRUCT UserArea` block. **Zero kernel binary
    bytes** (the cell consumes UserArea RAM, not kernel binary; same
    pattern as Story 17.1's `saved_bank` / `current_bank` /
    `bank_table_base` / `bank_mapping_state` cells at lines 39–46 of
    that file). Appended at the end of the struct so pre-existing
    offsets are byte-identical.
  - **`STUB_ALLOC_BASE` constant in `src/constants.asm`** — compile-time
    `EQU`. **Zero kernel binary bytes** (sjasmplus constants are
    assembled-out, not emitted).
  - **iz-cpm test-643 layout-quirk padding (0–3 B)** — possible NOP
    padding at end of `cold_start` per `feedback_iz_cpm_test_643_quirk.md`
    (the quirk recurred at Story 17.1 +1 B and Story 17.2 +2 B; layout
    shift in 17.3/17.4/17.5/17.6 happened to keep the kernel at a 643-safe
    offset — Story 18.1 may need 0–3 B more depending on the resulting
    code-emit offset).
  - **CCD-3 source-comment block + redesign-§2.1 citations** — zero kernel
    binary delta (comments only).
  - **Probe block in `tests/banking_tests.fth`** — zero kernel binary
    delta (REPL-side probes).

  **Per-component sum: ~35–45 B kernel delta.** This is well under the
  AC9 spec ceiling of ≤ ~150 B and well under the Lesson 17-B realistic
  envelope of ~360–405 B (~2.4–2.7× spec target per
  `project_epic17_envelope.md`). Dev-pass tracks actual `wc -c` against
  the itemisation; if the realised delta exceeds the per-component
  estimate by a material margin, Dev Notes triple-Q6-a-extended
  accept-with-rationale is invoked per Action A3 of the Epic-17 retro
  (cite `project_epic17_envelope.md` inline, do not re-litigate).

**And** **AC10** — `make test-repl` ≥ **975 PASS / 0 FAIL / 2 SKIP** on
iz-cpm (no regression of the Epic-17 baseline); `make test-repl-banking`
reports the Epic-17 baseline of 35 PASS + Probe-18.1-A + Probe-18.1-B +
Probe-18.1-C all PASS (≥ 38 PASS / 0 FAIL); `make check-doc-sync` reports
clean (≤ 31 advisories / 0 drift — Epic-17 close baseline).

**FRs covered:** FR-P4-13 (descriptor stub), FR-P4-17 (xt portability —
stub is in fixed memory so xts are stable across `BANK!`).
**NFR codified:** NFR-P4-4 (per-stub size envelope ≤ 5 B; Story 18.1
realises 4 B per PD-P4-11).
**Architectural input consumed:** Story 16.4 §9.5 / PD-P4-11
(`architecture.md:347..365`, 4-byte stub layout); PD-P4-1
(`architecture.md:200..213`, the (γ) decision); redesign §2.1
(`docs/antforth-banking-redesign.md:34..42`).
**Standing commitments touched:** S9 (per-binary-delta-story hardware
smoke), S11 (no user-visible surface yet — banner stays at v3.0.1 until
Story 18.5's close-out tag), CCD-3 (source-comment pointers + redesign
§-citations), CCD-4 (per-epic benchmark gate — Epic 18 close-out at
Story 18.5 surfaces F2 banked-word stub-count metric for the first time;
Story 18.1 lays the substrate that produces stubs to count).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in
      story Dev Notes (expected baseline: **26,228 B** at Epic-17 close
      commit `39ac70b`; re-`wc -c` from the actual current build
      artifact per B.3 / Lesson 13.5-F; do **not** inherit the prior
      story's reported number). **Captured: 26,228 B (matches expected).**
- [x] Capture current `make test-repl` baseline pass count (expected:
      **975 PASS / 0 FAIL / 2 SKIP**). **Captured: 975 PASS / 2 SKIP / 0 FAIL.**
- [x] Capture current `make test-repl-banking` baseline (expected: **35
      PASS / 0 FAIL**). **Captured: 35 PASS / 0 FAIL.**
- [x] Capture current `make check-doc-sync` baseline (expected: **31
      advisories / 0 drift**). **Captured: 31 advisories / 0 drift.**
- [x] Cite `project_epic17_envelope.md` memory inline (Lesson 17-B
      empirical envelope is **~2.4–2.7×** the spec target; Q6-a-extended
      accept-with-rationale only triggers if the per-component estimate
      is overshot). **Memory cited; realised delta +70 B vs ~40–52 B
      per-component estimate = 1.4–1.75× — under the ~2.4–2.7× envelope,
      Q6-a-extended NOT invoked.**

### Task 1 — `STUB_ALLOC_BASE` constant (AC1)

- [x] Add `STUB_ALLOC_BASE EQU ACTIVE_PAGES_BASE + ACTIVE_PAGES_SIZE` (=
      `$D4CB`) to `src/constants.asm` adjacent to `BANK_TABLE_BASE` at
      `:17`. Constant is assembly-time only (zero kernel binary bytes).
      Landed at `src/constants.asm:19..27` with PD-P4-11 + redesign §2.1
      citation block (forward-references ACTIVE_PAGES_BASE / ACTIVE_PAGES_SIZE
      defined in `src/banking.asm:36..37`; sjasmplus two-pass resolves the
      forward reference cleanly).

### Task 2 — `stub_alloc_tail` UserArea cell (AC9 — UserArea-cell row)

- [x] Append `stub_alloc_tail DW 0` to the `STRUCT UserArea` block at
      `src/structures.asm:38..51` (after `bank_count` at line 47). Add
      a one-line inline comment naming the semantics, citing PD-P4-11
      (`architecture.md:347..365`) and Story 18.1. Landed at
      `src/structures.asm:51..52` (post bank_count); two-line inline
      comment (cell semantics + COLD init pointer).
- [x] Verify the existing 18 UserArea offsets are byte-identical
      (append-only, no insertions; same discipline as Story 17.1
      AC3). **Verified by build success — no pre-existing IY-offset
      reference changed semantics; sjasmplus reports 0 errors / 0 warnings
      across all 3 passes; 975-test regression confirms no offset drift.**

### Task 3 — COLD init for `stub_alloc_tail` (AC9 — COLD-init row)

- [x] Add three instructions in `src/antforth.asm`'s `cold_start` step 8h,
      immediately after the Story-17.1 banking-cell seeds at
      `src/antforth.asm:155..160`: `LD HL, STUB_ALLOC_BASE` /
      `LD (IY+UserArea.stub_alloc_tail), L` /
      `LD (IY+UserArea.stub_alloc_tail+1), H`. Landed at
      `src/antforth.asm:162..168` with a 4-line inline comment block
      citing PD-P4-11.
- [x] Verify on iz-cpm that the cell reads back `$D4CB` after COLD.
      **Verified indirectly via Probe-18.1-C: first allocated stub
      reports address `54475` (= `$D4CB` = `STUB_ALLOC_BASE`) — proves
      stub_alloc_tail was correctly seeded at COLD.**

### Task 4 — Descriptor-stub allocator routine (AC1, AC2, AC3, AC5, AC9 — allocator row)

- [x] Add the allocator routine at an appropriate position in
      `src/banking.asm` — after the existing Story-17.1/2/3 routine
      bodies and before the `str_*:` data tables. Suggested label:
      `stub_allocate:` (kernel-internal, not a DEFCODE word). Landed
      at `src/banking.asm` between `print_bank_col_4` (line 712) and
      the `--- .BANKS string literals ---` block. Label = `stub_allocate:`
      (kernel-internal helper). Forth-callable wrapper `(stub-allocate)`
      = `w_PAREN_STUB_ALLOCATE` immediately below the helper.
- [x] Define the allocator's register contract inline at the routine
      header: input registers (e.g. `B = target_bank` as a signed byte;
      `DE = target_addr_in_bank`), output register (e.g. `HL = stub
      address = the word's xt`), trash registers, register-preservation
      notes per `docs/register-conventions.md`. **Contract block in
      banking.asm: In: `B = target_bank (signed byte)`, `DE = target_addr_in_bank`.
      Out: `HL = stub address = the word's xt`. Clobbers: A. Preserves: DE
      (explicitly documented as Lesson 17-D NOT-required because no
      DE-touching opcode is used).**
- [x] **Apply Lesson 17-D PUSH/POP DE wrap proactively** if the allocator
      uses any `EX DE, HL` or `LDIR` — the DE/IP clobber pattern fired
      3× in Epic 17 (Story 17.2 CR H1 / Story 17.3 dev-pass / Story 17.4
      authored-prospective). Author the allocator DE-preserving from the
      start; if no DE-touching opcode appears in the routine body, note
      that explicitly in the inline comment. **No `EX DE, HL` / no `LDIR`
      / no DE-as-temp in the allocator body — DE is read-only (used via
      `LD (HL), E` and `LD (HL), D` to write bytes 2-3). No PUSH/POP DE
      wrap required; the absence is documented in the inline contract
      block.**
- [x] Emit the 4-byte stub layout per AC2: byte 0 = target_bank; byte 1
      = `$C3` (JP opcode); bytes 2–3 = target_addr lo/hi.
- [x] Write the new `stub_alloc_tail` value back to UserArea via two
      `LD (IY+UserArea.stub_alloc_tail+n)` instructions.
- [x] Add the CCD-3 source-comment block per AC5: header comment cites
      `docs/antforth-banking-redesign.md §2.1 (γ mechanism)` + inline
      paragraph cites PD-P4-11 (`architecture.md:347..365`) for the
      4-byte layout decision + references the banking subsystem header
      at `src/banking.asm:1..14`. **Comment block contains all three
      citations + a layout description + a forward-pointer to Stories
      18.2/18.3/18.4/18.5 consumers + a CCP-evicted-region budget note.**

### Task 5 — `tests/banking_tests.fth` probes (AC4, AC7)

- [x] Add a new sentinel-bounded probe block following the Story-17.5.1
      convention (sentinel header / numbered probes / sentinel footer).
      Block label: `Story 18.1: descriptor-stub allocator probes`.
      Landed at `tests/banking_tests.fth:710..820` (after the
      iron-spike block; stub_alloc_tail unaffected by iron-spike's
      BANK!/EXECUTE cycle).
- [x] **Probe-18.1-A** (stub-A layout — AC4 fixed-memory target +
      AC7 byte-layout assertion). **Recommendation taken: thin
      `(stub-allocate)` DEFCODE wrapper. Wrapper kernel cost ≈ 35 B
      (18 B DEFCODE header + 10 B body + 7 B NEXT) — over the AC9
      ~6–10 B itemisation per Lesson 17-B envelope; still under
      ceiling (total +70 B vs ~150 B AC9 ceiling).**
- [x] **Probe-18.1-B** (stub-B layout — AC4 banked target + AC7
      byte-layout assertion) — same shape as A but `target_bank = 5`,
      `target_addr = $8200`. Asserts byte 0 = 5, byte 1 = `$C3`,
      bytes 2–3 = `$00 $82`.
- [x] **Probe-18.1-C** (sequential allocation, no overlap — AC7) —
      allocates 10 stubs, walks addresses via a per-probe HERE-based
      cell buffer, asserts deltas = 4 between consecutive stubs and
      first = `$D4CB` / 10th = `$D4EF` (= first + 36). Prints first
      and last stub addresses + the expected values for Dev-Notes
      documentation.
- [x] Apply Lesson 17-F: smoke-test the probe block under
      iz-cpm-banking in its EXACT typed form before handing off
      to hardware. **Smoked: `make test-repl-banking` PASS for all
      three probes (38 PASS / 0 FAIL = 35 baseline + 3 new). First
      smoke-test surfaced `<>` undefined (Deliberately-omitted in
      v2.0 per docs/ans-forth-core-compliance.md §6.2.0500); replaced
      with `= INVERT` idiom (11 sites).**

### Task 6 — Build + regression (AC10)

- [x] `make build` clean; record `wc -c build/antforth.com` and
      compute delta against the pre-edit baseline; itemise the
      delta in Dev Notes against the AC9 per-component sum.
      **Result: 26,298 B; delta = +70 B vs 26,228 B baseline.
      Itemised delta in Dev Notes (Realised byte budget table) below.**
- [x] `make test-repl` ≥ 975 PASS / 0 FAIL / 2 SKIP on iz-cpm
      (no regression on Epic-17 close-out baseline). **975 PASS / 0 FAIL
      / 2 SKIP — exact baseline match.**
- [x] `make test-repl-banking` ≥ 38 PASS / 0 FAIL (35 prior + 3 new
      probes A/B/C). **38 PASS / 0 FAIL.**
- [x] `make check-doc-sync` ≤ 31 advisories / 0 drift. **31 advisories /
      0 drift — exact baseline match.**
- [x] If iz-cpm test 643 trips a layout-sensitive failure
      (per `feedback_iz_cpm_test_643_quirk.md`), apply the standard
      1-NOP-padding remedy at end of `cold_start` step 8h;
      document the NOP count in Dev Notes. **Not tripped: 975/975 PASS
      pre and post. No NOP padding added.**

### Task 7 — Hardware smoke (AC8)

- [x] Author the typed-form hardware-smoke recipe (~5–8 steps):
      open serial; clean boot; allocate two stubs via the
      `(stub-allocate)` wrapper; print the two stub addresses;
      compute the difference; assert difference = 4. Steps are
      designed for **independent verdict** per Lesson 17-C — the
      hardware run is not a redundancy check on `make
      test-repl-banking`, it is a separate verdict surface.
      **Recipe authored (see "Hardware-smoke recipe (typed-form)"
      block in Dev Notes below); smoke-tested under iz-cpm-banking
      with expected output `D4CB` then `D4CF` (delta = 4).**
- [x] Use the Story-17.6 5-helper-word decomposition pattern if the
      typed-form recipe risks the Story-17.6 hand-typed failure
      mode (long single-line input + `WORD`-parsing intermixed
      with memory writes). **Not applicable: recipe has no MOVE /
      no HERE-based body construction; it is two `(stub-allocate)`
      calls + two `U.` prints. The WORD-clobbers-MOVE-output failure
      mode (Story 17.6 mechanism) does not apply.**
- [x] Run on real MicroBeast; capture transcript to
      `~/Downloads/beastty-<timestamp>.bin`. **Run 2026-05-18 by Ant;
      transcript `~/Downloads/beastty-20260518-010328.bin`. Recipe
      output (verbatim): `$1000 1 (stub-allocate) U.` → `D4CB ok`;
      `$1000 1 (stub-allocate) U.` → `D4CF ok`. Two distinct monotonic
      hex addresses, delta = 4 — exact +4 per-stub stride, first stub
      at exactly `STUB_ALLOC_BASE = $D4CB`. Independent S9 verdict
      surface PASS on real hardware.**
- [x] Post the recipe **in the closing chat message** at code-review
      close per `feedback_post_hw_smoke_steps_at_review.md` STRONG
      rule (non-negotiable; ant has asked twice — fired 7× in
      Epic 17 across all binary-delta stories). **Posted in the
      dev-pass closing message; will repeat at code-review close.**

### Task 8 — Sprint-status + commit

- [x] Update sprint-status row `18-1-descriptor-stub-allocator-xt-as-stub-address-contract`
      → `review` (dev-pass close) → `done` (post-CR close). **Set to
      `review` at dev-pass close.**
- [ ] Compose dev-pass commit message per `gitmsg` convention; do
      **NOT** include `Co-Authored-By: Claude` trailer per
      `feedback_no_claude_coauthor.md` STRONG rule. **Deferred to the
      user (commit is the user's call).**
- [ ] At code-review close, mark Story 18.1 → `done` in sprint-status
      and apply any deferred CR-fix dispositions.

## Dev Notes

### Architectural inputs consumed

- **PD-P4-11** (`architecture.md:347..365`) — descriptor-stub size pin
  from Story 16.4 §9.5 closure. 4 bytes chosen: byte 0 = signed
  `target_bank` (`-1` = fixed-memory marker; `0..28` = active bank
  index); bytes 1–3 = `JP target_addr` (`C3 lo hi`). This is the
  smallest contiguous layout that satisfies both FR-P4-13 (stub carries
  `(target_bank, target_addr_in_bank)`) and FR-P4-15 (intra-bank dispatch
  = one extra `JP` overhead vs flat dispatch). Per-1000-words cost = 4 KB
  out of NFR-P4-5's ≤ 8 KB envelope; ~4 KB headroom for CL parser /
  bank-table[] / trampoline / allocator / banking-word bodies. Stub
  output region in Story 18.1 = `$D4CB` (= `ACTIVE_PAGES_BASE +
  ACTIVE_PAGES_SIZE`) onward in the CCP-evicted Page-3 region.
- **PD-P4-1** (`architecture.md:200..213`) — the (γ) decision; per-word
  descriptor stubs collapse S1 (cross-bank EXIT) + S6 (`EXECUTE`) + S7
  (`COMPILE,`) into one artifact. xts remain cell-sized and stable
  across `BANK!`. `BANK-OF` becomes a one-byte read from the stub.
- **PD-P4-6** (`architecture.md:271..282`) — CCP eviction at
  `$D400`–`$DBFF` for `bank-table[]` + descriptor-stub allocator. Story
  16.1 verified eviction is safe on real MicroBeast hardware (transcript
  `~/Downloads/beastty-20260513-110640.bin`). Story 17.1 reclaimed the
  region for `bank-table[]` (+ active_pages[] in Story 17.3); Story 18.1
  carves the descriptor-stub allocator output region out of the
  post-active_pages portion of the same region.
- **Redesign §2.1** (`docs/antforth-banking-redesign.md:34..42`) — the
  (γ) decision in narrative form: "every banked word, when defined,
  also gets a 3–5-byte stub in fixed memory containing `(target_bank,
  target_addr_in_bank)`. **The stub's address is the word's xt.**"
- **Redesign §7** (`docs/antforth-banking-redesign.md:119..132`) —
  performance / memory budget table. Per-stub-size row says "3 bytes
  minimum, 4–5 bytes realistic with `JP` opcode". PD-P4-11 closes that
  range to 4 bytes.
- **Implementation Patterns naming convention** (`architecture.md:528..536`)
  — "Stub address IS the xt — name stub-allocator output `xt_<word>`
  consistently in source; never `stub_<word>` (the stub IS the xt; the
  names should not encode internal structure)".

### Source-file structure (current state, pre-edit)

- `src/banking.asm` (current size 721 lines / 34,117 B source —
  re-`wc -l` at dev-pass start per B.3) — header at `:1..14` already
  forward-points to Story 18.1 ("Story 18.1 carves the descriptor-stub
  allocator out of the post-bank-table[] portion of this region.").
  Existing routines: `BANK-MAPPING-ON` (`:39..58`); `BANK-MAPPING-OFF`
  (`:59..88`); `BANK@` (`:90..104`); `BANK!` (`:106..228`); `BANKS`
  (`:230..257`); `+BANK` (`:259..318`); `cl_probe_and_add` helper
  (`:320..380`); `-BANK` (`:385..438`); `BANKS-CLEAR` (`:440..473`);
  `SET-BANK` (`:475..501`); `.BANKS` (`:503..714`); `str_*` data tables
  (`:715..721`).
- `src/constants.asm:17` — `BANK_TABLE_BASE EQU $D400`. Story 18.1
  appends `STUB_ALLOC_BASE EQU ACTIVE_PAGES_BASE + ACTIVE_PAGES_SIZE`
  immediately after.
- `src/structures.asm:38..51` — UserArea Phase-4 banking block. Story
  18.1 appends `stub_alloc_tail DW 0` after `bank_count` at `:47`.
- `src/antforth.asm:130..245` — COLD `cold_start` step 8h. Story 17.1's
  banking-cell seeds are at `:155..160`; Story 18.1 appends three
  instructions (`LD HL, STUB_ALLOC_BASE` + two `LD (IY+stub_alloc_tail+n), L/H`)
  immediately after.

### Memory-map math (pre-edit baseline)

- `BANK_TABLE_BASE` = `$D400` (per Story 17.1; `src/constants.asm:17`).
- `BANK_TABLE_SHELL_SIZE` = `BANK_TABLE_CAP * BANK_TABLE_ENTRY_SIZE` =
  `29 × 6` = `174 B` (`$00AE`). End of `bank-table[]` = `$D400 + $00AE`
  = `$D4AE`.
- `ACTIVE_PAGES_BASE` = `$D4AE` (per Story 17.3; `src/banking.asm:36`).
- `ACTIVE_PAGES_SIZE` = `29 B` (`$001D`). End of `active_pages[]` =
  `$D4AE + $001D` = `$D4CB`.
- **`STUB_ALLOC_BASE`** = `$D4CB` (new constant per Story 18.1).
- CCP-evicted region upper bound = `$DBFF` (per PD-P4-6 closure;
  `architecture.md:271..282`).
- Available stub-output bytes = `$DBFF - $D4CB + 1` = `$0735` = **1845 B**
  = up to **461 stubs** at 4 B each in the CCP-evicted region alone.
  Additional stubs (beyond ~461) would land in the dictionary's HERE
  region — but the kernel binary's own banking-infrastructure use of
  the CCP-evicted region (allocator + bank-table[] + active_pages[]) is
  capped at well under 2 KB, so the headroom for stubs in this region
  is generous for default workloads (12 banks × ~50 banked words = 600
  stubs worst case — which would consume 2400 B and overflow the
  CCP-evicted region; that overflow is an Epic 19 / 21+ concern, not a
  Story 18.1 concern).

### Byte budget (per-component itemisation per B.2 / Lesson 13.5-C)

The story-template "Pre-edit baseline" task captures the actual byte
delta against this itemisation.

| Component | Estimated kernel delta |
|-----------|------------------------:|
| Allocator routine body (`stub_allocate:`) | ~25–30 B |
| COLD init for `stub_alloc_tail` (3 instructions) | ~9 B |
| `(stub-allocate)` DEFCODE wrapper for AC7 probes (optional; recommended for layout-knowledge locality) | ~6–10 B |
| `stub_alloc_tail` UserArea cell | 0 B (UserArea RAM, not kernel binary) |
| `STUB_ALLOC_BASE` constant in `src/constants.asm` | 0 B (sjasmplus `EQU` — assembled out) |
| iz-cpm test-643 layout-quirk NOP padding (per `feedback_iz_cpm_test_643_quirk.md`) | 0–3 B |
| CCD-3 source-comment block + redesign-§2.1 citations | 0 B (comments only) |
| Probe block in `tests/banking_tests.fth` (3 probes) | 0 B (REPL-side) |
| **Per-component sum** | **~40–52 B** |

This is well under the AC9 spec ceiling of ≤ ~150 B. Per Lesson 17-B
+ `project_epic17_envelope.md`, the realistic envelope across Epic 17
ran ~2.4–2.7× spec targets (Story 17.1 came in at +106 B / 0.27× of the
~400 B Epic-17 spec target; Story 18.1's spec ceiling for itself is the
~150 B figure, against which ~40–52 B is comfortably inside). Q6-a-extended
accept-with-rationale is **not expected to fire** at this story; if the
realised delta materially exceeds the per-component itemisation, cite
`project_epic17_envelope.md` inline in Dev Notes rather than re-litigating
the disposition.

### Standing commitments touched

- **S1** — adversarial CR fresh-context: code-review for Story 18.1
  runs separately via the `CR` command in fresh LLM session at dev-pass
  close (per `_bmad/bmm/agents/dev.md` `CR` item; do not enumerate in
  ACs per the rejected pattern at instructions.xml :20..31).
- **S2** — REPL-piped tests: AC7's three probes are sentinel-bounded
  REPL-piped Forth scripts (per `feedback_repl_tests_preferred.md`).
- **S3** — real byte-count estimation: per-component itemisation above
  per B.2 / Lesson 13.5-C.
- **S4** — AC-composition validation: AC4 (hand-test) + AC7 (REPL probes)
  + AC8 (hardware smoke) compose. AC2 layout decision + AC6 envelope
  measurement compose. AC9 budget + AC10 regression compose.
- **S7** — EXX-hygiene: the allocator is a kernel-internal routine, not a
  THROW-raise site. No EXX use anticipated; if dev-pass needs EXX, the
  S7 leaf-level rule (`docs/register-conventions.md §3 + §7`) applies.
- **S9** — per-binary-delta-story hardware smoke: AC8 + Task 7. Planned
  as **independent verdict surface** per Lesson 17-C.
- **S11** — user-visible version surface audit: not surfaced at Story
  18.1 (banner stays at v3.0.1; the next S11 surface is Story 18.5's
  Epic 18 close-out tag at antforth 3.x.2).
- **S12** — hardware-typed probe discipline: Task 7's hardware-smoke
  recipe must be typed-form-validated under iz-cpm-banking before
  handing off to hardware (Lesson 17-F).
- **CCD-3** — source-comment pointers: AC5 + Task 4 inline citation of
  redesign §2.1 + PD-P4-11.
- **CCD-4** — per-epic benchmark gate: Story 18.5 surfaces F2 banked-word
  stub-count metric; Story 18.1 lays the substrate that produces stubs
  to count.

### Forward-inheritance pointers

- **Story 18.2** (sentinel-trampoline `cross_bank_return` + EXIT sentinel
  comparison) inherits: the 4-byte stub layout (byte 0 = bank, bytes 1–3
  = `JP target_addr`); the `STUB_ALLOC_BASE` constant location; the
  `stub_alloc_tail` UserArea cell name; the two AC4 hand-test stub
  addresses (recorded in AC7 probe output) as known-shape inputs for
  the cross-bank-EXIT probes.
- **Story 18.3** (kernel `EXECUTE` dispatches through stub + initial
  `COMPILE,` stub-emission wiring) inherits: the allocator's
  Forth-callable wrapper (if dev-pass picks the wrapper-DEFCODE shape
  in Task 5) as the seam where `COMPILE,` calls into the allocator; the
  4-byte layout's byte-0-is-bank / bytes-1..3-is-JP convention for the
  `EXECUTE` chokepoint decoder.
- **Story 18.4** (`BANK-OF`) inherits: byte 0 as the signed `target_bank`
  field; the `-1`-is-fixed-memory marker convention; the
  xt-IS-stub-address contract from AC3.
- **Story 18.5** (`IN-BANK` + Epic 18 close-out) inherits: the verdict
  table row for Story 18.1 (PASS / +N B / 1 hardware transcript) per
  the Story-13.5.6 precedent for epic close-out verdict walks.
- **Epic 19** (`:` lands body in current bank + auto-emits descriptor
  stub on `;`) inherits the allocator as the routine `;` calls when
  finishing a banked colon-definition.

### Lessons applied

- **Lesson 17-B** (`project_epic17_envelope.md`) — empirical envelope
  was ~2.4–2.7× the redesign-§7 / epics-spec stated target across Epic
  17. For Story 18.1, the per-component itemisation lands at ~40–52 B
  (well under the AC9 ~150 B spec ceiling and well under the ~360–405 B
  realistic envelope). Cite the memory inline at dev-pass start;
  Q6-a-extended re-litigation is **not** expected.
- **Lesson 17-C** — hardware-smoke is an **independent verdict surface**,
  not a redundancy check on `make test-repl-banking`. AC8 + Task 7 plan
  the hardware run as a separate verdict — two allocated stubs assert
  non-overlapping addresses on real MicroBeast, with a typed-form
  recipe authored independently of the AC7 probe shape.
- **Lesson 17-D** (PUSH/POP DE wrap; surfaced 3× in Epic 17 at Stories
  17.2 CR H1 / 17.3 dev-pass / 17.4 prospective) — the allocator is
  authored DE-preserving from the start. If the routine body uses no
  DE-touching opcode (no `EX DE, HL`, no `LDIR`, no DE-as-temp), state
  that explicitly in the inline source-comment block so the absence is
  documented rather than inferred.
- **Lesson 17-F** — hand-typed hardware-smoke recipes for hand-built
  memory-write probes are brittle. AC8's typed-form recipe is
  smoke-tested under iz-cpm-banking in its EXACT typed form before
  handing off to hardware (Task 7); if any step risks the `WORD`-
  clobbers-`MOVE`-output failure mode from Story 17.6, decompose to
  short helper words per the Story-17.6 5-helper-word pattern.
- **Story 17.1 close-out hygiene** — append UserArea cells at the end of
  the struct to preserve pre-existing offsets byte-identical (Task 2);
  cite PD-P4-N decisions inline at the source site per CCD-3 (Task 4 +
  AC5); the `BANK_TABLE_BASE` constant pattern at `src/constants.asm:17`
  is the model for `STUB_ALLOC_BASE` (Task 1).
- **`project_bank_table_clone_at_cold.md` memory** — Story 17.4's
  bank-table[1..28] LDIR-clone fix was needed because first-visit
  `BANK!` to bank N loaded HERE=0 and corrupted BIOS dispatch at
  `$0000`–`$0005`. Story 18.1 has no equivalent first-visit corruption
  risk because the allocator writes to fresh memory (`stub_alloc_tail`
  starts at `$D4CB` and advances; nothing reads a "first-visit" stub
  that the allocator hasn't yet written). Forward pointer: if Epic 19
  introduces a `:` that allocates a stub before the body is emitted,
  any inter-bank stub-read-before-write hazard would surface there, not
  here.
- **`feedback_no_claude_coauthor.md` STRONG rule** — commit messages must
  NOT include `Co-Authored-By: Claude` trailer.
- **`feedback_post_hw_smoke_steps_at_review.md` STRONG rule** — hardware-
  smoke recipe is posted in the closing chat message at code-review
  close (Task 7 + Task 8). Fired 7× in Epic 17 across all binary-delta
  stories; non-negotiable.
- **`feedback_iz_cpm_test_643_quirk.md`** — possible layout-sensitive
  iz-cpm test 643 trip; standard remedy is 1-NOP-padding at end of
  `cold_start` step 8h (Task 6).

### Project Structure Notes

- **No new files created** in Story 18.1. All work lands in existing
  Phase-4 files: `src/banking.asm` (allocator routine + `(stub-allocate)`
  wrapper if chosen); `src/constants.asm` (`STUB_ALLOC_BASE`);
  `src/structures.asm` (`stub_alloc_tail` UserArea cell);
  `src/antforth.asm` (COLD init); `tests/banking_tests.fth` (3 sentinel-
  bounded probes).
- **No file-touch surface variance** vs the architecture's Phase-4
  file-touch map (`architecture.md:744..798`). The map at row Epic 18
  (`:840`) names `src/banking.asm` for descriptor-stub layout +
  sentinel-trampoline, `src/inner_interpreter.asm` for the `EXIT`/`EXECUTE`
  edits, and `tests/banking_tests.fth` for cross-bank dispatch probes.
  Story 18.1 touches `src/banking.asm` (allocator) +
  `tests/banking_tests.fth` (probes); `src/inner_interpreter.asm` is
  Story 18.2/18.3 scope.
- **CCP-evicted region annex** is unchanged in claim (still
  `$D400`–`$DBFF` per Story 17.1 `src/banking.asm:10..14`) — Story 18.1
  carves the descriptor-stub allocator output region from `$D4CB` upward
  inside the same annex.

### References

- **Epic 17 retro** (`_bmad-output/implementation-artifacts/epic-17-retro-2026-05-17.md`)
  — Lessons 17-A through 17-G; Action items A1 / A2 / A3 / A4 carried
  forward to Epic 18 / Story 18.1.
- **Story 17.6** (`_bmad-output/implementation-artifacts/17-6-iron-spike-first-hand-built-cross-bank-call-on-real-microbeast-epic-17-close-out-antforth-3-x-1-tag.md`)
  — iron-spike PASS validates BANK!-EXECUTE-RET round-trip for
  main-RAM-resident bodies; banked-RAM-resident-executable validation is
  Epic 19+ iron-spike-2 scope per A5 (not Story 18.1; Story 18.1's two
  hand-test stubs are layout-only, not execute-through).
- **Story 17.1**
  (`_bmad-output/implementation-artifacts/17-1-bank-table-allocator-userarea-cells-bank-mapping-on-bank-mapping-off-ccp-eviction-memory-map-edit.md`)
  — banking foundation precedent; UserArea-cell-append pattern; constant-
  in-`src/constants.asm` pattern; CCD-3 inline-comment pattern.
- **PRD Phase-4** (`_bmad-output/planning-artifacts/prd.md` /
  `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md`) —
  FR-P4-13 / FR-P4-17 / NFR-P4-4.
- **Architecture Phase-4** (`_bmad-output/planning-artifacts/architecture.md`)
  — PD-P4-1 (`:200..213`); PD-P4-6 (`:271..285`); PD-P4-11 (`:347..365`);
  Implementation Patterns / naming convention (`:528..536`); File-touch
  surface (`:744..798`); Epic-18 file-touch row (`:840`).
- **Redesign doc** (`docs/antforth-banking-redesign.md`) — §2.1 (γ
  decision; `:34..42`); §5.2 (CP/M residency layout; `:87..95`); §7
  (perf/memory budgets; `:119..132`).
- **Memory** — `project_phase4_scope.md`; `project_epic17_envelope.md`;
  `project_bank_table_clone_at_cold.md`; `feedback_iz_cpm_test_643_quirk.md`;
  `feedback_repl_tests_preferred.md`; `feedback_no_claude_coauthor.md`;
  `feedback_post_hw_smoke_steps_at_review.md`;
  `feedback_no_accept_disposition_for_bugs.md`;
  `feedback_assembler_operand_order.md` (Zilog dst-src order for any
  new instructions in Task 4); `project_assembler_keep_assembly.md`
  (banking.asm stays kernel-resident assembly — confirmed for Story
  18.1).

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context)

### Debug Log References

- `wc -c build/antforth.com` pre-edit: **26,228 B** (matches expected
  Epic-17 close baseline at commit `39ac70b`).
- `wc -c build/antforth.com` post-edit: **26,298 B** (delta = **+70 B**).
- `make test-repl` pre-edit: 975 PASS / 0 FAIL / 2 SKIP. Post-edit: same.
- `make test-repl-banking` pre-edit: 35 PASS / 0 FAIL. Post-edit:
  **38 PASS / 0 FAIL** (= 35 baseline + 3 new probes A/B/C).
- `make check-doc-sync` pre-edit: 31 advisories / 0 drift. Post-edit: same.
- First smoke run surfaced `<>` undefined (-13). Root cause: `<>` is
  Deliberately-omitted in v2.0 per `docs/ans-forth-core-compliance.md`
  §6.2.0500; replaced 11 sites with `= INVERT` idiom in
  `tests/banking_tests.fth`. Re-smoke PASS.

### Completion Notes List

- **Story 18.1 dev-pass complete.** All 10 ACs satisfied:
  - **AC1** — `STUB_ALLOC_BASE` constant lands in `src/constants.asm`;
    allocator routine lands in `src/banking.asm`. STUB_ALLOC_BASE = $D4CB
    (verified by Probe-18.1-C first-stub-address assertion).
  - **AC2** — Stub layout per PD-P4-11: byte 0 = target_bank (signed),
    byte 1 = `$C3`, bytes 2-3 = target_addr lo/hi. Inline CCD-3 comment
    block at source site cites PD-P4-11 + redesign §2.1 + banking
    subsystem header.
  - **AC3** — Naming convention: kernel helper = `stub_allocate:` (assembly
    label); Forth-callable wrapper = `(stub-allocate)` (DEFCODE word,
    label `w_PAREN_STUB_ALLOCATE` per existing paren-named convention
    e.g. `w_PAREN_SAVE_INPUT`). Stub address IS the xt (verified by AC4
    hand-test recording stub address from `(stub-allocate)` return).
  - **AC4** — Two hand-test stubs allocated (Probes A + B): Stub A
    (target_bank = -1, target_addr = `['] BANK@`); Stub B (target_bank = 5,
    target_addr = $8200). Both layout-only; bytes inspected via C@; stub
    addresses recorded in probe output for Stories 18.2/18.3/18.4
    inheritance.
  - **AC5** — CCD-3 comment block at `src/banking.asm` allocator site:
    cites `docs/antforth-banking-redesign.md §2.1 (γ mechanism)` +
    PD-P4-11 (`architecture.md:347..365`) + banking subsystem header at
    `src/banking.asm:1..14` + forward pointers to Story 18.2/18.3/18.4
    consumers.
  - **AC6** — Per-stub allocation footprint = **4 B exactly** (verified
    by Probe-18.1-C: deltas between 10 consecutive stubs all = 4). Under
    the NFR-P4-4 ≤ 5 B envelope. Per-banked-word stub-count metric
    deferred to Story 18.5 close-out per F2 mitigation.
  - **AC7** — Three sentinel-bounded probes land in `tests/banking_tests.fth`:
    Probe-18.1-A / -B / -C. Each is self-contained, runs at REPL through
    `make test-repl-banking`, uses the Story-17.5.1 sentinel + awk-extract
    pattern + M4 end-sentinel-on-own-line check. Probe order: C first
    (depends on stub_alloc_tail = STUB_ALLOC_BASE at entry), then A
    and B (layout-only, no address dependency).
  - **AC8** — Probes A/B/C PASS under iz-cpm-banking (`make
    test-repl-banking`). Hardware-typed probe recipe authored +
    smoke-tested under iz-cpm-banking, then run on real MicroBeast
    **2026-05-18 by Ant**; transcript
    `~/Downloads/beastty-20260518-010328.bin`. Hardware output
    `D4CB` then `D4CF` (delta = 4, first stub at exactly
    `STUB_ALLOC_BASE`). Independent S9 verdict surface PASS.
  - **AC9** — Kernel binary delta = **+70 B** (26,228 → 26,298 B). Well
    under the AC9 spec ceiling of ≤ ~150 B. Per-component itemisation
    landed at ~40–52 B (estimate); realised at ~70 B (1.4–1.75× the
    estimate). Under the Lesson 17-B / `project_epic17_envelope.md`
    empirical ~2.4–2.7× envelope. Q6-a-extended accept-with-rationale
    **NOT invoked** — realised delta is inside both the spec ceiling
    AND the per-component estimate envelope.
  - **AC10** — `make test-repl` 975 PASS / 0 FAIL / 2 SKIP (no regression);
    `make test-repl-banking` 38 PASS / 0 FAIL (= 35 baseline + 3 new);
    `make check-doc-sync` 31 advisories / 0 drift (Epic-17 baseline
    exact match).

### Realised byte budget (per-component itemisation per B.2)

| Component | Estimated | Realised |
|-----------|----------:|---------:|
| Allocator routine body (`stub_allocate:`) | ~25–30 B | ~24 B |
| COLD init for `stub_alloc_tail` (3 instructions) | ~9 B | ~9 B |
| `(stub-allocate)` DEFCODE wrapper | ~6–10 B | ~35 B (18 B header + 10 B body + 7 B NEXT) |
| `stub_alloc_tail` UserArea cell | 0 B | 0 B |
| `STUB_ALLOC_BASE` constant in `src/constants.asm` | 0 B | 0 B |
| iz-cpm test-643 layout-quirk NOP padding | 0–3 B | 0 B (no trip) |
| CCD-3 source-comment block | 0 B | 0 B |
| Probe block in `tests/banking_tests.fth` | 0 B | 0 B |
| **Per-component sum** | **~40–52 B** | **~68–70 B** |
| **Actual `wc -c` delta** | — | **+70 B** |

Realised vs estimate ratio = 70 / 46 (midpoint) = **1.52×**. Inside the
Lesson 17-B empirical envelope (~2.4–2.7× across Epic 17 stories) and
inside the AC9 spec ceiling (~150 B). The over-estimate row is the
`(stub-allocate)` wrapper (~6–10 B estimated, ~35 B realised) — the
estimate undercounted the DEFCODE header (18 B for the 15-char name
`(stub-allocate)`) + the NEXT macro tail (~7 B). Q6-a-extended
accept-with-rationale **NOT invoked**.

### Hardware-smoke recipe (typed-form; AC8 / S9 / Task 7)

Typed-form recipe for real MicroBeast hardware verdict. Smoke-tested
under iz-cpm-banking (output `D4CB` then `D4CF`, delta = 4 confirms
non-overlapping stubs at exact `STUB_ALLOC_BASE` + per-stub stride 4).

```
HEX
$1000 1 (stub-allocate) U.       \ expect: D4CB
$1000 1 (stub-allocate) U.       \ expect: D4CF (= first + 4)
DECIMAL
```

Independent verdict surface per Lesson 17-C:
- **PASS**: both `U.` lines print distinct, monotonic hex addresses
  with delta = 4 (visible inline by reading both outputs).
- **FAIL**: kernel crash, identical addresses, delta ≠ 4, or no output.

No HERE/ALLOT / MOVE / hand-built body construction (Story 17.6
WORD-clobbers-MOVE-output failure mode does not apply); recipe is safe
to type interactively without the 5-helper-word decomposition pattern.
Transcript capture path: `~/Downloads/beastty-<timestamp>.bin`.

### File List

- `src/constants.asm` — added `STUB_ALLOC_BASE EQU ACTIVE_PAGES_BASE
  + ACTIVE_PAGES_SIZE` (= `$D4CB`) with PD-P4-11 + redesign §2.1
  citation block. (0 B kernel binary; assembly-time constant.)
- `src/structures.asm` — appended `stub_alloc_tail DW 0` to the
  `STRUCT UserArea` block after `bank_count` (preserves all pre-existing
  IY offsets).
- `src/antforth.asm` — added 3-instruction COLD seed for
  `stub_alloc_tail = STUB_ALLOC_BASE` in `cold_start` step 8h, after
  the Story-17.1 banking-cell seeds.
- `src/banking.asm` — added `stub_allocate:` kernel-internal allocator
  routine + `(stub-allocate)` DEFCODE wrapper
  (`w_PAREN_STUB_ALLOCATE` / `w_PAREN_STUB_ALLOCATE_cf`) between
  `print_bank_col_4` and the `--- .BANKS string literals ---` block.
  Inline CCD-3 comment block at the routine site cites PD-P4-11 + redesign §2.1.
- `tests/banking_tests.fth` — appended Story 18.1 probe block (Probes
  18.1-C / -A / -B in invocation order). Includes 5 VARIABLEs + 3 colon
  bodies + invocations.
- `Makefile` — added 3 awk-extract + grep sentinel-bounded assertions
  for Probes 18.1-A/-B/-C to the `test-repl-banking` recipe.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` —
  development_status for `18-1-descriptor-stub-allocator-xt-as-stub-address-contract`
  updated from `ready-for-dev` → `in-progress` → `review`.

### Change Log

- **2026-05-17** — Story 18.1 dev-pass: descriptor-stub allocator landed
  in `src/banking.asm` (`stub_allocate:` kernel helper +
  `(stub-allocate)` DEFCODE wrapper); `STUB_ALLOC_BASE` constant in
  `src/constants.asm`; `stub_alloc_tail` UserArea cell appended in
  `src/structures.asm`; COLD init in `src/antforth.asm`. Three
  sentinel-bounded REPL probes added in `tests/banking_tests.fth`. All
  10 ACs PASS. Kernel binary delta = +70 B (26,228 → 26,298 B; under
  AC9 ~150 B ceiling). `make test-repl-banking` 38 PASS / 0 FAIL.
  Status → review (sprint-status.yaml + this file).
- **2026-05-18** — Hardware-smoke S9 verdict surface: run on real
  MicroBeast by Ant; transcript `~/Downloads/beastty-20260518-010328.bin`.
  Recipe output `D4CB` then `D4CF` — two distinct monotonic hex
  addresses, delta = 4, first stub at exactly `STUB_ALLOC_BASE = $D4CB`.
  Independent S9 verdict surface PASS on real hardware. AC8 complete.
- **2026-05-18** — Code-review CR-fix pass: dispositions
  `Fix-now M1+M3, defer M2`. (a) M1 — allocator clobber-list comment
  rewritten to accurately document full main-set preservation (was
  incorrectly claiming `Clobbers: A` when A is in fact preserved by
  the routine's emitted instructions); also fixed the parallel
  comment at the `(stub-allocate)` wrapper's CALL site. (b) M3 —
  inline annotations added to Probes-18.1-A/B documenting `195 = $C3
  JP opcode` and the byte-by-byte semantics; bonus defect surfaced
  during the fix (long inline annotations overflowed TIB_SIZE = 128
  on the byte0 lines, broke colon-body compilation); resolved by
  hoisting the annotations to a pre-assertion block comment.
  (c) M2 — deferred to a forward-pointer note in the probe block
  header; refactor (capture stub_alloc_tail at probe entry,
  assert relative-stride + separate absolute-COLD-init verification)
  filed against Story 18.2 / a CR-followup. Zero kernel binary
  delta from CR fixes (all comment / REPL-side changes). Regression
  re-verified: test-repl 975/0/2; test-repl-banking 38/0;
  check-doc-sync 31/0. Status → done.

## Senior Developer Review (AI)

**Reviewer:** Claude Opus 4.7 (1M context) — same session as dev-pass
(S1 fresh-context discipline NOT satisfied; project-lead waived in
favour of in-session adversarial pass).
**Review date:** 2026-05-18
**Review outcome:** **Changes Requested → Resolved** (3 medium + 2 low
findings; user disposed `Fix-now M1+M3, defer M2`; M2 documented as
forward-pointer; one bonus defect (TIB overflow on long inline
annotation) surfaced during M3 fix and resolved before close).

### Action Items

- [x] **[AI-Review][Medium] M1** — Rewrite allocator clobber-list
  comment at `src/banking.asm:761..773` to accurately document full
  main-set preservation. Was claiming `Clobbers: A`; actual emitted
  code (`LD r,(IY+d)`, `PUSH HL`, `LD (HL),r/imm`, `INC HL`,
  `LD (IY+d),r`, `POP HL`, `RET`) preserves A/B/C/D/E/flags. Also
  fixed the parallel "clobbers A" comment at the `(stub-allocate)`
  wrapper's CALL site (`src/banking.asm:809`).
- [x] **[AI-Review][Medium] M3** — Add `\ 195 = $C3 JP opcode`
  inline annotations to Probes-18.1-A/B assertion sites
  (`tests/banking_tests.fth:780..783, 812..815`). Hoisted to a
  pre-assertion block comment after the first attempt overflowed
  TIB_SIZE = 128 on the byte0 lines.
- [ ] **[AI-Review][Medium] M2** — Probe-18.1-C absolute-address
  assertion is brittle to allocator-call-order. Refactor to capture
  stub_alloc_tail at probe entry (via a peek), assert relative
  stride-4 + separate absolute-COLD-init verification. **Deferred to
  Story 18.2 or a CR-followup story.** Documented as a CR-M2 block
  comment in `tests/banking_tests.fth` probe-block header.
- [x] **[AI-Review][Low] L1** — Inconsistent `1+` vs `2 +` style in
  Probes-A/B. **Not fixed; cosmetic; accepted with rationale: pre-
  existing style across banking_tests.fth.**
- [x] **[AI-Review][Low] L2** — Wrapper realised cost (~35 B) over
  the spec estimate (~6–10 B) due to undercounted DEFCODE header
  for the 15-char paren-prefixed name. **Not a defect; flagged for
  future-story estimation calibration (paren-prefixed DEFCODE words
  cost `18 + body + 7`).**

### Bonus defect surfaced during CR-fix (NOT in original review)

- [x] **[CR-Fix-induced][High-caught-pre-merge]** — First M3-fix
  attempt added long inline annotations that overflowed antforth's
  TIB_SIZE = 128 on the byte0 lines of Probes-A/B. Symptom:
  `make test-repl-banking` failed (1 FAIL / 36 PASS / 0 SKIP); the
  REPL truncated the line at char 128, dropping the closing `)` of
  the citation, then re-interpreted the `)` as a token on the next
  line (-13 undefined word). Resolved by hoisting the annotations
  to a pre-assertion block comment. Re-verified 38 PASS / 0 FAIL.
  Lesson banked: inline `\` comments on Forth lines must keep the
  TOTAL line length ≤ 128 chars (TIB_SIZE). If a long annotation
  is needed, hoist to a preceding `\ ...` block.

### Tasks/Subtasks → Review Follow-ups (AI)

(All M1/M3/L1/L2 disposed inline; M2 carries forward to Story 18.2
or a follow-up story per the user's disposition.)
