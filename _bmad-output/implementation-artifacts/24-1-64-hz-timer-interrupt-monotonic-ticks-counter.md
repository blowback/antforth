# Story 24.1: 64 Hz timer interrupt + monotonic TICKS counter

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-29 by create-story workflow (context-engine pass).
     Story 24.1 is the FIRST story of Epic 24 (Phase 6 — Concurrency &
     On-Device Applications, → antforth 3.2.x). Deliverable: the kernel timer
     foundation — a 64 Hz interrupt service routine, a 32-bit monotonic TICKS
     counter in fixed memory, the TICKS ( -- d ) reader word, and a kernel
     install/remove word pair over MBB_SET_USR_INT. This is the clock the whole
     Phase-6 concurrency bundle rides (DELAY in 24.2, the per-task yielding
     DELAY in 25.3, the keyboard-break poll in 25.7).

     SIX load-bearing findings were resolved at DRAFT TIME by reading live
     source (B.4 / PD-2 figure-drift discipline). Do NOT re-discover at dev-pass:

       (1) MBB_SET_USR_INT IS NOT YET IN constants.asm — ADD IT.
           constants.asm:57-58 define MBB_GET_PAGE (0xFDDC) and MBB_SET_PAGE
           (0xFDDF) only. The user-interrupt entry 0xFDC7 is hardcoded in
           disk/a/TRAFFIC.FTH:30 ($FDC7 CALL,). Add
           `MBB_SET_USR_INT EQU 0xFDC7` to constants.asm next to the MBB_* pair,
           with a one-line note (HL = routine addr; 0 disables; fires 64 Hz —
           NOT the "60th/s" the firmware header wrongly claims; memory
           reference_microbeast_user_interrupt_timer).

       (2) THE ISR MAY TOUCH ONLY HL + A/flags. NOTHING ELSE.
           The firmware CALLs the user interrupt AFTER its own EXX (so HL is the
           shadow set — free) and with AF preserved (so A is free). Every other
           register (BC=TOS, DE=IP, IX=rstack, IY=UserArea, SP) is LIVE
           main-context and MUST NOT be disturbed. The ISR ends in RET (the
           firmware CALLed it — NOT NEXT). This is exactly the TRAFFIC.FTH
           TICK-ISR contract (disk/a/TRAFFIC.FTH:14-24, register-conventions
           §2-3). The 32-bit increment below fits inside HL + A.

       (3) `INC HL` DOES NOT SET FLAGS — the carry test is EXPLICIT.
           16-bit `INC rr` on the Z80 affects NO flags. So a 32-bit increment
           cannot detect low-word rollover from the INC itself. After
           `INC HL` you must test HL==0 via `LD A,H / OR L / JR NZ,.done`
           (A is free per finding (2)). Only on rollover (HL wrapped 0xFFFF→0)
           do you increment the high word. This is THE bug a naive dev will
           ship (assuming INC sets Z) — call it out in the ISR comment.

       (4) `TICKS` MUST `DI`/`EI` AROUND ITS 4-BYTE READ (torn-read guard).
           TICKS reads a 4-byte counter that the 64 Hz ISR mutates. If the ISR
           fires between byte reads, TICKS can return a torn value (e.g. old
           low + new high across a rollover). Wrap the read in `DI ... EI`.
           The window is ~a dozen T-states (negligible). NOTE: only `EI` if
           interrupts were on — at the REPL they always are (COLD enables them),
           so a plain DI/EI pair is correct for the runtime word. The ISR
           itself is non-reentrant (the Z80 disables interrupts on accept and
           the firmware RETs via EI), so its own increment is atomic.

       (5) THE COUNTER + ISR ARE GLOBAL FIXED-MEMORY STATE — NOT UserArea.
           TICKS is ONE system clock shared by all tasks (Phase 6), so its cells
           are NOT per-task and do NOT belong in the UserArea struct
           (structures.asm:21-70). Define `tick_count` as two `DW 0` cells
           (low, then high) inline in the new src/timer.asm — fixed memory,
           below $8000, in the .com image (which loads into writable TPA RAM).
           Order them low-cell-first so TICKS can push high-on-TOS cheaply
           (finding (6)). COLD should zero them for warm-restart hygiene.

       (6) `TICKS ( -- d )` PUSHES HIGH-ON-TOS PER §3.1.4.1 — THE 2@ SHAPE.
           antforth doubles put the HIGH cell on TOS (BC) and the LOW cell
           second-on-stack (post-Story-13.0.1; project_tos_in_register;
           src/double.asm:31-48 `2@` is the exact model). So TICKS: push the
           low 16-bit cell, then load the high 16-bit cell into BC = new TOS,
           NEXT. (The 4-byte counter is [low:2][high:2] in memory per (5).)
