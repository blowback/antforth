; test_outer.asm — Group 6: Outer interpreter tests
; Tests: user vars, WORD, NUMBER?, ., U., .R, .S, HEX/DECIMAL, INTERPRET
; Expected output: ()*42 0 -1 -32768 65535     42<3> 1 2 3 FF A

test_group_outer:
        ; Test: BL pushes 0x20 (space)
        DW      w_BL_cf                 ; ( -- 0x20 )
        DW      w_LIT_cf, 0x20
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.tbl_off:
        DW      .tbl_fail - .tbl_off
        ; BL correct — use it to verify STATE returns valid address
        ; STATE should point to user_area + 0 (state offset)
        DW      w_STATE_cf              ; ( -- addr )
        DW      w_FETCH_cf              ; ( addr -- value ) STATE should be 0
        DW      w_ZERO_EQUALS_cf        ; 0 = TRUE
        DW      w_QBRANCH_cf
.tstate_off:
        DW      .tbl_fail - .tstate_off
        ; BASE should be 10
        DW      w_BASE_cf               ; ( -- addr )
        DW      w_FETCH_cf              ; ( addr -- value )
        DW      w_LIT_cf, 10
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.tbase_off:
        DW      .tbl_fail - .tbase_off
        ; >IN should be 0 (set during cold_start)
        DW      w_TO_IN_cf              ; ( -- addr )
        DW      w_FETCH_cf
        DW      w_ZERO_EQUALS_cf
        DW      w_QBRANCH_cf
.ttoIn_off:
        DW      .tbl_fail - .ttoIn_off
        ; SOURCE should return (tib_buffer, 0) at cold start
        DW      w_SOURCE_cf             ; ( -- c-addr u )
        DW      w_ZERO_EQUALS_cf        ; u=0 → TRUE
        DW      w_QBRANCH_cf
.tsource_off:
        DW      .tbl_fail - .tsource_off
        DW      w_LIT_cf, tib_buffer
        DW      w_EQUALS_cf             ; c-addr = tib_buffer?
        DW      w_QBRANCH_cf
.tsource2_off:
        DW      .tbl_fail - .tsource2_off
        ; All 5 user var tests passed — emit pass char
        DW      w_LIT_cf, '('          ; Use '(' as pass char
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tbl_jmp:
        DW      .tbl_end - .tbl_jmp
.tbl_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tbl_end:

        ; Test: WORD — manually set TIB to " HI ", then parse with WORD
        ; Set up: write " HI " to tib_buffer, set #TIB=4, >IN=0
        DW      w_LIT_cf, ' '
        DW      w_LIT_cf, tib_buffer
        DW      w_C_STORE_cf            ; tib_buffer[0] = ' '
        DW      w_LIT_cf, 'H'
        DW      w_LIT_cf, tib_buffer + 1
        DW      w_C_STORE_cf            ; tib_buffer[1] = 'H'
        DW      w_LIT_cf, 'I'
        DW      w_LIT_cf, tib_buffer + 2
        DW      w_C_STORE_cf            ; tib_buffer[2] = 'I'
        DW      w_LIT_cf, ' '
        DW      w_LIT_cf, tib_buffer + 3
        DW      w_C_STORE_cf            ; tib_buffer[3] = ' '
        ; Set #TIB = 4
        DW      w_LIT_cf, 4
        DW      w_TIB_LEN_cf           ; ( 4 -- 4 addr )
        DW      w_STORE_cf             ; ( 4 addr -- )
        ; Set >IN = 0
        DW      w_LIT_cf, 0
        DW      w_TO_IN_cf
        DW      w_STORE_cf
        ; Call BL WORD
        DW      w_BL_cf                 ; ( -- 32 )
        DW      w_WORD_cf               ; ( 32 -- c-addr )
        ; c-addr should be HERE, count byte should be 2, name should be "HI"
        DW      w_DUP_cf                ; ( c-addr -- c-addr c-addr )
        DW      w_C_FETCH_cf            ; ( c-addr c-addr -- c-addr count )
        DW      w_LIT_cf, 2
        DW      w_EQUALS_cf             ; count = 2?
        DW      w_QBRANCH_cf
.tword_off:
        DW      .tword_fail - .tword_off
        ; Check first char = 'H'
        DW      w_LIT_cf, 1             ; offset past count byte
        DW      w_PLUS_cf               ; c-addr+1
        DW      w_DUP_cf
        DW      w_C_FETCH_cf            ; first char
        DW      w_LIT_cf, 'H'
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.tword2_off:
        DW      .tword_fail - .tword2_off
        ; Check second char = 'I'
        DW      w_LIT_cf, 1
        DW      w_PLUS_cf               ; c-addr+2
        DW      w_C_FETCH_cf
        DW      w_LIT_cf, 'I'
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.tword3_off:
        DW      .tword_fail - .tword3_off
        DW      w_LIT_cf, ')'           ; Pass char for WORD test
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tword_jmp:
        DW      .tword_end - .tword_jmp
