# Story 26.2: Mutex (binary semaphore)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a task author,
I want a mutex to protect a shared resource,
so that only one task uses it at a time.

## Acceptance Criteria

1. **AC1 — Constructor creates an unlocked binary-semaphore cell (FR18).**
   **Given** the counting semaphore from Story 26.1
   **When** the author runs `MUTEX name` (no count argument)
   **Then** `name` is a created word whose execution pushes the address of a single
   cell initialised to **1** (unlocked). The cell is an ordinary data-space cell
   (`@`/`!`-addressable like a `VARIABLE`), verifiable by `name @ .` printing `1`.
   `MUTEX` reuses the `SEMAPHORE` defining word (it is `1 SEMAPHORE` fixed at count 1),
   so the parse-name-then-comma mechanics are inherited, not re-implemented.

2. **AC2 — `LOCK` acquires (blocking), `UNLOCK` releases; both are `( mtx -- )` and
   `DEPTH`-clean.**
   **When** a task runs `mtx LOCK` and the mutex is free (count = 1), `LOCK` takes it
   (count → 0) and returns without yielding-and-waiting past the first PAUSE seam; **when**
   the mutex is already held (count = 0), `LOCK` cooperatively spins with `PAUSE`
   (yield-first) until it is released, then takes it. `mtx UNLOCK` releases it. Each word
   consumes exactly the mutex address and leaves the data stack otherwise unchanged.
   `LOCK` reuses the Story 26.1 `WAIT` acquire path verbatim.

3. **AC3 — `UNLOCK` is binary (clamps to 1), not an unbounded increment (FR18 correctness).**
   **When** a task runs `mtx UNLOCK`, the cell is **set to 1**, not incremented. A double
   `UNLOCK` (release of an already-free mutex) leaves the count at 1, never 2 — so the
   mutex can never admit two simultaneous holders through a spurious release. This is the
   design distinction from the counting semaphore's `SIGNAL` (which increments without
   bound) and is stated in a source comment on `UNLOCK` and in `docs/phase6-multitasker.md`.

4. **AC4 — Two contending tasks interleave cleanly, no corruption (FR18, headline of the
   story).**
   **Given** two tasks that each `LOCK` the mutex, mutate a shared buffer in two steps with
   a `PAUSE` between the steps, then `UNLOCK`
   **Then** neither task ever observes the buffer half-written by the other: every guarded
   read sees an internally-consistent buffer (both halves stamped by the same writer). A
   probe over the shared buffer counts consistent vs. inconsistent observations and asserts
   **zero** inconsistencies. Emulator asserts the structural outcome (consistency
   count / stack cleanliness); wall-clock interleave rides S9.

5. **AC5 — Contention blocks with `PAUSE`, ring stays alive.**
   **When** a background task holds the mutex and a second task attempts `LOCK`, the second
   task PAUSE-waits (does not busy-spin, does not wedge the ring) until the holder
   `UNLOCK`s, then proceeds. A peer counter and the operator REPL keep advancing while the
   second task is blocked (the cooperative-friendly wait, inherited from `WAIT`).

