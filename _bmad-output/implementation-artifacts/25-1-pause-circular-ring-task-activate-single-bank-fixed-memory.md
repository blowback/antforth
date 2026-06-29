# Story 25.1: PAUSE + circular ring + TASK/ACTIVATE (single-bank, fixed memory)

Status: done

> **Epic 25 opener — the scheduler spine.** This is bring-up step 1 of the
> architecture's fixed-memory-switch-first order (AD-P6 §"Implementation
> sequence"): a *testable scheduler* with task 0 (operator) + one background
> task, single-bank, no banking, no I/O yield. Every later Epic-25 story
> (KEY-hook 25.2, yielding DELAY 25.3, WAKE/SLEEP 25.4, per-bank switch 25.5,
> exception isolation 25.6, break 25.7, demo 25.8) calls the `PAUSE`/ring/TCB
> machinery this story lands. Get the register-save order and the ring walk
> right here; the rest of the epic rides on it.

## Story

As the operator,
I want to create a task and start a word running concurrently with my session,
so that two pieces of Forth make progress by cooperatively yielding.

## Acceptance Criteria

(Verbatim from `epics-phase6-epics-24-26.md` Story 25.1, lines 255–263; BDD form.)

1. **AC1 — single-task byte-identity (FR5 / NFR-P6-12 / NFR-P6-5).**
   **Given** a kernel with the TCB STRUCT (`structures.asm`) and a static
   operator-task-0 TCB wired into a circular ring at COLD,
   **When** no second task is activated,
   **Then** all Phase-1..5 behaviour is byte-identical (ring length-1) and the
   v3.1.0 `make test-repl` baseline passes **0 FAIL**.

2. **AC2 — `PAUSE` switch at a `NEXT` boundary (AD-P6-1 / AD-P6-3).**
   `PAUSE` saves `{SP, IX, DE, BC}` + the per-task subset
   `{catch_top, current_bank, base}` into `current_tcb`, walks `link` to the
   next AWAKE TCB, restores that TCB's subset and registers, and `NEXT`s —
   switching **only** at a `NEXT` boundary.

3. **AC3 — `TASK` carves a TCB with the $8000 guard (AD-P6-2 / validation F4).**
   `TASK ( -- )` carves a TCB + 256 + 256 B stacks from bank-0 dictionary
   `HERE`, and `THROW`s if `HERE + TCB_size` would cross `$8000`.

4. **AC4 — `ACTIVATE` + completion epilogue (FR4 / validation F3).**
   `ACTIVATE ( xt task -- )` sets the task running, wrapping the xt with a
   completion epilogue so a finite task word ends by setting `status = ASLEEP`
   + `PAUSE` (never falls off into garbage).

5. **AC5 — two-task round-robin probe + no corruption (NFR-P6-7 / NFR-P6-8).**
   A REPL-piped probe shows two tasks alternating via explicit `PAUSE`
   (round-robin deterministic) with no stack/dictionary corruption; binary
   delta recorded; **S9 hardware smoke PASSES**.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev
      Notes. **Do not inherit the figure below** — re-`wc -c` from the actual
      current build artifact (B.3 / Lesson 13.5-F). At time of story drafting
      (2026-06-29) the committed tree measured **29,415 B** (Epic-24 close); the
      dev-pass baseline may differ if commits have landed since.
- [x] Capture current `make test-repl` baseline pass count (the 0-FAIL floor,
      NFR-P6-5) — including the Epic-24 `test-repl-timer` 9/9.

### Task 1 — TCB STRUCT + field offsets + status enum (AC2, AC3) — `structures.asm`, `constants.asm`

- [x] Add the `TCB` STRUCT to `src/structures.asm` (doc-struct style, mirroring
      the existing `UserArea`/`DictEntry` doc-structs) with the fields from
      AD-P6-2's layout table (see Dev Notes "TCB layout"). Document the per-task
      subset `{catch_top, current_bank, base}` (AD-P6-1) in a comment block.
- [x] Add `TCB_*` field-offset EQUs (`TCB_LINK`, `TCB_STATUS`, `TCB_SP`,
      `TCB_IX`, `TCB_DE`, `TCB_BC`, `TCB_CATCH`, `TCB_BANK`, `TCB_BASE`,
      `TCB_PS`, `TCB_RS`, + `TCB_HDR_SIZE` / `TCB_SIZE`) in `src/constants.asm`.
      Address TCB fields by name, never by magic offset (Step-5 naming pattern).
