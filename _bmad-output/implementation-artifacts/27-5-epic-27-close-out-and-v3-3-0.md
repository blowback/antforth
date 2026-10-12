# Story 27.5: Epic 27 close-out and v3.3.0

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-10-12 by create-story. Figures below were measured at draft
     time on HEAD 50537ba (31,395 B). They are orientation, not authority:
     the dev pass re-measures every one (B.3 / PD-2). -->

## Story

As the project lead,
I want the v3.3.0 close-out checks run and the one known regression fixed,
so that the release ships with every test target green, the version surface
reading v3.3.0, and the docs matching what Epic 27 shipped.

## Draft-time findings (read first)

1. **The release is currently blocked by a regression.**
   `make test-repl-multitasker-bank` fails on HEAD `50537ba` (31,395 B): 16
   PASS / 10 FAIL, the second `TASK` raises `error -8: dictionary overflow`.
   The target is not a `test-repl` prerequisite, so 27.7's review follow-up
   (+36 B, the `WORD` cap) didn't run it. 27.7's dev record has all multitasker
   targets green at 31,359 B. Cause: the open dev-journal entry "2026-10-11
   (OPEN) — fixed RAM below `$8000` now holds only two TCBs". It predicted this:
   that probe had 14 B to spare at 31,336 B and the kernel has grown 59 B since.
   The other 11 timer/multitasker/semaphore/mutex/mailbox targets pass.
2. **Room below `$8000` at 31,395 B:** boot `HERE` = 31,651, leaving **1,117 B**
   (`DECIMAL HERE U. 32768 HERE - .` at a fresh prompt). A TCB is
   `TCB_HDR_SIZE` 23 + `PS_SIZE` 256 + `RS_SIZE` 256 = 535 B, 547 B with the
   `CONSTANT` that names it. Two named TCBs take 1,094 B, which leaves **23 B**.
   `disk/a/TRAFFIC.FTH` and `test-repl-multitasker-demo` carve two TCBs first,
   so they still pass, but the next kernel story that adds more than about 23 B
   breaks them too.
3. **Why the bank probe can't fit two TCBs any more.**
   `tests/multitasker_bank_tests.fth` defines `TAPE`/`APP`/`BG` *before*
   `TASK CONSTANT BT1` / `TASK CONSTANT BT2`. That order is deliberate: `BG`
   runs in a task that owns bank 1, so its body must sit below `$8000`, in
   fixed RAM that every bank can see. With 1,117 B, two TCBs plus `BG`'s code
   no longer fit.
