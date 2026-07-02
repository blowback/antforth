# Story 25.3: Yielding, per-task DELAY

Status: done

> **Epic 25 bring-up step 3 — make `DELAY` cooperative.** Story 25.1 landed the
> scheduler spine (`PAUSE`/ring/TCB/`TASK`/`ACTIVATE`); Story 25.2 made the REPL
> *yield while waiting for input* (KEY-hook → live prompt). This story closes the
> last busy-wait that would freeze the ring: `DELAY`/`MS`. It is the
> "timer/`DELAY`" milestone of the architecture's fixed-memory-switch-first
> bring-up order (`architecture.md:443-444`). **Story 24.2 already pre-engineered
> the seam** — `(DELAY)` is factored to a single site precisely so this story
> drops *one thread cell* (`DW w_PAUSE_cf`) in front of the `TICKS` read
> (`timer.asm:121-132`). No banking re-page, no `.TASKS`, no exception isolation —
> just the yield seam. Later stories ride on: `.TASKS`/`WAKE`/`SLEEP` (25.4),
> per-bank switch (25.5), exception isolation (25.6), keyboard break (25.7),
> headline demo (25.8 — which depends on a non-freezing background `DELAY`).

## Story

As a task author,
I want `DELAY` to yield instead of busy-wait,
so that a delaying task does not freeze the REPL or other tasks.

## Acceptance Criteria

(Verbatim from `epics-phase6-epics-24-26.md` Story 25.3, lines 286–293; BDD form.)

1. **AC1 — the wait loop yields (FR14).**
   **Given** Story 24.2's target-on-stack `DELAY` and a working `PAUSE` (Story
   25.1),
   **When** a task runs `n DELAY`,
   **Then** the wait loop calls `PAUSE` each iteration, so the REPL and other
   tasks keep running during the wait (FR14).

2. **AC2 — concurrent delays are independent (FR15).**
   Concurrent delays in different tasks are independent — each target rides its
   own task's data stack, no shared countdown cell (FR15).

3. **AC3 — accuracy preserved under multitask load (NFR-P6-2).**
   Accuracy is preserved (`60 DELAY` ≈ 60 s ±1 s, NFR-P6-2) under nominal
   multitask load.

4. **AC4 — probe + S9 + binary delta (NFR-P6-2/-14/-16/-17).**
   A probe shows two tasks with different `DELAY`s both completing on time;
   `4 DELAY` visibly does not freeze the prompt (hardware S9); binary delta
   recorded.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev
      Notes. **Do not inherit the figure below** — re-`wc -c` from the actual
      current build artifact (B.3 / Lesson 13.5-F). At story-drafting time
      (2026-06-30) the committed tree measured **30,038 B**; the dev-pass baseline
      may differ if commits have landed since.
- [x] Capture current `make test-repl` baseline pass count (the 0-FAIL floor,
      NFR-P6-5) — including `test-repl-timer` (9/9), `test-repl-multitasker`
      (5/5), and `test-repl-multitasker-key` (5/5).

### Task 1 — Drop the `PAUSE` seam into `(DELAY)` (AC1, AC2) — `src/timer.asm`

- [x] Insert **`DW w_PAUSE_cf`** as the first thread cell of the `(DELAY)` loop,
      immediately **before** `DW w_TICKS_cf` at `timer.asm:138` (the `.pd_begin`
      label). This is the exact edit the Story-24.2 seam comment prescribes
      (`timer.asm:126-127`). Nothing else in the loop math changes — the target
      double stays on the caller's data stack as the loop carry.
- [x] The loop becomes `BEGIN PAUSE TICKS 2OVER D< 0= UNTIL 2DROP` — **PAUSE
      first**, matching the AD-P6-5 pseudocode `BEGIN PAUSE TICKS 2-target D>=
      UNTIL` (`architecture.md:375-380`). PAUSE-before-test means `n DELAY` yields
      at least once even when the target is already reached (harmless: a length-1
      ring walks to self).
- [x] **`DELAY` and `MS` both become yielding for free** — they share the single
      `(DELAY)` site (`timer.asm:159, 185`). Confirm `MS` is intentionally
      yielding too (Open Question Q1) — a long `MS` should not freeze the ring
      either; this is correct and consistent. No edit to `DELAY`/`MS` bodies.

### Task 2 — Update the seam comment to done-state (AC1) — `src/timer.asm`

