# Phase 3 Carry-Forward Catalogue

**Created:** 2026-05-07 (Epic 13.5 retro Action Item A1)
**Status:** Living document — update as items close or new debt is named

This document consolidates **all open carry-forward items** from Phase-2 retros (Epics 9–13.5) plus residual `docs/WISHLIST.md` ideas, into a single prioritised list. It supersedes scattered `⏳ Phase-3 carry-forward` notes in individual retros. The sources are listed per-item for traceability.

**Project lead direction (2026-05-07 retro):** focus Phase 3 on stabilisation + standards close-out (categories A + B) before any new feature work (category E). Tooling and ROM-pressure-only items (C + D) are deferred indefinitely — surface them only if a specific trigger fires.

---

## Priority Legend

- **P1** — Active. Should land in the first Phase-3 epic (or epics) before any new feature work
- **P2** — Later. Post-stabilisation; revisit when category A + B is mostly closed
- **P3** — Deferred indefinitely. Re-evaluate only if a specific trigger fires (ROM pressure, perf-claim dispute, etc.)

---

## A. Standards / Compliance — **P1**

| # | Item | Source | Estimated effort | Notes |
|---|------|--------|------------------|-------|
| A.1 | **§-by-§ ANS Forth Core re-audit.** Walk DPANS94 + Forth 2014 chapter-by-chapter, verify each mandatory rule against the implementation. Likely 0–2 §-level structural gaps to surface (Stories 13.0 / 13.0.1 / 13.5 are the back-fill template — one story per gap, paired with a compliance-doc row addition). | Epic 13 retro #6; `docs/WISHLIST.md` § "Phase-3 systematic §-by-§ ANS Forth Core re-audit" | 1 audit story + 0–2 back-fill stories per gap | The strategic Phase-3 piece. Closes the "word-counted survey blindness" category that surfaced §3.4.1.3 / §3.1.4.1 mid-Epic-13. |
| A.2 | **Caught-form coverage gap for asm-error THROW codes −258..−269.** Harness extension to `tests/throw_migration_tests.fth` exercising the caught-form path for each asm-error code. Unblocked since Story 11.5.3 closed the EVALUATE source-frame fix. | Epic 9 retro carry → Epic 11.5 unblocked → Epic 12 carry → Epic 13 carry | ~½ story (test-only) | Standalone; can hitch-hike onto any sprint touching the THROW-test file. |
| A.3 | **Unprefixed `NUMBER?` base-specialization.** Base-aware parsing for unprefixed numerals when an explicit BASE is set. | Epic 9 retro carry → Epic 12 → Epic 13 | Small | Standalone. |

## B. Stabilisation / Process Debt — **P1**

| # | Item | Source | Estimated effort | Notes |
|---|------|--------|------------------|-------|
| B.1 | **A2 — Document `PAD` as canonical transient-buffer word for test authors.** Closes the long-overdue Epic-12 retro Action Item A1 (TIB-128 doc note) belatedly, now that the Story-13.5.4 real `PAD` exists. Add a short `tests/README.md` or inline header comment block to `Makefile`'s test section. | Epic 13.5 retro A2 (and Epic-12 retro A1) | Small (doc-only) | Should land before the next REPL probe is authored for any subsequent epic. |
| B.2 | **A3 — Capstone-aware drafting refresher: "mirrors prior arm" is a HALT signal.** Story-template / drafting-checklist edit. When a story's byte-budget rationale rests on "this mirrors arm X from Story Y", the drafter must instead count the parts of the new arm independently. Extends Lesson 13-C. | Epic 13.5 retro A3 | Small (template edit) | Apply to story-template before any future "mirror"-shaped story is drafted. |
| B.3 | **A4 — Story-to-story binary handoff: re-`wc -c` at next story's start.** Story-template edit promoting the discipline that caught the 6-byte 13.5.5-close-out-doc drift to standing practice. Every dev-pass's "Pre-edit baseline" task captures `wc -c` itself, not the prior story's reported number. | Epic 13.5 retro A4 | Small (template edit) | Per-story; template-level. Should land alongside B.2. |
| B.4 | **PD-2 — Story-drafter figure drift** (story-template note, 2.x scope). | Epic 13 retro #1 | Medium (template + retro audit) | Should land before Phase-3 story-drafting starts. Sibling of B.2 and B.3 — these three together are the story-template-discipline cluster. |
| B.5 | **PD-3 — PRD-vs-architecture transcription drift** (doc-build sync step). | Epic 13 retro #2 | Medium (process / Makefile target) | Should land before next PRD/Architecture refresh — i.e. before the Phase-3 PRD is drafted. |
| B.6 | **PD-6 — iz-cpm version stability** (`make check-tools` target). | Epic 13 retro #3 | Small | Standalone; opportunistic. |
| B.7 | **F-7 — NFR8 stress-matrix coverage gaps** (directory-full, zero-byte READ-FILE). | Epic 13 retro #5 | ~1 story (test-only + maybe small fix) | If hardware reveals issues; also a 2.x maintenance candidate. |
| B.8 | **Test-numbering hygiene** — Makefile duplicate test numbers from Story 11.3. | Epic 13 retro #11 | Small (cosmetic) | Cosmetic; renumber on next Makefile-touching story. |
| B.9 | **Disk-full hardware re-verification** on real CP/M 2.2 / MicroBeast. | `project_phase2_scope.md` | Small (hardware test) | Standalone; opportunistic. |

---

## C. Tooling / Measurement — **P3 (deferred indefinitely)**

