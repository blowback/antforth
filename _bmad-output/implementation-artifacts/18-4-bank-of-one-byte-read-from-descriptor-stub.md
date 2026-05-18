# Story 18.4: `BANK-OF` — one-byte read from descriptor stub

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Context — why this story exists, why now

Fourth story of Epic 18 (Stub mechanism (γ) + cross-bank EXIT (S1 b)
+ `BANK-OF` + `IN-BANK`). Stories 18.1 + 18.2 + 18.3 closed
2026-05-18:

- **Story 18.1** delivered the descriptor-stub allocator
  (`stub_allocate` at `src/banking.asm:780..795`,
  `(stub-allocate)` DEFCODE wrapper at `:811..822`, +70 B). Stub
  layout (PD-P4-11): byte 0 = `target_bank` (signed byte, `$FF` =
  -1 = fixed-memory marker per FR-P4-13; `$00..$1C` = active bank
  index 0..28 per PD-P4-13); byte 1 = `$C3` (JP opcode); bytes 2-3
  = `target_addr` little-endian.
- **Story 18.2** delivered `cross_bank_return:` trampoline at
  `src/banking.asm:947..963` (~32 B) and the `EXIT_CODE`
  sentinel-comparison discriminator at
  `src/inner_interpreter.asm:55..71` (~13 B). +45 B.
- **Story 18.3** delivered the EXECUTE chokepoint 3-way dispatch
  (legacy CFA / intra-bank stub / cross-bank stub) at
  `src/inner_interpreter.asm:285..408`, with CR-H1 dispatch-shape
  fix; +73 B. AC1 cross-bank empirically validated by Probe-18.3-F
  (interpret-mode round-trip via NEGATE in bank 1). Probes
  18.3-B/C/D/E DEFERRED to Epic 19 due to the
  slot-2-swap-under-IP + FIND-walks-through-slot-2 hazards (see
  "Hazard inheritance" subsection below).

Story 18.4 lands the user-facing **`BANK-OF ( xt -- n )`** word
— a one-byte read of stub byte 0, sign-extended to a single-cell
return per FR-P4-5. The architecture's Important Decisions row at
`architecture.md:155` and PD-P4-11's "Architectural impact"
paragraph at `architecture.md:361` both name `BANK-OF` as
"essentially free under the (γ) layout"; the implementation
collapses to ~7-9 B body inside a DEFCODE header. Concretely:

1. **New word `BANK-OF` in `src/banking.asm`** (insertion point:
   immediately after `(stub-allocate)` at
   `src/banking.asm:822`, before `cross_bank_return:` at
   `src/banking.asm:947` — keeps stub-handling code grouped). The
   body reads byte 0 from `xt` (= stub address in TOS = BC), copies
   it into the low byte of the new TOS, and sign-extends the high
   byte so that the `$FF` fixed-memory marker reads back as the
   signed cell `-1` (and any `$00..$1C` active-bank index reads
   back as `0..28`).
2. **CCD-3 source-comment block** above the new DEFCODE per
   CCD-3 + NFR-P4-14 + the architecture's Implementation Patterns
   section. Citations: FR-P4-5; PD-P4-1 (γ rationale, free under
   the descriptor-stub mechanism, `architecture.md:209`); PD-P4-11
   (stub byte-0 layout, `architecture.md:347..363`); redesign
   `docs/antforth-banking-redesign.md` §1 row (`:17`) +
   forward-pointer to Story 18.5's `IN-BANK`.
3. **One row added to `docs/ans-forth-core-compliance.md`** in the
   "Non-standard words (not in Core or Core Extension)" table at
   `:858..879`, immediately after the `.BANKS` row, per the
   convention used by `BANK@` / `BANK!` / `+BANK` / etc. Format
   matches the existing rows — citation back to
   `docs/antforth-banking-redesign.md` §1 (the `BANK-OF` row at
   redesign `:17`).
4. **Probes in `tests/banking_tests.fth`** (AC4 sub-probes a/b/c)
   land in a new sentinel-bounded block immediately following the
   Story-18.3 `probe-18.3-f` block at
   `tests/banking_tests.fth:1238`. Sentinel-on-own-line discipline
   per M4 check; canonical PASS literals per Story-18.3 convention.
   Probe-18.4-A exercises AC4(a) (`' BANK@` → `-1`); Probe-18.4-B
   exercises AC4(b) (hand-allocated stub at `target_bank = 5` →
   `BANK-OF` returns `5`); Probe-18.4-C exercises AC4(c) (xt
   portability — same xt read across a `BANK!` round-trip still
   reads `5`, subject to the Q1 hazard disposition below).
5. **Per-binary-delta S9 hardware-smoke run on real MicroBeast**
   is in-scope per Lesson 17-C + Lesson 17-F: one hardware-typed
   `BANK-OF` probe runs on real MicroBeast; transcript saved per
   S9 / NFR-P4-11. `BANK-OF` itself is bank-state-agnostic (it
   reads a fixed-memory byte and sign-extends — no MMU writes,
   no R-stack pushes), so AC4(a) and AC4(b) are
   surface-agnostic: the iz-cpm-banking PASS verdict is binding,
   and the hardware run is a redundancy check. AC4(c) (cross-bank
   round-trip) inherits the Probe-18.3-F-shape hazard
   disposition; its hardware run is subject to Q1 below.
6. **No `IN-BANK` user-surface word lands here.** Story 18.5
   (`IN-BANK` + Epic 18 close-out + antforth 3.x.2 tag) consumes
   `BANK-OF` indirectly (via the Epic-18 close-out verdict-table
   walk) but lands the IN-BANK kernel word, the S11 version-
   surface audit, and the v3.x.2 tag.
7. **Binary-delta envelope is comfortable.** AC6 spec ceiling
   is ≤ ~30 B; the per-component itemisation (Dev Notes — Byte
   budget) sums to ~18-25 B (DEFCODE header for the 7-char
   "BANK-OF" name + 7-instruction body + NEXT macro + CCD-3
   comments which are 0 B). Lesson 17-B's ~2.4-2.7× empirical
   envelope would put a realistic worst case at ~75 B; the
   per-component sum stays well under the spec ceiling so
   Q6-a-extended accept-with-rationale is **not expected to fire**.

### Hazard inheritance from Story 18.3 (Q1 background)

Story 18.3's deferred probes (B/C/D/E) hit two compounded hazards
when run from the full-file-load `make test-repl-banking` context:

- **Slot-2-swap-under-IP** — a colon body whose `xt` sits in slot
  2 ($8000-$BFFF, the per-bank body region) is remapped on every
  `BANK!` to a different bank. The currently-executing body
  vanishes; NEXT-fetch reads garbage from the swapped-in bank's
  uninitialised memory; the kernel halts.
- **FIND-walks-through-slot-2** — after the test file has loaded,
  HERE has advanced past `$8000` and LATEST sits in slot 2. After
  a `BANK!` to a non-current bank, FIND walks the dictionary chain
  through slot-2 addresses, where the linked entries belong to a
  different bank's memory and the names don't match → undefined
  word.

`BANK-OF` itself is **NOT affected** — it is a pure byte read +
sign-extend with no MMU writes, no R-stack pushes, and no
inner-interpreter excursion. The hazard surfaces only in AC4(c)
where the **probe SHAPE** does `BANK! → BANK-OF → BANK!` round-
trip and the outer interpreter has to look up tokens between the
`BANK!` calls (a FIND-walks-through-slot-2 trigger).

Probe-18.3-F's pattern resolved this by **pre-allocating** the
stub before any `BANK!` and then executing a single cross-bank
EXECUTE through the trampoline (one round-trip, no intermediate
FIND-of-user-defined-word). Story 18.4's AC4(c) probe can adopt
the same shape — pre-resolve `' BANK-OF` to an xt on the stack
before the `BANK!`s, then `EXECUTE`-via-xt across the bank swap.
Dev-pass Q1 below dispositions the probe shape (interpret-mode
pre-resolve vs deferral to Epic 19).

## Story

As Marc (OG user) debugging cross-bank dependencies,
I want `BANK-OF ( xt -- n )` to return the bank a word lives in
(`-1` for fixed-memory words; logical bank index `0..28` for
banked words),
So that I can disambiguate "this word is in bank 5" from "this
word is in fixed memory" when writing cross-bank applications or
investigating dispatch surprises, **and** so that Epic 19's
bank-aware `:` and Epic 20's bank-aware FIND have a stable
introspection primitive to compose against (e.g.,
`' MYWORD BANK-OF .` is the canonical user-surface query for the
bank-residency of any word).

## Acceptance Criteria

**Given** Story 18.1 has shipped (`stub_allocate` at
`src/banking.asm:780..795`; `(stub-allocate)` wrapper at
`:811..822`; stub byte-0 = `target_bank` signed byte per
PD-P4-11 / FR-P4-13),
**When** Story 18.4 is dev-passed,

