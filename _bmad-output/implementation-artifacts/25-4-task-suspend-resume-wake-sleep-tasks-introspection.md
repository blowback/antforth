# Story 25.4: Task suspend/resume (WAKE/SLEEP) + .TASKS introspection

Status: done

> **Epic 25 bring-up step 4 — make the task set *manageable and observable*.**
> Story 25.1 landed the scheduler spine (`PAUSE`/ring/TCB/`TASK`/`ACTIVATE`);
> 25.2 made the REPL yield while waiting for input (KEY-hook); 25.3 made `DELAY`
> yield. The ring can now run several tasks, but the operator has no way to
> *pause* a task short of letting it finish, and no way to *see* what is running.
> This story adds the three management words: `SLEEP` / `WAKE` (flip a task
> ASLEEP↔AWAKE) and `.TASKS` (list the ring + each task's state). It is the
> "introspection/management" milestone before the harder per-bank switch (25.5),
> exception isolation (25.6 — which *consumes* `.TASKS` + the SUSPENDED state for
> recovery), keyboard break (25.7), and the headline demo (25.8). No new
> scheduler mechanism: `PAUSE`'s ring-walk **already skips any non-AWAKE TCB**
> (`multitasker.asm:115-131`); `SLEEP`/`WAKE` only set the status byte the walk
> already honours, and `.TASKS` only *reads* the ring.

## Story

As the operator,
I want to suspend, resume, and list tasks with their state,
so that I can manage and observe the running task set.

## Acceptance Criteria

(Verbatim from `epics-phase6-epics-24-26.md` Story 25.4, lines 295–308; BDD form.)

1. **AC1 — SLEEP/WAKE flip status; the walk skips ASLEEP (FR3, FR7).**
   **Given** a ring with one or more activated tasks,
   **When** I run `task SLEEP` / `task WAKE`,
   **Then** the task's `status` flips ASLEEP/AWAKE and the round-robin walk skips
   ASLEEP tasks; a suspended task makes no progress until woken.

2. **AC2 — `.TASKS` lists each task and its state (FR25, AD-P6-1 MVP).**
   `.TASKS` ( -- ) lists each task and its state (AWAKE/ASLEEP/SUSPENDED),
   following the `.`-introspection convention.

3. **AC3 — Journey-1 witness.**
   `.TASKS` shows the operator and a background task both awake.

4. **AC4 — probe + S9 + binary delta (NFR-P6-16/-17).**
   REPL-piped probes assert the status transitions and `.TASKS` output via
   printed witnesses (interpret-level `'`, ≤128-char lines, NFR-P6-16/-17); binary
   delta recorded; S9 PASS.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev
      Notes. **Do not inherit the figure below** — re-`wc -c` from the actual
      current build artifact (B.3 / Lesson 13.5-F). At story-drafting time
      (2026-06-30) the committed tree measured **30,040 B** (HEAD = Story 25.3
      close, +2 B); the dev-pass baseline may differ if commits have landed since.
- [x] Capture current `make test-repl` baseline pass count (the 0-FAIL floor,
      NFR-P6-5) — including `test-repl-timer` (9/9), `test-repl-multitasker`
      (5/5), `test-repl-multitasker-key` (5/5), and `test-repl-multitasker-delay`
      (6/6).

### Task 1 — `SLEEP` / `WAKE` status-flip CODE words (AC1) — `src/multitasker.asm`

- [x] Add `SLEEP` ( task -- ) and `WAKE` ( task -- ) as DEFCODE words in
      `src/multitasker.asm` (the scheduler module owns task lifecycle —
      `architecture.md:417`). Each takes a **task handle = the TCB base** that
      `TASK` returned (TOS in BC), writes the status byte at `task + TCB_STATUS`
      (`=2`, `src/constants.asm:107`), then `POP BC` for the new TOS and `NEXT`.
  - [x] `SLEEP`: store `TASK_ASLEEP` (`=0`) at `(task+2)`.
  - [x] `WAKE`: store `TASK_AWAKE` (`=1`) at `(task+2)`.
- [x] **Register contract (25.1 gotcha #1 — every normal task word preserves
      DE=IP):** these words must NOT touch DE. The natural body
      (`LD H,B / LD L,C / INC HL / INC HL / LD (HL),n / POP BC / NEXT`) uses only
      A/BC/HL — DE=IP is untouched, so the contract holds with no save/restore.
      Do NOT copy `TASK`/`ACTIVATE`'s `LD (sched_ip),DE` preserve dance — that is
      only needed because *those* bodies clobber DE; `SLEEP`/`WAKE` do not.
      (`project_multitasker_pause_register_contract`.)
- [x] **No new scheduler logic.** `PAUSE`'s walk already terminates on
      `status == TASK_AWAKE` (`multitasker.asm:129` `CP TASK_AWAKE / JR NZ`), so an
      ASLEEP **or** SUSPENDED task is skipped identically. `SLEEP` is exactly the
      same status write the completion epilogue `task_exit` already does
      (`multitasker.asm:164-169`) — `SLEEP` is the operator-callable form of that
      park. `WAKE` is its inverse.

### Task 2 — `.TASKS` ring-listing introspection word (AC2, AC3) — `src/multitasker.asm`

- [x] Add `.TASKS` ( -- ) as a DEFCODE word following the **`.BANKS`
      introspection convention** (`src/banking.asm:705-...`): save caller TOS +
      IP (`PUSH BC` / `CALL rpush_de`), run straight-line asm with free use of
      BC/DE/HL, restore, `NEXT`. (`.S`/`.BANKS` are the cited precedents,
      `architecture.md:470-475`.)
- [x] **Anchor the walk at `operator_tcb`** (the static kernel record, a fixed
      address) — that makes the operator deterministically **task 0** (the
      Journey-1 "operator" row) and gives a stable ring terminator. Walk `link`
      (`multitasker.asm:118-123` shows the link-chase shape: `LD A,(HL)/INC HL/
      LD H,(HL)/LD L,A`), incrementing a task index, until `link` returns to
      `operator_tcb`. The ring is circular and always non-empty (operator always
      present), so the walk terminates.
- [x] For each TCB, print a row: **task index** (decimal) + **state string** +
      a **current-task marker** for the row whose base == `(current_tcb)` (mirror
      `.BANKS`'s `'*'`-for-current-bank marker, `banking.asm:752-756`). Map the
      status byte → string via three kernel string constants:
      `TASK_AWAKE`→`"AWAKE"`, `TASK_ASLEEP`→`"ASLEEP"`, `TASK_SUSPENDED`→
      `"SUSPENDED"`. Use `bdos_print_str` (HL=str, B=len) + `bdos_crlf` +
      `bdos_putchar` (E=char) — the same primitives `.BANKS` uses
      (`io.asm:433-449`). The index can reuse `print_bank_col_4` (prints A as
      right-aligned decimal, `banking.asm:857`) or a minimal single-digit emit —
      dev's call; capacity caps tasks well under 10 (≈530 B/task in a few-KB
      bank-0 budget, AD-P6-2), but `print_bank_col_4` is future-proof and already
      present. A one-line header row (e.g. `"TASK STATE"`) is optional — keep it
      if cheap; the AC only requires the per-task rows.
- [x] **SUSPENDED is display-only here.** No task reaches SUSPENDED until Story
      25.6 (exception isolation); `.TASKS` must still render it so 25.6 needs no
      `.TASKS` edit. (`architecture.md:344-361` — 25.6's recovery path calls
      `.TASKS`.)

### Task 3 — Document the deadlock hazard + scope boundaries (AC1) — source comments

- [x] **Document (do not guard in v1)** the cooperative-deadlock hazard: if every
      task in the ring is ASLEEP/SUSPENDED (e.g. the operator `SLEEP`s the only
      other awake task and then its own thread sleeps, or a handle to a
      self-referential ring is slept), `PAUSE`'s walk finds no `TASK_AWAKE` TCB
      and **loops forever** (a hard hang, reset-required). This is the same
      cooperative-failure class as a non-yielding task (FR22, 25.7) — stated
      honestly, not silently capped (`feedback_no_preexisting_discharge`). In
      practice the operator's own handle is never exposed (it is the static
      `operator_tcb`, not a `TASK` return), so `SLEEP` only reaches background
      tasks the operator explicitly created — a natural guard rail; note it.
