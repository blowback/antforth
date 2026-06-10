; macros.asm — Threading, dictionary, and BDOS macros
; AntForth — A Forth for CP/M on Z80

; === Hash Bucket Heads (assembly-time LUA table) ===
; Pure LUA global table for bucket heads — avoids sj.insert_label/sj.get_label
; timing issues across assembler passes. The bucket count is fixed at 64 to
; match WORDLIST_BUCKETS (src/wordlists.asm). The literal `63` here, the
; `& 63` mask in forth_hash below, and `AND 63` in src/hash.asm:30 must all
; stay in sync with WORDLIST_BUCKETS — verified at assembly time by the
; ASSERT in src/wordlists.asm.
    LUA ALLPASS
        _hash_buckets = {}
        for i = 0, 63 do
            _hash_buckets[i] = 0
        end
    ENDLUA

; === UPPER — Convert ASCII character in A to uppercase ===
; If A is 'a'-'z', subtracts 0x20. Otherwise leaves A unchanged.
; Clobbers: F
    MACRO UPPER
        CP      'a'
        JR      C, .not_lower
        CP      'z' + 1
        JR      NC, .not_lower
        SUB     0x20
.not_lower:
    ENDM

; === NEXT — Inner interpreter fetch-decode-execute ===
; DE = IP, fetch [DE] into HL, advance DE by 2, JP (HL)
    MACRO NEXT
        EX      DE, HL          ; HL = IP
        NEXTHL
    ENDM

; === NEXTHL — NEXT when HL already holds IP ===
; Use when HL = IP, skipping the initial EX DE, HL
    MACRO NEXTHL
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        INC     HL
        EX      DE, HL          ; DE = IP+2, HL = code field address
        JP      (HL)
    ENDM

; === XOR-rotate hash computation (LUA helper) ===
; Computes hash of a name string at assembly time
    LUA ALLPASS
        function forth_hash(name)
            local h = 0
            local upper = string.upper(name)
            for i = 1, #upper do
                h = h ~ string.byte(upper, i)
                h = ((h << 1) | (h >> 7)) & 0xFF
            end
            return h & 63
        end
    ENDLUA

; === DEFCODE — Define a CODE word (native Z80) ===
; Usage: DEFCODE "NAME", flags
;   ... Z80 code body ...
;   NEXT
    MACRO DEFCODE name?, flags?
        ; Pass name to LUA via DEFINE
        DEFINE _CURRENT_NAME name?
        DEFINE _CURRENT_FLAGS flags?

        ; Dictionary header: emit hash_link and count_flags from LUA,
        ; then name from assembler. Uses _pc() to avoid sj.insert_label
        ; timing issues across assembler passes.
.dict_entry:
        LUA ALLPASS
            local raw = sj.get_define("_CURRENT_NAME")
            local name = raw:sub(2, -2)
            local flags = sj.calc(sj.get_define("_CURRENT_FLAGS"))
            _current_bucket = forth_hash(name)
            local prev = _hash_buckets[_current_bucket]
            -- Emit fat hash_link: [addr:2 little-endian][bank:1].
            -- Kernel entries always chain to fixed-memory predecessors, so
            -- the bank byte is BANK_FIXED ($FF).
            _pc(string.format("DW 0x%04X", prev))
            _pc("DB 0xFF")
            -- Emit count_flags byte (flags | name_length)
            _pc(string.format("DB 0x%02X", flags | #name))
        ENDLUA
        DB      name?                   ; Name string

        ; Update bucket head to this entry
        LUA ALLPASS
            _hash_buckets[_current_bucket] = sj.get_label(".dict_entry")
        ENDLUA

        UNDEFINE _CURRENT_NAME
        UNDEFINE _CURRENT_FLAGS

        ; Code field — body follows inline
.code_field:
    ENDM

; === DEFWORD — Define a colon (threaded) word ===
; Usage: DEFWORD "NAME", flags
;   DW addr1, addr2, ...
;   DW EXIT_CODE_ADDR
    MACRO DEFWORD name?, flags?
        DEFINE _CURRENT_NAME name?
        DEFINE _CURRENT_FLAGS flags?

.dict_entry:
        LUA ALLPASS
            local raw = sj.get_define("_CURRENT_NAME")
            local name = raw:sub(2, -2)
            local flags = sj.calc(sj.get_define("_CURRENT_FLAGS"))
            _current_bucket = forth_hash(name)
            local prev = _hash_buckets[_current_bucket]
            -- Fat hash_link: [addr:2][bank:1]; kernel predecessor → $FF fixed.
            _pc(string.format("DW 0x%04X", prev))
            _pc("DB 0xFF")
            _pc(string.format("DB 0x%02X", flags | #name))
        ENDLUA
        DB      name?                   ; Name string

        LUA ALLPASS
            _hash_buckets[_current_bucket] = sj.get_label(".dict_entry")
        ENDLUA

        UNDEFINE _CURRENT_NAME
        UNDEFINE _CURRENT_FLAGS

        ; Code field — JP DOCOL, then thread body follows
.code_field:
        JP      DOCOL
.body:
    ENDM

; === DEFIMMED — Define an IMMEDIATE colon word ===
; Usage: DEFIMMED "NAME"
;   DW addr1, addr2, ...
;   DW EXIT_CODE_ADDR
    MACRO DEFIMMED name?
        DEFWORD name?, F_IMMEDIATE
    ENDM

; === BDOS_SAVE — Save registers before BDOS call ===
; BDOS clobbers all registers; save DE (IP) and BC (TOS)
    MACRO BDOS_SAVE
        PUSH    DE              ; Save IP
        PUSH    BC              ; Save TOS
    ENDM

; === BDOS_RESTORE — Restore registers after BDOS call ===
    MACRO BDOS_RESTORE
        POP     BC              ; Restore TOS
        POP     DE              ; Restore IP
    ENDM
