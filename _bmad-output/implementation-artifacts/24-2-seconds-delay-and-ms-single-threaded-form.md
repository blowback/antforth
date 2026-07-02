# Story 24.2: Seconds DELAY and MS (single-threaded form)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Drafted 2026-06-29 by create-story workflow (context-engine pass).
     Story 24.2 is the SECOND and final story of Epic 24 (Timer & Hardware
     Words; Phase 6 — Concurrency & On-Device Applications → antforth 3.2.x).
     Deliverable: `DELAY ( u -- )` (seconds) and `MS ( u -- )` (milliseconds),
     two threaded colon words added to src/timer.asm that ride the 64 Hz
     `TICKS` double-counter shipped by Story 24.1 (done). Single-threaded
     busy-wait form; the loop is FACTORED so Story 25.3 can drop one `PAUSE`
     into it without touching the target-on-stack math.

     SEVEN load-bearing findings resolved at DRAFT TIME by reading live source
     (B.4 / PD-2 figure-drift discipline). Do NOT re-discover at dev-pass:

       (1) DELAY/MS ARE DEFWORD THREADED COLON WORDS — NOT DEFCODE.
           They are pure compositions of existing primitives (TICKS, UM*, D+,
           2OVER, D<, 0=, 2DROP, …), so they belong as `DEFWORD` threaded
           definitions appended to src/timer.asm AFTER `w_TIMER_OFF` — exactly
           the DMAX/DMIN/MIN/MAX house pattern (src/double.asm:433-470,
           src/bootstrap.asm:38-72). NO new DEFCODE, NO native asm. The threaded
           body is a `DW w_XXX_cf` cell list ending in `DW EXIT_CODE`; literals
           are `DW w_LIT_cf, value`; a `BEGIN…UNTIL` back-edge is
           `DW w_QBRANCH_cf` + `DW begin_label - $`. The post-include wordlist
           re-scan (antforth.asm:778) registers them automatically — confirm
           DELAY/MS appear in `WORDS` at dev-pass.

       (2) 🚨 EMULATOR-HANG TRAP — THE #1 DEV TRAP. iz-cpm-banking does NOT
           fire the MicroBeast 0xFDC7 user interrupt, so `tick_count` is FROZEN
           at 0 0 under emulation (Story 24.1 verified this empirically — two
           TICKS reads across a busy-wait both returned 0 0; see 24.1 Debug
           Log + tests/timer_tests.fth header). CONSEQUENCE: any *nonzero*
           `DELAY`/`MS` BUSY-WAITS FOREVER under the emulator (target = 0 + u*64
           is never reached because TICKS never advances) → `make
           test-repl-timer` HANGS, the whole gate wedges, downstream INFO lines
           vanish. THEREFORE the automated probe may call ONLY `0 DELAY` and
           `0 MS` (which exit on the first loop iteration — target == TICKS, so
           the wait condition is already satisfied). Every TIMED assertion
           (`60 DELAY` ≈ 60 s, `1000 MS` ≈ 1 s) is S9 HARDWARE-SMOKE ONLY
           (NFR-P6-14 emulator=structure / hardware=wall-clock split — identical
           to 24.1's rate/carry deferral). DO NOT put `1 DELAY` (or any nonzero
           wait) in tests/timer_tests.fth.

       (3) TARGET-ON-STACK MATH (no shared countdown cell) — AC3.
           `DELAY ( u -- )`: target = `TICKS + u*64`, computed as a DOUBLE held
           on the task's OWN data stack, then busy-wait until TICKS reaches it.
           Threaded shape (single-threaded form, NO PAUSE yet):
               64 UM*            ( ud = u*64, unsigned single×single→double )
               TICKS D+          ( target.d = TICKS + u*64 )
               (DELAY)           ( wait loop, finding (4) )
           UM* is ( u1 u2 -- ud ) (src/double.asm:484); D+ is ( d1 d2 -- d3 )
           (src/double.asm:230). NO shared mutable counter (contrast TRAFFIC's
           single `VARIABLE TICKS-LEFT`, disk/a/TRAFFIC.FTH:11/44-46) — the
           target lives on the caller's stack, so concurrent per-task delays in
           Phase 6 never interfere (architecture AD-P6-5, FR14/15).

       (4) FACTOR THE WAIT LOOP into one internal helper `(DELAY) ( target.d -- )`
           so Story 25.3's `PAUSE` has a SINGLE insertion site (AC3). The helper:
               BEGIN  TICKS 2OVER D< 0=  UNTIL  2DROP
           Stack walk (target T = Tlo Thi on entry, kept as the loop carry):
               TICKS   ( Tlo Thi Nlo Nhi )         N = now
               2OVER   ( Tlo Thi Nlo Nhi Tlo Thi ) copy target to top
               D<      ( Tlo Thi flag )            flag = N < T  (D< is d1<d2,
                                                    top double=d2=T, so N<T)
               0=      ( Tlo Thi flag' )           flag' = N >= T  (exit cond)
               UNTIL → QBRANCH back to BEGIN while flag'==0 (i.e. while N<T)
               2DROP   ( )                          drop the spent target
           25.3 change is EXACTLY one cell: insert `DW w_PAUSE_cf` before
           `DW w_TICKS_cf` inside `(DELAY)`. The target math in DELAY/MS is
           untouched — that is the whole point of factoring here (AC3).

       (5) `D<` IS SIGNED — AND THAT IS FINE. There is no `DU<` / `D>=` in the
           kernel (verified: only D<, D=, DMAX, DMIN exist, src/double.asm).
           Signed D< is correct for tick doubles because the 32-bit counter does
           not reach the sign bit (0x8000_0000) until 2^31 / 64 / 86400 ≈ 388
           days of continuous uptime, and any realistic DELAY target stays far
           below it. DO NOT "fix" this by inventing a DU< — note the ~388-day
           bound in a comment and move on. (If a future story ever needs
           multi-year uptimes, DU< becomes a separate deliverable.)

       (6) MS ROUND-DOWN IS NON-CONFORMANT — ROUND UP. 64 Hz ⇒ 1 tick =
           15.625 ms. Naive `u*64/1000` truncates: `10 MS` → 640/1000 = 0 ticks
           → ZERO wait. Forth-2012 §10.6.2.1905 is verbatim "Wait at least u
           milliseconds" (confirmed against forth-standard.org — the parameter
           is `u`, the guarantee is "at least"), so a 0-tick wait for nonzero u
           waits 0 ms < u ms and VIOLATES the standard — it is non-conformant,
           not merely a style choice. Round UP by adding 999 to the u*64 product
           before the /1000 divide:
               64 UM*  999 M+  1000 UM/MOD  ( rem quot )  SWAP DROP  S>D
           `M+` is ( d n -- d ) (adds a single to a double, src/double.asm).
           UM/MOD is ( ud u1 -- urem uquot ) (src/double.asm:597). This
           guarantees any nonzero u waits ≥1 tick (~15.6 ms). NOTE the
           granularity floor in a comment: MS is a coarse convenience over a
           15.625 ms tick, not a true-millisecond timer (AD-P6-5 "MS optional
           convenience"; AC names it "millisecond-granularity").

       (7) `NIP` DOES NOT EXIST — use `SWAP DROP` (in MS, to drop the UM/MOD
           remainder). Verified: no DEFCODE/DEFWORD "NIP" in src/*.asm.

     NO COLD EDIT NEEDED. Story 24.1 already auto-installs `tick_isr` at COLD
     (step 8j) and zero-inits `tick_count`, so TICKS is live by default on every
     boot. 24.2 adds only the two threaded words (+ one helper) — no boot wiring,
     no ISR change, no banking machinery.
-->

## Story

As the operator,
I want `DELAY` and `MS` words that wait a given duration,
so that I can pace single-threaded hardware sequences like the traffic light —
on the same 64 Hz clock the Phase-6 multitasker's yielding `DELAY` (Story 25.3)
will later ride without changing this target-on-stack math.

## Acceptance Criteria

1. **`DELAY ( u -- )` waits `u` seconds via a target on the data stack.** It
   computes `target = TICKS + u*64` as a **double** held on the caller's data
   stack (NO shared countdown cell), then busy-waits until `TICKS` reaches it.
   `60 DELAY` measures ≈ 60 s ±1 s on a stopwatch (NFR-P6-2). Implemented as a
   `DEFWORD` threaded colon word in `src/timer.asm` after `w_TIMER_OFF` (finding
   (1)/(3)).
2. **`MS ( u -- )` waits at least `u` milliseconds over the same counter.**
   Forth-2012 §10.6.2.1905 is verbatim *"Wait at least u milliseconds"* — so
   `target = TICKS + ceil(u*64/1000)`, rounded UP so any nonzero `u` waits at
   least one tick ≈ 15.6 ms. `10 MS` must NOT be a 0-tick no-op (rounding DOWN
   would wait 0 ms < 10 ms = NON-CONFORMANT; finding (6)). The standard's
   "implementation-defined resolution" note sanctions the 15.625 ms granularity.
   `1000 MS` ≈ 1 s; `500 MS` ≈ 0.5 s on the stopwatch.
3. **The wait loop is factored into ONE site so the multitasker can later drop a
   `PAUSE` into it without changing the target-on-stack math.** A single internal
   helper `(DELAY) ( target.d -- )` holds the `BEGIN TICKS 2OVER D< 0= UNTIL
   2DROP` loop; `DELAY` and `MS` both compute their target then call it. Story
   25.3's only change is inserting one `PAUSE` cell before the `TICKS` read in
   `(DELAY)` — DELAY/MS target math is untouched (finding (4); architecture
   AD-P6-5). No shared mutable countdown cell anywhere.
4. **`DELAY` and `MS` are stack-clean and `0`-degenerate-safe.** `0 DELAY` and
   `0 MS` exit immediately (target == current TICKS) leaving the stack as found;
   both consume exactly their one input cell and push nothing (`DEPTH`
   conserved). This is the ONLY timing behaviour the emulator can assert, because
   iz-cpm-banking does not advance `tick_count` (finding (2)).
5. **Automated REPL-piped probe asserts structure only (emulator).** Extend
   `tests/timer_tests.fth` (run by `make test-repl-timer`): `DELAY`/`MS` resolve
   as words; `0 DELAY` and `0 MS` return and conserve `DEPTH`; a runtime-computed
   witness (e.g. `6 7 *`) proves the interpreter is alive after each. Probe lines
   ≤ TIB_SIZE=128; verdicts column-0-anchored (`^PASS:`/`^FAIL:`). The probe MUST
   NOT call any nonzero `DELAY`/`MS` (it would busy-wait forever under emulation —
   finding (2)).
6. **Timed behaviour is hardware-verified (S9).** On real CP/M 2.2 / MicroBeast:
   `60 DELAY` ≈ 60 s ±1 s on a stopwatch (NFR-P6-2); `1000 MS` ≈ 1 s; `10 MS`
   produces a perceptible (≥1 tick) wait, not a no-op; and `disk/a/TRAFFIC.FTH`
   still runs end-to-end (its own `DELAY`/`START-CLOCK` redefinitions shadow the
   kernel words — finding (8) in Dev Notes). Emulator asserts structure;
   hardware asserts wall-clock (NFR-P6-14).
7. **Backward compatibility holds.** No COLD/ISR change (TICKS already
   auto-installed by 24.1); all Phase-1..5 + Story-24.1 behaviour unchanged.
   `make test-repl` holds at the current close-out baseline (0 FAIL),
   `test-repl-timer` stays green (existing 5 verdicts + the new DELAY/MS ones),
   `check-doc-sync` adds 0 new drift.
8. **`DELAY`/`MS` flagged `; antforth extension`?** `MS` is ANS/Forth-2012
   (§10.6.2.1905, FACILITY EXT) and `DELAY` is an antforth extension — flag each
   accordingly with a one-line why-note (no provenance —
   `feedback_source_comment_discipline`); the compliance doc gains the rows
   (MS under its `§`, DELAY as a non-standard extension row). Binary delta
   recorded and itemised at close.

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` → record in Dev
      Notes. Do NOT inherit Story 24.1's reported number — re-`wc -c` from the
      actual current build artifact (B.3 / Lesson 13.5-F). 24.1's change log
      ended at ≈ 29318 B (after the code-review lockless-TICKS +10 B and the
      `BYE` slot-release +6 B), but re-measure.
- [x] Capture current `make test-repl` baseline pass count and
      `make test-repl-timer` count (5 PASS / 0 FAIL expected) — both green
      pre-edit.

### Story tasks

- [x] Task 1 — Add the `(DELAY)` wait-loop helper to `src/timer.asm` (AC: 3, 4)
  - [x] Append after `w_TIMER_OFF` a `DEFWORD "(DELAY)", 0` ( target.d -- ).
        Body (finding (4)):
        ```
        w_PAREN_DELAY:
            DEFWORD "(DELAY)", 0
        w_PAREN_DELAY_body:
        w_PAREN_DELAY_cf EQU w_PAREN_DELAY_body - 3
        .pd_begin:
            DW  w_TICKS_cf
            DW  w_TWO_OVER_cf
            DW  w_D_LESS_cf
            DW  w_ZERO_EQUALS_cf
            DW  w_QBRANCH_cf
            DW  .pd_begin - $        ; UNTIL: loop back while N<T (flag'==0)
            DW  w_TWO_DROP_cf        ; drop the spent target double
            DW  EXIT_CODE
        ```
  - [x] Comment the single-PAUSE-insertion-point contract for Story 25.3
        (insert `DW w_PAUSE_cf` before `DW w_TICKS_cf`) and the signed-`D<`
        ~388-day bound (finding (5)). No provenance (CCD-3 / source-comment rule).
  - [x] `(DELAY)` is an internal helper (parenthesized name = kernel "internal"
        convention, cf. `(DLIT)`, `(?3)`); it carries a header so it is findable/
        testable, but is not advertised as a user word in the compliance doc.

- [x] Task 2 — `DELAY ( u -- )` (AC: 1)
  - [x] `DEFWORD "DELAY", 0`; body: `LIT 64  UM*  TICKS  D+  (DELAY)  EXIT`
        (finding (3)). `; antforth extension — busy-wait u seconds (64 ticks =
        1 s); single-threaded form, see (DELAY)`.
  - [x] Confirm `w_LIT_cf`, `w_U_M_STAR_cf` (UM*), `w_D_PLUS_cf` (D+),
        `w_TICKS_cf`, `w_PAREN_DELAY_cf` are the exact `_cf` labels at dev-pass.

- [x] Task 3 — `MS ( u -- )` (AC: 2)
  - [x] `DEFWORD "MS", 0`; body (round-UP, finding (6)/(7)):
        `LIT 64  UM*  LIT 999  M+  LIT 1000  UM/MOD  SWAP DROP  S>D  TICKS  D+
        (DELAY)  EXIT`.
  - [x] Confirm `w_M_PLUS_cf` (M+), `w_U_M_SLASH_MOD_cf` (UM/MOD), `w_SWAP_cf`,
        `w_DROP_cf`, `w_S_TO_D_cf` (S>D) at dev-pass.
  - [x] `; MS — Forth-2012 §10.6.2.1905: "Wait at least u milliseconds"; 15.625 ms
        tick granularity, rounded UP so the "at least" guarantee holds`. Comment
        the granularity floor (finding (6)).

- [x] Task 4 — Extend the REPL-piped probe (AC: 4, 5)
  - [x] In `tests/timer_tests.fth` add (emulator-safe — ONLY `0 DELAY`/`0 MS`,
        NEVER a nonzero wait; finding (2)):
    - [x] **Word-existence** — `' DELAY DROP  ' MS DROP  ." PASS: delay-ms-resolve" CR`
          at interpret level (tick parses from input — the 23.3 gotcha).
    - [x] **`0 DELAY` returns + stack-clean** — `DEPTH >R 0 DELAY DEPTH R> =`
          → `PASS: delay-zero-clean`.
    - [x] **`0 MS` returns + stack-clean** — `DEPTH >R 0 MS DEPTH R> =`
          → `PASS: ms-zero-clean`.
    - [x] **Interpreter alive after** — gate on a runtime-computed witness
          (`6 7 * 42 =`), never a bare echoed sentinel (the 23.2 echoed-source
          lesson) → `PASS: delay-ms-alive`.
  - [x] Update the `tests/timer_tests.fth` header comment: the DELAY/MS TIMED
        behaviour (wall-clock, MS granularity) is S9 HW-smoke, structure only
        here — same NFR-P6-14 split already documented for TICKS rate/carry.
  - [x] `make test-repl-timer` → existing 5 + new 4 = 9 column-0 PASS / 0 FAIL.

- [x] Task 5 — Docs + CCD-3 (AC: 8)
  - [x] `docs/ans-forth-core-compliance.md`: add `MS` under its Forth-2012 §
        (FACILITY EXT §10.6.2.1905) and `DELAY` as an antforth-extension row
        (non-§). `(DELAY)` is internal — do not advertise.
  - [x] Confirm `; antforth extension` (DELAY) / `; Forth-2012 …` (MS) why-notes
        present; no provenance comments.

- [x] Task 6 — Regression + close (AC: 6, 7, 8)
  - [x] `make test-repl` (unchanged from baseline) · `test-repl-timer` (9/0) ·
        `test-repl-asm` · `test-repl-value-to` · `test-repl-in-out` ·
        `test-repl-banking` · `test-straddle-regression` (3/3). All green.
        `make check-doc-sync`: confirm 0 NEW drift (the pre-existing Story-23.6
        architecture.md citation drift noted in 24.1 is out of scope — prove by
        stash-and-rerun if it reappears).
  - [x] Final `wc -c` and delta vs the Task-0 baseline. Itemise in Dev Agent
        Record against the ~85–105 B estimate (Dev Notes byte budget).
  - [x] S9 hardware-smoke (binary-delta story) — **DEFERRED to operator** on real
        CP/M 2.2 / MicroBeast: `60 DELAY` ≈ 60 s ±1 s on a stopwatch; `1000 MS`
        ≈ 1 s; `10 MS` is a perceptible ≥1-tick wait (not a no-op); concurrent /
        repeated `DELAY` calls each wait independently (target-on-stack, no shared
        cell); TRAFFIC.FTH still runs. Post the recipe IN THE CLOSING CHAT MESSAGE
        (`feedback_post_hw_smoke_steps_at_review`, STRONG).

## Dev Notes

### Recommended implementation (synthesised from the live kernel map)

This story finishes Epic 24 by composing the Story-24.1 `TICKS` double-counter
into two wait words. Everything is THREADED (DEFWORD) — no native asm, no DEFCODE
— so the work is: author three `DW`-cell bodies in `src/timer.asm`, extend one
probe, add two doc rows. The 64 Hz ISR + COLD auto-install already exist (24.1),
so TICKS is live and there is NO boot wiring to touch.

**Why factor `(DELAY)`:** AC3 requires the loop be structured so Story 25.3 can
drop a `PAUSE` in without changing DELAY/MS target math. Factoring the
`BEGIN TICKS 2OVER D< 0= UNTIL 2DROP` loop into one `(DELAY) ( target.d -- )`
helper gives 25.3 exactly one cell to insert (`DW w_PAUSE_cf` before
`DW w_TICKS_cf`) and keeps DELAY/MS as pure target-computation words. It also
de-duplicates the loop (one copy, not two) and is the right seam for the
yielding rewrite. (Inlining the loop in both words is the alternative; it costs
~the same bytes but gives 25.3 *two* edit sites and a duplicated loop — don't.)

### The exact threaded bodies (verified `_cf` labels — re-confirm at dev-pass)

```
; --- (DELAY) ( target.d -- )  internal wait loop; 25.3 inserts PAUSE here ---
w_PAREN_DELAY:
        DEFWORD "(DELAY)", 0
w_PAREN_DELAY_body:
w_PAREN_DELAY_cf EQU w_PAREN_DELAY_body - 3
.pd_begin:
        DW      w_TICKS_cf          ; ( target  now )
        DW      w_TWO_OVER_cf       ; ( target  now  target )
        DW      w_D_LESS_cf         ; ( target  flag=now<target )   D< is signed*
        DW      w_ZERO_EQUALS_cf    ; ( target  flag'=now>=target )
        DW      w_QBRANCH_cf
        DW      .pd_begin - $       ; UNTIL: loop while now<target
        DW      w_TWO_DROP_cf       ; ( )   drop spent target
        DW      EXIT_CODE
; *signed D< is safe: tick doubles stay below 0x8000_0000 for ~388 days uptime.

; --- DELAY ( u -- )  busy-wait u seconds ---
w_DELAY:
        DEFWORD "DELAY", 0
w_DELAY_body:
w_DELAY_cf EQU w_DELAY_body - 3
        DW      w_LIT_cf, 64
        DW      w_U_M_STAR_cf       ; ( ud = u*64 )
        DW      w_TICKS_cf
        DW      w_D_PLUS_cf         ; ( target = TICKS + u*64 )
        DW      w_PAREN_DELAY_cf
        DW      EXIT_CODE

; --- MS ( u -- )  wait at least u ms (15.625 ms tick granularity, round up) ---
w_MS:
        DEFWORD "MS", 0
w_MS_body:
w_MS_cf EQU w_MS_body - 3
        DW      w_LIT_cf, 64
        DW      w_U_M_STAR_cf       ; ( ud = u*64 )
        DW      w_LIT_cf, 999
        DW      w_M_PLUS_cf         ; ( ud + 999 )  round-up bias
        DW      w_LIT_cf, 1000
        DW      w_U_M_SLASH_MOD_cf  ; ( rem quot )  quot = ceil(u*64/1000)
        DW      w_SWAP_cf
        DW      w_DROP_cf           ; ( quot )  drop remainder (no NIP word)
        DW      w_S_TO_D_cf         ; ( quot.d )
        DW      w_TICKS_cf
        DW      w_D_PLUS_cf         ; ( target = TICKS + ceil(u*64/1000) )
        DW      w_PAREN_DELAY_cf
        DW      EXIT_CODE
```

Label cross-check (from live source): `w_TICKS_cf` (src/timer.asm:71),
`w_TWO_OVER_cf` (double.asm:141), `w_D_LESS_cf` (double.asm:401),
`w_ZERO_EQUALS_cf` (logic.asm:202), `w_QBRANCH_cf` (inner_interpreter.asm:300),
`w_TWO_DROP_cf` (double.asm:101), `w_LIT_cf` (inner_interpreter.asm),
`w_U_M_STAR_cf` (double.asm:485), `w_D_PLUS_cf` (double.asm:231),
`w_U_M_SLASH_MOD_cf` (double.asm:629), `w_SWAP_cf` (stack_ops.asm:49),
`w_DROP_cf` (stack_ops.asm:38), `w_S_TO_D_cf` (double.asm:166), `EXIT_CODE`
(inner_interpreter.asm:55). Confirm `w_M_PLUS_cf` (M+) at dev-pass.

### Emulator-hang trap (finding (2)) — re-stated because it is the #1 dev trap

`tick_count` never advances under iz-cpm-banking (the emulator doesn't model the
0xFDC7 user interrupt — Story 24.1 proved it; the existing timer probe and its
header document the split). So `1 DELAY` under emulation computes target = 64,
TICKS stays 0, `0 < 64` forever → the loop never exits → `make test-repl-timer`
HANGS, taking the gate (and CI) down with it. The probe is restricted to
`0 DELAY` / `0 MS`, which exit on the first iteration (target == TICKS, so
`now >= target` immediately). All wall-clock behaviour is S9 HW-smoke. This is
the NFR-P6-14 emulator=structure / hardware=timing split, not a defect.

### DELAY loop stack discipline (finding (4))

Entry `( Tlo Thi )` (target double). Each iteration: `TICKS` pushes `now`
`( Tlo Thi Nlo Nhi )`; `2OVER` copies the target to the top
`( Tlo Thi Nlo Nhi Tlo Thi )`; `D<` consumes the top two doubles (d1=now,
d2=target) → `now < target` `( Tlo Thi flag )`; `0=` → `now >= target`
`( Tlo Thi flag' )`; `QBRANCH .pd_begin` loops back while `flag'==0` (still
waiting), consuming the flag and restoring the `( Tlo Thi )` invariant. On exit
`2DROP` releases the target. `0 DELAY` exits on the first pass (now == target →
`now<target` false → `0=` true → fall through).

### MS rounding + granularity (finding (6))

64 Hz ⇒ 15.625 ms/tick. Forth-2012 §10.6.2.1905 is verbatim "Wait at least u
milliseconds" (parameter is `u`; guarantee is "at least" — confirmed against
forth-standard.org), so round the tick count UP: `ceil(u*64/1000) = (u*64 + 999)
/ 1000`, via `999 M+` before `1000 UM/MOD`. Without the bias, `10 MS` →
`640/1000` → 0 ticks → 0 ms wait < 10 ms — NON-CONFORMANT (violates "at least"),
not just a style miss. With it, any nonzero `u` waits ≥ 1 tick (~15.6 ms). The floor is
inherent to a 64 Hz clock; `MS` is a coarse convenience (AD-P6-5 "MS optional
convenience"), not a true-ms timer. `M+ ( d n -- d )` and `UM/MOD ( ud u1 --
urem uquot )` are the exact signatures (src/double.asm).

### Signed D< bound (finding (5))

The kernel has only signed `D<` (no `DU<`/`D>=`). Tick doubles never reach the
sign bit: 2^31 ticks / 64 Hz / 86400 s ≈ 388 days of continuous uptime, and any
realistic `DELAY` target (`TICKS + u*64`) stays well below 0x8000_0000. Signed
`D<` is therefore correct here. Comment the bound; do NOT add a `DU<` word for
this story.

### Byte-budget rationale (itemised — B.2, no "mirrors prior arm" shorthand)

Per-component, each line an independent itemisation (DEFWORD header = link 2 +
bank 1 + count_flags 1 + name; code field `JP DOCOL` = 3 B; each `DW` cell = 2 B):

- **`(DELAY)` helper** — header 4 + name `(DELAY)` 7 = 11 B; code field 3 B;
  body 8 cells (TICKS, 2OVER, D<, 0=, QBRANCH, back-offset, 2DROP, EXIT) × 2 =
  16 B → ≈ **30 B**.
- **`DELAY`** — header 4 + name 5 = 9 B; code field 3 B; body 7 cells (LIT, 64,
  UM*, TICKS, D+, (DELAY), EXIT) × 2 = 14 B → ≈ **26 B**.
- **`MS`** — header 4 + name 2 = 6 B; code field 3 B; body 16 cells (LIT, 64,
  UM*, LIT, 999, M+, LIT, 1000, UM/MOD, SWAP, DROP, S>D, TICKS, D+, (DELAY),
  EXIT) × 2 = 32 B → ≈ **41 B**.
- **Probe / docs** — 0 B in the binary (test + markdown).

**Story total ≈ 97 B (≈ 85–105 B band).** All threaded composition over existing
primitives — no native code. Re-measure the real delta at close (Task 6); the
~2.4× epic-envelope multiplier (project_epic17_envelope) does not apply to a pure
threaded-composition story with no new mechanism.

### Backward-compat note (AC7 / NFR-P6-12)

No COLD, ISR, or banking change — 24.2 only appends three threaded words. TICKS
is already live from 24.1's COLD auto-install. The full `make test-repl` baseline
must be unmoved; `test-repl-timer` gains 4 verdicts (5 → 9). Nothing Phase-1..5
or 24.1 reads is touched.

### TRAFFIC.FTH coexistence (finding (8) — for AC6 HW-smoke)

`disk/a/TRAFFIC.FTH` defines its OWN `DELAY`/`START-CLOCK`/`STOP-CLOCK` over a
`VARIABLE TICKS-LEFT` (lines 11, 38-46). Loading the tutorial REDEFINES `DELAY`
as a colon word, shadowing the kernel `DELAY` in the dictionary — so the tutorial
still runs unchanged after `INCLUDE`. The kernel `DELAY` supersedes it for
non-tutorial use; the tutorial *rewrite* (as a background task on the kernel
clock) is Story 25.8, NOT here. The AC6 "TRAFFIC.FTH still runs" check confirms
the redefinition path is intact (no name-clash hang).

### Source tree components to touch

- `src/timer.asm` — append `(DELAY)`, `DELAY`, `MS` DEFWORD threaded bodies
  after `w_TIMER_OFF`. (No `tick_count`/ISR/COLD change.)
- `tests/timer_tests.fth` — add 4 emulator-safe verdicts (`0 DELAY`/`0 MS`
  only); update the header's emulator/hardware-split note for DELAY/MS timing.
- `docs/ans-forth-core-compliance.md` — `MS` (Forth-2012 §10.6.2.1905) +
  `DELAY` (antforth extension) rows.
- (No `Makefile` change — `test-repl-timer` already runs `tests/timer_tests.fth`.)
- (No `src/antforth.asm` change — INCLUDE + wordlist re-scan already wired by 24.1;
  the new DEFCODE/DEFWORD entries are picked up automatically.)

### Testing standards summary

REPL-piped Forth probes (S2/NFR-P6-16) asserting OBSERVABLE behaviour: DELAY/MS
resolve, `0 DELAY`/`0 MS` return + conserve DEPTH, interpreter alive after.
NEVER a nonzero wait in-emulator (finding (2) — it hangs). Keep probe lines ≤
TIB_SIZE=128 (S12); word-existence pre-flight with `'` at INTERPRET level (tick
parses from input — never inside a colon body; the 23.3 gotcha). Column-0-anchor
verdict greps (the 23.2 echoed-source lesson). Binary-delta story → S9
hardware-smoke required before done; post the recipe in the closing chat message
(`feedback_post_hw_smoke_steps_at_review`, STRONG).

### Project Structure Notes

- Pure addition to the Story-24.1 module `src/timer.asm`; no new file, no COLD/
  ISR/banking edit. DELAY/MS are MMU-agnostic threaded words (they only read the
  fixed-memory TICKS counter).
- `DELAY` = antforth extension (no `§`); `MS` = Forth-2012 FACILITY EXT
  §10.6.2.1905 (cite the `§`). `(DELAY)` = internal helper (parenthesized; not
  advertised).
- No new THROW codes. No new data cells (target lives on the caller's stack — the
  whole point of the no-shared-countdown design, AD-P6-5).

### References

- [Source: src/timer.asm:1-160] — Story-24.1 module: `tick_count`, `tick_isr`,
  `TICKS` (lockless double read), `TIMER-ON`/`TIMER-OFF`. Append DELAY/MS after.
- [Source: src/double.asm:140-145] — `2OVER` ( copy second double ).
- [Source: src/double.asm:230-231] — `D+` ( d1 d2 -- d3 ).
- [Source: src/double.asm:400-401] — `D<` (signed; finding (5)).
- [Source: src/double.asm:484-485] — `UM*` ( u1 u2 -- ud ).
- [Source: src/double.asm:597,628-629] — `UM/MOD` ( ud u1 -- urem uquot ).
- [Source: src/double.asm:165-166] — `S>D` ( n -- d ).
- [Source: src/double.asm] — `M+` ( d n -- d ) (confirm `w_M_PLUS_cf`).
- [Source: src/logic.asm:201-202] — `0=` (`w_ZERO_EQUALS_cf`).
- [Source: src/inner_interpreter.asm:55,285,300] — `EXIT_CODE`, `BRANCH`, `?BRANCH`/`QBRANCH`.
- [Source: src/bootstrap.asm:38-72 / src/double.asm:433-470] — DEFWORD threaded-body house pattern (LIT, QBRANCH back-edge, EXIT); DMAX/DMIN/MIN/MAX.
- [Source: src/antforth.asm:778] — post-include wordlist re-scan (auto-registers DELAY/MS).
- [Source: disk/a/TRAFFIC.FTH:11,38-46] — tutorial DELAY/START-CLOCK over TICKS-LEFT; redefinition coexistence (finding (8)).
- [Source: tests/timer_tests.fth] — 24.1 probe to extend; emulator/hardware-split header.
- [Source: Makefile:172,228-230] — `TIMER_PROBE` + `test-repl-timer` target (no edit needed).
- [Source: _bmad-output/implementation-artifacts/24-1-64-hz-timer-interrupt-monotonic-ticks-counter.md] — TICKS shape, lockless read, emulator-doesn't-fire-0xFDC7 finding, HW-smoke pattern.
- [Source: _bmad-output/planning-artifacts/architecture.md#AD-P6-5] — target-on-stack per-task DELAY (`TICKS + u*64`, no shared countdown); MS optional convenience.
- [Source: _bmad-output/planning-artifacts/epics-phase6-epics-24-26.md#Story-24.2] — epic spec (FR13/FR16; NFR-P6-2; the "no shared countdown cell" + PAUSE-drop-in requirement).
- [Source: _bmad-output/planning-artifacts/prd-phase6-concurrency.md:413-414] — NFR-P6-2 (`60 DELAY` = 60 s ±1 s).
- [Memory: project_double_producer_push_bc] — double producers PUSH BC; relevant to TICKS shape DELAY/MS consume.
- [Memory: project_tos_in_register] — BC=TOS; doubles = HIGH cell on TOS, low second (§3.1.4.1).
- [Memory: reference_microbeast_user_interrupt_timer] — 0xFDC7 fires 64 Hz; ISR in fixed mem; the TRAFFIC.FTH worked example.
- [Memory: feedback_post_hw_smoke_steps_at_review] — STRONG: post HW-smoke recipe in the closing chat message.
- [Memory: feedback_tib_size_inline_comments] — probe lines ≤ TIB_SIZE=128.
- [Memory: feedback_banking_probe_straddle_halt] — drive bank/word orchestration at interpret level; keep colon-body probes clear of $8000.
- [Memory: project_epic17_envelope] — epic byte estimates run ~2.4× low for new mechanisms; a pure threaded-composition story is NOT a new mechanism (multiplier N/A).
- [Memory: feedback_source_comment_discipline] — comment the why (CCD-3), never provenance.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Opus 4.8) — dev-story workflow

### Debug Log References

- **Pre-edit baseline (re-measured, not inherited):** `wc -c build/antforth.com`
  = **29318 B**; `make test-repl` = 1005 PASS / 0 FAIL; `make test-repl-timer`
  = 5 PASS / 0 FAIL. All green pre-edit.
- **Label cross-check at dev-pass:** all 15 `_cf` labels confirmed in live source,
  including the flagged `w_M_PLUS_cf` (src/double.asm:201). DEFWORD house pattern
  (`DEFWORD "X",0` / `w_X_body:` / `w_X_cf EQU w_X_body - 3`, QBRANCH back-edge
  `.label - $`) confirmed against DMAX/DMIN (src/double.asm:433-475).
- **MS/DELAY arithmetic verified empirically** (replicated the target math without
  the wait, since the emulator can't advance TICKS): `10 MS`→1 tick (round-up holds,
  NOT a 0-tick no-op), `0 MS`→0 (degenerate-safe), `1000 MS`→64 (=1 s), `500 MS`→32
  (=0.5 s), `1 DELAY`→64 (=1 s), `60 DELAY`→3840 (=60 s). All correct.
- **🚨 Emulator-hang trap (finding (2)) respected:** probe calls ONLY `0 DELAY` /
  `0 MS` (first-pass exit); no nonzero wait — verified the timer gate does not hang.
- **Banking-gate straddle regression (the `feedback_banking_probe_straddle_halt`
  hazard) — found and fixed.** The +97 B kernel growth pushed `tests/banking_tests.fth`'s
  `_probe-minus-bank-ldir` colon body across the $8000 slot-2 window; both its PASS
  lines printed, then the IP wedged crossing $8000 in the cleanup tail, so the
  downstream `INFO: bank-store-t-states` witness vanished and `make test-repl-banking`
  failed. Confirmed introduced (not pre-existing) by stash-and-rerun: baseline
  29318 B passes banking 0-FAIL. Fix: converted that probe to interpret-level
  orchestration with raw `mbl-count:`/`mbl-data:` witnesses (the Story-23.2 cap-probe
  pattern), asserted via the Makefile. Full banking suite (incl. all downstream cap /
  iron-spike / 18.x / 19.x probes) green afterward — no secondary straddle.
- **check-doc-sync non-zero is PRE-EXISTING / out of scope** (Story-23.6 architecture.md
  citation + 15 PRD↔architecture advisories — all in untouched planning artifacts).
  Proven 0 NEW drift: stash-and-rerun output byte-identical (1 drift / 15 advisory)
  with and without this story's changes.

### Completion Notes List

Delivered Epic 24's second and final story: `DELAY ( u -- )` (seconds) and
`MS ( u -- )` (milliseconds) as `DEFWORD` threaded colon words appended to
`src/timer.asm`, plus the internal `(DELAY) ( target.d -- )` wait-loop helper.
All threaded composition over existing primitives — no native asm, no DEFCODE,
no COLD/ISR/banking change (TICKS is already auto-installed by Story 24.1).

- **AC1 — `DELAY`:** `target = TICKS + u*64` (double on the caller's own stack, no
  shared countdown cell) via `LIT 64 UM* TICKS D+`, then `(DELAY)`. Timed
  wall-clock (`60 DELAY` ≈ 60 s) is S9 HW-smoke (emulator can't advance TICKS);
  target arithmetic verified above.
- **AC2 — `MS`:** `target = TICKS + ceil(u*64/1000)` with a `999 M+` round-UP bias
  before `1000 UM/MOD` so any nonzero `u` waits ≥1 tick (15.625 ms) — a naive
  round-down (`10 MS`→0 ticks) would be a 0 ms wait, NON-CONFORMANT to Forth-2012
  §10.6.2.1905 "Wait at least u milliseconds". `NIP` doesn't exist → `SWAP DROP`.
- **AC3 — factored wait loop:** the `BEGIN TICKS 2OVER D< 0= UNTIL 2DROP` loop lives
  in the single internal `(DELAY)` helper; Story 25.3's only change is inserting one
  `DW w_PAUSE_cf` before `DW w_TICKS_cf` (commented in-source as the insertion seam).
  DELAY/MS target math is untouched by that change.
- **AC4 — stack-clean / 0-degenerate-safe:** `0 DELAY` / `0 MS` exit on the first
  loop pass (target == current TICKS); DEPTH conserved. Asserted by the emulator probe.
- **AC5 — emulator probe (structure only):** `tests/timer_tests.fth` gains 4 verdicts
  (5→9): `delay-ms-resolve`, `delay-zero-clean`, `ms-zero-clean`, `delay-ms-alive`
  (runtime-computed `6 7 *` witness). ONLY `0 DELAY` / `0 MS` (no nonzero wait — would
  busy-wait forever under emulation). Probe lines ≤ TIB_SIZE; column-0-anchored.
  The `test-repl-timer` Makefile target was extended to assert all 9 patterns (the
  draft's "no Makefile change" note was contradicted by the live target, which
  hard-codes its expected pattern list — the 4 new verdicts would otherwise print
  but go unchecked, leaving AC5's "9 PASS / 0 FAIL" gate hollow).
- **AC6 — timed behaviour: S9 HARDWARE-SMOKE PASS (Ant, real MicroBeast / CP/M 2.2,
  2026-06-29).** `60 DELAY` ≈ 60 s on the stopwatch; `1000 MS` ≈ 1 s; `500 MS`; `10 MS`
  a perceptible (non-no-op) wait; `0 DELAY 0 MS` returns immediately; and the
  independence check `: T2 5 DELAY ." five" 5 DELAY ." ten" ; T2` → `fiveten` (two
  sequential stack-held targets, no shared cell). The `TRAFFIC.FTH` coexistence
  sub-check was deliberately SKIPPED by the operator: its `START-CLOCK` installs its
  own user-interrupt handler, evicting the kernel `tick_isr`, after which a nonzero
  kernel `DELAY`/`MS` would busy-wait forever (frozen TICKS) until `TIMER-ON` — a real
  operational hazard, sensibly avoided. The `: DELAY ...` redefinition-compiles-clean
  piece is the only unconfirmed sliver; low-risk (Forth redefinition is well-trodden).
  See [[reference_microbeast_user_interrupt_timer]] for the DELAY/MS-needs-tick-ISR
  hang gotcha now recorded.
- **AC7 — backward compat:** no COLD/ISR/banking change; `test-repl` holds at 1005/0;
  `test-repl-timer` 5→9; all close-out gates green; check-doc-sync 0 new drift.
- **AC8 — docs / CCD-3:** `docs/ans-forth-core-compliance.md` gains a `DELAY`
  (antforth-extension) row and an `MS` (Forth-2012 §10.6.2.1905, FACILITY EXT) row;
  `(DELAY)` is internal and not advertised. Why-note comments in source, no provenance.

**Binary delta: 29318 → 29415 B = +97 B**, exactly the Dev-Notes itemised estimate
(≈97 B, 85–105 band): (DELAY) ≈30, DELAY ≈26, MS ≈41. Probe + docs are 0 B.

**Out-of-scope but required for AC7 (test-infra fix, 0 binary B):** the banking-gate
straddle regression above forced a probe restructure in `tests/banking_tests.fth`
(+ the two corresponding Makefile pattern swaps). This is the documented kernel-growth
straddle hazard, not a feature defect — feature is fine; the probe was fixed.

### File List

- `src/timer.asm` — appended `(DELAY)`, `DELAY`, `MS` DEFWORD threaded bodies after
  `w_TIMER_OFF` (+97 B; the only binary-affecting change).
- `tests/timer_tests.fth` — added 4 emulator-safe DELAY/MS structure verdicts;
  updated the header's emulator/hardware-split note for DELAY/MS timing.
- `Makefile` — `test-repl-timer`: assert the 4 new timer verdicts (5→9 patterns) +
  comment/echo update. `test-repl-banking`: swapped the two `minus-bank-ldir-shift-*`
  PASS patterns for the new interpret-level `mbl-count: 2` / `mbl-data: 35` witnesses.
- `tests/banking_tests.fth` — converted `_probe-minus-bank-ldir` from a (now
  $8000-straddling) colon body to interpret-level orchestration with raw witnesses
  (straddle-hazard fix; no behaviour change to what is verified).
- `docs/ans-forth-core-compliance.md` — added `DELAY` (antforth extension) and `MS`
  (Forth-2012 §10.6.2.1905 FACILITY EXT) rows to the non-standard-words table.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — story 24.2
  ready-for-dev → in-progress → review.

### Change Log

- 2026-06-29 — Story 24.2 implemented (dev-story workflow). Added `DELAY`/`MS`/`(DELAY)`
  threaded words to src/timer.asm (+97 B); extended the timer probe (5→9 verdicts) and
  its Makefile gate; added DELAY/MS compliance-doc rows. Fixed a kernel-growth straddle
  regression in the banking probe (`_probe-minus-bank-ldir` → interpret-level driving).
  All close-out gates green (test-repl 1005/0, test-repl-timer 9/0, asm/value-to/in-out,
  banking incl. isolated, straddle 3/3, file-sanity; check-doc-sync 0 new drift). Status
  → review. Timed wall-clock behaviour (AC6) deferred to operator hardware-smoke.
- 2026-06-29 — AC6 S9 hardware-smoke PASS on real MicroBeast / CP/M 2.2 (Ant):
  `60 DELAY`≈60 s, `1000/500/10 MS`, `0 DELAY 0 MS` immediate, and independence
  (`T2` two-DELAY → `fiveten`) all confirmed on silicon. TRAFFIC.FTH coexistence
  sub-check skipped by operator (its ISR takeover would freeze kernel TICKS → recorded
  as a hang gotcha in memory). Timing AC fully satisfied on hardware.
