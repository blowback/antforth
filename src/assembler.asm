; assembler.asm — Built-in reverse-polish Z80 assembler for CODE words
; AntForth — A Forth for CP/M on Z80
;
; === Design Overview ===
;
; Unified tag encoding (story 4.3.5 refactor):
;
;   Every tagged operand has high byte 0xFF. The low byte encodes a
;   3-bit class (bits 7-5) and a 5-bit index (bits 4-0):
;
;     Class 000 (0x00)  8-bit register   B=0 C=1 D=2 E=3 H=4 L=5 A=7 I=8 R=9
;     Class 001 (0x20)  Condition code   NZ=0 Z=1 NC=2 CS=3 PO=4 PE=5 P=6 M=7
;     Class 010 (0x40)  Immediate marker value in next stack cell
;     Class 011 (0x60)  16-bit register  BC=0 DE=1 HL=2 AF=3 SP=4 IX=5 IY=6 AF'=7
;     Class 100 (0x80)  Indirect         (HL)=0 (IX)=1 (IY)=2 (IX+d)=3 (IY+d)=4
;                                        (SP)=5 (C)=6 (BC)=7 (DE)=8 ()=9
;     Class 101 (0xA0)  Label            slot index 0..15
;
;   Opcode words check B==0xFF to detect tagged operands (bare integers
;   have B != 0xFF and trigger a "forgot #?" error), then extract the
;   class via AND 0xE0 and the index via AND 0x1F.
;
; Operand order for multi-operand opcode words is **Zilog convention**,
; applied uniformly across every form — register-to-register,
; register-immediate, indirect-(HL), and every future Story 4.4+
; extension. Destination comes first on the input stream, source last:
;
;   B C LD,            assembles  LD B, C          (reg,reg)
;   A 0x42 # LD,       assembles  LD A, 0x42       (reg,n)
;   BC 0x1234 # LD,    assembles  LD BC, 0x1234    (rp,nn)
;   A (HL) LD,         assembles  LD A, (HL)       (reg,(HL))
;   (HL) A LD,         assembles  LD (HL), A       ((HL),reg)
;
; On the parameter stack at opcode-word entry, TOS is whatever was
; typed last: for the register forms that is the source register; for
; the immediate forms it is the `#` marker (with the value in NOS and
; the destination in NNOS). Opcode words dispatch on the TOS tag class
; and pop the operands in the matching order. Common footgun: omitting
; the `#` marker (`A 0x42 LD,`) silently mis-assembles as a register-
; to-register LD where 0x42 is interpreted as a register tag. Under the
; unified tag encoding (story 4.3.5) this is now caught: bare integers
; have high byte != 0xFF and trigger a clear error.
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
;
; Reserved single-letter dictionary words (will shadow any user word of
; the same name once assembler.asm is loaded):
;   A B C D E H L      8-bit registers (story 4.1)
;   Z P M              condition codes (story 4.3 — Z=zero, P=plus, M=minus)
; Two-letter condition words NZ NC CS PO PE are also reserved. The
; carry-set condition is spelled `CS` (6502-style) — never `C`, which is
; the C register — and `CC` is intentionally NOT defined so it remains
; usable as a hex literal in BASE=16 (= 204).

; =====================================================================
; Assembler state / error-recovery scratch
; =====================================================================
asm_mode:          DB 0   ; 1 while inside CODE..END-CODE
asm_saved_here:    DW 0   ; HERE at CODE entry (entry start, for restore)
asm_body_start:    DW 0   ; HERE at the start of the CODE word body
                          ; (= code field address; for LABEL "no opcodes" check)
asm_saved_bucket:  DB 0   ; hash bucket for new word
asm_saved_head:    DW 0   ; previous bucket head (for unlink)
asm_smudge_addr:   DW 0   ; count_flags address (for END-CODE)
asm_tmp:           DB 0   ; 1-byte spill slot shared by LD, / PUSH, /
                          ; POP, / arith-word helpers (never nested)
asm_tmp2:          DW 0   ; 2-byte spill slot for label/fixup helpers
asm_ip_save:       DW 0   ; spill slot for DE (IP) across helper calls in
                          ; FIX/JR,/DW, that clobber DE
asm_resolve_target: DW 0  ; cached target address for asm_resolve_slot's
                          ; fixup-walk loop (loaded once at FIX time and
                          ; reloaded into DE before each apply call)
asm_jp_op:         DB 0   ; 1-byte spill slot for JP,/CALL, unconditional
                          ; opcode (kept separate from asm_tmp — Story 4.3
                          ; retrospective lesson #2: don't share scratch
                          ; across nesting boundaries)

; =====================================================================
; Per-CODE label and fixup pools (Story 4.2)
; =====================================================================
; LABEL declares a per-CODE forward/back-reference target. Each LABEL
; allocates one slot in asm_label_pool and builds a normal Forth dict
; entry in the side area asm_label_dict (NOT at HERE — HERE is busy
; assembling native machine code into the in-progress CODE word body).
;
; Slot record (8 bytes):
;   +0  resolved flag (0 = unresolved, 1 = resolved)
;   +1  target address (2 bytes; valid only when resolved=1)
;   +3  hash bucket index (set by LABEL after build_header)
;   +4  saved bucket head (2 bytes; for unlink at END-CODE/cleanup)
;   +6  count_flags ptr (2 bytes; points at the dict entry's count_flags
;       byte — name length follows in low 5 bits, name bytes follow)
;
; Fixup record (4 bytes):
;   +0  patch address (2 bytes — the placeholder byte/word in CODE body)
;   +2  fixup kind (0 = JR-disp, 1 = DW-absolute)
;   +3  label slot index
;
; Label tag encoding: TOS = 0xFF | (ASM_CLASS_LABEL | slot_index).
; High byte 0xFF, low byte = 0xA0 | slot (class=101, 5-bit index).
; Decoder: check B==0xFF, then (C AND 0xE0)==ASM_CLASS_LABEL,
; slot = C AND 0x1F.
;
; Cleanup (asm_unlink_labels) walks slots in reverse insertion order and
; restores each bucket's head from the saved old_head. LIFO undo of the
; prepend-to-head dictionary discipline correctly handles bucket-collision
; cases (worked example in story Dev Notes).
ASM_LABEL_POOL_SIZE  EQU 16
ASM_LABEL_REC_SIZE   EQU 8
ASM_FIXUP_POOL_SIZE  EQU 32
ASM_FIXUP_REC_SIZE   EQU 4
; Worst case per label entry: 2 (link) + 1 (count_flags) + 31 (max name,
; F_LENMASK = 0x1F) + 5 (LD L,n / JP asm_push_label_tag body) = 39 bytes.
; With ASM_LABEL_POOL_SIZE = 16 the upper bound is 16 * 39 = 624 bytes.
; 768 leaves comfortable headroom and is bounded by the slot pool size,
; so no runtime overflow check is required.
ASM_LABEL_DICT_SIZE  EQU 768
ASM_FIXUP_KIND_JR    EQU 0
ASM_FIXUP_KIND_DW    EQU 1
; Unified tag encoding: high byte = 0xFF for ALL tagged operands.
; Low byte = 3-bit class (top) | 5-bit index (bottom).
ASM_TAG_HI           EQU 0xFF
; Class constants (upper 3 bits of low byte)
ASM_CLASS_REG8       EQU 0x00     ; 8-bit register (index = r-field 0..7)
ASM_CLASS_COND       EQU 0x20     ; condition code (index = cc 0..7)
ASM_CLASS_IMM        EQU 0x40     ; immediate marker (index = 0)
ASM_CLASS_REG16      EQU 0x60     ; 16-bit register pair (index 0..6)
ASM_CLASS_INDIRECT   EQU 0x80     ; indexed/indirect (index 0..6)
ASM_CLASS_LABEL      EQU 0xA0     ; label (index = slot 0..15)
; Extraction masks
ASM_CLASS_MASK       EQU 0xE0     ; AND with low byte to get class
ASM_INDEX_MASK       EQU 0x1F     ; AND with low byte to get index
; REG16 extended indices (class 0x60):
;   0=BC, 1=DE, 2=HL, 3=AF, 4=SP, 5=IX, 6=IY, 7=AF'
ASM_IX_INDEX         EQU 5
ASM_IY_INDEX         EQU 6
ASM_AFP_INDEX        EQU 7
; INDIRECT extended indices (class 0x80):
;   0=(HL), 1=(IX), 2=(IY), 3=(IX+d), 4=(IY+d), 5=(SP), 6=(C),
;   7=(BC), 8=(DE), 9=() (absolute memory address)
ASM_IND_IX           EQU 1
ASM_IND_IY           EQU 2
ASM_IND_IXD          EQU 3
ASM_IND_IYD          EQU 4
ASM_IND_SP           EQU 5
ASM_IND_C            EQU 6
ASM_IND_BC           EQU 7
ASM_IND_DE           EQU 8
ASM_IND_ABS          EQU 9
; REG8 extended indices for special registers (LD-only):
;   8=I, 9=R
ASM_REG8_I           EQU 8
ASM_REG8_R           EQU 9

asm_label_count:   DB 0
asm_fixup_count:   DB 0
asm_label_dict_ptr: DW 0
asm_label_pool:    DS ASM_LABEL_POOL_SIZE * ASM_LABEL_REC_SIZE
asm_fixup_pool:    DS ASM_FIXUP_POOL_SIZE * ASM_FIXUP_REC_SIZE
asm_label_dict:    DS ASM_LABEL_DICT_SIZE

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

str_asm_label_after: DB "LABEL must precede opcodes"
STR_ASM_LABEL_AFTER_LEN EQU $ - str_asm_label_after

str_asm_jr_range:  DB "JR out of range"
STR_ASM_JR_RANGE_LEN EQU $ - str_asm_jr_range

str_asm_too_labels: DB "too many labels"
STR_ASM_TOO_LABELS_LEN EQU $ - str_asm_too_labels

str_asm_too_fixups: DB "too many fixups"
STR_ASM_TOO_FIXUPS_LEN EQU $ - str_asm_too_fixups

str_asm_equ_in_code: DB "EQU outside CODE only"
STR_ASM_EQU_IN_CODE_LEN EQU $ - str_asm_equ_in_code

; "unresolved label " — printed before name; trailing space included
str_asm_unresolved: DB "unresolved label "
STR_ASM_UNRESOLVED_LEN EQU $ - str_asm_unresolved

; "already fixed: " — printed before name (NAME-after format keeps the
; name-printing helper uniform with the unresolved-label path)
str_asm_already:   DB "already fixed: "
STR_ASM_ALREADY_LEN EQU $ - str_asm_already

str_asm_bare_int:  DB "bare integer "
STR_ASM_BARE_INT_LEN EQU $ - str_asm_bare_int

str_asm_range:     DB "range"
STR_ASM_RANGE_LEN  EQU $ - str_asm_range

asm_print_str EQU bdos_print_str

; -----------------------------------------------
; asm_print_error — Print HL..HL+B-1, then " ?", CR, LF via BDOS.
;   Entry: HL = message ptr, B = length
;   Clobbers: A, BC, DE, HL
; -----------------------------------------------
asm_print_error:
        CALL    bdos_print_str
        JP      bdos_print_q_crlf   ; explicit tail-call replaces fall-through

asm_print_q_crlf EQU bdos_print_q_crlf

; -----------------------------------------------
; asm_print_hex16 — Print HL as 4 hex digits via BDOS.
;   Clobbers: A, BC, DE, HL
; -----------------------------------------------
asm_print_hex16:
        PUSH    HL
        LD      A, H
        CALL    asm_print_hex8
        POP     HL
        LD      A, L
        ; Fall through to asm_print_hex8

; -----------------------------------------------
; asm_print_hex8 — Print A as 2 hex digits via BDOS.
;   Clobbers: A, DE, C
; -----------------------------------------------
asm_print_hex8:
        PUSH    AF
        RRCA
        RRCA
        RRCA
        RRCA
        CALL    .nibble
        POP     AF
.nibble:
        AND     0x0F
        ADD     A, '0'
        CP      '9' + 1
        JR      C, .digit
        ADD     A, 'A' - '9' - 1
.digit:
        LD      E, A
        JP      bdos_putchar

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

asm_err_label_after:
        LD      HL, str_asm_label_after
        LD      B, STR_ASM_LABEL_AFTER_LEN
        JP      asm_die

asm_err_jr_range:
        LD      HL, str_asm_jr_range
        LD      B, STR_ASM_JR_RANGE_LEN
        JP      asm_die

asm_err_too_labels:
        LD      HL, str_asm_too_labels
        LD      B, STR_ASM_TOO_LABELS_LEN
        JP      asm_die

asm_err_too_fixups:
        LD      HL, str_asm_too_fixups
        LD      B, STR_ASM_TOO_FIXUPS_LEN
        JP      asm_die

asm_err_equ_in_code:
        LD      HL, str_asm_equ_in_code
        LD      B, STR_ASM_EQU_IN_CODE_LEN
        JP      asm_die

asm_err_bare_int:
        ; HL = bare integer value on entry (set by callers)
        PUSH    HL
        LD      HL, str_asm_bare_int
        LD      B, STR_ASM_BARE_INT_LEN
        CALL    asm_print_str
        POP     HL
        CALL    asm_print_hex16
        CALL    asm_print_q_crlf
        JP      w_ABORT_cf

; -----------------------------------------------
; asm_check_tagged — Verify TOS (BC) is a tagged operand (B == 0xFF).
;   If B != 0xFF, the user passed a bare integer where a tagged operand
;   was expected. Prints "bare integer ?" and ABORTs.
;   On success: returns with BC unchanged, Z flag set.
;   On failure: never returns (ABORTs).
; -----------------------------------------------
asm_check_tagged:
        LD      A, B
        CP      ASM_TAG_HI
        RET     Z
        LD      H, B
        LD      L, C
        JP      asm_err_bare_int

; -----------------------------------------------
; asm_print_error_with_name — Print prefix string + label name + " ?" CRLF.
;   Entry: HL = prefix string, B = prefix length,
;          DE = pointer to count_flags byte of the label dict entry
;          (length is low 5 bits of (DE), name bytes follow at DE+1)
;   Never returns — falls through to ABORT via asm_die_after_name.
; -----------------------------------------------
asm_print_error_with_name:
        ; Print prefix bytes
        LD      A, B
        OR      A
        JR      Z, .pen_skip_prefix
        CALL    bdos_print_str
.pen_skip_prefix:
        ; HL = count_flags ptr (saved in asm_tmp2 by caller via DE→tmp);
        ; we re-read it from asm_tmp2 here so prefix print could clobber DE.
        LD      HL, (asm_tmp2)          ; HL = count_flags ptr
        LD      A, (HL)                 ; A = count_flags
        AND     F_LENMASK               ; A = name length
        LD      B, A
        OR      A
        JR      Z, .pen_no_name
        INC     HL                      ; HL = name start
        CALL    bdos_print_str
.pen_no_name:
        ; Print " ?" CR LF
        CALL    bdos_print_q_crlf
        JP      w_ABORT_cf

; -----------------------------------------------
; asm_err_unresolved — print "unresolved label NAME ?" and ABORT.
;   Entry: HL = count_flags ptr of the unresolved label's dict entry.
;   Stashes HL into asm_tmp2 then jumps to asm_print_error_with_name.
; -----------------------------------------------
asm_err_unresolved:
        LD      (asm_tmp2), HL
        LD      HL, str_asm_unresolved
        LD      B, STR_ASM_UNRESOLVED_LEN
        JP      asm_print_error_with_name

