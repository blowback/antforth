; arithmetic.asm — Arithmetic primitives (+, -, *, /, MOD, /MOD)
; AntForth — A Forth for CP/M on Z80
;
; Register contract:
;   BC = TOS, DE = IP (preserve!), SP = parameter stack
;   HL, AF = scratch (free within CODE words)

; -----------------------------------------------
; 1+ ( n -- n+1 )
;   Add one to TOS
; -----------------------------------------------
w_ONE_PLUS:
        DEFCODE "1+", 0
w_ONE_PLUS_cf:
        INC     BC
        NEXT

; -----------------------------------------------
; 1- ( n -- n-1 )
;   Subtract one from TOS
; -----------------------------------------------
w_ONE_MINUS:
        DEFCODE "1-", 0
w_ONE_MINUS_cf:
        DEC     BC
        NEXT

; -----------------------------------------------
; 2* ( x -- x*2 )
;   Arithmetic left shift (multiply by 2)
; -----------------------------------------------
w_TWO_STAR:
        DEFCODE "2*", 0
w_TWO_STAR_cf:
        SLA     C
        RL      B
        NEXT

; -----------------------------------------------
; 2/ ( x -- x/2 )
;   Arithmetic right shift (divide by 2, sign-preserving)
; -----------------------------------------------
w_TWO_SLASH:
        DEFCODE "2/", 0
w_TWO_SLASH_cf:
        SRA     B
        RR      C
        NEXT

; -----------------------------------------------
; + ( n1 n2 -- n3 )
;   Add top two stack items
; -----------------------------------------------
w_PLUS:
    DEFCODE "+", 0
w_PLUS_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = n1
    ADD     HL, BC          ; HL = n1 + n2
    LD      B, H
    LD      C, L            ; BC = result
    NEXT

; -----------------------------------------------
; - ( n1 n2 -- n3 )
;   Subtract n2 from n1
; -----------------------------------------------
w_MINUS:
    DEFCODE "-", 0
w_MINUS_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = n1
    OR      A               ; Clear carry
    SBC     HL, BC          ; HL = n1 - n2
    LD      B, H
    LD      C, L            ; BC = result
    NEXT

; -----------------------------------------------
; * ( n1 n2 -- n3 )
;   Multiply (16-bit, low 16 bits of result)
;   Uses shift-and-add algorithm (Z80 has no MUL)
;   Saves/restores DE (IP) since it's used as scratch
; -----------------------------------------------
w_STAR:
    DEFCODE "*", 0
w_STAR_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = n1
    PUSH    DE              ; Save IP
    EX      DE, HL          ; DE = n1 (multiplicand)
    LD      HL, 0           ; HL = accumulator
    LD      A, 16           ; bit counter
.mul_loop:
    ADD     HL, HL          ; shift accumulator left
    SLA     C               ; shift multiplier (BC) left
    RL      B               ; MSB falls into carry
    JR      NC, .mul_skip
    ADD     HL, DE          ; add multiplicand if bit was set
.mul_skip:
    DEC     A
    JR      NZ, .mul_loop
    LD      B, H
    LD      C, L            ; BC = result (low 16 bits)
    POP     DE              ; Restore IP
    NEXT

; -----------------------------------------------
; Internal: udivmod
;   Unsigned 16-bit division: HL / BC -> HL=quotient, DE=remainder
;   Caller MUST save DE (IP) before calling
;   Uses A as bit counter, clobbers DE
;   Divisor-zero is checked at entry; BC = 0 raises
;   -10 THROW via w_THROW_cf.kernel_entry. Covers `/`, `MOD`, `/MOD`
;   user-facing words (each routes through sdivmod → udivmod;
;   sdivmod's sign-fixup preserves zero via the BIT 7 check, so
;   an entry-time BC = 0 reaches udivmod unchanged and trips the
;   guard here).
;   Note: when the guard fires, several pushes upstream remain unmatched
;   on SP:
;     - sdivmod's `PUSH AF` (sign flags) — sdivmod's matching
;       `POP AF` is skipped.
;     - The user-word caller's `PUSH DE` (IP-stash) at
;       w_SLASH_cf, w_MOD_cf, w_SLASH_MOD_cf.
;   The catch-frame `LD SP, HL` (caught path) and the inlined recovery
;   chain at .throw_uncaught (uncaught path; `LD SP, (sp_base)`) both
;   wholesale-reset SP, so all stranded bytes are discarded. Future
;   refactors that change either reset path inherit the leak.
; -----------------------------------------------
udivmod:
    ; Divisor-zero guard: BC = 0 → -10 THROW.
    ; -10 THROW: division by zero per ANS Forth 1994 §9.3.5
    LD      A, B
    OR      C
    JR      NZ, .udiv_proceed
    LD      BC, THROW_DIV_BY_ZERO
    JP      w_THROW_cf.kernel_entry
