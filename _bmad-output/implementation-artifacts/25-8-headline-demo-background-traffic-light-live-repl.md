# Story 25.8: Headline demo — background traffic light + live REPL

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Epic 25 capstone — assemble the shipped parts into the headline moment.** Stories
> 25.1–25.7 built the whole cooperative spine: `PAUSE` + circular ring + `TASK`/`ACTIVATE`
> (25.1), the KEY-hooked yielding REPL (25.2), yielding per-task `DELAY` (25.3),
> `SLEEP`/`WAKE`/`.TASKS` (25.4), per-bank switching (25.5), background-fault isolation
> (25.6), and the keyboard break + documented starvation (25.7). Epic 24 shipped the 64 Hz
> `TICKS` clock, `TIMER-ON`/`TIMER-OFF`, and the seconds `DELAY`/`MS`. **This story writes no
> new kernel word.** It productizes the Phase-5 `disk/a/TRAFFIC.FTH` prototype into the
> *background-task sequel* the whole phase was built to enable (FR26, the headline
> acceptance; NFR-P6-6, the MVP gate), ships it as a runnable/tutorial asset, proves the
> structure under emulation with a probe, and validates the real "lights cycle while the
> prompt stays live" experience on silicon (S9).

## Story

As a tutorial reader,
I want to load the traffic-light demo as a background task and keep using the prompt,
so that I experience cooperative multitasking on an 8-bit machine first-hand.

## Acceptance Criteria

(BDD sourced from `_bmad-output/planning-artifacts/epics-phase6-epics-24-26.md` Story 25.8,
lines 369–382. Cross-refs: FR26 (headline acceptance), FR10–FR12 (live REPL concurrency),
FR14/FR15 (yielding `DELAY`), FR25 (`.TASKS`); NFR-P6-6 (S9 MVP gate), NFR-P6-7 (fault
containment), NFR-P6-16 (REPL-piped testing). Journeys 1 & 4, PRD lines 197–206, 228–236.)

1. **AC1 — the demo runs as a background task; the prompt returns immediately (FR26, the
   headline acceptance; FR10–FR12).**
   **Given** the full scheduler (Stories 25.1–25.7) and Epic 24's timer/hardware words in the
   shipped kernel,
   **When** the operator loads the demo asset, creates the task (`TASK CONSTANT LIGHTS` — see
   the Dev Note "the epic's `TASK LIGHTS` is shorthand"), defines the light-cycling word, and
   arms it (`' RUN-LIGHTS LIGHTS ACTIVATE`),
   **Then** the LEDs cycle on tempo **while the `ok` prompt returns immediately and stays
   responsive** — the operator defines and evaluates new words while the lights keep time,
   because the light task yields at each `DELAY` (kernel `DELAY` → `(DELAY)` → `PAUSE`, Story
   25.3) and the REPL yields in its input wait (Story 25.2). *(The on-tempo cycling and
   "returns immediately" timing are the S9 deliverable per AC4 — the emulator cannot advance
   `TICKS`; see the Dev Note "Emulator vs hardware split.")*

2. **AC2 — `.TASKS` shows the operator and `LIGHTS` both awake (FR25).**
   With the light task activated, `.TASKS` renders **both** the operator row (task 0, the
   `*` current marker) and the `LIGHTS` row (task 1) as `AWAKE` — the Journey-1 "the machine
   does two things at once" witness. The row format is the Story-25.4 `"   N M STATE"` shape
   (no header): `   0 * AWAKE` / `   1   AWAKE`.

3. **AC3 — background, not terminal-hijacking; `4 DELAY` does not freeze the prompt
   (FR14/FR15, vs the Phase-5 version).**
   The sequel is a genuine background task, contrasted explicitly with the Phase-5
   `TRAFFIC.FTH` that ran a `BEGIN … AGAIN` loop *directly* and hijacked the terminal until a
   reset. A `4 DELAY` inside the light loop **visibly does not freeze the operator prompt** —
   the operator keeps typing and getting results while a `DELAY` is pending (the FR14 "yielding
   DELAY" payoff, Journey 4). The sequel **must not** redefine `DELAY` (it uses the kernel's
   yielding word) and **must not** install its own ISR (it uses kernel `TIMER-ON`); it must use
   a terminable forever-loop form (`BEGIN … 0 UNTIL`, **not** `BEGIN … AGAIN` — `AGAIN` is
   undefined in antforth; confirmed by the 25.7 S9 capture, `25-7…md:539–540`).

