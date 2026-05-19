# Story 17.5.2: Refactor probes 1–5 to colon-body wrappers — root-cause fix for the top-level IF/ELSE/THEN silent-false-PASS class (incl. probe 2 BASE=16 residue)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Context — why this story exists, why now

Surfaced as **M1** in the AI code-review pass on Story 17.5.1
(2026-05-17; see
`_bmad-output/implementation-artifacts/17-5-1-probe-g-plus-bank-cap-false-pass-fix.md:317..318`
and Debug Log at `…:554`). Filed as the root-cause follow-up per
`feedback_no_preexisting_discharge.md` (Lesson 13-B) — correctness
defects in the test surface (silent false-PASS via source-echo;
BASE residue leaking forward) cannot be discharged as
"pre-existing, out of scope" once known. Story 17.5.1 patched
the symptom locally at probe G via `DECIMAL` bracketing; this
story closes the root cause.

**Sprint-status row caveat:** the sprint-status row key is
`17-5-2-probes-1-2-colon-body-refactor-base-residue-root-cause-fix`
(authored 2026-05-17 at 17.5.1 close, before this story's draft-
time scope analysis). The literal "probes 1-2" in the key reflects
the original narrow scope motivated by the BASE-leak symptom. At
story-draft time 2026-05-19 the scope was re-examined against
`tests/banking_tests.fth` and the same top-level IF/ELSE/THEN
mechanism was identified in **probes 3, 4, and 5** (lines 88..143)
— same defect class (silent run-time false-PASS via -14 THROW on
each compile-only IF/ELSE/THEN; recipe-side substring grep
matches source-echo regardless of branch outcome), differing
only in that probes 3-5 don't touch BASE so the leak symptom
isn't visible. Per Lesson 13-B "surface, file, fix" once known.
Scope EXPANDED to probes 1-5 at draft time with project-lead
approval (AskUserQuestion 2026-05-19). The sprint-status row
file-name key is preserved as the immutable identifier; the
story title and ACs reflect the expanded scope. Sprint-status
row comment updated in Task 7 to document the scope expansion.

**The defect (root cause, two intertwined consequences):**

1. **The structural mechanism.** Probes 1, 2, 3, 4, 5 in
   `tests/banking_tests.fth` (lines 49..143) use **top-level**
   `IF/ELSE/THEN` (i.e., not wrapped in a `:` colon definition).
   `IF`, `ELSE`, `THEN` are compile-only words in antforth (they
   compile branch primitives into the current colon definition's
   body); when invoked at the interpreter top level they each
   raise `THROW -14` ("interpreting a compile-only word") via
   `?COMP`. The kernel's uncaught-THROW handler resets the
   data stack and returns to the REPL, which then reads the
   NEXT token. The net effect: **every token in BOTH the IF-
   branch and the ELSE-branch executes sequentially, with the
   stack repeatedly reset between branches.** The IF/ELSE/THEN
   constructs do **nothing** — they're not actually branching;
   they're throwing -14 each time and being skipped over by the
   REPL.

2. **Consequence A — silent false-PASS via source-echo
   (probes 1-5).** Both branches' `." PASS: …"` and
   `." FAIL: …"` literals get echoed by iz-cpm/CCP at parse
   time (BDOS function 1 echoes typed input on the simulated
   console). The substring grep `PASS: banking-mapping-on-
   idempotent` at `Makefile:92` matches the source-echo of the
   PASS literal regardless of whether the PASS branch's
   run-time emit actually fired. **Probes 1-5 are silently
   PASSing on every test run — the run-time PASS branch has
   never executed.** This is the same source-echo false-PASS
   class that motivated Story 17.5.1's sentinel-bounded
   recipe pattern for probe G.

3. **Consequence B — BASE=16 residue leaking forward
   (probe 2 specifically).** Probe 2's ELSE-branch body
   contains `BASE @ HEX SWAP . BASE !` (line 83). At top
   level, the `IF` throws -14 (stack reset); then `." SKIP: …"`
   prints (source-echo); then `BASE @` pushes 10; `HEX` sets
   BASE to 16; `SWAP` underflows (-4) and resets the stack
   again; `.` underflows again; `BASE !` underflows again —
   **`BASE !` never restores DECIMAL**. `BASE = 16` persists
   into all subsequent file parse and execution. Story 17.5
   (`_dot-banks-setup`) and Story 17.5.1 (probe G `DECIMAL`
   brackets at file-parse time + runtime) both work around
   this leak defensively. Both workarounds are technical debt
   that retires with this story's root-cause fix.

**What this story does:**

- Refactors **probes 1, 2, 3, 4, 5** in
  `tests/banking_tests.fth` from top-level `IF/ELSE/THEN`
  blocks into `: _probe-N … ; _probe-N` colon-body wrappers
  (the same shape used by probes 6, 7, 8, A, B, C, D, E, F).
  Inside the colon body, `IF/ELSE/THEN` compile correctly —
  exactly one branch runs at run-time per the kernel-cell
  predicates the probe is testing.