.udiv_proceed:
    ; Precondition: BC != 0 (now enforced by the guard above)
    LD      DE, 0           ; DE = remainder
    LD      A, 16           ; 16 bits
.udiv_loop:
    ADD     HL, HL          ; Shift dividend left (MSB into carry)
    RL      E               ; Shift carry into remainder
    RL      D
    EX      DE, HL          ; HL = remainder, DE = partial quotient
    OR      A               ; Clear carry before SBC
    SBC     HL, BC          ; Try subtract divisor
    JR      NC, .udiv_1     ; Subtraction succeeded
    ADD     HL, BC          ; Restore remainder
    EX      DE, HL          ; DE = remainder, HL = partial quotient
    JR      .udiv_next
.udiv_1:
    EX      DE, HL          ; DE = remainder, HL = partial quotient
    SET     0, L            ; Set quotient bit
.udiv_next:
    DEC     A
    JR      NZ, .udiv_loop
    ; HL = quotient, DE = remainder
    RET

; -----------------------------------------------
; Internal: sdivmod
;   Signed 16-bit division with symmetric (truncate toward zero) semantics
;   Input:  HL = dividend (signed), BC = divisor (signed)
;   Output: HL = quotient, DE = remainder
;   Clobbers: AF, BC (BC = |divisor| on exit from udivmod, but we restore)
;   Caller MUST save DE (IP) before calling
;
;   Sign rules (symmetric):
;     remainder sign = dividend sign
;     quotient negative if signs differ
; -----------------------------------------------
sdivmod:
    ; Use IYL to store sign flags (bit 0 = negate quotient, bit 1 = negate remainder)
    ; Actually, IY is the user pointer — must not clobber.
    ; Use the stack to store sign flags instead.
    LD      A, 0            ; sign flag

    ; Check dividend sign
    BIT     7, H
    JR      Z, .sd_pos1
    OR      3               ; Set bits 0 and 1 (dividend was negative)
    ; Negate HL
    PUSH    AF
    XOR     A
    SUB     L
    LD      L, A
    SBC     A, A
    SUB     H
    LD      H, A
    POP     AF
.sd_pos1:
    ; Check divisor sign
    BIT     7, B
    JR      Z, .sd_pos2
    XOR     1               ; Toggle bit 0 (quotient sign)
    ; Negate BC
    PUSH    AF
    XOR     A
    SUB     C
    LD      C, A
    SBC     A, A
    SUB     B
    LD      B, A
    POP     AF
.sd_pos2:
    ; Save sign flags
    PUSH    AF
    CALL    udivmod         ; HL = quotient, DE = remainder
    POP     AF

    ; Fix remainder sign (bit 1)
    BIT     1, A
    JR      Z, .sd_rem_ok
    PUSH    AF
    XOR     A
    SUB     E
    LD      E, A
    SBC     A, A
    SUB     D
    LD      D, A
    POP     AF
.sd_rem_ok:
    ; Fix quotient sign (bit 0)
    BIT     0, A
    JR      Z, .sd_quot_ok
    XOR     A
    SUB     L
    LD      L, A
    SBC     A, A
    SUB     H
    LD      H, A
.sd_quot_ok:
    ; HL = quotient (signed), DE = remainder (signed)
    RET

; -----------------------------------------------
; /MOD ( n1 n2 -- rem quot )
;   Signed symmetric division with remainder
; -----------------------------------------------
w_SLASH_MOD:
    DEFCODE "/MOD", 0