; -----------------------------------------------
; asm_err_already — print "already fixed: NAME ?" and ABORT.
;   Entry: HL = count_flags ptr of the already-fixed label's dict entry.
; -----------------------------------------------
asm_err_already:
        LD      (asm_tmp2), HL
        LD      HL, str_asm_already
        LD      B, STR_ASM_ALREADY_LEN
        JP      asm_print_error_with_name

; -----------------------------------------------
; asm_cleanup — Subroutine (called from w_ABORT_cf)
;   If asm_mode != 0, restore HERE and hash bucket from the saved state
;   captured by CODE, then clear asm_mode. Leaves a clean dictionary.
; -----------------------------------------------
asm_cleanup:
        LD      A, (asm_mode)
        OR      A
        RET     Z
        ; Unlink any in-progress label dict entries FIRST (they were
        ; added AFTER the CODE word's link, so reverse-order unlink keeps
        ; correctness even when labels collide with the CODE word in the
        ; same bucket).
        CALL    asm_unlink_labels
        ; Restore HERE
        LD      HL, (asm_saved_here)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        ; Restore hash bucket head for the in-progress CODE word
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
        ; (LATEST is intentionally not restored — matches the existing
        ; colon-compiler error recovery convention; QUIT carries on and
        ; the next `:` / CODE will overwrite LATEST.)
        ; Reset label/fixup state
        CALL    asm_reset_label_state
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
; Label / fixup helpers (Story 4.2)
; =====================================================================

; -----------------------------------------------
; asm_slot_addr — Compute slot address from index.
;   Entry: A = slot index (0..ASM_LABEL_POOL_SIZE-1)
;   Exit:  HL = &asm_label_pool[A]
;   Clobbers: A, HL
; -----------------------------------------------
asm_slot_addr:
        LD      L, A
        LD      H, 0
        ADD     HL, HL              ; *2
        ADD     HL, HL              ; *4
        ADD     HL, HL              ; *8 (== ASM_LABEL_REC_SIZE)
        PUSH    DE
        LD      DE, asm_label_pool
        ADD     HL, DE
        POP     DE
        RET

; -----------------------------------------------
; asm_fixup_addr — Compute fixup record address from index.
;   Entry: A = fixup index
;   Exit:  HL = &asm_fixup_pool[A]
; -----------------------------------------------
asm_fixup_addr:
        LD      L, A
        LD      H, 0
        ADD     HL, HL              ; *2
        ADD     HL, HL              ; *4 (== ASM_FIXUP_REC_SIZE)
        PUSH    DE
        LD      DE, asm_fixup_pool
        ADD     HL, DE
        POP     DE
        RET

; -----------------------------------------------
; asm_alloc_label_slot — Allocate next free label slot.
;   Exit: A = new slot index (also leaves slot zeroed)
;   On overflow: ABORT via asm_err_too_labels.
;   Preserves: BC, DE, IY, IX
; -----------------------------------------------
asm_alloc_label_slot:
        LD      A, (asm_label_count)
        CP      ASM_LABEL_POOL_SIZE
        JP      NC, asm_err_too_labels
        PUSH    AF                  ; save new index
        CALL    asm_slot_addr       ; HL = &slot
        ; Zero 8 bytes
        LD      (HL), 0             ; resolved=0
        INC     HL
        LD      (HL), 0             ; target lo
        INC     HL
        LD      (HL), 0             ; target hi
        INC     HL
        LD      (HL), 0             ; bucket
        INC     HL
        LD      (HL), 0             ; old_head lo
        INC     HL
        LD      (HL), 0             ; old_head hi
        INC     HL
        LD      (HL), 0             ; cf_ptr lo
        INC     HL
        LD      (HL), 0             ; cf_ptr hi
        ; Bump count
        LD      A, (asm_label_count)
        INC     A
        LD      (asm_label_count), A
        POP     AF                  ; A = new index
        RET

; -----------------------------------------------
; asm_add_fixup — Append a fixup record.
;   Entry: A = label index, C = kind (0=JR, 1=DW), HL = patch address
;   Exit:  fixup record written, asm_fixup_count incremented.
;   On overflow: ABORT via asm_err_too_fixups.
; -----------------------------------------------
asm_add_fixup:
        PUSH    AF                  ; save label idx
        PUSH    HL                  ; save patch addr
        PUSH    BC                  ; save kind in C
        LD      A, (asm_fixup_count)
        CP      ASM_FIXUP_POOL_SIZE
        JP      NC, asm_err_too_fixups
        CALL    asm_fixup_addr      ; HL = &fixup_pool[count]
        POP     BC                  ; C = kind
        POP     DE                  ; DE = patch addr
        LD      (HL), E             ; +0 patch lo
        INC     HL
        LD      (HL), D             ; +1 patch hi
        INC     HL
        LD      (HL), C             ; +2 kind
        INC     HL
        POP     AF                  ; A = label idx
        LD      (HL), A             ; +3 label idx
        ; Bump count
        LD      HL, asm_fixup_count
        INC     (HL)
        RET

; -----------------------------------------------
; asm_jr_disp — Compute and range-check an 8-bit JR displacement.
;   Entry: HL = patch address (== address of the displacement byte),
;          DE = target address
;   Exit:  A = signed displacement byte (target - (patch+1))
;          HL preserved.
;   On out-of-range: ABORT via asm_err_jr_range. Shared by the patch
;   path (asm_apply_jr_fixup) and the direct-emit path
;   (asm_apply_jr_fixup_emit) so the range logic lives in one place.
; -----------------------------------------------
asm_jr_disp:
        PUSH    HL
        INC     HL                  ; HL = patch + 1
        EX      DE, HL              ; HL = target, DE = patch+1
        OR      A
        SBC     HL, DE              ; HL = signed displacement
        LD      A, H
        OR      A
        JR      Z, .jrd_pos
        CP      0xFF
        JR      NZ, .jrd_oor
        BIT     7, L                ; negative → bit 7 must be set
        JR      Z, .jrd_oor
        JR      .jrd_ok
.jrd_pos:
        BIT     7, L                ; positive → bit 7 must be clear
        JR      NZ, .jrd_oor
.jrd_ok:
        LD      A, L                ; A = displacement
        EX      DE, HL              ; HL = patch+1, DE = old HL=junk
        POP     HL                  ; HL = patch addr
        RET
.jrd_oor:
        POP     HL                  ; clean stack
        JP      asm_err_jr_range

; -----------------------------------------------
; asm_apply_jr_fixup — Patch a queued JR fixup with a real displacement.
;   Entry: HL = patch address, DE = target address
;   On out-of-range: ABORT via asm_err_jr_range.
;   The displacement byte field is at HL; the JR opcode itself sits at
;   HL-1. The "next instruction" address used by Z80 is patch_addr+1.
; -----------------------------------------------
asm_apply_jr_fixup:
        CALL    asm_jr_disp         ; A = disp, HL = patch addr
        LD      (HL), A
        RET

; -----------------------------------------------
; asm_apply_dw_fixup — Patch a queued DW fixup (16-bit absolute).
;   Entry: HL = patch address, DE = target address
;   Stores DE little-endian at HL.
; -----------------------------------------------
asm_apply_dw_fixup:
        LD      (HL), E
        INC     HL
        LD      (HL), D
        RET

; -----------------------------------------------
; asm_apply_fixup_record — Apply one fixup record by reading patch
;   address and kind in a single linear pass and tail-dispatching to
;   the appropriate leaf.
;   Entry: HL = &fixup record (record layout: patch_lo, patch_hi, kind, label_idx)
;          DE = target address
;   Exit:  Tail-jumps to asm_apply_jr_fixup or asm_apply_dw_fixup, which
;          return to the caller of asm_apply_fixup_record.
;   Clobbers: A, C, HL. Preserves B (slot index) and DE (target).
; -----------------------------------------------
asm_apply_fixup_record:
        INC     HL
        INC     HL
        LD      A, (HL)             ; A = kind (record+2)
        DEC     HL
        DEC     HL                  ; HL = &record again
        LD      C, A                ; spill kind to C
        LD      A, (HL)             ; A = patch lo
        INC     HL
        LD      H, (HL)             ; H = patch hi
        LD      L, A                ; HL = patch addr
        LD      A, C                ; A = kind
        OR      A
        JP      Z, asm_apply_jr_fixup
        JP      asm_apply_dw_fixup

; -----------------------------------------------
; asm_resolve_slot — Mark slot resolved with HERE as target, walk fixups.
;   Entry: A = slot index of the label being resolved.
;   Marks the slot resolved, stores HERE as its target, then sweeps the
;   fixup pool: for every record whose label index matches, applies the
;   patch via asm_apply_fixup_record and removes the record by swapping
;   the last record over the current slot and decrementing the count.
;   On JR-range error during apply, the underlying helper ABORTs.
;
;   Register usage in the walk:
;     B  = our slot index (preserved across the loop)
;     C  = walk index (preserved across the loop)
;     HL = pointer to current fixup record (advanced by 4 per non-match)
;     DE = scratch (reloaded from asm_resolve_target before each apply)
; -----------------------------------------------
asm_resolve_slot:
        LD      B, A                ; B = our slot idx (live across loop)
        CALL    asm_slot_addr       ; HL = &slot[B]
        LD      (HL), 1             ; +0 resolved = 1
        INC     HL
        LD      A, (IY+UserArea.here)
        LD      (HL), A             ; +1 target lo
        LD      E, A
        INC     HL
        LD      A, (IY+UserArea.here+1)
        LD      (HL), A             ; +2 target hi
        LD      D, A
        LD      (asm_resolve_target), DE

        LD      HL, asm_fixup_pool
        LD      C, 0                ; C = walk index
.rsl_loop:
        LD      A, (asm_fixup_count)
        CP      C
        RET     Z                   ; walk == count → done
        ; Read this record's label idx (record+3); restore HL after.
        INC     HL
        INC     HL
        INC     HL
        LD      A, (HL)
        DEC     HL
        DEC     HL
        DEC     HL                  ; HL = &record[walk]
        CP      B
        JR      Z, .rsl_match
        ; No match — advance HL by 4 (one record), C++.
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        INC     C
        JR      .rsl_loop
.rsl_match:
        ; Apply the matching fixup. The helper clobbers HL/A/C; preserve
        ; B (slot idx) and the record pointer across the call.
        PUSH    HL                  ; save record ptr
        PUSH    BC                  ; save slot/walk
        LD      DE, (asm_resolve_target)
        CALL    asm_apply_fixup_record
        POP     BC                  ; B=slot, C=walk
        POP     HL                  ; HL = &record[walk]
        ; Compact: copy fixup_pool[count-1] over fixup_pool[walk], dec count.
        LD      A, (asm_fixup_count)
        DEC     A                   ; A = last index
        CP      C
        JR      Z, .rsl_just_dec    ; current IS last → no copy
        ; Copy 4 bytes from &record[last] over &record[walk]; HL is dst.
        PUSH    HL                  ; save dst (= &record[walk])
        PUSH    BC                  ; save B/C
        CALL    asm_fixup_addr      ; HL = &record[A=last]; A unchanged
        POP     BC                  ; B=slot, C=walk
        POP     DE                  ; DE = dst (= &record[walk])
        LD      A, (HL)             ; copy +0
        LD      (DE), A
        INC     HL
        INC     DE
        LD      A, (HL)             ; copy +1
        LD      (DE), A
        INC     HL
        INC     DE
        LD      A, (HL)             ; copy +2
        LD      (DE), A
        INC     HL
        INC     DE
        LD      A, (HL)             ; copy +3
        LD      (DE), A
        ; Restore HL = &record[walk] (DE is one past the end after copy).
        EX      DE, HL              ; HL = &record[walk] + 3
        DEC     HL
        DEC     HL
        DEC     HL                  ; HL = &record[walk]
.rsl_just_dec:
        ; Decrement asm_fixup_count without disturbing HL.
        PUSH    HL
        LD      HL, asm_fixup_count
        DEC     (HL)
        POP     HL                  ; HL = &record[walk]
        ; Re-process the same walk index (a record was swapped in).
        JR      .rsl_loop

; -----------------------------------------------
; asm_check_unresolved — Called from END-CODE before SMUDGE-clear.
;   If any fixup remains, look up its label's count_flags ptr (slot+6),
;   and ABORT via asm_err_unresolved (which prints "unresolved label NAME ?").
; -----------------------------------------------
asm_check_unresolved:
        LD      A, (asm_fixup_count)
        OR      A
        RET     Z
        ; Read first fixup's label idx (fixup +3)
        XOR     A
        CALL    asm_fixup_addr      ; HL = &fixup[0]
        INC     HL
        INC     HL
        INC     HL
        LD      A, (HL)             ; A = label idx
        ; Get slot, read cf_ptr (slot+6,7)
        CALL    asm_slot_addr       ; HL = &slot
        LD      DE, 6
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)             ; DE = cf_ptr
        EX      DE, HL              ; HL = cf_ptr
        JP      asm_err_unresolved

; -----------------------------------------------
; asm_unlink_labels — Walk asm_label_pool in reverse insertion order
;   and restore each bucket's head from the slot's saved old_head.
;   Called from END-CODE (success path) and asm_cleanup (error path).
;   Order matters: reverse insertion = LIFO undo of prepend-to-head.
; -----------------------------------------------
asm_unlink_labels:
        LD      A, (asm_label_count)
        OR      A
        RET     Z
.ul_loop:
        DEC     A                   ; A = current slot index
        PUSH    AF
        CALL    asm_slot_addr       ; HL = &slot
        ; Skip resolved/target (3 bytes) → bucket at +3
        INC     HL
        INC     HL
        INC     HL
        LD      A, (HL)             ; A = bucket index
        INC     HL
        LD      E, (HL)             ; E = old_head lo
        INC     HL
        LD      D, (HL)             ; D = old_head hi
        ; Compute &hash_table[bucket]
        LD      L, A
        LD      H, 0
        ADD     HL, HL              ; *2
        PUSH    DE
        LD      DE, hash_table
        ADD     HL, DE
        POP     DE
        ; Restore bucket head
        LD      (HL), E
        INC     HL
        LD      (HL), D
        POP     AF
        OR      A
        JR      NZ, .ul_loop
        RET

; -----------------------------------------------
; asm_reset_label_state — Reset all label/fixup state to empty.
; -----------------------------------------------
asm_reset_label_state:
        XOR     A
        LD      (asm_label_count), A
        LD      (asm_fixup_count), A
        LD      HL, asm_label_dict
        LD      (asm_label_dict_ptr), HL
        RET

; =====================================================================
; Compact register/condition-code lookup table
; =====================================================================
; Used by w_ASM_RECOGNIZE to resolve register names at interpret time.
; Format: DB name_len, "NAME", tag_byte per entry, terminated by DB 0.
asm_reg_table:
        ; REG8 (class 0x00, index = r-field)
        DB 1, "B", 0x00
        DB 1, "C", 0x01
        DB 1, "D", 0x02
        DB 1, "E", 0x03
        DB 1, "H", 0x04
        DB 1, "L", 0x05
        DB 1, "A", 0x07
        ; REG16 (class 0x60)
        DB 2, "BC", 0x60
        DB 2, "DE", 0x61
        DB 2, "HL", 0x62
        DB 2, "AF", 0x63
        DB 2, "SP", 0x64
        DB 2, "IX", 0x65
        DB 2, "IY", 0x66
        DB 3, "AF'", 0x67
        ; INDIRECT (class 0x80)
        DB 4, "(HL)", 0x80
        DB 4, "(IX)", 0x81
        DB 4, "(IY)", 0x82
        DB 4, "(SP)", 0x85
        DB 3, "(C)", 0x86
        DB 4, "(BC)", 0x87
        DB 4, "(DE)", 0x88
        ; Extended REG8
        DB 4, "IREG", 0x08
        DB 4, "RREG", 0x09
        ; COND (class 0x20)
        DB 2, "NZ", 0x20
        DB 1, "Z", 0x21
        DB 2, "NC", 0x22
        DB 2, "CS", 0x23
        DB 2, "PO", 0x24
        DB 2, "PE", 0x25
        DB 1, "P", 0x26
        DB 1, "M", 0x27
        DB 0                            ; sentinel

