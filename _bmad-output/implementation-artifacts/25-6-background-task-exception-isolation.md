# Story 25.6: Background-task exception isolation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Epic 25 bring-up step 6 — make the fault *legible and recoverable*.** Stories
> 25.1–25.5 built the cooperative scheduler and, along the way, Story 25.4 landed a
> **defensive fix** (commit `0ea1f57`) that already reroutes an uncaught background
> `THROW`: `.throw_uncaught` compares `current_tcb` against `operator_tcb`, and on a
> background task sets `status = TASK_SUSPENDED`, resets SP to the task base, and
> resumes the operator via `sched_resume_current` — the REPL survives. That fix
> exists **so the scheduler could not desync**; it was not the full Story-25.6
> deliverable. **This story completes AD-P6-4:** it adds the operator-facing
> `task N: error <n>` **task-labeled notice** (currently the background path prints
> the plain operator-style `error <n>` — the task label is missing; see the explicit
> forward-reference at `src/multitasker.asm:372`), proves the **per-task `catch_top`
> non-unwind** guarantee with a dedicated probe, and verifies the **FR21
> redefine + re-`ACTIVATE` recovery loop** end-to-end. The mechanism is largely in
> place; the net-new work is the diagnostic label, the isolation/recovery
> acceptance coverage, and the honest byte/hardware accounting.

## Story

As the operator,
I want an uncaught error in a background task to suspend only that task,
so that one bad task does not kill my REPL or the other tasks.

## Acceptance Criteria

(Verbatim from `_bmad-output/planning-artifacts/epics-phase6-epics-24-26.md` Story
25.6, lines 325–339; BDD form. Cross-refs: FR20, FR21, FR24, NFR-P6-7,
AD-P6-4.)

1. **AC1 — background uncaught THROW → `task N: error <n>` + SUSPEND + operator/other tasks continue (FR20, NFR-P6-7, AD-P6-4).**
   **Given** a background task that raises an uncaught `THROW` (e.g. `-99 THROW`,
   `0 /`, a bad store),
   **When** the throw reaches `.throw_uncaught` (`src/exception.asm`) with
   `current_tcb ≠ operator_tcb`,
   **Then** it prints a **task-labeled** notice `task N: error <n>` (N = the ring
   index of the faulting task, matching `.TASKS`/`>TASK`) followed by the existing
   throw-description lookup, sets that task's `status = TASK_SUSPENDED`, and hands
   control back to the operator (via the scheduler restore tail) — the operator's
   REPL and every other task keep running. **The task label `task N: ` is the
   net-new behaviour**; the suspend+resume plumbing already shipped in 25.4's fix
   and must be preserved.

2. **AC2 — operator uncaught THROW keeps the legacy reset → `QUIT`, byte-identical to Phase 5.**
   An uncaught throw in the operator task (`current_tcb = operator_tcb`) prints the
   unchanged `error <n>[: <desc>]` diagnostic (no `task N:` prefix), runs the
   INCLUDE-chain / `asm_cleanup` recovery, resets SP, and `JP w_QUIT_cf`. The
   operator diagnostic string and control flow must be **unchanged** from the
   current committed behaviour (which is itself the Phase-5 behaviour).

3. **AC3 — per-task `catch_top` never unwinds a background throw into an operator CATCH frame (AD-P6-4).**
   Because `PAUSE` swaps `catch_top` as part of the per-task subset
   (`{catch_top, current_bank, base}`, AD-P6-1), a background task runs with its own
   (empty, seeded 0) exception-frame chain. An uncaught throw in a background task
   reaches `.throw_uncaught` via CATCH-TOP = 0 and **never** consults, pops, or
   corrupts an operator CATCH frame that is open on the operator's return stack. A
   probe demonstrates: operator holds an open `CATCH` across a `PAUSE` that enters a
   throwing task → the task suspends → the operator's `CATCH` still round-trips
   normally afterward.

