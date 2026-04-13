; control_flow.asm — Compile-only guard + conditional/loop control flow words
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; ?COMP ( -- )
;   Compile-only guard: if STATE=0 (interpreting), print error and ABORT
; -----------------------------------------------
w_QCOMP:
        DEFCODE "?COMP", 0
w_QCOMP_cf:
        LD      A, (IY+UserArea.state)
        OR      (IY+UserArea.state+1)
        JR      NZ, .qcomp_ok
        ; Print "? compile only" CR LF
        ; Raw BDOS calls (no BDOS_SAVE/BDOS_RESTORE) — registers are
        ; irrelevant since we JP to ABORT immediately after printing.
        LD      HL, .comp_only_msg
        LD      B, .comp_only_len
        CALL    bdos_print_str
        JP      w_ABORT_cf
.comp_only_msg:
        DB      "? compile only", 0x0D, 0x0A
.comp_only_len  EQU     $ - .comp_only_msg
.qcomp_ok:
        NEXT

; -----------------------------------------------
; IF ( -- fwd-ref )  IMMEDIATE, compile-only
;   Compile ?BRANCH + placeholder for forward offset
; -----------------------------------------------
w_IF:
        DEFIMMED "IF"
w_IF_body:
w_IF_cf EQU w_IF_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        DW w_LIT_cf, w_QBRANCH_cf   ; push ?BRANCH xt
        DW w_COMMA_cf                ; compile ?BRANCH at HERE
        DW w_HERE_cf                 ; push HERE (fwd-ref = offset cell addr)
        DW w_LIT_cf, 0
        DW w_COMMA_cf                ; compile placeholder 0
        DW EXIT_CODE

; -----------------------------------------------
; THEN ( fwd-ref -- )  IMMEDIATE, compile-only
;   Resolve forward reference: store offset = HERE - fwd-ref
; -----------------------------------------------
w_THEN:
        DEFIMMED "THEN"
w_THEN_body:
w_THEN_cf EQU w_THEN_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( fwd-ref -- )
        DW w_HERE_cf                 ; ( fwd-ref here )
        DW w_OVER_cf                 ; ( fwd-ref here fwd-ref )
        DW w_MINUS_cf                ; ( fwd-ref here-fwd-ref ) = offset
        DW w_SWAP_cf                 ; ( offset fwd-ref )
        DW w_STORE_cf                ; store offset at fwd-ref
        DW EXIT_CODE

; -----------------------------------------------
; ELSE ( if-fwd -- else-fwd )  IMMEDIATE, compile-only
;   Compile unconditional BRANCH + placeholder, then resolve IF's fwd-ref
; -----------------------------------------------
w_ELSE:
        DEFIMMED "ELSE"
w_ELSE_body:
w_ELSE_cf EQU w_ELSE_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( if-fwd -- else-fwd )
        DW w_LIT_cf, w_BRANCH_cf    ; push BRANCH xt
        DW w_COMMA_cf                ; compile BRANCH at HERE
        DW w_HERE_cf                 ; push HERE (else-fwd for THEN)
        DW w_LIT_cf, 0
        DW w_COMMA_cf                ; compile placeholder 0
        DW w_SWAP_cf                 ; ( else-fwd if-fwd )
        ; Resolve IF's forward reference
        DW w_HERE_cf                 ; ( else-fwd if-fwd here )
        DW w_OVER_cf                 ; ( else-fwd if-fwd here if-fwd )
        DW w_MINUS_cf                ; ( else-fwd if-fwd offset )
        DW w_SWAP_cf                 ; ( else-fwd offset if-fwd )
        DW w_STORE_cf                ; store offset at if-fwd; ( else-fwd )
        DW EXIT_CODE

; -----------------------------------------------
; BEGIN ( -- begin-addr )  IMMEDIATE, compile-only
;   Push HERE as backward target
; -----------------------------------------------
w_BEGIN:
        DEFIMMED "BEGIN"
w_BEGIN_body:
w_BEGIN_cf EQU w_BEGIN_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        DW w_HERE_cf                 ; push HERE (backward target)
        DW EXIT_CODE

