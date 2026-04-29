; wordlists.asm — Per-wordlist hash-table struct + canonical FORTH-WORDLIST
; AntForth — A Forth for CP/M on Z80
;
; Defines the 130-byte per-wordlist struct (E12-D1) and emits the kernel-
; resident FORTH-WORDLIST instance. Story 12.1 introduces the struct shape
; and parameterises dictionary lookup on a wordlist-struct address; the
; user-facing search-order words (WORDLIST, SEARCH-WORDLIST, FORTH-WORDLIST,
; GET-ORDER, SET-ORDER, …) arrive in Stories 12.2–12.5.
;
; Wordlist struct layout (architecture.md:326-330 — E12-D1):
;     +0   2 bytes   next-wordlist chain pointer (0 = end of chain)
;     +2 128 bytes   64 × 2-byte hash-bucket array
; Total = 130 bytes (= WORDLIST_SIZE).
;
; A wordlist identifier (`wid`, E12-D3) is the raw address of this struct.
; Dictionary lookup primitives load the bucket-head address as
; `wid + WORDLIST_BUCKET0` (i.e., struct base + 2). The legacy global
; `hash_table` symbol is retired in this story; every call site now
; addresses the bucket array via `forth_wordlist + WORDLIST_BUCKET0`.

; === Layout EQUs ===
WORDLIST_SIZE       EQU     130     ; architecture.md:328 — E12-D1 (2-byte next link + 64×2-byte buckets)
WORDLIST_BUCKETS    EQU     64      ; architecture.md:328 — E12-D1; sole source of truth (HASH_BUCKETS retired Story 12.1 per AC #5(d)(i))
                                    ; Three sites duplicate this literal for sjasmplus-pass-ordering reasons:
                                    ;   src/macros.asm:9   `for i = 0, 63 do`     (LUA _hash_buckets[] init — runs before this EQU is defined)
                                    ;   src/macros.asm:54  `return h & 63`        (LUA forth_hash mask — same pass-ordering)
                                    ;   src/hash.asm:30    `AND 63`               (runtime hash_name mask)
                                    ; Assertion below catches any future drift.
    ASSERT WORDLIST_BUCKETS = 64
WORDLIST_NEXT       EQU     0       ; architecture.md:326-330 — offset of next-wordlist chain link
WORDLIST_BUCKET0    EQU     2       ; architecture.md:326-330 — offset of first hash-bucket entry (per-bucket stride is 2 bytes)

; === User-facing search-order words (Story 12.2) ===
; WORDLIST and SEARCH-WORDLIST are emitted INSIDE this file BEFORE the
; `forth_wordlist:` label so the DEFCODE macros' `_hash_buckets[]` updates
; (src/macros.asm:75-86, 109-117) run before the bucket array below reads
; the table. They are also emitted INSIDE the trailing INCLUDE in
; src/antforth.asm (line 205) so they land after all other DEFCODE/DEFWORDs
; — preserving Story 12.1's INCLUDE-order discipline (Finding F2).

; ANS Forth 1994 §16.6.1.2460   WORDLIST    ( -- wid )
;   Allocate a new 130-byte wordlist struct at HERE; zero-init all bytes
;   (next-link cell + 64-entry bucket array); advance HERE by 130; return
;   the struct base address as the wordlist identifier (wid).
w_WORDLIST:
        DEFCODE "WORDLIST", 0
w_WORDLIST_cf:
        PUSH    BC                      ; old TOS -> SP-stack (Forth 2nd-on-stack)
        PUSH    DE                      ; save IP — LDIR clobbers DE
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1) ; HL = HERE = base of new struct
        PUSH    HL                      ; preserve wid for return below saved IP
        LD      (HL), 0                 ; zero first byte
        LD      D, H
        LD      E, L
        INC     DE                      ; DE = HL + 1
        LD      BC, WORDLIST_SIZE - 1   ; 129
        LDIR                            ; cascade-zero remaining 129 bytes
                                        ; on exit DE = HL + WORDLIST_SIZE = HERE + 130
        LD      (IY+UserArea.here), E
        LD      (IY+UserArea.here+1), D ; HERE = old + 130
        POP     BC                      ; BC = wid (new TOS)
        POP     DE                      ; restore IP
        NEXT

