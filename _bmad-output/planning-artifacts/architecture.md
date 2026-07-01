---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-06-29'
lastEdited: '2026-06-29'
editHistory:
  - date: '2026-06-29'
    changes: 'Fresh Phase-6 architecture init — concurrency bundle (Epics 24–26). Phase-4 doc archived to architecture-phase4-epics-16-22.md'
  - date: '2026-06-29'
    changes: 'Completed all 8 steps — context, starter (N/A), 9 core decisions (AD-P6-1..9) + 4 forks, patterns, structure, adversarial validation (6 findings, F1/F2 lead-resolved). Status: READY FOR IMPLEMENTATION.'
inputDocuments:
  - _bmad-output/planning-artifacts/prd-phase6-concurrency.md
  - _bmad-output/planning-artifacts/phase6-proposal-concurrency-2026-06-28.md
  - _bmad-output/planning-artifacts/product-brief-antforth-2026-05-08.md
  - _bmad-output/planning-artifacts/architecture-phase4-epics-16-22.md
  - docs/register-conventions.md
  - docs/throw-codes.md
  - docs/antforth-banking-redesign.md
  - docs/banking-pointer-hazards.md
  - docs/phase4-memory-map.md
  - docs/WISHLIST.md
  - docs/ans-forth-core-compliance.md
  - docs/adr-19-5-cross-bank-dispatch.md
  - disk/a/TRAFFIC.FTH
workflowType: 'architecture'
project_name: 'antforth'
user_name: 'Ant'
date: '2026-06-29'
phase: 6
phaseScope: 'Phase 6 — Concurrency & On-Device Applications (cooperative multitasker + timer/hardware words + semaphores; Epics 24–26, per prd-phase6-concurrency.md)'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements (26 FRs / 7 groups):**

Phase 6 turns antforth from single-threaded into a cooperative multitasker.
The FRs cluster into seven architectural concerns:

- **Task lifecycle (FR1–FR5):** create TCB + private stacks; assign+run an xt;
  suspend/resume; auto-inactivate on completion; *boot session = default
  operator task 0* with zero behavioral change until a 2nd task activates.
  → Architectural surface: TCB allocation, `TASK`/`ACTIVATE`/`WAKE`/`SLEEP`.
- **Cooperative scheduling (FR6–FR9):** voluntary `PAUSE` yield; round-robin
  skipping suspended tasks; cooperative fairness; single-task = no observable
  change. → The scheduler + the `PAUSE` primitive (Epic 25 spine).
- **REPL concurrency (FR10–FR12):** type/evaluate while tasks run; blocking
  input (`KEY`/`KEY?`/`ACCEPT`) yields instead of busy-waiting; output
  interleaves safely. → Re-implement the I/O leaf words to call `PAUSE`.
- **Timing (FR13–FR16):** 64 Hz timer handler + monotonic `TICKS`; yielding
  per-task `DELAY`; readable tick count. → Epic 24, productizing TRAFFIC.FTH.
- **Coordination / Growth (FR17–FR19):** counting semaphores, mutex, one-slot
  mailbox. → Epic 26, layered on a working scheduler.
- **Robustness (FR20–FR22):** uncaught background `THROW` suspends only that
  task; faulted task is recoverable without reset; non-yielding loop produces
  an observable, documented stall with a keyboard break path. → exception.asm
  surgery — the riskiest item.
- **Banking-aware state (FR23–FR24):** a task runs code in any bank, bank
  context preserved across yields; compilation stays a single shared
  operator-task activity. → per-task bank in TCB + MBB_SET_PAGE on switch.
- **Introspection/demo (FR25–FR26):** `.TASKS`; the headline acceptance —
  TRAFFIC.FTH as a background task while the REPL stays live.

**Non-Functional Requirements (17 NFRs):**

The NFRs that actively *shape* the architecture (not just gate it):

- **NFR-P6-1 / -4 (switch + ISR latency):** `PAUSE` and the 64 Hz handler must
  be bounded and cheap at 8 MHz; the per-bank `MBB_SET_PAGE` cost measured and
  documented. Drives a minimal register-save switch and a fixed-memory ISR.
- **NFR-P6-7 (fault containment):** no task's error or non-yield can corrupt
  the scheduler, another task's stacks, or the dictionary. Drives the
  exception-isolation design and per-task stack separation.
- **NFR-P6-9 / -11 (RAM + fixed-memory budget):** per-task = TCB + 256+256 B
  stacks; the TCB pool + ISR must fit in fixed memory without crowding the
  dictionary. Drives TCB-pool placement and static-vs-dynamic allocation.
- **NFR-P6-12 / -13 (compat + BIOS contract):** Phase-1..5 behavior identical
  with one task; timer/bank use only blessed BIOS entries (MBB_SET_USR_INT
  0xFDC7, MBB_SET_PAGE/GET_PAGE) — never direct MMU port writes.
- **NFR-P6-5 / -6 / -8 (regression, hardware smoke, determinism):** v3.1.0
  close-out baseline 0-FAIL under the multitasking build; per-binary-delta-story
  hardware smoke (S9); deterministic round-robin.

**Scale & Complexity:**

- Primary domain: bare-metal Z80 retro-embedded systems programming (an
  interactive ANS Forth + a concurrency/timer wordset on MicroBeast hardware).
- Complexity level: **low (systemic) / high (implementation-local)** — no
  systemic/regulatory complexity; intricacy is all in Z80 task-switch register
  juggling, banking dispatch, and exception-path surgery.
- Estimated architectural components: ~5 — (1) `PAUSE` switch + scheduler,
  (2) TCB/stack allocator + lifecycle words, (3) yielding I/O + timer/ISR
  wordset, (4) exception-isolation rework, (5) semaphore/coordination layer.

### Technical Constraints & Dependencies

