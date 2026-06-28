# Story 23.5: Epic 23 close-out — CCD-4 regression gate + v3.1.0 tag

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-28 by create-story workflow (context-engine pass).
     Story 23.5 is the Epic-23 / Phase-5 CLOSE-OUT — a zero-feature
     verification + version-surface + tag story. Stories 23.1–23.4 (the four
     Phase-5 features) are all DONE. This story ties them into a tagged
     antforth v3.1.0 release with the full regression baseline green.

     THREE load-bearing facts pinned at DRAFT TIME against source-of-truth
     (B.3 / B.4 / PD-2 — do NOT re-derive from prior prose):

       (1) THIS IS A MINOR BUMP: v3.0.7 → v3.1.0 (not a point release).
           Phase 4 closed at v3.0.7 (banner, README, memory all read 3.0.7).
           Phase 5 ships as v3.1.0 (epics-phase5-epic-23.md:27,133). Unlike
           Phase 4, there is NO interlude that shifts the tag mapping — Epic 23
           is a single epic, maps cleanly to a single minor release. The slug
           and the epic AC agree on v3.1.0 (no "stale slug" reconciliation
           needed, contrast Story 22.4's 3-x-6→3.0.7 shift).

       (2) FOUR version surfaces, not three. The epic AC3 names three (banner,
           README, memory). There is a FOURTH: `Makefile:2144` REPL test 80
           asserts the banner string `AntForth v3.0.7`. This is the exact trap
           that aborted the `test-repl` suite in Story 22.4 (the un-bumped
           assertion failed at PASS 80 and halted the run). ALL FOUR must bump
           in lock-step (Epic-21-retro action A3 surface). Banner swap is
           same-length (`v3.0.7`→`v3.1.0`, both 6 chars) → 0 B kernel delta.

       (3) BINARY LEDGER (orientation — RE-MEASURE fresh per B.3, do not inherit):
           v3.0.7 / Phase-4 close (tag `47690da`) = 28,499 B
             23.1 (asm IN,/OUT, order)   +0   B → 28,499 B  (byte-neutral)
             23.2 (VALUE / TO)           +310 B → 28,809 B
             23.3 (IN / OUT port words)  +43  B → 28,859 B  (committed baseline measured 28,816)
             23.4 (UD. + env rows)       +112 B → 28,947 B  (current HEAD `5b4baba`)
           Epic-23 cumulative ≈ +448 B (28,499 → 28,947) vs the epic's ≈300 B
           rough aggregate (epics-phase5-epic-23.md:147) ≈ 1.5×. The per-story
           sum (0+310+43+112 = 465) and the start→HEAD delta (448) DISAGREE by
           ~17 B — that gap is exactly the figure-drift trap (23.2 reported
           28,809 but 23.3 re-measured the committed baseline at 28,816). The
           AUTHORITATIVE close-out figure is `HEAD` minus a FRESH rebuild of the
           v3.0.7 tag artifact (`47690da`), both via `make clean && make &&
           wc -c build/antforth.com`. -->

## Story

As Ant (project lead applying the Phase-5 close-out tag),
I want the full regression baseline green across all three test surfaces
(iz-cpm flat + banking-capable emulator + real MicroBeast), the four
user-visible version surfaces advanced v3.0.7 → v3.1.0 in lock-step, the
Epic-23 byte budget recorded against the ≈300 B estimate, the docs reconciled,
and a Phase-5 successor memory written,
so that antforth **v3.1.0** ships cleanly — four standing ANS / ergonomics gaps
and one assembler conformance bug closed, zero regressions — the first minor
release since the 3.0 banked-memory line.

## Acceptance Criteria

**Given** Stories 23.1 + 23.2 + 23.3 + 23.4 **and Story 23.6** have all shipped
(`done` in sprint-status — Story 23.6 ships under v3.1.0 per project-lead
decision 2026-06-28; see "Epic-23 completeness gate"), AND the Phase-4 close-out
baseline (v3.0.7, 28,499 B, 975 PASS / 0 FAIL on silicon) is the starting point,
**When** Story 23.5 is dev-passed,

1. **AC1 — full regression sweep green, zero regressions (release blocker).**
   The Phase-4 baseline **plus** the four new Phase-5 probes pass across all
   three surfaces. Counts recorded in Dev Notes (re-run fresh; do not inherit):
   - **Surface 1 — iz-cpm flat baseline:** `make test-repl` ≥ **975 PASS / 0
     FAIL** (FR-P4-41 floor; current actual 975/0 with 2 SKIP). `test-repl` now
     chains the four Phase-5 probe targets as prerequisites — confirm each:
     `test-repl-asm` (23.1), `test-repl-value-to` (23.2), `test-repl-in-out`
     (23.3), `test-repl-ud-env` (23.4) — all 0 FAIL.
   - **Surface 2 — iz-cpm-banking:** `make test-repl-banking` full probe corpus
     PASS (current actual 62/0), PLUS the full isolated-fixture battery +
     `test-repl-cr-21-3` + `test-straddle-regression` (3/3) + **Story 23.6's
     window-top overflow-guard probe** (23.6 ships in v3.1.0 — its target must be
     green here). **Enumerate the isolated/CR/straddle targets fresh from the
     Makefile `.PHONY` line at dev-pass start — do NOT inherit a stale list**
     (22.4 lesson; 23.6's target will be new).
   - **Surface 3 — real MicroBeast:** ONE consolidated hardware-typed smoke
     batch covering the Phase-5 user surface — `VALUE`/`TO` (incl. one banked
     round), `IN`/`OUT` port words, `UD.`, the six `ENVIRONMENT?` rows, and a
     spot-check of the assembler `IN,`/`OUT,` new operand order — PASSes on
     silicon per S9 / NFR-P4-11. The per-story HW UATs are already discharged
     (23.1–23.4 each smoke-passed); AC1 Surface-3 is the consolidated final
     batch on the v3.1.0 binary. Transcript filename + recipe posted **in the
     closing chat message** (S9 / STRONG — `feedback_post_hw_smoke_steps_at_review`).
   A single regression on any surface **blocks the v3.1.0 tag**.

2. **AC2 — CCD-4 byte-budget row logged.** Dev Notes record the HEAD byte delta
   vs v3.0.7 (28,499 B), **each figure re-measured from a fresh `make clean &&
   make && wc -c build/antforth.com`** (B.3 / Lesson 13.5-F — the orientation
   numbers in this story are explicitly NOT authoritative). The Epic-23
   cumulative (orientation ≈ +448 B) is justified against the epic's ≈300 B
   rough aggregate (epics-phase5-epic-23.md:147), itemised per-story
   (23.1 +0 / 23.2 +310 / 23.3 +43 / 23.4 +112), and reconciled against the
   ~17 B per-story-sum-vs-start→HEAD drift (finding (3)). The dominant driver is
   23.2's +310 B (`VALUE`/`TO` + the banking-gate-halt probe restructure) — a
   genuine feature delta, not waste; frame per `feedback_no_preexisting_discharge`
   as a deliberate, itemised, project-lead-visible cost, not a defect-accept.
   Report against NFR-P4-5 (~6 KB @12 banks) — well inside (Phase-4+Phase-5
   cumulative ≈ +3,952 B vs Phase-3-close 24,995 B).

3. **AC3 — S11 user-visible version-surface audit (FOUR surfaces, lock-step).**
   All four surfaces advanced **v3.0.7 → v3.1.0**:
   - `src/antforth.asm` banner `str_banner1` (`:785`) reads
     `AntForth v3.1.0 (C) ant.org 2026` — **same-length** swap (`v3.0.7`→`v3.1.0`,
     both 6 chars) → expected kernel binary delta **0 B** (v3.0.4/.5/.6/.7
     same-length precedent).
   - `README.md` version reference (`## Version 3.0.7` at `:14`; the table-intro
     `V3.0.7 supports …` at `:59`) → `3.1.0`, with a one-paragraph "what 3.1.0 /
     Phase-5 delivers" entry following the existing per-release prose pattern.
     **Also refresh the stale "Coming up in the next version" section** (`:119`):
     it still lists "Bank-aware compilation … antforth 3.1+" and "Per-bank
     dictionary search-order traversal and `WORDS`" as upcoming — **both shipped
     in Phase 4** (Epics 19 & 20). Replace with the genuine forward slate (the
     Phase-5 deferrals: cooperative multitasker, semaphores, full ANS locals —
     epics-phase5-epic-23.md:302-317).
   - The **fourth surface** (finding (2)): `Makefile:2144-2147` REPL test 80
     banner assertion `AntForth v3.0.7` → `v3.1.0`. Verify by re-running the
     FULL `test-repl` on the final binary (the un-bumped assertion aborts the
     suite — Story 22.4 Step-9 lesson).
   - The new Phase-5 memory's (AC5) `description:` field reads `v3.1.0 … Phase 5
     CLOSED`.

4. **AC4 — `make check-doc-sync` clean-pass (B.5) + doc reconciliation.**
   `make check-doc-sync` reports **no NEW drift** across the surfaces the tool
   covers, AFTER the AC3 v3.1.0 bump lands on all of them (pre-existing
   advisories — ~31 at 22.4 — are unchanged, not introduced). Docs reflect
   Phase-5 deliverables + deferrals:
   - `docs/ans-forth-core-compliance.md` — already gained the 23.2/23.4 rows
     (`VALUE`/`TO`/`UD.`/env-query); verify present + the §3.2.6 enumerations
     read 20-entry (no further edit expected — confirm, don't re-edit).
   - `docs/dev_journal.md` — the Phase-5 gap lines (`UD.` + env queries) already
     annotated RESOLVED by 23.4 (journal:5-8); confirm no open Phase-5 gaps
     remain unannotated.
   - `docs/WISHLIST.md` — confirm the three Phase-5 deferrals (multitasker,
     semaphores, locals) remain as forward candidates; `VALUE`/`TO` (the locals
     ergonomics partial) noted as delivered.
   - Verdict-table walk per Story-13.5.6 precedent (AC included in Dev Notes —
     one PASS row per Phase-5 story 23.1–23.5 with one-line evidence).

5. **AC5 — Phase-5 successor memory written.** A new project memory (successor
   to `project_phase4_scope.md`) records: Phase 5 CLOSED, antforth v3.1.0; the
   four feature deliverables (23.1 asm operand-order fix, 23.2 `VALUE`/`TO`,
   23.3 `IN`/`OUT` port words, 23.4 `UD.` + honest `ENVIRONMENT?` rows); the
   Epic-23 byte delta (≈ +448 B vs ≈300 B estimate) and cumulative vs
   Phase-3-close; the env-query-honesty decision (three sets answer `false`,
   not blanket-true — Ant 2026-06-28); and the three deferral decisions
   (multitasker / semaphores / full ANS locals = platform shifts, not
   increments). Add the one-line `MEMORY.md` index hook; link `[[…]]` to
   `project_phase4_scope`. (Do NOT duplicate code structure or git history —
   record only the non-obvious close-state and decisions.)

6. **AC6 — `git tag v3.1.0` gated on explicit project-lead authorization.**
   The dev prepares the close-out commit on branch `banked_memory` and surfaces
   the exact `git tag v3.1.0 <commit>` + push command **in the closing chat
   message**; Ant applies and pushes. Tags are NEVER auto-applied
   (`project_phase4_scope.md` precedent; mirror the v3.0.5/.6/.7 handoffs). No
   `Co-Authored-By: Claude` trailer on the close-out commit
   (`feedback_no_claude_coauthor` — STRONG). **Phase 5 ENDS.**

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: fresh `make clean && make && wc -c
      build/antforth.com` → **29,062 B** (HEAD `a27c6b5`, includes Story 23.6).
      Did NOT inherit 23.4's 28,947 B.
- [x] Capture the v3.0.7-tag artifact size for the authoritative Epic-23 delta:
      fresh rebuild of tag `47690da` in an isolated worktree → **28,499 B**
      (matches orientation exactly). This is the AC2 denominator. (Note: `v3.0.7`
      is an annotated tag; its object SHA is `f75ad4e`, the commit it points to is
      `47690da` — no discrepancy.)
- [x] Capture baseline gate counts pre-edit: `make test-repl` **1005/0/6 SKIP**;
      `make test-repl-banking` **62/0**; isolated battery **61/0**;
      `test-repl-banking-23-6` **7/0**; `cr-21-3` **4/0**; straddle **3/3**;
      `check-doc-sync` 31 advisories / **0 drift**. All green pre-edit.

### Story tasks

- [x] **Task 1 — Version-surface bump v3.0.7 → v3.1.0, all FOUR surfaces (AC3)**
  - [x] `src/antforth.asm:785` `str_banner1`: `AntForth v3.0.7 (C) ant.org 2026`
        → `… v3.1.0 …` (same-length; **0 B** kernel delta confirmed post-rebuild;
        binary banner reads `AntForth v3.1.0`).
  - [x] `Makefile:2184–2188` REPL test 80 banner assertion `AntForth v3.0.7` →
        `v3.1.0` (the fourth surface — finding (2); line nums drifted from the
        story's `:2144`).
  - [x] `README.md:14` `## Version 3.0.7` → `3.1.0`; table-intro `V3.0.7
        supports` → `V3.1.0`; added a 3.1.0 per-release prose paragraph (Phase-5:
        `VALUE`/`TO`, `IN`/`OUT`, `UD.`, env-query honesty, assembler operand
        fix) following the existing pattern.
  - [x] `README.md` "Coming up in the next version": DELETED the two
        already-shipped lines (bank-aware compilation 3.1+; per-bank search-order
        `WORDS` — both done in Phase 4) and replaced with the real forward slate
        (multitasker, semaphores, full ANS `{: :}` locals — the Phase-5 deferrals).
  - [x] Re-`wc -c` after the bump → **29,062 B = 0 B** vs Task-0 baseline.

- [x] **Task 2 — Three-surface regression sweep (AC1) + doc-sync (AC4)**
  - [x] Surface 1: `make test-repl` → **1005/0** (≥975). Four Phase-5 probe
        prerequisites all 0 FAIL (`test-repl-asm` 5/0, `-value-to` 7/0, `-in-out`
        4/0, `-ud-env` 14/0). Re-run on the FINAL (post-bump) binary — **test-80
        now asserts `AntForth v3.1.0` and PASSES** (22.4 Step-9 lesson).
  - [x] Surface 2: `make test-repl-banking` **62/0** + isolated battery (12
        fixtures enumerated fresh from `.PHONY`) **61/0** + `test-repl-cr-21-3`
        **4/0** + `test-straddle-regression` **3/3** + **`test-repl-banking-23-6`
        7/0** (Story 23.6 gate). `make test-file-sanity` → **1/0**.
  - [x] `make check-doc-sync` → **31 advisories / 0 drift** (= pre-edit; no NEW
        drift). Run AFTER the v3.1.0 bump landed on all surfaces.
  - [x] Surface 3: consolidated HW smoke batch on real CP/M 2.2 / MicroBeast —
        **PASS on silicon, v3.1.0 binary** (transcript `beastty-20260628-161341.bin`).
        Banner `AntForth v3.1.0`, **24954 bytes free** (= 25517 v3.0.7 − 563 B,
        independently corroborates the AC2 +563 B ledger). `VALUE`/`TO` → `42 99`;
        banked `VALUE` round (bank 1) → `7 7`; `UD.` → `4294967295`;
        `ENVIRONMENT?` `DOUBLE`/`SEARCH-ORDER-EXT` → `-1 0 -1 0` (present=false),
        `EXCEPTION` → `-1 -1` (present=true). Per-story HW UATs (23.1–23.4 incl.
        `IN`/`OUT` + asm operand order) already discharged.

- [x] **Task 3 — Byte-budget reconciliation (AC2)**
  - [x] Epic-23 cumulative = fresh HEAD (29,062) − fresh v3.0.7-artifact (28,499)
        = **+563 B**. Itemised per story from boundary-commit rebuilds (23.1 +0 /
        23.2 +317 / 23.3 +19 / 23.4 +112 / 23.6 +115); per-step sum = 563 =
        start→HEAD delta EXACTLY (no drift when measured from one toolchain — the
        orientation ~448 B was pre-23.6).
  - [x] Recorded vs the epic's ≈300 B estimate (~1.9×) and vs NFR-P4-5 (~6 KB @12
        banks; well inside — Phase-4+5 cumulative ≈ +4,067 B vs 24,995 B).
        Aggregated accept-with-rationale (dominant driver 23.2 +317 B; no fresh
        SCP — mirrors 22.4). See Completion Notes ledger.
  - [x] Verdict-table walk: one PASS row per story 23.1–23.5 (+23.6), built from
        `sprint-status.yaml` `done` keys + git + gate evidence. See Completion Notes.

- [x] **Task 4 — Phase-5 successor memory (AC5)**
  - [x] Wrote `project_phase5_scope.md` (frontmatter `type: project`,
        `name: antforth-3-1-0-phase-5-scope`): Phase 5 CLOSED / v3.1.0; five
        deliverables; +563 B ledger; env-query-honesty decision; three deferrals.
        Links `[[antforth-3-0-2-phase-4-scope]]`.
  - [x] Added the one-line `MEMORY.md` index hook.

- [x] **Task 5 — Sprint-status + close-out commit + tag handoff (AC6)**
  - [x] **PREREQUISITE — Story 23.6 is `done`** in sprint-status (line 264) and
        its probe target `test-repl-banking-23-6` is green (7/0) in the AC1
        Surface-2 sweep. Completeness gate SATISFIED — close-out proceeds. (FR-map
        discrepancy noted: epic doc lists only 23.1–23.5; 23.6 ships in v3.1.0 per
        the 2026-06-28 project-lead decision.)
  - [x] `sprint-status.yaml`: `23-5-…` `ready-for-dev` → `in-progress` (dev-pass
        start) → `review` (Step 9). The `→ done` flip + `epic-23` → `done` +
        `epic-23-retrospective` are the post-CR project-lead-gated close steps.
  - [~] Close-out commit + tag: working tree staged on `banked_memory`; exact
        `git tag v3.1.0 <commit>` + push command surfaced in the closing chat.
        NOT self-applied/self-pushed. No Claude co-author trailer.

## Dev Notes

### Story character — close-out / verification, not a feature

The only **kernel source** edit is the same-length banner bump (`v3.0.7`→`v3.1.0`,
expected 0 B). Everything else is the Makefile-assertion bump, README prose, the
three-surface sweep, the byte reconciliation, the verdict walk, and the new
memory. Mirror the house style of the prior close-out stories — **22.4**
(Phase-4 close, 0 B kernel, four-surface version bump + verdict walk + sweep) is
the direct precedent; **20.3** / **21.3** are the lighter epic-close analogues.
Do NOT introduce any new word, mechanism, or banking change here.

### Epic-23 completeness gate (RESOLVED — 23.6 ships in v3.1.0)

`sprint-status.yaml` shows **two** backlog rows under Epic 23 at this story's
creation: `23-5-…` (this story) and
`23-6-banked-dictionary-window-top-overflow-guard`. The epic doc
(epics-phase5-epic-23.md) defines only 23.1–23.5 — Story 23.6 was added to
sprint-status AFTER the epic doc was authored (its story FILE already exists in
implementation-artifacts but it is not in the epic's FR map).

**Project-lead decision (2026-06-28): Story 23.6 ships in v3.1.0.** Therefore:
- Story 23.6 must reach `done` **BEFORE** this close-out applies the v3.1.0 tag.
- This story's AC1 Surface-2 sweep **includes 23.6's probe target** (green
  required).
- `epic-23` closes (→ `done`) only after **both** 23.5 and 23.6 are `done`.
- If, at dev-pass, 23.6 is still open, **HALT the close-out** — the tag cannot
  apply over an open epic story (AC1 "zero regressions" presumes the tagged set
  is fully green).

The epic FR map should also be reconciled to record 23.6 as a v3.1.0
deliverable (it predates 23.6's addition) — note the discrepancy in the dev-pass
even though the binding source is this decision, not the stale epic prose.

### Version mapping (validated source-of-truth — PD-2)

| Phase | Epic | Tag | Note |
|---|---|---|---|
| 4 (final) | 22 | v3.0.7 | applied `47690da` — Phase-4 close |
| **5** | **23** | **v3.1.0** | **THIS STORY — first minor bump since 3.0** |

No interlude shift this time (contrast Phase 4's 19.5 → v3.0.4 shift that moved
the whole downstream mapping). Epic 23 = one epic → one minor release. The slug
(`…-v3-1-0-tag`) and the epic AC both say v3.1.0 — they agree; no reconciliation
prose needed.

### Binary-size ledger (orientation — RE-MEASURE per B.3, do not inherit)

| Point | Size | Per-step | Note |
|---|---|---|---|
| v3.0.7 / Phase-4 close (`47690da`) | 28,499 B | — | AC2 denominator (rebuild fresh) |
| Story 23.1 (asm IN,/OUT, order) | 28,499 B | +0 B | byte-neutral restructure |
| Story 23.2 (VALUE / TO) | 28,809 B | +310 B | dominant driver; banking-gate probe restructure |
| Story 23.3 (IN / OUT port words) | 28,859 B | +43 B | committed baseline re-measured 28,816 |
| Story 23.4 (UD. + 6 env rows) | 28,947 B | +112 B | current HEAD `5b4baba` |
| **Epic-23 cumulative** | — | **≈ +448 B** | vs ≈300 B epic estimate (~1.5×) |
| **Phase-4 + Phase-5 cumulative** | — | **≈ +3,952 B** | vs Phase-3-close 24,995 B; well inside NFR-P4-5 ~6 KB @12 banks |

The per-story sum (0+310+43+112 = 465) and the start→HEAD delta (≈448) disagree
by ~17 B — figure-drift between per-story measurements (23.2's close reported
28,809; 23.3 re-measured the committed baseline at 28,816). The authoritative
close-out number is `HEAD − fresh-v3.0.7-rebuild`, both via `make clean && make
&& wc -c`. Do NOT just sum the per-story Dev-Notes figures.

### Four version surfaces (S11 / NFR-P4-38 — the 22.4 lesson)

The epic AC3 names three (banner, README, memory). There are **four**:
1. `src/antforth.asm:785` `str_banner1` — kernel banner (same-length, 0 B).
2. `README.md:14` `## Version` + `:59` table-intro + `:119` "Coming up" refresh.
3. The new Phase-5 memory `description:` field (+ `MEMORY.md` hook).
4. **`Makefile:2144` REPL test 80 banner assertion** — easy to miss; the
   un-bumped assertion FAILS `test-repl` and aborts the suite (Story 22.4 caught
   this only by re-running on the final binary at Step 9). Bump it, then re-run
   the FULL `test-repl` on the post-bump binary.

`make check-doc-sync` covers banner/README/memory drift; run it AFTER all four
bump in lock-step.

### README "Coming up" is stale (refresh, don't just bump the number)

`README.md:119-124` still advertises as future work two features that Phase 4
already delivered: "Bank-aware compilation … (antforth 3.1+)" (Epic 19) and
"Per-bank dictionary search-order traversal and `WORDS`" (Epic 20). Leaving them
would ship a v3.1.0 README promising features already in the binary. Replace the
section with the genuine forward slate — the three Phase-5 deferrals
(cooperative multitasker, semaphores, full ANS `{: :}` locals;
epics-phase5-epic-23.md:302-317) — keeping the "Bluesky wishlist" section as-is.

### Three-test-surface convention (Story 16.3 — carried forward)

- `make test-repl` — iz-cpm flat baseline (general regression; 975/0). Now
  chains the four Phase-5 probes (`test-repl-asm`/`-value-to`/`-in-out`/`-ud-env`).
- `make test-repl-banking` — iz-cpm-banking (banking probes load-bearing; 62/0 +
  isolated battery + cr-21-3 + straddle 3/3).
- Real MicroBeast — S9 / NFR-P4-11 hardware smoke (the third surface).

Enumerate every isolated/CR/straddle target from the Makefile `.PHONY` at sweep
time (`feedback_phase4_probe_bank_switch_limitation` — behavioural per-bank
probes live in isolated fixtures). Do not inherit a target list.

### Hardware-smoke discipline (STRONG)

Post the consolidated HW-smoke recipe + transcript filename **in the closing
chat message**, not only in Dev Notes (`feedback_post_hw_smoke_steps_at_review`
— Ant has asked twice). 0x1A-terminate any `.FTH` SLIDE-transferred to silicon
(`feedback_cpm_0x1a_eof_marker`); REPL probe lines ≤ TIB_SIZE 128
(`feedback_tib_size_inline_comments`). Per-story HW UATs (23.1–23.4) are already
discharged; AC1 Surface-3 is the consolidated final batch on the v3.1.0 binary.

### Tag application is project-lead-gated

Per the v3.0.5/.6/.7 close-out handoffs, the dev prepares the close-out commit
and surfaces `git tag v3.1.0 <commit>` + the push command; **Ant applies and
pushes**. Do not self-apply or self-push. No `Co-Authored-By: Claude` trailer
(`feedback_no_claude_coauthor` — STRONG, overrides baseline).

### Adversarial review runs separately

Per the standing rule (PD-1, instructions.xml), adversarial code-review runs via
the `CR` command in fresh context after dev-pass close — NOT an AC here. For a
close-out story the CR surface is thin (only the same-length banner is a code
change); the high-value review targets are the verdict-walk completeness, the
byte reconciliation, the four-surface lock-step, and the 23.6 completeness gate.

### Project Structure Notes

- Touch points: `src/antforth.asm` (banner), `Makefile` (test-80 assertion),
  `README.md` (version + prose + "Coming up" refresh), the new Phase-5 memory +
  `MEMORY.md`, `sprint-status.yaml`, and the verdict-walk/measurements inline in
  THIS story's Dev Notes. No `src/*.asm` mechanism edits beyond the banner.
- The compliance doc + dev_journal are ALREADY reconciled by 23.2/23.4 — verify,
  don't re-edit (AC4).
- Do not migrate the assembler out of `src/assembler.asm`
  (`project_assembler_keep_assembly`).

### Testing standards summary

- No new probes expected — this story verifies the existing Phase-5 corpus
  across three surfaces. Re-`wc -c` from a fresh `make clean && make` for every
  binary figure (B.3). Validate every quoted figure/commit against
  source-of-truth at measure time (PD-2 / B.4) — the orientation numbers here
  are explicitly NOT authoritative.
- REPL-piped Forth probes are the default (S2 / `feedback_repl_tests_preferred`).

### References

- [Source: _bmad-output/planning-artifacts/epics-phase5-epic-23.md#Story-23.5] —
  the epic close-out AC (`:273-298`); v3.1.0 (`:27,133`); ≈300 B aggregate
  (`:147`); deferrals (`:302-317`).
- [Source: _bmad-output/implementation-artifacts/22-4-…phase-4-retrospective.md]
  — the direct structural precedent (four-surface version bump, verdict walk,
  three-surface sweep, tag handoff, the test-80 fourth-surface lesson).
- [Source: _bmad-output/implementation-artifacts/23-1-…md, 23-2-…md, 23-3-…md,
  23-4-…md] — per-story byte deltas (+0 / +310 / +43 / +112) for AC2; HW-smoke
  discharge evidence for AC1 Surface-3.
- [Source: sprint-status.yaml:258-265] — Epic-23 rows (incl. the backlog 23.6 —
  completeness gate); `23-5-…: backlog` → `ready-for-dev`.
- [Source: src/antforth.asm:785] — `str_banner1` `AntForth v3.0.7` → v3.1.0.
- [Source: Makefile:2144-2147] — REPL test 80 banner assertion (fourth surface);
  `:1501` `test-repl` chain; `:105` `check-doc-sync`; `:276,869+` banking/isolated.
- [Source: README.md:14,59,119] — version header, table-intro, stale "Coming up".
- [Source: docs/ans-forth-core-compliance.md, docs/dev_journal.md, docs/WISHLIST.md]
  — already reconciled by 23.x; AC4 confirms, does not re-edit.
- [Source: git tag v3.0.7 = 47690da] — AC2 denominator (rebuild fresh).
- Memory: `project_phase4_scope` (tag-handoff convention, envelope-aggregation
  pattern, NFR-P4-5 budget, Phase-4 close-state — the AC5 memory's predecessor),
  `project_epic17_envelope` (2.4× multiplier; Epic-23 ~1.5× under it),
  `feedback_post_hw_smoke_steps_at_review` (STRONG), `feedback_no_claude_coauthor`
  (STRONG), `feedback_standards_compliance` (drove 23.4's env-honesty decision —
  recorded in AC5 memory), `feedback_cpm_0x1a_eof_marker`,
  `feedback_tib_size_inline_comments`, `feedback_phase4_probe_bank_switch_limitation`,
  `feedback_no_preexisting_discharge` (AC2 byte-cost framing),
  `feedback_repl_tests_preferred`, `project_assembler_keep_assembly`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Opus 4.8)

### Debug Log References

- Pre-edit `test-repl` 1005/0/6 SKIP; post-bump `test-repl` 1005/0 with test-80
  asserting `AntForth v3.1.0`. Logs in scratchpad (`pre_testrepl.log`,
  `post_testrepl.log`, `post_*` per-target).
- Boundary-commit rebuilds for the AC2 ledger done in an isolated worktree on
  tag/commits `47690da` (v3.0.7), `d7f9c1a` (23.1), `bba5dae` (23.2), `c6ef2a9`
  (23.3+CR), `5b4baba` (23.4), `a27c6b5` (23.6/HEAD).

### Completion Notes List

**Story character:** close-out / verification. Only kernel-source change is the
same-length banner swap (`v3.0.7`→`v3.1.0`) → **0 B**. Everything else is
docs/test-assertion. No new word, mechanism, or banking change.

**AC1 — three-surface sweep (post-bump binary, all green):**
- Surface 1 (iz-cpm flat): `test-repl` **1005 PASS / 0 FAIL / 6 SKIP** (≥975
  floor). Four Phase-5 probes chained: asm 5/0, value-to 7/0, in-out 4/0,
  ud-env 14/0. test-80 banner assertion PASSES on `v3.1.0`.
- Surface 2 (iz-cpm-banking): `test-repl-banking` **62/0**; isolated battery (12
  fixtures: 19-3 15, 19-4 2, 19-5-1 2, 20-1 7, 20-2 5, 20-3 5, 21-1 5, 21-2 5,
  21-3 6, 22-1 1, 22-2 4, 22-3 4 = **61/0**); `test-repl-banking-23-6` **7/0**;
  `test-repl-cr-21-3` **4/0**; `test-straddle-regression` **3/3**;
  `test-file-sanity` **1/0**.
- Surface 3 (real MicroBeast): **PASS on silicon, v3.1.0 binary** — transcript
  `beastty-20260628-161341.bin` (operator-supplied 2026-06-28). Banner
  `AntForth v3.1.0`, free mem **24954 B** (= 25517 v3.0.7 − 563 B — independent
  HW corroboration of the +563 B ledger). `VALUE`/`TO` `42 99`; banked `VALUE`
  round (bank 1) `7 7`; `UD.` `4294967295`; env `DOUBLE`/`SEARCH-ORDER-EXT`
  `-1 0 -1 0` (false), `EXCEPTION` `-1 -1` (true). All correct.

**AC2 — byte-budget ledger** (fresh `make clean && make && wc -c`, one toolchain):

| Point | commit | size | per-step |
|---|---|---|---|
| v3.0.7 / Phase-4 close | `47690da` | 28,499 B | — (AC2 denominator) |
| 23.1 asm `IN,`/`OUT,` order | `d7f9c1a` | 28,499 B | **+0** (byte-neutral) |
| 23.2 `VALUE`/`TO` | `bba5dae` | 28,816 B | **+317** (dominant driver) |
| 23.3 `IN`/`OUT` (+23.2/23.3 CR) | `c6ef2a9` | 28,835 B | **+19** |
| 23.4 `UD.` + 6 env rows | `5b4baba` | 28,947 B | **+112** |
| 23.6 window-top guard | `a27c6b5` (HEAD) | 29,062 B | **+115** |
| **Epic-23 cumulative** | | | **+563 B** |

Per-step sum 0+317+19+112+115 = 563 = HEAD−v3.0.7 **exactly** (no drift when
measured from one toolchain; the story's orientation ~448 B was pre-23.6, and the
~17 B "drift" was cross-toolchain figure-noise). vs epic ≈300 B estimate = **~1.9×**
(within the ~2.4× Phase-4 multiplier). Dominant driver 23.2 +317 B = genuine
`VALUE`/`TO` feature delta + banking-gate-halt probe restructure, not waste —
deliberate, itemised, project-lead-visible (per `feedback_no_preexisting_discharge`).
Aggregated accept-with-rationale, **no fresh SCP** (mirrors 22.4). Phase-4+Phase-5
cumulative ≈ **+4,067 B** vs Phase-3-close 24,995 B — well inside NFR-P4-5 ~6 KB
@12 banks. v3.1.0 close-out itself is **0 B kernel** (banner same-length swap).
Note: 23.6's commit subject says "(-8)" — that was relative to a 23.6 in-dev WIP
draft, not vs the 23.4 committed baseline; fresh vs 23.4 = +115 B (authoritative).

**Verdict-table walk (Phase-5 stories — one PASS row each):**

| Story | Deliverable | `done` commit | Gate evidence | HW |
|---|---|---|---|---|
| 23.1 | asm `IN,`/`OUT,` Zilog dst-src order | `c712363`/`d7f9c1a` | `test-repl-asm` 5/0 | discharged (per-story UAT) |
| 23.2 | `VALUE`/`TO` (Core-Ext) | `bba5dae` | `test-repl-value-to` 7/0 | discharged |
| 23.3 | `IN`/`OUT` port words | `c6ef2a9` | `test-repl-in-out` 4/0 | discharged |
| 23.4 | `UD.` + honest `ENVIRONMENT?` rows | `5b4baba` | `test-repl-ud-env` 14/0 | discharged |
| 23.5 | close-out (4-surface bump + sweep + tag) | this commit | full sweep green; 0 B | consolidated batch → operator |
| 23.6 | banked window-top overflow guard | `a27c6b5` | `test-repl-banking-23-6` 7/0 | discharged (ships in v3.1.0) |

**AC3 — four version surfaces** bumped lock-step: banner (0 B), Makefile test-80
assertion, README (header/intro/prose/Coming-up), memory `description:`.

**AC4 — doc reconciliation:** `check-doc-sync` 31 advisories / 0 drift (no NEW).
Compliance doc has `VALUE`/`TO` (§6.2.2405/§6.2.2295), env rows (§3.2.6 20-entry,
honest false/true), `UD.` row — verified present, not re-edited. dev_journal: all
5 Phase-5 gap lines annotated RESOLVED 23.4. WISHLIST: reconciled — IN/OUT
(`# Z80 IO primitives`) + `VALUE`/`TO` (`# ANS Forth locals`) annotated DELIVERED
in 3.1.0; full `{: :}` locals + multitasker + semaphores remain forward candidates.

**AC5 — memory:** `project_phase5_scope.md` written + `MEMORY.md` hook added.

**AC6 — tag:** project-lead-gated; command surfaced in closing chat, not applied.

### File List

- `src/antforth.asm` — banner `str_banner1` v3.0.7 → v3.1.0 (same-length, 0 B)
- `Makefile` — REPL test-80 banner assertion v3.0.7 → v3.1.0 (fourth surface)
- `README.md` — version header, table-intro, 3.1.0 prose paragraph, "Coming up" refresh
- `docs/WISHLIST.md` — IN/OUT + VALUE/TO annotated DELIVERED in 3.1.0
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 23-5 status transitions
- `_bmad-output/implementation-artifacts/23-5-…-v3-1-0-tag.md` — this story (tasks, Dev Agent Record)
- `~/.claude/.../memory/project_phase5_scope.md` (new) + `MEMORY.md` (index hook)

## Change Log

| Date | Change |
|------|--------|
| 2026-06-28 | Story 23.5 drafted (create-story context-engine pass): Epic-23 / Phase-5 close-out — four-surface v3.0.7→v3.1.0 bump, three-surface regression sweep, ≈+448 B Epic-23 byte reconciliation, Phase-5 successor memory, project-lead-gated v3.1.0 tag. Flags the backlog Story 23.6 completeness gate + the Makefile test-80 fourth-surface trap. Status → ready-for-dev. |
| 2026-06-28 | Story 23.5 dev-pass: four-surface v3.0.7→v3.1.0 bump (banner 0 B, Makefile test-80, README, memory); three-surface sweep green (flat 1005/0, banking 62/0 + isolated 61/0 + 23.6 gate 7/0 + cr-21-3 4/0 + straddle 3/3 + file-sanity); doc-sync 31/0-drift; WISHLIST IN/OUT+VALUE/TO reconciled. AC2 ledger re-measured fresh: Epic-23 **+563 B** (HEAD 29,062 − v3.0.7 28,499; orientation ~448 B was pre-23.6). Phase-5 memory written. Surface-3 HW + v3.1.0 tag handed to project lead. Status → review. |
| 2026-06-28 | AC1 Surface-3 HW smoke **PASS on silicon, v3.1.0 binary** (operator transcript `beastty-20260628-161341.bin`): banner `AntForth v3.1.0`, free 24954 B (= −563 B vs v3.0.7, corroborates AC2 ledger); `VALUE`/`TO` `42 99`, banked round `7 7`, `UD.` `4294967295`, env honesty `DOUBLE`/`SEARCH-ORDER-EXT` false + `EXCEPTION` true. All ACs now satisfied incl. silicon. |
