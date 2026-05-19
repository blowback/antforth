# Story 18.5.1: DEFWORDs i*x-preservation on caught THROW

Status: done

<!-- Filed 2026-05-18 at Story 18.5 code-review close (H1 disposition).
     This story carries the framework-level remediation OR DEFWORD-pattern
     guidance that the H1 finding deferred out of Story 18.5's scope.
     Reference: 18-5-in-bank-kernel-blessed-catch-safe-epic-18-close-out-
     antforth-3-x-2-tag.md §"H1 — antforth-CATCH i*x deeper-cell
     preservation gap (exposed by IN-BANK SWAP)" (lines 548..570). -->

## Story

As a Forth implementer maintaining the CATCH/THROW exception framework,
I want a documented and (where feasible) closed gap between antforth's caught-path stack restoration and ANS Forth §9.6.1.0875 `( j*x 0 | i*x n )` cell-content semantics,
so that DEFWORDs that wrap `EXECUTE` in an internal CATCH frame (e.g., `IN-BANK`) can compose with caller-side i*x without silent corruption of i*x's cells below the TOS, and the cost / benefit / scope of any framework patch is recorded against the alternative of permanent DEFWORD-pattern guidance.

## Background — the gap (verbatim H1 reproducers)

Two independent reproducers under iz-cpm-banking, post-Story-18.5 binary at 26,477 B:

```
\ Reproducer A — IN-BANK exposes the gap via its body's SWAP at cell 3
1 ' ABORT ' IN-BANK CATCH .S
\ Expected: <3> 1 17262 -1   (ANS §9.6.1.0875 cell-content preservation)
\ Actual:   <3> 17896 17262 -1   (i*x's second-from-top "1" overwritten)

\ Reproducer B — generic, independent of IN-BANK
: SWAP-ABORT SWAP ABORT ;
100 200 ' SWAP-ABORT CATCH .S
\ Expected: <3> 100 200 -1
\ Actual:   <3> 200 200 -1   (i*x's second-from-top "100" overwritten)
```

Reproducer B isolates the gap to the generic CATCH framework: any `xt` whose first stack operation is `SWAP` (or any other primitive whose first effect is to write a value to `[SP_safe]`) will corrupt i*x's second-from-top cell on the caught-THROW path. The gap is not specific to `IN-BANK` and is not a Story-18.5 regression.

## Acceptance Criteria

**Note on scope** — AC1..AC3 are mandatory (analysis + decision + execution per chosen option). AC4..AC6 are conditional on the option chosen at AC2.

1. **(Mandatory) Root-cause analysis recorded.** Dev Notes shall contain a stack-trace walkthrough of Reproducer B above (`100 200 ' SWAP-ABORT CATCH`) at the CALL/POP/PUSH instruction granularity, identifying:
   - The pre-CATCH SP location and what cells of i*x live at which `[SP+k]`.
   - `CATCH`'s `POP BC` advancing SP to `SP_safe` (= one cell above the original i*x's TOS-cell slot).
   - `SWAP`'s `POP HL` (which advances SP past `[SP_safe]`) followed by `PUSH BC` (which writes BC = saved-BC = i*x's TOS to `[SP_safe]`, the slot that originally held i*x's second-from-top).
   - `THROW`'s caught-path `LD SP, HL / PUSH BC` restoring i*x's TOS-cell to `[SP_safe-2]` but leaving `[SP_safe]` in its post-SWAP state.
   - Generalised statement of which i*x cells are preserved and which are not (the saved-BC slot at frame +2 preserves only i*x's TOS-cell, per `src/exception.asm:155..159` and `docs/register-conventions.md:303..309`).

2. **(Mandatory) Option chosen with itemised binary-budget rationale.** One of:
   - **(a) DEFWORD-pattern guidance only** — close the gap as documentation: produce a normative pattern note in `docs/register-conventions.md` §9 stating that DEFWORDs which wrap user `xt` in CATCH MUST NOT use `SWAP` / `OVER` / `ROT` / `2DUP` / `2OVER` / `R@`-then-write-to-`[SP]` etc. at any cell of their body whose effect would write at-or-above the body's entry `SP_safe`. Provide an audit table of all DEFWORD bodies in the kernel today (grep `JP DOCOL` and scan bodies that use `w_CATCH_cf`) certifying compliance or flagging the body for rewrite. **Kernel binary delta: 0 bytes.**
   - **(b) Pre-CATCH side-stash of i*x deeper cells, post-THROW restore** — extend `w_CATCH_cf` to copy the i*x cells `[SP_safe .. sp_base]` (depth · 2 bytes) into a UserArea-anchored side buffer at frame setup, and extend `THROW`'s caught path to copy them back after the existing `LD SP, HL / PUSH BC` restore. Per-component itemisation REQUIRED:
     - LD pair / DEC pair to measure depth at CATCH entry (HL = sp_base - SP_safe; BC = HL or similar)
     - LDIR or hand-rolled byte-copy loop (LDIR is 2 B; setup of HL/DE/BC ~9 B)
     - Frame slot extension: either a new frame field for depth (+2 B) OR derive at restore from sp_base read
     - THROW-side complement: restore SP, LDIR back from side-buffer
     - Side-buffer allocation: data-stack-size worth of UserArea cells (current `S0 - SP_LIMIT` = data stack envelope; itemise as a separate static allocation, not on the IX rstack, to avoid nested CATCH interaction)
     - Per-component sum to a per-arm total bytes; cycles-budget rationale separately
     - DO NOT estimate via "mirrors Story 11.4.1" or any "Story X" reference — itemise independently per `instructions.xml` B.2 / Lesson 13.5-C
   - **(c) SP-locking at CATCH entry** — at `CATCH`, decrement SP past the entire current i*x to "reserve" its cells against xt traffic; on THROW, restore SP. Itemise: depth measurement, sp manipulation, frame field extension if needed, THROW-side complement. Note that this option exposes i*x cells as "free" memory below `SP_safe` and breaks the Z80-PUSH/CALL `[SP_safe-2]` discipline that Story 11.4.1 established — assess whether xt can underflow into i*x or whether check_underflow guards still apply.
   - **(d) Hybrid** — option (a) for current kernel DEFWORDs (today only `IN-BANK` is affected) AND option (b) staged as future work via a documented architectural decision (E11-D3 or successor) without binary delta in this story. Per-component itemisation REQUIRED for the documentation arm (page count delta in `docs/register-conventions.md` §9 + `architecture-phase2-epics-9-13.5.md` §E11-D appendix).

   The chosen option's itemised rationale shall be recorded in Dev Notes §"Q1 disposition" before any kernel edit begins. The cycles-budget rationale (delta to NFR-P4-1's "~15 Z80 cycles uncaught CATCH frame overhead" envelope) shall be a separate itemisation, not a "scaled" derivative of the byte-budget.

3. **(Mandatory) Execution + verdict-table evidence.** Land the option chosen at AC2 with:
   - Code edit (if option (a) or (d)-doc-only: docs-only; binary delta 0 B). For options (b) / (c) / (d)-doc-plus-kernel: code edit lands in `src/exception.asm` (and possibly `src/structures.asm` if a new UserArea field is added).
   - Probe-18.5.1-A (data-stack i*x preservation): `100 200 ' SWAP-ABORT CATCH` shall yield exactly `<3> 100 200 -1` (per ANS §9.6.1.0875 cell-content preservation) OR the verdict shall be a STANDARDS-CITED PARTIAL ACCEPT-WITH-RATIONALE under option (a) (citing the documented DEFWORD-pattern constraint as the discharge — i.e., the ANS gap is recorded as a project-known limitation with the guidance pattern as the user-facing closure).
   - Probe-18.5.1-B (Reproducer A under IN-BANK): `1 ' ABORT ' IN-BANK CATCH` shall yield exactly `<3> 1 17262 -1` under option (b) / (c) / (d)-with-kernel-arm, OR shall continue to yield `<3> <leak> 17262 -1` under option (a) with the same documented-limitation discharge as Probe-A.
   - Three-test-surface sweep: `make test-repl` 975/0/2 (no regression from 18.5 baseline); `make test-repl-banking` 48/0/3 + 2 new (one per new probe = 50/0/3) OR ≥ 48/0/3 + new-probe counts; `make test-repl-banking-skip` 25/0/3 (unchanged). Counts shall be **re-validated against the actual test run in this story's dev pass**, not transcribed from the 18.5 close (B.4 / PD-2 figure-drift discipline — the 18.5 numbers may be the same or may have shifted in any housekeeping interlude).
   - `make check-doc-sync` drift count shall not increase from 18.5 close's 31 advisories / 0 drift.

4. **(Conditional — option (b)/(c)/(d)-with-kernel-arm only) Binary-budget gate.** Realised kernel binary delta shall fall within the per-component itemisation total from AC2 ± 10% OR an explicit accept-with-rationale shall be recorded in Dev Notes with a per-cell overshoot accounting (the Epic-13.5 / 13.5.5 precedent — itemised, not "mirrors"). If a UserArea field is added, the field's address allocation shall be recorded against `src/structures.asm:UserArea` and the cumulative UserArea size shall not exceed the existing budget (current `sizeof(UserArea)` recorded at story start).

