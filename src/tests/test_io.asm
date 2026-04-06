; test_io.asm — Group 4: I/O primitive tests
; Tests: s-| (TYPE, CR, SPACE, SPACES)
; Expected output: stu\r\nv w  xyz{|

test_group_io:
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

        ; Chain to next test group
        DW      w_LIT_cf, test_group_dictionary
        DW      w_TEST_BRIDGE_cf
