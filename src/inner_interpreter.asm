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
;   Execute the word whose execution token is on the stack
; -----------------------------------------------
w_EXECUTE:
        DEFCODE "EXECUTE", 0
w_EXECUTE_cf:
        LD      H, B
        LD      L, C            ; HL = xt (code field address)
        POP     BC              ; Pop new TOS
        JP      (HL)            ; Jump to code field
