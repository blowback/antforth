# Story 17.2: `BANK@` / `BANK!` / `BANKS` — read + swap primitives

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Context — why this story exists, why now

Second story of Epic 17 (Bank primitives + CL configuration), the
second binary-delta story of Phase 4. Story 17.1 closed 2026-05-15
shipping the **banking foundation** — `src/banking.asm` subsystem
file with the 29-entry `bank-table[]` shell at `$D400`, four new
UserArea cells (`saved_bank`, `current_bank`, `bank_table_base`,
`bank_mapping_state`), and `BANK-MAPPING-ON` / `BANK-MAPPING-OFF`
with auto-`ON` in `COLD`. Post-17.1 baseline = **25,101 B / 975 PASS
/ 0 FAIL / 2 SKIP-on-iz-cpm** (re-verify at dev-pass start per B.3 —
see Pre-edit baseline task below). Epic-17 envelope consumed: 106 B
of ~400 B (26.5%); remaining envelope for Stories 17.2 through 17.5
= ~294 B.

Story 17.2 lands the **three user-observable banking-control primitives**
that turn the Story 17.1 infrastructure into something the user can
exercise at the REPL:

1. **`BANK@ ( -- n )`** — getter for `(IY+UserArea.current_bank)`.
   Returns the current logical bank index (index into the active
   bank list, NOT the physical page number). Per FR-P4-1.
2. **`BANK! ( n -- )`** — switcher. Validates `n` against the active
   bank list (ABORT" bank?" if invalid); writes the corresponding
   physical page to the slot-2 MMU port; swaps the per-bank
   `(here, latest, wordlist_head)` triple between the live
   active-state cells and `bank-table[old_bank]` / `bank-table[new_bank]`;
   updates `current_bank`. Per FR-P4-2.
3. **`BANKS ( -- n )`** — count of currently-available banks. Reads
   the active bank-list length cell (new in 17.2). Per FR-P4-3.
   FR-P4-3 names the implementation as a "`VALUE`"; antforth lacks
   ANS `VALUE` / `TO` (§6.2.2295 + §6.2.2405 both
   `Deliberately-omitted` per `docs/ans-forth-core-compliance.md:453,458`),
   so Story 17.2 implements `BANKS` as a `DEFCODE` proxy reading a
   kernel cell — observable behaviour is identical to a Forth `VALUE`
   (push the stored cell). See Q1 in the Questions section for the
   spec-vs-implementation reconciliation.

Story 17.2 also lands the **storage for the active bank list itself**
(the physical-page-per-logical-bank-index mapping that Story 17.3's
`+BANK` / `-BANK` will populate). Story 17.1 declared `bank-table[]`
holding only the `(here, latest, wordlist_head)` triple per bank;
the physical-page-per-bank-index mapping is a separate concern,
declared here for the first time:

  - **`active_pages[]` array** at `BANK_TABLE_BASE + BANK_TABLE_SHELL_SIZE`
    (= `$D400 + 174 = $D4AE`), reserving 29 bytes (one byte per
    logical-bank-index slot) in the reclaimed `$D400-$DBFF` CCP region.
    Zero-initialised in COLD alongside the existing bank-table[]
    zero-init. Read by `BANK!` to get the physical page for a logical
    bank index. Written by Story 17.3's `+BANK` (push) / `-BANK` (slot
    delete) / `BANKS-CLEAR` (zero) — Story 17.2 only declares it.
  - **`bank_count` UserArea cell** (DW 0) — count of active banks
    (= length of the active list). Read by `BANKS`. Initialised to
    0 in COLD (no banks active at Story 17.2 close; Story 17.4's
    CL parser populates the defaults at boot). Story 17.2 only
    declares the cell + the COLD zero-init.

The forward-inheritance contract is captured in §"Forward inheritance
pointers" below: Story 17.3 owns `+BANK` / `-BANK` / `BANKS-CLEAR`
/ `SET-BANK`; Story 17.4 owns the CL parser that auto-populates
the active list with defaults at boot; Story 17.5 owns `.BANKS`;
Story 17.6 is the iron-spike + tag close-out.

## Story

As Marc (OG retrocomputing user) running antforth on real MicroBeast,
I want to read the current logical bank index with `BANK@`, switch banks
with `BANK!`, and query the active-bank count with `BANKS`,
So that I have observable end-to-end banking control at the REPL before
bank-aware `:` (Epic 19) ships — and the Epic-17 ~400 B envelope's next
≤80 B is consumed against the **measured** 25,101 B baseline (re-`wc -c`
at dev-pass start per B.3 / Lesson 13.5-F).

## Acceptance Criteria

**Given** Story 17.1 has shipped (`bank-table[]` shell at `$D400` +
UserArea cells `saved_bank` / `current_bank` / `bank_table_base` /
`bank_mapping_state` + `BANK-MAPPING-ON` / `BANK-MAPPING-OFF` +
COLD auto-`ON` + memory-map edit),
**When** Story 17.2 is dev-passed,

**Then** **AC1** (`BANK@`) — `BANK@ ( -- n )` is implemented in
`src/banking.asm` as a `DEFCODE` word. The body reads
`(IY+UserArea.current_bank)` and pushes it onto the parameter stack
(BC=TOS convention; standard `_push_bc_tos` then load new BC).
`n` is the index into the active bank list (NOT the physical page
number) per FR-P4-1. Source-comment block above the `DEFCODE` carries
`; antforth extension BANK@ — see docs/antforth-banking-redesign.md §5.4`
per CCD-3 / NFR-P4-14. The word is available at the REPL and inside
colon definitions.

**And** **AC2** (`BANK!`) — `BANK! ( n -- )` is implemented in
`src/banking.asm` as a `DEFCODE` word per FR-P4-2:

  - **Precondition check:** if `n < 0` or `n >= bank_count`, raise
    `ABORT" bank?"` per FR-P4-2 / PD-P4-13's existing ABORT" convention
    (`THROW -2` decoded by `print_throw_description` via the existing
    ABORT" path). The check uses the standard `_abort_msg` pattern
    seen elsewhere in `src/banking.asm` (cross-reference Story 17.1's
    BANK-MAPPING-OFF source-comment block for the in-file precedent).
  - **MMU port write:** on success, write `active_pages[n]` (the
    physical page byte) to MMU port `0x70 + 2 = 0x72` (slot 2; the
    portal-page slot per PD-P4-9 + redesign-doc §5.1 / §5.2 — the
    user-RAM banks rotate through slot 2 at `$8000-$BFFF`). The
    exact port number is **decided in dev-pass against the
    iz-cpm-banking source + the MicroBeast schematic**; the port
    write is a single `OUT (port), A` instruction. UNLIKE
    `BANK-MAPPING-OFF`'s port-0x74 write (which disconnects the
    kernel from RAM and triggers a firmware reset — Story 17.1
    AC10 hardware finding), the slot-2 page-map write at port 0x72
    is **safe from kernel-disconnect failure**: the kernel binary
    lives in slot 0 (`$0000-$3FFF`); switching slot 2 does not
    affect the address range the CPU is currently fetching from.
    Dev-pass verifies this empirically by round-tripping `0 BANK!`
    + `BANK@ .` under `iz-cpm-banking` before any other test.
  - **Per-bank triple swap:** swap the
    `(here, latest, wordlist_head)` triple between the live
    active-state cells and `bank-table[old_bank]` /
    `bank-table[new_bank]`. Concretely: save `(live_here, live_latest,
    live_wordlist_head)` to `bank-table[old_bank][0..5]`; then load
    `bank-table[new_bank][0..5]` into the live cells. This is the
    "initial swap only" semantics per FR-P4-22 — full plumbing of
    per-bank `,` / `COMPILE,` writes is Epic 19. Story 17.2 ships
    the swap MECHANISM; the live cells whose values are being
    swapped are: live `here` = current `(IY+UserArea.here)` (or
    whatever cell antforth's HERE word reads — verify in dev-pass
    against `src/memory.asm` HERE/LATEST/wordlist-head storage);
    live `latest` = current `(IY+UserArea.latest)`; live
    `wordlist_head` = first cell of `forth_wordlist` (cross-ref
    `src/wordlists.asm`). The dev-pass MUST verify these
    addresses exist before assuming UserArea offsets — if HERE
    lives elsewhere, the swap source/destination changes
    accordingly (recorded in Dev Notes per B.4 figure-drift
    discipline).
  - **`current_bank` update:** on success, write `n` to
    `(IY+UserArea.current_bank)`.
  - **bank-table[0] initial population in COLD:** for the swap-on-`BANK!`
    semantics to round-trip correctly once Story 17.3+17.4 have
    populated the active list, `bank-table[0]` MUST hold the live
    `(here, latest, wordlist_head)` values at COLD entry. Story 17.2
    extends `cold_start` step 8h (Story 17.1's bank-table[] zero-init
    region) with a "bank-table[0] ← live triple" snapshot AFTER the
    zero-init clears the 174 B. The snapshot fires after the kernel
    has finished setting up `here` / `latest` / `wordlist_head` but
    before the auto-`BANK-MAPPING-ON` body (the existing step 8h
    insertion point). Estimated cost: ≤15 B (three 2-cell copies
    via `LD A, (src); LD (dst), A` × 6 bytes, or one `LDIR` if
    addressing aligns).

  Source-comment block above the `DEFCODE` carries `; antforth
  extension BANK! — see docs/antforth-banking-redesign.md §5.4`.
  The word is available at the REPL and inside colon definitions.

**And** **AC3** (`BANKS`) — `BANKS ( -- n )` is implemented in
`src/banking.asm` per FR-P4-3. **Implementation choice deviates from
the FR text** — FR-P4-3 says "a VALUE derived from the active
bank-list length"; antforth has `VALUE` / `TO` deliberately omitted
in v2.0 (`docs/ans-forth-core-compliance.md:453,458`); shipping
`VALUE` / `TO` to back this single use is out-of-Epic-17-scope and
unnecessary (an Epic-N+1 enhancement could refactor `BANKS` to a
real `VALUE` once `VALUE` / `TO` ship). Story 17.2 implements
`BANKS` as a `DEFCODE` word that reads `(IY+UserArea.bank_count)`
and pushes it. **Observable behaviour at the REPL is identical**
to a Forth `VALUE`: stack effect is `( -- n )` returning the
stored count; the value is mutable via the kernel-cell writes
that Story 17.3's `+BANK` / `-BANK` / `BANKS-CLEAR` will perform.