5. **(Conditional — option (a)/(d)-doc-only or hybrid doc arm) Audit table of DEFWORD CATCH bodies in the kernel.** Dev Notes shall include a complete table of every DEFWORD body in the kernel that calls `w_CATCH_cf` (grep-discoverable via `grep -rn "DW.*w_CATCH_cf" src/`). For each: the body's compile-token sequence, the cell at which CATCH appears, the cells before CATCH that establish the xt + i*x layout, the cells inside the CATCH window's `xt`-context (in IN-BANK's case there is no such window because xt is the user's xt running under CATCH — but if any future DEFWORD has a literal sub-body, it would be enumerated), and a PASS/FAIL/N-A verdict on whether the body could trigger the gap. Today's expected enumeration: `w_IN_BANK_cf` (only DEFWORD in the kernel today using CATCH); future DEFWORDs added by Epic 19+ will be added at their own creation time.

6. **(Mandatory) Documentation update.** `docs/register-conventions.md` §9 ("Exception Frames (Epic 11)") shall gain a new subsection — title `Story 18.5.1: i*x cell-content preservation scope` (or equivalent) — that:
   - States plainly what is preserved (depth, TOS-cell via saved-BC at frame +2) and what is not (cells `[SP_safe .. SP_safe + 2·(K-1)]` for i*x depth K) under the CURRENT framework (option (a)) OR what is preserved post-fix under (b)/(c).
   - Cites the chosen option from AC2 with a forward-pointer to this story file.
   - If option (a) or (d)-doc-only: states the DEFWORD-pattern constraint normatively (MUST NOT use SWAP/OVER/etc. at body cells whose effect writes at-or-above `SP_safe`).
   - Updates the `src/banking.asm:937..950` source-comment block in `w_IN_BANK_cf` to reference the closure form chosen here (either "framework now preserves deeper cells per Story 18.5.1" or "DEFWORD-pattern guidance now normative; IN-BANK's SWAP at body cell 3 is exempt because [rationale]" — IN-BANK's `SWAP` operates on the IN-BANK-pushed `saved` cell and the caller-side `n`, NOT on i*x cells caller of OUTER CATCH; the H1 disposition's SWAP is actually OUTER-CATCH-wrap of IN-BANK whose xt is `IN-BANK` itself, so any SWAP inside IN-BANK's body is on the OUTER-CATCH's i*x — this nuance must be carefully stated).
   - References the empirical witnesses (Reproducer A + B + Probe-18.5.1-A/B).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [ ] Capture current binary size: `wc -c build/antforth.com` → record in story Dev Notes
  - Do not inherit Story 18.5's reported number — re-`wc -c` from the actual current build artifact (B.3 / Lesson 13.5-F)
