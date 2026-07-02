# Story 26.1: Counting semaphore (SIGNAL / WAIT)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a task author,
I want counting semaphores to coordinate access between tasks,
so that a producer and consumer can synchronise without corrupting shared state.

## Acceptance Criteria

1. **AC1 — Constructor initialises a count cell (FR17).**
   **Given** a working scheduler (Epic 25)
   **When** the author runs `n SEMAPHORE name` (e.g. `2 SEMAPHORE sem`)
   **Then** `name` is a created word whose execution pushes the address of a single
   count cell initialised to `n`, verifiable by `sem @ .` printing `n`. A negative or
   zero initial count is stored verbatim (no clamping); the cell is an ordinary
   data-space cell (`sem` is `@`/`!`-addressable like a `VARIABLE`).

2. **AC2 — `SIGNAL` increments, `WAIT` (non-blocked path) decrements.**
   **When** a task runs `sem SIGNAL`, the count at `sem` is incremented by one; **when**
   a task runs `sem WAIT` and the count is already non-zero, `WAIT` decrements the count
   by one and returns immediately without yielding-and-waiting past the first PAUSE seam.
   Both words consume exactly the semaphore address (`( sem -- )`) and leave the data
   stack otherwise unchanged (`DEPTH`-clean).

3. **AC3 — `WAIT` cooperatively spins with `PAUSE` when the count is zero (FR17).**
   **When** a task runs `sem WAIT` and the count is zero
   **Then** it cooperatively spins with `PAUSE` (yield-first) until the count becomes
   non-zero, then decrements it and returns. While spinning it makes no forward progress
   of its own but **yields the processor every pass** (no CPU busy-spin), so the REPL and
   peer tasks keep running.

4. **AC4 — Cross-task hand-off, no corruption, no deadlock (FR17, headline of the story).**
   **Given** a background producer task that writes to a shared buffer and `SIGNAL`s a
   semaphore, and a consumer that `WAIT`s then reads
   **Then** a producer/consumer probe over the shared buffer shows every produced value
   is consumed exactly once, in order, with no corruption and no deadlock in the
   documented pattern. Emulator asserts the structural outcome (counts / values / stack
   cleanliness); wall-clock behaviour rides S9.

5. **AC5 — Non-atomic by design, documented (FR17 / AD-P6-8).**
   The implementation is non-atomic by design — it is safe **only** because the model is
   cooperative (single-threaded except the 64 Hz ISR, which touches only `TICKS`, never a
   semaphore cell). The test-and-decrement in `WAIT` is not guarded by interrupt masking;
   correctness rests on there being **no `PAUSE` between the "count > 0" check and the
   decrement**. This invariant is stated in a source comment on `WAIT` and in
   `docs/phase6-multitasker.md`.

6. **AC6 — Starvation is observable, ring stays alive (deadlock/starvation semantics; AI-25-3).**
   A named, probed AC: a task that `WAIT`s on a semaphore that is **never** `SIGNAL`ed
   does not itself progress, **but the scheduler ring stays alive** — because `WAIT`
   PAUSEs each pass, a peer background counter and the operator REPL keep advancing. This
   is the *cooperative-friendly* failure mode and is explicitly contrasted, in
   `docs/phase6-multitasker.md`, with the Story 25.7 silicon-confirmed **non-yielding**
   stall (a hard, reset-required wedge). The contrast is the point: `WAIT` starvation is
   recoverable/observable; a non-yielding critical section is not.

7. **AC7 — Regression, budget, and hardware.**
   The v3.1.0 close-out `make test-repl` baseline still passes with **0 FAIL**; the new
   semaphore probe is additive (its own Makefile target, **not** folded into plain
   `test-repl`, mirroring the `test-repl-multitasker-*` sibling targets). Binary delta is
   recorded against the pre-edit baseline (30,438 B) with per-word itemisation. S9
   hardware-smoke on real CP/M 2.2 / MicroBeast **PASS** (NFR-P6-6), covering the
   producer/consumer hand-off.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → **30,438 B** (validated by
      a clean `make asm` before any edits).
- [x] Capture current `make test-repl` baseline pass count → **1005 PASS / 0 FAIL**.

### Story tasks

