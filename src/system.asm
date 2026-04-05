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

; -----------------------------------------------
; ABORT ( -- )
;   Reset parameter stack and restart QUIT
;   Never returns
; -----------------------------------------------
w_ABORT:
        DEFCODE "ABORT", 0
w_ABORT_cf:
        LD      HL, (sp_base)
        LD      SP, HL                  ; Reset parameter stack
        JP      w_QUIT_cf               ; Enter QUIT (resets return stack + STATE)