- [x] Add the status enum EQUs `TASK_AWAKE` / `TASK_ASLEEP` / `TASK_SUSPENDED`.
      (SUSPENDED is unused until 25.6 but reserve the value now so the walk's
      "skip non-AWAKE" test is final.)
- [x] Reuse `PS_SIZE` / `RS_SIZE` (256 / 256, `constants.asm:88-89`) for the
      private stack areas — do NOT invent new sizes.

### Task 2 — `src/multitasker.asm` new module: static cells + `PAUSE` (AC1, AC2) — NEW + `antforth.asm`

- [x] Create `src/multitasker.asm`; add `INCLUDE "multitasker.asm"` to
      `src/antforth.asm` **after** `banking.asm` (line 736) and `timer.asm`
      (line 737) — it depends on banking symbols (for 25.5) and lives in the
      same fixed-memory neighbourhood as `tick_count`.
- [x] Declare fixed-memory kernel cells: `current_tcb DW 0` (pointer to running
      TCB) and the **static `operator_tcb`** record (task 0). Follow the
      `timer.asm` `tick_count` precedent: place them in always-mapped fixed
      memory and add `ASSERT $ <= SLOT2_WINDOW_BASE` after the block
      (`timer.asm:53`) so a future kernel-growth story fails loud if the
      scheduler state ever crosses `$8000`.
- [x] Implement `PAUSE` as a **DEFCODE** word (register-contract-critical). Save
      order **`{SP, IX, DE, BC}` then subset**, restore in reverse (Step-5
      "Register-Contract Patterns"). See Dev Notes "PAUSE switch sequence" for
      the exact 5-step body. Exit via `NEXT`. **No banking re-page in this
      story** — `current_bank` is saved/restored as a cell but the
      conditional `MBB_SET_PAGE` is deferred to 25.5 (single-bank here).
- [x] Subset copy goes *through* IY-relative loads/stores (`catch_top` =
      `structures.asm:33`, `base` = `:25`, `current_bank` = `:46`). **IY is
      never reassigned** (AD-P6-1).

### Task 3 — `TASK` with the $8000 budget guard (AC3) — `multitasker.asm`

- [x] Implement `TASK ( -- )`: read `HERE`, compute the new TCB top
      (`HERE + TCB_SIZE`), and **`THROW` if it would reach/cross `$8000`**
      (`SLOT2_WINDOW_BASE`). Reuse `THROW_DICT_OVERFLOW` (`-8`,
      `constants.asm:161` — the banked-window-top-guard code; a TCB carve is a
      dictionary allocation, so `-8` is the natural fit). See Dev Notes
      "Why the $8000 guard is real (F4)".
- [x] On success: initialise the TCB header — `status = TASK_ASLEEP` (a freshly
      carved task is not runnable until `ACTIVATE`), `link` spliced into the
      ring (insert after `current_tcb`, or after operator_tcb — pick one,
      document it; round-robin order is deterministic either way, NFR-P6-8),
      stack-area pointers derivable from the TCB base + `TCB_PS`/`TCB_RS`.
- [x] Advance `HERE` past the TCB (the carve). `TASK` leaves nothing on the data
      stack in v1 (`( -- )`); the just-created TCB is referenced via a
      mechanism the probe can name it by — see Open Question Q2 (does `TASK`
      push the TCB address, or is there a `LATEST-TASK`-style handle?). The
      epics AC says `TASK ( -- )` and `ACTIVATE ( xt task -- )` — so a task
      handle must reach the stack somehow; resolve at dev time per Q2.

### Task 4 — `ACTIVATE` + completion epilogue (AC4) — `multitasker.asm`

- [x] Implement the **completion epilogue** as a tiny CODE fragment: set the
      running TCB `status = TASK_ASLEEP`, then fall into `PAUSE`. This is the
      thread cell a finite task's terminal `NEXT` chases into so it never runs
      off its xt into garbage (FR4 / F3).
- [x] Implement `ACTIVATE ( xt task -- )`: build the resume thread
      `[ xt | <epilogue_cf> ]` (recommend storing it as a 4-byte `t_thread`
      field *inside* the TCB so no separate allocation is needed — see Dev Notes
      "Completion epilogue & resume thread"), set `saved_de` = address of that
      thread, `saved_sp` = top of the task's `ps_area`, `saved_ix` = top of its
      `rs_area`, seed the subset (`catch_top = 0`, `current_bank` = current,
      `base` = current `BASE`), and set `status = TASK_AWAKE`.

### Task 5 — COLD: wire the static operator-task-0 TCB + ring (AC1) — `antforth.asm`

