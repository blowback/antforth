# Story 21.1: `MARKER` / `FORGET` per-bank dictionary tail + descriptor-stub allocator tail reclamation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As Marc (OG user) using `MARKER` to mark a checkpoint and `FORGET` to roll back,
I want `MARKER` to snapshot every active bank's `(here, latest, wordlist-heads)` triple AND the descriptor-stub allocator tail, with `FORGET` reverting both,
so that I can experiment across banks freely without leaking stub-allocator fixed-memory occupancy on rollback.

> **Naming note (read first):** There is **no separate `FORGET` word** in antforth (`grep` confirms zero `w_FORGET`). "`FORGET`" throughout this story = **invoking the marker word**, whose code field is `JP DOMARKER`. So "extend `FORGET`" means **extend `DOMARKER`** (`src/inner_interpreter.asm`), and "extend `MARKER`" means **extend `w_MARKER_cf`** (`src/system.asm`). Do **not** add a new `FORGET` word.

## Acceptance Criteria

**Given** Epic 19 has shipped (per-bank dictionary state plumbed; `:` allocates body in current bank + stub in fixed memory),
**When** Story 21.1 is dev-passed,

1. **AC1** — `MARKER` (`w_MARKER_cf`, `src/system.asm:33`) is extended to snapshot every active bank's `(here, latest, wordlist-heads)` triple from `bank-table[]` into the MARKER's stored (body) state; the snapshot covers all banks present in the active list at MARKER-creation time. (The robust way to "cover all active banks" is to snapshot the full 29-entry `bank-table[]` region — see Dev Notes "Design").
2. **AC2** — `MARKER` additionally snapshots the descriptor-stub allocator tail (`UserArea.stub_alloc_tail`, the next-free address in the fixed-memory stub region from Story 18.1's allocator, base `STUB_ALLOC_BASE = $D4CB`); the snapshot is stored alongside the per-bank triples in the MARKER's body.
3. **AC3** — `FORGET` (i.e. executing the marker word → `DOMARKER`, `src/inner_interpreter.asm:133`) restores every active bank's triple from the snapshot AND restores the descriptor-stub allocator tail; words defined in any bank since the MARKER are no longer reachable; their stubs are reclaimed (allocator-tail-rollback semantics — the next stub allocated after FORGET reuses the reclaimed region).
4. **AC4** — if the active bank list changed between MARKER and FORGET (e.g. `+BANK` / `-BANK` was called), the FORGET behaviour for those bank changes is **documented in source**: bank-list membership changes (`active_pages[]` / `bank_count`) are **NOT** rolled back by FORGET — FORGET only reverts dictionary tails (`bank-table[]` triples) + the stub allocator tail. The user-doc gotcha lands in Epic 22 polish.
5. **AC5** (gap-analysis mitigation per arch §"Gap Analysis") — the source comment explicitly references the architecture's gap-analysis note: **"MARKER stores both tails — per-bank dictionary tail AND stub-allocator tail — and FORGET reverts both."**
6. **AC6** (REPL probes — new isolated fixture `tests/banking_tests_21_1.fth`; see Dev Notes "Testing"):
   - **(a)** `MARKER ZZZ 5 BANK! : W5 1 ; 7 BANK! : W7 2 ; 0 BANK! ZZZ` then `' W5` raises an undefined-word error (`W5` is forgotten); same for `' W7`.
   - **(b)** `MARKER ZZZ : FOO ;` then `ZZZ` is invoked; `' FOO` raises undefined-word; **subsequent definitions allocate stubs from the reclaimed allocator-tail region** — verified via the stub-position probe (the stub xt of a bank-N word defined after FORGET equals the pre-MARKER allocator tail, i.e. the count dropped back to pre-MARKER level).
   - **(c)** cross-bank-MARKER survival: MARKER set while in bank 5, a word added in bank 7, FORGET via the bank-5-set marker correctly reclaims bank 7's tail.
7. **AC7** (probe surfaces + hardware smoke) — probes pass under the banking-capable emulator (`make test-repl-banking-isolated-21-1`); one hardware-typed probe batch covering AC6 (a)–(c) runs on real MicroBeast per S9 / NFR-P4-11. **(Post-HW-smoke recipe goes in the code-review closing message, not just here — `feedback_post_hw_smoke_steps_at_review`.)**
8. **AC8** (CCD-3 source citation) — the MARKER/FORGET extension cites `docs/antforth-banking-redesign.md §5.4` (per-bank state — S2 resolution) + the architecture §"Gap Analysis" stub-reclamation note (`architecture.md:1027`).
9. **AC9** (binary delta) — `wc -c build/antforth.com` grows by **≤ ~80 B** for this story (per-bank snapshot storage + restore loop + allocator-tail snapshot/restore); tracked against the Epic 21 ~150 B budget per Decision Impact Analysis. Per-component itemisation in Dev Notes "Binary budget".
10. **AC10** — `make test-repl` **≥ 974 PASS / 0 FAIL** on iz-cpm (single-bank MARKER/FORGET semantics preserved exactly for the bank-0 case); `make test-repl-banking` reports new probes PASS.

> **Adversarial review (`CR`) is NOT an acceptance criterion** and is not a dev-pass task — it runs separately via the `CR` command in fresh context after dev-pass close (PD-1, Story 13.5.0). Do not add a "trigger adversarial review" AC.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev Notes "Binary budget". **Do NOT inherit any number from this story text or the Epic 20 retro** — re-`wc -c` from a clean `make` (B.3 / Lesson 13.5-F). Note: at draft time the build artifact read **27888 B** while the Epic-20 retro reported **27625 B** at the v3.0.5 HEAD — these disagree, so the *only* trustworthy baseline is a fresh `make && wc -c build/antforth.com` at your dev-pass start. **→ Fresh clean-`make` baseline measured: 27888 B.**
- [x] Capture current `make test-repl` baseline pass count (expect ≥ 974) and `make test-repl-banking` / isolated-target counts (20-1 6/0, 20-2 5/0, 20-3 5/0, 19-3 15/0, 19-4 2/0, 19-5-1 2/0, straddle 3/3). **→ Measured: test-repl 975/0; banking-main 61/0; isolated 20-1 7, 20-2 5, 20-3 5, 19-3 15, 19-4 2, 19-5-1 2; straddle 3/3.**

### Task 1 — Extend `MARKER` to snapshot per-bank triples + stub-allocator tail (AC: #1, #2, #5)

- [x] Sub-1.1 In `w_MARKER_cf` (`src/system.asm:33`), **after** the existing `[saved_here(2)][saved_buckets(192)]` emission and **before** updating `HERE`, sync the **live** triple into `bank-table[triple_owner]` so the current bank's snapshot captures its true tail (the live `(here, latest, wordlist_head)` is in `UserArea` + `forth_wordlist`, *not* in `bank-table[current_bank]`, until a `BANK!` swaps it out). Use `UserArea.triple_owner` (not `current_bank` — they can diverge mid cross-bank dispatch; `triple_owner` is authoritative for "who owns the live triple"). `bank_offset_hl` (`src/banking.asm:226`) gives `&bank-table[A]`. **→ Implemented; mirrors `bank_triple_swap` save-half inline. KEY: `build_header` does NOT advance `UserArea.here` (it only saves it to `bh_entry_start`; the caller updates HERE at the very end), so at the sync point `UserArea.here == saved_here` — the literal "sync live triple" is correct AND matches the iz-cpm-safety invariant.**
- [x] Sub-1.2 Append the **full 29-entry `bank-table[]` region** (`BANK_TABLE_BASE = $D400`, `BANK_TABLE_SHELL_SIZE = 174` B) to the marker body via `LDIR` (source `$D400`, dest = body pointer in `DE`). See Dev Notes "Design" for why full-table beats active-only.
- [x] Sub-1.3 Append `UserArea.stub_alloc_tail` (2 B) to the body.
- [x] Sub-1.4 Update `HERE = DE` past the enlarged body (the existing `LD (IY+UserArea.here),E/+1,D` already does this from the post-`LDIR` `DE` — verify it still lands past the new fields). **→ Verified: `DE` is preserved across the live-triple sync (PUSH/POP) and advances through both new LDIRs + the stub-tail store, so the existing HERE update lands past all new fields.**
- [x] Sub-1.5 Add the AC5 source comment verbatim: `"MARKER stores both tails — per-bank dictionary tail AND stub-allocator tail — and FORGET reverts both."` plus the AC8 citations (`docs/antforth-banking-redesign.md §5.4`; `architecture.md` §"Gap Analysis" / `:1027`). Keep comments to **what + why-not-obvious only — no story/CR/date provenance in source** (`feedback_source_comment_discipline`).

### Task 2 — Extend `DOMARKER` to restore per-bank triples + stub-allocator tail (AC: #3, #4)

- [x] Sub-2.1 In `DOMARKER` (`src/inner_interpreter.asm:133`), **after** the existing `saved_here` + 192-byte bucket restore, advance the body pointer past `[saved_here(2)][saved_buckets(192)]` to the new fields. **→ No explicit advance needed: the existing 192-byte `LDIR` leaves `HL` pointing exactly at the new `bank_table` field.**
- [x] Sub-2.2 Restore the full `bank-table[]` region from the body via `LDIR` (source = body, dest `$D400`, count `174`). This does **not** touch `active_pages[]` ($D4AE) or `bank_count` — so bank-list membership is left as-is (AC4).
- [x] Sub-2.3 Restore `UserArea.stub_alloc_tail` (2 B) from the body.
- [x] Sub-2.4 **Reload the live triple** for the current owner: after the table is restored, copy `bank-table[triple_owner]` → live (`UserArea.here/latest` + `(forth_wordlist)` head) so the live allocation pointers reflect the reverted tail. (For the bank-0 / iz-cpm case `bank-table[0].here` == the just-restored `saved_here`, so this is consistent — see Dev Notes "iz-cpm safety".) Consider whether `bank_triple_swap` (`src/banking.asm:248`) or a smaller bespoke loader is cheaper for the byte budget. **→ Bespoke load-half loader used (NOT `bank_triple_swap`): its save-half would overwrite the just-restored `bank-table[owner]` with stale live values before reading them back, netting a no-op. The load-half-only path is also fewer bytes than CALL+arg-setup.**
- [x] Sub-2.5 Document AC4 in source at the DOMARKER restore site: "FORGET reverts dictionary tails + stub allocator only; `+BANK`/`-BANK` membership changes since MARKER are NOT rolled back (active_pages[]/bank_count untouched) — Epic 22 user-doc gotcha."

### Task 3 — New isolated REPL-probe fixture + Makefile target (AC: #6, #7, #10)

- [x] Sub-3.1 Create `tests/banking_tests_21_1.fth` — sentinel-delimited `result=-1` verdict probes (mirror the structure of `tests/banking_tests_20_2.fth` / `_20_3.fth`). Probes (a) forget-across-banks, (b) stub reclamation via stub-position probe, (c) cross-bank-MARKER survival. Keep **every line ≤ TIB_SIZE = 128** (`feedback_tib_size_inline_comments`). **0x1A-terminate the file** for real-hardware SLIDE transfer (`feedback_cpm_0x1a_eof_marker`). **→ Done (max line 79 chars; 0x1A appended). Probes (a)/(c) use `' name` + content-grep of the `<name> ?` undefined line — NOT `BL WORD name FIND`: a pre-existing antforth quirk makes explicit `FIND` still resolve a forgotten word, while the interpreter/`'` path (user-visible ground truth) correctly reports -13. Probe (c) invokes the bank-5 MARKER from its HOME bank (5): a banked MARKER has no real dispatch stub (xt = CFA in its window), so cross-bank invocation from bank 0 is unsupported — empirically hangs.**
- [x] Sub-3.2 Add `make test-repl-banking-isolated-21-1` target + `.PHONY` entry, mirroring the `test-repl-banking-isolated-20-2` recipe (`Makefile:872`) / `-20-3` (`Makefile:914`). Behavioural bank-switch+lookup probes **must** live in this isolated fixture, not the main `tests/banking_tests.fth` suite (Dev Notes "Testing" explains why).
- [x] Sub-3.3 Run `make test-repl` (≥ 974 / 0), `make test-repl-banking`, all existing isolated targets (no regressions), and the new `-21-1` target (all PASS). **→ test-repl 975/0; banking-main 61/0; isolated 20-1 7, 20-2 5, 20-3 5, 19-3 15, 19-4 2, 19-5-1 2 (all unchanged); 21-1 4/0; straddle 3/3.**

### Task 4 — Verify binary budget + doc-sync (AC: #9)

- [x] Sub-4.1 `make && wc -c build/antforth.com`; compute delta vs the Sub-baseline; assert ≤ ~80 B. If over, record the per-component overrun against the Epic 21 ~150 B envelope (don't SCP unless the epic total is threatened — `project_epic17_envelope.md`, do not re-litigate). **→ 27888 → 27970 = +82 B. Within the AC9 ~80 B line (Dev Notes allow ~90–100 B before alarm). Leaves ~68 B of the Epic 21 ~150 B envelope for 21.2 (~70 B est) — epic total NOT threatened; no SCP.**
- [x] Sub-4.2 `make check-doc-sync` → 0 drift. **→ 0 drift (exit 0; 31 pre-existing advisory items, none drift).**

## Dev Notes

### Design — how to snapshot "every active bank's triple"

The live `(here, latest, wordlist_head)` triple lives in `UserArea.here/latest` + the `forth_wordlist` next-link cell; `bank-table[]` holds the **parked** triples for banks that aren't currently mapped. `BANK!` (`src/banking.asm:116`) and `bank_triple_swap` (`src/banking.asm:248`) swap live↔table on every switch; `UserArea.triple_owner` records which bank currently owns the live copy (it can differ from `current_bank` during cross-bank dispatch — `exception.asm` uses `triple_owner` at frame+9 to restore on caught THROW).

**Recommended snapshot strategy: full-table (174 B), not active-only.**
- *Full-table* — `MARKER` syncs live→`bank-table[triple_owner]`, then `LDIR`s the whole 29-entry/174-byte region into the body (+2 B stub tail). `DOMARKER` `LDIR`s it back and reloads the live triple. **Cheapest in code** (two `LDIR`s, no per-bank loop, no count byte), satisfies AC1 ("covers all banks present in the active list" — trivially, it covers all 29 slots), and inactive-bank entries are inert (never consulted until that bank is `+BANK`'d). Cost: every marker body grows ~176 B of **dictionary RAM** (not binary) — acceptable; markers are infrequent and TPA dictionary is the cheap resource.
- *Active-only* — store `bank_count` + only the active entries (`bank_count × 6` B). Smaller bodies, but needs a snapshot loop + restore loop + a stored count, costing **more binary** (the AC9-budgeted resource). Reject unless byte budget forces it.

**AC4 falls out naturally from full-table restore:** restoring the 174-byte triple region touches only `$D400..$D4AD`. `active_pages[]` ($D4AE) and `bank_count` are *outside* that region, so `+BANK`/`-BANK` membership changes between MARKER and FORGET are inherently not rolled back. Just document it (Sub-2.5).

### iz-cpm safety (AC10 — the bank-0 case must keep passing)

For the non-banking build, `bank_count = 0`, `current_bank = triple_owner = 0`. The existing `[saved_here][saved_buckets]` restore is what drives bank-0 dictionary correctness and **must be preserved byte-for-byte in behaviour** (keep it; append the new fields after it — do **not** rewrite the existing path). The appended bank-table restore is a consistent quasi-no-op for bank 0: `bank-table[0].here` was captured at MARKER time == `saved_here`, so reloading the live triple from the restored table reasserts the same `HERE`. Net behaviour on iz-cpm is unchanged; `make test-repl` must still report ≥ 974/0. No gating flag is required (the unconditional append is harmless at `bank_count = 0`), which is also the smallest-binary choice.

### Binary budget (AC9) — per-component itemisation

> Itemised independently per the B.2 / Lesson 13.5-C rule (no "mirrors prior arm" analogy as the load-bearing estimate). Figures are opcode-byte estimates; the gate is the measured `wc -c` delta at Sub-4.1, **not** this table.

**`MARKER` (`w_MARKER_cf`):**
| Component | Est. bytes |
|---|---|
| Sync live→`bank-table[triple_owner]` (load `triple_owner`; `CALL bank_offset_hl`; `EX DE,HL`; `LD HL,user_area+here`; `LD BC,4`; `LDIR`; `LD HL,(forth_wordlist)`; store 2 B) | ~24 |
| `LDIR` 174-byte `bank-table[]` → body (`LD HL,$D400`; `LD BC,174`; `LDIR` — `DE` already = body) | ~7 |
| Store `stub_alloc_tail` (2 B) → body (`LD L,(IY+tail)`; `LD H,(IY+tail+1)`; `LD (DE),L`; `INC DE`; `LD (DE),H`; `INC DE`) | ~12 |
| Body-pointer bookkeeping / `PUSH`-`POP` balance | ~5 |
| **MARKER subtotal** | **~48** |

**`DOMARKER`:**
| Component | Est. bytes |
|---|---|
| Advance body ptr past `[saved_here][saved_buckets]` to new fields | ~4 |
| `LDIR` body → 174-byte `bank-table[]` (`LD DE,$D400`; `LD BC,174`; `LDIR`) | ~7 |
| Restore `stub_alloc_tail` (2 B) from body | ~12 |
| Reload live triple from `bank-table[triple_owner]` (bespoke loader or `CALL bank_triple_swap`) | ~10 |
| **DOMARKER subtotal** | **~33** |

**Estimated total ≈ ~81 B** — at the AC9 ~80 B line. Realistic outcomes on this codebase have run ~1.25× over per-component asm estimates (`feedback_kernel_ldir_estimate_overshoot`), so a measured ~90–100 B would not be alarming; it would draw from the Epic 21 ~150 B envelope (21.1 ~80 + 21.2 ~70). Only evaluate an SCP if the **epic** total is threatened (`project_epic17_envelope.md` — cite, don't re-litigate). The Epic-20 envelope multiplier is **void here** only if the mechanism is substituted; this story is pure-addition lifecycle plumbing (no substitution), so normal calibration applies (Epic-20 retro key takeaway #1).

### Testing — why behavioural bank-switch probes need an isolated fixture

The main `tests/banking_tests.fth` suite's own dictionary crosses `$8000` mid-file, so its (bank-shared, fat-pointer) hash-bucket chains contain window-resident entries; **any token lookup while a non-zero bank is mapped can walk a chain through the `$8000` window and read the foreign page** (a `-13` strand; documented in `banking_tests.fth`'s probe-19.5.1-B note and `feedback_phase4_probe_bank_switch_limitation`). Epic 20's fat-pointer FIND pages-in before deref on the *lookup* path, but the safe, established pattern for behavioural `BANK!`-then-lookup probes is still a **dedicated isolated fixture** with only the probe code loaded (`tests/banking_tests_19_5_1.fth`, `_20_1`..`_20_3` precedent). AC6 (a) and (c) do exactly this (`5 BANK! : W5 ; ... ' W5`), so they **must** go in `tests/banking_tests_21_1.fth`, not the main suite.

**Stub-position probe (AC6 b) — read the allocator tail without an absolute address:** the xt of a freshly-defined **bank-N** word *is* the stub address (`xt-as-stub-address` contract), and the allocator hands out stubs sequentially from `STUB_ALLOC_BASE = $D4CB` in 4-byte strides (Story 20.3 confirmed: first boot stub xt = `$D4CB`, second = `$D4CF`). So:
1. Before MARKER, in some bank, define a throwaway bank word and capture its xt `T0` (= current allocator tail). (Or capture `$D4CB` at fresh boot.)
2. `MARKER ZZZ`, then in a bank define `FOO` (consumes ≥1 stub; tail advances).
3. `ZZZ` (FORGET) — should restore the tail.
4. Define a new bank word; its xt must `=` the **pre-MARKER** tail (`T0`-relative), proving the region was reclaimed and reused, not leaked.

This is more robust than reading `UserArea.stub_alloc_tail` by absolute address (which isn't a fixed literal). Sentinel-bound the verdict (`result=-1`) like `banking_tests_20_3.fth`.

### Source tree components to touch

| File | What |
|---|---|
| `src/system.asm:33` (`w_MARKER_cf`) | Snapshot per-bank triples + stub tail (Task 1) |
| `src/inner_interpreter.asm:133` (`DOMARKER`) | Restore per-bank triples + stub tail (Task 2) |
| `tests/banking_tests_21_1.fth` (new) | Isolated behavioural probes (Task 3) |
| `Makefile` (`.PHONY:52`, new target near `:872`/`:914`) | `test-repl-banking-isolated-21-1` |

**Do not touch:** `src/banking.asm` bank-table / allocator definitions (reuse `bank_offset_hl`, `bank_triple_swap`, the `STUB_*` EQUs as-is); `active_pages[]` / `bank_count` (AC4 — not rolled back).

### Key facts (verified at draft time)

- `bank-table[]`: `BANK_TABLE_BASE = $D400` (`constants.asm:15`); 29 entries × 6 B = 174 B (`BANK_TABLE_SHELL_SIZE`, `banking.asm:12-19`); entry = `[here:2][latest:2][wordlist_head:2]`.
- `active_pages[]`: `$D4AE`, 29 B (1 B/bank); `bank_count` = `UserArea.bank_count`.
- Stub allocator: `STUB_ALLOC_BASE = $D4CB` (`constants.asm:25`); 4 B/stub; region `$D4CB..$DBFF` = 1845 B = 461-stub cap; **0/461 at boot**; tail = `UserArea.stub_alloc_tail` (`structures.asm:53`); `stub_allocate` at `banking.asm:787`; stub-count = `(stub_alloc_tail − $D4CB) / 4`.
- Current MARKER body: `[saved_here(2)][saved_buckets(192)]` (192 = 64 × 3-B fat bucket heads — Story 20.1). `DOMARKER` restores `HERE` + the 192-byte `forth_wordlist` bucket array.
- `triple_owner` (`UserArea`) is authoritative for "who owns the live triple"; `current_bank` can diverge during cross-bank dispatch.
- Stub allocation fires only when `current_bank > 0` (`:` semicolon `compiler.asm:673`; `CREATE` `compiler.asm:814`) — bank-0 words keep the legacy CFA-as-xt path and allocate no stub. So the reclamation matters only for banked words; the iz-cpm path is stub-free.

### Project Structure Notes

- Aligns with the established per-story banking layout: kernel changes in `src/`, isolated behavioural probes in `tests/banking_tests_NN_M.fth`, dedicated `make test-repl-banking-isolated-NN-M` target. No structural variance.
- Reuses existing primitives (`bank_offset_hl`, `bank_triple_swap`, `STUB_*` EQUs) rather than introducing new mechanisms — keeps the binary delta inside the AC9 budget.

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:1050-1071`] — Story 21.1 spec (ACs verbatim).
- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:1034-1048`] — Epic 21 goal / FRs (FR-P4-40) / NFRs (NFR-P4-8).
- [Source: `_bmad-output/planning-artifacts/architecture.md:1021-1027`] — §"Gap Analysis": "the MARKER stores both tails and FORGET reverts both" (AC5/AC8).
- [Source: `docs/antforth-banking-redesign.md` §5.4 (per-bank state — S2 resolution, line 109)] — per-bank `(here, latest, wordlist_head)` triple (AC8).
- [Source: `src/system.asm:33-115` `w_MARKER_cf`; `src/inner_interpreter.asm:133-164` `DOMARKER`] — extension points.
- [Source: `src/banking.asm:12-30` table/active/stub EQUs; `:226-246` `bank_offset_hl`; `:248-286` `bank_triple_swap`; `:787-802` `stub_allocate`] — primitives to reuse.
- [Source: `src/structures.asm:53` `stub_alloc_tail`; `src/constants.asm:15,25` `BANK_TABLE_BASE`/`STUB_ALLOC_BASE`] — addresses.
- [Source: `Makefile:872` `test-repl-banking-isolated-20-2`; `:914` `-20-3`; `:52` `.PHONY`] — isolated-target recipe to mirror.
- [Source: `_bmad-output/implementation-artifacts/20-3-...md:195-261`] — CCD-4 stub-count metric technique + isolated-fixture precedent.
- [Memory: `feedback_phase4_probe_bank_switch_limitation`, `feedback_tib_size_inline_comments`, `feedback_cpm_0x1a_eof_marker`, `feedback_source_comment_discipline`, `feedback_post_hw_smoke_steps_at_review`, `feedback_kernel_ldir_estimate_overshoot`, `project_epic17_envelope`, `project_bank_table_clone_at_cold`] — applicable disciplines.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — BMad dev-story workflow.

### Debug Log References

- Exploratory marker-invocation sweep (`/tmp/explore_marker.fth`): confirmed (A) bank-0 marker forgets a bank-7 word from bank 0; (B) a bank-5 marker invoked **from bank 5** forgets a bank-7 word; (C) a bank-5 marker invoked **from bank 0 HANGS** — banked MARKER has no real dispatch stub. Shaped probe (c) to the scenario-B pattern.
- `FIND`-vs-interpreter discrepancy isolated against a stashed baseline build (no 21.1 changes): `BL WORD <forgotten> FIND` returns -1 (found) in BOTH baseline and 21.1 builds, while the interpreter/`'` path reports -13. Pre-existing quirk, not introduced by this story → probes use the `'` + content-grep ground-truth path.
- Stub-position probe verified: `' _p2` (pre-FORGET) and `' _p3` (post-FORGET, same bank) both = `$D4CF` → `result=-1`, proving allocator-tail rollback + region reuse.

### Completion Notes List

- **AC1/AC2/AC5** — `w_MARKER_cf` (`src/system.asm`) extended: syncs the live triple into `bank-table[triple_owner]`, then appends the full 174-byte `bank-table[]` region + the 2-byte `stub_alloc_tail` to the marker body. AC5 verbatim "both tails" comment + AC8 citations added. Body layout doc-comment updated to `[saved_here(2)][saved_buckets(192)][bank_table(174)][stub_tail(2)]`.
- **AC3/AC4** — `DOMARKER` (`src/inner_interpreter.asm`) extended: restores the full `bank-table[]` region + `stub_alloc_tail`, then reloads the live triple for `triple_owner`. AC4 documented in source (active_pages[]/bank_count outside the restored $D400..$D4AD range → membership NOT rolled back).
- **AC6/AC7/AC10** — new isolated fixture `tests/banking_tests_21_1.fth` + `make test-repl-banking-isolated-21-1` (4/4 PASS): (a) forget-across-banks, (b) stub-tail reclamation (`result=-1`), (c) cross-bank-MARKER survival. iz-cpm `make test-repl` 975/0 (single-bank MARKER/FORGET preserved byte-for-byte in behaviour — existing `[saved_here][saved_buckets]` path untouched, new fields appended). **AC7 hardware-smoke batch is deferred to a real-MicroBeast run (recipe to be posted in the code-review closing message per `feedback_post_hw_smoke_steps_at_review`).**
- **AC9** — +82 B (27888 → 27970), within tolerance; Epic 21 envelope not threatened.
- Design note: `build_header` does not advance `UserArea.here`, so the Sub-1.1 live-triple sync captures `here == saved_here` — resolving the apparent tension between "sync live triple" (Sub-1.1) and the iz-cpm-safety invariant "bank-table[0].here == saved_here".

### File List

- `src/system.asm` (modified) — `w_MARKER_cf`: per-bank triple + stub-tail snapshot; body-layout doc-comment.
- `src/inner_interpreter.asm` (modified) — `DOMARKER`: per-bank triple + stub-tail restore + live-triple reload; body-layout doc-comment.
- `tests/banking_tests_21_1.fth` (new) — isolated MARKER/FORGET reclamation probes (a/b/c).
- `Makefile` (modified) — `test-repl-banking-isolated-21-1` target + `.PHONY` entry.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — story status ready-for-dev → in-progress → review.

### Change Log

- 2026-06-12 — Story 21.1 dev-pass: MARKER/FORGET extended to snapshot/restore every active bank's dictionary tail (full 174-byte `bank-table[]` region) plus the descriptor-stub allocator tail; new isolated probe fixture + Makefile target; +82 B; gates green (test-repl 975/0, banking-main 61/0, isolated targets unchanged + 21-1 4/0, straddle 3/3, doc-sync 0 drift). Status → review.
