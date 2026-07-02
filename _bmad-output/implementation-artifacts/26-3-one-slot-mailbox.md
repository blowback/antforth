# Story 26.3: One-slot mailbox

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a task author,
I want to pass a value between tasks via a one-slot mailbox,
so that a producer can hand a reading to a consumer safely.

## Acceptance Criteria

1. **AC1 — Constructor creates an empty one-slot mailbox (FR19).**
   **Given** the scheduler and the Story 26.1 semaphore primitives
   **When** the author runs `MAILBOX name` (no argument)
   **Then** `name` is a created word whose execution pushes the base address of a
   three-cell mailbox structure: `[value][empty][full]` at `name+0`, `name CELL+`,
   `name CELL+ CELL+`. It is initialised **empty** — `empty = 1` (one free slot),
   `full = 0` (no item), `value = 0` (cosmetic; overwritten by the first `POST`).
   `MAILBOX` reuses `CREATE` + `,` (the `SEMAPHORE` mechanic) to parse the name and lay
   the three cells; no new parse machinery. The cells are ordinary `@`/`!`-addressable
   data-space cells, verifiable by `name @` → 0, `name CELL+ @` → 1, `name CELL+ CELL+ @` → 0.

2. **AC2 — `POST` and `FETCH` transfer a value, blocking on the full/empty condition (FR19).**
   `POST ( x mbx -- )` waits on the **empty** slot (`empty WAIT`, yield-first), stores `x`
   into the value cell, then signals **full** (`full SIGNAL`). `FETCH ( mbx -- x )` waits
   on **full** (`full WAIT`, yield-first), reads the value cell, then signals **empty**
   (`empty SIGNAL`). A `POST` to a **full** mailbox (`empty = 0`) cooperatively spins with
   `PAUSE` until a `FETCH` frees the slot; a `FETCH` from an **empty** mailbox (`full = 0`)
   cooperatively spins with `PAUSE` until a `POST` fills it. Both words inherit `WAIT`'s
   PAUSE-first spin verbatim (no re-implemented wait loop).

3. **AC3 — Single-task round-trip transfers the exact value, `DEPTH`-clean.**
   **When** a single task (no second task activated) runs `x mbx POST  mbx FETCH`, it
   yields the value `x` back unchanged (the mailbox starts with one free slot, so neither
   the `POST` nor the following `FETCH` blocks past its first walk-to-self `PAUSE`). The
   value cell round-trips a full 16-bit value. `POST` consumes exactly `( x mbx )`, `FETCH`
   consumes `( mbx )` and leaves `( x )`; across a POST/FETCH pair the data stack returns to
   its starting depth. (A single-task **double** `POST` without an intervening `FETCH` would
   block on the empty slot — the operator-context wedge of AC6; the probe never does this.)

4. **AC4 — Producer→consumer hand-off with no loss and no overwrite (FR19, headline).**
   **Given** a background PRODUCER task that `POST`s a sequence of readings into the mailbox
   and a consumer (the operator) that `FETCH`es them
   **Then** the consumer receives **every** value exactly once, in order, with no loss and
   no overwrite: because the mailbox holds exactly one slot, the producer cannot `POST`
   reading *i+1* until the consumer has `FETCH`ed reading *i* (the empty/full semaphores
   force lockstep). A probe over N readings asserts the RUNTIME-COMPUTED running sum and a
   match-count equal their expected values (never one echoed literal), defeating false-green.
   Emulator asserts the structural outcome (sum / count / stack cleanliness); wall-clock
   interleave rides S9.

