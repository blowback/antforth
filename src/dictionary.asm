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
; name at c-addr. Walks UserArea.search_order[0..depth-1],
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
; Shared by FIND (passing forth_wordlist), SEARCH-WORDLIST (passing the
; user-supplied wid), and the per-wid search-order walk.
;
; Input:  HL = name address (raw characters, NOT counted)
;         B  = name length (passed unchanged; chain compare rejects entries
;              whose stored length-mask doesn't match B, so u > 31 yields
;              a pure miss without crashing)
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
        ; Compute &bucket = wid + WORDLIST_BUCKET0 + 3*A (fat-bucket stride).
        LD      L, A
        LD      H, 0
        LD      C, A
        LD      B, 0                    ; BC = bucket
        ADD     HL, HL                  ; HL = 2 * bucket
        ADD     HL, BC                  ; HL = 3 * bucket
        INC     HL
        INC     HL                      ; HL = WORDLIST_BUCKET0 + 3 * bucket
        ADD     HL, DE                  ; HL = &wid.buckets[bucket]
        ; Reset per-walk slot-2 switch state, then deref the fat head INLINE:
        ; HL = first entry addr; page the entry's bank into slot 2 only if it
        ; is window-resident. Inlined (not CALLed) so the per-entry hot path
        ; carries no call/return overhead — the everyday fixed-entry walk hits
        ; no subroutine and does no MMU work.
        XOR     A
        LD      (sw_switched), A
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        INC     HL
        LD      A, (HL)                 ; A = bank; DE = entry addr
        EX      DE, HL                  ; HL = entry addr
        BIT     7, H
        JR      Z, .sw_head_fixed       ; addr < $8000 -> fixed, no MMU switch
        BIT     6, H
        JR      NZ, .sw_head_fixed      ; addr >= $C000 -> fixed
        CALL    sw_map_bank             ; window-resident -> page bank in (A=bank; HL preserved)
.sw_head_fixed:

.sw_chain:
        LD      A, H
        OR      L
        JR      Z, .sw_miss             ; end of chain
        PUSH    HL                      ; save entry-start (= &fat hash_link)
        INC     HL
        INC     HL
        INC     HL                      ; HL = &count_flags (past 3-byte fat link)
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
        ; Match — HL points past the name. Runtime-built entries (every
        ; build_header consumer: `:`, CREATE, CONSTANT, MARKER, CODE,
        ; LABEL) carry a 2-byte stub-xt cell between name and CFA, flagged
        ; by F_HAS_STUB_XT_CELL in count_flags. Kernel-assembled
        ; DEFCODE/DEFWORD/DEFIMMED entries keep the legacy post-name = CFA
        ; layout (no cell, flag clear). Discriminate on the flag:
        ;   - flag set: read 2-byte cell at HL → HL = xt. Bank-0 entries'
        ;     cell holds the CFA address (initial-fill from build_header →
        ;     FIND returns CFA; the folded EXECUTE's JP (HL) executes it
        ;     directly); bank-N>0 colon entries' cell holds the
        ;     descriptor-stub address (overwritten by w_SEMICOLON_cf →
        ;     FIND returns stub-xt; the stub self-dispatches via RST $28 /
        ;     stub_dispatch).
        ;   - flag clear: HL is post-name = CFA directly (legacy layout).
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
        CALL    sw_restore_slot2        ; undo any head/link page-in (preserves HL = xt)
        LD      A, (sw_match_cf)        ; A = count_flags
        OR      A                       ; clear CF (NC = hit)
        RET

.sw_skip:
        POP     HL                      ; restore entry-start (= &fat hash_link)
        ; inline fat-link deref (page-in only if window-resident)
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        INC     HL
        LD      A, (HL)                 ; A = bank; DE = next entry addr
        EX      DE, HL                  ; HL = next entry addr
        BIT     7, H
        JR      Z, .sw_skip_fixed
        BIT     6, H
        JR      NZ, .sw_skip_fixed
        CALL    sw_map_bank
.sw_skip_fixed:
        JR      .sw_chain

