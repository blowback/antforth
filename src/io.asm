; io.asm — Console I/O primitives
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; EMIT ( char -- )
;   Output character to console via BDOS C_WRITE
;   NO YIELD — output never PAUSEs (see the yield checklist below and
;   AD-P6-6). A PAUSE here would let a concurrent task interleave its output
;   char-by-char inside a single EMIT, shredding both strings; output-side
;   yielding is rejected (validation F2). Do NOT add a PAUSE to any output word.
; -----------------------------------------------
w_EMIT:
        DEFCODE "EMIT", 0
w_EMIT_cf:
        LD      A, C            ; A = char (save from TOS before BDOS clobbers)
        BDOS_SAVE               ; PUSH DE, PUSH BC
        LD      E, A            ; E = char for BDOS
        CALL    bdos_putchar
        BDOS_RESTORE            ; POP BC, POP DE — restores IP and old TOS
        POP     BC              ; Pop new TOS (char consumed)
        NEXT

; -----------------------------------------------
; TYPE ( c-addr u -- )
;   Output u characters starting at c-addr
; -----------------------------------------------
w_TYPE:
        DEFCODE "TYPE", 0
w_TYPE_cf:
        ; BC = u (count, TOS), (SP) = c-addr
        POP     HL              ; HL = c-addr
        ; BC = count — if count is 0, skip entirely
        LD      A, B
        OR      C
        JR      Z, .type_done
        PUSH    DE              ; Save IP once outside loop
        ; Note: Manual register saves used instead of BDOS_SAVE/BDOS_RESTORE
        ; to avoid macro nesting issues — IP is saved once outside the loop,
        ; and HL/BC/DE are managed per-iteration with explicit PUSH/POP.
.type_loop:
        PUSH    HL              ; Save address
        PUSH    BC              ; Save count
        LD      A, (HL)         ; A = next char
        PUSH    DE              ; Save DE (BDOS clobbers all)
        LD      E, A
        CALL    bdos_putchar
        POP     DE              ; Restore DE
        POP     BC              ; Restore count
        POP     HL              ; Restore address
        INC     HL              ; Next character
        DEC     BC
        LD      A, B
        OR      C
        JR      NZ, .type_loop
        POP     DE              ; Restore IP
.type_done:
        POP     BC              ; New TOS
        NEXT

; -----------------------------------------------
; CR ( -- )
;   Output carriage return + line feed
; -----------------------------------------------
w_CR:
        DEFCODE "CR", 0
w_CR_cf:
        BDOS_SAVE
        CALL    bdos_crlf
        BDOS_RESTORE
        NEXT

; -----------------------------------------------
; SPACE ( -- )
;   Output a single space character
; -----------------------------------------------
w_SPACE:
        DEFCODE "SPACE", 0
w_SPACE_cf:
        BDOS_SAVE
        LD      E, 0x20         ; Space character
        CALL    bdos_putchar
        BDOS_RESTORE
        NEXT

; -----------------------------------------------
; SPACES ( n -- )
;   Output n space characters (n <= 0 is a no-op)
; -----------------------------------------------
w_SPACES:
        DEFCODE "SPACES", 0
w_SPACES_cf:
        ; BC = n (count)
        LD      A, B
        OR      A               ; Check if high byte is negative (bit 7 set)
        JP      M, .spaces_done ; n < 0, skip
        LD      A, B
        OR      C
        JR      Z, .spaces_done ; n == 0, skip
        PUSH    DE              ; Save IP
.spaces_loop:
        BDOS_SAVE               ; Saves DE (IP) and BC (count)
        LD      E, 0x20
        CALL    bdos_putchar
        BDOS_RESTORE            ; Restores BC (count) and DE (IP)
        DEC     BC
        LD      A, B
        OR      C
        JR      NZ, .spaces_loop
        POP     DE              ; Restore IP
.spaces_done:
        POP     BC              ; New TOS (n consumed)
        NEXT

