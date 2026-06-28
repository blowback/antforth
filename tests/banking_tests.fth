\ banking_tests.fth — Phase-4 banking word tests
\ Run under the banking-capable emulator (make test-repl-banking).
\
\ === Architectural note: BANK-MAPPING-OFF emulator coverage ===
\ BANK-MAPPING-OFF is a one-way warm-boot escape: it disconnects the kernel
\ from the RAM that hosts its code, so it cannot be exercised under the
\ emulator (no flash mirror of antforth). The emulator probes here verify
\ ON-idempotence + port 0x74 readback; the OFF→BYE warm-boot escape to a
\ healthy `B>` CCP prompt is verified on real MicroBeast hardware.

\ Inline assembler reader for port 0x74 (MMU mapping enable).
\ Pushes the live mapping_enabled byte (1 after BANK-MAPPING-ON).
CODE FETCH-74 ( -- byte )
  BC PUSH,          \ save old TOS to SP
  A $74 # IN,       \ IN A, (74h)
  C A LD,           \ C <- A (low byte)
  B 0 # LD,         \ B <- 0     (zero-extend to cell)
  NEXT,
END-CODE

\ A raw IN A,(72h) reader was retired: the page registers (0x70-0x73) are
\ write-only, so the readback is open bus. Slot-2 mapping is now read via
\ MBB-GET-2 (MBB_GET_PAGE; defined in 16.3-probe.fth, loaded first).

\ === Probe 1: BANK-MAPPING-ON idempotence + stack effect ===
\ Stack-effect verification — repeated BANK-MAPPING-ON has stack effect
\ `( -- )` and the word body completes cleanly. Idempotent: mapping is
\ enabled at startup, so second-and-third ON are silent re-writes of the
\ same bit pattern.
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
\ After BANK-MAPPING-ON, the MMU mapping-enable register (port 0x74)
\ reads back as 1.
: _probe-2 ( -- )
  BANK-MAPPING-ON
  FETCH-74
  DUP 1 = IF
    ." PASS: banking-mapping-on-port-74 — port 0x74 reads back 1 (mapping enabled)"
    DROP
  ELSE
    ." FAIL: banking-mapping-on-port-74 — port 0x74 readback=$"
    BASE @ HEX SWAP . BASE !
    ." expected=$1"
  THEN
  CR
;
_probe-2

\ === Probe 3: BANK@ at boot returns 0 (Story 17.2 AC6 Probe 1) ===
\ Verifies (IY+UserArea.current_bank) is zero-initialised in COLD. The
\ cell read does not touch the MMU.
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
\ Kernel cell read; no MMU touch.
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
\ No MMU touch on the precondition-fail path.
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

\ === +BANK / -BANK / BANK! probe block ===
\
\ These probes are wrapped in colon definitions so IF/ELSE/THEN compile
\ (top-level IF errors with -14 'compile-only' per ?COMP).

\ Probe 6: 0 BANK! round-trips after $22 +BANK.
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

\ Probe 7: 1 BANK! BANK@ round-trip.
: _probe-7 ( -- )
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
  CR
;
_probe-7

\ Probe 8: 0 BANK! BANK@ round-trip.
: _probe-8 ( -- )
  $22 +BANK
  0 BANK! BANK@ DUP 0 = IF
    ." PASS: bank-store-round-trip-0 — 0 BANK! round-trips after $22 +BANK"
    DROP
  ELSE
    ." FAIL: bank-store-round-trip-0 — BANK@ returned " .
  THEN
  BANKS-CLEAR
  CR
;
_probe-8

\ Probe A: +BANK known-good RAM (page $22 = RAM bank 2 default).
: _probe-a ( -- )
  $22 +BANK BANKS DUP 1 = IF
    ." PASS: plus-bank-known-good — $22 +BANK appends; BANKS = 1"
    DROP
  ELSE
    ." FAIL: plus-bank-known-good — BANKS = " .
  THEN
  BANKS-CLEAR
  CR
;
_probe-a

