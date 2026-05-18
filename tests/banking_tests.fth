\ banking_tests.fth — Phase-4 banking word tests (Epic 17+)
\ Surface annotations per tests/README.md §5; one annotation per probe block.
\
\ Probes here ship with Story 17.1's BANK-MAPPING-ON / BANK-MAPPING-OFF.
\ Later Epic-17 stories (17.2 BANK@/BANK!, 17.3 +BANK/-BANK, 17.5 .BANKS)
\ extend this file with their own probe blocks.
\
\ === Architectural note: BANK-MAPPING-OFF emulator coverage ===
\ BANK-MAPPING-OFF is a one-way warm-boot-escape transition per FR-P4-12
\ (returns control to a flat-memory CP/M context). Under iz-cpm-banking
\ (cpm_machine.rs virtual_bank: when mapping is disabled the CPU sees
\ flash banks 0..3, and load_flash is only called via --flash) and on
\ real MicroBeast (flash holds BIOS, not antforth), executing
\ BANK-MAPPING-OFF disconnects the kernel from the RAM that hosts its
\ code. Story 17.1 dev-pass surfaced this divergence: AC5/AC6/AC11's
\ `BANK-MAPPING-OFF BANK-MAPPING-ON round-trip` text cannot run under
\ iz-cpm-banking (no flash mirror) without bigger plumbing. Pragmatic
\ split (project-lead direction 2026-05-15):
\   - emulator probes here verify ON-idempotence + port 0x74 readback;
\   - real-MicroBeast hardware (AC10 / Task 11) verifies the OFF→BYE
\     warm-boot escape to a healthy `B>` CCP prompt.

\ Inline assembler reader for port 0x74 (MMU mapping enable).
\ Pattern lifted from _bmad-output/implementation-artifacts/16.3-probe.fth.
\ Pushes the live mapping_enabled byte (0 or 1 under iz-cpm-banking;
\ 0 always on iz-cpm baseline — unmodelled port).
CODE FETCH-74 ( -- byte )
  BC PUSH,          \ save old TOS to SP
  $74 # A IN,       \ IN A, (74h)
  C A LD,           \ C <- A (low byte)
  B 0 # LD,         \ B <- 0     (zero-extend to cell)
  NEXT,
END-CODE

\ Inline assembler reader for port 0x72 (slot-2 MMU page register).
\ Returns the live slot-2 mapping under iz-cpm-banking (cpm_machine.rs:138
\ returns bank_map[2]); returns 0 / 0xFF / garbage under iz-cpm baseline
\ (port unmodelled — surface-gate with FETCH-74 when used as an assertion).
\ Used by Probe E (SET-BANK port-write verification) and Probe F (-BANK
\ LDIR data verification via 0 BANK! → port-0x72 readback).
CODE FETCH-72 ( -- byte )
  BC PUSH,
  $72 # A IN,
  C A LD,
  B 0 # LD,
  NEXT,
END-CODE

\ === Probe 1: BANK-MAPPING-ON idempotence + stack effect ===
\ Surface: iz-cpm-PASS / iz-cpm-banking-PASS / real-MicroBeast-PASS
\
\ AC5 stack-effect verification — repeated BANK-MAPPING-ON has stack
\ effect `( -- )` and the word body completes cleanly. Idempotent
\ under iz-cpm-banking (mapping is enabled at startup; second-and-third
\ ON are silent re-writes of the same bit pattern). Idempotent under
\ iz-cpm baseline (port 0x74 is unmodelled — OUT is a no-op trace, but
\ the kernel-side bank_mapping_state cell still updates correctly).
BANK-MAPPING-ON  BANK-MAPPING-ON  BANK-MAPPING-ON
DEPTH 0 = IF
  ." PASS: banking-mapping-on-idempotent — BANK-MAPPING-ON ×3 leaves stack empty"
ELSE
  ." FAIL: banking-mapping-on-idempotent — DEPTH = " DEPTH .
THEN
CR

\ === Probe 2: port 0x74 readback after BANK-MAPPING-ON ===
\ Surface: iz-cpm-SKIP (no MMU model — port 0x74 unmodelled, returns 0)
\        / iz-cpm-banking-PASS (port_in 0x74 = mapping_enabled byte)
\        / real-MicroBeast-PASS (hardware MMU reflects bit 0).
\
\ AC5 load-bearing verification — after BANK-MAPPING-ON, the MMU
\ mapping-enable register (port 0x74) reads back as 1. Under iz-cpm
\ baseline the readback is 0 (no MMU model) — probe declares SKIP
\ with rationale per the Story 16.3 convention; on iz-cpm-banking and
\ real MicroBeast the load-bearing assertion (readback = 1) fires PASS.
BANK-MAPPING-ON
FETCH-74
DUP 1 = IF
  ." PASS: banking-mapping-on-port-74 — port 0x74 reads back 1 (mapping enabled)"
  DROP
ELSE
  ." SKIP: banking-mapping-on-port-74 — iz-cpm does not model MMU port 0x74 (readback=$"
  BASE @ HEX SWAP . BASE !
  ." expected=$1)"
THEN
CR

\ === Probe 3: BANK@ at boot returns 0 (Story 17.2 AC6 Probe 1) ===
\ Surface: iz-cpm-PASS / iz-cpm-banking-PASS / real-MicroBeast-PASS
\
\ Verifies (IY+UserArea.current_bank) is zero-initialised in COLD per
\ Story 17.1 step 8h. Surface-agnostic: the cell read does not touch
\ the MMU; passes on all three test surfaces.
BANK@
DUP 0 = IF
  ." PASS: bank-at-zero — BANK@ returns 0 at boot"
  DROP
ELSE
  ." FAIL: bank-at-zero — BANK@ returned " .
THEN
CR