6. **AC6 — Non-atomic by design + operator-context footgun, documented (FR18 / AD-P6-8).**
   `LOCK`/`UNLOCK` inherit the Story 26.1 non-atomic-but-cooperatively-safe invariant (the
   take-and-decrement has no `PAUSE` between the count check and the store; correctness
   rests on the cooperative single-thread-except-ISR model, ISR touching only `TICKS`).
   In addition, the **operator-context blocking footgun** carries over from `WAIT`
   (Story 26.1 caveat / `project_operator_wait_wedge`): a `LOCK` run **at the REPL prompt**
   on a mutex that no background task will `UNLOCK` **hard-wedges** the machine (the operator
   is the keyboard reader and is break-exempt — even `Ctrl-\` cannot recover). Blocking
   `LOCK`s belong in background `TASK`s. Both the non-atomic note and the operator-LOCK
   wedge are documented in `docs/phase6-multitasker.md`.

7. **AC7 — Regression, budget, and hardware.**
   The current `make test-repl` baseline still passes with **0 FAIL**; the new mutex probe
   is additive (its own Makefile target, **not** folded into plain `test-repl`, mirroring
   the `test-repl-semaphore` / `test-repl-multitasker-*` sibling targets). Binary delta is
   recorded against the pre-edit baseline (30,518 B) with per-word itemisation. S9
   hardware-smoke on real CP/M 2.2 / MicroBeast **PASS** (NFR-P6-6), covering the two-task
   mutual-exclusion hand-off.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev Notes.
  - Do NOT inherit Story 26.1's reported 30,518 B — re-`wc -c` from the actual current build
    artifact after a clean `make asm` (B.3 / Lesson 13.5-F).
- [x] Capture current `make test-repl` baseline pass count (26.1 close recorded 1005/0; confirm).

### Story tasks

- [x] **Task 1 — Mutex constructor `MUTEX ( "<spaces>name" -- )` (AC: 1).**
  Add to the coordination section of `src/multitasker.asm` (AD-P6-8), immediately after
  `WAIT` (`src/multitasker.asm:599-614`), as a `DEFWORD` that reuses `SEMAPHORE` as a
  defining word with a fixed count of 1: body = `w_LIT_cf, 1, w_SEMAPHORE_cf, EXIT_CODE`.
  When `MUTEX foo` runs it pushes 1 then calls `SEMAPHORE`, whose `CREATE` parses `foo`
  from the input stream and commas the 1 — so `foo` pushes a cell holding 1 (unlocked).
  - [x] 1.1 Header + body per the `DEFWORD` idiom (`w_MUTEX_cf EQU w_MUTEX_body - 3`
        → `JP DOCOL`), matching `SEMAPHORE` (`src/multitasker.asm:558-564`).
  - [x] 1.2 Confirm reused labels against source: `w_LIT_cf` (immediate value follows in the
        next cell — see `src/bootstrap.asm:12,78`), `w_SEMAPHORE_cf`, `EXIT_CODE`.
  - [x] 1.3 Verify the nested-defining-word parse: `MUTEX foo` must leave `>IN` positioned so
        `SEMAPHORE`'s `CREATE` reads `foo` (it does — `CREATE` parses from the live input
        stream, exactly as a user typing `1 SEMAPHORE foo` would). No new parse machinery.

- [x] **Task 2 — `LOCK ( mtx -- )` acquire — reuse `WAIT` (AC: 2, 5, 6).**
  Add as a `DEFWORD` thin wrapper over the Story 26.1 acquire path: body =
  `w_WAIT_cf, EXIT_CODE`. Binary-semaphore acquire is identical to counting-semaphore
  acquire (block until count > 0, then decrement), so `LOCK` inherits `WAIT`'s PAUSE-first
  spin, its non-atomic-but-safe take, and its ring-stays-alive property with zero
  re-implementation.
  - [x] 2.1 Source comment on `LOCK` states it is `WAIT` re-exposed under mutex vocabulary,
        and carries the operator-context wedge caveat (AC6) by reference to `WAIT`.

- [x] **Task 3 — `UNLOCK ( mtx -- )` release — clamp to 1, NOT `SIGNAL` (AC: 2, 3, 6).**
  Add as a `DEFWORD` that **stores 1** rather than incrementing: body =
  `w_LIT_cf, 1, w_SWAP_cf, w_STORE_cf, EXIT_CODE` (`1 SWAP !`). This makes the mutex a
  true binary semaphore: a double `UNLOCK` is idempotent (count stays 1), so a spurious or
  redundant release can never push the count to 2 and let two tasks hold the mutex at once.
  - [x] 3.1 Verify there is **no `PAUSE`** in `UNLOCK` (it is a straight-line store — the
        release is atomic w.r.t. the ring, same discipline as `SIGNAL`).
  - [x] 3.2 Source comment on `UNLOCK` states the binary-clamp rationale explicitly:
        "stores 1, does NOT increment — a binary semaphore, so double-UNLOCK cannot admit
        two holders; contrast SIGNAL which is unbounded."

- [x] **Task 4 — Probe `tests/mutex_tests.fth` + Makefile `test-repl-mutex` target
      (AC: 1, 2, 3, 4, 5, 7).**
  New probe modelled on `tests/semaphore_tests.fth` + `test-repl-semaphore`
  (`Makefile:431-450`): fail-loud `timeout`, verdicts via `tests/assert_verdicts.sh`
  column-0-anchored `^PASS:` helper with a `^FAIL:` tripwire; added to `.PHONY`; **not**
  folded into `test-repl`.
  - [x] 4.1 `mutex-words-resolve` (AC1/AC2): `' MUTEX DROP ' LOCK DROP ' UNLOCK DROP` then
        PASS (a miss throws -13 before the verdict).
  - [x] 4.2 `mutex-constructor-init` (AC1): `MUTEX MTX` then `MTX @ 1 =` — starts unlocked.
  - [x] 4.3 `mutex-lock-unlock-cycle` (AC2/AC3): single-task, no task activated yet
        (`LOCK`'s PAUSE is a walk-to-self no-op). `MTX LOCK` → `MTX @ 0 =`; `MTX UNLOCK`
        → `MTX @ 1 =`; **double** `MTX UNLOCK MTX UNLOCK` → `MTX @ 1 =` (binary clamp, the
        AC3 witness); assert `DEPTH` unchanged across the sequence.
  - [x] 4.4 `mutex-exclusion-clean` (AC4/AC5): a background WRITER task loops
        `MTX LOCK; stamp BUF[0]=tag; PAUSE; stamp BUF[1]=tag; MTX UNLOCK; tag+1` (the PAUSE
        mid-write is the corruption trap). The operator loops `MTX LOCK; read BUF[0],BUF[1];
        consistent? (equal) count++ else bad++; MTX UNLOCK`. Assert **bad = 0** and
        consistent-count > 0 — RUNTIME-computed witnesses (never one echoed literal),
        defeating false-green. Because the operator only reads while holding the mutex, it
        never catches a half-stamped buffer. **Two forever-tasks max** — WRITER plus the
        operator's checker loop is a bounded `DO` loop, not a third task (F4/NFR-P6-11
        ~2 KB TCB budget; Story 26.1 hit the `-8` guard at 4 tasks).
  - [x] 4.5 `mutex-alive` (AC7): interpreter healthy + stack clean after the interleave
        (`DEPTH 0= 1 2 3 + + 6 = AND`).
  - [x] 4.6 All probe lines ≤ 128 chars (TIB limit); no `$8000` straddle; drive at
        interpret level. 0x1A-terminate the file before any SLIDE to real MicroBeast.

- [x] **Task 5 — Docs + budget close-out (AC: 3, 6, 7).**
  - [x] 5.1 Add a "Coordination — the mutex (`MUTEX` / `LOCK` / `UNLOCK`)" subsection to
        `docs/phase6-multitasker.md`, after the counting-semaphore section (`:86-165`):
        word surface, the documented lock/unlock usage pattern (a background `TASK` guarding
        a critical section), the binary-clamp rationale (AC3), and — reusing the existing
        `WAIT` operator-wedge callout (`docs/phase6-multitasker.md:154-164`) — the
        operator-context `LOCK` footgun (AC6).
  - [x] 5.2 Record binary delta against the pre-edit baseline; itemise per word in Dev Notes;
        reconcile the measured delta at close. Any overshoot is accept-with-rationale per
        NFR-P6-10, no silent bloat.
  - [x] 5.3 **S9 hardware-smoke on real MicroBeast / CP/M 2.2** — post the recipe in the
        review-close chat message (not only in Dev Notes): constructor init (`MUTEX m` →
        `m @` = 1), lock (1→0), unlock (0→1), double-unlock stays 1, and a background
        writer / operator two-task exclusion hand-off staying consistent with the prompt
        responsive. Record the capture filename and the banner "free" figure.

## Dev Notes

### Design decision to confirm at dev-pass — `UNLOCK` semantics (binary clamp vs. `SIGNAL`)

This story specs `UNLOCK` as **store-1** (`1 SWAP !`, a true binary semaphore), **not**
`SIGNAL` (increment). Rationale: a mutex must never admit two holders; if `UNLOCK` were
`SIGNAL`, a double-release (a real bug class — releasing a mutex you already released, or
that a peer released) would push the count to 2 and let two tasks `LOCK` simultaneously,
silently defeating exclusion. Clamping makes double-`UNLOCK` idempotent and the invariant
"count ∈ {0,1}" structural. The counting semaphore keeps `SIGNAL` (unbounded) because a
counting semaphore's whole purpose is to count units; a mutex's is to be binary. This is
the recommended, more-defensive design and is what AC3 asserts. If you instead want
`UNLOCK = SIGNAL` (maximal reuse, no clamp), that is a deliberate downgrade of the binary
guarantee — flag it and update AC3 + the probe's double-unlock witness before implementing.

### Standing multitasker contract — front-loaded (AI-25-4; do not rediscover)

The Epic 25 footguns that bite Epic 26 authors — internalise before writing a line:

- **`PAUSE` register contract** (`project_multitasker_pause_register_contract`): every
  normal task word **must preserve `DE` = IP**; `PAUSE` is the *only* word allowed not to.
  All three words here take the `DEFWORD` route (threaded lists of proven leaves), so this
  is satisfied by construction — no raw Z80, no register exposure. Do **not** rewrite any of
  them as `DEFCODE` without re-honouring the `DE`-preservation contract (as `SLEEP`/`WAKE`
  do, `src/multitasker.asm:371-415`).
- **`check_overflow`/`DEPTH` use the per-task `t_sp_base`** — not relevant here (you touch
  no scheduler state); the mutex cell lives in shared data space, not per-task state.
- **`( -- d )` producers push BC** (`project_double_producer_push_bc`) — no double-cell
  producers in this story; noted only because coordination sits next to `TICKS`.

### `TASK` handle + `AGAIN` undefined (AI-25-4)

- `TASK ( -- task )` returns the TCB handle as a **stack value**, not a variable — the
  probe's background WRITER must keep its handle (activate via `' WRITER TASK ACTIVATE`,
  the Story 26.1 idiom). Re-reading `LATEST @` won't give a usable xt for a bank-0 runtime
  word (`project_bank_triple_excludes_buckets` — use `'`).
- **`AGAIN` is undefined** in antforth — a forever loop is `BEGIN … 0 UNTIL`. The WRITER
  loop must use that idiom (see `PEER` in `tests/semaphore_tests.fth:90`), never `AGAIN`.

### Why the design is correct despite being non-atomic (AC6 rationale)

`LOCK` *is* `WAIT`, so it inherits Story 26.1's proof verbatim: the cooperative model is
single-threaded except the 64 Hz ISR, and the ISR touches only `TICKS` (`AD-P6-5`), never
a mutex cell. A context switch happens only at a `PAUSE` (a `NEXT` boundary). `WAIT`/`LOCK`
places its only `PAUSE` at the **top** of the loop, before the count check; between the
"count > 0" fall-through and the `!` decrement there is no `PAUSE`, so no other task can
take the mutex mid-acquire. `UNLOCK` is a straight-line store (no `PAUSE`), so release is
atomic w.r.t. the ring too. Two tasks both blocked in `LOCK` on the same mutex cannot both
acquire a single `UNLOCK`: after `UNLOCK` sets count to 1, whichever the round-robin runs
next decrements it to 0; the other sees 0 and loops. No lost wakeup, no double-acquire.

### Operator-context `LOCK` is a hard wedge (AC6; `project_operator_wait_wedge`)

Story 26.1's HW-smoke surfaced this for `WAIT` and it applies identically to `LOCK`: a
blocking `LOCK` run **in the operator** (at the REPL prompt) on a mutex that no background
task will `UNLOCK` **hard-wedges** the machine. The operator is the keyboard-reader and is
break-exempt by design (an operator yield hands off, it never breaks itself), so even a set
`Ctrl-\` break cannot recover it — reset only. The feature is correct; the footgun is
usage. The probe therefore does all *blocking* contention in **background tasks**, and the
operator's checker only ever `LOCK`s a mutex a background writer actively releases. Document
the caveat by extending the existing `WAIT` callout (`docs/phase6-multitasker.md:154-164`).

### Byte-budget estimate — per-component itemisation (B.2; no "mirrors prior arm")

Independent per-word itemisation. Header base measured from Story 26.1's actual +80 B: the
three 26.1 bodies were 3+6+11 = 20 cells = 40 B, so the three headers summed to 40 B; with
names `SEMAPHORE`(9)+`SIGNAL`(6)+`WAIT`(4) = 19 name bytes, the non-name header base is
(40 − 19)/3 ≈ **7 B/word** (link 2 + len/flags 1 + bank 1 + `JP DOCOL` 3). Using that:

- **`MUTEX`** (`DEFWORD`): header ≈ 7 + 5 (`"MUTEX"`) = 12 B; body = 4 cells
  (`LIT` + value 1 + `SEMAPHORE` + `EXIT`) = 8 B → **≈ 20 B**.
- **`LOCK`** (`DEFWORD` wrapper): header ≈ 7 + 4 (`"LOCK"`) = 11 B; body = 2 cells
  (`WAIT` + `EXIT`) = 4 B → **≈ 15 B**.
- **`UNLOCK`** (`DEFWORD`): header ≈ 7 + 6 (`"UNLOCK"`) = 13 B; body = 5 cells
  (`LIT` + value 1 + `SWAP` + `!` + `EXIT`) = 10 B → **≈ 23 B**.
- **Total ≈ 58 B** kernel growth (≈ 50–70 B allowing for header-macro exactness). Trivial
  against the F5 per-epic envelope (~2.4× applies to the *epic* aggregate, not one story).
  Reconcile the measured delta at close (Task 5.2).

### Source tree components to touch

- `src/multitasker.asm` — **coordination section** (AD-P6-8), immediately after `WAIT`
  (`:614`, before the `ASSERT $ <= SLOT2_WINDOW_BASE` fixed-memory guard at `:621` — keep
  the three new words above that assert so they stay in always-mapped memory). No edits to
  the scheduler ring, `PAUSE`, TCB, exception paths, or the existing semaphore words.
- `tests/mutex_tests.fth` — **new** probe (parallels `tests/semaphore_tests.fth`).
- `Makefile` — new `test-repl-mutex` target + `MUTEX_PROBE` var + `.PHONY` entry
  (`:56`, `:431-450` templates); **not** wired into `test-repl`.
- `docs/phase6-multitasker.md` — new mutex subsection after the counting-semaphore section.

### Testing standards summary

- REPL-piped Forth only (NFR-P6-16) — test through the threading model, never raw BDOS
  (`feedback_testing_rules`, `feedback_repl_tests_preferred`).
- Fail-loud `timeout` wrapper (Story 24.3) so a genuine deadlock → loud FAIL, not a CI hang;
  verdicts through `tests/assert_verdicts.sh` (Story 24.4), column-0-anchored `^PASS:`.
- Defeat false-green source echo with RUNTIME-only witnesses (the bad=0 / consistent-count
  computed by the checker loop, not an echoed literal) — the 23.2 defence.
- Probe lines ≤ 128 chars (TIB limit, `feedback_tib_size_inline_comments`); honour the
  $8000 straddle constraint; drive any bank-ops at interpret level (`'`, not `[']`).
- **CP/M 0x1A EOF**: `tests/mutex_tests.fth` must be 0x1A-terminated before SLIDE to real
  MicroBeast (`feedback_cpm_0x1a_eof_marker`).
- Run the full sibling suite green at close: `test-repl` (no regression), `test-repl-mutex`,
  `test-repl-semaphore`, `test-repl-multitasker-*`, `test-repl-timer`,
  `test-straddle-regression`, `check-doc-sync`, `test-file-sanity`.

### Project Structure Notes

- **Word surface.** The PRD/architecture leave the mutex words unnamed ("mutex, mailbox"),
  but Epic 26's AC for this story explicitly says "**lock/unlock** words are provided"
  (`epics-phase6-epics-24-26.md:418`). This story names them `LOCK`/`UNLOCK` with
  constructor `MUTEX`, parallelling the 26.1 `SEMAPHORE`/`SIGNAL`/`WAIT` triple. No other
  coordination words ship here (mailbox = 26.3).
- **Probe file name.** Architecture's file-tree (`architecture.md:664`) declares a single
  `tests/semaphore_tests.fth` "SIGNAL/WAIT/mutex/mailbox". Story 26.1 already took that
  filename for the counting-semaphore probe; this story uses a **sibling** `tests/mutex_tests.fth`
  (own `test-repl-mutex` target) rather than swelling the 26.1 probe — matching the
  one-target-per-feature convention the multitasker probes follow. If the dev prefers to
  extend `semaphore_tests.fth` in place, note the choice in the File List.
- No new module, no INCLUDE-order change (coordination lives inside `src/multitasker.asm`,
  already after `banking.asm`/`exception.asm` per AD-P6-7).

### References

- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story 26.2] — user story, ACs, FR18 (lines 407-419).
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-8] — coordination primitives, cooperative spin-with-PAUSE, "mutex (binary sem)", non-atomic-OK (lines 469-476).
- [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md] — FR18 (line 386); mutex in the coordination word surface (lines 243, 259-267).
- [Source: src/multitasker.asm:543-621] — coordination section: `SEMAPHORE` (558-564), `SIGNAL` (571-580), `WAIT` (599-614), fixed-memory ASSERT (621) — the words `MUTEX`/`LOCK`/`UNLOCK` reuse and sit beside.
- [Source: src/bootstrap.asm:12,78] — `w_LIT_cf, <value>` immediate-literal idiom for laying the 1 in `MUTEX`/`UNLOCK`.
- [Source: tests/semaphore_tests.fth] — the probe template (task activation, 2-task budget, runtime witnesses, `BEGIN … 0 UNTIL`).
- [Source: Makefile:431-450] — `test-repl-semaphore` target + `.PHONY` (line 56) — the probe-target template.
- [Source: docs/phase6-multitasker.md:86-165] — counting-semaphore section + the operator-`WAIT` wedge callout (154-164) to extend for `LOCK`.
- [Source: _bmad-output/implementation-artifacts/26-1-counting-semaphore-signal-wait.md] — the immediately-prior story: DEFWORD idiom, byte-itemisation method, AC5 non-atomic proof, S9 recipe, 2-task budget lesson.
- Memory: `project_operator_wait_wedge`, `project_multitasker_pause_register_contract`, `project_phase6_concurrency_direction`, `feedback_defword_cf_label`, `feedback_testing_rules`, `feedback_repl_tests_preferred`, `feedback_cpm_0x1a_eof_marker`, `feedback_tib_size_inline_comments`, `feedback_post_hw_smoke_steps_at_review`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (create-story workflow)

### Debug Log References

- Probe (d) `mutex-exclusion-clean` first ran with `bad=1, consistent=19`: on the very
  first checker iteration the operator wins `LOCK` before the WRITER has stamped anything
  and reads **uninitialised** `WBUF` (CREATE…ALLOT leaves garbage; the two garbage halves
  happened to differ once). Fix: initialise both halves to `0` after `CREATE WBUF`
  (`0 WBUF !  0 WBUF CELL+ !`) so the buffer starts internally-consistent. Re-run:
  `bad=0, consistent=19` → PASS. Not a mutex defect — a test-fixture init omission; the
  mutex correctly serialised every subsequent read/write pair.

### Completion Notes List

- **Implemented as three thin `DEFWORD`s** in `src/multitasker.asm`, in the coordination
  section immediately after `WAIT` and above the `ASSERT $ <= SLOT2_WINDOW_BASE` fixed-memory
  guard (so all three stay in always-mapped memory below $8000). No edits to the scheduler
  ring, `PAUSE`, TCB, exception paths, or the existing semaphore words.
  - `MUTEX` = `1 SEMAPHORE` (`w_LIT_cf, 1, w_SEMAPHORE_cf, EXIT`): reuses `SEMAPHORE`'s
    parse-name-then-comma verbatim; `name @` starts at 1 (unlocked).
  - `LOCK` = `WAIT` re-exposed (`w_WAIT_cf, EXIT`): inherits PAUSE-first spin, non-atomic-
    but-safe take, ring-stays-alive, and the operator-wedge caveat (all by reference).
  - `UNLOCK` = `1 SWAP !` (`w_LIT_cf, 1, w_SWAP_cf, w_STORE_cf, EXIT`): stores 1 (binary
    clamp), NOT `SIGNAL`'s increment — double-`UNLOCK` is idempotent (count stays 1).
  - All three take the `DEFWORD` route (threaded lists of proven leaves), so the `PAUSE`
    register-contract (DE=IP preserved by every leaf) holds by construction — no raw Z80.
- **Design confirmed at dev-pass:** kept the recommended `UNLOCK = store-1` binary clamp
  (not `UNLOCK = SIGNAL`), per Dev Notes; AC3's double-`UNLOCK` witness asserts it.
- **Binary delta: +58 B** (30,518 → 30,576 B), exactly the itemised estimate. Per word
  (from the map / build): `MUTEX` ~20 B, `LOCK` ~15 B, `UNLOCK` ~23 B → 58 B. Well inside
  the F5 per-epic envelope; accept as pure addition (no SCP, NFR-P6-10).
- **Verification (emulator, iz-cpm-banking):** `make test-repl-mutex` → 6/6 PASS
  (`mutex-words-resolve`, `mutex-constructor-init`, `mutex-lock-unlock-cycle` incl. the AC3
  double-`UNLOCK`-stays-1 clamp + DEPTH-clean, `mutex-exclusion-clean` with runtime-computed
  `bad=0` / `consistent>0`, `mutex-ring-alive`, `mutex-alive`). Exclusion witnesses are
  RUNTIME-computed (never one echoed literal) — the 23.2 false-green defence.
- **Full gate sweep green at close:** `test-repl` 1005/0 (no regression), `test-repl-mutex`
  6/6, `test-repl-semaphore`, all `test-repl-multitasker-*`, `test-repl-timer`,
  `test-straddle-regression`, `check-doc-sync`, `test-file-sanity` — all OK.
- **S9 hardware-smoke on real MicroBeast / CP/M 2.2: PASS (2026-07-01).** Capture
  `beastty-20260701-222128.bin`; banner `AntForth v3.1.0 — 23440 bytes free — 12 banks`.
  All recipe steps green on silicon: `mutex m  m @ .`→1 (init), `m lock  m @ .`→0 (acquire),
  `m unlock  m @ .`→1 (release), `m unlock m unlock  m @ .`→**1** (binary clamp, not 2), and
  the background writer `W` / operator checker `C` two-task exclusion → `done` with **no
  "BAD"** and the prompt responsive. AC7 fully satisfied. (Same capture also re-smoked the
  26.1 semaphore; its `0 semaphore x x wait` operator-wedge line forced the documented reset
  before the SLIDE reload — the expected `project_operator_wait_wedge` footgun, not a defect.)

### File List

- `src/multitasker.asm` — MODIFIED: added `MUTEX` / `LOCK` / `UNLOCK` coordination words
  (three `DEFWORD`s) after `WAIT`, above the fixed-memory ASSERT.
- `tests/mutex_tests.fth` — NEW: 6-verdict REPL probe (words-resolve, constructor-init,
  lock-unlock-cycle + binary-clamp, exclusion-clean, ring-alive, alive).
- `Makefile` — MODIFIED: new `MUTEX_PROBE` var + `test-repl-mutex` target (not folded into
  `test-repl`) + `.PHONY` entry.
- `docs/phase6-multitasker.md` — MODIFIED: new "Coordination — the mutex" subsection
  (word surface, critical-section pattern, binary-clamp rationale, operator-`LOCK` footgun).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — MODIFIED: 26.2 → review.

## Change Log

| Date | Change |
|---|---|
| 2026-07-01 | Story 26.2 drafted (create-story). Mutex = binary semaphore: `MUTEX` (reuse `SEMAPHORE` at count 1), `LOCK` (reuse `WAIT`), `UNLOCK` (store-1 binary clamp, NOT `SIGNAL`). New `tests/mutex_tests.fth` + `test-repl-mutex`. Est. ≈ 50–70 B. Status → ready-for-dev. |
| 2026-07-01 | Story 26.2 developed (dev-story). Three `DEFWORD`s added to `src/multitasker.asm` coordination section; `+58 B` (30,518 → 30,576). New probe `tests/mutex_tests.fth` + `test-repl-mutex` (6/6). Docs subsection added. Full gate sweep green (test-repl 1005/0). Kept recommended binary-clamp `UNLOCK`. Status → review. S9 HW-smoke deferred to Ant (recipe in review-close chat). |
| 2026-07-01 | S9 hardware-smoke PASS on real MicroBeast / CP/M 2.2 (capture `beastty-20260701-222128.bin`, banner 23440 B free). Init/lock/unlock/double-unlock-clamp + two-task writer/checker exclusion all green (`c`→`done`, no BAD); AC7 fully satisfied. |
| 2026-07-01 | Code-review (high, recall-biased) — zero findings. Verified empirically: clean build (30,576 B), `test-repl-mutex` 6/6, neutered-LOCK discrimination test proves the exclusion probe is a genuine witness (not a 23.2 false-green), doc-sync 0-drift + straddle 3/3 + semaphore 6/6 green. Status → done. |
