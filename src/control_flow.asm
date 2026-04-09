; control_flow.asm — Compile-only guard + conditional/loop control flow words
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; ?COMP ( -- )
;   Compile-only guard: if STATE=0 (interpreting), print error and ABORT
; -----------------------------------------------
w_QCOMP:
        DEFCODE "?COMP", 0
w_QCOMP_cf:
        LD      A, (IY+UserArea.state)
        OR      (IY+UserArea.state+1)
        JR      NZ, .qcomp_ok
        ; Print "? compile only" CR LF
        ; Raw BDOS calls (no BDOS_SAVE/BDOS_RESTORE) — registers are
        ; irrelevant since we JP to ABORT immediately after printing.
        LD      HL, .comp_only_msg
        LD      B, 16               ; length: 14 chars + CR + LF
.qcomp_print:
        PUSH    HL
        PUSH    BC
        LD      E, (HL)
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC
        POP     HL
        INC     HL
        DJNZ    .qcomp_print
        JP      w_ABORT_cf
.comp_only_msg:
        DB      "? compile only", 0x0D, 0x0A
.qcomp_ok:
        NEXT

; -----------------------------------------------
; IF ( -- fwd-ref )  IMMEDIATE, compile-only
;   Compile ?BRANCH + placeholder for forward offset
; -----------------------------------------------
w_IF:
        DEFIMMED "IF"
w_IF_body:
w_IF_cf EQU w_IF_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        DW w_LIT_cf, w_QBRANCH_cf   ; push ?BRANCH xt
        DW w_COMMA_cf                ; compile ?BRANCH at HERE
        DW w_HERE_cf                 ; push HERE (fwd-ref = offset cell addr)
        DW w_LIT_cf, 0
        DW w_COMMA_cf                ; compile placeholder 0
        DW EXIT_CODE

; -----------------------------------------------
; THEN ( fwd-ref -- )  IMMEDIATE, compile-only
;   Resolve forward reference: store offset = HERE - fwd-ref
; -----------------------------------------------
w_THEN:
        DEFIMMED "THEN"
w_THEN_body:
w_THEN_cf EQU w_THEN_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( fwd-ref -- )
        DW w_HERE_cf                 ; ( fwd-ref here )
        DW w_OVER_cf                 ; ( fwd-ref here fwd-ref )
        DW w_MINUS_cf                ; ( fwd-ref here-fwd-ref ) = offset
        DW w_SWAP_cf                 ; ( offset fwd-ref )
        DW w_STORE_cf                ; store offset at fwd-ref
        DW EXIT_CODE

; -----------------------------------------------
; ELSE ( if-fwd -- else-fwd )  IMMEDIATE, compile-only
;   Compile unconditional BRANCH + placeholder, then resolve IF's fwd-ref
; -----------------------------------------------
w_ELSE:
        DEFIMMED "ELSE"
w_ELSE_body:
w_ELSE_cf EQU w_ELSE_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( if-fwd -- else-fwd )
        DW w_LIT_cf, w_BRANCH_cf    ; push BRANCH xt
        DW w_COMMA_cf                ; compile BRANCH at HERE
        DW w_HERE_cf                 ; push HERE (else-fwd for THEN)
        DW w_LIT_cf, 0
        DW w_COMMA_cf                ; compile placeholder 0
        DW w_SWAP_cf                 ; ( else-fwd if-fwd )
        ; Resolve IF's forward reference
        DW w_HERE_cf                 ; ( else-fwd if-fwd here )
        DW w_OVER_cf                 ; ( else-fwd if-fwd here if-fwd )
        DW w_MINUS_cf                ; ( else-fwd if-fwd offset )
        DW w_SWAP_cf                 ; ( else-fwd offset if-fwd )
        DW w_STORE_cf                ; store offset at if-fwd; ( else-fwd )
        DW EXIT_CODE

; -----------------------------------------------
; BEGIN ( -- begin-addr )  IMMEDIATE, compile-only
;   Push HERE as backward target
; -----------------------------------------------
w_BEGIN:
        DEFIMMED "BEGIN"
w_BEGIN_body:
w_BEGIN_cf EQU w_BEGIN_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        DW w_HERE_cf                 ; push HERE (backward target)
        DW EXIT_CODE

; -----------------------------------------------
; UNTIL ( begin-addr -- )  IMMEDIATE, compile-only
;   Compile ?BRANCH with backward offset to begin-addr
; -----------------------------------------------
w_UNTIL:
        DEFIMMED "UNTIL"
w_UNTIL_body:
w_UNTIL_cf EQU w_UNTIL_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( begin-addr -- )
        DW w_LIT_cf, w_QBRANCH_cf
        DW w_COMMA_cf                ; compile ?BRANCH
        DW w_HERE_cf                 ; ( begin-addr here ) here = offset cell addr
        DW w_MINUS_cf                ; ( begin-addr - here ) negative backward offset
        DW w_COMMA_cf                ; compile offset
        DW EXIT_CODE

; -----------------------------------------------
; WHILE ( begin-addr -- while-fwd begin-addr )  IMMEDIATE, compile-only
;   Compile ?BRANCH + placeholder, SWAP so begin-addr is on top for REPEAT
; -----------------------------------------------
w_WHILE:
        DEFIMMED "WHILE"
w_WHILE_body:
w_WHILE_cf EQU w_WHILE_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( begin-addr -- while-fwd begin-addr )
        DW w_LIT_cf, w_QBRANCH_cf
        DW w_COMMA_cf                ; compile ?BRANCH
        DW w_HERE_cf                 ; ( begin-addr while-fwd )
        DW w_LIT_cf, 0
        DW w_COMMA_cf                ; compile placeholder 0
        DW w_SWAP_cf                 ; ( while-fwd begin-addr )
        DW EXIT_CODE

; -----------------------------------------------
; REPEAT ( while-fwd begin-addr -- )  IMMEDIATE, compile-only
;   Compile BRANCH back to begin-addr, then resolve WHILE's fwd-ref
; -----------------------------------------------
w_REPEAT:
        DEFIMMED "REPEAT"
w_REPEAT_body:
w_REPEAT_cf EQU w_REPEAT_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( while-fwd begin-addr -- )
        ; Compile BRANCH back to begin-addr
        DW w_LIT_cf, w_BRANCH_cf
        DW w_COMMA_cf                ; compile BRANCH
        DW w_HERE_cf                 ; ( while-fwd begin-addr here )
        DW w_MINUS_cf                ; ( while-fwd begin-addr-here ) backward offset
        DW w_COMMA_cf                ; compile backward offset; ( while-fwd )
        ; Resolve WHILE's forward reference
        DW w_HERE_cf                 ; ( while-fwd here )
        DW w_OVER_cf                 ; ( while-fwd here while-fwd )
        DW w_MINUS_cf                ; ( while-fwd here-while-fwd )
        DW w_SWAP_cf                 ; ( offset while-fwd )
        DW w_STORE_cf                ; store offset at while-fwd; ( )
        DW EXIT_CODE
