; pictured.asm — Pictured numeric output words
; AntForth — A Forth for CP/M on Z80
;
; Epic 10 Story 10.7 — pictured numeric output subsystem:
;   <# HOLD # #S #> SIGN HOLDS  (+HLD user variable, §6.2.1675 HOLDS)
;
; Buffer resides in UserArea at IY+UserArea.pic_buf (40 bytes). HLD
; holds the absolute write cursor; <# resets it to the buffer's
; one-past-end sentinel; HOLD / # / SIGN / HOLDS decrement then write,
; so the buffer fills right-to-left. #> returns the final c-addr u.
;
; `#` collides with the assembler's immediate-operand sigil at
; assembler.asm:985. The assembler entry (defined later in the build
; order, so it is head of the `#` hash bucket) dispatches at run time:
; when asm_mode is clear it jumps to w_PIC_HASH_cf below; when set it
; emits the sigil tag as before. Both dictionary entries coexist;
; Epic 12 (wordlists) will migrate the asm entry to an ASSEMBLER
; wordlist, retiring this dispatch hack.

; -----------------------------------------------
; HLD ( -- a-addr )
;   Push the address of the pictured-output write cursor.
; antforth extension — HLD exposed as user variable (DPANS94 does not
;   require exposure but Gforth / SwiftForth precedent)
; -----------------------------------------------
w_PIC_HLD:
        DEFCODE "HLD", 0
w_PIC_HLD_cf:
        LD      A, UserArea.hld
        JP      push_user_var

; -----------------------------------------------
; <# ( -- )
;   Reset pictured-output write cursor to buffer's one-past-end sentinel.
; ANS Forth 1994 §6.1.0490   <#   — start pictured numeric output conversion
; -----------------------------------------------
w_PIC_LESS_HASH:
        DEFCODE "<#", 0