- [x] **Task 1 — Semaphore constructor `SEMAPHORE ( n "<spaces>name" -- )` (AC: 1).**
  Added to the coordination section of `src/multitasker.asm` (AD-P6-8) as a `DEFWORD`
  mirroring `VARIABLE` but commaing the supplied count: body = `w_CREATE_cf, w_COMMA_cf,
  EXIT_CODE`. `name` pushes the count-cell address; the cell holds `n`.
  - [x] 1.1 Header + body per the `DEFWORD` idiom (`w_SEMAPHORE_cf EQU w_SEMAPHORE_body - 3`
        → `JP DOCOL`), matching `src/bootstrap.asm:73` `VARIABLE`.
  - [x] 1.2 Confirmed reused labels against source: `w_CREATE_cf`, `w_COMMA_cf`, `EXIT_CODE`.

- [x] **Task 2 — `SIGNAL ( sem -- )` increment (AC: 2).**
  Added as `DEFWORD` `DUP @ 1+ SWAP !` (the recommended route — no register-contract
  exposure; DEFCODE not needed since the +80 B total is well inside budget).
  - [x] 2.1 Body = `w_DUP_cf, w_FETCH_cf, w_ONE_PLUS_cf, w_SWAP_cf, w_STORE_cf, EXIT_CODE`.

- [x] **Task 3 — `WAIT ( sem -- )` yield-and-wait, then decrement (AC: 2, 3, 5).**
  Added to the coordination section as a `DEFWORD` whose loop mirrors `(DELAY)`'s
  **PAUSE-first** spin seam (`src/timer.asm:135`). The fetched count *is* the loop flag:
  `QBRANCH` loops back on 0 (count still zero) and falls through on non-zero — so **no
  `0<>`/`0=` polarity word is needed**.
  ```
  w_WAIT_body:
  .begin:
        DW  w_PAUSE_cf        ; yield-first every pass (FR17; ring stays live under starvation)
        DW  w_DUP_cf          ; ( sem sem )
        DW  w_FETCH_cf        ; ( sem count )   count is the flag
        DW  w_QBRANCH_cf
        DW  .begin - $        ; loop back while count == 0
        DW  w_DUP_cf          ; ( sem sem )     count>0: consume one unit
        DW  w_FETCH_cf        ; ( sem count )
        DW  w_ONE_MINUS_cf    ; ( sem count-1 )
        DW  w_SWAP_cf         ; ( count-1 sem )
        DW  w_STORE_cf        ; ( )
        DW  EXIT_CODE
  ```
  - [x] 3.1 Verified there is **no `PAUSE` between the `@`/non-zero fall-through and the
        `!`** — the only PAUSE is at the top of the loop, before the check (AC5).
  - [x] 3.2 Source comment on `WAIT` states the non-atomic-but-cooperatively-safe
        invariant and the "PAUSE-first ⇒ starving WAITer never wedges the ring" property.

- [x] **Task 4 — Probe `tests/semaphore_tests.fth` + Makefile target (AC: 1, 2, 3, 4, 6, 7).**
  New probe `tests/semaphore_tests.fth` + `test-repl-semaphore` target modelled on
  `test-repl-multitasker-delay`: fail-loud `timeout`, verdicts via
  `tests/assert_verdicts.sh` column-0 helper with a `^FAIL:` tripwire; added to `.PHONY`;
  **not** folded into `test-repl`. All 6 verdicts PASS.
  - [x] 4.1 AC1/AC2 single-task structural asserts (`sem-constructor-init`,
        `sem-signal-wait-count`), including verbatim negative-count init.
  - [x] 4.2 AC3+AC4 cross-task hand-off (`sem-handoff-no-loss`): background producer
        `SIGNAL`s a shared 4-cell buffer; operator `WAIT`s ×4 and reads each in order.
        RUNTIME-computed witnesses (sum = 100 AND all-4-good) defeat false-green.
  - [x] 4.3 AC6 starvation-liveness (`sem-wait-starves-ring-alive`): the producer parks
        on a never-signalled `WAIT` while a peer counter keeps advancing and the probe
        still reaches `BYE`. All lines ≤ 128 chars; no `$8000` straddle issue.
        **Task-budget note:** TCBs carve from the ~2 KB below `$8000`, so the probe uses
        only **two** forever-tasks (the initial 4-task draft hit the F4 `-8` guard).

