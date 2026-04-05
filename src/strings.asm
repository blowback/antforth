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