w_PIC_LESS_HASH_cf:
        PUSH    BC                      ; preserve TOS during compute
        PUSH    IY
        POP     HL                      ; HL = IY
        LD      BC, UserArea.pic_buf + PIC_BUF_SIZE
        ADD     HL, BC                  ; HL = sentinel (one past buffer's last byte)
        LD      (IY+UserArea.hld), L
        LD      (IY+UserArea.hld+1), H
        POP     BC                      ; restore TOS
        NEXT

; -----------------------------------------------
; HOLD ( char -- )
;   Insert char into the pictured-output buffer (buffer fills RTL).
;   Underflow (writing below pic_buf) raises -17 THROW per ANS Forth
;   1994 §9.3.5 (via do_pic_overflow_error).
; ANS Forth 1994 §6.1.1670   HOLD   — insert char into pictured-output buffer
; -----------------------------------------------
w_PIC_HOLD:
        DEFCODE "HOLD", 0
w_PIC_HOLD_cf:
        CALL    check_underflow
        LD      A, C                    ; A = char (low byte of TOS cell)
        CALL    hold_common             ; decrement HLD, guard, store A
        POP     BC                      ; load new TOS
        NEXT

; -----------------------------------------------
; # ( ud1 -- ud2 )
;   Extract one digit of pictured numeric output: divide ud1 by BASE;
;   convert the remainder (0..35) to its ASCII digit; HOLD it; return
;   the quotient as ud2. Inline 32-by-8 shift-subtract division (BASE
;   always fits in 8 bits — it is capped at 36).
; ANS Forth 1994 §6.1.0030   #   — extract one digit of pictured numeric output
; -----------------------------------------------
w_PIC_HASH:
        DEFCODE "#", 0
w_PIC_HASH_cf:
        CALL    check_underflow_2
        LD      (pictured_ip_stash), DE ; stash IP — DE needed as scratch
        POP     HL                      ; HL = ud-hi; BC already = ud-lo
        XOR     A                       ; A = 8-bit remainder accumulator
        LD      D, 32                   ; 32-iteration loop counter
.pic_hash_loop:
        ; Shift (A : HL : BC) left by 1 — 40-bit shift
        SLA     C
        RL      B                       ; BC <<= 1; CF = old bit 15
        RL      L
        RL      H                       ; HL <<= 1 with CF; CF = old bit 31
        RLA                             ; A <<= 1 with CF; CF = old bit 39
        JR      C, .pic_hash_force_sub  ; 9-bit remainder overflow → unconditional sub
        CP      (IY+UserArea.base)
        JR      C, .pic_hash_no_sub
.pic_hash_force_sub:
        SUB     (IY+UserArea.base)
        INC     C                       ; set bit 0 of quotient (SLA left it clear)
.pic_hash_no_sub:
        DEC     D
        JR      NZ, .pic_hash_loop
        ; Loop done: BC = ud2-lo, HL = ud2-hi, A = remainder (0..BASE-1)
        PUSH    HL                      ; push ud2-hi (second on stack)
        CALL    digit_to_char           ; A = ASCII digit ('0'..'9' or 'A'..)
        CALL    hold_common             ; decrement HLD, store A
        LD      DE, (pictured_ip_stash) ; restore IP
        NEXT

; -----------------------------------------------
; #S ( ud1 -- ud2 )
;   Emit pictured-output digits until ud is 0 0. Always emits at least
;   one digit (so `0. <# #S #>` produces "0"). Exits with ud2 = 0 0.
;   The `#` body guards 2-cell depth via check_underflow_2, so #S
;   inherits the underflow discipline without a separate guard word.
; ANS Forth 1994 §6.1.0050   #S   — emit digits until ud is 0 0
; -----------------------------------------------
w_PIC_HASH_S:
        DEFWORD "#S", 0
w_PIC_HASH_S_body:
w_PIC_HASH_S_cf EQU w_PIC_HASH_S_body - 3
.pic_hash_s_loop:
        DW      w_PIC_HASH_cf           ; # — one digit (and its underflow check)
        DW      w_TWO_DUP_cf            ; 2DUP
        DW      w_OR_cf                 ; OR of the two cells on TOS
        DW      w_ZERO_EQUALS_cf        ; 0= — TRUE iff ud is (0,0)
        DW      w_QBRANCH_cf            ; UNTIL: branch back on FALSE
        DW      .pic_hash_s_loop - $
        DW      EXIT_CODE

; -----------------------------------------------
; #> ( xd -- c-addr u )
;   Discard xd; return the pictured-output string. c-addr is the current
;   HLD (leftmost written byte); u is the byte count to the buffer's end.
; ANS Forth 1994 §6.1.0040   #>   — finish pictured numeric output
; -----------------------------------------------
w_PIC_GREATER_HASH:
        DEFCODE "#>", 0
w_PIC_GREATER_HASH_cf:
        CALL    check_underflow_2
        LD      (pictured_ip_stash), DE ; stash IP; DE free for compute
        POP     HL                      ; discard xd-hi (BC held xd-lo, about to be overwritten)
        LD      L, (IY+UserArea.hld)
        LD      H, (IY+UserArea.hld+1)  ; HL = c-addr (= HLD)
        PUSH    HL                      ; push c-addr (second on stack)
        LD      D, H
        LD      E, L                    ; DE = HLD (preserve for subtract)
        PUSH    IY
        POP     HL                      ; HL = IY
        LD      BC, UserArea.pic_buf + PIC_BUF_SIZE
        ADD     HL, BC                  ; HL = end sentinel
        OR      A                       ; clear CF
        SBC     HL, DE                  ; HL = end - HLD = u (>= 0)
        LD      B, H
        LD      C, L                    ; BC = u (new TOS)
        LD      DE, (pictured_ip_stash)
        NEXT

; -----------------------------------------------
; SIGN ( n -- )
;   If n is negative (bit 15 = 1), HOLD '-'. Consume n in both branches.
;   Inline DEFCODE: SIGN is the only pictured word that needs a 1-cell
;   guard, so adding a generic (?1) DEFCODE helper is not justified.
; ANS Forth 1994 §6.1.2210   SIGN   — insert '-' if n is negative
; -----------------------------------------------
w_PIC_SIGN:
        DEFCODE "SIGN", 0
w_PIC_SIGN_cf:
        CALL    check_underflow
        BIT     7, B                    ; sign bit of n (high byte bit 7)
        JR      Z, .pic_sign_nonneg
        LD      A, '-'
        CALL    hold_common             ; HOLD '-'
.pic_sign_nonneg:
        POP     BC                      ; consume n; load new TOS
        NEXT

; -----------------------------------------------
; (?2) ( -- )
;   Internal 2-cell underflow guard. Used as the prefix of DEFWORD HOLDS
;   because its canonical body starts with DUP (1-cell guard), which
;   would not catch DEPTH = 1. Pictured-local helper.
; -----------------------------------------------
w_PIC_QGUARD_2:
        DEFCODE "(?2)", 0
w_PIC_QGUARD_2_cf:
        CALL    check_underflow_2
        NEXT

; -----------------------------------------------
; HOLDS ( c-addr u -- )
;   Insert the counted string into the pictured-output buffer, left-to-
;   right in the final output. Walks c-addr..c-addr+u-1 back-to-front
;   so that the right-to-left buffer fill yields correct visual order.
;   Canonical DPANS94 §6.2.1675 reference body is used verbatim.
; Forth 2014 §6.2.1675   HOLDS   — insert counted string into pictured-output buffer
; -----------------------------------------------
w_PIC_HOLDS:
        DEFWORD "HOLDS", 0
w_PIC_HOLDS_body:
w_PIC_HOLDS_cf EQU w_PIC_HOLDS_body - 3
        DW      w_PIC_QGUARD_2_cf       ; 2-cell underflow guard
.pic_holds_loop:
        DW      w_DUP_cf                ; DUP — copy u for the WHILE test
        DW      w_QBRANCH_cf            ; WHILE — exit if u == 0
        DW      .pic_holds_exit - $
        DW      w_ONE_MINUS_cf          ; 1-  (u -> u-1)
        DW      w_TWO_DUP_cf            ; 2DUP (c-addr u')
        DW      w_PLUS_cf               ; +   (c-addr + u')
        DW      w_C_FETCH_cf            ; C@  (fetch char at that address)
        DW      w_PIC_HOLD_cf           ; HOLD
        DW      w_BRANCH_cf             ; REPEAT
        DW      .pic_holds_loop - $
.pic_holds_exit:
        DW      w_TWO_DROP_cf           ; 2DROP (drop c-addr u)
        DW      EXIT_CODE

; -----------------------------------------------
; hold_common — Internal helper
;   Decrement HLD (with underflow guard) and write A at the new HLD.
;   Entry: A = char, IY = user_area. DE (IP) preserved.
;   Exit:  HLD decremented; A stored at new HLD. Flags clobbered.
;   Preserves: BC, DE, IX, IY, SP.
;   Overflow: JP do_pic_overflow_error (raises -17 THROW; no return).
; -----------------------------------------------
hold_common:
        LD      L, (IY+UserArea.hld)
        LD      H, (IY+UserArea.hld+1)  ; HL = current HLD
        PUSH    DE                      ; preserve IP
        LD      DE, user_area + UserArea.pic_buf
        PUSH    HL                      ; preserve HLD for restore
        OR      A                       ; clear CF
        SBC     HL, DE                  ; HL = HLD - pic_buf_start
        POP     HL                      ; restore HLD (flags preserved across POP)
        POP     DE                      ; restore IP (flags preserved across POP)
        JR      Z, .hc_overflow         ; HLD == pic_buf start → DEC would underflow
        JR      C, .hc_overflow         ; HLD < pic_buf start (corrupt; cannot happen in normal use)
        DEC     HL                      ; HLD -= 1
        LD      (IY+UserArea.hld), L
        LD      (IY+UserArea.hld+1), H
        LD      (HL), A                 ; write char at new HLD
        RET
.hc_overflow:
        JP      do_pic_overflow_error

; -----------------------------------------------
; do_pic_overflow_error — Internal raise helper
;   Migrated by Story 11.6 to raise -17 THROW per ANS Forth 1994 §9.3.5.
;   Never returns. Pre-Story-11.6 this site printed "? Pictured buffer
;   overflow" + CR/LF via direct BDOS before JP w_ABORT_cf; the unified
;   `error -17: pictured numeric output string overflow` diagnostic
;   from Story 11.3's throw_desc_table replaces the pre-print (mirrors
;   Story 11.4's removal of "? Stack underflow" and Story 11.5's
;   removal of "? compile only").
;
;   Callers: hold_common.hc_overflow falls into this site (so HOLD,
;   #, SIGN, HOLDS all reach it via hold_common). All callers are
;   primary-set DEFCODE bodies — no EXX-restore needed at the raise.
; -----------------------------------------------
do_pic_overflow_error:
        ; -17 THROW (Story 11.6): pictured numeric output string
        ; overflow per ANS Forth 1994 §9.3.5.
        LD      BC, THROW_PIC_OVERFLOW
        JP      w_THROW_cf.kernel_entry

; Scratch cell for stashing IP (DE) across the DEFCODE pictured words
; that need DE as a general-purpose register (#, #>, HOLDS). Never held
; across NEXT; never re-entered from threaded code while valid.
pictured_ip_stash:
        DW      0