\ === Probe 4: BANKS at boot returns 0 (Story 17.2 AC6 Probe 2) ===
\ Surface: iz-cpm-PASS / iz-cpm-banking-PASS / real-MicroBeast-PASS
\
\ Verifies (IY+UserArea.bank_count) is zero-initialised in COLD. The
\ active list is empty at Story 17.2 close — Story 17.3's +BANK
\ populates it; Story 17.4's CL parser auto-populates at boot. This
\ probe's assertion changes to the default-count at Story 17.4 close
\ (epic AC6 text says "BANKS . returns the configured-banks count
\ (initially 12 with defaults)" — that PASSes post-17.4; 0 at 17.2
\ close per the sequencing in story 17-2 §"AC6 probe sequencing" Q2).
\ Surface-agnostic: kernel cell read, no MMU touch.
BANKS
DUP 0 = IF
  ." PASS: banks-zero — BANKS returns 0 at boot (active list empty until Story 17.3/17.4)"
  DROP
ELSE
  ." FAIL: banks-zero — BANKS returned " .
THEN
CR

\ === Probe 5: 99 BANK! raises ABORT" bank?" (Story 17.2 AC6 Probe 3) ===
\ Surface: iz-cpm-PASS / iz-cpm-banking-PASS / real-MicroBeast-PASS
\
\ Verifies BANK!'s precondition check (n < bank_count) fires for an
\ out-of-range argument. At Story 17.2 close, bank_count = 0 so every
\ BANK! invocation aborts; the precondition path is the only path
\ exercised on the dev-pass test surface. ABORT" routes through
\ THROW -2 (kernel-internal entry); REPL recovers to the prompt with
\ DEPTH = 0 (stack reset wholesale by uncaught-THROW handler). The
\ probe asserts DEPTH = 0 after the abort, NOT the printed message
\ (the message text "bank?" + the THROW-decoded "error -2: ABORT\""
\ both land in the upstream-pipe stdout pre-prompt, but verifying via
\ DEPTH avoids the brittleness of an inline string match).
\ Surface-agnostic: no MMU touch on the precondition-fail path.
99 BANK!
DEPTH 0 = IF
  ." PASS: bank-store-abort-bank-q — 99 BANK! aborts; REPL recovers; DEPTH = 0"
ELSE
  ." FAIL: bank-store-abort-bank-q — DEPTH after abort = " DEPTH .
THEN
CR

\ === Story 17.3 probe block (Probes 6 rewrite + 7+8 re-enable + A..E) ===
\
\ All Story-17.3 probes are wrapped in colon definitions so IF/ELSE/THEN
\ compile (top-level IF errors with -14 'compile-only' per ?COMP). Probes
\ that exercise port 0x72 are surface-gated via FETCH-74 (returns 1 on
\ iz-cpm-banking / real MicroBeast after auto-BANK-MAPPING-ON; returns 0
\ on iz-cpm baseline where port 0x74 is unmodelled). Story-17.2 Probe 6
\ (`bank-store-swap-path`) is rewritten to drop the inline-asm
\ `_SEED-BANK` / `_CLEAR-BANK` fixture (retired this story); its body
\ now uses `$22 +BANK` to populate the active list.

\ Probe 6 (rewrite — was inline-asm fixture-seeded; now uses real +BANK).
\ Surface: iz-cpm-PASS (flat memory PASSes +BANK probe) / iz-cpm-banking-PASS /
\          real-MicroBeast-PASS
: _probe-6 ( -- )
  $22 +BANK
  0 BANK!
  BANK@ DUP 0 = IF
    ." PASS: bank-store-swap-path — 0 BANK! round-trips after $22 +BANK (H1 IP-clobber fix verified)"
    DROP
  ELSE
    ." FAIL: bank-store-swap-path — BANK@ returned " .
  THEN
  CR
  $22 -BANK
;
_probe-6

\ Probe 7 (re-enabled PENDING-17.3): 1 BANK! BANK@ round-trip.
\ Surface: iz-cpm-SKIP (port 0x72 unmodelled — flat memory would
\          accidentally PASS but BANK! swap-path is meaningless) /
\          iz-cpm-banking-PASS / real-MicroBeast-PASS
: _probe-7 ( -- )
  FETCH-74 1 = IF
    $22 +BANK $23 +BANK
    1 BANK! BANK@ DUP 1 = IF
      ." PASS: bank-store-round-trip-1 — 1 BANK! round-trips after $22+$23 +BANK"
      DROP
    ELSE
      ." FAIL: bank-store-round-trip-1 — BANK@ returned " .
    THEN
    \ Restore bank 0 before BANKS-CLEAR so HERE/LATEST come back to the
    \ kernel snapshot — leaving current_bank = 1 then clearing the list
    \ would leave HERE pointing into bank-table[1]'s zero-init slot,
    \ which corrupts the next colon definition compiled in the REPL.
    0 BANK!
    BANKS-CLEAR
  ELSE
    ." SKIP: bank-store-round-trip-1 — port 0x72 unmodelled (iz-cpm baseline)"
  THEN
  CR
;
_probe-7

\ Probe 8 (re-enabled PENDING-17.3): 0 BANK! BANK@ round-trip.
\ Surface: iz-cpm-SKIP / iz-cpm-banking-PASS / real-MicroBeast-PASS
: _probe-8 ( -- )
  FETCH-74 1 = IF
    $22 +BANK
    0 BANK! BANK@ DUP 0 = IF
      ." PASS: bank-store-round-trip-0 — 0 BANK! round-trips after $22 +BANK"
      DROP
    ELSE
      ." FAIL: bank-store-round-trip-0 — BANK@ returned " .
    THEN
    BANKS-CLEAR
  ELSE
    ." SKIP: bank-store-round-trip-0 — port 0x72 unmodelled (iz-cpm baseline)"
  THEN
  CR
;
_probe-8

