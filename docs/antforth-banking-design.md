# AntForth Banking Architecture for MicroBeast

> **⚠️ SUPERSEDED 2026-05-09.** This document is the initial banking sketch (2026-05-07). It was superseded by the `/bmad-party-mode` session of 2026-05-09; the authoritative Phase-4 design is now [`docs/antforth-banking-redesign.md`](antforth-banking-redesign.md). Specifically, the user-facing wordset (`USER-BANK` / `USER-BANK@` / `ENABLE-MAPPING` / `THUNK-TO-USER-BANKn`) is replaced by a 12-word set (`BANK@` / `BANK!` / `BANKS` / `IN-BANK` / `BANK-OF` / `.BANKS` / `+BANK` / `-BANK` / `BANKS-CLEAR` / `SET-BANK` / `BANK-MAPPING-ON` / `BANK-MAPPING-OFF`); the per-target-bank thunk family is replaced by per-word descriptor stubs (the **(γ)** mechanism); the cross-bank EXIT `BIT 7,H` heuristic is replaced by sentinel-tagged returns (broken in this doc — user code at $8000–$BFFF always has bit 7 set on return-address high bytes). **Do not consult this document for current decisions.** Retained for historical traceability of design evolution only.

## Problem Statement

MicroBeast has 512KB RAM but only 64KB address space, organized as 4×16KB banks. Need to adapt AntForth (Z80 Forth implementation) to utilize extended memory without breaking portability to flat-memory systems.

## Core Constraint

Forth's threaded execution model assumes 16-bit addresses are meaningful without bank context. The inner interpreter (`NEXT`) fetches instruction pointers with no slack for bank switching per instruction.

## Solution: Fixed System + Swappable User Space

### Memory Layout

**Fixed System (48KB):**
- **Page 0** (`$0000-$3FFF`): CP/M + Core Forth kernel  
- **Page 1** (`$4000-$7FFF`): Assembler + Extended kernel
- **Page 3** (`$C000-$D3FF`): Return stack, user area, system data (5KB - BIOS takes `$D400+`)

**Swappable User Space (176KB):**
- **Page 2** (`$8000-$BFFF`): User bank slot (16KB visible, 11 banks total: 0x35-0x3F)

### Key Design Decisions

**Three fixed pages:** Complete system (core + assembler + I/O) lives in always-mapped memory. No system code needs bank switching.

**Single swappable slot:** One 16KB window (`$8000-$BFFF`) provides access to 11 different user code banks (176KB total).

**Cross-bank calls via thunks:** User code calling between different banks uses thunk system. All system code (including assembler) available without thunks.

**Parameterized thunks:** One thunk per target user bank, takes target address as next cell:
```
DW THUNK_TO_USER_BANK5    ; thunk address  
DW TARGET_WORD            ; target address in user bank 5
```

Memory cost: 11 user bank thunks (~110 bytes) vs potentially hundreds of per-word thunks.

**Single file deployment:** Complete system including assembler ships as one `.COM` file. No external dependencies or sidecar files.

## Wordlist Integration

**Current architecture:** 64-bucket hash tables per wordlist, up to 16 wordlists in search order.

**Banking extension:** 
- System wordlists (FORTH, ASSEMBLER) stay in fixed memory  
- User wordlists can live in swappable user banks
- `FIND` doesn't need to switch banks for system lookups (the common case)
- Cross-references between user banks handled by thunk system

## User Interface

### Core Words
```forth
USER-BANK ( n -- )         \ Switch to user bank 0-10
USER-BANK@ ( -- n )        \ Query current user bank
SET-BANK ( page slot -- )  \ Low-level bank control
ENABLE-MAPPING ( -- )      \ Enable bank mapping hardware
```

### Example Usage
```forth
\ System and assembler always available - no banking needed
: MYWORD DUP + ;           \ core primitives in fixed memory
CODE FAST ADD, ;CODE       \ assembler in fixed memory

\ User banks for applications  
5 USER-BANK                \ switch to user bank 5
: GRAPHICS-APP
  PIXEL CIRCLE LINE        \ define graphics words in bank 5
;

3 USER-BANK                \ switch to user bank 3  
: DATABASE-APP
  5 THUNK-TO-USER-BANK5 GRAPHICS-APP  \ cross-bank call via thunk
  STORE-RECORDS            \ other words in bank 3
;
```

## Implementation Details

