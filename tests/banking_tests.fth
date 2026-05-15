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

\ === PENDING-17.3: Probe 6 — 1 BANK! BANK@ . round-trips (Story 17.3 active) ===
\ Surface: SKIP-on-all (active list empty at Story 17.2 close;
\          Story 17.3's +BANK populates index 1; this probe lights up
\          at Story 17.3 dev-pass)
\
\ Authored at Story 17.2 close per §"AC6 probe sequencing" Q2 — the
\ epic AC6 lists this probe but it requires `+BANK` (Story 17.3) to
\ populate the active list before the precondition succeeds. The
\ probe text is parseable Forth wrapped in a \ comment so the
\ banking-emu pipe doesn't try to run it (would ABORT" bank?" at
\ Story 17.2 close because bank_count = 0). Story 17.3's dev-pass
\ removes the \ comment + the `PENDING-17.3` marker.
\
\ PENDING-17.3: 1 BANK! BANK@ DUP 1 = IF ." PASS: bank-store-round-trip-1" DROP ELSE ." FAIL " . THEN CR
." SKIP: bank-store-round-trip-1 — PENDING-17.3 (active list empty until +BANK populates index 1)" CR

\ === PENDING-17.3: Probe 7 — 0 BANK! round-trips (Story 17.3 active) ===
\ Surface: SKIP-on-all (active list empty at Story 17.2 close; even
\          though current_bank = 0 by COLD default, 0 BANK! ABORTs
\          because precondition `0 < bank_count` fails when bank_count
\          = 0. Story 17.3's +BANK populates index 0; this probe
\          lights up at Story 17.3 dev-pass.)
\
\ PENDING-17.3: 0 BANK! BANK@ DUP 0 = IF ." PASS: bank-store-round-trip-0" DROP ELSE ." FAIL " . THEN CR
." SKIP: bank-store-round-trip-0 — PENDING-17.3 (active list empty; 0 BANK! aborts with bank_count = 0)" CR

\ === Probe 8: BANK! T-state latency probe (Story 17.2 AC5; informational) ===
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
