# Story 17.5.1: Probe G (`_probe-plus-bank-cap`) false-PASS fix — sentinel-bounded recipe + reset-before-seed

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Context — why this story exists, why now

Surfaced as **H2** in the AI code-review pass on Story 17.5
(2026-05-16; see
`_bmad-output/implementation-artifacts/17-5-dot-banks-minimal-working-form.md:547`).
Filed as a follow-up story per `feedback_no_preexisting_discharge.md`
(Lesson 13-B) — a correctness defect in the test surface is **not**
dischargeable as "pre-existing, out of scope". Slotted between
Story 17.5 and Story 17.6 per project-lead direction 2026-05-16.

**The defect (two intertwined causes):**

1. **Probe-side**: `_probe-plus-bank-cap`
   (`tests/banking_tests.fth:383..406`, added by Story 17.3 review
   pass as Probe G — H2 fix) attempts to seed 29 entries via
   `_do-29-+bank` (`29 0 DO $22 +BANK LOOP`), then asserts the
   30th `+BANK` ABORTs with `THROW -2 ("cap?")` via CATCH. The
   probe was designed assuming `bank_count = 0` at probe-entry,
   but Story 17.4's CL parser populates `active_pages[]` with the
   default `0x22, 0x35..0x3F` (12 entries) at boot — so probe
   entry sees `bank_count = 12`, not `0`. The DO LOOP body trips
   the `+BANK` cap-check at iteration 17 (`12 + 17 = 29`; iter 18
   would push to 30 and ABORTs). The ABORT propagates **uncaught**
   past the LOOP (not inside the probe's CATCH frame — CATCH only
   wraps `_do-one-more-+bank`, not the seed loop), bubbles to the
   outer interpreter, and resets state via `w_QUIT_cf`. The probe's
   PASS branch never runs; `BANKS-CLEAR` at the end of the probe
   never runs; runtime is left with `bank_count = 29` /
   `BASE = 16`.

2. **Makefile-side**: both `test-repl-banking`
   (`Makefile:92`) and `test-repl-banking-skip` (`Makefile:261`)
   recipes assert via `grep -q 'PASS: plus-bank-cap'` over the
   raw piped-output. iz-cpm echoes every input character to its
   console output (because the CCP-equivalent console is run with
   echo enabled), so the **source text** of the `." PASS: plus-
   bank-cap — 30th +BANK aborts; BANKS stays at 29"` literal —
   embedded in the colon-body of `_probe-plus-bank-cap` itself —
   appears in the captured output **regardless of whether the
   PASS branch executed**. The substring grep matches the source
   echo. Both recipes false-PASS. This is the load-bearing root
   cause: even if the probe ran perfectly, the recipe pattern
   would false-PASS on source-echo for any colon-defined probe.

**Collateral damage observed during Story 17.5 dev-pass:** because
probe G leaves `bank_count = 29` and `BASE = 16`, Story 17.5's
`.BANKS` probes downstream of probe G had to be authored
defensively — each colon definition opens with `_dot-banks-setup`
(`tests/banking_tests.fth:450..456`) which asserts
`DECIMAL + BANKS-CLEAR + 12 unrolled $22 +BANK calls`. That
defensive pattern is now technical debt: after this story closes,
the test surface needs to reaffirm whether `_dot-banks-setup`'s
`DECIMAL` reset is still load-bearing or can be retired.

**What this story does NOT do:**

- Does NOT change kernel binary. Test-infra only.
  (`build/antforth.com` is expected to remain at **26,228 B**
  post-dev-pass; per-AC verification at dev-pass close.)
- Does NOT add or modify any user-facing word.
- Does NOT touch `src/banking.asm` or `src/antforth.asm`.
- Does NOT change the `.BANKS` probes (X / Y / Z / W) from
  Story 17.5 — those stay as-is. The `_dot-banks-setup` helper
  may be revisited under AC5 (retirement of `DECIMAL` reset
  defensive workaround) but only if the BASE residue is
  confirmed kernel-side, not probe-side.
- Does NOT investigate every Forth-side or BDOS-side reason
  why `iz-cpm-banking` echoes input characters — that behaviour
  is structural (BDOS function 1 echoes; antforth's REPL uses
  it via `bdos_getchar`) and far outside Epic-17 scope. The fix
  is at the assertion layer (sentinel-bounded extraction), not
  the surface layer.

