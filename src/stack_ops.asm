; stack_ops.asm — Parameter stack, return stack, and stack pointer primitives
; AntForth — A Forth for CP/M on Z80
;
; Parameter stack: DUP, DROP, SWAP, OVER, ROT, PICK, ROLL, DEPTH
; Stack pointers:  SP@, SP!, RP@, RP!
; Return stack:    >R, R>, R@

; -----------------------------------------------
; DUP ( x -- x x )
;   Duplicate top of stack
; -----------------------------------------------
w_DUP:
        DEFCODE "DUP", 0
w_DUP_cf:
        PUSH    BC              ; Push TOS copy to parameter stack
        NEXT                    ; BC (TOS) unchanged

; -----------------------------------------------
; DROP ( x -- )
;   Remove top of stack
; -----------------------------------------------
w_DROP:
        DEFCODE "DROP", 0
w_DROP_cf:
        POP     BC              ; Load new TOS from parameter stack
        NEXT

; -----------------------------------------------
; SWAP ( x1 x2 -- x2 x1 )
;   Exchange top two stack items
; -----------------------------------------------
w_SWAP:
        DEFCODE "SWAP", 0
w_SWAP_cf:
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
        POP     HL              ; HL = x1
        PUSH    HL              ; Restore x1 on stack
        PUSH    BC              ; Push x2 (old TOS)
        LD      B, H
        LD      C, L            ; BC = x1 (new TOS)
        NEXT

; -----------------------------------------------
; ROT ( x1 x2 x3 -- x2 x3 x1 )
;   Rotate third item to top
; -----------------------------------------------
w_ROT:
        DEFCODE "ROT", 0
w_ROT_cf:
        ; BC = x3 (TOS), (SP) = x2, (SP+2) = x1
        POP     HL              ; HL = x2
        EX      (SP), HL        ; HL = x1, (SP) = x2
        PUSH    BC              ; Push x3
        LD      B, H
        LD      C, L            ; BC = x1 (new TOS)
        NEXT

; -----------------------------------------------
; PICK ( xu ... x1 x0 u -- xu ... x1 x0 xu )
;   Copy the u-th stack item to top (0 PICK = DUP)
;   u is consumed; xu replaces it as new TOS
; -----------------------------------------------
w_PICK:
        DEFCODE "PICK", 0
w_PICK_cf:
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
        ; Save IP to return stack (LDDR needs DE)
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D

        ; Compute address of xu on stack: SP + u*2
        LD      H, B
        LD      L, C            ; HL = u
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
        POP     HL              ; HL = xu
        LD      B, H
        LD      C, L            ; BC = xu (new TOS)

        ; Remove the duplicate slot left at bottom of shifted region
        INC     SP
        INC     SP

        ; Restore IP from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX

        NEXT

; -----------------------------------------------
; DEPTH ( -- n )
;   Return the number of items on the stack (before DEPTH executes)
; -----------------------------------------------
w_DEPTH:
        DEFCODE "DEPTH", 0
w_DEPTH_cf:
        PUSH    BC              ; Save TOS — full stack now on SP
        LD      HL, (sp_base)   ; HL = initial SP value
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP (bytes used)
        SRL     H
        RR      L               ; HL = HL / 2 (number of cells)
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
