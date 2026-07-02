# Story 25.5: Per-bank task switching

Status: done

> **Epic 25 bring-up step 5 — make the switch *bank-aware*.** Stories 25.1–25.4
> built the fixed-memory scheduler: `PAUSE`/ring/TCB/`TASK`/`ACTIVATE` (25.1),
> the KEY-hooked yielding REPL (25.2), yielding `DELAY` (25.3), and
> `SLEEP`/`WAKE`/`.TASKS`/`>TASK` task management (25.4). Throughout, `PAUSE`
> has saved and restored the per-task `current_bank` cell **but never re-paged
> the MMU** — every task has been forced to share the operator's live bank
> (single-bank scheduler). This is the bring-up order's deliberate
> "fixed-memory-switch-first" sequencing (AD-P6 §7). This story lights up the
> last piece of the per-task state model: when `PAUSE` selects a next task whose
> `current_bank` differs from the outgoing one, it re-pages slot 2 via
> `MBB_SET_PAGE` (conditionally — only on a bank change) so concurrent tasks can
> live in different banks. It is a **small, surgical kernel change** at one
> already-documented seam, plus a genuinely hard cross-bank switch probe and a
> per-switch overhead measurement.

## Story

As a task author,
I want a task to run code in any memory bank with its bank preserved across yields,
so that concurrent tasks can live in different banks.

## Acceptance Criteria

(Verbatim from `epics-phase6-epics-24-26.md` Story 25.5, lines 310–323; BDD form.)

1. **AC1 — conditional re-page on a bank-differing switch (AD-P6-1, AD-P6-3 step 4,
   NFR-P6-1).**
   **Given** the fixed-memory scheduler (Stories 25.1–25.4) and the Phase-4
   banking subsystem,
   **When** `PAUSE` switches to a task whose `current_bank` differs from the
   outgoing one,
   **Then** it restores the next task's `current_bank` and re-pages via
   `MBB_SET_PAGE` (0xFDDF) — **conditionally, only when the bank differs** —
   never a direct MMU port write (NFR-P6-13). Same-bank switches do **not** call
   the BIOS (the common case stays free).

2. **AC2 — operator-only-compile lock preserved (FR24).**
   Compilation remains a single shared operator-task activity; background tasks
   execute pre-compiled words only. This story adds **no** compile-side change and
   must not let a background task touch HERE/LATEST/wordlist/triple (AD-P6-1
   "global cells never written by a background path").

3. **AC3 — per-switch page-call overhead measured and documented (NFR-P6-1).**
   The cost of the conditional re-page is measured (the BIOS `MBB_SET_PAGE` path
   on a cross-bank switch; the near-zero compare-and-skip on a same-bank switch)
   and documented, so the switch stays bounded and cheap at 8 MHz.

4. **AC4 — cross-bank switch probe + S9 (NFR-P6-6).**
   A cross-bank switch probe (interpret-level, dodging the `$8000` straddle-halt)
   runs under the banking-capable emulator and is hardware-verified (cross-bank
   switch + `INCLUDE`-after-activation, S9); binary delta recorded.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev
      Notes. **Do not inherit the figure below** — re-`wc -c` from the actual
      current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out
      6-byte doc-drift). At story-drafting time (2026-06-30) the committed tree
      measured **30,265 B** (HEAD = Story 25.4 close, +225 B); the dev-pass
      baseline may differ if commits have landed since. **Measured pre-edit
      (clean rebuild at dev-pass start, HEAD b82733f): 30,293 B.**
- [x] Capture current `make test-repl` baseline pass count (the 0-FAIL floor,
      NFR-P6-5) — including `test-repl-timer` (9/9), `test-repl-multitasker`
      (5/5), `test-repl-multitasker-key` (5/5), `test-repl-multitasker-delay`
      (6/6), `test-repl-multitasker-tasks` (8/8), and `test-repl-banking`
      (60/0 + the isolated banking fixtures). **Measured floor: timer 9/9,
      multitasker 5/5, key 5/5, delay 6/6, tasks 8/8, throw 5/5, banking 57/0
      (the drafted "60" was stale — 57 is the actual current PASS count).**

### Task 1 — Conditional `MBB_SET_PAGE` re-page in the `PAUSE` resume tail (AC1) — `src/multitasker.asm`

- [x] **The whole kernel change is at one seam.** `PAUSE`'s resume tail
      `sched_resume_current` (`multitasker.asm:137-150`) already restores the
      next task's `current_bank` as a plain cell and carries the explicit
      placeholder comment: *"NO MBB_SET_PAGE re-page in this story —
      current_bank is copied as a cell only; the conditional page call on a bank
      change is Story 25.5"* (`:138-140`). This story **replaces that comment**
      with the conditional re-page. Do **not** touch the save side (step 2,
      `:100-114`), the ring walk (step 3, `:115-131`), or the register
      restore/`NEXT` (step 5, `:151-...`) — only step 4.
- [x] **Capture the outgoing bank BEFORE the subset restore overwrites it.** At
      `sched_resume_current` entry the live `(IY+UserArea.current_bank)` still
      holds the **outgoing** task's bank — in the `PAUSE` path it has not yet
      been overwritten; in the exception-handler entry path
      (`exception.asm:592-599` jumps here after setting `current_tcb =
      operator_tcb`) it holds the **faulting** task's bank. So the live cell is
      the correct "from" value for **both** entry paths. Read it into a register
      that survives `RESTORE_UA_CELL` (which clobbers only A) and the `sp_base`
      restore — e.g. `LD A,(IY+UserArea.current_bank) / LD B,A` (B is free here;
      it is reloaded from the scratch bridge in step 5). The high byte is
      invariantly 0 (bank index < 29), so the **low byte alone** is the compare
      key.
