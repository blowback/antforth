; number_prefixes.asm — Numeric-literal prefix recogniser (Epic 9)
; AntForth — A Forth for CP/M on Z80
;
; Implements the NUMBER-PREFIX? recogniser that handles numeric literals
; carrying an explicit base prefix (Forth 2014 §3.4.1.3). The recogniser
; is wired into the outer interpreter's INTERPRET thread between
; ASM-RECOGNIZE and NUMBER? so that prefixed tokens are handled before
; the default-BASE parser. Never reads or writes (IY+UserArea.base).
;
; Story 9.1 scope:
;   - w_NUMBER_PREFIX_Q_cf   Recogniser entry; ( c-addr -- n true | c-addr false )
;   - '#' decimal prefix     Parses body as decimal regardless of BASE;
;                            supports a leading '-' in the body (mirrors
;                            NUMBER?'s sign-strip pattern).
;   - do_number_base10       Digit-accumulate helper with hard-coded base 10.
;   - char_to_digit_base10   ASCII '0'..'9' → 0..9; carry = invalid.
;
; Story 9.2 additions:
;   - '$' hex prefix         Forth 2014 §3.4.1.3 standard hex literal
;                            prefix (parses body as base 16, BASE
;                            unchanged); mirrors 9.1 sign-in-body.
;   - '0x'/'0X' hex prefix   antforth extension (NFR13) — C-style hex
;                            literal. The '0' dispatch arm PEEKS the
;                            second byte BEFORE entering the EXX window
;                            so bare '0', '00', '012', '0A'(HEX) etc.
;                            remain hot-path NUMBER? literals (FR52).
;                            Case fold via OR 0x20 so both 'x' and 'X'
;                            are accepted.
;   - do_number_base16       Digit-accumulate helper with hard-coded
;                            base 16 (four ADD HL,HL for *16).
;   - char_to_digit_base16   ASCII '0'..'9','A'..'F','a'..'f' → 0..15;
;                            OR 0x20 case-fold implements the Forth 2014
;                            §3.4.1.3 case-insensitivity requirement
;                            for hex digits.
;
; Prefix-dispatch scaffold for Stories 9.2–9.5
; --------------------------------------------
; The dispatch is a flat CP / JR Z chain on the first byte of the token
; (see `w_NUMBER_PREFIX_Q_cf` below). Adding a new single-char prefix is
; two lines in that chain plus a dedicated `.pref_<name>_entry` handler
; that mirrors `.pref_hash_entry` with a different base constant.
;
; Handler entry ritual (MANDATORY for every `.pref_<x>_entry`):
;   PUSH BC                 ; temporarily stash c-addr via data stack
;   EXX                     ; park TOS/IP in shadows (BC' = c-addr, DE' = IP)
;   POP  HL                 ; HL (shadow bank) = c-addr for parsing
;   ...                     ; body lives entirely in the shadow bank
; Success exit:  PUSH DE (value) / EXX / LD BC, 0xFFFF / NEXT
; Fail exit:     EXX / PUSH BC (c-addr_orig) / LD BC, 0 / NEXT
; Any helper called from inside the EXX window MUST be EXX-free — see
; `do_number_base10` and `char_to_digit_base10` as leaf-level templates.
;
; Pre-EXX peek arms (e.g. `.pref_zero_entry`): if a handler peeks the
; second body byte BEFORE entering the EXX window (to keep a hot
; fast-fail path cheap), it MUST preserve BC = c-addr until the EXX is
; reached. The peek may use HL (already = c-addr+1 from the dispatch
; prologue) and A; it MUST NOT clobber BC. `LD A, (BC)` to re-read the
; count is the canonical idiom — it's how `.pref_zero_entry` recovers
; the count without disturbing the c-addr in BC.
;
;   Story  Prefix    Base  Notes
;   -----  ------    ----  ----------------------------------------------
;   9.1    '#'       10    Forth 2014 standard (done)
;   9.2    '$'       16    Forth 2014 standard hex (this story)
;   9.2    '0x'/'0X' 16    antforth extension (this story) — two-character
;                          prefix; the '0' dispatch arm must peek the
;                          second byte to distinguish `0x2A` from a bare
;                          `0` followed by more digits. This is the ONLY
;                          2-char prefix in scope; single-char is the norm.
;   9.3    '%'       2     Binary
;   9.3    0x27 'c'  —     Character literal — variable-length body with a
;                          closing-quote check. Cannot reuse the digit
;                          accumulator; needs a dedicated handler.
;   9.4    '-'       —     Sign modifier BEFORE any other prefix. Handler
;                          should be a pre-pass that consumes the '-', sets
;                          a negate flag, and re-enters the dispatch on the
;                          remainder. Body-level '-' (e.g. `#-5`) is already
;                          handled inside `.pref_hash_entry` per 9.1 scope.

; =====================================================================
; NUMBER-PREFIX? ( c-addr -- n true | c-addr false )
; =====================================================================
; Fast-fail path (no EXX): inspect the first character while BC still
; holds c-addr. Only enters the EXX window when a known prefix char is
; seen, keeping the bare-literal hot path minimal (per AC #3).
; No dictionary header — only called from the INTERPRET thread.
;
; Forth 2014 §3.4.1.3      #<num>        — decimal-base numeric literal prefix
w_NUMBER_PREFIX_Q_cf:
        LD      H, B
        LD      L, C                    ; HL = c-addr
        LD      A, (HL)                 ; A = count
        OR      A
        JR      Z, .pref_fast_false     ; empty counted string → fail
        INC     HL                      ; HL → first char
        LD      A, (HL)                 ; A = first char

        ; === Scaffold: prefix dispatch chain ===
        ; Extend by adding CP / JR Z (or JP Z, if the handler is out of
        ; JR range) pairs below for new prefixes.
        CP      '#'
        JR      Z, .pref_hash_entry
        CP      '$'
        JP      Z, .pref_dollar_entry
        CP      '0'
        JP      Z, .pref_zero_entry
        ; 9.3:  CP '%'   / JR Z, .pref_percent_entry    ; base 2
        ; 9.3:  CP 0x27  / JR Z, .pref_quote_entry      ; 'c' literal
        ; 9.4:  CP '-'   / JR Z, .pref_sign_entry       ; sign modifier

.pref_fast_false:
        ; Not a prefix — BC still = original c-addr.
        PUSH    BC                      ; NOS = c-addr
        LD      BC, 0                   ; TOS = FALSE
        NEXT

; ---------------------------------------------------------------------
; '#' decimal prefix handler (Story 9.1).
; Enters with BC = c-addr, DE = IP, HL = c-addr+1 (→ '#' byte).
; Uses the shadow BC' preservation idiom from NUMBER? — a plain entry
; EXX leaves the original c-addr in BC' for the fail path for free.
; ---------------------------------------------------------------------
.pref_hash_entry:
        PUSH    BC                      ; save c-addr on SP (for POP HL below)
        EXX                             ; BC' = c-addr, DE' = IP
        POP     HL                      ; HL = c-addr (main)

        LD      A, (HL)                 ; A = count
        INC     HL                      ; past count byte
        INC     HL                      ; past '#' (first char)
        DEC     A                       ; body count = count - 1
        ; Defensive: bare `#` is currently consumed by FIND (assembler
        ; IMM-marker word `#` at assembler.asm:985) before reaching this
        ; recogniser, so this branch is unreachable in today's dictionary.
        ; Kept in case `#` is hidden/renamed or the dictionary order changes.
        JR      Z, .pref_hash_fail      ; bare "#" → fail
        LD      B, A                    ; B = body count

        ; Optional leading '-' in body (e.g. '#-5'). Mirrors NUMBER?
        ; sign-strip at strings.asm:387. Sign-BEFORE-prefix (-#42) is
        ; Story 9.4 scope and is NOT handled here.
        XOR     A
        LD      (.pref_negate), A       ; negate = false
        LD      A, (HL)
        CP      '-'
        JR      NZ, .pref_hash_convert
        LD      A, 1
        LD      (.pref_negate), A
        INC     HL
        DEC     B
        JR      Z, .pref_hash_fail      ; bare "#-" → fail

.pref_hash_convert:
        LD      DE, 0                   ; accumulator = 0
        CALL    do_number_base10        ; DE = value, B = remaining count
        LD      A, B
        OR      A
        JR      NZ, .pref_hash_fail     ; unparsed chars → fail

        ; Apply sign if flagged
        LD      A, (.pref_negate)
        OR      A
        JR      Z, .pref_hash_ok
        LD      A, E
        CPL
        LD      E, A
        LD      A, D
        CPL
        LD      D, A
        INC     DE                      ; two's complement

.pref_hash_ok:
        PUSH    DE                      ; NOS = n
        EXX                             ; restore IP to main DE
        LD      BC, 0xFFFF              ; TOS = TRUE
        NEXT

.pref_hash_fail:
        ; Shadow BC' still holds c-addr_orig — EXX brings it back to main BC.
        EXX                             ; restore IP; main BC = c-addr_orig
        PUSH    BC                      ; NOS = c-addr
        LD      BC, 0                   ; TOS = FALSE
        NEXT

; Scratch for sign flag — scoped to w_NUMBER_PREFIX_Q_cf via the local
; label prefix, must live before the next global label. Shared by the
; '#', '$', and '0x'/'0X' handlers (w_NUMBER_PREFIX_Q_cf is single-
; threaded and non-reentrant, so one scratch byte is sufficient).
.pref_negate:   DB      0

; ---------------------------------------------------------------------
; '$' hexadecimal prefix handler (Story 9.2).
; Enters with BC = c-addr, DE = IP, HL = c-addr+1 (→ '$' byte), A = '$'.
; Structure mirrors .pref_hash_entry — swap base-10 → base-16 helpers.
; ---------------------------------------------------------------------
; Forth 2014 §3.4.1.3      $<num>        — hexadecimal-base numeric literal prefix
.pref_dollar_entry:
        PUSH    BC                      ; save c-addr on SP (for POP HL below)
        EXX                             ; BC' = c-addr, DE' = IP
        POP     HL                      ; HL = c-addr (main)

        LD      A, (HL)                 ; A = count
        INC     HL                      ; past count byte
        INC     HL                      ; past '$' (first char)
        DEC     A                       ; body count = count - 1
        JR      Z, .pref_dollar_fail    ; bare "$" → fail
        LD      B, A                    ; B = body count

        ; Optional leading '-' in body (e.g. '$-FF'). Mirrors 9.1 `#-5`
        ; sign-strip pattern (NUMBER? parity). Sign-BEFORE-prefix (-$FF)
        ; is Story 9.4 scope.
        XOR     A
        LD      (.pref_negate), A       ; negate = false
        LD      A, (HL)
        CP      '-'
        JR      NZ, .pref_dollar_convert
        LD      A, 1
        LD      (.pref_negate), A
        INC     HL
        DEC     B
        JR      Z, .pref_dollar_fail    ; bare "$-" → fail

.pref_dollar_convert:
        LD      DE, 0                   ; accumulator = 0
        CALL    do_number_base16        ; DE = value, B = remaining count
        LD      A, B
        OR      A
        JR      NZ, .pref_dollar_fail   ; unparsed chars → fail

        ; Apply sign if flagged
        LD      A, (.pref_negate)
        OR      A
        JR      Z, .pref_dollar_ok
        LD      A, E
        CPL
        LD      E, A
        LD      A, D
        CPL
        LD      D, A
        INC     DE                      ; two's complement

.pref_dollar_ok:
        PUSH    DE                      ; NOS = n
        EXX                             ; restore IP to main DE
        LD      BC, 0xFFFF              ; TOS = TRUE
        NEXT

.pref_dollar_fail:
        ; Shadow BC' still holds c-addr_orig — EXX brings it back to main BC.
        EXX                             ; restore IP; main BC = c-addr_orig
        PUSH    BC                      ; NOS = c-addr
        LD      BC, 0                   ; TOS = FALSE
        NEXT

; ---------------------------------------------------------------------
; '0x' / '0X' hexadecimal prefix handler (Story 9.2, antforth extension).
; Enters with BC = c-addr, DE = IP, HL = c-addr+1 (→ '0' byte), A = '0'.
;
; CRITICAL: the second-byte peek happens BEFORE any EXX. Bare '0', '00',
; '012', '0A' etc. must fast-fail with zero stack touch so NUMBER? sees
; the same c-addr and parses unchanged (FR52 — unprefixed hot path must
; not regress). Only when the second byte is 'x'/'X' do we commit to
; the hex path and enter the EXX window.
; ---------------------------------------------------------------------
; antforth extension         0x<num>       — C-style hex prefix
.pref_zero_entry:
        ; BC = c-addr (the counted-string address), so the count byte
        ; is at (BC). HL currently → '0' (first char).
        LD      A, (BC)                 ; A = count
        CP      2
        JP      C, .pref_fast_false     ; bare '0' → not a '0x' token (JP: out of JR range)
        INC     HL                      ; HL → second char
        LD      A, (HL)
        OR      0x20                    ; fold case: 'X' (0x58) → 'x' (0x78); 'x' → 'x'
        CP      'x'
        JP      NZ, .pref_fast_false    ; second char not 'x'/'X' → fallthrough (JP: out of JR range)

        ; Second char IS 'x'/'X' — commit to hex path (enter EXX window).
        PUSH    BC                      ; save c-addr on SP (for POP HL)
        EXX                             ; BC' = c-addr, DE' = IP
        POP     HL                      ; HL = c-addr (main)

        LD      A, (HL)                 ; A = count
        INC     HL                      ; past count byte
        INC     HL                      ; past '0'
        INC     HL                      ; past 'x'/'X'
        SUB     2                       ; body count = count - 2
        JR      Z, .pref_zero_fail      ; bare "0x" / "0X" → fail
        LD      B, A                    ; B = body count

        ; Optional leading '-' in body (e.g. '0x-FF'). Mirrors 9.1 `#-5`.
        XOR     A
        LD      (.pref_negate), A
        LD      A, (HL)
        CP      '-'
        JR      NZ, .pref_zero_convert
        LD      A, 1
        LD      (.pref_negate), A
        INC     HL
        DEC     B
        JR      Z, .pref_zero_fail      ; bare "0x-" → fail

.pref_zero_convert:
        LD      DE, 0
        CALL    do_number_base16
        LD      A, B
        OR      A
        JR      NZ, .pref_zero_fail

        LD      A, (.pref_negate)
        OR      A
        JR      Z, .pref_zero_ok
        LD      A, E
        CPL
        LD      E, A
        LD      A, D
        CPL
        LD      D, A
        INC     DE

.pref_zero_ok:
        PUSH    DE
        EXX
        LD      BC, 0xFFFF
        NEXT

.pref_zero_fail:
        EXX                             ; restore IP; main BC = c-addr_orig
        PUSH    BC
        LD      BC, 0
        NEXT

; ---------------------------------------------------------------------
; do_number_base10 — Digit-accumulate with hard-coded base = 10.
; Near-copy of strings.asm:do_number but never reads BASE (per FR9).
; Optimised *10 via shift-and-add (5 ADDs) instead of the 16-bit
; shift-and-add multiplier used by the generic do_number.
; Input:  HL = digit string, B = count, DE = accumulator
; Output: HL = advanced, B = remaining, DE = result
; Clobbers: A, F, C
; EXX-free — safe to CALL from inside an EXX window.
; ---------------------------------------------------------------------
do_number_base10:
.dn10_loop:
        LD      A, B
        OR      A
        RET     Z                       ; no chars left
        LD      A, (HL)
        CALL    char_to_digit_base10
        RET     C                       ; invalid digit → stop
        ; DE = DE * 10 + digit: HL = DE*2, HL*=2 (*4), HL+=DE (*5), HL*=2 (*10)
        PUSH    AF                      ; save digit
        PUSH    HL                      ; save str ptr
        PUSH    BC                      ; save count
        LD      H, D
        LD      L, E
        ADD     HL, HL                  ; *2
        ADD     HL, HL                  ; *4
        ADD     HL, DE                  ; *5
        ADD     HL, HL                  ; *10
        EX      DE, HL                  ; DE = value * 10
        POP     BC
        POP     HL
        POP     AF
        ; DE += A (digit)
        LD      C, A
        LD      A, E
        ADD     A, C
        LD      E, A
        JR      NC, .dn10_nc
        INC     D
.dn10_nc:
        INC     HL                      ; next char
        DEC     B                       ; count--
        JR      .dn10_loop

; ---------------------------------------------------------------------
; char_to_digit_base10 — ASCII → digit (0..9 only).
; Input:  A = ASCII char
; Output: A = digit 0..9 with carry clear if valid; carry set if invalid
; Clobbers: F
; EXX-free.
; ---------------------------------------------------------------------
char_to_digit_base10:
        CP      '0'
        JR      C, .ctd10_invalid
        CP      '9' + 1
        JR      NC, .ctd10_invalid
        SUB     '0'
        OR      A                       ; OR clears carry (value is 0..9, bit 7 = 0)
        RET
.ctd10_invalid:
        SCF
        RET

; ---------------------------------------------------------------------
; do_number_base16 — Digit-accumulate with hard-coded base = 16.
; Near-sibling of do_number_base10; same loop structure, *16 replaces
; *10 (four ADD HL,HL is shorter than *10's 5-op sequence).
; Input:  HL = digit string, B = count, DE = accumulator
; Output: HL = advanced, B = remaining, DE = result
; Clobbers: A, F, C
; EXX-free — safe to CALL from inside an EXX window.
; ---------------------------------------------------------------------
do_number_base16:
.dn16_loop:
        LD      A, B
        OR      A
        RET     Z                       ; no chars left
        LD      A, (HL)
        CALL    char_to_digit_base16
        RET     C                       ; invalid digit → stop
        ; DE = DE * 16 + digit via four shifts of HL
        PUSH    AF                      ; save digit
        PUSH    HL                      ; save str ptr
        PUSH    BC                      ; save count
        LD      H, D
        LD      L, E
        ADD     HL, HL                  ; *2
        ADD     HL, HL                  ; *4
        ADD     HL, HL                  ; *8
        ADD     HL, HL                  ; *16
        EX      DE, HL                  ; DE = value * 16
        POP     BC
        POP     HL
        POP     AF
        ; DE += A (digit)
        LD      C, A
        LD      A, E
        ADD     A, C
        LD      E, A
        JR      NC, .dn16_nc
        INC     D
.dn16_nc:
        INC     HL                      ; next char
        DEC     B                       ; count--
        JR      .dn16_loop

; ---------------------------------------------------------------------
; char_to_digit_base16 — ASCII → digit (0..9, a..f, A..F).
; Folds 'A'..'F' and 'a'..'f' into the same range via `OR 0x20` —
; implements the Forth 2014 §3.4.1.3 case-insensitivity requirement for
; hex digits (cited at architecture §E9 / CCD-3, per project memory
; `feedback_design_upfront.md`: design for the full case-insensitivity
; scope up front rather than retrofitting in 9.4).
; Input:  A = ASCII char
; Output: A = digit 0..15 with carry clear if valid; carry set if invalid
; Clobbers: F
; EXX-free.
; ---------------------------------------------------------------------
char_to_digit_base16:
        CP      '0'
        JR      C, .ctd16_invalid
        CP      '9' + 1
        JR      NC, .ctd16_alpha        ; not a decimal digit; try alpha
        SUB     '0'                     ; digit 0..9
        OR      A                       ; clear carry
        RET
.ctd16_alpha:
        ; Fold case: 'A'..'F' and 'a'..'f' both → 'a'..'f' after OR 0x20
        OR      0x20                    ; force lower case (bit 5)
        CP      'a'
        JR      C, .ctd16_invalid
        CP      'f' + 1
        JR      NC, .ctd16_invalid
        SUB     'a' - 10                ; digit 10..15
        OR      A                       ; clear carry
        RET
.ctd16_invalid:
        SCF
        RET
