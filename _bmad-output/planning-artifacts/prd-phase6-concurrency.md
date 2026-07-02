---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
lastEdited: '2026-06-29'
workflowType: 'prd'
phase: 6
phaseTitle: 'Concurrency & On-Device Applications'
outputPathOverride: 'prd-phase6-concurrency.md (chosen 2026-06-28: leave Phase-4 prd.md untouched)'
classification:
  projectType: developer_tool_embedded
  domain: general
  complexity: low
  projectContext: brownfield
inputDocuments:
  - _bmad-output/planning-artifacts/phase6-proposal-concurrency-2026-06-28.md
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-05-08.md
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/prd-phase3-epics-14-15.md
  - _bmad-output/planning-artifacts/architecture.md
  - docs/WISHLIST.md
  - docs/register-conventions.md
  - docs/throw-codes.md
  - docs/antforth-banking-redesign.md
  - docs/banking-pointer-hazards.md
documentCounts:
  briefCount: 1
  researchCount: 0
  brainstormingCount: 1
  projectDocsCount: 5
---

# Product Requirements Document - antforth

**Phase:** 6 — Concurrency & On-Device Applications
**Author:** Ant
**Date:** 2026-06-28

## Executive Summary

antforth is an ANS-compliant Forth interpreter and interactive development
environment built from scratch in Z80 assembly for the MicroBeast retrocomputer
(8 MHz Z80, 512 KB banked RAM/ROM, CP/M 2.2). Five phases have shipped: v2.0.0
(2026-05-07); the Phase-3 debt-cleanup interlude; Phase-4 banked-RAM enablement
(antforth 3.x point-releases); and Phase 5 — the ANS-conformance + ergonomics
round (Epic 23, v3.1.0, closed 2026-06-28) that delivered built-in `IN`/`OUT`
port words and `VALUE`/`TO`.

This PRD scopes **Phase 6 — Concurrency & On-Device Applications** — antforth's
transition from a single-threaded interactive Forth into a cooperative-
multitasking platform on which background hardware tasks run while the REPL stays
live. Phase 6 ships a `PAUSE`-based cooperative multitasker (`TASK` / `ACTIVATE`,
`KEY`-hooked REPL), promotes the MicroBeast's 64 Hz system-timer interrupt into a
yielding `DELAY` / timer wordset, and adds counting semaphores for inter-task
coordination — three interlocking epics with the multitasker as the spine.

**Phase-numbering note:** earlier planning docs (`prd.md:118`,
`architecture.md:339`) label this work "Phase 5", predating actual events —
Phase 5 shipped as Epic 23. The concurrency bundle is therefore **Phase 6**, with
epics continuing from Epic 23 (provisional Epics 24–26).

### What Makes This Special

- **Live REPL + background hardware, on an 8-bit machine.** Load the traffic-light
  demo (`disk/a/TRAFFIC.FTH`) as a background task and keep working at the `ok>`
  prompt while the LEDs cycle on tempo. Cooperative multitasking with a live
  terminal, under standard ANS Forth dispatch, with banking-aware task state —
  uncommon in the Z80 Forth space.
- **The architecture insists on cooperative.** The register-based inner
  interpreter (BC = TOS, IX = return stack) has phantom mid-primitive states;
  preemption would snapshot them and corrupt a task. Cooperative `PAUSE` switches
  only at word boundaries, where the register model is coherent. The constraint is
  the design.
