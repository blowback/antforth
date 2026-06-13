; banking.asm — Phase-4 banking subsystem
; AntForth — A Forth for CP/M on Z80
;
; Phase-4 wordset: BANK@ / BANK! / BANKS / +BANK / -BANK / BANKS-CLEAR /
; .BANKS / BANK-OF / IN-BANK / (stub-allocate) / BANK-MAPPING-ON / -OFF.
; (SET-BANK retired — see note below.)
;
; The 2 KB region $D400-$DBFF is annexed to the kernel's fixed-memory claim
; (CCP eviction). bank-table[] base = $D400; the descriptor-stub allocator
; lives in the post-bank-table[] portion of this region.

; === Phase-4 banking constants ===
; bank-table[] cap = 29 entries. Per-entry layout: here (2 B) + latest
; (2 B) + wordlist_head (2 B) = 6 B / 3 cells. The shell lives AT
; BANK_TABLE_BASE = $D400 (src/constants.asm), in the reclaimed
; $D400-$DBFF CCP region — NOT allocated by a DS directive (no kernel
; binary bytes consumed for the shell); zero-initialised in COLD.
BANK_TABLE_CAP         EQU 29
BANK_TABLE_ENTRY_SIZE  EQU 6
BANK_TABLE_SHELL_SIZE  EQU BANK_TABLE_CAP * BANK_TABLE_ENTRY_SIZE   ; 174 B

; active_pages[]: dense logical-bank-index → physical-page mapping.
; Lives in the reclaimed $D400-$DBFF CCP region immediately after
; bank-table[] (no kernel binary bytes consumed). Read by BANK! to
; translate the popped logical index to the physical page mapped into
; slot 2; written by +BANK / -BANK / BANKS-CLEAR. Zero-initialised in
; COLD alongside bank-table[]. Footprint $D4AE..$D4CA — well under the
; 2 KB CCP claim's high edge.
ACTIVE_PAGES_BASE      EQU BANK_TABLE_BASE + BANK_TABLE_SHELL_SIZE   ; $D4AE
ACTIVE_PAGES_SIZE      EQU BANK_TABLE_CAP                            ; 29 B (1 byte / logical bank)

; === BANK-MAPPING-ON ( -- ) ===
;   Enable the MicroBeast MMU mapping. Updates UserArea.bank_mapping_state
;   to 1. Auto-run in COLD (after pool_init).
;
;   Port 0x74 is the MMU-mapping-enable register; bit 0 = enable.
w_BANK_MAPPING_ON:
        DEFCODE "BANK-MAPPING-ON", 0
w_BANK_MAPPING_ON_cf:
        LD      A, 1
        OUT     (0x74), A
        LD      (IY+UserArea.bank_mapping_state),   1
        LD      (IY+UserArea.bank_mapping_state+1), 0
        NEXT

; === BANK-MAPPING-OFF ( -- ) ===
;   CP/M warm-boot escape. Jumps to BIOS WBOOT at $0000 to reload CCP and
;   return to a healthy `B>` prompt. Never returns.
;
;   The literal port-0x74 write is INTENTIONALLY NOT performed. A naive
;   `OUT (0x74), A` with A=0 disconnects the kernel from RAM in the next
;   instruction fetch: the CPU sees flash bank 0 (firmware code) at the
;   slot-0 address it was executing, falls through to the firmware reset
;   path, and triggers a full cold-boot (PIO/Display/RTC re-detect,
;   RAM-disk reformat, sector restore) — confirmed on real MicroBeast.
;   The firmware-blessed transition is BIOS WBOOT, reachable as `JP 0x0000`
;   (the firmware installs a JP wboote at address 0). Mapping stays enabled
;   across warm-boot; CP/M operates with mapping enabled (it's how the BIOS
;   loaded antforth in the first place).
;
;   The kernel-side `bank_mapping_state` cell is NOT updated here — the BIOS
;   warm-boot destroys the antforth runtime before any observer could read
;   it back, so the cell write would be dead code. The next invocation runs
;   COLD, which re-inits `bank_mapping_state` to 1.
w_BANK_MAPPING_OFF:
        DEFCODE "BANK-MAPPING-OFF", 0
w_BANK_MAPPING_OFF_cf:
        JP      0x0000          ; BIOS WBOOT — never returns

; === mbb_set_slot2 / mbb_get_slot2 — blessed slot-2 page accessors ===
;   The page registers are write-only and the BIOS owns the authoritative
;   page shadow (and re-pages under disk ops), so slot 2 is switched/read
;   via the BIOS routines, never raw OUT/IN (see constants.asm MBB_*).
;   The BIOS routines clobber A/BC/HL/F; these wrappers preserve the
;   inner-interpreter registers BC (TOS), DE (IP) and HL so call sites can
;   invoke them inline. IX (R-stack) and IY (UserArea) are BIOS-preserved.
;
; mbb_set_slot2 ( A = physical page -> ) — map logical page 2 to A.
mbb_set_slot2:
        PUSH    DE                      ; E is reused as the arg; save IP
        PUSH    HL
        PUSH    BC
        LD      E, A                    ; E = physical page
        LD      A, 2                    ; logical CPU page 2 = $8000..$BFFF window
        CALL    MBB_SET_PAGE
        POP     BC
        POP     HL
        POP     DE
        RET