; ===============================================================
; Yield-instrumentation checklist (Story 25.2 / AD-P6-6) — STANDING RULE
; ---------------------------------------------------------------
; Cooperative scheduling advances other tasks ONLY at a PAUSE (a NEXT
; boundary). A word that blocks the operator while waiting for input must
; therefore PAUSE inside its wait loop, or it starves the ring — the
; background task freezes for as long as the operator sits at the prompt.
;
;   Word    Blocking?              Yields?  Mechanism
;   ----    --------------------   -------  ------------------------------
;   KEY     yes (waits for a char)  YES     poll KEY? (fn 11); PAUSE while
;                                           empty; then (KEY) fn-1 read
;   KEY?    no (status query)       no      the non-blocking poll the
;                                           yielders call (returns at once)
;   (LINE)  yes (waits for a line)  YES     char loop over the yielding KEY;
;                                           backs ACCEPT and QUERY
;   ACCEPT  yes (waits for a line)  YES     = (LINE)
;   QUERY   yes (waits for a line)  YES     = (LINE) (outer_interpreter.asm)
;   EMIT    no (output)             no      F2: output never yields
;
; ANY NEW blocking INPUT primitive MUST be added here with a PAUSE in its
; wait loop. KEY? is the poll primitive the yielders call, NOT itself a
; yielder (a status query must return immediately). Output primitives
; (EMIT, TYPE, ...) never yield (F2).
;
; Keyboard break (Story 25.7): (EDIT) recognises Ctrl-\ (0x1C) in-band and sets
; break_pending (multitasker.asm); PAUSE is the single break-CONSUME point, so
; every input primitive that yields via PAUSE (KEY, and thus (LINE)/ACCEPT/QUERY,
; plus (DELAY)) inherits keyboard break automatically — no per-primitive wiring.
; ===============================================================

