; hash.asm — Runtime XOR-rotate hash function
; AntForth — A Forth for CP/M on Z80
;
; Provides hash_name subroutine for dictionary lookup.
; Must produce identical results to the LUA assembly-time hash
; function in macros.asm (forth_hash).

; === hash_name — Compute dictionary hash for a name string ===
; Input:  HL = pointer to name string (raw characters, NOT counted)
;         B  = name length
; Output: A  = bucket index (0-63)
; Clobbers: HL (advanced past name), B (0), C, F
; Preserves: DE, IX, IY, SP
hash_name:
        LD      A, B            ; A = length
        OR      A               ; Test if zero (sets Z flag)
        LD      A, 0            ; A = 0 (hash accumulator) — LD doesn't affect flags
        JR      Z, .hash_done   ; Empty name -> bucket 0
.hash_loop:
        PUSH    AF              ; Save hash accumulator
        LD      A, (HL)         ; A = next character
        UPPER                   ; Convert to uppercase
        LD      C, A            ; C = uppercase character
        POP     AF              ; A = hash accumulator
        XOR     C               ; hash ^= uppercase_char
        RLC     A               ; Rotate left circular (bit 7 -> bit 0 and carry)
        INC     HL              ; Advance string pointer
        DJNZ    .hash_loop      ; Decrement B, loop if not zero
.hash_done:
        AND     63              ; Mask to 6-bit bucket index
        RET
