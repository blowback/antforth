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

; --- .BANKS string literals ---
str_dot_banks_hdr:     DB "BANK PAGE   USED   FREE"
str_dot_banks_hdr_len  EQU 23
str_3sp:               DB "   "
str_used_free_crlf:    DB "    0  16384", 0x0D, 0x0A
str_used_free_crlf_len EQU 14
str_total_pfx:         DB "TOTAL          0 "
str_total_pfx_len      EQU 17