- [x] **`WAKE` of a SUSPENDED task** flips it AWAKE and it resumes from wherever
      its saved IP points. For a task SUSPENDED by an *uncaught throw* (25.6) that
      resume point may be mid-unwind — the *correct* recovery is redefine + re-
      `ACTIVATE` (FR21, Story 25.6), which rebuilds the resume thread. 25.4's
      `WAKE` is the cooperative ASLEEP→AWAKE resume; note that reviving a
      throw-SUSPENDED task without re-`ACTIVATE` is a 25.6 concern, not supported
      here. Comment discipline: what + why-not-obvious in source; provenance
      (story/CR/date) stays in git/story/ADR/memory
      (`feedback_source_comment_discipline`).

### Task 4 — Probe + Makefile wiring (AC1–AC4) — `tests/multitasker_tasks_tests.fth` (new), `Makefile`

- [x] Add a new probe `tests/multitasker_tasks_tests.fth` (model on
      `tests/multitasker_tests.fth` / `multitasker_key_tests.fth`: column-0-anchored
      self-printed `PASS:`/`FAIL:`, runtime-computed witnesses, header explaining
      the verdict-grep anchoring). Add a Makefile target
      `test-repl-multitasker-tasks` modeled on `test-repl-multitasker-delay`
      (`Makefile:304`): `sed`-CRLF the probe, append `BYE`, pipe through
      `$(IZCPM)` (non-banking iz-cpm is fine — no banking here), wrap in the Story
      24.3 fail-loud `timeout` (a `SLEEP`-induced ring wedge → loud FAIL, not a CI
      hang), verdicts through `tests/assert_verdicts.sh` (Story 24.4 helper —
      `--fail-line '^FAIL:'`, do NOT re-derive the grep/`\r` block). Single-feature
      target; **NOT folded into plain `test-repl`** (matches the 25.1/25.2/25.3
      convention). Keep every probe line **≤ 128 chars** incl. `\` annotations
      (`feedback_tib_size_inline_comments`).
- [x] **Witness set** (all through the threading model, NFR-P6-16 — no raw BDOS):
  - [x] **Words resolve:** `' SLEEP DROP ' WAKE DROP ' .TASKS DROP` → `PASS:
        tasks-words-resolve` (a miss throws -13 before the verdict).
  - [x] **`.TASKS` is `( -- )` / stack-clean:** `DEPTH >R .TASKS DEPTH R> =` →
        `PASS: tasks-dot-clean`. (`.TASKS` prints rows but must not perturb the
        stack.)
  - [x] **AC1 SLEEP skips (discriminating):** reuse the `multitasker_tests.fth`
        TAPE pattern — `' BG TASK` → keep the handle (e.g. `CONSTANT BGT`),
        `ACTIVATE` it, `BGT SLEEP`, then drive several operator `PAUSE`s and
        assert the BG accumulator did **not** advance (BG was skipped) → `PASS:
        tasks-sleep-skips`. Reverting `SLEEP` (no status write) makes BG run and
        this FAILs — i.e. genuinely discriminating.
  - [x] **AC1 WAKE resumes:** `BGT WAKE`, drive operator `PAUSE`s, assert the BG
        accumulator advanced → `PASS: tasks-wake-resumes`. (Design the BG word so
        it has remaining work to do after the wake — e.g. a long counting loop
        with a `PAUSE` per iteration, not the 2-shot `BG` from 25.1.)
  - [x] **AC2/AC3 `.TASKS` output (printed-witness via the harness):** bracket a
        `.TASKS` call with unique runtime sentinels the probe prints at col 0
        (e.g. `." ==TASKS-BEGIN==" CR .TASKS ." ==TASKS-END==" CR`), and have the
        Makefile `assert_verdicts` **require the state-string rows** emitted
        between them (the Journey-1 witness: operator + a background task both
        `AWAKE`; after a `SLEEP`, an `ASLEEP` row). The state literals are
        **runtime output of `.TASKS`**, never present in the echoed source as a
        matchable token, so their presence proves `.TASKS` executed and rendered
        the table — false-green-safe (the 23.2 column-anchoring lesson). Finalize
        the exact required strings/anchors when the row format is fixed.
  - [x] **Interpreter healthy after:** `1 2 3 + + . = 6` / `DEPTH 0=` → `PASS:
        tasks-alive` (runtime-computed token, not a bare sentinel).
