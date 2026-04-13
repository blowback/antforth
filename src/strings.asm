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
        ; Save DE (IP) to return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D

        ; Save delimiter in scratch
        LD      A, C
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
        LD      B, H
        LD      C, L                              ; BC = HERE (c-addr, new TOS)
        ; Restore DE (IP) from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
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
        LD      B, H
        LD      C, L                               ; BC = HERE (c-addr, new TOS)
        ; Restore DE (IP) from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
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

        ; Save DE (IP) to return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D

        ; Parse next space-delimited token from TIB
        ; Load parse state: HL = tib_addr + >IN
        LD      E, (IY+UserArea.tib_addr)
        LD      D, (IY+UserArea.tib_addr+1)     ; DE = tib_addr
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)       ; HL = >IN
        ADD     HL, DE                           ; HL = tib_addr + >IN

        ; Compute remaining = tib_len - >IN
        LD      E, (IY+UserArea.tib_len)
        LD      D, (IY+UserArea.tib_len+1)      ; DE = tib_len
        LD      A, (IY+UserArea.tib_in)
        LD      C, A
        LD      A, (IY+UserArea.tib_in+1)
        LD      B, A                             ; BC = >IN
        PUSH    HL                               ; Save parse pos
        EX      DE, HL                           ; HL = tib_len
        OR      A
        SBC     HL, BC                           ; HL = remaining
        LD      B, H
        LD      C, L                             ; BC = remaining
        POP     HL                               ; HL = parse pos

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
        PUSH    HL
        PUSH    BC
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     BC
        POP     HL
        JR      .char_skip

.char_found:
        ; HL = first char of token
        LD      A, (HL)         ; A = first char — save it
        LD      (.char_result), A

        ; Skip rest of token to advance >IN past it
.char_scan:
        INC     HL
        DEC     BC
        PUSH    HL
        PUSH    BC
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     BC
        POP     HL
        LD      A, B
        OR      C
        JR      Z, .char_finish                  ; End of input
        LD      A, (HL)
        CP      ' '
        JR      NZ, .char_scan                   ; Still in token

        JR      .char_finish

.char_empty:
        ; No token found — return 0
        XOR     A
        LD      (.char_result), A

.char_finish:
        ; Set BC = char value (new TOS)
        LD      A, (.char_result)
        LD      C, A
        LD      B, 0

        ; Restore DE (IP) from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        NEXT

.char_result:   DB 0

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
;   Convert string to number using BASE
;   Processes left to right, stops at first non-digit
;   ud is double-cell; high cell passed through unchanged (MVP)
; -----------------------------------------------
w_TO_NUMBER:
        DEFCODE ">NUMBER", 0
w_TO_NUMBER_cf:
        ; Stack: BC = u1 (TOS), (SP) = c-addr1, ud1-low, ud1-high
        ; Save DE (IP) to return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D

        ; Get arguments
        LD      B, C            ; B = count (u1, only low byte matters for reasonable strings)
        POP     HL              ; HL = c-addr1
        ; Stack: ud1-low, ud1-high

        POP     DE              ; DE = ud1-low (accumulator for do_number)
        ; Stack: ud1-high

        CALL    do_number

        ; DE = result (ud2-low), B = remaining count, HL = advanced pointer
        ; Stack: ud1-high (becomes ud2-high, unchanged)

        ; Push results: ud2-low, c-addr2, u2
        PUSH    DE              ; ud2-low
        PUSH    HL              ; c-addr2

        LD      C, B
        LD      B, 0            ; BC = u2 (remaining count, TOS)

        ; Restore DE (IP) from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        NEXT

; -----------------------------------------------
; NUMBER? ( c-addr -- n true | c-addr false )
;   Try to convert counted string to a number
;   Returns n and TRUE if successful, original c-addr and FALSE if not
; -----------------------------------------------
w_NUMBER_Q:
        DEFCODE "NUMBER?", 0
w_NUMBER_Q_cf:
        ; BC = c-addr (TOS, points to counted string)
        ; Save DE (IP) to return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D

        ; Save original c-addr for failure return
        PUSH    BC              ; Stack: [c-addr_orig]

        ; Load count byte
        LD      A, (BC)
        OR      A
        JR      Z, .numq_fail  ; count = 0 → fail

        INC     BC              ; BC = name start (past count byte)
        LD      H, B
        LD      L, C            ; HL = name start
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
        ; HL = string, B = count, DE = accumulator
        LD      DE, 0
        CALL    do_number
        ; DE = result, B = remaining

        LD      A, B
        OR      A
        JR      NZ, .numq_fail ; Remaining chars → not fully converted → fail

        ; Success — negate if needed
        LD      A, (.numq_negate)
        OR      A
        JR      Z, .numq_ok
        ; Negate DE: DE = 0 - DE
        LD      A, E
        CPL
        LD      E, A
        LD      A, D
        CPL
        LD      D, A
        INC     DE              ; Two's complement

.numq_ok:
        ; Stack: [c-addr_orig]
        POP     AF              ; Discard original c-addr
        PUSH    DE              ; Push n (second on stack)
        LD      BC, 0xFFFF      ; TRUE (TOS)
        ; Restore IP
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        NEXT

.numq_fail:
        ; Stack: [c-addr_orig]
        POP     BC              ; Restore original c-addr
        PUSH    BC              ; Push c-addr as second-on-stack
        LD      BC, 0           ; FALSE (TOS)
        ; Restore IP
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
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
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC
        POP     HL
        JR      .dq_i_loop

.dq_i_end:
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
;   Error if ')' not found before end of input
; -----------------------------------------------
w_PAREN:
        DEFCODE "(", F_IMMEDIATE
w_PAREN_cf:
        ; Save BC (TOS) to parameter stack — ( has no stack effect
        PUSH    BC

        ; Save DE (IP) to return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D

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

        ; Found ')' — restore DE (IP) and BC (TOS)
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        POP     BC              ; Restore TOS
        NEXT

.paren_missing:
        ; Print "missing )" CR LF then ABORT
        LD      HL, .paren_err_msg
        LD      B, .paren_err_len
.paren_err_print:
        PUSH    HL
        PUSH    BC
        LD      E, (HL)
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC
        POP     HL
        INC     HL
        DJNZ    .paren_err_print
        JP      w_ABORT_cf

.paren_err_msg:
        DB      "? missing )", 0x0D, 0x0A
.paren_err_len  EQU     $ - .paren_err_msg