- [x] Replace the **`>>> Story-25.3 yielding form: insert ... <<<`** TODO at
      `timer.asm:126-127` with a done-state rationale: *why* `PAUSE` is the first
      cell (cooperative yield so a delaying task does not starve the ring; the
      target-on-stack carry makes the delay per-task with no shared countdown
      cell). Keep the existing "single factored site" / "signed D< is safe for
      ~388 days" rationale (`:122-132`). Comment discipline: what + why-not-obvious
      in source; provenance (story/CR/date) stays in git/story/ADR/memory
      (`feedback_source_comment_discipline`).

### Task 3 — Verify the forward reference resolves + single-task identity (AC1) — build

- [x] Build (`make`) and confirm `DW w_PAUSE_cf` **resolves**: `w_PAUSE_cf` lives
      in `src/multitasker.asm`, which is `INCLUDE`d *after* `src/timer.asm`
      (`antforth.asm:750-751`). sjasmplus is multi-pass and `timer.asm` already
      forward-references cross-module cf labels (`w_TWO_OVER_cf`/`w_D_LESS_cf` in
      `double.asm`, `:139-140`), so the ref links in pass 2 — but confirm the
      build is clean (no undefined-symbol error). See Dev Notes "Forward-reference
      safety".
- [x] **Single-task identity (FR9 / NFR-P6-12):** with a length-1 ring `PAUSE`
      walks to self (no-op), so single-threaded `DELAY`/`MS` still busy-wait on
      `TICKS` exactly as Story 24.2 — `0 DELAY` / `0 MS` still return immediately
      and conserve `DEPTH`. The `make test-repl` floor (incl. `test-repl-timer`
      9/9) must still pass 0 FAIL. Record the execution-shape note (one extra
      walk-to-self PAUSE per loop pass) — result-identical, which is what
      NFR-P6-12 requires.

### Task 4 — Probe + Makefile wiring (AC1, AC4) — `tests/multitasker_tests.fth` (or new), `Makefile`

- [x] Add a yielding-`DELAY` probe to the multitasker suite (extend
      `tests/multitasker_tests.fth` or add `test-repl-multitasker-delay`). Assert
      **structure** (NFR-P6-16) — the emulator cannot assert wall-clock timing
      (see the EMULATOR-vs-HARDWARE split below, the decisive constraint). Minimal
      witness set:
  - [x] `DELAY` / `MS` / `(DELAY)` resolve; `0 DELAY` / `0 MS` return and conserve
        `DEPTH` (the 24.2 degenerate-case regression, now via the yielding loop).
  - [x] **FR14 yield witness:** a background counter task advances **across an
        operator `0 DELAY`** (the single PAUSE in `0 DELAY`'s loop yields to it —
        counter advanced by ≥1), proving `(DELAY)` contains a live `PAUSE`.
  - [x] **FR14/FR15 non-monopoly witness:** with one background task parked in a
        **nonzero** `DELAY` (forever-pending under emulation because `TICKS` is
        frozen — see split) and a *second* free-running background counter, the
        operator's commands still complete and the second counter still advances —
        i.e. a task mid-`DELAY` yields rather than monopolizing the CPU. The
        operator drives the probe to `BYE`; the parked-DELAY task is fine because
        it yields on every loop pass.
  - [x] Interpreter healthy after (`1 2 3 + + .` = `6`); stack clean.
