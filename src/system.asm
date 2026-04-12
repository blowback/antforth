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
; MARKER ( "<spaces>name" -- )
;   Create a word that, when executed, restores dictionary state
;   to what it was just before MARKER ran.
;   Body layout: [saved_here(2)][saved_hash_table(128)]
; -----------------------------------------------
w_MARKER:
        DEFCODE "MARKER", 0
w_MARKER_cf:
        ; Save DE (IP) and BC (TOS) to return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B

        ; Build dictionary header (flags=0, no SMUDGE)
        XOR     A
        CALL    build_header
        JR      C, .marker_no_name

        ; HL = code field — emit JP DOMARKER
        LD      (HL), 0xC3              ; JP opcode
        INC     HL
        LD      (HL), LOW DOMARKER
        INC     HL
        LD      (HL), HIGH DOMARKER
        INC     HL

        ; Emit saved HERE (2 bytes) — bh_entry_start is pre-header HERE
        LD      DE, (bh_entry_start)
        LD      (HL), E
        INC     HL
        LD      (HL), D
        INC     HL

        ; Save body hash start address for fixup later
        PUSH    HL                      ; body_hash_start on stack

        ; Copy 128 bytes from hash_table to body
        ; Need LDIR: HL=src, DE=dst, BC=count
        ; Currently HL = body dest, need to swap
        EX      DE, HL                  ; DE = body dest
        LD      HL, hash_table          ; HL = source
        LD      BC, 128
        LDIR                            ; DE = past end of body

        ; Fixup: restore pre-MARKER bucket value in body copy
        ; Body hash copy starts at (saved on stack)
        ; Modified bucket = bh_bucket_index, old value = bh_old_bucket_head
        POP     HL                      ; HL = body_hash_start
        LD      A, (bh_bucket_index)
        LD      C, A
        LD      B, 0
        ADD     HL, BC
        ADD     HL, BC                  ; HL = body_hash_start + bucket_index * 2
        LD      BC, (bh_old_bucket_head)
        LD      (HL), C
        INC     HL
        LD      (HL), B

        ; Update HERE = DE (past end of body, from LDIR)
        LD      (IY+UserArea.here), E
        LD      (IY+UserArea.here+1), D

        ; Restore BC (TOS) and DE (IP) from return stack
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX
        NEXT

.marker_no_name:
        ; Restore BC (TOS) and DE (IP) from return stack
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX
        JP      w_ABORT_cf

; -----------------------------------------------
; ABORT ( -- )
;   Reset parameter stack and restart QUIT
;   Never returns
; -----------------------------------------------
w_ABORT:
        DEFCODE "ABORT", 0
w_ABORT_cf:
        CALL    asm_cleanup             ; If asm_mode set, restore HERE/bucket
        LD      HL, (sp_base)
        LD      SP, HL                  ; Reset parameter stack
        JP      w_QUIT_cf               ; Enter QUIT (resets return stack + STATE)

; -----------------------------------------------
; check_underflow — Internal subroutine (not a Forth word)
;   Verify DEPTH >= 1 (at least 1 cell on machine stack)
;   CALL pushes 2-byte return address onto SP, so at time of check
;   SP is 2 less than "real" SP. Need sp_base - SP_real >= 2,
;   i.e. sp_base - SP_measured >= 4.
;
;   On underflow: prints "? Stack underflow", calls ABORT (never returns)
;   On success: returns normally
;   Clobbers: AF, HL
;   Preserves: BC (TOS), DE (IP), IX, IY, SP
; -----------------------------------------------
check_underflow:
        LD      HL, (sp_base)
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP_measured
        JR      C, .underflow   ; sp_base < SP = corrupt, definitely underflow
        LD      A, H
        OR      A
        RET     NZ              ; HL >= 256, plenty of stack — fast exit
        LD      A, L
        CP      4               ; Need >= 4 (2 for CALL ret addr + 2 for one cell)
        RET     NC              ; HL >= 4, OK
.underflow:
        JP      do_underflow_error

; -----------------------------------------------
; check_underflow_2 — Internal subroutine (not a Forth word)
;   Verify DEPTH >= 2 (at least 2 cells on machine stack)
;   For binary ops needing 2 user items (BC + 1 POP).
;   Threshold: sp_base - SP_measured >= 6
;   (2 for CALL ret addr + 4 for two cells)
;
;   Clobbers: AF, HL
;   Preserves: BC (TOS), DE (IP), IX, IY, SP
; -----------------------------------------------
check_underflow_2:
        LD      HL, (sp_base)
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP_measured
        JR      C, .underflow2  ; sp_base < SP = corrupt
        LD      A, H
        OR      A
        RET     NZ              ; HL >= 256, plenty of stack
        LD      A, L
        CP      6               ; Need >= 6 (2 ret addr + 4 for two cells)
        RET     NC              ; HL >= 6, OK
.underflow2:
        JP      do_underflow_error

; -----------------------------------------------
; do_underflow_error — Internal subroutine (not a Forth word)
;   Print "? Stack underflow" + CR/LF via direct BDOS calls
;   then jump to ABORT. Never returns.
;   Uses direct BDOS because SP may be corrupt.
; -----------------------------------------------
do_underflow_error:
        ; Note: CALL check_underflow return addr remains on SP — harmless, ABORT resets SP
        LD      HL, str_underflow
        LD      B, STR_UNDERFLOW_LEN
.print_loop:
        LD      E, (HL)
        PUSH    HL
        PUSH    BC
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC
        POP     HL
        INC     HL
        DJNZ    .print_loop
        ; Newline
        LD      E, 0x0D
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        LD      E, 0x0A
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        ; ABORT resets SP and enters QUIT
        JP      w_ABORT_cf