| # | Item | Source | Trigger to revisit |
|---|------|--------|--------------------|
| C.1 | **`make bench` infrastructure** for measurement-backed NFR2 verdicts. | Epic 12 retro #3 → Epic 13 retro #7 | If ROM pressure or perf-claim disputes surface; or pre-emptively before any perf-sensitive epic |

## D. ROM-pressure-triggered — **P3 (deferred indefinitely)**

| # | Item | Source | Estimated saving |
|---|------|--------|------------------|
| D.1 | **TD-9 — DMA pool size-reduction** (4 FCBs sharing 2 buffers) | Epic 13 retro #4 | ~512 B saved |
| D.2 | **`.S` migration to pictured output** | Epic 13 retro #10 | ~90 B saved |
| D.3 | **MARKER full-graph snapshot** (current behaviour is documented scope-pick) | Epic 12 retro TD #1 | Semantics expansion — non-urgent |
| D.4 | **WORDS scope-pick (a)** | Epic 12 retro TD #2 | Semantics expansion — non-urgent |

**Trigger to revisit C / D:** ROM headroom shrinks below working margin OR a specific perf-claim dispute / use-case requirement surfaces.

---

## E. Phase-3+ Features — **P2 (later, post-stabilisation)**

These are net-new feature ideas (not debt). Defer until A + B is substantially closed, then revisit which to scope into a Phase-3 feature epic.

| # | Item | Source | Estimated effort | Notes |
|---|------|--------|------------------|-------|
| E.1 | **MicroBeast hardware vocabulary** (system timer ISR, GPIO, board-specific) | `project_phase2_scope.md` | Medium-large (1 epic) | Strong fit with E.2 via timer-driven `PAUSE` |
| E.2 | **Multitasker** (polyForth/fig-Forth style; tasks yield with `PAUSE`; `TASK` / `ACTIVATE`) | `docs/WISHLIST.md` | Large (1 epic) | Could pair with E.1 for ISR-driven preemption-feel |
| E.3 | **Semaphores** (`SIGNAL` / `WAIT`) | `docs/WISHLIST.md` | Small (post-multitasker) | Depends on E.2 |
| E.4 | **`SEE` decompiler** | `docs/WISHLIST.md` | Medium | Likely depends on E.5 |
| E.5 | **`TRAVERSE-WORDLIST`** (ANS extension) | `docs/WISHLIST.md` | Small | Enables E.4 (SEE) + xref tools |
| E.6 | **ANS Forth Locals** (`{: a b -- c :}` or `VALUE` / `TO`) | `docs/WISHLIST.md` | Medium-large | Compiler surgery |
| E.7 | **Z80 IN / OUT primitives** | `docs/WISHLIST.md` | Small | Easy as code words; could hitch-hike onto E.1 |
| E.8 | **Compilation to .com binary** (Forth without outer interpreter; tree-shaking) | `docs/WISHLIST.md` | Large (separate tool / mode) | Strategic — shifts antforth's product positioning |
| E.9 | **OO** (need Pountain's book first) | `docs/WISHLIST.md` | Large; research-first | Strategic; uncertain |
| E.10 | **Beginner's guide** | `project_phase2_scope.md` | Medium (doc) | User-facing; pairs naturally with v2.0 launch publicity |
| E.11 | **Per-wordset reference doc** | `project_phase2_scope.md` | Medium-large (doc) | Reference doc for the now-shipped wordsets |

---

## Suggested Phase-3 First-Epic Shape

The 12 P1 items split naturally into a process-foundation lead-in followed by the standards re-audit work. Mirroring the Epic 13.5 PD-1-first sequencing pattern:

- **Lead-in (must land first):** B.1 + B.2 + B.3 + B.4 + B.5. Story-template / process-discipline edits (mostly small, doc-only). These shape every subsequent dev-pass in the epic.
- **Standards re-audit (the strategic body):** A.1 §-by-§ Core re-audit. One audit story; 0–2 back-fill stories per gap surfaced.
- **Hitch-hikers (can land in any story touching the relevant area):** A.2 caught-form THROW −258..−269 (any THROW-test sprint), A.3 unprefixed `NUMBER?` (any number-parsing sprint), B.6 `make check-tools` (any tooling sprint), B.8 test-numbering hygiene (next Makefile-touching story), B.9 disk-full hardware re-verification (any hardware-touching story).
- **Conditional:** B.7 NFR8 stress-matrix gaps if hardware reveals issues (otherwise 2.x maintenance).

This shape would frame the first Phase-3 epic as **"Phase-3 process-foundation + ANS Core §-by-§ re-audit + standalone debt close-out"** — comparable in shape to Epic 13.5 (process-recovery vehicle) and could close the residual carry-forward catalogue cleanly before any net-new feature epic starts.

---

## Status Tracking

Mark items as `✅ Done`, `🔄 In progress`, `❌ Dropped`, or leave default (open) as work proceeds. When an item closes, append a closure note (story reference + date) and leave the row in place as historical record.

| # | Status | Closure note |
|---|--------|--------------|
| B.1 | ✅ Done | Story 14.1 / 2026-05-08 — `tests/README.md` authored at project root; Makefile test-section pointer comment added; PAD-as-canonical guidance landed (ANS §6.2.2000 + §3.3.3.6); HERE-collision class documented (Story-13.5.1 / 13.6 F-9 / 13.5.4 references); S12 reference inline; verdict criteria 5/5 PASS. |
| (all other P1 + P2 items default to open) | | |
| (P3 items deferred until trigger fires — see C/D trigger note above) | | |
