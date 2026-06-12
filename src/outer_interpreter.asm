; outer_interpreter.asm — Outer interpreter, REPL loop, user variable words
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; push_user_var — Internal helper
;   Push address of user variable at IY+offset
;   Entry: A = offset into UserArea, BC = previous TOS
;   Exit:  BC = IY + offset (address of user variable)
; -----------------------------------------------
push_user_var:
        ; -3 THROW guard (depth +1). check_overflow
        ; clobbers AF/HL; A holds the offset and must be preserved
        ; across the CALL (it's the input contract). Spill A through
        ; the data stack via PUSH AF / POP AF (transient SP +2,
        ; covered by the 32-byte safety margin).
        PUSH    AF              ; spill A (= offset)
        CALL    check_overflow
        POP     AF              ; recover A
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
; DPL ( -- addr )
;   Push address of DPL user variable. DPL holds the count of digits to the
;   right of the dot from the last successful numeric parse, or -1 if no
;   dot was present (single-cell parse). Updated only on successful parses;
;   failed parses leave the previous value intact. Initialised to -1 at
;   cold start.
; de-facto Forth convention (fig-Forth / F83 / gforth / SwiftForth / pforth)
; — NOT in ANS Core. ANS Forth 1994 §3.4.1.3 — dot-marker recogniser
;   exposes the digits-after-dot count for fixed-point reconstruction.
; -----------------------------------------------
w_DPL:
        DEFCODE "DPL", 0
w_DPL_cf:
        LD      A, UserArea.dpl
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

        ; Defensively re-assert canonical REPL source-spec
        ; (tib_addr = tib_buffer, source_id = 0) so that any
        ; leaked source-frame state from a pre-existing EVALUATE /
        ; INCLUDE source-spec cannot survive into the next REPL line.
        ; EVALUATE's CATCH wrapper closes the structural case; this
        ; catches future leak paths uncovered by it. source_id = 0 per
        ; Forth 2014 §6.2.2218 (terminal input). A is already 0 from
        ; the tib_in reset above.
        LD      HL, tib_buffer
        LD      (IY+UserArea.tib_addr), L
        LD      (IY+UserArea.tib_addr+1), H
        LD      (IY+UserArea.source_id), A      ; A still 0 from above
        LD      (IY+UserArea.source_id+1), A

        ; Restore BC (TOS) and DE (IP) from return stack
        CALL    rpop_bc
        CALL    rpop_de
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
        ; Interpret mode: ( xt flag ) — drop flag, recognise an interactive
        ; BANK! (peek), execute, then commit the save. Token identity at THIS
        ; site (xt == BANK!, executed directly by the text interpreter) is the
        ; only signal distinguishing a typed `n BANK!` from a colon word that
        ; internally calls BANK! — the latter runs BANK! nested under its own
        ; DOCOL frame and never re-enters here (docs/antforth-banking-redesign.md
        ; §5.6; arch Findings F6). QMARK-BANK peeks xt WITHOUT touching either
        ; stack and sets a one-shot flag; EXECUTE then consumes xt (and BANK!'s
        ; n arg below it); QSAVE-BANK commits current_bank->saved_bank iff the
        ; flag survived. The flag (not a stack slot) carries the recognition
        ; across EXECUTE because the executed word may rearrange BOTH stacks
        ; (e.g. an interactively-typed >R/R>). If BANK! THROWs, the unwind skips
        ; QSAVE-BANK so a failed switch is never saved.
        DW      w_DROP_cf               ; ( xt flag -- xt )
        DW      w_QMARK_BANK_cf         ; ( xt -- xt )   peek: flag := interactive BANK!?
        DW      w_EXECUTE_cf            ; ( xt -- )      executes the word
        DW      w_QSAVE_BANK_cf         ; ( -- )         commit if flag set
        DW      w_BRANCH_cf             ; loop back
        DW      .interp_loop - $
.try_number:
        ; Stack: ( c-addr 0 ) — not found
        DW      w_DROP_cf               ; ( c-addr 0 -- c-addr )
        DW      w_ASM_RECOGNIZE_cf      ; ( c-addr -- value true | c-addr false )
        ; Success keeps the flag on TOS so .got_value can
        ; dispatch on flag=2 (double) vs anything-nonzero (single).
        ; ASM-RECOGNIZE returns 0xFFFF (single) or 0 (fail).
        DW      w_DUP_cf                ; ( ... flag flag )
        DW      w_QBRANCH_cf
        DW      .try_pn_drop - $        ; if false, drop and try prefix
        DW      w_BRANCH_cf
        DW      .got_value - $          ; if true, keep flag, share handling
.try_pn_drop:
        DW      w_DROP_cf               ; drop the duplicated false
.try_prefix_num:                         ; NUMBER-PREFIX?
        ; ( c-addr -- n 0xFFFF | d.lo d.hi 2 | c-addr 0 )
        ; 3-shape return: single (flag=0xFFFF), double (flag=2), or
        ; fail (flag=0). DUP+QBRANCH preserves flag for .got_value
        ; dispatch. Double-shape has d.lo below d.hi (high cell on
        ; TOS per §3.1.4.1).
        DW      w_NUMBER_PREFIX_Q_cf
        DW      w_DUP_cf
        DW      w_QBRANCH_cf
        DW      .try_rn_drop - $
        DW      w_BRANCH_cf
        DW      .got_value - $
.try_rn_drop:
        DW      w_DROP_cf
.try_real_number:
        DW      w_NUMBER_Q_cf           ; ( c-addr -- n 0xFFFF | d.lo d.hi 2 | c-addr 0 )
        DW      w_DUP_cf
        DW      w_QBRANCH_cf
        DW      .not_number_drop - $
        DW      w_BRANCH_cf
        DW      .got_value - $
.not_number_drop:
        DW      w_DROP_cf               ; drop the duplicated false
        DW      w_BRANCH_cf
        DW      .not_number - $         ; jump to error path (not fall through to .got_value)
.got_value:
        ; Valid number — flag still on TOS. Single: flag = 0xFFFF (or 1);
        ; Double: flag = 2.
        DW      w_STATE_cf              ; ( ... flag -- ... flag state-addr )
        DW      w_FETCH_cf              ; ( ... flag state-addr -- ... flag state )
        DW      w_QBRANCH_cf            ; if STATE=0, drop flag, leave value(s)
        DW      .got_interp - $
        ; Compile state — dispatch on flag value (2 = double, else single)
        DW      w_DUP_cf                ; ( ... flag flag )
        DW      w_LIT_cf, 2
        DW      w_EQUALS_cf             ; ( ... flag eq2? )
        DW      w_QBRANCH_cf
        DW      .compile_single - $     ; flag != 2 → single
        ; flag == 2: emit (DLIT) + high + low. Stack: ( d.lo d.hi flag )
        ; per ANS Forth 1994 §3.1.4.1 (hi-on-TOS). BC walks d.hi then
        ; d.lo.
        ; Inline data layout: [w_D_LIT_cf addr][d.hi lo,hi][d.lo lo,hi]
        ; — high cell at lower address per §6.1.0350 (matches 2!).
        DW      w_DROP_cf               ; drop flag → ( d.lo d.hi )
        DW      w_LIT_cf, w_D_LIT_cf    ; ( d.lo d.hi (DLIT)-xt )
        DW      w_COMMA_cf              ; emit (DLIT) xt
        DW      w_COMMA_cf              ; emit d.hi (high cell at lower address)
        DW      w_COMMA_cf              ; emit d.lo
        DW      w_BRANCH_cf
        DW      .interp_loop - $
.compile_single:
        DW      w_DROP_cf               ; drop flag → ( n )
        DW      w_LIT_cf, w_LIT_cf      ; ( n LIT-xt )
        DW      w_COMMA_cf              ; emit LIT xt
        DW      w_COMMA_cf              ; emit n
        DW      w_BRANCH_cf
        DW      .interp_loop - $
.got_interp:
        ; Interpret state: drop flag, value(s) stay on stack.
        DW      w_DROP_cf
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
        DW      w_COMP_ERROR_cf         ; ( c-addr -- ) never returns (raises -13 THROW)
.interp_error:
        DW      w_COUNT_cf              ; ( c-addr -- addr len )
        DW      w_TYPE_cf               ; print the unknown word
        DW      w_LIT_cf, ' '
        DW      w_EMIT_cf               ; space
        DW      w_LIT_cf, '?'
        DW      w_EMIT_cf               ; question mark
        DW      w_CR_cf                 ; newline
        ; -13 THROW: undefined word per ANS Forth 1994 §9.3.5
        ; Forth-thread form: push the THROW code as a literal then call the
        ; user-mode w_THROW_cf entry (NOT w_THROW_cf.kernel_entry, which is
        ; not addressable from a Forth thread).
        DW      w_LIT_cf, THROW_UNDEFINED_WORD
        DW      w_THROW_cf
.interp_done:
        DW      w_DROP_cf               ; drop the empty c-addr
        DW      EXIT_CODE               ; return to caller (QUIT loop)

; -----------------------------------------------
; (QMARK-BANK) ( xt -- xt )            [headerless kernel-internal]
;   Pre-execute peek at the interpret loop's direct-execute path. Sets the
;   one-shot interp_bank_pending flag iff the token about to run IS an
;   interactive BANK! — xt == BANK! AND include_top == 0 (not inside an
;   INCLUDEd source frame; F6: an INCLUDEd file's BANK! must not pollute
;   saved_bank). Clears the flag otherwise. STATE is 0 by construction here
;   (the STATE QBRANCH upstream), so it is not re-tested. xt is left untouched
;   on the data stack for EXECUTE. See docs/antforth-banking-redesign.md §5.6.
; -----------------------------------------------
w_QMARK_BANK_cf:
        LD      (IY+UserArea.interp_bank_pending), 0   ; default: not an interactive BANK!
        LD      A, C                                   ; BC = xt (TOS); compare without disturbing it
        CP      LOW w_BANK_STORE_cf
        JR      NZ, .qmb_done
        LD      A, B
        CP      HIGH w_BANK_STORE_cf
        JR      NZ, .qmb_done                          ; not BANK! -> leave flag clear
        LD      A, (IY+UserArea.include_top)
        OR      (IY+UserArea.include_top+1)
        JR      NZ, .qmb_done                          ; inside INCLUDE -> do not save (F6)
        LD      (IY+UserArea.interp_bank_pending), 1   ; interactive BANK! about to run -> mark pending
.qmb_done:
        NEXT

; -----------------------------------------------
; (QSAVE-BANK) ( -- )                  [headerless kernel-internal]
;   Post-execute commit. If interp_bank_pending is set (the just-run token was
;   an interactive BANK! that did NOT throw — a throwing BANK! skips this word
;   on the unwind), snapshot current_bank -> saved_bank and clear the flag.
;   Touches neither stack. See docs/antforth-banking-redesign.md §5.6.
; -----------------------------------------------
w_QSAVE_BANK_cf:
        LD      A, (IY+UserArea.interp_bank_pending)
        OR      A
        JR      Z, .qsb_done                    ; not a pending interactive BANK! -> nothing to save
        LD      A, (IY+UserArea.current_bank)
        LD      (IY+UserArea.saved_bank), A     ; saved_bank.low <- current_bank.low
        XOR     A
        LD      (IY+UserArea.saved_bank+1), A   ; saved_bank.high <- 0 (current_bank.high invariant 0)
        LD      (IY+UserArea.interp_bank_pending), A   ; clear one-shot flag (A == 0 here)
.qsb_done:
        NEXT

; -----------------------------------------------
; (REASSERT-BANK) ( -- )               [headerless kernel-internal]
;   Run at the head of .quit_loop on every REPL re-entry. If the live bank
;   drifted from the saved interactive bank (an ABORT/THROW unwind, or a
;   colon word that switched bank), restore saved_bank as the live bank so
;   the user is never stranded. The saved_bank == current_bank guard makes
;   this a permanent no-op on the single-bank iz-cpm build (0 == 0 always),
;   keeping that path byte-for-byte unchanged. The .throw_uncaught "KNOWN
;   LIMIT" comment (src/exception.asm) names QUIT as this restorer.
;   Reuses the factored mbb_set_slot2 + bank_triple_swap helpers so the live
;   (HERE,LATEST,wordlist_head) triple stays coherent after the restore.
;   Preserves the data-stack TOS (BC). See docs/antforth-banking-redesign.md §5.6.
; -----------------------------------------------
w_REASSERT_BANK_cf:
        LD      A, (IY+UserArea.current_bank)
        LD      L, (IY+UserArea.saved_bank)     ; L = saved bank (keep BC=TOS intact)
        CP      L
        JR      Z, .rab_done                    ; saved == current -> no-op (entire iz-cpm case)
        PUSH    BC                              ; preserve data-stack TOS across the switch
        LD      C, L
        LD      B, 0
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC                          ; HL = &active_pages[saved]
        LD      A, (HL)                         ; A = physical page
        CALL    mbb_set_slot2                   ; map slot 2; preserves BC, DE
        LD      A, (IY+UserArea.current_bank)   ; A = old bank (save-target)
        LD      (IY+UserArea.current_bank), C   ; current_bank <- saved
        LD      (IY+UserArea.triple_owner), C
        PUSH    DE                              ; bank_triple_swap clobbers DE (IP)
        CALL    bank_triple_swap                ; A = old, C = new
        POP     DE
        POP     BC                              ; restore data-stack TOS
.rab_done:
        NEXT

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
        ; CATCH-TOP = 0 (no enclosing exception frame after ABORT/QUIT recovery —
        ; chain-link invariant)
        LD      (IY+UserArea.catch_top), A
        LD      (IY+UserArea.catch_top+1), A
        ; Enter the QUIT loop thread
        LD      DE, .quit_loop
        NEXT

.quit_loop:
        ; Re-assert the saved interactive bank on every REPL re-entry (no-op
        ; when saved_bank == current_bank — the common case and the entire
        ; iz-cpm case). Restores the user's bank after an ABORT/THROW unwind.
        DW      w_REASSERT_BANK_cf
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

; -----------------------------------------------
; (SAVE-INPUT) ( c-addr u -- )
;   Internal helper. Save current (tib_addr, tib_len, tib_in,
;   source_id) to the return stack (8 bytes), then install the new
;   source: tib_addr=c-addr, tib_len=u, tib_in=0, source_id=-1.
;
;   R-stack push order (top of stack last): source_id, tib_in,
;   tib_len, tib_addr — so (RESTORE-INPUT) pops tib_addr first, then
;   tib_len, tib_in, source_id (LIFO inverse).
;
;   On the parameter stack, c-addr is at [SP] and u is in BC at entry.
;   After the routine: BC = old second-on-stack (new TOS).
;
;   INVARIANT: every call to (SAVE-INPUT) MUST be matched by exactly one
;   (RESTORE-INPUT) on the same control path. A direct user-level call
;   without a matching restore corrupts the input source on the next
;   parse. EVALUATE owns the only sanctioned pairing; INCLUDE owns the
;   second. The (paren) naming warns of internal-helper status —
;   convention only, NOT enforced by SMUDGE/F_HIDDEN. Treat as private.
;
;   THROW-survival: EVALUATE wraps INTERPRET in CATCH so (RESTORE-INPUT)
;   runs on both the success and the THROW paths. QUERY also defensively
;   re-asserts tib_addr = tib_buffer and source_id = 0. Combined defence
;   closes the -58 caught form via EVALUATE harness.
; -----------------------------------------------
w_PAREN_SAVE_INPUT:
        DEFCODE "(SAVE-INPUT)", 0
w_PAREN_SAVE_INPUT_cf:
        CALL    check_underflow_2       ; needs c-addr u (2 cells)
        ; Save the four current source-spec cells to the R-stack.
        ; Push order (deepest first): source_id, tib_in, tib_len, tib_addr.
        LD      L, (IY+UserArea.source_id)
        LD      H, (IY+UserArea.source_id+1)
        CALL    rpush_hl
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        CALL    rpush_hl
        LD      L, (IY+UserArea.tib_len)
        LD      H, (IY+UserArea.tib_len+1)
        CALL    rpush_hl
        LD      L, (IY+UserArea.tib_addr)
        LD      H, (IY+UserArea.tib_addr+1)
        CALL    rpush_hl

        ; Install new source spec.
        POP     HL                      ; HL = c-addr (was second-on-stack)
        LD      (IY+UserArea.tib_addr), L
        LD      (IY+UserArea.tib_addr+1), H
        ; tib_len = u (still in BC)
        LD      (IY+UserArea.tib_len), C
        LD      (IY+UserArea.tib_len+1), B
        ; tib_in = 0
        XOR     A
        LD      (IY+UserArea.tib_in), A
        LD      (IY+UserArea.tib_in+1), A
        ; source_id = -1 ($FFFF) per Forth 2014 §6.2.2218
        DEC     A                       ; A = $FF
        LD      (IY+UserArea.source_id), A
        LD      (IY+UserArea.source_id+1), A
        ; Pop new TOS from below the consumed (c-addr, u) pair.
        POP     BC
        NEXT

; -----------------------------------------------
; (RESTORE-INPUT) ( -- )
;   Internal helper. Pop the four-cell source-spec frame saved by
;   (SAVE-INPUT) and write it back into the USER area.
;   Pop order (top first): tib_addr, tib_len, tib_in, source_id.
;   Stack-neutral: parameter stack is untouched.
;
;   INVARIANT: must only run when a matching (SAVE-INPUT) frame is on
;   the return stack. Calling this directly (no prior SAVE) pops 4
;   garbage R-stack cells into the USER source-spec fields, corrupting
;   the next parse. Treat as private — see (SAVE-INPUT) for rationale.
; -----------------------------------------------
w_PAREN_RESTORE_INPUT:
        DEFCODE "(RESTORE-INPUT)", 0
w_PAREN_RESTORE_INPUT_cf:
        CALL    rpop_hl
        LD      (IY+UserArea.tib_addr), L
        LD      (IY+UserArea.tib_addr+1), H
        CALL    rpop_hl
        LD      (IY+UserArea.tib_len), L
        LD      (IY+UserArea.tib_len+1), H
        CALL    rpop_hl
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        CALL    rpop_hl
        LD      (IY+UserArea.source_id), L
        LD      (IY+UserArea.source_id+1), H
        NEXT

; -----------------------------------------------
; SAVE-INPUT ( -- xn ... x1 n )                  ANS Forth 1994 §6.2.2182
;   User-facing CORE-EXT word.
;   Pushes a description of the current input source spec for later
;   use by RESTORE-INPUT. antforth's pick (a) uniform-quadruple shape:
;   five cells total with count = 4 on top, regardless of SOURCE-ID.
;
;   Stack effect (pick a): ( -- tib_addr tib_len >IN SOURCE-ID 4 )
;
;   Primary scope: the EVALUATE arm of §6.2.2182 / §6.2.2148 — within
;   an EVALUATEd string, save → mutate-`>IN` → restore round-trips
;   cleanly because the EVALUATEd string buffer doesn't rotate during
;   INTERPRET (it's the c-addr / u the user passed; it lives until
;   EVALUATE returns). Keyboard (SOURCE-ID = 0) and INCLUDE-FILE
;   (SOURCE-ID > 0) arms work structurally with the cross-REFILL
;   impl-defined deviation noted on RESTORE-INPUT.
;
;   Relationship to private `(SAVE-INPUT)`: different
;   surfaces. The (paren) helper is EVALUATE's R-stack plumbing
;   (install-and-uninstall semantics; reads c-addr / u from the data
;   stack and writes them into UserArea, setting source_id = -1 and
;   tib_in = 0). The user-facing SAVE-INPUT is snapshot-only: it
;   does NOT modify UserArea — it pushes a copy of the current spec
;   onto the data stack. The two co-exist; the (paren) helper is
;   not modified.
; -----------------------------------------------
w_SAVE_INPUT:
        DEFCODE "SAVE-INPUT", 0
w_SAVE_INPUT_cf:
        ; -3 THROW guard. One CALL covers PUSH BC + 4
        ; cells (10 bytes); 32-byte margin shrinks to ~22 — same
        ; envelope discipline as w_GET_ORDER_cf (`wordlists.asm`).
        CALL    check_overflow
        PUSH    BC                      ; spill old TOS to memory; new TOS (= count) loaded last
        LD      L, (IY+UserArea.tib_addr)       ; first pushed = x4 = deepest description cell
        LD      H, (IY+UserArea.tib_addr+1)
        PUSH    HL
        LD      L, (IY+UserArea.tib_len)
        LD      H, (IY+UserArea.tib_len+1)
        PUSH    HL
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        PUSH    HL
        LD      L, (IY+UserArea.source_id)
        LD      H, (IY+UserArea.source_id+1)
        PUSH    HL
        LD      BC, 4                   ; new TOS = count
        NEXT

; -----------------------------------------------
; RESTORE-INPUT ( xn ... x1 n -- flag )          ANS Forth 1994 §6.2.2148
;   User-facing CORE-EXT word.
;   Attempt to restore the input source spec to the state described
;   by x1..xn. flag is true (-1) if the spec cannot be restored, else
;   false (0). Per §6.2.2148: "An ambiguous condition exists if the
;   input source represented by the arguments is not the same as
;   the current input source."
;
;   Stack effect (pick a): ( tib_addr tib_len >IN SOURCE-ID 4 -- flag )
;
;   Flag semantics:
;     flag = 0   — restored cleanly (count == 4 AND saved SOURCE-ID
;                  matches current SOURCE-ID); the four UserArea
;                  source-spec cells are written back atomically.
;     flag = -1  — count != 4 (count_mismatch path; impl-defined:
;                  the bogus cells remain on the stack — §6.2.2148
;                  ambiguous condition) OR saved SOURCE-ID does
;                  not match current SOURCE-ID (src_mismatch path;
;                  the remaining 3 description cells are dropped
;                  and UserArea is NOT mutated).
;
;   IMPL-DEFINED DEVIATION (cross-REFILL keyboard / INCLUDE-FILE):
;     antforth's SOURCE-ID-match check is necessary but not
;     sufficient for cross-REFILL correctness. If a user calls
;     SAVE-INPUT during keyboard input, then REFILL rotates the TIB
;     content, then RESTORE-INPUT, the SOURCE-ID still matches
;     (0 = 0) but the bytes at tib_addr have changed since the
;     SAVE-INPUT call. Same shape for INCLUDE-FILE across a record
;     refill. Within a single EVALUATE call (the binding scope)
;     no rotation occurs, so the round-trip is clean.
;
;   Relationship to private `(RESTORE-INPUT)`: different
;   surfaces. The (paren) helper pops the four-cell frame saved by
;   `(SAVE-INPUT)` from the R-stack; this user-facing word pops the
;   five-cell description from the data stack and validates it
;   before writing back. (paren) helper is unmodified.
; -----------------------------------------------
w_RESTORE_INPUT:
        DEFCODE "RESTORE-INPUT", 0
w_RESTORE_INPUT_cf:
        ; BC = n (count cell, TOS). Compare to 4.
        LD      HL, 4
        OR      A                       ; clear CY
        SBC     HL, BC                  ; HL = 4 - BC; Z iff BC = 4
        JR      NZ, .ri_count_mismatch
        ; count == 4 — verify 4 description cells available.
        CALL    check_underflow_4
        ; Pop x1 = saved SOURCE-ID; validate against current.
        POP     HL
        LD      A, (IY+UserArea.source_id)
        CP      L
        JR      NZ, .ri_src_mismatch
        LD      A, (IY+UserArea.source_id+1)
        CP      H
        JR      NZ, .ri_src_mismatch
        ; SOURCE-ID matches current; UA.source_id is already correct,
        ; so skip the redundant write-back and commit the rest.
        POP     HL                      ; x2 = saved >IN
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     HL                      ; x3 = saved tib_len
        LD      (IY+UserArea.tib_len), L
        LD      (IY+UserArea.tib_len+1), H
        POP     HL                      ; x4 = saved tib_addr
        LD      (IY+UserArea.tib_addr), L
        LD      (IY+UserArea.tib_addr+1), H
        LD      BC, 0                   ; flag = 0 (restored)
        JR      .ri_done
.ri_src_mismatch:
        ; SOURCE-ID mismatch; drop the remaining 3 description cells,
        ; then fall through to .ri_count_mismatch's flag-load + NEXT.
        POP     HL
        POP     HL
        POP     HL
.ri_count_mismatch:
        ; Reached directly on count != 4 (bogus cells stay on stack —
        ; §6.2.2148 ambiguous condition; impl-defined) or via fall-
        ; through from .ri_src_mismatch (3 cells already dropped).
        LD      BC, $FFFF               ; flag = -1 (cannot restore)
.ri_done:
        NEXT

; -----------------------------------------------
; EVALUATE ( i*x c-addr u -- j*x )
;   Save the current input source spec, install c-addr/u as the
;   active input source with source_id = -1, run INTERPRET, then
;   restore the saved source spec.
;
;   THROW-safety: INTERPRET runs inside an internal CATCH so
;   (RESTORE-INPUT) ALWAYS runs — on the success path AND on the
;   THROW path. The wrapping pattern is:
;       (SAVE-INPUT) ['] INTERPRET CATCH (RESTORE-INPUT) THROW EXIT
;   On success, CATCH leaves 0 → THROW is silent (Forth 2014
;   §9.6.1.2275: "If any bits of n are non-zero, ...") → EXIT. On a
;   THROW from inside INTERPRET, CATCH re-emerges with n on TOS,
;   (RESTORE-INPUT) runs (data-stack-neutral), then THROW re-raises n
;   to the caller's wrapping CATCH. This closes the -58 caught form
;   via EVALUATE harness.
;
; ANS Forth 1994 §6.1.1360   EVALUATE   — interpret from string
; -----------------------------------------------
w_EVALUATE:
        DEFWORD "EVALUATE", 0
w_EVALUATE_body:
w_EVALUATE_cf EQU w_EVALUATE_body - 3
        DW      w_PAREN_SAVE_INPUT_cf       ; ( c-addr u -- ) install eval source
        DW      w_LIT_cf, w_INTERPRET_cf    ; ( -- xt-of-INTERPRET )
        DW      w_CATCH_cf                  ; ( xt -- 0 | n )
        DW      w_PAREN_RESTORE_INPUT_cf    ; restore source-spec on both paths
        DW      w_THROW_cf                  ; THROW 0 silent; non-zero re-raises
        DW      EXIT_CODE                   ; reached on success path only
