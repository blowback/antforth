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
;   -13 THROW (Story 11.5) per ANS Forth 1994 §9.3.5. The dynamic
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
        ; -13 THROW (Story 11.5): undefined word per ANS Forth 1994 §9.3.5
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
bh_old_bucket_head:  DW 0   ; Previous bucket head (for error recovery)
bh_count_flags_addr: DW 0   ; Address of count_flags byte (for unsmudging)
bh_flags:            DB 0   ; Flags to OR into count_flags
bh_code_field:       DW 0   ; Code field position (saved for return)
bh_wid:              DW 0   ; Wid used for header insertion (Story 12.4 — for error recovery)
bh_stub_xt_addr:     DW 0   ; Story 19.2 (Q1-α): address of the 2-byte stub-xt cell
                            ; inserted between name and CFA. build_header initial-fills
                            ; with the CFA address (so FIND extraction returns CFA for
                            ; legacy bank-0 / Phase-1/2/3 entries unchanged);
                            ; w_SEMICOLON_cf overwrites for bank-N>0 colon definitions
                            ; with the descriptor-stub address (PD-P4-1; architecture.md:200..211).

; Story 19.2 (Q2-γ) — fixed-memory scratch read by w_IMMEDIATE_cf so the
; IMMEDIATE bit lands on the right count_flags byte even after w_SEMICOLON_cf
; has overwritten LATEST with a stub-xt (bank-N>0 path). Mirror-written at
; the tail of every successful build_header (covers `:`, CREATE, CONSTANT,
; MARKER, CODE, LABEL). See PD-P4-1 (architecture.md:200..211) + redesign §2.1.
;
; CR fix (Story 19.2 review): assembly-time initial value points at a
; sentinel sink so IMMEDIATE invoked before any build_header consumer has
; run no-ops on the sink instead of writing F_IMMEDIATE into the CP/M
; zero-page (the DW 0 form wrote the bit into $0002 = BDOS dispatch).
; Pre-Story 19.2 IMMEDIATE walked LATEST (= 0 at COLD) and hit the same
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
colon_saved_wid:     DW 0   ; Wid the colon header was inserted into (Story 12.4)
colon_saved_xt_cell: DW 0   ; Story 19.2 (Q1-α): bh_stub_xt_addr snapshot for SEMICOLON
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

        ; --- Hash the name ---
        LD      HL, (bh_name_start)
        LD      B, A                            ; B = name length
        CALL    hash_name                       ; A = bucket index
        LD      (bh_bucket_index), A

        ; Compute bucket head address: current_wordlist bucket array + A*2
        ; Story 12.4 — bucket array now lives in (IY+UserArea.current_wordlist),
        ; not in forth_wordlist directly. Capture the wid into bh_wid for
        ; the error-recovery paths (w_COMP_ERROR_cf, asm_cleanup,
        ; asm_unlink_labels) to read from colon_saved_wid / asm_saved_wid.
        ; Lifecycle invariant: bh_wid is written ONLY on the success path
        ; below this point; the .bh_no_name early-exit at :161 returns CF=1
        ; without touching bh_wid. Callers that consume bh_wid (colon /
        ; CODE / MARKER prologues) MUST first test the carry flag and skip
        ; the bh_wid read on error — otherwise they read a stale wid from
        ; a previous successful build_header invocation.
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      C, (IY+UserArea.current_wordlist)
        LD      B, (IY+UserArea.current_wordlist+1)
        LD      (bh_wid), BC                    ; capture wid (Story 12.4)
        INC     BC
        INC     BC                              ; BC = wid + WORDLIST_BUCKET0
        ADD     HL, BC                          ; HL = &<current_wordlist>.buckets[bucket]
        LD      (bh_bucket_addr), HL
        ; Read current bucket head
        LD      C, (HL)
        INC     HL
        LD      B, (HL)                         ; BC = current bucket head
        LD      (bh_old_bucket_head), BC

        ; --- Build dictionary entry at HERE ---
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)         ; HL = HERE

        ; Emit hash_link (2 bytes)
        LD      (HL), C
        INC     HL
        LD      (HL), B
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

        ; --- Story 19.2 (Q1-α + Q3-β) — bank-aware stub-xt cell reservation ---
        ; Bank-0 entries: legacy layout (HL = post-name = CFA; no cell, no
        ; flag). Preserves NFR-P4-16 byte-identical bank-0 dispatch + protects
        ; iron-spike (tests/banking_tests.fth:705..728) which crosses the
        ; slot-1/slot-2 boundary at $8000 — extra cells per bank-0 entry
        ; would push iron-spike's body into bank-0's slot-2 and break it on
        ; `5 BANK!` mid-execution. Bank-N>0 entries: reserve 2-byte cell
        ; between name and CFA; set F_HAS_STUB_XT_CELL bit in count_flags;
        ; initial-fill the cell with the CFA address (overwritten by
        ; w_SEMICOLON_cf with descriptor-stub address per PD-P4-1; FIND
        ; discriminates on the flag at src/dictionary.asm).
        ; architecture.md:200..211 + 347..363; redesign §2.1.
        LD      A, (IY+UserArea.current_bank)
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
        ; Preserve DE — EXX'd callers (w_COLON_cf at :424; CREATE at :638;
        ; CONSTANT at :681; CODE at :1248; MARKER at :36; LABEL at :2275)
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

        ; --- Story 19.2 (Q2-γ) — latest_count_flags_addr mirror ---
        ; Mirror count_flags address so w_IMMEDIATE_cf reaches the right
        ; byte even after w_SEMICOLON_cf has overwritten LATEST with a
        ; stub-xt (bank-N>0 path). Always-mirror covers `:`, CREATE,
        ; CONSTANT, MARKER, CODE, LABEL — every build_header consumer in
        ; either bank-0 (LATEST = entry-start, +2 = count_flags) or
        ; bank-N>0 (LATEST = stub-xt post-SEMICOLON, no longer +2 to
        ; count_flags).
        PUSH    HL
        LD      HL, (bh_count_flags_addr)
        LD      (latest_count_flags_addr), HL
        POP     HL                                ; restore HL = CFA address

        ; --- Update LATEST (always, regardless of bank) ---
        ; LATEST is per-bank state (architecture.md PD-P4-3). Bank-0 keeps
        ; legacy semantics (LATEST = entry_start). The bank-N>0 callers in
        ; w_CREATE_cf / w_COLON_cf overwrite LATEST with the stub-xt after
        ; stub_allocate runs, so the value written here is just the
        ; bank-0 default that bank-N paths replace.
        LD      BC, (bh_entry_start)
        LD      (IY+UserArea.latest), C
        LD      (IY+UserArea.latest+1), B

        ; --- Update hash bucket head to point to new entry ---
        ; Story 19.3.1 — skip the bucket-head update when current_bank > 0.
        ; The FORTH-WORDLIST bucket array lives in always-mapped slot-1
        ; and is SHARED across all banks; writing a bank-N HERE address
        ; (slot-2, bank-N RAM) into a bucket leaves a dangling pointer
        ; after `0 BANK!` reverts slot-2 to bank-0 RAM. FIND walks would
        ; dereference into bank-0 slot-2 garbage and rot every word
        ; sharing the polluted bucket. Bank-N CREATEd entries remain
        ; reachable via post-CREATE `LATEST @` (the stub-xt capture
        ; pattern); bank-N FIND-by-name is deferred to Epic 20.
        LD      A, (IY+UserArea.current_bank)
        OR      A
        JR      NZ, .bh_skip_bucket_update
        LD      HL, (bh_bucket_addr)
        LD      (HL), C
        INC     HL
        LD      (HL), B
