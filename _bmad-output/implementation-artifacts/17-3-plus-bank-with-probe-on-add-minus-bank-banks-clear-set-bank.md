# Story 17.3: `+BANK` (with probe-on-add) + `-BANK` + `BANKS-CLEAR` + `SET-BANK`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Context — why this story exists, why now

Third story of Epic 17 (Bank primitives + CL configuration), the third
binary-delta story of Phase 4. Stories 17.1 + 17.2 closed shipping the
banking foundation (`src/banking.asm` subsystem, 29-entry `bank-table[]`
shell at `$D400`, six UserArea cells, COLD bank-table[0] live-triple
snapshot, `BANK-MAPPING-ON` / `BANK-MAPPING-OFF` / `BANK@` / `BANK!` /
`BANKS`). Post-17.2 baseline = **25,285 B / 975 PASS / 0 FAIL / 2
SKIP-on-iz-cpm** (re-verify at dev-pass start per B.3 — see Pre-edit
baseline task). Epic-17 envelope consumed = **290 B of ~400 B (72.5%)**;
remaining envelope for Stories 17.3 + 17.4 + 17.5 = **~110 B**.

Story 17.3 lands the **four bank-list-mutating words** that turn
Story 17.2's empty-list `bank?error` precondition path into a populated
active list:

1. **`+BANK ( page -- )`** — probe a physical page (write sentinel,
   read back, restore), `ABORT" probe?"` if read-back fails (ROM,
   unmapped, unstable); on success, append `page` to `active_pages[]`,
   increment `bank_count`. `ABORT" cap?"` if `bank_count` already
   at the 29-entry cap (per PD-P4-13 / §9.4 closure). FR-P4-7.
2. **`-BANK ( page -- )`** — search `active_pages[]` for `page`; if
   present, shift entries down and decrement `bank_count`; if absent,
   silent no-op (no THROW). Does not affect underlying memory. FR-P4-8.
3. **`BANKS-CLEAR ( -- )`** — zero `bank_count`; `BANK!` raises
   `ABORT" bank?"` for any argument until `+BANK` rebuilds the list.
   The `active_pages[]` array bytes may be left non-zero (only
   `bank_count` is load-bearing for `BANK!`'s precondition; the
   garbage tail entries are unreachable). FR-P4-9.
4. **`SET-BANK ( page slot -- )`** — raw `OUT (0x70+slot), page`
   diagnostic. Bypasses `active_pages[]`; does NOT update
   `current_bank` or `bank_count`; documented as "diagnostics only —
   bad arguments produce undefined hardware behaviour". FR-P4-10.

Story 17.3 also **enables the two Story 17.2 PENDING-17.3 probes**
(`bank-store-round-trip-1`, `bank-store-round-trip-0` at
`tests/banking_tests.fth:178..202`) and **retires the
`_SEED-BANK` / `_CLEAR-BANK` inline-asm fixture** added in Story 17.2's
review pass — Story 17.3's `$22 +BANK` is the canonical replacement for
the fixture's `(IY+UserArea.bank_count) := 1` + `active_pages[0] := $22`
direct cell writes.

The forward-inheritance contract is captured in §"Forward inheritance
pointers" below: Story 17.4 owns the CL parser (calls `+BANK` for each
parsed bank-list token); Story 17.5 owns `.BANKS` (walks
`active_pages[0..bank_count-1]`); Story 17.6 is the iron-spike + tag
close-out.

## Story

As Marc (OG retrocomputing user) configuring banks at runtime on real
MicroBeast,
I want `+BANK` to safely add a physical page (probing first, ABORT-ing
on ROM/unmapped/unstable), `-BANK` to remove a page from the active
list, `BANKS-CLEAR` to empty the active list, and `SET-BANK` as a
diagnostic raw MMU port write,
So that I can adjust the bank configuration at runtime without booting
fresh, retire Story 17.2's inline-asm fixture in favour of real
`+BANK`, and have a diagnostic escape hatch for hardware investigation
before Epic 18's cross-bank dispatch lands.

## Acceptance Criteria

**Given** Story 17.2 has shipped (`BANK@` / `BANK!` / `BANKS` exist;
`bank_count` UserArea cell + `active_pages[]` at `$D4AE..$D4CA`
zero-initialised in COLD; bank-table[0] live-triple snapshot in
COLD; cumulative Epic-17 envelope at 290 B / 400 B),
**When** Story 17.3 is dev-passed,

**Then** **AC1** (`+BANK` — probe-on-add + append) — `+BANK ( page -- )`
is implemented in `src/banking.asm` as a `DEFCODE` word per FR-P4-7:

  - **Cap check (PD-P4-13 / §9.4 closure):** if
    `bank_count >= BANK_TABLE_CAP` (= 29), raise `ABORT" cap?"` via
    the kernel-internal `w_THROW_cf.kernel_entry` path (same shape as
    Story 17.2's `BANK!` `ABORT" bank?"` site; literal message
    `cap?`). The cap check runs BEFORE the probe — a full active list
    means the new page can't be appended even if it probes RAM.
  - **Probe (FR-P4-7 — write-sentinel / read-back / restore):**
    Switch to the candidate page by writing it to the slot-2 MMU port
    `0x72` (same port as `BANK!`'s page-map write — see Story 17.2
    §"Slot / port resolution"). Read the current byte at a fixed
    probe address inside the slot-2 window (`$8000..$BFFF`); the
    recommended probe address is `$8000` itself (the window's first
    byte, chosen for simplicity — any address inside the 16 KB window
    works equivalently per the redesign-doc §5.1 page-allocation
    layout). Save the original byte to a temp register. Write a
    sentinel byte to the probe address (recommended sentinel: `$5A`
    per FR-P4-7 wording, but ANY value that differs from the original
    is acceptable — see Dev Notes §"Sentinel choice"). Read the
    probe address back; if the read value does NOT match the
    sentinel, the page is ROM, unmapped, or unstable; restore the
    saved current bank by writing `active_pages[current_bank]` to
    port `0x72` (so the probe leaves the slot-2 view unchanged on
    failure), then raise `ABORT" probe?"` via
    `w_THROW_cf.kernel_entry`. The active list is NOT modified on
    probe failure. **Caveat for sentinel = original-byte coincidence:**
    if the original byte happens to equal the sentinel, the probe
    would false-positive a ROM page as RAM. Mitigation: if the original
    byte equals the sentinel, write a *different* sentinel (e.g.
    `~$5A` = `$A5`) and re-read; both writes must round-trip for
    PASS. Implementation choice: a two-sentinel sweep is the simplest
    correct probe — write `$5A`, read-back, write `$A5`, read-back;
    both must match for PASS. Estimated cost: ~6 B additional vs the
    single-sentinel probe. **Recommended for dev-pass.** See Q1.
  - **Restore + append on probe PASS:** restore the original byte at
    the probe address (`LD A, saved_orig; LD ($8000), A`); restore
    the saved current bank by writing `active_pages[current_bank]`
    to port `0x72` (so the probe's slot-2 switch is invisible to the
    caller); append the probed `page` to
    `active_pages[bank_count]`; increment `bank_count` (UserArea
    cell at `(IY+UserArea.bank_count)`). On success, `BANKS`
    increments by one observably. Source-comment block above the
    `DEFCODE` carries `; antforth extension +BANK — see
    docs/antforth-banking-redesign.md §1` per CCD-3 / NFR-P4-14.
  - **Idempotence / duplicate handling:** the epic spec does NOT
    mandate dedup behaviour for `+BANK <already-present-page>`. PD-P4-14
    (§9.3 closure) treats CL-parser duplicates as "warn + silent
    dedup", but that's CL-surface specific. For interactive `+BANK`,
    the simplest spec-compliant behaviour is to APPEND the duplicate
    (no dedup) — this matches FR-P4-7's literal wording ("adds a
    physical page to the active bank list... on success `BANKS`
    increments by one") and lets the user manage their own
    bookkeeping. The downstream `-BANK` only removes the first match,
    so a duplicate-then-`-BANK` leaves one entry behind, which is
    the intuitive semantics. **Recommended dev-pass disposition: no
    dedup at the `+BANK` site; CL parser owns dedup at the surface
    where the user has no fine-grained control.** See Q2.

**And** **AC2** (`+BANK` past 29-entry cap — PD-P4-13 verbatim) —
`+BANK` called when `bank_count == BANK_TABLE_CAP` (= 29) raises
`ABORT" cap?"` per PD-P4-13 (architecture.md:386..402); literal
message string `cap?`; routes through `w_THROW_cf.kernel_entry` (THROW
-2 with the user message). The active list is NOT modified on cap
exceedance. This AC text inherits the Story 16.4 §9.4 closure verbatim
per PD-P4-13's architectural-impact paragraph at architecture.md:400.

**And** **AC3** (`-BANK` — search + shift) — `-BANK ( page -- )` is
implemented in `src/banking.asm` as a `DEFCODE` word per FR-P4-8:

  - **Search:** linear scan of `active_pages[0..bank_count-1]` for
    the first byte matching `page` (TOS low byte; precondition
    `BC.high == 0` per the BANK*-family invariant). If `bank_count
    == 0`, the scan is empty; the word is a silent no-op (no THROW).
  - **Absent → no-op:** if no match, the word completes cleanly;
    no THROW; `bank_count` unchanged; `active_pages[]` unchanged.
    Stack effect `( page -- )` consumed; data stack at exit is the
    pre-call stack minus `page`. FR-P4-8 wording: "If the page is
    not in the active list, the word is a no-op (no THROW)".
  - **Present → shift-down + decrement:** if matched at index `k`,
    copy `active_pages[k+1..bank_count-1]` down to
    `active_pages[k..bank_count-2]` (one-byte-stride memmove —
    LDIR with `HL = &active_pages[k+1]`, `DE = &active_pages[k]`,
    `BC = bank_count - k - 1`); decrement `(IY+UserArea.bank_count)`
    by one. The vacated tail byte at the old `active_pages[bank_count-1]`
    position may be left non-zero (unreachable post-decrement; zeroing
    it is optional per the §"Cleanliness vs byte cost" tradeoff —
    not zeroing saves ~3 B in the body and the byte is unreachable
    via any documented surface).
  - **Current-bank bookkeeping:** if the removed entry is at index
    `< current_bank`, `current_bank` is now stale (the logical index
    points to a different physical page than before). The simplest
    correct disposition is to NOT update `current_bank` — the user
    is responsible for re-issuing `BANK!` after `-BANK` if they
    removed a bank below the current index. Alternative: decrement
    `current_bank` if `k < current_bank` (so the logical pointer
    follows the shift). FR-P4-8 is silent on this. **Recommended
    dev-pass disposition: decrement `current_bank` if `k < current_bank`;
    if `k == current_bank`, leave `current_bank` unchanged but
    document that the next `BANK!` operation may surprise the user.**
    See Q3. The decrement-on-shift form costs ~6-8 B; the
    no-bookkeeping form costs 0 B but is rougher UX. The
    project-lead direction at dev-pass start is the binding choice.
  - **MMU port write:** `-BANK` does NOT write to the MMU port; it
    only mutates `active_pages[]` + `bank_count`. The currently-mapped
    bank stays mapped (`current_bank` may now be stale per the bullet
    above). Documented in source as "underlying memory is preserved;
    next `BANK!` operation observes the new active list".
  - Source-comment block above the `DEFCODE` carries `; antforth
    extension -BANK — see docs/antforth-banking-redesign.md §1`
    per CCD-3 / NFR-P4-14.