- [x] **After the subset + `sp_base` restore, compare and conditionally re-page.**
      The `RESTORE_UA_CELL UserArea.current_bank` at `:144` has now written the
      **next** task's bank into the live cell. Compare it against the captured
      outgoing bank; if equal, skip (zero BIOS cost). If different, look up the
      physical page and map slot 2 — the **first three operations of
      `switch_live_bank_to_c`** (`banking.asm:402-406`) minus the triple swap:

      ```
      ; (4b) Story 25.5 — re-page slot 2 iff the next task's bank differs from
      ;      the outgoing one. current_bank.high is invariantly 0 (idx < 29), so
      ;      the low byte is the whole compare key. mbb_set_slot2 preserves
      ;      BC/DE/HL (banking.asm:124); HL is reloaded in step 5 regardless.
              LD      A, (IY+UserArea.current_bank)   ; A = next bank (just restored)
              CP      B                               ; B = outgoing bank (captured above)
              JR      Z, .same_bank                   ; same bank → no BIOS call (NFR-P6-1)
              LD      C, A                            ; C = next bank index
              LD      B, 0                            ; high byte invariantly 0
              LD      HL, ACTIVE_PAGES_BASE
              ADD     HL, BC                          ; HL -> active_pages[next]
              LD      A, (HL)                         ; A = physical page
              CALL    mbb_set_slot2                   ; map slot 2; preserves DE=IP, BC, HL
      .same_bank:
      ```
- [x] **Do NOT swap the per-bank triple.** `switch_live_bank_to_c` also writes
      `triple_owner` and calls `bank_triple_swap` — that is the **compile-side**
      machinery for `BANK!`, and it is forbidden on the scheduler path:
      HERE/LATEST/wordlist/triple_owner are **global, operator-owned** cells, NOT
      per-task (AD-P6-1 "Explicitly NOT per-task"; the operator-only-compile
      lock). A background task executes pre-compiled words; it never parses or
      compiles, so the dictionary triple must stay exactly as the operator left
      it. Re-page **only** maps the MMU window. (If a future story ever needs a
      background task to compile, that is an architecture change — escalate, do
      not swap the triple here. AC2.)
- [x] **Register/IP contract (25.1 gotcha #1 — `PAUSE` is the ONLY DE-swapping
      word, and it does that swap via the TCB, not here).** The re-page must
      preserve DE=IP for the trailing `NEXT`. `mbb_set_slot2` already preserves
      DE/BC/HL (`banking.asm:124-135` — it `PUSH DE/HL/BC` around the BIOS call).
      Confirm no path through step 4 leaves DE clobbered.
      (`project_multitasker_pause_register_contract`.)
- [x] **`mbb_set_slot2` / `ACTIVE_PAGES_BASE` are cross-module but kernel-local.**
      Both live in `banking.asm`, linked below `$8000` like `multitasker.asm`;
      `PAUSE` already `CALL`s cross-module kernel routines (`bdos_print_str` in
      `.TASKS`), so the call is in-bounds. Confirm `ACTIVE_PAGES_BASE` is the
      EQU `switch_live_bank_to_c` uses (`banking.asm:403`) — address it by name,
      never a magic offset.
- [x] **Bank-0 / operator round-trip is correct by construction.**
      `active_pages[0]` is the portal page; re-paging to bank 0 maps slot 2 back
      to the portal window — the right thing when switching to (or back to) the
      operator. The exception-handler entry (faulting bg task → operator) thus
      re-pages to the operator's bank for free via this same seam. Verify, note.

### Task 2 — Measure & document the per-switch page-call overhead (AC3) — Dev Notes + source comment

- [x] **Measure both arms.** (a) *Same-bank* (the overwhelmingly common case): the
      added cost is the `LD A / CP B / JR Z` compare-and-skip = a handful of
      T-states, no BIOS call. (b) *Cross-bank*: the BIOS `MBB_SET_PAGE` round-trip
      (0xFDDF) plus the `active_pages` lookup. State the measured/derived cost
      (T-states at 8 MHz, or wall-clock from an S9 timing observation) for each.
      Reference the existing `MBB_SET_PAGE` characterisation from the Phase-4
      banking work if a figure already exists (`reference_microbeast_user_interrupt_timer`,
      banking docs) — but re-validate it at draft time, do not transcribe a stale
      number (PD-2 / B.4 figure-drift discipline).
- [x] Record the cost in Dev Notes (NFR-P6-1 deliverable) and, if it clarifies the
      seam, a one-line **what + why** source comment (no provenance —
      `feedback_source_comment_discipline`). The honest framing: same-bank
      switches stay free; cross-bank switches pay one BIOS page call, by design —
      the documented per-switch banking cost (AD-P6-3 step 4).

### Task 3 — Cross-bank switch probe (AC1, AC4) — `tests/multitasker_bank_tests.fth` (new), `Makefile`

- [x] **This is the hard probe of the story.** A cross-bank task switch requires
      banks to exist and a task whose `current_bank` ≠ the operator's. Build it at
      **interpret level** (caller IP < `$8000`, dodging the `$8000` straddle-halt
      and the `BANK!` portal-window `-273` guard), driving bank/task orchestration
      with `'` not `[']` (`feedback_banking_probe_straddle_halt`,
      `feedback_phase4_probe_bank_switch_limitation`). Run under the
      **banking-capable emulator** (`$(IZCPM_BANKING)`, which is the banking-modelling
      iz-cpm — Makefile `:20`), NOT the plain non-banking path.
- [x] **Establishing a cross-bank task** (the mechanism — verify against the live
      `ACTIVATE`): `ACTIVATE` seeds the new task's `t_current_bank` from the
      **operator's** `current_bank` at activation time (`multitasker.asm:280-285`).
      So the probe pattern is: ensure ≥1 extra bank is active (the default CL
      tail brings up 12 banks — `BANKS .` → 12; `test-repl-banking` confirms),
      `' BGWORD MYTASK` (carve the TCB), then `1 BANK!` → `MYTASK ACTIVATE` →
      `0 BANK!` so the **task** owns bank 1 while the **operator** is back in
      bank 0. The next `PAUSE` into `MYTASK` must re-page to bank 1, run, and the
      switch back to the operator must re-page to bank 0. (Confirm `BGWORD` is a
      word reachable from bank 1's mapping; for the emulator probe, a bank-0
      kernel word the task merely *runs while bank-1-mapped* exercises the
      re-page itself — the discriminating assertion is that the **re-page
      happened and state survived**, not that the body lives in bank 1.)
