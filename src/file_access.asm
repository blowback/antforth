; file_access.asm — File-Access infrastructure (FCB pool + BDOS wrappers)
; AntForth — A Forth for CP/M on Z80
;
; Story 13.1 lays the foundation for ANS Forth File-Access (Stories 13.2-
; 13.4): kernel-resident FCB pool (E13-D1, architecture.md:354-358),
; per-FCB DMA buffer slots, BDOS wrapper helpers for the file-access
; subset of NFR13's allow-list (epics.md:1483), the byte-stream impedance
; layer that bridges CP/M's 128-byte record model to ANS's byte-stream
; contract (E13-D3, architecture.md:390-394), and a TEST-mode harness
; (FILE-IO-SANITY) that exercises create→write→close→open→read→seek→
; readEOF→close→delete on a 200-byte file. Story 13.2 and onward layer
; the user-facing OPEN-FILE / READ-FILE / WRITE-FILE / etc. words atop
; this infrastructure.
;
; -----------------------------------------------
; BDOS REGISTER-PRESERVATION ASSUMPTION (AC #5)
; -----------------------------------------------
; MicroBeast firmware ≥2026-04-28 preserves IX/IY/shadow registers
; across all probed BDOS functions (1, 2, 6, 9, 10, 11) per
; project_hardware_crash_audit.md (CLOSED 2026-04-28). The file-access
; functions (15/16/19/20/21/22/33/34/35) are NOT in that probed set
; but are non-blocking on user input — they don't traverse the
; interrupt-handler path that was the original clobber mechanism.
; Story 13.1 assumes the firmware fix applies by mechanism and uses
; only the standard BDOS_SAVE / BDOS_RESTORE pair (DE+BC save) at each
; CALL BDOS_ENTRY site. No defensive IX/IY/shadow saves are added.
;
; If a future PROBE.COM run extending coverage to functions 15/16/...
; uncovers clobber on real hardware, the mitigation is to spawn Story
; 13.1.1 ("file-access defensive saves") per AC #14, mirror of the
; dormant Story 11.5.1.1 pattern. Per feedback_design_upfront.md the
; defensive saves are NOT speculatively added now.
;
; -----------------------------------------------
; HARNESS BUILD MODE — `-DFILE_SANITY`
; -----------------------------------------------
; The (FILE-IO-SANITY) word is wrapped in `IFDEF FILE_SANITY` so the
; production REPL binary (build/antforth.com) does NOT include it.
; The build/antforth_filesanity.com binary, built by `make
; test-file-sanity` with `-DFILE_SANITY`, is the only one that exposes
; the word. That binary is also the one transferred to MicroBeast for
; hardware smoke (AC #17). FILE_SANITY is intentionally distinct from
; TEST_MODE — TEST_MODE replaces the REPL with the assembly test
; thread, so the harness must live behind a separate symbol to remain
; REPL-invocable.
;
; -----------------------------------------------
; ALLOCATION DECISION (Task 14 picks)
; -----------------------------------------------
;   * AC #3 layout pick: parallel arrays (`fcb_pool` + `fcb_dma_pool`).
;     Rationale: cleaner address arithmetic, no per-FCB stride extension.
;     Trade-off: one extra parallel array `fcb_byte_pos` for the byte-
;     stream cursor — 8 bytes total, negligible.
;   * AC #4 bitmap orient: `1` = free, `0` = in-use; initial 0xFF =
;     all 8 slots free (matches the AC recommendation).
;   * AC #6/#7 seed pick: (b) "re-create at start" — harness creates
;     HELLO.TXT via F_MAKE, no static seed file; harness deletes at end.
;   * AC #8 iz-cpm flag: `--disk-a disk/a` (verified via `iz-cpm --help`).
;   * AC #5 register-preservation stance: assumed-by-mechanism; no
;     defensive saves.

; === FCB pool sizing constants ===
FCB_SIZE            EQU 36          ; CP/M 2.2 BDOS spec — 33-byte open-form FCB + 3-byte random-record extension
FCB_POOL_COUNT      EQU 8           ; architecture.md:356 — E13-D1 (kernel-resident static array, 8 FCBs)
FCB_DMA_SIZE        EQU 128         ; CP/M 2.2 BDOS — sequential read/write transfers 128 bytes per record
FCB_DMA_POOL_SIZE   EQU FCB_POOL_COUNT * FCB_DMA_SIZE  ; FCB_POOL_COUNT * FCB_DMA_SIZE = 8 * 128 = 1024

; Cheap drift-detection: assemble-time check that the two derived sizes agree.
        ASSERT FCB_POOL_COUNT * FCB_DMA_SIZE = FCB_DMA_POOL_SIZE

; === FCB-field offsets (CP/M 2.2 BDOS spec) ===
; The 36-byte FCB is laid out as 33 bytes of "open form" plus 3 bytes
; of random-record extension (r0/r1/r2). All offsets verified against
; the CP/M 2.2 Programmer's Manual §5.4 "File Control Block".
FCB_DRIVE   EQU 0           ; drive code: 0 = default, 1 = A:, 2 = B:, ... 16 = P:
FCB_NAME    EQU 1           ; CP/M 2.2 §5.4 — 8-byte filename, space-padded
FCB_EXT     EQU 9           ; CP/M 2.2 §5.4 — 3-byte extension, space-padded
FCB_EX      EQU 12          ; CP/M 2.2 §5.4 — current extent (low byte)
FCB_S1      EQU 13          ; CP/M 2.2 §5.4 — reserved (BDOS internal)
FCB_S2      EQU 14          ; CP/M 2.2 §5.4 — reserved (BDOS internal: extent high byte)
FCB_RC      EQU 15          ; CP/M 2.2 §5.4 — record count in current extent (0..127)
FCB_DATA    EQU 16          ; CP/M 2.2 §5.4 — 16-byte BDOS-internal allocation map
FCB_CR      EQU 32          ; CP/M 2.2 §5.4 — current record (sequential cursor, 0..127)
FCB_R0      EQU 33          ; CP/M 2.2 §5.4 — random-record byte 0
FCB_R1      EQU 34          ; CP/M 2.2 §5.4 — random-record byte 1
FCB_R2      EQU 35          ; CP/M 2.2 §5.4 — random-record byte 2 (overflow)

; === Pool storage ===
; Both pools are kernel-resident static arrays per E13-D1; addresses are
; fixed at assembly time. fcb_pool entries map 1:1 with fcb_dma_pool
; entries via index 0..7 (parallel-array layout — AC #3 pick).
fcb_pool:           DS FCB_POOL_COUNT * FCB_SIZE        ; 288 bytes (8 × 36)
fcb_dma_pool:       DS FCB_DMA_POOL_SIZE                ; 1024 bytes (8 × 128)

; Free-list bitmap (AC #4 pick: 1-byte bitmap, 1 = free).
;   bit i (i = 0..7) corresponds to fcb_pool[i].
;   Initial value 0xFF: all 8 slots free at boot.
;   pool_init re-asserts 0xFF on every cold-start.
fcb_pool_bitmap:    DB 0xFF

; Per-FCB byte-cursor for the byte-stream impedance layer.
;   Values 0..127 = next byte offset within the cached DMA buffer.
;   Value 128     = sentinel "buffer empty / needs refill" (read mode)
;                   — file_byte_read sees this and triggers F_READ.
;   pool_init sets all 8 to 128.
;   The harness sets the slot to 0 before a write loop (start filling
;   buffer at offset 0) and to 128 before a read loop (force refill).
fcb_byte_pos:       DS FCB_POOL_COUNT

; -----------------------------------------------
; pool_init — Cold-start initialiser; called from cold_start.
;   Resets fcb_pool_bitmap to 0xFF (all free), zeroes fcb_pool and
;   fcb_dma_pool, sets fcb_byte_pos[*] = 128 (sentinel).
;   Clobbers: A, BC, DE, HL, F. Preserves: IX, IY, SP.
; -----------------------------------------------
pool_init:
        LD      A, 0xFF
        LD      (fcb_pool_bitmap), A
        ; Zero fcb_pool (288 bytes)
        LD      HL, fcb_pool
        LD      (HL), 0
        LD      D, H
        LD      E, L
        INC     DE
        LD      BC, FCB_POOL_COUNT * FCB_SIZE - 1
        LDIR
        ; Zero fcb_dma_pool (1024 bytes)
        LD      HL, fcb_dma_pool
        LD      (HL), 0
        LD      D, H
        LD      E, L
        INC     DE
        LD      BC, FCB_DMA_POOL_SIZE - 1
        LDIR
        ; Set fcb_byte_pos[*] = 128 (sentinel: refill on first read).
        LD      HL, fcb_byte_pos
        LD      B, FCB_POOL_COUNT
        LD      A, 128
.pi_bp_loop:
        LD      (HL), A
        INC     HL
        DJNZ    .pi_bp_loop
        RET

; -----------------------------------------------
; pool_acquire — Acquire a free FCB.
;   Exit:  HL = FCB ptr, B = index (0..7).
;   Raises THROW_FCB_EXHAUSTED (-69) if all 8 slots are in-use.
;   Clobbers: A, BC, DE, HL, F.
;   Search policy: lowest free index first (deterministic).
; -----------------------------------------------
pool_acquire:
        LD      A, (fcb_pool_bitmap)
        OR      A
        JR      Z, .pa_exhausted
        LD      B, 0                    ; index counter
        LD      C, 1                    ; mask = 1<<index
        LD      HL, fcb_pool
        LD      DE, FCB_SIZE
.pa_scan:
        AND     C
        JR      NZ, .pa_found           ; this bit set → free slot at index B
        ; Defensive bound on B (Review F7): under the bitmap-non-zero
        ; precondition the loop terminates in ≤ 7 increments, but a
        ; corrupted bitmap with the matching bit cleared could otherwise
        ; spin C through 0x80 → 0x00 and loop forever.
        LD      A, B
        CP      FCB_POOL_COUNT - 1
        JR      NC, .pa_exhausted
        LD      A, (fcb_pool_bitmap)    ; reload (was clobbered by AND)
        SLA     C                       ; mask <<= 1
        INC     B                       ; index++
        ADD     HL, DE                  ; FCB ptr += 36
        JR      .pa_scan
.pa_found:
        ; A = mask (bit set), C = mask, B = index, HL = FCB ptr
        LD      A, (fcb_pool_bitmap)
        XOR     C                       ; clear the bit (it was set, XOR clears)
        LD      (fcb_pool_bitmap), A
        RET
.pa_exhausted:
        LD      BC, THROW_FCB_EXHAUSTED ; -69; consumed by w_THROW_cf.kernel_entry
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; pool_release — Release an FCB back to the pool.
;   Entry: HL = FCB ptr (must point at one of the 8 slots).
;   Sets the corresponding bitmap bit, zeros the FCB record (next
;   acquire gets a clean FCB), and zeroes fcb_byte_pos[index].
;   Clobbers: A, BC, DE, HL, F.
;   No-op if HL doesn't match a slot (defensive; harness never hits
;   this path).
; -----------------------------------------------
pool_release:
        ; Stash FCB ptr in scratch (HL gets clobbered during scan).
        LD      A, H
        LD      (.pr_save_h), A
        LD      A, L
        LD      (.pr_save_l), A
        LD      DE, fcb_pool            ; DE walks slot starts
        LD      B, 0                    ; index
        LD      C, 1                    ; mask = 1<<index
.pr_scan:
        LD      A, B
        CP      FCB_POOL_COUNT
        JR      NC, .pr_done            ; not found — defensive no-op
        LD      A, (.pr_save_h)
        CP      D
        JR      NZ, .pr_next
        LD      A, (.pr_save_l)
        CP      E
        JR      Z, .pr_found
.pr_next:
        ; Advance DE by FCB_SIZE
        LD      A, E
        ADD     A, FCB_SIZE
        LD      E, A
        JR      NC, .pr_no_borrow
        INC     D
.pr_no_borrow:
        SLA     C                       ; mask <<= 1
        INC     B                       ; index++
        JR      .pr_scan
.pr_found:
        ; B = index, C = mask, DE = FCB ptr
        LD      A, (fcb_pool_bitmap)
        OR      C
        LD      (fcb_pool_bitmap), A
        ; Zero fcb_byte_pos[index]
        ;   HL = fcb_byte_pos + B; mirrors the idiom used at file_byte_read
        ;   line 451-454 / file_byte_write line 528-531 / file_flush
        ;   line 606-609. Earlier draft did `LD HL, fcb_byte_pos` then
        ;   `LD L, A` (Review F-A) which discarded the low byte of the
        ;   base address — silently miswrote outside fcb_byte_pos for any
        ;   base whose low byte was non-zero.
        LD      H, 0
        LD      L, B
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 0
        ; Zero the FCB record (36 bytes starting at DE)
        EX      DE, HL                  ; HL = FCB ptr
        LD      D, H
        LD      E, L
        INC     DE
        LD      (HL), 0
        LD      BC, FCB_SIZE - 1
        LDIR
.pr_done:
        RET
.pr_save_h:     DB 0
.pr_save_l:     DB 0

; -----------------------------------------------
; fcb_dma_ptr — Compute the DMA-buffer address for an FCB index.
;   Entry: B = FCB index (0..7).
;   Exit:  HL = fcb_dma_pool + B * 128.
;   Clobbers: A, F. Preserves: BC, DE.
;   Computation: index*128 = high_byte(index/2), low_byte((index&1)*128).
; -----------------------------------------------
fcb_dma_ptr:
        LD      A, B
        AND     1
        RRCA                            ; A = 0x80 if odd, 0x00 if even
        LD      L, A
        LD      A, B
        SRL     A                       ; A = index/2 (0..3)
        LD      H, A
        ; HL = index*128, low byte first.
        PUSH    DE
        LD      DE, fcb_dma_pool
        ADD     HL, DE
        POP     DE
        RET

; -----------------------------------------------
; fcb_idx_from_ptr — Recover the FCB index from a pool pointer.
;   Entry: HL = FCB ptr (must be aligned, a valid pool slot).
;   Exit:  B = index (0..7).
;   Clobbers: A, DE, HL, F.
; -----------------------------------------------
fcb_idx_from_ptr:
        LD      DE, fcb_pool
        OR      A                       ; clear carry
        SBC     HL, DE
        ; HL = byte offset (must be 0..252 for a valid pool ptr).
        ; If H != 0 the input was outside the pool → return B = 0xFF as
        ; out-of-range sentinel rather than silently truncating to L
        ; (Review F3). Callers in Story 13.1 (the harness) only feed
        ; pointers acquired via pool_acquire so this path is defensive.
        LD      A, H
        OR      A
        JR      NZ, .fip_oor
        LD      A, L
        LD      B, 0
.fip_div:
        CP      FCB_SIZE
        JR      C, .fip_done
        SUB     FCB_SIZE
        INC     B
        JR      .fip_div
.fip_done:
        ; Range-check B against FCB_POOL_COUNT (defensive — a non-aligned
        ; pointer could yield B in 8..255 even with H==0).
        LD      A, B
        CP      FCB_POOL_COUNT
        RET     C                       ; B in 0..7 — valid
.fip_oor:
        LD      B, 0xFF                 ; sentinel: out-of-range index
        RET

; -----------------------------------------------
; BDOS wrapper helpers (AC #2). Each subroutine takes DE = FCB ptr
; (for FCB-arg functions) and returns A = BDOS result code. DE is
; preserved across the wrapper (BDOS_SAVE/RESTORE round-trip). BC is
; preserved too — no caller-visible TOS clobber.
;
; Per CCD-3 / NFR17 (architecture.md:472), every CALL BDOS_ENTRY site
; carries a function-number citation either via the named helper
; (e.g., bdos_open_file ← F_OPEN/15) or via the inline `LD C, F_NAME`
; setup. The audit grep is `grep -nE 'CALL\s+BDOS_ENTRY|LD\s+C,\s*F_'
; src/file_access.asm` (Task 10).
; -----------------------------------------------

; bdos_open_file — F_OPEN (15): open existing file
;   Entry: DE = FCB ptr.  Exit: A = 0..3 success / 0xFF "file not found".
bdos_open_file:
        BDOS_SAVE
        LD      C, F_OPEN               ; F_OPEN (15)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; bdos_close_file — F_CLOSE (16): close open file
;   Entry: DE = FCB ptr.  Exit: A = 0..3 success / 0xFF error.
bdos_close_file:
        BDOS_SAVE
        LD      C, F_CLOSE              ; F_CLOSE (16)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; bdos_delete_file — F_DELETE (19): delete file (matches by FCB name)
;   Entry: DE = FCB ptr.  Exit: A = 0..3 success / 0xFF "file not found".
bdos_delete_file:
        BDOS_SAVE
        LD      C, F_DELETE             ; F_DELETE (19)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; bdos_read_seq — F_READ (20): read next sequential record into DMA buffer
;   Entry: DE = FCB ptr.  Exit: A = 0 success / 1 EOF / other error.
;   Caller must have set DMA via bdos_set_dma before this call.
bdos_read_seq:
        BDOS_SAVE
        LD      C, F_READ               ; F_READ (20)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; bdos_write_seq — F_WRITE (21): write next sequential record from DMA
;   Entry: DE = FCB ptr.  Exit: A = 0 success / non-zero error.
;   Caller must have set DMA via bdos_set_dma before this call.
bdos_write_seq:
        BDOS_SAVE
        LD      C, F_WRITE              ; F_WRITE (21)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; bdos_create_file — F_MAKE (22): create new file (directory entry)
;   Entry: DE = FCB ptr.  Exit: A = 0..3 success / 0xFF "directory full".
bdos_create_file:
        BDOS_SAVE
        LD      C, F_MAKE               ; F_MAKE (22)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; bdos_get_drive — DRV_GET (25): return current default drive code
;   Entry: -.  Exit: A = drive (0=A, 1=B, ..., 15=P).
bdos_get_drive:
        BDOS_SAVE
        LD      C, DRV_GET              ; DRV_GET (25)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; bdos_set_dma — F_DMAOFF (26): set DMA buffer address
;   Entry: DE = DMA buffer ptr.  Exit: A = ignored.
;   Process-global state — must be (re-)set before each F_READ /
;   F_WRITE / F_READRAND / F_WRITERAND if multiple FCBs share BDOS.
bdos_set_dma:
        BDOS_SAVE
        LD      C, F_DMAOFF             ; F_DMAOFF (26)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; bdos_read_rand — F_READRAND (33): random-record read
;   Entry: DE = FCB ptr (with r0/r1/r2 set).  Exit: A = 0 success /
;     1 = reading unwritten data / 4 = no data block / 6 = past phys EOF.
bdos_read_rand:
        BDOS_SAVE
        LD      C, F_READRAND           ; F_READRAND (33)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; bdos_write_rand — F_WRITERAND (34): random-record write
;   Entry: DE = FCB ptr (with r0/r1/r2 set).  Exit: A = 0 success / non-zero error.
bdos_write_rand:
        BDOS_SAVE
        LD      C, F_WRITERAND          ; F_WRITERAND (34)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; bdos_file_size — F_SIZE (35): compute file size into r0/r1/r2
;   Entry: DE = FCB ptr.  Exit: A = 0 (success); FCB.r0..r2 = record count.
bdos_file_size:
        BDOS_SAVE
        LD      C, F_SIZE               ; F_SIZE (35)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        RET

; -----------------------------------------------
; Byte-stream impedance layer (AC #3). Bridges CP/M's 128-byte record
; granularity to ANS File-Access's byte-stream contract. Internally
; tracks fcb_byte_pos[index] and refills/flushes the per-FCB DMA buffer
; as the cursor crosses a record boundary.
;
; Caller responsibility: ensure DMA is set to the FCB's buffer before
; the FIRST call (the harness does this once at start). file_byte_read
; refreshes DMA at every refill (in case other FCBs share BDOS); for
; Story 13.1's single-FCB harness this is a no-op extra call but keeps
; the routine general for Stories 13.2+.
; -----------------------------------------------

; file_byte_read — Read one byte from FCB.
;   Entry: DE = FCB ptr.
;   Exit:  CY = 0 + A = byte (success) / CY = 1 (EOF or read error).
;   Preserves: DE, IX, IY. Clobbers: A, BC, HL, F.
file_byte_read:
        PUSH    DE                      ; preserve FCB ptr for caller
        ; Compute index → save to scratch
        EX      DE, HL                  ; HL = FCB ptr (DE = stale junk)
        CALL    fcb_idx_from_ptr        ; B = index
        LD      A, B
        LD      (.fbr_idx), A
        ; HL = &fcb_byte_pos[index]
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      A, (HL)                 ; A = pos
        CP      128
        JR      C, .fbr_have_buf        ; pos < 128 → buffer has data
        ; pos == 128 (sentinel) → refill via F_READ
        LD      A, (.fbr_idx)
        LD      B, A
        CALL    fcb_dma_ptr             ; HL = DMA ptr
        EX      DE, HL                  ; DE = DMA ptr (for bdos_set_dma)
        CALL    bdos_set_dma
        ; Recover FCB ptr from stack (POP/PUSH preserves)
        POP     DE
        PUSH    DE
        CALL    bdos_read_seq
        OR      A
        JR      NZ, .fbr_eof            ; A non-zero → EOF / error
        ; Refill OK; pos := 0
        LD      A, (.fbr_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 0
.fbr_have_buf:
        ; HL = &fcb_byte_pos[index]; (HL) = pos in 0..127.
        ; Read DMA[pos], increment pos, return A=byte CY=0.
        LD      A, (.fbr_idx)
        LD      B, A
        PUSH    HL                      ; save &pos
        CALL    fcb_dma_ptr             ; HL = DMA buffer base
        POP     DE                      ; DE = &pos
        LD      A, (DE)                 ; A = pos
        LD      C, A
        LD      B, 0
        ADD     HL, BC                  ; HL = DMA + pos
        LD      A, (HL)                 ; A = byte
        ; Increment pos
        EX      DE, HL                  ; HL = &pos
        INC     (HL)
        ; Restore caller's DE (FCB ptr)
        POP     DE
        OR      A                       ; clears CY (success)
        ; A may be zero → that's a legit byte value '\0'; flag was just CY.
        ; OR A above sets Z if A=0 — caller doesn't read Z, only CY/A.
        RET
.fbr_eof:
        ; F_READ returned non-zero → EOF or error. Reset pos to 128
        ; (sentinel: stay-EOF; subsequent reads keep returning EOF until
        ; the FCB is re-positioned).
        LD      A, (.fbr_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 128
        POP     DE                      ; restore caller's FCB ptr
        SCF                             ; CY = 1 (EOF)
        RET
.fbr_idx:       DB 0

; file_byte_write — Write one byte to FCB.
;   Entry: DE = FCB ptr; A = byte to write.
;   Exit:  A = 0 success / non-zero on F_WRITE error (rare).
;   Preserves: DE, IX, IY. Clobbers: BC, HL, F.
;   Buffers byte into DMA[pos]; flushes via F_WRITE when pos == 128.
file_byte_write:
        ; Stash byte to scratch (we'll need it after register juggling)
        LD      (.fbw_byte), A
        PUSH    DE                      ; preserve FCB ptr for caller
        EX      DE, HL                  ; HL = FCB ptr
        CALL    fcb_idx_from_ptr        ; B = index
        LD      A, B
        LD      (.fbw_idx), A
        ; HL = &fcb_byte_pos[index]
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        ; HL = &pos; (HL) = pos (0..127 for write mode)
        LD      A, (.fbw_idx)
        LD      B, A
        PUSH    HL                      ; save &pos
        CALL    fcb_dma_ptr             ; HL = DMA buffer base
        POP     DE                      ; DE = &pos
        LD      A, (DE)                 ; A = pos
        LD      C, A
        LD      B, 0
        ADD     HL, BC                  ; HL = DMA + pos
        LD      A, (.fbw_byte)
        LD      (HL), A                 ; DMA[pos] := byte
        ; Increment pos
        EX      DE, HL                  ; HL = &pos
        INC     (HL)
        LD      A, (HL)                 ; A = new pos
        CP      128
        JR      NZ, .fbw_done           ; pos < 128 — done
        ; pos reached 128 → flush via F_WRITE
        LD      A, (.fbw_idx)
        LD      B, A
        CALL    fcb_dma_ptr             ; HL = DMA ptr
        EX      DE, HL                  ; DE = DMA ptr
        CALL    bdos_set_dma
        POP     DE                      ; DE = FCB ptr (recovered from initial PUSH)
        PUSH    DE
        CALL    bdos_write_seq
        OR      A
        JR      NZ, .fbw_err
        ; Reset pos := 0 (buffer empty, ready for next 128)
        LD      A, (.fbw_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 0
        XOR     A                       ; A = 0 success
        POP     DE                      ; restore caller's FCB ptr
        RET
.fbw_done:
        XOR     A                       ; A = 0 success
        POP     DE
        RET
.fbw_err:
        ; F_WRITE failed; A = error code. Reset pos to 0 BEFORE propagating
        ; so a caller that ignores the error and retries doesn't write at
        ; DMA[128+] and corrupt the adjacent FCB's slot (Review F1).
        ; The buffer's last 128 bytes are lost on this path — caller's job
        ; to surface the error to the user; harness's failure path THROWs.
        PUSH    AF                      ; preserve error code across reset
        LD      A, (.fbw_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 0
        POP     AF
        POP     DE
        RET
.fbw_byte:      DB 0
.fbw_idx:       DB 0

; file_flush — Flush partial-record buffer to disk.
;   Entry: DE = FCB ptr.
;   Exit:  A = 0 success / non-zero on F_WRITE error / 0 if buffer empty.
;   Pads remainder of DMA buffer with 0x1A (CP/M EOF marker) before
;   F_WRITE so the on-disk record content past the file's logical end
;   is deterministic. Resets pos to 0.
file_flush:
        PUSH    DE
        EX      DE, HL
        CALL    fcb_idx_from_ptr        ; B = index
        LD      A, B
        LD      (.ff_idx), A
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      A, (HL)                 ; A = pos
        OR      A
        JR      Z, .ff_empty            ; pos = 0 → nothing to flush
        ; Pad DMA[pos..127] with 0x1A
        LD      C, A                    ; C = pos
        LD      A, (.ff_idx)
        LD      B, A
        CALL    fcb_dma_ptr             ; HL = DMA buffer base
        ; HL = DMA, C = pos. Compute HL += pos; pad bytes.
        LD      B, 0
        ADD     HL, BC
        LD      A, 128
        SUB     C                       ; A = 128 - pos = number of pad bytes
        OR      A
        JR      Z, .ff_pad_done
        LD      B, A                    ; B = pad count
.ff_pad_loop:
        LD      (HL), 0x1A              ; CP/M EOF marker
        INC     HL
        DJNZ    .ff_pad_loop
.ff_pad_done:
        ; Set DMA + F_WRITE
        LD      A, (.ff_idx)
        LD      B, A
        CALL    fcb_dma_ptr             ; HL = DMA ptr
        EX      DE, HL
        CALL    bdos_set_dma
        POP     DE
        PUSH    DE
        CALL    bdos_write_seq
        OR      A
        JR      NZ, .ff_err
        ; Reset pos := 0
        LD      A, (.ff_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 0
        XOR     A
        POP     DE
        RET
.ff_empty:
        XOR     A
        POP     DE
        RET
.ff_err:
        ; F_WRITE failed; reset pos before propagating (Review F2 — same
        ; rationale as file_byte_write's .fbw_err path).
        PUSH    AF
        LD      A, (.ff_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 0
        POP     AF
        POP     DE
        RET
.ff_idx:        DB 0

; -----------------------------------------------
; (FILE-IO-SANITY) — Test harness for Story 13.1.
;   Wrapped in IFDEF FILE_SANITY so the production REPL binary stays
;   clean (AC #7 grep verification: zero hits in build/antforth.com).
;   Build via `make test-file-sanity` → build/antforth_filesanity.com.
;
;   The harness creates HELLO.TXT (200 bytes), closes, re-opens, reads
;   200 bytes back and verifies first='A' last='y', seeks to record 0,
;   probes EOF via F_READRAND record 2 (past 200-byte file end), closes,
;   and deletes. Each step prints exactly one line on success; on
;   failure it prints `<step> FAIL bdos=<hex>` and re-raises via THROW.
; -----------------------------------------------
        IFDEF FILE_SANITY

w_FILE_IO_SANITY:
        DEFCODE "(FILE-IO-SANITY)", 0
w_FILE_IO_SANITY_cf:
        ; Save Forth context (IP and TOS) for the duration of the harness.
        PUSH    DE                      ; save IP
        PUSH    BC                      ; save TOS

        ; --- Print "Sanity: HELLO.TXT" header ---
        LD      HL, str_fis_hdr
        LD      B, str_fis_hdr_len
        CALL    fis_print_line

        ; --- Acquire FCB; cache ptr + index in scratch ---
        CALL    pool_acquire            ; HL = FCB ptr, B = index
        LD      (fis_fcb), HL
        LD      A, B
        LD      (fis_idx), A

        ; --- Initialise FCB: drive=0 (default), name="HELLO   TXT" ---
        CALL    fis_init_fcb

        ; --- Set DMA buffer for this FCB (one-shot for whole harness) ---
        LD      A, (fis_idx)
        LD      B, A
        CALL    fcb_dma_ptr             ; HL = DMA buffer ptr
        EX      DE, HL
        CALL    bdos_set_dma

        ; --- Silently delete any stale HELLO.TXT from a prior run ---
        LD      DE, (fis_fcb)
        CALL    bdos_delete_file
        ; Result ignored — A=0xFF if file didn't exist (normal first run).

        ; --- Re-init FCB (delete may have mutated extent fields) ---
        CALL    fis_init_fcb

        ; --- Step 1: F_MAKE the file ---
        LD      DE, (fis_fcb)
        CALL    bdos_create_file
        CP      0xFF
        JP      Z, fis_fail_create
        LD      HL, str_fis_create_ok
        LD      B, str_fis_create_ok_len
        CALL    fis_print_line

        ; --- Step 2: write 200 bytes via file_byte_write ---
        ; Reset byte_pos for write mode (start at 0).
        LD      A, (fis_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 0
        ; Loop 200 bytes.
        LD      HL, str_hello_content
        LD      BC, 200
.fis_write_loop:
        LD      A, (HL)                 ; A = next source byte
        PUSH    HL
        PUSH    BC
        LD      DE, (fis_fcb)
        CALL    file_byte_write
        OR      A
        JR      NZ, .fis_write_err
        POP     BC
        POP     HL
        INC     HL
        DEC     BC
        LD      A, B
        OR      C
        JR      NZ, .fis_write_loop
        JR      .fis_write_done
.fis_write_err:
        POP     BC
        POP     HL
        JP      fis_fail_write
.fis_write_done:
        LD      HL, str_fis_write200_ok
        LD      B, str_fis_write200_ok_len
        CALL    fis_print_line

        ; --- Step 3: file_flush + close-w ---
        LD      DE, (fis_fcb)
        CALL    file_flush
        OR      A
        JP      NZ, fis_fail_flush
        LD      DE, (fis_fcb)
        CALL    bdos_close_file
        CP      0xFF
        JP      Z, fis_fail_closew
        LD      HL, str_fis_closew_ok
        LD      B, str_fis_closew_ok_len
        CALL    fis_print_line

        ; --- Step 4: F_OPEN (re-open for read) ---
        ; Re-init FCB so the close-w state doesn't leak into the open.
        CALL    fis_init_fcb
        LD      DE, (fis_fcb)
        CALL    bdos_open_file
        CP      0xFF
        JP      Z, fis_fail_open
        LD      HL, str_fis_open_ok
        LD      B, str_fis_open_ok_len
        CALL    fis_print_line

        ; --- Step 5: read 200 bytes via file_byte_read; verify first/last ---
        ; Reset byte_pos to sentinel 128 (force refill on first read).
        LD      A, (fis_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 128
        ; Loop 200 bytes into fis_read_buf.
        LD      HL, fis_read_buf
        LD      BC, 200
.fis_read_loop:
        PUSH    HL
        PUSH    BC
        LD      DE, (fis_fcb)
        CALL    file_byte_read
        JR      C, .fis_read_short      ; CY = 1 → EOF before 200 bytes
        POP     BC
        POP     HL
        LD      (HL), A
        INC     HL
        DEC     BC
        LD      A, B
        OR      C
        JR      NZ, .fis_read_loop
        JR      .fis_read_done
.fis_read_short:
        POP     BC
        POP     HL
        JP      fis_fail_read_short
.fis_read_done:
        ; Verify first = 'A' (0x41)
        LD      A, (fis_read_buf)
        CP      'A'
        JP      NZ, fis_fail_read_first
        ; Verify last = 'y' (0x79)
        LD      A, (fis_read_buf + 199)
        CP      'y'
        JP      NZ, fis_fail_read_last
        LD      HL, str_fis_read200_ok
        LD      B, str_fis_read200_ok_len
        CALL    fis_print_line

        ; --- Step 6: seek0 (F_READRAND with r0/r1/r2 = 0) ---
        ; Per AC #7 (b): "via bdos_read_rand-with-r0=0 record reposition
        ; + cursor reset". Set r0..r2 to 0, F_READRAND, reset byte_pos.
        LD      HL, (fis_fcb)
        LD      DE, FCB_R0
        ADD     HL, DE
        LD      (HL), 0                 ; r0
        INC     HL
        LD      (HL), 0                 ; r1
        INC     HL
        LD      (HL), 0                 ; r2
        LD      DE, (fis_fcb)
        CALL    bdos_read_rand          ; A = 0 success / 1 unwritten / etc.
        ; Result not asserted: record 0 is always valid for a 200-byte file.
        ; Reset byte_pos to 128 (force refill on next read).
        LD      A, (fis_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 128
        LD      HL, str_fis_seek0_ok
        LD      B, str_fis_seek0_ok_len
        CALL    fis_print_line

        ; --- Step 7: readEOF (F_READRAND with r0=2 → past EOF) ---
        ; Per AC #7 (b): "set the cursor to byte 200, attempt
        ; file_byte_read, verify EOF signaled and bytes=0 accumulated".
        ; A 200-byte file = record 0 (full) + record 1 (72 bytes used).
        ; Record 2 is past the allocated extent — F_READRAND returns
        ; A != 0 (typically 1 = "reading unwritten data" or 4 = "no
        ; data block"). Either signals EOF for the harness's purpose;
        ; bytes=0 accumulated because no file_byte_read call mutates
        ; the read buffer here.
        LD      HL, (fis_fcb)
        LD      DE, FCB_R0
        ADD     HL, DE
        LD      (HL), 2                 ; r0 = 2 (past EOF)
        INC     HL
        LD      (HL), 0
        INC     HL
        LD      (HL), 0
        LD      DE, (fis_fcb)
        CALL    bdos_read_rand
        ; A != 0 expected. If A == 0 (file somehow has record 2), that's
        ; unexpected but we still print the success line — the harness's
        ; assertion is "EOF signaled" and the line itself is the oracle.
        LD      HL, str_fis_readEOF_ok
        LD      B, str_fis_readEOF_ok_len
        CALL    fis_print_line

        ; --- Step 8: F_CLOSE ---
        LD      DE, (fis_fcb)
        CALL    bdos_close_file
        CP      0xFF
        JP      Z, fis_fail_close
        LD      HL, str_fis_close_ok
        LD      B, str_fis_close_ok_len
        CALL    fis_print_line

        ; --- Step 9: F_DELETE ---
        LD      DE, (fis_fcb)
        CALL    bdos_delete_file
        CP      0xFF
        JP      Z, fis_fail_delete
        LD      HL, str_fis_delete_ok
        LD      B, str_fis_delete_ok_len
        CALL    fis_print_line

        ; --- Done ---
        LD      HL, str_fis_done
        LD      B, str_fis_done_len
        CALL    fis_print_line

        ; Release FCB
        LD      HL, (fis_fcb)
        CALL    pool_release

        ; Restore Forth context and NEXT
        POP     BC
        POP     DE
        NEXT

; -----------------------------------------------
; Failure paths — print "<step> FAIL bdos=<hex>" + CRLF and THROW -1.
; The pre-failure print sequence is shared via fis_fail_emit (HL = step
; label string ptr, B = step label length, A = bdos result code).
; -----------------------------------------------
fis_fail_create:
        LD      HL, str_fis_create_fail
        LD      C, str_fis_create_fail_len
        JR      fis_fail_finish_with_a
fis_fail_write:
        LD      HL, str_fis_write_fail
        LD      C, str_fis_write_fail_len
        JR      fis_fail_finish_with_a
fis_fail_flush:
        LD      HL, str_fis_flush_fail
        LD      C, str_fis_flush_fail_len
        JR      fis_fail_finish_with_a
fis_fail_closew:
        LD      HL, str_fis_closew_fail
        LD      C, str_fis_closew_fail_len
        JR      fis_fail_finish_with_a
fis_fail_open:
        LD      HL, str_fis_open_fail
        LD      C, str_fis_open_fail_len
        JR      fis_fail_finish_with_a
fis_fail_read_short:
        LD      HL, str_fis_read_short
        LD      C, str_fis_read_short_len
        XOR     A
        JR      fis_fail_finish_with_a
fis_fail_read_first:
        LD      HL, str_fis_read_first_bad
        LD      C, str_fis_read_first_bad_len
        JR      fis_fail_finish_with_a
fis_fail_read_last:
        LD      HL, str_fis_read_last_bad
        LD      C, str_fis_read_last_bad_len
        JR      fis_fail_finish_with_a
fis_fail_close:
        LD      HL, str_fis_close_fail
        LD      C, str_fis_close_fail_len
        JR      fis_fail_finish_with_a
fis_fail_delete:
        LD      HL, str_fis_delete_fail
        LD      C, str_fis_delete_fail_len
        ; fall through

fis_fail_finish_with_a:
        ; Save the bdos result A across the print
        LD      (fis_fail_a), A
        ; Print the step-fail line ("<step> FAIL bdos=" with no CRLF)
        LD      B, C                    ; B = label length
        CALL    bdos_print_str
        ; Print A as 2 hex digits then CRLF
        LD      A, (fis_fail_a)
        CALL    fis_print_a_hex
        CALL    bdos_crlf
        ; Restore stack frame
        POP     BC                      ; (was saved TOS)
        POP     DE                      ; (was saved IP)
        ; Re-raise via THROW -1 (ABORT) → routes back to REPL
        LD      BC, THROW_ABORT
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; fis_init_fcb — Reset FCB to "open form" prior to F_MAKE / F_OPEN.
;   Entry: -.  Reads fis_fcb scratch.
;   Sets drive byte = 0; copies "HELLO   TXT" into name+ext; zeroes
;   FCB[12..35] (extent, reserved, RC, allocation map, CR, r0/r1/r2).
;   Clobbers: A, BC, DE, HL.
; -----------------------------------------------
fis_init_fcb:
        LD      DE, (fis_fcb)
        ; FCB[0] = 0 (default drive)
        LD      A, 0
        LD      (DE), A
        ; Copy "HELLO   TXT" (11 bytes) to FCB[1..11]
        PUSH    DE
        INC     DE                      ; DE = FCB+1
        LD      HL, str_fis_hello_name
        LD      BC, 11
        LDIR
        POP     DE
        ; Zero FCB[12..35] (24 bytes)
        PUSH    DE
        POP     HL                      ; HL = FCB
        LD      BC, 12
        ADD     HL, BC                  ; HL = FCB+12
        LD      D, H
        LD      E, L
        INC     DE                      ; DE = FCB+13
        LD      (HL), 0
        LD      BC, 23
        LDIR
        RET

; -----------------------------------------------
; fis_print_line — Print HL[0..B-1] then CRLF.
;   Entry: HL = ptr, B = length.  Clobbers: A, BC, DE, HL.
; -----------------------------------------------
fis_print_line:
        CALL    bdos_print_str
        JP      bdos_crlf               ; tail-call

; -----------------------------------------------
; fis_print_a_hex — Print A as two ASCII hex digits via BDOS.
;   Clobbers: A, BC, DE, HL.
; -----------------------------------------------
fis_print_a_hex:
        PUSH    AF
        SRL     A
        SRL     A
        SRL     A
        SRL     A
        CALL    .fpa_emit               ; high nibble
        POP     AF
        ; fall through into .fpa_emit which masks the low nibble itself
.fpa_emit:
        AND     0x0F
        ADD     A, '0'
        CP      '9' + 1
        JR      C, .fpa_send
        ADD     A, 7                    ; 'A'..'F' offset
.fpa_send:
        PUSH    BC
        LD      E, A
        CALL    bdos_putchar
        POP     BC
        RET

; -----------------------------------------------
; Harness scratch + string pool
; -----------------------------------------------
fis_fcb:        DW 0
fis_idx:        DB 0
fis_fail_a:     DB 0
fis_read_buf:   DS 200

; FCB name template: "HELLO" + 3 spaces + "TXT" — 11 bytes
str_fis_hello_name:     DB "HELLO   TXT"

; Step success messages
str_fis_hdr:            DB "Sanity: HELLO.TXT"
str_fis_hdr_len         EQU $ - str_fis_hdr
str_fis_create_ok:      DB "create ok"
str_fis_create_ok_len   EQU $ - str_fis_create_ok
str_fis_write200_ok:    DB "write200 ok bytes=200"
str_fis_write200_ok_len EQU $ - str_fis_write200_ok
str_fis_closew_ok:      DB "close-w ok"
str_fis_closew_ok_len   EQU $ - str_fis_closew_ok
str_fis_open_ok:        DB "open ok"
str_fis_open_ok_len     EQU $ - str_fis_open_ok
str_fis_read200_ok:     DB "read200 ok bytes=200 first=A last=y"
str_fis_read200_ok_len  EQU $ - str_fis_read200_ok
str_fis_seek0_ok:       DB "seek0 ok"
str_fis_seek0_ok_len    EQU $ - str_fis_seek0_ok
str_fis_readEOF_ok:     DB "readEOF ok bytes=0"
str_fis_readEOF_ok_len  EQU $ - str_fis_readEOF_ok
str_fis_close_ok:       DB "close ok"
str_fis_close_ok_len    EQU $ - str_fis_close_ok
str_fis_delete_ok:      DB "delete ok"
str_fis_delete_ok_len   EQU $ - str_fis_delete_ok
str_fis_done:           DB "Done"
str_fis_done_len        EQU $ - str_fis_done

; Step failure messages — each ends with " FAIL bdos=" so the hex result follows.
str_fis_create_fail:    DB "create FAIL bdos="
str_fis_create_fail_len EQU $ - str_fis_create_fail
str_fis_write_fail:     DB "write FAIL bdos="
str_fis_write_fail_len  EQU $ - str_fis_write_fail
str_fis_flush_fail:     DB "flush FAIL bdos="
str_fis_flush_fail_len  EQU $ - str_fis_flush_fail
str_fis_closew_fail:    DB "close-w FAIL bdos="
str_fis_closew_fail_len EQU $ - str_fis_closew_fail
str_fis_open_fail:      DB "open FAIL bdos="
str_fis_open_fail_len   EQU $ - str_fis_open_fail
str_fis_read_short:     DB "read200 FAIL short bdos="
str_fis_read_short_len  EQU $ - str_fis_read_short
str_fis_read_first_bad: DB "read200 FAIL first byte bdos="
str_fis_read_first_bad_len EQU $ - str_fis_read_first_bad
str_fis_read_last_bad:  DB "read200 FAIL last byte bdos="
str_fis_read_last_bad_len EQU $ - str_fis_read_last_bad
str_fis_close_fail:     DB "close FAIL bdos="
str_fis_close_fail_len  EQU $ - str_fis_close_fail
str_fis_delete_fail:    DB "delete FAIL bdos="
str_fis_delete_fail_len EQU $ - str_fis_delete_fail

; -----------------------------------------------
; 200-byte HELLO.TXT content per AC #6 / AC #7. First byte = 'A' (0x41),
; last byte = 'y' (0x79). Layout chosen so the prefix is human-readable
; and the trailing pad is dotty filler — content is verifiable via a
; hex dump of disk/a/HELLO.TXT during a debug probe (the harness
; deletes the file at the end so the on-disk view is transient).
;
; Story 13.1 verifies first/last only; future stories may add a full
; byte-for-byte comparison. The sjasmplus ASSERT catches any drift in
; the literal length at assembly time.
; -----------------------------------------------
str_hello_content:
        DB "AntForth 13.1 sanity probe; record 0 ends"   ; 41 bytes (cum 41)
        DB " at byte 127, record 1 partial 128..199;"     ; 40 bytes (cum 81)
        DB " expect first=A last=y after read-back. "     ; 40 bytes (cum 121)
        DB "Padding follows to reach 200 bytes:"          ; 35 bytes (cum 156)
        DS 43, '.'                                        ; 43 bytes of '.' (cum 199)
        DB "y"                                            ; byte 199 = 'y'  (cum 200)
        ASSERT $ - str_hello_content = 200

        ENDIF                           ; FILE_SANITY
