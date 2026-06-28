; compiler.asm — Colon compiler words (:, ;, [, ], LITERAL, CREATE, CONSTANT, DOES>)
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; >BODY ( xt -- a-addr )
;   Given xt (code field address of a CREATE'd word), return body address
;   CREATE layout: [JP DOVAR (3 bytes)][does-addr (2 bytes)][body...]
;   So body = xt + 5
; -----------------------------------------------
w_TO_BODY:
        DEFCODE ">BODY", 0
w_TO_BODY_cf:
        INC     BC              ; +1
        INC     BC              ; +2
        INC     BC              ; +3
        INC     BC              ; +4
        INC     BC              ; +5
        NEXT

; -----------------------------------------------
; ' (tick) ( "<spaces>name" -- xt )
;   Parse next word, find it, return its execution token
;   Error if word not found: prints "<NAME> ?" + CR then raises
;   -13 THROW per ANS Forth 1994 §9.3.5. The dynamic
;   word-name print is preserved so the user sees which name failed;
;   the THROW code is then dispatched to CATCH (caught) or to the
;   uncaught-handler's "error -13: undefined word" diagnostic.
; -----------------------------------------------
w_TICK:
        DEFWORD "'", 0
w_TICK_body:
w_TICK_cf EQU w_TICK_body - 3
        DW w_BL_cf                   ; ( -- 32 )
        DW w_WORD_cf                 ; ( 32 -- c-addr )
        DW w_FIND_cf                 ; ( c-addr -- c-addr 0 | xt 1 | xt -1 )
        DW w_DUP_cf                  ; ( ... flag flag )
        DW w_QBRANCH_cf              ; if flag=0, not found
        DW .tick_notfound - $
        ; Found: ( xt flag ) — drop flag, keep xt
        DW w_DROP_cf                 ; ( xt )
        DW EXIT_CODE
.tick_notfound:
        ; ( c-addr 0 ) — word not found
        DW w_DROP_cf                 ; drop 0, leaving c-addr
        DW w_COUNT_cf                ; ( c-addr -- addr len )
        DW w_TYPE_cf                 ; print the unknown word
        DW w_LIT_cf, ' '
        DW w_EMIT_cf                 ; space
        DW w_LIT_cf, '?'
        DW w_EMIT_cf                 ; question mark
        DW w_CR_cf                   ; newline
        ; -13 THROW: undefined word per ANS Forth 1994 §9.3.5
        DW w_LIT_cf, THROW_UNDEFINED_WORD
        DW w_THROW_cf

; -----------------------------------------------
; ['] ( "<spaces>name" -- ) compile: ( -- xt )
;   Compile-time: parse name, find xt, compile as literal
; -----------------------------------------------
w_BRACKET_TICK:
        DEFIMMED "[']"
w_BRACKET_TICK_body:
w_BRACKET_TICK_cf EQU w_BRACKET_TICK_body - 3
        DW w_TICK_cf                 ; ( -- xt ) parse and find word
        DW w_LITERAL_cf              ; compile xt as inline literal
        DW EXIT_CODE

; -----------------------------------------------
; [CHAR] ( "<spaces>name" -- ) compile: ( -- char )
;   Compile-time: parse name, get first char, compile as literal
; -----------------------------------------------
w_BRACKET_CHAR:
        DEFIMMED "[CHAR]"
w_BRACKET_CHAR_body:
w_BRACKET_CHAR_cf EQU w_BRACKET_CHAR_body - 3
        DW w_CHAR_cf                 ; ( -- char ) parse and get first char
        DW w_LITERAL_cf              ; compile char as inline literal
        DW EXIT_CODE

; === Shared header-building scratch variables ===
bh_name_start:       DW 0   ; Pointer to name in TIB
bh_name_len:         DB 0   ; Clamped name length
bh_bucket_index:     DB 0   ; Hash bucket index (0-63)
bh_bucket_addr:      DW 0   ; Address in current wordlist's bucket array
bh_entry_start:      DW 0   ; HERE at entry (entry start address)
bh_old_bucket_head:  DW 0   ; Previous bucket head addr (for error recovery)
bh_old_bucket_bank:  DB 0   ; Previous bucket head bank (fat-pointer byte)
bh_count_flags_addr: DW 0   ; Address of count_flags byte (for unsmudging)
bh_flags:            DB 0   ; Flags to OR into count_flags
bh_code_field:       DW 0   ; Code field position (saved for return)
bh_wid:              DW 0   ; Wid used for header insertion (for error recovery)
bh_stub_xt_addr:     DW 0   ; Address of the 2-byte stub-xt cell
                            ; inserted between name and CFA. build_header initial-fills
                            ; with the CFA address (so FIND extraction returns CFA for
                            ; legacy bank-0 / Phase-1/2/3 entries unchanged);
                            ; w_SEMICOLON_cf overwrites for bank-N>0 colon definitions
                            ; with the descriptor-stub address.

; Fixed-memory scratch read by w_IMMEDIATE_cf so the
; IMMEDIATE bit lands on the right count_flags byte even after w_SEMICOLON_cf
; has overwritten LATEST with a stub-xt (bank-N>0 path). Mirror-written at
; the tail of every successful build_header (covers `:`, CREATE, CONSTANT,
; MARKER, CODE, LABEL).
;
; The assembly-time initial value points at a
; sentinel sink so IMMEDIATE invoked before any build_header consumer has
; run no-ops on the sink instead of writing F_IMMEDIATE into the CP/M
; zero-page (the DW 0 form wrote the bit into $0002 = BDOS dispatch).
; IMMEDIATE walking LATEST (= 0 at COLD) would hit the same
; $0002 corruption; the sink + assembly-time init closes that latent
; degenerate-input bug as well.
latest_count_flags_addr: DW latest_count_flags_sink
latest_count_flags_sink: DB 0

; === COLON error recovery variables ===
; (Used by SEMICOLON and COMP-ERROR — populated from bh_* after build_header)
colon_saved_here:    DW 0
colon_smudge_addr:   DW 0
colon_saved_bucket:  DB 0
colon_saved_head:    DW 0
colon_saved_bank:    DB 0   ; Fat bank byte of the saved head (for restore)
colon_saved_wid:     DW 0   ; Wid the colon header was inserted into
colon_saved_xt_cell: DW 0   ; bh_stub_xt_addr snapshot for SEMICOLON
                            ; to overwrite the cell with the descriptor-stub address
                            ; on the bank-N>0 path (intervening build_header calls
                            ; would otherwise clobber bh_stub_xt_addr).

; -----------------------------------------------
; build_header — Shared subroutine for :, CREATE, CONSTANT
;   Parse name from TIB, build dictionary header at HERE,
;   update hash bucket and LATEST.
;   Input:  A = flags to OR into count_flags (e.g. F_SMUDGE)
;   Output: CF=0 success, HL = code field position
;           CF=1 error (no name found)
;   Clobbers: A, BC, DE, HL, flags
; -----------------------------------------------
build_header:
        LD      (bh_flags), A

        ; Save current HERE as entry start
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (bh_entry_start), HL

        ; --- Parse next word from input ---
        LD      E, (IY+UserArea.tib_addr)
        LD      D, (IY+UserArea.tib_addr+1)    ; DE = tib_addr
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)      ; HL = >IN
        ADD     HL, DE                          ; HL = tib_addr + >IN

        ; Compute remaining = tib_len - >IN
        LD      E, (IY+UserArea.tib_len)
        LD      D, (IY+UserArea.tib_len+1)     ; DE = tib_len
        LD      A, (IY+UserArea.tib_in)
        LD      C, A
        LD      A, (IY+UserArea.tib_in+1)
        LD      B, A                            ; BC = >IN
        EX      DE, HL                          ; DE = parse pos, HL = tib_len
        OR      A
        SBC     HL, BC                          ; HL = remaining
        LD      B, H
        LD      C, L                            ; BC = remaining
        EX      DE, HL                          ; HL = parse pos

        ; Skip leading spaces
.bh_skip:
        LD      A, B
        OR      C
        JR      Z, .bh_no_name                 ; No chars left
        LD      A, (HL)
        CP      ' '
        JR      NZ, .bh_found_name
        INC     HL
        DEC     BC
        PUSH    HL
        PUSH    BC
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     BC
        POP     HL
        JR      .bh_skip

.bh_no_name:
        SCF                                     ; Set carry = error
        RET

.bh_found_name:
        LD      (bh_name_start), HL

        ; Scan for end of name
        LD      D, 0                            ; D = name length counter
.bh_scan:
        LD      A, B
        OR      C
        JR      Z, .bh_scan_done
        LD      A, (HL)
        CP      ' '
        JR      Z, .bh_scan_delim
        INC     HL
        DEC     BC
        INC     D
        PUSH    HL
        PUSH    BC
        PUSH    DE
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     DE
        POP     BC
        POP     HL
        JR      .bh_scan

.bh_scan_delim:
        PUSH    HL
        PUSH    DE
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     DE
        POP     HL

.bh_scan_done:
        ; D = name length — clamp to F_LENMASK (31) max
        LD      A, D
        CP      F_LENMASK + 1
        JR      C, .bh_len_ok
        LD      A, F_LENMASK
.bh_len_ok:
        LD      (bh_name_len), A

        ; --- Story 23.6: banked dictionary window-top overflow guard ---
        ; Refuse a defining word whose header + worst-case fixed code field
        ; would place any byte at/past the slot-2 window top ($C000). A = the
        ; clamped name_len here. prospective one-past-end =
        ;   HERE + header_overhead(6) + name_len + DOER_RESERVE(5)
        ; header_overhead = 3 (fat hash_link) + 1 (count_flags) + 2 (bank-N
        ; stub-xt cell). DOER_RESERVE = 5 = the largest fixed code field among
        ; the doers: CREATE/CONSTANT/VALUE each emit JP doer (3) + 2-byte body;
        ; `:` emits JP DOCOL (3) and grows its body later under the COMPILE,/,
        ; guard, so 5 is conservative-safe for it. check_banked_headroom no-ops
        ; on bank 0. This runs BEFORE the first dictionary write (the hash_link
        ; emit below), so the -8 THROW leaves HERE/LATEST/bucket untouched.
        ; build_header runs in the EXX shadow set (every caller EXX's at entry),
        ; so EXX-restore to primary before the THROW per the kernel-internal
        ; THROW contract (src/exception.asm:288-296).
        LD      HL, (bh_entry_start)            ; HERE at entry (nothing written yet)
        ADD     A, 6 + 5                        ; A = name_len + header_overhead + DOER_RESERVE
        LD      C, A                            ; name_len <= 31 → A <= 42, no carry
        LD      B, 0
        ADD     HL, BC                          ; HL = prospective one-past-end
        CALL    check_banked_headroom
        JR      NC, .bh_headroom_ok
        EXX                                     ; shadow → primary for THROW contract
        JP      dict_overflow_throw
.bh_headroom_ok:
        LD      A, (bh_name_len)                ; restore A = name_len for the hash

        ; --- Hash the name ---
        LD      HL, (bh_name_start)
        LD      B, A                            ; B = name length
        CALL    hash_name                       ; A = bucket index
        LD      (bh_bucket_index), A

        ; Compute bucket head address: current_wordlist bucket array + A*3
        ; (fat-bucket stride = WORDLIST_BUCKET_STRIDE = 3; [addr:2][bank:1])
        ; The bucket array lives in (IY+UserArea.current_wordlist),
        ; not in forth_wordlist directly. Capture the wid into bh_wid for
        ; the error-recovery paths (w_COMP_ERROR_cf, asm_cleanup,
        ; asm_unlink_labels) to read from colon_saved_wid / asm_saved_wid.
        ; Lifecycle invariant: bh_wid is written ONLY on the success path
        ; below this point; the .bh_no_name early-exit returns CF=1
        ; without touching bh_wid. Callers that consume bh_wid (colon /
        ; CODE / MARKER prologues) MUST first test the carry flag and skip
        ; the bh_wid read on error — otherwise they read a stale wid from
        ; a previous successful build_header invocation.
        LD      L, A
        LD      H, 0                            ; HL = bucket
        LD      E, A
        LD      D, 0                            ; DE = bucket
        ADD     HL, HL                          ; HL = 2*bucket
        ADD     HL, DE                          ; HL = 3*bucket (fat-bucket stride)
        LD      C, (IY+UserArea.current_wordlist)
        LD      B, (IY+UserArea.current_wordlist+1)
        LD      (bh_wid), BC                    ; capture wid
        INC     BC
        INC     BC                              ; BC = wid + WORDLIST_BUCKET0
        ADD     HL, BC                          ; HL = &<current_wordlist>.buckets[bucket]
        LD      (bh_bucket_addr), HL
        ; Read current fat bucket head: [addr:2][bank:1]
        LD      C, (HL)
        INC     HL
        LD      B, (HL)                         ; BC = current bucket head addr
        INC     HL
        LD      A, (HL)                         ; A = current bucket head bank
        LD      (bh_old_bucket_head), BC
        LD      (bh_old_bucket_bank), A

        ; --- Build dictionary entry at HERE ---
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)         ; HL = HERE

        ; Emit fat hash_link (3 bytes): [addr:2][bank:1] = old bucket head
        LD      (HL), C
        INC     HL
        LD      (HL), B
        INC     HL
        LD      A, (bh_old_bucket_bank)
        LD      (HL), A
        INC     HL

        ; Save count_flags address
        LD      (bh_count_flags_addr), HL

        ; Emit count_flags: flags | name_len
        LD      A, (bh_name_len)
        LD      B, A                             ; save name_len for copy loop
        LD      A, (bh_flags)
        OR      B                                ; A = flags | name_len
        LD      (HL), A
        INC     HL

        ; Copy name string from TIB
        LD      DE, (bh_name_start)
        LD      A, (bh_name_len)
        LD      B, A
.bh_copy_name:
        LD      A, (DE)
        LD      (HL), A
        INC     DE
        INC     HL
        DJNZ    .bh_copy_name

        ; --- bank-aware stub-xt cell reservation ---
        ; Bank-0 entries: legacy layout (HL = post-name = CFA; no cell, no
        ; flag). Preserves byte-identical bank-0 dispatch + protects
        ; iron-spike (tests/banking_tests.fth) which crosses the
        ; slot-1/slot-2 boundary at $8000 — extra cells per bank-0 entry
        ; would push iron-spike's body into bank-0's slot-2 and break it on
        ; `5 BANK!` mid-execution. Bank-N>0 entries: reserve 2-byte cell
        ; between name and CFA; set F_HAS_STUB_XT_CELL bit in count_flags;
        ; initial-fill the cell with the CFA address (overwritten by
        ; w_SEMICOLON_cf with descriptor-stub address; FIND
        ; discriminates on the flag at src/dictionary.asm).
        ; Keyed off triple_owner (the bank that OWNS the live HERE/LATEST/
        ; wordlist triple = the bank the entry physically lands in), not
        ; current_bank. The two coincide on every ordinary path but diverge
        ; whenever the live triple is keyed to a bank other than current_bank:
        ; (1) Story 22.3's CODE→fixed-memory redirect (triple swapped to bank
        ; 0 while current_bank stays on the user's bank); (2) a cross-bank
        ; dispatch window (stub_dispatch sets current_bank=target but does NOT
        ; swap the triple → triple_owner stays the caller's, per
        ; structures.asm). In both, the entry takes the layout of the bank it
        ; physically lands in = the triple owner.
        LD      A, (IY+UserArea.triple_owner)
        OR      A
        JR      Z, .bh_skip_cell                  ; bank-0: legacy layout
        ; bank-N>0: set F_HAS_STUB_XT_CELL flag in count_flags
        PUSH    HL                                ; save HL = post-name
        LD      HL, (bh_count_flags_addr)
        LD      A, (HL)
        OR      F_HAS_STUB_XT_CELL
        LD      (HL), A
        POP     HL                                ; HL = post-name = cell address
        LD      (bh_stub_xt_addr), HL
        INC     HL
        INC     HL                                ; HL = CFA position (post-cell)
        ; Write CFA address (HL) into the 2-byte cell at (bh_stub_xt_addr).
        ; Preserve DE — EXX'd callers (w_COLON_cf; CREATE; CONSTANT;
        ; CODE; MARKER; LABEL)
        ; hold IP in shadow-DE across the call; an EX DE,HL here would
        ; clobber that and the final caller-side EXX would restore garbage
        ; into main DE → NEXT crashes. Use A-via-load idiom to write cell.
        PUSH    HL                                ; save CFA address (return value)
        LD      A, L                              ; A = CFA.lo
        LD      HL, (bh_stub_xt_addr)             ; HL = cell address
        LD      (HL), A                           ; cell.lo = CFA.lo
        INC     HL
        POP     BC                                ; BC = saved CFA address (temp)
        LD      (HL), B                           ; cell.hi = CFA.hi
        LD      H, B
        LD      L, C                              ; HL = CFA address (restored)
