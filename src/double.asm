; double.asm — Double-cell (32-bit) stack and memory primitives
; AntForth — A Forth for CP/M on Z80
;
; Epic 10 double-cell primitives:
;   Stack:        2DUP, 2DROP, 2SWAP, 2OVER        (Story 10.2)
;   Memory:       2@, 2!                           (Story 10.2)
;   Conversions:  S>D, D>S                         (Story 10.3)
;   Arithmetic:   D+, D-, M+                       (Story 10.4)
;   Sign:         DNEGATE, DABS                    (Story 10.4)
;   Compare:      D=, D<, DMAX, DMIN               (Story 10.4)
;
; Byte-order convention (architecture decision E10-D1): on the parameter
; stack, the low cell is on top and the high cell below — matching
; DPANS94 §6.1.0350 `2@ ( a-addr -- x1 x2 )` where x2 (low) is TOS.
; In memory, the low cell is stored at a-addr and the high cell at
; a-addr+2.

; -----------------------------------------------
; 2@ ( a-addr -- x1 x2 )
;   Fetch double-cell at a-addr: low cell (x2) ends on TOS, high cell
;   (x1) second on stack. x2 = M[a-addr], x1 = M[a-addr+2].
; ANS Forth 1994 §6.1.0350   2@   — double-cell fetch
; -----------------------------------------------
w_TWO_FETCH:
        DEFCODE "2@", 0
w_TWO_FETCH_cf:
        CALL    check_underflow
        LD      H, B
        LD      L, C            ; HL = a-addr
        INC     HL
        INC     HL              ; HL = a-addr + 2
        LD      A, (HL)         ; A = low byte of x1
        INC     HL
        LD      H, (HL)         ; H = high byte of x1 (HL scratch after this)
        LD      L, A            ; HL = x1 (high cell)
        PUSH    HL              ; Push x1 (second on stack)
        LD      H, B
        LD      L, C            ; HL = a-addr (BC was preserved)
        LD      C, (HL)
        INC     HL
        LD      B, (HL)         ; BC = x2 (low cell, new TOS)
        NEXT

; -----------------------------------------------
; 2! ( x1 x2 a-addr -- )
;   Store double-cell at a-addr: x2 (low) at a-addr, x1 (high) at a-addr+2.
; ANS Forth 1994 §6.1.0310   2!   — double-cell store
; -----------------------------------------------
w_TWO_STORE:
        DEFCODE "2!", 0
w_TWO_STORE_cf:
        CALL    check_underflow_3
        LD      H, B
        LD      L, C            ; HL = a-addr
        POP     BC              ; BC = x2 (low cell)
        LD      (HL), C
        INC     HL
        LD      (HL), B         ; M[a-addr], M[a-addr+1] = x2
        INC     HL              ; HL = a-addr + 2
        POP     BC              ; BC = x1 (high cell)
        LD      (HL), C
        INC     HL
        LD      (HL), B         ; M[a-addr+2], M[a-addr+3] = x1
        POP     BC              ; New TOS from below
        NEXT

; -----------------------------------------------
; 2DUP ( x1 x2 -- x1 x2 x1 x2 )
;   Duplicate the top double-cell pair. BC (x2) is unchanged; x1 is
;   read from SP and both cells are pushed between the original pair
;   and the retained TOS.
; ANS Forth 1994 §6.1.0380   2DUP   — duplicate double-cell pair
; -----------------------------------------------
w_TWO_DUP:
        DEFCODE "2DUP", 0
w_TWO_DUP_cf:
        CALL    check_underflow_2
        POP     HL              ; HL = x1, SP = (guard)
        PUSH    HL              ; Restore x1. SP = (x1, guard)
        PUSH    BC              ; Push x2 copy. SP = (x2, x1, guard)
        PUSH    HL              ; Push x1 copy. SP = (x1, x2, x1, guard)
        NEXT                    ; BC still = x2

; -----------------------------------------------
; 2DROP ( x1 x2 -- )
;   Drop the top double-cell pair. Two POPs mirror DROP's one POP
;   (DROP uses check_underflow for 1 POP; 2DROP uses check_underflow_2
;   for 2 POPs).
; ANS Forth 1994 §6.1.0370   2DROP   — drop double-cell pair
; -----------------------------------------------
w_TWO_DROP:
        DEFCODE "2DROP", 0
w_TWO_DROP_cf:
        CALL    check_underflow_2
        POP     HL              ; Discard x1
        POP     BC              ; New TOS (or phantom if input DEPTH was 2)
        NEXT

; -----------------------------------------------
; 2SWAP ( x1 x2 x3 x4 -- x3 x4 x1 x2 )
;   Swap the top two double-cell pairs. Uses the shadow register set
;   (EXX) to gain enough scratch registers to hold all four cells
;   without clobbering DE=IP.
; ANS Forth 1994 §6.1.0430   2SWAP   — swap double-cell pairs
; -----------------------------------------------
w_TWO_SWAP:
        DEFCODE "2SWAP", 0
