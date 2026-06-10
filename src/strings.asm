; strings.asm — String parsing and number conversion words
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; WORD ( char -- c-addr )
;   Parse next whitespace-delimited token from TIB
;   Skip leading delimiters, copy token to HERE as counted string
;   Advance >IN past parsed token
; -----------------------------------------------
w_WORD:
        DEFCODE "WORD", 0
w_WORD_cf:
        ; BC = delimiter char (TOS, only C matters)
        ; Capture delim in A (survives EXX), then free BC/DE/HL via shadows
        LD      A, C            ; A = delimiter — must precede EXX
        EXX                     ; Save TOS/IP/W to shadows

        ; Save delimiter in scratch
        LD      (.word_delim), A

        ; Load parse state: HL = tib_addr + >IN
        LD      E, (IY+UserArea.tib_addr)
        LD      D, (IY+UserArea.tib_addr+1)     ; DE = tib_addr
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)       ; HL = >IN
        ADD     HL, DE                           ; HL = tib_addr + >IN (current parse position)

        ; Compute remaining = tib_len - >IN
        LD      E, (IY+UserArea.tib_len)
        LD      D, (IY+UserArea.tib_len+1)      ; DE = tib_len
        LD      A, (IY+UserArea.tib_in)
        LD      C, A
        LD      A, (IY+UserArea.tib_in+1)
        LD      B, A                             ; BC = >IN
        EX      DE, HL                           ; DE = parse pos, HL = tib_len
        OR      A
        SBC     HL, BC                           ; HL = remaining = tib_len - >IN
        LD      B, H
        LD      C, L                             ; BC = remaining
        EX      DE, HL                           ; HL = parse pos, DE = remaining(unused)
        ; BC = remaining count, HL = current parse position

        ; Skip leading delimiters
        LD      A, (.word_delim)
        LD      D, A                             ; D = delimiter for fast access
.word_skip:
        LD      A, B
        OR      C
        JR      Z, .word_empty                   ; No chars left — empty token
        LD      A, (HL)
        CP      D                                ; Compare with delimiter
        JR      NZ, .word_found                  ; Found non-delimiter
        INC     HL
        DEC     BC
        ; Update >IN
        PUSH    HL
        PUSH    BC
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     BC
        POP     HL
        JR      .word_skip

.word_empty:
        ; No token found — return counted string with count = 0 at HERE
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)          ; HL = HERE
        LD      (HL), 0                           ; count = 0
        ; Stage HERE (new TOS) through param stack across exit EXX
        PUSH    HL
        EXX                                       ; Restore IP from shadow
        POP     BC                                ; BC = HERE (c-addr, new TOS)
        NEXT

.word_found:
        ; HL = start of token, BC = remaining, D = delimiter
        ; Get HERE address — destination for counted string
        PUSH    HL                                ; Save token start
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)           ; HL = HERE
        LD      (.word_here), HL                   ; Save HERE for return
        INC     HL                                 ; HL = HERE+1 (past count byte)
        POP     DE                                 ; DE = token start
        ; DE = source (TIB), HL = dest (HERE+1), BC = remaining
        ; Delimiter is in .word_delim scratch (D was overwritten by POP DE)
        LD      A, 0                               ; count = 0

.word_copy:
        ; Check remaining
        PUSH    AF                                 ; Save count
        LD      A, B
        OR      C
        JR      Z, .word_done_copy
        ; Check delimiter
        PUSH    HL                                 ; Save dest
        LD      A, (.word_delim)
        LD      H, A                               ; H = delimiter temporarily
        LD      A, (DE)                            ; A = source char
        CP      H                                  ; delimiter?
        POP     HL                                 ; Restore dest
        JR      Z, .word_done_delim
        ; Copy char
        LD      (HL), A
        INC     HL
        INC     DE
        DEC     BC
        ; Increment >IN
        PUSH    HL
        PUSH    BC
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     BC
        POP     HL
        POP     AF                                 ; Restore count
        INC     A                                  ; count++
        JR      .word_copy

.word_done_delim:
        ; Skip one trailing delimiter — advance >IN
        PUSH    HL
        PUSH    BC
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     BC
        POP     HL
        POP     AF                                 ; count
        JR      .word_finish

.word_done_copy:
        POP     AF                                 ; count
        ; Fall through to finish