.bh_skip_cell:
        ; HL = CFA position (post-name for bank-0; post-cell for bank-N>0)
        LD      (bh_code_field), HL               ; save CFA position for return

        ; --- latest_count_flags_addr mirror ---
        ; Mirror count_flags address so w_IMMEDIATE_cf reaches the right
        ; byte even after w_SEMICOLON_cf has overwritten LATEST with a
        ; stub-xt (bank-N>0 path). Always-mirror covers `:`, CREATE,
        ; CONSTANT, MARKER, CODE, LABEL — every build_header consumer in
        ; either bank-0 (LATEST = entry-start, +3 = count_flags past the
        ; 3-byte fat hash_link) or bank-N>0 (LATEST = stub-xt
        ; post-SEMICOLON, no longer +3 to count_flags).
        PUSH    HL
        LD      HL, (bh_count_flags_addr)
        LD      (latest_count_flags_addr), HL
        POP     HL                                ; restore HL = CFA address

        ; --- Update LATEST (always, regardless of bank) ---
        ; LATEST is per-bank state. Bank-0 keeps
        ; legacy semantics (LATEST = entry_start). The bank-N>0 callers in
        ; w_CREATE_cf / w_COLON_cf overwrite LATEST with the stub-xt after
        ; stub_allocate runs, so the value written here is just the
        ; bank-0 default that bank-N paths replace.
        LD      BC, (bh_entry_start)
        LD      (IY+UserArea.latest), C
        LD      (IY+UserArea.latest+1), B

        ; --- Update fat bucket head → new entry (ALL banks) ---
        ; Inline 24-bit pointers (Story 20.1): the head is [addr:2][bank:1].
        ; Recording the entry's bank lets FIND page it in before reading a
        ; window-resident entry, so bank-N definitions are findable by name
        ; (superseding the old bank-N bucket-skip, which left them reachable
        ; only via `LATEST @`).
        LD      HL, (bh_bucket_addr)
        LD      (HL), C                         ; BC = bh_entry_start (new entry addr)
        INC     HL
        LD      (HL), B
        INC     HL
        LD      A, (IY+UserArea.triple_owner)   ; bank the entry lives in
                                                ; (= triple owner; see the cell-
                                                ; reservation note above re Story 22.3)
        LD      (HL), A

        ; Restore HL = code field position, clear carry = success
        LD      HL, (bh_code_field)
        OR      A
        RET

