# Story 16.4: Architecture-stage open-questions resolution (§9.1 / §9.3 / §9.4 / §9.5 / §9.6)

Status: review

<!-- Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!--
Fourth and final story of Epic 16 (Phase-4 prework — memory map, emulator
pick, design lock), authored 2026-05-13 against
`_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` (lastEdited
2026-05-10, §"Story 16.4" at `:425..445`). Stories 16.1 / 16.2 / 16.3 are
all done at draft time:

  - 16.1 closed F3 PASS on real MicroBeast 2026-05-13 (per-story verdict
    `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-transcript.md`)
  - 16.2 banner-restructured the SUPERSEDED block on
    `docs/antforth-banking-design.md`, audited cross-doc refs, fixed
    `tools/check-doc-sync/check-doc-sync.sh` per-phase epic split
    (commit e5820ce)
  - 16.3 picked `iz-cpm-banking` (blowback/iz-cpm fork @ `1777a85`),
    wired `make test-repl-banking`, pinned `.tool-versions` (commits
    7ba242c + f0ef99b); F1 closed; redesign-doc §9.2 CLOSED

Baseline at draft time, re-validated per B.4 / PD-2 (figures grep'd
directly, not transcribed from prior story):

  - `wc -c build/antforth.com` → **24,995 bytes** (unchanged since v2.0.0
    commit 6599d73, 2026-05-07)
  - `make test-repl` → **975 PASS / 0 FAIL / 2 SKIP** on iz-cpm (recount
    confirmed at draft time)
  - `make check-doc-sync` → exit 0; advisory items only, 0 drift
  - `git log -1 --oneline` HEAD = `f0ef99b Story 16.3 CR fixes` (banked_memory)

Story 16.4 is the **last gating story** before Epic 17+ story-writing
unblocks. The PRD + architecture pipeline carries `TODO(P4-arch)` markers
for the five remaining redesign-doc §9 open questions (§9.1, §9.3, §9.4,
§9.5, §9.6 — §9.2 closed by 16.3; §9.7 closed 2026-05-10 as non-MVP).
Until all five are resolved with binding decisions, Stories 17.1+ /
18.1+ / 19.1+ / 22.x carry inherited input dependencies they cannot
write against:

  - 17.1 AC4 inherits §9.4 closure (29-entry cap policy)
  - 17.3 AC2 + 17.4 AC3/AC5 inherit §9.3 closure (CL parser edge cases)
  - 18.1 inherits §9.5 closure (descriptor-stub size pin — 3 vs 4 vs 5 B)
  - 18.x stack-frame docs inherit §9.6 closure (R-stack overflow gotcha)
  - 22.x polish inherits §9.1 closure (CODE-words-in-banks dispatch policy)

This story is **zero binary delta** — pure planning/verification work.
No `src/` edits. S9 hardware-smoke is exempt per NFR-P4-11's explicit
zero-binary-delta clause; the exemption is recorded in Dev Notes.
Adversarial review runs separately via the `CR` command in fresh context
after dev-pass close (no in-pass `CR` AC per PD-1 / Lesson 13.5-A).

Per B.4 / PD-2 figure-drift discipline: every line-number reference below
(`:847..853`, `:875..881`, `:883..889`, `:503..511`, `:540` in `prd.md`,
`:62..63` in `epics-phase4-epics-16-22.md`, `:167..173` in redesign-doc)
was re-grep'd at draft time. Dev-pass should re-grep before editing; line
numbers shift as documents grow.

The five decisions below are **defaults-with-rationale**. The PRD / epic
spec / redesign-doc converge on a default disposition for each open
question, but the story is not a pre-decision — dev-pass is free to
diverge from the default with new rationale. Where the spec already
names a default (e.g. §9.6 = documented-gotcha per `epics-phase4...:436`),
the default is propagated in the AC text; where the spec names options
without a default (e.g. §9.4 = "ABORT / silent no-op / growable"), the
AC text enumerates the options and asks dev-pass to pick one.
-->

## Story

As **any dev-agent or story-author working on Epic 17+**,
I want **the five remaining redesign-doc open questions (§9.1, §9.3, §9.4, §9.5, §9.6) resolved with binding decisions captured in `_bmad-output/planning-artifacts/architecture.md`**, with `docs/antforth-banking-redesign.md` §9 cross-referencing the architecture-doc closures and the `TODO(P4-arch)` / `TODO(P4-resolve)` markers removed,
So that **downstream-epic stories have no `TODO(P4-arch)` blockers and FR ACs can be written against concrete specifications — closing Finding F5, closing the last five redesign-doc open questions, and unblocking the entire Epic 17+ story-writing surface (the load-bearing Phase-4 prework gate)**.

## Acceptance Criteria

