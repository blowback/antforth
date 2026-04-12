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
; to-register LD where 0x42 is interpreted as a register tag — always
; include `#` for immediate operands.
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
; Label tag encoding: TOS = 0xFFnn where nn = slot index 0..15. The high
; byte 0xFF is well above any realistic HERE on iz-cpm/MicroBeast (BDOS
; base ~0xE400) and disjoint from register tags (high byte 0). Decoder:
; `if BC.high == 0xFF then label tag, slot = BC.low`.
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
; Tag high-byte sentinels. Each is well above any plausible HERE/dict
; address on iz-cpm/MicroBeast (BDOS lives ~0xE400+) so a tag can never
; collide with a real 16-bit value the user might push. JP,/CALL, share
; ASM_FIXUP_KIND_DW because the patch operation is byte-identical.
ASM_IMM_TAG_HI       EQU 0xFD     ; immediate-marker tag pushed by `#`
ASM_COND_TAG_HI      EQU 0xFE     ; condition-code tag (low byte = cc 0..7)
ASM_LABEL_TAG_HI     EQU 0xFF

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
.pen_pfx:
        LD      E, (HL)                 ; (HL) = prefix char
        PUSH    HL
        PUSH    BC
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC
        POP     HL
        INC     HL
        DJNZ    .pen_pfx
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
.pen_name:
        LD      E, (HL)
        PUSH    HL
        PUSH    BC
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC
        POP     HL
        INC     HL
        DJNZ    .pen_name
.pen_no_name:
        ; Print " ?" CR LF
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

; --- (HL) parsing word — pushes 8-bit r-field tag 6 (memory-via-HL).
;     Distinguished from real registers only at the LD, level (the
;     arith ops still reject 6 via assert_8bit_reg). ---
w_REG_IHL:
        DEFCODE "(HL)", 0
w_REG_IHL_cf:
        LD      L, 0x06
        JP      asm_push_tag

; --- Immediate-marker word `#` — pushes ASM_IMM_TAG_HI<<8 on TOS,
;     leaving the value the user just typed in NOS. Consumed by the
;     next opcode word that supports an immediate variant. No global
;     state — the marker lives entirely on the data stack. ---
w_HASH:
        DEFCODE "#", 0
w_HASH_cf:
        CALL    check_asm_mode
        PUSH    BC                      ; old TOS becomes NOS
        LD      C, 0                    ; low byte irrelevant
        LD      B, ASM_IMM_TAG_HI       ; B = 0xFD → BC = 0xFD00
        NEXT

; --- Condition-code parsing words ---
; The carry-set condition is spelled `CS` (6502-style), not Zilog `C`,
; to avoid colliding with the existing register `C`. The carry-clear
; condition keeps its Zilog spelling `NC` — `CC` was rejected because
; CC is a valid hex literal in BASE=16. See story 4.3 Q2 / Q8.
asm_push_cond_tag:
        CALL    check_asm_mode
        PUSH    BC                      ; save old TOS
        LD      C, L                    ; C = cc (0..7)
        LD      B, ASM_COND_TAG_HI      ; B = 0xFE
        NEXT

w_COND_NZ:
        DEFCODE "NZ", 0
w_COND_NZ_cf:
        LD      L, 0
        JP      asm_push_cond_tag

w_COND_Z:
        DEFCODE "Z", 0
w_COND_Z_cf:
        LD      L, 1
        JP      asm_push_cond_tag

w_COND_NC:
        DEFCODE "NC", 0
w_COND_NC_cf:
        LD      L, 2
        JP      asm_push_cond_tag

w_COND_CS:
        DEFCODE "CS", 0
w_COND_CS_cf:
        LD      L, 3
        JP      asm_push_cond_tag

w_COND_PO:
        DEFCODE "PO", 0
w_COND_PO_cf:
        LD      L, 4
        JP      asm_push_cond_tag

w_COND_PE:
        DEFCODE "PE", 0
w_COND_PE_cf:
        LD      L, 5
        JP      asm_push_cond_tag