; -----------------------------------------------
; POSTPONE ( "<spaces>name" -- ) IMMEDIATE, compile-only
;   If name is non-IMMEDIATE: compile its xt directly (deferred compilation)
;   If name is IMMEDIATE: compile [LIT xt COMPILE,] to defer its execution
; -----------------------------------------------
w_POSTPONE:
        DEFIMMED "POSTPONE"
w_POSTPONE_body:
w_POSTPONE_cf EQU w_POSTPONE_body - 3
        DW w_QCOMP_cf                ; compile-only guard
        DW w_BL_cf                   ; ( -- 32 )
        DW w_WORD_cf                 ; ( 32 -- c-addr )
        DW w_FIND_cf                 ; ( c-addr -- c-addr 0 | xt 1 | xt -1 )
        DW w_DUP_cf                  ; ( ... flag -- ... flag flag )
        DW w_QBRANCH_cf              ; if flag=0, not found
        DW .postpone_notfound - $
        ; Found: ( xt flag )
        DW w_LIT_cf, 1
        DW w_EQUALS_cf               ; ( xt flag==1? )
        DW w_QBRANCH_cf              ; if not IMMEDIATE, defer compilation
        DW .postpone_defer - $
        ; IMMEDIATE word: compile xt directly (its compilation semantics = execute)
        DW w_COMMA_cf                ; compile xt at HERE
        DW w_BRANCH_cf
        DW .postpone_done - $
.postpone_defer:
        ; Non-IMMEDIATE word: compile [LIT xt COMPILE,] to defer compilation
        DW w_LIT_cf, w_LIT_cf
        DW w_COMMA_cf                ; compile LIT
        DW w_COMMA_cf                ; compile xt
        DW w_LIT_cf, w_COMPILE_COMMA_cf
        DW w_COMMA_cf                ; compile COMPILE,
        DW w_BRANCH_cf
        DW .postpone_done - $
