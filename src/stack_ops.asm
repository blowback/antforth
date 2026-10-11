; stack_ops.asm — Parameter stack, return stack, and stack pointer primitives
; AntForth — A Forth for CP/M on Z80
;
; Parameter stack: DUP, DROP, SWAP, OVER, NIP, TUCK, ROT, -ROT, PICK, ROLL, DEPTH
; Stack pointers:  SP@, SP!, RP@, RP!
; Return stack:    >R, R>, R@

; -----------------------------------------------
; ?DUP ( x -- 0 | x x )
;   Duplicate TOS only if non-zero
; -----------------------------------------------
w_QDUP:
        DEFCODE "?DUP", 0
w_QDUP_cf:
        CALL    check_underflow
        LD      A, B
        OR      C               ; Test if BC is zero
        JR      Z, .qdup_zero
        PUSH    BC              ; Non-zero: duplicate
.qdup_zero:
        NEXT

; -----------------------------------------------
; DUP ( x -- x x )
;   Duplicate top of stack
; -----------------------------------------------
w_DUP:
        DEFCODE "DUP", 0
w_DUP_cf:
        CALL    check_underflow
        PUSH    BC              ; Push TOS copy to parameter stack
        NEXT                    ; BC (TOS) unchanged

; -----------------------------------------------
; DROP ( x -- )
;   Remove top of stack
; -----------------------------------------------
w_DROP:
        DEFCODE "DROP", 0
w_DROP_cf:
        CALL    check_underflow
        POP     BC              ; Load new TOS from parameter stack
        NEXT

; -----------------------------------------------
; SWAP ( x1 x2 -- x2 x1 )
;   Exchange top two stack items
; -----------------------------------------------
w_SWAP:
        DEFCODE "SWAP", 0
w_SWAP_cf:
        CALL    check_underflow_2
        POP     HL              ; HL = x1 (second on stack)
        PUSH    BC              ; Push x2 (old TOS) to stack
        LD      B, H
        LD      C, L            ; BC = x1 (new TOS)
        NEXT

; -----------------------------------------------
; OVER ( x1 x2 -- x1 x2 x1 )
;   Copy second item to top
; -----------------------------------------------
w_OVER:
        DEFCODE "OVER", 0
w_OVER_cf:
        CALL    check_underflow_2
        POP     HL              ; HL = x1
        PUSH    HL              ; Restore x1 on stack
        PUSH    BC              ; Push x2 (old TOS)
        LD      B, H
        LD      C, L            ; BC = x1 (new TOS)
        NEXT

; -----------------------------------------------
; NIP ( x1 x2 -- x2 )
;   Drop the second item
; ANS Forth 1994 §6.2.1930   NIP   (Core Extension)
; -----------------------------------------------
w_NIP:
        DEFCODE "NIP", 0
w_NIP_cf:
        CALL    check_underflow_2
        POP     HL              ; Discard x1; BC = x2 already
        NEXT

; -----------------------------------------------
; TUCK ( x1 x2 -- x2 x1 x2 )
;   Copy the top item below the second
; ANS Forth 1994 §6.2.2300   TUCK   (Core Extension)
; -----------------------------------------------
w_TUCK:
        DEFCODE "TUCK", 0
w_TUCK_cf:
        CALL    check_underflow_2
        POP     HL              ; HL = x1
        PUSH    BC              ; x2
        PUSH    HL              ; x1
        NEXT                    ; BC = x2 unchanged

; -----------------------------------------------
; ROT ( x1 x2 x3 -- x2 x3 x1 )
;   Rotate third item to top
; -----------------------------------------------
w_ROT:
        DEFCODE "ROT", 0
w_ROT_cf:
        CALL    check_underflow_3
        ; BC = x3 (TOS), (SP) = x2, (SP+2) = x1
        POP     HL              ; HL = x2
        EX      (SP), HL        ; HL = x1, (SP) = x2
        PUSH    BC              ; Push x3
        LD      B, H
        LD      C, L            ; BC = x1 (new TOS)
        NEXT

