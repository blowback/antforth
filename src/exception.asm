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
; Frame layout (E11-D1, post-Story-11.4.1 + Story 18.5.1):
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
;
; Story 18.5.1 (post-frame extension) — i*x deeper-cell preservation:
;   -2: depth_bytes word     (= sp_base − SP_safe = bytes of i*x cells
;                             below the TOS that need preservation; high
;                             byte invariantly 0 since PS_SIZE = 256.)
;   -2-depth_bytes..-3:  i*x stash zone (data-stack bytes copied from
;                             [SP_safe..sp_base-1] at CATCH entry; LDIR'd
;                             back to data stack on THROW caught path.
;                             Closes the ANS §9.6.1.0875 cell-content
;                             preservation gap exposed by Story 18.5 H1
;                             disposition.)
;   CATCH-TOP still points at frame +0 (saved-SP slot); the stash zone
;   sits BELOW CATCH-TOP on IX rstack. THROW and catch_resume_cf both
;   advance IX past frame + depth_word + stash via a variable-size
;   ADD IX, BC = (8 + 2 + depth_bytes). See `w_CATCH_cf`, `catch_resume_cf`,
;   and `w_THROW_cf.kernel_entry` caught path for the implementation.

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
; INCLUDE-TOP ( -- a-addr )
;   Push the address of the most-recent INCLUDE source-frame USER variable.
;   Zero when no INCLUDE is in progress (cold-start init in antforth.asm;
;   restored to prev value on every (input-frame-pop) and on the THROW
;   chain-walk per Story 13.4 v2 PD-9).
; antforth extension  INCLUDE-TOP  — most recent INCLUDE source-frame addr (CCD-1 chain head)
;   (CCD-1 dual-LIFO chain discipline; DPANS94 §11.6 does not require user-visibility)
; -----------------------------------------------
w_INCLUDE_TOP:
        DEFCODE "INCLUDE-TOP", 0        ; ( -- a-addr )
w_INCLUDE_TOP_cf:
        LD      A, UserArea.include_top
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
        ; --- Story 18.5.1 option (b): stash i*x deeper cells on IX rstack ---
        ; Copy [SP_safe..sp_base-1] into a new zone below the 8-byte frame,
        ; preceded by a 2-byte depth_word, so that THROW caught path can
        ; LDIR them back after restoring SP. Closes ANS §9.6.1.0875 cell-
        ; content preservation gap exposed by Story 18.5 H1 disposition.
        ; State here: IX = frame_base, BC = i*x's TOS, DE = caller's IP
        ; (already saved to frame +2 / +4), system stack [SP+0] = xt spill.
        ; Strategy: spill BC and SP_safe, compute depth, LDIR-push stash.
        PUSH    BC                      ; spill i*x's TOS-cell across LDIR
        LD      L, (IX+0)
        LD      H, (IX+1)               ; HL = SP_safe
        PUSH    HL                      ; spill SP_safe (recovered post-LDIR)
        EX      DE, HL                  ; DE = SP_safe; HL = caller's IP (now dead)
        LD      HL, (sp_base)
        OR      A
        SBC     HL, DE                  ; HL = sp_base - SP_safe = depth_bytes
        ; --- Push depth_word at IX-2 UNCONDITIONALLY. The THROW caught
        ;     path at `w_THROW_cf.kernel_entry` reads (IX-2)/(IX-1) into
        ;     BC and uses it as both the LDIR byte-count and the JR Z
        ;     short-circuit predicate (`LD A,B / OR C / JR Z`), so the
        ;     slot must hold the actual depth_bytes value even when
        ;     depth = 0 (Story-18.5.1 dev-pass iteration #1 bug: gating
        ;     the write on depth>0 left (IX-2) holding rstack garbage,
        ;     which THROW then attempted to LDIR-copy → crashes in test
        ;     622 EVALUATE / test-repl-banking-skip).
        ;     catch_resume_cf does NOT read (IX-2); it does a fixed +8
        ;     advance after re-anchoring IX via CATCH-TOP. ---
        LD      B, H
        LD      C, L                    ; BC = depth_bytes (count for LDIR)
        DEC     IX
        DEC     IX
        LD      (IX+0), C
        LD      (IX+1), B               ; high byte is 0 while PS_SIZE ≤ 256;
                                        ; depth_word is stored as a full 2-byte
                                        ; cell so a future PS_SIZE bump only
                                        ; requires re-validating the LDIR cycle
                                        ; budget, not the encoding.
        LD      A, B
        OR      C
        JR      Z, .catch_no_stash      ; depth_bytes = 0: skip LDIR (depth_word still written above)
        ; --- Advance IX downward by depth_bytes: IX = (frame_base-2) - depth_bytes ---
        PUSH    IX
        POP     HL                      ; HL = IX (= frame_base - 2)
        OR      A
        SBC     HL, BC                  ; HL = stash_low addr
        PUSH    HL
        POP     IX                      ; IX = stash_low
        ; --- LDIR: HL = SP_safe (source), DE = IX = stash_low (dest), BC = depth_bytes ---
        EX      DE, HL                  ; HL = SP_safe (source), DE = stash_low (dest)
        LDIR