- [x] **Task 5 — Docs + budget close-out (AC: 5, 6, 7).**
  - [x] 5.1 Added "Coordination — the counting semaphore" section to
        `docs/phase6-multitasker.md`: word surface, documented producer/consumer pattern,
        non-atomic-by-design note (AC5), starvation-vs-non-yielding-stall contrast citing
        Story 25.7 (AC6).
  - [x] 5.2 Binary delta recorded: **+80 B** (30,438 → 30,518); itemised in Dev Notes.
  - [x] 5.3 **S9 hardware-smoke — PASS on real MicroBeast / CP/M 2.2** (capture
        `beastty-20260701-212718.bin`). Constructor init (`2 semaphore s` → `s @` = 2),
        `WAIT` decrement (2→1), `SIGNAL` increment (1→2), and the background producer→operator
        hand-off (`full wait … buf + @` → 10, 20 in order) all confirmed on silicon with the
        prompt staying responsive. Banner `23498 bytes free` matches the +80 B build (NFR-P6-6).

## Dev Notes

### Standing multitasker contract — front-loaded (AI-25-4; do not rediscover)

These are the footguns Epic 25 proved will bite Epic 26 authors. Internalise before writing a line:

- **`PAUSE` register contract** (`project_multitasker_pause_register_contract`): every
  normal task word **must preserve `DE` = IP** — `PAUSE` is the *only* word allowed to not.
  If Task 2's `SIGNAL` is written as `DEFCODE` (not the recommended `DEFWORD`), the raw
  Z80 must leave `DE` untouched (as `SLEEP`/`WAKE` do — `src/multitasker.asm:392,414`
  "DE=IP untouched throughout"). The `DEFWORD` route sidesteps this entirely; prefer it.
- **`( -- d )` producers push BC** (`project_double_producer_push_bc`): not relevant to
  the single-cell semaphore words here, but noted because the coordination section sits
  next to `TICKS`. No double-cell producers in this story.
- **`check_overflow`/`DEPTH` use the per-task `t_sp_base`** — `PAUSE` swaps `sp_base`.
  You are not touching the scheduler, so no action; just know the semaphore cell lives in
  shared data space, not per-task state.

### `TASK ( -- task )` handle footgun + `AGAIN` undefined (AI-25-4)

- `TASK` returns the TCB handle as a **stack value** — it is *not* a variable. The
  probe's background producer must keep that handle (e.g. in a `VARIABLE` or on the
  stack) to `ACTIVATE`/address it; re-reading `LATEST @` won't give a usable xt for a
  bank-0 runtime word (`project_bank_triple_excludes_buckets` / use `'`).
- **`AGAIN` is undefined** in antforth — a forever loop is `BEGIN … 0 UNTIL`. The
  producer/demo loop in the probe must use that idiom, never `AGAIN`.

### Why the design is correct despite being non-atomic (AC5 rationale)

The cooperative model is single-threaded except the 64 Hz ISR, and **the ISR touches only
`TICKS`** (`AD-P6-5`), never a semaphore cell. A context switch happens *only* at a
`PAUSE` (a `NEXT` boundary). `WAIT` places its only `PAUSE` at the **top** of the loop,
before the count check; between the "count > 0" fall-through and the `!` decrement there
is no `PAUSE`, so no other task can observe or mutate the count mid-decrement. Two tasks
both blocked in `WAIT` on the same semaphore cannot both consume a single `SIGNAL`: after
`SIGNAL` bumps the count to 1, whichever task the round-robin runs next decrements it to
0; the other sees 0 and loops. No lost wakeup, no double-take. This is why interrupt
masking is unnecessary — and why it would be **wrong** to add a `PAUSE` inside the
check-decrement window.

### Byte-budget estimate — per-component itemisation (B.2; no "mirrors prior arm")

Independent per-word itemisation (cells × 2 B + `DEFWORD`/`DEFCODE` header = link 2 B +
count/flags 1 B + name bytes; validate exact header cost against the macro at dev time):

- **`SEMAPHORE`** (`DEFWORD`): header ≈ 2 + 1 + 9 (`"SEMAPHORE"`) = 12 B; body = 3 cells
  (`CREATE`, `,`, `EXIT`) = 6 B → **≈ 18 B**.
- **`SIGNAL`** (`DEFWORD` `DUP @ 1+ SWAP !`): header ≈ 2 + 1 + 6 = 9 B; body = 6 cells
  (`DUP @ 1+ SWAP ! EXIT`) = 12 B → **≈ 21 B**.
- **`WAIT`** (`DEFWORD`): header ≈ 2 + 1 + 4 = 7 B; body = 11 cells (`PAUSE DUP @ QBRANCH
  <off> DUP @ 1- SWAP ! EXIT`) = 22 B → **≈ 29 B**.
