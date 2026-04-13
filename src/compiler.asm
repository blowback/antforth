; compiler.asm — Colon compiler words (:, ;, [, ], LITERAL, CREATE, CONSTANT, DOES>)
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; >BODY ( xt -- a-addr )
;   Given xt (code field address of a CREATE'd word), return body address
;   CREATE layout: [JP DOVAR (3 bytes)][does-addr (2 bytes)][body...]
;   So body = xt + 5
; -----------------------------------------------
w_TO_BODY:
        DEFCODE ">BODY", 0
w_TO_BODY_cf:
        INC     BC              ; +1
        INC     BC              ; +2
        INC     BC              ; +3
        INC     BC              ; +4
        INC     BC              ; +5
        NEXT

; -----------------------------------------------
; ' (tick) ( "<spaces>name" -- xt )
;   Parse next word, find it, return its execution token
;   Error if word not found
; -----------------------------------------------
w_TICK:
        DEFWORD "'", 0
w_TICK_body:
w_TICK_cf EQU w_TICK_body - 3
        DW w_BL_cf                   ; ( -- 32 )
        DW w_WORD_cf                 ; ( 32 -- c-addr )
        DW w_FIND_cf                 ; ( c-addr -- c-addr 0 | xt 1 | xt -1 )
        DW w_DUP_cf                  ; ( ... flag flag )
        DW w_QBRANCH_cf              ; if flag=0, not found
        DW .tick_notfound - $
        ; Found: ( xt flag ) — drop flag, keep xt
        DW w_DROP_cf                 ; ( xt )
        DW EXIT_CODE
.tick_notfound:
        ; ( c-addr 0 ) — word not found
        DW w_DROP_cf                 ; drop 0, leaving c-addr
        DW w_COUNT_cf                ; ( c-addr -- addr len )
        DW w_TYPE_cf                 ; print the unknown word
        DW w_LIT_cf, ' '
        DW w_EMIT_cf                 ; space
        DW w_LIT_cf, '?'
        DW w_EMIT_cf                 ; question mark
        DW w_CR_cf                   ; newline
        DW w_ABORT_cf                ; reset and restart (never returns)

; -----------------------------------------------
; ['] ( "<spaces>name" -- ) compile: ( -- xt )
;   Compile-time: parse name, find xt, compile as literal
; -----------------------------------------------
w_BRACKET_TICK:
        DEFIMMED "[']"
w_BRACKET_TICK_body:
w_BRACKET_TICK_cf EQU w_BRACKET_TICK_body - 3
        DW w_TICK_cf                 ; ( -- xt ) parse and find word
        DW w_LITERAL_cf              ; compile xt as inline literal
        DW EXIT_CODE

; -----------------------------------------------
; [CHAR] ( "<spaces>name" -- ) compile: ( -- char )
;   Compile-time: parse name, get first char, compile as literal
; -----------------------------------------------
w_BRACKET_CHAR:
        DEFIMMED "[CHAR]"
w_BRACKET_CHAR_body:
w_BRACKET_CHAR_cf EQU w_BRACKET_CHAR_body - 3
        DW w_CHAR_cf                 ; ( -- char ) parse and get first char
        DW w_LITERAL_cf              ; compile char as inline literal
        DW EXIT_CODE

; === Shared header-building scratch variables ===
bh_name_start:       DW 0   ; Pointer to name in TIB
bh_name_len:         DB 0   ; Clamped name length
bh_bucket_index:     DB 0   ; Hash bucket index (0-63)
bh_bucket_addr:      DW 0   ; Address in hash_table
bh_entry_start:      DW 0   ; HERE at entry (entry start address)
bh_old_bucket_head:  DW 0   ; Previous bucket head (for error recovery)
bh_count_flags_addr: DW 0   ; Address of count_flags byte (for unsmudging)
bh_flags:            DB 0   ; Flags to OR into count_flags
bh_code_field:       DW 0   ; Code field position (saved for return)

; === COLON error recovery variables ===
; (Used by SEMICOLON and COMP-ERROR — populated from bh_* after build_header)
colon_saved_here:    DW 0
colon_smudge_addr:   DW 0
colon_saved_bucket:  DB 0
colon_saved_head:    DW 0

; -----------------------------------------------
; build_header — Shared subroutine for :, CREATE, CONSTANT
;   Parse name from TIB, build dictionary header at HERE,
;   update hash bucket and LATEST.
;   Input:  A = flags to OR into count_flags (e.g. F_SMUDGE)
;   Output: CF=0 success, HL = code field position
;           CF=1 error (no name found)
;   Clobbers: A, BC, DE, HL, flags
; -----------------------------------------------
build_header:
        LD      (bh_flags), A

        ; Save current HERE as entry start
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (bh_entry_start), HL

        ; --- Parse next word from input ---
        LD      E, (IY+UserArea.tib_addr)
        LD      D, (IY+UserArea.tib_addr+1)    ; DE = tib_addr
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)      ; HL = >IN
        ADD     HL, DE                          ; HL = tib_addr + >IN

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
.bh_skip:
        LD      A, B
        OR      C
        JR      Z, .bh_no_name                 ; No chars left
        LD      A, (HL)
        CP      ' '
        JR      NZ, .bh_found_name
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
        JR      .bh_skip

.bh_no_name:
        SCF                                     ; Set carry = error
        RET

.bh_found_name:
        LD      (bh_name_start), HL

        ; Scan for end of name
        LD      D, 0                            ; D = name length counter
.bh_scan:
        LD      A, B
        OR      C
        JR      Z, .bh_scan_done
        LD      A, (HL)
        CP      ' '
        JR      Z, .bh_scan_delim
        INC     HL
        DEC     BC
        INC     D
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
        JR      .bh_scan

.bh_scan_delim:
        PUSH    HL
        PUSH    DE
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     DE
        POP     HL

.bh_scan_done:
        ; D = name length — clamp to F_LENMASK (31) max
        LD      A, D
        CP      F_LENMASK + 1
        JR      C, .bh_len_ok
        LD      A, F_LENMASK
.bh_len_ok:
        LD      (bh_name_len), A

        ; --- Hash the name ---
        LD      HL, (bh_name_start)
        LD      B, A                            ; B = name length
        CALL    hash_name                       ; A = bucket index
        LD      (bh_bucket_index), A

        ; Compute bucket head address: hash_table + A*2
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      BC, hash_table
        ADD     HL, BC                          ; HL = &hash_table[bucket]
        LD      (bh_bucket_addr), HL
        ; Read current bucket head
        LD      C, (HL)
        INC     HL
        LD      B, (HL)                         ; BC = current bucket head
        LD      (bh_old_bucket_head), BC

        ; --- Build dictionary entry at HERE ---
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)         ; HL = HERE

        ; Emit hash_link (2 bytes)
        LD      (HL), C
        INC     HL
        LD      (HL), B
        INC     HL

        ; Save count_flags address
        LD      (bh_count_flags_addr), HL

        ; Emit count_flags: flags | name_len
        LD      A, (bh_name_len)
        LD      B, A                             ; save name_len for copy loop
        LD      A, (bh_flags)
        OR      B                                ; A = flags | name_len
        LD      (HL), A
        INC     HL

        ; Copy name string from TIB
        LD      DE, (bh_name_start)
        LD      A, (bh_name_len)
        LD      B, A