4. **AC4 — S9 MVP gate + tutorial/example asset + binary delta (NFR-P6-6).**
   The headline demo **PASSES on real CP/M 2.2 / MicroBeast hardware** over the operator's
   serial TTY (the MVP acceptance gate, NFR-P6-6, PRD line 174): the LEDs cycle on tempo, the
   prompt returns immediately and stays responsive, `.TASKS` shows both tasks `AWAKE`, and
   `4 DELAY` demonstrably does not freeze the prompt. A **tutorial/example asset is provided**
   (the rewritten background-task demo file, self-documenting, plus a short demo-recipe writeup
   — see Task 3 for placement). The **binary delta is recorded** — this story is expected to
   be **0 kernel bytes** (demo asset + probe + docs only); if any kernel byte moves, itemise
   why (B.2, `feedback_no_preexisting_discharge`).

5. **AC5 — structural REPL probe (NFR-P6-16, NFR-P6-7).** A REPL-piped probe demonstrates,
   under emulation, everything the emulator *can* prove (the tempo/timing is S9, AC4):
   - the demo pattern **activates cleanly**: `TASK CONSTANT LIGHTS`, define the light word,
     `' RUN-LIGHTS LIGHTS ACTIVATE` — no throw, stack clean;
   - `.TASKS` renders **both** the operator `AWAKE` row and the `LIGHTS` `AWAKE` row (assert
     the runtime `^   1   AWAKE` row — absent from the echoed source, so its presence proves
     `.TASKS` executed; the 23.2 false-green defence);
   - the light task **yields and does not monopolize**: the operator keeps making progress
     (a runtime token echoes; a free-running background counter advances) across the light
     task's pending `DELAY` — the 25.3 `delay-no-monopoly` pattern, proving FR14/FR15 and
     NFR-P6-7 (one task cannot starve the ring while yielding);
   - the operator survives **stack-clean** after the interleave (`DEPTH 0=` + an arithmetic
     witness).
   Emit `PASS:` verdicts (column-0 anchored, the 23.2/24.4 convention) wired to a single-feature
   Makefile target (mirroring the 25.3/25.4 recipes); wrap the emulator pipe in the Story-24.3
   fail-loud `timeout` (a wedged ring → loud FAIL, not a silent CI hang). Guard TIB ≤ 128 chars
   (NFR-P6-16/-17) and dodge the `$8000` straddle-halt (interpret-level `'`, printed witnesses —
   `feedback_banking_probe_straddle_halt`).

**Operator-only-compile lock (FR24) — standing constraint, not a new AC:** the demo's word
definitions (`TASK CONSTANT LIGHTS`, `: RUN-LIGHTS …`) are all **operator** activities at the
prompt (or via `INCLUDE`, which runs at the operator); the background light task executes
**pre-compiled words only** and writes nothing to HERE/LATEST/wordlist/triple. No new
background-compile path is introduced.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev Notes.
      **Do not inherit the figure below** — re-`wc -c` from an actual clean rebuild at dev-pass
      start (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). At story-drafting
      time (2026-07-01) the committed build artifact measured **30,438 B** (HEAD = `3bf963d`).
      **This story is expected to leave that number unchanged** (0 kernel bytes) — the pre/post
      comparison is the *proof* of the 0-delta claim, not a formality.
- [x] Capture the full `make test-repl` baseline pass count (the 0-FAIL floor, NFR-P6-5) and the
      Epic-24/25 single-feature targets so a no-regression is provable: `test-repl-timer`,
      `test-repl-multitasker`, `-multitasker-key`, `-multitasker-delay`, `-multitasker-tasks`,
      `-multitasker-throw`, `-multitasker-break`, `-multitasker-bank`, `test-repl-banking`,
      `test-straddle-regression`, `lint-banking-probes`, `check-doc-sync`, `test-file-sanity`.

### Task 1 — Rewrite the demo as the background-task sequel (AC1, AC3) — `disk/a/TRAFFIC.FTH`

