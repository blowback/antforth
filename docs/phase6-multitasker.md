# Phase 6 — the cooperative multitasker, by way of a traffic light

This is the demo Phase 6 was built to enable: a set of traffic lights that cycle
on their own tempo **as a background task**, while the `ok` prompt stays live in
your hands. You keep defining and evaluating words; the machine keeps time. On an
8-bit Z80, running CP/M, over a serial terminal.

The whole cooperative spine — `PAUSE`, the task ring, `TASK`/`ACTIVATE`, the
yielding `DELAY`, `.TASKS`, the keyboard break — shipped across Epics 24 and 25.
This page is just the recipe for the headline moment, plus the one contrast that
explains *why it doesn't freeze the prompt* the way the first version did.

## The demo asset

`disk/a/TRAFFIC.FTH` — self-documenting, load it with `INCLUDE`. It defines three
things: the PIO setup (`PIO-INIT`, the `RED`/`AMBER`/`GREEN` masks), a named task
handle (`TASK CONSTANT LIGHTS`), and the cycle word `RUN-LIGHTS`.

## Run recipe

At the `ok` prompt, on real hardware (with a 3-LED board on the Z84C20 PIO Port A):

```
INCLUDE TRAFFIC.FTH              \ compile the demo words; LIGHTS is now a task
TIMER-ON                         \ start the 64 Hz tick the yielding DELAY counts
' RUN-LIGHTS LIGHTS ACTIVATE     \ arm the background light task — the prompt returns at once
```

That's it — the lights start cycling (red 4 s → red+amber 1 s → green 4 s →
amber 2 s) and **the prompt comes straight back**. Prove it by using the machine
while the lights keep time:

```
.TASKS                           \ shows both tasks awake:
   0 * AWAKE                     \   task 0 = you (the * marks the current task)
   1   AWAKE                     \   task 1 = LIGHTS
: SQUARE DUP * ;   9 SQUARE .    \ define and run a new word — lights never miss a beat
4 DELAY                          \ even a 4-second DELAY of your own does not freeze the lights
```

## Stop / recover

```
LIGHTS SLEEP                     \ park the light task (it stops cycling; ring keeps running)
TIMER-OFF                        \ stop the 64 Hz tick
```

If a task ever runs away, press **Ctrl-\\** (the in-band keyboard break, Story
25.7) to throw it off the CPU and get your prompt back.

## Why it doesn't freeze the prompt (the whole point)

The earlier prototype ran its light loop *directly* — it owned the terminal until
you reset the machine, because a `DELAY` was a busy-wait that never gave the CPU
back. This sequel is a genuine **background task**, and two changes make the
difference:

1. **Every `DELAY` is the kernel's *yielding* `DELAY`.** While a light is holding,
   the task parks at a `PAUSE` *inside* `DELAY` and hands the CPU back to the ring.
   The operator (and any other task) keeps running. The prototype's private
   `: DELAY` busy-waited and would re-freeze the prompt — so the sequel has no
   private `DELAY`; it uses the kernel's.

2. **The tick clock is the kernel's** (`TIMER-ON` / `TIMER-OFF`). The demo installs
   no interrupt of its own. A private ISR would *evict* the kernel's 64 Hz tick
   slot, after which the yielding `DELAY` would have nothing to count and would
   hang. So `TIMER-ON` once, before you activate the task.

