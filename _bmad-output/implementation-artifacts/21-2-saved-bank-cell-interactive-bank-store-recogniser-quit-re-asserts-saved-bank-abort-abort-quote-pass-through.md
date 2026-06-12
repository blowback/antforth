# Story 21.2: Saved-bank cell + interactive-`BANK!` recogniser + `QUIT` re-asserts saved bank + `ABORT` / `ABORT"` pass-through

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As Marc (OG user) confident that `ABORT` mid-execution returns me to the bank I had typed at the REPL,
I want the kernel to track a "saved current bank" updated **only** by interactive `BANK!` from the outermost interpret loop, and `QUIT` to re-assert that bank on re-entry,
so that an `ABORT` inside a colon definition or inside an `INCLUDE`d file does not strand me in a wrong bank; and `INCLUDE`d `.FTH` files' `BANK!` calls do NOT pollute the saved-bank cell (F6 mitigation).

> **Read first — the cell already exists; this story WIRES it.** `UserArea.saved_bank` (`src/structures.asm:44`) is already declared and COLD-initialised to 0 (`src/antforth.asm:158-159`), but **nothing reads or writes it yet**. This story adds exactly two wirings: (1) a **write** site — the interpret loop's direct-execute path recognises a top-level interactive `BANK!` and copies `current_bank → saved_bank`; (2) a **read** site — `QUIT`'s loop re-asserts `saved_bank` into the live bank on each re-entry. `ABORT` / `ABORT"` need **no new code** — they already funnel through `THROW → .throw_uncaught → JP w_QUIT_cf`; AC4 is a *verification* that the existing unwind leaves `saved_bank` intact (it lives in UserArea, not on either stack).
>
> **The non-obvious design crux (do not get this wrong).** "Interactive `BANK!`" canNOT be detected inside `w_BANK_STORE_cf` (`src/banking.asm:165`). When the user types a colon word that internally calls `7 BANK!`, that `BANK!` runs at `STATE @ 0=` **and** `include_top == 0` — *byte-for-byte indistinguishable* from the user typing `7 BANK!` directly, if you only look at STATE+include_top. The **sole** signal that separates AC6(d) (interactive `7 BANK!` → saved) from AC6(b) (colon-internal `7 BANK!` → NOT saved) is **token identity at the interpret loop's direct-execute path**: only a token whose xt **is** `w_BANK_STORE_cf`, executed directly by `INTERPRET` (not nested under a `DOCOL` frame), counts. That is precisely why AC1 places the recogniser in `src/outer_interpreter.asm` (the interpret loop), not in `BANK!` itself. See Dev Notes "Design — the recogniser MUST live at `.interp_execute`".

## Acceptance Criteria

**Given** Stories 17.1 (saved-bank UserArea cell already wired — *declared + COLD-init only; this story adds read/write*), 18.2 (sentinel-trampoline EXIT for cross-bank THROW unwind), and 19.1 (per-bank dictionary state) have shipped,
**When** Story 21.2 is dev-passed,

