; test_key.asm — Interactive test exercising KEY and KEY? Forth primitives
; Tests KEY and KEY? through the Forth inner interpreter (not raw BDOS)
; Uses KEY? to poll for input, KEY to read characters, Ctrl-C exits via BYE
;
; Part of antforth — ANS Forth for MicroBeast Z80

        DEVICE NONE

        INCLUDE "constants.asm"
        INCLUDE "macros.asm"
        INCLUDE "structures.asm"

        ORG     TPA_START

; === Cold start (minimal — just enough for threading) ===
cold_start:
        LD      HL, (BDOS_ADDR_PTR)
        LD      SP, HL
        LD      (sp_base), HL

        OR      A
        LD      DE, PS_SIZE
        SBC     HL, DE
        PUSH    HL
        POP     IX

        LD      IY, user_area

        LD      DE, test_thread
        NEXT

; === Include primitives (same code words as antforth.com) ===
        INCLUDE "inner_interpreter.asm"
        INCLUDE "stack_ops.asm"
        INCLUDE "logic.asm"
        INCLUDE "io.asm"
        INCLUDE "system.asm"

; === Test thread ===
; Exercises: KEY?, KEY, EMIT, TYPE, CR, DUP, DROP, =, LIT, BRANCH, ?BRANCH, BYE
test_thread:
        ; Print banner using TYPE and CR
        DW      w_CR_cf
        DW      w_LIT_cf, str_banner
        DW      w_LIT_cf, str_banner_len
        DW      w_TYPE_cf
        DW      w_CR_cf

        ; Interactive loop: poll with KEY?, read with KEY, Ctrl-C exits
.poll:
        DW      w_KEYQ_cf               ; KEY? ( -- flag )
        DW      w_QBRANCH_cf            ; if no key ready, keep polling
.qb1:
        DW      .poll - .qb1

        ; Key ready — read it via KEY
        DW      w_KEY_cf                ; KEY ( -- char )  [BDOS auto-echoes]
        DW      w_DUP_cf                ; ( char -- char char )
        DW      w_LIT_cf, 0x03          ; ( char char -- char char 3 )
        DW      w_EQUALS_cf             ; ( char char 3 -- char flag )
        DW      w_QBRANCH_cf            ; if not Ctrl-C, continue loop
.qb2:
        DW      .continue - .qb2

        ; Ctrl-C path: clean up and exit
        DW      w_DROP_cf
        DW      w_CR_cf
        DW      w_LIT_cf, str_bye
        DW      w_LIT_cf, str_bye_len
        DW      w_TYPE_cf
        DW      w_CR_cf
        DW      w_BYE_cf

.continue:
        DW      w_DROP_cf               ; drop char (already echoed by BDOS)
        DW      w_BRANCH_cf             ; back to poll loop
.br1:
        DW      .poll - .br1

; === String data ===
str_banner:     DB      "KEY/KEY? test (Ctrl-C quits)"
str_banner_len  EQU     $ - str_banner
str_bye:        DB      "Done!"
str_bye_len     EQU     $ - str_bye

; === Data areas ===
sp_base:        DW      0
user_area:      DS      UserArea
