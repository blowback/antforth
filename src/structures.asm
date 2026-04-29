; structures.asm — sjasmplus STRUCT definitions
; AntForth — A Forth for CP/M on Z80

; === Dictionary Entry Structure ===
; Each dictionary entry has:
;   hash_link (2 bytes) — pointer to previous entry in same hash bucket
;   count_flags (1 byte) — bits 7=IMMEDIATE, 6=SMUDGE, 4-0=name length
;   name (n bytes) — name string (length from count_flags & 0x1F)
;   code_field — JP DOCOL (for threaded words) or inline Z80 (for CODE words)
    STRUCT DictEntry
hash_link   DW      0               ; Previous entry in hash bucket chain
count_flags DB      0               ; Count + flags byte
; name and code field follow dynamically
    ENDS

; === User Variable Area Structure ===
; Pointed to by IY register
    STRUCT UserArea
state       DW      0               ; STATE: 0 = interpreting, non-zero = compiling
base        DW      0               ; BASE: current number base (default 10)
here        DW      0               ; HERE: next free dictionary address
latest      DW      0               ; LATEST: most recently defined word
tib_addr    DW      0               ; TIB: text input buffer address
tib_len     DW      0               ; #TIB: current input length
tib_in      DW      0               ; >IN: parse position in TIB
source_id   DW      0               ; SOURCE-ID: 0 = console
hld         DW      0               ; HLD: pictured-output write cursor
catch_top   DW      0               ; CATCH-TOP: most recent exception frame addr, 0 if none (CCD-1)
pic_buf     DS      PIC_BUF_SIZE    ; Pictured-output buffer (fills RTL)
search_order_depth  DW      0       ; SEARCH-ORDER-DEPTH USER var (E12-D2 — architecture.md:332-336)
search_order        DS      32      ; 16 × 2-byte wid slots; slot 0 (offset 0) = top-of-search-order
    ENDS
