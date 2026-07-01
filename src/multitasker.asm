; multitasker.asm — Phase-6 cooperative scheduler: PAUSE, TASK, ACTIVATE
; AntForth — A Forth for CP/M on Z80
;
; The scheduler spine (Epic 25 step 1, single-bank). Tasks are a circular ring of
; TCBs linked by `link`; the running task is `current_tcb`. PAUSE switches between
; them — but ONLY at a NEXT boundary (the cooperative invariant), because PAUSE is
; a CODE word reached through threading: it must never run mid-primitive where
; BC/IP could be phantom. TASK carves a TCB from the bank-0 dictionary; ACTIVATE
; arms it with a word to run and makes it AWAKE.
;
; Register contract (docs/register-conventions.md Hard Rule #1): BC=TOS, DE=IP,
; IX=return stack, IY=UserArea (never reassigned), SP=data stack. PAUSE saves and
; restores exactly these four registers plus the per-task UserArea subset
; {catch_top, current_bank, base} — see src/structures.asm TCB doc for why those
; three and only those three are per-task.
;
; Banking re-page: the per-task current_bank cell is saved and restored, and on a
; switch to a task whose bank differs from the outgoing one PAUSE re-pages slot 2
; via MBB_SET_PAGE (conditionally — same-bank switches pay zero BIOS cost). The
; per-bank dictionary triple is NEVER swapped on this path: HERE/LATEST/wordlist
; are global operator-owned cells and a background task runs pre-compiled words
; only (operator-only-compile lock).

; === Fixed-memory scheduler state (always below $8000) ===
; Lives in the always-mapped kernel image like timer.asm's tick_count, so PAUSE
; can read the ring whichever bank is later mapped into the slot-2 window. The
; ASSERT at the module's end fails the build if kernel growth ever pushes this
; state across $8000.
current_tcb:    DW      0               ; base of the running task's TCB; COLD sets = operator_tcb
sched_save:     DS      8               ; register bridge for PAUSE: [sp][ix][de][bc], TCB field order
sched_tcb:      DW      0               ; ACTIVATE scratch: stashed TCB base while building the header
sched_ip:       DW      0               ; TASK/ACTIVATE scratch: preserves the caller's IP (DE) across the
                                        ; body, which freely uses DE as a pointer. PAUSE is exempt —
                                        ; swapping DE through the TCB is its job. Operator-only, no reentry.
break_pending:  DB      0               ; keyboard-break latch (Story 25.7). Set by (EDIT) when it reads
                                        ; Ctrl-\ (0x1C) on the console; consumed at PAUSE's ring-selection
                                        ; seam to break the running background task (THROW -28). Set/read by
                                        ; normal code, not the ISR, so it needs no ISR-safe region — but it
                                        ; still lives below $8000 in fixed memory because PAUSE reads it under
                                        ; whatever bank is mapped into slot 2. Image-zero at load (like the
                                        ; cells above); COLD adds no explicit clear.
operator_tcb:   DS      TCB_HDR_SIZE    ; static task-0 record — header only (reuses the system data/
                                        ; return stacks, so no private ps/rs carve). COLD wires status,
                                        ; link and current_tcb; the saved-register slots fill on the
                                        ; operator's first PAUSE.

; === TCB field-walk macros — single source for the repeated copy shapes ===
; HL walks the TCB header field-by-field; these collapse the three shapes that
; otherwise repeat verbatim. Pure source DRY — each expands to the same bytes it
; replaces, so a field-list change is edited once, not in mirror copies.
;
; STORE_TCB_PTR: write the absolute address (sched_tcb + off?) as a little-endian
; pointer at (HL), then advance HL one cell. ACTIVATE seeds saved_sp/saved_ix/
; saved_de/t_sp_base this way (each is a TCB-base-relative address).
    MACRO STORE_TCB_PTR off?
        LD      DE, (sched_tcb)
        PUSH    HL
        LD      HL, off?
        ADD     HL, DE          ; DE = sched_tcb + off?
        EX      DE, HL
        POP     HL
        LD      (HL), E
        INC     HL
        LD      (HL), D
    ENDM
; SAVE_UA_CELL / RESTORE_UA_CELL: copy one 2-byte UserArea subset cell between
; (IY+ua?) and the TCB field at (HL), advancing HL one cell. PAUSE walks
; {catch_top, current_bank, base} with these (t_sp_base is the absolute sp_base
; cell, handled inline since it is not IY-relative).
    MACRO SAVE_UA_CELL ua?
        LD      A, (IY+ua?)
        LD      (HL), A
        INC     HL
        LD      A, (IY+ua?+1)
        LD      (HL), A
        INC     HL
    ENDM
    MACRO RESTORE_UA_CELL ua?
        LD      A, (HL)
        LD      (IY+ua?), A
        INC     HL
        LD      A, (HL)
        LD      (IY+ua?+1), A
        INC     HL
    ENDM

; === PAUSE ( -- ) — cooperative yield to the next AWAKE task ===
; Saves the outgoing task's registers + subset, walks the ring to the next AWAKE
; task, restores it, and NEXTs. A length-1 ring (operator only) walks link once
; back to self and resumes unchanged — byte-identical single-task behaviour
; (FR9 / AC1). antforth extension — cooperative task switch at a NEXT boundary.
w_PAUSE:
        DEFCODE "PAUSE", 0
w_PAUSE_cf:
        ; (1) Snapshot the outgoing task's live registers to fixed scratch in TCB
        ;     field order. The ED-prefixed LD (nn),rr stores reach SP/IX/DE/BC into
        ;     fixed memory with no register juggling; current_tcb is dynamic, so a
        ;     separate LDIR copies the snapshot into its saved-register block.
        LD      (sched_save + 0), SP    ; saved_sp
        LD      (sched_save + 2), IX    ; saved_ix
        LD      (sched_save + 4), DE    ; saved_de (IP)
        LD      (sched_save + 6), BC    ; saved_bc (TOS)
        LD      HL, (current_tcb)
        LD      DE, TCB_SP
        ADD     HL, DE                  ; HL -> outgoing.saved_sp
        EX      DE, HL                  ; DE -> outgoing.saved_sp
        LD      HL, sched_save
        LD      BC, 8
        LDIR                            ; scratch -> outgoing TCB saved_sp..saved_bc
        ; (2) Save the per-task UserArea subset {catch_top,current_bank,base} into
        ;     the outgoing TCB, copied THROUGH IY (IY is never reassigned). The TCB
        ;     subset cells are contiguous (TCB_CATCH..TCB_BASE) so HL walks them;
        ;     the UserArea sources are not contiguous, hence field-by-field.
        LD      HL, (current_tcb)
        LD      DE, TCB_CATCH
        ADD     HL, DE                  ; HL -> outgoing.t_catch_top
        SAVE_UA_CELL UserArea.catch_top         ; -> t_current_bank
        SAVE_UA_CELL UserArea.current_bank      ; -> t_base
        SAVE_UA_CELL UserArea.base              ; -> t_sp_base (contiguous after t_base)
        LD      A, (sp_base)            ; capture the running task's data-stack base
        LD      (HL), A
        INC     HL
        LD      A, (sp_base+1)
        LD      (HL), A
        ; Break consume (Story 25.7). A set break_pending means (EDIT) read a
        ; Ctrl-\ on the console. Break the running task — but ONLY a non-operator:
        ; the operator is the task that READ the byte, so breaking "whoever runs"
        ; would reset the operator to its prompt instead of the runaway. On an
        ; operator yield leave the flag set and hand off (the misbehaving
        ; background task consumes it on its own next yield); on a background
        ; yield clear it and raise THROW -28, which funnels through exception.asm's
        ; uncaught-THROW reroute (task N: error -28 + SUSPEND + operator resume,
        ; Story 25.6 — do NOT re-implement that here). If no breakable task is
        ; AWAKE the flag latches on the operator arm; ACTIVATE/WAKE drain it so a
        ; task later joining the rotation never inherits a break aimed at nothing.
        ; (A background task with an active CATCH intercepts the -28 itself — the
        ; break is a genuine THROW; see docs/throw-codes.md §(a.2).) Placed AFTER steps 1–2 so
        ; the outgoing task's state is saved (a later inspect/recover reads
        ; coherent state) and current_tcb still = the running task (the walk below
        ; has not advanced it); A/HL are free here. Common path (flag clear) is
        ; three bytes of straight-line test — byte-neutral.
        LD      A, (break_pending)
        OR      A
        JR      Z, .pause_walk_init             ; no break pending — common path
        LD      HL, (current_tcb)               ; still the running task
        LD      A, L
        CP      LOW operator_tcb
        JR      NZ, .pause_do_break
        LD      A, H
        CP      HIGH operator_tcb
        JR      Z, .pause_walk_init             ; operator yield — leave flag, hand off