.word_finish:
        ; A = count, store at HERE
        LD      HL, (.word_here)
        LD      (HL), A                            ; Store count byte
        ; Stage HERE (new TOS) through param stack across exit EXX
        PUSH    HL
        EXX                                        ; Restore IP from shadow
        POP     BC                                 ; BC = HERE (c-addr, new TOS)
        NEXT

; === WORD scratch storage ===
.word_delim:    DB      0
.word_here:     DW      0

; -----------------------------------------------
; CHAR ( "<spaces>name" -- char )
;   Parse next space-delimited word, return ASCII value of first char
; -----------------------------------------------
w_CHAR:
        DEFCODE "CHAR", 0
w_CHAR_cf:
        ; Stack effect: ( -- char ) — push new value
        PUSH    BC              ; Save old TOS (grows stack by 1)
        EXX                     ; Park IP in DE'; main BC/DE/HL = free scratch

        ; Compute parse_ptr = tib_addr + tib_in in HL; keep tib_in in BC for reuse
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)       ; HL = tib_in
        LD      C, L
        LD      B, H                             ; BC = tib_in (retained for remaining calc)
        LD      E, (IY+UserArea.tib_addr)
        LD      D, (IY+UserArea.tib_addr+1)     ; DE = tib_addr
        ADD     HL, DE                           ; HL = tib_addr + tib_in = parse_ptr

        ; Compute remaining = tib_len - tib_in in BC (park parse_ptr in DE)
        EX      DE, HL                           ; DE = parse_ptr, HL = tib_addr (discarded)
        LD      L, (IY+UserArea.tib_len)
        LD      H, (IY+UserArea.tib_len+1)      ; HL = tib_len
        OR      A
        SBC     HL, BC                           ; HL = tib_len - tib_in = remaining
        LD      B, H
        LD      C, L                             ; BC = remaining
        EX      DE, HL                           ; HL = parse_ptr (DE now remaining — discarded)

        ; Skip leading spaces
.char_skip:
        LD      A, B
        OR      C
        JR      Z, .char_empty                   ; No chars left
        LD      A, (HL)
        CP      ' '
        JR      NZ, .char_found
        INC     HL
        DEC     BC
        JR      .char_skip

.char_found:
        ; HL = first char of token
        LD      A, (HL)                          ; A = first char
        LD      D, A                             ; D = stashed char (survives scan)

        ; Skip rest of token to advance parse_ptr past it
.char_scan:
        INC     HL
        DEC     BC
        LD      A, B
        OR      C
        JR      Z, .char_finish                  ; End of input
        LD      A, (HL)
        CP      ' '
        JR      NZ, .char_scan                   ; Still in token
        JR      .char_finish

.char_empty:
        ; No token found — char = 0. HL is live parse_ptr; .char_finish relies
        ; on it to compute new tib_in, so no instructions may clobber HL here.
        LD      D, 0

.char_finish:
        ; HL = final parse_ptr; D = char value (ASCII or 0)
        ; Compute new tib_in = HL - tib_addr and write back
        LD      A, D                             ; A = char (preserved through rest)
        LD      E, (IY+UserArea.tib_addr)
        LD      D, (IY+UserArea.tib_addr+1)     ; DE = tib_addr (D now clobbered)
        OR      A                                ; clear carry (A unchanged)
        SBC     HL, DE
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H

        EXX                                      ; Restore IP to main DE
        LD      C, A                             ; A survived EXX — build new TOS
        LD      B, 0
        NEXT

; -----------------------------------------------
; char_to_digit — Internal helper
;   Convert ASCII char to digit value using current BASE
;   Input: A = ASCII character
;   Output: A = digit value (0-35), Carry clear = valid
;           Carry set = invalid (digit >= BASE or non-digit)
;   Clobbers: F
; -----------------------------------------------
char_to_digit:
        CP      '0'
        JR      C, .ctd_invalid         ; < '0' → invalid
        CP      '9' + 1
        JR      C, .ctd_numeric         ; '0'-'9' → digit = char - '0'
        ; Try A-Z / a-z
        AND     0xDF                    ; Force uppercase (clear bit 5)
        CP      'A'
        JR      C, .ctd_invalid         ; < 'A' → invalid
        CP      'Z' + 1
        JR      NC, .ctd_invalid        ; > 'Z' → invalid
        SUB     'A' - 10               ; A=10, B=11, etc.
        JR      .ctd_check_base
.ctd_numeric:
        SUB     '0'                     ; A = 0-9
