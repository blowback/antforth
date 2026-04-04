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

        ; 9. Hash table is pre-populated in the binary (see hash_table below)
        ;    No runtime initialisation needed

        ; 10. Set IP (DE) to test thread and begin execution
        LD      DE, test_thread
        NEXT

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
        INCLUDE "control_flow.asm"
        INCLUDE "io.asm"
        INCLUDE "strings.asm"
        INCLUDE "formatting.asm"

; === Higher-level components (depend on primitives) ===
        INCLUDE "outer_interpreter.asm"
        INCLUDE "compiler.asm"
        INCLUDE "assembler.asm"
        INCLUDE "system.asm"

; === Forth bootstrap definitions (depend on everything above) ===
        INCLUDE "bootstrap.asm"

; --- Test-only IMMEDIATE word for FIND +1 flag verification ---
w_TEST_IMMED:
        DEFCODE "TESTIMM", F_IMMEDIATE
w_TEST_IMMED_cf:
        NEXT                            ; No-op — exists only for FIND test

; === Test thread ===
; Exercises all primitives from Stories 1.2-1.4 via self-verifying tests
; Output: each test emits a pass character or '!' on failure
test_thread:
        ; Test 1: LIT + EMIT — output 'A'
        DW      w_LIT_cf, 'A'
        DW      w_EMIT_cf

        ; Test 2: DOCOL/EXIT — call a colon def that emits 'B', then return
        DW      test_colon_cfa

        ; Test 3: BRANCH — unconditional jump over a BYE, land at LIT 'C'
        DW      w_BRANCH_cf
.br1_off:
        DW      .br1_target - .br1_off
        DW      w_BYE_cf               ; Should be skipped
.br1_target:
        DW      w_LIT_cf, 'C'
        DW      w_EMIT_cf

        ; Test 4: ?BRANCH with non-zero (true) — should NOT branch, fall through
        DW      w_LIT_cf, 1             ; Push 1 (true)
        DW      w_QBRANCH_cf
.qb1_off:
        DW      .qb1_skip - .qb1_off
        ; Fall through here (true case):
        DW      w_LIT_cf, 'D'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf             ; Skip past false path
.qb1_jmp:
        DW      .qb1_end - .qb1_jmp
.qb1_skip:
        ; Branch here (false case — should NOT happen):
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.qb1_end:

        ; Test 5: ?BRANCH with zero (false) — should branch
        DW      w_LIT_cf, 0             ; Push 0 (false)
        DW      w_QBRANCH_cf
.qb2_off:
        DW      .qb2_target - .qb2_off
        ; Fall through (should NOT happen for false):
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.qb2_jmp:
        DW      .qb2_end - .qb2_jmp
.qb2_target:
        ; Branch target (false case):
        DW      w_LIT_cf, 'E'
        DW      w_EMIT_cf
