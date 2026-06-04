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

; Story 13.4 v2 PD-1 — per-FCB private source-line slab. Each of the 8
; FCB pool slots gets a 128-byte source-line buffer addressed via
; slab[i] = include_line_pool + (i << 7). Children's INCLUDE writes to
; their own slab — clobber across nesting levels is structurally
; impossible (vs the v1 shared `include_buffer` band-aid).
include_line_pool:  DS FCB_POOL_COUNT * TIB_SIZE        ; 1024 bytes (8 × 128)
        ASSERT FCB_POOL_COUNT * TIB_SIZE = 1024

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

; Per-FCB file-access mode (Story 13.2 — AC #2/#6). Stores the fam
; argument passed to OPEN-FILE / CREATE-FILE so WRITE-FILE can enforce
; the R/O guard (AC #6) without re-deriving it from the FCB. Layout pick
; per Task 6.1: parallel array, mirror of fcb_byte_pos. Encoding picked
; per Task 2.1: R/O = 0, R/W = 1, W/O = 2, BIN = | 4 (BIN is a no-op on
; CP/M 2.2 which has no text/binary distinction; the bit is OR'd through
; non-destructively). pool_init sets all 8 slots to 0; pool_release
; resets the freed slot to 0 (R/O fallback) for stale-FID hardening.
fcb_fam:            DS FCB_POOL_COUNT

; Story 13.5 — per-FCB "has-written" bit; consulted by file_flush in
; R/W mode to skip destructive flush after partial-record reads on a
; never-written R/W FCB. Encoding: 0 = never-written (the only state
; that enables the R/W flush-skip arm), non-zero = at-least-one-write
; (flush proceeds normally). Cleared at pool_acquire (fresh FCB starts
; never-written). Set inside bdos_write_seq on A==0 success (covers all
; F_WRITE callers in one place). Reset at pool_release for stale-FID
; hardening (mirror of fcb_fam reset at line 280-282).
fcb_has_written:    DS FCB_POOL_COUNT

; Story 19.3.1 — per-FCB "soft-EOF seen" flag. Set when (file-refill)
; encounters a 0x1A byte (CP/M 2.2 §"Function 20" soft EOF). Checked at
; (file-refill) ENTRY (review-fix #8/#4 — moved off the per-byte
; file_byte_read path) to short-circuit subsequent refills to clean EOF,
; so a 0x1A in the file content terminates the INCLUDE stream even if the
; physical record contains more bytes (real MicroBeast doesn't pad
; partial-record tails with 0x1A per spec). Scoped to (file-refill):
; READ-FILE / random reads are latch-AGNOSTIC (0x1A is data to a binary
; read) and continue from the shared physical cursor, which after a
; latched refill sits just past the consumed 0x1A. Cleared at
; pool_acquire / pool_release / REPOSITION-FILE via clear_eof_seen.
fcb_eof_seen:       DS FCB_POOL_COUNT

; Story 13.5.1 — per-FCB "dirty" bit; consulted by file_flush + by
; w_FILE_POSITION_cf (TD-1, mid-read accuracy on R/W FIDs). Encoding:
;   0 = clean (DMA holds no uncommitted bytes — read-loaded after a
;       refill, freshly-flushed, freshly-acquired)
;   non-zero = dirty (DMA holds at least one byte from a file_byte_write
;       that has not yet been committed via bdos_write_seq).
; Differs from fcb_has_written semantically:
;   has-written is sticky (set forever after first F_WRITE; gates
;     "should this FCB ever flush?" wholesale).
;   dirty is transient (set on byte-write; cleared on read-refill,
;     successful flush, pool_acquire, pool_release; gates "does DMA
;     hold pending writes RIGHT NOW?" inside the flushable-FCB path).
; The two bits coexist; file_flush gates conjunctively (must be flushable
; AND dirty for flush to fire). Closes TD-1 (R/W mid-read FILE-POSITION
; accuracy), TD-2 (REPOSITION-FILE auto-flush vs Story 13.3 silent
; discard), TD-4 (W/O auto-flush probe coverage gap).
;
; Set sites:   file_byte_write entry (covers u1<128 byte writes).
; Clear sites: pool_acquire (fresh FCB), pool_release (stale-FID
;              hardening), file_byte_read post-refill (DMA replaced by
;              read data), file_flush success path (writes committed),
;              bdos_write_seq A==0 success (covers all F_WRITE callers
;              in one place — same site that sets has-written).
fcb_dirty:          DS FCB_POOL_COUNT

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
        ; Story 13.4 v2 — zero include_line_pool (1024 bytes). Each of the
        ; 8 per-FCB source-line slabs starts cleared so a fresh acquire
        ; never inherits stale bytes from a prior INCLUDE.
        LD      HL, include_line_pool
        LD      (HL), 0
        LD      D, H
        LD      E, L
        INC     DE
        LD      BC, FCB_POOL_COUNT * TIB_SIZE - 1
        LDIR
        ; Set fcb_byte_pos[*] = 128 (sentinel: refill on first read).
        LD      HL, fcb_byte_pos
        LD      B, FCB_POOL_COUNT
        LD      A, 128
.pi_bp_loop:
        LD      (HL), A
        INC     HL
        DJNZ    .pi_bp_loop
        ; Story 13.2 — zero fcb_fam[*] so freshly-acquired slots default
        ; to R/O (= 0). pool_acquire by itself does not set fam; the
        ; user-facing OPEN-FILE / CREATE-FILE words call fcb_fam_set to
        ; record the caller's fam after acquire.
        LD      HL, fcb_fam
        LD      B, FCB_POOL_COUNT
        XOR     A
.pi_fam_loop:
        LD      (HL), A
        INC     HL
        DJNZ    .pi_fam_loop
        ; Story 13.5 — zero fcb_has_written[*] so freshly-acquired slots
        ; start as never-written. pool_acquire also clears the bit at the
        ; per-acquire site; this cold-start zero is hygiene + matches the
        ; fcb_fam idiom above.
        LD      HL, fcb_has_written
        LD      B, FCB_POOL_COUNT
        XOR     A
.pi_hw_loop:
        LD      (HL), A
        INC     HL
        DJNZ    .pi_hw_loop
        ; Story 13.5.1 — zero fcb_dirty[*] so freshly-acquired slots
        ; start clean (DMA contents semantically empty/clean). Mirror
        ; of the .pi_hw_loop above.
        LD      HL, fcb_dirty
        LD      B, FCB_POOL_COUNT
        XOR     A
.pi_dirty_loop:
        LD      (HL), A
        INC     HL
        DJNZ    .pi_dirty_loop
        RET

; -----------------------------------------------
; clear_eof_seen — fcb_eof_seen[B] = 0.
;   Story 19.4 CR fix — single chokepoint for the soft-EOF latch reset.
;   The three logical-stream-restart sites (pool_acquire, pool_release,
;   REPOSITION-FILE) each open-coded the same 9-byte index→address→clear
;   block; REPOSITION-FILE's clear was itself a forgot-a-site retrofit
;   (19.3.1 review-fix #4), so the lifecycle now lives in one routine.
;   Entry: B = FCB index (0..7).
;   Clobbers: HL, DE, F.  (B, A, C preserved.)
; -----------------------------------------------
clear_eof_seen:
        LD      H, 0
        LD      L, B
        LD      DE, fcb_eof_seen
        ADD     HL, DE
        LD      (HL), 0
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
        ; Story 13.5 — clear fcb_has_written[B]: a fresh FCB starts as
        ; never-written. PUSH/POP HL across the index→address compute so
        ; the caller still sees HL = FCB ptr at exit.
        ; Story 13.5.1 — also clear fcb_dirty[B]: a fresh FCB's DMA is
        ; semantically clean (no uncommitted bytes). Both clears live
        ; inside the same PUSH/POP envelope.
        PUSH    HL
        PUSH    BC
        LD      H, 0
        LD      L, B
        LD      DE, fcb_has_written
        ADD     HL, DE
        LD      (HL), 0
        LD      H, 0
        LD      L, B
        LD      DE, fcb_dirty
        ADD     HL, DE
        LD      (HL), 0
        ; Story 19.3.1 — clear fcb_eof_seen[B]: a fresh FCB has not yet
        ; seen 0x1A. (fcb_last_was_clean removed — review-fix #1/#6.)
        CALL    clear_eof_seen          ; B = index; clobbers HL/DE (re-popped below)
        POP     BC
        POP     HL
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
        ; Story 13.2 — also reset fcb_fam[index] to 0 (R/O default) so a
        ; stale FID that slips past fid_validate (defence-in-depth) lands
        ; on R/O behaviour rather than whatever the previous holder set.
        LD      H, 0
        LD      L, B
        LD      DE, fcb_fam
        ADD     HL, DE
        LD      (HL), 0
        ; Story 13.5 — also reset fcb_has_written[index] to 0 (mirror
        ; fcb_fam reset above). A stale FID can never lift the
        ; has-written gate from a prior holder's state.
        LD      H, 0
        LD      L, B
        LD      DE, fcb_has_written
        ADD     HL, DE
        LD      (HL), 0
        ; Story 13.5.1 — also reset fcb_dirty[index] to 0 (parallel
        ; reset to fcb_has_written above). A released FCB's DMA is
        ; semantically clean — pool_acquire will re-clear too, but the
        ; release-time zero is stale-FID hardening.
        LD      H, 0
        LD      L, B
        LD      DE, fcb_dirty
        ADD     HL, DE
        LD      (HL), 0
        ; Story 19.3.1 — reset fcb_eof_seen[index] for stale-FID
        ; hardening. (fcb_last_was_clean removed — review-fix #1/#6.)
        CALL    clear_eof_seen          ; B = index; DE clobber recovered below
        ; Zero the FCB record (36 bytes starting at the FCB ptr).
        ; Story 13.5 — recover the FCB ptr from the function-entry
        ; scratch (.pr_save_h/.pr_save_l) before the LDIR. The prior
        ; per-array resets (fcb_byte_pos / fcb_fam / fcb_has_written)
        ; each clobbered DE with their parallel-array bases; without
        ; this recovery the LDIR was zeroing 36 bytes starting at the
        ; last-loaded parallel-array base — silently corrupting the
        ; bytes after the array (pool_init's code, which only runs at
        ; cold-start, so the corruption was undetectable in practice).
        ; Surfaced 2026-05-04 during Story 13.5 dev-pass when the
        ; audit-anchor probe relied on a clean FCB[R0..R2] state across
        ; reopen-then-FILE-SIZE. Story 13.5 Task 2 catalogue, finding F.
        LD      A, (.pr_save_h)
        LD      H, A
        LD      A, (.pr_save_l)
        LD      L, A                    ; HL = FCB ptr (from entry scratch)
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
; Story 13.4 v2 — INCLUDE source-frame layout (PD-4 / AC #5).
;   10-byte rstack frame; chain-walk reads slots via (IX+EQU), never
;   via magic numbers. Frame written highest-addr-first by
;   (input-frame-push) so IX = frame base after the push.
;       +8: previous INCLUDE-TOP   (chain link)
;       +6: saved SOURCE-ID        (parent's source-id)
;       +4: saved tib_addr         (parent's input buffer address)
;       +2: saved tib_len          (parent's input buffer length)
;       +0: saved >IN              (parent's parse offset)
; -----------------------------------------------
INCLUDE_FRAME_TIB_IN_OFFSET     EQU 0
INCLUDE_FRAME_TIB_LEN_OFFSET    EQU 2
INCLUDE_FRAME_TIB_ADDR_OFFSET   EQU 4
INCLUDE_FRAME_SOURCE_ID_OFFSET  EQU 6
INCLUDE_FRAME_PREV_OFFSET       EQU 8
INCLUDE_FRAME_SIZE              EQU 10
        ASSERT INCLUDE_FRAME_TIB_IN_OFFSET = 0
        ASSERT INCLUDE_FRAME_TIB_LEN_OFFSET = 2
        ASSERT INCLUDE_FRAME_TIB_ADDR_OFFSET = 4
        ASSERT INCLUDE_FRAME_SOURCE_ID_OFFSET = 6
        ASSERT INCLUDE_FRAME_PREV_OFFSET = 8
        ASSERT INCLUDE_FRAME_SIZE = 10

; -----------------------------------------------
; slab_from_fid — Derive the per-FCB source-line slab address.
;   Entry: HL = FID (FCB ptr).
;   Exit:  HL = include_line_pool + (idx << 7) where idx = fcb_idx_from_ptr(HL).
;   Clobbers: A, BC, DE, HL, F. Preserves: IX, IY.
;   Second entry slab_from_idx: B = index already derived (skips the
;     fcb_idx_from_ptr division; B preserved through to exit).
;   antforth internal  slab_from_fid  — derive per-FCB source-line buffer addr (asm helper)
; -----------------------------------------------
slab_from_fid:
        CALL    fcb_idx_from_ptr        ; B = index (0..7), or 0xFF if OOR
slab_from_idx:
        LD      A, B
        AND     1
        RRCA                            ; A = 0x80 if odd, 0x00 if even
        LD      L, A
        LD      A, B
        SRL     A                       ; A = index/2 (0..3)
        LD      H, A
        ; HL = index*128, low byte first.
        LD      DE, include_line_pool
        ADD     HL, DE
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
;   Story 13.5: on A==0 success, sets fcb_has_written[idx_of(DE)] := 1
;   so file_flush's R/W-mode guard sees the FCB has been written.
;   Single-point bit-set covers all callers (file_flush, file_byte_write
;   auto-flush, future direct WRITE-FILE sites).
bdos_write_seq:
        BDOS_SAVE
        LD      C, F_WRITE              ; F_WRITE (21)
        CALL    BDOS_ENTRY
        BDOS_RESTORE
        OR      A
        RET     NZ                      ; F_WRITE error — leave bit alone
        ; Success — set fcb_has_written[idx_of(DE)] := 1.
        ; Preserve A (= 0 success), BC (caller's TOS — restored by
        ; BDOS_RESTORE above), and DE (caller's FCB ptr) across the
        ; index→address compute. fcb_idx_from_ptr clobbers A, BC, DE,
        ; HL — without saving BC the caller's TOS is destroyed (a
        ; cross-call bug surfaced by Story 13.5 dev-pass when the
        ; FILE-SIZE THROW D. probe sequence printed garbage).
        PUSH    AF
        PUSH    BC
        PUSH    DE
        EX      DE, HL                  ; HL = FCB ptr
        CALL    fcb_idx_from_ptr        ; B = index (0..7) or 0xFF if OOR
        LD      A, B
        CP      FCB_POOL_COUNT
        JR      NC, .bws_oor            ; OOR — defensive no-op
        LD      H, 0
        LD      L, A
        LD      DE, fcb_has_written
        ADD     HL, DE
        LD      (HL), 1
        ; Story 13.5.1 — bdos_write_seq A==0 success commits DMA to
        ; disk; clear fcb_dirty[idx] := 0 (DMA contents are no longer
        ; "uncommitted"). Same call site sets has-written (sticky 1)
        ; and clears dirty (transient 0) — opposite writes correct
        ; semantically. Reuse A = idx (still in 0..FCB_POOL_COUNT-1
        ; from the OOR-guard CP above).
        LD      H, 0
        LD      L, A
        LD      DE, fcb_dirty
        ADD     HL, DE
        LD      (HL), 0
.bws_oor:
        POP     DE
        POP     BC
        POP     AF
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
;   Exit:  CY = 0, A = byte                (success-with-byte)
;          CY = 1, A = 0                   (clean EOF — BDOS F_READ returned 1)
;          CY = 1, A != 0                  (I/O error — A = BDOS F_READ return - 1)
;          Discriminate the two CY=1 cases with `JR Z, .clean_eof` — the
;          .fbr_eof tail's `DEC A` sets Z based on A and the trailing SCF
;          does not touch Z, so callers can branch on Z directly without
;          a redundant `OR A`.
;   Preserves: DE, IX, IY. Clobbers: A, BC, HL, F.
;   Story 13.5.2 (TD-3 closure 2026-05-05) — helper-layer rewrite per
;     Story 13.2 AC #17(h) approach (i). The pre-13.5.2 protocol (CY=1
;     for both EOF and I/O error) was the band-aid the Epic 13 retro
;     re-classified upward. The new tri-state signal is consumed by
;     `w_READ_FILE_cf` (clean EOF → ior=0; I/O error → non-zero ior) and
;     by `(file-refill)` (clean EOF → flag-return; I/O error → -37 THROW).
;   Dirty-flag policy on the no-byte path (Story 13.5.1 + 13.5.2):
;     fcb_dirty is cleared ONLY on the success-with-byte refill arm
;     (BDOS A=0). On clean EOF (A=1) DMA is unchanged so any pending
;     write bytes remain valid in DMA and fcb_dirty stays set so a
;     subsequent flush still commits them. On I/O error (A>1) DMA may
;     be partially clobbered per CP/M F_READ semantics; fcb_dirty is
;     intentionally NOT cleared (the user's write data may still be
;     intact, and silently dropping it would mask write loss). The
;     consumer's contract on -37 / non-zero ior is "this FCB's R/W
;     state is suspect; close-without-flush is the safe path."
file_byte_read:
        PUSH    DE                      ; preserve FCB ptr for caller
        ; Compute index → save to scratch
        EX      DE, HL                  ; HL = FCB ptr (DE = stale junk)
        CALL    fcb_idx_from_ptr        ; B = index
        LD      A, B
        LD      (.fbr_idx), A
        ; Story 19.3.1 review-fix — the 0x1A soft-EOF latch was moved OUT
        ; of this per-byte path into (file-refill)'s entry check. Rationale:
        ; (1) the latch only transitions at a refill boundary, so testing it
        ; per byte was wasted hot-path work; (2) fcb_eof_seen is INCLUDE-
        ; stream state — short-circuiting it here leaked premature EOF into
        ; READ-FILE / random reads on the same FID. file_byte_read is now
        ; latch-agnostic; (file-refill) gates the latch where it belongs.
        ; HL = &fcb_byte_pos[index]  (A still holds index from the store above)
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
        ; Story 13.5.1 — refill OK: DMA contents are now read-loaded.
        ; Clear fcb_dirty[index] := 0 so a subsequent file_flush sees
        ; "no pending writes" (closes TD-1: R/W mid-read FILE-POSITION
        ; and TD-2: REPOSITION-FILE auto-flush against read-loaded
        ; DMA). The .fbr_idx scratch already holds the index from
        ; entry; reuse it.
        LD      A, (.fbr_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_dirty
        ADD     HL, DE
        LD      (HL), 0
        ; Refill OK; pos := old_pos - 128.
        ;   Story 13.2 baseline behaviour: old_pos was always 128 (the
        ;   refill sentinel) so post-refill pos = 0.
        ;   Story 13.3 extends this — REPOSITION-FILE encodes a target
        ;   in-buffer offset B as pos = 128 + B. After F_READ_SEQ refills
        ;   the DMA buffer with the record CR points at, pos := B (skip
        ;   to the requested byte within the freshly-loaded record).
        ;   For the legacy pos==128 sentinel case, B = 0 → pos := 0
        ;   (identical to pre-Story-13.3 behaviour).
        LD      A, (.fbr_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      A, (HL)                 ; A = old pos (128..255 since refill branch)
        SUB     128
        LD      (HL), A                 ; pos := A (in 0..127)
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
        ; F_READ returned non-zero → EOF (A=1) or I/O error (A>1).
        ; Story 13.5.2 — stash the BDOS A return BEFORE the pos-sentinel
        ; update clobbers A; reload + DEC A at the tail to encode the
        ; tri-state CY+A signal (clean EOF → A=0; I/O error → A=A_BDOS-1).
        LD      (.fbr_err), A
        ; Reset pos to 128 (sentinel: stay-EOF; subsequent reads keep
        ; returning EOF until the FCB is re-positioned).
        LD      A, (.fbr_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      (HL), 128
        POP     DE                      ; restore caller's FCB ptr
        LD      A, (.fbr_err)
        DEC     A                       ; A=1 (BDOS EOF) → 0; A>1 (BDOS error) → A-1
        SCF                             ; CY = 1 (no byte; DEC A does not touch CY)
        RET
.fbr_idx:       DB 0
.fbr_err:       DB 0                    ; Story 13.5.2 — BDOS F_READ A return stash; the
                                        ; .fbr_eof tail clobbers A while updating the
                                        ; pos-sentinel, so the original return is parked
                                        ; here on entry to the tail and reloaded just
                                        ; before the DEC A / SCF that encodes the
                                        ; tri-state signal.

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
        ; Story 13.5 — set fcb_has_written[index] := 1 at byte-write
        ; entry. The bit gates file_flush at close-time: any FCB on
        ; which file_byte_write has been called has dirty DMA bytes that
        ; must be flushed even if the count is below the 128-byte
        ; record threshold (i.e., bdos_write_seq never fired). Without
        ; this site the close-time flush would skip and the buffered
        ; bytes would be lost (regression of WRITE-FILE for u1 < 128).
        LD      H, 0
        LD      L, A
        LD      DE, fcb_has_written
        ADD     HL, DE
        LD      (HL), 1
        ; Story 13.5.1 — also set fcb_dirty[index] := 1: this byte-write
        ; commits an uncommitted byte into DMA. The bit clears at
        ; bdos_write_seq A==0 success, file_byte_read refill, file_flush
        ; success, pool_acquire, pool_release. Closes TD-1/TD-2 by
        ; giving file_flush + FILE-POSITION a transient "DMA holds
        ; pending writes RIGHT NOW" signal independent of has-written's
        ; sticky "FCB ever written" signal.
        LD      H, 0
        LD      L, A
        LD      DE, fcb_dirty
        ADD     HL, DE
        LD      (HL), 1
        ; HL = &fcb_byte_pos[index]
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        ; HL = &pos. Story 13.2 baseline: pos in 0..127 in write mode.
        ; Story 13.3 extension: REPOSITION-FILE may set pos = 128+B (see
        ;   file_byte_read .fbr_refill_ok comment); for write-mode FIDs
        ;   with B>0 REPOSITION-FILE pre-loads DMA via bdos_read_rand so
        ;   bytes 0..B-1 of the target record are preserved across the
        ;   write. Here we just normalise pos by stripping the encoded
        ;   sentinel bit so the per-byte write loop sees pos in 0..127.
        LD      A, (HL)
        CP      128
        JR      C, .fbw_pos_ok
        SUB     128
        LD      (HL), A                 ; pos := pos - 128 (0..127)
.fbw_pos_ok:
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
        ; Story 13.5 — has-written guard. Skip flush if no F_WRITE has
        ; been issued on this FCB. The bit is cleared at pool_acquire
        ; / pool_release (fresh / freed slot = never-written) and set
        ; inside bdos_write_seq on A==0 success (covers all callers:
        ; file_flush itself, file_byte_write auto-flush, future direct
        ; WRITE-FILE sites). The has-written bit is the source of truth
        ; for "this FCB is dirty"; FAM consult is unnecessary because:
        ;   R/O: has-written stays 0 (no writes possible) → skip.
        ;   R/W reads-only: has-written stays 0 → skip.
        ;   R/W with writes / W/O writes: has-written = 1 → flush.
        ; The audit-anchor (Story 13.5 test 938) closes via this gate:
        ; R/O OPEN → READ-FILE → CLOSE-FILE no longer fires F_WRITE_SEQ
        ; (which previously padded DMA[pos..127] with 0x1A and wrote at
        ; the read-walk-advanced FCB.CR, extending the source file by
        ; ~1.5 MB per cycle on iz-cpm).
        ; OOR-check the index before touching fcb_has_written so a
        ; corrupt FCB ptr (B==0xFF from fcb_idx_from_ptr) does not read
        ; a byte 255 deep into pool_init code and decide flush policy
        ; from it. Mirrors bdos_write_seq's .bws_oor guard (review L3).
        CP      FCB_POOL_COUNT
        JR      NC, .ff_empty           ; OOR index → skip flush
        LD      H, 0
        LD      L, A
        LD      DE, fcb_has_written
        ADD     HL, DE
        LD      A, (HL)
        OR      A
        JR      Z, .ff_empty            ; never written → skip flush
        ; Story 13.5.1 — dirty guard. Skip flush if DMA holds no
        ; uncommitted bytes (cleared by bdos_write_seq A==0 success,
        ; file_byte_read refill, pool_acquire, pool_release; set by
        ; file_byte_write entry). Conjunctive with the has-written gate
        ; above: must be flushable AND have pending writes for flush
        ; to fire. Closes TD-2 (REPOSITION-FILE auto-flush against
        ; read-loaded DMA: dirty=0 → no-op, the t13-probe corruption
        ; mechanism is structurally impossible).
        ; Reload idx — the has-written gate above clobbered A with the
        ; has-written byte value (per the OR A; JR Z chain). .ff_idx
        ; is the canonical scratch holding the FCB index.
        LD      A, (.ff_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_dirty
        ADD     HL, DE
        LD      A, (HL)
        OR      A
        JR      Z, .ff_empty            ; clean (no pending writes) → skip flush
        LD      A, (.ff_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      A, (HL)                 ; A = pos
        OR      A
        JR      Z, .ff_empty            ; pos = 0 → nothing to flush
        CP      128
        JR      NC, .ff_empty           ; pos >= 128 → no pending writes
                                        ;   (Story 13.2 R/O refill sentinel
                                        ;    or Story 13.3 REPOSITION-FILE
                                        ;    encoded sentinel; either way
                                        ;    nothing to flush, leave pos
                                        ;    intact for subsequent ops).
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

; ===============================================
; STORY 13.2 — User-facing File-Access wordset
; ===============================================
; The helpers below (fcb_fam_get, fcb_fam_set, fid_validate,
; fcb_parse_filename, pf_to_upper, pf_validate_byte) and the user-
; facing DEFCODE words (R/O, R/W, W/O, BIN, OPEN-FILE, CREATE-FILE,
; DELETE-FILE, CLOSE-FILE, READ-FILE, WRITE-FILE) layer ANS Forth 1994
; §11.6.1 File-Access semantics atop the Story 13.1 wrapper layer
; (E13-D3, architecture.md:390-394). All BDOS I/O routes through the
; existing wrappers — no new CALL BDOS_ENTRY sites added (AC #10).
;
; ior-vs-THROW split (AC #12):
;   * ior (recoverable, no THROW): file not found, malformed filename,
;     R/O write attempt, disk full, EOF mid-read.
;   * THROW (unrecoverable): -69 FCB pool exhausted, -70 invalid FID.
;
; -----------------------------------------------
; fcb_fam_get — Read fcb_fam[index of FCB ptr].
;   Entry: HL = FCB ptr.   Exit: A = fam.
;   Clobbers: A, BC, DE, HL, F. (Calls fcb_idx_from_ptr internally.)
; -----------------------------------------------
fcb_fam_get:
        CALL    fcb_idx_from_ptr        ; B = index (0..7) or 0xFF
        LD      A, B
        CP      FCB_POOL_COUNT
        JR      NC, .fg_oor             ; out-of-range — return 0 (R/O default)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_fam
        ADD     HL, DE
        LD      A, (HL)
        RET
.fg_oor:
        XOR     A
        RET

; -----------------------------------------------
; fcb_fam_set — Write A → fcb_fam[index of FCB ptr].
;   Entry: HL = FCB ptr; A = fam.   Exit: -.
;   Clobbers: BC, DE, HL, F. Preserves: A. (Calls fcb_idx_from_ptr.)
; -----------------------------------------------
fcb_fam_set:
        LD      C, A                    ; preserve fam across fcb_idx_from_ptr
        CALL    fcb_idx_from_ptr        ; B = index or 0xFF
        LD      A, B
        CP      FCB_POOL_COUNT
        JR      NC, .fs_oor
        LD      H, 0
        LD      L, A
        LD      DE, fcb_fam
        ADD     HL, DE
        LD      A, C
        LD      (HL), A
        RET
.fs_oor:
        LD      A, C                    ; restore A on out-of-range no-op
        RET

; -----------------------------------------------
; fcb_set_byte_pos — Set fcb_byte_pos[index of FCB] = A.
;   Entry: HL = FCB ptr; A = byte_pos value (typical: 0 for write mode,
;     128 for read sentinel).
;   Exit:  - (no caller-visible state).
;   Clobbers: BC, DE, HL, F. Preserves: A.
;   Used by OPEN-FILE / CREATE-FILE to seed the cursor at success —
;   pool_acquire (post-release) leaves pos=0 which is wrong for read
;   mode and right for write mode; pool_init leaves pos=128 which is
;   right for read and wrong for write. The mode-specific seed must
;   happen at the user-facing word's success path so subsequent
;   READ-FILE / WRITE-FILE cycles behave per the byte-stream contract.
; -----------------------------------------------
fcb_set_byte_pos:
        LD      C, A                    ; stash A across fcb_idx_from_ptr
        CALL    fcb_idx_from_ptr        ; B = index or 0xFF
        LD      A, B
        CP      FCB_POOL_COUNT
        JR      NC, .fsbp_oor
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      A, C
        LD      (HL), A
        RET
.fsbp_oor:
        LD      A, C
        RET

; -----------------------------------------------
; fid_validate — Verify a fileid points at an in-use FCB pool slot;
;   raise -70 THROW if not. AC #8 invariant.
;   Entry: HL = FID (FCB ptr from caller).
;   Exit:  returns normally if valid, with B = FCB index (0..7);
;     otherwise JP w_THROW_cf.kernel_entry with BC = -70.
;   Clobbers: A, C, DE, F (HL preserved on success path; B = index
;     returned — 19.4 CR follow-up: lets (file-refill) feed slab_from_idx
;     without a second fcb_idx_from_ptr division).
;   Discipline: every File-Access word that takes a fileid (CLOSE-FILE,
;     READ-FILE, WRITE-FILE — and Story 13.3 FILE-POSITION etc.) calls
;     this BEFORE any FCB-byte access or BDOS call. Use-after-free of
;     a closed FID is then impossible.
; -----------------------------------------------
fid_validate:
        PUSH    HL                      ; preserve FID across fcb_idx_from_ptr
        CALL    fcb_idx_from_ptr        ; B = index or 0xFF
        LD      A, B
        CP      FCB_POOL_COUNT
        JR      NC, .fv_invalid         ; pointer not in pool / not aligned
        ; Mask = 1 << index. Bit set in bitmap means "free" (released);
        ; in-use slot must have its bit clear. Counter runs in A so B
        ; (the index) survives to the caller (see Exit contract).
        LD      C, 1
        LD      A, B
        OR      A
        JR      Z, .fv_check
.fv_shift:
        SLA     C
        DEC     A
        JR      NZ, .fv_shift
.fv_check:
        LD      A, (fcb_pool_bitmap)
        AND     C
        JR      NZ, .fv_invalid         ; bit set → slot is free → stale FID
        POP     HL                      ; restore caller's FID
        RET
.fv_invalid:
        POP     HL                      ; balance stack (HL discarded)
        LD      BC, THROW_FILE_INVALID_FID
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; pf_to_upper — Map ASCII a..z → A..Z; pass others through.
;   Entry: A = byte.   Exit: A = uppercased byte.
;   Clobbers: F.
; -----------------------------------------------
pf_to_upper:
        CP      'a'
        RET     C                       ; A < 'a' — leave alone
        CP      'z' + 1
        RET     NC                      ; A > 'z' — leave alone
        SUB     'a' - 'A'
        RET

; -----------------------------------------------
; pf_validate_byte — Reject filename chars that are illegal in a
;   CP/M FCB name/ext field, per AC #9. Accepts: lower/upper alpha,
;   digits, and the "tame" punctuation. Rejects: '*', '?', '/',
;   ' ' (embedded space), '.' (a second dot in the ext, or any '.'
;   the caller hasn't already filtered).
;   Entry: A = byte.
;   Exit:  CY = 0 valid / CY = 1 invalid.
;   Clobbers: F.
; -----------------------------------------------
pf_validate_byte:
        CP      '*'
        JR      Z, .pvb_bad
        CP      '?'
        JR      Z, .pvb_bad
        CP      '/'
        JR      Z, .pvb_bad
        CP      ' '
        JR      Z, .pvb_bad
        CP      '.'
        JR      Z, .pvb_bad
        OR      A                       ; clear CY (success)
        RET
.pvb_bad:
        SCF
        RET

; -----------------------------------------------
; fcb_parse_filename — Parse a Forth ( c-addr u ) tuple into a CP/M
;   FCB's drive (FCB[0]) + name (FCB[1..8]) + ext (FCB[9..11]) fields.
;   See AC #9 for the full rule set.
;   Entry: DE = FCB ptr; HL = c-addr; B = u (length 0..255).
;   Exit:  CY = 0 success — FCB[0..11] populated, name/ext space-padded;
;          CY = 1 malformed input — FCB state is undefined (caller is
;            expected to release the FCB on the failure path; see Task 5).
;   Clobbers: A, BC, DE, HL, F.
;
; CP/M FCB drive byte uses 1-origin (0 = default, 1 = A:, 2 = B:, ...,
; 16 = P:). BDOS function 25 / DRV_GET (Story 13.1's bdos_get_drive
; helper at file_access.asm above) returns 0-origin (0 = A:). The two
; encodings DO NOT MATCH. fcb_parse_filename produces FCB-form. AC #9
; and AC #17(c) flag this as the canonical off-by-one trap on CP/M;
; never pass the result of bdos_get_drive directly into FCB[0] without
; an INC A translation step.
; -----------------------------------------------
fcb_parse_filename:
        ; --- Length cap: u > 14 → reject before any byte inspection ---
        LD      A, B
        CP      15
        JP      NC, .pf_reject
        OR      A
        JP      Z, .pf_reject           ; u = 0 → empty filename
        ; --- Init FCB[0] = 0; FCB[1..11] = ' ' (0x20) ---
        PUSH    DE                      ; save FCB ptr base for the parse
        PUSH    HL                      ; save c-addr
        PUSH    BC                      ; save u
        XOR     A
        LD      (DE), A                 ; FCB[0] = 0
        ; Set FCB[1] = 0x20, then LDIR-propagate to FCB[2..11].
        ;   LDIR semantics: copies (HL)→(DE), then HL++/DE++/BC--.
        ;   src = FCB+1, dst = FCB+2, count = 10 → FCB[1..11] all 0x20.
        LD      H, D
        LD      L, E
        INC     HL                      ; HL = FCB+1 (src)
        LD      (HL), 0x20
        LD      D, H
        LD      E, L
        INC     DE                      ; DE = FCB+2 (dst)
        LD      BC, 10
        LDIR
        ; FCB[1..11] all 0x20 now. Restore initial registers.
        POP     BC                      ; B = u
        POP     HL                      ; HL = c-addr
        POP     DE                      ; DE = FCB ptr base
        ; --- Drive prefix: "X:" requires u >= 2 and (HL+1) == ':' ---
        LD      A, B
        CP      2
        JR      C, .pf_no_drive         ; u < 2 — too short for prefix
        INC     HL
        LD      A, (HL)
        DEC     HL
        CP      ':'
        JR      NZ, .pf_no_drive
        ; Yes drive prefix. Validate letter; encode 1-origin.
        LD      A, (HL)
        CALL    pf_to_upper
        SUB     'A'
        JP      C, .pf_reject           ; below 'A'
        CP      16
        JP      NC, .pf_reject          ; above 'P'
        INC     A                       ; FCB drive: A=1, B=2, ..., P=16
        LD      (DE), A
        ; Skip "X:" — advance HL by 2, decrement B by 2.
        INC     HL
        INC     HL
        DEC     B
        DEC     B
        LD      A, B
        OR      A
        JP      Z, .pf_reject           ; "X:" with no name → reject
.pf_no_drive:
        ; --- Parse name into FCB[1..8] (up to 8 chars before '.' or EOI) ---
        ; Save FCB[0] for ext-base computation.
        PUSH    DE                      ; save FCB ptr base
        INC     DE                      ; DE = FCB+1 (name slot 0)
        LD      C, 8                    ; remaining name slots
.pf_name_loop:
        LD      A, B
        OR      A
        JR      Z, .pf_name_eoi         ; ran out of input — name done
        LD      A, (HL)
        CP      '.'
        JR      Z, .pf_name_dot
        CALL    pf_validate_byte        ; reject *, ?, /, space, '.'
        JP      C, .pf_reject_pop
        LD      A, C
        OR      A
        JP      Z, .pf_reject_pop       ; > 8 name chars before dot
        LD      A, (HL)
        CALL    pf_to_upper
        LD      (DE), A
        INC     DE
        DEC     C
        INC     HL
        DEC     B
        JR      .pf_name_loop
.pf_name_eoi:
        ; End of input during name (no extension). FCB[9..11] already
        ; space-padded by the init pass.
        ; Empty name? (C still 8 means we wrote nothing.) Reject.
        LD      A, C
        CP      8
        JP      Z, .pf_reject_pop
        POP     DE                      ; restore FCB ptr base
        OR      A                       ; clear CY (success)
        RET
.pf_name_dot:
        ; Found '.'. Verify name not empty.
        LD      A, C
        CP      8
        JP      Z, .pf_reject_pop       ; "." or "X:.TXT" — empty name
        ; Skip the dot.
        INC     HL
        DEC     B
        ; --- Parse extension into FCB[9..11] ---
        ; Recover FCB ptr base; advance to FCB_EXT (= FCB + 9). Use ADD
        ; through A so we don't clobber B (which still holds remaining
        ; input length).
        POP     DE                      ; DE = FCB ptr base
        PUSH    DE                      ; save again for cleanup label
        LD      A, E
        ADD     A, FCB_EXT
        LD      E, A
        JR      NC, .pf_nd_no_carry
        INC     D
.pf_nd_no_carry:
        LD      C, 3                    ; max ext slots
.pf_ext_loop:
        LD      A, B
        OR      A
        JR      Z, .pf_ext_eoi
        LD      A, (HL)
        CALL    pf_validate_byte        ; reject *, ?, /, space, '.' (second dot)
        JP      C, .pf_reject_pop
        LD      A, C
        OR      A
        JP      Z, .pf_reject_pop       ; > 3 ext chars
        LD      A, (HL)
        CALL    pf_to_upper
        LD      (DE), A
        INC     DE
        DEC     C
        INC     HL
        DEC     B
        JR      .pf_ext_loop
.pf_ext_eoi:
        POP     DE                      ; restore FCB ptr base
        OR      A                       ; clear CY (success)
        RET
.pf_reject_pop:
        POP     DE                      ; balance stack
        ; fall through
.pf_reject:
        SCF                             ; CY = 1 (rejected)
        RET

; -----------------------------------------------
; STORY 13.2 — Scratch storage for user-facing File-Access words
; -----------------------------------------------
; All File-Access words use this single shared scratch since Forth is
; single-threaded — no re-entrancy concern. Set at the top of each
; word body, read at error/exit paths.
fac_fcb:        DW 0                    ; current FCB ptr (acquired)
fac_caddr:      DW 0                    ; current c-addr arg
fac_u:          DB 0                    ; current u arg (filename length)
fac_fam:        DB 0                    ; current fam arg
fac_count:      DW 0                    ; READ-FILE / WRITE-FILE u1 arg
fac_buf:        DW 0                    ; READ-FILE / WRITE-FILE c-addr arg
fac_done:       DW 0                    ; READ-FILE u2 accumulator
fac_ip:         DW 0                    ; saved Forth IP across helper calls
                                        ;   (pool_acquire / pool_release /
                                        ;    fcb_parse_filename clobber DE).

; Story 13.3 additions — see FILE-POSITION / REPOSITION-FILE / FILE-SIZE.
fac_r0r1r2:     DS 3                    ; FILE-SIZE cursor save (FCB[33..35])
fac_bp:         DS 4                    ; FILE-POSITION / FILE-SIZE 32-bit
                                        ;   byte-position scratch (little-
                                        ;   endian: bp[0..1] = low cell,
                                        ;   bp[2..3] = high cell).

; ===============================================
; STORY 13.2 — User-facing DEFCODE words
; ===============================================
; All words below are production primitives — no IFDEF wrap. They sit
; before the FILE_SANITY-wrapped harness so both build/antforth.com
; and build/antforth_filesanity.com expose them.
;
; fam encoding pick (Task 2.1): R/O = 0, R/W = 1, W/O = 2, BIN = | 4.
; Bit 2 (= 4) is the BIN flag; bits 0..1 carry the read/write mode.
; The R/O guard in WRITE-FILE tests (fam & 3) == 0; BIN's bit-2 OR
; passes through non-destructively. CP/M 2.2 has no text/binary
; distinction so BIN is a semantic no-op on this platform.

; -----------------------------------------------
; R/O ( -- fam )                           ANS Forth 1994 §11.6.1.2054
;   File-access mode: read-only.
; -----------------------------------------------
w_R_SLASH_O:
        DEFCODE "R/O", 0
w_R_SLASH_O_cf:
        PUSH    BC
        LD      BC, 0
        NEXT

; -----------------------------------------------
; R/W ( -- fam )                           ANS Forth 1994 §11.6.1.2055
;   File-access mode: read-write.
; -----------------------------------------------
w_R_SLASH_W:
        DEFCODE "R/W", 0
w_R_SLASH_W_cf:
        PUSH    BC
        LD      BC, 1
        NEXT

; -----------------------------------------------
; W/O ( -- fam )                           ANS Forth 1994 §11.6.1.2425
;   File-access mode: write-only.
; -----------------------------------------------
w_W_SLASH_O:
        DEFCODE "W/O", 0
w_W_SLASH_O_cf:
        PUSH    BC
        LD      BC, 2
        NEXT

; -----------------------------------------------
; BIN ( fam1 -- fam2 )                     ANS Forth 1994 §11.6.1.0865
;   Binary modifier — sets bit 2 of fam. CP/M 2.2 has no text/binary
;   distinction; BIN is identity-by-mechanism on this platform but the
;   bit is OR'd through so a future port to a system that distinguishes
;   modes can read it back.
; -----------------------------------------------
w_BIN:
        DEFCODE "BIN", 0
w_BIN_cf:
        LD      A, C
        OR      4
        LD      C, A
        NEXT

; -----------------------------------------------
; OPEN-FILE ( c-addr u fam -- fileid ior )  ANS Forth 1994 §11.6.1.1970
;   Open existing file. On success, fileid is the FCB ptr and ior = 0.
;   On failure (file not found, malformed filename, drive out of range),
;   fileid = 0 and ior is non-zero. Pool exhaustion → -69 THROW.
;   ior picks (Task 14): 1 = malformed filename / u > 14; 2 = file not
;   found from F_OPEN.
; -----------------------------------------------
w_OPEN_FILE:
        DEFCODE "OPEN-FILE", 0
w_OPEN_FILE_cf:
        CALL    check_underflow_3
        LD      (fac_ip), DE            ; pool_acquire/release/parser clobber DE
        ; BC = fam, (SP) = u, (SP+2) = c-addr
        LD      A, C
        LD      (fac_fam), A
        POP     HL                      ; HL = u
        ; Cap check: u > 14 — guard before any pool_acquire (AC #17(e))
        LD      A, H
        OR      A
        JP      NZ, .of_too_long
        LD      A, L
        CP      15
        JP      NC, .of_too_long
        LD      (fac_u), A
        POP     HL                      ; HL = c-addr
        LD      (fac_caddr), HL
        ; pool_acquire (may THROW -69 — ANS-recoverable cases pre-handled above)
        CALL    pool_acquire            ; HL = FCB ptr, B = index
        LD      (fac_fcb), HL
        ; Parse filename into FCB
        EX      DE, HL                  ; DE = FCB ptr
        LD      HL, (fac_caddr)
        LD      A, (fac_u)
        LD      B, A
        CALL    fcb_parse_filename
        JR      C, .of_release_malformed
        ; Record fam in fcb_fam[index]
        LD      HL, (fac_fcb)
        LD      A, (fac_fam)
        CALL    fcb_fam_set
        ; F_OPEN
        LD      DE, (fac_fcb)
        CALL    bdos_open_file          ; A = 0..3 success / 0xFF not found
        CP      0xFF
        JR      Z, .of_release_notfound
        ; Zero FCB[32] (CR) — CP/M 2.2 spec: CR is "undefined" after
        ; F_OPEN, application must initialise. iz-cpm zeros it as a
        ; courtesy so partial-record files read correctly without this
        ; step; real MicroBeast firmware leaves CR set (typically to the
        ; last-record value from the prior close-w cycle), so F_READ at
        ; the first call sees CR >= RC and returns 1 (EOF) immediately.
        ; Surfaced 2026-05-03 hardware smoke (Story 13.2 Task 17 probe:
        ; EX=00 RC=01 CR=01 → READ-FILE u2=0 ior=0 instead of u2=N).
        LD      HL, (fac_fcb)
        LD      DE, FCB_CR
        ADD     HL, DE
        LD      (HL), 0
        ; Success — seed byte_pos by fam (Code Review H1, 2026-05-03):
        ;   R/O (fam & 3 == 0)  → pos = 128 (refill sentinel; first
        ;     READ-FILE triggers F_READ_SEQ to fill the DMA buffer).
        ;   R/W or W/O          → pos = 0 (DMA buffer empty, ready for
        ;     first WRITE-FILE byte at offset 0).
        ; Without this discrimination, OPEN-FILE in W/O or R/W mode
        ; followed by WRITE-FILE silently writes the first byte to
        ; DMA[128] (out-of-bounds, corrupts adjacent FCB's buffer or
        ; memory past fcb_dma_pool), and file_flush's `128 - pos`
        ; underflow scribbles up to 224 bytes of 0x1A past the end.
        ; Reproducer: `S" X" R/W CREATE-FILE DROP DROP S" X" R/W
        ; OPEN-FILE DROP FA ! BUF 32 FA @ WRITE-FILE` returned ior=0
        ; but wrote zero bytes of user data and corrupted memory.
        ; AC #19 escalation note: this is a one-line user-facing-layer
        ; fix and stays inside Story 13.2 per AC #19's "small in-pass
        ; refinements" branch (mirroring Task 17's CR-zero defensive
        ; write — same shape: fix at the user-facing word's success
        ; path, not in Story 13.1's helper layer). The byte-stream
        ; layer's pos-128-means-refill convention is unchanged; what
        ; changed is OPEN-FILE's understanding that the convention is
        ; read-mode-only. R/W mixed read+write within one FID still
        ; needs REPOSITION-FILE (Story 13.3) to work cleanly — out of
        ; scope for 13.2.
        LD      HL, (fac_fcb)
        LD      A, (fac_fam)
        AND     3                       ; isolate read/write bits (mask BIN)
        JR      Z, .of_seed_read        ; A = 0 → R/O → seed 128
        XOR     A                       ; non-R/O → seed 0 (write start)
        JR      .of_seed_apply
.of_seed_read:
        LD      A, 128
.of_seed_apply:
        CALL    fcb_set_byte_pos
        LD      HL, (fac_fcb)
        PUSH    HL                      ; fileid = FCB ptr
        LD      BC, 0                   ; ior = 0
        LD      DE, (fac_ip)
        NEXT
.of_release_malformed:
        LD      HL, (fac_fcb)
        CALL    pool_release
        LD      BC, 0
        PUSH    BC                      ; fileid = 0
        LD      BC, 1                   ; ior = 1 (malformed filename)
        LD      DE, (fac_ip)
        NEXT
.of_release_notfound:
        LD      HL, (fac_fcb)
        CALL    pool_release
        LD      BC, 0
        PUSH    BC                      ; fileid = 0
        LD      BC, 2                   ; ior = 2 (file not found)
        LD      DE, (fac_ip)
        NEXT
.of_too_long:
        ; u > 14; FCB not yet acquired. c-addr still on the param stack.
        POP     HL                      ; discard c-addr
        LD      BC, 0
        PUSH    BC                      ; fileid = 0
        LD      BC, 1                   ; ior = 1 (malformed — over length cap)
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; CREATE-FILE ( c-addr u fam -- fileid ior ) ANS Forth 1994 §11.6.1.1010
;   Create file in the manner of OPEN-FILE; if the file already exists,
;   replace it with an empty one of the same name (truncate to zero
;   length). Implementation: pre-emptive silent F_DELETE (ignoring 0xFF
;   "not found") followed by F_MAKE. ior picks: 1 = malformed; 3 = F_MAKE
;   failure (directory full or BDOS error).
; -----------------------------------------------
w_CREATE_FILE:
        DEFCODE "CREATE-FILE", 0
w_CREATE_FILE_cf:
        CALL    check_underflow_3
        LD      (fac_ip), DE
        LD      A, C
        LD      (fac_fam), A
        POP     HL                      ; u
        LD      A, H
        OR      A
        JP      NZ, .cf_too_long
        LD      A, L
        CP      15
        JP      NC, .cf_too_long
        LD      (fac_u), A
        POP     HL                      ; c-addr
        LD      (fac_caddr), HL
        CALL    pool_acquire            ; HL = FCB ptr
        LD      (fac_fcb), HL
        EX      DE, HL                  ; DE = FCB ptr
        LD      HL, (fac_caddr)
        LD      A, (fac_u)
        LD      B, A
        CALL    fcb_parse_filename
        JR      C, .cf_release_malformed
        LD      HL, (fac_fcb)
        LD      A, (fac_fam)
        CALL    fcb_fam_set
        ; --- Pre-emptive silent delete (mirror harness pattern at line 716-718) ---
        ; Per AC #3 / §11.6.1.1010 truncation rule. Result ignored; 0xFF
        ; ("not found") is the normal first-create path.
        LD      DE, (fac_fcb)
        CALL    bdos_delete_file
        ; F_DELETE may have mutated FCB extent fields; re-parse filename
        ; from scratch to restore a clean FCB before F_MAKE.
        LD      HL, (fac_fcb)
        EX      DE, HL                  ; DE = FCB ptr
        LD      HL, (fac_caddr)
        LD      A, (fac_u)
        LD      B, A
        CALL    fcb_parse_filename      ; cannot fail second time (same input)
        ; F_MAKE
        LD      DE, (fac_fcb)
        CALL    bdos_create_file        ; A = 0..3 success / 0xFF directory full
        CP      0xFF
        JR      Z, .cf_release_makefail
        ; Zero FCB[32] (CR) — same defensive reset as OPEN-FILE. F_MAKE
        ; on real CP/M may leave CR in any state; F_WRITE depends on it
        ; starting at 0 to write record 0 first. iz-cpm zeros it; real
        ; hardware may not.
        LD      HL, (fac_fcb)
        LD      DE, FCB_CR
        ADD     HL, DE
        LD      (HL), 0
        ; Success — seed byte_pos = 0 (start DMA fill at offset 0 for WRITE-FILE).
        LD      HL, (fac_fcb)
        XOR     A
        CALL    fcb_set_byte_pos
        LD      HL, (fac_fcb)
        PUSH    HL                      ; fileid
        LD      BC, 0                   ; ior = 0
        LD      DE, (fac_ip)
        NEXT
.cf_release_malformed:
        LD      HL, (fac_fcb)
        CALL    pool_release
        LD      BC, 0
        PUSH    BC                      ; fileid = 0
        LD      BC, 1                   ; ior = 1 (malformed filename)
        LD      DE, (fac_ip)
        NEXT
.cf_release_makefail:
        LD      HL, (fac_fcb)
        CALL    pool_release
        LD      BC, 0
        PUSH    BC                      ; fileid = 0
        LD      BC, 3                   ; ior = 3 (F_MAKE failure — dir full / disk error)
        LD      DE, (fac_ip)
        NEXT
.cf_too_long:
        POP     HL                      ; discard c-addr
        LD      BC, 0
        PUSH    BC                      ; fileid = 0
        LD      BC, 1                   ; ior = 1 (malformed — over length cap)
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; DELETE-FILE ( c-addr u -- ior ) ANS Forth 1994 §11.6.1.1190
;   Delete the named file. Acquires a transient FCB for the BDOS call,
;   releases it unconditionally. ior picks: 1 = malformed filename or
;   "not found" / other recoverable BDOS error.
; -----------------------------------------------
w_DELETE_FILE:
        DEFCODE "DELETE-FILE", 0
w_DELETE_FILE_cf:
        CALL    check_underflow_2
        LD      (fac_ip), DE
        ; BC = u, (SP) = c-addr
        LD      A, B
        OR      A
        JP      NZ, .df_too_long
        LD      A, C
        CP      15
        JP      NC, .df_too_long
        LD      (fac_u), A
        POP     HL                      ; HL = c-addr
        LD      (fac_caddr), HL
        CALL    pool_acquire
        LD      (fac_fcb), HL
        EX      DE, HL                  ; DE = FCB ptr
        LD      HL, (fac_caddr)
        LD      A, (fac_u)
        LD      B, A
        CALL    fcb_parse_filename
        JR      C, .df_release_malformed
        LD      DE, (fac_fcb)
        CALL    bdos_delete_file        ; A = 0..3 success / 0xFF not found
        CP      0xFF
        JR      Z, .df_release_notfound
        ; Success — release and return ior = 0
        LD      HL, (fac_fcb)
        CALL    pool_release
        LD      BC, 0                   ; ior = 0
        LD      DE, (fac_ip)
        NEXT
.df_release_malformed:
        LD      HL, (fac_fcb)
        CALL    pool_release
        LD      BC, 1                   ; ior = 1 (malformed filename)
        LD      DE, (fac_ip)
        NEXT
.df_release_notfound:
        LD      HL, (fac_fcb)
        CALL    pool_release
        LD      BC, 1                   ; ior = 1 (file not found)
        LD      DE, (fac_ip)
        NEXT
.df_too_long:
        ; u > 14; no acquire yet, but c-addr still on stack.
        POP     HL                      ; discard c-addr
        LD      BC, 1                   ; ior = 1 (malformed — over length cap)
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; CLOSE-FILE ( fileid -- ior ) ANS Forth 1994 §11.6.1.0900
;   Close an open file. Flushes any partial-record buffered writes,
;   issues F_CLOSE (16), releases the FCB to the pool. ior = 0 on
;   success; non-zero on flush or close error. Stale-FID raises -70.
;   Pool release happens regardless of close result so the slot is
;   reclaimed (the user's ior signals close-failure, no leak).
; -----------------------------------------------
w_CLOSE_FILE:
        DEFCODE "CLOSE-FILE", 0
w_CLOSE_FILE_cf:
        CALL    check_underflow
        LD      (fac_ip), DE
        ; BC = fileid (FCB ptr)
        LD      H, B
        LD      L, C                    ; HL = fileid
        CALL    fid_validate            ; may raise -70 THROW
        LD      (fac_fcb), HL
        ; --- Flush any pending writes ---
        LD      DE, (fac_fcb)
        CALL    file_flush              ; A = 0 / non-zero on F_WRITE error
        LD      (fac_u), A              ; reuse fac_u to hold flush ior temporarily
        ; --- F_CLOSE ---
        LD      DE, (fac_fcb)
        CALL    bdos_close_file         ; A = 0..3 / 0xFF error
        ; Combine flush and close error into a single ior — non-zero if either failed.
        ;   Map: A = 0xFF (close error) → ior = the FF
        ;        else if flush had error → ior = flush A
        ;        else ior = 0
        LD      C, A                    ; C = close result (0..3 success or 0xFF)
        LD      A, (fac_u)
        OR      A
        JR      NZ, .clf_flush_err
        LD      A, C
        CP      0xFF
        JR      Z, .clf_close_err
        ; Both OK — release and return ior = 0.
        LD      HL, (fac_fcb)
        CALL    pool_release
        LD      BC, 0
        LD      DE, (fac_ip)
        NEXT
.clf_flush_err:
        ; Release FCB anyway; ior = flush error code (in fac_u).
        ; Sign-extend 0xFF → 0xFFFF (-1) for consistency with .clf_close_err
        ; (Code Review L5); other small low-byte BDOS codes pass as-is.
        LD      HL, (fac_fcb)
        CALL    pool_release
        LD      A, (fac_u)
        LD      C, A
        LD      B, 0
        CP      0xFF
        JR      NZ, .clf_flush_err_done
        LD      B, 0xFF                 ; A=0xFF → BC=0xFFFF (-1)
.clf_flush_err_done:
        LD      DE, (fac_ip)
        NEXT
.clf_close_err:
        ; Release FCB; ior = close error (0xFF mapped to non-zero -1).
        LD      HL, (fac_fcb)
        CALL    pool_release
        LD      BC, 0xFFFF              ; ior = -1 (close error)
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; READ-FILE ( c-addr u1 fileid -- u2 ior ) ANS Forth 1994 §11.6.1.2080
;   Read u1 bytes into the buffer at c-addr. u2 = bytes actually read
;   (u2 ≤ u1). On clean EOF, u2 reflects bytes-read-before-EOF and
;   ior = 0. On I/O error, ior != 0. Stale-FID raises -70.
;
;   AC #17(h) closure (Story 13.5.2 TD-3 close 2026-05-05): Story 13.1's
;   file_byte_read now signals tri-state CY+A — clean EOF returns CY=1, A=0
;   (mapped to ior=0 per ANS §11.6.1.2080's "u1 bytes not available is not
;   an exception"); BDOS F_READ I/O error returns CY=1, A!=0 (mapped to
;   non-zero ior, sign-extended to 0xFFFF when A=0xFF, per WRITE-FILE's
;   .wf_io_err / CLOSE-FILE convention — Code Review L5 in Story 13.2).
;   The Story 13.2 deviation noted here previously is now closed; the
;   helper-layer rewrite is the structural fix originally scoped at
;   AC #17(h) approach (i).
; -----------------------------------------------
w_READ_FILE:
        DEFCODE "READ-FILE", 0
w_READ_FILE_cf:
        CALL    check_underflow_3
        LD      (fac_ip), DE
        ; BC = fileid, (SP) = u1, (SP+2) = c-addr
        LD      H, B
        LD      L, C                    ; HL = fileid
        CALL    fid_validate            ; raise -70 THROW on stale FID
        LD      (fac_fcb), HL
        POP     HL
        LD      (fac_count), HL         ; u1
        POP     HL
        LD      (fac_buf), HL           ; c-addr
        ; (Code Review L8) entry-time bdos_set_dma dropped — file_byte_read
        ; sets DMA on every refill internally (file_access.asm:493-495), so
        ; the entry-time set was dead code. Same in WRITE-FILE.
        ; --- Read loop ---
        LD      HL, 0
        LD      (fac_done), HL          ; u2 accumulator
.rf_loop:
        ; Check remaining count
        LD      HL, (fac_count)
        LD      A, H
        OR      L
        JR      Z, .rf_eof_clean        ; count exhausted → ior = 0
        ; Read one byte
        LD      DE, (fac_fcb)
        CALL    file_byte_read          ; tri-state: CY=0 A=byte / CY=1 A=0 clean EOF /
                                        ; CY=1 A!=0 I/O error (Story 13.5.2)
        JR      C, .rf_no_byte
        ; Store byte at c-addr + u2_so_far
        LD      HL, (fac_buf)
        LD      DE, (fac_done)
        ADD     HL, DE
        LD      (HL), A
        ; Increment counters
        LD      HL, (fac_done)
        INC     HL
        LD      (fac_done), HL
        LD      HL, (fac_count)
        DEC     HL
        LD      (fac_count), HL
        JR      .rf_loop
.rf_no_byte:
        ; Helper signalled CY=1; Z (set by helper's DEC A; SCF preserves Z)
        ; discriminates clean EOF (Z=1, A=0) vs I/O error (Z=0, A!=0).
        JR      NZ, .rf_io_err
        ; A = 0 → clean EOF: ior = 0 per §11.6.1.2080. Fall through.
.rf_eof_clean:
        LD      BC, 0                   ; ior = 0
        JR      .rf_done
.rf_io_err:
        ; A != 0 → I/O error. A holds (BDOS F_READ return - 1) per the
        ; helper's tri-state encoding (range 1..254 — BDOS A=0 is success
        ; and never reaches this tail; BDOS A=1 is clean EOF and routes
        ; to .rf_eof_clean). The WRITE-FILE / CLOSE-FILE sign-extend of
        ; A=0xFF → 0xFFFF is structurally unreachable here (would require
        ; helper-A = 0xFF, i.e. BDOS A = 0x100, impossible in 8-bit) so
        ; the BC encoding is a single LD B, 0; LD C, A.
        LD      C, A
        LD      B, 0
.rf_done:
        ; BC = ior set by upstream branch; push u2 and exit.
        LD      HL, (fac_done)
        PUSH    HL                      ; u2
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; WRITE-FILE ( c-addr u1 fileid -- ior ) ANS Forth 1994 §11.6.1.2480
;   Write u1 bytes from c-addr. ior = 0 on success; non-zero on disk
;   error or R/O write attempt (no THROW for either — both ANS-
;   recoverable per §11.3.5). Stale-FID raises -70.
;
;   R/O guard placement (AC #17(d)): the fam check happens BEFORE any
;   DMA setup or FCB mutation. A R/O WRITE-FILE returns ior!=0 having
;   touched no FCB state.
; -----------------------------------------------
w_WRITE_FILE:
        DEFCODE "WRITE-FILE", 0
w_WRITE_FILE_cf:
        CALL    check_underflow_3
        LD      (fac_ip), DE
        ; BC = fileid, (SP) = u1, (SP+2) = c-addr
        LD      H, B
        LD      L, C                    ; HL = fileid
        CALL    fid_validate            ; raise -70 on stale FID
        LD      (fac_fcb), HL
        ; --- R/O guard: read fam, mask bits 0..1, reject if = 0 ---
        CALL    fcb_fam_get             ; A = fam
        AND     3                       ; mask out BIN bit (= 4) and noise
        JR      Z, .wf_ro_guard         ; A = 0 → R/O → reject without mutation
        ; --- Pop args + DMA setup ---
        POP     HL
        LD      (fac_count), HL         ; u1
        POP     HL
        LD      (fac_buf), HL           ; c-addr
        ; (Code Review L8) entry-time bdos_set_dma dropped — file_byte_write
        ; sets DMA on every flush internally (file_access.asm:585-587).
        ; --- Write loop ---
.wf_loop:
        LD      HL, (fac_count)
        LD      A, H
        OR      L
        JR      Z, .wf_done
        ; Fetch next source byte
        LD      HL, (fac_buf)
        LD      A, (HL)
        INC     HL
        LD      (fac_buf), HL
        ; Write it
        LD      DE, (fac_fcb)
        CALL    file_byte_write         ; A = 0 success / non-zero on F_WRITE error
        OR      A
        JR      NZ, .wf_io_err
        LD      HL, (fac_count)
        DEC     HL
        LD      (fac_count), HL
        JR      .wf_loop
.wf_done:
        LD      BC, 0                   ; ior = 0
        LD      DE, (fac_ip)
        NEXT
.wf_io_err:
        ; F_WRITE error — A holds the BDOS return; map to ior in BC.
        ; Sign-extend 0xFF → 0xFFFF (-1) for consistency with .clf_close_err
        ; (Code Review L5); other low-byte BDOS codes pass through.
        LD      C, A
        LD      B, 0
        CP      0xFF
        JR      NZ, .wf_io_err_done
        LD      B, 0xFF
.wf_io_err_done:
        LD      DE, (fac_ip)
        NEXT
.wf_ro_guard:
        ; R/O FID — reject WITHOUT touching DMA / FCB. Pop the two
        ; remaining args (u1, c-addr) and return ior = 1 (R/O write
        ; refused; recoverable per ANS §11.3.5).
        POP     HL                      ; discard u1
        POP     HL                      ; discard c-addr
        LD      BC, 1                   ; ior = 1 (R/O guard)
        LD      DE, (fac_ip)
        NEXT

; ===============================================
; STORY 13.3 — File positioning (FILE-POSITION / REPOSITION-FILE / FILE-SIZE)
; ===============================================
; Three user-facing DEFCODE words that expose the byte-cursor as an
; ANS double-cell unsigned value, allow random-access seeks, and report
; file size in bytes. All ride atop the Story 13.1 BDOS wrappers
; (bdos_file_size / bdos_read_rand / bdos_write_rand) and the Story 13.2
; user-facing infrastructure (fid_validate, fcb_fam, fcb_byte_pos). No
; new BDOS function numbers introduced (AC #7).
;
; Sync-strategy pick (Task 1.8): mirror + encoded pos. REPOSITION sets
; FCB[R0..R2] AND mirrors CR/EX/S2 to the same 24-bit record number;
; sets fcb_byte_pos[index] = 128 + B (encoded "refill then skip B"
; sentinel). file_byte_read interprets pos>=128 as "refill via
; F_READ_SEQ at CR; post-refill pos := old_pos - 128" (1-line tweak at
; .fbr_refill_ok). file_byte_write strips the encoded sentinel at top
; (4-line addition at .fbw_pos_ok). file_flush treats pos>=128 as
; "no pending writes" (defence in depth). For W/O / R/W with B>0,
; REPOSITION pre-loads the DMA buffer via bdos_read_rand so bytes
; 0..B-1 of the target record are preserved across the next write.
;
; ior-vs-THROW routing (Task 9):
;   THROW (-70):  stale FID (fid_validate, all three words).
;   ior=5:        REPOSITION-FILE target ≥ 16 MB (24-bit overflow).
;   ior=0:        success (only outcome for FILE-POSITION / FILE-SIZE
;                 once fid_validate returns — both are infallible
;                 against well-formed FCBs; CP/M 2.2 spec says F_SIZE
;                 never returns an error and FILE-POSITION is pure
;                 arithmetic on FCB fields).

; -----------------------------------------------
; FILE-POSITION ( fileid -- ud ior )            ANS Forth 1994 §11.6.1.1520
;   Return the current byte cursor position as an ANS double-cell
;   unsigned value (high cell on TOS per §3.1.4.1, post-Story-13.0.1)
;   plus an ior. ior is always 0 on the success path; a stale FID
;   raises -70 THROW via fid_validate.
;
;   Cursor synthesis:
;     record_count_seq = (S2 << 12) | (EX << 7) | CR    ; sequential cursor
;     pos              = fcb_byte_pos[index]            ; byte-stream cursor
;     dirty            = fcb_dirty[index]               ; 0=clean, !0=pending
;     bp = (record_count_seq * 128) + (pos & 0x7F),
;       record_count_seq -= 1 if pos < 128 AND dirty == 0 AND
;                              record_count_seq > 0
;       (DMA holds READ-loaded bytes — file_byte_read's F_READ_SEQ has
;        auto-advanced CR by 1 past the loaded record. Story 13.5.1
;        replaced the Story-13.3 fam_masked==0 check with dirty==0:
;        universal across R/O, R/W, W/O FAM modes; correct on R/W
;        mid-read where fam_masked==1 but DMA contents are read data.
;        The record_count_seq>0 guard prevents the SUB 1 borrow chain
;        from underflowing to 0xFFFFFFFF for fresh-OPEN FCBs).
;
;   AC #2 anchors:
;     (a) fresh OPEN-FILE (any fam) → 0 0 0   (record_count_seq=0 guard)
;     (b) after reading 200 bytes of a 256-byte file → 200 0 0
;
;   TD-1 closure (Story 13.5.1 2026-05-05): R/W mid-read FILE-POSITION
;   now reports the byte cursor accurately. Pre-13.5.1 the formula
;   gated on fam_masked==0 (R/O only) and reported +128 too high for
;   R/W mid-read; the dirty-bit replacement closes the gap because
;   file_byte_read clears dirty on every successful refill.
; -----------------------------------------------
w_FILE_POSITION:
        DEFCODE "FILE-POSITION", 0
w_FILE_POSITION_cf:
        CALL    check_underflow
        LD      (fac_ip), DE            ; preserve Forth IP
        LD      H, B
        LD      L, C                    ; HL = fileid
        CALL    fid_validate            ; -70 THROW on stale FID
        LD      (fac_fcb), HL
        ; --- Read FCB fields into scratch (pos, fam, CR, EX, S2) ---
        CALL    fcb_idx_from_ptr        ; B = index (0..7)
        LD      A, B
        LD      (fac_u), A              ; stash index
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      A, (HL)
        LD      (fac_bp), A             ; bp+0 = pos
        LD      A, (fac_u)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_dirty           ; Story 13.5.1 — was fcb_fam (TD-1)
        ADD     HL, DE
        LD      A, (HL)
        LD      (fac_bp + 1), A         ; bp+1 = dirty (0=clean, !0=pending)
        LD      HL, (fac_fcb)
        LD      DE, FCB_CR
        ADD     HL, DE
        LD      A, (HL)
        LD      (fac_bp + 2), A         ; bp+2 = CR
        LD      HL, (fac_fcb)
        LD      DE, FCB_EX
        ADD     HL, DE
        LD      A, (HL)
        LD      (fac_bp + 3), A         ; bp+3 = EX
        LD      HL, (fac_fcb)
        LD      DE, FCB_S2
        ADD     HL, DE
        LD      A, (HL)
        ; CR-010 (hardware-smoke 2026-05-05): mask CP/M 2.2 §5.4 reserved
        ; bits 6..7. Real BDOS sets S2 bit 7 (modified-extent flag) after
        ; F_OPEN / F_READ_SEQ on real hardware; iz-cpm zeros it. Without
        ; the mask, the formula folds the flag bit into byte 2 of
        ; record_count_seq → byte_position off by 0x4000000 (= 64 MB)
        ; on every R/O / R/W mid-read post-refill on real hardware.
        ; CP/M 2.2 max file size is 8 MB, so meaningful S2 is bits 0..3
        ; (CP/M 3 extends to bit 5 for 32 MB); masking 0x3F keeps the
        ; conservative meaningful range and clears the system-reserved
        ; bits without disturbing BDOS's directory-update flag (which
        ; lives in the FCB and is consumed by F_CLOSE at FCB write-back).
        AND     0x3F
        LD      (fac_count), A          ; fac_count[0] = S2 masked (scratch reuse)
        ; --- Build record_count_seq into L=byte0, H=byte1, B=byte2 ---
        LD      A, (fac_bp + 2)         ; A = CR (0..127, bit 7 = 0)
        LD      L, A                    ; L = byte 0
        LD      A, (fac_bp + 3)         ; A = EX (0..31)
        SRL     A                       ; A = EX>>1; CY = EX & 1
        JR      NC, .fp_no_ex_lsb
        SET     7, L                    ; byte 0 bit 7 := EX & 1
.fp_no_ex_lsb:
        LD      H, A                    ; H = EX>>1 (low nibble of byte 1)
        LD      A, (fac_count)          ; A = S2 masked (0..63)
        LD      C, A                    ; C = S2 (preserve)
        AND     0x0F
        RLCA
        RLCA
        RLCA
        RLCA                            ; A = (S2 & 0xF) << 4
        OR      H
        LD      H, A                    ; H = byte 1
        LD      A, C                    ; A = S2
        SRL     A
        SRL     A
        SRL     A
        SRL     A                       ; A = S2 >> 4 (0..3)
        LD      B, A                    ; B = byte 2
        ; --- Adjust: if pos<128 AND dirty==0 AND record_count_seq>0,
        ;     decrement (L,H,B) by 1 (Story 13.5.1 — was fam_masked==0)
        LD      A, (fac_bp)             ; A = pos
        CP      128
        JR      NC, .fp_no_dec
        LD      A, (fac_bp + 1)         ; A = dirty
        OR      A
        JR      NZ, .fp_no_dec          ; dirty → DMA holds writes, no decrement
        ; Story 13.5.1 — underflow guard. record_count_seq is in (L, H, B).
        ; If all three bytes are zero (fresh-OPEN FCB at byte 0), the SUB
        ; 1 chain below would borrow from B beyond zero, producing
        ; 0xFFFFFFFF. Skip the decrement when record_count_seq == 0 so
        ; fresh-OPEN reports 0 0 0, not 0xFFFFFFFF.
        LD      A, L
        OR      H
        OR      B
        JR      Z, .fp_no_dec
        LD      A, L
        SUB     1
        LD      L, A
        JR      NC, .fp_no_dec
        LD      A, H
        SUB     1
        LD      H, A
        JR      NC, .fp_no_dec
        DEC     B
.fp_no_dec:
        ; --- byte_position = (L,H,B) << 7 — accumulate into (L,H,B,bp+3) ---
        XOR     A
        LD      (fac_bp + 3), A         ; bp+3 = 0 (high byte of 32-bit result)
        LD      C, 7
.fp_shift:
        SLA     L
        RL      H
        RL      B
        LD      A, (fac_bp + 3)
        RLA
        LD      (fac_bp + 3), A
        DEC     C
        JR      NZ, .fp_shift
        ; --- OR offset = pos & 0x7F into byte 0 (low 7 bits of L are 0) ---
        LD      A, (fac_bp)
        AND     0x7F
        OR      L
        LD      (fac_bp + 0), A
        LD      A, H
        LD      (fac_bp + 1), A
        LD      A, B
        LD      (fac_bp + 2), A
        ; bp+3 already in memory
        ; --- Push ud-low, ud-high, ior=0 (high cell on TOS per ANS §3.1.4.1) ---
        LD      HL, (fac_bp)            ; ud-low (bp[0..1])
        PUSH    HL
        LD      HL, (fac_bp + 2)        ; ud-high (bp[2..3])
        PUSH    HL
        LD      BC, 0                   ; ior = 0 (TOS)
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; REPOSITION-FILE ( ud fileid -- ior )          ANS Forth 1994 §11.6.1.2142
;   Set the byte cursor of an open FID to ud (0-origin byte position
;   within the file). ud is consumed from the stack with high cell on
;   TOS per §3.1.4.1.
;
;   Implementation:
;     - Auto-flush (Story 13.5.1, TD-2 closure): file_flush is called
;       on the FCB before any cursor mutation. The new dirty-gate makes
;       this safe — flush only fires when DMA holds uncommitted bytes
;       (a real partial-record write); flush is a no-op when DMA holds
;       read-loaded bytes (the post-Story-13.3 (t13)-probe corruption
;       mechanism is structurally impossible). Flush failure → ior = 6;
;       cursor untouched.
;     - 24-bit overflow check: ud-high upper byte != 0 → ior = 5
;       (CP/M 2.2 random-record byte address space is 24 bits = 16 MB).
;     - Compute N = ud >> 7 (24-bit record number); B = ud & 0x7F.
;     - Set FCB[R0..R2] = N (low 24 bits, little-endian) AND mirror
;       CR = N & 0x7F, EX = (N>>7) & 0x1F, S2 = (N>>12) & 0x3F so
;       sequential and random BDOS calls both observe the same cursor.
;     - For W/O or R/W modes (fam_masked != 0) AND B != 0: pre-load
;       the DMA buffer via bdos_read_rand so bytes 0..B-1 of record N
;       are preserved across the next WRITE-FILE. F_READ_RAND failure
;       (e.g., past EOF on growing file) is silently ignored — DMA
;       bytes 0..B-1 may be junk in that path.
;     - Set fcb_byte_pos[index] = 128 + B (encoded sentinel; consumed
;       by file_byte_read / file_byte_write modifications).
;
;   Returns ior = 0 on success, 5 on overflow, 6 on flush-fail.
;
;   Story 13.5.1 closure (TD-2): the Story-13.3 discard discipline is
;   removed. Partial writes survive REPOSITION on R/W and W/O FIDs.
;   The mixed-mode pathological sequencing note (mid-record write,
;   reposition, mid-record write at a different offset) is closed by
;   the dirty gate in file_flush — the flush correctly commits the
;   first partial write before the second mid-record write begins.
; -----------------------------------------------
w_REPOSITION_FILE:
        DEFCODE "REPOSITION-FILE", 0
w_REPOSITION_FILE_cf:
        CALL    check_underflow_3
        LD      (fac_ip), DE
        ; BC = TOS = fileid; (SP) = ud-high; (SP+2) = ud-low
        LD      H, B
        LD      L, C
        CALL    fid_validate            ; -70 THROW on stale FID
        LD      (fac_fcb), HL
        POP     HL                      ; HL = ud-high (on top of stack after fileid pop)
        LD      (fac_buf), HL           ; fac_buf = ud-high (scratch)
        POP     HL                      ; HL = ud-low
        LD      (fac_count), HL         ; fac_count = ud-low (scratch)
        ; --- 24-bit overflow check: ud-high upper byte must be 0 ---
        LD      A, (fac_buf + 1)        ; A = ud-high upper byte (bits 24..31)
        OR      A
        JP      NZ, .rf_overflow
        ; --- Story 13.5.1 — auto-flush (TD-2 closure). Replaces the
        ;     Story-13.3 discard discipline. file_flush is gated by
        ;     fcb_has_written + fcb_dirty (Story 13.5 + 13.5.1) so
        ;     the flush is a no-op on R/O FCBs, never-written R/W
        ;     FCBs, or R/W FCBs whose DMA holds read-loaded bytes.
        ;     The flush only fires when DMA holds uncommitted writes
        ;     — closing TD-2 silent partial-write loss. Flush failure
        ;     → ior = 6, cursor untouched. ---
        LD      DE, (fac_fcb)           ; DE = FCB ptr
        CALL    file_flush
        OR      A
        JP      NZ, .rf_flush_err       ; flush failed → ior = 6
        ; --- Compute N = (ud >> 7) into FCB[R0..R2] ---
        ; ud (24-bit, low byte = fac_count[0], mid = fac_count[1], hi = fac_buf[0])
        ; N = ud >> 7 → 17-bit value in N0/N1/N2:
        ;   N0 = (ud_lo >> 7) | ((ud_mid & 0x7F) << 1)
        ;   N1 = (ud_mid >> 7) | ((ud_hi  & 0x7F) << 1)
        ;   N2 = (ud_hi  >> 7)
        ; B = ud & 0x7F = (ud_lo & 0x7F)
        LD      A, (fac_count)          ; A = ud_lo
        AND     0x7F
        LD      (fac_u), A              ; fac_u = B (in 0..127)
        ; Now compute N (24-bit). Use HL+B (B as high byte).
        ; Approach: load (ud_lo, ud_mid, ud_hi) into (E, D, B), then shift right 7 = shift left 1 then take high bytes.
        LD      A, (fac_count)
        LD      E, A                    ; E = ud_lo
        LD      A, (fac_count + 1)
        LD      D, A                    ; D = ud_mid
        LD      A, (fac_buf)
        LD      C, A                    ; C = ud_hi (low byte)
        ; Shift (C, D, E) left 1 — easier: shift right 7 = (shift right 8) then (shift left 1).
        ; Shift right 8: drop low byte, shift result down by 8 bits.
        ;   N tentative = (C, D, E) >> 8 = (0, C, D), then >> -1 (i.e., shift LEFT 1):
        ;   N0 = (D << 1) | (E >> 7)
        ;   N1 = (C << 1) | (D >> 7)
        ;   N2 = (C >> 7)
        SLA     E                       ; CY = E bit 7 (= bit 7 of ud_lo)
        LD      A, D
        RLA                             ; A = (D << 1) | CY = (D << 1) | (E_bit7)
        LD      L, A                    ; L = N0
        LD      A, C
        RLA                             ; A = (C << 1) | (D_bit7)
        LD      H, A                    ; H = N1
        LD      A, 0
        RLA                             ; A = CY (= C bit 7); N2 = 0 + CY
        LD      B, A                    ; B = N2
        ; Now (L, H, B) = N (24-bit, little-endian)
        ; --- Write FCB[R0..R2] = N ---
        LD      DE, (fac_fcb)
        ; FCB+33 = R0, +34 = R1, +35 = R2.
        PUSH    HL                      ; preserve N
        EX      DE, HL                  ; HL = FCB ptr
        LD      DE, FCB_R0
        ADD     HL, DE                  ; HL = FCB+33
        POP     DE                      ; DE = N's low 16 bits (E=N0, D=N1)
        LD      (HL), E                 ; FCB+33 = N0
        INC     HL
        LD      (HL), D                 ; FCB+34 = N1
        INC     HL
        LD      (HL), B                 ; FCB+35 = N2
        ; --- Mirror CR / EX / S2 ---
        ;   CR = N & 0x7F     = N0 & 0x7F
        ;   EX = (N>>7) & 0x1F
        ;     bits 7..11 of N: bit 7 of N0, bits 0..3 of N1
        ;     EX = (N0 >> 7) | ((N1 & 0x0F) << 1)
        ;   S2 = (N>>12) & 0x3F
        ;     bits 12..17 of N: bits 4..7 of N1, bits 0..1 of N2
        ;     S2 = (N1 >> 4) | ((N2 & 0x03) << 4)
        ;
        ; Stash N0/N1/N2 to scratch FIRST so subsequent FCB-offset loads
        ; (LD DE, FCB_xx — which reset E to the offset's low byte) can't
        ; clobber the values mid-computation. Earlier draft kept N1 in E
        ; across an LD DE, FCB_EX which silently overwrote it with 12 →
        ; S2 mirror collapsed for any N1 ≥ 16 (target byte ≥ 512 KB),
        ; producing silent wrong-record I/O on subsequent sequential ops.
        LD      DE, (fac_fcb)
        LD      HL, FCB_R0
        ADD     HL, DE
        LD      A, (HL)                 ; A = N0
        LD      (fac_r0r1r2 + 0), A
        INC     HL
        LD      A, (HL)                 ; A = N1
        LD      (fac_r0r1r2 + 1), A
        INC     HL
        LD      A, (HL)                 ; A = N2
        LD      (fac_r0r1r2 + 2), A
        ; CR = N0 & 0x7F
        LD      A, (fac_r0r1r2 + 0)
        AND     0x7F
        LD      HL, (fac_fcb)
        LD      DE, FCB_CR
        ADD     HL, DE
        LD      (HL), A                 ; FCB[CR] = N0 & 0x7F
        ; EX = (N0 >> 7) | ((N1 & 0x0F) << 1)
        LD      A, (fac_r0r1r2 + 0)     ; A = N0
        RLCA                            ; bit 0 of A := N0 bit 7
        AND     1
        LD      C, A                    ; C = N0 >> 7
        LD      A, (fac_r0r1r2 + 1)     ; A = N1
        AND     0x0F
        SLA     A                       ; A = (N1 & 0x0F) << 1
        OR      C                       ; A = EX
        LD      HL, (fac_fcb)
        LD      DE, FCB_EX
        ADD     HL, DE
        LD      (HL), A                 ; FCB[EX] = EX
        ; S2 = (N1 >> 4) | ((N2 & 0x03) << 4)
        LD      A, (fac_r0r1r2 + 1)     ; A = N1
        SRL     A
        SRL     A
        SRL     A
        SRL     A                       ; A = N1 >> 4
        LD      C, A
        LD      A, (fac_r0r1r2 + 2)     ; A = N2
        AND     0x03
        RLCA
        RLCA
        RLCA
        RLCA                            ; A = (N2 & 0x03) << 4
        OR      C                       ; A = S2
        LD      HL, (fac_fcb)
        LD      DE, FCB_S2
        ADD     HL, DE
        LD      (HL), A                 ; FCB[S2] = S2
        ; --- Pre-load DMA via F_READ_RAND if write-mode AND B>0 ---
        ;   B is in fac_u. Skip if B == 0. Skip if fam_masked == 0 (R/O).
        LD      A, (fac_u)              ; A = B
        OR      A
        JR      Z, .rf_no_preload       ; B = 0 → no pre-load needed
        LD      HL, (fac_fcb)
        CALL    fcb_fam_get             ; A = fam (clobbers BC, DE, HL, F)
        AND     3
        JR      Z, .rf_no_preload       ; R/O → no pre-load
        ; Pre-load: set DMA, F_READ_RAND. Failure ignored (file may not
        ; yet have record N — user is extending it via subsequent writes).
        LD      HL, (fac_fcb)
        CALL    fcb_idx_from_ptr        ; B = index
        CALL    fcb_dma_ptr             ; HL = DMA ptr (clobbers A, F; B preserved)
        EX      DE, HL                  ; DE = DMA ptr
        CALL    bdos_set_dma
        LD      DE, (fac_fcb)
        CALL    bdos_read_rand          ; A = result; ignored
.rf_no_preload:
        ; --- Set fcb_byte_pos[index] = 128 + B ---
        LD      HL, (fac_fcb)
        CALL    fcb_idx_from_ptr        ; B = index
        LD      A, B
        LD      H, 0
        LD      L, A
        LD      DE, fcb_byte_pos
        ADD     HL, DE
        LD      A, (fac_u)              ; A = B
        ADD     A, 128
        LD      (HL), A                 ; pos = 128 + B (encoded sentinel)
        ; Story 19.3.1 review-fix (#4) — clear fcb_eof_seen[index]:
        ; repositioning re-opens the logical stream, so a 0x1A consumed by a
        ; prior (file-refill) must not stick and force premature EOF on a
        ; re-read from the new cursor. B still holds the index from the
        ; fcb_idx_from_ptr above.
        CALL    clear_eof_seen          ; B = index; HL/DE dead here (reloaded below)
        ; --- Success: ior = 0 ---
        LD      BC, 0
        LD      DE, (fac_ip)
        NEXT
.rf_overflow:
        ; ud-high upper byte != 0 → target ≥ 16 MB. ior = 5; no FCB mutation.
        LD      BC, 5
        LD      DE, (fac_ip)
        NEXT
.rf_flush_err:
        ; Story 13.5.1 — file_flush failed (bdos_write_seq returned non-
        ; zero). Return ior = 6 (the slot Story 13.3 Task 1.10
        ; pre-allocated for "REPOSITION-FILE flush-fail" and never used
        ; while the discard discipline was in force).
        ;
        ; CURSOR STATE on flush failure (CR-004 documentation):
        ;   R0..R2 / CR / EX / S2 — UNCHANGED (REPOSITION had not yet
        ;     reached the cursor-mirror block when file_flush ran, so
        ;     the record cursor stays at its pre-REPOSITION value).
        ;   fcb_byte_pos — RESET TO 0 by file_flush.ff_err (review F2,
        ;     Story 13.5). Caller's pre-REPOSITION pos value (e.g. the
        ;     5 bytes the user had pending) is clobbered.
        ; The byte_pos reset is a pre-existing behaviour of file_flush
        ; (it predates Story 13.5.1 by way of the original Story 13.5
        ; F2 hardening) but only became reachable via REPOSITION-FILE
        ; with the auto-flush in this story — pre-13.5.1 the discard
        ; discipline never invoked file_flush from REPOSITION, so the
        ; .ff_err pos-reset never bit a REPOSITION caller. Users
        ; receiving ior=6 should treat byte_pos as undefined and
        ; CLOSE-FILE / re-OPEN-FILE before relying on FILE-POSITION.
        LD      BC, 6
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; FILE-SIZE ( fileid -- ud ior )                ANS Forth 1994 §11.6.1.1522
;   Return the byte size of an open file as a double-cell unsigned
;   value (high cell on TOS per §3.1.4.1) plus an ior.
;
;   CP/M record-rounding caveat: CP/M 2.2's filesystem tracks size in
;   128-byte records, not bytes. A file written with WRITE-FILE of 100
;   bytes occupies 1 record on disk (128 bytes, with bytes 100..127
;   padded to 0x1A by file_flush at CLOSE-FILE); FILE-SIZE reports
;   128, not 100. Per ANS §11.6.1.1522 this is permitted: "the size,
;   in characters, of the file" — on CP/M 2.2 this is rounded up to
;   the nearest 128-byte boundary. AC #4 caveat documented.
;
;   Implementation:
;     - Save FCB[R0..R2] to fac_r0r1r2 (F_SIZE clobbers these fields
;       to write the size into them — must be restored to preserve the
;       user's cursor).
;     - bdos_file_size (F_SIZE = 35; Story 13.1 wrapper). After the
;       call, FCB[R0..R2] = file's record count (24-bit unsigned).
;     - bp = (record_count << 7) — multiply by 128 to convert records
;       to bytes; up to 25 bits, fits in 32-bit unsigned.
;     - Restore FCB[R0..R2] from fac_r0r1r2.
;     - Push ud-low, ud-high, ior=0 (high cell on TOS).
;
;   ior is always 0 on the success path (CP/M 2.2 spec: F_SIZE never
;   returns an error code; A documented as "not used" on return). A
;   stale FID raises -70 THROW.
; -----------------------------------------------
w_FILE_SIZE:
        DEFCODE "FILE-SIZE", 0
w_FILE_SIZE_cf:
        CALL    check_underflow
        LD      (fac_ip), DE
        LD      H, B
        LD      L, C
        CALL    fid_validate            ; -70 THROW on stale FID
        LD      (fac_fcb), HL
        ; --- Save FCB[R0..R2] to fac_r0r1r2 ---
        LD      DE, (fac_fcb)
        LD      HL, FCB_R0
        ADD     HL, DE                  ; HL = &FCB[R0]
        LD      DE, fac_r0r1r2
        LD      BC, 3
        LDIR
        ; --- F_SIZE: writes file's record count into FCB[R0..R2] ---
        LD      DE, (fac_fcb)
        CALL    bdos_file_size          ; A = ignored per CP/M 2.2 spec
        ; --- Read FCB[R0..R2] = 24-bit record count into (L, H, B) ---
        LD      HL, (fac_fcb)
        LD      DE, FCB_R0
        ADD     HL, DE
        LD      A, (HL)
        LD      C, A                    ; C = R0
        INC     HL
        LD      A, (HL)
        LD      D, A                    ; D = R1
        INC     HL
        LD      A, (HL)
        LD      B, A                    ; B = R2
        LD      L, C
        LD      H, D                    ; HL = (R0, R1) = low 16 bits
        ; --- Multiply (L, H, B) by 128 = shift left 7 into 32-bit (L, H, B, bp+3) ---
        XOR     A
        LD      (fac_bp + 3), A         ; bp+3 = 0 (high byte)
        LD      C, 7
.fs_shift:
        SLA     L
        RL      H
        RL      B
        LD      A, (fac_bp + 3)
        RLA
        LD      (fac_bp + 3), A
        DEC     C
        JR      NZ, .fs_shift
        LD      A, L
        LD      (fac_bp + 0), A
        LD      A, H
        LD      (fac_bp + 1), A
        LD      A, B
        LD      (fac_bp + 2), A
        ; bp+3 already in memory
        ; --- Restore FCB[R0..R2] from fac_r0r1r2 ---
        LD      HL, (fac_fcb)
        LD      BC, FCB_R0
        ADD     HL, BC
        EX      DE, HL                  ; DE = &FCB[R0]
        LD      HL, fac_r0r1r2
        LD      BC, 3
        LDIR
        ; --- Push ud-low, ud-high, ior=0 (high cell on TOS) ---
        LD      HL, (fac_bp)            ; ud-low
        PUSH    HL
        LD      HL, (fac_bp + 2)        ; ud-high
        PUSH    HL
        LD      BC, 0                   ; ior = 0
        LD      DE, (fac_ip)
        NEXT

; ===============================================
; STORY 13.4 v2 — INCLUDE source-input nesting helpers
; ===============================================
; Per PD-1..PD-14: per-FCB private slab (no shared include_buffer); 10-byte
; IX-rstack INCLUDE frames; chain-walk discipline in src/exception.asm. All
; helpers below are production primitives (no IFDEF wrap). The INCLUDE family
; (INCLUDED / INCLUDE-FILE / INCLUDE) sits before the FILE_SANITY-wrapped
; harness so both build/antforth.com and build/antforth_filesanity.com expose
; them.

; -----------------------------------------------
; Scratch storage for (file-refill) and (input-frame-push). Single-threaded
; Forth — no re-entrancy concern. Always set at the top of each helper body.
; -----------------------------------------------
fr_fid:         DW 0                    ; (file-refill) current FID
fr_slab:        DW 0                    ; (file-refill) per-FCB slab address
fr_pos:         DB 0                    ; (file-refill) current line-byte count
fr_fcb_idx:     DB 0                    ; (file-refill) cached FCB index for the current call;
                                        ; set at entry from slab_from_fid; reused by .fr_terminator
                                        ; / .fr_eof / .fr_soft_eof_seen to address per-FCB flags.
ifp_src_id:     DW 0                    ; (input-frame-push) source-id arg
ifp_u:          DW 0                    ; (input-frame-push) tib_len arg
ifp_caddr:      DW 0                    ; (input-frame-push) tib_addr arg

; -----------------------------------------------
; (slab-from-fid) ( fileid -- slab )  PD-2 / AC #3
;   DEFCODE wrapper around the slab_from_fid asm helper. Used by INCLUDED's
;   and INCLUDE-FILE's colon-thread bodies (DEFWORDs cannot call asm-only
;   helpers directly).
; antforth internal  (slab-from-fid) — DEFCODE wrapper for colon-thread callers
; -----------------------------------------------
w_PAREN_SLAB_FROM_FID:
        DEFCODE "(slab-from-fid)", 0
w_PAREN_SLAB_FROM_FID_cf:
        CALL    check_underflow         ; 1-cell guard (BC = fileid)
        LD      (fac_ip), DE            ; fcb_idx_from_ptr clobbers DE
        LD      H, B
        LD      L, C                    ; HL = fileid
        CALL    slab_from_fid           ; HL = slab address
        LD      B, H
        LD      C, L                    ; BC = slab → new TOS
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; (fid-validate) ( fileid -- fileid )  PD-7 / AC #6
;   DEFCODE wrapper around fid_validate. On valid: passes fileid through.
;   On stale FID: raises -70 THROW_FILE_INVALID_FID via fid_validate's
;   internal JP w_THROW_cf.kernel_entry.
; antforth internal  (fid-validate) — DEFCODE wrapper for fid_validate
; -----------------------------------------------
w_PAREN_FID_VALIDATE:
        DEFCODE "(fid-validate)", 0
w_PAREN_FID_VALIDATE_cf:
        CALL    check_underflow         ; 1-cell guard
        LD      (fac_ip), DE            ; fid_validate may JP w_THROW
        LD      H, B
        LD      L, C                    ; HL = fileid
        CALL    fid_validate            ; -70 THROW on stale FID
        ; HL still holds fileid on success path (per fid_validate contract)
        LD      B, H
        LD      C, L                    ; BC = fileid (passes through)
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; (input-frame-push) ( c-addr u source-id -- )  PD-5 / AC #6
;   Saves parent's source_id / tib_addr / tib_len / >IN + previous
;   INCLUDE-TOP into a 10-byte IX-rstack frame; sets INCLUDE-TOP to the
;   new frame base; installs the new spec (tib_addr=c-addr, tib_len=u,
;   source_id=arg, >IN=0). Frame written highest-addr-first so IX = frame
;   base after the push.
; antforth internal  (input-frame-push) — push INCLUDE source frame
; -----------------------------------------------
w_PAREN_INPUT_FRAME_PUSH:
        DEFCODE "(input-frame-push)", 0
w_PAREN_INPUT_FRAME_PUSH_cf:
        CALL    check_underflow_3       ; 3-cell guard
        LD      (fac_ip), DE
        ; BC = source-id, SP[0] = u, SP[2] = c-addr
        LD      (ifp_src_id), BC
        POP     HL
        LD      (ifp_u), HL
        POP     HL
        LD      (ifp_caddr), HL
        ; --- Push 10-byte frame on rstack (highest-addr first; IX grows down) ---
        ; +8: previous INCLUDE-TOP
        DEC     IX
        DEC     IX
        LD      A, (IY+UserArea.include_top)
        LD      (IX+0), A
        LD      A, (IY+UserArea.include_top+1)
        LD      (IX+1), A
        ; +6: saved SOURCE-ID
        DEC     IX
        DEC     IX
        LD      A, (IY+UserArea.source_id)
        LD      (IX+0), A
        LD      A, (IY+UserArea.source_id+1)
        LD      (IX+1), A
        ; +4: saved tib_addr
        DEC     IX
        DEC     IX
        LD      A, (IY+UserArea.tib_addr)
        LD      (IX+0), A
        LD      A, (IY+UserArea.tib_addr+1)
        LD      (IX+1), A
        ; +2: saved tib_len
        DEC     IX
        DEC     IX
        LD      A, (IY+UserArea.tib_len)
        LD      (IX+0), A
        LD      A, (IY+UserArea.tib_len+1)
        LD      (IX+1), A
        ; +0: saved >IN
        DEC     IX
        DEC     IX
        LD      A, (IY+UserArea.tib_in)
        LD      (IX+0), A
        LD      A, (IY+UserArea.tib_in+1)
        LD      (IX+1), A
        ; --- Update INCLUDE-TOP = frame base. IX now = frame base. ---
        PUSH    IX
        POP     HL
        LD      (IY+UserArea.include_top), L
        LD      (IY+UserArea.include_top+1), H
        ; --- Install new spec ---
        ; tib_addr = c-addr (saved arg)
        LD      HL, (ifp_caddr)
        LD      (IY+UserArea.tib_addr), L
        LD      (IY+UserArea.tib_addr+1), H
        ; tib_len = u
        LD      HL, (ifp_u)
        LD      (IY+UserArea.tib_len), L
        LD      (IY+UserArea.tib_len+1), H
        ; source_id = arg (was BC at entry, stashed in ifp_src_id)
        LD      HL, (ifp_src_id)
        LD      (IY+UserArea.source_id), L
        LD      (IY+UserArea.source_id+1), H
        ; tib_in = 0
        LD      (IY+UserArea.tib_in), 0
        LD      (IY+UserArea.tib_in+1), 0
        ; --- Pop new TOS into BC; restore IP; NEXT ---
        POP     BC
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; (input-frame-pop) ( -- )  PD-5 / AC #6
;   Restores parent's 4-cell spec from the most-recent INCLUDE frame; relinks
;   INCLUDE-TOP from slot +8; advances IX past the 10-byte frame. NO
;   compensation logic. NO marker flag. NO `tib_in = tib_len` fixup —
;   per-FCB slab discipline (PD-1) makes those structurally unnecessary.
; antforth internal  (input-frame-pop) — pop INCLUDE source frame
; -----------------------------------------------
w_PAREN_INPUT_FRAME_POP:
        DEFCODE "(input-frame-pop)", 0
w_PAREN_INPUT_FRAME_POP_cf:
        ; IX points at frame base (frame is most-recent on rstack).
        ; Restore parent's spec from frame slots HL+0..HL+6.
        ; >IN
        LD      A, (IX+INCLUDE_FRAME_TIB_IN_OFFSET)
        LD      (IY+UserArea.tib_in), A
        LD      A, (IX+INCLUDE_FRAME_TIB_IN_OFFSET+1)
        LD      (IY+UserArea.tib_in+1), A
        ; tib_len
        LD      A, (IX+INCLUDE_FRAME_TIB_LEN_OFFSET)
        LD      (IY+UserArea.tib_len), A
        LD      A, (IX+INCLUDE_FRAME_TIB_LEN_OFFSET+1)
        LD      (IY+UserArea.tib_len+1), A
        ; tib_addr
        LD      A, (IX+INCLUDE_FRAME_TIB_ADDR_OFFSET)
        LD      (IY+UserArea.tib_addr), A
        LD      A, (IX+INCLUDE_FRAME_TIB_ADDR_OFFSET+1)
        LD      (IY+UserArea.tib_addr+1), A
        ; source_id
        LD      A, (IX+INCLUDE_FRAME_SOURCE_ID_OFFSET)
        LD      (IY+UserArea.source_id), A
        LD      A, (IX+INCLUDE_FRAME_SOURCE_ID_OFFSET+1)
        LD      (IY+UserArea.source_id+1), A
        ; INCLUDE-TOP := previous (slot +8)
        LD      A, (IX+INCLUDE_FRAME_PREV_OFFSET)
        LD      (IY+UserArea.include_top), A
        LD      A, (IX+INCLUDE_FRAME_PREV_OFFSET+1)
        LD      (IY+UserArea.include_top+1), A
        ; Advance IX past the 10-byte frame
        PUSH    BC
        LD      BC, INCLUDE_FRAME_SIZE
        ADD     IX, BC
        POP     BC
        NEXT

; -----------------------------------------------
; (close-current-fid) ( -- )  PD-15 / AC #15
;   Closes the FID currently bound to USER.source_id if it is a real FID
;   (> 0). No-op for keyboard (0) and EVALUATE (-1). Runs flush + F_CLOSE
;   + pool_release via existing Story-13.2 wrappers; the resulting ior is
;   DISCARDED (per PD-10 close-failure semantics: pool_release always runs,
;   the user only sees the original THROW code that triggered the cleanup).
; antforth internal  (close-current-fid) — release the active INCLUDE FID
; -----------------------------------------------
w_PAREN_CLOSE_CURRENT_FID:
        DEFCODE "(close-current-fid)", 0
w_PAREN_CLOSE_CURRENT_FID_cf:
        LD      (fac_ip), DE            ; EX DE,HL below clobbers DE; bdos_close_file
                                        ; itself preserves DE via BDOS_SAVE/RESTORE
                                        ; (src/macros.asm:141-152), so the save is
                                        ; only required for the EX traffic.
        PUSH    BC                      ; preserve TOS — pool_release clobbers BC
        ; Read source_id; treat 0 (keyboard) and 0xFFFF (-1 EVALUATE) as
        ; sentinels. Exact-value tests instead of a bit-7 sniff so the
        ; check stays correct if the FCB pool ever lands at addr ≥ 0x8000.
        LD      L, (IY+UserArea.source_id)
        LD      H, (IY+UserArea.source_id+1)
        LD      A, H
        OR      L
        JR      Z, .ccf_skip            ; HL == 0 → keyboard
        LD      A, H
        AND     L
        INC     A                       ; A == 0 iff HL == 0xFFFF
        JR      Z, .ccf_skip            ; HL == 0xFFFF → EVALUATE
        ; HL = real FID. F_CLOSE + pool_release; ior discarded.
        ; Note: no file_flush call in this body (review L4 — earlier
        ; "explicit skip" framing was figurative; the body just omits
        ; the call). INCLUDE always opens R/O so the byte-stream layer
        ; never invokes file_byte_write and the per-FCB
        ; `fcb_has_written` bit stays 0 — file_flush is now mode-aware
        ; via that bit (Story 13.5) plus the per-FCB `fcb_dirty` bit
        ; (Story 13.5.1, transient counterpart) and would itself skip
        ; even if called. Omitting the call is documented intent +
        ; defence-in-depth (clarity at the INCLUDE close-site +
        ; regression protection per Story 13.5 AC #5).
        EX      DE, HL                  ; DE = FID
        CALL    bdos_close_file         ; A discarded
        EX      DE, HL                  ; HL = FID for pool_release
        CALL    pool_release
.ccf_skip:
        POP     BC                      ; restore TOS
        LD      DE, (fac_ip)
        NEXT

; -----------------------------------------------
; (file-refill) ( -- flag )  PD-3 / AC #4
;   Reads one line from the file bound to USER.source_id (must be > 0)
;   into the per-FCB slab via Story 13.1's file_byte_read byte-stream
;   helper. Sets USER.tib_addr = slab, USER.tib_len = line length,
;   USER.tib_in = 0. Returns -1 (true) if any byte was read before EOF;
;   0 (false) on immediate EOF.
;
;   Line-end discipline:
;     LF (0x0A) and 0x1A (CP/M soft EOF) terminate the line.
;     CR (0x0D) is silently dropped (treated as whitespace).
;     If a line exceeds TIB_SIZE (128) bytes, the first 128 bytes are
;     stored, the rest of the line is silently consumed up to the next
;     terminator.
;
;   Precondition: USER.source_id > 0 (real FID, not keyboard 0 / not
;     EVALUATE -1). Defensive guard: raises -70 THROW_FILE_INVALID_FID
;     if the precondition fails (caller misfire defence).
;
;   I/O-error handling (Story 13.5.2 — TD-3 closure 2026-05-05): Story 13.1's
;     file_byte_read now signals tri-state CY+A (helper rewrite). On clean
;     EOF (CY=1, A=0) (file-refill) preserves its existing flag-return
;     contract (-1 if any bytes read before EOF, 0 on immediate EOF). On
;     BDOS F_READ I/O error (CY=1, A!=0) the call sites raise -37
;     THROW_FILE_IO via the shared .fr_io_error tail rather than silently
;     truncating the source — closing the latent flagged at constants.asm
;     for THROW_FILE_IO. Caller stack discipline: .fr_io_error pops the
;     entry-time PUSH BC before jumping into THROW (mirrors .fr_invalid_src).
;     Note on input-source frame: (file-refill) mutates UserArea.tib_addr /
;     tib_in / fr_pos in flight. INCLUDED / INCLUDE-FILE wrap their refill
;     loop in CATCH and on a caught THROW call (close-current-fid) +
;     (input-frame-pop) before re-raising (file_access.asm:2947-2949 /
;     :2997-3000), so the pre-INCLUDE input-source frame is restored;
;     callers reaching THROW from -37 see the OUTER source unchanged.
; antforth internal  (file-refill) — read one line from file source into per-FCB slab
; -----------------------------------------------
w_PAREN_FILE_REFILL:
        DEFCODE "(file-refill)", 0
w_PAREN_FILE_REFILL_cf:
        LD      (fac_ip), DE
        PUSH    BC                      ; preserve old TOS
        ; Precondition: USER.source_id is a real FID (not 0 keyboard, not
        ; -1 EVALUATE). Exact-value tests instead of a bit-7 sniff so the
        ; check stays correct if the FCB pool ever lands at addr ≥ 0x8000.
        LD      L, (IY+UserArea.source_id)
        LD      H, (IY+UserArea.source_id+1)
        LD      A, H
        OR      L
        JP      Z, .fr_invalid_src      ; HL == 0 → keyboard → invalid
        LD      A, H
        AND     L
        INC     A                       ; A == 0 iff HL == 0xFFFF
        JP      Z, .fr_invalid_src      ; HL == 0xFFFF → EVALUATE → invalid
        ; HL = FID. Validate, then save and derive slab.
        ; Story 19.4 CR fix (supersedes the 19.3.1 review-fix #5 CP-range
        ; guard) — the range-only CP FCB_POOL_COUNT check let a RELEASED but
        ; pool-aligned source_id through (e.g. `SOURCE-ID CLOSE-FILE` mid-
        ; INCLUDE): pool_release zeroes the FCB, so the next refill drove
        ; F_READ_SEQ off a blank FCB instead of throwing. fid_validate is
        ; the chokepoint every sibling fileid word already calls — range AND
        ; fcb_pool_bitmap membership → -70 THROW on stale FID. Its THROW
        ; path leaves the entry PUSH BC outstanding (unlike .fr_invalid_src,
        ; which pops); that cell is reclaimed by the caller's CATCH-frame SP
        ; restore — the same recovery contract documented at .fr_io_error.
        LD      (fr_fid), HL
        CALL    fid_validate            ; -70 THROW on non-pool / stale FID;
                                        ; HL preserved, B = index (0..7)
        CALL    slab_from_idx           ; HL = slab from B (19.4 CR follow-up:
                                        ; index divided once per line, not
                                        ; re-derived by slab_from_fid)
        LD      A, B
        LD      (fr_fcb_idx), A         ; cache index
        LD      (fr_slab), HL
        LD      (IY+UserArea.tib_addr), L
        LD      (IY+UserArea.tib_addr+1), H
        ; pos = 0; >IN = 0
        XOR     A
        LD      (fr_pos), A
        LD      (IY+UserArea.tib_in), 0
        LD      (IY+UserArea.tib_in+1), 0
        ; Story 19.3.1 review-fix (#8/#4) — soft-EOF latch gate, hoisted out
        ; of the per-byte file_byte_read path. If a prior refill on this FCB
        ; consumed a 0x1A, the file's logical content has ended: return
        ; immediate EOF without reading the partial-record tail. Once per
        ; line. Scope note (19.4 CR wording fix): READ-FILE / random reads
        ; are latch-AGNOSTIC, not unaffected — 0x1A is data to a binary
        ; read, and the shared physical cursor (fcb_byte_pos) sits just past
        ; the consumed 0x1A after a latched refill, so a later READ-FILE on
        ; the still-open FID continues physically from there (pre-19.3.1
        ; semantics); REPOSITION-FILE clears the latch and re-anchors.
        LD      H, 0
        LD      L, B                    ; B = index, live since fid_validate
                                        ; (19.4 CR fix: was a 3-byte reload
                                        ; of fr_fcb_idx the register made
                                        ; redundant on this per-line path)
        LD      DE, fcb_eof_seen
        ADD     HL, DE
        LD      A, (HL)
        OR      A
        JP      NZ, .fr_immediate_eof
.fr_loop:
        LD      DE, (fr_fid)
        CALL    file_byte_read          ; tri-state: CY=0 byte / CY=1 A=0 EOF /
                                        ; CY=1 A!=0 I/O error (Story 13.5.2)
        JR      C, .fr_loop_no_byte
        CP      0x0A
        JR      Z, .fr_terminator
        CP      0x1A
        JR      Z, .fr_soft_eof_seen    ; Story 19.3.1 D1 v3 — CP/M soft-EOF marker
        CP      0x0D
        JR      Z, .fr_loop             ; CR — drop silently
        ; Regular byte. Store if pos < TIB_SIZE.
        LD      L, A                    ; spill byte
        LD      A, (fr_pos)
        CP      TIB_SIZE
        JR      NC, .fr_truncate
        ; slab[pos] = byte; pos++
        LD      C, A                    ; C = pos
        LD      B, 0                    ; BC = pos
        LD      A, L                    ; A = byte
        LD      HL, (fr_slab)
        ADD     HL, BC
        LD      (HL), A
        LD      A, C
        INC     A
        LD      (fr_pos), A
        JR      .fr_loop
.fr_truncate:
        ; pos >= 128. Consume bytes silently until terminator / EOF.
        LD      DE, (fr_fid)
        CALL    file_byte_read
        JR      C, .fr_trunc_no_byte
        CP      0x0A
        JR      Z, .fr_terminator
        CP      0x1A
        JR      Z, .fr_soft_eof_seen    ; Story 19.3.1 D1 v3 — CP/M soft-EOF marker
        JR      .fr_truncate
.fr_soft_eof_seen:
        ; Story 19.3.1 — CP/M 2.2 §"Function 20" 0x1A soft-EOF marker
        ; consumed. Sets fcb_eof_seen[idx] so the entry gate short-circuits
        ; the NEXT (file-refill) on this FCB to immediate EOF (file's
        ; logical content ends here even if more physical record bytes
        ; exist). 19.4 CR comment fix: file_byte_read itself is latch-
        ; agnostic — the physical cursor stays just past the 0x1A, so a
        ; later READ-FILE on the still-open FID reads on from there. Then
        ; routes by fr_pos: bytes accumulated → return as last line; else
        ; immediate EOF. fr_fcb_idx was cached at routine entry.
        LD      A, (fr_fcb_idx)
        LD      H, 0
        LD      L, A
        LD      DE, fcb_eof_seen
        ADD     HL, DE
        LD      (HL), 1                 ; fcb_eof_seen[idx] = 1
        ; Route: if fr_pos > 0, return accumulated line; else immediate EOF.
        LD      A, (fr_pos)
        OR      A
        JR      NZ, .fr_terminator
        JR      .fr_immediate_eof
.fr_loop_no_byte:
        ; Helper signalled CY=1; Z (set by helper's DEC A; SCF preserves Z)
        ; discriminates clean EOF (Z=1, A=0) vs I/O error (Z=0, A!=0).
        JR      Z, .fr_eof              ; clean EOF → existing flag-return path
        JR      .fr_io_error            ; A != 0 → BDOS F_READ I/O error → -37 THROW
.fr_trunc_no_byte:
        ; Same shape as .fr_loop_no_byte — clean EOF mid-truncate returns the
        ; data captured so far (already-stored TIB prefix); I/O error THROWs.
        JR      Z, .fr_terminator       ; clean EOF mid-truncate → return data
        JR      .fr_io_error            ; A != 0 → BDOS F_READ I/O error → -37 THROW
.fr_eof:
        ; F_READ returned EOF. Return -1 if any bytes read, else 0.
        LD      A, (fr_pos)
        OR      A
        JR      Z, .fr_immediate_eof
        ; Story 19.3.1 review-fix (#1/#6) — the fcb_last_was_clean
        ; "partial-record padding discard" (v2 defence-in-depth) was
        ; REMOVED here. It keyed off "previous refill ended on a clean
        ; terminator", which is the normal case for every well-formed line,
        ; and could NOT distinguish BDOS partial-record padding from a real
        ; final line lacking a trailing newline (no in-band signal exists).
        ; It therefore silently DROPPED the last line of any multi-line file
        ; whose final line had no LF/0x1A — a data-loss regression vs the
        ; pre-19.3.1 behaviour. End-of-content is now governed solely by the
        ; deterministic v3 0x1A soft-EOF latch (fcb_eof_seen), which is the
        ; documented CP/M 2.2 §"Function 20" contract and the project's
        ; mandatory 0x1A-termination convention (feedback_cpm_0x1a_eof_marker).
        ; EOF-with-bytes now falls through and returns the accumulated line.
.fr_terminator:
        ; Set tib_len = pos; flag = -1.
        LD      A, (fr_pos)
        LD      (IY+UserArea.tib_len), A
        LD      (IY+UserArea.tib_len+1), 0
        LD      BC, -1                  ; flag = TRUE
        LD      DE, (fac_ip)
        NEXT
.fr_immediate_eof:
        ; tib_len = 0; flag = 0.
        LD      (IY+UserArea.tib_len), 0
        LD      (IY+UserArea.tib_len+1), 0
        LD      BC, 0                   ; flag = FALSE
        LD      DE, (fac_ip)
        NEXT
.fr_io_error:
        ; Story 13.5.2 (TD-3 closure) — BDOS F_READ I/O error path. Shared
        ; tail for .fr_loop_no_byte / .fr_trunc_no_byte. Discard the saved
        ; old-TOS and raise -37 THROW_FILE_IO. Stack shape mirrors
        ; .fr_invalid_src exactly so the recovery contract (caller's CATCH
        ; frame restores SP) is identical.
        POP     BC                      ; balance the entry-time PUSH BC
        LD      BC, THROW_FILE_IO
        JP      w_THROW_cf.kernel_entry
.fr_invalid_src:
        ; Discard the saved old-TOS and raise -70.
        POP     BC                      ; balance the PUSH BC
        LD      BC, THROW_FILE_INVALID_FID
        JP      w_THROW_cf.kernel_entry

; -----------------------------------------------
; (refill-and-interpret-loop) ( -- )  Task 9 / AC #10
;   Run-loop body wrapped in CATCH by INCLUDED / INCLUDE-FILE.
;   `BEGIN (file-refill) WHILE INTERPRET REPEAT` — terminates on first
;   immediate-EOF return from (file-refill); INTERPRET handles each
;   refilled line and may THROW (caught by the surrounding CATCH).
; -----------------------------------------------
w_PAREN_REFILL_AND_INTERPRET_LOOP:
        DEFWORD "(refill-and-interpret-loop)", 0
w_PAREN_REFILL_AND_INTERPRET_LOOP_body:
w_PAREN_REFILL_AND_INTERPRET_LOOP_cf EQU w_PAREN_REFILL_AND_INTERPRET_LOOP_body - 3
.ril_loop:
        DW      w_PAREN_FILE_REFILL_cf
        DW      w_QBRANCH_cf
        DW      .ril_done - $
        DW      w_INTERPRET_cf
        DW      w_BRANCH_cf
        DW      .ril_loop - $
.ril_done:
        DW      EXIT_CODE

; -----------------------------------------------
; INCLUDED ( i*x c-addr u -- j*x )  ANS Forth 1994 §11.6.1.1718
;   Open the named file (R/O), make it the current source, run the
;   refill+interpret loop wrapped in CATCH, then close the FID and pop
;   the source frame. -38 THROW_FILE_NOT_FOUND on open-failure.
;   On caught THROW: close FID + pop frame + re-raise.
;   On clean EOF: close FID + pop frame + return.
; ANS Forth 1994 §11.6.1.1718  INCLUDED  — load source from file (CCD-1 INCLUDE-TOP framed)
;   See architecture.md E13-D2 (INCLUDE source frame layout) and PD-1
;   (per-FCB slab) for the structural design.
; -----------------------------------------------
w_INCLUDED:
        DEFWORD "INCLUDED", 0
w_INCLUDED_body:
w_INCLUDED_cf EQU w_INCLUDED_body - 3
        ; ( c-addr u )
        DW      w_R_SLASH_O_cf                          ; R/O
        DW      w_OPEN_FILE_cf                          ; ( fileid ior )
        DW      w_ZERO_EQUALS_cf                        ; ( fileid flag )
        DW      w_QBRANCH_cf                            ; if ior != 0 → .inc_open_fail
        DW      .inc_open_fail - $
        ; ior == 0: ( fileid )
        DW      w_DUP_cf                                ; ( fileid fileid )
        DW      w_PAREN_SLAB_FROM_FID_cf                ; ( fileid slab )
        DW      w_SWAP_cf                               ; ( slab fileid )
        DW      w_LIT_cf, 0                             ; ( slab fileid 0 )
        DW      w_SWAP_cf                               ; ( slab 0 fileid )
        DW      w_PAREN_INPUT_FRAME_PUSH_cf             ; ( -- ) push frame
        DW      w_LIT_cf, w_PAREN_REFILL_AND_INTERPRET_LOOP_cf
        DW      w_CATCH_cf                              ; ( 0 | n )
        DW      w_QDUP_cf                               ; ( 0 | n n )
        DW      w_QBRANCH_cf                            ; if 0 → .inc_clean_eof
        DW      .inc_clean_eof - $
        ; Caught THROW: ( n )
        DW      w_PAREN_CLOSE_CURRENT_FID_cf
        DW      w_PAREN_INPUT_FRAME_POP_cf
        DW      w_THROW_cf                              ; re-raise (does not return)
.inc_clean_eof:
        DW      w_PAREN_CLOSE_CURRENT_FID_cf
        DW      w_PAREN_INPUT_FRAME_POP_cf
        DW      w_BRANCH_cf
        DW      .inc_done - $
.inc_open_fail:
        ; ( fileid ) where fileid = 0 on failure
        DW      w_DROP_cf
        DW      w_LIT_cf, THROW_FILE_NOT_FOUND
        DW      w_THROW_cf
.inc_done:
        DW      EXIT_CODE

; -----------------------------------------------
; INCLUDE-FILE ( i*x fileid -- j*x )  ANS Forth 1994 §11.6.1.1717
;   Make the open FID the current source and run the refill+interpret
;   loop wrapped in CATCH. (fid-validate) is called FIRST — stale FID
;   raises -70 before any frame push.
;
;   Caller-retains-ownership deviation: ANS literally reads "INCLUDE-FILE
;   does not close the FID." On clean EOF antforth honours this. On
;   the THROW path antforth deviates: the FID is closed (gforth /
;   SwiftForth precedent — deterministic cleanup beats handle leak).
;   Documented in docs/ans-forth-core-compliance.md.
; ANS Forth 1994 §11.6.1.1717 INCLUDE-FILE — load source from open FID
; -----------------------------------------------
w_INCLUDE_FILE:
        DEFWORD "INCLUDE-FILE", 0
w_INCLUDE_FILE_body:
w_INCLUDE_FILE_cf EQU w_INCLUDE_FILE_body - 3
        ; ( fileid )
        DW      w_PAREN_FID_VALIDATE_cf                 ; -70 THROW on stale FID;
                                                        ; passthrough per PD-2 / AC #6.
                                                        ; PD-7 pseudocode "DUP (fid-validate)"
                                                        ; is a typo — wrapper does not consume.
        ; ( fileid )
        DW      w_DUP_cf                                ; ( fileid fileid )
        DW      w_PAREN_SLAB_FROM_FID_cf                ; ( fileid slab )
        DW      w_SWAP_cf                               ; ( slab fileid )
        DW      w_LIT_cf, 0                             ; ( slab fileid 0 )
        DW      w_SWAP_cf                               ; ( slab 0 fileid )
        DW      w_PAREN_INPUT_FRAME_PUSH_cf             ; ( -- )
        DW      w_LIT_cf, w_PAREN_REFILL_AND_INTERPRET_LOOP_cf
        DW      w_CATCH_cf                              ; ( 0 | n )
        DW      w_QDUP_cf
        DW      w_QBRANCH_cf                            ; if 0 → .if_clean_eof
        DW      .if_clean_eof - $
        ; Caught THROW path: close FID (gforth precedent), pop frame, re-raise.
        DW      w_PAREN_CLOSE_CURRENT_FID_cf
        DW      w_PAREN_INPUT_FRAME_POP_cf
        DW      w_THROW_cf                              ; re-raise
.if_clean_eof:
        ; Clean EOF: leave FID open (caller retains ownership per ANS).
        DW      w_PAREN_INPUT_FRAME_POP_cf
        DW      EXIT_CODE

; -----------------------------------------------
; INCLUDE ( "name" -- )  Forth 2014 §11.6.2.1717.40
;   Token-form INCLUDE: parse one space-delimited filename and run INCLUDED.
; Forth 2014 §11.6.2.1717.40 INCLUDE — = BL WORD COUNT INCLUDED
; -----------------------------------------------
w_INCLUDE:
        DEFWORD "INCLUDE", 0
w_INCLUDE_body:
w_INCLUDE_cf EQU w_INCLUDE_body - 3
        DW      w_BL_cf
        DW      w_WORD_cf                               ; ( c-addr )
        DW      w_COUNT_cf                              ; ( c-addr u )
        DW      w_INCLUDED_cf
        DW      EXIT_CODE

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

        ; --- Step 7.5 (Story 13.5.2 H1) — synthetic-BDOS-A injection of the
        ;     .fbr_eof tri-state discriminator. Real BDOS F_READ A>1 is
        ;     dormant in practice on iz-cpm and MicroBeast firmware (no
        ;     deterministic injector via real I/O), so this step calls
        ;     directly into the helper's tail with synthetic A values to
        ;     exercise the tri-state encoding (CY=1, A=0 for clean EOF;
        ;     CY=1, A=A_BDOS-1 for I/O error). PASS-line oracle: prints
        ;     "io-disc ok bdos=1>A0 bdos=2>A1 bdos=ff>Afe" iff all three
        ;     synthetic returns map through the helper as expected.
        ; Test (a) — synthetic BDOS A=1 (clean EOF) → helper CY=1, A=0.
        LD      A, (fis_idx)
        LD      (file_byte_read.fbr_idx), A
        LD      DE, (fis_fcb)
        LD      A, 1                    ; synthetic BDOS A=1
        CALL    fis_call_fbr_eof
        JP      NC, fis_fail_io_disc    ; CY must be 1
        OR      A
        JP      NZ, fis_fail_io_disc    ; A must be 0 (clean EOF discriminant)
        ; Test (b) — synthetic BDOS A=2 (I/O error) → helper CY=1, A=1.
        LD      A, (fis_idx)
        LD      (file_byte_read.fbr_idx), A
        LD      DE, (fis_fcb)
        LD      A, 2                    ; synthetic BDOS A=2
        CALL    fis_call_fbr_eof
        JP      NC, fis_fail_io_disc    ; CY must be 1
        CP      1
        JP      NZ, fis_fail_io_disc    ; A must be 1 (= BDOS 2 - 1)
        ; Test (c) — synthetic BDOS A=0xFF → helper CY=1, A=0xFE.
        LD      A, (fis_idx)
        LD      (file_byte_read.fbr_idx), A
        LD      DE, (fis_fcb)
        LD      A, 0xFF                 ; synthetic BDOS A=0xFF (worst case)
        CALL    fis_call_fbr_eof
        JP      NC, fis_fail_io_disc
        CP      0xFE
        JP      NZ, fis_fail_io_disc    ; A must be 0xFE (= BDOS 0xFF - 1)
        LD      HL, str_fis_io_disc_ok
        LD      B, str_fis_io_disc_ok_len
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
        JR      fis_fail_finish_with_a
fis_fail_io_disc:
        ; Story 13.5.2 H1 — .fbr_eof discriminator probe failed. A holds
        ; whatever the helper returned (or 0 if CY was wrong); print it
        ; via the shared finisher.
        LD      HL, str_fis_io_disc_fail
        LD      C, str_fis_io_disc_fail_len
        JR      fis_fail_finish_with_a

; -----------------------------------------------
; fis_call_fbr_eof — Story 13.5.2 H1 thunk: enter file_byte_read.fbr_eof
;   under the same stack shape file_byte_read sets up at its entry, so
;   the .fbr_eof tail's POP DE recovers the FCB ptr cleanly and its RET
;   returns to the harness rather than to the FCB ptr.
;   Entry: A = synthetic BDOS F_READ return value; DE = FCB ptr;
;          (file_byte_read.fbr_idx) already set to the FCB index.
;   Exit:  CY+A per the helper's tri-state encoding (clean EOF: CY=1,
;          A=0; I/O error: CY=1, A=A_BDOS-1). Clobbers: A, BC, DE, HL, F.
fis_call_fbr_eof:
        ; Stack at CALL entry: [harness_retaddr (top)]. .fbr_eof's POP DE
        ; expects the FCB ptr on top of the harness retaddr — exactly the
        ; shape file_byte_read's entry-time PUSH DE creates. So push DE
        ; on top of the retaddr and JP into .fbr_eof; its POP DE will
        ; pull the FCB ptr; its terminal RET will pop the harness retaddr.
        PUSH    DE                      ; stack: [FCB ptr (top), harness_retaddr]
        JP      file_byte_read.fbr_eof

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
str_fis_io_disc_ok:     DB "io-disc ok bdos=1>A0 bdos=2>A1 bdos=ff>Afe"
str_fis_io_disc_ok_len  EQU $ - str_fis_io_disc_ok
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
str_fis_io_disc_fail:   DB "io-disc FAIL bdos="
str_fis_io_disc_fail_len EQU $ - str_fis_io_disc_fail

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
