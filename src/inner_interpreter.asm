; inner_interpreter.asm — Inner interpreter core routines
; AntForth — A Forth for CP/M on Z80
;
; Contains: DOCOL, EXIT_CODE, LIT, BRANCH, ?BRANCH, EXECUTE
; NEXT macro is defined in macros.asm
;
; For the register contract (BC=TOS, DE=IP, ...) and shadow-register (EXX)
; conventions — leaf-level rule, Group A/B entry patterns, "A survives EXX"
; staging idiom, shadow BC' as TOS-preservation slot — see:
;   docs/register-conventions.md

; === DOCOL — Enter colon definition ===
; Push IP (DE) onto return stack (IX), set IP to body (following JP DOCOL)
DOCOL:
        ; Push current IP onto return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        ; W (HL) points to code field (the JP DOCOL), body = HL+3
        INC     HL
        INC     HL
        INC     HL
        ; HL = body address = new IP, use NEXTHL to avoid redundant EX DE, HL
        NEXTHL

; -----------------------------------------------
; EXIT ( -- ) ( R: nest-sys -- )
;   Return from colon definition (dictionary word wrapping EXIT_CODE)
; -----------------------------------------------
w_EXIT:
        DEFCODE "EXIT", 0
w_EXIT_cf:
        JP      EXIT_CODE

; === EXIT — Return from colon definition ===
; Story 18.2 (PD-P4-2 / architecture.md:215..227; redesign §2.2 at
; docs/antforth-banking-redesign.md:44..48) — sentinel-tagged
; cross-bank returns. After the standard R-stack pop, DE = popped
; return-address. A 16-bit CP against the constant `cross_bank_return`
; (Layout A — explicit JP on match; the trampoline body lives in
; src/banking.asm) decides intra-bank vs cross-bank:
;   - miss (the common case) → standard NEXT runs; FR-P4-19
;     zero-overhead invariant preserved up to the CP/JR-NZ overhead
;     (~23 T-states worst-case miss-path penalty per dev-pass T-state
;     accounting in Story 18.2 Dev Notes).
;   - match (cross-bank return) → JP cross_bank_return; the trampoline
;     pops caller_bank + target_addr from the R-stack, restores the
;     caller's bank via OUT (0x72) + (IY+UserArea.current_bank), then
;     JP (HL) to target_addr.
; The 3-cell frame (sentinel_addr, caller_bank, target_addr) is
; produced by Story 18.3's EXECUTE chokepoint when EXECUTE decodes
; a cross-bank target from a descriptor stub (PD-P4-11 byte-0 =
; signed bank index, architecture.md:347..365).
EXIT_CODE:
        ; Pop IP from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        ; Story 18.2 — sentinel-trampoline cross-bank EXIT discriminator
        LD      A, LOW cross_bank_return
        CP      E
        JR      NZ, .exit_normal
        LD      A, HIGH cross_bank_return
        CP      D
        JR      NZ, .exit_normal
        JP      cross_bank_return
.exit_normal:
        NEXT

; === DOVAR — Push variable body address ===
; HL points to code field (JP DOVAR)
; Body = HL+5 (skips 3-byte JP + 2-byte does-addr slot)
; ( -- addr )
DOVAR:
        ; Story 11.5.2: -3 THROW guard. PUSH HL spills W across the
        ; check (check_overflow clobbers HL); the +2-byte transient SP
        ; pressure is covered by check_overflow's 32-byte safety margin.
        PUSH    HL              ; spill W (= code field addr)
        CALL    check_overflow
        POP     HL              ; recover W
        PUSH    BC              ; Save old TOS
        LD      BC, 5
        ADD     HL, BC          ; HL = body address (cf+5)
        LD      B, H
        LD      C, L            ; BC = body address (new TOS)
        NEXT

; === DOCON — Push constant value ===
; HL points to code field (JP DOCON)
; Value = HL+3 (no does-addr slot for constants)
; ( -- x )
DOCON:
        ; Story 11.5.2: -3 THROW guard (depth +1). PUSH HL spills W.
        PUSH    HL              ; spill W (= code field addr)
        CALL    check_overflow
        POP     HL              ; recover W
        PUSH    BC              ; Save old TOS
        INC     HL
        INC     HL
        INC     HL              ; HL = body address (cf+3)
        LD      C, (HL)
        INC     HL
        LD      B, (HL)         ; BC = value at body (new TOS)
        NEXT

