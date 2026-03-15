; system.asm — System words (BYE, MARKER, WORDS, ABORT, QUIT, error handling)
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; BYE ( -- )
;   Exit to CP/M (terminate via BDOS function 0)
; -----------------------------------------------
w_BYE:
        DEFCODE "BYE", 0
w_BYE_cf:
        LD      C, P_TERMCPM
        JP      BDOS_ENTRY
        ; No NEXT — BYE never returns