.pause_do_break:
        XOR     A
        LD      (break_pending), A              ; clear before raising
        LD      BC, THROW_USER_INTERRUPT        ; -28; current_tcb = this background task,
        JP      w_THROW_cf.kernel_entry         ;   so .throw_uncaught takes the background arm
        ; (3) Walk link to the next TASK_AWAKE TCB (skip ASLEEP/SUSPENDED). The
        ;     operator is always AWAKE in this story, so the walk always
        ;     terminates; a length-1 ring returns to self.
.pause_walk_init:
        LD      HL, (current_tcb)
.pause_walk:
        LD      A, (HL)                 ; link lo
        INC     HL
        LD      H, (HL)                 ; link hi
        LD      L, A                    ; HL = next TCB base
        INC     HL
        INC     HL                      ; -> status (+2)
        LD      A, (HL)
        DEC     HL
        DEC     HL                      ; HL -> next TCB base
        CP      TASK_AWAKE
        JR      NZ, .pause_walk
        LD      (current_tcb), HL       ; the selected next running task
; Reusable resume tail. Entry contract: current_tcb already points at the task to
; run and HL = that same TCB base. Restores its full context {UA-subset, sp_base,
; SP, IX, DE=IP, BC=TOS} and NEXTs into it — the ONLY landing point of a switch.
; The uncaught-THROW handler (exception.asm) jumps here to hand control back to the
; operator after suspending a faulting background task.
sched_resume_current:
        ; (4) Restore the next task's UserArea subset, then re-page slot 2 to its
        ;     bank iff it differs from the outgoing one. Capture the outgoing bank
        ;     NOW — the live current_bank cell still holds it (PAUSE: the outgoing
        ;     task; exception resume: the faulting task) until RESTORE_UA_CELL below
        ;     overwrites it with the next task's bank. current_bank.high is
        ;     invariantly 0 (idx < 29), so the low byte is the whole compare key. B
        ;     is free here and survives RESTORE_UA_CELL/sp_base (they touch only
        ;     A/HL); step 5 reloads BC wholesale.
        LD      A, (IY+UserArea.current_bank)   ; A = outgoing (or faulting) bank
        LD      B, A                            ; B = outgoing bank — held across the restore
        LD      DE, TCB_CATCH
        ADD     HL, DE                  ; HL -> next.t_catch_top
        RESTORE_UA_CELL UserArea.catch_top      ; -> t_current_bank
        RESTORE_UA_CELL UserArea.current_bank   ; -> t_base
        RESTORE_UA_CELL UserArea.base           ; -> t_sp_base
        LD      A, (HL)                 ; install the next task's data-stack base
        LD      (sp_base), A            ; so the depth guards / DEPTH track its private ps_area
        INC     HL
        LD      A, (HL)
        LD      (sp_base+1), A
        ; Conditional re-page: map slot 2 to the next task's bank only when it
        ; differs from the outgoing one — same-bank switches (the common case) pay
        ; zero BIOS cost. mbb_set_slot2 routes through MBB_SET_PAGE (never a raw MMU
        ; OUT) and preserves DE=IP/BC/HL. The dictionary triple is NOT swapped: it
        ; is global operator-owned state a background task never touches.
        LD      A, (IY+UserArea.current_bank)   ; A = next bank (just restored)
        CP      B                               ; compare against the outgoing bank
        JR      Z, .same_bank                   ; same bank → skip the BIOS page call
        LD      C, A                            ; C = next bank index
        LD      B, 0                            ; high byte invariantly 0 → BC = index
        LD      HL, ACTIVE_PAGES_BASE
        ADD     HL, BC                          ; HL -> active_pages[next]
        LD      A, (HL)                         ; A = physical page for that bank
        CALL    mbb_set_slot2                   ; re-page slot 2; preserves DE/BC/HL