Two smaller notes for anyone reading the source: the forever-loop is
`BEGIN … 0 UNTIL`, not `BEGIN … AGAIN` (`AGAIN` isn't defined in antforth); and if
your LEDs are wired active-low, invert the colour masks.

## What the emulator can and can't show

The `make test-repl-multitasker-demo` probe drives all of this under iz-cpm and
proves the **structure**: the demo activates cleanly, `.TASKS` shows both tasks
awake, and the light task *yields* while parked in a `DELAY` (a free-running
counter and the operator both keep making progress across it). What it can't
show is the *tempo* — the emulator doesn't model the MicroBeast 0xFDC7 user
interrupt, so `TICKS` never advances and a nonzero `DELAY` never completes there
(it just yields each pass, which is exactly what the no-monopoly test checks).
On-tempo cycling, "the prompt returns immediately", and "`4 DELAY` doesn't freeze
the prompt" are the real-hardware experience — the MVP acceptance gate, verified
on silicon over the serial TTY.

## Coordination — the counting semaphore (`SEMAPHORE` / `SIGNAL` / `WAIT`)

Once two tasks share a buffer, they need a way to hand data across without one
reading a slot the other hasn't filled. The Phase-6 answer is a **counting
semaphore**: a single cell holding a count, with three words.

- `n SEMAPHORE name` — create a semaphore `name` whose count starts at `n`. It's an
  ordinary `@`/`!`-addressable cell (like a `VARIABLE`), so `name @` reads the
  count. `0 SEMAPHORE g` starts "blocked"; `1 SEMAPHORE m` is the makings of a
  mutex (Story 26.2).
- `sem SIGNAL` — add one unit (increment the count). This is how a producer says
  "one more item is ready".
- `sem WAIT` — take one unit. If the count is already non-zero it decrements and
  returns at once; if it's zero the task **yields with `PAUSE` on every pass** until
  someone `SIGNAL`s, then decrements and returns.

The documented producer/consumer pattern:

```forth
CREATE BUF  4 CELLS ALLOT
0 SEMAPHORE FULL              \ counts items available to the consumer

: PRODUCER ( -- )            \ a background task
   4 0 DO
     I 1+ 10 *  I CELLS BUF + !   \ fill BUF[I]
     FULL SIGNAL                  \ announce it
     PAUSE
   LOOP ;

' PRODUCER TASK ACTIVATE

: CONSUME ( -- )             \ the operator (or another task)
   4 0 DO
     FULL WAIT               \ blocks (yielding) until an item is ready
     I CELLS BUF + @  .      \ read BUF[I] — guaranteed already written
   LOOP ;
CONSUME
```

The consumer's *k*-th `WAIT` cannot succeed until the producer has issued *k*
`SIGNAL`s, so it never reads a slot the producer hasn't filled — no corruption, no
lost values, and the two run interleaved without the operator ever freezing.

### Non-atomic by design — and why that's safe

`WAIT` checks the count and, if non-zero, decrements it — **without** masking
interrupts around the check-and-decrement. That is deliberate. The multitasker is
cooperative: a context switch happens *only* at a `PAUSE`, and the 64 Hz tick ISR
touches only `TICKS`, never a semaphore cell. `WAIT` places its only `PAUSE` at the
**top** of the loop, before the check; there is no `PAUSE` between "count > 0" and
the decrement, so no other task can slip in and consume the same unit. Two tasks
blocked on one semaphore cannot both take a single `SIGNAL`: whichever the
round-robin runs first decrements to zero, the other sees zero and loops again. No
lock, no masking — and it would be a *bug* to add a `PAUSE` inside that window.

### Starvation vs. the reset-required stall

If nobody ever `SIGNAL`s a semaphore, a **background** task blocked in `WAIT`
never progresses — but because `WAIT` yields every pass, **the rest of the ring
stays alive**: the REPL still echoes, peer tasks still run. That is the
cooperative-friendly failure, and it's the opposite of the Story 25.7 non-yielding
stall (a task in a tight loop with *no* `PAUSE`), which wedges the whole scheduler
and is only recoverable by reset. A starving *background* `WAIT`er you can observe
and redefine; a non-yielding loop you cannot. The `make test-repl-semaphore` probe
asserts exactly this: a **background** task parked forever in `WAIT` on a
never-signalled semaphore, while a peer counter keeps advancing and the probe still
runs to completion.

> **⚠️ Footgun — never `WAIT` in the operator on a count that won't be `SIGNAL`ed.**
> The "ring stays alive" guarantee holds only for *background* tasks. The operator
> **is** the REPL — the task that reads the keyboard. If you run `sem WAIT` directly
> at the prompt (operator context) and the count is zero, the operator parks itself
> in the spin loop and there is nothing left to echo your keystrokes: the console
> goes dead. Worse, it is **unrecoverable without a reset** — `Ctrl-\` is read only
> inside the line editor, which the parked operator never re-enters, and even a set
> break is operator-exempt by design (an operator yield hands off, it never breaks
> itself). So an operator-context `WAIT` on a dead semaphore is *also* a hard,
> reset-required stall — the same class as the 25.7 non-yielding loop, not the
> friendly one above. Do blocking `WAIT`s in a background `TASK`; keep the operator
> free to service the console (and, if needed, redefine the producer).

## Coordination — the mutex (`MUTEX` / `LOCK` / `UNLOCK`)

Where a counting semaphore counts *units available*, a **mutex** answers a simpler
question: is the shared resource free, or is someone using it? It is a binary
semaphore — a single cell that holds `1` (unlocked) or `0` (locked) — and it is
built directly on the Story 26.1 primitives.

- `MUTEX name` — create a mutex `name`, initialised **unlocked** (count `1`). It is
  literally `1 SEMAPHORE`: an ordinary `@`/`!`-addressable cell (like a `VARIABLE`),
  so `name @` reads `1` when free, `0` when held.
- `mtx LOCK` — acquire. This *is* `WAIT` re-exposed under the mutex vocabulary: if the
  mutex is free it takes it (count `1 → 0`) and returns; if it is held it **yields with
  `PAUSE` on every pass** until the holder releases, then takes it.
- `mtx UNLOCK` — release. It **stores `1`** — it does *not* increment.

### Why `UNLOCK` stores 1 instead of incrementing (binary clamp)

This is the one deliberate difference from the counting semaphore's `SIGNAL`. `SIGNAL`
increments without bound because a counting semaphore's whole purpose is to count
units. A mutex must be **binary**: exactly one holder at a time. If `UNLOCK` were
`SIGNAL`, a double release — a real bug class, releasing a mutex you already released
or that a peer released — would push the count to `2` and let *two* tasks `LOCK`
simultaneously, silently defeating exclusion. Storing `1` makes a double `UNLOCK`
idempotent (the count stays `1`, never `2`) and the invariant "count ∈ {0, 1}"
structural. So `MUTEX m ... m UNLOCK m UNLOCK` leaves `m @` at `1`, not `2`.

The documented critical-section pattern — guard the resource inside a background `TASK`:

```forth
CREATE SHARED  2 CELLS ALLOT
MUTEX GATE                     \ starts unlocked (1)

: WRITER ( -- )               \ a background task
   BEGIN
     GATE LOCK                \ blocks (yielding) until the gate is free
     42 SHARED !  PAUSE  42 SHARED CELL+ !   \ two-step write; safe under the lock
     GATE UNLOCK
   0 UNTIL ;                   \ AGAIN is undefined in antforth; forever = BEGIN..0 UNTIL

' WRITER TASK ACTIVATE
```

Any other task (or the operator) that reads `SHARED` **only while holding `GATE`**
never observes it half-written: the two-step write and every read are serialised by
the mutex, even though the writer yields (`PAUSE`) between its two stores.

### Non-atomic by design — inherited from `WAIT`

`LOCK` *is* `WAIT`, so it inherits the same proof: the multitasker is cooperative, a
context switch happens *only* at a `PAUSE`, and the 64 Hz tick ISR touches only
`TICKS`, never a mutex cell. `LOCK`'s only `PAUSE` is at the **top** of its loop,
before the count check; between "count > 0" and the decrement there is no `PAUSE`, so
no other task can slip in and take the same mutex. `UNLOCK` is a straight-line store
with no `PAUSE`, so release is atomic w.r.t. the ring too. Two tasks both blocked in
`LOCK` cannot both acquire a single `UNLOCK`: after `UNLOCK` sets the count to `1`,
whichever the round-robin runs next decrements it to `0`; the other sees `0` and loops.
No lost wakeup, no double-acquire — and it would be a *bug* to add a `PAUSE` inside the
check-decrement window.

> **⚠️ Footgun — never `LOCK` in the operator on a mutex no background task will
> `UNLOCK`.** This carries over verbatim from the `WAIT` warning above. The operator
> **is** the REPL — the task that reads the keyboard — and is break-exempt by design.
> If you run `mtx LOCK` directly at the prompt on a mutex that is held and no background
> task will ever `UNLOCK` it, the operator parks in the spin loop with nothing left to
> echo your keystrokes: the console goes dead and it is **unrecoverable without a
> reset** — even a set `Ctrl-\` break cannot recover it (an operator yield hands off, it
> never breaks itself). Do all blocking `LOCK`s in a background `TASK`; keep the operator
> free to service the console.

## Coordination — the one-slot mailbox (`MAILBOX` / `POST` / `FETCH`)

Where a semaphore counts units and a mutex guards a resource, a **mailbox** *carries a
value* from one task to another. This one is a **bounded buffer of capacity 1**: a
single slot that holds exactly one value, with the transfer gated so a producer and a
consumer hand off in lockstep — no value is ever lost, and none is ever overwritten
before it is read.

- `MAILBOX name` — create an empty one-slot mailbox `name`. Under the hood it is three
  ordinary `@`/`!`-addressable cells laid by `CREATE` + `,` (the `SEMAPHORE` mechanic):
  `[value][empty][full]` at `name+0`, `name CELL+`, `name CELL+ CELL+`. It starts
  **empty** — `empty = 1` (one free slot), `full = 0` (no item), `value = 0` (cosmetic,
  overwritten by the first `POST`).
- `x mbx POST` — deposit `x`. Waits on the **empty** slot (`empty WAIT`, yield-first),
  stores `x` into the value cell, then signals **full**. If the mailbox is already full
  it yields with `PAUSE` on every pass until a `FETCH` frees the slot.
- `mbx FETCH` — collect a value. Waits on **full** (`full WAIT`, yield-first), reads the
  value cell, then signals **empty**. If the mailbox is empty it yields until a `POST`
  fills it, then returns the value.

### The design — two semaphores plus a value cell

The two count cells **are** Story 26.1 counting semaphores. `empty` starts at `1` ("one
free slot available"); `full` starts at `0` ("no item yet"). `POST` = `empty WAIT` (take
the free slot, blocking) → `value !` → `full SIGNAL` (announce an item). `FETCH` is the
mirror: `full WAIT` (take the item) → `value @` → `empty SIGNAL` (announce a free slot).
The only new code is the three threaded bodies; `WAIT`/`SIGNAL`/`CREATE`/`,` are the
same proven leaves used everywhere else.

Because `empty` never exceeds `1` under this protocol, **the producer cannot `POST`
reading *i+1* until the consumer has `FETCH`ed reading *i*** and signalled `empty` — the
empty/full pair force a lockstep hand-off. That is the no-loss, no-overwrite guarantee.
It is also safe for multiple producers/consumers: at most one task is ever inside the
transfer window.

The documented producer→consumer pattern — the blocking side in a background `TASK`, the
consumer in the operator (or another `TASK`):

```forth
MAILBOX MBX                    \ starts empty

: PRODUCER ( -- )              \ a background task
   4 0 DO
     I 1+ 10 *  MBX POST      \ blocks (yielding) until the slot is free
   LOOP
   BEGIN PAUSE 0 UNTIL ;       \ park, still yielding; AGAIN is undefined

' PRODUCER TASK ACTIVATE

: CONSUMER  4 0 DO  MBX FETCH .  LOOP ;   \ collects each reading, in order
CONSUMER                                  \ => 10 20 30 40, prompt responsive
```

`DO`/`LOOP`/`I` are **compile-only** — they must live inside a `: … ;` definition, so the
consumer loop is wrapped in `CONSUMER` rather than typed bare at the prompt (a bare
`4 0 DO … LOOP` at the operator throws `-14: interpreting a compile-only word`).

### Non-atomic by design — inherited from `WAIT`

`POST`/`FETCH` compose `WAIT`/`SIGNAL`, so they inherit the same proof: the multitasker
is cooperative, a context switch happens *only* at a `PAUSE`, and the 64 Hz tick ISR
touches only `TICKS`, never a mailbox cell. The only `PAUSE` in the transfer path is
inside `WAIT`, *before* the slot is taken; once `WAIT` falls through, the value `!`/`@`
and the following `SIGNAL` run straight-line with no `PAUSE`, so no other task can
observe or mutate the value mid-transfer. Two tasks both blocked in `FETCH` on the same
mailbox cannot both consume a single `POST`: after `POST` signals `full` to `1`,
whichever the round-robin runs next decrements it to `0`; the other sees `0` and loops.
No lost wakeup, no double-take.

> **⚠️ Footgun — never `POST`/`FETCH` in the operator on a mailbox no background task
> will service.** This carries over verbatim from the `WAIT`/`LOCK` warnings above. The
> operator **is** the REPL — the task that reads the keyboard — and is break-exempt by
> design. If you run `mbx FETCH` directly at the prompt on an **empty** mailbox (or
> `x mbx POST` on a **full** one) with no background task to fill (or drain) it, the
> operator parks in the spin loop with nothing left to echo your keystrokes: the console
> goes dead and it is **unrecoverable without a reset** — even a set `Ctrl-\` break cannot
> recover it (an operator yield hands off, it never breaks itself). Do all blocking
> `POST`/`FETCH` in a background `TASK`; keep the operator free to service the console.
