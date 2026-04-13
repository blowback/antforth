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
; (ABORT") ( flag -- ) runtime helper
;   If flag is zero, skip inline counted string and continue.
;   If flag is non-zero, print inline string via TYPE, then ABORT.
;   Inline string format: count byte + chars + cell-alignment padding
; -----------------------------------------------
w_PAREN_ABORT_QUOTE:
        DEFCODE '(ABORT")', 0
w_PAREN_ABORT_QUOTE_cf:
        ; BC = flag (TOS)
        LD      A, B
        OR      C               ; Test if flag is zero
        POP     BC              ; Pop new TOS (consumed flag)
        JR      NZ, .paq_abort  ; Non-zero: abort with message

        ; Flag is zero: skip inline string
        ; DE = IP, points to count byte
        LD      A, (DE)         ; A = count
        INC     DE              ; DE past count byte
        ADD     A, E
        LD      E, A
        JR      NC, .paq_skip_nc
        INC     D
.paq_skip_nc:
        ; Cell-align: if DE is odd, increment by 1
        BIT     0, E
        JR      Z, .paq_skip_aligned
        INC     DE
.paq_skip_aligned:
        ; DE = new IP, past string
        NEXT

.paq_abort:
        ; Non-zero flag: print string then ABORT
        ; DE = IP = pointer to count byte
        ; Note: raw BDOS calls (not BDOS_SAVE/BDOS_RESTORE) because ABORT
        ; resets SP anyway; IP saved/restored via return stack instead.
        ; Save IP to return stack for BDOS safety
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D

        LD      A, (DE)         ; A = count
        INC     DE              ; DE = string start
        OR      A
        JR      Z, .paq_do_abort ; Empty string, just abort

        LD      B, A            ; B = count
        LD      H, D
        LD      L, E            ; HL = string address
        CALL    bdos_print_str

.paq_do_abort:
        ; Restore return stack (not strictly needed since ABORT resets everything,
        ; but keep it clean)
        INC     IX
        INC     IX
        JP      w_ABORT_cf      ; ABORT (never returns)

; -----------------------------------------------
; ABORT" ( "ccc<quote>" flag -- ) IMMEDIATE, compile-only
;   Compile-time: compile (ABORT") + inline string
;   Runtime: if flag non-zero, print string and ABORT
; -----------------------------------------------
w_ABORT_QUOTE:
        DEFCODE 'ABORT"', F_IMMEDIATE
w_ABORT_QUOTE_cf:
        ; Save DE (IP) to scratch cell
        LD      (aq_saved_ip), DE

        ; Compile (ABORT") xt + inline string at HERE
        PUSH    BC              ; save TOS
        ; First compile the (ABORT") xt
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (HL), LOW w_PAREN_ABORT_QUOTE_cf
        INC     HL
        LD      (HL), HIGH w_PAREN_ABORT_QUOTE_cf
        INC     HL
        ; Now compile the inline counted string at HL
        ; Save count address, then copy chars from TIB
        PUSH    HL              ; save count_addr
        INC     HL              ; HL = first char destination

        ; Compute source pointer: TIB + >IN
        LD      E, (IY+UserArea.tib_in)
        LD      D, (IY+UserArea.tib_in+1)
        PUSH    HL              ; save dest
        LD      L, (IY+UserArea.tib_addr)
        LD      H, (IY+UserArea.tib_addr+1)
        ADD     HL, DE          ; HL = source
        LD      (aq_src), HL
        POP     HL              ; HL = dest

        ; Skip one leading space (per string literal convention)
        PUSH    HL
        LD      HL, (aq_src)
        LD      A, (HL)
        CP      ' '
        JR      NZ, .aq_no_skip
        INC     HL
        LD      (aq_src), HL
        ; Advance >IN by 1
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
.aq_no_skip:
        POP     HL              ; HL = dest

        ; Compute remaining = tib_len - >IN
        LD      A, (IY+UserArea.tib_len)
        SUB     (IY+UserArea.tib_in)
        LD      C, A
        LD      A, (IY+UserArea.tib_len+1)
        SBC     A, (IY+UserArea.tib_in+1)
        OR      A
        JR      Z, .aq_rem_ok
        LD      C, 255
.aq_rem_ok:
        LD      B, 0            ; B = char count

.aq_copy:
        LD      A, C
        OR      A
        JR      Z, .aq_done     ; end of input
        PUSH    HL
        LD      HL, (aq_src)
        LD      A, (HL)
        INC     HL
        LD      (aq_src), HL
        POP     HL
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
        JR      Z, .aq_done     ; closing quote found
        ; Copy character
        LD      (HL), A
        INC     HL
        INC     B               ; count++
        JR      .aq_copy

.aq_done:
        ; B = string length, HL = past last char
        ; Write count byte
        POP     DE              ; DE = count_addr
        LD      A, B
        LD      (DE), A         ; store count byte

        ; Cell-align HL: if odd, pad with 0 and advance
        BIT     0, L
        JR      Z, .aq_aligned
        LD      (HL), 0         ; padding byte
        INC     HL
.aq_aligned:
        ; Update HERE
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        POP     BC              ; restore TOS

        ; Restore IP
        LD      DE, (aq_saved_ip)
        NEXT

; ABORT" scratch storage
aq_saved_ip:    DW 0
aq_src:         DW 0

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
        CALL    bdos_print_str
        ; Newline
        CALL    bdos_crlf
        ; ABORT resets SP and enters QUIT
        JP      w_ABORT_cf
