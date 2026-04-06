; compiler.asm — Colon compiler words (:, ;, [, ], LITERAL)
; AntForth — A Forth for CP/M on Z80

; === Compiler scratch variables ===
colon_saved_here:    DW 0   ; HERE at entry to `:` (for error recovery)
colon_smudge_addr:   DW 0   ; Address of count_flags byte (for unsmudging)
colon_saved_bucket:  DB 0   ; Hash bucket index (for error recovery)
colon_saved_head:    DW 0   ; Previous bucket head value (for error recovery)

; -----------------------------------------------
; : (COLON) ( "<spaces>name" -- )
;   Begin a new colon definition. Parse name, create dictionary header
;   at HERE with SMUDGE set, emit JP DOCOL, enter compile mode.
; -----------------------------------------------
w_COLON:
        DEFCODE ":", 0
w_COLON_cf:
        ; Save DE (IP) and BC (TOS) to return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B

        ; --- 1.2: Save current HERE for error recovery ---
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (colon_saved_here), HL

        ; --- 1.1: Parse the next word from input using WORD logic ---
        ; Set up delimiter = space (0x20) in C, call w_WORD_cf inline logic
        ; Actually, call WORD as subroutine via manual execution:
        ; We'll parse manually like WORD does, since we're in a CODE word.
        ; Load parse state: HL = tib_addr + >IN
        LD      E, (IY+UserArea.tib_addr)
        LD      D, (IY+UserArea.tib_addr+1)    ; DE = tib_addr
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)      ; HL = >IN
        ADD     HL, DE                          ; HL = tib_addr + >IN (parse pos)

        ; Compute remaining = tib_len - >IN
        LD      E, (IY+UserArea.tib_len)
        LD      D, (IY+UserArea.tib_len+1)     ; DE = tib_len
        LD      A, (IY+UserArea.tib_in)
        LD      C, A
        LD      A, (IY+UserArea.tib_in+1)
        LD      B, A                            ; BC = >IN
        EX      DE, HL                          ; DE = parse pos, HL = tib_len
        OR      A
        SBC     HL, BC                          ; HL = remaining
        LD      B, H
        LD      C, L                            ; BC = remaining
        EX      DE, HL                          ; HL = parse pos

        ; Skip leading spaces
.colon_skip:
        LD      A, B
        OR      C
        JP      Z, .colon_no_name              ; No chars left
        LD      A, (HL)
        CP      ' '
        JR      NZ, .colon_found_name
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
        JR      .colon_skip

.colon_no_name:
        ; No name found — error, restore and abort
        ; Restore BC and DE from return stack
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX
        JP      w_ABORT_cf

.colon_found_name:
        ; HL = start of name in TIB, BC = remaining chars
        ; Save name start
        LD      (.colon_name_start), HL

        ; Scan for end of name (next space or end of buffer)
        LD      D, 0                            ; D = name length counter
.colon_scan:
        LD      A, B
        OR      C
        JR      Z, .colon_scan_done
        LD      A, (HL)
        CP      ' '
        JR      Z, .colon_scan_delim
        INC     HL
        DEC     BC
        INC     D
        ; Update >IN
        PUSH    HL
        PUSH    BC
        PUSH    DE
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     DE
        POP     BC
        POP     HL
        JR      .colon_scan

.colon_scan_delim:
        ; Skip the trailing delimiter
        PUSH    HL
        PUSH    DE
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     DE
        POP     HL

.colon_scan_done:
        ; D = name length — clamp to F_LENMASK (31) max
        LD      A, D
        CP      F_LENMASK + 1
        JR      C, .colon_len_ok
        LD      A, F_LENMASK            ; Clamp to 31