- [x] **Discriminating witness — the re-page actually fires.** The rigorous test
      is behavioral, like the 25.1 TAPE round-robin: a cross-bank task that
      reads/writes a witness which is **only correct if slot 2 was re-paged to
      its bank** across the yield, and a same-bank control that must pass with
      the re-page elided (proving the conditional skip is taken). At minimum
      assert: (a) `' PAUSE DROP` and the banking words resolve; (b) a cross-bank
      task advances a per-task data-stack witness across several operator
      `PAUSE`s with no corruption (`DEPTH`/value checks → `PASS:`); (c) the
      operator's own bank (`BANK@`) is **unchanged** after driving the switches
      (the re-page restored it — `BANK@ . = 0`); (d) interpreter healthy after
      (`1 2 3 + + . = 6` / `DEPTH 0=`). Runtime-computed tokens, not bare
      sentinels (the 23.2 column-anchoring / false-green lesson).
- [x] **Makefile target `test-repl-multitasker-bank`** modeled on
      `test-repl-banking-23-7` / `test-repl-multitasker-tasks`
      (`Makefile:328,:373`): `sed`-CRLF the probe, append `BYE`, pipe through
      `$(IZCPM_BANKING) $(IZCPM_DISKS) $(TARGET)`, wrap in the Story 24.3
      fail-loud `timeout` (a wedged ring or a bad re-page → loud FAIL, not a CI
      hang), verdicts via `tests/assert_verdicts.sh` (Story 24.4 helper —
      `--fail-line '^FAIL:'`; do NOT re-derive the grep/`\r` block). Add the
      `.PHONY` entry. **Single-feature target, NOT folded into plain
      `test-repl`** (matches the 25.1–25.4 convention). Keep every probe line
      **≤ 128 chars** incl. `\` annotations (`feedback_tib_size_inline_comments`).
- [x] **Straddle re-check.** This story grows the kernel by only ~+25–45 B (see
      envelope), the smallest Epic-25 bump — unlikely to push a late
      `banking_tests.fth` colon-body probe across `$8000`, but run
      `make test-straddle-regression` / `lint-banking-probes` (Story 24.3) to
      confirm (`feedback_banking_probe_straddle_halt`). If it did, fix the
      **probe** (interpret-level, printed witnesses), not the feature.
- [x] Full `make test` gate green; record the binary delta (`wc -c` after −
      before) in Dev Notes against the proposed envelope (Q3).

### S9 hardware smoke (post dev-pass — recipe in the close-out chat message)

- [x] On real CP/M 2.2 / MicroBeast (per the **STRONG**
      `feedback_post_hw_smoke_steps_at_review` commitment, post the exact recipe
      in the closing chat message, not only here). **UAT confirmed by project lead
      2026-07-01; capture `~/Downloads/beastty-20260701-063506.bin`.**
  - [x] **Cross-bank switch (AC1/AC4):** bring up banks (default CL tail → 12),
        `' LIGHTS BG` (or any background word), `1 BANK!` → `BG ACTIVATE` →
        `0 BANK!`, then confirm the background task makes progress at the live
        prompt while the operator keeps typing/evaluating — the switch re-pages
        cleanly with no visible lag (NFR-P6-1), and `BANK@` reads 0 for the
        operator throughout. **CONFIRMED on silicon:** capture shows `banks .`=12,
        `: lights begin ." ." PAUSE 0 UNTIL ;`, `' LIGHTS TASK`, `1 BANK!`,
        `activate` → the task emits a continuous `.` stream at the live prompt
        while the operator, back in bank 0, types `0 bank!` and evaluates
        `1 2 +` → `3 ok` (interpreter stays healthy/responsive under live
        cross-bank multitasking), then `BYE`.
  - [x] **`INCLUDE`-after-activation (AC4):** with a cross-bank task running,
        `INCLUDE` a small `.FTH` from disk and confirm the include parses and
        runs correctly — the operator-owned dictionary triple survived every
        re-page (the AC2 operator-only-compile lock holds across switches).
        (This is the regression the bring-up order was sequenced to protect —
        the Phase-4 "INCLUDE-after-BANK! mapping survives" silicon check,
        `project_banking_bios_pivot`, now under live multitasking.)
        **CONFIRMED on silicon 2026-07-01** (capture
        `~/Downloads/beastty-20260701-064041.bin`): after `' lights task` /
        `1 bank!` / `activate` / `0 bank!`, with the bank-1 task streaming `.`,
        the operator typed `include hello.fth` (chars interleaved in the live dot
        stream) → **`Hello!`** printed → ` ok` → `bye`. The include parsed and ran
        correctly while the cross-bank task was live — AC2 triple survived.

## Dev Notes

### Architecture provenance (read these first)

- **AD-P6-1** (per-task state model; the `{catch_top, current_bank, base}`
  subset; "global cells never written by a background path") —
  `architecture.md:245-274` + the Register-Contract / TCB / Banking pattern rules
  at `:494-525`. `current_bank` is *"the locked banking decision; restored value
  drives the `MBB_SET_PAGE` re-page"* (`:257-258`).
