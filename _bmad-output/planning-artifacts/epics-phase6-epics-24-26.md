---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories', 'step-04-final-validation']
lastStep: 4
phase: 6
phaseTitle: 'Concurrency & On-Device Applications'
status: 'complete'
completedAt: '2026-06-29'
lastEdited: '2026-06-29'
inputDocuments:
  - _bmad-output/planning-artifacts/prd-phase6-concurrency.md
  - _bmad-output/planning-artifacts/architecture.md
workflowType: 'epics-and-stories'
project_name: 'antforth'
user_name: 'Ant'
---

# antforth - Epic Breakdown (Phase 6 — Concurrency, Epics 24–26)

## Overview

This document provides the complete epic and story breakdown for **Phase 6 —
Concurrency & On-Device Applications**, decomposing the requirements from
`prd-phase6-concurrency.md` and the Phase-6 `architecture.md` (decisions
AD-P6-1..9) into implementable stories. Epics continue from Epic 23 (Phase 5):
**Epic 24** = Timer/Hardware, **Epic 25** = Multitasker (spine), **Epic 26** =
Semaphores. Brownfield — starts from the v3.1.0 close-out tree; no
project-initialization story.

## Requirements Inventory

### Functional Requirements

**Task Lifecycle Management**
- FR1: The operator can create a new task, allocating its control block and private stacks.
- FR2: The operator can assign a word to a task and start it running concurrently.
- FR3: The operator can suspend a running task and resume a suspended one.
- FR4: A completed task becomes inactive without affecting other tasks.
- FR5: Existing single-task programs (Phases 1–5) run unchanged when no additional task is activated; the boot session is the default operator task.

**Cooperative Scheduling & Yielding**
- FR6: A task can voluntarily yield the processor to the next ready task.
- FR7: The scheduler selects the next runnable task in round-robin order, skipping suspended tasks.
- FR8: All active tasks make forward progress over time provided each yields (cooperative fairness).
- FR9: When only one task is active, scheduling does not change its observable behavior.

**Interactive REPL Concurrency**
- FR10: The operator can continue entering and evaluating Forth at the prompt while background tasks run.
- FR11: Input-waiting operations (`KEY`, `KEY?`, `ACCEPT`) yield to other tasks instead of busy-waiting.
- FR12: Output operations interleave safely so the terminal remains usable while background tasks run.

**Timing & Hardware Timer**
- FR13: The system can install a periodic 64 Hz timer handler that maintains a monotonic tick count.
- FR14: A task can delay for a specified number of seconds without freezing other tasks or the REPL.
- FR15: Delays are per-task: concurrent delays in different tasks do not interfere.
- FR16: The operator can read the current tick count for timing-driven logic.

**Inter-Task Coordination (Growth)**
- FR17: A task author can coordinate access between tasks using counting semaphores (`SIGNAL` / `WAIT`).
- FR18: A task author can protect a shared resource with a mutex so only one task uses it at a time.
- FR19: A task author can pass a value between tasks via a single-slot mailbox.

**Robustness & Fault Isolation**
- FR20: An uncaught error raised inside a background task suspends only that task and reports it; the operator's REPL and other tasks continue.
- FR21: The operator can recover a faulted task — inspect, redefine its word, re-activate — without restarting the system.
- FR22: A task that never yields produces an observable, documented stall rather than silent corruption, and the operator can break in from the keyboard.

**Banking-Aware Task State**
- FR23: A task can run code located in any memory bank, and its bank context is preserved across yields, so concurrent tasks may reside in different banks.
- FR24: Compilation (dictionary growth) remains a single shared operator-task activity; background tasks execute pre-compiled words.

**Introspection & Demo**
- FR25: The operator can list the current tasks and their state.
- FR26: A user can load the traffic-light demo and run it as a background task while continuing to use the REPL (the headline acceptance scenario).

### NonFunctional Requirements

