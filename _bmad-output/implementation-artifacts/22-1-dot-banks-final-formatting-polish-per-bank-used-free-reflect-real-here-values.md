# Story 22.1: `.BANKS` final formatting polish + per-bank used / free reflect real `here` values

Status: review

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
           `bank_triple_swap` (src/banking.asm:287-323) flushes
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
           surface-agnostic header/marker probes (Probe X header-row, Probe
           Y marker) can stay in the main `tests/banking_tests.fth`, but the
           placeholder-guard Probe Z there must be RETARGETED (it currently
           asserts the literal `0  16384` — wrong for bank 0 and for any
           non-empty bank). See finding (5) for the totals probes.

       (5) THE PLACEHOLDER TOTALS `196608` IS ASSERTED BY TWO PROBES AND
           BREAKS HERE. The main suite has FOUR `.BANKS` probes (X/Y/Z/W),
           not the three the epics-file AC5 implies. Probe X
           (`tests/banking_tests.fth:386-395`) AND Probe W (`:429-437`) both
           grep-assert the literal `196608` (= 12 × 16384) on the TOTAL line
           — the `bank_count * 16384` placeholder total. Once AC3 makes the
           totals a real running sum, BOTH break. The new value depends on
           whether bank 0 is a counted row: Probe Y proves bank 0 is row 0,
           and bank-0's real free = `$D400 − kernel_end` ≠ 16384, so if
           bank 0 contributes to the totals the new figure ≠ 196608. The
           dev-pass must settle the bank-0-in-totals question, re-derive the
           expected totals, and update BOTH Makefile grep targets — not just
           Probe Z. See AC5 main-suite bullet + Task 4 Sub-4.1b. -->

## Story

As Marc (OG retrocomputing user) inspecting bank state with `.BANKS`,
I want a polished, column-stable status table whose per-bank **used** / **free** columns reflect each bank's **real** `here` value (now that Epic 19's per-bank dictionary state is live), plus a totals row and CCD-4 summary rows,
So that `.BANKS` is the canonical observability tool for banking — not the Story-17.5 placeholder that printed `0 / 16384` for every bank regardless of what I had compiled into it.

## Acceptance Criteria

> Final form of FR-P4-6. Promotes the Story-17.5 `.BANKS` minimal form (zero-used / full-free placeholders) to real per-bank used/free, adds CCD-4 summary rows (F2 mitigation), and resolves the Story-17.5 deferred M1 mixed-base finding. The epics-file Story 22.1 AC1 formula is re-specced here against repo reality: **bank 0 is special** (kernel dictionary, base=`kernel_end`, ceiling=`$D400`); banks 1..28 use base=`$8000`, ceiling=`$C000`. FRs covered: FR-P4-6 (final form). Findings advanced: F2 (stub-cost visibility surfaced in `.BANKS` summary rows).

**Given** Story 17.5 shipped `.BANKS` in minimal/working form (per-bank used=0, free=16384 literal placeholders; `w_DOT_BANKS_cf` at src/banking.asm:608, literal `str_used_free_crlf` at :1141), AND Epic 19 made per-bank `here`/`latest`/`wordlist_head` real (the `bank_triple_swap` LDIR at BANK! time, src/banking.asm:287-323; bank-table[1..28].here COLD-seeded to `$8000` at src/antforth.asm:221-229), AND Epic 21 has closed (21.3 ships the v3.0.6 banner; this story builds on top of that — re-baseline at dev-pass start),
**When** Story 22.1 is dev-passed,

**Then** **AC1** (per-bank used/free reflect real `here` — FR-P4-6 final, **bank-0-special**) — the per-row USED/FREE columns in `.BANKS` (src/banking.asm `w_DOT_BANKS_cf`) are computed from each bank's real `here`, replacing the `str_used_free_crlf` literal `"    0  16384"`:
- **For the row whose logical index == `(IY+UserArea.current_bank)`**: read the LIVE `here` from `(IY+UserArea.here)` — NOT `bank-table[current].here`, which is stale until a BANK! away (finding (2)).
- **For every other row N**: read the saved `here` from `bank-table[N].here` (offset 0 of the 6-byte entry; `BANK_TABLE_BASE = $D400`; per-entry stride `BANK_TABLE_ENTRY_SIZE = 6`; use the existing `bank_offset_hl` helper at src/banking.asm:225-234).
- **Bank N ≥ 1** (banked window): `used = here − $8000`; `free = $C000 − here` (equivalently `$4000 − used`; `SLOT2_WINDOW_BASE = $8000`, size `$4000` = 16384).
- **Bank 0** (kernel/portal dictionary): `used = here − kernel_end`; `free = $D400 − here` (`BANK_TABLE_BASE = $D400`; `kernel_end` is the assembler label at src/antforth.asm:819; bank-0 free already computed this exact way by the banner at src/antforth.asm:280-289).
- Both `used` and `free` are single 16-bit values per row (max `used` in a banked window = `$4000` = 16384; bank-0 `used` ≤ `$D400 − kernel_end` ≈ a few KB; all < `$10000`), so a **single-cell** right-aligned unsigned print suffices per column (no double needed per row — only the totals FREE can overflow 16 bits; see AC3).