.ctd_check_base:
        ; A = digit value, check against BASE
        PUSH    HL
        LD      L, (IY+UserArea.base)
        LD      H, A                    ; H = digit, L = BASE (low byte only for bases <= 36)
        LD      A, H
        CP      L                       ; digit >= BASE?
        POP     HL
        JR      NC, .ctd_invalid        ; digit >= BASE → invalid (carry clear from CP means >=)
        ; Valid: A = digit, carry clear
        OR      A                       ; Clear carry (A is already the digit)
        RET
.ctd_invalid:
        SCF                             ; Set carry = invalid
        RET

; -----------------------------------------------
; do_number — Internal helper
;   Convert string to number using BASE
;   Input:  HL = string address, B = char count, DE = accumulator
;   Output: DE = result, HL = advanced string addr, B = remaining count
;   Clobbers: A, F, C (caller must save IP before calling)
; -----------------------------------------------
do_number:
.do_num_loop:
        LD      A, B
        OR      A
        RET     Z               ; No chars left
        LD      A, (HL)
        CALL    char_to_digit
        RET     C               ; Invalid digit — stop
        ; A = digit value. Multiply accumulator (DE) by BASE and add digit.
        ; DE = DE * BASE + A
        PUSH    AF              ; Save digit
        PUSH    HL              ; Save string pointer
        ; Multiply DE by BASE
        LD      L, (IY+UserArea.base)
        LD      H, 0            ; HL = BASE
        ; DE = DE * HL using shift-and-add
        PUSH    BC              ; Save count
        EX      DE, HL          ; HL = accumulator, DE = BASE
        LD      C, L
        LD      B, H            ; BC = accumulator
        LD      HL, 0           ; HL = result
        LD      A, 16           ; 16 bits
.mul_loop:
        ADD     HL, HL          ; result <<= 1
        SLA     C
        RL      B               ; multiplier (BC) <<= 1, carry = high bit
        JR      NC, .mul_skip
        ADD     HL, DE          ; result += BASE
.mul_skip:
        DEC     A
        JR      NZ, .mul_loop
        ; HL = accumulator * BASE
        EX      DE, HL          ; DE = result
        POP     BC              ; Restore count (B = remaining)
        POP     HL              ; Restore string pointer
        POP     AF              ; Restore digit
        ; Add digit to DE
        LD      C, A
        LD      A, E
        ADD     A, C
        LD      E, A
        JR      NC, .no_carry
        INC     D
.no_carry:
        INC     HL              ; Next char
        DEC     B               ; Remaining--
        JR      .do_num_loop

; -----------------------------------------------
; >NUMBER ( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )
;   Accumulate digits from c-addr1 into 32-bit ud per current BASE.
;   Stops at the first non-digit (char_to_digit carry-set). Each
;   iteration performs ud ← ud × BASE + digit with full carry
;   propagation across both cells.
;   antforth implementation limit: u1 is truncated to 8 bits (count fits
;   in .tonum_count byte). Strings longer than 255 characters process
;   only the first 255; u2 reflects the 8-bit remaining count.
; ANS Forth 1994 §6.1.0570   >NUMBER   — accumulate digits into 32-bit ud per BASE
; -----------------------------------------------
w_TO_NUMBER:
        DEFCODE ">NUMBER", 0
w_TO_NUMBER_cf:
        ; Stack on entry:
        ;   BC = u1 (TOS, count)
        ;   SP+0 = c-addr1
        ;   SP+2 = ud1-low
        ;   SP+4 = ud1-high
        CALL    check_underflow_4       ; need 4 user cells (BC + 3 SP)
        LD      A, C                    ; stash count low byte (8-bit limit
        LD      (.tonum_count), A       ;  — see header comment)
        EXX                             ; save TOS/IP/W to shadows
        POP     HL
        LD      (.tonum_ptr), HL        ; c-addr1
        POP     HL
        LD      (.tonum_ud_lo), HL      ; ud1-low
        POP     HL
        LD      (.tonum_ud_hi), HL      ; ud1-high