.bh_copy_name:
        LD      A, (DE)
        LD      (HL), A
        INC     DE
        INC     HL
        DJNZ    .bh_copy_name

        ; HL = code field position — save it
        LD      (bh_code_field), HL

        ; --- Update hash bucket head to point to new entry ---
        LD      HL, (bh_bucket_addr)
        LD      BC, (bh_entry_start)
        LD      (HL), C
        INC     HL
        LD      (HL), B

        ; --- Update LATEST ---
        LD      (IY+UserArea.latest), C
        LD      (IY+UserArea.latest+1), B

        ; Restore HL = code field position, clear carry = success
        LD      HL, (bh_code_field)
        OR      A
        RET

; -----------------------------------------------
; POSTPONE ( "<spaces>name" -- ) IMMEDIATE, compile-only
;   If name is non-IMMEDIATE: compile its xt directly (deferred compilation)
;   If name is IMMEDIATE: compile [LIT xt COMPILE,] to defer its execution
; -----------------------------------------------
w_POSTPONE:
        DEFIMMED "POSTPONE"
w_POSTPONE_body:
w_POSTPONE_cf EQU w_POSTPONE_body - 3
        DW w_QCOMP_cf                ; compile-only guard
        DW w_BL_cf                   ; ( -- 32 )
        DW w_WORD_cf                 ; ( 32 -- c-addr )
        DW w_FIND_cf                 ; ( c-addr -- c-addr 0 | xt 1 | xt -1 )
        DW w_DUP_cf                  ; ( ... flag -- ... flag flag )
        DW w_QBRANCH_cf              ; if flag=0, not found
        DW .postpone_notfound - $
        ; Found: ( xt flag )
        DW w_LIT_cf, 1
        DW w_EQUALS_cf               ; ( xt flag==1? )
        DW w_QBRANCH_cf              ; if not IMMEDIATE, defer compilation
        DW .postpone_defer - $
        ; IMMEDIATE word: compile xt directly (its compilation semantics = execute)
        DW w_COMMA_cf                ; compile xt at HERE
        DW w_BRANCH_cf
        DW .postpone_done - $