w_COND_P:
        DEFCODE "P", 0
w_COND_P_cf:
        LD      L, 6
        JP      asm_push_cond_tag

w_COND_M:
        DEFCODE "M", 0
w_COND_M_cf:
        LD      L, 7
        JP      asm_push_cond_tag

; --- Tag predicates (Z if matching tag) — used by LD,, arith, RET,, etc.
asm_is_imm_tag:
        LD      A, B
        CP      ASM_IMM_TAG_HI
        RET

asm_is_cond_tag:
        LD      A, B
        CP      ASM_COND_TAG_HI
        RET

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
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B

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

; Permissive variant: accepts r-field 0..7 INCLUDING 6 = (HL). Used by
; LD, where memory-via-HL is a valid operand; arith ops continue to use
; the strict assert_8bit_reg above (Story 4.4 territory for arith (HL)).
assert_8bit_reg_or_ihl:
        LD      A, H
        OR      A
        JP      NZ, asm_bad_operand
        LD      A, L
        CP      8
        JP      NC, asm_bad_operand     ; >= 8 → 16-bit tag or garbage
        RET                              ; allow 0..7 including 6 = (HL)

; -----------------------------------------------
; LD, ( dst src -- )  emits LD r, r' (0x40 | (dst<<3) | src)
;   Zilog operand order: NOS = destination, TOS = source.
; -----------------------------------------------
w_LD_COMMA:
        DEFCODE "LD,", 0
w_LD_COMMA_cf:
        CALL    check_asm_mode
        ; Immediate-form check: TOS (BC) is the 0xFD00 marker?
        ; Stack on entry for `destreg value # LD,`:
        ;   TOS = 0xFD00 marker, NOS = value, NNOS = destreg tag.
        ; Zilog dst-src order is preserved uniformly: destreg is the
        ; leftmost (deepest) operand, the value follows, and `#` tags
        ; the value as an immediate. Detecting the marker on TOS keeps
        ; that ordering identical to the register-to-register form.
        CALL    asm_is_imm_tag
        JP      Z, .ldc_imm
        ; Register-to-register path — Zilog dst-src: NOS = dst, TOS = src.
        LD      H, B
        LD      L, C
        CALL    assert_8bit_reg_or_ihl  ; A = src r-value (0..7)
        LD      (asm_tmp), A            ; spill src — shares asm_tmp with
                                        ; asm_arith_word; safe because LD,
                                        ; and arith opcode words never nest
        POP     HL                      ; HL = destination tag (NOS)
        CALL    assert_8bit_reg_or_ihl  ; A = dst r-value
        ; Reject LD (HL),(HL) — that opcode (0x76) is HALT, not LD.
        LD      H, A                    ; stash dst in H temporarily
        LD      A, (asm_tmp)            ; A = src
        CP      6
        JR      NZ, .ldc_emit
        LD      A, H                    ; A = dst
        CP      6
        JP      Z, asm_bad_operand
.ldc_emit:
        LD      A, H                    ; A = dst
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

.ldc_imm:
        ; Immediate path. TOS was the marker — discard by popping the
        ; value into BC (new TOS = value); NNOS is the destination tag.
        POP     BC                      ; BC = value (new working TOS)
        POP     HL                      ; HL = destination register tag
        LD      A, H
        OR      A
        JP      NZ, asm_bad_operand     ; high byte must be 0 for register tag
        LD      A, L
        CP      8
        JR      C, .ldc_imm8
        ; 16-bit destination — must be one of BC/DE/HL/SP (0x10..0x12, 0x14)
        SUB     0x10
        JP      C, asm_bad_operand
        CP      5
        JP      NC, asm_bad_operand     ; >= 0x15 → garbage
        CP      3
        JP      Z, asm_bad_operand      ; AF (0x13) → no LD AF, nn
        ; A is now 0..4 with 3 already excluded (0,1,2,4 → BC,DE,HL,SP).
        ; Map to qq: BC=0, DE=1, HL=2, SP=3 — that means 4 → 3.
        CP      4
        JR      NZ, .ldc_imm16_qq
        LD      A, 3