- **AD-P6-3 step 4** (the `PAUSE` switch sequence; *"if its `current_bank`
  differs, `MBB_SET_PAGE` to re-page (the only banking cost on a switch)"*) —
  `architecture.md:334-335`. This story **is** AD-P6-3 step 4 — every other step
  shipped in 25.1.
- **Banking Patterns** (`architecture.md:519-525`): *"`MBB_SET_PAGE`/`MBB_GET_PAGE`
  only — never direct MMU port writes"* and *"Re-page conditionally: only call
  `MBB_SET_PAGE` when the next task's `current_bank` ≠ the outgoing one (saves the
  BIOS call on same-bank switches; NFR-P6-1). The page call is the measured
  per-switch banking cost."* — this story's AC1 + AC3 verbatim.
- **AD-P6-2** (TCB layout; `t_current_bank` at `TCB_BANK=13`) —
  `architecture.md:284-297`; live EQUs `src/constants.asm:112-114`
  (`TCB_BANK EQU 13 ; per-task current_bank (2; re-paged in 25.5)`).
- The 5 Phase-6 locks + the "fixed-memory-switch-first" bring-up order live in
  `project_phase6_concurrency_direction`; the two load-bearing register/sp_base
  gotchas from 25.1 in `project_multitasker_pause_register_contract`; the
  MBB-not-MMU-port discipline in `project_div1_mmu_port_readback` and
  `project_banking_bios_pivot`.

### The whole kernel change is ~20 instructions at one seam

The scheduler already saves and restores `current_bank` as a cell (25.1) — the
per-task bank value has ridden every switch since the spine landed. The ONLY
missing piece is the MMU re-page, and the resume tail was deliberately written
with the seam pre-marked:

```
src/multitasker.asm:137-145  (sched_resume_current, step 4 — the edit site)
sched_resume_current:
        ; (4) Restore the next task's UserArea subset. NO MBB_SET_PAGE re-page in
        ;     this story — current_bank is copied as a cell only; the conditional
        ;     page call on a bank change is Story 25.5 (single-bank here).   <-- replace
        LD      DE, TCB_CATCH
        ADD     HL, DE                  ; HL -> next.t_catch_top
        RESTORE_UA_CELL UserArea.catch_top      ; -> t_current_bank
        RESTORE_UA_CELL UserArea.current_bank   ; -> t_base   <-- next bank now live
        RESTORE_UA_CELL UserArea.base           ; -> t_sp_base
```

Capture the outgoing bank from the live `(IY+UserArea.current_bank)` **before**
the `RESTORE_UA_CELL UserArea.current_bank` overwrites it (B is free); after the
subset+`sp_base` restore, compare and conditionally re-page (Task 1 sketch). The
re-page reuses the page-lookup head of `switch_live_bank_to_c`
(`banking.asm:402-406`) — `LD HL,ACTIVE_PAGES_BASE / ADD HL,BC / LD A,(HL) /
CALL mbb_set_slot2` — **without** the `triple_owner`/`bank_triple_swap` tail (the
compile-side machinery the operator-only-compile lock forbids on this path).

### Why "conditional" matters, and why both entry paths are correct

- **Conditional (NFR-P6-1).** A single-bank workload (the operator + bank-0
  tasks) must pay **zero** BIOS calls — every switch is same-bank, so the
  `CP B / JR Z` skips. Only a genuine cross-bank switch pays one `MBB_SET_PAGE`.
  An unconditional re-page would also be *correct* but would tax the common case;
  the AC requires the compare.
- **`sched_resume_current` has two callers, both correct with this logic.**
  (1) `PAUSE` itself (the normal yield). (2) The uncaught-THROW handler
  (`exception.asm:592-599`) sets `current_tcb = operator_tcb`, loads HL, and jumps
  here to hand control back to the operator after suspending a faulting bg task.
  In both, the live `(IY+UserArea.current_bank)` at entry is the **outgoing**
  (resp. **faulting**) task's bank, so the captured "from" value is right and the
  operator gets re-paged back to its bank for free on a fault. No special-casing.

### Register / TOS conventions (25.1 gotcha #1 applies — with the one exemption)

