; assembler.asm — Built-in reverse-polish Z80 assembler for CODE words
; AntForth — A Forth for CP/M on Z80
;
; === Design Overview ===
;
; Register-tag encoding (stories 4.2/4.3/4.4 extend this scheme; do not
; change the existing tag values):
;
;   8-bit registers use the Z80 r-field directly (tags 0x00..0x07):
;       B=0  C=1  D=2  E=3  H=4  L=5  (HL)=6  A=7
;   (HL) is not exposed in story 4.1 but its slot is reserved.
;
;   16-bit register pairs use a disjoint tag namespace (0x10..0x14) so
;   an opcode word can tell an 8-bit operand from a 16-bit operand:
;       BC=0x10  DE=0x11  HL=0x12  AF=0x13  SP=0x14
;
;   Opcode words translate these canonical indices to the correct Z80
;   field (qq for PUSH/POP, rp for arithmetic) as needed.
;
; Operand order for multi-operand opcode words is **Zilog convention**:
; destination first, then source. `B C LD,` assembles `LD B, C`. On the
; parameter stack: TOS = source, NOS = destination — so multi-operand
; opcode words pop source first, then destination.
;
; Assembler mode:
;   `CODE name` calls build_header with F_SMUDGE, saves recovery info,
;   sets HERE to the raw code field (no JP DOCOL — CODE words are native
;   machine code, not threaded), and sets asm_mode = 1.
;   Opcode and register words refuse to run unless asm_mode = 1 (AC9:
;   bare register names and opcode words in normal Forth error out
;   cleanly instead of polluting the session). The per-word gate is a
;   `CALL check_asm_mode` preamble routed through one shared helper so
;   adding opcodes in 4.3/4.4 keeps the gate centralised; a cheaper
;   dispatch would require INTERPRET-level changes and is deferred past
;   Epic 4.
;   `END-CODE` clears SMUDGE on the new word and clears asm_mode.
;   On any ABORT path while asm_mode is set, asm_cleanup restores HERE,
;   unlinks the half-built hash entry, and clears asm_mode — hook is in
;   system.asm's w_ABORT_cf.
;
; Error format: all assembler errors print `{subject} ?` followed by CR
; LF, matching the interpreter's `word ?` convention, then jump to
; w_ABORT_cf which calls asm_cleanup to unwind any half-built word.

; =====================================================================
; Assembler state / error-recovery scratch
; =====================================================================
asm_mode:          DB 0   ; 1 while inside CODE..END-CODE
asm_saved_here:    DW 0   ; HERE at CODE entry
asm_saved_bucket:  DB 0   ; hash bucket for new word
asm_saved_head:    DW 0   ; previous bucket head (for unlink)
asm_smudge_addr:   DW 0   ; count_flags address (for END-CODE)
asm_tmp:           DB 0   ; 1-byte spill slot shared by LD, / PUSH, /
                          ; POP, / arith-word helpers (never nested)

; =====================================================================
; Error message strings (printed with trailing " ?" CR LF)
; =====================================================================
str_asm_notcode:   DB "not in CODE"
STR_ASM_NOTCODE_LEN EQU $ - str_asm_notcode

str_asm_badop:     DB "bad operand"
STR_ASM_BADOP_LEN  EQU $ - str_asm_badop

str_asm_nested:    DB "nested CODE"
STR_ASM_NESTED_LEN EQU $ - str_asm_nested

str_asm_noname:    DB "CODE needs name"
STR_ASM_NONAME_LEN EQU $ - str_asm_noname

str_asm_orphan:    DB "END-CODE without CODE"
STR_ASM_ORPHAN_LEN EQU $ - str_asm_orphan

; -----------------------------------------------
; asm_print_error — Print HL..HL+B-1, then " ?", CR, LF via BDOS.
;   Entry: HL = message ptr, B = length
;   Clobbers: A, BC, DE, HL
; -----------------------------------------------
asm_print_error:
.loop:
        LD      E, (HL)
        PUSH    HL
        PUSH    BC
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC
        POP     HL
        INC     HL
        DJNZ    .loop
        LD      E, ' '
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        LD      E, '?'
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        LD      E, 0x0D
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        LD      E, 0x0A
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        RET

; -----------------------------------------------
; asm_die — Print (HL/B) via asm_print_error and JP ABORT. Never returns.
; asm_bad_operand / asm_err_* — Shorthand entries for specific messages.
; -----------------------------------------------
asm_die:
        CALL    asm_print_error
        JP      w_ABORT_cf

asm_bad_operand:
        LD      HL, str_asm_badop
        LD      B, STR_ASM_BADOP_LEN
        JP      asm_die

