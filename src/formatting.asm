; formatting.asm — Number formatting and stack inspection words
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; digit_to_char — Internal helper
;   Convert digit value (0-35) to ASCII character
;   Input:  A = digit value
;   Output: A = ASCII character ('0'-'9' or 'A'-'Z')
;   Clobbers: F
; -----------------------------------------------
digit_to_char:
        CP      10
        JR      C, .dtc_decimal
        ADD     A, 'A' - 10
        RET
.dtc_decimal:
        ADD     A, '0'
        RET

; -----------------------------------------------
; div_bc_by_e — Internal helper
;   Divide BC (16-bit) by E (8-bit base)
;   Input:  BC = dividend, E = divisor
;   Output: BC = quotient, A = remainder
;   Clobbers: AF, D (caller must save DE/IP beforehand)
; -----------------------------------------------
div_bc_by_e:
        XOR     A               ; Clear remainder (A=0)
        LD      D, 16           ; 16 bits to process
.div_loop:
        SLA     C               ; Shift BC left through carry
        RL      B
        RLA                     ; Shift carry into remainder
        CP      E               ; Compare remainder with divisor
        JR      C, .div_no_sub  ; If remainder < divisor, skip
        SUB     E               ; Subtract divisor from remainder
        INC     C               ; Set bit 0 of quotient
.div_no_sub:
        DEC     D
        JR      NZ, .div_loop
        RET                     ; BC = quotient, A = remainder

; -----------------------------------------------
; u_to_str — Internal subroutine
;   Convert unsigned 16-bit number to ASCII string in num_buf
;   Input:  BC = unsigned number to convert
;           BASE read from (IY+UserArea.base)
;   Output: HL = address of first digit character in num_buf
;           A  = character count (string length)
;   Clobbers: AF, BC (consumed), HL
;   Preserves: IX, IY, SP
;   NOTE: Caller must preserve DE (IP) across the call — either via rpush_de
;         or by parking IP in DE' with EXX — since div_bc_by_e clobbers D.
; -----------------------------------------------
u_to_str:
        LD      HL, num_buf + NUM_BUF_SIZE - 1  ; Point to end of buffer
        XOR     A
        LD      (.uts_count), A                  ; digit count = 0
        LD      E, (IY+UserArea.base)            ; E = BASE (8-bit, always <= 36)
.uts_loop:
        CALL    div_bc_by_e             ; BC = quotient, A = remainder
        CALL    digit_to_char           ; A = ASCII digit
        LD      (HL), A                 ; Store digit
        ; Increment count
        PUSH    AF
        LD      A, (.uts_count)
        INC     A
        LD      (.uts_count), A
        POP     AF
        ; Check if quotient is zero
        LD      A, B
        OR      C
        JR      Z, .uts_done
        DEC     HL                      ; Move to next position (right-to-left)
        JR      .uts_loop
