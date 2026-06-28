; memory.asm — Memory access, dictionary allocation, and bulk memory operations
; AntForth — A Forth for CP/M on Z80
;
; Memory access:  @, !, C@, C!, +!
; Dictionary:     HERE, ALLOT, , (COMMA), C,, ALIGN, ALIGNED
; Bulk:           FILL, MOVE

; -----------------------------------------------
; CELL+ ( a-addr -- a-addr+2 )
;   Add cell size (2) to address
; -----------------------------------------------
w_CELL_PLUS:
        DEFCODE "CELL+", 0
w_CELL_PLUS_cf:
        INC     BC
        INC     BC
        NEXT

; -----------------------------------------------
; CHAR+ ( c-addr -- c-addr+1 )
;   Add char size (1) to address
; -----------------------------------------------
w_CHAR_PLUS:
        DEFCODE "CHAR+", 0
w_CHAR_PLUS_cf:
        INC     BC
        NEXT

; -----------------------------------------------
; CHARS ( n -- n )
;   Convert chars to address units (no-op on Z80: 1 char = 1 byte)
; -----------------------------------------------
w_CHARS:
        DEFCODE "CHARS", 0
w_CHARS_cf:
        NEXT

; -----------------------------------------------
; @ ( addr -- x )
;   Fetch cell (16-bit) from memory
; ANS Forth 1994 §6.1.0650   @   — single-cell fetch
; -----------------------------------------------
w_FETCH:
        DEFCODE "@", 0
w_FETCH_cf:
        CALL    check_underflow
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
;   Push current dictionary pointer.
;
;   Per-bank HERE: the read path through (IY+UserArea.here) is
;   per-bank-correct by construction. BANK! (src/banking.asm) atomically
;   LDIR-swaps the (HERE, LATEST, wordlist_head) triple between
;   bank-table[old/new] and the live UserArea cells; the active cell is
;   the read-cache, the swap is the consistency mechanism.
;
;   Cross-bank pointer hazard: if the user holds HERE from bank A then
;   BANK!s to B and writes there, the write lands in bank B's dictionary
;   — undefined behaviour, no runtime guard.
; -----------------------------------------------
w_HERE:
        DEFCODE "HERE", 0
w_HERE_cf:
        PUSH    BC              ; Save old TOS
        LD      C, (IY+UserArea.here)
        LD      B, (IY+UserArea.here+1)   ; BC = HERE value
        NEXT

; -----------------------------------------------
; LATEST ( -- a-addr )           antforth extension
;   Push the address of the LATEST cell in UserArea. Read via
;   `LATEST @` (returns the dictionary entry pointer of the most-
;   recently-defined word in the current bank); write via `LATEST !`
;   (interactive dictionary surgery — uncommon but standard Forth
;   tradition).
;
;   Per-bank LATEST: the cell at (user_area + UserArea.latest) is
;   per-bank-correct by construction via BANK!'s LDIR triple-swap
;   (src/banking.asm).
;
;   Variable-style ( -- a-addr ) matches the gforth/SwiftForth/pforth
;   idiom and the existing antforth STATE / >IN convention.
; -----------------------------------------------
w_LATEST:
        DEFCODE "LATEST", 0
w_LATEST_cf:
        PUSH    BC                                    ; save old TOS
        LD      BC, user_area + UserArea.latest       ; BC = &LATEST cell
        NEXT

; -----------------------------------------------
; PAD ( -- c-addr )           ANS Forth 1994 §6.2.2000
;   Push the address of a transient region that survives parsing
;   of any one space-delimited name (§3.3.3.6). antforth places PAD
;   at HERE+PAD_OFFSET (PAD_OFFSET = 84, src/constants.asm); WORD stages
;   its counted-string output at HERE+0..HERE+31 (count byte at HERE+0,
;   ≤31 chars at HERE+1..HERE+u per F_LENMASK; see src/strings.asm),
;   which leaves HERE+32..HERE+84+ untouched, so PAD survives a single
;   WORD parse by construction.
;   PAD is also exposed as a word so /PAD ENVIRONMENT? ( 84 -1 ) has the
;   surface its compliance claim presupposes per §3.2.6.
; -----------------------------------------------
w_PAD:
        DEFCODE "PAD", 0
w_PAD_cf:
        PUSH    BC              ; Save old TOS
        LD      C, (IY+UserArea.here)
        LD      B, (IY+UserArea.here+1)   ; BC = HERE
        LD      HL, PAD_OFFSET             ; HL = 84
        ADD     HL, BC                     ; HL = HERE + 84 = PAD
        LD      B, H
        LD      C, L                       ; BC = PAD (new TOS)
        NEXT