4. **AC4 — operator recovery without restart: inspect, redefine, re-ACTIVATE (FR21).**
   After a background fault the operator can `.TASKS` (sees the task `SUSPENDED`),
   **redefine** the faulting word, and **re-`ACTIVATE`** the same TCB handle — the
   task returns to `AWAKE` and makes progress on the next `PAUSE`, with no system
   restart. (`ACTIVATE` already sets `status = TASK_AWAKE` and re-arms the entry;
   `WAKE` does **not** cleanly recover a fault-suspended task — it re-arms stale
   pre-fault registers — so redefine + re-`ACTIVATE` is the sanctioned path, per
   `src/multitasker.asm:347-352`.)

5. **AC5 — probe + byte delta + S9.**
   A REPL-piped probe asserts: (a) background throw → REPL survives + stack-clean +
   task `SUSPENDED` + the `task N: error <n>` notice is printed; (b) operator throw
   → normal reset (legacy path intact); (c) the AC3 catch-frame isolation; (d) the
   AC4 redefine + re-`ACTIVATE` recovery. Binary delta is recorded; S9 hardware
   smoke PASSES.

**Operator-only-compile lock (FR24) — standing constraint, not a new AC:** this
story touches only the diagnostic/print path in `src/exception.asm`; it must add
**no** background-task write to HERE/LATEST/wordlist/triple. The redefine step in
AC4 is an **operator** activity (the operator compiles the new definition, then
re-`ACTIVATE`s) — the background task still executes pre-compiled words only.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev
      Notes. **Do not inherit the figure below** — re-`wc -c` from an actual clean
      rebuild at dev-pass start (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out
      6-byte doc-drift). At story-drafting time (2026-07-01) the committed build
      artifact measured **30,318 B** (HEAD = `2d845a8`, Story 25.5 close); the
      dev-pass baseline may differ if commits have landed since.
- [x] Capture current `make test-repl` baseline pass counts (the 0-FAIL floor,
      NFR-P6-5), including the Epic-24/25 targets:
      `test-repl-timer`, `test-repl-multitasker`, `test-repl-multitasker-key`,
      `test-repl-multitasker-delay`, `test-repl-multitasker-tasks`,
      **`test-repl-multitasker-throw`** (the target this story extends),
      `test-repl-multitasker-bank`, and `test-repl-banking` (+ isolated fixtures).
      Record each per-target count so the post-edit delta is provable.

### Task 1 — Add the `task N: error <n>` task-labeled notice on the background uncaught path (AC1) — `src/exception.asm`

- [x] **Understand what already exists before editing.** `.throw_uncaught`
      (`src/exception.asm:538-611`) currently: (1) prints the shared
      `error <n>[: <desc>]` diagnostic (lines 546-558) for **both** operator and
      background, THEN (2) discriminates `current_tcb` vs `operator_tcb`
      (lines 572-578), branching to `.throw_uncaught_task` (563-611) for background
      (suspend + resume) or falling into the operator reset (579-591). **Do not
      re-implement the suspend/resume — it works.** The gap is only the missing
      `task N: ` prefix on the background diagnostic.
- [x] **Emit `task N: ` ahead of the shared error line, on the background path
      only.** Add a pre-print discrimination block at the top of `.throw_uncaught`
      (before the existing `error `-prefix print at line 548): compare
      `current_tcb` against `operator_tcb` (the same 2-byte LOW/HIGH compare already
      at 572-578); on **equal** (operator) skip straight to the existing shared
      print — the operator path stays byte-identical (AC2); on **not-equal**
      (background) compute the ring index N and print `task N: ` then fall through
      into the existing shared `error <n>[: <desc>]` print. Keep the existing
      post-print discrimination (572-578 → `.throw_uncaught_task`) unchanged so the
      suspend/resume still fires. (Two compares total; additive, lowest-risk — no
      reorder of the delicate register-contract tail.)