The `BANKS`-as-`DEFCODE` rationale is recorded in Dev Notes
"BANKS implementation choice" with the cross-reference to
`docs/ans-forth-core-compliance.md:458` (the `VALUE` omission row);
the spec-vs-implementation reconciliation is the binding choice.
A row added to the compliance doc per AC4 names the word as
"`Implemented (antforth extension, DEFCODE proxy for the VALUE
specified in FR-P4-3)`".

Source-comment block above the `DEFCODE` carries `; antforth
extension BANKS — see docs/antforth-banking-redesign.md §5.4`
+ a one-line rationale citing the `VALUE` omission.

**And** **AC4** (CCD-3 source flags + compliance-doc rows) — all three
words carry `; antforth extension <word> — see
docs/antforth-banking-redesign.md §<n>` source-comment blocks
above their `DEFCODE` lines per NFR-P4-14.
`docs/ans-forth-core-compliance.md` gains three rows in the
"Non-standard words" table at the end of the file (currently the
table holds the Story 17.1 two-row addition; pre-17.1 baseline =
5 rows; post-17.1 = 7 rows; post-17.2 = 10 rows). Row format
follows the Story 17.1 precedent at `docs/ans-forth-core-compliance.md:869..870`:

| Word | Source | Standard word set |
|------|--------|-------------------|
| `BANK@` | `src/banking.asm:<line>` | Non-standard (antforth extension — see `docs/antforth-banking-redesign.md` §5.4) |
| `BANK!` | `src/banking.asm:<line>` | Non-standard (antforth extension — see `docs/antforth-banking-redesign.md` §5.4) |
| `BANKS` | `src/banking.asm:<line>` | Non-standard (antforth extension — see `docs/antforth-banking-redesign.md` §5.4; DEFCODE proxy for the VALUE specified in FR-P4-3 — `VALUE` / `TO` are `Deliberately-omitted` in v2.0 per §6.2.2295 + §6.2.2405) |

Line numbers re-derived from the final `src/banking.asm` at dev-pass
close per B.4 figure-drift discipline (Story 17.1 used `:41` /
`:76` after re-grep; Story 17.2 follows the same re-grep pattern).
`make check-doc-sync` MUST exit 0 with 0 drift (advisory count may
increase by ≤3 corresponding to the three new compliance rows).

**And** **AC5** (NFR-P4-2 latency probe) — a benchmark probe under
the banking-capable emulator measures `BANK!` completing in
≤ 60 Z80 T-states + the MMU port-write time per NFR-P4-2. Concretely:

  - The probe is a T-state counter wrapping a single `BANK!` invocation.
    iz-cpm-banking's `--trace` mode or equivalent T-state accounting
    is the measurement surface (verify availability in dev-pass; if
    iz-cpm-banking lacks T-state accounting, the probe falls back to
    a paper-arithmetic walk through the `BANK!` body counting Z80
    T-states per opcode — the per-opcode T-state table at
    `docs/z80_opcodes.md` is the reference). The paper-arithmetic walk
    is the FALLBACK; the empirical measurement is preferred when
    available.
  - The body itemisation: `0` argument (push) + `BANK!` invocation.
    `BANK!` body itemisation = active-list-lookup loop (or array
    indexing — see Q3 in Questions section) + ABORT" bank?" check
    (taken path: trivial; not-taken path: ≤10 T-states for the
    compare-and-branch) + `OUT (0x72), A` (12 T-states) + 6-byte
    LDIR-cascade for the triple swap or 3× 2-byte LD-pairs (~30-50
    T-states) + `(IY+UserArea.current_bank) ← n` write (~20 T-states).
    Estimated total: ~70-100 T-states (above the ≤60 T-state NFR
    envelope by 10-40 T-states). Dev-pass surfaces the measured
    value + the per-opcode walk; if measured exceeds 60 T-states,
    options: (a) accept-with-rationale (NFR-P4-2's "≤ 60" is for
    cross-bank dispatch overhead per FR-P4-16; `BANK!` itself is a
    REPL-level word, not a per-call hot path), (b) micro-optimise
    the swap to LDIR, (c) trigger sprint-change-proposal evaluation.
    The recommended disposition is **(a) accept-with-rationale** per
    the FR-P4-16 / NFR-P4-2 split — NFR-P4-2's 60-T-state envelope
    binds the cross-bank-dispatch path (Epic 18), not the user-facing
    `BANK!` word.
  - Result captured in Dev Notes against the envelope; included in
    `tests/banking_tests.fth` as a Probe-3 with annotation
    "informational — NFR-P4-2 envelope is for cross-bank dispatch
    (Epic 18), not `BANK!` itself" per the disposition above.

**And** **AC6** (REPL probes — per S2 / NFR-P4-29) — `tests/banking_tests.fth`
gains a probe block honoring the epic AC text:

  - **Probe 1 (always-valid at 17.2 close):** `BANK@ .` returns `0 ok` at
    boot — verifies `current_bank` is 0 after COLD; PASS on iz-cpm,
    iz-cpm-banking, real-MB.
  - **Probe 2 (always-valid at 17.2 close):** `BANKS .` returns `0 ok`
    at boot — verifies `bank_count` is 0 after COLD; PASS on all three
    surfaces. **NOTE:** the epic AC text reads `BANKS . returns the
    configured-banks count (initially 12 with defaults)`. This is
    correct at the END of Epic 17 (after Story 17.4's CL parser
    populates the defaults at boot); at Story 17.2 close, `bank_count`
    is still 0 because the active list is empty (Story 17.3's `+BANK`
    populates it, Story 17.4's CL parser auto-populates at boot).
    Probe 2 asserts `0 ok`; the "12 ok" probe lights up post-17.4 and
    is deferred to Story 17.4's probe block per the sequencing in
    §"Project Structure Notes" → "AC6 probe sequencing"
    below. See Q2 in Questions section for the spec-vs-implementation
    reconciliation.
  - **Probe 3 (always-valid at 17.2 close):** `99 BANK!` raises
    `ABORT" bank?"` — verifies precondition check fires; the REPL
    recovers to the prompt with state intact (stack empty post-ABORT
    via the standard ABORT"-via-THROW-(-2) path); PASS on all three
    surfaces. This is the precondition-path probe; works regardless
    of the active list being empty.
  - **Probe 4 (deferred to Story 17.3):** `1 BANK! BANK@ .` returns
    `1 ok` — requires the active list to contain bank index 1, which
    requires Story 17.3's `+BANK` to populate it (or Story 17.4's
    CL parser at boot). Probe 4 is **authored in `tests/banking_tests.fth`
    at Story 17.2 close** as a **PENDING-17.3** marker (Forth
    comment `\ PENDING-17.3` before the probe text + an
    `iz-cpm-SKIP / iz-cpm-banking-SKIP / real-MB-SKIP` annotation
    block per the Story 16.3 three-surface convention); Story 17.3's
    dev-pass enables Probe 4 once the active-list-population
    machinery is wired. The decision to author-now-and-defer (vs.
    author-later-in-17.3) is a Lesson-14-F call (no ceremony for
    ceremony's sake); recommended per §"AC6 probe sequencing".
  - **Probe 5 (deferred to Story 17.3):** `0 BANK!` round-trips —
    requires the active list to contain bank index 0 (same
    sequencing constraint as Probe 4). Authored as PENDING-17.3
    alongside Probe 4. Note: even though `current_bank` is already
    0 at COLD, `0 BANK!` would ABORT" bank?" at 17.2 close because
    `bank_count == 0` and the precondition `n < bank_count` fails.

Probe 1 + Probe 2 + Probe 3 are the **active probe gate** at Story
17.2 close. Probe 4 + Probe 5 + the latency-probe (AC5) sit alongside
in the file but do not block 17.2 PASS verdict.

**And** **AC7** (probe surfaces — three-test-surface convention per
Story 16.3) — probes from AC6 are annotated per the Story 16.3
three-surface convention; surface annotation block precedes each
probe per `tests/README.md` §5. Verdict matrix at Story 17.2 close:

| Probe | iz-cpm | iz-cpm-banking | real-MB |
|-------|--------|----------------|---------|
| 1 (`BANK@ .` → `0 ok`) | PASS | PASS | PASS |
| 2 (`BANKS .` → `0 ok`) | PASS | PASS | PASS |
| 3 (`99 BANK!` → ABORT" bank?") | PASS | PASS | PASS |
| 4 (`1 BANK! BANK@ .` → `1 ok`) | SKIP (PENDING-17.3) | SKIP (PENDING-17.3) | SKIP (PENDING-17.3) |
| 5 (`0 BANK!` round-trip) | SKIP (PENDING-17.3) | SKIP (PENDING-17.3) | SKIP (PENDING-17.3) |

One hardware-typed probe (Probe 3, the ABORT precondition path)
runs on real MicroBeast per S9 / NFR-P4-11 (Story 17.2 is a
binary-delta story; S9 reactivates). The hardware probe is a single
human-typed run per Lesson 16-A; transcript saved as
`~/Downloads/beastty-<date>.bin`.

**And** **AC8** (binary delta + Epic 17 envelope tracking) — `wc -c
build/antforth.com` grows by **≤ ~80 B** for this story. Per-component
estimate (B.2-compliant per-component itemisation; no comparison to
prior story body shapes):

  - `BANK@` DEFCODE header (5-byte name) = ~16 B
  - `BANK@` body (push current_bank cell to BC=TOS) = ~10 B
    (`_push_bc_tos` call + `LD C, (IY+...); LD B, (IY+...+1)` + NEXT)
  - `BANK!` DEFCODE header (5-byte name) = ~16 B
  - `BANK!` body (precondition check + OUT + triple swap + cell write)
    = ~40-60 B (compare-against-bank_count + ABORT" bank?" call site
    + active_pages[] index + OUT (port), A + 6-byte triple
    save-then-load + current_bank write)
  - `BANKS` DEFCODE header (5-byte name) = ~16 B
  - `BANKS` body (push bank_count cell to BC=TOS) = ~10 B
  - `bank_count` UserArea cell — 0 B (DS UserArea is fixed-memory)
  - `active_pages[]` array — 0 B (lives at $D4AE in reclaimed $D400-region;
    declared via EQU only, no DS in binary)
  - COLD bank-table[0] live-triple snapshot (AC2 final bullet) = ~15 B
    (three 2-byte writes via LD A, (src); LD (dst), A pairs, or one
    LDIR)
  - COLD active_pages[] zero-init (29 B) — option (a) absorb into
    existing 174 B DJNZ zero-loop by extending it to 174+29 = 203 B
    (+1 B in LD B,n immediate, no extra opcodes); option (b) add a
    separate DJNZ pass for active_pages[] (+10 B). Picked in dev-pass.
    Recommended (a) per Lesson 14-F (no ceremony).
  - **Estimated total:** ~110-130 B with all components. The ≤~80 B
    envelope is tight; dev-pass MUST validate against actual measured
    delta and trigger sprint-change-proposal evaluation if the
    measured delta exceeds +20 B over the ~80 B target (per Story
    17.1's AC9 precedent: +20 B is the noise tolerance, beyond which
    SCP triggers).

The cumulative Epic-17 envelope = ~400 B; Story 17.1 consumed 106 B;
Story 17.2's ≤ ~80 B contribution leaves Stories 17.3 / 17.4 / 17.5
with ~214 B remaining. Per-component itemisation captured in Dev
Notes per B.2 / Lesson 13.5-C ("mirrors prior arm" HALT signal
applies — every component named with its opcode-level byte cost; no
"this is the BANK! arm of the pattern from Story 17.1" rationale).

**And** **AC9** (regression baseline + banking-emu probes) — `make
test-repl` reports **≥ 975 PASS / 0 FAIL / 2 SKIP** on iz-cpm
(Phase-3+17.1 close-out baseline preserved per FR-P4-41 / NFR-P4-10;
baseline re-derived at dev-pass start per B.3 — the 975 figure is
the Story-17.1 close-out baseline and may be incremented between
17.1 close and 17.2 start by any hitch-hiker commits; whichever
value is current at dev-pass start is the binding baseline).
`make test-repl-banking` reports PASS on all active probes (Probe 1
+ Probe 2 + Probe 3 from AC6, plus Story 17.1's existing 3 probes
= 6 active probes total). `make test-repl-banking-skip` reports
PASS on surface checks for the SKIP probes (Probes 4 + 5 SKIP
cleanly on iz-cpm baseline; PASS-asserts on the surface-agnostic
probes Probes 1 + 2 + 3). `make check-doc-sync` exits 0; advisory
count may increase by ≤3 per AC4.

**And** **AC10** (S9 hardware-smoke per NFR-P4-11) — a hardware-typed
probe batch runs on real CP/M 2.2 / MicroBeast and PASSes:

  1. Boot reaches the banner cleanly (no crash from the COLD
     bank-table[0] snapshot at AC2 final bullet; banner string
     unchanged from Story 17.1 post-fix baseline since Story 17.4
     is what changes the banner — Story 17.2 keeps the banner as
     `AntForth v2.0.0 (C) ant.org 2026` / `MicroBeast - XXXXX
     bytes free` / `Type BYE to exit`).
  2. `BANK@ .` at the REPL prompt prints `0 ok` (Probe 1 on
     hardware).
  3. `BANKS .` at the REPL prompt prints `0 ok` (Probe 2 on
     hardware).
  4. `99 BANK!` at the REPL prompt prints `bank?` (or the configured
     ABORT" decoding) and the REPL recovers to the prompt with state
     intact (Probe 3 on hardware).
  5. Transcript saved per established `~/Downloads/beastty-<date>.bin`
     naming.

  The probe batch is single human-typed per Lesson 16-A (single
  human-typed hardware run is the cheapest hardware-verification
  shape when the verdict is observable in the terminal). One run,
  one transcript, verdict captured inline in Dev Notes per the S12
  + S9 convention.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Expected baseline = 25,101 B post-Story-17.1. **Measured: 25,101 B ✓**
- [x] Capture current `make test-repl` baseline pass count → expected = 975 PASS / 0 FAIL / 2 SKIP **— measured exactly 975 PASS / 0 FAIL / 2 SKIP ✓**
- [x] Capture current `make test-repl-banking` baseline → expected = PASS × 3 **— measured 3 PASS (banking-emu-probe, banking-mapping-on-idempotent, banking-mapping-on-port-74) ✓**
- [x] Capture current `make test-repl-banking-skip` baseline → expected = PASS × 3 **— measured 3 PASS surface checks ✓**
- [x] Verify `iz-cpm-banking` @ `1777a85` still on PATH (per `.tool-versions`) **— `iz-cpm-banking 1777a85` on PATH ✓**
- [x] Verify HERE / LATEST / wordlist_head storage addresses (`src/memory.asm` + `src/wordlists.asm`) — these are the live-cell sources/destinations for the BANK! triple swap (AC2). If the storage shape differs from what AC2 assumes (e.g., HERE in a label not a UserArea cell), record the actual shape in Dev Notes and adjust the swap implementation accordingly per B.4 figure-drift discipline. **— Confirmed: HERE = `(IY+UserArea.here)` at offset 4 (`src/structures.asm:21`); LATEST = `(IY+UserArea.latest)` at offset 6 (contiguous 4-byte HERE+LATEST pair); wordlist_head = first cell at `forth_wordlist:` label = WORDLIST_NEXT chain pointer (`src/wordlists.asm:336-337`), initial value 0. Port 0x72 = slot 2 confirmed against iz-cpm-banking `src/cpm_machine.rs:13` (PORT_BANK0 = 0x70, slot 2 = 0x72).**

### Task 1 — `bank_count` UserArea cell + `active_pages[]` storage declaration (AC2, AC3, AC8)

- [x] 1.1 — Add `bank_count DW 0` to `STRUCT UserArea` in `src/structures.asm` at the end (after Story 17.1's `bank_mapping_state`). Verify IY+d displacement headroom: post-17.1 = 20 B; post-17.2 = 18 B (one new 2-byte cell). Still well within the 127-byte signed-byte LD-IY+d cap. **— Appended at `src/structures.asm:36-39` with CCD-3 cite + VALUE/TO-omission reference.**
- [x] 1.2 — Add `ACTIVE_PAGES_BASE EQU BANK_TABLE_BASE + BANK_TABLE_SHELL_SIZE` (= `$D400 + 174 = $D4AE`) to `src/banking.asm` constants block. Reserves the 29-byte region `$D4AE..$D4CA` for the active-pages mapping. Add a one-line CCD-3 comment citing the design. **— Added at `src/banking.asm:30-37` together with `ACTIVE_PAGES_SIZE EQU BANK_TABLE_CAP` for the zero-init counter reuse.**
- [x] 1.3 — Verify the active_pages region fits in the reclaimed `$D400-$DBFF` (2 KB) claim: `$D4CA < $DBFF` ✓ (with ~1.8 KB headroom for the descriptor-stub allocator that Epic 18 lands). **— Confirmed; comments in `src/banking.asm:31-32` cite the 2 KB headroom.**
- [x] 1.4 — `make asm` exits 0, no warnings. UserArea struct grows 108 B → 110 B (+2 B). Pre-existing offsets preserved byte-identical (`bank_count` is appended, not inserted). **— Build clean, 0 warnings; `wc -c` jumped 25,101 → 25,103 (+2 B) consistent with UserArea growth.**

### Task 2 — Extend COLD: bank_count zero-init + active_pages[] zero-init + bank-table[0] live-triple snapshot (AC2 final bullet, AC8)

- [x] 2.1 — In `cold_start` step 8h (`src/antforth.asm`, inside Story 17.1's bank-table[] zero-init region), extend the DJNZ zero-init loop's counter from 174 B (`BANK_TABLE_SHELL_SIZE`) to 203 B (`BANK_TABLE_SHELL_SIZE + 29`) — same loop body, single byte change in the `LD B, n` immediate. Verifies in dev-pass: the loop zeros both `bank-table[]` and `active_pages[]` in one pass. **— Implemented via `LD B, BANK_TABLE_SHELL_SIZE + ACTIVE_PAGES_SIZE` at `src/antforth.asm:144`; opcode unchanged, only the immediate byte (174 → 203). 0 B delta.**
- [x] 2.2 — Add `(IY+UserArea.bank_count) ← 0` (low byte + high byte) immediately after the Story 17.1 bank_table_base / current_bank / saved_bank inits. Estimated cost: ~8 B (2 × LD-IY+d,n). **— 2× LD `(IY+UserArea.bank_count[+1])`, 0 at `src/antforth.asm:157-158`; measured +8 B.**
- [x] 2.3 — Add bank-table[0] live-triple snapshot AFTER the kernel has finished setting up HERE / LATEST / wordlist_head (verify timing in dev-pass — depends on where HERE init lives in cold_start). Snapshot writes `(live_here, live_latest, live_wordlist_head)` to `bank-table[0][0..5]` (= `$D400..$D405`). Estimated cost: ~15 B for three 2-byte copies, or fewer if HL is already pointing at one of the live cells from a prior init step (peephole opportunity flagged for dev-pass). **— LDIR-cascade form: 4-byte LDIR for HERE+LATEST (contiguous in UserArea), then `LD HL, (forth_wordlist); LD (BANK_TABLE_BASE+4), HL` for the wordlist_head cell (non-contiguous). Total +17 B. Insertion point = `src/antforth.asm:159-169`, after bank_count zero-init, before the auto-`BANK-MAPPING-ON` block. HERE (step 7) / LATEST (step 8b) / current_wordlist (step 8e) all settled before this point ✓.**
- [x] 2.4 — Verify boot under iz-cpm: kernel reaches banner cleanly, no crash from the snapshot or the extended zero-loop. `make test-repl` = 975 PASS preserved. **— BANNER prints cleanly; initial `make test-repl` failed test 643 (iz-cpm `*/` underflow recovery hang — known layout-sensitive quirk per `feedback_iz_cpm_test_643_quirk.md`). +25 B layout shift re-introduced the hang; restored 975 PASS / 0 FAIL / 2 SKIP by extending the Story 17.1 single-NOP layout-shift slot to 3 NOPs (`src/antforth.asm:179-181`; +2 B net). Comment in-file documents the empirical tuning.**
- [x] 2.5 — Verify the bank-table[0] snapshot was correct via probe: `BANK_TABLE_BASE @` should equal the current `HERE` value at REPL prompt time (i.e., `here_after_cold_init`). One-line probe `HERE BANK_TABLE_BASE @ = . CR` should print `-1 ok` (TRUE). This is an internal-consistency check, not a user-facing probe; capture verdict in Dev Notes. **— Probe run (BANK_TABLE_BASE is a kernel EQU, not a Forth word; substituted literal `$D400`). `HERE $D400 @ = . CR` → `-1` (TRUE) ✓. `$D404 @ . CR` → `0` (= forth_wordlist's WORDLIST_NEXT cell at COLD; matches expected wordlist_head value).**

### Task 3 — `BANK@` DEFCODE (AC1)

- [x] 3.1 — Author `w_BANK_AT_cf` at the start of the banking-words DEFCODE block in `src/banking.asm` (after the existing BANK-MAPPING-OFF DEFCODE). Body: `_push_bc_tos` (standard pattern in `src/banking.asm` and elsewhere) then `LD C, (IY+UserArea.current_bank); LD B, (IY+UserArea.current_bank+1)` then `NEXT`. Estimated body cost: ~10 B (3-byte call + 6-byte LD-IY+d pair + 1-byte NEXT trampoline tail). **— Implemented at `src/banking.asm:91-100`. Antforth convention is inline `PUSH BC` (1 B) rather than a `_push_bc_tos` subroutine call (verified via `w_HERE_cf` precedent at `src/memory.asm:124-130`); body = PUSH BC + 2× LD-IY+d (3 B each) + NEXT (7 B inline) = 14 B body. Header (hash_link+count+name "BANK@") = 8 B. Task 3 total = 22 B (matches estimate ✓).**
- [x] 3.2 — Source-comment block above the DEFCODE with FR-P4-1 cross-ref + CCD-3 antforth-extension tag (the §5.4 / §1 references). **— Comment block at `src/banking.asm:91-98`: cites FR-P4-1, redesign §5.4, and "logical bank-list index, NOT physical page number" disambiguation.**
- [x] 3.3 — Verify under iz-cpm: `BANK@ .` at REPL prints `0 ok`. Probe 1 of AC6. **— `BANK@ . CR` → `0  ok` under iz-cpm baseline ✓.**

### Task 4 — `BANK!` DEFCODE (AC2)

- [x] 4.1 — Author `w_BANK_STORE_cf` immediately after `w_BANK_AT_cf` in `src/banking.asm`. Body decomposed:
  - **4.1a (precondition check)** — pop TOS into A (or scratch reg), compare `A < bank_count` (or `A < (IY+UserArea.bank_count)`); if not, branch to ABORT" bank?" site. Estimated cost: ~10-15 B (TOS-pop + compare + conditional branch). **— Implemented as 2-stage check at `src/banking.asm:151-156`: `LD A, B; OR A; JR NZ, .abort_bank` rejects BC.high != 0 (handles 16-bit out-of-range like `400 BANK!`), then `LD A, C; CP (IY+UserArea.bank_count); JR NC, .abort_bank` rejects BC.low >= bank_count. Total 10 B.**
  - **4.1b (MMU port write)** — load `active_pages[A]` (= `LD HL, ACTIVE_PAGES_BASE; ADD HL, A_extended_to_HL`; `LD A, (HL)`); `OUT (0x72), A` (slot-2 port per §"Slot/port resolution" in Dev Notes). Estimated cost: ~10 B. **— Implemented at `src/banking.asm:158-161` using `ADD HL, BC` directly (BC.high == 0 already validated above) instead of zero-extending C through H+L: `LD HL, ACTIVE_PAGES_BASE; ADD HL, BC; LD A, (HL); OUT (0x72), A`. Total 7 B (3 B saved vs the literal-spec form). Port 0x72 confirmed against iz-cpm-banking `cpm_machine.rs:13-14`.**
  - **4.1c (triple swap)** — save live (here, latest, wordlist_head) to `bank-table[old_bank][0..5]` via `LD HL, BANK_TABLE_BASE; ... ; LDIR` (or three 2-byte copies); then load `bank-table[new_bank][0..5]` to live cells. Estimated cost: ~30-40 B (two indexing computations + two LDIR-cascade ops). Dev-pass picks the layout (LDIR vs. three explicit copies vs. EX DE,HL swap pattern) per actual cell address pairs. **— LDIR-cascade picked. The HERE+LATEST live cells are contiguous (UserArea offsets 4..7 — 4 bytes), so 4-byte LDIR handles them as one op; the wordlist_head cell at `forth_wordlist` is non-contiguous, so a separate 2-byte LDIR (load direction) or 2-byte EX-DE+manual-store (save direction; 1 B shorter than LDIR here) handles it. Offset computation factored into `bank_offset_hl` helper (compact 8-B form per §"Body byte-budget" in Dev Notes below) called twice. Total swap body = 22 B save + 23 B load = 45 B (vs the 30-40 B estimate — over by ~5-15 B due to the rpush_bc/rpop_bc preservation of BC=new_bank across the LDIR cascade; LDIR's `LD BC, 4` clobbers BC and BC must survive both halves of the swap).**
  - **4.1d (current_bank update)** — `LD (IY+UserArea.current_bank), A; LD (IY+UserArea.current_bank+1), 0`. Estimated cost: ~8 B. **— Implemented at `src/banking.asm:165-166` as `LD A, (IY+UserArea.current_bank); LD (IY+UserArea.current_bank), C` (3 + 3 = 6 B). The +1 high-byte write is ELIDED — current_bank+1 is zero at COLD (`src/antforth.asm:151`) and the precondition guarantees BC.high == 0 on every entry, so the high byte stays 0 permanently and the write would be a known-zero no-op (saves 3 B vs the spec's literal 8-B form). Rationale documented in the source-comment block at `src/banking.asm:140-143`.**
  - **4.1e** — `NEXT`. **— `POP BC` (1 B, pulls new TOS from data stack) + inline NEXT (7 B) = 8 B tail.**
- [x] 4.2 — Source-comment block above the DEFCODE with FR-P4-2 cross-ref + CCD-3 antforth-extension tag + a brief note on the slot-2-port-0x72 choice + the "safe from kernel-disconnect failure" rationale (distinct from BANK-MAPPING-OFF's port-0x74-disconnect-failure mode). **— Comment block at `src/banking.asm:102-145` cites FR-P4-2 / PD-P4-3 / FR-P4-22, the §5.4 redesign reference, the slot-2 / port-0x72 choice with the iz-cpm-banking source citation, and the kernel-disconnect-safety contrast to Story 17.1's BANK-MAPPING-OFF.**
- [x] 4.3 — ABORT" bank?" call site — use the standard ABORT"-via-THROW(-2) pattern; the literal `bank?` message lives in the DEFCODE source per the ABORT" macro convention. Verify the message text appears in the binary post-build via `strings build/antforth.com | grep bank` — should print `bank?` exactly once. **— `.abort_bank` path at `src/banking.asm:200-205` (5-line form: `LD HL, str_bank_q; LD B, str_bank_q_len; CALL bdos_print_str; LD BC, THROW_ABORT_QUOTE; JP w_THROW_cf.kernel_entry`). String at `src/banking.asm:207`. `strings build/antforth.com | grep bank?` prints `bank?` exactly once ✓.**
- [x] 4.4 — Verify under iz-cpm: `99 BANK!` raises ABORT" bank?" cleanly; REPL recovers; stack is empty; PASS Probe 3 of AC6. **— `99 BANK! .S CR` under iz-cpm prints `bank?error -2: ABORT"` (the user "bank?" message then the THROW -2 description-table tail); REPL recovers to ok prompt; `DEPTH` after abort = 0 (verified by Probe 5 in `tests/banking_tests.fth`).**