- [x] **Reuse** `tests/assert_verdicts.sh --mode anchored` (Story 24.4) — do NOT
      re-derive the grep/`\r`/`xxd` block. Wrap the emulator pipe in the Story
      24.3 fail-loud `timeout` so any wedge (e.g. a non-yielding `DELAY` that
      monopolizes the ring) is a loud FAIL, not a CI hang. Keep every probe line
      **≤ 128 chars** incl. `\` annotations (`feedback_tib_size_inline_comments`).
- [x] Run `make lint-banking-probes` / the straddle guard (Story 24.3). This story
      grows the kernel by only **~2 B** (one thread cell), so a banking-probe
      `$8000` straddle push is extremely unlikely — but re-check that late
      `banking_tests.fth` colon-body probes did not cross `$8000`
      (`feedback_banking_probe_straddle_halt`). If they did, fix the **probe**, not
      the feature.
- [x] Full `make test` gate green; record the binary delta (`wc -c` after −
      before) in Dev Notes against the proposed envelope (Q3).

### Task 5 — Document the timing split + ISR-not-installed hang (AC3, AC4) — source/`docs/`

- [x] State the **EMULATOR-vs-HARDWARE timing split** in the probe header (mirror
      the existing `timer_tests.fth:8-22` block): iz-cpm-banking does NOT model the
      0xFDC7 user interrupt, so `tick_count` never advances; therefore a **nonzero**
      `DELAY`/`MS` never *completes* under emulation. The emulator asserts the
      yield *structure* only; wall-clock accuracy (`60 DELAY` ≈ 60 s ±1 s) and
      "two different `DELAY`s both complete on time" are **hardware S9** (NFR-P6-2
      / NFR-P6-14). State this split honestly — no silent cap
      (`feedback_no_preexisting_discharge`).
- [x] Carry forward the standing **ISR-not-installed hang gotcha**
      (`reference_microbeast_user_interrupt_timer`): a nonzero `DELAY`/`MS` wedges
      forever (now yielding, but never completing) if the 64 Hz tick ISR is not
      installed (`TIMER-OFF`, or a foreign ISR like TRAFFIC's `START-CLOCK` evicted
      the slot) — recover with `TIMER-ON`. The yield seam does not change this; it
      only stops the *delaying task* from monopolizing the CPU while it waits.

### S9 hardware smoke (post dev-pass — recipe in the close-out chat message)

- [ ] On real CP/M 2.2 / MicroBeast (per the **STRONG**
      `feedback_post_hw_smoke_steps_at_review` commitment, post the exact recipe in
      the closing chat message, not only here):
  - [ ] **Accuracy (AC3, NFR-P6-2):** `TIMER-ON` (if not already), then stopwatch
        `60 DELAY` ≈ 60 s ±1 s under nominal load. (Same gate as 24.2, re-confirmed
        through the yielding loop.) — *Partial (Ant, 2026-06-30): a foreground
        `60 DELAY` ran and completed in roughly the right time, but was not
        explicitly stopwatched; the ±1 s accuracy assertion is the same gate 24.2
        already passed on silicon and rides the unchanged `TICKS` math.*
  - [x] **Non-freezing prompt (AC4 headline) — PASS (Ant, 2026-06-30):** with
        background `DELAY` tasks active, the operator typed at the live prompt and
        it echoed/evaluated with no perceptible lag (input processed live;
        keystrokes typed during a foreground `60 DELAY` also queued in the firmware
        keyboard type-ahead buffer and drained when the delay returned).
  - [x] **Independence (AC2/AC4, FR15) — PASS (Ant, 2026-06-30):** two background
        tasks with **different** delays (`delay5` = `5 DELAY`, `delay7` = `7 DELAY`)
        both completed on their own tempo → `five!seven!` printed; each target rode
        its own task's data stack. The headline 25.8 demo works on silicon.

## Dev Notes

### Architecture provenance (read these first)

- **AD-P6-5** (Timer/ISR, 32-bit `TICKS`, *per-task `DELAY`*) —
  `_bmad-output/planning-artifacts/architecture.md:363-386`. The yielding form is
  specified there: `DELAY` computes `target = TICKS + u*64` as a **double** on the
  task's own data stack, then `BEGIN PAUSE TICKS 2-target D>= UNTIL` — no shared
  countdown cell, so concurrent delays never interfere (FR14/FR15).
- **AD-P6-3** (`PAUSE` = the yield target; switches only at a `NEXT` boundary) —
  `architecture.md:324-342`; bring-up order `:443-444`; `PAUSE` is called by
  AD-P6-5 (`DELAY`) and AD-P6-6 (I/O) `:452`.
- The 5 Phase-6 locks + bring-up order live in
  `project_phase6_concurrency_direction`; the two load-bearing register/stack-base
  gotchas from 25.1 live in `project_multitasker_pause_register_contract`; the
  timer/ISR + ISR-not-installed-hang facts live in
  `reference_microbeast_user_interrupt_timer`.

### The whole story is one thread cell (the seam was pre-built in 24.2)

Story 24.2 deliberately factored the busy-wait into a single `(DELAY)` helper
(`timer.asm:121-145`) *for this story*. The current loop is:

```
.pd_begin:
        DW      w_TICKS_cf              ; ( target  now )
        DW      w_TWO_OVER_cf           ; ( target  now  target )
        DW      w_D_LESS_cf             ; ( target  flag=now<target )  signed D<
        DW      w_ZERO_EQUALS_cf        ; ( target  flag'=now>=target )
        DW      w_QBRANCH_cf
        DW      .pd_begin - $           ; UNTIL: loop back while now<target
        DW      w_TWO_DROP_cf           ; ( )  drop the spent target double
        DW      EXIT_CODE
```

The edit is to insert **one cell** so the loop body becomes:

```
.pd_begin:
        DW      w_PAUSE_cf              ; <-- Story 25.3: cooperative yield each pass
        DW      w_TICKS_cf              ; ( target  now )
        DW      w_TWO_OVER_cf
        ...
```

`DELAY` (`:151-160`) and `MS` (`:170-186`) both call `(DELAY)`, so both become
yielding with no further edit. The target double is held on the *caller's* data
stack as the loop carry; `PAUSE` saves/restores `SP` per task (Story 25.1), so
the target survives the switch and rides the delaying task's own stack — that is
exactly FR15 (no shared mutable countdown cell). The seam comment at
`timer.asm:128-130` already documents this ("no shared mutable countdown cell, so
concurrent per-task delays never interfere").

### Why PAUSE-first (not PAUSE-last) is correct

The loop is a `BEGIN ... UNTIL` (test at the bottom). Putting `PAUSE` at the top
(`BEGIN PAUSE TICKS ... UNTIL`) means: yield, *then* check whether the target is
reached. This matches the AD-P6-5 pseudocode (`architecture.md:377`). The only
observable consequence vs a hypothetical PAUSE-last is that an *already-satisfied*
`DELAY` (e.g. `0 DELAY`, or a target already passed) still executes one `PAUSE`
before exiting. In a length-1 ring that is a walk-to-self no-op; with other tasks
present it yields one slice — harmless and arguably desirable (a `0 DELAY` becomes
a one-shot "yield now"). It does **not** change the timing of a real `n DELAY`
(the first `TICKS` read happens immediately after the first yield).

### Forward-reference safety (`w_PAUSE_cf` resolves)

`w_PAUSE_cf` is defined in `src/multitasker.asm:84`, which `antforth.asm` includes
at `:751` — *after* `timer.asm` at `:750`. This is a forward reference at the point
`timer.asm` is assembled. It resolves because (a) sjasmplus is multi-pass and
resolves all global labels in a later pass, and (b) `timer.asm` *already* forward-
references cross-module cf labels — `w_TWO_OVER_cf`, `w_D_LESS_cf` (defined in
`double.asm`), `w_U_M_STAR_cf`, `w_QBRANCH_cf` — and those link today. So
`DW w_PAUSE_cf` is the same class of reference and will link. Task 3 still
*verifies* the clean build (no undefined-symbol error) rather than assuming.

### Register / TOS conventions (unchanged — PAUSE owns the switch)

- BC = TOS, DE = IP, IX = return stack, IY = UserArea (never reassigned), SP =
  data stack (`project_tos_in_register`; `register-conventions.md` Hard Rule #1).
- **25.1 gotcha #1 (preserve DE=IP):** does NOT apply here — `PAUSE` is the *one*
  word exempt from the preserve-DE rule (swapping DE through the TCB is its job),
  and this story adds no new CODE word. `(DELAY)` is a DEFWORD thread; the cells
  it threads (`PAUSE`, `TICKS`, `2OVER`, …) each already honor the contract.
- **25.1 gotcha #2 (`sp_base` is per-task):** already handled — `PAUSE` swaps the
  global `sp_base` to the running task's `t_sp_base` (`multitasker.asm:140-144`),
  so a background task delaying on its own `ps_area` has correct depth guards. The
  target double on that task's stack is preserved across the switch.
- No `BDOS_SAVE`/`BDOS_RESTORE` involved — `(DELAY)` makes no BDOS call.
  (`project_multitasker_pause_register_contract`.)

### EMULATOR vs HARDWARE split (the decisive testing constraint)

iz-cpm-banking does **not** model the MicroBeast 0xFDC7 user interrupt, so
`tick_count` never advances under emulation (verified at the 24.1/24.2 dev-pass:
two `TICKS` reads across a busy-wait both read `0 0`). Consequences for 25.3:

- A **nonzero** `DELAY`/`MS` never *completes* under emulation (target never
  reached) — so wall-clock accuracy (`60 DELAY` ≈ 60 s, AC3/NFR-P6-2) and "two
  different `DELAY`s both complete on time" (AC4) are **hardware S9 only**
  (NFR-P6-14). This is the same split Story 24.2 documented (`timer_tests.fth:17-22`).
- **What the emulator CAN now assert that 24.2 could not:** the *yield structure*.
  A background counter advancing across an operator `0 DELAY` proves the PAUSE is
  live in the loop (FR14); a task parked in a nonzero `DELAY` not stopping a second
  counter / the operator proves a delaying task yields rather than monopolizing
  (FR14/FR15-flavored). These run to completion because the operator drives the
  probe to `BYE` and every parked task yields on each loop pass.
- The Story 24.3 fail-loud `timeout` is the safety net: if the seam were wrong and
  a `DELAY` busy-waited without yielding, the probe would wedge → loud FAIL, not a
  silent hang.

### ISR-not-installed hang (standing gotcha, carried forward)

A nonzero `DELAY`/`MS` waits for `TICKS` to reach a target; if the 64 Hz tick ISR
is not installed, `TICKS` is frozen and the wait never ends. The yield seam means
the *delaying task* no longer monopolizes the CPU (other tasks + the REPL run),
but the delaying task itself still never completes. Causes: `TIMER-OFF`; or a
foreign ISR (e.g. TRAFFIC.FTH's `START-CLOCK`) evicted the slot; or, on the
emulator, the slot is never fired at all. Recover with `TIMER-ON`
(`reference_microbeast_user_interrupt_timer`). Not a regression — same as 24.2;
document it.

### Binary-size envelope (sprint-planning carry-forward F5 — proposed here)

This is the cheapest Epic-25 story: the seam was pre-factored in 24.2, so the
implementation is a **single inserted thread cell**. Per-component itemisation
(B.2 — no "mirrors prior arm"; each component costed independently):

| Component | Est. bytes |
|---|---|
| Insert `DW w_PAUSE_cf` thread cell in `(DELAY)` loop | +2 |
| Seam-comment update (TODO → done-state rationale) | 0 (comments) |
| `DELAY` / `MS` bodies (unchanged — share `(DELAY)`) | 0 |
| **Total** | **+2 B** |

No ×1.25 register-juggle overshoot multiplier applies — there is no register
juggle, no scratch cell, no LDIR; it is one literal `DW` cell. **Proposed
Story-25.3 envelope: ~+2 B**, accept-with-rationale, no silent bloat (NFR-P6-10).
Record the actual `wc -c` delta at dev-pass close (Q3).

### Testing standards (S2 / NFR-P6-16/-17 + the 24.3/24.4 interludes)

- REPL-piped Forth only; concurrency tested through the threading model
  (`feedback_testing_rules`, `feedback_repl_tests_preferred`). No raw-BDOS hacks.
- Emulator asserts *structure* (yield witnessed via a counter advancing); the
  *wall-clock* asserts are hardware S9 (NFR-P6-14). State the split, no silent cap
  (`feedback_no_preexisting_discharge`).
- Use `tests/assert_verdicts.sh --mode anchored` (24.4) + the 24.3 fail-loud
  `timeout`; ≤128-char probe lines (`feedback_tib_size_inline_comments`).
- Reviews are adversarial by design (`feedback_adversarial_review`); the `CR`
  command runs separately at story close (NOT an AC — PD-1).

### Hazards to document (not guard in v1)

- A task parked in a nonzero `DELAY` with the ISR not installed never completes
  (above) — documented, not guarded.
- `DELAY` accuracy *degrades* under heavy multitask load if other tasks consume
  long slices between yields (each `PAUSE` round-trip adds latency before the next
  `TICKS` check). NFR-P6-2's "±1 s under *nominal* load" is the contract; a
  pathological always-busy peer task can stretch a `DELAY`. State the cooperative-
  scheduling reality honestly; it is inherent to cooperative multitasking, not a
  bug.

### Scope boundaries (explicitly deferred — do not implement here)

- ❌ `.TASKS` / `WAKE` / `SLEEP` introspection → **Story 25.4**.
- ❌ Per-bank re-page on switch (`MBB_SET_PAGE`) → **Story 25.5** (`PAUSE` still
  saves/restores `current_bank` as a cell only).
- ❌ Background-task exception isolation → **Story 25.6**.
- ❌ Keyboard break / `break_pending` / fn-6 / Ctrl-C → **Story 25.7**.
- ❌ Headline background-traffic-light demo → **Story 25.8** (which *consumes* this
  non-freezing `DELAY`).
- ❌ Any change to `TICKS` / the ISR / `TIMER-ON`/`TIMER-OFF` (Epic 24, frozen).
- ❌ Any change to `PAUSE` itself (Story 25.1, frozen — this story only *calls* it).

### Project Structure Notes

- **Edit:** `src/timer.asm` (one `DW w_PAUSE_cf` cell in `(DELAY)` + seam-comment
  update), `Makefile` (probe recipe via the 24.4 helper + 24.3 timeout — if a new
  target is added), `tests/multitasker_tests.fth` (or new
  `tests/multitasker_delay_tests.fth`) for the yield probe.
- **Read-only references:** `src/multitasker.asm` (`PAUSE` = the yield target,
  `w_PAUSE_cf:84`; do not modify), `src/antforth.asm` (INCLUDE order `:750-751`),
  `tests/timer_tests.fth` (the 24.2 DELAY/MS degenerate-case probe + the
  emulator-vs-hardware split header to mirror).
- No new module, no directory reorganization; flat `src/*.asm` preserved.
- **Comment discipline:** what + why-not-obvious in source; provenance stays in
  git/story/ADR/memory (`feedback_source_comment_discipline`).

## Open Questions (for project lead — saved for the end, per workflow)

1. **`MS` yields too.** `MS` shares the single `(DELAY)` site, so inserting the
   `PAUSE` cell makes `MS` yielding as well as `DELAY`. **Recommendation: keep it
   — yes, `MS` should yield.** A long `MS` should not freeze the ring any more than
   a long `DELAY`; it is correct and consistent, and `MS` is already a coarse
   15.625 ms-granularity convenience (no atomicity contract to break). Confirm.
2. **Emulator probe scope.** The emulator can assert only the yield *structure*
   (a counter advances across a yield; a parked-`DELAY` task does not monopolize),
   not wall-clock timing — accuracy (`60 DELAY` ≈ 60 s), "two `DELAY`s both
   complete on time", and "`4 DELAY` doesn't freeze the prompt" are **hardware
   S9**. **Recommendation: accept this split** (it matches the 24.2 emulator-can't-
   time precedent and NFR-P6-14). Confirm.
3. **Envelope (F5).** Confirm the proposed **~+2 B** Story-25.3 envelope (one
   thread cell; comment edits 0 B). Record the actual `wc -c` delta at close.

### References

- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story-25.3] (lines 280–293)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-5] (Timer/ISR + per-task DELAY, 363–386; yielding pseudocode 375–380)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-3] (PAUSE = yield target, 324–342; bring-up order 443–444; PAUSE called by DELAY 452)
- [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md] (FR14, FR15, NFR-P6-2/-14/-16/-17)
- [Source: src/timer.asm] (`(DELAY)` factored seam:121–145; seam TODO to replace:126–127; `DELAY`:151–160; `MS`:170–186; emulator-vs-hardware split header pattern:8–22)
- [Source: src/multitasker.asm] (`PAUSE` = the yield target, `w_PAUSE_cf`:82–84; `t_sp_base` swap:140–144 — already handles per-task depth)
- [Source: src/antforth.asm] (INCLUDE order: banking:749, timer:750, multitasker:751 — the forward-ref ordering)
- [Source: src/double.asm] (`w_TWO_OVER`:139, `w_D_LESS`:399, `w_U_M_STAR`:483 — the cross-module forward-ref precedent that links today)
- [Source: tests/timer_tests.fth] (24.2 DELAY/MS degenerate-case probe + the emulator-vs-hardware split to mirror)
- [Source: _bmad-output/implementation-artifacts/25-1-pause-circular-ring-task-activate-single-bank-fixed-memory.md] (PAUSE/ring/TCB this story rides; the two register/sp_base gotchas)
- [Source: _bmad-output/implementation-artifacts/25-2-key-hooked-repl-multitasking-input-only-yield.md] (the prior yield seam; the EOF-wait + timeout probe idioms to reuse)
- [Source: _bmad-output/implementation-artifacts/24-3-standing-8000-straddle-lint.md] / [24-4-shared-verdict-assert-helper.md] (the timeout + verdict helper to reuse)
- Memory: `project_phase6_concurrency_direction`, `project_multitasker_pause_register_contract`,
  `reference_microbeast_user_interrupt_timer`, `project_double_producer_push_bc`,
  `project_tos_in_register`, `feedback_kernel_ldir_estimate_overshoot`,
  `feedback_banking_probe_straddle_halt`, `feedback_tib_size_inline_comments`,
  `feedback_source_comment_discipline`, `feedback_post_hw_smoke_steps_at_review`,
  `feedback_no_preexisting_discharge`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (create-story workflow, 2026-06-30)

### Open-Question resolutions (project lead, 2026-06-30 — at story creation)

1. **`MS` yields too?** → **Yes, keep it.** `MS` shares the single `(DELAY)` site,
   so it becomes yielding along with `DELAY` — correct and consistent (a long `MS`
   should not freeze the ring; `MS` is a coarse 15.625 ms convenience with no
   atomicity contract to break). No special-casing.
2. **Emulator probe scope = structure-only?** → **Accepted.** The emulator asserts
   the yield *structure* (counter advances across a yield; a parked-`DELAY` task
   does not monopolize the ring); wall-clock accuracy (`60 DELAY` ≈ 60 s), "two
   `DELAY`s both complete on time", and "`4 DELAY` doesn't freeze the prompt" are
   **hardware S9** (matches the 24.2 emulator-can't-time precedent / NFR-P6-14).
3. **Envelope (F5)?** → **~+2 B confirmed** (one `DW w_PAUSE_cf` thread cell;
   comment edits 0 B). Record the actual `wc -c` delta at dev-pass close.

### Debug Log References

- Clean build after the seam insert: `make` OK, no undefined-symbol error — the
  forward reference `DW w_PAUSE_cf` (defined in `multitasker.asm`, INCLUDE'd at
  `antforth.asm:751`, after `timer.asm:750`) links in sjasmplus pass 2 exactly as
  the existing cross-module cf refs (`w_TWO_OVER_cf`/`w_D_LESS_cf`) do.
- Binary: **30,038 B → 30,040 B = +2 B** (one `DW` thread cell), matching the
  proposed envelope (Q3) to the byte; comment edits are 0 B.

### Completion Notes List

- **The whole implementation is one thread cell.** Inserted `DW w_PAUSE_cf` as the
  first cell of the `(DELAY)` loop at `.pd_begin` (`src/timer.asm`), so the loop is
  now `BEGIN PAUSE TICKS 2OVER D< 0= UNTIL 2DROP` (PAUSE-first, per AD-P6-5). The
  target double stays on the caller's data stack as the loop carry — no shared
  countdown cell — so concurrent per-task delays never interfere (FR15). `DELAY`
  and `MS` share the single `(DELAY)` site, so both became yielding with no edit to
  their bodies (Q1: `MS` yields too, confirmed/kept).
- **Seam comment rewritten to done-state** (`src/timer.asm`): replaced the
  `>>> Story-25.3 … <<<` TODO with the why (cooperative yield so a delaying task
  does not starve the ring; target-on-stack carry = per-task, no shared cell). Kept
  the signed-`D<`-safe-for-~388-days rationale. Provenance stays out of source
  (`feedback_source_comment_discipline`).
- **Single-task identity preserved (FR9 / NFR-P6-12):** length-1 ring → PAUSE walks
  to self (no-op); `test-repl-timer` floor still **9/9** (incl. `0 DELAY`/`0 MS`
  return stack-clean through the yielding loop). Execution-shape note: one extra
  walk-to-self PAUSE per loop pass — result-identical.
- **New yield-structure probe** `tests/multitasker_delay_tests.fth` + Makefile
  target `test-repl-multitasker-delay` (modeled on `test-repl-multitasker-key`;
  24.4 `assert_verdicts.sh` column-0 helper + 24.3 fail-loud `timeout`; lines
  ≤115 chars). **6/6 PASS**: words-resolve, `0 DELAY`/`0 MS` stack-clean, **FR14
  yield witness** (BG counter advances across an operator `0 DELAY` — proves
  `(DELAY)` holds a live PAUSE; the 3 `0 DELAY`s are the only PAUSE source so the
  witness is genuinely discriminating), **FR14/FR15 non-monopoly witness** (a task
  parked in `100 DELAY` — forever-pending under emulation — does not stop the
  operator or the free-running counter), and interpreter-alive.
- **Emulator-vs-hardware split stated honestly** in the probe header (Task 5):
  iz-cpm-banking does not model the 0xFDC7 interrupt, so a nonzero `DELAY`/`MS`
  never *completes* under emulation — wall-clock accuracy (`60 DELAY` ≈ 60 s, AC3)
  and "two `DELAY`s both complete on time" / "`4 DELAY` doesn't freeze the prompt"
  (AC4) are **hardware S9** (NFR-P6-14). ISR-not-installed hang gotcha carried
  forward (recover with `TIMER-ON`). No silent cap.
- **Gates green (from committed source):** `make test` (asm regression), `test-repl`
  (1005 PASS), `test-repl-timer` 9/9, `test-repl-multitasker` 5/5,
  `test-repl-multitasker-key` 5/5, `test-repl-multitasker-delay` 6/6,
  `test-repl-banking` 57 PASS, `test-file-sanity`, `lint-banking-probes`,
  `test-straddle-regression` 3/3 — all 0 FAIL. The +2 B pushed no banking probe
  across `$8000`.
- **S9 hardware smoke deferred** (accuracy / non-freezing prompt / independence) —
  recipe in the close-out chat message per `feedback_post_hw_smoke_steps_at_review`.

### File List

- `src/timer.asm` (modified) — inserted `DW w_PAUSE_cf` cell in `(DELAY)` loop;
  rewrote the `(DELAY)` header/seam comment to done-state.
- `tests/multitasker_delay_tests.fth` (new) — yielding-`DELAY`/`MS` structure probe.
- `Makefile` (modified) — new `test-repl-multitasker-delay` target + `.PHONY` entry.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — story
  status ready-for-dev → in-progress → review.

## Change Log

| Date | Change |
|---|---|
| 2026-06-30 | Story 25.3 drafted (create-story): yielding per-task `DELAY`/`MS`. The whole implementation is a single `DW w_PAUSE_cf` thread cell inserted into the 24.2-pre-factored `(DELAY)` seam (`timer.asm:138`); `DELAY`+`MS` become yielding for free. Documented the forward-reference safety (multitasker.asm INCLUDE'd after timer.asm; sjasmplus multi-pass), the emulator-can't-time split (yield-structure probe only; accuracy + non-freezing-prompt on S9), and the ISR-not-installed hang carry-forward. Proposed ~+2 B envelope. 3 open questions for project lead (MS-yields / emulator-scope / envelope). Status → ready-for-dev. |
| 2026-06-30 | All 3 open questions resolved by project lead at story creation (all recommended): `MS` yields too (keep); emulator probe is structure-only with accuracy/non-freezing-prompt on S9; ~+2 B envelope confirmed. Resolutions pinned in Dev Agent Record. |
| 2026-06-30 | S9 hardware smoke (Ant, real MicroBeast): **non-freezing prompt PASS** (typed live at the prompt with background `DELAY` tasks active, no perceptible lag) and **independence PASS** (`delay5`/`delay7` two different delays → `five!seven!`, the 25.8 headline demo on silicon). Accuracy partial (a `60 DELAY` ran/completed, not explicitly stopwatched; same gate 24.2 passed). Observed: keystrokes typed during a foreground `60 DELAY` queue in the firmware keyboard type-ahead buffer and drain when the delay returns. |
| 2026-06-30 | Dev-pass complete (dev-story). Inserted `DW w_PAUSE_cf` as the first cell of the `(DELAY)` loop (`src/timer.asm`); `DELAY`/`MS` now yield each pass (PAUSE-first), target rides the caller's stack (no shared cell, FR14/FR15). Rewrote the seam comment to done-state. Binary **30,038 → 30,040 B = +2 B** (matches envelope exactly). Added `tests/multitasker_delay_tests.fth` + `test-repl-multitasker-delay` (6/6 PASS: resolve, `0 DELAY`/`0 MS` clean, FR14 yield witness, FR14/FR15 non-monopoly witness, alive) via the 24.4 helper + 24.3 timeout. Documented the emulator-can't-time split + ISR-not-installed hang in the probe header. Floors held: timer 9/9, multitasker 5/5, multitasker-key 5/5, test-repl 1005, banking 57, straddle 3/3, lint/file-sanity green — all 0 FAIL. Wall-clock accuracy + non-freezing-prompt + independence are S9 hardware-smoke (deferred). Status → review. |
| 2026-06-30 | Code review (high-effort, recall-biased; self + two independent finder agents — 8-axis correctness, 6-axis false-green/test-quality). **No correctness bugs.** Branch offset self-corrects (symbolic `.pd_begin - $`); PAUSE round-trips SP/IX/DE/BC with no data-stack PUSH/POP so the target double survives the switch; `0 DELAY`/`0 MS` exit clean (degenerate first-pass); length-1 ring is a walk-to-self no-op; per-task `ps_area` prevents cross-task interference. Probe is discriminating (revert the one cell → `delay-yields` fails) and false-green-safe (`^PASS:`/`^FAIL:` column-0 anchoring, all lines ≤115 < 128 TIB, timeout catches a monopolizing DELAY). Two non-blocking notes: standalone Makefile target not folded into `test`/`test-repl` (matches `test-repl-timer`/`-multitasker[-key]` convention); test (c) leans on test (b)'s `BG` staying alive to advance `CNT` (intentional; non-monopoly independently guarded by the timeout). Status → done. |
