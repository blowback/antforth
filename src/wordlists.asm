; wordlists.asm — Per-wordlist hash-table struct + canonical FORTH-WORDLIST
; AntForth — A Forth for CP/M on Z80
;
; Defines the 130-byte per-wordlist struct (E12-D1) and emits the kernel-
; resident FORTH-WORDLIST instance. Story 12.1 introduces the struct shape
; and parameterises dictionary lookup on a wordlist-struct address; the
; user-facing search-order words (WORDLIST, SEARCH-WORDLIST, FORTH-WORDLIST,
; GET-ORDER, SET-ORDER, …) arrive in Stories 12.2–12.5.
;
; Wordlist struct layout (architecture.md:326-330 — E12-D1):
;     +0   2 bytes   next-wordlist chain pointer (0 = end of chain)
;     +2 128 bytes   64 × 2-byte hash-bucket array
; Total = 130 bytes (= WORDLIST_SIZE).
;
; A wordlist identifier (`wid`, E12-D3) is the raw address of this struct.
; Dictionary lookup primitives load the bucket-head address as
; `wid + WORDLIST_BUCKET0` (i.e., struct base + 2). The legacy global
; `hash_table` symbol is retired in this story; every call site now
; addresses the bucket array via `forth_wordlist + WORDLIST_BUCKET0`.

; === Layout EQUs ===
WORDLIST_SIZE       EQU     130     ; architecture.md:328 — E12-D1 (2-byte next link + 64×2-byte buckets)
WORDLIST_BUCKETS    EQU     64      ; architecture.md:328 — E12-D1; sole source of truth (HASH_BUCKETS retired Story 12.1 per AC #5(d)(i))
                                    ; Three sites duplicate this literal for sjasmplus-pass-ordering reasons:
                                    ;   src/macros.asm:9   `for i = 0, 63 do`     (LUA _hash_buckets[] init — runs before this EQU is defined)
                                    ;   src/macros.asm:54  `return h & 63`        (LUA forth_hash mask — same pass-ordering)
                                    ;   src/hash.asm:30    `AND 63`               (runtime hash_name mask)
                                    ; Assertion below catches any future drift.
    ASSERT WORDLIST_BUCKETS = 64
WORDLIST_NEXT       EQU     0       ; architecture.md:326-330 — offset of next-wordlist chain link
WORDLIST_BUCKET0    EQU     2       ; architecture.md:326-330 — offset of first hash-bucket entry (per-bucket stride is 2 bytes)

; === FORTH-WORDLIST struct (kernel-resident, canonical) ===
; The bucket array is populated at assembly time by the LUA `_hash_buckets`
; table (src/macros.asm:7-12), which DEFCODE / DEFWORD update via
; `_hash_buckets[bucket] = sj.get_label(".dict_entry")` (src/macros.asm:75-86,
; 109-117). For the LUA expansion below to read populated buckets, this
; struct MUST be emitted AFTER all DEFCODE/DEFWORD invocations have run —
; i.e., this file must be INCLUDEd from src/antforth.asm AFTER bootstrap.asm
; (the last code-include). Emitting earlier would emit zeros.
forth_wordlist:
        DW      0                       ; WORDLIST_NEXT — chain end (FORTH-WORDLIST is canonical)
    LUA ALLPASS
        local n = sj.calc("WORDLIST_BUCKETS")
        for i = 0, n - 1 do
            _pc(string.format("DW 0x%04X", _hash_buckets[i]))
        end
    ENDLUA