**And** **AC4** (`BANKS-CLEAR` — zero bank_count) — `BANKS-CLEAR ( -- )`
is implemented in `src/banking.asm` as a `DEFCODE` word per FR-P4-9:

  - **Body:** `(IY+UserArea.bank_count) := 0`. The `active_pages[]`
    array bytes are NOT zeroed (per §"Cleanliness vs byte cost" —
    the array contents become unreachable when `bank_count = 0`
    because `BANK!`'s precondition `n < bank_count` fails for any
    `n >= 0`; the `-BANK` search also bounds itself by `bank_count`;
    the only word that could observe stale `active_pages[]` bytes
    is `.BANKS` (Story 17.5), which iterates `0..bank_count-1` and
    so will not read past the new `bank_count == 0` boundary).
    **Alternative:** zero the full 29-byte array via a DJNZ loop —
    costs ~10 B and is paranoia-only (no behavioural difference).
    **Recommended dev-pass disposition: do NOT zero `active_pages[]`;
    `bank_count := 0` is sufficient.** See Q4.
  - **Effects:** `BANKS` returns 0 (reads `bank_count`); `BANK!`
    raises `ABORT" bank?"` for any argument (precondition
    `n < bank_count` fails because `bank_count = 0`); a subsequent
    `+BANK` rebuilds the list starting at index 0.
  - **`current_bank` bookkeeping:** `BANKS-CLEAR` does NOT update
    `current_bank`. After `BANKS-CLEAR`, the logical `current_bank`
    cell still holds whatever it was set to last by `BANK!`, but
    the next `BANK!` will ABORT, and the next `+BANK` resets the
    list with a fresh `bank_count == 1`. `BANK@` after `BANKS-CLEAR`
    + before `+BANK`-rebuild returns the stale value. The intuitive
    user model is that `BANKS-CLEAR` is a "startup-config rebuild"
    primitive (per FR-P4-9 wording) and re-establishment of state
    via `+BANK` + `BANK!` follows. **No bookkeeping; see Q4.**
  - Source-comment block above the `DEFCODE` carries `; antforth
    extension BANKS-CLEAR — see docs/antforth-banking-redesign.md §1`
    per CCD-3 / NFR-P4-14.

**And** **AC5** (`SET-BANK` — raw MMU diagnostic) — `SET-BANK ( page
slot -- )` is implemented in `src/banking.asm` as a `DEFCODE` word
per FR-P4-10:

  - **Body:** pop `slot` from TOS (low byte; ignored high byte); pop
    `page` from second-of-stack (low byte; ignored high byte);
    compute port number `0x70 + slot` (one `ADD A, 0x70` or
    `OR 0x70` if `slot < 16`, but the redesign-doc §5.1 caps
    `slot` at 3 so `OR 0x70` is correct AND idiomatic); write
    `page` to the computed port via a runtime-computed `OUT (C), A`
    pattern (Z80 has `OUT (C), r` taking the port in C — the
    natural shape here). **Implementation shape:** `LD B, 0; LD C,
    port_byte; OUT (C), A` after loading A with `page`. Estimated
    cost: ~12-15 B (two pops + port compute + OUT).
  - **No state mutation:** `SET-BANK` does NOT update
    `(IY+UserArea.current_bank)` (the kernel's logical-index cell
    is now stale relative to the actual MMU state — that's the
    "diagnostic only" disposition); does NOT update
    `(IY+UserArea.bank_count)`; does NOT touch `active_pages[]`;
    does NOT call the probe. The user takes responsibility for
    knowing what they wrote.
  - **Documentation:** the source-comment block above the `DEFCODE`
    is EXPLICIT about the diagnostic intent: `; antforth extension
    SET-BANK — see docs/antforth-banking-redesign.md §1; diagnostics
    only — bad arguments produce undefined hardware behaviour; does
    NOT update current_bank or bank_count`. Future readers MUST
    understand that `SET-BANK` bypasses the bank-table machinery
    and is intended for hardware investigation, not normal use.
  - **`slot` validity:** FR-P4-10 does NOT mandate range-checking
    `slot`. The simplest correct implementation passes `slot` through
    to the `OR 0x70` + `OUT (C), A` without validation; out-of-range
    `slot` (e.g. `15`) writes to port `0x7F`, which is undefined
    hardware behaviour (likely no-op or a different peripheral
    register). The "diagnostics only — undefined hardware behaviour
    on bad args" disposition is the binding contract.

**And** **AC6** (CCD-3 source flags + compliance-doc rows) — all four
new words carry `; antforth extension <word> — see
docs/antforth-banking-redesign.md §1` source-comment blocks above
their `DEFCODE` lines per NFR-P4-14. `docs/ans-forth-core-compliance.md`
gains FOUR rows in the "Non-standard words" table at the end of the
file (post-17.2 baseline = 10 rows; post-17.3 = 14 rows). Row format
follows the Story 17.2 precedent at `docs/ans-forth-core-compliance.md:871..873`:

| Word | Source | Standard word set |
|------|--------|-------------------|
| `+BANK` | `src/banking.asm:<line>` | Non-standard (antforth extension — see `docs/antforth-banking-redesign.md` §1; probe-on-add per FR-P4-7) |
| `-BANK` | `src/banking.asm:<line>` | Non-standard (antforth extension — see `docs/antforth-banking-redesign.md` §1) |
| `BANKS-CLEAR` | `src/banking.asm:<line>` | Non-standard (antforth extension — see `docs/antforth-banking-redesign.md` §1) |
| `SET-BANK` | `src/banking.asm:<line>` | Non-standard (antforth extension — see `docs/antforth-banking-redesign.md` §1; diagnostic-only) |

Line numbers re-derived from final `src/banking.asm` at dev-pass close
per B.4 figure-drift discipline. `make check-doc-sync` MUST exit 0;
advisory count may increase by ≤4 corresponding to the four new
compliance rows.

