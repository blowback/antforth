\ Story 16.3 - first iron probe: slot-2 page-switch round-trip
\
\ Reworked for the banking-correctness interlude: the MMU page registers
\ (ports 0x70-0x73) are write-only on real hardware and now in the emulator,
\ so a raw IN A,(72h) readback returns open bus. Page switching is verified
\ through the BIOS MBB routines instead: MBB_SET_PAGE ($FDDF, A=logical page,
\ E=physical) and MBB_GET_PAGE ($FDDC, C=logical page -> A=physical), which
\ keep the BIOS page shadow in sync. antforth is MicroBeast-BIOS-only, so this
\ surface always models MBB; a round-trip mismatch is a real FAIL (no SKIP).
\
\ Slot-2 (0x8000-0xBFFF) is the safe slot to poke: slot 0/1 hold running code,
\ slot 3 holds the stacks + CCP/BDOS, slot 2 is the portal window. The probe
\ saves the live mapping, writes a marker page, reads it back, and restores.
\
\ Both CODE words preserve the inner-interpreter registers: MBB_GET/SET clobber
\ A,B,C,H,L,F and preserve DE,IX,IY (verified against the MicroBeast BIOS), so
\ DE=IP is saved across MBB-SET-2 (it loads E) and the old TOS is spilled to the
\ data stack before either result is built.

CODE MBB-GET-2 ( -- page )
  BC PUSH,          \ save old TOS to the data stack
  C 2 # LD,         \ C = logical page 2 (slot 2)
  $FDDC CALL,       \ MBB_GET_PAGE -> A = physical page
  C A LD,           \ C <- A (low byte)
  B 0 # LD,         \ B <- 0  (zero-extend to a cell)
  NEXT,
END-CODE

CODE MBB-SET-2 ( page -- )
  DE PUSH,          \ save IP (DE) — we overwrite E with the page below
  A 2 # LD,         \ A = logical page 2 (slot 2)
  E C LD,           \ E = physical page (low byte of BC = TOS)
  $FDDF CALL,       \ MBB_SET_PAGE — sets slot 2 and the BIOS shadow
  DE POP,           \ restore IP
  BC POP,           \ new TOS (consume the page arg)
  NEXT,
END-CODE

: BANKING-EMU-PROBE ( -- )
  MBB-GET-2                                  \ ( saved )  live slot-2 mapping
  $36 MBB-SET-2                              \ map slot 2 to marker page $36
  MBB-GET-2                                  \ ( saved readback )
  DUP $36 = IF
    ." PASS: banking-emu-probe — slot-2 page switch round-trips via MBB ($36 set then read)"
    DROP
  ELSE
    ." FAIL: banking-emu-probe — MBB slot-2 readback = $" BASE @ HEX SWAP . BASE ! ." expected=$36"
  THEN
  CR
  MBB-SET-2                                  \ restore saved slot-2 mapping (consumes saved)
;

BANKING-EMU-PROBE
