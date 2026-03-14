; macros.asm — Threading, dictionary, and BDOS macros
; AntForth — A Forth for CP/M on Z80

; === Hash Bucket Heads (assembly-time variables) ===
; One variable per bucket, initialized to 0 (no previous entry)
    LUA ALLPASS
        for i = 0, 63 do
            sj.insert_label("_hash_bucket_" .. i, 0)
        end
    ENDLUA

; === NEXT — Inner interpreter fetch-decode-execute ===
; DE = IP, fetch [DE] into HL, advance DE by 2, JP (HL)
    MACRO NEXT
        EX      DE, HL          ; HL = IP
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
        ; Pass name to LUA via DEFINE (macro params aren't directly accessible as strings in LUA)
        DEFINE _CURRENT_NAME name?
        ; Compute hash, name length, and get previous bucket head via LUA
        LUA ALLPASS
            local name = sj.get_define("_CURRENT_NAME")
            local bucket = forth_hash(name)
            local prev = sj.get_label("_hash_bucket_" .. bucket)
            sj.insert_label("_hash_prev_link", prev)
            sj.insert_label("_hash_bucket_idx", bucket)
            sj.insert_label("_hash_name_len", #name)
        ENDLUA
        UNDEFINE _CURRENT_NAME

        ; Dictionary header
.dict_entry:
        DW      _hash_prev_link         ; Hash link: previous entry in same bucket
        DB      (flags?) | _hash_name_len ; Count + flags byte
        DB      name?                   ; Name string

        ; Update bucket head to this entry
        LUA ALLPASS
            local bucket = sj.get_label("_hash_bucket_idx")
            sj.insert_label("_hash_bucket_" .. bucket, sj.get_label(".dict_entry"))
        ENDLUA

        ; Code field — body follows inline
.code_field:
    ENDM

; === DEFWORD — Define a colon (threaded) word ===
; Usage: DEFWORD "NAME", flags
;   DW addr1, addr2, ...
;   DW EXIT_CODE_ADDR
    MACRO DEFWORD name?, flags?
        DEFINE _CURRENT_NAME name?
        LUA ALLPASS
            local name = sj.get_define("_CURRENT_NAME")
            local bucket = forth_hash(name)
            local prev = sj.get_label("_hash_bucket_" .. bucket)
            sj.insert_label("_hash_prev_link", prev)
            sj.insert_label("_hash_bucket_idx", bucket)
            sj.insert_label("_hash_name_len", #name)
        ENDLUA
        UNDEFINE _CURRENT_NAME

        ; Dictionary header
.dict_entry:
        DW      _hash_prev_link         ; Hash link
        DB      (flags?) | _hash_name_len ; Count + flags
        DB      name?                   ; Name string

        LUA ALLPASS
            local bucket = sj.get_label("_hash_bucket_idx")
            sj.insert_label("_hash_bucket_" .. bucket, sj.get_label(".dict_entry"))
        ENDLUA

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
