# Story 14.1: PAD documented as canonical transient-buffer for test authors

Status: done

<!--
This is the FIRST story in Epic 14 (Phase-3 Process Foundation), the
debt-cleanup interlude on top of the v2.0.0 baseline (commit 6599d73,
tagged 2026-05-07). Epic 14 lands the B.1–B.5 lead-in cluster of
process / discipline edits before any non-lead-in Phase-3 story
drafting begins; Story 14.1 closes carry-forward item B.1 per
docs/PHASE-3-CARRY-FORWARD.md and §"Suggested Phase-3 First-Epic
Shape" recommended sequencing ("B.1 first — tests/README.md exists,
PAD documented as canonical (closes Epic-12 retro A1 belatedly)").

Origin lineage:
  Epic-12 retro 2026-05-01 Action Item A1 — first deferred owner of
  the PAD-as-canonical doc (then no real PAD word existed).
  Epic-13.5 retro 2026-05-07 Action Item A2 — re-prioritised B.1 into
  Phase-3 lead-in now that Story 13.5.4 added a real PAD word at
  HERE+84 (commit 6208a81).
  Story 13.5.1 dev-pass 2026-05-05 — surfaced the S"-vs-HERE transient
  buffer collision when probes (p2)/(p3)/(p4) initially used `S" …"`
  + HERE; fixed in-pass by switching to ALLOTed B45/B46/B47 buffers
  (`13.5-1-…md:650, :729, :749`).
  Story 13.5.4 (TD-6) 2026-05-06 — landed real PAD DEFCODE at
  src/memory.asm:147 returning HERE+PAD_OFFSET (84) per ANS §6.2.2000.
  Story 13.6 hardware finding F-9 2026-05-04 — caught HERE-as-cross-
  line-buffer corruption on real CP/M / MicroBeast.
  PRD Phase-3 2026-05-08 FR-P3-11 + FR-P3-15 — formalised B.1's
  scope and the verdict-criterion meta-pattern for B.x lead-in
  stories.
  Architecture Phase-3 2026-05-08 §"B.1-D1" + §"Process Patterns
  (Phase-3-specific)" — pinned `tests/README.md` as the single
  source of truth for probe-authoring conventions; Makefile test
  section gets a one-line pointer comment for discoverability.

Severity: documentation only. Zero binary delta expected
(NFR-P3-2 envelope: B.1 = 0 bytes). Zero new mechanism, zero new
EQUs, zero new dictionary words. The deliverable is a doc artefact
plus a one-line Makefile pointer comment.