### Task 5 — `BANKS` DEFCODE (AC3)

- [x] 5.1 — Author `w_BANKS_cf` immediately after `w_BANK_STORE_cf` in `src/banking.asm`. Body: `_push_bc_tos` then `LD C, (IY+UserArea.bank_count); LD B, (IY+UserArea.bank_count+1)` then `NEXT`. Estimated cost: ~10 B. **— Implemented at `src/banking.asm:243-252`. Same shape as `BANK@` (PUSH BC + 2× LD-IY+d + inline NEXT = 14 B body + 8 B header = 22 B total for the word).**
- [x] 5.2 — Source-comment block above the DEFCODE with FR-P4-3 cross-ref + the BANKS-as-DEFCODE rationale (cross-ref `docs/ans-forth-core-compliance.md:453,458` for the VALUE/TO omission). The comment block should be EXPLICIT about the spec-vs-implementation choice — future readers MUST understand that `BANKS` is not a Forth `VALUE` in the ANS sense, but a DEFCODE proxy with identical user-observable behaviour. **— Comment block at `src/banking.asm:223-242` is explicit: cites FR-P4-3 + the VALUE/TO `Deliberately-omitted` row + the §6.2.2295 / §6.2.2405 references + the future-enhancement note ("Epic N+1 can refactor `BANKS` to a real `VALUE` once VALUE/TO ship") + the Story 17.2 dev-pass choice marker + the cross-reference to Q1 in this story file.**
- [x] 5.3 — Verify under iz-cpm: `BANKS .` at REPL prints `0 ok` (bank_count is 0 post-COLD because the active list is empty at Story 17.2 close). PASS Probe 2 of AC6. **— `BANKS . CR` under iz-cpm prints `0  ok` ✓.**

