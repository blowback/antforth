; structures.asm — sjasmplus STRUCT definitions
; AntForth — A Forth for CP/M on Z80

; === Dictionary Entry Structure ===
; Each dictionary entry has:
;   hash_link (3 bytes) — fat pointer [addr:2][bank:1] to the previous entry
;       in the same hash bucket (Story 20.1 bank-aware FIND; bank $FF = fixed
;       memory). Bucket heads share this [addr:2][bank:1] shape.
;   count_flags (1 byte) — bits 7=IMMEDIATE, 6=SMUDGE, 4-0=name length
;   name (n bytes) — name string (length from count_flags & 0x1F)
;   code_field — JP DOCOL (for threaded words) or inline Z80 (for CODE words)
; (Doc-only struct — no code addresses fields through it; the live layout is
;  hand-coded in dictionary.asm / compiler.asm.)
    STRUCT DictEntry
hash_link   DW      0               ; Previous entry addr in hash bucket chain
hash_bank   DB      0               ; Fat-pointer bank byte ($FF = fixed memory)
count_flags DB      0               ; Count + flags byte
; name and code field follow dynamically
    ENDS

; === User Variable Area Structure ===
; Pointed to by IY register
    STRUCT UserArea
state       DW      0               ; STATE: 0 = interpreting, non-zero = compiling
base        DW      0               ; BASE: current number base (default 10)
here        DW      0               ; HERE: next free dictionary address
latest      DW      0               ; LATEST: most recently defined word
tib_addr    DW      0               ; TIB: text input buffer address
tib_len     DW      0               ; #TIB: current input length
tib_in      DW      0               ; >IN: parse position in TIB
source_id   DW      0               ; SOURCE-ID: 0 = console
hld         DW      0               ; HLD: pictured-output write cursor
catch_top   DW      0               ; CATCH-TOP: most recent exception frame addr, 0 if none
pic_buf     DS      PIC_BUF_SIZE    ; Pictured-output buffer (fills RTL)
search_order_depth  DW      0       ; SEARCH-ORDER-DEPTH USER var
search_order        DS      32      ; 16 × 2-byte wid slots; slot 0 (offset 0) = top-of-search-order
current_wordlist    DW      0       ; CURRENT-WORDLIST USER var (wid for next dictionary insert)
dpl                 DW      0       ; DPL: digits-after-dot from last successful number parse, -1 if no dot.
                                    ; de-facto Forth convention (fig-Forth / F83 / gforth / SwiftForth / pforth);
                                    ; NOT in ANS Core. ANS Forth 1994 §3.4.1.3 dot-marker recogniser.
include_top         DW      0       ; INCLUDE-TOP: most-recent INCLUDE source-frame address, 0 if none.
                                    ; antforth extension — exposed via DEFCODE INCLUDE-TOP.
; --- Phase-4 banking (appended — pre-existing offsets unchanged) ---
saved_bank          DW      0       ; saved by outermost interactive BANK!; QUIT re-asserts on re-entry.
current_bank        DW      0       ; current logical bank index; BANK@ returns this. 0 = portal page (default bank 0).
bank_table_base     DW      0       ; base of bank-table[] (29-entry cap); COLD sets to BANK_TABLE_BASE = $D400.
bank_mapping_state  DW      0       ; non-zero iff MMU mapping enabled; BANK-MAPPING-ON sets 1, BANK-MAPPING-OFF sets 0.
                                    ; COLD's auto-BANK-MAPPING-ON sets to 1 before banner.
bank_count          DW      0       ; count of active banks (= length of the active-pages list). BANKS pushes this cell.
                                    ; COLD zero-inits; +BANK / -BANK / BANKS-CLEAR update it.
                                    ; Implemented as a DEFCODE-readable kernel cell rather than an ANS VALUE (VALUE / TO are
                                    ; deliberately omitted in v2.0 per docs/ans-forth-core-compliance.md).
stub_alloc_tail     DW      0       ; descriptor-stub allocator next-free pointer.
                                    ; COLD sets to STUB_ALLOC_BASE = $D4CB (src/constants.asm); stub_allocate writes 4 B + advances cell.