.same_bank:
        ; (5) Restore {SP,IX,DE,BC} from the next TCB via the scratch bridge, then
        ;     NEXT. The switch lands ONLY here, at a NEXT boundary.
        LD      HL, (current_tcb)
        LD      DE, TCB_SP
        ADD     HL, DE                  ; HL -> next.saved_sp
        LD      DE, sched_save
        LD      BC, 8
        LDIR                            ; next TCB saved_sp..saved_bc -> scratch
        LD      SP, (sched_save + 0)
        LD      IX, (sched_save + 2)
        LD      DE, (sched_save + 4)    ; DE = IP
        LD      BC, (sched_save + 6)    ; BC = TOS
        NEXT

; === task_exit — completion epilogue (the resume thread's 2nd cell) ===
; Reached when a finite task word's terminal EXIT chases past its xt into the
; t_thread[1] cell (= this address): NEXT does JP (HL) into here. Marks the
; running task ASLEEP and re-enters PAUSE, so the task leaves the rotation cleanly
; instead of running off its xt into garbage (FR4 / AC4). Shared by all tasks.
task_exit:
        LD      HL, (current_tcb)
        INC     HL
        INC     HL                      ; HL -> status (+2)
        LD      (HL), TASK_ASLEEP
        JP      w_PAUSE_cf

; === TASK ( -- task ) — carve a TCB from the bank-0 dictionary ===
; Allocates a TCB + its 256+256 B private stacks at HERE and returns the TCB base
; as the handle ACTIVATE consumes. THROWs -8 (dictionary overflow) if the carve
; would reach/cross $8000: a TCB in the slot-2 window would vanish under a foreign
; bank mapping (Story 24.3 memory-map note), fatal for a record PAUSE reads on
; every switch — so TCBs must stay below $8000. The fresh task is ASLEEP and
; spliced into the ring right after the running task; ACTIVATE makes it runnable.
; antforth extension — create a cooperative task control block.
w_TASK:
        DEFCODE "TASK", 0
w_TASK_cf:
        LD      (sched_ip), DE          ; preserve caller IP — the body uses DE as a pointer
        PUSH    BC                      ; save old TOS; the handle becomes the new TOS
        CALL    check_overflow          ; room for the produced cell (clobbers AF,HL)
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1) ; HL = HERE = prospective TCB base
        LD      E, L
        LD      D, H                    ; DE = TCB base (kept across the size add)
        LD      BC, TCB_SIZE
        ADD     HL, BC                  ; HL = new HERE (one past the TCB)
        LD      A, H
        CP      HIGH SLOT2_WINDOW_BASE  ; CY iff H < $80, i.e. new HERE below the window
        JR      C, .task_room
        ; reach-or-cross $8000: a TCB ending at/above the window is unreachable
        ; under a foreign mapping. (A carve ending exactly at $8000 is rejected
        ; too — conservative; the slack below $8000 is ~3 KB so this costs nothing
        ; real.) The earlier PUSH BC residue is wiped by THROW's wholesale SP reset.
        JP      dict_overflow_throw     ; raises -8 via w_THROW_cf.kernel_entry