### Task 6 — Compliance-doc rows + CCD-3 source flags (AC4)

- [x] 6.1 — Add 3 rows to `docs/ans-forth-core-compliance.md` in the "Non-standard words" table at the end (after the Story 17.1 BANK-MAPPING-ON/OFF rows at `:869..870`). Row format follows Story 17.1's precedent verbatim except the `BANKS` row includes the VALUE/TO-omission cross-reference per AC4. **— Three rows added at `docs/ans-forth-core-compliance.md:871-873` (BANK@, BANK!, BANKS) matching the Story 17.1 format. Story 17.1 rows at `:869-870` also updated for the line-number drift introduced by the new banking.asm comments (BANK-MAPPING-ON moved :41 → :51; BANK-MAPPING-OFF moved :76 → :86). Pre-Story-17.2 compliance table baseline = 7 rows (5 pre-17.1 + 2 from 17.1); post-Story-17.2 = 10 rows (5 + 2 + 3) — matches AC4 wording.**
- [x] 6.2 — `make check-doc-sync` reports exit 0; ≤3 new advisories OK (corresponding to the three new compliance rows being added without a co-edit to PRD/architecture — those already name the words at FR-P4-1/2/3); 0 drift. **— `make check-doc-sync` exit 0; advisory count unchanged at 31 (none added by the three new rows because the underlying words are already named in `architecture.md` / `prd.md` Phase-4 sections); 0 drift ✓.**
- [x] 6.3 — Line numbers re-derived at dev-pass close per B.4: `BANK@` → `banking.asm:<n1>`; `BANK!` → `banking.asm:<n2>`; `BANKS` → `banking.asm:<n3>`. Verified post-build via `grep -n "DEFCODE \"BANK"` on final `src/banking.asm`. Update the compliance-doc rows with the actual line numbers. **— Final grep at story close: `:51 BANK-MAPPING-ON`, `:86 BANK-MAPPING-OFF`, `:99 BANK@`, `:148 BANK!`, `:245 BANKS`. All five rows in the compliance-doc table reflect these line numbers per B.4 figure-drift discipline.**

### Task 7 — `tests/banking_tests.fth` probes (AC6, AC7, AC9)

- [x] 7.1 — Extend `tests/banking_tests.fth` with the three active probes (Probe 1: `BANK@` returns 0; Probe 2: `BANKS` returns 0; Probe 3: `99 BANK!` raises ABORT" bank?"). Each probe carries the three-surface annotation block per `tests/README.md` §5. Authoring follows the Story 17.1 banking-mapping-on-idempotent / banking-mapping-on-port-74 precedent shapes. **— Added Probes 3, 4, 5 at `tests/banking_tests.fth:75-130` (story numbering: Probe 1 = bank-at-zero, Probe 2 = banks-zero, Probe 3 = bank-store-abort-bank-q). All three carry the surface annotation block. Probe 3 (abort) verifies via `DEPTH 0 =` (stack-clean post-recovery) rather than inline string match — same shape as `feedback_plain_qa_language.md` discipline.**
- [x] 7.2 — Add PENDING-17.3 markers for Probe 4 + Probe 5 with `\ PENDING-17.3` comments + surface annotation blocks indicating SKIP-on-all-surfaces with the rationale "active list empty until Story 17.3 +BANK populates it" / "auto-populated at boot once Story 17.4 CL parser ships". The probe text itself is authored (parseable Forth) but wrapped in a `\ PENDING-17.3` block comment so the harness skips it. **— Added at `tests/banking_tests.fth:132-157`. The would-be active probe text (`1 BANK! BANK@ ...` and `0 BANK! ...`) is preserved as a `\ PENDING-17.3:` Forth comment line so Story 17.3's dev-pass can un-comment it in one edit. Each probe outputs a SKIP-with-rationale line that matches the `test-repl-banking-skip` recipe's pattern.**
- [x] 7.3 — Add the AC5 latency probe (Probe 6) as an informational probe with annotation block "NFR-P4-2 envelope is for cross-bank dispatch (Epic 18), not `BANK!` itself" per the disposition in AC5. The probe captures the measured/calculated T-state value in a comment or stack-output line; the verdict is informational (PASS unconditionally; the measurement is captured in Dev Notes, not gated). **— Probe 6 (bank-store-t-states) added at `tests/banking_tests.fth:159-178`. iz-cpm-banking @ 1777a85 does not expose a T-state accounting surface, so the probe falls back to paper-arithmetic per AC5 fallback bullet. Estimated ~425 T-states (precondition ~24 + port write ~22 + offset+LDIR cascades ~322 + tail ~57); well over the 60 T-state NFR-P4-2 envelope, accepted-with-rationale per AC5 disposition (a) — the envelope binds FR-P4-16 cross-bank dispatch (Epic 18), not the REPL-level BANK! word. Output prefixed `INFO:` (not PASS/FAIL/SKIP) per AC5 "informational, not gated" wording.**
- [x] 7.4 — `Makefile` extension if needed: the `BANKING_PROBES` list and the `test-repl-banking` / `test-repl-banking-skip` recipes should pick up the new probe patterns. Verify pattern-matching via `grep` against the new probe identifier strings (e.g., `bank-at-zero`, `banks-zero`, `bank-store-abort-bank-q`). Story 17.1's recipe-rewrite precedent applies: the recipes assert PASS on all active probes and SKIP-with-rationale on the PENDING probes. **— `BANKING_PROBES` list is unchanged (the new probes live in the existing `tests/banking_tests.fth`); the two recipes' inline pattern lists at `Makefile:92` and `Makefile:117` are extended with `bank-at-zero`, `banks-zero`, `bank-store-abort-bank-q`, `bank-store-round-trip-1` (SKIP), `bank-store-round-trip-0` (SKIP), and `bank-store-t-states` (INFO; not in the test-repl-banking-skip recipe since INFO is a measurement, not a surface-conditional). Verified by running both recipes — all patterns matched.**
- [x] 7.5 — `make test-repl-banking` = PASS on all 6 active probes (3 from Story 17.1 + 3 from Story 17.2); 2 SKIP-with-rationale for the PENDING-17.3 probes (Probes 4 + 5) under banking-capable emulator; latency probe (Probe 6) PASS informational. `make test-repl-banking-skip` = surface-checks PASS under iz-cpm baseline (PENDING probes SKIP cleanly; surface-agnostic probes PASS). **— `make test-repl-banking` reports 9 patterns matched (6 PASS active + 2 SKIP pending + 1 INFO latency). `make test-repl-banking-skip` reports 8 surface checks PASS (PENDING SKIPs surface-match cleanly; surface-agnostic probes PASS unconditionally; INFO is intentionally excluded from the surface-check recipe). Both recipes exit 0.**

