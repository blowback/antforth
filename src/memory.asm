; memory.asm — Memory access, dictionary allocation, and bulk memory operations
; AntForth — A Forth for CP/M on Z80
;
; Memory access:  @, !, C@, C!, +!
; Dictionary:     HERE, ALLOT, , (COMMA), C,, ALIGN, ALIGNED
; Bulk:           FILL, MOVE

; -----------------------------------------------
; @ ( addr -- x )
;   Fetch cell (16-bit) from memory
; -----------------------------------------------
w_FETCH:
        DEFCODE "@", 0
w_FETCH_cf:
        LD      H, B
        LD      L, C            ; HL = addr
        LD      C, (HL)
        INC     HL
        LD      B, (HL)         ; BC = cell at addr (little-endian)
        NEXT

; -----------------------------------------------
; ! ( x addr -- )
;   Store cell (16-bit) to memory
; -----------------------------------------------
w_STORE:
        DEFCODE "!", 0
w_STORE_cf:
        CALL    check_underflow_2
        LD      H, B
        LD      L, C            ; HL = addr (TOS)
        POP     BC              ; BC = x (value to store)
        LD      (HL), C
        INC     HL
        LD      (HL), B         ; Store x at addr (little-endian)
        POP     BC              ; New TOS (! consumes both items)
        NEXT

; -----------------------------------------------
; C@ ( addr -- char )
;   Fetch byte from memory
; -----------------------------------------------
w_C_FETCH:
        DEFCODE "C@", 0
w_C_FETCH_cf:
        LD      H, B
        LD      L, C            ; HL = addr
        LD      C, (HL)         ; C = byte
        LD      B, 0            ; Zero-extend to cell
        NEXT

; -----------------------------------------------
; C! ( char addr -- )
;   Store byte to memory
; -----------------------------------------------
w_C_STORE:
        DEFCODE "C!", 0
w_C_STORE_cf:
        CALL    check_underflow_2
        LD      H, B
        LD      L, C            ; HL = addr
        POP     BC              ; BC = char
        LD      (HL), C         ; Store low byte only
        POP     BC              ; New TOS
        NEXT

; -----------------------------------------------
; +! ( n addr -- )
;   Add n to cell at addr
; -----------------------------------------------
w_PLUS_STORE:
        DEFCODE "+!", 0
w_PLUS_STORE_cf:
        CALL    check_underflow_2
        LD      H, B
        LD      L, C            ; HL = addr
        POP     BC              ; BC = n
        LD      A, (HL)
        ADD     A, C
        LD      (HL), A         ; Low byte
        INC     HL
        LD      A, (HL)
        ADC     A, B
        LD      (HL), A         ; High byte (with carry)
        POP     BC              ; New TOS
        NEXT

; -----------------------------------------------
; HERE ( -- addr )
;   Push current dictionary pointer
; -----------------------------------------------
w_HERE:
        DEFCODE "HERE", 0
w_HERE_cf:
        PUSH    BC              ; Save old TOS
        LD      C, (IY+UserArea.here)
        LD      B, (IY+UserArea.here+1)   ; BC = HERE value
        NEXT

; -----------------------------------------------
; ALLOT ( n -- )
;   Advance HERE by n bytes
; -----------------------------------------------
w_ALLOT:
        DEFCODE "ALLOT", 0
w_ALLOT_cf:                             ; No underflow check — low-risk dictionary op
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)   ; HL = current HERE
        ADD     HL, BC                     ; HL = HERE + n
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        POP     BC              ; New TOS (n consumed)
        NEXT

; -----------------------------------------------
; , (COMMA) ( x -- )
;   Compile cell at HERE, advance HERE by 2
; -----------------------------------------------
w_COMMA:
        DEFCODE ",", 0
w_COMMA_cf:                             ; No underflow check — low-risk dictionary op
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)   ; HL = HERE
        LD      (HL), C
        INC     HL
        LD      (HL), B         ; Store cell (little-endian)
        INC     HL              ; HL = HERE + 2
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        POP     BC              ; New TOS
        NEXT

; -----------------------------------------------
; C, ( char -- )
;   Compile byte at HERE, advance HERE by 1
; -----------------------------------------------
w_C_COMMA:
        DEFCODE "C,", 0
w_C_COMMA_cf:                           ; No underflow check — low-risk dictionary op
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        LD      (HL), C         ; Store byte
        INC     HL              ; HERE + 1
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        POP     BC              ; New TOS
        NEXT