w_TWO_SWAP_cf:
        CALL    check_underflow_4
        EXX                     ; Main now scratch; shadow holds (x4, IP, junk)
        POP     BC              ; BC = x3
        POP     HL              ; HL = x2
        POP     DE              ; DE = x1
        PUSH    BC              ; Push x3 (deepest new cell)
        EXX                     ; Main = (x4, IP, junk); shadow = (x3, x1, x2)
        PUSH    BC              ; Push x4
        EXX                     ; Main = (x3, x1, x2); shadow = (x4, IP, junk)
        PUSH    DE              ; Push x1
        PUSH    HL              ; Stage x2 on SP as new TOS
        EXX                     ; Main = (x4, IP, junk); IP restored in DE
        POP     BC              ; BC = x2 (new TOS)
        NEXT

; -----------------------------------------------
; 2OVER ( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )
;   Copy the second double-cell pair over the first. No rearrangement
;   of existing items is needed; x1 and x2 are read via SP-relative
;   loads after pushing x4.
; ANS Forth 1994 §6.1.0400   2OVER   — copy second double-cell pair
; -----------------------------------------------
w_TWO_OVER:
        DEFCODE "2OVER", 0
w_TWO_OVER_cf:
        CALL    check_underflow_4
        PUSH    BC              ; Push x4. SP = (x4, x3, x2, x1, guard)
        LD      HL, 6
        ADD     HL, SP          ; HL = SP + 6 = address of x1
        LD      C, (HL)
        INC     HL
        LD      B, (HL)         ; BC = x1
        PUSH    BC              ; Push x1. SP = (x1, x4, x3, x2, x1, guard)
        LD      HL, 6
        ADD     HL, SP          ; HL = SP + 6 = address of x2
        LD      C, (HL)
        INC     HL
        LD      B, (HL)         ; BC = x2 (new TOS)
        NEXT

; -----------------------------------------------
; S>D ( n -- d )
;   Sign-extend single to double. BC (= n) stays as the low cell on TOS;
;   high cell is 0 if n >= 0, or -1 ($FFFF) if n < 0, pushed under BC.
; ANS Forth 1994 §6.1.2170   S>D   — sign-extend single to double
; -----------------------------------------------
w_S_TO_D:
        DEFCODE "S>D", 0
w_S_TO_D_cf:
        CALL    check_underflow
        LD      A, B            ; A = high byte of n (sign bit in bit 7)
        RLA                     ; Carry = sign bit of n
        SBC     A, A            ; A = 0 if n >= 0, $FF if n < 0
        LD      H, A
        LD      L, A            ; HL = 0 or $FFFF (sign-extended high cell)
        PUSH    HL              ; Push high cell under BC (low cell = TOS)
        NEXT

; -----------------------------------------------
; D>S ( d -- n )
;   Narrow double to single by dropping the high cell. BC already holds
;   x2 (low cell, TOS) on entry and is the correct ANS output.
;   Truncation is ANS implementation-defined: the high cell is
;   unconditionally dropped — safe when d is within single-cell range,
;   silently truncating otherwise.
; ANS Forth 1994 §8.6.1140   D>S   — narrow double to single (truncating)
; -----------------------------------------------
w_D_TO_S:
        DEFCODE "D>S", 0
w_D_TO_S_cf:
        CALL    check_underflow_2
        POP     HL              ; Discard x1 (high cell); BC (= x2) stays as TOS
        NEXT

; -----------------------------------------------
; M+ ( d1 n -- d2 )
;   Mixed single+double add. n is sign-extended to 32 bits then added
;   to d1; low cell on TOS, high cell below. CF from the low-cell add
;   is stashed on the return (AF) stack while BC is rewritten to the
;   sign-extended high half of n.
; ANS Forth 1994 §8.6.1830   M+   — mixed single+double add (sign-extended)
; -----------------------------------------------
w_M_PLUS:
        DEFCODE "M+", 0
w_M_PLUS_cf:
        CALL    check_underflow_3
        POP     HL              ; HL = x2 (low of d1)
        ADD     HL, BC          ; HL = x2 + n = new low; CF = carry
        EX      (SP), HL        ; HL = x1 (high of d1); SP top = new low
        PUSH    AF              ; Save CF across sign-extend
        LD      A, B            ; A = high byte of n (sign in bit 7)
        RLA                     ; CF = sign bit of n
        SBC     A, A            ; A = 0 if n >= 0, $FF if n < 0
        LD      B, A
        LD      C, A            ; BC = sign-extended high half of n
        POP     AF              ; Restore CF = carry from low-cell add
        ADC     HL, BC          ; HL = x1 + sign_ext(n) + carry = new high
        EX      (SP), HL        ; HL = new low; SP top = new high
        LD      B, H
        LD      C, L            ; BC = new low (TOS)
        NEXT

