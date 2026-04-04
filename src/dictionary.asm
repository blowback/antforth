; dictionary.asm — Dictionary lookup words
; AntForth — A Forth for CP/M on Z80
;
; Provides FIND and COUNT for dictionary operations.

; === COUNT ( c-addr -- c-addr+1 u ) ===
; Extract length from counted string, masking off flags
w_COUNT:
        DEFCODE "COUNT", 0
w_COUNT_cf:
        LD      A, (BC)         ; A = count/flags byte
        INC     BC              ; BC = c-addr+1 (name start)
        PUSH    BC              ; Push c-addr+1 (second on stack)
        AND     F_LENMASK       ; Mask off IMMEDIATE/SMUDGE flags
        LD      C, A
        LD      B, 0            ; BC = length (new TOS)
        NEXT

; === FIND ( c-addr -- c-addr 0 | xt 1 | xt -1 ) ===
; Search dictionary for word named by counted string at c-addr
w_FIND:
        DEFCODE "FIND", 0
w_FIND_cf:
        ; Save DE (IP) — we need registers as scratch
        PUSH    DE              ; Stack: [saved_IP, ...]

        ; BC = c-addr (TOS), save it for not-found case
        PUSH    BC              ; Stack: [c-addr, saved_IP, ...]

        ; Load name length and compute name address
        LD      A, (BC)         ; A = count byte (length)
        AND     F_LENMASK       ; Mask off any flags
        LD      (.find_len), A  ; Store search length
        INC     BC              ; BC = name address (c-addr+1)
        LD      (.find_name), BC ; Store name address

        ; Hash the name to get bucket index
        LD      H, B
        LD      L, C            ; HL = name address
        LD      B, A            ; B = name length
        CALL    hash_name       ; A = bucket index (0-63)

        ; Compute bucket head address: hash_table + A*2
        LD      L, A
        LD      H, 0            ; HL = bucket index
        ADD     HL, HL          ; HL = bucket index * 2
        LD      BC, hash_table
        ADD     HL, BC          ; HL = &hash_table[bucket]

        ; Load bucket head pointer
        LD      A, (HL)
        INC     HL
        LD      H, (HL)
        LD      L, A            ; HL = first entry address (or 0)

        ; === Chain traversal loop ===
        ; Base stack: [c-addr, saved_IP, ...]
.find_chain:
        ; Check if end of chain (HL == 0)
        LD      A, H
        OR      L
        JR      Z, .find_not_found

        ; HL points to dict entry: [hash_link 2B][count_flags 1B][name nB]
        ; Save entry address for following the chain
        PUSH    HL              ; Stack: [entry, c-addr, saved_IP, ...]

        ; Skip hash_link (2 bytes) to get count_flags
        INC     HL
        INC     HL              ; HL = &count_flags
        LD      A, (HL)         ; A = count_flags byte
        LD      (.find_cf_byte), A ; Save for later IMMEDIATE check

        ; Check SMUDGE flag — skip if set
        BIT     6, A            ; Test F_SMUDGE bit
        JR      NZ, .find_skip  ; Smudged entry, skip it

        ; Compare lengths
        AND     F_LENMASK       ; A = entry name length
        LD      C, A            ; C = entry name length
        LD      A, (.find_len)  ; A = search name length
        CP      C               ; Compare lengths
        JR      NZ, .find_skip  ; Different lengths, skip

        ; Lengths match — compare names case-insensitively
        INC     HL              ; HL = entry name start
        LD      DE, (.find_name) ; DE = search name start
        LD      B, C            ; B = name length (for loop counter)

.find_compare:
        LD      A, (HL)         ; Load entry char
        UPPER                   ; Convert to uppercase
        LD      C, A            ; C = uppercase entry char

        LD      A, (DE)         ; Load search char
        UPPER                   ; Convert to uppercase

        ; Compare
        CP      C
        JR      NZ, .find_skip  ; Mismatch, skip entry

        INC     HL              ; Next entry char
        INC     DE              ; Next search char
        DJNZ    .find_compare   ; Loop for all chars

        ; === Match found ===
        ; HL now points past the name = code field address (xt)
        ; Stack: [entry, c-addr, saved_IP, ...]

        POP     AF              ; Discard saved entry start
        POP     AF              ; Discard original c-addr
        POP     DE              ; Restore IP
        ; Stack: [...]

        PUSH    HL              ; Push xt as second-on-stack

        ; Check IMMEDIATE flag to determine return flag
        LD      A, (.find_cf_byte)
        BIT     7, A            ; Test F_IMMEDIATE bit
        JR      Z, .find_non_immediate

        ; IMMEDIATE word: flag = +1
        LD      BC, 1
        NEXT

.find_non_immediate:
        ; Non-immediate word: flag = -1 (0xFFFF)
        LD      BC, 0xFFFF
        NEXT

.find_not_found:
        ; Stack: [c-addr, saved_IP, ...]
        ; Return original c-addr and 0
        POP     BC              ; BC = original c-addr
        POP     DE              ; DE = saved IP
        PUSH    BC              ; Push c-addr as second-on-stack
        LD      BC, 0           ; BC = 0 (TOS = not-found flag)
        NEXT

.find_skip:
        ; Follow hash_link to next entry in chain
        ; Stack: [entry, c-addr, saved_IP, ...]
        POP     HL              ; HL = current entry start
        LD      A, (HL)         ; Low byte of hash_link
        INC     HL
        LD      H, (HL)         ; High byte of hash_link
        LD      L, A            ; HL = next entry (or 0)
        JR      .find_chain

; === Scratch storage for FIND ===
.find_len:      DB      0       ; Search name length
.find_name:     DW      0       ; Search name address
.find_cf_byte:  DB      0       ; Count/flags byte of current entry
