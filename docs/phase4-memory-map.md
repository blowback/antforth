# Phase-4 memory map — page-allocation survey

**Status:** authored by Story 16.1 (2026-05-13) as the AC6 deliverable. Closes F3 (CCP eviction policy verified on real CP/M 2.2 / MicroBeast hardware — transcript `~/Downloads/beastty-20260513-110640.bin`).

**Purpose:** a per-page reference table for the MicroBeast MMU's 6-bit page space ($0x00..0x3F$, 64 pages × 16 KB = 1 MB). Downstream-story developers (Story 17.1 onward; anyone touching MMU port writes, CL parser, banked-word descriptor stubs) can look up "what's at page 0x2A?" here without re-deriving the assignment from the schematic + redesign doc.

**Source-of-truth columns matter:** each row cites the canonical source for that page's assignment. Where a row is inferred from convention rather than a primary document, the citation is flagged `(inferred)` explicitly. Don't fabricate citations.

---

## Slot model

MicroBeast's Z80 sees a 64 KB address space mapped through four 16 KB slots:

| Z80 slot | Z80 address range |
|---|---|
| Slot 0 | `$0000–$3FFF` |
| Slot 1 | `$4000–$7FFF` |
| Slot 2 | `$8000–$BFFF` |
| Slot 3 | `$C000–$FFFF` |

Each slot is filled by mapping one 16 KB **page** from the MMU's 6-bit page space ($0x00..0x3F$) into the slot. The MMU has four "slot-select" registers (one per slot) that hold the current page ID.

Default boot configuration (per `docs/antforth-banking-redesign.md` §5.1):

| Slot | Default page | Default content |
|---|---|---|
| 0 | `0x20` | Kernel page 0 (fixed) |
| 1 | `0x21` | Kernel page 1 (fixed) |
| 2 | `0x22` | "Portal page" — DEFAULT BANK 0 (reclaimable for banking) |
| 3 | `0x23` | Stacks / user area / CCP / BDOS / BIOS (fixed) |

---

## Page-allocation table (pages $0x20..0x3F$ — slot-mapped user-RAM range)

One row per page (32 rows) per AC6: downstream lookup ("what's at page 0xNN?") is a single-key index, not a range-walk. Uniform-assignment runs (RAM disk 0x25..0x34; default banks 0x35..0x3F) carry the per-page assignment in each row with `(N of M; range 0xLL..0xHH)` annotation so the block structure remains visible.

| Page | Address-range-when-mapped | Assignment | Source-of-truth |
|---|---|---|---|
| `0x20` | `$0000–$3FFF` (slot 0 default) | Kernel page 0 — fixed; not bankable; contains TPA_START ($0100) through the lower 16 KB of the antforth `.COM` body | `docs/antforth-banking-redesign.md` §5.1 (`0x20-0x21 slot 0/1 default content kernel — fixed, not bankable`) |
| `0x21` | `$4000–$7FFF` (slot 1 default) | Kernel page 1 — fixed; not bankable; contains the upper portion of the antforth kernel body | `docs/antforth-banking-redesign.md` §5.1 |
| `0x22` | `$8000–$BFFF` (slot 2 default) | "Portal page" = **DEFAULT BANK 0** (reclaimed by banking); Phase-4 swap target for `BANK!` | `docs/antforth-banking-redesign.md` §5.1 (`0x22 slot 2 default content ★ DEFAULT BANK 0 (the "portal page", reclaimed)`) |
| `0x23` | `$C000–$FFFF` (slot 3 default) | Stacks / user area / **CCP** / BDOS / BIOS — fixed; not bankable; CP/M residency layout (see sub-table below) | `docs/antforth-banking-redesign.md` §5.1, §5.2 |
| `0x24` | (when mapped in slot 2) | Virtual console buffer — reusable for banking; trades VC for **+1 extra bank** | `docs/antforth-banking-redesign.md` §5.1 (`0x24 virtual console buffer reusable (trades VC for one extra bank)`) |
| `0x25` | (when mapped in slot 2) | RAM disk page 1 of 16 (range `0x25..0x34`) — reusable for banking; trades RAM disk for up to **+16 extra banks** | `docs/antforth-banking-redesign.md` §5.1 (`0x25-0x34 RAM disk (16 pages)`) |
| `0x26` | (when mapped in slot 2) | RAM disk page 2 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x27` | (when mapped in slot 2) | RAM disk page 3 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x28` | (when mapped in slot 2) | RAM disk page 4 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x29` | (when mapped in slot 2) | RAM disk page 5 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x2A` | (when mapped in slot 2) | RAM disk page 6 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x2B` | (when mapped in slot 2) | RAM disk page 7 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x2C` | (when mapped in slot 2) | RAM disk page 8 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x2D` | (when mapped in slot 2) | RAM disk page 9 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x2E` | (when mapped in slot 2) | RAM disk page 10 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x2F` | (when mapped in slot 2) | RAM disk page 11 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x30` | (when mapped in slot 2) | RAM disk page 12 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x31` | (when mapped in slot 2) | RAM disk page 13 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x32` | (when mapped in slot 2) | RAM disk page 14 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x33` | (when mapped in slot 2) | RAM disk page 15 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x34` | (when mapped in slot 2) | RAM disk page 16 of 16 (range `0x25..0x34`) — reusable for banking | `docs/antforth-banking-redesign.md` §5.1 |
| `0x35` | (when mapped in slot 2) | ★ **DEFAULT BANK 1** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 (`0x35-0x3F default user banks (11) ★ DEFAULT BANKS 1-11`) |
| `0x36` | (when mapped in slot 2) | ★ **DEFAULT BANK 2** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 |
| `0x37` | (when mapped in slot 2) | ★ **DEFAULT BANK 3** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 |
| `0x38` | (when mapped in slot 2) | ★ **DEFAULT BANK 4** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 |
| `0x39` | (when mapped in slot 2) | ★ **DEFAULT BANK 5** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 |
| `0x3A` | (when mapped in slot 2) | ★ **DEFAULT BANK 6** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 |
| `0x3B` | (when mapped in slot 2) | ★ **DEFAULT BANK 7** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 |
| `0x3C` | (when mapped in slot 2) | ★ **DEFAULT BANK 8** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 |
| `0x3D` | (when mapped in slot 2) | ★ **DEFAULT BANK 9** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 |
| `0x3E` | (when mapped in slot 2) | ★ **DEFAULT BANK 10** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 |
| `0x3F` | (when mapped in slot 2) | ★ **DEFAULT BANK 11** of 11 (range `0x35..0x3F`) | `docs/antforth-banking-redesign.md` §5.1 |