; -----------------------------------------------
; D+ ( d1 d2 -- d3 )
;   Double-cell add: d3 = d1 + d2 with 32-bit carry propagation.
;   IP (DE) is stashed to scratch memory so DE is available for the
;   intermediate register juggle. CF from the low-cell ADD survives
;   the ensuing POP BC because POP does not affect flags.
; ANS Forth 1994 §8.6.1040   D+   — double-cell add
; -----------------------------------------------
w_D_PLUS:
        DEFCODE "D+", 0
w_D_PLUS_cf:
        CALL    check_underflow_4
        LD      (double_ip_stash), DE
        POP     HL              ; HL = x3 (high of d2)
        POP     DE              ; DE = x2 (low of d1)
        EX      DE, HL          ; HL = x2; DE = x3
        ADD     HL, BC          ; HL = x2 + x4 = new low; CF = carry
        POP     BC              ; BC = x1; CF preserved
        EX      DE, HL          ; HL = x3; DE = new low; CF preserved
        ADC     HL, BC          ; HL = x3 + x1 + carry = new high
        PUSH    HL              ; Push new high
        LD      B, D
        LD      C, E            ; BC = new low (TOS)
        LD      DE, (double_ip_stash)
        NEXT

; -----------------------------------------------
; D- ( d1 d2 -- d3 )
;   Double-cell subtract: d3 = d1 - d2 with 32-bit borrow propagation.
; ANS Forth 1994 §8.6.1050   D-   — double-cell subtract
; -----------------------------------------------
w_D_MINUS:
        DEFCODE "D-", 0
w_D_MINUS_cf:
        CALL    check_underflow_4
        LD      (double_ip_stash), DE
        POP     DE              ; DE = x3 (high of d2)
        POP     HL              ; HL = x2 (low of d1)
        OR      A               ; Clear CF
        SBC     HL, BC          ; HL = x2 - x4 = new low; CF = borrow
        POP     BC              ; BC = x1; CF preserved
        PUSH    HL              ; Save new low; CF preserved
        LD      H, B
        LD      L, C            ; HL = x1
        LD      B, D
        LD      C, E            ; BC = x3
        SBC     HL, BC          ; HL = x1 - x3 - borrow = new high
        POP     BC              ; BC = new low (TOS)
        PUSH    HL              ; Push new high
        LD      DE, (double_ip_stash)
        NEXT

; -----------------------------------------------
; (DLIT) ( -- d.hi-2nd d.lo-tos )
;   Runtime for a compiled double-cell literal. Reads 4 inline bytes
;   from the thread following its own code-field: low cell first, then
;   high cell. Pushes the pair so the low cell is on TOS (per E10-D1)
;   and the high cell is second-on-stack — matching D+ / 2@ / D.
;   consumption order. Advances IP by 4 bytes.
;   Inline layout in compiled code: [w_D_LIT_cf addr][d.lo lo,hi][d.hi lo,hi]
;   so a 2! of the same value at (HERE+2) round-trips byte-for-byte.
; ANS Forth 1994 §3.4.1.3 — runtime for compile-state double-literal emitted
;   by NUMBER-PREFIX? / NUMBER? when a dot-bearing digit string is parsed.
; Story 13.0 — paren-convention internal helper (architecture.md:438).
; -----------------------------------------------
w_D_LIT:
        DEFCODE "(DLIT)", 0
w_D_LIT_cf:
        ; Story 11.5.2 -3 THROW guard. Depth grows by 2 cells (high + low);
        ; the 32-byte safety margin in check_overflow covers both cells.
        CALL    check_overflow
        PUSH    BC                      ; spill old TOS (3rd-on-stack)
        EX      DE, HL                  ; HL = IP (→ low cell)
        LD      C, (HL)
        INC     HL
        LD      B, (HL)                 ; BC = d.lo (new TOS)
        INC     HL                      ; HL → high cell
        LD      E, (HL)
        INC     HL
        LD      D, (HL)                 ; DE = d.hi
        INC     HL                      ; HL = new IP (past 4 inline bytes)
        PUSH    DE                      ; push d.hi as second-on-stack
        NEXTHL                          ; HL is already new IP — skip the EX

; -----------------------------------------------
; DNEGATE ( d -- -d )
;   Double-cell two's-complement negation: -d = 0 - d. The unique
;   $80000000 fixed-point case negates to itself (ANS-conformant;
;   mirrors single-cell NEGATE of $8000).
; ANS Forth 1994 §8.6.1230   DNEGATE   — double-cell two's-complement negate
; -----------------------------------------------
w_D_NEGATE:
        DEFCODE "DNEGATE", 0
w_D_NEGATE_cf:
        CALL    check_underflow_2
        LD      (double_ip_stash), DE
        OR      A               ; Clear CF
        LD      HL, 0
        SBC     HL, BC          ; HL = 0 - low = -low; CF = borrow
        LD      B, H
        LD      C, L            ; BC = new low
        POP     DE              ; DE = high; CF preserved
        LD      HL, 0
        SBC     HL, DE          ; HL = 0 - high - borrow = new high
        PUSH    HL              ; Push new high
        LD      DE, (double_ip_stash)
        NEXT