- [x] In COLD init, initialise `operator_tcb`: `status = TASK_AWAKE`,
      `link = operator_tcb` (ring of length 1 → points at itself), and
      `current_tcb = operator_tcb`. The operator's saved register slots are
      filled on its *first* `PAUSE` (it is the running task at boot). **The
      operator TCB reuses the existing system stacks** — it does NOT get a
      private 256+256 B carve (see Dev Notes "Operator TCB reuses system
      stacks"). A ring of length 1 means `PAUSE` walks `link` once back to self
      and resumes — byte-identical single-task behaviour (FR9 / AC1).
- [x] Verify the COLD addition is straight Z80 (no Forth-stack marshalling at
      COLD — matches the `timer.asm` tick-cell COLD pattern).

### Task 6 — Probe + Makefile wiring (AC5) — `tests/multitasker_tests.fth`, `Makefile`

- [x] Create `tests/multitasker_tests.fth` (REPL-piped, NFR-P6-16). Probe shows
      **two tasks alternating via explicit `PAUSE`** with printed witnesses
      proving interleave + deterministic round-robin + no stack/dictionary
      corruption. Keep every line **≤ 128 chars** including `\` annotations
      (`feedback_tib_size_inline_comments`).
- [x] Wire a `test-repl-multitasker` (or epic-named) recipe into the Makefile
      gate. **Reuse the Story 24.4 shared helper `tests/assert_verdicts.sh`**
      (`--mode anchored`, column-0-anchored `^PASS:` asserts) — do NOT
      re-derive the grep/`\r`/`xxd` block. The emulator-feed pipe is wrapped in
      the Story 24.3 fail-loud `timeout` so any wedge is a loud FAIL, not a
      hang.
- [x] Run `make lint-banking-probes` / the straddle guard (Story 24.3): this
      probe does NOT mutate the bank window, so it is straddle-safe, but keep
      bodies low / interpret-level per habit. Confirm no false-positive.
- [x] Full `make test` gate green; record the binary delta (`wc -c` after −
      before) in Dev Notes against the proposed envelope.

### S9 hardware smoke (post dev-pass — recipe in the close-out chat message)

- [x] On real CP/M 2.2 / MicroBeast: load the kernel, `TASK` a background
      counter, `' <word> <task> ACTIVATE`, drive a few explicit `PAUSE`s, and
      confirm both tasks advance with no corruption / hang. (Per the
      **STRONG** `feedback_post_hw_smoke_steps_at_review` commitment, post the
      exact recipe in the closing chat message, not only here.) **S9 PASSED on
      silicon 2026-06-29** (project lead): `' BG TASK ACTIVATE`, `DRV` →
      `TAPE @ .` = `12121` (deterministic round-robin), `1 2 3 + + .` = `6`
      (interpreter healthy), `PAUSE PAUSE 42 .` = `42` (BG asleep, solo PAUSE
      a no-op). No corruption / no hang.

## Dev Notes

### Architecture provenance (read these first)

- **AD-P6-1** (per-task state), **AD-P6-2** (TCB layout & dict allocation),
  **AD-P6-3** (scheduler ring & PAUSE sequence) —
  `_bmad-output/planning-artifacts/architecture.md:245-342`. Plus the Step-5
  "Register-Contract Patterns" / "TCB & Per-Task State Patterns" /
  "Anti-Patterns" at `architecture.md:488-591`.
- The 5 locks (cooperative; shared dict / operator-only compile; per-task bank
  in TCB; fixed-memory-switch-first) and the memory note
  `project_phase6_concurrency_direction` govern; mind the label drift (old docs
  say "Phase 5").

### TCB layout (AD-P6-2, `architecture.md:284-297`)

| Field | Off (EQU) | Bytes | Purpose |
|---|---|---|---|
| `link` | `TCB_LINK` | 2 | next TCB in the circular ring |
| `status` | `TCB_STATUS` | 1 | `TASK_AWAKE` / `TASK_ASLEEP` / `TASK_SUSPENDED` |
| `saved_sp` | `TCB_SP` | 2 | data-stack pointer at yield |
| `saved_ix` | `TCB_IX` | 2 | return-stack pointer at yield |
| `saved_de` | `TCB_DE` | 2 | IP (resume thread address) |
| `saved_bc` | `TCB_BC` | 2 | TOS at yield |
| `t_catch_top` | `TCB_CATCH` | 2 | per-task CATCH-TOP (AD-P6-1) |
| `t_current_bank` | `TCB_BANK` | 2 | per-task bank (AD-P6-1; saved/restored here, re-paged in 25.5) |
| `t_base` | `TCB_BASE` | 2 | per-task BASE (AD-P6-1) |
| `t_thread` | (suggested) | 4 | resume thread `[xt|epilogue_cf]` (see below) |
| `ps_area` | `TCB_PS` | 256 | private parameter stack |
| `rs_area` | `TCB_RS` | 256 | private return stack |

Header ≈ 17 B (+4 if `t_thread` lives in the TCB) + 512 B stacks ≈ **~533 B per
dictionary-allocated task**. Document the per-task cost for capacity planning
(NFR-P6-9).

### PAUSE switch sequence (AD-P6-3, `architecture.md:328-340` + Step-5 save-order)

`PAUSE` is a **DEFCODE** word reached through threading (switches ONLY at a
`NEXT` boundary — the cooperative invariant, `register-conventions.md` Hard
Rule #1). Body:

1. Save `BC, DE, IX, SP` into the **outgoing** `current_tcb`'s saved slots.
   (`LD (nn),SP` and `LD (nn),IX` are the special-form stores; load
   `current_tcb`→HL/index for the rest.)
2. Copy `(IY+catch_top)`, `(IY+current_bank)`, `(IY+base)` → outgoing TCB
   subset slots. (Through IY — never swap IY.)
3. Walk `link` to the next TCB whose `status = TASK_AWAKE` (skip ASLEEP /
   SUSPENDED). If the walk returns to self, the single awake task just resumes
   (FR9 — ring length-1 ⇒ no observable change, satisfies AC1).
4. Restore the next TCB's subset → UserArea. *(In 25.1 only the cells are
   copied; the conditional `MBB_SET_PAGE` re-page is **deferred to 25.5** — see
   Anti-Patterns: do not re-page here.)*
5. Restore `SP, IX, DE, BC` from the next TCB; `NEXT`.

**Do not** reorder the register restore after `NEXT`, interleave the subset copy
with the register restore, or invoke `PAUSE` from inside an EXX window / mid-
primitive (`architecture.md:582-591` Anti-Patterns).

### Operator TCB reuses system stacks (clarification, not in the AC text)

The operator (task 0) already owns the system data stack (`sp_base` region) and
return stack (IX). Its static `operator_tcb` is therefore a **header-only record**
(no `ps_area`/`rs_area` carve) — `saved_sp`/`saved_ix` simply capture the live
system SP/IX at the operator's first `PAUSE`. Only dictionary-allocated tasks
(via `TASK`) get the private 256+256 B stacks. This keeps the static fixed-memory
footprint tiny and is why AC1 byte-identity holds: with one task the operator
runs on exactly the stacks it always used.

### Why the $8000 guard is real (F4) — the load-bearing memory-map nuance

AD-P6-2 says TCBs carve from `HERE` and `TASK` must `THROW` if it would cross
`$8000`. **This guard is not cosmetic**, and the reason is sharper than the
architecture text alone: per **Story 24.3's as-built correction**
(`24-3-standing-8000-straddle-lint.md:5-22`), the bank-0 dictionary grows
*through* the slot-2 window — `kernel_end` ≈ `0x73E7`, in-suite `HERE` reaches
`0xB1D8`, ceiling `$D400`. Addresses **above `$8000` are the slot-2 banked
window**: when a non-portal bank is later mapped in (25.5+), `$8000–$BFFF` shows
*that bank's* RAM, not the portal's. A TCB carved above `$8000` would therefore
**vanish from the scheduler's view under a different bank mapping** — fatal for a
structure `PAUSE` must read on every switch. Hence: **TCBs must stay below
`$8000`** to be reachable under any mapping, and the carve window is only
`HERE..$8000` (≈ 3 KB at a fresh boot, kernel_end `0x73E7`→`$8000`) — room for
~5–6 tasks before `TASK` legitimately `THROW`s. State this as the documented v1
capacity limit; the `$D4xx` allocator fallback (AD-P6-2) is a future option, not
this story.

This `$8000` guard *is* the home for sprint-planning carry-forward **F4** (TCB
fixed-RAM budget guard + measurement) — see `sprint-status.yaml` Phase-6 note.

### Completion epilogue & resume thread (F3, `architecture.md:303-308`)

`ACTIVATE` makes the resume IP (`saved_de`) point at a 2-cell thread
`[ xt_cf | epilogue_cf ]`. When the finite task word's terminal `EXIT`/`NEXT`
runs, the IP advances into `epilogue_cf`, which sets `status = TASK_ASLEEP` and
`PAUSE`s — the task leaves the rotation cleanly instead of running off the end
(FR4). **Recommended placement:** store the 4-byte `t_thread` *inside the TCB*
(a fixed field) so there is no separate dictionary allocation to track per
activation and re-`ACTIVATE` (FR21, later) just rewrites it. The epilogue CODE
fragment is shared by all tasks (one copy in `multitasker.asm`).

### Register / TOS conventions

- BC = TOS, DE = IP, IX = return stack, IY = UserArea, SP = data stack
  (`project_tos_in_register`; `register-conventions.md` Hard Rule #1).
- DEFCODE label/skeleton: `macros.asm:66`; `NEXT`/`NEXTHL`: `macros.asm:32-46`.
  For any DEFWORD helper, `w_*_cf` via `EQU body-3 → JP DOCOL`
  (`feedback_defword_cf_label`). `PAUSE` + the epilogue are DEFCODE (raw Z80).

### Binary-size envelope (sprint-planning carry-forward F5 — proposed here)

F5 asks the per-epic envelope be agreed before Epic 25. Story 25.1 is **new
hand-written asm**, not a cross-bank design substitution — so the 2.4× Epic-17
multiplier (`project_epic17_envelope`) does **not** apply (Epic 24 retro made
the same ruling for composition stories). Per-component itemisation (B.2 — no
"mirrors prior arm"):

| Component | Est. bytes |
|---|---|
| `PAUSE` DEFCODE (save 4 regs + 3-cell subset, ring walk loop, restore) | ~120–170 |
| `TASK` (HERE read, $8000 guard + THROW, header init, ring splice, HERE advance) | ~80–120 |
| `ACTIVATE` (build resume thread, seed subset, stack tops, status) | ~50–90 |
| Completion epilogue (status store + fall-through to PAUSE) | ~10–20 |
| COLD operator-TCB wiring + static cells (`current_tcb`, operator record) | ~30–50 |
| TCB EQUs / STRUCT / status enum | 0 (assembler constants) |
| **Raw subtotal** | **~290–450** |
| **Register-juggle overshoot ×1.25** (`feedback_kernel_ldir_estimate_overshoot` — PAUSE is exactly an EX/LD register-save story) | **~360–560** |

**Proposed Story-25.1 envelope: ~360–560 B**, accept-with-rationale, no silent
bloat (NFR-P6-10). Record the actual delta at dev-pass close. *(Flag for project
lead: confirm this envelope and the whole-Epic-25 envelope at story acceptance —
F5.)*

### Testing standards (S2 / NFR-P6-16/-17 + the 24.3/24.4 interludes)

- REPL-piped Forth only; concurrency tested through the threading model
  (`feedback_testing_rules`, `feedback_repl_tests_preferred`). No raw-BDOS /
  asm-thread hacks.
- **Use the Story 24.4 helper** `tests/assert_verdicts.sh --mode anchored` for
  verdict asserts (column-0 `^PASS:` anchoring is the 23.2 false-green defense);
  the **Story 24.3 fail-loud `timeout`** wraps the emulator pipe so a wedge is a
  loud FAIL not a CI hang. Both interludes are `done` and exist precisely to
  serve this probe-heavy epic.
- ≤ 128-char probe lines incl. `\` annotations (`feedback_tib_size_inline_comments`).
- This probe drives explicit `PAUSE`es (no KEY-hook / DELAY / banking yet) — it
  asserts *structure* (interleave order, status, no corruption) under the
  emulator; wall-clock / interrupt behaviour is not exercised until 25.2+.
- Reviews are adversarial by design — absence of findings is suspect
  (`feedback_adversarial_review`); the `CR` command runs separately at story
  close (NOT an AC — PD-1).

### Hazards to document (not guard in v1)

- `FORGET` / `MARKER` past an active task's TCB reclaims its storage — same
  lifecycle class as the banked-MARKER hazard (`project_banked_marker_no_stub`,
  AD-P6-2). Document as don't-do; not guarded this story.
- A task that never reaches a `PAUSE` starves the ring — the documented
  cooperative failure (FR22), broken via keyboard in 25.7. Out of scope here.

### Project Structure Notes

- **New:** `src/multitasker.asm` (INCLUDE after `banking.asm:736` /
  `timer.asm:737` in `antforth.asm`), `tests/multitasker_tests.fth`.
- **Edit:** `src/structures.asm` (TCB STRUCT + subset doc), `src/constants.asm`
  (TCB EQUs + status enum), `src/antforth.asm` (COLD ring wiring + INCLUDE
  line), `Makefile` (new test recipe via the 24.4 helper + 24.3 timeout).
- **Read-only references:** `src/inner_interpreter.asm` (NEXT boundary, DOCOL),
  `src/io.asm` (KEY/EMIT — yield hooks are **25.2**, NOT this story),
  `src/banking.asm` (MBB path — re-page is **25.5**, NOT this story),
  `src/timer.asm` (the `tick_count` fixed-mem-cell + `ASSERT $ <= SLOT2_WINDOW_BASE`
  pattern to copy).
- No directory reorganisation; flat `src/*.asm` convention preserved
  (`architecture.md:592-642`).
- **Comment discipline:** what + why-not-obvious in source; provenance
  (story/CR/date) goes in git/story/ADR/memory only
  (`feedback_source_comment_discipline`).

### Scope boundaries (explicitly deferred — do not implement here)

- ❌ Banking re-page on switch (`MBB_SET_PAGE`) → **Story 25.5**. Save/restore
  the `current_bank` cell, but no page call.
- ❌ `KEY`/`KEY?`/`ACCEPT` yield hooks, REPL concurrency → **Story 25.2**.
- ❌ Yielding `DELAY` → **Story 25.3**. (Epic 24's busy-wait `(DELAY)` seam is
  already factored for it; untouched here.)
- ❌ `WAKE`/`SLEEP`/`.TASKS` → **Story 25.4**. (Reserve `TASK_SUSPENDED` so the
  walk's AWAKE test is final, but no user words.)
- ❌ Background-task exception isolation (`.throw_uncaught` reroute) →
  **Story 25.6**.

## Open Questions (for project lead — saved for the end, per workflow)

1. **25.1 split?** `sprint-status.yaml` flags "*SM may split scheduler-core vs
   TASK/ACTIVATE user words at create-story*". **Recommendation: keep whole.**
   AD-P6's bring-up step 1 explicitly groups `PAUSE` + ring + TCB as one
   "testable scheduler" milestone, and AC5's two-task probe is undemonstrable
   until `PAUSE` + `TASK` + `ACTIVATE` all exist together — splitting would leave
   a half-story with no end-to-end witness. Splitting would also renumber 25.2–25.8.
   Confirm whole, or request a split (e.g. 25.1a PAUSE+ring+TCB-struct+COLD /
   25.1b TASK+ACTIVATE+probe).
2. **Task handle shape.** The epics ACs read `TASK ( -- )` and
   `ACTIVATE ( xt task -- )` — so a task reference must reach the data stack for
   `ACTIVATE` to consume. Does `TASK` push the new TCB address ( `-- task` in
   practice ), or is there a separate `LATEST-TASK`/named-handle mechanism? The
   architecture is silent on the surface. **Recommendation:** `TASK` pushes the
   TCB base address (simplest, matches `ACTIVATE ( xt task -- )`); confirm at
   dev time and pin the stack effect in the probe.
3. **Envelope (F5).** Confirm the proposed ~360–560 B Story-25.1 envelope and
   set the whole-Epic-25 envelope (Dev Notes "Binary-size envelope").

### References

- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story-25.1] (lines 249–263)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-1] (per-task state, 245–274)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-2] (TCB layout & alloc, 276–322)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-3] (scheduler & PAUSE, 324–342)
- [Source: _bmad-output/planning-artifacts/architecture.md#Register-Contract-Patterns] (488–591)
- [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md] (FR1–FR9, NFR-P6-1/-5/-7/-8/-9/-11/-12)
- [Source: src/structures.asm#UserArea] (subset cells: base:25, catch_top:33, current_bank:46)
- [Source: src/constants.asm] (PS_SIZE/RS_SIZE:88-89; SLOT2_WINDOW_BASE:47; THROW_DICT_OVERFLOW:161)
- [Source: src/macros.asm] (NEXT:32; DEFCODE:66)
- [Source: src/timer.asm] (fixed-mem cell + `ASSERT $ <= SLOT2_WINDOW_BASE`:21,53 — the pattern to copy)
- [Source: src/antforth.asm] (kernel_end:836; HERE=kernel_end:57; INCLUDE order:736-737)
- [Source: _bmad-output/implementation-artifacts/24-3-standing-8000-straddle-lint.md] (as-built memory-map correction:5-22 — F4 grounding)
- [Source: _bmad-output/implementation-artifacts/24-4-shared-verdict-assert-helper.md] (tests/assert_verdicts.sh — use it)
- [Source: _bmad-output/implementation-artifacts/epic-24-retro-2026-06-29.md] (AI-24-1/-2 interludes gate this epic; AI-24-3 break-in note for 25.7)
- Memory: `project_phase6_concurrency_direction`, `project_tos_in_register`,
  `feedback_defword_cf_label`, `feedback_kernel_ldir_estimate_overshoot`,
  `feedback_banking_probe_straddle_halt`, `feedback_tib_size_inline_comments`,
  `feedback_source_comment_discipline`, `project_banked_marker_no_stub`,
  `feedback_post_hw_smoke_steps_at_review`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Code dev-story workflow), 2026-06-29.

### Open-Question resolutions (project lead, at dev-pass start)

1. **25.1 split?** → **Keep whole** (recommended). PAUSE + ring + TCB + TASK +
   ACTIVATE shipped as one testable scheduler; AC5's two-task probe is the
   end-to-end witness.
2. **Task-handle shape?** → **`TASK` pushes the TCB base address** (recommended),
   so `TASK` is effectively `( -- task )` and `' BG TASK ACTIVATE` reads naturally.
3. **Envelope (F5)?** → **~360–560 B, record actual** (recommended). Actual delta
   **+474 B** (see below), inside the band.

### Debug Log References

- **Bug 1 (crash → warm-boot on `' BG TASK ACTIVATE`).** Both `TASK` and
  `ACTIVATE` used `DE` (= the IP) as a scratch pointer but never restored it, so
  the operator's next `NEXT` fetched from a garbage IP and ran wild (a second
  banner appeared in the probe dump = CP/M warm boot). Fix: preserve the caller
  IP across both words via a fixed `sched_ip` cell (PAUSE is exempt — swapping DE
  through the TCB is its job).
- **Bug 2 (`error -3` the instant a background task ran).** `check_overflow` /
  `check_underflow` / `DEPTH` measure `sp_base - SP` against the global `sp_base`
  (the operator's system stack base); a background task runs on its private
  `ps_area` (a much lower address), so the guard saw a huge delta and false-tripped
  `-3`. Fix: added a per-task `t_sp_base` TCB cell (offset 17, contiguous with the
  subset) and made `PAUSE` swap the global `sp_base` to the running task's base.
  (`rp_base` left global — only operator-run QUIT uses it; no background path
  guards the return stack.)
- **Regression (banking gate `plus-bank-cap`).** The +474 B kernel growth lifted
  the late `banking_tests.fth` `+BANK`-cap helper headers across `$8000` into the
  volatile slot-2 window, so the post-seed `'` lookup failed under a foreign
  mapping — the documented `feedback_banking_probe_straddle_halt` hazard the story
  flagged. Fix is to the PROBE (not the feature): moved `_do-29-+bank` /
  `_do-one-more-+bank` to the TOP of the file (fixed memory, below `$8000`) so they
  stay findable under any bank mapping; orchestration + verdict stay
  interpret-level (Story 23.2 pattern). Root cause confirmed empirically — a word
  in fixed memory is findable regardless of bank state.

### Completion Notes List

- **Pre-edit baseline (2026-06-29):** `wc -c build/antforth.com` = **29,415 B**;
  `make test-repl` = **1005 PASS / 0 FAIL**; `make test-repl-timer` = **9/9**.
- **TCB STRUCT + EQUs (Task 1):** `TCB` doc-struct in `structures.asm` with 13
  drift `ASSERT`s pinning each field offset (and total size) to the `TCB_*` EQUs in
  `constants.asm` — a field reorder without a matching EQU edit fails the build.
  Status enum `TASK_AWAKE`/`TASK_ASLEEP`/`TASK_SUSPENDED` (SUSPENDED reserved for
  25.6). Reused `PS_SIZE`/`RS_SIZE` (256/256). Header = 23 B, `TCB_SIZE` = 535 B.
- **`PAUSE` (DEFCODE):** save `{SP,IX,DE,BC}` via the ED-prefixed `LD (nn),rr`
  stores → fixed `sched_save` bridge → outgoing TCB; copy subset
  `{catch_top,current_bank,base}` + `sp_base` through IY; walk `link` to the next
  AWAKE TCB; restore subset + registers; `NEXT`. No `MBB_SET_PAGE` re-page
  (deferred to 25.5). Switches only at a `NEXT` boundary.
- **`TASK ( -- task )`:** carves a TCB at HERE, `THROW`s `-8` via
  `dict_overflow_throw` if `HERE + TCB_SIZE` reaches/crosses `$8000`, inits the
  header ASLEEP, splices into the ring after `current_tcb`, advances HERE, pushes
  the TCB base as the handle.
- **`ACTIVATE ( xt task -- )`:** builds the resume thread `[xt | task_exit]` in the
  TCB, seeds saved regs (SP/IX at the private-stack tops, IP at the thread, TOS=0)
  + subset (catch_top=0, current_bank/base inherited) + `t_sp_base`, sets AWAKE.
- **`task_exit` epilogue:** sets the running task ASLEEP and re-enters `PAUSE`, so a
  finite task word leaves the rotation cleanly instead of running off its xt.
- **COLD wiring:** `operator_tcb` (static, header-only, reuses the system stacks)
  set AWAKE + `link = self`; `current_tcb = operator_tcb`. Length-1 ring ⇒ PAUSE
  walks once back to self ⇒ byte-identical single-task behaviour (AC1).
- **Probe (`tests/multitasker_tests.fth`, `make test-repl-multitasker`):** 5/5
  PASS — `mt-words-resolve`, `mt-solo-pause` (length-1 ring no-op), `mt-roundrobin`
  (two tasks alternate to the deterministic witness TAPE=12121), `mt-task-asleep`
  (epilogue parks BG out of the rotation), `mt-alive` (clean stack + alive after).
- **Binary delta: +474 B** (29,415 → **29,889 B**), inside the ~360–560 B envelope
  (F5). No silent bloat.
- **Gates (all green):** `make test` PASS; `test-repl` 1005/0; `test-repl-timer`
  9/9; `test-repl-multitasker` 5/5; full banking suite (18 targets) 0 FAIL;
  `test-straddle-regression` 3/3; `lint-banking-probes` PASS; `test-file-sanity`
  PASS; `test-repl-cr-21-3` PASS. `check-doc-sync` drift is pre-existing
  (prd/architecture, untouched here) and advisory-only.
- **S9 hardware smoke: PASSED on real MicroBeast 2026-06-29** (project lead). On
  silicon: `' BG TASK ACTIVATE` + `DRV` → `TAPE @ .` = `12121` (two tasks
  alternated deterministically via explicit `PAUSE`), `1 2 3 + + .` = `6`
  (interpreter healthy, stack clean), `PAUSE PAUSE 42 .` = `42` (BG asleep after
  its epilogue; solo PAUSE on the now-length-1 awake ring is a clean no-op). No
  corruption, no hang — the AC5 hardware gate is met.

### File List

- `src/constants.asm` (M) — `TCB_*` field-offset EQUs, `TCB_HDR_SIZE`/`TCB_PS`/
  `TCB_RS`/`TCB_SIZE`, `TASK_AWAKE`/`TASK_ASLEEP`/`TASK_SUSPENDED`, `TCB_SPBASE`.
- `src/structures.asm` (M) — `TCB` doc-STRUCT + per-task-subset/`t_sp_base` doc +
  13 drift `ASSERT`s against the EQUs.
- `src/multitasker.asm` (A) — new module: fixed-memory scheduler state
  (`current_tcb`, `sched_save`/`sched_tcb`/`sched_ip`, `operator_tcb`), `PAUSE`,
  `task_exit` epilogue, `TASK`, `ACTIVATE`, `ASSERT $ <= SLOT2_WINDOW_BASE`.
- `src/antforth.asm` (M) — `INCLUDE "multitasker.asm"` after `timer.asm`; COLD step
  8k wires the operator task-0 TCB + ring.
- `tests/multitasker_tests.fth` (A) — new REPL probe (5 verdicts).
- `tests/banking_tests.fth` (M) — moved the `+BANK`-cap helpers
  (`_do-29-+bank`/`_do-one-more-+bank`) to fixed memory at the top of the file
  (probe-hardening vs the kernel-growth $8000 straddle).
- `Makefile` (M) — `test-repl-multitasker` recipe (24.4 helper + 24.3 timeout) +
  `.PHONY` entry.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (M) — 25.1
  `ready-for-dev` → `in-progress` → `review`.

## Change Log

| Date | Change |
|---|---|
| 2026-06-29 | Story 25.1 dev-pass: PAUSE + circular ring + TASK/ACTIVATE single-bank scheduler. New `src/multitasker.asm`; TCB STRUCT/EQUs; COLD operator-TCB ring wiring; `tests/multitasker_tests.fth` (5/5). Fixed two dev-pass bugs (IP clobber in TASK/ACTIVATE; `sp_base` not task-aware) + one banking-probe straddle regression from the +474 B kernel growth. +474 B (29,415 → 29,889). All gates green. Status → review. |
| 2026-06-29 | **S9 hardware smoke PASSED on real MicroBeast** (project lead): two-task round-robin `TAPE @ .`=12121, `1 2 3 + + .`=6, `PAUSE PAUSE 42 .`=42. AC5 hardware gate met. |
