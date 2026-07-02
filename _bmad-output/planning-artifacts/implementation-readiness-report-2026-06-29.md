---
stepsCompleted: ['step-01-document-discovery', 'step-02-prd-analysis', 'step-03-epic-coverage-validation', 'step-04-ux-alignment', 'step-05-epic-quality-review', 'step-06-final-assessment']
lastStep: 6
phase: 6
phaseTitle: 'Concurrency & On-Device Applications'
date: '2026-06-29'
status: 'complete'
verdict: 'READY'
inputDocuments:
  - _bmad-output/planning-artifacts/prd-phase6-concurrency.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-06-29
**Project:** antforth
**Phase:** 6 — Concurrency & On-Device Applications (Epics 24–26)

## Step 1 — Document Inventory

| Type | File | Disposition |
|---|---|---|
| PRD | `prd-phase6-concurrency.md` | ✅ selected (ratified; 26 FR / 17 NFR) |
| Architecture | `architecture.md` | ✅ selected (Phase-6, status complete; AD-P6-1..9) |
| Epics & Stories | `epics-phase6-epics-24-26.md` | ✅ selected (3 epics / 13 stories) |
| UX Design | — | N/A (no GUI; PRD skips visual_design) |

**Duplicates:** none (no whole-vs-sharded conflicts). Prior-phase docs
(`prd.md`, `architecture-phase1..4-*.md`, `epics-phase1..5-*.md`, etc.) are
intentional per-phase archives, excluded from this Phase-6 assessment.

**Missing required documents:** none.

## PRD Analysis

Source: `prd-phase6-concurrency.md` (read in full). 26 FRs / 17 NFRs.

### Functional Requirements (26)

**Task Lifecycle**
- FR1: Operator creates a task, allocating its control block + private stacks.
- FR2: Operator assigns a word to a task and starts it running concurrently.
- FR3: Operator suspends a running task and resumes a suspended one.
- FR4: A completed task becomes inactive without affecting other tasks.
- FR5: Existing single-task programs run unchanged when no extra task active; boot session = default operator task.

**Cooperative Scheduling**
- FR6: A task can voluntarily yield to the next ready task.
- FR7: Scheduler selects next runnable task round-robin, skipping suspended tasks.
- FR8: All active tasks make forward progress provided each yields.
- FR9: When only one task is active, scheduling doesn't change its observable behavior.

**REPL Concurrency**
- FR10: Operator continues entering/evaluating Forth while background tasks run.
- FR11: Input-waiting ops (KEY/KEY?/ACCEPT) yield instead of busy-waiting.
- FR12: Output operations interleave safely; terminal stays usable.

**Timing**
- FR13: Install a 64 Hz timer handler maintaining a monotonic tick count.
- FR14: A task delays N seconds without freezing other tasks or the REPL.
- FR15: Delays are per-task; concurrent delays don't interfere.
- FR16: Operator reads the current tick count.

**Coordination (Growth)**
- FR17: Coordinate access via counting semaphores (SIGNAL/WAIT).
- FR18: Protect a shared resource with a mutex.
- FR19: Pass a value between tasks via a one-slot mailbox.

**Robustness**
- FR20: Uncaught error in a background task suspends only that task; REPL + others continue.
- FR21: Operator recovers a faulted task (inspect, redefine, re-activate) without restart.
- FR22: A non-yielding task produces an observable, documented stall; operator can break in from keyboard.

**Banking-Aware State**
- FR23: A task runs code in any bank; bank context preserved across yields.
- FR24: Compilation remains a single shared operator-task activity.

**Introspection & Demo**
- FR25: Operator lists current tasks and their state.
- FR26: User loads the traffic-light demo as a background task while using the REPL (headline acceptance).

### Non-Functional Requirements (17)

- **Performance:** NFR-P6-1 bounded switch latency (+per-bank MBB cost measured); NFR-P6-2 DELAY ±1 tick/s (60 DELAY = 60 s ±1 s); NFR-P6-3 REPL responsiveness; NFR-P6-4 bounded ISR cost.
- **Reliability:** NFR-P6-5 zero regression (v3.1.0 baseline 0 FAIL); NFR-P6-6 S9 hardware smoke per binary-delta story; NFR-P6-7 fault containment; NFR-P6-8 deterministic round-robin.
- **Resource:** NFR-P6-9 per-task RAM documented (TCB + 256+256 B); NFR-P6-10 binary-size envelope tracked; NFR-P6-11 scheduler+ISR+TCB fit fixed memory below $8000.
- **Compatibility:** NFR-P6-12 backward compat (single-task identical); NFR-P6-13 BIOS-only contract (MBB_*, no MMU ports); NFR-P6-14 emulator/hardware parity.
- **Maintainability:** NFR-P6-15 S1–S12 hold; NFR-P6-16 test-through-threading (REPL-piped); NFR-P6-17 probe safety ($8000 straddle + TIB limits).

### Additional Requirements / Constraints

