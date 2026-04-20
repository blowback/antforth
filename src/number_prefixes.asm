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
;   - '0x'/'0X' hex prefix   antforth extension (NFR12) — C-style hex
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
; Story 9.3 additions:
;   - '%' binary prefix      Forth 2014 §3.4.1.3 binary literal prefix
;                            (parses body as base 2, BASE unchanged);
;                            mirrors 9.1/9.2 sign-in-body.
;   - 0x27 'c' char literal  Forth 2014 §3.4.1.3 character-code literal.
;                            Dedicated handler — variable-length body
;                            with an exact-length (3-byte) check and a
;                            closing-quote validation. Does NOT reuse
;                            `do_number_base<N>` and does NOT touch the
;                            `.pref_negate` scratch (no sign-in-body —
;                            a char literal is a transparent byte pass-
;                            through). Bare `'` is intercepted by FIND
;                            (TICK at compiler.asm) and never reaches
;                            this recogniser.
;   - do_number_base2        Digit-accumulate helper with hard-coded
;                            base 2 (single ADD HL,HL for *2).
;   - char_to_digit_base2    ASCII '0'..'1' → 0..1; carry = invalid.
;
; Story 9.4 additions:
;   - '-' sign-before-prefix .pref_sign_entry — a pre-dispatch handler
;                            that peeks the second char OUTSIDE the EXX
;                            window and only commits if it is a known
;                            prefix. Outer sign composes with in-body
;                            sign via XOR (e.g. `-#-5` → +5). Per-handler
;                            entry points (`.pref_<x>_enter_after_sign`)
;                            handle the "skip one extra byte" offset.
;                            Forth 2014 §3.4.1.3 — leading sign is
;                            standard, not an antforth extension.
;   - .pref_check_sign       Shared in-body sign-strip helper (13 bytes,
;                            EXX-free). Replaces the quadruplicated sign-
;                            strip blocks in `#`, `$`, `0x`, `%` handlers
;                            (collapses ~7 lines × 4 = ~28 lines to one
;                            CALL per site). Pays off the M2 finding from
;                            9.2 (re-surfaced as debt in 9.3).
;   - XOR-semantic flag      `.pref_negate` is initialised ONCE at
;                            dispatch entry; every sign source (outer
;                            '-' pre-pass, in-body '-' via check helper)
;                            XOR-toggles with 1. This discipline makes
;                            outer and in-body signs compose without
;                            special-case code — falls out of XOR.
;   - 'c' outer-sign read    The `'c'` handler gains a sign-apply block
;                            on its success path (~14 bytes). It still
;                            does not WRITE `.pref_negate` — reads only.
;   - Case-insensitivity     No new code: 9.2 already designed hex-digit
;       (audit only)         and `0x`/`0X` prefix-letter case-fold up
;                            front (per `feedback_design_upfront.md`).
;                            9.4 adds test coverage that asserts the
;                            promise observationally.
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
;   9.2    '$'       16    Forth 2014 standard hex (done)
;   9.2    '0x'/'0X' 16    antforth extension (done) — two-character
;                          prefix; the '0' dispatch arm must peek the
;                          second byte to distinguish `0x2A` from a bare
;                          `0` followed by more digits. This is the ONLY
;                          2-char prefix in scope; single-char is the norm.
;   9.3    '%'       2     Binary (done)
;   9.3    0x27 'c'  —     Character literal (done) — variable-length
;                          body with an exact-length (3-byte) check and a
;                          closing-quote check. Dedicated handler, no digit
;                          accumulator.
;   9.4    '-'       —     Sign modifier BEFORE any other prefix (done).
;                          Pre-pass `.pref_sign_entry` peeks the second
;                          char outside the EXX window and, if it is a
;                          known prefix, jumps to a per-handler
;                          `.pref_<x>_enter_after_sign` entry. Each entry
;                          checks the count, then XOR-toggles `.pref_negate`
;                          only once committed, then enters the normal
;                          handler body one byte later. Double-sign
;                          composition (`-#-5` → +5) is a consequence of
;                          the XOR discipline.
;   9.5    —         —     Verification only (done) — no new dispatch code.
;                          Story 9.5 adds 35 REPL-piped tests proving
;                          prefix reach into colon bodies and CODE blocks.
;                          The single shared INTERPRET thread at
;                          outer_interpreter.asm:.try_number makes the
;                          three contexts (REPL / colon body / CODE block)
;                          already identical — 9.5 is the observational
;                          proof, not a new wire-in. Zero-byte binary
;                          delta; no new standards citations.

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

        ; 9.4: dispatch-level one-time reset of .pref_negate. Every sign
        ; source (outer '-' pre-pass, in-body '-' via pref_check_sign)
        ; XOR-toggles this byte; this single reset per recogniser entry
        ; is the anchor that makes outer+in-body sign composition work
        ; via XOR (see AC #5, #12 in the 9.4 story spec). A is clobbered
        ; here but re-loaded from (HL) below, so no preserve is needed.
        XOR     A
        LD      (.pref_negate), A

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
        CP      '%'
        JP      Z, .pref_percent_entry
        CP      0x27
        JP      Z, .pref_quote_entry
        ; Forth 2014 §3.4.1.3      -<prefix><num>  — optional leading sign modifier
        CP      '-'
        JP      Z, .pref_sign_entry

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
        ; handled by the .pref_sign_entry pre-pass (9.4) which toggles
        ; .pref_negate before re-entering via .pref_hash_enter_after_sign.
        ; The shared helper XOR-toggles the flag so outer and in-body
        ; signs compose (AC #5: `-#-5` → +5).
        CALL    .pref_check_sign
        JR      C, .pref_hash_fail      ; bare "#-" → fail

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
; '-' pre-pass (9.4) and the '#', '$', '0x'/'0X', '%' handlers' in-body
; sign-strip (w_NUMBER_PREFIX_Q_cf is single-threaded and non-reentrant,
; so one scratch byte is sufficient). The 'c' character-literal handler
; READS .pref_negate on its success path (9.4) to apply an outer '-',
; but never writes it.
;
; Invariant (MANDATORY for any future reader) — 9.4 semantics:
;
;   Dispatch is the one-time initialiser. w_NUMBER_PREFIX_Q_cf resets
;   .pref_negate to 0 exactly once per recogniser entry, immediately
;   after the empty-count check and before the dispatch chain. Every
;   subsequent sign source XOR-TOGGLES the flag with 1. Sign sources
;   in play after 9.4:
;
;     (a) Outer '-' pre-pass in .pref_sign_entry — toggles once if the
;         '-' arm commits (second char is a recognised prefix).
;     (b) In-body '-' in the '#', '$', '0x', '%' handlers — toggles
;         once via the shared pref_check_sign helper.
;
;   This XOR discipline is what makes outer and in-body signs compose
;   cleanly: `-#-5` toggles twice (outer + in-body) and yields +5,
;   directly reflecting two's-complement arithmetic intuition. See the
;   9.4 story AC #5 for the full composition table.
;
;   The 'c' handler is a read-only consumer: on the success path it
;   loads .pref_negate once and, if nonzero, applies a two's-complement
;   negate to the char code before PUSH. It never writes to the flag.
;
;   Failed handler paths may leave the byte at 1 (e.g. `%-` fails after
;   toggling it); the next recogniser entry's dispatch-level reset
;   makes that irrelevant.
.pref_negate:   DB      0

; ---------------------------------------------------------------------
; .pref_check_sign — in-body sign-strip helper (leaf; EXX-free).
; At entry: HL → first body byte, B = body count (>= 1).
; If first byte is '-', advance HL, decrement B, XOR .pref_negate with 1.
;   Exit carry set   → bare '<prefix>-' (body exhausted after stripping '-').
;   Exit carry clear → either '-' was stripped (B = B-1, HL advanced) or
;                      first byte was not '-' (HL, B unchanged).
; Preserves: DE, IX, IY, and the shadow bank (caller's c-addr in BC',
; IP in DE'). Clobbers: A, F (F carries the fail/not-fail signal).
;
; EXX-free — safe to CALL from inside an EXX window. Do NOT issue EXX
; here. Shared by every handler's in-body sign-strip call site (9.4
; refactor — collapses the 4x duplicated block from 9.1/9.2/9.3; also
; reused by the 9.4 .pref_<x>_enter_after_sign entries to allow double-
; sign composition like `-#-5` → +5 via XOR toggle).
; ---------------------------------------------------------------------
.pref_check_sign:
        LD      A, (HL)
        CP      '-'
        RET     NZ                      ; not '-', no change (carry clear from CP)
        LD      A, (.pref_negate)
        XOR     1
        LD      (.pref_negate), A
        INC     HL
        DEC     B
        RET     NZ                      ; more bytes in body, carry clear
        SCF
        RET                             ; body exhausted → carry set (fail signal)

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

        ; Optional leading '-' in body (e.g. '$-FF'). See .pref_hash_entry
        ; for the full comment block; the shared helper XOR-toggles the
        ; flag so outer and in-body signs compose via `.pref_sign_entry`.
        CALL    .pref_check_sign
        JR      C, .pref_dollar_fail    ; bare "$-" → fail

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

        ; Optional leading '-' in body (e.g. '0x-FF'). Shared helper
        ; XOR-toggle; see .pref_hash_entry for the full comment block.
        CALL    .pref_check_sign
        JR      C, .pref_zero_fail      ; bare "0x-" → fail

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
; '%' binary prefix handler (Story 9.3).
; Enters with BC = c-addr, DE = IP, HL = c-addr+1 (→ '%' byte), A = '%'.
; Structure mirrors .pref_dollar_entry — swap base-16 → base-2 helper.
; ---------------------------------------------------------------------
; Forth 2014 §3.4.1.3      %<num>        — binary-base numeric literal prefix
.pref_percent_entry:
        PUSH    BC                      ; save c-addr on SP (for POP HL below)
        EXX                             ; BC' = c-addr, DE' = IP
        POP     HL                      ; HL = c-addr (main)

        LD      A, (HL)                 ; A = count
        INC     HL                      ; past count byte
        INC     HL                      ; past '%' (first char)
        DEC     A                       ; body count = count - 1
        JR      Z, .pref_percent_fail   ; bare "%" → fail
        LD      B, A                    ; B = body count

        ; Optional leading '-' in body (e.g. '%-1010'). Shared helper
        ; XOR-toggle; see .pref_hash_entry for the full comment block.
        CALL    .pref_check_sign
        JR      C, .pref_percent_fail   ; bare "%-" → fail

.pref_percent_convert:
        LD      DE, 0                   ; accumulator = 0
        CALL    do_number_base2         ; DE = value, B = remaining count
        LD      A, B
        OR      A
        JR      NZ, .pref_percent_fail  ; unparsed chars → fail

        ; Apply sign if flagged
        LD      A, (.pref_negate)
        OR      A
        JR      Z, .pref_percent_ok
        LD      A, E
        CPL
        LD      E, A
        LD      A, D
        CPL
        LD      D, A
        INC     DE                      ; two's complement

.pref_percent_ok:
        PUSH    DE                      ; NOS = n
        EXX                             ; restore IP to main DE
        LD      BC, 0xFFFF              ; TOS = TRUE
        NEXT

.pref_percent_fail:
        ; Shadow BC' still holds c-addr_orig — EXX brings it back to main BC.
        EXX                             ; restore IP; main BC = c-addr_orig
        PUSH    BC                      ; NOS = c-addr
        LD      BC, 0                   ; TOS = FALSE
        NEXT

; ---------------------------------------------------------------------
; "'c'" character-literal handler (Story 9.3).
; Enters with BC = c-addr, DE = IP, HL = c-addr+1 (→ opening ' byte),
; A = 0x27 ('). Dedicated handler — does NOT call do_number_base<N> and
; does NOT touch .pref_negate. Reads exactly one middle byte and
; validates the closing quote.
;
; Bare ' is intercepted by FIND (TICK at compiler.asm:26) before
; reaching this recogniser — this arm only fires for "'..." tokens
; (≥ 2 bytes) that FIND did not match. Exact-length discipline: count
; MUST equal 3; anything else fails.
;
; 9.4 extension: the success path reads .pref_negate once and applies
; a two's-complement negate to the char code if the outer '-' pre-pass
; (.pref_sign_entry) set the flag. The handler still never writes to
; .pref_negate and still has no in-body sign — a char literal's middle
; byte is a transparent pass-through per Forth 2014 §3.4.1.3.
; ---------------------------------------------------------------------
; Forth 2014 §3.4.1.3      'c'           — character-code literal
.pref_quote_entry:
        PUSH    BC                      ; save c-addr on SP (for POP HL below)
        EXX                             ; BC' = c-addr, DE' = IP
        POP     HL                      ; HL = c-addr (main)

        LD      A, (HL)                 ; A = count
        CP      3
        JR      NZ, .pref_quote_fail    ; must be exactly 3 bytes total
        INC     HL                      ; past count byte
        INC     HL                      ; past opening '
        LD      E, (HL)                 ; E = middle byte (char code)
        LD      D, 0                    ; DE = zero-extended char code
        INC     HL                      ; → closing-quote position
        LD      A, (HL)
        CP      0x27
        JR      NZ, .pref_quote_fail    ; missing closing '

.pref_quote_ok:
        ; 9.4: apply outer '-' prefix from .pref_negate. The 'c' handler
        ; has no in-body sign; this reads the flag set by the sign-before-
        ; prefix dispatch arm (.pref_sign_entry) and applies a two's-
        ; complement negate — mirrors the digit handlers' sign-apply tail.
        ; Also the fallthrough success target for .pref_quote_enter_after_sign.
        LD      A, (.pref_negate)
        OR      A
        JR      Z, .pref_quote_push
        LD      A, E
        CPL
        LD      E, A
        LD      A, D
        CPL
        LD      D, A
        INC     DE                      ; two's complement

.pref_quote_push:
        PUSH    DE                      ; NOS = char code
        EXX                             ; restore IP to main DE
        LD      BC, 0xFFFF              ; TOS = TRUE
        NEXT

.pref_quote_fail:
        EXX                             ; restore IP; main BC = c-addr_orig
        PUSH    BC                      ; NOS = c-addr
        LD      BC, 0                   ; TOS = FALSE
        NEXT

; ---------------------------------------------------------------------
; '-' sign-BEFORE-prefix modifier handler (Story 9.4).
; Enters with BC = c-addr, HL = c-addr+1 (→ '-' byte), A = '-'.
;
; Peeks the SECOND char (first char after '-') OUTSIDE the EXX window.
; If the second char is a recognised prefix (# $ 0 % 0x27), jumps to
; the corresponding .pref_<x>_enter_after_sign entry which toggles
; .pref_negate and proceeds. Otherwise falls through to .pref_fast_false
; so NUMBER? owns '-42' etc. per FR47.
;
; Like .pref_zero_entry's second-byte peek: runs entirely outside the
; EXX window, preserving BC = c-addr for the fall-through path. BC is
; only consumed (via PUSH BC / EXX) inside the per-handler enter-after-
; sign labels, which commit to the outer-sign path.
; ---------------------------------------------------------------------
; Forth 2014 §3.4.1.3      -<prefix><num>  — optional leading sign modifier
.pref_sign_entry:
        ; BC = c-addr (counted-string address), (BC) = count.
        ; HL currently → '-' (first body char).
        LD      A, (BC)                 ; A = count
        CP      2
        JP      C, .pref_fast_false     ; bare '-' → FIND caught (unreachable normally)
        INC     HL                      ; HL → second char
        LD      A, (HL)                 ; A = second char
        CP      '#'
        JP      Z, .pref_hash_enter_after_sign
        CP      '$'
        JP      Z, .pref_dollar_enter_after_sign
        CP      '0'
        JP      Z, .pref_zero_enter_after_sign
        CP      '%'
        JP      Z, .pref_percent_enter_after_sign
        CP      0x27
        JP      Z, .pref_quote_enter_after_sign
        JP      .pref_fast_false        ; second char not a prefix → NUMBER?

; ---------------------------------------------------------------------
; .pref_<x>_enter_after_sign — per-handler entry points for the '-'
; pre-pass. Each one:
;   1. Peeks count (via LD A, (BC)) and validates the body shape BEFORE
;      touching .pref_negate — a failed entry falls through to
;      .pref_fast_false (so NUMBER? reports the undefined word) and
;      leaves the flag at 0 regardless of dispatch-level reset. This
;      mirrors .pref_zero_entry's pre-EXX peek discipline.
;   2. Only once committed, XOR-toggles .pref_negate (the outer sign
;      commit) — still outside EXX.
;   3. Enters the EXX window (PUSH BC / EXX / POP HL).
;   4. Skips count + '-' + prefix byte(s) to position HL at body start.
;      Body count = count - 2 for single-char prefix, count - 3 for 0x;
;      exact count == 4 check for 'c' (done in step 1).
;   5. Calls .pref_check_sign for any in-body '-' (enables double-sign
;      composition: `-#-5` XOR-toggles a second time → +5).
;   6. JP to the handler's .pref_<x>_convert (or .pref_quote_ok) tail,
;      which runs the digit-accumulate (or char-body read) + sign-apply.
; ---------------------------------------------------------------------
.pref_hash_enter_after_sign:
        ; Check count BEFORE toggling .pref_negate — mirrors the
        ; check-first-then-commit ordering used by .pref_zero_enter_after_sign,
        ; so a failed entry leaves the flag at 0 rather than relying on
        ; the next token's dispatch-level reset to clean up.
        LD      A, (BC)                 ; A = count
        SUB     2                       ; body count = count - 2 ('-' + '#')
        JP      Z, .pref_fast_false     ; bare "-#" → fall through to NUMBER?
        LD      A, (.pref_negate)       ; commit: toggle outer-sign flag
        XOR     1
        LD      (.pref_negate), A
        PUSH    BC                      ; save c-addr
        EXX                             ; BC' = c-addr, DE' = IP
        POP     HL                      ; HL = c-addr (main)
        LD      A, (HL)                 ; A = count
        INC     HL                      ; past count
        INC     HL                      ; past '-'
        INC     HL                      ; past '#'
        SUB     2                       ; body count = count - 2
        LD      B, A                    ; B = body count
        CALL    .pref_check_sign        ; allow double-sign ('-#-5')
        JP      C, .pref_hash_fail      ; "-#-" body exhausted → fail
        JP      .pref_hash_convert

.pref_dollar_enter_after_sign:
        LD      A, (BC)                 ; check count BEFORE committing flag
        SUB     2
        JP      Z, .pref_fast_false     ; bare "-$" → fall through to NUMBER?
        LD      A, (.pref_negate)
        XOR     1
        LD      (.pref_negate), A
        PUSH    BC
        EXX
        POP     HL
        LD      A, (HL)                 ; count
        INC     HL                      ; past count
        INC     HL                      ; past '-'
        INC     HL                      ; past '$'
        SUB     2                       ; body count = count - 2
        LD      B, A
        CALL    .pref_check_sign        ; allow "-$-FF" double-sign
        JP      C, .pref_dollar_fail    ; "-$-" body exhausted → fail
        JP      .pref_dollar_convert

.pref_percent_enter_after_sign:
        LD      A, (BC)                 ; check count BEFORE committing flag
        SUB     2
        JP      Z, .pref_fast_false     ; bare "-%" → fall through to NUMBER?
        LD      A, (.pref_negate)
        XOR     1
        LD      (.pref_negate), A
        PUSH    BC
        EXX
        POP     HL
        LD      A, (HL)                 ; count
        INC     HL                      ; past count
        INC     HL                      ; past '-'
        INC     HL                      ; past '%'
        SUB     2                       ; body count = count - 2
        LD      B, A
        CALL    .pref_check_sign        ; allow "-%-1010" double-sign
        JP      C, .pref_percent_fail
        JP      .pref_percent_convert

; '-0x' / '-0X' requires an extra third-char check (second-byte peek
; precedent from .pref_zero_entry): we only commit to the -0x form if
; the third char is 'x' or 'X'. Otherwise fall through to .pref_fast_false
; so NUMBER? gets '-0...' (e.g. '-0' as signed-zero is a pre-9.4 literal).
.pref_zero_enter_after_sign:
        ; HL → '0' (second char; was set by .pref_sign_entry's INC HL).
        ; BC = c-addr; (BC) = count.
        LD      A, (BC)                 ; A = count
        CP      3
        JP      C, .pref_fast_false     ; '-0' alone (2 bytes) → fall through
        INC     HL                      ; HL → third char
        LD      A, (HL)
        OR      0x20                    ; fold case: 'X'→'x'
        CP      'x'
        JP      NZ, .pref_fast_false    ; '-0Y' (Y != x/X) → fall through
        ; Committed to '-0x' / '-0X' form.
        LD      A, (.pref_negate)
        XOR     1
        LD      (.pref_negate), A
        PUSH    BC
        EXX
        POP     HL
        LD      A, (HL)                 ; count
        INC     HL                      ; past count
        INC     HL                      ; past '-'
        INC     HL                      ; past '0'
        INC     HL                      ; past 'x'/'X'
        SUB     3                       ; body count = count - 3
        JP      Z, .pref_zero_fail      ; "-0x" → fail
        LD      B, A
        CALL    .pref_check_sign        ; allow "-0x-FF" double-sign
        JP      C, .pref_zero_fail
        JP      .pref_zero_convert

; '-'c'' requires exact count == 4 ('-' + "'c'" = 4 bytes). No in-body
; sign (the 'c' handler has none); sign-apply happens at the shared
; .pref_quote_ok tail which both .pref_quote_entry and this entry reach.
.pref_quote_enter_after_sign:
        LD      A, (BC)                 ; check count BEFORE committing flag
        CP      4
        JP      NZ, .pref_fast_false    ; not exactly 4 bytes → fall through
        LD      A, (.pref_negate)
        XOR     1
        LD      (.pref_negate), A
        PUSH    BC
        EXX
        POP     HL
        INC     HL                      ; past count
        INC     HL                      ; past '-'
        INC     HL                      ; past opening '
        LD      E, (HL)                 ; E = middle byte (char code)
        LD      D, 0
        INC     HL                      ; → closing-quote position
        LD      A, (HL)
        CP      0x27
        JP      NZ, .pref_quote_fail    ; missing closing '
        JP      .pref_quote_ok          ; rejoin sign-apply + push + NEXT

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

; ---------------------------------------------------------------------
; do_number_base2 — Digit-accumulate with hard-coded base = 2.
; Third sibling in the base-N family (see do_number_base10,
; do_number_base16 above) — same loop structure, *2 is a single
; ADD HL,HL. Inlined directly (2 EX + 1 ADD) instead of the sibling
; PUSH/POP save-restore block (3 PUSH + 3 POP + N ADD) — net ~7 bytes
; smaller than if base-2 had reused the base-16 multiply scaffold.
; Input:  HL = digit string, B = count, DE = accumulator
; Output: HL = advanced, B = remaining, DE = result
; Clobbers: A, F, C
; EXX-free — safe to CALL from inside an EXX window.
; ---------------------------------------------------------------------
do_number_base2:
.dn2_loop:
        LD      A, B
        OR      A
        RET     Z                       ; no chars left
        LD      A, (HL)
        CALL    char_to_digit_base2
        RET     C                       ; invalid digit → stop
        ; DE = DE * 2 + digit via a single ADD HL,HL (no stack churn).
        LD      C, A                    ; C = digit (saved across shift)
        EX      DE, HL                  ; HL = value, DE = str ptr
        ADD     HL, HL                  ; value *= 2
        EX      DE, HL                  ; DE = value * 2, HL = str ptr
        ; DE += C (digit)
        LD      A, E
        ADD     A, C
        LD      E, A
        JR      NC, .dn2_nc
        INC     D
.dn2_nc:
        INC     HL                      ; next char
        DEC     B                       ; count--
        JR      .dn2_loop

; ---------------------------------------------------------------------
; char_to_digit_base2 — ASCII → digit (0 or 1 only).
; Input:  A = ASCII char
; Output: A = digit 0..1 with carry clear if valid; carry set if invalid
; Clobbers: F
; EXX-free.
; ---------------------------------------------------------------------
char_to_digit_base2:
        CP      '0'
        JR      C, .ctd2_invalid
        CP      '2'                     ; '0' or '1' are valid (< '2')
        JR      NC, .ctd2_invalid
        SUB     '0'                     ; digit 0 or 1
        OR      A                       ; clear carry
        RET
.ctd2_invalid:
        SCF
        RET