triple_owner        DB      0       ; bank index that owns the live (HERE, LATEST,
                                    ; wordlist_head) triple. Diverges from current_bank only inside a
                                    ; cross-bank dispatch window (stub_dispatch does NOT swap the triple).
                                    ; Written by COLD (0), real BANK! (new bank), and THROW's caught-path
                                    ; triple restore (CATCH frame +9). Single byte: bank index ≤ 28.
interp_bank_pending DB      0       ; one-shot flag set by the interpret loop's pre-execute (QMARK-BANK)
                                    ; peek when the token about to run IS an interactive BANK!, cleared
                                    ; otherwise; QSAVE-BANK (post-execute) commits current_bank->saved_bank
                                    ; iff still set. Carries the recognition across EXECUTE without using
                                    ; either stack (executed words may rearrange both). Always written
                                    ; before read (QMARK runs every direct-execute), so no COLD init needed.
prompt_show_bank    DW      0       ; opt-in REPL prompt bank indicator (Story 22.2). Non-zero → QUIT prompt
                                    ; prepends "[N]" (current bank) before " ok"; 0 → Phase-3 prompt. Default OFF
                                    ; (COLD zero-inits). DEFCODE-readable kernel cell (not an ANS VALUE, per the
                                    ; bank_mapping_state precedent above). Set/cleared by PROMPT-SHOW-BANK.
    ENDS

; === Task Control Block (Phase-6 cooperative multitasker) ===
; A fixed-memory record (always below $8000). TASK carves one per background task
; from the bank-0 dictionary; the operator (task 0) is a static header-only
; record (operator_tcb, src/multitasker.asm) that reuses the system stacks, so it
; needs no private ps_area/rs_area.
;
; PAUSE saves the running task's {saved_sp, saved_ix, saved_de, saved_bc} plus the
; per-task UserArea SUBSET {t_catch_top, t_current_bank, t_base} into its TCB, then
; restores the next AWAKE task's. That subset is EXACTLY the three cells AD-P6-1
; declares per-task: each task owns its exception-frame chain (catch_top), its bank
; (current_bank — saved/restored as a plain cell here; the conditional MBB_SET_PAGE
; re-page is Story 25.5), and its number base. Every OTHER UserArea cell (STATE,
; HERE, LATEST, the TIB/>IN parse state, search order, the whole bank-table) stays
; GLOBAL and is never touched by a task switch — background tasks run pre-compiled
; words and neither parse nor compile, so the interpreter/dictionary cells are
; operator-owned and uncontended.
;
; t_sp_base is NOT part of the AD-P6-1 subset — it is an implementation cell that
; makes the existing depth guards task-aware: each task's check_overflow /
; check_underflow / DEPTH must measure against its OWN private parameter stack, so
; PAUSE swaps the global sp_base cell to the running task's t_sp_base. (rp_base
; stays global; no background path guards the return stack.)
;
; t_thread is the 2-cell resume thread [xt | epilogue_cf] that ACTIVATE builds;
; saved_de points at it, so the task word's terminal EXIT chases past its xt into
; the completion epilogue (task_exit) and can never run off the end into garbage.
;
; Doc-struct only: the live record is hand-addressed via the TCB_* EQUs
; (src/constants.asm). The ASSERTs below pin the two representations together so a
; field reorder here without a matching EQU edit fails the build.
    STRUCT TCB
link            DW      0
status          DB      0
saved_sp        DW      0
saved_ix        DW      0
saved_de        DW      0
saved_bc        DW      0
t_catch_top     DW      0
t_current_bank  DW      0
t_base          DW      0
t_sp_base       DW      0
t_thread        DS      4
ps_area         DS      PS_SIZE
rs_area         DS      RS_SIZE
    ENDS
    ASSERT TCB.link == TCB_LINK
    ASSERT TCB.status == TCB_STATUS
    ASSERT TCB.saved_sp == TCB_SP
    ASSERT TCB.saved_ix == TCB_IX
    ASSERT TCB.saved_de == TCB_DE
    ASSERT TCB.saved_bc == TCB_BC
    ASSERT TCB.t_catch_top == TCB_CATCH
    ASSERT TCB.t_current_bank == TCB_BANK
    ASSERT TCB.t_base == TCB_BASE
    ASSERT TCB.t_sp_base == TCB_SPBASE
    ASSERT TCB.t_thread == TCB_THREAD
    ASSERT TCB.ps_area == TCB_PS
    ASSERT TCB.rs_area == TCB_RS
    ASSERT TCB == TCB_SIZE