.postpone_defer:
        ; Non-IMMEDIATE word: compile [LIT xt COMPILE,] to defer compilation
        DW w_LIT_cf, w_LIT_cf
        DW w_COMMA_cf                ; compile LIT
        DW w_COMMA_cf                ; compile xt
        DW w_LIT_cf, w_COMPILE_COMMA_cf
        DW w_COMMA_cf                ; compile COMPILE,
        DW w_BRANCH_cf
        DW .postpone_done - $
.postpone_notfound:
        ; ( c-addr 0 ) — word not found
        DW w_DROP_cf                 ; drop 0 flag, leaving c-addr as TOS
        DW w_COMP_ERROR_cf           ; proper cleanup + error message + abort
.postpone_done:
        DW EXIT_CODE

; -----------------------------------------------
; COMPILE, ( xt -- )
;   Compile execution token into the current definition at HERE
;   Functionally identical to , for direct-threaded Forth but
;   semantically distinct per ANS standard
; -----------------------------------------------
w_COMPILE_COMMA:
        DEFCODE "COMPILE,", 0
w_COMPILE_COMMA_cf:
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (HL), C
        INC     HL
        LD      (HL), B
        INC     HL
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        POP     BC              ; New TOS
        NEXT

; -----------------------------------------------
; IMMEDIATE ( -- )
;   Set the IMMEDIATE flag (bit 7) on the most recently defined word
; -----------------------------------------------
w_IMMEDIATE:
        DEFCODE "IMMEDIATE", 0
w_IMMEDIATE_cf:
        ; Load LATEST pointer
        LD      L, (IY+UserArea.latest)
        LD      H, (IY+UserArea.latest+1)
        ; Skip hash_link (2 bytes) to reach count_flags
        INC     HL
        INC     HL
        ; Set F_IMMEDIATE bit
        LD      A, (HL)
        OR      F_IMMEDIATE
        LD      (HL), A
        NEXT

; -----------------------------------------------
; : (COLON) ( "<spaces>name" -- )
;   Begin a new colon definition. Parse name, create dictionary header
;   at HERE with SMUDGE set, emit JP DOCOL, enter compile mode.
; -----------------------------------------------
w_COLON:
        DEFCODE ":", 0
w_COLON_cf:
        ; Save DE (IP) and BC (TOS) to return stack
        CALL    rpush_de
        CALL    rpush_bc

        LD      A, F_SMUDGE
        CALL    build_header
        JR      C, .colon_no_name

        ; Save error recovery info from shared scratch
        LD      BC, (bh_entry_start)
        LD      (colon_saved_here), BC
        LD      A, (bh_bucket_index)
        LD      (colon_saved_bucket), A
        LD      BC, (bh_old_bucket_head)
        LD      (colon_saved_head), BC
        LD      BC, (bh_count_flags_addr)
        LD      (colon_smudge_addr), BC

        ; HL = code field position — emit JP DOCOL
        LD      (HL), 0xC3                       ; JP opcode
        INC     HL
        LD      (HL), LOW DOCOL
        INC     HL
        LD      (HL), HIGH DOCOL
        INC     HL

        ; Update HERE past code field (body starts here)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; Set STATE to compile mode
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

.colon_no_name:
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
        ; Print name via BDOS
        CALL    bdos_print_str
        ; Print " ?" CR LF
        CALL    bdos_print_q_crlf

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

; -----------------------------------------------
; CREATE ( "<spaces>name" -- )
;   Parse name, build dictionary header at HERE with JP DOVAR
;   code field + 2-byte does-addr slot (zeroed). No SMUDGE, no
;   compile mode. Word is immediately findable.
; -----------------------------------------------
w_CREATE:
        DEFCODE "CREATE", 0