; -----------------------------------------------
; (KEY) ( -- char )                    [headerless kernel-internal]
;   Raw blocking console read via BDOS function 1. Called by the yielding KEY
;   thread ONLY once KEY? has confirmed a char is ready, so fn 1 returns
;   immediately (no block). fn 1 echoes the char (iz-cpm bdos_console::read).
;   B=0: chars zero-extend to a clean cell. Keep this primitive for the line
;   reader; the yield wrapper is w_KEY_cf below.
; -----------------------------------------------
w_PAREN_KEY_cf:
        PUSH    BC              ; Push old TOS to make room
        BDOS_SAVE
        LD      C, C_READ       ; BDOS function 1: console input
        CALL    BDOS_ENTRY      ; A = character read
        BDOS_RESTORE            ; Restores old BC and DE (POP doesn't touch A)
        LD      C, A            ; C = char (low byte of new TOS)
        LD      B, 0            ; B = 0 (char is 0-255)
        NEXT

; -----------------------------------------------
; KEY ( -- char )
;   Yielding console read. Never sits inside a blocking BDOS call while a char
;   is absent: poll the non-blocking KEY? (fn 11) and PAUSE while no char is
;   ready, so a background task runs between keystrokes (FR10/FR11); once a
;   char is ready, (KEY) reads it (fn 1, immediate). PAUSE goes inside the
;   loop, before re-testing (AD-P6-6). KEY is a DEFWORD thread so it can host
;   PAUSE as a thread cell — PAUSE ends in NEXT and cannot be CALLed from a
;   DEFCODE leaf (see multitasker.asm / project_multitasker_pause_register_contract).
;
;       : KEY  BEGIN KEY? 0= WHILE PAUSE REPEAT (KEY) ;
;
;   Single-task identity (FR5/NFR-P6-12): on a length-1 ring PAUSE walks to
;   self (no-op), so KEY busy-polls fn 11 then reads — result-identical to the
;   old blocking KEY (same char, same B=0), only the execution shape differs.
; -----------------------------------------------
w_KEY:
        DEFWORD "KEY", 0
w_KEY_body:
w_KEY_cf  EQU   w_KEY_body - 3          ; code field = JP DOCOL, 3 bytes before body
.key_loop:
        DW      w_KEYQ_cf               ; ( -- flag )    fn-11 status poll
        DW      w_ZERO_EQUALS_cf        ; ( flag -- no-char? )  true when empty
        DW      w_QBRANCH_cf            ; char ready (false) -> exit loop, read it
        DW      .key_read - $
        DW      w_PAUSE_cf              ; no char yet -> yield to the ring
        DW      w_BRANCH_cf
        DW      .key_loop - $
.key_read:
        DW      w_PAREN_KEY_cf          ; ( -- char )    raw fn-1 read (immediate)
        DW      EXIT_CODE

; -----------------------------------------------
; KEY? ( -- flag )
;   Non-blocking console status via BDOS function 11.
;   NO YIELD — a status query must return immediately. KEY? is the poll
;   primitive the yielders (KEY, the line reader) call; it has no wait loop,
;   so a PAUSE here would be wrong (see the yield checklist above).
; -----------------------------------------------
w_KEYQ:
        DEFCODE "KEY?", 0
w_KEYQ_cf:
        PUSH    BC              ; Push old TOS to make room
        BDOS_SAVE
        LD      C, C_STATUS     ; BDOS function 11: console status
        CALL    BDOS_ENTRY      ; A = 0x00 (no char) or 0xFF (char ready)
        BDOS_RESTORE            ; POP doesn't touch A — result preserved
        ; Convert BDOS result to Forth flag: 0 → 0, 0xFF → -1 (0xFFFF)
        OR      A
        JR      Z, .keyq_false
        LD      BC, 0xFFFF      ; TRUE (-1)
        NEXT
.keyq_false:
        LD      BC, 0           ; FALSE (0)
        NEXT

; -----------------------------------------------
; (EDIT) ( c-addr max pos char -- c-addr max pos' done )   [headerless]
;   Process one keystroke for the line reader (LINE). The running line state
;   (buffer base c-addr, capacity max, count-so-far pos) rides the data stack
;   across each yielding KEY, so it is per-task (saved by PAUSE) and re-entrant.
;     CR (0x0D) : terminator. fn-1 echoed only the CR, so emit LF; done := -1.
;     LF (0x0A) : terminator (the stray LF that trails a piped CRLF, matching
;                 the old fn-10 reader which also broke on CR-or-LF). fn-1
;                 already echoed the LF, so DON'T emit again; done := -1.
;     BS (0x08) / DEL (0x7F) : destructive backspace. If pos>0, pos-- and erase
;                 the deleted column. fn-1 has already auto-echoed the keystroke,
;                 so the erase compensates for it: CTRL-H already stepped the
;                 cursor left (emit SPACE BS), DEL did not (emit BS SPACE BS).
;                 If pos==0, no-op.
;     ^C (0x03) : at the start of a line (pos==0) exit to CP/M, restoring the
;                 fn-10 reader's warm-boot-on-^C that the fn-1 read path drops
;                 (routed through BYE so the tick slot is released). Mid-line,
;                 ^C is an ordinary character (fn-10 stored it the same way).
;     else      : printable. Store at c-addr+pos and pos++ IF pos<max (else
;                 ignore — buffer full). fn-1 already echoed the char.
;   No underflow check — internal, called only by (LINE) with a known stack.
;   Preserves DE(IP), IX, IY. Uses A + the shadow set (EXX) for the 3-arg
;   printable case so DE(IP) is never disturbed (cf. ACCEPT's old EXX pattern).
; -----------------------------------------------
w_EDIT_cf:
        LD      A, C            ; A = char (B is 0 from KEY)
        CP      0x0D            ; CR?
        JR      Z, .edit_cr
        CP      0x0A            ; LF?
        JR      Z, .edit_lf
        CP      0x08            ; BS?
        JR      Z, .edit_bs
        CP      0x7F            ; DEL?
        JR      Z, .edit_bs
        CP      0x03            ; ^C (ETX)?
        JR      Z, .edit_etx
        CP      0x1C            ; Ctrl-\ (FS) — keyboard break?
        JR      Z, .edit_break
        ; --- printable: store into the caller's buffer, mirroring BDOS fn-10's
        ;     "stop at max, leave the rest in the stream" semantics (iz-cpm
        ;     read_string: `if size >= max_size break`). This is NOT a
        ;     drop-the-overflow: an over-long line must SPILL into the next read
        ;     (a >128-char CODE definition keeps its tail across the TIB break),
        ;     so we terminate the line the instant the buffer fills and leave
        ;     the unread chars in the stream. Needs pos+max+c-addr at once, so
        ;     work in the shadow set to keep DE(IP) parked.
.edit_printable:
        EXX                     ; shadow set: HL'/DE'/BC' scratch; real DE(IP) parked
        POP     HL              ; HL = pos           (stack: max, c-addr, ...)
        POP     DE              ; DE = max
        POP     BC              ; BC = c-addr
        PUSH    HL              ; save pos for the room test
        OR      A               ; clear carry (A = char; A's flags don't matter)
        SBC     HL, DE          ; pos - max ; carry iff pos < max (room to store)
        POP     HL              ; restore pos (POP preserves flags)
        JR      NC, .edit_full  ; no room (degenerate max==0) -> terminate, no store
        PUSH    HL              ; save pos
        ADD     HL, BC          ; HL = c-addr + pos = store address
        LD      (HL), A         ; store the char (fn-1 already echoed it)
        POP     HL              ; restore pos
        INC     HL              ; pos++
        PUSH    HL              ; save pos' for the "just filled?" test
        OR      A
        SBC     HL, DE          ; pos' - max ; carry iff pos' < max (still room)
        POP     HL              ; restore pos'
        PUSH    BC              ; re-push args: c-addr (deepest)
        PUSH    DE              ; max
        PUSH    HL              ; pos' (top)
        EXX                     ; restore real BC/DE(IP)/HL (carry preserved)
        JR      C, .edit_more   ; still room -> keep reading this line
        JR      .edit_term_lf   ; buffer just filled -> LF + terminate (rest spills)
.edit_more:
        LD      BC, 0           ; done = false -> read more
        NEXT
.edit_full:
        ; pos >= max with nothing stored (max == 0 degenerate): terminate.
        PUSH    BC
        PUSH    DE
        PUSH    HL
        EXX
        ; fall through to .edit_term_lf
.edit_term_lf:
        ; Terminate the line AND emit a trailing LF. The old fn-10 QUERY/ACCEPT
        ; emitted one LF after every read regardless of why it stopped (CR,
        ; LF, or buffer-full); match that so a >TIB-length line's echo lands on
        ; its own line and the next read (the spilled tail) starts fresh.
        ; DE = IP is valid here (CR path never EXX'd; the full paths EXX'd back).
        PUSH    DE              ; save IP (BDOS clobbers all)
        LD      E, 0x0A
        CALL    bdos_putchar
        POP     DE              ; restore IP
        LD      BC, 0xFFFF      ; done = true
        NEXT
.edit_cr:
        ; fn-1 echoed only the CR (col 0, no advance) — add the LF + terminate.
        JR      .edit_term_lf
.edit_lf:
        ; Terminator: fn-1 ALREADY echoed this LF (the stray \n trailing a piped
        ; CRLF, matching old fn-10 breaking on CR-or-LF), so do NOT emit another.
        ; Stack still holds ( c-addr max pos ) untouched; done := -1.
        LD      BC, 0xFFFF
        NEXT
.edit_bs:
        ; fn-1 has already auto-echoed the keystroke: CTRL-H (0x08) stepped the
        ; cursor left one cell; DEL (0x7F, rubout) printed a glyph without moving
        ; it. Stash the char (B is free — BC is reloaded before NEXT) so the
        ; pos test can reuse A, then erase the deleted column accordingly.
        LD      B, A            ; B = triggering keystroke (0x08 or 0x7F)
        POP     HL              ; HL = pos           (stack: max, c-addr, ...)
        LD      A, H
        OR      L
        JR      Z, .edit_bs_done        ; pos == 0 -> nothing to erase
        DEC     HL              ; pos--
        PUSH    HL              ; save pos
        PUSH    DE              ; save IP
        LD      A, B
        CP      0x08            ; CTRL-H? fn-1 already moved the cursor left
        JR      Z, .edit_bs_blank       ; -> skip straight to the overwrite
        LD      E, 0x08         ; DEL: cursor was not moved, step left over it
        CALL    bdos_putchar
.edit_bs_blank:
        LD      E, 0x20         ; SPACE (overwrite the deleted char)
        CALL    bdos_putchar
        LD      E, 0x08         ; BS (cursor back onto the now-blank cell)
        CALL    bdos_putchar
        POP     DE              ; restore IP
        POP     HL              ; restore pos
.edit_bs_done:
        PUSH    HL              ; push pos (decremented or 0) -> ( c-addr max pos' )
        LD      BC, 0           ; done = false
        NEXT
.edit_etx:
        ; ^C: at the start of a line exit to CP/M (old fn-10 warm-boot-on-^C; the
        ; fn-1 read path otherwise stores ^C as a char). Route through BYE so the
        ; 64 Hz tick slot is released. Mid-line, ^C is an ordinary character.
        POP     HL              ; peek pos (top of data stack)
        PUSH    HL
        LD      A, H
        OR      L
        LD      A, 0x03         ; reload char for the printable path (LD keeps Z)
        JR      NZ, .edit_printable     ; pos != 0 -> store ^C as a normal char
        JP      w_BYE_cf        ; pos == 0 -> terminate to CP/M (never returns)
.edit_break:
        ; Ctrl-\ (0x1C): keyboard-break request (Story 25.7). Set break_pending
        ; (multitasker.asm); PAUSE consumes it at the next yield seam and raises
        ; THROW -28 in the running BACKGROUND task — never the operator, which is
        ; the task that reads this byte. Don't store it into the line buffer and
        ; don't echo (like .edit_etx, a special char is not a buffer byte); return
        ; done=false so the line keeps reading — the break fires at the next yield,
        ; not by terminating the line. Stack still holds ( c-addr max pos )
        ; untouched; done := 0. DE=IP and HL are not disturbed.
        LD      A, 0xFF
        LD      (break_pending), A
        LD      BC, 0                   ; done = false -> (LINE) keeps reading
        NEXT

; -----------------------------------------------
; (LINE) ( c-addr max -- count )       [headerless kernel-internal thread]
;   The shared yielding line reader behind ACCEPT and QUERY. Loops over the
;   yielding KEY (so the operator task PAUSEs between keystrokes and a
;   background task keeps running — FR10), letting (EDIT) accumulate into the
;   caller's buffer at c-addr (honoring c-addr — Q2) until a CR/LF terminator,
;   then returns the character count. Minimal editing this story (CR/LF + BS +
;   echo via fn-1); full fn-10 parity deferred (Q4).
;       : (LINE)  0  BEGIN KEY (EDIT) UNTIL  >R 2DROP R> ;
;
;   KNOWN LIMITATION — interactive editing vs. a chatty background task.
;   The per-task line state (c-addr/max/pos) rides the data stack, so PAUSE
;   keeps it private and the BUFFER is always correct (a background task runs
;   on its own stack and can only touch the shared CONSOLE, never this buffer).
;   But EMIT does not yield, so a background task that prints between keystrokes
;   (KEY PAUSEs in the gaps) moves the terminal cursor out from under the
;   editor. (EDIT)'s backspace erase (SPACE BS) then rubs out whatever glyph the
;   cursor now sits on — a background character, not the operator's — so the
;   VISIBLE line diverges from the buffer and the operator can no longer edit by
;   eye. This is display desync, not corruption; it is the cooperative
;   EMIT-no-yield model meeting interactive line editing. Mitigation is to not
;   run output-heavy tasks while typing a definition (SLEEP them first); real
;   console-output coordination is future work, not handled here.
; -----------------------------------------------
w_PAREN_LINE_cf:
        JP      DOCOL
.line_body:
        DW      w_LIT_cf, 0             ; ( c-addr max -- c-addr max 0 )  pos = 0
.line_loop:
        DW      w_KEY_cf                ; ( ... pos -- ... pos char )     yields
        DW      w_EDIT_cf               ; ( ... pos char -- ... pos' done )
        DW      w_QBRANCH_cf            ; done false -> loop; true -> finish
        DW      .line_loop - $
        ; ( c-addr max pos ) — strip c-addr and max, leave the count.
        DW      w_TO_R_cf               ; ( c-addr max ) R: pos
        DW      w_TWO_DROP_cf           ; ( )            R: pos
        DW      w_R_FROM_cf             ; ( pos )
        DW      EXIT_CODE

; -----------------------------------------------
; ACCEPT ( c-addr +n1 -- +n2 )                   ANS Forth 1994 §6.1.0695
;   Read a line of input into the caller's buffer at c-addr (max +n1 chars),
;   returning the count +n2. Yields while waiting (FR11) and honors c-addr
;   (Q2 — closes the old tib-only deviation): it is exactly the shared line
;   reader (LINE).
; -----------------------------------------------
w_ACCEPT:
        DEFWORD "ACCEPT", 0
w_ACCEPT_body:
w_ACCEPT_cf  EQU  w_ACCEPT_body - 3
        DW      w_PAREN_LINE_cf         ; ( c-addr max -- count )
        DW      EXIT_CODE

; -----------------------------------------------
; Z80 hardware port I/O (antforth extensions)
;   Raw register-indirect port access. BC is TOS, and the Z80 register-
;   indirect forms take the full 16-bit port in BC (B = A8..A15, C = A0..A7),
;   so the port needs no marshalling. MMU-agnostic fixed-memory code words.
; -----------------------------------------------

; -----------------------------------------------
; IN ( port -- byte )
;   Read one byte from Z80 I/O port BC via IN A,(C)
; antforth extension — raw Z80 port read; BC=port (B=A8..A15)
; -----------------------------------------------
w_IN:
        DEFCODE "IN", 0
w_IN_cf:
        CALL    check_underflow ; needs 1 cell (port); preserves BC
        IN      A, (C)          ; ED 78 — read port BC into A
        LD      C, A            ; zero-extend to a cell (cf. C@)
        LD      B, 0            ; high byte provably 0
        NEXT

; -----------------------------------------------
; OUT ( x port -- )
;   Write the low byte of x to Z80 I/O port BC via OUT (C),A
; antforth extension — raw Z80 port write; ( x port -- ), datum below address like !
; -----------------------------------------------
w_OUT:
        DEFCODE "OUT", 0
w_OUT_cf:
        CALL    check_underflow_2 ; needs 2 cells (x, port); preserves BC
        POP     HL              ; HL = x (NOS); BC still = port (TOS)
        LD      A, L            ; A = low byte of x
        OUT     (C), A          ; ED 79 — write A to port BC
        POP     BC              ; new TOS (OUT consumed x and port)
        NEXT

; -----------------------------------------------
; Internal BDOS output helpers (not Forth words)
; -----------------------------------------------
bdos_putchar:               ; Entry: E = character
        LD      C, C_WRITE      ; 2 bytes
        CALL    BDOS_ENTRY      ; 3 bytes
        RET                     ; 1 byte — 6 bytes total

bdos_crlf:                  ; Print CR + LF
        LD      E, 0x0D
        CALL    bdos_putchar
        LD      E, 0x0A
        JP      bdos_putchar    ; tail-call, 10 bytes total

; -----------------------------------------------
; bdos_print_str — Print HL..HL+B-1 via BDOS (no suffix).
;   Entry: HL = string ptr, B = length
;   Clobbers: A, BC, DE, HL
; -----------------------------------------------
bdos_print_str:
.loop:
        LD      E, (HL)
        PUSH    HL
        PUSH    BC
        CALL    bdos_putchar
        POP     BC
        POP     HL
        INC     HL
        DJNZ    .loop
        RET

; -----------------------------------------------
; bdos_print_q_crlf — Print " ?" CR LF via BDOS.
;   Clobbers: A, BC, DE, HL
; -----------------------------------------------
bdos_print_q_crlf:
        LD      E, ' '
        CALL    bdos_putchar
        LD      E, '?'
        CALL    bdos_putchar
        JP      bdos_crlf       ; tail-call
