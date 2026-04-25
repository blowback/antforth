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
; Frame layout (E11-D1):
;   +6: previous CATCH-TOP   (chain link)
;   +4: catching-IP          (caller's IP at CATCH entry)
;   +2: saved IX             (post-push IX = frame's own base address)
;   +0: saved SP             (parameter-stack pointer at CATCH entry)

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
;   Frame layout (E11-D1) — pushed in highest-addr-first order so the
;   final IX matches the frame base:
;       +6: prev CATCH-TOP
;       +4: catching-IP (caller's IP at CATCH entry)
;       +2: saved IX (= frame base, recursive — backfilled after pushes)
;       +0: saved SP (parameter-stack pointer at CATCH entry)
;
;   Implementation notes:
;     - Saves DE (caller's IP) into frame +4 BEFORE the LD DE, catch_
;       resume_thread clobber — no scratch stash cell needed.
;     - Captures SP via "LD HL,0 / ADD HL,SP" (Z80 has no LD HL,SP).
;     - Backfills +2 placeholder via PUSH IX/POP HL after all four
;       cells are allocated, since the post-push IX is only knowable
;       once all 8 bytes have been DEC'd off.
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
        ; --- Capture SP-at-entry into HL (Z80 has no LD HL,SP) ---
        LD      HL, 0
        ADD     HL, SP                  ; HL = SP at CATCH entry
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
        ; +2: saved-IX placeholder (filled below once final IX is known)
        DEC     IX
        DEC     IX
        ; +0: saved-SP (HL captured above)
        DEC     IX
        DEC     IX
        LD      (IX+0), L
        LD      (IX+1), H
        ; --- Backfill saved-IX slot: IX now = frame base ---
        PUSH    IX
        POP     HL                      ; HL = IX (frame base)
        LD      (IX+2), L
        LD      (IX+3), H
        ; --- Update CATCH-TOP = frame base ---
        LD      (IY+UserArea.catch_top), L
        LD      (IY+UserArea.catch_top+1), H
        ; --- EXECUTE pattern (matches inner_interpreter.asm:240-243) ---
        LD      H, B
        LD      L, C                    ; HL = xt
        POP     BC                      ; BC = new TOS (i*x's TOS)
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
        ; --- Push xt's final TOS to SP; new TOS = 0 ---
        ; Note: the saved-SP slot at +0 becomes stale after this PUSH (xt's
        ; final TOS is now on SP, while +0 holds SP-at-CATCH-entry). This is
        ; harmless — Story 11.3's THROW reads +0 directly off CATCH-TOP
        ; before any normal-return teardown could clobber it; on the normal-
        ; return path the frame is popped immediately below.
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