.ldc_imm16_qq:
        ; A = qq (0..3). opcode = 0x01 | (qq << 4)
        RLCA
        RLCA
        RLCA
        RLCA                            ; A = qq << 4
        OR      0x01                    ; A = 0x01 | (qq<<4)
        CALL    asm_emit_byte
        ; BC holds the 16-bit value; asm_emit_byte preserves BC so we
        ; can emit lo then hi directly without a scratch spill.
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC                      ; new TOS
        NEXT

.ldc_imm8:
        ; A = L = 0..7 (destination 8-bit reg). Reject (HL) — Z80 has
        ; LD (HL),n = 0x36 nn but it is deferred to Story 4.4 (Q3).
        CP      6
        JP      Z, asm_bad_operand
        ; opcode = 0x06 | (r << 3)
        RLCA
        RLCA
        RLCA                            ; A = r << 3
        OR      0x06
        CALL    asm_emit_byte
        ; Value is in BC (new TOS); low byte is C.
        LD      A, C
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
        ; Immediate-form check: TOS = 0xFD00 marker?
        CALL    asm_is_imm_tag
        JR      Z, .arith_imm
        ; Register form (existing path).
        CALL    asm_get_r8              ; A = r-field
        LD      HL, asm_tmp
        OR      (HL)                    ; A = base | r
        CALL    asm_emit_byte
        POP     BC                      ; new TOS
        NEXT
.arith_imm:
        ; TOS is the immediate marker; pop it (so new TOS is the value).
        POP     BC                      ; new TOS = value (n)
        ; imm_base = 0xC6 | (reg_base & 0x38)
        LD      A, (asm_tmp)
        AND     0x38                    ; isolate alu field
        OR      0xC6
        CALL    asm_emit_byte
        ; Emit n (low byte of value).
        LD      A, C
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

; =====================================================================
; Label tag push helper — Tail used by all label-word bodies.
;   The body of every LABEL-defined dict entry is exactly:
;       LD      L, slot_index           ; 2 bytes
;       JP      asm_push_label_tag      ; 3 bytes
;   asm_push_label_tag pushes BC = 0xFF00 | slot_index onto the data
;   stack and refuses to run outside CODE (defence in depth — correct
;   cleanup makes label words unreachable when not in CODE).
; =====================================================================
asm_push_label_tag:
        CALL    check_asm_mode
        PUSH    BC                      ; save old TOS
        LD      C, L                    ; C = slot index
        LD      B, ASM_LABEL_TAG_HI     ; B = 0xFF
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
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B

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
        LD      A, B
        CP      ASM_LABEL_TAG_HI
        JP      NZ, asm_bad_operand
        LD      A, C
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
        ; Spill IP — we use D/E as scratch for the target address.
        LD      (asm_ip_save), DE
        ; Conditional-prefix detection: peek NOS for a condition tag.
        ; The cond words push 0xFE00 | cc; if NOS matches, this is a
        ; conditional JR (NZ/Z/NC/CS only — PO/PE/P/M rejected).
        POP     HL                      ; HL = NOS
        LD      A, H
        CP      ASM_COND_TAG_HI
        JR      Z, .jrc_cond
        ; Not a condition — restore NOS and emit unconditional JR.
        PUSH    HL
        LD      A, 0x18
        JR      .jrc_emit_op
.jrc_cond:
        ; HL = condition tag; cc in L. Only NZ/Z/NC/CS (cc 0..3) are
        ; legal — Z80 has no JR PO/PE/P/M.
        LD      A, L
        CP      4
        JP      NC, asm_bad_operand
        ; Conditional opcode = 0x20 | (cc << 3).
        ADD     A, A
        ADD     A, A
        ADD     A, A                    ; cc << 3
        OR      0x20