- Brownfield (no init story); BIOS entry points MBB_SET_USR_INT (0xFDC7),
  MBB_SET_PAGE/GET_PAGE (0xFDDF/0xFDDC); cooperative-only switch model;
  shared dictionary / operator-only compile; per-task bank in TCB;
  fixed-memory-switch-first bring-up.

### PRD Completeness Assessment

Complete and implementation-grade: every FR is testable; NFRs carry concrete
thresholds (±1 s, 0 FAIL, below $8000); MVP/Growth tiers and locked decisions
are explicit; open technical choices were resolved in the architecture. No
ambiguous or unbounded requirements found.

## Epic Coverage Validation

Source: `epics-phase6-epics-24-26.md` (read in full; 3 epics / 13 stories).
Each PRD FR traced to the specific story that implements it.

### Coverage Matrix

| FR | Requirement (short) | Story | Status |
|---|---|---|---|
| FR1 | Create task + stacks | 25.1 | ✓ Covered |
| FR2 | Assign word + run concurrently | 25.1 | ✓ Covered |
| FR3 | Suspend / resume task | 25.4 | ✓ Covered |
| FR4 | Completed task inactive | 25.1 (epilogue) | ✓ Covered |
| FR5 | Single-task unchanged | 25.1 | ✓ Covered |
| FR6 | Voluntary yield | 25.1 | ✓ Covered |
| FR7 | Round-robin skip suspended | 25.1 + 25.4 | ✓ Covered |
| FR8 | Cooperative fairness | 25.1 | ✓ Covered |
| FR9 | One-task no observable change | 25.1 | ✓ Covered |
| FR10 | Type while tasks run | 25.2 | ✓ Covered |
| FR11 | Input ops yield | 25.2 | ✓ Covered |
| FR12 | Output interleaves safely | 25.2 | ✓ Covered |
| FR13 | Install 64 Hz timer + tick | 24.1 | ✓ Covered |
| FR14 | DELAY without freezing | 25.3 | ✓ Covered |
| FR15 | Per-task delays | 25.3 | ✓ Covered |
| FR16 | Read tick count | 24.1 | ✓ Covered |
| FR17 | Counting semaphores | 26.1 | ✓ Covered |
| FR18 | Mutex | 26.2 | ✓ Covered |
| FR19 | One-slot mailbox | 26.3 | ✓ Covered |
| FR20 | Uncaught error suspends only that task | 25.6 | ✓ Covered |
| FR21 | Recover faulted task | 25.6 | ✓ Covered |
| FR22 | Documented stall + keyboard break | 25.7 | ✓ Covered |
| FR23 | Run in any bank, preserved | 25.5 | ✓ Covered |
| FR24 | Operator-only compile | 25.5 | ✓ Covered |
| FR25 | List tasks + state | 25.4 | ✓ Covered |
| FR26 | Background traffic-light + live REPL | 25.8 | ✓ Covered |

### Missing Requirements

None. All 26 PRD FRs trace to a story. No story implements a capability absent
from the PRD (no scope creep) — the dropped GPIO/beeper item (former 24.3) was a
Growth/Vision extra, not a PRD FR, so its removal leaves coverage intact.

### Coverage Statistics

- Total PRD FRs: **26**
- FRs covered in epics/stories: **26**
- Coverage: **100%**
- NFR handling: all 17 NFRs carried as ACs/obligations across stories (regression,
  S9 hardware-smoke, binary-delta, switch-cost measurement, BIOS-contract).

## UX Alignment Assessment

### UX Document Status

**Not found — and not required (N/A).** antforth is a terminal-REPL Forth
interpreter on bare MicroBeast hardware; there is no GUI, web, or mobile surface.
The PRD explicitly skips `visual_design` / `store_compliance` / `browser_support`
under its `developer_tool_embedded` classification. A formal UX document is
genuinely not applicable here — this is **not** a missing-but-implied warning.

### Alignment Issues

None. The terminal-interaction dimension that *does* exist (live `ok>` prompt
responsiveness, `.TASKS` output, legible `task N: error <n>` notices, `4 DELAY`
not freezing the prompt) is specified in the PRD user journeys and addressed in
the architecture: AD-P6-6 (input-yield/EMIT-no-yield + keyboard break), AD-P6-4
(notice format matching the existing `error <n>: <desc>` style), and FR25/.TASKS.

### Warnings

None. No UI is implied that the architecture fails to support.

## Epic Quality Review

Rigorous validation against create-epics-and-stories standards (user value,
independence, no forward deps, sizing, AC quality, brownfield handling).

### Epic-level

- **User value (not technical milestones):** ✅ All three epics name a user
  capability — Timer (time things), Multitasker (run background tasks),
  Coordination (safe sharing). No "setup DB / API layer" technical-milestone epics.
- **Independence / no forward dependency:** ✅ 24 standalone; 25 builds on 24
  (backward, allowed) and does NOT require 26; 26 builds on 25. No epic requires a
  *later* epic. Note: a hard cross-epic ordering exists — **24 must precede
  Story 25.3** (yielding `DELAY` upgrades 24.2). Expected and backward; sprint
  sequencing must respect 24 → 25.