; ANS Forth 1994 §16.6.1.2192   SEARCH-WORDLIST    ( c-addr u wid -- 0 | xt 1 | xt -1 )
;   Search the specified wordlist's 64-entry bucket array for a name match.
;   On miss return single 0 (depth shrinks 3 -> 1). On hit return xt and
;   either +1 (IMMEDIATE) or -1 (non-IMMEDIATE) (depth 3 -> 2).
;   Reuses the shared chain-walk helper `search_wid_for_name` factored out
;   of FIND in Story 12.2 (per AC #5 pick (a)).
;
;   `u` is operated on as an 8-bit length: only the low byte is passed to
;   the chain-walk helper (sw_search_len is a DB). Practical names are
;   <= F_LENMASK (31), so this is a non-issue in normal use; for u > 255
;   the high byte is discarded. AC #11(b) pick (ii) ("pass u unchanged")
;   is honoured within the 8-bit window — the chain compare still rejects
;   any low-byte length that doesn't match an entry's stored length-mask.
w_SEARCH_WORDLIST:
        DEFCODE "SEARCH-WORDLIST", 0
w_SEARCH_WORDLIST_cf:
        CALL    check_underflow_3       ; need 3 cells: c-addr, u, wid
        LD      (sw_saved_ip), DE       ; save IP — DE is needed for wid
        LD      D, B
        LD      E, C                    ; DE = wid
        POP     HL                      ; HL = u (length cell)
        LD      A, L                    ; A = u low byte (length)
        POP     HL                      ; HL = c-addr (name start)
        LD      B, A                    ; B = u (length passed unchanged per AC #11(b) pick (ii))
        CALL    search_wid_for_name
        ; Helper output: HL = xt and A = count_flags on hit (CF clear);
        ;                HL = 0 on miss (CF set).
        LD      DE, (sw_saved_ip)       ; restore IP regardless of outcome
        JR      C, .sw_miss
        ; Hit — push xt and set BC = +1 / -1 per IMMEDIATE flag
        PUSH    HL                      ; xt second-on-stack
        BIT     7, A                    ; F_IMMEDIATE
        JR      Z, .sw_nonimm
        LD      BC, 1                   ; flag = +1 (IMMEDIATE)
        NEXT
.sw_nonimm:
        LD      BC, 0xFFFF              ; flag = -1 (non-IMMEDIATE)
        NEXT
.sw_miss:
        LD      BC, 0                   ; miss flag = 0; depth shrunk to 1
        NEXT

sw_saved_ip:    DW      0               ; SEARCH-WORDLIST IP slot

; === Story 12.3 — search-order infrastructure ===
; FORTH-WORDLIST, GET-ORDER, SET-ORDER (and the do_search_order_overflow
; raise site) — all emitted BEFORE the forth_wordlist: label below so the
; DEFCODE macros' _hash_buckets[] updates run before the bucket array is
; emitted.

; ANS Forth 1994 §16.6.1.1595   FORTH-WORDLIST    ( -- wid )
;   Push the canonical Forth wordlist's struct address onto TOS.
w_FORTH_WORDLIST:
        DEFCODE "FORTH-WORDLIST", 0
w_FORTH_WORDLIST_cf:
        PUSH    BC                      ; old TOS -> SP-stack
        LD      BC, forth_wordlist      ; new TOS = canonical wid
        NEXT

; ANS Forth 1994 §16.6.1.1647   GET-ORDER    ( -- widn ... wid1 n )
;   Push the search-order wordlists onto the stack with slot 0
;   (top-of-search-order) deepest (= immediately below n).
;
;   Stack-direction discipline (Story 12.3 AC #18(a) trap): slot 0
;   is the FIRST wordlist consulted by FIND, so wid1 = slot 0 and
;   wid1 must end up adjacent to n. Algorithm: walk slots from
;   index `depth-1` down to `0`, pushing each wid; finally BC = depth.
w_GET_ORDER:
        DEFCODE "GET-ORDER", 0
w_GET_ORDER_cf:
        ; check_overflow: covers PUSH BC + ≤15-deep search order cleanly
        ; via the standard 32-byte margin. For depth=16 (34 bytes) the
        ; margin shrinks 2 bytes — practical impact zero in normal use.
        CALL    check_overflow
        LD      (srch_saved_ip), DE     ; save IP — DE used for pointer math
        PUSH    BC                      ; old TOS -> SP-stack
        LD      A, (IY+UserArea.search_order_depth)
        OR      A
        JR      Z, .go_done             ; depth = 0: only n=0 to push
        LD      C, A                    ; C = loop counter (depth)
        ; HL = IY + UserArea.search_order + 2*(depth-1)
        ;    = IY + (UserArea.search_order - 2) + 2*depth
        PUSH    IY
        POP     HL
        LD      D, 0
        LD      E, A
        ADD     HL, DE
        ADD     HL, DE                  ; HL += 2*depth
        LD      DE, UserArea.search_order - 2
        ADD     HL, DE                  ; HL = &slot[depth-1] (low byte)
.go_loop:
        LD      E, (HL)
        INC     HL
        LD      D, (HL)                 ; DE = wid at slot[i]
        PUSH    DE                      ; push wid to SP-stack
        DEC     HL
        DEC     HL
        DEC     HL                      ; HL -= 3 → &slot[i-1] low byte
        DEC     C
        JR      NZ, .go_loop
.go_done:
        LD      C, A                    ; new TOS = depth
        LD      B, 0
        LD      DE, (srch_saved_ip)     ; restore IP
        NEXT

; ANS Forth 1994 §16.6.1.2195   SET-ORDER    ( widn ... wid1 n -- )
;   Replace the search order with the n wids from the stack.
;   Special case n = -1: install the implementation-defined minimum
;   search order (FORTH-WORDLIST at slot 0, depth 1).
;   n > 16 OR n < -1 raises THROW_SEARCH_ORDER_OVERFLOW (-49)
;   per ANS §9.3.5.
w_SET_ORDER:
        DEFCODE "SET-ORDER", 0
w_SET_ORDER_cf:
        CALL    check_underflow         ; n on TOS (BC) — 1-cell guard
        LD      (srch_saved_ip), DE     ; save IP — DE used for math
        ; Test sign of n.
        LD      A, B
        AND     A
        JP      P, .so_nonneg
        ; n is negative. n = -1 ⟺ BC = 0xFFFF.
        LD      A, B
        AND     C
        INC     A                       ; Z iff (B AND C) = 0xFF iff B=C=0xFF
        JP      NZ, do_search_order_overflow
        ; n = -1: install implementation-defined minimum search order.
        LD      HL, forth_wordlist
        LD      (IY+UserArea.search_order),   L
        LD      (IY+UserArea.search_order+1), H
        LD      (IY+UserArea.search_order_depth),   1
        LD      (IY+UserArea.search_order_depth+1), 0
        POP     BC                      ; new TOS = cell below the consumed n
        LD      DE, (srch_saved_ip)     ; restore IP
        NEXT
.so_nonneg:
        ; n >= 0. Bound: n ≤ 16.
        LD      A, B
        OR      A
        JP      NZ, do_search_order_overflow   ; n >= 256
        LD      A, C
        CP      17
        JP      NC, do_search_order_overflow   ; n >= 17
        ; n in 0..16. Verify n more cells on SP-stack (variable underflow).
        ; Need sp_base - SP >= 2*n bytes below current SP for the n wids.
        LD      H, 0
        LD      L, A                    ; HL = n
        ADD     HL, HL                  ; HL = 2*n (max 32)
        EX      DE, HL                  ; DE = 2*n
        LD      HL, (sp_base)
        OR      A
        SBC     HL, SP                  ; HL = sp_base - SP (bytes below SP)
        SBC     HL, DE                  ; HL = bytes_below_SP - 2*n
        JP      C, do_underflow_error   ; insufficient cells below SP
        ; All checks passed. Set depth = n.
        LD      A, C
        LD      (IY+UserArea.search_order_depth),   A
        LD      (IY+UserArea.search_order_depth+1), 0
        OR      A
        JR      Z, .so_done             ; n = 0: empty search order, skip pop loop
        ; Pop n wids; first pop = wid1 → slot[0]; last = widn → slot[n-1].
        LD      B, A                    ; B = n (DJNZ counter)
        PUSH    IY
        POP     HL
        LD      DE, UserArea.search_order
        ADD     HL, DE                  ; HL = &slot[0]
.so_loop:
        POP     DE                      ; DE = wid (LIFO: wid1 first)
        LD      (HL), E
        INC     HL
        LD      (HL), D
        INC     HL                      ; HL = &slot[i+1]
        DJNZ    .so_loop
.so_done:
        POP     BC                      ; new TOS = cell below the consumed wids
        LD      DE, (srch_saved_ip)     ; restore IP
        NEXT

; ANS Forth 1994 §9.3.5   THROW -49 raise site for SET-ORDER bounds checks.
; Mirrors do_overflow_error / do_underflow_error idiom (Story 11.5.2).
do_search_order_overflow:
        LD      BC, THROW_SEARCH_ORDER_OVERFLOW
        JP      w_THROW_cf.kernel_entry

srch_saved_ip:  DW      0               ; shared IP slot for GET-ORDER / SET-ORDER

; === FORTH-WORDLIST struct (kernel-resident, canonical) ===
; The bucket array is populated at assembly time by the LUA `_hash_buckets`
; table (src/macros.asm:7-12), which DEFCODE / DEFWORD update via
; `_hash_buckets[bucket] = sj.get_label(".dict_entry")` (src/macros.asm:75-86,
; 109-117). For the LUA expansion below to read populated buckets, this
; struct MUST be emitted AFTER all DEFCODE/DEFWORD invocations have run —
; i.e., this file must be INCLUDEd from src/antforth.asm AFTER bootstrap.asm
; (the last code-include). Emitting earlier would emit zeros.
forth_wordlist:
        DW      0                       ; WORDLIST_NEXT — chain end (FORTH-WORDLIST is canonical)
    LUA ALLPASS
        local n = sj.calc("WORDLIST_BUCKETS")
        for i = 0, n - 1 do
            _pc(string.format("DW 0x%04X", _hash_buckets[i]))
        end
    ENDLUA