.catch_no_stash:
        POP     HL                      ; drop SP_safe spill (clobbers HL — fine)
        POP     BC                      ; restore i*x's TOS-cell value
        ; --- end Story 18.5.1 option (b) ---
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
        ; --- Story 18.5.1: re-anchor IX to frame_base via CATCH-TOP.
        ;     Post-Story-18.5.1, w_CATCH_cf pushes a stash zone BELOW the
        ;     8-byte frame on the IX rstack (depth_word + i*x deeper-cell
        ;     stash), so IX at xt's terminal NEXT may be at stash_low
        ;     (= frame_base − 2 − depth_bytes) rather than at frame_base.
        ;     CATCH-TOP still points at frame +0 (= frame_base) by contract,
        ;     so reload IX from CATCH-TOP before reading frame fields. ---
        LD      L, (IY+UserArea.catch_top)
        LD      H, (IY+UserArea.catch_top+1)
        PUSH    HL
        POP     IX                      ; IX = frame_base
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
        ; --- Pop the 8-byte frame: IX += 8. The Story-18.5.1 stash zone
        ;     (depth_word + i*x stash) lives at LOWER addresses than
        ;     frame_base on the IX rstack; advancing IX past the frame
        ;     leaves the stash bytes in the now-free region below IX
        ;     (they will be overwritten by subsequent rstack pushes;
        ;     no GC required — IX rstack is dynamic). ---
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
;     is in throw_desc_table, then run the recovery chain (asm_cleanup
;     + SP-reset + JP w_QUIT_cf) inline; routes back to the .quit_loop
;     REPL prompt with dictionary preserved (FR21, FR22, NFR3, NFR7, NFR8).
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
        ; the dictionary/compiler/control-flow/string/I-O sites migrated
        ; by Stories 11.5 / 11.6, and the user-facing ABORT / (ABORT")
        ; sites migrated by Story 11.7) JP w_THROW_cf.kernel_entry with
        ; BC pre-loaded to the THROW code.
        ; The check_underflow guard above is skipped for two reasons:
        ;   (1) the caller's user stack is by definition in a degenerate
        ;       state on the underflow path (so check_underflow would
        ;       re-trip and recurse through do_underflow_error endlessly);
        ;   (2) the THROW code in BC is not a stack arg but a register-
        ;       passed parameter, so the ( n -- ) arity contract that
        ;       check_underflow enforces does not apply here.
        ; SP/IX may be in any state on entry — the caught-path's
        ; LD SP, HL from the catch frame +0, and the uncaught-path's
        ; inlined recovery chain at .throw_uncaught (asm_cleanup +
        ; SP-reset + JP w_QUIT_cf), both perform a wholesale state
        ; reset before any SP-dependent operation.
        ; EXX hygiene: each kernel-internal call site must verify
        ; EXX-not-active at entry. The three sites added in Story 11.4
        ; (do_underflow_error, the udivmod guard, the UM/MOD guard)
        ; satisfy this — they all run from primary-set context. The
        ; sites added in Stories 11.5 / 11.6 / 11.7 each re-verified
        ; the contract per their AC #12 spot-checks.
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
        ; site does this (post-Epic-11 the codes raised from the
        ; kernel-internal entry are -1, -2, -4, -10, -13, -14, -16,
        ; -17, -22, -58, -258..-271 — all non-zero); flagging for any
        ; future migration that wishes to raise THROW 0 from the kernel.
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
        ; --- Story 13.4 v2: INCLUDE-TOP chain walk (PD-10 / AC #11).
        ;     Pop INCLUDE source frames more recent than the target catch
        ;     frame (rstack grows DOWN: frame addr < IX_target ⇒ more
        ;     recent). Closes each FID on the way and restores the
        ;     parent's input-spec into USER. IX is preserved across the
        ;     walk; chain_walk_target scratch cell holds the target frame
        ;     base for the unsigned `<` compare. See architecture.md
        ;     E11-D2 (THROW algorithm) and E13-D2 (frame layout). ---
        CALL    throw_chain_walk_caught
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
        LD      H, (IX+1)               ; HL = SP_safe
        ; --- Read saved i*x's TOS-cell value from frame +2 (Story 11.4.1).
        ;     Pre-Story-18.5.1 this read happened POST-ADD-IX-8 via
        ;     (IX-6)/(IX-5); Story 18.5.1 reads it BEFORE the variable
        ;     advance so the stash-restore LDIR can be sequenced cleanly. ---
        LD      C, (IX+2)
        LD      B, (IX+3)               ; BC = saved i*x's TOS-cell
        ; --- Story 18.5.1 option (b): restore i*x deeper cells from IX-rstack
        ;     stash zone (pushed by w_CATCH_cf above). Stash saved-BC and
        ;     SP_safe to scratch cells; LDIR from stash to data stack at
        ;     [SP_safe..sp_base-1]; advance IX past frame + depth_word +
        ;     stash; recover saved-BC and SP_safe; LD SP, HL; PUSH BC;
        ;     LD BC, n; NEXT. ---
        LD      (throw_stash_hl), HL    ; spill SP_safe
        LD      (throw_stash_bc), BC    ; spill saved-BC (i*x TOS)
        LD      (throw_stash_de), DE    ; spill catching-IP. Use a kernel
                                        ; scratch cell rather than the
                                        ; system stack: if xt consumed cells
                                        ; before THROW (SP > SP_safe at
                                        ; THROW entry), a PUSH DE on the
                                        ; system stack would land at an
                                        ; address inside [SP_safe..sp_base-1]
                                        ; which the LDIR below overwrites.
                                        ; Scratch cell sidesteps the overlap.
        LD      C, (IX-2)
        LD      B, (IX-1)               ; BC = depth_bytes (high inv. 0)
        LD      A, B
        OR      C
        JR      Z, .throw_no_unstash    ; depth_bytes = 0: skip LDIR
        ; --- HL = stash_low = (frame_base - 2) - depth_bytes ---
        PUSH    IX
        POP     HL
        DEC     HL
        DEC     HL                      ; HL = frame_base - 2
        OR      A
        SBC     HL, BC                  ; HL = stash_low (source)
        ; --- DE = SP_safe (dest) ---
        LD      DE, (throw_stash_hl)
        ; --- LDIR copy BC bytes from stash (HL) → data stack (DE) ---
        LDIR
.throw_no_unstash:
        ; --- Advance IX past the 8-byte frame. The Story-18.5.1 stash
        ;     zone (depth_word + i*x stash) at lower addrs is now in the
        ;     freed rstack region below IX (parallel to catch_resume_cf
        ;     above; no variable advance needed — stash sits BELOW frame_base). ---
        LD      BC, 8
        ADD     IX, BC
        ; --- Recover saved-BC, SP_safe, and catching-IP from kernel scratch ---
        LD      BC, (throw_stash_bc)    ; BC = saved i*x's TOS-cell
        LD      HL, (throw_stash_hl)    ; HL = SP_safe
        LD      DE, (throw_stash_de)    ; DE = catching-IP
        ; --- Restore SP_safe; push i*x TOS at [SP_safe-2] (matches
        ;     pre-Story-18.5.1 contract — Story 11.4.1 i*x preservation).
        ;     With option (b), the data-stack cells [SP_safe..sp_base-1]
        ;     have ALREADY been restored from stash above; this PUSH BC
        ;     only restores the TOS-cell at the original slot. ---
        LD      SP, HL
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
        ; --- Story 13.4 v2: walk INCLUDE-TOP chain to completion (PD-10
        ;     uncaught). Closes every FID from in-progress INCLUDEs and
        ;     restores the input-spec back to the outermost (typically
        ;     keyboard). NFR9 ("no orphaned FIDs after THROW") closure. ---
        CALL    throw_chain_walk_uncaught
        ; --- State reset + REPL recovery (Story 11.7 inline).
        ;     Pre-Story-11.7 this was `JP w_ABORT_cf` and the chain
        ;     lived in w_ABORT_cf's body; Story 11.7 retargets
        ;     w_ABORT_cf itself to -1 THROW so the chain `user-ABORT
        ;     → -1 THROW → uncaught (CATCH-TOP=0) → JP w_ABORT_cf`
        ;     would otherwise infinite-loop. The chain is moved
        ;     here; w_QUIT_cf's IX/STATE/CATCH-TOP reset
        ;     (outer_interpreter.asm:243-258) closes the recovery.
        ;     FR22 / NFR7 / NFR8. ---
        CALL    asm_cleanup             ; If asm_mode set, restore HERE/bucket
        LD      HL, (sp_base)
        LD      SP, HL                  ; Reset parameter stack
        JP      w_QUIT_cf               ; Enter QUIT (resets return stack + STATE
                                        ; + CATCH-TOP per outer_interpreter.asm:252-255)

; -----------------------------------------------
; print_signed_dec_bc — Print BC as signed decimal via BDOS.
;   Hardcodes base 10 (does NOT read UserArea.base) — diagnostic must be
;   readable regardless of user's BASE setting (FR21 / AC #13). The sign
;   prefix and absolute-value reduction reuse print_neg_prefix from
;   src/formatting.asm; the digit loop reuses div_bc_by_e and
;   digit_to_char from the same file. The shared num_buf is safe here
;   because the THROW path is the terminal action before NEXT or the
;   inlined recovery chain at .throw_uncaught — no print-during-print
;   reentrancy is possible.
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
;   The 16-bit `ADD HL, DE` walk (LD E,(HL) / INC HL / LD D,0 /
;   ADD HL,DE) assumes string length <= 255 — enforced by every entry
;   (max length seeded is 43 bytes). The 16-bit add wraps modulo 65536
;   per Zilog UM008011 §8, so the walk is wrap-safe regardless of
;   table base address (closes Story 11.5 F9 / Story 11.6 R-L6 — see
;   _bmad-output/implementation-artifacts/
;     11.5-4-print-throw-description-table-walk-hardening.md).
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
        ; 16-bit ADD HL,DE form: wraps mod 65536 (UM008011 §8) — wrap-safe
        ; regardless of table address. Story 11.5.4 (closes 11.5 F9 / 11.6 R-L6).
        LD      E, (HL)                 ; E = length (LD r,(HL) is flag-neutral)
        INC     HL                      ; HL → first text byte
        LD      D, 0
        ADD     HL, DE                  ; HL → next entry's code-DW
        JR      .ptd_loop

; -----------------------------------------------
; Story 13.4 v2 — THROW INCLUDE-TOP chain-walk helpers (PD-10 / AC #11).
;   Used by both the caught path (target = IX = catch frame base; pops
;   only frames more recent than target) and the uncaught path (target
;   = 0xFFFF effective; walks to completion). HL = walk pointer; IX
;   preserved; chain_walk_target scratch holds the unsigned-compare
;   target. Close-failure semantics: ior is DISCARDED, pool_release is
;   always called, walk continues regardless (PD-10 close-failure spec).
; -----------------------------------------------

; throw_chain_walk_caught — Walk frames more recent than IX (target catch
;   frame base). Captures IX → chain_walk_target then falls into the
;   common loop. IX is preserved across the call.
throw_chain_walk_caught:
        PUSH    IX
        POP     HL
        LD      (chain_walk_target), HL
        JR      throw_chain_walk_loop_init

; throw_chain_walk_uncaught — Walk all remaining frames (target = 0xFFFF
;   means "no upper bound"; the loop terminates only at HL == 0).
throw_chain_walk_uncaught:
        LD      HL, 0xFFFF
        LD      (chain_walk_target), HL
        ; fall through

throw_chain_walk_loop_init:
        ; Initialise HL = USER.INCLUDE-TOP and run the loop.
        LD      L, (IY+UserArea.include_top)
        LD      H, (IY+UserArea.include_top+1)
.cw_loop:
        ; Termination 1: HL == 0?
        LD      A, H
        OR      L
        JR      Z, .cw_done
        ; Termination 2: HL < target? (unsigned compare)
        PUSH    HL
        LD      DE, (chain_walk_target)
        OR      A                       ; clear carry
        SBC     HL, DE
        POP     HL                      ; restore walk pointer
        JR      NC, .cw_done            ; HL >= target → stop
        ; --- Frame is more recent than target. Unwind it. ---
        ; Close current FID if SOURCE-ID > 0 (preserves HL).
        CALL    chain_walk_close_current_fid
        ; Restore parent spec from frame slots HL+0..HL+7.
        LD      A, (HL)
        LD      (IY+UserArea.tib_in), A
        INC     HL
        LD      A, (HL)
        LD      (IY+UserArea.tib_in+1), A
        INC     HL
        LD      A, (HL)
        LD      (IY+UserArea.tib_len), A
        INC     HL
        LD      A, (HL)
        LD      (IY+UserArea.tib_len+1), A
        INC     HL
        LD      A, (HL)
        LD      (IY+UserArea.tib_addr), A
        INC     HL
        LD      A, (HL)
        LD      (IY+UserArea.tib_addr+1), A
        INC     HL
        LD      A, (HL)
        LD      (IY+UserArea.source_id), A
        INC     HL
        LD      A, (HL)
        LD      (IY+UserArea.source_id+1), A
        INC     HL
        ; HL points at INCLUDE_FRAME_PREV slot (offset +8). Read prev-link.
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        EX      DE, HL                  ; HL = prev frame ptr
        JR      .cw_loop
.cw_done:
        ; Final write-back: USER.INCLUDE-TOP = surviving frame addr (= 0
        ; if walk completed entire chain).
        LD      (IY+UserArea.include_top), L
        LD      (IY+UserArea.include_top+1), H
        RET

; chain_walk_close_current_fid — Close USER.source_id if it's a real FID.
;   No-op for keyboard (0) / EVALUATE (-1). Discards close ior. Preserves
;   HL (walk pointer) across the call. Clobbers A, BC, DE, F.
;   Note: no file_flush call in this body (review L4) — the INCLUDE
;   close path always closes R/O FIDs whose byte-stream layer has only
;   been reading, so the per-FCB `fcb_has_written` bit stays 0.
;   file_flush is mode-aware as of Story 13.5 via that bit, plus the
;   per-FCB `fcb_dirty` bit (Story 13.5.1, transient counterpart), and
;   would itself skip even if called; omitting the call is documented
;   intent.
chain_walk_close_current_fid:
        PUSH    HL                      ; preserve walk pointer
        ; Exact-value sentinel tests (0 keyboard, 0xFFFF EVALUATE); avoid
        ; a bit-7 sniff so the check stays correct if the FCB pool ever
        ; lands at addr ≥ 0x8000.
        LD      L, (IY+UserArea.source_id)
        LD      H, (IY+UserArea.source_id+1)
        LD      A, H
        OR      L
        JR      Z, .cwc_skip            ; HL == 0 → keyboard
        LD      A, H
        AND     L
        INC     A                       ; A == 0 iff HL == 0xFFFF
        JR      Z, .cwc_skip            ; HL == 0xFFFF → EVALUATE
        EX      DE, HL                  ; DE = FID
        CALL    bdos_close_file
        EX      DE, HL                  ; HL = FID for pool_release
        CALL    pool_release
.cwc_skip:
        POP     HL                      ; restore walk pointer
        RET

; chain_walk_target — Scratch cell for the unsigned 16-bit compare.
;   Set by throw_chain_walk_caught (= target catch frame base) or by
;   throw_chain_walk_uncaught (= 0xFFFF). Read inside the loop. Single-
;   threaded invariant: never re-entered.
chain_walk_target:      DW      0

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
        DW      -3
        DB      14
        DB      "stack overflow"
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
        ; -49 — Story 12.3: SET-ORDER bounds check (search-order overflow)
        DW      THROW_SEARCH_ORDER_OVERFLOW
        DB      21
        DB      "search-order overflow"
        DW      -58
        DB      23
        DB      "unexpected end of input"
        ; --- File-Access codes (Story 13.4 v2) ---
        DW      THROW_FILE_IO               ; -37
        DB      14
        DB      "file I/O error"
        DW      THROW_FILE_NOT_FOUND        ; -38
        DB      14
        DB      "file not found"
        ; --- antforth extension codes -258..-272 (assembler errors) ---
        ; Added by Story 11.5 (-258..-269), extended by Story 11.6
        ; (-270 / -271 to retire the asm_die residual: check_asm_mode
        ; and the +D / bit-op range guards — the two non-fan-in callers
        ; Story 11.1's inventory missed), and split by Story 11.5.6
        ; (-271 disp range + new -272 bit range; see assembler.asm
        ; asm_disp_range_err / asm_bit_range_err). Description text
        ; matches the pre-Story-11.5/11.6 str_asm_<name> string contents
        ; — the migration
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
        DW      THROW_ASM_DISP_RANGE        ; -271
        DB      10
        DB      "disp range"
        DW      THROW_ASM_BIT_RANGE         ; -272
        DB      9
        DB      "bit range"
        DW      0                       ; terminator

; -----------------------------------------------
; throw_saved_n — Scratch cell for the THROW path.
;   Parks n across:
;     - The caught path's `LD BC, 8 / ADD IX, BC` (BC clobbered by 8).
;     - The uncaught path's three bdos_print_str calls (BC clobbered by
;       the `LD B, <len>` argument).
;   Never held across NEXT (THROW is the terminal call before NEXT or
;   the inlined recovery chain at .throw_uncaught). Never re-entered:
;   single-threaded invariant.
;
;   Storage note: this is 2 bytes of initialised data baked into the
;   .COM image (not a zero-page BSS allocation). CP/M loads the entire
;   .COM into RAM at $0100, so the cell is writable; the initial DW 0
;   simply means it starts as zero on every program load.
; -----------------------------------------------
throw_saved_n:  DW      0

; -----------------------------------------------
; Story 18.5.1 option (b) THROW caught-path scratch cells.
;   Spill SP_safe, saved-BC (= i*x's TOS-cell, frame +2), and the
;   catching-IP across the LDIR that restores i*x deeper cells from the
;   IX-rstack stash zone. LDIR clobbers HL/DE/BC, so all three must be
;   parked somewhere safe before the LDIR runs.
;
;   CRITICAL: the catching-IP is parked in `throw_stash_de` rather than
;   spilled to the system stack via `PUSH DE`/`POP DE`. A `PUSH DE` here
;   would land the catching-IP at [SP_throw − 2]; if xt consumed any
;   cells before THROW (SP_throw > SP_safe), that address can fall inside
;   the LDIR write range [SP_safe..sp_base-1], which the LDIR-restore
;   below would then overwrite with stash bytes. POP DE would read garbage
;   and NEXT would dispatch to a corrupted IP — empirically witnessed by
;   the Story-18.5.1 dev-pass `DROP-ABORT` and `EVALUATE` crashes
;   (Debug Log iteration #3). DO NOT revert `throw_stash_de` to a
;   PUSH/POP pair; the kernel scratch cell sidesteps the SP/LDIR overlap.
;
;   Single-threaded invariant: never re-entered (caught-path runs
;   atomically between THROW entry and NEXT).
;
;   Storage note: 2 bytes each of initialised data baked into the .COM
;   image (parallel to throw_saved_n above).
; -----------------------------------------------
throw_stash_hl: DW      0
throw_stash_bc: DW      0
throw_stash_de: DW      0