; -----------------------------------------------
; DABS ( d -- ud )
;   Double-cell absolute value. Peek the high cell's sign bit via
;   SP+1 (high byte of the cell directly beneath BC) without popping;
;   fall through for non-negative d; tail-call DNEGATE for negative d.
;   The re-entry into DNEGATE re-checks underflow (cheap, ~30 T-states).
; ANS Forth 1994 §8.6.1160   DABS   — double-cell absolute value
; -----------------------------------------------
w_D_ABS:
        DEFCODE "DABS", 0
w_D_ABS_cf:
        CALL    check_underflow_2
        LD      HL, 1
        ADD     HL, SP          ; HL = addr of high byte of the high cell
        LD      A, (HL)         ; A = high byte of high cell
        OR      A               ; S = bit 7 = sign of d
        JP      P, .dabs_done   ; Non-negative: pass through unchanged
        JP      w_D_NEGATE_cf   ; Negative: tail-call DNEGATE
.dabs_done:
        NEXT

; -----------------------------------------------
; D= ( d1 d2 -- flag )
;   True flag iff d1 equals d2 bit-for-bit across both cells. Short-
;   circuits on low-cell mismatch but still drops x1 so the stack net
;   is (4 consumed, 1 pushed).
; ANS Forth 1994 §8.6.1120   D=   — double-cell equality → flag
; -----------------------------------------------
w_D_EQUALS:
        DEFCODE "D=", 0
w_D_EQUALS_cf:
        CALL    check_underflow_4
        LD      (double_ip_stash), DE
        POP     DE              ; DE = x3 (high of d2)
        POP     HL              ; HL = x2 (low of d1)
        OR      A
        SBC     HL, BC          ; Z iff x2 == x4
        JR      NZ, .deq_false_pop1
        POP     HL              ; HL = x1 (high of d1)
        OR      A
        SBC     HL, DE          ; Z iff x1 == x3
        JR      NZ, .deq_false
        LD      BC, -1          ; TRUE
        JR      .deq_done
.deq_false_pop1:
        POP     HL              ; Drop x1 (low-cell mismatch already decided)
.deq_false:
        LD      BC, 0           ; FALSE
.deq_done:
        LD      DE, (double_ip_stash)
        NEXT

; -----------------------------------------------
; D< ( d1 d2 -- flag )
;   Double-cell signed less-than. Compute (d1 - d2) as a full 32-bit
;   subtract; the high-cell SBC's S and P/V flags encode the signed
;   compare of the *whole* 32-bit difference: the result is signed-
;   negative iff (S XOR P/V) = 1. This naturally handles the two
;   distinct regimes — high cells differ (decided at the high SBC) and
;   high cells equal (in which case the high SBC reduces to 0 - borrow,
;   whose sign reflects the unsigned low-cell compare).
; ANS Forth 1994 §8.6.1110   D<   — double-cell signed less-than → flag
; -----------------------------------------------
w_D_LESS:
        DEFCODE "D<", 0
w_D_LESS_cf:
        CALL    check_underflow_4
        LD      (double_ip_stash), DE
        POP     HL              ; HL = x3
        EX      (SP), HL        ; HL = x2; SP top = x3
        OR      A               ; Clear CF
        SBC     HL, BC          ; HL = x2 - x4 (low-cell diff); CF = borrow
        POP     BC              ; BC = x3; CF preserved
        POP     HL              ; HL = x1; CF preserved
        SBC     HL, BC          ; HL = x1 - x3 - borrow; S, P/V set
        LD      BC, 0           ; Assume FALSE
        JP      PO, .dlt_no_ov  ; P/V = 0: no signed overflow
        ; P/V = 1: 16-bit signed overflow flipped the result's sign
        JP      M, .dlt_done    ; S=1, V=1 → S XOR V = 0 → NOT less
        DEC     BC              ; S=0, V=1 → S XOR V = 1 → less → BC = -1
        JR      .dlt_done
.dlt_no_ov:
        JP      P, .dlt_done    ; S=0, V=0 → NOT less
        DEC     BC              ; S=1, V=0 → less → BC = -1
.dlt_done:
        LD      DE, (double_ip_stash)
        NEXT

; -----------------------------------------------
; DMAX ( d1 d2 -- d )
;   Return the larger of d1 and d2 under D< (signed) ordering.
;   Thin DEFWORD wrapper: 2OVER 2OVER D< IF 2SWAP THEN 2DROP.
;   Equal-case returns d1 (the deeper pair survives the 2DROP).
; ANS Forth 1994 §8.6.1210   DMAX   — double-cell max (signed)
; -----------------------------------------------
w_D_MAX:
        DEFWORD "DMAX", 0