.jrc_emit_op:
        CALL    asm_emit_byte
        ; HERE now points at the displacement byte slot. patch_addr =
        ; HERE (the next byte we will emit).
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (asm_tmp2), HL          ; save patch addr
        ; Inspect TOS.
        LD      A, B
        CP      ASM_LABEL_TAG_HI
        JR      Z, .jrc_label
        ; Plain 16-bit address: literal-target JR.
        ; disp = target - (patch + 1)
        LD      D, B
        LD      E, C                    ; DE = target
        LD      HL, (asm_tmp2)
        CALL    asm_apply_jr_fixup_emit
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT
.jrc_label:
        ; Label tag: validate idx, look up slot.
        LD      A, C
        LD      HL, asm_label_count
        CP      (HL)
        JP      NC, asm_bad_operand
        CALL    asm_slot_addr           ; HL = &slot
        LD      A, (HL)                 ; resolved?
        OR      A
        JR      Z, .jrc_unresolved
        ; Resolved: read target from slot+1,2.
        INC     HL
        LD      E, (HL)
        INC     HL
        LD      D, (HL)                 ; DE = target
        LD      HL, (asm_tmp2)          ; HL = patch addr
        CALL    asm_apply_jr_fixup_emit
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT
.jrc_unresolved:
        ; Emit 0x00 placeholder displacement, queue fixup.
        XOR     A
        CALL    asm_emit_byte
        ; A = label idx, C-arg = kind, HL = patch addr.
        LD      A, C                    ; A = label index
        LD      C, ASM_FIXUP_KIND_JR
        LD      HL, (asm_tmp2)
        CALL    asm_add_fixup
        LD      DE, (asm_ip_save)
        POP     BC                      ; pop new TOS
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
        LD      A, 0xC3
        JP      asm_jp_call_word

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
        ; Save the target operand (BC) — could be label tag or literal.
        LD      H, B
        LD      L, C
        LD      (asm_tmp2), HL          ; save target/tag
        ; Pop the cell that was below TOS into BC. This is semantically
        ; a peek + conditional-consume: unconditional form leaves this
        ; value as the new TOS (1 cell consumed total), conditional form
        ; does one more POP later (2 cells consumed total).
        POP     BC
        LD      A, B
        CP      ASM_COND_TAG_HI
        JR      Z, .jpc_cond
        ; --- unconditional path ---
        LD      A, (asm_jp_op)
        CALL    asm_emit_byte
        JR      .jpc_emit_target
.jpc_cond:
        ; --- conditional path ---
        ; Compute the conditional base for JP (0xC2) or CALL (0xC4).
        LD      A, (asm_jp_op)
        CP      0xC3
        JR      Z, .jpc_cond_jp
        LD      A, 0xC4                 ; CALL cond base
        JR      .jpc_have_base
.jpc_cond_jp:
        LD      A, 0xC2                 ; JP cond base
.jpc_have_base:
        LD      H, A                    ; H = cond base
        LD      A, C                    ; A = cc (low byte of cond tag)
        AND     0x07                    ; defence: range 0..7
        RLCA
        RLCA
        RLCA                            ; A = cc << 3
        OR      H                       ; A = base | (cc<<3)
        CALL    asm_emit_byte
        POP     BC                      ; consume the cell below the cond tag
.jpc_emit_target:
        ; HL := saved target/tag.
        LD      HL, (asm_tmp2)
        LD      A, H
        CP      ASM_LABEL_TAG_HI
        JR      Z, .jpc_label
        ; Literal target — emit lo then hi.
        LD      A, L
        CALL    asm_emit_byte
        LD      HL, (asm_tmp2)
        LD      A, H
        CALL    asm_emit_byte
        JR      .jpc_done