.sw_miss:
        CALL    sw_restore_slot2        ; undo any head/link page-in
        XOR     A                       ; A = 0
        LD      H, A
        LD      L, A                    ; HL = 0
        SCF                             ; CF set = miss
        RET

; The fat-pointer deref (read [addr:2][bank:1] + conditional page-in) is
; inlined at its two hot-path sites above (.sw_head_fixed / .sw_skip_fixed)
; so the per-entry walk carries no call/return overhead. Only the rare
; window-resident case calls the helper below.

; sw_map_bank: A = logical bank -> map active_pages[bank] into slot 2.
;   On the first call of a walk, saves the caller's slot-2 page so the exit
;   path can restore it. Preserves DE and HL; clobbers A.
sw_map_bank:
        PUSH    HL
        PUSH    DE
        PUSH    AF                      ; save bank
        LD      A, (sw_switched)
        OR      A
        JR      NZ, .smb_mapped         ; already switched -> name already copied
        ; First switch of this walk: save the caller's page, then snapshot
        ; the search name into fixed scratch BEFORE we unmap slot 2 — the
        ; name may itself live in the window we are about to page away (it
        ; was parsed at an in-bank HERE). Lazy: the fast path (no page-in)
        ; never reaches here, so all-fixed lookups copy nothing.
        CALL    mbb_get_slot2           ; A = caller's slot-2 page
        LD      (sw_saved_page), A
        LD      A, 1
        LD      (sw_switched), A
        LD      A, (sw_search_len)      ; clamp to 31 (max stored name length;
        CP      32                      ; a longer name can never match, so a
        JR      C, .smb_clamp           ; truncated copy is compare-irrelevant)
        LD      A, 31
.smb_clamp:
        OR      A
        JR      Z, .smb_repoint         ; zero length — nothing to copy
        LD      C, A
        LD      B, 0
        LD      HL, (sw_search_name)    ; src = original name (still mapped)
        LD      DE, sw_name_buf         ; dst = fixed scratch
        LDIR
.smb_repoint:
        LD      HL, sw_name_buf
        LD      (sw_search_name), HL    ; compares now read the fixed copy
.smb_mapped:
        POP     AF                      ; A = bank
        LD      HL, ACTIVE_PAGES_BASE
        LD      C, A
        LD      B, 0
        ADD     HL, BC                  ; &active_pages[bank]
        LD      A, (HL)                 ; A = physical page
        CALL    mbb_set_slot2
        POP     DE
        POP     HL
        RET

; sw_restore_slot2: if this walk paged slot 2, restore the caller's page.
;   Preserves HL (mbb_set_slot2 push/pops it); clobbers A/F (don't-care).
sw_restore_slot2:
        LD      A, (sw_switched)
        OR      A
        RET     Z
        XOR     A
        LD      (sw_switched), A
        LD      A, (sw_saved_page)
        JP      mbb_set_slot2

sw_search_len:  DB      0               ; saved name length
sw_search_name: DW      0               ; saved name address
sw_match_cf:    DB      0               ; count_flags of matched entry
sw_saved_page:  DB      0               ; caller's slot-2 page during a page-in
sw_switched:    DB      0               ; non-zero iff this walk paged slot 2
sw_name_buf:    DS      32              ; fixed-memory copy of the search name
                                        ; (snapshotted on first page-in, so a
                                        ;  window-resident name survives the swap)

; FIND scratch — saved across the search-order walk (CODE words don't
; reentrantly nest, so a single set is safe).
find_search_name:   DW      0
find_search_len:    DB      0
find_slot_ptr:      DW      0

; -----------------------------------------------
; WORDS ( -- )
;   List all words in the dictionary by traversing all 64 hash buckets
;   of FORTH-WORDLIST. WORDS is scoped to FORTH-WORDLIST; ANS does not
;   standardise WORDS across wordlists. With SET-CURRENT live, a user
;   can place definitions into non-FORTH-WORDLIST wordlists; those words
;   are NOT visible to WORDS. Workaround: dump the bucket array of the
;   target wordlist by hand.
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
        ; entry+3 = count_flags (past 3-byte fat hash_link)
        INC     DE
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
        INC     HL
        INC     HL              ; next bucket (fat-bucket stride = 3)
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
