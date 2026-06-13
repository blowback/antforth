# Story 22.1: `.BANKS` final formatting polish + per-bank used / free reflect real `here` values

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-12 by create-story workflow.
     Story 22.1 is the FIRST story of Epic 22 (Polish + Phase-4 close-out)
     and the first binary-delta story since Epic 21. It promotes `.BANKS`
     from the Story-17.5 minimal/placeholder form (used=0, free=16384 for
     every row) to its Phase-4 FINAL form: per-bank used/free computed from
     each bank's REAL `here` now that Epic 19 made per-bank HERE live.

     FOUR load-bearing findings were resolved at DRAFT TIME by reading the
     live source (B.4 / PD-2 figure-drift discipline). Do NOT re-discover
     them at dev-pass:

       (1) BANK-0 IS SPECIAL. The epics-file AC1 formula
           "used = here - bank-base-address; free = bank-size - used"
           does NOT hold uniformly. Bank 0 is the kernel/portal dictionary
           (architecture.md:922 "the Phase-1/2/3 single-dictionary-pointer
           model is now bank-0's case"): its base = `kernel_end`
           (src/antforth.asm:819) and its ceiling = `BANK_TABLE_BASE` =
           $D400 (the banner already computes bank-0 free this way at
           src/antforth.asm:280-289). Banks 1..28 have base = $8000
           (SLOT2_WINDOW_BASE) and ceiling = $C000 (size $4000 = 16384) —
           the COLD `.bank_here_init` loop seeds bank-table[1..28].here =
           $8000 at src/antforth.asm:221-229. The formula must branch on
           bank index 0. See AC1 + Dev Notes "Per-bank memory model".

       (2) CURRENT-BANK HERE IS LIVE IN UserArea; OTHERS ARE IN bank-table.
           `bank_triple_swap` (src/banking.asm:263-286) flushes
           UserArea.here → bank-table[old] only at BANK! time, so the
           CURRENT bank's bank-table[N].here is STALE until a BANK! away.
           `.BANKS` must read `(IY+UserArea.here)` for the row whose index
           == current_bank, and `bank-table[N].here` (offset 0 of the
           6-byte entry) for every other row. Getting this wrong makes the
           current bank's used/free read a stale value.

       (3) M1 MIXED-BASE BUG is INHERITED HERE. Story 17.5's code-review
           filed deferred finding M1 (17.5 story file :549): `.BANKS`
           mixes rendering bases — BANK col hardcoded decimal, PAGE
           hardcoded hex, USED/FREE were literal decimal STRINGS, but the
           totals FREE follows BASE via `D.R`. In HEX mode the totals print
           "30000" alongside per-row "16384". 17.5 explicitly assigned the
           unified-base decision to Story 22.1. Now that USED/FREE become
           COMPUTED (not literals), the base question is unavoidable —
           resolved as Q1 below (recommend: byte-count columns forced
           decimal, PAGE stays hex, base-independent).

       (4) BEHAVIOURAL "DEFINE-THEN-CHECK" PROBE NEEDS AN ISOLATED FIXTURE.
           AC5(a) ("5 BANK! : SOME-WORD ; → used in bank 5 increases")
           switches to a non-zero bank and defines — exactly the pattern
           that corrupts the main suite's straddling dictionary bucket
           chain (`feedback_phase4_probe_bank_switch_limitation`, ADR 19.5
           DR-1). It MUST live in a new isolated fixture
           `tests/banking_tests_22_1.fth` with a `make
           test-repl-banking-isolated-22-1` target (mirror 21-1/21-2). The
           surface-agnostic header/marker/totals probes can stay in the
           main `tests/banking_tests.fth`, but the placeholder-guard Probe
           Z there must be RETARGETED (it currently asserts the literal
           `0  16384` — that is now wrong for any non-empty bank). -->

## Story

As Marc (OG retrocomputing user) inspecting bank state with `.BANKS`,
I want a polished, column-stable status table whose per-bank **used** / **free** columns reflect each bank's **real** `here` value (now that Epic 19's per-bank dictionary state is live), plus a totals row and CCD-4 summary rows,
So that `.BANKS` is the canonical observability tool for banking — not the Story-17.5 placeholder that printed `0 / 16384` for every bank regardless of what I had compiled into it.

## Acceptance Criteria

