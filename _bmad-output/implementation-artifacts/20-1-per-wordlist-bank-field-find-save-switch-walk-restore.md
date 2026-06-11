# Story 20.1: Bank-aware `FIND` via inline 24-bit dictionary pointers

Status: review

<!-- Mechanism re-spec (2026-06-10): the planning-era "per-wordlist `bank`
     field + FIND save/switch/walk/restore" approach was superseded during the
     dev pass. See Dev Notes "Why the mechanism changed". The user-facing goal
     (FIND resolves words that live in any bank) is unchanged. -->

## Story

As Marc (OG user) looking up a word that may live in any bank,
I want `FIND` to resolve a name to its xt regardless of which bank the word's header physically lives in, while the everyday FORTH-wordlist case incurs no MMU switch,
so that lookups transparently traverse banks and the hot path stays free.

## Why the mechanism changed (read this first)

The planning artifact specified a **per-wordlist `bank` field**: each wordlist tagged with one bank, FIND switching MMU slot 2 to that bank around the chain walk. Investigation at dev-pass start showed this cannot work for antforth's actual structure, and the project lead confirmed the intended design is a **single global wordlist** (per-bank wordlists "would be invisible most of the time"):

- There is **one** global `forth_wordlist`; `current_wordlist` is not per-bank-swapped, so every `:` definition (in any bank) chains into it. A single per-wordlist bank tag cannot describe a list whose entries live in many different banks.
- A wordlist created in a bank would have its struct (and tag) in the `$8000` window — unreadable when another bank is mapped (chicken-and-egg).
- Pre-existing behaviour: `build_header` deliberately **skipped** bucket-linking for bank-N entries (to avoid dangling window pointers), so bank-N words were unfindable by name — reachable only via `LATEST @`.

The root cause (per `docs/antforth-banking-redesign.md` §5.5 "INTERIM GOTCHA") is that bucket heads and entry hash_links were **bare 16-bit addresses that lost the bank**. The fix, steered by the project lead: make every stored dictionary pointer a **24-bit `bank:address` "fat pointer"**, and page the bank in before dereferencing a window-resident address. This makes the single global wordlist genuinely global, keeps each word's name *and* body in its bank (frugal on fixed memory), and leaves the fast path untouched.

## Acceptance Criteria

> Re-spec of `epics-phase4-epics-16-22.md` §"Story 20.1" against the implemented mechanism. FRs covered: FR-P4-27 (bank attribution of dictionary entries), FR-P4-28 (FIND traversal). NFRs: NFR-P4-6 (batch-load envelope), NFR-P4-12 (ANS compliance).