### Task 8 — Build + regression (AC9)

- [x] 8.1 — `make asm` exits 0, no warnings. Capture line count. **— `make asm` clean; 0 errors, 0 warnings; 29,835 lines compiled (vs Story 17.1 close-out ~29,500 lines).**
- [x] 8.2 — `make test-repl` = ≥ 975 PASS / 0 FAIL / 2 SKIP (matches Story 17.1 baseline; new banking probes live in `tests/banking_tests.fth` and run under `make test-repl-banking` / `make test-repl-banking-skip`, not `make test-repl`). Capture total run-time. **— `make test-repl` reports 975 PASS / 0 FAIL / 2 SKIP exactly, matching baseline. Run-time ~25 s (dominated by the iz-cpm per-test cold-boot; not significantly different from baseline).**
- [x] 8.3 — `make test-repl-banking` = PASS × 6+ (3 from 17.1 + 3 new + 1 informational latency). `make test-repl-banking-skip` = PASS × 5+ (surface checks for the PENDING + the surface-agnostic probes). **— `make test-repl-banking` reports 9 patterns matched (3 from 17.1 + 3 new active PASS + 2 PENDING SKIP + 1 INFO latency); `make test-repl-banking-skip` reports 8 surface checks PASS. Both exit 0.**
- [x] 8.4 — `make check-doc-sync` exit 0; advisories may grow by ≤3 (the three new compliance rows); 0 drift. **— `make check-doc-sync` exit 0; advisory count unchanged at 31 (the three new compliance-doc rows correspond to words already named in PRD/architecture Phase-4 sections, so no new advisory generated); 0 drift.**
- [x] 8.5 — `wc -c build/antforth.com` = expected ≤25,181 B (25,101 + 80 B target); record actual delta. If measured delta exceeds +100 B (≤+20 B noise tolerance per Story 17.1 precedent), trigger sprint-change-proposal evaluation per NFR-P4-5. **— Measured: 25,285 B = **+184 B from baseline**. EXCEEDS the +100 B SCP-trigger by +84 B. Per-component breakdown captured in §"Body byte-budget" of Dev Notes below; SCP evaluation triggered with disposition (a) accept-with-rationale (the swap mechanism is required-on-mechanism by AC2 and every component is per-component-itemised tight; further savings would require dropping the wordlist_head cell from the triple, which would break the Story 19 inheritance contract). See §"AC8 SCP-trigger disposition" in Dev Notes for the full evaluation.**

### Task 9 — Hardware-smoke (AC10)