> Final form of FR-P4-6. Promotes the Story-17.5 `.BANKS` minimal form (zero-used / full-free placeholders) to real per-bank used/free, adds CCD-4 summary rows (F2 mitigation), and resolves the Story-17.5 deferred M1 mixed-base finding. The epics-file Story 22.1 AC1 formula is re-specced here against repo reality: **bank 0 is special** (kernel dictionary, base=`kernel_end`, ceiling=`$D400`); banks 1..28 use base=`$8000`, ceiling=`$C000`. FRs covered: FR-P4-6 (final form). Findings advanced: F2 (stub-cost visibility surfaced in `.BANKS` summary rows).

**Given** Story 17.5 shipped `.BANKS` in minimal/working form (per-bank used=0, free=16384 literal placeholders; src/banking.asm:540-727), AND Epic 19 made per-bank `here`/`latest`/`wordlist_head` real (the `bank_triple_swap` LDIR at BANK! time, src/banking.asm:263-286; bank-table[1..28].here COLD-seeded to `$8000` at src/antforth.asm:221-229), AND Epic 21 has closed (21.3 ships the v3.0.6 banner; this story builds on top of that — re-baseline at dev-pass start),
**When** Story 22.1 is dev-passed,

**Then** **AC1** (per-bank used/free reflect real `here` — FR-P4-6 final, **bank-0-special**) — the per-row USED/FREE columns in `.BANKS` (src/banking.asm `w_DOT_BANKS_cf`) are computed from each bank's real `here`, replacing the `str_used_free_crlf` literal `"    0  16384"`:
- **For the row whose logical index == `(IY+UserArea.current_bank)`**: read the LIVE `here` from `(IY+UserArea.here)` — NOT `bank-table[current].here`, which is stale until a BANK! away (finding (2)).
- **For every other row N**: read the saved `here` from `bank-table[N].here` (offset 0 of the 6-byte entry; `BANK_TABLE_BASE = $D400`; per-entry stride `BANK_TABLE_ENTRY_SIZE = 6`; use the existing `bank_offset_hl` helper at src/banking.asm:233-246).
- **Bank N ≥ 1** (banked window): `used = here − $8000`; `free = $C000 − here` (equivalently `$4000 − used`; `SLOT2_WINDOW_BASE = $8000`, size `$4000` = 16384).
- **Bank 0** (kernel/portal dictionary): `used = here − kernel_end`; `free = $D400 − here` (`BANK_TABLE_BASE = $D400`; `kernel_end` is the assembler label at src/antforth.asm:819; bank-0 free already computed this exact way by the banner at src/antforth.asm:280-289).
- Both `used` and `free` are single 16-bit values per row (max `used` in a banked window = `$4000` = 16384; bank-0 `used` ≤ `$D400 − kernel_end` ≈ a few KB; all < `$10000`), so a **single-cell** right-aligned unsigned print suffices per column (no double needed per row — only the totals FREE can overflow 16 bits; see AC3).

**And** **AC2** (column-stable, right-aligned, 80-col fit) — column widths stay FIXED across header / per-bank rows / totals / summary rows; USED and FREE are right-aligned in their (existing width-6) fields; the current-bank `*` marker keeps its own fixed-width column; the worst-case line (29-bank cap, 6-digit free total `475136`) fits within 80 columns. The existing header `"BANK PAGE   USED   FREE"` (src/banking.asm:1101, len EQU 23) and the right-edge alignment (USED right-edge col 15, FREE right-edge col 22) from the Story-17.5 H1 code-review fix are preserved; if real values widen any column, re-derive the ASCII width inventory at dev-pass start and keep ≤ 80.

**And** **AC3** (totals row + CCD-4 summary rows — F2 mitigation) — after the last per-bank row:
- the **totals row** (`TOTAL` label, src/banking.asm:1106 `str_total_pfx`) sums per-bank `used` and per-bank `free` across all active banks (not the `bank_count * 16384` placeholder shortcut the current code uses at src/banking.asm:650-669 — that assumed every bank was empty). The FREE total can exceed 16 bits (29 × 16384 = 475136), so it stays a **double-cell** value printed via `D.R` (the existing inline-thread mechanism at src/banking.asm:678-684 `.totals_thread`); the USED total likewise (kernel + banked usage can exceed 16 bits at high bank counts) — confirm width at dev-pass.
- **two additional summary rows** for CCD-4 / F2 stub-cost visibility (per `epics-phase4-epics-16-22.md:1153`):
  - **banked-word count** = total descriptor stubs allocated = `(stub_alloc_tail − STUB_ALLOC_BASE) / 4` (`STUB_ALLOC_BASE = $D4CB`, `stub_alloc_tail` cell read via `(IY+UserArea.stub_alloc_tail)`; 4 B/stub stride). Label + value, column-aligned.
  - **descriptor-stub fixed-memory occupancy** = banked-word-count × 4 B (bytes consumed in the `$D4CB..$DBFF` allocator region). Label + value.
  - Exact row labels + layout are Q5 (dev-pass); keep them column-aligned with the table and ≤ 80 cols. These rows are 0-cost at boot when no banked words exist (count = 0).

