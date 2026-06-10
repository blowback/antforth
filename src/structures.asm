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
catch_top   DW      0               ; CATCH-TOP: most recent exception frame addr, 0 if none
pic_buf     DS      PIC_BUF_SIZE    ; Pictured-output buffer (fills RTL)
search_order_depth  DW      0       ; SEARCH-ORDER-DEPTH USER var
search_order        DS      32      ; 16 × 2-byte wid slots; slot 0 (offset 0) = top-of-search-order
current_wordlist    DW      0       ; CURRENT-WORDLIST USER var (wid for next dictionary insert)
dpl                 DW      0       ; DPL: digits-after-dot from last successful number parse, -1 if no dot.
                                    ; de-facto Forth convention (fig-Forth / F83 / gforth / SwiftForth / pforth);
                                    ; NOT in ANS Core. ANS Forth 1994 §3.4.1.3 dot-marker recogniser.
include_top         DW      0       ; INCLUDE-TOP: most-recent INCLUDE source-frame address, 0 if none.
                                    ; antforth extension — exposed via DEFCODE INCLUDE-TOP.
; --- Phase-4 banking (appended — pre-existing offsets unchanged) ---
saved_bank          DW      0       ; saved by outermost interactive BANK!; QUIT re-asserts on re-entry.
current_bank        DW      0       ; current logical bank index; BANK@ returns this. 0 = portal page (default bank 0).
bank_table_base     DW      0       ; base of bank-table[] (29-entry cap); COLD sets to BANK_TABLE_BASE = $D400.
bank_mapping_state  DW      0       ; non-zero iff MMU mapping enabled; BANK-MAPPING-ON sets 1, BANK-MAPPING-OFF sets 0.
                                    ; COLD's auto-BANK-MAPPING-ON sets to 1 before banner.
bank_count          DW      0       ; count of active banks (= length of the active-pages list). BANKS pushes this cell.
                                    ; COLD zero-inits; +BANK / -BANK / BANKS-CLEAR update it.
                                    ; Implemented as a DEFCODE-readable kernel cell rather than an ANS VALUE (VALUE / TO are
                                    ; deliberately omitted in v2.0 per docs/ans-forth-core-compliance.md).
stub_alloc_tail     DW      0       ; descriptor-stub allocator next-free pointer.
                                    ; COLD sets to STUB_ALLOC_BASE = $D4CB (src/constants.asm); stub_allocate writes 4 B + advances cell.
triple_owner        DB      0       ; bank index that owns the live (HERE, LATEST,
                                    ; wordlist_head) triple. Diverges from current_bank only inside a
                                    ; cross-bank dispatch window (stub_dispatch does NOT swap the triple).
                                    ; Written by COLD (0), real BANK! (new bank), and THROW's caught-path
                                    ; triple restore (CATCH frame +9). Single byte: bank index ≤ 28.
    ENDS