**Then** **AC1** (BANK-OF implementation — `src/banking.asm`) —
a new `w_BANK_OF` / `w_BANK_OF_cf` DEFCODE pair lands in
`src/banking.asm`, inserted between the `(stub-allocate)` body
(currently at `:811..822`) and the `cross_bank_return:` trampoline
(currently at `:947..963`) — re-validate these line numbers per
B.3 / Lesson 13.5-F at dev-pass start; do not inherit. The body
implements the stack effect `( xt -- n )` as a one-byte read of
the byte at address `xt`, sign-extended into a single-cell return:

  - **Input contract**: BC = xt = stub address (typically in
    `[STUB_ALLOC_BASE, $DC00)` = `[$D4CB, $DC00)`; but no range
    check is performed — the caller owns valid-stub-address
    discipline, matching the `stub_allocate` undefined-input
    contract at `src/banking.asm:751..769`).
  - **Body shape** (dev-pass-tuned; the shape below is reference,
    not contract): `LD H, B` / `LD L, C` (HL = xt) / `LD C, (HL)`
    (low byte of new TOS = byte 0 of stub) / `LD A, C` / `RLA`
    (sign bit → carry flag) / `SBC A, A` (A = $FF if neg, $00 if
    pos) / `LD B, A` (high byte of new TOS = sign-extension) /
    `NEXT`. Stack effect: TOS consumed (xt) and replaced (n) —
    no PUSH BC / POP BC wraps (single-cell-in, single-cell-out).
  - **Sign-extension correctness**: the stub byte-0 layout per
    PD-P4-11 stores `target_bank` as a SIGNED byte where `$FF` =
    `-1` (fixed-memory marker per FR-P4-13) and `$00..$1C` =
    active bank indices `0..28`. BANK-OF MUST preserve the sign
    so that `$FF` reads back as the cell `-1` (= `$FFFF`) and
    `$05` reads back as the cell `5` (= `$0005`). The
    `RLA / SBC A, A` shape achieves this in 2 instructions / 2 B;
    alternative shapes (`BIT 7,A` + branches; `XOR A` + conditional)
    are dev-pass-permissible.
  - **EXX-hygiene audit** (per NFR-P4-34 + `docs/register-conventions.md`
    §3 leaf-level rule + §7 EXX-using inventory): the body reads
    only main-set registers (BC, HL, A) and does NOT issue `EXX`.
    Lesson 17-D PUSH/POP DE wrap NOT required (no `EX DE, HL`,
    no `LDIR`, no DE-as-temp). Document the audit inline in the
    CCD-3 block.

**And** **AC2** ("essentially free" implementation per (γ)
rationale) — the BANK-OF body realises PD-P4-1's "BANK-OF
becomes a one-byte read from the stub — essentially free"
(`architecture.md:209`) and PD-P4-11's "BANK-OF (FR-P4-5) is
implemented as a one-byte read at xt+0 (free under this layout)"
(`architecture.md:361`). The realised emit (per Dev Notes Byte
budget) sums to ~18-25 B total (DEFCODE header + body + NEXT);
under the AC6 ≤ ~30 B spec ceiling. The CCD-3 block cites both
architecture rows as the source-of-truth for the "free under (γ)"
contract.

**And** **AC3** (source-comment + compliance-doc row per CCD-3 +
NFR-P4-14) —

  - A CCD-3 source-comment block lands above `w_BANK_OF` citing:
    FR-P4-5; PD-P4-1 (`architecture.md:209`); PD-P4-11
    (`architecture.md:347..363`); redesign §1 row at
    `docs/antforth-banking-redesign.md:17`; forward-pointer to
    Story 18.5's `IN-BANK` close-out. The block also documents
    the EXX-hygiene audit verdict per AC1 final sub-bullet, the
    undefined-input contract (no range-check on xt), and the
    sign-extension shape pick.
  - One row added to `docs/ans-forth-core-compliance.md` in the
    "Non-standard words (not in Core or Core Extension)" table
    at `:858..879`, immediately after the existing `.BANKS` row
    at `:878`. Row format: `| `BANK-OF` | `banking.asm:NNN` |
    Non-standard (antforth extension — see
    `docs/antforth-banking-redesign.md` §1; FR-P4-5 — one-byte
    read of descriptor-stub byte 0, sign-extended; `-1` for
    fixed-memory words, `0..28` for banked words) |` where `NNN`
    is the dev-pass-realised line number of `w_BANK_OF` (per
    PD-2 figure-drift discipline — extract from the realised
    source file, do not transcribe from this spec).

**And** **AC4** (REPL probes — `tests/banking_tests.fth`) —
sentinel-bounded probes land in a new block immediately following
`probe-18.3-f` at `tests/banking_tests.fth:1238` (re-validate the
insertion point at dev-pass start; line numbers shift). Sentinel
header on its own line / numbered probes / canonical PASS literal
/ sentinel footer on its own line per M4 end-sentinel check at
`Makefile:281..304`. `feedback_tib_size_inline_comments.md`
applies — no inline `\` annotation line exceeds TIB_SIZE = 128.

  - **Probe-18.4-A** (fixed-memory marker — AC4 sub-probe a) —
    pre-condition: any bank state (the probe does not touch
    BANK!). The probe:
    1. `' BANK@ -1 (stub-allocate)` — allocate a stub with
       target_addr = xt of BANK@ (fixed-memory), target_bank =
       `-1` (= signed byte `$FF`).
    2. `BANK-OF` — read the freshly-allocated stub's byte 0.
    3. Assert: TOS = `-1`. Print canonical PASS literal
       `probe-18.4-a-pass-fixed-mem-marker`.
    PASS on iz-cpm + iz-cpm-banking + hardware (surface-agnostic).
  - **Probe-18.4-B** (banked-bank-5 marker — AC4 sub-probe b) —
    pre-condition: any bank state. The probe:
    1. `0 5 (stub-allocate)` — allocate a stub with target_addr
       = 0 (placeholder; not executed by this story), target_bank
       = `5`. The allocator does not validate that bank 5 is in
       the active list (per `stub_allocate`'s undefined-input
       contract); byte 0 simply holds `$05`.
    2. `BANK-OF` — read the freshly-allocated stub's byte 0.
    3. Assert: TOS = `5`. Print canonical PASS literal
       `probe-18.4-b-pass-banked-bank-5`.
    PASS on iz-cpm + iz-cpm-banking + hardware (surface-agnostic
    — no MMU writes, no R-stack pushes, no bank-state dependency).
  - **Probe-18.4-C** (xt portability across `BANK!` — AC4 sub-
    probe c, per FR-P4-17) — pre-condition: ≥ 2 banks seeded.
    Dev-pass Q1 below dispositions the probe shape (interpret-
    mode pre-resolve vs deferral to Epic 19). The intent (if Q1
    picks the in-scope shape):
    1. `BANKS-CLEAR $22 +BANK $35 +BANK 0 BANK!` — seed two
       banks; ensure caller starts in bank 0.
    2. `0 5 (stub-allocate)` — allocate stub at `target_bank = 5`
       (the value-as-a-number; bank 5 need not be in the active
       list — the stub byte 0 simply stores `$05`). Save the
       returned xt (e.g., via `DUP` cascade).
    3. Pre-resolve `' BANK-OF` to its xt on the stack BEFORE any
       `BANK!` — this avoids FIND-walks-through-slot-2 (the
       Story-18.3 hazard) since `BANK-OF` lives in fixed memory
       and its xt is a fixed-memory CFA. The cross-bank
       `EXECUTE` then dispatches via the legacy-CFA path
       (`xt < STUB_ALLOC_BASE = $D4CB` per Story 18.3 AC1) and
       avoids the stub-dispatch chokepoint.
    4. `1 BANK!` — slot-2 swap to bank 1. (Probe-18.3-F precedent
       — this works in interpret mode when the next tokens'
       lookups are pre-resolved.)
    5. `DUP <bank-of-xt> EXECUTE` — read stub byte 0 while in
       bank 1; assert TOS = `5` (the stub bytes live in fixed
       memory at $D4xx and are NOT remapped by the slot-2 swap;
       BANK-OF's xt was pre-resolved; the EXECUTE dispatches via
       legacy-CFA path; the read succeeds).
    6. `0 BANK!` — swap back.
    7. `<bank-of-xt> EXECUTE` again — assert TOS still = `5`.
    8. `BANKS-CLEAR` cleanup.
    9. Print canonical PASS literal
       `probe-18.4-c-pass-xt-portability-across-bank-swap`.
    Probe-18.4-C is **PASS-on-banking-emulator-only**; conditional
    on Q1 disposition.

  Each probe block carries sentinel-bounded delimiters
  (`---probe-18.4-{a,b,c}-start---` / `---probe-18.4-{a,b,c}-end---`).
  Each end-sentinel is on its own line per the M4 fix.

**And** **AC5** (probe surfaces + hardware smoke per S9 /
NFR-P4-11) — the AC4 probes pass under iz-cpm-banking;
`make test-repl-banking` reports **Probe-18.4-A**, **Probe-18.4-B**,
and (subject to Q1 disposition) **Probe-18.4-C** PASS. **One
hardware-typed `BANK-OF` probe runs on real MicroBeast** covering
at least Probe-18.4-A + Probe-18.4-B (which are surface-agnostic
— iz-cpm-banking is binding witness but hardware confirmation
closes the S9 per-binary-delta discipline). Transcript saved to
`~/Downloads/beastty-<timestamp>.bin` per Lesson 17-C "independent
verdict surface". Hardware-smoke recipe is posted **in the closing
chat message** at code-review close per
`feedback_post_hw_smoke_steps_at_review.md` STRONG rule (fired
9× across Epic 17 + Story 18.1 + Story 18.2 + Story 18.3 — Ant
non-negotiable). Recipe is typed-form-validated under iz-cpm-banking
first per Lesson 17-F.