**And** **AC4** (source-comment swap per epics AC4) — the `.BANKS` source-comment block in src/banking.asm (currently the Story-17.5 "Epic 17 minimal form" framing at src/banking.asm:540-568, including the line `Per-bank used = 0 and per-bank free = 16384 are PLACEHOLDERS`) is rewritten to describe the final form; the Story-17.5 minimal-form annotation is removed and replaced with `; Phase-4 final form — see Story 22.1`. The new comment documents the bank-0-vs-banks-1..N base/ceiling split (finding (1)) and the live-vs-saved here read (finding (2)) so future readers understand the branch. Per `feedback_source_comment_discipline`: say what + why-not-obvious; NO provenance (no story/CR/date beyond the single "see Story 22.1" pointer).

**And** **AC5** (M1 base-rendering resolved + probes) — the Story-17.5 deferred **M1** mixed-base finding is resolved per Q1 (recommend: byte-count columns USED/FREE/totals forced decimal regardless of `BASE`; PAGE stays hex as a hardware page-id; BANK stays decimal — the whole numeric table is then base-independent). Probes:
- **Main suite (`tests/banking_tests.fth`, surface-agnostic, sentinel+grep)** — the existing Probe X (header/row-count/totals) and Probe Y (marker tracking) at src/.../banking_tests.fth:386-414 stay; **Probe Z (placeholder guard) at :416-427 is RETARGETED** — it currently asserts the literal `0  16384` substring (finding (3)), which is now correct ONLY for an *empty* bank. Update it to assert empty-bank rows still read `used=0` and the bank-specific `free` (16384 for a banked row at boot), and document that a non-empty bank shows real values (covered by the isolated fixture below). If Q1 chooses forced-decimal, also add a `BASE`-independence assertion: `HEX` then `.BANKS` shows the SAME byte-count digits as `DECIMAL` (the M1 regression guard).
- **Isolated fixture (NEW `tests/banking_tests_22_1.fth` + `make test-repl-banking-isolated-22-1`, mirror 21-1/21-2)** — the AC5(a) behavioural probe: in a bank N≥1, capture `.BANKS` used for that bank, define a `:` word, capture again, assert used INCREASED by the body byte-count (sentinel-bounded `result=-1` verdict). This MUST be isolated, not in the main suite (`feedback_phase4_probe_bank_switch_limitation`). Also assert (b) totals row = sum of per-row used/free, and (c) banked-word-count summary row = `(stub_alloc_tail−STUB_ALLOC_BASE)/4` after the define. Lines ≤ TIB_SIZE 128 (`feedback_tib_size_inline_comments`); file 0x1A-terminated (`feedback_cpm_0x1a_eof_marker`); observe values via printed output + grep, not via words that don't exist.

**And** **AC6** (hardware smoke per S9 / NFR-P4-11) — one hardware-typed `.BANKS` probe runs on real MicroBeast: boot, `.BANKS` (note bank-0 real used/free), define a word in a non-zero bank (`5 BANK! : FOO ; 0 BANK!`), `.BANKS` again — visually confirm bank-5 used increased + column stability + 80-col fit + the totals/summary rows are readable. Transcript saved per the `~/Downloads/beastty-<date>.bin` convention. DEFERRED to user-triggered run per the established S9 precedent; the recipe is posted IN THE CLOSING CHAT MESSAGE per `feedback_post_hw_smoke_steps_at_review` (STRONG).