- **Total ≈ 68 B** kernel growth (≈ 60–90 B allowing for header-macro overhead). Trivial
  against the F5 per-epic envelope (~2.4× prior-phase pattern applies to the *epic*
  aggregate, not this one story). Reconcile the measured delta at close (Task 5.2); any
  overshoot is accept-with-rationale per NFR-P6-10, no silent bloat.

If the `DEFCODE` route is taken for `SIGNAL` (16-bit `INC (HL)` + carry to high byte),
budget ≈ 11 B for the body instead of 21 B — but it re-incurs the `DE`-preservation
contract. The ~10 B saving does not justify the register-contract risk for v1; recommend
`DEFWORD`.

### Source tree components to touch

- `src/multitasker.asm` — **coordination section** (AD-P6-8): the three new words. This
  is where AD-P6-7/AD-P6-8 place semaphores ("Owns the scheduler… semaphores (Epic 26)").
  No edits to the scheduler ring, `PAUSE`, TCB, or exception paths.
- `tests/semaphore_tests.fth` — **new** probe (architecture's declared name).
- `Makefile` — new `test-repl-semaphore` target + `.PHONY` entry; **not** wired into
  `test-repl`.
- `docs/phase6-multitasker.md` — coordination section.

### Testing standards summary

- REPL-piped Forth only (NFR-P6-16) — test through the threading model, never raw BDOS
  (`feedback_testing_rules`, `feedback_repl_tests_preferred`).
- Fail-loud `timeout` wrapper (Story 24.3) so a genuine deadlock → loud FAIL, not a CI
  hang; verdicts through `tests/assert_verdicts.sh` (Story 24.4).
- Defeat false-green source echo with RUNTIME-only witness tokens / `--present` row
  checks for any state a task actually computed (the 23.2 defence, used in 25.4/25.6).
- Probe lines ≤ 128 chars (TIB limit, `feedback_tib_size_inline_comments`); honour the
  $8000 straddle constraint; drive any bank-ops at interpret level (`'`, not `[']`).
- **CP/M 0x1A EOF**: `tests/semaphore_tests.fth` must be 0x1A-terminated before SLIDE to
  real MicroBeast (`feedback_cpm_0x1a_eof_marker`).

### Project Structure Notes

- **Probe file name.** Architecture (`architecture.md` file-tree, line 664) declares
  `tests/semaphore_tests.fth`; the sibling multitasker probes use the
  `tests/multitasker_*_tests.fth` prefix. This story follows the **architecture's
  declared name** (`semaphore_tests.fth`) as source-of-truth. If the dev prefers grep-
  adjacency with the `multitasker_*` siblings, `tests/multitasker_sem_tests.fth` is an
  acceptable variance — note whichever is chosen in the File List.
- **Word-surface closure.** The PRD's New Word Surface for v1 lists `SIGNAL WAIT`
  (`architecture.md:514`); the constructor is unnamed in that list. `SEMAPHORE` is the
  chosen constructor name (parallels `VARIABLE`/`CONSTANT`). No other coordination words
  ship in this story (mutex = 26.2, mailbox = 26.3).
- No new module, no INCLUDE-order change (coordination lives inside the existing
  `src/multitasker.asm`, already after `banking.asm`/`exception.asm` per AD-P6-7).

### References

- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story 26.1] — user story, ACs, FR17.
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-8] — coordination primitives, cooperative spin-with-PAUSE, non-atomic-OK (lines 469–476).
- [Source: _bmad-output/planning-artifacts/architecture.md#Naming Patterns] — `SIGNAL WAIT` word surface, DEFCODE/DEFWORD label rules (lines 511–519).
- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Requirements Inventory] — FR17 (line 62), NFR-P6-5/6/10/16/17.
- [Source: src/timer.asm:121-148] — `(DELAY)` PAUSE-first spin loop — the pattern `WAIT` mirrors.
- [Source: src/bootstrap.asm:69-80] — `VARIABLE` = `CREATE 0 ,` DEFWORD — the pattern `SEMAPHORE` mirrors.
- [Source: src/compiler.asm:900-929] — `CREATE`; src/memory.asm:44-60 — `@`/`!`; src/arithmetic.asm:13-24 — `1+`/`1-`.
- [Source: src/multitasker.asm:371-415] — `SLEEP`/`WAKE` DEFCODE cell-mutation + "DE=IP untouched" contract.
- [Source: Makefile:303-310] — `test-repl-multitasker-delay` target — the probe-target template.
- [Source: _bmad-output/implementation-artifacts/epic-25-retro-2026-07-01.md:89-127] — Epic 26 readiness; AI-25-3 (deadlock AC), AI-25-4 (front-load contract).
- Memory: `project_multitasker_pause_register_contract`, `project_story25_7_keyboard_break_design`, `feedback_defword_cf_label`, `feedback_testing_rules`, `project_double_producer_push_bc`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story workflow)

