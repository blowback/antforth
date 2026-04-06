; test_arithmetic.asm — Group 3: Arithmetic, logic & comparison tests
; Tests: 0-9, a-r (+, -, *, /, MOD, /MOD, AND, OR, XOR, INVERT,
;         LSHIFT, RSHIFT, =, <, >, 0=, 0<, U<, false cases, edge cases)
; Expected output: 0123456789abcdefghijklmnopqr

test_group_arithmetic:
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

        ; --- FALSE-case and edge case tests ---

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

        ; Test 'p': signed MOD — -10 MOD 3 = -1
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

        ; Chain to next test group
        DW      w_LIT_cf, test_group_io
        DW      w_TEST_BRIDGE_cf