w_CREATE_cf:
        ; Save DE (IP) and BC (TOS) to return stack
        CALL    rpush_de
        CALL    rpush_bc

        XOR     A                                ; flags = 0 (no SMUDGE)
        CALL    build_header
        JR      C, .create_no_name

        ; HL = code field — emit JP DOVAR + does-addr slot
        LD      (HL), 0xC3                       ; JP opcode
        INC     HL
        LD      (HL), LOW DOVAR
        INC     HL
        LD      (HL), HIGH DOVAR
        INC     HL
        LD      (HL), 0                          ; does-addr low (zeroed)
        INC     HL
        LD      (HL), 0                          ; does-addr high (zeroed)
        INC     HL

        ; Update HERE (body starts here, user can ALLOT after)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

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

.create_no_name:
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
; CONSTANT ( x "<spaces>name" -- )
;   Parse name, build dictionary header with JP DOCON code field,
;   store x in body.
; -----------------------------------------------
w_CONSTANT:
        DEFCODE "CONSTANT", 0
w_CONSTANT_cf:
        ; Save DE (IP) and BC (TOS=value) to return stack
        CALL    rpush_de
        CALL    rpush_bc                         ; Save the constant value

        XOR     A                                ; flags = 0
        CALL    build_header
        JR      C, .const_no_name

        ; HL = code field — emit JP DOCON
        LD      (HL), 0xC3                       ; JP opcode
        INC     HL
        LD      (HL), LOW DOCON
        INC     HL
        LD      (HL), HIGH DOCON
        INC     HL

        ; Body: emit constant value from return stack
        LD      C, (IX+0)
        LD      B, (IX+1)                        ; BC = saved value
        LD      (HL), C
        INC     HL
        LD      (HL), B
        INC     HL

        ; Update HERE
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; Discard saved value from return stack
        INC     IX
        INC     IX

        ; Restore DE (IP) — TOS consumed
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX

        ; Pop new TOS (value was consumed)
        POP     BC
        NEXT

.const_no_name:
        INC     IX
        INC     IX                               ; Discard saved value
        LD      D, (IX+1)
        LD      E, (IX+0)
        INC     IX
        INC     IX
        POP     BC
        JP      w_ABORT_cf

; -----------------------------------------------
; DOES> ( -- ) IMMEDIATE
;   Compile (DOES>) into the current definition.
;   The DOES> body follows and is compiled normally by ;.
; -----------------------------------------------
w_DOES:
        DEFCODE "DOES>", F_IMMEDIATE
w_DOES_cf:
        ; Guard: DOES> only valid in compile mode
        LD      A, (IY+UserArea.state)
        OR      A
        JR      NZ, .does_ok
        LD      A, (IY+UserArea.state+1)
        OR      A
        JR      NZ, .does_ok
        JP      w_ABORT_cf
.does_ok:
        ; Compile (DOES>) into current definition
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (HL), LOW w_PAREN_DOES_cf
        INC     HL
        LD      (HL), HIGH w_PAREN_DOES_cf
        INC     HL
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        NEXT

; -----------------------------------------------
; (DOES>) ( -- ) runtime helper
;   Patches LATEST word's code field from JP DOVAR to JP DODOES,
;   stores IP (DOES> body addr) at cf+3, then EXITs.
; -----------------------------------------------
w_PAREN_DOES:
        DEFCODE "(DOES>)", 0
w_PAREN_DOES_cf:
        ; DE = IP = address of DOES> body (right after this word in the thread)
        ; Find LATEST word's code field
        LD      L, (IY+UserArea.latest)
        LD      H, (IY+UserArea.latest+1)   ; HL = LATEST (dict entry)
        INC     HL
        INC     HL                           ; HL = &count_flags
        LD      A, (HL)
        AND     F_LENMASK                    ; A = name length
        INC     HL                           ; HL = &name[0]
        ; Skip name bytes to reach code field
        ADD     A, L
        LD      L, A
        JR      NC, .pdoes_no_carry
        INC     H
.pdoes_no_carry:                             ; HL = code field address
        ; Overwrite code field with JP DODOES
        LD      (HL), 0xC3                   ; JP opcode
        INC     HL
        LD      (HL), LOW DODOES
        INC     HL
        LD      (HL), HIGH DODOES
        INC     HL
        ; Write does-addr (DE = IP = DOES> body start)
        LD      (HL), E
        INC     HL
        LD      (HL), D
        ; EXIT — return from defining word (pop IP from return stack)
        CALL    rpop_de
        NEXT
