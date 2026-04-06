; test_dictionary.asm — Group 5: Dictionary lookup tests
; Tests: FIND (known, unknown, case-insensitive, single-char, IMMEDIATE), COUNT
; Expected output: }~#$%&

test_group_dictionary:
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

        ; Chain to next test group
        DW      w_LIT_cf, test_group_outer
        DW      w_TEST_BRIDGE_cf