1. **AC1** — Dictionary pointers carry a bank. The wordlist bucket-head array and every entry `hash_link` become inline 24-bit fat pointers `[addr:2][bank:1]`. Kernel/fixed entries emit `bank = $FF` (`BANK_FIXED`). `src/wordlists.asm` struct grows to `WORDLIST_SIZE = 194` (`WORDLIST_BUCKET_STRIDE = 3`).
2. **AC2** — `build_header` (`src/compiler.asm`) records the entry's bank in its fat head/link for **all** banks (the old `current_bank > 0` bucket-skip is removed), so bank-N `:` definitions are linked into the global FORTH-WORDLIST and findable by name.
3. **AC3** — `search_wid_for_name` (`src/dictionary.asm`) dereferences each fat pointer; if the pointed-to address is window-resident (`$8000..$BFFF`) it pages `active_pages[bank]` into slot 2 via the blessed `mbb_set_slot2`/`mbb_get_slot2` (BIOS `MBB_*`), and restores the caller's page on **every** exit edge (hit, miss). Fixed addresses (`< $8000`, `>= $C000`) read directly — no MMU touch.
4. **AC4** — Per-entry traversal: each link is paged in independently, so a single bucket chain mixing entries from different banks is fully walkable. Drives FIND, SEARCH-WORDLIST (shared helper), and the search-order walk.
5. **AC5** (NFR-P4-6 batch-load envelope) — measured against the pre-edit HEAD (26945 B), pure-FIND runtime loop (memory-stable; large-compile benchmarks are confounded by the 64 KB dictionary ceiling). Pre-optimisation ≈ 14.3 %; after inlining the fixed-path fat-pointer deref (`.sw_head_fixed`/`.sw_skip_fixed`, no per-entry CALL) ≈ **7.8 %** (60k loop, best-of-9). Comfortably within the ≤ 5–15 % envelope. Real INCLUDE (which also parses, builds headers, executes) dilutes the FIND-attributable share further. Fast path takes no MMU op (AC7-b witness + unchanged 975 baseline).
6. **AC6** (NFR-P4-12) — `FIND` matches ANS §6.1.1550 / §6.2.1985 (no semantic drift). `docs/ans-forth-core-compliance.md` FIND row annotated "Phase-4-bank-aware (Story 20.1)".
7. **AC7** (REPL probes — `tests/banking_tests_20_1.fth`, isolated):
   - (a) `5 BANK! : W5 100 ; 0 BANK! ' W5 BANK-OF` → `5` (creation-bank traversal).
   - (b) `' BANK@` (fixed word) resolves with **no** slot-2 change — witnessed by `MBB-GET-2` identical before/after the find, xt non-zero.
   - (c) FIND of an undefined name returns flag 0 (TICK's `-13` wrapping unchanged); tested from a CREATE'd counted-string buffer so the interpreter's own parse-into-HERE can't clobber it.
   - (d) Q2 in-window search name: parked in bank 5 (HERE in window), `' <bank-3 word> BANK-OF` → `3` — the name is snapshotted to fixed scratch on the first page-in.
   - (e) Execute-by-name across `BANK!`: a bank-5 body runs from bank 0 by bare name.
8. **AC8** (hardware smoke) — **PASS on real MicroBeast 2026-06-10** (transcript `beastty-20260610-200525.bin`): `INCLUDE P201FIND.FTH` → all five AC7 (a)–(e) probes `result=-1`, no errors/underflow/strands.
9. **AC9** (binary delta) — `wc -c build/antforth.com` = 27516 B, Δ **+571 B** vs 26945 (+10 B for the inlined fast-path deref). Exceeds the planning ~120 B figure because the mechanism changed from a localised FIND tweak to a dictionary header-format migration (+1 B per 379 kernel header links + 64 B fat bucket array + walk/build code + 32 B name buffer). Tracked against the revised Epic-20 understanding.
10. **AC10** — `make test-repl` = **975 PASS / 0 FAIL**; `make test-repl-banking` = **61 PASS / 0**; `make test-repl-banking-isolated-20-1` = 6 PASS; isolated 19.2/19.3/19.4/19.5.1 = 6/15/2/2; straddle 3/3.

## Tasks / Subtasks

### Pre-edit baseline
- [x] Binary: 26945 B (HEAD 2808ce3). `make test-repl` 975 PASS / 0 FAIL. `make test-repl-banking` 61 PASS.

### Task 1 — Fat-pointer dictionary format (AC1)
- [x] `src/wordlists.asm`: `WORDLIST_SIZE` 130→194, `WORDLIST_BUCKET_STRIDE = 3`, `WORDLIST_BANKS0`/`BANK_FIXED` EQUs; `forth_wordlist` LUA emits 3-byte fat heads (`DW addr` + `DB $FF`); WORDLIST zero-init 193.
- [x] `src/macros.asm`: `DEFCODE`/`DEFWORD` emit 3-byte fat `hash_link` (`DW prev` + `DB $FF`).

### Task 2 — build_header records the bank (AC2)
- [x] `src/compiler.asm` `build_header`: bucket address ×3; read 3-byte fat head (addr + bank into `bh_old_bucket_bank`); emit 3-byte fat link; **removed the bank-N bucket-skip** — write fat head (addr + `current_bank`) for all banks.

### Task 3 — search_wid_for_name page-in/restore (AC3, AC4)
- [x] `src/dictionary.asm`: bucket address ×3; `sw_deref` (fat-pointer deref + conditional page-in per entry); `sw_map_bank` (page-in + lazy search-name snapshot on first switch); `sw_restore_slot2` on every exit; count_flags offset +1; `.sw_skip` re-derefs the fat link.

### Task 4 — Layout-shift sweep (AC1 consumers)
- [x] `RECURSE` (`src/control_flow.asm`): skip 3-byte link to count_flags.
- [x] `WORDS` (`src/dictionary.asm`): bucket stride ×3, count_flags +1.
- [x] `MARKER` snapshot/restore (`src/system.asm`, `src/inner_interpreter.asm`): copy 192 B; fixup ×3 stride + restore fat bank byte.
- [x] Assembler error-recovery (`src/assembler.asm`, 2 sites): bucket stride ×3.
- [x] `COMP-ERROR` (`src/compiler.asm`): bucket stride ×3.

### Task 5 — Q2 search-name snapshot (AC7-d)
- [x] On the first page-in (`sw_map_bank`), copy the search name (clamped ≤31) to `sw_name_buf` and repoint `sw_search_name` before unmapping slot 2. Lazy: the fast path never copies.

### Task 6 — ANS annotation (AC6)
- [x] `docs/ans-forth-core-compliance.md` FIND row annotated.

### Task 7 — REPL probes + benchmark (AC7, AC5)
- [x] `tests/banking_tests_20_1.fth` (probes a–e) + `test-repl-banking-isolated-20-1` Makefile recipe + `.PHONY`.
- [x] Existing layout-introspection probes re-pointed to the new offset (`banking_tests.fth` probes 19.2-c / 19.3-c → `3 +`; test-807 struct-size assertion 130→194).
- [x] AC5 benchmark measured (≈14.3 % pure-FIND, ≈14.8 % compile) vs the pre-edit binary.

### Task 8 — Gates + binary delta (AC9, AC10)
- [x] 975/0 · 61/0 · 20.1 6 · 19.x 6/15/2/2 · straddle 3/3. Binary 27506 B (+561).

### Task 9 — Hardware smoke (AC8)
- [x] `disk/a/P201FIND.FTH` (CP/M 8.3, 0x1A-terminated). `INCLUDE P201FIND.FTH` on real MicroBeast 2026-06-10 → all five AC7 (a)–(e) probes `result=-1` (transcript `beastty-20260610-200525.bin`). Bank-aware FIND verified on silicon.

## Dev Notes

### The mechanism (what shipped)

Every dictionary pointer — each of the 64 bucket heads in a wordlist struct, and the `hash_link` at the start of every entry header — is an inline 3-byte fat pointer `[addr:2 little-endian][bank:1]`. The bank byte names the bank the *pointed-to* entry physically lives in; `$FF` (`BANK_FIXED`) = fixed memory (kernel / main RAM, always mapped). FIND, walking a chain, calls `sw_deref` on each pointer: it reads the address and bank, and **only if the address is window-resident (`$8000..$BFFF`)** pages `active_pages[bank]` into slot 2 (saving the caller's page on the first switch of the walk). On hit or miss it restores the caller's page. Kernel/bank-0 heads (`addr < $8000`) read directly — the everyday lookup does no MMU work, which is why the 975 baseline holds byte-for-byte.

Because the bank travels *with the pointer*, a single global wordlist whose entries are scattered across banks is fully walkable — no per-bank wordlists, no chicken-and-egg. A word's name and body both stay in its bank; only the tiny fat pointers and the existing 4-byte trampoline stub live in fixed memory.

### Q2 — search name in the window

`WORD` writes the parsed token to HERE; in a bank context HERE is in the `$8000` window. If FIND pages a *different* bank in to read a target's name, the search name would be unmapped mid-compare. Fix: on the first page-in, `sw_map_bank` snapshots the search name (clamped to 31, the max stored length) into fixed `sw_name_buf` and repoints `sw_search_name`. Lazy — the fast path (no page-in) never copies, so the AC5 hot path is unaffected. Witnessed by probe-20.1-d (find a bank-3 word while parked in bank 5).

### Files touched (vs the planned 2)

`src/wordlists.asm`, `src/macros.asm`, `src/compiler.asm`, `src/dictionary.asm`, `src/control_flow.asm`, `src/system.asm`, `src/inner_interpreter.asm`, `src/assembler.asm`, `docs/ans-forth-core-compliance.md`, `tests/banking_tests_20_1.fth` (new), `tests/banking_tests.fth`, `Makefile`. The header-format migration is wider than the planning artifact's `wordlists.asm` + `dictionary.asm` surface.

### Known limitations / follow-ups

- **WORDS** bank-aware page-in: resolved in this story's CR pass `d078548` (bank-N names list flat from any bank); verified by Story 20.2 probes (`tests/banking_tests_20_2.fth`).
- **AC5** — the fixed-path fat-pointer deref is now inlined (≈7.8 % pure-FIND, was ≈14 %); re-validated 975/0 · 61/0 · 20.1 6/6 after the change. Binary 27516 B (+10 B for the inlined code).
- **Error-recovery bank byte** (COMP-ERROR / assembler): the fat bank byte is left at the failed entry's `current_bank` on rollback — correct for the bank-0 error path (the only tested one; restored head is fixed memory). A bank-N compile-error edge would need the old head's bank saved in the prologue.
- **AC8 hardware smoke** deferred; recipe in closing message.

### References

- [Source: docs/antforth-banking-redesign.md §5.5] — bank-aware FIND + the INTERIM GOTCHA (bare 16-bit chains lose the bank).
- [Source: src/dictionary.asm] — `search_wid_for_name`, `sw_deref`, `sw_map_bank`, `sw_restore_slot2`.
- [Source: src/banking.asm:78-101] — `mbb_set_slot2` / `mbb_get_slot2`; :22 `active_pages[]`; :800-843 `BANK-OF`.
- Memory: `[[project_banking_bios_pivot]]`, `[[project_div1_mmu_port_readback]]`, `[[feedback_phase4_probe_bank_switch_limitation]]`, `[[feedback_post_hw_smoke_steps_at_review]]`, `[[feedback_cpm_0x1a_eof_marker]]`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8)

### Debug Log References

- Q2 false-miss reproduced + fixed: find bank-3 word from bank 5 → `BANK-OF 3`.
- RECURSE regression (test 55 FACT): 2-byte link skip → 3; root-caused via `5 FACT .` producing no output.
- Probe-c interpreter-clobber gotcha: manual `BL WORD x FIND` searches "FIND" (interpreter re-parses next token into HERE between WORD and FIND); fixed with a CREATE'd counted-string buffer.

### Completion Notes List

- Mechanism re-specced from per-wordlist bank field → inline 24-bit fat dictionary pointers (project-lead-steered). Proven via throwaway parallel-array POC first, then implemented as the chosen inline-uniform layout.
- All gates green: 975/0 · 61/0 · 20.1 isolated 6 · 19.2/19.3/19.4/19.5.1 6/15/2/2 · straddle 3/3.
- AC5: ≈14.3 % (pure FIND) / ≈14.8 % (compile) — within ≤15 %, at boundary.
- Binary 27506 B (+561). AC8 hardware smoke deferred (recipe posted at close).

### File List

- src/wordlists.asm (modified) — fat struct + LUA emitter
- src/macros.asm (modified) — fat hash_link in DEFCODE/DEFWORD
- src/compiler.asm (modified) — build_header fat read/write + bucket-skip removal; COMP-ERROR ×3
- src/dictionary.asm (modified) — search_wid_for_name fat deref + page-in + name snapshot; WORDS ×3/+1
- src/control_flow.asm (modified) — RECURSE 3-byte link skip
- src/system.asm (modified) — MARKER snapshot 192 + fat fixup
- src/inner_interpreter.asm (modified) — DOMARKER restore 192
- src/assembler.asm (modified) — 2 error-recovery bucket strides ×3
- docs/ans-forth-core-compliance.md (modified) — FIND row annotation
- tests/banking_tests_20_1.fth (new) — probes a–e (emulator gate)
- disk/a/P201FIND.FTH (new) — CP/M 8.3 hardware-UAT copy, 0x1A-terminated, `INCLUDED` on real MicroBeast (AC8)
- tests/banking_tests.fth (modified) — probes 19.2-c/19.3-c offset → 3 +
- Makefile (modified) — test-repl-banking-isolated-20-1 + .PHONY + test-807 expectation 194

### Change Log

- 2026-06-10 — Bank-aware FIND via inline 24-bit fat dictionary pointers. Mechanism re-specced from per-wordlist bank field. +571 B. Gates green. AC8 hardware smoke PASS on real MicroBeast (transcript beastty-20260610-200525.bin, all five probes result=-1).
- 2026-06-10 — Fast-path optimisation: inlined the fixed-path fat-pointer deref (no per-entry CALL). AC5 pure-FIND ≈14 %→≈7.8 %. Re-validated 975/0 · 61/0 · 20.1 6/6. +10 B (27516 B).