- [x] Rewrite `disk/a/TRAFFIC.FTH` from the Phase-5 terminal-hijacking prototype into the
      **background-task sequel** (the architecture migration note, `architecture.md:383–386`, and
      Journey 4, PRD 228–236, both direct that TRAFFIC.FTH *itself* becomes the background version
      the reader INCLUDEs). Keep the teaching structure and PIO section; **delete** the parts the
      kernel now supersedes:
  - **Remove** the private `CODE TICK-ISR`, `CODE (SET-USR-INT)`, `START-CLOCK`/`STOP-CLOCK`,
    the `VARIABLE TICKS-LEFT`, and the private `: DELAY` — the kernel provides `TIMER-ON`/
    `TIMER-OFF` (`src/timer.asm:99,111`) and a yielding `DELAY` (Epic 24 / Story 25.3). A private
    `DELAY` would **shadow** the kernel's yielding one and re-freeze the prompt (AC3 regression);
    a private ISR would **evict** the kernel tick slot (the `foreign-ISR evicts the slot` gotcha,
    `reference_microbeast_user_interrupt_timer`).
  - **Keep** the PIO section unchanged (`$10 CONSTANT PIO-A-DATA`, `$12 CONSTANT PIO-A-CTRL`,
    `PIO-INIT`, the `RED`/`AMBER`/`GREEN` masks) — the demo still drives the Z84C20 via `OUT`
    (AD-P6-9 GPIO sugar was dropped; raw `OUT` suffices, `architecture.md:475`).
  - **Add** the background-task shape:
    - `TASK CONSTANT LIGHTS` ( create the task handle and name it — see the Dev Note on the
      epic's `TASK LIGHTS` shorthand; `TASK` is `( -- task )`, `src/multitasker.asm:251`, so it
      is stored in a `CONSTANT`, exactly as the 25.7 break probe did `TASK … CONSTANT`).
    - `: RUN-LIGHTS ( -- )  PIO-INIT  BEGIN  RED PIO-A-DATA OUT 4 DELAY  RED AMBER OR
      PIO-A-DATA OUT 1 DELAY  GREEN PIO-A-DATA OUT 4 DELAY  AMBER PIO-A-DATA OUT 2 DELAY
      0 UNTIL ;` — the forever loop uses **`BEGIN … 0 UNTIL`** (terminable form; `AGAIN` is
      undefined, 25.7 finding), and every `DELAY` is the **kernel yielding** `DELAY` (the yield
      seam that keeps the prompt alive). Do **not** call `TIMER-ON` inside `RUN-LIGHTS`; make the
      operator recipe `TIMER-ON` once before `ACTIVATE` (or note it in the header) so the tick is
      live for the yielding `DELAY` to complete on hardware.
    - A header comment block giving the run recipe: `TIMER-ON` → `TASK CONSTANT LIGHTS` →
      `: RUN-LIGHTS …` → `' RUN-LIGHTS LIGHTS ACTIVATE` → keep typing; `.TASKS` shows both awake;
      recover/stop with the keyboard break (`Ctrl-\`, Story 25.7) or `LIGHTS` `SLEEP` (Story 25.4).
- [x] **0x1A-terminate the file** before it can be SLIDE-transferred to real MicroBeast
      (`feedback_cpm_0x1a_eof_marker` — a missing EOF marker breaks `INCLUDE` post-EOF parse on
      silicon; iz-cpm hides it). Verify it passes `test-file-sanity`.
- [x] Comment discipline: what + why-not-obvious, **no** story/CR/date provenance in the file body
      (`feedback_source_comment_discipline`). The teaching comments (why background, why kernel
      DELAY yields, why `0 UNTIL` not `AGAIN`, active-low LED note) are the *tutorial* content and
      belong; provenance does not.

### Task 2 — Structural REPL probe + Makefile target (AC5) — `tests/` + `Makefile`

- [x] Add a probe (new `tests/multitasker_demo_tests.fth`, or fold into an existing 25.x file —
      prefer a new file so the headline demo has its own named target). Model it on
      `tests/multitasker_delay_tests.fth` (the closest precedent — same emulator/hardware split).
      It must, using **only** REPL-piped Forth through the threading model (`feedback_testing_rules`,
      `feedback_repl_tests_preferred`):
  - reproduce the demo's activation shape (a light-like task that `OUT`s to the PIO ports and
    `DELAY`s in a `BEGIN … 0 UNTIL` loop, plus a free-running counter task or the operator itself
    as the liveness witness). It may **either** `INCLUDE TRAFFIC.FTH` and activate `LIGHTS`
    directly (strongest — exercises the shipped asset end-to-end; confirm the emulator handles
    `OUT` to ports `$10`/`$12` inertly, as the 23.3 IN/OUT work established for inert ports) **or**
    inline an equivalent reduced light word if INCLUDE-in-probe proves awkward under the pipe.
  - assert (all column-0-anchored `^PASS:` / `--present '^   1   AWAKE'`):
    `PASS: demo-activates` (words resolve + `ACTIVATE` no-throw), the `^   1   AWAKE` `.TASKS`
    row (both-awake witness, AC2), `PASS: demo-no-monopoly` (operator/counter progresses across
    the light task's pending `DELAY` — the 25.3 `delay-no-monopoly` shape, FR14/FR15/NFR-P6-7),
    and `PASS: demo-alive` (`DEPTH 0=` + arithmetic witness after the interleave).
  - **Do not** assert on-tempo timing or `DELAY` *completion* — the emulator never fires the
    0xFDC7 tick, so a nonzero `DELAY` never completes here (it yields each pass, which is exactly
    what the no-monopoly assertion tests). State this split in the probe header (as the 25.3 probe
    does, `multitasker_delay_tests.fth:8–28`).
- [x] Wire a single-feature Makefile target `test-repl-multitasker-demo` (mirror the 25.3 recipe
      at `Makefile:304–310`): `sed 's/$$/\r/'` + `printf 'BYE\r\n'` + `timeout $(PROBE_TIMEOUT)`,
      fail-loud on `rc==124`, verdicts via `tests/assert_verdicts.sh --present`/`--fail-line`.
      Add it to `.PHONY` (`Makefile:56`). Single-feature target — **not** folded into plain
      `test-repl` (the 25.x convention). If the probe `INCLUDE`s `TRAFFIC.FTH`, ensure the test
      disk image is rebuilt (`make disk`) so the rewritten file is present.
- [x] Guard: probe lines ≤ 128 chars (`feedback_tib_size_inline_comments`); interpret-level `'`
      orchestration and printed witnesses to dodge the `$8000` straddle-halt
      (`feedback_banking_probe_straddle_halt`); keep every existing assertion in any touched file.

### Task 3 — Tutorial/example asset + demo-recipe doc (AC4)

- [x] Provide the tutorial writeup. The rewritten `disk/a/TRAFFIC.FTH` (self-documenting) is the
      primary asset; add a concise **demo recipe** section so a reader can reproduce the headline
      moment. Placement (pick the lightest that fits the repo's convention — flag in Dev Notes):
      **either** a short section in a Phase-6 doc (`docs/phase6-multitasker.md`, the
      architecture-listed [NEW] Epic-25 doc with a "demo recipe" slot, `architecture.md:671–672`)
      **or** a blog-style tutorial mirroring `docs/blog-phase4-*.md` / `docs/blog-phase5-*.md`.
      Keep it lean (audience-of-one, `feedback_ceremony_diminishing_returns`): the run recipe, the
      "why it doesn't freeze the prompt now" contrast with the Phase-5 version, and the
      break/sleep recovery. Optionally mirror the demo file into `examples/` (the repo already
      ships `examples/batnball.fth`, `examples/extended-asm-demo.fth`) — confirm whether `examples/`
      or `disk/a/` is the canonical showcase location and keep them in sync if both.
- [x] Do not re-document the whole scheduler here — the model/TCB/switch-cost prose is broader
      Epic-25 doc territory; this story's doc deliverable is the **demo** (Journey 4), not a
      scheduler reference.

### Task 4 — Close-out: byte delta + S9 MVP gate (AC4)

- [x] Re-`wc -c build/antforth.com`; confirm **0 delta** vs the pre-edit baseline (demo asset +
      probe + docs are all non-kernel). If any byte moved, itemise why (B.2 — do not "accept"
      silently, `feedback_no_preexisting_discharge`). Record the number in Dev Notes.
- [x] Run the full gate set from the Pre-edit baseline task and confirm the 0-FAIL floor holds
      (NFR-P6-5) plus the new `test-repl-multitasker-demo` passes.
- [x] **Post the S9 hardware-smoke recipe in the closing chat message** (not only in Dev Notes —
      STRONG operator preference, `feedback_post_hw_smoke_steps_at_review`). This story's S9 **is**
      the MVP acceptance gate (NFR-P6-6, PRD 174) — the recipe on real CP/M 2.2 / MicroBeast over
      the serial TTY, with the 3-LED board wired: `INCLUDE TRAFFIC.FTH`, `TIMER-ON`,
      `TASK CONSTANT LIGHTS`, `: RUN-LIGHTS …`, `' RUN-LIGHTS LIGHTS ACTIVATE`; confirm the LEDs
      cycle on tempo (red 4 s → red+amber 1 s → green 4 s → amber 2 s, ±1 s per `DELAY`), the `ok`
      prompt returns **immediately** and stays responsive (define + evaluate a word while the
      lights keep time), `.TASKS` shows `   0 * AWAKE` / `   1   AWAKE`, and a `4 DELAY` typed at
      the prompt visibly does **not** freeze the background lights nor vice-versa. Then break the
      task with `Ctrl-\` (Story 25.7) and confirm recovery, and `STOP`/`TIMER-OFF` cleanly. Record
      the capture filename + free-byte reading in the Change Log.

## Dev Notes

### The single most important thing to understand about this story

**No new kernel word. This is the capstone that assembles Epics 24–25 into the headline
demo.** Every ingredient already shipped and is silicon-blessed: `TASK`/`ACTIVATE`
(`src/multitasker.asm`, 25.1), the yielding REPL (25.2), yielding `DELAY` (25.3), `.TASKS`
(25.4), `TIMER-ON`/`TIMER-OFF` + `TICKS`/`DELAY`/`MS` (Epic 24). The deliverables are a
**demo asset** (rewrite `disk/a/TRAFFIC.FTH`), a **structural probe**, a **tutorial recipe**,
and the **S9 MVP-gate validation**. Expected binary delta: **0**. Do **not** invent kernel
words, do **not** touch `src/`.

### The epic's `TASK LIGHTS` is shorthand — the real form is `TASK CONSTANT LIGHTS`

Epic AC1 (and Journey 1) write "`TASK LIGHTS`" as if `TASK` were a parsing/defining word. It
is **not**: `TASK` is `( -- task )` — it splices a new TCB into the ring and pushes its handle
(`src/multitasker.asm:251–298`). The idiomatic way to give the handle a name is
`TASK CONSTANT LIGHTS` (exactly what the 25.7 break probe did with `TASK … CONSTANT`). Then
`' RUN-LIGHTS LIGHTS ACTIVATE` reads: push the xt of `RUN-LIGHTS`, push the `LIGHTS` handle,
`ACTIVATE ( xt task -- )`. Write the demo and doc with `TASK CONSTANT LIGHTS`; the story's AC1
notes the shorthand so the dev does not go hunting for a non-existent parsing `TASK`.

### Emulator vs hardware split — the decisive constraint (NFR-P6-14)

iz-cpm-banking does **not** model the MicroBeast 0xFDC7 user interrupt, so `TICKS` never
advances under emulation and a **nonzero `DELAY` never completes** there (its target is never
reached). This is the same wall the 25.3 `DELAY` probe hit (`multitasker_delay_tests.fth:8–28`).
Consequences:
- **Emulator (the probe, AC5) proves STRUCTURE:** the demo activates, `.TASKS` shows both
  awake, and the light task **yields** (a pending `DELAY` does not monopolize the ring — the
  operator/counter keeps progressing). That is the FR14/FR15/NFR-P6-7 payoff and is genuinely
  testable because "yields each pass" is exactly what a never-completing-but-yielding `DELAY`
  does.
- **Hardware (S9, AC4) proves the EXPERIENCE:** on-tempo cycling, "prompt returns immediately,"
  and "`4 DELAY` does not freeze the prompt" all require the real tick — they are the **MVP
  acceptance gate** (NFR-P6-6, PRD 174), not an optional smoke. Wire the board, run the recipe,
  and post it in the closing chat message.

The **ISR-not-installed hang** gotcha applies: a nonzero `DELAY` waits for `TICKS`; with the
tick slot not live (emulator never fires it; on hardware after `TIMER-OFF` or if a foreign ISR
evicts the slot) the delaying task never completes. Recover with `TIMER-ON`. The demo recipe
must `TIMER-ON` before activating the light task (`reference_microbeast_user_interrupt_timer`).

### Why rewrite `TRAFFIC.FTH` rather than shadow it

The current `disk/a/TRAFFIC.FTH` (Phase-5 prototype) is actively **incompatible** with the
kernel it now runs on:
- it defines its **own** `: DELAY` (busy-wait on `TICKS-LEFT`) that would **shadow** the kernel
  yielding `DELAY` — re-freezing the prompt, defeating the entire demo (AC3);
- it installs its **own** `CODE TICK-ISR` via `(SET-USR-INT)`, which **evicts** the kernel tick
  slot (foreign-ISR gotcha) — after which the kernel `DELAY` would hang;
- its main loop is `BEGIN … AGAIN`, and **`AGAIN` is undefined** in antforth (confirmed on
  silicon in the 25.7 capture: `: HOG BEGIN AGAIN ;` raised `-13 undefined word`,
  `25-7…md:539–540`). A forever loop is `BEGIN … 0 UNTIL`.
The architecture migration note (`architecture.md:383–386`) and Journey 4 (PRD 228–236) both
direct that the tutorial **sequel rewrites** the demo as a background task the reader INCLUDEs —
so the rewrite target is `TRAFFIC.FTH` itself. **Open decision (flagged below):** overwrite in
place vs. ship a sibling `TRAFFIC2.FTH`/`LIGHTS.FTH`. Default taken here: **overwrite in place**
(matches Journey 4's "INCLUDEs TRAFFIC.FTH … runs it as a background task"). Confirm with the
operator if a side-by-side prototype-vs-sequel pairing is wanted for teaching.

### Byte-budget estimate

**0 kernel bytes.** No `src/*.asm` change — the demo is Forth-level, the probe is a test asset,
the tutorial is docs. The pre/post `wc -c` comparison is the *evidence* of 0-delta, not a
formality (B.2 / B.3). If a byte moves, something touched `src/` that should not have —
investigate before accepting.

### Register / register-contract notes

None — this story adds no assembly. The multitasker register contract
(`project_multitasker_pause_register_contract`: normal task words preserve `DE=IP`; PAUSE is the
sole exception; per-task `sp_base`) is honored automatically because the demo composes existing,
already-contract-correct kernel words. The light task's `RUN-LIGHTS` is an ordinary colon word;
its `OUT` and `DELAY` are shipped words; nothing here can violate the contract.

### Stale-premise / drift flags carried into the dev-pass

1. **`AGAIN` is not defined** — the Phase-5 `TRAFFIC.FTH` uses `BEGIN … AGAIN`; the sequel must
   use `BEGIN … 0 UNTIL`. (Silicon-confirmed, 25.7.)
2. **`TASK` is not a parsing word** — use `TASK CONSTANT LIGHTS`, not `TASK LIGHTS` (see the Dev
   Note above). The epic text is shorthand.
3. **Architecture Yield-Instrumentation list (arch ~539–540) still lists `EMIT (per-emit
   yield)`**, contradicting AD-P6-6's authoritative "EMIT does NOT yield" (`architecture.md:392`).
   Not this story's fix; do not rely on EMIT yielding — the light task holds the CPU through a
   print until its next `DELAY`. Its outputs are `OUT` to the PIO, not `EMIT`, so this does not
   affect the demo.
4. **`docs/phase6-multitasker.md` does not exist yet** — the architecture lists it as [NEW]
   with a "demo recipe" slot. Creating it (or a blog-phase6 tutorial) is this story's Task 3
   doc deliverable; keep it lean and demo-focused, not a full scheduler reference.

### Project Structure Notes

- **No kernel change.** `src/` is untouched (`src/multitasker.asm`, `src/timer.asm`, etc. all
  read-only for this story). If a change to `src/` seems necessary, stop — a needed kernel word
  is missing from the Epic-24/25 scope and that is a correct-course signal, not a 25.8 edit.
- **Demo asset:** `disk/a/TRAFFIC.FTH` (rewrite; 0x1A-terminate). Optional mirror in `examples/`.
- **Test:** new `tests/multitasker_demo_tests.fth` + `test-repl-multitasker-demo` Makefile target
  (single-feature, not in plain `test-repl`). Rebuild the disk (`make disk`) if the probe
  `INCLUDE`s the rewritten asset.
- **Docs:** `docs/phase6-multitasker.md` (new, demo-recipe section) **or** a `docs/blog-phase6-*.md`
  tutorial — operator's pick; keep lean.
- **Testing standard:** REPL-piped Forth through the threading model only (`make test-repl`,
  NFR-P6-16) — no raw BDOS/asm-thread hacks (`feedback_testing_rules`,
  `feedback_repl_tests_preferred`). Interpret-level `'`; printed witnesses; lines ≤ 128 chars;
  dodge the `$8000` straddle-halt.
- **Comment discipline:** what + why-not-obvious, never story/CR/date provenance in source/asset
  files (`feedback_source_comment_discipline`). Tutorial *teaching* comments in the demo file are
  content, not provenance, and belong.

### References

- Story spec: [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story 25.8] (lines 369–382); Epic 25 intro (178–184, 241)
- Requirements: [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md] FR26 (403), FR10–FR12, FR14/FR15, FR25; NFR-P6-6 MVP-gate S9 (424–426), NFR-P6-7 fault-containment (427–428), NFR-P6-14 emulator/hardware split; MVP definition (165–174); Journey 1 (197–206), Journey 4 (228–236), Journey Requirements (238–247)
- Architecture: [Source: _bmad-output/planning-artifacts/architecture.md] headline acceptance FR25–FR26 (68–69), AD-P6-5 timer/DELAY + TRAFFIC migration note (365–386), AD-P6-6 input-only yield / EMIT-no-yield (388–397), MVP gate (487), source-tree demo/tutorial slots (665–676)
- Demo prototype to rewrite: [Source: disk/a/TRAFFIC.FTH] (full file — private ISR/DELAY/START-CLOCK to remove, PIO section to keep)
- Kernel words the demo composes: [Source: src/multitasker.asm] `TASK` (251–298), `ACTIVATE` (300–383), `.TASKS` (428), `SLEEP`/`WAKE` (385–428); [Source: src/timer.asm] `TIMER-ON`/`TIMER-OFF` (93–120), `(DELAY)` PAUSE-first loop (135–148); kernel yielding `DELAY`/`MS` (Epic 24)
- Probe precedent (emulator/hardware split, no-monopoly pattern): [Source: tests/multitasker_delay_tests.fth] (whole file, esp. 8–28 header split and 53–62 no-monopoly probe); Makefile recipe [Source: Makefile] (304–310)
- Keyboard-break recovery for the demo (stop a running light task): [Source: _bmad-output/implementation-artifacts/25-7-keyboard-break-documented-starvation.md] (`Ctrl-\` break; `AGAIN` undefined finding at 539–540)
- Prior story (context continuity): [Source: _bmad-output/implementation-artifacts/25-7-keyboard-break-documented-starvation.md]
- Timer/DELAY gotchas: memory `reference_microbeast_user_interrupt_timer` (ISR-not-installed hang; foreign-ISR slot eviction), `project_multitasker_pause_register_contract`
- CP/M asset hygiene: memory `feedback_cpm_0x1a_eof_marker` (0x1A EOF terminate before SLIDE transfer)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8)

### Debug Log References

- Pre-edit smoke of the rewritten asset (INCLUDE + activate + `.TASKS` + interleave)
  under `iz-cpm-banking`: `.TASKS` rendered `   0 * AWAKE` / `   1   AWAKE`; operator
  computed `42` and stayed `DEPTH 0` while `LIGHTS` was parked in its `4 DELAY`; `OUT`
  to PIO ports `$10`/`$12` inert (no fault) — confirms the headline moment structurally.
- `make test-repl-multitasker-demo` → 4/4 green (demo-lights-awake-row, demo-activates,
  demo-no-monopoly, demo-alive).

### Completion Notes List

**Capstone — no new kernel word; 0 byte delta.** Story 25.8 assembles the shipped
Epic-24/25 parts into the headline demo. No `src/*.asm` change: pre-edit and post-edit
`wc -c build/antforth.com` both = **30,438 B** (delta **0**), which is the *proof* of the
0-kernel-byte claim (AC4).

- **Task 1 — `disk/a/TRAFFIC.FTH` rewritten** from the Phase-5 terminal-hijacking prototype
  into the background-task sequel (overwrite in place — Open Question #1 default, Journey 4).
  **Removed** the private `CODE TICK-ISR`, `(SET-USR-INT)`, `START-CLOCK`/`STOP-CLOCK`,
  `VARIABLE TICKS-LEFT`, and the private `: DELAY` (all would shadow/evict the kernel's
  yielding `DELAY` + tick slot). **Kept** the PIO section (`PIO-INIT`, `RED`/`AMBER`/`GREEN`,
  raw `OUT`). **Added** `TASK CONSTANT LIGHTS` + `: RUN-LIGHTS … BEGIN … 0 UNTIL ;` (kernel
  yielding `DELAY`, terminable loop — `AGAIN` undefined) + a run-recipe header comment.
  0x1A-terminated. Verified `TASK` marks the fresh TCB `TASK_ASLEEP` (`src/multitasker.asm:263`),
  so the un-armed `LIGHTS` is safely skipped by INCLUDE's yielding reader until `ACTIVATE`.
- **Task 2 — probe `tests/multitasker_demo_tests.fth` + `test-repl-multitasker-demo` target.**
  INCLUDE-based (Open Question #3 default — exercises the shipped asset end-to-end): activates
  `LIGHTS`, asserts `^   1   AWAKE` (runtime `.TASKS` row, 23.2 false-green defence), a
  free-running counter advances across `LIGHTS`'s pending `DELAY` (no-monopoly, FR14/FR15/
  NFR-P6-7), and operator stack-clean after. Single-feature target (not in plain `test-repl`),
  fail-loud `timeout`, column-0 verdicts via `assert_verdicts.sh`. Lines ≤ 128; interpret-level
  `'`. Note: `IZCPM_DISKS` mounts `disk/a` directory-backed, so the rewritten file is picked up
  live — **no `make disk` needed** (the `disk:` target only copies `antforth.com`).
- **Task 3 — `docs/phase6-multitasker.md`** (Open Question #2 default): lean demo-recipe doc —
  run recipe, stop/recover, the "why it doesn't freeze the prompt" contrast with the Phase-5
  version, and the emulator-vs-hardware split. Not a scheduler reference. `examples/` mirror
  skipped (Open Question #4 default — canonical asset stays the `disk/a` INCLUDE target).
- **Task 4 — close-out.** 0 byte delta confirmed. Full gate set green: `make test-repl`
  (**0 FAIL**, rc=0), all Epic-24/25 single-feature targets, `test-repl-multitasker-demo`,
  `test-repl-banking`, `test-straddle-regression`, `lint-banking-probes`, `check-doc-sync`,
  `test-file-sanity`. **S9 MVP-gate hardware smoke PASSED on real MicroBeast 2026-07-01**
  (operator-confirmed, with actual 3-LED traffic-light hardware on the Z84C20 PIO): LEDs
  cycle on tempo while the `ok` prompt stays live, `.TASKS` shows `   0 * AWAKE` /
  `   1   AWAKE`, `4 DELAY` at the prompt does not freeze the background lights (nor
  vice-versa), and `Ctrl-\` breaks the light task cleanly — all four S9 sub-checks
  witnessed. **This is the Phase 6 MVP acceptance gate (NFR-P6-6, PRD 174).**

**Open Questions — defaults taken** (all reversible via git; flagged for operator at review):
#1 overwrite `TRAFFIC.FTH` in place; #2 doc in `docs/phase6-multitasker.md`; #3 INCLUDE-based
probe; #4 no `examples/` mirror.

### File List

- `disk/a/TRAFFIC.FTH` (rewritten — background-task sequel; 0x1A-terminated)
- `tests/multitasker_demo_tests.fth` (new — structural REPL probe)
- `Makefile` (new `test-repl-multitasker-demo` target + `.PHONY` entry)
- `docs/phase6-multitasker.md` (new — demo-recipe tutorial)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (25.8 → review)

### Change Log

- 2026-07-01 — Story 25.8 dev-complete (status → review). **0 kernel bytes** (30,438 B
  unchanged, pre = post). Emulator banner reads **23,578 bytes free**. Rewrote
  `disk/a/TRAFFIC.FTH` as the background-task sequel; added `tests/multitasker_demo_tests.fth`
  + `test-repl-multitasker-demo` (4/4 green); added `docs/phase6-multitasker.md`. Full gate set
  green, `make test-repl` 0 FAIL.
- 2026-07-01 — **S9 MVP-gate HW smoke PASSED on real MicroBeast** with actual 3-LED
  traffic-light hardware (Z84C20 PIO Port A). All four sub-checks confirmed by the operator:
  on-tempo LED cycling with the prompt live, `.TASKS` both-awake rows, `4 DELAY` non-freeze,
  and `Ctrl-\` break + clean stop. **Phase 6 MVP acceptance gate (NFR-P6-6) met.**
  _(Capture filename + banner free-byte reading to be slotted in from the operator's session
  log for the record.)_

## Open Questions (for the operator — non-blocking, sensible defaults taken)

1. **Overwrite `TRAFFIC.FTH` in place, or ship a sibling sequel file?** Default taken:
   **overwrite in place** (Journey 4 says the reader "INCLUDEs TRAFFIC.FTH … runs it as a
   background task"; the migration note says the sequel *rewrites* the demo). Alternative: keep
   the Phase-5 prototype as `TRAFFIC.FTH` and add `LIGHTS.FTH`/`TRAFFIC2.FTH` for a side-by-side
   prototype-vs-sequel teaching pairing. Pick if you want both preserved.
2. **Tutorial doc placement:** new `docs/phase6-multitasker.md` (architecture-listed [NEW], with
   a demo-recipe section) vs. a `docs/blog-phase6-*.md` tutorial (mirroring the phase4/phase5
   blogs). Default: a lean demo-recipe section in `docs/phase6-multitasker.md`. Either is fine;
   audience-of-one, keep it short.
3. **Probe strategy:** `INCLUDE TRAFFIC.FTH` in the probe (strongest — tests the shipped asset
   end-to-end, needs `make disk` + confirming `OUT` to PIO ports is inert under the emulator) vs.
   an inlined reduced light word (simpler, decoupled from the asset). Default: try INCLUDE first;
   fall back to inline if the piped INCLUDE proves awkward.
4. **Mirror the demo into `examples/`?** The repo ships `examples/*.fth` as a showcase and
   `disk/a/*.FTH` as the loadable CP/M drive. Default: canonical asset in `disk/a/TRAFFIC.FTH`
   (the INCLUDE target); mirror to `examples/` only if you want it in the repo showcase too.