; =====================================================================
; ASM-RECOGNIZE ( c-addr -- value true | c-addr false )
; =====================================================================
; Recognizer word for register/condition-code names. Scans asm_reg_table
; for a case-insensitive match. Fast-fails when asm_mode == 0.
; No dictionary header — only called from INTERPRET thread, not user-visible.
w_ASM_RECOGNIZE_cf:
        ; Fast-fail if not in assembler mode — BC still = c-addr here
        LD      A, (asm_mode)
        OR      A
        JR      Z, .recog_fast_false

        ; Save DE (threaded IP) — we need DE as scratch for comparison.
        LD      (.recog_save_ip), DE

        ; BC = c-addr (TOS). Load counted string length.
        LD      H, B
        LD      L, C                    ; HL = c-addr
        LD      A, (HL)                 ; A = name length (0 = empty, handled by scan)
        LD      (.recog_len), A         ; save search length
        INC     HL
        LD      (.recog_name), HL       ; save name pointer

        ; Scan table
        LD      HL, asm_reg_table
.recog_next:
        LD      A, (HL)                 ; table entry length
        OR      A
        JR      Z, .recog_no_match      ; sentinel — no match

        ; Compare lengths
        LD      B, A                    ; B = entry name length (also loop counter)
        LD      A, (.recog_len)
        CP      B
        JR      NZ, .recog_skip         ; length mismatch → skip entry

        ; Lengths match — compare name bytes (case-insensitive)
        PUSH    HL                      ; save pointer to length byte
        INC     HL                      ; HL → table name bytes
        LD      DE, (.recog_name)       ; DE = search name pointer
.recog_cmp:
        LD      A, (DE)                 ; search char
        UPPER                           ; convert to uppercase (one expansion per parent label only)
        LD      C, A                    ; C = uppercased search char
        LD      A, (HL)                 ; table char (already uppercase)
        CP      C
        JR      NZ, .recog_cmp_fail
        INC     HL
        INC     DE
        DJNZ    .recog_cmp

        ; Match found! HL points to tag byte.
        LD      C, (HL)                 ; C = tag byte
        POP     HL                      ; discard saved length ptr
        LD      DE, (.recog_save_ip)    ; restore IP
        ; Push tag value as NOS, TRUE as TOS.
        LD      B, ASM_TAG_HI           ; BC = 0xFFxx tag value
        PUSH    BC                      ; push tag value
        LD      BC, 0xFFFF              ; TRUE
        NEXT

.recog_cmp_fail:
        POP     HL                      ; HL = length byte of this entry
        LD      B, (HL)                 ; B = full name length (re-read)
        ; fall through to .recog_skip
.recog_skip:
        ; HL at length byte, B = name length.
        ; Advance past: length(1) + name(B) + tag(1)
        INC     HL                      ; skip length byte
        LD      C, B
        LD      B, 0
        ADD     HL, BC                  ; skip name bytes
        INC     HL                      ; skip tag byte
        JR      .recog_next

.recog_no_match:
        ; Table exhausted or empty name. Restore DE and c-addr.
        LD      DE, (.recog_save_ip)    ; restore IP
        LD      HL, (.recog_name)
        DEC     HL                      ; HL = c-addr (count byte)
        LD      B, H
        LD      C, L                    ; BC = c-addr (restored TOS)
        PUSH    BC                      ; push c-addr
        LD      BC, 0                   ; FALSE
        NEXT

.recog_fast_false:
        ; BC = c-addr (still valid, DE untouched or restored above)
        PUSH    BC                      ; push c-addr
        LD      BC, 0                   ; FALSE
        NEXT

; Scratch storage for recognizer
.recog_len:       DB 0
.recog_name:      DW 0
.recog_save_ip:   DW 0

; =====================================================================
; Special assembler words with unique bodies (not handled by recognizer)
; =====================================================================

; --- () — absolute memory address marker (Story 5.0.5, Task 4)
;     Wraps a bare integer address as an indirect-memory tag. Two cells
;     pushed: the address value (under) and the INDIRECT|ABS tag on top.
;     Mirrors `#` but for memory addresses instead of immediates. ---
w_ABS_PAREN:
        DEFCODE "()", 0
w_ABS_PAREN_cf:
        CALL    check_asm_mode
        ; TOS (BC) = address value (bare integer). Push it as NOS, tag on TOS.
        PUSH    BC                      ; address becomes NOS
        LD      C, ASM_CLASS_INDIRECT | ASM_IND_ABS ; 0x89
        LD      B, ASM_TAG_HI           ; B = 0xFF → BC = 0xFF89
        NEXT

; --- Immediate-marker word `#` — pushes 0xFF40 (class=010, index=0)
;     on TOS, leaving the value the user just typed in NOS. ---
w_HASH:
        DEFCODE "#", 0
w_HASH_cf:
        CALL    check_asm_mode
        PUSH    BC                      ; old TOS becomes NOS
        LD      C, ASM_CLASS_IMM        ; C = 0x40
        LD      B, ASM_TAG_HI           ; B = 0xFF → BC = 0xFF40
        NEXT

; --- Tag predicates (Z if matching class) — used by LD,, arith, RET,, etc.
;     All assume B==0xFF has already been verified (via asm_check_tagged
;     or inline check). They test the class bits of C.

asm_is_imm_tag:
        LD      A, ASM_CLASS_IMM
        JR      asm_is_class_check

asm_is_label_tag:
        LD      A, ASM_CLASS_LABEL
        JR      asm_is_class_check

asm_is_reg16_tag:
        LD      A, ASM_CLASS_REG16
        JR      asm_is_class_check

asm_is_indirect_tag:
        LD      A, ASM_CLASS_INDIRECT
        ; fall through

asm_is_class_check:                     ; asm_is_indirect_tag falls through here
        XOR     C
        AND     ASM_CLASS_MASK
        RET

asm_get_class:
        LD      A, C
        AND     ASM_CLASS_MASK
        RET

asm_get_index:
        LD      A, C
        AND     ASM_INDEX_MASK
        RET

; -----------------------------------------------
; asm_is_ixiy_indexed — Check if TOS is (IX+d) or (IY+d) tag.
;   Entry: BC = TOS (B==0xFF already verified)
;   Exit:  Z set if indexed; A = index (3 or 4)
; -----------------------------------------------
asm_is_ixiy_indexed:
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_INDIRECT
        RET     NZ
        LD      A, C
        AND     ASM_INDEX_MASK
        CP      ASM_IND_IXD
        RET     Z
        CP      ASM_IND_IYD
        RET

; -----------------------------------------------
; asm_emit_ixiy_prefix — Emit DD (IX) or FD (IY) prefix byte.
;   Entry: A = indirect index (1=IX, 2=IY, 3=IX+d, 4=IY+d)
;          OR reg16 index (5=IX, 6=IY)
;   Clobbers: A, HL
; -----------------------------------------------
asm_emit_ixiy_prefix:
        CP      ASM_IND_IY
        JR      Z, .emit_fd
        CP      ASM_IND_IYD
        JR      Z, .emit_fd
        CP      ASM_IY_INDEX
        JR      Z, .emit_fd
        LD      A, 0xDD
        JP      asm_emit_byte
.emit_fd:
        LD      A, 0xFD
        JP      asm_emit_byte

; -----------------------------------------------
; asm_pop_indexed_disp — Pop displacement cell below indexed tag.
;   Entry: BC was the indexed tag (already consumed); Forth param stack
;          has displacement on top, then old TOS below.
;   Exit:  A = displacement byte, BC = new TOS (from under disp)
;   Clobbers: HL
;   Preserves: DE (IP)
; -----------------------------------------------
asm_pop_indexed_disp:
        POP     HL                      ; HL = return address
        EX      (SP), HL               ; HL = displacement cell, ret addr on stack
        LD      A, L                    ; A = displacement byte
        POP     HL                      ; HL = return address (was swapped onto stack)
        EX      (SP), HL               ; HL = old TOS, ret addr back on stack
        LD      B, H
        LD      C, L                    ; BC = new TOS
        RET

; =====================================================================
; +D ( (IX)|tag disp -- (IX+d)|tag )  displacement combiner
;   Pops TOS = displacement (bare integer), NOS = (IX) or (IY) tag.
;   Pushes: displacement cell, then (IX+d) or (IY+d) tag.
; =====================================================================
w_PLUS_D:
        DEFCODE "+D", 0
w_PLUS_D_cf:
        CALL    check_asm_mode
        ; TOS (BC) = displacement (bare integer)
        ; Range check: must fit signed 8-bit (-128..+127)
        ; B=0x00 and C<=0x7F (positive), or B=0xFF and C>=0x80 (negative).
        ; No tag check here: B=0xFF overlaps with negative integers.
        ; The range check rejects most tag values, and the NOS check
        ; (must be (IX)/(IY)) catches remaining misuse.
        LD      A, B
        OR      A
        JR      Z, .pd_pos
        CP      0xFF
        JP      NZ, asm_range_err
        ; B=0xFF: check C >= 0x80
        BIT     7, C
        JP      Z, asm_range_err
        JR      .pd_range_ok
.pd_pos:
        ; B=0x00: check C <= 0x7F
        BIT     7, C
        JP      NZ, asm_range_err
.pd_range_ok:
        ; Save displacement
        LD      A, C
        LD      (asm_tmp), A
        ; Pop NOS = must be (IX) or (IY) bare tag
        POP     BC
        CALL    asm_check_tagged
        CALL    asm_is_indirect_tag
        JP      NZ, asm_bad_operand
        CALL    asm_get_index
        CP      ASM_IND_IX
        JR      Z, .pd_ix
        CP      ASM_IND_IY
        JR      Z, .pd_iy
        JP      asm_bad_operand
.pd_ix:
        ; Push displacement cell, then (IX+d) tag
        LD      A, (asm_tmp)
        LD      C, A
        LD      B, 0
        OR      A
        JP      P, .pd_ix_push
        LD      B, 0xFF                 ; sign-extend negative
.pd_ix_push:
        PUSH    BC
        LD      C, ASM_CLASS_INDIRECT | ASM_IND_IXD ; 0x83
        LD      B, ASM_TAG_HI
        NEXT
.pd_iy:
        LD      A, (asm_tmp)
        LD      C, A
        LD      B, 0
        OR      A
        JP      P, .pd_iy_push
        LD      B, 0xFF
.pd_iy_push:
        PUSH    BC
        LD      C, ASM_CLASS_INDIRECT | ASM_IND_IYD ; 0x84
        LD      B, ASM_TAG_HI
        NEXT