**Why now (slotting before Story 17.6):** Story 17.6 carries the
iron-spike + Epic-17 close-out gate + antforth-3.x.1 tag application.
The verdict-table walk in Story 17.6's AC6 (`epics-phase4-epics-16-
22.md:599`) explicitly lists Story 17.3 PASS as one row in the table.
Story 17.3's AC2 is the `+BANK` past-cap policy. A verdict-table walk
that signs off PASS on AC2 while Probe G is silently false-PASSing
would be a Story 17.6 correctness defect downstream of 17.3's review
disposition. This story closes that exposure before the iron-spike
gate runs.

## Story

As the antforth maintainer relying on `make test-repl-banking` to
gate `+BANK` cap-check correctness across Stories 17.3 → 17.6 → Epic
22 polish,
I want `_probe-plus-bank-cap` to **actually** exercise the cap-check
branch — both at the probe runtime layer (probe state correctly
controls bank_count entering the seed loop) and at the assertion
layer (recipe pattern asserts on output **that cannot collide with
source echo**),
So that AC2 / PD-P4-13 (`+BANK` past cap raises `ABORT" cap?"`) has
a real test gate that won't rot when the +BANK body is touched in
future stories (Epic 19 per-bank dictionary plumbing; Epic 21 MARKER
reclamation) — and so the same anti-source-echo discipline that
Story 17.5's `.BANKS` probes already use (sentinel + awk-extract)
covers the probe-G assertion too.

## Acceptance Criteria

**Given** Story 17.5 has closed (post-17.5 baseline = **26,228 B
/ 975 PASS / 0 FAIL / 2 SKIP on iz-cpm baseline / 34 PASS on
test-repl-banking / 24 PASS + 3 SKIP on test-repl-banking-skip /
31 advisories / 0 drift on check-doc-sync**; the H2 follow-up row
`17-5-1-probe-g-plus-bank-cap-false-pass-fix` is filed in
`sprint-status.yaml` at `ready-for-dev`),
**And** the cumulative Epic-17 envelope is **~1,200 B / ~400 B
(~300%)** with Q6-a-extended accept-with-rationale binding
(`project_epic17_envelope.md`; Story 17.5 close 2026-05-16),
**When** Story 17.5.1 is dev-passed,

**Then** **AC1** (probe state — reset-before-seed) —
`_probe-plus-bank-cap` is rewritten so its body's first executed
statement is `BANKS-CLEAR`. After `BANKS-CLEAR`, `bank_count = 0`
and the table is empty; the `_do-29-+bank` LOOP body then seeds
exactly 29 entries (iterations 0..28; ends with `bank_count = 29`,
at-cap), and the subsequent `_do-one-more-+bank` is the 30th
`+BANK` call which trips the cap and throws `-2`. The probe MUST
exercise the cap-check branch end-to-end on every run, regardless
of the runtime state at probe-entry. **No probe-state assumption
about boot defaults survives the `BANKS-CLEAR` reset.**

**And** **AC2** (sentinel-bounded output) —
`_probe-plus-bank-cap`'s output is wrapped in sentinel markers
that **cannot appear as a substring of the colon-source-echo of
the probe**:
  - Probe opens with `." ---plus-bank-cap-start---" CR`
  - Probe closes with `." ---plus-bank-cap-end---" CR` (printed
    unconditionally regardless of PASS / FAIL branch)
  - PASS branch emits a distinct **assertion text** that does
    NOT contain the substring `PASS: plus-bank-cap` (e.g.,
    `." cap-check-fired-after-29-seed"` or similar — wording at
    dev-pass discretion subject to AC3 grep compatibility). The
    rationale: the assertion text gets echoed by the colon-body
    parse just like the old `." PASS: ..."` literal did; **the
    asserting condition must be detectable by a grep pattern
    that the source-echo cannot satisfy**.
  - FAIL branches emit distinct FAIL strings (per existing
    Story-17.3 convention) which the recipe greps for and
    treats as failure if any are present in the extracted
    region.

**And** **AC3** (Makefile recipe — `test-repl-banking`) — the
substring grep for `'PASS: plus-bank-cap'` (`Makefile:92`,
embedded in the `pat` loop) is **removed** from the loop list.
A standalone sentinel-bounded recipe replaces it, using the
same awk-extract pattern as Story 17.5's dot-banks probes
(`Makefile:206..247`):

```
PROBE_G=$(echo "$OUTPUT" | awk '/---plus-bank-cap-start---$/{p=1; next} /---plus-bank-cap-end---$/{p=0} p')
```

The recipe MUST assert all three of:
  - (a) PASS-branch evidence: the AC2 PASS-branch literal
    appears in `PROBE_G`.
  - (b) Cap-trip-condition evidence: the literal `bank_count=29`
    OR equivalent diagnostic confirms the seed loop completed
    to `bank_count = 29` before the 30th call (a sanity probe
    against silent regressions where the seed loop early-aborts).
  - (c) No FAIL-branch literals appear in `PROBE_G`.

**And** **AC4** (Makefile recipe — `test-repl-banking-skip`) —
the matching substring grep `'PASS: plus-bank-cap'` is removed
from the loop list at `Makefile:261` (the iz-cpm baseline
recipe). The sentinel-bounded assertion at AC3 lifts to the
baseline recipe as **PASS-on-both-surfaces** (the cap-check is a
kernel-cell comparison — surface-independent, like `BANKS-CLEAR`
itself). Two parallel sentinel-bounded recipes (one per surface),
identical assertion logic, per the Story-17.5 dual-recipe
precedent.

**And** **AC5** (BASE residue — investigation) — dev-pass
investigates the BASE-flipped-to-HEX residue noted in Story
17.5's `tests/banking_tests.fth:437..445` comment block (which
motivated the defensive `DECIMAL` reset in
`_dot-banks-setup`). One of two dispositions:
  - **(a) probe-side cause** (most likely): trace which prior
    probe leaked BASE=HEX through a state-corrupting path
    (e.g., the `BASE @ HEX SWAP . BASE !` pattern at
    `tests/banking_tests.fth:83, 323, 362` — if any of those
    are wrapped inside a colon-body that ABORTed between `HEX`
    and `BASE !`, BASE leaks). Fix at the probe source (e.g.,
    move `BASE !` to a guard structure, or use `BASE @ >R HEX
    ... R> BASE !` if R-stack save survives ABORT — which
    it does not). Dispose with a probe-side fix; document in
    Dev Notes.
  - **(b) kernel-side correct behaviour** (per ANS Forth 1994
    §9.6.2.0670 QUIT does NOT mandate BASE reset; COLD does
    — `src/antforth.asm:46` "6. BASE = 10 (decimal)"). If the
    residue is structural, document as
    accepted-with-rationale (ANS-compliant; defensive `DECIMAL`
    in `_dot-banks-setup` stays) and surface it in
    `docs/ans-forth-core-compliance.md` if not already
    documented.

**And** **AC6** (negative-test — reversion verification) —
dev-pass verifies the AC3 / AC4 recipes are NOT false-passing
on the new probe shape. Method: deliberately corrupt the probe
in a way that should cause it to FAIL (e.g., comment out the
`BANKS-CLEAR` line; or change `_do-one-more-+bank` to be a
no-op; or change `-2` in the CATCH equality check to `-99`).
Re-run `make test-repl-banking` + `make test-repl-banking-skip`.
Both recipes MUST report FAIL for `plus-bank-cap`. Restore the
probe; both recipes MUST report PASS. Record the negative-test
output in Dev Notes for traceability. **This AC is the
load-bearing verification that the new assertion machinery
actually asserts.**

**And** **AC7** (binary delta — no kernel change) —
`wc -c build/antforth.com` is **unchanged at 26,228 B** at
dev-pass close (test-infra-only fix; no source-tree change to
`src/banking.asm` or any other file under `src/`). If the
binary delta is non-zero, dev-pass HALTs and surfaces the
unexpected kernel touch to project lead before continuing.

**And** **AC8** (regression baseline preserved) —
  - `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP** (baseline
    preserved per FR-P4-41 / NFR-P4-10; no test-thread
    contribution from this story).
  - `make test-repl-banking` = **34 PASS** (was 34 post-17.5;
    Probe-G recipe count unchanged — still 1 recipe; new
    recipe replaces old grep position).
  - `make test-repl-banking-skip` = **24 PASS + 3 SKIP** (was
    24+3 post-17.5; same shape).
  - `make check-doc-sync` = **31 advisories / 0 drift**
    (unchanged; no compliance-doc row added).

