# Story 25.2: KEY-hooked REPL multitasking (input-only yield)

Status: done

> **Epic 25 bring-up step 2 — the live prompt.** Story 25.1 landed the scheduler
> spine (`PAUSE`/ring/TCB/`TASK`/`ACTIVATE`); this story makes the operator's REPL
> *yield while it waits for input*, so a background task keeps running while the
> `ok>` prompt is live. It is the "KEY-hook → live REPL" milestone of the
> architecture's fixed-memory-switch-first order (AD-P6 §"Implementation
> sequence", `architecture.md:443`). No banking, no timer-driven yielding, no
> exception isolation — input-only yield, single bank. Later stories ride this:
> yielding `DELAY` (25.3), `.TASKS`/`WAKE`/`SLEEP` (25.4), per-bank switch (25.5),
> exception isolation (25.6), keyboard break + fn-6/Ctrl-C input overhaul (25.7),
> headline demo (25.8).

## Story

As the operator,
I want the prompt to stay responsive while a background task runs,
so that I can keep typing and evaluating Forth as the task works underneath.

## Acceptance Criteria

(Verbatim from `epics-phase6-epics-24-26.md` Story 25.2, lines 265–278; BDD form.)

1. **AC1 — input words yield while waiting (FR10, FR11, NFR-P6-3).**
   **Given** a working scheduler (Story 25.1) with a background task activated,
   **When** the REPL waits for input in `KEY` / `KEY?` / `ACCEPT`,
   **Then** those words call `PAUSE` inside their wait loop, so the background
   task runs between keystrokes (FR10, FR11) and operator keystrokes
   echo/evaluate without perceptible lag (NFR-P6-3).

2. **AC2 — `EMIT` does NOT yield (FR12, AD-P6-6).**
   `EMIT` does **not** yield, so concurrent task output is not interleaved
   char-by-char (clean output; FR12). (Output-side yielding is explicitly
   rejected — validation F2.)

3. **AC3 — yield-instrumentation checklist documented.**
   The yield-instrumentation checklist (`KEY` / `KEY?` / `ACCEPT`) is documented;
   any future blocking input primitive must be added to it.

4. **AC4 — live-prompt probe + binary delta (NFR-P6-3, NFR-P6-5/-16/-17).**
   A probe demonstrates a background counter task advancing across several
   operator commands at the live prompt; S9 hardware smoke confirms
   responsiveness; binary delta recorded.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev
      Notes. **Do not inherit the figure below** — re-`wc -c` from the actual
      current build artifact (B.3 / Lesson 13.5-F). At story-drafting time
      (2026-06-29) the committed tree measured **29,889 B** (Story 25.1 close);
      the dev-pass baseline may differ if commits have landed since.
- [x] Capture current `make test-repl` baseline pass count (the 0-FAIL floor,
      NFR-P6-5) — including `test-repl-timer` (9/9) and `test-repl-multitasker`
      (5/5 from 25.1).

### Task 1 — Decide and pin the input-yield mechanism (AC1) — design gate

- [x] **Resolve Open Question Q1 (line-reader depth) BEFORE coding** — it sets the
      scope of every task below. The two paths and the recommendation are in Dev
      Notes "The load-bearing problem: where the REPL actually blocks". Record the
      project-lead decision in **Dev Agent Record → Open-Question resolutions**.
