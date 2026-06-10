\ DIV1RB.FTH  -- DIV-1 falsifiable core: does IN A,(0x72) read back
\ what OUT (0x72) wrote?  Story 19.5.4 / Epic 19.5 retro action item.
\
\ DIV-1 (banking.asm cl_probe_and_add, fixed 1bab95a) claims the
\ MicroBeast MMU slot-2 page register at port 0x72 is WRITE-ONLY on
\ real silicon: an `IN A,(0x72)` readback floats (open bus) instead of
\ returning the page last written by `OUT (0x72),A`. The iz-cpm-banking
\ emulator MODELS the readback (cpm_machine.rs:138 returns bank_map[2]),
\ so it cannot reproduce the divergence -- this fixture is the silicon
\ check Ant asked for.
\
\ PORT72-RT does the whole round-trip in ONE CODE word so the
\ $8000..$BFFF window is NEVER accessed while a foreign page is mapped
\ into slot 2: write test page, read it back, restore the caller page,
\ return the readback. The word body lives in low memory (< $8000); it
\ touches the slot-2 PAGE REGISTER only, never slot-2 ADDRESS SPACE.
\
\   PORT72-RT ( testpage restorepage -- readback )
\   restorepage = page to put back into slot 2 before returning; pass
\                 your boot portal page (default $22) so the window is
\                 left exactly as it was.
\
\ INTERPRETATION
\   readback == testpage  -> port 0x72 IS readable; DIV-1 premise FALSE
\                            (the +13 B fix treats the wrong cause;
\                             re-open the real root cause before Epic 20)
\   readback != testpage  -> port 0x72 readback floats; DIV-1 CONFIRMED
\
\ CONTROL: under iz-cpm-banking every line MUST print " OK" (proves the
\ harness is sound). On real MicroBeast it is the actual experiment.

HEX

\ Inner-interpreter register contract: BC = TOS, DE = IP, IX = R-stack.
\ This leaf word touches only A / B / C / H / L (HL is reloaded by NEXT),
\ so it never disturbs the IP or return stack.
CODE PORT72-RT ( testpage restorepage -- readback )
  H C LD,            \ H <- restorepage (low byte of TOS is in C)
  BC POP,            \ BC <- testpage cell (C = testpage low)
  A C LD,            \ A <- testpage
  A 72 # OUT,        \ OUT (0x72),A   -- map test page into slot 2
  72 # A IN,         \ IN  A,(0x72)   -- read it back (the experiment)
  L A LD,            \ L <- readback
  A H LD,            \ A <- restorepage
  A 72 # OUT,        \ OUT (0x72),A   -- restore caller's slot-2 page
  C L LD,            \ C <- readback  (new TOS low byte)
  B 0 # LD,          \ B <- 0         (zero-extend to a cell)
  NEXT,
END-CODE

\ Round-trip one test page (restore = $22 default portal) and report.
: _rb ( testpage -- )
  DUP HEX U. ."  -> "        \ print the test page
  DUP $22 PORT72-RT          \ ( testpage readback )  keep a copy to compare
  DUP HEX U. SPACE           \ print the readback
  = IF ." OK" ELSE ." FLOAT (port 0x72 readback NOT honoured)" THEN CR ;

CR ." === DIV-1 port-0x72 readback check (restore portal=22) ===" CR
35 _rb        \ a normal RAM bank page
3F _rb        \ another bank page
05 _rb        \ a low page id, distinct bit pattern
CR ." Expected under iz-cpm-banking: all OK.  On real MicroBeast: see verdict above." CR