- [x] **Compute N = ring index of `current_tcb`.** Walk the ring from
      `operator_tcb` (index 0) following `link`, incrementing a counter until the
      walk pointer equals `current_tcb` — the identical walk `.TASKS` uses
      (`src/multitasker.asm:379-447`) and that `>TASK` inverts. N must match the
      index `.TASKS` prints and `>TASK` accepts (operator = 0; first background task
      = 1). Registers: use A/BC/HL only where free on this path — **BC/DE/IP
      contract does not apply here** (this is the terminal uncaught path, not a
      normal task word; `.throw_uncaught` already freely clobbers and ends in
      `JP w_QUIT_cf` or `JP sched_resume_current`, never a plain `NEXT`), but you
      MUST preserve nothing the resume tail needs beyond what 25.4's code already
      preserves — re-derive N into a register/scratch cell before the print, since
      the print helpers clobber BC/DE/HL.
- [x] **Print "task ", then N in decimal, then ": ".** Reuse
      `print_signed_dec_bc` (`src/exception.asm:634`) for N (N is a small
      non-negative index; the signed printer prints it compactly and
      BASE-independently — the notice must be readable regardless of user BASE, same
      rationale as the existing `error <n>` print). Add a length-prefixed
      `str_task_notice` `DB "task "` + `_len EQU 5` near the other exception
      strings, and emit the `": "` separator via two `bdos_putchar` calls or a small
      2-byte string (match the surrounding style). Do **not** read `UserArea.base`.
- [x] **Preserve `throw_saved_n`.** The code stashes `n` in `throw_saved_n`
      (line 546) because the BDOS print helpers clobber BC. The new prefix print
      happens **before** that stash today — ensure `n` (in BC on entry) is stashed
      before any new print helper runs, or re-load it from `throw_saved_n` after the
      prefix. Verify BC still holds (or is re-loaded to) `n` at the existing
      `error `-prefix print.

### Task 2 — Extend the throw probe: task-label, catch-frame isolation, recovery (AC1, AC3, AC4, AC5) — `tests/multitasker_throw_tests.fth` + `Makefile`

- [x] **Assert the new `task N: error <n>` notice.** The existing probe
      (`tests/multitasker_throw_tests.fth`) already activates `BOOM` (`-99 THROW`)
      as ring index 1 and PAUSEs into it. Add a Makefile `--present` assertion for
      the literal notice line (e.g. `^task 1: error -99`) between throw sentinels,
      alongside the existing `^   1   SUSPENDED` row check. Guard the TIB 128-char
      line limit (NFR-P6-16/-17) and the `$8000` straddle (interpret-level `'`, not
      `[']` in orchestration — the isolation guarantees are asserted via printed
      witnesses, per the banking-probe lessons).
