\ TRAFFIC.FTH -- background traffic-light demo for antforth (cooperative task)
\ Hardware: Z84C20 (Z80 PIO), Port A.  Data reg = $10, control reg = $12.
\
\ The headline moment of the cooperative multitasker: the lights cycle on tempo
\ as a BACKGROUND TASK while the `ok` prompt stays live -- you keep defining and
\ evaluating words with one hand while the machine keeps time with the other.
\
\ This is the SEQUEL to the earlier terminal-hijacking prototype.  Two things
\ make it a real background task instead of a loop that owns the terminal:
\   * every `DELAY` is the KERNEL's yielding DELAY -- while a light is holding,
\     the task parks at a PAUSE inside DELAY and hands the CPU back to the ring,
\     so the prompt never freezes (that is the whole point);
\   * the tick clock is the KERNEL's -- `TIMER-ON` installs the 64 Hz slot the
\     yielding DELAY counts against.  The demo installs NO interrupt of its own:
\     a private ISR would evict the kernel tick slot and DELAY would then hang.
\ So there is no private DELAY and no private ISR here -- both would shadow /
\ evict the kernel's and re-freeze the prompt.
\
\ RUN RECIPE (operator, at the prompt or via INCLUDE then the last two lines):
\   INCLUDE TRAFFIC.FTH        \ compiles the words below; defines LIGHTS
\   TIMER-ON                   \ start the 64 Hz tick so DELAY can complete
\   ' RUN-LIGHTS LIGHTS ACTIVATE   \ arm the background light task
\   ( keep typing -- the prompt is live; the lights keep time )
\   .TASKS                     \ shows  0 * AWAKE  (you) and  1   AWAKE  (LIGHTS)
\ STOP / RECOVER:
\   Ctrl-\  breaks a runaway task (in-band keyboard break); or  LIGHTS SLEEP
\   parks the light task; then  TIMER-OFF  stops the tick.

\ ---- Z84C20 PIO, Port A ----------------------------------------------
\ A Z80 PIO drives nothing until you program its mode.
$10 CONSTANT PIO-A-DATA
$12 CONSTANT PIO-A-CTRL
: PIO-INIT ( -- )
   $0F PIO-A-CTRL OUT       \ mode-control word: Mode 0 (all 8 lines output)
   $07 PIO-A-CTRL OUT ;     \ interrupt-control word: PIO interrupts OFF

\ ---- The three lamps -------------------------------------------------
\ Note: if the LEDs are active-low, invert the colour masks.
1 CONSTANT RED   2 CONSTANT AMBER   4 CONSTANT GREEN

\ ---- The background light task ---------------------------------------
\ A named task handle.  `TASK` is ( -- task ): it splices a new TCB into the
\ ring and pushes its handle; a CONSTANT gives that handle a name.
TASK CONSTANT LIGHTS

\ The cycle.  Forever loop is `BEGIN ... 0 UNTIL` (terminable) -- `AGAIN` is not
\ defined in antforth.  Each `DELAY` is the kernel yielding DELAY: the task parks
\ there and the prompt keeps running.  `RUN-LIGHTS` never calls TIMER-ON itself,
\ so the operator arms the tick once (see the run recipe) and can TIMER-OFF later
\ without editing the task.
: RUN-LIGHTS ( -- )
   PIO-INIT
   BEGIN
      RED          PIO-A-DATA OUT   4 DELAY    \ stop
      RED AMBER OR PIO-A-DATA OUT   1 DELAY    \ get ready
      GREEN        PIO-A-DATA OUT   4 DELAY    \ go
      AMBER        PIO-A-DATA OUT   2 DELAY    \ slow down
   0 UNTIL ;
