; io.asm — Console I/O primitives
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; EMIT ( char -- )
;   Output character to console via BDOS C_WRITE
; -----------------------------------------------
w_EMIT:
        DEFCODE "EMIT", 0
w_EMIT_cf:
        LD      A, C            ; A = char (save from TOS before BDOS clobbers)
        BDOS_SAVE               ; PUSH DE, PUSH BC
        LD      E, A            ; E = char for BDOS
        LD      C, C_WRITE      ; BDOS function 2: C_WRITE
        CALL    BDOS_ENTRY
        BDOS_RESTORE            ; POP BC, POP DE — restores IP and old TOS
        POP     BC              ; Pop new TOS (char consumed)
        NEXT

; -----------------------------------------------
; TYPE ( c-addr u -- )
;   Output u characters starting at c-addr
; -----------------------------------------------
w_TYPE:
        DEFCODE "TYPE", 0
w_TYPE_cf:
        ; BC = u (count, TOS), (SP) = c-addr
        POP     HL              ; HL = c-addr
        ; BC = count — if count is 0, skip entirely
        LD      A, B
        OR      C
        JR      Z, .type_done
        PUSH    DE              ; Save IP once outside loop
        ; Note: Manual register saves used instead of BDOS_SAVE/BDOS_RESTORE
        ; to avoid macro nesting issues — IP is saved once outside the loop,
        ; and HL/BC/DE are managed per-iteration with explicit PUSH/POP.
.type_loop:
        PUSH    HL              ; Save address
        PUSH    BC              ; Save count
        LD      A, (HL)         ; A = next char
        PUSH    DE              ; Save DE (BDOS clobbers all)
        LD      E, A
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     DE              ; Restore DE
        POP     BC              ; Restore count
        POP     HL              ; Restore address
        INC     HL              ; Next character
        DEC     BC
        LD      A, B
        OR      C
        JR      NZ, .type_loop
        POP     DE              ; Restore IP
.type_done:
        POP     BC              ; New TOS
        NEXT

; -----------------------------------------------
; CR ( -- )
;   Output carriage return + line feed
; -----------------------------------------------
w_CR:
        DEFCODE "CR", 0
w_CR_cf:
        BDOS_SAVE
        LD      E, 0x0D         ; Carriage return
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        BDOS_SAVE
        LD      E, 0x0A         ; Line feed
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        NEXT

; -----------------------------------------------
; SPACE ( -- )
;   Output a single space character
; -----------------------------------------------
w_SPACE:
        DEFCODE "SPACE", 0
w_SPACE_cf:
        BDOS_SAVE
        LD      E, 0x20         ; Space character
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        NEXT

; -----------------------------------------------
; SPACES ( n -- )
;   Output n space characters (n <= 0 is a no-op)
; -----------------------------------------------
w_SPACES:
        DEFCODE "SPACES", 0
w_SPACES_cf:
        ; BC = n (count)
        LD      A, B
        OR      A               ; Check if high byte is negative (bit 7 set)
        JP      M, .spaces_done ; n < 0, skip
        LD      A, B
        OR      C
        JR      Z, .spaces_done ; n == 0, skip
        PUSH    DE              ; Save IP
.spaces_loop:
        BDOS_SAVE               ; Saves DE (IP) and BC (count)
        LD      E, 0x20
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        BDOS_RESTORE            ; Restores BC (count) and DE (IP)
        DEC     BC
        LD      A, B
        OR      C
        JR      NZ, .spaces_loop
        POP     DE              ; Restore IP
.spaces_done:
        POP     BC              ; New TOS (n consumed)
        NEXT

; -----------------------------------------------
; KEY ( -- char )
;   Blocking console read via BDOS function 1
; -----------------------------------------------
w_KEY:
        DEFCODE "KEY", 0
w_KEY_cf:
        PUSH    BC              ; Push old TOS to make room
        BDOS_SAVE
        LD      C, C_READ       ; BDOS function 1: console input
        CALL    BDOS_ENTRY      ; A = character read
        BDOS_RESTORE            ; Restores old BC and DE (POP doesn't touch A)
        LD      C, A            ; C = char (low byte of new TOS)
        LD      B, 0            ; B = 0 (char is 0-127)
        NEXT

; -----------------------------------------------
; KEY? ( -- flag )
;   Non-blocking console status via BDOS function 11
; -----------------------------------------------
w_KEYQ:
        DEFCODE "KEY?", 0
w_KEYQ_cf:
        PUSH    BC              ; Push old TOS to make room
        BDOS_SAVE
        LD      C, C_STATUS     ; BDOS function 11: console status
        CALL    BDOS_ENTRY      ; A = 0x00 (no char) or 0xFF (char ready)
        BDOS_RESTORE            ; POP doesn't touch A — result preserved
        ; Convert BDOS result to Forth flag: 0 → 0, 0xFF → -1 (0xFFFF)
        OR      A
        JR      Z, .keyq_false
        LD      BC, 0xFFFF      ; TRUE (-1)
        NEXT
.keyq_false:
        LD      BC, 0           ; FALSE (0)
        NEXT