;
; mbb_get_slot2 ( -> A = physical page ) — read logical page 2's mapping.
mbb_get_slot2:
        PUSH    DE
        PUSH    HL
        PUSH    BC
        LD      C, 2                    ; logical CPU page 2
        CALL    MBB_GET_PAGE            ; A = physical page (survives the POPs)
        POP     BC
        POP     HL
        POP     DE
        RET

; === BANK@ ( -- n ) ===
;   Return the current logical bank index — i.e. (IY+UserArea.current_bank).
;   n is the index into the active bank list (NOT the physical page number).
;   Initial value 0 (portal-page default); updated by BANK! on successful
;   bank switch. Available at the REPL and inside colon definitions.
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
;     path (same shape as the `(ABORT")` runtime).
;
;     Portal-window guard: a foreign-bank switch (n != current_bank)
;     attempted from window-resident code — caller IP in $8000..$BFFF,
;     the MMU slot-2 portal window — raises THROW -273
;     (THROW_BANK_FROM_BANKED) BEFORE any MMU or state mutation.
;     Rationale: a threaded body physically resident in the window keeps
;     fetching cells from whatever page is mapped; switching the page
;     under itself makes subsequent fetches read the foreign page (portal-
;     window dictionary aliasing — corrupts into opcode soup or a JP $0000
;     warm boot). Same-bank switches from window code stay legal, as do all
;     switches with caller IP < $8000 or >= $C000 (interpreted-mode BANK!
;     runs from the outer interpreter's kernel-resident thread with IP in
;     kernel space, so the guard never fires on interactive use).
;
;     Residual exposure (documented limit): the guard checks the caller IP
;     only — DE at DEFCODE entry, i.e. the address of the cell AFTER the
;     invoking BANK! xt (NEXT has already advanced IP), which is exactly
;     the cell the post-swap NEXT would fetch from the foreign page. A
;     bank-0 body whose post-BANK! cell sits below $8000 but whose later
;     cells straddle into the window still corrupts (R-stack walking was
;     rejected on cost). Boundary note: a BANK! xt cell at $7FFE has caller
;     IP $8000 and IS guarded — the check is on the next-fetch address, not
;     the xt cell itself. The straddle reproducer (tests/straddle_repro.fth.in
;     + make test-straddle-regression) pins the residual as a regression
;     signature.
;
;   Effects on success:
;     1. Map slot 2 to active_pages[n]. Slot 2 = the portal window
;        $8000..$BFFF. UNLIKE BANK-MAPPING-OFF (port 0x74, disconnects
;        kernel from RAM and triggers BIOS WBOOT), the slot-2 page switch
;        is safe from kernel-disconnect: the kernel binary lives in slot 0
;        ($0000-$3FFF); switching slot 2 does not affect the address range
;        the CPU is currently fetching from.
;     2. Per-bank triple swap: save live (HERE, LATEST, wordlist_head) →
;        bank-table[old][0..5] then load bank-table[new][0..5] → live cells.
;        wordlist_head = the cell at `forth_wordlist` (the canonical
;        FORTH-WORDLIST struct's WORDLIST_NEXT slot).
;     3. (IY+UserArea.current_bank) ← n. (The high byte stays 0 — it is
;        zero at COLD and the precondition validates BC.high == 0 on every
;        entry, so the high-byte write is a known-zero no-op and is elided.)
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
        ; --- Portal-window guard: foreign-bank switch from window-resident
        ;     code (caller IP in $8000..$BFFF) THROWs -273 BEFORE any
        ;     MMU/state mutation. Same-bank switches stay legal. DE = caller
        ;     IP at DEFCODE entry (inner-interpreter convention); only D is
        ;     read — no save needed here (the swap's PUSH DE comes later).
        ;     Residual (see docstring): only the caller IP — the cell AFTER
        ;     the invoking BANK! xt, i.e. the post-swap NEXT fetch address —
        ;     is checked; later body cells are not. ---
        ; A still holds C (target bank) from the precondition above (CP does
        ; not modify A), so a redundant LD A, C is elided.
        CP      (IY+UserArea.current_bank)
        JR      Z, .window_ok                       ; same-bank → legal
        LD      A, D                                ; caller IP high byte
        AND     $C0                                 ; mask to 16-KiB-slot granularity
        CP      HIGH SLOT2_WINDOW_BASE              ; window = base..base+$3FFF <=> bit7=1 AND bit6=0
        JR      NZ, .window_ok                      ; IP < $8000 or >= $C000 → legal
        LD      BC, THROW_BANK_FROM_BANKED          ; -273
        JP      w_THROW_cf.kernel_entry
.window_ok:
        ; --- Activate bank C as the live bank (map slot 2, point
        ;     current_bank/triple_owner at C, swap the per-bank triple). The
        ;     shared helper preserves DE (IP) so the trailing NEXT resumes at
        ;     the caller; BC is clobbered, recovered by the POP below. C = n
        ;     (validated < bank_count, B == 0) from the precondition above. ---
        CALL    switch_live_bank_to_c
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
;   HL = &bank-table[A]. Internal helper for bank_triple_swap below
;   (called twice per swap). Clobbers A.
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

; bank_triple_save — save the live (HERE, LATEST, wordlist_head) triple
;   into bank-table[A][0..5].
;   ENTRY:  A = bank index in [0..28].
;   EXIT:   bank-table[A] = live triple. Clobbers A, BC, DE, HL.
;           IX / IY preserved. No system-stack push (leaf after bank_offset_hl).
;   Shared by bank_triple_swap and MARKER's pre-build_header snapshot
;   (src/system.asm), which previously hand-copied this cascade.
bank_triple_save:
        CALL    bank_offset_hl                      ; HL = &bank-table[A]
        EX      DE, HL                              ; DE = &bank-table[A]
        LD      HL, user_area + UserArea.here
        LD      BC, 4
        LDIR                                        ; HERE,LATEST → [0..3]; DE += 4
        LD      HL, (forth_wordlist)
        EX      DE, HL
        LD      (HL), E
        INC     HL
        LD      (HL), D                             ; wordlist_head → [4..5]
        RET

; bank_triple_load — load bank-table[A][0..5] into the live triple.
;   ENTRY:  A = bank index in [0..28].
;   EXIT:   live triple = bank-table[A]'s. Clobbers A, BC, DE, HL.
;           IX / IY preserved. No system-stack push.
;   Shared by bank_triple_swap and DOMARKER's reload (src/inner_interpreter.asm),
;   which previously hand-copied this cascade.
bank_triple_load:
        CALL    bank_offset_hl                      ; HL = &bank-table[A]
        LD      DE, user_area + UserArea.here
        LD      BC, 4
        LDIR                                        ; [0..3] → HERE,LATEST; HL += 4
        LD      DE, forth_wordlist
        LD      BC, 2
        LDIR                                        ; [4..5] → (forth_wordlist)
        RET

; bank_triple_swap — save the live (HERE, LATEST, wordlist_head) triple
;   to bank-table[A], then load bank-table[C]'s triple into the live
;   cells. Factored out of w_BANK_STORE_cf so THROW's caught-path triple
;   restore (src/exception.asm) can share it.
;
;   ENTRY:  A = save-target bank index, C = load-source bank index
;           (both in [0..28]; B is ignored).
;   EXIT:   live triple = bank-table[C]'s. Clobbers A, BC, DE, HL.
;           IX / IY preserved. Transient 2-byte PUSH BC on the system
;           stack, balanced before the tail call — safe both in DEFCODE
;           context and on the THROW caught path (completed before the
;           stash-restore LDIR touches [SP_safe..sp_base-1]).
;   Callers must NOT rely on the IX R-stack here: on the THROW caught
;   path IX = frame base with the stash zone live directly below it, so
;   an rpush would clobber the depth word.
bank_triple_swap:
        PUSH    BC                                  ; preserve load-source across save
        CALL    bank_triple_save                    ; live → bank-table[A=save]
        POP     BC                                  ; C = load-source bank
        LD      A, C
        JP      bank_triple_load                    ; bank-table[C=load] → live (tail)

; switch_live_bank_to_c — activate logical bank C as the live bank: map
;   slot 2 to active_pages[C], point current_bank + triple_owner at C, and
;   swap the per-bank (HERE,LATEST,wordlist_head) triple (save old → table,
;   load C → live). The identical sequence formerly appeared inline in
;   BANK!'s .window_ok and REASSERT-BANK (src/outer_interpreter.asm); both
;   now CALL here.
;
;   NOT shared with THROW's caught-path restore (src/exception.asm): that
;   path restores current_bank from CATCH frame +8 but triple_owner from
;   frame +9 (they diverge across a cross-bank dispatch live at CATCH) and
;   swaps the triple CONDITIONALLY — a different shape, not "switch both to
;   one C", so factoring it here would lose the +8/+9 distinction.
;
;   ENTRY:  C = target bank index (B == 0 — C is a logical index 0..28).
;           DE = IP (preserved across the call).
;   EXIT:   live bank = C. Clobbers A, BC, HL. DE / IX / IY preserved.
;   Callers own the data-stack TOS (BC is clobbered here): BANK! POPs the
;   consumed arg after; REASSERT-BANK brackets the call in PUSH/POP BC.
switch_live_bank_to_c:
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC                              ; HL = &active_pages[C] (B == 0)
        LD      A, (HL)
        CALL    mbb_set_slot2                       ; map slot 2; preserves BC, DE
        LD      A, (IY+UserArea.current_bank)       ; A = old bank (swap save-target)
        LD      (IY+UserArea.current_bank), C       ; current_bank ← C
        LD      (IY+UserArea.triple_owner), C       ; live triple keyed to C
        PUSH    DE                                  ; bank_triple_swap clobbers DE (IP)
        CALL    bank_triple_swap                    ; A = old, C = new
        POP     DE
        RET

; === BANKS ( -- n ) ===
;   Push the count of currently-active banks (= length of the active
;   list). Reads (IY+UserArea.bank_count).
;
;   The spec names this a VALUE derived from the active bank-list length,
;   but VALUE/TO are deliberately omitted from antforth's core; shipping
;   them to back this single use is rejected as scope-creep. A DEFCODE
;   proxy reading the kernel cell has the identical ( -- n ) stack effect.
w_BANKS:
        DEFCODE "BANKS", 0
w_BANKS_cf:
        PUSH    BC                                  ; save old TOS
        LD      C, (IY+UserArea.bank_count)
        LD      B, 0                                ; bank_count.high invariantly 0 (bounded by BANK_TABLE_CAP=29)
        NEXT

; === +BANK ( page -- ) ===
;   Probe-on-add + append to active_pages[]. Maps slot 2 to the candidate
;   page, writes two sentinels ($5A then $A5) to $8000, and reads back. If
;   either round-trip fails (ROM, unmapped, unstable), the original $8000
;   byte and the caller's slot-2 mapping are restored and ABORT" probe?"
;   fires. On success, the original $8000 byte + slot-2 mapping are
;   restored, the candidate is appended to active_pages[bank_count], and
;   bank_count is incremented.
;
;   Cap check: if bank_count == BANK_TABLE_CAP (29), ABORT" cap?" fires
;   BEFORE the probe. The active list is NOT modified on either ABORT path.
;
;   Probe correctness — two-sentinel sweep, conservatively. $5A alone would
;   false-positive a ROM page whose byte at $8000 happens to equal $5A; $A5
;   catches that case because the original byte cannot equal both sentinels.
;
;   The caller's slot-2 page is read from the BIOS shadow via MBB_GET (the
;   page registers are write-only on real silicon — a raw IN floats open-bus,
;   so reading the live mapping must go through the BIOS), then restored via
;   MBB_SET after the probe.
;
;   No dedup at this surface: duplicate pages append; downstream -BANK
;   removes the first match, leaving subsequent duplicates intact. The CL
;   parser owns surface-level dedup.
w_PLUS_BANK:
        DEFCODE "+BANK", 0
w_PLUS_BANK_cf:
        ; --- Cap check ---
        LD      A, (IY+UserArea.bank_count)
        CP      BANK_TABLE_CAP
        JP      Z, .abort_cap
        ; --- Probe + append via shared helper ---
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
; cl_probe_and_add — shared probe-and-append.
;
;   Used by:
;     - w_PLUS_BANK_cf (above): on CY=1, JPs to .abort_probe (ABORT" probe?").
;     - cl_tail_parse  (src/antforth.asm): on CY=1, emits "probe? NN" +
;       continues with the next CL-tail token (warn-and-continue).
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
        ; Save the caller's current slot-2 page from the BIOS shadow
        ; (MBB_GET preserves BC=candidate). Reads the actual live mapping —
        ; no bootstrap special-case needed; the port itself is write-only.
        CALL    mbb_get_slot2                       ; A = caller's slot-2 page
        LD      B, A                                ; B = saved restore page
.cpa_probe:
        LD      A, C
        CALL    mbb_set_slot2                       ; switch slot 2 to candidate
        LD      HL, SLOT2_WINDOW_BASE
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
        CALL    mbb_set_slot2                       ; restore caller's slot 2
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
        CALL    mbb_set_slot2                       ; restore caller's slot 2
        SCF                                         ; CY=1 (FAIL)
        RET

str_probe_q:     DB "probe?"
str_probe_q_len  EQU 6
str_cap_q:       DB "cap?"
str_cap_q_len    EQU 4

; === -BANK ( page -- ) ===
;   Linear-search active_pages[0..bank_count-1] for page; on hit, shift
;   tail down by one byte via LDIR and decrement bank_count. On miss
;   (or empty list), silent no-op (no THROW).
;
;   -BANK does NOT touch the MMU port; the currently-mapped slot-2 page
;   stays mapped. If the removed entry's logical index was below
;   current_bank, current_bank is left unchanged — the kernel cell may
;   now point to a different physical page than before, and the user is
;   responsible for re-issuing BANK! to re-establish the intended mapping
;   (no current_bank bookkeeping).
;
;   The vacated tail byte at the old active_pages[bank_count-1] position
;   is NOT zeroed — it is unreachable post-decrement per the BANK!
;   precondition, the -BANK search bounds, and the .BANKS iteration cap.
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
        ; --- Scrub the bucket chains BEFORE the active_pages[] shift, while
        ; the pre-shift logical indices in the fat pointers still resolve via
        ; active_pages[]. scrub_forth_buckets unlinks entries in bank k and
        ; renumbers surviving pointers with index > k. It clobbers A/BC/DE/HL,
        ; so save the match pos (HL), IP (DE), and shift counter (B/C).
        PUSH    HL                                  ; save &active_pages[k]
        PUSH    DE                                  ; save IP
        PUSH    BC                                  ; save B = bank_count - k
        LD      DE, ACTIVE_PAGES_BASE
        OR      A
        SBC     HL, DE                              ; HL = k (0..28)
        LD      A, L                                ; A = k (scrub selector)
        CALL    scrub_forth_buckets
        POP     BC
        POP     DE
        POP     HL                                  ; HL = &active_pages[k] again
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
;   Reset bank_count to 0. The active_pages[] byte array is NOT zeroed —
;   the bytes become unreachable when bank_count == 0 because BANK!'s
;   precondition `n < bank_count` fails for every n; -BANK's search loop
;   bounds itself by bank_count; .BANKS iterates 0..bank_count-1. A
;   subsequent +BANK rebuilds the list from index 0, overwriting the
;   stale tail bytes as it goes.
;
;   current_bank is NOT updated — its stale value is benign until the
;   next BANK!, which will ABORT" bank?" (precondition fails). After a
;   +BANK rebuild, the user is expected to re-issue BANK! to map the
;   intended logical index.
;
;   USER-FACING TRAP — call `0 BANK!` BEFORE BANKS-CLEAR when current_bank
;   != 0. BANK!'s swap saves live HERE/LATEST/wordlist_head to
;   bank-table[old] and loads bank-table[new]. Calling BANKS-CLEAR while a
;   bank N != 0 is live strands the live cells on bank-N's triple (HERE
;   at/above $8000 — the window compile point) with no BANK! route back:
;   the precondition fails for every n until a +BANK rebuild, so
;   dictionary-extending words run before the rebuild compile into the
;   window under whatever page is still mapped. The safe rebuild sequence:
;     N BANK! ... 0 BANK! BANKS-CLEAR ... +BANK ... BANK!
;   The 0 BANK! before BANKS-CLEAR swaps the kernel-snapshot triple back
;   into the live cells, so the dictionary stays consistent across the
;   clear-and-rebuild.
w_BANKS_CLEAR:
        DEFCODE "BANKS-CLEAR", 0