; -----------------------------------------------
; ALLOT ( n -- )
;   Advance HERE by n bytes.
;
;   Per-bank ALLOT: read/write of (IY+UserArea.here) is per-bank via
;   BANK!'s LDIR triple-swap (src/banking.asm).
; -----------------------------------------------
w_ALLOT:
        DEFCODE "ALLOT", 0
w_ALLOT_cf:                             ; No underflow check — low-risk dictionary op
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)   ; HL = current HERE
        ADD     HL, BC                     ; HL = HERE + n  (prospective one-past-end)
        JR      C, .allot_carry            ; 16-bit wrap (huge +n) OR normal -n release
.allot_store:
        CALL    check_banked_headroom      ; Story 23.6: -8 if HERE+n straddles $C000 on a bank
        JP      C, dict_overflow_throw     ; (no-op on bank 0; HL preserved across the call)
        LD      (IY+UserArea.here), L
        LD      (IY+UserArea.here+1), H
        POP     BC              ; New TOS (n consumed)
        NEXT
.allot_carry:
        ; ADD HL,BC carried out of 16 bits. For a NEGATIVE n (sign bit set) this
        ; is a normal space-release — HL already holds the correct lower HERE
        ; (< $C000) so just store it. For a NON-NEGATIVE n the request wrapped
        ; past $FFFF and cannot fit a 16 KB window, so raise -8 — except on bank 0
        ; (fixed memory, no window) where the guard stays a strict no-op and the
        ; pre-guard wrapped-HERE behaviour is preserved.
        BIT     7, B                       ; B = n high byte → bit 7 = sign
        JR      NZ, .allot_store           ; n < 0: legitimate release, no overflow
        LD      A, (IY+UserArea.triple_owner)
        OR      A
        JR      Z, .allot_store            ; bank 0: no window, keep wrapped HERE
        JP      dict_overflow_throw        ; banked +n wrapped past $FFFF → -8

; -----------------------------------------------
; , (COMMA) ( x -- )
;   Compile cell at HERE, advance HERE by 2.
;
;   Per-bank `,`: writes through (IY+UserArea.here) into the current
;   bank's `here` via BANK!'s LDIR triple-swap (src/banking.asm).
;   Cross-bank `,` is NOT exposed — user MUST `BANK!` to target bank
;   before writing (explicit ergonomic decision). Cross-bank pointer
;   hazard: holding HERE from bank A then `BANK!`ing to B and writing
;   lands in B's dictionary — undefined; no runtime guard.
; -----------------------------------------------
w_COMMA:
        DEFCODE ",", 0
w_COMMA_cf:                             ; No underflow check — low-risk dictionary op
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)   ; HL = HERE
        GUARD_BANKED_WRITE 2               ; Story 23.6: -8 if the cell straddles $C000 on a bank
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
;   Compile byte at HERE, advance HERE by 1.
;
;   Per-bank `C,`: same per-bank-via-swap discipline as `,` above
;   (src/banking.asm).
;
;   Cross-bank pointer hazard: holding HERE from bank A then `BANK!`ing
;   to B and writing lands in B's dictionary — undefined; no runtime
;   guard. Same caveat as `,`.
; -----------------------------------------------
w_C_COMMA:
        DEFCODE "C,", 0
w_C_COMMA_cf:                           ; No underflow check — low-risk dictionary op
        LD      L, (IY+UserArea.here)
        LD      H, (IY+UserArea.here+1)
        GUARD_BANKED_WRITE 1               ; Story 23.6: -8 if the byte straddles $C000 on a bank
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
        ; Capture char in A (survives EXX), then use EXX to free BC/DE/HL scratch
        LD      A, C            ; A = fill byte (char) — must precede EXX
        EXX                     ; Save TOS/IP/W to shadows; main BC/DE/HL = scratch

        POP     HL              ; HL = u (count)
        POP     DE              ; DE = addr (safe — IP preserved in shadow)
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
        ; Restore IP from shadow
        EXX

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
        ; Preserve u across the EXX so main BC still holds count for LDIR/LDDR
        PUSH    BC              ; save u on param stack
        EXX                     ; save TOS/IP/W to shadows
        POP     BC              ; recover u into main BC

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
        ; Restore IP from shadow
        EXX

        POP     BC              ; New TOS
        NEXT