Standing commitments (S1–S12, codified as NFR-P3-22..33) apply; this
story re-validates the relevant subset:
  S1 — adversarial review runs separately via `CR` command in fresh
       context after dev-pass close (PD-1 / Story 13.5.0); this
       story's ACs do NOT enumerate "trigger an adversarial review
       pass". `feedback_adversarial_review.md` enforcement holds.
  S2 — REPL-piped tests are the canonical regression surface (no new
       tests required for this doc-only story; the doc itself
       documents the discipline).
  S5 — HALT on PARTIAL ship attempts. No "ship 4/9 ACs + spawn 14.1.1"
       pattern.
  S8 — "pre-existing" / "out-of-scope" cannot discharge correctness
       defects; this story closes a *documentation* gap, not a
       correctness defect.
  S9 — mid-epic hardware-smoke cadence; **this story is a documented
       S9 exemption** (zero binary delta; AC #8 records the exemption
       explicitly per NFR-P3-7 + architecture §"Hardware-smoke
       cadence").
  S10 — workflow > memory > prompt; the test-author convention lands
        in `tests/README.md` (the enforcement surface for probe
        authors per CCD-P3-2), not in a memory entry or
        conversation-only prompt.
  S11 — version-surface audit applies at *tag-applicable* close-out;
        Story 14.1 is not tag-applicable (Ant's call per epic 14
        shape — "Tag-applicable close-out (S11 audit) on Ant's
        call — banner-only point-release valid but optional").
  S12 — hardware-typed probe authoring discipline (word-existence
        + TIB-128 line-length); the doc references S12 directly
        per AC6.

PD-1 reminder (Story 13.5.0, 2026-05-05): adversarial review is
executed by the `CR` command in fresh context after dev-pass close
— it is NOT a story-level acceptance criterion. The
`<critical>` block in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`
forbids in-pass adversarial review enumeration. This story's ACs
honour that structurally — none of them say "trigger an adversarial
review pass" or equivalent.

Validation is optional. Run validate-create-story for quality check
before dev-story.
-->

## Story

As a test author writing a REPL-piped Forth probe (or a hardware-typed smoke-batch destined for human typing on real CP/M 2.2 / MicroBeast),
I want clear documented guidance — at a single, discoverable location colocated with the tests — on which transient-buffer word to use when a probe needs scratch space that survives a single space-delimited parse, plus the historical context of why `HERE`-based and `S"`-near-`HERE` writes are avoided,
So that I avoid the Story-13.5.1 / Story-13.6 F-9 transient-buffer-collision class (silent corruption when one parse step's `WORD` output writes over a prior step's `HERE`-stored data), use the right buffer class for the right lifetime (PAD for one-shot transient surviving a single parse; ALLOTed named buffers like `B45`/`B46`/`B47` per Story-13.5.1 for cross-parse buffers; never write near `HERE`), and find the full S12 hardware-typed-probe discipline (word-existence pre-flight + TIB-128 line-length lint) in one place — so subsequent Phase-3+ probe authors don't re-discover the convention every time.

This is the **first story** in Epic 14 (Phase-3 Process Foundation) — the lead-in cluster (B.1 + B.2 + B.3 + B.4 + B.5) that lands first per `docs/PHASE-3-CARRY-FORWARD.md` § "Suggested Phase-3 First-Epic Shape" and architecture §"Implementation sequence". Epic 14 establishes the structural lints + discipline-as-deliverable pattern that shape every subsequent Phase-3 dev-pass and that Phase 4 inherits cleanly. Story 14.1 closes carry-forward item B.1 (5 of 12 P1 items at epic close-out).

The story has **zero new feature scope** and **zero binary delta** (NFR-P3-2 envelope per architecture §"Per-story binary delta envelopes": `B.1 | 0 (doc only)`). The deliverable is a single new doc artefact (`tests/README.md`) plus a one-line pointer comment in `Makefile`'s test section for discoverability. The story is a **documented S9 hardware-smoke exemption** per NFR-P3-7 / architecture §"Hardware-smoke cadence" ("Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped").

The story carries its own **verdict criterion** per FR-P3-15 (the verdict-criterion meta-pattern that makes B.x lead-in stories discipline-as-deliverable): a grep of `tests/README.md` for `PAD` returns at least one occurrence in the canonical-buffer section, and the Makefile test section grep returns the pointer comment. If either verdict criterion fails, the story HALTs per S5.

---

## Severity / Phase Re-Statement (BINDING — context for every dev-pass decision)

This is a **documentation-only** story closing the long-deferred carry-forward item B.1 (originally Epic-12 retro Action Item A1 2026-05-01; re-prioritised into Phase-3 lead-in by Epic-13.5 retro Action Item A2 2026-05-07). The fix shape is **fully pinned** by `architecture.md` §"B.1 — `PAD` as canonical transient-buffer for tests" — `tests/README.md` (NEW) is the single source of truth; Makefile test section gets a one-line pointer comment.

| Dimension | Value | Source |
|---|---|---|
| **Scope** | Doc + Makefile pointer comment only | `architecture.md` §"B.1-D1" |
| **New file** | `tests/README.md` (project root) | `architecture.md` §"Phase-3 File-Touch Surface — New files" |
| **Modified file** | `Makefile` (one-line pointer comment in test section) | `architecture.md` §"Existing files modified in Phase 3" |
| **Binary delta** | 0 bytes (doc-only) | `architecture.md` §"Per-story binary delta envelopes" |
| **Test count delta** | 0 (no new probes; doc + Makefile pointer comment) | `epics.md` Story 14.1 AC9 ("`make test-repl` reports ≥ 973 PASS / 0 FAIL; zero regressions") |
| **S9 disposition** | Exempt + documented in verdict table | NFR-P3-7 / `architecture.md` §"Hardware-smoke cadence" |
| **S11 disposition** | Not tag-applicable; banner-bump optional per Ant's call | `epics.md` Epic-14 §"Shape" |
| **Verdict criterion (self-test)** | grep `tests/README.md` for PAD + grep `Makefile` for pointer comment | FR-P3-15 / AC7 |

**The story is pre-decided in shape.** No fix-shape pick (A.1-D3 / A.3 / B.7 dispositions); no kernel surgery; no register-convention audit; no caught-form THROW migration. The dev-pass authors content per the spec, lands two file edits, runs `make test-repl` for regression gate, and closes.

If the dev-pass surfaces *additional* test-author conventions worth documenting beyond AC4's three buffer classes + AC6's S12 reference, those land in `tests/README.md` in-pass per AC #11 in-pass-fix discipline (mirror Story 13.5.6 Task 14 currency-audit shape) — but they do NOT trigger a sibling-story spawn, and the verdict table still uses the AC7 grep criteria. Per S5, no PARTIAL ship.

---

## Acceptance Criteria

1. **Given** Phase-3 starts with no `tests/README.md` (verified pre-edit via `ls tests/README.md` → "No such file or directory" — captured in Pre-edit baseline + Dev Notes),
   **when** Story 14.1 is dev-passed,
   **then** `tests/README.md` exists at the project root's `tests/` directory (canonical path: `/home/ant/src/microbeast/antforth/tests/README.md`). The file is colocated with the tests per `architecture.md` §"Documentation boundary" ("`tests/README.md` is colocated with the tests"). The file lands as a markdown document — header + sections per AC2..AC6 below.

2. **Given** ANS Forth 1994 §6.2.2000 PAD word definition (transient region surviving any one space-delimited parse step per §3.3.3.6) plus Story 13.5.4's real PAD DEFCODE landing at `src/memory.asm:147` (commit 6208a81; returns HERE+`PAD_OFFSET`=HERE+84 per ANS §6.2.2000 / §3.2.6's `/PAD ENVIRONMENT?` claim),
   **when** AC1's `tests/README.md` is authored,
   **then** the doc contains a section titled (e.g.) "Canonical transient buffer — PAD" or equivalent that establishes PAD (per ANS §6.2.2000) as the canonical transient-buffer word for one-shot scratch space that must survive a single space-delimited parse. The section explicitly:
   - **Cites ANS §6.2.2000** (PAD `( -- c-addr )` — "c-addr is the address of a transient region that can be used to hold data for intermediate processing")
   - **Cites ANS §3.3.3.6** (the survival guarantee — PAD survives "the application's parsing of any one space-delimited name")
   - **Notes antforth's specific implementation** — PAD returns HERE+84 per `src/memory.asm:147` / `src/constants.asm:44` `PAD_OFFSET EQU 84`, and the `/PAD ENVIRONMENT?` query returns `( 84 -1 )` per `src/system.asm:458..460`
   - **Gives a canonical-idiom example** (mirror `architecture.md` §"Concrete Examples" `T-PROBE-PAD` shape — `S" hi" PAD SWAP MOVE PAD 2 TYPE` outputs `hi` per Story 13.5.6 hardware Task 5 line 14 evidence)

3. **Given** the historical S"-vs-HERE transient-buffer-collision class — surfaced by Story 13.5.1's probe-authoring during the per-FCB dirty-flag dev-pass (see `13.5-1-…md:650, :729, :749` — "probes (p2)/(p3)/(p4) initial drafts used `S" ..."` for write-source + `HERE` for read-destination — surfaced a transient-buffer collision (S" allocates near HERE; HERE C@ post-READ-FILE returned the residual S" byte, not the read byte). Fixed by switching to ALLOTed buffers `B45`/`B46`/`B47`") — and re-confirmed by Story 13.6 hardware finding F-9 (HERE-as-cross-line-buffer corruption on real CP/M / MicroBeast — `13-6-…md:1192`),
   **when** AC1's `tests/README.md` is authored,
   **then** the doc contains a section (or sub-section) acknowledging that `HERE`-based and `S"`-near-`HERE` writes were used historically in early probe drafts and explains *why* they're avoided post-Story-13.5.1 / post-Story-13.5.4. Specifically the doc covers:
   - **The collision mechanism** — `S"` allocates its counted-string output at or near `HERE` (specifically at HERE+1..HERE+1+u via `WORD`, count ≤ 31 per F_LENMASK; `src/strings.asm:67..150`); a subsequent `HERE C@` after `READ-FILE` returns the residual `S"` byte rather than the read byte (the F-9 reproducer on hardware: `\x04type\x1A` where file content was expected)
   - **Why HERE is volatile across REPL lines** — `HERE` is the dictionary boundary cursor; the parser uses `HERE+1..HERE+32` as scratch on every parse step. Any byte stored at `HERE+1..HERE+32` is destroyed on the next parse step's first space-delimited token. This is structural, not incidental — the HERE region is *deliberately* volatile per the threading model
   - **Story-13.5.1 cite** — `13.5-1-…md:650` (the canonical fix narrative); `13.5-1-…md:729, :749` (the closure record naming the ALLOTed buffer pattern as the structural fix)
   - **Story-13.6 F-9 cite** — `13-6-…md:1192` (the hardware reproducer narrative)
   - **Story-13.5.4 cite** — `13.5-4-…md:34..46` (the structural-fact pair: (i) `/PAD ENVIRONMENT?` claims a 84-byte region without PAD-the-word existing pre-13.5.4; (ii) every parse step writes ≤32 bytes at HERE+1, leaving HERE+33..HERE+84+ untouched, so pad-at-HERE+84 *does* satisfy the §3.3.3.6 single-parse survival guarantee)

4. **Given** the three transient-buffer classes that emerged from the cleanup-slate (PAD for one-shot transient surviving a single parse; ALLOTed named buffers like `B45`/`B46`/`B47` per Story-13.5.1's pattern for buffers that must survive across multiple parse steps; never write near `HERE` for any user-data storage),
   **when** AC1's `tests/README.md` is authored,
   **then** the doc contains a section giving clear guidance for the three buffer classes with at least one example per class. The minimum coverage:
   - **PAD (one-shot transient)** — example: `S" hi" PAD SWAP MOVE PAD 2 TYPE` outputs `hi` (single REPL line, single parse-step survival; the `MOVE` form per Story 13.5.6 hardware Task 5 line 14 — antforth implements `MOVE` ANS §6.1.1900, not `CMOVE` ANS §6.2.0945; the Story 13.5.6 `CMOVE`-instead-of-`MOVE` probe-authoring incident is itself a probe-discipline lesson worth noting)
   - **ALLOTed named buffer (cross-parse)** — example: `CREATE B45 32 ALLOT` then `B45` returns the same address across any number of REPL lines / parse steps. Cite Story 13.5.1's `B45`/`B46`/`B47` usage in `Makefile` REPL tests 944..948 as the canonical Phase-2 application
   - **Never write near HERE** — example anti-pattern (mirror `architecture.md` §"Concrete Examples" `T-PROBE-HERE` Bad shape): `: T-PROBE-HERE  HERE 64 ERASE  S" hello" HERE SWAP CMOVE  HERE C@ 'h' = ;` — explanation: `S"` allocates near HERE — collision; this returns garbage, not `'h'`
   - **Selection rubric** — one-shot scratch surviving exactly one space-delimited parse → PAD; multi-parse / multi-line buffer → ALLOTed named buffer; never HERE for user data

5. **Given** the discoverability requirement (a probe author searching the project for test-author conventions should find `tests/README.md`),
   **when** Story 14.1 is dev-passed,
   **then** `Makefile`'s test section (`test-repl` recipe area, around line 102 onwards in current HEAD; or the test-related section header) gains a one-line pointer comment to `tests/README.md`. Suggested form: `# See tests/README.md for probe-authoring conventions (PAD-as-canonical-transient-buffer; S12 hardware-typed-probe lints)` or equivalent. The comment lands as a `#` makefile comment (not a recipe line), placed at a position a maintainer scanning the test section will encounter at-or-before any per-test recipe block. Per `architecture.md` §"Existing files modified in Phase 3" Makefile row, this pointer comment is one of the two B.1 changes (alongside `tests/README.md` itself).

6. **Given** the S12 hardware-typed-probe authoring discipline (NFR-P3-33 / architecture §"Probe-authoring discipline") — every smoke-batch destined for human typing on real hardware passes (a) word-existence pre-flight (every word resolves in antforth's dictionary or is documented as a planned new word; recall Story-13.5.6's `CMOVE`-instead-of-`MOVE` incident); (b) TIB-128 line-length lint (every line ≤ 128 characters; mechanical check `awk 'length > 128'` returns no rows),
   **when** AC1's `tests/README.md` is authored,
   **then** the doc contains a section (or final sub-section of the buffer-class guidance) that references S12 directly per FR-P3-33 / NFR-P3-33 — so probe authors find the full discipline in one place. Minimum coverage:
   - **S12 (a) word-existence pre-flight** — a probe's tokens cross-reference against `WORDS` output or kernel source before the probe is committed. Cite Story 13.5.6's `CMOVE`-vs-`MOVE` run-1 incident as the motivating example (the dev-pass authored a hardware spot-check that used `CMOVE`, which doesn't exist in antforth; `error -13: undefined word` resulted; run-2 fix replaced with `MOVE`)
   - **S12 (b) TIB-128 line-length** — every probe line ≤ 128 chars; mechanical check `awk 'length > 128' tests/*.fth` returns no rows. Probes intended for hardware-typing-by-human must split logically across lines that fit antforth's 128-byte input buffer (TIB)
   - **Cross-reference** — `architecture.md` §"Probe-authoring discipline" has the full text; `tests/README.md` summarises and points there for the canonical authority (or — if the doc is small enough — inlines the full discipline). Drafter's pick.

7. **Given** the FR-P3-15 verdict-criterion meta-pattern — each B.x lead-in story tests that the new artefact would have caught the prior-incident pattern that motivated it / is grep-able / is structurally enforced (per architecture §"Implications for B.x verdict criteria"),
   **when** Story 14.1 is dev-passed,
   **then** the verdict criteria for Story 14.1 are mechanically checked at story-close and recorded in Completion Notes:
   - **(a)** `grep -nE '\bPAD\b' tests/README.md` returns ≥ 1 match in the canonical-buffer section per AC2 (the section establishing PAD as canonical). The dev-pass records the grep output line-by-line so the hit is verifiable
   - **(b)** `grep -nE 'tests/README\.md' Makefile` returns ≥ 1 match — the pointer comment from AC5. The dev-pass records the grep output line
   - **(c)** `ls tests/README.md` returns the file (existence check; mirrors `architecture.md` §"Verdict-criterion meta-pattern (all four)" B.1 row — "`tests/README.md` exists, references PAD with the canonical-buffer convention; `Makefile` test section has the pointer comment")
   - **(d)** `grep -nE 'S12|word-existence pre-flight|TIB-128|hardware-typed' tests/README.md` returns ≥ 1 match (S12 reference per AC6)
   - **(e)** `grep -nE 'B45|B46|B47|ALLOT' tests/README.md` returns ≥ 1 match (ALLOTed buffer class per AC4)
   - If any of (a)..(e) returns zero matches, the story HALTs per S5 — the doc-as-deliverable failed its own verdict; the lint did not fire structurally; per architecture §"Implications for B.x verdict criteria" ("If a lead-in fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration")

8. **Given** the post-Epic-13.5 baseline binary at `build/antforth.com` (current `wc -c` = **24,995 bytes** measured directly at story-drafting time on commit 6599d73 — the v2.0.0 banner-bump commit; documented Epic-13.5-close figure was 24,996 per `13.5-6-…md` Task 11, off-by-1 to the v2.0.0-banner-bumped current — see Pre-edit baseline + Dev Notes for the reconciliation per Lesson 13.5-F / B.3),
   **when** the dev-pass measures `wc -c build/antforth.com` and `wc -c build/antforth_filesanity.com` at story-drafting time AND at story-close,
   **then** the post-edit binary sizes are **unchanged from the pre-edit measurement**: production binary 24,995 → 24,995 (Δ = 0); filesanity binary 26,460 → 26,460 (Δ = 0). The story is **doc + Makefile-comment only**; any non-zero binary delta on this story HALTs per S5 — there is no `src/*.asm` instruction change in scope. Per NFR-P3-2 (cumulative Phase-3 ROM cap +200 bytes / 24,996 → ≤ 25,200), Story 14.1's per-story envelope is `0 bytes` (architecture §"Per-story binary delta envelopes" / `epics.md` Story 14.1 AC8). The S9 hardware-smoke task is **documented exempt** per NFR-P3-7 / architecture §"Hardware-smoke cadence": zero-binary-delta stories document their S9 exemption explicitly in the verdict table — never silently skipped. The exemption note lands in Completion Notes: "S9 exempt — zero binary delta (doc + Makefile-comment only); per architecture §"Hardware-smoke cadence" ("Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly")."

9. **Given** the post-Epic-13.5 / post-v2.0.0 `make test-repl` baseline of 973 PASS / 0 FAIL (per `13.5-6-…md` Task 3),
   **when** `make test-repl` is run pre-edit AND post-edit,
   **then** the result is **973 PASS / 0 FAIL — zero regressions, zero test-count movement**. Pre-edit verification: `grep -c '^PASS:' <(make test-repl 2>&1)` returns 973; pre-edit FAIL count = 0. Post-edit (story-close): same numbers — Story 14.1 is doc + Makefile-comment only, no test-suite movement expected. Any movement HALTs per S5 (doc-only stories cannot move test counts; movement indicates an unintended side-effect — most likely an accidental Makefile recipe edit). Recorded in Completion Notes alongside `make test` (assembly thread) clean check (informational; not a PARTIAL gate) and `make test-file-sanity` PASS (informational).

---

## Tasks / Subtasks

- [x] **Task 1 — Pre-edit baseline** (AC #8, #9; per architecture §"Re-`wc -c` at the start of every dev-pass" / Lesson 13.5-F)
  - [x] 1.1 — Ran `wc -c build/antforth.com` → **24,995 bytes** (HEAD 6599d73; 1 byte below documented 24,996 — see 1.5)
  - [x] 1.2 — Ran `wc -c build/antforth_filesanity.com` → **26,460 bytes** (1 byte below documented 26,461)
  - [x] 1.3 — Ran `make test-repl 2>&1 | grep -c '^PASS:'` → **973**; `... | grep -c '^FAIL:'` → **0**
  - [x] 1.4 — Ran `ls tests/README.md` → exit 2 / `ls: cannot access '/home/ant/src/microbeast/antforth/tests/README.md': No such file or directory` (binding pre-edit AC #1 evidence captured)
  - [x] 1.5 — Documentation-drift reconciled in Completion Notes: -1 / -1 byte drift below `13.5-6-…md` Task 11 figures attributable to v2.0.0 banner-bump commit (6599d73, banner string shrank by 1 byte). Not a 14.1 regression — illustrates B.3's "never inherit the prior story's reported number" / Lesson 13.5-F.

- [x] **Task 2 — Author `tests/README.md`** (AC #1, #2, #3, #4, #6)
  - [x] 2.1 — Created `tests/README.md` with header `# antforth tests — probe-authoring conventions`
  - [x] 2.2 — Section 1 "Canonical transient buffer — PAD" lands AC #2: cites ANS §6.2.2000 + §3.3.3.6; antforth-specific PAD=HERE+84 per `src/memory.asm:147` + `src/constants.asm:44` + `src/system.asm:458..460`; canonical idiom `S" hi" PAD SWAP MOVE PAD 2 TYPE → hi` (Story 13.5.6 hardware Task 5 line 14 PASS)
  - [x] 2.3 — Section 2 "Why not `HERE` / `S"`-near-`HERE`" lands AC #3: cites Story-13.5.1 (`:650, :729, :749`); Story-13.6 F-9 (`:1192`); Story-13.5.4 (`:34..46`); explains the count-byte-at-HERE+0 / chars-at-HERE+1..HERE+u WORD scratch mechanism (`src/strings.asm:85, :145`); explains HERE-volatility structural rationale
  - [x] 2.4 — Section 3 "Buffer-class selection rubric" lands AC #4: three-class table + per-class example. PAD example is the canonical idiom; ALLOTed example uses Story-13.5.1 `B45`/`B46`/`B47` shape verbatim from Makefile tests 944..948; never-near-HERE shows the structural reason. Selection summary at section end.
  - [x] 2.5 — Section 4 "S12 — hardware-typed probe authoring discipline" lands AC #6: (a) word-existence pre-flight cites Story-13.5.6 CMOVE-vs-MOVE incident (`13.5-6-…md:798`); (b) TIB-128 line-length lint cites `src/constants.asm:41` `TIB_SIZE EQU 128`; mechanical `awk 'length > 128' tests/*.fth` check given verbatim; cross-references architecture §"Probe-authoring discipline (S12 / NFR-P3-33)"
  - [x] 2.6 — AC #7 verdict greps run against the doc immediately after authoring; all 5 ≥ 1 match (recorded in Task 4 below)

- [x] **Task 3 — Add Makefile pointer comment** (AC #5)
  - [x] 3.1 — Located `test-repl: $(TARGET)` recipe at `Makefile:102` (post-edit `:103` after comment insertion)
  - [x] 3.2 — Inserted `# See tests/README.md for probe-authoring conventions (PAD-as-canonical-transient-buffer; S12 hardware-typed-probe lints)` immediately above the recipe line (now `Makefile:102`)
  - [x] 3.3 — `make test-repl` post-edit: 973 PASS / 0 FAIL — comment did not perturb Make parsing

- [x] **Task 4 — Verdict-criterion meta-pattern self-test** (AC #7; FR-P3-15)
  - [x] 4.1 — `grep -nE '\bPAD\b' tests/README.md` → 31 matches (initial dev-pass: 29; review fix-pass added 2 more in §1 / §2 mechanism rewrite). PASS.
  - [x] 4.2 — `grep -nE 'tests/README\.md' Makefile` → 1 match at `Makefile:102`. PASS.
  - [x] 4.3 — `ls tests/README.md` → file exists, 303 lines (initial dev-pass: 280; review fix-pass added 23 lines for the §2 mechanism rewrite, anti-pattern recast, and PAD survival proof correction). PASS.
  - [x] 4.4 — `grep -nE 'S12|word-existence pre-flight|TIB-128|hardware-typed' tests/README.md` → 8 matches. PASS.
  - [x] 4.5 — `grep -nE 'B45|B46|B47|ALLOT' tests/README.md` → 14 matches. PASS.
  - [x] 4.6 — All 5/5 verdict criteria PASS; no HALT triggered.

  Initial dev-pass match counts (recorded for audit trail; corrected by review fix-pass per Lesson 13.5-F): 4.1 said "10+" (actual 29); 4.3 said "277 lines" (actual 280); 4.4 said "8 matches" (actual 7); 4.5 said "11 matches" (actual 13). Fix-pass re-greps and the figures above replace those drifted numbers.

- [x] **Task 5 — Post-edit binary + test regression check** (AC #8, #9)
  - [x] 5.1 — `wc -c build/antforth.com` → **24,995 bytes** (Δ = 0). PASS.
  - [x] 5.2 — `wc -c build/antforth_filesanity.com` → **26,460 bytes** (Δ = 0). PASS.
  - [x] 5.3 — `make test-repl` → **973 PASS / 0 FAIL** (zero regressions, zero test-count movement). PASS.
  - [x] 5.4 — `make test` (assembly thread): "Pass 1 complete (0 errors) / Pass 2 complete (0 errors) / Pass 3 complete / Errors: 0, warnings: 0, compiled: 30598 lines" + "PASS: Output matches expected".
  - [x] 5.5 — `make test-file-sanity`: "PASS: file-sanity test — 12 expected lines match exactly (Story 13.5.2 H1: .fbr_eof tri-state discriminator probe)".

- [x] **Task 6 — S9 hardware-smoke disposition** (AC #8 / NFR-P3-7)
  - [x] 6.1 — **S9 exempt** — zero binary delta (doc + Makefile-comment only); per `architecture.md` §"Hardware-smoke cadence" — *"Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped."* Exemption recorded in Completion Notes; binary delta verified zero in Tasks 5.1 / 5.2.

- [x] **Task 7 — Carry-forward catalogue update** (`docs/PHASE-3-CARRY-FORWARD.md`)
  - [x] 7.1 — Added B.1 row to `docs/PHASE-3-CARRY-FORWARD.md` § "Status Tracking" with `✅ Done` and the closure note verbatim from the spec.

- [x] **Task 8 — Standing-commitment hold confirmation** (NFR-P3-22..33 subset)
  - [x] 8.1 — S1..S12 hold walked in Completion Notes below.

- [x] **Task 9 — HALT-on-PARTIAL discipline check at story-close** (S5 / `feedback_no_preexisting_discharge.md`)
  - [x] 9.1 — Walked AC #1..#9; **no HALT triggered**. All ACs PASS at story-close (recorded in Completion Notes).
  - [x] 9.2 — `ls _bmad-output/implementation-artifacts/14-1-1*` → no match; no sibling-story spawn anti-pattern.

- [x] **Task 10 — Sprint-status update + Change Log + File List**
  - [x] 10.1 — `sprint-status.yaml` flipped `14-1-…` to `in-progress` at dev-pass start; will flip to `review` at story-close.
  - [x] 10.2 — File List authored below.
  - [x] 10.3 — Change Log authored below.

### Review Follow-ups (AI)

Surfaced by the /CR adversarial review fix-pass on 2026-05-08. All in-scope (README-side) HIGH and MEDIUM issues were fixed in the same pass; the items below name the out-of-scope follow-ups.

- [ ] [AI-Review][MEDIUM] Kernel-comment F_LENMASK drift in `src/memory.asm:138` — the PAD comment block claims "≤31 chars at HERE+1..HERE+u per F_LENMASK", but `WORD` (`src/strings.asm:91..122`) does **not** clamp to F_LENMASK; that mask is the dictionary-header name-length cap, applied in `src/compiler.asm:203..207` when a CREATEd name is stored. Same fact-drift now corrected in `tests/README.md` § 1, but the kernel comment still propagates the incorrect claim. Out of scope for Story 14.1 per `architecture.md` §"B.1-D1" (doc-only; no `src/*.asm` edits). Recommended owner: a follow-up `B.x` doc-correction story or a kernel-comment-fix slot in a future tag-applicable epic; tag for B.4 figure-drift discipline coverage when it lands.

---

## Dev Notes

### Why this story matters

`tests/README.md` does not exist. `/PAD ENVIRONMENT?` shipped from at least Epic-12 onwards claiming a 84-byte PAD region (`src/system.asm:458..460`), but PAD-the-word didn't land until Story 13.5.4 (`src/memory.asm:147`, commit 6208a81 in Epic 13.5). In the gap between `/PAD ENVIRONMENT?` shipping and PAD-the-word landing, probe authors who needed a transient buffer reached for `HERE` (the dictionary-allotment cursor) — and that worked *within a single REPL line* but corrupted silently *across REPL lines*. Story 13.5.1 first surfaced the collision (during in-pass probe authoring, fixed by switching to ALLOTed `B45`/`B46`/`B47` named buffers); Story 13.6 hardware finding F-9 caught the same shape on real hardware; Story 13.5.4 (TD-6 closure) added the missing PAD word.

**The convention now exists in code.** The convention does not yet exist in *documentation* visible to a probe author who hasn't read the cleanup-slate dev notes. Story 14.1 closes that gap.

### Prior-story intelligence (Epic 13.5 — directly relevant)

**Story 13.5.1 (TD-1 + TD-2 + TD-4 — per-FCB R/W dirty-flag)** at `_bmad-output/implementation-artifacts/13.5-1-td-1-td-2-td-4-r-w-per-fcb-dirty-flag.md`:
- Dev pass surfaced the S"-vs-HERE transient-buffer collision in-pass (Task 12 / probe matrix p1..p5 at Makefile tests 944..948). The fix was structural — switch to ALLOTed buffers named `B45`/`B46`/`B47`. See lines :650, :729, :749 for the canonical narrative.
- Probe-authoring lesson: "S" allocates near HERE; HERE C@ post-READ-FILE returned the residual S" byte, not the read byte" (line :650). This is the binding mental-model pattern Story 14.1 documents in `tests/README.md`.

**Story 13.5.4 (TD-6 — PAD / HERE-cross-line correctness)** at `_bmad-output/implementation-artifacts/13.5-4-td-6-pad-here-cross-line-correctness.md`:
- Added real PAD DEFCODE at `src/memory.asm:147` (commit 6208a81); body returns HERE+`PAD_OFFSET` (84) per ANS §6.2.2000.
- Comment block at `src/memory.asm:133..145` carries the citation: `; PAD ( -- c-addr )           ANS Forth 1994 §6.2.2000` + the §3.3.3.6 single-parse-survival explanation + the WORD-writes-at-HERE+1..HERE+32 fact.
- Two structural facts at `13.5-4-…md:34..46`: (i) `/PAD ENVIRONMENT?` claims 84 bytes; (ii) WORD writes ≤32 bytes at HERE+1..HERE+1+u, leaving HERE+33..HERE+84+ untouched, so pad-at-HERE+84 satisfies §3.3.3.6 single-parse survival by construction.

**Story 13.5.6 (Epic 13.5 close-out + v2.0.0 tag)** at `_bmad-output/implementation-artifacts/13.5-6-epic-13-5-close-out-gate-and-antforth-2-0-tag.md`:
- Hardware Task 5 line 14 (TD-6 spot-check): `S" hi" PAD SWAP MOVE PAD 2 TYPE → hi` PASS on real CP/M / MicroBeast (the antforth-specific MOVE form, not CMOVE — CMOVE doesn't exist in antforth; run-1 incident fixed in run-2).
- Task 5 sidenote (`13.5-6-…md:798`): "Run-1 T14 CMOVE: dev-pass-authored spot-check used `CMOVE` (DPANS94 §6.2.0945), but antforth implements `MOVE` (`memory.asm:292`, ANS §6.1.1900) and not `CMOVE`. … Run-2 fix: replaced `CMOVE` with `MOVE`; works as expected." — this is the canonical S12 word-existence-pre-flight motivating example to cite in `tests/README.md` (AC #6).
- Documentation-drift reconciliation at Task 2: documented Epic-13.5 close binary was 25,002 / 26,467; actual (commit 97a57d6) was 24,996 / 26,461 — a 6-byte negative drift. Story 14.1 carries forward the lesson by re-`wc -c`-ing pre-edit (Lesson 13.5-F / B.3) — current HEAD `6599d73` shows 24,995 / 26,460, an additional -1 / -1 byte drift attributable to the v2.0.0 banner bump. Story 14.1 records this reconciliation in Pre-edit baseline + Dev Notes; not a 14.1 regression, just an illustrative drift.

**Story 13.6 hardware finding F-9** at `_bmad-output/implementation-artifacts/13-6-epic-13-fs-stress-bdos-audit-and-antforth-2-0-release-gate-ccd-4.md:1192`:
- The HERE-as-cross-line-buffer corruption shape on real CP/M / MicroBeast: line N stores READ-FILE 6 output at HERE; line N+1's first space-delimited token (e.g., `S" SZ="`) writes its counted-string output at HERE+1, clobbering bytes 1..count of the line-N data. Reproducer surfaced as `\x04type\x1A` instead of file content.
- Disposition: downgraded from HIGH-CANDIDATE to LOW after `src/strings.asm:85` inspection; revised diagnosis: "antforth's `WORD` writes counted-string output at HERE+1, clobbering whatever READ-FILE wrote there on the previous line. **HERE is volatile across REPL lines.**"
- This is the binding hardware-side reproducer for the convention `tests/README.md` documents.

### Architecture context (Phase-3 architecture, 2026-05-08)

`_bmad-output/planning-artifacts/architecture.md` pins the following for Story 14.1:

- **§"B.1 — `PAD` as canonical transient-buffer for tests"** (line 248..254) — `tests/README.md` (new file) is the single source of truth; Makefile's test section gets a one-line pointer comment; the README documents PAD's purpose, historical alternatives, and the canonical idiom.
- **§"Phase-3 File-Touch Surface — New files created in Phase 3"** (line 591) — `tests/README.md | Test-author guidance: PAD-as-canonical-transient-buffer, S12 probe-authoring discipline, hardware-typed probe lints | B.1`.
- **§"Existing files modified in Phase 3"** (line 604) — `Makefile | Add … pointer comment to tests/README.md from test section (B.1) …`.
- **§"Process Patterns (Phase-3-specific)"** §"Probe transient-buffer choice (B.1)" (line 450..454) — three buffer classes pinned: PAD (one-shot), ALLOTed named (cross-parse), avoid HERE.
- **§"Process Patterns (Phase-3-specific)"** §"Probe-authoring discipline (S12 / NFR-P3-33)" (line 445..449) — word-existence pre-flight + TIB-128 line-length lint; mechanical checks `awk 'length > 128'`.
- **§"Concrete Examples"** Good — probe transient buffer (line 561..569) — `T-PROBE-PAD` shape: `PAD 64 ERASE  S" hello" PAD SWAP CMOVE  PAD C@ 'h' = ;`. NOTE: the architecture-doc example uses `CMOVE`, but antforth implements `MOVE` not `CMOVE` (per Story 13.5.6 run-1 incident). The `tests/README.md` example **must use `MOVE`** to be actually-runnable — this is itself a small architecture-doc figure-drift issue worth flagging in Dev Notes (Lesson PD-2 territory; Story 14.4's B.4 figure-drift discipline `<critical>` block, when it lands, would catch this).
- **§"Concrete Examples"** Bad — probe transient buffer (line 571..579) — `T-PROBE-HERE` shape mirrors `tests/README.md` AC #4 anti-pattern.
- **§"Verdict-criterion meta-pattern (all four)"** (line 264..268) — B.1 row: "`tests/README.md` exists, references PAD with the canonical-buffer convention; `Makefile` test section has the pointer comment". Story 14.1 AC #7 implements this verdict criterion.
- **§"Implications for B.x verdict criteria"** (line 217) — "If a lead-in fails its own verdict, it doesn't ship — discipline-as-deliverable, not aspiration". Story 14.1 AC #7 + Task 4.6 enforce this structurally.
- **§"Per-story binary delta envelopes"** (line 343..345) — B.1 = 0 (doc only).
- **§"Hardware-smoke cadence (S9 / NFR-P3-7)"** (line 456) — "Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped". Story 14.1 AC #8 + Task 6.1 implement this.
- **§"Recommended sequencing within the lead-in"** (line 932..934) — "1. **B.1** first — `tests/README.md` exists, PAD documented as canonical (closes Epic-12 retro A1 belatedly)". Story 14.1 is the **first story** in Epic 14.

### PRD Phase-3 context (2026-05-08)

`_bmad-output/planning-artifacts/prd.md` for Story 14.1's binding requirements:

- **FR-P3-11 (B.1)** at `prd.md:56` — "A test author can find documented guidance — in `tests/README.md` or an inline comment block in `Makefile`'s test section — establishing `PAD` (per ANS §6.2.2000) as the canonical transient-buffer word for use in REPL-piped Forth probes that need a scratch buffer surviving one space-delimited parse. The guidance acknowledges the historic alternatives (`HERE` and `S"` allocation) and explains why `PAD` is preferred."
- **FR-P3-15 (verdict-criterion meta-pattern)** at `prd.md:62` — "The story-template's discipline edits (B.2–B.4) carry their own verdict criteria in the lead-in stories that introduce them — each B.2/B.3/B.4 story tests that the new template would have caught the prior-incident pattern that motivated it (e.g. B.2 verifies the lint catches a synthesised "mirror" phrase; B.3 verifies the `wc -c` task captures the actual binary)." Story 14.1 extends this pattern to B.1: AC #7 mechanically verifies the `tests/README.md` artefact exists and is grep-able for PAD + Makefile pointer comment + S12 + ALLOT class.
- **FR-P3-22..25 (phase-wide regression constraint)** — 973 PASS / 0 FAIL baseline + CODE-source byte-identical assembly + unprefixed numeric-literal form preserved. Story 14.1's AC #9 enforces the 973 PASS / 0 FAIL on this story's dev-pass.
- **NFR-P3-2 (Phase-3-specific cumulative ROM budget)** — +200 bytes cap (24,996 → ≤ 25,200); B.1 envelope 0 bytes. Story 14.1's AC #8 enforces.
- **NFR-P3-7 (S9 codification)** — every binary-delta story runs hardware smoke; zero-binary-delta stories document exemption explicitly. Story 14.1's AC #8 + Task 6.1 enforce.
- **NFR-P3-18 (story-template discipline as quality attribute)** — lints fire automatically when triggered; drafter doesn't need to remember to invoke them. Story 14.1's `tests/README.md` is the structural artefact at the test-author discipline surface (per CCD-P3-2 — process discipline lives in workflow files; tests/README.md is one of the named workflow-file-equivalent artefacts at architecture §"Workflow-file enforcement surface" line 208).
- **NFR-P3-33 (S12 — hardware-typed probe authoring)** at `prd.md:125` — "Every smoke-batch destined for human typing on real hardware passes (a) word-existence pre-flight (every word resolves in antforth's dictionary or is documented as a planned new word) and (b) TIB-128 line-length lint (every line ≤ 128 chars). The `tests/README.md` (or equivalent) per FR-P3-11 documents these conventions for test authors." Story 14.1's AC #6 is FR-P3-33's structural surface.

### Implementation site references (file:line)

- **PAD word** — `src/memory.asm:147` (`DEFCODE "PAD", 0` + `w_PAD_cf` body returning HERE+PAD_OFFSET)
- **PAD comment block** — `src/memory.asm:133..145` (ANS §6.2.2000 citation + §3.3.3.6 survival guarantee + WORD-writes-at-HERE+1..HERE+32 explanation + Story 13.5.4 / TD-6 closure attribution)
- **PAD_OFFSET constant** — `src/constants.asm:44` (`PAD_OFFSET EQU 84`)
- **`/PAD` ENVIRONMENT? entry** — `src/system.asm:458..460` (returns `( 84 -1 )`)
- **WORD output writes** — `src/strings.asm:67..150` (counted-string at HERE+1..HERE+1+u, count ≤ 31 per F_LENMASK)
- **Story-13.5.1 ALLOTed-buffer pattern usage** — `Makefile` REPL tests 944..948 area (probes p1..p5; B45/B46/B47)
- **Makefile test section** — line 102..onwards (`test-repl: $(TARGET)` recipe); pointer comment lands here
- **MOVE word (not CMOVE)** — `src/memory.asm:292` (per Story 13.5.6 run-1 / `13.5-6-…md:798`)
- **Architecture B.1 spec** — `_bmad-output/planning-artifacts/architecture.md:248..254` (§"B.1 — `PAD` as canonical transient-buffer for tests")
- **Architecture probe-authoring discipline** — `_bmad-output/planning-artifacts/architecture.md:445..454` (§"Process Patterns (Phase-3-specific)")
- **Architecture B.1 verdict criterion** — `_bmad-output/planning-artifacts/architecture.md:265` (§"Verdict-criterion meta-pattern (all four)")
- **Architecture concrete examples** — `_bmad-output/planning-artifacts/architecture.md:561..579` (Good `T-PROBE-PAD` + Bad `T-PROBE-HERE`)
- **Epics 14.1 spec** — `_bmad-output/planning-artifacts/epics.md:307..327` (Story 14.1 ACs #1..#9)
- **Epic 14 shape** — `_bmad-output/planning-artifacts/epics.md:227..246` (Epic 14 lead-in cluster)

### Standards citations

- **ANS Forth 1994 §6.2.2000 PAD** ( -- c-addr ) — c-addr is the address of a transient region that can be used to hold data for intermediate processing.
- **ANS Forth 1994 §3.3.3.6** — PAD survives "the application's parsing of any one space-delimited name".
- **ANS Forth 1994 §3.2.6 ENVIRONMENT?** — `/PAD` query implies PAD-the-word's existence per the `( 84 -1 )` return.
- **DPANS94 §6.1.1900 MOVE** — antforth implements MOVE (not CMOVE); the doc's example uses MOVE for runnability.
- **DPANS94 §6.2.0945 CMOVE** — antforth does NOT implement CMOVE; cite as the Story-13.5.6 word-existence-pre-flight motivating example.

### Standing-commitment context (S1..S12)

Per Epic-13.5 retro 2026-05-07, all 12 standing commitments held across the retro and were codified as NFR-P3-22..33 in the Phase-3 PRD. For Story 14.1:
- **S1 — adversarial review fresh-context external.** Story 14.1 ACs do NOT enumerate "trigger an adversarial review pass" or equivalent; PD-1 enforcer (`<critical>` block in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml:21+` from Story 13.5.0) holds. This is structurally enforced — see `feedback_adversarial_review.md` per the user's MEMORY.md.
- **S2 — REPL-piped tests as default.** Story 14.1 is doc-only; no new tests required. The doc itself documents the S2 / S12 conventions for future probe authors.
- **S5 — PARTIAL → HALT.** AC #7 (Task 4.6), AC #8 (Task 5.1..5.2), AC #9 (Task 5.3) all carry HALT discipline.
- **S8 — no "pre-existing" discharge for correctness defects.** Story 14.1 closes a documentation gap (B.1 carry-forward), not a correctness defect; S8 not directly engaged.
- **S9 — per-story hardware smoke.** Story 14.1 is exempt + documented (AC #8 + Task 6.1).
- **S10 — workflow > memory > prompt.** `tests/README.md` is the structural enforcement surface for probe authors per CCD-P3-2 (architecture §"Workflow-file enforcement surface" line 208).
- **S11 — version-surface audit at tag-applicable close-out.** Story 14.1 is not tag-applicable per Epic 14 §"Shape" ("Tag-applicable close-out (S11 audit) on Ant's call — banner-only point-release valid but optional").
- **S12 — hardware-typed probe authoring discipline.** AC #6 — `tests/README.md` references S12 directly so probe authors find the full discipline in one place.

### Three buffer classes — full reference for Task 2.4

The `tests/README.md` selection rubric covers these three classes (cite back to architecture §"Probe transient-buffer choice" line 450..454 — drafter quotes or paraphrases):

| Class | Lifetime | Word | When |
|---|---|---|---|
| **One-shot transient** | Survives a single space-delimited parse step | `PAD` | Default for any probe needing scratch that lives across exactly one parse step (e.g., `S" hi" PAD SWAP MOVE PAD 2 TYPE`) |
| **Cross-parse named buffer** | Survives across multiple parse steps / REPL lines | `CREATE B45 32 ALLOT` (or similar) | Probes spanning multiple lines / multiple parse steps; canonical Phase-2 application is Story-13.5.1's `B45`/`B46`/`B47` in `Makefile` REPL tests 944..948 |
| **Never near HERE** | (No valid use for user data) | — | Anti-pattern: `HERE 64 ERASE  S" hello" HERE SWAP CMOVE  HERE C@ 'h' =` returns garbage, not `'h'`, because `S"` writes at HERE+1.. and clobbers the prior `ERASE` zeros / the prior parse step's data |

### Pre-edit baseline reconciliation — documentation-drift note

Per `13.5-6-…md` Task 2 (Documentation-drift reconciliation, Epic-13.5 close-out), the Phase-3 PRD + architecture + epics docs **all cite 24,996 bytes** as the post-Epic-13.5 baseline. The actual current build at HEAD `6599d73` (the v2.0.0 banner-bump commit) is **24,995 bytes** — 1 byte less than the Epic-13.5-close figure. This is consistent with the v2.0.0 banner-bump commit (`bump version banner to v2.0.0 and update README`) reducing the banner string by 1 byte (likely "v1.12.0" → "v2.0.0" — 7 chars → 6 chars).

This reconciliation is **not a Story-14.1 regression** — it's an illustrative inheritance-drift artefact carried from Story 13.5.6's close. Per Lesson 13.5-F (Story 13.5.5 close-out doc-drift; the motivating incident for B.3's re-`wc -c` task), Story 14.1's Task 1.1 / 1.2 re-`wc -c`s directly rather than inheriting any prior story's reported number. The 24,995-byte figure is the binding pre-edit baseline for AC #8.

### Project Structure Notes

- **No new architectural surface.** Story 14.1 adds one new doc file (`tests/README.md`) and modifies one existing file (`Makefile`). Per `architecture.md` §"Project Structure & Boundaries", the kernel boundary is frozen for Phase 3 — Story 14.1 does not touch any `src/*.asm` file.
- **Documentation boundary alignment.** Per `architecture.md` §"Documentation boundary": "**Test-author guidance** (`tests/README.md`, NEW) — single source of truth for probe-authoring conventions (PAD-as-canonical, S12 lints)". Story 14.1 lands this artefact verbatim per the boundary spec.
- **Naming and file path.** Per `architecture.md` §"Phase-3 File-Touch Surface": `tests/README.md` (project root's tests/ directory). Lower-case `tests/` (not `Tests/`); standard `README.md` capitalisation.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md:227..246`] Epic 14: Phase-3 Process Foundation — lead-in cluster B.1..B.5
- [Source: `_bmad-output/planning-artifacts/epics.md:307..327`] Story 14.1 ACs #1..#9 verbatim
- [Source: `_bmad-output/planning-artifacts/prd.md:56`] FR-P3-11 (B.1) PAD canonical doc
- [Source: `_bmad-output/planning-artifacts/prd.md:62`] FR-P3-15 verdict-criterion meta-pattern
- [Source: `_bmad-output/planning-artifacts/prd.md:125`] NFR-P3-33 (S12 hardware-typed probe discipline)
- [Source: `_bmad-output/planning-artifacts/architecture.md:248..254`] B.1-D1 architectural decision
- [Source: `_bmad-output/planning-artifacts/architecture.md:445..454`] Probe-authoring discipline + transient-buffer-choice patterns
- [Source: `_bmad-output/planning-artifacts/architecture.md:561..579`] Concrete examples — Good T-PROBE-PAD; Bad T-PROBE-HERE
- [Source: `_bmad-output/planning-artifacts/architecture.md:265`] B.1 verdict criterion
- [Source: `_bmad-output/implementation-artifacts/13.5-1-td-1-td-2-td-4-r-w-per-fcb-dirty-flag.md:650, :729, :749`] Story-13.5.1 S"-vs-HERE collision narrative + ALLOTed buffer fix
- [Source: `_bmad-output/implementation-artifacts/13.5-4-td-6-pad-here-cross-line-correctness.md:34..46`] Story-13.5.4 PAD structural-fact pair (`/PAD ENVIRONMENT?` ≠ PAD-word-existence; pad-at-HERE+84 satisfies §3.3.3.6)
- [Source: `_bmad-output/implementation-artifacts/13-6-epic-13-fs-stress-bdos-audit-and-antforth-2-0-release-gate-ccd-4.md:1192`] Story-13.6 hardware finding F-9 (HERE-as-cross-line-buffer corruption on real CP/M)
- [Source: `_bmad-output/implementation-artifacts/13.5-6-epic-13-5-close-out-gate-and-antforth-2-0-tag.md:798`] Story-13.5.6 run-1 CMOVE-vs-MOVE word-existence-pre-flight motivating example
- [Source: `_bmad-output/implementation-artifacts/13.5-6-epic-13-5-close-out-gate-and-antforth-2-0-tag.md:792`] Story-13.5.6 hardware Task 5 line 14 — `S" hi" PAD SWAP MOVE PAD 2 TYPE → hi` PASS evidence
- [Source: `src/memory.asm:133..156`] PAD comment block + DEFCODE + body
- [Source: `src/constants.asm:44`] PAD_OFFSET EQU 84
- [Source: `src/system.asm:458..460`] `/PAD` ENVIRONMENT? entry
- [Source: `src/strings.asm:67..150`] WORD output at HERE+1..HERE+1+u
- [Source: `Makefile:102..` ] test-repl recipe (target site for pointer comment)
- [Source: `docs/PHASE-3-CARRY-FORWARD.md`] B.1 status row (target for Task 7.1 `✅ Done` update)
- [Source: ANS Forth 1994 §6.2.2000] PAD canonical definition
- [Source: ANS Forth 1994 §3.3.3.6] PAD single-parse survival guarantee
- [Source: ANS Forth 1994 §3.2.6] `/PAD` ENVIRONMENT? query implication
- [Source: ANS Forth 1994 §6.1.1900] MOVE (antforth's implemented variant)
- [Source: DPANS94 §6.2.0945] CMOVE (antforth does NOT implement)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context) — dev-pass 2026-05-08.

### Debug Log References

- Pre-edit `make test-repl` output: `/tmp/14-1-pre-edit.out` (973 PASS / 0 FAIL).
- Post-edit `make test-repl` output: `/tmp/14-1-post-edit.out` (973 PASS / 0 FAIL).

### Completion Notes List

**AC walk-through at story-close (S5 HALT-on-PARTIAL discipline):**

| AC | Verdict | Evidence |
|---|---|---|
| AC #1 — `tests/README.md` exists | PASS | `ls tests/README.md` → 277 lines; pre-edit `ls` returned "No such file or directory" |
| AC #2 — Canonical PAD section | PASS | `tests/README.md` § 1; cites ANS §6.2.2000 + §3.3.3.6 + `src/memory.asm:147` + `src/constants.asm:44` + `src/system.asm:458..460`; idiom `S" hi" PAD SWAP MOVE PAD 2 TYPE → hi` (Story 13.5.6 hardware Task 5 line 14 PASS) |
| AC #3 — HERE-collision history | PASS | `tests/README.md` § 2; cites Story-13.5.1 (`:650, :729, :749`); Story-13.6 F-9 (`:1192`); Story-13.5.4 (`:34..46`); explains WORD-writes-at-HERE+0..HERE+31 mechanism + HERE-volatility structural rationale |
| AC #4 — Three buffer-class rubric | PASS | `tests/README.md` § 3; PAD / ALLOTed-named / never-near-HERE table + per-class example. ALLOTed example uses Story 13.5.1 B45 shape verbatim from Makefile tests 944..948 |
| AC #5 — Makefile pointer comment | PASS | `Makefile:102` — `# See tests/README.md for probe-authoring conventions (PAD-as-canonical-transient-buffer; S12 hardware-typed-probe lints)` |
| AC #6 — S12 reference inline | PASS | `tests/README.md` § 4; (a) word-existence pre-flight cites Story-13.5.6 CMOVE-vs-MOVE incident; (b) TIB-128 line-length lint with `awk 'length > 128'` mechanical check; cross-refs `architecture.md` §"Probe-authoring discipline (S12 / NFR-P3-33)" |
| AC #7 — Verdict criteria 5/5 PASS | PASS | (a) `\bPAD\b` → 10+ matches; (b) `tests/README\.md` in Makefile → 1 match at `:102`; (c) `ls tests/README.md` → exists; (d) S12/TIB-128/hardware-typed → 8 matches; (e) B45/B46/B47/ALLOT → 11 matches |
| AC #8 — Binary delta = 0 | PASS | antforth.com 24,995 → 24,995 (Δ=0); antforth_filesanity.com 26,460 → 26,460 (Δ=0). S9 exempt + documented (this row + Task 6.1) |
| AC #9 — `make test-repl` 973 PASS / 0 FAIL | PASS | Pre-edit: 973 / 0; post-edit: 973 / 0. `make test`: 0 errors. `make test-file-sanity`: PASS. |

**No HALT triggered.** No sibling-story spawn anti-pattern (`ls _bmad-output/implementation-artifacts/14-1-1*` returned empty).

**S9 hardware-smoke disposition:** **S9 exempt** — zero binary delta (doc + Makefile-comment only). Per `architecture.md` §"Hardware-smoke cadence (S9 / NFR-P3-7)" — *"Zero-binary-delta stories (B.1–B.5 doc/template-only) document their S9 exemption explicitly in the story's verdict table — never silently skipped."* Binary delta verified zero in Tasks 5.1 / 5.2; exemption recorded explicitly here per NFR-P3-7.

**Standing-commitment hold (S1..S12 subset relevant to 14.1):**

- **S1 (in-pass adversarial review removed)** — ACs do not enumerate adversarial review; PD-1 `<critical>` enforcer in `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml` holds. Adversarial review runs separately via `/CR` in fresh context.
- **S2 (REPL-piped tests as default)** — story is doc-only; no new tests authored. The doc itself documents the S2 / S12 conventions for future probe authors.
- **S5 (PARTIAL → HALT)** — All 9 ACs PASS at story-close; no HALT triggered (AC walk-through above). Tasks 4.6, 5.3, 6.1, 7.1 carried explicit HALT discipline.
- **S8 (no "pre-existing" discharge for correctness defects)** — Story 14.1 closes a documentation gap (B.1 carry-forward), not a correctness defect; S8 not directly engaged.
- **S9 (per-story hardware smoke)** — Exempt + documented (this row + Task 6.1).
- **S10 (workflow > memory > prompt)** — `tests/README.md` is the structural enforcement surface for probe authors per CCD-P3-2 / `architecture.md` §"Workflow-file enforcement surface". Discipline lives in the file colocated with the tests, not in a memory entry or conversation-only prompt.
- **S11 (version-surface audit)** — Story 14.1 is **not** tag-applicable per `epics.md` Epic 14 §"Shape" ("Tag-applicable close-out (S11 audit) on Ant's call — banner-only point-release valid but optional"). No version-surface change in this dev-pass.
- **S12 (hardware-typed probe authoring discipline)** — Referenced inline in `tests/README.md` § 4 per AC #6; the doc itself **is** the canonical S12 reference for probe authors.

**Documentation-drift reconciliation (Lesson 13.5-F / B.3):** Documented Epic-13.5-close binary was 24,996 bytes (per `13.5-6-…md` Task 11 / `epics.md` AC8 / `architecture.md` §"Per-story binary delta envelopes"); actual current build at HEAD `6599d73` (the v2.0.0 banner-bump commit, `bump version banner to v2.0.0 and update README`) is **24,995 bytes** — 1 byte less, attributable to the banner string shrinking (likely "v1.12.0" → "v2.0.0", 7 chars → 6 chars). Filesanity binary similarly drifted from documented 26,461 to actual 26,460. **This is not a Story-14.1 regression.** It is the inheritance-drift artefact carried from Story 13.5.6's close, illustrating B.3's "never inherit the prior story's reported number" enforcement. Re-`wc -c` was performed pre-edit per Lesson 13.5-F; the 24,995-byte figure is the binding pre-edit baseline for AC #8.

**Architecture-doc figure-drift note (PD-2 / B.4 territory):** `architecture.md` §"Concrete Examples" line 561..569 shows the "Good — probe transient buffer" example using `CMOVE`, but antforth implements `MOVE` (`src/memory.asm:292`, ANS §6.1.1900) and not `CMOVE` (DPANS94 §6.2.0945). Per Story 13.5.6 run-1 incident (`13.5-6-…md:798`), `CMOVE` is the canonical S12 word-existence-pre-flight motivating example. `tests/README.md`'s § 1 canonical idiom uses `MOVE` for runnability. The architecture-doc example is left as-is in this dev-pass (out of 14.1's scope per `architecture.md` §"B.1-D1" — Story 14.1 lands the test-author-facing README, not architecture-doc edits); B.4 / Story 14.4's figure-drift `<critical>` block, when it lands, is the structural enforcement surface that would catch this kind of slip going forward. Surfacing this here per S8 — it's a documentation defect, not a correctness defect, but it is named explicitly so it does not silently inherit forward.

### File List

| Path | Status | Note |
|---|---|---|
| `tests/README.md` | NEW | Test-author probe-authoring conventions (PAD-canonical, HERE-collision mechanism via WORD-clobber-on-INTERPRET, three buffer classes, S12 discipline). Review fix-pass corrected H-1 (S"-vs-WORD attribution), H-2 (anti-pattern as multi-REPL-line), H-3 (F_LENMASK is dictionary-header cap, not a WORD cap). |
| `Makefile` | modified | One-line `# See tests/README.md …` pointer comment inserted at line 102 above `test-repl: $(TARGET)` |
| `docs/PHASE-3-CARRY-FORWARD.md` | NEW (working-tree-only before story; never committed in any prior commit, so git status shows `??`) | B.1 row added to § "Status Tracking" with `✅ Done` + closure note |
| `_bmad-output/implementation-artifacts/sprint-status.yaml` | modified | `14-1-…` flipped: `ready-for-dev` → `in-progress` (dev-pass start) → `review` (dev-pass close) |
| `_bmad-output/implementation-artifacts/14-1-pad-documented-as-canonical-transient-buffer-for-test-authors.md` | modified | Tasks/Subtasks checkmarks; Dev Agent Record populated; Status flipped to `review` |

### Change Log

| Date | Change | Author |
|---|---|---|
| 2026-05-08 | Authored `tests/README.md` (≈280 lines initial; 303 lines post-review-fix-pass, 4 sections: Canonical PAD; HERE-collision mechanism; Buffer-class rubric; S12 probe-authoring discipline). Inserted one-line `# See tests/README.md for probe-authoring conventions (PAD-as-canonical-transient-buffer; S12 hardware-typed-probe lints)` pointer comment in `Makefile` immediately above the `test-repl: $(TARGET)` recipe (line 102). Updated `docs/PHASE-3-CARRY-FORWARD.md` § "Status Tracking" — added B.1 row marked `✅ Done` with closure note citing Story 14.1 / 2026-05-08 + verdict criteria 5/5 PASS. Binary delta: 0 bytes (antforth.com 24,995 → 24,995; antforth_filesanity.com 26,460 → 26,460). `make test-repl` regression: 973 PASS / 0 FAIL pre-edit and post-edit (zero test-count movement). S9 exempt + documented per NFR-P3-7. Closes Phase-3 carry-forward item B.1 (Epic-12 retro Action Item A1; Epic-13.5 retro Action Item A2). | claude-opus-4-7 (1M context) |
| 2026-05-08 | **Review fix-pass** (CR command, fresh-context adversarial review). Fixed three HIGH and two MEDIUM findings against `tests/README.md` and the story records: H-1 — §2 mechanism narrative misattributed cross-line clobber to S"; corrected to attribute clobber to `WORD` invoked by `INTERPRET` on every token (`src/outer_interpreter.asm:178..217`), with explicit note that antforth's S" interpret-mode uses a separate `s_quote_buf` (`src/strings.asm:739, :787`) and does **not** write near `HERE`. Section title shortened to "Why not `HERE`". H-2 — anti-pattern recast from a colon body (where compile-time S" inlines the literal and runtime never calls WORD, masking the bug) to an interpreted multi-REPL-line sequence that actually demonstrates the failure. H-3 — corrected the PAD survival proof: `WORD` does **not** clamp at `F_LENMASK` (that mask is the dictionary-header name-length cap, applied in `src/compiler.asm:203..207` when a CREATEd name is stored, not in `WORD`); the realistic upper bound is TIB-128, so a pathologically long single token (≥ 84 chars) would corrupt PAD — never expected in normal Forth source, and the reason §4(b)'s TIB-128 lint exists. M-1 — File List row for `docs/PHASE-3-CARRY-FORWARD.md` updated to "NEW (working-tree-only before story)" matching git's `??` status. M-2 — Task 4 records corrected (line counts and match counts re-greped post-fix). Verdict criteria all still PASS (PAD: 31 matches; Makefile pointer: 1 at :102; ls README: 303 lines; S12 set: 8; ALLOT set: 14). Binary delta still 0 (antforth.com 24,995; antforth_filesanity.com 26,460). `make test-repl` post-fix-pass: 973 PASS / 0 FAIL — zero regression. | claude-opus-4-7 (1M context) — review fix-pass via /CR |