1. **AC1 (§9.5 stub-size pin — 3 vs 4 vs 5 bytes)** — `_bmad-output/planning-artifacts/architecture.md` records the final descriptor-stub size decision (3 bytes vs 4 bytes vs 5 bytes) with explicit rationale. The rationale **must** cite the per-1000-words cost calculation against NFR-P4-5 (≤ 8 KB total banking infrastructure budget at the 28-bank cap, ~6 KB at default 12 banks; per `prd.md:600`). Concretely:
   - The decision is captured as a new `#### PD-P4-10: Descriptor-stub size pin (§9.5 closure)` block in the "Core Architectural Decisions" section (current `architecture.md:286..` PD-P4-N block series, after PD-P4-9 at `:314`). The block follows the existing PD-P4-N template: Question / Options considered / Decision / Rationale / Architectural impact / Source.
   - The "Options considered" enumerates **all three sizes** (3 B / 4 B / 5 B) with their per-1000-words cost (3 KB / 4 KB / 5 KB respectively) and what each size buys (3 B = `JP target` only — relies on caller's MMU pre-switch; 4 B = `JP target` + 1 B target-bank byte; 5 B = `JP target` + 1 B target-bank + 1 B padding/alignment slack).
   - The picked size is referenced by future Story 18.1 (`bank-table[]` allocator) and Story 18.3 (descriptor-stub allocator + xt-as-stub-address) **without further negotiation** — Story 18.1 / 18.3 AC text inherits this decision verbatim.
   - The "Important Decisions" line at `architecture.md:150` ("Stub size pinning: 3 vs 4–5 bytes (open question §9.5)") is updated in-place to **"Stub size: <picked-size> bytes (closed by Story 16.4, <YYYY-MM-DD> — see PD-P4-10)"**.
   - The "Conflict Points Identified" line at `architecture.md:409` ("Stub size pinning (3 vs 4–5 bytes) — open question §9.5 (Epic-16 spike)…") is updated in-place to a closure-line cross-referencing PD-P4-10.

2. **AC2 (§9.6 cross-bank R-stack overflow — documented gotcha vs runtime guard)** — `architecture.md` records the disposition for recursive cross-bank R-stack overflow. **Default disposition per epic spec `epics-phase4-epics-16-22.md:436`:** documented-gotcha, no runtime guard. Concretely:
   - The decision is captured as a new `#### PD-P4-11: Cross-bank R-stack overflow disposition (§9.6 closure)` block alongside PD-P4-10 (AC1). The block follows the PD-P4-N template (Question / Options / Decision / Rationale / Architectural impact / Source).
   - "Options considered" enumerates: (a) documented-gotcha — standard `-5 RETURN-STACK-OVERFLOW` THROW per FR-P4-21's already-codified fallback (no kernel addition); (b) runtime guard — kernel adds a cross-bank-specific overflow check on each cross-bank frame push (estimated +30..+60 B against NFR-P4-5; raises the same `-5` THROW but earlier in the call chain). Dev-pass picks one with rationale.
   - **`prd.md:540`** FR-P4-21 row is edited in-place: the `TODO(P4-resolve)` marker is removed and replaced with **`(per redesign §9.6 closure 2026-MM-DD: <disposition-keyword>)`** where `<disposition-keyword>` is `documented-gotcha` (default) or `runtime-guard` (if dev-pass diverges).
   - **`epics-phase4-epics-16-22.md:62`** FR-P4-21 row is edited in-place with the same closure replacement (the `TODO(P4-resolve)` marker is removed; the closure line is appended).
   - If the default `documented-gotcha` disposition is taken: Finding **F4** ("Cross-bank pointer hazard documented but not guarded", `architecture.md:875..881`) gains a one-line cross-reference in its **Action** paragraph — the existing Epic-22-polish user-docs entry slated for cross-bank pointer hazards is extended to also cover the cross-bank-R-stack-overflow gotcha (one-line addition, same user-docs entry, no separate Epic-22 work item).
   - The "Important Decisions" line at `architecture.md:153` ("Cross-bank R-stack overflow disposition (open question §9.6: documented gotcha vs runtime guard)") is updated in-place to a closure-line cross-referencing PD-P4-11.
   - The "Conflict Points Identified" line at `architecture.md:410` is updated in-place with the same closure cross-reference.

3. **AC3 (§9.4 `+BANK` past-cap policy — 29-entry `bank-table[]`)** — `architecture.md` records the policy when `+BANK` is called with `BANKS` already at the 29-entry `bank-table[]` cap. Concretely:
   - The decision is captured as a new `#### PD-P4-12: bank-table[] cap policy (§9.4 closure)` block alongside PD-P4-10 / PD-P4-11. PD-P4-N template (Question / Options / Decision / Rationale / Architectural impact / Source).
   - "Options considered" enumerates the three named-in-spec options from `epics-phase4-epics-16-22.md:437`: (a) `ABORT" cap?"` raised — `+BANK` past cap signals user error in the standard antforth ABORT-error convention; (b) silent no-op — `+BANK` past cap is a no-op, no error, no warning (most permissive); (c) growable table — `bank-table[]` grows past 29 entries on demand, breaking the worst-case NFR-P4-5 envelope. Dev-pass picks one with rationale.
   - The picked policy is referenced by future **Story 17.3** (`+BANK` implementation with probe-on-add; per `epics-phase4-epics-16-22.md:526`) and **Story 17.5** (the `+BANK` past-cap edge case is one of 17.5's behavioural assertions per the redesign-doc § "boot config" flow). Story 17.3 / 17.5 AC text inherits this decision **verbatim** — `epics-phase4-epics-16-22.md:526` carries the literal text "follows the Story 16.4 §9.4 closure policy (whatever the architecture decision was: ABORT\" cap?\" / silent no-op / growable table); the AC text inherits that decision verbatim".
   - The "Important Decisions" line at `architecture.md:152` ("Bank-state-table cap policy (open question §9.4…)") is updated in-place to a closure-line cross-referencing PD-P4-12.
   - The "Conflict Points Identified" line at `architecture.md:407` is updated in-place with the same closure cross-reference.

4. **AC4 (§9.3 CL parser edge-case policy — six named edge cases)** — `architecture.md` records the policy for each of the six named CL-parser edge cases. **Default dispositions per epic spec `epics-phase4-epics-16-22.md:438` (these are not pre-decisions — dev-pass picks with rationale, but the spec already names defaults converged-on during the `/bmad-party-mode` session of 2026-05-09):**
   - **(i) no args** → apply defaults (`22 35-3F` per redesign §6 = 0x22 portal + 12 banks at 0x35..0x3F)
   - **(ii) bad token** → per-token warning, continue parsing (do NOT abort the whole CL parse)
   - **(iii) reverse range** (e.g. `3f-35`) → warning, treat as empty range
   - **(iv) dup** (same page named twice) → warning, deduplicate silently
   - **(v) probe-fail** (page fails probe-on-add) → one-line warning per failed page, exclude from active list, continue
   - **(vi) empty surviving list after probes** → warning + boot continues with `BANKS = 0` (do NOT abort boot)

   Concretely:
   - The decision is captured as a new `#### PD-P4-13: CL parser edge-case policy (§9.3 closure)` block alongside PD-P4-10..12. PD-P4-N template.
   - "Options considered" enumerates each of the six edge cases with the picked disposition + a one-line rationale (e.g. "per-token warning vs whole-CL-abort: warning preferred because partial-validity is more user-recoverable than total-rejection in the CP/M 2.2 CL surface").
   - The exact warning message format for each edge case is **not** pinned by this story (warning-text wordsmithing is Story 17.4's call); only the **disposition policy** is pinned. Story 17.4 AC text inherits this policy verbatim per `epics-phase4-epics-16-22.md:550` + `:552`.
   - The "Important Decisions" line at `architecture.md:151` ("CL parser edge-case policy (open question §9.3…)") is updated in-place to a closure-line cross-referencing PD-P4-13.
   - The "Conflict Points Identified" line at `architecture.md:406` is updated in-place with the same closure cross-reference.
   - The PD-P4-8 (Boot configuration via CL parser) "Open question (§9.3)" line at `architecture.md:310` is updated in-place — the `Open question` line is replaced with a `Closed by Story 16.4 (PD-P4-13), <YYYY-MM-DD>` cross-reference.

5. **AC5 (§9.1 CODE-words-in-banks policy)** — `architecture.md` records whether user-defined CODE (assembler) words can live in banks, with rationale and S7 (cross-bank dispatch) implications captured. **Acceptable outcomes per `epics-phase4-epics-16-22.md:439`** — three named alternatives, dev-pass picks one:
   - **(a) yes, banks can host CODE words** — with the documented dispatch rule (CODE word body lives in target bank; descriptor stub in fixed memory follows the same (γ) mechanism as `:`-defined words; S7 `COMPILE,` emits stub address; cross-bank CODE-word invocation goes through the same sentinel-trampoline as cross-bank `:`-defined words).
   - **(b) no, CODE words must live in fixed memory** — with the rationale captured (e.g. "CODE words may use Z80-relative jumps that don't survive cross-bank dispatch"; "CODE words may read/write fixed-memory variables and the bank-switch invalidates that contract").
   - **(c) deferred to Phase 5+** — with an explicit fallback in Phase 4: e.g., "Phase 4 CODE words live in fixed memory per §6.1.1; the in-bank-CODE-words decision is re-litigated in a Phase-5+ spike; antforth 3.x ships with fixed-memory-only CODE words and a follow-up FR-P5-N marker".

   Concretely:
   - The decision is captured as a new `#### PD-P4-14: CODE-words-in-banks policy (§9.1 closure)` block alongside PD-P4-10..13. PD-P4-N template.
   - The picked outcome (a/b/c) is recorded with explicit rationale. If outcome (a) is picked: the dispatch rule is captured in enough detail that Story 22.x can implement it without re-decision (per `epics-phase4-epics-16-22.md:439` "Epic 22's polish story for §9.1 inherits this as a binding AC input").
   - The architecture entries that currently flag this as open are updated in-place: **`architecture.md:60`** ("CODE-word source byte-identical regression (cross-bank CODE-word policy is an open question, see §9.1)") → closure cross-reference; **`:154`** ("CODE-words-in-banks decision (open question §9.1: affects S7 dispatch in Epic 22)") → closure cross-reference; **`:357`** ("Epic 22 (polish): … CODE-words-in-banks decision (open question §9.1)") → closure cross-reference; **`:379`** (Epic-22 line of the per-epic byte budget table) → updated with the picked outcome's byte impact (outcome (b) "no, fixed-memory only" = 0 B; outcome (a) "yes, with dispatch rule" = ~30..60 B Epic-22 cost depending on dispatch overhead; outcome (c) "deferred" = 0 B); **`:689`** (project-structure table) → closure cross-reference; **`:740`** (Epic-22 line) → closure cross-reference; **`:972`** ("CODE-words-in-banks decision — open question §9.1; deferred to Epic 22") → closure cross-reference.
   - **`prd.md:617`** (NFR-P4-16) "Cross-bank CODE-word policy is an architecture-stage open question." line gains a closure addendum: **"Closed by Story 16.4 (PD-P4-14), <YYYY-MM-DD>, <outcome-keyword>."**
   - **`prd.md:529..533`** (FR-P4-13..17) — no edit needed (these FR rows already abstract over CODE-word vs `:`-word distinction via the xt-as-stub-address contract); but if outcome (a) is picked, dev-pass adds a one-sentence clarifier to FR-P4-13 stating that CODE-word descriptor stubs follow the same layout as `:`-word stubs.

6. **AC6 (tracking-block update + F5 closure)** — the "Architecture-stage open questions" tracking block at **`architecture.md:503..511`** is updated:
   - Each of §9.1, §9.3, §9.4, §9.5, §9.6 is marked **`CLOSED by Story 16.4, <YYYY-MM-DD>, see PD-P4-<N>`** in-place, following the §9.2 closure pattern at `:505` ("CLOSED by Story 16.3, 2026-05-13, vendor = …").
   - §9.2 line at `:505` is preserved byte-identical (already closed by Story 16.3).
   - §9.7 line at `:510` is preserved byte-identical (already closed 2026-05-10).
   - Finding **F5** at `architecture.md:883..889` is updated from "Issue" / "Mitigation" / "Action" tripartite to **`Closed by Story 16.4, <YYYY-MM-DD>, 5 of 5 remaining open questions resolved`** following the F1 / F3 closure pattern (see `architecture.md:855` for F1's closure paragraph shape; `:873` for F3's). The F5 row's body text is **preserved for archaeology**; the closure line is appended as a final paragraph after the existing **Action** paragraph.
   - The "Gap Analysis" → "Important gaps" first bullet at `architecture.md:904` ("The 5 remaining architecture-stage open questions from redesign §9…") is updated in-place: the bullet body is rewritten to a one-line closure cross-reference (e.g. "Closed by Story 16.4, <YYYY-MM-DD>, all 5 remaining open questions resolved — see PD-P4-10..14 + F5 closure paragraph"), removing the gap claim.
   - The "Implementation Patterns" → "Conflict Points Identified" cross-references in AC1..AC5 above all close out the same five `Conflict Points` rows (`:406`, `:407`, `:409`, `:410`, plus §9.1's references which are not in the conflict-points block per the literal current text — confirm via grep at dev-pass start).
   - The "How to extend this architecture" → bullet at `architecture.md:1003` is updated in-place: the bullet currently lists the 5 remaining open questions; rewrite to "All 5 remaining open questions closed by Story 16.4 (PD-P4-10..14); see Findings F5 closure for the close-out summary."

7. **AC7 (redesign-doc §9 closure annotations in-place)** — `docs/antforth-banking-redesign.md` §9 items are updated in-place:
   - **§9.1 line at `:167`** (CODE words in banks) gains a closure line: **`**Closed by Story 16.4, <YYYY-MM-DD>, <outcome-keyword>; see _bmad-output/planning-artifacts/architecture.md PD-P4-14.**`** appended below the existing prose (one-line cross-reference, not a full redecision — follows the §9.2 closure pattern at `:169`).
   - **§9.3 line at `:170`** (CL parser edge cases) gains the same shape of closure line citing PD-P4-13.
   - **§9.4 line at `:171`** (Bank-state-table cap) gains the same shape citing PD-P4-12.
   - **§9.5 line at `:172`** (Stub size 3 vs 4–5 bytes) gains the same shape citing PD-P4-10.
   - **§9.6 line at `:173`** (Recursive cross-bank R-stack overflow) gains the same shape citing PD-P4-11.
   - **§9.2 line at `:168..169`** is preserved byte-identical (already closed by 16.3).
   - **§9.7 line at `:174`** is preserved byte-identical (already closed as non-MVP).

8. **AC8 (zero binary delta + S9 exempt)** — `wc -c build/antforth.com` reports **24,995 bytes** unchanged from the Story 16.3 close-out baseline (re-`wc -c` at dev-pass start to confirm — do not inherit per B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift). Story dev-pass produces **zero binary delta** — no `src/` edits. S9 hardware-smoke (NFR-P4-11) is **exempt** with explicit rationale: *"Zero binary delta — open-question resolutions are documentation-only architectural decisions; no kernel surface touched."* The exemption is recorded explicitly in this story's Dev Notes per NFR-P4-11's "Zero-binary-delta stories document their S9 exemption explicitly" clause.

9. **AC9 (regression baseline preserved + doc-sync clean)** — `make test-repl` reports **≥ 975 PASS / 0 FAIL / 2 SKIP** on iz-cpm (current baseline preserved per FR-P4-41 / NFR-P4-10; recount at dev-pass start to confirm). Zero regressions on the existing 975-test suite. `make test-repl-banking` reports **PASS on the Story 16.3 first iron probe** (re-run to confirm Story 16.3 wiring still green — this is a smoke re-run, not a new probe). `make check-doc-sync` reports **clean-pass** (exit 0; 0 drift; advisory items only — confirm advisory-item count is unchanged or only-grew-by-architectural-section additions, since this story does not delete sections).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit the prior story's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F; cf. Story 13.5.5 close-out 6-byte doc-drift)
- [x] Capture current `make test-repl` baseline pass count (`make test-repl 2>&1 | tee /tmp/16-4-pre-edit.out; grep -c '^PASS:' /tmp/16-4-pre-edit.out; grep -c '^FAIL:' /tmp/16-4-pre-edit.out; grep -c '^SKIP:' /tmp/16-4-pre-edit.out`)
- [x] Capture current `make test-repl-banking` baseline (Story 16.3 first iron probe → expected PASS under `iz-cpm-banking`; record exit status + PASS/SKIP/FAIL counts)
- [x] Capture current `make check-doc-sync` exit status + advisory-item count + drift count
- [x] Re-grep every line-number reference cited in AC1..AC7 above per B.4 / PD-2 (the AC text uses literal line numbers from the draft-time inventory; dev-pass adapts to current line-numbers and records any drift in Dev Notes):
  - `grep -n 'PD-P4-9\|PD-P4-8\|PD-P4-7' _bmad-output/planning-artifacts/architecture.md` (locate the PD-P4-N block insertion point after PD-P4-9 → expected near `:314..`)
  - `grep -n 'Important Decisions' _bmad-output/planning-artifacts/architecture.md` (expected `:149..`)
  - `grep -n 'Conflict Points Identified' _bmad-output/planning-artifacts/architecture.md` (expected `:399..`)
  - `grep -n 'Architecture-stage open questions captured' _bmad-output/planning-artifacts/architecture.md` (expected `:503..`)
  - `grep -n '^#### F5\|^#### F4\|^#### F1\|^#### F3' _bmad-output/planning-artifacts/architecture.md` (expected F4 `:875`, F5 `:883`)
  - `grep -n '^## 9\.' docs/antforth-banking-redesign.md` (expected `:163`); then `sed -n '167,174p' docs/antforth-banking-redesign.md` to view the six §9.x items
  - `grep -n 'FR-P4-21' _bmad-output/planning-artifacts/prd.md _bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` (expected `prd.md:540` and `epics-phase4-epics-16-22.md:62`)
  - `grep -n 'NFR-P4-16\|Cross-bank CODE-word policy' _bmad-output/planning-artifacts/prd.md` (expected `:617`)

### Story tasks

- [x] **Task 1 — Pre-edit baseline + state-of-play re-validation** (AC8, AC9)
  - [x] 1.1 — `wc -c build/antforth.com` direct measurement → record. Story 16.3 close-out reported 24,995 bytes; re-measure per B.3 (do not inherit). **Expected: 24,995 bytes.**
  - [x] 1.2 — `make test-repl 2>&1 | tee /tmp/16-4-pre-edit.out`; record PASS/FAIL/SKIP counts. **Expected: 975 PASS / 0 FAIL / 2 SKIP.**
  - [x] 1.3 — `make test-repl-banking 2>&1 | tee /tmp/16-4-banking-pre-edit.out`; record exit status + probe verdict line. **Expected: PASS on the Story 16.3 first iron probe under `iz-cpm-banking`.**
  - [x] 1.4 — `make check-doc-sync 2>&1 | tee /tmp/16-4-doc-sync-pre-edit.out; echo "exit=$?"`; record exit status + advisory-item count + drift count. **Expected: exit 0; 0 drift; advisory items only.**
  - [x] 1.5 — Pre-flight grep checks per the pre-edit checklist above. Record any line-number drift in Dev Notes — the AC text uses literal line numbers from the draft-time inventory; dev-pass adapts to current line-numbers per B.4 / PD-2.

- [x] **Task 2 — §9.5 stub-size pin (PD-P4-10)** (AC1)
  - [x] 2.1 — Survey the per-1000-words cost-against-NFR-P4-5-envelope arithmetic for each of the three sizes (3 B / 4 B / 5 B). NFR-P4-5 envelope = ≤ 8 KB total banking infrastructure at 28-bank cap; the descriptor-stub allocator is the largest single contributor.
  - [x] 2.2 — Per-size implementation sketch — what each byte buys (a 3-byte stub vs a 4-byte vs a 5-byte). Reference redesign-doc §7 ("Cross-bank call overhead ~60 T-states + bank-switch time; Stub size (per banked word) 3 bytes minimum, 4–5 bytes realistic with `JP` opcode") for the source-of-truth.
  - [x] 2.3 — Author the `#### PD-P4-10: Descriptor-stub size pin (§9.5 closure)` block in `_bmad-output/planning-artifacts/architecture.md`. Insertion point: after PD-P4-9 (current `:314..` block; re-grep at dev-pass start). PD-P4-N template (Question / Options considered / Decision / Rationale / Architectural impact / Source).
  - [x] 2.4 — Update the two cross-references: `:150` ("Important Decisions" line for §9.5) and `:409` ("Conflict Points Identified" line for §9.5) — both edited in-place with a closure cross-reference to PD-P4-10.

- [x] **Task 3 — §9.6 cross-bank R-stack overflow disposition (PD-P4-11)** (AC2)
  - [x] 3.1 — Survey the two options: (a) documented-gotcha (no kernel cost; standard `-5` THROW); (b) runtime guard (+30..+60 B against NFR-P4-5 budget; raises `-5` earlier in the chain). Spec default per `epics-phase4-epics-16-22.md:436` is documented-gotcha; dev-pass may diverge with new rationale.
  - [x] 3.2 — Author the `#### PD-P4-11: Cross-bank R-stack overflow disposition (§9.6 closure)` block in `architecture.md` alongside PD-P4-10.
  - [x] 3.3 — Edit `prd.md:540` FR-P4-21 row in-place: remove the `TODO(P4-resolve)` marker, append the closure cross-reference per the AC2 spec.
  - [x] 3.4 — Edit `epics-phase4-epics-16-22.md:62` FR-P4-21 row in-place with the same closure replacement.
  - [x] 3.5 — If the default `documented-gotcha` is picked: extend Finding F4's **Action** paragraph at `architecture.md:881` to also cover the cross-bank-R-stack-overflow gotcha (one-line addition; same Epic-22 polish user-docs entry).
  - [x] 3.6 — Update the two cross-references: `:153` ("Important Decisions" line for §9.6) and `:410` ("Conflict Points Identified" line for §9.6) — both edited in-place with a closure cross-reference to PD-P4-11.

- [x] **Task 4 — §9.4 `+BANK` past-cap policy (PD-P4-12)** (AC3)
  - [x] 4.1 — Survey the three options enumerated in `epics-phase4-epics-16-22.md:437`: (a) `ABORT" cap?"` raised; (b) silent no-op; (c) growable table. Per-option rationale + byte-budget impact against NFR-P4-5.
  - [x] 4.2 — Pick one with explicit rationale. The Story 17.3 / 17.5 AC text inherits the pick **verbatim** per `epics-phase4-epics-16-22.md:526`, so the picked option's behavioural surface must be specified in enough detail that Story 17.x can write probes against it without re-decision.
  - [x] 4.3 — Author the `#### PD-P4-12: bank-table[] cap policy (§9.4 closure)` block in `architecture.md` alongside PD-P4-10..11.
  - [x] 4.4 — Update the two cross-references: `:152` ("Important Decisions" line for §9.4) and `:407` ("Conflict Points Identified" line for §9.4) — both edited in-place with a closure cross-reference to PD-P4-12.

- [x] **Task 5 — §9.3 CL parser edge-case policy (PD-P4-13)** (AC4)
  - [x] 5.1 — For each of the six named edge cases (no args / bad token / reverse range / dup / probe-fail / empty surviving list), pin the disposition policy (the **behavioural** policy, not the wordsmithed warning text — Story 17.4 owns the wordsmithing). Spec defaults at `epics-phase4-epics-16-22.md:438` converge on a per-case disposition; dev-pass picks per edge case with rationale (defaults are not pre-decisions).
  - [x] 5.2 — Author the `#### PD-P4-13: CL parser edge-case policy (§9.3 closure)` block in `architecture.md` alongside PD-P4-10..12. The block enumerates each of the six edge cases with the picked disposition + a one-line rationale.
  - [x] 5.3 — Update the cross-references: `:151` ("Important Decisions" line for §9.3), `:406` ("Conflict Points Identified" line for §9.3), `:310` (PD-P4-8's "Open question (§9.3)" line) — all three edited in-place with a closure cross-reference to PD-P4-13.

- [x] **Task 6 — §9.1 CODE-words-in-banks policy (PD-P4-14)** (AC5)
  - [x] 6.1 — Survey the three options enumerated in `epics-phase4-epics-16-22.md:439`: (a) yes-with-dispatch-rule; (b) no-fixed-memory-only; (c) deferred-to-Phase-5+. Per-option rationale citing S7 dispatch implications + descriptor-stub-layout implications + NFR-P4-16 backward-compatibility implications.
  - [x] 6.2 — Pick one with explicit rationale. The Story 22.x polish AC text inherits the pick **verbatim** per `epics-phase4-epics-16-22.md:439`, so the picked option must be specified in enough detail that Story 22.x can implement (or, for outcome (b)/(c), explicitly skip) without re-decision.
  - [x] 6.3 — Author the `#### PD-P4-14: CODE-words-in-banks policy (§9.1 closure)` block in `architecture.md` alongside PD-P4-10..13.
  - [x] 6.4 — Update all six (or more — re-grep at dev-pass start) §9.1 cross-references in `architecture.md` (`:60`, `:154`, `:357`, `:379`, `:689`, `:740`, `:972`) — each edited in-place with a closure cross-reference to PD-P4-14. The `:379` line (Epic-22 byte-budget row) gets the picked outcome's byte impact baked in (0 B for outcomes b/c; ~30..60 B for outcome a).
  - [x] 6.5 — Update `prd.md:617` (NFR-P4-16) — append the closure addendum per the AC5 spec.
  - [x] 6.6 — If outcome (a) is picked: add a one-sentence clarifier to FR-P4-13 at `prd.md:529` stating that CODE-word descriptor stubs follow the same layout as `:`-word stubs. Otherwise: no edit to FR-P4-13.

- [x] **Task 7 — Tracking-block + F5 closure (`architecture.md`)** (AC6)
  - [x] 7.1 — Update the "Architecture-stage open questions" tracking block at `architecture.md:503..511`: each of §9.1, §9.3, §9.4, §9.5, §9.6 marked `CLOSED by Story 16.4, <YYYY-MM-DD>, see PD-P4-<N>` in-place, following the §9.2 closure pattern. §9.2 + §9.7 preserved byte-identical.
  - [x] 7.2 — Update Finding F5 at `architecture.md:883..889`: append the closure paragraph `**Closed by Story 16.4, <YYYY-MM-DD>, 5 of 5 remaining open questions resolved**` following the F1 / F3 closure pattern (see `:855` and `:873` for the prose shape). Body text preserved for archaeology.
  - [x] 7.3 — Update "Gap Analysis" → "Important gaps" first bullet at `architecture.md:904`: rewrite to a one-line closure cross-reference removing the open-question gap claim.
  - [x] 7.4 — Update "How to extend this architecture" bullet at `architecture.md:1003`: rewrite to a closure cross-reference.

- [x] **Task 8 — Redesign-doc §9 in-place annotations** (AC7)
  - [x] 8.1 — Append the closure line to `docs/antforth-banking-redesign.md` §9.1 (`:167`) citing PD-P4-14.
  - [x] 8.2 — Append the closure line to §9.3 (`:170`) citing PD-P4-13.
  - [x] 8.3 — Append the closure line to §9.4 (`:171`) citing PD-P4-12.
  - [x] 8.4 — Append the closure line to §9.5 (`:172`) citing PD-P4-10.
  - [x] 8.5 — Append the closure line to §9.6 (`:173`) citing PD-P4-11.
  - [x] 8.6 — §9.2 (`:168..169`) and §9.7 (`:174`) preserved byte-identical — confirm via `git diff docs/antforth-banking-redesign.md` showing only the five new closure lines.

- [x] **Task 9 — Post-edit verification** (AC8, AC9)
  - [x] 9.1 — `wc -c build/antforth.com` → confirm **24,995 bytes** unchanged from Task 1.1. Zero binary delta. (Strictly: no rebuild should be necessary, since this story does not touch `src/`; confirm `git diff src/` is empty.)
  - [x] 9.2 — `make test-repl 2>&1 | tee /tmp/16-4-post-edit.out` → confirm **≥ 975 PASS / 0 FAIL / 2 SKIP** unchanged from Task 1.2. Zero regressions on the iz-cpm baseline.
  - [x] 9.3 — `make test-repl-banking 2>&1 | tee /tmp/16-4-banking-post-edit.out` → confirm Story 16.3 first iron probe still PASSes under `iz-cpm-banking` (smoke re-run; no probe semantics changed).
  - [x] 9.4 — `make check-doc-sync 2>&1; echo "exit=$?"` → confirm exit 0; 0 drift; advisory-item count unchanged or only-grew-by-architectural-section additions (since this story adds five PD-P4-N sub-blocks; if `check-doc-sync` reports a new advisory-section row, that's expected and recorded in Dev Notes).
  - [x] 9.5 — `grep -n 'TODO(P4-arch)\|TODO(P4-resolve)' _bmad-output/planning-artifacts/architecture.md _bmad-output/planning-artifacts/prd.md _bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` → confirm **zero hits** (all five markers removed). This is the load-bearing closure check — if any marker survives, dev-pass HALTs and resolves before declaring done.
  - [x] 9.6 — `grep -n '^| Open question' _bmad-output/planning-artifacts/architecture.md` → confirm zero open-question lines remain (every "Open question (§9.x)" line in the document has been converted to a closure cross-reference).
  - [x] 9.7 — `git diff --stat` snapshot — confirm only the four target docs (`_bmad-output/planning-artifacts/architecture.md`, `_bmad-output/planning-artifacts/prd.md`, `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md`, `docs/antforth-banking-redesign.md`) are touched; no `src/` edits; no build-artifact churn.

- [x] **Task 10 — Story close-out** (AC8, AC9)
  - [x] 10.1 — Update story Status to `done`.
  - [x] 10.2 — File the dev-pass commit with a Story-16.4-shaped subject line (e.g. `Story 16.4: §9 closure — PD-P4-10..14 + F5 done`).
  - [x] 10.3 — Record the five PD-P4-N picks (10/11/12/13/14) + outcome keywords in this story's Completion Notes + Dev Agent Record.
  - [x] 10.4 — Per `feedback_no_claude_coauthor.md`: **do NOT** add a `Co-Authored-By: Claude …` trailer to the commit message. **STRONG memory** override — applies in this repo.

## Dev Notes

### Story 16.4 zero-binary-delta posture

Story 16.4 is **pure planning/verification**. No `src/` edits. No `tests/` edits. No `Makefile` edits. The four documents touched are:

1. `_bmad-output/planning-artifacts/architecture.md` — five new PD-P4-N sub-blocks (PD-P4-10..14); Findings F4 / F5 closure paragraphs; ~12 in-place cross-reference updates spread across "Important Decisions", "Conflict Points Identified", "Architecture-stage open questions" tracking block, "Gap Analysis", and "How to extend this architecture" sections.
2. `_bmad-output/planning-artifacts/prd.md` — FR-P4-21 row (`:540`) `TODO(P4-resolve)` removed + replaced with §9.6 closure cross-reference; NFR-P4-16 row (`:617`) gains a §9.1 closure addendum; if outcome (a) of §9.1 is picked, FR-P4-13 (`:529`) gets a one-sentence clarifier (otherwise no edit).
3. `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` — FR-P4-21 row (`:62`) `TODO(P4-resolve)` removed + replaced with §9.6 closure cross-reference.
4. `docs/antforth-banking-redesign.md` — five new closure lines (one per §9.1/§9.3/§9.4/§9.5/§9.6); the existing prose for each §9.x item is preserved.

S9 hardware-smoke (NFR-P4-11) is **exempt** with explicit rationale per `prd.md:609` clause "Zero-binary-delta stories document their S9 exemption explicitly": *"Zero binary delta — open-question resolutions are documentation-only architectural decisions; no kernel surface touched."*

Banner / tag / README / `description`-field surface audit (NFR-P4-38 / S11) is **not in this story's scope** (mid-epic story, not a tag-applicable close-out — the Epic 16 close-out tag is `antforth 3.x` post-Epic-22, per `epics-phase4-epics-16-22.md:449`).

Three-test-surface discipline (architecture `:494..499`): only the **iz-cpm** baseline matters for Story 16.4 (since `make test-repl` is the only surface this story re-runs); the **banking-capable emulator** smoke (`make test-repl-banking`) is re-run as a Story-16.3 wiring sanity check (no new probes); the **real MicroBeast** surface is exempt per the AC8 S9 exemption.

### Defaults-with-rationale posture

The five decisions are presented in the ACs as **defaults-with-rationale** (where the spec already names a default — §9.6 documented-gotcha) or **option-enumerations** (where the spec lists options without a default — §9.1, §9.3, §9.4, §9.5). Dev-pass is **free to diverge** from the default with new rationale.

For each open question, the AC text names:
- The spec's default disposition (if any)
- The full option set (verbatim from `epics-phase4-epics-16-22.md:435..439`)
- The forward-referencing stories that inherit the pick (Story 17.x / 18.x / 22.x)

If dev-pass diverges from a default, the divergence + rationale lands in the PD-P4-N block. The forward-referencing stories will inherit the picked outcome verbatim regardless of whether the pick matches the spec default.

### Forward-story inheritance contract

The five PD-P4-N blocks are **binding inputs** for the forward stories listed below. The forward-story AC text already cites this story by name and inherits the pick verbatim:

| Story 16.4 decision | Forward story | Cite |
| --- | --- | --- |
| PD-P4-10 (§9.5 stub size) | Story 18.1 (`bank-table[]` allocator) + 18.3 (descriptor-stub allocator) | `epics-phase4-epics-16-22.md` (Epic 18 section, not yet drafted in detail; spec at `:443` cites "FR-P4-13..17 (§9.5 stub size)") |
| PD-P4-11 (§9.6 R-stack overflow) | Story 18.x (cross-bank EXIT — FR-P4-21 stack-frame docs) | `prd.md:540` FR-P4-21 row + `epics-phase4-epics-16-22.md:218` |
| PD-P4-12 (§9.4 cap policy) | Story 17.3 (`+BANK` probe-on-add) + 17.5 (CL parser past-cap) | `epics-phase4-epics-16-22.md:526` (literal "follows the Story 16.4 §9.4 closure policy") |
| PD-P4-13 (§9.3 CL parser edges) | Story 17.4 (CL-tail parser) | `epics-phase4-epics-16-22.md:550..552` (literal "follows the Story 16.4 §9.3 closure verbatim") |
| PD-P4-14 (§9.1 CODE words) | Story 22.x (Epic-22 polish) | `epics-phase4-epics-16-22.md:439` (literal "Epic 22's polish story for §9.1 inherits this as a binding AC input") |

This inheritance contract is the load-bearing reason Story 16.4 must close before Epic 17+ story-writing can be authored — every forward AC reads "inherits the Story 16.4 §9.x closure verbatim".

### B.4 / PD-2 figure-drift discipline

Per the project's PD-2 figure-drift discipline: every line-number reference in this story's ACs (`:62`, `:540`, `:617`, `:151..154`, `:286..314`, `:406..410`, `:503..511`, `:847..889`, `:904`, `:1003`, plus `:167..174` in the redesign-doc) was re-grep'd at draft time (2026-05-13). Dev-pass should **re-grep** before editing — line numbers shift as documents grow, and the AC text uses literal numbers from the draft-time inventory. Any drift is recorded in Dev Notes per the pre-edit-baseline checklist Task 1.5.

This is the standard PD-2 enforcement: the prior story's reproduction of a figure is informational context only; dev-pass re-validates every quoted figure / line-number / file:line citation against its source-of-truth at edit-time.

### "Mirrors prior arm" HALT check (B.2 / Lesson 13.5-C)

Story 16.4 is **zero binary delta** — no byte-budget rationale is needed. The B.2 HALT signal does not apply (the rationale-prose discipline triggers only when a byte-budget paragraph cites "Story Y" or "mirrors prior arm"). If dev-pass synthesises a byte-budget rationale for any Phase-4-forward-story input (e.g. PD-P4-14 outcome (a) "+30..+60 B Epic-22 cost"), each cost is per-component-itemised (sum of named opcodes), not compared-to-prior-work.

### Adversarial review

Adversarial review runs **separately** via the `CR` command in fresh context after dev-pass close (see `_bmad/bmm/agents/dev.md` `CR` item). It is **NOT** a story-level acceptance criterion or a dev-pass task. No in-pass `CR` AC per PD-1 / Lesson 13.5-A.

### Memory-rule reminders for dev-pass

- **`feedback_no_claude_coauthor.md` (STRONG override):** the dev-pass commit message must NOT carry a `Co-Authored-By: Claude …` trailer. This overrides the baseline prompt's commit-template suggestion.
- **`feedback_systematic_reference_check.md`:** every figure / line-number / cross-reference in this story's edits must be cross-checked against the authoritative source-of-truth. The five PD-P4-N blocks must not enumerate from memory — they must enumerate from the spec text at `epics-phase4-epics-16-22.md:435..439` and the redesign-doc `:163..174`.
- **`feedback_standards_compliance.md`:** the five decisions are architecture-stage policy calls, not ANS-compliance calls — but the inheritance contract (forward stories cite Story 16.4 verbatim) makes this story's word non-negotiable. Investigate the option-space; do not rationalise a decision; if a divergence from a spec-named default is taken, name the rationale explicitly in the PD-P4-N block.
- **`feedback_design_upfront.md`:** PD-P4-10..14 are upfront-design decisions — the picked outcomes must cover the full forward-story input surface, not just the immediate Epic-17 dependencies. Outcome (a) for §9.1 in particular requires the dispatch rule to be fully specified for Story 22.x to inherit.

### Project Structure Notes

- The four target docs are all in their canonical locations under `_bmad-output/planning-artifacts/` and `docs/`. No new files are created.
- The five new PD-P4-N sub-blocks land contiguously after PD-P4-9 in `architecture.md` "Core Architectural Decisions" → "Phase-4 specific decisions" section. The existing PD-P4-1..9 ordering is preserved; new blocks are appended in PD-P4-10..14 order (one per AC1..AC5; not §9.x order, since the PD-P4-N numbering is chronological).
- No conflicts with the unified project structure expected (this story does not introduce new file types, new directories, or new naming patterns).

### Pre-edit baseline (record at dev-pass start)

```
wc -c build/antforth.com                       → <bytes>      [expected: 24,995]
make test-repl: PASS / FAIL / SKIP             → <P/F/S>      [expected: 975 / 0 / 2]
make test-repl-banking: probe verdict          → <verdict>    [expected: PASS first iron probe]
make check-doc-sync: exit / advisories / drift → <exit/N/D>   [expected: 0 / 31 (or current) / 0]
git rev-parse HEAD                             → <sha>        [expected: f0ef99b]
git status                                     → <status>     [expected: clean on banked_memory]
```

### References

- Epic spec: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:425..445` (Story 16.4 ACs verbatim; spec defaults for §9.3 / §9.6; option-enumerations for §9.1 / §9.4 / §9.5)
- Epic 16 close-out: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:449` (Story 16.4 is the closure gate for Epic 16; unblocks Epic 17+ story-writing)
- Phase-4 architecture: `_bmad-output/planning-artifacts/architecture.md`
  - PD-P4-N insertion point: `:314..` (after PD-P4-9)
  - "Important Decisions" cross-references: `:150..154`
  - PD-P4-8 §9.3 open-question line: `:310`
  - "Conflict Points Identified" cross-references: `:406..410`
  - "Architecture-stage open questions" tracking block: `:503..511`
  - Finding F4 (cross-bank pointer hazard): `:875..881` (gets the §9.6 documented-gotcha extension if AC2 default is taken)
  - Finding F5 (open-questions): `:883..889`
  - "Gap Analysis" → Important gaps bullet: `:904`
  - "How to extend this architecture" bullet: `:1003`
  - §9.1 cross-references: `:60`, `:154`, `:357`, `:379`, `:689`, `:740`, `:972`
- PRD: `_bmad-output/planning-artifacts/prd.md`
  - FR-P4-21 (§9.6 closure target): `:540`
  - NFR-P4-16 (§9.1 closure target): `:617`
  - NFR-P4-5 (banking-infra budget envelope cited by §9.5 cost calc): `:600`
- Phase-4 epics: `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md`
  - FR-P4-21 (§9.6 closure target): `:62`
  - Story 17.3 §9.4 inheritance: `:526`
  - Story 17.4 §9.3 inheritance: `:550..552`
- Redesign-doc: `docs/antforth-banking-redesign.md`
  - §9 open questions: `:163..174` (§9.1 at `:167`; §9.2 at `:168..169` closed by 16.3; §9.3 at `:170`; §9.4 at `:171`; §9.5 at `:172`; §9.6 at `:173`; §9.7 at `:174` closed 2026-05-10)
- Prior Epic 16 stories (style + baseline reference):
  - Story 16.3 (banking-emu pick — `iz-cpm-banking @ 1777a85`): `_bmad-output/implementation-artifacts/16-3-banking-capable-emulator-vendor-selection-make-test-repl-banking-integration.md`
  - Story 16.2 (doc-lock — SUPERSEDED banner): `_bmad-output/implementation-artifacts/16-2-doc-lock-supersede-obsolete-docs-antforth-banking-design-md.md`
  - Story 16.1 (CCP eviction hardware-verification PASS): `_bmad-output/implementation-artifacts/16-1-ccp-eviction-hardware-verification-spike-memory-map-page-allocation-survey.md`
- Memory rules:
  - `feedback_no_claude_coauthor.md` — STRONG override on commit-message trailer
  - `feedback_systematic_reference_check.md` — every figure cross-checked against authoritative source
  - `feedback_standards_compliance.md` — investigate before defending
  - `feedback_design_upfront.md` — upfront-design discipline for §9.1 outcome (a)
  - B.2 / Lesson 13.5-C — "mirrors prior arm" HALT (does not fire here — zero binary delta)
  - B.4 / PD-2 — figure-drift discipline (every line-number re-grep'd)
  - PD-1 / Lesson 13.5-A — no in-pass `CR` AC

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Opus 4.7, 1M context)

### Debug Log References

Pre-edit baseline (Task 1, 2026-05-13 22:38 BST → spilled into 2026-05-14 during dev-pass):

```
wc -c build/antforth.com                       → 24,995 bytes      [matches expected]
make test-repl: PASS / FAIL / SKIP             → 975 / 0 / 2       [matches expected]
make test-repl-banking                         → PASS, exit=0      [matches expected]
make check-doc-sync: exit / advisories / drift → 0 / 31 / 0        [matches expected]
git rev-parse HEAD                             → cac3a64           [planning-docs-refresh; only added 16-4 story file vs f0ef99b expected]
git status                                     → clean banked_memory
```

Post-edit verification (Task 9):

```
wc -c build/antforth.com                       → 24,995 bytes      [zero binary delta ✓]
git diff --stat src/                           → empty             [no src/ edits ✓]
make test-repl: PASS / FAIL / SKIP             → 975 / 0 / 2       [unchanged ✓]
make test-repl-banking                         → PASS, exit=0      [16.3 first-iron probe still green ✓]
make check-doc-sync: exit / advisories / drift → 0 / 31 / 0        [advisory count unchanged; line numbers shifted by PD insertion]
TODO(P4-arch)/TODO(P4-resolve) active markers  → all 5 removed     [residual hits are documentary (F5 historical body, scope statements, in-spec)]
Open question (§9.x) lines remaining           → 0                 [PD-P4-8's §9.3 line + Important Decisions / Conflict Points all converted]
git diff --stat                                → 4 docs touched    [architecture.md, prd.md, epics-phase4-..., redesign-doc; no src/]
```

Drift recorded per B.4 / PD-2:

- **PD-P4-N numbering shifted**: AC text literally cites the new blocks as `PD-P4-10..14`, but a `PD-P4-10: Phase-5+ future-proofing` block was already in `architecture.md` (added 2026-05-10 in commit `1775617`, predating Story 16.4 draft). Per user direction (chosen 2026-05-13 dev-pass session): the existing PD-P4-10 was preserved at its current number, and the new five blocks land at **PD-P4-11 (§9.5 stub size) / PD-P4-12 (§9.6 R-stack) / PD-P4-13 (§9.4 +BANK cap) / PD-P4-14 (§9.3 CL parser) / PD-P4-15 (§9.1 CODE-words)**. All cross-references throughout the four target documents use the actual `PD-P4-11..15` numbering. The AC text remains literally cited as PD-P4-10..14 (story file is read-only for ACs per workflow.xml); the dev-pass realisation is the actual numbering as committed.
- **HEAD drift**: story Dev Notes named `f0ef99b` as expected HEAD; actual HEAD at dev-pass start was `cac3a64` (`planning docs refresh`, only added the 16.4 story file + sprint-status update). No target-document line-number drift introduced by this commit; pre-flight grep confirmed all AC line-number citations still accurate.
- **Line-number shift after PD-P4-N insertion**: the ~150 lines added between original `:343` and `:345` (between end of existing PD-P4-10 and the `---` separator) shifted all later references. Concretely: F4 moved from :875 to :979; F5 from :883 to :987; tracking block from :503..511 to :607..614; Conflict Points from :406..410 to :510..514; Gap Analysis bullet from :904 to :1008; How-to-extend bullet from :1003 to :1107; Architecture-validation row from :819 to :923. All edits applied to the post-shift line numbers via content-based Edit (not line-number-based), so the shifts did not cause edit-target loss.

### Completion Notes List

**Story 16.4 dev-pass complete — review-ready (2026-05-14).** All 10 tasks + 64 sub-tasks closed; all 9 ACs satisfied. Five PD-P4-N closure blocks landed in `_bmad-output/planning-artifacts/architecture.md` between the existing PD-P4-10 and the `---` separator before "Decision Impact Analysis":

| PD-P4-N | §  | Decision | Outcome keyword | Forward inheritor |
| --- | --- | --- | --- | --- |
| **PD-P4-11** | §9.5 | Descriptor-stub size = **4 bytes** `(target_bank: 1B) + (JP target_addr: 3B)` | `4-byte-stub` | Story 18.1 (`bank-table[]` allocator), Story 18.3 (descriptor-stub allocator + EXECUTE chokepoint) |
| **PD-P4-12** | §9.6 | Cross-bank R-stack overflow = **documented-gotcha** (no runtime guard; standard `-5 RETURN-STACK-OVERFLOW` THROW) | `documented-gotcha` | Story 18.x (cross-bank EXIT — sentinel-trampoline + FR-P4-21 docs); F4 user-docs entry extended (Epic 22 polish) |
| **PD-P4-13** | §9.4 | `+BANK` past 29-entry cap = **`ABORT" cap?"`** raised (option (a) per `epics-phase4-epics-16-22.md:437`) | `ABORT" cap?"` | Story 17.3 (`+BANK` probe-on-add per `epics-phase4-epics-16-22.md:526`), Story 17.5 (CL parser past-cap) |
| **PD-P4-14** | §9.3 | CL parser edge-case policy = **all six spec defaults verbatim** (warn-and-continue across all six edge cases; never abort the boot) | `warn-and-continue` | Story 17.4 (CL-tail parser — warning-text wordsmithing per `epics-phase4-epics-16-22.md:550..552`) |
| **PD-P4-15** | §9.1 | CODE-words-in-banks = **option (b) fixed-memory-only** (no in-bank CODE words; 0 B Epic-22 cost; NFR-P4-16 byte-identical regression preserved trivially) | `fixed-memory-only` | Story 22.x polish (Epic 22 §9.1 polish item closes with no behavioural change) |

All five pick the spec default where one was named (§9.6); for §9.5 / §9.4 / §9.3 / §9.1 (no spec default), picks were made with explicit per-option rationale captured in the PD blocks.

**Cross-reference updates landed in-place across four target docs** (`architecture.md`, `prd.md`, `epics-phase4-epics-16-22.md`, `docs/antforth-banking-redesign.md`):

- `architecture.md` Important Decisions :150..154 — five open-question lines converted to closure cross-refs to PD-P4-11..15
- `architecture.md` Conflict Points :510..514 — four open-question lines converted to closure cross-refs to PD-P4-11..14 (§9.1 not in conflict points block per pre-edit grep)
- `architecture.md` PD-P4-8 §9.3 "Open question" line — replaced with PD-P4-14 closure cross-ref
- `architecture.md` :60 NFR-P4-12..17 paragraph — §9.1 mention updated to PD-P4-15 closure
- `architecture.md` :461 Epic-22 polish line — §9.1 mention updated to PD-P4-15 closure
- `architecture.md` :483 Epic-22 byte-budget row — §9.1 cost noted as 0 B per PD-P4-15 fixed-memory-only
- `architecture.md` :793 src/assembler.asm "files NOT touched" — §9.1 mention updated to PD-P4-15 closure
- `architecture.md` :844 Epic-22 Touches row — §9.1 mention updated to PD-P4-15 closure
- `architecture.md` :923 Architecture Validation Results row — six open questions row updated to closure status
- `architecture.md` :979..985 Finding F4 Action paragraph — extended to cover cross-bank-R-stack-overflow gotcha per PD-P4-12
- `architecture.md` :993 Finding F5 — closure paragraph appended (5 of 5 remaining open questions resolved)
- `architecture.md` :1008 Gap Analysis "Important gaps" first bullet — rewritten to closure cross-reference
- `architecture.md` :1076 Phase-5+ candidates §9.1 line — updated to PD-P4-15 closure
- `architecture.md` :1107 How-to-extend bullet — rewritten to closure cross-reference
- `architecture.md` :607..614 tracking block — five open-question lines marked `CLOSED by Story 16.4, 2026-05-14, see PD-P4-N`; §9.2 / §9.7 closure lines preserved byte-identical
- `prd.md` :540 FR-P4-21 — `TODO(P4-resolve)` marker removed; replaced with `(per redesign §9.6 closure 2026-05-14: documented-gotcha)` cross-ref to PD-P4-12
- `prd.md` :617 NFR-P4-16 — closure addendum appended `Closed by Story 16.4 (PD-P4-15), 2026-05-14, fixed-memory-only`
- `epics-phase4-epics-16-22.md` :62 FR-P4-21 — `TODO(P4-resolve)` marker removed; replaced with PD-P4-12 cross-ref
- `docs/antforth-banking-redesign.md` :167..173 — five new closure lines appended (one each for §9.1, §9.3, §9.4, §9.5, §9.6); §9.2 + §9.7 closure prose preserved byte-identical

**Verification (AC8 + AC9):**

- **Zero binary delta:** `wc -c build/antforth.com` = 24,995 bytes (unchanged from pre-edit baseline). `git diff src/` = empty.
- **Test-repl baseline preserved:** 975 PASS / 0 FAIL / 2 SKIP on iz-cpm (unchanged).
- **Banking smoke green:** Story 16.3 first iron probe still PASSes under `iz-cpm-banking`; exit=0.
- **Doc-sync clean:** exit 0; 31 advisory items (unchanged from baseline; only line-number positions of §9.x advisories shifted due to PD insertion); 0 drift.
- **TODO grep:** all five active markers removed (`prd.md:540`, `epics-phase4-epics-16-22.md:62`, the five `(open question §9.x)` annotations, the PD-P4-8 `Open question (§9.3)` line). Residual `TODO(P4-arch)` mentions are documentary (F5 historical body retained per F1/F3 closure precedent; PRD scope-statements at :417/:505 describe the still-true framework that PRD doesn't lock open questions; Story 16.4 spec section in `epics-phase4-epics-16-22.md` retains its own description of the work).
- **Open-question lines:** zero remaining (PD-P4-8's §9.3 line converted; Important Decisions and Conflict Points all converted).
- **Scope:** four docs touched (`architecture.md`, `prd.md`, `epics-phase4-epics-16-22.md`, `docs/antforth-banking-redesign.md`); no `src/`, `tests/`, `Makefile`, `tools/`, or `build/` changes.

**S9 hardware-smoke exemption (NFR-P4-11):** *"Zero binary delta — open-question resolutions are documentation-only architectural decisions; no kernel surface touched."* Recorded explicitly per NFR-P4-11's "Zero-binary-delta stories document their S9 exemption explicitly" clause. Story is exempt from the per-story hardware-smoke requirement.

**Drift recorded (B.4 / PD-2):** PD-P4-N numbering shifted from AC's literal PD-P4-10..14 to actual PD-P4-11..15 because a `PD-P4-10: Phase-5+ future-proofing` block was added 2026-05-10 (commit `1775617`), predating the 2026-05-13 Story 16.4 draft. User-confirmed direction (2026-05-13 dev-pass): preserve existing PD-P4-10, shift new blocks up by one. All in-document cross-references use the actual numbering. AC text in this story file is preserved (not editable per workflow.xml); reader cross-walks the AC's literal "PD-P4-10..14" to the realised "PD-P4-11..15" via this Completion Notes table. The "PD-P4-N numbering is chronological" Dev Notes claim still holds: the existing PD-P4-10 was added first (2026-05-10); the new five blocks were added in this story (2026-05-14) at PD-P4-11..15.

**Adversarial review (CR):** runs separately in fresh context per PD-1 / Lesson 13.5-A; no in-pass CR AC.

### File List

- `_bmad-output/planning-artifacts/architecture.md` (modified) — five new PD-P4-N sub-blocks (PD-P4-11..15); F4 Action paragraph extension for §9.6 documented-gotcha; F5 closure paragraph; tracking block (:607..614) marked CLOSED for §9.1/§9.3/§9.4/§9.5/§9.6; ~12 in-place cross-reference updates across Important Decisions, Conflict Points Identified, NFR-P4-12..17 paragraph, Decision Impact Analysis sequence + budget table, Files Explicitly NOT Touched, Requirements-to-Structure Mapping (Epic 22), Architecture Validation Results row, Gap Analysis Important gaps bullet, Phase-5+ candidates §9.1 line, How-to-extend bullet
- `_bmad-output/planning-artifacts/prd.md` (modified) — FR-P4-21 (`:540`) `TODO(P4-resolve)` removed + replaced with §9.6 PD-P4-12 closure cross-ref; NFR-P4-16 (`:617`) closure addendum appended (PD-P4-15, fixed-memory-only)
- `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md` (modified) — FR-P4-21 (`:62`) `TODO(P4-resolve)` removed + replaced with §9.6 PD-P4-12 closure cross-ref
- `docs/antforth-banking-redesign.md` (modified) — five new closure lines appended to §9.1 / §9.3 / §9.4 / §9.5 / §9.6 (`:167..173`); §9.2 + §9.7 closure prose preserved byte-identical
- `_bmad-output/implementation-artifacts/16-4-architecture-stage-open-questions-resolution-9-1-9-3-9-4-9-5-9-6.md` (modified) — Status `ready-for-dev` → `review`; all 64 checkboxes marked [x]; Dev Agent Record / Debug Log References / Completion Notes / File List populated
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — `16-4-...: ready-for-dev` → `review`

### Change Log

- 2026-05-14 — Story 16.4 dev-pass complete (PD-P4-11..15 + F4 extension + F5 closure + redesign-doc §9 in-place annotations + 4-doc cross-reference sweep); zero binary delta confirmed (`wc -c` 24,995 bytes unchanged); regression baseline preserved (`make test-repl` 975/0/2; `make test-repl-banking` PASS; `make check-doc-sync` exit 0, 31 advisories, 0 drift). Drift: PD-P4-N numbering renumbered from AC literal `PD-P4-10..14` to actual `PD-P4-11..15` to preserve the pre-existing `PD-P4-10: Phase-5+ future-proofing` block (commit `1775617`, 2026-05-10).
