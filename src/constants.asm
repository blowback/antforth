; constants.asm — Memory layout equates and system constants
; AntForth — A Forth for CP/M on Z80

; === CP/M System Addresses ===
BDOS_ENTRY      EQU     0x0005          ; BDOS entry point
BDOS_ADDR_PTR   EQU     0x0006          ; Word containing BDOS base address
TPA_START       EQU     0x0100          ; .COM entry point / start of TPA

; === Phase-4 Banking ===
; bank-table[] base in the reclaimed CCP region $D400-$DBFF (2 KB).
; Chose CCP eviction for Phase-4 banking infrastructure; verified safe on
; real MicroBeast hardware (BIOS reloads CCP from disk on warm-boot).
; Per-bank `(here, latest, wordlist_head)` triple table and descriptor-stub
; allocator both consume this region.
BANK_TABLE_BASE EQU     0xD400

; === Phase-4 Descriptor-stub allocator base ===
; Output region for the descriptor-stub allocator (src/banking.asm).
; Sits immediately after active_pages[] in the reclaimed $D400-$DBFF
; CCP region. Per-stub size is 4 B — layout v2 per ADR 19.5 DR-2: byte 0 =
; $EF (RST $28, self-dispatch); byte 1 = signed target_bank (-1 =
; fixed-memory marker; 0..28 = active bank index); bytes 2..3 =
; target_addr lo/hi. Stub address IS the word's xt.
; ACTIVE_PAGES_BASE + ACTIVE_PAGES_SIZE are defined in src/banking.asm.
STUB_ALLOC_BASE EQU     ACTIVE_PAGES_BASE + ACTIVE_PAGES_SIZE  ; $D4CB

; === Phase-4 RST-$28 stub-dispatch vector (ADR 19.5 DR-2) ===
; Zero-page RST vector claimed for descriptor-stub self-dispatch. The
; stub's byte 0 ($EF = RST $28) transfers here; COLD installs
; `JP stub_dispatch` (src/banking.asm) at this address. Zero page is
; RAM under CP/M; BIOS IM-1 uses $0038; iz-cpm intercepts only
; $0000/$0005 (emulator- and hardware-verified). Contingency: if $0028 is
; occupied, re-vector to $0008/$0010/$0018/$0020 by editing this one EQU
; plus the RST opcode byte in stub_allocate
; ($EF = RST $28; $CF/$D7/$DF/$E7 = RST $08/$10/$18/$20).
STUB_DISPATCH_VECTOR EQU 0x0028

; === Phase-4 MMU slot-2 portal window base ===
; The MMU slot-2 window is $8000..$BFFF (16 KiB; ports 0x70-0x73 select
; the page per slot; geometry is fixed MicroBeast silicon). Single edit
; point for the window-geometry literals: the F1
; window guard's high-byte compare (src/banking.asm w_BANK_STORE_cf),
; the bank-N HERE COLD-init high byte (src/antforth.asm), and the
; +BANK candidate-page probe address (src/banking.asm cl_probe_and_add)
; all derive from this EQU — parallel to STUB_DISPATCH_VECTOR's
; single-EQU re-vector contingency above.
SLOT2_WINDOW_BASE EQU 0x8000

; === MicroBeast BIOS page-mapping routines (blessed slot accessors) ===
; The page registers (ports 0x70-0x73) are write-only; the BIOS owns the
; authoritative page shadow and re-pages logical pages itself (e.g. during
; disk ops), so all page switching MUST go through these, never raw OUT/IN.
; Both clobber A, B, C, H, L, F and preserve DE, IX, IY (verified against
; MicroBeast firmware beastos/bios.asm get_page_mapping/set_page_mapping).
; antforth wraps them as mbb_set_slot2 / mbb_get_slot2 (src/banking.asm),
; which preserve the inner-interpreter registers (BC=TOS, DE=IP, HL).
MBB_GET_PAGE    EQU     0xFDDC          ; C = logical page 0-2 -> A = physical (0xFF err)
MBB_SET_PAGE    EQU     0xFDDF          ; A = logical page 0-2, E = physical page
; User-interrupt install vector: HL = ISR address (0 disables). Fires the
; routine 64 Hz — NOT the "60th of a second" the firmware header wrongly claims
; (see src/timer.asm). The slot holds a single user routine at a time.
MBB_SET_USR_INT EQU     0xFDC7          ; HL = ISR addr (0 = disable); 64 Hz