w_D_MAX_body:
w_D_MAX_cf EQU w_D_MAX_body - 3
        DW      w_TWO_OVER_cf
        DW      w_TWO_OVER_cf
        DW      w_D_LESS_cf
        DW      w_QBRANCH_cf
        DW      .dmax_skip - $
        DW      w_TWO_SWAP_cf
.dmax_skip:
        DW      w_TWO_DROP_cf
        DW      EXIT_CODE

; -----------------------------------------------
; DMIN ( d1 d2 -- d )
;   Return the smaller of d1 and d2 under D< (signed) ordering.
;   Thin DEFWORD wrapper: 2OVER 2OVER D< 0= IF 2SWAP THEN 2DROP.
;   (Flag is inverted so QBRANCH-on-FALSE skips 2SWAP exactly when
;   d1 < d2, leaving d1 on top as the minimum.)
; ANS Forth 1994 §8.6.1220   DMIN   — double-cell min (signed)
; -----------------------------------------------
w_D_MIN:
        DEFWORD "DMIN", 0
w_D_MIN_body:
w_D_MIN_cf EQU w_D_MIN_body - 3
        DW      w_TWO_OVER_cf
        DW      w_TWO_OVER_cf
        DW      w_D_LESS_cf
        DW      w_ZERO_EQUALS_cf
        DW      w_QBRANCH_cf
        DW      .dmin_skip - $
        DW      w_TWO_SWAP_cf
.dmin_skip:
        DW      w_TWO_DROP_cf
        DW      EXIT_CODE

; -----------------------------------------------
; UM* ( u1 u2 -- ud )
;   Unsigned mixed multiply: 16-bit u1 × 16-bit u2 → 32-bit ud.
;   Right-shift schoolbook method: BC starts holding u2 (multiplier) and
;   drains as bits are consumed from its LSB; HL accumulates the high
;   half of the product. The 32-bit accumulator (HL:BC) is shifted right
;   by 1 each iteration; the carry-out of ADD HL,DE is captured by the
;   subsequent RR H, giving an effective 33-bit shift register so the
;   $FFFF × $FFFF = $FFFE0001 corner case settles correctly.
; ANS Forth 1994 §6.1.2360   UM*   — unsigned mixed multiply (single × single → double)
; -----------------------------------------------
w_U_M_STAR:
        DEFCODE "UM*", 0
w_U_M_STAR_cf:
        CALL    check_underflow_2
        LD      (double_ip_stash), DE   ; Stash IP — DE now free
        POP     DE              ; DE = u1 (multiplicand, held fixed)
        LD      HL, 0           ; HL = accumulator high half
        LD      A, 16           ; Loop counter (16 multiplier bits)
.umstar_loop:
        OR      A               ; Clear CF (safe path if BIT skips ADD)
        BIT     0, C            ; Test current LSB of multiplier in BC
        JR      Z, .umstar_skip
        ADD     HL, DE          ; acc += multiplicand; CF = carry-out
.umstar_skip:
        RR      H               ; 33-bit shift right: CF (or 0) → bit 7 of H
        RR      L
        RR      B
        RR      C               ; Multiplier LSB shifted out (consumed)
        DEC     A
        JR      NZ, .umstar_loop
        ; HL = product high cell, BC = product low cell (TOS)
        PUSH    HL              ; Push high cell under BC (low cell stays TOS)
        LD      DE, (double_ip_stash)
        NEXT

; -----------------------------------------------
; M* ( n1 n2 -- d )
;   Signed mixed multiply: 16-bit signed × 16-bit signed → 32-bit signed
;   double. Wraps UM* with sign tracking: stash sign(n1) XOR sign(n2),
;   replace operands with their absolute values, multiply unsigned, then
;   DNEGATE the double result if the stashed sign was negative.
;
;   The single-cell ABS($8000) = $8000 fixed-point trap collapses cleanly:
;   for `-32768 -32768 M*`, the sign-XOR is positive (negative XOR negative),
;   so no DNEGATE; UM*($8000, $8000) = $40000000 = (16384, 0), which is
;   the correct +1073741824 = (-32768) × (-32768).
; ANS Forth 1994 §6.1.1810   M*   — signed mixed multiply (single × single → double)
; -----------------------------------------------
w_M_STAR:
        DEFWORD "M*", 0
w_M_STAR_body:
w_M_STAR_cf EQU w_M_STAR_body - 3
        DW      w_TWO_DUP_cf            ; Underflow guard (needs >= 2)
        DW      w_XOR_cf                ; n1 XOR n2 — sign bit reflects sign-XOR
        DW      w_ZERO_LESS_cf          ; flag = (sign-XOR < 0) ? -1 : 0
        DW      w_TO_R_cf               ; Stash sign flag on R-stack
        DW      w_ABS_cf                ; |n2|
        DW      w_SWAP_cf
        DW      w_ABS_cf                ; |n1|
        DW      w_SWAP_cf               ; ( |n1| |n2| )
        DW      w_U_M_STAR_cf           ; ( ud-hi ud-lo ) — unsigned product
        DW      w_R_FROM_cf             ; Recover sign flag
        DW      w_QBRANCH_cf
        DW      .mstar_skip - $
        DW      w_D_NEGATE_cf           ; If signs differed, negate the double