**Performance & Real-Time**
- NFR-P6-1: A cooperative `PAUSE` switch completes in bounded, documented time; the per-bank `MBB_SET_PAGE` cost is measured and reported; overhead stays low enough that a 64 Hz tick + REPL + a handful of tasks never visibly lag at 8 MHz.
- NFR-P6-2: `DELAY` is accurate to ±1 tick (1/64 s) per wall-clock second under nominal load; `60 DELAY` measures 60 s ±1 s on a stopwatch.
- NFR-P6-3: With background tasks yielding normally, operator keystrokes echo and evaluate without perceptible lag.
- NFR-P6-4: The 64 Hz handler runs in fixed memory in bounded time and does not perceptibly steal time from foreground work.

**Reliability & Robustness**
- NFR-P6-5: The v3.1.0 close-out test baseline passes with 0 FAIL under the multitasking build; concurrency probes added, none removed.
- NFR-P6-6: Every binary-delta story runs hardware-smoke (S9) on real CP/M 2.2 / MicroBeast with PASS, including cross-bank switch and INCLUDE-after-activation.
- NFR-P6-7: No single task's error or non-yielding loop can corrupt the scheduler, another task's stacks, or the dictionary; verified by probe.
- NFR-P6-8: Scheduling is deterministic round-robin; given the same task set and yields, behavior is reproducible.

**Resource Footprint**
- NFR-P6-9: Each task costs its TCB + a documented stack pair (default 256 + 256 B); total task RAM stays within the TPA/banked budget; per-task cost documented.
- NFR-P6-10: Phase-6 kernel growth is tracked per epic close-out against an agreed envelope; growth is accept-with-rationale, no silent bloat.
- NFR-P6-11: Scheduler + ISR + TCB pool fit in fixed memory below $8000 alongside the existing kernel without crowding the dictionary.

**Compatibility & Portability**
- NFR-P6-12: All Phase-1..5 user-visible behavior is identical when no second task is activated (per FR5).
- NFR-P6-13: Timer install and per-bank switching use only the blessed BIOS entry points (`MBB_SET_USR_INT` 0xFDC7, `MBB_SET_PAGE`/`MBB_GET_PAGE`), never direct MMU port writes.
- NFR-P6-14: Emulator-verifiable behavior is tested there; divergent behavior (timing, real interrupts) is hardware-verified and documented.

**Maintainability & Testability**
- NFR-P6-15: Standing commitments S1–S12 continue to hold across every Phase-6 epic close-out.
- NFR-P6-16: Concurrency is tested through the Forth threading model via REPL-piped scripts, not raw BDOS / asm-thread hacks.
- NFR-P6-17: New colon-body probes respect the $8000 straddle constraint and TIB size limits; bank-switching probes follow established isolation patterns.

### Additional Requirements

From the Phase-6 architecture (`architecture.md`, decisions AD-P6-1..9):

- **No project-initialization story** — brownfield; starts from the v3.1.0
  close-out working tree (Starter Template Evaluation = N/A).
- **Per-task state = IY-fixed subset save/restore** (AD-P6-1): `PAUSE`
  saves/restores exactly `{catch_top, current_bank, base}` into the TCB; IY is
  never reassigned; the shared dictionary stays global by construction.
- **TCB = dictionary-allocated per `TASK`** from bank-0 fixed memory
  (`kernel_end..$8000`) (AD-P6-2); 256+256 B stacks; static operator-task-0 TCB
  wired at COLD; `ACTIVATE` wraps the xt with a completion epilogue (status=ASLEEP
  + `PAUSE`); `TASK` must guard against crossing $8000 and `THROW` (F4).
- **Scheduler = circular TCB ring; `PAUSE` switches only at a `NEXT` boundary**
  (AD-P6-3); save `{SP,IX,DE,BC}` + subset, walk to next AWAKE TCB, conditional
  `MBB_SET_PAGE`, restore, `NEXT`.
- **Exception isolation** (AD-P6-4): `.throw_uncaught` reroute — operator task
  keeps legacy reset→`QUIT`; background task prints `task N: error <n>`, sets
  `status=SUSPENDED`, `PAUSE`s. Discriminator = `current_tcb` vs `operator_tcb`.
