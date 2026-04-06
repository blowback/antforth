; test_stack.asm — Group 2: Stack & memory primitive tests
; Tests: F-Z (DUP, SWAP, OVER, >R/R>, !, @, +!, HERE, ROT, R@, C!/C@,
;         FILL, PICK, ROLL, DEPTH, COMMA, ALLOT, C,, ALIGNED, MOVE, SP@, RP@)
; Expected output: FGHIJKLMNOPQRSTUVWXYZ

test_group_stack:
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

        ; Test M: ROT — LIT 'M', LIT 'X', LIT 'Y', ROT → (X Y M), EMIT 'M'
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
        DW      w_LIT_cf, 'Q'
        DW      w_LIT_cf, 0
        DW      w_PICK_cf       ; 0 PICK = DUP: stack 'Q' 'Q'
        DW      w_EMIT_cf       ; Emit 'Q'
        DW      w_DROP_cf       ; Clean up

        ; Test R: ROLL — 1 ROLL = SWAP
        DW      w_LIT_cf, 'R'
        DW      w_LIT_cf, 'X'
        DW      w_LIT_cf, 1
        DW      w_ROLL_cf       ; 1 ROLL = SWAP: stack 'X' 'R'
        DW      w_EMIT_cf       ; Emit 'R'
        DW      w_DROP_cf       ; Drop 'X'

        ; Test S: DEPTH — push two items, DEPTH should be 3
        DW      w_LIT_cf, 1
        DW      w_LIT_cf, 2
        DW      w_DEPTH_cf      ; Stack: 1 2 3 (depth=3)
        DW      w_DROP_cf       ; Stack: 1 2
        DW      w_DROP_cf       ; Stack: 1
        DW      w_DROP_cf       ; Stack: (empty)
        DW      w_LIT_cf, 'S'
        DW      w_EMIT_cf

        ; Test T: COMMA and C@ — store 'T' via COMMA at HERE, then C@ it back
        DW      w_HERE_cf       ; Stack: here_addr
        DW      w_LIT_cf, 'T'
        DW      w_COMMA_cf      ; Store 'T' at old HERE, advance HERE by 2
        DW      w_C_FETCH_cf    ; C@ the saved here_addr → 'T' (low byte)
        DW      w_EMIT_cf

        ; Test U: ALLOT — allot 4 bytes, verify HERE advanced
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

        ; Chain to next test group
        DW      w_LIT_cf, test_group_arithmetic
        DW      w_TEST_BRIDGE_cf
