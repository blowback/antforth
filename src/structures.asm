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
current_wordlist    DW      0       ; CURRENT-WORDLIST USER var (Story 12.4 — wid for next dictionary insert)
dpl                 DW      0       ; DPL: digits-after-dot from last successful number parse, -1 if no dot.
                                    ; de-facto Forth convention (fig-Forth / F83 / gforth / SwiftForth / pforth);
                                    ; NOT in ANS Core. Story 13.0 ANS Forth 1994 §3.4.1.3 dot-marker recogniser.
include_top         DW      0       ; INCLUDE-TOP: most-recent INCLUDE source-frame address, 0 if none (CCD-1).
                                    ; antforth extension — exposed via DEFCODE INCLUDE-TOP (Story 13.4 v2).
; --- Phase-4 banking (Story 17.1; appended — pre-existing offsets unchanged) ---
saved_bank          DW      0       ; PD-P4-5 (S5): saved by outermost interactive BANK!; QUIT re-asserts on re-entry (architecture.md:267).
                                    ; Story 17.1 declares the cell; QUIT re-assertion plumbing is Story 17.2 / Epic 21 scope.
current_bank        DW      0       ; FR-P4-1: current logical bank index; BANK@ returns this. 0 = portal page (default bank 0).
                                    ; Story 17.1 declares + zero-inits the cell; BANK@ / BANK! land in Story 17.2.
bank_table_base     DW      0       ; PD-P4-13 (29-entry cap): base of bank-table[]; COLD sets to BANK_TABLE_BASE = $D400 (architecture.md:386..402).
                                    ; Story 17.1 routes the value; Story 17.2 / Epic 19 reads from it.
bank_mapping_state  DW      0       ; FR-P4-11/12: non-zero iff MMU mapping enabled; BANK-MAPPING-ON sets 1, BANK-MAPPING-OFF sets 0.
                                    ; COLD's auto-BANK-MAPPING-ON sets to 1 before banner (architecture.md:323; redesign §5.1).
bank_count          DW      0       ; FR-P4-3: count of active banks (= length of the active-pages list). BANKS pushes this cell.
                                    ; Story 17.2 declares the cell + COLD zero-init; +BANK / -BANK / BANKS-CLEAR (Story 17.3) update it.
                                    ; Implemented as a DEFCODE-readable kernel cell rather than an ANS VALUE (VALUE / TO are
                                    ; `Deliberately-omitted` in v2.0 per docs/ans-forth-core-compliance.md:453,458).
    ENDS
