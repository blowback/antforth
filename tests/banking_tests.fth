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

\ Probe G (Code Review H2): +BANK cap check at bank_count == 29 — AC2 / PD-P4-13.
\
\ Seeds 29 copies of $22 via +BANK (no-dedup per Q2 disposition), then
\ asserts the 30th +BANK aborts with "cap?" (THROW -2 caught via CATCH).
\ Surface-agnostic: under iz-cpm baseline the probes succeed via flat
\ memory; under iz-cpm-banking and real MB they succeed via the modelled
\ RAM bank $22. The cap check itself is a kernel-cell comparison —
\ surface-independent.
: _do-29-+bank ( -- )
  29 0 DO $22 +BANK LOOP
;
: _do-one-more-+bank ( -- ) $22 +BANK ;
: _probe-plus-bank-cap ( -- )
  _do-29-+bank
  BANKS DUP 29 = IF
    DROP
    ['] _do-one-more-+bank CATCH -2 = IF
      BANKS 29 = IF
        ." PASS: plus-bank-cap — 30th +BANK aborts; BANKS stays at 29"
      ELSE
        ." FAIL: plus-bank-cap — BANKS = " BANKS . ." (expected 29 after cap abort)"
      THEN
    ELSE
      ." FAIL: plus-bank-cap — 30th +BANK did not throw -2 (CATCH)"
    THEN
  ELSE
    ." FAIL: plus-bank-cap — could not seed 29 entries; BANKS = " .
  THEN
  CR
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