; === BDOS Function Numbers ===
P_TERMCPM       EQU     0               ; BDOS function 0: terminate program
C_READ          EQU     1               ; BDOS function 1: console input (blocking, echoes)
C_WRITE         EQU     2               ; BDOS function 2: console output (E = char)
C_STATUS        EQU     11              ; BDOS function 11: console status (non-blocking)
C_READSTR       EQU     10              ; BDOS function 10: read console buffer

; --- File-access subset — BDOS allow-list ---
; Every CALL BDOS_ENTRY site in src/file_access.asm cites the function
; number either via the `LD C, F_<NAME>` setup or via a comment beside
; the wrapper helper.
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
; Red-zone reserved above sp_base. A stack underflow can over-pop past sp_base
; (>R is intentionally unguarded) and the next primitive's check_underflow CALL
; then pushes a return address ABOVE sp_base before the underflow is caught.
; This gap keeps that transient inside antforth's own arena instead of clobbering
; the byte at top-of-TPA (the BDOS entry / warm-boot vector).
SP_GUARD        EQU     8

; === Phase-6 Multitasker — TCB field offsets & status enum ===
; A Task Control Block (TCB) is a fixed-memory record (always below $8000). TASK
; carves one per background task from the bank-0 dictionary; the operator (task
; 0) is a static header-only record (operator_tcb, src/multitasker.asm). PAUSE
; saves the running task's {SP,IX,DE,BC} plus the per-task UserArea subset
; {catch_top,current_bank,base} into its TCB and restores the next AWAKE task's.
; Fields are addressed by these named offsets, never by magic number. The
; doc-STRUCT in src/structures.asm mirrors this table and ASSERTs each offset
; against these EQUs, so the two representations cannot drift.
TCB_LINK        EQU 0           ; next TCB in the circular ring (2)
TCB_STATUS      EQU 2           ; TASK_AWAKE / TASK_ASLEEP / TASK_SUSPENDED (1)
TCB_SP          EQU 3           ; saved data-stack pointer (2)
TCB_IX          EQU 5           ; saved return-stack pointer (2)
TCB_DE          EQU 7           ; saved IP / resume-thread address (2)
TCB_BC          EQU 9           ; saved TOS (2)
TCB_CATCH       EQU 11          ; per-task CATCH-TOP (2)
TCB_BANK        EQU 13          ; per-task current_bank (2; re-paged in 25.5)
TCB_BASE        EQU 15          ; per-task BASE (2)
TCB_SPBASE      EQU 17          ; per-task data-stack base (2). PAUSE swaps the global sp_base
                                ; cell to this so check_overflow/check_underflow/DEPTH measure
                                ; against the RUNNING task's private ps_area, not the operator's.
                                ; (rp_base stays global — only operator-run QUIT uses it.)
TCB_THREAD      EQU 19          ; resume thread [xt | epilogue_cf] (4)
TCB_HDR_SIZE    EQU 23          ; header size (link .. t_thread end)
TCB_PS          EQU TCB_HDR_SIZE        ; private parameter-stack area (PS_SIZE)
TCB_RS          EQU TCB_PS + PS_SIZE    ; private return-stack area (RS_SIZE)
TCB_SIZE        EQU TCB_RS + RS_SIZE    ; full dictionary-allocated task footprint
; Status enum. SUSPENDED is reserved now (used by Story 25.6) so the PAUSE walk's
; "skip non-AWAKE" test is final from the start.
TASK_ASLEEP     EQU 0
TASK_AWAKE      EQU 1
TASK_SUSPENDED  EQU 2

