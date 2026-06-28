;------------------------------------------------------------------------------
; mmu_probe.asm — MicroBeast MMU port 0x72 (slot-2 page register) readback probe
;
; Standalone CP/M 2.2 .COM, INDEPENDENT of antforth (does not reference or
; share any src/*.asm). Settles one question: does `IN ...,(0x72)` read back
; the page last written by `OUT (0x72),A`, and does the answer depend on the
; Z80 instruction form?
;
;   `IN A,(n)`  (DB nn)  puts the ACCUMULATOR on A8..A15 during the I/O cycle.
;   `IN r,(C)`  (ED ..)  puts register B          on A8..A15.
;
; antforth's cl_probe_and_add and the DIV1RB.FTH reproducer both used the
; IMMEDIATE form `IN A,(0x72)` with an uncontrolled accumulator. If the
; MicroBeast MMU readback decode is sensitive to A8..A15, the immediate form
; would miss the device and float (a floating bus typically reflects the low
; address byte = the port number 0x72) while the register form reads correctly.
; The iz-cpm-banking emulator returns bank_map[2] for ANY read of 0x72
; regardless of the high byte, so it cannot exhibit this dependence.
;
; This probe writes known pages and reads them back five ways, capturing all
; results to low RAM BEFORE any console output, then restores the original
; slot-2 mapping and prints. It never reads/writes/executes in $8000..$BFFF
; (the slot-2 window), so remapping slot 2 to an arbitrary page is harmless;
; a private low stack keeps the stack out of the window too.
;
; Build:  cd tools/mmu_probe && sjasmplus --fullpath --nologo --raw=mmu_probe.com mmu_probe.asm
;   or:   make mmu-probe   (from repo root)
; Run on real MicroBeast (raw CP/M, NOT inside antforth): MMU_PROBE  (or  MMU_PROB)
;
; INTERPRETATION
;   * If a "write PP, read back" row shows PP for some form  -> port 0x72 IS
;     readable via that form. If the IN A,(C) rows read PP but the IN A,(n)
;     rows read 72 -> readback works; the immediate-form/high-byte decode was
;     the real DIV-1 cause (NOT a write-only port). Fix stands; DIAGNOSIS was
;     wrong.
;   * If EVERY read-back row is 72 (or constant garbage) regardless of form
;     and high byte -> port really is write-only; DIV-1 as diagnosed.
;------------------------------------------------------------------------------

BDOS            EQU     0x0005
MMU_SLOT2       EQU     0x72            ; MMU page register for $8000..$BFFF
MMU_ENABLE      EQU     0x74            ; MMU mapping-enable; bit 0 = enable

                ORG     0x0100

main:
                LD      SP, stack_top   ; private low stack (out of the window)

                ; ---- enable MMU mapping (mirrors antforth BANK-MAPPING-ON /
                ;      cold_start: LD A,1 / OUT (0x74),A). CP/M already runs
                ;      with mapping enabled, so this is an idempotent re-assert
                ;      — HW-proven safe (it's what antforth does at COLD). The
                ;      0x70-0x73 page registers are only live/readable while
                ;      mapping is enabled; without this the probe read 0x70
                ;      (registers inactive). NEVER write 0 here — that
                ;      disconnects RAM and warm-boots. ----
                LD      A, 1
                OUT     (MMU_ENABLE), A

                ; ---- save original slot-2 mapping (best effort, via C-form) ----
                LD      BC, 0x0072      ; B=00, C=port
                IN      A,(C)
                LD      (orig_page), A

                ; ================= LIVE reads (no write performed) =============
                LD      A, 0xFF         ; control A8..A15 = FF for the imm read
                IN      A,(MMU_SLOT2)   ; DB 72  (A8..A15 = FF)
                LD      (r_live_n), A

                LD      BC, 0x0072
                IN      A,(C)           ; A8..A15 = 00
                LD      (r_live_c00), A
                LD      BC, 0x7272
                IN      A,(C)           ; A8..A15 = 72
                LD      (r_live_c72), A
                LD      BC, 0xFF72
                IN      A,(C)           ; A8..A15 = FF
                LD      (r_live_cFF), A

                ; ================= write 0x35, read back five ways ============
                LD      A, 0x35
                OUT     (MMU_SLOT2), A  ; latch page 35
                ; A8..A15 currently = 35 (the just-written value)
                IN      A,(MMU_SLOT2)   ; DB 72, A8..A15 = 35
                LD      (r35_n_hi35), A

                LD      A, 0x35
                OUT     (MMU_SLOT2), A
                LD      A, 0x00         ; control A8..A15 = 00
                IN      A,(MMU_SLOT2)   ; DB 72, A8..A15 = 00
                LD      (r35_n_hi00), A

                LD      A, 0x35
                OUT     (MMU_SLOT2), A
                LD      BC, 0x0072
                IN      A,(C)           ; A8..A15 = 00
                LD      (r35_c00), A
                LD      A, 0x35
                OUT     (MMU_SLOT2), A
                LD      BC, 0x7272
                IN      A,(C)           ; A8..A15 = 72
                LD      (r35_c72), A
                LD      A, 0x35
                OUT     (MMU_SLOT2), A
                LD      BC, 0xFF72
                IN      A,(C)           ; A8..A15 = FF
                LD      (r35_cFF), A

                ; ================= write 0x3A, read back five ways ============
                LD      A, 0x3A
                OUT     (MMU_SLOT2), A
                IN      A,(MMU_SLOT2)   ; A8..A15 = 3A
                LD      (r3A_n_hi3A), A

                LD      A, 0x3A
                OUT     (MMU_SLOT2), A
                LD      A, 0x00
                IN      A,(MMU_SLOT2)   ; A8..A15 = 00
                LD      (r3A_n_hi00), A

                LD      A, 0x3A
                OUT     (MMU_SLOT2), A
                LD      BC, 0x0072
                IN      A,(C)
                LD      (r3A_c00), A
                LD      A, 0x3A
                OUT     (MMU_SLOT2), A
                LD      BC, 0x7272
                IN      A,(C)
                LD      (r3A_c72), A
                LD      A, 0x3A
                OUT     (MMU_SLOT2), A
                LD      BC, 0xFF72
                IN      A,(C)
                LD      (r3A_cFF), A

                ; ---- restore original slot-2 mapping before any console I/O ----
                LD      A, (orig_page)
                OUT     (MMU_SLOT2), A

                ; ============================ print =========================
                LD      DE, hdr_str
                CALL    puts

                LD      DE, live_hdr
                CALL    puts
                LD      DE, lbl_n_ff
                CALL    puts
                LD      A,(r_live_n)
                CALL    hexln
                LD      DE, lbl_c00
                CALL    puts
                LD      A,(r_live_c00)
                CALL    hexln
                LD      DE, lbl_c72
                CALL    puts
                LD      A,(r_live_c72)
                CALL    hexln
                LD      DE, lbl_cFF
                CALL    puts
                LD      A,(r_live_cFF)
                CALL    hexln

                LD      DE, w35_hdr
                CALL    puts
                LD      DE, lbl_n_hi_w
                CALL    puts
                LD      A,(r35_n_hi35)
                CALL    hexln
                LD      DE, lbl_n_hi00
                CALL    puts
                LD      A,(r35_n_hi00)
                CALL    hexln
                LD      DE, lbl_c00
                CALL    puts
                LD      A,(r35_c00)
                CALL    hexln
                LD      DE, lbl_c72
                CALL    puts
                LD      A,(r35_c72)
                CALL    hexln
                LD      DE, lbl_cFF
                CALL    puts
                LD      A,(r35_cFF)
                CALL    hexln

                LD      DE, w3A_hdr
                CALL    puts
                LD      DE, lbl_n_hi_w
                CALL    puts
                LD      A,(r3A_n_hi3A)
                CALL    hexln
                LD      DE, lbl_n_hi00
                CALL    puts
                LD      A,(r3A_n_hi00)
                CALL    hexln
                LD      DE, lbl_c00
                CALL    puts
                LD      A,(r3A_c00)
                CALL    hexln
                LD      DE, lbl_c72
                CALL    puts
                LD      A,(r3A_c72)
                CALL    hexln
                LD      DE, lbl_cFF
                CALL    puts
                LD      A,(r3A_cFF)
                CALL    hexln

                LD      DE, orig_hdr
                CALL    puts
                LD      A,(orig_page)
                CALL    hexln

                LD      DE, verdict_str
                CALL    puts

                JP      0x0000          ; warm boot

;------------------------------------------------------------------------------
; puts — print $-terminated string at DE via BDOS fn 9. Clobbers A,C,DE,(HL).
;------------------------------------------------------------------------------
puts:
                LD      C, 9
                JP      BDOS            ; tail-call

;------------------------------------------------------------------------------
; hexln — print A as two hex digits then CRLF. Clobbers A,B,C,DE,HL.
;------------------------------------------------------------------------------
hexln:
                PUSH    AF              ; byte safe on stack (BDOS fn 2 clobbers B/HL)
                RRCA
                RRCA
                RRCA
                RRCA
                CALL    hexnib          ; high nibble
                POP     AF              ; restore byte
                CALL    hexnib          ; low nibble
                LD      DE, crlf
                JP      puts            ; tail-call (CRLF + return)

hexnib:
                AND     0x0F
                ADD     A, '0'
                CP      '9' + 1
                JR      C, .emit
                ADD     A, 'A' - '0' - 10
.emit:
                LD      E, A
                LD      C, 2
                JP      BDOS            ; tail-call

;------------------------------------------------------------------------------
; Strings ($-terminated)
;------------------------------------------------------------------------------
hdr_str:    DB "MicroBeast MMU port 0x72 readback probe",0x0D,0x0A
            DB "(OUT 0x74<-1 mapping enabled; write a page, read 5 ways)",0x0D,0x0A,'$'
live_hdr:   DB 0x0D,0x0A,"Live (no write):",0x0D,0x0A,'$'
w35_hdr:    DB 0x0D,0x0A,"Wrote 35, read back:",0x0D,0x0A,'$'
w3A_hdr:    DB 0x0D,0x0A,"Wrote 3A, read back:",0x0D,0x0A,'$'
orig_hdr:   DB 0x0D,0x0A,"orig slot-2 page (C-form, B=00): ",'$'

lbl_n_ff:   DB "  IN A,(n)   A8-15=FF : ",'$'
lbl_n_hi_w: DB "  IN A,(n)   A8-15=pg : ",'$'   ; pg = the just-written page
lbl_n_hi00: DB "  IN A,(n)   A8-15=00 : ",'$'
lbl_c00:    DB "  IN A,(C)   B=00     : ",'$'
lbl_c72:    DB "  IN A,(C)   B=72     : ",'$'
lbl_cFF:    DB "  IN A,(C)   B=FF     : ",'$'

verdict_str:
            DB 0x0D,0x0A
            DB "READING THIS:",0x0D,0x0A
            DB "- A row that DIFFERS between the 35 and 3A blocks (even if",0x0D,0x0A
            DB "  masked, e.g. 35/3A or 15/1A) = that form READS the page.",0x0D,0x0A
            DB "- A row stuck at 72 (the port number) or any constant",0x0D,0x0A
            DB "  regardless of the written page = that form does NOT read.",0x0D,0x0A
            DB "If IN A,(C) tracks the page but IN A,(n) sits at 72, the",0x0D,0x0A
            DB "immediate-form high-byte decode was the DIV-1 cause, NOT a",0x0D,0x0A
            DB "write-only port. Every row constant -> port is write-only.",0x0D,0x0A,'$'

crlf:       DB 0x0D,0x0A,'$'

;------------------------------------------------------------------------------
; Result bytes + stack (all below $8000)
;------------------------------------------------------------------------------
orig_page:  DB 0
r_live_n:   DB 0
r_live_c00: DB 0
r_live_c72: DB 0
r_live_cFF: DB 0
r35_n_hi35: DB 0
r35_n_hi00: DB 0
r35_c00:    DB 0
r35_c72:    DB 0
r35_cFF:    DB 0
r3A_n_hi3A: DB 0
r3A_n_hi00: DB 0
r3A_c00:    DB 0
r3A_c72:    DB 0
r3A_cFF:    DB 0

            DS 64
stack_top:

            END
