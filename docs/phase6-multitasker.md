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