.colon_len_ok:
        LD      (.colon_name_len), A

        ; --- 1.2 already done above ---

        ; --- Hash the name ---
        LD      HL, (.colon_name_start)
        LD      B, A                            ; B = name length
        CALL    hash_name                       ; A = bucket index (0-63)
        LD      (.colon_bucket), A              ; Save bucket index

        ; --- 1.7: Save hash bucket index and head for error recovery ---
        LD      (colon_saved_bucket), A
        ; Compute bucket head address: hash_table + A*2
        LD      L, A
        LD      H, 0
        ADD     HL, HL                          ; HL = bucket * 2
        LD      BC, hash_table
        ADD     HL, BC                          ; HL = &hash_table[bucket]
        LD      (.colon_bucket_addr), HL        ; Save for later update
        ; Read current bucket head
        LD      C, (HL)
        INC     HL
        LD      B, (HL)                         ; BC = current bucket head (prev entry)
        LD      (colon_saved_head), BC          ; Save for error recovery

        ; --- 1.3: Build dictionary entry at HERE ---
        ; Load HERE
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)         ; HL = HERE

        ; Emit hash_link (2 bytes): current bucket head
        LD      (HL), C                          ; Low byte of prev entry
        INC     HL
        LD      (HL), B                          ; High byte of prev entry
        INC     HL

        ; --- 1.6: Save address of count_flags for later unsmudging ---
        LD      (colon_smudge_addr), HL

        ; Emit count_flags (1 byte): F_SMUDGE | name_length
        LD      A, (.colon_name_len)
        OR      F_SMUDGE                         ; Set SMUDGE flag
        LD      (HL), A
        INC     HL

        ; Emit name string (copy from TIB)
        LD      DE, (.colon_name_start)          ; DE = source (name in TIB)
        LD      A, (.colon_name_len)
        LD      B, A                             ; B = name length
.colon_copy_name:
        LD      A, (DE)
        LD      (HL), A
        INC     DE
        INC     HL
        DJNZ    .colon_copy_name

        ; --- 1.5: Emit code field: JP DOCOL (3 bytes) ---
        LD      (HL), 0xC3                       ; JP opcode
        INC     HL
        LD      (HL), LOW DOCOL
        INC     HL
        LD      (HL), HIGH DOCOL
        INC     HL

        ; Update HERE past code field (body starts here)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; --- 1.4: Update hash bucket head to point to this new entry ---
        LD      HL, (.colon_bucket_addr)
        LD      BC, (colon_saved_here)           ; Entry starts at saved HERE
        LD      (HL), C
        INC     HL
        LD      (HL), B

        ; --- 1.9: Update LATEST to point to the new entry ---
        LD      (IY+UserArea.latest), C
        LD      (IY+UserArea.latest+1), B

        ; --- 1.8: Set STATE to compile mode ---
        LD      (IY+UserArea.state), 1
        LD      (IY+UserArea.state+1), 0

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

; Scratch storage for COLON
.colon_name_start:  DW 0
.colon_name_len:    DB 0
.colon_bucket:      DB 0
.colon_bucket_addr: DW 0

; -----------------------------------------------
; COMP-ERROR ( c-addr -- ) internal, never returns
;   Compilation error recovery: restore HERE, unlink hash entry,
;   print error, ABORT.
; -----------------------------------------------
w_COMP_ERROR:
        DEFCODE "COMP-ERROR", 0
w_COMP_ERROR_cf:
        ; BC = c-addr (TOS) — the unknown word's counted string
        ; Save c-addr for error message
        PUSH    BC

        ; --- 5.1: Restore HERE from colon_saved_here ---
        LD      HL, (colon_saved_here)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; --- 5.2: Restore hash bucket head ---
        LD      A, (colon_saved_bucket)
        LD      L, A
        LD      H, 0
        ADD     HL, HL                          ; HL = bucket * 2
        LD      BC, hash_table
        ADD     HL, BC                          ; HL = &hash_table[bucket]
        LD      BC, (colon_saved_head)
        LD      (HL), C
        INC     HL
        LD      (HL), B

        ; --- 5.3: Set STATE to 0 ---
        LD      (IY+UserArea.state), 0
        LD      (IY+UserArea.state+1), 0

        ; Print error message: "word ?" CR
        POP     BC                              ; BC = c-addr
        ; Print counted string: get count byte, then name
        LD      H, B
        LD      L, C                            ; HL = c-addr
        LD      A, (HL)                         ; A = count
        AND     F_LENMASK
        OR      A
        JR      Z, .comp_err_abort              ; empty name, just abort
        LD      B, A                            ; B = length
        INC     HL                              ; HL = name start
        ; Print chars via BDOS