.tonum_loop:
        LD      A, (.tonum_count)
        OR      A
        JR      Z, .tonum_done

        LD      HL, (.tonum_ptr)
        LD      A, (HL)
        CALL    char_to_digit
        JR      C, .tonum_done          ; invalid → stop
        LD      (.tonum_digit), A

        INC     HL
        LD      (.tonum_ptr), HL
        LD      A, (.tonum_count)
        DEC     A
        LD      (.tonum_count), A

        ; result (DE:HL) = ud × BASE, via 8-iter shift-and-add.
        ; Each iter: result <<= 1; if top bit of remaining BASE byte set, result += ud.
        LD      A, (IY+UserArea.base)
        LD      B, A                    ; B = BASE bits (MSB-first consumption)
        LD      C, 8                    ; C = loop counter
        LD      HL, 0                   ; result low
        LD      DE, 0                   ; result high
.tonum_mul:
        ADD     HL, HL                  ; result <<= 1 (HL carry out → E)
        RL      E
        RL      D                       ; carry-propagate through high cell
        SLA     B                       ; carry = next high bit of BASE
        JR      NC, .tonum_mul_skip
        PUSH    BC                      ; save loop state (B=BASE rem, C=counter)
        LD      BC, (.tonum_ud_lo)
        ADD     HL, BC                  ; result_lo += ud_lo
        LD      BC, (.tonum_ud_hi)      ; LD preserves carry
        EX      DE, HL
        ADC     HL, BC                  ; result_hi += ud_hi + carry
        EX      DE, HL
        POP     BC
.tonum_mul_skip:
        DEC     C
        JR      NZ, .tonum_mul
        ; DE:HL = ud × BASE

        ; result += digit (low-cell add, carry ripples into high cell)
        LD      A, (.tonum_digit)
        ADD     A, L
        LD      L, A
        JR      NC, .tonum_add_done
        INC     H
        JR      NZ, .tonum_add_done
        INC     E
        JR      NZ, .tonum_add_done
        INC     D
.tonum_add_done:
        LD      (.tonum_ud_lo), HL
        LD      (.tonum_ud_hi), DE
        JR      .tonum_loop

.tonum_done:
        ; Push ud2-low, ud2-high, c-addr2 — high cell ends up second-on-
        ; stack-just-under-c-addr2 per ANS Forth 1994 §3.1.4.1 (hi-on-TOS).
        ; After EXX + BC=u2: stack picture is
        ; ( ud2-lo ud2-hi c-addr2 u2 ) with u2=BC=TOS.
        LD      HL, (.tonum_ud_lo)
        PUSH    HL
        LD      HL, (.tonum_ud_hi)
        PUSH    HL
        LD      HL, (.tonum_ptr)
        PUSH    HL
        EXX                             ; restore IP (DE) from shadow
        LD      A, (.tonum_count)
        LD      C, A
        LD      B, 0                    ; BC = u2 (remaining count, TOS)
        NEXT

; >NUMBER scratch storage
.tonum_count:   DB      0
.tonum_digit:   DB      0
.tonum_ptr:     DW      0
.tonum_ud_lo:   DW      0
.tonum_ud_hi:   DW      0

; -----------------------------------------------
; NUMBER? ( c-addr -- n true | c-addr false )
;   Try to convert counted string to a number
;   Returns n and TRUE if successful, original c-addr and FALSE if not
; -----------------------------------------------
w_NUMBER_Q:
        DEFCODE "NUMBER?", 0
w_NUMBER_Q_cf:
        ; -3 THROW guard. NUMBER? grows the data stack
        ; by 1 cell on BOTH the success path (n + true) and the fail
        ; path (c-addr + false), so guard at entry covers both.
        CALL    check_overflow
        ; BC = c-addr (TOS, points to counted string)
        ; Stage c-addr into main HL while saving TOS/IP/W to shadows.
        ; Shadow BC' implicitly preserves original c-addr for the fail path.
        PUSH    BC              ; save c-addr on param stack
        EXX                     ; save TOS/IP/W; shadow BC' = c-addr_orig
        POP     HL              ; HL = c-addr (main)

        ; Load count byte
        LD      A, (HL)
        OR      A
        JR      Z, .numq_fail  ; count = 0 → fail

        INC     HL              ; HL = name start (past count byte)
        LD      B, A            ; B = count

        ; Check for leading '-'
        XOR     A               ; A = 0 (negate flag = false)
        LD      (.numq_negate), A
        LD      A, (HL)
        CP      '-'
        JR      NZ, .numq_convert
        ; Leading '-': set negate flag
        LD      A, 1
        LD      (.numq_negate), A
        INC     HL              ; Skip '-'
        DEC     B               ; One less char
        JR      Z, .numq_fail  ; Bare "-" → fail