\ Probe B: +BANK known-ROM rejection (page 0 = flash bank 0, reads 0xFF;
\ +BANK probe rejects). Uses CATCH to trap the ABORT" probe?" THROW (-2)
\ inside the colon definition so the surrounding IF/ELSE survives.
: _do-zero-+bank ( -- ) 0 +BANK ;
: _probe-b ( -- )
  ['] _do-zero-+bank CATCH -2 = IF
    BANKS 0 = IF
      ." PASS: plus-bank-rom-rejection — 0 +BANK aborts; BANKS = 0"
    ELSE
      ." FAIL: plus-bank-rom-rejection — BANKS = " BANKS .
    THEN
  ELSE
    ." FAIL: plus-bank-rom-rejection — 0 +BANK did not throw -2 (CATCH)"
  THEN
  CR
;
_probe-b

\ Probe C: -BANK present + absent (no MMU touch in -BANK).
\ BANKS-CLEAR at the head because the active list starts non-empty (the
\ CL parser auto-populates it), and the probe's `BANKS = 0` predicates
\ assume an empty list at entry.
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

\ Probe D: BANKS-CLEAR zeroes bank_count; BANK! aborts.
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

\ Probe E (SET-BANK diagnostic) was RETIRED with the SET-BANK word in the
\ banking-correctness interlude: a raw OUT desyncs the BIOS page shadow, and
\ the write-only port can no longer be read back to witness it (MBB_GET reads
\ the shadow, which SET-BANK deliberately did not touch). See banking.asm.

\ Probe F (Code Review H1): -BANK LDIR shift-down — count + data verification.
\
\ Two-part probe. F1 (surface-agnostic count check): seeds 3 entries
\ [$22, $23, $24], removes $22 twice. If the LDIR shift fires correctly
\ on the first remove, the array becomes [$23, $24, ...] and the second
\ $22 -BANK is a no-op (BANKS stays at 2). If LDIR is broken (e.g.,
\ skipped entirely), $22 is still at index 0 after the first remove and
\ the second remove decrements again → BANKS = 1.
\
\ F2 (data check): after the shift, 0 BANK! maps slot 2 to active_pages[0];
\ MBB-GET-2 readback should equal $23 (the shifted-in value), catching the
\ case where LDIR skipped without leaving the right page at index 0.
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
  0 BANK!     \ slot 2 ← active_pages[0]
  MBB-GET-2 DUP $23 = IF
    ." PASS: minus-bank-ldir-shift-data — MBB slot-2 readback = $23 (shifted-in value at index 0)"
    DROP
  ELSE
    ." FAIL: minus-bank-ldir-shift-data — MBB slot-2 readback = $" BASE @ HEX SWAP . BASE !
  THEN
  CR
  \ Cleanup: restore bank 0 (HERE/LATEST snapshot) BEFORE BANKS-CLEAR
  \ so subsequent REPL state stays sane (see BANKS-CLEAR docstring).
  0 BANK!
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
\ Sentinel-bounded output: the test-repl-banking recipe uses awk to extract
\ the runtime-output region between ---plus-bank-cap-start--- and
\ ---plus-bank-cap-end--- sentinels, then asserts the witnesses the
\ interpret-level driver below prints — "seeded: 29" (seed-loop completion),
\ "cap-catch-code: -2" (the 30th +BANK threw the cap code via CATCH), and
\ "cap-banks-after: 29" (count intact after the caught abort) — and
\ negative-asserts on FAIL strings. The witnesses deliberately lack a "PASS:"
\ prefix — the recipe handles verdict-label semantics, not the probe text.
\ See the Story 23.2 restructure note above _do-one-more-+bank for why the
\ verdict is driven at interpret level rather than from a colon body.
\
\ The cap check itself is a kernel-cell comparison.
\
\ Two load-bearing BANKS-CLEAR sites: the HEAD one (reset-before-seed —
\ removing it breaks every test run, since boot defaults populate 12
\ entries and the seed loop would trip the cap mid-iteration) and the
\ TAIL one (handoff guard for any probes added after probe G — leaves
\ bank_count = 0 for the next probe's known state). Do not move either.
: _do-29-+bank ( -- )
  29 0 DO $22 +BANK LOOP
;
: _do-one-more-+bank ( -- ) $22 +BANK ;
\ Story 23.2 restructure: the +BANK cap probe is now DRIVEN AT INTERPRET
\ LEVEL, so the running IP stays kernel-resident (<$8000). The prior single
\ `: _probe-plus-bank-cap ... ;` colon body straddled the $8000 slot-2 window
\ once cumulative kernel growth pushed HERE past the boundary; after the
\ seed/cap bank ops, the IP crossing into the body's >$8000 tail tripped the
\ F1-unguardable straddle halt (the class enumerated by
\ test-straddle-regression). Driving the orchestration line-by-line keeps the
\ verdict out of a straddling body — the raw -2 cap-throw code and the
\ post-abort BANKS count are printed for the Makefile to assert, so no
\ compile-mode IF/THEN (and hence no straddle-prone verdict word) is needed.
\ _do-29-+bank / _do-one-more-+bank stay as compiled helpers: they execute
\ fine (each +BANK restores slot 2 before returning, and the seed witness
\ prints), and a DO/LOOP / CATCH target must be compiled.
BANKS-CLEAR
." ---plus-bank-cap-start---" CR
_do-29-+bank
." seeded: " BANKS . CR
' _do-one-more-+bank CATCH
." cap-catch-code: " . CR
." cap-banks-after: " BANKS . CR
." ---plus-bank-cap-end---" CR
BANKS-CLEAR

\ === Probe 9: BANK! T-state latency probe (informational) ===
\
\ A T-state counter around a single BANK! would require the emulator's
\ --trace mode or a paper-arithmetic walk through the BANK! body.
\ Per-opcode estimate (precondition ~24 T; port write ~22 T; current_bank
\ swap ~30 T; rpush_bc + rpop_bc ~36 T; two bank_offset_hl calls ~70 T;
\ two LDIRs (4 bytes each) ~168 T; wordlist_head save+load ~50 T; POP BC
\ + NEXT ~25 T): ~425 T-states. The 60 T-state envelope binds cross-bank-
\ call dispatch overhead, not the REPL-level BANK! word — informational only.
." INFO: bank-store-t-states — paper-arithmetic estimate ~425 T-states (precondition ~24 + port-write ~22 + offset+LDIR cascades ~322 + tail ~57); NFR-P4-2 envelope (60 T) binds cross-bank dispatch (Epic 18), not BANK! itself" CR

\ === .BANKS probes (X, Y, Z, W) ===
\ `.BANKS` reads (IY+bank_count) + (IY+current_bank) + walks active_pages[];
\ no MMU port operations. Sentinel-and-grep pattern: each probe prints
\ `dot-banks-probe-<name>-start` + `.BANKS` + `dot-banks-probe-<name>-end`
\ sentinels; the Makefile test-repl-banking recipe grep-asserts on the
\ content between sentinels.
\
\ BANKS-CLEAR + the manual 12× $22 +BANK unroll are load-bearing — they set
\ up the dot-banks probes' kernel-cell state at a known shape: 12 entries
\ (logical banks 0..11) all at PAGE 22. Bank 0 is row 0 and is the KERNEL
\ dictionary (used = HERE-kernel_end, free = $D400-HERE — non-zero, grows
\ with compiled state). Banks 1..11 are empty slot-2 windows (used=0,
\ free=16384). Totals SUM all 12 rows, so the totals are NOT a fixed literal;
\ the deterministic invariant used below is: totals_used == bank-0 used (the
\ only non-zero used) and totals_free == bank-0 free + 11*16384.

\ The dot-banks setup (BANKS-CLEAR + 12× $22 +BANK) is INLINED at each probe
\ site below rather than factored into a `_dot-banks-setup` colon word, and the
\ probes themselves run at INTERPRET level (no colon wrappers). A colon body
\ here straddles $8000 at current kernel sizes (HERE ~32686 at this point in the
\ file), and invoking a >$8000 body AFTER a foreign BANK! (probe Y) portal-
\ aliases and halts the emulator. De-coloned 2026-06-28 (Story 23.6, whose +100 B
\ banked-overflow guard tipped exactly this section); same class as the probe-Y
\ note below and feedback_banking_probe_straddle_halt. Interpret-level keeps the
\ caller IP in the kernel QUIT loop (< $8000), so it is layout-robust.

\ Probe X — header + banked-row shape + totals self-consistency.
\ Makefile grep targets: `BANK PAGE` header + ≥11 banked rows reading
\ `used=0 free=16384` + a TOTAL row whose used/free satisfy the
\ bank-0-inclusive invariant (computed in the recipe, not a fixed literal).
BANKS-CLEAR  $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
$22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
." ---dot-banks-probe-x-start---" CR
.BANKS
." ---dot-banks-probe-x-end---" CR

\ Probe Y — current-bank marker tracking. Asserts `*` on row 0 at boot,
\ then on row 1 after `1 BANK!`, then back to row 0 after `0 BANK!`.
\ Makefile grep targets: between the start/mid1 sentinels, marker `*` on
\ the row whose BANK col reads `   0`; between mid1/mid2, on the row whose
\ BANK col reads `   1`; between mid2/end, back to row 0.
\ Run INTERACTIVELY (not wrapped in a colon body): the `1 BANK!` switch must
\ execute with the caller IP in the kernel QUIT loop (< $8000), not inside a
\ window-resident colon body. A colon wrapper trips the portal-window guard
\ (THROW -273, Story 19.5.1) once kernel growth pushes the body above $8000 —
\ this probe is layout-fragile in colon form (feedback_phase4_probe_bank_switch_limitation).
\ Each `BANK! .BANKS` is kept on ONE input line so the switch and the print
\ run in a single INTERPRET pass with no QUIT re-entry between them. That
\ matters: a re-entry would run REASSERT-BANK, which reverts current_bank to
\ saved_bank — and saved_bank only tracks `1 BANK!` when QSAVE-BANK recognises
\ it as an interactive BANK! (source_id==0, Story 21.2). Combining the two
\ words removes that coupling, so the marker tracks the live bank no matter how
\ the fixture is fed (piped console vs INCLUDE), not just on console stdin.
BANKS-CLEAR  $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
$22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
." ---dot-banks-probe-y-start---" CR
.BANKS
." ---dot-banks-probe-y-mid1---" CR
1 BANK! .BANKS
." ---dot-banks-probe-y-mid2---" CR
0 BANK! .BANKS
." ---dot-banks-probe-y-end---" CR

\ Probe Z — empty-banked-row guard + bank-0 exemption. Empty banked windows
\ still read used=0 / free=16384; bank 0 (row 0) is EXEMPT — it shows the
\ kernel-region free (≠ 16384). Makefile grep targets: ≥11 banked rows carry
\ `0  16384`, and the bank-0 row does NOT read free 16384.
\ Run INTERACTIVELY (de-coloned 2026-06-28, Story 23.6 — mirrors probe Y at
\ line 420): a colon body here is layout-fragile. Cumulative kernel + bank-0
\ dictionary growth eventually pushes the body across $8000; the window-resident
\ body then halts mid-.BANKS (feedback_banking_probe_straddle_halt). Story 23.6's
\ +100 B banked-overflow guard tipped exactly this probe. Interpret-level keeps
\ the caller IP in the kernel QUIT loop (< $8000), so .BANKS runs from fixed RAM.
BANKS-CLEAR  $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
$22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
." ---dot-banks-probe-z-start---" CR
.BANKS
." ---dot-banks-probe-z-end---" CR

\ Probe M1 — BASE-independence guard (Story-17.5 M1 close-out). The byte-count
\ columns are FORCED decimal regardless of BASE, so an empty banked row still
\ reads `16384` (decimal) in HEX mode — not `4000` (hex). Makefile grep target:
\ between the sentinels (emitted while BASE=HEX), a banked row still shows
\ `16384`, and no row shows the hex form ` 4000`.
\ De-coloned 2026-06-28 (Story 23.6) — same layout-fragility as probe Z above.
BANKS-CLEAR  $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
$22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
." ---dot-banks-probe-m1-start---" CR
HEX .BANKS DECIMAL
." ---dot-banks-probe-m1-end---" CR

\ Probe W — totals row + summary rows. Asserts `TOTAL` present with the
\ bank-0-inclusive totals invariant, plus the BANKED-WORDS / STUB-BYTES
\ summary rows (both 0 at this point — no banked words defined in the setup).
\ De-coloned 2026-06-28 (Story 23.6) — same layout-fragility as probe Z above.
BANKS-CLEAR  $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
$22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK $22 +BANK
." ---dot-banks-probe-w-start---" CR
.BANKS
." ---dot-banks-probe-w-end---" CR

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
\ The iron-spike validates (a)+(b)+(c) above — including that the MMU
\ port-0x72 page-map write does not disrupt main-RAM contents at
\ `kernel_end..kernel_end+8`.
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
\ Story 19.3 dev-pass 2026-05-20: _iron-spike-test runtime invocation
\ MOVED to an isolated iz-cpm-banking subprocess in the Makefile
\ (test-repl-banking target). Inline invocation removed because at +33 B
\ Story-19.3 kernel growth, iron-spike running INSIDE the full
\ banking_tests.fth probe sequence hangs the emulator's sentinel-
\ trampoline EXIT chain after emitting the success literal (boundary
\ 26748→26749 B; see Makefile iron-spike recipe block for the full
\ rationale). Hardware UAT 2026-05-20 (transcript beastty-20260520-
\ 153439.bin) confirmed iron-spike PASSes at this kernel layout on real
\ MicroBeast under disk/a/P193IRON.FTH — emulator quirk only. Moving
\ the runtime invocation to an isolated subprocess lets the emulator
\ run iron-spike WITHOUT the preceding cumulative-state corruption AND
\ lets the other probes (18.1.x, 18.2.x, 18.3.x, 19.1.x, 19.2.x, 19.3.x)
\ run WITHOUT iron-spike's potential hang. The colon definition stays
\ here so the isolated Makefile recipe can INCLUDE this file and call
\ _iron-spike-test directly. Same family of emulator-vs-hardware gap
\ as project_phase4_banking_off_emulator (BANK-MAPPING-OFF only
\ verifiable on hardware).

\ === Story 18.1: descriptor-stub allocator probes (Probe-18.1-A/B/C) ===
\ Story 18.1 lays the (γ) cross-bank dispatch foundation: a 4-byte
\ descriptor stub per word in the CCP-evicted $D400-$DBFF region;
\ stub address IS the word's xt (PD-P4-1 + redesign §2.1; PD-P4-11
\ layout at architecture.md:347..365). Probes here are LAYOUT-ONLY —
\ stubs are inspected via C@/@. Post-Story-19.5.2 (ADR 19.5 DR-2,
\ layout v2) stubs are genuinely executable: byte 0 = $EF (RST $28)
\ self-dispatches via the kernel stub_dispatch handler; the
\ execute-through witnesses are probe-19.5.2-a below + the 18.3/19.x
\ EXECUTE probes.
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
\ The allocator writes to the fixed-memory CCP-evicted region $D4CB+
\ (plain RAM; no MMU port operations).

VARIABLE _p18c-buf  18 ALLOT   \ 10 cells × 2 B = 20 B total (cell at VARIABLE + 18 ALLOT)
VARIABLE _p18c-pass

\ Story 19.2 CR fix (2026-05-19): refactored to RELATIVE-STRIDE assertion
\ per the CR-M2 deferred follow-up noted at line 744..752 above. Iron-spike
\ at line 705 (and other upstream code) now indirectly allocates a stub
\ during runtime — the H5 CR fix (bank-N HERE bumped to $8000) interacts
\ with iron-spike's `5 BANK!`-then-write-9-bytes pattern in a way that
\ leaves stub_alloc_tail advanced by 4. Probe-18.1-C now captures
\ stub_alloc_tail at entry via a marker call and asserts the 10 allocated
\ stubs land at marker+4, marker+8, ..., marker+40 (relative). The
\ absolute-COLD-init verification moved to Probe-18.1-COLD below (runs
\ before iron-spike).

: _probe-18.1-c ( -- )
  DECIMAL
  ." ---probe-18.1-c-start---" CR
  -1 _p18c-pass !
  \ Capture stub_alloc_tail position by allocating a marker stub; record
  \ where the marker landed so subsequent stub addresses can be checked
  \ relative to it (robust to upstream allocator-call-order).
  0 -1 (stub-allocate)                   \ ( marker_xt )
  \ Allocate 10 stubs with dummy target_addr=$1000, target_bank=1.
  10 0 DO
    4096 1 (stub-allocate)               \ ( marker_xt -- marker_xt xt_i )
    _p18c-buf I CELLS + !                \ buf[i] := xt_i
  LOOP
  \ Walk pairwise deltas: buf[i] - buf[i-1] must equal 4 for i in 1..9.
  10 1 DO
    _p18c-buf I CELLS + @                \ ( -- buf[i] )
    _p18c-buf I 1- CELLS + @ -           \ ( -- delta )
    4 = INVERT IF 0 _p18c-pass ! THEN
  LOOP
  ." first-stub-offset="    _p18c-buf            @  OVER -  U.
  ." last-stub-offset="     _p18c-buf 9 CELLS +  @  OVER -  U.
  ." expected-first-offset=4 expected-last-offset=40 "
  \ Relative-offset assertions: first stub is 4 B past marker; last is 40 B past.
  _p18c-buf           @ OVER -  4 = INVERT IF 0 _p18c-pass ! THEN
  _p18c-buf 9 CELLS + @ OVER - 40 = INVERT IF 0 _p18c-pass ! THEN
  DROP                                   \ drop marker_xt
  _p18c-pass @ IF
    ." probe-18.1-c-pass-10-stubs-deltas-4-and-relative-stride-40"
  ELSE
    ." FAIL: probe-18.1-c delta or relative-offset assertion mismatch"
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
  \ Read back the 4 bytes via C@ at xt+0..3 (stub layout v2, Story 19.5.2).
  \ Assertions: byte 0 = 239 = $EF = RST $28 opcode; byte 1 = 255 = $FF = -1 fixed-mem marker (FR-P4-13);
  \ byte 2 = target_addr lo; byte 3 = target_addr hi. Lines stay ≤ TIB_SIZE (128) per CR-M3 fix 2026-05-18.
  _p18a-xt @         C@   239 = INVERT IF 0 _p18a-pass ! ." byte0-bad " THEN
  _p18a-xt @ 1+      C@   255 = INVERT IF 0 _p18a-pass ! ." byte1-bad " THEN
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
  \ Assertions (stub layout v2, Story 19.5.2): byte 0 = 239 = $EF = RST $28; byte 1 = 5 = target_bank (PD-P4-13);
  \ byte 2 = 0 = $00 (lo of $8200); byte 3 = 130 = $82 (hi of $8200). Lines stay ≤ TIB_SIZE (128).
  _p18b-xt @         C@   239 = INVERT IF 0 _p18b-pass ! ." byte0-bad " THEN
  _p18b-xt @ 1+      C@   5   = INVERT IF 0 _p18b-pass ! ." byte1-bad " THEN
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

\ === Story 18.2 slot — RST-dispatch witness + intra-bank EXIT round-trip ===
\ Probe-18.2-A is RETIRED-AND-REPLACED (Story 19.5.2, ADR 19.5 DR-2):
\ it synthesized the old 3-cell sentinel frame via >R pushes and read
\ the JP cross_bank_return bytes out of EXIT_CODE+20..22 — BOTH
\ mechanisms ceased to exist when option C landed (EXIT_CODE is back
\ to plain pop + NEXT; the trampoline is deleted; cross-bank returns
\ route through stub_dispatch's 2-cell frame + xbank_thunk /
\ xbank_restore in src/banking.asm). Its replacement in the same
\ slot is probe-19.5.2-a below.
\
\ Probe-19.5.2-A — RST self-dispatch witness, end-to-end: a
\ (stub-allocate)-built fixed-memory stub ($FF marker) for a colon
\ word, invoked via EXECUTE. The folded EXECUTE (4 B, Story 19.5.2)
\ does a blind JP (HL) onto stub byte 0 = $EF = RST $28 → vector at
\ $0028 → stub_dispatch intra path (marker matches) → JP DOCOL with
\ HL = target CF → body runs → EXIT → NEXT resumes. The 12345 result
\ on the stack is the witness that the whole chain dispatched and
\ returned (fixed-memory target; no MMU change). The cross-bank half of
\ the handler is witnessed by probe-19.4-a (isolated fixture) + the
\ non-DOCOL witness in tests/banking_tests_19_3.fth.
\
\ Probe-18.2-B — intra-bank EXIT round-trip (100 colon-body call/EXIT
\ cycles), KEPT as-is: post-19.5.2 the plain pop + NEXT is the ONLY
\ EXIT path (the sentinel CP miss-path it used to witness is retired;
\ the probe now witnesses the plain path + BANK@ invariance). Also
\ implicitly exercised tens of thousands of times across the
\ test-repl regression suite — binding fitness witness for FR-P4-19
\ exact-zero-overhead behaviour.
DECIMAL

VARIABLE _p1952a-pass
: _p1952a-target 12345 ;       \ DOCOL body reached through the RST chain

: _probe-19.5.2-a ( -- )
  DECIMAL
  ." ---probe-19.5.2-a-start---" CR
  -1 _p1952a-pass !
  \ Build a fixed-memory stub for the target's CFA; EXECUTE the stub xt.
  ['] _p1952a-target -1 (stub-allocate)   \ ( xt ) — byte0=$EF byte1=$FF
  EXECUTE                                  \ JP (HL) → RST $28 → handler → DOCOL
  12345 = INVERT IF 0 _p1952a-pass ! ." result-bad " THEN
  _p1952a-pass @ IF
    ." probe-19.5.2-a-pass-rst-stub-dispatch-end-to-end"
  ELSE
    ." FAIL: probe-19.5.2-a RST stub dispatch did not return 12345"
  THEN CR
  ." ---probe-19.5.2-a-end---" CR
;
_probe-19.5.2-a

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

\ === Story 18.3 slot: stub-EXECUTE dispatch probes (A/B/C/D/E) ===
\ MECHANISM NOTE (Story 19.5.2, ADR 19.5 DR-2): Story 18.3's 3-way
\ EXECUTE dispatch these probes originally targeted is RETIRED. EXECUTE
\ is folded to a blind JP (HL); stubs self-dispatch via byte 0 = RST
\ $28 → stub_dispatch (src/banking.asm), which handles legacy-vs-stub,
\ intra-vs-cross uniformly for EVERY dispatch site. The probes below
\ are RETAINED as dispatch witnesses — their observable contracts
\ (stub xt EXECUTEs correctly; bank restored after a cross-bank call)
\ are mechanism-independent and now route through the RST chain
\ (PD-P4-1 + PD-P4-11; architecture.md:207..363; redesign §3).
\
\ Probe-18.3-A — fixed-memory stub EXECUTE. Allocates a stub for ' BANK@
\ with target_bank = -1; EXECUTE dispatches via the intra-bank path
\ (target_bank == -1 marker matches). No MMU change.
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
\ Probe-18.3-A is fixed-memory intra-bank dispatch; Probes 18.3-B/C/D/E
\ require real bank-table seeding and an MMU that honors port 0x72.
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
\ kernel DEFWORD NEGATE (xt < $D400, main-RAM CFA). Post-19.5.2
\ mechanism (ADR DR-2): EXECUTE's JP (HL) lands on the stub's RST $28
\ → stub_dispatch cross path pushes the 2-cell frame, sets DE =
\ xbank_thunk, MMU-switches, JPs to w_NEGATE_cf; DOCOL pushes the
\ thunk-IP; body runs (LIT 0, SWAP, MINUS, EXIT); EXIT pops the
\ thunk-IP → NEXT → xbank_restore restores the caller's bank and
\ resumes INTERPRET. Validates cross-bank dispatch + MMU port-write +
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
\ pollution), bank-table[1..28] are LDIR-clones of bank-table[0] with
\ the `here` field overridden to $8000 (Story 19.5.1 F2 COLD-init per
\ src/antforth.asm — LATEST/wordlist_head still cloned) — both reads
\ are non-zero but bt0 != bt5, so the divergence assertion direction
\ is moot. CR review H2/H3 (2026-05-19) dropped the
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

\ === Story 19.2 — bank-0 probes (Q4-γ; AC7 a + AC6 + Q3-β invariants) ===
\ Probes A/B/C/H cover bank-0 `:` legacy-preservation invariants under
\ Q3-β: no stub allocation, no F_HAS_STUB_XT_CELL flag, LATEST = entry-start,
\ compilation-THROW state-integrity. Per-bank behavioural probes
\ (Probe-19.2-D/E/F/G covering AC4 / AC5 via EXECUTE-explicit dispatch)
\ live in tests/banking_tests_19_2.fth and run under the NEW Makefile
\ target `test-repl-banking-isolated` per Q4-γ-default fresh-fixture
\ strategy. See _bmad-output/implementation-artifacts/19-2-*.md Dev Notes
\ §"Q4-γ probe split" for rationale. Threading-through-stub-xt (compiled-
\ body intra-bank dispatch for bank-N>0) deferred to Story 19.5 per the
\ architectural finding surfaced at Story 19.2 dev-pass close (2026-05-19).

\ Probe-19.2-A — bank-0 `:` legacy semantics: LATEST @ returns entry-start;
\ `'` returns CFA (= post-name in legacy layout). For bank-0 entries the
\ two differ by 3 + name-length (hash_link + count_flags + name).
VARIABLE _p19-2a-latest-cell
VARIABLE _p19-2a-tick-cfa
VARIABLE _p19-2a-pass
: _p19-2a-start ." ---probe-19.2-a-start---" CR ;
: _p19-2a-end   ." ---probe-19.2-a-end---"   CR ;
: _p19-2a-check
  -1 _p19-2a-pass !
  _p19-2a-latest-cell @ 0= IF 0 _p19-2a-pass ! ." latest-zero " THEN
  _p19-2a-tick-cfa @ 0= IF 0 _p19-2a-pass ! ." tick-zero " THEN
  _p19-2a-tick-cfa @ _p19-2a-latest-cell @ = IF 0 _p19-2a-pass !
    ." latest-equals-tick-but-should-differ-for-bank-0 " THEN
  _p19-2a-pass @ IF
    ." probe-19.2-a-pass-bank-0-latest-and-tick-differ"
  ELSE
    ." FAIL: probe-19.2-a bank-0 LATEST/tick differ test failed"
  THEN CR ;
_p19-2a-start
: _p19-2a-target 42 ;
LATEST @ _p19-2a-latest-cell !
' _p19-2a-target _p19-2a-tick-cfa !
_p19-2a-check
_p19-2a-end

\ Probe-19.2-B — bank-0 `:` does NOT advance the descriptor-stub allocator.
\ Allocates two marker stubs flanking a bank-0 `:` definition; asserts the
\ stub-address stride is exactly 4 (= one stub between markers), proving
\ the `:`/`;` cycle skipped stub_allocate per Q3-β. A stride of 8 would
\ indicate SEMICOLON erroneously allocated a stub for bank 0.
VARIABLE _p19-2b-stub1
VARIABLE _p19-2b-stub2
VARIABLE _p19-2b-pass
: _p19-2b-start ." ---probe-19.2-b-start---" CR ;
: _p19-2b-end   ." ---probe-19.2-b-end---"   CR ;
: _p19-2b-check
  -1 _p19-2b-pass !
  _p19-2b-stub2 @ _p19-2b-stub1 @ - 4 = INVERT IF 0 _p19-2b-pass !
    ." stride-not-4 " THEN
  _p19-2b-pass @ IF
    ." probe-19.2-b-pass-bank-0-no-stub-on-semicolon"
  ELSE
    ." FAIL: probe-19.2-b bank-0 allocated stub on `;` (stride != 4)"
  THEN CR ;
_p19-2b-start
0 -1 (stub-allocate) _p19-2b-stub1 !
: _p19-2b-target 7 ;
0 -1 (stub-allocate) _p19-2b-stub2 !
_p19-2b-check
_p19-2b-end

\ Probe-19.2-C — bank-0 entry F_HAS_STUB_XT_CELL flag CLEAR. Walks
\ LATEST → +2 = count_flags byte; asserts bit 5 ($20) is 0 (legacy layout
\ preserved per NFR-P4-16 byte-identical bank-0 regression).
VARIABLE _p19-2c-cf
VARIABLE _p19-2c-pass
: _p19-2c-start ." ---probe-19.2-c-start---" CR ;
: _p19-2c-end   ." ---probe-19.2-c-end---"   CR ;
: _p19-2c-check
  -1 _p19-2c-pass !
  _p19-2c-cf @ $20 AND IF 0 _p19-2c-pass ! ." cf-flag-set " THEN
  _p19-2c-pass @ IF
    ." probe-19.2-c-pass-bank-0-no-stub-xt-cell-flag"
  ELSE
    ." FAIL: probe-19.2-c bank-0 has F_HAS_STUB_XT_CELL flag set"
  THEN CR ;
_p19-2c-start
: _p19-2c-target 13 ;
LATEST @ 3 + C@ _p19-2c-cf !   \ count_flags at entry+3 (fat 3-byte hash_link)
_p19-2c-check
_p19-2c-end

\ Probe-19.2-H — bank-0 subsequent-`:`-after-THROW state integrity (AC6
\ partial coverage). Triggers a -13 THROW via `'` on an unknown word
\ inside a CATCH (exercises the THROW unwind path that COMP-ERROR shares
\ at src/compiler.asm:478..532), then verifies a subsequent `: GOOD ... ;`
\ in bank 0 succeeds with non-zero LATEST + non-zero xt. Full compile-
\ mode-mid-THROW HERE-rollback verification (interpret-mode EVALUATE of
\ a colon body with a bad word) is deferred to Story 19.5 alongside the
\ threading-rework story per the architectural finding at Story 19.2 close.
VARIABLE _p19-2h-throw-code
VARIABLE _p19-2h-good-xt
VARIABLE _p19-2h-good-latest
VARIABLE _p19-2h-pass
: _p19-2h-throw-13 -13 THROW ;
: _p19-2h-start ." ---probe-19.2-h-start---" CR ;
: _p19-2h-end   ." ---probe-19.2-h-end---"   CR ;
: _p19-2h-check
  -1 _p19-2h-pass !
  _p19-2h-throw-code @ -13 = INVERT IF 0 _p19-2h-pass !
    ." throw-code-not-minus-13 " THEN
  _p19-2h-good-xt @ 0= IF 0 _p19-2h-pass ! ." good-xt-zero " THEN
  _p19-2h-good-latest @ 0= IF 0 _p19-2h-pass ! ." good-latest-zero " THEN
  _p19-2h-pass @ IF
    ." probe-19.2-h-pass-bank-0-subsequent-colon-after-throw"
  ELSE
    ." FAIL: probe-19.2-h bank-0 subsequent-colon-after-throw failed"
  THEN CR ;
_p19-2h-start
' _p19-2h-throw-13 CATCH _p19-2h-throw-code !
: _p19-2h-good 99 ;
' _p19-2h-good _p19-2h-good-xt !
LATEST @ _p19-2h-good-latest !
_p19-2h-check
_p19-2h-end

\ Probe-19.2-J — AC7-d coverage: bank-0 `:`-defined word's xt is a legacy
\ CFA (xt < $D400). BANK-OF reads stub byte 1 (target_bank, layout v2
\ per Story 19.5.2) at xt+1 — for a legacy CFA xt, the discriminator in
\ src/banking.asm short-circuits to -1 (the fixed-memory marker per
\ FR-P4-13) without dereferencing the stub-byte read (which would yield
\ a code byte outside the signed [-1..28] range). AC7-d in the story
\ spec was enumerated but not probed in the dev pass; CR fix 2026-05-19.
VARIABLE _p19-2j-bank-of
VARIABLE _p19-2j-tick
VARIABLE _p19-2j-pass
: _p19-2j-start ." ---probe-19.2-j-start---" CR ;
: _p19-2j-end   ." ---probe-19.2-j-end---"   CR ;
: _p19-2j-check
  -1 _p19-2j-pass !
  _p19-2j-tick @ $D400 < INVERT IF 0 _p19-2j-pass !
    ." xt-not-below-D400 " THEN
  _p19-2j-bank-of @ -1 = INVERT IF 0 _p19-2j-pass !
    ." bank-of-not-minus-1 " THEN
  _p19-2j-pass @ IF
    ." probe-19.2-j-pass-bank-0-bank-of-returns-minus-1"
  ELSE
    ." FAIL: probe-19.2-j bank-0 BANK-OF discriminator returned non--1"
  THEN CR ;
_p19-2j-start
: _p19-2j-target 1 ;
' _p19-2j-target DUP _p19-2j-tick !
BANK-OF _p19-2j-bank-of !
_p19-2j-check
_p19-2j-end

\ ============================================================
\ Story 19.3 bank-0 probes (Q4-γ default; AC6 / AC9 / FR-P4-25)
\ ============================================================
\
\ Probe-19.3-A — bank-0 CREATE byte-identical sanity + BANK-OF=-1 (AC1/AC3)
\ Probe-19.3-B — bank-0 CREATE/DOES> regression sanity (AC2)
\ Probe-19.3-C — bank-0 entry has NO F_HAS_STUB_XT_CELL flag (AC1)
\ Probe-19.3-H — bank-0 NFR-P4-8 state integrity after CREATE empty-name -16 THROW
\ Probes D/E/F/G live in tests/banking_tests_19_3.fth (Q4-γ hybrid; Sub-5.8
\ parallel target test-repl-banking-isolated-19-3 per dev-pass-start AskUserQuestion).

\ === Probe-19.3-A — bank-0 CREATE byte-identical sanity (AC1 / AC3 / AC6-A) ===
VARIABLE _p193a-val
VARIABLE _p193a-bank
VARIABLE _p193a-pass
: _p193a-start ." ---probe-19.3-a-start---" CR ;
: _p193a-end   ." ---probe-19.3-a-end---"   CR ;
: _p193a-check
  -1 _p193a-pass !
  _p193a-val @ 42 = INVERT IF 0 _p193a-pass !
    ." value-not-42 " THEN
  _p193a-bank @ -1 = INVERT IF 0 _p193a-pass !
    ." bank-of-not-minus-1 " THEN
  _p193a-pass @ IF
    ." probe-19.3-a-pass-bank-0-create-byte-identical"
  ELSE
    ." FAIL: probe-19.3-a bank-0 CREATE sanity failed"
  THEN CR ;
_p193a-start
CREATE _p193a-c0 42 ,
_p193a-c0 @ _p193a-val !
' _p193a-c0 BANK-OF _p193a-bank !
_p193a-check
_p193a-end

\ === Probe-19.3-B — bank-0 CREATE/DOES> regression sanity (AC2 / AC6-B) ===
VARIABLE _p193b-val
VARIABLE _p193b-pass
: _p193b-start ." ---probe-19.3-b-start---" CR ;
: _p193b-end   ." ---probe-19.3-b-end---"   CR ;
: _p193b-array CREATE CELLS ALLOT DOES> SWAP CELLS + ;
: _p193b-check
  -1 _p193b-pass !
  _p193b-val @ 13 = INVERT IF 0 _p193b-pass !
    ." doesify-not-13 " THEN
  _p193b-pass @ IF
    ." probe-19.3-b-pass-bank-0-create-does-regression"
  ELSE
    ." FAIL: probe-19.3-b bank-0 CREATE/DOES> regression failed"
  THEN CR ;
_p193b-start
4 _p193b-array _p193b-arr
13 0 _p193b-arr !
0 _p193b-arr @ _p193b-val !
_p193b-check
_p193b-end

\ === Probe-19.3-C — bank-0 entry has NO F_HAS_STUB_XT_CELL flag (AC1 / AC6-C) ===
\ Bank-0 entries take .bh_skip_cell at compiler.asm:316 — no 2-byte cell,
\ F_HAS_STUB_XT_CELL bit ($20 = 0x20 per src/constants.asm:78) clear in
\ count_flags. LATEST → entry-start → +2 = count_flags for bank-0
\ (legacy CFA xt = entry-start; Q3-β inheritance).
VARIABLE _p193c-flag
VARIABLE _p193c-pass
: _p193c-start ." ---probe-19.3-c-start---" CR ;
: _p193c-end   ." ---probe-19.3-c-end---"   CR ;
: _p193c-check
  -1 _p193c-pass !
  _p193c-flag @ 0= INVERT IF 0 _p193c-pass !
    ." stub-xt-cell-flag-set " THEN
  _p193c-pass @ IF
    ." probe-19.3-c-pass-bank-0-no-stub-xt-cell-flag"
  ELSE
    ." FAIL: probe-19.3-c bank-0 entry has unexpected F_HAS_STUB_XT_CELL"
  THEN CR ;
_p193c-start
CREATE _p193c-c0
LATEST @ 3 + C@ $20 AND _p193c-flag !   \ count_flags at entry+3 (fat 3-byte hash_link)
_p193c-check
_p193c-end

\ === Probe-19.3-H — bank-0 NFR-P4-8 state integrity after CREATE empty-name THROW ===
\ Per-spec: CATCH-wrap an empty-name CREATE via EVALUATE — build_header's
\ .bh_no_name at compiler.asm:185..187 returns CF=1 without writing
\ HERE/LATEST/buckets; CREATE's .create_no_name at :798..804 throws -16.
\ Post-CATCH state must match pre-CATCH exactly. Then a subsequent
\ CREATE-with-name must work cleanly (subsequent-definition sanity).
VARIABLE _p193h-here-pre
VARIABLE _p193h-here-post
VARIABLE _p193h-latest-pre
VARIABLE _p193h-latest-post
VARIABLE _p193h-throw-code
VARIABLE _p193h-good-val
VARIABLE _p193h-pass
: _p193h-start ." ---probe-19.3-h-start---" CR ;
: _p193h-end   ." ---probe-19.3-h-end---"   CR ;
: _p193h-empty S" CREATE" EVALUATE ;
: _p193h-check
  -1 _p193h-pass !
  _p193h-throw-code @ -16 = INVERT IF 0 _p193h-pass !
    ." throw-not-minus-16 " THEN
  _p193h-here-pre @ _p193h-here-post @ = INVERT IF 0 _p193h-pass !
    ." here-changed " THEN
  _p193h-latest-pre @ _p193h-latest-post @ = INVERT IF 0 _p193h-pass !
    ." latest-changed " THEN
  _p193h-good-val @ 99 = INVERT IF 0 _p193h-pass !
    ." good-not-99 " THEN
  _p193h-pass @ IF
    ." probe-19.3-h-pass-bank-0-state-integrity-after-create-throw-16"
  ELSE
    ." FAIL: probe-19.3-h bank-0 state-integrity violated"
  THEN CR ;
_p193h-start
HERE _p193h-here-pre !
LATEST @ _p193h-latest-pre !
' _p193h-empty CATCH _p193h-throw-code !
HERE _p193h-here-post !
LATEST @ _p193h-latest-post !
CREATE _p193h-good 99 ,
_p193h-good @ _p193h-good-val !
_p193h-check
_p193h-end

\ === Story 19.5.1 — F1/F2 portal-aliasing guard probes (AC5) ===
DECIMAL

\ === Probe-19.5.1-A — F1 BANK! window guard: CATCH -273, state unchanged (AC5a) ===
\ A colon body compiled at/above $8000 (window-resident) attempting a
\ foreign-bank BANK! must CATCH -273 (THROW_BANK_FROM_BANKED) with
\ current bank + window content unchanged -- the guard fires BEFORE any
\ MMU/state mutation (src/banking.asm w_BANK_STORE_cf; ADR 19.5 DR-1 F1).
\ Precondition asserted at run time: the victim's compile point is at or
\ above $8000 (true this late in the suite -- the dictionary crossed
\ $8000 around the probe-18.2-a region). If a future re-layout drops it
\ below, the probe emits SKIP + reason rather than false-grading.
\ Window-content witness: the cell at the victim's xt (>= $8000) must
\ read back identically post-CATCH -- under a leaked MMU switch that
\ read would hit the foreign page.
VARIABLE _p1951a-precond
VARIABLE _p1951a-xt
VARIABLE _p1951a-cell-pre
VARIABLE _p1951a-cell-post
VARIABLE _p1951a-bank-pre
VARIABLE _p1951a-bank-post
VARIABLE _p1951a-throw
VARIABLE _p1951a-pass
: _p1951a-start ." ---probe-19.5.1-a-start---" CR ;
: _p1951a-end   ." ---probe-19.5.1-a-end---"   CR ;
: _p1951a-check
  _p1951a-precond @ 0= IF
    ." SKIP: probe-19.5.1-a precondition - compile point below $8000 (window residency lost)" CR
    EXIT THEN
  -1 _p1951a-pass !
  _p1951a-throw @ -273 = INVERT IF 0 _p1951a-pass !
    ." throw-not-273 " THEN
  _p1951a-bank-pre @ _p1951a-bank-post @ = INVERT IF 0 _p1951a-pass !
    ." bank-changed " THEN
  _p1951a-bank-post @ 0= INVERT IF 0 _p1951a-pass !
    ." bank-not-zero " THEN
  _p1951a-cell-pre @ _p1951a-cell-post @ = INVERT IF 0 _p1951a-pass !
    ." window-cell-changed " THEN
  _p1951a-pass @ IF
    ." probe-19.5.1-a-pass-window-guard-catch-273-state-unchanged"
  ELSE
    ." FAIL: probe-19.5.1-a window-guard CATCH/state check failed"
  THEN CR ;
_p1951a-start
BANKS-CLEAR  $22 +BANK  $35 +BANK
0 BANK!
HERE $8000 U< INVERT _p1951a-precond !
: _p1951a-victim 1 BANK! ;
' _p1951a-victim DUP _p1951a-xt ! @ _p1951a-cell-pre !
BANK@ _p1951a-bank-pre !
' _p1951a-victim CATCH _p1951a-throw !
BANK@ _p1951a-bank-post !
_p1951a-xt @ @ _p1951a-cell-post !
_p1951a-check
BANKS-CLEAR
_p1951a-end

\ === Probe-19.5.1-B — F2 bank-table[1].here COLD-init = $8000 (AC5b, table-read witness) ===
\ COLD initialises bank-table[1..28].here = $8000 (src/antforth.asm,
\ Story 19.5.1 F2 -- the re-landed 19.2-H5 fix): bank-N>0 bodies are
\ page-resident from byte 0 and can never straddle the window boundary.
\ Witnessed here by a DIRECT fixed-memory read of bank-table[1].here at
\ $D406 (= BANK_TABLE_BASE $D400 + entry stride 6; same raw-read
\ precedent as probe-19.1-b's $D400/$D41E). Bank 1's table cell still
\ holds the COLD value this late in the suite: earlier probes visit
\ bank 1 (probe-7, dot-banks-y) but never compile in it, and BANK!
\ cycles save the unchanged HERE straight back.
\ NB this is deliberately NOT a behavioural `1 BANK! HERE` probe: the
\ main-suite dictionary crosses $8000 mid-file, so its (bank-shared)
\ hash-bucket chains contain window-resident entries -- any token
\ lookup while bank 1 is mapped can walk a chain through the window
\ and read the foreign page (-13 strand; observed at dev-pass). The
\ behavioural first-visit witness lives in the isolated fixture
\ tests/banking_tests_19_5_1.fth (make test-repl-banking-isolated-19-5-1).
VARIABLE _p1951b-here
VARIABLE _p1951b-pass
: _p1951b-start ." ---probe-19.5.1-b-start---" CR ;
: _p1951b-end   ." ---probe-19.5.1-b-end---"   CR ;
: _p1951b-check
  -1 _p1951b-pass !
  _p1951b-here @ $8000 = INVERT IF 0 _p1951b-pass !
    ." here-not-8000 " THEN
  _p1951b-pass @ IF
    ." probe-19.5.1-b-pass-bank-table-1-here-cold-init-8000"
  ELSE
    ." FAIL: probe-19.5.1-b bank-table[1].here COLD-init check failed - got " _p1951b-here @ U.
  THEN CR ;
_p1951b-start
$D406 @ _p1951b-here !
_p1951b-check
_p1951b-end
