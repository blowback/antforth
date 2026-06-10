;------------------------------------------------------------------------------
; mbb_probe.asm — exercise the BIOS page-mapping routines MBB_SET_PAGE /
; MBB_GET_PAGE (the blessed interface; ports 0x70-0x73 are write-only).
; Standalone CP/M .COM, independent of antforth.
;
;   MBB_SET_PAGE (0xFDDF): A = logical CPU page 0-2; E = physical page.
;   MBB_GET_PAGE (0xFDDC): C = logical CPU page 0-2; returns A = physical.
;
; Demonstrates, on logical page 2 (the $8000-$BFFF window antforth uses):
;   1. MBB_SET_PAGE then MBB_GET_PAGE round-trips (read back what was set).
;   2. A direct `OUT (0x72)` write does NOT update the BIOS shadow, so a
;      following MBB_GET_PAGE reads back STALE — the desync hazard that bit
;      antforth on hardware (and the reason to drop direct port I/O).
;
; The window itself is never read/executed; private low stack. Restores the
; original page-2 mapping via MBB before exit.
;
; Build:  cd tools/mbb_probe && sjasmplus --fullpath --nologo --raw=mbbprobe.com mbb_probe.asm
;   or:   make mbb-probe   (from repo root)
;------------------------------------------------------------------------------

BDOS            EQU     0x0005
MBB_GET_PAGE    EQU     0xFDDC
MBB_SET_PAGE    EQU     0xFDDF

                ORG     0x0100

main:
                LD      SP, stack_top

                LD      C, 2                ; save original physical page of logical page 2
                CALL    MBB_GET_PAGE
                LD      (orig), A

                LD      A, 2                ; SET page 2 -> 0x37
                LD      E, 0x37
                CALL    MBB_SET_PAGE
                LD      C, 2
                CALL    MBB_GET_PAGE        ; GET -> expect 0x37
                LD      (r_set37), A

                LD      A, 2                ; SET page 2 -> 0x3A
                LD      E, 0x3A
                CALL    MBB_SET_PAGE
                LD      C, 2
                CALL    MBB_GET_PAGE        ; GET -> expect 0x3A
                LD      (r_set3A), A

                LD      A, 0x30             ; DIRECT OUT (bypasses BIOS shadow)
                OUT     (0x72), A
                LD      C, 2
                CALL    MBB_GET_PAGE        ; GET -> expect STALE 0x3A (not 0x30)
                LD      (r_desync), A

                LD      A, (orig)           ; restore page 2 via MBB (re-syncs both)
                LD      E, A
                LD      A, 2
                CALL    MBB_SET_PAGE

                LD      DE, hdr
                CALL    puts
                LD      DE, l_orig
                CALL    puts
                LD      A,(orig)
                CALL    hexln
                LD      DE, l_set37
                CALL    puts
                LD      A,(r_set37)
                CALL    hexln
                LD      DE, l_set3A
                CALL    puts
                LD      A,(r_set3A)
                CALL    hexln
                LD      DE, l_desync
                CALL    puts
                LD      A,(r_desync)
                CALL    hexln
                LD      DE, verdict
                CALL    puts
                JP      0x0000

puts:           LD      C, 9
                JP      BDOS
hexln:          PUSH    AF              ; byte safe on stack (BDOS fn 2 clobbers B/HL)
                RRCA
                RRCA
                RRCA
                RRCA
                CALL    hexnib          ; high nibble
                POP     AF              ; restore byte
                CALL    hexnib          ; low nibble
                LD      DE, crlf
                JP      puts
hexnib:         AND     0x0F
                ADD     A, '0'
                CP      '9' + 1
                JR      C, .e
                ADD     A, 'A' - '0' - 10
.e:             LD      E, A
                LD      C, 2
                JP      BDOS

hdr:        DB "MBB_GET/SET_PAGE probe (logical page 2)",0x0D,0x0A,'$'
l_orig:     DB "  original page2          : ",'$'
l_set37:    DB "  after SET 37, GET        : ",'$'
l_set3A:    DB "  after SET 3A, GET        : ",'$'
l_desync:   DB "  after direct OUT 30, GET : ",'$'
verdict:    DB 0x0D,0x0A
            DB "Expect 37 then 3A (MBB round-trips). The last line should be",0x0D,0x0A
            DB "3A, NOT 30: a direct OUT bypasses the BIOS shadow, so MBB_GET",0x0D,0x0A
            DB "reads stale -- the desync that justifies dropping direct port",0x0D,0x0A
            DB "I/O in favour of MBB_SET_PAGE/MBB_GET_PAGE.",0x0D,0x0A,'$'
crlf:       DB 0x0D,0x0A,'$'

orig:       DB 0
r_set37:    DB 0
r_set3A:    DB 0
r_desync:   DB 0
            DS 64
stack_top:
            END