- [x] Run `make lint-banking-probes` / the straddle guard (Story 24.3). This story
      grows the kernel by ~+200 B (see envelope) — a meaningful bump, so
      **re-check that late `banking_tests.fth` colon-body probes did not cross
      `$8000`** (`feedback_banking_probe_straddle_halt`). If they did, fix the
      **probe** (drive at interpret level, assert printed witnesses), not the
      feature.
- [x] Full `make test` gate green; record the binary delta (`wc -c` after −
      before) in Dev Notes against the proposed envelope (Q3).

### S9 hardware smoke (post dev-pass — recipe in the close-out chat message)

- [ ] On real CP/M 2.2 / MicroBeast (per the **STRONG**
      `feedback_post_hw_smoke_steps_at_review` commitment, post the exact recipe in
      the closing chat message, not only here):
  - [ ] **`.TASKS` Journey-1 (AC3):** `TASK LIGHTS` (or any BG word), `' …
        LIGHTS ACTIVATE`, then `.TASKS` shows the operator + `LIGHTS` both AWAKE
        at the live prompt; the table renders legibly in 80 cols.
  - [ ] **SLEEP/WAKE round-trip (AC1):** `LIGHTS SLEEP` → the background activity
        visibly stalls and `.TASKS` shows it `ASLEEP`; `LIGHTS WAKE` → it resumes
        and `.TASKS` shows it `AWAKE` again; the operator REPL stays responsive
        throughout.

## Dev Notes

### Architecture provenance (read these first)

- **AD-P6-1** (per-task state model; `.TASKS` in MVP) —
  `architecture.md:245-274`; the `.TASKS` convention note (`.`-prefix, like
  `.S`/`.BANKS`) at `:470-475`; FR25 introspection scope at `:68`.
- **AD-P6-3** (scheduler / `PAUSE` walk skips non-AWAKE) — `architecture.md:324-342`,
  esp. step 3 "walk `link` to the next TCB whose `status = AWAKE` (skip
  ASLEEP/SUSPENDED)". This is the mechanism `SLEEP`/`WAKE` drive — already live in
  `multitasker.asm:115-131`; this story adds **no** scheduler code.
- **AD-P6-4** (exception isolation, Story 25.6) — `architecture.md:344-361`: the
  recovery path explicitly calls `.TASKS` and relies on the SUSPENDED state. 25.4
  must render SUSPENDED (display-only) so 25.6 needs no `.TASKS` edit.
- **AD-P6-2** (TCB layout / status field) — `architecture.md:276-322`; the live
  field offsets are the `TCB_*` EQUs in `src/constants.asm:106-130`
  (`TCB_STATUS = 2`; `TASK_ASLEEP=0`, `TASK_AWAKE=1`, `TASK_SUSPENDED=2` at
  `:126-128`).
- The 5 Phase-6 locks + bring-up order live in
  `project_phase6_concurrency_direction`; the two load-bearing register/stack-base
  gotchas from 25.1 live in `project_multitasker_pause_register_contract`.

### The whole story is three small words over the existing ring

The scheduler already has everything: the ring (`link`), the status byte
(`TCB_STATUS`), the AWAKE-only walk, and `current_tcb`. This story is purely
*surface*:

