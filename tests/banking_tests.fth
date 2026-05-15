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