; === Dictionary ===
; HASH_BUCKETS retired — single source of truth is now WORDLIST_BUCKETS
; in src/wordlists.asm.

; === Text Input Buffer ===
TIB_SIZE        EQU     128             ; TIB size in bytes

; === PAD ===
PAD_OFFSET      EQU     84              ; PAD is 84 bytes above HERE

; === Number Formatting Buffer ===
NUM_BUF_SIZE    EQU     18              ; Max 16 binary digits + sign + safety

; === Pictured Numeric Output Buffer ===
; 40 bytes in UserArea, IY-relative, addressed via USER variable HLD.
; Sized to cover the 32-digit base-2 double-cell worst case plus sign
; plus decorators.
PIC_BUF_SIZE    EQU     40

; === Dictionary Entry Flags ===
F_IMMEDIATE     EQU     0x80            ; Bit 7: IMMEDIATE flag
F_SMUDGE        EQU     0x40            ; Bit 6: SMUDGE flag (hidden)
F_HAS_STUB_XT_CELL EQU  0x20            ; Bit 5: entry has a 2-byte
                                        ; stub-xt cell between name and CFA. Set on every
                                        ; runtime-built entry by build_header; cleared on
                                        ; kernel-assembled DEFCODE/DEFWORD entries (which
                                        ; keep the legacy post-name = CFA layout to avoid
                                        ; +2 B per kernel word). FIND's match-success
                                        ; exit at src/dictionary.asm reads the cell only
                                        ; when this bit is set. F_LENMASK below masks
                                        ; bits 5-7, so length-extraction paths in
                                        ; src/dictionary.asm + src/strings.asm are
                                        ; unaffected.
F_LENMASK       EQU     0x1F            ; Bits 0-4: name length (max 31)

; === Dictionary code-field reserve (banked window-top guard) ===
; build_header's window-top guard reserves, beyond the header (6 B) + name,
; a code-field+body allowance via the bh_code_reserve cell. DOER_RESERVE is
; the default: the largest fixed code field among the doers (CREATE/CONSTANT/
; VALUE emit JP doer (3) + 2-byte body; `:` emits JP DOCOL (3) and grows its
; body later under the ,/COMPILE, guard), so 5 covers every ordinary caller.
DOER_RESERVE        EQU 5
; MARKER is the exception: it emits a large fixed body after the code field
; (JP DOMARKER (3) + saved FORTH-WORDLIST bucket array (192) + snap_count (1) +
; live bank-table prefix (snap_count*6, worst case BANK_TABLE_CAP=29 → 174) +
; stub-allocator tail (2)). w_MARKER_cf raises bh_code_reserve to this before
; build_header so the single pre-commit guard covers MARKER's whole footprint
; (all-or-nothing — the 192-byte body is emitted AFTER build_header commits the
; header, so a body-time guard could not unwind it). 3+192+1+174+2 = 372.
MARKER_CODE_RESERVE EQU 3 + 192 + 1 + (29 * 6) + 2     ; 372

; === ANS THROW Codes ===
; Codes -1..-58 reserved for ANS standard, -59..-255 reserved for future
; ANS extensions, -256..-32767 for antforth extensions. Every EQU carries
; a one-line citation. Not all are referenced by the kernel today.