- **`SLEEP` / `WAKE`** = a single status-byte write each. They are the
  operator-callable twins of the `task_exit` epilogue (`multitasker.asm:164-169`),
  which already writes `TASK_ASLEEP` at `(current_tcb)+2`. The only differences:
  `SLEEP`/`WAKE` target an *arbitrary* task by handle (TOS), not `current_tcb`,
  and `WAKE` writes `TASK_AWAKE`. Sketch (`SLEEP`; `WAKE` identical with
  `TASK_AWAKE`):

  ```
  w_SLEEP:
          DEFCODE "SLEEP", 0
  w_SLEEP_cf:
          LD      H, B
          LD      L, C            ; HL = task (TCB base, the TOS)
          INC     HL
          INC     HL              ; -> status (+2 = TCB_STATUS)
          LD      (HL), TASK_ASLEEP
          POP     BC              ; new TOS
          NEXT                    ; DE=IP untouched throughout (25.1 gotcha #1)
  ```

- **`.TASKS`** = a read-only ring walk anchored at `operator_tcb`, printing one
  row per TCB via the `.BANKS` print primitives. No state is mutated; it saves the
  caller's TOS+IP like `.BANKS` and runs straight-line asm.

### Register / TOS conventions (25.1 gotcha #1 applies)

- BC = TOS, DE = IP, IX = return stack, IY = UserArea (never reassigned), SP =
  data stack (`project_tos_in_register`; `register-conventions.md` Hard Rule #1).
- **25.1 gotcha #1 (preserve DE=IP):** **APPLIES** to all three words — unlike
  `PAUSE` (the one exempt word, which swaps DE through the TCB by design), these
  are normal task words. `SLEEP`/`WAKE` naturally preserve DE (they never touch
  it). `.TASKS` uses DE freely in its body **but** brackets it with `CALL
  rpush_de` / a matching restore (the `.BANKS` pattern) so DE=IP is intact at
  `NEXT`. Do NOT leave DE clobbered.
- **25.1 gotcha #2 (`sp_base` is per-task):** not relevant — none of these words
  carve stacks or run a background depth-guarded path; `.TASKS`'s `PUSH BC` /
  `rpush_de` use the operator's own stacks while the operator is current.
- No `BDOS_SAVE`/`BDOS_RESTORE` dance beyond what `bdos_print_str`/`bdos_putchar`
  already encapsulate (the `.BANKS` precedent makes BDOS console calls from a
  DEFCODE introspection word with no extra ceremony).

### `.TASKS` output format (follow `.BANKS`, keep it cheap)

The AC requires only "each task and its state" + the Journey-1 "operator and a
background task both awake". A minimal, convention-consistent format:

```
TASK STATE          (optional header)
   0 * AWAKE         ('*' = current task, like .BANKS' current-bank marker)
   1   AWAKE
   2   ASLEEP
```

- Task **0 = the operator** (the `operator_tcb` anchor) — documented, matches the
  "task N" numbering AD-P6-4/Story 25.6 will reuse for `task N: error <n>`. 25.4
  *owns* this numbering = ring position from `operator_tcb`; 25.6 reuses it.
- Numeric columns forced **decimal** is not required here (no BASE-sensitive
  multi-digit table like `.BANKS`), but using `print_bank_col_4` gives a stable
  decimal index for free. Single-digit emit (`'0'+N`) is acceptable given the
  capacity cap — note the ≥10-task cliff if you take that shortcut.
- State strings are three kernel `DB`-length-prefixed constants reused by the
  status→string map. SUSPENDED is rendered but not produced until 25.6.

### Test strategy — behavioral transitions are the rigorous part

`.TASKS` returns nothing, so its *printed table* can only be asserted by the
harness grepping the emulator's stdout (printed-witness, NFR-P6-16) — the AC's
"`.TASKS` output via printed witnesses". The **discriminating** assertions are the
WAKE/SLEEP *behavioral* transitions, asserted exactly like the 25.1 TAPE
round-robin witness:

- `SLEEP` a background counter task → drive operator `PAUSE`s → its accumulator
  must **not** advance (proves the walk skipped it). Revert the `SLEEP` status
  write and this FAILs.
- `WAKE` it → drive `PAUSE`s → the accumulator advances (proves it rejoined the
  rotation).

These run fully under the emulator (no timer/interrupt dependency — explicit
`PAUSE`, like `multitasker_tests.fth`). The `.TASKS` table rows are the
supplementary printed witness (Journey-1: two AWAKE rows; an ASLEEP row after a
SLEEP). Reuse `tests/assert_verdicts.sh --mode anchored` + the 24.3 fail-loud
`timeout`; ≤128-char lines; reviews are adversarial by design
(`feedback_adversarial_review`), and the `CR` command runs separately at story
close (NOT an AC — PD-1).

### Binary-size envelope (sprint-planning carry-forward F5 — proposed here)

Per-component itemisation (B.2 — each component costed *independently* from its
own opcodes; **no "mirrors prior arm" shorthand**). DEFCODE header =
`hash_link(2) + bank(1) + count_flags(1) + name(N)`; `NEXT` macro = 7 B
(`EX DE,HL` + `NEXTHL`'s 6, `src/macros.asm:32-46`).

| Component | Itemisation | Est. bytes |
|---|---|---|
| `SLEEP` CODE word | header 9 (name "SLEEP"=5) + body: `LD H,B`/`LD L,C` (2) + `INC HL`×2 (2) + `LD (HL),0` (2) + `POP BC` (1) + `NEXT` (7) = 14 | +23 |
| `WAKE` CODE word | header 8 (name "WAKE"=4) + body 14 (as `SLEEP`, immediate = `TASK_AWAKE`) | +22 |
| `.TASKS` header + frame | header 10 (name ".TASKS"=6) + `PUSH BC`/`CALL rpush_de` save (4) + restore+`NEXT` (~12) | +26 |
| `.TASKS` ring-walk + index print | `LD HL,operator_tcb` (3) + index counter init/inc (≈4) + per-iter link-chase (`LD A,(HL)/INC/LD H,(HL)/LD L,A` ≈6) + terminator compare to `operator_tcb` (≈8) + index decimal print call (≈5) | +30 |
| `.TASKS` status→string map + marker | load status byte (≈4) + 3-way compare→str-ptr select (≈18) + current-task `'*'` marker compare to `(current_tcb)` (≈12) + `bdos_print_str`/`bdos_putchar`/`bdos_crlf` calls (≈12) | +46 |
| 3 state-string constants | `"AWAKE"`(5)+`"ASLEEP"`(6)+`"SUSPENDED"`(9) + 3 length bytes + optional `"TASK STATE"` header (~12) | +35 |
| Comments (hazard + scope) | 0 (comments) | 0 |
| **Subtotal (raw)** | | **~+182** |
| ×1.25 register-juggle overshoot, `.TASKS` body only (string-select + marker + walk juggle; `feedback_kernel_ldir_estimate_overshoot`) | applied to the ~+76 B `.TASKS` walk+map portion → +19 | +19 |
| **Total** | | **~+200 B** |

**Proposed Story-25.4 envelope: ~+200 B** (range **+175..+230**),
accept-with-rationale, no silent bloat (NFR-P6-10). The two status-flip words are
trivial (no register juggle → no multiplier); `.TASKS` carries the cost and the
×1.25 overshoot. Record the actual `wc -c` delta at dev-pass close (Q3). This is
well inside the Phase-6 per-epic envelope (NFR-P6-11) and pushes no banking probe
across `$8000` only if Task 4's straddle re-check confirms it (a ~200 B bump is
the first Epic-25 story large enough to plausibly shift a late colon-body probe —
verify, don't assume).

### Hazards to document (not guard in v1)

- **Cooperative deadlock if no task is AWAKE.** `PAUSE`'s walk loops until it
  finds `TASK_AWAKE`; if the operator `SLEEP`s the last awake task (or sleeps
  itself via an exposed handle), the walk never terminates = hard hang,
  reset-required. Same class as the non-yielding-task stall (FR22, 25.7).
  Mitigated in practice because the operator's handle is the static
  `operator_tcb`, never a `TASK` return value — `SLEEP` only reaches background
  tasks. Document; don't guard.
- **`WAKE` of a throw-SUSPENDED task** resumes from its saved IP, which may be
  mid-unwind for a task SUSPENDED by 25.6's exception path — proper recovery is
  redefine + re-`ACTIVATE` (FR21, 25.6). 25.4's `WAKE` is the cooperative
  ASLEEP→AWAKE resume only.
- **`FORGET`/`MARKER` past an active task's TCB** reclaims its storage (AD-P6-2
  hazard, `project_banked_marker_no_stub`) — unchanged by this story; a stale
  handle passed to `SLEEP`/`WAKE`/`.TASKS` after a reclaim is undefined. Document.
- **Interactive line-editing vs. a chatty background task** (surfaced in 25.4
  HW/UAT, 2026-06-30; project-lead disposition = document-as-known-limitation).
  Because `EMIT` does not yield (locked), a background task that prints between
  keystrokes (the line reader's `KEY` `PAUSE`s in the gaps) moves the terminal
  cursor out from under `(EDIT)`; the backspace erase (`SPACE BS`) then rubs out
  a background glyph rather than the operator's char, so the *visible* line
  diverges from the input buffer and the operator can no longer correct by eye.
  Verified **display desync, not buffer corruption**: the per-task line state
  rides the data stack (PAUSE keeps it private) and a background task touches
  only the shared console, never the operator's buffer — single-task backspace/
  DEL/multi-correction/column-0 all parse correctly. Not a 25.4 mechanism (no
  edit to the editor / `EMIT` / `KEY`); `WAKE` merely makes a chatty task
  reachable at the prompt. Mitigation: `SLEEP` output-heavy tasks before typing
  a definition. Documented in `src/io.asm` at `(LINE)`. Real console-output
  coordination is future work (fits 25.7/25.8).

### Scope boundaries (explicitly deferred — do not implement here)

- ❌ Per-bank re-page on switch (`MBB_SET_PAGE`) → **Story 25.5** (`PAUSE` still
  saves/restores `current_bank` as a cell only).
- ❌ Background-task exception isolation / the **SUSPENDED-producing** path →
  **Story 25.6** (25.4 only *renders* SUSPENDED + provides the `.TASKS`/`WAKE`
  recovery surface it consumes).
- ❌ Keyboard break / `break_pending` / fn-6 / Ctrl-C → **Story 25.7**.
- ❌ Headline background-traffic-light demo → **Story 25.8**.
- ❌ Any change to `PAUSE`, `TASK`, `ACTIVATE`, the ring walk, or the TCB layout
  (Story 25.1, frozen — this story only *reads* the ring and *writes the status
  byte* those words already defined).
- ❌ Configurable per-task naming / labels for `.TASKS` (numeric index only in
  MVP; named tasks = Vision).
- ❌ Re-`ACTIVATE`-based recovery of a faulted task (FR21) → **Story 25.6**.

### Project Structure Notes

- **Edit:** `src/multitasker.asm` (add `SLEEP`/`WAKE`/`.TASKS` + 3 state-string
  constants; place near `task_exit`/`ACTIVATE`, before the closing
  `ASSERT $ <= SLOT2_WINDOW_BASE` at `:297` — the new words must stay below
  `$8000`, and the assert already guards that), `Makefile` (new
  `test-repl-multitasker-tasks` target + `.PHONY` entry, modeled on
  `test-repl-multitasker-delay:304`), `tests/multitasker_tasks_tests.fth` (new
  probe).
- **Read-only references:** `src/multitasker.asm` (`PAUSE` walk `:115-131`,
  `task_exit` status write `:164-169`, `current_tcb`/`operator_tcb` `:26,:32`),
  `src/banking.asm` (`.BANKS` introspection pattern `:705-...`, `print_bank_col_4`
  `:857`, current-marker `:752-756`), `src/io.asm` (`bdos_putchar:433`,
  `bdos_crlf:438`, `bdos_print_str:449`), `src/constants.asm` (TCB EQUs `:106-128`),
  `src/antforth.asm` (COLD ring init `:280-284`), `tests/multitasker_tests.fth`
  (the TAPE round-robin / status witness pattern to reuse).
- No new module, no directory reorganization; flat `src/*.asm` preserved. The
  module-end `ASSERT $ <= SLOT2_WINDOW_BASE` (`multitasker.asm:297`) fails the
  build if the +200 B pushes the scheduler across `$8000` (kernel-growth guard).
- **Comment discipline:** what + why-not-obvious in source; provenance stays in
  git/story/ADR/memory (`feedback_source_comment_discipline`).

## Open Questions (for project lead — saved for the end, per workflow)

1. **`.TASKS` row format.** Proposed: `"   N M STATE"` per row (N = decimal index,
   M = `'*'` for the current task else space, STATE ∈ {AWAKE, ASLEEP, SUSPENDED}),
   task 0 = operator, optional `"TASK STATE"` header. **Recommendation: accept**
   the `.BANKS`-style marker + decimal index; keep an optional header only if it
   costs <15 B. Confirm, or specify a different layout.
2. **`SLEEP`/`WAKE` self-safety.** Should `SLEEP` refuse to sleep the operator /
   the last awake task (a guard against the documented deadlock), or stay
   unguarded-but-documented like the rest of the cooperative model?
   **Recommendation: unguarded + documented** — consistent with FR22's "observable
   documented stall, not silent corruption", cheaper, and the operator handle is
   never exposed so the realistic footgun is small. A guard costs a ring-scan per
   `SLEEP`. Confirm.
3. **Envelope (F5).** Confirm the proposed **~+200 B** Story-25.4 envelope
   (`SLEEP` ~23 + `WAKE` ~22 + `.TASKS` ~155 incl. ×1.25 on its juggle portion).
   Record the actual `wc -c` delta at close.

## References

- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story-25.4] (lines 295–308)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-1] (per-task state, `.TASKS` in MVP, 245–274; `.`-introspection convention 470–475; FR25 scope 68)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-3] (scheduler / PAUSE walk skips non-AWAKE, 324–342)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-4] (exception isolation consumes `.TASKS` + SUSPENDED, 344–361; task-N numbering)
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-2] (TCB layout / status field, 276–322)
- [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md] (FR3, FR7, FR25, NFR-P6-16/-17)
- [Source: src/multitasker.asm] (PAUSE ring-walk skips non-AWAKE:115–131; `task_exit` status write:164–169; `current_tcb`:26; `operator_tcb`:32; module-end $8000 ASSERT:297)
- [Source: src/constants.asm] (TCB EQUs:106–123; `TASK_ASLEEP`/`TASK_AWAKE`/`TASK_SUSPENDED`:126–128)
- [Source: src/banking.asm] (`.BANKS` introspection convention to mirror:705–...; `print_bank_col_4`:857; current-row `'*'` marker:752–756)
- [Source: src/io.asm] (`bdos_putchar`:433, `bdos_crlf`:438, `bdos_print_str`:449)
- [Source: src/macros.asm] (`NEXT`/`NEXTHL`:32–46; `DEFCODE` header bytes:66–86 — for the byte itemisation)
- [Source: src/antforth.asm] (COLD ring init:280–284 — operator_tcb wired AWAKE/link=self)
- [Source: tests/multitasker_tests.fth] (the TAPE round-robin / status witness pattern + column-0 anchoring to reuse)
- [Source: _bmad-output/implementation-artifacts/25-1-pause-circular-ring-task-activate-single-bank-fixed-memory.md] (ring/TCB/status this story drives; the two register/sp_base gotchas)
- [Source: _bmad-output/implementation-artifacts/25-3-yielding-per-task-delay.md] (the prior story; probe/Makefile/timeout idioms to reuse)
- Memory: `project_phase6_concurrency_direction`, `project_multitasker_pause_register_contract`,
  `project_tos_in_register`, `feedback_kernel_ldir_estimate_overshoot`,
  `feedback_banking_probe_straddle_halt`, `feedback_tib_size_inline_comments`,
  `feedback_source_comment_discipline`, `feedback_post_hw_smoke_steps_at_review`,
  `feedback_no_preexisting_discharge`, `feedback_adversarial_review`,
  `feedback_testing_rules`, `feedback_repl_tests_preferred`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (create-story workflow, 2026-06-30)