- [x] **AC3 — catch-frame isolation probe.** Add a case where the operator holds an
      open `CATCH` across the `PAUSE` that enters the throwing task, e.g.
      `['] PAUSE CATCH 0=` must be **true** (the task's uncaught throw suspended the
      task and resumed the operator inside the protected region — the operator's
      CATCH saw no throw), and a subsequent operator `['] BOOM CATCH -99 =` still
      round-trips (the operator's exception machinery is intact). This proves the
      per-task `catch_top` swap kept the background throw out of the operator's
      frame. Emit `PASS: throw-catch-isolated`.
- [x] **AC4 — redefine + re-ACTIVATE recovery probe.** After `BOOM` is SUSPENDED,
      **redefine** the faulting behaviour (define a good word, e.g.
      `: FIXED 41 1+ RESULT ! ;` writing a sentinel to a VARIABLE) and
      re-`ACTIVATE` the **same** TCB handle (`BMT` is already stashed in a CONSTANT
      by the existing probe), `PAUSE`, then assert the task ran (the sentinel is
      present and the task is back `AWAKE` / completed). Emit
      `PASS: throw-reactivate-recovers`. This is the FR21 witness.
- [x] **Wire the new PASS witnesses into the Makefile `--present` list** for
      `test-repl-multitasker-throw` (currently asserts `throw-words-resolve`,
      `throw-operator-survives`, the `   1   SUSPENDED` row, `throw-operator-catch`,
      `throw-alive` — Makefile lines ~347-355). Keep all existing assertions
      (regression floor) and add: the `task 1: error -99` notice line,
      `throw-catch-isolated`, `throw-reactivate-recovers`.

### Task 3 — Documentation + close-out (AC2, AC5)

- [x] Add a short note to `docs/throw-codes.md` documenting the background
      task-suspend notice format (`task N: error <n>`) and that a fault SUSPENDs the
      task (recovery = redefine + re-`ACTIVATE`, not `WAKE`) — mirrors the operator
      `error <n>: <desc>` documentation convention. Follow the source-comment
      discipline (what + why-not-obvious; no story/CR/date provenance in the doc
      body beyond what belongs there).
- [x] Update the `src/multitasker.asm:372` and `:450-451` comments that say
      SUSPENDED "is rendered but not produced until Story 25.6" / "no task produces
      it until Story 25.6" — 25.4's fix already produces SUSPENDED, so these
      forward-references are now stale. Correct them to reflect that the background
      uncaught-THROW path (`exception.asm`) produces SUSPENDED and this story adds
      the `task N:` notice. (Comment-only; 0 binary impact.)
- [x] Re-`wc -c build/antforth.com`; record the delta vs the pre-edit baseline in
      Dev Notes with the per-component itemisation reconciled against the estimate.
- [x] Post the S9 hardware-smoke recipe **in the closing chat message** (not only
      in Dev Notes): on real CP/M 2.2 / MicroBeast, activate a background task that
      throws uncaught, confirm the `task N: error <n>` notice prints, the `ok>`
      prompt survives and stays responsive, `.TASKS` shows the task `SUSPENDED`, and
      a redefine + re-`ACTIVATE` recovers it. Also confirm an operator uncaught
      throw still resets to `QUIT` normally. (STRONG operator preference — post the
      recipe in chat at review.)

## Dev Notes

### The single most important thing to understand about this story

**The hard part already shipped.** Story 25.4's close included a defensive fix
(commit `0ea1f57`, "Epic 25 fix — uncaught THROW in a task suspends it, resumes
operator") because leaving a faulting background task AWAKE while `QUIT` rebuilt the
operator's return stack **desynced the scheduler** (the next yielding `QUERY→PAUSE`
snapshotted operator registers into the background TCB — corruption/hang). That fix
is live and covered by `test-repl-multitasker-throw` (5/5). It implements the
mechanism of AD-P6-4:

- `current_tcb` vs `operator_tcb` discrimination — `src/exception.asm:572-578`
- background: `status = TASK_SUSPENDED`, SP reset to task base, resume operator via
  `JP sched_resume_current` — `src/exception.asm:593-611`
- operator: INCLUDE-chain walk + `asm_cleanup` + SP reset + `JP w_QUIT_cf` —
  `src/exception.asm:579-591`
- per-task `catch_top` isolation — already guaranteed because `PAUSE` swaps
  `{catch_top, current_bank, base}` (Story 25.1); a background task's CATCH-TOP is
  its own (0), so an uncaught throw hits `.throw_uncaught` via the CATCH-TOP=0 test
  at `src/exception.asm:405-409` and cannot touch an operator frame.

**What is genuinely net-new in 25.6:**
1. **The `task N: error <n>` task-labeled notice** (AC1) — the *only* required
   kernel code change. Today the background path prints the plain operator-style
   `error <n>`; the task label is absent. `src/multitasker.asm:372` names Story 25.6
   as the story that produces it.
2. **Acceptance coverage** the 25.4 fix did not assert: the task label (AC1), the
   catch-frame non-unwind (AC3), and the FR21 redefine + re-`ACTIVATE` recovery
   (AC4). These are probe/test extensions (0 binary impact beyond Task 1).
3. **Stale-comment cleanup** for the now-satisfied `Story 25.6` forward-references.

Do **not** re-architect the suspend/resume, re-order the `.throw_uncaught_task`
register tail, or change the SP-reset (see the detailed comment at
`src/exception.asm:600-606` — the SP reset guards `mbb_set_slot2`'s pushes from
landing on the faulting task's unsafe stack during the 25.5 conditional re-page).

### Byte-budget estimate (per-component itemisation — B.2 / Lesson 13.5-C)

Independent itemisation of the AC1 notice code (the only binary-affecting change);
**not** derived from any prior story. Z80 opcode counts:

| Component | Opcodes | Bytes |
|---|---|---|
| Pre-print discrimination (`LD HL,(current_tcb)`; `LD A,L`/`CP LOW operator_tcb`/`JR Z`; `LD A,H`/`CP HIGH operator_tcb`/`JR Z`) | dup of :572-578 | ~14 |
| Ring-index walk (`LD HL,operator_tcb`; `LD C,0`; compare-HL-vs-current_tcb loop: 2×`LD A`/`CP`/`JR Z` + link-follow `LD A,(HL)`/`INC HL`/`LD H,(HL)`/`LD L,A` + `INC C` + `JR`) | ~11 ops | ~22 |
| Print `"task "` (`LD HL,str_task_notice`; `LD B,5`; `CALL bdos_print_str`) | 3 ops | ~8 |
| `str_task_notice DB "task "` literal | data | 5 |
| Print N decimal (`LD C,index`/`LD B,0`; `CALL print_signed_dec_bc`) | reuse existing helper | ~7 |
| Print `": "` separator (2× `LD E,c`/`CALL bdos_putchar`) | 4 ops | ~8 |
| `throw_saved_n` stash re-ordering (move existing `LD (throw_saved_n),BC` earlier or re-load) | ~0 net | ~3 |
| **Per-component total** | | **~67** |

Apply the kernel register-juggle margin (~×1.2, not the ×1.25 LDIR figure — no LDIR
here): **budget ≈ 60–85 B**. Tests + docs + comment fixes are 0 binary. If the
dev-pass lands materially outside this envelope, itemise the variance in Dev Notes
(do not "accept" silently).

### Task-index (`N`) semantics

N is the **ring index** from `operator_tcb` (task 0), identical to what `.TASKS`
prints and `>TASK` consumes (`src/multitasker.asm:379-447`, `:459-470`). The
existing throw probe activates `BOOM` as the only background task → ring index 1, so
the notice reads `task 1: error -99`. If a probe activates multiple tasks, the index
is position-in-ring order of `ACTIVATE`.

### Register / register-contract note

`.throw_uncaught` is a **terminal** path: it never returns via a plain `NEXT` to
continue a task word — it ends in `JP w_QUIT_cf` (operator) or
`JP sched_resume_current` (background), both of which reload register/scheduler
state wholesale. So the normal "task words must preserve DE=IP / BC=TOS" contract
does **not** bind the new prefix code (the 25.4 code already clobbers freely here).
BUT: the print helpers (`bdos_print_str`, `print_signed_dec_bc`, `bdos_putchar`)
clobber A/BC/DE/HL — compute N into a scratch cell or re-derive it after each helper
call, and preserve `n` via the existing `throw_saved_n` cell.

### Project Structure Notes

- **Kernel change:** `src/exception.asm` only (`.throw_uncaught`, ~538-558 region +
  a new `str_task_notice` near the other exception strings). No new module, no
  `structures.asm`/`multitasker.asm` code change (only stale-comment fixes in
  `multitasker.asm`).
- **Tests:** extend `tests/multitasker_throw_tests.fth` + the
  `test-repl-multitasker-throw` recipe in `Makefile` (~lines 347-355). Keep every
  existing assertion (regression floor); add the new witnesses.
- **Docs:** `docs/throw-codes.md` note.
- **Testing standard:** REPL-piped Forth through the threading model only
  (`make test-repl`, NFR-P6-16) — no raw BDOS/asm-thread hacks
  (`feedback_testing_rules`, `feedback_repl_tests_preferred`). Drive orchestration
  at interpret level with `'` (not `[']`); assert printed witnesses; keep probe
  lines ≤128 chars (TIB limit) and dodge the `$8000` straddle-halt.
- **Comment discipline:** what + why-not-obvious, never story/CR/date provenance in
  source (`feedback_source_comment_discipline`).

### References

- Story spec: [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story 25.6] (lines 325–339)
- Requirements: [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md] FR20 (line 391), FR21 (392), FR24 (398), NFR-P6-7 (427)
- Architecture decision: [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-4 — Exception isolation: uncaught-THROW reroute] (lines 344–361); Exception-Isolation Patterns (527–535); per-task subset (512–514)
- Current uncaught path: [Source: src/exception.asm] `.throw_uncaught` (538–611), `.throw_uncaught_task` (593–611), CATCH-TOP=0 test (405–409), `print_signed_dec_bc` (634–659), `print_throw_description` (661+)
- Scheduler / .TASKS / >TASK / WAKE: [Source: src/multitasker.asm] `.TASKS` walk (365–447), state strings + Story-25.6 forward-ref (449–457), `>TASK` (459–470), WAKE-vs-fault-recovery note (347–352), `sched_resume_current` (140+)
- Existing probe: [Source: tests/multitasker_throw_tests.fth] + Makefile `test-repl-multitasker-throw` (~347–355)
- Prior story (context continuity): [Source: _bmad-output/implementation-artifacts/25-5-per-bank-task-switching.md]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story workflow)

### Debug Log References

- First probe run wedged (30 s timeout): the AC3 line `' BOOM2 TASK CONSTANT BMT2
  ACTIVATE` was missing the `DUP`. `TASK` is `( -- task )` (it does **not** consume
  the xt; it `PUSH BC`es the old TOS and produces the handle as new TOS), so
  `CONSTANT` ate the handle and `ACTIVATE ( xt task -- )` underflowed (`error -4`) →
  BOOM2 never went AWAKE → `_iso`'s `PAUSE` found no other AWAKE task and hung
  (cooperative deadlock). Fixed to match the existing BOOM line:
  `' BOOM2 TASK DUP CONSTANT BMT2 ACTIVATE`.

### Completion Notes List

- **AC1 (task-labeled notice):** Added a pre-print discrimination block at the top of
  `.throw_uncaught` (`src/exception.asm`) that compares `current_tcb` vs
  `operator_tcb` **before** the shared `error <n>` print. Operator throws branch
  straight to the shared line (byte-identical to Phase 5 — AC2). Background throws
  walk the ring from `operator_tcb` (index 0) following `TCB_LINK` to compute N, then
  print `str_task_notice` ("task ") + N (via `print_signed_dec_bc`, BASE-independent)
  + `str_colon_space` (": ", reused) and fall through into the shared print → the
  line reads `task 1: error -99`. `n` is preserved via the existing `throw_saved_n`
  stash (moved-earlier is unnecessary — the stash is already the first instruction of
  the path; the new block clobbers only BC/DE/HL/A, never `throw_saved_n`).
- **AC2 (operator path unchanged):** operator uncaught throws skip the label and run
  the unchanged INCLUDE-chain/`asm_cleanup`/`JP w_QUIT_cf` recovery. Proven by the
  full 1005/0 regression suite (many tests parse operator `error` output) + the
  probe's `throw-operator-survives`/`throw-operator-catch` witnesses.
- **AC3 (catch-frame isolation):** new `_iso` probe — operator holds `['] PAUSE
  CATCH` across a `PAUSE` that enters a fresh throwing task (BOOM2, -7). The per-task
  `catch_top` swap keeps the background throw off the operator's frame → `CATCH`
  returns 0; a subsequent `['] BOOM2 CATCH -7 =` confirms the operator's machinery is
  intact. Witness `PASS: throw-catch-isolated`.
- **AC4 (recovery without restart):** new `_recov` probe — re-`ACTIVATE` the same
  fault-suspended TCB handle (BMT) with a good word (`FIXED`, writes sentinel 42 to
  VARIABLE `RESULT`), `PAUSE`, assert `RESULT @ 42 =`. Witness
  `PASS: throw-reactivate-recovers`.
- **AC5:** probe extended 5→8 assertions; Makefile adds `--present 'task 1: error
  -99'` + the two new PASS witnesses; all existing assertions retained (regression
  floor). **S9 HW UAT PASSED on real MicroBeast 2026-07-01** (antforth v3.1.0,
  12 banks; capture `~/Downloads/beastty-20260701-080644.bin`): background `-99 THROW`
  → `task 1: error -99` prints and `ok` survives; `.TASKS` shows `   1   SUSPENDED`
  (operator `   0 * AWAKE`); `' FIXED BMT ACTIVATE PAUSE  R @ .` → `42` (re-ACTIVATE
  recovers the suspended TCB); operator `-99 THROW` → bare `error -99` (no `task N:`
  prefix, clean reset — AC2); the recovered task then shows `   1   ASLEEP`
  (completed via `task_exit`). All four sub-checks confirmed on silicon.
- **Task 3:** documented the uncaught-THROW diagnostic format (operator vs
  `task N:` background, redefine + re-`ACTIVATE` recovery) in a new §(a.1) of
  `docs/throw-codes.md`; corrected the now-stale "not produced until Story 25.6"
  forward-references in `src/multitasker.asm` (`.TASKS` header + state-string
  comment) — SUSPENDED is produced by the `exception.asm` reroute. Comment-only,
  0 binary.

**Binary delta:** baseline 30,318 B (HEAD `2d845a8`, clean rebuild at dev-pass
start) → 30,383 B = **+65 B**, inside the story's 60–85 B budget (AC1 notice code +
`str_task_notice`). Comment/doc/test changes are 0 binary. No variance to itemise.

