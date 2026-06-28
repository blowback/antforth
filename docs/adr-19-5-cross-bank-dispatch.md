# ADR 19.5 — Cross-bank dispatch: layout-fragility root cause + DTC dispatch architecture

- **Status:** Accepted (Ant sign-off 2026-06-04 at Story 19.5.0 close; includes the NFR-P4-3 re-baseline rider. Sprint-status row renames for 19-5-1/19-5-3 deferred to their create-story time.)
- **Date:** 2026-06-04
- **Story:** 19.5.0 (Epic 19.5 stabilization interlude — ADR spike, zero binary delta)
- **Baseline:** 26834 B `build/antforth.com` @ 94c2ba0 (v3.0.3); `test-repl` 975/0/2; `test-repl-banking` 61/0/3
- **Decides:** DR-1 (the "trampoline layout-fragility" root cause + fix) and DR-2 (the DTC dispatch architecture for Stories 19.5.1–19.5.4)

This document is the first ADR in the repo and establishes the convention (Q1):
one file per decision cluster under `docs/`, decision records numbered DR-n,
status `Proposed` → `Accepted` on project-lead sign-off.

---

## DR-1 — "Sentinel-trampoline layout fragility" is portal-window dictionary aliasing

### Verdict

The hang class that forced the Story-19.2-H5 and Story-19.3 reverts is **not**
a trampoline defect, **not** a sentinel value-collision, and **not** an
emulator defect. The mechanism is:

> **Portal-window dictionary aliasing.** The interpreted-mode dictionary
> (HERE) grows monotonically from `kernel_end` and, under a long enough input
> (the full `banking_tests.fth` sequence), crosses `$8000` — the MMU slot-2
> window. A definition compiled at/above `$8000` physically lives in whatever
> page was mapped at compile time (bank 0's page `$22`, also the boot
> mapping). If that definition — specifically, any of its thread cells or
> inline-string bytes at ≥ `$8000` that still need to be **fetched** — runs
> while a foreign bank's page is mapped (because the definition itself
> executed `BANK!`, or because an earlier straddled definition died before
> its restoring `0 BANK!`), the fetch reads the foreign page. A zero-filled
> page yields thread cell `0000` → `JP $0000` → CP/M warm boot (the emulator
> exits); non-zero residue yields opcode soup that can spin (the historical
> "hang" flavor; `$76` HALT residue halts the emulator — both flavors
> demonstrated).