-->

## Story

As the operator,
I want a kernel 64 Hz tick interrupt that maintains a readable 32-bit monotonic
counter,
so that I have a real-time clock to drive timing logic — and the foundation the
whole Phase-6 concurrency bundle (DELAY, yielding DELAY, the keyboard-break poll)
depends on.

## Acceptance Criteria

1. **A 64 Hz interrupt service routine is installed via `MBB_SET_USR_INT`
   (0xFDC7).** The ISR is a native CODE routine in fixed memory that ends in
   `RET` (the firmware CALLs it). It runs after the firmware's `EXX` and with
   `AF` preserved, and therefore touches ONLY `HL` and `A`/flags — every other
   register (BC/DE/IX/IY/SP) is left untouched (finding (2)). `MBB_SET_USR_INT
   EQU 0xFDC7` is added to `src/constants.asm` (finding (1)).
2. **A 32-bit monotonic `tick_count` in fixed memory increments 64×/second.**
   On each fire the ISR increments the 32-bit counter with correct carry from
   the low word to the high word — using an EXPLICIT zero-test after `INC HL`
   (since `INC rr` sets no flags, finding (3)). The counter is global
   fixed-memory state (two `DW` cells, low then high), NOT a UserArea cell
   (finding (5)); COLD zero-inits it.
3. **`TICKS ( -- d )` returns the live counter as a double**, high cell on TOS
   per §3.1.4.1 (the `2@` shape, finding (6)). The read is guarded against a
   torn read by `DI`/`EI` around the 4-byte access (finding (4)).
4. **A kernel install/remove word pair exists.** `TIMER-ON ( -- )` installs the
   kernel tick ISR via `MBB_SET_USR_INT`; `TIMER-OFF ( -- )` disables it
   (installs address 0). Both save/restore the Forth IP (`DE`) across the BIOS
   call (the TRAFFIC.FTH `(SET-USR-INT)` discipline). COLD auto-installs the
   ISR so `TICKS` is live by default (FR16); `TIMER-OFF`/`TIMER-ON` let a user
   reclaim the single user-interrupt slot for their own ISR and restore it.
5. **Automated REPL-piped probe asserts monotonicity + the 32-bit carry.** A
   self-printing probe asserts: `TICKS` is monotonic non-decreasing across a
   busy-wait (`d1 ... d2` with `d2 d1 D<` false); the low-word→high-word carry
   is exercised structurally (see Dev Notes for the deterministic technique —
   do NOT wait ~17 min of real ticks). Probe lines ≤ TIB_SIZE=128; verdict
   greps column-0-anchored (`^PASS:`/`^FAIL:`).
