; constants.asm — Memory layout equates and system constants
; AntForth — A Forth for CP/M on Z80

; === CP/M System Addresses ===
BDOS_ENTRY      EQU     0x0005          ; BDOS entry point
BDOS_ADDR_PTR   EQU     0x0006          ; Word containing BDOS base address
TPA_START       EQU     0x0100          ; .COM entry point / start of TPA

; === BDOS Function Numbers ===
P_TERMCPM       EQU     0               ; BDOS function 0: terminate program
C_READ          EQU     1               ; BDOS function 1: console input (blocking, echoes)
C_WRITE         EQU     2               ; BDOS function 2: console output (E = char)
C_STATUS        EQU     11              ; BDOS function 11: console status (non-blocking)
C_READSTR       EQU     10              ; BDOS function 10: read console buffer

; === Stack Sizes ===
PS_SIZE         EQU     256             ; Parameter stack: 128 cells (256 bytes)
RS_SIZE         EQU     256             ; Return stack: 128 cells (256 bytes)

; === Dictionary ===
HASH_BUCKETS    EQU     64              ; Number of hash buckets

; === Text Input Buffer ===
TIB_SIZE        EQU     128             ; TIB size in bytes

; === PAD ===
PAD_OFFSET      EQU     84              ; PAD is 84 bytes above HERE

; === Number Formatting Buffer ===
NUM_BUF_SIZE    EQU     18              ; Max 16 binary digits + sign + safety

; === Pictured Numeric Output Buffer ===
; Per architecture decision E10-D2 (architecture.md:254-258): 40 bytes in
; UserArea, IY-relative, addressed via USER variable HLD. Sized to cover
; the 32-digit base-2 double-cell worst case plus sign plus decorators.
PIC_BUF_SIZE    EQU     40

; === Dictionary Entry Flags ===
F_IMMEDIATE     EQU     0x80            ; Bit 7: IMMEDIATE flag
F_SMUDGE        EQU     0x40            ; Bit 6: SMUDGE flag (hidden)
F_LENMASK       EQU     0x1F            ; Bits 0-4: name length (max 31)