**And** **AC6** (binary delta — per-component itemisation per
B.2 / Lesson 13.5-C) — `wc -c build/antforth.com` grows by
**≤ ~30 B** for this story, tracked against the Epic-18 ~400 B
envelope per `architecture.md:479` row "Epic 18: ~400 B
(allocator ~150 B; trampoline ~80 B; EXECUTE-switch ~50 B;
`IN-BANK` + `BANK-OF` ~120 B)". The per-component itemisation
in Dev Notes (Byte budget) sums to ~18-25 B; under the AC6 spec
ceiling at 60-83% utilisation. Cumulative Epic-18 delta after
this story = Story 18.1 (+70 B) + Story 18.2 (+45 B) + Story 18.3
(+73 B) + Story 18.4 (~+18-25 B) ≈ **+206-213 B against the
~400 B envelope (52-53% consumed)**. Lesson 17-B realistic
envelope of ~2.4-2.7× would put a worst case at ~75 B; the
per-component sum stays well under so Q6-a-extended
accept-with-rationale is NOT expected to fire.

**And** **AC7** — `make test-repl` ≥ **975 PASS / 0 FAIL / 2 SKIP**
on iz-cpm (no regression of the Epic-17 / Story-18.1 / Story-18.2
/ Story-18.3 baseline — BANK-OF is a new DEFCODE word in
fixed memory with no inner-interpreter or compiler edits, so
the legacy-CFA dispatch path stays byte-for-byte unchanged);
`make test-repl-banking` reports the Story-18.3-close baseline
of 43 PASS + Probe-18.4-A + Probe-18.4-B + (subject to Q1)
Probe-18.4-C all PASS (≥ 45-46 PASS / 0 FAIL); `make check-doc-sync`
reports ≤ 31 advisories / 0 drift (Story-18.3 close baseline;
the one new row in `docs/ans-forth-core-compliance.md` does not
introduce a new section header, so no `[advisory-section]` is
added).

**FRs covered:** FR-P4-5 (`BANK-OF`); FR-P4-13 (descriptor-stub
byte-0-bank layout — consumed); FR-P4-17 (xt portability — AC4(c)
verifies xt stability across `BANK!` subject to Q1 disposition).
**NFRs codified:** NFR-P4-4 (per-stub ≤5 B — preserved; no stub-layout
edit); NFR-P4-11 / NFR-P4-36 (S9 hardware smoke per binary-delta
story — AC5); NFR-P4-14 (CCD-3 source comments — AC3);
NFR-P4-34 (S7 EXX-hygiene — AC1 final sub-bullet).
**Architectural inputs consumed:** PD-P4-1 (`architecture.md:209`,
γ descriptor-stub mechanism — BANK-OF is the "essentially free"
introspection consumer); PD-P4-11 (`architecture.md:347..363`,
4-byte stub layout with byte 0 = signed `target_bank`); FR-P4-5
(PRD Phase-4); redesign `docs/antforth-banking-redesign.md:17`
(BANK-OF row in the Phase-4 banking-wordset overview).
**Standing commitments touched:** S1 (CR fresh-context — code
review for Story 18.4 runs separately via the `CR` command in
fresh LLM session at dev-pass close per `_bmad/bmm/agents/dev.md`;
do not enumerate in ACs per the rejected pattern at
`instructions.xml:20..31`); S2 (REPL-piped tests — AC4 probes
follow `feedback_repl_tests_preferred.md`); S3 (real byte-count
estimation — per-component itemisation in Dev Notes per B.2 /
Lesson 13.5-C; NO "mirrors prior arm" shorthand per Lesson 13.5-C);
S4 (AC-composition validation — AC1 lands the code, AC2 affirms
the (γ) "free" rationale, AC3 binds the docs, AC4+AC5 compose as
test-coverage tiers ending in hardware smoke, AC6+AC7 compose as
bounded-binary + regression-clean envelope); S7 (EXX-hygiene
re-walk — AC1 final sub-bullet); S9 (per-binary-delta-story
hardware smoke — AC5; independent verdict surface per Lesson
17-C); S11 (no user-visible version surface yet — banner stays
at v3.0.1 until Story 18.5's Epic 18 close-out tag at antforth
3.x.2); S12 (hardware-typed probe discipline — AC5 typed-form
recipe smoke-tested under iz-cpm-banking first per Lesson 17-F);
CCD-3 (source-comment block — AC3); CCD-4 (per-epic benchmark
gate — Story 18.5 surfaces F2 banked-word stub-count metric;
Story 18.4 adds the user-facing introspection word that lets a
user query bank-residency without inspecting stub bytes directly).

## Tasks / Subtasks

### Pre-edit baseline (capture at dev-pass start, before any source edits)

- [x] Capture current binary size: `wc -c build/antforth.com` →
      record in story Dev Notes. **Expected baseline: 26,416 B**
      (Story 18.3 close). Re-`wc -c` from the actual current
      build artifact per B.3 / Lesson 13.5-F; do **not** inherit
      the prior story's reported number.
- [x] Capture current `make test-repl` baseline pass count.
      **Expected: 975 PASS / 0 FAIL / 2 SKIP**.
- [x] Capture current `make test-repl-banking` baseline.
      **Expected: 43 PASS / 0 FAIL** (40 baseline from Epic-17 +
      Story-18.1 + Probe-18.2-A/B + Probe-18.3-A + Probe-18.3-A2
      + Probe-18.3-F).
- [x] Capture current `make check-doc-sync` baseline.
      **Expected: 31 advisories / 0 drift**.
- [x] Re-validate insertion-point line numbers per PD-2 /
      figure-drift discipline. Specifically: `(stub-allocate)`
      body end-line (this spec quotes `:822`),
      `cross_bank_return:` start-line (this spec quotes `:947`),
      and `probe-18.3-f` end-line (this spec quotes
      `tests/banking_tests.fth:1238`). Line numbers shift; the
      spec quotes are reference, not source-of-truth — re-read
      the files at dev-pass start.
- [x] Cite `project_epic17_envelope.md` memory inline (Lesson
      17-B empirical envelope is ~2.4-2.7× the spec target;
      Stories 18.1 / 18.2 / 18.3 came in at 1.52× / 1.0× /
      0.91× of corrected mid-estimates — well within envelope).
      Q6-a-extended accept-with-rationale only triggers if the
      per-component estimate is materially overshot.
- [x] Decide sign-extension shape (Q2 below): `RLA / SBC A, A`
      (~2 B / ~8 T) vs `BIT 7, A / JR Z / LD B, -1` (~6 B /
      higher T) vs other. Record decision in Dev Notes with
      byte-count + T-state rationale.
- [x] Disposition Probe-18.4-C shape (Q1 below): interpret-mode
      pre-resolve-and-EXECUTE (in-scope) vs defer to Epic 19
      (matches Story 18.3 disposition of Probes B/C/D/E). Record
      decision in Dev Notes.

### Task 1 — `w_BANK_OF` DEFCODE body (AC1, AC2)

- [x] Read the current state of `src/banking.asm` around the
      insertion point. Confirm `(stub-allocate)` body ends and
      `cross_bank_return:` begins where the spec references
      indicate (per Pre-edit baseline re-validation).
- [x] Implement `w_BANK_OF` / `w_BANK_OF_cf` DEFCODE pair per
      AC1 body shape. Reference shape: `LD H, B / LD L, C / LD C,
      (HL) / LD A, C / RLA / SBC A, A / LD B, A / NEXT`. Q2
      decision governs the exact sign-extension idiom.
- [x] Apply Zilog dst-src operand order per
      `feedback_assembler_operand_order.md` (e.g., `LD H, B`
      means HL.high ← B; `LD C, (HL)` means C ← byte at HL).
- [x] Verify EXX-hygiene per AC1 final sub-bullet — no EXX
      issued; main-set-only register reads; document the audit
      verdict inline in the CCD-3 block (Task 2).
- [x] Verify the body emit fits the Byte budget itemisation in
      Dev Notes. If the dev-pass-realised emit overshoots
      ~25 B, invoke Q6-a-extended accept-with-rationale per
      `project_epic17_envelope.md`.

### Task 2 — CCD-3 source-comment block (AC3 first sub-bullet)