.numq_convert:
        ; 32-bit dot-aware accumulator (ANS Forth 1994 §3.4.1.3). For
        ; unprefixed digit strings, base is BASE (UserArea). saw_dot=0 →
        ; single-cell single (flag=0xFFFF, DPL=-1); saw_dot=1 →
        ; double-cell (flag=2, DPL=digits-after-dot).
        CALL    do_double_dot_user
        JR      C, .numq_fail   ; multi-dot or invalid digit
        LD      A, B
        OR      A
        JR      NZ, .numq_fail  ; Remaining chars → fail

        ; Branch on saw_dot for sign-apply + push.
        LD      A, (dlit_saw_dot)
        OR      A
        JR      NZ, .numq_double

.numq_single:
        ; Single-cell: apply sign if flagged, push value, flag = 0xFFFF
        LD      A, (.numq_negate)
        OR      A
        CALL    NZ, dlit_negate ; 32-bit negate; high cell remains 0 from
                                ; init so 16-bit sign result lives in
                                ; (dlit_acc_lo) low cell as expected
        ; DPL = -1
        LD      HL, -1
        LD      (IY+UserArea.dpl),   L
        LD      (IY+UserArea.dpl+1), H
        LD      HL, (dlit_acc_lo)
        PUSH    HL              ; n as NOS
        EXX                     ; restore IP to main DE
        LD      BC, 0xFFFF      ; flag = TRUE (single)
        NEXT

.numq_double:
        ; Double-cell: apply 32-bit sign, write DPL, push low+high, flag=2.
        ; High cell on TOS per ANS Forth 1994 §3.1.4.1.
        LD      A, (.numq_negate)
        OR      A
        CALL    NZ, dlit_negate
        LD      A, (dlit_dpl)
        LD      (IY+UserArea.dpl),   A
        XOR     A
        LD      (IY+UserArea.dpl+1), A
        LD      HL, (dlit_acc_lo)
        PUSH    HL              ; second-on-stack (low)
        LD      HL, (dlit_acc_hi)
        PUSH    HL              ; would-be-TOS (high)
        EXX                     ; restore IP to main DE
        LD      BC, 2           ; flag = 2 (double)
        NEXT

.numq_fail:
        ; Shadow BC' still holds original c-addr — EXX brings it back to main BC
        EXX                     ; Restore IP; main BC = c-addr_orig
        PUSH    BC              ; Push c-addr as NOS
        LD      BC, 0           ; FALSE (new TOS)
        NEXT

.numq_negate:   DB      0