; === DODOES — Enter DOES> definition, push body address ===
; HL points to code field (JP DODOES)
; cf+3 = does-addr, cf+5 = body
; ( -- addr )
DODOES:
        ; Save IP to return stack (entering a colon-like definition)
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        ; Read does-addr at HL+3
        INC     HL
        INC     HL
        INC     HL              ; HL = &does-addr
        LD      E, (HL)
        INC     HL
        LD      D, (HL)         ; DE = does-addr (new IP)
        INC     HL              ; HL = body address (cf+5)
        ; Story 11.5.2: -3 THROW guard before the data-stack push (depth +1).
        ; PUSH HL spills the body addr across the check.
        PUSH    HL              ; spill body addr
        CALL    check_overflow
        POP     HL              ; recover body addr
        ; Push body address as new TOS
        PUSH    BC              ; Save old TOS
        LD      B, H
        LD      C, L            ; BC = body address (new TOS)
        NEXT

; === DOMARKER — Restore dictionary state from marker body ===
; HL points to code field (JP DOMARKER)
; Body at cf+3: [saved_here(2)][saved_buckets(128)]   ; FORTH-WORDLIST bucket array only —
; the wordlist struct's next-link cell is NOT snapshotted (Story 12.1 AC #6).
; ( -- ) no stack effect
DOMARKER:
        ; Skip code field to reach body
        INC     HL
        INC     HL
        INC     HL                      ; HL = &saved_here

        ; Save DE (IP) and BC (TOS) — LDIR clobbers both DE and BC
        CALL    rpush_de
        CALL    rpush_bc

        ; Read saved HERE from body
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        INC     HL                      ; DE = saved_here, HL = &saved_hash_data

        ; Restore HERE
        LD      (IY+UserArea.here), E
        LD      (IY+UserArea.here+1), D

        ; Copy 128 bytes from body to FORTH-WORDLIST bucket array
        LD      DE, forth_wordlist + WORDLIST_BUCKET0   ; DE = destination (bucket array only — Story 12.1 AC #6)
        LD      BC, 128
        LDIR                            ; Restore all 64 hash bucket heads

        ; Restore BC (TOS) and DE (IP)
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        CALL    rpop_de
        NEXT

; -----------------------------------------------
; Internal return-stack helpers (not Forth words)
; -----------------------------------------------
rpush_de:                       ; Push DE onto return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        RET                         ; 9 bytes

rpop_de:                        ; Pop DE from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX
        RET                         ; 9 bytes

rpush_bc:                       ; Push BC onto return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B
        RET                         ; 9 bytes

rpop_bc:                        ; Pop BC from return stack
        LD      B, (IX+1)
        LD      C, (IX+0)
        INC     IX
        INC     IX
        RET                         ; 9 bytes

rpush_hl:                       ; Push HL onto return stack
        DEC     IX
        DEC     IX
        LD      (IX+0), L
        LD      (IX+1), H
        RET                         ; 9 bytes

rpop_hl:                        ; Pop HL from return stack
        LD      L, (IX+0)
        LD      H, (IX+1)
        INC     IX
        INC     IX
        RET                         ; 9 bytes

; -----------------------------------------------
; LIT ( -- x )
;   Push inline literal from thread to parameter stack
; -----------------------------------------------
w_LIT:
        DEFCODE "LIT", 0
w_LIT_cf:
        ; Story 11.5.2: -3 THROW guard (depth +1). HL on entry is W
        ; (= code field addr) but LIT does not use it — it uses DE
        ; (= IP). check_overflow clobbers AF/HL, both unused, so no
        ; spill is needed.
        CALL    check_overflow
        PUSH    BC              ; Push current TOS to parameter stack
        EX      DE, HL          ; HL = IP
        LD      C, (HL)
        INC     HL
        LD      B, (HL)
        INC     HL              ; HL = IP past literal
        NEXTHL                  ; Use HL directly as IP

; -----------------------------------------------
; BRANCH ( -- )
;   Unconditional branch: add inline offset to IP
;   Offset is relative to the address of the offset cell itself
; -----------------------------------------------
w_BRANCH:
        DEFCODE "BRANCH", 0
w_BRANCH_cf:
        EX      DE, HL          ; HL = IP (points to offset cell)
        LD      E, (HL)
        INC     HL
        LD      D, (HL)         ; DE = offset
        DEC     HL              ; HL = IP (back to start of offset)
        ADD     HL, DE          ; HL = IP + offset (new IP)
        NEXTHL

; -----------------------------------------------
; ?BRANCH ( flag -- )
;   Conditional branch: if flag is 0 (FALSE), branch; else fall through
; -----------------------------------------------
w_QBRANCH:
        DEFCODE "?BRANCH", 0
w_QBRANCH_cf:
        LD      A, B
        OR      C               ; Test if BC (TOS) is zero
        POP     BC              ; Pop new TOS from stack regardless
        EX      DE, HL          ; HL = IP
        JR      Z, .do_branch   ; If flag was 0, take the branch
        ; Fall through: skip the offset
        INC     HL
        INC     HL              ; IP past the offset
        NEXTHL
.do_branch:
        ; Take the branch: add inline offset to IP
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        DEC     HL
        ADD     HL, DE          ; HL = IP + offset
        NEXTHL

; -----------------------------------------------
; EXECUTE ( xt -- )
;   Execute the word whose execution token is on the stack.
;
;   Story 18.3 (PD-P4-1 / architecture.md:207..211 — (γ) descriptor-stub
;   mechanism; PD-P4-11 / architecture.md:347..363 — 4-byte stub layout;
;   PD-P4-2 / architecture.md:215..227 — S1 b sentinel-tagged cross-bank
;   returns; redesign §3 at docs/antforth-banking-redesign.md:54..63):
;   3-way dispatch.
;
;   1. **Legacy CFA** (xt < $D4 high-byte) — xt is a Phase-1/2/3 dictionary
;      code-field address (the CFA-as-xt contract). Fall through to the
;      pre-edit `JP (HL)` — preserves the 975-PASS test-repl regression
;      baseline byte-for-byte.
;   2. **Intra-bank stub** (target_bank at xt+0 == BANK@ OR target_bank
;      == -1 fixed-memory marker) — `INC HL / JP (HL)` executes the
;      in-stub `JP target_addr` at xt+1. Total intra-bank stub-dispatch
;      overhead vs flat dispatch = 1 extra JP (the in-stub JP) per
;      FR-P4-15.
;   3. **Cross-bank stub** (target_bank ≠ BANK@ AND ≠ -1) — push the
;      cross-bank sentinel frame onto the R-stack. The frame is conceptually
;      4-cell, but EXECUTE only pushes 3 cells directly — the callee's
;      JP DOCOL pushes the 4th (the sentinel) as a natural consequence
;      of EXECUTE having pre-loaded DE = cross_bank_return.
;
;      EXECUTE's 3-cell push:
;        (IX+0..1) = caller_bank = BANK@
;        (IX+2..3) = target_addr = xt(EXIT)
;        (IX+4..5) = caller_IP = DE (the original IP into the caller's body)
;      Then EXECUTE: LD DE, cross_bank_return — the value DOCOL will push
;      on callee entry.
;      Then OUT (0x72), active_pages[target_bank]; update
;      (IY+UserArea.current_bank) ← target_bank; JP xt+1 (the in-stub JP).
;
;      Callee's JP DOCOL fires, DOCOL pushes DE = cross_bank_return:
;        (IX-2..-1) = cross_bank_return    ← sentinel (new top)
;        (IX+0..1) = caller_bank
;        (IX+2..3) = target_addr = xt(EXIT)
;        (IX+4..5) = caller_IP
;
;      Callee body runs (thread = LIT 12345 EXIT for an iron-spike-shape
;      probe, or any DEFWORD body). On EXIT:
;        - EXIT_CODE pops top = cross_bank_return → CP match → JP cross_bank_return
;        - Trampoline pops caller_bank, OUT (0x72), updates current_bank
;        - Trampoline pops target_addr = xt(EXIT), JP (HL) → JP EXIT_CODE
;        - EXIT_CODE pops caller_IP → CP miss → NEXT resumes caller in restored bank
;
;      target_addr = `xt(EXIT)` because JP (HL) in Story 18.2's trampoline
;      is a direct PC←HL transfer — a raw Forth IP there would crash
;      (Story 18.2 CR-H1 contract).
;
;      **Limitation: DEFWORD callees only.** For DEFCODE-shaped banked
;      callees (no JP DOCOL), DE = sentinel would be misinterpreted by
;      the callee body's NEXT. Story 18.3 scope is DEFWORD-only banked
;      callees, matching the iron-spike pattern and Epic-19's bank-aware
;      `:` (which compiles DEFWORD-shape colon definitions). DEFCODE
;      banked callees are an Epic 19+ extension if needed.
;
;   Q1 discriminator (Story 18.3 pre-edit baseline): one-byte H-test
;   `LD A, H / CP $D4 / JR C, .legacy_dispatch`. xt < $D400 → legacy
;   (Phase-1/2/3 CFAs live in $0100-$D3FF per architecture.md:271..285).
;   xt ≥ $D400 → stub region (stubs live in $D4CB+; the $D400-$D4CA range
;   holds bank-table + active_pages which never produce legitimate xts,
;   so the broader claim is harmless). Saves 4 B vs the two-byte
;   H+L-test option.
;
;   Q5 push shape (Story 18.3 pre-edit baseline): single `LD BC, -8 /
;   ADD IX, BC` advance (with PUSH/POP BC TOS-wrap, 7 B / 46 T) followed
;   by 8 IX-indexed byte writes (vs 8 × DEC IX at 16 B / 80 T). Saves
;   9 B + 34 T.
;
;   T-state accounting (cross-bank dispatch from EXECUTE entry to first
;   instruction of target body — AC3 / NFR-P4-3): see Story 18.3 Dev
;   Notes "Realised T-state account (AC3)". The realised count materially
;   exceeds the spec's "≤ 60 T-states + bank-switch" budget; Q6-a-extended
;   accept-with-rationale is invoked per project_epic17_envelope.md
;   (Lesson 17-B empirical envelope is ~2.4-2.7× the spec target across
;   Epic 17; Story 18.3 dispatches a 4-cell push + MMU + cell update at
;   leaf-instruction granularity, naturally exceeding the optimistic
;   spec target). The spec budget remains the forward-looking aspiration
;   for an all-stubs future where the discriminator is elided.
;
;   EXX-hygiene (S7 / NFR-P4-34): the dispatch is leaf with respect to
;   the EXX rule — no `EXX` instruction; main-set only (BC, DE, HL, IX,
;   IY, A); no THROW raise (the byte-0 read is unguarded but pusher-
;   precondition'd to land in a stub; the MMU port write is hardware-
;   deterministic; range-check is the allocator's responsibility per
;   PD-P4-1 § "EXECUTE chokepoint contract"). No `EX DE, HL`, no `LDIR`
;   anywhere — DE is preserved across the dispatch and pushed verbatim
;   as caller_IP.
;
;   FORWARD POINTERS:
;     - Story 18.4 (BANK-OF) is a degenerate one-byte read at xt+0 —
;       the same byte this discriminator inspects, exposed as a Forth
;       word.
;     - Story 18.5 (IN-BANK + Epic 18 close-out) wraps this EXECUTE in
;       a CATCH-safe save/restore frame.
;     - Epic 19 (bank-aware `:`) makes `:` allocate the stub itself;
;       once stubs become the universal xt format the legacy-CFA
;       discriminator can be elided (saves 5 B + 18 T per intra-bank
;       EXECUTE). Story 18.3 is the dispatch substrate; Epic 19 makes
;       the substrate universal.
; -----------------------------------------------
w_EXECUTE:
        DEFCODE "EXECUTE", 0
w_EXECUTE_cf:
        LD      H, B
        LD      L, C                ; HL = xt
        POP     BC                  ; new TOS (preserved through dispatch)
        ; --- Q1 legacy-CFA discriminator ---
        LD      A, H
        CP      $D4
        JR      C, .legacy_dispatch  ; H < $D4 → Phase-1/2/3 CFA
        ; --- Stub byte-0 read: target_bank as signed byte ---
        LD      A, (HL)
        ; --- Intra-bank check 1: target_bank == BANK@ ---
        CP      (IY+UserArea.current_bank)
        JR      Z, .intra_bank
        ; --- Intra-bank check 2: target_bank == -1 (fixed memory) ---
        CP      $FF
        JR      Z, .intra_bank
        ; --- Cross-bank dispatch: push 3 cells, set DE=sentinel, MMU swap ---
        ; Q5 push shape: single ADD IX, BC for the 6-byte advance,
        ; then 6 IX-indexed writes.
        ; EXECUTE pushes 3 cells; callee's JP DOCOL pushes the 4th cell
        ; (the sentinel) via the standard DOCOL push of DE.
        PUSH    BC                  ; save TOS
        LD      BC, -6
        ADD     IX, BC
        POP     BC                  ; restore TOS
        ; Field order top-to-bottom (R-stack offsets from IX after our push):
        ;   (IX+0..1) = caller_bank = BANK@         (popped by trampoline first)
        ;   (IX+2..3) = target_addr = xt(EXIT)      (popped by trampoline second)
        ;   (IX+4..5) = caller_IP = DE              (popped by chained EXIT_CODE)
        ; The DOCOL push of DE = cross_bank_return will land at (IX-2..-1)
        ; relative to current IX, becoming the new top (sentinel cell)
        ; before EXIT_CODE pops it on the body's EXIT.
        LD      (IX+4), E           ; caller_IP low
        LD      (IX+5), D           ; caller_IP high
        LD      (IX+2), LOW w_EXIT_cf    ; target_addr low (= xt of EXIT)
        LD      (IX+3), HIGH w_EXIT_cf   ; target_addr high
        LD      E, (IY+UserArea.current_bank)  ; E = caller_bank (= BANK@)
        LD      (IX+0), E           ; caller_bank low
        LD      (IX+1), 0           ; caller_bank high (invariantly 0)
        ; Pre-load DE = sentinel so callee's DOCOL push provides the
        ; sentinel-tagged top cell of the cross-bank frame.
        LD      DE, cross_bank_return
        ; --- MMU lookup + slot-2 write + current_bank update ---
        ; A still holds target_bank (the caller_bank push used E, not A).
        PUSH    BC                  ; save TOS
        LD      C, A                ; C = target_bank
        LD      B, 0
        PUSH    HL                  ; save stub xt
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC              ; HL = &active_pages[target_bank]
        LD      A, (HL)             ; A = physical page
        POP     HL                  ; restore stub xt
        OUT     (0x72), A           ; MMU slot 2 ← page
        LD      (IY+UserArea.current_bank), C  ; current_bank ← target_bank
        POP     BC                  ; restore TOS
        ; Fall through to .intra_bank (HL = stub xt; load target_addr → HL)
        ;
        ; Story 18.3 CR-H1 fix (2026-05-18): the .intra_bank path MUST
        ; transfer control to the callee's CF with HL = CF (because
        ; DOCOL relies on HL pointing to its own CF to compute
        ; `body = HL+3` per src/inner_interpreter.asm:14..25). Earlier
        ; shape `INC HL / JP (HL)` jumped through the in-stub JP at
        ; stub+1 but left HL = stub+1 — DOCOL then read garbage at
        ; stub+4 → wild NEXT → kernel reboot. The fix reads
        ; target_addr from stub bytes 2..3 directly into HL and JPs.
        ; The in-stub JP at stub+1 is no longer executed; Story 18.1's
        ; 4-byte stub layout is preserved (the $C3 + addr bytes are
        ; still emitted by stub_allocate but are dead code at dispatch).
.intra_bank:
        INC     HL                  ; HL = stub + 1
        INC     HL                  ; HL = stub + 2 (target_addr.lo)
        LD      A, (HL)             ; A = target_addr.lo
        INC     HL                  ; HL = stub + 3 (target_addr.hi)
        LD      H, (HL)             ; H = target_addr.hi
        LD      L, A                ; L = target_addr.lo; HL = target_addr = CF
        JP      (HL)                ; JP CF — DOCOL sees HL = CF, OK
.legacy_dispatch:
        JP      (HL)                ; pre-edit Phase-1/2/3 CFA dispatch
