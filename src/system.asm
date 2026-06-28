; system.asm — System words (BYE, MARKER, WORDS, ABORT, QUIT, error handling)
; AntForth — A Forth for CP/M on Z80

; -----------------------------------------------
; BYE ( -- )
;   Exit to CP/M (terminate via BDOS function 0)
; -----------------------------------------------
w_BYE:
        DEFCODE "BYE", 0
w_BYE_cf:
        LD      C, P_TERMCPM
        JP      BDOS_ENTRY
        ; No NEXT — BYE never returns

; -----------------------------------------------
; MARKER ( "<spaces>name" -- )
;   Create a word that, when executed, restores dictionary state
;   to what it was just before MARKER ran.
;   Body layout: [saved_buckets(192)][snap_count(1)][bank_triples(snap_count*6)][stub_tail(2)]
;   saved_buckets = FORTH-WORDLIST bucket array only (64 × 3-byte fat heads,
;   Story 20.1); the wordlist struct's next-link cell is NOT in it.
;   bank_triples = the live prefix of bank-table[] — snap_count entries of the
;   per-bank (here, latest, wordlist_head) triple, where snap_count =
;   max(bank_count, triple_owner+1) (always >= 1; covers every reachable bank
;   plus the owner reloaded at FORGET; entries >= snap_count are inert under
;   BANK!'s n < bank_count precondition, so snapshotting them is wasted TPA).
;   stub_tail = the descriptor-stub allocator next-free pointer. FORGET reverts
;   both tails.
;   Errors: -16 THROW (zero-length name) per ANS Forth 1994 §9.3.5
;   when the parsed name is empty.
;   Limitation: MARKER snapshots FORTH-WORDLIST's
;   bucket array regardless of CURRENT-WORDLIST. Definitions placed into
;   other wordlists between MARKER-create and MARKER-execute are NOT
;   rolled back.
;   When MARKER itself is created with current_wordlist != FORTH-WORDLIST,
;   the snapshot's bucket-head fixup is skipped — bh_old_bucket_head is the
;   foreign wid's chain head, and writing it into FORTH-WORDLIST's snapshot
;   would corrupt FORTH-WORDLIST on DOMARKER restore.
; -----------------------------------------------
w_MARKER:
        DEFCODE "MARKER", 0
w_MARKER_cf:
        EXX                                      ; Save TOS/IP/W to shadows

        ; --- Snapshot the PRE-MARKER per-bank tail into bank-table[owner] ---
        ; Sync the live (here, latest, wordlist_head) triple into
        ; bank-table[triple_owner] BEFORE build_header runs. build_header
        ; overwrites UserArea.latest with the MARKER's own entry, so capturing
        ; the triple first records the PRE-MARKER latest — FORGET then reverts
        ; LATEST to the word defined just before MARKER (ANS MARKER semantics)
        ; rather than the now-forgotten MARKER. here/wordlist_head are not
        ; advanced by build_header, so this captures the pre-MARKER HERE too.
        ; triple_owner (not current_bank — they diverge mid cross-bank dispatch)
        ; owns the live copy; the bounded snapshot below folds the entry into the
        ; marker body. Runs unconditionally: writing the current live triple to
        ; its own stale-until-reparked table slot is a no-op on the abort path.
        ; Shares bank_triple_save (src/banking.asm) — the SAVE half of the
        ; BANK! triple swap (CR 21.3 #3).
        LD      A, (IY+UserArea.triple_owner)
        CALL    bank_triple_save                ; live triple -> bank-table[owner]

        ; Raise the build_header window-top reserve to MARKER's full footprint
        ; (code field + 192-byte saved body + bank-table prefix + stub tail) so
        ; the single pre-commit guard inside build_header is all-or-nothing: if
        ; the body would cross $C000 it throws -8 BEFORE the header/LATEST/bucket
        ; are committed (the body LDIR below runs only after build_header has
        ; already committed them, so it cannot self-guard). build_header resets the
        ; cell on EVERY exit — the window-top guard on the found-name path and
        ; .bh_no_name on the no-name (-16) path — so no cleanup is needed here on
        ; either the success or the no-name error return (Story 23.7).
        LD      HL, MARKER_CODE_RESERVE
        LD      (bh_code_reserve), HL

        ; Build dictionary header (flags=0, no SMUDGE)
        XOR     A
        CALL    build_header
        JR      C, .marker_no_name

        ; HL = code field — emit JP DOMARKER
        LD      (HL), 0xC3              ; JP opcode
        INC     HL
        LD      (HL), LOW DOMARKER
        INC     HL
        LD      (HL), HIGH DOMARKER
        INC     HL

        ; Save body hash start address for fixup later. The body now opens
        ; directly with saved_buckets: the old saved_here field was emitted but
        ; never read (DOMARKER takes HERE from the reloaded bank-table[owner]
        ; triple), so it is dropped (CR 21.3 #2).
        PUSH    HL                      ; body_hash_start (= cf+3, start of saved_buckets)

        ; Copy 192 bytes from FORTH-WORDLIST fat bucket array to body
        ; (64 × 3-byte fat heads). Need LDIR: HL=src, DE=dst, BC=count
        ; Currently HL = body dest, need to swap.
        ; No inline window-top guard here: build_header's pre-commit check already
        ; reserved MARKER_CODE_RESERVE (this body + the tail below), so the whole
        ; footprint is proven to fit before any byte was committed (Story 23.7).
        ; A guard at this point would throw with a half-built MARKER — do NOT add one.
        EX      DE, HL                  ; DE = body dest
        LD      HL, forth_wordlist + WORDLIST_BUCKET0   ; HL = source (bucket array only)
        LD      BC, 192
        LDIR                            ; DE = past end of body

        ; Fixup: restore pre-MARKER bucket value in body copy.
        ; Body hash copy starts at (saved on stack). Only valid when MARKER's
        ; header was inserted INTO FORTH-WORDLIST itself: in that case
        ; bh_old_bucket_head is FORTH-WORDLIST's pre-MARKER bucket head and
        ; the snapshot's bucket (now pointing at MARKER's new entry) must be
        ; reverted. When current_wordlist != FORTH-WORDLIST the snapshot
        ; already reflects FORTH-WORDLIST's true bucket head (MARKER didn't
        ; touch FORTH-WORDLIST) and bh_old_bucket_head is the FOREIGN wid's
        ; bucket head — applying the fixup would corrupt FORTH-WORDLIST on
        ; DOMARKER restore (snapshot-scope discipline).
        POP     HL                      ; HL = body_hash_start
        LD      BC, (bh_wid)
        LD      A, C
        CP      LOW forth_wordlist
        JR      NZ, .marker_skip_fixup
        LD      A, B
        CP      HIGH forth_wordlist
        JR      NZ, .marker_skip_fixup
        LD      A, (bh_bucket_index)
        LD      C, A
        LD      B, 0
        ADD     HL, BC
        ADD     HL, BC
        ADD     HL, BC                  ; HL = body_hash_start + bucket_index * 3 (fat stride)
        LD      BC, (bh_old_bucket_head)
        LD      (HL), C
        INC     HL
        LD      (HL), B
        INC     HL
        LD      A, (bh_old_bucket_bank)
        LD      (HL), A                 ; restore fat bank byte too
.marker_skip_fixup:

        ; --- Append snap_count + live per-bank triples + stub-allocator tail ---
        ; DE = next free body byte (past saved_buckets). The live (here, latest,
        ; wordlist_head) triple was already synced into bank-table[triple_owner]
        ; above (pre-build_header, so the captured latest is the PRE-MARKER one).
        ; Snapshot only the LIVE prefix of bank-table[]: entry k >= bank_count is
        ; inert (BANK!'s n < bank_count precondition makes it unreachable), so
        ; copying it back per FORGET burns ~168 B of TPA + copy time for provably
        ; constant data (CR 21.3 #5).
        ;   snap_count = max(bank_count, triple_owner+1)
        ; bounds the copy: bank_count covers every reachable bank, and the
        ; owner+1 clause guarantees the owner entry (reloaded by DOMARKER) is
        ; captured even when bank_count == 0 (fresh boot / nested MARKER) or a
        ; BANKS-CLEAR left owner > bank_count. snap_count >= 1 always, which also
        ; rules out the BC==0 -> LDIR-copies-64KB trap. snap_count is stored in
        ; the body so DOMARKER reverts exactly the entries live at MARKER time.
        ; INVARIANT (correctness rests on it): triple_owner must stay < snap_count
        ; between this snapshot and its FORGET, so DOMARKER's final bank_triple_load
        ; reads a RESTORED owner entry. Holds today because owner only moves via
        ; BANK!/THROW to indices < bank_count <= snap_count. Epic 22 bank-renumber
        ; work MUST preserve it (or re-snapshot) — see DOMARKER (CR 21.3 review).
        ; active_pages[]/bank_count sit OUTSIDE bank-table[], so +BANK / -BANK
        ; membership changes are not snapshotted; worse, a -BANK between MARKER
        ; and FORGET renumbers logical banks without renumbering bank-table[], so
        ; this restore can reassert triples onto the wrong banks — MARKER with
        ; mid-span -BANK is unsupported until Epic 22.
        LD      A, (IY+UserArea.bank_count)
        LD      C, A                            ; C = bank_count
        LD      A, (IY+UserArea.triple_owner)
        INC     A                               ; A = triple_owner + 1
        CP      C
        JR      NC, .marker_snap_count          ; owner+1 >= bank_count -> snap = owner+1
        LD      A, C                            ; else snap = bank_count
.marker_snap_count:
        LD      (DE), A                         ; snap_count -> body
        INC     DE
        ; BC = snap_count * 6 (entry stride). snap_count in [1..29] => *6 in
        ; [6..174] < 256 (no carry, never 0).
        ADD     A, A                            ; *2
        LD      C, A
        ADD     A, A                            ; *4
        ADD     A, C                            ; *6
        LD      C, A
        LD      B, 0                            ; BC = snap_count * 6
        LD      HL, BANK_TABLE_BASE             ; $D400 source (live prefix)
        LDIR                                    ; bank-table[0..snap_count-1] -> body; DE advanced

        ; Append the descriptor-stub allocator tail (2 B) to the body.
        LD      A, (IY+UserArea.stub_alloc_tail)
        LD      (DE), A
        INC     DE
        LD      A, (IY+UserArea.stub_alloc_tail+1)
        LD      (DE), A
        INC     DE

        ; Update HERE = DE (past end of enlarged body, from LDIR + stub tail)
        LD      (IY+UserArea.here), E
        LD      (IY+UserArea.here+1), D

        EXX                                      ; Restore TOS/IP/W from shadows
        NEXT

.marker_no_name:
        EXX                                      ; Restore primary set:
                                                 ; kernel-internal THROW entry contract
                                                 ; requires primary-set BC (see src/exception.asm)
        ; -16 THROW: attempt to use zero-length string as a name per ANS Forth 1994 §9.3.5
        LD      BC, THROW_ZERO_LEN_NAME
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; (ABORT") ( flag -- ) runtime helper
;   If flag is zero, skip inline counted string and continue.
;   If flag is non-zero, print inline string then raise -2 THROW per
;   ANS Forth 1994 §9.3.5 / §6.1.0680 / Forth 2014 §9.6.2.0680.
;   Inline string format: count byte + chars + cell-alignment padding
;   Truthy flag → message + raise; zero flag → skip string and continue.
; -----------------------------------------------
w_PAREN_ABORT_QUOTE:
        DEFCODE '(ABORT")', 0
w_PAREN_ABORT_QUOTE_cf:
        ; BC = flag (TOS)
        LD      A, B
        OR      C               ; Test if flag is zero
        POP     BC              ; Pop new TOS (consumed flag)
        JR      NZ, .paq_abort  ; Non-zero: abort with message

        ; Flag is zero: skip inline string
        ; DE = IP, points to count byte
        LD      A, (DE)         ; A = count
        INC     DE              ; DE past count byte
        ADD     A, E
        LD      E, A
        JR      NC, .paq_skip_nc
        INC     D
.paq_skip_nc:
        ; Cell-align: if DE is odd, increment by 1
        BIT     0, E
        JR      Z, .paq_skip_aligned
        INC     DE
.paq_skip_aligned:
        ; DE = new IP, past string
        NEXT

.paq_abort:
        ; Non-zero flag: print string then raise -2 THROW.
        ; No IP save needed: -2 THROW's uncaught-handler resets SP wholesale
        ; and re-enters QUIT (or, if caught, the catching frame's SP_safe +
        ; IP discard the partial state).
        ; bdos_print_str preserves IX (established invariant — return stack is
        ; IX-based and all BDOS-calling words rely on this).
        LD      A, (DE)         ; A = count
        INC     DE              ; DE = string start
        OR      A
        JR      Z, .paq_do_abort ; Empty string, just abort

        LD      B, A            ; B = count
        LD      H, D
        LD      L, E            ; HL = string address
        CALL    bdos_print_str

.paq_do_abort:
        ; -2 THROW: ABORT" with truthy flag per
        ; ANS Forth 1994 §9.3.5 / §6.1.0680 / Forth 2014 §9.6.2.0680.
        ; Recovery happens via the uncaught-THROW handler.
        LD      BC, THROW_ABORT_QUOTE
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; ABORT" ( "ccc<quote>" flag -- ) IMMEDIATE, compile-only
;   Compile-time: compile (ABORT") + inline string
;   Runtime: if flag non-zero, print string and ABORT
; -----------------------------------------------
w_ABORT_QUOTE:
        DEFCODE 'ABORT"', F_IMMEDIATE
w_ABORT_QUOTE_cf:
        ; Save DE (IP) to scratch cell
        LD      (aq_saved_ip), DE

        ; Compile (ABORT") xt + inline string at HERE
        PUSH    BC              ; save TOS
        ; First compile the (ABORT") xt
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        ; Banked window-top guard for the fixed framing bytes: (ABORT") xt (2)
        ; + count byte (1). Per-char body growth is guarded in .aq_copy below.
        ; No-op on bank 0; -8 BEFORE any byte. Primary set (IP saved to scratch).
        GUARD_BANKED_WRITE 3
        LD      (HL), LOW w_PAREN_ABORT_QUOTE_cf
        INC     HL
        LD      (HL), HIGH w_PAREN_ABORT_QUOTE_cf
        INC     HL
        ; Now compile the inline counted string at HL
        ; Save count address, then copy chars from TIB
        PUSH    HL              ; save count_addr
        INC     HL              ; HL = first char destination

        ; Compute source pointer: TIB + >IN
        LD      E, (IY+UserArea.tib_in)
        LD      D, (IY+UserArea.tib_in+1)
        PUSH    HL              ; save dest
        LD      L, (IY+UserArea.tib_addr)
        LD      H, (IY+UserArea.tib_addr+1)
        ADD     HL, DE          ; HL = source
        LD      (aq_src), HL
        POP     HL              ; HL = dest

        ; Skip one leading space (per string literal convention)
        PUSH    HL
        LD      HL, (aq_src)
        LD      A, (HL)
        CP      ' '
        JR      NZ, .aq_no_skip
        INC     HL
        LD      (aq_src), HL
        ; Advance >IN by 1
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
.aq_no_skip:
        POP     HL              ; HL = dest

        ; Compute remaining = tib_len - >IN
        LD      A, (IY+UserArea.tib_len)
        SUB     (IY+UserArea.tib_in)
        LD      C, A
        LD      A, (IY+UserArea.tib_len+1)
        SBC     A, (IY+UserArea.tib_in+1)
        OR      A
        JR      Z, .aq_rem_ok
        LD      C, 255
.aq_rem_ok:
        LD      B, 0            ; B = char count

.aq_copy:
        LD      A, C
        OR      A
        JR      Z, .aq_done     ; end of input
        PUSH    HL
        LD      HL, (aq_src)
        LD      A, (HL)
        INC     HL
        LD      (aq_src), HL
        POP     HL
        DEC     C               ; remaining--
        ; Advance >IN
        PUSH    HL
        PUSH    AF
        LD      L, (IY+UserArea.tib_in)
        LD      H, (IY+UserArea.tib_in+1)
        INC     HL
        LD      (IY+UserArea.tib_in), L
        LD      (IY+UserArea.tib_in+1), H
        POP     AF
        POP     HL
        CP      '"'
        JR      Z, .aq_done     ; closing quote found
        ; Banked window-top guard: refuse a char at/past $C000 (no-op on
        ; bank 0). A holds the char; the guard clobbers AF, so bracket with
        ; PUSH/POP AF. Overflow JPs to dict_overflow_throw; the orphaned
        ; PUSH AF is discarded by THROW/ABORT's SP reset.
        PUSH    AF
        GUARD_BANKED_WRITE 1
        POP     AF
        ; Copy character
        LD      (HL), A
        INC     HL
        INC     B               ; count++
        JR      .aq_copy

.aq_done:
        ; B = string length, HL = past last char
        ; Write count byte
        POP     DE              ; DE = count_addr
        LD      A, B
        LD      (DE), A         ; store count byte

        ; Cell-align HL: if odd, pad with 0 and advance
        BIT     0, L
        JR      Z, .aq_aligned
        LD      (HL), 0         ; padding byte
        INC     HL
.aq_aligned:
        ; Update HERE
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        POP     BC              ; restore TOS

        ; Restore IP
        LD      DE, (aq_saved_ip)
        NEXT

; ABORT" scratch storage
aq_saved_ip:    DW 0
aq_src:         DW 0

; -----------------------------------------------
; ABORT ( -- )
;   Raise -1 THROW per ANS §6.1.0670 / Forth 2014 §9.6.2.0670.
;   Uncaught: REPL recovery via the uncaught-THROW handler
;   (src/exception.asm:.throw_uncaught — this handler owns the
;   asm_cleanup / SP-reset / JP w_QUIT_cf chain directly).
;   Caught: -1 lands on the data stack as the THROW code; i*x
;   cells underneath are preserved.
;
;   ABORT is the user-facing entry point that raises -1 THROW;
;   all internal ABORT call sites raise THROW directly.
; -----------------------------------------------
w_ABORT:
        DEFCODE "ABORT", 0
w_ABORT_cf:
        ; -1 THROW: ABORT per ANS Forth 1994 §9.3.5 /
        ; §6.1.0670 / Forth 2014 §9.6.2.0670.
        LD      BC, THROW_ABORT
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; ENVIRONMENT? ( c-addr u -- false | i*x true )
;   Look up the query string c-addr/u in env_table. On hit, push the
;   associated value (single, double, or flag), then push true. On miss,
;   push false alone (one cell — the i*x is absent per DPANS94 §6.1.1345).
;   Match is case-sensitive (all 14 standard keys are uppercase literals
;   per DPANS94 §3.2.6). Keys longer than 255 bytes cannot match — every
;   table key is shorter — so u >= 256 short-circuits to false.
;
; ANS Forth 1994 §6.1.1345   ENVIRONMENT?   — query environment
; -----------------------------------------------
w_ENVIRONMENT_QUERY:
        DEFCODE "ENVIRONMENT?", 0
w_ENVIRONMENT_QUERY_cf:
        CALL    check_underflow_2       ; needs c-addr u (2 cells)
        ; BC = u (TOS), [SP] = c-addr
        LD      A, B
        OR      A
        JR      NZ, .env_too_long       ; u >= 256: no match possible
        ; Consume operands and walk the table.
        LD      (env_saved_ip), DE
        POP     HL                      ; HL = c-addr
        LD      DE, env_table
.env_loop:
        LD      A, (DE)                 ; A = entry length
        OR      A
        JR      Z, .env_not_found       ; len=0 terminator
        CP      C                       ; query length match?
        JR      Z, .env_compare
.env_advance:
        ; Skip this entry: DE += 1 + len + 1 (kind) + (2 or 4)
        INC     DE                      ; -> first key char
        ADD     A, E
        LD      E, A
        JR      NC, .env_adv_no_carry
        INC     D
.env_adv_no_carry:                      ; DE -> kind byte
        LD      A, (DE)                 ; A = kind
        INC     DE                      ; -> first value byte
        CP      1
        JR      NZ, .env_adv_skip2
        INC     DE                      ; double: skip 2 extra bytes
        INC     DE
.env_adv_skip2:
        INC     DE
        INC     DE
        JR      .env_loop
.env_compare:
        ; A = len = u, DE -> length byte, HL -> c-addr
        PUSH    HL                      ; save c-addr
        PUSH    DE                      ; save entry start
        INC     DE                      ; -> first key char
        LD      B, A                    ; B = byte count (>0)
.env_cmp_loop:
        LD      A, (DE)
        CP      (HL)
        JR      NZ, .env_mismatch
        INC     DE
        INC     HL
        DJNZ    .env_cmp_loop
        ; All bytes matched — recover entry start, then advance to value.
        POP     DE                      ; restore entry start
        POP     HL                      ; discard c-addr
        LD      A, (DE)                 ; reload length
        INC     DE
        ADD     A, E
        LD      E, A
        JR      NC, .env_hit_no_carry
        INC     D
.env_hit_no_carry:                      ; DE -> kind byte
        LD      A, (DE)                 ; A = kind
        INC     DE                      ; -> value bytes
        DEC     A
        JR      Z, .env_kind_double
        ; A = kind - 1. Expected post-DEC values: 0->$FF (single), 2->1 (flag).
        ; Any other value here means the table is malformed (kind >= 3 or
        ; corrupted entry header). The 2-byte path is the safe default for
        ; both kind 0 and kind 2; if a future kind needs a different value
        ; size, ADD a JR/CP branch here BEFORE the fall-through. Do NOT
        ; rely on silent fall-through for new kinds.
.env_kind_2byte:
        LD      A, (DE)
        LD      C, A
        INC     DE
        LD      A, (DE)
        LD      B, A                    ; BC = value
        PUSH    BC                      ; value as second-on-stack
        LD      BC, -1                  ; TOS = true ($FFFF)
        LD      DE, (env_saved_ip)
        NEXT
.env_mismatch:
        POP     DE                      ; restore entry start
        POP     HL                      ; restore c-addr
        LD      A, (DE)                 ; reload length
        JR      .env_advance
.env_kind_double:
        ; DE -> 4 bytes: lo_low, lo_high, hi_low, hi_high.
        ; Per ANS Forth 1994 §3.1.4.1 the high cell is on
        ; TOS. We want stack
        ; ( lo hi true ) with true as TOS, so push lo first (deepest),
        ; then hi (above lo), then BC = -1 (new TOS = true).
        LD      A, (DE)
        LD      L, A
        INC     DE
        LD      A, (DE)
        LD      H, A                    ; HL = lo
        INC     DE
        LD      A, (DE)
        LD      C, A
        INC     DE
        LD      A, (DE)
        LD      B, A                    ; BC = hi
        PUSH    HL                      ; lo (deepest)
        PUSH    BC                      ; hi (above lo)
        LD      BC, -1                  ; TOS = true
        LD      DE, (env_saved_ip)
        NEXT
.env_not_found:
        ; (c-addr, u) already consumed; leave only false on the stack.
        LD      BC, 0
        LD      DE, (env_saved_ip)
        NEXT
.env_too_long:
        ; u >= 256: drop c-addr and return false alone.
        POP     HL                      ; discard c-addr
        LD      BC, 0
        NEXT

env_saved_ip:   DW 0

; --- DPANS94 §3.2.6 standard query-key table ---
; Format per entry: db len, "KEY", kind, value-bytes (2 for kind 0/2, 4 for kind 1)
; Kind: 0 = single-cell, 1 = double-cell (lo then hi), 2 = flag (0=false, $FFFF=true)
; Key match is case-sensitive (all standard keys are uppercase literals).
env_table:
        ; /COUNTED-STRING -> 255 (max counted-string length; antforth uses 8-bit count byte)
        db  15, "/COUNTED-STRING", 0
        dw  255
        ; /HOLD -> PIC_BUF_SIZE = 40 (pictured-output buffer size)
        db  5, "/HOLD", 0
        dw  PIC_BUF_SIZE
        ; /PAD -> PAD_OFFSET = 84 (PAD offset above HERE)
        db  4, "/PAD", 0
        dw  PAD_OFFSET
        ; ADDRESS-UNIT-BITS -> 8 (Z80 byte-addressable)
        db  17, "ADDRESS-UNIT-BITS", 0
        dw  8
        ; CORE -> true (133/133 §6.1 Core words implemented)
        db  4, "CORE", 2
        dw  $FFFF
        ; CORE-EXT -> false (§6.2 partial: 13/46 DPANS94 §6.2 + 1 Forth-2014 bonus HOLDS; DPANS94 §15.3.5.2 needs full set)
        db  8, "CORE-EXT", 2
        dw  0
        ; FLOORED -> false (antforth's `/` is symmetric per sdivmod, not floored)
        db  7, "FLOORED", 2
        dw  0
        ; MAX-CHAR -> 255 (8-bit char)
        db  8, "MAX-CHAR", 0
        dw  255
        ; MAX-D -> +2147483647 = (lo=$FFFF, hi=$7FFF) — double-cell
        db  5, "MAX-D", 1
        dw  $FFFF
        dw  $7FFF
        ; MAX-N -> 32767 (INT16_MAX)
        db  5, "MAX-N", 0
        dw  32767
        ; MAX-U -> 65535 ($FFFF unsigned; antforth signed TOS shows -1)
        db  5, "MAX-U", 0
        dw  $FFFF
        ; MAX-UD -> 4294967295 = (lo=$FFFF, hi=$FFFF) — double-cell
        db  6, "MAX-UD", 1
        dw  $FFFF
        dw  $FFFF
        ; RETURN-STACK-CELLS -> RS_SIZE/2 = 128
        db  18, "RETURN-STACK-CELLS", 0
        dw  RS_SIZE/2
        ; STACK-CELLS -> PS_SIZE/2 = 128
        db  11, "STACK-CELLS", 0
        dw  PS_SIZE/2
        ; EXCEPTION -> true (CATCH/THROW present)
        db  9, "EXCEPTION", 2
        dw  $FFFF
        ; EXCEPTION-EXT -> true (ABORT/ABORT" present)
        db  13, "EXCEPTION-EXT", 2
        dw  $FFFF
        ; DOUBLE -> false (recognised; set incomplete — D0< D0= D2* D2/ 2CONSTANT 2LITERAL 2VARIABLE missing)
        db  6, "DOUBLE", 2
        dw  0
        ; DOUBLE-EXT -> false (recognised; 2ROT 2VALUE DU< absent)
        db  10, "DOUBLE-EXT", 2
        dw  0
        ; SEARCH-ORDER -> true (all 8 words present)
        db  12, "SEARCH-ORDER", 2
        dw  $FFFF
        ; SEARCH-ORDER-EXT -> false (recognised; ALSO FORTH ORDER PREVIOUS missing, only ONLY present)
        db  16, "SEARCH-ORDER-EXT", 2
        dw  0
        ; Terminator (zero-length entry)
        db  0

; -----------------------------------------------
; check_underflow — Internal subroutine (not a Forth word)
;   Verify DEPTH >= 1 (at least 1 cell on machine stack)
;   CALL pushes 2-byte return address onto SP, so at time of check
;   SP is 2 less than "real" SP. Need sp_base - SP_real >= 2,
;   i.e. sp_base - SP_measured >= 4.
;
;   On underflow: JP do_underflow_error (raises -4 THROW via
;     w_THROW_cf.kernel_entry). Never returns to caller.
;   On success: returns normally
;   Clobbers: AF, HL
;   Preserves: BC (TOS), DE (IP), IX, IY, SP
; -----------------------------------------------
check_underflow:
        LD      HL, (sp_base)
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP_measured
        JR      C, .underflow   ; sp_base < SP = corrupt, definitely underflow
        LD      A, H
        OR      A
        RET     NZ              ; HL >= 256, plenty of stack — fast exit
        LD      A, L
        CP      4               ; Need >= 4 (2 for CALL ret addr + 2 for one cell)
        RET     NC              ; HL >= 4, OK
.underflow:
        JP      do_underflow_error

; -----------------------------------------------
; check_underflow_2 — Internal subroutine (not a Forth word)
;   Verify DEPTH >= 2 (at least 2 cells on machine stack)
;   For binary ops needing 2 user items (BC + 1 POP).
;   Threshold: sp_base - SP_measured >= 6
;   (2 for CALL ret addr + 4 for two cells)
;
;   On underflow: JP do_underflow_error (-4 THROW).
;   Clobbers: AF, HL
;   Preserves: BC (TOS), DE (IP), IX, IY, SP
; -----------------------------------------------
check_underflow_2:
        LD      HL, (sp_base)
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP_measured
        JR      C, .underflow2  ; sp_base < SP = corrupt
        LD      A, H
        OR      A
        RET     NZ              ; HL >= 256, plenty of stack
        LD      A, L
        CP      6               ; Need >= 6 (2 ret addr + 4 for two cells)
        RET     NC              ; HL >= 6, OK
.underflow2:
        JP      do_underflow_error

; -----------------------------------------------
; check_underflow_3 — Internal subroutine (not a Forth word)
;   Verify DEPTH >= 3 (at least 3 cells on machine stack)
;   For ternary ops needing 3 user items (e.g. 2!).
;   Threshold: sp_base - SP_measured >= 8
;   (2 for CALL ret addr + 6 for three cells)
;
;   On underflow: JP do_underflow_error (-4 THROW).
;   Clobbers: AF, HL
;   Preserves: BC (TOS), DE (IP), IX, IY, SP
; -----------------------------------------------
check_underflow_3:
        LD      HL, (sp_base)
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP_measured
        JR      C, .underflow3  ; sp_base < SP = corrupt
        LD      A, H
        OR      A
        RET     NZ              ; HL >= 256, plenty of stack
        LD      A, L
        CP      8               ; Need >= 8 (2 ret addr + 6 for three cells)
        RET     NC              ; HL >= 8, OK
.underflow3:
        JP      do_underflow_error

; -----------------------------------------------
; check_underflow_4 — Internal subroutine (not a Forth word)
;   Verify DEPTH >= 4 (at least 4 cells on machine stack)
;   For quaternary ops needing 4 user items (e.g. 2SWAP, 2OVER).
;   Threshold: sp_base - SP_measured >= 10
;   (2 for CALL ret addr + 8 for four cells)
;
;   On underflow: JP do_underflow_error (-4 THROW).
;   Clobbers: AF, HL
;   Preserves: BC (TOS), DE (IP), IX, IY, SP
; -----------------------------------------------
check_underflow_4:
        LD      HL, (sp_base)
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP_measured
        JR      C, .underflow4  ; sp_base < SP = corrupt
        LD      A, H
        OR      A
        RET     NZ              ; HL >= 256, plenty of stack
        LD      A, L
        CP      10              ; Need >= 10 (2 ret addr + 8 for four cells)
        RET     NC              ; HL >= 10, OK
.underflow4:
        JP      do_underflow_error

; -----------------------------------------------
; check_overflow — Internal subroutine (not a Forth word)
;   Verify enough headroom remains for the upcoming PUSH BC at the
;   caller, AND for the THROW-uncaught path itself if this guard fires.
;
;   Computes HL = sp_base - SP_measured (= bytes already used below
;   sp_base, including this CALL's 2-byte return address). Triggers
;   overflow when HL >= (PS_SIZE - SAFETY_MARGIN). The safety margin
;   covers (a) the 2 ret-addr bytes already on SP at this point;
;   (b) the 2 bytes the about-to-execute PUSH BC will consume; AND
;   (c) the THROW-uncaught path's worst-case nested-CALL SP usage
;   (.throw_uncaught → CALL bdos_print_str → CALL bdos_putchar →
;   CALL BDOS_ENTRY → BDOS internals; ~26 bytes deepest per the
;   trace below, with conservative slack for variable BDOS impls).
;   32 bytes chosen to give 6-byte slack over the measured worst
;   case. -3 THROW per ANS Forth 1994 §9.3.5.
;
;   Threshold derivation:
;     - HL_computed at guard entry = U_caller + 2 (CALL ret addr).
;     - On normal return + caller's PUSH BC: used = HL_computed.
;     - On overflow path: SP at .throw_uncaught entry = caller_SP - 2;
;       deepest SP usage in .throw_uncaught path = HL_computed + ~28
;       (bdos_print_str's PUSH HL + PUSH BC + CALL bdos_putchar +
;       CALL BDOS_ENTRY + BDOS internals).
;     - Safety: trigger overflow when HL_computed >= PS_SIZE - 32 = 224.
;       Both paths have headroom: caught path uses 0 additional bytes
;       (LD SP, HL is wholesale restore via the catch frame's saved
;       SP_safe); uncaught path's ~28-byte deepest-CALL fits in 32.
;
;   On overflow: JP do_overflow_error (raises -3 THROW via
;     w_THROW_cf.kernel_entry; mirrors do_underflow_error pattern).
;     Never returns to caller.
;   On success: returns normally.
;   Clobbers: AF, HL.
;   Preserves: BC (TOS), DE (IP), IX, IY, SP.
; -----------------------------------------------
check_overflow:
        LD      HL, (sp_base)
        OR      A               ; Clear carry
        SBC     HL, SP          ; HL = sp_base - SP_measured (bytes used incl. CALL ret)
        JR      C, .overflow    ; SP > sp_base = corrupt → treat as overflow
        LD      A, H
        OR      A
        JR      NZ, .overflow   ; HL >= 256 = beyond PS_SIZE — definite overflow
        LD      A, L
        CP      PS_SIZE - 32    ; Threshold = 224 = PS_SIZE (256) - 32-byte margin
        RET     C               ; HL < 224 — OK, return
.overflow:
        JP      do_overflow_error

; -----------------------------------------------
; do_underflow_error — Internal subroutine (not a Forth word)
;   Raises a clean -4 THROW. The diagnostic the
;   user sees on the uncaught path is "error -4: stack
;   underflow" (description in throw_desc_table at
;   src/exception.asm). On the caught path,
;   -4 lands on the user's data stack as the THROW code per
;   ANS Forth 1994 §9.3.5.
;
;   Note: CALL check_underflow's return address remains on SP —
;   harmless because the THROW-restore (caught) or the inlined
;   recovery chain at .throw_uncaught (uncaught)
;   both wholesale reset SP downstream. SP-may-be-corrupt safety
;   is preserved: the new path neither reads nor writes SP-relative
;   values until the downstream restore.
; -----------------------------------------------
do_underflow_error:
        ; -4 THROW: stack underflow per ANS Forth 1994 §9.3.5
        LD      BC, THROW_STACK_UNDERFLOW
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; do_overflow_error — Internal subroutine (not a Forth word)
;   Raise -3 THROW (stack overflow per ANS Forth 1994 §9.3.5).
;   Mirror of do_underflow_error: the SP-may-be-tight property is
;   preserved here because this routine neither reads nor writes SP-
;   relative data — the JP into w_THROW_cf.kernel_entry takes the
;   stack to a wholesale restore (caught path: LD SP, HL via catch
;   frame +0; uncaught path: LD SP, (sp_base) at .throw_uncaught
;   tail). The CALL check_overflow's return address remains on SP —
;   harmless for the same reason underflow's ret-addr is harmless.
; -----------------------------------------------
do_overflow_error:
        ; -3 THROW: stack overflow per ANS Forth 1994 §9.3.5
        LD      BC, THROW_STACK_OVERFLOW
        JP      w_THROW_cf.kernel_entry
