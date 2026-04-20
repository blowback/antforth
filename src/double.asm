; double.asm — Double-cell (32-bit) stack and memory primitives
; AntForth — A Forth for CP/M on Z80
;
; Epic 10 double-cell primitives:
;   Stack:   2DUP, 2DROP, 2SWAP, 2OVER
;   Memory:  2@, 2!
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
