; antforth.asm — Main assembly manifest
; AntForth — A Forth for CP/M on Z80
; Includes all components in dependency order per architecture spec

        DEVICE NONE

; === System constants and definitions (no code emitted) ===
        INCLUDE "constants.asm"
        INCLUDE "macros.asm"
        INCLUDE "structures.asm"

; === Code starts at CP/M .COM entry point ===
        ORG     TPA_START               ; 0x0100

; === Cold Start ===
; Full cold start protocol: initialise stacks, registers, user variables,
; then begin executing the test thread via NEXT
cold_start:
        ; 1. Read BDOS address from 0x0006 for TPA top
        LD      HL, (BDOS_ADDR_PTR)     ; HL = BDOS base = top of TPA

        ; 2. SP = TPA top (parameter stack base, grows downward)
        LD      SP, HL

        ; 2b. Store SP base for DEPTH calculation
        ;     Z80 has no LD (nn),SP — use HL which still holds BDOS addr
        LD      (sp_base), HL

        ; 3. IX = SP - PS_SIZE (return stack base, below parameter stack region)
        OR      A               ; Clear carry flag before SBC
        LD      DE, PS_SIZE
        SBC     HL, DE          ; HL = return stack base
        PUSH    HL
        POP     IX              ; IX = return stack base

        ; 3b. Store initial return stack pointer for QUIT
        LD      (rp_base), HL

        ; 4. IY = user variable area
        LD      IY, user_area

        ; 5. STATE = 0 (interpret mode)
        LD      (IY+UserArea.state), 0
        LD      (IY+UserArea.state+1), 0

        ; 6. BASE = 10 (decimal)
        LD      (IY+UserArea.base), 10
        LD      (IY+UserArea.base+1), 0

        ; 7. HERE = kernel_end
        LD      HL, kernel_end
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H

        ; 8. TIB and >IN
        LD      HL, tib_buffer
        LD      (IY+UserArea.tib_addr), L
        LD      (IY+UserArea.tib_addr+1), H
        LD      (IY+UserArea.tib_len), 0
        LD      (IY+UserArea.tib_len+1), 0
        LD      (IY+UserArea.tib_in), 0
        LD      (IY+UserArea.tib_in+1), 0

        ; 8b. LATEST = 0, SOURCE-ID = 0
        LD      (IY+UserArea.latest), 0
        LD      (IY+UserArea.latest+1), 0
        LD      (IY+UserArea.source_id), 0
        LD      (IY+UserArea.source_id+1), 0

        ; 8b'. CATCH-TOP = 0 (no enclosing exception frame at REPL start)
        LD      (IY+UserArea.catch_top), 0
        LD      (IY+UserArea.catch_top+1), 0

        ; 8b''. INCLUDE-TOP = 0 (no INCLUDE source-frame at REPL start —
        ;       Story 13.4 v2; CCD-1 dual-LIFO chain head)
        LD      (IY+UserArea.include_top), 0
        LD      (IY+UserArea.include_top+1), 0

        ; 8c. HLD = IY + UserArea.pic_buf + PIC_BUF_SIZE
        ;     (sentinel one past the buffer's high end; <# resets to this)
        PUSH    IY
        POP     HL
        LD      DE, UserArea.pic_buf + PIC_BUF_SIZE
        ADD     HL, DE
        LD      (IY+UserArea.hld), L
        LD      (IY+UserArea.hld+1), H

        ; 8d. SEARCH-ORDER init — slot 0 = forth_wordlist; depth = 1.
        ;     ANS Forth 1994 §16.6.1.2195 SET-ORDER (-1) "minimum search order".
        ;     Slots 1..15 zero-initialised defensively (Story 12.3 AC #11
        ;     recommended pick) via plain DJNZ store loop. An LDIR cascade-
        ;     zero variant was ruled out: it shifted the binary layout in
        ;     a way that produced a layout-sensitive iz-cpm hang on the */
        ;     stack-underflow regression test (test 643). DJNZ keeps the
        ;     same defensive intent without that side effect — see
        ;     _bmad-output/implementation-artifacts/12-3-… Completion Notes
        ;     Task 8 in-pass-fix log.
        LD      HL, forth_wordlist
        LD      (IY+UserArea.search_order),   L
        LD      (IY+UserArea.search_order+1), H
        LD      (IY+UserArea.search_order_depth),   1
        LD      (IY+UserArea.search_order_depth+1), 0
        PUSH    IY
        POP     HL
        LD      BC, UserArea.search_order + 2
        ADD     HL, BC                          ; HL = &slot[1]
        LD      B, 30                           ; 30 bytes (slot 1..15)
        XOR     A
.so_init_zero:
        LD      (HL), A
        INC     HL
        DJNZ    .so_init_zero

        ; 8e. CURRENT-WORDLIST init — default compilation wordlist = FORTH-WORDLIST.
        ;     ANS Forth 1994 §16.6.1.2193 SET-CURRENT default-state convention.
        LD      HL, forth_wordlist
        LD      (IY+UserArea.current_wordlist),   L
        LD      (IY+UserArea.current_wordlist+1), H

        ; 8f. DPL init — -1 (0xFFFF) sentinel meaning "no dot seen on last parse".
        ;     Story 13.0 ANS Forth 1994 §3.4.1.3 dot-marker recogniser; DPL is a
        ;     de-facto Forth convention (fig-Forth / F83 / gforth) — NOT in ANS Core.
        LD      (IY+UserArea.dpl),   0xFF
        LD      (IY+UserArea.dpl+1), 0xFF

        ; 8g. FCB pool init — Story 13.1 file-access foundation (E13-D1,
        ;     architecture.md:354-358). Resets fcb_pool_bitmap, zeros
        ;     fcb_pool + fcb_dma_pool, and seeds fcb_byte_pos[] = 128
        ;     (sentinel: refill on first read).
        CALL    pool_init

        ; 9. FORTH-WORDLIST is pre-populated in the binary (see src/wordlists.asm)
        ;    No runtime initialisation needed

        ; 10. Enter execution
        IFDEF TEST_MODE
            ; Regression test mode: run first test group, exit via BYE
            LD      DE, test_group_inner
            NEXT
        ELSE
            ; Normal mode: print startup banner then enter QUIT
            LD      BC, 0           ; Clean TOS
            LD      DE, cold_thread
            NEXT                    ; Enter banner thread
cold_thread:
        ; Line 1: "AntForth v2.0.0 (C) ant.org 2026"
        DW      w_LIT_cf, str_banner1
        DW      w_LIT_cf, STR_BANNER1_LEN
        DW      w_TYPE_cf
        DW      w_CR_cf
        ; Line 2: "MicroBeast - XXXX bytes free"
        DW      w_LIT_cf, str_banner2
        DW      w_LIT_cf, STR_BANNER2_LEN
        DW      w_TYPE_cf
        ; Calculate free bytes: (sp_base - PS_SIZE - RS_SIZE) - HERE
        DW      w_LIT_cf, sp_base
        DW      w_FETCH_cf              ; ( sp_base_value )
        DW      w_LIT_cf, PS_SIZE + RS_SIZE
        DW      w_MINUS_cf              ; ( sp_base - 512 = bottom of stack area )
        DW      w_HERE_cf               ; ( stack_bottom here )
        DW      w_MINUS_cf              ; ( free_bytes )
        DW      w_U_DOT_cf              ; print unsigned number + space
        DW      w_LIT_cf, str_banner3
        DW      w_LIT_cf, STR_BANNER3_LEN
        DW      w_TYPE_cf
        DW      w_CR_cf
        ; Line 3: "Type BYE to exit"
        DW      w_LIT_cf, str_banner4
        DW      w_LIT_cf, STR_BANNER4_LEN
        DW      w_TYPE_cf
        DW      w_CR_cf
        ; Enter QUIT (CODE word — NEXT will JP to its assembly directly)
        DW      w_QUIT_cf
        ENDIF

; === Inner interpreter (DOCOL, EXIT, LIT, BRANCH, ?BRANCH, EXECUTE) ===
        INCLUDE "inner_interpreter.asm"

; === Dictionary and hash ===
        INCLUDE "dictionary.asm"
        INCLUDE "hash.asm"

; === CODE primitives ===
        INCLUDE "stack_ops.asm"
        INCLUDE "arithmetic.asm"
        INCLUDE "logic.asm"
        INCLUDE "memory.asm"
        INCLUDE "double.asm"
        INCLUDE "pictured.asm"
        INCLUDE "control_flow.asm"
        INCLUDE "io.asm"
        INCLUDE "strings.asm"
        INCLUDE "number_prefixes.asm"
        INCLUDE "formatting.asm"

; === Higher-level components (depend on primitives) ===
        INCLUDE "outer_interpreter.asm"
        INCLUDE "compiler.asm"
        INCLUDE "assembler.asm"
        INCLUDE "system.asm"
        INCLUDE "exception.asm"
        INCLUDE "file_access.asm"

; === Forth bootstrap definitions (depend on everything above) ===
        INCLUDE "bootstrap.asm"

        IFDEF TEST_MODE
; --- Test-only IMMEDIATE word for FIND +1 flag verification ---
w_TEST_IMMED:
        DEFCODE "TESTIMM", F_IMMEDIATE
w_TEST_IMMED_cf:
        NEXT                            ; No-op — exists only for FIND test

; === TEST_BRIDGE — CODE word to chain between test groups ===
; Resets parameter stack, return stack, and TOS, then starts next group thread.
; Usage: DW w_LIT_cf, test_group_next, w_TEST_BRIDGE_cf
; BC (TOS) = address of next test group thread (from LIT)
w_TEST_BRIDGE:
        DEFCODE "TEST-BRIDGE", 0
w_TEST_BRIDGE_cf:
        LD      H, B
        LD      L, C                    ; HL = next group address
        LD      SP, (sp_base)           ; Reset parameter stack
        LD      IX, (rp_base)           ; Reset return stack pointer
        LD      BC, 0                   ; Clean TOS (phantom)
        EX      DE, HL                  ; DE = next group address (new IP)
        NEXT                            ; Start next group

; --- Test colon definition: emits 'B' ---
; Manual construction (no DEFWORD macro) to control code field label
test_colon_header:
        DW      0               ; hash_link (not linked into dictionary)
        DB      10              ; count_flags: length 10, no flags
        DB      "TEST-COLON"    ; name
test_colon_cfa:                 ; Code field address (execution token)
        JP      DOCOL
        DW      w_LIT_cf, 'B'
        DW      w_EMIT_cf
        DW      EXIT_CODE

; === Test groups ===
; Each group is self-contained — no dependency on stack state from prior groups
        INCLUDE "tests/test_inner.asm"
        INCLUDE "tests/test_stack.asm"
        INCLUDE "tests/test_arithmetic.asm"
        INCLUDE "tests/test_io.asm"
        INCLUDE "tests/test_dictionary.asm"
        INCLUDE "tests/test_outer.asm"
        ENDIF

; === Wordlist struct + canonical FORTH-WORDLIST (Epic 12) ===
; Must follow ALL DEFCODE/DEFWORD invocations (including TEST_MODE-only
; words like TESTIMM and TEST-BRIDGE) so the LUA _hash_buckets[] table is
; fully populated when the bucket-array is emitted.
        INCLUDE "wordlists.asm"

; === Runtime data areas ===
sp_base:        DW      0               ; Initial SP value, set during cold start (for DEPTH)
rp_base:        DW      0               ; Initial IX value, set during cold start (for QUIT)
str_banner1:    DB      "AntForth v2.0.0 (C) ant.org 2026"
STR_BANNER1_LEN EQU     32
str_banner2:    DB      "MicroBeast - "
STR_BANNER2_LEN EQU     13
str_banner3:    DB      "bytes free"
STR_BANNER3_LEN EQU     10
str_banner4:    DB      "Type BYE to exit"
STR_BANNER4_LEN EQU     16
str_ok:         DB      " ok"
STR_OK_LEN      EQU     3
test_cell:      DW      0               ; Scratch cell for test threads
test_cell2:     DW      0               ; Scratch cell for test threads
test_find_dup:    DB      3, "DUP"        ; Counted string for FIND test
test_find_lc_dup: DB      3, "dup"        ; Lowercase — test case-insensitivity
test_find_plus:   DB      1, "+"          ; Single-char word
test_find_bad:    DB      5, "ZZZZZ"      ; Unknown word — should not be found
test_find_immed:  DB      7, "TESTIMM"   ; IMMEDIATE word — should return +1 flag
test_num_42:    DB      2, "42"         ; Counted string "42" for NUMBER? test
test_num_neg7:  DB      2, "-7"         ; Counted string "-7" for NUMBER? test
test_num_bad:   DB      3, "abc"        ; Non-numeric string for NUMBER? test
test_str_s:     DB      's'             ; Test string for TYPE test
test_str_t:     DB      't'             ; Test string for TYPE test
test_str_multi: DB      'z', '{'        ; Multi-char test string for TYPE loop test

num_buf:        DS      NUM_BUF_SIZE    ; Number-to-string conversion buffer
user_area:      DS      UserArea        ; User variable area (IY points here)
; BDOS function 10 input buffer — MUST be immediately before tib_buffer
bdos_input_buf: DS      1               ; max_len (set by ACCEPT before BDOS call)
bdos_input_len: DS      1               ; actual_len (filled by BDOS after call)
tib_buffer:     DS      TIB_SIZE        ; Terminal input buffer (BDOS writes chars here)
kernel_end:                             ; Label marking end of kernel