asm_err_nested:
        LD      HL, str_asm_nested
        LD      B, STR_ASM_NESTED_LEN
        JP      asm_die

asm_err_noname:
        LD      HL, str_asm_noname
        LD      B, STR_ASM_NONAME_LEN
        JP      asm_die

asm_err_orphan:
        LD      HL, str_asm_orphan
        LD      B, STR_ASM_ORPHAN_LEN
        JP      asm_die

; -----------------------------------------------
; asm_cleanup — Subroutine (called from w_ABORT_cf)
;   If asm_mode != 0, restore HERE and hash bucket from the saved state
;   captured by CODE, then clear asm_mode. Leaves a clean dictionary.
; -----------------------------------------------
asm_cleanup:
        LD      A, (asm_mode)
        OR      A
        RET     Z
        ; Restore HERE
        LD      HL, (asm_saved_here)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        ; Restore hash bucket head
        LD      A, (asm_saved_bucket)
        LD      L, A
        LD      H, 0
        ADD     HL, HL                          ; bucket * 2
        LD      BC, hash_table
        ADD     HL, BC                          ; HL = &hash_table[bucket]
        LD      BC, (asm_saved_head)
        LD      (HL), C
        INC     HL
        LD      (HL), B
        ; Clear asm_mode
        XOR     A
        LD      (asm_mode), A
        RET

; -----------------------------------------------
; check_asm_mode — abort unless asm_mode is set.
;   Pass path (RET NZ): preserves BC, DE, HL, IX, IY.
;   Fail path: prints "not in CODE ?" and jumps to ABORT.
; -----------------------------------------------
check_asm_mode:
        LD      A, (asm_mode)
        OR      A
        RET     NZ
        LD      HL, str_asm_notcode
        LD      B, STR_ASM_NOTCODE_LEN
        JP      asm_die

; -----------------------------------------------
; asm_emit_byte — Write A at HERE, advance HERE.
;   Entry:    A = byte to emit
;   Clobbers: HL
;   Preserves: A, BC, DE, IX, IY
; -----------------------------------------------
asm_emit_byte:
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (HL), A
        INC     HL
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        RET

; =====================================================================
; Register-tag constants
; =====================================================================
; Each register word is a DEFCODE that — after asserting asm_mode —
; pushes its canonical tag byte onto the data stack. All 12 words share
; one tail helper (asm_push_tag) so each word body is just "LD L = tag,
; JP asm_push_tag".

; -----------------------------------------------
; asm_push_tag — Shared tail for register-tag words.
;   Entry: L = tag byte (high byte assumed 0 because all tags < 256)
;   check_asm_mode preserves L on the pass path.
; -----------------------------------------------
asm_push_tag:
        CALL    check_asm_mode
        PUSH    BC                      ; save old TOS
        LD      C, L
        LD      B, 0                    ; new TOS = tag
        NEXT

; --- 8-bit registers (tags 0x00..0x07) ---

w_REG_B:
        DEFCODE "B", 0
w_REG_B_cf:
        LD      L, 0x00
        JP      asm_push_tag

w_REG_C:
        DEFCODE "C", 0
w_REG_C_cf:
        LD      L, 0x01
        JP      asm_push_tag

w_REG_D:
        DEFCODE "D", 0
w_REG_D_cf:
        LD      L, 0x02
        JP      asm_push_tag

w_REG_E:
        DEFCODE "E", 0
w_REG_E_cf:
        LD      L, 0x03
        JP      asm_push_tag

w_REG_H:
        DEFCODE "H", 0
w_REG_H_cf:
        LD      L, 0x04
        JP      asm_push_tag

w_REG_L:
        DEFCODE "L", 0
w_REG_L_cf:
        LD      L, 0x05
        JP      asm_push_tag

w_REG_A:
        DEFCODE "A", 0
w_REG_A_cf:
        LD      L, 0x07
        JP      asm_push_tag

; --- 16-bit register pairs (tags 0x10..0x14) ---

w_REG_BC:
        DEFCODE "BC", 0
w_REG_BC_cf:
        LD      L, 0x10
        JP      asm_push_tag

w_REG_DE:
        DEFCODE "DE", 0
w_REG_DE_cf:
        LD      L, 0x11
        JP      asm_push_tag

w_REG_HL:
        DEFCODE "HL", 0
w_REG_HL_cf:
        LD      L, 0x12
        JP      asm_push_tag

w_REG_AF:
        DEFCODE "AF", 0
w_REG_AF_cf:
        LD      L, 0x13
        JP      asm_push_tag

w_REG_SP:
        DEFCODE "SP", 0
w_REG_SP_cf:
        LD      L, 0x14
        JP      asm_push_tag