- **Brownfield handling:** ✅ Correct — architecture specifies no starter template,
  so there is correctly no init story; FR5 (single-task-unchanged compatibility)
  lives in 25.1; stories integrate with existing subsystems (banking, exception,
  IN/OUT). The TCB STRUCT is created in 25.1 (first story needing it), not a
  separate upfront "create all structures" story (entity-when-needed ✅).

### Story-level

- **Forward dependencies (within epic):** ✅ None. Verified each story depends only
  on earlier ones: 24.1→24.2; 25.1 foundational → 25.2..25.8 each backward
  (25.6's `.TASKS` ref is to 25.4 ◀; 25.6's re-ACTIVATE is to 25.1 ◀); 26.1→26.2/26.3.
- **AC quality:** ✅ All stories use Given/When/Then, are testable, and include
  error/edge conditions (25.1 $8000-guard THROW; 25.6 operator-vs-background
  disposition; 25.7 non-yielding stall; 24.1 32-bit carry) with concrete
  thresholds (`60 DELAY` = 60 s ±1 s). Process gates (binary-delta, S9) are ACs.

### Findings

**🔴 Critical:** none.

**🟠 Major:** none.

**🟡 Minor / advisory:**
- **M1 — Story 25.1 is heavy.** It bundles `PAUSE` + ring + TCB STRUCT + `TASK` +
  `ACTIVATE` + completion epilogue + COLD wiring + the $8000 guard + FR5 compat.
  It is a coherent unit (the minimal testable scheduler bring-up) and completable,
  but at the upper bound for one dev session. *Recommendation:* the SM may split it
  at `create-story` into 25.1a (scheduler core: `PAUSE`+ring+TCB+COLD with a
  hardcoded test task) and 25.1b (`TASK`/`ACTIVATE`/epilogue + $8000 guard). Already
  flagged in `sprint-status.yaml`. Optional, not blocking.
- **M2 — Two ACs use qualitative NFR language** ("without perceptible lag",
  NFR-P6-3). Acceptable: they mirror the PRD's own qualitative NFR and are
  hardware-verified at S9; no tightening required, but note they are judgment calls
  at review time.
- **M3 — Cross-epic ordering 24 → 25.3** (see Epic-level). Document in the sprint
  so 24.1/24.2 land before 25.3.

### Best-Practices Compliance Checklist

- [x] Epics deliver user value
- [x] Epics function independently (no forward-epic dependency)
- [x] Stories appropriately sized (one advisory: M1)
- [x] No forward dependencies within epics
- [x] Entities (TCB) created when needed, not upfront
- [x] Clear, testable acceptance criteria
- [x] Traceability to FRs maintained (100%, Step 3)

## Summary and Recommendations

### Overall Readiness Status

**READY** ✅ — Phase 6 is cleared for implementation.

| Dimension | Result |
|---|---|
| Document completeness | PRD + Architecture + Epics all complete; UX N/A |
| FR coverage | 26 / 26 (100%) traced to specific stories |
| NFR handling | All 17 carried as story ACs / process obligations |
| Epic structure | User-value epics, independent, no forward deps |
| Critical / Major issues | **0** |
| Minor advisories | 3 (none blocking) |

### Critical Issues Requiring Immediate Action

None. No critical or major defects were found in the planning artifacts.

### Minor Advisories (address during sprint, not blocking)

1. **M1 — Story 25.1 heaviness:** consider splitting into 25.1a (scheduler core)
   + 25.1b (TASK/ACTIVATE + $8000 guard) at `create-story`. Optional.
2. **M3 — Cross-epic ordering:** sequence Epic 24 (24.1/24.2) before Story 25.3
   (yielding `DELAY` upgrade). Already reflected in the dependency order 24→25.
3. **M2 — Qualitative ACs** (NFR-P6-3 "no perceptible lag") are S9-hardware-verified
   judgment calls; acceptable as-is.

### Carry-Forwards from the Architecture (to settle at sprint/story time)

- **F4 — TCB fixed-RAM budget:** measure per-task cost against the bank-0
  `kernel_end..$8000` budget; the `TASK` $8000 guard (Story 25.1 AC) is the
  mechanism. Noted in `sprint-status.yaml`.
- **F5 — Binary-size envelope:** agree the per-epic byte budget (≈2.4×
  prior-phase pattern) before Epic 25 dev. Noted in `sprint-status.yaml`.

### Recommended Next Steps

1. (Optional) Decide the M1 25.1 split now or defer to `create-story`.
2. Run `create-story` for **Story 24.1** (64 Hz timer + `TICKS`) — the natural
   first build, no dependencies — flipping it to `ready-for-dev`.
3. Settle F4/F5 numbers when Epic 25 work begins.

### Final Note

This assessment found **0 critical / 0 major** issues and **3 minor advisories**
across 5 validation categories. Phase 6 planning is internally consistent,
fully traceable, and implementation-ready. No remediation is required before
proceeding; the advisories can be handled inline during sprint execution.

**Assessor:** Implementation Readiness workflow · **Date:** 2026-06-29
