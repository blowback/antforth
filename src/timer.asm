; timer.asm — Phase-6 64 Hz system tick + monotonic TICKS counter
; AntForth — A Forth for CP/M on Z80
;
; The MicroBeast firmware fires the installed user-interrupt routine 64x/second
; (the firmware header's "60th of a second" is wrong — it is 64 Hz). This module
; owns that slot by default: COLD installs tick_isr, which maintains a 32-bit
; monotonic up-counter (tick_count) in fixed memory. TICKS reads it as a double;
; TIMER-OFF / TIMER-ON release and reclaim the single user-interrupt slot so a
; program can install its own ISR and later restore ours.
;
; A monotonic up-counter (not a TRAFFIC.FTH-style down-counter) lets any number
; of concurrent Phase-6 delays ride a stack-held target (TICKS + n*64) without a
; shared mutable cell.

; === 32-bit monotonic tick counter (fixed memory) ===
; Low cell first, high cell second — the low 16 bits sit at the lower address
; (tick_count) and the high 16 bits at tick_count+2 (standard little-endian).
; TICKS reads this and pushes it as a §3.1.4.1 double (high cell on TOS). Fixed
; memory (below the slot-2 window) so the ISR fires whichever bank is mapped.
; COLD zero-inits both.
tick_count:
        DW      0                       ; low 16 bits
        DW      0                       ; high 16 bits

; === tick_isr — the 64 Hz interrupt service routine ===
; The firmware CALLs this 64x/sec AFTER its own EXX (so HL is the shadow set,
; free) and with AF preserved (so A is free). Every other register — BC=TOS,
; DE=IP, IX=rstack, IY=UserArea, SP — is LIVE main-context and MUST be left
; untouched. The routine ends in RET (the firmware CALLed it — it is NOT a
; threaded word, so it must NOT end in NEXT).
;
; Carry trap: 16-bit `INC HL` sets NO flags, so a low-word rollover cannot be
; detected from the INC. After bumping the low word we test HL==0 explicitly
; (LD A,H / OR L) and only carry into the high word on a true 0xFFFF->0 wrap.
tick_isr:
        LD      HL, (tick_count)        ; low word
        INC     HL
        LD      (tick_count), HL
        LD      A, H
        OR      L                       ; INC rr sets no flags — test HL==0 here
        RET     NZ                      ; no rollover -> done
        LD      HL, (tick_count+2)      ; high word
        INC     HL
        LD      (tick_count+2), HL
        RET

; Cross-bank invariant: the firmware CALLs tick_isr and both the ISR and TICKS
; read tick_count regardless of which bank is mapped into the slot-2 window, so
; this whole region MUST live in always-mapped fixed memory (< $8000). The
; straddle-regression gate only catches colon-body IP crossings, not data/ISR
; placement, so guard it at build time here (kernel growth would silently push
; it into the bank window otherwise).
        ASSERT $ <= SLOT2_WINDOW_BASE

; === TICKS ( -- d ) — read the live tick counter as a double ===
; High cell on TOS (BC), low cell second-on-stack — the §3.1.4.1 double layout
; (cf. src/double.asm). TICKS PRODUCES a double and consumes nothing, so it must
; first PUSH BC to displace the current TOS (the LIT convention) — unlike 2@,
; which reuses BC because its address argument is consumed.
;
; LOCKLESS read (no DI/EI). The ISR only carries into the high word when the low
; word wraps 0xFFFF->0, and a Z80 maskable interrupt runs the whole ISR to
; completion between two of our instructions — so a carry lands atomically from
; our point of view. We read high, then low, then re-read high: if the two high
; reads differ a carry landed mid-read and we retry. A single increment always
; flips the low byte of the value it lands in (n and n+1 differ in bit 0), so a
; carry into the high word always changes its low byte — comparing the re-read
; high against the first read catches it. Each LD rr,(nn) / LD A,(nn) is itself
; uninterruptible, so no individual read tears.
; Why not DI/EI: a DI would have to restore the caller's prior interrupt state
; (a Phase-6 DELAY/critical section may DI before calling TICKS), and the usual
; LD A,I probe for that state has the well-known Z80 erratum — an interrupt taken
; during LD A,I clears P/V even when interrupts were enabled, so we could wrongly
; leave them off. The lockless read disturbs nothing. At ~64 Hz a carry is ~17
; min apart, so the retry effectively never spins.
; antforth extension — 64 Hz system tick, double (high on TOS)
w_TICKS:
        DEFCODE "TICKS", 0
w_TICKS_cf:
        PUSH    BC                      ; displace current TOS (TICKS only produces)
.ticks_read:
        LD      BC, (tick_count+2)      ; high (first read) -> BC
        LD      HL, (tick_count)        ; low
        LD      A, (tick_count+2)       ; re-read high, low byte
        CP      C
        JR      NZ, .ticks_read         ; carry landed mid-read -> retry
        LD      A, (tick_count+3)       ; re-read high, high byte
        CP      B
        JR      NZ, .ticks_read
        PUSH    HL                      ; low = second-on-stack
        NEXT                            ; BC = high = new TOS (§3.1.4.1)

; === TIMER-ON ( -- ) / TIMER-OFF ( -- ) — claim / release the tick slot ===
; MBB_SET_USR_INT (0xFDC7): HL = routine address (0 disables). The firmware
; routine clobbers A,B,C,H,L,F; save BC (=TOS) and DE (=IP) across the call (the
; TRAFFIC.FTH (SET-USR-INT) discipline). IX/IY are firmware-preserved.
; antforth extension — install the kernel 64 Hz tick ISR
w_TIMER_ON:
        DEFCODE "TIMER-ON", 0
w_TIMER_ON_cf:
        PUSH    BC                      ; save TOS
        PUSH    DE                      ; save IP
        LD      HL, tick_isr
        CALL    MBB_SET_USR_INT
        POP     DE                      ; restore IP
        POP     BC                      ; restore TOS
        NEXT

; antforth extension — release the tick slot (install address 0 = disable)
w_TIMER_OFF:
        DEFCODE "TIMER-OFF", 0
w_TIMER_OFF_cf:
        PUSH    BC                      ; save TOS
        PUSH    DE                      ; save IP
        LD      HL, 0                   ; 0 = disable the user-interrupt slot
        CALL    MBB_SET_USR_INT
        POP     DE                      ; restore IP
        POP     BC                      ; restore TOS
        NEXT

; === (DELAY) ( target.d -- ) — busy-wait until TICKS reaches the target double ===
; Internal helper (parenthesized name = kernel-internal convention, cf. (DLIT)).
; Factored into ONE site so the Phase-6 yielding rewrite can drop a single PAUSE
; cell in front of the TICKS read without disturbing the target-on-stack math in
; DELAY/MS — that single seam is the whole reason this loop is not inlined.
; >>> Story-25.3 yielding form: insert `DW w_PAUSE_cf` immediately before the
;     `DW w_TICKS_cf` below; nothing else here changes. <<<
; The target double is held on the caller's data stack as the loop carry — there
; is no shared mutable countdown cell, so concurrent per-task delays never
; interfere. D< is signed, which is correct here: a 32-bit 64 Hz counter does not
; reach the sign bit (0x8000_0000) until ~388 days of continuous uptime, far
; beyond any realistic DELAY target — no DU< is needed.
w_PAREN_DELAY:
        DEFWORD "(DELAY)", 0
w_PAREN_DELAY_body:
w_PAREN_DELAY_cf EQU w_PAREN_DELAY_body - 3
.pd_begin:
        DW      w_TICKS_cf              ; ( target  now )
        DW      w_TWO_OVER_cf           ; ( target  now  target )
        DW      w_D_LESS_cf             ; ( target  flag=now<target )  signed D<
        DW      w_ZERO_EQUALS_cf        ; ( target  flag'=now>=target )
        DW      w_QBRANCH_cf
        DW      .pd_begin - $           ; UNTIL: loop back while now<target
        DW      w_TWO_DROP_cf           ; ( )  drop the spent target double
        DW      EXIT_CODE

; === DELAY ( u -- ) — busy-wait u seconds ===
; target = TICKS + u*64 (64 ticks = 1 s), computed as a double on the caller's
; own stack and handed to (DELAY). 0 DELAY returns at once (target == TICKS).
; antforth extension — busy-wait u seconds; single-threaded form, see (DELAY)
w_DELAY:
        DEFWORD "DELAY", 0
w_DELAY_body:
w_DELAY_cf EQU w_DELAY_body - 3
        DW      w_LIT_cf, 64
        DW      w_U_M_STAR_cf           ; ( ud = u*64 )
        DW      w_TICKS_cf
        DW      w_D_PLUS_cf             ; ( target = TICKS + u*64 )
        DW      w_PAREN_DELAY_cf
        DW      EXIT_CODE

; === MS ( u -- ) — wait at least u milliseconds ===
; target = TICKS + ceil(u*64/1000). 64 Hz ⇒ 1 tick = 15.625 ms, so the tick count
; is rounded UP (add 999 before the /1000 divide): a naive round-DOWN makes
; 10 MS → 640/1000 = 0 ticks → a 0 ms wait, which would violate the "Wait at
; least u milliseconds" guarantee. With the bias any nonzero u waits ≥1 tick.
; MS is a coarse convenience over the 15.625 ms tick, not a true-ms timer.
; MS — Forth-2012 §10.6.2.1905: "Wait at least u milliseconds" (FACILITY EXT);
; 15.625 ms tick granularity, rounded UP so the "at least" guarantee holds
w_MS:
        DEFWORD "MS", 0
w_MS_body:
w_MS_cf EQU w_MS_body - 3
        DW      w_LIT_cf, 64
        DW      w_U_M_STAR_cf           ; ( ud = u*64 )
        DW      w_LIT_cf, 999
        DW      w_M_PLUS_cf             ; ( ud + 999 )  round-up bias
        DW      w_LIT_cf, 1000
        DW      w_U_M_SLASH_MOD_cf      ; ( rem quot )  quot = ceil(u*64/1000)
        DW      w_SWAP_cf
        DW      w_DROP_cf               ; ( quot )  drop remainder (no NIP word)
        DW      w_S_TO_D_cf             ; ( quot.d )
        DW      w_TICKS_cf
        DW      w_D_PLUS_cf             ; ( target = TICKS + ceil(u*64/1000) )
        DW      w_PAREN_DELAY_cf
        DW      EXIT_CODE