; =====================================================================
; CODE ( "<spaces>name" -- )
;   Parse name, build dictionary header with F_SMUDGE, save recovery
;   state, leave HERE pointing at the raw code field, and set asm_mode.
;   Unlike `:`, CODE does NOT emit JP DOCOL — the body is native Z80.
; =====================================================================
w_CODE:
        DEFCODE "CODE", 0
w_CODE_cf:
        ; Guard: CODE is not allowed while already compiling or
        ; already inside another CODE definition.
        LD      A, (IY+UserArea.state)
        OR      A
        JP      NZ, asm_err_nested
        LD      A, (IY+UserArea.state+1)
        OR      A
        JP      NZ, asm_err_nested
        LD      A, (asm_mode)
        OR      A
        JP      NZ, asm_err_nested

        ; Save DE (IP) and BC (TOS) to return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B

        LD      A, F_SMUDGE
        CALL    build_header
        JR      C, .code_no_name

        ; Save recovery state from shared bh_* scratch
        LD      BC, (bh_entry_start)
        LD      (asm_saved_here), BC
        LD      A, (bh_bucket_index)
        LD      (asm_saved_bucket), A
        LD      BC, (bh_old_bucket_head)
        LD      (asm_saved_head), BC
        LD      BC, (bh_count_flags_addr)
        LD      (asm_smudge_addr), BC

        ; HL = code field position (from build_header).
        ; CODE words are native: HERE := HL with NO JP DOCOL prefix.
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; Enter assembler mode
        LD      A, 1
        LD      (asm_mode), A

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

.code_no_name:
        ; build_header signalled "no name" — unwind IX (for symmetry
        ; with the colon pattern; QUIT would reset it anyway) and abort
        ; with a descriptive error.
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX
        JP      asm_err_noname

; =====================================================================
; END-CODE ( -- )
;   Clear SMUDGE on the word being defined, leave assembler mode.
;   No HERE adjustment needed — the opcode words already advanced HERE.
; =====================================================================
w_END_CODE:
        DEFCODE "END-CODE", 0
w_END_CODE_cf:
        ; Must be inside a CODE definition
        LD      A, (asm_mode)
        OR      A
        JP      Z, asm_err_orphan

        ; Clear SMUDGE on the new word
        LD      HL, (asm_smudge_addr)
        LD      A, (HL)
        AND     0xBF                    ; = ~F_SMUDGE & 0xFF
        LD      (HL), A

        ; Leave assembler mode
        XOR     A
        LD      (asm_mode), A
        NEXT

; =====================================================================
; Opcode words — PUSH, / POP, (16-bit register-pair operand)
; =====================================================================

; -----------------------------------------------
; asm_pushpop_word — Shared tail for PUSH, and POP,.
;   Entry: A = base opcode (0xC5 for PUSH, 0xC1 for POP)
;   Validates TOS = 16-bit tag in 0x10..0x13, emits base | (qq<<4),
;   pops new TOS. Rejects SP and any 8-bit tag.
; -----------------------------------------------
asm_pushpop_word:
        LD      (asm_tmp), A            ; spill base opcode
        CALL    check_asm_mode
        ; Validate tag in BC: high byte 0, low byte 0x10..0x13
        LD      A, B
        OR      A
        JP      NZ, asm_bad_operand
        LD      A, C
        SUB     0x10
        JP      C, asm_bad_operand      ; < 0x10 → 8-bit tag
        CP      4
        JP      NC, asm_bad_operand     ; >= 0x14 → SP or garbage
        ; qq = A (0..3); opcode = base | (qq<<4)
        RLCA
        RLCA
        RLCA
        RLCA                            ; A = qq << 4
        LD      HL, asm_tmp
        OR      (HL)                    ; A = base | (qq<<4)
        CALL    asm_emit_byte
        POP     BC                      ; new TOS
        NEXT

w_PUSH_COMMA:
        DEFCODE "PUSH,", 0
w_PUSH_COMMA_cf:
        LD      A, 0xC5
        JP      asm_pushpop_word

w_POP_COMMA:
        DEFCODE "POP,", 0
w_POP_COMMA_cf:
        LD      A, 0xC1
        JP      asm_pushpop_word

; =====================================================================
; Opcode words — LD, (8-bit register-to-register)
; =====================================================================

; -----------------------------------------------
; assert_8bit_reg — HL = tag; reject if not a valid 8-bit r-field.
;   On success: A = L (tag value 0..7 excluding 6), Z flag from `CP 6`.
;   On failure: JP asm_bad_operand (never returns)
; -----------------------------------------------
assert_8bit_reg:
        LD      A, H
        OR      A
        JP      NZ, asm_bad_operand
        LD      A, L
        CP      8
        JP      NC, asm_bad_operand     ; >= 8 → 16-bit tag or garbage
        CP      6
        JP      Z, asm_bad_operand      ; (HL) not exposed in 4.1
        RET