.uts_done:
        ; HL already points to first digit (we didn't decrement after last store)
        LD      A, (.uts_count)         ; A = character count
        RET

.uts_count:     DB      0               ; Scratch for digit count

; -----------------------------------------------
; print_neg_prefix — Internal helper
;   If BC is negative, emit '-' and negate BC.
;   If BC is non-negative, do nothing.
;   Input:  BC = signed number
;   Output: BC = |BC| (absolute value)
;   Clobbers: AF, DE, HL (HL via BDOS)
;   Preserves: IX, IY
; -----------------------------------------------
print_neg_prefix:
        BIT     7, B
        RET     Z               ; Non-negative: return immediately
        ; Negative: emit '-'
        PUSH    BC              ; Save number
        LD      E, '-'
        CALL    bdos_putchar
        POP     BC              ; Restore number
        ; Negate BC: BC = 0 - BC
        XOR     A
        SUB     C
        LD      C, A
        SBC     A, A
        SUB     B
        LD      B, A
        RET

; -----------------------------------------------
; emit_unsigned — Internal helper
;   Emit unsigned number from BC followed by trailing space
;   Caller must preserve DE (IP) across the call — either via rpush_de
;   or by parking IP in DE' with EXX — since u_to_str clobbers D.
;   Input:  BC = unsigned number
;   Output: nothing (number + space emitted)
;   Clobbers: AF, BC, DE, HL
; -----------------------------------------------
emit_unsigned:
        CALL    u_to_str                ; HL = string addr, A = length
        ; Emit digits
        LD      B, A                    ; B = count
.eu_emit:
        CALL    bdos_print_str
        ; Emit trailing space
        LD      E, ' '
        JP      bdos_putchar

; -----------------------------------------------
; . (dot) ( n -- )
;   Print signed number followed by space using current BASE
; -----------------------------------------------
w_DOT:
        DEFCODE ".", 0
w_DOT_cf:
        CALL    check_underflow
        ; Park IP in DE' via shadow registers; TOS stays in main BC for helpers
        PUSH    BC
        EXX
        POP     BC
        ; Handle sign: emit '-' and negate if negative
        CALL    print_neg_prefix
        CALL    emit_unsigned
        ; Restore IP from DE' (main BC holds garbage — overwritten by POP BC below)
        EXX
        ; Pop new TOS from parameter stack
        POP     BC
        NEXT

; -----------------------------------------------
; U. ( u -- )
;   Print unsigned number followed by space using current BASE
; -----------------------------------------------
w_U_DOT:
        DEFCODE "U.", 0
w_U_DOT_cf:
        CALL    check_underflow
        ; Park IP in DE' via shadow registers; TOS stays in main BC for emit_unsigned
        PUSH    BC
        EXX
        POP     BC
        CALL    emit_unsigned
        ; Restore IP from DE' (main BC holds garbage — overwritten by POP BC below)
        EXX
        ; Pop new TOS from parameter stack
        POP     BC
        NEXT

; -----------------------------------------------
; .R ( n width -- )
;   Print signed number right-justified in field of given width
;   No trailing space
; -----------------------------------------------
w_DOT_R:
        DEFCODE ".R", 0
w_DOT_R_cf:
        CALL    check_underflow_2
        ; Park IP in DE' via shadow registers; rearrange main set so
        ; main DE = width and main BC = n (consumed for u_to_str).
        PUSH    BC                      ; width onto SP
        EXX                             ; IP → DE'
        POP     DE                      ; main DE = width
        POP     BC                      ; main BC = n

        ; Check sign of n
        BIT     7, B
        JR      Z, .dotr_positive
        ; Negative: set flag and negate
        LD      A, 1
        LD      (.dotr_neg), A
        XOR     A
        SUB     C
        LD      C, A
        SBC     A, A
        SUB     B
        LD      B, A
        JR      .dotr_convert
.dotr_positive:
        XOR     A
        LD      (.dotr_neg), A
.dotr_convert:
        ; BC = |n|, DE = width — preserve width across u_to_str (clobbers DE)
        PUSH    DE                      ; save width
        CALL    u_to_str                ; HL = string addr, A = length
        ; Save string info (lives across pad-loop BDOS calls — see Dev Notes)
        LD      (.dotr_str), HL
        LD      (.dotr_len), A
        POP     DE                      ; restore DE = width

        ; Calculate padding = width_lo - string_length - sign_char
        LD      B, A                    ; B = string length
        LD      A, (.dotr_neg)
        ADD     A, B                    ; A = string_length + sign_char
        LD      B, A
        LD      A, E                    ; A = width (low byte)
        ; NOTE: only the low 8 bits of width are used for padding (pre-existing
        ; behaviour); widths >= 256 fall through to .dotr_no_pad via wrap.
        SUB     B                       ; A = padding count
        ; If padding <= 0, skip
        JR      C, .dotr_no_pad
        JR      Z, .dotr_no_pad
        ; Emit padding spaces
        LD      B, A                    ; B = padding count
.dotr_pad:
        PUSH    BC
        LD      E, ' '
        CALL    bdos_putchar
        POP     BC
        DJNZ    .dotr_pad
.dotr_no_pad:
        ; Emit '-' if negative
        LD      A, (.dotr_neg)
        OR      A
        JR      Z, .dotr_emit_digits
        LD      E, '-'
        CALL    bdos_putchar
.dotr_emit_digits:
        ; Emit digit string
        LD      HL, (.dotr_str)
        LD      A, (.dotr_len)
        LD      B, A
        CALL    bdos_print_str

        ; Restore IP from DE' (main BC overwritten by POP BC below)
        EXX
        ; Pop new TOS
        POP     BC
        NEXT

.dotr_neg:      DB      0
.dotr_str:      DW      0
.dotr_len:      DB      0

; -----------------------------------------------
; .S ( -- )
;   Display stack contents non-destructively
;   Format: <depth> item1 item2 ... itemN
;   Depth = (S0 - SP) / 2 — counts cells on SP, not TOS in BC
;   Empty stack: SP == sp_base → <0>
;   Items on SP include a guard cell at sp_base-2 (old TOS from
;   first push), which is skipped — user items start at sp_base-4
; -----------------------------------------------
w_DOT_S:
        DEFCODE ".S", 0
w_DOT_S_cf:
        ; Park TOS in BC' and IP in DE' via shadow registers; main BC/DE/HL
        ; are free scratch. Shadow holds TOS+IP for the duration of the word
        ; (briefly swapped in .dots_print_tos to recover TOS into main BC).
        EXX

        ; Calculate depth = (S0 - SP) / 2 — SP unchanged by EXX
        LD      HL, (sp_base)
        OR      A
        SBC     HL, SP          ; HL = bytes on SP
        SRL     H
        RR      L               ; HL = depth (cells on SP)
        LD      (.dots_depth), HL

        ; Print '<'
        LD      E, '<'
        CALL    bdos_putchar

        ; Print depth as unsigned number
        LD      BC, (.dots_depth)
        CALL    u_to_str                ; HL = str, A = len
        LD      B, A
        CALL    bdos_print_str

        ; Print '> '
        LD      E, '>'
        CALL    bdos_putchar
        LD      E, ' '
        CALL    bdos_putchar

        ; Check if depth == 0
        LD      HL, (.dots_depth)
        LD      A, H
        OR      L
        JR      Z, .dots_done

        ; depth >= 1: print (depth-1) items from SP, then TOS from saved BC
        ; User items on SP start at sp_base - 4 (skip guard cell at sp_base - 2)
        ; Walk from bottom (sp_base - 4) toward top (lower addresses)
        LD      HL, (.dots_depth)
        DEC     HL              ; depth - 1 = SP items to print (exclude guard)
        LD      (.dots_remaining), HL

        LD      HL, (sp_base)
        DEC     HL
        DEC     HL
        DEC     HL
        DEC     HL              ; HL = sp_base - 4 (first user item)
        LD      (.dots_addr), HL

.dots_walk:
        LD      HL, (.dots_remaining)
        LD      A, H
        OR      L
        JR      Z, .dots_print_tos

        ; Load item from (.dots_addr)
        LD      HL, (.dots_addr)
        LD      C, (HL)
        INC     HL
        LD      B, (HL)         ; BC = stack item

        ; Print this item signed with trailing space
        CALL    .dots_print_signed

        ; Move toward top of stack (lower addresses)
        LD      HL, (.dots_addr)
        DEC     HL
        DEC     HL
        LD      (.dots_addr), HL

        ; Decrement remaining
        LD      HL, (.dots_remaining)
        DEC     HL
        LD      (.dots_remaining), HL
        JR      .dots_walk

.dots_print_tos:
        ; Recover original TOS from BC' into main BC via SP stash.
        ; (No direct BC'→BC opcode; round-trip through SP keeps shadows intact.)
        EXX                     ; main = entry set: BC=TOS, DE=IP
        PUSH    BC              ; original TOS to SP
        EXX                     ; back to body set; BC'/DE' still hold TOS/IP
        POP     BC              ; main BC = original TOS
        CALL    .dots_print_signed  ; clobbers BC/DE/HL (body set, OK)

.dots_done:
        ; Restore TOS into main BC and IP into main DE
        EXX
        NEXT

; .dots_print_signed — print BC as signed number with trailing space
; Clobbers: AF, BC, DE, HL
.dots_print_signed:
        CALL    print_neg_prefix
        JP      emit_unsigned

.dots_depth:      DW      0
.dots_addr:       DW      0
.dots_remaining:  DW      0

; -----------------------------------------------
; HEX ( -- )
;   Set BASE to 16
; -----------------------------------------------
w_HEX:
        DEFWORD "HEX", 0
w_HEX_body:
w_HEX_cf       EQU     w_HEX_body - 3
        DW      w_LIT_cf, 16
        DW      w_BASE_cf
        DW      w_STORE_cf
        DW      EXIT_CODE

; -----------------------------------------------
; DECIMAL ( -- )
;   Set BASE to 10
; -----------------------------------------------
w_DECIMAL:
        DEFWORD "DECIMAL", 0
w_DECIMAL_body:
w_DECIMAL_cf    EQU     w_DECIMAL_body - 3
        DW      w_LIT_cf, 10
        DW      w_BASE_cf
        DW      w_STORE_cf
        DW      EXIT_CODE
