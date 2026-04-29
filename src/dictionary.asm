; dictionary.asm — Dictionary lookup words
; AntForth — A Forth for CP/M on Z80
;
; Provides FIND and COUNT for dictionary operations.

; === COUNT ( c-addr -- c-addr+1 u ) ===
; Extract length from counted string, masking off flags
w_COUNT:
        DEFCODE "COUNT", 0
w_COUNT_cf:
        LD      A, (BC)         ; A = count/flags byte
        INC     BC              ; BC = c-addr+1 (name start)
        PUSH    BC              ; Push c-addr+1 (second on stack)
        AND     F_LENMASK       ; Mask off IMMEDIATE/SMUDGE flags
        LD      C, A
        LD      B, 0            ; BC = length (new TOS)
        NEXT

; === FIND ( c-addr -- c-addr 0 | xt 1 | xt -1 ) ===
; Search FORTH-WORDLIST for the counted-string name at c-addr.
; Wraps the shared helper `search_wid_for_name` (Story 12.2 AC #5 pick (a))
; with FIND's counted-string input adapter and `c-addr 0` miss shape.
w_FIND:
        DEFCODE "FIND", 0
w_FIND_cf:
        PUSH    DE              ; save IP
        PUSH    BC              ; save c-addr (for miss case)
        ; HL = c-addr; load count byte; advance to name; mask length.
        LD      H, B
        LD      L, C
        LD      A, (HL)         ; A = count_flags byte
        AND     F_LENMASK       ; mask off any flags (FIND parses counted strings)
        INC     HL              ; HL = name address
        LD      B, A            ; B = name length
        LD      DE, forth_wordlist
        CALL    search_wid_for_name
        ; Helper: HL = xt + A = count_flags + NC on hit; HL = 0 + CF on miss.
        JR      C, .find_not_found
        ; Hit — drop saved c-addr; restore IP; push xt; format flag from A.
        POP     BC              ; discard saved c-addr
        POP     DE              ; restore IP
        PUSH    HL              ; xt second-on-stack
        BIT     7, A            ; F_IMMEDIATE
        JR      Z, .find_non_immediate
        LD      BC, 1           ; +1 IMMEDIATE
        NEXT
.find_non_immediate:
        LD      BC, 0xFFFF      ; -1 non-IMMEDIATE
        NEXT
.find_not_found:
        ; Miss — restore c-addr (second-on-stack) and IP; flag = 0.
        POP     BC              ; BC = original c-addr
        POP     DE              ; restore IP
        PUSH    BC              ; c-addr second-on-stack
        LD      BC, 0           ; flag = 0
        NEXT

; -----------------------------------------------
; search_wid_for_name — Walk a single wordlist's bucket chain for a name match.
; Story 12.2 — shared by FIND (passing forth_wordlist) and SEARCH-WORDLIST
; (passing the user-supplied wid). Designed-up-front to also serve Story
; 12.3's per-wid search-order walk (per `feedback_design_upfront.md`).
;
; Input:  HL = name address (raw characters, NOT counted)
;         B  = name length (passed unchanged; chain compare rejects entries
;              whose stored length-mask doesn't match B, so u > 31 yields
;              a pure miss without crashing — AC #11(b) pick (ii))
;         DE = wid (wordlist struct base address)
; Output: On HIT:  HL = xt (code field address);
;                  A  = count_flags byte of matched entry (caller checks F_IMMEDIATE);
;                  CF clear (NC).
;         On MISS: HL = 0;
;                  A  = 0;
;                  CF set.
; Clobbers: AF, BC, DE, HL
; Preserves: IX, IY, SP
; -----------------------------------------------
search_wid_for_name:
        LD      A, B
        LD      (sw_search_len), A      ; save length for chain-compare
        LD      (sw_search_name), HL    ; save name addr for chain-compare
        ; hash_name takes HL = name, B = length; returns A = bucket (0-63).
        CALL    hash_name
        ; Compute &bucket = wid + WORDLIST_BUCKET0 + 2*A.
        LD      L, A
        LD      H, 0
        ADD     HL, HL                  ; HL = 2 * bucket
        INC     HL
        INC     HL                      ; HL = WORDLIST_BUCKET0 + 2 * bucket
        ADD     HL, DE                  ; HL = &wid.buckets[bucket]
        ; Load chain head pointer.
        LD      A, (HL)
        INC     HL
        LD      H, (HL)
        LD      L, A                    ; HL = first entry (or 0)

.sw_chain:
        LD      A, H
        OR      L
        JR      Z, .sw_miss             ; end of chain
        PUSH    HL                      ; save entry-start
        INC     HL
        INC     HL                      ; HL = &count_flags
        LD      A, (HL)
        LD      (sw_match_cf), A        ; remember count_flags for caller
        BIT     6, A                    ; F_SMUDGE
        JR      NZ, .sw_skip
        AND     F_LENMASK
        LD      C, A                    ; C = entry length
        LD      A, (sw_search_len)
        CP      C
        JR      NZ, .sw_skip
        ; Lengths match — compare names case-insensitively.
        INC     HL                      ; HL = entry name start
        LD      DE, (sw_search_name)    ; DE = search name start
        LD      B, C                    ; B = length
.sw_compare:
        LD      A, (HL)
        UPPER
        LD      C, A
        LD      A, (DE)
        UPPER
        CP      C
        JR      NZ, .sw_skip
        INC     HL
        INC     DE
        DJNZ    .sw_compare
        ; Match — HL points past the name = code field address (xt).
        POP     DE                      ; discard saved entry-start (DE clobbered next)
        LD      A, (sw_match_cf)        ; A = count_flags
        OR      A                       ; clear CF (NC = hit)
        RET

.sw_skip:
        POP     HL                      ; restore entry-start
        LD      A, (HL)
        INC     HL
        LD      H, (HL)
        LD      L, A                    ; HL = next entry (or 0)
        JR      .sw_chain

.sw_miss:
        XOR     A                       ; A = 0
        LD      H, A
        LD      L, A                    ; HL = 0
        SCF                             ; CF set = miss
        RET

sw_search_len:  DB      0               ; saved name length
sw_search_name: DW      0               ; saved name address
sw_match_cf:    DB      0               ; count_flags of matched entry

; -----------------------------------------------
; WORDS ( -- )
;   List all words in the dictionary by traversing all 64 hash buckets
;   of FORTH-WORDLIST. (Epic 12 multi-wordlist support adds search-order
;   iteration in Story 12.3 — Story 12.1 walks FORTH-WORDLIST only.)
; -----------------------------------------------
w_WORDS:
        DEFCODE "WORDS", 0
w_WORDS_cf:
        ; Save DE (IP) — we'll use all registers as scratch
        LD      (words_saved_ip), DE
        PUSH    BC              ; save TOS

        LD      HL, forth_wordlist + WORDLIST_BUCKET0
        LD      A, WORDLIST_BUCKETS     ; 64
.words_bucket:
        LD      (words_bucket_count), A
        LD      (words_bucket_ptr), HL
        ; Load bucket head
        LD      E, (HL)
        INC     HL
        LD      D, (HL)         ; DE = chain head

.words_chain:
        LD      A, D
        OR      E
        JR      Z, .words_next_bucket   ; end of chain

        ; DE = entry address
        LD      (words_entry), DE
        ; entry+2 = count_flags
        INC     DE
        INC     DE
        LD      A, (DE)         ; A = count_flags

        ; Skip smudged entries
        BIT     6, A            ; F_SMUDGE
        JR      NZ, .words_skip

        AND     F_LENMASK       ; A = name length
        INC     DE              ; DE = first name char
        LD      B, A            ; B = char count
        OR      A
        JR      Z, .words_skip  ; zero length, skip

        ; Print B characters starting at DE
.words_print:
        PUSH    BC
        PUSH    DE
        LD      A, (DE)
        LD      E, A
        CALL    bdos_putchar
        POP     DE
        POP     BC
        INC     DE
        DJNZ    .words_print

        ; Print a space
        PUSH    DE
        LD      E, ' '
        CALL    bdos_putchar
        POP     DE

.words_skip:
        ; Follow hash_link: entry+0,1
        LD      HL, (words_entry)
        LD      E, (HL)
        INC     HL
        LD      D, (HL)         ; DE = next entry
        JR      .words_chain

.words_next_bucket:
        LD      HL, (words_bucket_ptr)
        INC     HL
        INC     HL              ; next bucket
        LD      A, (words_bucket_count)
        DEC     A
        JR      NZ, .words_bucket

        ; Print CR/LF
        CALL    bdos_crlf

        ; Restore TOS and IP
        POP     BC
        LD      DE, (words_saved_ip)
        NEXT

; WORDS scratch storage
words_saved_ip:     DW 0
words_bucket_count: DB 0
words_bucket_ptr:   DW 0
words_entry:        DW 0