.bh_skip_bucket_update:

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
;   Story 18.3 (FR-P4-14 initial stub-emission wiring; PD-P4-1 /
;   architecture.md:207..211; PD-P4-11 / architecture.md:347..363):
;   xt-as-stub-address contract. The 16-bit value written here is
;   transparently treated as an xt — for Phase-1/2/3 fixed-memory
;   words it is the code-field address (the legacy CFA-as-xt
;   contract preserved by w_EXECUTE_cf's legacy-CFA discriminator);
;   for Epic-18+ banked words it is the descriptor-stub address
;   (PD-P4-11 4-byte stub layout in $D4CB+; the stub's address IS
;   the word's xt per FR-P4-13). COMPILE, performs ZERO inspection
;   of the value — same 16-bit store-and-advance whether the xt
;   is a CFA or a stub. The discrimination happens at dispatch time
;   (w_EXECUTE_cf at src/inner_interpreter.asm:285+), NOT at compile
;   time.
;
;   This means COMPILE, requires NO functional code edit at Story
;   18.3 — the current emit IS the xt-as-stub-address contract.
;   Story 18.3's edit is documentation-only: this CCD-3 source
;   comment block + a forward pointer to Epic 19 (where bank-aware
;   `:` allocates the stub on `;` and COMPILE, is naturally consumed
;   in the per-bank compile path).
;
;   Story 19.1 / FR-P4-14 (final integration; AC4 closure) — per-bank
;   COMPILE,: writes through (IY+UserArea.here) into the current
;   bank's `here` via BANK!'s LDIR triple-swap at
;   src/banking.asm:170..193 (same per-bank-via-swap discipline as `,`
;   in src/memory.asm). The Epic-19 forward-pointer below is CLOSED
;   by this story; Story 19.2 will land bank-aware `:` on top of this
;   per-bank cell-write foundation. See PD-P4-3
;   (_bmad-output/planning-artifacts/architecture.md:229..241) and
;   docs/antforth-banking-redesign.md §5.4.
;
;   DOWNSTREAM CONSUMERS (Epic 18+):
;     - Story 18.4 (BANK-OF) consumes xt-as-stub-address — BANK-OF
;       reads byte 0 of the stub at xt.
;     - Story 19.2 (bank-aware `:`) is the load-bearing consumer:
;       `:` will allocate a stub for each banked word; the stub
;       address is set as the word's xt; COMPILE, references via the
;       compiled xt resolve to the stub address transparently.
; -----------------------------------------------
w_COMPILE_COMMA:
        DEFCODE "COMPILE,", 0
w_COMPILE_COMMA_cf:
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
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
;   Story 19.2 (Q2-γ): reads through latest_count_flags_addr (mirrored at
;   build_header tail) instead of walking from LATEST. Required because
;   w_SEMICOLON_cf overwrites LATEST with a stub-xt for bank-N>0 colon
;   definitions (PD-P4-1 / FR-P4-13 stub-as-xt) — a stub-xt + 2 lands
;   inside the stub body (target_addr.lo), not on the count_flags byte.
;   The scratch covers all build_header consumers (`:`, CREATE, CONSTANT,
;   MARKER, CODE, LABEL). architecture.md:200..211; redesign §2.1.
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
;   when the parsed name is empty (Story 11.5).
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
        LD      BC, (bh_count_flags_addr)
        LD      (colon_smudge_addr), BC
        LD      BC, (bh_wid)                     ; Story 12.4 — save wid for COMP-ERROR rollback
        LD      (colon_saved_wid), BC
        LD      BC, (bh_stub_xt_addr)            ; Story 19.2 — save cell addr for SEMICOLON
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
        EXX                                      ; Restore primary set (Story 11.5:
                                                 ; kernel-internal THROW entry contract
                                                 ; requires primary-set BC; src/exception.asm:288-296)
        ; -16 THROW (Story 11.5): attempt to use zero-length string as a name per ANS Forth 1994 §9.3.5
        LD      BC, THROW_ZERO_LEN_NAME
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; COMP-ERROR ( c-addr -- ) internal, never returns
;   Compilation error recovery: restore HERE, unlink hash entry,
;   print "<NAME> ?" + CR, then raise -13 THROW (Story 11.5)
;   per ANS Forth 1994 §9.3.5. Migrated from `JP w_ABORT_cf` to
;   `LD BC, THROW_UNDEFINED_WORD / JP w_THROW_cf.kernel_entry` —
;   the dynamic word-name print and HERE/bucket recovery are
;   preserved verbatim.
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

        ; --- 5.2: Restore hash bucket head (Story 12.4 — saved wid from colon prologue) ---
        LD      A, (colon_saved_bucket)
        LD      L, A
        LD      H, 0
        ADD     HL, HL                          ; HL = bucket * 2
        LD      BC, (colon_saved_wid)
        INC     BC
        INC     BC                              ; BC = saved_wid + WORDLIST_BUCKET0
        ADD     HL, BC                          ; HL = &<saved_wid>.buckets[bucket]
        LD      BC, (colon_saved_head)
        LD      (HL), C
        INC     HL
        LD      (HL), B

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
        ; --- 5.4: Raise -13 THROW (Story 11.5) ---
        ; -13 THROW (Story 11.5): undefined word per ANS Forth 1994 §9.3.5
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
;   1994 §9.3.5 when invoked outside compile mode (Story 11.5).
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
        ; STATE=0 — `;` used outside definition; raise -14 THROW (Story 11.5)
        ; -14 THROW (Story 11.5): interpreting a compile-only word per ANS Forth 1994 §9.3.5
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

        ; --- Story 19.2 (Q3-β / FR-P4-13..17) — bank-aware stub allocation ---
        ; If current_bank == 0: skip stub_allocate. LATEST stays at the
        ; entry-start value the build_header tail wrote (= hash_link
        ; address, NOT CFA — bank-0 entries take the .bh_skip_cell branch
        ; and have no cell; xt extraction is the legacy
        ; post-name-= CFA path at src/dictionary.asm:187). Preserves
        ; NFR-P4-1 (Phase-2/3 test surface; 975 PASS) and NFR-P4-16
        ; (byte-identical bank-0 dispatch).
        ; If current_bank > 0: call stub_allocate (src/banking.asm:780);
        ; overwrite the reserved cell with the returned stub_addr; update
        ; LATEST to stub_addr. The stub's address IS the word's xt
        ; (PD-P4-1; architecture.md:200..211 + 347..363; redesign §2.1).
        ; Cross-bank dispatch consumes via w_EXECUTE_cf's 3-way path at
        ; src/inner_interpreter.asm:384..463 (FR-P4-15/16).
        ; PUSH/POP DE wrap IS required: the bank-N>0 body uses DE as a
        ; scratch (EX DE,HL to set up stub_allocate's target_addr input
        ; and again to extract the stub_addr return). Without the wrap,
        ; the caller-side EXX would restore garbage into main DE → NEXT
        ; crashes. stub_allocate itself preserves main-set (its contract
        ; at src/banking.asm:760..773) so the wrap is only protecting
        ; against SEMICOLON's own DE-scratch usage.
        LD      A, (IY+UserArea.current_bank)
        OR      A
        JR      Z, .semi_skip_stub
        ; CR fix (Story 19.2 review): PUSH BC required — BC is TOS-in-register
        ; and `LD B, A` below clobbers it for stub_allocate's target_bank
        ; input. Without this wrap, defining a SECOND banked colon while a
        ; previous banked xt sits on the data stack corrupts xt.high to
        ; current_bank (e.g., xt $D4CB → $05CB after `: _p192e-b 22 ;`
        ; with 5 BANK! active and the stash from `: _p192e-a 11 ;` on
        ; stack). Probe-19.2-E surfaced this; pre-edit dev pass missed it
        ; because Probes D/F/G each held only one bank-N xt on the stack.
        PUSH    BC                                ; save TOS
        PUSH    DE                                ; save IP across stub_allocate
        LD      HL, (colon_saved_xt_cell)
        INC     HL
        INC     HL                                ; HL = CFA address
        EX      DE, HL                             ; DE = CFA = stub target_addr
        LD      B, A                               ; B = target_bank (A still = current_bank)
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
; CREATE ( "<spaces>name" -- )
;   Parse name, build dictionary header at HERE with JP DOVAR
;   code field + 2-byte does-addr slot (zeroed). No SMUDGE, no
;   compile mode. Word is immediately findable.
;   Errors: -16 THROW (zero-length name) per ANS Forth 1994 §9.3.5
;   when the parsed name is empty (Story 11.5).
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

        ; --- Story 19.3 (Q1-α / FR-P4-25) — bank-aware doer-stub allocation ---
        ; Re-applied 2026-05-20 for the real-hardware iron-spike layout test
        ; (see _bmad-output/implementation-artifacts/19-3-*.md §"Dev-Pass
        ; Deferral 2026-05-20"). If hardware iron-spike PASSes at this
        ; +30 B layout, the iz-cpm-banking hang is emulator-quirk-class
        ; (similar to project_phase4_banking_off_emulator) and Story 19.3
        ; can ship with hardware as load-bearing verdict. If hardware
        ; also hangs, there's a real kernel defect to root-cause.
        ;
        ; If current_bank == 0: skip stub_allocate (NFR-P4-16 byte-identical
        ; bank-0 dispatch). If current_bank > 0: call stub_allocate
        ; (src/banking.asm:780); overwrite the reserved cell at
        ; (bh_stub_xt_addr) with the returned stub_addr; update LATEST.
        ; PD-P4-1 (architecture.md:200..211); PD-P4-11 (:347..363);
        ; FR-P4-13/17/25; redesign §2.1.
        ;
        ; NO PUSH BC / PUSH DE required — w_CREATE_cf EXX'd at entry,
        ; so BC/DE inside the body are alt-set scratch (not TOS/IP).
        LD      A, (IY+UserArea.current_bank)
        OR      A
        JR      Z, .create_skip_stub
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
.create_skip_stub:

        EXX                                      ; Restore TOS/IP/W from shadows
        NEXT

.create_no_name:
        EXX                                      ; Restore primary set (Story 11.5:
                                                 ; kernel-internal THROW entry contract
                                                 ; requires primary-set BC; src/exception.asm:288-296)
        ; -16 THROW (Story 11.5): attempt to use zero-length string as a name per ANS Forth 1994 §9.3.5
        LD      BC, THROW_ZERO_LEN_NAME
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; CONSTANT ( x "<spaces>name" -- )
;   Parse name, build dictionary header with JP DOCON code field,
;   store x in body.
;   Errors: -16 THROW (zero-length name) per ANS Forth 1994 §9.3.5
;   when the parsed name is empty; the value-cell `x` is consumed
;   from the data stack before the THROW raise (Story 11.5).
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
        EXX                                      ; Restore primary set (Story 11.5:
                                                 ; kernel-internal THROW entry contract
                                                 ; requires primary-set BC; src/exception.asm:288-296)
        POP     BC                               ; TOS consumed, pop new TOS — must
                                                 ; precede the LD BC below or the user's
                                                 ; value-cell would be orphaned on the
                                                 ; stack across the THROW (Story 11.5
                                                 ; Dev Notes pitfall #3).
        ; -16 THROW (Story 11.5): attempt to use zero-length string as a name per ANS Forth 1994 §9.3.5
        LD      BC, THROW_ZERO_LEN_NAME
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; DOES> ( -- ) IMMEDIATE
;   Compile (DOES>) into the current definition.
;   The DOES> body follows and is compiled normally by ;.
;   Errors: -14 THROW (interpreting a compile-only word) per ANS Forth
;   1994 §9.3.5 when invoked outside compile mode (Story 11.5).
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
        ; STATE=0 — DOES> used outside definition; raise -14 THROW (Story 11.5)
        ; -14 THROW (Story 11.5): interpreting a compile-only word per ANS Forth 1994 §9.3.5
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
        ; --- Story 19.3 (Q2-α / FR-P4-25) — bank-aware CFA walk ---
        ; Re-applied 2026-05-20 for the real-hardware iron-spike layout test.
        ; Pre-Story-19.3 walked LATEST → +2 → count_flags. That breaks for
        ; bank-N>0 entries because Story 19.2 SEMICOLON Q3-β overwrites
        ; LATEST with the descriptor-stub address (stub_xt, not entry-
        ; start); LATEST+2 lands inside the stub body, not on count_flags.
        ; Read (latest_count_flags_addr) — Story 19.2 Q2-γ scratch mirrored
        ; at build_header tail — for the count_flags byte address directly.
        ; If F_HAS_STUB_XT_CELL set (bank-N>0), skip 2-byte cell to reach
        ; CFA; else (bank-0/legacy) HL = post-name = CFA bit-identical to
        ; pre-edit. DE = IP preserved (does-addr write below uses DE).
        ; PUSH BC wrap: BC is TOS-in-register; `LD B, A` below uses B as
        ; scratch for count_flags. Same CR-fix pattern as SEMICOLON
        ; bank-N stub block at :683.
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