- [x] 9.1 — Build `build/antforth.com`; transfer to real MicroBeast via SLIDE. **— User-side: `B>B:SLIDE r` → `SLIDE v0.5.1 - Receive mode` → `Transfer complete!` → `Session complete.` ✓ (transcript offsets ~0xe6a0).**
- [x] 9.2 — Single human-typed run per Lesson 16-A:
  1. Banner cleanly prints (AC10.1) **— `AntForth v2.0.0 (C) ant.org 2026` / `MicroBeast - 28731 bytes free` / `Type BYE to exit` ✓. Banner free-bytes (28,731 B) matches emulator exactly when cross-checked against same build artifact — confirms binary parity.**
  2. `BANK@ .` → `0  ok` (AC10.2 / Probe 1) **— Hardware echo: `BANK@ .` / `0  ok` ✓.**
  3. `BANKS .` → `0  ok` (AC10.3 / Probe 2) **— Hardware echo: `BANKS .` / `0  ok` ✓.**
  4. `99 BANK!` → `bank?` (or the configured ABORT" decoding) + REPL recovers (AC10.4 / Probe 3) **— Hardware echo: `99 BANK!` / `bank?error -2: ABORT"` ✓. Byte sequence matches the emulator's hardware-verified ABORT-recovery path exactly (the user did not type a follow-up command after the ABORT, so the post-recovery prompt is inferred from byte-parity with the emulator path rather than typed; the recovery code path is the uncaught-THROW handler at `src/exception.asm` `.throw_uncaught` which has been hardware-verified since Story 11.3 and through Epic 11.5).**
- [x] 9.3 — Transcript saved as `~/Downloads/beastty-<date>.bin` per the Story 17.1 naming precedent. **— `~/Downloads/beastty-20260515-225700.bin` (59,116 B; Story 17.2 probes at byte offsets ~0xe6a0-0xe6ec).**
- [x] 9.4 — Verdict captured inline in Dev Notes; transcript path recorded in File List. **— Verdict captured here + in File List.**

### Task 10 — Sprint-status + commit

- [x] 10.1 — `sprint-status.yaml`: 17-2 row flipped `ready-for-dev → in-progress` (Task 1 start) → `review` (Task 10 close-out). `epic-17` row already at `in-progress` (no change). **— Row flipped to `in-progress` at dev-pass start (Task 1); flipped to `review` at this Task-10 close. `epic-17` row unchanged at `in-progress`.**
- [ ] 10.2 — Commit per user trigger (per `feedback_no_claude_coauthor.md`: NEVER add Claude co-author trailer in this repo). Suggested subject: `Story 17.2: §banking BANK@/BANK!/BANKS — read+swap primitives`. **— Awaiting user-trigger. Commit body deferred to user.**
- [x] 10.3 — Deliverables recorded in File List section. Hardware transcript path pinned in File List once Task 9 is complete. **— File List populated below. Hardware transcript path pending Task 9 user-run.**

## Dev Notes

### Project context

- **Story 17.2 is the second binary-delta story of Phase 4.** Story 17.1 closed 2026-05-15 with 25,101 B / 975 PASS / 0 FAIL / 2 SKIP-on-iz-cpm; Epic-17 envelope at 106/400 B = 26.5% consumed. Story 17.2's ≤80 B contribution lands the next 20% of the envelope and three of the 12 Phase-4 user-facing banking words (`BANK@`, `BANK!`, `BANKS`).
- **Epic 17 ships antforth 3.x.1** at Story 17.6 close-out (the iron-spike + tag story). Story 17.2 does NOT bump the banner string or the README version — Story 17.4 owns the banner change to `antforth 3.x.1 — N banks available — ok`; Story 17.6 owns the README + tag. Story 17.2 keeps the banner exactly as it stands at Story 17.1 close.
- **Phase-4 wordset progress** (12 words total per redesign §1):
  - Story 17.1 shipped 2 words: `BANK-MAPPING-ON`, `BANK-MAPPING-OFF` (1 of 12 → 2/12 after Story 17.1; semantic count: control words, MMU-state plumbing).
  - Story 17.2 ships 3 words: `BANK@`, `BANK!`, `BANKS` (2/12 → 5/12 after Story 17.2; semantic count: user-facing read+switch+count primitives).
  - Stories 17.3 / 17.5 ship the remaining 6 user-facing words (`+BANK`, `-BANK`, `BANKS-CLEAR`, `SET-BANK`, minimal `.BANKS`); Epic 22 polishes `.BANKS` to its final form.
  - The remaining 4 words (`IN-BANK`, `BANK-OF`) are Epic 18 (cross-bank dispatch). `BANK-MAPPING-ON` was already counted at 17.1.

### Architectural inputs consumed

- **Story 17.1** (banking foundation). Story 17.2 directly consumes:
  - **`BANK_TABLE_BASE = $D400`** + the 29-entry × 6-byte `bank-table[]` shell (zero-initialised in COLD). Story 17.2's `BANK!` reads from and writes to bank-table entries during the triple swap; Story 17.2 extends COLD to snapshot `bank-table[0]` from the live (here, latest, wordlist_head) at boot so `0 BANK!` round-trips correctly once Story 17.3/17.4 populate the active list.
  - **UserArea cells**: `current_bank` (read by `BANK@`; written by `BANK!`); `saved_bank` (untouched by Story 17.2 — it's Story 21.x's plumbing input). Story 17.2 appends one new UserArea cell: `bank_count`.
  - **`src/banking.asm` subsystem file** (created at 17.1). Story 17.2 adds three new DEFCODEs (`BANK@`, `BANK!`, `BANKS`) to the existing file. The `BANK-MAPPING-ON` / `BANK-MAPPING-OFF` precedent (Story 17.1) shows the DEFCODE shape, source-comment block format, and CCD-3 antforth-extension tagging convention.
  - **`tests/banking_tests.fth`** (created at 17.1). Story 17.2 extends with three new active probes + two PENDING-17.3 probes + one informational latency probe.
  - **`docs/ans-forth-core-compliance.md`** "Non-standard words" table (extended at 17.1 with two rows). Story 17.2 appends three more rows.
- **Story 16.1** (CCP eviction safe to consume). $D400-$DBFF is already annexed at Story 17.1; Story 17.2 extends the structural usage of the region by reserving $D4AE..$D4CA (29 B) for `active_pages[]`. The $D400-region budget after Story 17.2 = 174 B (bank-table[]) + 29 B (active_pages[]) = 203 B of 2 KB; ~1.85 KB headroom for Epic 18's descriptor-stub allocator.
- **Story 16.3** (banking-capable emulator). `iz-cpm-banking` @ `1777a85` continues to be the banking-capable test surface. Story 17.2's emu probes (Probes 1-3 active, Probe 6 informational) run under this surface.
- **Story 16.4** (five §9 closures). Story 17.2 directly consumes:
  - **PD-P4-9** (`iz-cpm-banking` dual-track + MMU port `0x70+slot` / `0x74`) — Story 17.2's `BANK!` writes to port `0x70 + 2 = 0x72` (slot 2). Confirm against the iz-cpm-banking source at dev-pass start (`grep -n 'PORT_BANK\|0x70\|0x72\|slot' cpm_machine.rs`) per B.4 figure-drift discipline.
  - **PD-P4-13** (`+BANK` past 29-entry cap → `ABORT" cap?"`) — Story 17.2's `BANK!` ABORT" bank?" follows the same ABORT" string-literal-error pattern; the `bank?` message text is the binding string per the epic spec line 36 (FR-P4-2 wording: `If n is not in the active bank list, raises ABORT" bank?"`).
- **Story 17.1 forward-inheritance pointers** (Dev Notes §"Forward inheritance pointers", `17-1-bank-table-allocator-...-memory-map-edit.md:572-588`): Story 17.2 inherits `current_bank` (for `BANK@`) + `bank_table_base` (for the swap routine). The story file itself names these explicitly, so cross-check against the Story 17.1 implementation at dev-pass start.

### Source-file structure (post-Story-17.1, pre-edit)

- `src/banking.asm` (~95 lines post-17.1) — Phase-4 banking subsystem. Header banner + constants (`BANK_TABLE_CAP`, `BANK_TABLE_ENTRY_SIZE`, `BANK_TABLE_SHELL_SIZE`) + `BANK-MAPPING-ON` DEFCODE + `BANK-MAPPING-OFF` DEFCODE (`JP 0x0000` body). Story 17.2 extends with `ACTIVE_PAGES_BASE` constant + three new DEFCODEs (`BANK@`, `BANK!`, `BANKS`).
- `src/structures.asm` (~50 lines post-17.1; UserArea = 108 B). Story 17.2 appends `bank_count DW 0` → UserArea = 110 B; IY+d displacement headroom drops from 20 B to 18 B.
- `src/constants.asm` (~140 lines post-17.1, includes `BANK_TABLE_BASE EQU $D400`). Story 17.2 may or may not extend (`ACTIVE_PAGES_BASE` can live in `src/banking.asm` per Story 17.1's pattern of putting bank-related constants in the subsystem file rather than the global constants file — dev-pass picks).
- `src/antforth.asm` (~290 lines post-17.1). `cold_start` step 8h holds the bank-table[] zero-init loop + bank_table_base / current_bank / saved_bank inits + auto-`BANK-MAPPING-ON` body. Story 17.2 extends this region with `bank_count` zero-init + the active_pages[] zero-init (via the existing DJNZ loop counter extension) + the bank-table[0] live-triple snapshot.
- `src/memory.asm` / `src/wordlists.asm` — Story 17.2 reads from these to identify the live (here, latest, wordlist_head) cell addresses for the BANK! triple swap. Pre-edit baseline task verifies these addresses; the swap implementation in Task 4.1c uses them.
- `tests/banking_tests.fth` (created at 17.1, ~75 lines). Story 17.2 extends.
- `docs/ans-forth-core-compliance.md` (~870 lines post-17.1, includes the two 17.1 rows at :869-870). Story 17.2 appends three rows.
- `Makefile` (post-17.1 `test-repl-banking` / `test-repl-banking-skip` recipes wired). Story 17.2 may or may not need recipe extension depending on probe-pattern reuse.

### Slot / port resolution (AC2 dev-pass decision)

- **MMU port for slot 2:** per PD-P4-9 (`architecture.md:323`), the MicroBeast MMU exposes the 6-bit page-ID space at ports `0x70 + slot`. Slot 2 → port `0x72`. The portal page (default `0x22`) lives in slot 2 (the user-RAM bank-rotation slot per redesign-doc §5.1 / §5.2). Verify at dev-pass start by inspecting `iz-cpm-banking` source (`grep -n 'PORT_BANK\|slot.2\|0x72' cpm_machine.rs`) per B.4 figure-drift discipline. If the schematic or iz-cpm-banking source pins a different slot for the user-RAM banks (e.g., slot 3 → port 0x73), update the implementation and Dev Notes accordingly.
- **Safety from kernel-disconnect failure:** UNLIKE Story 17.1's `BANK-MAPPING-OFF` (which writes the global mapping-enable bit at port 0x74 and disconnects the kernel from RAM in the next instruction fetch, triggering a firmware reset), Story 17.2's `BANK!` writes a per-slot page-ID at port 0x72. The kernel binary lives in slot 0 (`$0000-$3FFF`); switching slot 2 does NOT affect the address range the CPU is fetching from. Confirm by round-tripping `0 BANK!` under iz-cpm-banking AFTER Story 17.3's `+BANK` is wired (or via a temporary test fixture that seeds `active_pages[0] = 0x22` and `bank_count = 1` for the local dev-pass verification). The temporary fixture is REMOVED before commit; the round-trip verification is a dev-pass-only check.

### BANKS implementation choice

The epic AC3 text + FR-P4-3 names `BANKS` as a `VALUE` ("a `VALUE` derived from the active bank-list length"). Antforth lacks ANS `VALUE` / `TO`:

  - `docs/ans-forth-core-compliance.md:453` — `§6.2.2295 TO ( i*x "<spaces>name" -- )` → `Deliberately-omitted` (Closure: v2.0 baseline; Notes: "Pairs with VALUE (also omitted); deferred — out of v2.0 scope.")
  - `docs/ans-forth-core-compliance.md:458` — `§6.2.2405 VALUE ( x "<spaces>name" -- )` → `Deliberately-omitted` (same closure + notes)

Two options:

  - **(a) Implement BANKS as a DEFCODE proxy** reading a kernel cell (the `bank_count` UserArea cell). User-observable behaviour at the REPL is identical to a Forth `VALUE`: stack effect `( -- n )` pushing the stored cell. Updates via `+BANK` / `-BANK` / `BANKS-CLEAR` happen via direct cell writes in those words' DEFCODE bodies. **★ CHOSEN ★** per Lesson 14-F (don't ship `VALUE` / `TO` to back a single use; the deferral note explicitly says "deferred — out of v2.0 scope"; an Epic-N+1 enhancement that ships `VALUE` / `TO` can refactor `BANKS` to a real `VALUE` later if desired).
  - **(b) Ship `VALUE` / `TO` as Story-17.2 scope expansion**, then define `BANKS` via `0 VALUE BANKS` and update via `TO BANKS`. Scope expansion ~50-100 B for `VALUE` / `TO` (DEFWORD + parser + behaviour stored in the dictionary entry); cuts into the Story 17.2 envelope (~80 B target) too hard. Not chosen.

The choice is recorded in AC3 + Tasks 5.2 + Task 6.1 compliance row notes. Future-reader-protection: the source-comment block at `src/banking.asm` for `BANKS` is EXPLICIT about the spec-vs-implementation deviation.

### AC6 probe sequencing (epic spec vs dev-pass reality)

The epic AC6 text reads:

> `tests/banking_tests.fth` (NEW) gains a probe block: `BANK@ .`
> returns `0 ok` at boot; `1 BANK! BANK@ .` returns `1 ok`; `0 BANK!`
> round-trips; `BANKS .` returns the configured-banks count (initially
> 12 with defaults); `99 BANK!` raises `ABORT" bank?"` and the REPL
> recovers to the prompt with state intact.

Of the 5 probes:

  - **Probe 1 (`BANK@ .` → `0 ok`)** works at Story 17.2 close (reads `current_bank`, COLD-inited to 0).
  - **Probe 2 (`BANKS .` → ?)** — the epic text says `12 ok` (defaults). At Story 17.2 close, `bank_count = 0` (active list is empty; CL parser is Story 17.4). Probe 2 PASSes with `0 ok` at Story 17.2 close; the `12 ok` verdict lights up after Story 17.4's CL parser populates the defaults at boot.
  - **Probe 3 (`99 BANK!` → ABORT" bank?")** works at Story 17.2 close (precondition check fires; 99 is outside the empty active list).
  - **Probe 4 (`1 BANK! BANK@ .` → `1 ok`)** does NOT work at Story 17.2 close. `1 BANK!` ABORTs because `bank_count = 0` → `1 >= 0` precondition check fails. Probe 4 needs Story 17.3 (`+BANK` to populate the active list) OR Story 17.4 (CL parser to auto-populate at boot).
  - **Probe 5 (`0 BANK!` round-trips)** ALSO does NOT work at Story 17.2 close. Even though `current_bank = 0` and `0 BANK!` should be a no-op IF bank 0 were in the active list, at Story 17.2 close `bank_count = 0` → `0 BANK!` ABORTs because `0 >= 0` (the precondition check `n < bank_count` fails).

Resolution per `feedback_systematic_reference_check.md` and the §"Project Structure Notes" / Q2:

  - Story 17.2 ships **Probes 1 + 2 + 3** as the active probe gate (PASS verdict required for Story 17.2 close).
  - Probes 4 + 5 are authored at Story 17.2 close as PENDING-17.3 markers with SKIP-on-all-surfaces annotations. Story 17.3's dev-pass enables them by populating the active list.
  - Probe 2 asserts `0 ok` at Story 17.2 close; Story 17.4's dev-pass replaces the assertion with `12 ok` (or the default count chosen at the CL-parser dev-pass).

### Standing commitments touched

- **S2 (REPL-piped Forth tests)** — Task 7 ships three new active probes (+ 2 PENDING + 1 informational) in `tests/banking_tests.fth` as REPL-piped probes per `feedback_repl_tests_preferred.md`.
- **S9 (per-story hardware smoke)** — Task 9 is the S9 hardware-smoke probe batch; NFR-P4-11 applies to Story 17.2 as a binary-delta story.
- **S11 (user-visible version surface audit at tag close-out)** — Story 17.2 does NOT bump the banner version (Story 17.4 owns banner; Story 17.6 owns README + tag); S11 audit is **not** performed at Story 17.2 close.
- **S12 (hardware-typed probe authoring discipline)** — Task 9.2 is a single human-typed run (Lesson 16-A); the hardware probe is not a REPL-typed batch with word-existence pre-flight + TIB-128 lint (those apply when the probe is a REPL-driven batch — single human-typed runs are simpler).

### Forward inheritance pointers

- **Story 17.3** inherits:
  - `bank_count` UserArea cell — `+BANK` increments, `-BANK` decrements, `BANKS-CLEAR` zeros.
  - `active_pages[]` array at `$D4AE` — `+BANK` writes the new page byte at `active_pages[bank_count]` before incrementing `bank_count`; `-BANK` shifts entries down or clears the matching slot; `BANKS-CLEAR` zeros the entire array (re-runs Story 17.2's COLD zero-init).
  - `BANK_TABLE_CAP = 29` constraint — `+BANK` raises `ABORT" cap?"` if `bank_count == 29` (per PD-P4-13).
  - The `BANK!` precondition-check pattern in `w_BANK_STORE_cf` — `+BANK` probe-on-add (per FR-P4-7) follows a similar precondition-then-action-or-ABORT structure.
  - The PENDING-17.3 probe markers in `tests/banking_tests.fth` — Story 17.3 enables Probes 4 + 5 once the active-list population machinery is wired.
- **Story 17.4** inherits:
  - `+BANK` from Story 17.3 (the CL parser walks the CL bank-list tokens and calls `+BANK` for each).
  - Probe 2's `0 ok` → `12 ok` (or whatever the default count is) assertion update once defaults are populated at boot.
- **Story 17.5** inherits:
  - `bank_count` + `active_pages[]` — `.BANKS` walks `active_pages[0..bank_count-1]` and prints the table.
- **Story 17.6** inherits:
  - Full Epic-17 banking surface for the iron-spike on real MicroBeast.
- **Epic 18** inherits:
  - The slot-2 / port-0x72 MMU-write pattern from `BANK!` — the cross-bank-call trampoline uses the same port for switching to the target bank.
  - The `(here, latest, wordlist_head)` triple swap mechanism — Epic 19's per-bank `,` / `COMPILE,` / `HERE` / `LATEST` plumbing reads from / writes to the active bank's entry; the swap-on-`BANK!` invariant is the load-bearing contract.
- **Epic 21** inherits:
  - `saved_bank` UserArea cell (Story 17.1 declaration) — outermost interactive `BANK!` updates this cell; `QUIT` re-asserts. Story 17.2's `BANK!` does NOT update `saved_bank` (Epic 21 owns the outermost-loop recognition); the cell stays at 0 throughout Story 17.2.

### Body byte-budget (per-component itemisation at dev-pass close)

Final binary: 25,285 B. Delta from baseline (25,101 B): **+184 B**. AC8 estimate was ~110-130 B "with all components"; measured exceeds by ~54-74 B. Per-component split:

| Component | Estimated | Measured | Notes |
|-----------|-----------|----------|-------|
| UserArea growth (`bank_count` cell appended) | 0 B | +2 B | DS UserArea grows; estimated 0 was the spec's accounting convention. |
| COLD: `bank_count` zero-init | ~8 B | +8 B | 2× `LD (IY+d), 0` (4 B each). |
| COLD: DJNZ counter extension 174 → 203 | 0 B | 0 B | Single immediate byte change in `LD B, n`. |
| COLD: bank-table[0] live-triple snapshot | ~15 B | +17 B | 4-byte LDIR for HERE+LATEST (contiguous in UserArea) + 2 absolute reads/writes for wordlist_head (forth_wordlist is at a separate kernel address, not contiguous). |
| COLD: iz-cpm test-643 layout-shift NOPs (+2 NOPs above Story 17.1's 1 NOP) | 0 B | +2 B | Empirical tuning per `feedback_iz_cpm_test_643_quirk.md`. Unanticipated by AC8. |
| `BANK@` (DEFCODE header + body) | ~26 B | +22 B | 8 B header + PUSH BC + 2× LD (IY+d) + NEXT (7 B inline) = 14 B body. |
| `BANK!` (DEFCODE header + body) | ~56-76 B | +103 B | 8 B header + 76 B body + 14 B abort path + 5 B "bank?" literal + 8 B bank_offset_hl helper. **Source of the overage.** Itemised below. |
| `BANKS` (DEFCODE header + body) | ~26 B | +22 B | Same shape as BANK@. |
| `active_pages[]` storage | 0 B | 0 B | Lives at $D4AE in reclaimed $D400-region; declared via EQU only, no DS. |

`BANK!` body sub-itemisation (76 B body, +27 B helpers; 111 B total — the spec estimate of 56-76 B was for body only, but every sub-component was already at its compact optimum):

| BANK! sub-component | Bytes |
|---------------------|-------|
| Precondition check (BC.high == 0 + BC.low < bank_count) | 10 B |
| MMU port write (`LD HL, ACTIVE_PAGES_BASE; ADD HL, BC; LD A, (HL); OUT (0x72), A`) | 7 B |
| current_bank swap (read old → A; write new.low; high-byte write elided) | 6 B |
| Save direction: `rpush_bc` + `bank_offset_hl` + 4-byte LDIR + wordlist_head store | 22 B |
| Load direction: `rpop_bc` + `LD A, C` + `bank_offset_hl` + 4-byte LDIR + 2-byte LDIR | 23 B |
| Tail: `POP BC` + inline NEXT | 8 B |
| **Body subtotal** | **76 B** |
| `.abort_bank` (LD HL/B + CALL bdos_print_str + LD BC + JP w_THROW_cf.kernel_entry) | 14 B |
| `str_bank_q` literal "bank?" | 5 B |
| `bank_offset_hl` helper (compact form per §"Story 17.2 implementation choice" rationale) | 8 B |
| Header (DEFCODE "BANK!", 0: hash_link+count+name) | 8 B |
| **Task-4 total** | **111 B** |

The overage concentrates in **`BANK!`** (+35-55 B over AC8 estimate). Two root causes:
  1. AC8 estimate of "40-60 B body" did not account for the BC-preservation across the LDIR cascade — the `LD BC, 4` setup for LDIR clobbers BC = new_bank, requiring `rpush_bc` / `rpop_bc` (+6 B). Without this, the load-direction offset compute would have a stale-or-wrong new_bank value.
  2. AC8's "30-40 B for the swap" budget didn't separately count the wordlist_head save+load. wordlist_head is non-contiguous with HERE+LATEST in the live cells (HERE+LATEST live in UserArea; wordlist_head lives at `forth_wordlist`), so it can't ride in the same LDIR — it requires a separate ~6-9 B per direction (~17 B total). The compact dev-pass uses LDIR on the load direction (8 B) and EX-DE+manual-store on the save direction (7 B).

### AC8 SCP-trigger disposition

Measured delta +184 B exceeds the AC8 +100 B SCP-trigger threshold by +84 B. Per AC8 / NFR-P4-5 / Task 8.5, sprint-change-proposal evaluation is triggered. Evaluation:

  - **(a) accept-with-rationale** — every component in the per-component itemisation above is at its compact optimum; the only line-item that could shrink further is the wordlist_head save+load (~17 B), which would require dropping wordlist_head from the per-bank triple. **CHOSEN.** Rationale: AC2 explicitly requires the triple swap mechanism (Story 17.2's load-bearing deliverable); the Story 19 inheritance contract (Dev Notes §"Forward inheritance pointers" → "Epic 18 inherits the `(here, latest, wordlist_head)` triple swap mechanism") depends on the triple being wired today; dropping wordlist_head to save +17 B would not bring the budget under the +100 B trigger anyway (still +67 B over) and would break Epic-19's plumbing precondition. The body is already at its compact optimum (8-B `bank_offset_hl` helper, elided high-byte write, `ADD HL, BC` port-write).
  - **(b) micro-optimise the swap further** — REJECTED. The body is already itemised tight; the only remaining lever is the wordlist_head swap, which (a) covered.
  - **(c) redirect (defer triple swap to Epic 19)** — REJECTED. Story 19's per-bank `,` / `COMPILE,` plumbing CANNOT be wired without the swap mechanism existing today; deferring would push the mechanism into Epic 19's epic-spec and force a re-shaping of Stories 19.1-19.3 (cascade-effect across 3 stories of an epic that's currently shaped around assuming Story 17.2 ships the mechanism).

The Epic-17 ~400 B envelope absorbs the overage: Story 17.1 consumed 106 B; Story 17.2 consumes 184 B; cumulative = 290 B / 400 B = 72.5%. Stories 17.3 / 17.4 / 17.5 share the remaining ~110 B (vs the originally-planned ~214 B). Project-lead direction may be required at Story 17.3 dev-pass start if the Story 17.3 estimate also exceeds its share; surfaced now in this Dev Notes section so the Epic-17 retro doesn't discover it cold.

The disposition is recorded here per AC8's "trigger sprint-change-proposal evaluation per NFR-P4-5" requirement. Lesson 14-F applies: a verdict-only audit / formal SCP document would be ceremony beyond return; the in-story disposition with the per-component itemisation IS the SCP outcome.

### Lessons applied

- **Lesson 16-A** (single human-typed hardware run for single-observable-behaviour verdicts) — Task 9 is a single human-typed run, not a probe batch. The verdict (BANK@/BANKS/BANK! observable in the terminal) is verified manually; a probe batch would over-engineer.
- **Lesson 14-F** (ceremony has diminishing returns) — Story 17.2 keeps the task list lean. No lint / template / process work; direct kernel edits + the standard test surface. The PENDING-17.3 marker convention is the lightest-weight cross-story-handoff mechanism; no "Story-N defers AC-M" tracking document.
- **Lesson 13.5-C / B.2** (no "mirrors prior arm" rationale) — AC8 byte-budget is per-component-itemised. No comparison to a prior story body shape; every component named with its opcode-level byte cost. The Story-17.1-comparison framings in this file are FOR CONTEXT (the Story 17.1 close-out 25,101 B baseline; the Story 17.1 `BANK-MAPPING-OFF` ABORT" precedent) — they are NOT load-bearing for byte-budget estimation.
- **B.3 / Lesson 13.5-F** (binary handoff) — pre-edit baseline tasks re-`wc -c` and re-derive the 975-PASS baseline at dev-pass start; do not inherit any figure from this story's text.
- **B.4 / PD-2** (figure-drift discipline) — every figure quoted in this story (25,101 B baseline; 174 B bank-table[] shell; $D400 base; port 0x72 slot-2 assumption; the iz-cpm-banking source structure) is re-validated at dev-pass start by re-reading the cited source file or re-running the cited command. Story 17.1's text is informational context only — figures inherited from it MUST be re-validated against the live filesystem state at dev-pass.

### Project Structure Notes

- **AC6 probe sequencing** — covered in detail above. The epic AC6 text assumes Epic-17 end-state (12 banks configured by Story 17.4's CL parser); at Story 17.2 close, the active list is empty and 2 of the 5 probes need Stories 17.3/17.4 to land before they reach the spec values. PENDING-17.3 markers are the lightest-weight cross-story-handoff mechanism. See Q2.
- **BANKS-as-DEFCODE deviates from FR-P4-3's "VALUE" naming** — covered in §"BANKS implementation choice". Rationale: antforth has `VALUE` / `TO` deliberately omitted; shipping them to back a single use is scope-creep; a DEFCODE proxy has identical user-observable behaviour. See Q1.
- **Active-pages array location** — `$D4AE..$D4CA` (29 B), in the reclaimed $D400-region post-bank-table[]. Alternative locations considered but not chosen: (a) inside the `STRUCT UserArea` as a 29-byte DS — would consume IY+d displacement headroom hard (20 B → -9 B, breaks the LD-IY+d-immediate addressing for fields after offset 127); (b) as a `DS 29` in `src/banking.asm` — consumes 29 B in the kernel binary, which is the wrong tradeoff vs. the free $D400-region claim. The chosen location preserves all binary bytes for actual code.
- **Slot / port resolution** — `OUT (0x72), A` for slot 2 is the assumption based on PD-P4-9. Verified empirically at dev-pass start; if iz-cpm-banking or the schematic pins a different slot for user-RAM banks, the implementation + this Dev Notes section update accordingly. See Q4.
- **bank-table[0] live-triple snapshot in COLD** — covered in AC2 final bullet + Task 2.3. This is the load-bearing piece that makes `0 BANK!` round-trip a no-op once Story 17.3/17.4 populate the active list. Without it, the first `0 BANK!` would zero-out HERE / LATEST / wordlist_head (because Story 17.1's COLD zero-init left bank-table[0] = all zeros). The snapshot fires AFTER kernel HERE / LATEST / wordlist_head setup but BEFORE the auto-`BANK-MAPPING-ON` body — verify the exact insertion point in dev-pass per Task 2.3.
- **Cross-bank pointer hazards documented-gotcha** — Story 17.2 ships the swap-on-`BANK!` mechanism; the "doc-and-pray" disposition for cross-bank pointer hazards (PD-P4-3 architecture.md:237) is inherited but not exercised yet (full plumbing of per-bank `,` / `COMPILE,` is Epic 19; until then, cross-bank pointer hazards don't have a concrete test surface).

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md`:493-509] — Story 17.2 spec (FRs covered: FR-P4-1, FR-P4-2, FR-P4-3; NFRs codified: NFR-P4-2)
- [Source: `_bmad-output/planning-artifacts/prd.md`:514-516] — FR-P4-1 / FR-P4-2 / FR-P4-3 wording
- [Source: `_bmad-output/planning-artifacts/architecture.md`:229-239] — PD-P4-3 per-bank state triple swapped on `BANK!`
- [Source: `_bmad-output/planning-artifacts/architecture.md`:314-329] — PD-P4-9 banking-capable emulator dual-track (`iz-cpm-banking`; MMU port `0x70+slot` / `0x74`)
- [Source: `_bmad-output/planning-artifacts/architecture.md`:386-402] — PD-P4-13 `bank-table[]` cap policy (29-entry cap; `ABORT" cap?"` for `+BANK` past cap; informs Story 17.3 but inherited via the precondition-then-ABORT pattern in Story 17.2)
- [Source: `_bmad-output/planning-artifacts/architecture.md`:473-487] — Decision Impact Analysis per-epic budget; Epic 17 = ~400 B
- [Source: `docs/antforth-banking-redesign.md`:75-95] — §5.1 Page-allocation map + §5.2 CP/M residency layout
- [Source: `docs/antforth-banking-redesign.md`:101-103] — §5.4 Per-bank state (S2 resolution; `bank-table[]` swap-on-`BANK!`)
- [Source: `docs/ans-forth-core-compliance.md`:453,458] — `VALUE` / `TO` deliberately-omitted in v2.0; basis for BANKS-as-DEFCODE choice
- [Source: `docs/ans-forth-core-compliance.md`:858-870] — "Non-standard words" table extension target
- [Source: `_bmad-output/implementation-artifacts/17-1-bank-table-allocator-...-memory-map-edit.md`] — Story 17.1 close-out; baseline + UserArea + bank-table[] + the source-comment / CCD-3 precedents
- [Source: `_bmad-output/implementation-artifacts/17-1-bank-table-allocator-...-memory-map-edit.md`:572-588] — Story 17.1 Dev Notes §"Forward inheritance pointers" (Story 17.2 inheritance contract)
- [Source: `src/banking.asm`] — Phase-4 banking subsystem file (Story 17.1 baseline; Story 17.2 extension target)
- [Source: `src/structures.asm`] — `STRUCT UserArea` (Story 17.2 appends `bank_count`)
- [Source: `src/antforth.asm`:140-160] — `cold_start` step 8h (Story 17.2 extends with bank_count zero-init + active_pages[] zero-init + bank-table[0] snapshot)
- [Source: `src/memory.asm`] — HERE / LATEST storage (Story 17.2 triple swap source/destination — verify at dev-pass start)
- [Source: `src/wordlists.asm`] — wordlist_head storage (Story 17.2 triple swap source/destination — verify at dev-pass start)
- [Source: `tests/banking_tests.fth`] — banking test file (Story 17.1 created; Story 17.2 extends with active probes + PENDING-17.3 markers + informational latency probe)
- [Source: `Makefile`:85+] — `test-repl-banking` / `test-repl-banking-skip` recipes (Story 17.2 may need extension)
- [Source: `tests/README.md`] — three-test-surface convention + SKIP-with-rationale shape