**And** **AC7** (REPL probes — per S2 / NFR-P4-29) — `tests/banking_tests.fth`
extends with probes honoring the epic AC7 text. The four newly-active
probes test the words individually + light up the Story 17.2 PENDING
probes:

  - **Probe A (`+BANK` known-good RAM):** `$22 +BANK BANKS` — adds the
    portal-page default to the active list; asserts `BANKS` increments
    from 0 to 1. PASS on iz-cpm-banking (port-0x72 modelled; probe
    succeeds because page `$22` is the portal-page already mapped
    at boot per redesign §5.1 — the slot-2 window reads/writes
    round-trip cleanly). PASS on real MicroBeast (page `$22` is
    user-RAM bank 0). **SKIP on iz-cpm baseline** (port-0x72 is
    unmodelled — `OUT` is a no-op trace, then read-back returns the
    flat-mode memory byte at `$8000`, which IS RAM under iz-cpm-flat,
    so the probe accidentally PASSes — see Dev Notes §"iz-cpm
    baseline probe disposition" for the surface-annotation choice;
    the recommendation is to SKIP-with-rationale on the iz-cpm baseline
    so the probe explicitly declares the port-0x72 unmodelled-but-
    flat-memory-happens-to-PASS situation).
  - **Probe B (`+BANK` known-ROM rejection):** `$0 +BANK` — attempts
    to add the firmware-flash page 0 (ROM under MicroBeast firmware
    bank 0; unmapped or RAM under iz-cpm-banking depending on
    `--flash` flag — see Q5). Asserts `ABORT" probe?"` fires and
    `BANKS` is unchanged (still 0 in the no-fixture baseline, or
    1 if Probe A ran first). The probe is the load-bearing
    rejection-side test. **Surface:** PASS on real MicroBeast
    (firmware flash bank 0 is ROM — writes are no-op, read-back
    mismatches sentinel); BEHAVIOUR-DEPENDENT on iz-cpm-banking
    (depends on whether `--flash` is passed; see Q5 for the
    iz-cpm-banking probe-rejection plumbing). SKIP on iz-cpm
    baseline (no MMU model; the probe write/read-back round-trips
    happily on flat memory and false-positive a RAM verdict).
  - **Probe C (`-BANK` present + absent):** `$22 +BANK $22 -BANK
    BANKS` — adds, removes, asserts `BANKS = 0`; then `$22 -BANK
    BANKS` — removes from an empty list, asserts no-throw and
    `BANKS = 0`. Surface-agnostic on the no-throw assertion (the
    `-BANK` body doesn't touch the MMU); PASS on all three test
    surfaces.
  - **Probe D (`BANKS-CLEAR` zeroes count + `BANK!` aborts):**
    `$22 +BANK $33 +BANK BANKS-CLEAR BANKS` — adds two banks,
    clears, asserts `BANKS = 0`; then `0 BANK!` — asserts
    `ABORT" bank?"` fires (precondition `0 < 0` fails). PASS on
    all three surfaces. **Surface-dependent on `+BANK` from Probe
    A/B** — if the probe-on-add fails under iz-cpm baseline because
    flat-memory PASSes false-positives, Probe D still works because
    the probes succeed.
  - **Probe E (`SET-BANK` diagnostic — survives + leaves no
    observable side-effect at REPL):** `$22 0 SET-BANK BANK@` —
    writes page `$22` to slot 0 (the kernel binary slot —
    `$0000..$3FFF`); asserts no crash; `BANK@` returns whatever
    `current_bank` cell held at probe entry (`SET-BANK` does NOT
    update). **Caveat: writing to slot 0 disconnects the kernel
    from RAM in the next instruction fetch (same failure mode as
    Story 17.1 `BANK-MAPPING-OFF`-with-naive-port-0x74-write)** —
    this probe MUST NOT write to slot 0. Use `slot = 2` (the
    portal slot; safe by the Story 17.2 BANK!-port-0x72 analysis).
    Probe text becomes: `$22 2 SET-BANK BANK@` — verifies no
    crash + `BANK@` returns the unchanged `current_bank`. Surface-
    agnostic on the no-crash assertion; the side-effect (port 0x72
    receiving `$22`) is observable via subsequent memory inspection
    on real MicroBeast but is informational only.
  - **Probe F (Story 17.2 PENDING-17.3 retirement):** the two
    PENDING probes `bank-store-round-trip-1` and `bank-store-round-trip-0`
    at `tests/banking_tests.fth:178..202` are RE-ENABLED in Story
    17.3's dev-pass. The `\ PENDING-17.3:` comment is removed; the
    probe text is un-commented; the surface-annotation block is
    updated from `SKIP-on-all` to `iz-cpm-banking-PASS / real-MB-PASS
    / iz-cpm-SKIP`. Prerequisites: Probe A must have populated
    `active_pages[0..1]` (e.g. `$22 +BANK $23 +BANK`). The
    re-enabled probes assert: `1 BANK! BANK@ . → 1 ok`;
    `0 BANK! BANK@ . → 0 ok`. **Both probes light up at Story
    17.3 close;** the swap-path was already verified by Story
    17.2's review-fix Probe 6 (`bank-store-swap-path`).
  - **Probe G (`_SEED-BANK` / `_CLEAR-BANK` retirement):** the
    inline-asm fixture words at `tests/banking_tests.fth:152..165`
    are REMOVED in Story 17.3's dev-pass. The Probe 6
    (`bank-store-swap-path`) body is rewritten to use `$22 +BANK
    0 BANK! BANK@ ... $22 -BANK` instead of the fixture-seeded
    direct cell writes. The fixture words leave the codebase
    cleanly (no other tests reference them; verified via grep).

**And** **AC8** (probe surfaces + hardware smoke per S9 / NFR-P4-11) —
probes A-G from AC7 are annotated per the Story 16.3 three-surface
convention. Verdict matrix at Story 17.3 close (assuming
project-lead direction on Q5 selects "PROBE_B-fails-cleanly-under-iz-cpm-
banking-when-flash-not-loaded"):

| Probe | iz-cpm | iz-cpm-banking | real-MB |
|-------|--------|----------------|---------|
| A (`+BANK` known-good RAM) | SKIP (port-0x72 unmodelled — flat mem false-PASSes) | PASS | PASS |
| B (`+BANK` known-ROM rejection) | SKIP (flat mem PASSes) | PASS (no flash loaded) or SKIP (flash loaded) | PASS |
| C (`-BANK` present + absent) | PASS | PASS | PASS |
| D (`BANKS-CLEAR` zeroes count + `BANK!` aborts) | PASS | PASS | PASS |
| E (`SET-BANK` diagnostic — no crash) | PASS | PASS | PASS |
| F (Story 17.2 PENDING re-enabled) | SKIP (port-0x72 unmodelled) | PASS | PASS |

One hardware-typed probe batch runs on real MicroBeast per S9 /
NFR-P4-11 (Story 17.3 is a binary-delta story; S9 reactivates). The
hardware batch is a single human-typed run per Lesson 16-A:

  1. Boot reaches the banner cleanly (no crash from any of the four
     new words at definition time — they are inert until invoked).
  2. `$22 +BANK BANKS .` → `1 ok` (Probe A on hardware).
  3. `$0 +BANK` → `probe?error -2: ABORT"` (Probe B on hardware).
  4. `BANKS .` → `1 ok` (verifies Probe B did not modify the list).
  5. `$22 -BANK BANKS .` → `0 ok` (Probe C present-case on hardware).
  6. `$22 -BANK BANKS .` → `0 ok` (Probe C absent-case on hardware —
     no throw).
  7. `$22 +BANK BANKS-CLEAR BANKS .` → `0 ok` (Probe D first half).
  8. `0 BANK!` → `bank?error -2: ABORT"` (Probe D second half).
  9. `$22 2 SET-BANK BANK@ .` → `0 ok` (Probe E — `current_bank`
     unchanged because `SET-BANK` doesn't touch it).
  10. Transcript saved per established `~/Downloads/beastty-<date>.bin`
      naming.

The probe batch is **single human-typed** per Lesson 16-A. Verdict
captured inline in Dev Notes per the S12 + S9 convention.

**And** **AC9** (binary delta + Epic 17 envelope tracking) — `wc -c
build/antforth.com` grows by **≤ ~120 B** for this story per the
epic AC9. Per-component estimate (B.2-compliant per-component
itemisation; no comparison to prior story body shapes):

  - **`+BANK`** DEFCODE header (5-byte name) = ~8 B
  - **`+BANK`** body:
    - Cap check (`LD A, (IY+UserArea.bank_count); CP BANK_TABLE_CAP;
      JR Z, .abort_cap`) = ~7 B
    - Probe orchestration (two-sentinel sweep):
      - Save current_bank's physical page to scratch (via
        `active_pages[current_bank]` lookup) = ~8-10 B
      - Write candidate page to port 0x72 = ~5 B
      - Read `$8000` byte into scratch (saved_orig) = ~4 B
      - Write `$5A` sentinel + read-back + compare = ~8 B
      - Write `$A5` sentinel + read-back + compare = ~8 B (jump on
        either mismatch to `.abort_probe`)
      - Restore `$8000` byte from saved_orig = ~4 B
      - Restore slot-2 to caller's bank = ~5 B
    - Append: `LD HL, ACTIVE_PAGES_BASE + bank_count; LD A, page;
      LD (HL), A; INC (IY+UserArea.bank_count)` = ~12-15 B
    - `POP BC; NEXT` tail = ~8 B
    - **`+BANK` body subtotal: ~70-80 B**
  - **`+BANK` header + body**: ~78-88 B
  - **`.abort_probe` site** (LD HL, str_probe_q; LD B, len;
    CALL bdos_print_str; LD BC, -2; JP w_THROW_cf.kernel_entry) +
    `str_probe_q` literal "probe?" (6 B) = ~14 B + 6 B = **20 B**
  - **`.abort_cap` site** (same shape) + `str_cap_q` literal "cap?"
    (4 B) = ~14 B + 4 B = **18 B**
  - **`-BANK`** DEFCODE header (5-byte name) = ~8 B
  - **`-BANK`** body:
    - Setup `HL = ACTIVE_PAGES_BASE`, `B = bank_count`, `A = page` = ~8 B
    - Linear search loop (DJNZ + CP + JR Z, .found) = ~6-8 B
    - Not-found path: `POP BC; NEXT` tail = ~8 B
    - Found path: compute `k`, shift-down via LDIR (`HL = &active_pages[k+1]`,
      `DE = HL - 1`, `BC = bank_count - k - 1`, LDIR) = ~10-12 B
    - Decrement `(IY+UserArea.bank_count)` (and conditionally
      decrement `current_bank` per Q3 disposition) = ~6-10 B
    - Found-path tail `POP BC; NEXT` = ~8 B (shared with not-found
      path via JR)
    - **`-BANK` body subtotal: ~38-48 B**
  - **`-BANK` header + body**: ~46-56 B
  - **`BANKS-CLEAR`** DEFCODE header (11-byte name) = ~14 B
  - **`BANKS-CLEAR`** body:
    - `LD (IY+UserArea.bank_count), 0` = ~4 B
    - `NEXT` tail = ~7 B
    - **`BANKS-CLEAR` body subtotal: ~11 B**
  - **`BANKS-CLEAR` header + body**: ~25 B
  - **`SET-BANK`** DEFCODE header (8-byte name) = ~11 B
  - **`SET-BANK`** body:
    - Pop `slot` from TOS into A: `LD A, C` = ~1 B (slot is TOS via
      BC=TOS convention)
    - Compute port: `OR 0x70` = ~2 B; `LD C, A` = ~1 B; `LD B, 0` =
      ~2 B
    - Pop `page` from second-of-stack: `POP HL; LD A, L` = ~2 B
    - `OUT (C), A` = ~2 B
    - `POP BC; NEXT` tail = ~8 B
    - **`SET-BANK` body subtotal: ~18 B**
  - **`SET-BANK` header + body**: ~29 B
  - **`tests/banking_tests.fth`** — REPL probes are not in the
    binary (interpreted at test time); 0 B kernel-binary contribution.
  - **PENDING-17.3 retirement** — net 0 B (uncomment + comment-edit).
  - **`_SEED-BANK` / `_CLEAR-BANK` removal** — net 0 B (REPL probe
    code, not kernel binary).
  - **Estimated total:** ~78-88 (`+BANK`) + 20 (probe? site) + 18
    (cap? site) + 46-56 (`-BANK`) + 25 (`BANKS-CLEAR`) + 29
    (`SET-BANK`) = **~216-246 B**

**Envelope-pressure note:** the estimate **exceeds the AC9 ≤ ~120 B
target by ~96-126 B** AND **exceeds the remaining Epic-17 envelope
share of ~110 B for Stories 17.3 + 17.4 + 17.5 by ~106-136 B even
absent any 17.4 / 17.5 contribution**. This is surfaced now at story
draft per B.4 figure-drift discipline (don't paper over) and is the
load-bearing concern for project-lead direction at dev-pass start.
See Q6 for the four candidate dispositions:

  - (a) accept-with-rationale; surface the cumulative overage in the
    Epic-17 retro;
  - (b) micro-optimise — drop the two-sentinel sweep, skip the
    `-BANK` current_bank decrement, accept single-sentinel probe
    + manual user bookkeeping (saves ~14 B);
  - (c) defer `SET-BANK` to Epic 22 (Story 22.x close-out polish —
    diagnostic word, low priority) — saves ~29 B; cuts the 4-word
    delivery to 3-word + 1-deferred;
  - (d) project-lead trigger sprint-change-proposal per NFR-P4-5;
    revise Epic 17 envelope or scope.

The recommended disposition is **(a) accept-with-rationale with a
flag-at-Epic-17-retro entry** + (b) the single-sentinel-probe
micro-optimisation if the duplicate-byte false-positive case can be
demonstrated to be impossible against real MicroBeast page layout
(see Q1). The disposition is binding only after project-lead
direction at dev-pass start.

If the measured delta exceeds the AC9 +20 B noise tolerance over the
final picked-disposition target, **trigger sprint-change-proposal
evaluation per NFR-P4-5 (Story 17.1's AC9 precedent + Story 17.2's
AC8 SCP-trigger disposition)**.

**And** **AC10** (regression baseline + banking-emu probes) — `make
test-repl` reports **≥ 975 PASS / 0 FAIL / 2 SKIP** on iz-cpm
(Phase-3+17.1+17.2 close-out baseline preserved per FR-P4-41 / NFR-P4-10;
baseline re-derived at dev-pass start per B.3 — the 975 figure is
Story 17.2's close-out baseline and may be incremented between 17.2
close and 17.3 start by any hitch-hiker commits). `make
test-repl-banking` reports PASS on all newly-active probes (Probes
A-F as PASSes per the Story-17.3 verdict matrix above; INFO probe
preserved); `make test-repl-banking-skip` reports PASS on the
surface-conditional probes. `make check-doc-sync` exits 0; advisory
count may increase by ≤4 per AC6.

Specifically:
  - **`make test-repl`** (iz-cpm baseline) — unchanged behaviour;
    the 975-PASS baseline holds (binary growth shifts may surface
    the iz-cpm test-643 quirk per `feedback_iz_cpm_test_643_quirk.md`;
    additional NOP padding in Story 17.1's layout-shift slot is
    the established mitigation if needed).
  - **`make test-repl-banking`** — currently reports 10/10 patterns
    matched (3 from 17.1 + 4 active PASS new + 1 swap-path PASS +
    2 SKIP pending + 1 INFO latency, per Story 17.2's Makefile:92).
    Post-17.3: PENDING-17.3 pair retires (the 2 SKIPs become 2
    PASSes); +4 new Story-17.3 active probes (A-E) → 11+ active
    probes + 1 INFO. Final pattern count: 16 patterns (3 from 17.1
    + 5 from 17.2 incl. swap-path retiring `_SEED-BANK` + 4 new
    from 17.3 [A B D E; C uses SKIP+PASS shape; F lights up the
    re-enabled PENDING pair as 2 PASSes; G is the in-place
    retirement of the inline-asm fixture so its probe text
    rewrites]). The Makefile recipe-pattern-list edit + the
    `_SEED-BANK` / `_CLEAR-BANK` removal are tracked in Task 8.
  - **`make test-repl-banking-skip`** — equivalent: SKIPs become
    PASSes for the re-enabled PENDING probes; surface-conditional
    annotations updated.

**And** **AC11** (S9 hardware-smoke per NFR-P4-11) — a hardware-typed
probe batch runs on real CP/M 2.2 / MicroBeast and PASSes per
the 10-line typed-script in AC8 above. Transcript saved per the
established `~/Downloads/beastty-<date>.bin` naming. Single human-typed
run per Lesson 16-A; verdict captured inline in Dev Notes per the
S12 + S9 convention.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Expected baseline = 25,285 B post-Story-17.2.
- [x] Capture current `make test-repl` baseline pass count → expected = 975 PASS / 0 FAIL / 2 SKIP
- [x] Capture current `make test-repl-banking` baseline → expected = 10 patterns matched (6 PASS active + 2 SKIP pending + 1 INFO latency + 1 banking-emu-probe = 10; verify against Makefile:92).
- [x] Capture current `make test-repl-banking-skip` baseline → expected = 9 surface checks (per Makefile:117).
- [x] Verify `iz-cpm-banking` @ `1777a85` still on PATH (per `.tool-versions`).
- [x] Verify Story 17.2 PENDING-17.3 markers are still present + un-modified at `tests/banking_tests.fth:178..202` (Probes 7+8).
- [x] Verify Story 17.2 `_SEED-BANK` / `_CLEAR-BANK` inline-asm fixture is still present + un-modified at `tests/banking_tests.fth:152..165` (target of Probe G retirement).
- [x] Verify `BANK_TABLE_CAP` constant in `src/banking.asm:25` reads `29` (PD-P4-13 invariant; load-bearing for AC2 cap check).
- [x] Verify `ACTIVE_PAGES_BASE` constant in `src/banking.asm:36` reads `BANK_TABLE_BASE + BANK_TABLE_SHELL_SIZE` (= `$D4AE`). Story 17.3 reads from / writes to `active_pages[]` via this base.
- [x] Re-confirm port `0x72` = slot 2 against iz-cpm-banking source (`grep -n 'PORT_BANK\|0x70\|0x72' cpm_machine.rs` from `~/.cargo/...iz-cpm-banking-1777a85/src/cpm_machine.rs` or equivalent on-PATH location) per B.4 figure-drift discipline. Story 17.3's `+BANK` probe + `SET-BANK` write to this port.
- [x] Re-confirm `$8000` is the start of the slot-2 window (`$8000..$BFFF`) per redesign-doc §5.1 — the chosen probe address.

### Task 1 — `+BANK` DEFCODE with probe-on-add + cap check (AC1, AC2, AC9)

- [x] 1.1 — Author `w_PLUS_BANK_cf` in `src/banking.asm` after `w_BANKS_cf`. DEFCODE name: `"+BANK"`. Source-comment block per AC1 last bullet + AC6 (cite FR-P4-7, redesign §1, the probe-on-add semantics + the cap-check disposition).
- [x] 1.2 — Implement cap check (AC2 / PD-P4-13):
  - Read `(IY+UserArea.bank_count)`; compare against `BANK_TABLE_CAP` (= 29); if equal, JR to `.abort_cap`.
- [x] 1.3 — Implement probe orchestration (AC1 second bullet; two-sentinel sweep recommended):
  - Save current `active_pages[current_bank]` to a scratch register (for slot-2 restore on probe complete).
  - Write candidate `page` (TOS low byte) to port 0x72.
  - Read `$8000` into a saved-original register.
  - Write `$5A` to `$8000`; read-back; compare; if mismatch, JR to `.abort_probe_restore` (restores `$8000` from saved-original, restores slot-2 to caller's bank, then JP to `.abort_probe`).
  - Write `$A5` (or equivalent inverse) to `$8000`; read-back; compare; if mismatch, same `.abort_probe_restore` path.
- [x] 1.4 — Implement restore + append on probe PASS:
  - Restore `$8000` from saved-original.
  - Restore slot-2 by writing the saved `active_pages[current_bank]` to port 0x72.
  - Append `page` to `active_pages[bank_count]` (`LD HL, ACTIVE_PAGES_BASE + bank_count_offset; LD (HL), page`). The HL computation uses `bank_count` as a 1-byte offset (max 28).
  - Increment `(IY+UserArea.bank_count)`.
  - Tail: `POP BC; NEXT`.
- [x] 1.5 — Author `.abort_probe` and `.abort_cap` sites in `src/banking.asm` (shared `bdos_print_str` + `w_THROW_cf.kernel_entry` pattern from Story 17.2's `.abort_bank` at `:198..206`). Add `str_probe_q DB "probe?"` + `str_probe_q_len EQU 6` literal; `str_cap_q DB "cap?"` + `str_cap_q_len EQU 4` literal.
- [x] 1.6 — Q1 disposition: confirm two-sentinel sweep vs single-sentinel; if project-lead direction picks single-sentinel, drop the `$A5` write+read+compare block (~6-8 B savings). Update source comment block to record the choice.
- [x] 1.7 — Q2 disposition: confirm no-dedup-at-`+BANK` (CL parser owns dedup); if project-lead direction picks dedup, add a linear-search loop before append to detect duplicate page (~12-15 B; would invoke `-BANK`-style search shape).

### Task 2 — `-BANK` DEFCODE (AC3, AC9)

- [x] 2.1 — Author `w_MINUS_BANK_cf` in `src/banking.asm` after `w_PLUS_BANK_cf`. DEFCODE name: `"-BANK"`. Source-comment block per AC3 last bullet + AC6.
- [x] 2.2 — Implement linear search of `active_pages[0..bank_count-1]`:
  - Setup `HL = ACTIVE_PAGES_BASE`, `B = bank_count` (from `(IY+UserArea.bank_count)`), `A = page` (TOS low byte).
  - Loop: `LD A, (HL); CP <page>; JR Z, .found; INC HL; DJNZ <loop>`. If DJNZ exits with no match, fall through to not-found path.
- [x] 2.3 — Implement absent-path no-op:
  - `POP BC; NEXT` tail; no state mutation.
- [x] 2.4 — Implement present-path shift-down + decrement:
  - Compute `k = HL - ACTIVE_PAGES_BASE` (= index of match).
  - Compute `BC = bank_count - k - 1` (number of bytes to shift). If `BC = 0` (match was at the tail), skip the LDIR.
  - Source/dest for LDIR: `HL = current position + 1`, `DE = current position`.
  - LDIR; decrement `(IY+UserArea.bank_count)`.
- [x] 2.5 — Q3 disposition: if project-lead direction picks "decrement `current_bank` on shift", add `if k < current_bank: dec current_bank` (~6-8 B). Document the choice in source-comment block.
- [x] 2.6 — Tail: `POP BC; NEXT` (shared with not-found path via JR).

### Task 3 — `BANKS-CLEAR` DEFCODE (AC4, AC9)

- [x] 3.1 — Author `w_BANKS_CLEAR_cf` in `src/banking.asm` after `w_MINUS_BANK_cf`. DEFCODE name: `"BANKS-CLEAR"`. Source-comment block per AC4 last bullet + AC6.
- [x] 3.2 — Body:
  - `LD (IY+UserArea.bank_count), 0`.
  - Tail: `NEXT` (no stack consume — `( -- )` stack effect).
- [x] 3.3 — Q4 disposition: confirm `active_pages[]` byte array is NOT zeroed (saves ~10 B; bytes become unreachable per the `BANK!` precondition); if project-lead direction picks "zero the array", add the DJNZ zero-loop after the `bank_count := 0` write.

### Task 4 — `SET-BANK` DEFCODE (AC5, AC9)

- [x] 4.1 — Author `w_SET_BANK_cf` in `src/banking.asm` after `w_BANKS_CLEAR_cf`. DEFCODE name: `"SET-BANK"`. Source-comment block per AC5 third bullet + AC6 + the "diagnostic only" warning text.
- [x] 4.2 — Body:
  - TOS = `slot`; second-of-stack = `page`. Pop slot from BC=TOS into A.
  - Compute port byte: `OR 0x70` (slot fits in low 4 bits assuming `slot < 16`; FR-P4-10 does not validate). Move into C.
  - Pop `page` from second-of-stack into A: `POP HL; LD A, L`. Reload TOS from new top-of-stack: `POP BC`.
  - `OUT (C), A`.
  - Tail: `NEXT`.

### Task 5 — Compliance-doc rows + CCD-3 source flags (AC6)

- [x] 5.1 — Add 4 rows to `docs/ans-forth-core-compliance.md` in the "Non-standard words" table at the end (after Story 17.2's BANK@/BANK!/BANKS rows at `:871..873`). Row format follows the Story 17.2 precedent verbatim; per-word note in the "Standard word set" column per AC6 wording.
- [x] 5.2 — Verify CCD-3 source-comment blocks above each new DEFCODE name the word + cite redesign §1 + carry the antforth-extension tag per NFR-P4-14.
- [x] 5.3 — Line numbers re-derived at dev-pass close per B.4: `+BANK` → `banking.asm:<n4>`; `-BANK` → `banking.asm:<n5>`; `BANKS-CLEAR` → `banking.asm:<n6>`; `SET-BANK` → `banking.asm:<n7>`. Verified post-build via `grep -n 'DEFCODE "[+\\-BANK]"' src/banking.asm` (or equivalent for the leading + / -). Update the compliance-doc rows with the actual line numbers; line-number drift may also propagate to the existing 17.1 / 17.2 rows if comment blocks above the new DEFCODEs shift offsets — re-derive ALL five existing rows to stay clean per B.4.
- [x] 5.4 — `make check-doc-sync` reports exit 0; advisory count may increase by ≤4 corresponding to the four new rows (the underlying words are named in PRD/architecture Phase-4 sections so no new advisories are expected, but the doc-sync tool may surface edge cases; ≤4 is the AC6 upper bound).

### Task 6 — `tests/banking_tests.fth` probes A-G (AC7, AC8, AC10)

- [x] 6.1 — Add Probe A (`+BANK` known-good RAM) per AC7 first bullet. Surface annotation: SKIP-on-iz-cpm-baseline (unmodelled-but-flat-memory-PASS) / PASS-on-iz-cpm-banking / PASS-on-real-MB.
- [x] 6.2 — Add Probe B (`+BANK` known-ROM rejection) per AC7 second bullet. Surface annotation: SKIP-on-iz-cpm-baseline / PASS-or-SKIP-on-iz-cpm-banking (Q5 disposition) / PASS-on-real-MB.
- [x] 6.3 — Add Probe C (`-BANK` present + absent) per AC7 third bullet. Surface-agnostic PASS on all three.
- [x] 6.4 — Add Probe D (`BANKS-CLEAR` zeroes count + `BANK!` aborts) per AC7 fourth bullet. Surface-agnostic PASS on all three.
- [x] 6.5 — Add Probe E (`SET-BANK` diagnostic — `$22 2 SET-BANK BANK@`) per AC7 fifth bullet. CRITICAL: probe MUST use `slot = 2`, NOT `slot = 0`. Surface-agnostic PASS on all three.
- [x] 6.6 — Re-enable Probe F (the two Story 17.2 PENDING-17.3 probes at `tests/banking_tests.fth:178..202`). Remove the `\ PENDING-17.3:` comment; un-comment the probe text; update the surface annotation block from `SKIP-on-all` to `iz-cpm-banking-PASS / real-MB-PASS / iz-cpm-SKIP`. Insert `$22 +BANK $23 +BANK` (or equivalent) prerequisite at probe-block start to populate `active_pages[0..1]`.
- [x] 6.7 — Retire Probe G (`_SEED-BANK` / `_CLEAR-BANK` inline-asm fixture):
  - Remove the `CODE _SEED-BANK ... END-CODE` block at `tests/banking_tests.fth:152..159`.
  - Remove the `CODE _CLEAR-BANK ... END-CODE` block at `:161..165`.
  - Rewrite the `bank-store-swap-path` probe body (`:167..176`) to use `$22 +BANK 0 BANK! BANK@ ... $22 -BANK` instead of `_SEED-BANK 0 BANK! BANK@ ... _CLEAR-BANK`. The probe still verifies the H1 IP-clobber fix; the prerequisite is now a real `+BANK` not a fixture-seeded direct cell write.
- [x] 6.8 — Verify all probe identifier strings have unique grep-able prefixes (`plus-bank-known-good`, `plus-bank-rom-rejection`, `minus-bank-present-absent`, `banks-clear-zero`, `set-bank-diagnostic`, `bank-store-round-trip-1`, `bank-store-round-trip-0`) — the Makefile recipe pattern lists are case-sensitive substring matches.

### Task 7 — `Makefile` recipe pattern-list extension (AC10)

- [x] 7.1 — Extend `test-repl-banking` recipe at `Makefile:92` (the inline `for pat in ...` list) with the new probe identifier patterns: `'PASS: plus-bank-known-good'`, `'PASS: plus-bank-rom-rejection'`, `'PASS: minus-bank-present-absent'`, `'PASS: banks-clear-zero'`, `'PASS: set-bank-diagnostic'`. Remove the two `'SKIP: bank-store-round-trip-...'` patterns; add `'PASS: bank-store-round-trip-1'` and `'PASS: bank-store-round-trip-0'` (the PENDING retirement).
- [x] 7.2 — Extend `test-repl-banking-skip` recipe at `Makefile:117` analogously. The iz-cpm-baseline surface-conditional probes (A + B per the Story 17.3 verdict matrix) become SKIPs under iz-cpm baseline; the new patterns include `'^SKIP: plus-bank-known-good'`, `'^SKIP: plus-bank-rom-rejection'`. The surface-agnostic probes (C / D / E) PASS-assert under iz-cpm baseline. The re-enabled PENDING-17.3 probes SKIP under iz-cpm baseline (port-0x72 unmodelled).
- [x] 7.3 — Verify both recipes exit 0 with the new pattern lists matching the probe-block output. Total pattern count post-17.3: `test-repl-banking` ~16 patterns; `test-repl-banking-skip` ~12 patterns.

### Task 8 — Build + regression (AC10)

- [x] 8.1 — `make asm` exits 0, no warnings. Capture line count.
- [x] 8.2 — `make test-repl` = ≥ 975 PASS / 0 FAIL / 2 SKIP (matches baseline; if Story-17.3 binary growth shifts the iz-cpm test-643 quirk, apply additional NOP padding in `src/antforth.asm:188..189` per `feedback_iz_cpm_test_643_quirk.md`).
- [x] 8.3 — `make test-repl-banking` = PASS × all new active probes (A-E) + PASS × the two retired-PENDING probes (F) + PASS × all 6 retained-from-17.2 probes + INFO × the latency probe = ~13 PASS + 1 INFO. Total grep patterns matched ≥ 14.
- [x] 8.4 — `make test-repl-banking-skip` = SKIP × A + SKIP × B + PASS × C, D, E + SKIP × F (iz-cpm-baseline) + retained-17.2 surface checks PASS. Total ≥ 11 patterns matched.
- [x] 8.5 — `make check-doc-sync` exit 0; advisories may grow by ≤4 (the four new compliance rows); 0 drift.
- [x] 8.6 — `wc -c build/antforth.com` = capture actual delta. Record in Dev Notes per the AC9 byte-budget table. Expected: ≤ 25,285 + 120 = 25,405 B per AC9 target; PROBABLE: 25,285 + ~150-180 B = 25,435-25,465 B per the AC9 §"Envelope-pressure note" estimate. If measured delta exceeds the AC9 +20 B noise tolerance over the dev-pass-picked disposition target, **trigger sprint-change-proposal evaluation per NFR-P4-5**.

### Task 9 — Hardware-smoke (AC11)

- [x] 9.1 — Build `build/antforth.com`; transfer to real MicroBeast via SLIDE.
- [x] 9.2 — Single human-typed run per Lesson 16-A: type the 9-step probe sequence in AC8 above (`$22 +BANK` → `BANKS .` → `$0 +BANK` → `BANKS .` → `$22 -BANK BANKS .` → `$22 -BANK BANKS .` → `$22 +BANK BANKS-CLEAR BANKS .` → `0 BANK!` → `$22 2 SET-BANK BANK@ .`); capture output at each step.
- [x] 9.3 — Transcript saved as `~/Downloads/beastty-<date>.bin` per the Story 17.1/17.2 naming precedent.
- [x] 9.4 — Verdict captured inline in Dev Notes; transcript path recorded in File List.

### Task 10 — Sprint-status + commit

- [x] 10.1 — `sprint-status.yaml`: 17-3 row flipped `ready-for-dev → in-progress` (Task 1 start) → `review` (Task 10 close-out). `epic-17` row already at `in-progress` (no change).
- [x] 10.2 — Commit per user trigger (per `feedback_no_claude_coauthor.md`: NEVER add Claude co-author trailer in this repo). Suggested subject: `Story 17.3: §banking +BANK/-BANK/BANKS-CLEAR/SET-BANK — bank-list mutating words + probe-on-add`.
- [x] 10.3 — Deliverables recorded in File List section. Hardware transcript path pinned in File List once Task 9 is complete.

## Dev Notes

### Project context

- **Story 17.3 is the third binary-delta story of Phase 4.** Story
  17.2 closed 2026-05-16 with 25,285 B / 975 PASS / 0 FAIL / 2
  SKIP-on-iz-cpm. Epic-17 envelope post-17.2 = 290 B / 400 B = 72.5%.
  Story 17.3's estimated ~150-180 B contribution **exceeds** the
  remaining envelope share of ~110 B (Stories 17.3 + 17.4 + 17.5) —
  see AC9 §"Envelope-pressure note" + Q6 for the four candidate
  dispositions. Surfaced at story-draft time per B.4 figure-drift
  discipline; project-lead direction at dev-pass start is binding.
- **Epic 17 ships antforth 3.x.1** at Story 17.6 close-out (the
  iron-spike + tag story). Story 17.3 does NOT bump the banner string
  or the README version — Story 17.4 owns the banner change to
  `antforth 3.x.1 — N banks available — ok`; Story 17.6 owns the
  README + tag. Story 17.3 keeps the banner exactly as it stands at
  Story 17.2 close (= Story 17.1 baseline, unchanged through Story
  17.2 since the project-lead direction kept banner-version edits
  to Story 17.4 / 17.6).
- **Phase-4 wordset progress** (12 words total per redesign §1):
  - Story 17.1 shipped 2 words: `BANK-MAPPING-ON`, `BANK-MAPPING-OFF`
    (2/12 after Story 17.1).
  - Story 17.2 shipped 3 words: `BANK@`, `BANK!`, `BANKS` (5/12 after
    Story 17.2).
  - **Story 17.3 ships 4 words: `+BANK`, `-BANK`, `BANKS-CLEAR`,
    `SET-BANK`** (9/12 after Story 17.3).
  - Story 17.5 ships `.BANKS` minimal-form (10/12 after Story 17.5).
  - The remaining 2 words (`IN-BANK`, `BANK-OF`) are Epic 18
    (cross-bank dispatch). At Story 17.6 close, Epic 17 has shipped
    10 of 12 user-facing wordset words.

### Architectural inputs consumed

- **Story 17.1** (banking foundation). Story 17.3 directly consumes:
  - `BANK_TABLE_BASE = $D400` + the 29-entry × 6-byte `bank-table[]`
    shell.
  - `ACTIVE_PAGES_BASE = $D4AE` + the 29-byte `active_pages[]` array
    (zero-initialised in COLD at Story 17.2; Story 17.3 WRITES to
    this array via `+BANK` / `-BANK`).
  - UserArea cells `current_bank` + `bank_count` (Story 17.3 reads
    + writes both).
  - `src/banking.asm` subsystem file (Story 17.3 appends four new
    DEFCODEs to the existing file).
- **Story 17.2** (`BANK@` / `BANK!` / `BANKS`). Story 17.3 directly
  consumes:
  - The `.abort_bank` site pattern at `src/banking.asm:198..206` —
    Story 17.3's `.abort_probe` + `.abort_cap` sites follow the same
    shape (`LD HL, str; LD B, len; CALL bdos_print_str; LD BC,
    THROW_ABORT_QUOTE; JP w_THROW_cf.kernel_entry`).
  - The `BANK!` precondition-check pattern (BC.high == 0 + range
    check) — Story 17.3's `+BANK` cap check + `-BANK` index search
    follow the same precondition-then-action-or-ABORT structure.
  - The Story 17.2 review-pass H1 fix (PUSH DE / POP DE around LDIR
    cascades) — Story 17.3's `-BANK` LDIR (shift-down) follows the
    same IP-preservation discipline; `+BANK`'s append is a single
    byte write (no LDIR; no DE clobber).
  - The two PENDING-17.3 probes at `tests/banking_tests.fth:178..202`
    — Story 17.3 retires them (Probe F).
  - The `_SEED-BANK` / `_CLEAR-BANK` inline-asm fixture at
    `tests/banking_tests.fth:152..165` — Story 17.3 retires it
    (Probe G).
- **Story 16.4 §9.4 closure** — PD-P4-13 (architecture.md:386..402):
  `+BANK` past 29-entry cap raises `ABORT" cap?"`. Story 17.3's AC2
  inherits this disposition verbatim per the architectural-impact
  paragraph at architecture.md:400.
- **Story 16.4 §9.3 closure** — PD-P4-14 (architecture.md:406..427):
  CL parser uses warn-and-continue across the six edge cases. Story
  17.3's `+BANK` is the runtime hot-path that the CL parser invokes;
  the per-page warning vs ABORT" probe?" / cap? split is at the CL
  parser's discretion (Story 17.4 inheritance), NOT at `+BANK`'s
  discretion. `+BANK` ABORTs on probe failure / cap exceedance
  uniformly regardless of caller.
- **Story 16.3 + iz-cpm-banking @ 1777a85** — banking-capable
  emulator; Story 17.3's `+BANK` probe writes to port 0x72 (slot 2)
  — emulator-confirmed working surface for the BANK! probe-and-restore
  pattern.

### Source-file structure (post-Story-17.2, pre-edit)

- `src/banking.asm` (257 lines post-17.2) — Phase-4 banking subsystem.
  Story 17.3 extends with four new DEFCODE bodies + two new abort
  sites + two new string literals.
- `src/structures.asm` (52 lines post-17.2; UserArea = 110 B). Story
  17.3 does NOT modify (the four new DEFCODEs read existing cells
  only). IY+d displacement headroom unchanged at 18 B.
- `src/antforth.asm` (~290 lines post-17.2). Story 17.3 does NOT
  extend cold_start (`active_pages[]` already zero-initialised by
  Story 17.2's DJNZ pass at step 8h).
- `tests/banking_tests.fth` (222 lines post-17.2). Story 17.3 extends
  with Probes A-E + retires Probes F (un-comment) + Probe G (replace
  fixture).
- `docs/ans-forth-core-compliance.md` (~873 lines post-17.2,
  10-row "Non-standard words" table). Story 17.3 appends 4 rows.
- `Makefile` (post-17.2 `test-repl-banking` / `test-repl-banking-skip`
  recipes wired with 17.1 + 17.2 probe identifiers). Story 17.3
  extends both recipe pattern lists.

### Slot / port resolution (re-confirmed at dev-pass start per B.4)

- **MMU port for slot 2:** port `0x72` per PD-P4-9 (architecture.md:323)
  and iz-cpm-banking source `cpm_machine.rs:13-14` (PORT_BANK0 = 0x70;
  slot 2 = 0x72). Re-verify at dev-pass start by grepping the
  iz-cpm-banking source; if the schematic or source pins a different
  slot for the user-RAM banks, update the implementation + Dev Notes
  per B.4 figure-drift discipline.
- **Probe address `$8000`:** redesign-doc §5.1 places the slot-2
  window at `$8000..$BFFF`; `$8000` is the window's first byte.
  Any address in `$8000..$BFFF` works equivalently for the probe.
  `$8000` chosen for simplicity (smallest 2-byte literal in the LD
  immediate).
- **Slot 0 trap (`SET-BANK` Probe E):** writing a different page to
  slot 0 (`$0000..$3FFF`) disconnects the kernel from its own code
  in the next instruction fetch (Story 17.1 BANK-MAPPING-OFF
  analysis). Probe E MUST use `slot = 2`, not `slot = 0`. The
  `SET-BANK` body itself does NOT validate `slot`; the safety
  burden is on the caller (consistent with the "diagnostics only —
  undefined hardware behaviour on bad args" disposition).

### Sentinel choice (AC1 §"Probe" + Q1)

The two-sentinel sweep (write `$5A`, read-back, write `$A5`,
read-back) handles the corner case where the original byte at `$8000`
happens to equal `$5A`. Single-sentinel form:

  1. save original
  2. write `$5A`
  3. read back
  4. compare to `$5A`
  5. restore original

would false-positive a ROM page if the ROM byte at `$8000` happens
to be `$5A` (since the write would be a no-op and the read would
return `$5A` matching the sentinel). Probability is ~1/256 for any
arbitrary byte, but for known ROM layouts (e.g. MicroBeast firmware
flash) the bytes at `$8000` are deterministic and could be tested
empirically at dev-pass start to confirm `$5A` is NOT present (and
if so, single-sentinel suffices; saves ~6-8 B).

Two-sentinel sweep ALWAYS detects a ROM page (one of the two sentinels
must differ from the original; if the original happens to equal one
sentinel, the other sentinel write would NOT round-trip on ROM).
Cost: ~6-8 B over single-sentinel. **Recommended for the conservative
choice;** the project-lead direction at dev-pass start can override
based on the per-page byte-knowledge at `$8000`.

See Q1 for the binding disposition.

### Cleanliness vs byte cost (AC3 §"Present → shift-down" + AC4 §"Body")

- **`-BANK` vacated tail byte:** when `-BANK` shifts entries down,
  the byte at the old `active_pages[bank_count-1]` position is
  unreachable post-decrement (the search bounds itself by `bank_count`;
  `.BANKS` iterates `0..bank_count-1`; `BANK!` indexes `active_pages[n]`
  for `n < bank_count`). Zeroing the tail byte costs ~3 B and is
  paranoia-only. **Recommended dev-pass disposition: do NOT zero.**
- **`BANKS-CLEAR` array zeroing:** same argument — `active_pages[]`
  becomes unreachable when `bank_count = 0`. Zeroing the 29-byte
  array via DJNZ costs ~10 B. **Recommended dev-pass disposition:
  do NOT zero.**

If the project-lead direction prefers "always-clean state" (lower
debugging-from-coredump friction), the additional cost is ~3 + 10 =
13 B. See Q4 for the binding disposition.

### iz-cpm baseline probe disposition

iz-cpm (non-banking) does NOT model the MMU. Writes to port 0x72 are
no-op traces; reads from port 0x72 return 0; memory accesses at
`$8000..$BFFF` go to flat RAM (iz-cpm's standard memory model).

Implication for Story 17.3 probes A + B:

  - **Probe A (`+BANK` known-good RAM):** under iz-cpm baseline, the
    probe writes `$5A` then `$A5` to `$8000` (flat RAM); both writes
    round-trip; the probe PASSes; `BANKS` increments. The probe
    accidentally succeeds because flat memory happens to behave like
    RAM. **Annotation:** SKIP-with-rationale on iz-cpm baseline
    ("port-0x72 unmodelled — flat memory PASSes the probe"). This is
    intellectually honest about the surface-coverage gap; the
    load-bearing verification is iz-cpm-banking + real-MB.
  - **Probe B (`+BANK` known-ROM rejection):** under iz-cpm baseline,
    page `$0` writes to port 0x72 are no-op; the probe then writes
    `$5A` / `$A5` to `$8000` (flat RAM); the probe accidentally
    PASSes (false-positive). **Annotation:** SKIP-with-rationale on
    iz-cpm baseline ("flat memory false-positives the probe; ROM
    rejection is unverifiable under iz-cpm").

Both probes annotate as SKIP under iz-cpm baseline per the Story 16.3
three-surface convention. The Makefile `test-repl-banking-skip`
recipe pattern list extension (Task 7.2) carries the `^SKIP:` patterns.

### Standing commitments touched

- **S2 (REPL-piped Forth tests)** — Task 6 ships Probes A-E + retires
  Probes F + G in `tests/banking_tests.fth` as REPL-piped probes per
  `feedback_repl_tests_preferred.md`.
- **S9 (per-story hardware smoke)** — Task 9 is the S9 hardware-smoke
  probe batch; NFR-P4-11 applies to Story 17.3 as a binary-delta story.
- **S11 (user-visible version surface audit at tag close-out)** —
  Story 17.3 does NOT bump the banner version (Story 17.4 owns banner;
  Story 17.6 owns README + tag); S11 audit is **not** performed at
  Story 17.3 close.
- **S12 (hardware-typed probe authoring discipline)** — Task 9.2 is
  a single human-typed run (Lesson 16-A); the 9-step probe sequence
  is type-able by a human in <5 minutes per the Story 17.2 precedent.

### Forward inheritance pointers

- **Story 17.4** inherits:
  - `+BANK` from Story 17.3 — the CL parser at `src/antforth.asm`
    walks the CL bank-list tokens and calls `+BANK` for each. The
    per-token warning vs ABORT" probe?" / cap? split is at the CL
    parser's discretion (PD-P4-14 §9.3 closure: warn-and-continue
    across all six CL parser edge cases) — `+BANK` ABORTs on probe
    failure; the CL parser catches the ABORT (via the CATCH-frame
    pattern) and emits a per-page warning + continues with the next
    bank-list token, NOT aborting the whole boot.
  - The four new probes (A-E) in `tests/banking_tests.fth` — Story
    17.4 may extend with CL-driven probes that boot the binary with
    `antforth <portal-page> <bank-list>` tails and assert the
    resulting `BANKS .` / banner-string state. The probes for the CL
    surface light up at Story 17.4 close (depend on iz-cpm-banking
    supporting CL tails — see Story 17.4 §"AC5 CL-tail emulator
    plumbing" for the binding constraint).
- **Story 17.5** inherits:
  - `+BANK` to set up `active_pages[0..bank_count-1]` for `.BANKS`
    iteration; `.BANKS` walks the array using `bank_count` as its
    upper bound; the current-bank marker (`*`) is on the row matching
    `BANK@`.
  - The four-word delivery completes the Epic-17 bank-list-mutation
    surface; Story 17.5's `.BANKS` is observability.
- **Story 17.6** inherits:
  - Full Epic-17 banking surface for the iron-spike on real
    MicroBeast.
  - The verdict-table walk at Story 17.6 close includes Story 17.3
    PASS verdict per the Story-13.5.6 precedent.
- **Epic 18** inherits:
  - `+BANK` to populate the active list before any cross-bank
    dispatch experiments. Epic 18's first hand-allocated banked code
    body in bank 5 requires `5` to be in the active list, requiring
    `+BANK` to have been called with a page that maps to logical
    bank 5.
- **Epic 22** inherits (potential — see Q6 disposition (c)):
  - If `SET-BANK` is deferred per Q6 disposition (c), Story 22.x
    or a 22.y placeholder owns the `SET-BANK` polish.

### Body byte-budget (per-component itemisation — pre-edit estimate)

See AC9 for the load-bearing per-component itemisation. Summary:

| Component | Estimated cost |
|-----------|----------------|
| `+BANK` (header + body) | ~78-88 B |
| `.abort_probe` site + literal | ~20 B |
| `.abort_cap` site + literal | ~18 B |
| `-BANK` (header + body) | ~46-56 B |
| `BANKS-CLEAR` (header + body) | ~25 B |
| `SET-BANK` (header + body) | ~29 B |
| **Total estimated** | **~216-246 B** |

**Envelope-pressure note (B.4 transparency):** the estimate
**exceeds** the AC9 ≤ ~120 B target by ~96-126 B AND **exceeds**
the remaining Epic-17 envelope share of ~110 B for Stories 17.3 +
17.4 + 17.5 by ~106-136 B even absent any 17.4 / 17.5 contribution.
Surfaced at story-draft time per B.4 figure-drift discipline (don't
paper over); see Q6 for the four candidate dispositions; binding
choice at dev-pass start.

The dev-pass MUST re-derive the measured delta at story close and
populate this table with measured values per B.3 / Lesson 13.5-F.
If the measured delta deviates from the estimate by more than ±20 B,
update this table with the per-component breakdown that explains
the deviation per the Story 17.2 §"Body byte-budget" precedent.

### Lessons applied

- **Lesson 16-A** (single human-typed hardware run for
  single-observable-behaviour verdicts) — Task 9 is a single
  human-typed run, not a probe batch. The verdict (9 probe steps
  observable in the terminal) is verified manually; a probe batch
  would over-engineer per the Story 17.1 / 17.2 precedent.
- **Lesson 14-F** (ceremony has diminishing returns) — Story 17.3
  keeps the task list lean. No lint / template / process work;
  direct kernel edits + the standard test surface. The
  envelope-pressure surfaced in AC9 / Q6 is a SUBSTANTIVE concern,
  not ceremony; the project-lead direction at dev-pass start is
  binding without further codification.
- **Lesson 13.5-C / B.2** (no "mirrors prior arm" rationale) — AC9
  byte-budget is per-component-itemised. No "this is the BANK*
  family arm of the pattern from Story 17.2" rationale; every
  component named with its opcode-level byte cost. References to
  Story 17.1 / 17.2 patterns are FOR CONTEXT (the `.abort_bank`
  shape; the PUSH DE / POP DE LDIR precedent) — they are NOT
  load-bearing for byte-budget estimation.
- **B.3 / Lesson 13.5-F** (binary handoff) — Pre-edit baseline tasks
  re-`wc -c` and re-derive the 975-PASS baseline at dev-pass start;
  do not inherit any figure from this story's text.
- **B.4 / PD-2** (figure-drift discipline) — every figure quoted in
  this story (25,285 B baseline; 290 B cumulative envelope; 110 B
  remaining; ~216-246 B estimated cost; port 0x72 = slot 2;
  `$8000` = slot-2 window first byte; `$D4AE` = `ACTIVE_PAGES_BASE`)
  is re-validated at dev-pass start by re-reading the cited source
  file or re-running the cited command.

### Project Structure Notes

- **Envelope pressure dominates** — see AC9 §"Envelope-pressure
  note" + Q6. This is the load-bearing concern for Story 17.3's
  dev-pass. The four-word delivery is feature-complete per the
  Epic-17 spec; the byte budget is the gating constraint.
- **Probe-on-add design** — see AC1 + §"Sentinel choice" + Q1. The
  two-sentinel sweep is the recommended conservative choice; the
  single-sentinel form is the byte-shaving alternative.
- **`-BANK` current_bank bookkeeping** — see AC3 + Q3. The
  decrement-on-shift form costs ~6-8 B; the no-bookkeeping form
  costs 0 B but is rougher UX.
- **`BANKS-CLEAR` array zeroing** — see AC4 + Q4. The minimal-cost
  form (zero `bank_count` only) is recommended; the array-zero form
  costs ~10 B.
- **`SET-BANK` slot validation** — see AC5. FR-P4-10 does NOT mandate
  validation; the "diagnostics only — undefined hardware behaviour
  on bad args" disposition is the binding contract. Probe E uses
  `slot = 2` (safe); slot 0 is the kernel slot and writing to it
  disconnects the kernel mid-fetch.
- **iz-cpm baseline probe coverage gap** — see §"iz-cpm baseline
  probe disposition". Probes A + B SKIP on iz-cpm baseline; the
  load-bearing verification is iz-cpm-banking + real-MB. The Story
  16.3 three-surface convention is honoured.

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md`:515..536] — Story 17.3 spec (FRs covered: FR-P4-7, FR-P4-8, FR-P4-9, FR-P4-10; architectural input: Story 16.4 §9.4 closure)
- [Source: `_bmad-output/planning-artifacts/prd.md`:520..523] — FR-P4-7 / FR-P4-8 / FR-P4-9 / FR-P4-10 wording
- [Source: `_bmad-output/planning-artifacts/architecture.md`:386..402] — PD-P4-13 bank-table[] cap policy (§9.4 closure): `+BANK` past cap raises `ABORT" cap?"`
- [Source: `_bmad-output/planning-artifacts/architecture.md`:406..427] — PD-P4-14 CL parser edge-case policy (§9.3 closure): warn-and-continue; informs Story 17.4 inheritance of `+BANK`
- [Source: `_bmad-output/planning-artifacts/architecture.md`:473..487] — Decision Impact Analysis per-epic budget; Epic 17 = ~400 B
- [Source: `docs/antforth-banking-redesign.md`:14..24] — §1 wordset table including `+BANK` / `-BANK` / `BANKS-CLEAR` / `SET-BANK` stack effects + ABORT semantics
- [Source: `docs/antforth-banking-redesign.md`:127..131] — §7 memory budgets: `+BANK`/`-BANK`/`BANKS-CLEAR` ~120 B total estimated by redesign; CL parser + probe loop ~200 B
- [Source: `docs/antforth-banking-redesign.md`:173..174] — §9.4 cap policy (closed by Story 16.4 PD-P4-13)
- [Source: `_bmad-output/implementation-artifacts/17-1-bank-table-allocator-...-memory-map-edit.md`] — Story 17.1 close-out: bank-table[] + UserArea cells + COLD step 8h
- [Source: `_bmad-output/implementation-artifacts/17-2-bank-fetch-bank-store-banks-read-and-swap-primitives.md`] — Story 17.2 close-out: BANK@/BANK!/BANKS + active_pages[] + cold bank-table[0] snapshot + the `.abort_bank` shape + the PUSH DE/POP DE LDIR precedent + PENDING-17.3 + `_SEED-BANK`/`_CLEAR-BANK` fixture
- [Source: `src/banking.asm`:198..206] — `.abort_bank` site (template for `.abort_probe` + `.abort_cap` shape)
- [Source: `src/banking.asm`:25..27] — `BANK_TABLE_CAP = 29` (load-bearing for AC2)
- [Source: `src/banking.asm`:36..37] — `ACTIVE_PAGES_BASE = $D4AE`, `ACTIVE_PAGES_SIZE = 29`
- [Source: `src/banking.asm`:147..196] — `w_BANK_STORE_cf` (Story 17.2; template for the +BANK / -BANK precondition-then-action shape)
- [Source: `src/banking.asm`:166..170] — PUSH DE / POP DE LDIR-preservation pattern (H1 review fix; load-bearing for `-BANK`'s shift-down)
- [Source: `src/structures.asm`:38..50] — Phase-4 UserArea cells (current_bank, bank_count, etc.)
- [Source: `src/antforth.asm`:132..189] — cold_start step 8h: bank-table[] + active_pages[] zero-init; auto-BANK-MAPPING-ON; iz-cpm test-643 NOP slot
- [Source: `tests/banking_tests.fth`:131..202] — Story 17.2 Probe 6 (`bank-store-swap-path`) + PENDING-17.3 probes (Story 17.3 retires + re-enables)
- [Source: `tests/banking_tests.fth`:152..165] — `_SEED-BANK` / `_CLEAR-BANK` inline-asm fixture (Story 17.3 retires)
- [Source: `docs/ans-forth-core-compliance.md`:858..873] — "Non-standard words" table (Story 17.3 appends 4 rows)
- [Source: `Makefile`:88..118] — `test-repl-banking` + `test-repl-banking-skip` recipes (Story 17.3 extends pattern lists)
- [Source: `tests/README.md`] — three-test-surface convention + SKIP-with-rationale shape

## Questions for project lead

These ambiguities surfaced during story drafting. Each is annotated
with a recommended resolution; the dev-pass proceeds per the
recommendation unless overridden at dev-pass start.

- **Q1 (Probe sentinel — single vs two-sentinel sweep):** AC1's
  probe writes a sentinel byte to `$8000`, reads back, restores.
  Single-sentinel form (write `$5A`, read-back, restore) is cheapest
  (~5-6 B less than two-sentinel) but false-positives if the
  original byte at `$8000` happens to equal `$5A` (the write is a
  no-op on ROM, the read returns `$5A`, the probe PASSes the ROM
  page). Two-sentinel sweep (write `$5A`, read-back, write `$A5`,
  read-back) ALWAYS detects ROM at the cost of ~6-8 B over
  single-sentinel.
  **Recommended:** two-sentinel sweep. The single-sentinel byte
  savings is small and the false-positive case is real (firmware
  flash bank 0 byte at `$8000` is deterministic but unknown without
  empirical check). Empirical override is possible at dev-pass start:
  if the byte at `$8000` on MicroBeast firmware flash bank 0 is
  observably NOT `$5A`, single-sentinel suffices.
- **Q2 (`+BANK` dedup at interactive surface):** AC1 last bullet —
  PD-P4-14 (§9.3 closure) treats CL-parser dups as "warn + silent
  dedup", but that's CL-surface. For interactive `+BANK`, the
  cheapest spec-compliant behaviour is to APPEND duplicates (no
  dedup). The downstream `-BANK` only removes the first match, so
  duplicate-then-`-BANK` leaves one entry — intuitive semantics.
  **Recommended:** no dedup at the `+BANK` site; CL parser owns
  dedup at its surface. The interactive `+BANK` user is presumed
  to know what they're doing; CL-parser users may not be (CL tail
  can have a typo or copy-paste dup).
- **Q3 (`-BANK` `current_bank` bookkeeping):** AC3 §"Current-bank
  bookkeeping" — when `-BANK` removes an entry at index `k`, the
  remaining entries at `k+1..bank_count-1` shift down. If
  `k < current_bank`, the logical `current_bank` index now points
  to a different physical page than before. Two dispositions:
  (a) NOT update `current_bank` — user re-issues `BANK!` after
  `-BANK` if needed; 0 B cost; (b) decrement `current_bank` if
  `k < current_bank` — preserves the user's apparent intent that
  the currently-mapped bank stays mapped; ~6-8 B cost.
  **Recommended:** (b) decrement-on-shift. The 6-8 B cost buys
  intuitive UX (the currently-mapped bank stays mapped after
  removing a bank below it). Override to (a) if envelope pressure
  per Q6 dictates byte shaving.
- **Q4 (`BANKS-CLEAR` array zeroing + `-BANK` tail zeroing):** AC4
  §"Body" + AC3 §"Present → shift-down". Zeroing the vacated bytes
  costs ~3 B (`-BANK` tail) + ~10 B (`BANKS-CLEAR` full-array
  zero-loop) = ~13 B. The bytes are unreachable per the `BANK!`
  precondition + the search bounds + the `.BANKS` iteration cap.
  **Recommended:** do NOT zero. The 13 B is unjustified given the
  unreachability; the bytes become unreachable when `bank_count`
  drops below their position. Override is possible if "always-clean
  state" debugging-from-coredump is preferred.
- **Q5 (Probe B `+BANK` known-ROM rejection under iz-cpm-banking):**
  AC7 second bullet — Probe B asserts `$0 +BANK` raises `ABORT"
  probe?"` because page 0 is firmware flash ROM on real MicroBeast.
  Under iz-cpm-banking, page 0 behaviour depends on the `--flash`
  flag: without `--flash`, page 0 is unmapped (returns 0xFF or
  similar; probe sentinel does NOT round-trip; probe fails =
  PASS-the-rejection); with `--flash`, page 0 contains the flash
  contents (also typically ROM-like; probe sentinel still does NOT
  round-trip on ROM-modelled flash; same PASS-the-rejection).
  **Recommended:** verify at dev-pass start by booting iz-cpm-banking
  and probing the behaviour of page 0 directly; surface annotation
  reflects the verified disposition. If iz-cpm-banking models page
  0 as writable (unlike ROM), Probe B SKIPs on iz-cpm-banking with
  the rationale "iz-cpm-banking models flash page 0 as writable;
  ROM rejection unverifiable; load-bearing verification is
  real-MB". Test-run the iz-cpm-banking + page-0 + probe combo at
  dev-pass start to settle this.
- **Q6 (Envelope pressure — four candidate dispositions):** AC9
  §"Envelope-pressure note". The Story 17.3 estimate (~150-180 B at
  the trimmed recommendation, ~216-246 B at the conservative
  estimate) exceeds the AC9 ≤ ~120 B target AND the remaining
  Epic-17 envelope share of ~110 B. Four dispositions:

  - **(a) accept-with-rationale** — surface in Epic-17 retro; the
    envelope is per-epic-budget guidance, not a hard cap (Story
    17.2 already +184 B vs ~80 B target; precedent set). Cost: 0 B
    saved; risk: cumulative pressure on 17.4 / 17.5 / 17.6.
    **Recommended.**
  - **(b) micro-optimise** — drop two-sentinel sweep (Q1 single
    saves ~6-8 B); drop -BANK current_bank bookkeeping (Q3 (a)
    saves ~6-8 B); drop array zeroing (Q4 saves ~13 B). Cumulative
    savings: ~25-29 B. Cost: rougher UX in -BANK + small
    false-positive risk in probe. **Recommended in combination
    with (a).**
  - **(c) defer `SET-BANK` to Epic 22** — `SET-BANK` is diagnostic
    only; not load-bearing for any user-journey path. Deferring to
    Epic 22's polish epic saves ~29 B. Re-scopes Story 17.3 to 3
    words; Epic-17 wordset count drops from 9/12 to 8/12 at 17.3
    close; Story 17.5 still hits 10/12 with `.BANKS`.
    **Recommended only if (a)+(b) miss the target by >50 B.**
  - **(d) sprint-change-proposal** — formal Epic-17 envelope
    expansion or scope cut. **Recommended only if (a)+(b)+(c) miss
    the target.**

  **Compound recommendation:** (a) accept-with-rationale + (b)
  micro-optimise. The envelope is guidance; the four-word delivery
  is feature-complete per the spec; the cumulative pressure is
  surfaced + tracked in Epic-17 retro. The dev-pass picks (b) at
  start; (c) only if measured exceeds the (a)+(b) target by >50 B;
  (d) only if (c) doesn't recover.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]`

### Debug Log References

- iz-cpm-banking source verified at `/home/ant/src/microbeast/iz-cpm/src/cpm_machine.rs` — port 0x72 = bank_map[2], FLASH_BANKS=32, default bank_map=[32,33,34,35] (=[$20,$21,$22,$23]); flash banks 0..31 silently ignore writes (ROM model) — confirms Probe B rejection path under iz-cpm-banking without `--flash`.

### Completion Notes List

**Dev-pass dispositions (Q1-Q6):**

- **Q1 (probe sentinel):** Two-sentinel sweep ($5A + $A5) implemented. Conservative choice per Q1 recommendation — single-sentinel saves ~6-8 B but false-positives if probe target byte = $5A; two-sentinel always detects ROM.
- **Q2 (+BANK dedup):** No dedup. Duplicates append. CL parser (Story 17.4) owns surface-level dedup per PD-P4-14.
- **Q3 (-BANK current_bank bookkeeping):** Disposition (a) — no bookkeeping. -BANK does not touch current_bank or the MMU port; if the removed entry was below current_bank, user re-issues BANK!.
- **Q4 (array zeroing):** Do NOT zero. -BANK leaves vacated tail byte; BANKS-CLEAR resets bank_count only. Both bytes unreachable per BANK! precondition + .BANKS iteration cap.
- **Q5 (iz-cpm-banking page-0 behaviour):** Verified empirically against `cpm_machine.rs:115-133` — flash banks (virt < FLASH_BANKS=32) silently ignore pokes, return 0xFF when no `--flash` loaded. Probe B ROM-rejection asserts cleanly under iz-cpm-banking without flash.
- **Q6 (envelope):** Disposition (a) + partial (b). Two-sentinel sweep retained (Q1 conservative); -BANK no-bookkeeping kept (Q3 a, micro-opt); no array zero (Q4, micro-opt). Measured delta = +217 B, within the conservative AC9 estimate envelope (216-246 B). Cumulative Epic-17 envelope: 290 B + 217 B = 507 B / ~400 B target = 127% — surfaced for Epic-17 retro per Q6 (a).

**Implementation surprises:**

- `+BANK` and `-BANK` initially clobbered DE (= threaded IP) via the probe scratch / LDIR destination — caught on first colon-definition probe run via stack-underflow symptoms after `1 BANK!` corrupted HERE. Fixed by `PUSH DE` / `POP DE` wraps around the probe body (+BANK) and the LDIR (-BANK), same pattern as Story 17.2 BANK! H1 fix.
- Top-level `IF` in interpret mode errors with -14 (`?COMP`), but the surrounding `." PASS:"` / `." FAIL:"` strings emit anyway, accidentally satisfying grep-based recipes — pre-existing pattern in Probes 1-5. Story 17.3 probes are wrapped in colon definitions so `IF/ELSE/THEN` actually compile and the conditional logic actually fires. Surface-gating via `FETCH-74` (port 0x74 readback) now works deterministically.
- Probe 7's `1 BANK!` swaps HERE/LATEST to bank-table[1] (zero-initialised), so any subsequent colon-def compilation would write to address 0. Probe 7 restores bank 0 via `0 BANK!` before `BANKS-CLEAR` so the REPL state stays sane for downstream probes.
- Probe B (ROM-rejection) and Probe D (BANK! abort after BANKS-CLEAR) use `['] _xt CATCH` to trap the `ABORT" probe?"` / `ABORT" bank?"` THROWs inside a colon definition — `CATCH` survives the kernel-internal `w_THROW_cf.kernel_entry` per the existing exception machinery.

**AC1 deviation (surfaced in code-review pass):** AC1 specifies "restore the saved current bank by writing `active_pages[current_bank]` to port `0x72`" on probe complete. The implementation reads the caller's slot-2 page via `IN A, (0x72)` instead (`src/banking.asm:303..304`). Reason: the FIRST `+BANK` at boot runs with `bank_count = 0`, so `active_pages[current_bank=0]` is undefined — `IN A, (0x72)` lifts the chicken-and-egg by reading the live MMU port. Verified against iz-cpm-banking `cpm_machine.rs:138` (port read returns `bank_map[2]`) and the MicroBeast firmware port-readback contract. The deviation is BETTER than the AC for the boot case and equivalent for steady-state; flagged here per [[feedback_standards_compliance]] discipline rather than silently shipped.

**Hardware-smoke (Task 9) — PASS on real MicroBeast 2026-05-16.** Transcript: `~/Downloads/beastty-20260516-101959.bin`. All 9 typed probe steps + the code-review Probe F LDIR extra (step 10) PASSed:

  1. `$22 +BANK BANKS .` → `1 ok` ✓
  2. `$0 +BANK` → `probe?error -2: ABORT"` ✓ (typed as `$0 +BANLK<bksp> K` with mid-token correction; the firmware-flash ROM rejection still fired cleanly through the backspace path)
  3. `BANKS .` → `1 ok` ✓ (Probe B did not modify the list)
  4. `$22 -BANK BANKS .` → `0 ok` ✓ (present-case remove)
  5. `$22 -BANK BANKS .` → `0 ok` ✓ (absent-case no-throw)
  6. `$22 +BANK BANKS-CLEAR BANKS .` → `0 ok` ✓
  7. `0 BANK!` → `bank?error -2: ABORT"` ✓
  8. `$22 2 SET-BANK BANK@ .` → `0 ok` ✓ (current_bank unchanged after raw MMU write)
  9. `$22 +BANK $23 +BANK $24 +BANK $22 -BANK $22 -BANK BANKS .` → `2 ok` ✓ (Probe F LDIR shift-down verified on real hardware — second `$22 -BANK` is a no-op because the shift moved `$23` into index 0)

Banner clean: "MicroBeast - 28514 bytes free" (banking foundation intact; no boot-time crash from the four new DEFCODEs). AC8 + AC11 satisfied.

**Code-review fixes (post-`review` status, in-place):**

- **H1 (`-BANK` LDIR shift untested):** Added Probe F (`minus-bank-ldir-shift-count` + `minus-bank-ldir-shift-data`) at `tests/banking_tests.fth` — seeds `[$22, $23, $24]`, removes `$22` twice; count-check asserts `BANKS=2` (surface-agnostic; catches shift-not-firing); data-check via new `FETCH-72` CODE word asserts port-0x72 readback after `0 BANK!` equals `$23` (surface-gated by `FETCH-74`; catches off-by-N LDIR bugs that pass the count check).
- **H2 (AC2 cap check untested):** Added Probe G (`plus-bank-cap`) — seeds 29 copies of `$22` via `DO 29 0 ... LOOP`, asserts `BANKS=29`, then `['] _do-one-more-+bank CATCH -2 = IF BANKS 29 = IF PASS` — verifies the 30th `+BANK` throws `-2` (cap?) AND `bank_count` is unchanged. Surface-agnostic (cap check is a kernel-cell comparison).
- **M1 (SET-BANK port-write unverified):** Split Probe E into `set-bank-diagnostic-bank-at` (surface-agnostic BANK@-unchanged assertion) + `set-bank-diagnostic-port-write` (surface-gated FETCH-72 readback). Switched sentinel page from `$22` (= slot-2 default; readback would coincide with pre-existing mapping per L5) to `$23` so the readback genuinely discriminates a real OUT from no-op.
- **M2 (BANKS-CLEAR dictionary-state trap undocumented):** Added "USER-FACING TRAP" block to `BANKS-CLEAR` docstring at `src/banking.asm:417..449` — documents the `N BANK! ... BANKS-CLEAR` corruption (HERE/LATEST left at bank-table[N]'s zero snapshot → next dictionary write lands at address 0) and the safe rebuild sequence (`N BANK! ... 0 BANK! BANKS-CLEAR ... +BANK ... BANK!`).
- **M3 (AC1 deviation not flagged):** Added "AC1 deviation" paragraph above under Implementation surprises — documents the `IN A, (0x72)` substitute for `active_pages[current_bank]` and the chicken-and-egg rationale.

LOW findings deferred (L1 SET-BANK slot>=16 footgun, L2 missing +BANK ASSERT, L3 compliance-row convention inconsistency, L4 fixture word namespace pollution, L5 fixed as part of M1, L6 -BANK BC.high asymmetry) — captured in this section for traceability; none are correctness defects.

**Regression baseline preserved (post-code-review re-run):**

- `make test-repl`: 975 PASS / 0 FAIL / 2 SKIP (matches pre-edit baseline; iz-cpm test-643 NOP-padding workaround NOT triggered by +217 B delta).
- `make test-repl-banking`: 19/19 patterns matched (+4 Story-17.3 active probes A-D, +1 split Probe E (bank-at + port-write), +2 re-enabled PENDING-17.3 PASSes, +1 swap-path rewritten to use `$22 +BANK`, +2 code-review Probes F (count + data), +1 code-review Probe G (cap), 1 INFO retained).
- `make test-repl-banking-skip`: 18/18 patterns matched (Probes A/B/F-data/E-port-write SKIP under iz-cpm baseline via FETCH-74 gate; C/D/E-bank-at/F-count/G PASS surface-agnostic).
- `make check-doc-sync`: exit 0; advisory count unchanged at 31 / 0 drift.
- `wc -c build/antforth.com`: 25,502 B (binary unchanged — code-review fixes touch only tests/Makefile and source-comment blocks).

### File List

Modified:

- `src/banking.asm` — +213 B body. Appended `w_PLUS_BANK_cf` + `w_MINUS_BANK_cf` + `w_BANKS_CLEAR_cf` + `w_SET_BANK_cf` DEFCODEs after Story 17.2's `w_BANKS_cf`. Added shared `.abort_probe` + `.abort_cap` sites with `str_probe_q` (6 B) + `str_cap_q` (4 B) literals. Both `+BANK` and `-BANK` wrap DE-clobbering work with `PUSH DE` / `POP DE` (H1-pattern from Story 17.2). **Code-review M2:** added USER-FACING TRAP block to BANKS-CLEAR docstring documenting the `N BANK! ... BANKS-CLEAR` dictionary-corruption pattern and the safe `0 BANK!`-first rebuild sequence.
- `tests/banking_tests.fth` — Probe 6 (`bank-store-swap-path`) rewritten to use `$22 +BANK` instead of `_SEED-BANK` fixture. PENDING-17.3 Probes 7+8 re-enabled (now `bank-store-round-trip-1` / `..-0` with FETCH-74 surface-gate). Story-17.3 Probes A-E added (colon-wrapped so `IF/ELSE/THEN` compile). Inline-asm fixture `_SEED-BANK` / `_CLEAR-BANK` removed (Probe G retirement). Probe 7 added `0 BANK!` restore before `BANKS-CLEAR` to keep HERE/LATEST sane for downstream probes. **Code-review additions:** new `FETCH-72` CODE word (slot-2 port readback); Probe E split into surface-agnostic `set-bank-diagnostic-bank-at` + surface-gated `set-bank-diagnostic-port-write` using sentinel `$23` (M1+L5); Probe F (`minus-bank-ldir-shift-count` + `..-data`) covering the -BANK LDIR path (H1); Probe G (`plus-bank-cap`) covering the 30th-+BANK cap abort (H2).
- `Makefile` — `test-repl-banking` recipe pattern list extended with 5 new PASS patterns (`plus-bank-known-good`, `plus-bank-rom-rejection`, `minus-bank-present-absent`, `banks-clear-zero`, `set-bank-diagnostic`); PENDING `SKIP:` patterns flipped to `PASS:`. `test-repl-banking-skip` pattern list extended with new SKIP patterns (Probes A, B gated) + new PASS patterns (Probes C, D, E surface-agnostic). **Code-review:** swapped `set-bank-diagnostic` for split `set-bank-diagnostic-bank-at` + `set-bank-diagnostic-port-write`; added `minus-bank-ldir-shift-count`, `minus-bank-ldir-shift-data`, `plus-bank-cap` patterns in both recipes (count + cap surface-agnostic; data SKIP-on-baseline).
- `docs/ans-forth-core-compliance.md` — Appended 4 rows to the "Non-standard words" table for `+BANK` / `-BANK` / `BANKS-CLEAR` / `SET-BANK` (file lines 874..877).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `17-3-...` row flipped `ready-for-dev` → `in-progress` (dev start) → `review` (this commit).
- `_bmad-output/implementation-artifacts/17-3-plus-bank-with-probe-on-add-minus-bank-banks-clear-set-bank.md` — this file. Tasks 1-8 + Task 10 checkboxes ticked; Task 9 (hardware-smoke) unchecked pending user action.

Build artifact:

- `build/antforth.com` — 25,502 B (+217 B from 25,285 B Story-17.2 close baseline; code-review fixes touch tests/Makefile/source-comments only — binary unchanged).

Hardware transcript:

- `~/Downloads/beastty-20260516-101959.bin` — real MicroBeast hardware-smoke run for Task 9 / AC8 / AC11. 9-step typed probe sequence + Probe F LDIR-shift extra all PASS.

### Change Log

| Date | Change |
|------|--------|
| 2026-05-16 | Story 17.3 drafted from epics-phase4-epics-16-22.md:515..536; envelope-pressure surfaced in AC9 + Q6; PENDING-17.3 retirement + `_SEED-BANK` fixture retirement scheduled in Task 6; status → ready-for-dev. |
| 2026-05-16 | Story 17.3 dev-passed. Four DEFCODEs added (`+BANK` probe-on-add + cap check, `-BANK` linear search + shift, `BANKS-CLEAR` count reset, `SET-BANK` raw MMU diagnostic). Probe scratch DE-clobber fixed via PUSH/POP DE wrap. Probes A-E added (colon-wrapped, FETCH-74 surface-gated where needed); PENDING-17.3 Probes 7+8 re-enabled; `_SEED-BANK` / `_CLEAR-BANK` fixture retired. Binary +217 B → 25,502 B. test-repl 975/0/2 preserved. test-repl-banking 15/15; test-repl-banking-skip 14/14. Status → review. Hardware-smoke (Task 9) pending user-typed run. |
| 2026-05-16 | Code-review pass (HIGH+MEDIUM fixes in place). Added `FETCH-72` CODE word, Probe F (-BANK LDIR shift count+data — H1), Probe G (+BANK cap abort — H2), split Probe E into bank-at + port-write with sentinel `$23` (M1+L5). Strengthened BANKS-CLEAR docstring with USER-FACING TRAP block on the `N BANK!`-then-BANKS-CLEAR dictionary-corruption pattern (M2). Documented AC1 deviation (`IN A, (0x72)` substitute for `active_pages[current_bank]` to handle boot chicken-and-egg) in Completion Notes (M3). Makefile pattern lists extended in both recipes. Binary unchanged at 25,502 B; test-repl 975/0/2; test-repl-banking 19/19; test-repl-banking-skip 18/18; check-doc-sync 0 drift. Status remains review (Task 9 hardware-smoke still pending). |
| 2026-05-16 | Hardware-smoke (Task 9) PASS on real MicroBeast. Transcript `~/Downloads/beastty-20260516-101959.bin`. All 9 AC8 probe steps + the code-review Probe F LDIR extra (step 10) PASS; banner clean (28,514 bytes free); ROM rejection (`$0 +BANK` → `probe?error -2`), cap rejection deferred to emulator-side Probe G (29 +BANK seeds infeasible by hand-typing), BANKS-CLEAR + bank-list round-trip + SET-BANK diagnostic all behave as specified on real hardware. AC8 + AC11 satisfied. Status → done. |