.mstar_skip:
        DW      EXIT_CODE

; -----------------------------------------------
; D* ( d1 d2 -- d3 )
;   Truncating signed double × double: low 32 bits of the 64-bit product.
;   Two's-complement two-fold: low-32 of (signed) is bit-identical to
;   low-32 of (unsigned), so no sign tracking is required.
;
;   Algebra (treating both as unsigned, with d_i = a_i*2^16 + b_i):
;       d3 = (b1*b2) + ((b1*a2 + a1*b2) << 16)  mod 2^32
;   The cross terms (b1*a2 and a1*b2) contribute only to the high cell
;   so we use the truncating single-cell `*` for them and add into the
;   high half of the full UM*(b1, b2) product.
;
;   Threaded body:
;       2OVER 2DROP       \ underflow_4 guard via 2OVER's check
;       >R                \ stash b2 on R
;       OVER R@ UM*       \ ( a1 b1 a2 P_hi P_lo )      P = b1*b2 (32-bit)
;       2SWAP * ROT +     \ ( a1 P_lo H1 ); H1 = (P_hi + b1*a2) mod 2^16
;       R> 3 PICK *       \ ( a1 P_lo H1 a1*b2 )
;       SWAP +            \ ( a1 P_lo res_hi )
;       ROT DROP SWAP     \ ( res_hi P_lo ) = ( res_hi res_lo )
; ANS Forth 1994 §8.6.1090   D*   — double-cell signed multiply (truncating)
; -----------------------------------------------
w_D_STAR:
        DEFWORD "D*", 0
w_D_STAR_body:
w_D_STAR_cf EQU w_D_STAR_body - 3
        DW      w_TWO_OVER_cf           ; Underflow guard (needs >= 4)
        DW      w_TWO_DROP_cf           ; Drop the duplicates from 2OVER
        DW      w_TO_R_cf               ; >R: stash b2
        DW      w_OVER_cf               ; copy b1
        DW      w_R_FETCH_cf            ; R@: copy b2
        DW      w_U_M_STAR_cf           ; UM*(b1,b2) → (P_hi, P_lo)
        DW      w_TWO_SWAP_cf           ; ( a1 P_hi P_lo b1 a2 )
        DW      w_STAR_cf               ; ( a1 P_hi P_lo (b1*a2) ) — single * truncates
        DW      w_ROT_cf                ; ( a1 P_lo (b1*a2) P_hi )
        DW      w_PLUS_cf               ; ( a1 P_lo H1 ) — H1 = P_hi + b1*a2 mod 2^16
        DW      w_R_FROM_cf             ; ( a1 P_lo H1 b2 ) — recover b2
        DW      w_LIT_cf
        DW      3
        DW      w_PICK_cf               ; ( a1 P_lo H1 b2 a1 ) — copy a1 to top
        DW      w_STAR_cf               ; ( a1 P_lo H1 (b2*a1) ) — single * truncates
        DW      w_SWAP_cf               ; ( a1 P_lo (b2*a1) H1 )
        DW      w_PLUS_cf               ; ( a1 P_lo res_hi )
        DW      w_ROT_cf                ; ( P_lo res_hi a1 )
        DW      w_DROP_cf               ; ( P_lo res_hi )
        DW      w_SWAP_cf               ; ( res_hi P_lo ) = ( res_hi res_lo )
        DW      EXIT_CODE

; -----------------------------------------------
; UM/MOD ( ud u1 -- urem uquot )
;   Unsigned mixed divide: 32-bit unsigned double dividend ÷ 16-bit
;   unsigned single divisor → 16-bit unsigned remainder (second on
;   stack) + 16-bit unsigned quotient (TOS).
;
;   Restoring shift-subtract: DE is pre-seeded with the high cell of
;   ud (the running remainder); HL holds the low cell of ud (doubles
;   as the quotient accumulator — its top bit shifts into DE's bottom
;   each iteration while we set its bottom bit when the trial subtract
;   succeeds). Sixteen iterations extract sixteen quotient bits.
;
;   Thirty-third-bit handling: the RL D at each iteration's top sets
;   CF to the bit shifted out of DE's top. When that CF is 1, the
;   conceptual 33-bit remainder is ≥ 2^16 and the 16-bit divisor
;   always fits — the force path subtracts unconditionally and sets
;   the quotient bit.
;
;   Quotient-overflow behaviour (DPANS94 §3.2.2.1 / §6.1.2370): when
;   the true quotient does not fit in a single cell the result is
;   implementation-defined. antforth silently returns the low 16 bits
;   of the quotient — matching the single-cell `/` truncation
;   convention. No overflow check; Epic 11 may reconsider.
;
;   Divide-by-zero: Migrated by Story 11.4: divisor-zero raises
;   `-10 THROW` (catchable via `CATCH`; uncaught diagnostic
;   `error -10: division by zero`). The single guard at this site
;   covers SM/REM, FM/MOD, */, and */MOD (each funnels through
;   UM/MOD), plus bare UM/MOD user invocations. Note: M/MOD is not
;   a kernel primitive in antforth (Story 11.4 review F3).
; ANS Forth 1994 §6.1.2370   UM/MOD   — unsigned mixed divide (double ÷ single → single rem + single quot)
; -----------------------------------------------
w_U_M_SLASH_MOD:
        DEFCODE "UM/MOD", 0