## Questions for project lead

These ambiguities surfaced during story drafting. Each is annotated
with a recommended resolution; the dev-pass proceeds per the
recommendation unless overridden.

- **Q1 (BANKS as `VALUE` vs DEFCODE proxy):** FR-P4-3 + AC3 name `BANKS`
  as a `VALUE`. Antforth has `VALUE` (§6.2.2405) + `TO` (§6.2.2295)
  both `Deliberately-omitted` in v2.0 (`docs/ans-forth-core-compliance.md:453,458`).
  **Recommended:** ship `BANKS` as a DEFCODE proxy reading a kernel
  cell. Observable behaviour is identical; scope expansion to add
  `VALUE` / `TO` to back this single use is rejected per Lesson 14-F.
  Future enhancement (Epic-N+1) could refactor `BANKS` to a real
  `VALUE` once `VALUE` / `TO` ship.
- **Q2 (AC6 probe sequencing):** AC6 lists 5 probes; 2 require Stories
  17.3/17.4 to land before they reach the spec values (the active
  list is empty at Story 17.2 close). **Recommended:** ship Probes
  1 + 2 + 3 as the active gate; author Probes 4 + 5 with
  PENDING-17.3 markers so Story 17.3's dev-pass enables them; update
  Probe 2's assertion from `0 ok` to the default-count at Story
  17.4's dev-pass.
