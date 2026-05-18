; banking.asm — Phase-4 banking subsystem
; AntForth — A Forth for CP/M on Z80
;
; See docs/antforth-banking-redesign.md §5.1 for the canonical memory layout
; and §1 for the Phase-4 wordset. Story 17.1 ships the file shell with the
; bank-table[] cap/size constants, BANK-MAPPING-ON, and BANK-MAPPING-OFF.
; Stories 17.2–17.6 fill in BANK@ / BANK! / BANKS / +BANK / -BANK /
; BANKS-CLEAR / SET-BANK / .BANKS in this same file.
;
; The 2 KB region $D400-$DBFF is annexed to the kernel's fixed-memory
; claim per PD-P4-6 closure (CCP eviction; Story 16.1 hardware
; verification). Story 17.1 routes the bank-table[] base to $D400;
; Story 18.1 carves the descriptor-stub allocator out of the
; post-bank-table[] portion of this region.

; === Phase-4 banking constants ===
; bank-table[] cap = 29 entries per PD-P4-13 (architecture.md:386..402).
; Per-entry layout: here (2 B) + latest (2 B) + wordlist_head (2 B) =
; 6 B / 3 cells. Full plumbing of the triple swap on BANK! is Story
; 17.2 / Epic 19; Story 17.1 only declares the cell layout and
; zero-initialises the table shell in COLD (src/antforth.asm step 8h).
; The shell lives AT BANK_TABLE_BASE = $D400 (src/constants.asm), in
; the reclaimed $D400-$DBFF CCP region — NOT allocated by a DS
; directive (no kernel binary bytes consumed for the shell).
BANK_TABLE_CAP         EQU 29
BANK_TABLE_ENTRY_SIZE  EQU 6
BANK_TABLE_SHELL_SIZE  EQU BANK_TABLE_CAP * BANK_TABLE_ENTRY_SIZE   ; 174 B

; active_pages[]: dense logical-bank-index → physical-page mapping.
; Lives in the reclaimed $D400-$DBFF CCP region immediately after
; bank-table[] (no kernel binary bytes consumed). Read by BANK! to
; translate the popped logical index to the physical page written to
; MMU port 0x72 (slot 2); written by Story 17.3's +BANK / -BANK /
; BANKS-CLEAR. Zero-initialised in COLD alongside bank-table[].
; Footprint $D4AE..$D4CA — well under the 2 KB CCP claim's high edge.
ACTIVE_PAGES_BASE      EQU BANK_TABLE_BASE + BANK_TABLE_SHELL_SIZE   ; $D4AE
ACTIVE_PAGES_SIZE      EQU BANK_TABLE_CAP                            ; 29 B (1 byte / logical bank)

; === BANK-MAPPING-ON ( -- ) ===
;   Enable the MicroBeast MMU mapping (port 0x74 bit 0 set).
;   Updates UserArea.bank_mapping_state to 1.
;   Auto-run in COLD (src/antforth.asm cold_start, after pool_init).
;
; PD-P4-9 (architecture.md:323): port 0x74 is the MMU-mapping-enable
; register; bit 0 = enable. Confirmed against iz-cpm-banking @ 1777a85
; (src/cpm_machine.rs: PORT_MAP_ENABLE = 0x74,
;  `mapping_enabled = (value & 1) != 0`).
;
; antforth extension BANK-MAPPING-ON — see docs/antforth-banking-redesign.md §5.1
w_BANK_MAPPING_ON:
        DEFCODE "BANK-MAPPING-ON", 0
w_BANK_MAPPING_ON_cf:
        LD      A, 1
        OUT     (0x74), A
        LD      (IY+UserArea.bank_mapping_state),   1
        LD      (IY+UserArea.bank_mapping_state+1), 0
        NEXT

