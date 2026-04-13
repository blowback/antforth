; outer_interpreter.asm — Outer interpreter, REPL loop, user variable words
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; push_user_var — Internal helper
;   Push address of user variable at IY+offset
;   Entry: A = offset into UserArea, BC = previous TOS
;   Exit:  BC = IY + offset (address of user variable)
; -----------------------------------------------
push_user_var:
        PUSH    BC              ; Save current TOS
        PUSH    IY
        POP     HL              ; HL = IY (user area base)
        LD      C, A
        LD      B, 0            ; BC = offset
        ADD     HL, BC          ; HL = IY + offset
        LD      B, H
        LD      C, L            ; BC = address (new TOS)
        NEXT

; -----------------------------------------------
; STATE ( -- addr )
;   Push address of STATE variable
; -----------------------------------------------
w_STATE:
        DEFCODE "STATE", 0
w_STATE_cf:
        LD      A, UserArea.state
        JP      push_user_var

; -----------------------------------------------
; BASE ( -- addr )
;   Push address of BASE variable
; -----------------------------------------------
w_BASE:
        DEFCODE "BASE", 0
w_BASE_cf:
        LD      A, UserArea.base
        JP      push_user_var

; -----------------------------------------------
; >IN ( -- addr )
;   Push address of >IN variable
; -----------------------------------------------
w_TO_IN:
        DEFCODE ">IN", 0
w_TO_IN_cf:
        LD      A, UserArea.tib_in
        JP      push_user_var

; -----------------------------------------------
; #TIB ( -- addr )
;   Push address of #TIB variable
; -----------------------------------------------
w_TIB_LEN:
        DEFCODE "#TIB", 0
w_TIB_LEN_cf:
        LD      A, UserArea.tib_len
        JP      push_user_var

; -----------------------------------------------
; SOURCE ( -- c-addr u )
;   Push TIB address and current input length
; -----------------------------------------------
w_SOURCE:
        DEFCODE "SOURCE", 0
w_SOURCE_cf:
        PUSH    BC                      ; Save TOS
        ; Push TIB address
        LD      L, (IY+UserArea.tib_addr)
        LD      H, (IY+UserArea.tib_addr+1)
        PUSH    HL                      ; c-addr on stack
        ; TOS = tib_len
        LD      C, (IY+UserArea.tib_len)
        LD      B, (IY+UserArea.tib_len+1)
        NEXT

; -----------------------------------------------
; BL ( -- char )
;   Push space character 0x20
; -----------------------------------------------
w_BL:
        DEFCODE "BL", 0
w_BL_cf:
        PUSH    BC
        LD      BC, 0x0020
        NEXT

; -----------------------------------------------
; QUERY ( -- )
;   Read a line from the console into TIB, set #TIB and >IN
;   Does NOT touch the parameter stack (stack-neutral housekeeping)
;   Used by QUIT loop to avoid phantom TOS values
; -----------------------------------------------
w_QUERY:
        DEFCODE "QUERY", 0
w_QUERY_cf:
        ; Save DE (IP) and BC (TOS) to return stack
        CALL    rpush_de
        CALL    rpush_bc

        ; Set max_len in BDOS input buffer header
        LD      A, TIB_SIZE
        LD      (bdos_input_buf), A

        ; Call BDOS function 10: read console buffer
        LD      DE, bdos_input_buf
        LD      C, C_READSTR
        CALL    BDOS_ENTRY

        ; BDOS 10 echoes CR — emit LF ourselves
        LD      E, 0x0A
        CALL    bdos_putchar

        ; Set #TIB = actual chars read
        LD      A, (bdos_input_len)
        LD      (IY+UserArea.tib_len), A
        XOR     A
        LD      (IY+UserArea.tib_len+1), A

        ; Reset >IN = 0
        LD      (IY+UserArea.tib_in), A         ; A = 0
        LD      (IY+UserArea.tib_in+1), A

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

; -----------------------------------------------
; INTERPRET ( -- )
;   Parse and execute all words in the input buffer
;   Uses BRANCH/?BRANCH with manual offsets (no control flow words)
; -----------------------------------------------
w_INTERPRET:
        DEFWORD "INTERPRET", 0
w_INTERPRET_body:
w_INTERPRET_cf  EQU     w_INTERPRET_body - 3    ; Code field = JP DOCOL, 3 bytes before body
.interp_loop:
        DW      w_BL_cf                 ; ( -- 32 )
        DW      w_WORD_cf               ; ( 32 -- c-addr )
        DW      w_DUP_cf                ; ( c-addr -- c-addr c-addr )
        DW      w_C_FETCH_cf            ; ( c-addr c-addr -- c-addr count )
        DW      w_QBRANCH_cf            ; if count=0, done
        DW      .interp_done - $
        ; Non-empty token — try FIND
        DW      w_FIND_cf               ; ( c-addr -- c-addr 0 | xt flag )
        DW      w_DUP_cf                ; ( ... x -- ... x x )
        DW      w_QBRANCH_cf            ; if flag=0 (not found), try number
        DW      .try_number - $
        ; Found: ( xt flag )
        ; Check STATE: if interpreting OR flag=1 (IMMEDIATE), execute
        DW      w_STATE_cf              ; ( xt flag -- xt flag state-addr )
        DW      w_FETCH_cf              ; ( xt flag state-addr -- xt flag state )
        DW      w_QBRANCH_cf            ; if STATE=0 (interpreting), go execute
        DW      .interp_execute - $
        ; STATE != 0 (compiling)
        ; Check if flag=1 (IMMEDIATE) — immediate words execute even in compile mode
        ; flag is on stack: ( xt flag ) — flag=1 means IMMEDIATE, flag=-1 means normal
        DW      w_LIT_cf, 1
        DW      w_EQUALS_cf             ; ( xt flag 1 -- xt flag=1? )
        DW      w_QBRANCH_cf            ; if not IMMEDIATE, compile
        DW      .compile_word - $
        ; IMMEDIATE word in compile mode: execute it
        DW      w_EXECUTE_cf            ; ( xt -- )
        DW      w_BRANCH_cf
        DW      .interp_loop - $