### Open-Question resolutions (project lead, 2026-06-30 — at story creation)

1. **`.TASKS` row format?** → **Accepted (recommendation).** Per-row
   `"   N M STATE"` — N = decimal index, M = `'*'` for the current task else
   space, STATE ∈ {AWAKE, ASLEEP, SUSPENDED}; **task 0 = the operator**
   (`operator_tcb` anchor). Optional `"TASK STATE"` header kept only if it costs
   <15 B. `.BANKS`-style current-row marker + decimal index.
2. **`SLEEP`/`WAKE` self-safety?** → **Unguarded + documented (recommendation).**
   No ring-scan guard against sleeping the operator / the last awake task —
   consistent with FR22's "observable documented stall, not silent corruption",
   cheaper, and the operator handle is never exposed (`operator_tcb` is static,
   never a `TASK` return), so the realistic footgun is small. The no-awake-task
   deadlock is the documented Task-3 hazard.
3. **Envelope (F5)?** → **~+200 B confirmed** (`SLEEP` ~23 + `WAKE` ~22 +
   `.TASKS` ~155 incl. ×1.25 on its walk/map juggle portion; range +175..+230).
   Record the actual `wc -c` delta at dev-pass close.

### Debug Log References

- Build clean (sjasmplus 0 errors / 0 warnings); module-end `ASSERT $ <= SLOT2_WINDOW_BASE`
  held (the +190 B did not push the scheduler across `$8000`).