- [x] Add a CCD-3 block above the new `w_BANK_OF` DEFCODE, modelled
      on the existing `w_BANK_AT` (BANK@) block at
      `src/banking.asm:90..97` and the `(stub-allocate)` block at
      `:797..810`. Required citations:
      - FR-P4-5 (PRD Phase-4)
      - PD-P4-1 ((γ) descriptor-stub mechanism;
        `architecture.md:209`, "BANK-OF becomes a one-byte read
        from the stub — essentially free")
      - PD-P4-11 (4-byte stub layout, byte-0 = signed `target_bank`;
        `architecture.md:347..363`; specifically the
        "Architectural impact" paragraph at `:361` that names
        BANK-OF as "implemented as a one-byte read at xt+0
        (free under this layout)")
      - Redesign §1 row at `docs/antforth-banking-redesign.md:17`
      - Forward-pointer to Story 18.5 (`IN-BANK` + Epic 18
        close-out)
      - EXX-hygiene audit verdict (no EXX; main-set-only; Lesson
        17-D PUSH/POP DE wrap NOT required)
      - Undefined-input contract (no range-check on xt — caller
        owns valid-stub-address discipline; matches `stub_allocate`
        contract at `src/banking.asm:751..769`)
      - Sign-extension shape pick rationale (Q2 decision)

### Task 3 — Compliance-doc row (AC3 second sub-bullet)

- [x] Open `docs/ans-forth-core-compliance.md` and locate the
      "Non-standard words (not in Core or Core Extension)" table
      at `:858..879` (re-validate line range at dev-pass start
      per PD-2). The `.BANKS` row sits at `:878` as the current
      bottom row of the banking-words sequence.
- [x] Insert a new row immediately after `.BANKS`, before the
      `---` table-end marker at `:879`. Format matches the
      existing rows:
      `| `BANK-OF` | `banking.asm:NNN` | Non-standard (antforth
      extension — see `docs/antforth-banking-redesign.md` §1;
      FR-P4-5 — one-byte read of descriptor-stub byte 0, sign-
      extended; `-1` for fixed-memory words, `0..28` for banked
      words) |`
      where `NNN` is the dev-pass-realised line number of
      `w_BANK_OF` in `src/banking.asm` (extract from the actual
      source file per PD-2 — do NOT transcribe from this spec).

### Task 4 — Probes Probe-18.4-A/B/C (AC4)

- [x] Open `tests/banking_tests.fth` and locate the end of the
      Story-18.3 probe block (currently `_p18f-end` at `:1238`;
      re-validate line numbers per PD-2). Add a new sentinel-
      bounded probe block immediately after.
- [x] **Probe-18.4-A** (fixed-memory marker — AC4 sub-probe a).
      Implement per AC4(a) shape. Surface-agnostic; PASS on iz-cpm
      + iz-cpm-banking + hardware. Probe body can be interpret-mode
      (no enclosing colon body required — BANK-OF + (stub-allocate)
      + BANK@ are all DEFCODE primitives that work in interpret
      mode). Sentinel-on-own-line; canonical PASS literal
      `probe-18.4-a-pass-fixed-mem-marker`.
- [x] **Probe-18.4-B** (banked-bank-5 marker — AC4 sub-probe b).
      Implement per AC4(b) shape. Surface-agnostic (no MMU writes,
      no R-stack pushes — same shape as -A). Sentinel-on-own-line;
      canonical PASS literal `probe-18.4-b-pass-banked-bank-5`.
- [x] **Probe-18.4-C** (xt portability — AC4 sub-probe c).
      Implement per Q1 disposition. If Q1 picks in-scope:
      pre-resolve `' BANK-OF` to xt on stack BEFORE first BANK!;
      use `EXECUTE`-via-xt across the swap; verify BANK-OF reads
      `5` in both bank-0 and bank-1 contexts. If Q1 picks defer:
      add a sentinel-bounded "DEFERRED to Epic 19" marker block
      with rationale citing the Story-18.3 hazard pattern; do not
      add a real probe; update AC4(c) verdict in Dev Notes to
      DEFERRED.
- [x] Apply `feedback_tib_size_inline_comments.md` — verify no
      inline `\` annotation line in the new probe block exceeds
      TIB_SIZE = 128 chars. Long annotations live in standalone
      comment lines BEFORE the probe shape, not inline with code.

### Task 5 — Makefile `test-repl-banking` integration (AC5)

- [x] Add awk-extract + sentinel-bounded grep assertion blocks
      for Probe-18.4-A, Probe-18.4-B, and (subject to Q1)
      Probe-18.4-C in `Makefile`. Insertion point: immediately
      after the Story-18.3 `probe-18.3-f` assertion block at
      `Makefile:378..390` (re-validate at dev-pass start per
      PD-2). Pattern matches Story-18.3 blocks:
      - `awk '/---probe-18.4-{a,b,c}-start---$$/{p=1; next}
        /---probe-18.4-{a,b,c}-end---$$/{p=0} p'`
      - `grep -q '<canonical-pass-literal>'`
      - `! grep -q 'FAIL:'`
      - `grep -qE '^---probe-18.4-{a,b,c}-end---$$'` (M4
        end-sentinel-on-own-line check)
      - PASS message annotated with `under $(IZCPM_BANKING)` per
        the Story-18.3 convention.
- [x] If Q1 defers Probe-18.4-C, omit its Makefile assertion.

### Task 6 — Build + regression (AC6, AC7)

- [x] `make build` clean; record `wc -c build/antforth.com` and
      compute delta against the pre-edit baseline. Verify under
      the AC6 ≤ ~30 B ceiling.
- [x] `make test-repl` ≥ 975 PASS / 0 FAIL / 2 SKIP on iz-cpm.
      Regression baseline must hold (no inner-interpreter or
      compiler edits at this story; the legacy-CFA dispatch path
      is untouched).
- [x] `make test-repl-banking` ≥ 45 PASS / 0 FAIL (43 baseline +
      Probe-18.4-A + Probe-18.4-B), or ≥ 46 PASS if Q1 picks
      in-scope (= +Probe-18.4-C).
- [x] `make check-doc-sync` ≤ 31 advisories / 0 drift. The new
      compliance-doc row does not add a new section header.
- [x] iz-cpm test 643 layout-quirk padding (per
      `feedback_iz_cpm_test_643_quirk.md`). NOT EXPECTED at this
      story's binary-delta range (Stories 18.1 +70 B / 18.2 +45 B
      / 18.3 +73 B all PASSed without padding); if test 643
      trips, add 1-NOP padding at end of `cold_start`.

### Task 7 — Hardware smoke (AC5)

- [x] Author the typed-form hardware-smoke recipe. Minimum
      coverage: Probe-18.4-A (fixed-memory marker) + Probe-18.4-B
      (banked-bank-5 marker). Recipe is typed-form-validated
      under iz-cpm-banking FIRST per Lesson 17-F.
- [x] Smoke-test the recipe under iz-cpm-banking. Expected
      output: `BANK-OF .` prints `-1 ok` for the fixed-memory
      stub, `5 ok` for the bank-5 stub.
- [x] Run on real MicroBeast; capture transcript to
      `~/Downloads/beastty-<timestamp>.bin`.
- [x] Post the hardware-smoke recipe **in the closing chat
      message** at code-review close per
      `feedback_post_hw_smoke_steps_at_review.md` STRONG rule.
      Do not bury the recipe inside Dev Notes only — the user
      has reported this gap twice and the rule is non-negotiable.

### Task 8 — Sprint-status + commit

- [x] Update sprint-status row
      `18-4-bank-of-one-byte-read-from-descriptor-stub` →
      `in-progress` at dev-pass start → `review` at dev-pass
      close.
- [x] Compose dev-pass commit message per `gitmsg` convention;
      do **NOT** include `Co-Authored-By: Claude` trailer per
      `feedback_no_claude_coauthor.md` STRONG rule.
- [x] At code-review close, mark Story 18.4 → `done` in
      sprint-status and apply any deferred CR-fix dispositions.

## Dev Notes

### Architectural inputs consumed

- **FR-P4-5** (PRD Phase-4) — `BANK-OF ( xt -- n )` returns the
  bank a word lives in (`-1` for fixed memory). Implemented as
  a one-byte read from descriptor stub at `xt` (free under
  FR-P4-13). The PRD row at
  `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:40`
  is the requirement source.
- **PD-P4-1** (`architecture.md:209`) — γ fixed-memory descriptor
  stubs. The "BANK-OF becomes a one-byte read from the stub —
  essentially free" sentence is the source-of-truth for AC2's
  "free under (γ)" claim.
- **PD-P4-11** (`architecture.md:347..363`) — 4-byte stub layout
  pin. Byte 0 = `target_bank` (signed; `$FF` = -1 fixed-memory
  marker; `$00..$1C` = active bank index 0..28). The
  "Architectural impact" paragraph at `:361` names BANK-OF as
  the consumer of this byte. Story 18.4 IS the implementation
  of that architectural claim.
- **FR-P4-13** (PRD Phase-4) — descriptor stub carries
  `(target_bank, target_addr_in_bank)`; byte 0 = `target_bank`
  signed-byte semantics.
- **FR-P4-17** (PRD Phase-4) — xt portability (stubs in fixed
  memory; xts stable across `BANK!`). AC4(c) verifies this
  property by reading the same xt's byte 0 from a different
  bank context and getting the same value.
- **Redesign §1 row** (`docs/antforth-banking-redesign.md:17`)
  — the user-facing description of `BANK-OF` in the Phase-4
  banking-wordset overview. The CCD-3 block cites this row as
  the canonical user-doc anchor.
- **Architecture's file-touch map** (`architecture.md:840`) —
  Epic 18 row names `BANK-OF + IN-BANK wordset bodies in
  src/banking.asm`. Story 18.4 lands the `BANK-OF` body; Story
  18.5 lands the `IN-BANK` body.

### Source-file structure (pre-edit reference)

- `src/banking.asm` (972 lines at Story 18.3 close —
  re-`wc -l` at dev-pass start per B.3). Insertion point for
  `w_BANK_OF`:
  - After `w_PAREN_STUB_ALLOCATE_cf` body end (currently `:822`).
  - Before the `cross_bank_return` separator banner (currently
    starts at the `; ===` block around `:824`).
  - Rationale: keeps the new word grouped with the stub-handling
    code (`(stub-allocate)` immediately above; `cross_bank_return`
    immediately below). Existing precedent for in-source
    grouping by topic: `w_BANK_AT` / `w_BANK_STORE` /
    `bank_offset_hl` / `w_BANKS` are all clustered in `:90..258`.
- `docs/ans-forth-core-compliance.md` (888+ lines — re-`wc -l`
  at dev-pass start). Insertion point for the BANK-OF row:
  immediately after `.BANKS` at `:878`, before the `---`
  table-end marker.
- `tests/banking_tests.fth` (1238 lines at Story 18.3 close).
  Insertion point for the Probe-18.4 block: immediately after
  `_p18f-end` at `:1238`.
- `Makefile` (9679 lines at Story 18.3 close). Insertion point
  for the Probe-18.4 assertion blocks: immediately after the
  `probe-18.3-f` assertion block at `:378..390`.

### Byte budget (per-component itemisation per B.2 / Lesson 13.5-C)

The story-template "Pre-edit baseline" task captures the actual
byte delta against this itemisation.

| Component | Estimated kernel delta |
|-----------|------------------------:|
| `DEFCODE` header for "BANK-OF" name (7 chars): link cell 2 B + flags+len byte 1 B + name 7 B + cf-stub bytes per the DEFCODE macro convention (compare `w_BANK_AT` header at `src/banking.asm:98..100` for the canonical shape) | ~10-13 B |
| `w_BANK_OF_cf` body: `LD H, B` (1) + `LD L, C` (1) + `LD C, (HL)` (1) + `LD A, C` (1) + `RLA` (1) + `SBC A, A` (1) + `LD B, A` (1) | ~7 B |
| `NEXT` macro emit (Z80 jump back to inner-interpreter; varies by macro definition — typically 1-3 B) | ~1-3 B |
| CCD-3 source-comment block above `w_BANK_OF` (Task 2) | 0 B (comments only) |
| `docs/ans-forth-core-compliance.md` row (Task 3) | 0 B (doc-only) |
| Probe block in `tests/banking_tests.fth` (3 probes) | 0 B (REPL-side) |
| Makefile `test-repl-banking` awk-extract + grep blocks (Task 5) | 0 B (Makefile-side) |
| iz-cpm test-643 layout-quirk NOP padding | 0 B (not expected at this delta range — Stories 18.1 / 18.2 / 18.3 did not trip) |
| **Per-component sum** | **~18-25 B** |

This is well under the AC6 spec ceiling of ≤ ~30 B (60-83%
utilisation). Lesson 17-B realistic envelope of ~2.4-2.7× would
put a worst case at ~75 B; the per-component sum stays well
under so Q6-a-extended accept-with-rationale is **not expected
to fire**. The body emit is highly constrained — it is 7
straight-line instructions with no branches, no R-stack
manipulation, no MMU writes, no per-cell loops. Realised emit
should land within ±2 B of the itemisation.

The per-component itemisation is INDEPENDENT — it sums each
component (DEFCODE header, body instructions, NEXT macro) from
opcode-byte-cost first principles, NOT from comparison-to-prior-
arm shorthand per Lesson 13.5-C. The header cost references
`w_BANK_AT`'s realised shape only as a sanity anchor (its
realised header is the same shape this story emits — both are
non-immediate DEFCODE words with comparable name lengths), not
as the source of the estimate.