; -----------------------------------------------
; LD, ( dst src -- )  emits LD r, r' (0x40 | (dst<<3) | src)
;   Zilog operand order: NOS = destination, TOS = source.
; -----------------------------------------------
w_LD_COMMA:
        DEFCODE "LD,", 0
w_LD_COMMA_cf:
        CALL    check_asm_mode
        ; TOS (BC) = source tag; validate as 8-bit
        LD      H, B
        LD      L, C
        CALL    assert_8bit_reg         ; A = src r-value
        LD      (asm_tmp), A            ; spill src
        POP     HL                      ; HL = destination tag (NOS)
        CALL    assert_8bit_reg         ; A = dst r-value
        ; Compute opcode: 0x40 | (dst<<3) | src
        RLCA
        RLCA
        RLCA                            ; A = dst << 3
        OR      0x40                    ; A = 0x40 | (dst<<3)
        LD      HL, asm_tmp
        OR      (HL)                    ; A |= src
        CALL    asm_emit_byte
        POP     BC                      ; new TOS
        NEXT

; =====================================================================
; Opcode words — Arithmetic/logic on A (8-bit register operand)
; =====================================================================

; -----------------------------------------------
; asm_get_r8 — Take TOS (BC) as an 8-bit register tag, return r in A.
;   Tail-calls assert_8bit_reg → JP asm_bad_operand on failure.
;   Preserves DE (IP); clobbers HL.
; -----------------------------------------------
asm_get_r8:
        LD      H, B
        LD      L, C
        JP      assert_8bit_reg

; -----------------------------------------------
; asm_arith_word — Shared tail for ADD,/SUB,/AND,/OR,/XOR,/CP,.
;   Entry: A = base opcode (0x80/0x90/0xA0/0xA8/0xB0/0xB8)
;   Pops TOS as 8-bit register tag, emits base | r, pops new TOS.
; -----------------------------------------------
asm_arith_word:
        LD      (asm_tmp), A            ; spill base opcode
        CALL    check_asm_mode
        CALL    asm_get_r8              ; A = r-field
        LD      HL, asm_tmp
        OR      (HL)                    ; A = base | r
        CALL    asm_emit_byte
        POP     BC                      ; new TOS
        NEXT

w_ADD_COMMA:
        DEFCODE "ADD,", 0
w_ADD_COMMA_cf:
        LD      A, 0x80
        JP      asm_arith_word

w_SUB_COMMA:
        DEFCODE "SUB,", 0
w_SUB_COMMA_cf:
        LD      A, 0x90
        JP      asm_arith_word

w_AND_COMMA:
        DEFCODE "AND,", 0
w_AND_COMMA_cf:
        LD      A, 0xA0
        JP      asm_arith_word

w_XOR_COMMA:
        DEFCODE "XOR,", 0
w_XOR_COMMA_cf:
        LD      A, 0xA8
        JP      asm_arith_word

w_OR_COMMA:
        DEFCODE "OR,", 0
w_OR_COMMA_cf:
        LD      A, 0xB0
        JP      asm_arith_word

w_CP_COMMA:
        DEFCODE "CP,", 0
w_CP_COMMA_cf:
        LD      A, 0xB8
        JP      asm_arith_word

; =====================================================================
; NEXT, ( -- )  emit the inner-interpreter NEXT macro's byte sequence
;   Uses a template assembled by the NEXT macro at build time so the
;   template always stays byte-for-byte in sync with macros.asm.
; =====================================================================
w_NEXT_COMMA:
        DEFCODE "NEXT,", 0
w_NEXT_COMMA_cf:
        CALL    check_asm_mode
        ; Copy NEXT_TEMPLATE_LEN bytes from next_template to HERE via
        ; LDIR. Must preserve DE (=IP) and BC (=TOS) — save both to RS.
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B
        LD      HL, next_template
        LD      E, (IY+UserArea.here)
        LD      D, (IY+UserArea.here+1)
        LD      BC, NEXT_TEMPLATE_LEN
        LDIR                                    ; HL→DE, DE ends = HERE+N
        LD      (IY+UserArea.here), E
        LD      (IY+UserArea.here+1), D
        ; Restore TOS and IP
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX
        NEXT                                    ; real NEXT — return to interp

; --- Template: the NEXT macro expands here. Flow never reaches these
;     bytes (the NEXT above jumps away), so they serve as pure data. ---
next_template:
        NEXT
next_template_end:
NEXT_TEMPLATE_LEN EQU next_template_end - next_template
