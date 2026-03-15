; inner_interpreter.asm — Inner interpreter core routines
; AntForth — A Forth for CP/M on Z80
;
; Contains: DOCOL, EXIT_CODE
; NEXT macro is defined in macros.asm
; LIT, BRANCH, ?BRANCH, EXECUTE to be added in later stories

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

; === EXIT — Return from colon definition ===
EXIT_CODE:
        ; Pop IP from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        NEXT