- Smoke (interpret-level, iz-cpm): `.TASKS` on a length-1 ring → `   0 * AWAKE`; after
  `' BG TASK DUP CONSTANT BGT ACTIVATE` → two rows (`   0 * AWAKE` / `   1   AWAKE`);
  `BGT SLEEP` → row 1 `ASLEEP`; `BGT WAKE` → row 1 `AWAKE`.
- Discriminating behaviour confirmed: `BGT SLEEP 0 CTR ! DRV5` → `CTR=0` (walk skipped
  BG); `BGT WAKE 0 CTR ! DRV5` → `CTR=5` (5 PAUSEs = 5 BG bumps).
- Loop-word note: `AGAIN` is not defined in this build; the background task uses
  `BEGIN BUMP PAUSE 0 UNTIL` (0 = false → never exits) as the forever-loop form.

### Completion Notes List

- **`SLEEP` / `WAKE`** ( task -- ) added as DEFCODE words in `src/multitasker.asm`: each
  writes the status byte at `(task+TCB_STATUS=2)` — `SLEEP`→`TASK_ASLEEP`, `WAKE`→
  `TASK_AWAKE` — then `POP BC` for the new TOS and `NEXT`. Body uses only A/BC/HL, so
  DE=IP is untouched (25.1 gotcha #1 holds with no save/restore). No new scheduler logic:
  `PAUSE`'s existing walk (`multitasker.asm`) terminates on `status == TASK_AWAKE`, so a
  non-AWAKE task is skipped automatically. `SLEEP` is the operator-callable twin of the
  `task_exit` epilogue's status write.
- **`.TASKS`** ( -- ) added as a DEFCODE introspection word following the `.BANKS`
  convention: `PUSH BC` / `CALL rpush_de` save, straight-line ring walk, `rpop_de` / `POP
  BC` restore, `NEXT`. Anchored at the static `operator_tcb` (operator = deterministic
  task 0 + stable terminator); walks `link` incrementing a decimal index until back at
  `operator_tcb`. Each row: `print_bank_col_4` index + `'*'`/`' '` current-task marker
  (compared to `current_tcb`, mirroring `.BANKS`) + state string (`AWAKE`/`ASLEEP`/
  `SUSPENDED`) via `bdos_print_str`/`bdos_putchar`/`bdos_crlf`. SUSPENDED is rendered but
  not produced until Story 25.6 (display-only).
- **Row format** (Q1 resolution): `"   N M STATE"` — `print_bank_col_4` (4-char decimal
  index, future-proof to 29 tasks) + space + marker + space + state string. **No header**
  row: a `"TASK STATE"` header (string + print code ≈ 22 B) exceeds the Q1 "<15 B" gate,
  so it was dropped — the AC requires only the per-task rows.
- **Self-safety** (Q2 resolution): `SLEEP`/`WAKE` are unguarded + documented. The
  no-AWAKE-task cooperative deadlock and the `WAKE`-of-throw-SUSPENDED (→ 25.6 re-ACTIVATE)
  boundary are documented in source comments (what + why; provenance stays in git/story).
- **3 state-string constants** (`AWAKE`/`ASLEEP`/`SUSPENDED`, length-prefixed by EQU)
  added below the `$8000` ASSERT.
- **`>TASK`** ( n -- task ) added (project-lead request during review, 2026-06-30) as a
  companion to `.TASKS`: walks the ring `n` links from `operator_tcb` and returns that TCB
  base, so the operator can `SLEEP`/`WAKE` a task by the index `.TASKS` prints without
  having stashed its handle (`1 >TASK SLEEP`). Body uses only A/BC/HL (DE=IP preserved) +
  `check_underflow`. `n=0` = operator; `n` past the last task wraps the circular ring
  (always a live TCB). Probe witness `tasks-index-to-handle` (`BGT 1 >TASK =`).
- **Binary delta: +190 B** for the three spec'd words (30,040 → 30,230 B); **+35 B** for
  the `>TASK` companion → **+225 B total** (30,040 → 30,265 B), inside the confirmed F5
  envelope (range +175..+230, Q3).
- **Probe** `tests/multitasker_tasks_tests.fth` (new) + Makefile target
  `test-repl-multitasker-tasks` (+ `.PHONY`): 5 column-0 PASS verdicts
  (`tasks-words-resolve`, `tasks-dot-clean`, `tasks-sleep-skips`, `tasks-wake-resumes`,
  `tasks-alive`) + 2 `--present` runtime-row witnesses (`^   1   AWAKE` Journey-1,
  `^   1   ASLEEP` post-SLEEP). All 7 PASS. Single-feature target, NOT folded into plain
  `test-repl` (matches 25.1/25.2/25.3).
- **Gates green:** `make test` (regression), `test-repl-timer`/`-multitasker`/
  `-multitasker-key`/`-multitasker-delay` (no regression), `test-straddle-regression`
  (rc=0 — the +190 B pushed no late banking colon-body probe across `$8000`),
  `lint-banking-probes` PASS, `test-repl-banking` 60 PASS / 0 FAIL.
- **No TCB layout change** → `src/structures.asm` doc-STRUCT untouched (Story 25.1 frozen).
- **Deferred:** S9 hardware smoke (recipe in close-out chat message,
  `feedback_post_hw_smoke_steps_at_review`).

### File List

- `src/multitasker.asm` — added `SLEEP`, `WAKE`, `.TASKS`, `>TASK` DEFCODE words + 3
  state-string constants (`str_task_awake`/`_aslp`/`_susp`), before the module-end `$8000`
  ASSERT.
- `src/io.asm` — documentation only: a KNOWN-LIMITATION note at `(LINE)` on the interactive
  line-editor vs. chatty-background-task cursor desync (comment-only, byte-identical).
- `tests/multitasker_tasks_tests.fth` — new probe (SLEEP/WAKE behavioural witnesses,
  `.TASKS` printed-row witnesses, `>TASK` index→handle round-trip).
- `Makefile` — new `test-repl-multitasker-tasks` target + `.PHONY` entry.
- `build/antforth.com` — rebuilt artifact (30,265 B).

## Change Log

| Date | Change |
|---|---|
| 2026-06-30 | Review-time additions (project-lead requests): (1) documented the interactive line-editor vs. chatty-background-task cursor desync as a KNOWN LIMITATION (`src/io.asm` `(LINE)` comment + Dev-Notes hazard) — verified display-desync not buffer corruption (single-task BS/DEL/multi-correction all parse correctly); disposition = document, no fix (cooperative EMIT-no-yield model; real console coordination is 25.7/25.8). (2) Added `>TASK` ( n -- task ) companion to `.TASKS` (index→handle so `1 >TASK SLEEP` works without a saved handle); +35 B → **+225 B total** (30,265 B), still inside the F5 envelope; probe gains `tasks-index-to-handle`. All gates re-run green (regression, straddle rc=0, multitasker-tasks 8/8, prior probes 5/5/6). |
| 2026-06-30 | Story 25.4 implemented (dev-story): `SLEEP`/`WAKE` status-flip CODE words + `.TASKS` ring-listing introspection in `src/multitasker.asm`; 3 state-string constants. No new scheduler mechanism. Row format `"   N M STATE"`, task 0 = operator, no header (>15 B gate). New probe `tests/multitasker_tasks_tests.fth` + `test-repl-multitasker-tasks` target — 5 PASS verdicts + 2 runtime-row `--present` witnesses, all green. Binary +190 B (30,040 → 30,230), inside the ~+200 B envelope. Regression/straddle/lint/banking gates green. Status → review. S9 hardware smoke deferred (recipe in close-out). |
| 2026-06-30 | All 3 open questions resolved by project lead at story creation (all recommended): `.TASKS` row format = `.BANKS`-style `"   N M STATE"`, task 0 = operator, optional header if <15 B; `SLEEP`/`WAKE` unguarded + documented (no-awake-task deadlock is the Task-3 hazard); ~+200 B envelope confirmed. Resolutions pinned in Dev Agent Record. |
| 2026-06-30 | Story 25.4 drafted (create-story): `SLEEP`/`WAKE` status-flip CODE words + `.TASKS` ring-listing introspection. No new scheduler mechanism — `PAUSE`'s walk already skips non-AWAKE; `SLEEP`/`WAKE` write the status byte (`TCB_STATUS=2`) the walk honours, `.TASKS` reads the ring (anchored at `operator_tcb`, task 0 = operator) and prints rows via the `.BANKS` print primitives. Documented the no-awake-task deadlock hazard + `WAKE`-of-SUSPENDED → 25.6-re-ACTIVATE boundary. New probe `tests/multitasker_tasks_tests.fth` + `test-repl-multitasker-tasks` target: discriminating WAKE/SLEEP behavioral witnesses (TAPE-style) + `.TASKS` printed-table witness. Per-component byte itemisation → proposed ~+200 B envelope. 3 open questions (row format / self-safety guard / envelope). Status → ready-for-dev. |
