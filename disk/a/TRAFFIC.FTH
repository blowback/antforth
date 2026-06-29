\ TRAFFIC.FTH -- 64 Hz tick-driven traffic-light demo for antforth
\ Hardware: Z84C20 (Z80 PIO), Port A.  Data reg = $10, control reg = $12.
\ Idea: assemble a 64 Hz timer interrupt in Forth's own assembler, install
\ it through the MicroBeast BIOS, then count seconds in plain Forth.
\ `4 DELAY` waits 4 seconds.
\
\ Load all of this at the boot bank (bank 0) so the ISR + counter live in
\ fixed memory -- an interrupt fires no matter which bank is mapped.

\ ---- 1. Fixed-memory countdown cell ----------------------------------
VARIABLE TICKS-LEFT

\ ---- 2. The 64 Hz interrupt service routine --------------------------
\ Firmware fires this 64x/sec, after EXX (so HL is the shadow reg, free)
\ and with AF preserved (so A is free).  It MUST end in RET, -- NOT NEXT,
\ -- because the firmware CALLs it; the Forth interpreter never does.
CODE TICK-ISR
   HL TICKS-LEFT () LD,     \ LD HL,(TICKS-LEFT)
   A H LD,   L OR,          \ A = H OR L  -> Z flag set when HL = 0
   Z RET,                   \ already at 0? nothing to do
   HL DEC,                  \ one tick closer
   TICKS-LEFT () HL LD,     \ LD (TICKS-LEFT),HL
   RET,
END-CODE

\ ---- 3. Install / remove the ISR through the BIOS --------------------
\ MBB_SET_USR_INT @ $FDC7 : HL = routine address (0 disables).
\ DE is the Forth instruction pointer -- save it across the BIOS call.
CODE (SET-USR-INT)   ( addr -- )
   DE PUSH,                 \ preserve the Forth IP
   H B LD,   L C LD,        \ HL = BC  (addr is TOS in BC)
   $FDC7 CALL,              \ MBB_SET_USR_INT
   DE POP,                  \ restore IP
   BC POP,                  \ load next TOS (addr consumed)
   NEXT,
END-CODE

: START-CLOCK ( -- )  ['] TICK-ISR (SET-USR-INT) ;
: STOP-CLOCK  ( -- )  0 (SET-USR-INT) ;

\ ---- 4. DELAY: 64 ticks = 1 second -----------------------------------
\ The firmware header says "60th of a second" -- that is WRONG; the tick
\ really is 64 Hz, so 1 second = 64 ticks.
: DELAY ( seconds -- )
   64 *  TICKS-LEFT !
   BEGIN  TICKS-LEFT @  0=  UNTIL ;

\ ---- 5. Z84C20 PIO, Port A -------------------------------------------
\ A Z80 PIO drives nothing until you program its mode.
$10 CONSTANT PIO-A-DATA
$12 CONSTANT PIO-A-CTRL
: PIO-INIT ( -- )
   $0F PIO-A-CTRL OUT       \ mode-control word: Mode 0 (all 8 lines output)
   $07 PIO-A-CTRL OUT ;     \ interrupt-control word: PIO interrupts OFF

\ ---- 6. The traffic light --------------------------------------------
1 CONSTANT RED   2 CONSTANT AMBER   4 CONSTANT GREEN
: TRAFFIC ( -- )
   PIO-INIT  START-CLOCK
   BEGIN
      RED          PIO-A-DATA OUT   4 DELAY    \ stop
      RED AMBER OR PIO-A-DATA OUT   1 DELAY    \ get ready
      GREEN        PIO-A-DATA OUT   4 DELAY    \ go
      AMBER        PIO-A-DATA OUT   2 DELAY    \ slow down
   AGAIN ;

\ Run:    TRAFFIC          ( break with the keyboard, then  STOP-CLOCK )
\ Test:   START-CLOCK 60 DELAY   should be 60 s on a stopwatch, +/- 1.
\ Note:   if the LEDs are active-low, invert the colour masks.