.postpone_notfound:
        ; ( c-addr 0 ) — word not found
        DW w_DROP_cf                 ; drop 0 flag, leaving c-addr as TOS
        DW w_COMP_ERROR_cf           ; proper cleanup + error message + abort
.postpone_done:
        DW EXIT_CODE

; -----------------------------------------------
; COMPILE, ( xt -- )
;   Compile execution token into the current definition at HERE
;   Functionally identical to , for direct-threaded Forth but
;   semantically distinct per ANS standard.
;
;   xt-as-stub-address contract. The 16-bit value written here is
;   transparently treated as an xt — for Phase-1/2/3 fixed-memory
;   words it is the code-field address (the legacy CFA-as-xt
;   contract; the folded EXECUTE JP (HL)s it directly); for banked
;   words it is the descriptor-stub
;   address (4-byte stub layout v2 in $D4CB+; the stub's
;   address IS the word's xt). COMPILE, performs ZERO
;   inspection of the value — same 16-bit store-and-advance whether
;   the xt is a CFA or a stub. The discrimination happens at dispatch
;   time (the stub's own RST $28 → stub_dispatch, src/banking.asm),
;   NOT at compile time.
;
;   This means COMPILE, requires NO functional code edit — the
;   current emit IS the xt-as-stub-address contract.
;
;   Per-bank COMPILE,: writes through (IY+UserArea.here) into the
;   current bank's `here` via BANK!'s LDIR triple-swap (same
;   per-bank-via-swap discipline as `,` in src/memory.asm).
;
;   DOWNSTREAM CONSUMERS:
;     - BANK-OF consumes xt-as-stub-address — BANK-OF
;       reads byte 0 of the stub at xt.
;     - bank-aware `:` is the load-bearing consumer:
;       `:` will allocate a stub for each banked word; the stub
;       address is set as the word's xt; COMPILE, references via the
;       compiled xt resolve to the stub address transparently.
; -----------------------------------------------
w_COMPILE_COMMA:
        DEFCODE "COMPILE,", 0
w_COMPILE_COMMA_cf:
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        GUARD_BANKED_WRITE 2               ; Story 23.6: -8 if a banked colon body crosses $C000 (AC2)
        LD      (HL), C
        INC     HL
        LD      (HL), B
        INC     HL
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        POP     BC              ; New TOS
        NEXT

; -----------------------------------------------
; IMMEDIATE ( -- )
;   Set the IMMEDIATE flag (bit 7) on the most recently defined word.
;
;   Reads through latest_count_flags_addr (mirrored at
;   build_header tail) instead of walking from LATEST. Required because
;   w_SEMICOLON_cf overwrites LATEST with a stub-xt for bank-N>0 colon
;   definitions (stub-as-xt) — a stub-xt + 2 lands
;   inside the stub body (target_addr.lo), not on the count_flags byte.
;   The scratch covers all build_header consumers (`:`, CREATE, CONSTANT,
;   MARKER, CODE, LABEL).
; -----------------------------------------------
w_IMMEDIATE:
        DEFCODE "IMMEDIATE", 0
w_IMMEDIATE_cf:
        LD      HL, (latest_count_flags_addr)
        LD      A, (HL)
        OR      F_IMMEDIATE
        LD      (HL), A
        NEXT

; -----------------------------------------------
; : (COLON) ( "<spaces>name" -- )
;   Begin a new colon definition. Parse name, create dictionary header
;   at HERE with SMUDGE set, emit JP DOCOL, enter compile mode.
;   Errors: -16 THROW (zero-length name) per ANS Forth 1994 §9.3.5
;   when the parsed name is empty.
; -----------------------------------------------
w_COLON:
        DEFCODE ":", 0
w_COLON_cf:
        EXX                                      ; Save TOS/IP/W to shadows

        LD      A, F_SMUDGE
        CALL    build_header
        JR      C, .colon_no_name

        ; Save error recovery info from shared scratch
        LD      BC, (bh_entry_start)
        LD      (colon_saved_here), BC
        LD      A, (bh_bucket_index)
        LD      (colon_saved_bucket), A
        LD      BC, (bh_old_bucket_head)
        LD      (colon_saved_head), BC
        LD      A, (bh_old_bucket_bank)
        LD      (colon_saved_bank), A           ; fat bank byte for COMP-ERROR
        LD      BC, (bh_count_flags_addr)
        LD      (colon_smudge_addr), BC
        LD      BC, (bh_wid)                     ; save wid for COMP-ERROR rollback
        LD      (colon_saved_wid), BC
        LD      BC, (bh_stub_xt_addr)            ; save cell addr for SEMICOLON
        LD      (colon_saved_xt_cell), BC        ; (intervening CREATE inside colon body
                                                 ; could clobber bh_stub_xt_addr; defensive)

        ; HL = code field position — emit JP DOCOL
        LD      (HL), 0xC3                       ; JP opcode
        INC     HL
        LD      (HL), LOW DOCOL
        INC     HL
        LD      (HL), HIGH DOCOL
        INC     HL

        ; Update HERE past code field (body starts here)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; Set STATE to compile mode
        LD      (IY+UserArea.state), 1
        LD      (IY+UserArea.state+1), 0

        EXX                                      ; Restore TOS/IP/W from shadows
        NEXT

.colon_no_name:
        EXX                                      ; Restore primary set:
                                                 ; kernel-internal THROW entry contract
                                                 ; requires primary-set BC; src/exception.asm:288-296
        ; -16 THROW: attempt to use zero-length string as a name per ANS Forth 1994 §9.3.5
        LD      BC, THROW_ZERO_LEN_NAME
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; COMP-ERROR ( c-addr -- ) internal, never returns
;   Compilation error recovery: restore HERE, unlink hash entry,
;   print "<NAME> ?" + CR, then raise -13 THROW
;   per ANS Forth 1994 §9.3.5. The dynamic word-name print and
;   HERE/bucket recovery are preserved verbatim.
; -----------------------------------------------
w_COMP_ERROR:
        DEFCODE "COMP-ERROR", 0
w_COMP_ERROR_cf:
        ; BC = c-addr (TOS) — the unknown word's counted string
        ; Save c-addr for error message
        PUSH    BC

        ; --- 5.1: Restore HERE from colon_saved_here ---
        LD      HL, (colon_saved_here)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; --- 5.2: Restore hash bucket head (saved wid from colon prologue) ---
        LD      A, (colon_saved_bucket)
        LD      L, A
        LD      H, 0                            ; HL = bucket
        LD      E, A
        LD      D, 0                            ; DE = bucket
        ADD     HL, HL                          ; HL = 2*bucket
        ADD     HL, DE                          ; HL = 3*bucket (fat-bucket stride)
        LD      BC, (colon_saved_wid)
        INC     BC
        INC     BC                              ; BC = saved_wid + WORDLIST_BUCKET0
        ADD     HL, BC                          ; HL = &<saved_wid>.buckets[bucket]
        ; Restore the fat bucket head: addr (2 bytes) + the saved bank byte.
        ; Restoring the bank too keeps the head consistent when the previous
        ; head was a window-resident bank-N entry (FIND pages on the bank byte,
        ; so a stale byte would page the wrong bank for the restored address).
        LD      BC, (colon_saved_head)
        LD      (HL), C
        INC     HL
        LD      (HL), B
        INC     HL
        LD      A, (colon_saved_bank)
        LD      (HL), A

        ; --- 5.3: Set STATE to 0 ---
        LD      (IY+UserArea.state), 0
        LD      (IY+UserArea.state+1), 0

        ; Print error message: "word ?" CR
        POP     BC                              ; BC = c-addr
        ; Print counted string: get count byte, then name
        LD      H, B
        LD      L, C                            ; HL = c-addr
        LD      A, (HL)                         ; A = count
        AND     F_LENMASK
        OR      A
        JR      Z, .comp_err_abort              ; empty name, just abort
        LD      B, A                            ; B = length
        INC     HL                              ; HL = name start
        ; Print name via BDOS
        CALL    bdos_print_str
        ; Print " ?" CR LF
        CALL    bdos_print_q_crlf

.comp_err_abort:
        ; --- 5.4: Raise -13 THROW ---
        ; -13 THROW: undefined word per ANS Forth 1994 §9.3.5
        ; STATE was already cleared above (5.3); HERE / hash bucket already
        ; restored (5.1, 5.2). EXX is not active here (COMP-ERROR is a
        ; DEFCODE called from INTERPRET which runs in primary-set context),
        ; so the kernel-internal entry contract holds.
        LD      BC, THROW_UNDEFINED_WORD
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; ; (SEMICOLON) ( -- ) IMMEDIATE
;   End a colon definition. Compile EXIT, clear SMUDGE, return to
;   interpret mode.
;   Errors: -14 THROW (interpreting a compile-only word) per ANS Forth
;   1994 §9.3.5 when invoked outside compile mode.
; -----------------------------------------------
w_SEMICOLON:
        DEFCODE ";", F_IMMEDIATE
w_SEMICOLON_cf:
        ; Guard: `;` is only valid in compile mode
        LD      A, (IY+UserArea.state)
        OR      A
        JR      NZ, .semi_ok
        LD      A, (IY+UserArea.state+1)
        OR      A
        JR      NZ, .semi_ok
        ; STATE=0 — `;` used outside definition; raise -14 THROW
        ; -14 THROW: interpreting a compile-only word per ANS Forth 1994 §9.3.5
        LD      BC, THROW_COMPILE_ONLY
        JP      w_THROW_cf.kernel_entry
.semi_ok:
        ; --- 3.1: Compile EXIT_CODE into the definition ---
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)         ; HL = HERE
        LD      (HL), LOW EXIT_CODE
        INC     HL
        LD      (HL), HIGH EXIT_CODE
        INC     HL
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; --- bank-aware stub allocation ---
        ; If triple_owner == 0: skip stub_allocate. LATEST stays at the
        ; entry-start value the build_header tail wrote (= hash_link
        ; address, NOT CFA — bank-0 entries take the .bh_skip_cell branch
        ; and have no cell; xt extraction is the legacy
        ; post-name-= CFA path at src/dictionary.asm). Preserves the
        ; byte-identical bank-0 dispatch.
        ; If triple_owner > 0: call stub_allocate (src/banking.asm);
        ; overwrite the reserved cell with the returned stub_addr; update
        ; LATEST to stub_addr. The stub's address IS the word's xt.
        ; Dispatch consumes via the stub's own RST $28 → stub_dispatch
        ; (src/banking.asm).
        ; Gated on triple_owner (the bank that owns the live triple = the
        ; bank this entry lands in), matching build_header's cell reservation;
        ; current_bank diverges only inside a cross-bank dispatch window.
        ; PUSH/POP DE wrap IS required: the bank-N>0 body uses DE as a
        ; scratch (EX DE,HL to set up stub_allocate's target_addr input
        ; and again to extract the stub_addr return). Without the wrap,
        ; the caller-side EXX would restore garbage into main DE → NEXT
        ; crashes. stub_allocate itself preserves main-set (its contract
        ; in src/banking.asm) so the wrap is only protecting
        ; against SEMICOLON's own DE-scratch usage.
        LD      A, (IY+UserArea.triple_owner)
        OR      A
        JR      Z, .semi_skip_stub
        ; PUSH BC required — BC is TOS-in-register
        ; and `LD B, A` below clobbers it for stub_allocate's target_bank
        ; input. Without this wrap, defining a SECOND banked colon while a
        ; previous banked xt sits on the data stack corrupts xt.high to
        ; the bank index (e.g., xt $D4CB → $05CB after `: _p192e-b 22 ;`
        ; with 5 BANK! active and the stash from `: _p192e-a 11 ;` on
        ; stack).
        PUSH    BC                                ; save TOS
        PUSH    DE                                ; save IP across stub_allocate
        LD      HL, (colon_saved_xt_cell)
        INC     HL
        INC     HL                                ; HL = CFA address
        EX      DE, HL                             ; DE = CFA = stub target_addr
        LD      B, A                               ; B = target_bank (A still = triple_owner)
        CALL    stub_allocate                     ; HL = stub_addr (= xt); main-set preserved
        LD      DE, (colon_saved_xt_cell)         ; DE = cell address
        EX      DE, HL                             ; HL = cell address; DE = stub_addr
        LD      (HL), E
        INC     HL
        LD      (HL), D                            ; cell ← stub_addr (overwrite CFA fill)
        LD      (IY+UserArea.latest), E
        LD      (IY+UserArea.latest+1), D          ; LATEST ← stub_addr (xt-as-stub-address)
        POP     DE                                 ; restore IP
        POP     BC                                 ; restore TOS
.semi_skip_stub:

        ; --- 3.2: Clear SMUDGE flag ---
        LD      HL, (colon_smudge_addr)
        LD      A, (HL)
        AND     ~F_SMUDGE                        ; Clear bit 6
        LD      (HL), A

        ; --- 3.3: Set STATE to 0 (interpret mode) ---
        LD      (IY+UserArea.state), 0
        LD      (IY+UserArea.state+1), 0

        NEXT

; -----------------------------------------------
; [ ( -- ) IMMEDIATE
;   Switch to interpret mode (set STATE to 0)
; -----------------------------------------------
w_LEFT_BRACKET:
        DEFCODE "[", F_IMMEDIATE
w_LEFT_BRACKET_cf:
        LD      (IY+UserArea.state), 0
        LD      (IY+UserArea.state+1), 0
        NEXT

; -----------------------------------------------
; ] ( -- )
;   Switch to compile mode (set STATE to non-zero)
; -----------------------------------------------
w_RIGHT_BRACKET:
        DEFCODE "]", 0
w_RIGHT_BRACKET_cf:
        LD      (IY+UserArea.state), 1
        LD      (IY+UserArea.state+1), 0
        NEXT

; -----------------------------------------------
; LITERAL ( n -- ) IMMEDIATE
;   Compile LIT n into the current definition.
;   Used as: [ expr ] LITERAL inside colon definitions.
; -----------------------------------------------
w_LITERAL:
        DEFCODE "LITERAL", F_IMMEDIATE
w_LITERAL_cf:
        ; Compile LIT xt at HERE
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)         ; HL = HERE
        LD      (HL), LOW w_LIT_cf
        INC     HL
        LD      (HL), HIGH w_LIT_cf
        INC     HL
        ; Compile the value (BC = TOS = n)
        LD      (HL), C
        INC     HL
        LD      (HL), B
        INC     HL
        ; Update HERE
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        ; Consume n from stack
        POP     BC
        NEXT