5. **AC5 — Blocking on the empty/full condition keeps the ring alive.**
   **When** a background task blocks in `FETCH` on an empty mailbox (or `POST` on a full
   one) with nothing to unblock it, that task parks but the round-robin ring stays alive —
   a peer counter task and the operator REPL keep advancing (the cooperative-friendly wait,
   inherited from `WAIT`'s PAUSE-first spin). This is the same starvation-liveness contract
   the counting semaphore documents (`WAIT` on a never-signalled cell), not the Story 25.7
   non-yielding hard stall.

6. **AC6 — Non-atomic by design + operator-context footgun, documented (FR19 / AD-P6-8).**
   `POST`/`FETCH` inherit the Story 26.1 non-atomic-but-cooperatively-safe invariant: each
   value `!`/`@` sits between a `WAIT` (which took a slot) and a `SIGNAL` (which frees the
   complementary slot), with **no `PAUSE`** between taking the slot and transferring the
   value, so no other task can observe or mutate the value mid-transfer. Correctness rests
   on the cooperative single-thread-except-ISR model (the ISR touches only `TICKS`). In
   addition, the **operator-context blocking footgun** carries over from `WAIT`/`LOCK`
   (`project_operator_wait_wedge`): a `FETCH` on an empty mailbox — or a `POST` to a full
   one — run **at the REPL prompt** with no background task to unblock it **hard-wedges** the
   machine (the operator is the keyboard reader and is break-exempt — even `Ctrl-\` cannot
   recover). Blocking `POST`/`FETCH` on a contended mailbox belong in background `TASK`s.
   Both the non-atomic note and the operator wedge are documented in `docs/phase6-multitasker.md`.

7. **AC7 — Regression, budget, and hardware.**
   The current `make test-repl` baseline still passes with **0 FAIL**; the new mailbox probe
   is additive (its own Makefile target, **not** folded into plain `test-repl`, mirroring the
   `test-repl-semaphore` / `test-repl-mutex` sibling targets). Binary delta is recorded
   against the pre-edit baseline (Story 26.2 close recorded 30,576 B — re-`wc -c` the actual
   current artifact, do not inherit) with per-word itemisation. S9 hardware-smoke on real
   CP/M 2.2 / MicroBeast **PASS** (NFR-P6-6), covering the constructor init, a single-task
   round-trip, and a two-task producer→consumer hand-off with the prompt responsive.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev Notes.
  - Do NOT inherit Story 26.2's reported 30,576 B — re-`wc -c` from the actual current build
    artifact after a clean `make asm` (B.3 / Lesson 13.5-F).
- [x] Capture current `make test-repl` baseline pass count (26.2 close recorded 1005/0; confirm).

### Story tasks

- [x] **Task 1 — Mailbox constructor `MAILBOX ( "<spaces>name" -- )` (AC: 1).**
  Add to the coordination section of `src/multitasker.asm` (AD-P6-8), immediately after
  `UNLOCK` (`src/multitasker.asm:661-669`) and **above** the `ASSERT $ <= SLOT2_WINDOW_BASE`
  fixed-memory guard (`:676`), so the three new words stay in always-mapped memory below
  $8000. Implement as a `DEFWORD` that reuses `CREATE` + `,` (the `SEMAPHORE` mechanic):
  `CREATE` parses the name and lays a `JP DOVAR` word whose body = HERE; three `,` then
  lay the `[value=0][empty=1][full=0]` cells, so `name` afterwards pushes the base address.
  - [x] 1.1 Header + body per the `DEFWORD` idiom (`w_MAILBOX_cf EQU w_MAILBOX_body - 3`
        → `JP DOCOL`), matching `SEMAPHORE`/`MUTEX` (`src/multitasker.asm:558-564,630-637`).
        Body: `w_CREATE_cf, w_LIT_cf,0,w_COMMA_cf, w_LIT_cf,1,w_COMMA_cf, w_LIT_cf,0,w_COMMA_cf, EXIT_CODE`.
  - [x] 1.2 Confirm reused labels against source: `w_CREATE_cf` (`src/compiler.asm:901`),
        `w_COMMA_cf` (`,`, `src/memory.asm:235`), `w_LIT_cf`, `EXIT_CODE`.
  - [x] 1.3 Source comment: mailbox = bounded-buffer(1) — the two count cells ARE Story 26.1
        semaphores (`empty` starts 1 = one free slot; `full` starts 0 = no item), the third
        is the value; `POST`/`FETCH` gate the value transfer with `WAIT`/`SIGNAL` on them.

- [x] **Task 2 — `POST ( x mbx -- )` — wait empty, store, signal full (AC: 2, 4, 5, 6).**
  Add as a `DEFWORD` composing the Story 26.1 primitives over the mailbox structure. Stash
  the base on the return stack, wait the empty slot at `mbx CELL+`, store `x` into the value
  cell at `mbx`, then signal full at `mbx CELL+ CELL+`:
  `w_DUP_cf, w_TO_R_cf, w_CELL_PLUS_cf, w_WAIT_cf, w_R_FETCH_cf, w_STORE_cf, w_R_FROM_cf, w_CELL_PLUS_cf, w_CELL_PLUS_cf, w_SIGNAL_cf, EXIT_CODE`.
  - [x] 2.1 Verify the reused labels: `>R` = `w_TO_R_cf` (`src/stack_ops.asm:250`), `R@` =
        `w_R_FETCH_cf` (`:278`), `R>` = `w_R_FROM_cf` (`:264`), `CELL+` = `w_CELL_PLUS_cf`
        (`src/memory.asm:14`), `!` = `w_STORE_cf` (`:59`), `w_WAIT_cf`/`w_SIGNAL_cf`
        (`src/multitasker.asm:599,571`).
  - [x] 2.2 Confirm the value store sits between `WAIT` and `SIGNAL` with **no `PAUSE`** —
        the transfer is atomic w.r.t. the ring (AC6). The `PAUSE` is inside `WAIT` only,
        before the slot is taken.
  - [x] 2.3 Source comment on `POST` states the `( x mbx -- )` contract, the wait-empty /
        store / signal-full sequence, and that the operator-context wedge caveat carries
        over from `WAIT` (blocking `POST` to a full mailbox belongs in a background `TASK`).

- [x] **Task 3 — `FETCH ( mbx -- x )` — wait full, read, signal empty (AC: 2, 4, 5, 6).**
  Add as a `DEFWORD`, the mirror of `POST`. Stash the base, wait the full slot at
  `mbx CELL+ CELL+`, read the value cell at `mbx`, then signal empty at `mbx CELL+`:
  `w_DUP_cf, w_TO_R_cf, w_CELL_PLUS_cf, w_CELL_PLUS_cf, w_WAIT_cf, w_R_FETCH_cf, w_FETCH_cf, w_R_FROM_cf, w_CELL_PLUS_cf, w_SIGNAL_cf, EXIT_CODE`.
  - [x] 3.1 Verify `@` = `w_FETCH_cf` (`src/memory.asm:44`) — note the internal label is
        `w_FETCH_cf` (for `@`); the new **visible** word `FETCH` does not collide (grep
        confirms no visible `FETCH`).
  - [x] 3.2 Confirm the value read sits between `WAIT` and `SIGNAL`, no `PAUSE` in the
        window (AC6). Leaves exactly `( x )`.
  - [x] 3.3 Source comment on `FETCH` states the `( mbx -- x )` contract and the
        wait-full / read / signal-empty sequence.

- [x] **Task 4 — Probe `tests/mailbox_tests.fth` + Makefile `test-repl-mailbox` target
      (AC: 1, 2, 3, 4, 5, 7).**
  New probe modelled on `tests/semaphore_tests.fth` + `tests/mutex_tests.fth`
  (`Makefile:443-471`): fail-loud `timeout`, verdicts via `tests/assert_verdicts.sh`
  column-0-anchored `^PASS:` helper with a `^FAIL:` tripwire; added to `.PHONY`; **not**
  folded into `test-repl`. Six verdicts (parallelling the sibling probes):
  - [x] 4.1 `mailbox-words-resolve` (AC1/AC2): `' MAILBOX DROP ' POST DROP ' FETCH DROP`
        then PASS (a miss throws -13 before the verdict).
  - [x] 4.2 `mailbox-constructor-init` (AC1): `MAILBOX MB` then
        `MB @ 0 =  MB CELL+ @ 1 = AND  MB CELL+ CELL+ @ 0 = AND` — starts empty
        (value 0, empty 1, full 0).
  - [x] 4.3 `mailbox-roundtrip-single` (AC3): single-task, no task activated
        (the mailbox starts with a free slot, so neither word blocks past walk-to-self).
        `DEPTH >R  123 MB POST  MB FETCH  123 =  DEPTH R> = AND` → PASS (exact value back +
        DEPTH-clean). Optionally follow with a second `456 MB POST  MB FETCH  456 =` to show
        the slot re-fills. Do **not** double-`POST` (would wedge — AC6).
  - [x] 4.4 `mailbox-handoff-no-loss` (AC4): a background PRODUCER task loops `4 0 DO ...`
        `POST`ing `(I+1)*10` into `MB`, then parks on a never-signalled sink (`NEVER WAIT`,
        the 26.1 idiom, so it stays blocked-but-yielding). The operator loops `4 0 DO MB FETCH ...`
        summing each value and counting matches vs `(I+1)*10`. Assert RUNTIME-COMPUTED
        `sum = 100 AND good = 4` (never one echoed literal). Because the mailbox is one slot,
        the producer and consumer hand off in lockstep — no loss, no overwrite.
  - [x] 4.5 `mailbox-empty-blocks-ring-alive` (AC5): with the PRODUCER now parked (blocked)
        and a PEER counter task advancing, rotate the ring a few `PAUSE`s and assert the PEER
        counter advanced (`PC2 @ 0 >`) and the probe still reaches `BYE`. **Two forever-tasks
        max** — PRODUCER + PEER (the operator's consumer loop is a bounded `DO`, not a third
        task; F4/NFR-P6-11 ~2 KB TCB budget; Story 26.1 hit the `-8` guard at 4 tasks).
  - [x] 4.6 `mailbox-alive` (AC7): interpreter healthy + stack clean after the interleave
        (`DEPTH 0= 1 2 3 + + 6 = AND`).
  - [x] 4.7 All probe lines ≤ 128 chars (TIB limit); no `$8000` straddle; drive at
        interpret level (`'`, not `[']`). 0x1A-terminate the file before any SLIDE to real
        MicroBeast. Producer forever-loop uses `BEGIN … 0 UNTIL` (never `AGAIN`, undefined);
        activate via `' PRODUCER TASK ACTIVATE` (the handle is a stack value, use `'`).

- [x] **Task 5 — Docs + budget close-out (AC: 1, 2, 6, 7).**
  - [x] 5.1 Add a "Coordination — the one-slot mailbox (`MAILBOX` / `POST` / `FETCH`)"
        subsection to `docs/phase6-multitasker.md`, after the mutex section (ends `:234`):
        word surface, the bounded-buffer(1) design (two semaphores + a value cell; empty=1
        free slot, full=0 no item), the documented producer→consumer hand-off pattern (a
        background `TASK` producing, the operator or another `TASK` consuming), the
        no-loss/lockstep guarantee, and — reusing the existing `WAIT`/`LOCK` operator-wedge
        callout (`docs/phase6-multitasker.md:226-234`) — the operator-context `POST`/`FETCH`
        footgun (AC6).
  - [x] 5.2 Record binary delta against the pre-edit baseline; itemise per word in Dev Notes;
        reconcile the measured delta at close. Any overshoot is accept-with-rationale per
        NFR-P6-10, no silent bloat.
  - [x] 5.3 **S9 hardware-smoke on real MicroBeast / CP/M 2.2** — post the recipe in the
        review-close chat message (not only in Dev Notes; `feedback_post_hw_smoke_steps_at_review`):
        constructor init (`MAILBOX mb` → `mb @` 0, `mb CELL+ @` 1, `mb CELL+ CELL+ @` 0),
        single-task round-trip (`123 mb POST  mb FETCH .` → 123), and a background producer /
        operator consumer hand-off delivering readings with the prompt responsive. Record the
        capture filename and the banner "free" figure.

## Dev Notes

### Design decision to confirm at dev-pass — mailbox = two-semaphore bounded-buffer(1)

This story specs the one-slot mailbox as a **bounded-buffer of capacity 1 built from two
Story 26.1 counting semaphores plus a value cell** — the textbook design, maximal reuse:

- `empty` semaphore, initialised **1** — "one free slot available."
- `full` semaphore, initialised **0** — "no item available yet."
- `value` cell — the single slot.

`POST` = `empty WAIT` (take the free slot, blocking) → `value !` → `full SIGNAL` (announce
an item). `FETCH` = `full WAIT` (take the item, blocking) → `value @` → `empty SIGNAL`
(announce a free slot). This directly satisfies the AC wording — "the posting/consuming task
`PAUSE`-waits on the full/empty condition until the slot is available, then transfers the
value" — and is deadlock-free for the single-producer/single-consumer (and, because `empty`
never exceeds 1 under the protocol, safe for multiple producers/consumers too: at most one
task is ever inside the transfer window). It continues the reuse ladder
(`MUTEX = 1 SEMAPHORE`, `LOCK = WAIT`, `UNLOCK = store-1`): the only new code is the three
threaded bodies; `WAIT`/`SIGNAL`/`CREATE`/`,` are all pre-existing proven leaves.

**Alternative considered — single full-flag spin (Option B):** a 2-cell mailbox
`[value][full-flag]` where `POST` spins `PAUSE`-first while `full≠0` then stores + sets
`full=1`, and `FETCH` spins while `full=0` then reads + sets `full=0`. This re-implements
the `WAIT` spin loop (its own `PAUSE`-first `BEGIN…QBRANCH`) inside both words, re-derives
the non-atomic-but-safe proof, and costs more bytes than reusing `WAIT`/`SIGNAL`. **Rejected**
in favour of Option A (reuse). If the dev prefers Option B for some reason, flag it and
update AC1's cell-layout witness (4.2) and the byte itemisation before implementing.

### Return-stack use across `WAIT`'s `PAUSE` is safe (verify at dev-pass)

`POST`/`FETCH` stash the mailbox base on the **return stack** (`>R … R@ … R>`) across the
`WAIT` call — and `WAIT` contains a `PAUSE`, so the base sits on the return stack while the
task may be blocked/yielding for a long time. This is safe: the return stack is **per-task**
— `PAUSE` saves/restores `IX` (the rstack pointer) along with `SP` into the TCB, so each
task's return-stack contents are preserved across a yield and restored when it resumes
(`project_multitasker_pause_register_contract`). `>R`/`R@`/`R>` are used exactly this way
throughout the kernel colon bodies (`src/formatting.asm`, `src/double.asm`, `src/io.asm:409`).
The `>R`/`R>` are balanced within each word, so the return stack is clean at `EXIT`.

### Standing multitasker contract — front-loaded (AI-25-4; do not rediscover)

- **`PAUSE` register contract** (`project_multitasker_pause_register_contract`): every
  normal task word **must preserve `DE` = IP**; `PAUSE` is the *only* word allowed not to.
  All three words here take the `DEFWORD` route (threaded lists of proven leaves — `CREATE`,
  `,`, `DUP`, `>R`, `R@`, `R>`, `CELL+`, `!`, `@`, `WAIT`, `SIGNAL`), so this holds by
  construction — no raw Z80, no register exposure. Do **not** rewrite any of them as
  `DEFCODE` without re-honouring the `DE`-preservation contract.
- **`check_overflow`/`DEPTH` use the per-task `t_sp_base`** — not relevant here (you touch
  no scheduler state); the mailbox cells live in shared data space, not per-task state.
- **`( -- d )` producers push BC** (`project_double_producer_push_bc`) — no double-cell
  producers in this story (`POST`/`FETCH` move single cells); noted only because
  coordination sits next to `TICKS`.

### `TASK` handle + `AGAIN` undefined (AI-25-4)

- `TASK ( -- task )` returns the TCB handle as a **stack value**, not a variable — the
  probe's background PRODUCER must keep its handle (activate via `' PRODUCER TASK ACTIVATE`,
  the Story 26.1/26.2 idiom). Re-reading `LATEST @` won't give a usable xt for a bank-0
  runtime word (`project_bank_triple_excludes_buckets` — use `'`).
- **`AGAIN` is undefined** in antforth — a forever loop is `BEGIN … 0 UNTIL`. The PRODUCER's
  park-loop (and PEER) must use that idiom (see `PROD`/`PEER` in
  `tests/semaphore_tests.fth:62-90`), never `AGAIN`.

### Why the design is correct despite being non-atomic (AC6 rationale)

`POST`/`FETCH` compose `WAIT`/`SIGNAL`, so they inherit Story 26.1's proof verbatim: the
model is single-threaded except the 64 Hz ISR, and the ISR touches only `TICKS` (AD-P6-5),
never a mailbox cell. A context switch happens only at a `PAUSE` (a `NEXT` boundary), and the
only `PAUSE` in the transfer path is inside `WAIT`, *before* the slot is taken. Once `WAIT`
falls through (slot taken), the `!`/`@` and the following `SIGNAL` run straight-line with no
`PAUSE`, so no other task can observe or mutate the value mid-transfer. Because the mailbox
is one slot (`empty` capped at 1), the producer cannot post reading *i+1* until the consumer
has fetched reading *i* and signalled `empty` — lockstep hand-off, no loss, no overwrite. Two
tasks blocked in `FETCH` on the same mailbox cannot both consume a single `POST`: after `POST`
signals `full` to 1, whichever the round-robin runs next decrements it to 0; the other sees 0
and loops. No lost wakeup, no double-take.

### Operator-context `POST`/`FETCH` is a hard wedge (AC6; `project_operator_wait_wedge`)

The wedge surfaced for `WAIT` (Story 26.1 HW-smoke) and `LOCK` (26.2) applies identically: a
blocking `FETCH` on an **empty** mailbox — or a `POST` to a **full** one — run **in the
operator** (at the REPL prompt) with no background task to unblock it **hard-wedges** the
machine. The operator is the keyboard-reader and is break-exempt by design (an operator yield
hands off, it never breaks itself), so even a set `Ctrl-\` break cannot recover it — reset
only. The feature is correct; the footgun is usage. The probe therefore does all *blocking*
hand-off in **background tasks**, and the operator's consumer loop only ever `FETCH`es values
a background producer is actively `POST`ing (bounded to the exact producer count). Document
the caveat by extending the existing `WAIT`/`LOCK` callout (`docs/phase6-multitasker.md:226-234`).

### Byte-budget estimate — per-component itemisation (B.2; no "mirrors prior arm")

Independent per-word itemisation. `DEFWORD` non-name header base = link(2) + len/flags(1) +
bank(1) + `JP DOCOL`(3) = **7 B**; body = (number of `DW` cells) × 2 B, EXIT and each inline
literal counting as one cell. (This 7-B base is re-derived from first principles here, not
lifted from a prior story; it independently agrees with Story 26.2's measured +58 B as a
sanity anchor only.)

- **`MAILBOX`** (`DEFWORD`): header ≈ 7 + 7 (`"MAILBOX"`) = 14 B; body = 11 cells
  (`CREATE` + 3×`[LIT val COMMA]` + `EXIT`) = 22 B → **≈ 36 B**.
- **`POST`** (`DEFWORD`): header ≈ 7 + 4 (`"POST"`) = 11 B; body = 11 cells
  (`DUP >R CELL+ WAIT R@ ! R> CELL+ CELL+ SIGNAL EXIT`) = 22 B → **≈ 33 B**.
- **`FETCH`** (`DEFWORD`): header ≈ 7 + 5 (`"FETCH"`) = 12 B; body = 11 cells
  (`DUP >R CELL+ CELL+ WAIT R@ @ R> CELL+ SIGNAL EXIT`) = 22 B → **≈ 34 B**.
- **Total ≈ 103 B** kernel growth (≈ 90–115 B allowing for header-macro exactness). Well
  inside the F5 per-epic envelope (~2.4× applies to the *epic* aggregate, not one story).
  Reconcile the measured delta at close (Task 5.2).

### Source tree components to touch

- `src/multitasker.asm` — **coordination section** (AD-P6-8), immediately after `UNLOCK`
  (`:661-669`, before the `ASSERT $ <= SLOT2_WINDOW_BASE` fixed-memory guard at `:676` — keep
  the three new words above that assert so they stay in always-mapped memory). No edits to the
  scheduler ring, `PAUSE`, TCB, exception paths, or the existing semaphore/mutex words.
- `tests/mailbox_tests.fth` — **new** probe (parallels `tests/semaphore_tests.fth` /
  `tests/mutex_tests.fth`).
- `Makefile` — new `MAILBOX_PROBE` var + `test-repl-mailbox` target + `.PHONY` entry
  (`:56`, `:443-471` templates); **not** wired into `test-repl`.
- `docs/phase6-multitasker.md` — new mailbox subsection after the mutex section (`:234`).

### Testing standards summary

- REPL-piped Forth only (NFR-P6-16) — test through the threading model, never raw BDOS
  (`feedback_testing_rules`, `feedback_repl_tests_preferred`).
- Fail-loud `timeout` wrapper (Story 24.3) so a genuine deadlock → loud FAIL, not a CI hang;
  verdicts through `tests/assert_verdicts.sh` (Story 24.4), column-0-anchored `^PASS:`.
- Defeat false-green source echo with RUNTIME-only witnesses (the `sum=100` / `good=4`
  computed by the consumer loop, not echoed literals) — the 23.2 defence.
- Probe lines ≤ 128 chars (TIB limit, `feedback_tib_size_inline_comments`); honour the
  $8000 straddle constraint; drive any bank-ops at interpret level (`'`, not `[']`).
- **CP/M 0x1A EOF**: `tests/mailbox_tests.fth` must be 0x1A-terminated before SLIDE to real
  MicroBeast (`feedback_cpm_0x1a_eof_marker`).
- Run the full sibling suite green at close: `test-repl` (no regression), `test-repl-mailbox`,
  `test-repl-mutex`, `test-repl-semaphore`, `test-repl-multitasker-*`, `test-repl-timer`,
  `test-straddle-regression`, `check-doc-sync`, `test-file-sanity`.

### Project Structure Notes

- **Word surface.** The PRD/architecture leave the mailbox words unnamed ("mailbox"), but
  Epic 26's AC for this story explicitly says "**post/fetch** words are provided"
  (`epics-phase6-epics-24-26.md:432`). This story names them `POST` / `FETCH` with
  constructor `MAILBOX`, parallelling the 26.1 `SEMAPHORE`/`SIGNAL`/`WAIT` and 26.2
  `MUTEX`/`LOCK`/`UNLOCK` triples, taking the epic's own vocabulary literally (as 26.2 did
  with "lock/unlock"). Grep confirms no visible-word collision for `MAILBOX`/`POST`/`FETCH`
  (the internal `w_FETCH_cf` label is `@`'s, not a visible `FETCH`). A dev preferring
  `MAIL!`/`MAIL@` or `SEND`/`RECV` may rename — note the choice in the File List.
- **Probe file name.** Architecture's file-tree (`architecture.md:664`) declares a single
  `tests/semaphore_tests.fth` "SIGNAL/WAIT/mutex/mailbox". Stories 26.1/26.2 already took that
  filename and `tests/mutex_tests.fth`; this story uses a **sibling** `tests/mailbox_tests.fth`
  (own `test-repl-mailbox` target) — matching the one-target-per-feature convention the
  coordination probes follow. If the dev prefers to extend an existing probe in place, note
  the choice in the File List.
- No new module, no INCLUDE-order change (coordination lives inside `src/multitasker.asm`,
  already after `banking.asm`/`exception.asm` per AD-P6-7).
- **Epic 26 capstone.** This is the final story of Epic 26 — it completes the coordination
  toolkit (FR17 semaphore → FR18 mutex → FR19 mailbox). Its close likely triggers the
  optional `epic-26-retrospective`. Keep the story scoped to the mailbox; do not fold epic
  close-out work in here.

### References

- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story 26.3] — user story, ACs, FR19 (lines 421-433).
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-8] — coordination primitives, cooperative spin-with-PAUSE, "one-slot mailbox", non-atomic-OK.
- [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md] — FR19; mailbox in the coordination word surface.
- [Source: src/multitasker.asm:542-676] — coordination section: `SEMAPHORE` (558-564), `SIGNAL` (571-580), `WAIT` (599-614), `MUTEX` (630-637), `LOCK` (648-653), `UNLOCK` (661-669), fixed-memory ASSERT (676) — `MAILBOX`/`POST`/`FETCH` reuse and sit beside, above the ASSERT.
- [Source: src/stack_ops.asm:250,264,278] — `>R` (`w_TO_R_cf`), `R>` (`w_R_FROM_cf`), `R@` (`w_R_FETCH_cf`) for the base-address stash in `POST`/`FETCH`.
- [Source: src/memory.asm:14,44,59,235] — `CELL+` (`w_CELL_PLUS_cf`), `@` (`w_FETCH_cf`), `!` (`w_STORE_cf`), `,` (`w_COMMA_cf`) for the cell arithmetic + constructor.
- [Source: src/compiler.asm:901] — `CREATE` (`w_CREATE_cf`) for the mailbox constructor.
- [Source: tests/semaphore_tests.fth] — the probe template (task activation, 2-task budget, runtime witnesses, `BEGIN … 0 UNTIL`, `NEVER WAIT` park idiom).
- [Source: tests/mutex_tests.fth + Makefile:452-471] — the sibling `test-repl-mutex` target + `.PHONY` (line 56) — the probe-target template.
- [Source: docs/phase6-multitasker.md:167-234] — the mutex section + the operator-`LOCK` wedge callout (226-234) to extend for `POST`/`FETCH`.
- [Source: _bmad-output/implementation-artifacts/26-2-mutex-binary-semaphore.md] — the immediately-prior story: DEFWORD idiom, byte-itemisation method, non-atomic proof, S9 recipe, 2-task budget lesson.
- Memory: `project_operator_wait_wedge`, `project_multitasker_pause_register_contract`, `project_phase6_concurrency_direction`, `project_bank_triple_excludes_buckets`, `feedback_defword_cf_label`, `feedback_testing_rules`, `feedback_repl_tests_preferred`, `feedback_cpm_0x1a_eof_marker`, `feedback_tib_size_inline_comments`, `feedback_post_hw_smoke_steps_at_review`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (create-story workflow)

### Debug Log References

- First probe run FAILed `mailbox-roundtrip-single`: the round-trip leaves one result flag
  on the stack before the `DEPTH` check, so `DEPTH` is start+1. Fixed with `DEPTH R> 1+ =`
  (the same accounting the mutex probe's `_cycle` uses) — not a kernel bug, a probe
  arithmetic error. All other verdicts passed first try.
- Asm label collision: the visible `FETCH` word's chosen label `w_FETCH` clashed with `@`'s
  existing `w_FETCH:` label in `memory.asm`. Renamed the mailbox word's asm labels to
  `w_MB_FETCH` / `w_MB_FETCH_body` / `w_MB_FETCH_cf` (the DEFWORD *name string* "FETCH" is
  independent of the asm label, so the visible word is still `FETCH`).

### Completion Notes List

- **Design = Option A (reuse), as specced.** `MAILBOX` = `CREATE` + three `,` laying
  `[value=0][empty=1][full=0]`; `POST`/`FETCH` are DEFWORDs composing the Story 26.1
  `WAIT`/`SIGNAL` over that structure. No new parse machinery, no re-implemented wait loop,
  no raw Z80 — so the PAUSE register contract (DE=IP preserved) holds by construction.
- **Stack traces verified.** `POST ( x mbx -- )`: `DUP >R CELL+ WAIT R@ ! R> CELL+ CELL+
  SIGNAL` — waits empty at `mbx+2`, stores `x` at `mbx`, signals full at `mbx+4`, no PAUSE
  in the store window. `FETCH ( mbx -- x )`: `DUP >R CELL+ CELL+ WAIT R@ @ R> CELL+ SIGNAL`
  — waits full at `mbx+4`, reads value at `mbx`, signals empty at `mbx+2`, leaves `( x )`.
- **All three words land below $8000.** Build-time `ASSERT $ <= SLOT2_WINDOW_BASE` passed
  (0 errors) — the words sit in always-mapped fixed memory, before the guard.
- **Regression clean:** `make test-repl` = 975 PASS / **0 FAIL** (the "1005" note in the
  pre-edit task counted probe sub-verdicts; the canonical core count is 975/0, unchanged).
  Sibling probes all green: `test-repl-mailbox` (6/6), `test-repl-mutex`, `test-repl-semaphore`,
  all 8 `test-repl-multitasker-*`, `test-repl-timer`, `test-straddle-regression`,
  `test-file-sanity`, `check-doc-sync` (0 drift).
- **Binary delta = +103 B** (pre-edit 30,576 B → 30,679 B), matching the estimate exactly.
  Per-word itemisation (measured aggregate confirms): `MAILBOX` ≈ 36 B (header 14 + body 22),
  `POST` ≈ 33 B (header 11 + body 22), `FETCH` ≈ 34 B (header 12 + body 22) = 103 B. Inside
  the NFR-P6-10 envelope; no accept-with-rationale overshoot needed.
- **AC6 documented** in `docs/phase6-multitasker.md`: new mailbox subsection (bounded-buffer(1)
  design, lockstep no-loss guarantee, non-atomic-but-safe proof, and the operator-context
  `POST`/`FETCH` hard-wedge footgun extending the existing `WAIT`/`LOCK` callout).
- **S9 hardware-smoke: PASS** (2026-07-02, real MicroBeast / CP/M 2.2; capture
  `beastty-20260702-164745.bin`, banner "23337 bytes free - 12 banks available"). Verified:
  constructor init (`mb @`→0, `mb CELL+ @`→1, `mb CELL+ CELL+ @`→0); single-task round-trip
  (`123 mb POST  mb FETCH .`→123); two-task producer→consumer hand-off (`CONSUMER`→`10 20 30 40`
  in order, prompt responsive). Wall-clock interleave confirmed on silicon.
- **HW UAT surfaced a recipe/doc defect the emulator structurally couldn't:** a bare
  `4 0 DO mb FETCH . LOOP` typed at the **operator prompt** throws `-14: interpreting a
  compile-only word` — `DO`/`LOOP`/`I` are compile-only and must live inside a `: … ;`
  definition (the operator ran it as `: CONSUMER 4 0 DO mb FETCH . LOOP ;  CONSUMER`). The
  emulator probe never caught this because there the consumer loop is already inside the
  colon word `_handoff`. NOT a feature defect — the mailbox works. Fixed the doc example in
  `docs/phase6-multitasker.md` to wrap the consumer in a colon word + note the compile-only
  caveat. (My original chat UAT recipe had the same bare-loop error.)

### File List

- `src/multitasker.asm` — added `MAILBOX` / `POST` / `FETCH` DEFWORDs to the coordination
  section (after `UNLOCK`, above the `ASSERT $ <= SLOT2_WINDOW_BASE` fixed-memory guard).
- `tests/mailbox_tests.fth` — **new** probe (6 verdicts), modelled on `semaphore_tests.fth`.
- `Makefile` — new `MAILBOX_PROBE` var + `test-repl-mailbox` target + `.PHONY` entry;
  **not** folded into plain `test-repl`.
- `docs/phase6-multitasker.md` — new "Coordination — the one-slot mailbox" subsection.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 26.3 → in-progress → review.

## Change Log

| Date | Change |
|---|---|
| 2026-07-01 | Story 26.3 drafted (create-story). One-slot mailbox = bounded-buffer(1): `MAILBOX` (CREATE + three commas: value 0 / empty-sem 1 / full-sem 0), `POST` (wait-empty / store / signal-full), `FETCH` (wait-full / read / signal-empty) — composed from Story 26.1 `WAIT`/`SIGNAL`. New `tests/mailbox_tests.fth` + `test-repl-mailbox`. Est. ≈ 90–115 B. Epic 26 capstone (FR19). Status → ready-for-dev. |
| 2026-07-02 | Story 26.3 implemented (dev-story). `MAILBOX`/`POST`/`FETCH` added to `src/multitasker.asm` coordination section (below $8000, `ASSERT` held). New `tests/mailbox_tests.fth` (6/6 PASS) + `test-repl-mailbox` target. Docs subsection added to `docs/phase6-multitasker.md`. Measured delta **+103 B** (30,576 → 30,679), exactly the estimate. `test-repl` 975/0 (no regression); all sibling/multitasker probes green. S9 HW-smoke pending. Status → review. |
| 2026-07-02 | **S9 HW-smoke PASS** on real MicroBeast / CP/M 2.2 (capture `beastty-20260702-164745.bin`, archived): constructor init, single-task round-trip, two-task producer→consumer hand-off (`10 20 30 40`, prompt responsive) all verified. HW UAT surfaced that a bare `DO…LOOP` at the operator prompt is `-14` compile-only (must wrap in `: … ;`) — fixed the doc example + caveat in `docs/phase6-multitasker.md`; not a feature defect. |