### Debug Log References

- Baseline: `make asm` clean → `wc -c build/antforth.com` = 30,438 B; `make test-repl` = 1005 PASS / 0 FAIL.
- Post-implementation: `make asm` clean → 30,518 B (**+80 B**).
- Gates: `make test-repl-semaphore` (6/6 PASS); `make test-repl` (1005/0, no regression);
  `make test-straddle-regression` (3/3); all sibling `test-repl-multitasker-*` + `test-repl-timer`
  green; `make check-doc-sync` (0 drift); `make test-file-sanity` (PASS).
- One implementation detour: the first probe draft activated **4** forever-tasks and hit the
  Story 24.3 `TASK` `-8` dictionary-overflow guard (TCBs carve from the ~2 KB below `$8000`).
  Restructured to **2** background tasks (producer doubles as the AC6 starving waiter) — green.

### Completion Notes List

- **What shipped:** three coordination words in the `src/multitasker.asm` coordination section
  (AD-P6-8) — `SEMAPHORE ( n "name" -- )` (DEFWORD `CREATE ,`), `SIGNAL ( sem -- )` (DEFWORD
  `DUP @ 1+ SWAP !`), `WAIT ( sem -- )` (DEFWORD, PAUSE-first spin mirroring `(DELAY)`; the
  fetched count is the `QBRANCH` flag, so no `0=`/`0<>` needed).
- **Binary delta +80 B**, within the drafted ~60–90 B envelope. Itemised: the +12 B over the
  ~68 B point-estimate is the DEFWORD header baseline (link 2 + bank 1 + flags/len 1 = 4 B/word
  × 3) that the draft under-counted; the three bodies (3 + 6 + 11 cells) are exactly as specced.
- **AC5 (non-atomic-safe):** WAIT's only PAUSE is at loop top, before the count check; nothing
  yields between the non-zero fall-through and the `!`, so the take is atomic w.r.t. the ring.
  Documented in the WAIT source comment and `docs/phase6-multitasker.md`.
- **AC6 (AI-25-3):** `sem-wait-starves-ring-alive` is a named, probed verdict — a task parked
  forever in `WAIT` keeps the ring alive (peer counter advances, probe reaches BYE), contrasted
  in the doc with Story 25.7's reset-required non-yielding stall.
- **AI-25-4 footguns avoided:** all three words preserve DE=IP (DEFWORD route); probe uses
  `BEGIN … 0 UNTIL` (no `AGAIN`) and stashes task handles correctly.
- **S9 hardware-smoke PASS** on real MicroBeast / CP/M 2.2 (capture
  `beastty-20260701-212718.bin`): constructor init, WAIT decrement, SIGNAL increment, and the
  background producer→operator semaphore hand-off (10, 20 in order) all confirmed on silicon
  with the prompt responsive throughout. AC7 / NFR-P6-6 satisfied.

### File List

- `src/multitasker.asm` (modified) — coordination section: `SEMAPHORE`, `SIGNAL`, `WAIT`.
- `tests/semaphore_tests.fth` (new) — 6-verdict counting-semaphore probe.
- `Makefile` (modified) — `test-repl-semaphore` target + `SEMAPHORE_PROBE` var + `.PHONY` entry.
- `docs/phase6-multitasker.md` (modified) — "Coordination — the counting semaphore" section.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — epic-26 in-progress; 26.1 status.

## Change Log

| Date | Change |
|---|---|
| 2026-07-01 | Implemented Story 26.1 counting semaphore (`SEMAPHORE`/`SIGNAL`/`WAIT`), +80 B (30,438 → 30,518). New `test-repl-semaphore` probe (6/6 PASS); `test-repl` 1005/0 no regression; straddle/doc-sync/file-sanity green. Status → review. |
| 2026-07-01 | **S9 hardware-smoke PASS** on real MicroBeast / CP/M 2.2 (capture `beastty-20260701-212718.bin`): constructor init = 2, `WAIT` 2→1, `SIGNAL` 1→2, background producer→operator hand-off = 10, 20 in order, prompt responsive. AC7 / NFR-P6-6 closed. |