; -----------------------------------------------
; UNTIL ( begin-addr -- )  IMMEDIATE, compile-only
;   Compile ?BRANCH with backward offset to begin-addr
; -----------------------------------------------
w_UNTIL:
        DEFIMMED "UNTIL"
w_UNTIL_body:
w_UNTIL_cf EQU w_UNTIL_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( begin-addr -- )
        DW w_LIT_cf, w_QBRANCH_cf
        DW w_COMMA_cf                ; compile ?BRANCH
        DW w_HERE_cf                 ; ( begin-addr here ) here = offset cell addr
        DW w_MINUS_cf                ; ( begin-addr - here ) negative backward offset
        DW w_COMMA_cf                ; compile offset
        DW EXIT_CODE

; -----------------------------------------------
; WHILE ( begin-addr -- while-fwd begin-addr )  IMMEDIATE, compile-only
;   Compile ?BRANCH + placeholder, SWAP so begin-addr is on top for REPEAT
; -----------------------------------------------
w_WHILE:
        DEFIMMED "WHILE"
w_WHILE_body:
w_WHILE_cf EQU w_WHILE_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( begin-addr -- while-fwd begin-addr )
        DW w_LIT_cf, w_QBRANCH_cf
        DW w_COMMA_cf                ; compile ?BRANCH
        DW w_HERE_cf                 ; ( begin-addr while-fwd )
        DW w_LIT_cf, 0
        DW w_COMMA_cf                ; compile placeholder 0
        DW w_SWAP_cf                 ; ( while-fwd begin-addr )
        DW EXIT_CODE

; -----------------------------------------------
; REPEAT ( while-fwd begin-addr -- )  IMMEDIATE, compile-only
;   Compile BRANCH back to begin-addr, then resolve WHILE's fwd-ref
; -----------------------------------------------
w_REPEAT:
        DEFIMMED "REPEAT"
w_REPEAT_body:
w_REPEAT_cf EQU w_REPEAT_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( while-fwd begin-addr -- )
        ; Compile BRANCH back to begin-addr
        DW w_LIT_cf, w_BRANCH_cf
        DW w_COMMA_cf                ; compile BRANCH
        DW w_HERE_cf                 ; ( while-fwd begin-addr here )
        DW w_MINUS_cf                ; ( while-fwd begin-addr-here ) backward offset
        DW w_COMMA_cf                ; compile backward offset; ( while-fwd )
        ; Resolve WHILE's forward reference
        DW w_HERE_cf                 ; ( while-fwd here )
        DW w_OVER_cf                 ; ( while-fwd here while-fwd )
        DW w_MINUS_cf                ; ( while-fwd here-while-fwd )
        DW w_SWAP_cf                 ; ( offset while-fwd )
        DW w_STORE_cf                ; store offset at while-fwd; ( )
        DW EXIT_CODE

; Runtime return-stack frame layout after (DO):
;   (IX+0,1) = index (low,high)
;   (IX+2,3) = limit (low,high)
;
; Compile-time data stack convention:
;   DO      ( -- do-addr old-lc )
;   LOOP    ( do-addr old-lc -- )
;   +LOOP   ( do-addr old-lc -- )
;
; The LEAVE chain head is stored in a dedicated cell
; (leave_chain_head), NOT on the compile-time data stack.
; This keeps LEAVE working even when nested inside IF/THEN,
; because intervening IF/ELSE/WHILE fwd-refs pile on the
; data stack without disturbing the chain pointer.
;
; DO pushes the *previous* value of leave_chain_head onto the
; data stack as 'old-lc' and resets the global to 0 (new
; empty chain for the current DO...LOOP). LOOP walks the
; current chain, then restores old-lc from the data stack
; back into leave_chain_head — restoring the outer loop's
; chain for correct nesting.

; --- Internal helpers (no dictionary header) ---
; LC@  ( -- lc )    fetch leave_chain_head
w_LCFETCH_cf:
        PUSH    BC
        LD      BC, (leave_chain_head)
        NEXT

; LC!  ( lc -- )    store leave_chain_head
w_LCSTORE_cf:
        LD      (leave_chain_head), BC
        POP     BC
        NEXT

leave_chain_head: DW 0

; -----------------------------------------------
; (DO) ( limit start -- ) ( R: -- limit index )
;   Runtime primitive — push limit then index on return stack
; -----------------------------------------------
w_PAREN_DO:
        DEFCODE "(DO)", 0