; -----------------------------------------------
; -ROT ( x1 x2 x3 -- x3 x1 x2 )   ; antforth extension
;   Rotate the top item to third; the inverse of ROT
; -----------------------------------------------
w_MINUS_ROT:
        DEFCODE "-ROT", 0
w_MINUS_ROT_cf:
        CALL    check_underflow_3
        LD      H, B
        LD      L, C            ; HL = x3
        POP     BC              ; BC = x2 (new TOS), (SP) = x1
        EX      (SP), HL        ; HL = x1, deep slot = x3
        PUSH    HL              ; x1 above x3
        NEXT

; -----------------------------------------------
; PICK ( xu ... x1 x0 u -- xu ... x1 x0 xu )
;   Copy the u-th stack item to top (0 PICK = DUP)
;   u is consumed; xu replaces it as new TOS
; -----------------------------------------------
w_PICK:
        DEFCODE "PICK", 0
w_PICK_cf:
        CALL    check_underflow_u
        ; BC = u. (SP+0) = x0, (SP+2) = x1, ..., (SP+u*2) = xu
        LD      H, B
        LD      L, C            ; HL = u
        ADD     HL, HL          ; HL = u * 2
        ADD     HL, SP          ; HL = SP + u*2 = address of xu
        LD      C, (HL)
        INC     HL
        LD      B, (HL)         ; BC = xu (replaces u as TOS)
        NEXT

; -----------------------------------------------
; ROLL ( xu xu-1 ... x0 u -- xu-1 ... x0 xu )
;   Rotate the u-th stack item to top (1 ROLL = SWAP, 2 ROLL = ROT)
;   Removes xu from its position and places it in TOS
; -----------------------------------------------
w_ROLL:
        DEFCODE "ROLL", 0
w_ROLL_cf:
        CALL    check_underflow_u
        ; Algorithm: save xu, shift x0..xu-1 up one cell via LDDR, put xu in TOS.
        ; Uses return stack to save IP since LDDR needs DE.
        ;
        ; BC = u. 0 ROLL = no-op (consume u, x0 becomes TOS)
        LD      A, B
        OR      C
        JR      NZ, .roll_work
        POP     BC              ; u=0: just load x0 as new TOS
        NEXT
.roll_work:
        ; Preserve u across the EXX (main BC is junk after EXX)
        PUSH    BC              ; save u on param stack
        EXX                     ; save TOS/IP/W to shadows
        POP     HL              ; HL = u in main set

        ; Compute address of xu on stack: SP + u*2
        ADD     HL, HL          ; HL = u*2
        PUSH    HL              ; Save u*2 for LDDR byte count
        ADD     HL, SP          ; HL = SP_after_push + u*2 = SP_orig - 2 + u*2
        INC     HL
        INC     HL              ; HL = SP_orig + u*2 = &xu

        ; Read xu into DE and save it
        LD      E, (HL)
        INC     HL
        LD      D, (HL)         ; DE = xu
        ; Recover u*2 into BC (from earlier PUSH), then save xu
        POP     BC              ; BC = u*2
        PUSH    DE              ; Save xu. Stack: [xu] x0 x1 ... xu

        ; LDDR setup: shift x0..xu-1 up by one cell (2 bytes)
        ; Source end = last byte of xu-1 = SP + 2 + (u*2 - 1) = SP + u*2 + 1
        ; Dest end   = source end + 2
        ; Count      = u*2 bytes (in BC, already set)
        LD      HL, 0
        ADD     HL, SP          ; HL = SP (xu is at SP+0)
        ADD     HL, BC          ; HL = SP + u*2
        INC     HL              ; HL = SP + u*2 + 1 = source end
        LD      D, H
        LD      E, L
        INC     DE
        INC     DE              ; DE = source end + 2 = dest end

        LDDR                    ; Shift block up: x0..xu-1 each move +2 bytes

        ; Retrieve xu from stack, set as new TOS
        POP     BC              ; BC = xu (new TOS)

        ; Remove the duplicate slot left at bottom of shifted region
        INC     SP
        INC     SP

        ; Stage new TOS through the param stack across the exit EXX
        PUSH    BC              ; save new TOS
        EXX                     ; restore IP from shadow (main BC clobbered)
        POP     BC              ; recover new TOS

        NEXT