.task_room:
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H ; commit HERE past the carve
        EX      DE, HL                  ; HL = TCB base (DE = spent new HERE)
        INC     HL
        INC     HL                      ; -> status (+2)
        LD      (HL), TASK_ASLEEP       ; not runnable until ACTIVATE
        DEC     HL
        DEC     HL                      ; HL -> TCB base (= its link field)
        ; Ring splice (insert after current_tcb — deterministic round-robin order,
        ; NFR-P6-8): new.link = current.link ; current.link = new.
        LD      DE, (current_tcb)       ; DE -> current.link
        LD      A, (DE)
        LD      (HL), A                 ; new.link.lo = current.link.lo
        INC     DE
        INC     HL
        LD      A, (DE)
        LD      (HL), A                 ; new.link.hi = current.link.hi
        DEC     HL                      ; HL -> new TCB base
        DEC     DE                      ; DE -> current.link.lo
        LD      A, L
        LD      (DE), A
        INC     DE
        LD      A, H
        LD      (DE), A                 ; current.link = new TCB base
        LD      B, H
        LD      C, L                    ; BC = TCB base = new TOS (the handle)
        LD      DE, (sched_ip)          ; restore caller IP
        NEXT

; === ACTIVATE ( xt task -- ) — arm a task and make it AWAKE ===
; Builds the task's resume thread [xt | task_exit] inside its TCB, seeds the saved
; registers (SP/IX at the tops of its private stacks, IP at the resume thread,
; TOS=0) and the subset (catch_top=0, current_bank/base inherited from the
; operator), and sets status AWAKE. On the next PAUSE the scheduler restores this
; task and NEXT enters `xt`; the word's terminal EXIT chases into task_exit.
; antforth extension — start a word running in a task.
w_ACTIVATE:
        DEFCODE "ACTIVATE", 0