- BC = TOS, DE = IP, IX = return stack, IY = UserArea (never reassigned), SP =
  data stack (`project_tos_in_register`; `register-conventions.md` Hard Rule #1).
- **`PAUSE` is the single DE-swapping word** — it moves DE=IP through the TCB by
  design (saved at step 1, restored at step 5). The Task-1 re-page lands at step 4
  *between* those, where DE is mid-flight scratch; `mbb_set_slot2` preserves DE
  (`banking.asm:126,134`), so the restored IP is intact at `NEXT`. Do not
  introduce a DE clobber in the re-page.
- **25.1 gotcha #2 (`sp_base` is per-task):** untouched — the re-page sits after
  the `sp_base` restore (`:146-150`) and does not carve stacks.
- **IY never reassigned** — the bank is read IY-relative, never by swapping IY.

### Banking mechanism reference (the live code to mirror, not re-derive)

- `mbb_set_slot2` ( A = physical page → ) maps logical CPU page 2 (`$8000..$BFFF`,
  the portal window) to physical page A via `MBB_SET_PAGE` (0xFDDF); preserves
  BC/DE/HL/IX/IY (`banking.asm:124-135`). **This is the only paging primitive the
  re-page calls** — never a raw `OUT`.
- `ACTIVE_PAGES_BASE` + `active_pages[idx]` = the dense logical-bank-index →
  physical-page map (`banking.asm:22-25,:403`). `active_pages[0]` = the portal
  page (bank 0 / operator). `switch_live_bank_to_c` (`banking.asm:402-413`) is the
  full `BANK!` activation (page + `current_bank` + `triple_owner` + triple swap);
  the re-page reuses only its first four lines (`:403-406`).
- `current_bank.high` is invariantly 0 (index bounded < 29 = `BANK_TABLE_CAP`),
  asserted throughout banking.asm — the low-byte compare is exact.

### Test strategy — the cross-bank switch is the rigorous part

`PAUSE` re-paging is invisible to a single-bank probe (every switch skips), so the
discriminating test MUST establish a real cross-bank task and assert that state
survives the re-page. Run under `$(IZCPM_BANKING)` (banking-modelling iz-cpm); the
default CL tail brings up 12 banks. The behavioral witness (a cross-bank task
advancing a per-task data-stack value across operator `PAUSE`s, with the
operator's `BANK@` unchanged afterward) is the analog of the 25.1 TAPE round-robin
and the 25.4 SLEEP/WAKE accumulator tests — revert the re-page and a genuine
cross-bank read corrupts or the operator's bank drifts → FAIL, i.e. genuinely
discriminating. **Wall-clock "no visible lag" + `INCLUDE`-after-activation are
hardware-only (S9, NFR-P6-6/-14)** — the emulator asserts *structure* (the switch
happens, state survives, `BANK@` restored), hardware asserts *responsiveness*.
Reuse `tests/assert_verdicts.sh` + the 24.3 fail-loud `timeout`; ≤128-char lines;
reviews are adversarial by design (`feedback_adversarial_review`); the `CR` command
runs separately at story close (NOT an AC — PD-1).

### Binary-size envelope (sprint-planning carry-forward F5 — proposed here)

Per-component itemisation (B.2 — each component costed *independently* from its
own opcodes; **no "mirrors prior arm" shorthand**). The change is a single
inline block in `sched_resume_current`; no new word, no header.

| Component | Itemisation | Est. bytes |
|---|---|---|
| Capture outgoing bank (before subset restore) | `LD A,(IY+current_bank)` (3) + `LD B,A` (1) | +4 |
| Conditional compare | `LD A,(IY+current_bank)` (3) + `CP B` (1) + `JR Z,.same_bank` (2) | +6 |
| Re-page body (cross-bank arm) | `LD C,A` (1) + `LD B,0` (2) + `LD HL,ACTIVE_PAGES_BASE` (3) + `ADD HL,BC` (1) + `LD A,(HL)` (1) + `CALL mbb_set_slot2` (3) | +11 |
| Comment swap (placeholder → real) | 0 (comments) | 0 |
| **Subtotal (raw)** | | **~+21** |
| ×1.25 register-juggle/placement overshoot (capture-survives-restore juggling; `feedback_kernel_ldir_estimate_overshoot`) | +5 | +5 |
| **Total** | | **~+26 B** (range **+20..+45**) |

**Proposed Story-25.5 envelope: ~+26 B** (range **+20..+45**),
accept-with-rationale, no silent bloat (NFR-P6-10) — the **smallest Epic-25
story**, as expected for a one-seam insertion that reuses existing banking
primitives. Record the actual `wc -c` delta at dev-pass close (Q3). Well inside
the Phase-6 per-epic envelope (NFR-P6-11); a ~25 B bump is very unlikely to shift
a late banking colon-body probe across `$8000`, but Task 3's straddle re-check
confirms it rather than assumes.

### Hazards to document (not guard in v1)

- **A task whose `current_bank` names a bank that is no longer active** (the
  operator `-BANK`'d it, or it was never brought up) — `active_pages[idx]` is
  stale/garbage and the re-page maps slot 2 to a wrong/unmapped page. Same
  lifecycle class as the existing banked-MARKER / stale-handle hazards
  (`project_banked_marker_no_stub`, AD-P6-2 hazard). The operator-only-compile
  model means a task's bank is whatever the operator set at `ACTIVATE`; tearing
  that bank down underneath a live task is a documented don't-do, not guarded.
- **Cross-bank task body that itself calls `BANK!`** — a background task is not
  supposed to compile, but it *could* run a pre-compiled `BANK!`. The portal-window
  `-273` guard (`banking.asm:265-282`) still applies from the task's IP; and the
  per-task `current_bank` then diverges from what the operator expects on the
  next switch back. The supported model is: the operator owns banking; tasks run
  in the bank they were activated in. Note; don't guard.
- **`<# #>` pictured output across a cross-bank `PAUSE`** — HLD/pic_buf stay
  global (AD-P6-1 left them global for v1); this was already a documented
  don't-do and is unchanged. Cross-bank does not make it worse.

### Scope boundaries (explicitly deferred — do not implement here)

- ❌ Background-task exception isolation / the **SUSPENDED-producing** path →
  **Story 25.6** (25.5 only *benefits* from the resume-tail re-page when 25.6's
  handler hands control back to the operator).
- ❌ Keyboard break / `break_pending` / fn-6 / Ctrl-C → **Story 25.7**.
- ❌ Headline background-traffic-light demo → **Story 25.8**.
- ❌ Any change to the per-task subset definition `{catch_top, current_bank,
  base}` (AD-P6-1 frozen — adding/dropping a cell is an architecture change, not
  an implementation choice; `architecture.md:512-514`).
- ❌ Any compile-side change / letting a background task touch
  HERE/LATEST/wordlist/`triple_owner` (operator-only-compile lock, AC2) — re-page
  maps the MMU window **only**, never swaps the dictionary triple.
- ❌ Per-task search-order / STATE / TIB / SOURCE-ID (stay global, AD-P6-1).
- ❌ Configurable per-task stacks or named tasks (Vision, not MVP).

### Project Structure Notes

- **Edit:** `src/multitasker.asm` (replace the step-4 placeholder comment at
  `:138-140` with the conditional re-page block, inside `sched_resume_current`;
  the new instructions stay well below the module-end `ASSERT $ <=
  SLOT2_WINDOW_BASE` at `:297` — a ~25 B insertion). No new module, no new word,
  no header.
- **Read-only references:** `src/banking.asm` (`mbb_set_slot2:124-135`,
  `switch_live_bank_to_c:402-413` — the page-lookup head to mirror minus the
  triple swap, `ACTIVE_PAGES_BASE:403`), `src/exception.asm` (uncaught-THROW
  resume entry into `sched_resume_current:592-599`), `src/constants.asm`
  (`MBB_SET_PAGE:58`, `TCB_BANK:113`), `src/structures.asm` (TCB doc + per-task
  subset rationale `:79-125`), `src/multitasker.asm` (`PAUSE` save side `:100-114`,
  resume tail `:137-159`, `ACTIVATE` bank-inherit `:280-285`).
- **New test:** `tests/multitasker_bank_tests.fth` (model on
  `tests/multitasker_tests.fth` + the `banking_tests.fth` interpret-level idioms);
  `Makefile` new `test-repl-multitasker-bank` target + `.PHONY` entry (model on
  `test-repl-banking-23-7:373` / `test-repl-multitasker-tasks:328`).
- The module-end `ASSERT $ <= SLOT2_WINDOW_BASE` (`multitasker.asm:297`) fails the
  build if the insertion somehow pushes the scheduler across `$8000`
  (kernel-growth guard — ~25 B will not, but the assert is the backstop).
- **Comment discipline:** what + why-not-obvious in source; provenance stays in
  git/story/ADR/memory (`feedback_source_comment_discipline`). The re-page's
  "conditional, same-bank skips, no triple swap" rationale belongs in source; the
  Story-25.5 decision history stays here.

## Open Questions (for project lead — saved for the end, per workflow)

1. **Cross-bank probe rigor under the emulator.** The genuinely discriminating
   assertion is that slot 2 was re-paged to the task's bank across a yield. Under
   `$(IZCPM_BANKING)` the cleanest emulator-checkable witness is **(a)** a
   cross-bank task advancing a per-task data-stack value across operator `PAUSE`s
   + the operator's `BANK@` reading 0 afterward (proves the re-page restored the
   operator's bank), with a same-bank control that passes when the re-page is
   elided. A stronger witness — **(b)** a task that reads a byte at a
   bank-1-mapped address whose value differs from the bank-0 mapping of the same
   address — proves the *window contents* switched, but needs a known
   distinguishing byte in two banks (more probe scaffolding). **Recommendation:
   ship (a) as the emulator gate + lean on S9 for the true cross-bank-contents
   proof** (NFR-P6-14 puts wall-clock/real-bank behavior on hardware anyway).
   Confirm, or ask for (b) in-emulator.
2. **Overhead-measurement form (AC3/NFR-P6-1).** Document the per-switch cost as
   **(a)** a derived T-state count at 8 MHz for each arm (same-bank skip vs.
   cross-bank `MBB_SET_PAGE`), or **(b)** an observed S9 wall-clock figure, or
   both? **Recommendation: (a) derived T-states in Dev Notes** (cheap, exact,
   reproducible) **plus a one-line S9 "no visible lag" confirmation** — full
   profiling is overkill for a single conditional BIOS call. Confirm.
3. **Envelope (F5).** Confirm the proposed **~+26 B** Story-25.5 envelope (range
   **+20..+45**; one inline re-page block reusing `mbb_set_slot2` +
   `active_pages`, no new word). Record the actual `wc -c` delta at close.

## References

- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story-25.5] (lines 310–323)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-1] (per-task state model; `{catch_top,current_bank,base}` subset; "global cells never written by a background path", 245–274; pattern rules 494–525)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-3] (PAUSE switch sequence step 4 = the conditional re-page, 324–342)
- [Source: _bmad-output/planning-artifacts/architecture.md#Banking-Patterns] (MBB-only, re-page conditionally on bank-differ, page-call = measured cost, 519–525)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-2] (TCB layout, `t_current_bank`/`TCB_BANK`, 276–297)
- [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md] (FR24 operator-only-compile; NFR-P6-1 switch overhead; NFR-P6-6 S9; NFR-P6-13 BIOS-only; NFR-P6-14 hardware-verified timing)
- [Source: src/multitasker.asm] (`sched_resume_current` step-4 placeholder seam:137-145; PAUSE save side:100-114; ring walk:115-131; ACTIVATE bank-inherit:280-285; module-end $8000 ASSERT:297)
- [Source: src/banking.asm] (`mbb_set_slot2`:124-135; `switch_live_bank_to_c` page-lookup head to mirror:402-406, full body:402-413; `ACTIVE_PAGES_BASE`/`active_pages`:22-25,:403)
- [Source: src/exception.asm] (uncaught-THROW background-suspend → jump to `sched_resume_current`:561-599 — the second caller of the resume tail)
- [Source: src/constants.asm] (`MBB_SET_PAGE`/`MBB_GET_PAGE`:57-58; `TCB_BANK EQU 13 ; re-paged in 25.5`:113)
- [Source: src/structures.asm] (TCB doc + per-task subset rationale; `t_current_bank`:110; "current_bank … re-page is Story 25.5":82-83)
- [Source: _bmad-output/implementation-artifacts/25-4-task-suspend-resume-wake-sleep-tasks-introspection.md] (the prior story; probe/Makefile/timeout idioms; register gotchas; `>TASK`/`.TASKS` surface)
- [Source: _bmad-output/implementation-artifacts/25-1-pause-circular-ring-task-activate-single-bank-fixed-memory.md] (PAUSE/ring/TCB/sp_base contract; the two register/sp_base gotchas)
- Memory: `project_phase6_concurrency_direction`, `project_multitasker_pause_register_contract`,
  `project_div1_mmu_port_readback`, `project_banking_bios_pivot`, `project_tos_in_register`,
  `project_banked_marker_no_stub`, `feedback_banking_probe_straddle_halt`,
  `feedback_phase4_probe_bank_switch_limitation`, `feedback_kernel_ldir_estimate_overshoot`,
  `feedback_tib_size_inline_comments`, `feedback_source_comment_discipline`,
  `feedback_post_hw_smoke_steps_at_review`, `feedback_no_preexisting_discharge`,
  `feedback_adversarial_review`, `feedback_testing_rules`, `feedback_repl_tests_preferred`,
  `reference_microbeast_user_interrupt_timer`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (create-story workflow, 2026-06-30)

### Open-Question resolutions (project lead, 2026-07-01 — at story creation)

1. **Cross-bank probe rigor?** → **Witness + `BANK@`=0 (recommendation).** The
   emulator gate asserts *structure*: a cross-bank task advances a per-task
   data-stack witness across operator `PAUSE`s, and the operator's `BANK@` reads
   0 afterward (proving the re-page restored the operator's bank), with a
   same-bank control that passes when the re-page is elided. The heavier
   two-bank distinguishing-byte witness is **not** required in-emulator — true
   cross-bank *window contents* + wall-clock ride S9 (NFR-P6-14 puts real-bank
   behavior on hardware anyway). Task 3 witness set: `bank-task-advances`,
   `operator-bank-restored` (`BANK@ . = 0`), plus words-resolve + interpreter-alive.
2. **Overhead-measurement form (AC3/NFR-P6-1)?** → **Derived T-states + a one-line
   S9 confirmation (recommendation).** Dev Notes record the per-arm T-state count
   at 8 MHz — same-bank = `LD A / CP B / JR Z` compare-skip (no BIOS); cross-bank
   = `active_pages` lookup + `MBB_SET_PAGE` round-trip — plus a one-line S9 "no
   visible lag at the prompt" confirmation. Cheap, exact, reproducible; full
   profiling is overkill for one conditional BIOS call. Re-validate any reused
   `MBB_SET_PAGE` figure at draft time (PD-2 figure-drift).
3. **Envelope (F5)?** → **~+26 B confirmed** (range **+20..+45**; one inline
   re-page block reusing `mbb_set_slot2` + `active_pages`, no new word/header —
   the smallest Epic-25 story). Record the actual `wc -c` delta at dev-pass close.

### Debug Log References

- **Discrimination probing (throwaway, reverted).** Two deliberate-bug builds
  confirmed the emulator's discrimination boundary (OQ#1's "structure only"):
  (1) a `LD DE,0` after `mbb_set_slot2` did NOT fail the probe — step 5 reloads
  DE/IX/BC/SP wholesale from the TCB scratch bridge, so a transient DE clobber in
  step 4 is masked by design; (2) a `LD (IY+current_bank),7` at `.same_bank` did
  NOT fail `operator-bank-restored` either — QUIT re-asserts the operator's saved
  bank between REPL lines (Story 21.2), so `BANK@` reads 0 regardless. Both
  reverted. Conclusion: the emulator asserts the switch *happens and survives
  without wedge/corruption*; the *physical* slot-2 map + wall-clock ride S9
  (matches the project-lead OQ#1 resolution). `bank-task-advances` remains the
  discriminating witness — a re-page that wedges the BIOS call or corrupts
  IY/sp_base breaks the cross-bank round-robin or the liveness gate.

### Completion Notes List

- **Task 1 (AC1) — conditional re-page implemented.** Replaced the step-4
  placeholder comment in `sched_resume_current` (`src/multitasker.asm`) with: a
  pre-restore capture of the outgoing bank into `B`
  (`LD A,(IY+current_bank) / LD B,A`), then after the subset + `sp_base` restore,
  `LD A,(IY+current_bank) / CP B / JR Z,.same_bank` and, on a difference, the
  page-lookup head of `switch_live_bank_to_c` (`LD HL,ACTIVE_PAGES_BASE /
  ADD HL,BC / LD A,(HL) / CALL mbb_set_slot2`) — **without** the
  `triple_owner`/`bank_triple_swap` tail (AC2 operator-only-compile lock). `B` is
  free at entry and survives `RESTORE_UA_CELL`/`sp_base` (both touch only A/HL);
  step 5 reloads BC wholesale. `mbb_set_slot2` preserves DE=IP/BC/HL, so the
  trailing `NEXT` gets an intact IP (25.1 gotcha #1). Correct for both callers of
  the resume tail — `PAUSE` (outgoing = yielding task) and the uncaught-THROW
  handler (`exception.asm`, outgoing = faulting task → operator re-paged back for
  free). Module-header comment updated to match; module-end `$8000` ASSERT holds.
- **Task 2 (AC3) — per-switch overhead (derived T-states @ 8 MHz, OQ#2 form).**
  *Same-bank arm* (the common case): the always-run capture + compare, `JR Z`
  taken = `LD A,(IY+d)`19 + `LD B,A`4 + `LD A,(IY+d)`19 + `CP B`4 + `JR Z`12 =
  **58 T ≈ 7.25 µs**, **no BIOS call** — every same-bank switch skips the page
  call (NFR-P6-1). *Cross-bank arm*: the glue + `CALL mbb_set_slot2` = 109 T, plus
  `mbb_set_slot2`'s body (3×PUSH/POP + `CALL MBB_SET_PAGE`) = 101 T ⇒ **210 T ≈
  26.25 µs of antforth glue**, **plus one BIOS `MBB_SET_PAGE` round-trip**
  (firmware-resident, dominates; re-pages slot 2 + updates the BIOS page shadow).
  Honest framing (also captured as a source `what+why` comment at the seam):
  same-bank switches stay free; cross-bank switches pay one BIOS page call, by
  design (AD-P6-3 step 4). Wall-clock "no visible lag" confirmation rides S9.
- **Task 3 (AC1/AC4) — cross-bank switch probe.** New
  `tests/multitasker_bank_tests.fth` + `test-repl-multitasker-bank` Makefile
  target (`.PHONY` added; single-feature, NOT folded into plain `test-repl`,
  matching the 25.1–25.4 convention). Interpret-level orchestration (`' BG TASK` /
  `1 BANK!` / `ACTIVATE` / `0 BANK!` / `DRV`) dodges the `$8000` straddle-halt and
  the `BANK!` portal guard; runs under `$(IZCPM_BANKING)` with the Story 24.3
  fail-loud `timeout` and the Story 24.4 column-0 `assert_verdicts.sh` helper.
  6 witnesses PASS: `bank-words-resolve`, `bank-multi-active` (12 banks),
  `bank-task-advances` (cross-bank round-robin builds 12121, no corruption),
  `operator-bank-restored` (`BANK@`=0), `bank-same-control` (same-bank task
  round-robins — the compare-skip common case), `bank-alive` (runtime-42 token).
- **Binary delta:** 30,293 B → **30,314 B = +21 B** — inside the confirmed
  ~+26 B envelope (range +20..+45), the smallest Epic-25 story (one inline
  re-page block reusing `mbb_set_slot2` + `active_pages`, no new word/header).
- **Regression floor held (0 FAIL):** `make test` asm-thread PASS; `test-repl`
  1005 PASS/0 FAIL; timer 9/9, multitasker 5/5, key 5/5, delay 6/6, tasks 8/8,
  throw 5/5, banking 57/0, isolated-dot-banks 7/7, banking-23-7 4/4,
  file-sanity 1/1; `test-straddle-regression` 3/3 + `lint-banking-probes` clean
  (the ~+21 B bump did not push any banking colon-body probe across `$8000`).
  Pre-existing, unrelated: `make check-doc-sync` flags a planning-artifact drift
  (`architecture.md` "Starter Template Evaluation" absent from `prd.md`) — no
  file this story touched; out of scope.
- **S9 hardware smoke — cross-bank switch CONFIRMED on real MicroBeast**
  (project lead, 2026-07-01; capture `~/Downloads/beastty-20260701-063506.bin`).
  Session: boot (12 banks) → `: lights begin ." ." PAUSE 0 UNTIL ;` →
  `' LIGHTS TASK` → `1 BANK!` → `activate` → the bank-1 task streams `.` live
  while the operator (back in bank 0) types `0 bank!` and evaluates `1 2 +` →
  `3 ok` with no wedge, then `BYE`. Proves AC1/AC4 cross-bank live multitasking +
  operator interpreter healthy under it. **`INCLUDE`-after-activation ALSO
  CONFIRMED** in a second capture (`~/Downloads/beastty-20260701-064041.bin`,
  2026-07-01): with the bank-1 task streaming `.`, the operator ran
  `include hello.fth` (chars interleaved in the live dot stream) → `Hello!` →
  ` ok` → `bye` — the operator-owned dictionary triple survived every re-page
  (AC2 lock holds across switches). **Both S9 sub-checks pass; all AC1–AC4 met.**

### File List

- `src/multitasker.asm` (modified) — conditional `MBB_SET_PAGE` re-page in
  `sched_resume_current` step 4; module-header comment updated.
- `tests/multitasker_bank_tests.fth` (new) — cross-bank task-switch probe.
- `Makefile` (modified) — `test-repl-multitasker-bank` target + `.PHONY` entry.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) —
  `25-5-per-bank-task-switching`: ready-for-dev → in-progress → review.
- `_bmad-output/implementation-artifacts/25-5-per-bank-task-switching.md`
  (modified) — task checkboxes, Dev Agent Record, Change Log, Status.

## Change Log

| Date | Change |
|---|---|
| 2026-07-01 | **S9 hardware UAT — BOTH sub-checks CONFIRMED** on real MicroBeast by project lead. (1) Cross-bank switch (`~/Downloads/beastty-20260701-063506.bin`): bank-1 `LIGHTS` task streams live while the bank-0 operator types `0 bank!` and evaluates `1 2 +` → `3 ok`, no wedge. (2) `INCLUDE`-after-activation (`~/Downloads/beastty-20260701-064041.bin`): with the task streaming, `include hello.fth` → `Hello!` → ` ok` (operator-owned triple survived the re-pages, AC2). All AC1–AC4 met; all task boxes checked. |
| 2026-07-01 | **Dev-pass complete (status → review).** Implemented the conditional `MBB_SET_PAGE` re-page in `sched_resume_current` step 4 (`src/multitasker.asm`): capture outgoing bank in `B` before the subset restore, then `CP` the restored next bank and re-page slot 2 via `mbb_set_slot2` only on a difference — no triple swap (AC2). New cross-bank probe `tests/multitasker_bank_tests.fth` + `test-repl-multitasker-bank` target (6/6 PASS under `$(IZCPM_BANKING)`). Overhead (AC3): same-bank +58 T (~7.25 µs, no BIOS); cross-bank +210 T glue + one BIOS `MBB_SET_PAGE`. Binary +21 B (30,293 → 30,314), inside the +20..+45 envelope. Full regression floor held 0-FAIL; straddle 3/3 + lint clean. S9 hardware smoke deferred to silicon. |
| 2026-07-01 | All 3 open questions resolved by project lead at story creation (all recommended): probe rigor = witness + `BANK@`=0 emulator gate (structure), S9 for true cross-bank contents/wall-clock; overhead form = derived per-arm T-states in Dev Notes + one-line S9 "no visible lag"; ~+26 B envelope confirmed (range +20..+45). Resolutions pinned in Dev Agent Record. |
| 2026-06-30 | Story 25.5 drafted (create-story): conditional `MBB_SET_PAGE` re-page in `PAUSE`'s `sched_resume_current` step-4 seam — restore next task's `current_bank` then re-page slot 2 via `mbb_set_slot2` iff the bank differs from the outgoing one (same-bank skips = zero BIOS cost, NFR-P6-1); reuses the page-lookup head of `switch_live_bank_to_c` WITHOUT the triple swap (operator-only-compile lock, AC2). Correct for both `PAUSE` and the exception-handler resume-tail callers. New cross-bank probe `tests/multitasker_bank_tests.fth` + `test-repl-multitasker-bank` target (interpret-level, `$(IZCPM_BANKING)`, fail-loud timeout). Per-component itemisation → ~+26 B envelope (range +20..+45, smallest Epic-25 story). 3 open questions (probe rigor / overhead-measurement form / envelope). Status → ready-for-dev. |