; -----------------------------------------------
; DEPTH ( -- n )
;   Return the number of items on the stack (before DEPTH executes)
; -----------------------------------------------
w_DEPTH:
        DEFCODE "DEPTH", 0
w_DEPTH_cf:
        ; Compute depth BEFORE push — depth = (S0 - SP) / 2
        ; Counts cells on SP only; TOS in BC is not counted.
        ; Empty stack: SP == sp_base → depth = 0
        LD      HL, (sp_base)   ; HL = S0
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = S0 - SP (bytes on stack)
        SRL     H
        RR      L               ; HL = cells on stack
        PUSH    BC              ; Save old TOS
        LD      B, H
        LD      C, L            ; BC = depth (new TOS)
        NEXT

; -----------------------------------------------
; SP@ ( -- addr )
;   Push current stack pointer address
; -----------------------------------------------
w_SP_FETCH:
        DEFCODE "SP@", 0
w_SP_FETCH_cf:
        PUSH    BC
        LD      HL, 0
        ADD     HL, SP          ; HL = SP (Z80 has no LD HL,SP)
        LD      B, H
        LD      C, L
        NEXT

; -----------------------------------------------
; SP! ( addr -- )
;   Set the stack pointer
; -----------------------------------------------
w_SP_STORE:
        DEFCODE "SP!", 0
w_SP_STORE_cf:
        CALL    check_underflow
        LD      H, B
        LD      L, C
        LD      SP, HL
        POP     BC              ; New TOS from new stack
        NEXT

; -----------------------------------------------
; RP@ ( -- addr )
;   Push return stack pointer address
; -----------------------------------------------
w_RP_FETCH:
        DEFCODE "RP@", 0
w_RP_FETCH_cf:
        PUSH    BC
        PUSH    IX
        POP     BC              ; BC = IX (return stack pointer)
        NEXT

; -----------------------------------------------
; RP! ( addr -- )
;   Set the return stack pointer
; -----------------------------------------------
w_RP_STORE:
        DEFCODE "RP!", 0
w_RP_STORE_cf:
        CALL    check_underflow
        PUSH    BC
        POP     IX              ; IX = addr
        POP     BC              ; New TOS
        NEXT

; -----------------------------------------------
; >R ( x -- ) ( R: -- x )
;   Move top of parameter stack to return stack
; -----------------------------------------------
w_TO_R:
        DEFCODE ">R", 0
w_TO_R_cf:
        CALL    check_underflow
        DEC     IX
        DEC     IX
        LD      (IX+1), B       ; Store high byte
        LD      (IX+0), C       ; Store low byte
        POP     BC              ; New TOS from parameter stack
        NEXT

; -----------------------------------------------
; R> ( -- x ) ( R: x -- )
;   Move top of return stack to parameter stack
; -----------------------------------------------
w_R_FROM:
        DEFCODE "R>", 0
w_R_FROM_cf:
        PUSH    BC              ; Save current TOS
        LD      C, (IX+0)
        LD      B, (IX+1)       ; BC = top of return stack
        INC     IX
        INC     IX
        NEXT

; -----------------------------------------------
; R@ ( -- x ) ( R: x -- x )
;   Copy top of return stack to parameter stack (non-destructive)
; -----------------------------------------------
w_R_FETCH:
        DEFCODE "R@", 0
w_R_FETCH_cf:
        PUSH    BC              ; Save current TOS
        LD      C, (IX+0)
        LD      B, (IX+1)       ; BC = top of return stack (copied, not removed)
        NEXT