w_ACTIVATE_cf:
        LD      (sched_ip), DE          ; preserve caller IP — the body uses DE as a pointer
        ; Drain any stale keyboard-break latch (Story 25.7). A Ctrl-\ pressed while
        ; no breakable task was AWAKE leaves break_pending set on the operator arm
        ; (it is consumed only by a non-operator PAUSE); without this clear a task
        ; entering the rotation would eat a spurious THROW -28 on its first yield —
        ; a break aimed at nothing before this task existed. The break only ever
        ; targets a task that was already running when Ctrl-\ was read.
        XOR     A
        LD      (break_pending), A
        LD      H, B
        LD      L, C                    ; HL = task (TCB base, the TOS)
        LD      (sched_tcb), HL         ; stash base for the offset recomputations below
        POP     DE                      ; DE = xt (NOS)
        ; --- resume thread t_thread = [xt | task_exit] (written first, while DE=xt) ---
        LD      BC, TCB_THREAD
        ADD     HL, BC                  ; HL -> t_thread
        LD      (HL), E
        INC     HL
        LD      (HL), D                 ; t_thread[0..1] = xt
        INC     HL
        LD      DE, task_exit
        LD      (HL), E
        INC     HL
        LD      (HL), D                 ; t_thread[2..3] = epilogue cf
        ; --- header fields, walked contiguously from status (+2) ---
        LD      HL, (sched_tcb)
        INC     HL
        INC     HL                      ; HL -> status (+2)
        LD      (HL), TASK_AWAKE
        INC     HL                      ; -> saved_sp (+3) = top of ps_area
        STORE_TCB_PTR TCB_PS + PS_SIZE  ; saved_sp = ps top
        INC     HL                      ; -> saved_ix (+5) = top of rs_area
        STORE_TCB_PTR TCB_RS + RS_SIZE  ; saved_ix = rs top
        INC     HL                      ; -> saved_de (+7) = &t_thread (resume IP)
        STORE_TCB_PTR TCB_THREAD        ; saved_de = &t_thread
        INC     HL                      ; -> saved_bc (+9) = 0 (clean TOS at entry)
        LD      (HL), 0
        INC     HL
        LD      (HL), 0
        INC     HL                      ; -> t_catch_top (+11) = 0 (own empty frame chain)
        LD      (HL), 0
        INC     HL
        LD      (HL), 0
        INC     HL                      ; -> t_current_bank (+13) = operator's current bank
        LD      A, (IY+UserArea.current_bank)
        LD      (HL), A
        INC     HL
        LD      A, (IY+UserArea.current_bank+1)
        LD      (HL), A
        INC     HL                      ; -> t_base (+15) = operator's BASE
        LD      A, (IY+UserArea.base)
        LD      (HL), A
        INC     HL
        LD      A, (IY+UserArea.base+1)
        LD      (HL), A
        INC     HL                      ; -> t_sp_base (+17) = top of the task's ps_area
        STORE_TCB_PTR TCB_PS + PS_SIZE  ; t_sp_base = ps top (= initial empty-stack base)
        POP     BC                      ; new TOS = the cell left below xt on the data stack
        LD      DE, (sched_ip)          ; restore caller IP
        NEXT

; === SLEEP ( task -- ) — park a task; the ring walk skips it until WAKE ===
; The operator-callable form of the task_exit epilogue's status write: it stores
; TASK_ASLEEP at (task+TCB_STATUS), so PAUSE's "skip non-AWAKE" walk steps over the
; task on every switch and it makes no further progress. `task` is the TCB base the
; matching TASK returned (the handle, TOS in BC). No new scheduler logic — only the
; status byte changes; PAUSE already honours it.
; Deadlock note: if the operator parks the last other AWAKE task and then its own
; thread also has no work, PAUSE finds no AWAKE TCB and loops forever (hard hang,
; reset-required) — the same cooperative-failure class as a non-yielding task. The
; operator's own handle is the static operator_tcb (never a TASK return), so SLEEP
; only reaches background tasks the operator explicitly created. Documented, not
; guarded (cooperative model).
; antforth extension — suspend a cooperative task.
w_SLEEP:
        DEFCODE "SLEEP", 0
w_SLEEP_cf:
        LD      H, B
        LD      L, C                    ; HL = task (TCB base, the TOS)
        INC     HL
        INC     HL                      ; -> status (+2 = TCB_STATUS)
        LD      (HL), TASK_ASLEEP
        POP     BC                      ; new TOS — DE=IP untouched throughout
        NEXT

; === WAKE ( task -- ) — resume an ASLEEP task into the rotation ===
; The inverse of SLEEP: stores TASK_AWAKE at (task+TCB_STATUS) so PAUSE's walk
; selects the task again, resuming it from its saved IP. WAKE of a task SUSPENDED by
; an uncaught throw (Story 25.6) revives a mid-unwind resume point — the correct
; recovery there is redefine + re-ACTIVATE, not WAKE; 25.4's WAKE is the cooperative
; ASLEEP->AWAKE resume only.
; antforth extension — resume a cooperative task.
w_WAKE:
        DEFCODE "WAKE", 0
w_WAKE_cf:
        XOR     A
        LD      (break_pending), A      ; drain a stale break latch (see ACTIVATE) —
                                        ; a task rejoining the rotation is not the
                                        ; break's target (Story 25.7)
        LD      H, B
        LD      L, C                    ; HL = task (TCB base, the TOS)
        INC     HL
        INC     HL                      ; -> status (+2 = TCB_STATUS)
        LD      (HL), TASK_AWAKE
        POP     BC                      ; new TOS — DE=IP untouched throughout
        NEXT

