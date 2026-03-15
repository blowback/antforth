; io.asm — Console I/O primitives
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; EMIT ( char -- )
;   Output character to console via BDOS C_WRITE
; -----------------------------------------------
w_EMIT:
        DEFCODE "EMIT", 0
w_EMIT_cf:
        LD      A, C            ; A = char (save from TOS before BDOS clobbers)
        BDOS_SAVE               ; PUSH DE, PUSH BC
        LD      E, A            ; E = char for BDOS
        LD      C, C_WRITE      ; BDOS function 2: C_WRITE
        CALL    BDOS_ENTRY
        BDOS_RESTORE            ; POP BC, POP DE — restores IP and old TOS
        POP     BC              ; Pop new TOS (char consumed)
        NEXT
