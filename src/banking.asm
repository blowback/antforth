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
        ; DE = IP (inner-interpreter convention). The probe scratch path
        ; uses D for caller_slot2_page and E for the saved $8000 byte —
        ; preserve IP across the probe so NEXT resumes at the caller.
        ; Precedent: BANK! (Story 17.2 review fix H1) wraps its LDIR
        ; cascade with PUSH DE / POP DE for the same reason.
        PUSH    DE                                  ; save IP
        ; --- Save caller's slot-2 page via port readback ---
        IN      A, (0x72)
        LD      D, A                                ; D = caller_slot2_page
        ; --- Switch slot 2 to candidate page (BC.low = page) ---
        LD      A, C
        OUT     (0x72), A
        ; --- Save original $8000 byte ---
        LD      HL, 0x8000
        LD      E, (HL)                             ; E = saved_orig
        ; --- Sentinel 1: write $5A, read back, compare ---
        LD      A, 0x5A
        LD      (HL), A
        CP      (HL)
        JR      NZ, .probe_fail
        ; --- Sentinel 2: write $A5, read back, compare ---
        LD      A, 0xA5
        LD      (HL), A
        CP      (HL)
        JR      NZ, .probe_fail
        ; --- Probe PASS: restore $8000 byte + slot 2 + append + increment ---
        LD      (HL), E                             ; restore $8000
        LD      A, D
        OUT     (0x72), A                           ; restore caller's slot 2
        POP     DE                                  ; restore IP
        LD      HL, ACTIVE_PAGES_BASE
        LD      A, (IY+UserArea.bank_count)
        ADD     A, L                                ; ACTIVE_PAGES_BASE.low = $AE; idx ≤ 28; $AE+28=$CA (no carry)
        LD      L, A                                ; HL = &active_pages[bank_count]
        LD      (HL), C                             ; store candidate page
        INC     (IY+UserArea.bank_count)
        POP     BC                                  ; new TOS
        NEXT

.probe_fail:
        ; Restore $8000 (HL still = 0x8000), then slot 2, then ABORT" probe?".
        ; THROW's caught-path restores SP from the CATCH frame, discarding
        ; the saved IP we PUSH'd along with the rest of the user stack;
        ; the uncaught path resets SP to sp_base. Either way no POP DE
        ; is required on the failure path.
        LD      (HL), E
        LD      A, D
        OUT     (0x72), A
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
