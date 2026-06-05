; constants.asm — Memory layout equates and system constants
; AntForth — A Forth for CP/M on Z80

; === CP/M System Addresses ===
BDOS_ENTRY      EQU     0x0005          ; BDOS entry point
BDOS_ADDR_PTR   EQU     0x0006          ; Word containing BDOS base address
TPA_START       EQU     0x0100          ; .COM entry point / start of TPA

; === Phase-4 Banking (Story 17.1) ===
; bank-table[] base in the reclaimed CCP region $D400-$DBFF (2 KB).
; PD-P4-6 closure (architecture.md:282) chose option (c) — CCP eviction
; for Phase-4 banking infrastructure; Story 16.1 verified safe on real
; MicroBeast hardware (transcript ~/Downloads/beastty-20260513-110640.bin;
; BIOS reloads CCP from disk on warm-boot). Per-bank `(here, latest,
; wordlist_head)` triple table (Story 17.1) and descriptor-stub allocator
; (Story 18.1) both consume this region; see docs/antforth-banking-redesign.md §5.2.
BANK_TABLE_BASE EQU     0xD400

; === Phase-4 Descriptor-stub allocator base (Story 18.1) ===
; Output region for the descriptor-stub allocator (src/banking.asm).
; Sits immediately after active_pages[] in the reclaimed $D400-$DBFF
; CCP region. PD-P4-11 (architecture.md:347..365) pins the per-stub
; size at 4 B — layout v2 per ADR 19.5 DR-2 (Story 19.5.2): byte 0 =
; $EF (RST $28, self-dispatch); byte 1 = signed target_bank (-1 =
; fixed-memory marker; 0..28 = active bank index); bytes 2..3 =
; target_addr lo/hi. Stub address IS the word's xt per PD-P4-1 +
; redesign §2.1.
; ACTIVE_PAGES_BASE + ACTIVE_PAGES_SIZE are defined in src/banking.asm.
STUB_ALLOC_BASE EQU     ACTIVE_PAGES_BASE + ACTIVE_PAGES_SIZE  ; $D4CB

; === Phase-4 RST-$28 stub-dispatch vector (Story 19.5.2, ADR 19.5 DR-2) ===
; Zero-page RST vector claimed for descriptor-stub self-dispatch. The
; stub's byte 0 ($EF = RST $28) transfers here; COLD installs
; `JP stub_dispatch` (src/banking.asm) at this address. Zero page is
; RAM under CP/M; BIOS IM-1 uses $0038; iz-cpm intercepts only
; $0000/$0005 (ADR assumption A2 — emulator-verified Story 19.5.2,
; hardware-verified at 19.5.4). Contingency per AC10: if the 19.5.4 HW
; pass finds $0028 occupied, re-vector to $0008/$0010/$0018/$0020 by
; editing this one EQU plus the RST opcode byte in stub_allocate
; ($EF = RST $28; $CF/$D7/$DF/$E7 = RST $08/$10/$18/$20).
STUB_DISPATCH_VECTOR EQU 0x0028

; === Phase-4 MMU slot-2 portal window base (Story 19.5.2 CR pass) ===
; The MMU slot-2 window is $8000..$BFFF (16 KiB; ports 0x70-0x73 select
; the page per slot — redesign §5.1/§5.2; geometry is fixed MicroBeast
; silicon). Single edit point for the window-geometry literals: the F1
; window guard's high-byte compare (src/banking.asm w_BANK_STORE_cf),
; the bank-N HERE COLD-init high byte (src/antforth.asm), and the
; +BANK candidate-page probe address (src/banking.asm cl_probe_and_add)
; all derive from this EQU — parallel to STUB_DISPATCH_VECTOR's
; single-EQU re-vector contingency above.
SLOT2_WINDOW_BASE EQU 0x8000

; === BDOS Function Numbers ===
P_TERMCPM       EQU     0               ; BDOS function 0: terminate program
C_READ          EQU     1               ; BDOS function 1: console input (blocking, echoes)
C_WRITE         EQU     2               ; BDOS function 2: console output (E = char)
C_STATUS        EQU     11              ; BDOS function 11: console status (non-blocking)
C_READSTR       EQU     10              ; BDOS function 10: read console buffer

; --- File-access subset (Story 13.1) — NFR13 BDOS allow-list (epics.md:1483) ---
; Every CALL BDOS_ENTRY site in src/file_access.asm cites the function
; number either via the `LD C, F_<NAME>` setup or via a comment beside
; the wrapper helper (CCD-3 / NFR17, architecture.md:472).
F_OPEN          EQU     15              ; BDOS function 15: open file (DE = FCB ptr)
F_CLOSE         EQU     16              ; BDOS function 16: close file (DE = FCB ptr)
F_DELETE        EQU     19              ; BDOS function 19: delete file (DE = FCB ptr)
F_READ          EQU     20              ; BDOS function 20: read sequential record into DMA
F_WRITE         EQU     21              ; BDOS function 21: write sequential record from DMA
F_MAKE          EQU     22              ; BDOS function 22: create file / directory entry
DRV_GET         EQU     25              ; BDOS function 25: return current default drive
F_DMAOFF        EQU     26              ; BDOS function 26: set DMA buffer address
F_READRAND      EQU     33              ; BDOS function 33: random-record read (DE = FCB)
F_WRITERAND     EQU     34              ; BDOS function 34: random-record write (DE = FCB)
F_SIZE          EQU     35              ; BDOS function 35: compute file size into r0/r1/r2