; === BANK-MAPPING-OFF ( -- ) ===
;   CP/M warm-boot escape (FR-P4-12). Jumps to BIOS WBOOT at $0000
;   to reload CCP and return to a healthy `B>` prompt. Never returns.
;
;   IMPLEMENTATION NOTE — literal port-0x74 write is INTENTIONALLY
;   NOT performed. A naive `OUT (0x74), A` with A=0 disconnects the
;   kernel from RAM in the next instruction fetch: the CPU sees
;   flash bank 0 (firmware code) at the slot-0 address it was
;   executing, falls through to the firmware reset path, and
;   triggers a full cold-boot (PIO/Display/RTC re-detect, RAM-disk
;   reformat, sector restore) — verified on real MicroBeast 2026-05-15
;   transcript `~/Downloads/beastty-20260515-193026.bin`. Story 17.1
;   AC10 dev-pass finding. The firmware-blessed transition path is
;   BIOS WBOOT at $EA03 (MicroBeast firmware beastos/bios.asm:55+164
;   `wboote JP bios_wboot`), reachable as `JP 0x0000` via the JP
;   wboote that bios_wboot sets up at address 0 (beastos/bios.asm:173-176).
;   Mapping stays enabled across warm-boot; CP/M operates with mapping
;   enabled (it's how the BIOS loaded antforth in the first place).
;
;   The kernel-side `bank_mapping_state` cell is NOT updated here —
;   the BIOS warm-boot destroys the antforth runtime before any
;   observer could read it back, so the cell write would be dead
;   code. The next antforth invocation runs COLD, which re-inits
;   `bank_mapping_state` to 1 (src/antforth.asm step 8h).
;
; antforth extension BANK-MAPPING-OFF — see docs/antforth-banking-redesign.md §5.1
w_BANK_MAPPING_OFF:
        DEFCODE "BANK-MAPPING-OFF", 0
w_BANK_MAPPING_OFF_cf:
        JP      0x0000          ; BIOS WBOOT — never returns

; === BANK@ ( -- n ) ===
;   Return the current logical bank index — i.e. (IY+UserArea.current_bank).
;   n is the index into the active bank list (NOT the physical page
;   number) per FR-P4-1. Initial value 0 (portal-page default); updated
;   by BANK! on successful bank switch. Available at the REPL and inside
;   colon definitions.
;
; antforth extension BANK@ — see docs/antforth-banking-redesign.md §5.4
w_BANK_AT:
        DEFCODE "BANK@", 0
w_BANK_AT_cf:
        PUSH    BC                                  ; save old TOS
        LD      C, (IY+UserArea.current_bank)
        LD      B, 0                                ; current_bank.high invariantly 0 (bounded < 29)
        NEXT

; === BANK! ( n -- ) ===
;   Switch to logical bank n.
;
;   Preconditions:
;     n must satisfy 0 <= n < bank_count (BC.high == 0 also required;
;     n is a logical bank-list index, never > 28 in practice). On
;     out-of-range, raises ABORT" bank?" — THROW -2 with "bank?"
;     message printed via the kernel-internal w_THROW_cf.kernel_entry
;     path (same shape as `(ABORT")` runtime at src/system.asm:164-171).
;     FR-P4-2 wording: `If n is not in the active bank list, raises
;     ABORT" bank?"`.
;
;     At Story 17.2 close, bank_count = 0 (active list empty until
;     Story 17.3's +BANK populates it / Story 17.4's CL parser auto-
;     populates at boot), so every BANK! invocation aborts. The swap
;     mechanism wired below is dormant in 17.2 — verified active by
;     Story 17.3 / Epic 19.
;
;   Effects on success:
;     1. MMU port write: OUT (0x72), active_pages[n]. Port 0x72 = slot 2
;        per iz-cpm-banking cpm_machine.rs:13-14 (PORT_BANK0..3 =
;        0x70..0x73); slot 2 = portal page per redesign §5.1/§5.2.
;        UNLIKE BANK-MAPPING-OFF (port 0x74, disconnects kernel from
;        RAM and triggers BIOS WBOOT — Story 17.1 AC10), the slot-2
;        page-ID write at port 0x72 is safe from kernel-disconnect
;        failure: the kernel binary lives in slot 0 ($0000-$3FFF);
;        switching slot 2 does not affect the address range the CPU
;        is currently fetching from.
;     2. Per-bank triple swap (PD-P4-3 / FR-P4-22):
;        save live (HERE, LATEST, wordlist_head) → bank-table[old][0..5]
;        then load bank-table[new][0..5] → live cells. wordlist_head =
;        the cell at `forth_wordlist` (canonical FORTH-WORDLIST struct's
;        WORDLIST_NEXT slot per src/wordlists.asm:336-337). "Initial
;        swap only" semantics at 17.2; full per-bank ,/COMPILE,/HERE/
;        LATEST plumbing is Epic 19.
;     3. (IY+UserArea.current_bank) ← n. (The high byte stays 0 — it is
;        zero at COLD and the precondition validates BC.high == 0 on
;        every entry, so the high-byte write is a known-zero no-op and
;        is elided to save 3 B.)
;
; antforth extension BANK! — see docs/antforth-banking-redesign.md §5.4
w_BANK_STORE:
        DEFCODE "BANK!", 0
w_BANK_STORE_cf:
        ; --- Precondition: BC.high == 0 AND BC.low < bank_count ---
        LD      A, B
        OR      A
        JR      NZ, .abort_bank
        LD      A, C
        CP      (IY+UserArea.bank_count)
        JR      NC, .abort_bank
        ; --- MMU port write: OUT (0x72), active_pages[n] ---
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC                              ; BC.high == 0 validated
        LD      A, (HL)
        OUT     (0x72), A
        ; --- Swap current_bank (read old; write new). High byte stays 0. ---
        LD      A, (IY+UserArea.current_bank)       ; A = old_bank
        LD      (IY+UserArea.current_bank), C       ; current_bank.low ← new
        ; DE = IP (inner-interpreter convention; src/inner_interpreter.asm:7).
        ; The LDIR cascade + EX DE,HL below clobber DE; preserve IP across the
        ; swap so the trailing NEXT resumes at the caller. Precedent: WORDLIST
        ; (src/wordlists.asm:48-63) does the same PUSH DE / POP DE around its
        ; LDIR. (Story 17.2 review fix — H1.)
        PUSH    DE                                  ; save IP — LDIR clobbers DE
        ; --- Save live → bank-table[old_bank][0..5] ---
        CALL    rpush_bc                            ; preserve new_bank across LDIR
        CALL    bank_offset_hl                      ; HL = &bank-table[A=old]
        EX      DE, HL                              ; DE = &bank-table[old]
        LD      HL, user_area + UserArea.here
        LD      BC, 4
        LDIR                                        ; HERE,LATEST → [0..3]; DE += 4
        LD      HL, (forth_wordlist)
        EX      DE, HL
        LD      (HL), E
        INC     HL
        LD      (HL), D                             ; wordlist_head → [4..5]
        ; --- Load bank-table[new_bank][0..5] → live ---
        CALL    rpop_bc                             ; BC = new_bank
        LD      A, C
        CALL    bank_offset_hl                      ; HL = &bank-table[new]
        LD      DE, user_area + UserArea.here
        LD      BC, 4
        LDIR                                        ; [0..3] → HERE,LATEST; HL += 4
        LD      DE, forth_wordlist
        LD      BC, 2
        LDIR                                        ; [4..5] → (forth_wordlist)
        POP     DE                                  ; restore IP
        ; --- Pop new TOS (BC = previous-second-from-top) ---
        POP     BC
        NEXT

.abort_bank:
        LD      HL, str_bank_q
        LD      B, str_bank_q_len
        CALL    bdos_print_str
        LD      BC, THROW_ABORT_QUOTE
        JP      w_THROW_cf.kernel_entry

str_bank_q:     DB "bank?"
str_bank_q_len  EQU 5

; bank_offset_hl — Given A = logical bank index in [0..28], returns
;   HL = &bank-table[A]. Internal helper for w_BANK_STORE_cf (called
;   twice per BANK! invocation). Clobbers A.
;
;   Compact path takes advantage of two invariants:
;     - BANK_TABLE_BASE = $D400 has low byte 0, so HL.high = HIGH
;       BANK_TABLE_BASE unchanged regardless of offset.
;     - Max index = BANK_TABLE_CAP-1 = 28, max offset = 28*6 = 168 < 256,
;       so the offset fits entirely in HL.low (no carry into HL.high).
;   ASSERTed below; any future redesign that changes either invariant
;   forces this helper to fall back to a longer HL-arithmetic shape.
bank_offset_hl:
    ASSERT (BANK_TABLE_BASE & 0xFF) == 0
    ASSERT (BANK_TABLE_CAP - 1) * BANK_TABLE_ENTRY_SIZE < 256
        ADD     A, A                                ; A = idx*2
        LD      L, A
        ADD     A, A                                ; A = idx*4
        ADD     A, L                                ; A = idx*6
        LD      L, A
        LD      H, HIGH BANK_TABLE_BASE             ; HL = &bank-table[A]
        RET

; === BANKS ( -- n ) ===
;   Push the count of currently-active banks (= length of the active
;   list). Reads (IY+UserArea.bank_count).
;
;   Implementation-vs-spec NOTE: FR-P4-3 names this word as "a VALUE
;   derived from the active bank-list length". Antforth has §6.2.2405
;   `VALUE` and §6.2.2295 `TO` both Deliberately-omitted in v2.0
;   (docs/ans-forth-core-compliance.md:453,458 — "Pairs with VALUE
;   (also omitted); deferred — out of v2.0 scope"). Shipping VALUE/TO
;   to back this single use is scope-creep against the Story 17.2
;   ~80 B envelope; a DEFCODE proxy reading a kernel cell has identical
;   user-observable stack effect ( -- n ) pushing the stored count.
;   Future enhancement (Epic N+1) can refactor `BANKS` to a real `VALUE`
;   once VALUE/TO ship. Story 17.2 dev-pass choice; see Q1 in story
;   17-2-bank-fetch-bank-store-banks-read-and-swap-primitives.md.
;   At Story 17.2 close bank_count = 0 (active list empty until
;   Story 17.3's +BANK / Story 17.4's CL parser populate it); BANKS
;   returns 0. Story 17.4 dev-pass updates the active-probe to assert
;   the configured-defaults count.
;
; antforth extension BANKS — see docs/antforth-banking-redesign.md §5.4
w_BANKS:
        DEFCODE "BANKS", 0
w_BANKS_cf:
        PUSH    BC                                  ; save old TOS
        LD      C, (IY+UserArea.bank_count)
        LD      B, 0                                ; bank_count.high invariantly 0 (bounded by BANK_TABLE_CAP=29)
        NEXT

; === +BANK ( page -- ) ===
;   Probe-on-add + append to active_pages[]. Switches slot 2 (port 0x72)
;   to the candidate page, writes two sentinels ($5A then $A5) to $8000,
;   and reads back. If either round-trip fails (ROM, unmapped, unstable),
;   the original $8000 byte and the caller's slot-2 mapping are restored
;   and ABORT" probe?" fires. On success, the original $8000 byte +
;   slot-2 mapping are restored, the candidate is appended to
;   active_pages[bank_count], and bank_count is incremented.
;
;   Cap check (PD-P4-13 / §9.4 closure — architecture.md:386..402): if
;   bank_count == BANK_TABLE_CAP (29), ABORT" cap?" fires BEFORE the
;   probe. The active list is NOT modified on either ABORT path.
;
;   Probe correctness — two-sentinel sweep (Q1 dev-pass disposition,
;   conservative). $5A alone would false-positive a ROM page whose
;   byte at $8000 happens to equal $5A; $A5 catches that case because
;   the original byte cannot equal both sentinels.
;
;   Saved caller slot-2 page is read via `IN A, (0x72)` (port readback —
;   iz-cpm-banking cpm_machine.rs:138 returns bank_map[2]; real
;   MicroBeast firmware exposes the same read-back). This avoids the
;   chicken-and-egg of needing a populated active_pages[current_bank]
;   on the FIRST +BANK call (when bank_count = 0 at boot).
;
;   No dedup at this surface (Q2 dev-pass disposition). Duplicate
;   pages append; downstream -BANK removes the first match, leaving
;   subsequent duplicates intact. CL parser (Story 17.4) owns
;   surface-level dedup per PD-P4-14 (§9.3 closure).
;
; antforth extension +BANK — see docs/antforth-banking-redesign.md §1
w_PLUS_BANK:
        DEFCODE "+BANK", 0
w_PLUS_BANK_cf:
        ; --- Cap check (AC2 / PD-P4-13) ---
        LD      A, (IY+UserArea.bank_count)
        CP      BANK_TABLE_CAP
        JP      Z, .abort_cap
        ; --- Probe + append via shared helper (Story 17.4 refactor) ---
        ; Helper preserves DE (IP) so no PUSH/POP DE wrap is needed; the
        ; old D/E scratch arrangement (D=caller_slot2_page, E=saved_orig)
        ; is replaced by B/AF-via-stack inside the helper.
        LD      A, C                                ; A = candidate page (TOS.low)
        CALL    cl_probe_and_add
        JR      C, .abort_probe
        POP     BC                                  ; new TOS
        NEXT

.abort_probe:
        LD      HL, str_probe_q
        LD      B, str_probe_q_len
        CALL    bdos_print_str
        LD      BC, THROW_ABORT_QUOTE
        JP      w_THROW_cf.kernel_entry

.abort_cap:
        LD      HL, str_cap_q
        LD      B, str_cap_q_len
        CALL    bdos_print_str
        LD      BC, THROW_ABORT_QUOTE
        JP      w_THROW_cf.kernel_entry

; ============================================================
; cl_probe_and_add — shared probe-and-append (Story 17.4 factoring).
;
;   Used by:
;     - w_PLUS_BANK_cf (above): on CY=1, JPs to .abort_probe (ABORT" probe?").
;     - cl_tail_parse  (src/antforth.asm): on CY=1, emits "probe? NN" +
;       continues with the next CL-tail token (warn-and-continue per
;       PD-P4-14 (v) / §9.3 closure).
;
;   Body identical to the post-cap-check, pre-NEXT section of the
;   pre-17.4 w_PLUS_BANK_cf; refactored 2026-05-16 for Story 17.4 reuse.
;
;   Input:  A = candidate page byte.
;   Output: CY=0 on PASS — page appended to active_pages[bank_count];
;                          bank_count incremented; slot 2 restored to
;                          caller's mapping; $8000 byte restored.
;           CY=1 on FAIL — slot 2 restored; $8000 byte restored;
;                          NO console output (caller owns warning text);
;                          active_pages[] / bank_count unchanged.
;   Clobbers: A, B, C, HL. DE preserved (callers may use DE as IP).
;   Caller is responsible for the cap check (BANK_TABLE_CAP).
; ============================================================
cl_probe_and_add:
        LD      C, A                                ; C = candidate page
        IN      A, (0x72)                           ; A = caller_slot2_page
        LD      B, A                                ; B = caller_slot2_page (saved)
        LD      A, C
        OUT     (0x72), A                           ; switch slot 2 to candidate
        LD      HL, 0x8000
        LD      A, (HL)
        PUSH    AF                                  ; stash orig $8000 byte
        LD      A, 0x5A
        LD      (HL), A
        CP      (HL)
        JR      NZ, .cpa_fail
        LD      A, 0xA5
        LD      (HL), A
        CP      (HL)
        JR      NZ, .cpa_fail
        ; --- PASS: restore $8000 + caller's slot 2 + append + increment ---
        POP     AF                                  ; recover orig $8000 byte
        LD      (HL), A                             ; restore $8000
        LD      A, B
        OUT     (0x72), A                           ; restore caller's slot 2
        LD      HL, ACTIVE_PAGES_BASE
        LD      A, (IY+UserArea.bank_count)
        ADD     A, L                                ; idx ≤ 28; $AE+28=$CA (no carry)
        LD      L, A                                ; HL = &active_pages[bank_count]
        LD      (HL), C                             ; store candidate
        INC     (IY+UserArea.bank_count)
        OR      A                                   ; clear CY (PASS)
        RET
.cpa_fail:
        POP     AF                                  ; recover orig $8000 byte (in A)
        LD      (HL), A                             ; restore $8000 (HL still = $8000)
        LD      A, B
        OUT     (0x72), A                           ; restore caller's slot 2
        SCF                                         ; CY=1 (FAIL)
        RET

str_probe_q:     DB "probe?"
str_probe_q_len  EQU 6
str_cap_q:       DB "cap?"
str_cap_q_len    EQU 4

; === -BANK ( page -- ) ===
;   Linear-search active_pages[0..bank_count-1] for page; on hit, shift
;   tail down by one byte via LDIR and decrement bank_count. On miss
;   (or empty list), silent no-op (no THROW) per FR-P4-8.
;
;   -BANK does NOT touch the MMU port; the currently-mapped slot-2 page
;   stays mapped. If the removed entry's logical index was below
;   current_bank, current_bank is left unchanged — the kernel cell may
;   now point to a different physical page than before, and the user
;   is responsible for re-issuing BANK! to re-establish the intended
;   mapping (Q3 dev-pass disposition (a) — no current_bank bookkeeping).
;
;   The vacated tail byte at the old active_pages[bank_count-1]
;   position is NOT zeroed — it is unreachable post-decrement per the
;   BANK! precondition, the -BANK search bounds, and .BANKS iteration
;   cap (Q4 dev-pass disposition).
;
; antforth extension -BANK — see docs/antforth-banking-redesign.md §1
w_MINUS_BANK:
        DEFCODE "-BANK", 0
w_MINUS_BANK_cf:
        LD      A, (IY+UserArea.bank_count)
        OR      A
        JR      Z, .not_found                       ; empty list — no-op
        LD      B, A                                ; B = bank_count (loop counter)
        LD      HL, ACTIVE_PAGES_BASE
        LD      A, C                                ; A = page (TOS low byte)
.search_loop:
        CP      (HL)
        JR      Z, .found
        INC     HL
        DJNZ    .search_loop
.not_found:
        POP     BC                                  ; new TOS
        NEXT

.found:
        ; HL → &active_pages[k]; B = bank_count - k. Bytes to shift = B - 1.
        DEC     B
        JR      Z, .post_shift                      ; match at tail — skip LDIR
        ; Save IP across LDIR — LDIR uses DE as the copy destination and
        ; clobbers it (same shape as BANK! H1 fix).
        PUSH    DE                                  ; save IP
        LD      D, H
        LD      E, L                                ; DE = match pos (dst)
        INC     HL                                  ; HL = match+1 (src)
        LD      C, B                                ; LDIR count → BC (B was bytes-to-shift)
        LD      B, 0
        LDIR
        POP     DE                                  ; restore IP
.post_shift:
        DEC     (IY+UserArea.bank_count)
        POP     BC                                  ; new TOS
        NEXT

; === BANKS-CLEAR ( -- ) ===
;   Reset bank_count to 0. The active_pages[] byte array is NOT zeroed
;   (Q4 dev-pass disposition) — the bytes become unreachable when
;   bank_count == 0 because BANK!'s precondition `n < bank_count` fails
;   for every n; -BANK's search loop bounds itself by bank_count; .BANKS
;   (Story 17.5) iterates 0..bank_count-1. A subsequent +BANK rebuilds
;   the list starting at index 0, overwriting the stale tail bytes as
;   it goes.
;
;   current_bank is NOT updated — its stale value is benign until the
;   next BANK!, which will ABORT" bank?" (precondition fails). After a
;   +BANK rebuild, the user is expected to re-issue BANK! to map the
;   intended logical index.
;
;   USER-FACING TRAP — call `0 BANK!` BEFORE BANKS-CLEAR when current_bank
;   != 0. BANK!'s swap saves live HERE/LATEST/wordlist_head to
;   bank-table[old] and loads bank-table[new]. After `N BANK!` (N != 0
;   and bank N never visited before), the live HERE/LATEST cells hold
;   bank-table[N]'s zero-init state. Calling BANKS-CLEAR while in that
;   state leaves HERE = 0 / LATEST = 0; the next dictionary-extending
;   word (`: FOO ... ;`, VARIABLE, CREATE) writes to address 0 and
;   silently corrupts low memory. The safe rebuild sequence is:
;     N BANK! ... 0 BANK! BANKS-CLEAR ... +BANK ... BANK!
;   The 0 BANK! before BANKS-CLEAR swaps the kernel-snapshot triple back
;   into the live cells, so the dictionary stays consistent across the
;   clear-and-rebuild. Probes 7 + F (tests/banking_tests.fth) follow
;   this pattern.
;
; antforth extension BANKS-CLEAR — see docs/antforth-banking-redesign.md §1
w_BANKS_CLEAR:
        DEFCODE "BANKS-CLEAR", 0
w_BANKS_CLEAR_cf:
        LD      (IY+UserArea.bank_count), 0
        NEXT

; === SET-BANK ( page slot -- ) ===
;   Raw MMU port write: OUT (0x70+slot), page. Diagnostic-only escape
;   hatch (FR-P4-10) for hardware investigation. Does NOT update
;   (IY+UserArea.current_bank), does NOT update bank_count, does NOT
;   touch active_pages[], does NOT probe. The user takes responsibility
;   for the resulting machine state.
;
;   slot is NOT range-checked. FR-P4-10 explicit: "diagnostics only —
;   bad arguments produce undefined hardware behaviour". Writing to
;   slot 0 (port 0x70) disconnects the kernel from its own code in the
;   next instruction fetch (Story 17.1 BANK-MAPPING-OFF analysis).
;
; antforth extension SET-BANK — see docs/antforth-banking-redesign.md §1;
; diagnostics only — bad arguments produce undefined hardware behaviour;
; does NOT update current_bank or bank_count.
w_SET_BANK:
        DEFCODE "SET-BANK", 0
w_SET_BANK_cf:
        LD      A, C                                ; A = slot (TOS low byte)
        OR      0x70                                ; A = port (0x70 + slot)
        LD      C, A                                ; C = port for OUT (C), A
        LD      B, 0
        POP     HL                                  ; HL = page (second-of-stack)
        LD      A, L                                ; A = page low byte
        OUT     (C), A                              ; raw MMU write
        POP     BC                                  ; new TOS
        NEXT

; ============================================================
; === .BANKS ( -- ) ===
;   Print a status table of the current banking configuration:
;     header row + one row per active bank + totals row.
;   Each row shows: logical-bank-index (decimal, right-aligned), physical-page
;   (2-hex uppercase), current-bank marker ('*' for the row whose index
;   matches BANK@; space otherwise), per-bank `used` and `free` columns.
;
;   Format (Q1=a compact form, 23 chars per row + CRLF):
;     "BANK PAGE   USED   FREE\r\n"   ; header — USED right-edge col 15,
;     "   0   22 *    0  16384\r\n"   ; FREE right-edge col 22; column
;     "   1   35      0  16384\r\n"   ; right-edges aligned across header,
;     ...                              ; per-bank rows, and totals row
;     "TOTAL          0 196608\r\n"   ; (totals via D.R width-6).
;
;   Per-bank used = 0 and per-bank free = 16384 are PLACEHOLDERS (literal
;   strings) per the AC2 minimal-form scope. Epic 19's bank-aware ':' makes
;   the per-bank HERE real and updates .BANKS to read live values.
;
;   Totals: used = 0 (sum of zero placeholders); free = bank_count * 16384
;   (sum of per-bank 16384 placeholders). Computed as 24-bit value via
;   `bank_count << 14` then printed via D.R right-aligned in 6-char field.
;
; Q1=a (column layout): compact form. Per-row width 23 chars + CRLF; fits
;   80 cols at the 29-bank cap (worst case "TOTAL          0 475136\r\n").
; Q2=b (totals computation): post-loop, double-cell value
;   d-low = (bank_count & 3) << 14, d-high = bank_count >> 2.
;   The story Q2(b) print recommendation cites `w_U_DOT_R_cf` (~10-15 B);
;   that is INFEASIBLE because (a) U.R is a DEFWORD not a DEFCODE, and
;   (b) max free total = 29*16384 = 475136 overflows the 16-bit single-cell
;   that U.R consumes. Fix: switch IP to a tiny inline thread that calls
;   D.R (double-cell right-aligned) + CR + EXIT. Disposition documented
;   here; no project-lead escalation needed — the computation formula is
;   unchanged, only the print primitive switches single→double.
; Q3=c (BANK-column print): hand-rolled inline decimal printer via small
;   helper print_bank_col_4 (4-char right-aligned for 0..28).
; Q4=a (PAGE col bare hex): re-uses cl_emit_hex_byte (Story 17.4 helper).
; Q5=a (zero-bank case): zero per-bank rows, totals = 0; header + totals
;   row only, no per-bank-row loop entry.
; Q6=a-extended (envelope): accept-with-rationale forward per Story 17.4
;   precedent ACCEPTED 2026-05-16; Epic-17 retro absorbs cumulative overage.
; Q7=a (probes): sentinel-and-grep via Makefile (Story 17.4 pattern).
;
; antforth extension .BANKS — see docs/antforth-banking-redesign.md §1
; .BANKS — Epic 17 minimal form. Per-bank used/free are placeholders
; (literal "0" / "16384"); Epic 19's bank-aware ':' makes them real
; (probe: `5 BANK!  : SOME-WORD ; ` → used in bank 5 should reflect body
; byte-count). Epic 22 polishes column formatting + adds optional REPL
; prompt indicator integration (see architecture.md:483 Epic-22 budget).
w_DOT_BANKS:
        DEFCODE ".BANKS", 0
w_DOT_BANKS_cf:
        ; --- Save caller's TOS + IP so the body can use BC/DE/HL freely. ---
        ; Caller TOS → data stack (becomes SP-top-2 after we push d-low/d-high
        ; for the totals D.R call; D.R consumes 3 cells and lands BC back on
        ; the saved caller-TOS at exit).
        ; Caller IP → R-stack (recovered by EXIT_CODE in the inline totals
        ; thread; resumes caller's thread after the trailing CR).
        PUSH    BC                                  ; save caller TOS
        CALL    rpush_de                            ; save caller IP

        ; --- Print header row ---
        LD      HL, str_dot_banks_hdr
        LD      B, str_dot_banks_hdr_len
        CALL    bdos_print_str
        CALL    bdos_crlf

        ; --- Per-row loop ---
        ; B = remaining row count (DJNZ); C = current logical index (counts up).
        ; bank_count == 0: skip the loop (Q5=a edge case — header + totals only).
        LD      A, (IY+UserArea.bank_count)
        OR      A
        JR      Z, .totals
        LD      B, A
        LD      C, 0
.row_loop:
        PUSH    BC                                  ; save loop state

        ; 1. BANK col: 4-char right-aligned decimal for C value
        LD      A, C
        CALL    print_bank_col_4                    ; clobbers A/BC/DE/HL

        ; 2. "   " sep (BANK → PAGE)
        LD      HL, str_3sp
        LD      B, 3
        CALL    bdos_print_str

        ; 3. PAGE col: load active_pages[C], emit as 2-hex via cl_emit_hex_byte.
        ;    Compute marker char before cl_emit_hex_byte clobbers A.
        POP     BC                                  ; recover B=count, C=index
        PUSH    BC
        LD      A, C
        CP      (IY+UserArea.current_bank)          ; Z if this row's idx is current bank
        LD      L, ' '
        JR      NZ, .no_star
        LD      L, '*'
.no_star:
        PUSH    HL                                  ; stash marker char (L) across page load
        LD      A, C
        ADD     A, LOW ACTIVE_PAGES_BASE            ; idx ≤ 28; $AE+28=$CA (no carry)
        LD      L, A
        LD      H, HIGH ACTIVE_PAGES_BASE
        LD      A, (HL)                             ; A = active_pages[C]
        CALL    cl_emit_hex_byte                    ; emits 2 ASCII hex chars; clobbers A/BC/DE/HL

        ; 4. " " sep (PAGE → marker)
        LD      E, ' '
        CALL    bdos_putchar

        ; 5. Marker char
        POP     HL
        LD      E, L
        CALL    bdos_putchar

        ; 6. USED + FREE placeholders + CRLF as one literal
        LD      HL, str_used_free_crlf
        LD      B, str_used_free_crlf_len
        CALL    bdos_print_str

        ; 7. Loop epilogue
        POP     BC                                  ; recover B=count, C=index
        INC     C
        DJNZ    .row_loop

.totals:
        ; --- Totals row: "TOTAL          0 " prefix + 6-char right-aligned free ---
        LD      HL, str_total_pfx
        LD      B, str_total_pfx_len
        CALL    bdos_print_str

        ; Compute bank_count * 16384 as double:
        ;   d-low  = (bank_count & 3) << 14  → high byte = (bank_count & 3) << 6, low = 0
        ;   d-high = bank_count >> 2         (max 29 >> 2 = 7)
        LD      A, (IY+UserArea.bank_count)
        LD      D, A                                ; D = bank_count
        AND     3                                   ; A = bank_count & 3
        ADD     A, A
        ADD     A, A
        ADD     A, A
        ADD     A, A
        ADD     A, A
        ADD     A, A                                ; A = (bank_count & 3) << 6
        LD      H, A
        LD      L, 0                                ; HL = d-low
        SRL     D
        SRL     D                                   ; D = bank_count >> 2 = d-high
        PUSH    HL                                  ; d-low → data stack
        LD      C, D
        LD      B, 0                                ; BC = d-high
        PUSH    BC                                  ; d-high → data stack
        LD      BC, 6                               ; TOS = +n field width

        ; Switch IP to inline totals thread: NEXT will dispatch through
        ; D.R (double-cell right-aligned) → CR → EXIT_CODE.
        ; EXIT_CODE pops the caller's IP (saved at entry via rpush_de) and
        ; resumes the caller's thread. D.R consumes (d-low d-high +n) and
        ; lands BC on the caller TOS saved at the top of PUSH BC at entry,
        ; satisfying the ( -- ) stack effect.
        LD      DE, .totals_thread
        NEXT

.totals_thread:
        DW      w_D_DOT_R_cf                        ; ( d-low d-high +n -- )
        DW      w_CR_cf                             ; emit CRLF
        DW      EXIT_CODE                           ; restore caller IP, return

; print_bank_col_4 — Print A as decimal right-aligned in a 4-char field.
;   Input:  A = value in [0..29] (logical bank index)
;   Output: 4 chars emitted via BDOS ("   0".."  28")
;   Clobbers: A, BC, DE, HL
;
;   Single call site (per-row BANK column); inline cost ~25 B inline-emit per
;   row vs ~40 B via this helper + 3 B CALL = ~43 B helper-encapsulated. The
;   helper form is preferred for readability + future re-use if .BANKS gains
;   a second decimal column (Epic 22 polish).
print_bank_col_4:
        ; A is clobbered by bdos_putchar (BDOS func 2 returns through A);
        ; stash via PUSH AF across the two leading-space emissions so the
        ; tens/ones decode below sees the original index value.
        PUSH    AF
        LD      E, ' '
        CALL    bdos_putchar
        LD      E, ' '
        CALL    bdos_putchar
        POP     AF
        ; Decide single vs two digits.
        CP      10
        JR      C, .pbc_single
        ; Two-digit: peel tens via subtract-loop (max 2 iterations for 0..29).
        LD      C, '0' - 1
.pbc_tens:
        INC     C
        SUB     10
        JR      NC, .pbc_tens
        ADD     A, 10                               ; A = ones; C = tens char
        PUSH    AF
        LD      E, C
        CALL    bdos_putchar
        POP     AF
        JR      .pbc_ones
.pbc_single:
        ; A also clobbered by bdos_putchar — re-stash across 3rd leading space.
        PUSH    AF
        LD      E, ' '
        CALL    bdos_putchar                        ; 3rd leading space
        POP     AF
.pbc_ones:
        ADD     A, '0'
        LD      E, A
        JP      bdos_putchar                        ; tail-call

; ============================================================
; === Descriptor-stub allocator (Story 18.1, the (γ) mechanism) ===
;
;   Allocates one 4-byte descriptor stub at (IY+UserArea.stub_alloc_tail)
;   then advances the cell by 4. The stub's address IS the word's xt
;   per PD-P4-1 + redesign §2.1 (`docs/antforth-banking-redesign.md:34..42`);
;   xt portability across BANK! (FR-P4-17) is automatic because the stub
;   lives in fixed memory (the CCP-evicted $D400-$DBFF annex; see
;   PD-P4-6 / architecture.md:271..285).
;
;   Stub layout per PD-P4-11 (architecture.md:347..365):
;     byte 0 — target_bank as a signed byte. $FF = -1 = fixed-memory
;              marker per FR-P4-13; $00..$1C = active logical bank
;              index 0..28 per PD-P4-13 (29-entry cap). Caller owns
;              range-checking (the allocator does NOT validate).
;     byte 1 — $C3 (Z80 absolute JP opcode).
;     bytes 2..3 — target_addr lo/hi. Story 18.3's EXECUTE chokepoint
;              reads byte 0, optionally writes the MMU port for slot 2,
;              then jumps to stub_addr+1 to execute the JP.
;
;   No DS directive backs the output region — the bytes are claimed at
;   constant addresses in the fixed-memory map (STUB_ALLOC_BASE = $D4CB,
;   src/constants.asm). COLD (src/antforth.asm step 8h) seeds
;   stub_alloc_tail = STUB_ALLOC_BASE; each allocation writes 4 B and
;   advances the cell. Available region $D4CB..$DBFF = 1845 B = up to
;   461 stubs in the CCP-evicted region alone (Epic 19+ may overflow
;   into the HERE region — out of Story 18.1 scope).
;
;   Story 18.1 is layout-only: callers are the AC7 probes (via the
;   (stub-allocate) wrapper below); execute-through is Story 18.3
;   (EXECUTE switch) + Story 18.2 (cross_bank_return trampoline).
;   Story 18.4 (BANK-OF) reads byte 0; Epic 19's `:` calls the
;   allocator from `;`.
;
;   antforth Phase-4 — see docs/antforth-banking-redesign.md §2.1 (γ
;   mechanism). Banking subsystem header at src/banking.asm:1..14.
; ============================================================
; stub_allocate — Kernel-internal allocator.
;
;   Input:  B  = target_bank as a signed byte (-1 = fixed-memory marker
;                per FR-P4-13; 0..28 = logical bank index per PD-P4-13).
;                Out-of-range values are UNDEFINED INPUT — caller owns
;                the bounds check (Stories 18.3 / 19.x).
;           DE = target_addr_in_bank (16-bit; for fixed-memory targets
;                this is a fixed-memory address; for banked targets it
;                is an address in the target bank's $8000-$BFFF body).
;   Output: HL = stub address = the word's xt (per PD-P4-1 + redesign §2.1).
;   Clobbers: HL is the output (was used as the write-cursor across the
;                 4 bytes; restored to stub_addr via PUSH/POP). No other
;                 main-set register is modified: A / B / C / D / E and
;                 flags are all preserved. The alt-set is untouched
;                 (no EXX in the body). Lesson 17-D PUSH/POP DE wrap
;                 NOT required: no EX DE,HL / no LDIR / no DE-as-temp
;                 — DE is read-only (used as the source for `LD (HL),E`
;                 and `LD (HL),D` to emit bytes 2-3). BC.high unchanged
;                 (only B.low = target_bank consumed).
;
;                 Callers in Stories 18.3 / 19.x can rely on the full
;                 main-set preservation contract — no caller-save wrap
;                 is needed around `CALL stub_allocate`.
;   Side effect: writes 4 B at (stub_alloc_tail); advances
;                stub_alloc_tail by 4. No range check on the upper
;                bound of the output region — overflow into the HERE
;                region is an Epic 21 / future concern (the
;                CCP-evicted region holds 461 stubs; current Phase-4
;                workloads stay well under).
stub_allocate:
        LD      L, (IY+UserArea.stub_alloc_tail)
        LD      H, (IY+UserArea.stub_alloc_tail+1)
        PUSH    HL                                  ; save stub_addr (= return value)
        LD      (HL), B                             ; byte 0: target_bank
        INC     HL
        LD      (HL), 0xC3                          ; byte 1: JP opcode
        INC     HL
        LD      (HL), E                             ; byte 2: target_addr lo
        INC     HL
        LD      (HL), D                             ; byte 3: target_addr hi
        INC     HL
        LD      (IY+UserArea.stub_alloc_tail),   L  ; advance tail by 4
        LD      (IY+UserArea.stub_alloc_tail+1), H
        POP     HL                                  ; HL = stub_addr (xt)
        RET

; === (stub-allocate) ( target_addr target_bank -- xt ) ===
;   Forth-callable wrapper around stub_allocate. Layout-only kernel
;   surface for Story 18.1's AC7 probes (Probe-18.1-A/B/C) — keeps the
;   4-byte layout knowledge in one place (the kernel) rather than
;   spreading it into test code. Stories 18.3 / 19.x consume the
;   allocator via direct CALL stub_allocate inside their own
;   DEFCODE bodies; this (stub-allocate) wrapper is the only
;   Forth-callable surface in Story 18.1.
;
;   target_bank is consumed as a signed byte (low byte of TOS); the
;   high byte of TOS is discarded. target_addr is consumed as a 16-bit
;   cell (the NOS at entry).
;
; antforth Phase-4 — see docs/antforth-banking-redesign.md §2.1
w_PAREN_STUB_ALLOCATE:
        DEFCODE "(stub-allocate)", 0
w_PAREN_STUB_ALLOCATE_cf:
        LD      B, C                                ; B = target_bank.low (signed byte)
        POP     HL                                  ; HL = target_addr (NOS)
        PUSH    DE                                  ; save IP across allocator call
        EX      DE, HL                              ; DE = target_addr; HL = old IP (scratch)
        CALL    stub_allocate                       ; in: B=bank, DE=addr; out: HL=xt; main-set preserved (see contract above)
        POP     DE                                  ; restore IP
        LD      B, H
        LD      C, L                                ; BC = HL = xt (new TOS)
        NEXT

; === BANK-OF ( xt -- n ) ===
;   One-byte read of descriptor-stub byte 0, sign-extended to a single
;   cell. Returns the bank a word lives in: -1 for fixed-memory words
;   (FR-P4-13 marker, stored as signed $FF), 0..28 for banked words
;   (active-bank index per PD-P4-13).
;
;   Implementation contract:
;     - Input: BC = xt = stub address (typically in [STUB_ALLOC_BASE,
;       $DC00) = [$D4CB, $DC00)). No range check on xt — caller owns
;       valid-stub-address discipline, matching the stub_allocate
;       undefined-input contract at src/banking.asm:751..769.
;     - Output: BC = n = sign-extended byte at xt+0.
;       $FF → $FFFF (= -1); $00..$1C → $0000..$001C (= 0..28).
;     - Sign-extension idiom: RLA / SBC A, A — bit 7 → carry; SBC A,A
;       yields $FF if carry set, $00 if clear (Q2 decision: 2 B / 8 T;
;       smallest + no branches; same idiom is widely used in Zilog
;       programming guides).
;     - EXX-hygiene audit (S7 / NFR-P4-34; docs/register-conventions.md
;       §3 leaf-level rule + §7 EXX-using inventory): body reads only
;       main-set BC / HL / A. No EXX. No EX DE,HL. No LDIR. No
;       DE-as-temp. Lesson 17-D PUSH/POP DE wrap NOT required.
;     - Stack effect: single-cell-in / single-cell-out — TOS replaced
;       in BC, no PUSH BC / POP BC wraps.
;
;   "Essentially free" under PD-P4-1 / PD-P4-11: 7-instruction body
;   (~7 B) consuming the byte 0 layout fixed by Story 18.1.
;
; antforth Phase-4 — FR-P4-5; PD-P4-1 (architecture.md:209, γ
; descriptor-stub mechanism — "BANK-OF becomes a one-byte read from
; the stub — essentially free"); PD-P4-11 (architecture.md:347..363,
; 4-byte stub layout with byte 0 = signed target_bank); redesign §1
; row at docs/antforth-banking-redesign.md:17. Forward-pointer:
; Story 18.5 (IN-BANK + Epic 18 close-out + antforth 3.x.2 tag).
w_BANK_OF:
        DEFCODE "BANK-OF", 0
w_BANK_OF_cf:
        LD      H, B                                ; HL = xt
        LD      L, C
        LD      C, (HL)                             ; C = byte 0 (target_bank, signed)
        LD      A, C
        RLA                                         ; CF = bit 7 of byte 0
        SBC     A, A                                ; A = $FF if CF else $00
        LD      B, A                                ; BC = sign-extended cell
        NEXT

; ============================================================
; IN-BANK ( n xt -- )
;
;   Story 18.5 (FR-P4-4). Twelfth and final user-facing word of
;   the redesign §1 BANK* wordset. Save current bank, switch to
;   bank n, execute xt, restore caller's bank — CATCH-safe on
;   the THROW unwind path.
;
;   Reference colon body at docs/antforth-banking-redesign.md:16:
;
;     : IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;
;
;   The reference body is NOT CATCH-safe: a THROW from xt would
;   unwind to the caller's outer CATCH frame, abandoning the
;   >R-saved bank cell — caller's bank would NOT be restored on
;   the unwind path. FR-P4-4 binds CATCH-safety as externally-
;   observable, so IN-BANK is kernel-blessed (DEFWORD that wraps
;   EXECUTE in an internal CATCH frame), NOT a user library word.
;
;   Q1 (Story 18.5 §"Open implementation questions") — DEFWORD
;   with internal CATCH wrap chosen over DEFCODE inline-Z80:
;   composes cleanly with existing exception machinery (no new
;   CCD-1 dual-chain layout exposure), inherits the Story-11.4.1
;   saved-SP / saved-BC discipline at src/exception.asm:111..174
;   unchanged.
;
;   Q2 — saved-bank stash via Forth return stack (>R / R>):
;     - >R pushes saved bank ABOVE the internal CATCH frame on
;       the R-stack (i.e., at a higher IX address; R-stack grows
;       downward).
;     - CATCH frame is pushed BELOW (lower IX) — at IX_init-10..
;       IX_init-3 — by w_CATCH_cf's DEC IX × 4 frame push.
;     - On caught THROW from xt, THROW restores IX to the
;       internal CATCH frame base, pops 8 B → IX is back to
;       IX_init-2 with saved_bank still at (IX). R> recovers it;
;       BANK! restores caller's bank; ?DUP IF THROW THEN
;       re-throws the captured code.
;     - Re-entrant for free: nested IN-BANK invocations each
;       have their own R-stack stash cell; no aliasing. AC4
;       Probe-18.5-B asserts.
;     - UserArea fixed-cell stash REJECTED on Q2(d) non-re-
;       entrancy grounds.
;
;   Q3 — Probe-18.5-D (cross-bank IN-BANK) DEFERRED to Epic 19
;   per the slot-2-remap-under-IP hazard (Story-18.3 / 18.4
;   precedent documented at tests/banking_tests.fth:1302..1345 —
;   Probe-18.4-C deferral block). Epic 19's per-bank dictionary
;   plumbing resolves the hazard structurally.
;
;   Stack diagram (BC = TOS-in-register; [SP] = next):
;     ( n xt -- )                            initial
;     BANK@   ( n xt saved )                 push current bank
;     >R      ( n xt        R: saved )       stash on R-stack
;     SWAP    ( xt n        R: saved )       reorder for BANK!
;     BANK!   ( xt          R: saved )       switch to target
;     CATCH   ( j*x 0 |     R: saved )       wrap xt in frame
;             ( i*x throw   R: saved )       on caught THROW
;     R>      ( ... saved   R: )             unstash
;     BANK!   ( j*x 0 | i*x throw )          restore caller bank
;     ?DUP IF THROW THEN                     re-throw if non-zero
;
;   CATCH-SAFETY SCOPE (FR-P4-4 / Story 18.5 AC2 narrow binding) —
;   the externally-observable property guaranteed by this kernel
;   word is: on caught THROW from xt, (a) the throw code lands on
;   the CATCH frame's data stack, and (b) the caller's bank is
;   restored on the unwind path (via the R-stack-stashed saved
;   bank, recovered by R>). AC2's wording, Probe-18.5-C, and the
;   deeper-cell-independent Probe-18.5-E witness this binding.
;
;   The i*x notation `( j*x 0 | i*x throw )` above is the ANS
;   Forth CATCH stack effect. Story 18.5.1 (post-Story-18.5
;   close, option (b) framework patch) extends antforth's CATCH
;   frame with an IX-rstack stash zone (depth_word + i*x cells
;   below frame_base; see docs/register-conventions.md §9 "Story
;   18.5.1: i*x cell-content preservation scope") so that BOTH
;   i*x's TOS-cell (via Story-11.4.1 saved-BC at frame +2) AND
;   i*x's deeper cells (via the new LDIR-stash mechanism) are
;   preserved across the caught-THROW boundary per ANS §9.6.1.0875.
;   IN-BANK's body-cell-3 SWAP — which would have corrupted outer
;   i*x's second-from-top under the pre-Story-18.5.1 framework
;   (witnessed by the 18.5 H1 disposition Reproducer A trace) — is
;   now harmless: outer CATCH stashes the deeper cells at its push,
;   and the outer THROW caught-path LDIR restores them regardless
;   of IN-BANK body's intermediate writes at [SP_safe + 0]. See
;   `_bmad-output/implementation-artifacts/18-5-1-defwords-ix-
;   preservation-on-caught-throw.md` for the dev-pass log and
;   Probes 18.5.1-A/B for the empirical witnesses.
;
;   BANK!-on-bad-n contract: -2 THROW ("bank?") fires BEFORE the
;   bank switch commits (src/banking.asm:151..156). On bad n,
;   IN-BANK propagates -2 cleanly; caller's bank is preserved
;   because no switch occurred. The R-stack stash cell is
;   abandoned by the outer-CATCH (or uncaught-handler) unwind —
;   harmless since IX is restored above it.
;
;   FR-P4-21 (recursive R-stack — documented gotcha per
;   architecture.md:367..382): nested IN-BANK adds 5 cells per
;   level (1 stash + 4-cell internal CATCH frame). Unbounded
;   recursion eventually hits -5 RETURN-STACK-OVERFLOW THROW;
;   no runtime guard added here.
;
;   EXX-HYGIENE (per NFR-P4-34 / docs/register-conventions.md
;   §3): IN-BANK is a Forth-threaded DEFWORD composition of
;   existing primitives (BANK@, >R, SWAP, BANK!, CATCH, R>,
;   ?DUP, ?BRANCH, THROW), each of which is independently
;   EXX-clean. No new EXX-hygiene audit needed for IN-BANK
;   itself.
;
; antforth extension IN-BANK — see docs/antforth-banking-redesign.md §1
; ============================================================
w_IN_BANK:
        DEFWORD "IN-BANK", 0                ; ( n xt -- )
w_IN_BANK_body:
w_IN_BANK_cf    EQU     w_IN_BANK_body - 3
        DW      w_BANK_AT_cf                ; ( n xt saved )
        DW      w_TO_R_cf                   ; ( n xt       R: saved )
        DW      w_SWAP_cf                   ; ( xt n       R: saved )
        DW      w_BANK_STORE_cf             ; ( xt         R: saved ) — may THROW -2
        DW      w_CATCH_cf                  ; ( j*x 0 | i*x throw  R: saved )
        DW      w_R_FROM_cf                 ; ( ... saved          R: )
        DW      w_BANK_STORE_cf             ; restore caller bank
        DW      w_QDUP_cf                   ; ( ... 0 | throw throw )
        DW      w_QBRANCH_cf, 4             ; if 0, skip THROW (offset = +4)
        DW      w_THROW_cf
        DW      EXIT_CODE

; ============================================================
; cross_bank_return — Sentinel-trampoline for cross-bank EXIT.
;
;   Story 18.2: the S1 b sentinel-tagged cross-bank return mechanism
;   (PD-P4-2, architecture.md:215..227; redesign §2.2,
;   docs/antforth-banking-redesign.md:44..48). The label is BOTH the
;   trampoline entry point AND the sentinel address compared by
;   EXIT_CODE (architecture's "Sentinel-trampoline labels" pattern at
;   architecture.md:534..537 — one symbol does both jobs).
;
;   ENTRY CONTRACT (per AC1 / FR-P4-20):
;     Reached via JP cross_bank_return from src/inner_interpreter.asm
;     EXIT_CODE when the popped return-address matches this label.
;     Register state at entry (= NEXT-time minus DE which is the
;     just-popped sentinel value):
;       BC = TOS                — user-visible data-stack TOS;
;                                 PRESERVED through the body
;       DE = cross_bank_return  — popped sentinel addr; discarded
;       HL = scratch
;       IX = R-stack pointer    — after the EXIT pop of the sentinel
;       IY = UserArea base
;     R-stack state at entry (top-to-bottom):
;       (IX+0..1) = caller_bank   (low byte = logical index 0..28,
;                                  high byte invariantly 0 per the
;                                  Story-17.2 BANK! convention at
;                                  src/banking.asm:142..144)
;       (IX+2..3) = target_addr   (16-bit code address; typically a
;                                  Forth IP or DEFCODE entry point in
;                                  fixed memory or the now-active
;                                  caller bank's $8000-$BFFF region)
;
;   BODY (per AC1):
;     1. Save BC=TOS (PUSH BC).
;     2. Pop caller_bank into BC (low byte; high byte forced 0).
;        Advance IX by 2.
;     3. Look up active_pages[caller_bank] via LD HL,
;        ACTIVE_PAGES_BASE / ADD HL, BC / LD A, (HL). Same shape as
;        BANK! at src/banking.asm:157..161.
;     4. Write the physical page to MMU slot 2 via OUT (0x72), A.
;        Port 0x72 = slot 2 per iz-cpm-banking cpm_machine.rs:13..14
;        and Story 17.2's BANK! comment at src/banking.asm:125..133.
;        UNLIKE port 0x74 (BANK-MAPPING-OFF, disconnects kernel —
;        src/banking.asm:63..66), port 0x72 is safe from
;        kernel-disconnect (the kernel binary lives in slot 0).
;     5. Update (IY+UserArea.current_bank) ← caller_bank.low. High
;        byte stays 0 per the Story-17.2 BANK! convention at
;        src/banking.asm:142..144 (the high-byte write is elided to
;        save 3 B).
;     6. Restore BC=TOS (POP BC).
;     7. Pop target_addr into HL. Advance IX by 2.
;     8. JP (HL) to target_addr. The trampoline is leaf-with-respect-
;        to-NEXT — it does not fall through to NEXT; the jump target
;        is responsible for its own NEXT-resumption discipline.
;
;        target_addr is a Z80 CODE-FIELD address (executable opcodes
;        at HL), NOT a Forth IP (a data cell holding a CFA). JP (HL)
;        is a DIRECT JUMP — PC ← HL — so passing a Forth IP would
;        execute IP-cell bytes as opcodes and crash. For the typical
;        Forth-to-Forth cross-bank return, the pusher (Story 18.3)
;        sets target_addr = xt(EXIT) (= address of `JP EXIT_CODE`);
;        the chained EXIT_CODE then pops the actual caller-IP from
;        the next R-stack cell and resumes the caller via NEXT in
;        the standard way. Net R-stack consumption per cross-bank
;        return is therefore 4 cells: this 3-cell sentinel frame
;        (sentinel, caller_bank, target_addr=xt(EXIT)) PLUS the
;        standard DOCOL-pushed caller-IP underneath. DEFCODE / raw-
;        code targets supply their own NEXT in the body.
;
;   PRECONDITION owned by the pusher (Story 18.3's EXECUTE chokepoint):
;     caller_bank ∈ [0..bank_count); target_addr is a Z80 code-field
;     address (NOT a Forth IP — see step 8). The trampoline does NOT
;     range-check (matches the stub_allocate undefined-input contract
;     at src/banking.asm:751..769; range-checking is the pusher's
;     responsibility).
;
;   EXX-HYGIENE AUDIT (per AC5 / NFR-P4-34 / docs/register-conventions.md
;   §3 leaf-level rule + §7 EXX-using inventory):
;     - The trampoline reads only main-set registers (BC, DE, HL, IX,
;       IY, A). NO `EXX` instruction appears in the body. The trampoline
;       is a leaf with respect to the EXX rule — its callers are
;       EXIT-via-sentinel-match callers at NEXT-time main-set register
;       state.
;     - No DE-touching opcode (no `EX DE, HL`, no `LDIR`, no
;       DE-as-temp). DE is read-only on entry (= sentinel value) and
;       not preserved; Lesson 17-D PUSH/POP DE wrap NOT required.
;     - Under normal operation the trampoline does NOT raise THROW
;       (the OUT (0x72), A port write is hardware-deterministic; the
;       R-stack pops are unguarded but caller-precondition'd; the
;       JP (HL) is a raw jump). If a future PD-P4-12 disposition
;       turns this site into a THROW raiser (e.g., a runtime guard
;       for cross-bank R-stack overflow per FR-P4-21 — currently
;       CHOSEN as documented-gotcha at architecture.md:367..382),
;       the leaf-level EXX-hygiene re-walk must be re-applied.
;
;   PER-BANK TRIPLE SWAP (HERE / LATEST / wordlist_head) — DEFERRED:
;     BANK! at src/banking.asm:165..196 swaps (HERE, LATEST,
;     wordlist_head) to/from bank-table[old/new][0..5] via LDIR
;     cascades; cross_bank_return DELIBERATELY omits this. Story 18.2
;     restores ONLY the MMU port + current_bank cell — enough for
;     the cross-bank EXIT dispatch substrate, but NOT enough for
;     bank-local compile-time state (HERE/LATEST/wordlist_head stay
;     pointed at the callee's bank-table[] slots after the trampoline
;     returns). Full per-bank compile-time plumbing is FR-P4-22 / Epic
;     19 scope; until then, callers that do compile-time work across
;     a cross-bank boundary will see callee-bank HERE/LATEST values.
;     This is intentional at Story 18.2's substrate-only level.
;
;   FR-P4-21 (RECURSIVE CROSS-BANK R-STACK; per AC6 / PD-P4-12
;   architecture.md:367..382):
;     CHOSEN disposition is documented-gotcha; NO runtime guard lands
;     here. Cross-bank frames are 3 cells (vs intra-bank 1 cell) so
;     recursive cross-bank calls exhaust the R-stack 3× faster, but
;     the existing -5 RETURN-STACK-OVERFLOW THROW catches them. The
;     F4 user-docs entry is slated for Epic 22 polish per
;     architecture.md:378..382.
;
;   FORWARD POINTERS:
;     - Story 18.3 EXECUTE chokepoint is the PRODUCTION PUSHER of the
;       3-cell frame (sentinel_addr, caller_bank, target_addr).
;     - Story 18.4 (BANK-OF) reads stub byte 0; not involved here.
;     - Story 18.5 (IN-BANK + Epic 18 close-out) validates CATCH-safe
;       cross-bank THROW unwind on top of this trampoline.
; ============================================================
cross_bank_return:
        PUSH    BC                                  ; preserve TOS
        LD      C, (IX+0)                           ; C = caller_bank.low
        LD      B, 0                                ; high byte invariantly 0
        INC     IX
        INC     IX
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC                              ; HL = &active_pages[caller_bank]
        LD      A, (HL)
        OUT     (0x72), A                           ; MMU slot 2 ← physical page
        LD      (IY+UserArea.current_bank), C       ; current_bank.low ← caller_bank
        POP     BC                                  ; restore TOS
        LD      L, (IX+0)
        LD      H, (IX+1)                           ; HL = target_addr
        INC     IX
        INC     IX
        JP      (HL)                                ; transfer control; no NEXT here

; --- .BANKS string literals ---
str_dot_banks_hdr:     DB "BANK PAGE   USED   FREE"
str_dot_banks_hdr_len  EQU 23
str_3sp:               DB "   "
str_used_free_crlf:    DB "    0  16384", 0x0D, 0x0A
str_used_free_crlf_len EQU 14
str_total_pfx:         DB "TOTAL          0 "
str_total_pfx_len      EQU 17
