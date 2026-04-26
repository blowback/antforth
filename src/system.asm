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
        EXX                                      ; Save TOS/IP/W to shadows

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

        EXX                                      ; Restore TOS/IP/W from shadows
        NEXT

.marker_no_name:
        EXX                                      ; Restore TOS/IP/W from shadows
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
        ; Non-zero flag: print string then ABORT.
        ; No IP save needed: w_ABORT_cf resets SP wholesale and re-enters QUIT
        ; (which resets IX and reloads DE), so any leftover state is erased.
        ; bdos_print_str preserves IX (established invariant — return stack is
        ; IX-based and all BDOS-calling words rely on this).
        LD      A, (DE)         ; A = count
        INC     DE              ; DE = string start
        OR      A
        JR      Z, .paq_do_abort ; Empty string, just abort

        LD      B, A            ; B = count
        LD      H, D
        LD      L, E            ; HL = string address
        CALL    bdos_print_str

.paq_do_abort:
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
; ENVIRONMENT? ( c-addr u -- false | i*x true )
;   Look up the query string c-addr/u in env_table. On hit, push the
;   associated value (single, double, or flag), then push true. On miss,
;   push false alone (one cell — the i*x is absent per DPANS94 §6.1.1345).
;   Match is case-sensitive (all 14 standard keys are uppercase literals
;   per DPANS94 §3.2.6). Keys longer than 255 bytes cannot match — every
;   table key is shorter — so u >= 256 short-circuits to false.
;
; ANS Forth 1994 §6.1.1345   ENVIRONMENT?   — query environment
; -----------------------------------------------
w_ENVIRONMENT_QUERY:
        DEFCODE "ENVIRONMENT?", 0
w_ENVIRONMENT_QUERY_cf:
        CALL    check_underflow_2       ; needs c-addr u (2 cells)
        ; BC = u (TOS), [SP] = c-addr
        LD      A, B
        OR      A
        JR      NZ, .env_too_long       ; u >= 256: no match possible
        ; Consume operands and walk the table.
        LD      (env_saved_ip), DE
        POP     HL                      ; HL = c-addr
        LD      DE, env_table
.env_loop:
        LD      A, (DE)                 ; A = entry length
        OR      A
        JR      Z, .env_not_found       ; len=0 terminator
        CP      C                       ; query length match?
        JR      Z, .env_compare
.env_advance:
        ; Skip this entry: DE += 1 + len + 1 (kind) + (2 or 4)
        INC     DE                      ; -> first key char
        ADD     A, E
        LD      E, A
        JR      NC, .env_adv_no_carry
        INC     D
.env_adv_no_carry:                      ; DE -> kind byte
        LD      A, (DE)                 ; A = kind
        INC     DE                      ; -> first value byte
        CP      1
        JR      NZ, .env_adv_skip2
        INC     DE                      ; double: skip 2 extra bytes
        INC     DE
.env_adv_skip2:
        INC     DE
        INC     DE
        JR      .env_loop
.env_compare:
        ; A = len = u, DE -> length byte, HL -> c-addr
        PUSH    HL                      ; save c-addr
        PUSH    DE                      ; save entry start
        INC     DE                      ; -> first key char
        LD      B, A                    ; B = byte count (>0)
.env_cmp_loop:
        LD      A, (DE)
        CP      (HL)
        JR      NZ, .env_mismatch
        INC     DE
        INC     HL
        DJNZ    .env_cmp_loop
        ; All bytes matched — recover entry start, then advance to value.
        POP     DE                      ; restore entry start
        POP     HL                      ; discard c-addr
        LD      A, (DE)                 ; reload length
        INC     DE
        ADD     A, E
        LD      E, A
        JR      NC, .env_hit_no_carry
        INC     D
.env_hit_no_carry:                      ; DE -> kind byte
        LD      A, (DE)                 ; A = kind
        INC     DE                      ; -> value bytes
        DEC     A
        JR      Z, .env_kind_double
        ; A = kind - 1. Expected post-DEC values: 0->$FF (single), 2->1 (flag).
        ; Any other value here means the table is malformed (kind >= 3 or
        ; corrupted entry header). The 2-byte path is the safe default for
        ; both kind 0 and kind 2; if a future kind needs a different value
        ; size, ADD a JR/CP branch here BEFORE the fall-through. Do NOT
        ; rely on silent fall-through for new kinds.