; --- Standard codes (ANS Forth 1994 §9.3.5) ---
; Citation form: project-wide convention is `ANS Forth 1994 §<sec>` for §6,
; §8, §9 codes (matches existing src/*.asm DEFCODE/DEFWORD comments).
; See docs/throw-codes.md for the reconciliation note.
THROW_ABORT             EQU -1   ; ANS Forth 1994 §9.3.5
THROW_ABORT_QUOTE       EQU -2   ; ANS Forth 1994 §9.3.5
THROW_STACK_OVERFLOW    EQU -3   ; ANS Forth 1994 §9.3.5
THROW_STACK_UNDERFLOW   EQU -4   ; ANS Forth 1994 §9.3.5
THROW_DICT_OVERFLOW     EQU -8   ; ANS Forth 1994 §9.3.5 (dictionary overflow; banked window-top guard, Story 23.6)
THROW_DIV_BY_ZERO       EQU -10  ; ANS Forth 1994 §9.3.5
THROW_UNDEFINED_WORD    EQU -13  ; ANS Forth 1994 §9.3.5
THROW_COMPILE_ONLY      EQU -14  ; ANS Forth 1994 §9.3.5
THROW_ZERO_LEN_NAME     EQU -16  ; ANS Forth 1994 §9.3.5
THROW_PIC_OVERFLOW      EQU -17  ; ANS Forth 1994 §9.3.5
THROW_CONTROL_MISMATCH  EQU -22  ; ANS Forth 1994 §9.3.5
THROW_INVALID_NAME_ARG  EQU -32  ; ANS Forth 1994 §9.3.5 (invalid name argument, e.g. TO xxx)
THROW_SEARCH_ORDER_OVERFLOW EQU -49  ; ANS Forth 1994 §9.3.5 (search-order overflow; SET-ORDER bounds check)
THROW_END_OF_INPUT      EQU -58  ; ANS Forth 1994 §9.3.5

; --- File-Access codes (ANS Forth 1994 §9.3.5) ---
; -37 raised by (file-refill) on F_READ I/O error — file_byte_read signals
;   tri-state CY+A so the consumer can distinguish clean EOF from real I/O
;   error and raise -37 on the latter.
; -38 raised by INCLUDED when OPEN-FILE returns non-zero ior.
THROW_FILE_IO           EQU -37  ; ANS Forth 1994 §9.3.5
THROW_FILE_NOT_FOUND    EQU -38  ; ANS Forth 1994 §9.3.5

; --- Architecture-mandated example EQUs ---
; Declared upfront per the design-upfront rule. THROW_FCB_EXHAUSTED is used
; by File-Access; THROW_ASM_LOAD_FAIL is reserved for the lazy-load
; assembler.
THROW_FCB_EXHAUSTED     EQU -69  ; ANS Forth 1994 §9.3.5 (post-1994 extension; Forth 2014 retains)
; antforth re-purposing of Forth 2014 §9.3.5 reserved code -70 (originally
; FREE/memory deallocator in Forth 2014). antforth has no separate FREE
; wordset and re-uses -70 for the file-access invalid-FID condition
; (closer in spirit to a use-after-free than to memory FREE). See
; docs/throw-codes.md for the rationale and allocation history.
THROW_FILE_INVALID_FID  EQU -70  ; antforth extension — see docs/throw-codes.md

; --- antforth extensions: assembler-error codes (-258..-272) ---
; The antforth-extension series is not assembler-only — it continues past
; -272 with banking-error codes; see the -273 block below.
; Allocated as one contiguous block for grep-ability; one code per error
; entry point in src/assembler.asm. The block starts at -258 (not -256)
; to leave -256 reserved for future use and -257 reserved for
; architecture-mandated THROW_ASM_LOAD_FAIL. -271/-272 split the original
; generic -271 "range" into -271 disp range / -272 bit range — see this
; file's THROW_ASM_DISP_RANGE / THROW_ASM_BIT_RANGE entries.
; See docs/throw-codes.md.
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
; block. ADR 19.5 DR-1 fix F1: BANK! raises -273 when a foreign-bank
; switch is attempted from window-resident code (caller IP in
; $8000..$BFFF) — converting the portal-aliasing corruption class into a
; catchable THROW. Raised from banking.asm w_BANK_STORE_cf via the
; kernel-internal w_THROW_cf.kernel_entry path.
THROW_BANK_FROM_BANKED      EQU -273 ; antforth extension — see docs/throw-codes.md