- [x] Confirm the **PAUSE-as-thread** constraint (Dev Notes "Why KEY must become a
      thread, not a CALL"): the threaded `PAUSE` (`w_PAUSE_cf`, ends in `NEXT`)
      cannot be `CALL`ed from a DEFCODE leaf; any word that yields mid-wait must be
      a DEFWORD thread that *includes* `PAUSE` as a thread cell (the `w_INTERPRET`
      BRANCH/?BRANCH pattern, `outer_interpreter.asm:174`), or jump through a
      yield seam that itself ends in `NEXT`.

### Task 2 — `KEY` yields via a non-blocking poll loop (AC1) — `io.asm`

- [x] Restructure `KEY ( -- char )` so it **never sits inside blocking BDOS fn 1
      while a char is absent**. Wait loop: poll non-blocking status (BDOS fn 11,
      the existing `KEY?` primitive), and **while no char is ready, `PAUSE`**, then
      re-test; once a char is ready, read it (BDOS fn 1 returns immediately) and
      push it. `PAUSE` goes *inside* the loop, *before* re-testing the condition
      (AD-P6-6, `architecture.md:396`).
- [x] Implement `KEY` as a **DEFWORD thread** (so it can thread `PAUSE`), or factor
      a raw-read primitive (`(KEY)` = the current fn-1 body) + reuse `KEY?` and
      build the loop in a thread. Keep the raw-read primitive available for the
      line reader (Task 4). Preserve `KEY`'s stack effect `( -- char )` and the
      `B=0` high-byte zero-extension (`io.asm:160-161`).
- [x] **Single-task identity (FR5):** with a length-1 ring, `PAUSE` is a walk-to-
      self no-op, so `KEY` busy-polls fn 11 until a char then reads — observably
      identical result (same char) to the old blocking `KEY`. Note the
      execution-shape change (spin-poll vs BDOS block) in Dev Notes; it is
      result-identical, which is what NFR-P6-12 requires.

### Task 3 — `KEY?` reconciliation + `EMIT` stays no-yield (AC2, AC3) — `io.asm`

- [x] `KEY?` ( -- flag ) is the **non-blocking poll** (BDOS fn 11) — it has no wait
      loop, so it gets **no `PAUSE`** (a status query must return immediately).
      Document the reconciliation in the checklist (Dev Notes "Yield checklist"):
      the AC text lists `KEY?` among the trio, but `KEY?` is non-blocking by
      definition and is the *poll primitive the yielders call*, not itself a
      yielder. (Flagged as Open Question Q3 — confirm this reading.)
- [x] **Verify `EMIT` is untouched** and does NOT call `PAUSE` (AC2 / F2). Add a
      one-line "// no yield — see AD-P6-6/F2" comment at `w_EMIT` so a future
      editor does not "helpfully" add a yield. `EMIT` stays DEFCODE fn 2.

### Task 4 — Make the REPL prompt yield: the line reader (AC1, AC4) — `outer_interpreter.asm` (+ `io.asm`)

> **This task is the heart of the story.** Instrumenting `KEY` alone does NOT make
> the *prompt* responsive: the REPL reads its line in `QUERY`
> (`outer_interpreter.asm:120`) via blocking BDOS fn 10 (`C_READSTR`), which reads
> a whole line atomically with no yield seam. While the operator sits at / types
> at the prompt, the operator task is frozen inside fn 10 and the background task
> makes no progress. AD-P6-6 (`architecture.md:394-395`) states the intended
> design: *"The REPL's input path becomes 'task 0 yields in `KEY`'."* Scope per Q1.

- [x] **(Per Q1 = recommended path)** Re-point the REPL line read so the operator
      task yields while awaiting input: replace `QUERY`'s atomic fn-10 read with a
      **char-by-char loop over the yielding `KEY`** (CR terminates the line;
      destructive backspace; echo each char), accumulating into `tib_buffer` and
      setting `#TIB` / `>IN` exactly as the current `QUERY` does
      (`outer_interpreter.asm:140-148`). Keep `QUERY`'s defensive canonical
      source-spec re-assert (`tib_addr`/`source_id`, `:150-162`) unchanged.
- [x] Apply the same yielding line reader to **`ACCEPT`** (`io.asm:116`) so user
      programs that read a line also yield (FR11). Resolve `ACCEPT`'s pre-existing
      `c-addr`-ignored deviation (`io.asm:113`, `:120`) per Q2 (honor `c-addr` in
      the rewrite, or preserve the tib-only behavior and document).
- [x] Use **raw single-char input via fn 11 (poll) + fn 1 (read)** for now. The
      switch to BDOS fn 6 / BIOS CONIN (raw, no-echo, break-aware) and the Ctrl-C
      warm-boot slot-release are **Story 25.7** (see the 25.7 folded note,
      `epics-phase6-epics-24-26.md:356-367`) — do NOT pull them forward here.
- [x] Line-editing fidelity is **minimal** this story (CR-terminate + destructive
      backspace + echo) per Q4; full BDOS fn-10 editing parity is not a 25.2 goal.
      Document any editing-behavior change vs the old fn-10 prompt.

### Task 5 — Document the yield checklist + cooperative-input model (AC3) — source + `docs/`

- [x] Add the **yield-instrumentation checklist** as a comment block at the input
      section of `io.asm` (and/or `docs/register-conventions.md` if that is where
      Hard Rules live): the blocking *input* primitives that yield (`KEY`, the line
      reader behind `ACCEPT`/`QUERY`), the non-blocking poll (`KEY?`), and the
      explicit no-yield output rule (`EMIT`). State the standing rule: **any new
      blocking input primitive MUST be added to this list or it starves the ring**
      (AD-P6-6, `architecture.md:539-541`).
- [x] Comment discipline: what + why-not-obvious in source; provenance
      (story/CR/date) stays in git/story/ADR/memory
      (`feedback_source_comment_discipline`).

### Task 6 — Probe + Makefile wiring (AC4) — `tests/multitasker_tests.fth`, `Makefile`

- [x] Extend `tests/multitasker_tests.fth` (or a new `test-repl-multitasker-key`
      recipe) with a probe showing a **background counter task advancing across
      several operator commands at the live prompt** (NFR-P6-16). Because the
      emulator feed is a non-interactive pipe (no human keystroke timing), assert
      *structure*: e.g. drive several interpreted lines with an activated
      background counter and show the counter advanced by ≥1 between lines (proving
      the operator yielded in the line reader), plus the interpreter stays healthy
      (`1 2 3 + + .` = `6`) and the stack is clean. Wall-clock "no perceptible lag"
      is the **hardware S9** assertion, not the emulator's.
- [x] Add a `mt-emit-no-yield` style assertion that a background task's output does
      NOT interleave char-by-char with foreground `EMIT` (AC2) — e.g. a foreground
      multi-char `."` and a background printer do not shred each other's strings in
      the documented pattern.
- [x] **Reuse the Story 24.4 helper** `tests/assert_verdicts.sh --mode anchored`
      (column-0 `^PASS:` anchoring, 23.2 false-green defense) — do NOT re-derive
      the grep/`\r`/`xxd` block. Wrap the emulator pipe in the **Story 24.3
      fail-loud `timeout`** so a wedge is a loud FAIL, not a CI hang. Keep every
      probe line **≤ 128 chars** incl. `\` annotations
      (`feedback_tib_size_inline_comments`).
- [x] Run `make lint-banking-probes` / the straddle guard (Story 24.3). This probe
      does not mutate the bank window, but the kernel grows this story — re-check
      that late `banking_tests.fth` colon-body probes did not get pushed across
      `$8000` (the `feedback_banking_probe_straddle_halt` hazard that bit 25.1).
      If they did, fix the **probe** (hoist helpers to fixed memory / interpret-
      level), not the feature.
- [x] Full `make test` gate green; record the binary delta (`wc -c` after −
      before) in Dev Notes against the proposed envelope (Q5).

### S9 hardware smoke (post dev-pass — recipe in the close-out chat message)

- [x] On real CP/M 2.2 / MicroBeast: `TASK` a background counter, `' BG <task>
      ACTIVATE`, then sit at the `ok>` prompt and confirm the counter keeps
      advancing while you type / pause / evaluate — the prompt echoes and evaluates
      with no perceptible lag (NFR-P6-3), and the counter advanced while you were
      thinking at the prompt (proving the line reader yielded). Confirm `EMIT`
      output is not char-shredded by the background task (AC2). (Per the **STRONG**
      `feedback_post_hw_smoke_steps_at_review` commitment, post the exact recipe in
      the closing chat message, not only here.)

## Dev Notes

### Architecture provenance (read these first)

- **AD-P6-6** (blocking-primitive yield instrumentation + keyboard break) —
  `_bmad-output/planning-artifacts/architecture.md:388-411`. Plus the Step-5
  "blocking-word checklist is exhaustive and explicit" rule (`:539-541`) and the
  yield anti-patterns / register-contract patterns (`:488-591`).
- **Validation F1/F2** (`architecture.md:741-742`): F1 = keyboard break is an ISR
  `break_pending` flag consumed at the next yield (→ **25.7**, not here); F2 =
  **`EMIT` does NOT yield** (input-only). Both fold into AD-P6-6.
- The 5 Phase-6 locks + bring-up order live in `project_phase6_concurrency_direction`;
  the two load-bearing register/stack-base gotchas from 25.1 live in
  `project_multitasker_pause_register_contract` (apply to every new word here).

### The load-bearing problem: where the REPL actually blocks

The epics AC names `KEY`/`KEY?`/`ACCEPT`, but **the REPL prompt does not read
through any of them.** `QUIT` reads each line via `QUERY`
(`outer_interpreter.asm:120-167`), which calls **BDOS fn 10 (`C_READSTR`)** — an
*atomic whole-line* read with no internal yield seam. Likewise `ACCEPT`
(`io.asm:116-146`) uses fn 10. While the cursor sits at `ok>` waiting for the
operator to type (which is most of the wall-clock time in the headline demo), the
operator task is parked inside fn 10 and **the background task is frozen** — the
traffic light would stop whenever you stop typing. Cooperative scheduling only
advances other tasks at a `PAUSE`, and there is no `PAUSE` reachable from inside
BDOS fn 10.

So instrumenting `KEY` alone satisfies the AC's *letter* (user words that call
`KEY` will yield) but **not** FR10 / the headline ("continue at the prompt while
background tasks run"). To make the *prompt* live, the line reader behind `QUERY`
(and `ACCEPT`) must become a **char-by-char loop over the yielding `KEY`**, where
"no char yet → `PAUSE`" runs between keystrokes. This is exactly AD-P6-6's stated
design: *"The REPL's input path becomes 'task 0 yields in `KEY`'"*
(`architecture.md:394-395`). This is the headline of **Open Question Q1**.

### Why `KEY` must become a thread, not a CALL (the PAUSE-composition constraint)

`PAUSE` is `w_PAUSE_cf` — a DEFCODE word that **ends in `NEXT`** and swaps the
entire task register set (`multitasker.asm:82-157`). It is reached *through
threading*: the only legal entries are a thread cell (`DW w_PAUSE_cf`) or a
`JP w_PAUSE_cf` from a fragment that has already arranged the thread state (e.g.
`task_exit`, `:164-169`). You **cannot `CALL w_PAUSE_cf`** from inside a DEFCODE
leaf and expect to resume after the call — `PAUSE` does not `RET`; it `NEXT`s into
whatever the resumed task's IP points at. The current `KEY`/`ACCEPT` are DEFCODE
leaves ending in `NEXT`, so they cannot host an inline `PAUSE`.

**Resolution (recommended):** make the yielding words **DEFWORD threads** that
include `PAUSE` as a thread cell, looping with the `BRANCH`/`?BRANCH` manual-offset
pattern already used by `w_INTERPRET` (`outer_interpreter.asm:174-179`). Factor the
raw fn-1 read and the fn-11 poll as small DEFCODE primitives the thread calls:

```
: KEY   ( -- char )   BEGIN  KEY?  0= WHILE  PAUSE  REPEAT  (KEY) ;   \ shape, asm-threaded
```

where `(KEY)` is the current blocking-fn-1 body (immediate when a char is known
ready) and `KEY?` is the existing fn-11 poll. The line reader (`QUERY`/`ACCEPT`)
is a second DEFWORD thread that loops on this yielding `KEY`, handling CR /
backspace / echo. This composes cleanly and matches the kernel's existing
threaded-control idiom — no new yield-trampoline machinery.

### Register / TOS conventions (unchanged from 25.1)

- BC = TOS, DE = IP, IX = return stack, IY = UserArea (never reassigned), SP =
  data stack (`project_tos_in_register`; `register-conventions.md` Hard Rule #1).
- **25.1 gotcha #1 — preserve DE (=IP):** any new *non-PAUSE* CODE word that uses
  DE as scratch must stash/restore it (`sched_ip` precedent,
  `multitasker.asm:182`), or the operator's next `NEXT` runs a garbage IP →
  warm-boot. If `KEY`/line-reader stay as threads calling primitives, the
  primitives must each honor this. (`project_multitasker_pause_register_contract`.)
- **25.1 gotcha #2 — `sp_base` is per-task:** `PAUSE` already swaps the global
  `sp_base` to the running task's `t_sp_base` (`multitasker.asm:140-144`), so the
  depth guards are correct across a yield. Nothing extra needed here, but be aware
  a background task that calls `KEY` runs on its own `ps_area`.
- DEFCODE/DEFWORD skeletons: `macros.asm:66`/`:107`; `NEXT`: `macros.asm:32`. For
  any DEFWORD, `w_*_cf` via `EQU body-3 → JP DOCOL` (`feedback_defword_cf_label`).
- BDOS call hygiene: `BDOS_SAVE`/`BDOS_RESTORE` (`macros.asm:166,171`) preserve
  DE(IP)+BC(TOS) across a BDOS call (`io.asm` uses them throughout). The fn-1/fn-11
  primitives keep using these.

### Yield checklist (AC3 — the standing rule)

| Word | Blocking? | Yields? | Mechanism |
|---|---|---|---|
| `KEY` | yes (waits for a char) | **yes** | poll `KEY?` (fn 11); `PAUSE` while empty; then `(KEY)` fn-1 read |
| `KEY?` | no (status query) | **no** | the non-blocking poll the yielders call (fn 11) |
| `ACCEPT` | yes (waits for a line) | **yes** | char-loop over yielding `KEY` |
| `QUERY` (REPL line read) | yes (waits for a line) | **yes** | same char-loop over yielding `KEY` |
| `EMIT` | no (output) | **no** (F2) | clean concurrent output; never add a yield |

**Standing rule:** any *new* blocking **input** primitive MUST be added to this
list with a `PAUSE` in its wait loop, or it starves the ring (AD-P6-6). Output
primitives never yield (F2).

### Single-task behavior change (FR5 / NFR-P6-12)

With one task (length-1 ring), `PAUSE` walks to self (no-op), so the yielding
`KEY` becomes a **busy-poll** on fn 11 until a char arrives, then reads it — vs the
old blocking fn-1 wait. The *result* is identical (same char, same `#TIB`), which
is what NFR-P6-12 (user-visible behavior identical when no second task is active)
requires; the *execution shape* differs (spin-poll vs BDOS block — negligible on
an idle-waiting REPL). Record this as an accepted, documented behavior nuance, not
a regression. The `make test-repl` 1005/0 baseline must still pass 0 FAIL.

### Scope boundaries (explicitly deferred — do not implement here)

- ❌ **Keyboard break / `break_pending` / fn-6 / BIOS CONIN / Ctrl-C slot-release**
  → **Story 25.7** (the 25.7 folded note, `epics-phase6-epics-24-26.md:356-367`).
  25.2 stays on fn 11 (poll) + fn 1 (read). Do NOT switch input strategy here.
- ❌ **Yielding `DELAY`** → **Story 25.3** (Epic 24's `(DELAY)` busy-wait seam is
  untouched here).
- ❌ **`.TASKS` / `WAKE` / `SLEEP`** → **Story 25.4**.
- ❌ **Per-bank re-page on switch** → **Story 25.5** (`PAUSE` still saves/restores
  `current_bank` as a cell only).
- ❌ **Background-task exception isolation** → **Story 25.6**.
- ❌ Full BDOS-fn-10 line-editing parity (only minimal CR/backspace/echo here, Q4).

### Binary-size envelope (sprint-planning carry-forward F5 — proposed here)

Story 25.2 is mostly **rewiring existing input words into yielding threads** plus a
hand-rolled char line reader — new asm, not a cross-bank design substitution, so
the 2.4× Epic-17 multiplier does **not** apply (Epic 24 retro / 25.1 ruling).
Per-component itemisation (B.2 — no "mirrors prior arm"):

| Component | Est. bytes |
|---|---|
| `KEY` yielding thread (poll/`?BRANCH`/`PAUSE`/loop) + `(KEY)` raw primitive split | ~40–80 |
| Char line reader (loop over `KEY`, CR-terminate, backspace, echo, `#TIB`/`>IN`) | ~80–140 |
| Re-point `QUERY` to the line reader (+ keep canonical re-assert) | ~10–30 |
| `ACCEPT` rewrite onto the line reader (+ `c-addr` per Q2) | ~20–50 |
| Checklist comments / `EMIT` no-yield note | 0 (comments) |
| **Raw subtotal** | **~150–300** |
| **Register-juggle overshoot ×1.25** (`feedback_kernel_ldir_estimate_overshoot`) | **~190–375** |

**Proposed Story-25.2 envelope: ~190–375 B**, accept-with-rationale, no silent
bloat (NFR-P6-10). Record the actual delta at dev-pass close. *(If Q1 picks the
minimal "KEY-only, leave QUERY on fn 10" path, the envelope drops to ~50–120 B but
FR10/headline is not met — flag the trade explicitly.)*

### Testing standards (S2 / NFR-P6-16/-17 + the 24.3/24.4 interludes)

- REPL-piped Forth only; concurrency tested through the threading model
  (`feedback_testing_rules`, `feedback_repl_tests_preferred`). No raw-BDOS hacks.
- The emulator feed is a **non-interactive pipe** — it cannot simulate human
  keystroke *timing*, so the emulator probe asserts *structure* (a background
  counter advanced between interpreted lines ⇒ the line reader yielded; clean
  interpreter; `EMIT` non-interleave). Wall-clock "no perceptible lag" is the
  **hardware S9** assertion (NFR-P6-3). State this split honestly — no silent
  cap (`feedback_no_preexisting_discharge`).
- Use `tests/assert_verdicts.sh --mode anchored` (24.4) + the 24.3 fail-loud
  `timeout`; ≤128-char probe lines (`feedback_tib_size_inline_comments`).
- Reviews are adversarial by design (`feedback_adversarial_review`); the `CR`
  command runs separately at story close (NOT an AC — PD-1).

### Hazards to document (not guard in v1)

- The non-interactive emulator pipe means the live-prompt experience is only
  *fully* exercised on hardware (S9). Do not claim emulator-verified responsiveness.
- A background task that calls `EMIT` while the operator also prints can still
  interleave at *line/word* granularity (F2 only guarantees no *char-level*
  shredding within a single `EMIT`). Document the coarse-interleave reality.

### Project Structure Notes

- **Edit:** `src/io.asm` (`KEY` → yielding thread + `(KEY)` primitive; `ACCEPT`
  → yielding line reader; `EMIT` no-yield comment; checklist block),
  `src/outer_interpreter.asm` (`QUERY` re-pointed to the yielding line reader),
  `Makefile` (probe recipe via 24.4 helper + 24.3 timeout),
  `tests/multitasker_tests.fth` (live-prompt + EMIT-no-interleave probes).
- **Read-only references:** `src/multitasker.asm` (`PAUSE`/`task_exit` — the yield
  target; do not modify), `src/macros.asm` (DEFWORD/BDOS macros),
  `src/constants.asm` (BDOS fn EQUs `C_READ`/`C_STATUS`/`C_READSTR`).
- Possible `docs/register-conventions.md` edit for the yield checklist if that is
  the canonical home for Hard Rules.
- No new module, no directory reorganization; flat `src/*.asm` preserved.

## Open Questions (for project lead — saved for the end, per workflow)

1. **Line-reader depth — the scope-defining fork.** Does 25.2 make the *prompt*
   truly live (re-point `QUERY` + `ACCEPT` to a char-by-char yielding line reader
   over `KEY`, yielding between keystrokes), or only instrument `KEY` and leave
   `QUERY`/`ACCEPT` on atomic BDOS fn 10 (background freezes during line entry;
   tasks advance only *between* commands)?
   **Recommendation: the full re-point** — it is the only path that satisfies FR10
   / NFR-P6-3 and the AD-P6-6 "task 0 yields in KEY" design, and it is what makes
   the 25.8 headline demo possible. The minimal path technically satisfies the
   AC's letter for `KEY` but leaves the prompt dead-while-typing. Confirm.
2. **`ACCEPT` `c-addr` deviation.** Current `ACCEPT` ignores `c-addr` and always
   writes `tib_buffer` (`io.asm:113,120`). When rewriting it onto the char loop,
   do we **honor `c-addr`** (write to the caller's buffer — closes a long-standing
   ANS deviation) or preserve the tib-only behavior? **Recommendation: honor
   `c-addr`** (small extra cost, more correct) — but flag as a behavior change.
3. **`KEY?` in the checklist.** The AC lists `KEY?` among the yielding trio, but
   `KEY?` is a non-blocking status query with no wait loop — yielding inside it
   would be wrong. **Recommendation:** keep `KEY?` non-blocking (no `PAUSE`); it is
   the *poll primitive* the yielders call, documented as such in the checklist.
   Confirm this reading of the AC.
4. **Line-editing fidelity.** Minimal (CR-terminate + destructive backspace +
   echo) this story, with full BDOS-fn-10 parity deferred — acceptable?
   **Recommendation: yes, minimal** (the fn-6/raw-input overhaul is 25.7).
5. **Envelope (F5).** Confirm the proposed ~190–375 B Story-25.2 envelope (full
   re-point path). Record actual at close.

### References

- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story-25.2] (lines 265–278; 25.7 folded note 356–367)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-6] (yield instrumentation + break, 388–411)
- [Source: _bmad-output/planning-artifacts/architecture.md#blocking-word-checklist] (539–541)
- [Source: _bmad-output/planning-artifacts/architecture.md] (F1/F2 validation, 741–742; "task 0 yields in KEY", 394–395; bring-up order, 443)
- [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md] (FR10–FR12, NFR-P6-3/-5/-12/-16/-17)
- [Source: src/io.asm] (`w_EMIT`:8; `w_ACCEPT`:116 fn-10; `w_KEY`:152 fn-1; `w_KEYQ`:168 fn-11; `c-addr` deviation:113,120)
- [Source: src/outer_interpreter.asm] (`w_QUERY`:120 — REPL line read via fn-10:133; canonical re-assert:150-162; `w_INTERPRET` BRANCH/?BRANCH thread pattern:174)
- [Source: src/multitasker.asm] (`PAUSE` = the yield target:82-157; `task_exit` JP-into-PAUSE pattern:164-169; sched_ip IP-preserve:182)
- [Source: src/macros.asm] (DEFCODE:66; DEFWORD:107; NEXT:32; BDOS_SAVE:166; BDOS_RESTORE:171)
- [Source: src/constants.asm] (C_READSTR=10:69; C_READ=1; C_STATUS=11)
- [Source: _bmad-output/implementation-artifacts/25-1-pause-circular-ring-task-activate-single-bank-fixed-memory.md] (PAUSE/ring/TCB this story rides; the two dev-pass gotchas)
- [Source: _bmad-output/implementation-artifacts/24-3-standing-8000-straddle-lint.md] / [24-4-shared-verdict-assert-helper.md] (the timeout + verdict helper to reuse)
- Memory: `project_phase6_concurrency_direction`, `project_multitasker_pause_register_contract`,
  `project_tos_in_register`, `feedback_defword_cf_label`,
  `feedback_kernel_ldir_estimate_overshoot`, `feedback_banking_probe_straddle_halt`,
  `feedback_tib_size_inline_comments`, `feedback_source_comment_discipline`,
  `feedback_post_hw_smoke_steps_at_review`, `feedback_no_preexisting_discharge`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story workflow, 2026-06-29)

