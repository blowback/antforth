; exception.asm — Exception subsystem (CATCH/THROW)
; AntForth — A Forth for CP/M on Z80
;
; Story 11.2 establishes CATCH and the 8-byte exception frame layout
; (E11-D1, architecture.md:270-287). Stories 11.3–11.7 land THROW, the
; per-primitive ABORT→THROW migration crawl, and the ABORT/ABORT"
; retarget. Story 11.2 implements only the normal-return path —
; THROW-time restore is intentionally not present here.
;
; Per CCD-1 (architecture.md:168-191) the exception chain is rooted at
; the USER variable CATCH-TOP; CATCH pushes a frame, sets CATCH-TOP to
; the new frame address, and on normal return restores CATCH-TOP from
; the frame's prev-link slot at +6.
;
; Frame layout (E11-D1, post-Story-11.4.1):
;   +6: previous CATCH-TOP   (chain link)
;   +4: catching-IP          (caller's IP at CATCH entry)
;   +2: saved BC             (i*x's TOS-cell value at CATCH entry; restored
;                             to data stack on THROW caught path so that
;                             the cell at [SP_safe-2] — which any CALL
;                             inside xt would otherwise clobber with its
;                             return-address byte — is repopulated before
;                             NEXT. Pre-Story-11.4.1 this slot was named
;                             "saved IX" and unused — see story 11-4-1
;                             root-cause analysis.)
;   +0: saved SP             (parameter-stack pointer **after** the POP BC
;                             that consumed xt → HL and i*x's TOS → BC.
;                             Pre-Story-11.4.1 captured BEFORE POP BC,
;                             which left frame +0 pointing at a cell xt's
;                             first CALL would clobber with its return-
;                             address byte — the Story 11.4 Note A bug.)

; -----------------------------------------------
; CATCH-TOP ( -- a-addr )
;   Push the address of the most-recent-exception-frame USER variable.
;   Zero when no enclosing CATCH is active (cold-start init in
;   antforth.asm; restored to prev value on every CATCH normal return).
; antforth extension — CATCH-TOP exposed as user variable (per CCD-1
;   dual-chain discipline; DPANS94 §9.6 does not require user-visibility)
; -----------------------------------------------
w_CATCH_TOP:
        DEFCODE "CATCH-TOP", 0          ; ( -- a-addr )
w_CATCH_TOP_cf:
        LD      A, UserArea.catch_top
        JP      push_user_var

; -----------------------------------------------
; CATCH ( i*x xt -- j*x 0 | i*x n )
;   Execute xt with an exception frame on the IX return stack.
;   On normal return: push 0 onto the parameter stack as the success code.
;   On THROW: (Story 11.3 — not implemented here) restore SP/IX, push n.
;
;   Frame layout (E11-D1, post-Story-11.4.1) — pushed in highest-addr-
;   first order so the final IX matches the frame base:
;       +6: prev CATCH-TOP
;       +4: catching-IP (caller's IP at CATCH entry)
;       +2: saved BC   (i*x's TOS-cell value, captured from BC immediately
;                       after POP BC. THROW's caught path restores this
;                       to the data stack at [SP_safe-2] via PUSH BC.)
;       +0: saved SP   (parameter-stack pointer **after** POP BC =
;                       SP_safe — one cell above the original i*x's
;                       TOS-cell memory slot. xt's CALLs write at
;                       [SP_safe-2], never at-or-above [SP_safe], so
;                       the restored SP is unaffected by xt's stack
;                       traffic.)
;
;   Implementation notes:
;     - Saves DE (caller's IP) into frame +4 BEFORE the LD DE, catch_
;       resume_thread clobber — no scratch stash cell needed.
;     - Reorders the EXECUTE pattern (LD H,B / LD L,C / POP BC) BEFORE
;       the frame push, so SP_safe (= post-POP-BC SP) is available for
;       the saved-SP slot and i*x's TOS-cell value (= BC after POP) is
;       available for the saved-BC slot.
;     - Captures SP_safe via "PUSH HL / LD HL, 2 / ADD HL, SP / POP HL"
;       (HL holds xt at this point; spill xt to system stack, capture
;       SP_safe = SP+2 to undo the PUSH, recover xt at end).
;     - On entry BC=xt; AC #3 says check_underflow first (1-cell guard;
;       ABORT path identical to every other 1-cell primitive — Story 11.4
;       owns the migration to THROW -4).
;
; ANS Forth 1994 §9.6.1.0875   CATCH          — execute xt with exception frame
; -----------------------------------------------
w_CATCH:
        DEFCODE "CATCH", 0              ; ( i*x xt -- j*x 0 | i*x n )
w_CATCH_cf:
        CALL    check_underflow         ; AC #3: SP-cells >= 1 (xt cell)
        ; --- EXECUTE-prelude reorder (Story 11.4.1): consume xt → HL and
        ;     i*x's TOS → BC BEFORE the frame push so the post-POP SP
        ;     ("SP_safe") and i*x's TOS-cell value are both available
        ;     for the new frame layout. ---
        LD      H, B
        LD      L, C                    ; HL = xt
        POP     BC                      ; BC = i*x's TOS-cell value
                                        ; SP advances to SP_safe = one
                                        ; cell above the original [SP].
        ; --- SP_safe capture: the saved-SP slot must hold the SP value
        ;     AFTER the POP BC consumed i*x's TOS into BC. Pre-Story-
        ;     11.4.1 this was captured BEFORE the POP — frame +0 then
        ;     pointed at the i*x's TOS-cell location, which xt's first
        ;     CALL (typically check_underflow) would clobber with its
        ;     return-address byte. THROW's `LD SP, HL` then landed on
        ;     stale return-address data instead of i*x's TOS. The post-
        ;     Story-11.4.1 design captures SP_safe = SP after POP BC;
        ;     xt's CALLs write at [SP_safe - 2] (never at SP_safe or
        ;     above — Z80 PUSH/CALL discipline); i*x's TOS-cell value
        ;     is preserved separately in frame +2 (saved-BC).
        ;
        ;     The PUSH HL / LD HL, 2 / ADD HL, SP / POP HL idiom is
        ;     required because Z80 has no direct LD HL, SP — and HL
        ;     currently holds xt; we spill xt across the SP capture
        ;     and recover it on the other side. SP_safe = current SP
        ;     + 2 undoes the PUSH HL.
        ;
        ;     FUTURE-EDIT NOTE: the +2 offset in `LD HL, 2 / ADD HL, SP`
        ;     below assumes SP = SP_safe-2 at that exact moment (i.e.,
        ;     exactly one PUSH HL has happened since the POP BC). Do NOT
        ;     insert any SP-modifying instruction between this PUSH HL
        ;     and the ADD HL, SP — even a paired PUSH/POP would briefly
        ;     change SP, but only an UNPAIRED change would corrupt the
        ;     captured value. The PUSH IX / POP HL pair later in the
        ;     frame-push body is fine because it lands AFTER the SP
        ;     capture is complete; SP is back at SP_safe-2 by the
        ;     terminating POP HL. ---
        PUSH    HL                      ; spill xt across SP capture
        LD      HL, 2
        ADD     HL, SP                  ; HL = SP_safe (post-POP-BC SP)
        ; --- Push 8-byte frame (highest addr first; IX grows downward) ---
        ; +6: prev CATCH-TOP (read from IY+catch_top)
        DEC     IX
        DEC     IX
        LD      A, (IY+UserArea.catch_top)
        LD      (IX+0), A
        LD      A, (IY+UserArea.catch_top+1)
        LD      (IX+1), A
        ; +4: catching-IP (caller's IP — DE is still live here)
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D
        ; +2: saved BC (Story 11.4.1: i*x's TOS-cell value from BC)
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B
        ; +0: saved SP_safe (HL captured above)
        DEC     IX
        DEC     IX
        LD      (IX+0), L
        LD      (IX+1), H
        ; --- Update CATCH-TOP = frame base. IX now = frame base. ---
        PUSH    IX
        POP     HL                      ; HL = IX (frame base) — clobbers
                                        ; the SP_safe value we already
                                        ; wrote to +0; safe.
        LD      (IY+UserArea.catch_top), L
        LD      (IY+UserArea.catch_top+1), H
        POP     HL                      ; recover xt (matches PUSH HL above)
        ; --- DE = continuation thread (xt's terminal NEXT lands on (CATCH-RESUME)) ---
        LD      DE, catch_resume_thread
        JP      (HL)                    ; execute xt

; One-cell pseudo-thread used by CATCH to route xt's terminal NEXT to
; the (CATCH-RESUME) continuation. Not a dictionary entry.
catch_resume_thread:
        DW      catch_resume_cf

; -----------------------------------------------
; (CATCH-RESUME) — internal continuation; not a Forth word.
;   Normal-return teardown reached when xt's terminal NEXT chases
;   DE = catch_resume_thread → fetches catch_resume_cf → JP (HL).
;
;   Steps:
;     1. Restore CATCH-TOP from frame +6.
;     2. Restore caller's IP (DE) from frame +4.
;     3. Push xt's final TOS (BC) to SP; install BC = 0 (success code).
;     4. Pop the 8-byte frame (IX += 8).
;     5. NEXT to the caller's thread.
;
;   At entry: IX = frame base (xt did not pop our frame).
;             BC = whatever xt left as TOS (may be the i*x-TOS we POP'd
;             at frame setup if xt has zero stack effect — that's fine,
;             the value sits as second-on-stack after we install BC=0).
; -----------------------------------------------
catch_resume_cf:
        ; --- Restore CATCH-TOP from frame +6 ---
        LD      A, (IX+6)
        LD      (IY+UserArea.catch_top), A
        LD      A, (IX+7)
        LD      (IY+UserArea.catch_top+1), A
        ; --- Restore caller's IP (DE) from frame +4 ---
        LD      E, (IX+4)
        LD      D, (IX+5)
        ; --- Push xt's final TOS to SP; new TOS = 0. Story 11.4.1: the
        ;     +2 slot's repurposing as saved-BC has zero effect on this
        ;     path — normal-return doesn't read +2 (or +0); it just
        ;     pushes BC and pops the 8-byte frame. The saved-SP slot at
        ;     +0 likewise becomes stale on this path; harmless because
        ;     THROW's caught path reads +0 from a target frame that is
        ;     by definition still live (catch_resume_cf bypassed). ---
        PUSH    BC
        ; --- Pop 8-byte frame: IX += 8 (BC freely usable now) ---
        ; ADD IX, BC = DD 09 (first kernel use of the IX-relative ADD; the
        ; user-level assembler dispatches the same opcode via
        ; .add16_dst_ixiy in src/assembler.asm).
        LD      BC, 8
        ADD     IX, BC
        ; --- Install success code in BC ---
        LD      BC, 0
        NEXT

; -----------------------------------------------
; THROW ( k*x n -- k*x | i*x n )
;   Raise an exception. n=0 is a no-op (consumes the 0 from stack).
;   Non-zero n: if CATCH-TOP != 0, restore SP/IX/CATCH-TOP/IP from the
;     target exception frame, install BC = n, NEXT into caller's thread
;     (resumes one cell after the CATCH that wraps this THROW).
;   Non-zero n with CATCH-TOP = 0: uncaught — print "error <n>"
;     (decimal, BASE-independent) plus optional ": <description>" if n
;     is in throw_desc_table, then route through w_ABORT_cf for state
;     reset and REPL recovery (FR21, FR22, NFR3, NFR7, NFR8).
;
;   See architecture.md:289-300 (E11-D2 algorithm) and CCD-1 dual-chain
;   discipline (architecture.md:168-191) — the INCLUDE-TOP chain walk is
;   a no-op pre-Epic-13 and Story 13.4 inserts the loop here.
;
;   Post-NEXT invariant on the caught path: BC = n is a *real* TOS, not
;   phantom (project_tos_in_register.md). At CATCH entry, BC held xt
;   (TOS-in-register) and [SP] held i*x's TOS-cell. Story-11.4.1 frame
;   layout: CATCH's POP BC consumes i*x's TOS into BC; frame +2 captures
;   that BC value as saved-BC; frame +0 captures the post-POP SP value
;   as SP_safe (one cell above the original i*x's TOS-cell slot).
;
;   Pre-Story-11.4.1 (Story 11.4 Note A): saved-SP was captured BEFORE
;   the POP BC, so frame +0 pointed at the memory cell that held i*x's
;   TOS. xt's first CALL (typically check_underflow's entry CALL) wrote
;   its return-address byte at THAT cell, clobbering the i*x's TOS value
;   the THROW caught path expected to find via LD SP, HL. The fix splits
;   the responsibility: saved-SP at +0 holds SP_safe (above xt's CALL
;   territory) and saved-BC at +2 holds the i*x's TOS-cell value
;   separately. THROW's caught-path restore:
;     LD SP, HL    (HL = SP_safe — points one cell above xt's
;                   CALL/PUSH territory; preserved across xt)
;     PUSH BC      (BC = saved-BC at this point — restores
;                   i*x's TOS-cell to [SP_safe - 2])
;     LD BC, n
;     NEXT
;   Final invariant: BC = n (real TOS), [SP] = i*x's TOS-cell,
;   [SP+2] = i*x's second-from-top, … [SP+2*(K-1)] = i*x's deepest,
;   where K = the i*x cell count at CATCH entry. DEPTH = K + 1 =
;   pre-CATCH-DEPTH (xt consumed, n on top instead).
;
;   The IX rstack between the THROW site and the target frame's base
;   (colon return-addr frames, DO-LOOP frames, etc.) is abandoned
;   wholesale by the IX restore — E11-D2's "snap back" semantic.
;
;   Caller contract (Stories 11.4-11.6 watch-list): a primitive that
;   has executed `EXX` to acquire shadow registers must `EXX`-restore
;   *before* falling into THROW. THROW reads BC as `n`, captures HL/SP
;   from the primary set, and overwrites BC/DE/HL during the restore;
;   if the shadow set is still active at entry, n is read from the
;   wrong cell and the post-NEXT shadow state stays inverted into the
;   catching frame. Per the EXX convention (docs/register-conventions
;   .md §1) shadow regs must be restored before NEXT or any transfer
;   out — this contract simply restates that for THROW.
;
; ANS Forth 1994 §9.6.1.2275   THROW          — raise an exception
; -----------------------------------------------
w_THROW:
        DEFCODE "THROW", 0              ; ( k*x n -- k*x | i*x n )
w_THROW_cf:
        CALL    check_underflow         ; AC #17: 1-cell guard. Story 11.4
                                        ; migrates do_underflow_error itself
                                        ; to -4 THROW, but THROW's own entry
                                        ; call must remain wired to the
                                        ; legacy helper to avoid recursion.
        ; -----------------------------------------------
        ; Kernel-internal entry: callers from inside the kernel
        ; (do_underflow_error, the divisor-zero guards in udivmod / UM/MOD,
        ; and any future internal ABORT-site migration in Stories 11.5 / 11.6)
        ; JP w_THROW_cf.kernel_entry with BC pre-loaded to the THROW code.
        ; The check_underflow guard above is skipped for two reasons:
        ;   (1) the caller's user stack is by definition in a degenerate
        ;       state on the underflow path (so check_underflow would
        ;       re-trip and recurse through do_underflow_error endlessly);
        ;   (2) the THROW code in BC is not a stack arg but a register-
        ;       passed parameter, so the ( n -- ) arity contract that
        ;       check_underflow enforces does not apply here.
        ; SP/IX may be in any state on entry — the caught-path's
        ; LD SP, HL from the catch frame +0, and the uncaught-path's
        ; JP w_ABORT_cf, both perform a wholesale state reset before any
        ; SP-dependent operation.
        ; EXX hygiene: each kernel-internal call site must verify
        ; EXX-not-active at entry. The three sites added in Story 11.4
        ; (do_underflow_error, the udivmod guard, the UM/MOD guard)
        ; satisfy this — they all run from primary-set context.
        ; Stories 11.5/11.6 must re-verify per migrated site.
        ; FUTURE-EDIT NOTE 1: any new code inserted between this label
        ; and the n=0 short-circuit below will be SKIPPED on the
        ; kernel-internal path. New pre-throw work belongs *after*
        ; this label, not before.
        ; FUTURE-EDIT NOTE 2: kernel-internal callers MUST pass a
        ; non-zero BC. The n=0 short-circuit immediately below does
        ; `POP BC` to consume the zero from the user data stack — on
        ; the kernel-entry path SP may be indeterminate (per the
        ; "SP may be in any state" note above), so a BC=0 entry would
        ; pop a stale frame byte and corrupt the user stack. Today no
        ; site does this (THROW codes are -4, -10); flagging for any
        ; future Story 11.5/11.6/11.7 migration that wishes to raise
        ; THROW 0 from the kernel.
        ; -----------------------------------------------
.kernel_entry:
        ; --- n = 0 no-op (Forth 2014 §9.6.1.2275: "If any bits of n are
        ;     non-zero, ..." — zero is silent, only consumes the zero) ---
        LD      A, B
        OR      C
        JR      Z, .throw_zero
        ; --- Read CATCH-TOP into HL ---
        LD      L, (IY+UserArea.catch_top)
        LD      H, (IY+UserArea.catch_top+1)
        LD      A, H
        OR      L
        JR      Z, .throw_uncaught       ; CATCH-TOP = 0: no enclosing CATCH
                                         ; (caught-path body is ~76 bytes; in
                                         ; JR range. If future edits push the
                                         ; uncaught label past +127, switch back
                                         ; to JP Z.)
        ; --- Caught path. HL = target frame base.
        ;     Stash n in throw_saved_n so BC is free for ADD IX, BC. ---
        LD      (throw_saved_n), BC
        PUSH    HL
        POP     IX                       ; IX = target frame base
        ; (Pre-Epic-13: INCLUDE-TOP chain walk is a no-op — Story 13.4
        ;  inserts the loop here, between the CATCH-TOP read above and
        ;  the SP/CATCH-TOP/IP restores below.)
        ; --- Restore CATCH-TOP from frame +6 (read while IX = base) ---
        LD      A, (IX+6)
        LD      (IY+UserArea.catch_top), A
        LD      A, (IX+7)
        LD      (IY+UserArea.catch_top+1), A
        ; --- Read catching-IP from frame +4 into DE (resolve before
        ;     LD SP, HL — though there's no current dependency, the rule
        ;     is "read all frame fields before IX advances or SP changes") ---
        LD      E, (IX+4)
        LD      D, (IX+5)
        ; --- Read saved-SP from frame +0 into HL (read while IX = base) ---
        LD      L, (IX+0)
        LD      H, (IX+1)
        ; --- Pop the 8-byte frame: IX = frame_base + 8.
        ;     ADD IX, BC = DD 09 (second kernel use; first at
        ;     catch_resume_cf src/exception.asm above). ---
        LD      BC, 8
        ADD     IX, BC
        ; --- Read saved i*x's TOS-cell value from the popped frame's +2
        ;     slot, now at IX-6 (since IX advanced 8 bytes, frame_base+2
        ;     becomes IX-8+2 = IX-6). Story 11.4.1 i*x preservation.
        ;
        ;     Safe: the popped frame's memory is unwritten between
        ;     ADD IX, BC and this read — only CATCH and INCLUDE write
        ;     to the IX rstack (per CCD-1, architecture.md:166-191), and
        ;     we hold the kernel until NEXT.
        ;
        ;     FUTURE-EDIT NOTE: any new instruction inserted between the
        ;     ADD IX, BC above and this LD pair that writes IX-relative
        ;     memory (or does any push/call that lands on the popped
        ;     frame's bytes — the IX rstack is independent of SP, so
        ;     SP-side traffic is fine) would corrupt the saved-BC read. ---
        LD      C, (IX-6)
        LD      B, (IX-5)               ; BC = saved i*x's TOS-cell value
        ; --- Restore SP_safe (post-POP-BC SP at CATCH entry).
        ;     SP_safe sits one cell above the original i*x's TOS-cell
        ;     slot; xt's CALL/RET traffic during execution wrote its
        ;     return-address byte at [SP_safe-2] but never at-or-above
        ;     SP_safe (Z80 PUSH/CALL discipline). The cell at
        ;     [SP_safe-2] may now hold stale return-address data — we
        ;     restore it via PUSH BC below. ---
        LD      SP, HL
        ; --- PUSH BC: restore the i*x's TOS-cell value to the data
        ;     stack at [SP_safe-2], overwriting whatever return-address
        ;     garbage xt's CALLs may have left there. SP becomes
        ;     SP_safe-2 — exactly where it was at CATCH entry, with
        ;     i*x's TOS-cell back in its original slot. ---
        PUSH    BC
        ; --- Install BC = n (THROW code, new TOS) ---
        LD      BC, (throw_saved_n)
        ; --- NEXT into caller's thread (DE = catching-IP, one cell after
        ;     the CATCH that wraps this THROW — same continuation point
        ;     as catch_resume_cf would have reached on normal return) ---
        NEXT

.throw_zero:
        ; n = 0 path (BC was 0). Pop the cell below into BC; SP advances by
        ; one cell. Stack depth drops by 1 from the caller's view.
        POP     BC
        NEXT

.throw_uncaught:
        ; Stash n; it's needed across bdos_print_str calls (BDOS helper
        ; takes the length arg in B, clobbering BC).
        LD      (throw_saved_n), BC
        ; --- Print "error " ---
        LD      HL, str_throw_prefix
        LD      B, STR_THROW_PREFIX_LEN
        CALL    bdos_print_str
        ; --- Print n in signed decimal (BASE-independent: FR21, AC #13) ---
        LD      BC, (throw_saved_n)
        CALL    print_signed_dec_bc
        ; --- Look up description; print ": <desc>" on hit, nothing on miss ---
        LD      BC, (throw_saved_n)
        CALL    print_throw_description
        ; --- Trailing CR/LF ---
        CALL    bdos_crlf
        ; --- State reset + REPL recovery via the legacy ABORT chain.
        ;     w_ABORT_cf calls asm_cleanup (clears asm_mode, restores
        ;     HERE/bucket if mid-CODE), resets SP, then JP w_QUIT_cf
        ;     (which resets IX, STATE, CATCH-TOP, then re-enters the
        ;     .quit_loop REPL prompt). FR22 / NFR7 / NFR8.
        ;     Story 11.7 will retarget w_ABORT_cf itself to -1 THROW —
        ;     at which point this becomes a tail of ABORT's own
        ;     machinery, with the same recovery semantics either way. ---
        JP      w_ABORT_cf

; -----------------------------------------------
; print_signed_dec_bc — Print BC as signed decimal via BDOS.
;   Hardcodes base 10 (does NOT read UserArea.base) — diagnostic must be
;   readable regardless of user's BASE setting (FR21 / AC #13). The sign
;   prefix and absolute-value reduction reuse print_neg_prefix from
;   src/formatting.asm; the digit loop reuses div_bc_by_e and
;   digit_to_char from the same file. The shared num_buf is safe here
;   because the THROW path is the terminal action before NEXT or
;   JP w_ABORT_cf — no print-during-print reentrancy is possible.
;
;   Input:  BC = signed 16-bit integer
;   Output: ASCII representation emitted via BDOS console
;   Clobbers: AF, BC, DE, HL
;   Preserves: IX, IY, SP
;
;   Edge case: BC = 0x8000 (-32768). 0 - 0x8000 wraps to 0x8000 in 16-bit
;   arithmetic, so |BC| stays 0x8000; div_bc_by_e is unsigned-aware and
;   prints "32768". Combined with the leading '-' from print_neg_prefix
;   the output is "-32768" — correct.
; -----------------------------------------------
print_signed_dec_bc:
        CALL    print_neg_prefix        ; emit '-' if BC<0; BC = |BC|
        LD      HL, num_buf + NUM_BUF_SIZE - 1
        XOR     A
        LD      (.psd_count), A
        LD      E, 10                   ; force decimal — DO NOT read BASE
.psd_loop:
        CALL    div_bc_by_e             ; BC = quotient, A = remainder
        CALL    digit_to_char           ; A = ASCII digit
        LD      (HL), A
        PUSH    AF
        LD      A, (.psd_count)
        INC     A
        LD      (.psd_count), A
        POP     AF
        LD      A, B
        OR      C
        JR      Z, .psd_done
        DEC     HL
        JR      .psd_loop
.psd_done:
        LD      A, (.psd_count)
        LD      B, A
        JP      bdos_print_str          ; tail-call

.psd_count:     DB      0

; -----------------------------------------------
; print_throw_description — Look up BC (THROW code) in throw_desc_table.
;   On match: prints ": <description>" via BDOS.
;   On miss (or table terminator): prints nothing.
;
;   Table entry: code (DW), len (DB), text (len bytes).
;   Terminator: code = 0 (THROW 0 is no-op'd before any uncaught lookup,
;   so 0 never collides with a real entry — see AC #3 short-circuit at
;   the top of w_THROW_cf).
;
;   Linear search is fine for ~10-15 entries; the THROW path is cold
;   (only fires on errors) and a hash table would cost more bytes than
;   it would save cycles.
;
;   The 8-bit `ADD A, L / INC H` carry handling assumes string length
;   <= 255 — enforced by every entry (max length seeded is 43 bytes).
;   It also assumes HL stays below $FF00 across the walk (so the final
;   `INC H` never wraps from $FF to $00). Currently safe: throw_desc_
;   table sits near the start of the .COM image (~17KB total). If the
;   kernel ever grows past 32KB and this table is relocated near the
;   top of memory, replace the carry handler with a 16-bit `ADD HL, A`
;   pattern (e.g., LD E,A / LD D,0 / ADD HL,DE).
;
;   Input:  BC = THROW code (signed 16-bit)
;   Output: ": <desc>" emitted on match; nothing on miss.
;   Clobbers: AF, BC, DE, HL
;   Preserves: IX, IY, SP
; -----------------------------------------------
print_throw_description:
        LD      HL, throw_desc_table
.ptd_loop:
        LD      E, (HL)
        INC     HL
        LD      D, (HL)                 ; DE = entry's code
        INC     HL                      ; HL → length byte
        ; Terminator check: DE == 0?
        LD      A, D
        OR      E
        RET     Z                       ; end of table — no match
        ; Compare DE against BC
        LD      A, E
        CP      C
        JR      NZ, .ptd_skip
        LD      A, D
        CP      B
        JR      NZ, .ptd_skip
        ; Match. HL points at length byte. Print ": " then length-prefixed.
        PUSH    HL
        LD      HL, str_colon_space
        LD      B, 2
        CALL    bdos_print_str
        POP     HL                      ; HL → length byte
        LD      A, (HL)
        LD      B, A
        INC     HL                      ; HL → first text byte
        JP      bdos_print_str          ; tail-call
.ptd_skip:
        ; Advance HL past length byte + string body to next entry's code-DW.
        LD      A, (HL)                 ; A = length
        INC     HL                      ; HL → first text byte
        ADD     A, L
        LD      L, A
        JR      NC, .ptd_loop
        INC     H
        JR      .ptd_loop

; -----------------------------------------------
; Exception-subsystem string pool (kept here, not in antforth.asm's
; string pool, so the strings live alongside their only consumers).
; -----------------------------------------------
str_throw_prefix:       DB      "error "
STR_THROW_PREFIX_LEN    EQU     6
str_colon_space:        DB      ": "

; -----------------------------------------------
; throw_desc_table — Description table for the uncaught-THROW handler.
;   Seeded with the standard ANS Forth 1994 §9.3.5 codes Epic 11
;   migrations will issue. antforth-extension codes -258..-269
;   (assembler errors) are added here by Story 11.5 when those
;   migrations land. -69 / -257 are reserved for Epic 13 (file-access)
;   and added at that epic's first migration story.
;
;   Format per entry: DW <code>, DB <len>, DB "<description>"
;   Terminator:       DW 0  (THROW 0 is no-op'd before uncaught lookup,
;                            so 0 is unambiguous as terminator — see
;                            AC #3 short-circuit in w_THROW_cf).
;
;   Strings are the standard's "Name (verbatim)" from
;   docs/throw-codes.md §b. Length bytes hand-counted; mismatch would
;   misalign the table walk.
; -----------------------------------------------
throw_desc_table:
        DW      -1
        DB      5
        DB      "ABORT"
        DW      -2
        DB      6
        DB      "ABORT", 0x22           ; ABORT" — 0x22 = ASCII '"'
        DW      -4
        DB      15
        DB      "stack underflow"
        DW      -10
        DB      16
        DB      "division by zero"
        DW      -13
        DB      14
        DB      "undefined word"
        DW      -14
        DB      32
        DB      "interpreting a compile-only word"
        DW      -16
        DB      43
        DB      "attempt to use zero-length string as a name"
        DW      -17
        DB      39
        DB      "pictured numeric output string overflow"
        DW      -22
        DB      26
        DB      "control structure mismatch"
        DW      -58
        DB      23
        DB      "unexpected end of input"
        ; --- antforth extension codes -258..-271 (assembler errors) ---
        ; Added by Story 11.5 (-258..-269) and extended by Story 11.6
        ; (-270 / -271 to retire the asm_die residual: check_asm_mode
        ; and asm_range_err — the two non-fan-in callers Story 11.1's
        ; inventory missed). Description text matches the pre-Story-
        ; 11.5/11.6 str_asm_<name> string contents — the migration
        ; moved the diagnostic from inline pre-prints to the unified
        ; "error -<N>: <desc>" format via this table. Length bytes
        ; hand-counted to match the literal string contents (mismatch
        ; silently misaligns the table walk per Story 11.3 design —
        ; cross-check on every edit).
        DW      THROW_ASM_BAD_OPERAND       ; -258
        DB      11
        DB      "bad operand"
        DW      THROW_ASM_NESTED            ; -259
        DB      11
        DB      "nested CODE"
        DW      THROW_ASM_NONAME            ; -260
        DB      15
        DB      "CODE needs name"
        DW      THROW_ASM_ORPHAN_LABEL      ; -261
        DB      21
        DB      "END-CODE without CODE"
        DW      THROW_ASM_LABEL_AFTER_END   ; -262
        DB      26
        DB      "LABEL must precede opcodes"
        DW      THROW_ASM_JR_RANGE          ; -263
        DB      15
        DB      "JR out of range"
        DW      THROW_ASM_TOO_LABELS        ; -264
        DB      15
        DB      "too many labels"
        DW      THROW_ASM_TOO_FIXUPS        ; -265
        DB      15
        DB      "too many fixups"
        DW      THROW_ASM_EQU_IN_CODE       ; -266
        DB      21
        DB      "EQU outside CODE only"
        DW      THROW_ASM_BARE_INT          ; -267
        DB      12
        DB      "bare integer"
        DW      THROW_ASM_UNRESOLVED        ; -268
        DB      16
        DB      "unresolved label"
        DW      THROW_ASM_ALREADY_FIXED     ; -269
        DB      13
        DB      "already fixed"
        DW      THROW_ASM_NOT_IN_CODE       ; -270
        DB      11
        DB      "not in CODE"
        DW      THROW_ASM_RANGE             ; -271
        DB      5
        DB      "range"
        DW      0                       ; terminator

; -----------------------------------------------
; throw_saved_n — Scratch cell for the THROW path.
;   Parks n across:
;     - The caught path's `LD BC, 8 / ADD IX, BC` (BC clobbered by 8).
;     - The uncaught path's three bdos_print_str calls (BC clobbered by
;       the `LD B, <len>` argument).
;   Never held across NEXT (THROW is the terminal call before NEXT or
;   JP w_ABORT_cf). Never re-entered: single-threaded invariant.
;
;   Storage note: this is 2 bytes of initialised data baked into the
;   .COM image (not a zero-page BSS allocation). CP/M loads the entire
;   .COM into RAM at $0100, so the cell is writable; the initial DW 0
;   simply means it starts as zero on every program load.
; -----------------------------------------------
throw_saved_n:  DW      0