w_SLASH_MOD_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = n1 (dividend)
    PUSH    DE              ; Save IP
    CALL    sdivmod         ; HL = quotient, DE = remainder
    ; Stack has: [saved_IP] [...]
    ; Need: push remainder, BC = quotient, DE = IP restored
    PUSH    HL              ; [quotient] [saved_IP] [...]
    PUSH    DE              ; [remainder] [quotient] [saved_IP] [...]
    POP     HL              ; HL = remainder
    POP     BC              ; BC = quotient (TOS)
    POP     DE              ; DE = saved IP (restored)
    PUSH    HL              ; [remainder] [...] — second on stack
    NEXT

; -----------------------------------------------
; / ( n1 n2 -- quot )
;   Signed symmetric division
; -----------------------------------------------
w_SLASH:
    DEFCODE "/", 0
w_SLASH_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = n1 (dividend)
    PUSH    DE              ; Save IP
    CALL    sdivmod         ; HL = quotient, DE = remainder (ignored)
    LD      B, H
    LD      C, L            ; BC = quotient (TOS)
    POP     DE              ; Restore IP
    NEXT

; -----------------------------------------------
; MOD ( n1 n2 -- rem )
;   Signed symmetric modulus
; -----------------------------------------------
w_MOD:
    DEFCODE "MOD", 0
w_MOD_cf:
    CALL    check_underflow_2
    POP     HL              ; HL = n1 (dividend)
    PUSH    DE              ; Save IP
    CALL    sdivmod         ; HL = quotient (ignored), DE = remainder
    LD      B, D
    LD      C, E            ; BC = remainder (TOS)
    POP     DE              ; Restore IP
    NEXT

; -----------------------------------------------
; */MOD ( n1 n2 n3 -- n4 n5 )
;   Mixed-precision multiply-divide-modulo via double intermediate.
;   n4 = (n1*n2) mod n3 (remainder, sign matches dividend per SM/REM)
;   n5 = (n1*n2) / n3   (quotient, truncated toward zero)
; ANS Forth 1994 §6.1.0110   */MOD   — mixed-precision multiply-divide-modulo
; Body chain: >R M* R> SM/REM. Underflow guard chains via M*'s 2DUP
; (DEPTH>=2 after >R) — net DEPTH>=3 at entry. If guard trips inside M*,
; ABORT resets both stacks (including the >R-stashed n3), so no rstack leak.
; -----------------------------------------------
w_STAR_SLASH_MOD:
    DEFWORD "*/MOD", 0
w_STAR_SLASH_MOD_body:
w_STAR_SLASH_MOD_cf EQU w_STAR_SLASH_MOD_body - 3
    DW      w_TO_R_cf               ; >R   ( n1 n2 ; R: n3 )
    DW      w_M_STAR_cf             ; M*   ( d ; R: n3 ) — signed mixed multiply
    DW      w_R_FROM_cf             ; R>   ( d n3 )
    DW      w_S_M_SLASH_REM_cf      ; SM/REM ( rem quot )
    DW      EXIT_CODE

; -----------------------------------------------
; */ ( n1 n2 n3 -- n4 )
;   Mixed-precision multiply-divide via double intermediate.
;   n4 = (n1*n2) / n3 (truncated toward zero, symmetric per SM/REM)
; ANS Forth 1994 §6.1.0100   */   — mixed-precision multiply-divide
; Factored via */MOD: keeps both bodies tied (a change to */MOD
; propagates automatically). Trap test: 32767 32767 32767 */ → 32767
; (would return 0 if implementation accidentally used single-cell *).
; -----------------------------------------------
w_STAR_SLASH:
    DEFWORD "*/", 0
w_STAR_SLASH_body:
w_STAR_SLASH_cf EQU w_STAR_SLASH_body - 3
    DW      w_STAR_SLASH_MOD_cf     ; */MOD ( rem quot )
    DW      w_SWAP_cf               ; SWAP  ( quot rem )
    DW      w_DROP_cf               ; DROP  ( quot )
    DW      EXIT_CODE