### Open-Question resolutions (project lead, 2026-06-29 — at story creation)

1. **Line-reader depth?** → **Full re-point of `QUERY` + `ACCEPT`** onto a
   char-by-char yielding loop over `KEY`. Delivers FR10/NFR-P6-3/the live prompt;
   this is the AD-P6-6 "task 0 yields in KEY" design. The minimal KEY-only path is
   rejected (prompt would be dead-while-typing). Scope confirmed = the full path.
2. **`ACCEPT` `c-addr`?** → **Honor `c-addr`** — write to the caller's buffer,
   closing the long-standing tib-only ANS deviation (`io.asm:113,120`). Document
   it as a behavior change in the dev-pass close.
3. **`KEY?` no-yield?** → **Keep `KEY?` non-blocking, no `PAUSE`.** It is the poll
   primitive the yielders call (a status query must return immediately); yielding
   inside it would be wrong. The AC's listing of `KEY?` is reconciled in the
   checklist (Dev Notes "Yield checklist") as "non-blocking poll", not a yielder.
4. **Line-editing fidelity?** → **Minimal** this story: CR-terminate + destructive
   backspace + echo. Full BDOS-fn-10 editing parity is deferred to the Story 25.7
   fn-6/raw-input overhaul. Document any editing-behavior change vs the old prompt.
