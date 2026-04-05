; logic.asm — Logic and comparison primitives
; AntForth — A Forth for CP/M on Z80
;
; Logic: AND, OR, XOR, INVERT, LSHIFT, RSHIFT
; Comparison: =, <, >, 0=, 0<, U<
;
; Register contract:
;   BC = TOS, DE = IP (preserve!), SP = parameter stack
;   HL, AF = scratch (free within CODE words)
;
; Flag values: TRUE = -1 (0xFFFF), FALSE = 0 (0x0000)

; -----------------------------------------------
; AND ( x1 x2 -- x3 )
;   Bitwise AND
; -----------------------------------------------
w_AND:
    DEFCODE "AND", 0
w_AND_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = x1
    LD      A, H
    AND     B
    LD      B, A
    LD      A, L
    AND     C
    LD      C, A
    NEXT

; -----------------------------------------------
; OR ( x1 x2 -- x3 )
;   Bitwise OR
; -----------------------------------------------
w_OR:
    DEFCODE "OR", 0
w_OR_cf:
    CALL    check_underflow_2
    POP     HL
    LD      A, H
    OR      B
    LD      B, A
    LD      A, L
    OR      C
    LD      C, A
    NEXT

; -----------------------------------------------
; XOR ( x1 x2 -- x3 )
;   Bitwise XOR
; -----------------------------------------------
w_XOR:
    DEFCODE "XOR", 0
w_XOR_cf:
    CALL    check_underflow_2
    POP     HL
    LD      A, H
    XOR     B
    LD      B, A
    LD      A, L
    XOR     C
    LD      C, A
    NEXT

; -----------------------------------------------
; INVERT ( x1 -- x2 )
;   Bitwise complement (one's complement)
; -----------------------------------------------
w_INVERT:
    DEFCODE "INVERT", 0
w_INVERT_cf:
    LD      A, B
    CPL
    LD      B, A
    LD      A, C
    CPL
    LD      C, A
    NEXT

; -----------------------------------------------
; LSHIFT ( x1 u -- x2 )
;   Logical shift left by u bits
; -----------------------------------------------
w_LSHIFT:
    DEFCODE "LSHIFT", 0
w_LSHIFT_cf:
    CALL    check_underflow_2
    LD      A, C            ; A = shift count (low byte, max useful = 16)
    POP     HL              ; HL = x1
    OR      A
    JR      Z, .lshift_done
.lshift_loop:
    ADD     HL, HL          ; Shift HL left by 1
    DEC     A
    JR      NZ, .lshift_loop
.lshift_done:
    LD      B, H
    LD      C, L
    NEXT

; -----------------------------------------------
; RSHIFT ( x1 u -- x2 )
;   Logical shift right by u bits
; -----------------------------------------------
w_RSHIFT:
    DEFCODE "RSHIFT", 0
w_RSHIFT_cf:
    CALL    check_underflow_2
    LD      A, C            ; A = shift count
    POP     HL              ; HL = x1
    OR      A
    JR      Z, .rshift_done
.rshift_loop:
    SRL     H               ; Shift H right, bit 0 -> carry
    RR      L               ; Rotate carry into L bit 7
    DEC     A
    JR      NZ, .rshift_loop
.rshift_done:
    LD      B, H
    LD      C, L
    NEXT

; -----------------------------------------------
; = ( x1 x2 -- flag )
;   TRUE (-1) if x1 equals x2, FALSE (0) otherwise
; -----------------------------------------------
w_EQUALS:
    DEFCODE "=", 0
w_EQUALS_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = x1
    OR      A               ; Clear carry
    SBC     HL, BC          ; HL = x1 - x2
    LD      BC, 0           ; Assume FALSE
    LD      A, H
    OR      L
    JR      NZ, .eq_done    ; Not equal
    DEC     BC              ; BC = 0xFFFF = TRUE
.eq_done:
    NEXT

; -----------------------------------------------
; < ( n1 n2 -- flag )
;   TRUE if n1 < n2 (signed comparison)
;   After SBC: signed less if Sign XOR Overflow = 1
; -----------------------------------------------
w_LESS:
    DEFCODE "<", 0
w_LESS_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = n1
    OR      A
    SBC     HL, BC          ; HL = n1 - n2, sets S and P/V flags
    LD      BC, 0           ; Assume FALSE
    JP      PO, .less_no_ov ; P/V = 0 (no overflow): check sign only
    ; Overflow set (P/V = 1)
    JP      M, .less_done   ; S=1, V=1 -> S XOR V = 0 -> NOT less
    DEC     BC              ; S=0, V=1 -> S XOR V = 1 -> less
    JR      .less_done
.less_no_ov:
    ; No overflow (P/V = 0)
    JP      P, .less_done   ; S=0, V=0 -> NOT less
    DEC     BC              ; S=1, V=0 -> less
.less_done:
    NEXT

; -----------------------------------------------
; > ( n1 n2 -- flag )
;   TRUE if n1 > n2 (signed comparison)
;   Implemented as: n2 < n1 (swap operands)
; -----------------------------------------------
w_GREATER:
    DEFCODE ">", 0
w_GREATER_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = n1
    ; Swap HL and BC via register moves (faster than PUSH/POP)
    LD      A, H
    LD      H, B
    LD      B, A
    LD      A, L
    LD      L, C
    LD      C, A            ; Now HL = n2, BC = n1
    OR      A
    SBC     HL, BC          ; HL = n2 - n1
    LD      BC, 0           ; Assume FALSE
    JP      PO, .gt_no_ov
    JP      M, .gt_done     ; S=1, V=1 -> NOT less
    DEC     BC              ; S=0, V=1 -> less (n2 < n1 -> n1 > n2)
    JR      .gt_done
.gt_no_ov:
    JP      P, .gt_done     ; S=0, V=0 -> NOT less
    DEC     BC              ; S=1, V=0 -> less
.gt_done:
    NEXT

; -----------------------------------------------
; 0= ( x -- flag )
;   TRUE if x is zero
; -----------------------------------------------
w_ZERO_EQUALS:
    DEFCODE "0=", 0
w_ZERO_EQUALS_cf:
    LD      A, B
    OR      C               ; Z flag set if BC = 0
    LD      BC, 0
    JR      NZ, .zeq_done
    DEC     BC              ; BC = TRUE
.zeq_done:
    NEXT

; -----------------------------------------------
; 0< ( n -- flag )
;   TRUE if n is negative (bit 15 set)
; -----------------------------------------------
w_ZERO_LESS:
    DEFCODE "0<", 0
w_ZERO_LESS_cf:
    LD      A, B            ; Save high byte before clobbering BC
    LD      BC, 0           ; Assume FALSE
    RLA                     ; Bit 7 -> carry
    JR      NC, .zlt_done
    DEC     BC              ; BC = TRUE (0xFFFF)
.zlt_done:
    NEXT

; -----------------------------------------------
; U< ( u1 u2 -- flag )
;   TRUE if u1 < u2 (unsigned comparison)
; -----------------------------------------------
w_U_LESS:
    DEFCODE "U<", 0
w_U_LESS_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = u1
    OR      A               ; Clear carry
    SBC     HL, BC          ; HL = u1 - u2
    LD      BC, 0
    JR      NC, .ult_done   ; No borrow: u1 >= u2
    DEC     BC              ; Borrow: u1 < u2, TRUE
.ult_done:
    NEXT