.compile_word:
        ; Non-immediate word in compile mode: compile xt via COMMA
        DW      w_COMMA_cf              ; ( xt -- ) compile xt at HERE
        DW      w_BRANCH_cf
        DW      .interp_loop - $
.interp_execute:
        ; Interpret mode: ( xt flag ) — drop flag, execute
        DW      w_DROP_cf               ; ( xt flag -- xt )
        DW      w_EXECUTE_cf            ; execute the word
        DW      w_BRANCH_cf             ; loop back
        DW      .interp_loop - $
.try_number:
        ; Stack: ( c-addr 0 ) — not found
        DW      w_DROP_cf               ; ( c-addr 0 -- c-addr )
        DW      w_NUMBER_Q_cf           ; ( c-addr -- n true | c-addr false )
        DW      w_QBRANCH_cf            ; if false, error
        DW      .not_number - $
        ; Valid number — check STATE
        DW      w_STATE_cf              ; ( n -- n state-addr )
        DW      w_FETCH_cf              ; ( n state-addr -- n state )
        DW      w_QBRANCH_cf            ; if STATE=0, leave number on stack
        DW      .interp_loop - $        ; interpreting: n stays on stack, loop
        ; Compiling: compile LIT n
        DW      w_LIT_cf, w_LIT_cf      ; ( n -- n lit-xt )
        DW      w_COMMA_cf              ; ( n lit-xt -- n ) compile LIT address
        DW      w_COMMA_cf              ; ( n -- ) compile the number value
        DW      w_BRANCH_cf
        DW      .interp_loop - $
.not_number:
        ; Stack: ( c-addr ) — not a word, not a number
        ; Check STATE — if compiling, do error recovery
        DW      w_STATE_cf              ; ( c-addr -- c-addr state-addr )
        DW      w_FETCH_cf              ; ( c-addr state-addr -- c-addr state )
        DW      w_QBRANCH_cf            ; if STATE=0, normal error
        DW      .interp_error - $
        ; Compilation error: restore HERE and unlink hash entry
        DW      w_COMP_ERROR_cf         ; ( c-addr -- ) never returns (calls ABORT)
.interp_error:
        DW      w_COUNT_cf              ; ( c-addr -- addr len )
        DW      w_TYPE_cf               ; print the unknown word
        DW      w_LIT_cf, ' '
        DW      w_EMIT_cf               ; space
        DW      w_LIT_cf, '?'
        DW      w_EMIT_cf               ; question mark
        DW      w_CR_cf                 ; newline
        DW      w_ABORT_cf              ; reset and restart QUIT (never returns)
.interp_done:
        DW      w_DROP_cf               ; drop the empty c-addr
        DW      EXIT_CODE               ; return to caller (QUIT loop)

; -----------------------------------------------
; QUIT ( -- )
;   Reset return stack, set interpret mode, enter REPL loop
;   Never returns — loops forever (or until BYE)
; -----------------------------------------------
w_QUIT:
        DEFCODE "QUIT", 0
w_QUIT_cf:
        ; Reset return stack
        LD      HL, (rp_base)
        PUSH    HL
        POP     IX
        ; STATE = 0 (interpret mode)
        XOR     A
        LD      (IY+UserArea.state), A
        LD      (IY+UserArea.state+1), A
        ; Enter the QUIT loop thread
        LD      DE, .quit_loop
        NEXT

.quit_loop:
        ; Read line of input, set #TIB and >IN (stack-neutral)
        DW      w_QUERY_cf
        ; Interpret the line
        DW      w_INTERPRET_cf
        ; Only print " ok" when STATE=0 (interpret mode)
        DW      w_STATE_cf              ; ( -- state-addr )
        DW      w_FETCH_cf              ; ( state-addr -- state )
        DW      w_QBRANCH_cf            ; if STATE=0, print ok
        DW      .quit_ok - $
        ; STATE != 0 (compiling), skip ok prompt
        DW      w_BRANCH_cf
        DW      .quit_loop - $
.quit_ok:
        DW      w_LIT_cf, str_ok        ; ( -- addr )
        DW      w_LIT_cf, STR_OK_LEN    ; ( addr -- addr len )
        DW      w_TYPE_cf               ; print " ok"
        DW      w_CR_cf                 ; newline
        ; Loop forever
        DW      w_BRANCH_cf
        DW      .quit_loop - $
