# Code Review — Stories 21.1 + 21.2 (banking lifecycle)

**Date:** 2026-06-12
**Reviewer:** Claude Code `/code-review` (high effort, recall-biased)
**Scope:** `git diff origin/banked_memory...HEAD` (5 commits: Stories 21.1 + 21.2) + working-tree version bump 3.0.5→3.0.6.
**Source touched:** `src/system.asm` (MARKER), `src/inner_interpreter.asm` (DOMARKER), `src/outer_interpreter.asm` (QMARK-BANK / QSAVE-BANK / REASSERT-BANK, `.interp_execute`, `.quit_loop`), `src/structures.asm` (`interp_bank_pending`).

## Method
7 finder angles (3 correctness + 3 cleanup + 1 altitude), ~30 candidates, then per-candidate verification (CONFIRMED / PLAUSIBLE / REFUTED).

## Refuted candidates (recorded as design-confirmations — do NOT "fix")
- **DOMARKER reload from `bank-table[triple_owner]`** (instead of old `saved_here→HERE` write) is **correct**. `triple_owner` always tracks `current_bank` (BANK! writes both together), so the live HERE must describe the windowed bank. The *old* direct `saved_here→HERE` write was the latent bug (it stamped a non-windowed bank-0 address into live HERE). The full-table LDIR already reverts bank-table[0]'s tail, so bank 0 is rolled back regardless.
- **MARKER "leaks its own stub" on a bank>0 FORGET** — does NOT happen. `build_header` (compiler.asm:137-397) never calls `stub_allocate`; stub allocation is done only by `:`/CREATE/CODE callers AFTER build_header, gated on bank>0. MARKER is not one of those callers, so it allocates no stub for itself and `stub_alloc_tail` is unchanged across MARKER — the body's captured tail equals the pre-MARKER value.
- **REASSERT-BANK low-byte-only compare of saved/current bank** — not reachable; `current_bank.high` and `saved_bank.high` are invariably 0 (QSAVE explicitly zeroes saved_bank+1).
- **Altitude: "move saved_bank recognition into BANK! gated by source_id"** — rejected. source_id alone cannot distinguish a *typed* `BANK!` from a colon word that internally calls `BANK!`; the xt-identity check at `.interp_execute` is the mechanism that draws that line (a nested BANK! runs under its own DOCOL and never re-enters that site). The current location is the right layer.

---

## Findings (ranked most-severe first)

### 1. [CONFIRMED · correctness] REASSERT-BANK maps `active_pages[saved_bank]` with no bounds check
**`src/outer_interpreter.asm:404`** (in `w_REASSERT_BANK_cf`)