4. **Byte ledger (re-measure; don't copy).** v3.2.1 tag artifact rebuilt fresh in
   a worktree at draft time: **30,754 B**. Per-story records:

   | Story | Before → after (B) | Delta |
   |---|---|---|
   | 27.1 `NIP` `TUCK` `-ROT` `?` | 30,754 → 30,830 | +76 |
   | 27.2 comparisons | 30,830 → 31,009 | +179 |
   | 27.3 `AGAIN` | 31,009 → 31,017 | +8 |
   | 27.4 `?DO` | 31,017 → 31,077 | +60 |
   | 27.6 underflow checks (+ review fix +12) | 31,077 → 31,348 | +271 |
   | 27.7 `+BANK` / `$BF58` ceiling (+ `WORD` cap +36) | 31,348 → 31,395 | +47 |
   | **Epic 27** | **30,754 → 31,395** | **+641** |

   The per-story sum (641) matches start → HEAD (641), so nothing is lost between
   stories. The envelope is ≤ 500 B (NFR-P7-2). The overage was accepted for
   27.6 on 2026-10-11 (≈ 55 unchecked sites plus the assembler, not ≈ 20). 27.7's
   +47 B is a bug fix found during the epic. Without 27.6 and 27.7 the epic is
   323 B against an estimate of ≈ 340 B.
5. **Version surfaces (four, change together):**
   - `src/antforth.asm:802` `str_banner1` `"AntForth v3.2.1 (C) ant.org 2026"`.
     `v3.2.1` → `v3.3.0` is the same length → **0 B**.
   - `Makefile:2764-2767` REPL test 80 asserts `AntForth v3.2.1`. If it isn't
     bumped, `test-repl` fails at test 80.
   - `README.md:26` `## Version 3.2.1`, the `**3.2.1 is a fix release.**`
     paragraph at `:33`, and the release-history list at `:117`.
   - `.github/workflows/release.yml:76-87` fails the GitHub release if the built
     binary's banner doesn't contain `AntForth <tag> `. Pushing tag `v3.3.0`
     triggers that workflow, so the banner bump has to be in the tagged commit.
6. **Other doc drift found at draft time:**
   - `src/system.asm:577` env_table comment still reads `13/46`. The compliance
     doc and README both say **23 / 46** after Epic 27 (17 after 27.1, + 4 from
     27.2, + `AGAIN`, + `?DO`). The comment changes; the value stays `false`
     (0 B).
   - The README "Beyond the standard" table (`README.md:62-70`) doesn't list the
     three extensions `-ROT`, `<=`, `>=`. The compliance doc already lists them
     at `:867-869`.
   - `docs/WISHLIST.md` still lists "Multitasker" (`:18`), "Semaphores" (`:34`)
     and "Z80 IO primitives" (`:58`) as wishes. They shipped in v3.2.0, v3.2.0
     and v3.1.0. The only "Shipped" section is v2.0 (`:109`).
   - `make check-doc-sync`: **15 advisories / 0 drift** at draft time.
   - `docs/dev_journal.md` top list: every Epic-27 word is marked RESOLVED
     (`:9-10`, `:16-17`, `:21-22`, `:24-25`). The 27.6 and 27.7 entries are
     RESOLVED. Still OPEN: the TCB-room entry (`:28`), and the 2026-09-02
     "unbalanced colon body" note, which the project lead decided to leave as it
     is. Neither is an Epic-27 word.
7. **Hardware items not run yet**, to fold into the combined smoke:
   - 27.7 S9 step 7 (`WORD` cap → `-18`): the cap landed after 27.7's hardware
     run (that run used 31,359 B).
   - 27.7 S9 step 6 (`INCLUDE P193IRON.FTH`): missing from the 27.7 transcript.
   - 27.1's unexplained stray `5` after `variable v 5 42 v ! v ?`: needs a
     fresh-session replay on hardware.

## Acceptance Criteria

1. **Regression fixed before anything else (release blocker).**
   `make test-repl-multitasker-bank` passes on the candidate binary. The probe
   still tests a task that owns bank 1 switching against an operator in bank 0,
   plus a same-bank control run. **Fix the probe only, 0 kernel bytes**
   (project lead, 2026-10-12): carve `BT1` first, define `TAPE`/`APP`/`BG`
   after it (still below `$8000`), drop `BT2`, and re-`ACTIVATE` `BT1` for the
   same-bank control once `BG` has exited. Re-`ACTIVATE` of an exited task is
   the supported path (`src/multitasker.asm:403`). No kernel change for the
   task-room limit in this story.
2. **The multitasker targets can't be skipped again.** `test-repl-timer`,
   `test-repl-multitasker`, `-key`, `-delay`, `-tasks`, `-throw`, `-break`,
   `-bank`, `-demo`, `test-repl-semaphore`, `test-repl-mutex` and
   `test-repl-mailbox` become prerequisites of `test-repl`, so a kernel story
   that runs `make test-repl` also runs them. The runtime increase is recorded.
3. **Full sweep green on the final binary (NFR-P7-1).** All of these pass, with
   counts recorded in Dev Notes:
   - `make test` passes.
   - `make test-repl` is 0 FAIL. The count is the 1012 v3.2.1 baseline plus every
     probe Epic 27 added, plus whatever AC2 adds. None are removed.
   - Every other `test-*` target and `lint-banking-probes`. Take the list fresh
     from the `.PHONY` line (`Makefile:56`) plus `test-repl-cr-21-3`, which
     exists but isn't on that line. Don't copy this list.
   - `make check-doc-sync` shows 0 drift.

   A single FAIL or timeout blocks the tag.
4. **Combined hardware smoke passes on real MicroBeast (NFR-P7-7).** One session
   on the v3.3.0 binary covers:
   - the banner reading `AntForth v3.3.0`;
   - one line per Epic-27 word: `NIP`, `TUCK`, `-ROT`, `?`, `<>`, `0<>`, `0>`,
     `U>`, `<=`, `>=`, `AGAIN`, `?DO`;
   - empty-stack `-4` spot checks (`DUP`, `0=`, `1+`);
   - `TRAFFIC.FTH` as a background task;
   - the 27.7 repros, including steps 6 and 7 (finding 7);
   - the 27.1 fresh-session replay.

   The recipe and the transcript filename go **in the closing review chat
   message** (`feedback_post_hw_smoke_steps_at_review`).
5. **Byte delta logged (NFR-P7-2).** Dev Notes record the final size and the
   delta against the v3.2.1 artifact (30,754 B), both re-measured with a fresh
   `make clean && make && wc -c build/antforth.com`. The table in finding 4 is
   filled in with the re-measured figures, and the overage past the 500 B
   envelope is stated with its reason. This story's own delta is expected to be
   **0 B** (see Byte budget).
6. **Version surface reads v3.3.0 (S11).**
   - The banner, REPL test 80 and `README.md` say v3.3.0.
   - The README gets a short "3.3.0" paragraph under `## Version` that replaces
     the 3.2.1 fix-release paragraph, plus a release-history entry.
   - The README "Beyond the standard" table gains `-ROT`, `<=`, `>=`.
   - `src/system.asm:577` reads `23/46`, and `ENVIRONMENT? CORE-EXT` still
     answers false (`env-core-x` in `test-repl-ud-env`).
7. **Docs match what shipped.**
   - The compliance doc's §6.2 count, the README Standards-coverage row and the
     env_table comment all agree. Count the table rows; don't take the number
     from prose.
   - `docs/WISHLIST.md` moves Multitasker, Semaphores and Z80 IO primitives into
     a "Shipped in v3.x" section next to the v2.0 one, and names the Epic-27
     words that came from the dev-journal "Small tasks" list.
   - `docs/phase6-multitasker.md` states the task limit: TCBs must sit below
     `$8000`, carve them before other definitions, and on the v3.3.0 binary
     there is room for N (measured).
   - The TCB-room dev-journal entry stays OPEN, with the v3.3.0 figures and the
     AC1 fix added.
8. **Memory.** A Phase-7 project memory records:
   - v3.3.0 and Epic 27 closed;
   - the +641 B delta (or the re-measured figure) and why it passed the 500 B
     envelope;
   - the open TCB-room limit (two TCBs, N bytes spare);
   - that multitasker targets are now `test-repl` prerequisites.

   It gets a `MEMORY.md` index line. `project_phase6_concurrency_direction.md`
   loses its stale "No Epic 27; roadmap ends at 26" line.
9. **Tag left to the project lead.** The close-out commit goes on `main` with no
   Claude co-author trailer (`feedback_no_claude_coauthor`). The closing message
   gives the exact `git tag v3.3.0 <commit>` and `git push origin v3.3.0`
   commands. It also notes that the push starts `.github/workflows/release.yml`,
   which builds the binary, checks the banner and publishes
   `antforth-v3.3.0.com`.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Draft-time reading was 31,395 B (HEAD `50537ba`) — confirm, don't copy.
- [x] Capture current `make test-repl` baseline pass count (27.7's close recorded 1147 PASS / 0 FAIL — re-measure)
- [x] Rebuild the `v3.2.1` tag in a throwaway worktree and `wc -c` it (draft: 30,754 B). This is the AC5 denominator.
- [x] Run every multitasker-family target and record PASS/FAIL (draft: only `-bank` fails, 16/10).

### Story tasks

- [x] **Task 1 — Fix `test-repl-multitasker-bank` (AC1)**
  - [x] 1.1 (Decided 2026-10-12: probe-only fix, no kernel change.)
  - [x] 1.2 reorder `tests/multitasker_bank_tests.fth` so `TASK CONSTANT BT1` comes first, then `TAPE`/`APP`/`BG`/`DRV`; remove `BT2`; run the same-bank control as `' BG2 BT1 ACTIVATE` after the cross-bank run has finished. Keep all six verdict names so the Makefile assertion list doesn't change. Update the probe's header comment.
  - [x] 1.3 Check that the probe still catches a fault: temporarily break the cross-bank re-page (or change one expected `TAPE` value), see the target FAIL, restore it.
  - [x] 1.4 Check that `BG`'s body sits below `$8000` (`' BG U.` < 32768) and print it in the probe as a witness, so the next squeeze fails with a clear reason and not a wrong `TAPE` value.
- [x] **Task 2 — Make `test-repl` run the multitasker family (AC2)**
  - [x] 2.1 Add the 12 targets to the `test-repl:` prerequisite line (`Makefile:2121`).
  - [x] 2.2 Time `make test-repl` before and after; record both.
- [x] **Task 3 — Version bump (AC6)**
  - [x] 3.1 `src/antforth.asm` banner → `AntForth v3.3.0 (C) ant.org 2026`. Rebuild, check the size is unchanged, and `strings build/antforth.com | grep 'AntForth v'`.
  - [x] 3.2 `Makefile` REPL test 80: all three `v3.2.1` strings → `v3.3.0`.
  - [x] 3.3 `README.md`: `## Version 3.3.0`; replace the 3.2.1 paragraph with a short 3.3.0 one (Epic 27: twelve words, one-operand `-4` checks, `+BANK` duplicate-page refusal + `$BF58` banked ceiling + `WORD` 128-char cap); add the release-history entry above 3.2.1; add `-ROT`/`<=`/`>=` to "Beyond the standard"; check that the §6.2 row matches the compliance doc.
  - [x] 3.4 `src/system.asm:577` comment `13/46` → `23/46` (or the recount from Task 4.1).
- [x] **Task 4 — Docs (AC7)**
  - [x] 4.1 Recount the compliance doc's §6.2 Implemented table rows; check the summary table (`:78`), the §6.2 paragraph (`:387`) and the heading (`:391`) agree.
  - [x] 4.2 `docs/WISHLIST.md`: add "Shipped in v3.x" (3.1.0 IO port words, `VALUE`/`TO`; 3.2.0 multitasker, semaphores/mutex/mailbox; 3.3.0 Epic-27 words) and remove those items from the wish sections.
  - [x] 4.3 `docs/phase6-multitasker.md`: add the task-room limit with the measured figure.
  - [x] 4.4 `docs/dev_journal.md` TCB-room entry: add the v3.3.0 figures and the AC1 outcome; it stays OPEN.
  - [x] 4.5 `make check-doc-sync` → 0 drift.
- [x] **Task 5 — Full sweep (AC3) and byte log (AC5)**
  - [x] 5.1 `make clean && make && wc -c build/antforth.com`; `make test`; `make test-repl`; every remaining `test-*` target from the `.PHONY` line plus `test-repl-cr-21-3`; `lint-banking-probes`. Record the counts.
  - [x] 5.2 Fill in the byte-ledger table with re-measured figures.
- [x] **Task 6 — Hardware smoke (AC4)**
  - [x] 6.1 Write the combined recipe into Dev Notes, using the draft below as a starting point.
  - [x] 6.2 Copy `build/antforth.com` and `disk/a/TRAFFIC.FTH` to the board (0x1A-terminated per `feedback_cpm_0x1a_eof_marker`), run the recipe, and record the transcript filename and the result.
- [x] **Task 7 — Memory and handoff (AC8, AC9)**
  - [x] 7.1 Write the Phase-7 memory and the `MEMORY.md` line; fix the stale line in `project_phase6_concurrency_direction.md`.
  - [x] 7.2 Commit on `main` (no co-author trailer). Post the tag and push commands, the release-workflow note and the hardware recipe in the closing message.

## Dev Notes

### What this story is

A close-out: no new words. Most of it is checking things and bumping version
strings. The one piece of real work is the regression in finding 1. Fix that
first, because every other check depends on a green sweep.

### Byte budget

| Item | Bytes | Why |
|---|---|---|
| Banner `v3.2.1` → `v3.3.0` | 0 | Same length (6 chars) inside a `DB` string |
| env_table comment | 0 | Comment only |
| Probe reorder (Task 1) | 0 | Test file, not kernel |
| Makefile prerequisites (Task 2) | 0 | Build script |
| **Total** | **0** | |

If the size moves, find out why before going on.

### The task-room squeeze

- `TASK` puts a TCB at `HERE` and raises `-8` if the TCB would end past `$8000`
  (TCBs must be in fixed RAM, which every bank can see).
- The room is whatever the kernel leaves between boot `HERE` and `$8000`, so
  every kernel byte comes out of it. Epic 27's +641 B took it from about
  1.8 KB to 1,117 B.
- AC1's fix (chosen by the project lead 2026-10-12) keeps the probe honest without spending kernel bytes, but
  it doesn't give the user more room. Two named TCBs fit with 23 B to spare.
  That is why AC7 documents the limit and the journal entry stays OPEN.
- The options already recorded in the journal (smaller per-task stacks, a TCB
  pool outside the dictionary, or documenting two tasks as the limit) are for
  the project lead, after the tag.
- The `PS_SIZE`/`RS_SIZE` constants (`src/constants.asm:88-89`) are shared with
  the operator's stacks. Shrinking per-task stacks would need separate task
  constants and a check of every `TCB_RS`/`TCB_SIZE` user. That isn't
  close-out work.

### Files to touch

- `tests/multitasker_bank_tests.fth` (Task 1)
- `Makefile`: the `test-repl:` prerequisite line and REPL test 80
- `src/antforth.asm:802` (banner), `src/system.asm:577` (comment)
- `README.md`, `docs/WISHLIST.md`, `docs/phase6-multitasker.md`,
  `docs/dev_journal.md`, and `docs/ans-forth-core-compliance.md` (only if the
  recount disagrees)
- memory files (Task 7)

Don't touch any other kernel source. The release workflow
(`.github/workflows/release.yml`) needs no edit; its comments say `v3.2.0` only
as an example.

### Testing standards

- REPL-piped, through the threading model (`feedback_testing_rules`,
  `feedback_repl_tests_preferred`).
- Verdicts are column-0 anchored via `tests/assert_verdicts.sh`. The REPL echoes
  piped source, so a verdict string that only appears in the echoed source must
  not count as a PASS.
- Lines stay ≤ 128 chars (`feedback_tib_size_inline_comments`).
- Banking probes run under `timeout $(PROBE_TIMEOUT)` with a FAIL branch for
  rc 124.
- If a banking probe halts after a change, check
  `feedback_banking_probe_straddle_halt` first. If a number looks wrong, check
  BASE first (`project_hex_base_leak_literal_truncation`).
- Blocking `WAIT`/`LOCK`/`FETCH` at the operator prompt hard-wedges the machine
  (`project_operator_wait_wedge`). The hardware recipe must only block inside
  tasks.

### Hardware recipe (draft; the dev pass finalises it)

Copy `build/antforth.com` and the 0x1A-terminated `disk/a/TRAFFIC.FTH`, cold
boot, `DECIMAL`:

1. The banner reads `AntForth v3.3.0`. Note the bytes-free figure.
2. `1 2 NIP .S` → `2`; `1 2 TUCK .S` → `2 1 2`; `1 2 3 -ROT .S` → `3 1 2`;
   then `CLEARSTACK` or drop to empty. Use whatever the 27.1 recipe used.
3. `VARIABLE V 42 V ! V ?` → `42`; `HEX V ? DECIMAL` → `2A`.
4. `1 2 <> . 0 0<> . 1 0> . $FFFF 1 U> . $8000 0 <= . 1 2 >= .` →
   `-1 0 -1 -1 -1 0`.
5. `: T 0 BEGIN 1+ DUP 5 = IF EXIT THEN AGAIN ; T .` → `5`.
6. `: C 0 SWAP 0 ?DO 1+ LOOP ; 0 C . 5 C .` → `0 5`.
7. Empty stack: `DUP`, `0=`, `1+` each → `error -4`; `DEPTH .` → `0`.
8. 27.1 replay, fresh session: `variable v 5 42 v ! v ?` then `.s` → expect
   `<1> 5` (the emulator's result). Record what the hardware shows.
9. `INCLUDE TRAFFIC.FTH`, `TIMER-ON`, `' RUN-LIGHTS LIGHTS ACTIVATE`; the prompt
   stays live (`1 2 + .` → `3`); `.TASKS` shows both AWAKE; `Ctrl-\` →
   `task 1: error -28`; `TIMER-OFF`. Check the activation line against the
   final `TRAFFIC.FTH` before running it.
10. 27.7 steps 1–7 as in the 27.7 story file's "S9 recipe", including step 6
    (`INCLUDE P193IRON.FTH`) and step 7 (`WORD` cap → `-18`, `B0 .` → `42`).
    Steps 2–4 need a fresh boot or `BANKS-CLEAR` between them, as written there.

### Previous stories — what carries over

- 27.6 moved every TCB carve to the top of its probe and of `TRAFFIC.FTH` for
  the same squeeze. The bank probe couldn't be moved that way because `BG` must
  sit below `$8000` too.
- 27.7's draft trace showed "hangs" can come from page aliasing rather than a
  FIND bug. `+BANK` now refuses duplicate pages, so the hardware recipe must use
  distinct pages.
- Every Epic-27 story found something outside its own scope while running its
  probes or the hardware smoke (the batnball tick source, the bank-lookup bug,
  the TCB squeeze). If the combined smoke turns up something new, record it and
  file it in the dev journal. Fix it here only if it blocks the tag, and say so.

### Git context

Last five commits are the six Epic-27 stories (27.1–27.4, 27.6, 27.7), one
commit each on `main`, with a `feat:`/`fix:` prefix and `(Story 27.N)` in the
subject. Follow that: `chore: v3.3.0 close-out (Story 27.5)` or similar.

### References

- `_bmad-output/planning-artifacts/epics-phase7-epic-27.md` — Story 27.5 ACs, NFR-P7-1/2/7
- `_bmad-output/implementation-artifacts/23-5-epic-23-close-out-ccd-4-regression-gate-v3-1-0-tag.md` — previous close-out (four version surfaces, test 80 trap)
- `_bmad-output/implementation-artifacts/27-6-one-operand-underflow-checks.md`, `27-7-cross-bank-lookup-hides-or-hangs-on-kernel-words.md` — byte figures, hardware recipes
- `docs/dev_journal.md:28` — TCB-room entry
- `src/constants.asm:88-89,106-123` — stack sizes and TCB layout
- `.github/workflows/release.yml:72-87` — banner/tag check

## Dev Agent Record

### Agent Model Used

claude-opus-5-5 (Claude Code, dev-story workflow), 2026-10-12

### Debug Log References

- Pre-edit baseline: `wc -c` 31,395 B (HEAD `50537ba`, matches draft). `make test-repl` 1147 PASS / 0 FAIL / 2 SKIP. v3.2.1 rebuilt in a worktree: 30,754 B. Multitasker family: 11 green, `test-repl-multitasker-bank` rc=2 (16 PASS / 10 FAIL lines), as drafted.
- Task room measured at a fresh prompt: boot `HERE` 31,651, `32768 HERE -` = 1,117. `TASK CONSTANT T1` → `HERE` 32,197; `T2` → 32,743 (25 B left); `T3` → `error -8`. A named TCB is **546 B**, not the 547 B the draft assumed, so the spare is 25 B, not 23.
- Fault injection on the reworked bank probe: (1) expected `TAPE` 12121 → 12122 in `_rr`: target FAILs (`FAIL: bank-task-advances` plus the missing-verdict line). (2) `600 ALLOT` after `VARIABLE TAPE` pushes `BG` past `$8000`: the cross-bank task wedges and the target times out. Before the fix, the timeout branch dropped the captured output, so the reason was lost. The timeout branch now prints any `^FAIL:` lines already captured, and it shows `FAIL: bank-bg-fixed` above the timeout line. Both temp probes deleted.
- `make test-repl` timing (two runs each, same machine): HEAD Makefile 5.41 s / 5.45 s; with the 12 prerequisites 5.93 s / 5.94 s (+0.5 s).

### Completion Notes List

- **AC1 — bank probe fixed, 0 kernel bytes.** `tests/multitasker_bank_tests.fth` carves `TASK CONSTANT BT1` first, then `TAPE`/`APP`/`BG`; `BT2` is gone; the same-bank control re-`ACTIVATE`s `BT1` with `BG2` after `BG` has exited. The six original verdicts are unchanged. A seventh, `bank-bg-fixed`, checks `HERE` after `BG` is ≤ 32768 and prints the value (32,266 on v3.3.0, so `BG` ends 502 B below `$8000`). The Makefile asserts it too. `make test-repl-multitasker-bank`: 7/7.
- **AC2 — the 12 targets are `test-repl` prerequisites.** `test-repl` now reports 1225 PASS / 0 FAIL (1147 + 78 lines from the 12 targets). Runtime 5.4 s → 5.9 s. The "Single-feature target; NOT folded into plain `test-repl`" comments on those 12 targets now say "Runs as a `test-repl` prerequisite"; the comment above `test-repl:` names them.
- **AC3 — full sweep on the final binary** (`make clean && make`, 31,395 B). Every target rc=0, 0 `^FAIL`: `test` (PASS: Output matches expected), `test-repl` 1225/0 (2 SKIP, the disk-full/dir-full hardware-only rows, as before), `-asm` 5, `-value-to` 7, `-in-out` 4, `-timer` 9, `-multitasker` 5, `-key` 5, `-delay` 6, `-tasks` 8, `-throw` 8, `-break` 8, `-bank` 7, `-demo` 4, `-semaphore` 6, `-mutex` 6, `-mailbox` 6, `-ud-env` 14, `-rstack-guard` 7, `-stack-words` 15, `-comparisons` 19, `-again` 12, `-qdo` 16, `-underflow` 55, `-bank-lookup` 18, `-banking` 57, `-banking-isolated` 6, `-19-3` 15, `-19-4` 2, `-19-5-1` 2, `-20-1` 7, `-20-2` 5, `-20-3` 5, `-21-1` 5, `-21-2` 5, `-21-3` 6, `-22-1` 1, `-22-2` 4, `-22-3` 4, `-dot-banks` 7, `lint-banking-probes` 1, `-banking-23-6` 8, `-23-7` 4, `-23-9` 9, `test-straddle-regression` 3, `test-file-sanity` 1, `test-repl-cr-21-3` 4. `check-doc-sync`: 15 advisories / **0 drift**. (Counts are `^PASS` lines in each target's output.) `env-core-x` in `test-repl-ud-env` still passes, so `ENVIRONMENT? CORE-EXT` still answers false.
- **AC4 — hardware smoke: PASS, 2026-10-12, `beastty-20261012-093931.txt`** (v3.3.0 sessions start at log line 250; lines 1–249 are earlier v3.2.1 sessions). Run by the project lead; log checked line by line:
  - Banner `AntForth v3.3.0`, 22,621 bytes free, 12 banks (same as the emulator).
  - Steps 2–6: every value matches (`<1> 2`, `<3> 2 1 2`, `<3> 3 1 2`, `42`, `2A`, `-1 0 -1 -1 -1 0`, `5`, `0 5`). Lines 256–261 are typing errors (`DROP.`), not faults.
  - Step 7: `DROP`, `DUP`, `0=`, `1+` on an empty stack each give `error -4`; `DEPTH .` → `0`.
  - Step 8: `32768 HERE - .` → 1041, the same as the emulator after the same lines.
  - Step 9: `TRAFFIC.FTH` runs as a background task, `1 2 + .` → `3`, `.TASKS` shows tasks 0 and 1 AWAKE, `Ctrl-\` → `task 1: error -28`, `TIMER-OFF`.
  - Step 10 (27.1 replay): `variable v 5 42 v ! v ?` → `42`, `.s` → `<1> 5`, the same as the emulator. The `5` is correct (nothing consumes it), so the 27.1 "open anomaly" (hardware `<0>`) does not reproduce and is closed. One earlier line in that session was mistyped as `variable v 5 42 ! v ?`, which stored 5 at address 42 in page zero; nothing visibly went wrong.
  - Step 11, 27.7 steps 1–6: FREE 16216 per bank; `dup?` + `error -2`, `BANKS .` → `1`; step 3: `-8`, `48984`, `-13`, `3` with no hang, `B0 .` → `42`; step 4 `BANK@ .` → `0`; step 5 `CR`, no error; step 6 `P193IRON.FTH` prints both sentinels.
  - Step 11, 27.7 step 7 (`WORD` cap): first tried right after `P193IRON.FTH`, which ends with `BANKS-CLEAR`, so every `BANK!` gave `bank?` / `-2`, as expected with zero banks. Rerun after a fresh boot and the page list: `-18`. That rerun didn't have step 3's setup (bank 6 at `$BF58`, `B0` straddling `$C000`), so the "`B0` survives" half of step 7 wasn't covered on hardware; `B0` was redefined by hand and printed `42`, which proves nothing. The `-18` throw itself is confirmed. The emulator covers `B0` surviving (case H in `test-repl-bank-lookup`).
- **AC5 — bytes.** Final 31,395 B (`make clean && make && wc -c`). v3.2.1 artifact 30,754 B. Delta **+641 B**. This story: **0 B** (banner swap is same-length; everything else is tests/docs/Makefile). Every Epic-27 commit rebuilt in a worktree:

  | Story | Commit | Before → after (B) | Delta |
  |---|---|---|---|
  | 27.1 `NIP` `TUCK` `-ROT` `?` | `2868649` | 30,754 → 30,830 | +76 |
  | 27.2 comparisons | `35c096d` | 30,830 → 31,009 | +179 |
  | 27.3 `AGAIN` | `3b50b0c` | 31,009 → 31,017 | +8 |
  | 27.4 `?DO` | `09b3c00` | 31,017 → 31,077 | +60 |
  | 27.6 underflow checks | `bfb9a48` | 31,077 → 31,348 | +271 |
  | 27.7 `+BANK` / `$BF58` / `WORD` cap | `50537ba` | 31,348 → 31,395 | +47 |
  | 27.5 close-out | — | 31,395 → 31,395 | 0 |
  | **Epic 27** | | **30,754 → 31,395** | **+641** |

  141 B over the ≤ 500 B envelope (NFR-P7-2). Reason: 27.6 had ≈ 55 unchecked sites plus the assembler instead of ≈ 20 (overage accepted 2026-10-11), and 27.7's +47 B fixed a bug found during the epic. Without those two the epic is 323 B against an estimate of ≈ 340 B.
- **AC6 — version surface.** Banner `AntForth v3.3.0 (C) ant.org 2026` (`strings` confirms; size unchanged). REPL test 80 asserts `v3.3.0` (passes). README: `## Version 3.3.0`, a 3.3.0 paragraph replacing the 3.2.1 one, a 3.3.0 release-history entry above 3.2.1, and `-ROT`, `<=` `>=` added to "Beyond the standard". `src/system.asm` env_table comment `13/46` → `23/46`.
- **AC7 — docs.** Compliance doc §6.2 Implemented table: 23 rows counted; summary table, §6.2 paragraph and heading all say 23, as do the README row and the env_table comment, so the compliance doc needed no edit. `docs/WISHLIST.md`: Multitasker, Semaphores and Z80 IO primitives sections removed; new "Shipped in v3.x" section lists them plus `VALUE`/`TO` and the twelve Epic-27 words. `docs/phase6-multitasker.md`: new "How many tasks fit" section (two named tasks, 25 B spare on v3.3.0, carve first, the cross-bank case, how to check with `32768 HERE -`). `docs/dev_journal.md` TCB-room entry: v3.3.0 figures and the AC1 fix added; still OPEN.
- **Draft wording corrected:** the README draft text tied the `$BF58` ceiling to the lookup hangs. Per 27.7's commit the hangs came from duplicate pages; the ceiling stops `WORD`/`PAD` writing into fixed RAM. The README says that.
- **AC8 — memory.** `project_phase7_epic27_v330.md` written with its `MEMORY.md` line; the stale "No Epic 27 defined — roadmap ends at 26" sentence in `project_phase6_concurrency_direction.md` (and its index line) replaced with a pointer.
- **AC9 — tag left to the project lead.** Commit on `main`, no co-author trailer. Tag after the hardware smoke passes.

#### Combined hardware recipe (v3.3.0, AC4)

Copy `build/antforth.com` (31,395 B), `disk/a/TRAFFIC.FTH` and `disk/a/P193IRON.FTH` to the board (both `.FTH` files already end in `0x1A`). Cold boot. `DECIMAL`.

1. Banner reads `AntForth v3.3.0 (C) ant.org 2026`. Note the bytes-free figure (emulator: 22,621, 12 banks).
2. `1 2 NIP .S` → `<1> 2`, `DROP`. `1 2 TUCK .S` → `<3> 2 1 2`, `DROP DROP DROP`. `1 2 3 -ROT .S` → `<3> 3 1 2`, `DROP DROP DROP`.
3. `VARIABLE V 42 V ! V ?` → `42`. `HEX V ? DECIMAL` → `2A`.
4. `1 2 <> . 0 0<> . 1 0> . $FFFF 1 U> . $8000 0 <= . 1 2 >= .` → `-1 0 -1 -1 -1 0`.
5. `: T 0 BEGIN 1+ DUP 5 = IF EXIT THEN AGAIN ; T .` → `5`.
6. `: C 0 SWAP 0 ?DO 1+ LOOP ; 0 C . 5 C .` → `0 5`.
7. Empty stack: `DUP`, `0=`, `1+`, each on its own line → `error -4: stack underflow`. `DEPTH .` → `0`.
8. Task room: `32768 HERE - .` → expect 1117 minus whatever steps 3–6 compiled. Not a pass/fail line; just record it.
9. **Cold boot again** (TRAFFIC.FTH carves its TCB first and needs the room). `DECIMAL`. `INCLUDE TRAFFIC.FTH`, `TIMER-ON`, `' RUN-LIGHTS LIGHTS ACTIVATE`. Lights cycle; prompt stays live: `1 2 + .` → `3`. `.TASKS` → `0 * AWAKE` and `1   AWAKE`. `Ctrl-\` → `task 1: error -28`. `TIMER-OFF`.
10. **Cold boot again.** 27.1 replay as the first line of a fresh session: `variable v 5 42 v ! v ?` → `42`, then `.s` → emulator shows `<1> 5`. Record what the hardware shows.
11. **Cold boot again.** 27.7 steps 1–7, as written in the 27.7 story's "S9 recipe" (fresh boot or `BANKS-CLEAR` between 2–4 as stated there):
    1. `.BANKS` → banks 1..N show FREE 16216.
    2. `BANKS-CLEAR $22 +BANK $22 +BANK` → `dup?` and `error -2`; `BANKS .` → `1`.
    3. `0 BANK! BANKS-CLEAR $22 +BANK $35 +BANK $36 +BANK $37 +BANK $38 +BANK $39 +BANK $3A +BANK`, `0 BANK!  $C000 HERE - 3 - ALLOT`, `42 VALUE B0`, `6 BANK!  $C000 HERE - 2 - ALLOT` → `error -8`; `$BF58 HERE - ALLOT`, `HERE U.` → `48984`; `ABCDEFGHIJKLMNOPQRSTUVWXYZ01234` → `error -13`; `1 2 + . CR` → `3`, no hang; `0 BANK! B0 .` → `42`.
    4. (fresh boot + step-3 page setup) `2 BANK! : _by 1 ;  3 BANK!  0 BANK!  BANK@ .` → `0`.
    5. `1 BANK! : _qk 1 ;  2 BANK!  CR` → newline, no error; `0 BANK!`.
    6. `INCLUDE P193IRON.FTH` → its usual sentinel. (Not run in 27.7's hardware session.)
    7. After step 3's setup: `0 BANK!  CREATE _LT 220 ALLOT  _LT 220 65 FILL`, `6 BANK!  _LT 220 ' EVALUATE CATCH . 2DROP` → `-18`; `0 BANK! B0 .` → `42`. (The `WORD` cap landed after 27.7's hardware run.)

Pass = every expected value above, no hang, no unexpected error. Save the terminal log as `beastty-<date>-<time>.txt` and record its name here.

### File List

- `tests/multitasker_bank_tests.fth` — one TCB carved first, `BT2` removed, `BT1` re-`ACTIVATE`d for the same-bank control, `bank-bg-fixed` witness
- `Makefile` — 12 targets added to `test-repl:`; `bank-bg-fixed` verdict; bank-probe timeout prints captured `^FAIL:` lines; REPL test 80 → `v3.3.0`; comments on the 12 targets and above `test-repl:`
- `src/antforth.asm` — banner `v3.3.0`
- `src/system.asm` — env_table comment `23/46`
- `README.md` — version heading, 3.3.0 paragraph, release history, "Beyond the standard"
- `docs/WISHLIST.md` — "Shipped in v3.x" section; shipped items removed
- `docs/phase6-multitasker.md` — "How many tasks fit"
- `docs/dev_journal.md` — TCB-room entry updated (still OPEN)
- `_bmad-output/implementation-artifacts/27-5-epic-27-close-out-and-v3-3-0.md` — this file
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 27.5 status
- Memory (outside the repo): `project_phase7_epic27_v330.md` (new), `project_phase6_concurrency_direction.md`, `MEMORY.md`

### Change Log

- 2026-10-12 — Dev pass: bank probe fixed (0 kernel bytes), multitasker family made `test-repl` prerequisites, version surface bumped to v3.3.0, docs and memory updated, full sweep green on 31,395 B (+641 B over v3.2.1). Hardware smoke (Task 6.2) pending.
- 2026-10-12 — Hardware smoke PASS (`beastty-20261012-093931.txt`); 27.1 stray-`5` anomaly closed (hardware matches the emulator). Status → review.