.tword_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tword_end:
        ; Reset >IN and #TIB for clean state
        DW      w_LIT_cf, 0
        DW      w_TO_IN_cf
        DW      w_STORE_cf
        DW      w_LIT_cf, 0
        DW      w_TIB_LEN_cf
        DW      w_STORE_cf

        ; Test: NUMBER? with "42" — should return 42 and TRUE
        DW      w_LIT_cf, test_num_42     ; counted string "42"
        DW      w_NUMBER_Q_cf             ; ( c-addr -- n true | c-addr false )
        DW      w_QBRANCH_cf              ; branch if false
.tnum1_off:
        DW      .tnum_fail - .tnum1_off
        ; Check n = 42
        DW      w_LIT_cf, 42
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.tnum2_off:
        DW      .tnum_fail - .tnum2_off
        ; Test: NUMBER? with "-7" — should return -7 (0xFFF9) and TRUE
        DW      w_LIT_cf, test_num_neg7
        DW      w_NUMBER_Q_cf
        DW      w_QBRANCH_cf
.tnum3_off:
        DW      .tnum_fail - .tnum3_off
        DW      w_LIT_cf, 0xFFF9          ; -7
        DW      w_EQUALS_cf
        DW      w_QBRANCH_cf
.tnum4_off:
        DW      .tnum_fail - .tnum4_off
        ; Test: NUMBER? with "abc" — should return c-addr and FALSE
        DW      w_LIT_cf, test_num_bad
        DW      w_NUMBER_Q_cf
        DW      w_ZERO_EQUALS_cf          ; FALSE → 0= → TRUE
        DW      w_QBRANCH_cf
.tnum5_off:
        DW      .tnum_fail - .tnum5_off
        DW      w_DROP_cf                 ; drop c-addr
        ; All NUMBER? tests pass
        DW      w_LIT_cf, '*'
        DW      w_EMIT_cf
        DW      w_BRANCH_cf
.tnum_jmp:
        DW      .tnum_end - .tnum_jmp
.tnum_fail:
        DW      w_LIT_cf, '!'
        DW      w_EMIT_cf
.tnum_end:

        ; --- Number formatting and stack inspection tests ---

        ; Test DOT: 42 . → "42 "
        DW      w_LIT_cf, 42
        DW      w_DOT_cf

        ; Test DOT zero: 0 . → "0 "
        DW      w_LIT_cf, 0
        DW      w_DOT_cf

        ; Test DOT negative: -1 . → "-1 "
        DW      w_LIT_cf, 0xFFFF       ; -1
        DW      w_DOT_cf

        ; Test DOT -32768: edge case → "-32768 "
        DW      w_LIT_cf, 0x8000       ; -32768
        DW      w_DOT_cf

        ; Test U.DOT: 65535 U. → "65535 "
        DW      w_LIT_cf, 0xFFFF
        DW      w_U_DOT_cf

        ; Test .R: 42 in field width 6 → "    42"
        DW      w_LIT_cf, 42
        DW      w_LIT_cf, 6
        DW      w_DOT_R_cf

        ; Test .S: Push 1, 2, 3 then .S → "<3> 1 2 3 "
        DW      w_LIT_cf, 1
        DW      w_LIT_cf, 2
        DW      w_LIT_cf, 3
        DW      w_DOT_S_cf
        ; Clean up: drop 3, 2, 1
        DW      w_DROP_cf
        DW      w_DROP_cf
        DW      w_DROP_cf

        ; Test HEX/DECIMAL: HEX, print 255 → "FF ", DECIMAL
        DW      w_HEX_cf
        DW      w_LIT_cf, 255
        DW      w_DOT_cf
        DW      w_DECIMAL_cf

        ; Test: INTERPRET — Set TIB to "65 EMIT" and call INTERPRET
        DW      w_LIT_cf, '6'
        DW      w_LIT_cf, tib_buffer
        DW      w_C_STORE_cf
        DW      w_LIT_cf, '5'
        DW      w_LIT_cf, tib_buffer + 1
        DW      w_C_STORE_cf
        DW      w_LIT_cf, ' '
        DW      w_LIT_cf, tib_buffer + 2
        DW      w_C_STORE_cf
        DW      w_LIT_cf, 'E'
        DW      w_LIT_cf, tib_buffer + 3
        DW      w_C_STORE_cf
        DW      w_LIT_cf, 'M'
        DW      w_LIT_cf, tib_buffer + 4
        DW      w_C_STORE_cf
        DW      w_LIT_cf, 'I'
        DW      w_LIT_cf, tib_buffer + 5
        DW      w_C_STORE_cf
        DW      w_LIT_cf, 'T'
        DW      w_LIT_cf, tib_buffer + 6
        DW      w_C_STORE_cf
        ; Set #TIB = 7
        DW      w_LIT_cf, 7
        DW      w_TIB_LEN_cf
        DW      w_STORE_cf
        ; Set >IN = 0
        DW      w_LIT_cf, 0
        DW      w_TO_IN_cf
        DW      w_STORE_cf
        ; Call INTERPRET — should push 65 then call EMIT (outputs 'A')
        DW      w_INTERPRET_cf

        ; Done — exit via EXECUTE of BYE (last group terminates)
        DW      w_LIT_cf, w_BYE_cf
        DW      w_EXECUTE_cf