.jpc_label:
        ; Label tag: validate slot index. HL is discarded — the slot
        ; look-up below rebuilds it from A via asm_slot_addr.
        LD      A, L                    ; A = slot idx
        LD      HL, asm_label_count
        CP      (HL)
        JP      NC, asm_bad_operand
        PUSH    AF                      ; save slot idx (only needed for
                                        ; the unresolved path; balanced
                                        ; with a discard pop on resolve)
        CALL    asm_slot_addr           ; HL = &slot
        LD      A, (HL)                 ; resolved?
        OR      A
        JR      Z, .jpc_unres
        ; Resolved — read lo+hi from slot+1/slot+2 into DE before any
        ; emit (asm_emit_byte clobbers HL but preserves DE), then emit
        ; both bytes without re-looking-up the slot.
        INC     HL
        LD      E, (HL)                 ; lo
        INC     HL
        LD      D, (HL)                 ; hi
        POP     AF                      ; discard saved slot idx
        LD      A, E
        CALL    asm_emit_byte
        LD      A, D
        CALL    asm_emit_byte
        JR      .jpc_done
.jpc_unres:
        ; Save patch addr = HERE; emit 2 zero placeholders; queue fixup.
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (asm_tmp2), HL          ; patch addr
        XOR     A
        CALL    asm_emit_byte
        XOR     A
        CALL    asm_emit_byte
        POP     AF                      ; A = slot idx
        LD      C, ASM_FIXUP_KIND_DW    ; share DW fixup kind
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
        ; Depth guard — BC is phantom garbage when the data stack is
        ; empty (see memory project_tos_in_register). Without this
        ; check, a post-boot or post-ABORT BC that happens to match
        ; ASM_COND_TAG_HI would take the conditional path and POP
        ; from an empty stack. Need sp_base - SP >= 2 (one real cell).
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
        CP      ASM_COND_TAG_HI
        JR      Z, .retc_cond
.retc_uncond:
        ; Unconditional — emit 0xC9, do NOT pop TOS.
        LD      A, 0xC9
        CALL    asm_emit_byte
        NEXT
.retc_cond:
        LD      A, C
        AND     0x07                    ; defence: range
        RLCA
        RLCA
        RLCA
        OR      0xC0
        CALL    asm_emit_byte
        POP     BC                      ; consume the cond tag (new TOS)
        NEXT

; =====================================================================
; DB, ( value -- )    emit one byte (low byte of value)
; =====================================================================
w_DB_COMMA:
        DEFCODE "DB,", 0
w_DB_COMMA_cf:
        CALL    check_asm_mode
        ; Reject label tags — `LABEL X X DB,` is almost always a user
        ; mistake; emitting the slot index byte silently is a UX trap.
        LD      A, B
        CP      ASM_LABEL_TAG_HI
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
        LD      A, B
        CP      ASM_LABEL_TAG_HI
        JR      Z, .dwc_label
        ; Plain int: emit low then high (asm_emit_byte preserves DE).
        LD      A, C
        CALL    asm_emit_byte
        LD      A, B
        CALL    asm_emit_byte
        POP     BC
        NEXT
.dwc_label:
        ; Spill IP — the slot lookups use HL only but we'll touch DE
        ; via fixup queue / asm_add_fixup which preserves DE; still,
        ; spill for safety since asm_slot_addr's PUSH/POP DE leaves
        ; DE intact but the body is easier to reason about with a save.
        LD      (asm_ip_save), DE
        LD      A, C
        LD      HL, asm_label_count
        CP      (HL)
        JP      NC, asm_bad_operand
        CALL    asm_slot_addr           ; HL = &slot
        LD      A, (HL)
        OR      A
        JR      Z, .dwc_unresolved
        ; Resolved: emit target lo then hi via two emits. Re-look-up
        ; slot for hi byte (asm_emit_byte clobbers HL).
        INC     HL
        LD      A, (HL)                 ; target lo
        CALL    asm_emit_byte
        LD      A, C                    ; slot idx
        CALL    asm_slot_addr
        INC     HL
        INC     HL
        LD      A, (HL)
        CALL    asm_emit_byte
        LD      DE, (asm_ip_save)
        POP     BC
        NEXT
.dwc_unresolved:
        ; Save patch addr = HERE before placeholders.
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (asm_tmp2), HL
        XOR     A
        CALL    asm_emit_byte
        XOR     A
        CALL    asm_emit_byte
        LD      A, C                    ; A = slot idx
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
