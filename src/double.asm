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
; Byte-order convention (architecture decision E10-D1, post-Story-13.0.1):
; on the parameter stack, the HIGH cell is on top and the LOW cell below —
; matching ANS Forth 1994 §3.1.4.1 ("the cell containing the most
; significant part of a double-cell integer shall be above the cell
; containing the least significant part") and §6.1.0350 `2@ ( a-addr --
; x1 x2 )` where x2 (the most-significant cell, MSC) is TOS. In memory,
; the HIGH cell is stored at a-addr and the LOW cell at a-addr+2 (each
; cell internally little-endian per Z80 native order; the cell-pair is
; "big-endian"). Story 13.0.1 (2026-05-01) flipped from the inverted
; pre-13.0.1 convention; see architecture.md E10-D1 decision history.

; -----------------------------------------------
; 2@ ( a-addr -- x1 x2 )
;   Fetch double-cell at a-addr: x2 (high cell, MSC) ends on TOS;
;   x1 (low cell) second on stack. x2 = M[a-addr], x1 = M[a-addr+2].
;   Per ANS Forth 1994 §3.1.4.1 + §6.1.0350: high-on-TOS / high-at-low-
;   address. Story 13.0.1 — previously the labelling was inverted
;   (low-on-TOS / low-at-low-address); the assembly code is unchanged
;   because the pair-load is layout-symmetric — only the conceptual
;   labels of M[a-addr] and second-on-stack flipped.
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
        LD      A, (HL)         ; A = low byte of x1 (the LOW cell)
        INC     HL
        LD      H, (HL)         ; H = high byte of x1 (HL scratch after this)
        LD      L, A            ; HL = x1 (LOW cell, second-on-stack)
        PUSH    HL              ; Push x1 (LOW cell, second on stack)
        LD      H, B
        LD      L, C            ; HL = a-addr (BC was preserved)
        LD      C, (HL)
        INC     HL
        LD      B, (HL)         ; BC = x2 (HIGH cell, new TOS per §3.1.4.1)
        NEXT

; -----------------------------------------------
; 2! ( x1 x2 a-addr -- )
;   Store double-cell at a-addr: x2 (HIGH cell, was on TOS) at a-addr;
;   x1 (LOW cell, was second-on-stack) at a-addr+2. Per §3.1.4.1 +
;   §6.1.0310: high cell at lower address. Story 13.0.1 — same
;   assembly code as pre-flip; only the cell labels swapped.
; ANS Forth 1994 §6.1.0310   2!   — double-cell store
; -----------------------------------------------
w_TWO_STORE:
        DEFCODE "2!", 0
w_TWO_STORE_cf:
        CALL    check_underflow_3
        LD      H, B
        LD      L, C            ; HL = a-addr
        POP     BC              ; BC = x2 (HIGH cell, was TOS-of-pair)
        LD      (HL), C
        INC     HL
        LD      (HL), B         ; M[a-addr], M[a-addr+1] = x2 (HIGH)
        INC     HL              ; HL = a-addr + 2
        POP     BC              ; BC = x1 (LOW cell, was second)
        LD      (HL), C
        INC     HL
        LD      (HL), B         ; M[a-addr+2], M[a-addr+3] = x1 (LOW)
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
;   Sign-extend single to double. Per §3.1.4.1 the HIGH cell is on TOS:
;   push n (low cell) as second-on-stack, then set BC = sign-extended
;   high cell (0 if n >= 0, $FFFF if n < 0).
; ANS Forth 1994 §6.1.2170   S>D   — sign-extend single to double
; -----------------------------------------------
w_S_TO_D:
        DEFCODE "S>D", 0
w_S_TO_D_cf:
        CALL    check_underflow
        LD      A, B            ; A = high byte of n (sign bit in bit 7)
        PUSH    BC              ; Push n (LOW cell) as second-on-stack
        RLA                     ; Carry = sign bit of n
        SBC     A, A            ; A = 0 if n >= 0, $FF if n < 0
        LD      B, A
        LD      C, A            ; BC = 0 or $FFFF (sign-extended HIGH cell, new TOS)
        NEXT

; -----------------------------------------------
; D>S ( d -- n )
;   Narrow double to single by dropping the high cell. Post-Story-13.0.1
;   per §3.1.4.1: BC holds the HIGH cell on entry; pop the LOW cell
;   from second-on-stack into BC, discarding the high cell (it was the
;   incoming BC, overwritten). Truncation is ANS implementation-defined.
; ANS Forth 1994 §8.6.1140   D>S   — narrow double to single (truncating)
; -----------------------------------------------
w_D_TO_S:
        DEFCODE "D>S", 0
w_D_TO_S_cf:
        CALL    check_underflow_2
        POP     BC              ; BC = LOW cell (new TOS); HIGH cell discarded
        NEXT

; -----------------------------------------------
; M+ ( d1 n -- d2 )
;   Mixed single+double add. n (BC, TOS) is sign-extended to 32 bits
;   then added to d1; per §3.1.4.1 the HIGH cell of d2 ends on TOS.
;   Entry stack: ( lo(d1) hi(d1) n ); BC=n. SP-top=hi(d1), SP-2nd=lo(d1).
;   CF from the low-cell add is preserved across sign-extend via PUSH AF.
; ANS Forth 1994 §8.6.1830   M+   — mixed single+double add (sign-extended)
; -----------------------------------------------
w_M_PLUS:
        DEFCODE "M+", 0
w_M_PLUS_cf:
        CALL    check_underflow_3
        POP     HL              ; HL = hi(d1); SP-top now = lo(d1)
        EX      (SP), HL        ; HL = lo(d1); SP-top = hi(d1) (stashed)
        ADD     HL, BC          ; HL = lo(d1) + n = new lo; CF = carry
        PUSH    AF              ; Save CF across sign-extend
        LD      A, B            ; A = high byte of n (sign in bit 7)
        RLA                     ; CF = sign bit of n
        SBC     A, A            ; A = 0 if n >= 0, $FF if n < 0
        LD      B, A
        LD      C, A            ; BC = sign-extended high half of n
        POP     AF              ; Restore CF = carry from low-cell add
        EX      (SP), HL        ; HL = hi(d1); SP-top = new lo (stashed)
        ADC     HL, BC          ; HL = hi(d1) + sign_ext(n) + carry = new hi
        LD      B, H
        LD      C, L            ; BC = new hi (TOS per §3.1.4.1)
        NEXT

; -----------------------------------------------
; D+ ( d1 d2 -- d3 )
;   Double-cell add: d3 = d1 + d2 with 32-bit carry propagation.
;   Per §3.1.4.1: stack ( lo1 hi1 lo2 hi2 ) with hi2 = BC = TOS;
;   output ( lo3 hi3 ) with hi3 = BC. The lo-cell add must precede
;   the hi-cell add so CF propagates correctly. IP (DE) is stashed
;   so DE is available as scratch. PUSH preserves flags so CF
;   survives the intermediate stack moves.
; ANS Forth 1994 §8.6.1040   D+   — double-cell add
; -----------------------------------------------
w_D_PLUS:
        DEFCODE "D+", 0
w_D_PLUS_cf:
        CALL    check_underflow_4
        LD      (double_ip_stash), DE
        POP     DE              ; DE = lo2; SP-top = hi1
        POP     HL              ; HL = hi1; SP-top = lo1
        EX      (SP), HL        ; HL = lo1; SP-top = hi1 (stashed)
        ADD     HL, DE          ; HL = lo1 + lo2 = new lo; CF = carry
        POP     DE              ; DE = hi1; CF preserved
        PUSH    HL              ; Push new lo as second-on-stack; CF preserved
        LD      H, D
        LD      L, E            ; HL = hi1
        ADC     HL, BC          ; HL = hi1 + hi2 + carry = new hi
        LD      B, H
        LD      C, L            ; BC = new hi (TOS per §3.1.4.1)
        LD      DE, (double_ip_stash)
        NEXT

; -----------------------------------------------
; D- ( d1 d2 -- d3 )
;   Double-cell subtract: d3 = d1 - d2 with 32-bit borrow propagation.
;   Per §3.1.4.1: stack ( lo1 hi1 lo2 hi2 ) with hi2 = BC = TOS;
;   output ( lo3 hi3 ) with hi3 = BC. The lo-cell subtract must
;   precede the hi-cell subtract so borrow propagates correctly.
; ANS Forth 1994 §8.6.1050   D-   — double-cell subtract
; -----------------------------------------------
w_D_MINUS:
        DEFCODE "D-", 0
w_D_MINUS_cf:
        CALL    check_underflow_4
        LD      (double_ip_stash), DE
        POP     DE              ; DE = lo2; SP-top = hi1
        POP     HL              ; HL = hi1; SP-top = lo1
        EX      (SP), HL        ; HL = lo1; SP-top = hi1 (stashed)
        OR      A               ; Clear CF
        SBC     HL, DE          ; HL = lo1 - lo2 = new lo; CF = borrow
        POP     DE              ; DE = hi1; CF preserved
        PUSH    HL              ; Push new lo as second-on-stack; CF preserved
        LD      H, D
        LD      L, E            ; HL = hi1
        SBC     HL, BC          ; HL = hi1 - hi2 - borrow = new hi
        LD      B, H
        LD      C, L            ; BC = new hi (TOS per §3.1.4.1)
        LD      DE, (double_ip_stash)
        NEXT

; -----------------------------------------------
; (DLIT) ( -- d.lo-2nd d.hi-tos )
;   Runtime for a compiled double-cell literal. Reads 4 inline bytes
;   from the thread following its own code-field: HIGH cell first
;   (at IP+0..1, since high-at-low-address per §6.1.0350), then LOW
;   cell (at IP+2..3). Pushes the pair so the HIGH cell is on TOS
;   (per ANS Forth 1994 §3.1.4.1) and the LOW cell is second-on-stack
;   — matching D+ / 2@ / D. consumption order. Advances IP by 4 bytes.
;   Inline layout in compiled code: [w_D_LIT_cf addr][d.hi lo,hi][d.lo lo,hi]
;   so a 2! of the same value at (HERE+2) round-trips byte-for-byte.
;   The Z80 assembly code is unchanged from pre-Story-13.0.1 — only
;   the cell-label interpretation flipped (BC reads from IP+0..1 which
;   is now the HIGH cell, DE reads from IP+2..3 which is now the LOW
;   cell). Same opcodes; conventionally re-labelled.
; ANS Forth 1994 §3.4.1.3 — runtime for compile-state double-literal emitted
;   by NUMBER-PREFIX? / NUMBER? when a dot-bearing digit string is parsed.
; Story 13.0 — paren-convention internal helper (architecture.md:438).
; Story 13.0.1 — flipped to high-on-TOS / high-at-low-address per §3.1.4.1.
; -----------------------------------------------
w_D_LIT:
        DEFCODE "(DLIT)", 0
w_D_LIT_cf:
        ; Story 11.5.2 -3 THROW guard. Depth grows by 2 cells (high + low);
        ; the 32-byte safety margin in check_overflow covers both cells.
        CALL    check_overflow
        PUSH    BC                      ; spill old TOS (3rd-on-stack)
        EX      DE, HL                  ; HL = IP (→ HIGH cell)
        LD      C, (HL)
        INC     HL
        LD      B, (HL)                 ; BC = d.hi (new TOS per §3.1.4.1)
        INC     HL                      ; HL → LOW cell
        LD      E, (HL)
        INC     HL
        LD      D, (HL)                 ; DE = d.lo
        INC     HL                      ; HL = new IP (past 4 inline bytes)
        PUSH    DE                      ; push d.lo as second-on-stack
        NEXTHL                          ; HL is already new IP — skip the EX

; -----------------------------------------------
; DNEGATE ( d -- -d )
;   Double-cell two's-complement negation: -d = 0 - d. Per §3.1.4.1
;   BC = high cell on entry; SP-top = low cell. Subtract low first
;   (CF = borrow), then high (with borrow). Output BC = -hi (TOS),
;   SP-top = -lo. The unique $80000000 fixed-point case negates to
;   itself (ANS-conformant; mirrors single-cell NEGATE of $8000).
; ANS Forth 1994 §8.6.1230   DNEGATE   — double-cell two's-complement negate
; -----------------------------------------------
w_D_NEGATE:
        DEFCODE "DNEGATE", 0
w_D_NEGATE_cf:
        CALL    check_underflow_2
        LD      (double_ip_stash), DE
        POP     DE              ; DE = low cell
        OR      A               ; Clear CF
        LD      HL, 0
        SBC     HL, DE          ; HL = 0 - low = -low; CF = borrow
        PUSH    HL              ; Push new low (second-on-stack); CF preserved
        LD      HL, 0
        SBC     HL, BC          ; HL = 0 - high - borrow = new high
        LD      B, H
        LD      C, L            ; BC = new high (TOS per §3.1.4.1)
        LD      DE, (double_ip_stash)
        NEXT

; -----------------------------------------------
; DABS ( d -- ud )
;   Double-cell absolute value. Per §3.1.4.1 the high cell is on TOS
;   (in BC); its sign bit is bit 7 of B. Fall through for non-negative
;   d; tail-call DNEGATE for negative d. The re-entry into DNEGATE
;   re-checks underflow (cheap, ~30 T-states).
; ANS Forth 1994 §8.6.1160   DABS   — double-cell absolute value
; Story 13.0.1 — sign-bit peek moved from M[SP+1] (old: high cell at
;   SP) to register B.bit7 (new: high cell in BC).
; -----------------------------------------------
w_D_ABS:
        DEFCODE "DABS", 0
w_D_ABS_cf:
        CALL    check_underflow_2
        BIT     7, B            ; Sign bit of high cell (= TOS = BC)
        JR      Z, .dabs_done   ; Non-negative: pass through unchanged
        JP      w_D_NEGATE_cf   ; Negative: tail-call DNEGATE
.dabs_done:
        NEXT

; -----------------------------------------------
; D= ( d1 d2 -- flag )
;   True flag iff d1 equals d2 bit-for-bit across both cells. Short-
;   circuits on first-popped-cell mismatch but still drops the deeper
;   cell so the stack net is (4 consumed, 1 pushed). Algorithm is
;   convention-symmetric — just compares both cells; the cell labels
;   (high/low) are irrelevant to equality. Story 13.0.1 — code
;   unchanged from pre-flip; only comment labels updated.
; ANS Forth 1994 §8.6.1120   D=   — double-cell equality → flag
; -----------------------------------------------
w_D_EQUALS:
        DEFCODE "D=", 0
w_D_EQUALS_cf:
        CALL    check_underflow_4
        LD      (double_ip_stash), DE
        POP     DE              ; DE = low cell of d2 (post-flip)
        POP     HL              ; HL = high cell of d1 (post-flip)
        OR      A
        SBC     HL, BC          ; Z iff hi(d1) == hi(d2)
        JR      NZ, .deq_false_pop1
        POP     HL              ; HL = low cell of d1
        OR      A
        SBC     HL, DE          ; Z iff lo(d1) == lo(d2)
        JR      NZ, .deq_false
        LD      BC, -1          ; TRUE
        JR      .deq_done
.deq_false_pop1:
        POP     HL              ; Drop low cell of d1 (high mismatch already decided)
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
;   negative iff (S XOR P/V) = 1. Per §3.1.4.1: BC = hi(d2) on entry;
;   pop lo(d2), hi(d1), lo(d1) from SP. Subtract lo first (CF=borrow),
;   then hi (with borrow); flag from S/V of the high SBC.
; ANS Forth 1994 §8.6.1110   D<   — double-cell signed less-than → flag
; -----------------------------------------------
w_D_LESS:
        DEFCODE "D<", 0
w_D_LESS_cf:
        CALL    check_underflow_4
        LD      (double_ip_stash), DE
        POP     DE              ; DE = lo(d2); SP-top = hi(d1)
        POP     HL              ; HL = hi(d1); SP-top = lo(d1)
        EX      (SP), HL        ; HL = lo(d1); SP-top = hi(d1) (stashed)
        OR      A               ; Clear CF
        SBC     HL, DE          ; HL = lo(d1) - lo(d2); CF = borrow
        POP     DE              ; DE = hi(d1); CF preserved
        LD      H, D
        LD      L, E            ; HL = hi(d1)
        SBC     HL, BC          ; HL = hi(d1) - hi(d2) - borrow; S, P/V set
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
;   Unsigned mixed multiply: 16-bit u1 × 16-bit u2 → 32-bit ud. Per
;   §3.1.4.1 the HIGH cell of ud is on TOS. Right-shift schoolbook:
;   BC starts holding u2 (multiplier) and drains as bits are consumed
;   from its LSB; HL accumulates the high half. The 32-bit accumulator
;   (HL:BC) is shifted right by 1 each iteration; the carry-out of
;   ADD HL,DE is captured by the subsequent RR H, giving an effective
;   33-bit shift register so the $FFFF × $FFFF = $FFFE0001 corner
;   case settles correctly. Story 13.0.1 — final push/load swapped:
;   push LOW cell (was BC) as second-on-stack, then load BC = HIGH
;   cell (= HL) as the new TOS.
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
        ; HL = product HIGH cell, BC = product LOW cell
        PUSH    BC              ; Push LOW cell as second-on-stack
        LD      B, H
        LD      C, L            ; BC = HIGH cell (TOS per §3.1.4.1)
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
;   where a = HIGH cell, b = LOW cell.
;
;   Story 13.0.1: high-on-TOS convention flipped from low-on-TOS. The
;   pre-13.0.1 body was structured around input ( a1 b1 a2 b2 ) with
;   b2 (low) on TOS. The new convention has input ( b1 a1 b2 a2 ) with
;   a2 (high) on TOS. Rather than rewrite the algebra from scratch we
;   adapt: convert NEW input → OLD-style with "SWAP 2SWAP SWAP 2SWAP",
;   run the OLD body (with one inner SWAP after UM* to flip its NEW
;   output back to OLD-style), then SWAP the final result back to NEW
;   ( res_lo res_hi ) with res_hi on TOS. Cost: +6 cells = +12 bytes.
;   Native rewrite would shave a few bytes but at significant
;   readability/correctness risk; the adapter approach is transparent.
; ANS Forth 1994 §8.6.1090   D*   — double-cell signed multiply (truncating)
; -----------------------------------------------
w_D_STAR:
        DEFWORD "D*", 0
w_D_STAR_body:
w_D_STAR_cf EQU w_D_STAR_body - 3
        ; Convert NEW input ( lo1 hi1 lo2 hi2 ) → OLD-style ( hi1 lo1 hi2 lo2 ).
        DW      w_SWAP_cf               ; ( lo1 hi1 hi2 lo2 )
        DW      w_TWO_SWAP_cf           ; ( hi2 lo2 lo1 hi1 )
        DW      w_SWAP_cf               ; ( hi2 lo2 hi1 lo1 )
        DW      w_TWO_SWAP_cf           ; ( hi1 lo1 hi2 lo2 ) — OLD-style ( a1 b1 a2 b2 )
        ; Pre-Story-13.0.1 body (OLD conv internally):
        DW      w_TWO_OVER_cf           ; Underflow guard (needs >= 4)
        DW      w_TWO_DROP_cf           ; Drop the duplicates from 2OVER
        DW      w_TO_R_cf               ; >R: stash b2
        DW      w_OVER_cf               ; copy b1
        DW      w_R_FETCH_cf            ; R@: copy b2
        DW      w_U_M_STAR_cf           ; UM*(b1,b2) — under NEW outputs ( P_lo P_hi )
        DW      w_SWAP_cf               ; flip UM* NEW output → OLD-style ( P_hi P_lo )
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
        DW      w_SWAP_cf               ; ( res_hi P_lo ) — OLD-style output ( res_hi res_lo )
        ; Convert OLD-style output → NEW ( res_lo res_hi ) with res_hi on TOS.
        DW      w_SWAP_cf               ; ( res_lo res_hi )
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
        ; Story 13.0.1: under §3.1.4.1 hi-on-TOS, the cell layout for ud is
        ; ( ud-lo ud-hi ) with ud-hi at SP-top. Swap the two POPs so DE
        ; receives ud-hi (running remainder) and HL receives ud-lo
        ; (quotient accumulator). Body algorithm unchanged.
        POP     DE                      ; DE = ud-hi (running remainder)
        POP     HL                      ; HL = ud-lo (quotient accumulator)
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
        ; Story 13.0.1: under §3.1.4.1 hi-on-TOS, entry stack is
        ; ( d-lo d-hi n1 ) with d-hi at depth 1 (not depth 2 as under
        ; pre-flip OLD conv). Use 2DUP to copy (d-hi n1) for the
        ; sign-XOR, and OVER to copy d-hi for the rem-sign. Saves 10
        ; bytes vs the pre-flip "LIT 2 PICK" pattern.
        DW      w_QGUARD_3_cf           ; Underflow guard (3 cells)
        DW      w_TWO_DUP_cf            ; ( d-lo d-hi n1 d-hi n1 )
        DW      w_XOR_cf                ; ( d-lo d-hi n1 (d-hi^n1) )
        DW      w_ZERO_LESS_cf          ; quotient-sign flag (true if signs differ)
        DW      w_TO_R_cf               ; R: (quot-sign)
        DW      w_OVER_cf               ; ( d-lo d-hi n1 d-hi )
        DW      w_ZERO_LESS_cf          ; remainder-sign flag (true if d < 0)
        DW      w_TO_R_cf               ; R: (quot-sign rem-sign)
        DW      w_ABS_cf                ; |n1|
        DW      w_TO_R_cf               ; R: (quot-sign rem-sign |n1|)
        DW      w_D_ABS_cf              ; |d|
        DW      w_R_FROM_cf             ; recover |n1|: ( |d-lo| |d-hi| |n1| )
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
