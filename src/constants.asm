; constants.asm — Memory layout equates and system constants
; AntForth — A Forth for CP/M on Z80

; === CP/M System Addresses ===
BDOS_ENTRY      EQU     0x0005          ; BDOS entry point
BDOS_ADDR_PTR   EQU     0x0006          ; Word containing BDOS base address
TPA_START       EQU     0x0100          ; .COM entry point / start of TPA

; === BDOS Function Numbers ===
P_TERMCPM       EQU     0               ; BDOS function 0: terminate program
C_READ          EQU     1               ; BDOS function 1: console input (blocking, echoes)
C_WRITE         EQU     2               ; BDOS function 2: console output (E = char)
C_STATUS        EQU     11              ; BDOS function 11: console status (non-blocking)
C_READSTR       EQU     10              ; BDOS function 10: read console buffer

; === Stack Sizes ===
PS_SIZE         EQU     256             ; Parameter stack: 128 cells (256 bytes)
RS_SIZE         EQU     256             ; Return stack: 128 cells (256 bytes)

; === Dictionary ===
HASH_BUCKETS    EQU     64              ; Number of hash buckets

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
THROW_END_OF_INPUT      EQU -58  ; ANS Forth 1994 §9.3.5

; --- Architecture-mandated example EQUs (architecture.md:476-478) ---
; Declared upfront per the design-upfront feedback rule even though no
; Epic 11 migration references them. THROW_FCB_EXHAUSTED lands first in
; Epic 13 (File-Access); THROW_ASM_LOAD_FAIL is reserved for the
; lazy-load assembler also in Epic 13.
THROW_FCB_EXHAUSTED     EQU -69  ; ANS Forth 1994 §9.3.5 (post-1994 extension; Forth 2014 retains)

; --- antforth extensions: assembler-error codes (-258..-271) ---
; Allocated as one contiguous block for grep-ability; one code per error
; entry point in src/assembler.asm. The block starts at -258 (not -256)
; to leave -256 reserved for future use and -257 reserved for
; architecture-mandated THROW_ASM_LOAD_FAIL (architecture.md:478,606).
; The block extends to -271 per Story 11.6's asm_die-residual cleanup
; (the two non-fan-in callers check_asm_mode and asm_range_err were
; missed by Story 11.1's inventory; -270 / -271 retire them).
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
THROW_ASM_RANGE             EQU -271 ; antforth extension — see docs/throw-codes.md
