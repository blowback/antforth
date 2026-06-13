; antforth.asm — Main assembly manifest
; AntForth — A Forth for CP/M on Z80
; Includes all components in dependency order per architecture spec

        DEVICE NONE

; === System constants and definitions (no code emitted) ===
        INCLUDE "constants.asm"
        INCLUDE "macros.asm"
        INCLUDE "structures.asm"

; === Code starts at CP/M .COM entry point ===
        ORG     TPA_START               ; 0x0100

; === Cold Start ===
; Full cold start protocol: initialise stacks, registers, user variables,
; then begin executing the test thread via NEXT
cold_start:
        ; 1. Read BDOS address from 0x0006 for TPA top
        LD      HL, (BDOS_ADDR_PTR)     ; HL = BDOS base = top of TPA

        ; 1b. Drop sp_base by SP_GUARD so a stack-underflow over-pop + the
        ;     following check_underflow CALL push lands in our own red-zone,
        ;     never on the BDOS entry at top-of-TPA. (see SP_GUARD, constants.asm)
        OR      A                       ; clear carry for SBC
        LD      DE, SP_GUARD
        SBC     HL, DE

        ; 2. SP = TPA top (parameter stack base, grows downward)
        LD      SP, HL

        ; 2b. Store SP base for DEPTH calculation
        ;     Z80 has no LD (nn),SP — use HL which still holds the stack base
        LD      (sp_base), HL

        ; 3. IX = SP - PS_SIZE (return stack base, below parameter stack region)
        OR      A               ; Clear carry flag before SBC
        LD      DE, PS_SIZE
        SBC     HL, DE          ; HL = return stack base
        PUSH    HL
        POP     IX              ; IX = return stack base

        ; 3b. Store initial return stack pointer for QUIT
        LD      (rp_base), HL

        ; 4. IY = user variable area
        LD      IY, user_area

        ; 5. STATE = 0 (interpret mode)
        LD      (IY+UserArea.state), 0
        LD      (IY+UserArea.state+1), 0

        ; 6. BASE = 10 (decimal)
        LD      (IY+UserArea.base), 10
        LD      (IY+UserArea.base+1), 0

        ; 7. HERE = kernel_end
        LD      HL, kernel_end
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; 8. TIB and >IN
        LD      HL, tib_buffer
        LD      (IY+UserArea.tib_addr), L
        LD      (IY+UserArea.tib_addr+1), H
        LD      (IY+UserArea.tib_len), 0
        LD      (IY+UserArea.tib_len+1), 0
        LD      (IY+UserArea.tib_in), 0
        LD      (IY+UserArea.tib_in+1), 0

        ; 8b. LATEST = 0, SOURCE-ID = 0
        LD      (IY+UserArea.latest), 0
        LD      (IY+UserArea.latest+1), 0
        LD      (IY+UserArea.source_id), 0
        LD      (IY+UserArea.source_id+1), 0

        ; 8b'. CATCH-TOP = 0 (no enclosing exception frame at REPL start)
        LD      (IY+UserArea.catch_top), 0
        LD      (IY+UserArea.catch_top+1), 0

        ; 8b''. INCLUDE-TOP = 0 (no INCLUDE source-frame at REPL start —
        ;       dual-LIFO chain head)
        LD      (IY+UserArea.include_top), 0
        LD      (IY+UserArea.include_top+1), 0

        ; 8c. HLD = IY + UserArea.pic_buf + PIC_BUF_SIZE
        ;     (sentinel one past the buffer's high end; <# resets to this)
        PUSH    IY
        POP     HL
        LD      DE, UserArea.pic_buf + PIC_BUF_SIZE
        ADD     HL, DE
        LD      (IY+UserArea.hld), L
        LD      (IY+UserArea.hld+1), H

        ; 8d. SEARCH-ORDER init — slot 0 = forth_wordlist; depth = 1.
        ;     ANS Forth 1994 §16.6.1.2195 SET-ORDER (-1) "minimum search order".
        ;     Slots 1..15 zero-initialised defensively via plain DJNZ store
        ;     loop. An LDIR cascade-zero variant was ruled out: it shifted
        ;     the binary layout in a way that produced a layout-sensitive
        ;     iz-cpm hang on the */ stack-underflow regression test (test
        ;     643). DJNZ keeps the same defensive intent without that side
        ;     effect.
        LD      HL, forth_wordlist
        LD      (IY+UserArea.search_order),   L
        LD      (IY+UserArea.search_order+1), H
        LD      (IY+UserArea.search_order_depth),   1
        LD      (IY+UserArea.search_order_depth+1), 0
        PUSH    IY
        POP     HL
        LD      BC, UserArea.search_order + 2
        ADD     HL, BC                          ; HL = &slot[1]
        LD      B, 30                           ; 30 bytes (slot 1..15)
        XOR     A
.so_init_zero:
        LD      (HL), A
        INC     HL
        DJNZ    .so_init_zero

        ; 8e. CURRENT-WORDLIST init — default compilation wordlist = FORTH-WORDLIST.
        ;     ANS Forth 1994 §16.6.1.2193 SET-CURRENT default-state convention.
        LD      HL, forth_wordlist
        LD      (IY+UserArea.current_wordlist),   L
        LD      (IY+UserArea.current_wordlist+1), H

        ; 8f. DPL init — -1 (0xFFFF) sentinel meaning "no dot seen on last parse".
        ;     ANS Forth 1994 §3.4.1.3 dot-marker recogniser; DPL is a
        ;     de-facto Forth convention (fig-Forth / F83 / gforth) — NOT in ANS Core.
        LD      (IY+UserArea.dpl),   0xFF
        LD      (IY+UserArea.dpl+1), 0xFF

        ; 8g. FCB pool init — file-access foundation. Resets fcb_pool_bitmap,
        ;     zeros fcb_pool + fcb_dma_pool, and seeds fcb_byte_pos[] = 128
        ;     (sentinel: refill on first read).
        CALL    pool_init

        ; 8h. Phase-4 banking foundation —
        ;     zero-init the 29-entry bank-table[] shell AND the 29-byte
        ;     active_pages[] array in the reclaimed $D400-$DBFF CCP
        ;     region (single DJNZ pass covers both: shell at $D400+0..173,
        ;     active_pages at $D400+174..202), seed the five banking
        ;     UserArea cells, snapshot the live (HERE, LATEST, wordlist
        ;     head) triple into bank-table[0] so `0 BANK!` round-trips
        ;     once the active list is populated, and auto-enable MMU
        ;     mapping.
        ;     DJNZ loop pattern chosen for layout-stability parity with
        ;     `.so_init_zero` (LDIR cascade was ruled out for the same
        ;     layout-sensitive reason).
        LD      HL, BANK_TABLE_BASE
        LD      B, BANK_TABLE_SHELL_SIZE + ACTIVE_PAGES_SIZE    ; 174 + 29 = 203
        XOR     A
.bt_init_zero:
        LD      (HL), A
        INC     HL
        DJNZ    .bt_init_zero
        ; Seed banking UserArea cells: saved_bank = 0, current_bank = 0
        ; (portal page default), bank_table_base = $D400,
        ; bank_count = 0 (active list empty until the CL parser runs).
        LD      (IY+UserArea.saved_bank),       0
        LD      (IY+UserArea.saved_bank+1),     0
        LD      (IY+UserArea.current_bank),     0
        LD      (IY+UserArea.current_bank+1),   0
        LD      (IY+UserArea.triple_owner),     0       ; live triple owned by bank 0
        LD      (IY+UserArea.bank_table_base),   LOW BANK_TABLE_BASE
        LD      (IY+UserArea.bank_table_base+1), HIGH BANK_TABLE_BASE
        LD      (IY+UserArea.bank_count),       0
        LD      (IY+UserArea.bank_count+1),     0
        ; Prompt bank-indicator opt-in flag — default OFF (Story 22.2): the
        ; QUIT prompt is byte-identical to Phase-3 until PROMPT-SHOW-BANK enables it.
        LD      (IY+UserArea.prompt_show_bank),   0
        LD      (IY+UserArea.prompt_show_bank+1), 0
        ; Seed stub_alloc_tail = STUB_ALLOC_BASE ($D4CB), the first free
        ; byte after active_pages[] in the reclaimed $D400-$DBFF CCP region.
        ; stub_allocate (src/banking.asm) writes 4 B per stub and advances
        ; this cell.
        LD      HL, STUB_ALLOC_BASE
        LD      (IY+UserArea.stub_alloc_tail),   L
        LD      (IY+UserArea.stub_alloc_tail+1), H
        ; Snapshot live (HERE, LATEST, wordlist_head) → bank-table[0][0..5].
        ; HERE / LATEST live in UserArea (contiguous 4 bytes at offset
        ; UserArea.here); wordlist_head = the cell at `forth_wordlist` (the
        ; canonical FORTH-WORDLIST struct's first cell, WORDLIST_NEXT).
        ; Without this snapshot, `0 BANK!` would clobber HERE / LATEST with
        ; the zero-initialised bank-table[0]. The snapshot fires AFTER HERE
        ; (step 7) / LATEST (step 8b) / CURRENT-WORDLIST (step 8e) have
        ; settled, BEFORE the auto-BANK-MAPPING-ON below.
        LD      HL, user_area + UserArea.here
        LD      DE, BANK_TABLE_BASE
        LD      BC, 4                           ; 2 cells: HERE, LATEST
        LDIR
        LD      HL, (forth_wordlist)
        LD      (BANK_TABLE_BASE + 4), HL
        ; Clone bank-table[0] → bank-table[1..28] so first-visit BANK! to any
        ; unvisited bank doesn't load zeros over the live HERE / LATEST /
        ; wordlist_head cells. Without this, HERE=0 after first `N BANK!` and
        ; the very next WORD parse (every INTERPRET cycle calls WORD) writes
        ; its counted string at $0000, overwriting the CP/M BIOS `JP wboote`
        ; + `JP bdos_entry` dispatch vectors → next BDOS call JPs to garbage.
        ; The BANKS-CLEAR docstring (src/banking.asm) flagged a related
        ; trap for "dictionary-extending words" but missed that WORD itself
        ; writes to HERE on every parse. Hardware smoke at `BANK@ .` after
        ; `1 BANK!` surfaced the crash.
        LD      HL, BANK_TABLE_BASE
        LD      DE, BANK_TABLE_BASE + BANK_TABLE_ENTRY_SIZE
        LD      BC, BANK_TABLE_ENTRY_SIZE * (BANK_TABLE_CAP - 1)        ; 6 × 28 = 168
        LDIR
        ; Bank-N HERE COLD-init. Override the cloned `here` field of
        ; bank-table entries 1..28 to $8000 so every bank-N>0 dictionary
        ; starts page-resident at the slot-2 window base: bodies compiled
        ; there never straddle the $8000 boundary and never alias once
        ; stub dispatch enters them with their own page mapped.
        ; LATEST + wordlist_head clone semantics are UNCHANGED — kernel
        ; words stay findable in bank N per the bucket-skip contract;
        ; only `here` is overridden.
        ;
        ; The relevant hang class is portal-window dictionary aliasing —
        ; a test body compiled at/above $8000 fetched under a foreign
        ; mapping after its own BANK!. Kernel size only moves the
        ; dictionary's $8000 crossing point. This fix is guarded (BANK!
        ; -273 window guard, src/banking.asm) and regression-gated (make
        ; test-straddle-regression). See docs/adr-19-5-cross-bank-dispatch.md.
        ;
        ; Loop shape: entry stride 6 ([here:2][latest:2][wordlist_head:2]);
        ; from entry's byte 1 (here.high) to the next entry's byte 0
        ; (here.low) is +5 = BANK_TABLE_ENTRY_SIZE - 1.
        LD      HL, BANK_TABLE_BASE + BANK_TABLE_ENTRY_SIZE     ; &bank-table[1].here
        LD      DE, BANK_TABLE_ENTRY_SIZE - 1                   ; stride 5 after INC
        LD      B, BANK_TABLE_CAP - 1                           ; 28 entries
.bank_here_init:
        LD      (HL), LOW SLOT2_WINDOW_BASE                     ; here.low
        INC     HL
        LD      (HL), HIGH SLOT2_WINDOW_BASE                    ; here.high → window base ($8000)
        ADD     HL, DE
        DJNZ    .bank_here_init
        ; RST-$28 stub-dispatch vector install. Descriptor stubs are
        ; self-dispatching: stub byte 0 = $EF (RST $28) so NEXT's blind
        ; JP (HL) and the folded EXECUTE both vector through here to
        ; stub_dispatch (src/banking.asm) for bank-aware dispatch. Zero
        ; page is RAM under CP/M (BIOS IM-1 uses $0038; iz-cpm intercepts
        ; only $0000/$0005); the vector address is the single EQU
        ; STUB_DISPATCH_VECTOR (src/constants.asm).
        LD      A, $C3                                          ; JP opcode
        LD      (STUB_DISPATCH_VECTOR), A
        LD      HL, stub_dispatch
        LD      (STUB_DISPATCH_VECTOR+1), HL
        ;
        ; Auto BANK-MAPPING-ON: enable MMU mapping before banner.
        ; Inline body matches w_BANK_MAPPING_ON_cf (src/banking.asm); inlined
        ; rather than CALLed because the DEFCODE body ends in NEXT, not RET.
        LD      A, 1
        OUT     (0x74), A
        LD      (IY+UserArea.bank_mapping_state),   1
        LD      (IY+UserArea.bank_mapping_state+1), 0

        ; 8i. Phase-4 CL-tail parser — read CP/M command tail at $0080,
        ;     populate active_pages[] with portal-page + bank-list per
        ;     user invocation; apply defaults `22 35-3F` on empty tail.
        ;     Six edge-case warn-and-continue dispositions. See
        ;     cl_tail_parse below for the full source comment.
        CALL    cl_tail_parse

        ; 9. FORTH-WORDLIST is pre-populated in the binary (see src/wordlists.asm)
        ;    No runtime initialisation needed

        ; 10. Enter execution
        IFDEF TEST_MODE
            ; Regression test mode: run first test group, exit via BYE
            LD      DE, test_group_inner
            NEXT
        ELSE
            ; Normal mode: print startup banner then enter QUIT
            LD      BC, 0           ; Clean TOS
            LD      DE, cold_thread
            NEXT                    ; Enter banner thread
cold_thread:
        ; Line 1: "AntForth v2.0.0 (C) ant.org 2026"
        DW      w_LIT_cf, str_banner1
        DW      w_LIT_cf, STR_BANNER1_LEN
        DW      w_TYPE_cf
        DW      w_CR_cf
        ; Line 2: "MicroBeast - XXXX bytes free"
        DW      w_LIT_cf, str_banner2
        DW      w_LIT_cf, STR_BANNER2_LEN
        DW      w_TYPE_cf
        ; Calculate free bytes: BANK_TABLE_BASE - HERE.
        ; The dictionary HERE ceiling was lowered from
        ; (sp_base - PS_SIZE - RS_SIZE) ≈ $F4F6 (iz-cpm) / ~$DA00 (real MB)
        ; to BANK_TABLE_BASE = $D400 — banking infrastructure now occupies
        ; $D400-$DBFF.
        ; A MIN(stack-bottom, BANK_TABLE_BASE) - HERE form was considered;
        ; rejected because $D400 < (sp_base - 512) uniformly on both
        ; surfaces (iz-cpm sp_base≈$F6F6 → stack-bottom≈$F4F6; real MB
        ; sp_base≈$DC00 → stack-bottom≈$DA00 — both > $D400).
        DW      w_LIT_cf, BANK_TABLE_BASE
        DW      w_HERE_cf               ; ( bank_table_base here )
        DW      w_MINUS_cf              ; ( free_bytes )
        DW      w_U_DOT_cf              ; print unsigned number + space
        DW      w_LIT_cf, str_banner3
        DW      w_LIT_cf, STR_BANNER3_LEN
        DW      w_TYPE_cf               ; "bytes free"
        ; " - N banks available"
        DW      w_LIT_cf, str_banner_banks_sep
        DW      w_LIT_cf, STR_BANNER_BANKS_SEP_LEN
        DW      w_TYPE_cf               ; " - "
        DW      w_BANKS_cf              ; ( -- bank_count )
        DW      w_U_DOT_cf              ; print "N "
        DW      w_LIT_cf, str_banner_banks
        DW      w_LIT_cf, STR_BANNER_BANKS_LEN
        DW      w_TYPE_cf               ; "banks available"
        DW      w_CR_cf
        ; Line 3: "Type BYE to exit"
        DW      w_LIT_cf, str_banner4
        DW      w_LIT_cf, STR_BANNER4_LEN
        DW      w_TYPE_cf
        DW      w_CR_cf
        ; Enter QUIT (CODE word — NEXT will JP to its assembly directly)
        DW      w_QUIT_cf
        ENDIF

; ============================================================
; CL-tail parser.
;   Invoked between cold_start step 8h (banking foundation init) and
;   step 10 (banner thread entry). Reads $0080 (CP/M command tail
;   populated by the CCP: length byte then uppercased ASCII), walks
;   the tail, probes each candidate page via cl_probe_and_add
;   (src/banking.asm), and populates active_pages[] / bank_count.
;
;   STARTUP.FTH NOT the boot-config mechanism — bank availability
;   needed at banner-print time, before any .FTH file could run.
;
;   Tail syntax: `<portal> <bank-list>`
;     portal    = 1-2 hex digits  (e.g. `22`)
;     bank-list = range  `NN-MM`  (e.g. `35-3F`)
;                 OR list `NN,MM,PP,…`
;                 OR single `NN`
;                 OR whitespace-separated mix of the above.
;     The first hex byte parsed becomes active_pages[0] (portal);
;     all subsequent bytes append as bank-list entries.
;
;   Edge-case dispositions:
;     (i)   no args        → silent defaults `22 35-3F`
;     (ii)  bad token      → "bad? X"  warn + skip to next sep + continue
;     (iii) reverse range  → "range?"  warn + treat as empty + continue
;     (iv)  dup            → "dup? NN" warn + dedup silently + continue
;     (v)   probe-fail     → "probe? NN" warn + exclude + continue
;     (vi)  empty list     → "empty?"  warn + boot with BANKS=0
;
;   Register convention while parsing:
;     HL = tail walker ptr;  B = remaining tail bytes
;     Helpers cl_skip_ws / cl_parse_hex_byte advance HL/B (no save needed).
;     Helpers cl_process_page / cl_emit_hex_byte clobber HL/B — caller
;     saves via PUSH/POP HL/BC around them.
;     IY = user_area (set in step 4); cl_probe_and_add reads/writes
;     (IY+UserArea.bank_count).
;
;   No data-stack interaction (called from cold_start; SP = sp_base
;   minus a return address; balanced PUSH/POP). DE not used by the
;   parser at boot — IP is not yet meaningful before the banner-
;   thread NEXT.
; ============================================================
cl_tail_parse:
        LD      A, (0x0080)             ; tail length byte (CCP-populated)
        OR      A
        JP      Z, .defaults            ; empty tail → defaults

        LD      HL, 0x0081
        LD      B, A                    ; B = remaining bytes
        ; edge case (i) — silent defaults applies to BOTH empty AND
        ; all-whitespace tails. Initial cl_skip_ws scoops leading ws+commas;
        ; if it exhausts the tail (CY=1) we never had any tokens → defaults.
        CALL    cl_skip_ws
        JP      C, .defaults
        JR      .first_token
.tloop:
        CALL    cl_skip_ws
        JP      C, .post                ; tail exhausted
.first_token:
        ; HL → first hex char of token; B = remaining
        CALL    cl_parse_hex_byte       ; A = first hex byte; CY=err
        JR      C, .bad
        LD      D, A                    ; D = first byte (single or range-start)
        ; Look ahead at next char for '-' (range marker)
        LD      A, B
        OR      A
        JR      Z, .single              ; out of bytes → single page
        LD      A, (HL)
        CP      '-'
        JR      NZ, .single             ; not range marker → single page
        ; Range: consume '-', parse end byte
        INC     HL
        DEC     B
        JR      Z, .bad                 ; '-' with no end → bad
        CALL    cl_parse_hex_byte       ; A = range end; CY=err
        JR      C, .bad
        LD      E, A                    ; E = range end byte
        LD      A, D
        CP      E
        JR      Z, .single              ; D == E → single page
        JR      NC, .rev_range          ; D > E → reverse range warning
        ; D < E: walk D..E inclusive
        PUSH    HL
        PUSH    BC                      ; save tail-walker state
.rwalk:
        LD      A, D
        PUSH    DE                      ; preserve D, E across cl_process_page
        CALL    cl_process_page
        POP     DE
        ; M1 — cap-hit early exit: once bank_count reaches BANK_TABLE_CAP,
        ; cl_process_page emits one `cap?` per call. Break out of the range
        ; walk on the first cap-hit so the user sees one warning per range,
        ; not one per excess page.
        LD      A, (IY+UserArea.bank_count)
        CP      BANK_TABLE_CAP
        JR      Z, .rwalk_done
        INC     D
        LD      A, E
        CP      D
        JR      NC, .rwalk              ; E >= D → keep walking
.rwalk_done:
        POP     BC
        POP     HL
        JR      .after_token
.single:
        LD      A, D
        PUSH    HL
        PUSH    BC
        CALL    cl_process_page
        POP     BC
        POP     HL
.after_token:
        ; edge case (vi) gate — if token 1 produces no successful adds
        ; (bank_count still 0 after the first cl_process_page call), the
        ; portal page failed; fall through to .post which emits `empty?` and
        ; the banner reports `0 banks available`. For tokens 2+ bank_count
        ; is already > 0 so this is a no-op fall-through to JR .tloop.
        LD      A, (IY+UserArea.bank_count)
        OR      A
        JP      Z, .post
        JR      .tloop
.rev_range:
        ; "range?" + CRLF; continue
        PUSH    HL
        PUSH    BC
        LD      HL, str_range_q
        LD      B, str_range_q_len
        CALL    bdos_print_str
        CALL    bdos_crlf
        POP     BC
        POP     HL
        JR      .tloop
.bad:
        ; "bad? X" where X = offending char at (HL) (if B>0)
        PUSH    HL
        PUSH    BC
        LD      A, B
        OR      A
        JR      Z, .bad_no_arg
        LD      A, (HL)
        PUSH    AF
        LD      HL, str_bad_q
        LD      B, str_bad_q_len
        CALL    bdos_print_str
        LD      E, ' '
        CALL    bdos_putchar
        POP     AF
        LD      E, A
        CALL    bdos_putchar
        CALL    bdos_crlf
        JR      .bad_recover
.bad_no_arg:
        LD      HL, str_bad_q
        LD      B, str_bad_q_len
        CALL    bdos_print_str
        CALL    bdos_crlf
.bad_recover:
        POP     BC
        POP     HL
        ; Skip remaining non-separator chars (eat the bad token in full)
.bad_skip:
        LD      A, B
        OR      A
        JP      Z, .post
        LD      A, (HL)
        CP      '!'
        JP      C, .tloop               ; whitespace/control → resume parsing
        CP      ','
        JP      Z, .tloop
        INC     HL
        DEC     B
        JR      .bad_skip

.post:
        ; Parse done. Edge-case (vi): empty surviving list?
        LD      A, (IY+UserArea.bank_count)
        OR      A
        RET     NZ
        LD      HL, str_empty_q
        LD      B, str_empty_q_len
        CALL    bdos_print_str
        JP      bdos_crlf               ; tail-call

.defaults:
        ; silent defaults `22 35-3F`:
        ; portal $22, then banks $35..$3F (11 pages). Each routes
        ; through cl_process_page (probes; dup/cap/probe-fail warnings
        ; would still print if they ever trigger — should not on real
        ; hardware with stock MicroBeast banking).
        LD      A, 0x22
        CALL    cl_process_page
        LD      D, 0x35
.dloop:
        LD      A, D
        PUSH    DE
        CALL    cl_process_page
        POP     DE
        INC     D
        LD      A, D
        CP      0x40
        JR      C, .dloop
        RET

; ------------------------------------------------------------
; cl_process_page — probe-and-append one page with full edge-case handling.
;   Input:  A = candidate page byte
;   Clobbers: A, BC, DE, HL (caller saves anything it needs)
; ------------------------------------------------------------
cl_process_page:
        LD      C, A                    ; C = candidate (preserved through scan)
        ; --- Dup check (linear scan of active_pages[]) ---
        LD      A, (IY+UserArea.bank_count)
        OR      A
        JR      Z, .nodup
        LD      B, A
        LD      HL, ACTIVE_PAGES_BASE
.dscan:
        LD      A, (HL)
        CP      C
        JR      Z, .dup
        INC     HL
        DJNZ    .dscan
.nodup:
        ; --- Cap check (BANK_TABLE_CAP = 29) ---
        LD      A, (IY+UserArea.bank_count)
        CP      BANK_TABLE_CAP
        JR      Z, .cap
        ; --- Probe + append via shared helper ---
        LD      A, C
        CALL    cl_probe_and_add
        RET     NC                      ; PASS — done
        ; --- FAIL: "probe? NN" + CRLF; continue ---
        LD      HL, str_probe_q
        LD      B, str_probe_q_len
        CALL    bdos_print_str
        JR      .emit_space_hex_c
.dup:
        ; "dup? NN" + CRLF
        LD      HL, str_dup_q
        LD      B, str_dup_q_len
        CALL    bdos_print_str
        JR      .emit_space_hex_c
.cap:
        ; "cap?" + CRLF (no arg — cap is a parser-state fault)
        LD      HL, str_cap_q
        LD      B, str_cap_q_len
        CALL    bdos_print_str
        JP      bdos_crlf               ; tail-call
.emit_space_hex_c:
        ; bdos_putchar clobbers C (sets C=C_WRITE) — save candidate first
        LD      A, C
        PUSH    AF
        LD      E, ' '
        CALL    bdos_putchar
        POP     AF
        CALL    cl_emit_hex_byte
        JP      bdos_crlf               ; tail-call

; ------------------------------------------------------------
; cl_skip_ws — advance HL past spaces, tabs, control chars, commas.
;   Input:  HL = ptr, B = remaining bytes
;   Output: CY=0 → HL → next non-ws char, A = that char, B updated.
;           CY=1 → tail exhausted (B reached 0 walking ws).
; ------------------------------------------------------------
cl_skip_ws:
        LD      A, B
        OR      A
        JR      Z, .swend
.swloop:
        LD      A, (HL)
        CP      '!'
        JR      C, .swadv               ; < 0x21 → whitespace/control
        CP      ','
        JR      Z, .swadv
        OR      A                       ; CY=0
        RET
.swadv:
        INC     HL
        DJNZ    .swloop
.swend:
        SCF                             ; CY=1, exhausted
        RET

; ------------------------------------------------------------
; cl_parse_hex_byte — parse 1 or 2 uppercase hex digits at (HL).
;   Input:  HL = ptr, B = remaining bytes
;   Output: A = parsed byte (0..255); HL/B advanced past consumed digits;
;           CY=0 → success (1 or 2 hex digits consumed)
;           CY=1 → parse error (first char non-hex OR B=0 at entry);
;                   HL/B unchanged on error.
; ------------------------------------------------------------
cl_parse_hex_byte:
        LD      A, B
        OR      A
        SCF
        RET     Z                       ; B=0 → error, HL unchanged
        LD      A, (HL)
        CALL    cl_hex_digit_a          ; A → 0..15 or CY=1
        RET     C
        LD      C, A                    ; C = first digit
        INC     HL
        DEC     B
        JR      Z, .pdone               ; B=0 now → single-digit byte
        LD      A, (HL)
        CALL    cl_hex_digit_a
        JR      C, .pdone               ; non-hex → single-digit byte
        ; Two digits → combine
        SLA     C
        SLA     C
        SLA     C
        SLA     C
        OR      C                       ; A = high<<4 | low
        INC     HL
        DEC     B
        RET                             ; CY clear from OR
.pdone:
        LD      A, C                    ; A = single-digit value
        OR      A                       ; CY=0
        RET

; ------------------------------------------------------------
; cl_hex_digit_a — ASCII char → 0..15 or CY=1 on non-hex.
;   Input/Output: A. Uppercase-only (CCP-uppercased per CP/M convention).
; ------------------------------------------------------------
cl_hex_digit_a:
        CP      '0'
        JR      C, .hdbad
        CP      '9' + 1
        JR      C, .hddigit
        CP      'A'
        JR      C, .hdbad
        CP      'F' + 1
        JR      NC, .hdbad
        SUB     'A' - 10
        OR      A                       ; CY=0
        RET
.hddigit:
        SUB     '0'
        OR      A                       ; CY=0
        RET
.hdbad:
        SCF
        RET

; ------------------------------------------------------------
; cl_emit_hex_byte — emit A as 2 uppercase ASCII hex chars via BDOS.
;   Input: A. Clobbers: A, BC, DE, HL.
; ------------------------------------------------------------
cl_emit_hex_byte:
        PUSH    AF
        RRA
        RRA
        RRA
        RRA
        AND     0x0F
        CALL    cl_emit_hex_digit
        POP     AF
        AND     0x0F
        ; fall through
cl_emit_hex_digit:
        ; Classic Z80 nibble→ASCII via DAA (saves 2 B over conditional)
        ADD     A, 0x90
        DAA
        ADC     A, 0x40
        DAA
        LD      E, A
        JP      bdos_putchar            ; tail-call

; CL-tail parser warning string literals.
; Note: str_probe_q / str_cap_q already exist in src/banking.asm
; and are re-used here as cross-module label references.
str_bad_q:       DB "bad?"
str_bad_q_len    EQU 4
str_range_q:     DB "range?"
str_range_q_len  EQU 6
str_dup_q:       DB "dup?"
str_dup_q_len    EQU 4
str_empty_q:     DB "empty?"
str_empty_q_len  EQU 6

; === Inner interpreter (DOCOL, EXIT, LIT, BRANCH, ?BRANCH, EXECUTE) ===
        INCLUDE "inner_interpreter.asm"

; === Dictionary and hash ===
        INCLUDE "dictionary.asm"
        INCLUDE "hash.asm"

; === CODE primitives ===
        INCLUDE "stack_ops.asm"
        INCLUDE "arithmetic.asm"
        INCLUDE "logic.asm"
        INCLUDE "memory.asm"
        INCLUDE "double.asm"
        INCLUDE "pictured.asm"
        INCLUDE "control_flow.asm"
        INCLUDE "io.asm"
        INCLUDE "strings.asm"
        INCLUDE "number_prefixes.asm"
        INCLUDE "formatting.asm"

; === Higher-level components (depend on primitives) ===
        INCLUDE "outer_interpreter.asm"
        INCLUDE "compiler.asm"
        INCLUDE "assembler.asm"
        INCLUDE "system.asm"
        INCLUDE "exception.asm"
        INCLUDE "banking.asm"
        INCLUDE "file_access.asm"

; === Forth bootstrap definitions (depend on everything above) ===
        INCLUDE "bootstrap.asm"

        IFDEF TEST_MODE
; --- Test-only IMMEDIATE word for FIND +1 flag verification ---
w_TEST_IMMED:
        DEFCODE "TESTIMM", F_IMMEDIATE
w_TEST_IMMED_cf:
        NEXT                            ; No-op — exists only for FIND test

; === TEST_BRIDGE — CODE word to chain between test groups ===
; Resets parameter stack, return stack, and TOS, then starts next group thread.
; Usage: DW w_LIT_cf, test_group_next, w_TEST_BRIDGE_cf
; BC (TOS) = address of next test group thread (from LIT)
w_TEST_BRIDGE:
        DEFCODE "TEST-BRIDGE", 0
w_TEST_BRIDGE_cf:
        LD      H, B
        LD      L, C                    ; HL = next group address
        LD      SP, (sp_base)           ; Reset parameter stack
        LD      IX, (rp_base)           ; Reset return stack pointer
        LD      BC, 0                   ; Clean TOS (phantom)
        EX      DE, HL                  ; DE = next group address (new IP)
        NEXT                            ; Start next group

; --- Test colon definition: emits 'B' ---
; Manual construction (no DEFWORD macro) to control code field label
test_colon_header:
        DW      0               ; hash_link (not linked into dictionary)
        DB      10              ; count_flags: length 10, no flags
        DB      "TEST-COLON"    ; name
test_colon_cfa:                 ; Code field address (execution token)
        JP      DOCOL
        DW      w_LIT_cf, 'B'
        DW      w_EMIT_cf
        DW      EXIT_CODE

; === Test groups ===
; Each group is self-contained — no dependency on stack state from prior groups
        INCLUDE "tests/test_inner.asm"
        INCLUDE "tests/test_stack.asm"
        INCLUDE "tests/test_arithmetic.asm"
        INCLUDE "tests/test_io.asm"
        INCLUDE "tests/test_dictionary.asm"
        INCLUDE "tests/test_outer.asm"
        ENDIF

; === Wordlist struct + canonical FORTH-WORDLIST ===
; Must follow ALL DEFCODE/DEFWORD invocations (including TEST_MODE-only
; words like TESTIMM and TEST-BRIDGE) so the LUA _hash_buckets[] table is
; fully populated when the bucket-array is emitted.
        INCLUDE "wordlists.asm"

; === Runtime data areas ===
sp_base:        DW      0               ; Initial SP value, set during cold start (for DEPTH)
rp_base:        DW      0               ; Initial IX value, set during cold start (for QUIT)
; Banner-version is a same-length string: a same-length swap is zero
; binary cost for a version bump.
str_banner1:    DB      "AntForth v3.0.6 (C) ant.org 2026"
STR_BANNER1_LEN EQU     32
str_banner2:    DB      "MicroBeast - "
STR_BANNER2_LEN EQU     13
str_banner3:    DB      "bytes free"
STR_BANNER3_LEN EQU     10
; Line 2 extends with " - N banks available" where N = post-CL `BANKS`
; count. The separator is ASCII " - " (matches existing "MicroBeast - "
; convention; em-dash is non-7-bit-ASCII and not representable in the
; binary literal).
str_banner_banks_sep: DB " - "
STR_BANNER_BANKS_SEP_LEN EQU 3
str_banner_banks: DB "banks available"
STR_BANNER_BANKS_LEN EQU 15
str_banner4:    DB      "Type BYE to exit"
STR_BANNER4_LEN EQU     16
str_ok:         DB      " ok"
STR_OK_LEN      EQU     3
test_cell:      DW      0               ; Scratch cell for test threads
test_cell2:     DW      0               ; Scratch cell for test threads
test_find_dup:    DB      3, "DUP"        ; Counted string for FIND test
test_find_lc_dup: DB      3, "dup"        ; Lowercase — test case-insensitivity
test_find_plus:   DB      1, "+"          ; Single-char word
test_find_bad:    DB      5, "ZZZZZ"      ; Unknown word — should not be found
test_find_immed:  DB      7, "TESTIMM"   ; IMMEDIATE word — should return +1 flag
test_num_42:    DB      2, "42"         ; Counted string "42" for NUMBER? test
test_num_neg7:  DB      2, "-7"         ; Counted string "-7" for NUMBER? test
test_num_bad:   DB      3, "abc"        ; Non-numeric string for NUMBER? test
test_str_s:     DB      's'             ; Test string for TYPE test
test_str_t:     DB      't'             ; Test string for TYPE test
test_str_multi: DB      'z', '{'        ; Multi-char test string for TYPE loop test

num_buf:        DS      NUM_BUF_SIZE    ; Number-to-string conversion buffer
user_area:      DS      UserArea        ; User variable area (IY points here)
; BDOS function 10 input buffer — MUST be immediately before tib_buffer
bdos_input_buf: DS      1               ; max_len (set by ACCEPT before BDOS call)
bdos_input_len: DS      1               ; actual_len (filled by BDOS after call)
tib_buffer:     DS      TIB_SIZE        ; Terminal input buffer (BDOS writes chars here)
kernel_end:                             ; Label marking end of kernel
