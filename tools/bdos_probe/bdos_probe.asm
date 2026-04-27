;------------------------------------------------------------------------------
; bdos_probe.asm — MicroBeast BDOS register-preservation reproducer
;
; Standalone CP/M 2.2 .COM that probes BDOS functions 1, 2, 6, 9, 10, 11
; with sentinel values in every general-purpose register and shadow-register
; pair. After each call, every main and shadow register is snapshotted to a
; fixed memory area before any subsequent code runs. Each probe emits one raw
; result line for visual diff against the leading "Sentinels:" line.
;
; Independent of antforth — does not link against, reference, or share any
; source with src/*.asm. Builds via Makefile target "firmware-repro" →
; build/bdos_probe.com.
;
; Story:  11.5.1.2 (firmware-bdos-register-preservation-reproducer)
; Date:   2026-04-27
; Author: AntForth project (project-lead-attributed: Ant)
;
; Sentinels (canonical, also printed verbatim at startup):
;   Main:   BC=1234 DE=5678 HL=9ABC IX=CAFE IY=BABE A=AA F=00
;   Shadow: BC'=DEAD DE'=C0DE HL'=F00D A'=55 F'=FF
;
; Build:
;   sjasmplus --raw=../../build/bdos_probe.com bdos_probe.asm   (from this dir)
;   or via:  make firmware-repro                                (from repo root)
;------------------------------------------------------------------------------

BDOS_ENTRY      EQU     0x0005

SENT_BC         EQU     0x1234
SENT_DE         EQU     0x5678
SENT_HL         EQU     0x9ABC
SENT_IX         EQU     0xCAFE
SENT_IY         EQU     0xBABE
SENT_A          EQU     0xAA
SENT_F          EQU     0x00
SENT_BC2        EQU     0xDEAD
SENT_DE2        EQU     0xC0DE
SENT_HL2        EQU     0xF00D
SENT_A2         EQU     0x55
SENT_F2         EQU     0xFF

                ORG     0x0100

main:
                LD      DE, sentinels_str
                LD      C, 9
                CALL    BDOS_ENTRY

                LD      DE, de_note_str
                LD      C, 9
                CALL    BDOS_ENTRY

                ; Probe order: non-blocking first (2, 11, 6, 9), blocking last
                ; (1, 10). Minimises operator interaction inside the
                ; "interesting" probe zone.
                CALL    probe_fn02
                CALL    probe_fn11
                CALL    probe_fn06
                CALL    probe_fn09
                CALL    probe_fn01
                CALL    probe_fn10

                LD      DE, done_str
                LD      C, 9
                CALL    BDOS_ENTRY

                LD      C, 0            ; P_TERMCPM
                CALL    BDOS_ENTRY
                JP      0x0000          ; safety: warm-boot if BDOS-0 returns

;------------------------------------------------------------------------------
; load_sentinels — prime every register with its sentinel value.
;
; Order: shadow set (BC', DE', HL') via EXX, shadow AF' via EX-AF push-pop,
; then main IX/IY/BC/DE/AF/HL. On RET every register holds its sentinel.
;
; Caller is expected to set C = function number and (optionally) E or DE for
; parameter overlay before invoking BDOS. The C overlay overrides the low
; byte of BC's sentinel; this is unavoidable per the BDOS calling contract
; (function-number must live in C). The verdict-matrix interpretation
; accounts for it (BC's "preserved" reading is "B = 0x12 AND C = fn-number").
;------------------------------------------------------------------------------
load_sentinels:
                EXX                     ; switch to shadow set
                LD      BC, SENT_BC2
                LD      DE, SENT_DE2
                LD      HL, SENT_HL2
                EXX                     ; back to main set

                ; Load AF' via EX-AF + push-pop trick.
                LD      HL, 0x55FF      ; H = SENT_A2 = 0x55, L = SENT_F2 = 0xFF
                PUSH    HL
                EX      AF, AF'
                POP     AF              ; main AF now := 0x55FF (was AF')
                EX      AF, AF'         ; shadow AF' now := 0x55FF; main AF restored

                ; Load main set.
                LD      IX, SENT_IX
                LD      IY, SENT_IY
                LD      BC, SENT_BC
                LD      DE, SENT_DE

                ; Load main AF via push-pop trick.
                LD      HL, 0xAA00      ; H = SENT_A = 0xAA, L = SENT_F = 0x00
                PUSH    HL
                POP     AF              ; main AF := 0xAA00

                LD      HL, SENT_HL     ; final reload of HL (was scratch)
                RET

;------------------------------------------------------------------------------
; snapshot_regs — capture all main and shadow registers to snap_area.
;
; CRITICAL ordering (AC #11(a)): no instruction between BDOS-RET and snapshot
; commit may modify the registers being measured. The order below uses only:
;   - PUSH AF / PUSH (other) — does not modify register contents
;   - LD (nn), rr           — does not modify rr
;   - EX AF, AF'            — swaps AF with AF' (controlled use)
;   - EXX                   — swaps main BC/DE/HL with shadow (controlled use)
;   - POP HL                — modifies HL but only AFTER snap_hl is committed
;
; No ALU / arithmetic / "LD A, ..." / flag-affecting op runs between entry
; and the final commit; main AF is preserved across the whole routine via
; the (1) PUSH AF / POP HL pair; AF' is preserved via the (2) PUSH AF /
; POP HL pair sandwiched between the two EX-AF swaps.
;------------------------------------------------------------------------------
snapshot_regs:
                PUSH    AF              ; (1) save main AF on stack
                LD      (snap_bc), BC
                LD      (snap_de), DE
                LD      (snap_hl), HL
                LD      (snap_ix), IX
                LD      (snap_iy), IY

                EX      AF, AF'         ; main AF := AF'; AF' := old main AF
                PUSH    AF              ; (2) save AF' (currently in main) on stack

                EXX                     ; switch to shadow set
                LD      (snap_bc2), BC
                LD      (snap_de2), DE
                LD      (snap_hl2), HL
                EXX                     ; restore main set

                POP     HL              ; pop (2): HL = AF'
                LD      (snap_af2), HL

                EX      AF, AF'         ; restore: main AF := original; AF' := original

                POP     HL              ; pop (1): HL = main AF
                LD      (snap_af), HL
                RET

;------------------------------------------------------------------------------
; print_snapshot — emit the result line per AC #4:
;   "Fn NN: BC=hhhh DE=hhhh HL=hhhh IX=hhhh IY=hhhh A=hh F=hh \
;    BC'=hhhh DE'=hhhh HL'=hhhh A'=hh F'=hh"
;
; Probes with visible console side-effects (X, Fn9, echoed input) call
; flush_crlf themselves AFTER snapshot to terminate the side-effect line
; before the result line is emitted. Result line ends with CRLF.
;
; May freely clobber any register since the snapshot is already
; memory-resident before this routine is entered.
;------------------------------------------------------------------------------
print_snapshot:
                LD      DE, fn_prefix
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      A, (current_fn)
                CALL    print_dec_byte

                LD      DE, lbl_BC
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      HL, (snap_bc)
                CALL    print_hex_word

                LD      DE, lbl_DE
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      HL, (snap_de)
                CALL    print_hex_word

                LD      DE, lbl_HL
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      HL, (snap_hl)
                CALL    print_hex_word

                LD      DE, lbl_IX
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      HL, (snap_ix)
                CALL    print_hex_word

                LD      DE, lbl_IY
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      HL, (snap_iy)
                CALL    print_hex_word

                LD      DE, lbl_A
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      A, (snap_af + 1) ; A = high byte of AF word
                CALL    print_hex_byte

                LD      DE, lbl_F
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      A, (snap_af)     ; F = low byte of AF word
                CALL    print_hex_byte

                LD      DE, lbl_BC2
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      HL, (snap_bc2)
                CALL    print_hex_word

                LD      DE, lbl_DE2
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      HL, (snap_de2)
                CALL    print_hex_word

                LD      DE, lbl_HL2
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      HL, (snap_hl2)
                CALL    print_hex_word

                LD      DE, lbl_A2
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      A, (snap_af2 + 1)
                CALL    print_hex_byte

                LD      DE, lbl_F2
                LD      C, 9
                CALL    BDOS_ENTRY
                LD      A, (snap_af2)
                CALL    print_hex_byte

                LD      DE, crlf_str    ; trailing CRLF terminates the line
                LD      C, 9
                JP      BDOS_ENTRY      ; tail-call

;------------------------------------------------------------------------------
; print_hex_word — emit HL as four upper-case hex digits.
; print_hex_byte — emit A   as two  upper-case hex digits.
; print_hex_nibble — emit low 4 bits of A as one upper-case hex digit.
; All clobber A, BC, DE freely (called only from print_snapshot, post-snap).
;
; print_hex_word saves HL across the inner BDOS call, since BDOS function 2
; (C_WRITE) is contractually permitted to destroy HL — without the save, the
; second nibble print would read garbage in L. (This was the bug that the
; first iz-cpm self-test pass surfaced; see Completion Notes.)
;------------------------------------------------------------------------------
print_hex_word:
                LD      A, H
                PUSH    HL
                CALL    print_hex_byte
                POP     HL
                LD      A, L
                ; fall through to print_hex_byte

print_hex_byte:
                PUSH    AF
                RRCA
                RRCA
                RRCA
                RRCA
                CALL    print_hex_nibble
                POP     AF
                ; fall through to print_hex_nibble (low nibble)

print_hex_nibble:
                AND     0x0F
                ADD     A, '0'
                CP      '9' + 1
                JR      C, .emit
                ADD     A, 'A' - '0' - 10
.emit:
                LD      E, A
                LD      C, 2            ; C_WRITE
                JP      BDOS_ENTRY      ; tail-call

;------------------------------------------------------------------------------
; print_dec_byte — emit A as two decimal digits via BDOS fn 2 (AC #4).
; Caller's contract: A < 100 (the function-number byte is in 0..11 here).
; Clobbers A, BC, DE, HL.
;------------------------------------------------------------------------------
print_dec_byte:
                LD      H, '0'          ; tens digit, ASCII; counts up
.div10:
                CP      10
                JR      C, .emit
                SUB     10
                INC     H
                JR      .div10
.emit:
                ADD     A, '0'          ; units digit ASCII
                LD      L, A
                LD      E, H            ; emit tens
                LD      C, 2
                PUSH    HL
                CALL    BDOS_ENTRY
                POP     HL
                LD      E, L            ; emit units
                LD      C, 2
                JP      BDOS_ENTRY

;------------------------------------------------------------------------------
; Per-function probe drivers (AC #2, #5)
;------------------------------------------------------------------------------

; Function 2 (C_WRITE) — non-blocking; E = char to emit. Side effect: 'X'.
probe_fn02:
                CALL    load_sentinels
                LD      C, 2
                LD      E, 'X'
                CALL    BDOS_ENTRY
                CALL    snapshot_regs
                CALL    flush_crlf      ; flush 'X' onto its own line
                LD      A, 2
                LD      (current_fn), A
                JP      print_snapshot

; Function 11 (C_STATUS) — non-blocking; no parameters. No console side effect.
probe_fn11:
                CALL    load_sentinels
                LD      C, 11
                CALL    BDOS_ENTRY
                CALL    snapshot_regs
                LD      A, 11
                LD      (current_fn), A
                JP      print_snapshot

; Function 6 (C_RAWIO) — E=0xFF non-blocking input poll. Returns A=0 or char.
; Single-mode probe (input poll). Output mode (E≠0xFF) not measured here.
probe_fn06:
                CALL    load_sentinels
                LD      C, 6
                LD      E, 0xFF
                CALL    BDOS_ENTRY
                CALL    snapshot_regs
                LD      A, 6
                LD      (current_fn), A
                JP      print_snapshot

; Function 9 (C_WRITESTR) — DE = '$'-terminated string. Side effect: "Fn9".
; The DE sentinel is overwritten by fn9_str pre-call; the post-call DE is
; reported relative to fn9_str's address (see de_note_str at startup).
probe_fn09:
                CALL    load_sentinels
                LD      DE, fn9_str
                LD      C, 9
                CALL    BDOS_ENTRY
                CALL    snapshot_regs
                CALL    flush_crlf      ; flush "Fn9" onto its own line
                LD      A, 9
                LD      (current_fn), A
                JP      print_snapshot

; Function 1 (C_READ) — blocks until char ready. Operator prompt printed
; first via fn 9 (clobber state of the prompt's BDOS call is not measured —
; load_sentinels re-primes after the prompt). Function 1 contractually
; returns the read char in A → A-clobber expected for fn 1 specifically.
probe_fn01:
                LD      DE, fn01_prompt
                LD      C, 9
                CALL    BDOS_ENTRY
                CALL    load_sentinels
                LD      C, 1
                CALL    BDOS_ENTRY
                CALL    snapshot_regs
                CALL    flush_crlf      ; flush echoed input char onto its own line
                LD      A, 1
                LD      (current_fn), A
                JP      print_snapshot

; Function 10 (C_READSTR) — blocks until line entered. DE = buffer ptr;
; sentinel-DE replaced. Operator prompt via fn 9 first; then re-prime then
; call. Buffer fn10_buf has byte0=64 (max), byte1 set by BDOS (actual count),
; bytes2..65 hold the chars.
probe_fn10:
                LD      DE, fn10_prompt
                LD      C, 9
                CALL    BDOS_ENTRY
                CALL    load_sentinels
                LD      DE, fn10_buf
                LD      C, 10
                CALL    BDOS_ENTRY
                CALL    snapshot_regs
                CALL    flush_crlf      ; flush echoed line onto its own line
                LD      A, 10
                LD      (current_fn), A
                JP      print_snapshot

; flush_crlf — emit CRLF via fn 9. Used after probes that emit visible
; console side-effects (X, Fn9, echoed input) to terminate that side-effect
; output before the result line is printed. May freely clobber registers
; since it is only ever called AFTER snapshot_regs has committed all values.
flush_crlf:
                LD      DE, crlf_str
                LD      C, 9
                JP      BDOS_ENTRY

;------------------------------------------------------------------------------
; String constants ($-terminated for BDOS function 9)
;------------------------------------------------------------------------------
sentinels_str:
                DB      "Sentinels: BC=1234 DE=5678 HL=9ABC IX=CAFE IY=BABE "
                DB      "A=AA F=00 BC'=DEAD DE'=C0DE HL'=F00D A'=55 F'=FF"
                DB      0x0D, 0x0A, '$'

de_note_str:
                DB      "Note: Fn 09 / Fn 10 overwrite DE pre-call (string ptr / "
                DB      "buffer ptr); compare DE col against pointer, not sentinel."
                DB      0x0D, 0x0A, '$'

done_str:       DB      "Done", 0x0D, 0x0A, '$'

fn_prefix:      DB      "Fn ", '$'
lbl_BC:         DB      ": BC=", '$'
lbl_DE:         DB      " DE=", '$'
lbl_HL:         DB      " HL=", '$'
lbl_IX:         DB      " IX=", '$'
lbl_IY:         DB      " IY=", '$'
lbl_A:          DB      " A=",  '$'
lbl_F:          DB      " F=",  '$'
lbl_BC2:        DB      " BC'=", '$'
lbl_DE2:        DB      " DE'=", '$'
lbl_HL2:        DB      " HL'=", '$'
lbl_A2:         DB      " A'=", '$'
lbl_F2:         DB      " F'=", '$'

crlf_str:       DB      0x0D, 0x0A, '$'

fn9_str:        DB      "Fn9", '$'

fn01_prompt:    DB      "Press any key for fn 01: ", '$'
fn10_prompt:    DB      "Type a line + Enter for fn 10: ", '$'

fn10_buf:       DB      64                ; max chars
                DB      0                 ; actual chars (filled by BDOS)
                DS      64                ; buffer

;------------------------------------------------------------------------------
; Snapshot data area — 5 main words + 1 main AF word + 3 shadow words +
; 1 shadow AF word + 1 fn-number byte = 21 bytes total.
;------------------------------------------------------------------------------
current_fn:     DB      0
snap_bc:        DW      0
snap_de:        DW      0
snap_hl:        DW      0
snap_ix:        DW      0
snap_iy:        DW      0
snap_af:        DW      0
snap_bc2:       DW      0
snap_de2:       DW      0
snap_hl2:       DW      0
snap_af2:       DW      0

                END