**And** **AC7** (binary delta + envelope) — `wc -c build/antforth.com` delta for this story is tracked against the epics' **≤ ~50 B** target (`epics-phase4-epics-16-22.md:1157`) and the Epic-22 ~100 B budget (`architecture.md:499`: `.BANKS ~80 B` of which 17.5 already spent the bulk). **Envelope-tension note (B.4):** replacing two fixed string literals with two computed right-aligned decimal prints per row + two summary rows is realistically MORE than ~50 B (a width-6 unsigned-decimal printer + the bank-0/bank-N branch + the per-row live-vs-saved-here read). The empirical ~2.4× Phase-4 multiplier (`project_epic17_envelope`) suggests ~50 B may land ~100-120 B. This is a **pure addition** (no design substitution → the multiplier-void carve-out does NOT apply). Disposition granularity is Q4: recommend accept-with-rationale in Dev Notes if ≤ ~120 B; surface for SCP only if structurally larger. Reuse the existing `print_bank_col_4` shape (src/banking.asm:693-727) and the `D.R` inline-thread (src/banking.asm:678-684) to minimise new code.

**And** **AC8** (regression baselines preserved — re-validate at dev-pass start per B.3) — `make test-repl` ≥ **974 PASS / 0 FAIL** on iz-cpm (21.2/21.3 measured **975/0**; `.BANKS` output is surface-agnostic so iz-cpm is unaffected by the value change); `make test-repl-banking` ≥ **61 PASS / 0 FAIL** (the retargeted Probe Z + any new main-suite assertions stay green); `make test-repl-banking-isolated-22-1` ≥ **1 PASS** (the new behavioural fixture); all other isolated targets (`-19-3 -19-4 -19-5-1 -20-1 -20-2 -20-3 -21-1 -21-2 -21-3`) unchanged; `make test-straddle-regression` = **3/3**; `make test-file-sanity` = **0 errors**; `make check-doc-sync` 0 new drift.

**FRs covered:** FR-P4-6 (`.BANKS` final form). **Findings advanced:** F2 (stub-cost visibility surfaced in `.BANKS` summary rows). **Deferred finding closed:** Story-17.5 M1 (mixed-base rendering).

> **Adversarial review (`CR`) is NOT an acceptance criterion** and is not a dev-pass task — it runs separately via the `CR` command in fresh context after dev-pass close (PD-1, Story 13.5.0). Do not add a "trigger adversarial review" AC.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [ ] Capture current binary size: clean `make clean && make && wc -c build/antforth.com`. **Do not inherit any number from this story text** (B.3 / Lesson 13.5-F). Story 21.2 close was 28069 B; Story 21.3 (Epic 21 close-out) is ~0 B kernel and may or may not be committed at your dev-pass start — re-`wc -c` from the actual current artifact. Record the absolute size + which HEAD it reflects.
- [ ] Confirm Epic 21 is closed (21.3 done; banner `src/antforth.asm:781` reads `v3.0.6`). If 21.3 is NOT yet done, NOTE the dependency: Story 22.1 is the first Epic-22 binary-delta story and assumes the Epic-21 lifecycle surface is shipped. (Story 22.1 does NOT touch the banner — the final tag is Story 22.4 / v3.0.7.)
- [ ] Capture `make test-repl` (expect **975 / 0**), `make test-repl-banking` (expect **61 / 0**), all isolated targets (`-19-3 -19-4 -19-5-1 -20-1 -20-2 -20-3 -21-1 -21-2 -21-3`; re-validate exact counts — some drifted 6↔7 historically), `make test-straddle-regression` (**3/3**), `make test-file-sanity` (**0 errors**), `make check-doc-sync` (~31 advisory / 0 drift). Record all in Dev Notes.
- [ ] Re-confirm the memory-model constants against source-of-truth (B.4 — line numbers shift): `SLOT2_WINDOW_BASE = $8000` (src/constants.asm:47); `BANK_TABLE_BASE = $D400`, `BANK_TABLE_ENTRY_SIZE = 6`, `ACTIVE_PAGES_BASE` (src/banking.asm:18-30); `STUB_ALLOC_BASE = $D4CB` (src/constants.asm); `kernel_end` label (src/antforth.asm:819); `UserArea.here` offset 4, `current_bank`, `bank_count`, `stub_alloc_tail` (src/structures.asm:23-66); the `.bank_here_init` COLD seed of bank-table[1..28].here=$8000 (src/antforth.asm:221-229); `bank_triple_swap` flush semantics (src/banking.asm:263-286); `bank_offset_hl` helper (src/banking.asm:233-246).
- [ ] Re-read the current `.BANKS` body (src/banking.asm:540-727) + its string literals (src/banking.asm:1101-1107) + the current main-suite `.BANKS` probes (`tests/banking_tests.fth:368-427`) before editing.