; -----------------------------------------------
; alloc_doer_stub — bank-aware descriptor-stub allocation for a defining word.
;   Shared by CREATE and VALUE (identical EXX'd context). Call after the code
;   field + body are emitted and HERE is updated, with bh_stub_xt_addr set by
;   build_header. On a bank that owns no stub (triple_owner == 0) it is a no-op;
;   otherwise it allocates a stub, patches the reserved cell to the stub addr,
;   and points LATEST at it (the stub addr IS the bank-stable xt).
;
;   Keyed off triple_owner — the bank the entry physically lands in (= the
;   owner of the live HERE/LATEST triple), matching build_header's stub-cell
;   reservation. current_bank would diverge from triple_owner under a cross-bank
;   dispatch window (stub_dispatch sets current_bank without swapping the
;   triple), reserving no cell yet still allocating a stub through a stale
;   bh_stub_xt_addr = wild write; gating on triple_owner keeps the two in step.
;
;   Caller is EXX'd, so BC/DE are alt-set scratch (no PUSH wrap needed).
;   stub_allocate preserves the main set. Clobbers A/BC/DE/HL/F.
; -----------------------------------------------
alloc_doer_stub:
        LD      A, (IY+UserArea.triple_owner)
        OR      A
        RET     Z                                ; bank-0: no stub, legacy dispatch
        LD      B, A                              ; B = target_bank
        LD      HL, (bh_stub_xt_addr)             ; HL = cell address
        INC     HL
        INC     HL                                ; HL = CFA address (post-cell)
        EX      DE, HL                            ; DE = CFA = stub target_addr
        CALL    stub_allocate                     ; HL = stub_addr (= xt)
        LD      DE, (bh_stub_xt_addr)             ; DE = cell address
        EX      DE, HL                            ; HL = cell addr; DE = stub_addr
        LD      (HL), E
        INC     HL
        LD      (HL), D                           ; cell ← stub_addr
        LD      (IY+UserArea.latest), E
        LD      (IY+UserArea.latest+1), D         ; LATEST ← stub_addr
        RET

; -----------------------------------------------
; CREATE ( "<spaces>name" -- )
;   Parse name, build dictionary header at HERE with JP DOVAR
;   code field + 2-byte does-addr slot (zeroed). No SMUDGE, no
;   compile mode. Word is immediately findable.
;   Errors: -16 THROW (zero-length name) per ANS Forth 1994 §9.3.5
;   when the parsed name is empty.
; -----------------------------------------------
w_CREATE:
        DEFCODE "CREATE", 0
w_CREATE_cf:
        EXX                                      ; Save TOS/IP/W to shadows
        XOR     A                                ; flags = 0 (no SMUDGE)
        CALL    build_header
        JR      C, .create_no_name

        ; HL = code field — emit JP DOVAR + does-addr slot
        LD      (HL), 0xC3                       ; JP opcode
        INC     HL
        LD      (HL), LOW DOVAR
        INC     HL
        LD      (HL), HIGH DOVAR
        INC     HL
        LD      (HL), 0                          ; does-addr low (zeroed)
        INC     HL
        LD      (HL), 0                          ; does-addr high (zeroed)
        INC     HL

        ; Update HERE (body starts here, user can ALLOT after)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; --- bank-aware doer-stub allocation (shared helper) ---
        ; EXX'd at entry, so BC/DE are alt-set scratch (no PUSH wrap needed).
        CALL    alloc_doer_stub

        EXX                                      ; Restore TOS/IP/W from shadows
        NEXT

.create_no_name:
        EXX                                      ; Restore primary set:
                                                 ; kernel-internal THROW entry contract
                                                 ; requires primary-set BC; src/exception.asm:288-296
        ; -16 THROW: attempt to use zero-length string as a name per ANS Forth 1994 §9.3.5
        LD      BC, THROW_ZERO_LEN_NAME
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; CONSTANT ( x "<spaces>name" -- )
;   Parse name, build dictionary header with JP DOCON code field,
;   store x in body.
;   Errors: -16 THROW (zero-length name) per ANS Forth 1994 §9.3.5
;   when the parsed name is empty; the value-cell `x` is consumed
;   from the data stack before the THROW raise.
; -----------------------------------------------
w_CONSTANT:
        DEFCODE "CONSTANT", 0
w_CONSTANT_cf:
        EXX                                      ; Save TOS (value)/IP/W to shadows
        XOR     A                                ; flags = 0
        CALL    build_header
        JR      C, .const_no_name

        ; HL = code field — emit JP DOCON
        LD      (HL), 0xC3                       ; JP opcode
        INC     HL
        LD      (HL), LOW DOCON
        INC     HL
        LD      (HL), HIGH DOCON
        INC     HL

        ; Body: emit constant value from BC' (shadow)
        EXX                                      ; BC = saved value (TOS)
        LD      A, C                             ; A = value low byte
        EXX                                      ; back to main, HL = body pos
        LD      (HL), A                          ; emit low byte
        INC     HL
        EXX                                      ; BC = saved value again
        LD      A, B                             ; A = value high byte
        EXX                                      ; back to main
        LD      (HL), A                          ; emit high byte
        INC     HL

        ; Update HERE
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; TOS consumed — restore IP/W, pop new TOS
        EXX                                      ; Restore DE=IP, HL=W from shadows
        POP     BC                               ; Pop new TOS
        NEXT

.const_no_name:
        EXX                                      ; Restore primary set:
                                                 ; kernel-internal THROW entry contract
                                                 ; requires primary-set BC; src/exception.asm:288-296
        POP     BC                               ; TOS consumed, pop new TOS — must
                                                 ; precede the LD BC below or the user's
                                                 ; value-cell would be orphaned on the
                                                 ; stack across the THROW.
        ; -16 THROW: attempt to use zero-length string as a name per ANS Forth 1994 §9.3.5
        LD      BC, THROW_ZERO_LEN_NAME
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; VALUE ( x "<spaces>name" -- )
;   Define a named mutable cell: executing the name pushes the stored x;
;   TO rewrites it. Shaped like CONSTANT but with two deliberate changes:
;     1. Emit JP DOVALUE (not JP DOCON) so TO can recognise a VALUE by its
;        code field and reject a CONSTANT / colon word / VARIABLE.
;     2. Append the CREATE-style bank-aware stub block so a bank-N>0 VALUE
;        gets a descriptor stub and a bank-stable xt — without it a banked
;        VALUE would be invocable only from its home bank.
;   Errors: -16 THROW (zero-length name) per ANS Forth 1994 §9.3.5; the
;   value-cell x is consumed before the THROW raise.
; -----------------------------------------------
w_VALUE:
        DEFCODE "VALUE", 0
w_VALUE_cf:
        EXX                                      ; Save TOS (value)/IP/W to shadows
        XOR     A                                ; flags = 0
        CALL    build_header
        JR      C, .value_no_name

        ; HL = code field — emit JP DOVALUE
        LD      (HL), 0xC3                       ; JP opcode
        INC     HL
        LD      (HL), LOW DOVALUE
        INC     HL
        LD      (HL), HIGH DOVALUE
        INC     HL

        ; Body: emit initial value from BC' (shadow), as CONSTANT does
        EXX                                      ; BC = saved value (TOS)
        LD      A, C                             ; A = value low byte
        EXX                                      ; back to main, HL = body pos
        LD      (HL), A
        INC     HL
        EXX                                      ; BC = saved value again
        LD      A, B                             ; A = value high byte
        EXX                                      ; back to main
        LD      (HL), A
        INC     HL

        ; Update HERE
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; --- bank-aware doer-stub allocation (shared helper) ---
        ; EXX'd at entry, so BC/DE are alt-set scratch (no PUSH wrap needed).
        CALL    alloc_doer_stub

        EXX                                      ; Restore TOS/IP/W from shadows
        POP     BC                               ; value consumed — pop new TOS
        NEXT

.value_no_name:
        EXX                                      ; Restore primary set (THROW entry contract)
        POP     BC                               ; value consumed — pop new TOS first so the
                                                 ; user's value-cell is not orphaned across THROW
        ; -16 THROW: zero-length name per ANS Forth 1994 §9.3.5
        LD      BC, THROW_ZERO_LEN_NAME
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; TO ( x "<spaces>name" -- ) / compile: ( "<spaces>name" -- )  IMMEDIATE
;   Parse the name, verify it is a VALUE, then store/compile-a-store.
;   STATE-aware: interpreting stores x now; compiling emits LIT <xt> (TO)
;   so the store happens at run time. Compiling the xt (not a raw cell
;   address) keeps the banked case correct — the xt is bank-stable.
;   Errors: -13 (undefined name, via the ' path); -32 (name is not a
;   VALUE, via to_verify).
; -----------------------------------------------
w_TO:
        DEFIMMED "TO"
w_TO_body:
w_TO_cf EQU w_TO_body - 3
        DW w_TICK_cf                 ; ( [x] "name" -- [x] xt ) parse+find; -13 on miss
        DW to_verify                 ; ( ... xt -- ... xt ) require VALUE; -32 otherwise
        DW w_STATE_cf                ; ( -- a-addr )
        DW w_FETCH_cf                ; ( a-addr -- state )
        DW w_QBRANCH_cf              ; consume state; 0 (interpret) → branch
        DW .to_interpret - $
        ; compile arm (STATE != 0): ( xt -- ) compile  LIT xt  then  (TO)
        DW w_LITERAL_cf              ; compile LIT xt (consumes xt)
        DW w_LIT_cf, w_PAREN_TO_cf   ; push (TO)'s xt
        DW w_COMPILE_COMMA_cf        ; compile (TO)
        DW EXIT_CODE
.to_interpret:
        ; ( x xt -- ) store x into the VALUE's cell now
        DW w_PAREN_TO_cf
        DW EXIT_CODE

; -----------------------------------------------
; (TO) ( x xt -- )  — run-time store compiled by TO in compile mode.
;   Bank-aware: resolves xt → (bank, cell) and writes x into the cell,
;   mapping the target bank into the window when it is not the current one.
; -----------------------------------------------
w_PAREN_TO:
        DEFCODE "(TO)", 0
w_PAREN_TO_cf:
        ; ( x xt -- ) BC = xt (TOS); x = NOS on the data stack
        PUSH    DE                      ; save IP (DE is free across resolve)
        LD      H, B
        LD      L, C                    ; HL = xt
        CALL    to_resolve_map_hl       ; HL = CFA (slot 2 mapped if cross-bank)
        INC     HL
        INC     HL
        INC     HL                      ; HL = value cell (CFA+3)
        POP     DE                      ; restore IP
        POP     BC                      ; BC = x (was NOS) — data stack is fixed-memory
        LD      (HL), C
        INC     HL
        LD      (HL), B                 ; cell ← x
        CALL    to_unmap                ; restore slot 2 if it was switched
        POP     BC                      ; new TOS
        NEXT

; -----------------------------------------------
; to_verify — bare runtime ( xt -- xt ): require xt to be a VALUE.
;   Reads xt's code-field JP operand (paging in the home bank for a banked
;   stub xt) and compares it to DOVALUE. Leaves xt untouched on a match;
;   raises -32 (invalid name argument) otherwise. Reached via DW to_verify.
; -----------------------------------------------
to_verify:
        PUSH    BC                      ; save xt (left as TOS on success)
        PUSH    DE                      ; save IP
        LD      H, B
        LD      L, C                    ; HL = xt
        CALL    to_resolve_map_hl       ; HL = CFA (mapped if needed)
        INC     HL                      ; CFA+1 (JP operand lo)
        LD      E, (HL)
        INC     HL                      ; CFA+2 (JP operand hi)
        LD      D, (HL)                 ; DE = code-field handler address
        CALL    to_unmap                ; restore slot 2 (preserves DE)
        LD      HL, DOVALUE
        LD      A, E
        CP      L
        JR      NZ, .tv_bad
        LD      A, D
        CP      H
        JR      NZ, .tv_bad
        POP     DE                      ; restore IP
        POP     BC                      ; restore xt (TOS)
        NEXT