**Default capacity:** 12 banks × 16 KB = 192 KB user RAM (page 0x22 portal + pages 0x35–0x3F user banks).
**Theoretical maximum:** 29 banks × 16 KB = 464 KB user RAM (sacrificing both virtual console at 0x24 and RAM disk at 0x25–0x34).
*(`docs/antforth-banking-redesign.md` §5.1: "Default 12 banks × 16 KB = 192 KB user RAM. Theoretical max 29 banks × 16 KB = 464 KB.")*

### Slot-3 residency sub-table (page `0x23` when mapped at `$C000–$FFFF`)

| Address range | Region | Disposition | Source-of-truth |
|---|---|---|---|
| `$C000–$D3FF` | Stacks (parameter stack + return stack) + user area + TIB; antforth's `sp_base` initialised to top-of-TPA = BDOS base; stacks grow down | Must stay; antforth-managed | `src/antforth.asm:18..130` (cold_start); `src/constants.asm:33-34` (`PS_SIZE`, `RS_SIZE` = 256 each); `docs/antforth-banking-redesign.md` §5.2 (implicit — region between kernel end and CCP) |
| `$D400–$DBFF` | **CCP** | **DISPOSABLE** — Story 16.1 closes F3; +2 KB Page-3 headroom safe to consume in Epic 17+ for descriptor-stub allocator + `bank-table[]` (verified clean on real MicroBeast hardware via BIOS warm-boot CCP-reload; transcript `~/Downloads/beastty-20260513-110640.bin`) | `docs/antforth-banking-redesign.md` §5.2 (`$D400-$DBFF CCP DISPOSABLE — eaten for +2 KB Page 3`); CP/M 2.2 BIOS warm-boot semantics; Story 16.1 hardware verdict |
| `$DC00–$E9FF` | **BDOS** | Must stay — `CALL 0005h` works unchanged from banked code (BDOS lives in fixed memory; trap-and-vector to BDOS entry point) | `docs/antforth-banking-redesign.md` §5.2 (`$DC00-$E9FF BDOS must stay; CALL 0005h works unchanged from banked code`) |
| `$EA00+` | **BIOS** | Must stay — IM 2 vector table; BIOS work area; BIOS stack; ISRs (no banked code reachable from interrupt vectors per §5.3) | `docs/antforth-banking-redesign.md` §5.2 (`$EA00+ BIOS IM 2 vector table; BIOS work area; BIOS stack`); §5.3 (ISR invariant) |

Note: precise `$DC00` / `$EA00` boundaries are CP/M 2.2 BIOS conventions; on real MicroBeast the exact BDOS base may shift slightly (the boot-time `BDOS_ADDR_PTR` at `$0006` is the authoritative source, read by antforth at cold-start `src/antforth.asm:20`). The redesign-doc §5.2 boundaries are the canonical reference for layout reasoning.

---

## Pages below `0x20` (page-IDs `0x00..0x1F`)

The MMU's 6-bit page-ID space covers $0x00..0x3F$ (64 pages). User-accessible expansion RAM populates $0x20..0x3F$ (32 pages × 16 KB = **512 KB**, matching MicroBeast's documented RAM capacity). Pages $0x00..0x1F$ are NOT consumed by the banking model; antforth + Phase-4 banking never reads or writes a page-ID below `0x20`.

Their precise assignment is **outside the scope of Phase-4 banking** — likely a mix of MicroBeast firmware ROM, host-side bridge pages, and/or unmapped — but the load-bearing point for Phase-4 is **uniform**: not user-accessible for banking, not written by antforth, not read by `BANK!`. Where exact assignment is needed for a future story, the MicroBeast hardware schematic is the authoritative source.

| Page range | Disposition for Phase-4 banking | Source-of-truth |
|---|---|---|
| `0x00..0x1F` (32 pages) | Out of scope; never mapped into a slot by antforth's banking; `+BANK` / `BANKS-CLEAR` rejects any page-ID in this range | `docs/antforth-banking-redesign.md` §5.1 (implicit — table starts at `0x20`); **(inferred from convention)** — the MicroBeast hardware schematic is the canonical source if a downstream story needs an exact per-page assignment in this range |

---

## Cross-references

- `_bmad-output/planning-artifacts/architecture.md` §F3 (closed 2026-05-13 by Story 16.1)
- `_bmad-output/planning-artifacts/architecture.md` PD-P4-6 (CCP eviction decision, option (c))
- `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md` (verdict + transcript-verbatim block)
- `docs/antforth-banking-redesign.md` §5 (canonical memory-layout doc)
- `src/antforth.asm:18..130` (cold_start; sp_base / rp_base / user_area init)
- `src/antforth.asm:290` (`kernel_end:` — Story 17.1's edit target for the +2 KB kernel-end move-up)