; === .TASKS ( -- ) — list the ring: each task's index + state ===
; A read-only ring walk anchored at operator_tcb (the static task-0 record), so the
; operator is deterministically task 0 and the anchor is a stable terminator. For
; each TCB it prints "   N M STATE": N = decimal index (print_bank_col_4), M = '*'
; for the current task else ' ' (mirrors .BANKS' current-bank marker), STATE one of
; AWAKE/ASLEEP/SUSPENDED. Mutates nothing — saves the caller's TOS+IP like .BANKS
; and runs straight-line asm with free use of BC/DE/HL. SUSPENDED is produced by the
; uncaught-THROW reroute in exception.asm (a faulting background task is parked
; SUSPENDED; recovery = redefine + re-ACTIVATE, not WAKE).
; antforth extension — task-set introspection (the .S/.BANKS convention).
w_DOT_TASKS:
        DEFCODE ".TASKS", 0
w_DOT_TASKS_cf:
        PUSH    BC                      ; save caller TOS
        CALL    rpush_de                ; save caller IP (DE=IP restored before NEXT)
        LD      HL, operator_tcb        ; HL = TCB walk pointer; operator is task 0
        LD      BC, 0                   ; C = task index (B unused)
.dt_row:
        PUSH    BC                      ; save index across the row's BDOS calls
        PUSH    HL                      ; save TCB base (the walk pointer)
        ; 1. index column — A = index, right-aligned 4-char decimal
        LD      A, C
        CALL    print_bank_col_4        ; clobbers A/BC/DE/HL
        LD      E, ' '
        CALL    bdos_putchar
        ; 2. current-task marker: '*' if this TCB == (current_tcb), else ' '
        POP     HL
        PUSH    HL                      ; HL = TCB base
        LD      DE, (current_tcb)
        LD      A, L
        CP      E
        JR      NZ, .dt_nostar
        LD      A, H
        CP      D
        JR      NZ, .dt_nostar
        LD      E, '*'
        JR      .dt_mark
.dt_nostar:
        LD      E, ' '
.dt_mark:
        CALL    bdos_putchar
        LD      E, ' '
        CALL    bdos_putchar
        ; 3. state string from the status byte (+2)
        POP     HL
        PUSH    HL                      ; HL = TCB base
        INC     HL
        INC     HL                      ; -> status
        LD      A, (HL)
        CP      TASK_AWAKE
        JR      Z, .dt_awake
        CP      TASK_SUSPENDED
        JR      Z, .dt_susp
        LD      HL, str_task_aslp       ; default: ASLEEP (status 0 or unknown)
        LD      B, str_task_aslp_len
        JR      .dt_pstate
.dt_awake:
        LD      HL, str_task_awake
        LD      B, str_task_awake_len
        JR      .dt_pstate
.dt_susp:
        LD      HL, str_task_susp
        LD      B, str_task_susp_len
.dt_pstate:
        CALL    bdos_print_str
        CALL    bdos_crlf
        ; 4. advance: follow this TCB's link to the next; loop until back at task 0
        POP     HL                      ; HL = TCB base (= its link field)
        LD      A, (HL)
        INC     HL
        LD      H, (HL)
        LD      L, A                    ; HL = next TCB base
        POP     BC                      ; recover index
        INC     C                       ; next index
        LD      A, L
        CP      LOW operator_tcb
        JR      NZ, .dt_row
        LD      A, H
        CP      HIGH operator_tcb
        JR      NZ, .dt_row
        ; ring closed (back at operator_tcb) — restore caller IP + TOS, resume
        CALL    rpop_de
        POP     BC
        NEXT

; State strings for .TASKS' status->name map (length-prefixed by EQU, the
; str_*/_len convention of banking.asm's .BANKS table). SUSPENDED is produced by the
; exception.asm uncaught-THROW reroute (fault-suspended background task).
str_task_awake:         DB "AWAKE"
str_task_awake_len      EQU 5
str_task_aslp:          DB "ASLEEP"
str_task_aslp_len       EQU 6
str_task_susp:          DB "SUSPENDED"
str_task_susp_len       EQU 9

; === >TASK ( n -- task ) — handle for the task at ring index n (as .TASKS shows) ===
; Walks the ring n links from operator_tcb (task 0) and returns that TCB base — the
; same handle TASK first produced — so `1 >TASK SLEEP` parks the task .TASKS lists as
; row 1 without having stashed its handle in a CONSTANT. n is the decimal index from
; .TASKS. The ring is circular, so an n past the last task simply wraps (always a
; live TCB, never garbage). n=0 is the operator (returned for symmetry, but SLEEPing
; it courts the documented no-AWAKE deadlock). Body uses only A/BC/HL — DE=IP is
; untouched (25.1 gotcha #1), so no save/restore. Indices assumed < 256 (capacity
; caps tasks well under that); the high byte of n is ignored.
; antforth extension — index->handle for the .TASKS introspection surface.
w_TO_TASK:
        DEFCODE ">TASK", 0
w_TO_TASK_cf:
        CALL    check_underflow         ; needs 1 cell (n); preserves BC/DE/IX/IY/SP
        LD      HL, operator_tcb        ; HL = task 0 base
.tf_loop:
        LD      A, C
        OR      A
        JR      Z, .tf_done             ; counter exhausted -> HL = wanted TCB base
        DEC     C                       ; one fewer link to chase
        LD      A, (HL)                 ; link lo (TCB_LINK = 0)
        INC     HL
        LD      H, (HL)                 ; link hi
        LD      L, A                    ; HL = next TCB base
        JR      .tf_loop
.tf_done:
        LD      B, H
        LD      C, L                    ; BC = TCB base = new TOS
        NEXT

; =====================================================================
; === Coordination section (AD-P6-8, Epic 26) — counting semaphores ===
; =====================================================================
; Cooperative, non-atomic-by-design primitives layered on the scheduler. Safe ONLY
; because the model is single-threaded except the 64 Hz ISR, and the ISR touches
; only TICKS (never a semaphore cell) — so no interrupt masking is needed. A context
; switch happens only at a PAUSE (a NEXT boundary); see WAIT for why the test-and-
; decrement is atomic w.r.t. the ring without a guard.

; === SEMAPHORE ( n "<spaces>name" -- ) — create a count cell initialised to n ===
; Mirrors VARIABLE's CREATE-then-comma shape (bootstrap.asm) but stores the SUPPLIED
; count instead of a literal 0: CREATE lays a JP DOVAR word whose body is HERE, then
; `,` stores the TOS count into that body cell. `name` afterwards pushes the count-
; cell address, @/!-addressable like any VARIABLE. A zero/negative n is stored
; verbatim (no clamping) — 0 SEMAPHORE means "start blocked".
; antforth extension — counting-semaphore constructor (Story 26.1, FR17).
w_SEMAPHORE:
        DEFWORD "SEMAPHORE", 0
w_SEMAPHORE_body:
w_SEMAPHORE_cf EQU w_SEMAPHORE_body - 3
        DW      w_CREATE_cf             ; ( n )  parse name, lay DOVAR word, HERE=body
        DW      w_COMMA_cf              ; ( )    store n into the body cell
        DW      EXIT_CODE

; === SIGNAL ( sem -- ) — increment the semaphore count ===
; Threaded DUP @ 1+ SWAP ! — reuses proven primitives, so no PAUSE register-contract
; exposure (DE=IP is preserved by every leaf here). One SIGNAL releases exactly one
; waiting unit; two WAITers blocked on the same cell cannot both consume it (see WAIT).
; antforth extension — release one unit of a counting semaphore (Story 26.1, FR17).
w_SIGNAL:
        DEFWORD "SIGNAL", 0
w_SIGNAL_body:
w_SIGNAL_cf EQU w_SIGNAL_body - 3
        DW      w_DUP_cf                ; ( sem sem )
        DW      w_FETCH_cf              ; ( sem count )
        DW      w_ONE_PLUS_cf           ; ( sem count+1 )
        DW      w_SWAP_cf               ; ( count+1 sem )
        DW      w_STORE_cf              ; ( )
        DW      EXIT_CODE

; === WAIT ( sem -- ) — yield-and-wait until count>0, then take one unit ===
; The loop mirrors (DELAY)'s PAUSE-FIRST spin seam (timer.asm): PAUSE is the first
; cell, so a task blocked on a zero count yields to the ring every pass instead of
; busy-spinning — the REPL and peer tasks keep running (FR17). The fetched count IS
; the loop flag: QBRANCH loops back on 0 (still blocked) and falls through on non-zero
; (a unit is available), so no 0=/0<> polarity word is needed.
; Non-atomic-but-safe: the ONLY PAUSE is at the top, BEFORE the check. Between the
; non-zero fall-through and the `!` decrement there is no PAUSE, so no other task can
; observe or mutate the count mid-decrement. Two tasks both blocked here cannot both
; consume a single SIGNAL: after SIGNAL bumps count to 1, whichever the round-robin
; runs next decrements it to 0; the other sees 0 and loops. No lost wakeup, no double-
; take — which is why masking is unnecessary and adding a PAUSE inside the check-
; decrement window would be WRONG.
; Starvation note (AI-25-3): a WAIT on a never-SIGNALed semaphore parks THIS task
; forever but keeps the ring alive (PAUSE-first) — the cooperative-friendly failure,
; unlike Story 25.7's non-yielding stall (a hard, reset-required wedge).
; antforth extension — take one unit of a counting semaphore, blocking (Story 26.1, FR17).
w_WAIT:
        DEFWORD "WAIT", 0
w_WAIT_body:
w_WAIT_cf EQU w_WAIT_body - 3
.wait_begin:
        DW      w_PAUSE_cf              ; yield-first every pass (FR17; ring stays live)
        DW      w_DUP_cf                ; ( sem sem )
        DW      w_FETCH_cf              ; ( sem count )  count is the flag
        DW      w_QBRANCH_cf
        DW      .wait_begin - $         ; loop back while count == 0
        DW      w_DUP_cf                ; ( sem sem )    count>0: take one unit
        DW      w_FETCH_cf              ; ( sem count )
        DW      w_ONE_MINUS_cf          ; ( sem count-1 )
        DW      w_SWAP_cf               ; ( count-1 sem )
        DW      w_STORE_cf              ; ( )   atomic w.r.t. the ring (no PAUSE above)
        DW      EXIT_CODE

; =====================================================================
; === Coordination section — the mutex (binary semaphore, Story 26.2) ===
; =====================================================================
; A mutex is a counting semaphore fixed at count 1: the cell holds 1 (unlocked)
; or 0 (locked). MUTEX/LOCK/UNLOCK are thin DEFWORD re-exposures of the 26.1
; primitives — no scheduler, PAUSE, or TCB state is touched, so the PAUSE
; register-contract (DE=IP preserved by every leaf) holds by construction.

; === MUTEX ( "<spaces>name" -- ) — create an unlocked binary-semaphore cell ===
; `1 SEMAPHORE`: push 1, then let SEMAPHORE's CREATE parse `name` from the live
; input stream and comma the 1. `name` afterwards pushes a cell holding 1
; (unlocked), @/!-addressable like a VARIABLE. Reuses SEMAPHORE's parse-then-
; comma mechanics verbatim — no new parse machinery.
; antforth extension — mutex constructor (Story 26.2, FR18).
w_MUTEX:
        DEFWORD "MUTEX", 0
w_MUTEX_body:
w_MUTEX_cf EQU w_MUTEX_body - 3
        DW      w_LIT_cf                ; ( )
        DW      1                       ; ( 1 )   fixed count 1 (unlocked)
        DW      w_SEMAPHORE_cf          ; ( )     parse name, lay cell = 1
        DW      EXIT_CODE

; === LOCK ( mtx -- ) — acquire, blocking (yield-first) ===
; Binary-semaphore acquire is identical to counting-semaphore acquire (block
; until count>0, then decrement), so LOCK is WAIT re-exposed under the mutex
; vocabulary: PAUSE-first spin, non-atomic-but-safe take, ring stays alive.
; Operator-context wedge caveat carries over from WAIT (see WAIT above and
; docs/phase6-multitasker.md): a blocking LOCK run AT THE REPL PROMPT on a mutex
; no background task will UNLOCK hard-wedges the machine — do blocking LOCKs in
; background TASKs.
; antforth extension — mutex acquire, blocking (Story 26.2, FR18).
w_LOCK:
        DEFWORD "LOCK", 0
w_LOCK_body:
w_LOCK_cf EQU w_LOCK_body - 3
        DW      w_WAIT_cf               ; ( mtx )  block-then-take, verbatim WAIT
        DW      EXIT_CODE

; === UNLOCK ( mtx -- ) — release, binary clamp (stores 1, NOT increment) ===
; `1 SWAP !`: stores 1, does NOT increment — a binary semaphore, so double-UNLOCK
; is idempotent (count stays 1) and cannot admit two holders; contrast SIGNAL,
; which is unbounded. Straight-line store, no PAUSE — release is atomic w.r.t.
; the ring, same discipline as SIGNAL.
; antforth extension — mutex release, binary clamp (Story 26.2, FR18).
w_UNLOCK:
        DEFWORD "UNLOCK", 0
w_UNLOCK_body:
w_UNLOCK_cf EQU w_UNLOCK_body - 3
        DW      w_LIT_cf                ; ( mtx )
        DW      1                       ; ( mtx 1 )
        DW      w_SWAP_cf               ; ( 1 mtx )
        DW      w_STORE_cf              ; ( )   set to 1 (unlocked), never 2
        DW      EXIT_CODE

; Cross-bank invariant (mirrors timer.asm): the whole scheduler — code, ring
; state, and the operator's static TCB — MUST live in always-mapped fixed memory
; below $8000, or PAUSE would lose the ring under a foreign bank mapping. The
; straddle-regression gate only catches colon-body IP crossings, not data/code
; placement, so guard it at build time here.
        ASSERT $ <= SLOT2_WINDOW_BASE
