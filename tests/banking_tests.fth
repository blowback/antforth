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
: _probe-1 ( -- )
  BANK-MAPPING-ON  BANK-MAPPING-ON  BANK-MAPPING-ON
  DEPTH 0 = IF
    ." PASS: banking-mapping-on-idempotent — BANK-MAPPING-ON ×3 leaves stack empty"
  ELSE
    ." FAIL: banking-mapping-on-idempotent — DEPTH = " DEPTH .
  THEN
  CR
;
_probe-1

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
: _probe-2 ( -- )
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
;
_probe-2

\ === Probe 3: BANK@ at boot returns 0 (Story 17.2 AC6 Probe 1) ===
\ Surface: iz-cpm-PASS / iz-cpm-banking-PASS / real-MicroBeast-PASS
\
\ Verifies (IY+UserArea.current_bank) is zero-initialised in COLD per
\ Story 17.1 step 8h. Surface-agnostic: the cell read does not touch
\ the MMU; passes on all three test surfaces.
: _probe-3 ( -- )
  BANK@
  DUP 0 = IF
    ." PASS: bank-at-zero — BANK@ returns 0 at boot"
    DROP
  ELSE
    ." FAIL: bank-at-zero — BANK@ returned " .
  THEN
  CR
;
_probe-3

\ === Probe 4: BANKS-CLEAR drives BANKS to 0 (Story 17.2 AC6 Probe 2; Story 17.5.2 rewrite) ===
\ Surface: iz-cpm-PASS / iz-cpm-banking-PASS / real-MicroBeast-PASS
\
\ Verifies BANKS-CLEAR resets (IY+UserArea.bank_count) to 0. The
\ original Story-17.2 assertion was "BANKS = 0 at boot" — that PASSed
\ pre-CL-parser, and the inline comment at the time noted "This
\ probe's assertion changes to the default-count at Story 17.4 close"
\ since Story 17.4's CL parser auto-populates 12 entries by default.
\ The assertion was never updated and the probe silently false-PASSed
\ via source-echo (Story 17.5.2 §"Consequence A"). Story 17.5.2
\ surfaced the run-time FAIL once probe 4 was colon-body-wrapped, and
\ rewrote the probe to BANKS-CLEAR + check 0 (project-lead-approved
\ scope expansion 2026-05-19 — Lesson 13-B "surface, file, fix once
\ known"). Side effect: BANKS-CLEAR at probe-4 head leaves bank_count=0
\ for probes 5+, which they all tolerate (probes 6/7/8/A explicitly
\ +BANK their own pages; probes 5/B/D/G all start from a defined
\ BANKS=0 head or are insensitive to it).
\ Surface-agnostic: kernel cell read, no MMU touch.
: _probe-4 ( -- )
  BANKS-CLEAR
  BANKS
  DUP 0 = IF
    ." PASS: banks-zero — BANKS-CLEAR drives BANKS to 0"
    DROP
  ELSE
    ." FAIL: banks-zero — BANKS returned " .
  THEN
  CR
;
_probe-4

\ === Probe 5: 99 BANK! raises ABORT" bank?" (Story 17.2 AC6 Probe 3) ===
\ Surface: iz-cpm-PASS / iz-cpm-banking-PASS / real-MicroBeast-PASS
\
\ Verifies BANK!'s precondition check (n < bank_count) fires for an
\ out-of-range argument. At Story 17.2 close, bank_count = 0 so every
\ BANK! invocation aborts; the precondition path is the only path
\ exercised on the dev-pass test surface. ABORT" routes through
\ THROW -2 (kernel-internal entry).
\
\ Wrapped via CATCH (Story 17.5.2 root-cause fix) — THROW -2 from
\ `99 BANK!` is caught inside the probe so the DEPTH check inspects
\ the post-recovery state (CATCH restores i*x to pre-execute depth
\ and pushes the throw value; DEPTH = 0 after `-2 =` consumes it).
\ The probe asserts DEPTH = 0 after the abort, NOT the printed
\ message (the message text "bank?" + the THROW-decoded "error -2:
\ ABORT\"" both land in the upstream-pipe stdout pre-prompt, but
\ verifying via DEPTH avoids the brittleness of an inline string
\ match).
\ Surface-agnostic: no MMU touch on the precondition-fail path.
: _99-bank-store ( -- ) 99 BANK! ;
: _probe-5 ( -- )
  ['] _99-bank-store CATCH -2 = IF
    DEPTH 0 = IF
      ." PASS: bank-store-abort-bank-q — 99 BANK! throws -2 (CATCH); DEPTH = 0"
    ELSE
      ." FAIL: bank-store-abort-bank-q — DEPTH after CATCH = " DEPTH .
    THEN
  ELSE
    ." FAIL: bank-store-abort-bank-q — 99 BANK! did not throw -2 (CATCH)"
  THEN
  CR
;
_probe-5

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
\
\ Story 17.5.2 added BANKS-CLEAR at head — Story-17.3 authoring assumed
\ BANKS=0 at entry (pre-17.4 CL parser); post-17.4 the active list starts
\ at 12 entries so the predicate `BANKS = 0` after `+BANK -BANK` was
\ stale. Run-time FAIL was masked by source-echo until Story 17.5.2
\ surfaced it; project-lead-approved scope expansion 2026-05-19 per
\ Lesson 13-B "surface, file, fix once known".
: _probe-c ( -- )
  BANKS-CLEAR
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
\ Story 17.5.2 root-cause-fixed probes 1-5 (top-level IF/ELSE/THEN →
\ colon-body wrappers); BASE residue from probe 2 eliminated;
\ defensive DECIMAL brackets retired here + at _dot-banks-setup.
: _do-29-+bank ( -- )
  29 0 DO $22 +BANK LOOP
;
: _do-one-more-+bank ( -- ) $22 +BANK ;
: _probe-plus-bank-cap ( -- )
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
\ Story 17.5.2 root-cause-fixed the BASE residue (probes 1-5 colon-body
\ wrap); the defensive DECIMAL reset retired. BANKS-CLEAR + manual 12×
\ $22 +BANK unroll stay load-bearing — sets up the dot-banks probes'
\ kernel-cell state at a known shape (12 entries all at PAGE 22, used=0,
\ free=16384, totals free = 12 * 16384 = 196608). The manual unroll is
\ defensive-but-cheap; replacing it with `12 0 DO $22 +BANK LOOP` is an
\ Epic-22 polish item, not in scope here.

: _dot-banks-setup ( -- )
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

\ === Story 18.2: sentinel-trampoline + EXIT-sentinel probes (A/B) ===
\ Story 18.2 lands the (S1 b) cross-bank EXIT mechanism: a
\ cross_bank_return: trampoline body in src/banking.asm + a sentinel
\ comparison extended into src/inner_interpreter.asm's EXIT_CODE
\ (PD-P4-2 / architecture.md:215..227; redesign §2.2 at
\ docs/antforth-banking-redesign.md:44..48). On EXIT, the popped
\ return-address is CP'd against cross_bank_return; a match dispatches
\ the trampoline, which pops caller_bank + target_addr from the
\ R-stack, restores the caller's bank via OUT (0x72) +
\ (IY+UserArea.current_bank), then JP (HL) to target_addr. The
\ intra-bank EXIT path (miss-path) is preserved at zero net behaviour
\ change (FR-P4-19).
\
\ Probe-18.2-A — synthesized cross-bank-return frame fires the
\ trampoline. Exercises AC1 (trampoline body) + AC2 (sentinel-IS-
\ trampoline-label) + AC3 (EXIT sentinel comparison). caller_bank ==
\ current_bank (= 0) so the bank-state-swap is a no-op (the trampoline
\ alone does NOT do BANK!'s per-bank triple swap; that lives at the
\ pusher side per Story 18.3 / Epic 19). The probe asserts that
\ control flows through the trampoline + chains the post-restore
\ JP-to-target via a second EXIT_CODE pop of the colon-body's DOCOL
\ frame, and that BANK@ readback at probe-tail equals caller_bank.
\
\ Probe-18.2-B — intra-bank EXIT round-trip (100 colon-body call/EXIT
\ cycles). Exercises AC3 miss-path + AC4 (intra-bank-invariance under
\ the new sentinel comparison overhead). Asserts BANK@ unchanged
\ across the loop and the round-trip completes cleanly (no orphan
\ R-stack entry / no crash).
\
\ Per-probe surfaces:
\   Probe-18.2-B is surface-agnostic — only exercises the intra-bank
\   AC3-miss path which is identical behaviour across iz-cpm,
\   iz-cpm-banking, and real hardware. Also implicitly exercised tens
\   of thousands of times across the test-repl regression suite (every
\   colon-body return goes through EXIT_CODE) — binding fitness witness
\   for FR-P4-19 zero-overhead-up-to-CP behaviour.
\   Probe-18.2-A is surface-degenerate by design: caller_bank ==
\   current_bank == 0 so the MMU port-0x72 write + current_bank cell
\   update execute but are observably idempotent. Under iz-cpm baseline
\   port 0x72 is unmodelled (no-op); under iz-cpm-banking and real
\   hardware the write is a same-page rewrite. The PASS verdict
\   therefore looks the same on every surface — what's actually being
\   tested is the SENTINEL DISPATCH PATH (EXIT_CODE detected the
\   sentinel, JPed to the trampoline, the trampoline ran through to
\   JP (HL), and the chained EXIT-via-xt(EXIT) popped the DOCOL-pushed
\   caller IP cleanly). AC1 steps 3-5 (port write effect / cell-write
\   effect under caller_bank ≠ current_bank) are observationally
\   covered at Story 18.3 / 18.5 once the pusher-side per-bank state
\   swap lands. Probe-18.2-A is NOT listed in test-repl-banking-skip
\   because the surface-agnostic PASS shape makes the SKIP-with-
\   rationale annotation moot at this story.
\
\ Per-probe state-leave: Probe-18.2-A ends in BANKS-CLEAR (empty bank
\ table). Probe-18.2-B does not depend on a particular bank-table
\ state and is positioned immediately after. Any future probe added
\ below 18.2-B that needs a seeded bank-table must re-seed via
\ BANKS-CLEAR / +BANK / 0 BANK!.

\ Extract cross_bank_return address from EXIT_CODE byte sequence.
\ ' EXIT  = address of `JP EXIT_CODE` opcode (3 B: C3 lo hi).
\ ' EXIT 1+ @  = EXIT_CODE address (always a safe extraction — EXIT's
\ DEFCODE shape is unconditional).
\ EXIT_CODE offset +20 = $C3 (JP cross_bank_return opcode);
\ EXIT_CODE offset +21..22 = cross_bank_return address (little-endian).
\ Layout-sensitive: if a future story rearranges EXIT_CODE bytes the
\ +21 fetch returns garbage. We defer the +21 read into a VARIABLE
\ populated INSIDE _probe-18.2-a's runtime sanity-check IF-branch, so
\ no garbage value is captured into the dictionary at load time and
\ no garbage address gets pushed onto the R-stack on a layout shift.
DECIMAL
' EXIT 1+ @           CONSTANT _xbr-exit-code   \ EXIT_CODE address (safe)
VARIABLE _xbr-addr-cell                         \ filled by _probe-18.2-a after sanity-pass

\ Inner word that synthesizes the 3-cell sentinel frame on the R-stack
\ then EXITs (the implicit `;` compiles EXIT). Field order on R-stack
\ (top-to-bottom after the three >R pushes):
\   ( sentinel, caller_bank, target_addr, _p18a-inner-DOCOL-IP, ... )
\ The implicit `;` EXIT pops sentinel → CP match in EXIT_CODE → JP
\ cross_bank_return → trampoline pops (caller_bank, target_addr) →
\ JP (HL) to target_addr = xt of EXIT → JP EXIT_CODE pops the
\ DOCOL-pushed IP (= caller's IP into _probe-18.2-a) → CP no-match
\ → NEXT resumes the caller normally.
\
\ caller_bank = 0 (matches the outer body's current_bank): the
\ trampoline's MMU port-0x72 write + current_bank update run in full
\ but are observably idempotent. The trampoline body still executes
\ every step in AC1 — the binding evidence that the dispatch path
\ works is that control returns to _probe-18.2-a body at all. Without
\ the sentinel mechanism, EXIT would interpret xbr-addr as a Forth IP
\ via NEXT and crash on the resulting JP-to-garbage. The probe
\ printing its PASS literal IS the witness that EXIT_CODE detected
\ the sentinel, JPed to cross_bank_return, ran the trampoline body
\ through to JP (HL), and the chained EXIT-via-target_addr popped
\ the DOCOL-pushed caller IP cleanly.
\
\ Why not caller_bank ≠ current_bank? The trampoline alone does NOT do
\ BANK!'s per-bank triple swap; that's Story 18.3's pusher-side scope.
\ Under iz-cpm-banking, switching MMU slot 2 ($8000-$BFFF) to a
\ different bank remaps any HERE-region content that lives there. By
\ the time _probe-18.2-a is compiled at file load, HERE is past $8000,
\ so the probe body itself sits in slot 2 — switching slot 2 underneath
\ the running code remaps the body's bytes mid-execution and crashes.
\ The "trampoline switched banks observable" test belongs at Story 18.3
\ once the pusher-side state swap is in place.
: _p18a-inner ( -- )
  ['] EXIT       >R            \ target_addr (top resume point after trampoline)
  0              >R            \ caller_bank = 0 (== current; trampoline no-op observable)
  _xbr-addr-cell @ >R          \ sentinel = cross_bank_return address (gated above)
;                              \ implicit EXIT fires sentinel-matching pop

VARIABLE _p18a-pass

: _probe-18.2-a ( -- )
  DECIMAL
  ." ---probe-18.2-a-start---" CR
  -1 _p18a-pass !
  \ Runtime sanity: EXIT_CODE+20 must be $C3 (JP opcode). On match,
  \ capture the +21..22 cell into _xbr-addr-cell and run the trampoline-
  \ firing inner word. On miss, the EXIT_CODE byte layout shifted —
  \ report and SKIP the inner word entirely (firing _p18a-inner with a
  \ stale sentinel would crash on JP-to-garbage after the CP miss).
  _xbr-exit-code 20 + C@ 195 = IF
    _xbr-exit-code 21 + @ _xbr-addr-cell !   \ cross_bank_return addr
    \ Seed at least 2 banks so active_pages[0] is populated for the
    \ trampoline's logical→physical lookup.
    BANKS-CLEAR
    $22 +BANK   $35 +BANK       \ active_pages[0]=$22, [1]=$35
    0 BANK!                     \ stay in bank 0 (caller_bank == current)
    \ Invoke trampoline-firing inner word; control returns here after
    \ EXIT_CODE → trampoline → JP target_addr=xt of EXIT → second
    \ EXIT_CODE pops the DOCOL-pushed _probe-18.2-a-IP → NEXT resumes.
    _p18a-inner
    \ Post-restore observable: BANK@ must equal caller_bank (= 0). The
    \ binding witness that the trampoline ran is that we reached this
    \ point at all (without the sentinel mechanism, the EXIT would
    \ crash on JP-to-garbage interpreted from xbr-addr as a Forth IP).
    BANK@ 0 = INVERT IF 0 _p18a-pass ! ." bank-not-0 " THEN
  ELSE
    0 _p18a-pass ! ." exit-code-layout-shift "
  THEN
  _p18a-pass @ IF
    ." probe-18.2-a-pass-cross-bank-EXIT-trampoline-restored"
  ELSE
    ." FAIL: probe-18.2-a bank not restored to 0 after trampoline"
  THEN CR
  ." ---probe-18.2-a-end---" CR
  BANKS-CLEAR
;
_probe-18.2-a

: _p18b-noop ;                  \ minimal intra-bank colon body
: _p18b-driver
  100 0 DO _p18b-noop LOOP      \ 100 intra-bank call/EXIT cycles
;

VARIABLE _p18b-pass
VARIABLE _p18b-bank-before

: _probe-18.2-b ( -- )
  DECIMAL
  ." ---probe-18.2-b-start---" CR
  -1 _p18b-pass !
  BANK@ _p18b-bank-before !
  _p18b-driver                  \ exercises EXIT_CODE miss-path × 100
  BANK@ _p18b-bank-before @  = INVERT IF 0 _p18b-pass ! ." bank-changed " THEN
  _p18b-pass @ IF
    ." probe-18.2-b-pass-intra-bank-EXIT-round-trip"
  ELSE
    ." FAIL: probe-18.2-b BANK@ changed across intra-bank EXIT loop"
  THEN CR
  ." ---probe-18.2-b-end---" CR
;
_probe-18.2-b

\ === Story 18.3: EXECUTE chokepoint + cross-bank dispatch probes (A/B/C/D/E) ===
\ Story 18.3 extends w_EXECUTE_cf (src/inner_interpreter.asm) with a 3-way
\ dispatch: legacy CFA (xt < $D4 high-byte → JP (HL) byte-for-byte preserves
\ the 975-PASS test-repl baseline), intra-bank stub (target_bank == BANK@ OR
\ -1 fixed-memory → INC HL / JP (HL) executes the in-stub JP), and cross-bank
\ stub (push 3-cell frame + LD DE,cross_bank_return + OUT (0x72), update
\ current_bank, JP stub+1). The callee's JP DOCOL pushes DE = sentinel as
\ the 4th cell, providing the sentinel-tagged top of the cross-bank frame
\ (PD-P4-1 + PD-P4-11 + PD-P4-2; architecture.md:207..363; redesign §3 at
\ docs/antforth-banking-redesign.md:54..63).
\
\ Probe-18.3-A — fixed-memory stub EXECUTE. Allocates a stub for ' BANK@
\ with target_bank = -1; EXECUTE dispatches via the intra-bank path
\ (target_bank == -1 marker matches). Surface-agnostic (no MMU change).
\
\ Probe-18.3-B — cross-bank stub EXECUTE from bank 0. Hand-built iron-spike-
\ shape body in bank 1's per-bank HERE (main RAM at kernel_end-vicinity per
\ project_bank_table_clone_at_cold). Allocate stub via (stub-allocate) with
\ target_bank = 1; EXECUTE from bank 0 fires cross-bank dispatch; callee
\ runs in bank-1 logical context; sentinel-trampoline restores bank 0;
\ assert TOS = 12345 (iron-spike sentinel) and BANK@ = 0. **Binding witness
\ for Story 18.2 CR-H2 deferred coverage** (MMU port-write + current_bank
\ cell write under caller_bank ≠ current_bank).
\
\ Probe-18.3-C — cross-bank stub EXECUTE from bank 7 (non-zero caller).
\ Same shape as Probe-18.3-B but with 7 BANK! before EXECUTE; assert BANK@
\ after EXECUTE == 7 (caller bank preserved across cross-bank round-trip).
\
\ Probe-18.3-D — data-stack passing across cross-bank EXECUTE. Hand-built
\ body consumes 1 cell, doubles it, pushes result; probe pushes 21,
\ EXECUTEs, asserts 42. Validates FR-P4-17 xt portability + data-stack
\ survives the bank switch.
\
\ Probe-18.3-E — cross-bank THROW survivability. Hand-built body raises
\ THROW -1; CATCH-wrapped cross-bank EXECUTE; assert CATCH returns the
\ throw code and BANK@ is restored. Validates NFR-P4-7.
\
\ Per-probe surfaces:
\   Probe-18.3-A is surface-agnostic (fixed-memory intra-bank dispatch).
\   Probes 18.3-B/C/D/E are PASS-on-banking-emulator-only — they require
\   real bank-table seeding and an MMU that honors port 0x72. Under iz-cpm
\   baseline, port 0x72 is unmodelled (no-op); the per-bank state swap
\   still fires but the cross-bank dispatch's MMU effect is invisible.
\   No test-repl-banking-skip entry is added (the PASS shape under iz-cpm
\   baseline matches under iz-cpm-banking for the probes that exercise
\   the kernel paths without depending on MMU effect — Probe-18.3-A; the
\   B/C/D/E probes don't run under iz-cpm baseline because of bank seeding
\   precondition).
\
\ Per-probe state-leave: Probes 18.3-B/C/D/E each end in BANKS-CLEAR
\ (empty bank table). Probe-18.3-A is bank-state-agnostic. The hand-built
\ bodies persist in main RAM but are not addressable after BANKS-CLEAR
\ (no stub points to them anymore after the test). Story 18.3 IS THE LAST
\ probe block in this file at dev-pass close; future probe additions must
\ re-seed banks before relying on any bank state.

\ Probe-18.3-A — fixed-memory stub EXECUTE (intra-bank via -1 marker).
VARIABLE _p18-3a-pass
: _probe-18.3-a ( -- )
  DECIMAL
  ." ---probe-18.3-a-start---" CR
  -1 _p18-3a-pass !
  BANK@                                \ ( bank_before )
  \ Allocate stub: target_addr = xt(BANK@), target_bank = -1 (fixed memory)
  ['] BANK@ -1 (stub-allocate)         \ ( bank_before stub_xt )
  EXECUTE                              \ runs BANK@ via stub; pushes current bank
  \ Stack now: ( bank_before bank_via_stub )
  = INVERT IF 0 _p18-3a-pass ! ." bank-mismatch " THEN
  _p18-3a-pass @ IF
    ." probe-18.3-a-pass-fixed-mem-stub-EXECUTE"
  ELSE
    ." FAIL: probe-18.3-a fixed-mem stub EXECUTE did not invoke BANK@ correctly"
  THEN CR
  ." ---probe-18.3-a-end---" CR
;
_probe-18.3-a


\ === Probes 18.3-B/C/E — DEFERRED to Epic 19 ===
\ Story 18.3 originally planned five cross-bank EXECUTE probes (-A
\ fixed-memory marker, -B cross-bank from bank 0, -C cross-bank from
\ non-zero caller, -D data-stack passing, -E THROW survivability).
\ Probe-18.3-A landed as a colon-body probe at dev-pass. CR follow-ups
\ (2026-05-18) added Probe-18.3-A2 (intra-bank-via-current-bank case;
\ CR-M4) and Probe-18.3-F (cross-bank dispatch empirical via interpret-
\ mode; CR-H1) — see below. Probe-18.3-F transitively covers Probe-
\ 18.3-D's data-stack-passing contract (42 → -42 across the bank
\ switch). Probes 18.3-B/C/E remain deferred to Epic 19 (B is
\ subsumed by F; C requires non-zero-caller-bank with dictionary
\ chain in slot 2; E requires THROW unwind sentinel-frame
\ recognition — see Q4 in story).
\
\ HAZARD — slot-2-swap-under-running-IP after dictionary crosses $8000:
\ By the time the .fth file load reaches my probes (~line 1100), bank 0's
\ HERE has crossed $8000 (verified: my colon bodies sit at $8600+). When
\ a colon-body probe executes the cross-bank EXECUTE machinery (which
\ does OUT (0x72) to swap slot 2 to the target bank's page), the running
\ probe body's bytes are remapped → NEXT-fetch reads garbage → kernel
\ hangs. Interpret-mode workaround fails too: after 1 BANK!, the dictionary
\ chain crosses into slot 2 (user-defined entries above $8000), making
\ FIND unreliable in the full-file-load context.
\
\ The iron-spike probe (file line 708) succeeds with the same mechanism
\ only because its colon-body xt happens to be at $79CF (below $8000 —
\ main RAM); it was defined when HERE was still in main RAM. Probe-18.3-A
\ succeeds because it uses ONLY the intra-bank stub-dispatch path (target
\ bank = -1 fixed-memory marker; no slot-2 swap invoked).
\
\ ACTUAL COVERAGE ACHIEVED (post-CR 2026-05-18):
\   - AC1 legacy-CFA discriminator: PASSes via the 975-PASS test-repl
\     regression baseline (every EXECUTE on a non-stub xt goes through
\     the legacy fall-through path).
\   - AC1 intra-bank stub via target_bank == -1: PASSes via Probe-18.3-A.
\   - AC1 intra-bank stub via target_bank == current_bank: PASSes via
\     Probe-18.3-A2 (CR-M4 follow-up).
\   - AC1 cross-bank dispatch (MMU swap + 3-cell push + chained EXIT):
\     PASSes via Probe-18.3-F (CR-H1 follow-up; required dispatch
\     bug fix landing the `HL = target_addr` load in .intra_bank
\     before JP — see src/inner_interpreter.asm:454..461 CR-H1 block).
\   - AC1 cross-bank from non-zero caller (C): NOT COVERED.
\   - AC6 cross-bank THROW survivability (E): NOT COVERED.
\
\ FORWARD COMMITMENT (post-CR 2026-05-18):
\ Story-18.2 CR-H2 deferred coverage (MMU port-write + current_bank
\ cell-write under caller_bank ≠ current_bank) is now CLOSED by
\ Probe-18.3-F. The remaining deferred surfaces (non-zero caller,
\ cross-bank THROW survivability) carry forward to Epic 19 + Epic 21.
\ Epic 19 (bank-aware `:`) lands per-bank dictionary plumbing that
\ puts user-defined words in per-bank HERE regions, naturally avoiding
\ the slot-2-swap-under-IP hazard for colon-body-driven cross-bank
\ tests; Epic 21 owns the cross-bank-THROW unwind sentinel-frame
\ recognition question (story Q4).
\
\ DISPOSITION (post-CR 2026-05-18):
\ During CR-H1 follow-up, attempting empirical cross-bank coverage via
\ interpret-mode revealed that the original dispatch was NOT JUST
\ untested but ACTIVELY BROKEN for DEFWORD targets: the in-stub
\ `JP target_addr` transferred PC to the callee's CF but left HL =
\ stub+1 (not CF). DOCOL relies on HL = CF to compute body = HL+3;
\ it instead computed stub+4 → wild NEXT → kernel cold-reboot.
\ Fix: read target_addr from stub bytes 2..3 into HL in .intra_bank
\ and JP directly (+5 B kernel). Probe-18.3-F now PASSes empirically.
\ The remaining deferred probes (-C non-zero-caller / -E THROW)
\ retain the slot-2-hazard exposure and carry forward to Epic 19 +
\ Epic 21.

\ === Probe-18.3-A2 — intra-bank stub via target_bank == current_bank ===
\ CR-M4 follow-up (2026-05-18). Probe-18.3-A exercises only the
\ second JR Z in the EXECUTE dispatch (CP $FF / JR Z = -1 marker).
\ This probe exercises the FIRST JR Z (CP (IY+current_bank) / JR Z =
\ banked-but-current-bank). Pre-condition: current_bank == 0
\ (default). Allocates a stub with target_bank = 0; EXECUTE dispatches
\ via the (IY+current_bank) match branch.
VARIABLE _p18-3a2-pass
: _probe-18.3-a2 ( -- )
  DECIMAL
  ." ---probe-18.3-a2-start---" CR
  -1 _p18-3a2-pass !
  BANK@                                \ ( bank_before — = 0 by default )
  \ Allocate stub: target_addr = xt(BANK@), target_bank = 0 (current bank)
  ['] BANK@ 0 (stub-allocate)          \ ( bank_before stub_xt )
  EXECUTE                              \ intra-bank dispatch via CP (IY+d) JR Z
  = INVERT IF 0 _p18-3a2-pass ! ." bank-mismatch " THEN
  _p18-3a2-pass @ IF
    ." probe-18.3-a2-pass-intra-bank-via-current-bank-EXECUTE"
  ELSE
    ." FAIL: probe-18.3-a2 intra-bank-via-current-bank stub EXECUTE failed"
  THEN CR
  ." ---probe-18.3-a2-end---" CR
;
_probe-18.3-a2

\ === Probe-18.3-F — cross-bank EXECUTE empirical (interpret-mode) ===
\ CR-H1 follow-up (2026-05-18). The cross-bank EXECUTE call MUST run
\ from interpret mode (NOT a colon body), so the running code during
\ the dispatch's MMU slot-2 swap is INTERPRET (kernel-resident, body
\ < $8000) and is unaffected by the swap. Cross-bank target is the
\ kernel DEFWORD NEGATE (xt < $D400, main-RAM CFA): the in-stub JP
\ transfers to w_NEGATE_cf in main RAM, DOCOL pushes DE =
\ cross_bank_return as the sentinel, body runs (LIT 0, SWAP, MINUS,
\ EXIT), then EXIT_CODE + trampoline + chained EXIT_CODE restore the
\ caller's bank and resume INTERPRET. Validates AC1 cross-bank
\ dispatch + closes Story-18.2 CR-H2 deferred MMU port-write +
\ current_bank cell-write coverage under caller_bank ≠ current_bank.
\
\ Output formatting goes through a colon-body helper (_p18f-check)
\ that is invoked AFTER the trampoline has restored bank 0 — slot 2
\ is back to its original page by then, so calling a slot-2-resident
\ colon body is safe again.

\ Helpers (colon-bodies; called via outer-interpreter EXECUTE after the
\ trampoline has restored bank 0 / slot 2). Note: `."`, `IF`, `ELSE`,
\ `THEN` are compile-only in antforth, so sentinel printing and
\ assertions cannot live as raw interpret-mode tokens — they must be
\ wrapped in colon bodies.
: _p18f-start  ." ---probe-18.3-f-start---" CR ;
: _p18f-end    ." ---probe-18.3-f-end---" CR ;
VARIABLE _p18f-pass
: _p18f-check ( negate_result -- )
  -1 _p18f-pass !
  -42 = INVERT IF 0 _p18f-pass ! ." stack-mismatch " THEN
  BANK@ 0 = INVERT IF 0 _p18f-pass ! ." bank-not-restored " THEN
  _p18f-pass @ IF
    ." probe-18.3-f-pass-cross-bank-EXECUTE-NEGATE-roundtrip"
  ELSE
    ." FAIL: probe-18.3-f cross-bank EXECUTE round-trip failed"
  THEN CR
;

\ Interpret-mode probe — no enclosing colon body for the EXECUTE step.
_p18f-start
BANKS-CLEAR
$22 +BANK $35 +BANK                    \ active_pages[0]=$22, [1]=$35
0 BANK!                                \ ensure caller is in bank 0
42                                     \ test value (NEGATE will → -42)
' NEGATE 1 (stub-allocate)             \ stub: target_bank=1, target=NEGATE
EXECUTE                                \ ← CROSS-BANK DISPATCH FIRES HERE
_p18f-check                            \ assert ( -42 ) on stack + BANK@=0
BANKS-CLEAR
_p18f-end

\ === Probe-18.4-A/B/C — BANK-OF one-byte read of descriptor-stub byte 0 ===
\ Story 18.4 (FR-P4-5). BANK-OF is a fixed-memory DEFCODE word that
\ reads byte 0 of a stub (target_bank, signed) and returns it sign-
\ extended into a single cell. No MMU writes, no R-stack pushes, no
\ inner-interpreter excursion — Probes A + B are surface-agnostic
\ (PASS on iz-cpm + iz-cpm-banking + hardware).
\
\ Probe-A: AC4(a). Allocate stub with target_bank = -1 (fixed-mem
\ marker per FR-P4-13); BANK-OF must read $FF → sign-extend → -1.
\ Probe-B: AC4(b). Allocate stub with target_bank = 5; BANK-OF
\ must read $05 → 5.
\ Probe-C: AC4(c) — xt portability (FR-P4-17). Pre-resolves the
\ BANK-OF xt (a fixed-memory CFA) BEFORE the first BANK! so the
\ cross-bank EXECUTE dispatches via the legacy-CFA path; reads the
\ same stub byte 0 from bank-1 and bank-0 contexts. Q1 disposition:
\ option (a) — interpret-mode pre-resolve-and-EXECUTE; falls back
\ to deferral if the FIND-chain-in-slot-2 hazard fires (Story-18.3
\ Probes B/C/D/E precedent at file line ~1117).

\ Output helpers (colon-body sentinel printers — kept fixed-memory-
\ free of cross-bank concerns since BANK-OF Probes A + B never swap
\ banks).
: _p18a-start  ." ---probe-18.4-a-start---" CR ;
: _p18a-end    ." ---probe-18.4-a-end---"   CR ;
: _p18b-start  ." ---probe-18.4-b-start---" CR ;
: _p18b-end    ." ---probe-18.4-b-end---"   CR ;
: _p18c-start  ." ---probe-18.4-c-start---" CR ;
: _p18c-end    ." ---probe-18.4-c-end---"   CR ;

: _p18-4a-check ( bank-of-result -- )
  -1 = IF
    ." probe-18.4-a-pass-fixed-mem-marker"
  ELSE
    ." FAIL: probe-18.4-a fixed-mem marker BANK-OF returned non-(-1)"
  THEN CR
;

: _p18-4b-check ( bank-of-result -- )
  5 = IF
    ." probe-18.4-b-pass-banked-bank-5"
  ELSE
    ." FAIL: probe-18.4-b banked-bank-5 BANK-OF returned non-5"
  THEN CR
;

\ Probe-18.4-A — fixed-memory marker. Interpret-mode (no enclosing
\ body). ' BANK@ pushes xt of BANK@ (any fixed-memory xt works);
\ (stub-allocate) stores target_bank = -1 → byte 0 = $FF.
_p18a-start
' BANK@ -1 (stub-allocate)             \ ( stub_xt )
BANK-OF                                \ ( -1 expected )
_p18-4a-check
_p18a-end

\ Probe-18.4-B — banked-bank-5 marker. (stub-allocate) stores
\ target_bank = 5 → byte 0 = $05. No MMU activity invoked.
_p18b-start
0 5 (stub-allocate)                    \ ( stub_xt )  target_addr=0 placeholder
BANK-OF                                \ ( 5 expected )
_p18-4b-check
_p18b-end

\ Probe-18.4-C — DEFERRED to Epic 19. AC4(c) xt-portability across
\ BANK! (FR-P4-17). Q1 disposition at dev-pass: option (b) — defer.
\
\ Rationale: A direct interpret-mode probe `1 BANK! ... <xt> EXECUTE
\ ... 0 BANK!` requires the outer interpreter to FIND tokens (DUP,
\ EXECUTE, BANK!, integer literals) WHILE bank=1 is active. BANK!'s
\ triple swap (banking.asm:170..193) saves/loads HERE, LATEST, and
\ the FORTH-WORDLIST WORDLIST_NEXT cell — but the FORTH-WORDLIST's
\ hash-bucket array is NOT swapped (it is the kernel-resident
\ canonical wordlist; src/wordlists.asm:328..343). Bucket cells
\ already point at user-defined dict entries above $8000 by the
\ time this test file has loaded (HERE has crossed $8000 well
\ before line 1100; see Story-18.3 HAZARD note at file line
\ ~1117). After `1 BANK!`, slot 2 is remapped to bank 1's page,
\ and the next outer-interpreter FIND walks the SAME bucket
\ cells, dereferencing pointers into slot 2 where bank-1's page
\ holds either uninitialised bytes or unrelated content → wrong
\ link / undefined word / hang.
\
\ Cross-bank-EXECUTE-through-BANK-OF doesn't work either: the
\ cross-bank dispatch (inner_interpreter.asm:332..337) is
\ DEFWORD-only — it relies on the callee's JP DOCOL pushing the
\ sentinel return-address. BANK-OF is DEFCODE; its NEXT does not
\ EXIT, so the sentinel-trampoline mechanism never fires for a
\ cross-bank stub targeting BANK-OF.
\
\ Forward commitment to Epic 19: bank-aware `:` lands per-bank
\ HERE / LATEST plumbing and (per Epic 19 spec) per-bank wordlist
\ chains, which removes the FIND-walks-through-slot-2 hazard
\ structurally. AC4(c)'s xt-portability witness is then a clean
\ probe in that epic's test surface. The FR-P4-17 property is
\ provable structurally in the meantime: stubs live in fixed
\ memory ($D4CB+) which is unaffected by any slot-2 swap, so
\ BANK-OF reading byte 0 from a stub xt returns the same value
\ regardless of BANK@ — Probes A + B already exercise the read
\ path; AC4(c) is the across-bank witness that the same xt
\ value remains a valid argument across BANK!.
\
\ Marker block preserves M4 end-sentinel discipline so future
\ Epic-19 dev pass can inject the real probe in-place.
_p18c-start
." probe-18.4-c-deferred-to-epic-19-xt-portability-witness"
CR
_p18c-end


\ === Probe-18.5-A/B/C/D — IN-BANK kernel-blessed CATCH-safe ===
\ Story 18.5 (FR-P4-4). IN-BANK ( n xt -- ) saves caller bank,
\ switches to bank n, EXECUTEs xt, restores caller bank — with
\ CATCH-safety on the THROW unwind path (DEFWORD with internal
\ CATCH wrap; saved bank stashed via Forth return-stack >R / R>
\ ABOVE the internal CATCH frame so it survives the unwind).
\
\ Probe-A: AC4(a) basic round-trip. Interpret-mode invocation
\ (NOT a colon body) so the running interpreter is kernel-
\ resident (< $8000) and unaffected by BANK!'s slot-2 swap —
\ same shape as Probe-18.3-F (CR-H1 follow-up). xt is the
\ fixed-memory DEFCODE BANK@ (CFA < $D400 main-RAM) so the
\ EXECUTE'd body remains addressable across the bank switch.
\ Target = bank 1 (page $35), caller = bank 0 (page $22); IN-
\ BANK switches → BANK@ pushes 1 (current bank in target) →
\ IN-BANK restores bank 0. Asserts (a) stack TOS after IN-BANK
\ = 1, (b) BANK@ after IN-BANK = 0 (caller bank restored).
\
\ Probe-B: AC4(b) nested IN-BANK. DEFERRED to Epic 19 per the
\ slot-2-remap-under-IP hazard (Probe-18.3-B/C/E / Probe-18.4-C
\ precedent at file line ~1097 and ~1302). True nesting requires
\ the outer xt to be a colon body that itself calls IN-BANK; at
\ probe-time HERE has crossed $8000, so user-defined colon
\ bodies sit in slot 2 — BANK! within them remaps slot 2 under
\ the running IP → kernel halt. The re-entrancy property of
\ Q2's R-stack stash discipline (each nested IN-BANK gets its
\ own >R-stashed bank cell, isolated by the internal CATCH
\ frame placement) is provable structurally: every IN-BANK
\ invocation issues its OWN >R before its OWN CATCH, so the
\ saved-bank cells form a LIFO matching the IN-BANK call
\ nesting; Forth R-stack discipline guarantees no cross-call
\ aliasing. Epic 19's per-bank dictionary plumbing puts user-
\ defined colon bodies in per-bank HERE regions, naturally
\ removing the hazard for empirical nesting validation.
\
\ Probe-C: AC4(c) CATCH-safe variant (FR-P4-4 binding case).
\ Interpret-mode invocation (same hazard-avoidance pattern as
\ Probe-A). xt = ' ABORT (DEFCODE, fixed-memory CFA < $D400);
\ ABORT raises -1 THROW. CATCH wraps the IN-BANK call so the
\ -1 is caught at the test-level CATCH, not the uncaught
\ handler. Asserts (a) TOS after CATCH = -1 (throw code
\ propagated), (b) BANK@ after CATCH = 0 (caller's bank
\ restored via the >R / R> stash on the unwind path).
\
\ Probe-D: AC4(d) cross-bank IN-BANK xt-portability witness.
\ DEFERRED to Epic 19 per Q3 disposition in story Dev Notes —
\ slot-2-remap-under-IP hazard precludes empirical validation
\ of the (xt portability across BANK!) property at this story
\ scope; structurally provable per Probe-18.4-C precedent
\ (stubs live in fixed memory $D4CB+ unaffected by any slot-2
\ swap, so stub-xts remain valid arguments across BANK!).

\ Output helpers (colon-body sentinel printers + check words).
\ Names use _p18-5* per Story 18.4 CR-M1 disambiguation
\ convention (avoids collision with prior 18.x probe names).
: _p18-5a-start  ." ---probe-18.5-a-start---" CR ;
: _p18-5a-end    ." ---probe-18.5-a-end---"   CR ;
: _p18-5b-start  ." ---probe-18.5-b-start---" CR ;
: _p18-5b-end    ." ---probe-18.5-b-end---"   CR ;
: _p18-5c-start  ." ---probe-18.5-c-start---" CR ;
: _p18-5c-end    ." ---probe-18.5-c-end---"   CR ;
: _p18-5d-start  ." ---probe-18.5-d-start---" CR ;
: _p18-5d-end    ." ---probe-18.5-d-end---"   CR ;

VARIABLE _p18-5a-pass
: _p18-5a-check ( inner_bank caller_bank_post -- )
  -1 _p18-5a-pass !
  0 = INVERT IF 0 _p18-5a-pass ! ." caller-bank-not-restored " THEN
  1 = INVERT IF 0 _p18-5a-pass ! ." inner-bank-mismatch " THEN
  _p18-5a-pass @ IF
    ." probe-18.5-a-pass-in-bank-roundtrip"
  ELSE
    ." FAIL: probe-18.5-a IN-BANK round-trip failed"
  THEN CR
;

VARIABLE _p18-5c-pass
: _p18-5c-check ( throw_code caller_bank_post -- )
  -1 _p18-5c-pass !
  0 = INVERT IF 0 _p18-5c-pass ! ." caller-bank-not-restored " THEN
  -1 = INVERT IF 0 _p18-5c-pass ! ." throw-code-mismatch " THEN
  _p18-5c-pass @ IF
    ." probe-18.5-c-pass-in-bank-catch-safe"
  ELSE
    ." FAIL: probe-18.5-c IN-BANK CATCH-safe THROW unwind failed"
  THEN CR
;

\ Probe-18.5-A — basic round-trip. Interpret-mode invocation;
\ target = bank 1, xt = ' BANK@ (fixed-memory DEFCODE). After
\ IN-BANK: stack has 1 (BANK@'s output during the inner-bank
\ context), BANK@ post = 0 (caller bank restored).
_p18-5a-start
BANKS-CLEAR
$22 +BANK $35 +BANK                    \ active_pages[0]=$22, [1]=$35
0 BANK!                                \ ensure caller is in bank 0
1 ' BANK@ IN-BANK                      \ ← IN-BANK FIRES HERE; pushes 1
BANK@                                  \ ( 1 0 expected )
_p18-5a-check
BANKS-CLEAR
_p18-5a-end

\ Probe-18.5-B — DEFERRED to Epic 19. See block comment above.
\ Marker block preserves M4 end-sentinel discipline so Epic-19
\ dev pass (per-bank dictionary plumbing) can inject the real
\ nested-IN-BANK probe in-place.
_p18-5b-start
." probe-18.5-b-deferred-to-epic-19-nested-in-bank-re-entrancy-witness"
CR
_p18-5b-end

\ Probe-18.5-C — CATCH-safe THROW unwind. Interpret-mode
\ invocation; xt = ' ABORT (DEFCODE; raises -1 THROW). CATCH
\ wraps IN-BANK so -1 lands on data stack; BANK@ post-CATCH
\ must equal caller's pre-IN-BANK bank (= 0).
_p18-5c-start
BANKS-CLEAR
$22 +BANK $35 +BANK                    \ same bank setup as Probe-A
0 BANK!                                \ caller in bank 0
1 ' ABORT ' IN-BANK CATCH              \ ( i*x -1 expected; i*x = ( 1 xt_ABORT ) )
BANK@                                  \ ( i*x -1 0 expected )
_p18-5c-check                          \ consumes top 2 ( -1 0 ); i*x residue remains
2DROP                                  \ M1: drop i*x residue ( 1 xt_ABORT )
BANKS-CLEAR
_p18-5c-end

\ Probe-18.5-D — DEFERRED to Epic 19. See block comment above.
\ Marker block preserves M4 end-sentinel discipline so Epic-19
\ dev pass can inject the cross-bank IN-BANK xt-portability
\ witness in-place.
_p18-5d-start
." probe-18.5-d-deferred-to-epic-19-cross-bank-in-bank-xt-portability"
CR
_p18-5d-end


\ Probe-18.5-E — AC2 narrow binding: caller's bank restored on
\ caught THROW unwind, validated via a USER-variable stash so we
\ are independent of antforth-CATCH's i*x deeper-cell preservation
\ limitations (Story-18.5 code-review H1: antforth's CATCH frame
\ preserves only the i*x TOS-cell via Story-11.4.1 saved-BC; deeper
\ cells may be touched by xt's PUSH/POP/SWAP traffic at-or-above
\ SP_safe). Probe-C's data-stack-only check is sufficient for AC2's
\ wording, but Probe-E gives a deeper-cell-independent witness for
\ readers tracing the H1 disposition.
\
\ Mechanism: stash pre-IN-BANK BANK@ into a VARIABLE; run IN-BANK
\ inside CATCH with xt = ' ABORT (raises -1 THROW); after CATCH,
\ stash post-CATCH BANK@ into a second VARIABLE. Compare the two
\ via memory peek (no reliance on data stack contents below the
\ TOS pair). PASS marker iff (a) stashed pre = stashed post AND
\ (b) TOS = -1 (throw code propagated).
VARIABLE _p18-5e-pre
VARIABLE _p18-5e-post
VARIABLE _p18-5e-pass
: _p18-5e-start  ." ---probe-18.5-e-start---" CR ;
: _p18-5e-end    ." ---probe-18.5-e-end---"   CR ;
: _p18-5e-check ( throw_code -- )
  -1 _p18-5e-pass !
  -1 = INVERT IF 0 _p18-5e-pass ! ." throw-code-mismatch " THEN
  _p18-5e-pre @ _p18-5e-post @ = INVERT IF
    0 _p18-5e-pass !  ." caller-bank-not-restored-via-stash "
  THEN
  _p18-5e-pass @ IF
    ." probe-18.5-e-pass-in-bank-catch-safe-stash-witness"
  ELSE
    ." FAIL: probe-18.5-e IN-BANK CATCH-safe stash witness failed"
  THEN CR
;

_p18-5e-start
BANKS-CLEAR
$22 +BANK $35 +BANK                    \ active_pages[0]=$22, [1]=$35
0 BANK!                                \ caller in bank 0
BANK@ _p18-5e-pre !                    \ stash pre-IN-BANK bank
1 ' ABORT ' IN-BANK CATCH              \ ( i*x -1 expected )
BANK@ _p18-5e-post !                   \ stash post-CATCH bank
_p18-5e-check                          \ consumes -1; stashes carry the witness
DROP DROP                              \ drop i*x residue ( 1 xt_ABORT )
BANKS-CLEAR
_p18-5e-end

\ === Story 18.5.1 probes: i*x deeper-cell preservation on caught THROW ===
\ Reproducer A and B from the Story 18.5 H1 disposition. Both are PASS-only
\ under option (b) framework patch (this story); under option (a) they would
\ have carried PARTIAL-with-rationale verdicts.
\
\ Probe-18.5.1-A (Reproducer B — generic CATCH framework): defines a
\ SWAP-ABORT colon word and verifies `100 200 ' SWAP-ABORT CATCH` yields
\ ANS §9.6.1.0875 cell-content preservation `<3> 100 200 -1`. Pre-option-(b)
\ this returned `<3> 200 200 -1` (i*x's second-from-top corrupted by SWAP's
\ POP HL / PUSH BC at [SP_safe + 0]). VARIABLE-stashed witness avoids
\ data-stack arithmetic that would itself be subject to the same gap.
\
\ Probe-18.5.1-B (Reproducer A — IN-BANK exposure): verifies
\ `1 ' ABORT ' IN-BANK CATCH` yields `<3> 1 17262 -1` (where 17262 is the
\ xt_ABORT address restored from saved-BC at outer CATCH frame +2). The
\ second-from-top cell "1" is preserved post-option-(b); pre-option-(b)
\ it was overwritten with the outer CATCH frame_base leaked via THROW's
\ PUSH HL / POP IX idiom.
\
\ Both probes use the _p18-5-1* variable-name disambiguation pattern
\ (Story 18.4 CR-M1 precedent) and the SENTINEL-BOUNDED marker pattern.
\ Lines kept ≤ TIB_SIZE=128 per feedback_tib_size_inline_comments.md.

VARIABLE _p18-5-1a-c1
VARIABLE _p18-5-1a-c2
VARIABLE _p18-5-1a-tos
VARIABLE _p18-5-1a-pass
: _p18-5-1a-start ." ---probe-18.5.1-a-start---" CR ;
: _p18-5-1a-end   ." ---probe-18.5.1-a-end---"   CR ;
: SWAP-ABORT SWAP ABORT ;
: _p18-5-1a-check ( c1 c2 tos -- )
  -1 _p18-5-1a-pass !
  _p18-5-1a-tos !
  _p18-5-1a-c2  !
  _p18-5-1a-c1  !
  _p18-5-1a-c1  @ 100 = INVERT IF 0 _p18-5-1a-pass !
    ." i*x-deepest-mismatch " THEN
  _p18-5-1a-c2  @ 200 = INVERT IF 0 _p18-5-1a-pass !
    ." i*x-second-mismatch " THEN
  _p18-5-1a-tos @ -1  = INVERT IF 0 _p18-5-1a-pass !
    ." throw-code-mismatch " THEN
  _p18-5-1a-pass @ IF
    ." probe-18.5.1-a-pass-generic-catch-ix-preservation"
  ELSE
    ." FAIL: probe-18.5.1-a generic SWAP-ABORT i*x preservation failed"
  THEN CR ;

_p18-5-1a-start
100 200 ' SWAP-ABORT CATCH       \ ( 100 200 -1 expected post-option-(b) )
_p18-5-1a-check                  \ consumes 3 cells; witness in VARIABLEs
_p18-5-1a-end

VARIABLE _p18-5-1b-c1
VARIABLE _p18-5-1b-c2
VARIABLE _p18-5-1b-tos
VARIABLE _p18-5-1b-pass
: _p18-5-1b-start ." ---probe-18.5.1-b-start---" CR ;
: _p18-5-1b-end   ." ---probe-18.5.1-b-end---"   CR ;
: _p18-5-1b-check ( c1 c2 tos -- )
  -1 _p18-5-1b-pass !
  _p18-5-1b-tos !
  _p18-5-1b-c2  !
  _p18-5-1b-c1  !
  _p18-5-1b-c1  @ 1 = INVERT IF 0 _p18-5-1b-pass !
    ." in-bank-i*x-deepest-mismatch " THEN
  \ c1 (deepest) is the load-bearing assertion for Story 18.5.1: pre-
  \ option-(b) it leaked the outer CATCH frame_base. c2 (= i*x's TOS-cell,
  \ = xt_ABORT) is preserved by Story 11.4.1's saved-BC slot regardless of
  \ this story — we soft-check non-zero only (a literal-address check
  \ would couple the probe to dictionary layout for no extra coverage).
  _p18-5-1b-c2  @ 0= IF 0 _p18-5-1b-pass !
    ." in-bank-i*x-second-zero " THEN
  _p18-5-1b-tos @ -1 = INVERT IF 0 _p18-5-1b-pass !
    ." in-bank-throw-code-mismatch " THEN
  _p18-5-1b-pass @ IF
    ." probe-18.5.1-b-pass-in-bank-ix-preservation"
  ELSE
    ." FAIL: probe-18.5.1-b IN-BANK i*x preservation failed"
  THEN CR ;

_p18-5-1b-start
BANKS-CLEAR
$22 +BANK $35 +BANK
0 BANK!
1 ' ABORT ' IN-BANK CATCH        \ ( 1 xt_ABORT -1 expected post-option-(b) )
_p18-5-1b-check                  \ consumes 3 cells; witness in VARIABLEs
BANKS-CLEAR
_p18-5-1b-end

\ === Story 19.1 — per-bank HERE / LATEST / , / C, / COMPILE, =================
\
\ Story 19.1's substantive new surface is the LATEST DEFCODE in
\ src/memory.asm (variable-style: pushes the address of the LATEST cell
\ in UserArea). AC1/AC3/AC4 are documentation-only ACs (no functional
\ kernel code change): the existing UserArea.here / UserArea.latest
\ read/write paths in src/memory.asm are per-bank-correct by construction
\ via BANK!'s LDIR triple-swap at src/banking.asm:170..193 (PD-P4-3,
\ architecture.md:229..241). The "extension" specified by the AC wording
\ is a documentation closure rather than a kernel code edit; the source-
\ citation comments per AC6 record the per-bank semantic at each touchpoint
\ (HERE/LATEST/,/C,/COMPILE,).
\
\ Probe surface scope notes:
\
\   Probe-19.1-A (AC2) — LATEST as a Forth word: verifies LATEST returns
\   the address of UserArea.latest (variable-style per Q1 dev-pass disposition),
\   LATEST @ / LATEST ! round-trip. Bank-0-only test (no bank-switching);
\   reliable under the post-18.5.1-baseline test-file state.
\
\   Probe-19.1-B (AC1/AC3/AC4 architectural witness) — bank-table[5] vs
\   bank-table[0] divergence via raw memory read at $D400 / $D41E (the
\   bank-table[] base + bank-5 offset). Confirms per-bank dictionary
\   state exists in fixed memory and bank-table[0] has diverged from the
\   COLD-LDIR-cloned bank-table[5] snapshot through the accumulated test
\   probes' definitions. Bank-0-only test.
\
\ AC7 probes (a)/(b)/(c)/(d)/(e) — per-bank behavioural verification via
\ direct bank-switching — DEFERRED to Story 19.2 (bank-aware `:` lands
\ user-word bodies in the current bank's address space, fixing the test-
\ surface limitation that user-word entries above $8000 become inaccessible
\ after BANK!-switching). Same deferred-to-Epic-19 pattern as Story 18.5
\ probes (b)/(d) which SKIP-deferred for the same root cause (per-bank
\ dictionary not yet plumbed). See feedback_no_preexisting_discharge.md
\ "surface, file, fix" — the underlying defect is the test-surface
\ limitation, not the kernel; Story 19.2's bank-aware `:` is the structural
\ fix.

\ === Probe-19.1-A: LATEST DEFCODE word semantic (AC2 closure) ===
\ Verifies LATEST returns the address of UserArea.latest (variable-style);
\ verifies LATEST @ and LATEST ! round-trip. All in bank 0; no bank-switching.
\ Tests:
\   1. LATEST returns a non-zero cell address (specifically user_area + 6)
\   2. LATEST ! followed by LATEST @ round-trips the value
\   3. LATEST cell address is stable across multiple LATEST invocations
VARIABLE _p19-1a-addr1
VARIABLE _p19-1a-addr2
VARIABLE _p19-1a-saved
VARIABLE _p19-1a-readback
VARIABLE _p19-1a-pass
: _p19-1a-start ." ---probe-19.1-a-start---" CR ;
: _p19-1a-end   ." ---probe-19.1-a-end---"   CR ;
: _p19-1a-check
  -1 _p19-1a-pass !
  _p19-1a-addr1 @ 0= IF 0 _p19-1a-pass !
    ." latest-addr-zero " THEN
  _p19-1a-addr1 @ _p19-1a-addr2 @ = INVERT IF 0 _p19-1a-pass !
    ." latest-addr-not-stable " THEN
  _p19-1a-readback @ 12345 = INVERT IF 0 _p19-1a-pass !
    ." latest-roundtrip-mismatch " THEN
  _p19-1a-pass @ IF
    ." probe-19.1-a-pass-latest-word-semantic"
  ELSE
    ." FAIL: probe-19.1-a LATEST word semantic test failed"
  THEN CR ;
_p19-1a-start
LATEST _p19-1a-addr1 !
LATEST _p19-1a-addr2 !
LATEST @ _p19-1a-saved !
12345 LATEST !
LATEST @ _p19-1a-readback !
_p19-1a-saved @ LATEST !
_p19-1a-check
_p19-1a-end

\ === Probe-19.1-B: bank-table[] LDIR-clone witness (AC1/AC3/AC4) ===
\ Reads bank-table[0].here (fixed memory at $D400) and bank-table[5].here
\ (fixed memory at $D41E = $D400 + 5*6, since each entry is the 6-byte
\ (here, latest, wordlist_head) triple per architecture.md:229..241).
\ Asserts both are non-zero. This witnesses two architectural invariants:
\   (i) COLD's snapshot of LIVE → bank-table[0] (antforth.asm:144..183)
\       ran and produced a non-zero HERE for the portal page.
\   (ii) COLD's LDIR-clone of bank-table[0] → bank-table[1..28]
\        (antforth.asm:184..197) propagated to slot [5], so the per-bank
\        triple infrastructure exists in fixed-memory storage at $D400+.
\
\ NB the probe was originally specified to also assert
\ `bt0-here != bt5-here` (per-bank-divergence witness), but that
\ property is *test-history-dependent* — it requires accumulated
\ `5 BANK!`+compile+`0 BANK!` cycles from earlier test surfaces (e.g.,
\ the iron-spike at tests/banking_tests.fth:705..728 writes bank-5),
\ NOT a load-bearing invariant of Story 19.1. At fresh-boot (no test
\ pollution), all 29 bank-table entries are LDIR-clones with identical
\ HERE per src/antforth.asm:184..197 — so the divergence assertion
\ would FAIL on a clean COLD. CR review H2/H3 (2026-05-19) dropped the
\ divergence assertion to make this probe load-bearing-only. Per-bank
\ behavioural witnesses (AC7 a/b/c/d/e) deferred to Story 19.2 + a
\ fresh-test-fixture strategy per Dev Notes §"Probe scope revision".
VARIABLE _p19-1b-bt0-here
VARIABLE _p19-1b-bt5-here
VARIABLE _p19-1b-pass
: _p19-1b-start ." ---probe-19.1-b-start---" CR ;
: _p19-1b-end   ." ---probe-19.1-b-end---"   CR ;
: _p19-1b-check
  -1 _p19-1b-pass !
  _p19-1b-bt0-here @ 0= IF 0 _p19-1b-pass !
    ." bt0-here-zero " THEN
  _p19-1b-bt5-here @ 0= IF 0 _p19-1b-pass !
    ." bt5-here-zero " THEN
  _p19-1b-pass @ IF
    ." probe-19.1-b-pass-bank-table-ldir-clone-witness"
  ELSE
    ." FAIL: probe-19.1-b bank-table LDIR-clone witness failed"
  THEN CR ;
_p19-1b-start
$D400 @ _p19-1b-bt0-here !      \ bank-table[0].here
$D41E @ _p19-1b-bt5-here !      \ bank-table[5].here = $D400 + 5*6
_p19-1b-check
_p19-1b-end