REASSERT-BANK builds `&active_pages[saved_bank]` and maps that page into MMU slot 2 with **no `saved_bank < bank_count` guard** — unlike real `BANK!` (`banking.asm:172-174`, `CP (IY+bank_count) / JR NC,.abort_bank`). `saved_bank` is set by QSAVE-BANK to a then-valid `current_bank`, but `-BANK` (`banking.asm:488`, `DEC bank_count`) and `BANKS-CLEAR` (`banking.asm:531`, `LD (IY+bank_count),0`) shrink `bank_count` **without reconciling `saved_bank`** (BANKS-CLEAR's own docstring confirms it leaves active_pages[], current_bank, and saved_bank untouched).

**Reachable failure sequence:**
1. Add 3 banks; `2 BANK!` interactive → `current_bank = saved_bank = 2`.
2. `-BANK` twice → `bank_count = 1`; `saved_bank` still 2 (never reconciled).
3. An uncaught cross-bank THROW leaves `current_bank != 2` (`exception.asm` `.throw_uncaught` explicitly leaves current_bank at the throwing bank "QUIT re-asserts the saved bank downstream").
4. QUIT re-entry → REASSERT sees `saved(2) != current` → reads `active_pages[2]` (now past the valid `[0..1)` region — a vacated/garbage byte) → `mbb_set_slot2` maps an arbitrary physical page → sets `current_bank = 2` (out of range).

Silent slot-2 / MMU corruption on the exact post-ABORT path the feature was added to make safe. **Fix options:** bounds-check `saved_bank < bank_count` in REASSERT (fall back to bank 0 / no-op when stale), or reconcile `saved_bank` inside `-BANK` and `BANKS-CLEAR`.

### 2. [cleanup · simplification] Dead `saved_here` field in MARKER body
**`src/inner_interpreter.asm:145`** (skip) / **`src/system.asm:79`** (emit)

MARKER still emits `saved_here` into body[0..1], but DOMARKER now skips it (`INC HL / INC HL`) and takes HERE from the reloaded `bank-table[owner]` triple. The field is written-but-never-read; two comment blocks (inner_interpreter.asm:145-150, system.asm) exist only to explain why a stored field is ignored. Either drop `saved_here` (body 370→368 B, simpler layout) or stop documenting the skipped read as load-bearing.

### 3. [cleanup · reuse] Triple save/load LDIR cascade duplicated 3×
**`src/system.asm:53`** (MARKER snapshot) / **`src/inner_interpreter.asm:190`** (DOMARKER reload)

MARKER's pre-build_header snapshot is a byte-for-byte copy of `bank_triple_swap`'s SAVE half (`banking.asm:264-275`); DOMARKER's reload duplicates its LOAD half. Any change to the triple layout must be hand-applied to all three copies; a miss silently corrupts only the rarely-exercised MARKER/FORGET path. Factor `bank_triple_swap` into `bank_triple_save` / `bank_triple_load` halves and call them.

### 4. [cleanup · reuse] REASSERT-BANK re-implements BANK!'s `.window_ok` activation
**`src/outer_interpreter.asm:396`** vs **`src/banking.asm:193-210`**

The map-slot2 + write current_bank/triple_owner + `PUSH DE / bank_triple_swap / POP DE` sequence now exists in `BANK!` (`.window_ok`), `REASSERT-BANK`, and the THROW caught-path (`exception.asm`). Three copies of "activate live bank C"; an ordering fix must be replicated thrice. Factor the `.window_ok` tail into a shared "switch-live-bank-to-C" helper.

### 5. [cleanup · efficiency] MARKER body 194→370 B; ~176 B inert on single-bank build
**`src/system.asm:142`**

MARKER always appends the full 174-byte bank-table[] + 2-byte stub tail, even on the single-bank iz-cpm build where bank-table[1..28] is permanently inert (`bank_count` stays 1). DOMARKER LDIRs all 174 B back on every FORGET. Each MARKER burns ~176 extra TPA bytes for provably-constant data, and each FORGET does ~176 B of pointless copying. A `bank_count`-bounded copy (`BC = bank_count*6`) would snapshot only live entries. (The full-table copy was a deliberate code-size choice; the per-instance data cost was not weighed.)

---

## JSON (for dev-agent ingest)

```json
[
  {"file":"src/outer_interpreter.asm","line":404,"severity":"correctness","verdict":"CONFIRMED","summary":"REASSERT-BANK maps active_pages[saved_bank] into MMU slot 2 with no saved_bank<bank_count guard (unlike BANK!); -BANK/BANKS-CLEAR shrink bank_count without reconciling saved_bank, so the next ABORT-driven QUIT re-entry maps a stale/out-of-range page and sets an invalid current_bank.","fix":"Bounds-check saved_bank<bank_count in REASSERT (fall back to bank 0/no-op), or reconcile saved_bank in -BANK and BANKS-CLEAR."},
  {"file":"src/inner_interpreter.asm","line":145,"severity":"cleanup-simplification","verdict":"CONFIRMED","summary":"Dead field: MARKER emits saved_here (system.asm:79) but DOMARKER skips it and takes HERE from the reloaded bank-table[owner] triple. Written-but-never-read; two comment blocks explain why a stored field is ignored.","fix":"Drop saved_here (body 370->368 B) or stop documenting the skipped read as load-bearing."},
  {"file":"src/system.asm","line":53,"severity":"cleanup-reuse","verdict":"CONFIRMED","summary":"MARKER snapshot block = byte-for-byte copy of bank_triple_swap SAVE half (banking.asm:264-275); DOMARKER reload (inner_interpreter.asm:190) duplicates the LOAD half. Triple cascade now in 3 places.","fix":"Factor bank_triple_swap into bank_triple_save/bank_triple_load; call from MARKER and DOMARKER."},
  {"file":"src/outer_interpreter.asm","line":396,"severity":"cleanup-reuse","verdict":"CONFIRMED","summary":"REASSERT-BANK re-implements BANK!'s .window_ok activation (banking.asm:193-210); same core also in exception.asm THROW path. Three copies of 'activate live bank C'.","fix":"Factor the .window_ok tail into a shared switch-live-bank-to-C helper."},
  {"file":"src/system.asm","line":142,"severity":"cleanup-efficiency","verdict":"CONFIRMED","summary":"MARKER body grew 194->370 B by always appending full 174 B bank-table[] + 2 B stub tail; ~176 B inert on single-bank build, and DOMARKER copies all 174 B back per FORGET.","fix":"bank_count-bounded copy (BC = bank_count*6) to snapshot only live entries."}
]
```

---

## Resolution — CR-fix dev pass (2026-06-13, dev agent Amelia)

All 5 findings fixed. Kernel 28069 B → **28049 B** (−20 B). Gates green:
`make test` (asm threads) · `test-repl-banking` · isolated 19.3/19.4/19.5.1/20.1/20.2/20.3/21.1/21.2/21.3 · `test-straddle-regression` · new `test-repl-cr-21-3`.

- **#1 [correctness] — FIXED.** `w_REASSERT_BANK_cf` (`src/outer_interpreter.asm`) now bounds-checks `saved_bank < bank_count` (`CP (IY+bank_count) / JR NC, .rab_done`) before the activation, mirroring BANK!'s precondition. A stale `saved_bank` left behind by `-BANK`/`BANKS-CLEAR` now no-ops the re-assert (user keeps the post-unwind live bank) instead of mapping a vacated/out-of-range `active_pages[]` byte into MMU slot 2. Chose the consumer-side guard over reconciling `saved_bank` in `-BANK`/`BANKS-CLEAR` because REASSERT is the *sole* reader of `saved_bank` (grep-verified), so one guard closes the whole class. Behavioural emulator repro is not added: driving the stale state needs a multi-bank teardown the harness can't safely run from window-resident code (feedback_phase4_probe_bank_switch_limitation); the fix is a 3-instruction guard with the reasoning above.
- **#2 [cleanup] — FIXED.** `saved_here` field dropped from the MARKER body. `src/system.asm` no longer emits it; `src/inner_interpreter.asm` DOMARKER no longer skips it; both body-layout docstrings updated. HERE is taken authoritatively from the reloaded `bank-table[owner]` triple — the new `test-repl-cr-21-3` probe-A proves the revert is correct without the field.
- **#3 [cleanup] — FIXED.** `bank_triple_swap` split into `bank_triple_save` / `bank_triple_load` (`src/banking.asm`); `swap` is now `save; load`. MARKER's pre-build_header sync calls `bank_triple_save`; DOMARKER's reload calls `bank_triple_load`. Two hand-copied LDIR cascades eliminated.
- **#4 [cleanup] — FIXED (2 of 3 sites).** `switch_live_bank_to_c` helper (`src/banking.asm`) now holds the map-slot2 + current_bank/triple_owner + triple-swap sequence; BANK! `.window_ok` and `REASSERT-BANK` both call it. The exception.asm THROW caught-path is **deliberately not** folded in: it restores `current_bank` from CATCH frame +8 but `triple_owner` from +9 (they diverge across a live cross-bank dispatch) and swaps the triple *conditionally* — a different shape, so sharing the "both ← one C" helper would lose the +8/+9 distinction. Documented at the helper.
- **#5 [cleanup] — FIXED.** MARKER snapshots only the live prefix: `snap_count = max(bank_count, triple_owner+1)` entries (`snap_count*6` bytes), with `snap_count` stored in the body and read back by DOMARKER. The `owner+1` clause guarantees the owner entry (reloaded at FORGET) is always captured — required for correctness when `bank_count == 0` (fresh boot / nested MARKER) or after a `BANKS-CLEAR` left `owner > bank_count` — and forces `snap_count ≥ 1`, which also rules out the `BC==0 → LDIR-copies-64KB` trap. At BANKS=12 (emulator) a MARKER body shrinks from 370 B to ~265 B; on a bank_count=0/1 build it shrinks to ~195–201 B.

New regression: `tests/cr_21_3_fixes.fth` + `make test-repl-cr-21-3` — nested MARKER reverts HERE to the pre-outer-marker value, all nested-defined words (incl. the inner marker) are forgotten, and the dictionary keeps working post-FORGET.

**File List:** `src/banking.asm`, `src/outer_interpreter.asm`, `src/system.asm`, `src/inner_interpreter.asm`, `tests/cr_21_3_fixes.fth`, `Makefile`.

### HW UAT — PASS on real MicroBeast (2026-06-13, v3.0.6, transcript beastty-20260613-071441.bin)
- `include p213intg.fth`: `xcall=-1` · `recl=-1` · `result=-1` · suite-end present (cross-bank dispatch, stub-tail reclamation, bank+slot-2 restore).
- `marker zz : w1 ; : w2 ; zz  ' w1` → `w1 ?` (bounded MARKER/FORGET + saved_here drop, #5/#2).
- `marker ma : n1 ; marker mb : n2 ; ma  ' n2` → `n2 ?` (nested MARKER owner-capture, #5).
- `3 bank! : wb 7 ; 0 bank! 3 bank! wb .` → `7` (shared `.window_ok` activation, #4).
- `3 bank! abort` → `bank@ .` → `3` (QUIT re-assert, not stranded).
- `zz` → `zz ?` (self-FORGET'd marker gone).
- Mid-capture binary noise = a `connection lost` SLIDE transfer dumping the .com bytes onto the `B>` prompt (host serial mishap), NOT a kernel fault; the clean reboot + re-run confirms a healthy kernel. Deferred-hardware-smoke obligation discharged.