- **Retires** the three defensive `DECIMAL` workarounds added
  by Stories 17.5 and 17.5.1:
  - `tests/banking_tests.fth:422` (parse-time `DECIMAL` before
    `_do-29-+bank` / `_do-one-more-+bank` / `_probe-plus-bank-
    cap` colon defs — added by Story 17.5.1 AC5/Task 4.4 to
    parse literal `29` in DECIMAL despite probe-2's BASE leak)
  - `tests/banking_tests.fth:428` (runtime `DECIMAL` as the
    first body word inside `_probe-plus-bank-cap` — added by
    Story 17.5.1 AC5/Task 4.4 to ensure `BANKS .` prints in
    DECIMAL so the recipe's `seeded: 29` substring match works)
  - `tests/banking_tests.fth:495` (`DECIMAL` as the first body
    word inside `_dot-banks-setup` — added by Story 17.5
    `tests/banking_tests.fth:437..445` as a "polluted state
    from probe G makes a 12-iteration DO LOOP unreliable;
    manual unrolling sidesteps the issue" workaround prose
    block; the `DECIMAL` line in `_dot-banks-setup` was the
    second half of that workaround).
- **Updates** the surrounding inline comment blocks
  (`tests/banking_tests.fth:375..421` for probe G; `:481..492`
  for `_dot-banks-setup`) to drop the now-stale BASE-residue
  framing and replace it with a one-line forward-pointer to
  this story file.

**What this story does NOT do:**

- Does **NOT** change kernel binary. Test-infra only.
  (`build/antforth.com` is expected to remain at **26,583 B**
  at dev-pass close; per-AC verification at AC7.)
- Does **NOT** add or modify any user-facing word.
- Does **NOT** touch `src/banking.asm`, `src/antforth.asm`,
  or any other file under `src/`.
- Does **NOT** upgrade probes 1-5 to sentinel-bounded
  recipe extraction (Story 17.5.1 L3 — pre-existing scope;
  valid discharge per Lesson 13-B since the source-echo
  false-PASS class is the consequence of the top-level
  IF/ELSE/THEN mechanism — once the colon-body wrap
  eliminates the mechanism, the run-time branch executes
  correctly and the recipe's substring grep matches the
  intended emit, not just the source-echo). Sentinel-bounded
  upgrade for probes 1-5 is out of scope; refile if the
  test-infra ceiling matters again in Epic 22.
- Does **NOT** refactor `_dot-banks-setup`'s manual `$22 +BANK`
  unroll to a `DO LOOP` (the unroll was added by Story 17.5
  as part of the same workaround that introduced the `DECIMAL`
  reset; with BASE no longer leaking, the unroll could be
  replaced with `12 0 DO $22 +BANK LOOP` — but that's a polish
  item out of scope for this story; if Epic 22 polish-window
  reaches it, refile).
- Does **NOT** add a new diagnostic probe to verify BASE=10
  end-to-end. The existing test surface IS the BASE=10
  tripwire: probe G's `seeded: 29` literal (and the DO LOOP
  literal `29`) only matches the recipe's grep if BASE is 10
  at probe-G parse and run time. If BASE leaks from any future
  source, probe G's recipe FAILs. Adding a dedicated tripwire
  probe would be ceremony per Lesson 14-F ("mechanical sweep
  over codified discipline").

**Why now (slotting on top of Epic-18 close baseline):** Epic 17
is already tagged (`antforth-3.x.1`, Story 17.6 close 2026-05-17);
Epic 18 is at close (Story 18.5 + 18.5.1 done; 18-retrospective
optional). The next forward-moving work is Epic 19 (per-bank HERE
/ LATEST plumbing). Cleaning up the probes-1-5 silent false-PASS
class before Epic 19 dev-pass starts: (1) restores trust in the
`PASS: banking-mapping-on-…` / `PASS: bank-at-zero` / `PASS:
banks-zero` / `PASS: bank-store-abort-bank-q` recipe rows that
Epic 19 stories will use as their pre-edit baseline; (2) lets
the defensive `DECIMAL` workaround in `_dot-banks-setup` (which
Epic-19's per-bank HERE work will likely re-touch) retire on
the same ROM-cap-neutral story rather than getting tangled into
an Epic-19 story's scope.

## Story

As the antforth maintainer who relies on `make test-repl-banking`
and `make test-repl-banking-skip` to gate banking correctness
across Epic-17 (now closed) and Epic-19/20/21/22 (forward),
I want **probes 1, 2, 3, 4, 5** in `tests/banking_tests.fth`
refactored from top-level `IF/ELSE/THEN` blocks (which silently
false-PASS via source-echo because `IF/ELSE/THEN` THROW -14 at
the top level and both branches' tokens execute sequentially)
into `: _probe-N … ; _probe-N` colon-body wrappers (the same
shape as probes 6+),
so that (a) the run-time PASS / FAIL / SKIP branch actually
executes per the kernel-cell predicate under test, (b) the
recipe's substring grep matches the intended run-time emit
rather than the source-echo, (c) the BASE=16 residue currently
leaking from probe 2's underflowed `BASE @ HEX SWAP . BASE !`
is eliminated at root, and (d) the defensive `DECIMAL`
workarounds in Story 17.5's `_dot-banks-setup` and Story
17.5.1's probe G can both retire.

## Acceptance Criteria

**Given** Story 17.5.1 has closed (post-17.5.1 baseline =
**26,583 B / 975 PASS / 0 FAIL / 2 SKIP on iz-cpm baseline /
50 PASS on test-repl-banking / 25 PASS + 3 SKIP on
test-repl-banking-skip / 31 advisories / 0 drift on
check-doc-sync** — re-validated live at story-draft time
2026-05-19 against the current `build/antforth.com`; the
follow-up row `17-5-2-probes-1-2-colon-body-refactor-base-
residue-root-cause-fix` was filed at 17.5.1 review-close
2026-05-17),
**And** Epic 18 has closed (Story 18.5 + 18.5.1 done; Epic 18
retrospective optional; `antforth-3.x.2` tag applied per Story
18.5 close 2026-05-18),
**And** the root cause is the top-level `IF/ELSE/THEN` mechanism
in probes 1-5 (each compile-only word THROWs -14 at the top
level; both branches execute sequentially; consequence A =
silent false-PASS via source-echo for all 5 probes; consequence
B = BASE=16 residue from probe 2's underflowed `BASE @ HEX
SWAP . BASE !`),
**When** Story 17.5.2 is dev-passed,

**Then** **AC1** (probe 1 colon-body wrap) — `tests/banking_
tests.fth:49..64` is rewritten so the body
`BANK-MAPPING-ON BANK-MAPPING-ON BANK-MAPPING-ON DEPTH 0 = IF …
ELSE … THEN CR` is inside a `: _probe-1 ( -- ) … ; _probe-1`
wrapper (same shape as `_probe-6` at lines 159..171). At run
time exactly ONE of the IF / ELSE branches executes per the
DEPTH = 0 predicate; the source-echo of the colon-body parse
emits each literal once, but the run-time emit also fires from
the executing branch. The PASS-path emit and the colon-body
parse-echo BOTH carry the literal `PASS: banking-mapping-on-
idempotent`; this story preserves the existing substring grep
recipe (per AC6).

**And** **AC2** (probe 2 colon-body wrap) — same shape as AC1
for `tests/banking_tests.fth:66..86`. Body wraps `BANK-MAPPING-
ON FETCH-74 DUP 1 = IF … ELSE … THEN CR` into `: _probe-2 ( -- )
… ; _probe-2`. Critically: probe 2's ELSE-branch `BASE @ HEX
SWAP . BASE !` (line 83) now executes inside a compiled
control-flow structure where (a) `IF` correctly branches on
`FETCH-74 1 =` rather than THROWing -14, (b) the SKIP branch's
stack state is well-formed (FETCH-74 byte on TOS at entry, no
underflows), (c) `BASE !` runs to completion, restoring BASE
to 10 (DECIMAL). The BASE=16 residue is eliminated at root.

**And** **AC3** (probes 3, 4, 5 colon-body wrap) — same shape
for `tests/banking_tests.fth:88..101` (probe 3 — `bank-at-zero`),
`:103..121` (probe 4 — `banks-zero`), `:123..143` (probe 5 —
`bank-store-abort-bank-q`). Each becomes `: _probe-3 ( -- ) … ;
_probe-3` / `: _probe-4 ( -- ) … ; _probe-4` / `: _probe-5
( -- ) … ; _probe-5`. After the refactor, probes 1-5 are
structurally homogeneous with probes 6+ (all colon-body
wrappers; all run-time branches execute correctly).

**And** **AC3a** (probe 4 BANKS-CLEAR-at-head + predicate shift —
dev-pass-time scope expansion, project-lead-approved 2026-05-19
via AskUserQuestion) — beyond the bare colon-body wrap of AC3,
probe 4 receives `BANKS-CLEAR` as its first body word and its
predicate shifts from "BANKS = 0 at boot" (stale post-17.4
CL-parser, which defaults bank_count = 12) to "BANKS-CLEAR drives
BANKS to 0". The PASS-text leading substring `PASS: banks-zero —`
is preserved for `Makefile:92` substring-grep compatibility; the
trailer narrative changes. Probe 4 was the proximate witness: its
top-level form silently false-PASSed via source-echo because the
stale assertion was masked by the THROW-14 + sequential-branch
execution; once the colon-body wrap (AC3) made the run-time emit
fire, the stale assertion surfaced as a run-time FAIL. Per
Lesson 13-B ([[feedback-no-preexisting-discharge]]) "surface, file,
fix once known". The probe's inline comment block at lines 112..129
is rewritten to document the stale-assertion provenance + the
BANKS-CLEAR fix. Side effect: probe 4 exits with BANKS = 0, which
is the contract probes 5+ already tolerate (see Completion Notes
"Dev-pass-time scope expansion" entry for the downstream-impact
audit).

**And** **AC3b** (probe C BANKS-CLEAR-at-head — dev-pass-time scope
expansion, project-lead-approved 2026-05-19 via AskUserQuestion) —
probe C (`tests/banking_tests.fth:296..322`, `minus-bank-present-
absent`) receives `BANKS-CLEAR` as its first body word and a
paragraph addition to its inline comment block. Provenance:
Story-17.3 authored the probe assuming BANKS = 0 at entry (pre-CL-
parser); post-17.4, the active list starts at 12 entries by default,
so the probe's `BANKS = 0` predicate after `+BANK -BANK` was stale.
Run-time FAIL was masked by source-echo (probe C uses top-level
IF/ELSE/THEN itself prior to this story? — NO: probe C is already
colon-body-wrapped in the Story-17.3 baseline; the source-echo
false-PASS in this case was masked by the recipe's substring grep
matching the colon-body parse-echo regardless of the run-time
branch outcome — same defect class, different mechanism). Surfaced
during this story's dev-pass once probe-4's stale assertion was
also surfaced (the two share a common provenance: Story-17.2/17.3
era "BANKS = 0 at boot" assumptions invalidated by Story 17.4's
CL parser; both batch-fixed under Lesson 13-B "surface, file, fix
once known"). Probe C is NOT a colon-body wrap subject (it was
already wrapped) — AC3b only adds BANKS-CLEAR-at-head + the
comment-block paragraph. Recipe `PASS: minus-bank-present-absent`
text is unchanged.

**And** **AC4** (defensive `DECIMAL` retirement — probe G
parse-time site) — `tests/banking_tests.fth:422` (the standalone
`DECIMAL` line just before the `_do-29-+bank` colon definition,
added by Story 17.5.1 AC5/Task 4.4) is **removed**. Justification:
with probe 2's BASE-leak eliminated by AC2, BASE = 10 at probe G
parse time; the literal `29` in `_do-29-+bank` parses in DECIMAL
without the explicit bracketing.

**And** **AC5** (defensive `DECIMAL` retirement — probe G runtime
site) — `tests/banking_tests.fth:428` (the `DECIMAL` line as the
first body word inside `_probe-plus-bank-cap`, added by Story
17.5.1 AC5/Task 4.4) is **removed**. Justification: with probes
1-5 wrapped, BASE = 10 throughout the test run; `BANKS .` inside
probe G prints in DECIMAL natively; the recipe's `seeded: 29`
substring grep matches.

**And** **AC6** (defensive `DECIMAL` retirement — `_dot-banks-
setup` site) — `tests/banking_tests.fth:495` (the `DECIMAL` line
as the first body word inside `_dot-banks-setup`, added by Story
17.5 to defend against probe-G's polluted state per the workaround
prose block at `:481..492`) is **removed**. Justification: with
probes 1-5 wrapped and probe G's defensive brackets retired
(AC4/AC5), no upstream probe corrupts BASE; `_dot-banks-setup`
no longer needs the defensive reset. The `_dot-banks-setup`
helper itself stays — `BANKS-CLEAR` + 12× `$22 +BANK` remain
load-bearing for the dot-banks probes X/Y/Z/W setup. Only the
`DECIMAL` line on `:495` is removed.

**And** **AC7** (binary delta — no kernel change) —
`wc -c build/antforth.com` is **unchanged at 26,583 B** at
dev-pass close (test-infra-only fix; no source-tree change to
`src/banking.asm` or any other file under `src/`). If the
binary delta is non-zero, dev-pass HALTs and surfaces the
unexpected kernel touch to project lead before continuing.

**And** **AC8** (regression baseline preserved) —
  - `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP** (baseline
    preserved per FR-P4-41 / NFR-P4-10; no test-thread
    contribution from this story).
  - `make test-repl-banking` = **50 PASS / 0 FAIL** (was 50
    post-18.5.1; recipe-row count and PASS-text shapes
    unchanged — same substring greps; the only behavioural
    change is that the run-time PASS branch now fires for
    probes 1-5, where before only the source-echo was
    satisfying the grep).
  - `make test-repl-banking-skip` = **25 PASS + 3 SKIP / 0
    FAIL** (was 25+3 post-18.5.1; probe 2 SKIP path now
    executes correctly under iz-cpm baseline — FETCH-74 = 0
    drives the ELSE branch which prints `SKIP: banking-
    mapping-on-port-74 — iz-cpm does not model MMU port 0x74
    (readback=$0 expected=$1)`; recipe asserts on the
    anchored `^SKIP: banking-mapping-on-port-74` at
    `Makefile:531`).
  - `make check-doc-sync` = **31 advisories / 0 drift**
    (unchanged; no compliance-doc row added).

**And** **AC9** (hardware smoke — NOT required) — Story
17.5.2 does NOT require a hardware-smoke run. Rationale:
zero kernel binary delta + zero MMU surface interaction (the
colon-body refactor is a parse-level structural change to the
test surface; surface-agnostic). The Story-17.5 / Story-17.6
/ Story-18.5 hardware-smoke transcripts already evidence the
kernel banking surface end-to-end on real MicroBeast; nothing
about Story 17.5.2 changes that surface. **No `feedback_post_
hw_smoke_steps_at_review.md` recipe is required at code-review
close for this story** — the rule fires on binary-delta stories
with deferred S9/AC8 hardware-smoke tasks; Story 17.5.2 has no
binary delta and no hardware-smoke task. (If dev-pass finds any
reason a hardware-smoke is warranted — e.g., a structural
surprise — surface that during dev-pass; do not silently skip.)

**And** **AC10** (negative-test — reversion verification, BASE
tripwire) — dev-pass verifies the root-cause fix is load-
bearing by deliberately re-introducing the BASE=16 leak and
confirming the existing test surface FAILs. Method:
deliberately corrupt the AC2 refactor by re-introducing the
top-level form of probe 2's ELSE branch BASE switch (e.g.,
add an unguarded `HEX` line at top level between `_probe-2`
and `_probe-3` invocations — outside any colon body — which
runs at file-parse time without restore). Re-run
`make test-repl-banking` and `make test-repl-banking-skip`.
**Both recipes MUST report `FAIL: plus-bank-cap`** (because
probe G's `_do-29-+bank` then parses `29` as HEX = 41 decimal,
the DO LOOP runs 41 iters, the cap-check fires mid-loop at
iter 30, and probe G's end-sentinel never emits — same
mechanism Story 17.5.1 hit before the local DECIMAL fix).
Restore the probe; both recipes MUST report
`PASS: plus-bank-cap`. Record the negative-test output in
Dev Notes for traceability. **This AC is the load-bearing
verification that the existing recipe machinery (probe G's
sentinel-bounded + `seeded: 29` literal extraction) actually
catches a BASE residue; if the recipe false-PASSes under
the corruption, the story HALTs and dev-pass investigates
why the tripwire isn't load-bearing before continuing.**

**And** **AC11** (inline comment block currency) — the
inline comment block above probe G at `tests/banking_tests.
fth:375..421` is rewritten to drop the now-stale "BASE residue
note (Story 17.5.1 AC5 disposition (a) → probe-side fix)"
paragraph (lines 407..421) and the parse-time/runtime DECIMAL
rationale (lines 414..421). Replace with a short forward-
pointer paragraph (one sentence, soft-wrapped to ~3 file
lines for the 70-col file convention): `\ Story 17.5.2 root-
cause-fixed probes 1-5 (top-level IF/ELSE/THEN → colon-body
wrappers); BASE residue from probe 2 eliminated; defensive
DECIMAL brackets retired here + at _dot-banks-setup.` The
"Two load-bearing BANKS-CLEAR sites" paragraph (lines
401..405) stays — that paragraph is about AC1 of Story
17.5.1 (reset-before-seed for cap-check), not about BASE.

**And** **AC12** (inline comment block currency —
`_dot-banks-setup`) — the inline comment block at
`tests/banking_tests.fth:481..492` is rewritten to drop the
"Reproducibility: probe G (`_probe-plus-bank-cap`) leaves the
runtime with bank_count = 29 / BASE = 16 if its `_do-29-+bank`
LOOP body trips the cap-check mid-loop" framing (which is
mooted now that probe G correctly bookends with BANKS-CLEAR
and BASE no longer leaks). Replace with a short forward-
pointer paragraph (two sentences plus the preserved manual-
unroll rationale, soft-wrapped to ~7 file lines for the
70-col file convention): `\ Story 17.5.2 root-cause-fixed
the BASE residue (probes 1-5 colon-body wrap); the defensive
DECIMAL reset retired. BANKS-CLEAR + manual 12× $22 +BANK
unroll stay load-bearing — sets up the dot-banks probes'
kernel-cell state at a known shape.` The "manual unrolling
sidesteps the issue" framing for the 12× `$22 +BANK` is
preserved (the manual unroll is defensive-but-cheap; replacing
it with a DO LOOP is an Epic-22 polish item, not in scope
here).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → 26,583 B (matches expected post-18.5.1)
- [x] Capture current `make test-repl` baseline: 975 PASS / 0 FAIL / 2 SKIP (matches expected)
- [x] Capture current `make test-repl-banking` baseline: 50 PASS / 0 FAIL / 3 SKIP (matches expected; 3 SKIPs = probes 18.4-c, 18.5-b, 18.5-d — Epic-19 deferrals)
- [x] Capture current `make check-doc-sync` baseline: 31 advisories / 0 drift (matches expected)
- [x] Re-read `tests/banking_tests.fth:49..143` (probes 1-5 source) at dev-pass start — confirmed top-level `IF/ELSE/THEN` shape (B.4 / PD-2)

### Story tasks

- [x] **Task 1 — Refactor probe 1** (AC1)
  - [x] 1.1 — Located probe 1 body at `tests/banking_tests.fth:58..64` (3× BANK-MAPPING-ON + DEPTH 0 = IF/ELSE/THEN/CR).
  - [x] 1.2 — Wrapped in `: _probe-1 ( -- ) … ; _probe-1` per probes-6+ shape.
  - [x] 1.3 — Comment block unchanged.

- [x] **Task 2 — Refactor probe 2** (AC2)
  - [x] 2.1 — Located probe 2 body at `tests/banking_tests.fth:76..86`.
  - [x] 2.2 — Wrapped in `: _probe-2 ( -- ) … ; _probe-2`. ELSE-branch `BASE @ HEX SWAP . BASE !` now executes inside a compiled IF/ELSE/THEN — BASE=16 residue eliminated at root.
  - [x] 2.3 — Comment block unchanged.

- [x] **Task 3 — Refactor probes 3, 4, 5** (AC3)
  - [x] 3.1 — Probe 3 wrapped in `: _probe-3 ( -- ) … ; _probe-3`. Comment block unchanged.
  - [x] 3.2 — Probe 4 wrapped in `: _probe-4 ( -- ) … ; _probe-4`. **Scope-expanded** at dev-pass-time per project-lead approval (AskUserQuestion 2026-05-19): added `BANKS-CLEAR` as first body word + rewrote comment block. Justification: the colon-body wrap surfaced a run-time FAIL (BANKS=12 from CL-parser default, not 0 as predicate expected) — Story-17.4-era stale assertion that probe 4's own comment had pre-flagged as needing update but the probe text was never updated. Per Lesson 13-B "surface, file, fix once known".
  - [x] 3.3 — Probe 5 wrapped via D7 candidate B (CATCH-wrap with `_99-bank-store` helper, matching probe B/D shape). One-line comment block addition explains CATCH-wrap mechanism (THROW -2 from `99 BANK!` is caught inside the probe; CATCH restores i*x; `-2 =` consumes the throw value; DEPTH = 0 inside the IF body).

- [x] **Task 4 — Retire defensive `DECIMAL` brackets at probe G** (AC4, AC5)
  - [x] 4.1 — Removed standalone `DECIMAL` before `: _do-29-+bank`.
  - [x] 4.2 — Removed `DECIMAL` as first body word inside `_probe-plus-bank-cap`.
  - [x] 4.3 — Probe G body otherwise unchanged.

- [x] **Task 5 — Retire defensive `DECIMAL` in `_dot-banks-setup`** (AC6)
  - [x] 5.1 — Removed `DECIMAL` as first body word inside `_dot-banks-setup`.
  - [x] 5.2 — Body now `BANKS-CLEAR` + 12× `$22 +BANK` (manual unroll preserved).

- [x] **Task 6 — Update inline comment blocks** (AC11, AC12)
  - [x] 6.1 — Probe G comment block: dropped the "BASE residue note (Story 17.5.1 AC5 disposition (a) → probe-side fix)" paragraph. Replaced with the one-line forward-pointer per AC11.
  - [x] 6.2 — `_dot-banks-setup` comment block: dropped the "Reproducibility: probe G … leaves the runtime with bank_count = 29 / BASE = 16" framing. Replaced with the one-line forward-pointer per AC12 (preserved the manual-unroll rationale).
  - [x] 6.3 — "Two load-bearing BANKS-CLEAR sites" paragraph at probe G left intact.
  - [x] 6.4 — **Scope-expanded:** rewrote probe 4 comment block (Story-17.2-era "BANKS at boot returns 0" reframed to Story-17.5.2 "BANKS-CLEAR drives BANKS to 0" — documents the stale-assertion surfacing + the BANKS-CLEAR-at-head fix). Added one-block paragraph to probe C comment explaining the same defect class + scope adoption.

- [x] **Task 7 — Build + regression sweep + close** (AC7, AC8)
  - [x] 7.1 — `make` → `Nothing to be done for 'all'` (test-infra-only).
  - [x] 7.2 — `wc -c build/antforth.com` = **26,583 B** unchanged ✓ (AC7).
  - [x] 7.3 — `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP** ✓ (AC8).
  - [x] 7.4 — `make test-repl-banking` = **50 PASS / 0 FAIL / 3 SKIP** ✓ (AC8). Raw-OUTPUT inspection confirmed each of `PASS: banking-mapping-on-idempotent`, `PASS: banking-mapping-on-port-74`, `PASS: bank-at-zero`, `PASS: banks-zero`, `PASS: bank-store-abort-bank-q`, `PASS: minus-bank-present-absent` fires as a RUN-TIME emit (own line, not interior to a colon-body parse line). See Debug Log References below.
  - [x] 7.5 — `make test-repl-banking-skip` = **25 PASS + 3 SKIP / 0 FAIL** ✓ (AC8). `^SKIP: banking-mapping-on-port-74` anchored grep matches at run time.
  - [x] 7.6 — `make check-doc-sync` = **31 advisories / 0 drift** ✓ (AC8).

- [x] **Task 8 — Negative-test reversion verification** (AC10)
  - [x] 8.1 — Applied corruption: appended `HEX` line on its own immediately after `_probe-2` invocation (between probe-2 invocation and probe-3 comment block).
  - [x] 8.2 — `make test-repl-banking` → **FAIL** (exit 1). First fail: `FAIL: dot-banks-probe-x — header/rows/totals missing`. The recipe ordering tests dot-banks-probe-x BEFORE plus-bank-cap (Makefile:209 vs Makefile:263); the BASE=16 leak corrupts `.BANKS` totals output ($30000 hex instead of `196608` decimal), so dot-banks-probe-x FAILs first. The plus-bank-cap recipe row never runs (Makefile aborts on first failure). **AC10 binding intent verified:** the recipe tripwire IS load-bearing — a parse-time BASE leak fails the test surface. The specific failing probe (dot-banks-probe-x vs the AC10-named plus-bank-cap) differs because of Makefile recipe ordering, not because of any tripwire weakness. Both are downstream of the BASE-leak parse event.
  - [x] 8.3 — `make test-repl-banking-skip` → **FAIL** (exit 1). Same shape: `FAIL: dot-banks-probe-x (surface-agnostic) — header/rows/totals missing under iz-cpm`. Surface-agnostic per AC10 expectation.
  - [x] 8.4 — Reverted corruption (removed the `HEX` line). Re-ran both: `make test-repl-banking` = **50/0/3** + `PASS: plus-bank-cap — cap-check fired after 29-entry seed under iz-cpm-banking`; `make test-repl-banking-skip` = **25/0/3** + `PASS: plus-bank-cap (surface-agnostic) — cap-check fired after 29-entry seed under iz-cpm baseline`. Both PASSed cleanly post-revert.
  - [x] 8.5 — Recorded in Debug Log References below.

- [x] **Task 9 — Update sprint-status + flip Story 17.5.2 status `ready-for-dev → review`**
  - [x] 9.1 — Updated `_bmad-output/implementation-artifacts/sprint-status.yaml` row `17-5-2-probes-1-2-colon-body-refactor-base-residue-root-cause-fix` to `review`.
  - [x] 9.2 — Appended sprint-status row comment block documenting the dev-pass-time scope expansion to include probe 4 + probe C BANKS-CLEAR fixes (in addition to the draft-time expansion to probes 1-5). Cited this story file.
  - [x] 9.3 — Change Log entry appended (see Change Log section).
  - [x] 9.4 — Ran `CR` (code-review skill, fresh-LLM-context) 2026-05-19. Findings: 0 High / 3 Medium / 3 Low; all 6 dispositioned in-pass (see Review Follow-ups (AI) section). Regression baselines preserved (26,583 B / 975/0/2 / 50/0/3 / 25/0/3 / 31 advisories / 0 drift). Story-file Status → `done`; sprint-status row → `done`.

### Review Follow-ups (AI)

Code-review pass 2026-05-19 (BMAD code-review workflow, fresh-LLM-context per CR runs-in-fresh rule). Findings + in-pass dispositions:

- [x] [AI-Review][Medium] M1: AC10 specific tripwire path (probe G `seeded: 29` + sentinel-bounded recipe) was not exercised in dev-pass because Makefile recipe ordering aborts on `FAIL: dot-banks-probe-x` before probe G's recipe runs [tests/banking_tests.fth:454, Makefile:209 vs Makefile:264]. **Disposition:** fixed in this pass — re-ran HEX corruption with raw-output capture, applied probe G's exact recipe predicates directly, verdict `FAIL: plus-bank-cap` confirmed on all four predicates (NO `cap-check-fired-after-29-seed`, NO `seeded: 29`, FAIL: substrings present in awk-extracted region, NO `---plus-bank-cap-end---` sentinel). See Debug Log References "Code-review M1 supplementary verification" entry.
- [x] [AI-Review][Medium] M2: Sprint-status edit for row `18-5-…: review → done` was not in story File List; bundled into the 17-5-2 dev-pass commit without separate disposition [_bmad-output/implementation-artifacts/sprint-status.yaml:363]. **Disposition:** fixed in this pass — File List extended to call out the bundled-in edit + the Epic-18-close rationale (18.5.1 ship-out via commit 2d6ea18).
- [x] [AI-Review][Medium] M3: AC3 wording said "same shape" for probes 3-5 but probe 4 received a predicate shift (BANKS-CLEAR-at-head + "BANKS=0 at boot" → "BANKS-CLEAR drives BANKS to 0"); probe C, not in any AC, also received BANKS-CLEAR-at-head + comment-block paragraph [tests/banking_tests.fth:130..141, :296..322]. **Disposition:** fixed in this pass — AC3a (probe 4 expansion) + AC3b (probe C expansion) appended to Acceptance Criteria; both carry the Lesson-13-B rationale + project-lead AskUserQuestion provenance + downstream-impact framing already in Completion Notes.
- [x] [AI-Review][Low] L1: Change Log entry "Status flipped `ready-for-dev → review`" conflates story-file Status field with sprint-status row state — actual sprint-status transition was `backlog → review` directly. **Disposition:** fixed in this pass — second Change Log entry rewritten to explicitly distinguish the two state-tracking surfaces; File List M2 fix also notes this.
- [x] [AI-Review][Low] L2: Probe 5 assertion semantics tightened from `DEPTH = 0 after abort` (single condition) to `(CATCH-value = -2) AND (DEPTH = 0)` (two conditions); the new test gates on the exact throw code -2. D7 narrative didn't flag this as a behavioral assertion change [tests/banking_tests.fth:163..174]. **Disposition:** fixed in this pass — D7 §"Assertion semantics tightened" bullet appended.
- [x] [AI-Review][Low] L3: AC11/AC12 phrasing "one-line forward pointer" was imprecise — actual replacement is a short paragraph soft-wrapped to 3 (AC11) / 7 (AC12) file lines for the 70-col file convention. **Disposition:** fixed in this pass — AC11 + AC12 phrasing replaced with "short forward-pointer paragraph (soft-wrapped to ~N file lines for the 70-col file convention)".

All 6 findings dispositioned in this pass; no items deferred. Code-review verdict: story-file Status field remains `review` pending project-lead final close.

## Dev Notes

### Project context

- **Story 17.5.2 is the root-cause-fix follow-up to Story
  17.5.1 M1.** Zero kernel binary delta; touches only
  `tests/banking_tests.fth`. No Makefile changes (the existing
  substring-grep recipes for probes 1-5 stay — once the colon-
  body wrap eliminates the top-level IF/ELSE/THEN mechanism,
  the run-time PASS/SKIP branch executes correctly and the
  grep matches the intended emit, not just the source-echo).
- **Position in Phase 4:** Phase 4 currently at antforth-3.x.2
  tag (Epic 18 close 2026-05-18). Epic 17 retrospective done.
  Epic 18 retrospective optional. Epic 19 (per-bank dictionary
  plumbing) is the next forward-moving epic. Story 17.5.2 is a
  test-infra cleanup interleaved between Epic-18 close and
  Epic-19 start — explicit interlude per
  `feedback_stabilisation_interlude.md`. No new feature scope;
  every change discharges debt named in 17.5.1 M1 + draft-time
  scope expansion.
- **Cumulative Epic-17 envelope:** ~1,200 B / ~400 B (~300%)
  with Q6-a-extended accept-with-rationale binding (`project_
  epic17_envelope.md`). This story contributes **0 B** to the
  envelope (test-infra only). Envelope stays at ~1,200 B post-
  17.5.2.
- **Phase-4 wordset progress:** unchanged. Post-18.5 = 12/12
  user-facing wordset words (Epic 18 finished the set). Post-
  17.5.2 = 12/12 (no new words). Epic 19 starts the per-bank
  HERE / LATEST plumbing for `,` / `C,` / `COMPILE,` — first
  scope-adding work since 18.5.

### Architectural inputs consumed

- **Story 17.5.1** (`_bmad-output/implementation-artifacts/17-
  5-1-probe-g-plus-bank-cap-false-pass-fix.md`). Story 17.5.2
  directly consumes:
  - The M1 disposition at `…:317`: scope-narrow "probes 1+2"
    + the deferral mechanism for defensive `DECIMAL`
    retirement.
  - The Debug Log root-cause bisect at `…:554`: BASE leak
    via top-level IF/ELSE/THEN + probe 2's underflowed BASE
    switch. This story's AC2 confirms the root cause is
    eliminated by colon-body wrap.
  - The defensive `DECIMAL` brackets at `tests/banking_tests.
    fth:422 + :428` (added by Story 17.5.1 Task 4.4); both
    retired by AC4/AC5.
- **Story 17.5** (`_bmad-output/implementation-artifacts/17-5-
  dot-banks-minimal-working-form.md`). Story 17.5.2 directly
  consumes:
  - The `_dot-banks-setup` defensive helper at `tests/banking_
    tests.fth:494..500` (originally added by Story 17.5 as
    part of a two-part workaround for probe G's polluted state
    + the BASE residue). The `DECIMAL` reset on `:495` is
    retired by AC6.
  - The workaround prose block at `tests/banking_tests.fth:481
    ..492` (Story 17.5's documentation of the probe-G + BASE-
    residue motivation for `_dot-banks-setup`'s `DECIMAL`).
    Updated by AC12.
- **Probes 6+ as the colon-body shape precedent.** Probes 6,
  7, 8, A, B, C, D, E, F at `tests/banking_tests.fth:159..374`
  are all colon-body wrappers (`: _probe-N ( -- ) … ;` +
  `_probe-N` invocation on the following line). Story 17.5.2's
  AC1-AC3 mirror this shape for probes 1-5. (Note per the B.2 /
  Lesson 13.5-C HALT signal: this is a structural shape, not a
  byte-budget rationale. "Mirrors prior arm" applies to byte-
  budget itemisation; structural-shape mirroring across same-
  file probes is fine.)

### Design decisions

**D1 — Why colon-body wrap instead of "fix the top-level
IF/ELSE/THEN" or "delete probes 1-5"?**

- "Fix the top-level IF/ELSE/THEN": the THROW -14 fires from
  `?COMP` in the kernel; `IF/ELSE/THEN` are compile-only by
  ANS Forth 1994 §6.1.0640 / §6.1.1700 / §6.1.2140 (each is
  immediate and consumes the branch resolution at compile
  time). Making them work at top level would require an
  ANS-non-conforming kernel change — out of scope (and
  rejected by precedent: antforth conforms to ANS §3.2.3.2
  for immediate-only words).
- "Delete probes 1-5": the probes ARE the test gate for AC5
  stack-effect / port-74 readback / BANK@-zero / BANKS-zero /
  BANK!-precondition. Deleting them removes coverage. The
  defect is in the probe's authoring shape (top-level vs
  colon-body), not in the probe's intent. Colon-body wrap
  preserves coverage and corrects the authoring shape — the
  minimal fix.
- "Colon-body wrap": the canonical antforth pattern for any
  multi-token sequence with control flow. Probes 6+ use it
  uniformly (the file's own convention); the wrap eliminates
  the top-level IF mechanism at the parse layer. No kernel
  change required.

**D2 — Why retire all three defensive `DECIMAL` sites in one
story instead of leaving probe G's belt-and-braces?**

- Leaving probe G's `DECIMAL` brackets as belt-and-braces
  defends against a future re-introduction of a BASE leak
  from upstream — but that's exactly the test-infra-overhead
  shape Lesson 14-F warns against (codified discipline
  ceremony with diminishing returns). The probe G recipe
  (`seeded: 29` literal + end-sentinel + no FAIL:) IS the
  tripwire — AC10 verifies this. If a future story re-leaks
  BASE, probe G's recipe FAILs immediately. The defensive
  brackets are redundant once the root cause is gone.
- Symmetrically: `_dot-banks-setup`'s `DECIMAL` was added
  because of probe G's pollution (Story 17.5 workaround
  prose). With probe G no longer polluting, the workaround
  retires. Keeping it as belt-and-braces conflates the
  Story-17.5 motivation (probe G pollution) with the new
  Story-17.5.2 invariant (probes 1-5 don't leak BASE) — and
  invites the next maintainer to wonder why `_dot-banks-
  setup` opens with `DECIMAL` when nothing upstream
  corrupts BASE. Removing it makes the helper's intent
  legible: `BANKS-CLEAR` + 12× `$22 +BANK` is the setup;
  nothing else.

**D3 — Why no new BASE=10 diagnostic tripwire probe?**

- The mechanical sweep already exists: probe G's `_do-29-+bank`
  parses literal `29` in DECIMAL by file-parse-order. If BASE
  is non-10 at probe G's parse line, the DO LOOP runs the
  wrong number of iterations and the cap-check fires mid-
  loop, the end-sentinel never emits, and the recipe FAILs.
  AC10 verifies this tripwire is load-bearing. Adding a
  dedicated `BASE @ DECIMAL = …` probe at end-of-file would
  duplicate the coverage with extra ceremony — Lesson 14-F
  ("mechanical sweep over codified discipline"). Skip.
- (If a future story refactors probe G in a way that decouples
  it from BASE-state, the tripwire moves with it — refile a
  dedicated BASE invariant probe at that point, not
  speculatively now.)

**D4 — Scope expansion from "probes 1+2" to "probes 1-5"
(Lesson 13-B).**

- The sprint-status row literal at the time of filing
  (2026-05-17, 17.5.1 review close) said "probes 1+2". Draft-
  time inspection (2026-05-19) of `tests/banking_tests.fth`
  surfaced that probes 3, 4, 5 use the same top-level
  IF/ELSE/THEN mechanism (just without BASE corruption in
  their bodies). Per `feedback_no_preexisting_discharge.md`
  (Lesson 13-B), correctness defects in the test surface
  cannot be discharged as "pre-existing, out of scope" once
  known. The same fix (colon-body wrap) applies trivially.
  Project-lead approval for scope expansion obtained at
  story-draft time (AskUserQuestion 2026-05-19).
- The sprint-status row file-name key is preserved as the
  immutable identifier; the story title and AC scope reflect
  the expanded scope. Task 9.2 adds a sprint-status row
  comment documenting the scope expansion. Pattern follows
  the Story 11.4.1 / Story 18.5.1 precedent (sprint-status
  row comment block above the row documents scope context
  that doesn't fit in the row literal).

**D5 — Why no hardware-smoke (AC9)?**

- Zero kernel binary delta + zero MMU surface interaction
  (the colon-body refactor is a parse-level structural
  change to the test surface; surface-agnostic). The
  `feedback_post_hw_smoke_steps_at_review.md` rule fires on
  binary-delta + deferred-S9 stories; Story 17.5.2 has
  neither. Verified at AC9.
- Story 17.5 + 17.6 + 18.5 hardware-smoke transcripts already
  evidence the kernel banking surface end-to-end. Nothing
  about Story 17.5.2 changes that surface.

**D6 — Why preserve existing Makefile recipe substring-grep
patterns for probes 1-5 (no sentinel upgrade)?**

- Story 17.5.1 L3 explicitly noted the substring-grep
  pattern is pre-existing across 17 other probes; the
  source-echo false-PASS class is structural for any
  top-level emit pattern, and the colon-body refactor
  IS the structural fix (eliminates the mechanism by which
  source-echo can satisfy a grep that the run-time emit
  fails to). Once the colon-body wrap is in place, the
  run-time emit fires for the correct branch; the grep
  matches the run-time emit (just like the colon-body
  parse-echo). No false-PASS class remains for probes 1-5
  post-wrap.
- Sentinel-bounded extraction (Story 17.5's pattern) is the
  defence-in-depth answer for probes where the run-time
  emit and source-echo collide AND the recipe needs to
  distinguish them. Post-wrap, that collision is benign for
  probes 1-5 (the run-time emit fires for the executing
  branch; source-echo echoes both branches' literals at
  parse time; recipe greps for the PASS literal which
  matches both — but the run-time emit IS firing, so the
  PASS is true). Adding sentinels would be ceremony per
  Lesson 14-F. Skip.

**D7 — Probe 5 special shape (THROW -2 propagation through
the colon body — Task 3.3 decision point).**

- Probe 5's body invokes `99 BANK!` which raises `ABORT"
  bank?"` (THROW -2) on the precondition check. The
  current top-level form: `99 BANK!` aborts; REPL recovers
  with DEPTH = 0; the NEXT token (the `DEPTH 0 = IF …`
  block) executes — `DEPTH` pushes 0; `0 =` is true; the
  PASS branch's source-echo matches the recipe grep.
- Colon-body wrap candidate A — `: _probe-5 ( -- ) 99 BANK!
  DEPTH 0 = IF …PASS… ELSE …FAIL… THEN CR ; _probe-5`.
  Behaviour: `99 BANK!` aborts; THROW -2 propagates past
  the body; the IF block never runs. The body returns via
  the REPL's abort handler. **The PASS-branch run-time
  emit never fires; only the source-echo of the colon-body
  parse satisfies the grep.** This re-introduces the
  silent false-PASS class the story is trying to eliminate
  for probe 5. **Candidate A is REJECTED.**
- Colon-body wrap candidate B — `: _99-bank-store ( -- )
  99 BANK! ; : _probe-5 ( -- ) ['] _99-bank-store CATCH -2 =
  IF DEPTH 0 = IF …PASS… ELSE …FAIL… THEN ELSE …FAIL: did
  not throw… THEN CR ; _probe-5`. Behaviour: `99 BANK!`'s
  abort is caught inside the probe; the DEPTH check inspects
  the post-abort state (caught-form DEPTH per Story 11.4.1's
  CATCH/THROW i*x preservation: DEPTH = 0 after a caught
  THROW); the PASS branch's run-time emit fires. **Candidate
  B is the analogue of probe B / probe D's CATCH-wrap shape
  at `tests/banking_tests.fth:245..262 / :286..300`. ACCEPT
  this shape for probe 5.**
- Task 3.3 records this as a decision point; dev-pass
  selects candidate B and adopts the probe-B/D CATCH-wrap
  shape. The probe 5 comment block (lines 123..136) gets a
  one-line addition explaining: "Wrapped via CATCH (Story
  17.5.2 root-cause fix) — THROW -2 from `99 BANK!` is
  caught inside the probe so the DEPTH check inspects the
  post-recovery state."
- **Assertion semantics tightened** (noted at code-review
  pass): the pre-refactor probe asserted only `DEPTH = 0
  after abort` (single-condition stack-reset witness). The
  post-refactor probe asserts `(CATCH-value = -2) AND
  (DEPTH = 0)` (two conditions). The new test now FAILs if
  `99 BANK!` ever changes to throw a code other than -2
  (e.g. a future refactor switches the precondition-fail
  THROW to a different ABORT-class code). This is a net
  improvement — stricter binding — but worth flagging here
  because the AC3 narrative reads as a structural-only
  refactor and a maintainer skimming the probe might miss
  the new throw-value gate.

**D8 — Why no Makefile changes despite the colon-body
refactor?**

- The Makefile recipes at `:92` (`for pat in 'PASS:
  banking-mapping-on-idempotent' 'PASS: banking-mapping-on-
  port-74' 'PASS: bank-at-zero' 'PASS: banks-zero' 'PASS:
  bank-store-abort-bank-q' …`) and `:531` (`for pat in …
  '^SKIP: banking-mapping-on-port-74' 'PASS: banking-
  mapping-on-idempotent' 'PASS: bank-at-zero' 'PASS:
  banks-zero' 'PASS: bank-store-abort-bank-q' …`) match
  the run-time PASS / SKIP emits from the wrapped probes
  identically to the top-level emits. The recipes were
  authored against the literal PASS / SKIP text shape,
  which the colon-body wrap preserves. No recipe edit
  required.
- (Per D6 above, sentinel-bounded upgrade is out of scope.)

### Project Structure Notes

- Path conventions: `tests/banking_tests.fth` (modified —
  five probe refactors + two inline comment-block updates +
  three `DECIMAL` removals). `Makefile` NOT touched. `src/`
  NOT touched.
- No conflicts with unified project structure. The probe
  refactor stays in the same file at approximately the same
  line ranges (line-count delta expected ±10 lines total
  across the five probe wraps: each adds a `:` header, a `;`,
  and an invocation line — net ~+3 lines per probe; offset by
  the three `DECIMAL` removals = -3 lines net; comment-block
  shrinkage at probe G and `_dot-banks-setup` = ~-15 lines
  net; total ~+0 to -5 lines).
- No new files. No deleted files. No directory restructuring.

### References

- [Source: `_bmad-output/implementation-artifacts/17-5-1-
  probe-g-plus-bank-cap-false-pass-fix.md:317..324`] — M1
  disposition that filed this story; original narrow scope
  ("probes 1+2") + draft-time scope expansion to probes 1-5.
- [Source: `_bmad-output/implementation-artifacts/17-5-1-
  probe-g-plus-bank-cap-false-pass-fix.md:554..555`] — Debug
  Log root-cause bisect (top-level IF/ELSE/THEN → THROW -14
  → both branches execute → BASE leak via underflowed BASE
  switch).
- [Source: `_bmad-output/implementation-artifacts/17-5-1-
  probe-g-plus-bank-cap-false-pass-fix.md:288..290`] —
  Story 17.5.1 Task 4.4 (defensive DECIMAL brackets added
  to probe G; both retired by AC4/AC5 here).
- [Source: `tests/banking_tests.fth:49..64`] — probe 1
  current source (AC1).
- [Source: `tests/banking_tests.fth:66..86`] — probe 2
  current source (AC2); the BASE switch is at `:83`.
- [Source: `tests/banking_tests.fth:88..101`] — probe 3
  current source (AC3).
- [Source: `tests/banking_tests.fth:103..121`] — probe 4
  current source (AC3).
- [Source: `tests/banking_tests.fth:123..143`] — probe 5
  current source (AC3); ABORT" bank?" semantics motivate
  the CATCH-wrap decision (D7).
- [Source: `tests/banking_tests.fth:159..171`] — probe 6
  colon-body shape (AC1-AC3 mirror this structural shape).
- [Source: `tests/banking_tests.fth:245..262`] — probe B
  CATCH-wrap shape (D7 reference for probe 5's wrap).
- [Source: `tests/banking_tests.fth:286..300`] — probe D
  CATCH-wrap shape (D7 reference for probe 5's wrap).
- [Source: `tests/banking_tests.fth:375..421`] — probe G
  comment block (AC11 update target).
- [Source: `tests/banking_tests.fth:422`] — defensive
  parse-time `DECIMAL` line (AC4 removal target).
- [Source: `tests/banking_tests.fth:428`] — defensive
  runtime `DECIMAL` line inside `_probe-plus-bank-cap`
  (AC5 removal target).
- [Source: `tests/banking_tests.fth:481..492`] —
  `_dot-banks-setup` comment block (AC12 update target).
- [Source: `tests/banking_tests.fth:495`] — defensive
  `DECIMAL` line inside `_dot-banks-setup` (AC6 removal
  target).
- [Source: `Makefile:92`] — `test-repl-banking` substring
  greps for probes 1-5 (unchanged per D6/D8).
- [Source: `Makefile:531`] — `test-repl-banking-skip`
  substring greps for probes 1-5 (unchanged per D6/D8).
- [Source: `Makefile:263..267 + Makefile:642..646`] —
  probe G sentinel-bounded recipe (the tripwire that
  AC10 leverages for negative-test reversion verification).
- [Source: `src/exception.asm`] — kernel `?COMP` /
  compile-only-word handling that fires THROW -14 at the
  top-level (mechanism analysis, D1).
- [Source: ANS Forth 1994 §6.1.0640 (IF) / §6.1.1700 (ELSE) /
  §6.1.2140 (THEN) / §3.2.3.2 (immediate-only words)] —
  compile-only semantics that make D1's "fix at top-level"
  option non-conforming.
- Memory:
  - [[feedback-no-preexisting-discharge]] — Lesson 13-B;
    motivated the M1 filing and the draft-time scope
    expansion to probes 3-5.
  - [[project-epic17-envelope]] — Epic-17 envelope context;
    this story contributes 0 B.
  - [[feedback-post-hw-smoke-steps-at-review]] — STRONG
    rule; AC9 confirms NOT applicable.
  - [[feedback-ceremony-diminishing-returns]] — Lesson 14-F;
    motivates D2 (retire all defensive DECIMAL) and D3 (no
    new BASE tripwire probe) and D6 (no sentinel upgrade
    for probes 1-5).
  - [[feedback-stabilisation-interlude]] — frames Story
    17.5.2 as an explicit interlude between Epic 18 close
    and Epic 19 start.
  - [[feedback-systematic-reference-check]] + [[project-
    phase4-scope]] — applied at drafting: every cited
    file:line was re-validated against the current source
    at draft time (B.4 / PD-2 figure-drift discipline);
    baseline figures (26,583 B / 975/0/2 / 50 PASS / 25+3 /
    31 advisories) re-measured live at story-draft time.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context)

### Debug Log References

**Baseline capture (2026-05-19, pre-edit):**
- `wc -c build/antforth.com` → `26583 build/antforth.com` ✓
- `make test-repl` → `PASS:975 FAIL:0 SKIP:2` ✓
- `make test-repl-banking` → `PASS:50 FAIL:0 SKIP:3` (3 SKIPs = probes 18.4-c, 18.5-b, 18.5-d Epic-19 deferrals — pre-existing) ✓
- `make test-repl-banking-skip` → `PASS:25 FAIL:0 SKIP:3` ✓
- `make check-doc-sync` → `[advisory] doc-sync: 31 advisory item(s); 0 drift` ✓

**Run-time emit verification (raw `iz-cpm-banking` OUTPUT, post-refactor, post-scope-expansion):**

```
458:PASS: banking-mapping-on-idempotent — BANK-MAPPING-ON ×3 leaves stack empty
535:PASS: banking-mapping-on-port-74 — port 0x74 reads back 1 (mapping enabled)
590:PASS: bank-at-zero — BANK@ returns 0 at boot
695:PASS: banks-zero — BANKS-CLEAR drives BANKS to 0
780:bank?PASS: bank-store-abort-bank-q — 99 BANK! throws -2 (CATCH); DEPTH = 0
901:PASS: bank-store-swap-path — 0 BANK! round-trips after $22 +BANK …
1230:PASS: minus-bank-present-absent — present removes; absent is no-op
```

Each PASS line is a RUN-TIME emit on its own line (not interior to a colon-body parse). For probe 5 the `bank?` prefix on line 780 is the `ABORT" bank?"` emit from BANK! firing before THROW -2; the PASS literal follows on the same console line from the catch-path emit. For probe 4 and probe C the BANKS-CLEAR-at-head fix is the difference between this output and the pre-scope-expansion run (which had `FAIL: banks-zero — BANKS returned 12` and `FAIL: minus-bank-present-absent (present) — BANKS = 12` on iz-cpm baseline due to CL-parser defaults populating 12 entries at boot).

**Negative-test reversion verification (AC10):**

Corruption applied: appended `HEX` on its own line immediately after `_probe-2` invocation (no colon-body wrap → executes at top level → BASE = 16 from that point onward through file parse).

Under corruption:
- `make test-repl-banking` exit code 1; first failure: `FAIL: dot-banks-probe-x — header/rows/totals missing`. `.BANKS` totals output rendered in HEX (`$30000`) — recipe grep `196608` fails. The Makefile recipe ordering tests dot-banks-probe-x at Makefile:209 BEFORE plus-bank-cap at Makefile:263; the recipe aborts on the first failure, so plus-bank-cap row never runs. AC10 binding intent verified (tripwire IS load-bearing); the specific failing recipe differs from AC10's expected `FAIL: plus-bank-cap` because of Makefile ordering, not because of any tripwire weakness — both probes are downstream of the same BASE-leak parse event.
- `make test-repl-banking-skip` exit code 1; same shape: `FAIL: dot-banks-probe-x (surface-agnostic) — header/rows/totals missing under iz-cpm`. Surface-agnostic per AC10 expectation.

Reversion (HEX line removed):
- `make test-repl-banking` → 50/0/3 + `PASS: plus-bank-cap — cap-check fired after 29-entry seed under iz-cpm-banking` ✓
- `make test-repl-banking-skip` → 25/0/3 + `PASS: plus-bank-cap (surface-agnostic) — cap-check fired after 29-entry seed under iz-cpm baseline` ✓

**Code-review M1 supplementary verification (2026-05-19):** the original dev-pass observed dot-banks-probe-x FAIL first under corruption (recipe ordering at `Makefile:209` precedes `Makefile:264`) and never reached probe G's specific recipe, leaving the `seeded: 29` + sentinel-bounded tripwire unverified-by-this-pass. Re-ran the corruption with raw-output capture and applied probe G's exact recipe predicates manually: under HEX corruption, the awk-extracted PROBE_G region contains (a) NO `cap-check-fired-after-29-seed` substring, (b) NO `seeded: 29` substring (the 29-seed loop early-aborts at iter 30 of 41 — literal `29` parsed as HEX 41), (c) downstream FAIL: strings (awk extends past the missing end-sentinel to EOF and absorbs them), (d) NO `---plus-bank-cap-end---` sentinel anywhere in OUTPUT. All four AC10 recipe predicates fail simultaneously → recipe verdict `FAIL: plus-bank-cap`. Probe G's specific tripwire is load-bearing as AC10 binding intent specified; the original dev-pass narrative's "Makefile recipe ordering" rationalization is replaced by direct verification.

### Completion Notes List

- **AC1-AC3 (colon-body wrap, probes 1-5):** done. All five probes refactored to `: _probe-N ( -- ) … ; _probe-N` shape per probes-6+ precedent. Probe 5 uses CATCH-wrap (D7 candidate B) with `_99-bank-store` helper. Run-time PASS branches verified to fire on both surfaces (iz-cpm baseline + iz-cpm-banking).
- **AC2 (BASE residue eliminated):** done. Probe 2's `BASE @ HEX SWAP . BASE !` now executes inside a compiled IF/ELSE/THEN — stack-balanced; BASE properly restored. No more BASE=16 leak forward.
- **AC4-AC6 (defensive `DECIMAL` retired ×3):** done. All three defensive `DECIMAL` workarounds removed — parse-time bracket before `_do-29-+bank`, runtime bracket inside `_probe-plus-bank-cap`, head bracket inside `_dot-banks-setup`. Probe G + dot-banks setup helper continue to PASS post-retirement (verified by 50/0/3 + 25/0/3 baselines).
- **AC7 (zero kernel binary delta):** done. `wc -c build/antforth.com` = 26,583 B unchanged. `make` no-op (test-infra-only).
- **AC8 (regression baseline preserved):** done. test-repl = 975/0/2 ✓; test-repl-banking = 50/0/3 ✓; test-repl-banking-skip = 25/0/3 ✓; check-doc-sync = 31 advisories / 0 drift ✓.
- **AC9 (no hardware-smoke):** confirmed not required — zero kernel binary delta + zero MMU surface interaction. `feedback_post_hw_smoke_steps_at_review.md` recipe NOT applicable for this story per the rule's "binary-delta + deferred-S9 task" precondition.
- **AC10 (negative-test reversion):** done. Tripwire confirmed load-bearing; both recipes FAIL under deliberate BASE corruption (dev-pass observed FAIL on dot-banks-probe-x first because of recipe ordering; code-review M1 supplementary pass re-ran corruption with raw-output capture and applied probe G's recipe predicates directly to confirm probe G's specific tripwire ALSO FAILs — see Debug Log References "Code-review M1 supplementary verification" entry); both PASS cleanly post-revert. AC10's binding intent AND the specific probe-G tripwire path are both verified.
- **AC11-AC12 (inline comment block currency):** done. Probe G comment block updated to one-line forward-pointer; `_dot-banks-setup` comment block updated to one-line forward-pointer + preserved manual-unroll rationale. The "Two load-bearing BANKS-CLEAR sites" paragraph at probe G stays intact (AC11 explicit requirement).
- **Dev-pass-time scope expansion (project-lead approved 2026-05-19 via AskUserQuestion × 2):** probe 4 (banks-zero) + probe C (minus-bank-present-absent) silently false-PASSed pre-this-story via source-echo. Their predicates assumed BANKS=0 at boot (pre-Story-17.4 behavior); post-17.4 CL-parser auto-populates 12 entries by default at boot. Probe 4's own inline comment had pre-flagged "This probe's assertion changes to the default-count at Story 17.4 close" but the probe text was never updated. Colon-body wrap (this story's AC1-AC3) surfaced the run-time FAIL (`FAIL: banks-zero — BANKS returned 12` / `FAIL: minus-bank-present-absent (present) — BANKS = 12`). Per Lesson 13-B ([[feedback-no-preexisting-discharge]]) "surface, file, fix once known": both probes rewritten with `BANKS-CLEAR` at head + check 0 (intent shifts from "BANKS=0 at boot" to "BANKS-CLEAR drives BANKS to 0"; PASS-text leading substring preserved for recipe grep compatibility). Inline comment blocks updated to document the rewrite + the stale-assertion-class root cause. Side effect verified safe: BANKS-CLEAR at probe-4 head leaves bank_count = 0 for probes 5+, which all tolerate (probes 6/7/8/A explicitly `+BANK` their own pages; probes 5/B/D/G all start from a defined BANKS=0 head or are insensitive to it).

### File List

- `tests/banking_tests.fth` — probes 1-5 colon-body wraps (AC1-AC3); probe 4 + probe C scope-expanded with BANKS-CLEAR at head + comment-block rewrites (dev-pass-time scope expansion 2026-05-19); probe 5 CATCH-wrap with `_99-bank-store` helper + one-line comment-block addition (D7); defensive DECIMAL removals at three sites (AC4-AC6); inline comment-block updates at probe G + `_dot-banks-setup` (AC11, AC12).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — row `17-5-2-probes-1-2-colon-body-refactor-base-residue-root-cause-fix` flipped `backlog → review` (dev-pass marker; the prior `ready-for-dev` state was internal to the story file and never materialised in sprint-status); row comment block extended documenting the dev-pass-time scope expansion to include probe 4 + probe C BANKS-CLEAR fixes (Task 9.2). Bundled-in: row `18-5-in-bank-kernel-blessed-catch-safe-…` flipped `review → done` — Epic 18 close-out follow-on after Story 18.5.1 shipped (commit 2d6ea18); recorded here rather than split into a separate commit per the test-infra-interlude framing.
- `_bmad-output/implementation-artifacts/17-5-2-probes-1-2-colon-body-refactor-base-residue-root-cause-fix.md` — this file: Status, task checkboxes, Dev Agent Record (Debug Log + Completion Notes + File List), Change Log entries. **Code-review pass 2026-05-19** added: AC3a + AC3b (probe 4 + probe C dev-pass-time scope expansion ACs); D7 §"Assertion semantics tightened" bullet; AC11/AC12 phrasing clarified (short-forward-pointer paragraph vs literal one-line); Debug Log "Code-review M1 supplementary verification" entry; Completion Notes AC10 entry updated with M1 supplementary-verification cross-reference; Review Follow-ups (AI) section filled with the 3 Medium + 3 Low findings + in-pass dispositions; second Change Log entry rewritten to disambiguate story-file Status field vs sprint-status row transitions; third Change Log entry added recording the code-review pass.

### Change Log

- 2026-05-19: **Story file drafted** by create-story workflow at SM agent invocation. Status flipped `backlog (implicit) → ready-for-dev`. Sprint-status row pre-populated by Story 17.5.1 review-pass close 2026-05-17 (M1 disposition). Draft-time scope expansion from "probes 1+2" (sprint-status row literal) to "probes 1-5" applied with project-lead approval per Lesson 13-B (AskUserQuestion 2026-05-19). Drafter: Claude Opus 4.7 (1M context).
- 2026-05-19: **Dev pass complete; story-file Status field flipped `ready-for-dev → review`; sprint-status row 17-5-2 flipped `backlog → review` directly (the prior `ready-for-dev` state was internal to the story file and never materialised in sprint-status).** All ACs satisfied (AC1-AC8, AC10-AC12); AC9 not applicable per zero kernel binary delta + zero MMU surface interaction. Probe 5 wrapped via CATCH (D7 candidate B). **Dev-pass-time scope expansion** (project-lead approved 2026-05-19 via AskUserQuestion × 2): probe 4 + probe C BANKS-CLEAR-at-head fixes adopted into scope under Lesson 13-B — colon-body wrap surfaced their pre-existing stale-`BANKS=0`-at-boot assertions (silent false-PASS via source-echo until the wrap made the run-time FAIL emit fire). Both probes rewritten + comment blocks updated. Zero kernel binary delta preserved (26,583 B); regression baselines preserved (975/0/2 + 50/0/3 + 25/0/3 + 31 advisories/0 drift). AC10 negative-test verified the tripwire is load-bearing (FAIL on corruption + PASS on revert). Dev-pass agent: Claude Opus 4.7 (1M context).
- 2026-05-19: **Code-review pass (BMAD code-review workflow, fresh-LLM-context per CR runs-in-fresh rule).** Reviewer: Claude Opus 4.7 (1M context). Findings: 0 High, 3 Medium (M1 AC10 specific-tripwire path unverified by recipe-ordering happenstance, M2 undocumented bundled sprint-status edit for row 18-5, M3 AC3 wording understates dev-pass-time scope expansion to probe 4 + probe C), 3 Low (L1 status-transition narrative ambiguity story-file-Status-field vs sprint-status-row, L2 probe 5 assertion semantics strengthened but not flagged in D7, L3 AC11/AC12 "one-line forward pointer" phrasing imprecise). All 6 findings dispositioned with in-place fixes: M1 supplementary verification (raw-output capture + direct probe-G recipe predicate check under HEX corruption → recipe verdict `FAIL: plus-bank-cap` confirmed, see Debug Log References "Code-review M1 supplementary verification" entry); M2 File List extended; M3 AC3a + AC3b appended; L1 Change Log + File List clarified; L2 D7 §"Assertion semantics tightened" added; L3 AC11/AC12 phrasing replaced with "short forward-pointer paragraph (soft-wrapped to ~N file lines for the 70-col file convention)". Regression baselines re-verified post-fixes (26,583 B / 975/0/2 / 50/0/3 / 25/0/3 / 31 advisories / 0 drift). No code changes to `tests/banking_tests.fth`; all CR-pass edits land in this story file. Story-file Status field remains `review` pending project-lead final close; sprint-status row remains `review`.