6. **Wall-clock rate is hardware-verified (S9).** On real CP/M 2.2 / MicroBeast,
   the counter advances ≈64 ticks per stopwatch second (the ±1-tick basis for
   24.2's `60 DELAY` test; NFR-P6-2/-4). Emulator asserts structure; hardware
   asserts wall-clock (NFR-P6-14).
7. **Backward compatibility holds.** With the ISR auto-installed, all Phase-1..5
   user-visible behavior is unchanged (the counter is invisible unless `TICKS`
   is read; NFR-P6-12). `make test-repl` holds at the current close-out baseline
   (0 FAIL); `check-doc-sync` 0-drift.
8. **`TICKS`/`TIMER-ON`/`TIMER-OFF` flagged `; antforth extension`** per CCD-3
   with a one-line why-note (no provenance — `feedback_source_comment_discipline`);
   compliance doc gains extension rows. Binary delta recorded and itemised at close.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [ ] Capture current binary size: `wc -c build/antforth.com` → record in Dev
      Notes. Do NOT inherit a prior story's number — re-`wc -c` from the actual
      current build artifact (B.3 / Lesson 13.5-F). The last committed Phase-5
      figure was ~28859 B (Story 23.3 close), but Epic 23.6–23.9 follow-ups
      landed after — re-measure.
- [ ] Capture current `make test-repl` baseline pass count and
      `test-repl-banking` count — both green pre-edit.

### Story tasks

- [ ] Task 1 — Add the BIOS constant + new `src/timer.asm` module (AC: 1)
  - [ ] Add `MBB_SET_USR_INT EQU 0xFDC7` to `src/constants.asm` beside
        `MBB_GET_PAGE`/`MBB_SET_PAGE` (:57-58), with a why-note (HL=routine,
        0=disable, 64 Hz not 60).
  - [ ] Create `src/timer.asm`; add `INCLUDE "timer.asm"` to `src/antforth.asm`
        AFTER `banking.asm` (:724) — the wordlist re-scan at :778 picks up the
        new DEFCODE entries automatically (no hash-table edit needed).
  - [ ] Define global counter cells: `tick_count: DW 0` (low) then `DW 0`
        (high) — fixed memory, low-cell-first (finding (5)/(6)).

- [ ] Task 2 — Author the 64 Hz ISR (AC: 1, 2)
  - [ ] `tick_isr:` — assumes firmware-EXX context (HL shadow free, A free).
        Body (finding (3)):
        ```
        tick_isr:
            LD   HL,(tick_count)      ; low word
            INC  HL
            LD   (tick_count),HL
            LD   A,H
            OR   L                    ; INC rr sets no flags — test HL==0 here
            RET  NZ                   ; no rollover → done
            LD   HL,(tick_count+2)    ; high word
            INC  HL
            LD   (tick_count+2),HL
            RET
        ```
  - [ ] Comment the `RET`-not-`NEXT` contract and the "INC sets no flags" carry
        test (the dev trap). No provenance comment (CCD-3 / source-comment rule).

- [ ] Task 3 — `TICKS ( -- d )` reader (AC: 3)
  - [ ] `DEFCODE "TICKS", 0`; body: `DI`; read low cell → push; read high cell
        → BC (new TOS); `EI`; `NEXT`. Use the `2@` push shape (src/double.asm:
        31-48): `PUSH` low cell, then `BC` = high cell. Guard the 4-byte read
        with DI/EI (finding (4)). `; antforth extension — 64 Hz system tick,
        double (high on TOS)`.
  - [ ] (No `check_underflow` — TICKS only pushes.)

- [ ] Task 4 — `TIMER-ON` / `TIMER-OFF` install/remove + COLD auto-install (AC: 4)
  - [ ] `TIMER-ON ( -- )`: `PUSH DE` (save IP); `LD HL, tick_isr`; invoke
        `MBB_SET_USR_INT` per its calling convention (HL=routine); `POP DE`;
        `NEXT`. `TIMER-OFF ( -- )`: same but `LD HL,0` (disable).
  - [ ] In COLD (`src/antforth.asm` cold_start), after the UserArea/bank init
        block: zero `tick_count` (4 bytes) and install `tick_isr` via
        `MBB_SET_USR_INT` (straight asm — no Forth stack marshalling at COLD).
        Confirm the firmware accepts the install at boot (HW-smoke).
  - [ ] `; antforth extension` why-notes on both words (CCD-3).

- [ ] Task 5 — REPL-piped probe + Makefile target (AC: 5)
  - [ ] Create `tests/timer_tests.fth` (self-printing PASS/FAIL). Cover:
    - [ ] **Monotonic** — capture `TICKS` (2DUP to keep), busy-wait a short
          loop, capture `TICKS` again, assert `new old D<` is false AND they
          differ (advanced) → `PASS: ticks-monotonic`.
    - [ ] **32-bit carry (deterministic, NOT 17 min of waiting)** — see Dev
          Notes "Carry-probe technique": the probe seeds `tick_count` near a
          low-word boundary via a tiny helper CODE/word path OR asserts the
          carry logic by reading across a forced rollover. If no seed hook is
          exposed, assert the structural invariant (high word non-decreasing)
          and DEFER the true rollover assertion to the S9 HW-smoke (documented).
    - [ ] **TICKS is a clean double** — `TICKS DROP DROP` leaves depth unchanged
          net (pushes exactly 2 cells).
  - [ ] Add `make test-repl-timer` mirroring `test-repl-in-out`
        (Makefile:212-215 model): `TIMER_PROBE = tests/timer_tests.fth`, add to
        `.PHONY`, run under `$(IZCPM) $(IZCPM_DISKS)`. Column-0-anchored verdict.

- [ ] Task 6 — Docs + CCD-3 (AC: 8)
  - [ ] `docs/ans-forth-core-compliance.md`: add `TICKS`, `TIMER-ON`,
        `TIMER-OFF` as antforth-extension rows (non-ANS, NOT §-numbered).
  - [ ] Update `docs/phase4-memory-map.md` ONLY if the timer cells warrant a
        fixed-memory note (optional). Create/seed `docs/phase6-multitasker.md`
        is a LATER story (25.x) — not required here, but a stub TICKS note is OK.
  - [ ] Confirm `; antforth extension` flags present at all three words.

- [ ] Task 7 — Regression + close (AC: 6, 7, 8)
  - [ ] `make test-repl` (baseline/0) · `test-repl-asm` · `test-repl-value-to` ·
        `test-repl-in-out` · `test-repl-banking` · `test-straddle-regression` ·
        new `test-repl-timer` · `make check-doc-sync` 0-drift. All green.
  - [ ] Final `wc -c`; record delta vs baseline, itemised (Dev Notes byte budget).
  - [ ] S9 hardware-smoke (binary-delta story) — verify on real CP/M 2.2 /
        MicroBeast: COLD auto-install works; `TICKS` advances ≈64/s on a
        stopwatch; `TIMER-OFF` halts the counter, `TIMER-ON` resumes it; the
        true low→high rollover (if not assertable in-emulator). Post the recipe
        in the closing chat message (`feedback_post_hw_smoke_steps_at_review`,
        STRONG).

## Dev Notes

### Recommended implementation (synthesised from the live kernel map)

This story is the kernel-native productization of `disk/a/TRAFFIC.FTH`'s
hand-rolled timer. TRAFFIC builds its ISR with the *runtime Forth assembler*
(`CODE TICK-ISR ... END-CODE`) at the REPL and counts DOWN a `VARIABLE
TICKS-LEFT`. The kernel version instead: (a) lives in `src/timer.asm` as native
sjasmplus `DEFCODE`/asm, (b) counts UP a 32-bit monotonic `tick_count`, and (c)
is auto-installed at COLD so `TICKS` is always live.

**Why monotonic-up (not TRAFFIC's countdown):** the Phase-6 per-task `DELAY`
(Story 25.3) rides a stack-held *target* (`TICKS + n*64`) and yields with
`PAUSE` until `TICKS` reaches it — per-task for free, no shared mutable
countdown (architecture AD-P6-5). A single up-counter serves any number of
concurrent delays; TRAFFIC's single down-counter cannot.

### ISR register budget (finding (2)+(3))

The firmware fires the user interrupt after its own `EXX` and preserves `AF`.
Free: `HL` (shadow), `A`/flags. Live (must preserve): `BC`(TOS), `DE`(IP),
`IX`(rstack), `IY`(UserArea), `SP`. The 32-bit increment fits in HL+A exactly
(see Task 2 body). The ONLY trap is finding (3): `INC HL` sets no flags, so the
rollover test is the explicit `LD A,H / OR L / RET NZ`. End in `RET`.

### TICKS torn-read guard (finding (4))

```
w_TICKS:
        DEFCODE "TICKS", 0
w_TICKS_cf:
        DI                            ; ISR must not fire mid-read (torn value)
        LD   HL,(tick_count)          ; low cell
        PUSH HL                        ; low = second-on-stack
        LD   BC,(tick_count+2)         ; high cell → BC = TOS (§3.1.4.1)
        EI
        NEXT
```
This is the `2@` push shape (src/double.asm:31-48) without the address fetch.
DI/EI is correct at the REPL (interrupts always on); the window is ~12 T-states.

### Carry-probe technique (AC5 — the deterministic part)

A true low-word rollover is 65 536 ticks ≈ 17 min of real time — too long for an
automated gate. Options, in preference order:
1. **Seed-and-observe (preferred if cheap):** expose a tiny dev-only path to
   write `tick_count` near `0x0000FFF0` (e.g. a transient `CREATE`d cell aliased
   to the kernel address is NOT possible — the kernel cell isn't a Forth
   VARIABLE; instead add a guarded `(SET-TICKS) ( d -- )` test word OR assert via
   the HW-smoke). If a clean seed hook isn't justified for one probe, do NOT add
   kernel surface just to test — prefer option 2.
2. **Structural assertion in-emulator + rollover on HW (recommended):** the
   emulator probe asserts monotonic-non-decreasing + that the high word is
   readable and starts at 0; the genuine low→high rollover is asserted at S9
   hardware-smoke (let it run, or seed via a debugger). Document the split
   (NFR-P6-14: emulator = structure, hardware = wall-clock/long-run).
   **Default to option 2** unless the dev finds option 1 trivially cheap.

### Home-file decision

**New `src/timer.asm`** (per architecture AD-P6-7). Unlike Story 23.3's two tiny
words (which reused io.asm to avoid ceremony), Epic 24/25 is a *family* (TICKS,
DELAY, MS in 24.2; the multitasker references the same clock) — a dedicated
module is the right boundary and was the architecture's call. Cost: one INCLUDE
line in `src/antforth.asm` after `banking.asm` (:724). No Makefile OBJ edit
(antforth.asm is a single-unit assemble; INCLUDE is textual). The wordlist
re-scan at antforth.asm:778 registers the new DEFCODE entries — confirm the new
words appear in `WORDS` at dev-pass.

### COLD auto-install vs word-install (resolved at draft)

COLD auto-installs the kernel tick ISR so `TICKS` is live on every boot (serves
FR16 "read the current tick count" without a setup step, and gives the
multitasker a ready clock). `TIMER-OFF`/`TIMER-ON` exist so a user who wants the
single MBB user-interrupt slot for their OWN ISR can take it and give it back
(the slot is a shared resource — only one user interrupt at a time). NOTE: this
SUPERSEDES TRAFFIC.FTH's `START-CLOCK`/`STOP-CLOCK`/`(SET-USR-INT)`/`DELAY` — the
tutorial keeps its own copies (they still work standalone), but the kernel now
owns the slot by default. Flag this in the eventual tutorial-sequel story (25.8),
not here.

### Backward-compat note (AC7 / NFR-P6-12)

Auto-installing a 64 Hz ISR is a boot-behavior change, but it is NOT user-visible:
the ISR only increments a counter no Phase-1..5 program reads. The added per-tick
cost (~a few dozen T-states × 64/s at 8 MHz ≈ <0.05% CPU) is imperceptible
(NFR-P6-4). Verify the full `make test-repl` baseline is unmoved (AC7).

### Byte-budget rationale (itemised — B.2, no "mirrors prior arm" shorthand)

Per-component estimate (fixed memory). Each line is an independent itemisation:

- **`MBB_SET_USR_INT` EQU** — 0 B in the binary (assemble-time constant).
- **`tick_count` cells** — `DW 0` × 2 = **4 B** data.
- **`tick_isr`** — `LD HL,(nn)` (3) + `INC HL` (1) + `LD (nn),HL` (3) +
  `LD A,H` (1) + `OR L` (1) + `RET NZ` (1) + `LD HL,(nn)` (3) + `INC HL` (1) +
  `LD (nn),HL` (3) + `RET` (1) ≈ **18 B** code.
- **`TICKS` body** — `DI` (1) + `LD HL,(nn)` (3) + `PUSH HL` (1) +
  `LD BC,(nn)` (4, ED-prefixed) + `EI` (1) + `NEXT` (~1-2) ≈ **11-12 B**.
- **`TIMER-ON`/`TIMER-OFF` bodies** — each `PUSH DE` (1) + `LD HL,nn` (3) +
  the MBB invoke sequence (confirm calling form at dev-pass; ~3-6 B) +
  `POP DE` (1) + `NEXT` (~1-2) ≈ **9-13 B** each.
- **3 DEFCODE headers** — `TICKS`(5) `TIMER-ON`(8) `TIMER-OFF`(9) → header =
  4 B (link 2 + bank 1 + count_flags 1) + name → 9 + 12 + 13 = **34 B**.
- **COLD additions** — zero 4 bytes + install (LD HL + invoke) ≈ **8-12 B**.

**Story total ≈ 95-115 B** (code + data + headers + COLD). Larger than 23.3's
~43 B because this adds a new module, an ISR, a double-reader, two install words,
and COLD wiring — not two tiny words. Within the per-epic envelope to be agreed
at sprint planning (F5; ≈2.4× prior-phase pattern, project_epic17_envelope).
Re-measure the real delta at close (Task 7).

### Source tree components to touch

- `src/constants.asm` — add `MBB_SET_USR_INT EQU 0xFDC7` (:57-58 neighbourhood).
- `src/timer.asm` — NEW: `tick_count` cells, `tick_isr`, `TICKS`, `TIMER-ON`,
  `TIMER-OFF`.
- `src/antforth.asm` — add `INCLUDE "timer.asm"` after banking.asm (:724);
  COLD: zero `tick_count` + install `tick_isr`.
- `tests/timer_tests.fth` — NEW self-asserting probe.
- `Makefile` — `TIMER_PROBE` + `test-repl-timer` target + `.PHONY`.
- `docs/ans-forth-core-compliance.md` — TICKS/TIMER-ON/TIMER-OFF extension rows.

### Testing standards summary

REPL-piped Forth probes (S2/NFR-P6-16). Assert observable behaviour: TICKS
monotonic, clean double, high-word readable. The true 17-min rollover is HW-smoke
/ structural (NFR-P6-14). Keep probe lines ≤ TIB_SIZE=128 (S12); word-existence
pre-flight each new word (`' TICKS DROP` etc. at INTERPRET level — tick parses
from input, never inside a colon body — the 23.3 gotcha). Column-0-anchor verdict
greps (the 23.2 echoed-source lesson). Binary-delta story → S9 hardware-smoke
required before done; post the recipe in the closing chat message
(`feedback_post_hw_smoke_steps_at_review`, STRONG).

### Banking / hardware gotchas (verify empirically)

- `tick_isr` lives in FIXED memory (below $8000) so it fires regardless of which
  bank is mapped (architecture: fixed-memory ↔ banked boundary). Do NOT place
  the ISR or `tick_count` in a banked region.
- The ISR uses ONLY MBB_SET_USR_INT — never a direct interrupt-vector or MMU
  port write (NFR-P6-13).
- iz-cpm / iz-cpm-banking timer-interrupt fidelity: confirm the emulator fires
  the user interrupt (it may not model 0xFDC7 at all). If the emulator does NOT
  drive the 64 Hz interrupt, the monotonic/carry probe cannot advance under
  emulation — in that case the probe asserts install-doesn't-crash + TICKS reads
  a clean double, and ALL advancement/rate is HW-smoke (document this clearly;
  it is the NFR-P6-14 emulator/hardware split, not a defect). DETERMINE the
  emulator's behaviour at dev-pass before designing the probe's advance check.

### Project Structure Notes

- New kernel module `src/timer.asm` (architecture-sanctioned, AD-P6-7) — first
  Phase-6 file. INCLUDE after banking.asm; wordlist re-scan registers the words.
- `tick_count` is GLOBAL fixed-memory state, NOT a UserArea cell (it is one
  system clock, not per-task) — contrast the per-task subset of AD-P6-1.
- TICKS/TIMER-ON/TIMER-OFF are antforth EXTENSIONS (not ANS) — extension rows,
  no `§` numbers.
- No new THROW codes; no bank-aware machinery (MMU-agnostic fixed-memory words).

### References

- [Source: disk/a/TRAFFIC.FTH:11-46] — the prototype: TICK-ISR (EXX/RET/HL+A
  contract), (SET-USR-INT) (PUSH DE / 0xFDC7 / POP DE), DELAY (64 ticks = 1 s).
- [Source: src/constants.asm:57-58] — MBB_GET_PAGE/MBB_SET_PAGE; add MBB_SET_USR_INT here.
- [Source: src/macros.asm:62-101] — DEFCODE macro; header = link(2)+bank(1)+count_flags(1)+name.
- [Source: src/double.asm:31-48] — `2@`: the high-on-TOS double-push shape for TICKS.
- [Source: src/io.asm:198-225] — IN/OUT (Story 23.3): kernel hardware CODE-word + extension-flag precedent.
- [Source: src/antforth.asm:724] — INCLUDE list (add timer.asm after banking.asm).
- [Source: src/antforth.asm:778] — post-include wordlist re-scan (registers new DEFCODE words).
- [Source: src/antforth.asm: cold_start] — COLD init block (zero tick_count + install ISR).
- [Source: docs/register-conventions.md §2-3] — register contract; EXX leaf rule; what the ISR may touch.
- [Source: Makefile:212-215] — `test-repl-in-out` target (model for `test-repl-timer`); column-0 verdict.
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-5] — timer/ISR/32-bit TICKS/per-task DELAY decision.
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-7] — module boundaries (src/timer.asm).
- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story-24.1] — epic spec (FR13, FR16).
- [Source: _bmad-output/implementation-artifacts/23-3-z80-runtime-in-out-port-words.md] — house-style precedent (hardware CODE word, probe wiring, HW-smoke deferral).
- [Memory: reference_microbeast_user_interrupt_timer] — 0xFDC7 fires 64 Hz (NOT 60); ISR ends RET in fixed mem; STOP-CLOCK before FORGET; worked example TRAFFIC.FTH.
- [Memory: project_tos_in_register] — BC=TOS; doubles = HIGH cell on TOS, low second (§3.1.4.1).
- [Memory: project_phase6_concurrency_direction] — Phase-6 locks/forks; 32-bit TICKS (lead override); per-task DELAY rides the stack.
- [Memory: feedback_source_comment_discipline] — comment the why (CCD-3), never provenance.
- [Memory: feedback_post_hw_smoke_steps_at_review] — STRONG: post HW-smoke recipe in the closing chat message.
- [Memory: feedback_tib_size_inline_comments] — probe lines ≤ TIB_SIZE=128.
- [Memory: feedback_banking_probe_straddle_halt] — keep colon-body probes clear of $8000; drive at interpret level.
- [Memory: project_epic17_envelope] — epic byte estimates run low (~2.4×); F5 envelope to agree at sprint planning.

## Dev Agent Record

### Agent Model Used

_(to be filled by dev agent)_

### Debug Log References

### Completion Notes List

### File List

### Change Log