- **Timer/ISR + 32-bit double-cell `TICKS`** (AD-P6-5): ISR installed via
  `MBB_SET_USR_INT` (0xFDC7), ends in `RET`, lives in fixed memory, touches only
  HL+A (firmware preserves AF, shadows HL). `DELAY` rides a stack-held double
  target (per-task for free). 64 Hz (not 60).
- **Yield instrumentation, input-only** (AD-P6-6): `KEY`/`KEY?`/`ACCEPT` call
  `PAUSE`; **`EMIT` does NOT yield** (clean concurrent output). Keyboard break =
  64 Hz ISR sets `break_pending`, consumed at next yield; hard non-yielding loop
  = documented reset-only stall.
- **Module boundaries** (AD-P6-7): new `src/multitasker.asm` (Epic 25+26) +
  `src/timer.asm` (Epic 24); edits to `inner_interpreter.asm` (PAUSE + input
  hooks), `exception.asm` (isolation), `io.asm` (input yield), `antforth.asm`
  (COLD ring), `structures.asm` (TCB STRUCT). INCLUDE order: new modules after
  `banking.asm`/`exception.asm`.
- **Coordination primitives** (AD-P6-8, Epic 26): counting semaphore / mutex /
  one-slot mailbox; cooperative spin-with-`PAUSE`; non-atomic OK.
- ~~GPIO/PIO/beeper vocabulary (AD-P6-9, Epic 24 Growth)~~ — **dropped from
  Phase-6 scope** (epics review 2026-06-29); existing `IN`/`OUT` suffice.
- **Bring-up order (de-risking, fixed-memory switch first):** PAUSE+ring+TCB →
  KEY-hook → timer/DELAY → per-bank switch → exception isolation → demo gate →
  semaphores.
- **Testing:** REPL-piped Forth (NFR-P6-16); bank-switching probes at interpret
  level (`'` not `[']`) with Makefile printed-witness asserts; ≤128-char probe
  lines; emulator asserts structure, hardware asserts wall-clock timing.
- **Carried to sprint planning:** F4 (TCB fixed-RAM budget guard + measurement),
  F5 (per-epic binary-size envelope calibration, ≈2.4× prior-phase pattern).

### FR Coverage Map