- **Inviolable register contract** (`docs/register-conventions.md` Hard Rule #1):
  BC=TOS, DE=IP, IX=return stack, IY=UserArea, SP=data stack. `PAUSE` saves and
  restores exactly this set, and may switch *only* at a `NEXT` word boundary —
  mid-primitive these registers are phantom or parked in the shadow set (EXX).
  This constraint is the reason the switch model is cooperative, not preemptive.
- **UserArea conflates two lifetimes** (`src/structures.asm:21-70`): IY-pointed
  UserArea mixes per-task interpreter state (STATE/BASE/TIB/>IN/SOURCE-ID/HLD/
  CATCH-TOP/pic_buf) with *global* dictionary state (HERE/LATEST/
  current_wordlist/bank-table/saved+current_bank/triple_owner). The "shared
  dictionary, operator-only compile" lock requires a chosen split mechanism.
- **Single-task exception path** (`src/exception.asm:412-426`,
  `docs/register-conventions.md §9`): `.throw_uncaught` does a wholesale
  SP/IX/STATE reset → `JP w_QUIT_cf`, assuming one (operator) task. Background
  isolation requires re-routing this to suspend the faulting TCB.
- **Fixed-memory budget** (`docs/phase4-memory-map.md`, `src/constants.asm:84`):
  kernel grows up from $0100; stacks/user-area live at $C000–$D3FF; CCP at
  $D400–$DBFF already partly consumed by Epic-17's stub allocator + bank-table.
  TCB pool + per-task 512 B stacks + the ISR compete for this fixed space.
- **BIOS-only hardware contract** (NFR-P6-13): timer install via
  MBB_SET_USR_INT (0xFDC7, HL=routine, 64 Hz — header's "60th of a second" is
  wrong); per-bank switch via MBB_SET_PAGE/MBB_GET_PAGE (0xFDDF/0xFDDC). No
  direct MMU port writes (the standing post-Epic-19.5 BIOS-MBB discipline).
- **Banking dispatch interactions** (`docs/banking-pointer-hazards.md`,
  `docs/adr-19-5-cross-bank-dispatch.md`): cross-bank word bodies above $8000,
  the triple-owner model, and the `banking_tests.fth` $8000 straddle-halt that
  constrains how concurrency probes are written.
- **Locked decisions (2026-06-28), not open for re-derivation:** cooperative
  switching; shared dictionary / operator-only compile; per-task bank in TCB;
  fixed-memory-switch-first bring-up order.

### Cross-Cutting Concerns Identified

- **Per-task vs. global state split** — the IY/UserArea decision touches every
  task switch, the dictionary, and banking; spans Epics 24/25/26.
- **`PAUSE`-instrumentation of every blocking primitive** — `KEY`/`KEY?`/
  `EMIT`/`ACCEPT` (and `DELAY`) must all yield; broad surface, shallow depth;
  one un-instrumented busy word starves all tasks.
- **Exception isolation** — re-routing `.throw_uncaught` interacts with the
  scheduler, per-task CATCH-TOP, and the banking triple restore.
- **Banking on every switch** — per-task bank save/restore + MBB_SET_PAGE
  threads through the scheduler and the cross-bank test surface.
- **Fixed-memory pressure** — TCB pool + stacks + ISR placement vs. dictionary
  growth and binary-size envelope (NFR-P6-10/-11).
- **Test-through-threading under probe constraints** — concurrency verified via
  REPL-piped Forth (NFR-P6-16), respecting the $8000 straddle-halt and TIB-size
  limits (NFR-P6-17).
- **Backward compatibility** — single-task behavior must be byte-identical;
  boot session becomes "task 0" transparently (FR5 / NFR-P6-12).

## Starter Template Evaluation

**Not applicable.** antforth is a brownfield Z80 assembly project
(`developer_tool_embedded`) with no relevant starter-template ecosystem. There
is no scaffolding decision to make and no project-initialization story — the
"starter" is the v3.1.0 (Phase-5 / Epic-23) close-out codebase. (Web search for
Z80/Forth starters was deliberately skipped: hand-written-assembly retro kernels
have no `create-*` CLI, and inventing one would be ceremony, not architecture.)

**Phase-6 foundation: antforth v3.1.0** (Phase-5 / Epic 23 close, 2026-06-28 —
ANS-conformance + ergonomics: `IN`/`OUT`, `VALUE`/`TO`, `UD.`, banked-window-top
guard). The v3.1.0 close-out `make test-repl` baseline (0 FAIL) is the regression
floor for Phase 6 (NFR-P6-5). Inherited without replacement, the subsystems
Phase 6 builds on or modifies:

- **Inner interpreter** (`src/inner_interpreter.asm`): direct-threaded (JP-based);
  register contract BC=TOS / DE=IP / IX=return-stack / IY=user-area / HL=W /
  SP=data-stack (`docs/register-conventions.md`). DEFWORD `cf` label via
  `EQU body-3` → `JP DOCOL`. **This is the surface `PAUSE` switches on** — the
  switch is legal only at a `NEXT` boundary. Epic 25's `PAUSE` is a new CODE word
  in/near this file; the I/O leaf words gain `PAUSE` calls.
- **User area** (`src/structures.asm:21-70`, IY-based): the per-session state
  blob — STATE/BASE/HERE/LATEST/TIB/>IN/SOURCE-ID/HLD/CATCH-TOP/pic_buf/
  search-order + the Phase-4 banking cells (saved/current_bank, bank_table_base,
  triple_owner, …). **The per-task/global split (Epic 25) is a modification of
  how this struct is owned**, not a rewrite.
- **Exception subsystem** (`src/exception.asm`, Epic 11): CCD-1 dual-chain
  frames; CATCH-TOP per-session USER var (the per-task seed); `.throw_uncaught`
  recovery chain at `src/exception.asm:412-426`. **Epic 25's isolation story
  reworks the uncaught path** to suspend a background TCB instead of resetting
  the operator.
- **Banking subsystem** (`src/banking.asm`, Epics 16–21; BIOS-MBB pivot
  Epic 19.5): `BANK!`, per-bank dictionary triple, bank-aware FIND via 24-bit fat
  pointers, MBB_SET_PAGE/GET_PAGE discipline (no direct MMU ports). **Epic 25's
  per-task bank rides this** — `PAUSE` saves/restores `current_bank` + re-pages
  via MBB_SET_PAGE. The "bank = 1 byte of TCB" intent was future-proofed here.
- **Built-in Z80 assembler** (`src/assembler.asm`, Epic 4+): CODE/END-CODE,
  158/158 instruction-form coverage. **Epic 24's ISR is authored in this
  assembler** — TRAFFIC.FTH already prototypes the 64 Hz `TICK-ISR`/`(SET-USR-INT)`
  CODE words against MBB_SET_USR_INT (0xFDC7).
- **Port I/O** (`IN`/`OUT`, Epic 23/v3.1.0): the hardware primitives Epic 24's
  GPIO/PIO/beeper vocabulary builds on (TRAFFIC.FTH already drives the Z84C20
  PIO via `OUT`).
- **Test harness:** REPL-piped Forth scripts (`make test-repl`, S2/NFR-P6-16);
  banking-capable emulator dual-track with iz-cpm; real MicroBeast S9
  hardware-smoke per binary-delta story. Concurrency probes must respect the
  `banking_tests.fth` $8000 straddle-halt and TIB-size limits (NFR-P6-17).

**Toolchain (unchanged for Phase 6):** existing Z80 cross-assembler + build
scripts; iz-cpm for the non-banking `make test-repl` baseline; banking-capable
emulator for cross-bank assertions; real MicroBeast hardware for S9 smoke
(load-bearing for real-interrupt + cross-bank-switch timing per NFR-P6-14).

**Prior-phase cross-reference:** `architecture-phase1-epics-1-8.md`,
`architecture-phase2-epics-9-13.5.md`, `architecture-phase3-epics-14-15.md`, and
`architecture-phase4-epics-16-22.md` are the canonical references for all
inherited subsystems. **This document specifies only the additions and changes
for Phase 6.** Where documents disagree, Phase 6 wins (target state); where
Phase 6 is silent, Phase 4 governs, then Phase 3 → 2 → 1. Phase 6 concentrates
in: a new scheduler/TCB module (provisionally `src/multitasker.asm`), the
inner-interpreter `PAUSE` + I/O-leaf yield hooks, `src/exception.asm` isolation
surgery, the `src/structures.asm` per-task/global split, and a timer/ISR + GPIO
wordset (Epic 24).

**Note:** No project-initialization story is needed — Phase 6 starts from the
v3.1.0 close-out working tree.

## Core Architectural Decisions

All decisions inherit the 5 project-lead locks of 2026-06-28 (cooperative
switching; shared dictionary / operator-only compile; per-task bank in TCB;
fixed-memory-switch-first bring-up) and the 4 architecture-session forks settled
2026-06-29 (IY-fixed subset-swap; dictionary-allocated TCB; 32-bit TICKS;
`.TASKS` in MVP). Decision IDs are `AD-P6-n`.

### Decision Priority Analysis

**Critical (block implementation):**
- AD-P6-1 Per-task state model (IY-fixed + TCB subset save/restore)
- AD-P6-2 TCB layout & dictionary allocation
- AD-P6-3 Scheduler structure & `PAUSE` switch sequence
- AD-P6-4 Exception isolation (uncaught-THROW reroute)

**Important (shape architecture):**
- AD-P6-5 Timer/ISR + 32-bit `TICKS` + per-task `DELAY`
- AD-P6-6 Blocking-primitive yield instrumentation
- AD-P6-7 Module boundaries & build integration

**Deferred (post-MVP / Growth):**
- AD-P6-8 Coordination primitives (semaphore/mutex/mailbox) — Epic 26
- AD-P6-9 GPIO/PIO/beeper hardware vocabulary — Epic 24 Growth

### AD-P6-1 — Per-task state model: IY-fixed, TCB subset save/restore

**Decision:** IY remains the single global UserArea, never reassigned (preserves
`docs/register-conventions.md` Hard Rule: *"IY: Never reassigned after cold
start"*). `PAUSE` explicitly saves the running task's per-task UserArea cells
into its TCB and restores the next task's. The shared dictionary therefore stays
global *by construction* — HERE/LATEST/current_wordlist/bank-table/triple_owner
are never copied, never diverge.

**Per-task cell set (saved/restored by `PAUSE`):**
- `catch_top` — each task owns its exception-frame chain (required for AD-P6-4
  isolation; already a per-session cell — the good seed).
- `current_bank` — per-task bank (the locked banking decision); restored value
  drives the `MBB_SET_PAGE` re-page.
- `base` — per-task number base, so a background task formatting output can't be
  perturbed by the operator changing BASE (cheap; one cell).

**Explicitly NOT per-task (stay global in UserArea, untouched by background
tasks):** STATE, TIB/#TIB/>IN, SOURCE-ID, search-order, HERE/LATEST/
current_wordlist, all bank-table cells, triple_owner, saved_bank. Rationale:
background tasks execute pre-compiled words — they neither parse text nor
compile, so the interpreter/dictionary cells are operator-owned and never
contended. (HLD/pic_buf left global for v1 — pictured-output across a `PAUSE`
mid-`<# #>` is a documented don't-do, not a supported pattern.)

**Rejected:** (a) swap IY per task — violates the never-reassign invariant, risks
global-cell divergence; (c) struct refactor — large high-risk churn for no MVP
benefit. **Affects:** Epic 25 (`PAUSE`, TCB), `src/structures.asm`,
`src/exception.asm`. **Cost:** ~3 cell copies each direction per switch
(bounded, NFR-P6-1).

### AD-P6-2 — TCB layout & dictionary allocation

**Decision:** `TASK` carves a TCB + private stacks from the operator's bank-0
dictionary via HERE (like `CREATE`) — pay-as-you-go, no static pool. TCB +
stacks live in bank-0 fixed memory (below $8000), satisfying the scheduler-in-
fixed-memory invariant. Default stacks 256 + 256 B (`PS_SIZE`/`RS_SIZE`,
`src/constants.asm:84`), fixed for v1 (configurable stacks = Vision).

**TCB layout (fixed-memory record):**
| Field | Bytes | Purpose |
|---|---|---|
| `link` | 2 | next TCB in the circular ring |
| `status` | 1 | AWAKE / ASLEEP / SUSPENDED |
| `saved_sp` | 2 | data-stack pointer at yield |
| `saved_ix` | 2 | return-stack pointer at yield |
| `saved_de` | 2 | IP (resume thread address) |
| `saved_bc` | 2 | TOS at yield |
| `t_catch_top` | 2 | per-task CATCH-TOP (AD-P6-1) |
| `t_current_bank` | 2 | per-task bank (AD-P6-1) |
| `t_base` | 2 | per-task BASE (AD-P6-1) |
| `ps_area` | 256 | private parameter stack |
| `rs_area` | 256 | private return stack |

The **boot session is task 0 (the operator)** — its TCB is a static kernel
record (not dictionary-allocated) wired into the ring at COLD, so single-task
behavior is byte-identical until a 2nd `TASK` links in (FR5 / NFR-P6-12).

**Completion epilogue (validation F3):** `ACTIVATE` wraps the xt so that when a
*finite* task word returns, the epilogue sets the running TCB `status = ASLEEP`
and `PAUSE`s — the thread must never fall off its xt into garbage (FR4). The wrap
is the resume thread `DE` points at: `[ xt | <epilogue-cf> ]`, so the xt's
terminal `NEXT` chases into the epilogue.

**Fixed-RAM budget (validation F4):** TCBs carve from the bank-0 operator
dictionary (`kernel_end..$8000`) — fixed memory, but *scarce* (a few KB, shrinking
as the Phase-6 kernel grows). At ~530 B/task only a handful fit. `TASK` MUST guard
against `HERE + TCB_size` crossing $8000 and `THROW` if it would (precedent: the
banked window-top guard, Story 23.6/23.7). If the bank-0 budget proves too tight,
the fixed `$D4xx` allocator region (stub-allocator neighbourhood) is the
documented fallback — re-evaluate at sprint planning. Per-task cost is documented
for capacity planning (NFR-P6-9/-11).

**Hazard (documented):** `FORGET`/`MARKER` past an active task's TCB reclaims its
storage — same lifecycle class as the existing banked-MARKER hazards
(`project_banked_marker_no_stub`). Documented as don't-do; not guarded in v1.

**Affects:** Epic 25, `src/multitasker.asm`, COLD init in `src/antforth.asm`.

### AD-P6-3 — Scheduler structure & `PAUSE` switch sequence

**Decision:** Circular singly-linked ring of TCBs via `link`. `PAUSE` is a CODE
word (register-contract-critical; lives in/near `src/inner_interpreter.asm`):

1. Save `BC,DE,IX,SP` into the running TCB's saved slots.
2. Save per-task UserArea subset (`catch_top,current_bank,base`) into the TCB.
3. Walk `link` to the next TCB whose `status = AWAKE` (skip ASLEEP/SUSPENDED).
   If the walk returns to self, the single awake task simply resumes — FR9
   (one task ⇒ no observable change; the ring is length-1 for the operator).
4. Restore the next TCB's UserArea subset; if its `current_bank` differs,
   `MBB_SET_PAGE` to re-page (the only banking cost on a switch).
5. Restore `SP,IX,DE,BC`; `NEXT`.

Round-robin is deterministic (NFR-P6-8). The walk is O(ring length); a
non-yielding task simply never reaches its own `PAUSE`, starving the ring — the
documented expected cooperative failure (FR22), broken via the keyboard.

**Affects:** Epic 25; `src/inner_interpreter.asm`, `src/multitasker.asm`.

### AD-P6-4 — Exception isolation: uncaught-THROW reroute

**Decision:** Extend `.throw_uncaught` (`src/exception.asm:412-426`). Today it
does a wholesale operator reset (`asm_cleanup` → `LD SP,(sp_base)` → STATE/IX
reset → `JP w_QUIT_cf`). New logic, gated on *which task is running*:

- **Operator task (task 0):** unchanged — print diagnostic, reset, `JP
  w_QUIT_cf`. Preserves all Phase-1..5 REPL recovery behavior.
- **Background task:** print a legible `task N: error <n>` notice, set the
  running TCB `status = SUSPENDED`, and `PAUSE` to the next awake task. The
  faulting task leaves the rotation without touching the operator's SP/IX/STATE
  or any other task's stacks (NFR-P6-7). The operator can later inspect
  (`.TASKS`), redefine the word, and re-`ACTIVATE` (FR21).

"Which task" = compare the running TCB pointer against the operator-task-0 TCB
address (a kernel constant). Per-task `catch_top` (AD-P6-1) already ensures an
uncaught throw in a background task can't accidentally unwind into an operator
CATCH frame. **Affects:** Epic 25 (riskiest story); `src/exception.asm`.

### AD-P6-5 — Timer/ISR, 32-bit TICKS, per-task DELAY

**Decision:** Productize TRAFFIC.FTH's prototype into kernel words (Epic 24):
- A **32-bit (double-cell) monotonic `TICKS` counter** in fixed memory,
  incremented by the 64 Hz ISR with carry propagation across all 4 bytes.
  Chosen over 16-bit (project-lead call 2026-06-29) for a long readable range
  (no practical wrap; FR16) at the cost of a few extra ISR cycles + double-cell
  `DELAY` math — bounded and within NFR-P6-4.
- The ISR is a CODE word (Forth assembler), installed via `MBB_SET_USR_INT`
  (0xFDC7, HL=routine; the header's "60th/s" is wrong — it is 64 Hz), ending in
  `RET` (firmware CALLs it), living in fixed memory so it fires under any bank
  mapping (`reference_microbeast_user_interrupt_timer`).
- **`DELAY ( u -- )`** is *yielding and per-task for free*: it computes a target
  `= TICKS + u*64` as a **double** held on the task's own data stack, then
  `BEGIN PAUSE  TICKS  2-target  D>=  UNTIL`. No shared countdown cell (unlike
  TRAFFIC's `TICKS-LEFT`), so concurrent delays in different tasks ride their own
  stacks and never interfere (FR14/15). Double-cell modular comparison; monotonic
  counter means no wrap hazard for any realistic delay.
- `TICKS` readable word returns the live double; `MS` optional convenience.

**Affects:** Epic 24; `src/timer.asm`, ISR install path. **Migration note:** the
in-tree TRAFFIC.FTH `DELAY`/`TICKS-LEFT` is the *tutorial* version; the kernel
`DELAY` supersedes it and the tutorial sequel rewrites the demo as a background
task.

### AD-P6-6 — Blocking-primitive yield instrumentation + keyboard break

**Decision (refined by validation F1/F2, 2026-06-29):** Yield on **input only**,
not output. `KEY`, `KEY?`, `ACCEPT` call `PAUSE` while waiting on the console;
**`EMIT` does NOT yield** — output stays clean (no char-level interleaving of two
tasks' strings; FR12 "interleave safely") at the cost of a task briefly holding
the CPU through a long print until its next yield point. The REPL's input path
becomes "task 0 yields in `KEY`", which is what makes the live-prompt-plus-
background-task demo work (FR10–11). `PAUSE` goes *inside* the input wait/poll
loop, before re-testing the condition. The risk is *omission* — any new blocking
*input* primitive must be added to the yield checklist, or it starves the ring.

**Keyboard break (F1):** the 64 Hz ISR polls for a break key (`KEY?`-equivalent)
and sets a fixed-memory `break_pending` flag; the flag is consumed at the next
yield point (`PAUSE`/`KEY`/`DELAY`), routing control back to the operator and
raising a break in the running task. This breaks any task that yields *at all*.
A hard CPU-bound loop that never reaches a yield point remains the documented
"observable stall = reset required" — stated honestly (FR22), not papered over.
The ISR sets a flag only; it never reschedules or switches tasks (preserving the
cooperative model + the register contract — the ISR fires mid-primitive where
registers are phantom, so it must touch only fixed-memory cells + RET).

**Erratum — the *setter* is in-band, not the ISR (Story 25.7, operator-ratified
2026-07-01).** The operator drives antforth over a **serial TTY**, so an ISR
keyboard-port scan is inapplicable — there is no local keypress to scan; a break
must arrive as an in-band byte on the serial line. The break-key detection is
therefore moved from the ISR to the **console input path**: the break key is
**`Ctrl-\` (0x1C)** — a single byte, not an escape-sequence prefix (unlike ESC,
which leads cursor-key sequences such as `ESC [ D`, so it cannot false-trigger on
arrow keys) — recognised in `(EDIT)` beside the existing `^C` handler, which sets
`break_pending`. The `break_pending` flag + consume-at-next-yield + `THROW -28`
half of this decision is **unchanged**; only the setter moves (ISR poll →
`(EDIT)` recognition), and `src/timer.asm`'s ISR is left untouched. Consume rule:
only a **non-operator** task is broken — the operator (which reads the byte)
leaves the flag set and yields, so a runaway background task consumes it and is
broken (never the operator's prompt). A never-yielding loop still stalls (reset-required),
now because it never gives the operator a turn to read the byte. See
`_bmad-output/implementation-artifacts/25-7-keyboard-break-documented-starvation.md`.

**Erratum 2 — code-review corrections (Story 25.7 review, 2026-07-01).** The
review found `break_pending` is a single *ownerless global* latch, which qualifies
the "deterministic" wording above in three ways (two are inherent to the
mechanism, documented in `docs/throw-codes.md §(a.2)`; one was a real bug, fixed):
- **Not deterministic across multiple background tasks.** The `-28` lands on the
  **first** background task to reach `PAUSE` after the operator hands off, not
  necessarily "the" runaway. With a single busy task that *is* it; with several
  live tasks, targeting is first-to-yield, not by-culprit.
- **An active `CATCH` in the target intercepts the break.** The break is a genuine
  `THROW -28`, so a background task with a live `CATCH` frame at the yield point
  catches it and keeps running — a `CATCH`-guarded loop is unbreakable from the
  keyboard (redefine + reset is the fallback).
- **BUG FIXED — stale-latch ambush.** A `Ctrl-\` pressed with no breakable task
  AWAKE latches the flag indefinitely (the operator arm leaves it set, nothing
  consumes it); the original design let the *next* task `ACTIVATE`d later — even an
  unrelated one — eat a spurious `-28` on its first yield. Fix: **`ACTIVATE` and
  `WAKE` now drain `break_pending`** (a task entering the AWAKE rotation is never
  the target of a break aimed before it existed). Regression probe `break-no-ambush`;
  re-smoked PASS on silicon (`beastty-20260701-135403.bin`). +8 B over the initial
  25.7 build (kernel 30,438 B).

**Affects:** Epic 25; `src/io.asm` (`(EDIT)` `Ctrl-\` recognition), `src/multitasker.asm`
(`break_pending` cell + `PAUSE` consume/raise + `ACTIVATE`/`WAKE` latch-drain per Erratum 2).
*(Superseded: the original decision named `src/timer.asm` (ISR break poll) and
`src/inner_interpreter.asm`; the in-band erratum leaves both untouched.)*

### AD-P6-7 — Module boundaries & build integration

**Decision:**
- `src/multitasker.asm` (new) — `PAUSE` ring-walk body, TCB allocation, `TASK`/
  `ACTIVATE`/`WAKE`/`SLEEP`/`.TASKS`, semaphores (Epic 26). Owns the scheduler.
- `src/timer.asm` (new) — ISR install, 32-bit `TICKS`, `DELAY`/`MS`, GPIO/PIO/
  beeper vocabulary (Epic 24).
- `src/inner_interpreter.asm` (edit) — `PAUSE` primitive entry + I/O-leaf yield
  hooks (AD-P6-6), kept here because they touch the register contract directly.
- `src/exception.asm` (edit) — uncaught-THROW reroute (AD-P6-4).
- `src/antforth.asm` (edit) — COLD wires the static operator-task-0 TCB + ring.
- `src/structures.asm` (edit) — TCB STRUCT + per-task-subset documentation.

Build/test unchanged in shape: `make test-repl` baseline (NFR-P6-5) + the
banking-capable emulator dual-track + S9 hardware smoke per binary-delta story.

### AD-P6-8 / AD-P6-9 — Deferred to Growth (Epic 26 / Epic 24 Growth)

Counting semaphore (`SIGNAL`/`WAIT` over a cell), mutex (binary sem), one-slot
mailbox — cooperative spin-with-`PAUSE`, non-atomic (single-threaded except ISR;
the ISR touches only `TICKS`). ~~GPIO/PIO/beeper helpers over `IN`/`OUT`~~
(**AD-P6-9 dropped from Phase-6 scope** at epics review 2026-06-29 — existing
`IN`/`OUT` already suffice; TRAFFIC.FTH drives the PIO via `OUT` directly).
Semaphores (AD-P6-8) layer on the working scheduler; specced when Epic 26 opens.

### Decision Impact Analysis

**Implementation sequence (bring-up order — fixed-memory switch first):**
1. AD-P6-3 `PAUSE` + ring + AD-P6-2 TCB (single-bank, fixed memory) — a testable
   scheduler with task 0 + one task, no banking.
2. AD-P6-6 KEY-hook → live REPL while a fixed-memory task runs.
3. AD-P6-5 timer/ISR + yielding `DELAY` (Epic 24 minimal slice).
4. AD-P6-1 per-task bank restore + `MBB_SET_PAGE` on switch (bank-aware switch).
5. AD-P6-4 exception isolation.
6. Headline demo (background TRAFFIC + live REPL) on hardware = MVP gate.
7. AD-P6-8 semaphores (Epic 26, Growth).

**Cross-component dependencies:** AD-P6-1 (per-task subset) underpins both
AD-P6-4 (per-task catch_top) and the banking switch (per-task current_bank).
AD-P6-3's `PAUSE` is called by AD-P6-5 (`DELAY`) and AD-P6-6 (I/O) — so the
scheduler must land before the yield surface. AD-P6-4 depends on the operator-
task-0 identity established in AD-P6-2.

## Implementation Patterns & Consistency Rules

These pin the conventions a dev-agent could otherwise implement *differently* in
ways that break the register contract, the scheduler ring, or the test harness.
They extend (never override) `docs/register-conventions.md` and the standing
S1–S12 commitments. Phase-6-specific.

### Conflict Points Identified (Phase-6-specific)

Seven areas where independent implementations could diverge: (1) the `PAUSE`
register save/restore order, (2) how a TCB is addressed, (3) per-task vs global
cell ownership, (4) banking re-page placement on a switch, (5) the operator-task
identity test, (6) which blocking words yield, (7) how concurrency is probed
under the $8000 straddle constraint.

### Naming Patterns

- **Forth words** (user-facing, UPPERCASE): `PAUSE TASK ACTIVATE WAKE SLEEP
  .TASKS DELAY MS TICKS SIGNAL WAIT`. `.TASKS` follows the existing `.`-prefix
  introspection convention (`.S`, `.BANKS`). No abbreviations invented beyond
  these (the PRD's New Word Surface is the closed list for v1).
- **CODE-word labels:** `w_<NAME>_cf` with the `cf` label via `EQU body-3` →
  `JP DOCOL` for DEFWORDs (`feedback_defword_cf_label`); `PAUSE`, the ISR, and
  the switch body are DEFCODE (raw Z80, exit `NEXT`/`RET` as appropriate).
- **TCB field offsets:** `TCB_LINK`, `TCB_STATUS`, `TCB_SP`, `TCB_IX`, `TCB_DE`,
  `TCB_BC`, `TCB_CATCH`, `TCB_BANK`, `TCB_BASE`, `TCB_PS`, `TCB_RS` — EQU
  constants in `src/constants.asm`/`src/structures.asm`, addressed by name, never
  by magic offset.
- **Kernel cells:** `current_tcb` (pointer to the running TCB), `operator_tcb`
  (kernel constant = task-0 base), `ticks_lo`/`ticks_hi` (the 32-bit counter
  pair). Status enum: `TASK_AWAKE`/`TASK_ASLEEP`/`TASK_SUSPENDED`.

### Register-Contract Patterns (the load-bearing rules)

- **`PAUSE` switches ONLY at a `NEXT` boundary.** It is a CODE word reached
  through threading; it must never be invoked mid-primitive where BC/IP may be
  phantom or parked in the shadow set. This is the cooperative invariant —
  non-negotiable (`docs/register-conventions.md` Hard Rule #1).
- **Save order = {SP, IX, DE, BC} then the UserArea subset; restore in reverse.**
  Save the registers into the *outgoing* `current_tcb` first, then copy
  `(IY+catch_top/current_bank/base)` → outgoing TCB. After selecting the next
  TCB: copy its subset → UserArea, conditionally `MBB_SET_PAGE`, then restore
  `SP,IX,DE,BC`, then `NEXT`. A dev-agent must not reorder the register restore
  after `NEXT` or interleave the UserArea copy with the register restore.
- **IY is never reassigned** (AD-P6-1). The subset is *copied through* IY-relative
  loads/stores, not by swapping IY.
- **EXX leaf-level rule still holds** (`register-conventions.md §3`): if `PAUSE`
  or the ISR uses `EXX`, it must not `CALL` any EXX-using routine. The 64 Hz ISR
  runs after the firmware's own `EXX` (HL is shadow/free, A free) and must end in
  `RET`, not `NEXT` (the firmware CALLs it) — exactly the TRAFFIC.FTH pattern.

### TCB & Per-Task State Patterns

- **Address a TCB via a base pointer in HL/a register, with named offsets** —
  never IX-relative (IX is the live return-stack pointer and must not be
  repurposed). `current_tcb` holds the running task's base.
- **The per-task subset is exactly `{catch_top, current_bank, base}`** (AD-P6-1).
  A dev-agent must not silently add or drop a cell from this set; changing it is
  an architecture change (update AD-P6-1), not an implementation choice.
- **Global cells are never written by a background task path** — if a story needs
  a background task to touch HERE/LATEST/a wordlist, that violates the
  operator-only-compile lock; stop and escalate.

### Banking Patterns

- **`MBB_SET_PAGE`/`MBB_GET_PAGE` only** (0xFDDF/0xFDDC) — never direct MMU port
  writes (`project_div1_mmu_port_readback`, the post-Epic-19.5 discipline).
- **Re-page conditionally:** only call `MBB_SET_PAGE` when the next task's
  `current_bank` ≠ the outgoing one (saves the BIOS call on same-bank switches;
  NFR-P6-1). The page call is the measured per-switch banking cost.

### Exception-Isolation Patterns

- **Operator-task test:** compare `current_tcb` against `operator_tcb`
  (kernel constant). Equal ⇒ legacy reset→`JP w_QUIT_cf`; not-equal ⇒ suspend +
  `PAUSE`. No other discriminator (don't infer "background" from bank or status).
- **Notice format:** `task N: error <n>` then the existing throw-description
  lookup, matching the operator path's `error <n>: <desc>` style
  (`docs/throw-codes.md`). Background suspend must not print the operator's
  banner or re-enter QUIT.

### Yield-Instrumentation Patterns

- **The blocking-word checklist is exhaustive and explicit:** `KEY`, `KEY?`,
  `ACCEPT` (input wait), `EMIT` (per-emit yield). A story adding any new blocking
  primitive MUST add it to this list — an omitted yield is a starvation bug, not
  a style nit. `PAUSE` goes *inside* the wait/poll loop, before re-testing the
  condition.

### Testing Patterns (S2 + the banking-probe lessons)

- **REPL-piped Forth only** (`make test-repl`, NFR-P6-16) — concurrency tested
  through the threading model, never raw BDOS/asm-thread hacks.
- **Drive task/bank orchestration at interpret level** (`'` not `[']`) and assert
  printed witnesses via the Makefile — the established workaround for the
  `banking_tests.fth` $8000 straddle-halt (`feedback_banking_probe_straddle_halt`,
  `feedback_phase4_probe_bank_switch_limitation`).
- **Keep probe lines ≤ TIB_SIZE = 128** including `\` annotations
  (`feedback_tib_size_inline_comments`).
- **Timing/interrupt behavior is hardware-verified** (S9), with emulator probes
  asserting structure (switch happens, status transitions) and hardware
  asserting wall-clock (`60 DELAY` ±1 s) (NFR-P6-14).

### Comment & Provenance Discipline

- Source comments say **what + why-not-obvious**, never provenance (story/CR/date)
  — those live in git/story/ADR/memory (`feedback_source_comment_discipline`).
  The TCB layout and the `PAUSE` save-order rationale belong in source; the
  decision history belongs here and in the story files.

### Enforcement Guidelines

**Every Phase-6 dev-agent MUST:**
- Preserve BC=TOS / DE=IP / IX=RP / IY=UserArea across every new CODE word and
  the switch; switch only at `NEXT`.
- Keep the per-task subset = `{catch_top, current_bank, base}` unless AD-P6-1 is
  formally amended.
- Use MBB_* for all paging; never a direct MMU port write.
- Add any new blocking primitive to the yield checklist.
- Keep the v3.1.0 `make test-repl` baseline at 0 FAIL (NFR-P6-5) and run S9
  hardware smoke on every binary-delta story (NFR-P6-6).

**Pattern enforcement:** code review against `docs/register-conventions.md` + this
section; binary-size delta tracked per epic close-out against the agreed envelope
(NFR-P6-10), growth accept-with-rationale, no silent bloat.

### Anti-Patterns (do NOT)

- ❌ Invoking `PAUSE` from inside an EXX window or mid-primitive.
- ❌ Swapping IY to switch tasks (violates the never-reassign invariant).
- ❌ Re-paging unconditionally on every switch (wastes the BIOS call).
- ❌ Letting a background uncaught THROW reach `JP w_QUIT_cf` (kills the REPL).
- ❌ A blocking word that busy-waits without `PAUSE` (starves the ring).
- ❌ Bank-switching REPL probes with `[']`/colon bodies above $8000 (straddle halt).
- ❌ Provenance comments in source.

## Project Structure & Boundaries

Brownfield: the structure is the existing `src/` tree plus a small, surgical
Phase-6 delta. Two new modules + four edited files. No directory reorganization.

### Phase-6 File-Touch Surface

```
antforth/
├── src/
│   ├── antforth.asm          [EDIT] COLD: wire static operator-task-0 TCB +
│   │                                ring + ticks cells; add INCLUDE lines for
│   │                                the two new modules (after banking.asm)
│   ├── constants.asm         [EDIT] TCB field-offset EQUs, status enum,
│   │                                stack-size reuse (PS_SIZE/RS_SIZE)
│   ├── structures.asm        [EDIT] TCB STRUCT; document the per-task subset
│   │                                {catch_top,current_bank,base} (AD-P6-1)
│   ├── inner_interpreter.asm [EDIT] PAUSE primitive (register-contract body);
│   │                                I/O-leaf yield hooks land here (AD-P6-6)
│   ├── exception.asm         [EDIT] .throw_uncaught reroute: operator vs
│   │                                background task disposition (AD-P6-4)
│   ├── io.asm                [EDIT] KEY/KEY?/ACCEPT/EMIT call PAUSE (AD-P6-6)
│   ├── multitasker.asm       [NEW]  Epic 25 + 26 — ring walk, TCB alloc, TASK/
│   │                                ACTIVATE/WAKE/SLEEP/.TASKS; semaphores
│   ├── timer.asm             [NEW]  Epic 24 — 64 Hz ISR install, 32-bit TICKS,
│   │                                DELAY/MS; GPIO/PIO/beeper (Growth)
│   └── banking.asm           [READ] MBB_SET_PAGE/GET_PAGE reused, not edited
├── tests/
│   ├── multitasker_tests.fth [NEW]  Epic 25 — switch, KEY-hook, isolation,
│   │                                cross-bank-switch probes (REPL-piped)
│   ├── timer_tests.fth       [NEW]  Epic 24 — TICKS monotonicity, DELAY yield
│   ├── semaphore_tests.fth   [NEW]  Epic 26 — SIGNAL/WAIT/mutex/mailbox
│   └── banking_tests.fth     [READ] straddle-halt constraint reference
├── disk/a/
│   └── TRAFFIC.FTH           [READ] tutorial prototype; sequel runs it as a
│                                    background task (kernel DELAY supersedes it)
├── docs/
│   ├── register-conventions.md       [EDIT] add PAUSE switch-set + the §
│   │                                        documenting the TCB save/restore
│   ├── phase6-multitasker.md         [NEW]  scheduler model, TCB layout,
│   │                                        switch-cost measurements, demo recipe
│   └── throw-codes.md                [EDIT] any new task-suspend notice codes
├── Makefile                  [EDIT] register the 3 new test scripts into
│                                    test-repl; printed-witness asserts
└── examples/                 [maybe] background-task demo .FTH
```

Module INCLUDE order in `src/antforth.asm`: `multitasker.asm` + `timer.asm`
after `banking.asm` (line 724) and `exception.asm` (723) — both depend on the
banking + exception symbols. The TCB STRUCT goes in `structures.asm` (included
first, line 10) so every module sees the offsets.

### Architectural Boundaries

- **The `NEXT`-boundary line (register-contract boundary).** Above it: threaded
  Forth execution where BC=TOS/DE=IP are authoritative and `PAUSE` may switch.
  Below it: mid-primitive Z80 where registers are phantom/shadow — `PAUSE` must
  never be reached. This is the single most important boundary in Phase 6.
- **Operator-task ↔ background-task boundary.** The operator (task 0) owns the
  interpreter/dictionary state (STATE/TIB/>IN/HERE/LATEST/wordlists) and the
  legacy uncaught-THROW reset path. Background tasks own only their registers +
  the per-task subset; they execute pre-compiled words, never compile, and a
  background fault suspends only that TCB. Crossing this boundary (a background
  task compiling) is forbidden (AD-P6-1 / the operator-only-compile lock).
- **Fixed-memory ↔ banked boundary.** Scheduler, TCB pool, ISR, and the 32-bit
  TICKS counter live in fixed memory (below $8000 / page-0x23 region) so they
  are reachable under any bank mapping and the ISR fires regardless of the
  current page. Task *bodies* may live in banks; `PAUSE` re-pages per task.
- **BIOS contract boundary.** All paging via MBB_SET_PAGE/GET_PAGE; the timer
  via MBB_SET_USR_INT. antforth never touches MMU ports or the interrupt vector
  directly (NFR-P6-13).

### Requirements-to-Structure Mapping

| Epic | Lives in | FRs |
|---|---|---|
| **Epic 24 — Timer/Hardware** | `src/timer.asm`, ISR install in `antforth.asm`; `tests/timer_tests.fth` | FR13–16; Growth GPIO/PIO/beeper |
| **Epic 25 — Multitasker (spine)** | `src/multitasker.asm`, `PAUSE`+hooks in `inner_interpreter.asm`/`io.asm`, isolation in `exception.asm`, COLD in `antforth.asm`; `tests/multitasker_tests.fth` | FR1–12, FR20–26 |
| **Epic 26 — Semaphores** | `src/multitasker.asm` (coordination section); `tests/semaphore_tests.fth` | FR17–19 |

**Cross-cutting:**
- Per-task state (AD-P6-1) — `structures.asm` (TCB) + `inner_interpreter.asm`
  (PAUSE copy) + `exception.asm` (catch_top).
- Banking-on-switch — `multitasker.asm` calls into `banking.asm`'s MBB path.
- Backward compat (FR5) — `antforth.asm` COLD (static task-0 TCB, ring length-1).

### Integration Points & Data Flow

- **Switch data flow:** running word → `NEXT` → (if a task yields) `PAUSE` →
  save `{SP,IX,DE,BC}` + subset into `current_tcb` → walk `link` to next AWAKE
  TCB → restore subset → conditional `MBB_SET_PAGE` → restore `{SP,IX,DE,BC}` →
  `NEXT` into the resumed task's thread.
- **Timer data flow:** firmware 64 Hz IRQ → CALLs the installed ISR (fixed mem)
  → 32-bit `INC (TICKS)` with carry → `RET`. `DELAY` reads `TICKS` (double) each
  loop, `PAUSE`s, compares against its stack-held target (no shared cell).
- **Fault data flow:** background word `THROW` uncaught → `.throw_uncaught`
  sees `current_tcb ≠ operator_tcb` → print `task N: error <n>` → `status =
  SUSPENDED` → `PAUSE` → operator/next task continues.
- **REPL integration:** operator's `QUIT`→`KEY` now `PAUSE`s while waiting, so
  background tasks run between keystrokes — the mechanism behind the headline demo.

### File Organization & Workflow Integration

- **Source:** flat `src/*.asm`, one module per concern, INCLUDEd by
  `antforth.asm` — Phase 6 keeps the convention (no subdirectories).
- **Tests:** REPL-piped `tests/*.fth` driven by `make test-repl`; one new script
  per epic. Bank-switching probes follow the interpret-level (`'`) + Makefile
  printed-witness pattern to dodge the $8000 straddle-halt.
- **Build:** unchanged `Makefile` flow (Z80 cross-assembler → `build/antforth.com`);
  iz-cpm for the non-banking baseline, banking-capable emulator for cross-bank
  assertions, real MicroBeast for S9 hardware smoke per binary-delta story.
- **Docs:** a new `docs/phase6-multitasker.md` is the scheduler/TCB/switch-cost
  reference (parallel to `docs/phase4-memory-map.md`); `register-conventions.md`
  gains the PAUSE switch-set section.

## Architecture Validation Results

Adversarial pass (validation discipline: a review that finds nothing is suspect).
Six genuine findings surfaced; two resolved by project-lead decision (F1/F2,
2026-06-29), three folded into the decisions, one accepted as a documented limit.

### Coherence Validation ✅

- **Decision compatibility:** The 5 locks + 9 decisions are mutually consistent.
  Cooperative-only is *derived* from the register contract (not an independent
  choice that could conflict). IY-fixed subset-swap (AD-P6-1) satisfies the
  never-reassign invariant AND the shared-dictionary lock at once. Per-task bank
  rides the existing MBB path (no new banking mechanism). No contradictions.
- **Pattern consistency:** The Step-5 patterns enforce exactly the Step-4
  decisions (PAUSE save-order, MBB-only paging, operator-task test, yield
  checklist). Naming is consistent with existing antforth conventions
  (`.TASKS`←`.S`/`.BANKS`; `w_*_cf`; MBB_*).
- **Structure alignment:** The two new modules + four edits (Step 6) cover every
  decision; the fixed-memory ↔ banked boundary matches the verified bank-0
  dictionary location (`kernel_end`, below $8000).

### Requirements Coverage Validation

- **Epic coverage:** Epic 24 (timer/FR13–16), Epic 25 (spine/FR1–12,20–26),
  Epic 26 (coordination/FR17–19) — all architecturally supported.
- **FR coverage:** All 26 FRs map to decisions. FR4 (completion) and FR22
  (keyboard break) had gaps — now closed (F3, F1 below).
- **NFR coverage:** All 17 NFRs addressed. NFR-P6-10 (size envelope) deferred to
  sprint planning (F5); the rest covered by AD-P6-1..7 + process commitments.

### Findings & Resolutions

| # | Severity | Finding | Resolution |
|---|---|---|---|
| **F1** | 🔴 decision | FR22 "keyboard break" impossible for a truly non-yielding loop under cooperative + non-rescheduling ISR | **ISR sets `break_pending`, consumed at next yield** (project-lead 2026-06-29). Breaks any task that yields at all; hard CPU-bound loop = honest "reset-required" stall. Folded into **AD-P6-6**. |
| **F2** | 🔴 decision | `EMIT`-yields-per-char garbles concurrent task output vs FR12 "interleave safely" | **`EMIT` does NOT yield** (project-lead 2026-06-29); input-only yielding. Clean output; simpler. Folded into **AD-P6-6**. |
| **F3** | 🟡 spec gap | FR4 (completed task inactive) unspecified — a finite task word would fall off its xt into garbage | **`ACTIVATE` wraps xt with a completion epilogue** (`status=ASLEEP`+`PAUSE`). Folded into **AD-P6-2**. |
| **F4** | 🟡 resource | TCBs carve from the *scarce* bank-0 fixed dictionary (`kernel_end..$8000`), shrinking as the kernel grows | **`TASK` guards against crossing $8000 + THROW**; document per-task cost; `$D4xx` allocator as fallback. Folded into **AD-P6-2**. |
| **F5** | 🟡 process | NFR-P6-10 binary envelope uncalibrated | Agree the per-epic byte envelope at **sprint planning** (≈2.4× prior-phase pattern; Epic-17 envelope lesson). Tracked, not blocking. |
| **F6** | ⚪ limit | `HLD`/`pic_buf` stay global (AD-P6-1) → concurrent pictured-output across tasks unsupported | **Accepted, documented** v1 limitation; revisit only if a real demo needs it. |

### Gap Analysis Results

- **Critical gaps:** none remain. F1/F2 (the two that touched the locked model)
  are resolved by project-lead decision; F3 closes the only FR with no mechanism.
- **Important gaps (→ sprint planning):** F4 budget guard + measurement; F5
  envelope calibration. Both are sprint/story-level, not architecture blockers.
- **Nice-to-have:** switch-cost + ISR-cost measurement harness; a `.TASKS`
  output format spec (left to the Epic-25 story).

### Architecture Completeness Checklist

**✅ Requirements Analysis** — context, scale, constraints, cross-cutting concerns.
**✅ Architectural Decisions** — 9 decisions + 5 locks + 4 forks, all recorded with rationale.
**✅ Implementation Patterns** — register-contract, TCB, banking, isolation, yield, test, comment rules + anti-patterns.
**✅ Project Structure** — file-touch surface, boundaries, requirements mapping, data flows.
**✅ Validation** — adversarial pass, 6 findings, resolutions recorded.

### Architecture Readiness Assessment

**Overall status:** READY FOR IMPLEMENTATION (with F4/F5 carried into sprint planning).

**Confidence:** High. The hardest interactions (register contract, banking-on-
switch, exception isolation) build on already-future-proofed mechanisms; the two
model-level tensions the validation found are resolved; the bring-up order keeps
a testable scheduler at every step.

**Key strengths:** cooperative model is *derived from* the register contract, not
bolted on; IY-fixed subset-swap is minimal-churn and honors two locks at once;
fixed-memory-switch-first bring-up de-risks the banking interaction; per-task
`DELAY` falls out of the stack-held-target trick for free.

**Areas for future enhancement (Vision):** preemptive option (model already
future-proofed); configurable per-task stack sizes; output mutex (if concurrent
pictured-output is ever needed); a fixed `$D4xx` TCB allocator if bank-0 dict
proves tight.

### Implementation Handoff

**AI-agent guidelines:** follow the AD-P6-n decisions and the Step-5 patterns
exactly; never invoke `PAUSE` off a `NEXT` boundary; MBB-only paging; keep the
per-task subset = `{catch_top,current_bank,base}`; run `make test-repl`
(0 FAIL) + S9 hardware smoke per binary-delta story.

**First implementation priority:** Epic 25 bring-up step 1 — `PAUSE` + circular
ring + dictionary-allocated TCB (single-bank, fixed memory) with task 0 + one
task, no banking — the testable-scheduler milestone.