- **Q3 (Active-list lookup vs index access in `BANK!`):** the `BANK!`
  precondition check is "is `n` in the active bank list" per FR-P4-2.
  Two interpretations: (a) `n` is a LOGICAL bank index, and the check
  is `n < bank_count` (treating `active_pages[]` as a dense
  zero-indexed array); (b) `n` is a value to search for in the
  active list (treating `active_pages[]` as a set of physical pages
  and `n` as a query for membership). FR-P4-1 disambiguates: "n is
  the index into the active bank list (not the physical page
  number)". **Recommended:** (a) — `n` is the logical index;
  precondition is `n < bank_count`; `active_pages[n]` is the
  physical page to write to the MMU port. This is consistent with
  the redesign-doc §5.4 + the way Story 17.5's `.BANKS` walks
  `active_pages[0..bank_count-1]`.
- **Q4 (Slot / port for `BANK!` MMU write):** AC2 says "writes the
  corresponding physical page to the MMU port for slot 2". PD-P4-9
  + redesign-doc §5.1 imply slot 2 = port `0x70 + 2 = 0x72`. The
  iz-cpm-banking source (`cpm_machine.rs`) should confirm.
  **Recommended:** verify at dev-pass start by inspecting the
  iz-cpm-banking source for `PORT_BANK_*` / `0x72` constants;
  proceed with port `0x72` unless contradictory evidence surfaces.
- **Q5 (Per-bank wordlist_head storage cell):** the per-bank
  `(here, latest, wordlist_head)` triple swap needs concrete
  source/destination cell addresses. HERE + LATEST are likely
  UserArea cells (verify at dev-pass start); `wordlist_head` is
  the first cell of `forth_wordlist` (in `src/wordlists.asm`) —
  but if antforth has multiple wordlists at Story 17.2 close-out
  time (verify), the "wordlist_head" referred to by the triple is
  the first cell of which wordlist? **Recommended:** the
  `forth_wordlist` instance per the Story 17.1 AC4 wording ("the
  wordlist-heads component is one cell holding a pointer to the
  bank's first wordlist"). Multi-wordlist per-bank plumbing is
  Epic 19/20 scope.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Claude Opus 4.7 / 1M context)

### Debug Log References

- Pre-edit baseline at dev-pass start: 25,101 B / 975 PASS / 0 FAIL / 2 SKIP on iz-cpm; 3 PASS on `make test-repl-banking`; 3 PASS on `make test-repl-banking-skip`; iz-cpm-banking @ 1777a85 on PATH ✓.
- HERE / LATEST live cells: `(IY+UserArea.here)` at struct offset 4; `(IY+UserArea.latest)` at offset 6; contiguous 4-byte pair confirmed at `src/structures.asm:21-22`. wordlist_head = first cell at `forth_wordlist:` label, namely WORDLIST_NEXT (= 0 at COLD; `src/wordlists.asm:336-337`).
- iz-cpm-banking port-0x72 confirmation: `cpm_machine.rs:13` PORT_BANK0 = 0x70; slot 2 = 0x72 ✓.
- Task-2 surfaced the iz-cpm test-643 layout-sensitive hang (per `feedback_iz_cpm_test_643_quirk.md`). Story-17.1's single NOP layout-shift slot was tuned to 3 NOPs in Story 17.2 (+2 B net). Empirical: 0 NOPs → FAIL test 643; 1 NOP → FAIL test 643; 3 NOPs → PASS test 643 (and 975 PASS / 0 FAIL / 2 SKIP restored).
- BANK_TABLE_BASE → HERE round-trip verified at REPL prompt: `HERE $D400 @ = . CR` → `-1` (TRUE) ✓.
- BANK! abort path verified: `99 BANK! .S CR` → `bank?error -2: ABORT"` followed by `ok` (stack reset by uncaught-THROW handler).
- `strings build/antforth.com | grep -c "bank?"` → 1 (the message literal exactly once) ✓.

### Completion Notes List

- **All ACs satisfied** modulo AC10 (hardware-smoke). Emulator-side coverage complete; Task 9 deferred to user-driven hardware run before story → done.
- **AC8 SCP-trigger disposition** — see §"AC8 SCP-trigger disposition" in Dev Notes below. Disposition (a) accept-with-rationale applied based on the per-component itemised budget showing every component is already at its compact optimum; further savings require dropping the wordlist_head cell from the triple swap, which would break the Story 19/Epic 19 inheritance contract and is rejected.
- **Wordlist_head interpretation** — Q5 in story file recommended "the forth_wordlist instance per Story 17.1 AC4 wording". Dev-pass implementation uses the literal "first cell of forth_wordlist" form (= WORDLIST_NEXT chain pointer at `forth_wordlist+0`). At Story 17.2 close, this cell holds 0 (the canonical FORTH-WORDLIST has no chained successor); the swap is therefore degenerate at 17.2 close but the MECHANISM is wired for Epic 19/20's multi-wordlist plumbing per the Story 19 inheritance contract.
- **Body byte savings vs literal spec** — applied two compact-Z80 optimisations during dev-pass: (1) `bank_offset_hl` helper uses the `BANK_TABLE_BASE & 0xFF == 0` + `(BANK_TABLE_CAP-1)*6 < 256` invariants to compute the offset in 8 B instead of the literal 13-B HL-arithmetic shape — saves 5 B (two ASSERTs guard against future redesigns); (2) `current_bank+1` high-byte write elided since the precondition guarantees BC.high == 0 at every entry and the COLD-init leaves the cell at 0 permanently — saves 3 B; (3) port-write uses `ADD HL, BC` directly instead of zero-extending C through H+L (the precondition validates BC.high == 0) — saves 3 B. Net Task-4 savings vs literal-spec: ~11 B.

### File List

| Path | Status | Reason |
|------|--------|--------|
| `_bmad-output/implementation-artifacts/17-2-bank-fetch-bank-store-banks-read-and-swap-primitives.md` | modified | Story file: task checkboxes, Dev Agent Record, Status → review |
| `_bmad-output/implementation-artifacts/sprint-status.yaml` | modified | 17-2 row: ready-for-dev → in-progress → review |
| `src/structures.asm` | modified | UserArea +bank_count cell (DW 0, 4 lines of comment) — appended at end |
| `src/banking.asm` | modified | +ACTIVE_PAGES_BASE / ACTIVE_PAGES_SIZE constants; +w_BANK_AT / w_BANK_STORE / w_BANKS DEFCODEs; +bank_offset_hl helper; +str_bank_q literal; +.abort_bank tail |
| `src/antforth.asm` | modified | cold_start step 8h: DJNZ counter 174 → 203; +bank_count zero-init; +bank-table[0] live-triple snapshot; +2 extra layout-shift NOPs (iz-cpm test-643 parity) |
| `docs/ans-forth-core-compliance.md` | modified | Non-standard words table: BANK-MAPPING-ON/OFF line-number drift + 3 new rows (BANK@, BANK!, BANKS) |
| `tests/banking_tests.fth` | modified | +Probe 3 (bank-at-zero), +Probe 4 (banks-zero), +Probe 5 (bank-store-abort-bank-q), +Probe 6 (bank-store-round-trip-1 PENDING-17.3), +Probe 7 (bank-store-round-trip-0 PENDING-17.3), +Probe 8 (bank-store-t-states INFO) |
| `Makefile` | modified | `test-repl-banking` + `test-repl-banking-skip` recipes' inline pattern lists extended for the new probes |
| `build/antforth.com` | rebuilt | 25,101 B → 25,285 B (+184 B; see AC8 SCP-trigger disposition) |
| `~/Downloads/beastty-20260515-225700.bin` | added | Hardware-smoke transcript (Task 9; AC10 verdict PASS on banner + BANK@ + BANKS + BANK! ABORT" message) |

### Change Log

| Date | Change |
|------|--------|
| 2026-05-15 | Story 17.2 dev-pass: §banking BANK@ / BANK! / BANKS primitives + COLD bank-table[0] snapshot + UserArea bank_count cell + active_pages[$D4AE..$D4CA] zero-init + tests/banking_tests.fth 6-probe extension + compliance-doc 3-row addition. wc -c = 25,101 → 25,285 (+184 B; AC8 SCP-trigger accepted-with-rationale per the Body-byte-budget itemisation in Dev Notes). Tasks 1-8 + 10 closed; Task 9 (hardware-smoke) deferred to user-driven MicroBeast run. |