**And** **AC2** (column-stable, right-aligned, 80-col fit) — column widths stay FIXED across header / per-bank rows / totals / summary rows; USED and FREE are right-aligned in their (existing width-6) fields; the current-bank `*` marker keeps its own fixed-width column; the worst-case line (29-bank cap, 6-digit free total `475136`) fits within 80 columns. The existing header `"BANK PAGE   USED   FREE"` (`str_dot_banks_hdr`, src/banking.asm:1138; len `str_dot_banks_hdr_len` EQU 23 at :1139) and the right-edge alignment (USED right-edge col 15, FREE right-edge col 22) from the Story-17.5 H1 code-review fix are preserved; if real values widen any column, re-derive the ASCII width inventory at dev-pass start and keep ≤ 80.

**And** **AC3** (totals row + CCD-4 summary rows — F2 mitigation) — after the last per-bank row:
- the **totals row** (`TOTAL` label, `str_total_pfx` `"TOTAL          0 "`, src/banking.asm:1143) sums per-bank `used` and per-bank `free` across all active banks (not the `bank_count * 16384` placeholder shortcut the current code uses at src/banking.asm:687-708 — that assumed every bank was empty). The FREE total can exceed 16 bits (29 × 16384 = 475136), so it stays a **double-cell** value printed via `D.R` (the existing inline-thread mechanism at src/banking.asm:715-721 `.totals_thread`); the USED total likewise (kernel + banked usage can exceed 16 bits at high bank counts) — confirm width at dev-pass.
- **two additional summary rows** for CCD-4 / F2 stub-cost visibility (per `epics-phase4-epics-16-22.md:1177`):
  - **banked-word count** = total descriptor stubs allocated = `(stub_alloc_tail − STUB_ALLOC_BASE) / 4` (`STUB_ALLOC_BASE = $D4CB`, `stub_alloc_tail` cell read via `(IY+UserArea.stub_alloc_tail)`; 4 B/stub stride). Label + value, column-aligned.
  - **descriptor-stub fixed-memory occupancy** = banked-word-count × 4 B (bytes consumed in the `$D4CB..$DBFF` allocator region). Label + value.
  - Exact row labels + layout are Q5 (dev-pass); keep them column-aligned with the table and ≤ 80 cols. These rows are 0-cost at boot when no banked words exist (count = 0).

**And** **AC4** (source-comment swap per epics AC4) — the `.BANKS` source-comment block in src/banking.asm (currently the Story-17.5 "Epic 17 minimal form" framing at src/banking.asm:587-607, including the line `Per-bank used = 0 and per-bank free = 16384 are PLACEHOLDERS` at :593) is rewritten to describe the final form; the Story-17.5 minimal-form annotation is removed and replaced with `; Phase-4 final form — see Story 22.1`. The new comment documents the bank-0-vs-banks-1..N base/ceiling split (finding (1)) and the live-vs-saved here read (finding (2)) so future readers understand the branch. Per `feedback_source_comment_discipline`: say what + why-not-obvious; NO provenance (no story/CR/date beyond the single "see Story 22.1" pointer).

