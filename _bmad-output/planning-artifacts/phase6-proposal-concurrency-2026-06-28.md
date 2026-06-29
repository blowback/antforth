# Phase 6 Proposal — Concurrency & On-Device Applications

> **Status:** PROPOSAL / brainstorm output — not a ratified PRD.
> Produced 2026-06-28 in a party-mode design discussion (project lead: Ant).
> Formalize via `create-prd` → `create-epics-and-stories` → `sprint-planning`
> before any dev. Two scope decisions were taken by the project lead during
> this session (see "Locked decisions").

## Phase-numbering note (read first)

Earlier planning docs label the multitasker bundle "**Phase 5**"
(`prd.md:118`, `prd.md:207-218`, `architecture.md:339`). That label predates
actual events: **Phase 5 shipped as Epic 23** (ANS-conformance + ergonomics,
v3.1.0, closed 2026-06-28 — see `epics-phase5-epic-23.md`). The concurrency
bundle therefore slips to **Phase 6**, with epics continuing from Epic 23.
The "E.1–E.9" candidate IDs from `prd.md:207-218` are retained below for
traceability but re-homed under Phase 6.

## Thesis

*One 8-bit machine running background hardware tasks while you program it
live.* The cooperative multitasker is the spine; timer/hardware words feed it;
semaphores let tasks cooperate. Headline demo: load the traffic-light
(`disk/a/TRAFFIC.FTH`) as a **background task** and keep using the live `ok>`
prompt while the LEDs cycle on tempo.

## Locked decisions (project lead, 2026-06-28)

| Decision | Choice | Rationale |
|---|---|---|
| Phase scope | **Full concurrency bundle** (E.1 + E.2 + E.3) | Pieces interlock; one test harness + one demo; timer piece already prototyped |
| Switch model | **Cooperative**, not preemptive | `BC`=TOS / `IX`=RP have phantom mid-primitive states; switch only at word boundaries (`inner_interpreter.asm:1-20`) |
| Dictionary | **Shared; only the operator task compiles** | Avoids per-task `HERE`; classic polyForth/F83 model. UserArea (`structures.asm:21-70`) conflates per-task I/O state with global dictionary state — keep `here`/`latest`/`current_wordlist`/bank-table global |
| Banking | **Per-task bank in the TCB** (lead chose the ambitious option) | Builds to the fully future-proofed "bank = 1 byte of TCB" design (`architecture.md:339`, `prd.md:118`). `PAUSE` saves/restores `current_bank` and re-pages via `MBB_SET_PAGE` |
| Bring-up order | **Fixed-memory switch first → then bank-aware switch** | Always a testable scheduler; keeps clear of `banking_tests.fth` straddle-halt traps |

## Epics & dependency graph

```
E.1 Timer/Hardware words ──feeds──▶ E.2 Multitasker (SPINE) ──required by──▶ E.3 Semaphores
```

Provisional epic numbering (SM to finalize): **Epic 24** = Timer/Hardware
(E.1), **Epic 25** = Multitasker (E.2, spine), **Epic 26** = Semaphores (E.3).

### Epic 25 / E.2 — Cooperative Multitasker (spine)
- `PAUSE` primitive — save `BC`(TOS)/`DE`(IP)/`IX`(RP)/`SP` into the running
  TCB, round-robin to the next *awake* TCB, restore, `NEXT`.
- TCB in **fixed memory**: link (circular), status (awake/asleep), saved
  `SP`/`IX`/`DE`/`BC`, bank byte, + 512 B stacks (`PS_SIZE`+`RS_SIZE`,
  `constants.asm:84`).
- `TASK ( -- )` carves a TCB + stacks; `ACTIVATE ( xt task -- )`; `WAKE`/`SLEEP`.
- **Per-bank switch** (separate story) — save/restore `current_bank`
  (`structures.asm`), re-page via `MBB_SET_PAGE` (`constants.asm:58`). Measure
  the per-switch page-call overhead.
- `PAUSE`-hook into `KEY`/`EMIT`/`KEY?` → the REPL itself multitasks.
- **Exception isolation** — an uncaught `THROW` in a background task suspends
  *that task*, not the scheduler. Surgery on `exception.asm`'s
  `.throw_uncaught → QUIT` path (which currently assumes a single task).
  `catch_top` is already per-session (good seed).
- `.TASKS` introspection word (debug + demo aid).

### Epic 24 / E.1 — Timer & Hardware Words (feeds E.2)
- Productize the 64 Hz prototype (`disk/a/TRAFFIC.FTH`,
  `reference-microbeast-user-interrupt-timer`): free-running `TICKS` counter +
  a kernel `DELAY`/`MS` that **yields via `PAUSE`**. Note: with `PAUSE`, the
  free-running-tick `DELAY` becomes per-task *for free* — the target tick rides
  each task's own data stack across the yield (no shared mutable countdown).
- Kernel-level user-interrupt install (`MBB_SET_USR_INT` @ `0xFDC7`, HL=routine).
- PIO/GPIO + beeper helper words (WISHLIST "MicroBeast hardware vocabulary").

### Epic 26 / E.3 — Semaphores (depends E.2)
- `SIGNAL ( sem -- )` / `WAIT ( sem -- )`, mutex, mailbox primitives.
- **Non-atomic is acceptable** — single-threaded except the ISR (per WISHLIST).

## Risk register (honest)

- **Blocking-primitive instrumentation** — every `KEY`/`EMIT`/`ACCEPT` must
  `PAUSE` or one busy task starves the rest. Broad surface, shallow depth.
- **Exception isolation** — real `exception.asm` surgery; the riskiest item.
- **Per-bank switch cost + cross-bank test surface** — `MBB_SET_PAGE` call per
  switch; careful probe design vs. the known straddle-halt failure mode
  (`feedback_banking_probe_straddle_halt`).
- **Starvation** — a non-`PAUSE`ing loop hangs all tasks; document as expected
  cooperative behaviour (not a bug).
- **Stack memory budget** — 512 B per task; cheap on the TPA, but TCBs +
  stacks come out of fixed memory `HERE`.

## Headline acceptance

Load the traffic light as a background task → do arithmetic at the live `ok>`
prompt while the LEDs cycle. Prompt responds **and** lights stay on tempo =
switch + `KEY`-hook + timer integration proven in one demo. Plus: a starvation
test (documented expected hang) and an exception-isolation test (background
`THROW` does not kill the REPL).

## Open items to settle during PRD formalization

- Final epic numbering + story decomposition (SM).
- UserArea split mechanics: swap `IY` per task vs. save/restore a per-task
  subset. (Recommendation: shared dictionary, operator-only compile — see
  Locked decisions.)
- Emulator coverage for cross-bank task switching (which probes; vs.
  straddle-halt).
- Whether a preemptive option is a future stretch (docs future-proofed it;
  out of scope for Phase 6 v1).

## Grounding references

- Register model: `src/inner_interpreter.asm:1-20`, `src/macros.asm:30-46`,
  `src/antforth.asm:18-44`.
- UserArea / per-session state: `src/structures.asm:21-70`.
- Stack sizing / red-zone: `src/constants.asm:84-91`, `src/antforth.asm:18-44`.
- Banking future-proofing: `prd.md:78,118`, `architecture.md:294,339`.
- Phase-5/6 candidate menu (E.1–E.9): `prd.md:207-218`.
- Timer prototype: `disk/a/TRAFFIC.FTH`;
  memory `reference-microbeast-user-interrupt-timer`.