; === Stack Sizes ===
PS_SIZE         EQU     256             ; Parameter stack: 128 cells (256 bytes)
RS_SIZE         EQU     256             ; Return stack: 128 cells (256 bytes)

; === Dictionary ===
; HASH_BUCKETS retired in Story 12.1 (AC #5(d)(i)) — single source of truth
; is now WORDLIST_BUCKETS in src/wordlists.asm.

; === Text Input Buffer ===
TIB_SIZE        EQU     128             ; TIB size in bytes

; === PAD ===
PAD_OFFSET      EQU     84              ; PAD is 84 bytes above HERE

; === Number Formatting Buffer ===
NUM_BUF_SIZE    EQU     18              ; Max 16 binary digits + sign + safety

; === Pictured Numeric Output Buffer ===
; Per architecture decision E10-D2 (architecture.md:254-258): 40 bytes in
; UserArea, IY-relative, addressed via USER variable HLD. Sized to cover
; the 32-digit base-2 double-cell worst case plus sign plus decorators.
PIC_BUF_SIZE    EQU     40

; === Dictionary Entry Flags ===
F_IMMEDIATE     EQU     0x80            ; Bit 7: IMMEDIATE flag
F_SMUDGE        EQU     0x40            ; Bit 6: SMUDGE flag (hidden)
F_HAS_STUB_XT_CELL EQU  0x20            ; Bit 5: Story 19.2 (Q1-α): entry has a 2-byte
                                        ; stub-xt cell between name and CFA. Set on every
                                        ; runtime-built entry by build_header; cleared on
                                        ; kernel-assembled DEFCODE/DEFWORD entries (which
                                        ; keep the legacy post-name = CFA layout to avoid
                                        ; +2 B per kernel word ≈ +740 B that would blow
                                        ; the AC9 80-B envelope). FIND's match-success
                                        ; exit at src/dictionary.asm reads the cell only
                                        ; when this bit is set. F_LENMASK below masks
                                        ; bits 5-7, so length-extraction paths in
                                        ; src/dictionary.asm + src/strings.asm are
                                        ; unaffected.
F_LENMASK       EQU     0x1F            ; Bits 0-4: name length (max 31)

; === ANS THROW Codes ===
; Per CCD-2 (architecture.md:193-204): codes -1..-58 reserved for ANS
; standard, -59..-255 reserved for future ANS extensions, -256..-32767 for
; antforth extensions. Per CCD-3 / NFR17, every EQU carries a one-line
; citation. Declared upfront for Stories 11.2-11.7 to reference; not all
; are referenced by the kernel today.

; --- Standard codes (ANS Forth 1994 §9.3.5) used by Epic 11 migrations ---
; Citation form: project-wide convention is `ANS Forth 1994 §<sec>` for §6,
; §8, §9 codes (matches existing src/*.asm DEFCODE/DEFWORD comments and
; CCD-3's example for §6 — architecture.md:208-214). The architecture spec's
; THROW EQU example at architecture.md:476-478 uses `Forth 2014`; that
; example diverges from CCD-3's stated convention and from the rest of the
; codebase. See docs/throw-codes.md §a for the reconciliation note.
THROW_ABORT             EQU -1   ; ANS Forth 1994 §9.3.5
THROW_ABORT_QUOTE       EQU -2   ; ANS Forth 1994 §9.3.5
THROW_STACK_OVERFLOW    EQU -3   ; ANS Forth 1994 §9.3.5
THROW_STACK_UNDERFLOW   EQU -4   ; ANS Forth 1994 §9.3.5
THROW_DIV_BY_ZERO       EQU -10  ; ANS Forth 1994 §9.3.5
THROW_UNDEFINED_WORD    EQU -13  ; ANS Forth 1994 §9.3.5
THROW_COMPILE_ONLY      EQU -14  ; ANS Forth 1994 §9.3.5
THROW_ZERO_LEN_NAME     EQU -16  ; ANS Forth 1994 §9.3.5
THROW_PIC_OVERFLOW      EQU -17  ; ANS Forth 1994 §9.3.5
THROW_CONTROL_MISMATCH  EQU -22  ; ANS Forth 1994 §9.3.5
THROW_SEARCH_ORDER_OVERFLOW EQU -49  ; ANS Forth 1994 §9.3.5 (search-order overflow; Story 12.3 SET-ORDER bounds check)
THROW_END_OF_INPUT      EQU -58  ; ANS Forth 1994 §9.3.5

; --- File-Access codes (ANS Forth 1994 §9.3.5) — Story 13.4 v2 allocation ---
; -37 raised by (file-refill) on F_READ I/O error (Story 13.5.2 closure
;   2026-05-05; previously latent — file_byte_read now signals tri-state
;   CY+A so the consumer can distinguish clean EOF from real I/O error
;   and raise -37 on the latter).
; -38 raised by INCLUDED when OPEN-FILE returns non-zero ior.
THROW_FILE_IO           EQU -37  ; ANS Forth 1994 §9.3.5
THROW_FILE_NOT_FOUND    EQU -38  ; ANS Forth 1994 §9.3.5

; --- Architecture-mandated example EQUs (architecture.md:476-478) ---
; Declared upfront per the design-upfront feedback rule even though no
; Epic 11 migration references them. THROW_FCB_EXHAUSTED lands first in
; Epic 13 (File-Access); THROW_ASM_LOAD_FAIL is reserved for the
; lazy-load assembler also in Epic 13.
THROW_FCB_EXHAUSTED     EQU -69  ; ANS Forth 1994 §9.3.5 (post-1994 extension; Forth 2014 retains)
; antforth re-purposing of Forth 2014 §9.3.5 reserved code -70 (originally
; FREE/memory deallocator in Forth 2014). antforth has no separate FREE
; wordset and re-uses -70 for the file-access invalid-FID condition
; (closer in spirit to a use-after-free than to memory FREE). See
; docs/throw-codes.md §b.1 for the rationale and Story 13.2 AC #8 for the
; allocation history.
THROW_FILE_INVALID_FID  EQU -70  ; antforth extension — see docs/throw-codes.md §b.1 (Story 13.2)

; --- antforth extensions: assembler-error codes (-258..-272) ---
; (Story 19.5.1: the antforth-extension series is no longer assembler-
; only — it continues past -272 with banking-error codes; see the
; -273 block below.)
; Allocated as one contiguous block for grep-ability; one code per error
; entry point in src/assembler.asm. The block starts at -258 (not -256)
; to leave -256 reserved for future use and -257 reserved for
; architecture-mandated THROW_ASM_LOAD_FAIL (architecture.md:478,606).
; The block extends to -272 post-Story 11.5.6: Story 11.6 added -270 /
; -271 for the asm_die residual (check_asm_mode plus the +D / bit-op
; range guards, both originally raising the generic -271 "range"); Story
; 11.5.6 split the original -271 into -271 disp range / -272 bit range
; — see this file's THROW_ASM_DISP_RANGE / THROW_ASM_BIT_RANGE entries
; and _bmad-output/implementation-artifacts/11.5-6-throw-271-semantic-split.md.
; See docs/throw-codes.md §c.
THROW_ASM_LOAD_FAIL         EQU -257 ; antforth extension — see docs/throw-codes.md
THROW_ASM_BAD_OPERAND       EQU -258 ; antforth extension — see docs/throw-codes.md
THROW_ASM_NESTED            EQU -259 ; antforth extension — see docs/throw-codes.md
THROW_ASM_NONAME            EQU -260 ; antforth extension — see docs/throw-codes.md
THROW_ASM_ORPHAN_LABEL      EQU -261 ; antforth extension — see docs/throw-codes.md
THROW_ASM_LABEL_AFTER_END   EQU -262 ; antforth extension — see docs/throw-codes.md
THROW_ASM_JR_RANGE          EQU -263 ; antforth extension — see docs/throw-codes.md
THROW_ASM_TOO_LABELS        EQU -264 ; antforth extension — see docs/throw-codes.md
THROW_ASM_TOO_FIXUPS        EQU -265 ; antforth extension — see docs/throw-codes.md
THROW_ASM_EQU_IN_CODE       EQU -266 ; antforth extension — see docs/throw-codes.md
THROW_ASM_BARE_INT          EQU -267 ; antforth extension — see docs/throw-codes.md
THROW_ASM_UNRESOLVED        EQU -268 ; antforth extension — see docs/throw-codes.md
THROW_ASM_ALREADY_FIXED     EQU -269 ; antforth extension — see docs/throw-codes.md
THROW_ASM_NOT_IN_CODE       EQU -270 ; antforth extension — see docs/throw-codes.md
THROW_ASM_DISP_RANGE        EQU -271 ; antforth extension — see docs/throw-codes.md
THROW_ASM_BIT_RANGE         EQU -272 ; antforth extension — see docs/throw-codes.md

; --- antforth extensions: banking-error codes (-273..) ---
; Continues the contiguous antforth-extension series past the assembler
; block. Story 19.5.1 (ADR 19.5 DR-1 fix F1): BANK! raises -273 when a
; foreign-bank switch is attempted from window-resident code (caller IP
; in $8000..$BFFF) — converting the portal-aliasing corruption class
; into a catchable THROW. Raised from banking.asm w_BANK_STORE_cf via
; the kernel-internal w_THROW_cf.kernel_entry path.
THROW_BANK_FROM_BANKED      EQU -273 ; antforth extension — see docs/throw-codes.md (Story 19.5.1)
