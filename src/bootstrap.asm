; bootstrap.asm — Forth-defined words using DEFWORD macro
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; NEGATE ( n -- -n )
;   Negate the top of stack: 0 SWAP -
; -----------------------------------------------
w_NEGATE:
    DEFWORD "NEGATE", 0
w_NEGATE_body:
w_NEGATE_cf EQU w_NEGATE_body - 3
    DW w_LIT_cf, 0
    DW w_SWAP_cf
    DW w_MINUS_cf
    DW EXIT_CODE

; -----------------------------------------------
; ABS ( n -- |n| )
;   Absolute value: DUP 0< ?BRANCH(skip) NEGATE
; -----------------------------------------------
w_ABS:
    DEFWORD "ABS", 0
w_ABS_body:
w_ABS_cf EQU w_ABS_body - 3
    DW w_DUP_cf
    DW w_ZERO_LESS_cf
    DW w_QBRANCH_cf
    DW .abs_done - $
    DW w_NEGATE_cf
.abs_done:
    DW EXIT_CODE

; -----------------------------------------------
; MIN ( n1 n2 -- min )
;   Minimum: OVER OVER > ?BRANCH(skip) SWAP DROP
; -----------------------------------------------
w_MIN:
    DEFWORD "MIN", 0
w_MIN_body:
w_MIN_cf EQU w_MIN_body - 3
    DW w_OVER_cf
    DW w_OVER_cf
    DW w_GREATER_cf
    DW w_QBRANCH_cf
    DW .min_done - $
    DW w_SWAP_cf
.min_done:
    DW w_DROP_cf
    DW EXIT_CODE

; -----------------------------------------------
; MAX ( n1 n2 -- max )
;   Maximum: OVER OVER < ?BRANCH(skip) SWAP DROP
; -----------------------------------------------
w_MAX:
    DEFWORD "MAX", 0
w_MAX_body:
w_MAX_cf EQU w_MAX_body - 3
    DW w_OVER_cf
    DW w_OVER_cf
    DW w_LESS_cf
    DW w_QBRANCH_cf
    DW .max_done - $
    DW w_SWAP_cf
.max_done:
    DW w_DROP_cf
    DW EXIT_CODE