- **Pre-de-risked.** The hardest interaction — banking vs. per-task state — was
  deliberately future-proofed in the 2026-05-09 design session ("bank = 1 byte of
  TCB"). Phase 6 builds to an intent already on record, not a green field.
- **The pieces are on the bench.** v3.1.0 shipped the hardware primitives
  (`IN`/`OUT`); the 64 Hz timer ISR was prototyped in the Phase-5 traffic-light
  tutorial. The multitasker assembles existing parts into something demoable.

## Project Classification

- **Project Type:** `developer_tool_embedded` — hybrid tripping both
  `developer_tool` (interactive language, API surface, examples) and `iot_embedded`
  (device, hardware, real-time, power) signals.
- **Domain:** `general` — no regulatory or systemic complexity.
- **Complexity:** `low` (systemic). Implementation intricacy is high but
  Z80-assembly-local (task-switch register juggling, banking dispatch, exception
  isolation), not systemic — consistent with the Phase-4 framing.
- **Project Context:** `brownfield` — five phases shipped; Phase 6 builds on the
  v3.1.0 baseline under the standing regression discipline (close-out test baseline
  maintained; per-story hardware smoke).

## Success Criteria

### User Success

Phase 6 is a hobbyist/educational capability release; "users" are Forth
hobbyists, retro tinkerers, and tutorial readers on real MicroBeast hardware.

- A user loads `disk/a/TRAFFIC.FTH` as a background task (`TASK` + `ACTIVATE`)
  and the LEDs cycle on tempo **while the `ok>` prompt stays responsive** — they
  type and evaluate words with the background task running. This is the "aha".
- A user writes `4 DELAY` and it **does not freeze the terminal** — the REPL and
  other tasks keep running during the wait.
- A user coordinates two tasks over a shared resource with `SIGNAL` / `WAIT` with
  no corruption or deadlock in the documented patterns.
- Failure modes are legible: a task that never yields visibly stalls cooperation
  (documented as expected), and an uncaught error in a background task does not
  kill the operator's REPL.

### Business Success

N/A — antforth is a hobby / learning project with no commercial objectives.
Non-commercial framing for Phase 6:

- **New capability class.** First multitasking Z80 Forth in this lineage —
  concurrent on-device apps without sacrificing the live REPL or ANS dispatch.
- **Community-signal event.** "antforth multitasks — background hardware with a
  live REPL on an 8-bit machine" is an announcement-worthy follow-up to v3.1.0.
- **Tutorial leverage.** A sequel to the Phase-5 traffic-light tutorial: the same
  hardware running as a background task — a screenshot-friendly hook for Forth.

### Technical Success

- Cooperative round-robin scheduler; `PAUSE` switches only at word boundaries;
  `TASK` / `ACTIVATE` / `WAKE` / `SLEEP` operational.
- `KEY` / `EMIT` / `KEY?` call `PAUSE` so the REPL participates in scheduling.
- **Per-task bank** saved/restored across `PAUSE` (re-paged via `MBB_SET_PAGE`);
  cross-bank task switching verified on real hardware.
- **Exception isolation:** an uncaught `THROW` in a background task suspends that
  task, not the scheduler.
- Counting semaphores (`SIGNAL` / `WAIT`), mutex, mailbox; correct under the
  documented single-threaded-except-ISR model.
- **Zero regressions:** the v3.1.0 close-out test baseline keeps passing under the
  multitasking build; per-story hardware smoke (S9) PASSES on real CP/M 2.2 /
  MicroBeast for every binary-delta story.
- Context-switch overhead (including the per-bank page call) measured + documented.

### Measurable Outcomes

| Indicator | v3.1.0 baseline | Phase 6 target |
|---|---|---|
| `make test-repl` passing | v3.1.0 close-out baseline / 0 FAIL | ≥ baseline / 0 FAIL under multitasking build; concurrency probes added |
| Live-REPL-while-background-task demo | n/a (single-threaded) | PASS on hardware (prompt responsive + lights on tempo) |
| Yielding `DELAY` | busy-wait (Phase-5 prototype) | yields via `PAUSE`; per-task; stopwatch ±1 s at 64 ticks/s |
| Per-bank task switch | n/a | verified on hardware; switch overhead documented |
| Exception isolation | n/a | background `THROW` does not kill REPL (probe) |
| Hardware smoke (S9) | clean | clean for every binary-delta story |

## Product Scope

### MVP - Minimum Viable Product

The Phase-6 MVP proves concurrent on-device execution. Ships when ALL hold:
- `PAUSE` / `TASK` / `ACTIVATE` round-robin scheduler in fixed memory
  (bring-up milestone 1: single-bank).
- `KEY`-hooked REPL multitasking.
- Yielding `DELAY` / 64 Hz timer integration.
- Per-bank task switching (bring-up milestone 2).
- Exception isolation for background tasks.
- The headline demo (background traffic light + live REPL) PASSES on hardware.

### Growth Features (Post-MVP, still Phase 6)

- Counting semaphores / mutex / mailbox (`SIGNAL` / `WAIT`) — committed to the
  bundle, layered on the working scheduler.
- Broader MicroBeast hardware vocabulary (GPIO/PIO helpers, beeper); timer-event
  handler tasks; `.TASKS` introspection.

### Vision (Future phases)

- Optional preemptive scheduling (register model already future-proofed for it).
- Device-driver breadth (UART, I²C, RTC, LED matrix).
- Self-inspection (`SEE`, `TRAVERSE-WORDLIST`) + turnkey `.com` app path for
  shipping a multitasking Forth app without the outer interpreter.

## User Journeys

antforth is a solo-developer / hobbyist tool; "users" are the operator at the
live REPL, task authors writing cooperating tasks, and tutorial readers. Journeys
are kept lean and concrete (audience-of-one culture), each ending in the
capabilities it reveals.

### Journey 1 — Operator runs a background task (happy path)

Mid-session at the `ok>` prompt, Ant has the 3-LED board wired and wants the
traffic light cycling while he keeps experimenting. He types `TASK LIGHTS`,
defines `RUN-LIGHTS`, then `' RUN-LIGHTS LIGHTS ACTIVATE`. The lights start
cycling — and the prompt returns *immediately*. He keeps defining and testing
words while the LEDs keep time underneath; `.TASKS` shows the operator and LIGHTS
both awake. New reality: the machine does two things at once and the terminal
never locked up.
→ Reveals: `TASK`, `ACTIVATE`, `PAUSE`, `KEY`-hooked REPL, `.TASKS`, yielding `DELAY`.

### Journey 2 — A background task misbehaves (edge / recovery)

A background task hits an error (a `0 /`, a bad store) or worse, loops without
ever calling `PAUSE`. On the throw, the offending task is suspended with a legible
notice, but the `ok>` prompt survives — Ant inspects with `.TASKS`, fixes the
word, re-`ACTIVATE`s. On the never-yield case, cooperation visibly stalls
(documented as expected); Ant breaks in from the keyboard, finds the culprit,
`SLEEP`s or rewrites it. New reality: one bad task is recoverable, not a reset.
→ Reveals: exception isolation, `SLEEP` / `WAKE`, legible starvation, `.TASKS`
diagnostics, keyboard break path.

### Journey 3 — Two tasks share a resource (task author / coordination)

A producer task feeds sensor readings; a consumer task formats them to the
display. Uncoordinated, they interleave and corrupt the shared buffer. The author
guards the buffer with a mutex (`WAIT` / `SIGNAL`) or hands off via a one-slot
mailbox; the two tasks now cooperate cleanly. New reality: shared state is safe
with a few words.
→ Reveals: counting semaphores, mutex, mailbox; single-threaded-except-ISR model.

### Journey 4 — Tutorial reader meets multitasking (learner)

A newcomer reaches the multitasking chapter, `INCLUDE`s `TRAFFIC.FTH`, and —
instead of the lights hijacking the terminal as in the Phase-5 version — runs it
as a background task and keeps typing. The "whoa, this 8-bit machine multitasks"
moment lands; `4 DELAY` visibly does *not* freeze the prompt. New reality: a
memorable first contact with cooperative concurrency in an interactive language.
→ Reveals: demo/tutorial ergonomics, `INCLUDE` + background activation, yielding
`DELAY`, documentation/examples.

### Journey Requirements Summary

- **Task lifecycle:** `TASK`, `ACTIVATE`, `WAKE`, `SLEEP`, `.TASKS`.
- **Scheduler + yield:** `PAUSE`, `KEY`/`EMIT`/`KEY?` hooks, round-robin.
- **Timing:** yielding `DELAY` / 64 Hz timer wordset.
- **Coordination:** `SIGNAL`/`WAIT`, mutex, mailbox.
- **Robustness:** per-task exception isolation, legible starvation, keyboard break.
- **Banking:** per-task bank state so tasks in different banks coexist.
- **Tutorial/demo assets:** `TRAFFIC.FTH` runnable as a background task.

## developer_tool_embedded — Project-Type Requirements

### Project-Type Overview

Phase 6 extends an interactive ANS Forth (the "language") with a concurrency +
timer wordset on bare MicroBeast hardware. Per the project-type CSVs:
`visual_design` / `store_compliance` / `browser_support` are **skipped** (no GUI,
no app store, no browser); `connectivity` / `power_profile` / `security_model` /
`update_mechanism` (OTA) are **N/A for Phase 6** (single-user retro board;
networking + device drivers are future-vision, not this phase).

### New Word Surface (api_surface)

- **Task lifecycle:** `TASK ( -- )`, `ACTIVATE ( xt task -- )`, `WAKE ( task -- )`,
  `SLEEP ( task -- )`, `.TASKS ( -- )`.
- **Scheduler / yield:** `PAUSE ( -- )`; `KEY` / `EMIT` / `KEY?` re-implemented to
  call `PAUSE`.
- **Timing:** `DELAY ( s -- )` (yielding), `TICKS` counter, a timer-install word
  over `MBB_SET_USR_INT` (0xFDC7, 64 Hz).
- **Coordination (Growth):** `SIGNAL ( sem -- )`, `WAIT ( sem -- )`, mutex,
  one-slot mailbox.

### Technical Architecture Considerations (hardware_reqs)

- **Register contract** `PAUSE` must save/restore: BC=TOS, DE=IP, IX=return stack,
  SP=data stack, IY=UserArea (`src/inner_interpreter.asm`).
- **TCB** in fixed memory: circular link, status, saved SP/IX/DE/BC, bank byte; +
  per-task data + return stacks (default 256 + 256 B per `PS_SIZE`/`RS_SIZE`,
  `constants.asm:84`).
- **Fixed-memory invariant:** scheduler + ISR live in fixed memory; background task
  *bodies* may live in banks, with the per-task bank restored via `MBB_SET_PAGE`
  (0xFDDF) on switch.
- **Shared dictionary:** only the operator task compiles (HERE/LATEST/wordlists/
  bank-table stay global, not per-task).
- **Exception isolation:** per-task `catch_top` (already a UserArea field); the
  `.throw_uncaught → QUIT` path must suspend the faulting task, not the scheduler.
- **BIOS dependencies:** `MBB_SET_USR_INT` (0xFDC7) for the tick;
  `MBB_SET_PAGE`/`MBB_GET_PAGE` (0xFDDF/0xFDDC) for per-task bank.

### Implementation Considerations

- **Bring-up order:** fixed-memory switch first, then bank-aware switch (always a
  testable scheduler).
- **Backward compatibility (migration):** the boot session becomes "task 0" (the
  operator); single-task programs from Phases 1–5 run unchanged — no behavioral
  change until a second task is `ACTIVATE`d.
- **Cost:** context switch is a bounded register save/restore + (per-bank) one BIOS
  page call; overhead measured and documented.
- **Test surface:** cooperative-switch, KEY-hook REPL, cross-bank switch,
  exception-isolation, semaphore correctness; mind the `banking_tests.fth`
  straddle-halt when adding colon-body probes above $8000.

### Open Technical Choices (deferred to architecture / sprint planning)

1. Default per-task stack sizes — keep 256/256 B, or configurable at `TASK`?
2. Static TCB pool / max task count, or dictionary-allocated per `TASK`?
3. `.TASKS` introspection — MVP or Growth?

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Capability / problem-solving MVP — prove antforth can run a
background hardware task while the REPL stays live, on real hardware. The
validated-learning signal is the headline demo passing on silicon.

**Resource Requirements:** Solo developer (Ant), Z80 assembly + Forth; no deadline
pressure (consistent with the project's standing classification). Each epic ships
as an independent antforth 3.2.x point-release, so scope can stop cleanly between
epics.

### MVP Tier — Epic 25 spine + minimal Epic 24

The MVP must-have capabilities are enumerated under **Product Scope → MVP** above.
Epic mapping: the MVP is delivered by the **Epic 25** multitasker spine plus the
minimal `DELAY` / timer slice of **Epic 24**. Core journeys proven: Journey 1
(operator runs a background task) and Journey 2 (misbehaving task / recovery).

### Growth & Expansion Tiers

Growth and Vision feature lists are under **Product Scope** above. Mapping: the
**Growth** tier = **Epic 26** (semaphores, mutex, mailbox — Journey 3) + broader
**Epic 24** hardware vocabulary and `.TASKS`, plus the published tutorial sequel
(Journey 4). The **Expansion** tier (preemptive scheduling, device-driver breadth,
`SEE` / `TRAVERSE-WORDLIST`, turnkey `.com` app) remains future-phase.

### Risk Mitigation Strategy

**Technical Risks:** Hardest = exception isolation (`exception.asm` surgery) and
per-bank switch correctness. Mitigations: fixed-memory-switch-first bring-up
(always a testable scheduler); measure + document switch overhead including the
BIOS page call; lean on the already-future-proofed "bank = 1 byte of TCB" design;
adversarial cross-bank + isolation probes; mind `banking_tests.fth` straddle-halt
when adding colon-body probes above $8000.

**Adoption / Relevance Risks (hobby analogue of "market"):** Risk = the capability
doesn't land as a compelling Forth showcase. Mitigation: the live-REPL-plus-
background-traffic-light demo *is* both the acceptance gate and the tutorial hook
— value is validated by the demo, not assumed.

**Resource Risks:** Solo dev, no deadline. Contingency: epic-independent point-
releases mean the MVP multitasker (Epic 25) ships and delivers value on its own;
semaphores / hardware-vocab can slip to a later phase without stranding committed
work.

## Functional Requirements

### Task Lifecycle Management

- FR1: The operator can create a new task, allocating its control block and private stacks.
- FR2: The operator can assign a word to a task and start it running concurrently.
- FR3: The operator can suspend a running task and resume a suspended one.
- FR4: A completed task becomes inactive without affecting other tasks.
- FR5: Existing single-task programs (Phases 1–5) run unchanged when no additional task is activated; the boot session is the default operator task.

### Cooperative Scheduling & Yielding

- FR6: A task can voluntarily yield the processor to the next ready task.
- FR7: The scheduler selects the next runnable task in round-robin order, skipping suspended tasks.
- FR8: All active tasks make forward progress over time provided each yields (cooperative fairness).
- FR9: When only one task is active, scheduling does not change its observable behavior.

### Interactive REPL Concurrency

- FR10: The operator can continue entering and evaluating Forth at the prompt while background tasks run.
- FR11: Input-waiting operations (`KEY`, `KEY?`, `ACCEPT`) yield to other tasks instead of busy-waiting.
- FR12: Output operations interleave safely so the terminal remains usable while background tasks run.

### Timing & Hardware Timer

- FR13: The system can install a periodic 64 Hz timer handler that maintains a monotonic tick count.
- FR14: A task can delay for a specified number of seconds without freezing other tasks or the REPL.
- FR15: Delays are per-task: concurrent delays in different tasks do not interfere.
- FR16: The operator can read the current tick count for timing-driven logic.

### Inter-Task Coordination (Growth)

- FR17: A task author can coordinate access between tasks using counting semaphores (`SIGNAL` / `WAIT`).
- FR18: A task author can protect a shared resource with a mutex so only one task uses it at a time.
- FR19: A task author can pass a value between tasks via a single-slot mailbox.

### Robustness & Fault Isolation

- FR20: An uncaught error raised inside a background task suspends only that task and reports it; the operator's REPL and other tasks continue.
- FR21: The operator can recover a faulted task — inspect, redefine its word, re-activate — without restarting the system.
- FR22: A task that never yields produces an observable, documented stall rather than silent corruption, and the operator can break in from the keyboard.

### Banking-Aware Task State

- FR23: A task can run code located in any memory bank, and its bank context is preserved across yields, so concurrent tasks may reside in different banks.
- FR24: Compilation (dictionary growth) remains a single shared operator-task activity; background tasks execute pre-compiled words.

### Introspection & Demo

- FR25: The operator can list the current tasks and their state.
- FR26: A user can load the traffic-light demo and run it as a background task while continuing to use the REPL (the headline acceptance scenario).

## Non-Functional Requirements

### Performance & Real-Time

- NFR-P6-1 (Switch latency): A cooperative `PAUSE` switch completes in bounded,
  documented time; the per-bank variant's extra `MBB_SET_PAGE` cost is measured and
  reported. Overhead must stay low enough that a 64 Hz tick + interactive REPL + a
  handful of tasks never visibly lag at 8 MHz.
- NFR-P6-2 (Timer accuracy): `DELAY` is accurate to ±1 tick (1/64 s) per wall-clock
  second under nominal load; `60 DELAY` measures 60 s ±1 s on a stopwatch.
- NFR-P6-3 (REPL responsiveness): With background tasks yielding normally, operator
  keystrokes echo and evaluate without perceptible lag.
- NFR-P6-4 (ISR cost): The 64 Hz handler runs in fixed memory in bounded time and
  does not perceptibly steal time from foreground work.

### Reliability & Robustness

- NFR-P6-5 (Zero regression): The v3.1.0 close-out test baseline passes with 0 FAIL
  under the multitasking build; concurrency probes added, none removed.
- NFR-P6-6 (Hardware smoke / S9): Every binary-delta story runs hardware-smoke on
  real CP/M 2.2 / MicroBeast with PASS, including cross-bank switch and
  INCLUDE-after-activation.
- NFR-P6-7 (Fault containment): No single task's error or non-yielding loop can
  corrupt the scheduler, another task's stacks, or the dictionary; verified by probe.
- NFR-P6-8 (Determinism): Scheduling is deterministic round-robin; given the same
  task set and yields, behavior is reproducible.

### Resource Footprint

- NFR-P6-9 (Per-task RAM): Each task costs its TCB + a documented stack pair
  (default 256 + 256 B); total task RAM stays within the TPA/banked budget and the
  per-task cost is documented for capacity planning.
- NFR-P6-10 (Binary size): Phase-6 kernel growth is tracked per epic close-out
  against an agreed envelope (calibrated from prior phases); growth is
  accept-with-rationale, no silent bloat.
- NFR-P6-11 (Fixed-memory budget): Scheduler + ISR + TCB pool fit in fixed memory
  below $8000 alongside the existing kernel without crowding the dictionary.

### Compatibility & Portability

- NFR-P6-12 (Backward compatibility): All Phase-1..5 user-visible behavior is
  identical when no second task is activated (per FR5).
- NFR-P6-13 (BIOS contract): Timer install and per-bank switching use only the
  blessed BIOS entry points (`MBB_SET_USR_INT` 0xFDC7, `MBB_SET_PAGE`/`MBB_GET_PAGE`),
  never direct MMU port writes.
- NFR-P6-14 (Emulator/hardware parity): Emulator-verifiable behavior is tested there;
  divergent behavior (timing, real interrupts) is hardware-verified and documented.

### Maintainability & Testability

- NFR-P6-15 (Standing commitments): S1–S12 continue to hold across every Phase-6
  epic close-out.
- NFR-P6-16 (Test-through-threading): Concurrency is tested through the Forth
  threading model via REPL-piped scripts, not raw BDOS / asm-thread hacks.
- NFR-P6-17 (Probe safety): New colon-body probes respect the $8000 straddle
  constraint and TIB size limits; bank-switching probes follow established isolation
  patterns.
