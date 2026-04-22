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

; Shared scratch cell for stashing IP (DE) across the DEFCODE double-
; cell words that need DE as a general-purpose register (D+, D-, D=,
; D<, DNEGATE). Never accessed from threaded code and never held across
; a NEXT, so one shared cell is safe.
double_ip_stash:
        DW      0