.comp_err_print:
        LD      E, (HL)
        PUSH    HL
        PUSH    BC
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        POP     BC
        POP     HL
        INC     HL
        DJNZ    .comp_err_print
        ; Print " ?"
        LD      E, ' '
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        LD      E, '?'
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        ; CR LF
        LD      E, 0x0D
        LD      C, C_WRITE
        CALL    BDOS_ENTRY
        LD      E, 0x0A
        LD      C, C_WRITE
        CALL    BDOS_ENTRY

.comp_err_abort:
        ; --- 5.4: Call ABORT ---
        JP      w_ABORT_cf

; -----------------------------------------------
; ; (SEMICOLON) ( -- ) IMMEDIATE
;   End a colon definition. Compile EXIT, clear SMUDGE, return to
;   interpret mode.
; -----------------------------------------------
w_SEMICOLON:
        DEFCODE ";", F_IMMEDIATE
w_SEMICOLON_cf:
        ; Guard: `;` is only valid in compile mode
        LD      A, (IY+UserArea.state)
        OR      A
        JR      NZ, .semi_ok
        LD      A, (IY+UserArea.state+1)
        OR      A
        JR      NZ, .semi_ok
        ; STATE=0 — `;` used outside definition, abort
        JP      w_ABORT_cf
.semi_ok:
        ; --- 3.1: Compile EXIT_CODE into the definition ---
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)         ; HL = HERE
        LD      (HL), LOW EXIT_CODE
        INC     HL
        LD      (HL), HIGH EXIT_CODE
        INC     HL
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; --- 3.2: Clear SMUDGE flag ---
        LD      HL, (colon_smudge_addr)
        LD      A, (HL)
        AND     ~F_SMUDGE                        ; Clear bit 6
        LD      (HL), A

        ; --- 3.3: Set STATE to 0 (interpret mode) ---
        LD      (IY+UserArea.state), 0
        LD      (IY+UserArea.state+1), 0

        NEXT

; -----------------------------------------------
; [ ( -- ) IMMEDIATE
;   Switch to interpret mode (set STATE to 0)
; -----------------------------------------------
w_LEFT_BRACKET:
        DEFCODE "[", F_IMMEDIATE
w_LEFT_BRACKET_cf:
        LD      (IY+UserArea.state), 0
        LD      (IY+UserArea.state+1), 0
        NEXT

; -----------------------------------------------
; ] ( -- )
;   Switch to compile mode (set STATE to non-zero)
; -----------------------------------------------
w_RIGHT_BRACKET:
        DEFCODE "]", 0
w_RIGHT_BRACKET_cf:
        LD      (IY+UserArea.state), 1
        LD      (IY+UserArea.state+1), 0
        NEXT

; -----------------------------------------------
; LITERAL ( n -- ) IMMEDIATE
;   Compile LIT n into the current definition.
;   Used as: [ expr ] LITERAL inside colon definitions.
; -----------------------------------------------
w_LITERAL:
        DEFCODE "LITERAL", F_IMMEDIATE
w_LITERAL_cf:
        ; Compile LIT xt at HERE
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)         ; HL = HERE
        LD      (HL), LOW w_LIT_cf
        INC     HL
        LD      (HL), HIGH w_LIT_cf
        INC     HL
        ; Compile the value (BC = TOS = n)
        LD      (HL), C
        INC     HL
        LD      (HL), B
        INC     HL
        ; Update HERE
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        ; Consume n from stack
        POP     BC
        NEXT