"Layout fragility" was a misattribution: kernel-size changes (+17 B, +33 B)
merely shift the dictionary base, which moves the `$8000` crossing point in
and out of vulnerable body regions. The kernel-size knob and the
dictionary-position knob were shown to be **the same variable** (evidence E4:
the PASS/HANG transition pad value shifts by exactly −K for kernel pad +K,
with the transition's absolute address invariant at 32696/32697).

### Evidence (all on the 26834 B baseline; reproducers committed under `tests/`)

- **E1 — deterministic repro.** The pre-19.3 configuration (full
  `banking_tests.fth` with `_iron-spike-test` invoked inline) dies 100%
  deterministically at the current baseline, byte-identical output across
  runs, last marker `---iron-spike-start---`
  (`tests/layout_fragility_sweep.sh`).
- **E2 — death trace.** `iz-cpm-banking --cpu-trace` tail: the `(.")` runtime
  at `$1864` processes the 34-char `iron-spike-sentinel-12345-returned`
  literal at `$7FE6`; IP advances past the string to `$800A`; the fetch
  (under bank-5 page `$39`, mapped by the body's own `5 BANK!` 14 cells
  earlier) returns `0000`; `JP HL` → `PC=0000` → warm boot. No EXIT_CODE, no
  trampoline, no EXECUTE frame on the death path. IX stable (`$F6FC`),
  R-stack balanced.
- **E3 — numeric straddle.** In-band `HERE U.` brackets: `_iron-spike-test`'s
  body spans 32580 (`$7F44`) → 32866 (`$8062`); `$8000` = 32768 falls
  mid-body, exactly where E2 died.
- **E4 — dose-response + knob equivalence** (`tests/straddle_repro.fth.in` +
  `tests/straddle_repro_sweep.sh`): a minimal victim word (`1 BANK!`,
  markers m1–m5, `0 BANK!`) positioned by an `ALLOT` shim. Marker truncation
  walks cell-by-cell as the pad pushes successive body cells above `$8000`
  (full matrix in the appendix). Cells above `$8000` executed **after** the
  `0 BANK!` restore print fine — the hazard is precisely *fetch ≥ `$8000`
  while a foreign page is mapped*, including the `LIT 0 / BANK!` restore
  cells themselves. Kernel knob K=0 vs K=128: transition pad 5593→5594 vs
  5465→5466; identical transition address.
- **E5 — surface cross-check.** The identical inline byte-stream **completes
  to BYE under flat iz-cpm** (port `0x72` unmodelled → no remap → no
  aliasing) and dies under iz-cpm-banking. The faithful MMU remap is the
  discriminating variable.

### Hypothesis dispositions (AC1 falsification record)

| Hypothesis | Disposition | Falsification / positive evidence |
|---|---|---|
| **H-A** sentinel value-collision (a legitimate popped return address equals `cross_bank_return`) | **Refuted** | Empirical: hang verdict + death signature invariant under relative shifts of `cross_bank_return` (+0..+128 B before-knob sweep, 19 points) — H-A requires onset/offset to track collision alignment. Structural: the legitimate popped-IP population cannot contain `cross_bank_return` ($4D80): dictionary IPs all ≥ `kernel_end` ($69D2); the cell at $4D80−2 is IN-BANK's terminal `DW EXIT_CODE` (bytes `23 04` verified in the binary), not a DOCOL callee, so no DOCOL push of the sentinel address exists on any executed path. E2 shows the death never touches EXIT_CODE. |
| **H-B** iz-cpm-banking emulator defect | **Refuted** | The emulator faithfully executes a wrong instruction stream (E2); its MMU model verified against `cpm_machine.rs` (boot `bank_map = [0x20,0x21,0x22,0x23]`, slot-2 boot page $22 = bank-0 page; reads honour the live map — real-MMU semantics). E5: the defect disappears exactly when the MMU is absent. The prior "hardware passes / emulator hangs" evidence was **input-confounded**: HW UAT 2026-05-20 ran the isolated `P193IRON.FTH` (body far below `$8000`); the emulator ran the full cumulative sequence (body straddling `$8000`). No emulator fix is owed (Q3's emulator branch is moot). |
| **H-C** latent antforth trampoline/frame bug (IX page-edge arithmetic, high-byte aliasing) | **Refuted as stated; replaced** | E2: IX stable, frames balanced, no trampoline involvement, no page-boundary IX arithmetic on the death path. The defect IS antforth-side, but it is the portal-aliasing mechanism above, not a frame bug. |

Historical manifestations explained: 19.2-H5 (+17 B → probe-18.2-a "hang
after the second EXIT_CODE invocation") and 19.3 (+33 B → iron-spike dies
after its success literal; the "26748→26749 boundary") are the same mechanism
with the straddle point landing at different body offsets; once a straddled
body dies past its print but before its restoring `0 BANK!`, **every**
subsequent window-resident definition executes from the wrong page — the
"cumulative state" cascade. cold_start NOP re-tuning (+0..+128) could not
recover because every shift ≤ 128 B leaves some vulnerable cell straddling at
those layouts. The H5 and 19.3 kernel fixes themselves were never refuted —
they were reverted against a test-configuration hazard, not a defect in the
fixes.

### Fix proposal (per `feedback_no_accept_disposition_for_bugs` — "document the boundary" is not on the menu)

The hazard is real for **users**, not just the test corpus: any definition
compiled after HERE crosses `$8000` that invokes `BANK!` (a documented
user-facing word) silently corrupts execution. Three components, itemised:

- **F1 — `BANK!` window guard (~20 B, Story 19.5.1).** In `w_BANK_STORE_cf`
  after the existing precondition (src/banking.asm:150..156): if
  `target_bank ≠ current_bank` AND the caller's IP (DE at DEFCODE entry) lies
  in `$8000..$BFFF`, THROW instead of switching. Per-opcode: `LD A,C` (1) +
  `CP (IY+current_bank)` (3) + `JR Z,.ok` (2) + `LD A,D` (1) + `CP $80` (2) +
  `JR C,.ok` (2) + `CP $C0` (2) + `JR NC,.ok` (2) + `LD BC,<code>` (3) +
  `JP w_THROW_cf.kernel_entry` (3) = **20 B**. New project THROW code (next
  free in the -257.. series): "bank switch from banked code". Converts the
  silent corruption class into a catchable error. Honest coverage note: this
  guards the immediate caller's IP; a deeper caller chain returning into the
  window after a switch is not caught (R-stack walking rejected on cost).
  With F2 below, the residual exposure is bank-0 bodies only.
- **F2 — bank-N HERE COLD-init to `$8000` (the H5 fix, re-landed; +17 B
  empirical from the H5 attempt, Story 19.5.1).** Initialise
  bank-table[1..28].here to `$8000` at COLD so banked dictionaries are
  page-resident from the first byte: bank-N bodies then never straddle
  (their content starts at the window base) and never alias (they execute
  with their own page mapped, entered via DR-2's dispatch). Unblocked now
  that the hang that forced its revert is explained and reproducible.
- **F3 — reproducer regression slot (test-side, 0 kernel B, Story 19.5.1).**
  `tests/straddle_repro.fth.in` + driver get a Makefile target asserting the
  PASS configuration passes and the HANG configuration still dies (the
  mechanism's signature), so any future dispatch change that alters the
  aliasing surface is caught.

Bank-0 bodies above `$8000` remain legal and correct while bank 0 is mapped
(page `$22` content); F1 makes the one dangerous act (switching away
mid-body) a THROW. The straddle case for bank 0 is thereby contained, not
abolished — abolishing it would require knowing a definition's final size at
`CREATE` time, which DTC compilation cannot.

**Position on the sentinel discriminator (Q3 disposition, stated even though
the hangs were not its fault):** `EXIT_CODE`'s value-tagged compare remains a
design smell — it discriminates by address equality against a population it
does not control (user `>R` values can forge it; future layouts could in
principle align a DOCOL-following cell with the label). DR-2's chosen
architecture **retires it entirely** (dispatch-site frame + return thunk),
which is the robust resolution.

**Hardware-truth caveat (named 19.5.4 assumption A1):** no hardware this
dev-pass. Prediction: real MicroBeast dies identically on the full inline
sequence (same slot-2 boot-page convention `$22`, same MMU semantics); the HW
UAT that "passed" used the isolated fixture. 19.5.4 verifies the straddle
reproducer's PASS/HANG signature on hardware.

---

## DR-2 — DTC dispatch architecture: option C (self-dispatching stub via RST vector)

### Decision

**Option C.** The descriptor stub becomes self-dispatching while staying
4 bytes: `[RST $28][target_bank][target_addr.lo][target_addr.hi]`. A
kernel-resident handler installed at the `$0028` RST vector performs the
bank-aware dispatch for BOTH `NEXT`-threaded calls and `EXECUTE`. The
cross-bank return is reworked to a **dispatch-site 2-cell frame
[caller_bank][caller_IP] + fixed-memory return thunk**, which handles DOCOL
and non-DOCOL targets uniformly (root cause (b) subsumed) and retires the
value-tagged sentinel mechanism.

`NEXT` stays byte-for-byte untouched: its blind `JP (HL)` lands on the
stub's byte 0, which is now an *instruction* that performs exactly the
dispatch `NEXT` was never taught. Zero per-thread-step cost; the Phase-2/3
test surface (NFR-P4-1) is untouched by construction.

### Per-step / per-call cost comparison (measured anchor: tight `10000 0 DO LOOP` = **124.1 T/iter** on the live kernel, trace cycle counters)

| | A — inline discriminator | B — shared `next_dispatch` | **C — self-dispatching stub** |
|---|---|---|---|
| Bytes (itemised below) | **+1990 B** (JP-variant; +2630 JR-variant) | **−875 B** | **≈ −13 B** |
| Per-NEXT-step cost (non-stub miss) | +21 T (JP-var) / +18 T (JR-var) | +28 T | **0 T** |
| Tight-loop compound (124.1 T/iter) | +14.5..16.9% | **+22.6%** | **0%** |
| NFR-P4-1 "no measurable regression" | FAIL | FAIL | **PASS** |
| NFR-P4-4 stub ≤ 5 B / capacity | 4 B / 461 (unchanged) | 4 B / 461 (unchanged) | **4 B / 461 (unchanged)** |
| Root cause (b) | +~37 B thunk machinery (added in total) | +~37 B (added in total) | subsumed (in itemisation) |
| Chokepoint-vs-scatter (19.4 CR lesson) | 320-site scatter | chokepoint | **chokepoint** |

Sub-2.5's prototype condition ("two options remain close") is not met; the
static itemisation is decisive and the per-step anchor was measured on the
live kernel rather than prototypes.

### Option A itemisation (rejected: bytes)

Expansion-site count: **320** in-kernel `NEXT`/`NEXTHL` sites (grep total 322
− 1 macro definition − 1 `test_key.com`). Per site, cheapest inline check
before the existing `JP (HL)`: `LD A,H` (1) + `CP $D4` (2) +
`JP NC,stub_dispatch` (3) = +6 B, miss +21 T (4+7+10); JR-variant +8 B,
miss +18 T. Subtotal +1920/+2560 B; shared stub-decode handler ~70 B.
**Total ≈ +1990..+2630 B.** The epics file's ~+250 B provisional neglected
the site multiplier (≈8× under) — exactly the class of planning-figure error
B.2 exists to catch. Disqualifying regardless of T-states.

### Option B itemisation (rejected: per-step T-states)

Per `NEXT` site `EX DE,HL / JP next_dispatch_hl` = 4 B vs 7 B; per `NEXTHL`
site 3 B vs 6 B; −3 B × 320 = −960 B. Shared body (fetch 6 B + discriminator
5 B + `JP (HL)` 1 B + stub branch 3 B ≈ 15 B) + handler ~70 B. **Net ≈
−875 B** — a real ~0.9 KB saving. Per-step cost: `JP` 10 T + `LD A,H` 4 +
`CP` 7 + `JR` miss 7 = **+28 T on every thread step**. Compound: +22.6% on
the measured canonical loop; ≈ +19% on a ~150 T DEFCODE double primitive,
consuming NFR5's ~20% margin by itself. Violates NFR-P4-1's binding "no
Phase-4 work measurably regresses" clause. (Observation for a future
size-crunch epic: B *without* the discriminator — pure NEXT centralisation —
trades ~−1 KB for +10 T/step; same NFR conflict, recorded here so it isn't
re-derived from scratch.)

### Option C itemisation (chosen)

Per-component bytes (B.2 discipline; opcode sizes summed):

| Component | Δ bytes |
|---|---|
| COLD-time RST-vector install (`LD A,$C3` 2; `LD ($0028),A` 3; `LD HL,stub_dispatch` 3; `LD ($0029),HL` 3) | +11 |
| `stub_dispatch` handler (RST entry: `POP HL`; bank read + `$FF`-fixed + same-bank checks; cross path: 2-cell frame push, MMU lookup + `OUT (0x72)`, `current_bank` update, `IP ← thunk`; enter: target read, `JP (HL)` with HL = CF — DOCOL `body = HL+3` precondition preserved) | +56 |
| Fixed-memory return thunk (1 thread cell: `DW xbank_restore`) | +2 |
| `xbank_restore` code word (pop [caller_bank][caller_IP], MMU restore, `current_bank` update, `NEXT`) | +35 |
| `BANK-OF` byte read moves to xt+1 (`INC HL`) — `$D4` legacy discriminator kept | +1 |
| `stub_allocate` emit-order change (writes `$EF` first, bank second; same 4 stores) | +0 |
| Retire `EXIT_CODE` sentinel discriminator (src/inner_interpreter.asm:61..68) | −13 |
| Retire `cross_bank_return` trampoline body (src/banking.asm:1132..1148) | −32 |
| `w_EXECUTE_cf` 3-way folds into the RST path (becomes `LD H,B / LD L,C / POP BC / JP (HL)` = 4 B vs 77 B) | −73 |
| **Net** | **≈ −13 B** |

Planning figure for 19.5.2: −13 B itemised; carry as **−13..+25 B** under the
×1.25 kernel-story discipline (`feedback_kernel_ldir_estimate_overshoot`).

T-states (per-opcode): intra-bank call **through a stub** ≈ 107 T from
`JP (HL)` to target CF (vs ≈ 123 T on the shipped EXECUTE intra path — C is
*faster* than the mechanism it replaces); cross-bank dispatch ≈ 343 T + the
return-side thunk ≈ 196 T (vs ≈ 420 T shipped EXECUTE cross path —
also faster). Non-banked words: **0 T delta** (FR-P4-19 zero-overhead
invariant preserved exactly; bank-0 `:` keeps legacy CFA-as-xt per 19.2 Q3-β,
so the entire Phase-2/3 surface never touches a stub).

### Root cause (b) — non-DOCOL cross-bank targets (AC3)

Subsumed by the chosen rework. The old contract ("callee's DOCOL pushes the
pre-loaded sentinel; callee's EXIT pops it") is **deleted**, not patched. The
dispatch site (RST handler) pushes [caller_bank][caller_IP] and sets
`IP = xbank_thunk` before entering the target:

- **DOCOL targets:** body runs; terminal EXIT pops the DOCOL-pushed
  thunk-IP → `NEXT` fetches the thunk cell → `xbank_restore` → caller's bank
  remapped, `IP = caller_IP`, `NEXT` → caller resumes.
- **DOVAR/DOCON/DEFCODE targets:** body runs and `NEXT`s directly using
  `IP = xbank_thunk` → same restore path. (Probe-19.3-F's hang class —
  cross-bank `VARIABLE`/`CREATE` references — becomes structurally
  impossible rather than specially handled.)

The thunk cell lives in fixed memory (always mapped), is read-only, and is
re-entrant for nested cross-bank calls (each nesting level has its own
2-cell frame). The 2-cell frame replaces the 3+1-cell sentinel frame —
cross-bank R-stack pressure *drops* (FR-P4-21's documented-gotcha rationale
improves). `CATCH` across a cross-bank boundary still needs its frame to
save/restore `current_bank` (+~20 B, the CATCH-cross-bank debt item;
anchored in 19.5.2's design, verified in 19.5.3's banked NFR-P4-8 variant).

### Epic-18 stub-contract impact analysis (AC2c — option C reopens PD-P4-11)

The 4-byte size, the xt-is-stub-address identity (PD-P4-1), the
`$D4CB..$DBFF` region, the 1845 B / 461-stub capacity, and NFR-P4-4's ≤ 5 B
pin are all **unchanged**. What changes is byte semantics: byte 0
`target_bank` → `$EF` (RST $28 opcode, constant); byte 1 `$C3` (dead JP,
Story 18.3 CR-H1) → `target_bank`; bytes 2..3 unchanged. Consumer migration
checklist (every byte-0/byte-1 reader, verified by grep at draft time):

1. `stub_allocate` (src/banking.asm:780..796) — emit order swap; 0 B.
2. `w_EXECUTE_cf` (src/inner_interpreter.asm:386..463) — 3-way retired
   (−73 B); both legacy and stub xts route through `JP (HL)`.
3. `BANK-OF` (src/banking.asm:868..877) — read xt+1 (+1 B); `$D4`
   discriminator unchanged.
4. `;`-emit (src/compiler.asm:702..708) and CREATE-emit
   (src/compiler.asm:822..839) — call `stub_allocate`; no change.
5. `(stub-allocate)` probes + Probe-18.1-A/B/C layout assertions
   (tests/banking_tests.fth) — byte-index updates; test-side only.
6. PD-P4-11 prose (architecture.md:347..365) + redesign §2.1 — doc updates
   in the implementing story per `make check-doc-sync`.

The "BANK-OF becomes a one-byte read" property (PD-P4-1) survives at +1 B.

### NFR verdicts (AC2b)

- **NFR-P4-1:** PASS for C only (0 per-step delta; bank-0/legacy surface
  byte-identical at dispatch). A and B fail the "no measurable regression"
  clause (+14.5% / +22.6% measured-loop compound).
- **NFR-P4-3 (cross-bank ≤ 60 T + bank-switch):** the itemised C figure
  (≈343 T dispatch-side) exceeds it — but so does the **shipped** Epic-18
  EXECUTE path (≈420 T per-opcode), so the envelope was already unmet when
  it was codified; C improves on shipped reality while failing the paper
  number. Per `feedback_no_accept_disposition_for_bugs` this is surfaced as
  an explicit decision, not silently accepted: **proposal** — re-baseline
  NFR-P4-3 to "cross-bank dispatch ≤ 400 T + MMU port write, measured
  RST-entry → target CF" with the per-opcode table in this ADR as the
  source of truth. Sign-off on the re-baseline rides with this ADR's
  acceptance; the alternative (micro-optimising the handler toward 60 T) is
  not achievable with a 2-cell frame + MMU lookup on this CPU.

  **NFR-P4-3 re-baseline #2 (banking-correctness interlude).** The "+ MMU
  port write" term was a single direct `OUT (0x72),A` (~12 T). That term is
  retired: the hot path now switches slot 2 through the BIOS via
  `mbb_set_slot2 → MBB_SET_PAGE` so the BIOS page shadow stays in sync (a
  direct `OUT` desyncs it and a later BIOS disk op can clobber the mapping).
  Hardware cost of one slot-2 switch ≈ **250 T**: `mbb_set_slot2` wrapper
  ~84 T (3×PUSH/POP + 2×LD + RET) + `CALL`/`JP` framing ~27 T + BIOS
  `set_page_mapping` body ~124 T (incl. `_mapping_address`, OUT, SCF; firmware
  `MicroBeast/firmware/beastos/bios.asm:1566`). The one-way dispatch
  (RST-entry → target CF) does exactly one such switch
  (`stub_dispatch.enter`, `src/banking.asm`), so the envelope re-baselines to
  **"cross-bank dispatch ≤ 600 T + one MBB_SET_PAGE, measured RST-entry →
  target CF"** (~343 T table + ~250 T switch). NOTE: under iz-cpm-banking
  `MBB_SET_PAGE` is a RET-trap (~27 T), so emulator T-state counts under-read
  the BIOS body by ~124 T — the 250 T switch figure is a hardware quantity.
  Sign-off rides with the interlude (the page-routing pivot, 2026-06-10).
- **NFR-P4-4 / NFR-P4-5:** PASS (stub 4 B; banking fixed-memory budget
  shrinks by the EXECUTE/trampoline retirements).

### Risks / named assumptions

- **A1 (19.5.4):** straddle reproducer PASS/HANG signature on real hardware
  (DR-1 prediction: identical death).
- **A2 (19.5.4):** `$0028` RST slot is claimable on MicroBeast CP/M (zero
  page is RAM; BIOS IM-1 uses `$0038`; iz-cpm intercepts only
  `$0000`/`$0005`; classic debuggers claim RST 6/7 — `$0030`/`$0038`).
  Verified on HW before 19.5.2 is declared done; fallback if occupied:
  `$0008`/`$0010`/`$0018`/`$0020` equivalents, same cost.
- **A3:** Probe-19.2-F (HW intra-bank-EXECUTE-into-slot-2 hang) is
  plausibly the same aliasing family (EXECUTE of a window-resident body
  under a stale mapping); re-test under the C dispatch + F2 COLD-init
  before assuming a distinct defect (19.5.4 first diagnostic).
- The iz-cpm test-643 `*/` cold_start NOP slot may need re-tuning after
  19.5.2's layout shift (known, separate quirk —
  `feedback_iz_cpm_test_643_quirk`).

---

## Consequences — Epic 19.5 story shape (AC4)

Story shape **amended** (reflected in `epics-phase4-epics-16-22.md` Epic-19.5
stories block in this dev-pass):

- **19.5.1 — Portal-aliasing guards + bank-N HERE COLD-init (H5) +
  reproducer regression slot** (was "trampoline stabilization"): F1 `BANK!`
  window guard (~20 B) + F2 bank-table[1..28].here = `$8000` at COLD (~17 B)
  + F3 Makefile regression target for the straddle reproducer. There is no
  trampoline fix to land — DR-1 found no trampoline defect; what 19.5.1
  actually buys is "kernel growth no longer breaks the banking test
  configuration, and the user-facing corruption class THROWs".
- **19.5.2 — Dispatch rework: self-dispatching RST stub + return thunk**:
  stub layout v2, `$0028` handler, thunk + `xbank_restore`, EXECUTE fold-in,
  EXIT_CODE/`cross_bank_return` retirement, `BANK-OF` offset, probe/doc
  migration per the checklist; CATCH-cross-bank frame fix designed here.
  Envelope −13..+25 B (+~20 B CATCH fix).
- **19.5.3 — Compiled-body verification** (H5 moved out to 19.5.1, its
  natural home): re-enable 19.2 AC4/AC5 + 19.3 AC3/DOES> compiled-body
  probes without EXECUTE-explicit rewording; banked NFR-P4-8 CATCH variant.
- **19.5.4 — HW investigation + close-out**: assumptions A1/A2/A3 above +
  full three-surface sweep + tag.

Epic envelope: itemised core ≈ +25..+80 B across 19.5.1+19.5.2 (F1 20 + F2 17
+ C net −13..+25 + CATCH ~20), ×1.25 discipline → **plan ~+30..+100 B** —
under the ~+130–250 B provisional, because option C's retirements pay for
most of its additions.

Memory/record corrections owed at story close: the
`feedback_iz_cpm_trampoline_fragility` memory attributes the hang to the
emulator and to "trampoline EXIT chain" — superseded by DR-1 (antforth-side
portal aliasing; emulator faithful; HW/emulator divergence was input
confound).

---

## Evidence appendix

### A. Kernel-knob sweep (full-sequence inline-iron-spike input, `tests/layout_fragility_sweep.sh before …`)

All 19 points N ∈ {0,1,2,3,4,5,6,7,8,12,16,17,24,32,33,48,64,96,128}:
verdict HANG, last marker `---iron-spike-start---`, while size walks
26834→26962 and `cross_bank_return` walks $4D80→$4E00. (No PASS exists in
this configuration at this baseline because the iron-spike body straddles at
every reachable shift; the dictionary-position knob below is the one that
produces both verdicts.)

### B. Dictionary-position sweep (`tests/straddle_repro_sweep.sh 0 …`, K=0, here0=27090)

| pad | body-start | body-end | markers |
|---|---|---|---|
| 5400..5590 (9 pts) | ≤32693 | ≤32780 | m1 m2 m3 m4 m5 survived |
| 5593 | 32696 | 32782 | m1 m2 m3 m4 m5 survived |
| 5594 | 32697 | 32784 | m1 m2 m3 m4 |
| 5600 | 32703 | 32790 | m1 m2 m3 m4 |
| 5605..5610 | 32708.. | | m1 m2 m3 |
| 5615..5625 | 32718.. | | m1 m2 |
| 5630..5800 | 32733.. | | m1 |

K=128 (here0=27218): transition 5465→5466 at body-start 32696→32697 —
**identical absolute transition address; pad shift = −K exactly.**

### C. Death trace excerpt (E2; `--cpu-trace`, last 8 instructions)

```
1874: INC DE        DE:800a            ; IP advanced past inline string
1875: EX DE, HL     HL:800a
1876: LD E, (HL)    DE:1800 ← (800A)=00  ; fetch under bank-5 page $39
1878: LD D, (HL)    DE:0000 ← (800B)=00
187a: EX DE, HL     HL:0000
187b: JP HL         PC:0000            ; thread cell 0000 → warm boot
0000: JP ff03h                          ; CP/M WBOOT → emulator exits
```

### D. Benchmark anchor (option B assessment)

`: _bench 10000 0 DO LOOP ; _bench` under `iz-cpm-banking -z`: cycle counter
at the `(LOOP)` body entry PC (`$12C4`), 10 000 samples:
(1403317−162434)/9999 = **124.11 T per iteration**. Option deltas: A +18..21
T/step → +14.5..16.9%; B +28 T/step → +22.6%; C 0.

### E. Reproducer usage

```
sh tests/layout_fragility_sweep.sh before 0 17 33 128   # hang-class repro, kernel knob
sh tests/straddle_repro_sweep.sh 0   5550 5593 5594 5650 # PASS→HANG dose-response
sh tests/straddle_repro_sweep.sh 128 5465 5466           # knob-equivalence kill-shot
```

Both drivers back up and restore `src/banking.asm` (working-tree-only edits)
and rebuild the pristine kernel on exit, per the AC5 / H5 revert discipline.
