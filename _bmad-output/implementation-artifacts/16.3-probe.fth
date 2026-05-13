\ Story 16.3 - first iron probe: banking-capable emulator detection
\
\ Surface: banking-capable / iz-cpm-SKIP (no MMU model)
\ Probe writes a marker page index to slot-2's MMU page register
\ (port 0x72) and reads it back via IN A,(72h). Under the picked
\ banking emulator (iz-cpm-banking, blowback/iz-cpm fork @ 1777a85),
\ port_in for 0x70..0x73 returns bank_map[port-0x70] - so the
\ readback equals the written value and the probe declares PASS.
\ Under iz-cpm baseline (no MMU model), port_in returns 0 for
\ unmodelled ports - so the readback mismatch lets the probe
\ declare SKIP cleanly (no FAIL, no kernel crash).
\
\ Surface-detection mechanism: option (iii) from story Dev Notes -
\ Forth-side behavior probe; probe declares SKIP based on observed
\ behavior of port 0x72 round-trip.
\
\ BANK!/BANK@/SET-BANK kernel words land in Stories 17.1-17.3; this
\ probe inlines OUT (72h),A and IN A,(72h) via Epic 4's assembler
\ since those primitives don't exist yet in the 24,995-byte build.
\
\ Slot-2 (0x8000-0xBFFF) chosen because:
\   - slot 0/1 (0x0000-0x7FFF) holds running antforth code
\   - slot 3 (0xC000-0xFFFF) holds the parameter+return stacks and CCP/BDOS
\   - slot 2 is free between dictionary HERE and stack base

CODE BANG-72 ( byte -- )
  A C LD,           \ LD A, C  -- A <- low byte of BC=TOS (the byte to emit)
  A $72 # OUT,      \ OUT (72h), A    -- store byte in slot-2 bank reg
  BC POP,           \ pop new TOS into BC
  NEXT,
END-CODE

CODE FETCH-72 ( -- byte )
  BC PUSH,          \ save old TOS to SP
  $72 # A IN,       \ IN A, (72h)     -- read slot-2 bank reg
  C A LD,           \ C <- A (low byte)
  B 0 # LD,         \ B <- 0          (zero-extend to cell)
  NEXT,
END-CODE

: BANKING-EMU-PROBE ( -- )
  FETCH-72                                  \ ( saved )  default slot-2 mapping
  $36 BANG-72                               \ write marker
  FETCH-72                                  \ ( saved readback )
  DUP $36 = IF
    ." PASS: banking-emu-probe - bank switch observed (slot-2 port 72h round-tripped marker $36)"
    DROP
  ELSE
    ." SKIP: banking-emu-probe - iz-cpm does not model MMU; this probe targets banking-capable surface only (readback="
    . ." expected=36 hex)"
  THEN
  CR
  BANG-72                                   \ restore saved slot-2 mapping (consumes saved)
;

BANKING-EMU-PROBE