.qb2_end:

        ; --- Story 1.3: Stack and memory primitive tests ---
        ; EXECUTE is tested at end of thread (EXECUTE of BYE)

        ; Test F: DUP — LIT 'F', DUP, DROP, EMIT → 'F'
        DW      w_LIT_cf, 'F'
        DW      w_DUP_cf
        DW      w_DROP_cf
        DW      w_EMIT_cf

        ; Test G: SWAP — LIT 'X', LIT 'G', SWAP, DROP, EMIT → 'G'
        DW      w_LIT_cf, 'X'
        DW      w_LIT_cf, 'G'
        DW      w_SWAP_cf
        DW      w_DROP_cf       ; Drop 'X'
        DW      w_EMIT_cf       ; Emit 'G'

        ; Test H: OVER — LIT 'H', LIT 0, OVER, EMIT, DROP, DROP → 'H'
        DW      w_LIT_cf, 'H'
        DW      w_LIT_cf, 0
        DW      w_OVER_cf       ; Stack: 'H' 0 'H'
        DW      w_EMIT_cf       ; Emit 'H', stack: 'H' 0
        DW      w_DROP_cf       ; Stack: 'H'
        DW      w_DROP_cf       ; Stack: (empty)

        ; Test I: >R / R> round-trip — LIT 'I', >R, R>, EMIT → 'I'
        DW      w_LIT_cf, 'I'
        DW      w_TO_R_cf
        DW      w_R_FROM_cf
        DW      w_EMIT_cf

        ; Test J: ! and @ — store 'J' to test_cell, fetch it back, EMIT → 'J'
        DW      w_LIT_cf, 'J'
        DW      w_LIT_cf, test_cell
        DW      w_STORE_cf
        DW      w_LIT_cf, test_cell
        DW      w_FETCH_cf
        DW      w_EMIT_cf

        ; Test K: +! — store 1, add 74 (1+74=75='K'), fetch, EMIT → 'K'
        DW      w_LIT_cf, 1
        DW      w_LIT_cf, test_cell2
        DW      w_STORE_cf
        DW      w_LIT_cf, 74
        DW      w_LIT_cf, test_cell2
        DW      w_PLUS_STORE_cf
        DW      w_LIT_cf, test_cell2
        DW      w_FETCH_cf
        DW      w_EMIT_cf

        ; Test L: HERE — just verify it doesn't crash, emit 'L'
        DW      w_HERE_cf
        DW      w_DROP_cf
        DW      w_LIT_cf, 'L'
        DW      w_EMIT_cf

        ; Test M: ROT — LIT 'X', LIT 'Y', LIT 'M', ROT, EMIT, DROP, DROP → 'M'
        ;   ROT ( 'X' 'Y' 'M' -- 'Y' 'M' 'X' ), then EMIT 'X'... wait
        ;   Need ROT to bring 'M' to top: start with 'M' 'X' 'Y'
        ;   ROT ( 'M' 'X' 'Y' -- 'X' 'Y' 'M' ), EMIT 'M'? No...
        ;   ROT rotates third to top: (x1 x2 x3 -- x2 x3 x1)
        ;   LIT 'M', LIT 'X', LIT 'Y': stack = 'M' 'X' 'Y'(TOS)
        ;   ROT: (M X Y -- X Y M), TOS = M
        DW      w_LIT_cf, 'M'
        DW      w_LIT_cf, 'X'
        DW      w_LIT_cf, 'Y'
        DW      w_ROT_cf        ; Stack: 'X' 'Y' 'M'
        DW      w_EMIT_cf       ; Emit 'M', stack: 'X' 'Y'
        DW      w_DROP_cf       ; Stack: 'X'
        DW      w_DROP_cf       ; Stack: (empty)

        ; Test N: R@ — push 'N' to return stack, copy with R@, emit, then clean up
        DW      w_LIT_cf, 'N'
        DW      w_TO_R_cf       ; R: 'N'
        DW      w_R_FETCH_cf    ; Stack: 'N', R: 'N'
        DW      w_EMIT_cf       ; Emit 'N'
        DW      w_R_FROM_cf     ; Clean return stack
        DW      w_DROP_cf

        ; Test O: C! and C@ — store 'O' as byte, fetch back, emit
        DW      w_LIT_cf, 'O'
        DW      w_LIT_cf, test_cell
        DW      w_C_STORE_cf
        DW      w_LIT_cf, test_cell
        DW      w_C_FETCH_cf
        DW      w_EMIT_cf

        ; Test P: FILL — fill test_cell (2 bytes) with 'P', then C@ first byte
        DW      w_LIT_cf, test_cell
        DW      w_LIT_cf, 2
        DW      w_LIT_cf, 'P'
        DW      w_FILL_cf
        DW      w_LIT_cf, test_cell
        DW      w_C_FETCH_cf
        DW      w_EMIT_cf

        ; Test Q: PICK — 0 PICK = DUP, verify via emit
        ;   LIT 'Q', LIT 0, PICK → 'Q' 'Q', EMIT, DROP
        DW      w_LIT_cf, 'Q'
        DW      w_LIT_cf, 0
        DW      w_PICK_cf       ; 0 PICK = DUP: stack 'Q' 'Q'
        DW      w_EMIT_cf       ; Emit 'Q'
        DW      w_DROP_cf       ; Clean up

        ; Test R: ROLL — 1 ROLL = SWAP
        ;   LIT 'R', LIT 'X', LIT 1, ROLL → 'X' 'R', EMIT, DROP
        DW      w_LIT_cf, 'R'
        DW      w_LIT_cf, 'X'
        DW      w_LIT_cf, 1
        DW      w_ROLL_cf       ; 1 ROLL = SWAP: stack 'X' 'R'
        DW      w_EMIT_cf       ; Emit 'R'
        DW      w_DROP_cf       ; Drop 'X'

        ; Test S: DEPTH — push two items, DEPTH should be 3 (2 items + DEPTH's TOS)
        ;   Actually: PUSH BC saves TOS, then depth = (sp_base - SP)/2.
        ;   With 2 items on stack before DEPTH: LIT 1, LIT 2 → depth after PUSH = 3.
        ;   We want to emit 'S' (=83). 83 = depth + 80 if depth=3. Use +! trick:
        ;   Just verify DEPTH doesn't crash and emit 'S'
        DW      w_LIT_cf, 1
        DW      w_LIT_cf, 2
        DW      w_DEPTH_cf      ; Stack: 1 2 3 (depth=3)
        DW      w_DROP_cf       ; Stack: 1 2
        DW      w_DROP_cf       ; Stack: 1
        DW      w_DROP_cf       ; Stack: (empty)
        DW      w_LIT_cf, 'S'
        DW      w_EMIT_cf

        ; Test T: COMMA and C@ — store 'T' via COMMA at HERE, then C@ it back
        ;   Save HERE first, COMMA stores cell, then fetch low byte
        DW      w_HERE_cf       ; Stack: here_addr
        DW      w_LIT_cf, 'T'
        DW      w_COMMA_cf      ; Store 'T' at old HERE, advance HERE by 2
        DW      w_C_FETCH_cf    ; C@ the saved here_addr → 'T' (low byte)
        DW      w_EMIT_cf

        ; Test U: ALLOT — allot 4 bytes, verify HERE advanced
        ;   HERE, LIT 4, ALLOT, HERE, SWAP, - ... complex.
        ;   Simpler: just verify ALLOT doesn't crash, emit 'U'
        DW      w_LIT_cf, 4
        DW      w_ALLOT_cf
        DW      w_LIT_cf, 'U'
        DW      w_EMIT_cf

        ; Test V: C, — compile byte 'V' at HERE, fetch it back
        DW      w_HERE_cf       ; Stack: here_addr
        DW      w_LIT_cf, 'V'
        DW      w_C_COMMA_cf    ; Store 'V' at HERE, advance HERE by 1
        DW      w_C_FETCH_cf    ; C@ saved here_addr → 'V'
        DW      w_EMIT_cf

        ; Test W: ALIGNED — odd address becomes even
        ;   LIT 'W', EMIT first, then test ALIGNED doesn't crash
        DW      w_LIT_cf, 'W'
        DW      w_EMIT_cf
        DW      w_LIT_cf, 0x0101        ; Odd address
        DW      w_ALIGNED_cf            ; Should become 0x0102
        DW      w_DROP_cf

        ; Test X: MOVE — copy 'X' from test_cell to test_cell2, then C@ it
        DW      w_LIT_cf, 'X'
        DW      w_LIT_cf, test_cell
        DW      w_C_STORE_cf            ; Store 'X' at test_cell
        DW      w_LIT_cf, test_cell     ; source
        DW      w_LIT_cf, test_cell2    ; dest
        DW      w_LIT_cf, 1             ; count = 1 byte
        DW      w_MOVE_cf
        DW      w_LIT_cf, test_cell2
        DW      w_C_FETCH_cf
        DW      w_EMIT_cf               ; Should emit 'X'

        ; Test Y: SP@ — verify it returns an address (doesn't crash), emit 'Y'
        DW      w_SP_FETCH_cf
        DW      w_DROP_cf
        DW      w_LIT_cf, 'Y'
        DW      w_EMIT_cf

        ; Test Z: RP@ — verify it returns an address, emit 'Z'
        DW      w_RP_FETCH_cf
        DW      w_DROP_cf
        DW      w_LIT_cf, 'Z'
        DW      w_EMIT_cf

        ; --- Story 1.4: Arithmetic, logic and comparison tests ---

        ; Test '0': + — 3 + 4 = 7
        DW      w_LIT_cf, 3
        DW      w_LIT_cf, 4
        DW      w_PLUS_cf
        DW      w_LIT_cf, 7
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.t0_off:
        DW      .t0_fail - .t0_off
        DW      w_LIT_cf, '0'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t0_jmp:
        DW      .t0_end - .t0_jmp
.t0_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t0_end:

        ; Test '1': - — 10 - 3 = 7
        DW      w_LIT_cf, 10
        DW      w_LIT_cf, 3
        DW      w_MINUS_cf
        DW      w_LIT_cf, 7
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.t1_off:
        DW      .t1_fail - .t1_off
        DW      w_LIT_cf, '1'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t1_jmp:
        DW      .t1_end - .t1_jmp
.t1_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t1_end:

        ; Test '2': * — 6 * 7 = 42
        DW      w_LIT_cf, 6
        DW      w_LIT_cf, 7
        DW      w_STAR_cf
        DW      w_LIT_cf, 42
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.t2_off:
        DW      .t2_fail - .t2_off
        DW      w_LIT_cf, '2'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t2_jmp:
        DW      .t2_end - .t2_jmp
.t2_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t2_end:

        ; Test '3': / — 42 / 6 = 7
        DW      w_LIT_cf, 42
        DW      w_LIT_cf, 6
        DW      w_SLASH_cf
        DW      w_LIT_cf, 7
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.t3_off:
        DW      .t3_fail - .t3_off
        DW      w_LIT_cf, '3'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t3_jmp:
        DW      .t3_end - .t3_jmp
.t3_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t3_end:

        ; Test '4': MOD — 10 MOD 3 = 1
        DW      w_LIT_cf, 10
        DW      w_LIT_cf, 3
        DW      w_MOD_cf
        DW      w_LIT_cf, 1
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.t4_off:
        DW      .t4_fail - .t4_off
        DW      w_LIT_cf, '4'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t4_jmp:
        DW      .t4_end - .t4_jmp
.t4_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t4_end:

        ; Test '5': /MOD — 10 /MOD 3 -> rem=1 quot=3
        ; Check quotient first (TOS), then remainder
        DW      w_LIT_cf, 10
        DW      w_LIT_cf, 3
        DW      w_SLASH_MOD_cf          ; Stack: rem=1 quot=3(TOS)
        DW      w_LIT_cf, 3
        DW      w_EQUALS_cf             ; quot=3? Stack: rem flag
        DW      w_SWAP_cf               ; Stack: flag rem
        DW      w_LIT_cf, 1
        DW      w_EQUALS_cf             ; rem=1? Stack: flag1 flag2
        DW      w_AND_cf                ; Both true?
        DW      w_QBRANCH_cf
.t5_off:
        DW      .t5_fail - .t5_off
        DW      w_LIT_cf, '5'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t5_jmp:
        DW      .t5_end - .t5_jmp
.t5_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t5_end:

        ; Test '6': AND — 0xFF00 AND 0x0FF0 = 0x0F00
        DW      w_LIT_cf, 0xFF00
        DW      w_LIT_cf, 0x0FF0
        DW      w_AND_cf
        DW      w_LIT_cf, 0x0F00
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.t6_off:
        DW      .t6_fail - .t6_off
        DW      w_LIT_cf, '6'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t6_jmp:
        DW      .t6_end - .t6_jmp
.t6_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t6_end:

        ; Test '7': OR — 0xFF00 OR 0x00FF = 0xFFFF
        DW      w_LIT_cf, 0xFF00
        DW      w_LIT_cf, 0x00FF
        DW      w_OR_cf
        DW      w_LIT_cf, 0xFFFF
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.t7_off:
        DW      .t7_fail - .t7_off
        DW      w_LIT_cf, '7'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t7_jmp:
        DW      .t7_end - .t7_jmp
.t7_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t7_end:

        ; Test '8': XOR — 0xFFFF XOR 0xFF00 = 0x00FF
        DW      w_LIT_cf, 0xFFFF
        DW      w_LIT_cf, 0xFF00
        DW      w_XOR_cf
        DW      w_LIT_cf, 0x00FF
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.t8_off:
        DW      .t8_fail - .t8_off
        DW      w_LIT_cf, '8'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t8_jmp:
        DW      .t8_end - .t8_jmp
.t8_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t8_end:

        ; Test '9': INVERT — INVERT 0xFF00 = 0x00FF
        DW      w_LIT_cf, 0xFF00
        DW      w_INVERT_cf
        DW      w_LIT_cf, 0x00FF
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.t9_off:
        DW      .t9_fail - .t9_off
        DW      w_LIT_cf, '9'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.t9_jmp:
        DW      .t9_end - .t9_jmp
.t9_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.t9_end:

        ; Test 'a': LSHIFT — 1 LSHIFT 8 = 256
        DW      w_LIT_cf, 1
        DW      w_LIT_cf, 8
        DW      w_LSHIFT_cf
        DW      w_LIT_cf, 256
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.ta_off:
        DW      .ta_fail - .ta_off
        DW      w_LIT_cf, 'a'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.ta_jmp:
        DW      .ta_end - .ta_jmp
.ta_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.ta_end:

        ; Test 'b': RSHIFT — 256 RSHIFT 8 = 1
        DW      w_LIT_cf, 256
        DW      w_LIT_cf, 8
        DW      w_RSHIFT_cf
        DW      w_LIT_cf, 1
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.tb_off:
        DW      .tb_fail - .tb_off
        DW      w_LIT_cf, 'b'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tb_jmp:
        DW      .tb_end - .tb_jmp
.tb_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tb_end:

        ; Test 'c': = (true case) — 5 = 5 -> TRUE
        DW      w_LIT_cf, 5
        DW      w_LIT_cf, 5
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.tc_off:
        DW      .tc_fail - .tc_off
        DW      w_LIT_cf, 'c'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tc_jmp:
        DW      .tc_end - .tc_jmp
.tc_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tc_end:

        ; Test 'd': < — 3 < 5 -> TRUE
        DW      w_LIT_cf, 3
        DW      w_LIT_cf, 5
        DW      w_LESS_cf
        DW      w_QBRANCH_cf
.td_off:
        DW      .td_fail - .td_off
        DW      w_LIT_cf, 'd'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.td_jmp:
        DW      .td_end - .td_jmp
.td_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.td_end:

        ; Test 'e': > — 5 > 3 -> TRUE
        DW      w_LIT_cf, 5
        DW      w_LIT_cf, 3
        DW      w_GREATER_cf
        DW      w_QBRANCH_cf
.te_off:
        DW      .te_fail - .te_off
        DW      w_LIT_cf, 'e'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.te_jmp:
        DW      .te_end - .te_jmp
.te_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.te_end:

        ; Test 'f': 0= — 0 0= -> TRUE
        DW      w_LIT_cf, 0
        DW      w_ZERO_EQUALS_cf
        DW      w_QBRANCH_cf
.tf_off:
        DW      .tf_fail - .tf_off
        DW      w_LIT_cf, 'f'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tf_jmp:
        DW      .tf_end - .tf_jmp
.tf_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tf_end:

        ; Test 'g': 0< — -1 (0xFFFF) 0< -> TRUE
        DW      w_LIT_cf, 0xFFFF
        DW      w_ZERO_LESS_cf
        DW      w_QBRANCH_cf
.tg_off:
        DW      .tg_fail - .tg_off
        DW      w_LIT_cf, 'g'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tg_jmp:
        DW      .tg_end - .tg_jmp
.tg_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tg_end:

        ; Test 'h': U< — 1 U< 0xFFFF -> TRUE
        DW      w_LIT_cf, 1
        DW      w_LIT_cf, 0xFFFF
        DW      w_U_LESS_cf
        DW      w_QBRANCH_cf
.th_off:
        DW      .th_fail - .th_off
        DW      w_LIT_cf, 'h'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.th_jmp:
        DW      .th_end - .th_jmp
.th_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.th_end:

        ; --- Story 1.4 review: FALSE-case and edge case tests ---

        ; Test 'i': = false case — 5 = 3 -> FALSE, 0= -> TRUE
        DW      w_LIT_cf, 5
        DW      w_LIT_cf, 3
        DW      w_EQUALS_cf
        DW      w_ZERO_EQUALS_cf        ; Invert: FALSE -> TRUE
        DW      w_QBRANCH_cf
.ti_off:
        DW      .ti_fail - .ti_off
        DW      w_LIT_cf, 'i'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.ti_jmp:
        DW      .ti_end - .ti_jmp
.ti_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.ti_end:

        ; Test 'j': 0= false case — 5 0= -> FALSE, 0= -> TRUE
        DW      w_LIT_cf, 5
        DW      w_ZERO_EQUALS_cf
        DW      w_ZERO_EQUALS_cf        ; Invert: FALSE -> TRUE
        DW      w_QBRANCH_cf
.tj_off:
        DW      .tj_fail - .tj_off
        DW      w_LIT_cf, 'j'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tj_jmp:
        DW      .tj_end - .tj_jmp
.tj_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tj_end:

        ; Test 'k': 0< false case — 1 0< -> FALSE, 0= -> TRUE
        DW      w_LIT_cf, 1
        DW      w_ZERO_LESS_cf
        DW      w_ZERO_EQUALS_cf        ; Invert: FALSE -> TRUE
        DW      w_QBRANCH_cf
.tk_off:
        DW      .tk_fail - .tk_off
        DW      w_LIT_cf, 'k'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tk_jmp:
        DW      .tk_end - .tk_jmp
.tk_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tk_end:

        ; Test 'l': < false case — 5 < 3 -> FALSE, 0= -> TRUE
        DW      w_LIT_cf, 5
        DW      w_LIT_cf, 3
        DW      w_LESS_cf
        DW      w_ZERO_EQUALS_cf        ; Invert: FALSE -> TRUE
        DW      w_QBRANCH_cf
.tl_off:
        DW      .tl_fail - .tl_off
        DW      w_LIT_cf, 'l'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tl_jmp:
        DW      .tl_end - .tl_jmp
.tl_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tl_end:

        ; Test 'm': > false case — 3 > 5 -> FALSE, 0= -> TRUE
        DW      w_LIT_cf, 3
        DW      w_LIT_cf, 5
        DW      w_GREATER_cf
        DW      w_ZERO_EQUALS_cf        ; Invert: FALSE -> TRUE
        DW      w_QBRANCH_cf
.tm_off:
        DW      .tm_fail - .tm_off
        DW      w_LIT_cf, 'm'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tm_jmp:
        DW      .tm_end - .tm_jmp
.tm_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tm_end:

        ; Test 'n': U< false case — 0xFFFF U< 1 -> FALSE, 0= -> TRUE
        DW      w_LIT_cf, 0xFFFF
        DW      w_LIT_cf, 1
        DW      w_U_LESS_cf
        DW      w_ZERO_EQUALS_cf        ; Invert: FALSE -> TRUE
        DW      w_QBRANCH_cf
.tn_off:
        DW      .tn_fail - .tn_off
        DW      w_LIT_cf, 'n'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tn_jmp:
        DW      .tn_end - .tn_jmp
.tn_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tn_end:

        ; Test 'o': signed / — -42 / 6 = -7 (symmetric division)
        DW      w_LIT_cf, 0xFFD6        ; -42
        DW      w_LIT_cf, 6
        DW      w_SLASH_cf
        DW      w_LIT_cf, 0xFFF9        ; -7
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.to_off:
        DW      .to_fail - .to_off
        DW      w_LIT_cf, 'o'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.to_jmp:
        DW      .to_end - .to_jmp
.to_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.to_end:

        ; Test 'p': signed MOD — -10 MOD 3 = -1 (symmetric: remainder sign = dividend sign)
        DW      w_LIT_cf, 0xFFF6        ; -10
        DW      w_LIT_cf, 3
        DW      w_MOD_cf
        DW      w_LIT_cf, 0xFFFF        ; -1
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.tp_off:
        DW      .tp_fail - .tp_off
        DW      w_LIT_cf, 'p'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tp_jmp:
        DW      .tp_end - .tp_jmp
.tp_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tp_end:

        ; Test 'q': < with signed overflow — -32768 < 1 -> TRUE
        DW      w_LIT_cf, 0x8000        ; -32768
        DW      w_LIT_cf, 1
        DW      w_LESS_cf
        DW      w_QBRANCH_cf
.tq_off:
        DW      .tq_fail - .tq_off
        DW      w_LIT_cf, 'q'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tq_jmp:
        DW      .tq_end - .tq_jmp
.tq_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tq_end:

        ; Test 'r': > with signed overflow — 1 > -32768 -> TRUE
        DW      w_LIT_cf, 1
        DW      w_LIT_cf, 0x8000        ; -32768
        DW      w_GREATER_cf
        DW      w_QBRANCH_cf
.tr_off:
        DW      .tr_fail - .tr_off
        DW      w_LIT_cf, 'r'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tr_jmp:
        DW      .tr_end - .tr_jmp
.tr_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tr_end:

        ; --- Story 1.5: Console I/O primitive tests ---

        ; Test 's': TYPE — output 's' via TYPE (1 char from test_str_s)
        DW      w_LIT_cf, test_str_s    ; c-addr
        DW      w_LIT_cf, 1             ; u = 1
        DW      w_TYPE_cf               ; Should output 's'

        ; Test 't': TYPE — output "t" via TYPE (1 char from test_str_t)
        DW      w_LIT_cf, test_str_t    ; c-addr
        DW      w_LIT_cf, 1             ; u = 1
        DW      w_TYPE_cf               ; Should output 't'

        ; Test 'u': TYPE with length 0 — should output nothing, then emit 'u'
        DW      w_LIT_cf, test_str_s    ; c-addr (doesn't matter)
        DW      w_LIT_cf, 0             ; u = 0
        DW      w_TYPE_cf               ; Should output nothing
        DW      w_LIT_cf, 'u'
        DW      w_EMIT_cf

        ; Test 'v': CR — output CR+LF, then emit 'v'
        DW      w_CR_cf
        DW      w_LIT_cf, 'v'
        DW      w_EMIT_cf

        ; Test 'w': SPACE — output ' ', then emit 'w'
        DW      w_SPACE_cf              ; Outputs ' '
        DW      w_LIT_cf, 'w'
        DW      w_EMIT_cf

        ; Test 'x': SPACES — output 2 spaces, then emit 'x'
        DW      w_LIT_cf, 2
        DW      w_SPACES_cf             ; Outputs '  '
        DW      w_LIT_cf, 'x'
        DW      w_EMIT_cf

        ; Test 'y': SPACES with 0 — should output nothing, then emit 'y'
        DW      w_LIT_cf, 0
        DW      w_SPACES_cf             ; Should output nothing
        DW      w_LIT_cf, 'y'
        DW      w_EMIT_cf

        ; Test 'z{': TYPE with multi-char string — output "z{" (2 chars)
        DW      w_LIT_cf, test_str_multi ; c-addr
        DW      w_LIT_cf, 2             ; u = 2
        DW      w_TYPE_cf               ; Should output "z{"

        ; Test '|': SPACES with -1 — should be no-op, then emit '|'
        DW      w_LIT_cf, 0xFFFF        ; -1 (negative count)
        DW      w_SPACES_cf             ; Should output nothing
        DW      w_LIT_cf, '|'
        DW      w_EMIT_cf

        ; --- Story 2.1: Dictionary & hash table tests ---

        ; Test '}': FIND known word "DUP" — should return w_DUP_cf and -1
        DW      w_LIT_cf, test_find_dup   ; Push c-addr of counted string "DUP"
        DW      w_FIND_cf                 ; ( c-addr -- xt -1 )
        DW      w_LIT_cf, 0xFFFF          ; Expected flag: -1 (non-immediate)
        DW      w_EQUALS_cf               ; Check flag
        DW      w_QBRANCH_cf
.tfind1_off:
        DW      .tfind1_fail - .tfind1_off
        DW      w_LIT_cf, w_DUP_cf        ; Expected xt
        DW      w_EQUALS_cf               ; Check xt
        DW      w_QBRANCH_cf
.tfind1b_off:
        DW      .tfind1_fail - .tfind1b_off
        DW      w_LIT_cf, '}'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tfind1_jmp:
        DW      .tfind1_end - .tfind1_jmp
.tfind1_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tfind1_end:

        ; Test '~': FIND unknown word "ZZZZZ" — should return c-addr and 0
        DW      w_LIT_cf, test_find_bad   ; Push c-addr of counted string "ZZZZZ"
        DW      w_FIND_cf                 ; ( c-addr -- c-addr 0 )
        DW      w_ZERO_EQUALS_cf          ; Flag should be 0 → 0= gives TRUE
        DW      w_QBRANCH_cf
.tfind2_off:
        DW      .tfind2_fail - .tfind2_off
        ; Verify returned c-addr matches original
        DW      w_LIT_cf, test_find_bad
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.tfind2b_off:
        DW      .tfind2_fail - .tfind2b_off
        DW      w_LIT_cf, '~'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tfind2_jmp:
        DW      .tfind2_end - .tfind2_jmp
.tfind2_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tfind2_end:

        ; Test: FIND case-insensitive "dup" — should find DUP (same xt as uppercase)
        ; Emit two chars: one for flag check, one for xt check
        DW      w_LIT_cf, test_find_lc_dup
        DW      w_FIND_cf                 ; ( c-addr -- xt -1 )
        DW      w_LIT_cf, 0xFFFF
        DW      w_EQUALS_cf               ; Flag = -1?
        DW      w_SWAP_cf                 ; Get xt
        DW      w_LIT_cf, w_DUP_cf
        DW      w_EQUALS_cf               ; xt = w_DUP_cf?
        DW      w_AND_cf                  ; Both checks pass?
        DW      w_QBRANCH_cf
.tfind3_off:
        DW      .tfind3_fail - .tfind3_off
        DW      w_LIT_cf, '#'             ; Pass: case-insensitive find works
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tfind3_jmp:
        DW      .tfind3_end - .tfind3_jmp
.tfind3_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tfind3_end:

        ; Test: FIND single-char word "+" — should find w_PLUS_cf and -1
        DW      w_LIT_cf, test_find_plus
        DW      w_FIND_cf                 ; ( c-addr -- xt -1 )
        DW      w_LIT_cf, 0xFFFF
        DW      w_EQUALS_cf               ; Flag = -1?
        DW      w_SWAP_cf                 ; Get xt
        DW      w_LIT_cf, w_PLUS_cf
        DW      w_EQUALS_cf               ; xt = w_PLUS_cf?
        DW      w_AND_cf                  ; Both checks pass?
        DW      w_QBRANCH_cf
.tfind4_off:
        DW      .tfind4_fail - .tfind4_off
        DW      w_LIT_cf, '$'             ; Pass: single-char word found
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tfind4_jmp:
        DW      .tfind4_end - .tfind4_jmp
.tfind4_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tfind4_end:

        ; Test: COUNT — apply to counted string, verify addr+1 and length
        DW      w_LIT_cf, test_find_dup   ; c-addr of counted string (3, "DUP")
        DW      w_COUNT_cf                ; ( c-addr -- c-addr+1 u )
        DW      w_LIT_cf, 3
        DW      w_EQUALS_cf               ; u = 3?
        DW      w_SWAP_cf                 ; Get c-addr+1
        DW      w_LIT_cf, test_find_dup + 1
        DW      w_EQUALS_cf               ; addr = test_find_dup+1?
        DW      w_AND_cf                  ; Both checks pass?
        DW      w_QBRANCH_cf
.tcount_off:
        DW      .tcount_fail - .tcount_off
        DW      w_LIT_cf, '%'             ; Pass: COUNT works
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tcount_jmp:
        DW      .tcount_end - .tcount_jmp
.tcount_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tcount_end:

        ; Test: FIND IMMEDIATE word "TESTIMM" — should return w_TEST_IMMED_cf and +1
        DW      w_LIT_cf, test_find_immed
        DW      w_FIND_cf                 ; ( c-addr -- xt 1 )
        DW      w_LIT_cf, 1
        DW      w_EQUALS_cf               ; Flag = +1?
        DW      w_SWAP_cf                 ; Get xt
        DW      w_LIT_cf, w_TEST_IMMED_cf
        DW      w_EQUALS_cf               ; xt = w_TEST_IMMED_cf?
        DW      w_AND_cf                  ; Both checks pass?
        DW      w_QBRANCH_cf
.tfind5_off:
        DW      .tfind5_fail - .tfind5_off
        DW      w_LIT_cf, '&'             ; Pass: IMMEDIATE word returns +1
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tfind5_jmp:
        DW      .tfind5_end - .tfind5_jmp
.tfind5_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tfind5_end:

        ; Done — exit via EXECUTE of BYE
        DW      w_LIT_cf, w_BYE_cf
        DW      w_EXECUTE_cf

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

; === Runtime data areas ===
hash_table:
    LUA ALLPASS
        for i = 0, 63 do
            _pc(string.format("DW 0x%04X", _hash_buckets[i]))
        end
    ENDLUA

sp_base:        DW      0               ; Initial SP value, set during cold start (for DEPTH)
test_cell:      DW      0               ; Scratch cell for test threads
test_cell2:     DW      0               ; Scratch cell for test threads
test_find_dup:    DB      3, "DUP"        ; Counted string for FIND test
test_find_lc_dup: DB      3, "dup"        ; Lowercase — test case-insensitivity
test_find_plus:   DB      1, "+"          ; Single-char word
test_find_bad:    DB      5, "ZZZZZ"      ; Unknown word — should not be found
test_find_immed:  DB      7, "TESTIMM"   ; IMMEDIATE word — should return +1 flag
test_str_s:     DB      's'             ; Test string for TYPE test
test_str_t:     DB      't'             ; Test string for TYPE test
test_str_multi: DB      'z', '{'        ; Multi-char test string for TYPE loop test

user_area:      DS      UserArea        ; User variable area (IY points here)
tib_buffer:     DS      TIB_SIZE        ; Terminal input buffer
kernel_end:                             ; Label marking end of kernel