| FR | Epic | Note |
|---|---|---|
| FR1–FR5 | Epic 25 | Task lifecycle (TASK/ACTIVATE/WAKE/SLEEP, completion, single-task compat) |
| FR6–FR9 | Epic 25 | Cooperative scheduling / round-robin / fairness |
| FR10–FR12 | Epic 25 | REPL concurrency (KEY-hook input yield; EMIT no-yield) |
| FR13 | Epic 24 | Install 64 Hz timer + monotonic tick |
| FR14, FR15 | Epic 25 | Yielding, per-task `DELAY` (upgrades Epic 24's `DELAY` via `PAUSE`) |
| FR16 | Epic 24 | Read the tick count |
| FR17–FR19 | Epic 26 | Semaphores / mutex / mailbox |
| FR20–FR22 | Epic 25 | Fault isolation, recovery, keyboard break / stall |
| FR23, FR24 | Epic 25 | Per-task bank state; operator-only compile |
| FR25 | Epic 25 | `.TASKS` introspection |
| FR26 | Epic 25 | Headline demo (background TRAFFIC + live REPL) |

All 26 FRs mapped; no gaps. Dependency order: **24 → 25 → 26** (each builds only
on prior epics).

## Epic List

### Epic 24: Timer & Hardware Words
antforth gains real-time timing — a 64 Hz monotonic clock (`TICKS`) and a seconds
`DELAY`/`MS` — by productizing the `TRAFFIC.FTH` prototype into the kernel.
Standalone value: a cleaner single-threaded traffic-light demo runs on this epic
alone; it also provides the `TICKS` clock the multitasker's yielding `DELAY` will
ride. (GPIO/beeper sugar dropped — existing `IN`/`OUT` suffice.)
**FRs covered:** FR13, FR16

### Epic 25: Cooperative Multitasker (the spine)
antforth becomes a cooperative multitasker — create background tasks, run them
concurrently with a live REPL, give each its own bank context, isolate faults,
and upgrade `DELAY` to yield. The headline "background traffic light while the
`ok>` prompt stays live" demo lands here. Standalone value: complete multitasking
capability; builds on Epic 24's `TICKS` but requires no future epic.
**FRs covered:** FR1–FR12, FR14, FR15, FR20–FR26

### Epic 26: Inter-Task Coordination (Semaphores)
Task authors can safely share resources between tasks — counting semaphores
(`SIGNAL`/`WAIT`), a mutex, and a one-slot mailbox. Standalone value: complete
coordination toolkit layered on the working scheduler.
**FRs covered:** FR17, FR18, FR19

---

## Epic 24: Timer & Hardware Words

antforth gains real-time timing — a 64 Hz monotonic clock and a seconds
`DELAY`/`MS` — productizing the `TRAFFIC.FTH` prototype into the kernel.
Standalone, single-threaded value; provides the `TICKS` clock the multitasker
will ride. Lives in new `src/timer.asm` + ISR install in `antforth.asm`
(AD-P6-5). (GPIO/beeper vocabulary, AD-P6-9, dropped from Phase-6 scope.)

### Story 24.1: 64 Hz timer interrupt + monotonic TICKS counter

As the operator,
I want a kernel 64 Hz tick interrupt that maintains a readable monotonic counter,
So that I have a real-time clock to drive timing logic.

**Acceptance Criteria:**

**Given** the kernel is built with the new `src/timer.asm` module
**When** the timer is installed via `MBB_SET_USR_INT` (0xFDC7) with the ISR address
**Then** a 32-bit (double-cell) `TICKS` counter in fixed memory increments 64×/second
**And** `TICKS` ( -- d ) pushes the live double; reading it twice ~1 s apart differs by ≈64
**And** the ISR is a CODE word that ends in `RET` (not `NEXT`), lives in fixed memory, and touches only HL + A/flags (firmware preserves AF and shadows HL — register-contract safe, NFR-P6-4/-13)
**And** a kernel install/remove word pair exists (install + `0`-disable), saving/restoring the Forth IP (DE) across the BIOS call
**And** a REPL-piped probe asserts `TICKS` monotonicity and the 32-bit carry across the low-word boundary; wall-clock rate (±1 tick/s) is hardware-verified (S9), and the binary delta is recorded

### Story 24.2: Seconds DELAY and MS (single-threaded form)

As the operator,
I want `DELAY` and `MS` words that wait a given duration,
So that I can pace single-threaded hardware sequences like the traffic light.

**Acceptance Criteria:**

**Given** the 64 Hz `TICKS` counter from Story 24.1 is running
**When** I run `n DELAY` ( u -- )
**Then** it computes a target = `TICKS + u*64` held on the data stack and busy-waits until `TICKS` reaches it (`60 DELAY` ≈ 60 s ±1 s on a stopwatch, NFR-P6-2)
**And** `MS` ( u -- ) provides a millisecond-granularity convenience wait over the same counter
**And** the DELAY loop is structured so the multitasker (Story 25.3) can later drop a `PAUSE` into it without changing its target-on-stack math (no shared countdown cell)
**And** a hardware-smoke `START-CLOCK 60 DELAY` stopwatch check PASSES (S9) and the kernel/TRAFFIC.FTH tutorial still runs; binary delta recorded

> _GPIO/PIO/beeper hardware vocabulary (the former Story 24.3 / AD-P6-9 Growth
> item) was **dropped from Phase-6 scope** at epics review 2026-06-29 — the
> existing v3.1.0 `IN`/`OUT` port words already suffice (TRAFFIC.FTH drives the
> PIO directly via `OUT`). Revisit only if a future demo needs sugar over the
> raw port words._

---

## Epic 25: Cooperative Multitasker (the spine)

antforth becomes a cooperative multitasker — background tasks running concurrently
with a live REPL, each with its own bank context and fault isolation. Stories
follow the architecture's fixed-memory-switch-first bring-up order; each leaves a
testable scheduler. Lives in new `src/multitasker.asm` + edits to
`inner_interpreter.asm`, `io.asm`, `exception.asm`, `antforth.asm`, `structures.asm`.

### Story 25.1: PAUSE + circular ring + TASK/ACTIVATE (single-bank, fixed memory)

As the operator,
I want to create a task and start a word running concurrently with my session,
So that two pieces of Forth make progress by cooperatively yielding.

**Acceptance Criteria:**

**Given** a kernel with the TCB STRUCT (`structures.asm`) and a static operator-task-0 TCB wired into a circular ring at COLD
**When** no second task is activated
**Then** all Phase-1..5 behaviour is byte-identical (ring length-1; FR5 / NFR-P6-12) and the v3.1.0 `make test-repl` baseline passes 0 FAIL (NFR-P6-5)
**And** `PAUSE` saves `{SP,IX,DE,BC}` + the per-task subset `{catch_top,current_bank,base}` into `current_tcb`, walks `link` to the next AWAKE TCB, restores, and `NEXT`s — switching only at a `NEXT` boundary (AD-P6-1/-3)
**And** `TASK` ( -- ) carves a TCB + 256+256 B stacks from bank-0 dictionary HERE, and `THROW`s if `HERE + TCB_size` would cross $8000 (AD-P6-2 / validation F4)
**And** `ACTIVATE` ( xt task -- ) sets the task running, wrapping the xt with a completion epilogue so a finite task word ends by setting `status=ASLEEP` + `PAUSE` (never falls off into garbage, FR4)
**And** a REPL-piped probe shows two tasks alternating via explicit `PAUSE` (round-robin deterministic, NFR-P6-8) with no stack/dictionary corruption (NFR-P6-7); binary delta recorded; S9 hardware smoke PASSES

### Story 25.2: KEY-hooked REPL multitasking (input-only yield)

As the operator,
I want the prompt to stay responsive while a background task runs,
So that I can keep typing and evaluating Forth as the task works underneath.

**Acceptance Criteria:**

**Given** a working scheduler (Story 25.1) with a background task activated
**When** the REPL waits for input in `KEY` / `KEY?` / `ACCEPT`
**Then** those words call `PAUSE` inside their wait loop, so the background task runs between keystrokes (FR10, FR11) and operator keystrokes echo/evaluate without perceptible lag (NFR-P6-3)
**And** `EMIT` does NOT yield, so concurrent task output is not interleaved char-by-char (FR12, clean output; AD-P6-6)
**And** the yield-instrumentation checklist (KEY/KEY?/ACCEPT) is documented; any future blocking input primitive must be added to it
**And** a probe demonstrates a background counter task advancing across several operator commands at the live prompt; S9 hardware smoke confirms responsiveness; binary delta recorded

### Story 25.3: Yielding, per-task DELAY

As a task author,
I want `DELAY` to yield instead of busy-wait,
So that a delaying task does not freeze the REPL or other tasks.

**Acceptance Criteria:**

**Given** Story 24.2's target-on-stack `DELAY` and a working `PAUSE` (Story 25.1)
**When** a task runs `n DELAY`
**Then** the wait loop calls `PAUSE` each iteration, so the REPL and other tasks keep running during the wait (FR14)
**And** concurrent delays in different tasks are independent — each target rides its own task's data stack, no shared countdown cell (FR15)
**And** accuracy is preserved (`60 DELAY` ≈ 60 s ±1 s, NFR-P6-2) under nominal multitask load
**And** a probe shows two tasks with different `DELAY`s both completing on time; `4 DELAY` visibly does not freeze the prompt (hardware S9); binary delta recorded

### Story 25.4: Task suspend/resume (WAKE/SLEEP) + .TASKS introspection

As the operator,
I want to suspend, resume, and list tasks with their state,
So that I can manage and observe the running task set.

**Acceptance Criteria:**

**Given** a ring with one or more activated tasks
**When** I run `task SLEEP` / `task WAKE`
**Then** the task's `status` flips ASLEEP/AWAKE and the round-robin walk skips ASLEEP tasks (FR3, FR7); a suspended task makes no progress until woken
**And** `.TASKS` ( -- ) lists each task and its state (AWAKE/ASLEEP/SUSPENDED), following the `.`-introspection convention (FR25, AD-P6-1 MVP)
**And** `.TASKS` shows the operator and a background task both awake (the Journey-1 witness)
**And** REPL-piped probes assert the status transitions and `.TASKS` output via printed witnesses (interpret-level `'`, ≤128-char lines, NFR-P6-16/-17); binary delta recorded; S9 PASS

### Story 25.5: Per-bank task switching

As a task author,
I want a task to run code in any memory bank with its bank preserved across yields,
So that concurrent tasks can live in different banks.

**Acceptance Criteria:**

**Given** the fixed-memory scheduler (Stories 25.1–25.4) and the Phase-4 banking subsystem
**When** `PAUSE` switches to a task whose `current_bank` differs from the outgoing one
**Then** it restores the next task's `current_bank` and re-pages via `MBB_SET_PAGE` (0xFDDF) — conditionally, only when the bank differs (AD-P6-1, NFR-P6-1) — never a direct MMU port write (NFR-P6-13)
**And** compilation remains a single shared operator-task activity; background tasks execute pre-compiled words only (FR24, operator-only-compile lock)
**And** the per-switch page-call overhead is measured and documented (NFR-P6-1)
**And** a cross-bank switch probe (interpret-level, dodging the $8000 straddle-halt) runs under the banking-capable emulator and is hardware-verified (cross-bank switch + INCLUDE-after-activation, S9 / NFR-P6-6); binary delta recorded

### Story 25.6: Background-task exception isolation

As the operator,
I want an uncaught error in a background task to suspend only that task,
So that one bad task does not kill my REPL or the other tasks.

**Acceptance Criteria:**

**Given** a background task that raises an uncaught `THROW` (e.g. `0 /`, a bad store)
**When** the throw reaches `.throw_uncaught` (`src/exception.asm`)
**Then** because `current_tcb ≠ operator_tcb`, it prints `task N: error <n>` (+ the throw-description lookup), sets the task `status=SUSPENDED`, and `PAUSE`s — the operator's REPL and other tasks continue (FR20, NFR-P6-7)
**And** an uncaught throw in the operator task keeps the legacy reset → `QUIT` behaviour (byte-identical to Phase 5)
**And** per-task `catch_top` ensures a background throw never unwinds into an operator CATCH frame
**And** the operator can inspect (`.TASKS`), redefine the faulting word, and re-`ACTIVATE` the task without restarting (FR21)
**And** a probe asserts: background throw → REPL survives + task SUSPENDED; operator throw → normal reset; binary delta recorded; S9 PASS

### Story 25.7: Keyboard break + documented starvation

As the operator,
I want to break in from the keyboard when a task misbehaves,
So that a runaway task is recoverable rather than requiring a reset.

**Acceptance Criteria:**

**Given** a background task that loops while still reaching yield points
**When** I press the break key
**Then** the 64 Hz ISR sets a fixed-memory `break_pending` flag (the ISR only flags — it never reschedules or switches tasks), consumed at the next yield point (`PAUSE`/`KEY`/`DELAY`), returning control to the operator and breaking the running task (FR22)
**And** a task that never yields at all (a hard CPU-bound loop) produces an observable, documented stall = reset-required — stated honestly, not silently (FR22)
**And** documentation describes the cooperative starvation model and the break path
**And** probes demonstrate the break path for a yielding loop and the documented stall for a non-yielding loop; S9 confirms the keyboard break on hardware; binary delta recorded

> **Follow-up folded in from Story 24.1 (timer foundation), 2026-06-29:** the
> MicroBeast BIOS PRESERVES the user-interrupt slot across warm-boot, and
> antforth reads the REPL line via BDOS fn 10 (`C_READSTR`), so **Ctrl-C
> warm-boots straight to CCP, bypassing `BYE`** and leaving the COLD-installed
> 64 Hz tick ISR live in the freed TPA (a real crash hazard if a larger program
> loads afterwards). `BYE` already releases the slot (`MBB_SET_USR_INT` HL=0,
> src/system.asm); the Ctrl-C path cannot be cleaned from Forth without taking
> over console input. When this story switches input to BDOS fn 6 / BIOS CONIN
> for the break key, **also route the Ctrl-C/break-to-CCP exit through the same
> slot-release as `BYE`** (or make BYE the only CCP-exit). Acceptance: after a
> keyboard-break exit, loading a different program does not crash from a stale
> tick ISR. (Accepted+documented in 24.1 per operator; not a 24.1 blocker.)

### Story 25.8: Headline demo — background traffic light + live REPL

As a tutorial reader,
I want to load the traffic-light demo as a background task and keep using the prompt,
So that I experience cooperative multitasking on an 8-bit machine first-hand.

**Acceptance Criteria:**

**Given** the full scheduler (Stories 25.1–25.7) and Epic 24's timer/hardware words
**When** I `TASK LIGHTS`, define the light-cycling word, and `' RUN-LIGHTS LIGHTS ACTIVATE`
**Then** the LEDs cycle on tempo while the `ok>` prompt returns immediately and stays responsive — I define and evaluate words while the lights keep time (FR26, the headline acceptance)
**And** `.TASKS` shows the operator and `LIGHTS` both awake
**And** the demo runs as a background task (vs the Phase-5 terminal-hijacking version), with `4 DELAY` visibly not freezing the prompt
**And** the headline demo PASSES on real CP/M 2.2 / MicroBeast hardware (the MVP gate, NFR-P6-6); a tutorial/example asset is provided; binary delta recorded

---

## Epic 26: Inter-Task Coordination (Semaphores)

Task authors can safely share resources between tasks. Cooperative spin-with-`PAUSE`,
non-atomic (single-threaded except the ISR, which touches only `TICKS`). Lives in
the coordination section of `src/multitasker.asm` (AD-P6-8).

### Story 26.1: Counting semaphore (SIGNAL / WAIT)

As a task author,
I want counting semaphores to coordinate access between tasks,
So that a producer and consumer can synchronise without corrupting shared state.

**Acceptance Criteria:**

**Given** a working scheduler (Epic 25)
**When** a task runs `sem WAIT` and the count is zero
**Then** it cooperatively spins with `PAUSE` until the count is non-zero, then decrements it; `sem SIGNAL` increments the count (FR17)
**And** a constructor word creates a semaphore cell initialised to a given count
**And** the implementation is non-atomic by design (single-threaded except the ISR; documented)
**And** a producer/consumer probe over a shared buffer shows no corruption and no deadlock in the documented pattern; binary delta recorded; S9 PASS

### Story 26.2: Mutex (binary semaphore)

As a task author,
I want a mutex to protect a shared resource,
So that only one task uses it at a time.

**Acceptance Criteria:**

**Given** the counting semaphore from Story 26.1
**When** two tasks contend for a mutex around a critical section
**Then** the mutex (a binary semaphore) grants exclusive access — the second task `PAUSE`-waits until the first releases (FR18)
**And** lock/unlock words are provided with a documented usage pattern
**And** a probe shows two tasks guarding a shared buffer with the mutex interleave cleanly (no corruption); binary delta recorded; S9 PASS

### Story 26.3: One-slot mailbox

As a task author,
I want to pass a value between tasks via a one-slot mailbox,
So that a producer can hand a reading to a consumer safely.

**Acceptance Criteria:**

**Given** the scheduler and semaphore primitives
**When** a producer posts a value to a full mailbox or a consumer reads an empty one
**Then** the posting/consuming task `PAUSE`-waits on the full/empty condition until the slot is available, then transfers the value (FR19)
**And** post/fetch words are provided with a documented hand-off pattern
**And** a probe shows a producer feeding readings to a consumer via the mailbox with correct values and no loss; binary delta recorded; S9 PASS