### Hardware Interface
```forth
\ MicroBeast banking control via I/O ports
: SET-BANK ( page slot -- )
  SWAP OVER 0x70 + OUT ;    \ write page to port 0x70+slot

: ENABLE-MAPPING ( -- )  
  1 0x74 OUT ;              \ enable bank mapping

: USER-BANK ( bank -- )
  DUP 0 11 WITHIN 0= ABORT" User bank 0-10 only"
  0x35 + 2 SET-BANK ;       \ map user bank into slot 2 ($8000-$BFFF)
```

### Thunk Structure
```asm
THUNK_TO_USER_BANK5:
    LD A,(current_user_bank) ; save current user bank  
    PUSH A
    LD A,5                   ; switch to user bank 5
    CALL user_bank_switch    
    LD A,(DE)                ; fetch target address low
    INC DE
    LD L,A  
    LD A,(DE)                ; fetch target address high
    INC DE
    LD H,A
    EX DE,HL                 ; target -> DE (new IP)
    JP NEXT                  ; continue threading
```

### Modified EXIT
```asm
EXIT:
    POP HL               ; return address
    ; detect cross-user-bank return  
    BIT 7,H              ; example: high bit indicates cross-bank
    JR Z,local_return
    POP A                ; restore caller's user bank
    CALL user_bank_switch
local_return:
    EX DE,HL             ; return address -> DE  
    JP NEXT
```

### Compiler Changes
- `FIND` determines if target is system (fixed) or user (swappable) code
- `COMPILE,` emits thunk+address for cross-user-bank calls, direct CFA for same-bank or system calls
- User bank assignment tracked in current compilation state

## Performance Impact

**System-to-system calls:** Zero overhead (all in fixed memory - includes assembler!)  
**System-to-user calls:** Zero overhead (system never moves)
**User-to-system calls:** Zero overhead (system never moves)
**User-to-user calls (same bank):** Zero overhead (standard DTC)
**User-to-user calls (different banks):** ~60 T-states overhead + bank switch time  
**Dictionary lookup:** System words always fast (fixed memory), user words only switch if needed

## Portability Strategy

Banking features are conditional compilation:
- **Banked build:** User bank support enabled, thunks for user-to-user cross-bank calls
- **Flat build:** All memory directly addressable, no thunks, `USER-BANK` becomes no-op

Same source code, different binaries. System threading model unchanged - banking only affects user code organization.

## Memory Budget

**Fixed memory (48KB total):**
- Page 0: CP/M vectors (~1KB) + Core kernel (~15KB) 
- Page 1: Assembler (~7KB) + Extended kernel (~9KB)
- Page 3: Stacks, user area, system data (~5KB before BIOS)
- **Current AntForth.com: 24KB fits comfortably with room for banking infrastructure**

**User memory (176KB total):**
- 11 user banks × 16KB each = 176KB user workspace
- Only 16KB visible at once, but users can organize code across banks
- Each bank can hold ~100-200 typical Forth definitions

**Banking overhead:**
- User bank thunks: ~110 bytes (11 thunks)
- Bank control code: ~200 bytes
- **Total overhead: <1KB**

## Design Characteristics

- **Single file deployment:** Everything in one `.COM` file, no external dependencies
- **Return stack in fixed memory:** Required for IX register stability
- **11 user banks available:** Pages 0x35-0x3F (MicroBeast hardware limit)
- **System always accessible:** No banking overhead for core operations

## Development Plan

1. **Phase 1:** Reorganize existing code into 3-page fixed layout (48KB system)
2. **Phase 2:** Add user banking primitives (`USER-BANK`, hardware I/O control)
3. **Phase 3:** Implement user bank thunk system for cross-bank calls
4. **Phase 4:** Extend compiler to automatically generate thunks
5. **Phase 5:** Polish, optimize, and add development tools

## Risk Mitigation

**Fixed system size:** 48KB budget is generous for current 24KB kernel plus banking infrastructure. Assembler separation provides immediate space relief.

**User bank organization:** 176KB across 11 banks requires thoughtful code organization, but each 16KB bank is substantial for typical applications.

**Cross-bank call overhead:** Minimized by keeping all system code (including assembler) in fixed memory. Only user-to-user calls between banks pay the thunk cost.

**Development complexity:** Banking is largely transparent - users work in one bank at a time, system provides automatic thunk generation.

---

**Bottom line:** This design provides a complete, self-contained Forth system in a single file while enabling 176KB of organized user workspace. The 3-fixed + 1-swappable architecture maximizes system capability while keeping banking complexity minimal and localized to user code interactions.