### Q-dispositions (resolve at dev-pass start via AskUserQuestion BEFORE any edit)

- [ ] **Q1 — M1 base-rendering (byte-count columns).** Recommend **(a) force decimal** for USED / FREE / totals / summary-row byte counts regardless of `BASE`; PAGE stays hex (hardware page-id); BANK stays decimal (logical index). This makes the whole numeric table base-independent and closes the Story-17.5 M1 finding (no more "30000 vs 16384" in HEX mode). Alternative (b): all byte counts follow `BASE` (keep PAGE hex, BANK decimal). (a) is recommended — observability tools should be base-stable.
- [ ] **Q2 — bank-0 used/free semantics.** Recommend the special-case in AC1: bank-0 `used = here − kernel_end`, `free = $D400 − here`; banks N≥1 `used = here − $8000`, `free = $C000 − here`. Confirm whether bank 0 should appear in the table with these kernel-region figures (recommended — it is honest and matches the banner's free calc) or be visually flagged (e.g. a note that bank-0 size differs). Recommended: show real bank-0 figures, no special flag.
- [ ] **Q3 — per-row number printer.** Recommend **hand-rolled width-6 unsigned-decimal printer** for the single-cell per-row used/free (value < $10000), reused for both columns and both bank-0/bank-N paths — cheaper than the `D.R` inline-thread dance per row (which the totals already use for the double-cell total). Alternative: reuse `w_U_DOT_R_cf` via per-row inline threads (heavier).
- [ ] **Q4 — envelope disposition (AC7).** Recommend **accept-with-rationale in Dev Notes** if the measured delta is ≤ ~120 B (pure-addition, inside the ~2.4× multiplier); escalate to a dedicated SCP only if structurally larger.
- [ ] **Q5 — summary-row labels/layout (AC3).** Pick column-aligned labels for the banked-word-count + stub-occupancy rows (e.g. `STUBS` / `STUBMEM`, or spelled out) within the 80-col budget.

### Story tasks

- [ ] **Task 1 — Real per-bank used/free in `w_DOT_BANKS_cf`** (AC: #1, #2, #5-M1)
  - [ ] Sub-1.1 In the per-row loop (src/banking.asm:595-642), after the marker print, replace the `str_used_free_crlf` literal print (src/banking.asm:635-637) with: load this row's `here` (live `(IY+UserArea.here)` if `C == current_bank`, else `bank-table[C].here` via `bank_offset_hl`); branch on `C == 0` for the bank-0 base/ceiling vs banks-N base ($8000) / ceiling ($C000); compute used + free; print each right-aligned width-6 (Q3 printer), forced-decimal per Q1; then CRLF.
  - [ ] Sub-1.2 Add the hand-rolled width-6 unsigned-decimal printer (or wire the chosen Q3 mechanism). Keep it self-contained like `print_bank_col_4` (src/banking.asm:693-727).
  - [ ] Sub-1.3 Verify the current-bank row reads live HERE (finding (2)) — a probe that defines a word in the CURRENT bank and re-runs `.BANKS` must show the increase WITHOUT a BANK! away first.
- [ ] **Task 2 — Totals row sums real values + CCD-4 summary rows** (AC: #3)
  - [ ] Sub-2.1 Replace the `bank_count * 16384` totals-free shortcut (src/banking.asm:650-669) with a running sum of per-row used and per-row free accumulated during the loop (double-cell; print via the existing `D.R` `.totals_thread` at src/banking.asm:678-684). The running-sum approach avoids re-walking the table.
  - [ ] Sub-2.2 Add the two summary rows: banked-word count = `(stub_alloc_tail − STUB_ALLOC_BASE)/4`; stub fixed-memory occupancy = count × 4. Column-aligned per Q5.
- [ ] **Task 3 — Source-comment swap** (AC: #4)
  - [ ] Sub-3.1 Rewrite the `.BANKS` comment block (src/banking.asm:540-568): remove "Epic 17 minimal form" + the placeholder lines; add `; Phase-4 final form — see Story 22.1`; document the bank-0-vs-banks-N base/ceiling split + the live-vs-saved here read. `feedback_source_comment_discipline`: what + why, no provenance dump.
- [ ] **Task 4 — Probes** (AC: #5)
  - [ ] Sub-4.1 Retarget main-suite Probe Z (`tests/banking_tests.fth:416-427`): empty-bank rows read `used=0` + bank-specific free; add the Q1 `BASE`-independence guard (HEX `.BANKS` digits == DECIMAL `.BANKS` digits) if forced-decimal chosen.
  - [ ] Sub-4.2 NEW `tests/banking_tests_22_1.fth`: behavioural define-then-check (used increases after `: WORD ;` in bank N≥1), totals = sum-of-rows, stub-count summary == `(tail−base)/4`. Isolated per `feedback_phase4_probe_bank_switch_limitation`; sentinel `result=-1`; lines ≤ 128; 0x1A-terminated.
  - [ ] Sub-4.3 `Makefile`: new `test-repl-banking-isolated-22-1` target + `.PHONY` entry (mirror `:998` `-21-2` recipe). Extend `test-repl-banking` grep-list if the retargeted Probe Z needs new patterns.
- [ ] **Task 5 — Build + regression** (AC: #7, #8)
  - [ ] Sub-5.1 `make asm` 0 warnings (if the larger body trips JR-out-of-range, convert offending JRs to JPs per Story-17.4/17.5 precedent).
  - [ ] Sub-5.2 `make test-repl` 975/0; `make test-repl-banking` ≥ 61/0; `make test-repl-banking-isolated-22-1` ≥ 1 PASS; all other isolated targets unchanged; straddle 3/3; file-sanity 0; check-doc-sync 0 new drift.
  - [ ] Sub-5.3 `wc -c build/antforth.com` post-edit; record absolute + delta vs the dev-pass-start baseline; apply Q4 disposition.
- [ ] **Task 6 — Hardware smoke** (AC: #6) — *user-gated; recipe provided, execution deferred to Ant*
  - [ ] Sub-6.1 HW-smoke recipe (boot → `.BANKS` → define in bank 5 → `.BANKS` → confirm used increased + column stability) posted **in the closing chat message** (`feedback_post_hw_smoke_steps_at_review`, STRONG). `disk/a/P221*.FTH` CP/M 8.3 copy if a scripted probe is used, 0x1A-terminated.
- [ ] **Task 7 — Sprint-status + commit**
  - [ ] Sub-7.1 `sprint-status.yaml`: `22-1-…` `ready-for-dev` → `in-progress` at dev-pass start → `review` at close.
  - [ ] Sub-7.2 Commit per user trigger. NO `Co-Authored-By: Claude` trailer (`feedback_no_claude_coauthor`, STRONG).

## Dev Notes

### Per-bank memory model (the load-bearing AC1 inputs — verified at draft time)

Confirmed by reading live source (B.4 / PD-2). The epics-file AC1 single formula is INCOMPLETE; the real model branches on bank index:

| | Base | Ceiling | Size | `used` | `free` |
|---|---|---|---|---|---|
| **Bank 0** (kernel/portal dict) | `kernel_end` (antforth.asm:819) | `$D400` (`BANK_TABLE_BASE`) | `$D400 − kernel_end` (~a few KB) | `here − kernel_end` | `$D400 − here` |
| **Banks 1..28** (slot-2 window) | `$8000` (`SLOT2_WINDOW_BASE`) | `$C000` | `$4000` = 16384 | `here − $8000` | `$C000 − here` |

- **Why bank 0 differs:** architecture.md:922 — "the Phase-1/2/3 single-dictionary-pointer model is now bank-0's case." Bank 0 is the original kernel dictionary growing from `kernel_end` up toward `$D400` (where the banking infrastructure starts). The COLD banner already computes bank-0 free as `$D400 − HERE` (antforth.asm:280-289) — reuse that exact relationship.
- **Why banks 1..28 are uniform:** the COLD `.bank_here_init` loop (antforth.asm:221-229) overrides every cloned bank-table[1..28].here to `$8000` so banked bodies start page-resident at the slot-2 window base and never straddle `$8000`. An empty bank therefore has `here = $8000` → `used = 0`, `free = $4000 = 16384` (matching the old placeholder by construction — which is why empty banks still read `0 / 16384`).
- **Live vs saved `here` (finding (2)):** `bank_triple_swap` (banking.asm:263-286) saves `UserArea.here` → `bank-table[old]` and loads `bank-table[new]` → `UserArea.here` only at BANK! time. So the CURRENT bank's authoritative `here` is `(IY+UserArea.here)`; `bank-table[current].here` is whatever it was at the last BANK!-away (stale). `.BANKS` must read live for the current row, saved for the rest. `UserArea.here` is at struct offset 4 (state, base, here…; structures.asm:24-26); `bank-table[N].here` is offset 0 of the 6-byte entry; use `bank_offset_hl` (banking.asm:233-246) which returns `HL = &bank-table[A]`.

### The current `.BANKS` shape (what changes)

The Story-17.5 body (banking.asm:540-727) prints, per row: BANK (4-col decimal via `print_bank_col_4`), `"   "` sep, PAGE (2 hex via `cl_emit_hex_byte`), `" "`, marker (`*`/space), then the **literal** `str_used_free_crlf = "    0  16384\r\n"` (banking.asm:1104). Totals: `str_total_pfx = "TOTAL          0 "` then `bank_count<<14` as a double via `D.R` (banking.asm:650-684). Story 22.1 replaces the literal per-row used/free with computed values (Task 1), replaces the `bank_count*16384` totals shortcut with a real running sum (Task 2), and adds two summary rows (Task 2). Header (banking.asm:1101, len 23) + right-edge alignment (USED col 15, FREE col 22) from the 17.5 H1 fix are preserved.

### M1 mixed-base finding (Story-17.5 deferred → closed here)

Story-17.5 code-review M1 (17.5 story :549): `.BANKS` rendered BANK decimal, PAGE hex, USED/FREE as literal-decimal strings, but the totals FREE followed `BASE` via `D.R` — so in `HEX` mode the per-row "16384" and the totals "30000" disagreed in base. Now that USED/FREE are computed (and the totals stay `D.R`), the base must be unified. Q1 recommends forcing decimal for all byte-count columns (USED/FREE/totals/summary), keeping PAGE hex (hardware page-id) and BANK decimal (logical index). Add a `HEX .BANKS` == `DECIMAL .BANKS` digit-equality probe as the M1 regression guard.

### Envelope tension (AC7)

The epics target is ≤ ~50 B (`epics-phase4-epics-16-22.md:1157`); architecture allocates `.BANKS ~80 B` total of which 17.5 spent the bulk (architecture.md:499). Realistically, swapping two literals for two computed right-aligned decimals per row + the bank-0/bank-N branch + the live-vs-saved here read + two summary rows lands closer to ~100-120 B (the ~2.4× Phase-4 empirical multiplier, `project_epic17_envelope`). This is a **pure addition** (no mechanism substitution → multiplier-void carve-out does NOT apply, unlike Epic 20's 3.4× fat-pointer migration). Minimise via: reuse `print_bank_col_4`'s shape for the width-6 printer; reuse the `D.R` `.totals_thread` for the double totals; accumulate totals in the loop (no second walk). Q4 disposition: accept-with-rationale in Dev Notes if ≤ ~120 B.

### Why the behavioural probe needs an isolated fixture

`feedback_phase4_probe_bank_switch_limitation` + ADR 19.5 DR-1: the main `tests/banking_tests.fth` dictionary straddles `$8000`; any token lookup while a non-zero bank is mapped can walk a bucket chain through the portal window and read a foreign page. Every Epic-17..21 behavioural probe (define/switch/lookup in a non-zero bank) lives in a dedicated `tests/banking_tests_NN_M.fth` fixture with a matching `make test-repl-banking-isolated-NN-M` target (mirror 21-1 at Makefile:960, 21-2 at :998). The AC5(a) "define in bank 5, used increases" probe is exactly this pattern → new `tests/banking_tests_22_1.fth`. The surface-agnostic header/marker/totals probes (no per-bank define) can stay in the main suite; only Probe Z must be retargeted (it asserts the now-sometimes-wrong literal `0  16384`).

### Project Structure Notes

- Story 22.1 is the FIRST story of Epic 22 (Polish + Phase-4 close-out) and the first binary-delta story since Epic 21. Creating it flips `epic-22` `backlog → in-progress`.
- Story 22.1 does NOT touch the banner/version. The final Phase-4 tag (**v3.0.7** per the downstream-mapping shift recorded in 21.3) is applied by Story 22.4. The version surface is out of scope here.
- The sprint-status key + filename keep the full descriptive slug `22-1-dot-banks-final-formatting-polish-per-bank-used-free-reflect-real-here-values` per the workflow's `{story_key}.md` rule.
- **Do not touch** the per-bank state machinery (`bank_triple_swap`, COLD bank-table init, the compiler's per-bank `here`/`,`); Epic 19 shipped it and it is `done`. Story 22.1 only READS `here`/`stub_alloc_tail` and reformats `.BANKS` output. The only kernel edit is inside `w_DOT_BANKS_cf` + its string literals.

### Detected conflicts or variances

- **Epics-file AC1 formula is bank-0-incomplete** — re-specced in AC1 + the memory-model table (finding (1)). Bank 0 needs `kernel_end` base + `$D400` ceiling; the single "bank-size" formula only fits banks 1..28.
- **Epics-file AC1 omits the live-vs-saved here distinction** — folded into AC1 (finding (2)); the current bank reads `UserArea.here`, not `bank-table[current].here`.
- **AC5 "update Story 17.5's `.BANKS` probe" under-constrained** — split into main-suite retarget (Probe Z) + a new isolated behavioural fixture (finding (4)).
- **Envelope ~50 B is optimistic** — reconciled in AC7 / Dev Notes (pure-addition, ~2.4× multiplier; Q4 disposition).
- **Story-17.5 M1 deferred finding** — closed here via Q1 forced-decimal (finding (3)).
- **Dependency on Epic 21 close-out** — 22.1 assumes 21.3 done (banner v3.0.6). Re-baseline binary + banner at dev-pass start.

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:1141-1160`] — Story 22.1 spec (the AC set re-specced here); Epic 22 overview `:1123-1139`; Epic 22 summary `:1234-1236`.
- [Source: `_bmad-output/implementation-artifacts/17-5-dot-banks-minimal-working-form.md`] — the minimal form this story polishes; AC2 placeholder framing; M1 deferred finding (`:549`); H1 column-alignment fix; `print_bank_col_4` rationale.
- [Source: `src/banking.asm:540-727`] — current `w_DOT_BANKS_cf` body (comment block :540-568; per-row loop :595-642; totals :644-684; `print_bank_col_4` :693-727); string literals `:1101-1107`; constants `:18-30`; `bank_offset_hl` `:233-246`; `bank_triple_swap` `:263-286`.
- [Source: `src/antforth.asm:221-229`] — `.bank_here_init` COLD seed of bank-table[1..28].here = `$8000`; `:280-289` bank-0 free = `$D400 − HERE`; `:819` `kernel_end` label; `:57-60` bank-0 HERE = kernel_end.
- [Source: `src/structures.asm:23-66`] — UserArea layout (`here` offset 4; `current_bank`, `bank_count`, `stub_alloc_tail`, `saved_bank`).
- [Source: `src/constants.asm:47`] — `SLOT2_WINDOW_BASE = $8000`; `STUB_ALLOC_BASE = $D4CB`.
- [Source: `architecture.md:499`] — Epic-22 budget (`.BANKS ~80 B`; prompt indicator ~20 B; CODE-words 0 B); `:922` bank-0-is-the-single-dictionary case; `:243` redesign §5.4 cross-bank pointer hazard; `:977` F2 stub-cost growth.
- [Source: `tests/banking_tests.fth:368-427`] — current `.BANKS` Probes X/Y/Z; `_dot-banks-setup`. `Makefile:960,998` — isolated-21-1/-21-2 recipes to mirror; `:52` `.PHONY`; `:119` `test-repl-banking`.
- [Source: `_bmad-output/implementation-artifacts/21-3-epic-21-close-out-antforth-3-x-5-tag.md`] — current baselines (28069 B at 21.2 close; v3.0.6/Epic-22→v3.0.7 mapping; test gates 975/0 · 61/0 · straddle 3/3).
- Memory: `project_phase4_scope`, `project_bank_table_clone_at_cold`, `project_banking_bios_pivot`, `feedback_phase4_probe_bank_switch_limitation`, `feedback_source_comment_discipline`, `feedback_post_hw_smoke_steps_at_review` (STRONG), `feedback_no_claude_coauthor` (STRONG), `feedback_cpm_0x1a_eof_marker`, `feedback_tib_size_inline_comments`, `project_epic17_envelope`, `feedback_kernel_ldir_estimate_overshoot`, `feedback_plain_qa_language`, `feedback_no_preexisting_discharge`.

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

### Change Log
