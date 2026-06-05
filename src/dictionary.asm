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
; Search the current search order (slot 0 down) for the counted-string
; name at c-addr. Story 12.3 — walks UserArea.search_order[0..depth-1],
; calling the shared helper `search_wid_for_name` once per wid; returns
; on the first hit. On full miss returns ( c-addr 0 ) per the existing
; ANS contract.
w_FIND:
        DEFCODE "FIND", 0
w_FIND_cf:
        PUSH    DE              ; save IP
        PUSH    BC              ; save c-addr (for miss case)
        ; Parse counted-string input: HL = c-addr → name addr + length.
        LD      H, B
        LD      L, C
        LD      A, (HL)         ; A = count_flags byte
        AND     F_LENMASK       ; mask off any flags (counted-string discipline)
        INC     HL              ; HL = name address
        LD      B, A            ; B = name length
        ; Save name addr + length so each helper call can re-load them
        ; (the helper clobbers BC, HL).
        LD      (find_search_name), HL
        LD      A, B
        LD      (find_search_len), A
        ; Load search-order depth; depth = 0 = pure miss (no walk).
        LD      A, (IY+UserArea.search_order_depth)
        OR      A
        JR      Z, .find_not_found
        LD      C, A            ; C = remaining slots to walk
        ; HL = &slot[0] = IY + UserArea.search_order
        PUSH    IY
        POP     HL
        LD      DE, UserArea.search_order
        ADD     HL, DE
        LD      (find_slot_ptr), HL
.find_walk:
        ; DE = wid at current slot.
        LD      HL, (find_slot_ptr)
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        INC     HL
        LD      (find_slot_ptr), HL     ; advance to next slot
        ; Re-load name addr (HL) + length (B) for the helper.
        LD      HL, (find_search_name)
        LD      A, (find_search_len)
        LD      B, A
        ; Save loop counter (C) — helper clobbers BC.
        PUSH    BC
        CALL    search_wid_for_name
        POP     BC                       ; restore loop counter (flags preserved)
        JR      NC, .find_hit            ; helper CF clear = hit
        DEC     C
        JR      NZ, .find_walk
        ; All slots exhausted → miss.
        JR      .find_not_found
.find_hit:
        ; HL = xt; A = count_flags. Format ( xt 1 | xt -1 ).
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
        ; Match — HL points past the name. Story 19.2 (Q1-α): runtime-built
        ; entries (every build_header consumer: `:`, CREATE, CONSTANT,
        ; MARKER, CODE, LABEL) carry a 2-byte stub-xt cell between name and
        ; CFA, flagged by F_HAS_STUB_XT_CELL in count_flags. Kernel-assembled
        ; DEFCODE/DEFWORD/DEFIMMED entries keep the legacy post-name = CFA
        ; layout (no cell, flag clear). Discriminate on the flag:
        ;   - flag set: read 2-byte cell at HL → HL = xt. Bank-0 / Phase-1/2/3
        ;     entries' cell holds the CFA address (initial-fill from
        ;     build_header → FIND returns CFA; the folded EXECUTE's
        ;     JP (HL) executes it directly — Story 19.5.2); bank-N>0
        ;     colon entries' cell holds the descriptor-stub address
        ;     (overwritten by w_SEMICOLON_cf → FIND returns stub-xt; the
        ;     stub self-dispatches via RST $28 / stub_dispatch per
        ;     PD-P4-1 / FR-P4-13 / FR-P4-17 / ADR 19.5 DR-2).
        ;   - flag clear: HL is post-name = CFA directly (legacy layout).
        ; architecture.md:200..211 + 347..363; redesign §2.1.
        LD      A, (sw_match_cf)
        AND     F_HAS_STUB_XT_CELL
        JR      Z, .sw_match_legacy
        ; flag set: extract xt from 2-byte cell
        LD      A, (HL)                 ; cell.lo
        INC     HL
        LD      H, (HL)
        LD      L, A                    ; HL = cell value = xt
.sw_match_legacy:
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

; FIND scratch — saved across the search-order walk (CODE words don't
; reentrantly nest, so a single set is safe).
find_search_name:   DW      0
find_search_len:    DB      0
find_slot_ptr:      DW      0

; -----------------------------------------------
; WORDS ( -- )
;   List all words in the dictionary by traversing all 64 hash buckets
;   of FORTH-WORDLIST. Story 12.3 AC #10 + Story 12.4 AC #9 picked option
;   (a) — keep WORDS scoped to FORTH-WORDLIST. ANS does not standardise
;   WORDS across wordlists. With SET-CURRENT (Story 12.4) live, a user
;   can place definitions into non-FORTH-WORDLIST wordlists; those words
;   are NOT visible to WORDS. Workaround: dump the bucket array of the
;   target wordlist by hand. Revisit if MicroBeast hardware wordlists
;   land in Phase 3.
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