w_U_M_SLASH_MOD_cf:
        CALL    check_underflow_3
        ; Divisor-zero guard (Story 11.4): BC = the divisor n at this
        ; point. Single guard covers every double-cell-divide path.
        ; -10 THROW (Story 11.4): division by zero per ANS Forth 1994 §9.3.5
        LD      A, B
        OR      C
        JR      NZ, .ummod_proceed
        LD      BC, THROW_DIV_BY_ZERO
        JP      w_THROW_cf.kernel_entry
.ummod_proceed:
        LD      (double_ip_stash), DE   ; Stash IP — DE now free
        POP     HL                      ; HL = ud-lo (quotient accumulator)
        POP     DE                      ; DE = ud-hi (running remainder)
        LD      A, 16                   ; 16-iteration shift-subtract loop
.ummod_loop:
        ADD     HL, HL                  ; Quot-accum <<= 1; CF = bit shifted out
        RL      E                       ; Shift CF into remainder low
        RL      D                       ; Shift remainder; CF = 33rd bit
        JR      C, .ummod_force         ; Rem overflowed → always subtract & set
        EX      DE, HL                  ; HL = remainder, DE = quot accum
        OR      A                       ; Clear CF before trial subtract
        SBC     HL, BC                  ; Try remainder - divisor
        JR      NC, .ummod_set          ; No borrow: subtract succeeded
        ADD     HL, BC                  ; Restore remainder (trial failed)
        EX      DE, HL                  ; DE = remainder, HL = quot accum
        JR      .ummod_next
.ummod_force:
        EX      DE, HL                  ; HL = remainder (33rd bit conceptually set)
        OR      A                       ; Clear CF before SBC
        SBC     HL, BC                  ; Unconditionally subtract (always fits)
.ummod_set:
        EX      DE, HL                  ; DE = remainder, HL = quot accum
        SET     0, L                    ; Record quotient bit
.ummod_next:
        DEC     A
        JR      NZ, .ummod_loop
        PUSH    DE                      ; Push remainder (second on stack)
        LD      B, H
        LD      C, L                    ; BC = quotient (TOS)
        LD      DE, (double_ip_stash)
        NEXT

; -----------------------------------------------
; (?3) ( -- )
;   Internal underflow guard: asserts DEPTH >= 3, falling through to
;   ABORT via check_underflow_3 on failure. Threaded as the first
;   opcode of DEFWORD SM/REM and FM/MOD so the 3-cell guard fires
;   before any body word runs (none of those bodies' first words
;   individually guards for 3 — OVER / DUP / 2DUP / DABS need only 2
;   or fewer). Named with the existing `(X)`-style internal-word
;   convention (cf. `(DO)`, `(LOOP)`, `(DOES>)`).
; -----------------------------------------------
w_QGUARD_3:
        DEFCODE "(?3)", 0
w_QGUARD_3_cf:
        CALL    check_underflow_3
        NEXT

; -----------------------------------------------
; SM/REM ( d n1 -- nrem nquot )
;   Symmetric signed mixed divide: quotient truncates toward zero;
;   remainder's sign matches the dividend's sign. For
;   d = q·n1 + r:  sign(r) == sign(d), |q| == trunc(|d|/|n1|).
;
;   Decomposition (DPANS94 §A.6.1.2214 reference body): capture
;   sign(d-hi) XOR sign(n1) on the return stack for the quotient-
;   sign fixup; capture sign(d-hi) alone for the remainder-sign
;   fixup; ABS / DABS the operands; call UM/MOD; apply the fixups.
;   Two `2 PICK` reaches extract d-hi without permanently perturbing
;   the stack order.
;
;   $80000000 corner: DABS($80000000) returns $80000000 unchanged
;   (mirrors single-cell ABS($8000)). For this SM/REM input the
;   true quotient would overflow single-cell range anyway, so
;   AC #7's implementation-defined-truncation convention applies.
; ANS Forth 1994 §6.1.2214   SM/REM   — symmetric signed mixed divide
;   (quotient truncates toward zero; remainder sign matches dividend)
; -----------------------------------------------
w_S_M_SLASH_REM:
        DEFWORD "SM/REM", 0