### Open questions for dev-pass

- **Q1 — Probe-18.4-C disposition.** Two main options:
  - **(a) In-scope at this story (pre-resolve-and-EXECUTE
    pattern).** Pre-resolve `' BANK-OF` to its xt on the stack
    BEFORE the first `BANK!`. Use `<xt> EXECUTE` to invoke
    BANK-OF across the bank swap. Avoids
    FIND-walks-through-slot-2 (the Story-18.3 hazard that
    forced deferral of Probes B/C/D/E) because BANK-OF's xt is
    a fixed-memory CFA (its xt is in `[0x0100, 0xD4CB)` per
    Story 18.3's legacy-CFA range) and the EXECUTE dispatches
    via the legacy-CFA path (`JR C, .legacy_dispatch` at
    `src/inner_interpreter.asm:285..408`), which is byte-for-byte
    the Phase-3 `JP (HL)` baseline. No slot-2 IP-fetch hazard
    either because no colon body is currently executing — the
    BANK! sequence runs from the outer interpreter and the
    inter-token lookups (`DUP`, `EXECUTE`, integer literals)
    target kernel-fixed-memory primitives that pre-date HERE
    advancing past $8000.
    - **Risk**: the outer-interpreter token lookups between the
      BANK!s walk LATEST→link→link... If LATEST sits in slot 2
      after the test file has loaded, the chain crashes (per
      Story-18.3 third-attempt debug-log entry). Mitigation: see
      Probe-18.3-F's successful pattern which avoids any
      intermediate FIND-of-non-kernel-word; this story's probe
      only uses BANK!, EXECUTE, DUP, integer literals, and the
      pre-resolved BANK-OF xt — all of which resolve to kernel
      words in fixed memory IF the FIND chain reaches them before
      walking into slot 2. Story-18.3's third attempt suggests
      FIND chain in full-file-load context has LATEST in slot 2
      → first chain step crashes. Empirical dev-pass verifies.
  - **(b) Defer to Epic 19 (matches Story 18.3 disposition of
    Probes B/C/D/E).** Document the FR-P4-17 verification gap
    as a forward commitment to Epic 19 close-out (when per-bank
    HERE plumbing makes it cleanly testable). Cite Story 18.3
    deferral precedent. Probe-18.4-C is replaced by a
    sentinel-bounded "DEFERRED to Epic 19" marker block in
    `tests/banking_tests.fth` with rationale.
  - **Recommendation: (a) attempt empirically; fall back to (b)
    if dev-pass hits the FIND-chain-in-slot-2 hazard.** The
    BANK-OF semantics are simple enough that AC4(a) + AC4(b)
    provide strong implementation coverage even without AC4(c);
    AC4(c) is the xt-portability witness which has narrow
    additional coverage (the stub bytes are in fixed memory —
    structural — so the property is provable rather than only
    empirical). Q1 decision recorded in Pre-edit baseline task.

- **Q2 — Sign-extension shape.** Three main options:
  - **(a) `RLA / SBC A, A`** (2 B / 8 T). Idiomatic Z80 sign-
    extend: RLA shifts bit 7 of A into carry; SBC A, A produces
    $FF if carry set, $00 if clear; load into B. Smallest, no
    branches.
  - **(b) `BIT 7, A / JR NZ, .neg / LD B, 0 / JR .done / .neg: LD
    B, $FF / .done:`** (~10 B / variable T). Explicit branches;
    more readable; larger.
  - **(c) `CP $80 / JR C, .pos / LD B, $FF / JR .done / .pos:
    LD B, 0 / .done:`** (~8 B). Explicit unsigned-compare-to-
    half; readable but still branchy.
  - **Recommendation: (a) `RLA / SBC A, A`.** 2 B / 8 T is the
    optimum; the idiom is documented in Zilog programming guides
    and consistent with `src/exception.asm`'s sign-extension uses
    (re-verify at dev-pass start). The CCD-3 block documents the
    idiom inline with a one-sentence explanation.

### Standing commitments touched

- **S1** — adversarial CR fresh-context: code-review for Story
  18.4 runs separately via the `CR` command in fresh LLM session
  at dev-pass close (per `_bmad/bmm/agents/dev.md` `CR` item; do
  not enumerate in ACs per the rejected pattern at
  `instructions.xml:20..31`).
- **S2** — REPL-piped tests: AC4 probes are sentinel-bounded
  REPL-piped Forth scripts (per `feedback_repl_tests_preferred.md`).
- **S3** — real byte-count estimation: per-component itemisation
  above per B.2 / Lesson 13.5-C. NO "mirrors prior arm" rationale.
- **S4** — AC-composition validation: AC1 lands the code; AC2
  affirms the (γ) "free" rationale; AC3 binds the docs (CCD-3
  source comment + compliance-doc row); AC4 + AC5 compose as
  test-coverage tiers (probe → hardware-smoke); AC6 + AC7 compose
  as bounded-binary + regression-clean envelope.
- **S7** — EXX-hygiene re-walk: the BANK-OF body uses main-set
  only (BC, HL, A). No EXX. Documented inline in CCD-3 per AC1.
- **S9** — per-binary-delta-story hardware smoke: AC5 + Task 7.
  Independent verdict surface per Lesson 17-C.
- **S11** — user-visible version surface audit: not surfaced at
  Story 18.4 (banner stays at v3.0.1; the next S11 surface is
  Story 18.5's Epic 18 close-out tag at antforth 3.x.2).
- **S12** — hardware-typed probe discipline: Task 7's hardware-
  smoke recipe must be typed-form-validated under iz-cpm-banking
  before handing off to hardware (Lesson 17-F).
- **CCD-3** — source-comment pointers: AC3 + Task 2 (BANK-OF
  CCD-3 block citing FR-P4-5 + PD-P4-1 + PD-P4-11 + redesign §1
  + forward-pointer to Story 18.5; EXX-hygiene audit verdict;
  undefined-input contract; sign-extension shape pick rationale).
- **CCD-4** — per-epic benchmark gate: Story 18.5 surfaces F2
  banked-word stub-count metric; Story 18.4 adds the user-facing
  introspection word that lets a user query bank-residency
  without inspecting stub bytes directly.

### Hazard inheritance from Story 18.3 (Q1 background, detailed)

Story 18.3's debug log (`18-3-...md:1194..1228`) documents three
attempts at Probe-18.3-B (cross-bank EXECUTE from bank 0):

1. **First attempt** — used `'` (bare tick) inside a colon body.
   Failed with `-13 undefined word` at runtime (tick is interpret-
   only; `[']` is the compile-time variant).
2. **Second attempt** — fixed by using `[']` inside the colon body.
   HUNG iz-cpm-banking at the `1 BANK!` step. Root cause: the
   probe colon body's xt sits at `$8630` (slot 2 of bank 0); when
   `1 BANK!` swaps slot 2 to bank 1's page, the currently-running
   body's bytes vanish → NEXT-fetch reads garbage → kernel halts.
3. **Third attempt** — invoked the probe at interpret mode (no
   enclosing colon body). Used `'` on kernel words after `1 BANK!`.
   Failed: in the full-file-load context, FIND walks the
   dictionary chain through user-defined entries above `$8000`,
   which are remapped by the slot-2 swap. The fresh-REPL case
   works (verified standalone `' NEGATE U.` after `1 BANK!`
   succeeds), but in the full-file-load context the chain crashes.

Probe-18.3-F's successful pattern broke the deadlock by:
- Pre-allocating the stub BEFORE the bank swap (so the stub xt is
  on the stack, not requiring a FIND).
- Invoking ONE cross-bank `EXECUTE` (which uses the trampoline +
  chained EXIT — a single round-trip with no intermediate FIND).
- Using a colon-body helper (`_p18f-check`) for assertions, called
  AFTER the trampoline restores bank 0 (so slot 2 is back to its
  original page before the helper body executes).

Story 18.4's AC4(c) probe CAN follow the same pattern IF:
- BANK-OF's xt is pre-resolved (via `'` in interpret mode at
  probe start, BEFORE any BANK!).
- Between BANK!s, only kernel words (DUP, EXECUTE, integer
  literals) are invoked.
- Assertion logic runs AFTER returning to bank 0.

Q1 decision is whether this pattern is sufficient in the
full-file-load context (where LATEST is in slot 2 from the test
file having loaded a series of helper colon bodies). The
empirical answer is: probably yes (Probe-18.3-F works), but only
dev-pass empirical testing confirms.

### Forward-inheritance pointers

- **Story 18.5** (`IN-BANK` + Epic 18 close-out + antforth 3.x.2
  tag) consumes BANK-OF in the Epic 18 close-out verdict-table
  walk (one PASS row per Story 18.1..18.5) and in the user-facing
  banking-wordset roster (12-word `BANK*` wordset is locked per
  `architecture.md:191`). No direct functional dependency.
- **Epic 19** (bank-aware `:`) consumes BANK-OF indirectly: each
  banked `:`-definition gets a stub via `stub_allocate` (allocated
  in `;`); BANK-OF on the resulting xt returns the bank where `:`
  landed the body. The "north-star UX" probe at
  `epics-phase4-epics-16-22.md:847` includes
  `' FROM-FIVE BANK-OF .` returning `5` — this story's BANK-OF
  IS the implementation of that user query.
- **Epic 20** (bank-aware FIND) consumes BANK-OF transitively:
  the `BANK-OF`-of-a-FIND-result is the canonical way to learn
  which bank's wordlist a name came from after a multi-bank
  WORDS dump.
- **Epic 22** (polish) — BANK-OF stays surface-stable through
  Epic 22; the F2 banked-word stub-count metric (CCD-4 close-out
  line item per Finding F2 mitigation, Story 18.5) MAY use
  BANK-OF as one of the iteration primitives in a stub-count
  utility script, but no functional dependency.

### Lessons applied

- **Lesson 17-B** (`project_epic17_envelope.md`) — empirical
  envelope was ~2.4-2.7× the spec target across Epic 17; Stories
  18.1 / 18.2 / 18.3 came in at 1.52× / 1.0× / 0.91× of corrected
  itemisations. Story 18.4 per-component itemisation lands at
  ~18-25 B (well under the AC6 ≤ ~30 B spec ceiling and well
  under the realistic envelope of ~75 B). Cite the memory inline
  at dev-pass start; Q6-a-extended re-litigation is **not**
  expected.
- **Lesson 17-C** — hardware-smoke is an **independent verdict
  surface**, not a redundancy check on `make test-repl-banking`.
  AC5 + Task 7 plan the hardware run as a separate verdict — even
  though BANK-OF is surface-agnostic (no MMU writes), the
  per-binary-delta-story discipline applies.
- **Lesson 17-D** (PUSH/POP DE wrap) — NOT triggered at this
  story. The BANK-OF body has no `EX DE, HL`, no `LDIR`, no
  DE-as-temp. DE is untouched. Document the absence inline in
  the CCD-3 block.
- **Lesson 17-F** — hand-typed hardware-smoke recipes for any
  banked-RAM probe are brittle. AC5's recipe smoke-tests under
  iz-cpm-banking in EXACT typed form before handing off to
  hardware (Task 7). BANK-OF's recipe is shorter and simpler
  than Story 18.3's (no banked body to hand-emit), but the
  same discipline applies.
- **Story 18.1 close-out hygiene** — append components at the
  natural file position; cite PD-P4-N decisions inline at the
  source site per CCD-3.
- **Story 18.2 / 18.3 close-out hygiene** — same. The
  stub-byte-0 layout that BANK-OF reads is the one Story 18.1
  allocated and Story 18.3's EXECUTE chokepoint discriminates
  on; the three stories share the same byte-0 contract.
- **`feedback_no_claude_coauthor.md` STRONG rule** — commit
  messages must NOT include `Co-Authored-By: Claude` trailer.
- **`feedback_post_hw_smoke_steps_at_review.md` STRONG rule**
  — hardware-smoke recipe is posted in the closing chat message
  at code-review close (Task 7 + Task 8). Fired 9× across Epic
  17 + Story 18.1 + Story 18.2 + Story 18.3 — Ant non-negotiable.
- **`feedback_tib_size_inline_comments.md`** — REPL probe lines
  (code + `\` annotation) MUST stay ≤ TIB_SIZE = 128 chars.
  Long annotations live as standalone comment lines BEFORE the
  probe shape (Task 4 final sub-bullet).
- **`feedback_assembler_operand_order.md`** — Zilog dst-src
  operand order for the BANK-OF body instructions (Task 1).
- **`feedback_repl_tests_preferred.md`** — REPL-piped Forth
  scripts preferred over assembly test-thread extensions.
  AC4 probes follow this convention.
- **`feedback_stabilisation_interlude.md`** — if Q1 surfaces
  that Probe-18.4-C empirically fails the FIND-chain-walk
  hazard, defer to Epic 19 (don't smuggle stabilisation into
  this feature story's scope).
- **`feedback_no_accept_disposition_for_bugs.md`** — if AC1's
  BANK-OF surfaces a hardware-vs-spec divergence (e.g., the
  byte-0 read differs between iz-cpm-banking and real
  MicroBeast — very unlikely since this is a plain memory
  read), don't offer "accept" disposition — propose a fix.
- **PD-2 / B.4 figure-drift discipline** (template `<critical>`
  block) — every line:column citation in this spec is REFERENCE.
  Dev-pass re-validates by re-reading the cited file at dev-pass
  start. Specifically: the stub_allocate / cross_bank_return /
  probe-18.3-f / .BANKS row line numbers all shift as files
  grow; the spec quotes the Story-18.3-close state but the
  dev-pass extracts from current state.
- **Lesson 13.5-C / B.2** — the Byte budget itemisation above
  is INDEPENDENT per-component, not "mirrors Story 18.X" or
  "same shape as BANK@". The DEFCODE header cost references
  `w_BANK_AT` only as a sanity anchor (same word-class, similar
  name length), not as the source of the estimate. Each
  instruction's byte cost is from Z80 opcode-cost first
  principles.

### Project Structure Notes

- **No new files created** in Story 18.4. All work lands in
  existing files: `src/banking.asm` (BANK-OF DEFCODE);
  `docs/ans-forth-core-compliance.md` (1 row);
  `tests/banking_tests.fth` (3 probes); `Makefile` (3
  awk-extract + grep blocks, or 2 if Q1 defers -C).
- **No file-touch surface variance** vs the architecture's
  Phase-4 file-touch map at `architecture.md:840` — Epic 18 row
  explicitly names `BANK-OF + IN-BANK wordset bodies in
  src/banking.asm` as the implementation site for both words.
  Story 18.4 takes the BANK-OF half; Story 18.5 takes IN-BANK.
- **CCP-evicted region** (`$D400-$DBFF` per Story 17.1
  `src/banking.asm:10..14`) is unchanged — BANK-OF reads from
  it (the stubs live there) but does not allocate or modify
  anything in it.

### References

- **Story 18.1**
  (`_bmad-output/implementation-artifacts/18-1-descriptor-stub-allocator-xt-as-stub-address-contract.md`)
  — predecessor story; descriptor-stub allocator +
  `(stub-allocate)` wrapper + `stub_alloc_tail` UserArea cell +
  `STUB_ALLOC_BASE` constant. Stub byte-0 layout source. Verdict:
  10/10 ACs PASS; +70 B.
- **Story 18.2**
  (`_bmad-output/implementation-artifacts/18-2-sentinel-trampoline-cross-bank-return-kernel-exit-distinguishes-intra-bank-from-cross-bank.md`)
  — predecessor story; `cross_bank_return:` trampoline +
  EXIT_CODE sentinel comparison. Adjacent to BANK-OF's
  insertion point. Verdict: 10/10 ACs PASS; +45 B.
- **Story 18.3**
  (`_bmad-output/implementation-artifacts/18-3-kernel-execute-dispatches-through-stub-initial-compile-comma-stub-emission-wiring-dispatch-budget-verification.md`)
  — predecessor story; EXECUTE chokepoint 3-way dispatch +
  CR-H1 dispatch-shape fix. Source of the hazard pattern that
  Q1 dispositions and of the Probe-18.3-F successful
  interpret-mode pre-resolve pattern. Verdict: AC1/2/4/8/9 PASS,
  AC3 PARTIAL (Q6-a-extended), AC5/6/7 PARTIAL (Probes -B/-C/-D/-E
  deferred to Epic 19). +73 B.
- **Story 17.6**
  (`_bmad-output/implementation-artifacts/17-6-iron-spike-first-hand-built-cross-bank-call-on-real-microbeast-epic-17-close-out-antforth-3-x-1-tag.md`)
  — iron-spike precedent for hand-built banked code body
  patterns (5-helper-word decomposition per Lesson 17-F).
  Not directly consumed by Story 18.4 (no hand-built body
  needed), but cited as the structural precedent for AC5's
  typed-form hardware-smoke recipe discipline.
- **Epic 17 retro**
  (`_bmad-output/implementation-artifacts/epic-17-retro-2026-05-17.md`)
  — Lessons 17-A through 17-G; Action items A1 / A2 / A3 / A4
  carried forward to Epic 18 / Story 18.x.
- **PRD Phase-4** (`_bmad-output/planning-artifacts/prd.md` /
  `_bmad-output/planning-artifacts/epics-phase4-epics-16-22.md:698..716`)
  — Story 18.4 spec block. FR-P4-5 (BANK-OF row at `:40`).
- **Architecture Phase-4**
  (`_bmad-output/planning-artifacts/architecture.md`) — PD-P4-1
  (`:207..211`); PD-P4-11 (`:347..363`); Important Decisions row
  (`:155`); Epic-18 envelope (`:479`); Epic-18 file-touch row
  (`:840`).
- **Redesign doc** (`docs/antforth-banking-redesign.md`) — §1
  row (`:17`) for BANK-OF; §2.1 (γ descriptor stubs); §5.2
  (CP/M residency layout); §7 (perf/memory budgets).
- **Compliance doc** (`docs/ans-forth-core-compliance.md`) —
  "Non-standard words" table at `:858..879`; insertion point
  for new BANK-OF row.
- **Register conventions** (`docs/register-conventions.md`)
  — §3 (leaf-level EXX rule); §7 (EXX-using inventory).
  BANK-OF body S7 audit (Task 1) cites both sections.
- **Memory** — `project_phase4_scope.md`;
  `project_epic17_envelope.md`; `feedback_iz_cpm_test_643_quirk.md`;
  `feedback_repl_tests_preferred.md`;
  `feedback_no_claude_coauthor.md`;
  `feedback_post_hw_smoke_steps_at_review.md`;
  `feedback_no_accept_disposition_for_bugs.md`;
  `feedback_assembler_operand_order.md`;
  `feedback_tib_size_inline_comments.md`;
  `feedback_stabilisation_interlude.md`;
  `project_assembler_keep_assembly.md` (banking.asm stays
  kernel-resident assembly — confirmed for Story 18.4).

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Opus 4.7 / 1M context)

### Debug Log References

**Pre-edit baselines (captured 2026-05-18):**

- `wc -c build/antforth.com` = **26,416 B** (matches expected Story-18.3 close).
- `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP** (matches expected).
- `make test-repl-banking` = **43 PASS / 0 FAIL** (matches expected).
- `make check-doc-sync` = **31 advisories / 0 drift** (matches expected).
- `wc -l src/banking.asm` = **972 lines**.
- `wc -l docs/ans-forth-core-compliance.md` = **911 lines** (vs spec
  "888+ lines" — file has grown post-Story-13.5 + Story-15.5;
  `.BANKS` row still at `:878` so the spec insertion-point reference
  remains valid).
- `wc -l tests/banking_tests.fth` = **1,238 lines**; `_p18f-end`
  invocation at `:1238` (matches spec).
- `wc -l Makefile` = **9,679 lines**; `probe-18.3-f` assertion block
  spans `:378..390` (matches spec).

**Insertion points re-validated (PD-2 / B.3 / Lesson 13.5-F):**

- `src/banking.asm`: `(stub-allocate)` body `NEXT` at `:822`;
  blank line at `:823`; `cross_bank_return:` block banner starts at
  `:824`; trampoline label at `:947`. New `w_BANK_OF` block inserted
  at the blank line `:823`; post-edit the label `w_BANK_OF` lands at
  `:857` and `w_BANK_OF_cf` at `:859`.
- `docs/ans-forth-core-compliance.md`: `.BANKS` row at `:878`;
  table-end `---` at `:880`. BANK-OF row inserted at `:879`.
- `tests/banking_tests.fth`: `_p18f-end` invocation at `:1238`.
  Probe-18.4 block inserted starting at `:1240`.
- `Makefile`: `probe-18.3-f` assertion block ends `:390`. Probe-18.4
  blocks inserted starting at `:391`.

**Q1 disposition (Probe-18.4-C shape):** **(b) DEFER to Epic 19.**
Reasoning: investigated the FIND chain mechanics post-`1 BANK!`. The
FORTH-WORDLIST hash-bucket array lives in fixed memory (kernel-
resident `forth_wordlist:` at `src/wordlists.asm:336..343`) but BANK!'s
triple swap only saves/loads `WORDLIST_NEXT` (the cell AT
`forth_wordlist`), NOT the bucket array. The bucket cells already
point to user-defined dict entries above `$8000` by the time the test
file reaches line ~1100 — so the next FIND from interpret mode under
`1 BANK!` dereferences a stale slot-2 pointer (the swapped-in
bank-1 page holds no matching entry → undefined word / hang). The
existing Story-18.3 HAZARD note at `tests/banking_tests.fth:1111..1119`
documents this exact pattern. Cross-bank-EXECUTE-through-BANK-OF is
not viable either: `inner_interpreter.asm:332..337` explicitly limits
cross-bank dispatch to DEFWORD callees (the sentinel-trampoline relies
on the callee's `JP DOCOL` push); BANK-OF is DEFCODE and never EXITs.
Disposition recorded as a sentinel-bounded "DEFERRED to Epic 19"
marker block in `tests/banking_tests.fth` per spec's "If Q1 picks
defer" instruction; FR-P4-17 across-bank witness carries forward to
Epic 19's bank-aware `:` test surface.

**Q2 disposition (sign-extension shape):** **(a) `RLA / SBC A, A`**
(2 B / 8 T total — single-instruction-pair, no branches). Smallest
of the three options; idiom is documented in Zilog programming guides
and used implicitly elsewhere in the kernel for sign-extension. CCD-3
block documents the idiom inline with a one-sentence "bit 7 → CF;
SBC A,A produces $FF if carry set, $00 if clear" explanation.

**Realised emit (AC1 / AC6 / Byte budget reconciliation):**

| Component | Estimated | Realised | Delta |
|-----------|----------:|---------:|------:|
| DEFCODE header for "BANK-OF" (3 + 7 = 10 B) | ~10-13 | 10 | -0 |
| Body: `LD H,B` / `LD L,C` / `LD C,(HL)` / `LD A,C` / `RLA` / `SBC A,A` / `LD B,A` (7 × 1 B) | ~7 | 7 | 0 |
| `NEXT` macro (EX DE,HL → NEXTHL → EX DE,HL / JP (HL)) | ~1-3 | 7 | +4 |
| CCD-3 source comments (Task 2) | 0 | 0 | 0 |
| Compliance-doc row (Task 3) | 0 | 0 | 0 |
| Probes (Task 4) | 0 | 0 | 0 |
| Makefile assertions (Task 5) | 0 | 0 | 0 |
| iz-cpm test-643 NOP padding | 0 | 0 | 0 (did not trip) |
| **Total** | **~18-25** | **24** | **+24 vs 26,416 B baseline** |

The NEXT macro estimate was nominal at "1-3 B" — the actual realised
size is 7 B per `src/macros.asm:32..46` (the EX DE,HL / LD E,(HL) /
INC HL / LD D,(HL) / INC HL / EX DE,HL / JP (HL) sequence). Final
24 B delta is well within the AC6 spec ceiling of ≤ ~30 B (80%
utilisation); no Q6-a-extended accept-with-rationale needed.

**Cumulative Epic-18 delta:** Story 18.1 +70 B + Story 18.2 +45 B +
Story 18.3 +73 B + Story 18.4 +24 B = **+212 B** against the
architecture's ~400 B Epic-18 envelope = **53% consumed**.

**Hardware-smoke recipe (Task 7, iz-cpm-banking-validated):**

```
DECIMAL
' BANK@ -1 (stub-allocate) BANK-OF .      \ expect: -1 ok
0 5 (stub-allocate) BANK-OF .             \ expect:  5 ok
BYE
```

Smoke-tested under `iz-cpm-banking --disk-a disk/a --disk-b disk/b
build/antforth.com` 2026-05-18 — output matched expected (`-1 ok`
and ` 5 ok`). Recipe carried forward to the code-review closing
message per `feedback_post_hw_smoke_steps_at_review.md` STRONG rule.

**Hardware-smoke verdict — real MicroBeast (S9 / NFR-P4-11):**
PASS 2026-05-18. Transcript saved to
`~/Downloads/beastty-20260518-154928.bin` (20,149 B). Captured
output across two pass-throughs (operator retyped the script after
a transient line-glitch on attempt 1's `(stub-allocate)`):

- `' BANK@ -1 (stub-allocate) BANK-OF .` → **`-1  ok`** (Probe-A
  fixed-memory marker; matches iz-cpm-banking verdict)
- `0 5 (stub-allocate) BANK-OF .` → **`5  ok`** (Probe-B
  banked-bank-5 marker; matches iz-cpm-banking verdict)
- Bonus: `0 50 (stub-allocate) BANK-OF .` → **`50  ok`** —
  confirms positive sign-extension arm handles `target_bank`
  values > 28 (anything `$00..$7F` round-trips cleanly; the
  active-bank index is bounded to `0..28` by allocator
  preconditions but BANK-OF itself is bank-list-agnostic per
  its undefined-input contract).

Independent verdict surface per Lesson 17-C confirms binding
iz-cpm-banking verdict.

### Completion Notes List

- **AC1 PASS** — `w_BANK_OF` / `w_BANK_OF_cf` DEFCODE pair landed at
  `src/banking.asm:857..867` (label-to-NEXT), inserted between
  `(stub-allocate)` (ends `:822`) and `cross_bank_return:` (now at
  `:992` post-insertion). Body is `LD H, B / LD L, C / LD C, (HL) /
  LD A, C / RLA / SBC A, A / LD B, A / NEXT` exactly as the AC1
  reference shape specifies. EXX-hygiene audit verdict (main-set
  only, no EXX) inline-documented per AC1 final sub-bullet.
- **AC2 PASS** — Per-component itemisation = 24 B realised
  (estimated 18-25 B). Body is a 7-instruction straight-line emit
  with no branches, no R-stack manipulation, no MMU writes,
  realising PD-P4-1 / PD-P4-11's "essentially free" claim. CCD-3
  block cites `architecture.md:209` (PD-P4-1) + `:347..363`
  (PD-P4-11) as the source-of-truth.
- **AC3 PASS** — CCD-3 source-comment block at
  `src/banking.asm:824..856` cites FR-P4-5, PD-P4-1
  (`architecture.md:209`), PD-P4-11 (`architecture.md:347..363`),
  redesign §1 row (`docs/antforth-banking-redesign.md:17`),
  forward-pointer to Story 18.5, EXX-hygiene audit verdict,
  undefined-input contract, and sign-extension shape rationale
  (Q2 decision). Compliance-doc row at
  `docs/ans-forth-core-compliance.md:879` immediately after the
  `.BANKS` row, format-matching the existing banking rows.
- **AC4 PASS (with Probe-C deferred)** — Probes 18.4-A and 18.4-B
  land at `tests/banking_tests.fth:1288..1300` (sentinel-bounded
  with canonical PASS literals). Probe-18.4-C replaced by a
  sentinel-bounded "DEFERRED to Epic 19" marker block (lines
  1342..1345) per Q1(b) disposition; M4 end-sentinel discipline
  preserved.
- **AC5 PASS** — `make test-repl-banking` reports Probe-18.4-A
  PASS, Probe-18.4-B PASS, Probe-18.4-C SKIP (with deferral
  rationale). Hardware-smoke recipe authored + validated under
  iz-cpm-banking (output: `-1 ok` and ` 5 ok`); recipe carried
  to closing-chat message per `feedback_post_hw_smoke_steps_at_review.md`.
  **Real MicroBeast UAT PASS 2026-05-18** — transcript at
  `~/Downloads/beastty-20260518-154928.bin`; `-1 ok` / `5 ok` /
  bonus `50 ok` (positive-arm sign-extension confirmation).
- **AC6 PASS** — Binary delta = **+24 B** (26,416 → 26,440 B).
  Under AC6 ≤ ~30 B ceiling (80% utilisation); cumulative Epic-18
  delta = **+212 B vs ~400 B envelope = 53% consumed**.
- **AC7 PASS** — `make test-repl` = **975 PASS / 0 FAIL / 2 SKIP**
  (no regression vs Story-18.3 baseline). `make test-repl-banking`
  = **45 PASS / 0 FAIL / 1 SKIP** (43 baseline + Probe-A + Probe-B
  PASS; Probe-C SKIP — matches spec's "≥ 45 PASS if Q1 picks defer").
  `make check-doc-sync` = **31 advisories / 0 drift** (no new
  section header added; advisory count unchanged from baseline).

### File List

- `src/banking.asm` — modified; +`w_BANK_OF` / `w_BANK_OF_cf`
  DEFCODE pair + CCD-3 block (`:824..867`; CCD-3 comment block
  `:824..856`, label+body+NEXT `:857..867`).
- `docs/ans-forth-core-compliance.md` — modified; +1 row at `:879`
  in the "Non-standard words (not in Core or Core Extension)" table.
- `tests/banking_tests.fth` — modified; +Probe-18.4 block at
  `:1240..1345` (Probes A + B + Probe-C deferral marker). Post-CR
  fix M1+M2: dropped colliding `VARIABLE _p18a-pass`/`_p18b-pass`
  + collapsed check words to single-IF form; renamed checks to
  `_p18-4a-check` / `_p18-4b-check` per Story-18.3 disambiguation
  convention.
- `Makefile` — modified; +3 awk-extract / grep assertion blocks
  after the `probe-18.3-f` block (Probe-A PASS, Probe-B PASS,
  Probe-C SKIP).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` —
  modified; `18-4-bank-of-one-byte-read-from-descriptor-stub` row:
  `ready-for-dev` → `in-progress` (dev-pass start) → `review`
  (dev-pass close) → `done` (CR close).
- `_bmad-output/implementation-artifacts/18-4-bank-of-one-byte-read-from-descriptor-stub.md`
  — new file (created this story); Status → `review` at dev-pass
  close → `done` at CR close; Tasks/Subtasks checkboxes all marked
  `[x]`; Dev Agent Record populated; File List populated; Change
  Log entry added.

### Change Log

- **2026-05-18** — Dev pass executed. Q1 dispositioned as defer
  (Probe-18.4-C → Epic 19); Q2 dispositioned as `RLA / SBC A, A`.
  `w_BANK_OF` DEFCODE pair landed with 24 B delta. All ACs PASS
  (AC4(c) DEFERRED per Q1). Story → review.
- **2026-05-18** — Real-MicroBeast hardware-smoke UAT PASS;
  transcript `~/Downloads/beastty-20260518-154928.bin`. S9 /
  NFR-P4-11 satisfied; Lesson 17-C independent-verdict-surface
  confirmation. Awaiting fresh-context CR for review→done
  transition.
- **2026-05-18** — Fresh-context CR pass (Opus 4.7 / 1M ctx).
  All ACs re-validated empirically: 26,440 B / 975 PASS / 45 PASS
  banking / 31 advisories. Sign-extension correctness reproved
  ($00 / $05 / $7F / $80 / $FF round-trip). Two MEDIUM findings
  fixed: M1 (VARIABLE `_p18a-pass`/`_p18b-pass` collided with
  Stories 18.1/18.2 same-named vars; Story-18.3 had broken the
  collision with `_p18-3*`) + M2 (check words wrapped a stack
  flag through a permanent VARIABLE for no functional reason).
  Both findings collapsed into a single edit: dropped the two
  VARIABLEs entirely, renamed checks to `_p18-4a-check` /
  `_p18-4b-check` (Story-18.3 disambiguation convention), and
  collapsed to single-IF form. Kernel binary unchanged
  (REPL-side edit only); banking probes still PASS. Two LOW
  findings (L3 File-List "modified" → "new"; L4 inconsistent
  CCD-3 line ranges) also fixed in this entry. Story → done.