.env_kind_2byte:
        LD      A, (DE)
        LD      C, A
        INC     DE
        LD      A, (DE)
        LD      B, A                    ; BC = value
        PUSH    BC                      ; value as second-on-stack
        LD      BC, -1                  ; TOS = true ($FFFF)
        LD      DE, (env_saved_ip)
        NEXT
.env_mismatch:
        POP     DE                      ; restore entry start
        POP     HL                      ; restore c-addr
        LD      A, (DE)                 ; reload length
        JR      .env_advance
.env_kind_double:
        ; DE -> 4 bytes: lo_low, lo_high, hi_low, hi_high.
        ; E10-D1 byte-order: low cell on TOS, high cell second.
        ; We want stack ( hi lo true ) with true as TOS, so push hi first
        ; (deepest), then lo (above hi), then BC = -1 (new TOS = true).
        LD      A, (DE)
        LD      L, A
        INC     DE
        LD      A, (DE)
        LD      H, A                    ; HL = lo
        INC     DE
        LD      A, (DE)
        LD      C, A
        INC     DE
        LD      A, (DE)
        LD      B, A                    ; BC = hi
        PUSH    BC                      ; hi (deepest)
        PUSH    HL                      ; lo (above hi)
        LD      BC, -1                  ; TOS = true
        LD      DE, (env_saved_ip)
        NEXT
.env_not_found:
        ; (c-addr, u) already consumed; leave only false on the stack.
        LD      BC, 0
        LD      DE, (env_saved_ip)
        NEXT
.env_too_long:
        ; u >= 256: drop c-addr and return false alone.
        POP     HL                      ; discard c-addr
        LD      BC, 0
        NEXT

env_saved_ip:   DW 0