; -----------------------------------------------
; asm_range_err — Print "range ?" and ABORT.
; -----------------------------------------------
asm_range_err:
        LD      HL, str_asm_range
        LD      B, STR_ASM_RANGE_LEN
        JP      asm_die

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
        CALL    rpush_de
        CALL    rpush_bc

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
        LD      (asm_body_start), HL

        ; Reset per-CODE label/fixup state
        CALL    asm_reset_label_state

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

        ; Save DE (IP) and BC (TOS) to return stack — the helpers below
        ; (asm_check_unresolved, asm_unlink_labels) clobber DE/BC freely.
        CALL    rpush_de
        CALL    rpush_bc

        ; Check for unresolved fixups — if any remain, that helper
        ; ABORTs (which routes through asm_cleanup for full rollback).
        CALL    asm_check_unresolved

        ; Unlink all label dictionary entries from the global hash table
        ; (success path — labels are per-CODE only).
        CALL    asm_unlink_labels

        ; Reset label/fixup state on the success path too, so that the
        ; next CODE word starts from a clean baseline.
        CALL    asm_reset_label_state

        ; Restore LATEST to the CODE word entry (it may currently point
        ; at the last LABEL's dict entry in the side area).
        LD      HL, (asm_saved_here)
        LD      (IY+UserArea.latest), L
        LD      (IY+UserArea.latest+1), H

        ; Clear SMUDGE on the new word
        LD      HL, (asm_smudge_addr)
        LD      A, (HL)
        AND     0xBF                    ; = ~F_SMUDGE & 0xFF
        LD      (HL), A

        ; Leave assembler mode
        XOR     A
        LD      (asm_mode), A

        ; Restore BC (TOS) and DE (IP)
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX
        NEXT

; =====================================================================
; Opcode words — PUSH, / POP, (16-bit register-pair operand)
; =====================================================================

; -----------------------------------------------
; asm_pushpop_word — Shared tail for PUSH, and POP,.
;   Entry: A = base opcode (0xC5 for PUSH, 0xC1 for POP)
;   Validates TOS = reg16 tag (class=011, index 0..3: BC/DE/HL/AF).
;   Rejects SP (index 4) and any non-reg16 tag.
; -----------------------------------------------
asm_pushpop_word:
        LD      (asm_tmp), A            ; spill base opcode
        CALL    check_asm_mode
        CALL    asm_check_tagged        ; verify B==0xFF
        CALL    asm_is_reg16_tag
        JP      NZ, asm_bad_operand     ; not a 16-bit register
        CALL    asm_get_index           ; A = index (0..6)
        CP      ASM_IX_INDEX
        JR      Z, .pp_ixiy
        CP      ASM_IY_INDEX
        JR      Z, .pp_ixiy
        CP      4
        JP      NC, asm_bad_operand     ; SP (4) or out of range
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
.pp_ixiy:
        ; PUSH/POP IX/IY: emit DD/FD prefix then E5 (PUSH) or E1 (POP)
        CALL    asm_emit_ixiy_prefix
        LD      A, (asm_tmp)
        ; base for PUSH=0xC5, POP=0xC1; HL pair qq=2: PUSH HL=E5, POP HL=E1
        ; 0xC5 + (2<<4) = 0xE5, 0xC1 + (2<<4) = 0xE1
        AND     0x0F                    ; keep low nibble (5=PUSH, 1=POP)
        OR      0xE0                    ; E5 or E1
        CALL    asm_emit_byte
        POP     BC
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
; assert_8bit_reg — HL = unified tag; reject if H!=0xFF or not class=REG8.
;   On success: A = r-field (0..7 excluding 6)
;   On failure: JP asm_bad_operand or asm_err_bare_int (never returns)
; -----------------------------------------------
assert_8bit_reg:
        LD      A, H
        CP      ASM_TAG_HI
        JP      NZ, asm_err_bare_int    ; bare integer
        LD      A, L
        AND     ASM_CLASS_MASK
        JP      NZ, asm_bad_operand     ; class != REG8 (0x00)
        LD      A, L
        AND     ASM_INDEX_MASK          ; A = r-field
        CP      8
        JP      NC, asm_bad_operand
        RET

; Permissive variant: accepts class=REG8 (r-field 0..7) OR class=INDIRECT
; ((HL) → returns r-field 6). Used by LD, where memory-via-HL is valid.
assert_8bit_reg_or_ihl:
        LD      A, H
        CP      ASM_TAG_HI
        JP      NZ, asm_err_bare_int    ; bare integer
        LD      A, L
        AND     ASM_CLASS_MASK
        JR      Z, .a8ihl_reg8          ; class=REG8
        CP      ASM_CLASS_INDIRECT
        JP      NZ, asm_bad_operand     ; not REG8 or INDIRECT
        ; Verify index==0 (only (HL) is valid here, not (BC)/(DE)/() etc.)
        LD      A, L
        AND     ASM_INDEX_MASK
        JP      NZ, asm_bad_operand     ; reject non-(HL) indirect
        LD      A, 6                    ; (HL) → r-field = 6
        RET
.a8ihl_reg8:
        LD      A, L
        AND     ASM_INDEX_MASK
        CP      8
        JP      NC, asm_bad_operand
        RET

; -----------------------------------------------
; LD, ( dst src -- )  emits LD r, r' (0x40 | (dst<<3) | src)
;   Zilog operand order: NOS = destination, TOS = source.
; -----------------------------------------------
w_LD_COMMA:
        DEFCODE "LD,", 0
w_LD_COMMA_cf:
        CALL    check_asm_mode
        CALL    asm_check_tagged        ; TOS must be tagged
        ; Class-indexed dispatch on source operand
        LD      A, C
        AND     ASM_CLASS_MASK
        JR      Z, .ldc_reg8_src        ; REG8 (0x00)
        CP      ASM_CLASS_INDIRECT
        JR      Z, .ldc_indirect_src    ; INDIRECT (0x80)
        CP      ASM_CLASS_IMM
        JP      Z, .ldc_imm             ; IMM (0x40)
        CP      ASM_CLASS_REG16
        JP      Z, .ldc_r16_src         ; REG16 (0x60)
        JP      asm_bad_operand         ; COND/LABEL = error

; --- INDIRECT sub-dispatch ---
.ldc_indirect_src:
        LD      A, C
        AND     ASM_INDEX_MASK
        OR      A
        JR      Z, .ldc_r8_cont         ; (HL) index=0 → reg-to-reg path
        CP      ASM_IND_IXD
        JP      Z, .ldc_idx_src
        CP      ASM_IND_IYD
        JP      Z, .ldc_idx_src
        CP      ASM_IND_BC
        JP      Z, .ldc_ibc_src
        CP      ASM_IND_DE
        JP      Z, .ldc_ide_src
        CP      ASM_IND_ABS
        JP      Z, .ldc_abs_src
        JP      asm_bad_operand

; --- REG8 sub-dispatch (I/R check, then fallthrough to reg-to-reg) ---
.ldc_reg8_src:
        LD      A, C
        AND     ASM_INDEX_MASK
        CP      ASM_REG8_I
        JP      Z, .ldc_ir_src
        CP      ASM_REG8_R
        JP      Z, .ldc_ir_src
.ldc_r8_cont:
        ; Register-to-register path — Zilog dst-src: NOS = dst, TOS = src.
        LD      H, B
        LD      L, C
        CALL    assert_8bit_reg_or_ihl  ; A = src r-value (0..7)
        LD      (asm_tmp), A
        POP     HL                      ; HL = destination tag (NOS)
        ; Check if dst is indexed
        LD      A, H
        CP      ASM_TAG_HI
        JP      NZ, asm_err_bare_int
        LD      A, L
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_INDIRECT
        JR      Z, .ldc_chk_idx_dst
        ; Story 5.0.5: check for I/R as destination
        OR      A                       ; class == REG8 (0x00)?
        JR      NZ, .ldc_normal_reg_dst
        LD      A, L
        AND     ASM_INDEX_MASK
        CP      ASM_REG8_I
        JP      Z, .ldc_i_dst
        CP      ASM_REG8_R
        JP      Z, .ldc_r_dst
.ldc_normal_reg_dst:
        ; Normal register dst
        CALL    assert_8bit_reg_or_ihl  ; A = dst r-value
        ; Reject LD (HL),(HL) — opcode 0x76 is HALT, not LD.
        LD      H, A
        LD      A, (asm_tmp)
        CP      6
        JR      NZ, .ldc_emit
        LD      A, H
        CP      6
        JP      Z, asm_bad_operand
.ldc_emit:
        LD      A, H                    ; A = dst
        RLCA
        RLCA
        RLCA                            ; A = dst << 3
        OR      0x40
        LD      HL, asm_tmp
        OR      (HL)                    ; A |= src
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ldc_chk_idx_dst:
        ; HL = dst tag (INDIRECT class). Check for indexed.
        LD      A, L
        AND     ASM_INDEX_MASK
        CP      ASM_IND_IXD
        JR      Z, .ldc_idx_dst
        CP      ASM_IND_IYD
        JR      Z, .ldc_idx_dst
        ; Story 5.0.5: check for (BC)/(DE)/() as destination
        CP      ASM_IND_BC
        JP      Z, .ldc_ibc_dst
        CP      ASM_IND_DE
        JP      Z, .ldc_ide_dst
        CP      ASM_IND_ABS
        JP      Z, .ldc_abs_r8_dst
        ; Could be (HL) — index 0 → r-field 6
        OR      A
        JP      NZ, asm_bad_operand
        LD      A, 6                    ; (HL) r-field
        JR      .ldc_ihl_dst

.ldc_ihl_dst:
        ; dst is (HL), src r-field in asm_tmp
        LD      H, A
        LD      A, (asm_tmp)
        CP      6
        JP      Z, asm_bad_operand      ; LD (HL),(HL)
        LD      A, H
        RLCA
        RLCA
        RLCA
        OR      0x40
        LD      HL, asm_tmp
        OR      (HL)
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ldc_idx_dst:
        ; NOS is indexed = SOURCE per AC: LD r,(IX+d)
        ; asm_tmp = dst r-field, HL = indexed tag
        PUSH    AF                      ; save index
        LD      A, L
        AND     ASM_INDEX_MASK
        CALL    asm_emit_ixiy_prefix    ; emit DD/FD
        ; LD r,(IX+d) = DD 46|(dst_r<<3) dd
        LD      A, (asm_tmp)            ; dst r-field
        RLCA
        RLCA
        RLCA
        OR      0x46
        CALL    asm_emit_byte
        POP     AF                      ; discard saved index
        POP     BC                      ; BC = displacement cell
        LD      A, C
        CALL    asm_emit_byte           ; emit displacement
        POP     BC                      ; new TOS
        NEXT

.ldc_r16_src:
        ; TOS is a reg16 — check NOS for () absolute or LD SP,IX/IY
        CALL    asm_get_index
        LD      (asm_tmp), A            ; save source reg16 index
        ; Peek NOS to check for () destination
        POP     HL
        PUSH    HL                      ; peek and restore NOS
        LD      A, H
        CP      ASM_TAG_HI
        JR      NZ, .ldc_r16_chk_sp    ; NOS not tagged
        LD      A, L
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_INDIRECT
        JR      NZ, .ldc_r16_chk_sp
        LD      A, L
        AND     ASM_INDEX_MASK
        CP      ASM_IND_ABS
        JP      Z, .ldc_r16_abs_dst
.ldc_r16_chk_sp:
        ; Existing: LD SP,IX / LD SP,IY
        LD      A, (asm_tmp)
        CP      ASM_IX_INDEX
        JR      Z, .ldc_sp_ixiy
        CP      ASM_IY_INDEX
        JR      Z, .ldc_sp_ixiy
        JP      asm_bad_operand
.ldc_sp_ixiy:
        LD      (asm_tmp), A            ; save IX/IY index
        POP     BC                      ; NOS = destination
        CALL    asm_check_tagged
        CALL    asm_is_reg16_tag
        JP      NZ, asm_bad_operand
        CALL    asm_get_index
        CP      4                       ; must be SP
        JP      NZ, asm_bad_operand
        LD      A, (asm_tmp)
        CALL    asm_emit_ixiy_prefix    ; DD or FD
        LD      A, 0xF9                 ; LD SP,HL
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ldc_idx_src:
        ; TOS is indexed = DESTINATION per AC: LD (IX+d),r
        ; TOS = indexed tag (BC). Need to get src register from under displacement.
        CALL    asm_get_index           ; A = 3(IXD) or 4(IYD)
        CALL    asm_emit_ixiy_prefix    ; emit DD/FD
        ; Pop displacement
        POP     BC                      ; BC = displacement
        LD      A, C
        LD      (asm_tmp), A            ; save displacement
        ; Pop source register
        POP     BC                      ; BC = src tag
        CALL    asm_check_tagged
        CALL    asm_get_class
        JP      NZ, asm_bad_operand     ; must be REG8
        CALL    asm_get_index
        CP      8
        JP      NC, asm_bad_operand
        ; LD (IX+d),r = DD 70|r dd
        OR      0x70
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ldc_imm:
        ; TOS is imm marker — pop value and destination.
        POP     BC                      ; BC = value
        POP     HL                      ; HL = destination tag
        LD      A, H
        CP      ASM_TAG_HI
        JP      NZ, asm_err_bare_int
        ; Classify destination by class bits.
        LD      A, L
        AND     ASM_CLASS_MASK
        JR      Z, .ldc_imm8            ; class=REG8
        CP      ASM_CLASS_REG16
        JR      Z, .ldc_imm16
        CP      ASM_CLASS_INDIRECT
        JP      Z, .ldc_imm_idx
        JP      asm_bad_operand

.ldc_imm16:
        ; 16-bit dest: index 0..6 = BC/DE/HL/AF/SP/IX/IY. Reject AF (3).
        LD      A, L
        AND     ASM_INDEX_MASK
        CP      ASM_IX_INDEX
        JR      Z, .ldc_imm16_ixiy
        CP      ASM_IY_INDEX
        JR      Z, .ldc_imm16_ixiy
        CP      5
        JP      NC, asm_bad_operand
        CP      3
        JP      Z, asm_bad_operand      ; AF → no LD AF, nn
        ; Map index to rp: BC=0, DE=1, HL=2, SP→index 4 maps to rp=3.
        CP      4
        JR      NZ, .ldc_imm16_qq
        LD      A, 3
.ldc_imm16_qq:
        RLCA
        RLCA
        RLCA
        RLCA                            ; A = rp << 4
        OR      0x01
        CALL    asm_emit_byte
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ldc_imm16_ixiy:
        ; LD IX/IY,nn = DD/FD 21 lo hi
        CALL    asm_emit_ixiy_prefix    ; A = IX/IY index from dispatch
        LD      A, 0x21
        CALL    asm_emit_byte
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ldc_imm8:
        LD      A, L
        AND     ASM_INDEX_MASK
        CP      6
        JP      Z, asm_bad_operand
        ; opcode = 0x06 | (r << 3)
        RLCA
        RLCA
        RLCA
        OR      0x06
        CALL    asm_emit_byte
        LD      A, C
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ldc_imm_idx:
        ; LD (IX+d),n / LD (IY+d),n
        ; HL = dst indirect tag, BC = value (from imm pop above)
        LD      A, L
        AND     ASM_INDEX_MASK
        CP      ASM_IND_IXD
        JR      Z, .ldc_imm_ixiyd
        CP      ASM_IND_IYD
        JR      Z, .ldc_imm_ixiyd
        JP      asm_bad_operand
.ldc_imm_ixiyd:
        ; LD (IX+d),n / LD (IY+d),n = DD/FD 36 disp val
        CALL    asm_emit_ixiy_prefix    ; A = IXD/IYD index from dispatch
        LD      A, C
        LD      (asm_tmp), A            ; save value
        LD      A, 0x36                 ; LD (HL),n opcode
        CALL    asm_emit_byte
        POP     BC                      ; BC = displacement cell
        LD      A, C
        CALL    asm_emit_byte           ; emit displacement
        LD      A, (asm_tmp)
        CALL    asm_emit_byte           ; emit value
        POP     BC
        NEXT

; =====================================================================
; Story 5.0.5 / 6.5 LD, extensions — indirect/register forms
;   (handler pairs merged with H-parameter technique in 6.5)
; =====================================================================

; --- (BC)/(DE) as source: LD A,(BC) / LD A,(DE) ---
; Merged handler — H holds opcode, shared validation below.
.ldc_ibc_src:
        LD      H, 0x0A                 ; LD A,(BC) opcode
        JR      .ldc_ind_a_src
.ldc_ide_src:
        LD      H, 0x1A                 ; LD A,(DE) opcode
        ; fall through
.ldc_ind_a_src:
        POP     BC                      ; BC = destination tag
        CALL    asm_check_tagged
        CALL    asm_get_class
        JP      NZ, asm_bad_operand     ; must be REG8
        CALL    asm_get_index
        CP      7                       ; must be A
        JP      NZ, asm_bad_operand
        LD      A, H
        CALL    asm_emit_byte
        POP     BC
        NEXT

; --- () as source: LD dst,(nn) ---
.ldc_abs_src:
        ; TOS = () tag. NOS = address. NNOS = destination.
        POP     BC                      ; BC = address (lo=C, hi=B)
        POP     HL                      ; HL = destination tag
        LD      A, H
        CP      ASM_TAG_HI
        JP      NZ, asm_err_bare_int
        ; Save address
        PUSH    BC                      ; save address on stack
        ; Classify destination
        LD      A, L
        AND     ASM_CLASS_MASK
        JR      Z, .ldabs_r8_dst        ; class=REG8
        CP      ASM_CLASS_REG16
        JR      Z, .ldabs_r16_dst
        JP      asm_bad_operand

.ldabs_r8_dst:
        LD      A, L
        AND     ASM_INDEX_MASK
        CP      7                       ; must be A
        JP      NZ, asm_bad_operand
        ; LD A,(nn) = 0x3A lo hi
        LD      A, 0x3A
        CALL    asm_emit_byte
        POP     BC                      ; BC = address (lo=C, hi=B)
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ldabs_r16_dst:
        LD      A, L
        AND     ASM_INDEX_MASK
        CP      2                       ; HL
        JR      Z, .ldabs_hl
        CP      ASM_IX_INDEX
        JR      Z, .ldabs_ixiy
        CP      ASM_IY_INDEX
        JR      Z, .ldabs_ixiy
        ; ED-prefix: BC(0), DE(1), SP(4)
        CP      3
        JP      Z, asm_bad_operand      ; AF
        CP      ASM_IX_INDEX
        JP      NC, asm_bad_operand
        CP      4
        JR      NZ, .ldabs_ed
        LD      A, 3                    ; SP: index 4 → rp 3
.ldabs_ed:
        ; LD rr,(nn) = ED 4B|(rp<<4) lo hi
        RLCA
        RLCA
        RLCA
        RLCA
        OR      0x4B
        LD      (asm_tmp), A
        LD      A, 0xED
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        CALL    asm_emit_byte
        POP     BC                      ; BC = address (lo=C, hi=B)
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ldabs_hl:
        ; LD HL,(nn) = 0x2A lo hi
        LD      A, 0x2A
        CALL    asm_emit_byte
        POP     BC                      ; BC = address (lo=C, hi=B)
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ldabs_ixiy:
        ; LD IX/IY,(nn) = DD/FD 2A lo hi
        CALL    asm_emit_ixiy_prefix    ; A = IX/IY index from dispatch
        LD      A, 0x2A
        CALL    asm_emit_byte
        POP     BC                      ; BC = address (lo=C, hi=B)
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT

; --- I/R as source: LD A,I / LD A,R ---
.ldc_ir_src:
        ; TOS = I or R (REG8 index 8 or 9). Pop, check NOS = A.
        CALL    asm_get_index           ; A = 8 (I) or 9 (R)
        LD      (asm_tmp), A            ; save I/R index
        POP     BC                      ; BC = NOS = destination tag
        CALL    asm_check_tagged
        CALL    asm_get_class
        JP      NZ, asm_bad_operand     ; must be REG8
        CALL    asm_get_index
        CP      7                       ; must be A
        JP      NZ, asm_bad_operand
        ; LD A,I = ED 57, LD A,R = ED 5F
        LD      A, 0xED
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        CP      ASM_REG8_I
        JR      Z, .ldc_ai
        LD      A, 0x5F                 ; LD A,R
        JR      .ldc_ir_emit
.ldc_ai:
        LD      A, 0x57                 ; LD A,I
.ldc_ir_emit:
        CALL    asm_emit_byte
        POP     BC
        NEXT

; --- (BC)/(DE) as destination: LD (BC),A / LD (DE),A ---
; Merged handler — H holds opcode, shared validation below.
.ldc_ibc_dst:
        LD      H, 0x02                 ; LD (BC),A opcode
        JR      .ldc_ind_a_dst
.ldc_ide_dst:
        LD      H, 0x12                 ; LD (DE),A opcode
        ; fall through
.ldc_ind_a_dst:
        LD      A, (asm_tmp)
        CP      7                       ; only A
        JP      NZ, asm_bad_operand
        LD      A, H
        CALL    asm_emit_byte
        POP     BC
        NEXT

; --- () as destination from REG8: LD (nn),A ---
.ldc_abs_r8_dst:
        ; NOS popped into HL = () tag. asm_tmp = src r-field.
        LD      A, (asm_tmp)
        CP      7                       ; only A
        JP      NZ, asm_bad_operand
        ; Pop address from under () tag
        POP     BC                      ; BC = address (lo=C, hi=B)
        LD      A, 0x32                 ; LD (nn),A
        CALL    asm_emit_byte
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT

; --- () as destination from REG16: LD (nn),rr ---
.ldc_r16_abs_dst:
        ; NOS is () tag (peeked and verified). Pop it, pop address.
        POP     HL                      ; discard () tag (was peeked)
        POP     BC                      ; BC = address (lo=C, hi=B)
        LD      A, (asm_tmp)            ; source reg16 index
        CP      2                       ; HL
        JR      Z, .ldr16abs_hl
        CP      ASM_IX_INDEX
        JR      Z, .ldr16abs_ixiy
        CP      ASM_IY_INDEX
        JR      Z, .ldr16abs_ixiy
        ; ED-prefix: BC(0), DE(1), SP(4)
        CP      3
        JP      Z, asm_bad_operand      ; AF
        CP      ASM_IX_INDEX
        JP      NC, asm_bad_operand
        CP      4
        JR      NZ, .ldr16abs_ed
        LD      A, 3                    ; SP: index 4 → rp 3
.ldr16abs_ed:
        ; LD (nn),rr = ED 43|(rp<<4) lo hi
        ; BC = address (preserved by asm_emit_byte)
        RLCA
        RLCA
        RLCA
        RLCA
        OR      0x43
        LD      (asm_tmp), A
        LD      A, 0xED
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        CALL    asm_emit_byte
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT
.ldr16abs_hl:
        ; LD (nn),HL = 0x22 lo hi. BC = address.
        LD      A, 0x22
        CALL    asm_emit_byte
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT
.ldr16abs_ixiy:
        ; LD (nn),IX/IY = DD/FD 22 lo hi. BC = address.
        CALL    asm_emit_ixiy_prefix    ; A = IX/IY index from dispatch
        LD      A, 0x22
        CALL    asm_emit_byte
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT

; --- I/R as destination: LD I,A / LD R,A ---
; Merged handler — H holds second opcode byte, shared validation below.
.ldc_i_dst:
        LD      H, 0x47                 ; LD I,A second byte
        JR      .ldc_ir_dst
.ldc_r_dst:
        LD      H, 0x4F                 ; LD R,A second byte
        ; fall through
.ldc_ir_dst:
        LD      A, (asm_tmp)
        CP      7                       ; only A
        JP      NZ, asm_bad_operand
        PUSH    HL                      ; save H (opcode byte)
        LD      A, 0xED
        CALL    asm_emit_byte           ; clobbers HL
        POP     HL                      ; restore H
        LD      A, H
        CALL    asm_emit_byte
        POP     BC
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
        CALL    asm_check_tagged        ; TOS must be tagged
        CALL    asm_is_imm_tag
        JR      Z, .arith_imm
        ; Check for indexed operand
        CALL    asm_is_ixiy_indexed
        JR      Z, .arith_idx
        ; Check for (HL) indirect
        CALL    asm_is_indirect_tag
        JR      Z, .arith_ihl
        ; Register form.
        CALL    asm_get_r8              ; A = r-field
        LD      HL, asm_tmp
        OR      (HL)                    ; A = base | r
        CALL    asm_emit_byte
        POP     BC
        NEXT
.arith_ihl:
        CALL    asm_get_index
        OR      A
        JP      NZ, asm_bad_operand     ; only (HL) index=0
        LD      A, (asm_tmp)
        OR      0x06                    ; (HL) r-field
        CALL    asm_emit_byte
        POP     BC
        NEXT
.arith_idx:
        ; ADD A,(IX+d) = DD base|06 dd
        CALL    asm_get_index
        CALL    asm_emit_ixiy_prefix    ; DD or FD
        LD      A, (asm_tmp)
        OR      0x06                    ; (HL) r-field
        CALL    asm_emit_byte
        CALL    asm_pop_indexed_disp    ; A = disp, BC = new TOS
        CALL    asm_emit_byte
        NEXT
.arith_imm:
        POP     BC                      ; new TOS = value (n)
        LD      A, (asm_tmp)
        AND     0x38
        OR      0xC6
        CALL    asm_emit_byte
        LD      A, C
        CALL    asm_emit_byte
        POP     BC
        NEXT

w_ADD_COMMA:
        DEFCODE "ADD,", 0
w_ADD_COMMA_cf:
        ; Check if TOS is REG16 → 16-bit ADD HL,rr / ADD IX,rr / ADD IY,rr
        LD      A, B
        CP      ASM_TAG_HI
        JR      NZ, .add_8bit
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_REG16
        JR      Z, .add_16bit
.add_8bit:
        LD      A, 0x80
        JP      asm_arith_word
.add_16bit:
        CALL    check_asm_mode
        ; TOS (BC) = source reg16, extract index
        CALL    asm_get_index           ; A = source index
        LD      (asm_tmp), A            ; save raw source index
        ; Pop NOS = destination
        POP     BC
        CALL    asm_check_tagged
        CALL    asm_is_reg16_tag
        JP      NZ, asm_bad_operand
        CALL    asm_get_index           ; A = destination index
        ; Destination must be HL(2), IX(5), or IY(6)
        CP      2
        JR      Z, .add16_dst_hl
        CP      ASM_IX_INDEX
        JR      Z, .add16_dst_ixiy
        CP      ASM_IY_INDEX
        JR      Z, .add16_dst_ixiy
        JP      asm_bad_operand
.add16_dst_hl:
        ; ADD HL,rr — source must be BC(0), DE(1), HL(2), SP(4)
        LD      A, (asm_tmp)
        CP      3
        JP      Z, asm_bad_operand      ; reject AF
        CP      ASM_IX_INDEX
        JP      NC, asm_bad_operand     ; reject IX, IY, AF'
        ; Map index to rp: 0→0, 1→1, 2→2, 4→3
        CP      4
        JR      NZ, .add16_hl
        LD      A, 3                    ; SP: index 4 → rp 3
        JR      .add16_hl
.add16_dst_ixiy:
        ; ADD IX,rr / ADD IY,rr — source can be BC(0), DE(1), same-reg(→rp2), SP(4)
        LD      (asm_tmp+1), A          ; save destination index (IX=5 or IY=6)
        LD      A, (asm_tmp)            ; reload source index
        CP      3
        JP      Z, asm_bad_operand      ; reject AF
        ; Accept IX/IY as source ONLY if same as destination (ADD IX,IX / ADD IY,IY)
        CP      ASM_IX_INDEX
        JR      Z, .add16_ixiy_src_ixiy
        CP      ASM_IY_INDEX
        JR      Z, .add16_ixiy_src_ixiy
        ; Source is BC(0), DE(1), HL(2), or SP(4)
        CP      ASM_AFP_INDEX
        JP      NC, asm_bad_operand     ; reject AF'(7)+
        CP      4
        JR      NZ, .add16_ixiy_emit
        LD      A, 3                    ; SP: index 4 → rp 3
        JR      .add16_ixiy_emit
.add16_ixiy_src_ixiy:
        ; Source is IX or IY — must match destination
        LD      HL, asm_tmp+1
        CP      (HL)                    ; source index == dest index?
        JP      NZ, asm_bad_operand     ; reject cross-index (IX+IY)
        LD      A, 2                    ; same-reg → rp 2 (HL slot under prefix)
.add16_ixiy_emit:
        LD      (asm_tmp), A            ; save source rp
        LD      A, (asm_tmp+1)          ; reload dest index for prefix
        CALL    asm_emit_ixiy_prefix    ; DD or FD
        LD      A, (asm_tmp)            ; reload source rp
        JR      .add16_emit             ; share emit with HL path
.add16_hl:
        ; ADD HL,rr = 0x09 | (rp<<4)
        ; A already holds rp (or was set to 3 for SP)
.add16_emit:
        RLCA
        RLCA
        RLCA
        RLCA
        OR      0x09
        CALL    asm_emit_byte
        POP     BC
        NEXT

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
        CALL    rpush_de
        CALL    rpush_bc
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

; =====================================================================
; Label tag push helper — Tail used by all label-word bodies.
;   The body of every LABEL-defined dict entry is exactly:
;       LD      L, slot_index           ; 2 bytes
;       JP      asm_push_label_tag      ; 3 bytes
;   asm_push_label_tag pushes BC = 0xFFA0 | slot_index onto the data
;   stack and refuses to run outside CODE (defence in depth — correct
;   cleanup makes label words unreachable when not in CODE).
; =====================================================================
asm_push_label_tag:
        CALL    check_asm_mode
        PUSH    BC                      ; save old TOS
        LD      A, L
        OR      ASM_CLASS_LABEL         ; A = 0xA0 | slot_index
        LD      C, A
        LD      B, ASM_TAG_HI           ; B = 0xFF → BC = 0xFF | (0xA0|slot)
        NEXT

; =====================================================================
; LABEL ( "<spaces>name" -- )
;   Parse the next whitespace-delimited word, allocate a fresh slot,
;   build a dict entry in the side area whose body pushes the slot's
;   tag, capture bucket info for later unlink.
;   Errors:
;     not in CODE ?              — outside CODE
;     LABEL must precede opcodes ? — HERE has moved past asm_saved_here
;     too many labels ?          — slot pool full
; =====================================================================
w_LABEL:
        DEFCODE "LABEL", 0
w_LABEL_cf:
        CALL    check_asm_mode
        ; Save DE (IP) and BC (TOS) to return stack — build_header
        ; clobbers everything, and the body-start check below also
        ; clobbers DE.
        CALL    rpush_de
        CALL    rpush_bc

        ; "Before any opcodes" check: HERE must equal asm_body_start.
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      DE, (asm_body_start)
        OR      A
        SBC     HL, DE
        JP      NZ, asm_err_label_after

        ; Allocate the slot first (so the index is known when we patch
        ; the body); aborts on overflow.
        CALL    asm_alloc_label_slot    ; A = new slot index
        LD      (asm_tmp), A            ; spill slot idx

        ; Save real HERE (= the CODE-body start) and redirect HERE to
        ; the label dict side area for build_header.
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (asm_tmp2), HL          ; spill real HERE
        LD      HL, (asm_label_dict_ptr)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; build_header with flags=0
        XOR     A
        CALL    build_header
        JR      C, .lbl_no_name
        ; HL = code field address in the side area.
        ; Emit body: LD L, n / JP asm_push_label_tag (5 bytes).
        LD      A, 0x2E                 ; LD L, n opcode
        LD      (HL), A
        INC     HL
        LD      A, (asm_tmp)            ; A = slot index
        LD      (HL), A
        INC     HL
        LD      (HL), 0xC3              ; JP nn opcode
        INC     HL
        LD      (HL), LOW asm_push_label_tag
        INC     HL
        LD      (HL), HIGH asm_push_label_tag
        INC     HL
        ; Save new side-area top.
        LD      (asm_label_dict_ptr), HL

        ; Restore real HERE.
        LD      HL, (asm_tmp2)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; Fill in slot fields: bucket, old_head, cf_ptr.
        LD      A, (asm_tmp)            ; slot index
        CALL    asm_slot_addr           ; HL = &slot
        ; +0 resolved already 0; +1,2 target unset; advance to +3
        INC     HL
        INC     HL
        INC     HL
        LD      A, (bh_bucket_index)
        LD      (HL), A                 ; +3 bucket
        INC     HL
        LD      DE, (bh_old_bucket_head)
        LD      (HL), E                 ; +4 old_head lo
        INC     HL
        LD      (HL), D                 ; +5 old_head hi
        INC     HL
        LD      DE, (bh_count_flags_addr)
        LD      (HL), E                 ; +6 cf_ptr lo
        INC     HL
        LD      (HL), D                 ; +7 cf_ptr hi

        ; Restore LATEST to the CODE word's entry — build_header set
        ; LATEST to the new label entry, but the user expects LATEST to
        ; remain the in-progress CODE word.
        LD      HL, (asm_saved_here)
        LD      (IY+UserArea.latest), L
        LD      (IY+UserArea.latest+1), H

        ; Restore BC (TOS) and DE (IP) from return stack.
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX
        NEXT

.lbl_no_name:
        ; build_header signalled "no name" — restore real HERE and abort.
        ; The slot allocated above must be released BEFORE the abort path
        ; runs asm_unlink_labels (which would otherwise read the slot's
        ; uninitialised bucket=0 / old_head=0 fields and zero hash_table[0],
        ; corrupting whatever pre-CODE word lived in bucket 0).
        LD      HL, asm_label_count
        DEC     (HL)
        LD      HL, (asm_tmp2)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        ; Unwind RS save (symmetric with success path) — asm_cleanup
        ; will run via asm_err_noname → asm_die → ABORT.
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
; FIX ( label-tag -- )
;   Mark the label slot identified by the tag as resolved with target
;   = current HERE, then walk the fixup pool patching every queued
;   forward reference to that label.
; =====================================================================
w_FIX:
        DEFCODE "FIX", 0
w_FIX_cf:
        CALL    check_asm_mode
        ; Validate label tag in BC.
        CALL    asm_check_tagged
        CALL    asm_is_label_tag
        JP      NZ, asm_bad_operand
        LD      A, C
        AND     ASM_INDEX_MASK          ; A = slot index
        LD      HL, asm_label_count
        CP      (HL)
        JP      NC, asm_bad_operand
        ; A = slot index. Check resolved flag first.
        PUSH    AF
        CALL    asm_slot_addr           ; HL = &slot
        LD      A, (HL)                 ; resolved?
        OR      A
        JR      NZ, .fix_already
        POP     AF
        ; asm_resolve_slot may patch JR fixups (which can ABORT) and
        ; clobbers DE; spill IP to scratch.
        LD      (asm_ip_save), DE
        CALL    asm_resolve_slot
        LD      DE, (asm_ip_save)
        POP     BC                      ; pop new TOS
        NEXT
.fix_already:
        ; Already fixed — print "already fixed: NAME ?" and ABORT.
        ; HL currently points at slot+0; advance to +6 (cf_ptr).
        LD      DE, 6
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        EX      DE, HL                  ; HL = cf_ptr
        POP     AF                      ; discard saved index
        JP      asm_err_already

; =====================================================================
; JR, ( target -- )   unconditional Z80 JR
;   Operand is either a label tag (0xFFnn) or a plain 16-bit address.
;   Emits 0x18 + signed 8-bit displacement. Forward references with
;   unresolved labels emit a placeholder and queue a fixup.
; =====================================================================
w_JR_COMMA:
        DEFCODE "JR,", 0
w_JR_COMMA_cf:
        CALL    check_asm_mode
        LD      (asm_ip_save), DE
        ; Conditional-prefix detection: peek NOS for a condition tag.
        POP     HL                      ; HL = NOS
        LD      A, H
        CP      ASM_TAG_HI
        JR      NZ, .jrc_not_cond
        LD      A, L
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_COND
        JR      Z, .jrc_cond
.jrc_not_cond:
        ; Not a condition — restore NOS and emit unconditional JR.
        PUSH    HL
        LD      A, 0x18
        JR      .jrc_emit_op
.jrc_cond:
        ; cc = index from L. Only NZ/Z/NC/CS (0..3) legal for JR.
        LD      A, L
        AND     ASM_INDEX_MASK
        CP      4
        JP      NC, asm_bad_operand
        ADD     A, A
        ADD     A, A
        ADD     A, A                    ; cc << 3
        OR      0x20
.jrc_emit_op:
        CALL    asm_emit_byte
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (asm_tmp2), HL
        ; Inspect TOS — check for label tag.
        LD      A, B
        CP      ASM_TAG_HI
        JR      NZ, .jrc_literal
        CALL    asm_is_label_tag
        JR      Z, .jrc_label
.jrc_literal:
        ; Plain 16-bit address: literal-target JR.
        LD      D, B
        LD      E, C
        LD      HL, (asm_tmp2)
        CALL    asm_apply_jr_fixup_emit
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT
.jrc_label:
        ; Label tag: extract slot index via AND 0x1F.
        LD      A, C
        AND     ASM_INDEX_MASK
        LD      HL, asm_label_count
        CP      (HL)
        JP      NC, asm_bad_operand
        CALL    asm_slot_addr           ; HL = &slot
        LD      A, (HL)
        OR      A
        JR      Z, .jrc_unresolved
        INC     HL
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        LD      HL, (asm_tmp2)
        CALL    asm_apply_jr_fixup_emit
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT
.jrc_unresolved:
        XOR     A
        CALL    asm_emit_byte
        LD      A, C
        AND     ASM_INDEX_MASK          ; A = label slot index
        LD      C, ASM_FIXUP_KIND_JR
        LD      HL, (asm_tmp2)
        CALL    asm_add_fixup
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT

; -----------------------------------------------
; asm_apply_jr_fixup_emit — Emit a resolved JR displacement byte directly
;   (no patch — write at HERE). Entry: HL = HERE (patch addr), DE = target.
;   Computes signed disp, range-checks, then asm_emit_byte's it.
; -----------------------------------------------
asm_apply_jr_fixup_emit:
        CALL    asm_jr_disp             ; A = disp, HL = patch addr (== HERE)
        JP      asm_emit_byte           ; emit at HERE, advance HERE

; =====================================================================
; JP, ( target -- )         and    CALL, ( target -- )
;   Each accepts an optional condition tag in NOS:
;     [..., cc-tag, target] →  conditional form (cc encoded in opcode)
;     [..., target]         →  unconditional form (peeks NOS, doesn't pop)
;   Target is either a literal address or a label tag (0xFFnn).
;   Forward references with unresolved labels emit 0x00 0x00 placeholders
;   and queue an absolute (DW-kind) fixup; FIX patches them later.
;   The two opcode words share asm_jp_call_word; w_JP_COMMA_cf passes
;   A=0xC3, w_CALL_COMMA_cf passes A=0xCD.
; =====================================================================
w_JP_COMMA:
        DEFCODE "JP,", 0
w_JP_COMMA_cf:
        ; Check for JP (IX) / JP (IY) — bare indirect tags
        LD      A, B
        CP      ASM_TAG_HI
        JR      NZ, .jp_normal
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_INDIRECT
        JR      NZ, .jp_normal
        LD      A, C
        AND     ASM_INDEX_MASK
        CP      ASM_IND_IX
        JR      Z, .jp_iixiy
        CP      ASM_IND_IY
        JR      Z, .jp_iixiy
.jp_normal:
        LD      A, 0xC3
        JP      asm_jp_call_word
.jp_iixiy:
        ; JP (IX) / JP (IY) = DD/FD E9
        LD      (asm_tmp), A            ; save tag index across check
        CALL    check_asm_mode
        LD      A, (asm_tmp)
        CALL    asm_emit_ixiy_prefix    ; emit DD/FD
        LD      A, 0xE9
        CALL    asm_emit_byte
        POP     BC
        NEXT

w_CALL_COMMA:
        DEFCODE "CALL,", 0
w_CALL_COMMA_cf:
        LD      A, 0xCD
        JP      asm_jp_call_word

; -----------------------------------------------
; asm_jp_call_word — Shared body for JP, and CALL,.
;   Entry: A = unconditional opcode byte (0xC3 = JP, 0xCD = CALL).
;   Uses asm_tmp for the unconditional opcode and asm_tmp2 for the
;   saved target/patch-addr. asm_emit_byte / asm_slot_addr / asm_add_fixup
;   all preserve DE; we still spill IP defensively per the Story 4.2
;   retrospective lesson on JR,/FIX/DW,.
; -----------------------------------------------
asm_jp_call_word:
        LD      (asm_jp_op), A          ; save unconditional opcode
        CALL    check_asm_mode
        LD      (asm_ip_save), DE
        ; Save target operand (BC) — could be label tag or literal.
        LD      H, B
        LD      L, C
        LD      (asm_tmp2), HL
        POP     BC
        ; Check if NOS (now BC) is a condition tag.
        LD      A, B
        CP      ASM_TAG_HI
        JR      NZ, .jpc_uncond
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_COND
        JR      Z, .jpc_cond
.jpc_uncond:
        LD      A, (asm_jp_op)
        CALL    asm_emit_byte
        JR      .jpc_emit_target
.jpc_cond:
        LD      A, (asm_jp_op)
        CP      0xC3
        JR      Z, .jpc_cond_jp
        LD      A, 0xC4                 ; CALL cond base
        JR      .jpc_have_base
.jpc_cond_jp:
        LD      A, 0xC2                 ; JP cond base
.jpc_have_base:
        LD      H, A                    ; H = cond base
        LD      A, C
        AND     ASM_INDEX_MASK          ; cc = index 0..7
        RLCA
        RLCA
        RLCA                            ; A = cc << 3
        OR      H
        CALL    asm_emit_byte
        POP     BC                      ; consume the cell below cond tag
.jpc_emit_target:
        LD      HL, (asm_tmp2)
        ; Check if target is a label tag.
        LD      A, H
        CP      ASM_TAG_HI
        JR      NZ, .jpc_literal
        LD      A, L
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_LABEL
        JR      Z, .jpc_label
.jpc_literal:
        ; Literal target — emit lo then hi.
        LD      A, L
        CALL    asm_emit_byte
        LD      HL, (asm_tmp2)
        LD      A, H
        CALL    asm_emit_byte
        JR      .jpc_done
.jpc_label:
        LD      A, L
        AND     ASM_INDEX_MASK          ; A = slot idx
        LD      HL, asm_label_count
        CP      (HL)
        JP      NC, asm_bad_operand
        PUSH    AF
        CALL    asm_slot_addr           ; HL = &slot
        LD      A, (HL)
        OR      A
        JR      Z, .jpc_unres
        INC     HL
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        POP     AF
        LD      A, E
        CALL    asm_emit_byte
        LD      A, D
        CALL    asm_emit_byte
        JR      .jpc_done
.jpc_unres:
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (asm_tmp2), HL
        XOR     A
        CALL    asm_emit_byte
        XOR     A
        CALL    asm_emit_byte
        POP     AF                      ; A = slot idx
        LD      C, ASM_FIXUP_KIND_DW
        LD      HL, (asm_tmp2)
        CALL    asm_add_fixup
.jpc_done:
        LD      DE, (asm_ip_save)
        NEXT

; =====================================================================
; RET, ( -- )    and    cond RET, ( cond -- )
;   Peeks TOS — if it is a condition tag, pops it and emits RET cc
;   (0xC0 | (cc<<3)); otherwise emits unconditional RET (0xC9) and
;   leaves TOS untouched. RET, is the only opcode word in the assembler
;   that may peek-and-consume — by design, so the unconditional form
;   takes zero operands.
; =====================================================================
w_RET_COMMA:
        DEFCODE "RET,", 0
w_RET_COMMA_cf:
        CALL    check_asm_mode
        ; Depth guard — BC is phantom when stack is empty.
        LD      HL, (sp_base)
        OR      A
        SBC     HL, SP
        LD      A, H
        OR      A
        JR      NZ, .retc_bc_ok
        LD      A, L
        CP      2
        JR      C, .retc_uncond
.retc_bc_ok:
        LD      A, B
        CP      ASM_TAG_HI
        JR      NZ, .retc_uncond
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_COND
        JR      Z, .retc_cond
.retc_uncond:
        LD      A, 0xC9
        CALL    asm_emit_byte
        NEXT
.retc_cond:
        LD      A, C
        AND     ASM_INDEX_MASK          ; cc = 0..7
        RLCA
        RLCA
        RLCA
        OR      0xC0
        CALL    asm_emit_byte
        POP     BC
        NEXT

; =====================================================================
; DB, ( value -- )    emit one byte (low byte of value)
; =====================================================================
w_DB_COMMA:
        DEFCODE "DB,", 0
w_DB_COMMA_cf:
        CALL    check_asm_mode
        ; Reject any tagged operand — DB, expects a raw integer.
        LD      A, B
        CP      ASM_TAG_HI
        JP      Z, asm_bad_operand
        LD      A, C
        CALL    asm_emit_byte
        POP     BC
        NEXT

; =====================================================================
; DW, ( value-or-label-tag -- )    emit 16-bit cell little-endian
;   Plain integer: emit low then high.
;   Label tag (high byte = 0xFF):
;     resolved   -> emit slot's target address little-endian
;     unresolved -> emit two 0x00 placeholders + queue DW-absolute fixup
; =====================================================================
w_DW_COMMA:
        DEFCODE "DW,", 0
w_DW_COMMA_cf:
        CALL    check_asm_mode
        ; Check for label tag (class=LABEL).
        LD      A, B
        CP      ASM_TAG_HI
        JR      NZ, .dwc_plain
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_LABEL
        JR      Z, .dwc_label
.dwc_plain:
        ; Plain int: emit low then high.
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT
.dwc_label:
        LD      (asm_ip_save), DE
        LD      A, C
        AND     ASM_INDEX_MASK          ; A = slot idx
        LD      HL, asm_label_count
        CP      (HL)
        JP      NC, asm_bad_operand
        CALL    asm_slot_addr           ; HL = &slot
        LD      A, (HL)
        OR      A
        JR      Z, .dwc_unresolved
        INC     HL
        LD      A, (HL)                 ; target lo
        CALL    asm_emit_byte
        LD      A, C
        AND     ASM_INDEX_MASK          ; slot idx (re-extract)
        CALL    asm_slot_addr
        INC     HL
        INC     HL
        LD      A, (HL)
        CALL    asm_emit_byte
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT
.dwc_unresolved:
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (asm_tmp2), HL
        XOR     A
        CALL    asm_emit_byte
        XOR     A
        CALL    asm_emit_byte
        LD      A, C
        AND     ASM_INDEX_MASK          ; A = slot idx
        LD      C, ASM_FIXUP_KIND_DW
        LD      HL, (asm_tmp2)
        CALL    asm_add_fixup
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT

; =====================================================================
; DS, ( count -- )    reserve count bytes initialised to zero
;   Negative count → bad operand. count=0 is a no-op.
; =====================================================================
w_DS_COMMA:
        DEFCODE "DS,", 0
w_DS_COMMA_cf:
        CALL    check_asm_mode
        ; Reject negative (high bit of B set).
        BIT     7, B
        JP      NZ, asm_bad_operand
        ; Zero?
        LD      A, B
        OR      C
        JR      Z, .dsc_done
.dsc_loop:
        XOR     A
        CALL    asm_emit_byte
        DEC     BC
        LD      A, B
        OR      C
        JR      NZ, .dsc_loop
.dsc_done:
        POP     BC
        NEXT

; =====================================================================
; EQU ( value "<spaces>name" -- )
;   Defines NAME as a CONSTANT with the given value. Allowed only OUTSIDE
;   CODE (asm_mode == 0). Inside CODE it errors with "EQU outside CODE only ?".
; =====================================================================
w_EQU:
        DEFCODE "EQU", 0
w_EQU_cf:
        LD      A, (asm_mode)
        OR      A
        JP      NZ, asm_err_equ_in_code
        JP      w_CONSTANT_cf

; =====================================================================
; INC, / DEC, ( operand -- )
;   Accepts REG8, (HL), (IX+d), (IY+d), or REG16 (BC/DE/HL/SP/IX/IY).
; =====================================================================

; -----------------------------------------------
; asm_inc_dec_word — Shared dispatcher for INC, and DEC,.
;   Entry: asm_tmp = 8-bit base (0x04=INC, 0x05=DEC)
;                    16-bit base bits differ: INC=0x03, DEC=0x0B
;   Actually we parameterise with two bytes:
;     asm_tmp   = 8-bit base (0x04 for INC, 0x05 for DEC)
;     asm_tmp+1 = 16-bit base (0x03 for INC, 0x0B for DEC)
; -----------------------------------------------
asm_inc_dec_word:
        CALL    check_asm_mode
        CALL    asm_check_tagged
        ; Dispatch on class
        CALL    asm_get_class
        JR      Z, .idc_reg8            ; class=REG8 (0x00)
        CP      ASM_CLASS_REG16
        JR      Z, .idc_reg16
        CP      ASM_CLASS_INDIRECT
        JR      Z, .idc_indirect
        JP      asm_bad_operand

.idc_reg8:
        ; INC r = 0x04|(r<<3), DEC r = 0x05|(r<<3)
        CALL    asm_get_index
        CP      6
        JP      Z, asm_bad_operand      ; r=6 is (HL) in old encoding
        CP      8
        JP      NC, asm_bad_operand
        RLCA
        RLCA
        RLCA                            ; A = r<<3
        LD      HL, asm_tmp
        OR      (HL)                    ; A = base8 | (r<<3)
        CALL    asm_emit_byte
        POP     BC
        NEXT

.idc_reg16:
        CALL    asm_get_index
        CP      ASM_IX_INDEX
        JR      Z, .idc_ixiy16
        CP      ASM_IY_INDEX
        JR      Z, .idc_ixiy16
        CP      3
        JP      Z, asm_bad_operand      ; AF — no INC/DEC AF
        CP      5
        JP      NC, asm_bad_operand     ; AFP (7) or unknown
        ; Map: 0=BC(rr0), 1=DE(rr1), 2=HL(rr2), 4=SP(rr3)
        CP      4
        JR      NZ, .idc_r16_emit
        LD      A, 3                    ; SP: tag index 4 → rr 3
.idc_r16_emit:
        RLCA
        RLCA
        RLCA
        RLCA                            ; A = rr<<4
        LD      HL, asm_tmp+1
        OR      (HL)                    ; A = base16 | (rr<<4)
        CALL    asm_emit_byte
        POP     BC
        NEXT

.idc_ixiy16:
        ; INC/DEC IX/IY = DD/FD 23/2B
        ; A = ASM_IX_INDEX or ASM_IY_INDEX from dispatch
        ; DD prefix: INC IX = DD 23, DEC IX = DD 2B
        ; base16=0x03(INC) → HL opcode = 0x03|(2<<4) = 0x23
        ; base16=0x0B(DEC) → HL opcode = 0x0B|(2<<4) = 0x2B
        CALL    asm_emit_ixiy_prefix    ; emit DD/FD
        LD      A, (asm_tmp+1)
        OR      0x20                    ; rr=2 (HL) << 4
        CALL    asm_emit_byte
        POP     BC
        NEXT

.idc_indirect:
        CALL    asm_get_index
        OR      A
        JR      Z, .idc_ihl             ; index 0 = (HL)
        CP      ASM_IND_IXD
        JR      Z, .idc_ixiyd
        CP      ASM_IND_IYD
        JR      Z, .idc_ixiyd
        JP      asm_bad_operand

.idc_ihl:
        ; INC (HL) = 0x34, DEC (HL) = 0x35  → base8 | (6<<3)
        LD      A, (asm_tmp)
        OR      0x30                    ; 6<<3 = 0x30
        CALL    asm_emit_byte
        POP     BC
        NEXT

.idc_ixiyd:
        ; INC/DEC (IX+d)/(IY+d) = DD/FD opcode disp
        ; A = ASM_IND_IXD or ASM_IND_IYD from dispatch
        CALL    asm_emit_ixiy_prefix    ; emit DD/FD
        LD      A, (asm_tmp)
        OR      0x30                    ; opcode for (HL) = base|(6<<3)
        CALL    asm_emit_byte
        CALL    asm_pop_indexed_disp    ; A = displacement, BC = new TOS
        CALL    asm_emit_byte
        NEXT

w_INC_COMMA:
        DEFCODE "INC,", 0
w_INC_COMMA_cf:
        LD      A, 0x04
        LD      (asm_tmp), A
        LD      A, 0x03
        LD      (asm_tmp+1), A
        JP      asm_inc_dec_word

w_DEC_COMMA:
        DEFCODE "DEC,", 0
w_DEC_COMMA_cf:
        LD      A, 0x05
        LD      (asm_tmp), A
        LD      A, 0x0B
        LD      (asm_tmp+1), A
        JP      asm_inc_dec_word

; =====================================================================
; CB-prefix rotate/shift words (Task 3)
;   RLC, RRC, RL, RR, SLA, SRA, SRL
; =====================================================================

; -----------------------------------------------
; asm_cb_shift_word — Shared dispatcher for CB-prefix shift/rotate.
;   Entry: asm_tmp = CB sub-opcode base (0x00=RLC, 0x08=RRC, etc.)
;   Operand (TOS): REG8, (HL), (IX+d), (IY+d)
; -----------------------------------------------
asm_cb_shift_word:
        CALL    check_asm_mode
        CALL    asm_check_tagged
        CALL    asm_get_class
        JR      Z, .cbs_reg8
        CP      ASM_CLASS_INDIRECT
        JR      Z, .cbs_indirect
        JP      asm_bad_operand

.cbs_reg8:
        CALL    asm_get_index
        CP      8
        JP      NC, asm_bad_operand
        CP      6
        JP      Z, asm_bad_operand      ; r=6 is (HL), use indirect form
        LD      (asm_tmp+1), A          ; save r-field
        LD      A, 0xCB
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        LD      HL, asm_tmp+1
        OR      (HL)                    ; base | r
        CALL    asm_emit_byte
        POP     BC
        NEXT

.cbs_indirect:
        CALL    asm_get_index
        OR      A
        JR      Z, .cbs_ihl
        CP      ASM_IND_IXD
        JR      Z, .cbs_ixiyd
        CP      ASM_IND_IYD
        JR      Z, .cbs_ixiyd
        JP      asm_bad_operand

.cbs_ihl:
        LD      A, 0xCB
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        OR      0x06                    ; (HL) r-field = 6
        CALL    asm_emit_byte
        POP     BC
        NEXT

.cbs_ixiyd:
        ; DDCB/FDCB: prefix, CB, displacement, opcode
        ; A = ASM_IND_IXD or ASM_IND_IYD from dispatch
        CALL    asm_emit_ixiy_prefix    ; emit DD/FD
        LD      A, 0xCB
        CALL    asm_emit_byte
        CALL    asm_pop_indexed_disp    ; A = disp, BC = new TOS
        CALL    asm_emit_byte           ; emit displacement
        LD      A, (asm_tmp)
        OR      0x06
        CALL    asm_emit_byte           ; emit opcode
        NEXT

w_RLC_COMMA:
        DEFCODE "RLC,", 0
w_RLC_COMMA_cf:
        LD      A, 0x00
        LD      (asm_tmp), A
        JP      asm_cb_shift_word

w_RRC_COMMA:
        DEFCODE "RRC,", 0
w_RRC_COMMA_cf:
        LD      A, 0x08
        LD      (asm_tmp), A
        JP      asm_cb_shift_word

w_RL_COMMA:
        DEFCODE "RL,", 0
w_RL_COMMA_cf:
        LD      A, 0x10
        LD      (asm_tmp), A
        JP      asm_cb_shift_word

w_RR_COMMA:
        DEFCODE "RR,", 0
w_RR_COMMA_cf:
        LD      A, 0x18
        LD      (asm_tmp), A
        JP      asm_cb_shift_word

w_SLA_COMMA:
        DEFCODE "SLA,", 0
w_SLA_COMMA_cf:
        LD      A, 0x20
        LD      (asm_tmp), A
        JP      asm_cb_shift_word

w_SRA_COMMA:
        DEFCODE "SRA,", 0
w_SRA_COMMA_cf:
        LD      A, 0x28
        LD      (asm_tmp), A
        JP      asm_cb_shift_word

w_SRL_COMMA:
        DEFCODE "SRL,", 0
w_SRL_COMMA_cf:
        LD      A, 0x38
        LD      (asm_tmp), A
        JP      asm_cb_shift_word

; =====================================================================
; CB-prefix bit operation words (Task 4)
;   BIT, SET, RES — bit number from immediate, operand from register/(HL)/indexed
; =====================================================================

; -----------------------------------------------
; asm_bit_op_word — Shared dispatcher for BIT,/SET,/RES,.
;   Entry: asm_tmp = CB sub-opcode base (0x40=BIT, 0x80=RES, 0xC0=SET)
;   Stack: ( bit# # operand -- )
;     TOS = operand tag (reg8, (HL), indexed)
;     Under that: immediate marker (#), then bit value
; -----------------------------------------------
asm_bit_op_word:
        CALL    check_asm_mode
        CALL    asm_check_tagged
        ; Save operand tag class+index
        CALL    asm_get_class
        JR      Z, .bop_reg8
        CP      ASM_CLASS_INDIRECT
        JR      Z, .bop_indirect
        JP      asm_bad_operand

.bop_reg8:
        CALL    asm_get_index
        CP      8
        JP      NC, asm_bad_operand
        CP      6
        JP      Z, asm_bad_operand
        LD      (asm_tmp+1), A          ; save r-field
        ; Pop and verify immediate marker
        POP     BC
        CALL    asm_check_tagged
        CALL    asm_is_imm_tag
        JP      NZ, asm_bad_operand
        POP     BC                      ; BC = bit number
        LD      A, C
        CP      8
        JP      NC, asm_range_err
        ; Emit CB, then base | (bit<<3) | r
        PUSH    BC
        LD      A, 0xCB
        CALL    asm_emit_byte
        POP     BC
        LD      A, C                    ; A = bit number
        RLCA
        RLCA
        RLCA                            ; A = bit<<3
        LD      HL, asm_tmp
        OR      (HL)                    ; A = base | (bit<<3)
        LD      HL, asm_tmp+1
        OR      (HL)                    ; A = base | (bit<<3) | r
        CALL    asm_emit_byte
        POP     BC
        NEXT

.bop_indirect:
        CALL    asm_get_index
        OR      A
        JR      Z, .bop_ihl
        CP      ASM_IND_IXD
        JR      Z, .bop_ixiyd
        CP      ASM_IND_IYD
        JR      Z, .bop_ixiyd
        JP      asm_bad_operand

.bop_ihl:
        ; Pop imm marker + bit value
        POP     BC
        CALL    asm_check_tagged
        CALL    asm_is_imm_tag
        JP      NZ, asm_bad_operand
        POP     BC                      ; BC = bit number
        LD      A, C
        CP      8
        JP      NC, asm_range_err
        PUSH    BC
        LD      A, 0xCB
        CALL    asm_emit_byte
        POP     BC
        LD      A, C
        RLCA
        RLCA
        RLCA
        LD      HL, asm_tmp
        OR      (HL)
        OR      0x06                    ; (HL) r-field
        CALL    asm_emit_byte
        POP     BC
        NEXT

.bop_ixiyd:
        ; BIT/SET/RES (IX+d)/(IY+d) = DD/FD CB disp opcode
        ; Stack: ... | bit_val | imm_marker | disp | tag(consumed)
        ; A = ASM_IND_IXD or ASM_IND_IYD from dispatch
        LD      (asm_ip_save), A        ; save tag index for prefix emit
        ; Validate operands before emitting any bytes
        POP     HL                      ; HL = displacement cell
        LD      A, L
        LD      (asm_tmp+1), A          ; save displacement
        POP     BC
        CALL    asm_check_tagged
        CALL    asm_is_imm_tag
        JP      NZ, asm_bad_operand
        POP     BC
        LD      A, C
        CP      8
        JP      NC, asm_range_err
        LD      (asm_tmp+2), A          ; save bit number
        ; All operands validated — emit: DD/FD CB disp opcode
        LD      A, (asm_ip_save)
        CALL    asm_emit_ixiy_prefix    ; emit DD/FD prefix
        LD      A, 0xCB
        CALL    asm_emit_byte
        LD      A, (asm_tmp+1)          ; displacement
        CALL    asm_emit_byte
        LD      A, (asm_tmp+2)          ; bit number
        RLCA
        RLCA
        RLCA
        LD      HL, asm_tmp
        OR      (HL)                    ; base | (bit<<3)
        OR      0x06                    ; (HL) r-field
        CALL    asm_emit_byte
        POP     BC
        NEXT

w_BIT_COMMA:
        DEFCODE "BIT,", 0
w_BIT_COMMA_cf:
        LD      A, 0x40
        LD      (asm_tmp), A
        JP      asm_bit_op_word

w_RES_COMMA:
        DEFCODE "RES,", 0
w_RES_COMMA_cf:
        LD      A, 0x80
        LD      (asm_tmp), A
        JP      asm_bit_op_word

w_SET_COMMA:
        DEFCODE "SET,", 0
w_SET_COMMA_cf:
        LD      A, 0xC0
        LD      (asm_tmp), A
        JP      asm_bit_op_word

; =====================================================================
; I/O instructions (Task 5)
; =====================================================================

w_IN_COMMA:
        DEFCODE "IN,", 0
w_IN_COMMA_cf:
        CALL    check_asm_mode
        CALL    asm_check_tagged
        ; TOS = register tag (destination)
        CALL    asm_get_class
        JP      NZ, asm_bad_operand     ; must be REG8
        CALL    asm_get_index
        CP      8
        JP      NC, asm_bad_operand
        LD      (asm_tmp), A            ; save r-field
        ; Pop NOS = port specifier
        POP     BC
        CALL    asm_check_tagged
        CALL    asm_is_indirect_tag
        JR      Z, .in_indirect
        CALL    asm_is_imm_tag
        JR      Z, .in_imm
        JP      asm_bad_operand

.in_indirect:
        ; Must be (C) tag
        CALL    asm_get_index
        CP      ASM_IND_C
        JP      NZ, asm_bad_operand
        ; IN r,(C) = ED 40|(r<<3)
        LD      A, 0xED
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        RLCA
        RLCA
        RLCA
        OR      0x40
        CALL    asm_emit_byte
        POP     BC
        NEXT

.in_imm:
        ; Immediate port — only valid for A (r=7)
        LD      A, (asm_tmp)
        CP      7
        JP      NZ, asm_bad_operand
        POP     BC                      ; BC = port number
        ; IN A,(n) = DB nn
        LD      A, 0xDB
        CALL    asm_emit_byte
        LD      A, C
        CALL    asm_emit_byte
        POP     BC
        NEXT

w_OUT_COMMA:
        DEFCODE "OUT,", 0
w_OUT_COMMA_cf:
        CALL    check_asm_mode
        CALL    asm_check_tagged
        ; TOS = port specifier ((C) or imm marker)
        CALL    asm_is_indirect_tag
        JR      Z, .out_indirect
        CALL    asm_is_imm_tag
        JR      Z, .out_imm
        JP      asm_bad_operand

.out_indirect:
        ; Must be (C) tag
        CALL    asm_get_index
        CP      ASM_IND_C
        JP      NZ, asm_bad_operand
        ; Pop NOS = register tag
        POP     BC
        CALL    asm_check_tagged
        CALL    asm_get_class
        JP      NZ, asm_bad_operand     ; must be REG8
        CALL    asm_get_index
        CP      8
        JP      NC, asm_bad_operand
        ; OUT (C),r = ED 41|(r<<3)
        LD      (asm_tmp), A            ; save r-field
        LD      A, 0xED
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        RLCA
        RLCA
        RLCA
        OR      0x41
        CALL    asm_emit_byte
        POP     BC
        NEXT

.out_imm:
        ; Immediate port: TOS was imm marker, pop port value, pop register
        POP     BC                      ; BC = port number
        LD      A, C
        LD      (asm_tmp), A            ; save port
        POP     BC                      ; BC = register tag
        CALL    asm_check_tagged
        CALL    asm_get_class
        JP      NZ, asm_bad_operand
        CALL    asm_get_index
        CP      7
        JP      NZ, asm_bad_operand     ; only A
        ; OUT (n),A = D3 nn
        LD      A, 0xD3
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        CALL    asm_emit_byte
        POP     BC
        NEXT

; =====================================================================
; ED-prefix zero-operand words (Task 6)
;   Shared emitter: emit 0xED then second byte.
; =====================================================================

; -----------------------------------------------
; asm_emit_ed_op — Emit ED nn zero-operand instruction.
;   Entry: A = second byte
; -----------------------------------------------
asm_emit_ed_op:
        LD      (asm_tmp), A
        CALL    check_asm_mode
        LD      A, 0xED
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        CALL    asm_emit_byte
        NEXT

; Block transfer/search (repeat)
w_LDIR_COMMA:
        DEFCODE "LDIR,", 0
w_LDIR_COMMA_cf:
        LD      A, 0xB0
        JP      asm_emit_ed_op

w_LDDR_COMMA:
        DEFCODE "LDDR,", 0
w_LDDR_COMMA_cf:
        LD      A, 0xB8
        JP      asm_emit_ed_op

w_CPIR_COMMA:
        DEFCODE "CPIR,", 0
w_CPIR_COMMA_cf:
        LD      A, 0xB1
        JP      asm_emit_ed_op

w_CPDR_COMMA:
        DEFCODE "CPDR,", 0
w_CPDR_COMMA_cf:
        LD      A, 0xB9
        JP      asm_emit_ed_op

; Block transfer/search (single)
w_LDI_COMMA:
        DEFCODE "LDI,", 0
w_LDI_COMMA_cf:
        LD      A, 0xA0
        JP      asm_emit_ed_op

w_LDD_COMMA:
        DEFCODE "LDD,", 0
w_LDD_COMMA_cf:
        LD      A, 0xA8
        JP      asm_emit_ed_op

w_CPI_COMMA:
        DEFCODE "CPI,", 0
w_CPI_COMMA_cf:
        LD      A, 0xA1
        JP      asm_emit_ed_op

w_CPD_COMMA:
        DEFCODE "CPD,", 0
w_CPD_COMMA_cf:
        LD      A, 0xA9
        JP      asm_emit_ed_op

; Block I/O (single and repeat)
w_INI_COMMA:
        DEFCODE "INI,", 0
w_INI_COMMA_cf:
        LD      A, 0xA2
        JP      asm_emit_ed_op

w_INIR_COMMA:
        DEFCODE "INIR,", 0
w_INIR_COMMA_cf:
        LD      A, 0xB2
        JP      asm_emit_ed_op

w_IND_COMMA:
        DEFCODE "IND,", 0
w_IND_COMMA_cf:
        LD      A, 0xAA
        JP      asm_emit_ed_op

w_INDR_COMMA:
        DEFCODE "INDR,", 0
w_INDR_COMMA_cf:
        LD      A, 0xBA
        JP      asm_emit_ed_op

w_OUTI_COMMA:
        DEFCODE "OUTI,", 0
w_OUTI_COMMA_cf:
        LD      A, 0xA3
        JP      asm_emit_ed_op

w_OTIR_COMMA:
        DEFCODE "OTIR,", 0
w_OTIR_COMMA_cf:
        LD      A, 0xB3
        JP      asm_emit_ed_op

w_OUTD_COMMA:
        DEFCODE "OUTD,", 0
w_OUTD_COMMA_cf:
        LD      A, 0xAB
        JP      asm_emit_ed_op

w_OTDR_COMMA:
        DEFCODE "OTDR,", 0
w_OTDR_COMMA_cf:
        LD      A, 0xBB
        JP      asm_emit_ed_op

; Miscellaneous ED-prefix
w_NEG_COMMA:
        DEFCODE "NEG,", 0
w_NEG_COMMA_cf:
        LD      A, 0x44
        JP      asm_emit_ed_op

w_RETN_COMMA:
        DEFCODE "RETN,", 0
w_RETN_COMMA_cf:
        LD      A, 0x45
        JP      asm_emit_ed_op

w_RETI_COMMA:
        DEFCODE "RETI,", 0
w_RETI_COMMA_cf:
        LD      A, 0x4D
        JP      asm_emit_ed_op

w_IM0_COMMA:
        DEFCODE "IM0,", 0
w_IM0_COMMA_cf:
        LD      A, 0x46
        JP      asm_emit_ed_op

w_IM1_COMMA:
        DEFCODE "IM1,", 0
w_IM1_COMMA_cf:
        LD      A, 0x56
        JP      asm_emit_ed_op

w_IM2_COMMA:
        DEFCODE "IM2,", 0
w_IM2_COMMA_cf:
        LD      A, 0x5E
        JP      asm_emit_ed_op

; =====================================================================
; EX, / EXX, (Task 7)
; =====================================================================

w_EX_COMMA:
        DEFCODE "EX,", 0
w_EX_COMMA_cf:
        CALL    check_asm_mode
        ; TOS = second operand, NOS = first operand
        CALL    asm_check_tagged
        LD      H, B
        LD      L, C                    ; HL = TOS tag
        POP     BC                      ; BC = NOS tag
        CALL    asm_check_tagged
        ; Now: BC = NOS (first), HL = TOS (second)
        ; Check for DE,HL exchange
        LD      A, C
        CP      ASM_CLASS_REG16 | 1     ; DE = 0x61
        JR      NZ, .ex_not_dehl
        LD      A, L
        CP      ASM_CLASS_REG16 | 2     ; HL = 0x62
        JR      NZ, .ex_not_dehl
        LD      A, 0xEB                 ; EX DE,HL
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ex_not_dehl:
        ; Check for AF,AF' exchange
        LD      A, C
        CP      ASM_CLASS_REG16 | 3     ; AF = 0x63
        JR      NZ, .ex_not_afp
        LD      A, L
        CP      ASM_CLASS_REG16 | ASM_AFP_INDEX ; AF' = 0x67
        JR      NZ, .ex_not_afp
        LD      A, 0x08                 ; EX AF,AF'
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ex_not_afp:
        ; Check for (SP),r exchange — NOS must be (SP)
        LD      A, C
        CP      ASM_CLASS_INDIRECT | ASM_IND_SP ; (SP) = 0x85
        JP      NZ, asm_bad_operand
        ; TOS must be HL, IX, or IY
        LD      A, L
        CP      ASM_CLASS_REG16 | 2     ; HL
        JR      Z, .ex_sp_hl
        CP      ASM_CLASS_REG16 | ASM_IX_INDEX ; IX
        JR      Z, .ex_sp_ixiy
        CP      ASM_CLASS_REG16 | ASM_IY_INDEX ; IY
        JR      Z, .ex_sp_ixiy
        JP      asm_bad_operand

.ex_sp_hl:
        LD      A, 0xE3                 ; EX (SP),HL
        CALL    asm_emit_byte
        POP     BC
        NEXT

.ex_sp_ixiy:
        ; EX (SP),IX/IY = DD/FD E3
        AND     ASM_INDEX_MASK          ; extract index (5=IX, 6=IY)
        CALL    asm_emit_ixiy_prefix    ; emit DD/FD
        LD      A, 0xE3
        CALL    asm_emit_byte
        POP     BC
        NEXT

w_EXX_COMMA:
        DEFCODE "EXX,", 0
w_EXX_COMMA_cf:
        CALL    check_asm_mode
        LD      A, 0xD9
        CALL    asm_emit_byte
        NEXT

; =====================================================================
; Single-byte zero-operand words (Story 5.0.5, Task 1)
;   Shared emitter: check asm_mode, emit one byte, NEXT.
; =====================================================================

; -----------------------------------------------
; asm_emit_single — Emit single-byte zero-operand instruction.
;   Entry: A = opcode byte
; -----------------------------------------------
asm_emit_single:
        LD      (asm_tmp), A
        CALL    check_asm_mode
        LD      A, (asm_tmp)
        CALL    asm_emit_byte
        NEXT

w_NOP_COMMA:
        DEFCODE "NOP,", 0
w_NOP_COMMA_cf:
        LD      A, 0x00
        JP      asm_emit_single

w_HALT_COMMA:
        DEFCODE "HALT,", 0
w_HALT_COMMA_cf:
        LD      A, 0x76
        JP      asm_emit_single

w_DI_COMMA:
        DEFCODE "DI,", 0
w_DI_COMMA_cf:
        LD      A, 0xF3
        JP      asm_emit_single

w_EI_COMMA:
        DEFCODE "EI,", 0
w_EI_COMMA_cf:
        LD      A, 0xFB
        JP      asm_emit_single

w_DAA_COMMA:
        DEFCODE "DAA,", 0
w_DAA_COMMA_cf:
        LD      A, 0x27
        JP      asm_emit_single

w_CPL_COMMA:
        DEFCODE "CPL,", 0
w_CPL_COMMA_cf:
        LD      A, 0x2F
        JP      asm_emit_single

w_SCF_COMMA:
        DEFCODE "SCF,", 0
w_SCF_COMMA_cf:
        LD      A, 0x37
        JP      asm_emit_single

w_CCF_COMMA:
        DEFCODE "CCF,", 0
w_CCF_COMMA_cf:
        LD      A, 0x3F
        JP      asm_emit_single

w_RLCA_COMMA:
        DEFCODE "RLCA,", 0
w_RLCA_COMMA_cf:
        LD      A, 0x07
        JP      asm_emit_single

w_RRCA_COMMA:
        DEFCODE "RRCA,", 0
w_RRCA_COMMA_cf:
        LD      A, 0x0F
        JP      asm_emit_single

w_RLA_COMMA:
        DEFCODE "RLA,", 0
w_RLA_COMMA_cf:
        LD      A, 0x17
        JP      asm_emit_single

w_RRA_COMMA:
        DEFCODE "RRA,", 0
w_RRA_COMMA_cf:
        LD      A, 0x1F
        JP      asm_emit_single

; =====================================================================
; ADC, and SBC, (8-bit) — Story 5.0.5, Task 2
;   Reuse asm_arith_word with appropriate base opcodes.
;   16-bit forms (ADC HL,rr / SBC HL,rr) handled by prologue check.
; =====================================================================

w_ADC_COMMA:
        DEFCODE "ADC,", 0
w_ADC_COMMA_cf:
        ; Check if TOS is REG16 → 16-bit ADC HL,rr
        LD      A, B
        CP      ASM_TAG_HI
        JR      NZ, .adc_8bit
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_REG16
        JR      Z, .adc_16bit
.adc_8bit:
        LD      A, 0x88
        JP      asm_arith_word
.adc_16bit:
        CALL    check_asm_mode
        ; TOS (BC) = source reg16, extract rp
        CALL    asm_get_index           ; A = source index
        ; Validate: BC(0), DE(1), HL(2), SP(4). Reject AF(3), IX(5)+.
        CP      ASM_IX_INDEX
        JP      NC, asm_bad_operand
        CP      3
        JP      Z, asm_bad_operand
        ; Map index to rp: 0→0, 1→1, 2→2, 4→3
        CP      4
        JR      NZ, .adc16_rp_ok
        LD      A, 3
.adc16_rp_ok:
        LD      (asm_tmp), A            ; save source rp
        ; Pop NOS = destination, must be HL only
        POP     BC
        CALL    asm_check_tagged
        CALL    asm_is_reg16_tag
        JP      NZ, asm_bad_operand
        CALL    asm_get_index
        CP      2                       ; must be HL
        JP      NZ, asm_bad_operand
        ; ADC HL,rr = ED 4A|(rp<<4)
        LD      A, 0xED
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        RLCA
        RLCA
        RLCA
        RLCA
        OR      0x4A
        CALL    asm_emit_byte
        POP     BC
        NEXT

w_SBC_COMMA:
        DEFCODE "SBC,", 0
w_SBC_COMMA_cf:
        ; Check if TOS is REG16 → 16-bit SBC HL,rr
        LD      A, B
        CP      ASM_TAG_HI
        JR      NZ, .sbc_8bit
        LD      A, C
        AND     ASM_CLASS_MASK
        CP      ASM_CLASS_REG16
        JR      Z, .sbc_16bit
.sbc_8bit:
        LD      A, 0x98
        JP      asm_arith_word
.sbc_16bit:
        CALL    check_asm_mode
        ; TOS (BC) = source reg16, extract rp
        CALL    asm_get_index           ; A = source index
        ; Validate: BC(0), DE(1), HL(2), SP(4). Reject AF(3), IX(5)+.
        CP      ASM_IX_INDEX
        JP      NC, asm_bad_operand
        CP      3
        JP      Z, asm_bad_operand
        ; Map index to rp: 0→0, 1→1, 2→2, 4→3
        CP      4
        JR      NZ, .sbc16_rp_ok
        LD      A, 3
.sbc16_rp_ok:
        LD      (asm_tmp), A            ; save source rp
        ; Pop NOS = destination, must be HL only
        POP     BC
        CALL    asm_check_tagged
        CALL    asm_is_reg16_tag
        JP      NZ, asm_bad_operand
        CALL    asm_get_index
        CP      2                       ; must be HL
        JP      NZ, asm_bad_operand
        ; SBC HL,rr = ED 42|(rp<<4)
        LD      A, 0xED
        CALL    asm_emit_byte
        LD      A, (asm_tmp)
        RLCA
        RLCA
        RLCA
        RLCA
        OR      0x42
        CALL    asm_emit_byte
        POP     BC
        NEXT

; =====================================================================
; DJNZ, ( target -- )  Story 5.0.5, Task 5
;   Follows JR, pattern but with fixed opcode 0x10, no condition operand.
; =====================================================================
w_DJNZ_COMMA:
        DEFCODE "DJNZ,", 0
w_DJNZ_COMMA_cf:
        CALL    check_asm_mode
        LD      (asm_ip_save), DE
        ; Emit opcode 0x10
        LD      A, 0x10
        CALL    asm_emit_byte
        ; Record current HERE for displacement calculation
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (asm_tmp2), HL
        ; Check TOS for label tag
        LD      A, B
        CP      ASM_TAG_HI
        JR      NZ, .djnz_literal
        CALL    asm_is_label_tag
        JR      Z, .djnz_label
.djnz_literal:
        ; Plain 16-bit address
        LD      D, B
        LD      E, C
        LD      HL, (asm_tmp2)
        CALL    asm_apply_jr_fixup_emit
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT
.djnz_label:
        ; Label tag: extract slot index
        LD      A, C
        AND     ASM_INDEX_MASK
        LD      HL, asm_label_count
        CP      (HL)
        JP      NC, asm_bad_operand
        CALL    asm_slot_addr           ; HL = &slot
        LD      A, (HL)
        OR      A
        JR      Z, .djnz_unresolved
        ; Resolved: get target address
        INC     HL
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        LD      HL, (asm_tmp2)
        CALL    asm_apply_jr_fixup_emit
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT
.djnz_unresolved:
        ; Emit placeholder, queue fixup
        XOR     A
        CALL    asm_emit_byte
        LD      A, C
        AND     ASM_INDEX_MASK          ; A = label slot index
        LD      C, ASM_FIXUP_KIND_JR
        LD      HL, (asm_tmp2)
        CALL    asm_add_fixup
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT

; =====================================================================
; RST, ( vector -- )  Story 5.0.5, Task 6
;   Takes bare integer (not tagged), validates 0/8/10/18/20/28/30/38.
; =====================================================================
w_RST_COMMA:
        DEFCODE "RST,", 0
w_RST_COMMA_cf:
        CALL    check_asm_mode
        ; TOS (BC) = vector (bare integer). B must be 0.
        LD      A, B
        OR      A
        JP      NZ, asm_bad_operand     ; high byte must be 0
        LD      A, C
        CP      0x39                    ; > 0x38?
        JP      NC, asm_bad_operand
        AND     0x07                    ; low 3 bits must be 0
        JP      NZ, asm_bad_operand
        LD      A, C
        OR      0xC7                    ; build RST opcode
        CALL    asm_emit_byte
        POP     BC
        NEXT

; =====================================================================
; RLD, and RRD, — ED-prefix zero-operand (Story 5.0.5, Task 7)
; =====================================================================
w_RLD_COMMA:
        DEFCODE "RLD,", 0
w_RLD_COMMA_cf:
        LD      A, 0x6F
        JP      asm_emit_ed_op

w_RRD_COMMA:
        DEFCODE "RRD,", 0
w_RRD_COMMA_cf:
        LD      A, 0x67
        JP      asm_emit_ed_op