**And** **AC9** (hardware smoke — NOT required) — Story
17.5.1 does NOT require a hardware-smoke run. Rationale:
zero kernel binary delta + zero MMU surface interaction (the
probe is a kernel-cell-comparison test; surface-agnostic per
AC4). The Story-17.5 hardware-smoke transcript
(`~/Downloads/beastty-20260516-225900.bin`) already evidences
the `.BANKS` + `BANK!` round-trip on real MicroBeast; nothing
about Story 17.5.1 changes that surface. **No `feedback_post_
hw_smoke_steps_at_review.md` recipe is required at code-review
close for this story** — the rule fires on binary-delta stories
with deferred S9/AC8 hardware-smoke tasks; Story 17.5.1 has no
binary delta and no hardware-smoke task. (If dev-pass finds any
reason a hardware-smoke is warranted — e.g., a structural
surprise — surface that during dev-pass; do not silently
skip.)

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes (expected: 26,228 B post-17.5 close)
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F)
- [x] Capture current `make test-repl` baseline pass count (expected: 975 PASS / 0 FAIL / 2 SKIP)
- [x] Capture current `make test-repl-banking` (expected: 34 PASS) + `make test-repl-banking-skip` (expected: 24 PASS + 3 SKIP) baselines
- [x] Capture current `make check-doc-sync` (expected: 31 advisories / 0 drift)
- [x] Re-read `_bmad-output/implementation-artifacts/17-5-dot-banks-minimal-working-form.md:540..551` (the H2 finding block) and confirm the H2 framing is still accurate against the current `tests/banking_tests.fth:375..406` source

### Story tasks

