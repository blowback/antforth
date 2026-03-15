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

        ; Test 6: EXECUTE — push BYE's code field address, then EXECUTE it
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

user_area:      DS      UserArea        ; User variable area (IY points here)
tib_buffer:     DS      TIB_SIZE        ; Terminal input buffer
kernel_end:                             ; Label marking end of kernel
