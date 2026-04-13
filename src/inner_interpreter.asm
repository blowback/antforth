; inner_interpreter.asm — Inner interpreter core routines
; AntForth — A Forth for CP/M on Z80
;
; Contains: DOCOL, EXIT_CODE, LIT, BRANCH, ?BRANCH, EXECUTE
; NEXT macro is defined in macros.asm

; === DOCOL — Enter colon definition ===
; Push IP (DE) onto return stack (IX), set IP to body (following JP DOCOL)
DOCOL:
        ; Push current IP onto return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        ; W (HL) points to code field (the JP DOCOL), body = HL+3
        INC     HL
        INC     HL
        INC     HL
        ; HL = body address = new IP, use NEXTHL to avoid redundant EX DE, HL
        NEXTHL

; -----------------------------------------------
; EXIT ( -- ) ( R: nest-sys -- )
;   Return from colon definition (dictionary word wrapping EXIT_CODE)
; -----------------------------------------------
w_EXIT:
        DEFCODE "EXIT", 0
w_EXIT_cf:
        JP      EXIT_CODE

; === EXIT — Return from colon definition ===
EXIT_CODE:
        ; Pop IP from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        NEXT

; === DOVAR — Push variable body address ===
; HL points to code field (JP DOVAR)
; Body = HL+5 (skips 3-byte JP + 2-byte does-addr slot)
; ( -- addr )
DOVAR:
        PUSH    BC              ; Save old TOS
        LD      BC, 5
        ADD     HL, BC          ; HL = body address (cf+5)
        LD      B, H
        LD      C, L            ; BC = body address (new TOS)
        NEXT

; === DOCON — Push constant value ===
; HL points to code field (JP DOCON)
; Value = HL+3 (no does-addr slot for constants)
; ( -- x )
DOCON:
        PUSH    BC              ; Save old TOS
        INC     HL
        INC     HL
        INC     HL              ; HL = body address (cf+3)
        LD      C, (HL)
        INC     HL
        LD      B, (HL)         ; BC = value at body (new TOS)
        NEXT

; === DODOES — Enter DOES> definition, push body address ===
; HL points to code field (JP DODOES)
; cf+3 = does-addr, cf+5 = body
; ( -- addr )
DODOES:
        ; Save IP to return stack (entering a colon-like definition)
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        ; Read does-addr at HL+3
        INC     HL
        INC     HL
        INC     HL              ; HL = &does-addr
        LD      E, (HL)
        INC     HL
        LD      D, (HL)         ; DE = does-addr (new IP)
        INC     HL              ; HL = body address (cf+5)
        ; Push body address as new TOS
        PUSH    BC              ; Save old TOS
        LD      B, H
        LD      C, L            ; BC = body address (new TOS)
        NEXT

; === DOMARKER — Restore dictionary state from marker body ===
; HL points to code field (JP DOMARKER)
; Body at cf+3: [saved_here(2)][saved_hash_table(128)]
; ( -- ) no stack effect
DOMARKER:
        ; Skip code field to reach body
        INC     HL
        INC     HL
        INC     HL                      ; HL = &saved_here

        ; Save DE (IP) and BC (TOS) — LDIR clobbers both DE and BC
        CALL    rpush_de
        CALL    rpush_bc

        ; Read saved HERE from body
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        INC     HL                      ; DE = saved_here, HL = &saved_hash_data

        ; Restore HERE
        LD      (IY+UserArea.here), E
        LD      (IY+UserArea.here+1), D

        ; Copy 128 bytes from body to hash_table
        LD      DE, hash_table          ; DE = destination
        LD      BC, 128
        LDIR                            ; Restore all 64 hash bucket heads

        ; Restore BC (TOS) and DE (IP)
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        CALL    rpop_de
        NEXT

; -----------------------------------------------
; Internal return-stack helpers (not Forth words)
; -----------------------------------------------
rpush_de:                       ; Push DE onto return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        RET                         ; 9 bytes

rpop_de:                        ; Pop DE from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        RET                         ; 9 bytes

rpush_bc:                       ; Push BC onto return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B
        RET                         ; 9 bytes

rpop_bc:                        ; Pop BC from return stack
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        RET                         ; 9 bytes

; -----------------------------------------------
; LIT ( -- x )
;   Push inline literal from thread to parameter stack
; -----------------------------------------------
w_LIT:
        DEFCODE "LIT", 0
w_LIT_cf:
        PUSH    BC              ; Push current TOS to parameter stack
        EX      DE, HL          ; HL = IP
        LD      C, (HL)
        INC     HL
        LD      B, (HL)
        INC     HL              ; HL = IP past literal
        NEXTHL                  ; Use HL directly as IP

; -----------------------------------------------
; BRANCH ( -- )
;   Unconditional branch: add inline offset to IP
;   Offset is relative to the address of the offset cell itself
; -----------------------------------------------
w_BRANCH:
        DEFCODE "BRANCH", 0
w_BRANCH_cf:
        EX      DE, HL          ; HL = IP (points to offset cell)
        LD      E, (HL)
        INC     HL
        LD      D, (HL)         ; DE = offset
        DEC     HL              ; HL = IP (back to start of offset)
        ADD     HL, DE          ; HL = IP + offset (new IP)
        NEXTHL

; -----------------------------------------------
; ?BRANCH ( flag -- )
;   Conditional branch: if flag is 0 (FALSE), branch; else fall through
; -----------------------------------------------
w_QBRANCH:
        DEFCODE "?BRANCH", 0
w_QBRANCH_cf:
        LD      A, B
        OR      C               ; Test if BC (TOS) is zero
        POP     BC              ; Pop new TOS from stack regardless
        EX      DE, HL          ; HL = IP
        JR      Z, .do_branch   ; If flag was 0, take the branch
        ; Fall through: skip the offset
        INC     HL
        INC     HL              ; IP past the offset
        NEXTHL
.do_branch:
        ; Take the branch: add inline offset to IP
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        DEC     HL
        ADD     HL, DE          ; HL = IP + offset
        NEXTHL

; -----------------------------------------------
; EXECUTE ( xt -- )
;   Execute the word whose execution token is on the stack
; -----------------------------------------------
w_EXECUTE:
        DEFCODE "EXECUTE", 0
w_EXECUTE_cf:
        LD      H, B
        LD      L, C            ; HL = xt (code field address)
        POP     BC              ; Pop new TOS
        JP      (HL)            ; Jump to code field