5. **Envelope (F5)?** → **~190–375 B** (the full re-point path), accept-with-
   rationale, no silent bloat. Record the actual `wc -c` delta at dev-pass close.

### Debug Log References

- **Pre-edit baseline (2026-06-29):** `build/antforth.com` = **29,889 B**; `make
  test-repl` = **1005 PASS / 0 FAIL**; `test-repl-timer` = 9/9; `test-repl-multitasker`
  = 5/5. Captured before any source edit (B.3 / Lesson 13.5-F).
- **iz-cpm reader contract (decisive finding).** `src/bdos_console.rs`: fn-1
  (`read`) **echoes every char incl. CR**; fn-10 (`read_string`) breaks on **CR
  OR LF**, stores up to `max`, leaves the overflow in the stream, and at EOF the
  old fn-10 path `read_exact().unwrap()` **panics → emulator crash-exits**. The new
  yielding reader has no such crash: at EOF `KEY?` (fn-11 status, which blocks on
  the pipe read until a byte or EOF) returns false forever, so `KEY` busy-waits —
  correct for a live terminal, but it turns any probe that *relied on the
  EOF-crash to terminate* into a hang. This drove three classes of probe fixes
  (below). The 100 ns sleep in `status()` means the busy-wait is not a hot spin.
- **`(EDIT)` fn-10 spill + LF parity (two regressions found & fixed mid-dev):**
  (1) the buffer-full case must *terminate the line and leave the rest in the
  stream* (not drop the overflow), or a >128-char line loses its tail (broke
  REPL test 103's `CODE BIG LABEL...` overflow probe); (2) it must emit a LF on
  buffer-full termination (the old `QUERY` emitted one LF after *every* read), or
  a truncated line's echo glues onto the runtime output and strip-source filters
  the witness away (broke `bank-store-t-states`).

### Completion Notes List

**What shipped (AC1–AC4 all satisfied):**

- **AC1 — input words yield.** `KEY` is now a DEFWORD thread
  `: KEY BEGIN KEY? 0= WHILE PAUSE REPEAT (KEY) ;` (`src/io.asm`): it polls the
  non-blocking `KEY?` (fn 11) and `PAUSE`s while no char is ready, then reads via
  the new headless `(KEY)` raw fn-1 primitive. The REPL line read is now a shared
  yielding line reader `(LINE) ( c-addr max -- count )` that loops over the
  yielding `KEY`; `QUERY` (`src/outer_interpreter.asm`, now a DEFWORD thread =
  `tib_buffer TIB_SIZE (LINE) (QUERY-FINISH)`) and `ACCEPT` (now `= (LINE)`) both
  route through it. So the operator task `PAUSE`s between keystrokes (FR10/FR11);
  the old atomic BDOS-fn-10 reads (no yield seam) are gone.
- **AC2 — `EMIT` no-yield.** `w_EMIT` is unchanged (DEFCODE fn 2); added a
  no-yield rationale comment so a future editor does not add a `PAUSE` (F2).
- **AC3 — yield checklist.** Standing-rule checklist table added as a comment
  block at the input section of `src/io.asm` (KEY yields / KEY? is the poll /
  (LINE)/ACCEPT/QUERY yield / EMIT never yields; any new blocking input primitive
  MUST be added).
- **AC4 — probe + binary delta.** New `tests/multitasker_key_tests.fth` +
  `make test-repl-multitasker-key` recipe (5 verdicts, all PASS): words resolve;
  the new line reader is live (computed token 42); a background counter advances
  when the foreground yields; EMIT prints clean with a task active; interpreter
  healthy. **Binary delta: 29,889 → 30,017 B = +128 B** — *under* the proposed
  ~190–375 B envelope (Q5), no silent bloat.

**Open-Question resolutions applied (all as the project lead pinned them):** Q1
full re-point of QUERY+ACCEPT onto `(LINE)`; Q2 `ACCEPT` now honors `c-addr`
(writes the caller's buffer — closes the long-standing tib-only ANS deviation);
Q3 `KEY?` stays non-blocking (no PAUSE), reconciled in the checklist as the poll
primitive; Q4 minimal line editing (CR/LF terminate + destructive backspace +
echo via fn-1); Q5 envelope confirmed (actual +128 B).

**Documented behavior changes (Q4 + the fn-1 echo consequence):**
- The REPL echo is now proper **CRLF** (fn-1 echoes the CR, then `(EDIT)` adds
  the LF), where the old fn-10 path emitted LF-only. Visually identical; the
  extra `\r` is the correct terminator. The hand-rolled `tr '\r\n' '  '` probe
  idiom (47 sites) was normalized to `tr -d '\r' | tr '\n' ' '` so the assertions
  are echo-format-agnostic (reproduces the old single-space spacing exactly).
- Line editing is minimal (CR/LF terminate, destructive backspace best-effort
  under fn-1 auto-echo, no fn-10 cooked-editing parity). The exact no-echo
  editing is the Story 25.7 fn-6 overhaul.

**Test-harness fixes forced by the correct EOF-wait (no longer a crash):** three
classes of probe that relied on the old fn-10 EOF-crash to terminate were made to
terminate properly (the *feature* is fine — these are probe fixes per the 24.3
standing rule): (1) REPL test 828 dropped FORTH from the search order so its
`SET-ORDER`/`BYE` cleanup was unfindable → keep FORTH in the order (`WL2
FORTH-WORDLIST 2 SET-ORDER`); (2) REPL tests 844/850 used a bogus `; echo BYE`
shell-append (never fed to iz-cpm) → feed a real `BYE` line; (3) the iron-spike
(`disk/a/P193IRON.FTH`) and the isolated 19-5-1 / 22-1 probes fed files with no
BYE → append `BYE` + a fail-loud `timeout`. The iron-spike now resolves PASS-or-
SKIP (its documented emulator layout-sensitivity, hardware-authoritative per
Story 17.6 AC8) — both non-failing.

**Single-task identity (NFR-P6-12):** with a length-1 ring `PAUSE` walks to self,
so `KEY` busy-polls fn 11 then reads — result-identical to the old blocking `KEY`
(same char, same `B=0`), only the execution shape differs; the full 1005/0
`test-repl` floor confirms it (every REPL line now flows through the new reader).

**Gate results (this binary, 30,017 B):** asm self-test PASS · `test-repl`
1005/0 · timer 9/9 · multitasker 5/5 · multitasker-key 5/5 (new) · banking 57/0
(+3 pre-existing Epic-19 SKIPs) · all banking-isolated + 23-6/7/9 PASS · straddle
3/3 · lint-banking-probes PASS · file-sanity PASS. (`check-doc-sync` reports
pre-existing planning-doc drift unrelated to this story — fails identically on
the baseline tree; `test_key.asm` repointed to the raw `(KEY)` primitive since it
has no scheduler to host `KEY`'s `PAUSE`.)

**S9 hardware smoke — PASS on real MicroBeast / CP/M 2.2 (2026-06-30, UAT).**
Operator activated a yielding background counter (`: BG BEGIN C @ 1+ C ! PAUSE 0
UNTIL ;`), then idled/typed at the live `ok>` prompt:
- `C @ .` → **14426** after idling — the counter advanced ~14k times *while the
  operator sat at the prompt*. Definitive FR10/NFR-P6-3 evidence: this can only
  happen if `QUERY`/`KEY` yielded during the keyboard wait (the emulator pipe
  never shows this — input is always ready, so the counter barely moves there).
- `1 2 3 + + .` → **6** with no perceptible lag (NFR-P6-3); `C @ .` again →
  **-25272** (= 40264 unsigned; single-cell wrap past 32767 expected) — counter
  kept climbing across commands.
- `: HELLO ." HELLO-WORLD" CR ; HELLO` → **`HELLO-WORLD`** printed contiguous on
  its own line (AC2 — `EMIT`/`TYPE` not char-shredded by the concurrent task).
- Banner `23999 bytes free` = baseline `24127` − **128 B**, cross-checking the
  recorded binary delta on silicon.
All S9 acceptance points satisfied; the live-prompt headline is confirmed on
hardware (the load-bearing assertion the non-interactive emulator pipe cannot make).

**Deferred / not done here:** Keyboard break / fn-6 /
Ctrl-C → 25.7; yielding `DELAY` → 25.3; `.TASKS`/`WAKE`/`SLEEP` → 25.4; per-bank
re-page → 25.5; background-task exception isolation → 25.6.

### File List

- `src/io.asm` — modified: `EMIT` no-yield comment; yield-instrumentation
  checklist block; new `(KEY)` raw fn-1 primitive; `KEY` → yielding DEFWORD
  thread; `KEY?` checklist note; new `(EDIT)` keystroke processor; new `(LINE)`
  yielding line-reader thread; `ACCEPT` → DEFWORD `= (LINE)` (honors `c-addr`).
- `src/outer_interpreter.asm` — modified: `QUERY` → yielding DEFWORD thread over
  `(LINE)`; new `(QUERY-FINISH)` housekeeping primitive (#TIB/>IN/source-spec).
- `src/test_key.asm` — modified: standalone KEY test repointed `w_KEY_cf` →
  `w_PAREN_KEY_cf` (raw read; no scheduler to host the yielding KEY).
- `tests/multitasker_key_tests.fth` — new: Story 25.2 input-yield probe (5 verdicts).
- `Makefile` — modified: new `test-repl-multitasker-key` target (+ `.PHONY`);
  normalized 47 `tr '\r\n' '  '` probe idioms to `tr -d '\r' | tr '\n' ' '`
  (CRLF-echo agnostic); fixed REPL tests 828/844/850 and the iron-spike + isolated
  19-5-1 / 22-1 probes to terminate under the yielding reader (BYE + timeout).

## Change Log

| Date | Change |
|---|---|
| 2026-06-29 | Story 25.2 drafted (create-story): KEY-hooked REPL input-only yield. Identified the load-bearing QUERY-blocks-in-fn-10 problem and the PAUSE-as-thread composition constraint; 5 open questions for project lead (headline: line-reader depth). Status → ready-for-dev. |
| 2026-06-29 | All 5 open questions resolved by project lead at story creation (all recommended): full re-point of QUERY+ACCEPT; honor `c-addr`; `KEY?` stays non-blocking; minimal line-editing; ~190–375 B envelope. Resolutions pinned in Dev Agent Record. |
| 2026-06-30 | S9 hardware smoke PASS on real MicroBeast / CP/M 2.2 (UAT transcript): background counter advanced ~14k while idle at the prompt (`C @ .`=14426, then -25272), `1 2 3 + + .`=6 no lag, `." HELLO-WORLD"` printed contiguous (AC2), banner free-bytes confirm the +128 B delta on silicon. Live-prompt headline confirmed on hardware. S9 task checked. |
| 2026-06-29 | Dev-pass (dev-story): KEY/ACCEPT/QUERY re-pointed onto a shared yielding line reader `(LINE)` over a threaded yielding `KEY` (`(KEY)`+`KEY?`+`PAUSE`); `(EDIT)`/`(QUERY-FINISH)` helpers; `EMIT` no-yield comment + yield checklist. `ACCEPT` honors `c-addr`. New `tests/multitasker_key_tests.fth` + `make test-repl-multitasker-key` (5/5). Binary 29,889 → 30,017 B (+128 B, under envelope). Fixed test-harness probes that relied on the old fn-10 EOF-crash (REPL 828/844/850, iron-spike, isolated 19-5-1/22-1) + normalized 47 CR-sensitive probe idioms (fn-1 now echoes CRLF). All gates green (test-repl 1005/0, timer 9, mt 5, mt-key 5, banking 57/0, isolated+23-x, straddle 3/3, lint, file-sanity). S9 hardware smoke deferred (recipe posted at close). Status → review. |
