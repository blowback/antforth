# Story 25.7: Keyboard break + documented starvation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Epic 25 bring-up step 7 — make a *runaway* task recoverable, and make the one
> unrecoverable case *honest*.** Stories 25.1–25.6 built the cooperative scheduler,
> the input-only yield seam (`KEY`/`(LINE)`/`(DELAY)` all `PAUSE`), per-bank switching,
> and background-fault isolation (`task N: error <n>` + SUSPEND, reusing the
> `.throw_uncaught` reroute). This story closes **FR22**: a task that still reaches a
> yield point can be broken in from the keyboard; a task that *never* yields produces
> a **documented, observable stall = reset-required** — stated honestly, not papered
> over.
>
> **Design settled with the operator (2026-07-01) — a deliberate, ratified deviation
> from AD-P6-6's ISR-poll mechanism.** The operator works over a **serial TTY**, so an
> ISR keyboard-port scan is useless (there is no local keypress to scan — the break
> must arrive as an in-band byte on the serial line). The break key is **`Ctrl-\`
> (0x1C)** — a single, unambiguous byte that is *not* an escape-sequence prefix (unlike
> ESC, which leads arrow-key sequences such as `ESC [ D`), so it never false-triggers
> on cursor keys. It is **detected in-band in `(EDIT)`**, right beside the existing
> `^C` handler (`src/io.asm:343–353`), where it sets the fixed-memory `break_pending`
> flag; the flag is **consumed at the next yield point** (`PAUSE`, and thus
> `KEY`/`(DELAY)` which route through it) and, because the operator is the task that
> *reads* the byte, the consume rule **only breaks a non-operator task** (the operator
> leaves the flag set and yields so the misbehaving background task consumes it). The
> `break_pending` flag + PAUSE-consume + `THROW -28` machinery is exactly AD-P6-6's;
> only the *setter* moves from the ISR to the input path. **No ISR change, no hardware
> port** — the story is unblocked.

## Story

As the operator,
I want to break in from the keyboard when a task misbehaves,
so that a runaway task is recoverable rather than requiring a reset.

## Acceptance Criteria

(BDD adapted from `_bmad-output/planning-artifacts/epics-phase6-epics-24-26.md` Story
25.7, lines 341–354, plus the folded-in warm-boot follow-up, lines 356–367. The break
*mechanism* is the operator-ratified in-band `Ctrl-\` design above — a conscious
substitution for AD-P6-6's "ISR polls the break key," justified by the serial-TTY
reality; flag + consume + `THROW -28` are unchanged from AD-P6-6. Cross-refs: FR22,
AD-P6-6, AD-P6-3, NFR-P6-7, NFR-P6-14.)

1. **AC1 — keyboard break of a *yielding* runaway task (FR22, AD-P6-6 flag+consume).**
   **Given** a background task that loops but still reaches a yield point
   (`PAUSE`/`KEY`/`DELAY`),
   **When** the operator sends **`Ctrl-\` (0x1C)** over the console,
   **Then** the operator's input path (`(EDIT)`, `src/io.asm`) recognises the byte —
   **without inserting it into the line buffer** (exactly as `.edit_etx` special-cases
   `^C`) — and sets the fixed-memory `break_pending` flag; the flag is **consumed at the
   next yield point** (`PAUSE`, inherited by `KEY`/`(DELAY)`), which raises a break in
   the running **background** task (see AC3), returning control to the operator. The
   operator's `ok` prompt returns and stays responsive; the broken task leaves the
   rotation (state per AC5) **without corrupting the scheduler, another task's stacks, or
   the dictionary** (NFR-P6-7).

2. **AC2 — a *never-yielding* task is an honest, documented stall (FR22, AD-P6-3).**
   A hard CPU-bound loop that never reaches a yield point (e.g. `: SPIN BEGIN AGAIN ;`
   with no `PAUSE`/`KEY`/`DELAY`, cf. `TRAFFIC`'s `BEGIN … AGAIN`) **starves the ring**:
   once the scheduler switches to it, the operator never gets another turn, so it can
   never *read* the `Ctrl-\` byte and the break is never even detected. This is the
   **documented, expected cooperative failure mode = reset-required**, stated plainly in
   the docs and surfaced by a probe — **not** silently corrupted and **not** papered over
   as if breakable (architecture line 338–340; PRD lines 120–122, 208–217). (This is the
   inherent limit of in-band detection, and it coincides exactly with the cooperative
   model's own limit: no yield → no operator turn → no break.)

3. **AC3 — the break raises a legible break in the running task, reusing the 25.6 reroute.**
   Consuming `break_pending` at the yield seam **raises `THROW -28` ("user interrupt",
   ANS §9.3.5, `docs/throw-codes.md:137`) in the running task's own context**, funnelling
   through the existing uncaught-THROW discriminator (`.throw_uncaught`,
   `src/exception.asm`, Story 25.6):
   - running task is a **background task** → prints the task-labeled `task N: error -28`
     notice, sets that TCB `status = TASK_SUSPENDED`, and resumes the operator via
     `sched_resume_current` — the operator's REPL and every other task keep running.
   **Break-target rule (settled): only a non-operator task is broken.** Because the
   operator is the task that reads the `Ctrl-\` byte, the PAUSE-consume must, when the
   *running* task is the operator (task 0), **leave `break_pending` set and take the
   normal ring switch** — so the operator hands off to the misbehaving background task,
   which consumes the flag on *its* next yield and is the one broken. (This makes the
   break deterministic — always the runaway task, never the operator — and settles what
   was OQ#2.) No new suspend/resume plumbing is written; the net-new kernel behaviour is
   the `Ctrl-\` recognition, the flag, and the consume→raise `-28` at the seam.

4. **AC4 — documentation describes the cooperative starvation model and the break path.**
   Extend the multitasking prose in `docs/throw-codes.md` (the "When does a background
   fault appear?" block, `:83–98`, or a sibling section): the cooperative round-robin
   model, that a task only runs by yielding, that a *yielding* runaway is broken with
   **`Ctrl-\`** (→ `task N: error -28` + SUSPEND, recover by redefine + re-`ACTIVATE`),
   the choice of `Ctrl-\` (single byte, not an ESC-sequence prefix — arrow keys are
   safe), and the honest *non-yielding* stall = reset-required limit. Source-comment
   discipline: what + why-not-obvious, no story/CR/date provenance in the doc body
   (`feedback_source_comment_discipline`).

5. **AC5 — probes + byte delta + S9.**
   REPL-piped probes demonstrate **both** paths, injecting the **real `0x1C` byte** into
   piped stdin (the emulator can drive the actual in-band break end-to-end — no software
   stand-in needed):
   (a) **break path** for a *yielding* task — activate a background task that PAUSEs
   (or `DELAY`s) in a loop, feed `Ctrl-\` (Makefile `printf '\034'`) followed by an
   explicit interpret-level `PAUSE` to hand off deterministically, and assert the
   witnesses: the `task N: error -28` notice is printed (`--present 'task 1: error -28'`),
   the task shows `SUSPENDED` in `.TASKS`, the operator REPL survives (a runtime token
   echoes), the stack is clean, and a redefine + re-`ACTIVATE` recovers it
   (`PASS: break-recovers`, reusing the 25.6 `_recov` pattern). Emit
   `PASS: break-yielding-task`.
   (b) **documented stall** for a *non-yielding* task — demonstrate that a task which
   never yields is not broken by `Ctrl-\` (witness the mechanism — "no yield point → no
   operator turn → flag never consumed" — via a bounded, fail-loud form; do **not** ship
   a genuinely infinite `BEGIN AGAIN` in CI). Emit `PASS: break-nonyield-stalls`.
   Binary delta is recorded (per-component itemisation reconciled against the estimate);
   **S9 hardware smoke confirms the real `Ctrl-\` break over the operator's serial TTY**
   (the same in-band path the emulator exercises, on silicon).

6. **AC6 — warm-boot / stale-tick-ISR hygiene: verify (not re-implement) the CCP-exit slot release.**
   (Folded in from Story 24.1, epics lines 356–367.) After any exit to CCP, loading a
   *different* program must not crash from the COLD-installed 64 Hz tick ISR left live in
   the freed TPA. **This is now a verification + comment-fix task — the follow-up's
   premise is stale and the `Ctrl-\` design does not take over console input:**
   - the note's "antforth reads the REPL line via BDOS fn 10 (`C_READSTR`)" is **stale** —
     Story 25.2 migrated the REPL to the yielding fn-1/fn-11 char reader
     (`src/outer_interpreter.asm:146–162`, `src/io.asm:174–212`); fn 10 is no longer
     called. `Ctrl-\` arrives through that same fn-1 path (as `^C` already does), so the
     note's "switch input to BDOS fn 6 / BIOS CONIN" prescription is **not needed**;
   - the `^C`-to-CCP exit is **already** routed through `BYE`'s slot release: `(EDIT)`'s
     `.edit_etx` jumps `JP w_BYE_cf` on `^C` at column 0 (`src/io.asm:343–353`), and
     `w_BYE_cf` disables the slot (`MBB_SET_USR_INT` HL=0, `src/system.asm:16–17`).
   **Acceptance:** confirm (by S9 and/or reasoning documented in Dev Notes) that the
   REPL's `^C`-at-column-0 exit releases the tick slot and that `BYE` remains the sole
   clean CCP exit; **correct the now-inaccurate `BYE` comment** at `src/system.asm:11–15`
   (which claims "Ctrl-C / BDOS warm-boot bypasses BYE … relies on the BIOS clearing the
   slot" — under fn-1 input `^C` no longer triggers a BDOS warm-boot, so `(EDIT)`'s
   handler is the real path; comment-only, 0 binary). If the hazard cannot be *proven*
   closed for every CCP-exit path, document the residual gap honestly rather than
   claiming closure (`feedback_no_preexisting_discharge`).

**Operator-only-compile lock (FR24) — standing constraint, not a new AC:** this story
touches the input path, the `PAUSE` yield seam, and the diagnostic/exit paths; it must
add **no** background-task write to HERE/LATEST/wordlist/triple. The redefine step in
AC5(a) is an **operator** activity — the background task still executes pre-compiled words
only.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev Notes.
      **Do not inherit the figure below** — re-`wc -c` from an actual clean rebuild at
      dev-pass start (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift).
      At story-drafting time (2026-07-01) the committed build artifact measured
      **30,381 B** (HEAD = `dabd44c`); the dev-pass baseline may differ if commits have
      landed since.
- [x] Capture current `make test-repl` baseline pass count (the 0-FAIL floor, NFR-P6-5)
      and each Epic-24/25 single-feature target so the post-edit delta is provable:
      `test-repl-timer`, `test-repl-multitasker`, `-multitasker-key`, `-multitasker-delay`,
      `-multitasker-tasks`, `-multitasker-throw` (8), `-multitasker-bank` (6),
      `test-repl-banking` (57/0), `test-straddle-regression` (3/3),
      `lint-banking-probes`, `check-doc-sync`, `test-file-sanity`.

### Task 1 — `break_pending` flag + `Ctrl-\` recognition in the input path (AC1) — `src/multitasker.asm`, `src/io.asm`

- [x] Declare `break_pending: DB 0` in the fixed-memory scheduler-state block in
      `src/multitasker.asm` (alongside `current_tcb`/`sched_save`, `:29–38`, below the
      `ASSERT $ <= SLOT2_WINDOW_BASE` at `:495`) — `PAUSE` reads it and runs under any
      bank, so it must live below `$8000`. It is set/read by **normal code** now (not the
      ISR), so it does not need the timer's ISR-safe region. COLD zero-inits it (confirm
      whether the scheduler-state block is already zero-initialised at COLD, `src/antforth.asm`
      §8k; add an explicit zero if not — do not assume).
- [x] Add a `Ctrl-\` (0x1C) arm to `(EDIT)`'s special-char dispatch (`src/io.asm`, the
      chain that today branches `.edit_cr`/`.edit_lf`/`.edit_bs`/`.edit_etx`, `:305–353`).
      Mirror `.edit_etx` (`:343–353`): on `A == 0x1C`, set `break_pending` (a store of any
      non-zero flag value; no BDOS), **do not store the byte into the buffer**, and return
      `done = false` (BC = 0) so the line reader keeps reading — the break fires at the
      next yield, not by terminating the line. Preserve `DE=IP` (the surrounding `(EDIT)`
      code already saves/restores DE around `bdos_putchar`; the flag store touches none of
      the live registers, but keep to the existing discipline). Do **not** echo the 0x1C
      (or echo nothing visible) — match the quiet handling style of the other control arms.
- [x] Add a one-line note to the yield-instrumentation checklist (`src/io.asm:120–137`)
      recording that `Ctrl-\` in `(EDIT)` sets `break_pending` and that `PAUSE` is the
      break-consume point (so any future blocking input primitive that yields via PAUSE
      inherits the break automatically).

### Task 2 — Consume `break_pending` at the yield seam, non-operator only, raise `THROW -28` (AC1, AC3) — `src/multitasker.asm`

- [x] Add the break-consume check inside `PAUSE`, at the ring-selection seam
      (`src/multitasker.asm:118`, just before `.pause_walk`) — **after** steps 1–2 have
      saved the outgoing task's `{SP,IX,DE,BC}` + UA-subset to its TCB (so the running
      task's state is coherent for later inspection/recovery) and where `A`/`HL` are free.
      Test `break_pending`; if clear, fall into the normal AWAKE ring walk unchanged
      (byte-neutral common path).
- [x] **On a set flag, discriminate the running task (`current_tcb`, still the task that
      called PAUSE — the walk has not yet updated it) against `operator_tcb`** (the same
      2-byte LOW/HIGH compare `.throw_uncaught` uses, `src/exception.asm`):
      - running == **operator** → **leave `break_pending` set** and fall into the normal
        ring walk (`.pause_walk`), so control hands off to the misbehaving background task
        (AC3 non-operator rule);
      - running == **background task** → clear `break_pending`, then raise `THROW -28`:
        mirror the kernel-side raise convention used by `dict_overflow_throw`
        (`JP dict_overflow_throw` at `src/multitasker.asm:229`) — load throw code `-28` and
        jump to the THROW kernel entry so the running (background) task's context unwinds
        through `.throw_uncaught`, which **already** (Story 25.6) prints `task N: error -28`
        + SUSPEND + operator resume. **Do NOT re-implement suspend/resume or the `task N:`
        notice — reuse the 25.6 path verbatim.** `current_tcb` = the background task at the
        raise, so `.throw_uncaught`'s `current_tcb ≠ operator_tcb` test takes the background
        arm automatically.
- [x] Confirm `KEY` (`src/io.asm:183`) and `(DELAY)` (`src/timer.asm:140`) inherit the
      break-consume for free (both route through `w_PAUSE_cf`) — **no new bytes** at those
      seams; the AC's "`PAUSE`/`KEY`/`DELAY`" is satisfied by the single PAUSE check.
- [x] Register/contract care: the consume sits where PAUSE has already stashed `BC`/`DE`;
      `A`/`HL` are free (the ring walk uses only those). The raise path is terminal (`JP`
      into THROW → wholesale SP reset) so it needn't preserve the PAUSE resume tail — but
      it MUST fire only *after* steps 1–2 saved the outgoing context, or a later
      inspect/recover of the broken task reads torn state.

### Task 3 — Probes: break path + documented stall (AC5) — `tests/` + `Makefile`

- [x] **Break-path probe (AC5a).** In `tests/multitasker_throw_tests.fth` (or a new
      `tests/multitasker_break_tests.fth`): define a background task that yields in a loop,
      `TASK DUP CONSTANT` its handle + `ACTIVATE`; then the Makefile recipe injects the
      real `Ctrl-\` byte into the piped input (`printf '\034\r'`) followed by an explicit
      interpret-level `PAUSE` line to hand off deterministically, then `.TASKS` and a
      runtime witness. Assert: `--present 'task 1: error -28'`, the `SUSPENDED` `.TASKS`
      row, the operator alive (runtime token), and a redefine + re-`ACTIVATE` recovery
      (`PASS: break-recovers`, reuse the 25.6 `_recov` shape). Emit `PASS: break-yielding-task`.
- [x] **Documented-stall probe (AC5b).** Demonstrate the honest reset-required case: a
      never-yielding form is not broken by `Ctrl-\`. Use a bounded, fail-loud construction
      (a short counted loop with no PAUSE, or a timeout witness) proving "no yield → no
      operator turn → flag never consumed → no break", so the doc's claim (AC4/AC2) is
      backed by observed behaviour. Prefer a form that terminates deterministically under
      `PROBE_TIMEOUT` — do **not** ship a genuinely infinite loop in CI. Emit
      `PASS: break-nonyield-stalls` (or a documented timeout witness).
- [x] Wire both into a Makefile target (extend `test-repl-multitasker-throw`, or add
      `test-repl-multitasker-break` mirroring the 25.6 recipe at `Makefile:348–357`):
      `sed 's/$$/\r/'` line feed + the `printf '\034\r'` injection at the right point +
      `BYE\r\n`, `timeout $(PROBE_TIMEOUT)`, fail-loud on `rc==124`, verdicts via
      `tests/assert_verdicts.sh --present`. Keep all existing assertions (regression
      floor). Guard TIB ≤128 chars (NFR-P6-16/-17) and the `$8000` straddle (interpret-level
      `'`, printed witnesses — `feedback_banking_probe_straddle_halt`).

### Task 4 — Documentation + warm-boot verify + close-out (AC2, AC4, AC6)

- [x] **Starvation-model + break-path doc (AC4, AC2).** Extend the multitasking prose in
      `docs/throw-codes.md` (`:83–98` block or a sibling section) per AC4. Add `-28`
      "user interrupt" to the throw-codes coverage table (`docs/throw-codes.md:137`,
      currently "no") as **done — Story 25.7**, pointing at the `Ctrl-\`→`(EDIT)`→
      `break_pending`→PAUSE-consume path.
- [x] **Warm-boot verify + comment fix (AC6).** Correct the stale `BYE` comment
      (`src/system.asm:11–15`) to reflect that under fn-1 input `^C`-at-column-0 routes
      through `(EDIT)`'s `.edit_etx` → `w_BYE_cf` (slot release), so the tick ISR is not
      left live on the interactive exit; document any residual non-`BYE` CCP-exit path
      honestly (comment-only, 0 binary). Do **not** add a fn-6/CONIN input rewrite — the
      `Ctrl-\` design uses the existing fn-1 path.
- [x] Re-`wc -c build/antforth.com`; record the delta vs the pre-edit baseline in Dev
      Notes with the per-component itemisation reconciled against the estimate (B.2 —
      itemise any variance, do not "accept" silently, `feedback_no_preexisting_discharge`).
- [x] Post the **S9 hardware-smoke recipe in the closing chat message** (not only in Dev
      Notes — STRONG operator preference, `feedback_post_hw_smoke_steps_at_review`): on
      real CP/M 2.2 / MicroBeast over the serial TTY, `ACTIVATE` a background task that
      loops with a `PAUSE`/`DELAY`, send `Ctrl-\`, confirm `task N: error -28` prints and
      the `ok` prompt returns responsive with `.TASKS` showing the task `SUSPENDED`;
      redefine + re-`ACTIVATE` recovers it; confirm pressing an **arrow key does not
      break** anything (the ESC-prefix safety); a genuinely non-yielding loop does **not**
      break (documented stall); and after a `^C` exit, load a larger program and confirm
      no stale-ISR crash (AC6).

## Dev Notes

### The single most important thing to understand about this story

**The break is a `THROW`, the detection is in-band, and the hard part (suspend/resume/
notice) already shipped in Story 25.6.** The net-new kernel work is small and additive:
1. a `break_pending` flag in fixed memory (Task 1);
2. `(EDIT)` recognising `Ctrl-\` (0x1C) and setting the flag — a new arm on the existing
   special-char dispatch, right next to the `^C` handler (Task 1);
3. `PAUSE` consuming the flag — **only for a non-operator running task** — and raising
   `THROW -28` (Task 2), which funnels straight into the Story-25.6 `.throw_uncaught`
   discriminator that already prints `task N: error <n>`, SUSPENDs the task, and resumes
   the operator.

Do **not** re-architect suspend/resume, re-order the `.throw_uncaught` register tail, or
duplicate the `task N:` notice. The cooperative model already contains the non-yielding
stall for free — AC2 is a *documentation + probe* deliverable over existing behaviour.

### Why `Ctrl-\` in-band (and not the ISR / not ESC) — the ratified design

- **Serial TTY reality (operator, 2026-07-01):** the operator works over a serial line,
  not the MicroBeast's attached keyboard. An ISR keyboard-port scan (AD-P6-6's literal
  mechanism) is therefore useless — there is no local keypress to scan; the break must be
  an in-band byte. This is a conscious, operator-ratified substitution of AD-P6-6's
  *setter* (ISR-poll → in-band `(EDIT)` recognition); the *flag + PAUSE-consume + `THROW
  -28`* half of AD-P6-6 is unchanged. It also dissolves the whole "no ISR-safe keyboard
  read / no known hardware port" problem — there is no ISR change at all.
- **`Ctrl-\` (0x1C), not ESC:** ESC (0x1B) is the lead byte of terminal escape sequences
  (left-arrow = `ESC [ D` / `ESC O D` / `ESC D`), so a lone-ESC break would false-trigger
  on every arrow key. `Ctrl-\` is a single byte, never an escape-sequence prefix, and is
  the traditional Unix-tty "quit" key — one `CP 0x1C`, zero disambiguation state, robust
  against serial latency. (`^C`/0x03 was unavailable — it is already the REPL exit-to-CP/M
  key via `.edit_etx`→`BYE`.)
- **Non-operator-only break is required, not optional:** the operator is the task that
  *reads* the byte, so if PAUSE broke "whichever task is running," it would break the
  operator (reset-to-prompt), not the runaway. Having the operator leave the flag set and
  yield makes the break land deterministically on the misbehaving background task. (This
  settles what the draft flagged as OQ#2.)

### Emulator testability — the real byte, no stand-in

Because detection is in-band, the REPL probe injects the **actual `0x1C` byte** into piped
stdin (`printf '\034'`), so the emulator exercises the *same* consume→`THROW -28` path that
silicon does — a genuine end-to-end test, not a structure-only stand-in (contrast the
Phase-4 hardware-only patterns). Deterministic hand-off: after the operator reads `Ctrl-\`
(sets the flag) and interprets an explicit `PAUSE`, the non-operator rule leaves the flag
set and switches to the background task, whose next yield consumes it and raises the break.
S9 confirms the identical path over the real serial TTY (the only thing silicon adds is the
physical `Ctrl-\` keystroke and the arrow-key-safety check).

### Byte-budget estimate (per-component itemisation — B.2 / Lesson 13.5-C)

Independent Z80 opcode itemisation of the binary-affecting changes; **not** derived from any
prior story (the downstream `THROW -28` handler is the reused 25.6 code and adds 0 bytes
here):

| Component | Opcodes | Bytes |
|---|---|---|
| `break_pending: DB 0` (fixed scheduler-state cell) | data | 1 |
| COLD zero-init of `break_pending` (if the block is not already zero-initialised) | ~1 op | ~0–4 |
| `(EDIT)` `Ctrl-\` arm: dispatch `CP 0x1C`/`JR NZ` (4) + set flag (`LD A,-1`/`LD (break_pending),A` = 5) + `done=false`/`NEXT` reuse (~2) | ~4 ops | ~10–14 |
| PAUSE consume: `LD A,(break_pending)`/`OR A`/`JR Z,walk` | 3 ops | ~6 |
| PAUSE operator discriminate: `LD HL,(current_tcb)` + `LD A,L`/`CP LOW operator_tcb`/`JR NZ` + `LD A,H`/`CP HIGH operator_tcb`/`JR Z,walk` (operator → leave flag, walk) | ~7 ops | ~11 |
| PAUSE raise (background): clear (`XOR A`/`LD (break_pending),A`) + `LD BC,-28` + `JP <throw kernel entry>` | 4 ops | ~9 |
| **Per-component total** | | **~37–45** |

Apply the kernel register-juggle margin (~×1.2, no LDIR here): **budget ≈ 35–55 B.** Docs,
comment fixes, probes, and the warm-boot verify are 0 binary. If the dev-pass lands
materially outside this envelope, itemise the variance in Dev Notes (do not "accept"
silently).

### Register / register-contract notes

- **`(EDIT)` `Ctrl-\` arm:** runs in normal (non-ISR) context; `(EDIT)` already saves/
  restores `DE=IP` around its `bdos_putchar` calls. The flag store is a plain
  `LD (break_pending),A` — touches no live register beyond `A` — but keep to the existing
  arm discipline (return via the same `done`/`NEXT` tail as `.edit_bs_done`).
- **PAUSE consume seam:** place the check **after** steps 1–2 (outgoing context saved) and
  **before** step 3 (`.pause_walk`), so `current_tcb` still points at the running task for
  the operator-vs-background compare; `A`/`HL` are free there. The raise is terminal (`JP`
  into THROW → wholesale SP reset), so it needn't preserve PAUSE's resume tail.
- **General multitasker rule (binds every other word this story touches):** normal task
  words preserve `DE=IP` (PAUSE is the sole exception); depth guards/`DEPTH` use per-task
  `sp_base` which PAUSE swaps (`project_multitasker_pause_register_contract`).

### Stale-premise flags carried into the dev-pass

1. The 24.1 warm-boot follow-up (epics 356–367) says REPL input is BDOS **fn 10** — it is
   **fn 1/fn 11** since Story 25.2, and `Ctrl-\` uses that same fn-1 path. So its "switch
   input to fn 6 / CONIN" prescription is superseded — do **not** implement it (AC6).
2. The `BYE` comment (`src/system.asm:11–15`) claims "Ctrl-C / BDOS warm-boot bypasses BYE
   … relies on the BIOS clearing the slot" — inaccurate under fn-1 input (`^C` is a plain
   char handled by `(EDIT)`'s `.edit_etx` → `w_BYE_cf`). Correct it (AC6).
3. The architecture Yield-Instrumentation Patterns list (architecture ~line 539–540) still
   lists `EMIT (per-emit yield)`, contradicting AD-P6-6's authoritative "EMIT does NOT
   yield." Not this story's fix; do not propagate it.
4. AD-P6-6's literal setter is "the 64 Hz ISR polls for a break key." This story
   *deliberately deviates* to in-band `Ctrl-\` per the operator (serial-TTY reality);
   flag + consume + `THROW -28` are unchanged. **The deviation is already filed as an
   erratum in AD-P6-6** (`architecture.md`, "Erratum — the setter is in-band, not the
   ISR"), so the doc and code no longer disagree — implement to the erratum, not the
   original ISR-poll paragraph.

### Project Structure Notes

- **Kernel changes:** `src/io.asm` (`Ctrl-\` arm in `(EDIT)` + checklist note — Task 1),
  `src/multitasker.asm` (`break_pending` cell + PAUSE consume/discriminate/raise —
  Tasks 1–2). `src/system.asm` comment-only (AC6). **No ISR change** (`src/timer.asm`
  untouched), **no new module.** The downstream break handler is the unchanged Story-25.6
  `src/exception.asm` `.throw_uncaught` — do not touch it.
- **Tests:** `tests/multitasker_throw_tests.fth` (reuse `_recov`) or a new
  `tests/multitasker_break_tests.fth` + a Makefile target. Keep every existing assertion
  (regression floor).
- **Docs:** `docs/throw-codes.md` (starvation/break prose + `-28` row).
- **Testing standard:** REPL-piped Forth through the threading model only
  (`make test-repl`, NFR-P6-16) — no raw BDOS/asm-thread hacks (`feedback_testing_rules`,
  `feedback_repl_tests_preferred`). Interpret-level `'` orchestration; printed witnesses;
  probe lines ≤128 chars; dodge the `$8000` straddle-halt.
- **Comment discipline:** what + why-not-obvious, never story/CR/date provenance in source
  (`feedback_source_comment_discipline`).

### References

- Story spec: [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story 25.7] (lines 341–354); warm-boot follow-up (356–367)
- Requirements: [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md] FR22 (393), FR20 (391), FR21 (392), NFR-P6-7 (427–428), NFR-P6-8 (429–430), NFR-P6-14 (450–451); Journey 2 (208–217); User Success (120–122)
- Architecture: [Source: _bmad-output/planning-artifacts/architecture.md] AD-P6-6 break_pending + consume-at-yield (388–411; **setter deviates to in-band per operator — see Dev Notes flag #4**), AD-P6-3 starvation/round-robin (324–342, esp. 338–340), AD-P6-4 exception isolation (344–361)
- Input path (the break-detection site): [Source: src/io.asm] `(EDIT)` special-char dispatch `.edit_cr`/`.edit_lf`/`.edit_bs`/`.edit_etx` (305–353, `^C` pattern to mirror at 343–353), yield checklist (120–137), `KEY` + PAUSE cell (174–188), `(LINE)`/`ACCEPT` (356–406); `QUERY` [Source: src/outer_interpreter.asm] (146–162)
- Scheduler / consume seam: [Source: src/multitasker.asm] `PAUSE` (85–188), ring walk `.pause_walk` (118–134), fixed scheduler-state block + `break_pending` home (29–38), `sched_resume_current` (140–188), register contract (11–22), kernel-raise precedent `dict_overflow_throw` (229), state ASSERT (495)
- (DELAY) yield seam: [Source: src/timer.asm] `(DELAY)` PAUSE-first loop (135–148, PAUSE cell 140) — inherits the break for free
- Break code + reuse: [Source: docs/throw-codes.md] `-28` "user interrupt" (137), uncaught-THROW diagnostic + "when does a background fault appear?" prose (67–98)
- Uncaught-THROW handler (reused, do not modify): [Source: src/exception.asm] `.throw_uncaught` (per Story 25.6: 538–611) — `task N:` notice + SUSPEND + operator resume
- BYE slot release: [Source: src/system.asm] `w_BYE_cf` (8–20, slot release 16–17, stale comment 11–15)
- Prior story (context continuity): [Source: _bmad-output/implementation-artifacts/25-6-background-task-exception-isolation.md]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8)

### Debug Log References

- Initial `.edit_break` placement (between `.edit_lf` and `.edit_bs`) failed the
  build with two `[JR] Target out of range` errors (`io.asm` printable-path +133,
  `.edit_bs` -137): inserting ~13 bytes mid-dispatch-chain over-stretched existing
  short jumps. Fixed by relocating the handler to *after* `.edit_etx` (past its
  non-returning `JP w_BYE_cf`), so no internal `JR` span grows; the forward
  `JR Z, .edit_break` dispatch reaches it fine.

### Completion Notes List

- **Net-new kernel work is small and additive, as scoped.** (1) `break_pending`
  fixed-memory cell in the scheduler-state block (`multitasker.asm`); (2) a
  `Ctrl-\` (0x1C) arm on `(EDIT)`'s special-char dispatch (`io.asm`) that sets the
  flag, stores nothing, doesn't echo, returns `done=false`; (3) a break-consume at
  `PAUSE`'s ring-selection seam (`multitasker.asm`) that, on a **background** running
  task, clears the flag and `JP w_THROW_cf.kernel_entry` with `BC = -28`, funnelling
  straight into the **unchanged** Story-25.6 `.throw_uncaught` reroute (`task N:
  error -28` + SUSPEND + operator resume). On an **operator** running task it leaves
  the flag set and takes the normal ring walk (non-operator-only break). `exception.asm`
  and `timer.asm` were **not** touched; no new module.
- **`THROW_USER_INTERRUPT EQU -28`** added to `constants.asm` (ANS §9.3.5 "user
  interrupt"). Per the byte budget, **no** row was added to the asm `throw_desc_table`
  — the diagnostic prints `task 1: error -28` (no description suffix, exactly like the
  25.6 `-99` probe). AC4's coverage-table update is the markdown doc only.
- **`KEY`/`(DELAY)` inherit the break for free** — both route through `w_PAUSE_cf`, so
  the single PAUSE-seam consume satisfies the AC's "PAUSE/KEY/DELAY" with zero extra
  bytes at those words.
- **Probe drives the REAL 0x1C byte end-to-end.** `tests/multitasker_break_tests.fth`
  + `test-repl-multitasker-break`: the Makefile `awk` replaces each `@@BREAK@@` marker
  line with a lone `0x1C`, `sed` appends the CR, so `(EDIT)` reads the actual break
  byte — the same consume→`THROW -28` path silicon runs. Raw output confirmed: exactly
  one `task 1: error -28`, `.TASKS` renders `   0 * AWAKE` / `   1   SUSPENDED`, the
  operator survives stack-clean, and redefine + re-`ACTIVATE` recovers. The AC5b
  injection produced **no** second break — the flag latched un-consumed absent a
  yielding background task, witnessing the honest non-yielding stall mechanism.
- **AC5b is a bounded, honest proxy.** A genuinely non-yielding task cannot be run in
  CI (it would hang, and even a *finite* non-yielding task would be broken at its
  `task_exit` PAUSE, so it is not a faithful stand-in). The probe instead witnesses the
  *mechanism*: with the sole background task ASLEEP, a set `break_pending` is not
  consumed by non-yielding operator work — "no yield point → flag never consumed → no
  break." The doc (`throw-codes.md §a.2`) states the true infinite-stall = reset-required
  limit plainly.
- **Known benign edge (documented, not guarded):** if the operator sends `Ctrl-\` with
  **no** background task in the ring, the flag latches (operator yields leave it set,
  the length-1 walk returns to self). It fires only when a background task later reaches
  a yield. This matches the ratified design ("operator leaves the flag set and yields");
  `Ctrl-\` means "break something," and in normal use it is sent at a runaway. Surfaced
  here per `feedback_no_preexisting_discharge`; not a correctness defect.
- **AC6 warm-boot verified (0 binary).** Under the fn-1/fn-11 yielding reader (Story
  25.2), `^C` at column 0 is a plain char caught by `(EDIT)`'s `.edit_etx` → `JP
  w_BYE_cf`, which releases the 64 Hz tick slot (`MBB_SET_USR_INT` HL=0). BYE is thus
  the **sole clean CCP exit** (explicit `BYE` or interactive `^C`-at-col-0); neither
  leaves a stale ISR live in the freed TPA. The stale fn-10 premise was **not**
  implemented; the inaccurate `BYE` comment (`src/system.asm`) was corrected.
- **Byte delta: +49 B** (30,381 → 30,430; HEAD baseline `dabd44c`/`51a9bbd`, clean
  rebuild). Reconciles with the story estimate of **35–55 B** (per-component table
  below); `system.asm` comment + `throw-codes.md` + probe + Makefile are 0 binary.

  | Component | Bytes |
  |---|---|
  | `break_pending: DB 0` | 1 |
  | `(EDIT)` `Ctrl-\` dispatch arm + handler (`CP`/`JR` + `LD A,-1`/`LD (),A` + `LD BC,0`/`NEXT`) | ~14 |
  | PAUSE break-consume: `LD A,()`/`OR A`/`JR Z` + operator discriminate (`LD HL,()`, `LD A,L`/`CP`/`JR NZ`, `LD A,H`/`CP`/`JR Z`) + raise (`XOR A`/`LD (),A`/`LD BC,-28`/`JP`) + relocated `.pause_walk_init: LD HL,()` | ~34 |
  | **Total** | **~49** ✓ |

  No COLD zero-init byte was needed: `break_pending` is image-zero at load like the
  adjacent `current_tcb`/`sched_save` cells, and there is no re-COLD without a fresh
  `.COM` load.
- **S9 hardware smoke: PASS on real MicroBeast over the serial TTY** (2026-07-01,
  `beastty-20260701-115008.bin`). Confirmed on silicon, all core FR22 paths:
  - `: SPINNER BEGIN PAUSE 0 UNTIL ;` + `ACTIVATE`, then a physical **`Ctrl-\`**
    (correctly **not echoed**) → `task 1: error -28` fired — no explicit `PAUSE` needed,
    the prompt-idle yielding reader handed off naturally (matches `throw-codes.md §a.1`);
  - operator stayed responsive — `.TASKS` rendered `   0 * AWAKE` / `   1   SUSPENDED`;
  - **recovery**: `: SPINNER 42 . ;` redefine + re-`ACTIVATE` + `PAUSE` → printed `42`;
  - **honest stall**: a genuinely non-yielding `: HOG BEGIN 0 UNTIL ;` + `ACTIVATE PAUSE`
    wedged the ring — the terminal went dead and **`Ctrl-C` did not recover it** (nor would
    `Ctrl-\`): both keys are read by the operator's `(EDIT)`, which never gets a turn while
    HOG monopolises the CPU. Only a hardware reset recovers = the documented reset-required
    stall (AC2), confirmed on silicon. Doc §a.2 updated to state this explicitly (no key at
    all is read during a non-yielding stall, not even the exit key).
  - Not exercised in this capture: arrow-key ESC-safety and the AC6 stale-ISR-after-`^C`
    reload (AC6 closed by reasoning — the `^C`→`(EDIT)`→`BYE` slot-release path is
    unchanged and already shipped). Both remain sound; no silicon regression observed.

### File List

- `src/constants.asm` — `THROW_USER_INTERRUPT EQU -28`
- `src/multitasker.asm` — `break_pending` cell + PAUSE break-consume/discriminate/raise
- `src/io.asm` — `Ctrl-\` arm in `(EDIT)`, `.edit_break` handler, yield-checklist note
- `src/system.asm` — corrected `BYE` warm-boot comment (comment-only, 0 binary)
- `docs/throw-codes.md` — §(a.2) cooperative-starvation + keyboard-break prose; `-28` coverage row
- `tests/multitasker_break_tests.fth` — new break-path + documented-stall probe (real 0x1C injection)
- `Makefile` — `test-repl-multitasker-break` target + `.PHONY`

### Change Log

- 2026-07-01 — Story 25.7 implemented: in-band `Ctrl-\` (0x1C) keyboard break —
  `(EDIT)` sets `break_pending`, `PAUSE` consumes it (non-operator only) and raises
  `THROW -28` into the Story-25.6 uncaught reroute; documented non-yielding stall.
  +49 B (35–55 B envelope). All gates green (test-repl 1005/0, timer 9/0, multitasker
  5/5/6/8/8 + break 7/0 + bank 6/0, banking 57/0, straddle 3/3, lint/doc-sync/file-sanity).
  Status → review.
- 2026-07-01 — S9 hardware smoke PASS on real MicroBeast over serial TTY
  (`beastty-20260701-115008.bin`): physical `Ctrl-\` broke a yielding SPINNER task
  (`task 1: error -28`, `.TASKS` SUSPENDED), operator survived, redefine + re-`ACTIVATE`
  recovered (printed `42`), and a non-yielding `HOG` produced the documented
  reset-required stall. Current kernel is byte-identical to the silicon-tested build.
- 2026-07-01 — Code-review fixes (high-effort review, 4 findings). **Fixed (code):**
  a `break_pending` set while no breakable task was AWAKE latched and would ambush the
  NEXT task activated later with a spurious `-28`; `ACTIVATE`/`WAKE` now drain the latch
  (a task entering the rotation is never the target of a break aimed before it existed).
  New regression probe `break-no-ambush` (AC5c, reuses AC5b's latched flag) — verified it
  FAILS without the drain. **Fixed (docs, `throw-codes.md §a.2`):** removed the overclaimed
  "lands deterministically on the runaway" (with >1 background task the break takes the first
  to yield); documented that an active `CATCH` in the target intercepts the `-28` (genuine
  THROW — a CATCH-guarded loop is unbreakable); corrected the never-yielding example
  `: SPIN BEGIN AGAIN ;` → `BEGIN 0 UNTIL ;` (`AGAIN` is undefined here). +8 B (30,430 →
  30,438). Gates: break probe 8/8, sibling multitasker probes 0 fail, doc-sync 0 drift.
  **Binary is NO LONGER byte-identical to the silicon-tested build** — the drain touches
  the `ACTIVATE`/`WAKE` recovery path the S9 smoke exercised; a light re-smoke of
  break-then-recover is advisable (behavior change is emulator-verified, low risk).

## Open Questions (all resolved with the operator, 2026-07-01 — no longer blocking)

1. **Break-key read mechanism — RESOLVED.** In-band, not the ISR: the operator is on a
   serial TTY, so an ISR keyboard-port scan is useless. Detect the break byte in `(EDIT)`
   (the existing console-input path), no ISR change, no hardware port. (Dissolved the
   former blocker; deliberate, operator-ratified deviation from AD-P6-6's ISR-poll setter
   — flag + consume + `THROW -28` unchanged.)
2. **Break key — RESOLVED: `Ctrl-\` (0x1C).** Single byte, not an escape-sequence prefix
   (arrow keys `ESC [ D` etc. are safe), traditional Unix "quit" semantics. ESC rejected
   (prefix-collision with cursor keys); `^C` unavailable (REPL exit key).
3. **Break-target semantics — RESOLVED: only a non-operator task.** The operator reads the
   byte, so PAUSE leaves the flag set on an operator yield and hands off to the runaway
   background task, which consumes it — deterministic break of the misbehaving task.
4. **Emulator test seam — RESOLVED: inject the real `0x1C` byte.** No software stand-in;
   the probe feeds `printf '\034'` into piped stdin and exercises the true in-band path.
5. **AC6 (warm-boot) scope — RESOLVED: verify + comment-fix only** (0 binary). The
   follow-up's fn-10 premise is stale and `Ctrl-\` reuses the fn-1 path, so no fn-6/CONIN
   input rewrite; `^C`→`(EDIT)`→`BYE` slot release already exists.