; -----------------------------------------------
; ALIGN ( -- )
;   Align HERE to cell boundary (even address)
; -----------------------------------------------
w_ALIGN:
        DEFCODE "ALIGN", 0
w_ALIGN_cf:
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        BIT     0, L            ; Test if odd
        JR      Z, .already_aligned
        INC     HL              ; Round up to even
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
.already_aligned:
        NEXT

; -----------------------------------------------
; ALIGNED ( addr -- addr' )
;   Round address up to cell alignment (even)
; -----------------------------------------------
w_ALIGNED:
        DEFCODE "ALIGNED", 0
w_ALIGNED_cf:
        BIT     0, C            ; Test if addr is odd
        JR      Z, .ok
        INC     BC              ; Round up
.ok:
        NEXT

; -----------------------------------------------
; CELLS ( n -- n*2 )
;   Multiply TOS by cell size (2 bytes)
; -----------------------------------------------
w_CELLS:
        DEFCODE "CELLS", 0
w_CELLS_cf:
        SLA     C
        RL      B               ; BC = BC * 2
        NEXT

; -----------------------------------------------
; FILL ( addr u char -- )
;   Fill u bytes starting at addr with char
; -----------------------------------------------
w_FILL:
        DEFCODE "FILL", 0
w_FILL_cf:                              ; No underflow check — low-risk bulk op
        ; BC = char (TOS), (SP) = u, (SP+2) = addr
        ; Save IP (DE) to return stack — LDIR uses DE
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D

        LD      A, C            ; A = fill byte (char)
        POP     HL              ; HL = u (count)
        POP     DE              ; DE = addr (safe now, IP is saved)
        ; Now: A=char, HL=count, DE=addr
        LD      B, H
        LD      C, L            ; BC = count
        LD      H, D
        LD      L, E            ; HL = addr
        LD      D, A            ; D = char (save)
        LD      A, B
        OR      C
        JR      Z, .fill_done   ; count = 0, skip
        LD      (HL), D         ; Store first byte
        DEC     BC              ; BC = count - 1
        LD      A, B
        OR      C
        JR      Z, .fill_done   ; count was 1, done
        LD      D, H
        LD      E, L            ; DE = addr (source for LDIR)
        INC     DE              ; DE = addr+1 (destination)
        LDIR                    ; Propagate fill byte through region
.fill_done:
        ; Restore IP from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX

        POP     BC              ; New TOS
        NEXT

; -----------------------------------------------
; MOVE ( addr1 addr2 u -- )
;   Copy u bytes from addr1 to addr2 (overlap-safe)
; -----------------------------------------------
w_MOVE:
        DEFCODE "MOVE", 0
w_MOVE_cf:                              ; No underflow check — low-risk bulk op
        ; BC = u (TOS), (SP) = addr2, (SP+2) = addr1
        ; Save IP (DE) to return stack — LDIR/LDDR use DE
        DEC     IX
        DEC     IX
        LD      (IX+0), E
        LD      (IX+1), D

        LD      A, B
        OR      C
        JR      Z, .move_zero   ; u=0, nothing to do
        POP     DE              ; DE = addr2 (destination)
        POP     HL              ; HL = addr1 (source)
        ; Determine direction: if DE > HL, copy backwards to handle overlap
        PUSH    HL              ; Save source
        OR      A               ; Clear carry
        SBC     HL, DE          ; HL = addr1 - addr2
        POP     HL              ; Restore HL = addr1
        JR      NC, .move_fwd   ; addr1 >= addr2: forward copy is safe
        ; Backward copy: start from end
        ; HL = addr1, DE = addr2, BC = count
        ADD     HL, BC
        DEC     HL              ; HL = addr1 + u - 1 (last source byte)
        EX      DE, HL          ; DE = last source, HL = addr2
        ADD     HL, BC
        DEC     HL              ; HL = addr2 + u - 1 (last dest byte)
        EX      DE, HL          ; HL = last source, DE = last dest
        LDDR                    ; Copy backwards
        JR      .move_done
.move_fwd:
        LDIR                    ; Copy forwards
        JR      .move_done
.move_zero:
        POP     DE              ; Discard addr2
        POP     HL              ; Discard addr1
.move_done:
        ; Restore IP from return stack
        LD      E, (IX+0)
        LD      D, (IX+1)
        INC     IX
        INC     IX

        POP     BC              ; New TOS
        NEXT
