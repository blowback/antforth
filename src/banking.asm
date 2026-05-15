; banking.asm — Phase-4 banking subsystem
; AntForth — A Forth for CP/M on Z80
;
; See docs/antforth-banking-redesign.md §5.1 for the canonical memory layout
; and §1 for the Phase-4 wordset. Story 17.1 ships the file shell with the
; bank-table[] cap/size constants, BANK-MAPPING-ON, and BANK-MAPPING-OFF.
; Stories 17.2–17.6 fill in BANK@ / BANK! / BANKS / +BANK / -BANK /
; BANKS-CLEAR / SET-BANK / .BANKS in this same file.
;
; The 2 KB region $D400-$DBFF is annexed to the kernel's fixed-memory
; claim per PD-P4-6 closure (CCP eviction; Story 16.1 hardware
; verification). Story 17.1 routes the bank-table[] base to $D400;
; Story 18.1 carves the descriptor-stub allocator out of the
; post-bank-table[] portion of this region.

; === Phase-4 banking constants ===
; bank-table[] cap = 29 entries per PD-P4-13 (architecture.md:386..402).
; Per-entry layout: here (2 B) + latest (2 B) + wordlist_head (2 B) =
; 6 B / 3 cells. Full plumbing of the triple swap on BANK! is Story
; 17.2 / Epic 19; Story 17.1 only declares the cell layout and
; zero-initialises the table shell in COLD (src/antforth.asm step 8h).
; The shell lives AT BANK_TABLE_BASE = $D400 (src/constants.asm), in
; the reclaimed $D400-$DBFF CCP region — NOT allocated by a DS
; directive (no kernel binary bytes consumed for the shell).
BANK_TABLE_CAP         EQU 29
BANK_TABLE_ENTRY_SIZE  EQU 6
BANK_TABLE_SHELL_SIZE  EQU BANK_TABLE_CAP * BANK_TABLE_ENTRY_SIZE   ; 174 B

; === BANK-MAPPING-ON ( -- ) ===
;   Enable the MicroBeast MMU mapping (port 0x74 bit 0 set).
;   Updates UserArea.bank_mapping_state to 1.
;   Auto-run in COLD (src/antforth.asm cold_start, after pool_init).
;
; PD-P4-9 (architecture.md:323): port 0x74 is the MMU-mapping-enable
; register; bit 0 = enable. Confirmed against iz-cpm-banking @ 1777a85
; (src/cpm_machine.rs: PORT_MAP_ENABLE = 0x74,
;  `mapping_enabled = (value & 1) != 0`).
;
; antforth extension BANK-MAPPING-ON — see docs/antforth-banking-redesign.md §5.1
w_BANK_MAPPING_ON:
        DEFCODE "BANK-MAPPING-ON", 0
w_BANK_MAPPING_ON_cf:
        LD      A, 1
        OUT     (0x74), A
        LD      (IY+UserArea.bank_mapping_state),   1
        LD      (IY+UserArea.bank_mapping_state+1), 0
        NEXT

; === BANK-MAPPING-OFF ( -- ) ===
;   CP/M warm-boot escape (FR-P4-12). Updates the kernel-side
;   bank_mapping_state cell to 0 and jumps to BIOS WBOOT at $0000
;   to reload CCP and return to a healthy `B>` prompt. The JP
;   never returns.
;
;   IMPLEMENTATION NOTE — literal port-0x74 write is INTENTIONALLY
;   NOT performed. A naive `OUT (0x74), A` with A=0 (the obvious
;   reading of "disable MMU mapping hardware") disconnects the
;   kernel from RAM in the next instruction fetch: the CPU sees
;   flash bank 0 (firmware code) at the slot-0 address it was
;   executing, falls through to the firmware reset path, and
;   triggers a full cold-boot (PIO/Display/RTC re-detect, RAM-disk
;   reformat, sector restore) — verified on real MicroBeast 2026-05-15
;   transcript `~/Downloads/beastty-20260515-193026.bin`. Story 17.1
;   AC10 dev-pass finding. The firmware-blessed transition path is
;   BIOS WBOOT at $EA03 (MicroBeast firmware beastos/bios.asm:55+164
;   `wboote JP bios_wboot`), reachable as `JP 0x0000` via the JP
;   wboote that bios_wboot sets up at address 0 (beastos/bios.asm:173-176).
;   BDOS function 0 (`BYE`'s path) ends up here too. Mapping stays
;   enabled across warm-boot; CP/M operates with mapping enabled
;   (it's how the BIOS loaded antforth in the first place). The
;   `bank_mapping_state` cell update reflects user intent ("we're
;   done with banked mode") even though the hardware bit is unchanged.
;
;   FR-P4-12 / PRD wording ("disables the MMU mapping hardware")
;   needs a follow-up correction to align spec with the only
;   physically-feasible mechanism — flagged for Story-17 retro.
;
; antforth extension BANK-MAPPING-OFF — see docs/antforth-banking-redesign.md §5.1
w_BANK_MAPPING_OFF:
        DEFCODE "BANK-MAPPING-OFF", 0
w_BANK_MAPPING_OFF_cf:
        LD      (IY+UserArea.bank_mapping_state),   0
        LD      (IY+UserArea.bank_mapping_state+1), 0
        JP      0x0000          ; BIOS WBOOT — never returns