1. **AC1** — `src/outer_interpreter.asm`'s top-level `BANK!` recogniser is added/extended so that the saved-bank UserArea cell (`UserArea.saved_bank`) is updated **only** when `BANK!` is invoked from interactive context (per FR-P4-31). The recogniser fires on the interpret loop's **direct-execute path** (`.interp_execute`, `src/outer_interpreter.asm:212`) — the only site that executes a token's xt directly under the text interpreter in interpret state.
2. **AC2** (F6 mitigation — interactive recogniser semantics) — "interactive `BANK!`" is defined as: `STATE @ 0=` (interpret state) **AND** outer-interpreter-depth = 1 (not inside an `INCLUDE`d source frame, per CCD-1's INCLUDE-TOP chain depth check, i.e. `UserArea.include_top == 0`). The depth check uses the **existing** INCLUDE-TOP chain from Phase-2 Epic 13 (`src/structures.asm:41`; no new mechanism). **Note:** the `.interp_execute` path is structurally reached **only** when `STATE = 0` (the `STATE`-test QBRANCH at `src/outer_interpreter.asm:194`), so the `STATE @ 0=` clause is satisfied *by construction* at the recogniser site and need not be re-tested in asm — only the `include_top == 0` guard and the token-identity (xt == `w_BANK_STORE_cf`) test are explicit.
3. **AC3** — `src/outer_interpreter.asm`'s `w_QUIT_cf` loop (`.quit_loop`, `:345`) is extended per FR-P4-32: on re-entry to the outermost interpret loop, read the saved-bank cell; if it differs from `current_bank`, perform a real bank switch (map the corresponding physical page to MMU slot 2 via `mbb_set_slot2`, swap the per-bank triple via `bank_triple_swap`, and update `current_bank`/`triple_owner`). `IN-BANK`'s save/restore mechanism (FR-P4-4) is independent of this — `IN-BANK` operates within nested execution; this AC governs the outermost loop only.
4. **AC4** — `src/system.asm`'s `w_ABORT_cf` (`:361`) and the `ABORT"` runtime `(ABORT")` / `w_PAREN_ABORT_QUOTE_cf` (`:179`) are **verified** per FR-P4-33: they raise `THROW` (`-1` / `-2`) which unwinds the data + return stacks and re-enters `QUIT` via `.throw_uncaught` (`src/exception.asm:538`, `JP w_QUIT_cf`), which then re-asserts the saved bank per AC3. The unwind path leaves the saved-bank cell intact (it is in UserArea, addressed via `IY`, not on the return stack reset by QUIT nor the parameter stack reset by `.throw_uncaught`). **No code change to `w_ABORT_cf` / `w_PAREN_ABORT_QUOTE_cf` is expected** — if one *is* needed, justify it in Dev Notes.
5. **AC5** — uncaught-THROW unwind across cross-bank frames: a probe raises an uncaught THROW from inside a colon definition running in a non-zero bank; the THROW unwind reaches `.throw_uncaught` (which deliberately does NOT restore the bank — see the "KNOWN LIMIT" comment at `src/exception.asm:539-542`), re-enters `QUIT`, and AC3's re-assertion then restores the user's last interactive bank. Verified end-to-end with `BANK@ .` reflecting the restored bank.
6. **AC6** (REPL probes — **new isolated fixture** `tests/banking_tests_21_2.fth`; see Dev Notes "Testing — isolated fixture, not the main suite") — probes:
   - **(a)** interactive `5 BANK!` then `ABORT`: REPL recovers (QUIT loops past the `-1` THROW), and a subsequent `BANK@ .` returns `5` (the interactive choice was saved and re-asserted).
   - **(b)** a colon word that internally does `7 BANK!` then raises a THROW, executed interactively from bank 0: after recovery `BANK@ .` returns the **pre-execution** bank (0), **not** 7 — the colon-internal `BANK!` did NOT update `saved_bank`, and QUIT re-asserted the pre-execution bank over the stranded `current_bank = 7`.
   - **(c)** **F6 verification** — an `INCLUDE`d `.fth` file that internally does `5 BANK! : SOMETHING ;` is `INCLUDE`d while the interactive bank is `3`; after `INCLUDE` completes, an `ABORT` followed by `BANK@ .` returns `3` (the pre-`INCLUDE` interactive bank), proving the `INCLUDE`d file's `BANK!` did NOT pollute the saved-bank cell. (Observed indirectly through ABORT-restores-to-saved, since no Forth word exposes `saved_bank` — see Dev Notes "Testing".)
   - **(d)** **hardware-mode interactive** (HW-typed batch, may be emulator-partial): type `7 BANK!` then trigger an asm-error THROW (`-258..-272`) from inside a banked CODE word; REPL recovers, `BANK@ .` returns `7` (interactive `BANK!` to 7 IS reflected in the saved cell; the THROW unwind preserves it).
7. **AC7** (probe surfaces + hardware smoke) — emulator-testable probes pass under the banking-capable emulator (`make test-repl-banking-isolated-21-2`); one hardware-typed probe batch covering AC6 (a)–(d) runs on real MicroBeast per S9 / NFR-P4-11. **(Post-HW-smoke recipe goes in the code-review closing message, not just here — `feedback_post_hw_smoke_steps_at_review`.)**
8. **AC8** (CCD-3 source citation) — the `src/outer_interpreter.asm` and (if touched) `src/system.asm` extensions cite `docs/antforth-banking-redesign.md §5.6` per NFR-P4-20; the F6 mitigation note cites the architecture's Findings **F6** row (`architecture.md:1013-1019`). Keep comments to **what + why-not-obvious only — no story/CR/date provenance in source** (`feedback_source_comment_discipline`).
9. **AC9** (binary delta) — `wc -c build/antforth.com` grows by **≤ ~70 B** for this story (interactive recogniser + QUIT bank-restore + ABORT pass-through verification); tracked against the Epic 21 ~150 B budget per Decision Impact Analysis. **Envelope watch (see Dev Notes "Binary budget"):** Story 21.1 already consumed **+82 B** of the ~150 B epic envelope, leaving only **~68 B** — so 21.2's ~70 B target sits right at the epic edge. Per-component itemisation in Dev Notes; the gate is the measured `wc -c` delta, not the estimate.
10. **AC10** — `make test-repl` **≥ 974 PASS / 0 FAIL** on iz-cpm (single-bank ABORT/QUIT semantics preserved exactly — the bank-0 case is the original Phase-3 behaviour: with `bank_count = 0`, `saved_bank == current_bank == 0` always, so the AC3 re-assert guard is a permanent no-op and the recogniser never sees a `BANK!` token); `make test-repl-banking` reports new probes PASS including the F6 INCLUDE-doesn't-pollute probe.

> **Adversarial review (`CR`) is NOT an acceptance criterion** and is not a dev-pass task — it runs separately via the `CR` command in fresh context after dev-pass close (PD-1, Story 13.5.0). Do not add a "trigger adversarial review" AC.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `make && wc -c build/antforth.com` → record in Dev Notes "Binary budget". **Do NOT inherit any number from this story text, the 21.1 story, or the Epic-20 retro** (B.3 / B.4 / Lesson 13.5-F). Note: at draft time the on-disk artifact read **27960 B** while the 21.1 story reported **27970 B** post-change — these disagree, so the *only* trustworthy baseline is a fresh clean-`make` at your dev-pass start. → **Measured fresh baseline = 27960 B.**
- [x] Capture current `make test-repl` baseline (expect ≥ 974 — 21.1 measured 975/0) and `make test-repl-banking` / isolated-target counts (21.1 measured: banking-main 61/0; isolated 20-1 7, 20-2 5, 20-3 5, 19-3 15, 19-4 2, 19-5-1 2, 21-1 4/0; straddle 3/3). → **Measured baseline: test-repl 975/0; banking-main 61/0; isolated 20-1 7, 20-2 5, 20-3 5, 19-3 15, 19-4 2, 19-5-1 2, 21-1 5; straddle 3/0.**

### Task 1 — Add the interactive-`BANK!` recogniser at the interpret loop's direct-execute path (AC: #1, #2, #8)

- [x] Sub-1.1 In `src/outer_interpreter.asm`, at `.interp_execute`, insert a token-identity recogniser around `w_EXECUTE_cf`. **DEVIATION from the story's recommended thread shape (it was unsound — see Completion Notes "Design correction").** The recommended `DUP`-before-`EXECUTE` shape corrupts `BANK!`'s argument (EXECUTE `POP`s its new TOS from *below* the xt, so a duplicated xt interposes between EXECUTE's xt and `n`); and stashing the xt on the *return* stack is also unsound (an interactively-typed `>R`/`R>` rearranges the return stack mid-EXECUTE). Implemented shape — **peek before, commit after, carry the recognition in a UserArea flag (neither stack)**:
  ```
  .interp_execute:
          DW      w_DROP_cf               ; ( xt flag -- xt )
          DW      w_QMARK_BANK_cf         ; ( xt -- xt )   peek: flag := interactive BANK!?
          DW      w_EXECUTE_cf            ; ( xt -- )      execute the word
          DW      w_QSAVE_BANK_cf         ; ( -- )         commit if flag set
          DW      w_BRANCH_cf
          DW      .interp_loop - $
  ```
  Reading `current_bank` *after* EXECUTE (in `QSAVE-BANK`) is still the robust choice: it reflects the bank actually switched to, and a throwing `BANK!` (`-2` / `-273`) skips `w_QSAVE_BANK_cf` on the unwind so a failed switch is never saved.
- [x] Sub-1.2 Add new **headerless** code words (a `*_cf` label + body only, like other kernel-internal thread helpers): `w_QMARK_BANK_cf` ( xt -- xt ) — **peek** the xt in `BC` *without consuming it* (compare `C`/`B` to `LOW`/`HIGH w_BANK_STORE_cf`); if not BANK! or `UserArea.include_top != 0` (OR low|high), clear `interp_bank_pending`; else set it to 1. `w_QSAVE_BANK_cf` ( -- ) — **commit**: if `interp_bank_pending` set, copy `(IY+UserArea.current_bank) → (IY+UserArea.saved_bank)`, zero `saved_bank+1`, clear the flag. STATE is already 0 here (AC2) — not re-tested. New `interp_bank_pending DB 0` field in `UserArea` (`src/structures.asm`).
- [x] Sub-1.3 Added AC8 source comment: cites `docs/antforth-banking-redesign.md §5.6` + the F6 finding (`architecture.md` Findings F6); explains *why* the check lives here (token identity distinguishes interactive `BANK!` from a colon word that calls `BANK!`) and why the flag (not a stack slot) carries it. No story/CR/date provenance.

### Task 2 — Extend `QUIT` to re-assert the saved bank on loop re-entry (AC: #3, #5, #8)

- [x] Sub-2.1 In `src/outer_interpreter.asm`, at the head of `.quit_loop` (before `w_QUERY_cf`), inserted a `DW w_REASSERT_BANK_cf` reference so it runs on every loop re-entry (harmless no-op when `saved_bank == current_bank`, the common case and the *entire* iz-cpm case).
- [x] Sub-2.2 Added a new **headerless** code word `w_REASSERT_BANK_cf`. Logic: load `A = (IY+UserArea.current_bank)`, `L = (IY+UserArea.saved_bank)`; if `A == L` → `NEXT` (covers `0 == 0` on iz-cpm — keeps AC10 green). Else `PUSH BC` (**preserve the data-stack TOS** — re-assert can fire with live data when a colon word switched bank and returned), set `C = saved`, `B = 0`, map slot 2 (`HL = ACTIVE_PAGES_BASE + saved`; `A = (HL)`; `CALL mbb_set_slot2`), write `current_bank ← saved` and `triple_owner ← saved` (with `A` = old bank captured *before* the overwrite), `PUSH DE` / `CALL bank_triple_swap` / `POP DE`, `POP BC`, `NEXT`. `bank_triple_swap` clobbers `DE`; `mbb_set_slot2` preserves `BC`/`DE`. **Added `PUSH BC`/`POP BC` not in the story sketch** — re-assert is not always entered on an empty stack.
- [x] Sub-2.3 Added the AC8 source comment (cites §5.6; notes the guard rationale + "no-op on iz-cpm" invariant + that it reuses the factored helpers; references the `.throw_uncaught` "KNOWN LIMIT" comment as the named downstream restorer).

### Task 3 — Verify `ABORT` / `ABORT"` pass-through (AC: #4) — verification, expect zero code change

- [x] Sub-3.1 Traced `w_ABORT_cf` (`src/system.asm:361` → `LD BC, THROW_ABORT (-1); JP w_THROW_cf.kernel_entry`) and `w_PAREN_ABORT_QUOTE_cf` (`src/system.asm:179` → prints msg → `LD BC, THROW_ABORT_QUOTE (-2); JP w_THROW_cf.kernel_entry`). Both land in `.throw_uncaught` (`exception.asm:538`) which prints, walks the INCLUDE chain, `CALL asm_cleanup`, `LD SP,(sp_base)`, `JP w_QUIT_cf`. **Neither path touches `UserArea.saved_bank`** (it is IY-addressed, on neither stack). **No edit needed** — AC4 satisfied by trace + the AC6(a)/(c) probes (both ABORT-then-`BANK@`).
- [x] Sub-3.2 N/A — the trace revealed no path that clobbers `saved_bank`; no defect to document, no patch made.

### Task 4 — New isolated REPL-probe fixture + Makefile target (AC: #6, #7, #10)

- [x] Sub-4.1 Created `tests/banking_tests_21_2.fth` — sentinel-delimited probes (`---probe-21.2-X-start/-end---` + `---probe-21.2-suite-end---`). Probes (a) interactive-`BANK!`-then-ABORT, (b) colon-internal-`BANK!`-then-THROW, (c) F6 INCLUDE-doesn't-pollute. Verdicts observed via `." bank=" BANK@ . CR` printed on a line **after** the ABORT/THROW (QUIT loops past it; `bank=N` is greppable). Max line 79 ch (≤ 128); 0x1A-terminated. INCLUDE helper `disk/a/P212INC.FTH` (`5 BANK! : _incw ;`) created, LF + 0x1A terminator (matches the proven `P193INC1.FTH` convention).
- [x] Sub-4.2 Added `make test-repl-banking-isolated-21-2` target + `.PHONY` entry, mirroring the 21-1 recipe. `awk` block extraction between sentinels; `grep -qE '^bank=N ?$'` for (a)=5, (b)=0 (and not 7), (c)=3 (and not 5), plus the end-sentinel presence check. Probes live in this isolated fixture, not the main suite.
- [x] Sub-4.3 Ran `make test-repl` (**975/0** ≥ 974), `make test-repl-banking` (**61/0**), all isolated targets (**no regressions**: 20-1 7, 20-2 5, 20-3 5, 19-3 15, 19-4 2, 19-5-1 2, 21-1 5, straddle 3/0), and the new **`-21-2` (4/0)** — all PASS. *(Caught + fixed a self-introduced 20-2/20-3 regression mid-dev — see Completion Notes.)*

### Task 5 — Verify binary budget + doc-sync (AC: #9)

- [x] Sub-5.1 `make && wc -c build/antforth.com` = **28069 B**; delta vs 27960 B baseline = **+109 B**. **OVER the AC9 ~70 B per-story line.** Cumulative Epic-21 = 21.1 (+82 B) + 21.2 (+109 B) = **+191 B** vs the ~150 B envelope (~+41 B / ~1.27×). Per-component overrun + cause recorded in Completion Notes. **Flagged for the SCP evaluation gated at Story 21.3 AC7 / NFR-P4-5** — NOT SCP'd now (`project_epic17_envelope`: cite, don't re-litigate; the per-story AC9 is the ~70 B line, the *epic* total is the SCP trigger).
- [x] Sub-5.2 `make check-doc-sync` → **0 drift** (31 advisory items, unchanged).

## Dev Notes

### Design — the recogniser MUST live at `.interp_execute` (the load-bearing decision)

The interpret loop (`src/outer_interpreter.asm:178-319`) is a threaded `DEFWORD`. In interpret state it resolves a token via `FIND`, branches on `STATE` (`:192-195`), and for the interpret-state case reaches `.interp_execute` (`:212`), which does `DROP` (the FIND flag) then `EXECUTE` (the xt). **This is the only site that executes a directly-parsed token's xt under the text interpreter in interpret state.** (The IMMEDIATE-in-compile path at `:204` is `STATE ≠ 0`, so it is never interactive.)

Why this matters: the spec must separate two scenarios that are identical on `STATE` + `include_top`:

| Scenario | At the moment `BANK!` runs | Distinguishing signal |
|---|---|---|
| User types `7 BANK!` (AC6 d) | `STATE=0`, `include_top=0` | the **token** at `.interp_execute` *is* `BANK!` |
| User types `MYWORD` where `MYWORD` does `7 BANK!` (AC6 b) | `STATE=0`, `include_top=0` | the token at `.interp_execute` is `MYWORD`; `BANK!` runs nested under `MYWORD`'s `DOCOL` frame, never re-entering `.interp_execute` |
| `INCLUDE`d file does `5 BANK!` (AC6 c, F6) | `STATE=0`, **`include_top≠0`** | same loop, but the INCLUDE-TOP chain is non-empty |

So the recogniser is **token-identity at `.interp_execute`** (xt == `w_BANK_STORE_cf`) **gated by `include_top == 0`**. Putting the check *inside* `w_BANK_STORE_cf` would mis-fire on AC6(b) (it can't see whether its caller is the interpreter or a colon body without walking the R-stack — rejected on cost, mirrors the BANK! window-guard's own "R-stack walking was rejected on cost" note at `banking.asm:144`).

**Edge cases (documented limits, not blockers):** `' BANK! EXECUTE` and `S" .. BANK!" EVALUATE` typed interactively do not (resp. may not) update `saved_bank` — the token at `.interp_execute` is `EXECUTE`/`EVALUATE`, not `BANK!`. The spec's probes only cover the direct `<n> BANK!` form; note this in a source comment if convenient, otherwise leave as-is.

### Design — QUIT re-assertion reuses factored helpers; the guard keeps iz-cpm green

`w_QUIT_cf` (`:328`) currently resets the R-stack, `STATE`, and `CATCH-TOP`, then enters `.quit_loop` (`:345`). The `.throw_uncaught` path (`exception.asm:538`) explicitly does NOT restore the bank — its `:539-542` comment names QUIT as the downstream restorer. So the re-assertion belongs in `.quit_loop`.

Reuse the **already-factored** helpers rather than duplicating BANK!'s body:
- `mbb_set_slot2` (`banking.asm:79`, ENTRY `A` = physical page; preserves `BC`, `DE`) — maps slot 2.
- `bank_triple_swap` (`banking.asm:263`, ENTRY `A` = save-target/old bank, `C` = load-source/new bank; clobbers `A,BC,DE,HL`, preserves `IX,IY`) — swaps the live `(HERE,LATEST,wordlist_head)` triple. **This is the same helper BANK! and the THROW caught-path use** — using it keeps the dictionary triple coherent after the restore (a naive `current_bank ← saved_bank` *without* the triple swap would leave HERE/LATEST pointing at the wrong bank's tail — a latent corruption).

**The `saved_bank == current_bank` guard is mandatory for AC10.** On the non-banking iz-cpm build `bank_count = 0`, no interactive `BANK!` is ever possible (`BANK!` would `THROW -2` for any `n ≥ 0`), so `saved_bank` and `current_bank` are both永 0 — the guard makes the re-assert a permanent no-op and the `make test-repl` path byte-for-byte unchanged in behaviour. (Do **not** instead thread `saved_bank BANK!` unconditionally: with `bank_count = 0` that raises `-2` "bank?" on every REPL line and breaks iz-cpm.)

### Why ABORT/ABORT" need no new code (AC4)

`w_ABORT_cf` (`system.asm:361`) → `LD BC, THROW_ABORT (-1)` → `JP w_THROW_cf.kernel_entry`. `ABORT"`'s runtime `(ABORT")` / `w_PAREN_ABORT_QUOTE_cf` (`system.asm:179`) prints the message then `LD BC, THROW_ABORT_QUOTE (-2)` → `JP w_THROW_cf.kernel_entry`. Both land in the uncaught handler `.throw_uncaught` (`exception.asm:538`): it prints the error, walks the INCLUDE chain to close FIDs, `CALL asm_cleanup`, `LD SP,(sp_base)` (parameter-stack reset), `JP w_QUIT_cf` (QUIT resets the R-stack). **`saved_bank` is a UserArea cell addressed via `IY`** — it is on neither stack, so the unwind cannot touch it. AC4 is therefore a *trace + probe* verification; the bank restoration is entirely AC3's QUIT re-assertion. The same is true for any uncaught THROW (AC5): cross-bank frames unwind via the trampoline/recursive `cross_bank_return` mechanism (Epic 18.2), and the bank is restored only once control reaches QUIT.

### Testing — isolated fixture, not the main suite (and how to observe `saved_bank`)

Follow the 21.1 / 20.x precedent: behavioural `BANK!`-then-error probes go in a **dedicated isolated fixture** (`tests/banking_tests_21_2.fth`) with only the probe code loaded, NOT the main `tests/banking_tests.fth` suite. Reason (`feedback_phase4_probe_bank_switch_limitation`): the main suite's own dictionary straddles `$8000`, so any token lookup while a non-zero bank is mapped can walk a bucket chain through the portal window and read the foreign page (a `-13` strand; ADR 19.5 DR-1 portal-aliasing). The isolated fixture sidesteps this.

The harness recovers past ABORT/THROW: `tests/banking_tests_21_1.fth` + its recipe already rely on this (the `---probe-21.1-suite-end---` sentinel asserts "kernel recovered from -13, no mid-suite halt"). So an `ABORT` (`-1`) on one line, followed by `BANK@ .` on the next, works — QUIT loops, AC3 re-asserts, the next line reads `BANK@`.

**No Forth word exposes `saved_bank`** (only `BANK@` reads `current_bank`, `banking.asm:110`). Observe `saved_bank` *indirectly* through its effect: after an ABORT/THROW, QUIT copies `saved_bank → current_bank`, so `BANK@ .` post-recovery reports the value `saved_bank` held. The probes are built around this:
- **(a)** `5 BANK!` (interactive → `saved_bank=5`), `ABORT`; next line `BANK@ .` → `5`. (Here `current_bank` was already 5, so this mainly proves the interactive write happened and survived ABORT.)
- **(b)** Define `: _w7t  7 BANK! 999 THROW ;` in bank 0 (interactive `BANK!`s while *defining* don't run — the body is compiled). Then interactively `0 BANK!` (saved=0). Execute `_w7t`: inside it `7 BANK!` runs nested (xt at `.interp_execute` is `_w7t`, not `BANK!` → `saved_bank` stays 0), then `999 THROW` strands `current_bank=7`. After recovery `BANK@ .` → `0`, **not** 7. This is the core anti-stranding proof.
- **(c, F6)** Helper file (e.g. `tests/banking_tests_21_2_inc.fth`) containing `5 BANK! : _incw ;`. Interactively `3 BANK!` (saved=3), `INCLUDE` the helper (its `5 BANK!` runs with `include_top≠0` → `saved_bank` stays 3; after INCLUDE `current_bank=5`), then `ABORT`; `BANK@ .` → `3` (not 5). If the recogniser wrongly counted the INCLUDEd `BANK!`, this would print `5`.
- **(d)** Hardware-only flavour (asm-error THROW `-258..-272` from a banked CODE word); may be emulator-partial — mark it HW-batch in the fixture comment and the closing CR message.

Mirror the `Makefile:960` recipe: `sed 's/$$/\r/' … | $(IZCPM_BANKING) …`, `awk` block extraction, `grep -qE` for `BANK@`'s output (`grep -qE '^5 ok'` style) and the end-sentinel.

### Binary budget (AC9) — per-component itemisation

> Itemised independently per the B.2 / Lesson 13.5-C rule (no "mirrors prior story" analogy as the load-bearing estimate). Figures are opcode-byte estimates; the gate is the measured `wc -c` delta at Sub-5.1, **not** this table.

**Recogniser (Task 1):**
| Component | Est. bytes |
|---|---|
| `.interp_execute` thread edit: insert `DW w_DUP_cf` + `DW w_QSAVE_BANK_cf` (2 cells) | ~4 |
| `w_QSAVE_BANK_cf` body: pop xt→BC; cmp BC vs `w_BANK_STORE_cf` (LD A,C / CP L / JR NZ / LD A,B / CP H / JR NZ ≈ 10); `include_top` OR-test + JR NZ (≈ 6); copy `current_bank→saved_bank` + zero hi (≈ 8); `POP BC` + `NEXT` (≈ 2) | ~26 |
| **Recogniser subtotal** | **~30** |

**QUIT re-assertion (Task 2):**
| Component | Est. bytes |
|---|---|
| `.quit_loop` thread edit: insert `DW w_REASSERT_BANK_cf` (1 cell) | ~2 |
| `w_REASSERT_BANK_cf` body: load current/saved + `CP` + `JR Z` (≈ 8); `ADD HL,BC` slot-2 map + `CALL mbb_set_slot2` (≈ 10); write `current_bank`/`triple_owner` + set A=old (≈ 8); `PUSH DE`/`CALL bank_triple_swap`/`POP DE` (≈ 5); `NEXT` (≈ 1) | ~32 |
| **QUIT subtotal** | **~34** |

**ABORT/ABORT" (Task 3):** ~0 B (verification only).

**Estimated total ≈ ~64 B** — under the AC9 ~70 B line. Realistic outcomes on this codebase run ~1.25× over per-component asm estimates (`feedback_kernel_ldir_estimate_overshoot`), so a measured ~75–80 B would not surprise. **Epic-envelope reality:** 21.1 = +82 B of the ~150 B Epic-21 envelope → ~68 B remain. A ~64 B outcome keeps the epic at ~146 B (within); a ~80 B outcome pushes to ~162 B (over). Story 21.3 (close-out) is banner/README/`description` string edits (~handful of bytes). **If 21.2 lands > ~68 B, flag it for the SCP evaluation gated at Story 21.3 AC7 / NFR-P4-5** — do not pre-emptively SCP (the per-story AC9 is the ~70 B line; the *epic* total is the SCP trigger; `project_epic17_envelope.md` — cite, don't re-litigate). The Epic-20 envelope multiplier is **void only on mechanism substitution**; this story is pure-addition wiring (no substitution), so normal calibration applies.

### Source tree components to touch

| File | What |
|---|---|
| `src/outer_interpreter.asm` (`.interp_execute:212`, `.quit_loop:345`) | Recogniser + new `w_QSAVE_BANK_cf`; QUIT re-assert + new `w_REASSERT_BANK_cf` (Tasks 1, 2) |
| `src/system.asm` (`w_ABORT_cf:361`, `w_PAREN_ABORT_QUOTE_cf:179`) | **Verify only** — no edit expected (Task 3) |
| `tests/banking_tests_21_2.fth` (new) + `tests/banking_tests_21_2_inc.fth` (new, INCLUDE helper for probe c) | Isolated behavioural probes (Task 4) |
| `Makefile` (`.PHONY:52`, new target near `:960`) | `test-repl-banking-isolated-21-2` |

**Do not touch:** `w_BANK_STORE_cf` / `mbb_set_slot2` / `bank_triple_swap` (`src/banking.asm`) — reuse as-is (putting the recogniser there is the rejected design). `active_pages[]` / `bank_count` / the stub allocator. The existing `.throw_uncaught` path (`exception.asm`) — its "QUIT re-asserts downstream" comment becomes *true* once AC3 ships; do not delete it.

### Key facts (verified at draft time)

- `UserArea.saved_bank` (`structures.asm:44`): `DW 0`; COLD-init 0 (`antforth.asm:158-159`); **zero read/write sites today** — this story adds both.
- `UserArea.include_top` (`structures.asm:41`): `DW 0` = no INCLUDE frame active; non-zero = inside an INCLUDEd file. The depth-1 test is `include_top == 0` (OR low|high).
- `UserArea.current_bank` (`structures.asm:45`): live bank index; `BANK@` returns it (`banking.asm:110-114`). `triple_owner` (`structures.asm:55`) keys the live triple; BANK! writes both.
- `.interp_execute` (`outer_interpreter.asm:212`) is reached only when `STATE = 0` (QBRANCH at `:194`) — STATE clause of AC2 is structural.
- `w_BANK_STORE_cf` (`banking.asm:167`) is a fixed kernel label — comparable against directly as a 16-bit literal in `w_QSAVE_BANK_cf`.
- `w_QUIT_cf` (`outer_interpreter.asm:328`) → `.quit_loop` (`:345`); `.throw_uncaught` (`exception.asm:538`) `JP w_QUIT_cf` after SP reset; the `:539-542` "KNOWN LIMIT" comment names QUIT as the bank restorer.
- `mbb_set_slot2` (`banking.asm:79`): `A` = physical page → maps slot 2 via `MBB_SET_PAGE` (0xFDDF); preserves `BC/DE/HL`. `bank_triple_swap` (`banking.asm:263`): `A`=old, `C`=new; clobbers `A,BC,DE,HL`; preserves `IX,IY`. `ACTIVE_PAGES_BASE` = `$D4AE` (`banking.asm:29`).
- Harness recovers past THROW/ABORT (the 21.1 suite-end sentinel proves it) — so multi-line ABORT-then-`BANK@` probes are valid.

### Project Structure Notes

- Aligns with the established per-story banking layout: kernel changes in `src/`, isolated behavioural probes in `tests/banking_tests_NN_M.fth`, dedicated `make test-repl-banking-isolated-NN-M` target. New `w_QSAVE_BANK_cf` / `w_REASSERT_BANK_cf` are headerless internal code words (same pattern as other kernel-internal helpers) — no dictionary headers, no FIND surface.
- Reuses existing factored primitives (`mbb_set_slot2`, `bank_triple_swap`) rather than duplicating BANK!'s switch body — keeps the binary delta inside the AC9 budget and the triple coherent.

### References

- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:1073-1094`] — Story 21.2 spec (ACs verbatim).
- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:1034-1048`] — Epic 21 goal / FRs (FR-P4-31/32/33) / NFRs (NFR-P4-7/8) / arch inputs (Epic 18.2, F6).
- [Source: `_bmad-output/planning-artifacts/architecture.md:1013-1019`] — Findings **F6**: interactive-`BANK!` recogniser = `STATE @ 0=` AND outer-depth=1 (AC2/AC8).
- [Source: `_bmad-output/planning-artifacts/prd.md:559-561`] — FR-P4-31/32/33 requirement text.
- [Source: `docs/antforth-banking-redesign.md §5.6` (line ~164)] — ABORT/QUIT bank-state restore (S5 resolution); §5.4 (line ~109) per-bank triple (AC8).
- [Source: `src/outer_interpreter.asm:178-319` INTERPRET / `:212` `.interp_execute` / `:328` `w_QUIT_cf` / `:345` `.quit_loop`] — extension points.
- [Source: `src/system.asm:361` `w_ABORT_cf`; `:179` `w_PAREN_ABORT_QUOTE_cf`] — ABORT pass-through (verify).
- [Source: `src/exception.asm:538-571` `.throw_uncaught` (`JP w_QUIT_cf`); `:539-542` bank-restore "KNOWN LIMIT" comment] — unwind path.
- [Source: `src/banking.asm:79` `mbb_set_slot2`; `:110` `w_BANK_AT_cf`; `:167` `w_BANK_STORE_cf`; `:263` `bank_triple_swap`; `:29` `ACTIVE_PAGES_BASE`] — primitives to reuse / compare against.
- [Source: `src/structures.asm:41` `include_top`, `:44` `saved_bank`, `:45` `current_bank`, `:55` `triple_owner`; `src/antforth.asm:158-159` saved_bank COLD-init] — cell definitions.
- [Source: `tests/banking_tests_21_1.fth`; `Makefile:960` `test-repl-banking-isolated-21-1`; `.PHONY:52`] — fixture + isolated-target recipe to mirror.
- [Memory: `feedback_phase4_probe_bank_switch_limitation`, `feedback_tib_size_inline_comments`, `feedback_cpm_0x1a_eof_marker`, `feedback_source_comment_discipline`, `feedback_post_hw_smoke_steps_at_review`, `feedback_kernel_ldir_estimate_overshoot`, `feedback_no_accept_disposition_for_bugs`, `project_epic17_envelope`, `banking_bios_pivot`] — applicable disciplines.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — dev-story workflow.

### Debug Log References

- Baseline clean `make`: 27960 B; test-repl 975/0; banking-main 61/0; isolated 20-1 7 / 20-2 5 / 20-3 5 / 19-3 15 / 19-4 2 / 19-5-1 2 / 21-1 5; straddle 3/0.
- Mid-dev regression caught: first implementation stashed xt on the **return stack** (`DUP >R` … pop-in-asm). Isolated 20-2-b/20-3 verdict lines use interactively-typed `>R`/`R>`; those rearrange the return stack mid-EXECUTE, so the post-execute pop read the user's data instead of the stashed xt → `result=2593` (stack misalignment). Confirmed self-introduced by stashing the source change and re-running 20-2 on the baseline (got `result=-1`). Re-architected to the peek/flag/commit design (no stack used to carry the recognition); 20-2/20-3 back to green.
- Final: 28069 B (+109 B); test-repl 975/0; banking-main 61/0; isolated 20-1 7 / 20-2 5 / 20-3 5 / 19-3 15 / 19-4 2 / 19-5-1 2 / 21-1 5 / **21-2 4**; straddle 3/0; file-sanity PASS; doc-sync 0 drift.

### Completion Notes List

**Design correction (load-bearing — the story's recommended thread shape was unsound).** The story's Sub-1.1 sketch (`DROP DUP EXECUTE QSAVE`, with `QSAVE` popping xt from the *data* TOS) does not work, for two independent reasons verified against the kernel:
1. `w_EXECUTE_cf` (`inner_interpreter.asm:329`) does `LD H,B / LD L,C / POP BC / JP (HL)` — it takes the new TOS from *below* the xt. A data-stack `DUP` of the xt therefore interposes between EXECUTE's xt and `BANK!`'s `n` argument, so `BANK!` reads the xt as its bank index (→ `-2 bank?`).
2. Stashing the xt on the **return stack** (`DUP >R` … pop-in-asm after EXECUTE) is *also* unsound: an interactively-typed `>R`/`R>` (exercised by the 20-2/20-3 verdict lines) rearranges the return stack across the EXECUTE boundary, so the post-execute pop retrieves the wrong cell and corrupts the R-stack.

Implemented design — **peek before, commit after, carry the recognition in a one-shot UserArea flag** (`interp_bank_pending`, `structures.asm`), which is immune to both stacks because the executed word can rearrange either but never touches that cell:
- `w_QMARK_BANK_cf` ( xt -- xt ) runs *before* EXECUTE, peeks `BC`=xt without consuming it, and sets the flag iff `xt == w_BANK_STORE_cf && include_top == 0`, else clears it.
- `w_QSAVE_BANK_cf` ( -- ) runs *after* EXECUTE and, iff the flag survived (a throwing `BANK!` skips this on the unwind), copies `current_bank → saved_bank` and clears the flag.
The clear-by-default in `QMARK` also self-heals the post-throw case (flag left set by a skipped `QSAVE` is cleared by the next token's `QMARK` before any later `QSAVE` can read it). Reading `current_bank` post-EXECUTE keeps the story's intended robustness (actual switched-to bank; failed switch never saved).

**QUIT re-assertion** (`w_REASSERT_BANK_cf` at `.quit_loop` head) reuses the factored `mbb_set_slot2` + `bank_triple_swap` helpers (keeps the live HERE/LATEST/wordlist triple coherent). Added `PUSH BC`/`POP BC` around the switch (not in the story sketch) because re-assert can fire with a live data-stack TOS — e.g. a colon word that switched bank and returned cleanly leaves `current_bank != saved_bank` with data on the stack. The `saved_bank == current_bank` guard makes it a permanent no-op on single-bank iz-cpm (keeps AC10 green / behaviour byte-identical).

**ABORT/ABORT" (AC4):** verification only, **no code change** — both are `JP w_THROW_cf.kernel_entry`; the uncaught handler resets SP and `JP w_QUIT_cf`, never touching the IY-addressed `saved_bank`. The pre-existing `.throw_uncaught` "KNOWN LIMIT" comment naming QUIT as the downstream restorer becomes *true* with this story.

**AC5 (uncaught THROW across cross-bank frames):** exercised end-to-end by probe-21.2-b — `_w7t` switches `current_bank→7` mid-body then raises `999 THROW`; the unwind reaches `.throw_uncaught` (which deliberately does NOT restore the bank), re-enters QUIT, and `w_REASSERT_BANK_cf` restores the saved bank; `BANK@ .` reports `0`.

**AC6(d) is HARDWARE-ONLY** (asm-error THROW `-258..-272` from a banked CODE word; emulator-partial) — it is intentionally **not** in the isolated emulator fixture and is part of the HW-typed batch (AC7 / S9). Recipe in the closing message.

**HW smoke — PASS on real MicroBeast 2026-06-12** (`beastty-20260612-122451.bin`, AntForth v3.0.5, 12 banks):
- (a) `0 bank! 5 bank! abort` → `bank@ .` = **5** ✓ (interactive BANK! saved + re-asserted across ABORT on silicon).
- (b) `: _w7t 7 bank! 999 throw ; 0 bank! _w7t` → `bank@ .` = **0** ✓ (colon/cross-bank BANK! did NOT pollute; QUIT un-stranded). *Inner error was `-273` not `999 THROW` — a test-sequencing artifact: the line was typed while the live bank was still 5 (left over from probe a), so `_w7t` landed in bank 5 and its `7 bank!` ran from the portal window → `-273`. Verdict (bank=0) unaffected; anti-stranding confirmed regardless of which THROW fires.*
- (d) `7 bank!` → `bank@ .` = **7** ✓ (interactive BANK!→7 reflected in the saved cell on silicon).

Covers AC7's hardware-typed batch for AC6(a)/(b)/(d). AC6(c) F6/INCLUDE is emulator-verified (`test-repl-banking-isolated-21-2`); not in this HW batch.

**Binary delta = +109 B (over the AC9 ~70 B line).** Cause: the sound design needs *three* small headerless words (`QMARK` peek + `QSAVE` commit + `REASSERT`) plus a UserArea flag, where the story's (unsound) one-`QSAVE` sketch estimated ~64 B; the extra `QMARK` word + the `PUSH/POP BC` in `REASSERT` + normal ~1.25× asm overshoot account for the gap. Per-component (measured-region estimates): `QMARK` ~24 B, `QSAVE` ~20 B, `REASSERT` ~42 B, thread cells +4 B, flag field 0 B in `.com` (trailing DS). Epic-21 cumulative = +82 (21.1) + 109 (21.2) = **+191 B vs ~150 B envelope (~+41 B, ~1.27×)**. **Flagged for the SCP evaluation gated at Story 21.3 AC7 / NFR-P4-5** — not SCP'd now per `project_epic17_envelope` (per-story AC9 = the ~70 B line; the *epic* total is the SCP trigger). The Epic-20 envelope multiplier is void only on mechanism *substitution*; this is pure-addition wiring, so normal ~2.4× calibration applies and the epic sits within it.

### File List

- `src/outer_interpreter.asm` — `.interp_execute` recogniser thread (DROP/QMARK/EXECUTE/QSAVE); new headerless `w_QMARK_BANK_cf` + `w_QSAVE_BANK_cf`; `.quit_loop` re-assert thread cell; new headerless `w_REASSERT_BANK_cf`.
- `src/structures.asm` — new `interp_bank_pending DB 0` field in `UserArea`.
- `tests/banking_tests_21_2.fth` — new isolated probe fixture (probes a/b/c + suite-end sentinel; 0x1A-terminated).
- `disk/a/P212INC.FTH` — new INCLUDE helper for probe (c) F6 (LF + 0x1A terminator).
- `Makefile` — new `test-repl-banking-isolated-21-2` target + `.PHONY` entry.

### Change Log

- 2026-06-12 — Story 21.2 implemented: interactive-`BANK!` recogniser at the interpret loop's direct-execute path (peek/flag/commit design) + `QUIT` saved-bank re-assertion on REPL re-entry; `ABORT`/`ABORT"` pass-through verified (no code change). New isolated fixture `banking_tests_21_2.fth` (3 emulator probes + suite sentinel) + `test-repl-banking-isolated-21-2`. Binary +109 B (over AC9 ~70 B; flagged for SCP eval at 21.3). All gates green: test-repl 975/0, banking-main 61/0, all isolated targets, straddle 3/0, file-sanity, doc-sync 0 drift. Status → review.
- 2026-06-12 — HW smoke PASS on real MicroBeast (`beastty-20260612-122451.bin`, v3.0.5): AC6(a) bank=5, AC6(b) bank=0 (anti-stranding; inner -273 sequencing artifact), AC6(d) bank=7. AC7 hardware batch satisfied.