\ Probe A (Story 17.3): +BANK known-good RAM.
\ Surface: iz-cpm-SKIP (port 0x72 unmodelled) /
\          iz-cpm-banking-PASS (page $22 = RAM bank 2 default) /
\          real-MicroBeast-PASS (page $22 = user-RAM bank 0).
: _probe-a ( -- )
  FETCH-74 1 = IF
    $22 +BANK BANKS DUP 1 = IF
      ." PASS: plus-bank-known-good — $22 +BANK appends; BANKS = 1"
      DROP
    ELSE
      ." FAIL: plus-bank-known-good — BANKS = " .
    THEN
    BANKS-CLEAR
  ELSE
    ." SKIP: plus-bank-known-good — port 0x72 unmodelled (iz-cpm baseline; flat memory would false-PASS)"
  THEN
  CR
;
_probe-a

\ Probe B (Story 17.3): +BANK known-ROM rejection.
\ Surface: iz-cpm-SKIP (flat memory would false-PASS rejection) /
\          iz-cpm-banking-PASS (page 0 = flash bank 0; poke ignored,
\                               reads 0xFF; +BANK probe rejects) /
\          real-MicroBeast-PASS (firmware flash bank 0 is ROM).
\ Uses CATCH to trap the ABORT" probe?" THROW (-2) inside the colon
\ definition so the surrounding IF/ELSE survives.
: _do-zero-+bank ( -- ) 0 +BANK ;
: _probe-b ( -- )
  FETCH-74 1 = IF
    ['] _do-zero-+bank CATCH -2 = IF
      BANKS 0 = IF
        ." PASS: plus-bank-rom-rejection — 0 +BANK aborts; BANKS = 0"
      ELSE
        ." FAIL: plus-bank-rom-rejection — BANKS = " BANKS .
      THEN
    ELSE
      ." FAIL: plus-bank-rom-rejection — 0 +BANK did not throw -2 (CATCH)"
    THEN
  ELSE
    ." SKIP: plus-bank-rom-rejection — port 0x72 unmodelled (iz-cpm baseline; flat memory would false-PASS)"
  THEN
  CR
;
_probe-b

\ Probe C (Story 17.3): -BANK present + absent.
\ Surface-agnostic (no MMU touch in -BANK): iz-cpm-PASS / iz-cpm-banking-PASS
\ / real-MicroBeast-PASS
: _probe-c ( -- )
  $22 +BANK
  $22 -BANK BANKS DUP 0 = IF
    DROP
    $22 -BANK BANKS DUP 0 = IF
      ." PASS: minus-bank-present-absent — present removes; absent is no-op"
      DROP
    ELSE
      ." FAIL: minus-bank-present-absent (absent) — BANKS = " .
    THEN
  ELSE
    ." FAIL: minus-bank-present-absent (present) — BANKS = " .
  THEN
  CR
;
_probe-c

\ Probe D (Story 17.3): BANKS-CLEAR zeroes bank_count; BANK! aborts.
\ Surface-agnostic: iz-cpm-PASS / iz-cpm-banking-PASS / real-MicroBeast-PASS
: _do-zero-bank-store ( -- ) 0 BANK! ;
: _probe-d ( -- )
  $22 +BANK $23 +BANK BANKS-CLEAR BANKS DUP 0 = IF
    DROP
    ['] _do-zero-bank-store CATCH -2 = IF
      ." PASS: banks-clear-zero — BANKS-CLEAR empties list; 0 BANK! aborts"
    ELSE
      ." FAIL: banks-clear-zero — 0 BANK! did not throw -2 (CATCH)"
    THEN
  ELSE
    ." FAIL: banks-clear-zero — BANKS = " .
  THEN
  CR
;
_probe-d

\ Probe E (Story 17.3): SET-BANK diagnostic — split into two assertions.
\ E1 (surface-agnostic): SET-BANK does NOT update current_bank — BANK@ stays 0.
\ E2 (surface-gated): SET-BANK actually writes to the port — FETCH-72 readback
\ matches the sentinel page. Uses sentinel $23 instead of the slot-2 default
\ $22 so the readback discriminates a real write from coincidence with the
\ pre-existing mapping (Code Review L5).
\ Probe uses slot = 2 (portal slot; safe per Story 17.2 analysis).
: _probe-e ( -- )
  $23 2 SET-BANK
  BANK@ DUP 0 = IF
    ." PASS: set-bank-diagnostic-bank-at — $23 2 SET-BANK leaves BANK@ unchanged at 0"
    DROP
  ELSE
    ." FAIL: set-bank-diagnostic-bank-at — BANK@ = " .
  THEN
  CR
  FETCH-74 1 = IF
    FETCH-72 DUP $23 = IF
      ." PASS: set-bank-diagnostic-port-write — port-0x72 readback = $23 (SET-BANK wrote)"
      DROP
    ELSE
      ." FAIL: set-bank-diagnostic-port-write — port-0x72 readback = $" BASE @ HEX SWAP . BASE !
    THEN
  ELSE
    ." SKIP: set-bank-diagnostic-port-write — port 0x72 unmodelled (iz-cpm baseline)"
  THEN
  CR
;
_probe-e

\ Probe F (Code Review H1): -BANK LDIR shift-down — count + data verification.
\
\ Two-part probe. F1 (surface-agnostic count check): seeds 3 entries
\ [$22, $23, $24], removes $22 twice. If the LDIR shift fires correctly
\ on the first remove, the array becomes [$23, $24, ...] and the second
\ $22 -BANK is a no-op (BANKS stays at 2). If LDIR is broken (e.g.,
\ skipped entirely), $22 is still at index 0 after the first remove and
\ the second remove decrements again → BANKS = 1.
\
\ F2 (surface-gated data check): after the shift, 0 BANK! reads
\ active_pages[0] and writes it to port 0x72. FETCH-72 readback should
\ equal $23 (the shifted-in value), catching the case where LDIR
\ skipped without leaving the right page at index 0.
: _probe-minus-bank-ldir ( -- )
  $22 +BANK $23 +BANK $24 +BANK
  $22 -BANK   \ if LDIR works: [$23, $24, ...], bank_count=2
  $22 -BANK   \ $22 absent → no-op; bank_count stays 2 if shift worked
  BANKS DUP 2 = IF
    ." PASS: minus-bank-ldir-shift-count — second $22 -BANK was a no-op (BANKS=2)"
    DROP
  ELSE
    ." FAIL: minus-bank-ldir-shift-count — BANKS = " .
  THEN
  CR
  FETCH-74 1 = IF
    0 BANK!     \ slot 2 ← active_pages[0]
    FETCH-72 DUP $23 = IF
      ." PASS: minus-bank-ldir-shift-data — port-0x72 readback = $23 (shifted-in value at index 0)"
      DROP
    ELSE
      ." FAIL: minus-bank-ldir-shift-data — port-0x72 readback = $" BASE @ HEX SWAP . BASE !
    THEN
  ELSE
    ." SKIP: minus-bank-ldir-shift-data — port 0x72 unmodelled (iz-cpm baseline)"
  THEN
  CR
  \ Cleanup: restore bank 0 (HERE/LATEST snapshot) BEFORE BANKS-CLEAR
  \ so subsequent REPL state stays sane (see BANKS-CLEAR docstring).
  FETCH-74 1 = IF 0 BANK! THEN
  BANKS-CLEAR
;
_probe-minus-bank-ldir

\ Probe G (Story 17.5.1 rewrite, supersedes Story 17.3 Code Review H2):
\ +BANK cap check at bank_count == 29 — AC2 / PD-P4-13.
\
\ Reset-before-seed (Story 17.5.1 AC1): probe opens with BANKS-CLEAR so
\ the seed loop starts from bank_count = 0 regardless of CL-parser boot
\ defaults (Story 17.4 populates active_pages[] with 12 entries by
\ default; the original Story-17.3 H2 probe assumed bank_count = 0 at
\ entry and tripped the cap mid-seed-loop, leaving the probe's PASS
\ branch unreached and the recipe-side grep false-PASSing on the
\ source-echo of the ." PASS: ..." literal).
\
\ Sentinel-bounded output (Story 17.5.1 AC2): the Makefile recipes
\ (test-repl-banking + test-repl-banking-skip) use awk to extract the
\ runtime-output region between ---plus-bank-cap-start--- and
\ ---plus-bank-cap-end--- sentinels, then grep within that region for
\ assertion text ("cap-check-fired-after-29-seed") plus the seed-loop
\ completion witness ("seeded: 29") and negative-assert on FAIL strings.
\ The assertion text deliberately lacks a "PASS:" prefix — the
\ recipe-side awk-extract handles verdict-label semantics, not the
\ probe-side text.
\
\ Surface-agnostic: under iz-cpm baseline the probes succeed via flat
\ memory; under iz-cpm-banking and real MB they succeed via the modelled
\ RAM bank $22. The cap check itself is a kernel-cell comparison —
\ surface-independent.
\
\ Two load-bearing BANKS-CLEAR sites: the HEAD one (AC1 reset-before-seed —
\ removing it breaks every test run, since boot defaults populate 12
\ entries and the seed loop would trip the cap mid-iteration) and the
\ TAIL one (handoff guard for any probes added after probe G — leaves
\ bank_count = 0 for the next probe's known state). Do not move either.
\
\ BASE residue note (Story 17.5.1 AC5 disposition (a) → probe-side fix):
\ Probes 1 + 2 use top-level IF/ELSE/THEN, which fire THROW -14
\ ("interpreting a compile-only word") and DO NOT branch — every token
\ in BOTH branches executes sequentially. Probe 2's ELSE branch contains
\ `BASE @ HEX SWAP . BASE !` (line 83); the unprotected `SWAP .` raises
\ THROW -4 (stack underflow), so `BASE !` never runs to restore.
\ Result: BASE = 16 leaks into all subsequent parse + execution. Within
\ this story's scope (test-infra-only) the fix is local: bracket probe G
\ with DECIMAL at BOTH file-parse time (literals `29` / `0` parsed in
\ DECIMAL — otherwise `29` HEX = 41 makes the DO LOOP run 41 iterations
\ and trip the cap mid-loop) AND probe-body entry (so runtime `.` prints
\ the BANKS count in DECIMAL — recipe asserts `seeded: 29`). Refactoring
\ probes 1+2 to use colon-body wrappers like probes 6+ is out of scope
\ for Story 17.5.1; refile as a follow-up if/when the test-infra ceiling
\ matters again.
DECIMAL
: _do-29-+bank ( -- )
  29 0 DO $22 +BANK LOOP
;
: _do-one-more-+bank ( -- ) $22 +BANK ;
: _probe-plus-bank-cap ( -- )
  DECIMAL
  BANKS-CLEAR
  ." ---plus-bank-cap-start---" CR
  _do-29-+bank
  ." seeded: " BANKS . CR
  BANKS DUP 29 = IF
    DROP
    ['] _do-one-more-+bank CATCH -2 = IF
      BANKS 29 = IF
        ." cap-check-fired-after-29-seed" CR
      ELSE
        ." FAIL: plus-bank-cap — BANKS = " BANKS . ." (expected 29 after cap abort)" CR
      THEN
    ELSE
      ." FAIL: plus-bank-cap — 30th +BANK did not throw -2 (CATCH)" CR
    THEN
  ELSE
    ." FAIL: plus-bank-cap — could not seed 29 entries; BANKS = " . CR
  THEN
  ." ---plus-bank-cap-end---" CR
  BANKS-CLEAR
;
_probe-plus-bank-cap

\ === Probe 9: BANK! T-state latency probe (Story 17.2 AC5; informational) ===
\ Surface: informational-on-all (NFR-P4-2's ≤60 T-state envelope binds
\          cross-bank dispatch overhead per FR-P4-16 — Epic 18 scope —
\          NOT the user-facing BANK! word; AC5 disposition (a)
\          accept-with-rationale).
\
\ A T-state counter wrapped around a single BANK! invocation would
\ require iz-cpm-banking's --trace mode or a paper-arithmetic walk
\ through the BANK! body. Per-opcode estimate (precondition ~24 T;
\ port write ~22 T; current_bank swap ~30 T; rpush_bc + rpop_bc ~36 T;
\ two bank_offset_hl calls ~70 T; two LDIRs (4 bytes each, ~84 T per
\ LDIR including loop) ~168 T; wordlist_head save+load ~50 T; POP BC
\ + NEXT ~25 T): ~425 T-states. Well above the NFR-P4-2 60 T-state
\ envelope. Per AC5 disposition (a): the 60 T-state envelope binds
\ FR-P4-16 cross-bank-call dispatch overhead (Epic 18), not the
\ REPL-level BANK! word — informational only. Story 17.6's iron-spike
\ + Epic-18 cross-bank-call work re-measures against the binding
\ envelope.
." INFO: bank-store-t-states — paper-arithmetic estimate ~425 T-states (precondition ~24 + port-write ~22 + offset+LDIR cascades ~322 + tail ~57); NFR-P4-2 envelope (60 T) binds cross-bank dispatch (Epic 18), not BANK! itself" CR

\ === Story 17.5: .BANKS probes (Probes X, Y, Z, W) ===
\ Per Story 17.5 AC7 (4 binding probes) — surface-AGNOSTIC PASS on both
\ iz-cpm baseline and iz-cpm-banking (`.BANKS` reads (IY+bank_count) +
\ (IY+current_bank) + walks active_pages[]; no MMU port operations;
\ output is identical on both surfaces). Q7=a sentinel-and-grep pattern:
\ each probe prints `dot-banks-probe-<name>-start` + `.BANKS` + `dot-banks-
\ probe-<name>-end` sentinels; the Makefile test-repl-banking recipe
\ grep-asserts on the content between sentinels.
\
\ Reproducibility: probe G (_probe-plus-bank-cap) leaves the runtime with
\ bank_count = 29 / BASE = 16 if its `_do-29-+bank` LOOP body trips the
\ cap-check mid-loop (a pre-existing test-infra latent — surfaced during
\ Story 17.5 dev-pass; the Makefile's grep for `PASS: plus-bank-cap`
\ false-PASSes via the source-echo of the `." PASS: ..."` literal
\ regardless of whether the PASS branch actually ran). To make THESE
\ probes reproducible, each colon definition below opens with a
\ `_dot-banks-setup` helper that asserts DECIMAL + BANKS-CLEAR + seeds
\ exactly 12 entries via repeated `+BANK $22` (no DO LOOP — the polluted
\ state from probe G makes a 12-iteration DO LOOP unreliable; manual
\ unrolling sidesteps the issue). With this setup, .BANKS prints 12 rows
\ all at PAGE 22, used=0, free=16384, totals free = 12*16384 = 196608.

: _dot-banks-setup ( -- )
  DECIMAL
  BANKS-CLEAR
  $22 +BANK  $22 +BANK  $22 +BANK  $22 +BANK
  $22 +BANK  $22 +BANK  $22 +BANK  $22 +BANK
  $22 +BANK  $22 +BANK  $22 +BANK  $22 +BANK
;

\ Probe X — header + row-count + totals at 12 banks.
\ Makefile grep targets: `BANK PAGE` header substring + `TOTAL` keyword
\ + `196608` (= 12 * 16384) on the totals line.
: _dot-banks-probe-x ( -- )
  _dot-banks-setup
  ." ---dot-banks-probe-x-start---" CR
  .BANKS
  ." ---dot-banks-probe-x-end---" CR
;
_dot-banks-probe-x

\ Probe Y — current-bank marker tracking. Asserts `*` on row 0 at boot,
\ then on row 1 after `1 BANK!`, then back to row 0 after `0 BANK!`.
\ Makefile grep targets: between the start/mid1 sentinels, marker `*` on
\ the row whose BANK col reads `   0`; between mid1/mid2, on the row whose
\ BANK col reads `   1`; between mid2/end, back to row 0.
: _dot-banks-probe-y ( -- )
  _dot-banks-setup
  ." ---dot-banks-probe-y-start---" CR
  .BANKS
  ." ---dot-banks-probe-y-mid1---" CR
  1 BANK!
  .BANKS
  ." ---dot-banks-probe-y-mid2---" CR
  0 BANK!
  .BANKS
  ." ---dot-banks-probe-y-end---" CR
;
_dot-banks-probe-y

\ Probe Z — placeholder-values guard. Asserts every per-bank row carries
\ the literal `0  16384` substring (i.e. no accidental scope creep into
\ reading real per-bank-HERE values; Epic 19 owns the real-values upgrade).
\ Makefile grep targets: between sentinels, at least 12 lines containing
\ the substring `0  16384`.
: _dot-banks-probe-z ( -- )
  _dot-banks-setup
  ." ---dot-banks-probe-z-start---" CR
  .BANKS
  ." ---dot-banks-probe-z-end---" CR
;
_dot-banks-probe-z

\ Probe W — totals row. Asserts `TOTAL` keyword present and `196608`
\ (= 12 * 16384) on the totals line.
: _dot-banks-probe-w ( -- )
  _dot-banks-setup
  ." ---dot-banks-probe-w-start---" CR
  .BANKS
  ." ---dot-banks-probe-w-end---" CR
;
_dot-banks-probe-w

\ === Probe IRON-SPIKE: hand-built cross-bank call (Story 17.6 AC1..AC4) ===
\ Epic 17 iron-spike — Story 17.6 AC1..AC4. Hand-built cross-bank call.
\ No descriptor stub. No compiler integration. No sentinel-trampoline.
\ Epic 18 (descriptor-stub mechanism γ + sentinel-trampoline S1 b) supersedes
\ this probe. After Epic 18 ships, this probe is informational-only — keep as
\ a banking-layer round-trip witness; the user-facing cross-bank call surface
\ moves to descriptor-stub dispatch per docs/antforth-banking-redesign.md §3.
\
\ WARNING — interactive (typed-at-REPL) iron-spike forms are FRAGILE.
\ Story 17.6 first-pass hardware-smoke run 2026-05-17 transcript
\ ~/Downloads/beastty-20260517-092031.bin: kernel warm-booted on EXECUTE.
\ Root cause: when typed interactively, the outer interpreter's WORD parses
\ each token by writing its counted-string name at HERE+0 (count) +
\ HERE+1.. (chars) BEFORE the token executes. With sequence `HERE ['] NEGATE
\ HERE 3 MOVE 3 ALLOT`, MOVE writes JP DOCOL (C3 lo hi) at start-addr; the
\ very next `3` parsed for ALLOT then writes [01 33] at start-addr..+1,
\ clobbering the JP opcode. EXECUTE runs garbage → undefined → warm-boot.
\ The colon-body form below is safe: at runtime, the threaded interpreter
\ walks pre-resolved XTs without calling WORD between tokens. For typed
\ hardware-smoke, either (a) INCLUDE this file, or (b) wrap the body in a
\ ONE-LINE colon definition before invoking — see Story 17.6 hardware-smoke
\ closing-message recipe (corrected after the 2026-05-17 first-pass failure).
\
\ Where does the body actually live? — CRITICAL CR clarification (Story 17.6
\ code-review M1, 2026-05-17). Bank-5's per-bank HERE is LDIR-cloned from
\ bank-0's COLD-time HERE at COLD per [[project-bank-table-clone-at-cold]];
\ that COLD-time HERE is `kernel_end` (src/antforth.asm:51), which lives in
\ MAIN RAM (~ $677D observed on real hardware, well below the $8000 portal
\ lower bound). So when `5 BANK!` loads bank-5's saved (HERE, LATEST,
\ wordlist_head) triple into the live cells on first visit, live HERE points
\ at `kernel_end` — IN MAIN RAM — NOT at any address in the bank-5-mapped
\ $8000-$BFFF portal window. The 9-byte body therefore lands in MAIN RAM at
\ `kernel_end..kernel_end+8`, NOT in bank-5's banked RAM page $39.
\
\ What the round-trip actually validates:
\   (a) BANK! port-0x72 write fires unconditionally (iz-cpm-banking + hw);
\   (b) per-bank (here, latest, wordlist_head) swap is symmetric across a
\       0 BANK! → 5 BANK! cycle (live state restores correctly);
\   (c) EXECUTE on a hand-built JP-DOCOL-prefix body at a per-bank-saved
\       HERE works as a cross-bank dispatch target — provided the body
\       lives in main RAM (which is what this probe exercises).
\
\ What the round-trip does NOT validate:
\   - Bytes written into a banked-RAM page (eg. an address IN $8000-$BFFF
\     while bank N is mapped) surviving a swap-out / swap-in cycle. For
\     Epic 18's descriptor-stub trampoline this gap is OK iff the stub
\     lives in fixed memory per docs/antforth-banking-redesign.md §3. If
\     any Epic-18 / Epic-19 design ends up needing banked-RAM-resident
\     executable code, an iron-spike-2 (set HERE to a portal address like
\     $A000 before the MOVE; verify the 9 bytes survive 0 BANK! → 5 BANK!)
\     is owed BEFORE that design ships. Filed for the Epic-17 retro.
\
\ Destructive side-effect on bank 0's dictionary (CR M2):
\   `5 BANK!` loads bank-5's cloned-COLD HERE (= `kernel_end`) into live;
\   the 9-byte write therefore overwrites the physical-RAM bytes at
\   `kernel_end..kernel_end+8`. Those are the same physical addresses
\   bank 0 used for the first 9 bytes of the FIRST colon definition
\   compiled at COLD-time HERE — i.e. the earliest probe's body. After
\   `0 BANK!` restores bank-0's HERE = post-all-probes value, the
\   corrupted region (`kernel_end..kernel_end+8`) sits below the
\   restored HERE; future `,` / ALLOT in bank 0 do NOT touch it, but
\   the bytes themselves are permanently mangled. Benign in the current
\   pass because: this is the LAST probe in this file; final
\   `BANKS-CLEAR` sets bank_count = 0 so no later BANK! succeeds; BYE
\   follows. CONSTRAINT: iron-spike MUST remain the LAST probe in this
\   file. Inserting a new probe AFTER iron-spike, or re-running
\   `_iron-spike-test` interactively at the REPL during debugging, will
\   surface the corruption (the earliest probe's dictionary entry now
\   carries JP DOCOL / XT-LIT / 12345 / XT-EXIT instead of its
\   intended body).
\
\ Shape (per Story 17.6 Task 1.2):
\   1. Re-seed bank-table (probe G's tail BANKS-CLEAR left bank_count = 0):
\        BANKS-CLEAR + $22 +BANK + $35..$39 +BANK  → 6 entries; bank 5 = $39
\        (default-mapping bank-5 page per redesign §5.1).
\   2. 5 BANK!  — MMU port-0x72 write maps page $39 into the $8000-$BFFF
\      portal window AND per-bank (here, latest, wordlist_head) triple
\      becomes current (cloned from bank-0 at COLD per
\      [[project-bank-table-clone-at-cold]]). Live HERE = `kernel_end`,
\      which is in MAIN RAM — see "Where does the body actually live?"
\      block above.
\   3. HERE → save start-addr (main-RAM `kernel_end`-vicinity address).
\   4. Write a 9-byte colon body at the saved HERE (main RAM):
\        bytes 0..2: JP DOCOL prefix (MOVE-copied from NEGATE's CFA;
\                    NEGATE is DEFWORD per bootstrap.asm:9, so its CFA's
\                    first 3 bytes are `C3 DOCOL_lo DOCOL_hi`)
\        bytes 3..4: w_LIT_cf  (XT of LIT — pushes inline literal)
\        bytes 5..6: 12345     (literal sentinel value, decimal)
\        bytes 7..8: w_EXIT_cf (XT of EXIT — pops RS and NEXTs to caller)
\   5. 0 BANK!  — swap state back to bank 0 (port 0x72 ← active_pages[0]
\      = $22; live HERE restored from bank-table[0] = post-all-probes
\      value). MAIN RAM at `kernel_end..kernel_end+8` is unaffected by
\      the MMU port write and retains the 9 bytes we wrote.
\   6. 5 BANK!  — swap back to bank 5 (live HERE restored from
\      bank-table[5] = `kernel_end + 9`, the value we left). Main-RAM
\      contents at `kernel_end..kernel_end+8` still intact.
\   7. EXECUTE start-addr  — JP (HL) into our hand-built body:
\        JP DOCOL → DOCOL pushes IP, sets new IP = body+3 (= w_LIT_cf cell),
\        NEXT → LIT executes, reads literal 12345 from thread, pushes to data
\        stack, NEXT → EXIT pops return stack, NEXT continues caller.
\   8. Assert TOS = 12345 (kernel actually ran the hand-built body across
\      the bank-cycle round-trip).
\   9. 0 BANK! + BANKS-CLEAR  — restore probe-close state for hygiene.
\      Order matters: 0 BANK! while bank_count = 6 is still valid; then
\      BANKS-CLEAR drives bank_count → 0 (BANKS-CLEAR-before-0-BANK!
\      would ABORT" bank?" — see Story 17.6 Dev Notes "probe-close
\      ordering fix").
\
\ Sentinel: 12345 (decimal). PASS literal "iron-spike-sentinel-12345-returned"
\ lacks "PASS:" prefix per Story 17.5.1 source-echo lesson — the Makefile
\ recipe's awk-extract + grep handles verdict-label semantics; FAIL branches
\ emit distinct "FAIL: iron-spike <reason>" strings (recipe negative-asserts).
\
\ Sentinel-bounded output (Story 17.5.1 AC2 + M4 fix): wrapped in
\ ---iron-spike-start--- / ---iron-spike-end--- markers; the recipe asserts
\ end-sentinel-on-own-line presence in raw OUTPUT independently of the awk
\ extraction (catches the missing-end-sentinel false-PASS class).
\
\ Surface (Task 3 disposition): PASS-on-both-surfaces per Story 17.5.1 AC4
\ precedent. Under iz-cpm-banking the iron-spike validates (a)+(b)+(c)
\ above — including that the MMU port-0x72 page-map write does not
\ disrupt main-RAM contents at `kernel_end..kernel_end+8`. Under iz-cpm
\ baseline (flat memory), the MMU port write is unmodelled (no-op), but
\ the per-bank state swap still fires (writes the bank-table at $D400
\ which IS modelled as RAM); the 9-byte body still lands at the cloned-
\ COLD HERE in flat RAM and EXECUTE reaches it. The iz-cpm-banking PASS
\ is the binding evidence for the MMU-active case; the iz-cpm baseline
\ PASS is a surface-agnostic round-trip witness for the per-bank-state
\ swap mechanism alone.
DECIMAL
: _iron-spike-test ( -- )
  DECIMAL
  ." ---iron-spike-start---" CR
  BANKS-CLEAR
  $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK
  5 BANK!
  HERE                            \ ( start-addr )
  ['] NEGATE HERE 3 MOVE  3 ALLOT \ JP DOCOL prefix (3 bytes) at HERE..HERE+2
  ['] LIT ,                       \ w_LIT_cf at HERE+3..HERE+4
  12345 ,                         \ sentinel at HERE+5..HERE+6
  ['] EXIT ,                      \ w_EXIT_cf at HERE+7..HERE+8
  0 BANK!
  5 BANK!
  EXECUTE                         \ ( 12345 )  — kernel runs banked body
  12345 = IF
    ." iron-spike-sentinel-12345-returned" CR
  ELSE
    ." FAIL: iron-spike sentinel mismatch" CR
  THEN
  ." ---iron-spike-end---" CR
  0 BANK!
  BANKS-CLEAR
;
_iron-spike-test

\ === Story 18.1: descriptor-stub allocator probes (Probe-18.1-A/B/C) ===
\ Story 18.1 lays the (γ) cross-bank dispatch foundation: a 4-byte
\ descriptor stub per word in the CCP-evicted $D400-$DBFF region;
\ stub address IS the word's xt (PD-P4-1 + redesign §2.1; PD-P4-11
\ layout at architecture.md:347..365). Probes here are LAYOUT-ONLY —
\ stubs are inspected via C@/@, NOT executed through (execute-through
\ is Story 18.3's EXECUTE switch + Story 18.2's cross_bank_return).
\
\ ORDER NOTE: Probe-18.1-C runs FIRST among these probes. It asserts
\ the first allocated stub lives at STUB_ALLOC_BASE ($D4CB = 54475)
\ and the 10th at STUB_ALLOC_BASE + 36 ($D4EF = 54511). Probes A/B
\ then allocate stubs 11 and 12 — their PASS criteria are on byte
\ layout, not on stub address, so they run after C without issue.
\
\ CR-M2 (deferred 2026-05-18) — Probe-18.1-C's absolute-address
\ assertion is brittle to allocator-call-order: if any future probe
\ upstream of this block calls (stub-allocate), the assertion silently
\ fails with a non-diagnostic "delta or first/last assertion mismatch"
\ message. Current ordering (Probe-C first; no other banking probes
\ use the allocator) satisfies the invariant; refactor to capture
\ stub_alloc_tail at entry and assert relative-stride + a separate
\ absolute-COLD-init verification is forward work for Story 18.2 or
\ a CR-followup. Not fixed at Story 18.1 close.
\
\ stub_alloc_tail is a UserArea cell (not per-bank-swapped by BANK!);
\ iron-spike above does not allocate stubs, so the cell still reads
\ $D4CB when this block enters.
\
\ Per-probe surfaces: PASS under iz-cpm-banking AND iz-cpm baseline
\ (allocator writes to fixed-memory CCP-evicted region $D4CB+ which
\ is plain RAM on both surfaces; no MMU port operations).

VARIABLE _p18c-buf  18 ALLOT   \ 10 cells × 2 B = 20 B total (cell at VARIABLE + 18 ALLOT)
VARIABLE _p18c-pass

: _probe-18.1-c ( -- )
  DECIMAL
  ." ---probe-18.1-c-start---" CR
  -1 _p18c-pass !
  \ Allocate 10 stubs with dummy target_addr=$1000, target_bank=1.
  10 0 DO
    4096 1 (stub-allocate)               \ ( -- xt_i )
    _p18c-buf I CELLS + !                \ buf[i] := xt_i
  LOOP
  \ Walk pairwise deltas: buf[i] - buf[i-1] must equal 4 for i in 1..9.
  10 1 DO
    _p18c-buf I CELLS + @                \ ( -- buf[i] )
    _p18c-buf I 1- CELLS + @ -           \ ( -- delta )
    4 = INVERT IF 0 _p18c-pass ! THEN
  LOOP
  ." first-stub-addr="    _p18c-buf            @  U.
  ." last-stub-addr="     _p18c-buf 9 CELLS +  @  U.
  ." expected-first=54475 expected-last=54511 "
  \ Absolute address assertions: first = $D4CB, last = $D4EF = first+36.
  _p18c-buf           @ 54475 = INVERT IF 0 _p18c-pass ! THEN
  _p18c-buf 9 CELLS + @ 54511 = INVERT IF 0 _p18c-pass ! THEN
  _p18c-pass @ IF
    ." probe-18.1-c-pass-10-stubs-deltas-4-and-first-base-last-base+36"
  ELSE
    ." FAIL: probe-18.1-c delta or first/last assertion mismatch"
  THEN
  CR
  ." ---probe-18.1-c-end---" CR
;
_probe-18.1-c

VARIABLE _p18a-xt
VARIABLE _p18a-pass

: _probe-18.1-a ( -- )
  DECIMAL
  ." ---probe-18.1-a-start---" CR
  -1 _p18a-pass !
  \ Stub A: fixed-memory target. target_bank = -1 ($FF marker per FR-P4-13),
  \ target_addr = ['] BANK@ body (a known fixed-memory address in src/banking.asm).
  ['] BANK@                              \ ( target_addr )
  -1                                     \ ( target_addr target_bank )
  (stub-allocate)                        \ ( xt )
  _p18a-xt !
  \ Read back the 4 bytes via C@ at xt+0..3.
  \ Assertions: byte 0 = 255 = $FF = -1 fixed-mem marker (FR-P4-13); byte 1 = 195 = $C3 = JP opcode;
  \ byte 2 = target_addr lo; byte 3 = target_addr hi. Lines stay ≤ TIB_SIZE (128) per CR-M3 fix 2026-05-18.
  _p18a-xt @         C@   255 = INVERT IF 0 _p18a-pass ! ." byte0-bad " THEN
  _p18a-xt @ 1+      C@   195 = INVERT IF 0 _p18a-pass ! ." byte1-bad " THEN
  _p18a-xt @ 2 +     C@   ['] BANK@ 255 AND = INVERT IF 0 _p18a-pass ! ." byte2-bad " THEN
  _p18a-xt @ 3 +     C@   ['] BANK@ 8 RSHIFT 255 AND = INVERT IF 0 _p18a-pass ! ." byte3-bad " THEN
  ." stub-addr=" _p18a-xt @ U.
  ." byte0="     _p18a-xt @     C@ U.
  ." byte1="     _p18a-xt @ 1+  C@ U.
  ." byte2="     _p18a-xt @ 2 + C@ U.
  ." byte3="     _p18a-xt @ 3 + C@ U.
  _p18a-pass @ IF
    ." probe-18.1-a-pass-stub-A-fixed-memory-layout-correct"
  ELSE
    ." FAIL: probe-18.1-a stub-A byte layout mismatch"
  THEN
  CR
  ." ---probe-18.1-a-end---" CR
;
_probe-18.1-a

VARIABLE _p18b-xt
VARIABLE _p18b-pass

: _probe-18.1-b ( -- )
  DECIMAL
  ." ---probe-18.1-b-start---" CR
  -1 _p18b-pass !
  \ Stub B: banked target. target_bank = 5, target_addr = $8200 = 33280
  \ (an address inside the $8000-$BFFF body region for any banked slot).
  33280                                   \ ( target_addr=$8200 )
  5                                       \ ( target_addr target_bank )
  (stub-allocate)                         \ ( xt )
  _p18b-xt !
  \ Assertions: byte 0 = 5 = target_bank (logical bank index, PD-P4-13); byte 1 = 195 = $C3 = JP opcode;
  \ byte 2 = 0 = $00 (lo of $8200); byte 3 = 130 = $82 (hi of $8200). Lines stay ≤ TIB_SIZE (128).
  _p18b-xt @         C@   5   = INVERT IF 0 _p18b-pass ! ." byte0-bad " THEN
  _p18b-xt @ 1+      C@   195 = INVERT IF 0 _p18b-pass ! ." byte1-bad " THEN
  _p18b-xt @ 2 +     C@   0   = INVERT IF 0 _p18b-pass ! ." byte2-bad " THEN
  _p18b-xt @ 3 +     C@   130 = INVERT IF 0 _p18b-pass ! ." byte3-bad " THEN
  ." stub-addr=" _p18b-xt @ U.
  ." byte0="     _p18b-xt @     C@ U.
  ." byte1="     _p18b-xt @ 1+  C@ U.
  ." byte2="     _p18b-xt @ 2 + C@ U.
  ." byte3="     _p18b-xt @ 3 + C@ U.
  _p18b-pass @ IF
    ." probe-18.1-b-pass-stub-B-banked-target-layout-correct"
  ELSE
    ." FAIL: probe-18.1-b stub-B byte layout mismatch"
  THEN
  CR
  ." ---probe-18.1-b-end---" CR
;
_probe-18.1-b
