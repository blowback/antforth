; test_inner.asm — Group 1: Inner interpreter & control flow tests
; Tests: A-E (LIT, EMIT, DOCOL/EXIT, BRANCH, ?BRANCH)
; Expected output: ABCDE

test_group_inner:
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

        ; Chain to next test group
        DW      w_LIT_cf, test_group_stack
        DW      w_TEST_BRIDGE_cf