w_PAREN_DO_cf:
        ; BC = start (TOS), SP -> [limit, ...]
        POP     HL                   ; HL = limit
        ; Push limit to return stack (at IX+2,3 after index push)
        DEC     IX
        DEC     IX
        LD      (IX+0), L
        LD      (IX+1), H
        ; Push index (start) to return stack (at IX+0,1)
        CALL    rpush_bc
        POP     BC                   ; New TOS
        NEXT

; -----------------------------------------------
; (LOOP) ( -- ) ( R: limit index -- limit index' | )
;   Runtime primitive — increment index, exit on equal-limit.
;   Inline backward offset follows in the thread.
; -----------------------------------------------
w_PAREN_LOOP:
        DEFCODE "(LOOP)", 0
w_PAREN_LOOP_cf:
        ; Increment index at (IX+0,1)
        INC     (IX+0)
        JR      NZ, .loop_check
        INC     (IX+1)
.loop_check:
        ; Compare index (IX+0,1) with limit (IX+2,3)
        LD      A, (IX+0)
        CP      (IX+2)
        JR      NZ, .loop_take
        LD      A, (IX+1)
        CP      (IX+3)
        JR      NZ, .loop_take
        ; index == limit → exit loop
        ; Drop index+limit (4 bytes) from return stack
        INC     IX
        INC     IX
        INC     IX
        INC     IX
        ; Skip the inline offset cell: advance IP past it
        INC     DE
        INC     DE
        NEXT
.loop_take:
        ; Take the backward branch (same as BRANCH)
        EX      DE, HL               ; HL = IP (points to offset cell)
        LD      E, (HL)
        INC     HL
        LD      D, (HL)               ; DE = offset
        DEC     HL                   ; HL = offset_cell_addr
        ADD     HL, DE               ; HL = new IP
        NEXTHL

; -----------------------------------------------
; (+LOOP) ( n -- ) ( R: limit index -- limit index' | )
;   Runtime primitive — add n to index, exit on boundary crossing.
;   Inline backward offset follows in the thread.
; -----------------------------------------------
w_PAREN_PLUS_LOOP:
        DEFCODE "(+LOOP)", 0
w_PAREN_PLUS_LOOP_cf:
        ; Save IP (DE) to a scratch cell since we will clobber DE.
        LD      (ploop_saved_ip), DE
        ; HL = old_index
        LD      L, (IX+0)
        LD      H, (IX+1)
        ; DE = limit
        LD      E, (IX+2)
        LD      D, (IX+3)
        ; Compute diff_old = old_index - limit; save high byte
        OR      A                    ; clear carry
        SBC     HL, DE               ; HL = old - limit
        LD      A, H                 ; A = high byte of diff_old
        LD      (ploop_diff_old_hi), A
        ; Recompute new_index = old_index + step (BC)
        LD      L, (IX+0)
        LD      H, (IX+1)
        ADD     HL, BC               ; HL = new_index
        ; Store new_index back into return stack slot
        LD      (IX+0), L
        LD      (IX+1), H
        ; Compute diff_new = new_index - limit
        OR      A                    ; clear carry
        SBC     HL, DE               ; HL = new - limit
        ; Crossing test: (diff_old XOR diff_new) bit 15
        LD      A, (ploop_diff_old_hi)
        XOR     H                    ; A = (diff_old XOR diff_new) high byte
        ; Pop new TOS (step is consumed)
        POP     BC
        ; Restore IP (DE)
        LD      DE, (ploop_saved_ip)
        BIT     7, A
        JR      NZ, .ploop_exit
        ; Continue: take backward branch (same as BRANCH)
        EX      DE, HL               ; HL = IP (points to offset cell)
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        DEC     HL
        ADD     HL, DE               ; HL = new IP
        NEXTHL
.ploop_exit:
        ; Drop index+limit (4 bytes) from return stack
        INC     IX
        INC     IX
        INC     IX
        INC     IX
        ; Skip the inline offset cell
        INC     DE
        INC     DE
        NEXT

ploop_saved_ip:    DW 0
ploop_diff_old_hi: DB 0

; -----------------------------------------------
; UNLOOP ( -- ) ( R: limit index -- )
;   Drop innermost DO-loop frame from return stack.
; -----------------------------------------------
w_UNLOOP:
        DEFCODE "UNLOOP", 0
w_UNLOOP_cf:
        INC     IX
        INC     IX
        INC     IX
        INC     IX
        NEXT

; -----------------------------------------------
; I ( -- index )
;   Push innermost DO-loop index.
; -----------------------------------------------
w_I:
        DEFCODE "I", 0
w_I_cf:
        PUSH    BC                   ; save old TOS
        LD      C, (IX+0)
        LD      B, (IX+1)
        NEXT

; -----------------------------------------------
; J ( -- index )
;   Push next-outer DO-loop index (skip inner index+limit = 4 bytes).
; -----------------------------------------------
w_J:
        DEFCODE "J", 0
w_J_cf:
        PUSH    BC                   ; save old TOS
        LD      C, (IX+4)
        LD      B, (IX+5)
        NEXT

; -----------------------------------------------
; DO ( -- do-addr old-lc )  IMMEDIATE, compile-only
;   Compile (DO); save old leave chain head to data stack and
;   reset leave_chain_head to 0 for the new loop frame.
; -----------------------------------------------
w_DO:
        DEFIMMED "DO"
w_DO_body:
w_DO_cf EQU w_DO_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        DW w_LIT_cf, w_PAREN_DO_cf
        DW w_COMMA_cf                ; compile (DO) xt at HERE
        DW w_HERE_cf                 ; push HERE (do-addr = backward target)
        DW w_LCFETCH_cf              ; push old leave chain head
        DW w_LIT_cf, 0
        DW w_LCSTORE_cf              ; reset leave chain head to 0
        DW EXIT_CODE

; -----------------------------------------------
; LOOP ( do-addr old-lc -- )  IMMEDIATE, compile-only
;   Compile (LOOP) + backward offset, walk current LEAVE chain,
;   then restore outer old-lc as the leave_chain_head.
; -----------------------------------------------
w_LOOP:
        DEFIMMED "LOOP"
w_LOOP_body:
w_LOOP_cf EQU w_LOOP_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        ; ( do-addr old-lc -- )
        DW w_SWAP_cf                 ; ( old-lc do-addr )
        DW w_LIT_cf, w_PAREN_LOOP_cf
        DW w_COMMA_cf                ; compile (LOOP) xt
        ; Backward offset = do-addr - HERE (HERE = offset cell addr)
        DW w_HERE_cf                 ; ( old-lc do-addr here )
        DW w_MINUS_cf                ; ( old-lc do-addr-here )
        DW w_COMMA_cf                ; compile backward offset; ( old-lc )
        ; Walk current LEAVE chain: ( old-lc ) -> push current chain
        DW w_LCFETCH_cf              ; ( old-lc chain )
.loop_walk_begin:
        DW w_DUP_cf
        DW w_QBRANCH_cf
        DW .loop_walk_end - $        ; forward to DROP
        DW w_DUP_cf
        DW w_FETCH_cf                ; ( old-lc cell next-link )
        DW w_SWAP_cf                 ; ( old-lc next-link cell )
        DW w_HERE_cf                 ; ( old-lc next-link cell here )
        DW w_OVER_cf                 ; ( old-lc next-link cell here cell )
        DW w_MINUS_cf                ; ( old-lc next-link cell offset )
        DW w_SWAP_cf                 ; ( old-lc next-link offset cell )
        DW w_STORE_cf                ; store offset at cell; ( old-lc next-link )
        DW w_BRANCH_cf
        DW .loop_walk_begin - $      ; back to begin
.loop_walk_end:
        DW w_DROP_cf                 ; drop the 0; ( old-lc )
        ; Restore outer leave_chain_head
        DW w_LCSTORE_cf              ; ( )
        DW EXIT_CODE

; -----------------------------------------------
; +LOOP ( do-addr old-lc -- )  IMMEDIATE, compile-only
;   Identical to LOOP but compiles (+LOOP) runtime.
; -----------------------------------------------
w_PLUS_LOOP:
        DEFIMMED "+LOOP"
w_PLUS_LOOP_body:
w_PLUS_LOOP_cf EQU w_PLUS_LOOP_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        DW w_SWAP_cf                 ; ( old-lc do-addr )
        DW w_LIT_cf, w_PAREN_PLUS_LOOP_cf
        DW w_COMMA_cf                ; compile (+LOOP) xt
        DW w_HERE_cf                 ; ( old-lc do-addr here )
        DW w_MINUS_cf                ; ( old-lc backward-offset )
        DW w_COMMA_cf                ; compile backward offset; ( old-lc )
        DW w_LCFETCH_cf              ; ( old-lc chain )
.ploop_walk_begin:
        DW w_DUP_cf
        DW w_QBRANCH_cf
        DW .ploop_walk_end - $
        DW w_DUP_cf
        DW w_FETCH_cf
        DW w_SWAP_cf
        DW w_HERE_cf
        DW w_OVER_cf
        DW w_MINUS_cf
        DW w_SWAP_cf
        DW w_STORE_cf
        DW w_BRANCH_cf
        DW .ploop_walk_begin - $
.ploop_walk_end:
        DW w_DROP_cf
        DW w_LCSTORE_cf              ; restore outer leave_chain_head
        DW EXIT_CODE

; -----------------------------------------------
; LEAVE ( -- )  IMMEDIATE, compile-only
;   Compile UNLOOP + BRANCH + placeholder linked into the
;   leave_chain_head global. Does NOT touch the compile-time
;   data stack, so it works correctly when nested inside
;   IF/ELSE/THEN or BEGIN/WHILE/REPEAT.
; -----------------------------------------------
w_LEAVE:
        DEFIMMED "LEAVE"
w_LEAVE_body:
w_LEAVE_cf EQU w_LEAVE_body - 3
        DW w_QCOMP_cf               ; compile-only guard
        DW w_LIT_cf, w_UNLOOP_cf
        DW w_COMMA_cf                ; compile UNLOOP
        DW w_LIT_cf, w_BRANCH_cf
        DW w_COMMA_cf                ; compile BRANCH
        ; HERE now = placeholder slot address (new chain head)
        DW w_HERE_cf                 ; ( here )
        DW w_LCFETCH_cf              ; ( here old-chain )
        DW w_COMMA_cf                ; compile old-chain as placeholder; ( here )
        DW w_LCSTORE_cf              ; set leave_chain_head = here; ( )
        DW EXIT_CODE

; -----------------------------------------------
; RECURSE  IMMEDIATE
;   Compile the CFA of the currently-defining word (read LATEST).
;   CODE word: reads LATEST/HERE/STATE via IY without disturbing DE=IP.
; -----------------------------------------------
w_RECURSE:
        DEFCODE "RECURSE", F_IMMEDIATE
w_RECURSE_cf:
        ; Compile-only guard: STATE == 0 → error via ?COMP.
        ; Note: w_QCOMP_cf re-checks STATE itself before printing the
        ; error and ABORTing. The check below is intentionally
        ; redundant — it lets RECURSE skip straight to NEXT in the
        ; common (compiling) case without touching ?COMP at all.
        ; If ?COMP is ever changed to assume STATE=0 on entry, this
        ; jump-target contract still holds because we only JP there
        ; when STATE is genuinely 0.
        LD      A, (IY+UserArea.state)
        OR      (IY+UserArea.state+1)
        JP      Z, w_QCOMP_cf
        ; HL = LATEST (dict entry start)
        LD      L, (IY+UserArea.latest)
        LD      H, (IY+UserArea.latest+1)
        ; Skip hash_link (2 bytes) → HL -> count_flags
        INC     HL
        INC     HL
        LD      A, (HL)              ; A = count_flags
        AND     F_LENMASK            ; A = name length
        INC     HL                   ; HL -> first name byte
        ; HL += A (name length) → HL = code-field address
        ADD     A, L
        LD      L, A
        JR      NC, .rec_no_carry
        INC     H
.rec_no_carry:
        ; Save cfa in a scratch cell, then compile it at HERE.
        LD      (recurse_scratch), HL
        ; HL = HERE
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      A, (recurse_scratch)
        LD      (HL), A
        INC     HL
        LD      A, (recurse_scratch+1)
        LD      (HL), A
        INC     HL
        ; Update HERE
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        NEXT

recurse_scratch: DW 0