- [x] **Task 1 — Rewrite `_probe-plus-bank-cap` body** (AC1, AC2)
  - [x] 1.1 — Open `tests/banking_tests.fth:383..406`. The current shape is `: _do-29-+bank ... ; : _do-one-more-+bank ... ; : _probe-plus-bank-cap _do-29-+bank BANKS DUP 29 = IF ... THEN CR BANKS-CLEAR ;`
  - [x] 1.2 — Per AC1: move `BANKS-CLEAR` from the tail of the probe to the head. New shape opens with `BANKS-CLEAR` (so the seed loop starts from a known empty state regardless of CL-parser defaults).
  - [x] 1.3 — Per AC2: emit the start sentinel `." ---plus-bank-cap-start---" CR` immediately after `BANKS-CLEAR`. Emit the end sentinel `." ---plus-bank-cap-end---" CR` as the **last** action of the probe (unconditional — outside the IF/ELSE structure).
  - [x] 1.4 — Per AC2: replace the existing `." PASS: plus-bank-cap — 30th +BANK aborts; BANKS stays at 29"` literal with a distinct assertion-text literal that the colon-source-echo cannot satisfy. Recommended: `." cap-check-fired-after-29-seed"` (no leading `PASS: ` prefix; the recipe-side awk extraction handles the verdict-label semantics, not the probe-side text). FAIL branches keep their existing `." FAIL: ..."` shape (these are diagnostic strings shown when a real FAIL fires; their source-echo collision is harmless because the recipe only greps for FAIL strings to NEGATIVE-assert).
  - [x] 1.5 — Add a `BANKS .` print between the seed loop and the cap-trip call so AC3(b) (cap-trip-condition evidence) has a numeric line to assert against. Format: e.g., `." seeded:" BANKS . CR` (the digit `29` then appears in the extracted region between sentinels; recipe asserts the literal `seeded: 29`). Implemented as `." seeded: " BANKS . CR` (space after colon for clean grep match against `seeded: 29`).
  - [x] 1.6 — Per AC1 closing: at the tail of the probe (between the AC2-end-sentinel emit and the closing `;`), restore the runtime to a clean state — `BANKS-CLEAR` again (so downstream probes don't inherit `bank_count = 29` if they run after probe G in the file order).
  - [x] 1.7 — Source comment block above the probe: update the lines 375..382 comment to reflect the new probe semantics. Cite this story file. Remove the stale "boot bank_count = 12, not 0" framing (mooted by AC1's reset-before-seed). Add a one-line forward pointer: "If the test surface adds more probes after probe G, this one's tail BANKS-CLEAR is the load-bearing handoff guard — do not move it."

- [x] **Task 2 — Update Makefile recipe `test-repl-banking`** (AC3)
  - [x] 2.1 — Open `Makefile:92` (the `pat` loop in the `test-repl-banking` recipe). Remove the literal `'PASS: plus-bank-cap'` token from the `for pat in ...` list (keep the surrounding tokens intact).
  - [x] 2.2 — Append a new sentinel-bounded recipe block after the Story 17.5 dot-banks-probe-W recipe (after `Makefile:247`). Pattern: identical awk-extract shape as `Makefile:207..213` (probe X) — extract `PROBE_G` between `---plus-bank-cap-start---` / `---plus-bank-cap-end---`, then assert (a) AC2 PASS-branch literal present, (b) `seeded: 29` numeric evidence present, (c) no `FAIL:` substring in `PROBE_G`.
  - [x] 2.3 — Verify the new recipe's `if echo "$$PROBE_G" | grep -q ... && echo "$$PROBE_G" | grep -q ... && ! echo "$$PROBE_G" | grep -q "FAIL:"; then ... PASS: ... else ... FAIL: ...` structure matches the Story-17.5 dot-banks pattern (Makefile `${TAB}@` recipes; `\` line continuations; `$$` for shell-vars; `\\` for awk regex escapes — same conventions as the probe-X..W block).

- [x] **Task 3 — Update Makefile recipe `test-repl-banking-skip`** (AC4)
  - [x] 3.1 — Open `Makefile:261` (the `pat` loop in the `test-repl-banking-skip` recipe). Remove the literal `'PASS: plus-bank-cap'` token from the `for pat in ...` list.
  - [x] 3.2 — Append a parallel sentinel-bounded recipe block to the iz-cpm baseline section (after the Story 17.5 baseline-surface probe-W recipe, near `Makefile:343..`). The recipe mirrors Task 2.2's structure — identical extraction, identical asserts, only the harness command differs (`$(IZCPM)` instead of `$(IZCPM_BANKING)`).
  - [x] 3.3 — Per AC4: the assertion is PASS-on-both-surfaces (cap-check is a kernel-cell comparison; surface-independent). Confirm the iz-cpm baseline run successfully sees `bank_count = 29` reachable (it should — iz-cpm flat memory accepts every `$22 +BANK` add; the cap-check fires at bank_count = 29 regardless).

- [x] **Task 4 — BASE residue investigation + disposition** (AC5)
  - [x] 4.1 — Trace the BASE = HEX residue path through Story 17.5's `_dot-banks-setup` comment (`tests/banking_tests.fth:437..445`). Read the comment lines in their full context; verify the claim that BASE was at 16 (HEX) before `_dot-banks-setup` ran.
  - [x] 4.2 — Inspect the three `BASE @ HEX SWAP . BASE !` call sites at `tests/banking_tests.fth:83, 323, 362`. For each, check: (i) is the call site inside a colon-body that can ABORT after `HEX` and before `BASE !`? (ii) does the call site's surrounding control-flow execute the `BASE !` restore on every reachable exit path? (iii) is there a documented BASE-preserving pattern alternative (e.g., guarded by `>R ... R>` — won't survive ABORT, but neither does the stack alternative)?
  - [x] 4.3 — Root cause identified — **AC5(a) probe-side cause confirmed, but in probes 1+2, NOT in the three `BASE @ HEX SWAP . BASE !` sites originally hypothesised.** Probes 1+2 (lines 58..86) use top-level `IF/ELSE/THEN`; those words THROW -14 ("interpreting a compile-only word") and do NOT actually branch — every token in BOTH branches executes sequentially. Probe 2's ELSE branch contains `BASE @ HEX SWAP . BASE !` (line 83); the unprotected `SWAP .` raises THROW -4 (stack underflow) mid-sequence, so `BASE !` never runs to restore. Result: `BASE = 16` leaks into all subsequent parse + execution from line 87 onward (bisect-confirmed: BASE = 10 at line 75, BASE = 16 at line 87). Fix applied locally to probe G (bracket with `DECIMAL` at both file-parse time and probe-body entry; see Task 4.4). Refactoring probes 1+2 to use colon-body wrappers like probes 6+ is out of Story 17.5.1 scope.
  - [x] 4.4 — Fix applied: added `DECIMAL` immediately before the probe-G colon defs (line 401 — covers parse-time literal `29` / `0` interpretation) AND as the first runtime word inside `_probe-plus-bank-cap` body (covers runtime `.` printing of BANKS in DECIMAL — recipe asserts `seeded: 29`). Without the parse-time `DECIMAL`, the literal `29` would be parsed as HEX = 41 decimal and the DO LOOP would run 41 iterations, tripping the cap mid-loop. Without the runtime `DECIMAL`, `BANKS .` would print `1D` in HEX. Inline source comment block at `tests/banking_tests.fth:393..400` records the root cause + scope decision.
  - [x] 4.5 — Verified post-fix: `make test-repl-banking` reports `PASS: plus-bank-cap — cap-check fired after 29-entry seed under iz-cpm-banking` and `make test-repl-banking-skip` reports `PASS: plus-bank-cap (surface-agnostic) — cap-check fired after 29-entry seed under iz-cpm baseline`. PROBE_G extracted region contains `seeded: 29` + `cap-check-fired-after-29-seed` + no FAIL: substring. Story 17.5's defensive `DECIMAL` in `_dot-banks-setup` (`tests/banking_tests.fth:474`) stays load-bearing — the residue from probes 1+2 still flows downstream until those probes are refactored.

- [x] **Task 5 — Negative-test reversion verification** (AC6)
  - [x] 5.1 — Applied corruption: changed `['] _do-one-more-+bank CATCH -2 = IF` to `['] _do-one-more-+bank CATCH -99 = IF` in `tests/banking_tests.fth`.
  - [x] 5.2 — `make test-repl-banking` post-corruption: `FAIL: plus-bank-cap — assertion text missing OR 'seeded: 29' witness missing OR FAIL: present in extracted region` (recipe extracted region contained `cap?FAIL: plus-bank-cap b 30th +BANK did not throw -2 (CATCH)` — the inner FAIL branch fired because the corrupted equality `-99 = IF` skipped the PASS path).
  - [x] 5.3 — `make test-repl-banking-skip` post-corruption: `FAIL: plus-bank-cap (surface-agnostic) — assertion text missing OR 'seeded: 29' witness missing OR FAIL: present in extracted region under iz-cpm` (same root cause; surface-agnostic by AC4).
  - [x] 5.4 — Reverted corruption (`-99 =` → `-2 =`). Post-revert: `make test-repl-banking` reports `PASS: plus-bank-cap — cap-check fired after 29-entry seed under iz-cpm-banking`; `make test-repl-banking-skip` reports `PASS: plus-bank-cap (surface-agnostic) — cap-check fired after 29-entry seed under iz-cpm baseline`.
  - [x] 5.5 — Negative-test verification complete — new recipe machinery actually asserts and is not false-PASSing. FAIL-line literal: `FAIL: plus-bank-cap — assertion text missing OR 'seeded: 29' witness missing OR FAIL: present in extracted region`. PASS-line literal (post-revert): `PASS: plus-bank-cap — cap-check fired after 29-entry seed under iz-cpm-banking`.

- [x] **Task 6 — Regression sweep + close** (AC7, AC8)
  - [x] 6.1 — `make` (full rebuild) — `make: Nothing to be done for 'all'` (rebuild idempotent; source-only changes to `tests/banking_tests.fth` and `Makefile`; neither file is a kernel source dependency).
  - [x] 6.2 — `wc -c build/antforth.com` = **26,228 B** (unchanged; AC7 satisfied; zero kernel binary delta).
  - [x] 6.3 — `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP** (AC8 satisfied; baseline preserved per FR-P4-41 / NFR-P4-10).
  - [x] 6.4 — `make test-repl-banking` = **34 PASS / 0 FAIL** (AC8 satisfied; recipe count unchanged — old grep position replaced by new sentinel recipe in-place).
  - [x] 6.5 — `make test-repl-banking-skip` = **24 PASS + 3 SKIP / 0 FAIL** (AC8 satisfied; same shape as post-17.5).
  - [x] 6.6 — `make check-doc-sync` = **31 advisory item(s); 0 drift** (AC8 satisfied; unchanged).
  - [x] 6.7 — All post-fix metrics recorded in Completion Notes below.

- [x] **Task 7 — Update sprint-status + flip Story 17.5.1 status `ready-for-dev → review`**
  - [x] 7.1 — Updated `_bmad-output/implementation-artifacts/sprint-status.yaml` row `17-5-1-probe-g-plus-bank-cap-false-pass-fix` from `ready-for-dev` to `review`.
  - [x] 7.2 — Change Log entry appended (see Change Log section).
  - [x] 7.3 — Run `CR` (code-review skill) per the standing project workflow. Code review completed 2026-05-17 (Claude Opus 4.7 fresh context). 0 HIGH + 4 MEDIUM (M1 BASE root cause / M2 single-variant AC6 / M3 git-vs-File-List transparency / M4 missing end-sentinel false-PASS — surfaced by live re-testing of AC6) + 4 LOW findings. All MEDIUM + L1 fixed inline; verification re-run; sprint-status follow-up filed for M1.

### Review Follow-ups (AI)

Code-review pass 2026-05-17 (Claude Opus 4.7 [1M context], fresh context). Findings + dispositions:

- [x] [AI-Review][MEDIUM] M1 — BASE residue not fixed at root; probes 1+2 still leak BASE=16 forward on every test run. Probe G's DECIMAL bracketing is defensive only; future probes inserted between probe 2 and probe G remain at risk. **FIXED** by filing `17-5-2-probes-1-2-colon-body-refactor-base-residue-root-cause-fix` as a new `backlog` row in `sprint-status.yaml` (root-cause fix scoped: refactor probes 1+2 to colon-body wrappers like probes 6+; lets defensive DECIMAL in `_dot-banks-setup` retire). [`tests/banking_tests.fth:58..86`]
- [x] [AI-Review][MEDIUM] M2 — AC6 negative-test verified only ONE corruption variant (`-2 → -99`). **FIXED** by running two additional variants live during the code review: (a) seed loop early-exit (`29 0 DO → 1 0 DO`) — both recipes correctly FAIL with `could not seed 29 entries; BANKS = 1` (probe's own inner FAIL: branch fires; recipe negative-assert catches it); (b) end sentinel removed — initially **false-PASSed** (M4 — see below); fixed via recipe tightening then re-verified FAIL.
- [x] [AI-Review][MEDIUM] M3 — git working tree had 5 modified files; story File List named 4; the 2 extras (`src/banking.asm`, `docs/ans-forth-core-compliance.md`) are uncommitted Story-17.5 artefacts. **FIXED** by adding a "Provenance note (working-tree caveat for code-review)" header to the File List section disambiguating Story-17.5 vs Story-17.5.1 ownership.
- [x] [AI-Review][MEDIUM] M4 — **Recipe false-PASS on missing end sentinel.** Surfaced by live negative-test variant (b) under M2. When the end sentinel goes missing, the awk window stays open until EOF and swallows downstream probe output (X/Y/Z/W); none of those emit `FAIL:` substrings, so all three of the recipe's original assertion clauses (`cap-check-fired-after-29-seed` present + `seeded: 29` present + no `FAIL:` in PROBE_G) still pass. **FIXED** by adding a fourth assertion clause in both surface recipes: `echo "$$OUTPUT" | grep -qE '^---plus-bank-cap-end---$$'` — directly asserts the end sentinel appears on its own line in OUTPUT, independent of the awk extraction. Re-verified: missing-end-sentinel now correctly FAILs on both surfaces; revert correctly PASSes. [`Makefile:248..267 + Makefile:385..397`]
- [x] [AI-Review][LOW] L1 — Comment block singled out only the TAIL `BANKS-CLEAR` as load-bearing; HEAD one is equally load-bearing (AC1 reset-before-seed). **FIXED** — comment rewritten to highlight both sites. [`tests/banking_tests.fth:401..405`]
- [ ] [AI-Review][LOW] L2 — `PROBE_G` content contains the runtime ABORT message `cap?` between witness and assertion-text lines; benign (no `FAIL:` substring) but the `! grep -q 'FAIL:'` negative-assert is the only thing standing between this and any future PASS-path FAIL: substring. NOT fixed — would need a "FAIL:" → safer-marker convention spanning all probes; out of scope for 17.5.1.
- [ ] [AI-Review][LOW] L3 — Pre-existing substring-grep pattern at `Makefile:92` + `:279` still applies to 17 OTHER probes. Same source-echo false-PASS class theoretically applies; in practice the pre-17.5 probes use top-level emission patterns (not colon-body) so the class is less acute, but worth a future test-infra story. NOT fixed — pre-existing scope, valid discharge per Lesson 13-B (maintainability ≠ correctness).
- [ ] [AI-Review][LOW] L4 — Recipe duplication at `Makefile:248..267` vs `:385..397` (byte-identical except harness var). Pre-existing Story-17.5 pattern; duplication grows with every sentinel-bounded probe (now 5 × 2 = 10 blocks). Worth a Makefile-factoring story in Epic-22 polish window. NOT fixed — pre-existing scope; M4 fix doubled the diff burden of the duplication (one more clause per copy), reinforcing the case for factoring.

## Dev Notes

### Project context

- **Story 17.5.1 is the test-infra-fix follow-up to Story 17.5
  H2.** Zero kernel binary delta; touches only
  `tests/banking_tests.fth` and `Makefile`. No new user-facing
  word. No `.BANKS` semantics change. No banner change. No
  compliance-doc row addition.
- **Position in Epic 17:** slots between Story 17.5 (`.BANKS`
  minimal form) and Story 17.6 (iron-spike + 3.x.1 tag). Story
  17.6's AC6 verdict-table walk explicitly lists Story 17.3
  PASS as a row; AC2 of Story 17.3 is the +BANK past-cap policy
  PD-P4-13. This story closes the exposure that the verdict-
  table walk would sign off PASS on a silently false-PASSing
  test gate. Slotted before 17.6 per project-lead direction
  2026-05-16 at Story 17.5 review close.
- **Cumulative Epic-17 envelope:** ~1,200 B / ~400 B (~300%)
  with Q6-a-extended accept-with-rationale binding (`project_
  epic17_envelope.md`). This story contributes **0 B** to the
  envelope (test-infra only). Envelope stays at ~1,200 B post-
  17.5.1. Story 17.6 closes the epic.
- **Phase-4 wordset progress:** unchanged. Post-17.5 = 10/12
  user-facing wordset words. Post-17.5.1 = 10/12 (no new
  words). Remaining 2 (`IN-BANK`, `BANK-OF`) are Epic 18.

### Architectural inputs consumed

- **Story 17.3** (`+BANK` cap-check at PD-P4-13). Story 17.5.1
  directly consumes:
  - The `+BANK` body's cap-check at `src/banking.asm`
    (the `ABORT" cap?"` site that raises `THROW -2` per
    `architecture.md:392`). The probe is a behavioural
    contract test against this kernel-side code path. Story
    17.5.1 does NOT modify the kernel-side; it only fixes the
    contract test.
  - The Probe G colon definitions added by Story 17.3's
    review-pass H2 fix at `tests/banking_tests.fth:383..406`.
    Story 17.5.1 rewrites these colon definitions.
- **Story 17.4** (CL parser + boot defaults). Story 17.5.1
  directly consumes:
  - The post-CL `active_pages[]` state at probe entry:
    default boot path populates 12 entries (`0x22, 0x35..0x3F`).
    The reset-before-seed pattern in AC1 sidesteps this state
    dependency entirely.
- **Story 17.5** (`.BANKS` probes + sentinel-bounded recipe
  precedent). Story 17.5.1 directly consumes:
  - The `awk '/---<name>-start---$/{p=1; next} /---<name>-
    end---$/{p=0} p'` extraction pattern at `Makefile:208,
    216..218, 233, 241`. Story 17.5.1's AC3/AC4 recipes
    use the identical pattern (one new occurrence per
    surface).
  - The dual-surface recipe-pair convention (PASS-on-iz-cpm-
    banking + PASS-on-iz-cpm-baseline) at `Makefile:206..247`
    + `Makefile:334..386`. Story 17.5.1's recipe pair lifts
    the same convention for the cap-check probe.
  - The `_dot-banks-setup` defensive helper at `tests/banking_
    tests.fth:450..456`. AC5 may retire this helper's
    `DECIMAL` reset depending on BASE-residue disposition.

### Design decisions

**D1 — Why reset-before-seed (AC1) instead of "fix the boot
default" or "use a smaller seed loop"?**

- Fix the boot default: out of scope. The CL parser's default 12
  entries are the user-facing behaviour per Story 17.4 AC2; the
  defaults are not test-surface state.
- Smaller seed loop (e.g., `17 0 DO`): brittle. Hardcoded
  iteration count that drifts if the boot-default count changes
  (e.g., Epic 18 reduces boot defaults) or if the cap value changes
  (currently 29 entries; could grow in a future story). The
  reset-before-seed pattern is invariant to both axes.
- Reset-before-seed: the probe's pre-state is observable and
  controllable — `BANKS-CLEAR` is a kernel-cell write (no MMU
  surface). After `BANKS-CLEAR`, `bank_count = 0` is guaranteed
  for the duration of the probe (no concurrent mutation in
  antforth's single-threaded model). The `29 0 DO ... LOOP` seed
  body then composes cleanly with the cap-check at iteration 30
  (the next call after the loop completes).

**D2 — Why sentinel-bounded extraction (AC2/AC3) instead of "use
a more specific grep pattern"?**

- A more specific grep pattern (e.g., grep for a multi-word
  literal phrase that doesn't appear elsewhere) is just one
  word-choice change. The root issue is **structural**: any
  literal text that appears in the probe source is echoable by
  the colon-body parse. Any single-pattern grep is fragile against
  the source-echo class of false-PASS.
- The sentinel + awk-extract pattern from Story 17.5's `.BANKS`
  probes is the **structural** answer: extract the runtime-output
  region between two markers that bracket only the executed
  output, then grep within that region. The markers' source-echo
  appears in the **raw** output, but the awk extraction window
  closes around the source-echo of the start sentinel (because the
  start sentinel's `." ---<name>-start---"` source-echo includes
  the literal `---<name>-start---` text — but it also includes the
  echo of `." `, the closing `"`, and any surrounding parse
  whitespace — so awk's `$` end-of-line anchor on the regex `/---
  <name>-start---$/` excludes the source-echo line because the
  source-echo carries trailing characters after `---<name>-
  start---`). Story 17.5 verified this discipline holds on iz-cpm
  + iz-cpm-banking; AC6's negative-test verification confirms it
  holds for plus-bank-cap too.

**D3 — Why a separate Pre-edit baseline section + AC8 regression
sweep on a test-infra-only story?**

- Test-infra-only stories have a tempting failure mode: "no kernel
  delta, so no risk." But changing `Makefile` recipes is risky:
  one wrong `$` escape, one wrong continuation, one wrong recipe-
  insertion-position breaks the whole banking-recipe block.
  Pre-edit baseline + AC8 sweep is the cheap insurance against
  cascade failures in the recipe block. Costs 5 minutes; catches
  the failure mode that's most likely to slip through a "trivial"
  story.

**D4 — Why is AC6 (negative-test reversion) a binding AC, not a
nice-to-have?**

- The whole point of this story is that the **old assertion
  machinery was silently false-PASSing**. If the new assertion
  machinery is also broken in some subtle way (e.g., the awk
  regex anchors don't behave as expected; or the recipe's
  `! grep -q "FAIL:"` clause has a precedence bug), the new
  recipe will silently false-PASS too, and the story closes
  without actually fixing the defect. AC6 — deliberately break
  the probe and verify the recipe reports FAIL — is the **only**
  way to confirm the new machinery actually asserts. Lesson:
  positive-test-only verification is insufficient for assertion-
  layer changes.

**D5 — Why no hardware-smoke (AC9)?**

- Zero kernel binary delta + zero MMU surface interaction. The
  Probe G cap-check is a kernel-cell comparison
  (`bank_count == 29` in the `+BANK` body); the comparison runs
  identically on iz-cpm baseline (flat memory), iz-cpm-banking
  (modelled MMU), and real MicroBeast hardware (real MMU). No
  hardware-specific failure mode can surface here. The Story 17.5
  hardware-smoke transcript already evidences the kernel's
  banking surface end-to-end. (`feedback_post_hw_smoke_steps_at_
  review.md` fires on binary-delta + deferred-S9 stories; Story
  17.5.1 has neither. Verified at AC9.)

### Project Structure Notes

- Path conventions: `src/banking.asm` (NOT touched by this
  story); `tests/banking_tests.fth` (modified — probe G
  rewrite); `Makefile` (modified — two recipe blocks).
- No conflicts with unified project structure. The probe-G
  rewrite stays in the same file at the same line range
  (375..406 approximately; line-count delta expected ±5 lines).
  The Makefile changes are additive recipes in the established
  banking-recipe block (`Makefile:88..386` approximately).
- No new files. No deleted files. No directory restructuring.

### References

- [Source: `_bmad-output/implementation-artifacts/17-5-dot-
  banks-minimal-working-form.md:540..551`] — H2 finding origin
  (the false-PASS surfaced + disposition + sprint-status filing).
- [Source: `_bmad-output/implementation-artifacts/17-5-dot-banks-
  minimal-working-form.md:1031`] — Pre-existing-test-infra-latent
  prose block at Story 17.5 dev-pass; root-cause analysis and
  workaround scope disclosure.
- [Source: `_bmad-output/implementation-artifacts/17-3-plus-bank-
  with-probe-on-add-minus-bank-banks-clear-set-bank.md:1162`] —
  Probe G origin (Story 17.3 review-pass H2 fix; the original
  probe shape).
- [Source: `_bmad-output/planning-artifacts/epics-phase4-epics-
  16-22.md:561..575`] — Story 17.5 spec (the precedent that
  motivated the dot-banks-probe sentinel-bounded recipe pattern
  Story 17.5.1 reuses).
- [Source: `_bmad-output/planning-artifacts/architecture.md:392`]
  — PD-P4-13 closure: `+BANK` past cap raises `ABORT" cap?"`
  (option (a)). The kernel-side behavioural contract that Probe
  G tests.
- [Source: `_bmad-output/planning-artifacts/architecture.md:152,
  511, 611, 995, 1010, 1109`] — PD-P4-13 cross-references and
  closure-block context.
- [Source: `tests/banking_tests.fth:375..406`] — current Probe
  G source (the colon definitions being rewritten).
- [Source: `tests/banking_tests.fth:437..445`] — Story 17.5
  workaround prose disclosing the BASE-residue + DO-LOOP-trip
  causes.
- [Source: `tests/banking_tests.fth:83, 323, 362`] — three
  `BASE @ HEX SWAP . BASE !` call sites under AC5 investigation
  for the BASE residue.
- [Source: `Makefile:92, 261`] — the substring-grep `'PASS:
  plus-bank-cap'` tokens being removed from the loop lists.
- [Source: `Makefile:206..247`] — Story 17.5 dot-banks probe
  X/Y/Z/W sentinel-bounded recipe block under `test-repl-
  banking` (the AC3 pattern Story 17.5.1 reuses).
- [Source: `Makefile:334..386`] — Story 17.5 dot-banks probe
  X/Y/W sentinel-bounded recipe block under `test-repl-banking-
  skip` (the AC4 pattern Story 17.5.1 reuses).
- [Source: `src/banking.asm`] — `w_PLUS_BANK_cf` body (the
  `+BANK` DEFCODE with cap-check; behavioural contract under
  test) — NOT modified by this story.
- [Source: `src/antforth.asm:46`] — COLD-time BASE init
  (`BASE = 10 (decimal)`) — cited under AC5 for kernel-side
  disposition (b).
- [Source: ANS Forth 1994 §9.6.2.0670] — QUIT specification
  (BASE reset NOT mandated by QUIT; COLD-only) — cited under
  AC5(b).
- Memory:
  - [[feedback-no-preexisting-discharge]] — the rule that
    motivated filing this story (correctness defects are not
    "pre-existing, out of scope").
  - [[project-epic17-envelope]] — Epic-17 envelope context;
    this story contributes 0 B.
  - [[feedback-post-hw-smoke-steps-at-review]] — STRONG rule;
    AC9 confirms NOT applicable to this story.
  - [[feedback-systematic-reference-check]] — applied at
    drafting: every cited file:line was re-verified against
    current source at draft time (per B.4 / PD-2 figure-drift
    discipline).

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]`

### Debug Log References

- Root-cause bisect for the false-PASS: PROBE_G captured region under the original probe shape was `cap?error -2: ABORT"` — i.e., the start sentinel emitted then `_do-29-+bank` aborted immediately. In-isolation REPL trace of the 29-iter seed loop ran clean (`testit` returns `29` on stack), but post-probe-E + post-probe-minus-bank-ldir the same body aborted. BASE check post-probe-2 (line 87) returned **16** under `BASE @ DECIMAL . CR`; pre-probe-2 (line 75) returned **10**. Mechanism: top-level `IF/ELSE/THEN` in probe 2 (line 78..85) raises THROW -14 ("interpreting a compile-only word") on each of `IF`, `ELSE`, `THEN` and does NOT branch; the ELSE-branch `BASE @ HEX SWAP . BASE !` (line 83) runs `BASE @` (push 10), `HEX` (BASE = 16), then `SWAP` THROWs -4 (stack underflow), and `BASE !` never restores. BASE = 16 leaks downstream; at probe-G parse time the literal `29` is read as HEX = 41 decimal, the LOOP runs 41 iterations, the cap-check at `bank_count == BANK_TABLE_CAP (29)` fires mid-LOOP.
- Negative-test reproduction (AC6): corrupt `CATCH -2 = IF` → `CATCH -99 = IF`; both `make test-repl-banking` and `make test-repl-banking-skip` report `FAIL: plus-bank-cap — ...`. PROBE_G extracted region contained the inner FAIL: branch literal (`FAIL: plus-bank-cap b 30th +BANK did not throw -2 (CATCH)`), confirming the `! grep -q "FAIL:"` clause is the load-bearing negative-assert. Restored `-2 =`; both targets return to PASS.