w_S_M_SLASH_REM_body:
w_S_M_SLASH_REM_cf EQU w_S_M_SLASH_REM_body - 3
        DW      w_QGUARD_3_cf           ; Underflow guard (3 cells)
        DW      w_LIT_cf                ; 2 PICK — copy d-hi
        DW      2
        DW      w_PICK_cf
        DW      w_OVER_cf               ; copy n1 (was TOS before PICK, now 2nd)
        DW      w_XOR_cf                ; d-hi XOR n1
        DW      w_ZERO_LESS_cf          ; quotient-sign flag (true if signs differ)
        DW      w_TO_R_cf               ; R: (quot-sign)
        DW      w_LIT_cf                ; 2 PICK — copy d-hi again
        DW      2
        DW      w_PICK_cf
        DW      w_ZERO_LESS_cf          ; remainder-sign flag (true if d < 0)
        DW      w_TO_R_cf               ; R: (quot-sign rem-sign)
        DW      w_ABS_cf                ; |n1|
        DW      w_TO_R_cf               ; R: (quot-sign rem-sign |n1|)
        DW      w_D_ABS_cf              ; |d|
        DW      w_R_FROM_cf             ; recover |n1|: ( |d-hi| |d-lo| |n1| )
        DW      w_U_M_SLASH_MOD_cf      ; ( urem uquot )
        DW      w_SWAP_cf               ; ( uquot urem )
        DW      w_R_FROM_cf             ; ( uquot urem rem-sign )
        DW      w_QBRANCH_cf
        DW      .sm_rem_done - $
        DW      w_NEGATE_cf             ; fix remainder sign if dividend was negative
.sm_rem_done:
        DW      w_SWAP_cf               ; ( rem uquot )
        DW      w_R_FROM_cf             ; ( rem uquot quot-sign )
        DW      w_QBRANCH_cf
        DW      .sm_quot_done - $
        DW      w_NEGATE_cf             ; fix quotient sign if signs differed
.sm_quot_done:
        DW      EXIT_CODE

; -----------------------------------------------
; FM/MOD ( d n1 -- nrem nquot )
;   Floored signed mixed divide: quotient rounds toward negative
;   infinity; remainder's sign matches the divisor's sign. For
;   d = q·n1 + r:  sign(r) == sign(n1), q = floor(d/n1).
;
;   Decomposition (DPANS94 §A.6.1.1561 reference body): call SM/REM;
;   when remainder is non-zero AND sign(remainder) differs from
;   sign(divisor), decrement the quotient and add the divisor to
;   the remainder. The two guards (r ≠ 0 and sign-differ) must both
;   hold — skipping `r ≠ 0` corrupts exact-division cases
;   (`0 9 3 FM/MOD` → expected `( 0 3 )`, not `( 3 2 )`); skipping
;   sign-differ corrupts same-sign cases (`0 10 3 FM/MOD` →
;   expected `( 1 3 )`, not `( -2 4 )`).
; ANS Forth 1994 §6.1.1561   FM/MOD   — floored signed mixed divide
;   (quotient rounds toward -∞; remainder sign matches divisor)
; -----------------------------------------------
w_F_M_SLASH_MOD:
        DEFWORD "FM/MOD", 0
w_F_M_SLASH_MOD_body:
w_F_M_SLASH_MOD_cf EQU w_F_M_SLASH_MOD_body - 3
        DW      w_QGUARD_3_cf           ; Underflow guard (3 cells)
        DW      w_DUP_cf                ; preserve n1 for the correction step
        DW      w_TO_R_cf               ; R: (n1)
        DW      w_S_M_SLASH_REM_cf      ; ( rem quot )
        DW      w_OVER_cf               ; ( rem quot rem )
        DW      w_QBRANCH_cf
        DW      .fm_done - $            ; if rem == 0 no correction
        DW      w_R_FETCH_cf            ; ( rem quot n1 )
        DW      w_LIT_cf
        DW      2
        DW      w_PICK_cf               ; ( rem quot n1 rem )
        DW      w_XOR_cf                ; ( rem quot (n1 XOR rem) )
        DW      w_ZERO_LESS_cf          ; ( rem quot signs-differ-flag )
        DW      w_QBRANCH_cf
        DW      .fm_done - $            ; if signs match no correction
        DW      w_SWAP_cf               ; ( quot rem )
        DW      w_R_FETCH_cf            ; ( quot rem n1 )
        DW      w_PLUS_cf               ; ( quot rem+n1 )
        DW      w_SWAP_cf               ; ( rem+n1 quot )
        DW      w_ONE_MINUS_cf          ; ( rem+n1 quot-1 )
.fm_done:
        DW      w_R_FROM_cf             ; ( rem quot n1 )
        DW      w_DROP_cf               ; ( rem quot )
        DW      EXIT_CODE

; Shared scratch cell for stashing IP (DE) across the DEFCODE double-
; cell words that need DE as a general-purpose register (D+, D-, D=,
; D<, DNEGATE, UM*, UM/MOD). Never accessed from threaded code and
; never held across a NEXT, so one shared cell is safe.
double_ip_stash:
        DW      0