w_BANKS_CLEAR_cf:
        ; Scrub every window-resident entry out of the bucket chains BEFORE
        ; zeroing bank_count — once a bank is dropped its window entries are
        ; unmappable, and a FIND/WORDS that walked a surviving fat pointer
        ; into a dropped bank would page garbage. scrub clobbers A/BC/DE/HL,
        ; so save TOS (BC) and IP (DE).
        PUSH    DE                                  ; save IP
        PUSH    BC                                  ; save TOS
        LD      A, SCRUB_ALL_WINDOW
        CALL    scrub_forth_buckets
        POP     BC
        POP     DE
        LD      (IY+UserArea.bank_count), 0
        NEXT

; SET-BANK (diagnostic raw MMU port write) was RETIRED: a raw OUT desyncs
; the BIOS page shadow (the BIOS owns it and re-pages during disk ops), so a
; later BIOS call could restore a stale mapping and clobber slot 2 — a footgun
; once every page write must go through MBB_SET_PAGE. Use BANK! (kernel-managed)
; for page switching.

; ============================================================
; === .BANKS ( -- ) ===
;   Print a status table of the current banking configuration:
;     header row + one row per active bank + totals row.
;   Each row shows: logical-bank-index (decimal, right-aligned), physical-page
;   (2-hex uppercase), current-bank marker ('*' for the row whose index
;   matches BANK@; space otherwise), per-bank `used` and `free` columns.
;
;   Format (compact, 23 chars per row + CRLF; fits 80 cols at the 29-bank
;   cap — worst case "TOTAL          0 475136\r\n"):
;     "BANK PAGE   USED   FREE\r\n"   ; header — USED right-edge col 15,
;     "   0   22 *    0  16384\r\n"   ; FREE right-edge col 22; column
;     "   1   35      0  16384\r\n"   ; right-edges aligned across header,
;     ...                              ; per-bank rows, and totals row
;     "TOTAL          0 196608\r\n"   ; (totals via D.R width-6).
;
;   Per-bank used = 0 and per-bank free = 16384 are PLACEHOLDERS (literal
;   strings); a future bank-aware ':' makes per-bank HERE real.
;
;   Totals: used = 0; free = bank_count * 16384, computed post-loop as a
;   double-cell value (d-low = (bank_count & 3) << 14, d-high =
;   bank_count >> 2) and printed via D.R right-aligned in a 6-char field.
;   D.R (double) is used rather than U.R (single) because max free total
;   = 29*16384 = 475136 overflows a 16-bit single cell, and U.R is a
;   DEFWORD not a DEFCODE.
;
;   BANK col: hand-rolled decimal via print_bank_col_4. PAGE col: bare hex
;   via cl_emit_hex_byte. Zero-bank case: header + totals row only (totals
;   = 0), no per-bank loop.
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
        ; bank_count == 0: skip the loop (header + totals only).
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
;   Single call site (per-row BANK column); kept as a helper for readability
;   and future re-use if .BANKS gains a second decimal column.
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
; === Descriptor-stub allocator (the γ mechanism) ===
;
;   Allocates one 4-byte descriptor stub at (IY+UserArea.stub_alloc_tail)
;   then advances the cell by 4. The stub's address IS the word's xt;
;   xt portability across BANK! is automatic because the stub lives in
;   fixed memory (the CCP-evicted $D400-$DBFF annex).
;
;   Stub layout v2 — self-dispatching stub:
;     byte 0 — $EF (RST $28 opcode). The stub IS executable: NEXT's
;              blind `JP (HL)` (src/macros.asm) and the folded EXECUTE
;              both land here; the RST transfers to the stub_dispatch
;              handler installed at the STUB_DISPATCH_VECTOR by COLD.
;     byte 1 — target_bank as a signed byte. $FF = -1 = fixed-memory
;              marker; $00..$1C = active logical bank index 0..28
;              (29-entry cap). Caller owns range-checking (the allocator
;              does NOT validate).
;     bytes 2..3 — target_addr lo/hi.
;   stub_dispatch pops the RST-pushed stub+1, reads target_bank,
;   optionally writes the MMU port for slot 2, then JPs to target_addr
;   with HL = target CF (the DOCOL body = HL+3 precondition).
;
;   No DS directive backs the output region — the bytes are claimed at
;   constant addresses in the fixed-memory map (STUB_ALLOC_BASE = $D4CB,
;   src/constants.asm). COLD seeds stub_alloc_tail = STUB_ALLOC_BASE;
;   each allocation writes 4 B and advances the cell. Available region
;   $D4CB..$DBFF = 1845 B = up to 461 stubs in the CCP-evicted region
;   alone (heavier workloads may overflow into the HERE region).
;
;   Callers: the (stub-allocate) wrapper below, `;`-emit and CREATE-emit
;   (src/compiler.asm) — all pass B = bank, DE = CFA. Execute-through is
;   the RST-$28 stub_dispatch handler (below). BANK-OF reads byte 1
;   (target_bank) at xt+1.
; ============================================================
; stub_allocate — Kernel-internal allocator.
;
;   Input:  B  = target_bank as a signed byte (-1 = fixed-memory marker;
;                0..28 = logical bank index). Out-of-range values are
;                UNDEFINED INPUT — caller owns the bounds check.
;           DE = target_addr_in_bank (16-bit; for fixed-memory targets
;                this is a fixed-memory address; for banked targets it
;                is an address in the target bank's $8000-$BFFF body).
;   Output: HL = stub address = the word's xt.
;   Clobbers: HL is the output (used as the write-cursor across the 4
;                 bytes; restored to stub_addr via PUSH/POP). No other
;                 main-set register is modified: A / B / C / D / E and
;                 flags are all preserved. The alt-set is untouched (no
;                 EXX in the body). No PUSH/POP DE wrap required: no
;                 EX DE,HL / no LDIR / no DE-as-temp — DE is read-only
;                 (source for `LD (HL),E` / `LD (HL),D` emitting bytes
;                 2-3). BC.high unchanged (only B.low consumed). Callers
;                 can rely on the full main-set preservation contract —
;                 no caller-save wrap around `CALL stub_allocate`.
;   Side effect: writes 4 B at (stub_alloc_tail); advances stub_alloc_tail
;                by 4. No range check on the upper bound of the output
;                region — overflow into the HERE region is a future
;                concern (the CCP-evicted region holds 461 stubs; current
;                workloads stay well under).
stub_allocate:
        LD      L, (IY+UserArea.stub_alloc_tail)
        LD      H, (IY+UserArea.stub_alloc_tail+1)
        PUSH    HL                                  ; save stub_addr (= return value)
        LD      (HL), 0xEF                          ; byte 0: RST $28 opcode (self-dispatch)
        INC     HL
        LD      (HL), B                             ; byte 1: target_bank
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
;   Forth-callable wrapper around stub_allocate — keeps the 4-byte layout
;   knowledge in the kernel rather than spreading it into test code.
;   Kernel words consume the allocator via direct CALL stub_allocate
;   inside their own DEFCODE bodies; this is the only Forth-callable
;   surface.
;
;   target_bank is consumed as a signed byte (low byte of TOS); the high
;   byte of TOS is discarded. target_addr is consumed as a 16-bit cell
;   (the NOS at entry).
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
;   One-byte read of descriptor-stub byte 1 (target_bank; stub layout v2,
;   byte 0 = the RST $28 opcode), sign-extended to a single cell. Returns
;   the bank a word lives in: -1 for fixed-memory words (marker stored as
;   signed $FF), 0..28 for banked words (active-bank index).
;
;   Implementation contract:
;     - Input: BC = xt = stub address (typically in [STUB_ALLOC_BASE,
;       $DC00) = [$D4CB, $DC00)). No range check on xt — caller owns
;       valid-stub-address discipline, matching stub_allocate's
;       undefined-input contract.
;     - Output: BC = n = sign-extended byte at xt+1.
;       $FF → $FFFF (= -1); $00..$1C → $0000..$001C (= 0..28).
;     - Sign-extension idiom: RLA / SBC A, A — bit 7 → carry; SBC A,A
;       yields $FF if carry set, $00 if clear (2 B / 8 T; smallest, no
;       branches; widely used in Zilog programming guides).
;     - Body reads only main-set BC / HL / A. No EXX. No EX DE,HL. No
;       LDIR. No DE-as-temp. No PUSH/POP DE wrap required.
;     - Stack effect: single-cell-in / single-cell-out — TOS replaced
;       in BC, no PUSH BC / POP BC wraps.
w_BANK_OF:
        DEFCODE "BANK-OF", 0
w_BANK_OF_cf:
        ; --- legacy-CFA xt discriminator ---
        ; Bank-0 `:` keeps the legacy CFA-as-xt path (no descriptor stub
        ; allocated). BANK-OF on such an xt would otherwise read a code
        ; byte (the body's first opcode), out of signed [-1..28] range.
        ; Discriminate on xt.high < $D4: legacy CFA xt → return -1
        ; (fixed-memory marker). STUB_ALLOC_BASE = $D4CB.
        LD      A, B                                ; A = xt.high
        CP      $D4
        JR      C, .bank_of_legacy_fixed
        LD      H, B                                ; HL = xt
        LD      L, C
        INC     HL                                  ; HL = xt+1 (stub layout v2: byte 1 = target_bank)
        LD      C, (HL)                             ; C = byte 1 (target_bank, signed)
        LD      A, C
        RLA                                         ; CF = bit 7 of byte 0
        SBC     A, A                                ; A = $FF if CF else $00
        LD      B, A                                ; BC = sign-extended cell
        NEXT
.bank_of_legacy_fixed:
        LD      BC, -1                               ; legacy CFA xt → -1 (fixed-mem marker)
        NEXT

; ============================================================
; IN-BANK ( n xt -- )
;
;   Save current bank, switch to bank n, execute xt, restore caller's
;   bank — CATCH-safe on the THROW unwind path.
;
;   Reference colon body:
;
;     : IN-BANK BANK@ >R SWAP BANK! EXECUTE R> BANK! ;
;
;   The reference body is NOT CATCH-safe: a THROW from xt would unwind to
;   the caller's outer CATCH frame, abandoning the >R-saved bank cell —
;   caller's bank would NOT be restored on the unwind path. CATCH-safety
;   is externally observable, so IN-BANK is kernel-blessed (a DEFWORD that
;   wraps EXECUTE in an internal CATCH frame), NOT a user library word.
;
;   Saved-bank stash via the Forth return stack (>R / R>):
;     - >R pushes saved bank ABOVE the internal CATCH frame on the R-stack
;       (higher IX address; R-stack grows downward).
;     - The CATCH frame is pushed BELOW (lower IX) by CATCH's 4-cell push.
;     - On caught THROW from xt, THROW restores IX to the internal CATCH
;       frame base and pops it, leaving saved_bank at (IX). R> recovers it;
;       BANK! restores caller's bank; ?DUP IF THROW THEN re-throws.
;     - Re-entrant for free: nested IN-BANK invocations each have their own
;       R-stack stash cell; no aliasing. A UserArea fixed-cell stash was
;       REJECTED on non-re-entrancy grounds.
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
;   CATCH-SAFETY SCOPE — the externally-observable guarantee: on caught
;   THROW from xt, (a) the throw code lands on the CATCH frame's data
;   stack, and (b) the caller's bank is restored on the unwind path (via
;   the R-stack-stashed saved bank, recovered by R>).
;
;   The `( j*x 0 | i*x throw )` notation is the ANS Forth CATCH stack
;   effect. The outer CATCH frame's IX-rstack stash zone preserves both
;   i*x's TOS-cell and its deeper cells across the caught-THROW boundary
;   (ANS §9.6.1.0875), so IN-BANK's body-cell-3 SWAP is harmless: the
;   outer CATCH stashes the deeper cells at its push and the outer caught
;   path restores them regardless of IN-BANK's intermediate writes.
;
;   BANK!-on-bad-n contract: -2 THROW ("bank?") fires BEFORE the bank
;   switch commits. On bad n, IN-BANK propagates -2 cleanly; caller's bank
;   is preserved because no switch occurred. The R-stack stash cell is
;   abandoned by the outer-CATCH (or uncaught-handler) unwind — harmless
;   since IX is restored above it.
;
;   Recursive R-stack (documented gotcha): nested IN-BANK adds 5 cells per
;   level (1 stash + 4-cell internal CATCH frame). Unbounded recursion
;   eventually hits -5 RETURN-STACK-OVERFLOW THROW; no runtime guard here.
;
;   IN-BANK is a Forth-threaded DEFWORD composition of EXX-clean primitives
;   (BANK@, >R, SWAP, BANK!, CATCH, R>, ?DUP, ?BRANCH, THROW), so it needs
;   no EXX-hygiene audit of its own.
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
; stub_dispatch — RST-$28 self-dispatching descriptor-stub handler.
;
;   Descriptor stubs are executable: stub byte 0 = $EF (RST $28). NEXT's
;   blind JP (HL) (src/macros.asm), the folded EXECUTE, CATCH's xt-execute,
;   and the outer interpreter all land on stub byte 0; the RST vectors
;   through STUB_DISPATCH_VECTOR ($0028; COLD installs JP stub_dispatch
;   there) to this handler.
;
;   ENTRY CONTRACT:
;     Reached via RST $28 from stub byte 0.
;       BC = TOS                — user-visible data-stack TOS;
;                                 PRESERVED through both paths
;       DE = IP                 — caller's Forth IP (NEXT had already
;                                 advanced it past the stub-xt cell)
;       [SP+0..1] = stub+1      — the RST-pushed return address. SP is
;                                 the FORTH DATA STACK in antforth; this
;                                 is a transient 2-byte push, POPped by
;                                 the first instruction below. With the
;                                 cross path's PUSH BC + PUSH HL the
;                                 worst-case transient is 6 bytes —
;                                 covered by check_overflow's 32-byte
;                                 safety margin.
;       IX = R-stack pointer; IY = UserArea base
;
;   DISPATCH:
;     Read target_bank at stub byte 1 (= the popped stub+1 address).
;     - target_bank == current_bank OR == $FF (fixed-memory marker) →
;       INTRA path: load HL ← target_addr (stub bytes 2..3), JP (HL) with
;       HL = target CF. DOCOL's `body = HL+3` precondition holds on every
;       exit from this handler.
;     - else → CROSS path: push the 2-cell frame on the IX R-stack
;       (top-to-bottom: [caller_bank][caller_IP = DE]), set DE ←
;       xbank_thunk, map slot 2 to active_pages[target_bank] via
;       mbb_set_slot2 (BANK!-shape lookup, minus the F1 guard and minus
;       the per-bank triple swap — both deliberately: the dispatch path
;       switches the page directly and BANK!'s -273 window guard does not
;       constrain it, by design), update current_bank, then the same
;       HL ← target CF / JP (HL) tail.
;
;   RETURN (cross path): uniform for DOCOL and non-DOCOL targets.
;     HANDLER DE-CONTRACT (binding on EVERY code-field handler reachable
;     through a stub; mirrored at the handler sites in
;     src/inner_interpreter.asm): on entry DE = incoming IP (= xbank_thunk
;     here). A handler must either push DE to the R-stack as the return IP,
;     or reach NEXT with DE untouched. A future handler that clobbers DE
;     without pushing it breaks cross-bank return SILENTLY (stale-IP wild
;     fetch) — there is no runtime diagnostic.
;     - DOCOL/DODOES target: pushes DE (= xbank_thunk) as the return IP;
;       the body's terminal EXIT pops it; NEXT fetches the thunk cell →
;       xbank_restore.
;     - DOVAR/DOCON/DEFCODE target: the body's own NEXT runs with
;       IP = xbank_thunk → same fetch → xbank_restore.
;
;   RE-ENTRANCY / R-STACK PRESSURE: nested cross-bank calls each push their
;     own 2-cell frame; the thunk cell is read-only and shared. 2 cells per
;     cross-bank call doubles R-stack pressure vs intra-bank; the existing
;     -5 RETURN-STACK-OVERFLOW THROW still backstops.
;
;   PRECONDITION owned by the stub emitter (stub_allocate callers):
;     target_bank ∈ [0..bank_count) or $FF; target_addr is a Z80 code-field
;     address. The handler does NOT range-check (matches the stub_allocate
;     undefined-input contract above).
;
;   Main-set only (A, BC, DE, HL, IX, IY). No EXX. No EX DE,HL. No LDIR.
;   DE is read (caller_IP, cross path) and re-loaded (xbank_thunk); BC=TOS
;   is PUSH/POP-preserved around the MMU lookup. No THROW raise (the page
;   switch is hardware-deterministic; the byte reads are emitter-
;   precondition'd). If a future disposition adds a guard here, re-walk the
;   register audit.
; ============================================================
stub_dispatch:
        POP     HL                                  ; HL = stub+1 (FIRST: clear the RST transient off the data stack)
        LD      A, (HL)                             ; A = target_bank (signed byte)
        CP      (IY+UserArea.current_bank)          ; same bank?
        JR      Z, .enter                           ; → intra path
        CP      $FF                                 ; fixed-memory marker?
        JR      Z, .enter                           ; → intra path (no switch)
        ; --- CROSS path: 2-cell frame [caller_bank][caller_IP] on IX R-stack.
        ;     Both pushes route through rpush_de (the one R-stack push
        ;     convention, src/inner_interpreter.asm). ---
        CALL    rpush_de                            ; caller_IP → frame +2..3
        LD      E, (IY+UserArea.current_bank)       ; E = caller_bank (DE dead: IP saved)
        LD      D, 0                                ; high byte invariantly 0
        CALL    rpush_de                            ; caller_bank → frame +0..1 (top)
        LD      DE, xbank_thunk                     ; IP ← thunk (DOCOL pushes it; DEFCODE NEXTs it)
        ; --- MMU lookup + slot-2 write + current_bank update (BANK!-shape) ---
        PUSH    BC                                  ; save TOS
        LD      C, A                                ; C = target_bank
        LD      B, 0
        PUSH    HL                                  ; save stub+1 across lookup
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC                              ; HL = &active_pages[target_bank]
        LD      A, (HL)                             ; A = physical page
        POP     HL                                  ; HL = stub+1
        CALL    mbb_set_slot2                       ; MMU slot 2 ← page (preserves BC,HL,DE)
        LD      (IY+UserArea.current_bank), C       ; current_bank ← target_bank
        POP     BC                                  ; restore TOS
.enter:
        ; --- Common tail: HL ← target CF from stub bytes 2..3; JP ---
        INC     HL                                  ; HL = stub+2 (target_addr.lo)
        LD      A, (HL)
        INC     HL                                  ; HL = stub+3 (target_addr.hi)
        LD      H, (HL)
        LD      L, A                                ; HL = target CF
        JP      (HL)                                ; DOCOL sees HL = CF (body = HL+3 precondition)

; xbank_thunk — one fixed-memory thread cell. Read-only, always mapped,
;   re-entrant (each cross-bank nesting level has its own 2-cell frame;
;   this shared cell is never written). Reached as an IP by NEXT: the
;   fetch yields xbank_restore, NEXT JPs there. See stub_dispatch
;   contract above.
xbank_thunk:
        DW      xbank_restore

; xbank_restore — cross-bank return: pop the 2-cell dispatch frame,
;   restore caller's bank + IP, NEXT.
;
;   Raw code reached by NEXT's JP (HL) on the xbank_thunk cell — no
;   DEFCODE header (not a dictionary word).
;
;   ENTRY: BC = TOS (callee's final TOS — preserved); DE = xbank_thunk+2
;     (dead — re-loaded below); IX → 2-cell frame pushed by
;     stub_dispatch's cross path: (IX+0..1) = caller_bank,
;     (IX+2..3) = caller_IP.
;
;   Main-set only (A, BC, DE, HL, IX, IY); no EXX; no EX DE,HL; no LDIR;
;   BC=TOS PUSH/POP-preserved around the MMU lookup; DE written only after
;   its entry value is dead. No THROW raise.
xbank_restore:
        PUSH    BC                                  ; save TOS
        LD      C, (IX+0)                           ; C = caller_bank.low
        LD      B, 0                                ; high byte invariantly 0
        INC     IX
        INC     IX
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC                              ; HL = &active_pages[caller_bank]
        LD      A, (HL)
        CALL    mbb_set_slot2                       ; MMU slot 2 ← physical page (preserves BC,HL,DE)
        LD      (IY+UserArea.current_bank), C       ; current_bank ← caller_bank
        POP     BC                                  ; restore TOS
        LD      E, (IX+0)                           ; DE = caller_IP
        LD      D, (IX+1)
        INC     IX
        INC     IX
        NEXT                                        ; resume caller in restored bank

; --- .BANKS string literals ---
str_dot_banks_hdr:     DB "BANK PAGE   USED   FREE"
str_dot_banks_hdr_len  EQU 23
str_3sp:               DB "   "
str_used_free_crlf:    DB "    0  16384", 0x0D, 0x0A
str_used_free_crlf_len EQU 14
str_total_pfx:         DB "TOTAL          0 "
str_total_pfx_len      EQU 17