.tv_bad:
        ; not a VALUE — -32. THROW resets SP from the catch frame, so the
        ; two abandoned PUSHes need no cleanup; BC is primary-set here.
        LD      BC, THROW_INVALID_NAME_ARG
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; to_resolve_map_hl — shared xt → CFA resolver (TO's verify + (TO) store).
;   In:  HL = xt (descriptor-stub xt $EF.., or a bank-0/kernel CFA).
;   Out: HL = CFA. If the CFA is window-resident ($8000..$BFFF) and lives
;        in a bank other than current_bank, that bank is mapped into slot 2
;        and to_switched is set so to_unmap restores the caller's page.
;   Clobbers: A, BC, DE. Preserves IX, IY and the data stack.
;
;   Stub-marker sampling is GUARDED on HL being fixed-memory. A descriptor
;   stub always lives in fixed memory (STUB_ALLOC_BASE = $D4CB+), so a
;   window-resident xt ($8000..$BFFF) can ONLY be a bank-0 portal CFA — the
;   bank-0 dictionary grows up through $8000 and those words get no stub.
;   The marker byte must NOT be sampled at a window address: TO may be invoked
;   from another bank, so slot 2 then holds a FOREIGN bank; an `LD A,(HL)`
;   there reads the wrong bank, and a coincidental $EF would mis-decode a
;   genuine VALUE as a stub (→ wild active_pages[] index + wild cross-bank
;   write). Window-resident xts therefore skip straight to the non-stub
;   (target_bank 0) path, which then maps bank 0 in .trm_decide.
;
;   This rests on stubs being unreachable in the window: they grow upward from
;   STUB_ALLOC_BASE, so they must all land in fixed memory (>= $C000). Enforce
;   that structurally — a future STUB_ALLOC_BASE move into the window would
;   silently void the heuristic.
; -----------------------------------------------
        ASSERT STUB_ALLOC_BASE >= 0xC000
to_resolve_map_hl:
        BIT     7, H
        JR      Z, .trm_fixed           ; <$8000 → fixed memory, marker is safe to read
        BIT     6, H
        JR      NZ, .trm_fixed          ; >=$C000 → fixed memory, marker is safe to read
        ; window-resident ($8000..$BFFF) → bank-0 portal CFA, never a stub
        XOR     A                       ; target_bank 0; HL already = CFA
        JR      .trm_decide
.trm_fixed:
        LD      A, (HL)
        CP      0xEF                    ; descriptor-stub marker (RST $28)?
        JR      Z, .trm_stub
        ; non-stub: HL already = CFA; bank-0/kernel word → target_bank 0
        XOR     A
        JR      .trm_decide
.trm_stub:
        INC     HL                      ; xt+1
        LD      A, (HL)                 ; A = target_bank
        INC     HL                      ; xt+2
        LD      E, (HL)
        INC     HL                      ; xt+3
        LD      D, (HL)                 ; DE = CFA in target bank
        EX      DE, HL                  ; HL = CFA
.trm_decide:
        ; HL = CFA, A = target_bank (0 for a bank-0/window/fixed CFA, else the
        ; stub's 0..28 bank byte). Map only if the CFA is window-resident and
        ; the target bank is not the one already in slot 2.
        BIT     7, H
        JR      Z, .trm_nomap           ; <$8000 fixed memory
        BIT     6, H
        JR      NZ, .trm_nomap          ; >=$C000 fixed memory
        CP      (IY+UserArea.current_bank)
        JR      Z, .trm_nomap           ; already mapped
        CALL    to_map_target           ; A = target_bank → slot 2 (preserves HL)
        LD      A, 1
        LD      (to_switched), A
        RET
.trm_nomap:
        XOR     A
        LD      (to_switched), A
        RET

; to_map_target — A = target_bank: save the caller's slot-2 page, then map
;   active_pages[target_bank] into slot 2. Preserves BC, DE, HL.
to_map_target:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      C, A                    ; C = target_bank
        CALL    mbb_get_slot2           ; A = caller's slot-2 page (preserves BC,DE,HL)
        LD      (to_saved_page), A
        LD      B, 0                    ; BC = target_bank
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC                  ; &active_pages[target_bank]
        LD      A, (HL)                 ; A = physical page
        CALL    mbb_set_slot2           ; map slot 2 (preserves BC,DE,HL)
        POP     HL
        POP     DE
        POP     BC
        RET

; to_unmap — restore slot 2 to the saved page iff to_resolve_map_hl mapped.
;   Preserves BC, DE, HL (clobbers A/F).
to_unmap:
        LD      A, (to_switched)
        OR      A
        RET     Z
        XOR     A
        LD      (to_switched), A
        LD      A, (to_saved_page)
        JP      mbb_set_slot2           ; tail; restores slot 2

to_saved_page:  DB 0                    ; caller's slot-2 page during a TO cross-bank access
to_switched:    DB 0                    ; non-zero iff to_resolve_map_hl mapped slot 2

; -----------------------------------------------
; DOES> ( -- ) IMMEDIATE
;   Compile (DOES>) into the current definition.
;   The DOES> body follows and is compiled normally by ;.
;   Errors: -14 THROW (interpreting a compile-only word) per ANS Forth
;   1994 §9.3.5 when invoked outside compile mode.
; -----------------------------------------------
w_DOES:
        DEFCODE "DOES>", F_IMMEDIATE
w_DOES_cf:
        ; Guard: DOES> only valid in compile mode
        LD      A, (IY+UserArea.state)
        OR      A
        JR      NZ, .does_ok
        LD      A, (IY+UserArea.state+1)
        OR      A
        JR      NZ, .does_ok
        ; STATE=0 — DOES> used outside definition; raise -14 THROW
        ; -14 THROW: interpreting a compile-only word per ANS Forth 1994 §9.3.5
        LD      BC, THROW_COMPILE_ONLY
        JP      w_THROW_cf.kernel_entry
.does_ok:
        ; Compile (DOES>) into current definition
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (HL), LOW w_PAREN_DOES_cf
        INC     HL
        LD      (HL), HIGH w_PAREN_DOES_cf
        INC     HL
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        NEXT

; -----------------------------------------------
; (DOES>) ( -- ) runtime helper
;   Patches LATEST word's code field from JP DOVAR to JP DODOES,
;   stores IP (DOES> body addr) at cf+3, then EXITs.
; -----------------------------------------------
w_PAREN_DOES:
        DEFCODE "(DOES>)", 0
w_PAREN_DOES_cf:
        ; DE = IP = address of DOES> body (right after this word in the thread)
        ;
        ; --- bank-aware CFA walk ---
        ; A naive walk of LATEST → +2 → count_flags breaks for
        ; bank-N>0 entries because SEMICOLON overwrites
        ; LATEST with the descriptor-stub address (stub_xt, not entry-
        ; start); LATEST+2 lands inside the stub body, not on count_flags.
        ; Read (latest_count_flags_addr) — scratch mirrored
        ; at build_header tail — for the count_flags byte address directly.
        ; If F_HAS_STUB_XT_CELL set (bank-N>0), skip 2-byte cell to reach
        ; CFA; else (bank-0/legacy) HL = post-name = CFA. DE = IP preserved
        ; (does-addr write below uses DE).
        ; PUSH BC wrap: BC is TOS-in-register; `LD B, A` below uses B as
        ; scratch for count_flags. Same pattern as SEMICOLON's
        ; bank-N stub block.
        PUSH    BC                           ; save TOS
        LD      HL, (latest_count_flags_addr)
        LD      A, (HL)
        LD      B, A                         ; B = saved count_flags
        AND     F_LENMASK                    ; A = name length
        INC     HL                           ; HL = &name[0]
        ADD     A, L
        LD      L, A
        JR      NC, .pdoes_no_carry
        INC     H
.pdoes_no_carry:                             ; HL = post-name
        LD      A, B
        POP     BC                           ; restore TOS
        AND     F_HAS_STUB_XT_CELL
        JR      Z, .pdoes_cfa_ready
        INC     HL
        INC     HL                           ; HL = CFA (skip stub-xt cell)
.pdoes_cfa_ready:                            ; HL = CFA address
        ; Overwrite code field with JP DODOES
        LD      (HL), 0xC3                   ; JP opcode
        INC     HL
        LD      (HL), LOW DODOES
        INC     HL
        LD      (HL), HIGH DODOES
        INC     HL
        ; Write does-addr (DE = IP = DOES> body start)
        LD      (HL), E
        INC     HL
        LD      (HL), D
        ; EXIT — return from defining word (pop IP from return stack)
        CALL    rpop_de
        NEXT