; -----------------------------------------------
; (S") ( -- c-addr u ) runtime
;   Push address and length of inline counted string from thread.
;   IP (DE) points to count byte; advances IP past string + alignment.
; -----------------------------------------------
w_PAREN_S_QUOTE:
        DEFCODE '(S")', 0
w_PAREN_S_QUOTE_cf:
        ; Save old TOS
        PUSH    BC
        ; DE = IP, points to count byte
        LD      A, (DE)         ; A = count
        LD      C, A
        LD      B, 0            ; BC = u (new TOS)
        ; c-addr = DE + 1
        INC     DE
        PUSH    DE              ; push c-addr (second on stack)
        ; Advance IP past string: DE = DE + count
        ADD     A, E
        LD      E, A
        JR      NC, .sq_rt_nc
        INC     D
.sq_rt_nc:
        ; Cell-align: if DE is odd, increment by 1
        BIT     0, E
        JR      Z, .sq_rt_aligned
        INC     DE
.sq_rt_aligned:
        ; DE = new IP
        NEXT

; -----------------------------------------------
; compile_string — Internal subroutine shared by S" and ."
;   Compiles (S") xt + inline counted string at HERE.
;   Reads characters from TIB at >IN until closing '"'.
;   Skips one leading space per ANS S" spec.
;   Input:  IP saved by caller; IY = user area
;   Output: HERE updated past string + alignment
;   Clobbers: A, HL, BC, DE (caller saves IP)
; -----------------------------------------------
compile_string:
        ; Compile (S") xt at HERE
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (HL), LOW w_PAREN_S_QUOTE_cf
        INC     HL
        LD      (HL), HIGH w_PAREN_S_QUOTE_cf
        INC     HL
        ; HL = address for count byte
        PUSH    HL              ; save count_addr
        INC     HL              ; HL = first char destination

        ; Compute source pointer: TIB + >IN
        LD      E, (IY+UserArea.tib_in)
        LD      D, (IY+UserArea.tib_in+1)   ; DE = >IN
        PUSH    HL              ; save dest
        LD      L, (IY+UserArea.tib_addr)
        LD      H, (IY+UserArea.tib_addr+1)  ; HL = tib_addr
        ADD     HL, DE          ; HL = source = tib_addr + >IN
        ; Save source in scratch, get dest back
        LD      (cs_src), HL
        POP     HL              ; HL = dest

        ; Skip one leading space (per ANS S" spec)
        PUSH    HL              ; save dest
        LD      HL, (cs_src)
        LD      A, (HL)
        CP      ' '
        JR      NZ, .cs_no_skip
        INC     HL
        LD      (cs_src), HL
        ; Advance >IN by 1
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
.cs_no_skip:
        POP     HL              ; HL = dest

        ; Compute remaining = tib_len - >IN (16-bit safe)
        LD      A, (IY+UserArea.tib_len)
        SUB     (IY+UserArea.tib_in)
        LD      C, A
        LD      A, (IY+UserArea.tib_len+1)
        SBC     A, (IY+UserArea.tib_in+1)
        ; A:C = remaining (16-bit); use C (low byte) as counter
        ; If high byte non-zero, clamp C to 255 (max practical TIB)
        OR      A
        JR      Z, .cs_rem_ok
        LD      C, 255
.cs_rem_ok:
        LD      B, 0            ; B = char count

        ; Copy loop: source in (cs_src), dest in HL, remaining in C, count in B
.cs_copy:
        LD      A, C
        OR      A
        JR      Z, .cs_done     ; end of input
        PUSH    HL              ; save dest
        LD      HL, (cs_src)
        LD      A, (HL)
        INC     HL
        LD      (cs_src), HL
        POP     HL              ; restore dest
        DEC     C               ; remaining--
        ; Advance >IN
        PUSH    HL
        PUSH    AF
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     AF
        POP     HL
        CP      '"'
        JR      Z, .cs_done     ; closing quote found
        ; Copy character
        LD      (HL), A
        INC     HL
        INC     B               ; count++
        JR      .cs_copy

.cs_done:
        ; B = string length, HL = past last char
        ; Write count byte
        POP     DE              ; DE = count_addr (saved earlier)
        LD      A, B
        LD      (DE), A         ; store count byte

        ; Cell-align HL: if odd, pad with 0 and advance
        BIT     0, L
        JR      Z, .cs_aligned
        LD      (HL), 0         ; padding byte
        INC     HL
.cs_aligned:
        ; Update HERE
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        RET

; compile_string scratch
cs_src:         DW 0

; -----------------------------------------------
; S" ( -- c-addr u ) IMMEDIATE
;   Compile mode: compile (S") + inline string
;   Interpret mode: copy string to transient buffer, push c-addr u
; -----------------------------------------------
w_S_QUOTE:
        DEFCODE 'S"', F_IMMEDIATE
w_S_QUOTE_cf:
        ; Save DE (IP) to scratch cell
        LD      (sq_saved_ip), DE

        ; Check STATE
        LD      A, (IY+UserArea.state)
        OR      (IY+UserArea.state+1)
        JR      Z, .sq_interpret

        ; === Compile mode ===
        PUSH    BC              ; save TOS (not used, but must preserve)
        CALL    compile_string
        POP     BC              ; restore TOS
        ; Restore IP
        LD      DE, (sq_saved_ip)
        NEXT

.sq_interpret:
        ; === Interpret mode ===
        ; Parse string to transient buffer (s_quote_buf)
        PUSH    BC              ; save old TOS

        ; Compute source: TIB + >IN
        LD      E, (IY+UserArea.tib_in)
        LD      D, (IY+UserArea.tib_in+1)
        LD      L, (IY+UserArea.tib_addr)
        LD      H, (IY+UserArea.tib_addr+1)
        ADD     HL, DE          ; HL = source

        ; Skip one leading space
        LD      A, (HL)
        CP      ' '
        JR      NZ, .sq_i_no_skip
        INC     HL
        ; Advance >IN
        PUSH    HL
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     HL
.sq_i_no_skip:
        ; HL = source, DE = dest (s_quote_buf)
        LD      DE, s_quote_buf
        ; Compute remaining = tib_len - >IN (16-bit safe)
        LD      A, (IY+UserArea.tib_len)
        SUB     (IY+UserArea.tib_in)
        LD      C, A
        LD      A, (IY+UserArea.tib_len+1)
        SBC     A, (IY+UserArea.tib_in+1)
        ; Clamp to 255 if high byte non-zero
        OR      A
        JR      Z, .sq_i_rem_ok
        LD      C, 255
.sq_i_rem_ok:
        LD      B, 0            ; B = char count

.sq_i_copy:
        LD      A, C
        OR      A
        JR      Z, .sq_i_done
        LD      A, (HL)
        INC     HL
        DEC     C
        ; Advance >IN
        PUSH    HL
        PUSH    AF
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     AF
        POP     HL
        CP      '"'
        JR      Z, .sq_i_done
        ; Bounds check: B < 255 to prevent buffer overrun
        PUSH    AF
        LD      A, B
        CP      255
        JR      NC, .sq_i_done_pop
        POP     AF
        LD      (DE), A
        INC     DE
        INC     B
        JR      .sq_i_copy

.sq_i_done_pop:
        POP     AF              ; discard saved char
.sq_i_done:
        ; Push c-addr (s_quote_buf) and u (count)
        LD      HL, s_quote_buf
        PUSH    HL              ; push c-addr (under TOS)
        LD      C, B
        LD      B, 0            ; BC = u (new TOS)

        ; Restore IP
        LD      DE, (sq_saved_ip)
        NEXT

; S" scratch storage
sq_saved_ip:    DW 0
s_quote_buf:    DS 258          ; transient buffer for interpret mode (256 chars + safety)

; -----------------------------------------------
; ." ( -- ) IMMEDIATE
;   Compile mode: compile (S") + inline string + TYPE
;   Interpret mode: parse and print string immediately
;
;   Interpret-mode tail at .dq_interpret saves the caller's TOS
;   across the parse-and-print work via PUSH BC at entry / POP BC at
;   .dq_i_end exit. The loop counter `C` is loaded with the
;   remaining-TIB byte-count (LD C, A at .dq_i_rem_ok) and decremented
;   on every iteration (DEC C inside .dq_i_loop), which would destroy
;   BC (the TOS-in-register cell per docs/register-conventions.md)
;   without the save — violating ANS §6.1.0190 ( -- ) net stack
;   effect for any interpret-mode invocation (REPL, INCLUDED top-level,
;   EVALUATE outside a colon body). This mirrors the compile-mode tail
;   of this same word (PUSH BC / POP BC around compile_string) and the
;   interpret-mode tail of S" (PUSH BC at entry).
;
;   The in-loop PUSH BC / POP BC envelopes (>IN advance, and
;   bdos_putchar) are unrelated: they save the loop COUNTER state of
;   BC across helper-clobbering inner code; the function-level outer
;   envelope saves the original-TOS state at a strictly outer scope.
;   Two scopes, one register pair, no conflict.
; -----------------------------------------------
w_DOT_QUOTE:
        DEFCODE '."', F_IMMEDIATE
w_DOT_QUOTE_cf:
        ; Save DE (IP) to scratch cell
        LD      (dq_saved_ip), DE

        ; Check STATE
        LD      A, (IY+UserArea.state)
        OR      (IY+UserArea.state+1)
        JR      Z, .dq_interpret

        ; === Compile mode ===
        PUSH    BC              ; save TOS
        CALL    compile_string
        ; Compile TYPE xt after the string
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (HL), LOW w_TYPE_cf
        INC     HL
        LD      (HL), HIGH w_TYPE_cf
        INC     HL
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        POP     BC              ; restore TOS

        ; Restore IP
        LD      DE, (dq_saved_ip)
        NEXT

.dq_interpret:
        ; === Interpret mode: parse string and print directly ===
        PUSH    BC              ; save TOS across interpret-mode work
        ; Compute source: TIB + >IN
        LD      E, (IY+UserArea.tib_in)
        LD      D, (IY+UserArea.tib_in+1)
        LD      L, (IY+UserArea.tib_addr)
        LD      H, (IY+UserArea.tib_addr+1)
        ADD     HL, DE          ; HL = source

        ; Skip one leading space
        LD      A, (HL)
        CP      ' '
        JR      NZ, .dq_i_no_skip
        INC     HL
        PUSH    HL
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     HL
.dq_i_no_skip:
        ; Compute remaining = tib_len - >IN (16-bit safe)
        LD      A, (IY+UserArea.tib_len)
        SUB     (IY+UserArea.tib_in)
        LD      C, A
        LD      A, (IY+UserArea.tib_len+1)
        SBC     A, (IY+UserArea.tib_in+1)
        OR      A
        JR      Z, .dq_i_rem_ok
        LD      C, 255
.dq_i_rem_ok:
        ; HL = source, C = remaining
.dq_i_loop:
        LD      A, C
        OR      A
        JR      Z, .dq_i_end
        LD      A, (HL)
        INC     HL
        DEC     C
        ; Advance >IN
        PUSH    HL
        PUSH    AF
        PUSH    BC
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     BC
        POP     AF
        POP     HL
        CP      '"'
        JR      Z, .dq_i_end
        ; Print character via BDOS
        PUSH    HL
        PUSH    BC
        LD      E, A
        CALL    bdos_putchar
        POP     BC
        POP     HL
        JR      .dq_i_loop

.dq_i_end:
        POP     BC              ; restore TOS
        ; Restore IP
        LD      DE, (dq_saved_ip)
        NEXT

; ." scratch storage
dq_saved_ip:    DW 0

; -----------------------------------------------
; \ ( -- ) IMMEDIATE
;   Line comment: consume rest of parse area
;   Sets >IN = #TIB so remainder of input is ignored
; -----------------------------------------------
w_BACKSLASH:
        DEFCODE '\', F_IMMEDIATE
w_BACKSLASH_cf:
        ; Set >IN = #TIB (consume rest of line)
        LD      A, (IY+UserArea.tib_len)
        LD      (IY+UserArea.tib_in), A
        LD      A, (IY+UserArea.tib_len+1)
        LD      (IY+UserArea.tib_in+1), A
        NEXT

; -----------------------------------------------
; ( ( -- ) IMMEDIATE
;   Paren comment: consume input up to and including next ')'
;   Raises -58 THROW (unexpected end of input) per ANS Forth 1994
;   §9.3.5 if ')' not found before end of input. The syntactic
;   specificity of a "? missing )" message is lost in the unified
;   `error -58: unexpected end of input` diagnostic; the trade is
;   deliberate (mirrors ?COMP's "? compile only" → -14 migration).
;   A future refactor could re-introduce a (-specific extension code
;   if the syntactic clarity proves valuable.
; -----------------------------------------------
w_PAREN:
        DEFCODE "(", F_IMMEDIATE
w_PAREN_cf:
        ; Save TOS/IP/W via shadows. Shadow BC' implicitly preserves the
        ; original TOS for free, so no explicit `PUSH BC` is needed
        ; (matches the COLON/CREATE/CONSTANT convention for `( -- )` words).
        EXX

        ; Compute HL = tib_addr + >IN, BC = tib_len - >IN
        LD      E, (IY+UserArea.tib_addr)
        LD      D, (IY+UserArea.tib_addr+1)     ; DE = tib_addr
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)       ; HL = >IN
        ADD     HL, DE                           ; HL = tib_addr + >IN

        LD      A, (IY+UserArea.tib_len)
        SUB     (IY+UserArea.tib_in)
        LD      C, A
        LD      A, (IY+UserArea.tib_len+1)
        SBC     A, (IY+UserArea.tib_in+1)
        LD      B, A                             ; BC = remaining = tib_len - >IN

.paren_scan:
        ; Check if any chars remaining
        LD      A, B
        OR      C
        JR      Z, .paren_missing               ; No chars left — missing ')'

        LD      A, (HL)
        INC     HL
        DEC     BC

        ; Advance >IN
        PUSH    HL
        PUSH    BC
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     BC
        POP     HL

        CP      ')'
        JR      NZ, .paren_scan                  ; Not ')' — keep scanning

        ; Found ')' — restore IP via EXX; main BC ← shadow BC' = original TOS
        EXX
        NEXT

.paren_missing:
        EXX                              ; Restore primary set (kernel-internal
                                         ; THROW entry contract; matches the
                                         ; :/CREATE/CONSTANT/MARKER pattern)
        ; -58 THROW: unexpected end of input per ANS Forth 1994 §9.3.5.
        ; The unified `error -58: unexpected end of input` diagnostic from
        ; throw_desc_table replaces a syntactically specific "? missing )"
        ; message; the trade is deliberate per the unified-diagnostic
        ; discipline (mirrors ?COMP's "? compile only" → -14 migration).
        LD      BC, THROW_END_OF_INPUT
        JP      w_THROW_cf.kernel_entry