**And** **AC5** (M1 base-rendering resolved + probes) — the Story-17.5 deferred **M1** mixed-base finding is resolved per Q1 (recommend: byte-count columns USED/FREE/totals forced decimal regardless of `BASE`; PAGE stays hex as a hardware page-id; BANK stays decimal — the whole numeric table is then base-independent). Probes:
- **Main suite (`tests/banking_tests.fth`, surface-agnostic, sentinel+grep)** — there are FOUR existing `.BANKS` probes (X/Y/Z/W), all sharing `_dot-banks-setup` (`tests/banking_tests.fth:379-384` = `BANKS-CLEAR` + 12× `$22 +BANK`):
  - **Probe X** (header + row-count + totals; `:386-395`) and **Probe W** (totals row; `:429-437`) BOTH grep-assert the literal `196608` (= 12 × 16384) on the `TOTAL` line (the Makefile recipe's grep targets, `tests/banking_tests.fth:388` and `:429-430`). That `196608` is the `bank_count * 16384` PLACEHOLDER total. Once AC3 makes the totals a **real running sum**, this assertion MUST be re-derived — and the new value depends on **whether bank 0 is a counted row in the table** (finding (5) below): Probe Y proves bank 0 IS row 0, and bank-0's real free = `$D400 − kernel_end` ≠ 16384, so if bank 0 contributes to the totals the new total ≠ 196608. Re-derive the expected totals-FREE (and totals-USED) at dev-pass from the actual row set and update the Makefile grep targets for Probe X AND Probe W.
  - **Probe Y** (current-bank `*` marker tracking; `:397-414`) is surface-agnostic to used/free values and **stays unchanged**.
  - **Probe Z** (placeholder guard; `:416-427`) is **RETARGETED** — it currently grep-asserts ≥12 lines carrying the literal `0  16384` substring (finding (3)), correct ONLY for an *empty banked* row. Update it to assert empty banked rows still read `used=0` + bank-specific `free` (16384 for a banked row at boot), and that **bank-0's row is exempt** (it shows the kernel-region free, not 16384). Document that a non-empty bank shows real values (covered by the isolated fixture below). If Q1 chooses forced-decimal, also add a `BASE`-independence assertion: `HEX` then `.BANKS` shows the SAME byte-count digits as `DECIMAL` (the M1 regression guard).
- **Isolated fixture (NEW `tests/banking_tests_22_1.fth` + `make test-repl-banking-isolated-22-1`, mirror 21-1/21-2)** — the AC5(a) behavioural probe: in a bank N≥1, capture `.BANKS` used for that bank, define a `:` word, capture again, assert used INCREASED by the body byte-count (sentinel-bounded `result=-1` verdict). This MUST be isolated, not in the main suite (`feedback_phase4_probe_bank_switch_limitation`). Also assert (b) totals row = sum of per-row used/free, and (c) banked-word-count summary row = `(stub_alloc_tail−STUB_ALLOC_BASE)/4` after the define. Lines ≤ TIB_SIZE 128 (`feedback_tib_size_inline_comments`); file 0x1A-terminated (`feedback_cpm_0x1a_eof_marker`); observe values via printed output + grep, not via words that don't exist.

**And** **AC6** (hardware smoke per S9 / NFR-P4-11) — one hardware-typed `.BANKS` probe runs on real MicroBeast: boot, `.BANKS` (note bank-0 real used/free), define a word in a non-zero bank (`5 BANK! : FOO ; 0 BANK!`), `.BANKS` again — visually confirm bank-5 used increased + column stability + 80-col fit + the totals/summary rows are readable. Transcript saved per the `~/Downloads/beastty-<date>.bin` convention. DEFERRED to user-triggered run per the established S9 precedent; the recipe is posted IN THE CLOSING CHAT MESSAGE per `feedback_post_hw_smoke_steps_at_review` (STRONG).

**And** **AC7** (binary delta + envelope) — `wc -c build/antforth.com` delta for this story is tracked against the epics' **≤ ~50 B** target (`epics-phase4-epics-16-22.md:1181`) and the Epic-22 ~100 B budget (`architecture.md:499`: `.BANKS ~80 B` of which 17.5 already spent the bulk). **Envelope-tension note (B.4):** replacing two fixed string literals with two computed right-aligned decimal prints per row + two summary rows is realistically MORE than ~50 B (a width-6 unsigned-decimal printer + the bank-0/bank-N branch + the per-row live-vs-saved-here read). The empirical ~2.4× Phase-4 multiplier (`project_epic17_envelope`) suggests ~50 B may land ~100-120 B. This is a **pure addition** (no design substitution → the multiplier-void carve-out does NOT apply). Disposition granularity is Q4: recommend accept-with-rationale in Dev Notes if ≤ ~120 B; surface for SCP only if structurally larger. Reuse the existing `print_bank_col_4` shape (src/banking.asm:730) and the `D.R` inline-thread (src/banking.asm:715-721) to minimise new code.

**And** **AC8** (regression baselines preserved — re-validate at dev-pass start per B.3) — `make test-repl` ≥ **974 PASS / 0 FAIL** on iz-cpm (21.2/21.3 measured **975/0**; `.BANKS` output is surface-agnostic so iz-cpm is unaffected by the value change); `make test-repl-banking` ≥ **61 PASS / 0 FAIL** (the retargeted Probe Z + any new main-suite assertions stay green); `make test-repl-banking-isolated-22-1` ≥ **1 PASS** (the new behavioural fixture); all other isolated targets (`-19-3 -19-4 -19-5-1 -20-1 -20-2 -20-3 -21-1 -21-2 -21-3`) unchanged; `make test-straddle-regression` = **3/3**; `make test-file-sanity` = **0 errors**; `make check-doc-sync` 0 new drift.

**FRs covered:** FR-P4-6 (`.BANKS` final form). **Findings advanced:** F2 (stub-cost visibility surfaced in `.BANKS` summary rows). **Deferred finding closed:** Story-17.5 M1 (mixed-base rendering).

> **Adversarial review (`CR`) is NOT an acceptance criterion** and is not a dev-pass task — it runs separately via the `CR` command in fresh context after dev-pass close (PD-1, Story 13.5.0). Do not add a "trigger adversarial review" AC.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: clean `make clean && make && wc -c build/antforth.com`. **Do not inherit any number from this story text** (B.3 / Lesson 13.5-F). For orientation only: Epic 21 is closed (HEAD `95cfe6d` "Story 21.3 status -> done"; Story 21.2 close measured 28069 B, the current post-21.3 build artifact measured 28049 B) — but re-`wc -c` from the actual current artifact at YOUR dev-pass start. Record the absolute size + which HEAD it reflects.
- [x] Confirm Epic 21 is closed (21.3 done; banner `src/antforth.asm:781` reads `v3.0.6`). If 21.3 is NOT yet done, NOTE the dependency: Story 22.1 is the first Epic-22 binary-delta story and assumes the Epic-21 lifecycle surface is shipped. (Story 22.1 does NOT touch the banner — the final tag is Story 22.4 / v3.0.7.)
- [x] Capture `make test-repl` (expect **975 / 0**), `make test-repl-banking` (expect **61 / 0**), all isolated targets (`-19-3 -19-4 -19-5-1 -20-1 -20-2 -20-3 -21-1 -21-2 -21-3`; re-validate exact counts — some drifted 6↔7 historically), `make test-straddle-regression` (**3/3**), `make test-file-sanity` (**0 errors**), `make check-doc-sync` (~31 advisory / 0 drift). Record all in Dev Notes.
- [x] Re-confirm the memory-model constants against source-of-truth (B.4 — line numbers shift, and banking.asm shifted at the 2026-06-13 Story-21.3 CR-fix commit `a1dc735`): `SLOT2_WINDOW_BASE = $8000` (src/constants.asm:47); `BANK_TABLE_BASE = $D400` (src/constants.asm:15); `STUB_ALLOC_BASE = $D4CB` (src/constants.asm:25); `BANK_TABLE_ENTRY_SIZE = 6` (src/banking.asm:19), `ACTIVE_PAGES_BASE` (src/banking.asm:27); `kernel_end` label (src/antforth.asm:819); `UserArea.here` offset 4 (`state`/`base`/`here` at src/structures.asm:24-26), `saved_bank`/`current_bank`/`bank_count`/`stub_alloc_tail` (src/structures.asm:44-53); the `.bank_here_init` COLD seed of bank-table[1..28].here=$8000 (src/antforth.asm:221-229); `bank_triple_swap` flush semantics (src/banking.asm:287-323); `bank_offset_hl` helper (src/banking.asm:225-234).
- [x] Re-read the current `.BANKS` body (`w_DOT_BANKS`/`w_DOT_BANKS_cf` + `print_bank_col_4`, src/banking.asm:587-757) + its string literals (src/banking.asm:1138-1144) + the current main-suite `.BANKS` probes X/Y/Z/W (`tests/banking_tests.fth:368-437`) before editing.

### Q-dispositions (resolve at dev-pass start via AskUserQuestion BEFORE any edit)

- [x] **Q1 — M1 base-rendering (byte-count columns).** Recommend **(a) force decimal** for USED / FREE / totals / summary-row byte counts regardless of `BASE`; PAGE stays hex (hardware page-id); BANK stays decimal (logical index). This makes the whole numeric table base-independent and closes the Story-17.5 M1 finding (no more "30000 vs 16384" in HEX mode). Alternative (b): all byte counts follow `BASE` (keep PAGE hex, BANK decimal). (a) is recommended — observability tools should be base-stable.
- [x] **Q2 — bank-0 used/free semantics.** Recommend the special-case in AC1: bank-0 `used = here − kernel_end`, `free = $D400 − here`; banks N≥1 `used = here − $8000`, `free = $C000 − here`. Confirm whether bank 0 should appear in the table with these kernel-region figures (recommended — it is honest and matches the banner's free calc) or be visually flagged (e.g. a note that bank-0 size differs). Recommended: show real bank-0 figures, no special flag.
- [x] **Q3 — per-row number printer.** Recommend **hand-rolled width-6 unsigned-decimal printer** for the single-cell per-row used/free (value < $10000), reused for both columns and both bank-0/bank-N paths — cheaper than the `D.R` inline-thread dance per row (which the totals already use for the double-cell total). Alternative: reuse `w_U_DOT_R_cf` via per-row inline threads (heavier).
- [x] **Q4 — envelope disposition (AC7).** Recommend **accept-with-rationale in Dev Notes** if the measured delta is ≤ ~120 B (pure-addition, inside the ~2.4× multiplier); escalate to a dedicated SCP only if structurally larger.
- [x] **Q5 — summary-row labels/layout (AC3).** Pick column-aligned labels for the banked-word-count + stub-occupancy rows (e.g. `STUBS` / `STUBMEM`, or spelled out) within the 80-col budget.

### Story tasks

- [x] **Task 1 — Real per-bank used/free in `w_DOT_BANKS_cf`** (AC: #1, #2, #5-M1)
  - [x] Sub-1.1 In the per-row loop (`.row_loop` … `DJNZ .row_loop`, src/banking.asm:632-679), after the marker print, replace the `str_used_free_crlf` literal print (src/banking.asm:672-673) with: load this row's `here` (live `(IY+UserArea.here)` if `C == current_bank`, else `bank-table[C].here` via `bank_offset_hl`); branch on `C == 0` for the bank-0 base/ceiling vs banks-N base ($8000) / ceiling ($C000); compute used + free; print each right-aligned width-6 (Q3 printer), forced-decimal per Q1; then CRLF.
  - [x] Sub-1.2 Add the hand-rolled width-6 unsigned-decimal printer (or wire the chosen Q3 mechanism). Keep it self-contained like `print_bank_col_4` (src/banking.asm:730).
  - [x] Sub-1.3 Verify the current-bank row reads live HERE (finding (2)) — a probe that defines a word in the CURRENT bank and re-runs `.BANKS` must show the increase WITHOUT a BANK! away first.
- [x] **Task 2 — Totals row sums real values + CCD-4 summary rows** (AC: #3)
  - [x] Sub-2.1 Replace the `bank_count * 16384` totals-free shortcut (`.totals`, src/banking.asm:687-708) with a running sum of per-row used and per-row free accumulated during the loop (double-cell; print via the existing `D.R` `.totals_thread` at src/banking.asm:715-721). The running-sum approach avoids re-walking the table. NB: re-derive the test totals (Probe X/W grep `196608`) against the new sum + the bank-0-in-totals question (finding (5) / Task 4).
  - [x] Sub-2.2 Add the two summary rows: banked-word count = `(stub_alloc_tail − STUB_ALLOC_BASE)/4`; stub fixed-memory occupancy = count × 4. Column-aligned per Q5.
- [x] **Task 3 — Source-comment swap** (AC: #4)
  - [x] Sub-3.1 Rewrite the `.BANKS` comment block (src/banking.asm:587-607): remove "Epic 17 minimal form" + the placeholder lines (`:593`, `:596`); add `; Phase-4 final form — see Story 22.1`; document the bank-0-vs-banks-N base/ceiling split + the live-vs-saved here read. `feedback_source_comment_discipline`: what + why, no provenance dump.
- [x] **Task 4 — Probes** (AC: #5)
  - [x] Sub-4.1 Retarget main-suite Probe Z (`tests/banking_tests.fth:416-427`): empty banked rows read `used=0` + bank-specific free (16384), **bank-0 row exempt** (kernel-region free); add the Q1 `BASE`-independence guard (HEX `.BANKS` digits == DECIMAL `.BANKS` digits) if forced-decimal chosen.
  - [x] Sub-4.1b Re-derive the Probe X (`:386-395`, Makefile grep `196608` at `tests/banking_tests.fth:388`) AND Probe W (`:429-437`, grep `196608`) totals assertions: the placeholder `196608` (= 12×16384) is wrong once totals sum real values. First settle finding (5) — does `.BANKS` count bank 0 as a row in `_dot-banks-setup`'s 12-bank shape (Probe Y proves bank 0 = row 0)? Compute the new expected totals-FREE/USED from the actual row set (bank-0 free = `$D400 − kernel_end`) and update both Makefile grep targets. If bank 0 contributes, `196608` becomes a different fixed figure; assert that figure, not the placeholder.
  - [x] Sub-4.2 NEW `tests/banking_tests_22_1.fth`: behavioural define-then-check (used increases after `: WORD ;` in bank N≥1), totals = sum-of-rows, stub-count summary == `(tail−base)/4`. Isolated per `feedback_phase4_probe_bank_switch_limitation`; sentinel `result=-1`; lines ≤ 128; 0x1A-terminated.
  - [x] Sub-4.3 `Makefile`: new `test-repl-banking-isolated-22-1` target + `.PHONY` entry (mirror `:998` `-21-2` recipe). Extend `test-repl-banking` grep-list if the retargeted Probe Z needs new patterns.
- [x] **Task 5 — Build + regression** (AC: #7, #8)
  - [x] Sub-5.1 `make asm` 0 warnings (if the larger body trips JR-out-of-range, convert offending JRs to JPs per Story-17.4/17.5 precedent).
  - [x] Sub-5.2 `make test-repl` 975/0; `make test-repl-banking` ≥ 61/0; `make test-repl-banking-isolated-22-1` ≥ 1 PASS; all other isolated targets unchanged; straddle 3/3; file-sanity 0; check-doc-sync 0 new drift.
  - [x] Sub-5.3 `wc -c build/antforth.com` post-edit; record absolute + delta vs the dev-pass-start baseline; apply Q4 disposition.
- [x] **Task 6 — Hardware smoke** (AC: #6) — *user-gated; recipe provided, execution deferred to Ant*
  - [x] Sub-6.1 HW-smoke recipe (boot → `.BANKS` → define in bank 5 → `.BANKS` → confirm used increased + column stability) posted **in the closing chat message** (`feedback_post_hw_smoke_steps_at_review`, STRONG). `disk/a/P221*.FTH` CP/M 8.3 copy if a scripted probe is used, 0x1A-terminated.
- [x] **Task 7 — Sprint-status + commit**
  - [x] Sub-7.1 `sprint-status.yaml`: `22-1-…` `ready-for-dev` → `in-progress` at dev-pass start → `review` at close.
  - [x] Sub-7.2 Commit per user trigger. NO `Co-Authored-By: Claude` trailer (`feedback_no_claude_coauthor`, STRONG).

## Dev Notes

### Per-bank memory model (the load-bearing AC1 inputs — verified at draft time)

Confirmed by reading live source (B.4 / PD-2). The epics-file AC1 single formula is INCOMPLETE; the real model branches on bank index:

| | Base | Ceiling | Size | `used` | `free` |
|---|---|---|---|---|---|
| **Bank 0** (kernel/portal dict) | `kernel_end` (antforth.asm:819) | `$D400` (`BANK_TABLE_BASE`) | `$D400 − kernel_end` (~a few KB) | `here − kernel_end` | `$D400 − here` |
| **Banks 1..28** (slot-2 window) | `$8000` (`SLOT2_WINDOW_BASE`) | `$C000` | `$4000` = 16384 | `here − $8000` | `$C000 − here` |

- **Why bank 0 differs:** architecture.md:922 — "the Phase-1/2/3 single-dictionary-pointer model is now bank-0's case." Bank 0 is the original kernel dictionary growing from `kernel_end` up toward `$D400` (where the banking infrastructure starts). The COLD banner already computes bank-0 free as `$D400 − HERE` (antforth.asm:280-289) — reuse that exact relationship.
- **Why banks 1..28 are uniform:** the COLD `.bank_here_init` loop (antforth.asm:221-229) overrides every cloned bank-table[1..28].here to `$8000` so banked bodies start page-resident at the slot-2 window base and never straddle `$8000`. An empty bank therefore has `here = $8000` → `used = 0`, `free = $4000 = 16384` (matching the old placeholder by construction — which is why empty banks still read `0 / 16384`).
- **Live vs saved `here` (finding (2)):** `bank_triple_swap` (banking.asm:287-323) saves `UserArea.here` → `bank-table[old]` and loads `bank-table[new]` → `UserArea.here` only at BANK! time. So the CURRENT bank's authoritative `here` is `(IY+UserArea.here)`; `bank-table[current].here` is whatever it was at the last BANK!-away (stale). `.BANKS` must read live for the current row, saved for the rest. `UserArea.here` is at struct offset 4 (state, base, here…; structures.asm:24-26); `bank-table[N].here` is offset 0 of the 6-byte entry; use `bank_offset_hl` (banking.asm:225-234) which returns `HL = &bank-table[A]`.

### The current `.BANKS` shape (what changes)

The Story-17.5 body (`w_DOT_BANKS_cf` at banking.asm:608, per-row loop `.row_loop` 632-679, totals `.totals` 687-721, `print_bank_col_4` 730) prints, per row: BANK (4-col decimal via `print_bank_col_4`), `"   "` sep, PAGE (2 hex via `cl_emit_hex_byte`), `" "`, marker (`*`/space), then the **literal** `str_used_free_crlf = "    0  16384\r\n"` (banking.asm:1141, len 14 at :1142). Totals: `str_total_pfx = "TOTAL          0 "` (banking.asm:1143, len 17 at :1144) then `bank_count<<14` as a double via `D.R` (`.totals` 687-708 → `.totals_thread` 715-721). Story 22.1 replaces the literal per-row used/free with computed values (Task 1), replaces the `bank_count*16384` totals shortcut with a real running sum (Task 2), and adds two summary rows (Task 2). Header `str_dot_banks_hdr` (banking.asm:1138, len 23 at :1139) + right-edge alignment (USED col 15, FREE col 22) from the 17.5 H1 fix are preserved.

### M1 mixed-base finding (Story-17.5 deferred → closed here)

Story-17.5 code-review M1 (17.5 story :549): `.BANKS` rendered BANK decimal, PAGE hex, USED/FREE as literal-decimal strings, but the totals FREE followed `BASE` via `D.R` — so in `HEX` mode the per-row "16384" and the totals "30000" disagreed in base. Now that USED/FREE are computed (and the totals stay `D.R`), the base must be unified. Q1 recommends forcing decimal for all byte-count columns (USED/FREE/totals/summary), keeping PAGE hex (hardware page-id) and BANK decimal (logical index). Add a `HEX .BANKS` == `DECIMAL .BANKS` digit-equality probe as the M1 regression guard.

### Envelope tension (AC7)

The epics target is ≤ ~50 B (`epics-phase4-epics-16-22.md:1181`); architecture allocates `.BANKS ~80 B` total of which 17.5 spent the bulk (architecture.md:499). Realistically, swapping two literals for two computed right-aligned decimals per row + the bank-0/bank-N branch + the live-vs-saved here read + two summary rows lands closer to ~100-120 B (the ~2.4× Phase-4 empirical multiplier, `project_epic17_envelope`). This is a **pure addition** (no mechanism substitution → multiplier-void carve-out does NOT apply, unlike Epic 20's 3.4× fat-pointer migration). Minimise via: reuse `print_bank_col_4`'s shape for the width-6 printer; reuse the `D.R` `.totals_thread` for the double totals; accumulate totals in the loop (no second walk). Q4 disposition: accept-with-rationale in Dev Notes if ≤ ~120 B.

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
- **Epics-file AC5 implies 3 probes; there are 4 (X/Y/Z/W), and TWO assert the placeholder totals `196608`** — Probe X (`:386-395`) and Probe W (`:429-437`) both break once totals are a real sum; the bank-0-in-totals question (bank 0 is row 0, free ≠ 16384) must be settled to re-derive the figure (finding (5); AC5 main-suite bullet; Task 4 Sub-4.1b).
- **Citations re-validated 2026-06-13 (refresh/validate pass)** — `banking.asm` line numbers all shifted at the Story-21.3 CR-fix commit `a1dc735` (committed after the original 2026-06-12 draft), and the epics-file Story 22.1 spec shifted to `:1165-1184`. Every `file:line` in this story was re-checked against current source (B.4 / PD-2 figure-drift discipline).
- **Envelope ~50 B is optimistic** — reconciled in AC7 / Dev Notes (pure-addition, ~2.4× multiplier; Q4 disposition).
- **Story-17.5 M1 deferred finding** — closed here via Q1 forced-decimal (finding (3)).
- **Dependency on Epic 21 close-out** — 22.1 assumes 21.3 done (banner v3.0.6). Re-baseline binary + banner at dev-pass start.

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:1165-1184`] — Story 22.1 spec (the AC set re-specced here); Epic 22 overview `:1147-1163`; Epic 22 summary `:1260`. (Line numbers re-validated 2026-06-13; the epics file was edited after the original draft, shifting them.)
- [Source: `_bmad-output/implementation-artifacts/17-5-dot-banks-minimal-working-form.md`] — the minimal form this story polishes; AC2 placeholder framing; M1 deferred finding (`:549`); H1 column-alignment fix; `print_bank_col_4` rationale.
- [Source: `src/banking.asm`] — current `.BANKS`: comment block `:587-607` (placeholder lines `:593`, `:596`); `w_DOT_BANKS`/`w_DOT_BANKS_cf` `:606-608`; per-row loop `.row_loop` `:632-679`; current-bank marker compare `:649`; totals `.totals` `:687-708`; `.totals_thread` `:715-721`; `print_bank_col_4` `:730`; string literals `str_dot_banks_hdr` `:1138` (len 23 `:1139`), `str_used_free_crlf` `:1141` (len 14 `:1142`), `str_total_pfx` `:1143` (len 17 `:1144`); banking constants `BANK_TABLE_ENTRY_SIZE` `:19` + `ACTIVE_PAGES_BASE` `:27`; `bank_offset_hl` `:225-234`; `bank_triple_swap` `:287-323`. (All banking.asm line numbers re-validated 2026-06-13 — they shifted at the Story-21.3 CR-fix commit `a1dc735`, which was committed after the original draft.)
- [Source: `src/antforth.asm:221-229`] — `.bank_here_init` COLD seed of bank-table[1..28].here = `$8000`; `:280-289` bank-0 free = `$D400 − HERE`; `:819` `kernel_end` label; `:57-60` bank-0 HERE = kernel_end.
- [Source: `src/structures.asm:23-66`] — UserArea layout (`here` offset 4; `current_bank`, `bank_count`, `stub_alloc_tail`, `saved_bank`).
- [Source: `src/constants.asm`] — `BANK_TABLE_BASE = $D400` `:15`; `STUB_ALLOC_BASE = $D4CB` `:25`; `SLOT2_WINDOW_BASE = $8000` `:47`.
- [Source: `architecture.md:499`] — Epic-22 budget (`.BANKS ~80 B`; prompt indicator ~20 B; CODE-words 0 B); `:922` bank-0-is-the-single-dictionary case; `:243` redesign §5.4 cross-bank pointer hazard; `:977` F2 stub-cost growth.
- [Source: `tests/banking_tests.fth:368-437`] — current `.BANKS` Probes X (`:386-395`), Y (`:397-414`), Z (`:416-427`), W (`:429-437`); `_dot-banks-setup` (`:379-384`, BANKS-CLEAR + 12× `$22 +BANK`); Probe X/W grep `196608` at `:388`/`:429-430`. `Makefile:960,998` — isolated-21-1/-21-2 recipes to mirror; `:52` `.PHONY`; `:119` `test-repl-banking`.
- [Source: `_bmad-output/implementation-artifacts/21-3-epic-21-close-out-antforth-3-x-5-tag.md`] — current baselines (28069 B at 21.2 close; post-21.3 build artifact measured 28049 B at HEAD `95cfe6d`; v3.0.6/Epic-22→v3.0.7 mapping; test gates 975/0 · 61/0 · straddle 3/3). **Re-`wc -c` at dev-pass start regardless (B.3).**
- Memory: `project_phase4_scope`, `project_bank_table_clone_at_cold`, `project_banking_bios_pivot`, `feedback_phase4_probe_bank_switch_limitation`, `feedback_source_comment_discipline`, `feedback_post_hw_smoke_steps_at_review` (STRONG), `feedback_no_claude_coauthor` (STRONG), `feedback_cpm_0x1a_eof_marker`, `feedback_tib_size_inline_comments`, `project_epic17_envelope`, `feedback_kernel_ldir_estimate_overshoot`, `feedback_plain_qa_language`, `feedback_no_preexisting_discharge`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Opus 4.8) — BMAD dev-story workflow.

### Debug Log References

- Pre-edit baseline (HEAD `95cfe6d`, post-21.3): `wc -c build/antforth.com` = **28049 B**; banner reads v3.0.6 (Epic 21 closed, dependency satisfied). Gates: `test-repl` 975/0, `test-repl-banking` 61/0, isolated -19-3/-19-4/-19-5-1/-20-1/-20-2/-20-3/-21-1/-21-2/-21-3 = 15/2/2/7/5/5/5/5/6 (0 FAIL), straddle 3/3, file-sanity 0 errors, check-doc-sync 31 advisory / 0 drift.
- Memory-model constants re-confirmed against source: `kernel_end` = `$6E91` at baseline (shifts with kernel size — bank-0 capacity `$D400 − kernel_end` re-derives per build); `BANK_TABLE_BASE` `$D400`, `STUB_ALLOC_BASE` `$D4CB`, `SLOT2_WINDOW_BASE` `$8000`, ceiling `$C000`; `UserArea.here` offset 4, `current_bank`/`stub_alloc_tail` per structures.asm; `bank_offset_hl`, `rpush_de`/`rpop_de` (IX return stack) reused.
- Formatting bug caught during smoke: a 6-digit value (the totals) filled the full width-6 field and butted against the adjacent column (`TOTAL ... 0205922`). Fixed by emitting a guaranteed single-space separator between the USED and FREE columns (rows + totals); header widened to 24 chars, FREE right-edge col 24.
- Makefile probe bug caught: `expr 0 \* 4` returns exit status 1 (expr exits non-zero when the result is 0), which silently broke the `&&` recipe chain when `BANKED-WORDS=0`. Switched probe arithmetic from `expr` to `$(( ))`.

### Completion Notes List

**Q-dispositions (resolved with user at dev-pass start):**
- Q1 = **force decimal** for all byte-count columns (USED/FREE/totals/summary); PAGE stays hex, BANK decimal. Table is base-stable; closes Story-17.5 deferred M1.
- Q2 = bank-0 shows **real** kernel figures (used = HERE−kernel_end, free = $D400−HERE) and **is included** in the USED/FREE totals (epics "all active banks" wording).
- Q3 (not asked) = hand-rolled forced-decimal width-6 printer (`print_udword_w6`, unified 16/32-bit).
- Q4 = **accept-with-rationale** for the binary delta (see AC7 below).
- Q5 = summary labels `BANKED-WORDS` / `STUB-BYTES`.

**What was implemented & tested:**
- `w_DOT_BANKS_cf` rewritten (src/banking.asm): per-row real used/free from each bank's HERE — live `(IY+UserArea.here)` for the current bank, saved `bank-table[N].here` otherwise (finding (2)); bank-0/bank-N base+ceiling branch (finding (1)). Two 32-bit running totals accumulated in the loop; printed forced-decimal. The D.R inline-thread totals trampoline was removed in favour of a straight-line DEFCODE (save TOS+IP, restore + NEXT).
- Two CCD-4/F2 summary rows: `BANKED-WORDS` = `(stub_alloc_tail − STUB_ALLOC_BASE)/4`, `STUB-BYTES` = count×4. 0-cost at boot (count 0).
- AC4 comment block rewritten to final form (no provenance dump per `feedback_source_comment_discipline`).
- AC5-M1: forced-decimal makes the numeric table base-stable; new Probe M1 asserts `HEX .BANKS` still shows `16384` (not `4000`).
- Probes: main-suite Probe X/W re-derived to the **bank-0-inclusive totals invariant** computed in the recipe (`totals_used == bank-0 used`; `totals_free == bank-0 free + 11×16384`) — NOT a fixed `196608` literal, since bank-0's live HERE makes the total dynamic; Probe Z retargeted to "exactly 11 empty banked rows read 0/16384, bank-0 exempt"; new Probe M1 (BASE-independence). New isolated fixture `tests/banking_tests_22_1.fth` + `make test-repl-banking-isolated-22-1` (mirror 21-2): bank-5 used 0→54 after 2 defs (define-then-check, live HERE, AC5a), totals_used == bank-5 used (AC5b), BANKED-WORDS=2 / STUB-BYTES=8 (AC5c).

**Gate results (post-edit):** `test-repl` 975/0 (unchanged — `.BANKS` is surface-agnostic to iz-cpm), `test-repl-banking` **62/0** (+1 Probe M1), isolated -19-3…-21-3 unchanged + **-22-1 1/0**, straddle 3/3, file-sanity 0 errors, check-doc-sync 31 advisory / 0 drift. `make asm` 0 warnings.

**AC7 — binary delta (accept-with-rationale, Q4):** +282 B (28049 → **28331**), above the epics' ~50 B target and the ~120 B (2.4×-multiplier) accept threshold. Breakdown: per-bank used/free with bank-0/bank-N branch + live/saved HERE read ~95 B; forced-decimal 32-bit width-6 printer (`print_udword_w6` + `dbk_div10` + `dbk_val_nz`) ~82 B — unavoidable under Q1=force-decimal, the BASE-respecting `D.R` cannot be reused; 32-bit running totals ~30 B; two summary rows + labels ~40 B; 18 B scratch; remainder string/body net. Every byte is AC-mandated; the ~50 B target was self-acknowledged optimistic in AC7; pure addition (no design substitution, so the multiplier-void carve-out does not apply, but the feature set is fixed). ~1% kernel growth with ~25 KB still free. **User chose accept-with-rationale; no SCP, no Q1 revert.**

**AC6 — hardware smoke: PASS on real MicroBeast** (transcript `~/Downloads/beastty-20260613-155128.bin`, 2026-06-13). The `.BANKS` exercise ran on the **v3.0.6** build (banner immediately precedes the run in the transcript — the byte-exact current Story-22.1 artifact). The new `.BANKS` renders correctly on silicon: header `BANK PAGE    USED   FREE`, 24-char column-stable rows, bank-0 real figures (used 0 / free **25685** — matches the iz-cpm build to the byte), forced-decimal (`16384`, not hex), 80-col fit. `5 BANK! : FOO ; 0 BANK!` then `.BANKS`: bank-5 USED 0→**14**, TOTAL used 0→14 / free 205909→205895, BANKED-WORDS 0→**1**, STUB-BYTES 0→**4**. All AC6 criteria visually confirmed on hardware.

**Commit:** deferred to user trigger (`feedback_no_claude_coauthor` — NO Claude co-author trailer).

### File List

- `src/banking.asm` — `.BANKS` final form: comment block (AC4); `w_DOT_BANKS_cf` rewrite (real per-bank used/free, 32-bit running totals, summary rows, straight-line exit); new helpers `dot_banks_row_usedfree`, `add16_to_tot`, `print_summary_row`, `print_val16_w6`, `print_dword_at_hl_w6`, `print_udword_w6`, `dbk_div10`, `dbk_val_nz`; string literals (header→24 chars, `str_total_pfx`, `str_banked_words`, `str_stub_bytes`; removed `str_used_free_crlf`) + scratch cells (`dbk_val`, `dbk_numbuf`, `dbk_used_tot`, `dbk_free_tot`).
- `tests/banking_tests.fth` — retargeted Probe X/Z/W comments + added BASE-independence Probe M1; setup comment updated for the bank-0-inclusive totals model.
- `tests/banking_tests_22_1.fth` — NEW isolated behavioural fixture (define-then-check in bank 5; 0x1A-terminated, ASCII, ≤128-char lines).
- `Makefile` — Probe X/Z/W assertions re-derived (invariant arithmetic, not `196608` literal) + new Probe M1 assertion; new `test-repl-banking-isolated-22-1` target + `.PHONY` entry.
- `_bmad-output/implementation-artifacts/22-1-…-here-values.md` — story status/tasks/Dev Agent Record (this file).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `22-1-…` ready-for-dev → in-progress → review.

### Change Log

- 2026-06-13 — Story 22.1 dev-pass (claude-opus-4-8). `.BANKS` promoted from Story-17.5 placeholder to Phase-4 final form: real per-bank used/free (live/saved HERE, bank-0/bank-N branch), bank-0-inclusive 32-bit totals, CCD-4 `BANKED-WORDS`/`STUB-BYTES` summary rows, forced-decimal base-stable rendering (closes Story-17.5 M1). Probes X/Z/W re-derived; new Probe M1 + isolated fixture `tests/banking_tests_22_1.fth`. Binary +282 B (28049→28331), accept-with-rationale (Q4). Gates: 975/0 · 62/0 · isolated incl 22-1 · straddle 3/3 · file-sanity 0 · doc-sync 0 drift. HW smoke + commit deferred to user.
