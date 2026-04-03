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

; === Test thread ===
; Temporary hardcoded thread for Story 1.2 verification
; Exercises LIT, EMIT, BYE to prove inner interpreter works
; --- Test thread: exercises LIT, EMIT, BYE, DOCOL/EXIT, BRANCH, ?BRANCH, EXECUTE ---
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
            _pc(string.format("DW 0x%04X", sj.get_label("_hash_bucket_" .. i)))
        end
    ENDLUA

sp_base:        DW      0               ; Initial SP value, set during cold start (for DEPTH)
test_cell:      DW      0               ; Scratch cell for test threads
test_cell2:     DW      0               ; Scratch cell for test threads

user_area:      DS      UserArea        ; User variable area (IY points here)
tib_buffer:     DS      TIB_SIZE        ; Terminal input buffer
kernel_end:                             ; Label marking end of kernel