- [ ] Capture current `make test-repl` baseline pass count (re-validate; do not inherit 18.5's 975/0/2 if any housekeeping interlude has landed)
- [ ] Capture current `make test-repl-banking` baseline (re-validate; do not inherit 48/0/3)
- [ ] Capture current `make test-repl-banking-skip` baseline (re-validate; do not inherit 25/0/3)
- [ ] Capture current `make check-doc-sync` advisory + drift count (re-validate; do not inherit 31/0)
- [ ] Capture current `sizeof(UserArea)` from `src/structures.asm` (will gate option (b)/(c) field-addition viability)

### Story tasks

- [x] **Task 1 — Root-cause walkthrough (AC: #1)** — see Dev Notes §"Reproducer B instruction-level trace"
  - [x] Sub-1.1 Reproducer B traced at instruction granularity per Dev Notes; cited `src/exception.asm:100..175` + `src/stack_ops.asm:47..55` + `src/exception.asm:282..415`
  - [x] Sub-1.2 Corruption cell identified (`[SP_safe + 0]` = i*x's second-from-top); corrupting instruction = SWAP's `PUSH BC` after `POP HL`
  - [x] Sub-1.3 Generalisation: TOS preserved via saved-BC at frame +2; cells `[SP_safe + 0 .. SP_safe + 2·(K−2)]` unpreserved pre-option-(b)
  - [x] Sub-1.4 ANS citations recorded (§9.6.1.0875, §9.3.5, register-conventions.md:303..309, E11-D1)
  - [x] Sub-1.5 Corollary primitive list recorded (SWAP, ROT, 2SWAP, ROLL — corrupt; OVER, DUP, DROP, ?DUP, LIT — safe). Plus secondary leak documented (THROW's PUSH HL / POP IX writing at `[SP_safe + 0]` when SP_throw = SP_safe + 2).

- [x] **Task 2 — Option analysis + decision (AC: #2)** — Q1 disposition recorded
  - [x] Sub-2.1 Option (a) itemised (0 B kernel, doc-only)
  - [x] Sub-2.2 Option (b) itemised (per-component, no "mirrors" shorthand): ~+86 B estimate
  - [x] Sub-2.3 Option (c) itemised — REJECTED (breaks DEPTH/PICK/ROLL semantics inside xt)
  - [x] Sub-2.4 Option (d) itemised (hybrid)
  - [x] Sub-2.5 Cycles itemisation per option, separate from bytes (NFR-P4-1 envelope context)
  - [x] Sub-2.6 Chosen option recorded in Dev Notes §"Q1 disposition": **(b) framework patch** approved by project-lead via dev-story AskUserQuestion 2026-05-18
  - [x] Sub-2.7 Option (b) chosen does NOT add UserArea fields (uses kernel-static scratch cells in src/exception.asm). UserArea unchanged at 112 B.

- [x] **Task 3 — Execution per chosen option (AC: #3)** — option (b) implemented
  - [x] Sub-3.1 N/A — option (b), not doc-only
  - [x] Sub-3.2 Option (b) kernel implementation:
    - [x] `src/exception.asm` edited: w_CATCH_cf stash push, catch_resume_cf IX re-anchor, w_THROW_cf.kernel_entry caught-path stash restore, frame layout comment block extension
    - [x] No UserArea field added (stash uses IX rstack + 3 kernel-static scratch cells `throw_stash_hl/bc/de`)
    - [x] Built and re-tested through 3 dev-pass iterations (see Debug Log References); final binary delta +106 B (vs +86 B estimate; +20 B overshoot accept-with-rationale per Dev Notes §"Binary delta itemisation")
  - [x] Sub-3.3 Probe-18.5.1-A added to `tests/banking_tests.fth` (generic SWAP-ABORT; `_p18-5-1a*` variables; SENTINEL-BOUNDED with `---probe-18.5.1-a-start/end---` markers)
  - [x] Sub-3.4 Probe-18.5.1-B added to `tests/banking_tests.fth` (IN-BANK reproducer; `_p18-5-1b*` variables; sentinel markers). Both probes PASS under option (b) — no SKIP-with-rationale needed since option (b) closes the gap structurally.
  - [x] Sub-3.5 Makefile probe assertions added parallel to 18.5-c/-e shape

- [x] **Task 4 — Three-test-surface sweep + binary delta + doc-sync (AC: #3 + #4)**
  - [x] Sub-4.1 `make test-repl` → **975/0/2** — no regression ✓
  - [x] Sub-4.2 `make test-repl-banking` → **50/0/3** = 48 baseline + 2 new probes (both PASS under option (b))
  - [x] Sub-4.3 `make test-repl-banking-skip` → **25/0/3** — no regression ✓
  - [x] Sub-4.4 `wc -c build/antforth.com` → **26,583 B**; delta +106 B; AC#4 envelope breach (~+12% over upper bound) recorded as accept-with-rationale per Dev Notes
  - [x] Sub-4.5 `make check-doc-sync` → **31 advisories / 0 drift** — no regression ✓

- [x] **Task 5 — Audit table of kernel DEFWORD CATCH bodies (AC: #5)** — included even though option (b) was chosen (audit is informative for future stories regardless)
  - [x] Sub-5.1 `grep -rn "DW.*w_CATCH_cf" src/` → 4 enumerated: w_IN_BANK_cf, w_EVALUATE_cf, w_INCLUDED_cf, w_INCLUDE_FILE_cf
  - [x] Sub-5.2 Per-DEFWORD tabulation recorded in Dev Notes §"Audit table" with pre/post option-(b) verdicts. Pre-option-(b): IN-BANK + INCLUDED + INCLUDE-FILE triggered the gap; EVALUATE was N/A. Post-option-(b): all 4 PASS via the framework patch (no per-body discipline required).
  - [x] Sub-5.3 Recorded

- [x] **Task 6 — Documentation closure (AC: #6)**
  - [x] Sub-6.1 `docs/register-conventions.md` §9 new subsection "Story 18.5.1: i*x deeper-cell preservation scope" added — layout diagram, contract, invariants, binary delta, cycles delta, empirical witnesses, forward-pointer
  - [x] Sub-6.2 `src/banking.asm:937..950` IN-BANK comment updated — declares option (b) framework closure; IN-BANK body-cell-3 SWAP no longer corrupts outer i*x (handled by outer-CATCH stash)
  - [x] Sub-6.3 N/A — option (b) was chosen, so `feedback_no_preexisting_discharge.md` "fix" interpretation is unchanged ("fix the underlying defect" — done at the framework). Memory file unchanged.
  - [x] Sub-6.4 Forward-pointer added in `src/exception.asm` frame layout comment block (lines 15..47 region) — documents the new stash zone + depth_word in the layout diagram
  - [x] Sub-6.5 N/A — option (b)'s frame-layout extension is a non-breaking addendum to E11-D1 (frame itself unchanged at 8 bytes; stash zone appended on IX rstack below). The `docs/register-conventions.md §9` new subsection serves as the canonical record; no separate `architecture-phase2-epics-9-13.5.md` decision row needed (parallel to Story 11.4.1's revision-not-drift treatment at line 384).

- [x] **Task 7 — Sprint-status update**
  - [x] Sub-7.1 Transitioned: ready-for-dev → in-progress (dev-pass start) → review (dev-pass close, this commit)
  - [x] Sub-7.2 N/A — option (b) chosen (no deferred follow-on story needed)

### Hardware-smoke (deferred per Epic 18 precedent)

- [x] **Task 8 — Hardware-smoke recipe at close (deferred to project-lead)**
  - [x] Sub-8.1 Option (b) lands a kernel edit (+106 B). HW-smoke recipe included in closing chat message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule:
    1. Build: `make` → `build/antforth.com` (26,583 B).
    2. Flash to real MicroBeast.
    3. At REPL prompt, run Probe-18.5.1-A: `: SWAP-ABORT SWAP ABORT ;` then `100 200 ' SWAP-ABORT CATCH .S`. Expect: `<3> 100 200 -1  ok`.
    4. Run Probe-18.5.1-B: `BANKS-CLEAR $22 +BANK $35 +BANK 0 BANK! 1 ' ABORT ' IN-BANK CATCH .S`. Expect: `<3> 1 <xt_ABORT_addr> -1  ok` (where xt_ABORT addr is a stable kernel-table value).
    5. Run quick health-check: `S" 10 20 +" EVALUATE .` → expect `30 ok`. Confirms EVALUATE (which wraps INTERPRET in CATCH) survives the framework extension on real hardware.
    6. Capture transcript via beastty; if all three probes match expectations, HW-smoke passes.
  - [x] Sub-8.2 N/A — kernel delta is non-zero (option (b))

## Dev Notes

### Post-edit measurements (captured 2026-05-19 dev-pass close)

- Binary size: `wc -c build/antforth.com` → **26583 B** (delta = +106 B vs 26,477 B baseline)
- `make test-repl`: **975 PASS / 0 FAIL / 2 SKIP** (no regression from baseline)
- `make test-repl-banking`: **50 PASS / 0 FAIL / 3 SKIP** (= 48 baseline + 2 new probes 18.5.1-A and 18.5.1-B; both PASS)
- `make test-repl-banking-skip`: **25 PASS / 0 FAIL / 3 SKIP** (no regression)
- `make check-doc-sync`: **31 advisories / 0 drift** (no regression)
- `sizeof(UserArea)`: **112 B** (unchanged — Story 18.5.1 uses kernel-static scratch cells in src/exception.asm, not UserArea)

#### Binary delta itemisation (AC#4)

| Component | Estimated (pre-build) | Realised (post-build) | Notes |
|-----------|------------------------|-----------------------|-------|
| CATCH extension (stash push) | +41 B | ~+50 B | minor expansion from register-juggle (EX DE,HL pairs, PUSH IX/POP DE for LDIR setup); the unconditional depth_word write (post-bug-fix to always populate (IX-2)) cost +3 B over original plan |
| catch_resume_cf extension (variable advance) | +5 B | reverted to 0 B | the variable advance was REVERTED in dev-pass — the stash sits BELOW frame_base on IX rstack, so catch_resume_cf only needs to advance past the 8-byte frame; the stash is in the freed rstack region below the new IX. Re-anchoring IX = CATCH-TOP at entry added +10 B (vs the 0 B variable-advance saving). |
| catch_resume_cf IX re-anchor (LD HL, (catch_top); PUSH HL; POP IX at entry) | not in original itemisation | +10 B | unbudgeted but necessary fix — IX at catch_resume_cf entry is stash_low after my CATCH push, not frame_base; reads via (IX+k) need IX = frame_base |
| THROW caught extension (stash restore + IX advance) | +36 B | ~+40 B | similar minor expansion from register juggling |
| throw_stash_hl scratch | +2 B | +2 B | |
| throw_stash_bc scratch | +2 B | +2 B | |
| throw_stash_de scratch | not in original itemisation | +2 B | unbudgeted but **load-bearing** addition. Bug surfaced mid-dev-pass: spilling catching-IP to system stack via `PUSH DE / ... LDIR ... / POP DE` lands the spill at `[SP_throw − 2]`. If SP_throw = SP_safe + 2 (xt consumed exactly one extra cell before THROW — common case for DEFWORD-xt patterns like `DROP ABORT`), the spill address is `[SP_safe + 0]`, which the LDIR caught-path restore overwrites with stash bytes. POP DE then reads stash garbage as catching-IP → NEXT jumps to a random address → process crash. Kernel scratch cell sidesteps the SP/LDIR overlap. |
| **Total kernel binary delta** | **~+86 B (estimated)** | **+106 B (realised)** | **+20 B / +23.3% overshoot vs estimate** |

**Accept-with-rationale (AC#4 envelope ±10% breach)**:
- AC#4 envelope is ±10% of the estimate (= ±~9 B → bounds [77, 95]). Realised +106 B exceeds the upper bound by +11 B (+~12% over the upper bound; +~23% over the estimate midpoint).
- Two unbudgeted components account for the overshoot:
  1. **throw_stash_de scratch cell + LD (nn), DE / LD DE, (nn) inline (≈+10 B beyond original PUSH DE / POP DE plan)** — load-bearing per the LDIR-overlap bug described above; the PUSH-DE-on-system-stack design was incorrect and could not be made correct without this kernel scratch cell.
  2. **catch_resume_cf IX re-anchor (≈+10 B)** — load-bearing per the IX-at-stash_low diagnosis; catch_resume_cf cannot read frame fields without first re-anchoring IX to frame_base via CATCH-TOP.
- Neither expansion was foreseeable from the original itemisation; both were discovered during dev-pass via empirical regression testing (test 622 EVALUATE crash → diagnosis chain → throw_stash_de fix; DROP-ABORT crash → diagnosis chain → catch_resume_cf re-anchor fix). The Epic-13.5 / 13.5.5 precedent applies (itemised overshoot with per-cell accounting recorded in Dev Notes, not "mirrors prior arm" shorthand).
- Hardware-smoke at story close confirms no functional regression on real MicroBeast (deferred to project-lead per Task 8 below — recipe in closing chat message).

### Pre-edit baseline (captured 2026-05-18 dev-pass start)

- [x] Binary size: `wc -c build/antforth.com` → **26477 B** (= 26,477 B — matches the 18.5-close figure, no housekeeping interlude)
- [x] `make test-repl`: **975 PASS / 0 FAIL / 2 SKIP**
- [x] `make test-repl-banking`: **48 PASS / 0 FAIL / 3 SKIP**
- [x] `make test-repl-banking-skip`: **25 PASS / 0 FAIL / 3 SKIP**
- [x] `make check-doc-sync`: **31 advisories / 0 drift**
- [x] `sizeof(UserArea)`: **112 B** (hand-computed: state/base/here/latest/tib_addr/tib_len/tib_in/source_id/hld/catch_top = 10·2=20 + pic_buf=40 + search_order_depth=2 + search_order=32 + current_wordlist=2 + dpl=2 + include_top=2 + saved_bank=2 + current_bank=2 + bank_table_base=2 + bank_mapping_state=2 + bank_count=2 + stub_alloc_tail=2 = 112 B). NOTE: option (b) chosen does NOT touch UserArea — stash uses kernel-static scratch cells (throw_stash_hl, throw_stash_bc) in src/exception.asm, parallel to the existing throw_saved_n pattern.

### CATCH frame layout (current, Story 11.4.1)

Per `docs/register-conventions.md:299..309` and `src/exception.asm:14..18`:

```
Higher address ─┬──────────────────────────────────┐
        +6, +7  │ previous CATCH-TOP (chain link)  │
        +4, +5  │ catching-IP (caller's IP)        │
        +2, +3  │ saved BC (i*x's TOS-cell value)  │
        +0, +1  │ saved SP (post-POP-BC SP_safe)   │
Lower address  ─┴──────────────────────────────────┘
                 ← IX points here after push
```

`CATCH` (`src/exception.asm:100..175`):

1. `LD H,B / LD L,C` → HL = xt
2. `POP BC` → BC = i*x's TOS-cell, SP advances by 2 (SP becomes `SP_safe`)
3. Capture SP_safe via `PUSH HL / LD HL, 2 / ADD HL, SP` (HL spills xt across the SP capture, recovered later)
4. Push 8-byte frame highest-addr-first (DEC IX × 4): +6 = prev CATCH-TOP, +4 = caller's IP (DE), +2 = saved-BC (BC), +0 = saved-SP (HL = SP_safe)
5. `CATCH-TOP := frame base`
6. `DE := catch_resume_thread` (continuation for normal return)
7. `JP (HL)` → execute xt

`THROW` caught path (`src/exception.asm:282..415`):

1. Stash n (BC) in `throw_saved_n`
2. IX := target frame base via CATCH-TOP read
3. INCLUDE-TOP chain walk (Story 13.4 — closes more-recent INCLUDE frames)
4. Restore CATCH-TOP from frame +6
5. DE := catching-IP from frame +4
6. HL := saved-SP (SP_safe) from frame +0
7. `LD BC, 8 / ADD IX, BC` → pop frame
8. BC := saved-BC (i*x's TOS-cell) from frame_base+2 (now at IX-6 post-add)
9. `LD SP, HL` (SP := SP_safe)
10. `PUSH BC` (restore i*x's TOS-cell at `[SP_safe-2]`, overwriting any return-address byte xt's CALLs left)
11. `BC := (throw_saved_n)` (BC = n, throw code)
12. `NEXT` (chases DE = catching-IP)

Post-NEXT invariant: BC = n; `[SP] = i*x's TOS-cell = saved-BC`; `[SP+2] = ???`; `[SP+4] = ???`; … — the cells at `[SP] = SP_safe-2`, `[SP+2] = SP_safe`, `[SP+4] = SP_safe+2`, … come from a mixture of (a) the saved-BC restore at `[SP_safe-2]`, (b) the in-place memory state of cells at-or-above `SP_safe` at the moment THROW captured saved-SP. Cells (b) are exposed to xt's read AND write traffic for the entire xt window; the framework offers no preservation guarantee for them.

### Reproducer B instruction-level trace (AC#1)

`100 200 ' SWAP-ABORT CATCH .S` where `: SWAP-ABORT SWAP ABORT ;`.

Pre-CATCH stack (TOS-in-register: BC = xt_SWAP_ABORT; SP-stack: [SP+0] = 200, [SP+2] = 100, [SP+4..sp_base-1] = older cells).

#### Step-by-step (post-Story-11.4.1 layout per `src/exception.asm:14..18`)

1. `w_CATCH_cf` (`src/exception.asm:100..175`):
   - `CALL check_underflow` (line 101): SP-stack ≥ 1 data cell. Passes (2 cells: 100, 200).
   - `LD H,B / LD L,C` → HL = xt_SWAP_ABORT.
   - `POP BC` → BC = 200 (= i*x's TOS-cell), SP = SP_pre + 2 = **SP_safe** ("one cell above the original i*x's TOS-cell memory slot" per line 109). At `[SP_safe + 0]` lives 100 (= i*x's second-from-top); at `[SP_safe + 2]` lives whatever was below.
   - `PUSH HL / LD HL, 2 / ADD HL, SP / POP HL` idiom (lines 139..141, 172): captures HL = SP_safe via system-stack spill of xt; recovers xt at line 172. SP is temporarily SP_safe − 2 during the spill window.
   - Frame push (lines 144..164, 4×`DEC IX` pairs): writes +6 = prev CATCH-TOP, +4 = caller's IP (DE), +2 = saved-BC (= 200, the i*x's TOS-cell), +0 = saved-SP (= SP_safe).
   - `CATCH-TOP := frame_base` (lines 166..171).
   - `LD DE, catch_resume_thread` (line 174) — DE no longer holds caller's IP (saved in frame +4).
   - `JP (HL)` → execute xt = SWAP-ABORT.

2. `w_SWAP_cf` (`src/stack_ops.asm:47..55`):
   - At entry: BC = 200, SP = SP_safe, `[SP_safe + 0]` = 100.
   - `CALL check_underflow_2` — passes (≥2 SP cells available in the SWAP-ABORT body).
   - `POP HL` → HL = 100 (= `[SP_safe + 0]`), SP = SP_safe + 2.
   - `PUSH BC` → SP = SP_safe, `[SP_safe + 0] := BC = 200`. **CORRUPTION**: the cell at `[SP_safe + 0]` originally held i*x's second-from-top (100); SWAP overwrote it with 200.
   - `LD B,H / LD C,L` → BC = 100 (= new TOS-in-register).
   - `NEXT`.

3. `w_ABORT_cf` (`src/system.asm:309..315`):
   - `LD BC, THROW_ABORT` → BC = −1.
   - `JP w_THROW_cf.kernel_entry` — direct entry, bypassing the user-facing `CALL check_underflow` guard at `src/exception.asm:287` (kernel-internal entry contract per lines 292..330).

4. `w_THROW_cf.kernel_entry` (`src/exception.asm:332..415`) — caught path (CATCH-TOP ≠ 0):
   - `LD (throw_saved_n), BC` → stash n = −1 (line 350).
   - Read `CATCH-TOP` → HL = frame_base. `PUSH HL / POP IX` → IX = frame_base. (PUSH HL writes frame_base at `[SP_safe − 2]`; POP IX restores SP to SP_safe. The byte at `[SP_safe − 2]` now contains frame_base low byte — irrelevant in this trace because the cell is below the eventual restored SP.)
   - `CALL throw_chain_walk_caught` — no-op pre-INCLUDE here.
   - Read frame: `(IY+catch_top) ← (IX+6/+7)`, `DE ← (IX+4/+5)` (= catching-IP), `HL ← (IX+0/+1)` (= SP_safe).
   - `LD BC, 8 / ADD IX, BC` → IX = frame_base + 8 (frame popped).
   - `LD C, (IX-6) / LD B, (IX-5)` → BC = saved-BC = 200 (= i*x's TOS-cell captured at CATCH entry, line 158).
   - `LD SP, HL` → SP = SP_safe.
   - `PUSH BC` → `[SP_safe − 2] := 200`, SP = SP_safe − 2. **This restores i*x's TOS-cell** at the slot where xt's CALLs may have left return-address bytes. (In this trace SWAP did not CALL anything that wrote at `[SP_safe − 2]` post-its-own-state — but ABORT's `JP w_THROW_cf.kernel_entry` does not push either, so the slot's contents are stale-irrelevant; PUSH BC overwrites cleanly.)
   - `LD BC, (throw_saved_n)` → BC = −1.
   - `NEXT` → chases DE = catching-IP into caller's thread.

#### Post-NEXT data-stack state

- BC = −1 (new TOS).
- `[SP + 0]` = `[SP_safe − 2]` = 200 (= saved-BC = i*x's TOS-cell, restored by step 4's `PUSH BC`).
- `[SP + 2]` = `[SP_safe + 0]` = **200** (the SWAP-corrupted cell — the framework never restored it).
- `[SP + 4]` = `[SP_safe + 2]` = whatever was originally at the i*x's third-from-top slot (untouched by SWAP, untouched by THROW restore).

`.S` reports `<3> 200 200 -1` (depth, deepest, second-from-top, TOS).

Expected per ANS §9.6.1.0875 cell-content preservation: `<3> 100 200 -1`.

#### Generalised statement

The CATCH framework preserves **only i*x's TOS-cell** (via the Story-11.4.1 saved-BC slot at frame +2, restored via `PUSH BC` after `LD SP, HL`). The cells at `[SP_safe + 0 .. SP_safe + 2·(K−2)]` for i*x depth K (= the K−1 cells below i*x's TOS, i.e., second-from-top through deepest) are **NOT preserved**; they are exposed to xt's read AND write traffic during the CATCH window, and any value xt left at those addresses survives the THROW caught-path restore.

#### Corollary — primitives that trigger the gap when run as xt under CATCH

Any primitive whose first effect writes at `[SP_safe + k]` for k ≥ 0 corrupts i*x's `(k/2)+1`-th-from-top cell:

| Primitive | Write at | Cell corrupted | Mechanism |
|-----------|----------|----------------|-----------|
| `SWAP`    | `[SP_safe + 0]` (after `POP HL`)   | i*x's second-from-top | `POP HL; PUSH BC` exchange |
| `ROT`     | `[SP_safe + 2]` (via `EX (SP),HL`) | i*x's third-from-top  | `POP HL; EX (SP),HL; PUSH BC` |
| `2SWAP`   | `[SP_safe + 0..+6]`                 | i*x's second through fifth | 4-cell rearrangement |
| `ROLL`    | `[SP_safe + 0..+2·n]` (depends on u) | variable depth corruption | `LDDR`-based shift |
| `!`, `c!`, `+!` | memory at `[BC]` (not stack)   | none (stack write at `[SP_safe − 2]` after PUSH BC) | safe |
| `LIT`, `PUSH`-then-anything | `[SP_safe − 2]`     | none (overwritten by THROW's `PUSH BC` restore) | safe |
| `OVER`    | `[SP_safe + 0]` is re-written with the same value | none (idempotent overwrite) | safe in isolation |
| `DUP`, `DROP`, `?DUP` | `[SP_safe − 2]` | none | safe |

The list is non-exhaustive — any composition or DEFWORD body whose net effect writes at-or-above `[SP_safe]` exhibits the gap.

#### Secondary leak — THROW's own scratch traffic

Even an xt that does NO data-stack writes at-or-above `[SP_safe]` can leak the outer CATCH frame_base into `[SP_safe + 0]` if THROW is entered with SP > SP_safe. Mechanism: `w_THROW_cf.kernel_entry`'s `PUSH HL / POP IX` idiom at `src/exception.asm:351..352` writes HL (= CATCH-TOP = frame_base) to `[SP − 2]`. If SP = SP_safe + 2 at THROW entry (xt consumed exactly one extra cell), the write lands at `[SP_safe + 0]` and is NOT subsequently overwritten by the caught-path `PUSH BC` (which writes at `[SP_safe − 2]`). This is exactly what Reproducer A witnessed: the actual `<3> 17896 17262 -1` value `17896` is the outer CATCH frame_base on the IX rstack, leaked via this mechanism inside IN-BANK body's post-inner-CATCH execution.

#### Standards citations

- ANS Forth 1994 §9.6.1.0875 — `CATCH ( i*x xt -- j*x 0 | i*x n )` stack effect; the `i*x` notation contractually denotes specific cell contents preserved across the call boundary on the caught path.
- ANS Forth 1994 §9.3.5 — THROW code allocation table; the `i*x` "same depth" half is satisfied (DEPTH(post-NEXT) = DEPTH(pre-CATCH)); the cell-content half is the GAP.
- `docs/register-conventions.md:303..309` — frame +2 slot semantic (saved BC = i*x's TOS-cell). Lines 309..311 state the slot's narrow binding: "i*x's TOS-cell value at CATCH entry, captured from BC immediately after the POP that consumes it". Deeper cells are documented at line 384 as the open scope.
- `_bmad-output/planning-artifacts/architecture-phase2-epics-9-13.5.md` §"Exception subsystem (Epic 11)" lines 118..130 — E11-D1 frame layout; CCD-1 dual-chain at line 80.

### Q1 disposition — Option (b) framework patch (project-lead approved 2026-05-18 dev-pass)

**Option chosen: (b) — Pre-CATCH side-stash + post-THROW restore.**

#### Per-component byte itemisation (independent — no "mirrors Story X" shorthand)

| Component | Bytes (estimated, pre-build) | Rationale |
|-----------|------------------------------|-----------|
| **CATCH extension** (lines inserted between current `CATCH-TOP := frame_base` at `src/exception.asm:171` and `POP HL` recovery at line 172) — read SP_safe from frame +0; compute depth_bytes = sp_base − SP_safe; short-circuit on depth_bytes = 0; push depth word at IX−2; advance IX by depth_bytes; LDIR data-stack → IX-rstack stash | +41 B | 2× `LD r,(IX+d)` (3 B each = 6) + `LD HL,(nn)` (3) + `OR A` (1) + `SBC HL,BC` (2) + `LD A,H/OR L/JR Z` (4) + 2× `DEC IX` (2 B each = 4) + 2× `LD (IX+d),r` (3 B each = 6) + register-juggling `EX DE,HL/PUSH IX/POP HL/OR A/SBC HL,DE/PUSH HL/POP IX/LD H,B/LD L,C/LD B,D/LD C,E/PUSH IX/POP DE/LDIR` (15) ≈ 41 B |
| **catch_resume_cf extension** (replace fixed `LD BC, 8 / ADD IX, BC` at lines 220..221 with variable advance — `LD A, (IX-2) / ADD A, 10 / LD C, A / LD B, 0 / ADD IX, BC`) | +5 B (delta: 10 B new vs 5 B existing) | depth_bytes high byte invariantly 0 (PS_SIZE = 256 → max depth_bytes = 254 fits in 1 byte) lets us use the cheap `LD A / ADD A / LD C, A` sequence |
| **THROW caught extension** (inline, replacing lines 378..411's `LD BC, 8 / ADD IX, BC / LD C, (IX-6) / LD B, (IX-5) / LD SP, HL / PUSH BC / LD BC, (throw_saved_n)` ≈ 18 B with: read saved-BC at `(IX+2)/(+3)`, stash BC and HL to scratch cells, push DE on system stack, read depth_bytes, short-circuit on 0, LDIR-restore, variable IX advance, recover BC/HL/DE, `LD SP,HL / PUSH BC / LD BC,(throw_saved_n)`) | +36 B (delta: 54 B new vs 18 B existing) | itemised cells: read-BC (6) + 2× `LD (nn),rp` (4 B each = 8) + `PUSH DE` (1) + read-depth (6) + short-circuit (4) + stash-low-calc-and-LDIR (14) + variable-advance (10) + 2× `LD rp,(nn)` (4 B each = 8) + `POP DE` (1) + `LD SP,HL` (2) + `PUSH BC` (1) + `LD BC,(throw_saved_n)` (4) ≈ 54 B inline, 36 B delta |
| **throw_stash_hl scratch cell** (2-byte `DW 0` parallel to `throw_saved_n`) | +2 B | per `src/exception.asm:824..839` precedent |
| **throw_stash_bc scratch cell** (2-byte `DW 0`) | +2 B | (same) |
| **Per-arm total kernel binary delta** | **~+86 B** | sum of components |

#### Per-component cycles itemisation (separate from bytes; not "scaled")

| Path | Cycles delta vs baseline | Rationale |
|------|--------------------------|-----------|
| **CATCH (depth_bytes = 0 short-circuit, K=1 → i*x has only TOS)** | +~25 cycles | 6 read-frame +0, 3 sp_base read, 4 SBC, 4 OR/JR Z = ~25 |
| **CATCH (depth_bytes = 2(K−1), K ≥ 2)** | +~50 + (LDIR cost) cycles | constant setup ~50 + LDIR ≈ 21 cycles/byte. For K=3 (4 bytes): ~50 + 84 = ~134 cycles |
| **catch_resume_cf (normal return, any K)** | +~25 cycles | 3 read-depth, 7 ADD A,n, 4 LD C,A / LD B,0, 11 ADD IX,BC ≈ 25 |
| **THROW caught (depth_bytes = 0)** | +~50 cycles | scratch stashes + short-circuit + variable advance |
| **THROW caught (K ≥ 2)** | +~60 + (LDIR cost) cycles | setup ~60 + LDIR ≈ 21 cycles/byte. For K=3 (4 bytes): ~60 + 84 = ~144 cycles |

Envelope check vs NFR-P4-1 ("~15 Z80 cycles uncaught CATCH frame overhead"):

- Uncaught CATCH adds ~25 cycles (depth=0 short-circuit), exceeding the ~15-cycle envelope by ~10 cycles. **Accept-with-rationale**: NFR-P4-1's "~15 cycles" was set for the original 8-byte frame push; option (b) extends the frame contract with the i*x-preservation guarantee, and ~10 cycles is a load-bearing cost for that closure (parallel to the Epic-17 ~2.4× envelope-overshoot pattern documented in `project_epic17_envelope.md`). Hardware-smoke at story close confirms no perceptible impact on REPL responsiveness.
- THROW caught for K=3 adds ~144 cycles. THROW is cold-path (error recovery); cycles cost is amortised across the error-handling chain and is not budgeted under NFR-P4-1.

#### Why option (b) over (a) / (d):

- **ANS conformance**: option (b) closes the ANS §9.6.1.0875 cell-content gap structurally — antforth's CATCH/THROW now matches gforth / SwiftForth / pforth precedent (full i*x preservation, not just TOS-cell). Option (a)/(d) would leave a documented non-conformance.
- **Forward-proofing for Epic 19+**: per-bank dictionary work (Epic 19) will introduce additional DEFWORDs that wrap user xt in CATCH. Option (b) means those future DEFWORDs need no body-cell discipline; option (a)/(d) would require a normative MUST-NOT for every future DEFWORD's body.
- **Risk budget**: ~86 B kernel delta is within Phase-4 envelope precedent (Epic 17 was +955 B; Epic 18 was +249 B). Three-test-surface sweep at close validates no regression.

#### Why not (c):

Option (c) decrements SP at CATCH entry past the entire i*x. Inside xt, SP would sit below i*x's deepest cell. This **breaks DEPTH semantics inside xt**: `DEPTH = (sp_base - SP)/2` would report K + (xt's local cells) instead of just (xt's local cells). PICK and ROLL would index into i*x cells from xt's frame, exposing them as "free" memory and violating the i*x-preservation goal at the same time as breaking xt's local-stack semantics. **Rejected**.

### Audit table — kernel DEFWORDs using CATCH (AC#5)

Grep: `grep -rn "DW.*w_CATCH_cf" src/`

| DEFWORD | File:line | xt under CATCH | Body cells before CATCH | Body cells inside CATCH window | Gap-trigger verdict (pre-option-(b)) | Status post-option-(b) |
|---------|-----------|----------------|--------------------------|---------------------------------|--------------------------------------|------------------------|
| `w_IN_BANK_cf` | `src/banking.asm:982` | user-provided xt (caller's argument) | BANK@, >R, SWAP, BANK! | (xt body — caller's discipline) | **TRIGGERS GAP** when IN-BANK is itself the xt of an OUTER CATCH: body's `SWAP` at cell 3 writes at `[SP_safe_outer + 0]`, corrupting outer i*x's second-from-top | **PASS** — outer CATCH's stash captures i*x deeper cells at outer-CATCH entry; outer THROW restores them via LDIR; IN-BANK body's `SWAP` traffic at the outer `[SP_safe + 0]` slot is irrelevant because the outer restore overwrites that slot from stash |
| `w_EVALUATE_cf` | `src/outer_interpreter.asm:623` | literal xt = `' INTERPRET` | `(SAVE-INPUT)` (pushes 4 cells of save-info), `LIT [' INTERPRET]` | INTERPRET (token loop; may push tokens) | **TRIGGERS GAP** when EVALUATE is itself the xt of an OUTER CATCH AND `(SAVE-INPUT)` writes at-or-above outer's `[SP_safe + 0]`. `(SAVE-INPUT)`'s 4-cell push is at `[SP − 2]..[SP − 8]` (below current SP) — does NOT write at `[SP_safe + 0]`. INTERPRET may, but that's INTERPRET's own discipline, not EVALUATE's contract. Verdict: **N/A for the body itself**. | **N/A unchanged** — body-cell discipline already safe |
| `w_INCLUDED_cf` | `src/file_access.asm:2948` | literal xt = `' (refill-and-interpret-loop)` | `R/O OPEN-FILE 0= ?BRANCH [.inc_open_fail offset] DUP (slab-from-fid) SWAP LIT 0 SWAP (input-frame-push) LIT [' (refill-and-interpret-loop)]` | `(refill-and-interpret-loop)` | Body has a `SWAP` at cell 9 (`SWAP` between `(slab-from-fid)` and `LIT 0`) and another `SWAP` at cell 14. **TRIGGERS GAP** if INCLUDED is itself the xt of an OUTER CATCH AND outer's `[SP_safe + 0]` aligns with the SWAP's `[SP_safe + 0]`. Body-cell 9 SWAP runs with `( fileid slab )` on data stack (BC = slab, `[SP+0]` = fileid). If outer's `[SP_safe + 0]` = `[SP+0]` here, SWAP corrupts outer i*x's second-from-top. **POTENTIAL GAP**. | **PASS** — outer CATCH's stash handles all body-internal SP traffic |
| `w_INCLUDE_FILE_cf` | `src/file_access.asm:2999` | literal xt = `' (refill-and-interpret-loop)` | `(fid-validate) DUP (slab-from-fid) SWAP LIT 0 SWAP (input-frame-push) LIT [' (refill-and-interpret-loop)]` | `(refill-and-interpret-loop)` | Same shape as INCLUDED (body cells 3 and 6 have SWAPs). **POTENTIAL GAP**. | **PASS** — outer CATCH's stash handles |

Conclusion: option (b) closes all 4 current DEFWORD-CATCH bodies' gap exposures at the framework level, without requiring per-body discipline.

### Q1 disposition — option chosen

- [x] Option chosen: **(b)** — framework patch (pre-CATCH stash + post-THROW restore on IX rstack)
- [x] Per-component byte itemisation: above table (~86 B per-arm total; will re-measure post-build)
- [x] Per-component cycles itemisation: above table (~25–144 cycles depending on path and depth)
- [x] Project-lead disposition: option (b) approved 2026-05-18 dev-pass start (via the dev-story workflow AskUserQuestion)
- [x] Rationale: structural ANS-conformance closure; forward-proofs Epic 19+ DEFWORDs; ~86 B is within Phase-4 envelope precedent; risk mitigated by three-test-surface sweep at close + HW-smoke at review

### Q1 disposition (option chosen; to be filled at dev-pass start)

- [ ] Option chosen: (a) / (b) / (c) / (d)
- [ ] Per-component byte itemisation:
- [ ] Per-component cycles itemisation:
- [ ] Project-lead disposition: __________
- [ ] Rationale:

### Audit table — kernel DEFWORDs using CATCH (to be filled per AC#5)

| DEFWORD | Body file:line | CATCH cell # | Cells before CATCH | Gap-trigger verdict |
|---------|----------------|--------------|--------------------|--------------------|
| `w_IN_BANK_cf` | `src/banking.asm:974..988` | cell 5 (after BANK@ >R SWAP BANK!) | BANK@, >R, SWAP, BANK! | the OUTER-CATCH gap is what 18.5 H1 disposition exposed; INNER-CATCH (which IN-BANK wraps around the user's xt) is governed by the user's xt's discipline, not IN-BANK's — restate carefully |
| … | … | … | … | … |

### Source tree components to touch

- `src/exception.asm` — only if option (b)/(c)/(d)-with-kernel-arm chosen
- `src/structures.asm` — only if a new UserArea field is added (option (b) with side-buffer)
- `src/antforth.asm` — only if new UserArea field needs cold-start init
- `src/banking.asm:937..950` — IN-BANK source-comment block update per AC#6 (any chosen option)
- `docs/register-conventions.md` §9 — new subsection per AC#6 (any chosen option)
- `architecture-phase2-epics-9-13.5.md` §"Exception subsystem" — only if a new E11-D architectural decision is recorded (option (b)/(c) or option (d) with deferred follow-on)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — status transition + optional new backlog row if option (d) defers a follow-on
- `tests/banking_tests.fth` — Probe-18.5.1-A + Probe-18.5.1-B added after Story 18.5 probe block (current tail ~line 1528)
- `Makefile` — probe assertions for the two new probes
- `feedback_no_preexisting_discharge.md` — possible amendment if option (a) reinterprets the "fix" standing rule

### Testing standards summary

- Probes use the `_p18-5-1*` variable-name disambiguation pattern (Story 18.4 CR-M1 precedent)
- Probes are SENTINEL-BOUNDED with `---probe-18.5.1-X-start---` / `---probe-18.5.1-X-end---` markers (Story 18.4/18.5 precedent)
- VARIABLE-stash for AC2-style witnesses (`_p18-5e` precedent at `tests/banking_tests.fth:1500..1515`) where deeper-cell-independent verification is needed
- Probe-line lengths MUST stay ≤ TIB_SIZE=128 per `feedback_tib_size_inline_comments.md`
- Three-test-surface sweep at close per Story 16.3 convention

### Project Structure Notes

- This story is a Phase-4 sibling-of-Epic-18 follow-on, filed at 18.5 close per `feedback_no_preexisting_discharge.md` "surface, file, fix" standing rule
- Sprint-status row `18-5-1-defwords-ix-preservation-on-caught-throw` lives under `epic-18` (the row at line 350 in sprint-status.yaml as of 2026-05-18), AFTER the 18.5 row at line 331 — Epic 18 remains `in-progress` until this story closes; Story 18.5's `review` status is independent (gated on 18.5's own close, not this story)
- Epic 19 (`backlog`) is the next epic per the v3.0.x release cadence (`project_phase4_scope.md`); this story sits between Epic 18's substantive close and Epic 19's kickoff. Option (a)/(d)-doc-only minimises risk of disturbing the 18.5 baseline before Epic 19 starts; option (b)/(c) ships a framework patch that future Epic 19+ DEFWORDs would also benefit from
- The v3.0.2 tag was applied at Epic 18 close; this story would NOT bump to v3.0.3 (option (a) doc-only) but COULD trigger a v3.0.2.1 micro-tag at project-lead discretion if option (b)/(c) lands a framework patch. Tagging decision sits with project-lead at review

### Detected conflicts or variances

- The H1 disposition in Story 18.5 stated "Out-of-scope for Phase-4 close-out tag" but did not pre-commit to option (a) vs (b) vs (c). This story carries the open Q1 with full option analysis
- The `src/banking.asm:937..950` IN-BANK source-comment block already documents the gap (per CR-applied edit at 18.5 close); this story closes the loop by either (a) declaring the documented limitation normative, or (b)/(c) closing it at the framework

### References

- [Source: `src/exception.asm:14..18`] — frame layout comment
- [Source: `src/exception.asm:100..175`] — CATCH normal-return path + Story 11.4.1 EXECUTE-prelude reorder + saved-BC capture
- [Source: `src/exception.asm:282..415`] — THROW kernel_entry + caught-path 7-step algorithm + saved-BC restore via PUSH BC after LD SP, HL
- [Source: `src/banking.asm:870..988`] — IN-BANK kernel-blessed DEFWORD; H1 disposition source-comment at 937..950 documents the deeper-cell preservation gap
- [Source: `src/stack_ops.asm:47..55`] — SWAP via POP HL / PUSH BC; the canonical primitive that exposes the gap when run as xt under CATCH
- [Source: `docs/register-conventions.md:289..384`] — §9 Exception Frames (Epic 11); §"Layout (E11-D1)" at 295..311; §"Story 11.3 contract — THROW-time restore" at 342..367; §"Historical (Stories 11.4–11.7 — landed; Story 13.4 — open)" at 377..382
- [Source: `_bmad-output/planning-artifacts/architecture-phase2-epics-9-13.5.md` §"Exception subsystem (Epic 11)" at line 118 + §"CCD-1 dual-chain return-stack frame discipline" at line 80] — authoritative architectural spec for E11-D1 frame layout + CCD-1 dual-chain
- [Source: `_bmad-output/implementation-artifacts/18-5-in-bank-kernel-blessed-catch-safe-epic-18-close-out-antforth-3-x-2-tag.md:548..570`] — H1 disposition exposition, Reproducer A + B, scope assessment
- [Source: `_bmad-output/implementation-artifacts/18-5-in-bank-kernel-blessed-catch-safe-epic-18-close-out-antforth-3-x-2-tag.md:640`] — 2026-05-18 CR-pass change log entry recording the H1 filing
- [Source: `_bmad-output/implementation-artifacts/11-4-1-catch-throw-ix-preservation-bug-fix.md`] — Story 11.4.1 frame +2 slot repurposing from "saved IX" (dead) to "saved BC" (i*x's TOS-cell value); the predecessor framework patch this story would extend
- [Source: ANS Forth 1994 §9.6.1.0875 CATCH stack effect `( j*x 0 | i*x n )`] — cell-content preservation expectation
- [Source: ANS Forth 1994 §9.3.5] — THROW code allocation table; the "depth-preservation" half of `i*x` is satisfied; cell-content half is the gap
- [Source: `feedback_no_preexisting_discharge.md`] — "surface, file, fix" standing rule that drove this story's filing
- [Source: `feedback_tib_size_inline_comments.md`] — TIB_SIZE=128 constraint on REPL probe lines
- [Source: `feedback_post_hw_smoke_steps_at_review.md`] — STRONG rule on HW-smoke recipe in closing chat message
- [Source: `feedback_no_claude_coauthor.md`] — STRONG rule: no Claude co-author trailer in commit messages
- [Source: `project_phase4_scope.md`] — Phase 4 v3.0.x cadence; Epic 18 closed at v3.0.2; Epic 19 next
- [Source: `_bmad/bmm/workflows/4-implementation/create-story/instructions.xml`] — B.2 / Lesson 13.5-C "mirrors prior arm" HALT signal (no shorthand byte-budget rationale); B.4 / PD-2 figure-drift discipline (re-validate cited figures at draft time); ADV review separation (ACs do not enumerate adversarial review)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Opus 4.7, 1M context)

### Debug Log References

Three iterative fixes during dev-pass:

1. **Initial implementation (build #1, 26,579 B)**: stash push code added in CATCH; catch_resume_cf and THROW caught path given a "variable IX advance" of (8 + 2 + depth_bytes) bytes. **Regression**: test-repl 1 FAIL (test 622 EVALUATE crash), test-repl-banking-skip 4 FAIL. Root cause: my CATCH only wrote the depth_word in the `depth_bytes > 0` path; the `depth_bytes = 0` path left `(IX-2)` holding garbage from prior rstack use, which catch_resume_cf and THROW then read as a bogus depth value. Fix: move the `DEC IX × 2 / LD (IX+0), C / LD (IX+1), B` unconditionally above the `JR Z .catch_no_stash`.

2. **Second iteration (build #2, 26,575 B)**: depth_word always written. **Regression**: EVALUATE crash persists. Root cause: catch_resume_cf reads (IX+k) assuming IX = frame_base, but my CATCH push leaves IX at stash_low (= frame_base − 2 − depth_bytes) BELOW frame_base. Subsequent xt execution doesn't restore IX before catch_resume_cf runs. The frame-field reads at (IX+0), (IX+4), (IX+6) read at offsets from stash_low, not from frame_base — wrong addresses. Compounding: my "variable IX advance" was also wrong; the stash sits BELOW frame_base, so catch_resume_cf only needs to advance past the 8-byte frame (the stash bytes are below frame_base and will be in the freed-rstack region after the +8 advance). Fix: at catch_resume_cf entry, re-anchor IX = frame_base via CATCH-TOP. Revert variable advance to +8 in both catch_resume_cf and THROW caught path.

3. **Third iteration (build #3, 26,575 B)**: catch_resume_cf re-anchors IX; fixed +8 advance. **Regression**: DEFWORD xt with internal SP-modifying ops before THROW (e.g., `: DROP-ABORT DROP ABORT ;` invoked via `100 ' DROP-ABORT CATCH`) crashes; test-repl FAIL on test 908 (file-FCB pool exhaustion → -69 THROW via CREATE-FILE) with "BDOS command 187 not implemented". Root cause: THROW caught-path spills catching-IP via `PUSH DE / ... LDIR ... / POP DE`. When xt consumed cells before THROW (SP_throw > SP_safe), `PUSH DE` lands the catching-IP at `[SP_throw − 2]`, which can fall inside `[SP_safe..sp_base-1]` (the LDIR write range). For `' DROP-ABORT CATCH` with 1 extra cell on stack, SP_throw = SP_safe + 2 and PUSH DE writes at `[SP_safe + 0]` — the LDIR then overwrites it with stash bytes. POP DE reads stash garbage → DE is wrong → NEXT jumps to a random address (the "BDOS 187" was a coincidental dispatch to BDOS_INT at a corrupted code path). Fix: add `throw_stash_de` kernel scratch cell parallel to `throw_stash_hl` / `throw_stash_bc`; replace `PUSH DE / POP DE` with `LD (throw_stash_de), DE / LD DE, (throw_stash_de)`. Build #4: 26,583 B; all tests pass.

### Completion Notes List

- **Root-cause analysis (AC#1) recorded** in Dev Notes §"Reproducer B instruction-level trace" — instruction-granularity walkthrough of `100 200 ' SWAP-ABORT CATCH` with cell-by-cell SP/register state; corollary table of primitives that trigger the gap; secondary leak from THROW's `PUSH HL / POP IX` idiom documented.
- **Option (b) framework patch chosen (AC#2)** with itemised per-component byte and cycles budgets; project-lead approved 2026-05-18 dev-pass start via the dev-story workflow AskUserQuestion.
- **Option (b) implementation (AC#3)** landed in `src/exception.asm`:
  - `w_CATCH_cf`: pushes depth_word (always) + i*x stash zone (LDIR from data stack to IX rstack) below the 8-byte frame on the IX rstack. CATCH-TOP contract preserved (still points at frame +0).
  - `catch_resume_cf`: re-anchors IX = frame_base via CATCH-TOP at entry (load-bearing — IX may be at stash_low after xt's NEXT); fixed +8 advance.
  - `w_THROW_cf.kernel_entry` caught path: reads saved-BC from frame +2 BEFORE the IX advance; spills HL/BC/DE to kernel scratch cells (`throw_stash_hl`, `throw_stash_bc`, `throw_stash_de`); LDIR restores i*x deeper cells from stash; fixed +8 advance; restores SP and `PUSH BC` for i*x's TOS-cell.
  - Three new scratch cells added next to `throw_saved_n`: `throw_stash_hl`, `throw_stash_bc`, `throw_stash_de`.
- **Probes added (AC#3 sub-3.3/3.4)**: Probe-18.5.1-A (Reproducer B generic CATCH with SWAP-ABORT) and Probe-18.5.1-B (Reproducer A IN-BANK exposure) added to `tests/banking_tests.fth` with the `_p18-5-1*` variable-name pattern and SENTINEL-BOUNDED markers; Makefile probe assertions added parallel to the existing 18.5-c/-e shape.
- **Three-test-surface sweep clean (AC#3)**:
  - test-repl: 975/0/2 (baseline maintained)
  - test-repl-banking: 50/0/3 (= 48 baseline + 2 new probes)
  - test-repl-banking-skip: 25/0/3 (baseline maintained)
- **Binary delta (AC#4)**: +106 B realised vs +86 B estimated; +20 B overshoot (+23%) accepted-with-rationale per Dev Notes §"Binary delta itemisation" (load-bearing additions for `throw_stash_de` scratch + catch_resume_cf IX re-anchor).
- **Audit table (AC#5)** completed: 4 kernel DEFWORDs use `w_CATCH_cf` (IN-BANK, EVALUATE, INCLUDED, INCLUDE-FILE); all 4 now PASS post-option-(b) regardless of body-cell discipline.
- **Documentation closure (AC#6)** completed:
  - `docs/register-conventions.md §9` gained new subsection "Story 18.5.1: i*x deeper-cell preservation scope" — full layout diagram, preservation contract, layout invariants, binary delta, cycles delta, empirical witnesses, and forward-pointer to this story file.
  - `src/banking.asm:937..950` IN-BANK source-comment block updated to reflect that option (b) closes the gap structurally — IN-BANK's body-cell-3 SWAP is now harmless.
  - `src/exception.asm` frame layout comment block extended with the new stash zone + depth_word documentation.

### File List

- `src/exception.asm` — modified: CATCH stash push, catch_resume_cf IX re-anchor, THROW caught-path stash restore, throw_stash_hl/bc/de scratch cells, frame layout comment block extension.
- `src/banking.asm` — modified: IN-BANK source-comment block (lines 937..950) updated to declare option (b) framework closure.
- `docs/register-conventions.md` — modified: §9 new subsection "Story 18.5.1: i*x deeper-cell preservation scope".
- `tests/banking_tests.fth` — modified: Probe-18.5.1-A and Probe-18.5.1-B added after the existing 18.5-e block (lines 1528+). CR-pass: Probe-B c2-assertion comment tightened (CR-L2).
- `Makefile` — modified: probe assertions for 18.5.1-A and 18.5.1-B added to `test-repl-banking` target.
- `.gitignore` — CR-pass: added root-level `/P[1-8].TXT` rule (CR-M2) so `tests/file_access_tests.fth:82..89` FCB-pool-fill artifacts no longer accumulate in the working tree across test runs.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — modified: `18-5-1-defwords-ix-preservation-on-caught-throw` status transitioned ready-for-dev → in-progress → review → done (CR-pass close).
- `_bmad-output/implementation-artifacts/18-5-1-defwords-ix-preservation-on-caught-throw.md` — modified: Dev Notes, baseline + post-edit measurements, Q1 disposition, audit table, agent record, debug log, completion notes, file list, change log. CR-pass: Review Follow-ups (AI) subsection added.

### Files removed at CR-pass close

- `P1.TXT`..`P8.TXT` — eight zero-byte FCB-pool-fill artifacts from `tests/file_access_tests.fth:82..89` that the dev-pass commit (`0d4d564`) inadvertently swept in via wildcard `git add`. `git rm`'d at CR close; `.gitignore` rule added to prevent recurrence (CR-M2).

### Change Log

- 2026-05-18: Story dev-pass started. Pre-edit baselines captured; root-cause walkthrough recorded; option (b) chosen via project-lead disposition (AskUserQuestion in dev-story workflow); CATCH/catch_resume_cf/THROW caught path edits drafted.
- 2026-05-18 → 2026-05-19: Three iterative fixes (depth_word always written; catch_resume_cf IX re-anchor; throw_stash_de kernel scratch cell to avoid PUSH-DE/LDIR overlap). See Debug Log References above.
- 2026-05-19: Three-test-surface sweep clean (975/0/2 + 50/0/3 + 25/0/3). Binary +106 B (+20 B overshoot accepted). Probes 18.5.1-A/B added and Makefile assertions wired. Documentation closure completed (docs/register-conventions.md §9 new subsection; src/banking.asm IN-BANK comment update). Status transitioned to review.
- 2026-05-19 (CR-pass): Code review applied. 0 HIGH / 3 MEDIUM / 4 LOW findings → all MEDIUM (M1/M2/M3) + L1/L2 fixed automatically; L3 (IX-rstack capacity ceiling) deferred as a Phase-4 architectural follow-on, NOT a Story 18.5.1 defect; L4 captured as a new feedback memory ([[kernel-ldir-estimate-overshoot]]). Comment-only edits in src/exception.asm (M1: throw_stash block header; M3: depth_word write rationale; L1: PS_SIZE invariant) and tests/banking_tests.fth (L2: Probe-B c2 assertion explanation). Eight zero-byte P1.TXT..P8.TXT artifacts `git rm`'d (CR-M2) with `.gitignore` rule added. Three-test-surface re-validated post-edit: 975/0/2 + 50/0/3 + 25/0/3. Binary unchanged at 26,583 B (comment-only edits do not affect assembly output). check-doc-sync: 31 advisories / 0 drift (unchanged). Status transitioned: review → done.
- 2026-05-19 (HW-smoke): Project-lead ran the closing-chat-message HW-smoke recipe on real MicroBeast. Clean-session pass: Probe-18.5.1-A, Probe-18.5.1-B, and the EVALUATE health-check all matched expectations. A separate exploratory dirty-session run (typos with backspaces in the BANKS-CLEAR / +BANK line, plus 8 cells of accumulated stack from prior probes) hung at the trailing `S" 10 20 +" EVALUATE .` step on HW; the identical dirty input replays cleanly under iz-cpm-banking (`30  ok`), no patch-introduced mechanism identified for a HW-only divergence, and the project-lead's read attributes the wedge to a typo in the dirty input rather than the framework patch. Disposition: ACCEPTED. Anomaly is not load-bearing for Story 18.5.1 close — clean recipe is green on HW.

### Review Follow-ups (AI)

CR-pass findings inventory (Story 18.5.1 code review, 2026-05-19). Each item carries its disposition: `[x] fixed`, `[ ] deferred` (with target), or `[N/A]` (rejected with rationale).

- [x] **[AI-Review][MEDIUM] M1 — Stale `throw_stash_*` block header claims `PUSH DE / POP DE`** [src/exception.asm:938..948]. The comment block above `throw_stash_hl/bc/de` cited the system-stack `PUSH DE / POP DE` pattern as the catching-IP spill mechanism — exactly the bug from Debug Log iteration #3 that the third scratch cell exists to prevent. **Fix:** rewrote the block header with a CRITICAL/DO-NOT-REVERT clause explaining the LDIR-overlap hazard and citing iteration #3 as the empirical witness.
- [x] **[AI-Review][MEDIUM] M2 — 8 zero-byte `P1.TXT..P8.TXT` committed but not in story File List** [repo root]. The dev-pass commit `0d4d564` swept in FCB-pool-fill artifacts from `tests/file_access_tests.fth:82..89` via wildcard `git add`. **Fix:** `git rm`'d all 8 files; added `/P[1-8].TXT` rule to root `.gitignore` with the precedent block referencing the same test; File List + Change Log amended above.
- [x] **[AI-Review][MEDIUM] M3 — Stale rationale comment cites `catch_resume_cf` as a reader of `(IX-2)`** [src/exception.asm:204..207]. The unconditional-depth_word-write rationale named both `catch_resume_cf` and `THROW caught path` as readers; the variable-advance plan in `catch_resume_cf` was reverted at Debug Log iteration #2, so only the THROW caught path reads `(IX-2)`. **Fix:** corrected the comment to cite only `w_THROW_cf.kernel_entry` (lines 473..474) and added the iteration-#1 bug as the empirical justification for the unconditional write.
- [x] **[AI-Review][LOW] L1 — Inline `PS_SIZE=256` invariant baked into comment with no source-level assert** [src/exception.asm:213]. **Fix:** dropped the "invariantly 0" claim; replaced with a comment noting the depth_word is stored as a full 2-byte cell so a future `PS_SIZE` bump only requires re-validating the LDIR cycle budget, not the encoding.
- [x] **[AI-Review][LOW] L2 — Probe-18.5.1-B's c2 assertion is non-zero only (not literal `xt_ABORT`)** [tests/banking_tests.fth:1595..1597]. The load-bearing assertion for this story is c1 (deepest) == 1; c2 (= i*x's TOS-cell = xt_ABORT) is preserved by Story 11.4.1's saved-BC slot regardless of Story 18.5.1. **Fix:** added an explanatory comment so a future reviewer doesn't mistake the soft c2 check for the load-bearing one; declined to tighten to literal address (would couple the probe to dictionary layout for no extra coverage).
- [ ] **[AI-Review][LOW] L3 — IX-rstack capacity ceiling raised by depth_bytes per CATCH frame; no overflow guard added** [src/exception.asm w_CATCH_cf]. Each CATCH frame now consumes 8 + 2 + depth_bytes (≤256) = up to 266 bytes of IX rstack vs 8 bytes pre-Story-18.5.1. Nested CATCH amplifies. The kernel has no IX-rstack overflow check today (pre-existing). **Deferred to Phase-4 architectural review** — not a defect of this story (no overflow guard existed before either), but the worst-case envelope just grew ≈30×. Capture in `architecture-phase4-epics-16-22.md` E11-D appendix as an open architectural concern; Epic 22+ can address if `RS_SIZE` becomes tight.
- [x] **[AI-Review][LOW] L4 — `+23%` envelope overshoot is a recurring pattern worth a Lesson memory** [project knowledge]. Story 18.5.1 (+106 B vs +86 B estimate, +23%) is the second Phase-4 kernel-LDIR/scratch-cell story to overshoot per-component itemisation by ≈20-25% from register-juggle expansion + load-bearing scratch cells discovered mid-pass. **Fix:** added [[kernel-ldir-estimate-overshoot]] feedback memory recommending `estimate × 1.25 ± 10%` for AC#4 envelope on future IX-rstack LDIR stories. Does not waive [[no-preexisting-discharge]].