; --- DPANS94 §3.2.6 standard query-key table ---
; Format per entry: db len, "KEY", kind, value-bytes (2 for kind 0/2, 4 for kind 1)
; Kind: 0 = single-cell, 1 = double-cell (lo then hi), 2 = flag (0=false, $FFFF=true)
; Key match is case-sensitive (all standard keys are uppercase literals).
env_table:
        ; /COUNTED-STRING -> 255 (max counted-string length; antforth uses 8-bit count byte)
        db  15, "/COUNTED-STRING", 0
        dw  255
        ; /HOLD -> PIC_BUF_SIZE = 40 (pictured-output buffer size)
        db  5, "/HOLD", 0
        dw  PIC_BUF_SIZE
        ; /PAD -> PAD_OFFSET = 84 (PAD offset above HERE)
        db  4, "/PAD", 0
        dw  PAD_OFFSET
        ; ADDRESS-UNIT-BITS -> 8 (Z80 byte-addressable)
        db  17, "ADDRESS-UNIT-BITS", 0
        dw  8
        ; CORE -> true (post-Story-10.9: 133/133 §6.1 Core words implemented)
        db  4, "CORE", 2
        dw  $FFFF
        ; CORE-EXT -> false (§6.2 partial: 11/46 implemented; DPANS94 §15.3.5.2 needs full set)
        db  8, "CORE-EXT", 2
        dw  0
        ; FLOORED -> false (antforth's `/` is symmetric per sdivmod, not floored)
        db  7, "FLOORED", 2
        dw  0
        ; MAX-CHAR -> 255 (8-bit char)
        db  8, "MAX-CHAR", 0
        dw  255
        ; MAX-D -> +2147483647 = (lo=$FFFF, hi=$7FFF) — double-cell
        db  5, "MAX-D", 1
        dw  $FFFF
        dw  $7FFF
        ; MAX-N -> 32767 (INT16_MAX)
        db  5, "MAX-N", 0
        dw  32767
        ; MAX-U -> 65535 ($FFFF unsigned; antforth signed TOS shows -1)
        db  5, "MAX-U", 0
        dw  $FFFF
        ; MAX-UD -> 4294967295 = (lo=$FFFF, hi=$FFFF) — double-cell
        db  6, "MAX-UD", 1
        dw  $FFFF
        dw  $FFFF
        ; RETURN-STACK-CELLS -> RS_SIZE/2 = 128
        db  18, "RETURN-STACK-CELLS", 0
        dw  RS_SIZE/2
        ; STACK-CELLS -> PS_SIZE/2 = 128
        db  11, "STACK-CELLS", 0
        dw  PS_SIZE/2
        ; Terminator (zero-length entry)
        db  0

; -----------------------------------------------
; check_underflow — Internal subroutine (not a Forth word)
;   Verify DEPTH >= 1 (at least 1 cell on machine stack)
;   CALL pushes 2-byte return address onto SP, so at time of check
;   SP is 2 less than "real" SP. Need sp_base - SP_real >= 2,
;   i.e. sp_base - SP_measured >= 4.
;
;   On underflow: JP do_underflow_error (raises -4 THROW via
;     w_THROW_cf.kernel_entry; Story 11.4). Never returns to caller.
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
;   On underflow: JP do_underflow_error (-4 THROW; Story 11.4).
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
; check_underflow_3 — Internal subroutine (not a Forth word)
;   Verify DEPTH >= 3 (at least 3 cells on machine stack)
;   For ternary ops needing 3 user items (e.g. 2!).
;   Threshold: sp_base - SP_measured >= 8
;   (2 for CALL ret addr + 6 for three cells)
;
;   On underflow: JP do_underflow_error (-4 THROW; Story 11.4).
;   Clobbers: AF, HL
;   Preserves: BC (TOS), DE (IP), IX, IY, SP
; -----------------------------------------------
check_underflow_3:
        LD      HL, (sp_base)
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP_measured
        JR      C, .underflow3  ; sp_base < SP = corrupt
        LD      A, H
        OR      A
        RET     NZ              ; HL >= 256, plenty of stack
        LD      A, L
        CP      8               ; Need >= 8 (2 ret addr + 6 for three cells)
        RET     NC              ; HL >= 8, OK
.underflow3:
        JP      do_underflow_error

; -----------------------------------------------
; check_underflow_4 — Internal subroutine (not a Forth word)
;   Verify DEPTH >= 4 (at least 4 cells on machine stack)
;   For quaternary ops needing 4 user items (e.g. 2SWAP, 2OVER).
;   Threshold: sp_base - SP_measured >= 10
;   (2 for CALL ret addr + 8 for four cells)
;
;   On underflow: JP do_underflow_error (-4 THROW; Story 11.4).
;   Clobbers: AF, HL
;   Preserves: BC (TOS), DE (IP), IX, IY, SP
; -----------------------------------------------
check_underflow_4:
        LD      HL, (sp_base)
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP_measured
        JR      C, .underflow4  ; sp_base < SP = corrupt
        LD      A, H
        OR      A
        RET     NZ              ; HL >= 256, plenty of stack
        LD      A, L
        CP      10              ; Need >= 10 (2 ret addr + 8 for four cells)
        RET     NC              ; HL >= 10, OK
.underflow4:
        JP      do_underflow_error

; -----------------------------------------------
; do_underflow_error — Internal subroutine (not a Forth word)
;   Migrated by Story 11.4 from `JP w_ABORT_cf` (with a "? Stack
;   underflow" pre-print) to a clean -4 THROW. The diagnostic the
;   user sees on the uncaught path becomes "error -4: stack
;   underflow" (description seeded by Story 11.3 into
;   throw_desc_table at src/exception.asm). On the caught path,
;   -4 lands on the user's data stack as the THROW code per
;   ANS Forth 1994 §9.3.5.
;
;   Note: CALL check_underflow's return address remains on SP —
;   harmless because the THROW-restore (caught) or the ABORT-chain
;   (uncaught) both wholesale reset SP downstream. SP-may-be-corrupt
;   safety is preserved: the new path neither reads nor writes
;   SP-relative values until the downstream restore.
; -----------------------------------------------
do_underflow_error:
        ; -4 THROW (Story 11.4): stack underflow per ANS Forth 1994 §9.3.5
        LD      BC, THROW_STACK_UNDERFLOW
        JP      w_THROW_cf.kernel_entry