**Gates (all green, from committed source):** main `make test-repl` 1005 PASS / 0
FAIL (2 host-bounded SKIPs unchanged); `test-repl-timer` 9; `-multitasker` 5;
`-multitasker-key` 5; `-multitasker-delay` 6; `-multitasker-tasks` 8;
`-multitasker-throw` **8** (was 5); `-multitasker-bank` 6; `test-repl-banking` 57/0;
`test-straddle-regression` 3/3; `lint-banking-probes` OK; `check-doc-sync` 0-drift;
`test-file-sanity` OK.

### File List

- `src/exception.asm` — AC1 `task N:` prefix block on `.throw_uncaught` background
  path + `str_task_notice`/`_len` string (+65 B).
- `src/multitasker.asm` — corrected stale "not produced until Story 25.6"
  forward-reference comments (`.TASKS` header, state-string block); 0 binary.
- `tests/multitasker_throw_tests.fth` — AC3 catch-isolation (`_iso`, BOOM2) + AC4
  redefine/re-ACTIVATE recovery (`_recov`, FIXED/RESULT) probe cases.
- `Makefile` — `test-repl-multitasker-throw`: added `--present 'task 1: error -99'`
  + `PASS: throw-catch-isolated` + `PASS: throw-reactivate-recovers` assertions
  (existing assertions retained).
- `docs/throw-codes.md` — new §(a.1) Uncaught-THROW Diagnostic Format.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 25.6 → review.

## Open Questions (RESOLVED by operator 2026-07-01 — no longer blocking)

1. **Notice wording — CONFIRMED.** Use the literal `task N: error <n>` from the
   epics AC (e.g. `task 1: error -99`). The probe asserts this exact form.
2. **Task-index scope — CONFIRMED.** N is the `.TASKS` **ring index** (position
   order, operator = 0), matching `.TASKS`/`>TASK`. No separate stored task id.