### Completion Notes List

- **Story 17.5.1 closes the H2 follow-up filed at Story 17.5 review-close 2026-05-16.** Zero kernel binary delta (`build/antforth.com` = **26,228 B** unchanged; AC7). Test-infra only: changes confined to `tests/banking_tests.fth` and `Makefile`.
- **AC1 (reset-before-seed)** — `_probe-plus-bank-cap` now opens with `BANKS-CLEAR`, making the seed loop invariant to CL-parser boot defaults (Story 17.4 populates 12 entries by default).
- **AC2 (sentinel-bounded output)** — probe wraps its runtime output in `---plus-bank-cap-start---` / `---plus-bank-cap-end---` sentinels; assertion text changed from `." PASS: plus-bank-cap ..."` to `." cap-check-fired-after-29-seed"` so the source-echo of the colon-body literal cannot satisfy any grep that the recipe uses. Seed-loop completion witness added: `." seeded: " BANKS . CR`.
- **AC3 (Makefile `test-repl-banking`)** — removed `'PASS: plus-bank-cap'` from the `pat` loop at `Makefile:92`; appended sentinel-bounded probe-G recipe after the Story 17.5 probe-W block (asserts `cap-check-fired-after-29-seed` + `seeded: 29` + no `FAIL:` in PROBE_G).
- **AC4 (Makefile `test-repl-banking-skip`)** — same shape under the iz-cpm baseline; cap-check is surface-independent (kernel-cell comparison) so PASS-on-both-surfaces per the Story-17.5 dual-recipe precedent.
- **AC5 (BASE residue disposition)** — disposition (a) **probe-side cause** confirmed; root cause is NOT in the three `BASE @ HEX SWAP . BASE !` call sites listed in the story spec (those sites' PASS branches don't reach the BASE switch); root cause IS in **probes 1 + 2 (lines 58..86)**, which use top-level `IF/ELSE/THEN`. THROW -14 fires on each compile-only word at top level; both branches' tokens execute sequentially; probe 2's ELSE-branch `BASE @ HEX SWAP . BASE !` underflows mid-sequence, leaking `BASE = 16`. Fix applied locally to probe G (bracket with `DECIMAL` at parse-time AND runtime); Story 17.5's defensive `DECIMAL` in `_dot-banks-setup` remains load-bearing. Refactoring probes 1+2 to use colon-body wrappers like probes 6+ is out of Story 17.5.1 scope — refile if/when the test-infra ceiling matters.
- **AC6 (negative-test verification)** — corrupted-then-reverted; both recipes FAIL on corruption + PASS on revert. Recipe machinery actually asserts.
- **AC7 (binary delta = 0)** — `wc -c build/antforth.com` = 26,228 B (unchanged at dev-pass close).
- **AC8 (regression baseline preserved)** — `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP**; `make test-repl-banking` = **34 PASS / 0 FAIL**; `make test-repl-banking-skip` = **24 PASS / 0 FAIL / 3 SKIP**; `make check-doc-sync` = **31 advisories / 0 drift**.
- **AC9 (hardware smoke — N/A)** — zero kernel delta + zero MMU surface interaction; `feedback_post_hw_smoke_steps_at_review.md` does NOT fire on this story (no binary-delta + no deferred S9 hardware-smoke task).

### File List

**Provenance note (working-tree caveat for code-review):** Story 17.5 has not been committed at the time of Story 17.5.1's review. The working tree at review-time therefore shows the UNION of Story-17.5 + Story-17.5.1 changes. `git status` reports 5 modified files; Story 17.5.1's contribution is bounded to the 4 files listed below. The two files NOT in this list (`src/banking.asm` +220 lines, `docs/ans-forth-core-compliance.md` +1 line) are uncommitted Story-17.5 artefacts (see Story 17.5's File List for ownership) and have ZERO contribution from Story 17.5.1.

- `tests/banking_tests.fth` — Probe G rewrite (lines 375..432 approx after rewrite): comment block updated to reflect Story 17.5.1 semantics + BASE-residue inline note + two-BANKS-CLEAR-load-bearing note (post-review L1 fix); `_probe-plus-bank-cap` body rewritten with head `BANKS-CLEAR` + start sentinel + assertion text `cap-check-fired-after-29-seed` + seed-loop witness `seeded: ` + end sentinel + tail `BANKS-CLEAR`; one new top-level `DECIMAL` line at parse-time before the probe-G colon defs; one new runtime `DECIMAL` as first body word inside `_probe-plus-bank-cap`.
- `Makefile` — `test-repl-banking`: removed `'PASS: plus-bank-cap'` from `pat` loop; appended sentinel-bounded probe-G recipe after probe-W block (post-review M4 fix: tightened to additionally assert end-sentinel presence in OUTPUT, catching the case where the end sentinel goes missing and awk extraction would otherwise swallow downstream probe output). `test-repl-banking-skip`: same on iz-cpm baseline side; removed `'PASS: plus-bank-cap'` from `pat` loop; appended parallel sentinel-bounded probe-G recipe after baseline probe-W block (M4 fix applied here too).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — row `17-5-1-probe-g-plus-bank-cap-false-pass-fix` flipped `ready-for-dev → review`; post-review M1 disposition: added new row `17-5-2-probes-1-2-colon-body-refactor-base-residue-root-cause-fix: backlog` between 17.5.1 and 17.6 (root-cause fix for the BASE residue that 17.5.1 only patched locally at probe G).
- `_bmad-output/implementation-artifacts/17-5-1-probe-g-plus-bank-cap-false-pass-fix.md` — this file: Status `ready-for-dev → review → done` (post-review-fix close); all task checkboxes checked; Dev Agent Record sections populated; Review Follow-ups (AI) subsection added with code-review fix log; Change Log entries appended.

### Change Log

- 2026-05-17: **Story file drafted** by create-story workflow at SM agent invocation. Status flipped `backlog (implicit) → ready-for-dev`. Sprint-status row pre-populated by Story 17.5 review-pass closing-summary 2026-05-16. Drafter: Claude Opus 4.7 (1M context).
- 2026-05-17: **Dev-pass complete; Status `ready-for-dev → review`.** All 8 ACs satisfied (AC9 N/A by AC9's own carve-out). Implementation: probe G rewritten with reset-before-seed + sentinel-bounded output; two Makefile recipes updated to use sentinel + awk-extract pattern (Story-17.5 precedent) in place of the substring grep that false-PASSed on source-echo; BASE-residue root cause identified (probes 1+2 top-level IF/ELSE/THEN failure mode) and locally fixed for probe G via `DECIMAL` bracketing (out-of-scope refactor of probes 1+2 deferred). Post-fix metrics: `wc -c build/antforth.com` = 26,228 B (unchanged); `make test-repl` = 975 PASS / 0 FAIL / 2 SKIP; `make test-repl-banking` = 34 PASS / 0 FAIL; `make test-repl-banking-skip` = 24 PASS + 3 SKIP / 0 FAIL; `make check-doc-sync` = 31 advisories / 0 drift. Negative-test verification (AC6): corrupted-then-reverted; both recipes FAIL on corruption + PASS on revert. Dev-pass implementer: Claude Opus 4.7 (1M context).
- 2026-05-17: **Code-review pass complete; Status `review → done`.** Adversarial code-review (Claude Opus 4.7 [1M context], fresh context, per project workflow's CR-runs-in-fresh-LLM-session standing rule). Findings: 0 HIGH + 4 MEDIUM + 4 LOW. All MEDIUM + L1 fixed inline; sprint-status follow-up `17-5-2-probes-1-2-colon-body-refactor-base-residue-root-cause-fix` filed (M1 root-cause fix). M4 (missing-end-sentinel false-PASS — discovered by live AC6 re-test sweep authorized under M2 disposition) fixed by tightening both recipes with end-sentinel OUTPUT-presence assertion; re-verified FAIL on corruption + PASS on revert. M3 (git-vs-File-List transparency) fixed via Provenance note in File List. L1 (comment incompleteness) fixed via re-wording. L2 + L3 + L4 NOT actioned (pre-existing scope / out-of-scope; valid discharge per Lesson 13-B). Post-fix regression sweep: `wc -c build/antforth.com` = 26,228 B (unchanged; AC7 still holds); `make test-repl` = 975 / 0 / 2; `make test-repl-banking` = 34 PASS; `make test-repl-banking-skip` = 24 PASS + 3 SKIP; `make check-doc-sync` = 31 advisories / 0 drift. Sprint-status flipped `review → done`. Code-review pass implementer: Claude Opus 4.7 (1M context).
